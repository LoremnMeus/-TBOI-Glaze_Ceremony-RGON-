-- 全屏举起选择器：公开注册壳，复用蓝图已验证的生命周期。
-- 委托者只负责画面与业务；本 holder 负责打开/关闭、时停、输入拦截、
-- 换房/退出时不得碰旧 Player:GetData()。
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local selection_holder = require("Qing_Remaster_scripts.others.selection_holder")
local Mouse_UI = require("Qing_Remaster_scripts.others.Mouse_UI_holder")

local holder = {
	ToCall = {},
	pre_ToCall = {},
	specs = {},
	sessions = {},
	pending_reopen = {},
	suppress_open_until = {},
	room_selection_cleanup_until = nil,
	eid_hide_state = nil,
}

local DEFAULT_BLOCKED = {
	[ButtonAction.ACTION_LEFT] = true,
	[ButtonAction.ACTION_RIGHT] = true,
	[ButtonAction.ACTION_UP] = true,
	[ButtonAction.ACTION_DOWN] = true,
	[ButtonAction.ACTION_SHOOTLEFT] = true,
	[ButtonAction.ACTION_SHOOTRIGHT] = true,
	[ButtonAction.ACTION_SHOOTUP] = true,
	[ButtonAction.ACTION_SHOOTDOWN] = true,
	[ButtonAction.ACTION_DROP] = true,
	[ButtonAction.ACTION_PILLCARD] = true,
	[ButtonAction.ACTION_MAP] = true,
	[ButtonAction.ACTION_BOMB] = true,
	[ButtonAction.ACTION_ITEM] = true,
	[ButtonAction.ACTION_CONSOLE] = true,
	[ButtonAction.ACTION_MENUCONFIRM] = true,
	[ButtonAction.ACTION_MENULEFT] = true,
	[ButtonAction.ACTION_MENURIGHT] = true,
	[ButtonAction.ACTION_MENUUP] = true,
	[ButtonAction.ACTION_MENUDOWN] = true,
}

local pillcard = {
	probe = false,
	cache_frame = -1,
	cache_trig = false,
	cache_held = false,
}

local function player_exists_safe(player)
	if not player then return false end
	local ok, exists = pcall(function() return player:Exists() end)
	return ok and exists == true
end

local function pause_menu_open()
	return REPENTOGON and Game().IsPauseMenuOpen and Game():IsPauseMenuOpen()
end

local function selection_key_of(spec)
	return spec.selection_key or (spec.own_key .. "select")
end

local function hide_eid()
	if not EID then return end
	if holder.eid_hide_state == nil then
		holder.eid_hide_state = EID.isHidden and true or false
	end
	EID.isHidden = true
end

local function restore_eid()
	if holder.eid_hide_state == nil then return end
	if EID then
		EID.isHidden = holder.eid_hide_state
	end
	holder.eid_hide_state = nil
end

local function any_session_hides_eid()
	for id, session in pairs(holder.sessions) do
		local spec = holder.specs[id]
		if session and spec and spec.hide_eid ~= false then
			return true
		end
	end
	return false
end

function holder.player_exists_safe(player)
	return player_exists_safe(player)
end

function holder.pause_menu_open()
	return pause_menu_open()
end

function holder.register(spec)
	if type(spec) ~= "table" or spec.id == nil then return false end
	holder.specs[spec.id] = spec
	spec.blocked_actions = spec.blocked_actions or DEFAULT_BLOCKED
	if spec.hide_eid == nil then spec.hide_eid = true end
	if spec.time_stop == nil then spec.time_stop = true end
	if spec.lift_item == nil then spec.lift_item = true end
	if spec.block_inputs == nil then spec.block_inputs = true end
	if spec.reopen_on_room == nil then spec.reopen_on_room = true end
	return true
end

function holder.get(id)
	return holder.sessions[id]
end

local function session_is_alive(session)
	if not session then return false end
	local opened = session.opened_frame
	if opened ~= nil and Game():GetFrameCount() < opened then
		return false
	end
	return player_exists_safe(session.player)
end

