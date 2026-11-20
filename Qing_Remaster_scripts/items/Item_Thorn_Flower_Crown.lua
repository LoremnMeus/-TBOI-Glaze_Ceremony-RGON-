-- 荆棘花冠：普通底座有一次资格判定。刺长在底座上，接触且不在受伤无敌帧里就尝试伤害。
-- 第一次伤害尝试后染血。染血底座稳定空置后只孕育一件究极隐藏池道具。
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local collectible_holder = require("Qing_Remaster_scripts.callbacks.collectible_holder")
local consistance = require("Qing_Remaster_scripts.others.Consistance_holder")
local morph_txn = require("Qing_Remaster_scripts.others.Pickup_Morph_Transaction_holder")
local pedestal_encounter = require("Qing_Remaster_scripts.others.Pedestal_Encounter_holder")
local unique = require("Qing_Remaster_scripts.others.Unique_holder")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Thorn_Flower_Crown,
	own_key = "Item_Thorn_Flower_Crown_",
	-- 临时数值集中在这里。品质与道具池在 items.xml / itempools.xml。
	thorn_chance = 0.40,
	damage = 1,
	bloom_frames = 42,
	-- Alternates 第 0 帧的 altar 层裁切是 (0,0) 的 32×32。两张图都画在这个位置上。
	altar_sheet_thorn = "gfx/items/Thorn_altar_thorn.png",
	altar_sheet_bloody = "gfx/items/Thorn_altar_bloody.png",
	altar_frame = 0,
	bloom_anm2 = "gfx/items/Thorn_bloom.anm2",
	_trace = {},
	_morph_frame = {},
	_preview = {},
	_sting_frame = {},
}

local HOLD = { ignore_subtype = true, consistance = true }
local TRACE_LIMIT = 40

local function game_frame()
	return Game():GetFrameCount()
end

