local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Ice_holder_",
}

function item.try_ice(ent,dur)
	ent:GetData()[item.own_key.."counter"] = dur or 2
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = nil,
Function = function(_,ent)
	if ent:IsBoss() == false and ent:GetData()[item.own_key.."counter"] then ent:AddEntityFlags(EntityFlag.FLAG_ICE) end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData() 
	if d[item.own_key.."counter"] then
		d[item.own_key.."counter"] = d[item.own_key.."counter"] - 1
		if d[item.own_key.."counter"] <= 0 then d[item.own_key.."counter"] = nil end
	end
end,
})

return item