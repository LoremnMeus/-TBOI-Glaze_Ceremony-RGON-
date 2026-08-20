local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder") 

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Death_r,
	own_key = "Thoth_cd13r_Dea_",
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local d = player:GetData()
	local idx = d.__Index
	if idx ~= nil then
		save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
		local mul = save.elses[item.own_key.."effect"][idx]
		if mul then
			if cacheFlag == CacheFlag.CACHE_DAMAGE then
				player.Damage = player.Damage + 2.5
			end
			if cacheFlag == CacheFlag.CACHE_FIREDELAY then
				player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay,1.5)
			end
			if cacheFlag == CacheFlag.CACHE_RANGE then
				player.TearRange = player.TearRange + 3 * 40
			end
			if cacheFlag == CacheFlag.CACHE_SPEED then
				player.MoveSpeed = player.MoveSpeed + 0.5
			end
			if cacheFlag == CacheFlag.CACHE_LUCK then
				player.Luck = player.Luck + 5
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local idx = d.__Index
	if save.elses[item.own_key.."effect"][idx] then
		local should_work = false
		for slot = 0,2 do if player:GetActiveItem(slot) ~= 0 then should_work = true end end
		for slot = 0,1 do if player:GetTrinket(slot) ~= 0 then should_work = true end end
		for slot = 0,1 do if player:GetCard(slot) ~= 0 then should_work = true end end
		for slot = 0,1 do if player:GetPill(slot) ~= 0 then should_work = true end end
		if should_work then
			save.elses[item.own_key.."effect"][idx] = nil
			player:AddCacheFlags(CacheFlag.CACHE_ALL)
			player:GetData().should_evaluate_on_update_once = true
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_PICKUP_COLLECTIBLE, params = nil,
Function = function(_,player,colid,touched,ent)
	if ent:Exists() then
		local d = player:GetData()
		local idx = d.__Index
		local d2 = ent:GetData()
		local succ = consistance_holder.try_check_entity(ent,item.own_key)
		if succ and (d2._Data[item.own_key]["slot"] or 0) > 1 then 
			player:FlushQueueItem()
			player:RemoveCollectible(colid)
			player:AddCollectible(d2._Data[item.own_key]["colid"] or colid,d2._Data[item.own_key]["charge"] or 0,true,d2._Data[item.own_key]["slot"])
			d2._Data[item.own_key] = nil
			consistance_holder.try_remove_entity(ent,item.own_key)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	local rng = player:GetCardRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then 
		end
		player:DropTrinket(room:FindFreePickupSpawnPosition(player.Position,0,false),false)
		player:DropTrinket(room:FindFreePickupSpawnPosition(player.Position,0,false),false)
		player:DropPoketItem(0,room:FindFreePickupSpawnPosition(player.Position,0,false))
		player:DropPoketItem(1,room:FindFreePickupSpawnPosition(player.Position,0,false))
		for u,slot in pairs({0,0,2,}) do 
			local colid = player:GetActiveItem(slot)
			if (colid or 0) ~= 0 then 
				unique_holder.Hold_for_missing(true)
				local q = Isaac.Spawn(5,100,colid,room:FindFreePickupSpawnPosition(player.Position,0,false),Vector(0,0),player):ToPickup()
				auxi.self_morph(q,{5,100,colid,})
				unique_holder.Hold_for_missing()
				q.Charge = player:GetActiveCharge(slot) + player:GetBatteryCharge(slot)
				q.Touched = true
				local d2 = q:GetData()
				d2._Data = d2._Data or {}
				d2._Data[item.own_key] = d2._Data[item.own_key] or {}
				d2._Data[item.own_key]["slot"] = slot
				d2._Data[item.own_key]["colid"] = colid
				d2._Data[item.own_key]["charge"] = q.Charge
				consistance_holder.try_hold_entity(q,item.own_key,{ignore_subtype = true,})
				player:RemoveCollectible(colid)
			end
		end
		local e1 = Isaac.Spawn(1000,16,2,player.Position,Vector(0,0),nil):ToEffect()
		e1:GetSprite().Color = Color(0,0,0,1)
		local e2 = Isaac.Spawn(1000,16,1,player.Position,Vector(0,0),nil):ToEffect()
		e2:GetSprite().Color = Color(0,0,0,1)
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLACK_POOF,1,1,false,0,2)
		save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
		d[item.own_key.."effect"] = true
		save.elses[item.own_key.."effect"][idx] = 1
		player:AddCacheFlags(CacheFlag.CACHE_ALL)
		player:GetData().should_evaluate_on_update_once = true
	end
end,
})


return item