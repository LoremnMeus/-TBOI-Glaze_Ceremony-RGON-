-- Regenesis has one player-owned shared queue.
-- Every record owns its own recovery progress.
-- Familiars are indistinguishable presentation workers only:
-- they never own records, progress, identity, or persistent assignments.
-- At each room settlement, transiently assign up to one distinct queue record
-- to each currently existing Regenesis familiar.
-- A record may advance at most once per room.
-- New losses must never reset or steal progress already accumulated by older records.
-- Authoritative state lives in save.elses (Continue + Hourglass / project rewind).
-- Loss detection is owned by player_loss_holder (POST_PLAYER_LOSS).
-- Capture VFX is presentation-only (regenesis_capture_vfx).
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local pedestal_restore = require("Qing_Remaster_scripts.auxiliary.pedestal_restore")
local capture_vfx = require("Qing_Remaster_scripts.items.regenesis_capture_vfx")

local item = {
	ToCall = {},
	pre_ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Items.Regenesis,
	familiar = enums.Familiars.Regenesis,
	own_key = "Item_Regenesis_",
}

local STATE_KEY = item.own_key .. "state"
local RECORD_CAP = 12
local SCHEMA_VERSION = 1
local EID_QUEUE_VISIBLE = 6

local COIN_DENOMINATIONS = {
	{value = 10, subtype = CoinSubType.COIN_DIME},
	{value = 5, subtype = CoinSubType.COIN_NICKEL},
	{value = 2, subtype = CoinSubType.COIN_DOUBLEPACK},
	{value = 1, subtype = CoinSubType.COIN_PENNY},
}

-- Debug-only visual tuning. Not written to save.elses.
local visual_tune = {
	effort = true,
	resource_interval = 50,
	far_interval = 55,
	near_interval = 25,
	squash_x = 1.16,
	squash_y = 0.84,
	stretch_x = 0.86,
	stretch_y = 1.18,
	red_offset = 0.45,
	effort_duration = 12,
	resource_amount = 1,
}

local function default_visual_tune()
	visual_tune.effort = true
	visual_tune.resource_interval = 50
	visual_tune.far_interval = 55
	visual_tune.near_interval = 25
	visual_tune.squash_x = 1.16
	visual_tune.squash_y = 0.84
	visual_tune.stretch_x = 0.86
	visual_tune.stretch_y = 1.18
	visual_tune.red_offset = 0.45
	visual_tune.effort_duration = 12
	visual_tune.resource_amount = 1
end

local ELIGIBLE_ROOM = {
	[RoomType.ROOM_DEFAULT] = true,
	[RoomType.ROOM_BOSS] = true,
	[RoomType.ROOM_MINIBOSS] = true,
	[RoomType.ROOM_CHALLENGE] = true,
}

local function player_index(player)
	if not player or not player.GetData then return nil end
	local d = player:GetData()
	return d and d.__Index or nil
end

local function default_room()
	return {
		key = nil,
		eligible = false,
		rewarded = false,
	}
end

local function default_player_state()
	return {
		stored = {},
		dormant = {},
		room = default_room(),
		last_loss = nil,
	}
end

local function normalize_player_state(ps)
	if type(ps) ~= "table" then return end
	ps.stored = ps.stored or {}
	ps.dormant = ps.dormant or {}
	for _, rec in ipairs(ps.stored) do
		if type(rec) == "table" then
			rec.progress = math.max(0, math.floor(tonumber(rec.progress) or 0))
		end
	end
	for _, rec in ipairs(ps.dormant) do
		if type(rec) == "table" then
			rec.progress = 0
		end
	end
end

local function get_root()
	save.elses = save.elses or {}
	local root = save.elses[STATE_KEY]
	if type(root) ~= "table" then
		root = {schema_version = SCHEMA_VERSION, players = {}}
		save.elses[STATE_KEY] = root
	end
	root.players = root.players or {}
	root.schema_version = SCHEMA_VERSION
	for _, ps in pairs(root.players) do
		normalize_player_state(ps)
	end
	return root
end

local function get_pstate(player)
	local idx = player_index(player)
	if idx == nil then return nil, nil end
	local root = get_root()
	local ps = root.players[idx]
	if type(ps) ~= "table" then
		ps = default_player_state()
		root.players[idx] = ps
	end
	normalize_player_state(ps)
	ps.room = ps.room or default_room()
	-- Drop retired had_loss field if present on older save.elses.
	if ps.room.had_loss ~= nil then
		ps.room.had_loss = nil
	end
	return ps, idx
end

local function has_regenesis(player)
	return player and player.HasCollectible and player:HasCollectible(item.entity)
end

-- N copies → N indistinguishable familiars. Count includes temporary imitate effects.
local function familiar_count(player)
	if not player then return 0 end
	local count = player:GetCollectibleNum(item.entity)
	if player.GetEffects then
		local effects = player:GetEffects()
		if effects and effects.GetCollectibleEffectNum then
			count = count + effects:GetCollectibleEffectNum(item.entity)
		end
	end
	return math.max(0, count)
end

local function same_player(a, b)
	if not a or not b then return false end
	local ok_a, hash_a = pcall(GetPtrHash, a)
	local ok_b, hash_b = pcall(GetPtrHash, b)
	return ok_a and ok_b and hash_a == hash_b
end

