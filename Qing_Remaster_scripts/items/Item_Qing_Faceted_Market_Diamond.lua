local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")
local selection_holder = require("Qing_Remaster_scripts.others.selection_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	entity = enums.Items.Qing_Faceted_Market_Diamond,
	merchant = enums.Slots.Qing_Diamond_Merchant,
	own_key = "Item_Qing_Faceted_Market_Diamond_",
	base_price = 5,
	min_price = 1,
	max_sale = 99,
	default_merchant_chance = 0.5,
	trade_range = 48,
	-- 小于此距离视为与商人重叠；成交前需先离开重叠再撞上，避免刚靠近就卖掉
	touch_range = 28,
	dir_time_limit = 12,
	last_open_dir = 9,
	-- 头顶议价 UI 默认布局（可被 ImGui Debug 覆盖）
	hud_defaults = {
		BaseOffsetX = 4,
		BaseOffsetY = -50,
		IconOffsetX = -20,
		IconOffsetY = 17.5,
		IconScale = 0.5,
		ArrowOffsetX = -10,
		ArrowOffsetY = -2,
		ArrowScale = 1.0,
		DigitTensOffsetX = 3,
		DigitOnesOffsetX = 9.0,
		DigitOffsetY = -2,
		DigitScale = 1.0,
		CentOffsetX = 20,
		CentOffsetY = 8,
		CentScale = 0.5,
	},
	_diamond_hud_sprite = nil,
	_coin_hud_sprite = nil,
}

local function debug_root()
	local root = save.ModConfigSettings
	local options = root and root.QingRemasterOptions
	return options and options.Debug
end

function item.get_merchant_chance()
	local debug = debug_root()
	local value = tonumber(debug and debug.DiamondMerchantChance)
	if value == nil then value = item.default_merchant_chance end
	return math.max(0,math.min(1,value))
end

local function debug_number(key, default, min_value, max_value)
	local debug = debug_root()
	local value = tonumber(debug and debug[key])
	if value == nil then value = default end
	if min_value ~= nil then value = math.max(min_value,value) end
	if max_value ~= nil then value = math.min(max_value,value) end
	return value
end

function item.get_hud_layout()
	local d = item.hud_defaults
	return {
		base = Vector(
			debug_number("DiamondHudBaseOffsetX",d.BaseOffsetX,-120,120),
			debug_number("DiamondHudBaseOffsetY",d.BaseOffsetY,-160,80)
		),
		icon = Vector(
			debug_number("DiamondHudIconOffsetX",d.IconOffsetX,-80,80),
			debug_number("DiamondHudIconOffsetY",d.IconOffsetY,-80,80)
		),
		icon_scale = debug_number("DiamondHudIconScale",d.IconScale,0.1,2),
		arrow = Vector(
			debug_number("DiamondHudArrowOffsetX",d.ArrowOffsetX,-80,80),
			debug_number("DiamondHudArrowOffsetY",d.ArrowOffsetY,-80,80)
		),
		arrow_scale = debug_number("DiamondHudArrowScale",d.ArrowScale,0.2,3),
		digit_tens_x = debug_number("DiamondHudDigitTensOffsetX",d.DigitTensOffsetX,-80,80),
		digit_ones_x = debug_number("DiamondHudDigitOnesOffsetX",d.DigitOnesOffsetX,-80,80),
		digit_y = debug_number("DiamondHudDigitOffsetY",d.DigitOffsetY,-80,80),
		digit_scale = debug_number("DiamondHudDigitScale",d.DigitScale,0.2,3),
		cent = Vector(
			debug_number("DiamondHudCentOffsetX",d.CentOffsetX,-80,80),
			debug_number("DiamondHudCentOffsetY",d.CentOffsetY,-80,80)
		),
		cent_scale = debug_number("DiamondHudCentScale",d.CentScale,0.2,3),
	}
end

