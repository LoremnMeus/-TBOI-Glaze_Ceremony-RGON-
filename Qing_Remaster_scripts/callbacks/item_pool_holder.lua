local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local callback_manager = require("Qing_Remaster_scripts.core.callback_manager")

local item = {
	myToCall = {},
	ToCall = {},
	own_key = "Itempool_h_",
	Reload_Items = {
		[CollectibleType.COLLECTIBLE_GENESIS] = true,
	},
}

function item.init_pools()
	local ret = {}
	local tbl = callback_manager.work_with_result("PRE_CHECK_ITEMPOOL",function(funct,params,value) if true then return funct(nil,nil,value) end end,{})
	for u,v in pairs(tbl) do ret[u] = auxi.deepCopy(v) end
	return ret
end

function item.get_coll_from(name,decrease,rng,params)
	params = params or {}
	if auxi.have_player_has_collectible(CollectibleType.COLLECTIBLE_CHAOS) or auxi.have_player_has_collectible(CollectibleType.COLLECTIBLE_TMTRAINER) then 
	elseif save.elses[item.own_key.."effect"] and save.elses[item.own_key.."effect"][name] then
		local ret = (auxi.random_in_weighed_table(save.elses[item.own_key.."effect"][name].list,rng) or {}).id or auxi.random_in_weighed_table(save.elses[item.own_key.."effect"][name].default,rng)
		if ret then 
			if decrease and (save.elses[item.own_key.."effect"][name].list or {})[ret] then 
				save.elses[item.own_key.."effect"][name].list[ret].weigh = (save.elses[item.own_key.."effect"][name].list[ret].weigh or 1) - (save.elses[item.own_key.."effect"][name].wei or 1) 
				if save.elses[item.own_key.."effect"][name].list[ret].weigh <= 0 then save.elses[item.own_key.."effect"][name].list[ret] = nil end
			end
			local id = callback_manager.work_with_result("PRE_GET_COLLECTIBLE_FROM_POOL",function(funct,params,value) if params == nil or params == name then return funct(nil,value,name,decrease,rng:GetSeed()) end end,ret)
			return id
		end
	end
	if params.allow_miss then return nil end
	return auxi.get_item_from_pool(nil,decrease,rng)
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = item.init_pools()
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or item.init_pools()
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = nil,
Function = function(_,player,collid,cnt,touched)
	for u,v in pairs(save.elses[item.own_key.."effect"]) do
		if v.list[collid] then v.list[collid] = nil end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = nil,
Function = function(_,collid, itemRng, player, useFlags, activeSlot, customVarData)
	if item.Reload_Items[collid] then save.elses[item.own_key.."effect"] = item.init_pools() end
end,
})

return item