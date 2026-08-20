local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local callback_manager = require("Qing_Remaster_scripts.core.callback_manager")
local time_holder = require("Qing_Remaster_scripts.others.Time_holder")
local Pause_Screen_holder = require("Qing_Remaster_scripts.others.Pause_Screen_holder")
local Bed_holder = require("Qing_Remaster_scripts.mimics.Bed_holder")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
--l local slot_render_holder = require("Qing_Remaster_scripts.callbacks.slot_render_holder")
local item = {
	ToCall = {},
	myToCall = {},
	shader_name = "Qing_HelpfulShader",
	pause_info = {
		["Leave"] = {
			{frame = 0,alpha = 100/255,},
			{frame = 3,alpha = 100/255,},
			{frame = 6,alpha = 1,},
		},
		["Menu"] = {
			{frame = 0,alpha = 1,},
			{frame = 5,alpha = 100/255,},
		},
	},
}

function item.get_alpha()
	local alpha = 1
	local state = Pause_Screen_holder.currentState or {name = "UNPAUSED",}
	local stateinfo = Pause_Screen_holder.stateinfos[state.name]
	if state.record_state then stateinfo = Pause_Screen_holder.stateinfos[state.record_state.name] end
	alpha = alpha * Bed_holder.get_alpha()
	if stateinfo.Menu then
		local frame = item.render_frame or 0
		local sinfo = item.pause_info[item.render_anim]
		if sinfo then alpha = alpha * auxi.check_lerp(frame,sinfo).alpha end
	end
	return alpha
end

function item.do_frame(anim,no_update)
	if item.render_anim ~= anim then
		item.render_anim = anim
		item.render_frame = nil
	end
	if not no_update then item.render_frame = math.min(100,(item.render_frame or 0) + 0.5) end
end

function item.check_pocket(player,slot)
	if slot == 2 then 
		if player:GetCard(0) == 0 and player:GetPill(0) == 0 then return true 
		else return false end
	end
	return true
end

function item.work_on(name)
	if Game():GetHUD():IsVisible() then
		local tp = "Active"
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			for slot = 0,3 do 
				local cid = player:GetActiveItem(slot)
				if cid and cid ~= 0 and item.check_pocket(player,slot) then callback_manager.work(name,function(funct,params) if params == nil or params == tp then funct(nil,player,tp,cid,slot) end end) end
			end
		end
	end
end

if not REPENTOGON then
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_RENDER, params = nil,priority = 20,
Function = function(_)
	item.work_on("PRE_SLOT_RENDER")
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_GET_SHADER_PARAMS, params = nil,priority = 20,
Function = function(_,name)
	if name == item.shader_name then
		if time_holder.IsUpper() ~= true then return end
		local no_update = Pause_Screen_holder.check_info("NoUpdate")
		if Pause_Screen_holder.check_info("Leave") then	item.do_frame("Leave",no_update)
		elseif Pause_Screen_holder.check_info("Menu") then item.do_frame("Menu",no_update) end
		
		item.work_on("POST_SLOT_RENDER")
	end
end,
})
end

return item
