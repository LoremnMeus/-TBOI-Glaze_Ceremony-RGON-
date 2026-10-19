-- Blueprint panel lifecycle / state. Structural extract from Item_Blue_Print.lua.
-- Callers keep requiring the item façade. No gameplay/UI semantic changes.
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local selection_holder = require("Qing_Remaster_scripts.others.selection_holder")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local M = {}

function M.attach(item, BP)

local selection_key = item.own_key.."select"
local eid_hide_state = nil -- nil=未接管; bool=打开前 isHidden

function BP.player_exists_safe(player)
	if not player then return false end
	local ok, exists = pcall(function() return player:Exists() end)
	return ok and exists == true
end

--- 面板是否仍绑定有效玩家（重启/换局后残留引用视为无效）
function BP.panel_is_alive()
	if item.panel == nil then return false end
	-- 重开后 FrameCount 回绕，但 Exists() 偶发仍对旧 userdata 返回 true
	local opened = item.panel.opened_frame
	if opened ~= nil and Game():GetFrameCount() < opened then
		item.panel = nil
		item.suppress_open_until = -1
		pcall(function() auxi.time_free(item.own_key) end)
		pcall(function() BP.restore_eid_after_blueprint() end)
		return false
	end
	return BP.player_exists_safe(item.panel.player)
end

function BP.same_panel_player(player)
	if not BP.panel_is_alive() or not player then return false end
	local ok, same = pcall(function()
		return auxi.check_for_the_same(item.panel.player, player)
	end)
	return ok and same == true
end

--- 开场进度 0→1（升起与淡入共用，无前置停顿）
function item.get_panel_open_t()
	local panel = item.panel
	if not panel then return 1 end
	local dur = math.max(1, item.open_rise_dur or 14)
	local u = (Game():GetFrameCount() - (panel.opened_frame or 0)) / dur
	if u <= 0 then return 0 end
	if u >= 1 then return 1 end
	return u
end

function item.get_panel_rise_offset()
	local t = item.get_panel_open_t()
	local dist = item.open_rise_distance or 72
	local e = 1 - (1 - t) ^ 3
	return (1 - e) * dist
end

function item.get_panel_alpha()
	local t = item.get_panel_open_t()
	-- 前半段更快显形，后半段稳住
	local a = t < 0.55 and (t / 0.55) or 1
	return a
end

function item.panel_rise_finished()
	return item.get_panel_open_t() >= 1
end

--- 蓝图面板是否打开（可选限定玩家）。时停期间小青标记仍可能读输入，调用方须自行屏蔽。
function item.is_panel_open(player)
	if not BP.panel_is_alive() then return false end
	if player == nil then return true end
	return BP.same_panel_player(player)
end

-- ---------- 视图切换 ----------
function BP.set_tab(panel, idx)
	if idx < 1 or idx > #item.tabs then return end
	if panel.craft then BP.save_craft_draft(panel) end
	panel.tab = idx
	panel.view = "list"
	panel.craft = nil
	panel.drag = nil
	panel.form_press = nil
	panel.pad_carry = nil
	panel.delete_confirm_uid = nil
	panel.focus_id = "tab_"..idx
	panel.nav_group = "tabs"
	panel.body_focus_mem = nil
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_CLIP_CLOSE, 0.55, 1, false, 0, 2)
end

function BP.clear_blueprint_selection(player)
	pcall(function()
		local function safe_remove(p)
			if not BP.player_exists_safe(p) then return end
			selection_holder.remove_select(p, selection_key)
		end
		if player then
			safe_remove(player)
			return
		end
		local n = Game():GetNumPlayers()
		if not n or n < 1 then return end
		for i = 0, n - 1 do
			safe_remove(Game():GetPlayer(i))
		end
	end)
end

-- 蓝图面板打开期间暂时隐藏 EID（关闭后恢复原状态）
function BP.hide_eid_for_blueprint()
	if not EID then return end
	if eid_hide_state == nil then
		eid_hide_state = EID.isHidden and true or false
	end
	EID.isHidden = true
