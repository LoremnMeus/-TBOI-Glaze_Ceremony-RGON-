local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local callback_manager = require("Qing_Remaster_scripts.core.callback_manager")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")
local unique = require("Qing_Remaster_scripts.others.Unique_holder")

local item = {
	ToCall = {},
    post_ToCall = {},
	myToCall = {},
	own_key = "collectible_holder_",
	update_filter = nil,
	itemList = {},
	collectibles_size = 1,
	trinkets_size = 1,
	trinketList = {},
	trinket_at_hand = {},
	-- Runtime only: last pedestal acquisition context per persistent player index.
	-- Not save.elses (entity userdata must not persist across Continue).
	_last_gain_context = {},
}

function item.check_item_list()
	local config = Isaac:GetItemConfig()
	local collectibles = config:GetCollectibles()
	local size = collectibles.Size
	if size >= item.collectibles_size then 
		item.itemList = {}
		item.collectibles_size = size
		for i= 1, size do
			local collectible = config:GetCollectible(i)
			if collectible then
				table.insert(item.itemList,#item.itemList + 1,i)
			end
		end
	end
end
item.check_item_list()

function item.check_trinket_list()
	local config = Isaac:GetItemConfig()
	local trinkets = config:GetTrinkets()
	local size = trinkets.Size
	if size >= item.trinkets_size then 
		item.trinketList = {}
		item.trinkets_size = size
		for i= 1, size do
			local trinket = config:GetTrinket(i)
			if trinket then
				table.insert(item.trinketList,#item.trinketList + 1,i)
			end
		end
	end
end
item.check_trinket_list()

function item.compare_player_data(idx,player)
	if save.elses.collectible_counter[idx] then
		if player:GetCollectibleCount() ~= save.elses.collectible_counter[idx].num then return false end
		for u,v in pairs(save.elses.collectible_counter[idx].list) do
			if player:GetCollectibleNum(u,true) ~= v then return false end
		end
		return true
	end
end

--- INTERNAL.
--- Consumer code MUST NOT call this to fabricate a pickup.
--- Use simulate_pickup / simulate_active_pickup instead.
function item.add_queued_data(player, colid, touched)
	if not player or not colid then
		return
	end
	local idx = player:GetData().__Index
	save.elses[item.own_key.."record"] = save.elses[item.own_key.."record"] or {}
	table.insert(save.elses[item.own_key.."record"], #save.elses[item.own_key.."record"] + 1, {
		idx = idx,
		id = colid,
		touched = touched,
		frame = Game():GetFrameCount(),
	})
end

--- Acquisition Context V2: capture source while pedestal is live; confirm on Gain.
--- Layers: Acquisition fact / historical source / optional live pedestal.
--- OBSERVED: shop/devil may delete pedestal before Gain; source must outlive entity.

local ACQ_CANDIDATE_TTL = 90
local ACQ_TXN_TTL = 180
-- Game():GetFrameCount is 30 Hz. Collision alone is not a source; the queue
-- window only keeps a candidate eligible for a later identity/state check.
local ACQ_QUEUE_WINDOW = 60
local TRUSTED_SOURCE_METHODS = {
	collision_and_removed = true,
	collision_and_emptied = true,
	explicit_programmatic = true,
}

item._acq_candidates = item._acq_candidates or {} -- player_index -> { [ptr]=candidate }
item._acq_txns = item._acq_txns or {} -- acquisition_id -> txn
item._acq_by_player = item._acq_by_player or {} -- player_index -> acquisition_id (queued)
item._acq_serial = item._acq_serial or 0
item._explicit_binds = item._explicit_binds or {} -- player_index -> fifo of programmatic binds

local function player_index_of(player)
	if not player then return nil end
	local d = player:GetData()
	if d and d.__Index ~= nil then return d.__Index end
	return nil
end

local function room_identity()
	local level = Game():GetLevel()
	local desc = level and level:GetCurrentRoomDesc() or nil
	local dim = 0
	pcall(function() dim = auxi.GetDimension() or 0 end)
	local stage = level and level:GetStage() or 0
	local stype = level and level:GetStageType() or 0
	return {
		list_index = desc and desc.ListIndex or nil,
		safe_grid = desc and desc.SafeGridIndex or nil,
		dimension = dim,
		floor_key = tostring(stage) .. ":" .. tostring(stype) .. ":" .. tostring(dim),
	}
end

local function ptr_of(ent)
	if not ent then return nil end
	local ok, h = pcall(GetPtrHash, ent)
	return ok and h or nil
end

local function entity_alive(ent)
	return ent ~= nil and ent.Exists and ent:Exists() and not (ent.IsDead and ent:IsDead())
end

--- Copy the pedestal generation that already exists when the gain is associated.
--- A number in this runtime context still identifies the source after the item
--- queue clears. Empty pedestals are not classified here.
local function snapshot_generation_id(ent, explicit)
	if explicit ~= nil then
		return explicit
	end
	if not ent or not ent.GetData then
		return nil
	end
	if ent.Exists and not ent:Exists() then
		return nil
	end
	local gen = unique.peek_generation(ent)
	if type(gen) ~= "table" or gen.id == nil then
		if (tonumber(ent.SubType) or 0) <= 0 then
			return nil
		end
		gen = unique.resolve_generation(ent)
	end
	if type(gen) == "table" and gen.id ~= nil then
		return gen.id
	end
	return nil
end

local function capture_source_snapshot(player, pickup, collectible_id, meta)
	meta = meta or {}
	if not pickup then return nil end
	local room = room_identity()
	local subtype = tonumber(pickup.SubType) or 0
	local id = tonumber(collectible_id) or subtype
	if id <= 0 then
		id = subtype
	end
	local gen_id = snapshot_generation_id(pickup, meta.generation_id)
	return {
		generation_id = gen_id,
		collectible_id = id > 0 and id or nil,
		init_seed = pickup.InitSeed,
		drop_seed = pickup.DropSeed,
		pickup_ptr = ptr_of(pickup),
		player_index = player_index_of(player),
		room_list_index = room.list_index,
		safe_grid = room.safe_grid,
		dimension = room.dimension,
		floor_key = room.floor_key,
		observed_frame = Game():GetFrameCount(),
		attribution_method = meta.attribution_method,
		candidate_reasons = meta.candidate_reasons,
	}
end

local function prune_acq_runtime()
	local now = Game():GetFrameCount()
	for pidx, by_ptr in pairs(item._acq_candidates) do
		for ptr, cand in pairs(by_ptr) do
			if now - (cand.last_collision_frame or cand.first_collision_frame or now) > ACQ_CANDIDATE_TTL then
				by_ptr[ptr] = nil
			end
		end
	end
	for aid, txn in pairs(item._acq_txns) do
		if txn.state == "COMMITTED" or txn.state == "CANCELLED" or txn.state == "GAIN_CONFIRMED" then
			if now - (txn.closed_frame or txn.opened_frame or now) > ACQ_TXN_TTL then
				item._acq_txns[aid] = nil
			end
		elseif now - (txn.opened_frame or now) > ACQ_TXN_TTL then
			local pidx = txn.player_index
			local queued = pidx and save.elses.collectible_queue_item and save.elses.collectible_queue_item[pidx]
			local still_open = queued and tonumber(queued.Item) == tonumber(txn.collectible_id)
				and item._acq_by_player[pidx] == aid and txn.consumed ~= true
			if not still_open then
				txn.state = "CANCELLED"
				txn.closed_frame = now
			end
		end
	end
end

--- Observe collision candidate (read-only). Never intercepts collision.
function item.observe_pickup_collision_candidate(player, pickup)
	if not player or not pickup then return end
	if pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then return end
	local subtype = tonumber(pickup.SubType) or 0
	if subtype <= 0 then return end
	local pidx = player_index_of(player)
	if pidx == nil then return end
	prune_acq_runtime()
	local ptr = ptr_of(pickup)
	if not ptr then return end
	item._acq_candidates[pidx] = item._acq_candidates[pidx] or {}
	local existing = item._acq_candidates[pidx][ptr]
	local now = Game():GetFrameCount()
	if existing then
		existing.last_collision_frame = now
		existing.collision_count = (existing.collision_count or 1) + 1
		return existing
	end
	local snap = capture_source_snapshot(player, pickup, subtype, {
		attribution_method = "collision_candidate",
		candidate_reasons = { "pre_pickup_collision" },
	})
	local cand = {
		source_snapshot = snap,
		first_collision_frame = now,
		last_collision_frame = now,
		collision_count = 1,
		pickup_ptr = ptr,
		collectible_id = subtype,
		player_index = pidx,
	}
	item._acq_candidates[pidx][ptr] = cand
	return cand
end

local function new_acquisition_id()
	item._acq_serial = (item._acq_serial or 0) + 1
	return string.format("acq_%d_%d", Game():GetFrameCount(), item._acq_serial)
end

local function reasons_append(list, reason)
	list = list or {}
	list[#list + 1] = reason
	return list
end

local function clone_source_snapshot(snap, method)
	if type(snap) ~= "table" then
		return nil
	end
	return {
		generation_id = snap.generation_id,
		collectible_id = snap.collectible_id,
		init_seed = snap.init_seed,
		drop_seed = snap.drop_seed,
		pickup_ptr = snap.pickup_ptr,
		player_index = snap.player_index,
		room_list_index = snap.room_list_index,
		safe_grid = snap.safe_grid,
		dimension = snap.dimension,
		floor_key = snap.floor_key,
		observed_frame = snap.observed_frame,
		attribution_method = method or snap.attribution_method,
	}
end

local function room_matches_snapshot(snap)
	if type(snap) ~= "table" then
		return false
	end
	local room = room_identity()
	if snap.room_list_index ~= nil and room.list_index ~= nil and snap.room_list_index ~= room.list_index then
		return false
	end
	if snap.dimension ~= nil and room.dimension ~= nil and snap.dimension ~= room.dimension then
		return false
	end
	if snap.floor_key ~= nil and room.floor_key ~= nil and snap.floor_key ~= room.floor_key then
		return false
	end
	return true
end

local function find_live_collectible_by_ptr(ptr)
	if not ptr then
		return nil
	end
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, -1, false, false)) do
		if ptr_of(ent) == ptr and entity_alive(ent) then
			return ent:ToPickup() or ent
		end
	end
	return nil
