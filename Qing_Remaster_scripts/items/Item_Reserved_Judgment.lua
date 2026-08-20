local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Reserved_Judgment,
	own_key = "Item_Reserved_Judgment_",
	-- 旧版曾直写 innate 的组名；现已改走 imitate_item_holder，仅用于清理残留
	legacy_innate_group = "Qing_Remaster_Reserved_Judgment_Trial",
	mark_range = 90,
	icon_anm2 = "gfx/mimics/Reserved_Judgement/Reserved_icon.anm2",
	-- 标牌相对底座：配置直接用世界坐标（+Y 向下）。默认 22。公式里不要取反。
	icon_offset_x = 18,
	icon_offset_y = 22,
	icon_scale = 1,
	fall_sound = SoundEffect.SOUND_WOODEN_NICKEL_SPAWN,
	-- 标牌绘制偏晚，避免被同高度底座/特效挡住
	mark_depth_offset = 10,
	-- 试用 HUD：Tint 近白 + Colorize 暖黄（勿用 Tint RGB 乘脏图标）
	-- Color(R,G,B,A, RO,GO,BO, RC,GC,BC,AC)；绘制时 A 由脉冲覆盖，见 get_hud_draw_color
	hud_tint = Color(1,1,1,0.7,0,0,0,2.4,1.7,0.55,1),
	hud_pulse_base = 0.55,
	hud_pulse_amp = 0.35,
	hud_pulse_speed = 0.18,
}

local function trial_hud_color(alpha)
	local t = auxi.color2table(item.hud_tint)
	t.A = alpha
	return auxi.table2color(t)
end

-- 主动/被动试用 HUD 共用：alpha_mul 一般为槽位 alpha（被动 Extra HUD 用 1）
function item.get_hud_pulse()
	return item.hud_pulse_base + item.hud_pulse_amp * (0.5 + 0.5 * math.sin(Game():GetFrameCount() * item.hud_pulse_speed))
end

function item.get_hud_draw_color(alpha_mul)
	return trial_hud_color((alpha_mul or 1) * item.get_hud_pulse())
end

local state_save_key = item.own_key.."states"
local marked_owner_key = item.own_key.."marked_owner"
local markers = {} -- [GetPtrHash] = {sprite, pickup, phase}

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
	-- 直接使用配置值；不要在这里再对 Y 取反。
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

local function migrate_state(state)
	if not state then return end
	state.trials = state.trials or {}
	state.pending_offers = state.pending_offers or {}
	state.claimed_groups = state.claimed_groups or {}
	-- 旧 InitSeed / OptionsIndex 全局表丢弃
	state.claimed_init_seeds = nil
	state.claimed_option_groups = nil
	-- 兼容旧单试用字段
	if state.trial_id then
		local cfg = Isaac.GetItemConfig():GetCollectible(state.trial_id)
		local kind = (cfg and cfg.Type == ItemType.ITEM_ACTIVE) and "active" or "passive"
		state.trials[#state.trials + 1] = {id = state.trial_id,kind = kind}
		state.trial_id = nil
	end
	if state.pending_offer then
		state.pending_offers[#state.pending_offers + 1] = state.pending_offer
		state.pending_offer = nil
	end
end

local function room_group_key(options_index)
	if not options_index or options_index == 0 then return nil end
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local list_index = desc and desc.ListIndex or 0
	return tostring(list_index)..":"..tostring(options_index)
end

local function is_group_claimed(state,options_index)
	local key = room_group_key(options_index)
	if not state or not key then return false end
	return state.claimed_groups[key] == true
end

local function claim_option_group(state,options_index)
	local key = room_group_key(options_index)
	if not state or not key then return end
	state.claimed_groups[key] = true
end

local function clear_claimed_groups_for_level()
	for _,state in pairs(get_states()) do
		if state then state.claimed_groups = {} end
	end
end

local function get_state(player,create)
	local states = get_states()
	local key = get_player_key(player)
	if create then states[key] = states[key] or {} end
	local state = states[key]
	migrate_state(state)
	return state,key
end

local function collectible_kind(collectible)
	local config = Isaac.GetItemConfig():GetCollectible(collectible)
	if not config then return "passive" end
	if config.Type == ItemType.ITEM_ACTIVE then return "active" end
	if config.Type == ItemType.ITEM_FAMILIAR then return "familiar" end
	return "passive"
end

local function is_trial_candidate(pickup)
	if not REPENTOGON or not pickup or pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then return false end
	if pickup.SubType <= 0 or pickup.OptionsPickupIndex == 0 or pickup.Price ~= 0 or pickup:IsShopItem() then return false end
	local config = Isaac.GetItemConfig():GetCollectible(pickup.SubType)
	if not config or config.Tags & ItemConfig.TAG_QUEST == ItemConfig.TAG_QUEST then return false end
	return config.Type == ItemType.ITEM_PASSIVE
		or config.Type == ItemType.ITEM_FAMILIAR
		or config.Type == ItemType.ITEM_ACTIVE
end

local function find_candidate(player)
	local state = get_state(player,false)
	local best
	local best_distance = get_mark_range()
	for _,entity in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP,PickupVariant.PICKUP_COLLECTIBLE)) do
		local pickup = entity:ToPickup()
		if is_trial_candidate(pickup) and not is_group_claimed(state,pickup.OptionsPickupIndex) then
			local distance = pickup.Position:Distance(player.Position)
			if distance < best_distance then
				best = pickup
				best_distance = distance
			end
		end
	end
	return best