end

function BP.restore_eid_after_blueprint()
	if eid_hide_state == nil then return end
	if EID then
		EID.isHidden = eid_hide_state
	end
	eid_hide_state = nil
end

function BP.close_panel(skip_draft)
	if not item.panel then
		-- 无面板时勿强行遍历玩家清选择（暂停重置途中不安全）
		pcall(function() auxi.time_free(item.own_key) end)
		BP.restore_eid_after_blueprint()
		return
	end
	-- 重置/换房时 panel.player 可能已失效：只在仍 Exists 时碰 GetData
	local alive_player = BP.player_exists_safe(item.panel.player) and item.panel.player or nil
	if not skip_draft and item.panel.craft and alive_player then
		pcall(function() BP.save_craft_draft(item.panel) end)
	end
	pcall(function() BP.get_tutorial().on_panel_closed(alive_player) end)
	-- 先清 panel，避免换房时实体失效导致半清理卡死
	item.panel = nil
	item.suppress_open_until = Game():GetFrameCount() + 2
	if alive_player then
		BP.clear_blueprint_selection(alive_player)
		BP.drop_held_blueprint(alive_player)
		pcall(function()
			local Spwq = require("Qing_Remaster_scripts.player.player_Spwq")
			if Spwq and Spwq.seed_formation_hold then
				Spwq.seed_formation_hold(alive_player)
			end
		end)
	end
	-- alive_player 为空时禁止遍历 GetPlayer：暂停菜单重置途中 userdata 上 GetData 会硬崩
	pcall(function() auxi.time_free(item.own_key) end)
	BP.restore_eid_after_blueprint()
end

function BP.drop_held_blueprint(player)
	if not BP.player_exists_safe(player) then return end
	pcall(function()
		if player:IsHoldingItem() then
			player:AnimateCollectible(item.entity, "HideItem", "PlayerPickup")
		end
	end)
end

--- 清掉失效/残留面板（重启游戏后 module 级 item.panel 可能仍在）
function BP.scrub_stale_panel()
	if not item.panel then return false end
	if BP.panel_is_alive() then return false end
	item.panel = nil
	item.suppress_open_until = -1
	-- 面板玩家已失效：禁止 BP.clear_blueprint_selection(nil) / 遍历 GetPlayer（重置时 GetData 会崩）
	pcall(function() auxi.time_free(item.own_key) end)
	BP.restore_eid_after_blueprint()
	return true
end

function BP.open_panel(player)
	BP.scrub_stale_panel()
	if item.panel then BP.close_panel() end
	-- 换房残留保险
	pcall(function() auxi.time_free(item.own_key) end)
	pcall(function() selection_holder.remove_select(player, selection_key) end)
	BP.drop_held_blueprint(player)
	BP.hide_eid_for_blueprint()
	item.panel = {
		player = player,
		tab = 1,
		view = "list",
		craft = nil,
		drag = nil,
		pad_carry = nil, -- {token_id} 四向模式搬运中
		focus_id = "tab_1",
		nav_group = "tabs",
		body_focus_mem = nil,
		nav_hold = nil,
		lock_until = Game():GetFrameCount() + item.action_delay + (item.open_rise_dur or 14),
		opened_frame = Game():GetFrameCount(),
		input_armed = false,
		wait_drop_release = true,
		was_paused = false,
		ui = {},
		list_selected = 1,
	}
	selection_holder.try_select(player, selection_key)
	player:AnimateCollectible(item.entity, "LiftItem", "PlayerPickup")
	auxi.time_stop(item.own_key)
	item.refresh_craft_integrity(player)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOOK_PAGE_TURN_12, 1, 1, false, 0, 2)
	pcall(function() BP.get_tutorial().on_panel_opened(player) end)
end

function item.open_for_player(player)
	if not player then return false end
	BP.scrub_stale_panel()
	if BP.same_panel_player(player) then return true end
	if item.panel then BP.close_panel() end
	BP.open_panel(player)
	return true
end

end

return M