local function get_diamond_hud_sprite()
	if item._diamond_hud_sprite then return item._diamond_hud_sprite end
	local sprite = Sprite()
	sprite:Load("gfx/005.100_collectible.anm2",false)
	if EntityPickup.SetupCollectibleGraphics then
		EntityPickup.SetupCollectibleGraphics(sprite,1,item.entity,false,1,true)
	else
		local cfg = Isaac.GetItemConfig():GetCollectible(item.entity)
		if cfg and cfg.GfxFileName then
			sprite:ReplaceSpritesheet(1,cfg.GfxFileName)
			sprite:LoadGraphics()
		end
	end
	sprite:Play(sprite:GetDefaultAnimation(),true)
	sprite:SetFrame(0)
	item._diamond_hud_sprite = sprite
	return sprite
end

-- 与忒修斯印记相同：penny anm2 作硬币图标
local function get_coin_hud_sprite()
	if item._coin_hud_sprite then return item._coin_hud_sprite end
	local sprite = Sprite()
	sprite:Load("gfx/005.021_penny.anm2",true)
	sprite:Play("Idle",true)
	item._coin_hud_sprite = sprite
	return sprite
end

local DIR_LEFT = 4
local DIR_RIGHT = 5
local DIR_UP = 6
local DIR_DOWN = 7
local DIR_ITEM = 9
local DIR_DROP = 11

local function merchant_rooms_key()
	return item.own_key.."merchant_rooms"
end

-- 跨局永久字段：必须用 PermanentData（elses 属 RUN，新开局会清）
local function permanent_bag()
	local key = item.own_key.."data"
	save.PermanentData = save.PermanentData or {}
	-- 兼容曾误写入 elses 的旧档
	if save.PermanentData[key] == nil and save.elses then
		local legacy_price = save.elses[item.own_key.."shop_price"]
		local legacy_sale = save.elses[item.own_key.."last_sale"]
		if legacy_price ~= nil or legacy_sale ~= nil then
			save.PermanentData[key] = {
				shop_price = legacy_price,
				last_sale = legacy_sale,
			}
			save.elses[item.own_key.."shop_price"] = nil
			save.elses[item.own_key.."last_sale"] = nil
		end
	end
	save.PermanentData[key] = save.PermanentData[key] or {}
	return save.PermanentData[key]
end

function item.get_shop_price()
	local p = tonumber(permanent_bag().shop_price)
	if p == nil then return item.base_price end
	return math.max(0,math.min(item.max_sale,math.floor(p)))
end

function item.set_shop_price(price)
	price = math.max(0,math.min(item.max_sale,math.floor(tonumber(price) or item.base_price)))
	permanent_bag().shop_price = price
	local debug = debug_root()
	if debug then debug.DiamondShopPrice = price end
	price_holder.reset_price()
end

function item.halve_shop_price()
	local cur = item.get_shop_price()
	-- 向下取整；商店价默认不低于 1
	local next_price = math.max(item.min_price,math.floor(cur / 2))
	item.set_shop_price(next_price)
end

function item.get_last_sale_price()
	local p = tonumber(permanent_bag().last_sale)
	if p == nil then return item.get_shop_price() end
	return math.max(0,math.min(item.max_sale,math.floor(p)))
end

function item.set_last_sale_price(price)
	permanent_bag().last_sale = math.max(0,math.min(item.max_sale,math.floor(tonumber(price) or 0)))
end

local function any_player_has_diamond()
	return auxi.have_player_has_collectible(item.entity)
end

local function diamond_count(player)
	if not player then return 0 end
	return player:GetCollectibleNum(item.entity) or 0
end

