local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local custom_price_holder = require("Qing_Remaster_scripts.callbacks.custom_price_holder")

local PICKUP_COLLECTIBLE = PickupVariant and PickupVariant.PICKUP_COLLECTIBLE or 100
local PRICE_ONE_HEART = PickupPrice and PickupPrice.PRICE_ONE_HEART or -1
local PRICE_TWO_HEARTS = PickupPrice and PickupPrice.PRICE_TWO_HEARTS or -2
local PRICE_ONE_HEART_AND_TWO_SOULHEARTS = PickupPrice and PickupPrice.PRICE_ONE_HEART_AND_TWO_SOULHEARTS or -4

local darkness_heart_sprite = Sprite()
darkness_heart_sprite:Load("gfx/ui/ui_hearts.anm2", true)
darkness_heart_sprite:Play("BlackHeartFull", true)

local item = {
	ToCall = {},
	entity = enums.Items.Darkness,
	own_key = "Item_Darkness_",
	blacken_kill_goal = 6,
	debug = false,
	seen_kills = {},
}

local soul_heart_anims = {
	BlueHeartFull = "BlackHeartFull",
	BlueHeartHalf = "BlackHeartHalf",
	SoulHeartFull = "BlackHeartFull",
	SoulHeartHalf = "BlackHeartHalf",
	["SoulHeart"] = "BlackHeartFull",
	["HalfSoulHeart"] = "BlackHeartHalf",
}

local soul_or_black_heart_anims = {
	BlueHeartFull = true,
	BlueHeartHalf = true,
	SoulHeartFull = true,
	SoulHeartHalf = true,
	["SoulHeart"] = true,
	["HalfSoulHeart"] = true,
	BlackHeartFull = true,
	BlackHeartHalf = true,
}

local function debug_print(text)
	if item.debug then
		print("[Qing Darkness] "..tostring(text))
	end
end

local function get_black_heart_count(player)
	local mask = player:GetBlackHearts()
	if mask <= 0 then return 0 end
	return auxi.Count_Flags(mask)
end

local function get_pure_soul_half_hearts(player)
	return math.max(0,player:GetSoulHearts() - get_black_heart_count(player) * 2)
end

local function has_black_heart_at(mask,index)
	if mask <= 0 then return false end
	return math.floor(mask / (2 ^ index)) % 2 == 1
end

local function get_first_pure_soul_slot(player)
	local soul_hearts = player:GetSoulHearts()
	local full_slots = math.floor(soul_hearts / 2)
	local mask = player:GetBlackHearts()
	for slot = 0,full_slots - 1 do
		if not has_black_heart_at(mask,slot) then
			return slot
		end
	end
end

local function get_half_black_slot(player)
	local soul_hearts = player:GetSoulHearts()
	if soul_hearts <= 0 or soul_hearts % 2 == 0 then return end
	local slot = math.floor(soul_hearts / 2)
	if has_black_heart_at(player:GetBlackHearts(),slot) then
		return slot
	end
end

local function set_black_heart_slot(player,slot)
	if slot == nil then return false end
	if REPENTOGON and player.SetBlackHeart then
		local half_index = slot * 2 + 1
		player:SetBlackHeart(half_index)
		return true
	end
	return false
end

local function blacken_one_soul_heart(player)
	if get_pure_soul_half_hearts(player) < 2 then return false end
	local slot = get_first_pure_soul_slot(player)
	if set_black_heart_slot(player,slot) then
		return true
	end
	player:AddSoulHearts(-2)
	player:AddBlackHearts(2)
	return true
end

local function complete_half_black_heart(player)
	if get_pure_soul_half_hearts(player) > 0 then return false end
	local slot = get_half_black_slot(player)
	if slot == nil then return false end
	player:AddSoulHearts(1)
	set_black_heart_slot(player,slot)
	return true
end

local function apply_blacken_reward(player)
	if blacken_one_soul_heart(player) then return true end
	if complete_half_black_heart(player) then return true end
	return false
end

local function remove_one_black_heart(player)
	local mask = player:GetBlackHearts()
	if mask <= 0 then return false end
	local black_infos = auxi.split_bits(mask)
	local soul_hearts = player:GetSoulHearts()
	local index = nil
	local soul_cost = 2
	for _,slot in ipairs(black_infos) do
		if soul_hearts >= slot * 2 + 2 then
			index = slot
			break
		end
	end
	if index == nil then
		for _,slot in ipairs(black_infos) do
			if soul_hearts == slot * 2 + 1 then
				index = slot
				soul_cost = 1
				break
			end
		end
	end
	if index == nil then return false end
	player:RemoveBlackHeart(index * 2 + 1)
	player:AddSoulHearts(-soul_cost)
	return true
end

