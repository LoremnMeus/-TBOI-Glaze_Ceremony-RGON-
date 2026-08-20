local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	pre_ToCall = {},
	target = {
		enums.Items.A_Shard_Of_Coin,
		enums.Items.A_Shard_Of_Glaze,
		enums.Items.A_Shard_Of_Lava,
		enums.Items.A_Shard_Of_Meat,
		enums.Items.A_Shard_Of_Rock,
		--enums.Items.A_Shard_Of_Blood,
		},
	c_s = Sprite(),
	own_key = "Console_holder_",
	target_keys = {
		[Keyboard.KEY_GRAVE_ACCENT] = true,
		[Keyboard.KEY_RIGHT_CONTROL] = true,
		[Keyboard.KEY_RIGHT_ALT] = true,
		[Keyboard.KEY_LEFT_CONTROL] = true,
		[Keyboard.KEY_LEFT_ALT] = true,
	},
	Options_open = {
		["set"] = true,
		["open"] = true,
		["opened"] = true,
	},
	Options_close = {
		["close"] = true,
		["closed"] = true,
	},
	Options_tgs = {
		["fullscreen"] = "Fullscreen",
		["foundhud"] = "FoundHUD",
		["hud"] = "FoundHUD",
		["mouse"] = "MouseControl",
		["mousecontrol"] = "MouseControl",
		["debugconsoleenabled"] = "DebugConsoleEnabled",
		["console"] = "DebugConsoleEnabled",
	},
	Options_no = {
		["false"] = true,
		["no"] = true,
		["not"] = true,
		["don't"] = true,
	},
	Options = {
		["Fullscreen"] = true,
		["FoundHUD"] = true,
		["MouseControl"] = true,
		["DebugConsoleEnabled"] = true,
	},
}

function item.try_set_temp_option(name,val)
	local nval = Options[name]
	if nval == nil then return end
	if item.Options[name] and Options[name] ~= val then 
		if name == "MouseControl" and val == true then item.check_mouse() end
		save.elses[item.own_key.."tempsave"] = save.elses[item.own_key.."tempsave"] or {}
		if save.elses[item.own_key.."tempsave"][name] == val then save.elses[item.own_key.."tempsave"][name] = nil
		else save.elses[item.own_key.."tempsave"][name] = Options[name] end
		Options[name] = val
	end
end

function item.check_mouse() if not Options.MouseControl and not (save.elses[item.own_key.."tg"] or {})["MouseControl"] and not (save.elses[item.own_key.."tg"] or {})["MouseControl"] then item.MouseControl = true end end

function item.try_set_option(name,val)
	save.elses[item.own_key.."save"] = save.elses[item.own_key.."save"] or {}
	save.elses[item.own_key.."tg"] = save.elses[item.own_key.."tg"] or {}
	if item.Options[name] and Options[name] ~= val then 
		if name == "MouseControl" and val == true then item.check_mouse() end
		if save.elses[item.own_key.."save"][name] == val then save.elses[item.own_key.."save"][name] = nil
		elseif save.elses[item.own_key.."save"][name] == nil then save.elses[item.own_key.."save"][name] = Options[name] end
		save.elses[item.own_key.."tg"][name] = val
		Options[name] = val
	end
end

function item.back_to_my_normal_set()
	save.elses[item.own_key.."save"] = {}
	save.elses[item.own_key.."tg"] = {}
	Options.Gamma = 1.5
	Options.ExtraHUDStyle = 2
	Options.FoundHUD = true
	Options.ChargeBars = true
	item.check_mouse()
	Options.MouseControl = true
	--Options.MusicVolume = 0.11
	Options.ConsoleFont = 1
	Options.FadedConsoleDisplay = true
	Options.DebugConsoleEnabled = true
end