local function iter_shop_diamonds()
	local list = {}
	for _,ent in pairs(auxi.getothers(nil,5,100,item.entity) or {}) do
		local pickup = ent:ToPickup()
		if pickup and pickup:IsShopItem() and (pickup.Price or 0) ~= 0 then
			list[#list + 1] = pickup
		end
	end
	return list
end

-- 已因「遇见未购买」处理过的同一底座（InitSeed）不再减半，防反复进出刷价
local function mark_skip_halve(pickup)
	local d = pickup:GetData()
	d._Data = d._Data or {}
	d._Data[item.own_key] = d._Data[item.own_key] or {}
	d._Data[item.own_key].skipped = true
	consistance_holder.try_hold_entity(pickup,item.own_key,{keep_level = true,})
end

local function already_skip_halved(pickup)
	if consistance_holder.try_check_entity(pickup,item.own_key) then
		local info = pickup:GetData()._Data and pickup:GetData()._Data[item.own_key]
		return info and info.skipped == true
	end
	return false
end

local function merchant_variant()
	local v = item.merchant and item.merchant.Variant
	if type(v) == "number" and v >= 0 then return v end
	v = Isaac.GetEntityVariantByName("Qing Diamond Merchant")
	if item.merchant then item.merchant.Variant = v end
	return v
end

local function find_merchant()
	local variant = merchant_variant()
	if type(variant) ~= "number" or variant < 0 then return nil end
	local list = auxi.getothers(nil,6,variant) or {}
	for _,ent in pairs(list) do
		if ent and ent:Exists() then return ent end
	end
	return nil
end

local function merchant_is_idle(ent)
	if not ent or not ent:Exists() then return false end
	local s = ent:GetSprite()
	return s:IsPlaying("Idle")
end

local function merchant_data(ent)
	local d = ent:GetData()
	d[item.own_key.."slot"] = d[item.own_key.."slot"] or {}
	return d[item.own_key.."slot"]
end

local function find_player_by_hash(hash)
	if not hash then return nil end
	for i = 0,Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if p and p:Exists() and GetPtrHash(p) == hash then
			return p
		end
	end
	return nil
end

local function nearest_merchant(player)
	local best,best_dist = nil,nil
	local variant = merchant_variant()
	if type(variant) ~= "number" or variant < 0 then return nil,nil end
	local list = auxi.getothers(nil,6,variant) or {}
	for _,ent in pairs(list) do
		if ent and ent:Exists() then
			local dist = player.Position:Distance(ent.Position)
			if best_dist == nil or dist < best_dist then
				best = ent
				best_dist = dist
			end
		end
	end
	return best,best_dist
end

local function is_near_door(room,pos,clear)
	clear = clear or 80
	local max_slot = DoorSlot.NUM_DOOR_SLOTS or 8
	for slot = 0,max_slot - 1 do
		if room:GetDoor(slot) then
			if room:GetDoorSlotPosition(slot):Distance(pos) < clear then
				return true
			end
		end
	end
	return false
end

-- 从右下靠墙起找空位：优先靠近右下，避开门口
local function find_merchant_spawn_pos(room)
	local br = room:GetBottomRightPos()
	local tl = room:GetTopLeftPos()
	-- 往房间内侧收一点，避免贴在墙碰撞里导致 FindFree 失效
	local prefer = Vector(
		math.max(tl.X + 40,br.X - 80),
		math.max(tl.Y + 40,br.Y - 80)
	)
	local best_pos,best_score = nil,nil
	local function consider(pos,door_clear)
		if not pos then return end
		if not room:IsPositionInRoom(pos,16) then return end
		if is_near_door(room,pos,door_clear) then return end
		local score = pos:Distance(prefer)
		if best_score == nil or score < best_score then
			best_score = score
			best_pos = pos
		end
	end

	-- 1) 从右下偏好点螺旋找空位
	for _,step in ipairs({0,20,40,60,80,120}) do
		consider(room:FindFreePickupSpawnPosition(prefer,step,true),70)
	end
	if best_pos then return best_pos end

	-- 2) 扫格：取离右下最近的可行走格，再 FindFree
	for i = 0,room:GetGridSize() - 1 do
		if room:GetGridCollision(i) == GridCollisionClass.COLLISION_NONE then
			local gpos = room:GetGridPosition(i)
			if room:IsPositionInRoom(gpos,0) and not is_near_door(room,gpos,70) then
				local score = gpos:Distance(prefer)
				if best_score == nil or score < best_score then
					best_score = score
					best_pos = gpos
				end
			end
		end
	end
	if best_pos then
		return room:FindFreePickupSpawnPosition(best_pos,0,true)
	end

	-- 3) 放宽门口后再螺旋
	best_pos,best_score = nil,nil
	for _,step in ipairs({0,40,80,120}) do
		consider(room:FindFreePickupSpawnPosition(prefer,step,true),40)
	end
	if best_pos then return best_pos end

	return room:FindFreePickupSpawnPosition(prefer,40,true)
