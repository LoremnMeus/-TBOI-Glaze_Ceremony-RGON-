local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	entity = nil,
	own_key = "Boss_All_",
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = 996,
Function = function(_,ent)
	if ent.Variant == item.entity then
		local s = ent:GetSprite()
		local d = ent:GetData()
		local anim = s:GetAnimation()
		local frame = s:GetFrame()
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_INIT, params = 996,
Function = function(_,ent)
	if ent.Variant == item.entity then
		local s = ent:GetSprite()
		local d = ent:GetData()
	end
end,
})

return item