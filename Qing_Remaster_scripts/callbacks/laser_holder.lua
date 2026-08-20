local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local callback_manager = require("Qing_Remaster_scripts.core.callback_manager")
local Laser_holder = require("Qing_Remaster_scripts.mimics.Laser_holder")

local item = {
	ToCall = {},
	myToCall = {},
	recordlist = {},
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_LASER_INIT, params = nil,
Function = function(_,ent)
	table.insert(item.recordlist,ent)
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_EVERY_ENTITY_UPDATE, params = nil,		--在生成后的第一个Update结束瞬间触发
Function = function(_,ent)
	if #item.recordlist > 0 then for u,v in pairs(item.recordlist) do if auxi.check_all_exists(v) then callback_manager.work("POST_LASER_INIT_2_UPDATE",function(funct,params) if params == nil or params == v.Variant then funct(nil,v) end end) end end item.recordlist = {} end
end,
})

return item