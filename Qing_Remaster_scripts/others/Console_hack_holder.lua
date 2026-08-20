local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Pause_Screen_holder = require("Qing_Remaster_scripts.others.Pause_Screen_holder")
local time_holder = require("Qing_Remaster_scripts.others.Time_holder")

local item = {
	ToCall = {},
	pre_ToCall = {},
	buffers = {},
	now_state = {str1 = "",str2 = "",state = 0,},
	now_id = nil,
	now_over_id = nil,
	now_lv = 0,
	pause_delay = 0,
	hold_delay = 30,
	hold_over_delay = 20,
	track_over = {},
	shader_name = "Qing_HelpfulShader",
	KeyboardToString = {},
	may_executed = {str1 = "",fr = 0,},
	Key_list = {
		Function = function(val,info,item)
			if val >= 65 and val <= 90 then return {string.lower(item.KeyboardToString[val]),item.KeyboardToString[val],Cplock = true,} end
			if val >= 320 and val <= 329 then return {tostring(val - 320),"",numberlock = true,} end
			return info[val]
		end,
		[32] = {" "," ",},
		[39] = {"'","\"",},
		[44] = {",","<",},
		[45] = {"-","_",},
		[46] = {".",">",},
		[47] = {"/","?",},
		[48] = {"0",")",},
		[49] = {"1","!",},
		[50] = {"2","@",},
		[51] = {"3","#",},
		[52] = {"4","$",},
		[53] = {"5","%",},
		[54] = {"6","^",},
		[55] = {"7","&",},
		[56] = {"8","*",},
		[57] = {"9","(",},
		[59] = {";",":",},
		[61] = {"=","+",},
		[91] = {"[","{",},
		[92] = {"\\","|",},
		[93] = {"]","}",},
		[96] = {"`","~",},
		
		[256] = {Exit = true,},
		[257] = {ignore_hold = true,ignore_alt = true,
		Function = function(state,info,item)
			state.str1 = state.str1 .. state.str2
			state.str2 = ""
			item.Try_Execute(auxi.deepCopy(state))
			item.now_lv = 0
			state = {str1 = "",str2 = "",state = 0,}
			return state
		end,},		--Enter
		[259] = {
		Function = function(state)
			if string.len(state.str1) > 0 then state.str1 = string.sub(state.str1,1,string.len(state.str1) - 1) end
			return state
		end,},		--Backspace
		[261] = {
		Function = function(state)
			if string.len(state.str2) > 0 then state.str2 = string.sub(state.str2,2,string.len(state.str2))
			elseif string.len(state.str1) > 0 then state.str1 = string.sub(state.str1,1,string.len(state.str1) - 1) end
			return state
		end,},		--Delete
		[262] = {
		Function = function(state)
			if string.len(state.str2) > 0 then 
				state.str1 = state.str1 .. string.sub(state.str2,1,1) 
				state.str2 = string.sub(state.str2,2,string.len(state.str2))
			end
			return state
		end,},		--右
		[263] = {
		Function = function(state)
			if string.len(state.str1) > 0 then 
				state.str2 = string.sub(state.str1,string.len(state.str1)) .. state.str2
				state.str1 = string.sub(state.str1,1,string.len(state.str1) - 1)
			end
			return state
		end,},		--左
		[264] = {ignore_hold = true,
		Function = function(state,info,item)
			item.now_lv = math.max(0,item.now_lv - 1)
			state = item.buffers[item.now_lv] or {str1 = "",str2 = "",state = 1,}
			if item.now_lv == 0 then item.now_state.state = 0 end
			return state
		end,},		--下
		[265] = {ignore_hold = true,
		Function = function(state,info,item)
			item.now_lv = item.now_lv + 1
			state = item.buffers[item.now_lv] or {str1 = "",str2 = "",state = 1,}
			return state
		end,},		--上
		[268] = {ignore_hold = true,
		Function = function(state)
			state.str2 = state.str1 .. state.str2
			state.str1 = ""
			return state
		end,},		--Home
		[269] = {ignore_hold = true,
		Function = function(state)
			state.str1 = state.str1 .. state.str2
			state.str2 = ""
			return state
		end,},		--End
		[280] = {ignore_hold = true,
		Function = function(state,info,item)
			item.recordinfo["Cplock"] = not item.recordinfo["Cplock"]
		end,},
		[282] = {ignore_hold = true,
		Function = function(state,info,item)
			item.recordinfo["numberlock"] = not item.recordinfo["numberlock"]
		end,},		--这几个数值需要随时确定。
		[330] = {".","",numberlock = true,},
		[331] = {"/","",},
		[332] = {"*","",},
		[333] = {"-","",},
		[334] = {"+","",},
		[335] = {ignore_hold = true,ignore_alt = true,
		Function = function(state,info,item)
			state.str1 = state.str1 .. state.str2
			state.str2 = ""
			item.Try_Execute(auxi.deepCopy(state))
			item.now_lv = 0
			state = {str1 = "",str2 = "",state = 0,}
			return state
		end,},		--Enter
		[336] = {"=","",},
		--[340] = {Shift = true,ignore_hold = true,},
		--[341] = {Ctrl = true,ignore_hold = true,},
		--[342] = {Alt = true,ignore_hold = true,},
		--[344] = {Shift = true,ignore_hold = true,},
		--[345] = {Ctrl = true,ignore_hold = true,},
		--[346] = {Alt = true,ignore_hold = true,},
	},
	Key_over = {
		[259] = true,
		[261] = true,
		[262] = true,
		[263] = true,
		[264] = true,
		[265] = true,
	},
	recordinfo = {
		["numberlock"] = true,
		["Cplock"] = false,
	},
}
-- 命令回调能直接取得已执行命令。RGON 下不再通过 shader 轮询控制台历史；
-- Vanilla 下也保留这条直接路径，旧键盘模拟仅负责提交前的兼容处理。
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EXECUTE_CMD, params = nil,
Function = function(_,str,params)
	local command = string.lower(tostring(str or ""))
	item.may_executed = {str = command.." "..tostring(params or ""),fr = Isaac.GetFrameCount(),}
	if command == "rewind" then save.should_load2 = true end
