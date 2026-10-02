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
	local d = player:GetData()
	local idx = d.__Index
	local itemConfig = Isaac.GetItemConfig()
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	if auxi.has_have_coll(player,item.entity) then
		-- 第一份 10 件装扮，之后每份 +5
		local copies = player:GetCollectibleNum(item.entity)
		local num = 0
		if copies > 0 then num = 10 + math.max(0, copies - 1) * 5 end
		local rng = player:GetCollectibleRNG(item.entity)
		save.elses[item.own_key.."effect"][idx] = save.elses[item.own_key.."effect"][idx] or {}
		if #save.elses[item.own_key.."effect"][idx] ~= num then
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
			local cfg = itemConfig:GetCollectible(v)
			if cfg then player:RemoveCostume(cfg) end
		end
		save.elses[item.own_key.."effect"][idx] = nil
		player:AddCacheFlags(CacheFlag.CACHE_LUCK)
		player:GetData().should_evaluate_on_update_once = true
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
	if cacheFlag == CacheFlag.CACHE_LUCK and auxi.has_have_coll(player,item.entity) then
		player.Luck = player.Luck + 2 * player:GetCollectibleNum(item.entity)
	end
end,
})

return item