end

local function apply_mark_depth(pickup,m)
	if not pickup or not m or m.depth_applied then return end
	m.saved_depth = pickup.DepthOffset
	pickup.DepthOffset = (m.saved_depth or 0) + item.mark_depth_offset
	m.depth_applied = true
end

local function restore_mark_depth(pickup,m)
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
		apply_mark_depth(pickup,m)
		return m
	end
	local sprite = Sprite()
	sprite:Load(item.icon_anm2, true)
	sprite:Play("Idle", true)
	m = {sprite = sprite, pickup = pickup, phase = "idle"}
	markers[hash] = m
	apply_mark_depth(pickup,m)
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

local function apply_mark_on_pickup(pickup,player_key)
	if not pickup then return end
	pickup:GetData()[marked_owner_key] = player_key
	local d = pickup:GetData()
	d._Data = d._Data or {}
	d._Data[item.own_key] = {marked_owner = player_key}
	consistance_holder.try_hold_entity(pickup,item.own_key,{keep_level = true,})
end

local function clear_mark_on_pickup(pickup)
	if not pickup then return end
	pickup:GetData()[marked_owner_key] = nil
	local d = pickup:GetData()
	if d._Data then d._Data[item.own_key] = nil end
	consistance_holder.try_remove_entity(pickup,item.own_key)
end

local function restore_mark_from_consistance(pickup)
	if not pickup then return false end
	if not consistance_holder.try_check_entity(pickup,item.own_key) then return false end
	local info = pickup:GetData()._Data and pickup:GetData()._Data[item.own_key]
	if not info or not info.marked_owner then return false end
	pickup:GetData()[marked_owner_key] = info.marked_owner
	begin_appear(pickup)
	return true
end

-- 只清同一多选组内、该玩家的其它保留标记
local function clear_group_mark(player_key,options_index,except)
	if not options_index or options_index == 0 then return end
	for _,entity in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP,PickupVariant.PICKUP_COLLECTIBLE)) do
		local pickup = entity:ToPickup()
		if pickup
			and pickup ~= except
			and pickup.OptionsPickupIndex == options_index
			and pickup:GetData()[marked_owner_key] == player_key
		then
			clear_mark_on_pickup(pickup)
			begin_disappear(pickup)
		end
	end
end

local function clear_player_mark(player_key,except)
	for _,entity in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP,PickupVariant.PICKUP_COLLECTIBLE)) do
		local pickup = entity:ToPickup()
		if pickup and pickup ~= except and pickup:GetData()[marked_owner_key] == player_key then
			clear_mark_on_pickup(pickup)
			begin_disappear(pickup)
		end
	end
end

