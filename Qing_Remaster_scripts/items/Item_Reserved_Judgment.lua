local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Reserved_Judgment,
	own_key = "Item_Reserved_Judgment_",
	mark_range = 90,
	icon_anm2 = "gfx/mimics/Reserved_Judgement/Reserved_icon.anm2",
	icon_offset_x = 18,
	icon_offset_y = 22,
	icon_scale = 1,
	fall_sound = SoundEffect.SOUND_WOODEN_NICKEL_SPAWN,
	mark_depth_offset = 10,
}

local state_save_key = item.own_key.."states"
local marked_owner_key = item.own_key.."marked_owner"
local MORPH_POLICY = {zero_subtype_is_transient = true}
local markers = {} -- [GetPtrHash] = {sprite, pickup, phase}

local function perhaps_mod()
	local name = "Qing_Remaster_scripts.items.Item_Perhaps_Chosen"
	local mod = package.loaded[name]
	if not mod then
		local ok, loaded = pcall(require, name)
		if ok then mod = loaded end
	end
	return mod
end

local function debug_root()
	local root = save.ModConfigSettings
	local options = root and root.QingRemasterOptions
	return options and options.Debug
end

local function debug_number(key, default, min_value, max_value)
	local debug = debug_root()
	local value = tonumber(debug and debug[key])
	if value == nil then value = default end
	if min_value then value = math.max(min_value, value) end
	if max_value then value = math.min(max_value, value) end
	return value
end

local function get_mark_range()
	return debug_number("ReservedJudgmentMarkRange", item.mark_range, 20, 240)
end

local function get_icon_offset()
	return Vector(
		debug_number("ReservedJudgmentIconOffsetX", item.icon_offset_x, -64, 64),
		debug_number("ReservedJudgmentIconOffsetY", item.icon_offset_y, -96, 64)
	)
end

local function get_icon_scale()
	return debug_number("ReservedJudgmentIconScale", item.icon_scale, 0.1, 3)
end

local function get_player_key(player)
	return tostring(player:GetData().__Index or player.InitSeed)
end

local function get_states()
	save.elses[state_save_key] = save.elses[state_save_key] or {}
	return save.elses[state_save_key]
end

local function get_state(player, create)
	local states = get_states()
	local key = get_player_key(player)
	if create then states[key] = states[key] or {} end
	local state = states[key]
	return state, key
end

local function is_priced_offer(pickup)
	if not REPENTOGON or not pickup or pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then
		return false
	end
	if pickup.SubType <= 0 then return false end
	local config = Isaac.GetItemConfig():GetCollectible(pickup.SubType)
	if not config or config.Tags & ItemConfig.TAG_QUEST == ItemConfig.TAG_QUEST then
		return false
	end
	local quote = price_holder.get_quote(pickup)
	if quote and quote.resolved then
		return quote.has_price == true
	end
	-- settle 前：保留旧启发式，避免误判未定价底座
	return pickup:IsShopItem() or pickup.Price ~= 0
end

local function resolve_offer_quote(pickup, pc_choice)
	if pc_choice and pc_choice.pending_token ~= nil then
		local pc = perhaps_mod()
		if pc and pc.ensure_quote_resolved then
			pc.ensure_quote_resolved(pickup)
		end
		local mq = pc and pc.get_materialized_quote and pc.get_materialized_quote(pickup)
		if mq and mq.resolved then
			return {
				resolved = true,
				has_price = mq.has_price == true,
				quoted_price = mq.price,
				was_shop_item = mq.was_shop_item == true,
			}
		end
		return {resolved = false}
	end
	local quote = price_holder.get_quote(pickup)
	if not quote or quote.resolved ~= true then
		local captured, ok = price_holder.capture_quote(pickup)
		if ok then quote = captured end
	end
	if not quote or quote.resolved ~= true then
		return {resolved = false}
	end
	return {
		resolved = true,
		has_price = quote.has_price == true,
		quoted_price = quote.price,
		was_shop_item = quote.is_shop_item == true,
	}
end

local function apply_locked_price(pickup, quoted_price, opts)
	if not pickup or type(quoted_price) ~= "number" then return end
	price_holder.lock_price(pickup, quoted_price, opts)
