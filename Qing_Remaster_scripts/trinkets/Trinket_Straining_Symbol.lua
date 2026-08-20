local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Trinkets.Straining_Symbol,
	own_key = "Trinkets_Straining_Symbol_",
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = 350,
Function = function(_,ent)
	if ent.SubType == item.entity then
		Game():MakeShockwave(ent.Position,0.1,0.025,10) 
		local n_proj = auxi.getothers(n_entity,9)
		for u,v in pairs(n_proj) do v:Remove() end
	end
end,
})

return item