local function update_markers()
	for hash,m in pairs(markers) do
		local pickup = m.pickup
		if not pickup or not pickup:Exists() then
			restore_mark_depth(pickup,m)
			markers[hash] = nil
		else
			apply_mark_depth(pickup,m)
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
					restore_mark_depth(pickup,m)
					markers[hash] = nil
				end
			end
		end
	end
end

local function refresh_imitate(player)
	Imitate_item_holder.Evaluate_Imitate_Items(player)
end

-- 清掉旧版私有 innate 组残留（若仍存在）
local function scrub_legacy_innate(player,collectible)
	if not player or not collectible or not player.GetInnateCollectibleCount then return end
	local ok,count = pcall(function()
		return player:GetInnateCollectibleCount(collectible,item.legacy_innate_group)
	end)
	if ok and count and count > 0 then
		pcall(function()
			player:RemoveInnateCollectible(collectible,count,item.legacy_innate_group)
		end)
	end
end

local function player_holds_active(player,collectible)
	if not collectible or collectible <= 0 then return false end
	if player:GetActiveItem(ActiveSlot.SLOT_PRIMARY) == collectible then return true end
	if player:GetActiveItem(ActiveSlot.SLOT_SECONDARY) == collectible then return true end
	return player:HasCollectible(collectible)
end

local function remove_trial_entry(state,collectible,kind)
	if not state or not state.trials then return false end
	for i = #state.trials,1,-1 do
		local trial = state.trials[i]
		if trial.id == collectible and (not kind or trial.kind == kind) then
			table.remove(state.trials,i)
			return true
		end
	end
	return false
end

local function is_active_trial(state,collectible)
	if not state or not collectible then return false end
	for _,trial in ipairs(state.trials or {}) do
		if trial.kind == "active" and trial.id == collectible then return true end
	end
	return false
end

local function destroy_collectible_pickup(pickup)
	if not pickup or not pickup:Exists() then return end
	local m = markers[GetPtrHash(pickup)]
	if m then restore_mark_depth(pickup,m) end
	begin_disappear(pickup)
	clear_mark_on_pickup(pickup)
	local removed = pickup:TryRemoveCollectible()
	if not removed then
		pickup:Morph(EntityType.ENTITY_PICKUP,PickupVariant.PICKUP_COLLECTIBLE,0,true,true,true)
	end
end

-- 交换主动后，试用主动掉到底座上时立刻清除
local function destroy_dropped_trial_active(player,collectible)
	local best
	local best_distance = 120
	for _,entity in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP,PickupVariant.PICKUP_COLLECTIBLE,collectible)) do
		local pickup = entity:ToPickup()
		if pickup and pickup.SubType == collectible and pickup.Price == 0 and not pickup:IsShopItem() then
			local distance = pickup.Position:Distance(player.Position)
			if distance < best_distance then
				best = pickup
				best_distance = distance
			end
		end
	end
	if best then destroy_collectible_pickup(best) end
end

local function snapshot_actives(player)
	return {
		[ActiveSlot.SLOT_PRIMARY] = player:GetActiveItem(ActiveSlot.SLOT_PRIMARY) or 0,
		[ActiveSlot.SLOT_SECONDARY] = player:GetActiveItem(ActiveSlot.SLOT_SECONDARY) or 0,
	}
end

local function find_offer_spawn_pos(room)
	-- 从房间左上角内侧再内缩 80，避开墙边，再找空位
	local margin = 80
	local top_left = room:GetTopLeftPos()
	local start = Vector(top_left.X + margin, top_left.Y + margin)
	return room:FindFreePickupSpawnPosition(start, 20, true)
end

local function spawn_one_offer(player,collectible)
	if not collectible then return false end
	local room = Game():GetRoom()
	local position = find_offer_spawn_pos(room)
	unique_holder.try_spawn_shop_item()
	local pickup = Isaac.Spawn(EntityType.ENTITY_PICKUP,PickupVariant.PICKUP_COLLECTIBLE,collectible,position,Vector.Zero,player):ToPickup()
	if not pickup then return false end
	pickup:Morph(EntityType.ENTITY_PICKUP,PickupVariant.PICKUP_COLLECTIBLE,collectible,true,true,true)
	pickup.OptionsPickupIndex = 0
	pickup.ShopItemId = -1
	pickup.AutoUpdatePrice = false
	pickup.Price = 15
	pickup:GetData()[item.own_key.."offer"] = true
	return true