end

--- Queue bind. A single same-id collision is not confirmation.
--- Confirm only when that collided entity was removed or emptied, inside room and time window.
--- `ent` is a heuristic hint for old callers and is not evidence.
local function confirm_source_for_queue(player, id, _ent, heuristic_reasons)
	local pidx = player_index_of(player)
	local reasons = heuristic_reasons or {}
	local now = Game():GetFrameCount()
	local by_ptr = pidx and item._acq_candidates[pidx] or nil
	local diagnostics = {}
	local taken = {}

	if type(by_ptr) == "table" then
		for _, cand in pairs(by_ptr) do
			local snap = cand and cand.source_snapshot
			local state = "rejected"
			if not snap then
				state = "no_snapshot"
			elseif tonumber(cand.collectible_id) ~= tonumber(id) or (snap.collectible_id and tonumber(snap.collectible_id) ~= tonumber(id)) then
				state = "id_mismatch"
			elseif snap.player_index ~= nil and pidx ~= nil and tostring(snap.player_index) ~= tostring(pidx) then
				state = "player_mismatch"
			elseif not room_matches_snapshot(snap) then
				state = "room_mismatch"
			elseif now - (cand.last_collision_frame or cand.first_collision_frame or now) > ACQ_QUEUE_WINDOW then
				state = "outside_window"
			elseif snap.generation_id == nil and snap.pickup_ptr == nil and snap.init_seed == nil then
				state = "no_identity"
			else
				local live = snap.pickup_ptr and find_live_collectible_by_ptr(snap.pickup_ptr) or nil
				if not snap.pickup_ptr then
					state = "no_pointer"
				elseif not live then
					state = "removed"
				elseif snap.init_seed and live.InitSeed ~= snap.init_seed then
					state = "identity_break"
				else
					local subtype = tonumber(live.SubType) or 0
					if subtype <= 0 then
						state = "emptied"
					elseif subtype ~= tonumber(id) then
						state = "replaced"
					else
						state = "still_offer"
					end
				end
			end
			if state ~= "id_mismatch" and state ~= "player_mismatch" then
				diagnostics[#diagnostics + 1] = {
					state = state,
					generation_id = snap and snap.generation_id or nil,
					pickup_ptr = snap and snap.pickup_ptr or nil,
				}
			end
			if state == "removed" or state == "emptied" then
				taken[#taken + 1] = { snap = snap, state = state }
			end
		end
	end

	local confirmed, method = nil, nil
	if #taken == 1 then
		method = taken[1].state == "removed" and "collision_and_removed" or "collision_and_emptied"
		confirmed = clone_source_snapshot(taken[1].snap, method)
	elseif #taken > 1 then
		method = "ambiguous"
		reasons = reasons_append(reasons, "multiple_taken_candidates")
	else
		method = "unconfirmed"
		reasons = reasons_append(reasons, "no_taken_candidate")
	end
	return confirmed, method, diagnostics, reasons
end

local function open_acquisition_txn(player, id, source_snapshot, meta)
	meta = meta or {}
	local aid = new_acquisition_id()
	local pidx = player_index_of(player)
	local txn = {
		acquisition_id = aid,
		player_index = pidx,
		collectible_id = tonumber(id),
		source_snapshot = source_snapshot,
		state = "QUEUED",
		opened_frame = Game():GetFrameCount(),
		heuristic_reasons = meta.heuristic_reasons,
		attribution_method = source_snapshot and source_snapshot.attribution_method or nil,
		live_pedestal_ptr = source_snapshot and source_snapshot.pickup_ptr or nil,
		consumed = false,
	}
	item._acq_txns[aid] = txn
	if pidx ~= nil then
		item._acq_by_player[pidx] = aid
	end
	return txn
end

--- Only the txn currently bound to this player. Never the newest same-id leftover.
local function find_open_txn_for_gain(player, gained_id)
	local pidx = player_index_of(player)
	local aid = pidx and item._acq_by_player[pidx] or nil
	local txn = aid and item._acq_txns[aid] or nil
	if not txn or txn.consumed or txn.state ~= "QUEUED" then
		return nil
	end
	if tostring(txn.player_index) ~= tostring(pidx) then
		return nil
	end
	if tonumber(txn.collectible_id) ~= tonumber(gained_id) then
		return nil
	end
	return txn
end

local function push_explicit_bind(player, id, source)
	local pidx = player_index_of(player)
	if pidx == nil then
		return
	end
	item._explicit_binds[pidx] = item._explicit_binds[pidx] or {}
	local q = item._explicit_binds[pidx]
	q[#q + 1] = {
		id = tonumber(id) or 0,
		source = source and clone_source_snapshot(source, source.attribution_method or "explicit_programmatic") or nil,
		frame = Game():GetFrameCount(),
	}
end

--- FIFO explicit programmatic bind. found=false means there was no bind.
local function take_explicit_bind(player, gained_id)
	local pidx = player_index_of(player)
	local q = pidx and item._explicit_binds[pidx] or nil
	if type(q) ~= "table" then
		return nil, false
	end
	local now = Game():GetFrameCount()
	for i = #q, 1, -1 do
		if now - (q[i].frame or now) > ACQ_QUEUE_WINDOW then
			table.remove(q, i)
		end
	end
	for i = 1, #q do
		if tonumber(q[i].id) == tonumber(gained_id) then
			local source = q[i].source
			table.remove(q, i)
			return source, true
		end
	end
	return nil, false
end

local function live_pedestal_from_snapshot(snap)
	if not snap or not snap.pickup_ptr then
		return nil
	end
	local ent = find_live_collectible_by_ptr(snap.pickup_ptr)
	if not ent then
		return nil
	end
	if snap.init_seed and ent.InitSeed ~= snap.init_seed then
		return nil
	end
	if snap.generation_id then
		local gid = snapshot_generation_id(ent, nil)
		local subtype = tonumber(ent.SubType) or 0
		if gid == nil then
			-- Empty shell may not expose generation. Same ptr + InitSeed is the continuation.
			-- A still-filled pedestal with no readable generation is not that continuation.
			if subtype > 0 then
				return nil
			end
		elseif tostring(gid) ~= tostring(snap.generation_id) then
			return nil
		end
	end
	return ent
end

local function build_gain_context_v2(player, gained_id, mode)
	prune_acq_runtime()
	mode = mode or "queue"
	local txn = nil
	local source = nil
	if mode == "queue" then
		txn = find_open_txn_for_gain(player, gained_id)
		source = txn and txn.source_snapshot or nil
	else
		-- direct gift and simulate must not inherit a nearby queue txn.
		local bound_source, found = take_explicit_bind(player, gained_id)
		if found then
			source = bound_source
		end
	end
	if source and not TRUSTED_SOURCE_METHODS[source.attribution_method] then
		source = nil
	end
	local live = source and live_pedestal_from_snapshot(source) or nil
	local acquisition_id = txn and txn.acquisition_id or new_acquisition_id()
	if txn then
		txn.state = "GAIN_CONFIRMED"
		txn.consumed = true
		txn.closed_frame = Game():GetFrameCount()
		local pidx = player_index_of(player)
		if pidx ~= nil and item._acq_by_player[pidx] == txn.acquisition_id then
			item._acq_by_player[pidx] = nil
		end
	end
	local ctx = {
		version = 2,
		id = tonumber(gained_id) or 0,
		acquisition_id = acquisition_id,
		source = source,
		generation_id = source and source.generation_id or nil,
		attribution = source and "confirmed" or "unavailable",
		attribution_method = source and source.attribution_method or nil,
		pedestal = live,
		pickup = live,
	}
	local pidx = player_index_of(player)
	if pidx ~= nil then
		item._last_gain_context[pidx] = {
			version = 2,
			id = ctx.id,
			acquisition_id = acquisition_id,
			source = source,
			generation_id = ctx.generation_id,
			pedestal = live,
			pickup = live,
			frame = Game():GetFrameCount(),
		}
	end
	return ctx
end

--- Record the pedestal/pickup that produced the current queued collectible gain.
--- Runtime only. Prefer gain_context argument on POST_GAIN_COLLECTIBLE for new consumers.
function item.set_last_gain_context(player, ctx)
	if not player then
		return
	end
	local idx = player:GetData().__Index
	if idx == nil then
		return
	end
	ctx = ctx or {}
	local source = ctx.source
	if source and not TRUSTED_SOURCE_METHODS[source.attribution_method] then
		source = nil
	end
	local live = source and live_pedestal_from_snapshot(source) or nil
	item._last_gain_context[idx] = {
		version = 2,
		pickup = live,
		pedestal = live,
		id = tonumber(ctx.id) or 0,
		generation_id = source and source.generation_id or nil,
		source = source,
		attribution = source and "confirmed" or "unavailable",
		attribution_method = source and source.attribution_method or nil,
		acquisition_id = ctx.acquisition_id,
		frame = Game():GetFrameCount(),
	}
end

function item.get_last_gain_context(player)
	if not player then
		return nil
	end
	local idx = player:GetData().__Index
	if idx == nil then
		return nil
	end
	return item._last_gain_context[idx]
end

--- Read-only view of the current bound txn. Does not consume it and does not reuse last context.
function item.resolve_gain_context(player, gained_id)
	gained_id = tonumber(gained_id) or 0
	local txn = find_open_txn_for_gain(player, gained_id)
	local source = txn and txn.source_snapshot or nil
	if source and not TRUSTED_SOURCE_METHODS[source.attribution_method] then
		source = nil
	end
	local live = source and live_pedestal_from_snapshot(source) or nil
	return {
		version = 2,
		id = gained_id,
		acquisition_id = txn and txn.acquisition_id or nil,
		source = source,
		generation_id = source and source.generation_id or nil,
		attribution = source and "confirmed" or "unavailable",
		attribution_method = source and source.attribution_method or nil,
		pedestal = live,
		pickup = live,
	}
end

function item.clear_last_gain_context(player)
	if not player then
		return
	end
	local idx = player:GetData().__Index
	if idx == nil then
		return
	end
	item._last_gain_context[idx] = nil
end

function item.get_acquisition_source(gain_context)
	if type(gain_context) ~= "table" then
		return nil
	end
	local source = gain_context.source
	if type(source) ~= "table" then
		return nil
	end
	if not TRUSTED_SOURCE_METHODS[source.attribution_method] then
		return nil
	end
	if source.generation_id == nil and source.pickup_ptr == nil and source.init_seed == nil then
		return nil
	end
	return source
end

function item.get_live_source_pedestal(gain_context)
	local source = item.get_acquisition_source(gain_context)
	if not source then
		return nil
	end
	return live_pedestal_from_snapshot(source)
end

local function build_source_context(player, id, ent, heuristic_reasons)
	local source, method, filtered, reasons = confirm_source_for_queue(player, id, ent, heuristic_reasons)
	local txn = open_acquisition_txn(player, id, source, { heuristic_reasons = reasons })
	local live = nil
	if source then
		live = live_pedestal_from_snapshot(source)
	end
	local attribution = "unavailable"
	if source then
		attribution = "confirmed"
	elseif filtered and #filtered > 0 then
		attribution = "candidate"
	end
	return {
		version = 2,
		source = source,
		pedestal = live,
		acquisition_id = txn.acquisition_id,
		attribution = attribution,
		attribution_method = method,
		heuristic_reasons = reasons,
		candidate_count = filtered and #filtered or 0,
	}
end

--- Canonical one-shot pickup presentation (NOT LiftItem holding UI).
--- Behavior reference: Item_Paranoia.lua — do not copy that consumer; call this API.
local function play_simulated_pickup_presentation(player, id, opts)
	opts = opts or {}
	if opts.animate ~= false and player.AnimateCollectible then
		player:AnimateCollectible(id, "Pickup", "PlayerPickupSparkle")
	end
	if opts.sound ~= false then
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_POWERUP1, 1, 1, false, 0, 2)
	end
	if opts.display ~= false and item_displaying_holder.display_item then
		item_displaying_holder.display_item(player, id)
	end