function holder.is_open(id, player)
	local session = holder.sessions[id]
	if not session_is_alive(session) then return false end
	if player == nil then return true end
	local ok, same = pcall(function()
		return auxi.check_for_the_same(session.player, player)
	end)
	return ok and same == true
end

function holder.same_player(id, player)
	return holder.is_open(id, player)
end

local function drop_held(session)
	local spec = session and holder.specs[session.id]
	if not spec or spec.lift_item == false then return end
	local player = session.player
	if not player_exists_safe(player) then return end
	pcall(function()
		if player:IsHoldingItem() then
			player:AnimateCollectible(spec.item_id, "HideItem", "PlayerPickup")
		end
	end)
end

local function clear_selection(session, player)
	local spec = session and holder.specs[session.id]
	if not spec then return end
	if not player_exists_safe(player) then return end
	pcall(function()
		selection_holder.remove_select(player, selection_key_of(spec))
	end)
end

function holder.scrub(id)
	local session = holder.sessions[id]
	if not session then return false end
	if session_is_alive(session) then return false end
	local spec = holder.specs[id]
	holder.sessions[id] = nil
	holder.suppress_open_until[id] = -1
	if spec and spec.time_stop ~= false then
		pcall(function() auxi.time_free(spec.own_key) end)
	end
	if spec and spec.on_scrub then pcall(spec.on_scrub, session) end
	if not any_session_hides_eid() then restore_eid() end
	return true
end

function holder.close(id, opts)
	opts = opts or {}
	local session = holder.sessions[id]
	local spec = holder.specs[id]
	if not session then
		if spec and spec.time_stop ~= false then
			pcall(function() auxi.time_free(spec.own_key) end)
		end
		if not any_session_hides_eid() then restore_eid() end
		return
	end
	local alive_player = player_exists_safe(session.player) and session.player or nil
	if spec and spec.on_close then
		pcall(spec.on_close, session, alive_player, opts)
	end
	holder.sessions[id] = nil
	holder.suppress_open_until[id] = Game():GetFrameCount() + 2
	if alive_player and not opts.skip_player then
		clear_selection(session, alive_player)
		session.player = alive_player
		drop_held(session)
	end
	if spec and spec.time_stop ~= false then
		pcall(function() auxi.time_free(spec.own_key) end)
	end
	if not any_session_hides_eid() then restore_eid() end
end

function holder.open(id, player)
	local spec = holder.specs[id]
	if not spec or not player then return nil end
	holder.scrub(id)
	if holder.sessions[id] then holder.close(id) end
	if spec.time_stop ~= false then
		pcall(function() auxi.time_free(spec.own_key) end)
	end
	pcall(function() selection_holder.remove_select(player, selection_key_of(spec)) end)
	if spec.lift_item ~= false and spec.item_id then
		pcall(function()
			if player:IsHoldingItem() then
				player:AnimateCollectible(spec.item_id, "HideItem", "PlayerPickup")
			end
		end)
	end
	if spec.hide_eid ~= false then hide_eid() end
	local session = {
		id = id,
		player = player,
		opened_frame = Game():GetFrameCount(),
		input_armed = false,
		wait_drop_release = true,
		was_paused = false,
		lock_until = Game():GetFrameCount() + (spec.open_lock or 16),
		action_hold_lock = false,
		focus_id = nil,
		nav_group = "tabs",
	}
	holder.sessions[id] = session
	pcall(function() selection_holder.try_select(player, selection_key_of(spec)) end)
	if spec.lift_item ~= false and spec.item_id then
		player:AnimateCollectible(spec.item_id, "LiftItem", "PlayerPickup")
	end
	if spec.time_stop ~= false then
		auxi.time_stop(spec.own_key)
	end
	if spec.on_open then pcall(spec.on_open, session, player) end
	return session
end

function holder.can_interact(session)
	if not session or not session_is_alive(session) then return false end
	if pause_menu_open() or Game():IsPaused() or session.was_paused then return false end
	if not session.input_armed then return false end
	if Game():GetFrameCount() <= session.opened_frame then return false end
	return true
end