local function can_pay_cost(player,cost)
	if player == nil or cost == nil then return false end
	local black = get_black_heart_count(player)
	local pure_soul = get_pure_soul_half_hearts(player)
	return black >= (cost.black or 0) and pure_soul >= (cost.soul or 0)
end

local function pay_cost(player,cost)
	if not can_pay_cost(player,cost) then return false end
	for i = 1,(cost.black or 0) do
		remove_one_black_heart(player)
	end
	player:AddSoulHearts(-(cost.soul or 0))
	Game():AddDevilRoomDeal()
	return true
end

local function is_devil_collectible(ent)
	return ent and ent.Variant == PICKUP_COLLECTIBLE and ent:IsShopItem()
		and Game():GetRoom():GetType() == RoomType.ROOM_DEVIL
end

local function get_collectible_devil_price(ent,base_price)
	local config = Isaac.GetItemConfig():GetCollectible(ent.SubType)
	if config and config.DevilPrice and config.DevilPrice > 0 then
		return config.DevilPrice
	end
	if base_price == PRICE_TWO_HEARTS then return 2 end
	if base_price == PRICE_ONE_HEART_AND_TWO_SOULHEARTS then return 2 end
	if base_price == PRICE_ONE_HEART then return 1 end
end

local function iter_darkness_players()
	local players = {}
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.has_have_coll(player,item.entity) then
			
			table.insert(players,#players + 1,player)
		end
	end
	return players
end

local function find_payer(cost)
	for _,player in ipairs(iter_darkness_players()) do
		if can_pay_cost(player,cost) then return player end
	end
end

local function make_cost(black,soul)
	black = black or 0
	soul = soul or 0
	local price_icon = nil
	if black == 1 and soul == 0 then
		price_icon = "one_black"
	elseif black == 2 and soul == 0 then
		price_icon = "two_black"
	elseif black == 1 and soul == 4 then
		price_icon = "one_black_two_soul"
	elseif black == 1 and soul == 2 then
		price_icon = "one_black_one_soul"
	end
	return {black = black,soul = soul,price_icon = price_icon,}
end

local function get_darkness_devil_cost(ent,base_price)
	if not is_devil_collectible(ent) then return end
	local devil_price = get_collectible_devil_price(ent,base_price)
	if devil_price == nil then return end
	if devil_price >= 2 then
		local two_black = make_cost(2,0)
		if find_payer(two_black) then return two_black end
		local mixed = make_cost(1,4)
		if find_payer(mixed) then return mixed end
	elseif devil_price == 1 then
		local one_black = make_cost(1,0)
		if find_payer(one_black) then return one_black end
	end
end

custom_price_holder.register_price(item.own_key.."devil_deal",{
	variant = PICKUP_COLLECTIBLE,
	check = function(ent,base_price)
		return get_darkness_devil_cost(ent,base_price)
	end,
	can_any_pay = function(ent,cost)
		return find_payer(cost) ~= nil
	end,
	can_pay = function(player,ent,cost)
		return auxi.has_have_coll(player,item.entity) and can_pay_cost(player,cost)
	end,
	pay = function(player,ent,cost)
		return pay_cost(player,cost)
	end,
})

local function get_heart_row_max(hud)
	if hud and hud.GetLayout then
		local layout = hud:GetLayout()
		if layout == 2 or layout == 3 then return 3 end
	end
	return 6
end

local function get_heart_pos(index,scale,rowmax)
	scale = scale or 1
	rowmax = rowmax or 6
	local row = math.floor((index - 1) / rowmax)
	local column = (index - 1) - row * rowmax
	return Vector(column * 12 * scale,row * 10 * scale)
end

local function get_player_hud(player)
	if player.GetPlayerHUD then return player:GetPlayerHUD() end
	if g.HUD and g.HUD.GetPlayerHUD then
		for i = 0,3 do
			local hud = g.HUD:GetPlayerHUD(i)
			if hud and hud:GetPlayer() and GetPtrHash(hud:GetPlayer()) == GetPtrHash(player) then
				return hud
			end
		end
	end
end

local function get_heart_sprite_frame(heartsSprite)
	if heartsSprite and heartsSprite.GetFrame then
		return heartsSprite:GetFrame()
	end
	return 0
end

local function render_black_heart_overlay(anim,frame,pos,alpha,heartsSprite,spriteScale)
	darkness_heart_sprite:Play(anim,true)
	darkness_heart_sprite:SetFrame(anim,frame or 0)
	darkness_heart_sprite.Color = Color(1,1,1,alpha,0,0,0)
	if heartsSprite and heartsSprite.Scale then
		darkness_heart_sprite.Scale = Vector(heartsSprite.Scale.X,heartsSprite.Scale.Y)
	elseif spriteScale then
		darkness_heart_sprite.Scale = Vector(spriteScale,spriteScale)
	else
		darkness_heart_sprite.Scale = Vector(1,1)
	end
	darkness_heart_sprite:Render(pos,Vector.Zero,Vector.Zero)
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function()
	item.seen_kills = {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function()
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local d = player:GetData()
		if auxi.has_have_coll(player,item.entity) then
			if d[item.own_key.."has_item"] ~= true then
				d[item.own_key.."has_item"] = true
				d[item.own_key.."blacken_counter"] = 0
			end
			if not REPENTOGON then
				local q = player:GetMaxHearts()
				local pltp = player:GetPlayerType()
				if pltp == 14 or pltp == 18 or pltp == 33 then
					if q > 2 then
						player:AddMaxHearts(-q + 2,true)
						player:AddBlackHearts(q - 2)
					end
				else
					if q > 0 then
						player:AddMaxHearts(-q,true)
						player:AddBlackHearts(q)
					end
				end
			end
			player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
			d.should_evaluate_on_update_once = true
		elseif d[item.own_key.."has_item"] then
			d[item.own_key.."has_item"] = nil
			d[item.own_key.."blacken_counter"] = nil
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = nil,
Function = function(_,ent,killSource)
	if ent:IsEnemy() and not ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
		local seed = ent.InitSeed or ent.DropSeed or ent.Index
		if seed and item.seen_kills[seed] then
			return
		end
		if seed then item.seen_kills[seed] = true end
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			local cnt = player:GetCollectibleNum(item.entity)
			if cnt > 0 then
				local d = player:GetData()
				d[item.own_key.."blacken_counter"] = (d[item.own_key.."blacken_counter"] or 0) + 1
				while d[item.own_key.."blacken_counter"] >= item.blacken_kill_goal do
					if apply_blacken_reward(player) then
						d[item.own_key.."blacken_counter"] = d[item.own_key.."blacken_counter"] - item.blacken_kill_goal
					else
						d[item.own_key.."blacken_counter"] = item.blacken_kill_goal - 1
						break
					end
				end
			end
		end
	end
end,
})

