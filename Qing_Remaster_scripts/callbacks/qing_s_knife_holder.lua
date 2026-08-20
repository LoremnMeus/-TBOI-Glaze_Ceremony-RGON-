local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local callback_manager = require("Qing_Remaster_scripts.core.callback_manager")
local input_holder = require("Qing_Remaster_scripts.others.Input_holder")

local item = {
	ToCall = {},
	myToCall = {},
}

function item.collide_knife_on_it(ent,col,low)
	callback_manager.work("PRE_QINGS_KNIFE_COLLISION",function(funct,params) if params == nil or params == col.Type then funct(nil,ent,col,low) end end)
end

return item