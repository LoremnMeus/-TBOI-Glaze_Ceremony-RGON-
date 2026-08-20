local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local callback_manager = require("Qing_Remaster_scripts.core.callback_manager")

local item = {
	ToCall = {},
	myToCall = {},
}

function item.update_over_it(ent,col,player)
	callback_manager.work("POST_ANNAS_PORTAL_UPDATE",function(funct,params) if params == nil or params == col.Type then funct(nil,ent,col,player) end end)
end

function item.collide_over_it(ent,col,player)
	local succ = callback_manager.work_with_result("PRE_ANNAS_PORTAL_COLLISION",function(funct,params,value) if params == nil or params == col.Type then return funct(nil,ent,col,player,value) end end,false)
	return succ
end

return item