if REPENTOGON and ModCallbacks.MC_POST_PLAYERHUD_RENDER_HEARTS then
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYERHUD_RENDER_HEARTS, params = nil,
Function = function(_,offset,heartsSprite,position,spriteScale,player)
	if player == nil or not auxi.has_have_coll(player,item.entity) then return end
	local progress = player:GetData()[item.own_key.."blacken_counter"] or 0
	if progress <= 0 then return end
	local alpha = math.min(0.9,math.max(0.18,progress / item.blacken_kill_goal))
	local hud = get_player_hud(player)
	if hud == nil then return end
	local hearts = hud:GetHearts()
	local rowmax = get_heart_row_max(hud)
	local target_slot = get_first_pure_soul_slot(player)
	local target_is_half_black = false
	if target_slot == nil then
		target_slot = get_half_black_slot(player)
		target_is_half_black = target_slot ~= nil
	end
	if target_slot == nil then return end
	local soul_slot = -1
	local frame = get_heart_sprite_frame(heartsSprite)
	for i,heart in ipairs(hearts) do
		if heart:IsVisible() then
			local anim = heart:GetHeartAnim()
			local overlay_anim = soul_heart_anims[anim]
			if soul_or_black_heart_anims[anim] then
				soul_slot = soul_slot + 1
				if soul_slot == target_slot and (overlay_anim or target_is_half_black) then
					render_black_heart_overlay(overlay_anim or "BlackHeartFull",frame,position + get_heart_pos(i,spriteScale,rowmax),alpha,heartsSprite,spriteScale)
					break
				end
			end
		end
	end
end,
})
end

if REPENTOGON and ModCallbacks.MC_PLAYER_GET_HEALTH_TYPE then
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PLAYER_GET_HEALTH_TYPE, params = nil,
Function = function(_,player,currentHealthType,defaultHealthType)
	if auxi.has_have_coll(player,item.entity) then
		return (HealthType and HealthType.SOUL) or 1
	end
end,
})
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if auxi.has_have_coll(player,item.entity) then
		local cnt = player:GetCollectibleNum(item.entity)
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			local q1 = get_black_heart_count(player)
			player.Damage = player.Damage * (1 + q1 * 0.003) + q1 * 0.8 * (cnt + 3)/4 * auxi.get_damage_multiplier(player)
        end
		if cacheFlag == CacheFlag.CACHE_TEARCOLOR then
            player.TearColor = auxi.AddColor(player.TearColor,Color(1,1,1,1,-0.5,-0.5,-0.5),0,1)
            player.LaserColor = auxi.AddColor(player.LaserColor,Color(1,1,1,1,-0.5,-0.5,-0.5),0,1)
        end
	end
end,
})

return item