end

--- Programmatic collectible acquisition that should feel like a normal player pickup.
--- opts:
---   touched / first_time
---   charge (AddCollectible charge arg; default 0)
---   active_slot (optional; omit for vanilla default slot choice)
---   animate / display / sound (default true)
--- Returns false if args invalid; otherwise true after grant + presentation.
function item.simulate_pickup(player, id, opts)
	opts = opts or {}
	id = tonumber(id) or 0
	if not player or id <= 0 then
		return false
	end
	local cfg = Isaac.GetItemConfig():GetCollectible(id)
	if not cfg then
		return false
	end

	local touched = opts.touched == true
	local first_time = opts.first_time
	if first_time == nil then
		first_time = not touched
	end
	local charge = math.max(0, tonumber(opts.charge) or 0)
	local slot = opts.active_slot

	item.add_queued_data(player, id, touched)
	local explicit_source = nil
	if type(opts.source) == "table" then
		explicit_source = clone_source_snapshot(opts.source, "explicit_programmatic")
	elseif opts.pickup or opts.pedestal then
		explicit_source = capture_source_snapshot(player, opts.pedestal or opts.pickup, id, {
			attribution_method = "explicit_programmatic",
		})
	end
	push_explicit_bind(player, id, explicit_source)
	if slot ~= nil then
		player:AddCollectible(id, charge, first_time == true, slot)
	else
		player:AddCollectible(id, charge, first_time == true)
	end
	play_simulated_pickup_presentation(player, id, opts)
	return true