local function find_regenesis_familiars(player)
	local result = {}
	if not player or item.familiar == nil then
		return result
	end
	local entities = Isaac.FindByType(EntityType.ENTITY_FAMILIAR, item.familiar, -1, false, false)
	for _, ent in ipairs(entities) do
		local familiar = ent:ToFamiliar()
		if familiar
			and auxi.check_all_exists(familiar)
			and familiar.Player
			and same_player(familiar.Player, player)
		then
			result[#result + 1] = familiar
		end
	end
	-- InitSeed order is only a stable pairing for this call, not an identity.
	table.sort(result, function(a, b)
		return (a.InitSeed or 0) < (b.InitSeed or 0)
	end)
	return result
end

function item.get_familiar(player)
	local list = find_regenesis_familiars(player)
	return list[1]
end

function item.get_active_jobs(player)
	local ps = get_pstate(player)
	if not ps then return {} end
	local familiars = find_regenesis_familiars(player)
	local jobs = {}
	local record_index = #ps.stored
	for _, familiar in ipairs(familiars) do
		if record_index <= 0 then
			break
		end
		jobs[#jobs + 1] = {
			familiar = familiar,
			record = ps.stored[record_index],
			index = record_index,
		}
		record_index = record_index - 1
	end
	return jobs
end

local function play_spit(familiar)
	if not familiar or not auxi.check_all_exists(familiar) then return end
	local sprite = familiar:GetSprite()
	if not sprite then return end
	sprite:Play("Spit", true)
end

local function copy_record(rec)
	return {
		kind = rec.kind,
		amount = math.max(1, math.floor(tonumber(rec.amount) or 1)),
		subtype = rec.subtype,
		collectible_id = rec.collectible_id,
		active_slot = rec.active_slot,
		active_item = rec.active_item,
		source = rec.source,
		progress = math.max(0, math.floor(tonumber(rec.progress) or 0)),
	}
end

local function trim_dormant(ps)
	while #ps.dormant > RECORD_CAP do
		table.remove(ps.dormant, 1)
	end
end

local function trim_stored(ps)
	while #ps.stored > RECORD_CAP do
		local remove_index = nil
		for i = 1, #ps.stored do
			local rec = ps.stored[i]
			if (tonumber(rec.progress) or 0) <= 0 then
				remove_index = i
				break
			end
		end
		table.remove(ps.stored, remove_index or 1)
	end
end

function item.adopt_dormant(player)
	local ps = get_pstate(player)
	if not ps then return end
	for i = 1, #ps.dormant do
		local rec = ps.dormant[i]
		if type(rec) == "table" then
			rec.progress = math.max(0, tonumber(rec.progress) or 0)
			ps.stored[#ps.stored + 1] = rec
		end
	end
	ps.dormant = {}
	trim_stored(ps)
end

local function choose_battery_subtype_from_loss(player, loss)
	local amount = math.max(1, math.floor(tonumber(loss.amount) or 1))
	local active_id = tonumber(loss.active_item) or 0
	local cfg = active_id > 0 and Isaac.GetItemConfig():GetCollectible(active_id) or nil
	local max_charge = cfg and tonumber(cfg.MaxCharges) or 0

	if amount > 12 then
		if max_charge > 12 then
			return BatterySubType.BATTERY_NORMAL
		end
		return BatterySubType.BATTERY_MEGA
	end
	if amount <= 2 then
		return BatterySubType.BATTERY_MICRO
	end

	local rng = player:GetCollectibleRNG(item.entity)
	if amount < 6 then
		local p_normal = (amount - 2) / 4
		if rng:RandomFloat() < p_normal then
			return BatterySubType.BATTERY_NORMAL
		end
		return BatterySubType.BATTERY_MICRO
	end
	if amount == 6 then
		return BatterySubType.BATTERY_NORMAL
	end
	if amount < 12 then
		local p_mega = (amount - 6) / 6
		if rng:RandomFloat() < p_mega then
			return BatterySubType.BATTERY_MEGA
		end
		return BatterySubType.BATTERY_NORMAL
	end
	return BatterySubType.BATTERY_MEGA
end

local function prepare_record(player, loss)
	local rec = copy_record(loss)
	if rec.kind == "charge" then
		rec.subtype = choose_battery_subtype_from_loss(player, loss)
		-- Battery subtype is the restore payload. Source active is no longer needed.
		rec.active_item = nil
		rec.active_slot = nil
	end
	rec.progress = 0
	return rec
end

local function push_loss(player, loss)
	local ps = get_pstate(player)
	if not ps then return nil, nil end
	local rec = prepare_record(player, loss)
	ps.last_loss = {
		kind = rec.kind,
		amount = rec.amount,
		subtype = rec.subtype,
		collectible_id = rec.collectible_id,
	}
	if has_regenesis(player) then
		ps.stored[#ps.stored + 1] = rec
		trim_stored(ps)
		return rec, "stored"
	end
	ps.dormant[#ps.dormant + 1] = rec
	trim_dormant(ps)
	return rec, "dormant"
end

function item.record_progress(record)
	return math.max(0, math.floor(tonumber(record and record.progress) or 0))
end

function item.rooms_required(record)
	if type(record) ~= "table" then
		return 999
	end
	if record.kind == "pill" then
		return 2
	end
	if record.kind == "card" then
		return 3
	end
	if record.kind ~= "collectible" then
		return 1
	end
	local id = tonumber(record.collectible_id) or 0
	local cfg = Isaac.GetItemConfig():GetCollectible(id)
	local quality = cfg and tonumber(cfg.Quality) or 0
	quality = math.max(0, math.min(4, quality))
	if quality <= 2 then
		return 3
	end
	return 4
end

function item.rooms_remaining(player)
	local ps = get_pstate(player)
	if not ps or #ps.stored <= 0 then
		return 0
	end
	local record = ps.stored[#ps.stored]
	return math.max(0, item.rooms_required(record) - item.record_progress(record))
end

local function spawn_pickup(variant, subtype, pos, spawner)
	local room = Game():GetRoom()
	pos = room:FindFreePickupSpawnPosition(pos or room:GetCenterPos(), 0, true)
	local ent = Isaac.Spawn(
		EntityType.ENTITY_PICKUP,
		variant,
		subtype or 0,
		pos,
		RandomVector() * 2,
		spawner
	)
	return ent and ent:ToPickup() or nil
end

local function spawn_restore_pickup(variant, subtype, pos, player)
	return spawn_pickup(variant, subtype, pos, player)
end

local function scatter_restore_pos(origin, index, total)
	if total <= 1 then
		return origin
	end
	local angle = ((index - 1) / total) * 360 - 90
	local radius = 8 + math.min(total, 8)
	return origin + Vector.FromAngle(angle) * radius
end

local function decompose_coins(amount)
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	local result = {}
	for _, denom in ipairs(COIN_DENOMINATIONS) do
		while amount >= denom.value do
			result[#result + 1] = denom.subtype
			amount = amount - denom.value
		end
	end
	return result
end

local function spawn_subtype_list(player, variant, subtypes, origin)
	local total = #subtypes
	if total <= 0 then return false end
	for i, subtype in ipairs(subtypes) do
		local pos = scatter_restore_pos(origin, i, total)
		if not spawn_restore_pickup(variant, subtype, pos, player) then
			return false
		end
	end
	return true
end

local function spawn_repeated(player, variant, subtype, amount, origin)
	amount = math.max(1, math.floor(amount or 1))
	local subtypes = {}
	for i = 1, amount do
		subtypes[i] = subtype
	end
	return spawn_subtype_list(player, variant, subtypes, origin)
end

local function restore_coins(player, amount, origin)
	local parts = decompose_coins(amount)
	if #parts <= 0 then return false end
	return spawn_subtype_list(player, PickupVariant.PICKUP_COIN, parts, origin)
end

local function restore_bombs(player, amount, origin)
	return spawn_repeated(player, PickupVariant.PICKUP_BOMB, BombSubType.BOMB_NORMAL, amount, origin)
end

local function restore_keys(player, amount, origin)
	return spawn_repeated(player, PickupVariant.PICKUP_KEY, KeySubType.KEY_NORMAL, amount, origin)
end

local function restore_charge(player, record, origin)
	local subtype = tonumber(record.subtype) or BatterySubType.BATTERY_NORMAL
	return spawn_restore_pickup(PickupVariant.PICKUP_LIL_BATTERY, subtype, origin, player) ~= nil
end

local function heart_pair(amount, full_subtype, half_subtype)
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	local parts = {}
	local full = math.floor(amount / 2)
	local half = amount % 2
	for _ = 1, full do
		parts[#parts + 1] = full_subtype
	end
	if half > 0 then
		parts[#parts + 1] = half_subtype
	end
	return parts
end

local function restore_red_hearts(player, amount, origin)
	return spawn_subtype_list(player, PickupVariant.PICKUP_HEART, heart_pair(amount, HeartSubType.HEART_FULL, HeartSubType.HEART_HALF), origin)
end

local function restore_soul_hearts(player, amount, origin)
	return spawn_subtype_list(player, PickupVariant.PICKUP_HEART, heart_pair(amount, HeartSubType.HEART_SOUL, HeartSubType.HEART_HALF_SOUL), origin)
end

local function restore_black_hearts(player, amount, origin)
	return spawn_repeated(player, PickupVariant.PICKUP_HEART, HeartSubType.HEART_BLACK, amount, origin)
end

local function restore_eternal_hearts(player, amount, origin)
	return spawn_repeated(player, PickupVariant.PICKUP_HEART, HeartSubType.HEART_ETERNAL, amount, origin)
end

local function restore_bone_hearts(player, amount, origin)
	return spawn_repeated(player, PickupVariant.PICKUP_HEART, HeartSubType.HEART_BONE, amount, origin)
end

local function restore_cards(player, record, amount, origin)
	local id = tonumber(record.subtype) or 0
	if id <= 0 then return false end
	return spawn_repeated(player, PickupVariant.PICKUP_TAROTCARD, id, amount, origin)
end

local function restore_pills(player, record, amount, origin)
	local color = tonumber(record.subtype) or 0
	if color == 0 then return false end
	return spawn_repeated(player, PickupVariant.PICKUP_PILL, color, amount, origin)
end

local function restore_resource_record(player, record, origin)
	local amount = math.max(1, math.floor(tonumber(record.amount) or 1))
	if record.kind == "coin" then
		return restore_coins(player, amount, origin)
	elseif record.kind == "bomb" then
		return restore_bombs(player, amount, origin)
	elseif record.kind == "key" then
		return restore_keys(player, amount, origin)
	elseif record.kind == "charge" then
		return restore_charge(player, record, origin)
	elseif record.kind == "red_heart" then
		return restore_red_hearts(player, amount, origin)
	elseif record.kind == "soul_heart" then
		return restore_soul_hearts(player, amount, origin)
	elseif record.kind == "black_heart" then
		return restore_black_hearts(player, amount, origin)
	elseif record.kind == "eternal_heart" then
		return restore_eternal_hearts(player, amount, origin)
	elseif record.kind == "bone_heart" then
		return restore_bone_hearts(player, amount, origin)
	elseif record.kind == "card" then
		return restore_cards(player, record, amount, origin)
	elseif record.kind == "pill" then
		return restore_pills(player, record, amount, origin)
	end
	return false
end

local function restore_collectible_one(player, record, origin)
	local id = tonumber(record.collectible_id) or 0
	if id <= 0 then return false end
	local pedestal = pedestal_restore.spawn_owned_collectible(
		item.own_key,
		{collectible_id = id, touched = true, charge = 0},
		origin,
		player
	)
	return pedestal ~= nil
end

local function restore_record(player, record, familiar)
	local origin = player.Position
	if familiar and auxi.check_all_exists(familiar) then
		origin = familiar.Position
	end
	local success = false
	if record.kind == "collectible" then
		success = restore_collectible_one(player, record, origin)
	else
		success = restore_resource_record(player, record, origin)
	end
	if success then
		play_spit(familiar)
	end
	return success
end

local function try_restore_jobs(player, jobs)
	local ps = get_pstate(player)
	if not ps or type(jobs) ~= "table" then return end
	table.sort(jobs, function(a, b)
		return (a.index or 0) > (b.index or 0)
	end)
	for _, job in ipairs(jobs) do
		local index = job.index
		local record = ps.stored[index]
		if record and record == job.record then
			local need = item.rooms_required(record)
			if item.record_progress(record) >= need then
				if restore_record(player, record, job.familiar) then
					if record.kind == "collectible" then
						record.amount = (tonumber(record.amount) or 1) - 1
						if record.amount <= 0 then
							table.remove(ps.stored, index)
						else
							record.progress = 0
						end
					else
						table.remove(ps.stored, index)
					end
				end
			end
		end
	end
end

function item.try_restore(player)
	try_restore_jobs(player, item.get_active_jobs(player))
end

local function apply_room_end_settlement(player)
	local ps = get_pstate(player)
	if not ps or #ps.stored <= 0 then
		return
	end
	local jobs = item.get_active_jobs(player)
	for _, job in ipairs(jobs) do
		if type(job.record) == "table" then
			job.record.progress = item.record_progress(job.record) + 1
		end
	end
	try_restore_jobs(player, jobs)
end

local function current_room_key()
	local level = Game():GetLevel()
	local desc = level:GetCurrentRoomDesc()
	local dim = 0
	if level.GetDimension then
		dim = level:GetDimension()
	elseif auxi.GetDimension then
		dim = auxi.GetDimension() or 0
	end
	local list = desc and desc.ListIndex or -1
	return string.format("%d:%d:%d:%d", level:GetStage(), level:GetStageType(), dim, list)
end

local function room_is_eligible()
	local room = Game():GetRoom()
	local rtype = room:GetType()
	if not ELIGIBLE_ROOM[rtype] then return false end
	if room:IsClear() then return false end
	local alive = room.GetAliveEnemiesCount and room:GetAliveEnemiesCount() or 0
	return alive > 0
end

function item.on_capture_arrive(player, familiar, _record)
	if not familiar or not auxi.check_all_exists(familiar) then
		return
	end
	local d = familiar:GetData()
	d[item.own_key .. "ReceiveLeft"] = 10
	d[item.own_key .. "EffortFrame"] = nil
end

local RECEIVE_LEFT = item.own_key .. "ReceiveLeft"
local EFFORT_CD = item.own_key .. "EffortCooldown"
local EFFORT_FRAME = item.own_key .. "EffortFrame"
local TARGET_KEY = item.own_key .. "ChargeTargetKey"
local PRESENTATION = item.own_key .. "Presentation"
local RECEIVE_AFTER_DELAY = 18

local function default_sprite_color()
	return Color(1, 1, 1, 1, 0, 0, 0)
end

local function apply_pose(sprite, sx, sy, oy, red)
	sprite.Scale = Vector(sx or 1, sy or 1)
	sprite.Offset = Vector(0, oy or 0)
	sprite.Color = Color(1, 1, 1, 1, red or 0, 0, 0)
end

local function apply_idle_pose(sprite)
	if not sprite then return end
	apply_pose(sprite, 1, 1, 0, 0)
	sprite.Color = default_sprite_color()
end

local function blend_axis(base, strength)
	return 1 + (base - 1) * strength
end

local function get_charge_visual_state(player, familiar)
	if not familiar then return nil end
	local jobs = item.get_active_jobs(player)
	local job = nil
	for _, candidate in ipairs(jobs) do
		if same_player(candidate.familiar, familiar) then
			job = candidate
			break
		end
	end
	if not job or type(job.record) ~= "table" then
		return nil
	end
	local record = job.record
	local rooms = item.rooms_required(record)
	local progress = item.record_progress(record)
	return {
		record = record,
		index = job.index,
		progress = progress,
		rooms_required = rooms,
		stored_count = #((get_pstate(player) or {}).stored or {}),
		ratio = math.max(0, math.min(1, progress / math.max(1, rooms))),
	}
end

local function visual_record_key(state)
	local record = state.record
	return table.concat({
		tostring(state.index or 0),
		tostring(record.kind),
		tostring(record.collectible_id or ""),
		tostring(record.subtype or ""),
		tostring(record.amount or 1),
	}, "|")
end

local function effort_interval(state)
	if (state.rooms_required or 1) <= 1 then
		return math.max(1, math.floor(visual_tune.resource_interval or 50))
	end
	local far_n = visual_tune.far_interval or 55
	local near_n = visual_tune.near_interval or 25
	return math.max(1, math.floor(far_n + (near_n - far_n) * state.ratio))
end

local function receive_pose(frame)
	local red = visual_tune.red_offset or 0.45
	if frame <= 1 then return 1, 1, 0, 0 end
	if frame <= 3 then return 1.20, 0.82, 1, 0 end
	if frame <= 5 then return 0.86, 1.18, -1, red end
	if frame <= 7 then return 1.08, 0.94, 0, 0 end
	return 1, 1, 0, 0
end

local function effort_pose(frame, strength)
	local duration = math.max(1, math.floor(visual_tune.effort_duration or 12))
	local u = frame / math.max(1, duration - 1)
	local sx, sy, oy, red = 1, 1, 0, 0
	if u < 0.25 then
		sx, sy, oy = 1, 1, 0
	elseif u < 0.42 then
		sx = blend_axis(visual_tune.squash_x, strength)
		sy = blend_axis(visual_tune.squash_y, strength)
		oy = 1 * strength
	elseif u < 0.62 then
		sx = blend_axis(visual_tune.stretch_x, strength)
		sy = blend_axis(visual_tune.stretch_y, strength)
		oy = -1 * strength
		red = (visual_tune.red_offset or 0.45) * strength
	elseif u < 0.8 then
		sx = blend_axis(1.10, strength)
		sy = blend_axis(0.92, strength)
		oy = 0
	end
	return sx, sy, oy, red
end

local function clear_effort_runtime(familiar)
	local d = familiar:GetData()
	d[RECEIVE_LEFT] = nil
	d[EFFORT_CD] = nil
	d[EFFORT_FRAME] = nil
	d[TARGET_KEY] = nil
	d[PRESENTATION] = "idle"
end

local function update_presentation(familiar, player)
	local sprite = familiar:GetSprite()
	if not sprite then return end
	local d = familiar:GetData()
	if sprite:IsPlaying("Spit") then
		apply_idle_pose(sprite)
		d[PRESENTATION] = "spit"
		return
	end
	local state = get_charge_visual_state(player, familiar)
	if not state then
		clear_effort_runtime(familiar)
		apply_idle_pose(sprite)
		return
	end
	local key = visual_record_key(state)
	if d[TARGET_KEY] ~= key then
		d[TARGET_KEY] = key
		d[EFFORT_FRAME] = nil
		if (tonumber(d[RECEIVE_LEFT]) or 0) <= 0 then
			d[EFFORT_CD] = RECEIVE_AFTER_DELAY
		end
	end

	local receive = tonumber(d[RECEIVE_LEFT]) or 0
	if receive > 0 then
		local frame = 10 - receive
		local sx, sy, oy, red = receive_pose(frame)
		apply_pose(sprite, sx, sy, oy, red)
		d[RECEIVE_LEFT] = receive - 1
		d[PRESENTATION] = "receive"
		d[item.own_key .. "PresentFrame"] = frame
		if d[RECEIVE_LEFT] <= 0 then
			d[EFFORT_FRAME] = nil
			d[EFFORT_CD] = RECEIVE_AFTER_DELAY
		end
		return
	end

	if visual_tune.effort == false then
		apply_idle_pose(sprite)
		d[PRESENTATION] = "idle"
		return
	end

	local strength = 0.75 + state.ratio * 0.25
	local duration = math.max(1, math.floor(visual_tune.effort_duration or 12))
	local effort_frame = d[EFFORT_FRAME]
	if effort_frame ~= nil then
		local sx, sy, oy, red = effort_pose(effort_frame, strength)
		apply_pose(sprite, sx, sy, oy, red)
		effort_frame = effort_frame + 1
		d[PRESENTATION] = "effort"
		d[item.own_key .. "PresentFrame"] = effort_frame
		if effort_frame >= duration then
			d[EFFORT_FRAME] = nil
			d[EFFORT_CD] = effort_interval(state)
		else
			d[EFFORT_FRAME] = effort_frame
		end
		return
	end

	local cd = tonumber(d[EFFORT_CD])
	if cd == nil then
		cd = effort_interval(state)
	end
	cd = cd - 1
	if cd <= 0 then
		d[EFFORT_FRAME] = 0
		d[EFFORT_CD] = nil
	else
		d[EFFORT_CD] = cd
	end
	apply_idle_pose(sprite)
	d[PRESENTATION] = "idle"
	d[item.own_key .. "EffortInterval"] = effort_interval(state)
end

capture_vfx.set_familiar_resolver(function(player, hint)
	local list = find_regenesis_familiars(player)
	if #list == 0 then return nil end
	hint = type(hint) == "table" and hint or {}
	if hint.seed then
		for _, familiar in ipairs(list) do
			if familiar.InitSeed == hint.seed then
				return familiar
			end
		end
	end
	local origin = hint.pos
	if not origin then
		return list[1]
	end
	local best = list[1]
	local best_dist = nil
	for _, familiar in ipairs(list) do
		local screen = Isaac.WorldToScreen(familiar.Position)
		local dist = screen:DistanceSquared(origin)
		if not best_dist or dist < best_dist then
			best = familiar
			best_dist = dist
		end
	end
	return best
end)
capture_vfx.set_arrive_handler(function(player, familiar, record)
	item.on_capture_arrive(player, familiar, record)
end)

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_EVALUATE_CACHE,
	params = nil,
	Function = function(_, player, cacheFlag)
		if cacheFlag ~= CacheFlag.CACHE_FAMILIARS then
			return
		end
		if item.familiar == nil then
			return
		end
		local cnt = familiar_count(player)
		player:CheckFamiliar(
			item.familiar,
			cnt,
			player:GetCollectibleRNG(item.entity),
			Isaac.GetItemConfig():GetCollectible(item.entity)
		)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_FAMILIAR_INIT,
	params = item.familiar,
	Function = function(_, ent)
		local familiar = ent:ToFamiliar()
		if not familiar then return end
		familiar.CollisionDamage = 0
		familiar.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_WALLS
		local sprite = familiar:GetSprite()
		if sprite then
			sprite:Play("Appear", true)
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_FAMILIAR_UPDATE,
	params = item.familiar,
	Function = function(_, ent)
		local familiar = ent:ToFamiliar()
		if not familiar then return end
		local d = familiar:GetData()
		local sprite = familiar:GetSprite()

		familiar.CollisionDamage = 0
		familiar.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_WALLS

		-- Regenesis currently never leaves the vanilla follower chain.
		-- If later behavior detaches/reorders the familiar, use
		-- Familiar_Follower_Arbiter instead of directly owning queue transitions.
		if not d[item.own_key .. "IsFollow"] then
			familiar:AddToFollowers()
			d[item.own_key .. "IsFollow"] = true
		end
		familiar:FollowParent()

		if sprite then
			if sprite:IsFinished("Appear") then
				sprite:Play("Idle", true)
			elseif sprite:IsFinished("Spit") then
				sprite:Play("Idle", true)
			elseif not sprite:IsPlaying("Appear")
				and not sprite:IsPlaying("Idle")
				and not sprite:IsPlaying("Spit")
			then
				sprite:Play("Idle", true)
			end
		end

		-- One owner per frame: Spit > Receive > Effort > Idle.
		update_presentation(familiar, familiar.Player)
	end,
})

-- POST_PLAYER_LOSS
table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_PLAYER_LOSS,
	params = nil,
	Function = function(_, player, loss)
		if not player or type(loss) ~= "table" then return end
		local rec, destination = push_loss(player, loss)
		if rec and destination == "stored" then
			local fly = rec
			if rec.kind == "charge" then
				fly = {
					kind = rec.kind,
					amount = rec.amount,
					subtype = rec.subtype,
					active_slot = loss.active_slot,
					active_item = loss.active_item,
				}
			end
			capture_vfx.capture(player, fly)
		end
	end,
})

-- Gain Regenesis → adopt dormant (no replay of capture VFX)
table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE,
	params = item.entity,
	Function = function(_, player, _id, _count)
		item.adopt_dormant(player)
	end,
})

-- Floor boundary
table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_LEVEL,
	params = nil,
	Function = function(_)
		for i = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(i)
			local ps = get_pstate(player)
			if not ps then
				-- continue
			elseif has_regenesis(player) then
				item.adopt_dormant(player)
			else
				ps.dormant = {}
			end
		end
	end,
})

