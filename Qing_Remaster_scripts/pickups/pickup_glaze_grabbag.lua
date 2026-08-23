local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local glaze_curse = require("Qing_Remaster_scripts.pickups.pickup_glaze_curse")
local Unlocker = require("Qing_Remaster_scripts.core.unlock_manager")
local glaze_crown = require("Qing_Remaster_scripts.items.Item_Crown_of_the_Glaze")

local item = {
	pickup = enums.Pickups.Glaze_grabbag,
	ToCall = {},
	own_key = "Pickup_Glaze_Grabbag_",
	check_info = {
		Glaze_heart = {weigh = 1,check = function(player) return (player:GetSoulHearts() > 0 and player:GetBoneHearts() + player:GetSoulHearts() + player:GetHearts() > 1) end,
			get = function(player) player:AddSoulHearts(-1) end,},
		Glaze_heart_half = {weigh = 0.3,check = function(player) return (player:GetSoulHearts() > 0 and player:GetBoneHearts() + player:GetSoulHearts() + player:GetHearts() > 1) end,
			get = function(player) player:AddSoulHearts(-1) end,},
		Glaze_key = {weigh = 1,check = function(player) return (player:GetNumKeys() > 1) end,
			get = function(player) player:AddKeys(-1) end,},
		Glaze_bomb = {weigh = 1,check = function(player) return (player:GetNumBombs() > 1) end,
			get = function(player) player:AddBombs(-1) end,},
		Glaze_coin = {weigh = 0.5,check = function(player) return (player:GetNumCoins() > 5) end,
			get = function(player) player:AddCoins(-1) end,},
		Glaze_grabbag = {weigh =0.4,check = function(player) return player:HasCollectible(CollectibleType.COLLECTIBLE_SACK_HEAD) and (player:GetNumCoins() > 0) and (player:GetNumBombs() > 0) and (player:GetNumKeys() > 0) end,
			get = function(player) player:AddKeys(-1) player:AddBombs(-1) player:AddCoins(-1) end,},
		Glaze_battery = {weigh = 0.3,check = function(player,item) return (player:GetData()[item.own_key.."Battery"] == nil and auxi.get_active_charge(player) >= 1) end,
		get = function(player,item)
			player:GetData()[item.own_key.."Battery"] = true
			local charge = 1
			for i = 0,3 do
				if player:GetActiveCharge(i) > 0 and player:GetActiveCharge(i) <= 12 then
					local t_charge = player:GetActiveCharge(i) + player:GetBatteryCharge(i)
					player:SetActiveCharge(math.max(0,t_charge - charge),i)
					charge = math.max(0,charge - t_charge)
					if charge <= 0 then break end
				elseif player:GetActiveCharge(i) > 0 then
					player:SetActiveCharge(0,i)
					charge = charge - 1
					if charge <= 0 then break end
				end
			end
		end,},
		Glaze_chest = {weigh = 0.1,check = false,get = function(player) end,},
		Glaze_big_poop = {weigh = 0.3,check = function(player) return (player:GetPoopMana() > 2) end,get = function(player) player:AddPoopMana(-3) end,},
		Glaze_dice_shard = {weigh = 5,check = function(player) 
			for slot = 0,1 do
				if player:GetCard(slot) == Card.CARD_DICE_SHARD then return true end
			end
			return false 
		end,get = function(player) 
			for slot = 0,1 do
				if player:GetCard(slot) == Card.CARD_DICE_SHARD then player:SetCard(slot,0)	return end
			end
		end,},
	},
	description = {
		[CollectibleType.COLLECTIBLE_SACK_HEAD] = {desc = "有概率消耗基础各一个并再次生成琉璃化福袋",},
	},
}