local function trace(kind, pickup, detail)
	local row = {
		kind = kind,
		frame = game_frame(),
		detail = detail or "",
		subtype = pickup and pickup.SubType or nil,
		init_seed = pickup and pickup.InitSeed or nil,
	}
	item._trace[#item._trace + 1] = row
	while #item._trace > TRACE_LIMIT do
		table.remove(item._trace, 1)
	end
end

function item.copy_trace()
	return auxi.deepCopy(item._trace)
end

local function fresh_state()
	return {
		eligibility = "UNDECIDED",
		ritual = "NONE",
		roll_count = 0,
		bloom_count = 0,
		born_from_bloom = false,
	}
end

local function read_state(pickup)
	if not pickup then
		return nil
	end
	consistance.try_check_entity(pickup, item.own_key, false, HOLD)
	local data = pickup:GetData()
	local payload = data._Data and data._Data[item.own_key]
	if type(payload) ~= "table" then
		return nil
	end
	return payload
end

local function write_state(pickup, state)
	local data = pickup:GetData()
	data._Data = data._Data or {}
	data._Data[item.own_key] = state
	consistance.try_hold_entity(pickup, item.own_key, HOLD)
	return state
end

local function ensure_state(pickup)
	local state = read_state(pickup)
	if state then
		return state
	end
	return write_state(pickup, fresh_state())
end

--- Idle/Empty 的 altar 层在 anm2 里没有独立帧，默认是 32×32、(0,0) 的基础底座。
--- ShopIdle 与心之交易价格不是这一帧。层尺寸大于 32 时是 Alternates 里的特殊底座。
local function is_basic_altar(pickup)
	local sprite = pickup:GetSprite()
	if not sprite or not sprite.GetAnimation then
		return false
	end
	local anim = sprite:GetAnimation()
	if anim ~= "Idle" and anim ~= "Empty" then
		return false
	end
	if (tonumber(pickup.Price) or 0) < 0 then
		return false
	end
	local layer = sprite:GetLayer("altar")
	if not layer or not layer.GetSize then
		local data = pickup:GetData()
		if not data[item.own_key .. "altar_unread"] then
			data[item.own_key .. "altar_unread"] = true
			trace("altar_unreadable", pickup, anim)
		end
		return false
	end
	local size = layer:GetSize()
	if not size then
		local data = pickup:GetData()
		if not data[item.own_key .. "altar_unread"] then
			data[item.own_key .. "altar_unread"] = true
			trace("altar_unreadable", pickup, anim)
		end
		return false
	end
	local width = tonumber(size.X) or 0
	if width > 33 then
		return false
	end
	if width > 0 and layer.GetCropOffset then
		local crop = layer:GetCropOffset()
		if crop and (math.abs(crop.X) > 1 or math.abs(crop.Y) > 1) then
			return false
		end
	end
	return true
end

local function holder_player()
	return auxi.have_player_has_collectible(item.entity)
end

local function morph_open(pickup)
	local seed = pickup and pickup.InitSeed
	return seed ~= nil and item._morph_frame[seed] == game_frame()
end

local function consider_roll(pickup, reason)
	if not pickup or pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then
		return
	end
	if (tonumber(pickup.SubType) or 0) <= 0 then
		return
	end
	if morph_txn.has_open_pre_targeting(pickup) or morph_open(pickup) then
		return
	end
	local state = read_state(pickup)
	if state and state.born_from_bloom == true then
		return
	end
	if state and (tonumber(state.roll_count) or 0) >= 1 then
		return
	end
	if not is_basic_altar(pickup) then
		if not state then
			write_state(pickup, fresh_state())
		end
		return
	end
	if not holder_player() then
		if not state then
			write_state(pickup, fresh_state())
		end
		return
	end
	state = state or fresh_state()
	local player = holder_player()
	local rng = player and player:GetCollectibleRNG(item.entity)
	state.roll_count = 1
	if rng and rng:RandomFloat() < item.thorn_chance then
		state.eligibility = "ROLLED_SUCCESS"
		state.ritual = "THORN"
	else
		state.eligibility = "ROLLED_FAILED"
		state.ritual = "NONE"
	end
	write_state(pickup, state)
	trace("roll", pickup, reason .. ":" .. state.eligibility)
end

local function altar_look(state)
	local ritual = state and state.ritual
	if ritual == "THORN" then
		return "THORN", item.altar_sheet_thorn
	end
	if ritual == "BLOODY" or ritual == "BLOOMING" or ritual == "DONE" then
		return "BLOODY", item.altar_sheet_bloody
	end
	return nil, nil
end

local function apply_altar(pickup, state)
	local look, sheet = altar_look(state)
	if not look or not sheet then
		return
	end
	local sprite = pickup:GetSprite()
	if not sprite then
		return
	end
	local data = pickup:GetData()
	local anim = sprite.GetAnimation and sprite:GetAnimation() or ""
	local frame = sprite.GetFrame and sprite:GetFrame() or 0
	local cached = data[item.own_key .. "visual"]
	if type(cached) == "table"
		and cached.look == look
		and cached.anim == anim
		and (tonumber(cached.frame) or 0) <= frame
	then
		cached.frame = frame
		return
	end
	sprite:ReplaceSpritesheet(5, sheet)
	sprite:LoadGraphics()
	sprite:SetOverlayFrame("Alternates", item.altar_frame)
	data[item.own_key .. "visual"] = { look = look, anim = anim, frame = frame }
end

local bloom_sprite = nil

local function unit_range(value)
	if value < 0 then
		return 0
	end
	if value > 1 then
		return 1
	end
	return value
end

local function bloom_parts()
	if bloom_sprite then
		return bloom_sprite
	end
	local sprite = Sprite()
	sprite:Load(item.bloom_anm2, true)
	bloom_sprite = sprite
	return sprite
end

local function paint_part(sprite, anim, pos, scale, alpha)
	if alpha <= 0 then
		return
	end
	sprite:SetFrame(anim, 0)
	sprite.Scale = Vector(scale, scale)
	sprite.Color = Color(1, 1, 1, alpha, 0, 0, 0)
	sprite:Render(pos)
end

local function reward_preview(reward_id)
	reward_id = tonumber(reward_id) or 0
	if reward_id <= 0 then
		return nil
	end
	local key = tostring(reward_id)
	local cached = item._preview[key]
	if cached then
		return cached
	end
	local config = Isaac.GetItemConfig():GetCollectible(reward_id)
	if not config or not config.GfxFileName or config.GfxFileName == "" then
		return nil
	end
	local sprite = Sprite()
	sprite:Load("gfx/005.100_collectible.anm2", true)
	sprite:ReplaceSpritesheet(1, config.GfxFileName)
	sprite:LoadGraphics()
	sprite:SetFrame("Idle", 0)
	for _, name in ipairs({ "altar", "shadow", "body", "itemshadow", "sparkle" }) do
		local layer = sprite:GetLayer(name)
		if layer and layer.SetVisible then
			layer:SetVisible(false)
		end
	end
	item._preview[key] = sprite
	return sprite
end

local BLOOM_FEEDS = {
	{ x = -14, y = 8, delay = 0 },
	{ x = 13, y = 10, delay = 2 },
	{ x = -4, y = 12, delay = 4 },
}

local function main_bead(elapsed)
	if elapsed <= 7 then
		return 0, 8 - elapsed * 0.7, elapsed < 4 and "Pool" or "Orb", 1, 1
	end
	if elapsed <= 19 then
		local rise = (elapsed - 8) / 11
		local scale = 1
		if elapsed >= 12 then
			scale = 1.06
		end
		if elapsed >= 16 then
			scale = 1.12
		end
		return 0, 3 + (-25 * rise), "Orb", scale, 1
	end
	if elapsed <= 28 then
		local scale = 1.12
		if elapsed >= 23 and elapsed <= 25 then
			scale = 1.2
		elseif elapsed >= 26 then
			scale = 1.14
		end
		return 0, -22, "Orb", scale, 1
	end
	local fade = unit_range((elapsed - 29) / 12)
	return 0, -22, "Crack", 1.14 - 0.2 * fade, 1 - fade
end

local function render_blood(pickup, state, callback_offset)
	local timer = tonumber(state.bloom_timer) or 0
	local span = item.bloom_frames
	if timer <= 0 or span <= 0 then
		return
	end
	local elapsed = span - timer
	local base = Isaac.WorldToRenderPosition(pickup.Position + (pickup.PositionOffset or Vector.Zero))
		+ (callback_offset or Vector.Zero)
	-- Idle 第 0 帧图标：YPosition=-6，YPivot=32，中心在底座上方 22 像素。
	local sprite = bloom_parts()
	local mx, my, anim, scale, alpha = main_bead(elapsed)
	local main_pos = base + Vector(mx, my)
	if elapsed >= 8 and elapsed <= 19 then
		for _, feed in ipairs(BLOOM_FEEDS) do
			local travel = unit_range((elapsed - 8 - feed.delay) / 8)
			if elapsed >= 8 + feed.delay and travel < 1 then
				local arc = (1 - travel) * travel * -8
				paint_part(
					sprite,
					"Drop",
					base + Vector(feed.x * (1 - travel), feed.y + (my - feed.y) * travel + arc),
					1,
					1 - travel
				)
			end
		end
	end
	paint_part(sprite, anim, main_pos, scale, alpha)
	if elapsed >= 29 then
		local preview = reward_preview(tonumber(state.reward_id) or 0)
		if preview then
			preview.Color = Color(1, 1, 1, unit_range((elapsed - 29) / 12), 0, 0, 0)
			preview:Render(base)
		end
	end
end

local function begin_bloom(pickup, state)
	local player = holder_player()
	local rng = player and player:GetCollectibleRNG(item.entity) or pickup:GetDropRNG()
	local seed = rng:Next()
	local reward = Game():GetItemPool():GetCollectible(ItemPoolType.POOL_ULTRA_SECRET, true, seed)
	reward = tonumber(reward) or 0
	if reward <= 0 then
		state.ritual = "BLOODY"
		state.bloom_failed = true
		write_state(pickup, state)
		trace("bloom_failed", pickup, "empty_pool")
		return
	end
	state.ritual = "BLOOMING"
	state.reward_id = reward
	state.bloom_timer = item.bloom_frames
	state.bloom_count = 1
	write_state(pickup, state)
	trace("bloom_start", pickup, tostring(reward))
end

local function seal_bloom(pickup, state, reward)
	local restored = read_state(pickup) or state
	restored.ritual = "DONE"
	restored.born_from_bloom = true
	restored.bloom_count = 1
	restored.bloom_retry = nil
	restored.bloom_timer = 0
	restored.reward_id = reward
	restored.roll_count = math.max(1, tonumber(restored.roll_count) or 1)
	write_state(pickup, restored)
	trace("bloom_done", pickup, tostring(reward))
end

local function finish_bloom(pickup, state)
	local reward = tonumber(state.reward_id) or 0
	if reward <= 0 or not pickup or not pickup:Exists() then
		return
	end
	if (tonumber(pickup.SubType) or 0) == reward then
		seal_bloom(pickup, state, reward)
		return
	end
	if (tonumber(pickup.SubType) or 0) > 0 then
		return
	end
	state.bloom_timer = 0
	write_state(pickup, state)
	pedestal_encounter.with_suppressed_encounter(item.own_key, function()
		auxi.self_morph(pickup, {
			EntityType.ENTITY_PICKUP,
			PickupVariant.PICKUP_COLLECTIBLE,
			reward,
		})
	end)
	if not pickup:Exists() then
		trace("bloom_failed", nil, "removed")
		return
	end
	if (tonumber(pickup.SubType) or 0) ~= reward then
		if state.bloom_retry ~= true then
			state.bloom_retry = true
			state.ritual = "BLOOMING"
			state.bloom_timer = 1
			state.born_from_bloom = false
			write_state(pickup, state)
			trace("bloom_retry", pickup, "morph")
			return
		end
		state.ritual = "BLOODY"
		state.bloom_failed = true
		state.bloom_timer = 0
		state.born_from_bloom = false
		state.bloom_count = 1
		write_state(pickup, state)
		trace("bloom_failed", pickup, "morph")
		return
	end
	pickup.OptionsPickupIndex = 0
	pickup.Price = 0
	if pickup.ShopItemId ~= nil then
		pickup.ShopItemId = -1
	end
	if pickup.AutoUpdatePrice ~= nil then
		pickup.AutoUpdatePrice = false
	end
	seal_bloom(pickup, state, reward)
end

local function morph_blocked(pickup)
	return morph_txn.has_open_pre_targeting(pickup) or morph_open(pickup)
end

local function settled_empty(pickup, state)
	if morph_blocked(pickup) or state.empty_pending == true then
		return false
	end
	local confirmed = unique.confirm_stable_empty(pickup)
	return type(confirmed) == "table" and confirmed.confirmed == true
end

local function note_trusted_empty(context)
	local pedestal = collectible_holder.get_live_source_pedestal(context)
	if not pedestal or not pedestal.Exists or not pedestal:Exists() then
		return
	end
	local pickup = pedestal.ToPickup and pedestal:ToPickup() or pedestal
	if not pickup or pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then
		return
	end
	if (tonumber(pickup.SubType) or 0) > 0 then
		return
	end
	local state = read_state(pickup)
	if not state or state.ritual ~= "BLOODY" or state.bloom_failed == true or (tonumber(state.bloom_count) or 0) > 0 then
		return
	end
	if state.empty_evidence == "acquisition" then
		return
	end
	state.empty_evidence = "acquisition"
	write_state(pickup, state)
	trace("empty_acquisition", pickup, "")
end

local function sweep_morph_frames()
	local frame = game_frame()
	for seed, seen in pairs(item._morph_frame) do
		if seen ~= frame then
			item._morph_frame[seed] = nil
		end
	end
end

local function is_dangerous_altar(state)
	local ritual = state and state.ritual
	return ritual == "THORN" or ritual == "BLOODY" or ritual == "BLOOMING" or ritual == "DONE"
end

local function player_key(player)
	local data = player.GetData and player:GetData()
	if data and data.__Index ~= nil then
		return data.__Index
	end
	local ok, hash = pcall(GetPtrHash, player)
	if ok then
		return hash
	end
	return nil
end

local function player_can_attempt_sting(player)
	if not player or player:IsDead() then
		return false
	end
	return player:GetDamageCooldown() <= 0
end

local function altar_touching(pickup, player)
	local radius = (tonumber(pickup.Size) or 0) + (tonumber(player.Size) or 0)
	if radius <= 0 then
		return false
	end
	return pickup.Position:DistanceSquared(player.Position) <= radius * radius
end

local function try_sting_player(pickup, player)
	local state = read_state(pickup)
	if not is_dangerous_altar(state) or not player_can_attempt_sting(player) then
		return false
	end
	local key = player_key(player)
	local frame = game_frame()
	if key ~= nil and item._sting_frame[key] == frame then
		return false
	end
	if key ~= nil then
		item._sting_frame[key] = frame
	end
	local first_blood = state.ritual == "THORN"
	if first_blood then
		state.ritual = "BLOODY"
		write_state(pickup, state)
	end
	player:TakeDamage(item.damage, DamageFlag.DAMAGE_NO_PENALTIES, EntityRef(pickup), 0)
	trace("sting", pickup, first_blood and "first" or state.ritual)
	return true
end

local function tick_thorn_contact(pickup)
	if not pickup or not pickup:Exists() or pickup:IsDead() then
		return
	end
	local state = read_state(pickup)
	if not is_dangerous_altar(state) then
		return
	end
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player and altar_touching(pickup, player) then
			try_sting_player(pickup, player)
		end
	end
end

local function tick_pedestal(pickup)
	if not pickup or pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then
		return
	end
	local state = read_state(pickup)
	if not state then
		consider_roll(pickup, "update")
		return
	end
	if (tonumber(pickup.SubType) or 0) > 0 then
		local dirty = false
		if state.empty_pending or state.empty_seen_frame or state.empty_evidence then
			state.empty_pending = nil
			state.empty_seen_frame = nil
			state.empty_evidence = nil
			dirty = true
		end
		if dirty then
			write_state(pickup, state)
		end
	end
	if state.ritual == "BLOODY"
		and state.bloom_failed ~= true
		and (tonumber(state.bloom_count) or 0) == 0
		and (tonumber(pickup.SubType) or 0) <= 0
	then
		if state.empty_evidence ~= "acquisition" and settled_empty(pickup, state) then
			state.empty_evidence = "settled"
			write_state(pickup, state)
			trace("empty_settled", pickup, "")
		end
		if (state.empty_evidence == "acquisition" or state.empty_evidence == "settled")
			and not morph_blocked(pickup)
			and state.empty_pending ~= true
		then
			local seen = tonumber(state.empty_seen_frame)
			if seen == nil then
				state.empty_seen_frame = game_frame()
				write_state(pickup, state)
				trace("empty_seen", pickup, state.empty_evidence)
			elseif game_frame() > seen then
				begin_bloom(pickup, state)
				state = read_state(pickup) or state
			end
		end
	end
	if state.ritual == "BLOOMING" then
		state.bloom_timer = math.max(0, (tonumber(state.bloom_timer) or 0) - 1)
		write_state(pickup, state)
		if state.bloom_timer <= 0 and (tonumber(pickup.SubType) or 0) <= 0 then
			finish_bloom(pickup, state)
		end
	elseif state.roll_count == 0 then
		consider_roll(pickup, "update")
	end
	tick_thorn_contact(pickup)
end

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_PEDESTAL_ENCOUNTER,
	params = nil,
	Function = function(_, event)
		local pickup = event and event.pickup
		if not pickup then
			return
		end
		consider_roll(pickup, "encounter")
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_PICKUP_COLLECTIBLE,
	params = nil,
	Function = function(_, _player, _id, _touched, _ent, source_context)
		note_trusted_empty(source_context)
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE,
	params = nil,
	Function = function(_, _player, _id, _cnt, _touched, _prev, _from_direct, gain_context)
		note_trusted_empty(gain_context)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		sweep_morph_frames()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE,
	params = PickupVariant.PICKUP_COLLECTIBLE,
	Function = function(_, pickup)
		tick_pedestal(pickup)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION,
	params = PickupVariant.PICKUP_COLLECTIBLE,
	Function = function(_, pickup, collider)
		local player = collider and collider.ToPlayer and collider:ToPlayer()
		if not player then
			return
		end
		local state = read_state(pickup)
		if not is_dangerous_altar(state) then
			return
		end
		try_sting_player(pickup, player)
		-- true：忽略碰撞，内部拾取不会执行。Docs：nil 才继续原本拾取。
		if player:IsDead() or (player.HasMortalDamage and player:HasMortalDamage()) then
			return true
		end
		return nil
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PICKUP_RENDER,
	params = PickupVariant.PICKUP_COLLECTIBLE,
	Function = function(_, pickup, callback_offset)
		local state = read_state(pickup)
		if not state then
			return
		end
		apply_altar(pickup, state)
		if state.ritual == "BLOOMING" then
			render_blood(pickup, state, callback_offset)
		end
	end,
})