end

local function player_can_reserve(player, pickup)
	if not player or not pickup then return false end
	if auxi.has_have_coll(player, item.entity) then return true end
	return pickup.SubType == item.entity
end

local function offer_owner_on_pickup(pickup)
	if not pickup then return nil end
	return pickup:GetData()[marked_owner_key]
end

local function apply_mark_depth(pickup, m)
	if not pickup or not m or m.depth_applied then return end
	m.saved_depth = pickup.DepthOffset
	pickup.DepthOffset = (m.saved_depth or 0) + item.mark_depth_offset
	m.depth_applied = true
end

local function restore_mark_depth(pickup, m)
	if not m or not m.depth_applied then return end
	if pickup and pickup:Exists() then
		pickup.DepthOffset = m.saved_depth or 0
	end
	m.depth_applied = false
	m.saved_depth = nil
end

local function ensure_marker(pickup)
	local hash = GetPtrHash(pickup)
	local m = markers[hash]
	if m then
		m.pickup = pickup
		return m
	end
	local sprite = Sprite()
	sprite:Load(item.icon_anm2, true)
	m = {sprite = sprite, pickup = pickup, phase = "idle"}
	markers[hash] = m
	return m
end

local function begin_appear(pickup)
	if not pickup then return end
	local m = ensure_marker(pickup)
	m.sprite:Play("Appear", true)
	m.phase = "appear"
end

local function begin_disappear(pickup)
	if not pickup then return end
	local hash = GetPtrHash(pickup)
	local m = markers[hash]
	if not m or m.phase == "disappear" then return end
	m.sprite:Play("Disappear", true)
	m.phase = "disappear"
end

--- Consistance 业务绑定（跨房）；InitSeed 仅 debug
local function apply_mark_on_pickup(pickup, player_key, offer_extra)
	if not pickup then return nil end
	pickup:GetData()[marked_owner_key] = player_key
	local d = pickup:GetData()
	d._Data = d._Data or {}
	d._Data[item.own_key] = {
		marked_owner = player_key,
		collectible_id = offer_extra and offer_extra.collectible_id or pickup.SubType,
		provider = offer_extra and offer_extra.provider or "vanilla",
		provider_token = offer_extra and offer_extra.provider_token or nil,
		has_price = offer_extra and offer_extra.has_price == true or true,
		quoted_price = offer_extra and offer_extra.quoted_price or pickup.Price,
		was_shop_item = offer_extra and offer_extra.was_shop_item == true or false,
	}
	-- keep_level：跨层 scope；ignore_subtype：cycle STATE_SWITCH 不断；consistance：unload 仍保留 record
	return consistance_holder.try_hold_entity(pickup, item.own_key, {
		keep_level = true,
		ignore_subtype = true,
		consistance = true,
	})
end

local function clear_mark_on_pickup(pickup)
	if not pickup then return end
	pickup:GetData()[marked_owner_key] = nil
	local d = pickup:GetData()
	if d._Data then d._Data[item.own_key] = nil end
	consistance_holder.try_remove_entity(pickup, item.own_key, {ignore_subtype = true})
end

local function snapshot_collectible_cycle(pickup)
	if not pickup or not pickup.GetCollectibleCycle then return {} end
	local ok, cycle = pcall(function()
		return pickup:GetCollectibleCycle()
	end)
	if not ok or type(cycle) ~= "table" then return {} end
	local out = {}
	for i, id in ipairs(cycle) do
		out[i] = id
	end
	return out
end

--- 冻结当前展示：清空 CollectibleCycle；若 SubType 被改回则 Morph 回冻结项。
local function freeze_collectible_cycle(pickup, frozen_subtype)
	if not pickup then return {}, nil end
	frozen_subtype = tonumber(frozen_subtype) or pickup.SubType
	local snapshot = snapshot_collectible_cycle(pickup)
	if pickup.RemoveCollectibleCycle then
		pcall(function()
			pickup:RemoveCollectibleCycle()
		end)
	end
	if frozen_subtype and frozen_subtype > 0 and pickup.SubType ~= frozen_subtype and pickup.Morph then
		pcall(function()
			pickup:Morph(
				EntityType.ENTITY_PICKUP,
				PickupVariant.PICKUP_COLLECTIBLE,
				frozen_subtype,
				true, true, true
			)
		end)
	end
	return snapshot, frozen_subtype