end

--- Exact ActiveSlot acquisition + split charge restore + normal Pickup presentation.
--- opts:
---   touched / first_time
---   slot / active_slot (required for non-PRIMARY restore; defaults SLOT_PRIMARY)
---   main_charge / battery_charge
---   animate / display / sound (default true)
--- Does NOT use LiftItem. Does NOT Remove any pedestal (caller commits carrier after success).
function item.simulate_active_pickup(player, id, opts)
	opts = opts or {}
	id = tonumber(id) or 0
	if not player or id <= 0 then
		return false
	end
	local cfg = Isaac.GetItemConfig():GetCollectible(id)
	if not cfg or cfg.Type ~= ItemType.ITEM_ACTIVE then
		return false
	end

	local touched = opts.touched == true
	local first_time = opts.first_time
	if first_time == nil then
		first_time = not touched
	end
	local slot = opts.slot
	if slot == nil then
		slot = opts.active_slot
	end
	if slot == nil then
		slot = ActiveSlot.SLOT_PRIMARY
	end
	local main = math.max(0, tonumber(opts.main_charge) or 0)
	local battery = math.max(0, tonumber(opts.battery_charge) or 0)

	item.add_queued_data(player, id, touched)
	local explicit_source = nil
	if type(opts.source) == "table" then
		explicit_source = clone_source_snapshot(opts.source, "explicit_programmatic")
	elseif opts.pickup or opts.pedestal then
		explicit_source = capture_source_snapshot(player, opts.pedestal or opts.pickup, id, {
			attribution_method = "explicit_programmatic",
		})
	end
	push_explicit_bind(player, id, explicit_source)
	player:AddCollectible(id, 0, first_time == true, slot)
	if player.AddActiveCharge then
		if main > 0 then
			player:AddActiveCharge(main, slot, false, false, true)
		end
		if battery > 0 then
			player:AddActiveCharge(battery, slot, false, true, true)
		end
	elseif player.SetActiveCharge then
		player:SetActiveCharge(main + battery, slot)
	end
	play_simulated_pickup_presentation(player, id, opts)
	return true
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	item.check_item_list()
	item.check_trinket_list()
	if continue then
	else
		save.elses.collectible_counter = {}
		save.elses.trinket_counter = {}
	end
	save.elses.collectible_counter = save.elses.collectible_counter or {}
	save.elses.trinket_counter = save.elses.trinket_counter or {}
	save.elses.collectible_queue_item = {}
	save.elses.pocket_item_counter = {}
