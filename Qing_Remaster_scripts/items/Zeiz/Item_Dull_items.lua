local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local callback_manager = require("Qing_Remaster_scripts.core.callback_manager")

local item = {
	ToCall = {},
	pre_ToCall = {},
	post_ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	post_myToCall = {},
	entity = enums.Items.D773,
	own_key = "Item_Dull_Items_All_",
}

function item.add_point(player,val)
	local idx = player:GetData().__Index
	save.elses[item.own_key.."val"] = save.elses[item.own_key.."val"] or {}
	local ret = callback_manager.work_with_result("PRE_ADD_DULL_POINT",function(funct,params,value) return funct(nil,player,value) end,val)
	save.elses[item.own_key.."val"][idx] = (save.elses[item.own_key.."val"][idx] or 0) + ret
end

--tp: Normal/Real
function item.get_point(player,tp)
	tp = tp or "Normal"
	local idx = player:GetData().__Index
	save.elses[item.own_key.."val"] = save.elses[item.own_key.."val"] or {}
	local ret = callback_manager.work_with_result("MC_EVALUATE_DULL_POINT",function(funct,params,value) if params == nil or params == tp then return funct(nil,player,tp,value) end end,save.elses[item.own_key.."val"][idx] or 0)
	return ret
end



return item