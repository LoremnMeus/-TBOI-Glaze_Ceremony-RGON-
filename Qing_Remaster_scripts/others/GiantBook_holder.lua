local g = require("Qing_Remaster_scripts.core.globals")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	ToCall = {},
	post_ToCall = {},
	start = false,
	own_key = "GiantBook_holder_",
	Queue = {},
	session_id = 0,
	last_error = nil,
}

local BookSpr = Sprite()
BookSpr:Load("gfx/ui/achievement display api/achievements.anm2")
BookSpr.PlaybackSpeed = 0.5

local function pre_load_info()
	local info = item.Queue[1]
	if type(info) ~= "table" then return false, "invalid queue entry" end
	if info.Loader and info.Anim then BookSpr:Load(info.Loader) BookSpr:Play(info.Anim,true)
	else BookSpr:Load("gfx/ui/achievement display api/achievements.anm2") end
	local speed = info.PlaybackSpeed or 0.5
	BookSpr.PlaybackSpeed = speed
	auxi.check_if_any(info.Init,BookSpr,info)
	return true
end

local function release_player_locks()
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local ok, d = pcall(function() return player:GetData() end)
		if ok and d then
			if d[item.own_key.."ctrl_succ"] then Attribute_holder.try_rewind_attribute(player,"ControlsEnabled",d[item.own_key.."ctrl_succ"]) end
			if d[item.own_key.."vel_succ"] then Attribute_holder.try_rewind_attribute(player,"Velocity",d[item.own_key.."vel_succ"]) end
			d[item.own_key.."ctrl_succ"] = nil
			d[item.own_key.."vel_succ"] = nil
		end
	end
end

local function finish_session(clear_queue, reason)
	local was_active = item.start == true or #item.Queue > 0
	if clear_queue then item.Queue = {} end
	item.start = nil
	item.session_id = item.session_id + 1
	item.last_error = reason
	if was_active then
		auxi.time_free(item.own_key)
		release_player_locks()
	end
end

local function begin_session()
	item.session_id = item.session_id + 1
	auxi.time_stop(item.own_key)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local d = player:GetData()
		if d[item.own_key.."ctrl_succ"] then Attribute_holder.try_rewind_attribute(player,"ControlsEnabled",d[item.own_key.."ctrl_succ"]) end
		if d[item.own_key.."vel_succ"] then Attribute_holder.try_rewind_attribute(player,"Velocity",d[item.own_key.."vel_succ"]) end
		d[item.own_key.."ctrl_succ"] = Attribute_holder.try_hold_attribute(player,"ControlsEnabled",false)
		d[item.own_key.."vel_succ"] = Attribute_holder.try_hold_attribute(player,"Velocity",Vector(0,0))
	end
	local ok, loaded, err = pcall(pre_load_info)
	if not ok or loaded == false then finish_session(true, tostring(err or loaded)); return false end
	item.start = true
	return true
end

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	if item.Queue[1] then
		local info = item.Queue[1]
		if not Game():IsPaused() then
			if (ModConfigMenu and ModConfigMenu.IsVisible) then ModConfigMenu.CloseConfigMenu()	end
			if (DeadSeaScrollsMenu and DeadSeaScrollsMenu.OpenedMenu) then DeadSeaScrollsMenu:CloseMenu(true, true)	end
		end
		if item.start ~= true then
			if not begin_session() then return end
		end
		local succ = BookSpr:IsFinished(BookSpr:GetAnimation())
		if info.work then
			local ok, value = pcall(auxi.check_if_any,info.work,BookSpr,info)
			if not ok then finish_session(true, tostring(value)); return end
			succ = value
		end
		if succ then
			table.remove(item.Queue, 1)
			if (not item.Queue[1]) then
				finish_session(false)
			else
				local ok, loaded, err = pcall(pre_load_info)
				if not ok or loaded == false then finish_session(true, tostring(err or loaded)); return end
			end
		else
			BookSpr:Render(auxi.GetScreenCenter(),Vector(0,0),Vector(0,0))
			local ok, err = pcall(auxi.check_if_any,info.render,BookSpr,info)
			if not ok then finish_session(true, tostring(err)); return end
			BookSpr:Update()
		end
	end
end,
})

function item.PlayGiantBook(params)
	if type(params) ~= "table" then return false end
	table.insert(item.Queue,#item.Queue + 1,params)
	return true
end

function item.Is_Finished_playing()
	return item.start ~= true and #item.Queue == 0
end

function item.Abort(reason) finish_session(true, reason or "manual") end

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil, Function = function() finish_session(true, "game_exit") end})
table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_GAME_END, params = nil, Function = function() finish_session(true, "game_end") end})
table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil, Function = function()
	if item.start == true or #item.Queue > 0 then finish_session(true, "new_room") end
end})

--l local GiantBook_holder = require("Qing_Remaster_scripts.others.GiantBook_holder") GiantBook_holder.PlayGiantBook({Loader = "gfx/ui/giantbook/giantbook.anm2",Anim = "Shake",Init = function(s,info) s:ReplaceSpritesheet(0,"gfx/ui/giantbook/giantbook_rebirth_006_d100.png") s:LoadGraphics() end})

return item