end,
})

--[[
table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_INIT, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local idx = player:GetData().__Index
	if idx == nil then return end
	save.elses.collectible_counter[idx] = {num = player:GetCollectibleCount(),list = {},}
	for u,v in pairs(item.itemList) do
		if player:GetCollectibleNum(v, true) == 0 then save.elses.collectible_counter[idx].list[v] = nil
		else save.elses.collectible_counter[idx].list[v] = player:GetCollectibleNum(v,true) end
	end
end,
})
--]]
--
table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	save.elses.collectible_queue_item = save.elses.collectible_queue_item or {}
	save.elses.collectible_counter = save.elses.collectible_counter or {}
	save.elses.trinket_counter = save.elses.trinket_counter or {}
	if continue then
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
            local d = player:GetData()
			local idx = player:GetData().__Index
            save.elses.collectible_counter[idx] = {num = player:GetCollectibleCount(),list = {},}
			for u,v in pairs(item.itemList) do
				if player:GetCollectibleNum(v, true) == 0 then save.elses.collectible_counter[idx].list[v] = nil
				else save.elses.collectible_counter[idx].list[v] = player:GetCollectibleNum(v, true) end
			end
            save.elses.trinket_counter[idx] = {}
			for u,v in pairs(item.trinketList) do
				if player:GetTrinketMultiplier(v) ~= 0 then save.elses.trinket_counter[idx][v] = player:GetTrinketMultiplier(v)
				else save.elses.trinket_counter[idx][v] = nil end
			end
        end
    end
	--print("Filter Open")
	item.update_filter = true
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_,shouldsave)
	item.update_filter = nil
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = nil,
Function = function(_,pickup)
    if (pickup.Variant == PickupVariant.PICKUP_COLLECTIBLE) then
        local d = pickup:GetData()
		d.collectible_last_id = pickup.SubType
    end