-- New room: per-player room-end recovery init
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function(_)
		local key = current_room_key()
		local eligible = room_is_eligible()
		for i = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(i)
			local ps = get_pstate(player)
			if ps then
				ps.room = {
					key = key,
					eligible = eligible,
					rewarded = false,
				}
			end
		end
	end,
})

-- Combat-room clear → one step on each familiar's transient job, then spit finished records.
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD,
	params = nil,
	Function = function(_)
		for i = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(i)
			local ps = get_pstate(player)
			if not ps then
				-- continue
			elseif not has_regenesis(player) then
				-- continue
			elseif not ps.room or not ps.room.eligible then
				-- continue
			elseif ps.room.rewarded then
				-- already settled
			else
				ps.room.rewarded = true
				apply_room_end_settlement(player)
			end
		end
	end,
})

-- Debug / snapshot API
function item.get_player_state(player)
	return get_pstate(player)
end

local function battery_label(subtype)
	subtype = tonumber(subtype)
	if subtype == BatterySubType.BATTERY_MICRO then return "Micro Battery" end
	if subtype == BatterySubType.BATTERY_MEGA then return "Mega Battery" end
	if subtype == BatterySubType.BATTERY_NORMAL then return "Normal Battery" end
	return "Battery ?"
end

function item.restore_preview(record)
	if type(record) ~= "table" then return "" end
	local kind = record.kind
	local amount = math.max(1, math.floor(tonumber(record.amount) or 1))
	if kind == "coin" then
		local labels = {}
		for _, subtype in ipairs(decompose_coins(amount)) do
			if subtype == CoinSubType.COIN_DIME then labels[#labels + 1] = "10"
			elseif subtype == CoinSubType.COIN_NICKEL then labels[#labels + 1] = "5"
			elseif subtype == CoinSubType.COIN_DOUBLEPACK then labels[#labels + 1] = "2"
			else labels[#labels + 1] = "1" end
		end
		return table.concat(labels, "+")
	elseif kind == "bomb" then
		return tostring(amount) .. " normal bombs"
	elseif kind == "key" then
		return tostring(amount) .. " normal keys"
	elseif kind == "charge" then
		return battery_label(record.subtype)
	elseif kind == "red_heart" then
		return tostring(math.floor(amount / 2)) .. " full + " .. tostring(amount % 2) .. " half"
	elseif kind == "soul_heart" then
		return tostring(math.floor(amount / 2)) .. " soul + " .. tostring(amount % 2) .. " half"
	elseif kind == "black_heart" then
		return tostring(amount) .. " black"
	elseif kind == "eternal_heart" then
		return tostring(amount) .. " eternal"
	elseif kind == "bone_heart" then
		return tostring(amount) .. " bone"
	elseif kind == "card" then
		return tostring(amount) .. " card " .. tostring(record.subtype)
	elseif kind == "pill" then
		return tostring(amount) .. " pill " .. tostring(record.subtype)
	elseif kind == "collectible" then
		return "pedestal " .. tostring(record.collectible_id)
	end
	return ""
end

local function describe_record(rec)
	if type(rec) ~= "table" then return nil end
	return {
		kind = rec.kind,
		amount = tonumber(rec.amount) or 1,
		subtype = rec.subtype,
		collectible_id = rec.collectible_id,
		active_slot = rec.active_slot,
		active_item = rec.active_item,
		progress = item.record_progress(rec),
		rooms = item.rooms_required(rec),
		preview = item.restore_preview(rec),
		source = rec.source,
	}
end

function item.get_debug_snapshot(player)
	player = player or Isaac.GetPlayer(0)
	local ps, idx = get_pstate(player)
	if not ps then
		return {
			player_index = nil,
			has_regenesis = false,
			familiar = {present = false, variant = item.familiar},
			queue = {stored_count = 0, dormant_count = 0, cap = RECORD_CAP},
			familiars = 0,
			active_jobs = 0,
			room = default_room(),
		}
	end
	local familiars = find_regenesis_familiars(player)
	local jobs = item.get_active_jobs(player)
	local familiar = familiars[1]
	local top = ps.stored[#ps.stored]
	local top_progress = top and item.record_progress(top) or 0
	local top_rooms = top and item.rooms_required(top) or 0
	local sprite = familiar and familiar:GetSprite() or nil
	local fam_info = {
		present = #familiars > 0,
		count = #familiars,
		variant = item.familiar,
		init_seed = familiar and familiar.InitSeed or nil,
		position = familiar and {x = familiar.Position.X, y = familiar.Position.Y} or nil,
		animation = sprite and sprite:GetAnimation() or nil,
		owner_index = familiar and player_index(familiar.Player) or nil,
	}
	return {
		player_index = idx,
		has_regenesis = has_regenesis(player),
		familiar = fam_info,
		familiars = #familiars,
		active_jobs = #jobs,
		queue = {
			stored_count = #ps.stored,
			dormant_count = #ps.dormant,
			cap = RECORD_CAP,
			top = describe_record(top),
			last_loss = ps.last_loss and describe_record(ps.last_loss) or nil,
		},
		room = {
			key = ps.room and ps.room.key or nil,
			eligible = ps.room and ps.room.eligible or false,
			rewarded = ps.room and ps.room.rewarded or false,
		},
		recovery = {
			progress = top_progress,
			rooms_required = top_rooms,
			rooms_remaining = top and math.max(0, top_rooms - top_progress) or 0,
			ratio = top and math.min(1, top_progress / math.max(1, top_rooms)) or 0,
		},
		presentation = familiar and {
			mode = familiar:GetData()[PRESENTATION] or "idle",
			frame = familiar:GetData()[item.own_key .. "PresentFrame"],
			interval = familiar:GetData()[item.own_key .. "EffortInterval"],
		} or {mode = "idle"},
	}
end

function item.debug_queue_entries(player)
	player = player or Isaac.GetPlayer(0)
	local ps = get_pstate(player)
	local out = {stored = {}, dormant = {}}
	if not ps then return out end
	for i = #ps.stored, 1, -1 do
		local rec = ps.stored[i]
		local entry = describe_record(rec) or {}
		entry.index = i
		entry.is_top = (i == #ps.stored)
		out.stored[#out.stored + 1] = entry
	end
	for i = #ps.dormant, 1, -1 do
		local rec = ps.dormant[i]
		local entry = describe_record(rec) or {}
		entry.index = i
		entry.newest = (i == #ps.dormant)
		out.dormant[#out.dormant + 1] = entry
	end
	return out
end

function item.get_debug_status()
	local s = item.get_debug_snapshot()
	local top = s.queue and s.queue.top
	local top_s = "none"
	local top_w = "-"
	if top then
		top_s = tostring(top.kind)
		if top.collectible_id then top_s = top_s .. ":" .. tostring(top.collectible_id) end
		if top.subtype then top_s = top_s .. ":" .. tostring(top.subtype) end
		top_w = tostring(top.progress or 0) .. "/" .. tostring(top.rooms or 0)
	end
	local last = s.queue and s.queue.last_loss
	local last_s = last and tostring(last.kind) or "none"
	return string.format(
		"has=%s fams=%s jobs=%s stored=%d/%d dormant=%d top=%s prog=%s eligible=%s rewarded=%s last=%s",
		tostring(s.has_regenesis),
		tostring(s.familiars or 0),
		tostring(s.active_jobs or 0),
		s.queue.stored_count,
		s.queue.cap or RECORD_CAP,
		s.queue.dormant_count,
		top_s,
		top_w,
		tostring(s.room and s.room.eligible),
		tostring(s.room and s.room.rewarded),
		last_s
	)
end

function item.debug_get_familiar(player)
	return item.get_familiar(player or Isaac.GetPlayer(0))
end

function item.debug_refresh_familiar(player)
	player = player or Isaac.GetPlayer(0)
	if not player then return end
	player:AddCacheFlags(CacheFlag.CACHE_FAMILIARS)
	player:EvaluateItems()
end

function item.debug_locate_familiar(player)
	player = player or Isaac.GetPlayer(0)
	local familiars = find_regenesis_familiars(player)
	if #familiars == 0 then
		return "fam=0"
	end
	local parts = {}
	for i, familiar in ipairs(familiars) do
		local sprite = familiar:GetSprite()
		local anim = sprite and sprite:GetAnimation() or "?"
		parts[#parts + 1] = string.format(
			"#%d pos=(%.1f,%.1f) seed=%s anim=%s",
			i,
			familiar.Position.X,
			familiar.Position.Y,
			tostring(familiar.InitSeed),
			tostring(anim)
		)
	end
	return table.concat(parts, " | ")
end

function item.debug_clear_stored(player)
	player = player or Isaac.GetPlayer(0)
	local ps = get_pstate(player)
	if ps then ps.stored = {} end
end

function item.debug_clear_dormant(player)
	player = player or Isaac.GetPlayer(0)
	local ps = get_pstate(player)
	if ps then ps.dormant = {} end
end

function item.debug_add_progress(player, amount)
	player = player or Isaac.GetPlayer(0)
	local jobs = item.get_active_jobs(player)
	local steps = math.max(1, math.floor(tonumber(amount) or 1))
	for _, job in ipairs(jobs) do
		if type(job.record) == "table" then
			job.record.progress = item.record_progress(job.record) + steps
		end
	end
	try_restore_jobs(player, jobs)
end

function item.debug_simulate_room_clear(player)
	player = player or Isaac.GetPlayer(0)
	apply_room_end_settlement(player)
end

function item.debug_force_restore(player)
	-- Compat: try restore with current progress (does not pad progress).
	player = player or Isaac.GetPlayer(0)
	item.try_restore(player)
end

function item.debug_force_next_restore(player)
	player = player or Isaac.GetPlayer(0)
	local ps = get_pstate(player)
	if not ps or #ps.stored <= 0 then return false end
	local top = ps.stored[#ps.stored]
	top.progress = item.rooms_required(top)
	local jobs = item.get_active_jobs(player)
	local chosen = nil
	for _, job in ipairs(jobs) do
		if job.record == top then
			chosen = job
			break
		end
	end
	try_restore_jobs(player, {chosen or {record = top, index = #ps.stored, familiar = item.get_familiar(player)}})
	return true
end

local function debug_find_collectible_by_quality(q)
	q = tonumber(q) or 0
	local cfg = Isaac.GetItemConfig()
	local count = 0
	if cfg.GetCollectibles then
		local list = cfg:GetCollectibles()
		count = list and list.Size or 0
	end
	if count <= 0 then count = CollectibleType.NUM_COLLECTIBLES or 732 end
	for id = 1, count - 1 do
		local info = cfg:GetCollectible(id)
		if info
			and not info.Hidden
			and info.Type ~= ItemType.ITEM_ACTIVE
			and (not info.Tags or (info.Tags & ItemConfig.TAG_QUEST) == 0)
			and tonumber(info.Quality) == q
		then
			return id
		end
	end
	return nil
end

function item.debug_find_collectible_by_quality(q)
	return debug_find_collectible_by_quality(q)
end

function item.get_visual_tune()
	return visual_tune
end

function item.set_visual_tune(key, value)
	if visual_tune[key] == nil and key ~= "resource_amount" then return end
	visual_tune[key] = value
end

function item.debug_inject_loss(player, loss)
	player = player or Isaac.GetPlayer(0)
	loss = loss or {kind = "coin", amount = visual_tune.resource_amount, source = "debug"}
	if loss.amount == nil then
		loss.amount = visual_tune.resource_amount
	end
	if loss.kind == "charge" and not loss.active_item and player.GetActiveItem then
		loss.active_item = player:GetActiveItem(ActiveSlot.SLOT_PRIMARY)
		loss.active_slot = ActiveSlot.SLOT_PRIMARY
	end
	local rec, destination = push_loss(player, loss)
	if rec and destination == "stored" then
		local fly = rec
		if rec.kind == "charge" then
			fly = {
				kind = rec.kind,
				amount = rec.amount,
				subtype = rec.subtype,
				active_slot = loss.active_slot,
				active_item = loss.active_item,
			}
		end
		capture_vfx.capture(player, fly)
	end
	return rec, destination
end

function item.reset_debug()
	local player = Isaac.GetPlayer(0)
	local ps = get_pstate(player)
	if not ps then return end
	ps.stored = {}
	ps.dormant = {}
	ps.room = default_room()
	ps.last_loss = nil
	capture_vfx.clear_all()
	default_visual_tune()
end

-- Compatibility stubs (old century ImGui / callers)
item.CENTURIES = nil
function item.get_run_data() return nil end
function item.get_legacy() return nil end
function item.set_score() end
function item.set_active_century() end
function item.set_pending_century() end
function item.force_settle() return nil end
function item.debug_apply_active() return nil end
function item.debug_announce() end
function item.clear_legacy()
end

local HEART_EID_ICON = {
	red_heart = "Heart",
	soul_heart = "SoulHeart",
	black_heart = "BlackHeart",
	eternal_heart = "EternalHeart",
	bone_heart = "BoneHeart",
}

local function eid_record_icon(record)
	local kind = record.kind
	if kind == "collectible" then
		local id = tonumber(record.collectible_id) or 0
		if id > 0 then return "{{Collectible" .. tostring(id) .. "}}" end
		return "{{Collectible}}"
	end
	if kind == "card" then
		local id = tonumber(record.subtype) or 0
		if id > 0 then return "{{Card" .. tostring(id) .. "}}" end
		return "{{Card}}"
	end
	if kind == "pill" then
		local id = tonumber(record.subtype) or 0
		if id > 0 then return "{{Pill" .. tostring(id) .. "}}" end
		return "{{Pill}}"
	end
	if kind == "coin" then return "{{Coin}}" end
	if kind == "bomb" then return "{{Bomb}}" end
	if kind == "key" then return "{{Key}}" end
	if kind == "charge" then return "{{Battery}}" end
	if HEART_EID_ICON[kind] then
		return "{{" .. HEART_EID_ICON[kind] .. "}}"
	end
	return ""
end

local function eid_record_text(record)
	local icon = eid_record_icon(record)
	if icon == "" then return "" end
	local progress = item.record_progress(record)
	local required = item.rooms_required(record)
	local amount = math.max(1, math.floor(tonumber(record.amount) or 1))
	local count = amount > 1 and ("×" .. tostring(amount)) or ""
	return icon .. count .. " " .. tostring(progress) .. "/" .. tostring(required)
end

function item.build_eid_queue(player)
	local ps = get_pstate(player)
	if not ps or #ps.stored <= 0 then return "" end
	local parts = {}
	local shown = 0
	for i = #ps.stored, 1, -1 do
		if shown >= EID_QUEUE_VISIBLE then
			parts[#parts + 1] = "..."
			break
		end
		local text = eid_record_text(ps.stored[i])
		if text ~= "" then
			parts[#parts + 1] = text
			shown = shown + 1
		end
	end
	return table.concat(parts, " -> ")
end

if EID and EID.addDescriptionModifier then
	EID:addDescriptionModifier(
		"qing_regenesis_queue",
		function(desc)
			return desc.ObjType == 5
				and desc.ObjVariant == 100
				and desc.ObjSubType == item.entity
				and auxi.have_player_has_collectible(item.entity)
		end,
		function(desc)
			local player = (EID and EID.player) or Game():GetPlayer(0)
			local queue = item.build_eid_queue(player)
			if queue and queue ~= "" then
				EID:appendToDescription(desc, "#" .. queue)
			end
			return desc
		end
	)
end

return item