end

--- 回房后再次 enforce：不重写 snapshot（业务快照在 reserved_offer）。
local function enforce_frozen_presentation(pickup, frozen_subtype)
	if not pickup then return end
	frozen_subtype = tonumber(frozen_subtype)
	if pickup.RemoveCollectibleCycle then
		pcall(function()
			pickup:RemoveCollectibleCycle()
		end)
	end
	if frozen_subtype and frozen_subtype > 0 and pickup.SubType ~= frozen_subtype and pickup.Morph then
		pcall(function()
			pickup:Morph(
				EntityType.ENTITY_PICKUP,
				PickupVariant.PICKUP_COLLECTIBLE,
				frozen_subtype,
				true, true, true
			)
		end)
	end
end

local function restore_collectible_cycle(pickup, snapshot, frozen_subtype)
	if not pickup then return end
	frozen_subtype = tonumber(frozen_subtype)
	if frozen_subtype and frozen_subtype > 0 and pickup.SubType ~= frozen_subtype and pickup.Morph then
		pcall(function()
			pickup:Morph(
				EntityType.ENTITY_PICKUP,
				PickupVariant.PICKUP_COLLECTIBLE,
				frozen_subtype,
				true, true, true
			)
		end)
	end
	if type(snapshot) ~= "table" or not pickup.AddCollectibleCycle then return end
	for _, id in ipairs(snapshot) do
		if id and id > 0 and id ~= pickup.SubType then
			pcall(function()
				pickup:AddCollectibleCycle(id)
			end)
		end
	end
end

local function release_provider_if_needed(offer, opts)
	if not offer then return end
	if offer.provider == "perhaps_chosen" and offer.provider_token ~= nil then
		local pc = perhaps_mod()
		if pc and pc.release_reserved_choice then
			pc.release_reserved_choice(offer.provider_token, opts)
		end
	end
end

local function clear_player_mark(player_key, except)
	for _, entity in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)) do
		local pickup = entity:ToPickup()
		if pickup and pickup ~= except and pickup:GetData()[marked_owner_key] == player_key then
			clear_mark_on_pickup(pickup)
			begin_disappear(pickup)
		end
	end
end

local function find_pickup_for_offer(offer)
	if not offer then return nil end
	for _, entity in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)) do
		local pickup = entity:ToPickup()
		if not pickup then goto continue end
		if offer.provider == "perhaps_chosen" and offer.provider_token ~= nil then
			local pc = perhaps_mod()
			local data = pc and pc.get_materialized_choice and pc.get_materialized_choice(pickup)
			if data and data.pending_token == offer.provider_token then
				return pickup
			end
		elseif offer.source_record_id then
			if consistance_holder.try_check_entity(pickup, item.own_key, false, {ignore_subtype = true}) then
				local info = pickup:GetData()._Data and pickup:GetData()._Data[item.own_key]
				if info and info.marked_owner == offer.owner_key then
					return pickup
				end
			end
		elseif offer_owner_on_pickup(pickup) == offer.owner_key then
			return pickup
		end
		::continue::
	end
	return nil
end

--- opts.play_disappear：默认 true。
--- opts.restore_cycle：仅用户取消 / 改保留目标 / Debug Clear 为 true；购买/D6/失效为 false。
local function clear_reservation(state, player_key, opts)
	if not state then return end
	if type(opts) ~= "table" then
		opts = { play_disappear = opts ~= false, restore_cycle = false }
	end
	local play_disappear = opts.play_disappear ~= false
	local restore_cycle = opts.restore_cycle == true
	local offer = state.reserved_offer
	if offer then
		local pickup = find_pickup_for_offer(offer)
		if restore_cycle and offer.provider == "vanilla" and pickup then
			restore_collectible_cycle(
				pickup,
				offer.cycle_snapshot,
				offer.frozen_subtype or offer.collectible_id
			)
		end
		release_provider_if_needed(offer, { restore_cycle = restore_cycle })
		if play_disappear then
			if pickup then
				clear_mark_on_pickup(pickup)
				begin_disappear(pickup)
			else
				clear_player_mark(player_key)
			end
		end
	elseif player_key then
		clear_player_mark(player_key)
	end
	state.reserved_offer = nil