function item.try_collect(player,ent)
	if ent:IsShopItem() and auxi.check_shop_pickup(ent,player) then return nil end
	local rng = ent:GetDropRNG()
	rng = auxi.rng_for_sake(rng)
	local cnt = rng:RandomInt(2) + 2
	if glaze_crown.should_empower(player) then cnt = 3 end
	local allow = {Glaze_key = true, Glaze_bomb = true, Glaze_coin = true}
	for i = 1,cnt do
		local tbl = {}
		for u,v in pairs(enums.Pickups) do
			if allow[u] then
				local info = item.check_info[u] or {}
				if auxi.check_if_any(info.check,player,item) then
					table.insert(tbl,#tbl+1,{weigh = (v.weigh or 1),name = u,})
				end
			end
		end
		if #tbl == 0 then
			if i == 1 then
				local tg = enums.Pickups.Glaze_big_poop
				local q = Isaac.Spawn(5,tg.Variant,tg.SubType,ent.Position,auxi.RoundVector(rng,3),player):ToPickup()
				auxi.special_morph(q,tg)
			end
			break
		else
			local tg = auxi.random_in_weighed_table(tbl,rng)
			if tg.name == "Glaze_bomb" and auxi.has_poop_player() then tg.name = "Glaze_big_poop" end
			local info = item.check_info[tg.name] or {}
			auxi.check_if_any(info.get,player,item)
			local ttg = enums.Pickups[tg.name]
			local q = Isaac.Spawn(5,ttg.Variant,ttg.SubType,ent.Position,auxi.RoundVector(rng,3),player):ToPickup()		--此法生成的不会被替换
			auxi.special_morph(q,ttg)
		end
	end
	player:GetData()[item.own_key.."Battery"] = nil
	auxi.try_start_ambush()
	glaze_crown.notify_pickup(player)
	return true
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = item.pickup.Variant,
Function = function(_,ent, col, low)
    local player = col:ToPlayer()
	if ent.SubType == item.pickup.SubType then
		if player then
			local should_collect = item.try_collect(player,ent)
			if should_collect == true then
				glaze_curse.cast_a_glaze(player,ent)
				ent.Velocity = Vector(0,0)
				ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_SHELLGAME,1,1,false,0,2)
				auxi.remove_others_option_pickup(ent)
				if ent:IsShopItem() then auxi.buy_a_pickup(ent,player)
				else ent:GetSprite():Play("Collect",true) end
				return true
			elseif ent:IsShopItem() then return nil 
			else return false end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = item.pickup.Variant,
Function = function(_,ent)
	if ent.SubType == item.pickup.SubType then
		if ent:GetSprite():IsEventTriggered("DropSound") then
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_FETUS_JUMP,1,1,false,0,2)
		end
		if ent:GetSprite():IsFinished("Collect") or ent:GetSprite():IsEventTriggered("Remove") then
			ent:Remove()
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = 69,
Function = function(_,ent)
	if Unlocker.should_any_be_done("Pickup","Glaze_Grabbag",nil,"Pickup_allow") then
		if ent.SubType == 1 or ent.SubType == 2 then
			local rng = ent:GetDropRNG()
			rng = auxi.rng_for_sake(rng)
			if glaze_crown.roll_convert(rng, 20) then		-- 原 1/20
				ent:Morph(5,item.pickup.Variant,item.pickup.SubType,true)
			end
		end
	end
end,
})

if EID then
	for u,v in pairs(item.description) do
		EID:addDescriptionModifier("qing_item_sync"..tostring(item.entity), function(desc) local ret = auxi.have_player_has_collectible(u) if ret then return true end end, function(desc)
			local tp = desc.ObjType
			local vr = desc.ObjVariant
			local st = desc.ObjSubType
			if (tp == 5 and vr == item.pickup.Variant and st == item.pickup.SubType and item.description[u]) then
				local info = item.description[u].desc
				if (info) then
					info = "#"..info
					local repl = "#{{Collectible"..tostring(u).."}} "
					info = string.gsub(info, "#", repl)
					EID:appendToDescription(desc, info)
				end
			end
			return desc
		end)
	end
end

glaze_crown.install_glaze_crown_pickup_eid(item.pickup, {
	zh = "辉片满层时固定生成3份（否则为2-3份）",
	en = "At 5 shards: always 3 conversions (otherwise 2-3)",
})

return item