end

local function spawn_pending_offers(player,state)
	if not state or not state.pending_offers or #state.pending_offers == 0 then return end
	local remain = {}
	for _,collectible in ipairs(state.pending_offers) do
		if not spawn_one_offer(player,collectible) then
			remain[#remain + 1] = collectible
		end
	end
	state.pending_offers = remain
end

local function pick_debug_collectible(rng,allow_active)
	for _ = 1,24 do
		local colid = auxi.get_item_from_pool(nil,true,rng)
		local config = Isaac.GetItemConfig():GetCollectible(colid)
		if config
			and (config.Type == ItemType.ITEM_PASSIVE
				or config.Type == ItemType.ITEM_FAMILIAR
				or (allow_active and config.Type == ItemType.ITEM_ACTIVE))
			and (config.Tags & ItemConfig.TAG_QUEST) ~= ItemConfig.TAG_QUEST
			and colid ~= item.entity
		then
			return colid
		end
	end
	return CollectibleType.COLLECTIBLE_SAD_ONION
end

function item.debug_spawn_option_choices(count)
	if not Isaac.IsInGame or not Isaac.IsInGame() then return false end
	count = math.max(2, math.floor(tonumber(count) or 3))
	local player = Game():GetPlayer(0)
	local room = Game():GetRoom()
	local rng = player:GetCollectibleRNG(item.entity)
	local ndx = option_index_holder.find_a_new_index()
	local center = room:FindFreePickupSpawnPosition(player.Position + Vector(0,40),40,true)
	for i = 1,count do
		local colid = pick_debug_collectible(rng,true)
		local pos = center + Vector((i - (count + 1) / 2) * 40, 0)
		local pickup = Isaac.Spawn(EntityType.ENTITY_PICKUP,PickupVariant.PICKUP_COLLECTIBLE,colid,pos,Vector.Zero,nil):ToPickup()
		if pickup then
			pickup.OptionsPickupIndex = ndx
			pickup.Price = 0
			pickup.ShopItemId = -1
		end
	end
	return true
end

function item.debug_give_item()
	if not Isaac.IsInGame or not Isaac.IsInGame() then return false end
	Game():GetPlayer(0):AddCollectible(item.entity)
	return true
end

function item.debug_clear_trial()
	if not Isaac.IsInGame or not Isaac.IsInGame() then return false end
	for player_num = 0,Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(player_num)
		local state,player_key = get_state(player,false)
		if state then
			for _,trial in ipairs(state.trials or {}) do
				if trial.kind == "active" then
					if player_holds_active(player,trial.id) then
						player:RemoveCollectible(trial.id)
					end
				else
					scrub_legacy_innate(player,trial.id)
				end
			end
			state.trials = {}
			state.pending_offers = {}
			state.claimed_groups = {}
			clear_player_mark(player_key)
			refresh_imitate(player)
		end
	end
	return true
end

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if not REPENTOGON or not auxi.has_have_coll(player,item.entity) then return end
	local state,player_key = get_state(player,true)
	local d = player:GetData()

	-- 检测试用主动被换下：清除掉落在底座上的该主动，并结束该试用（不进入下层商店）
	local prev = d[item.own_key.."active_snap"]
	local cur = snapshot_actives(player)
	if prev then
		local held = {
			[cur[ActiveSlot.SLOT_PRIMARY] or 0] = true,
			[cur[ActiveSlot.SLOT_SECONDARY] or 0] = true,
		}
		for _,slot in ipairs({ActiveSlot.SLOT_PRIMARY,ActiveSlot.SLOT_SECONDARY}) do
			local old_id = prev[slot] or 0
			if old_id > 0 and not held[old_id] and is_active_trial(state,old_id) then
				destroy_dropped_trial_active(player,old_id)
				remove_trial_entry(state,old_id,"active")
			end
		end
	end
	d[item.own_key.."active_snap"] = cur

	if Input.IsActionTriggered(ButtonAction.ACTION_DROP,player.ControllerIndex) then
		local pickup = find_candidate(player)
		if not pickup then return end
		if is_group_claimed(state,pickup.OptionsPickupIndex) then return end
		if pickup:GetData()[marked_owner_key] == player_key then
			clear_mark_on_pickup(pickup)
			begin_disappear(pickup)
		else
			clear_group_mark(player_key,pickup.OptionsPickupIndex,pickup)
			apply_mark_on_pickup(pickup,player_key)
			begin_appear(pickup)
		end
	end
end,
})

