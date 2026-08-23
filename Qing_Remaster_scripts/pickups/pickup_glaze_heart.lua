local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Unlocker = require("Qing_Remaster_scripts.core.unlock_manager")
local glaze_curse = require("Qing_Remaster_scripts.pickups.pickup_glaze_curse")
local Heart_holder = require("Qing_Remaster_scripts.mimics.Heart_holder")
local glaze_crown = require("Qing_Remaster_scripts.items.Item_Crown_of_the_Glaze")

local item = {
	pickup = enums.Pickups.Glaze_heart,
	pickup2 = enums.Pickups.Glaze_heart_half,
	ToCall = {},
	Banishedlist = {
		["RED_HEART"] = true,
		["COIN_HEART"] = true,
		["ROTTEN_HEART"] = true,
		["SOUL_HEART"] = true,
		["BLACK_HEART"] = true,
		["EMPTY_HEART"] = true,
		["EMPTY_COIN_HEART"] = true,
		["BONE_HEART"] = true,
		["BROKEN_HEART"] = true,
		["BROKEN_COIN_HEART"] = true,
		["ETERNAL_HEART"] = true,
		["GOLDEN_HEART"] = true,
	},
}

function item.try_collect(player,ent,toHeal)
	if ent:IsShopItem() and auxi.check_shop_pickup(ent,player) then return nil end
	local succ = false
	local toplay = {id = SoundEffect.SOUND_HOLY,vol = 1,pit = 1}
	for i = 1,1 do if CustomHealthAPI then
		if CustomHealthAPI.Library and CustomHealthAPI.PersistentData and CustomHealthAPI.PersistentData.HealthDefinitions then
			for u,v in pairs(CustomHealthAPI.PersistentData.HealthDefinitions) do
				if not item.Banishedlist[u] and CustomHealthAPI.Library.GetHPOfKey(player,u) > 0 then 
					CustomHealthAPI.Library.AddHealth(player,u,toHeal) succ = true 
					local info = CustomHealthAPI.Library.GetInfoOfKey(v,"SumptoriumCollectSoundSettings")
					if info then toplay.id = info.ID toplay.vol = info.Volume toplay.pit = info.Pitch end
				break end
			end
		end
	end end
	if succ then
	elseif player:GetBrokenHearts() > 0 then
		player:AddBrokenHearts(-1)
		if toHeal == 2 then player:AddSoulHearts(1)	end
	elseif player:GetRottenHearts() > 0 then
		player:AddRottenHearts(-1)
		if toHeal == 1 then	player:AddHearts(-1) end
	elseif player:GetEternalHearts() > 0 and math.random(1000) > 900 then
		player:AddEternalHearts(1)
		if toHeal == 2 then	player:AddSoulHearts(1) end
		toplay.id = SoundEffect.SOUND_SUPERHOLY
	elseif player:GetBlackHearts() > 0 and player:CanPickBlackHearts() and math.random(1000) > 700 then
		if toHeal == 2 then	player:AddSoulHearts(1) end
		player:AddBlackHearts(1)
		Heart_holder.add_soul_buff(player,toHeal)
	elseif player:GetBoneHearts() > 0 and player:CanPickBoneHearts() and math.random(1000) > 950 then
		player:AddBoneHearts(1)
		toplay.id = SoundEffect.SOUND_BONE_HEART
	elseif player:GetGoldenHearts() > 0 and player:CanPickGoldenHearts() and math.random(1000) > 600 then
		player:AddGoldenHearts(1)
		toplay.id = SoundEffect.SOUND_GOLD_HEART
	elseif player:GetSoulHearts() > 0 and player:CanPickSoulHearts() and math.random(1000) > 700 then
		player:AddSoulHearts(toHeal)
		Heart_holder.add_soul_buff(player,toHeal)
	elseif player:CanPickRedHearts() then
		player:AddHearts(toHeal)
		Heart_holder.add_heart_buff(player,toHeal)
		toplay.id = SoundEffect.SOUND_BOSS2_BUBBLES
	elseif player:GetSoulHearts() > 0 and player:CanPickSoulHearts() then
		player:AddSoulHearts(toHeal)
		Heart_holder.add_soul_buff(player,toHeal)
	elseif player:GetBlackHearts() > 0 and player:CanPickBlackHearts() then
		if toHeal == 2 then	player:AddSoulHearts(1) end
		player:AddBlackHearts(1)
		Heart_holder.add_soul_buff(player,toHeal)
	elseif player:GetGoldenHearts() > 0 and player:CanPickGoldenHearts() then
		player:AddGoldenHearts(1)
		toplay.id = SoundEffect.SOUND_GOLD_HEART
	elseif player:GetBoneHearts() > 0 and player:CanPickBoneHearts() then
		player:AddBoneHearts(1)
		toplay.id = SoundEffect.SOUND_BONE_HEART
	elseif player:GetEternalHearts() > 0 then
		player:AddEternalHearts(1)
		if toHeal == 2 then	player:AddSoulHearts(1)	end
		toplay.id = SoundEffect.SOUND_SUPERHOLY
	else return nil end
	sound_tracker.PlayStackedSound(toplay.id,toplay.vol,toplay.pit,false,0,2)
	glaze_crown.notify_pickup(player)
	return true
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = item.pickup.Variant,
Function = function(_,ent, col, low)
    local player = col:ToPlayer()
	if ent.SubType == item.pickup.SubType or ent.SubType == item.pickup2.SubType then
		if player then
			local pinkType = ent.SubType
			local toHeal = 0
			if pinkType == item.pickup2.SubType then
				toHeal = 1
			elseif pinkType == item.pickup.SubType then
				toHeal = 2
			end
			local should_collect = item.try_collect(player,ent,toHeal)
			if should_collect == true then
				glaze_curse.cast_a_glaze(player,ent)ent.Velocity = Vector(0,0)
				ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
				auxi.remove_others_option_pickup(ent)
				if ent:IsShopItem() then auxi.buy_a_pickup(ent,player)
				else ent:GetSprite():Play("Collect", true) end
				return true
			elseif ent:IsShopItem() then return nil 
			else return false end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = item.pickup.Variant,