end,
})

local function CheckCollectibleChanged(player)
    local d = player:GetData()
	local idx = player:GetData().__Index
    if save.elses.collectible_counter[idx].num ~= player:GetCollectibleCount() then
        return true
    end
	for u,v in pairs(item.itemList) do
        if (save.elses.collectible_counter[idx].list[v] or 0) ~= player:GetCollectibleNum(v, true) then
            return true
        end
    end
    return false
end

local function CheckTrinketChanged(player)
    local d = player:GetData()
	local idx = player:GetData().__Index
	save.elses.trinket_counter[idx] = save.elses.trinket_counter[idx] or {}
	for u,v in pairs(item.trinketList) do
		if player:GetTrinketMultiplier(v) ~= (save.elses.trinket_counter[idx][v] or 0) then return true end
	end
    return false
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	local d = player:GetData()
	local idx = d.__Index
    if item.update_filter then 
		if idx == nil then return end
		if not (save.PERSISTENT_PLAYER_DATA[idx] or {}).__META then save.PERSISTENT_PLAYER_DATA[idx].__META = {player = player,Seed = player.InitSeed,Frame = Isaac.GetFrameCount(),PlayerType = player:GetPlayerType(),} end
		if d[save.own_key.."check"] then
			if save.elses.collectible_counter[idx] and item.compare_player_data(idx,player) ~= true then
				save.PERSISTENT_PLAYER_DATA[idx].__META.player = nil
				save.PERSISTENT_PLAYER_DATA[idx].__META.Seed = save.PERSISTENT_PLAYER_DATA[idx].__META.Seeded or save.PERSISTENT_PLAYER_DATA[idx].__META.Seed
				save.add_player(player,"Check")
			else
				save.PERSISTENT_PLAYER_DATA[idx].__META.Seed = player.InitSeed
			end
			d[save.own_key.."check"] = nil
		end
		save.elses.collectible_counter[idx] = save.elses.collectible_counter[idx] or {num = 0,list = {},}
		if ((save.elses.collectible_queue_item[idx] and player:IsItemQueueEmpty()) or (CheckCollectibleChanged(player))) then
			save.elses.collectible_counter[idx].num = player:GetCollectibleCount()
			local queuedItem = save.elses.collectible_queue_item[idx]
			local changed = false
			for u,v in pairs(item.itemList) do
				local curNum = save.elses.collectible_counter[idx].list[v] or 0
				local num = player:GetCollectibleNum(v, true)
				local diff = num - curNum
				if (diff ~= 0) then
					if (diff > 0) then
						local gained = diff
						if queuedItem then
							if (v == queuedItem.Item and queuedItem.Type ~= ItemType.ITEM_TRINKET) then
								local gain_context = build_gain_context_v2(player, v, "queue")
								callback_manager.work("POST_GAIN_COLLECTIBLE",function(funct,params) if params == nil or params == v then funct(nil,player,v,1,queuedItem.Touched,curNum,false,gain_context) end end)
								gained = gained - 1
								save.elses.collectible_queue_item[idx] = nil
							end
						elseif save.elses[item.own_key.."record"] and #save.elses[item.own_key.."record"] > 0 then
							for i = #save.elses[item.own_key.."record"],1,-1 do
								local tv = save.elses[item.own_key.."record"][i]
								if math.abs(tv.frame - Game():GetFrameCount()) > 2 then
									table.remove(save.elses[item.own_key.."record"], i)
								else
									if tv.idx == idx and tv.id == v then
										local gain_context = build_gain_context_v2(player, v, "programmatic")
										callback_manager.work(
											"POST_GAIN_COLLECTIBLE",
											function(funct, params)
												if params == nil or params == v then
													funct(nil, player, v, 1, tv.touched, curNum, false, gain_context)
												end
											end
										)
										gained = gained - 1
										if gained <= 0 then
											break
										end
									end
								end
							end
						end
						if (gained > 0) then
							local gain_context = build_gain_context_v2(player, v, "direct")
							callback_manager.work("POST_GAIN_COLLECTIBLE",function(funct,params) if params == nil or params == v then funct(nil,player,v,gained,false,curNum,true,gain_context) end end)
						end
					else
						callback_manager.work("POST_LOSE_COLLECTIBLE",function(funct,params) if params == nil or params == v then funct(nil,player,v,-diff,curNum) end end)
					end
					callback_manager.work("POST_CHANGE_COLLECTIBLE",function(funct,params) if params == nil or params == v then funct(nil,player,v,diff,curNum) end end)
					save.elses.collectible_counter[idx].list[v] = num
					if num == 0 then save.elses.collectible_counter[idx].list[v] = nil end
					changed = true
				end
			end
			if changed then	callback_manager.work("POST_CHANGE_ALL_COLLECTIBLE",function(funct,params) funct(nil,player) end) end
			
        end
        if (save.elses.collectible_queue_item[idx] and player:IsItemQueueEmpty()) then 
            save.elses.collectible_queue_item[idx] = nil
        end
    end