end

local function matches_source_offer(offer, pickup)
	if not offer or not pickup or offer.phase ~= "tracking" then return false end
	if offer.provider == "perhaps_chosen" and offer.provider_token ~= nil then
		local pc = perhaps_mod()
		local data = pc and pc.get_materialized_choice and pc.get_materialized_choice(pickup)
		return data ~= nil and data.pending_token == offer.provider_token
	end
	if offer_owner_on_pickup(pickup) == offer.owner_key then
		return true
	end
	if consistance_holder.try_check_entity(pickup, item.own_key, false, {ignore_subtype = true}) then
		local info = pickup:GetData()._Data and pickup:GetData()._Data[item.own_key]
		if info and info.marked_owner == offer.owner_key then
			return true
		end
	end
	return false
end

function item.InvalidateSourcePickup(pickup)
	if not pickup then return false end
	local hit = false
	for key, state in pairs(get_states()) do
		local offer = state and state.reserved_offer
		if offer and matches_source_offer(offer, pickup) then
			clear_reservation(state, key, { play_disappear = true, restore_cycle = false })
			hit = true
		end
	end
	return hit
end

function item.InvalidateByToken(token)
	if token == nil then return false end
	local hit = false
	for key, state in pairs(get_states()) do
		local offer = state and state.reserved_offer
		if offer and offer.phase == "tracking"
			and offer.provider == "perhaps_chosen"
			and offer.provider_token == token
		then
			clear_reservation(state, key, { play_disappear = true, restore_cycle = false })
			hit = true
		end
	end
	return hit
end

local function restore_mark_from_consistance(pickup)
	if not pickup then return false end
	if not consistance_holder.try_check_entity(pickup, item.own_key, false, {ignore_subtype = true}) then
		return false
	end
	local info = pickup:GetData()._Data and pickup:GetData()._Data[item.own_key]
	if not info or not info.marked_owner then return false end
	local state = get_states()[info.marked_owner]
	local offer = state and state.reserved_offer
	if not offer or offer.phase ~= "tracking" then
		clear_mark_on_pickup(pickup)
		return false
	end
	-- Perhaps：以 token 为准；vanilla：回房后再次 enforce 冻结展示
	if offer.provider == "perhaps_chosen" then
		local pc = perhaps_mod()
		local data = pc and pc.get_materialized_choice and pc.get_materialized_choice(pickup)
		if not data or data.pending_token ~= offer.provider_token then
			clear_mark_on_pickup(pickup)
			return false
		end
	elseif offer.cycle_paused then
		enforce_frozen_presentation(pickup, offer.frozen_subtype or offer.collectible_id)
	end
	pickup:GetData()[marked_owner_key] = info.marked_owner
	begin_appear(pickup)
	return true
end

local function update_markers()
	for hash, m in pairs(markers) do
		local pickup = m.pickup
		if not pickup or not pickup:Exists() then
			restore_mark_depth(pickup, m)
			markers[hash] = nil
		else
			apply_mark_depth(pickup, m)
			local sprite = m.sprite
			sprite:Update()
			if m.phase == "appear" then
				if sprite:IsEventTriggered("Fall") then
					sound_tracker.PlayStackedSound(item.fall_sound, 1, 1, false, 0, 2)
				end
				if sprite:IsFinished("Appear") then
					sprite:Play("Idle", true)
					m.phase = "idle"
				end
			elseif m.phase == "disappear" then
				if sprite:IsFinished("Disappear") then
					restore_mark_depth(pickup, m)
					markers[hash] = nil
				end
			end
		end
	end
end

local function find_candidate(player)
	local best
	local best_distance = get_mark_range()
	local player_key = get_player_key(player)
	for _, entity in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)) do
		local pickup = entity:ToPickup()
		if is_priced_offer(pickup) and player_can_reserve(player, pickup) then
			local owner = offer_owner_on_pickup(pickup)
			if owner and owner ~= player_key then
				-- 他人物品：无操作
			else
				local distance = pickup.Position:Distance(player.Position)
				if distance < best_distance then
					best = pickup
					best_distance = distance
				end
			end
		end
	end
	return best