local function action_inputs_held(session)
	if not session or not session.player then return false end
	local ctrlid = session.player.ControllerIndex or 0
	if Input.IsActionPressed(ButtonAction.ACTION_MENUCONFIRM, ctrlid) then return true end
	if Input.IsActionPressed(ButtonAction.ACTION_ITEM, ctrlid) then return true end
	if Mouse_UI and (Mouse_UI.is_down(0) or Mouse_UI.is_down(1)) then return true end
	return false
end

function holder.lock_actions(session, frames)
	if not session then return end
	if frames and frames > 0 then
		session.lock_until = Game():GetFrameCount() + frames
		session.action_hold_lock = false
		return
	end
	session.action_hold_lock = true
end

function holder.input_locked(session)
	if not session then return true end
	if Game():GetFrameCount() < (session.lock_until or 0) then return true end
	if session.action_hold_lock then
		if action_inputs_held(session) then return true end
		session.action_hold_lock = false
	end
	return false
end

local function refresh_pillcard_cache(ctrlid)
	ctrlid = ctrlid or 0
	local frame = Game():GetFrameCount()
	if pillcard.cache_frame == frame then return end
	pillcard.cache_frame = frame
	pillcard.cache_trig = false
	pillcard.cache_held = false
	pillcard.probe = true
	pillcard.cache_trig = Input.IsActionTriggered(ButtonAction.ACTION_PILLCARD, ctrlid) == true
	pillcard.cache_held = Input.IsActionPressed(ButtonAction.ACTION_PILLCARD, ctrlid) == true
	pillcard.probe = false
end

local function is_pocket_active(session)
	local spec = session and holder.specs[session.id]
	local player = session and session.player
	if not spec or not player or not spec.item_id then return false end
	if player:GetActiveItem(ActiveSlot.SLOT_POCKET) == spec.item_id then return true end
	if ActiveSlot.SLOT_POCKET2 and player:GetActiveItem(ActiveSlot.SLOT_POCKET2) == spec.item_id then return true end
	return false
end

function holder.exit_key_held(session)
	local player = session and session.player
	local ctrlid = (player and player.ControllerIndex) or 0
	if Input.IsActionPressed(ButtonAction.ACTION_DROP, ctrlid) then return true end
	if Input.IsActionPressed(ButtonAction.ACTION_MENUBACK, ctrlid) then return true end
	if Keyboard then
		if Input.IsButtonPressed(Keyboard.KEY_ESCAPE, 0) then return true end
		if Input.IsButtonPressed(Keyboard.KEY_LEFT_CONTROL, 0) then return true end
		if Input.IsButtonPressed(Keyboard.KEY_RIGHT_CONTROL, 0) then return true end
	end
	if is_pocket_active(session) then
		refresh_pillcard_cache(ctrlid)
		if pillcard.cache_held then return true end
		if Keyboard and Input.IsButtonPressed(Keyboard.KEY_Q, 0) then return true end
	end
	return false
end

function holder.exit_key_triggered(session)
	local player = session and session.player
	local ctrlid = (player and player.ControllerIndex) or 0
	if Input.IsActionTriggered(ButtonAction.ACTION_DROP, ctrlid) then return true end
	if Input.IsActionTriggered(ButtonAction.ACTION_MENUBACK, ctrlid) then return true end
	if Keyboard then
		if Input.IsButtonTriggered(Keyboard.KEY_ESCAPE, 0) then return true end
		if Input.IsButtonTriggered(Keyboard.KEY_LEFT_CONTROL, 0) then return true end
		if Input.IsButtonTriggered(Keyboard.KEY_RIGHT_CONTROL, 0) then return true end
	end
	if is_pocket_active(session) then
		refresh_pillcard_cache(ctrlid)
		if pillcard.cache_trig then return true end
		if Keyboard and Input.IsButtonTriggered(Keyboard.KEY_Q, 0) then return true end
	end
	return false
end