Function = function(_,ent)
	if ent.SubType == item.pickup.SubType or ent.SubType == item.pickup2.SubType then
		if ent:GetSprite():IsEventTriggered("DropSound") then
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MEAT_FEET_SLOW0,1,1,false,0,2)
		end
		if ent:GetSprite():IsFinished("Collect") or ent:GetSprite():IsEventTriggered("Remove")  then
			ent:Remove()
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = 10,
Function = function(_,ent)
	if Unlocker.should_any_be_done("Pickup","Glaze_Heart",nil,"Pickup_allow") then
		if ent.SubType == 1 or ent.SubType == 2 or ent.SubType == 3 or ent.SubType == 8 or ent.SubType == 9 or ent.SubType == 10 then
			local rng = ent:GetDropRNG()
			rng = auxi.rng_for_sake(rng)
			local convert = glaze_crown.roll_convert(rng, 25)		-- 原 1/25
			for playerNum = 1, Game():GetNumPlayers() do
				local player = Game():GetPlayer(playerNum - 1)
				if player:GetBrokenHearts() > 0 and convert then		--每一个角色拥有碎心，转化率下降80%。
					convert = rng:RandomInt(5) == 0
				end
			end
			if convert then
				if (ent.SubType == 2 or ent.SubType == 8) and not glaze_crown.any_complete() then
					ent:Morph(5,item.pickup2.Variant,item.pickup2.SubType,true)
				else
					ent:Morph(5,item.pickup.Variant,item.pickup.SubType,true)
				end
			end
		end
		if ent.SubType == item.pickup2.SubType then
			if glaze_crown.any_complete() then
				ent:Morph(5,item.pickup.Variant,item.pickup.SubType,true)
			end
		end
	end
end,
})

glaze_crown.install_glaze_crown_pickup_eid(item.pickup, {
	zh = "辉片满层时半心琉璃化产物升级为整心",
	en = "At 5 shards: half-heart glaze conversions become full glaze hearts",
})

return item