end

local function build_offer(pickup, player_key, provider, provider_token, record_id, quote, cycle_fields)
	local stage = Game():GetLevel():GetStage()
	local stage_type = Game():GetLevel():GetStageType()
	local dim = 0
	local level = Game():GetLevel()
	if level.GetDimension then
		dim = level:GetDimension()
	else
		dim = auxi.GetDimension() or 0
	end
	local desc = level:GetCurrentRoomDesc()
	quote = quote or {}
	cycle_fields = cycle_fields or {}
	local frozen = tonumber(cycle_fields.frozen_subtype) or pickup.SubType
	local offer = {
		provider = provider or "vanilla",
		provider_token = provider_token,
		collectible_id = frozen,
		has_price = quote.has_price == true,
		quoted_price = quote.quoted_price,
		was_shop_item = quote.was_shop_item == true,
		source_record_id = record_id and tostring(record_id) or nil,
		source_stage = stage,
		source_stage_type = stage_type,
		source_dimension = dim,
		source_list_index = desc and desc.ListIndex or 0,
		source_init_seed = pickup.InitSeed, -- debug only
		owner_key = player_key,
		phase = "tracking",
	}
	-- vanilla cycle freeze 是 reservation 业务状态，进 save.elses（Continue / 422）
	if provider == "vanilla" and cycle_fields.cycle_paused then
		offer.cycle_paused = true
		offer.cycle_snapshot = cycle_fields.cycle_snapshot or {}
		offer.frozen_subtype = frozen
	end
	return offer
end

local function reserve_offer(player, pickup)
	local state, player_key = get_state(player, true)
	if state.reserved_offer then
		clear_reservation(state, player_key, { play_disappear = true, restore_cycle = true })
	else
		clear_player_mark(player_key, pickup)
	end

	local provider = "vanilla"
	local provider_token = nil
	local pc = perhaps_mod()
	local choice = pc and pc.get_materialized_choice and pc.get_materialized_choice(pickup)
	local quote = resolve_offer_quote(pickup, choice)
	if not quote.resolved or quote.has_price ~= true or type(quote.quoted_price) ~= "number" then
		-- 报价尚未 settle：本次 RT 不建立 reservation
		return false
	end
	if choice and choice.pending_token ~= nil then
		provider = "perhaps_chosen"
		if pc.reserve_materialized_choice then
			provider_token = pc.reserve_materialized_choice(pickup, player_key)
		else
			provider_token = choice.pending_token
		end
		if provider_token == nil then
			return false
		end
	end

	-- vanilla：RJ 自己冻结当前展示；Perhaps 已由 adapter 冻结，禁止 double freeze
	local cycle_fields = {}
	local frozen_subtype = pickup.SubType
	if provider == "vanilla" then
		local snapshot
		snapshot, frozen_subtype = freeze_collectible_cycle(pickup, pickup.SubType)
		cycle_fields = {
			cycle_paused = true,
			cycle_snapshot = snapshot,
			frozen_subtype = frozen_subtype,
		}
	end

	local draft = {
		collectible_id = frozen_subtype,
		provider = provider,
		provider_token = provider_token,
		has_price = true,
		quoted_price = quote.quoted_price,
		was_shop_item = quote.was_shop_item == true,
	}
	local record_id = apply_mark_on_pickup(pickup, player_key, draft)
	state.reserved_offer = build_offer(pickup, player_key, provider, provider_token, record_id, quote, cycle_fields)
	state.committed_spawn = nil
	begin_appear(pickup)
	return true
end

local function find_offer_spawn_pos(room)
	local margin = 80
	local top_left = room:GetTopLeftPos()
	local start = Vector(top_left.X + margin, top_left.Y + margin)
	return room:FindFreePickupSpawnPosition(start, 20, true)
end