morph_txn.register("ThornFlowerCrown", {
	match_pre = function(pickup)
		return pickup
			and pickup.Variant == PickupVariant.PICKUP_COLLECTIBLE
			and read_state(pickup) ~= nil
	end,
	capture = function(pickup)
		item._morph_frame[pickup.InitSeed] = game_frame()
		local state = read_state(pickup)
		trace("morph_pre", pickup, state and state.eligibility or "")
		return state and auxi.deepCopy(state) or nil
	end,
	on_post = function(txn)
		local target = txn and txn.target
		if not target or target.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then
			trace("morph_drop", target, txn and txn.kind or "")
			return
		end
		local snap = auxi.deepCopy(txn.source_snapshot or fresh_state())
		if txn.kind == "EMPTY_PENDING" or (tonumber(target.SubType) or 0) <= 0 then
			snap.empty_pending = txn.kind == "EMPTY_PENDING" or nil
		else
			snap.empty_pending = nil
			snap.empty_seen_frame = nil
		end
		write_state(target, snap)
		target:GetData()[item.own_key .. "visual"] = nil
		item._morph_frame[txn.before and txn.before.init_seed or 0] = nil
		item._morph_frame[target.InitSeed] = nil
		trace("morph_post", target, tostring(txn.kind))
	end,
})

return item
