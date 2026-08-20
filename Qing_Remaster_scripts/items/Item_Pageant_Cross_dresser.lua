local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local costume_holder = require("Qing_Remaster_scripts.others.Costume_holder")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Pageant_Cross_dresser,
	own_key = "Item_PCD_",
	re_costume_items = {
		[CollectibleType.COLLECTIBLE_D100] = true,
		[CollectibleType.COLLECTIBLE_D4] = true,
		[CollectibleType.COLLECTIBLE_ESAU_JR] = true,
	},
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = nil,
Function = function(_,player,collid,count)
	if auxi.has_have_coll(player,item.entity) then
		local num = player:GetCollectibleNum(item.entity)
		num = num * 5 if num > 0 then num = num + 5 end
		local d = player:GetData()
		local idx = d.__Index
		local rng = RNG()
		rng:SetSeed(player:GetCollectibleRNG(item.entity):GetSeed(),0)
		save.elses[item.own_key.."effect"][idx] = save.elses[item.own_key.."effect"][idx] or {}
		if #save.elses[item.own_key.."effect"][idx] ~= num then
			local itemConfig = Isaac.GetItemConfig()
			local size = itemConfig:GetCollectibles().Size
			--l Game():GetPlayer(0):RemoveCostume(Isaac.GetItemConfig():GetCollectible())
			for i = 1,#save.elses[item.own_key.."effect"][idx] do
				local v = save.elses[item.own_key.."effect"][idx][i]
				player:RemoveCostume(itemConfig:GetCollectible(v))
			end
			save.elses[item.own_key.."effect"][idx] = {}
			local targ = {}
			for u,v in pairs(costume_holder.CanAdd) do
				if auxi.has_have_coll(player,v) ~= true then
					table.insert(targ,#targ+1,v)
				end
			end
			targ = auxi.randomTable(targ,rng)
			for i = 1,math.min(#targ,num) do
				player:AddCostume(itemConfig:GetCollectible(targ[i]),false)
				save.elses[item.own_key.."effect"][idx][i] = targ[i]
			end
			player:AddCacheFlags(CacheFlag.CACHE_LUCK)
			player:GetData().should_evaluate_on_update_once = true
		end
	elseif save.elses[item.own_key.."effect"][idx] then
		for i = 1,#save.elses[item.own_key.."effect"][idx] do
			local v = save.elses[item.own_key.."effect"][idx][i]
			player:RemoveCostume(itemConfig:GetCollectible(v))
		end
		save.elses[item.own_key.."effect"][idx] = nil
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = nil,
Function = function(_,colid,rng,player,useFlags,activeSlot,varData)
	if item.re_costume_items[colid] then save.elses[item.own_key.."effect"] = {} end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if auxi.has_have_coll(player,item.entity) then
		if cacheFlag == CacheFlag.CACHE_LUCK then
			local d = player:GetData()
			local idx = d.__Index
			save.elses[item.own_key.."effect"][idx] = save.elses[item.own_key.."effect"][idx] or {}
			local conter = #save.elses[item.own_key.."effect"][idx]
			local tbl = auxi.deepCopy(costume_holder.CanAddi)
			for u,v in pairs(save.elses[item.own_key.."effect"][idx]) do
				if tbl[v] then tbl[v] = nil end
			end
			for u,v in pairs(tbl) do
				if player:HasCollectible(u) then
					conter = conter + 1
				end
			end
			player.Luck = player.Luck + 0.1 * conter
		end
	end
end,
})

return item