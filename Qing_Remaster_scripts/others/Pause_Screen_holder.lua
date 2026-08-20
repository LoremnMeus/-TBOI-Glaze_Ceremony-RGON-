local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local time_holder = require("Qing_Remaster_scripts.others.Time_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	pre_ToCall = {},
	myToCall = {},
	shader_name = "Qing_HelpfulShader",
	curr_frame = nil,
	stateinfos = {		--这个算法无法处理切屏造成的暂停。
		UNPAUSED = {
			Hide = true,
			Dir = {
				[ButtonAction.ACTION_PAUSE] = "MAIN",
				[ButtonAction.ACTION_MENUBACK] = "MAIN",
				[Keyboard.KEY_GRAVE_ACCENT] = function(now_state) if Options.DebugConsoleEnabled then return {name = "IN_CONSOLE",record_state = now_state,} end end,
			},
		},
		UNPAUSING = {
			Hide = true,
			Dir = {
				[Keyboard.KEY_GRAVE_ACCENT] = function(now_state) if Options.DebugConsoleEnabled then return {name = "IN_CONSOLE",record_state = now_state,} end end,
			},
		},
		LEAVE = {
			Menu = true,
			Dir = {
				[Keyboard.KEY_GRAVE_ACCENT] = function(now_state) if Options.DebugConsoleEnabled then return {name = "IN_CONSOLE",record_state = now_state,} end end,
			},
		},
		MAIN = {
			Menu = true,
			Dir = {
				[ButtonAction.ACTION_MENUBACK] = function(now_state,item,info) return {name = "MAIN_OUT",hold_me = 11,} end,
				[ButtonAction.ACTION_MENUCONFIRM] = function(now_state,item,info) return info.Statelist[now_state.record_id or 0] end,
				[ButtonAction.ACTION_MENUDOWN] = function(now_state,item) now_state.record_id = ((now_state.record_id or 0) + 2)%3 return now_state end,
				[ButtonAction.ACTION_MENUUP] = function(now_state,item) now_state.record_id = ((now_state.record_id or 0) + 1)%3 return now_state end,
				[Keyboard.KEY_GRAVE_ACCENT] = function(now_state) if Options.DebugConsoleEnabled then return {name = "IN_CONSOLE",record_state = now_state,} end end,
			},
			Name = function(now_state,item,info) return info.Namelist[now_state.record_id or 0] or "Main?" end,
			Namelist = {
				[0] = "RESUME",
				[1] = "OPTIONS",
				[2] = "EXIT",
			},
			Statelist = {
				[0] = {name = "MAIN_OUT",hold_me = 11,},
				[1] = "IN_OPTIONS",
				[2] = "LEAVE",
			},
		},
		MAIN_OUT = {
			Menu = true,
			Leave = true,
			Dir = {
				[Keyboard.KEY_GRAVE_ACCENT] = function(now_state) if Options.DebugConsoleEnabled then return {name = "IN_CONSOLE",record_state = now_state,} end end,
			},
			Ignore_hold_me = {
				[Keyboard.KEY_GRAVE_ACCENT] = true,
			},
			Default = function(now_state) return "UNPAUSED"	end,
		},
		IN_OPTIONS = {
			Menu = true,
			Hide = true,
			Dir = {
				[ButtonAction.ACTION_MENUBACK] = {name = "MAIN",record_id = 1,},
				[ButtonAction.ACTION_MENUCONFIRM] = function(now_state,item) if (item.record_id or 0) == 0 then return {name = "CHANGE_CONTROL",hold_me = 11,}	end end,
				[ButtonAction.ACTION_MENUDOWN] = function(now_state,item) item.record_id = ((item.record_id or 0) + 13)%14 return now_state end,
				[ButtonAction.ACTION_MENUUP] = function(now_state,item) item.record_id = ((item.record_id or 0) + 1)%14 return now_state end,
				[Keyboard.KEY_GRAVE_ACCENT] = function(now_state) if Options.DebugConsoleEnabled then return {name = "IN_CONSOLE",record_state = now_state,} end end,
			},
			Ignore_hold_me = {
				[Keyboard.KEY_GRAVE_ACCENT] = true,
			},
		},
		CHANGE_CONTROL = {
			Menu = true,
			Hide = true,
			Dir = {
				[Keyboard.KEY_GRAVE_ACCENT] = function(now_state) return {name = "IN_CONSOLE",record_state = now_state,} end,
			},
			Ignore_hold_me = {
				[Keyboard.KEY_GRAVE_ACCENT] = true,
			},
			Any = {name = "IN_OPTIONS",hold_me = 10,}
		},
		IN_CONSOLE = {
			Hide = function(now_state,item) if now_state.record_state and auxi.check_if_any(item.stateinfos[now_state.record_state.name].Hide,now_state.record_state,item) ~= true then else return true end end,
			Leave = function(now_state,item) if now_state.record_state and auxi.check_if_any(item.stateinfos[now_state.record_state.name].Leave,now_state.record_state,item) ~= true then else return true end end,
			Menu = function(now_state,item) if now_state.record_state and auxi.check_if_any(item.stateinfos[now_state.record_state.name].Menu,now_state.record_state,item) ~= true then else return true end end,
			NoUpdate = true,
			Dir = {
				[ButtonAction.ACTION_MENUBACK] = function(now_state) 
					if now_state.record_state then 
						local tbl = auxi.deepCopy(now_state)
						tbl.hold_me = 7.5
						tbl.name = "OUT_CONSOLE"
						return tbl 
					end 
					return "UNPAUSED"
				end,
			},
			AlwaysDir = {
				[ButtonAction.ACTION_MENUBACK] = true,
			},
		},
		OUT_CONSOLE = {
			Hide = function(now_state,item) if now_state.record_state and auxi.check_if_any(item.stateinfos[now_state.record_state.name].Hide,now_state.record_state,item) ~= true then else return true end end,
			Leave = function(now_state,item) if now_state.record_state and auxi.check_if_any(item.stateinfos[now_state.record_state.name].Leave,now_state.record_state,item) ~= true then else return true end end,
			Menu = function(now_state,item) if now_state.record_state and auxi.check_if_any(item.stateinfos[now_state.record_state.name].Menu,now_state.record_state,item) ~= true then else return true end end,
			NoUpdate = true,
			Default = function(now_state) 
				if now_state.record_state then return now_state.record_state end
				return "UNPAUSED"
			end,
		},
		IN_BED = {
			Hide = true,
			Dir = {
				[ButtonAction.ACTION_PAUSE] = "MAIN",
				[ButtonAction.ACTION_MENUBACK] = "MAIN",
				[Keyboard.KEY_GRAVE_ACCENT] = function(now_state) if Options.DebugConsoleEnabled then return {name = "IN_CONSOLE",record_state = now_state,} end end,
			},
		},
	},
}