end,
})

function item.tk_work()
	if item.Tkcnt == nil then
		item.Tkcnt = true
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			item.Do_Update(player)
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = EntityType.ENTITY_PICKUP,
Function = function(_,ent)
	if ent.Variant == 350 then
		table.insert(item.trinket_at_hand,{ID = ent.SubType,})
		if Game():GetRoom():GetFrameCount() == 0 and ent.FrameCount == 0 then item.tk_work() end
    end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
    for i = #(item.trinket_at_hand),1,-1 do
		local v = item.trinket_at_hand[i]
        if v.should_remove then	table.remove(item.trinket_at_hand,i)
        else v.should_remove = true end 
    end
	if Game():GetRoom():GetFrameCount() ~= 0 and item.Tkcnt ~= nil then item.Tkcnt = nil end
end,
})

function item.Do_Update(player)
	if (item.update_filter) then
		local d = player:GetData()
		local idx = player:GetData().__Index
        if (not player:IsItemQueueEmpty()) then
            if (not save.elses.collectible_queue_item[idx]) then
                local queued = player.QueuedItem
				local id = queued.Item.ID
				save.elses.collectible_queue_item[idx] = {Item = id,Type = queued.Item.Type,Touched = queued.Touched,}
				if (queued.Item.Type == ItemType.ITEM_TRINKET) then
					for u,v in pairs(item.trinket_at_hand) do
						if (v.ID == id or v.ID - 32768 == id) then
							callback_manager.work("POST_PICKUP_TRINKET",function(funct,params) if params == nil or params == id then funct(nil,player,id,id > 32768,queued.Touched) end end)
							table.remove(item.trinket_at_hand,u)
							local v = id % 32768
							if player:GetTrinketMultiplier(v) == ((save.elses.trinket_counter[idx] or {})[v] or 0) then
								local num = player:GetTrinketMultiplier(v)
								local diff = auxi.judge_by_trinket(player,id > 32768)
								diff = math.min(diff,num)
								callback_manager.work("POST_LOSE_TRINKET",function(funct,params) if params == nil or params == v then funct(nil,player,v,diff,num) end end)
								callback_manager.work("POST_CHANGE_TRINKET",function(funct,params) if params == nil or params == v then funct(nil,player,v,-diff,num) end end)
								callback_manager.work("POST_GAIN_TRINKET",function(funct,params) if params == nil or params == v then funct(nil,player,v,1,queued.Touched,num - diff,true,id > 32768,diff) end end)
								callback_manager.work("POST_CHANGE_TRINKET",function(funct,params) if params == nil or params == v then funct(nil,player,v,diff,num - diff) end end)
							end
							break
						end
					end
				else
					-- Acquisition Context V2: heuristics discover candidates; only confirmed identity binds source.
					local best_ent = nil
					local heuristic_reasons = {}
					for i,ent in pairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)) do
						local d2 = ent:GetData()
						local idMatches = (d2 and d2.collectible_last_id == id)
						local swapped = ent.FrameCount <= 0
						local taken = (ent.SubType <= 0 and idMatches) or not ent:Exists()
						if swapped then
							heuristic_reasons[#heuristic_reasons + 1] = "new_entity_frame"
						end
						if taken then
							heuristic_reasons[#heuristic_reasons + 1] = "taken_or_empty_last_id"
						end
						if (swapped or taken) and not best_ent then
							best_ent = ent
						end
					end
					local source_context = build_source_context(player, id, best_ent, heuristic_reasons)
					local compat_ent = source_context.pedestal or (best_ent and entity_alive(best_ent) and best_ent) or best_ent
					item.set_last_gain_context(player, {
						pickup = source_context.pedestal,
						pedestal = source_context.pedestal,
						id = id,
						source = source_context.source,
						acquisition_id = source_context.acquisition_id,
						generation_id = source_context.source and source_context.source.generation_id or nil,
					})
					callback_manager.work("POST_PICKUP_COLLECTIBLE", function(funct, params)
						if params == nil or params == id then
							funct(nil, player, id, queued.Touched, compat_ent, source_context)
						end
					end)
				end
            end
        end
		local queuedItem = save.elses.collectible_queue_item[idx]
		if CheckTrinketChanged(player) then
			local changed = nil
			for u,v in pairs(item.trinketList) do
				if (save.elses.trinket_counter[idx][v] or 0) ~= player:GetTrinketMultiplier(v) then
					local curNum = save.elses.trinket_counter[idx][v] or 0
					local num = player:GetTrinketMultiplier(v)
					local diff = num - curNum
					if (diff ~= 0) then
						if (diff > 0) then
							local gained = diff
							if queuedItem and v == queuedItem.Item % 32768 and queuedItem.Type == ItemType.ITEM_TRINKET then
								callback_manager.work("POST_GAIN_TRINKET",function(funct,params) if params == nil or params == v then funct(nil,player,v,1,queuedItem.Touched,curNum,true,queuedItem.Item > 32768,gained) end end)
								gained = 0
								--save.elses.collectible_queue_item[idx] = nil
							end
							if (gained > 0) then
								callback_manager.work("POST_GAIN_TRINKET",function(funct,params) if params == nil or params == v then funct(nil,player,v,gained,false,curNum,false) end end)
							end
						else
							callback_manager.work("POST_LOSE_TRINKET",function(funct,params) if params == nil or params == v then funct(nil,player,v,-diff,curNum) end end)
						end
						callback_manager.work("POST_CHANGE_TRINKET",function(funct,params) if params == nil or params == v then funct(nil,player,v,diff,curNum) end end)
					end
					save.elses.trinket_counter[idx][v] = num
					changed = true
				end
			end
			if changed then	callback_manager.work("POST_CHANGE_ALL_TRINKET",function(funct,params) funct(nil,player) end) end
		end
		if not REPENTOGON and save.elses.pocket_item_counter[idx] ~= nil then
			for u,ent in pairs(save.elses.pocket_item_counter[idx]) do
				if (not ent:Exists() or ent:IsDead()) then
					for i = 0,3 do
						local tg = player:GetCard(i)
						if ent.Variant == 70 then tg = player:GetPill(i) end
						if (tg and tg == ent.SubType) then
							callback_manager.work("POST_PICKUP_POCKET_ITEM",function(funct,params) if params == nil or params == tg then funct(nil,player,ent.Variant,ent.SubType) end end)		--这里不管重复的编号。
							break
						end
					end
				end
			end
			save.elses.pocket_item_counter[idx] = nil
		end
		save.elses[item.own_key.."Pocket_Reminder"] = save.elses[item.own_key.."Pocket_Reminder"] or {}
		save.elses[item.own_key.."Pocket_Reminder"][idx] = save.elses[item.own_key.."Pocket_Reminder"][idx] or {}
		local tbl = {}
		for i = 0,3 do
			local cid = player:GetCard(i)
			if cid > 0 then tbl[cid] = (tbl[cid] or 0) + 1 end
			local pid = player:GetPill(i)
			if pid > 0 then tbl[-pid] = (tbl[-pid] or 0) + 1 end
		end
		if auxi.EqualTable(tbl,save.elses[item.own_key.."Pocket_Reminder"][idx]) ~= true then
			callback_manager.work("POST_CHANGE_POCKET_ITEM",function(funct,params) funct(nil,player,save.elses[item.own_key.."Pocket_Reminder"][idx]) end)
			save.elses[item.own_key.."Pocket_Reminder"][idx] = tbl
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	item.Do_Update(player)
end,
})
--[[
table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GET_TELEPORT, params = "door",
Function = function(_,player,tp,data)
	delay_buffer.addeffe(function(params)
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			item.Do_Update(player)
		end
	end,{},6,true)
end,
})
--]]
table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = nil,
Function = function(_,ent, col, low)
	if REPENTOGON then return end
	if ent.Variant == 300 or ent.Variant == 70 then
		local player = col:ToPlayer()
		if player then
			local d = player:GetData()
			local idx = player:GetData().__Index
			save.elses.pocket_item_counter[idx] = save.elses.pocket_item_counter[idx] or {}
			table.insert(save.elses.pocket_item_counter[idx],ent)
			if player:GetPlayerType() == PlayerType.PLAYER_THESOUL_B then 		--里骨需要特判？
				for playerNum = 1, Game():GetNumPlayers() do
					local t_player = Game():GetPlayer(playerNum - 1)
					if t_player:GetPlayerType() == PlayerType.PLAYER_THEFORGOTTEN_B then 
						local idx = t_player:GetData().__Index
						save.elses.pocket_item_counter[idx] = save.elses.pocket_item_counter[idx] or {}
						table.insert(save.elses.pocket_item_counter[idx],ent)
					end
				end
			end
		end
		--if Game():GetRoom():GetFrameCount() == 0 and ent.FrameCount == 0 then item.tk_work() end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function()
	if item.should_recharge then
		 for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
            local d = player:GetData()
			local idx = player:GetData().__Index
			save.elses.collectible_counter[idx] = save.elses.collectible_counter[idx] or {num = 0,list = {},}
            save.elses.collectible_counter[idx].num = player:GetCollectibleCount()
			for u,v in pairs(item.itemList) do
				if player:GetCollectibleNum(v, true) == 0 then save.elses.collectible_counter[idx].list[v] = nil
				else save.elses.collectible_counter[idx].list[v] = player:GetCollectibleNum(v, true) end
			end
        end
		item.should_recharge = nil
		item.update_filter = true
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = CollectibleType.COLLECTIBLE_GLOWING_HOUR_GLASS,
Function = function(_, colid, rng, player, flags, slot, data)
	item.should_recharge = true
	item.update_filter = nil
end,
})


table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION,
	params = PickupVariant.PICKUP_COLLECTIBLE,
	priority = 50,
	Function = function(_, pickup, collider, _)
		local player = collider and collider.ToPlayer and collider:ToPlayer()
		if not player or not pickup then
			return nil
		end
		item.observe_pickup_collision_candidate(player, pickup)
		return nil
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		-- Drop unfinished acquisition runtime across rooms (no cross-room pickup completion).
		item._acq_candidates = {}
		item._explicit_binds = {}
		for aid, txn in pairs(item._acq_txns) do
			if txn and txn.state ~= "COMMITTED" and txn.consumed ~= true then
				txn.state = "CANCELLED"
				txn.closed_frame = Game():GetFrameCount()
			end
		end
		item._acq_by_player = {}
	end,
})


return item