end

local function ensure_merchant_spawn()
	if Game():GetRoom():GetType() ~= RoomType.ROOM_SHOP then return end
	if not any_player_has_diamond() then return end
	local variant = merchant_variant()
	if type(variant) ~= "number" or variant < 0 then return end
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if not desc then return end
	local list_index = desc.ListIndex
	save.elses = save.elses or {}
	save.elses[merchant_rooms_key()] = save.elses[merchant_rooms_key()] or {}
	local bag = save.elses[merchant_rooms_key()]
	local chance = item.get_merchant_chance()
	-- 概率拉满时覆盖本房间先前“未出现”的锁定，便于调试/保证必出
	if chance >= 1 then
		bag[list_index] = true
	elseif bag[list_index] == nil then
		-- 仅在持有钻石时掷骰；未持有时进入商店不预先锁死结果
		local rng = RNG()
		rng:SetSeed(desc.SpawnSeed or Game():GetSeeds():GetStartSeed(),35)
		bag[list_index] = rng:RandomFloat() < chance
	end
	if bag[list_index] ~= true then return end
	if find_merchant() then return end
	local room = Game():GetRoom()
	local pos = find_merchant_spawn_pos(room)
	local ent = Isaac.Spawn(6,variant,0,pos,Vector(0,0),nil)
	if not (ent and ent:Exists()) then
		Isaac.Spawn(6,variant,0,room:FindFreePickupSpawnPosition(room:GetCenterPos(),40,true),Vector(0,0),nil)
	end
end

local function end_trade(player,hide)
	local d = player:GetData()
	if hide and player:IsHoldingItem() then
		player:AnimateCollectible(item.entity,"HideItem","PlayerPickup")
	end
	selection_holder.remove_select(player,item.own_key)
	d[item.own_key.."trade"] = nil
	d[item.own_key.."lift"] = nil
	d[item.own_key.."digit"] = nil
	d[item.own_key.."price"] = nil
	d[item.own_key.."need_sep"] = nil
	d[item.own_key.."merchant_ptr"] = nil
end

local function begin_trade(player,merchant)
	local d = player:GetData()
	if d[item.own_key.."blocked"] then return end
	if diamond_count(player) <= 0 then return end
	d[item.own_key.."trade"] = true
	d[item.own_key.."lift"] = true
	d[item.own_key.."digit"] = 0 -- 0=个位, 1=十位
	d[item.own_key.."price"] = item.get_last_sale_price()
	d[item.own_key.."merchant_ptr"] = GetPtrHash(merchant)
	-- 调价后再撞上才成交：若开议时已重叠，须先分开
	d[item.own_key.."need_sep"] = true
	item.last_open_dir = 9
	item.last_open_dir_counter = 0
end

local function adjust_digit(price,digit,delta)
	local ones = price % 10
	local tens = math.floor(price / 10) % 10
	if digit == 0 then
		ones = (ones + delta) % 10
		if ones < 0 then ones = ones + 10 end
	else
		tens = (tens + delta) % 10
		if tens < 0 then tens = tens + 10 end
	end
	return tens * 10 + ones
end