-- 试用主动入手：原主动需正常换下（掉落/进书包），不能被 AddCollectible 直接吞掉
local function give_trial_active(player,collectible)
	local primary = player:GetActiveItem(ActiveSlot.SLOT_PRIMARY) or 0
	local secondary = player:GetActiveItem(ActiveSlot.SLOT_SECONDARY) or 0
	local schoolbag_free = player:HasCollectible(CollectibleType.COLLECTIBLE_SCHOOLBAG) and secondary == 0
	if primary > 0 and not schoolbag_free then
		player:DropCollectible(primary)
	end
	local charge = 0
	local cfg = Isaac.GetItemConfig():GetCollectible(collectible)
	if cfg and cfg.MaxCharges and cfg.MaxCharges > 0 then charge = cfg.MaxCharges end
	player:AddCollectible(collectible,charge,true,ActiveSlot.SLOT_PRIMARY)
end

-- 只藏原版主动图标，充能条保留；真正绘制走模组 POST_SLOT_RENDER + PlayerActiveUIPos
table.insert(item.ToCall,{CallBack = ModCallbacks.MC_PRE_PLAYERHUD_RENDER_ACTIVE_ITEM, params = nil,
Function = function(_,player,slot,offset,alpha,scale,charge_bar_offset)
	local state = get_state(player,false)
	local active_id = player:GetActiveItem(slot)
	if not active_id or active_id <= 0 or not is_active_trial(state,active_id) then return end
	return {HideItem = true}
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_RENDER, params = "Active",
Function = function(_,player,tp,cid,slot)
	local state = get_state(player,false)
	if not cid or cid <= 0 or not is_active_trial(state,cid) then return end
	local info = ui.GetActiveSlotRenderInfo(player,slot)
	local scale = (info and tonumber(info.scale)) or 1
	-- HUD 层渲染：用回调带来的 alpha，不要用 slot_render_holder.get_alpha()
	local hud_alpha = (info and tonumber(info.alpha)) or 1
	local sprite = auxi.load_item(cid)
	sprite.Scale = Vector(scale,scale)
	sprite.Color = item.get_hud_draw_color(hud_alpha)
	-- Offset 是左上角；load_item Idle 不是中心锚点，按帧 Pivot/Pos 换算后再画
	local pos = ui.ActiveSlotSpriteRenderPos(player,slot,sprite,0)
	sprite:Render(pos,Vector.Zero,Vector.Zero)
end,
})

table.insert(item.pre_ToCall,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = PickupVariant.PICKUP_COLLECTIBLE,priority = -150,
Function = function(_,pickup,collider)
	local player = collider:ToPlayer()
	if not player or not auxi.has_have_coll(player,item.entity) or not is_trial_candidate(pickup) then return end
	local state,player_key = get_state(player,true)
	if pickup:GetData()[marked_owner_key] ~= player_key or not auxi.will_pick_up(player,pickup) then return end
	local options_index = pickup.OptionsPickupIndex
	if is_group_claimed(state,options_index) then return end

	local collectible = pickup.SubType
	local kind = collectible_kind(collectible)
	claim_option_group(state,options_index)
	pickup.OptionsPickupIndex = 0
	begin_disappear(pickup)
	local removed = pickup:TryRemoveCollectible()
	if not removed then
		pickup:Morph(EntityType.ENTITY_PICKUP,PickupVariant.PICKUP_COLLECTIBLE,0,true,true,true)
	end
	clear_mark_on_pickup(pickup)

	if kind == "active" then
		-- 真实入手主动以便充能/使用；先正常换下原主动，换下试用主动时再清掉底座
		give_trial_active(player,collectible)
		state.trials[#state.trials + 1] = {id = collectible,kind = "active"}
		player:GetData()[item.own_key.."active_snap"] = snapshot_actives(player)
	else
		-- 被动/跟班试用统一交给 imitate_item_holder
		scrub_legacy_innate(player,collectible)
		state.trials[#state.trials + 1] = {id = collectible,kind = "passive"}
		refresh_imitate(player)
	end

	player:AnimateCollectible(collectible,"Pickup","PlayerPickupSparkle")
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_POWERUP1,1,1,false,0,2)
	item_displaying_holder.display_item(player,collectible)
	return true
end,
})

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = PickupVariant.PICKUP_COLLECTIBLE,
Function = function(_,pickup)
	restore_mark_from_consistance(pickup)