local function panel_keys_held(session)
	local player = session and session.player
	local ctrlid = (player and player.ControllerIndex) or 0
	if holder.exit_key_held(session) then return true end
	if Input.IsActionPressed(ButtonAction.ACTION_ITEM, ctrlid) then return true end
	if Input.IsActionPressed(ButtonAction.ACTION_MENUCONFIRM, ctrlid) then return true end
	if Input.IsActionPressed(ButtonAction.ACTION_LEFT, ctrlid)
		or Input.IsActionPressed(ButtonAction.ACTION_RIGHT, ctrlid)
		or Input.IsActionPressed(ButtonAction.ACTION_UP, ctrlid)
		or Input.IsActionPressed(ButtonAction.ACTION_DOWN, ctrlid)
		or Input.IsActionPressed(ButtonAction.ACTION_SHOOTLEFT, ctrlid)
		or Input.IsActionPressed(ButtonAction.ACTION_SHOOTRIGHT, ctrlid)
		or Input.IsActionPressed(ButtonAction.ACTION_SHOOTUP, ctrlid)
		or Input.IsActionPressed(ButtonAction.ACTION_SHOOTDOWN, ctrlid)
	then
		return true
	end
	return false
end

function holder.dir_triggered(session)
	local player = session and session.player
	if not player then return nil end
	local ctrlid = player.ControllerIndex or 0
	local function pressed(a, b)
		return Input.IsActionTriggered(a, ctrlid) or Input.IsActionTriggered(b, ctrlid)
	end
	if pressed(ButtonAction.ACTION_LEFT, ButtonAction.ACTION_SHOOTLEFT) then return "left" end
	if pressed(ButtonAction.ACTION_RIGHT, ButtonAction.ACTION_SHOOTRIGHT) then return "right" end
	if pressed(ButtonAction.ACTION_UP, ButtonAction.ACTION_SHOOTUP) then return "up" end
	if pressed(ButtonAction.ACTION_DOWN, ButtonAction.ACTION_SHOOTDOWN) then return "down" end
	return nil
end

function holder.activate_triggered(session)
	local player = session and session.player
	if not player then return false end
	local ctrlid = player.ControllerIndex or 0
	return Input.IsActionTriggered(ButtonAction.ACTION_MENUCONFIRM, ctrlid)
		or Input.IsActionTriggered(ButtonAction.ACTION_ITEM, ctrlid)
end

local function input_active(session)
	if not session_is_alive(session) then return false end
	if pause_menu_open() then return false end
	return true
end

local function discard_all_sessions(reason)
	local reopen_ids = {}
	for id, session in pairs(holder.sessions) do
		local spec = holder.specs[id]
		if spec and spec.reopen_on_room ~= false and reason == "room" then
			reopen_ids[#reopen_ids + 1] = id
		end
		holder.sessions[id] = nil
		if spec and spec.time_stop ~= false then
			pcall(function() auxi.time_free(spec.own_key) end)
		end
	end
	restore_eid()
	return reopen_ids
end

local function update_session_input(session, player)
	local spec = holder.specs[session.id]
	if not spec then return end
	if Game():GetFrameCount() <= session.opened_frame then return end
	local ctrlid = player.ControllerIndex

	if session.was_paused then
		session.input_armed = false
		session.wait_drop_release = true
		if pause_menu_open() or panel_keys_held(session) then return end
		session.was_paused = false
		session.input_armed = true
		session.wait_drop_release = false
		return
	end
	if pause_menu_open() or Game():IsPaused() then return end

	if not session.input_armed then
		if not panel_keys_held(session) then session.input_armed = true end
		return
	end

	if session.wait_drop_release then
		if not holder.exit_key_held(session) then
			session.wait_drop_release = false
		end
	elseif holder.exit_key_triggered(session) then
		if spec.on_exit then
			local keep = spec.on_exit(session, player)
			if keep then return end
		end
		holder.close(session.id)
		return
	end

	if spec.on_input then
		pcall(spec.on_input, session, player, holder.can_interact(session))
	end
end

table.insert(holder.pre_ToCall, #holder.pre_ToCall + 1, {
	CallBack = ModCallbacks.MC_INPUT_ACTION,
	params = nil,
	priority = -1000,
	Function = function(_, ent, hook, button)
		if ent == nil then return end
		local player = ent:ToPlayer()
		if not player then return end
		for id, session in pairs(holder.sessions) do
			local spec = holder.specs[id]
			if spec and spec.block_inputs ~= false and input_active(session) then
				local ok, same = pcall(function()
					return auxi.check_for_the_same(session.player, player)
				end)
				if ok and same then
					if button == ButtonAction.ACTION_PILLCARD and pillcard.probe then
						return
					end
					local blocked = spec.blocked_actions or DEFAULT_BLOCKED
					if blocked[button] then
						if hook == InputHook.IS_ACTION_TRIGGERED or hook == InputHook.IS_ACTION_PRESSED then
							return false
						elseif hook == InputHook.GET_ACTION_VALUE then
							return 0
						end
					end
				end
			end
		end
	end,
})