end,
})

if REPENTOGON then
	return item
end

--l local state = {str1 = "123",str2 = "980",} state.str1 = state.str1 .. string.sub(state.str2,1,1) state.str2 = string.sub(state.str2,2,string.len(state.str2)) print(state.str1.." "..state.str2)
--l local chh = require("Qing_Remaster_scripts.others.Console_hack_holder") chh.pause_delay_limit = 20
for key,num in pairs(Keyboard) do
	local keyString = key
	local keyStart, keyEnd = string.find(keyString, "KEY_")
	keyString = string.sub(keyString, keyEnd+1, string.len(keyString))
	--keyString = string.gsub(keyString, "_", " ")
	item.KeyboardToString[num] = keyString
end

function item.KeyboardTriggered(key, controllerIndex)
	controllerIndex = controllerIndex or Game():GetPlayer(0).ControllerIndex
	return Input.IsButtonTriggered(key, controllerIndex) and not Input.IsButtonTriggered(key % 32, controllerIndex)
end

function item.KeyboardPressed(key, controllerIndex)
	controllerIndex = controllerIndex or Game():GetPlayer(0).ControllerIndex
	return Input.IsButtonPressed(key, controllerIndex) and not Input.IsButtonPressed(key % 32, controllerIndex)
end

function item.Try_Execute(state)
	if state.str1 == "" and state.str2 == "" and state.state == 0 then Pause_Screen_holder.Leave_console() end
	--print(state.str1..state.str2)
	if Isaac.GetFrameCount() - item.may_executed.fr == 1 then 
		--print("Examimed::"..item.may_executed.str.." "..item.may_executed.fr)
	elseif state.state == 0 then
		if state.str1 == "rewind" then 
			save.should_load2 = true
		end
	end
	table.insert(item.buffers,1,state)
end


function item.execute_state(state,val,tp)
	state = state or item.now_state
	local info = item.Key_list.Function(val,item.Key_list,item)
	if info then
		--local shifted = item.KeyboardPressed(340) 
		local shiftedid = 0
		if item.recordinfo.Cplock and info.Cplock then shiftedid = 1 end
		if item.KeyboardPressed(340) or item.KeyboardPressed(344) then shiftedid = 1 - shiftedid end
		if item.KeyboardPressed(341) or item.KeyboardPressed(345) then 
			if item.KeyboardToString[val] == "V" then state.state = 1 end
			return state
		end
		if (item.KeyboardPressed(342) or item.KeyboardPressed(346)) and not info.ignore_alt then return end
		if tp == "Hold" and info.ignore_hold then return end
		if info.Function then state = info.Function(state,info,item) or state end
		if info[shiftedid + 1] and (info.numberlock ~= true or item.recordinfo.numberlock) then state.str1 = state.str1 .. info[shiftedid + 1] end
	end
	return state
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_GET_SHADER_PARAMS, params = nil,
Function = function(_,name)
	if name == item.shader_name then 
		if time_holder.IsUpper() ~= true then return end
		if (Pause_Screen_holder.currentState or {}).name == "IN_CONSOLE" then
			local ctrlidx = Game():GetPlayer(0).ControllerIndex
			local tp = ""
			for u,v in pairs(item.track_over) do
				if item.KeyboardPressed(u,ctrlidx) == false then 
					item.track_over[u] = nil
					item.pause_delay = item.hold_delay
				end
			end
			item.pause_delay = (item.pause_delay or 0) - 1
			if item.now_id and item.pause_delay <= 0 then 
				if item.KeyboardPressed(item.now_id.id,ctrlidx) then 
					item.now_id.fr = item.now_id.fr + 1
					if item.now_id.fr % 2 == 1 then 
						item.now_state = item.execute_state(item.now_state,item.now_id.id,"Hold") or item.now_state
						--tp = tp .. item.KeyboardToString[item.now_id.id] .. " " .. item.now_id.id .. " " 
					end
				else
					item.now_id = nil 
				end
			end
			for u,v in pairs(item.KeyboardToString) do 
				if item.KeyboardTriggered(u,ctrlidx) then
					item.now_id = {id = u,fr = 0,}
					item.track_over[u] = true
					item.now_state = item.execute_state(item.now_state,u,"Press") or item.now_state
					--tp = tp .. v .. " " .. u .. " "
					item.pause_delay = item.hold_delay
					if item.Key_over[u] then
						item.pause_delay = item.hold_over_delay
						item.now_over_id = {id = u,fr = 0,}
					end
				end
			end
			--tp = item.now_state.str1..item.now_state.str2
			--if tp ~= "" then print(tp) end
		end
	end
end,
})

return item