end,
})

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	for player_num = 0,Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(player_num)
		local state = get_state(player,false)
		if state and state.trials and #state.trials > 0 then
			refresh_imitate(player)
		end
	end
	for _,entity in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP,PickupVariant.PICKUP_COLLECTIBLE)) do
		restore_mark_from_consistance(entity:ToPickup())
	end
end,
})

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	update_markers()
	if Game():GetRoom():GetFrameCount() < 2 then return end
	for player_num = 0,Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(player_num)
		local state = get_state(player,false)
		if state then spawn_pending_offers(player,state) end
	end
end,
})

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_PICKUP_RENDER, params = PickupVariant.PICKUP_COLLECTIBLE,
Function = function(_,pickup,render_offset)
	local m = markers[GetPtrHash(pickup)]
	if not m then return end
	local scale = get_icon_scale()
	m.sprite.Scale = Vector(scale, scale)
	local world = pickup.Position + get_icon_offset()
	m.sprite:Render(Isaac.WorldToScreen(world) + render_offset, Vector.Zero, Vector.Zero)
end,
})

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,priority = -20,
Function = function(_)
	clear_claimed_groups_for_level()
	for player_num = 0,Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(player_num)
		local state = get_state(player,false)
		if state and state.trials and #state.trials > 0 then
			local offers = state.pending_offers or {}
			local keep = {}
			local need_imitate = false
			for _,trial in ipairs(state.trials) do
				if trial.kind == "active" then
					if player_holds_active(player,trial.id) then
						player:RemoveCollectible(trial.id)
						offers[#offers + 1] = trial.id
					end
				else
					scrub_legacy_innate(player,trial.id)
					offers[#offers + 1] = trial.id
					need_imitate = true
				end
			end
			state.trials = keep
			state.pending_offers = offers
			player:GetData()[item.own_key.."active_snap"] = snapshot_actives(player)
			if need_imitate then refresh_imitate(player) end
		end
	end
end,
})

-- 向 imitate_item_holder 申报当前试用被动数量
table.insert(item.myToCall,{CallBack = enums.Callbacks.MC_EVALUATE_IMITATE_ITEM, params = nil,
Function = function(_,player,colid,value)
	local state = get_state(player,false)
	if not state then return end
	for _,trial in ipairs(state.trials or {}) do
		if trial.kind == "passive" and trial.id then
			value[trial.id] = (value[trial.id] or 0) + 1
		end
	end
end,
})

table.insert(item.myToCall,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if not continue then save.elses[state_save_key] = {} end
	markers = {}
end,
})

do
	local temp_hud = require("Qing_Remaster_scripts.callbacks.temp_item_hud_holder")
	temp_hud.register_provider(function(player)
		local state = get_state(player,false)
		if not state then return end
		local counts = {}
		-- 含主动：Extra HUD 仍会滤掉主动，EID 可通过 has_temp_collectible 识别
		for _,trial in ipairs(state.trials or {}) do
			if trial.id then
				counts[trial.id] = (counts[trial.id] or 0) + 1
			end
		end
		return counts
	end,{
		-- 与试用主动同一套 Colorize + 脉冲透明度
		color = item.hud_tint,
		color_fn = function() return item.get_hud_draw_color(1) end,
		exclusive = true,
		source_item = item.entity,
	})
end

return item