local function merchant_by_hash(hash)
	if not hash then return nil end
	local list = auxi.getothers(nil,6,item.merchant.Variant) or {}
	for _,ent in pairs(list) do
		if ent and ent:Exists() and GetPtrHash(ent) == hash then
			return ent
		end
	end
	return nil
end

-- 确认成交：先收钻石并播 PayPrize→Prize，钱在 Prize 结束时发放
local function confirm_sale(player)
	local d = player:GetData()
	local count_before = diamond_count(player)
	if count_before <= 0 then
		end_trade(player,true)
		return
	end
	local merchant = merchant_by_hash(d[item.own_key.."merchant_ptr"]) or find_merchant()
	if not merchant or not merchant_is_idle(merchant) then
		return
	end
	local sale = math.max(0,math.min(item.max_sale,math.floor(tonumber(d[item.own_key.."price"]) or 0)))
	player:RemoveCollectible(item.entity)
	local md = merchant_data(merchant)
	md.deal = {
		sale = sale,
		player_hash = GetPtrHash(player),
		remain = count_before - 1,
		count_before = count_before,
	}
	merchant:GetSprite():Play("PayPrize",true)
	-- 成交后不设 blocked：商人非 Idle 时本身无法再举起；Idle 后可连售
	end_trade(player,true)
end

local function finish_deal_payout(ent)
	local md = merchant_data(ent)
	local deal = md.deal
	if not deal then return false end
	md.deal = nil
	local sale = math.max(0,math.min(item.max_sale,math.floor(tonumber(deal.sale) or 0)))
	local player = find_player_by_hash(deal.player_hash)
	if player and player:Exists() then
		if sale > 0 then
			player:AddCoins(sale)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_CASH_REGISTER,1,1,false,0,2)
		else
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_PENNYPICKUP,1,1,false,0,2)
		end
	end
	item.set_last_sale_price(sale)
	local count_before = tonumber(deal.count_before) or 1
	if count_before > 1 then
		item.set_shop_price(math.max(item.get_shop_price(),sale))
	else
		item.set_shop_price(sale)
	end
	local remain = tonumber(deal.remain) or 0
	if player and player:Exists() then
		remain = math.max(remain,diamond_count(player))
	end
	return remain > 0
end

-- 商店钻石售价：使用永久价
table.insert(item.pre_myToCall,#item.pre_myToCall + 1,{CallBack = enums.Callbacks.PRE_CHECK_PRICE, params = 100,
Function = function(_,ent,val)
	if ent.Variant == 100 and ent.SubType == item.entity and ent:IsShopItem() and (val or 0) > 0 then
		return item.get_shop_price()
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = 100,
Function = function(_,ent)
	if ent.SubType == item.entity and ent:IsShopItem() and (ent.Price or 0) > 0 then
		price_holder.try_catch_price(ent)
		-- 恢复跨房间一致性标记（是否已因未购买减过价）
		consistance_holder.try_check_entity(ent,item.own_key)
	end
end,
})

-- 离开房间时：仍在的商店钻石若尚未标记，则减半一次并记入 Consistance（防同一底座刷价）
table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_ROOM, params = nil,
Function = function(_)
	for _,pickup in ipairs(iter_shop_diamonds()) do
		if not already_skip_halved(pickup) then
			mark_skip_halve(pickup)
			item.halve_shop_price()
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	-- 售价/上次成交价在 PermanentData，跨局保留；仅本局商店掷骰表走 elses
	local bag = permanent_bag()
	if bag.shop_price == nil then bag.shop_price = item.base_price end
	if bag.last_sale == nil then bag.last_sale = bag.shop_price end
	if not continue then
		save.elses[merchant_rooms_key()] = {}
	else
		save.elses[merchant_rooms_key()] = save.elses[merchant_rooms_key()] or {}
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	ensure_merchant_spawn()
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = nil,
Function = function(_,player,collid,cnt)
	if collid == item.entity then
		ensure_merchant_spawn()
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_INIT, params = enums.Slots.Qing_Diamond_Merchant.Variant,
Function = function(_,ent)
	local s = ent:GetSprite()
	s.Offset = Vector(0,5)
	s:Play("Idle",true)
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_UPDATE, params = enums.Slots.Qing_Diamond_Merchant.Variant,
Function = function(_,ent)
	local s = ent:GetSprite()
	if s:IsFinished("Teleport") then
		ent:Remove()
		return
	end
	if s:IsFinished("PayPrize") then
		s:Play("Prize",true)
		return
	end
	if s:IsFinished("Prize") then
		local keep = finish_deal_payout(ent)
		if keep then
			s:Play("Idle",true)
		else
			s:Play("Teleport",true)
			ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
		end
		return
	end
	if s:IsFinished("PayNothing") then
		s:Play("Idle",true)
	end
