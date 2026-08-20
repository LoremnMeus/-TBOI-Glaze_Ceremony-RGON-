local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local time_holder = require("Qing_Remaster_scripts.others.Time_holder")
local Pause_Screen_holder = require("Qing_Remaster_scripts.others.Pause_Screen_holder")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Bed_holder_",
	shader_name = "Qing_HelpfulShader",
	bed_info = {
		{frame = 0,alpha = 1,},
		{frame = 25 * 2,alpha = 0,},
		{frame = 157 * 2,alpha = 0,},
		{frame = 181 * 2,alpha = 1,},
	},
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_GET_SHADER_PARAMS, params = nil,priority = 10,
Function = function(_,name)
	if name == item.shader_name and Game():IsPaused() then 
		if time_holder.IsUpper() ~= true then return end
		local succ = (Pause_Screen_holder.Leave_sleep or 0) > 0
		local state = Pause_Screen_holder.currentState
		if state.name == "IN_BED" then 
			item.bed_time = (item.bed_time or 0) + 1
		elseif succ then 
		else item.bed_time = nil end
	end 
end,
})

function item.get_alpha()
	if item.bed_time == nil then return 1 end
	return auxi.check_lerp(item.bed_time,item.bed_info).alpha
end

return item