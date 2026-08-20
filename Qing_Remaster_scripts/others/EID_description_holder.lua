local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.EID_Descriptier,
Function = function(_,ent)
	if ent.Parent then
		if ent.Parent:Exists() ~= true then ent:Remove() 
		else ent:FollowParent(ent.Parent) end
	else ent.Velocity = ent.Velocity * 0.5 end
end,
})

return item