local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "Crane_Game_holder_",
	direct = {},
}

--娃娃机有着很特殊的特性
table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_SLOT_UPDATE, params = 16,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local rng = ent:GetDropRNG()
	local seed = rng:GetSeed()
	local succ = consistance_holder.try_check_entity(ent,item.own_key)
	if (not succ) or (d[item.own_key.."Rngseed"] ~= seed) then
		d[item.own_key.."Rngseed"] = seed
		consistance_holder.try_hold_over_entity(ent,item.own_key)
		d._Data[item.own_key]["Record"] = (save.elses[item.own_key.."Record"] or {})[seed] or d._Data[item.own_key]["Record"]
		item.direct[seed] = ent
		consistance_holder.try_hold_entity(ent,item.own_key)
	end
end,
})

function item.try_ask_ent(ent)
	local succ = consistance_holder.try_check_entity(ent,item.own_key)
	if succ then
		return ent:GetData()._Data[item.own_key]["Record"]
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	item.direct = {}
	item[item.own_key.."missing"] = nil
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GET_COLLECTIBLE, params = nil,
Function = function(_,pool,decrease,seed)
	if pool == 23 and (item[item.own_key.."missing"] or {})[seed] then 
		return item[item.own_key.."missing"][seed]
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_POST_GET_COLLECTIBLE, params = nil,
Function = function(_,colid,pool,decrease,seed)
	if pool == 23 then 
		if auxi.check_all_exists(item.direct[seed]) then
			local ent = item.direct[seed]
			if ent:GetDropRNG():GetSeed() == seed then
				local d = ent:GetData()
				consistance_holder.try_hold_over_entity(ent,item.own_key)
				d._Data[item.own_key]["Record"] = colid
				consistance_holder.try_hold_entity(ent,item.own_key)
			end
		end
		save.elses[item.own_key.."Record"] = save.elses[item.own_key.."Record"] or {}
		save.elses[item.own_key.."Record"][seed] = colid 
	end
end,
})

function item.Hold_for_missing(val,id,seed)
	if val then 
		item[item.own_key.."missing"] = item[item.own_key.."missing"] or {}
		item[item.own_key.."missing"][seed or 1] = id or 33
	elseif seed then (item[item.own_key.."missing"] or {})[seed] = nil 
	else item[item.own_key.."missing"] = nil end
end

return item