local function spawn_committed_offer(player, payload)
	if not payload then return false end
	local room = Game():GetRoom()
	local position = find_offer_spawn_pos(room)

	if payload.provider == "perhaps_chosen" and payload.provider_token ~= nil then
		local pc = perhaps_mod()
		if not pc or not pc.materialize_reserved_choice then return false end
		local carrier = pc.materialize_reserved_choice(payload.provider_token, {
			has_price = payload.has_price == true,
			quoted_price = payload.quoted_price,
			was_shop_item = payload.was_shop_item == true,
			position = position,
		})
		return carrier ~= nil
	end

	if not payload.collectible_id then return false end
	if payload.was_shop_item then
		unique_holder.try_spawn_shop_item()
	end
	local pickup = Isaac.Spawn(
		EntityType.ENTITY_PICKUP,
		PickupVariant.PICKUP_COLLECTIBLE,
		payload.collectible_id,
		position,
		Vector.Zero,
		player
	):ToPickup()
	if not pickup then return false end
	pickup:Morph(
		EntityType.ENTITY_PICKUP,
		PickupVariant.PICKUP_COLLECTIBLE,
		payload.collectible_id,
		true, true, true
	)
	pickup.OptionsPickupIndex = 0
	pickup.ShopItemId = -1
	apply_locked_price(pickup, payload.quoted_price, {
		was_shop_item = payload.was_shop_item == true,
	})
	pickup:GetData()[item.own_key.."spawned"] = true
	return true
end

local function try_spawn_committed(player, state)
	if not state or not state.committed_spawn then return end
	if spawn_committed_offer(player, state.committed_spawn) then
		state.committed_spawn = nil
	end
end

local function commit_tracking_offers()
	for key, state in pairs(get_states()) do
		local offer = state and state.reserved_offer
		if offer and offer.phase == "tracking" then
			state.committed_spawn = {
				provider = offer.provider,
				provider_token = offer.provider_token,
				collectible_id = offer.collectible_id,
				has_price = offer.has_price == true or offer.is_shop == true,
				quoted_price = offer.quoted_price,
				was_shop_item = offer.was_shop_item == true or offer.is_shop == true,
			}
			-- 标牌内存可丢；业务已进 committed_spawn。Perhaps lock 保留到 materialize。
			local pickup = find_pickup_for_offer(offer)
			if pickup then
				clear_mark_on_pickup(pickup)
			else
				clear_player_mark(key)
			end
			state.reserved_offer = nil
		end
	end
end

local function pick_debug_collectible(rng)
	for _ = 1, 24 do
		local colid = auxi.get_item_from_pool(nil, true, rng)
		local config = Isaac.GetItemConfig():GetCollectible(colid)
		if config
			and (config.Tags & ItemConfig.TAG_QUEST) ~= ItemConfig.TAG_QUEST
			and colid ~= item.entity
		then
			return colid
		end
	end
	return CollectibleType.COLLECTIBLE_SAD_ONION
end

function item.debug_spawn_priced_item(price)
	if not Isaac.IsInGame or not Isaac.IsInGame() then return false end
	price = tonumber(price) or 15
	local player = Game():GetPlayer(0)
	local room = Game():GetRoom()
	local rng = player:GetCollectibleRNG(item.entity)
	local colid = pick_debug_collectible(rng)
	unique_holder.try_spawn_shop_item()
	local pos = room:FindFreePickupSpawnPosition(player.Position + Vector(0, 40), 40, true)
	local pickup = Isaac.Spawn(
		EntityType.ENTITY_PICKUP,
		PickupVariant.PICKUP_COLLECTIBLE,
		colid,
		pos,
		Vector.Zero,
		nil
	):ToPickup()
	if not pickup then return false end
	pickup.OptionsPickupIndex = 0
	pickup.ShopItemId = -1
	apply_locked_price(pickup, price)
	return true
end

function item.debug_spawn_option_choices(_count)
	return item.debug_spawn_priced_item(15)
end

function item.debug_give_item()
	if not Isaac.IsInGame or not Isaac.IsInGame() then return false end
	Game():GetPlayer(0):AddCollectible(item.entity)
	return true
end

function item.debug_clear_reserved()
	if not Isaac.IsInGame or not Isaac.IsInGame() then return false end
	for player_num = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(player_num)
		local state, player_key = get_state(player, false)
		if state then
			clear_reservation(state, player_key, { play_disappear = true, restore_cycle = true })
			state.committed_spawn = nil
		end
	end
	return true
end

