local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	shader_name = "Qing_HelpfulShader",
}

function item.settime(val)
	val = val or 0
	Game().TimeCounter = math.max(0,Game().TimeCounter - val)
	Game().BlueWombParTime = Game().BlueWombParTime + val
end

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_GET_SHADER_PARAMS, params = nil,
Function = function(_,name)
	if name == item.shader_name then 
		local frame = Isaac.GetFrameCount()
		if (item.curr_frame or -1) == frame then item.Upper = false
		else item.Upper = true end
		item.curr_frame = frame
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	item.curr_frame = nil
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_,shouldsave)
	item.curr_frame = nil
end,
})
function item.IsUpper() return item.Upper end

return item