item.c_s:Load("gfx/ui/special ui/cursor.anm2")
item.c_s:Play("Idle",true)

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_GET_SHADER_PARAMS, params = nil,
Function = function(_,name)
	if name == "Qing_HelpfulShader" then
		if item.MouseControl and Options.MouseControl then		--需要绘制鼠标
			if Input.IsMouseBtnPressed(0) then item.c_s:Play("Clicked",true)
			else item.c_s:Play("Idle",true) end
			item.c_s:Render(Isaac.WorldToScreen(Input.GetMousePosition(true)) - Game().ScreenShakeOffset,Vector(0,0),Vector(0,0))
		end
		if Options.DebugConsoleEnabled ~= true then
			local succ = true
			local ctrlid = Game():GetPlayer(0).ControllerIndex
			for u,v in pairs(item.target_keys) do
				if Input.IsButtonTriggered(u,ctrlid) or Input.IsButtonPressed(u,ctrlid) then
				else succ = false break end
			end
			if succ then item.try_set_option("DebugConsoleEnabled",true) end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_,shouldsave)
	save.elses[item.own_key.."tempsave"] = save.elses[item.own_key.."tempsave"] or {}
	save.elses[item.own_key.."save"] = save.elses[item.own_key.."save"] or {}
	save.elses[item.own_key.."tg"] = save.elses[item.own_key.."tg"] or {}
	for u,v in pairs(save.elses[item.own_key.."tempsave"]) do Options[u] = v end
	save.elses[item.own_key.."tempsave"] = {}
	for u,v in pairs(save.elses[item.own_key.."save"]) do Options[u] = v end
	if shouldsave then
	else
		save.elses[item.own_key.."save"] = {}
		save.elses[item.own_key.."tg"] = {}
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	save.elses[item.own_key.."save"] = save.elses[item.own_key.."save"] or {}
	save.elses[item.own_key.."tg"] = save.elses[item.own_key.."tg"] or {}
	save.elses[item.own_key.."tempsave"] = {}
	if continue then
		for u,v in pairs(save.elses[item.own_key.."tg"]) do
			save.elses[item.own_key.."save"][u] = Options[u]
			if Options[u] == save.elses[item.own_key.."tg"][u] then save.elses[item.own_key.."save"][u] = nil save.elses[item.own_key.."tg"][u] = nil
			else Options[u] = save.elses[item.own_key.."tg"][u] end
		end
	else
		save.elses[item.own_key.."save"] = {}
		save.elses[item.own_key.."tg"] = {}
	end
end,
})

function item.console_speak(tbl)
	local word = nil
	if type(tbl) == "table" then
		word = tbl.word
		if tbl.Special then word = tbl.Special() end
	else
		word = tbl
	end
	item.try_set_option("DebugConsoleEnabled",true)
	local p_DebugConsoleEnabled = Options.DebugConsoleEnabled
	local p_FadedConsoleDisplay = Options.FadedConsoleDisplay
	Options.FadedConsoleDisplay = true
	if word ~= nil then print(word) end
	Options.FadedConsoleDisplay = p_FadedConsoleDisplay
	Options.DebugConsoleEnabled = p_DebugConsoleEnabled
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EXECUTE_CMD, params = nil,
Function = function(_,str,params)
	if string.lower(str) == "qing" and params ~= nil then
		local args={}
		for str in string.gmatch(params, "([^ ]+)") do
			table.insert(args, str)
		end
		if args[1] then
			if string.lower(args[1]) == "unlockall" then
				item.console_speak("Unlocked")
				save.UnLockAll()
			end
			if string.lower(args[1]) == "lockall" then
				item.console_speak("Locked")
				save.LockAll()
			end
			if string.lower(args[1]) == "alchemy" then
				local player = Game():GetPlayer(0)
				for u,v in pairs(item.target) do
					if player:HasCollectible(v) == false then
						player:AddCollectible(v)
					end
				end
			end
		end
	elseif string.lower(str) == "meus" and params ~= nil then
		local args={}
		for str in string.gmatch(params, "([^ ]+)") do
			table.insert(args, str)
		end
		if save.elses.should_meus_appear ~= true and args[1] then
			for ii = 1,1 do if string.lower(args[1]) == "please" then
				if args[2] and args[2] == "goto" and args[3] and args[3] == "shadow" then Isaac.ExecuteCommand("stage 6") save.elses.shadoll_level = 2 Isaac.ExecuteCommand("reseed") break end
				if args[2] and args[2] == "normalize" and args[3] and args[3] == "me" then item.back_to_my_normal_set() break end
				local open_flg = 0
				local fail_flg = false
				local not_flg = 0
				local tg = nil
				for i = 2,#args do
					if args[i] then
						local str = string.lower(args[i])
						if item.Options_open[str] then
							if open_flg == 0 then open_flg = open_flg + 1
							else fail_flg = true break end
						elseif item.Options_close[str] then
							if open_flg == 0 then open_flg = open_flg + 2
							else fail_flg = true break end
						elseif item.Options_tgs[str] then
							if tg then fail_flg = true break
							else tg = item.Options_tgs[str] end
						elseif item.Options_no[str] then
							not_flg = not_flg + 1
						end
					end
				end
				if not fail_flg and tg then
					local succ = (not_flg + open_flg) % 2
					if succ == 1 then 
						item.console_speak("Set "..tg.." to True.")
						item.try_set_option(tg,true) 
					else 
						item.console_speak("Set "..tg.." to False.")
						item.try_set_option(tg,false) 
					end
				end
				--meus please normalize me
			end
		end end
	end
end,
})

return item