function item.debug_clear_trial()
	return item.debug_clear_reserved()
end

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_, player)
	if not REPENTOGON then return end
	if not Input.IsActionTriggered(ButtonAction.ACTION_DROP, player.ControllerIndex) then return end
	local pickup = find_candidate(player)
	if not pickup then return end
	local player_key = get_player_key(player)
	if offer_owner_on_pickup(pickup) == player_key then
		local state = get_state(player, true)
		clear_reservation(state, player_key, { play_disappear = true, restore_cycle = true })
		return
	end
	reserve_offer(player, pickup)
end,
})

-- 真正替换交易：SUPERSEDE / EMPTY；正常 cycle 在 freeze 后不应再 Morph
if ModCallbacks.MC_POST_PICKUP_MORPH then
	table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_PICKUP_MORPH, params = nil, priority = 60,
	Function = function(_, pickup, previous_type, previous_variant, previous_subtype, _kept_price, kept_seed, _ignored)
		if not pickup or pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then return end
		local before = {
			init_seed = kept_seed and pickup.InitSeed or nil,
			type = previous_type,
			variant = previous_variant,
			subtype = previous_subtype,
		}
		local after = {
			init_seed = pickup.InitSeed,
			type = pickup.Type,
			variant = pickup.Variant,
			subtype = pickup.SubType or 0,
		}
		local kind = consistance_holder.classify_morph(before, after, MORPH_POLICY)
		-- seed 更换 / 清空 / SUPERSEDE：原交易结束（不恢复旧 cycle）
		if (not kept_seed) or kind == "SUPERSEDE" or kind == "EMPTY_PENDING" then
			item.InvalidateSourcePickup(pickup)
			return
		end
		if kind == "STATE_SWITCH" or kind == "SAME_LIFETIME" then
			for key, state in pairs(get_states()) do
				local offer = state and state.reserved_offer
				if offer and offer.phase == "tracking" and matches_source_offer(offer, pickup) then
					if offer.provider == "perhaps_chosen" then
						-- token 身份：presentation switch 不取消
					elseif offer.cycle_paused then
						-- freeze 失效或短暂抖动：重新 enforce，不取消 reservation
						local want = offer.frozen_subtype or offer.collectible_id
						if want and pickup.SubType ~= want then
							enforce_frozen_presentation(pickup, want)
						end
					elseif offer.collectible_id and pickup.SubType ~= offer.collectible_id then
						-- 未冻结的旧路径兜底
						clear_reservation(state, key, { play_disappear = true, restore_cycle = false })
					end
				end
			end
		end
	end,
	})
end

if ModCallbacks.MC_POST_PICKUP_SHOP_PURCHASE then
	table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_PICKUP_SHOP_PURCHASE, params = PickupVariant.PICKUP_COLLECTIBLE,
	Function = function(_, pickup, _player, _money_spent)
		item.InvalidateSourcePickup(pickup)
	end,
	})
end

-- 注意：禁止用 MC_POST_ENTITY_REMOVE 当 offer 失效（离房 unload ≠ 交易结束）

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = PickupVariant.PICKUP_COLLECTIBLE,
Function = function(_, pickup)
	restore_mark_from_consistance(pickup)
end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	for _, entity in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)) do
		restore_mark_from_consistance(entity:ToPickup())
	end
end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	update_markers()
	if Game():GetRoom():GetFrameCount() < 2 then return end
	for player_num = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(player_num)
		local state = get_state(player, false)
		if state then try_spawn_committed(player, state) end
	end
end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_PICKUP_RENDER, params = PickupVariant.PICKUP_COLLECTIBLE,
Function = function(_, pickup, render_offset)
	local m = markers[GetPtrHash(pickup)]
	if not m then return end
	local scale = get_icon_scale()
	m.sprite.Scale = Vector(scale, scale)
	local world = pickup.Position + get_icon_offset()
	m.sprite:Render(Isaac.WorldToScreen(world) + render_offset, Vector.Zero, Vector.Zero)
end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil, priority = -20,
Function = function(_)
	commit_tracking_offers()
end,
})

table.insert(item.myToCall, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	if not continue then save.elses[state_save_key] = {} end
	markers = {}
end,
})

return item