end,
})

-- 调价完成后撞上商人成交（不需按空格/道具键）
table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_COLLISION, params = enums.Slots.Qing_Diamond_Merchant.Variant,
Function = function(_,ent,col,low)
	if not merchant_is_idle(ent) then return end
	local player = col and col:ToPlayer()
	if not player then return end
	local d = player:GetData()
	if not d[item.own_key.."trade"] then return end
	if d[item.own_key.."need_sep"] or d[item.own_key.."lift"] then return end
	if not player:IsHoldingItem() then return end
	if not selection_holder.check_select(player,item.own_key) then return end
	if d[item.own_key.."merchant_ptr"] and GetPtrHash(ent) ~= d[item.own_key.."merchant_ptr"] then return end
	confirm_sale(player)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_INPUT_ACTION, params = nil,
Function = function(_,ent,hook,button)
	if ent == nil then return end
	local player = ent:ToPlayer()
	if not player then return end
	local d = player:GetData()
	if d[item.own_key.."trade"] and selection_holder.check_select(player,item.own_key) then
		for _,i in pairs({DIR_LEFT,DIR_RIGHT,DIR_UP,DIR_DOWN,DIR_ITEM,DIR_DROP}) do
			if button == i and (hook == InputHook.IS_ACTION_TRIGGERED or hook == InputHook.IS_ACTION_PRESSED) then
				return false
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local ctrlid = player.ControllerIndex
	local merchant,dist = nearest_merchant(player)
	local in_range = merchant and dist and dist <= item.trade_range

	-- 暂时取消 / 主动结束：必须离开范围后再进入才会重新举起
	if d[item.own_key.."blocked"] and not in_range then
		d[item.own_key.."blocked"] = nil
	end

	if d[item.own_key.."trade"] then
		if diamond_count(player) <= 0 or not in_range or not merchant or not merchant_is_idle(merchant) then
			local merchant_busy = merchant and not merchant_is_idle(merchant)
			end_trade(player,true)
			-- 成交动画中结束不 blocked（便于播完连售）；仍在范围内的其他中断须离开后再举
			if in_range and not merchant_busy then
				d[item.own_key.."blocked"] = true
			end
			return
		end
		-- 已离开重叠后，下次撞上即可成交
		if d[item.own_key.."need_sep"] and dist and dist > item.touch_range then
			d[item.own_key.."need_sep"] = nil
		end
		if d[item.own_key.."lift"] and player:IsExtraAnimationFinished() then
			player:AnimateCollectible(item.entity,"LiftItem","PlayerPickup")
			selection_holder.check_and_try_select(player,item.own_key)
			d[item.own_key.."lift"] = nil
		end
		if not d[item.own_key.."lift"] then
			if player:IsHoldingItem() == false then
				end_trade(player,false)
				d[item.own_key.."blocked"] = true
			elseif selection_holder.check_select(player,item.own_key) and Game():IsPaused() == false then
				local dir = nil
				for _,i in pairs({DIR_LEFT,DIR_RIGHT,DIR_UP,DIR_DOWN,DIR_ITEM,DIR_DROP}) do
					if Input.IsActionTriggered(i,ctrlid) or Input.IsActionPressed(i,ctrlid) then
						dir = i
					end
				end
				local should_count = false
				if dir then
					if dir == DIR_DROP then
						-- Ctrl / 丢弃键：取消议价
						end_trade(player,true)
						d[item.own_key.."blocked"] = true
						item.last_open_dir = dir
						return
					end
					if dir == DIR_ITEM then
						-- 空格不再确认，仅吞掉输入以免误用主动道具
						item.last_open_dir = dir
						return
					end
					if dir == item.last_open_dir then
						item.last_open_dir_counter = (item.last_open_dir_counter or 0) + 1
						if item.last_open_dir_counter > item.dir_time_limit and item.last_open_dir_counter % 8 == 1 then
							should_count = true
						end
					else
						item.last_open_dir_counter = 0
						should_count = true
					end
				end
				item.last_open_dir = dir
				if should_count and dir then
					local price = math.max(0,math.min(item.max_sale,math.floor(tonumber(d[item.own_key.."price"]) or 0)))
					local digit = d[item.own_key.."digit"] or 0
					if dir == DIR_LEFT or dir == DIR_RIGHT then
						digit = 1 - digit
						d[item.own_key.."digit"] = digit
						sound_tracker.PlayStackedSound(194,1,1,false,0,2)
					elseif dir == DIR_UP then
						d[item.own_key.."price"] = adjust_digit(price,digit,1)
						sound_tracker.PlayStackedSound(195,1,1,false,0,2)
					elseif dir == DIR_DOWN then
						d[item.own_key.."price"] = adjust_digit(price,digit,-1)
						sound_tracker.PlayStackedSound(195,1,1,false,0,2)
					end
				end
			end
		end
		return
	end

	if in_range and not d[item.own_key.."blocked"] and diamond_count(player) > 0
		and player:IsExtraAnimationFinished() and merchant_is_idle(merchant) then
		begin_trade(player,merchant)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	local d = player:GetData()
	if not (d[item.own_key.."trade"] and player:IsHoldingItem() and selection_holder.check_select(player,item.own_key)) then
		return
	end
	local price = math.max(0,math.min(item.max_sale,math.floor(tonumber(d[item.own_key.."price"]) or 0)))
	local digit = d[item.own_key.."digit"] or 0
	local tens = math.floor(price / 10) % 10
	local ones = price % 10
	local layout = item.get_hud_layout()
	local base = Isaac.WorldToScreen(player.Position) + layout.base
	-- 未选中：淡黄；选中：更亮的黄
	local col_dim = KColor(0.78,0.7,0.35,1)
	local col_lit = KColor(1,0.95,0.35,1)
	local col_arrow = KColor(0.9,0.9,0.9,1)

	local icon = get_diamond_hud_sprite()
	icon.Scale = Vector(layout.icon_scale,layout.icon_scale)
	icon.Color = Color(1,1,1,1)
	icon:Render(base + layout.icon,Vector.Zero,Vector.Zero)

	gui.draw_ch(base + layout.arrow,"→",layout.arrow_scale,layout.arrow_scale,col_arrow,true)
	gui.draw_ch(
		base + Vector(layout.digit_tens_x,layout.digit_y),
		tostring(tens),
		layout.digit_scale,layout.digit_scale,
		digit == 1 and col_lit or col_dim,
		true
	)
	gui.draw_ch(
		base + Vector(layout.digit_ones_x,layout.digit_y),
		tostring(ones),
		layout.digit_scale,layout.digit_scale,
		digit == 0 and col_lit or col_dim,
		true
	)

	local coin = get_coin_hud_sprite()
	coin.Scale = Vector(layout.cent_scale,layout.cent_scale)
	coin.Color = Color(1,1,1,1)
	coin:Render(base + layout.cent,Vector.Zero,Vector.Zero)
end,
})

return item