function item.Leave_console()			--这是为另一边黑入控制台留下的接口。
	if (item.currentState or {name = "UNPAUSED",}).name == "IN_CONSOLE" then
		item.currentState = auxi.check_if_any(item.stateinfos["IN_CONSOLE"]["Dir"][ButtonAction.ACTION_MENUBACK],item.currentState,item)
	end
end

local function UpdateState(state)
	state = state or item.currentState or {name = "UNPAUSED",}
	local ret
	for i = 1,1 do
		if not Game():IsPaused() then ret = {name = "UNPAUSED",} break
		elseif state.name == "UNPAUSED" and item.wasPausedLastFrame then 
			if (item.Leave_sleep or 0) > 0 then ret = {name = "IN_BED",} end
			break
		end
		local state_info = item.stateinfos[state.name]
		local ctrlid = Game():GetPlayer(0).ControllerIndex
		if state.hold_me then 
			state.hold_me = state.hold_me - 0.5
			if state.hold_me <= 0 then state.hold_me = nil end
		end
		for u,v in pairs(state_info.Dir or {}) do 
			if (Input.IsActionTriggered(u,ctrlid) or Input.IsButtonTriggered(u,ctrlid)) or ((state_info.AlwaysDir or {})[u] and Input.IsActionPressed(u,ctrlid)) then 
				if state.hold_me == nil or (state.hold_me and (state_info.Ignore_hold_me or {})[u]) then ret = auxi.check_if_any(v,state,item,state_info) end
				if ret then if type(ret) == "string" then ret = {name = ret,} end break	end
			end
		end
		if state_info.Any then 
			for u,v in pairs(ButtonAction) do 
				if Input.IsActionTriggered(v,ctrlid) or Input.IsButtonTriggered(v,ctrlid) then 
					if state.hold_me == nil or (state.hold_me and (state_info.Ignore_hold_me or {})[v]) then ret = auxi.check_if_any(state_info.Any,state) end
					if ret then if type(ret) == "string" then ret = {name = ret,} end break	end
				end
			end
		end
		if state.hold_me == nil and state_info.Default then
			ret = auxi.check_if_any(state_info.Default,state)
			if ret then if type(ret) == "string" then ret = {name = ret,} end break	end
		end
	end
	ret = ret or auxi.deepCopy(state)
	return ret
end

function item.check_info(name)
	if not item.currentState then return nil end
	return auxi.check_if_any(item.stateinfos[item.currentState.name][name],item.currentState,item)
end

function item.check_name(state)
	local ret = state.name
	local info = item.stateinfos[ret]
	if info.Name then ret = auxi.check_if_any(info.Name,state,item,info) or ret end
	return ret
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_GET_SHADER_PARAMS, params = nil,
Function = function(_,name)
	if name == item.shader_name then 
		if time_holder.IsUpper() ~= true then return end
		item.currentState = UpdateState(item.currentState)
		item.wasPausedLastFrame = Game():IsPaused()
	end 
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	item.wasPausedLastFrame = nil
	item.record_id = 0
	item.Leave_sleep = nil
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_,shouldsave)
	item.curr_frame = nil
	item.wasPausedLastFrame = nil
	item.record_id = 0
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = 380,
Function = function(_,ent,col,low)
	local player = col:ToPlayer()
	if player then
		if auxi.can_sleep(player) and ent.Touched == false then 
			item.Leave_sleep = (item.Leave_sleep or 0) + 1
			delay_buffer.addeffe(function(params)
				item.Leave_sleep = (item.Leave_sleep or 0) - 1
			end,{},2)
		end
	end
end,
})

return item