table.insert(holder.ToCall, #holder.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE,
	params = nil,
	Function = function(_, player)
		if holder.room_selection_cleanup_until then
			if Game():GetFrameCount() <= holder.room_selection_cleanup_until then
				for _, spec in pairs(holder.specs) do
					pcall(function()
						selection_holder.remove_select(player, selection_key_of(spec))
					end)
				end
			else
				holder.room_selection_cleanup_until = nil
			end
		end

		for id, until_frame in pairs(holder.pending_reopen) do
			local spec = holder.specs[id]
			if not spec then
				holder.pending_reopen[id] = nil
			elseif Game():GetFrameCount() > until_frame then
				holder.pending_reopen[id] = nil
				if not holder.sessions[id] and spec.item_id and player:HasCollectible(spec.item_id) and player:IsHoldingItem() then
					pcall(function()
						player:AnimateCollectible(spec.item_id, "HideItem", "PlayerPickup")
					end)
				end
			elseif not holder.sessions[id]
				and spec.item_id
				and player:HasCollectible(spec.item_id)
				and player:IsHoldingItem()
				and not pause_menu_open()
			then
				holder.suppress_open_until[id] = -1
				holder.pending_reopen[id] = nil
				holder.open(id, player)
				return
			end
		end

		for id, session in pairs(holder.sessions) do
			holder.scrub(id)
			session = holder.sessions[id]
			if session and holder.is_open(id, player) then
				local spec = holder.specs[id]
				if pause_menu_open() then
					session.was_paused = true
				else
					if spec and spec.time_stop ~= false then
						-- open() 已完成首次全量冻结；这里只低频接管会话期间的新实体。
						auxi.refresh_time_stop(spec.own_key, 15)
					end
					if spec and spec.lift_item ~= false and spec.item_id then
						if not player:IsHoldingItem() then
							player:AnimateCollectible(spec.item_id, "LiftItem", "PlayerPickup")
						end
					end
					update_session_input(session, player)
				end
			end
		end
	end,
})

table.insert(holder.ToCall, #holder.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_RENDER,
	params = nil,
	Function = function(_)
		for id, _ in pairs(holder.sessions) do
			holder.scrub(id)
		end
		if any_session_hides_eid() then hide_eid() end
		for id, session in pairs(holder.sessions) do
			if pause_menu_open() then
				session.was_paused = true
			else
				local spec = holder.specs[id]
				if spec and spec.on_render then
					pcall(spec.on_render, session)
				end
			end
		end
	end,
})

table.insert(holder.ToCall, #holder.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function(_)
		-- 旧 Player userdata 可能 Exists()==true，但 GetData() 会原生崩。只丢 Lua 状态。
		local reopen = discard_all_sessions("room")
		holder.room_selection_cleanup_until = Game():GetFrameCount() + 2
		for i = 1, #reopen do
			local id = reopen[i]
			holder.suppress_open_until[id] = Game():GetFrameCount() + 2
			holder.pending_reopen[id] = Game():GetFrameCount() + 8
		end
	end,
})

table.insert(holder.ToCall, #holder.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_GAME_EXIT,
	params = nil,
	Function = function(_)
		discard_all_sessions("exit")
		holder.pending_reopen = {}
		holder.suppress_open_until = {}
		holder.room_selection_cleanup_until = nil
	end,
})

table.insert(holder.ToCall, #holder.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	params = nil,
	Function = function(_)
		discard_all_sessions("start")
		holder.pending_reopen = {}
		holder.suppress_open_until = {}
		holder.room_selection_cleanup_until = nil
	end,
})

return holder
