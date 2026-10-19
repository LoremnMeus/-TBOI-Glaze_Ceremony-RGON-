-- Blueprint panel input / navigation / drag intent.
-- Structural extract from Item_Blue_Print.lua. No gameplay/UI semantic changes.
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Mouse_UI = require("Qing_Remaster_scripts.others.Mouse_UI_holder")
local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")

local M = {}

function M.attach(item, BP)

-- PILLCARD 被 MC_INPUT_ACTION 拦掉后，IsAction* 读不到真值；探测时放行一次并缓存本帧
local pillcard = {
	probe = false,
	cache_frame = -1,
	cache_trig = false,
	cache_held = false,
}

function BP.pillcard_is_probing()
	return pillcard.probe == true
end

function BP.action_inputs_held(panel)
	if not panel or not panel.player then return false end
	local ctrlid = panel.player.ControllerIndex or 0
	if Input.IsActionPressed(ButtonAction.ACTION_MENUCONFIRM, ctrlid) then return true end
	if Input.IsActionPressed(ButtonAction.ACTION_ITEM, ctrlid) then return true end
	if Mouse_UI and (Mouse_UI.is_down(0) or Mouse_UI.is_down(1)) then return true end
	return false
end

-- 开场仍用 lock_until；操作后改为“触发一次，松手即结束锁定”，便于双击

function BP.input_locked(panel)
	if Game():GetFrameCount() < (panel.lock_until or 0) then return true end
	if panel.action_hold_lock then
		if BP.action_inputs_held(panel) then return true end
		panel.action_hold_lock = false
	end
	return false
end

function BP.lock_actions(panel, frames)
	if not panel then return end
	if frames and frames > 0 and frames < (item.action_delay or 12) then
		-- 显式短锁（如翻页）仍按帧
		panel.lock_until = Game():GetFrameCount() + frames
		panel.action_hold_lock = false
		return
	end
	panel.action_hold_lock = true
end

function BP.focus_equals(panel, id)
	return panel and panel.focus_id == id
end

function BP.form_queue_insert_index(ui, mouse, drag_uid)
	local cards = (ui and ui.form_queue_cards) or {}
	local xs = {}
	for _, c in ipairs(cards) do
		if c.uid ~= drag_uid then
			xs[#xs + 1] = c.rect.x + c.rect.w * 0.5
		end
	end
	local idx = #xs + 1
	for i = 1, #xs do
		if mouse.X < xs[i] then
			idx = i
			break
		end
	end
	return idx
end

function BP.finish_form_drag(panel, ui)
	local drag = panel.drag
	panel.drag = nil
	panel.form_press = nil
	if not drag or drag.kind ~= "form_card" or not panel.player then return end
	ui = ui or panel.ui
	local mouse = Mouse_UI.mouse
	local BW = BP.get_bandwidth()
	if ui and ui.form_queue_rect and Mouse_UI.point_in_rect(mouse, ui.form_queue_rect) then
		local idx = BP.form_queue_insert_index(ui, mouse, drag.uid)
		if not BW.place_as_active(panel.player, drag.uid, idx) then
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.7, 1.1, false, 0, 2)
		else
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_BUTTON_PRESS, 0.75, 1, false, 0, 2)
		end
	elseif ui and ui.form_bench_rect and Mouse_UI.point_in_rect(mouse, ui.form_bench_rect) then
		BW.set_active(panel.player, drag.uid, false)
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_DARK, 0.5, 1, false, 0, 2)
	else
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_DARK, 0.35, 1, false, 0, 2)
	end
	-- 松手当帧必须按新 order 重建：否则 drag 已清空，旧 layouts 会在原槽再画一帧。
	panel.ui = nil
	panel.nav_graph = nil
end

function BP.handle_formation_id(panel, id)
	if not panel or not id or not panel.player then return false end
	local BW = BP.get_bandwidth()
	if id == "form_prev" then
		panel.form_bench_page = math.max(0, (panel.form_bench_page or 0) - 1)
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.35, 1, false, 0, 2)
		return true
	end
	if id == "form_next" then
		local pages = math.max(1, panel._form_bench_pages or 1)
		panel.form_bench_page = math.min(pages - 1, (panel.form_bench_page or 0) + 1)
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.35, 1, false, 0, 2)
		return true
	end
	for _, lay in ipairs((panel.ui and panel.ui.layouts) or {}) do
		local e = lay.entry
		if e and e.kind == "form_card" and e.rec and id == e.uid then
			if panel.form_carry then
				local carry_uid = panel.form_carry.uid
				panel.form_carry = nil
				if e.zone == "queue" then
					if not BW.place_as_active(panel.player, carry_uid, e.active_index or 1) then
						sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.7, 1.1, false, 0, 2)
					else
						sound_tracker.PlayStackedSound(SoundEffect.SOUND_BUTTON_PRESS, 0.75, 1, false, 0, 2)
					end
				else
					BW.set_active(panel.player, carry_uid, false)
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_DARK, 0.5, 1, false, 0, 2)
				end
				return true
			end
			if e.zone == "bench" then
				if not BW.place_as_active(panel.player, e.rec.uid, 999) then
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.7, 1.1, false, 0, 2)
				else
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_BUTTON_PRESS, 0.75, 1, false, 0, 2)
				end
			else
				panel.form_carry = {uid = e.rec.uid}
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.45, 1, false, 0, 2)
			end
			return true
		end
	end
	if panel.form_carry then
		if id == "form_queue" then
			local uid = panel.form_carry.uid
			panel.form_carry = nil
			if not BW.place_as_active(panel.player, uid, 999) then
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.7, 1.1, false, 0, 2)
			else
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_BUTTON_PRESS, 0.75, 1, false, 0, 2)
			end
			return true
		end
		if id == "form_bench" then
			BW.set_active(panel.player, panel.form_carry.uid, false)
			panel.form_carry = nil
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_DARK, 0.5, 1, false, 0, 2)
			return true
		end
	end
	return false
end

function BP.nav_add(list, id, x, y, meta)
	if not id then return end
	list[#list + 1] = {id = id, x = x, y = y, meta = meta or {}}
end

function BP.index_of_id(list, id)
	for i, n in ipairs(list) do
		if n.id == id then return i end
	end
	return nil
end

function BP.sort_reading(list)
	table.sort(list, function(a, b)
		if math.abs(a.y - b.y) > 10 then return a.y < b.y end
		return a.x < b.x
	end)
end

--- 组内前进方向无目标时回到第一项；后退方向无目标时回到最后一项（不反向挪到邻轴）

function BP.pick_forward_or_edge(list, from, dirx, diry)
	local best_id, best = nil, math.huge
	for _, to in ipairs(list) do
		if to.id ~= from.id then
			local dx, dy = to.x - from.x, to.y - from.y
			local primary = dx * dirx + dy * diry
			local lateral = math.abs(dx * (-diry) + dy * dirx)
			if primary > 3 then
				local s = primary + lateral * 2.4
				if s < best then best, best_id = s, to.id end
			end
		end
	end
	if best_id then return best_id end
	if #list == 0 then return from.id end
	-- 右/下：回第一项；左/上：去最后一项
	if dirx > 0 or diry > 0 then
		return list[1].id
	end
	return list[#list].id
end

function BP.rebuild_nav_groups(panel, ui)
	local tabs = {}
	for i = 1, #item.tabs do
		local r = ui.tab_rects[i]
		if r then BP.nav_add(tabs, "tab_"..i, r.x + r.w * 0.5, r.y + r.h * 0.5) end
	end

	local body = {}
	local craft = panel.craft
	local g = ui.craft_geom
	local body_name = "body"

	if craft and g then
		if panel.pad_carry then
			body_name = "carry"
			for i, slot in ipairs(craft.slots) do
				if slot._rect then
					local c = Mouse_UI.rect_center(slot._rect)
					BP.nav_add(body, "cslot_"..i, c.X, c.Y, {slot = true})
				end
			end
			if g.cost_rect then
				BP.nav_add(body, "cost_slot", g.cost_pos.X, g.cost_pos.Y, {cost = true})
			end
			if g.mirror_rect then
				BP.nav_add(body, "mirror_slot", g.mirror_pos.X, g.mirror_pos.Y, {slot = true, mirror = true})
			end
			for _, tok in ipairs(craft.tokens) do
				if tok.from_bag and tok.id ~= panel.pad_carry.token_id then
					local p = tok.home or tok.pos
					if p then BP.nav_add(body, "dropbag_"..tok.id, p.X, p.Y, {bag = true}) end
				end
			end
			local has_bag = false
			for _, n in ipairs(body) do if n.meta.bag then has_bag = true break end end
			if not has_bag and g.bag_inner then
				BP.nav_add(body, "bag_return", g.bag_inner.x + g.bag_inner.w * 0.5, g.bag_inner.y + g.bag_inner.h * 0.5, {bag = true})
			end
			BP.nav_add(body, "btn_back", g.back_rect.x + g.back_rect.w * 0.5, g.back_rect.y + g.back_rect.h * 0.5)
		else
			if g.quality_rect then
				BP.nav_add(body, "btn_quality", g.quality_rect.x + g.quality_rect.w * 0.5, g.quality_rect.y + g.quality_rect.h * 0.5)
			end
			if not craft.tutorial_bag and BP.all_items_mode_allowed() then
				BP.nav_add(body, "btn_mode", g.mode_rect.x + g.mode_rect.w * 0.5, g.mode_rect.y + g.mode_rect.h * 0.5)
			end
			if g.tag_col then
				BP.nav_add(body, "btn_tag_all", g.tag_col.all_rect.x + g.tag_col.all_rect.w * 0.5, g.tag_col.all_rect.y + g.tag_col.all_rect.h * 0.5)
				BP.nav_add(body, "btn_tag_invert", g.tag_col.invert_rect.x + g.tag_col.invert_rect.w * 0.5, g.tag_col.invert_rect.y + g.tag_col.invert_rect.h * 0.5)
				for _, def in ipairs(g.tag_col.defs or {}) do
					local r = g.tag_col.tag_rects and g.tag_col.tag_rects[def.key]
					if r then
						BP.nav_add(body, "btn_tag_"..def.key, r.x + r.w * 0.5, r.y + r.h * 0.5)
					end
				end
			end
			BP.nav_add(body, "btn_prev", g.prev_rect.x + g.prev_rect.w * 0.5, g.prev_rect.y + g.prev_rect.h * 0.5)
			BP.nav_add(body, "btn_next", g.next_rect.x + g.next_rect.w * 0.5, g.next_rect.y + g.next_rect.h * 0.5)
			if g.cost_rect then
				BP.nav_add(body, "cost_slot", g.cost_pos.X, g.cost_pos.Y, {cost = true})
			end
			if g.mirror_rect then
				BP.nav_add(body, "mirror_slot", g.mirror_pos.X, g.mirror_pos.Y, {slot = true, mirror = true})
			end
			for i, slot in ipairs(craft.slots) do
				if slot._rect and slot.token then
					local c = Mouse_UI.rect_center(slot._rect)
					BP.nav_add(body, "cslot_"..i, c.X, c.Y, {slot = true})
				end
			end
			for _, tok in ipairs(craft.tokens) do
				if tok.from_bag and not tok.slot then
					local p = tok.pos or tok.home
					if p then BP.nav_add(body, tok.id, p.X, p.Y, {token = true}) end
				end
			end
			BP.nav_add(body, "btn_confirm", g.confirm_rect.x + g.confirm_rect.w * 0.5, g.confirm_rect.y + g.confirm_rect.h * 0.5)
			BP.nav_add(body, "btn_back", g.back_rect.x + g.back_rect.w * 0.5, g.back_rect.y + g.back_rect.h * 0.5)
		end
	else
		for _, lay in ipairs(ui.layouts or {}) do
			local r = lay.rect
			if r and lay.entry and lay.entry.kind ~= "todo" then
				BP.nav_add(body, lay.entry.uid, r.x + 40, r.y + r.h * 0.5, {list = true})
				if lay.del_rect and lay.entry.del_uid then
					local dr = lay.del_rect
					BP.nav_add(body, lay.entry.del_uid, dr.x + dr.w * 0.5, dr.y + dr.h * 0.5, {list_del = true})
				end
			end
		end
	end

	BP.sort_reading(tabs)
	BP.sort_reading(body)

	if ui.tut then
		for _, b in ipairs(ui.tut.buttons or {}) do
			local r = b.rect
			if r then BP.nav_add(body, b.id, r.x + r.w * 0.5, r.y + r.h * 0.5) end
		end
		BP.sort_reading(body)
	end
	if BP.get_tutorial().is_locking() then
		local function keep_allowed(list)
			local out = {}
			for _, n in ipairs(list) do
				if BP.get_tutorial().allows(n.id) then out[#out + 1] = n end
			end
			return out
		end
		tabs = keep_allowed(tabs)
		body = keep_allowed(body)
	end

	-- 搬运模式只有 body 组；其它时候 tabs + body
	local groups = {}
	if body_name == "carry" then
		groups.carry = body
		panel.nav_group = "carry"
	else
		groups.tabs = tabs
		groups.body = body
		if panel.nav_group ~= "tabs" and panel.nav_group ~= "body" then
			panel.nav_group = panel.craft and "body" or "tabs"
		end
	end

	panel._nav_groups = groups
	panel._focus_nodes = body_name == "carry" and body or (panel.nav_group == "tabs" and tabs or body)

	-- 校正焦点落在当前组内
	local cur = groups[panel.nav_group]
	if not cur or #cur == 0 then
		if groups.tabs and #groups.tabs > 0 then
			panel.nav_group = "tabs"
			cur = groups.tabs
		elseif groups.body and #groups.body > 0 then
			panel.nav_group = "body"
			cur = groups.body
		elseif groups.carry and #groups.carry > 0 then
			panel.nav_group = "carry"
			cur = groups.carry
		end
	end
	if cur and #cur > 0 and not BP.index_of_id(cur, panel.focus_id) then
		panel.focus_id = cur[1].id
	end
	return groups
end

function BP.rebuild_focus_graph(panel, ui)
	return BP.rebuild_nav_groups(panel, ui)
end

function BP.is_top_row_of(list, id)
	local idx = BP.index_of_id(list, id)
	if not idx then return true end
	local y0 = list[idx].y
	for i = 1, #list do
		if list[i].y < y0 - 10 then return false end
	end
	return true
end

function BP.move_focus(panel, dir)
	local groups = panel._nav_groups
	if not groups then return false end
	local gname = panel.nav_group or "tabs"
	local list = groups[gname]
	if not list or #list == 0 then return false end
	local idx = BP.index_of_id(list, panel.focus_id) or 1
	local from = list[idx]

	-- 组切换：tabs ↔ body
	if gname == "tabs" then
		if dir == "down" and groups.body and #groups.body > 0 then
			panel.body_focus_mem = panel.body_focus_mem
			panel.nav_group = "body"
			local mem = panel.body_focus_mem
			if mem and BP.index_of_id(groups.body, mem) then
				panel.focus_id = mem
			else
				panel.focus_id = groups.body[1].id
			end
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.25, 1.1, false, 0, 2)
			return true
		end
		if dir == "up" then return false end
		-- 左右只在 tabs 内；越界回第一/最后
		local dirx = (dir == "right" and 1) or (dir == "left" and -1) or 0
		if dirx == 0 then return false end
		-- 选项页用线性左右更直观
		local nidx
		if dir == "right" then
			nidx = (idx >= #list) and 1 or (idx + 1)
		else
			nidx = (idx <= 1) and #list or (idx - 1)
		end
		if list[nidx].id == panel.focus_id then return false end
		panel.focus_id = list[nidx].id
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.25, 1.1, false, 0, 2)
		return true
	end

	if (gname == "body" or gname == "carry") then
		if gname == "body" and dir == "up" and BP.is_top_row_of(list, from.id) and groups.tabs and #groups.tabs > 0 then
			panel.body_focus_mem = panel.focus_id
			panel.nav_group = "tabs"
			panel.focus_id = "tab_"..tostring(panel.tab or 1)
			if not BP.index_of_id(groups.tabs, panel.focus_id) then
				panel.focus_id = groups.tabs[1].id
			end
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.25, 1.1, false, 0, 2)
			return true
		end
		local dirx = (dir == "right" and 1) or (dir == "left" and -1) or 0
		local diry = (dir == "down" and 1) or (dir == "up" and -1) or 0
		local nxt = BP.pick_forward_or_edge(list, from, dirx, diry)
		if not nxt or nxt == panel.focus_id then return false end
		panel.focus_id = nxt
		if gname == "body" then panel.body_focus_mem = nxt end
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.25, 1.1, false, 0, 2)
		return true
	end
	return false
end

function BP.get_held_nav_dir(ctrlid)
	local function down(a) return Input.IsActionPressed(a, ctrlid) end
	-- 同时按下时优先最近一次：按左/右/上/下固定优先级
	if down(ButtonAction.ACTION_LEFT) or down(ButtonAction.ACTION_MENULEFT) then return "left" end
	if down(ButtonAction.ACTION_RIGHT) or down(ButtonAction.ACTION_MENURIGHT) then return "right" end
	if down(ButtonAction.ACTION_UP) or down(ButtonAction.ACTION_MENUUP) then return "up" end
	if down(ButtonAction.ACTION_DOWN) or down(ButtonAction.ACTION_MENUDOWN) then return "down" end
	return nil
end

function BP.toggle_all_items_mode(panel)
	local craft = panel.craft
	if not craft or craft.tutorial_bag then return false end
	if not BP.all_items_mode_allowed() then
		craft.all_items = false
		return false
	end
	craft.all_items = not craft.all_items
	craft.bag_page = 0
	craft._catalog = nil
	craft._catalog_impl = nil
	craft._catalog_missing_stat = nil
	if craft.all_items then
		local prefs = BP.get_audit_ui_prefs(panel.player)
		craft.audit_filter = "all"
		craft.hide_gray = false
		craft.tag_enabled = CraftProfile.normalize_audit_tag_enabled(
			prefs.tag_enabled, prefs.audit_filter or (prefs.hide_gray and "impl" or "all")
		)
		prefs.tag_enabled = craft.tag_enabled
		prefs.audit_filter = "all"
		prefs.hide_gray = false
	end
	BP.clear_bag_tokens_keep_busy(craft, panel)
	panel.nav_graph = nil
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.55, 1, false, 0, 2)
	return true
end

function BP.persist_craft_tag_prefs(panel, craft)
	local prefs = BP.get_audit_ui_prefs(panel.player)
	prefs.tag_enabled = CraftProfile.normalize_audit_tag_enabled(craft.tag_enabled)
	craft.tag_enabled = prefs.tag_enabled
	prefs.audit_filter = "all"
	prefs.hide_gray = false
end

function BP.refresh_after_tag_change(panel, craft)
	craft.bag_page = 0
	BP.clear_bag_tokens_keep_busy(craft, panel)
	panel.nav_graph = nil
	BP.persist_craft_tag_prefs(panel, craft)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.4, 1, false, 0, 2)
end

function BP.toggle_audit_tag(panel, key)
	local craft = panel.craft
	if not craft or not craft.all_items or not key then return end
	craft.tag_enabled = CraftProfile.normalize_audit_tag_enabled(craft.tag_enabled)
	craft.tag_enabled[key] = not (craft.tag_enabled[key] == true)
	BP.refresh_after_tag_change(panel, craft)
end

function BP.enable_all_audit_tags(panel)
	local craft = panel.craft
	if not craft or not craft.all_items then return end
	craft.tag_enabled = CraftProfile.default_audit_tag_enabled()
	BP.refresh_after_tag_change(panel, craft)
end

function BP.invert_audit_tags(panel)
	local craft = panel.craft
	if not craft or not craft.all_items then return end
	craft.tag_enabled = CraftProfile.normalize_audit_tag_enabled(craft.tag_enabled)
	for _, def in ipairs(CraftProfile.audit_filter_tag_defs()) do
		craft.tag_enabled[def.key] = not (craft.tag_enabled[def.key] == true)
	end
	BP.refresh_after_tag_change(panel, craft)
end

function BP.cancel_pad_carry(panel)
	local craft = panel.craft
	if not craft or not panel.pad_carry then return end
	local tok = craft.token_map[panel.pad_carry.token_id]
	panel.pad_carry = nil
	if tok then
		BP.clear_token_slot(craft, tok)
		if tok.home then BP.begin_snap_anim(tok, tok.home) end
	end
	panel.nav_group = "body"
	panel.focus_id = tok and tok.id or "btn_confirm"
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_DARK, 0.4, 1, false, 0, 2)
end

-- 副手 = 口袋主动；此时面板内 Q ≡ Ctrl 退出（否则只拦 Q，防误用卡牌）

function BP.blueprint_is_pocket_active(player)
	if not player then return false end
	if player:GetActiveItem(ActiveSlot.SLOT_POCKET) == item.entity then return true end
	if ActiveSlot.SLOT_POCKET2 and player:GetActiveItem(ActiveSlot.SLOT_POCKET2) == item.entity then return true end
	return false
end

-- PILLCARD 被 MC_INPUT_ACTION 拦掉后，IsAction* 读不到真值；探测时放行一次并缓存本帧

function BP.refresh_pillcard_cache(ctrlid)
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

function BP.pocket_q_exit_triggered(player, ctrlid)
	if not BP.blueprint_is_pocket_active(player) then return false end
	BP.refresh_pillcard_cache(ctrlid)
	if pillcard.cache_trig then return true end
	if Keyboard and Input.IsButtonTriggered(Keyboard.KEY_Q, 0) then return true end
	return false
end

function BP.pocket_q_exit_held(player, ctrlid)
	if not BP.blueprint_is_pocket_active(player) then return false end
	BP.refresh_pillcard_cache(ctrlid)
	if pillcard.cache_held then return true end
	if Keyboard and Input.IsButtonPressed(Keyboard.KEY_Q, 0) then return true end
	return false
end

--- ESC / CTRL(DROP) / MENUBACK /（口袋副手时）Q：逐级退出（搬运→制造页→关面板）

function BP.exit_key_triggered(ctrlid, player)
	ctrlid = ctrlid or 0
	if Input.IsActionTriggered(ButtonAction.ACTION_DROP, ctrlid) then return true end
	if Input.IsActionTriggered(ButtonAction.ACTION_MENUBACK, ctrlid) then return true end
	if Keyboard then
		if Input.IsButtonTriggered(Keyboard.KEY_ESCAPE, 0) then return true end
		if Input.IsButtonTriggered(Keyboard.KEY_LEFT_CONTROL, 0) then return true end
		if Input.IsButtonTriggered(Keyboard.KEY_RIGHT_CONTROL, 0) then return true end
	end
	if player and BP.pocket_q_exit_triggered(player, ctrlid) then return true end
	return false
end

function BP.exit_key_held(ctrlid, player)
	ctrlid = ctrlid or 0
	if Input.IsActionPressed(ButtonAction.ACTION_DROP, ctrlid) then return true end
	if Input.IsActionPressed(ButtonAction.ACTION_MENUBACK, ctrlid) then return true end
	if Keyboard then
		if Input.IsButtonPressed(Keyboard.KEY_ESCAPE, 0) then return true end
		if Input.IsButtonPressed(Keyboard.KEY_LEFT_CONTROL, 0) then return true end
		if Input.IsButtonPressed(Keyboard.KEY_RIGHT_CONTROL, 0) then return true end
	end
	if player and BP.pocket_q_exit_held(player, ctrlid) then return true end
	return false
end

function BP.panel_keys_held(ctrlid, player)
	ctrlid = ctrlid or 0
	if BP.exit_key_held(ctrlid, player) then return true end
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

function BP.pause_menu_open()
	return auxi.is_pause_menu_open()
end

--- 对齐逢魔：面板开着且未进暂停时拦截输入（含 ent==nil 的菜单查询）

function BP.blueprint_input_active()
	BP.scrub_stale_panel()
	if not BP.panel_is_alive() then return false end
	if BP.pause_menu_open() then return false end
	return true
end

function BP.disarm_until_release(panel)
	if not panel then return end
	panel.input_armed = false
	panel.wait_drop_release = true
end

function BP.try_panel_exit(panel)
	if not panel or BP.input_locked(panel) then return false end
	local tut = BP.get_tutorial()
	local advanced = tut.note_close_attempt and tut.note_close_attempt(panel.player) == true
	if tut.blocks_close(panel.player) then
		if advanced then
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.45, 1, false, 0, 2)
		else
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.45, 1.2, false, 0, 2)
		end
		BP.lock_actions(panel)
		return true
	end
	if panel.pad_carry then
		BP.cancel_pad_carry(panel)
		BP.lock_actions(panel)
		return true
	end
	if panel.craft then
		if panel.view == "edit" then BP.cancel_edit(panel) else BP.leave_craft_view(panel) end
		BP.lock_actions(panel)
		return true
	end
	BP.close_panel()
	return true
end

function BP.start_pad_carry(panel, tok)
	if not tok then return end
	BP.clear_token_slot(panel.craft, tok)
	panel.pad_carry = {token_id = tok.id}
	panel.drag = nil
	tok.anim = nil
	tok.vel = Vector(0, 0)
	panel.nav_group = "carry"
	panel.focus_id = "cslot_1"
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.45, 1, false, 0, 2)
end

function BP.activate_focus(panel, ui)
	local id = panel.focus_id
	if not id then return end
	if id == "tut_yes" then
		BP.get_tutorial().accept(panel.player)
		BP.lock_actions(panel)
		return
	end
	if id == "tut_no" then
		BP.get_tutorial().decline(panel.player)
		BP.lock_actions(panel)
		return
	end
	if BP.get_tutorial().is_locking() and not BP.get_tutorial().allows(id) then
		return
	end
	local craft = panel.craft

	if panel.pad_carry and craft then
		local tok = craft.token_map[panel.pad_carry.token_id]
		if not tok then
			panel.pad_carry = nil
			return
		end
		if id == "btn_back" then
			BP.cancel_pad_carry(panel)
			BP.lock_actions(panel)
			return
		end
		if id:sub(1, 6) == "cslot_" then
			local idx = tonumber(id:sub(7))
			if idx then
				BP.assign_token_slot(craft, tok, idx)
				panel.pad_carry = nil
				panel.nav_group = "body"
				panel.focus_id = id
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_BUTTON_PRESS, 0.7, 1.05, false, 0, 2)
				BP.lock_actions(panel)
			end
			return
		end
		if id == "cost_slot" then
			BP.assign_token_cost(craft, tok, ui and ui.craft_geom)
			panel.pad_carry = nil
			panel.nav_group = "body"
			panel.focus_id = "cost_slot"
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_BUTTON_PRESS, 0.65, 0.95, false, 0, 2)
			BP.lock_actions(panel)
			return
		end
		if id == "mirror_slot" then
			BP.assign_mirror_token(craft, tok, ui and ui.craft_geom)
			panel.pad_carry = nil
			panel.nav_group = "body"
			panel.focus_id = "mirror_slot"
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_BUTTON_PRESS, 0.7, 1.05, false, 0, 2)
			BP.lock_actions(panel)
			return
		end
		if id:sub(1, 8) == "dropbag_" or id == "bag_return" then
			BP.clear_token_slot(craft, tok)
			if craft.all_items and type(tok.id) == "string" and tok.id:sub(1, 5) == "inst_" then
				BP.remove_token_entity(craft, tok)
			else
				if not craft.all_items then
					tok.from_bag = true
					if tok.lost or tok.lost_ghost then
						tok.lost_ghost = true
						tok.lost = true
					end
				end
				local dest = tok.home or BP.bag_area_anchor(tok)
				tok.home = dest
				BP.begin_snap_anim(tok, dest)
			end
			panel.pad_carry = nil
			panel.nav_group = "body"
			panel.focus_id = (id:sub(1, 8) == "dropbag_") and id:sub(9) or "btn_confirm"
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_DARK, 0.4, 1, false, 0, 2)
			BP.lock_actions(panel)
			return
		end
		return
	end

	if id:sub(1, 4) == "tab_" then
		local idx = tonumber(id:sub(5))
		if idx then
			local tab_info = item.tabs[idx]
			-- 已在建造列表：再确认则聚焦下方第一项，便于连按空格进入制造
			if tab_info and tab_info.id == "build"
				and panel.tab == idx and not panel.craft
			then
				local body = panel._nav_groups and panel._nav_groups.body
				if body and #body > 0 then
					panel.nav_group = "body"
					panel.focus_id = body[1].id
					panel.body_focus_mem = body[1].id
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.35, 1, false, 0, 2)
					BP.lock_actions(panel)
					return
				end
			end
			BP.set_tab(panel, idx)
			BP.lock_actions(panel)
		end
		return
	end

	if craft then
		if id == "btn_back" then
			if panel.view == "edit" then BP.cancel_edit(panel) else BP.leave_craft_view(panel) end
			BP.lock_actions(panel)
			return
		end
		if id == "btn_confirm" then
			BP.confirm_craft(panel)
			BP.lock_actions(panel)
			return
		end
		if id == "btn_quality" then
			BP.toggle_show_quality(panel)
			BP.lock_actions(panel)
			return
		end
		if id == "btn_mode" then
			BP.toggle_all_items_mode(panel)
			BP.lock_actions(panel)
			return
		end
		if id == "btn_tag_all" then
			BP.enable_all_audit_tags(panel)
			BP.lock_actions(panel)
			return
		end
		if id == "btn_tag_invert" then
			BP.invert_audit_tags(panel)
			BP.lock_actions(panel)
			return
		end
		if type(id) == "string" and id:sub(1, 8) == "btn_tag_" then
			local key = id:sub(9)
			if key ~= "all" and key ~= "invert" then
				BP.toggle_audit_tag(panel, key)
				BP.lock_actions(panel)
			end
			return
		end
		if id == "btn_prev" then
			craft.bag_page = math.max(0, (craft.bag_page or 0) - 1)
			BP.clear_bag_tokens_keep_busy(craft, panel)
			panel.nav_graph = nil
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.35, 1, false, 0, 2)
			BP.lock_actions(panel)
			return
		end
		if id == "btn_next" then
			local pages = craft.bag_pages or 1
			craft.bag_page = math.min(pages - 1, (craft.bag_page or 0) + 1)
			BP.clear_bag_tokens_keep_busy(craft, panel)
			panel.nav_graph = nil
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.35, 1, false, 0, 2)
			BP.lock_actions(panel)
			return
		end
		if id == "cost_slot" then
			local ids = craft.cost_ids or {}
			local tid = ids[#ids]
			local ctok = tid and craft.token_map[tid]
			if ctok then BP.start_pad_carry(panel, ctok) BP.lock_actions(panel) end
			return
		end
		if id:sub(1, 6) == "cslot_" then
			local idx = tonumber(id:sub(7))
			local slot = idx and craft.slots[idx]
			if slot and slot.token then
				local tok = craft.token_map[slot.token]
				if tok then BP.start_pad_carry(panel, tok) BP.lock_actions(panel) end
			end
			return
		end
		local tok = craft.token_map[id]
		if tok then
			BP.start_pad_carry(panel, tok)
			BP.lock_actions(panel)
			return
		end
		return
	end

	if BP.handle_formation_id(panel, id) then
		BP.lock_actions(panel)
		return
	end

	for _, lay in ipairs(ui.layouts or {}) do
		if lay.entry and lay.entry.uid == id then
			local e = lay.entry
			panel.delete_confirm_uid = nil
			if e.kind == "build_target" then
				BP.open_craft_view(panel, e.target, nil)
			elseif e.kind == "stock" then
				BP.open_craft_view(panel, e.rec.target, e.rec.uid)
			end
			BP.lock_actions(panel)
			return
		end
		if lay.entry and lay.entry.del_uid == id and lay.entry.kind == "stock" then
			BP.try_confirm_delete_stock(panel, lay.entry.rec.uid)
			BP.lock_actions(panel)
			return
		end
	end
end

function BP.handle_pad_actions(panel, ui)
	local player = panel.player
	if not player then return end
	local ctrlid = player.ControllerIndex
	BP.rebuild_focus_graph(panel, ui)

	-- 搬运中：道具跟随焦点
	if panel.pad_carry and panel.craft then
		local tok = panel.craft.token_map[panel.pad_carry.token_id]
		local list = panel._nav_groups and panel._nav_groups.carry
		if tok and list then
			for _, n in ipairs(list) do
				if n.id == panel.focus_id then
					tok.pos = Vector(n.x, n.y)
					break
				end
			end
		end
	end

	-- 长按连发（仿输入法：首次立即，等待 initial，再按 interval 连发）
	local frame = Game():GetFrameCount()
	local held = BP.get_held_nav_dir(ctrlid)
	local hold = panel.nav_hold
	if held then
		if not hold or hold.dir ~= held then
			panel.nav_hold = {dir = held, next_fire = frame + item.nav_repeat_initial}
			BP.move_focus(panel, held)
		elseif frame >= (hold.next_fire or 0) then
			BP.move_focus(panel, held)
			hold.next_fire = frame + item.nav_repeat_interval
		end
	else
		panel.nav_hold = nil
	end

	if BP.input_locked(panel) then return end

	local function trig(a)
		return Input.IsActionTriggered(a, ctrlid)
	end
	if trig(ButtonAction.ACTION_MENUCONFIRM) or trig(ButtonAction.ACTION_ITEM) then
		BP.activate_focus(panel, ui)
		return
	end
	-- 退出键统一在 update_panel_input（ESC/CTRL/DROP/MENUBACK），避免同帧双退
end

function BP.capture_mouse_wheel(panel, source)
	if not panel or not Input.GetMouseWheel then return end
	local ok, wheel = pcall(function() return Input.GetMouseWheel() end)
	if not ok or not wheel then
		return
	end
	local dy = tonumber(wheel.Y) or 0
	local dx = tonumber(wheel.X) or 0
	if dx ~= 0 or dy ~= 0 then
		panel.wheel_pending = {x = dx, y = dy, source = source, serial = panel.wheel_render_serial}
	end
end

function BP.try_mouse_wheel_page(panel, ui)
	if BP.get_tutorial().is_locking() then return end
	if not panel.craft or not ui or not ui.craft_geom then return end
	-- 渲染帧率可高于 update；禁止用 Game frame 去重，否则会吞同一 update 帧内的滚轮脉冲。
	local serial = panel.wheel_render_serial or 0
	if panel.wheel_read_serial == serial then return end
	-- 制造页没有其他可滚动容器：面板打开期间，滚轮默认延拓给背包。
	-- 不再要求鼠标命中左右栏；移到面板外也能继续翻页。

	local wheel = panel.wheel_pending
	if not wheel then return end
	panel.wheel_pending = nil
	local dy = tonumber(wheel.y) or 0
	local dx = tonumber(wheel.x) or 0
	-- 少数设备把竖滚报到 X；优先 Y，否则用 X
	local delta = dy
	if delta == 0 then delta = dx end
	if delta == 0 then return end
	panel.wheel_read_serial = serial

	-- Windows 常见 ±120；高精度滚轮/触摸板可能只报小于 1 的非零量。
	-- 页面不是连续滚动容器，因此一次非零脉冲至少翻一页，避免第一下只充累加器。
	local notches
	if math.abs(delta) >= 40 then
		notches = delta / 120
		if math.abs(notches) < 1 then notches = delta > 0 and 1 or -1 end
	else
		notches = delta > 0 and 1 or -1
	end

	-- 描述区优先接管滚轮；移出后继续使用默认延拓的背包翻页。
	local audit_rect = panel.audit_scroll_rect
	local audit_max = math.max(0, tonumber(panel.audit_scroll_max) or 0)
	if audit_rect and Mouse_UI.point_in_rect(Mouse_UI.mouse, audit_rect) and audit_max > 0 then
		local old = math.max(0, math.min(audit_max, tonumber(panel.craft.audit_scroll) or 0))
		local steps = math.max(1, math.floor(math.abs(notches) + 0.5))
		local next_scroll = old + (notches > 0 and -steps or steps)
		next_scroll = math.max(0, math.min(audit_max, next_scroll))
		panel.craft.audit_scroll = next_scroll
		panel.wheel_accum = 0
		if next_scroll ~= old then
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.22, 1.08, false, 0, 2)
		end
		return
	end
	panel.wheel_accum = (panel.wheel_accum or 0) + notches

	local pages = math.max(1, panel.craft.bag_pages or 1)
	local page = panel.craft.bag_page or 0
	local changed = false
	while panel.wheel_accum >= 1 do
		panel.wheel_accum = panel.wheel_accum - 1
		if page > 0 then
			page = page - 1
			changed = true
		end
	end
	while panel.wheel_accum <= -1 do
		panel.wheel_accum = panel.wheel_accum + 1
		if page < pages - 1 then
			page = page + 1
			changed = true
		end
	end
	-- 到边界仍继续滚时清空残余，避免粘滞后突然连翻
	if page <= 0 and panel.wheel_accum > 0 then panel.wheel_accum = 0 end
	if page >= pages - 1 and panel.wheel_accum < 0 then panel.wheel_accum = 0 end
	if not changed then
		return
	end

	panel.craft.bag_page = page
	BP.clear_bag_tokens_keep_busy(panel.craft, panel)
	panel.ui = nil -- 同帧强制 rebuild，避免「滚了但页未刷新」
	panel.nav_graph = nil
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.3, 1, false, 0, 2)
end

function BP.try_mouse_wheel_formation(panel, ui)
	if BP.get_tutorial().is_locking() then return end
	if not panel or panel.craft then return end
	local tab = item.tabs[panel.tab]
	if not tab or tab.id ~= "formation" then return end
	local serial = panel.wheel_render_serial or 0
	if panel.wheel_read_serial == serial then return end
	local wheel = panel.wheel_pending
	if not wheel then return end
	panel.wheel_pending = nil
	local dy = tonumber(wheel.y) or 0
	local dx = tonumber(wheel.x) or 0
	local delta = dy
	if delta == 0 then delta = dx end
	if delta == 0 then return end
	panel.wheel_read_serial = serial
	local pages = math.max(1, panel._form_bench_pages or 1)
	local page = panel.form_bench_page or 0
	if delta > 0 and page > 0 then
		panel.form_bench_page = page - 1
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.3, 1, false, 0, 2)
	elseif delta < 0 and page < pages - 1 then
		panel.form_bench_page = page + 1
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.3, 1, false, 0, 2)
	end
end

function BP.handle_mouse_actions(panel, ui)
	-- 滚轮由 render_panel 每帧集中读取；悬停/点击仍需鼠标权限。
	if not Mouse_UI.mouse_allowed(panel.player) then return end

	BP.enforce_all_items_gate(panel)

	-- 鼠标悬停同步焦点与导航组
	local hovered = Mouse_UI.get_hovered_id()
	if hovered and hovered ~= "modal_dim" and hovered ~= "panel_body" then
		panel.focus_id = hovered
		if panel.pad_carry then
			panel.nav_group = "carry"
		elseif type(hovered) == "string" and hovered:sub(1, 4) == "tab_" then
			panel.nav_group = "tabs"
		else
			panel.nav_group = "body"
			panel.body_focus_mem = hovered
		end
	end

	if panel.drag then
		if panel.drag.kind == "form_card" then
			if Mouse_UI.was_released(0) then
				BP.finish_form_drag(panel, ui)
				BP.lock_actions(panel)
			end
			return
		end
		if Mouse_UI.was_released(0) or Mouse_UI.is_released(panel.drag.token_id) then
			BP.finish_drag(panel, ui.craft_geom and ui.craft_geom.right, ui.craft_geom)
			BP.lock_actions(panel)
		end
		return
	end

	-- 编队卡：mousedown 进入 pending；移动超阈值才升级为 drag；松手未超阈 = 单击进仓库编辑
	if panel.form_press then
		local press = panel.form_press
		if Mouse_UI.was_released(0) then
			panel.form_press = nil
			local rec = press.rec
			if rec and rec.target and rec.uid then
				local inv = BP.find_tab_index("inventory")
				if inv then
					panel.tab = inv
					panel.focus_id = "tab_"..inv
					panel.nav_group = "tabs"
				end
				BP.open_craft_view(panel, rec.target, rec.uid)
				BP.lock_actions(panel)
			end
			return
		end
		if not Mouse_UI.is_down(0) then
			panel.form_press = nil
			return
		end
		local start = press.start_pos or Mouse_UI.mouse
		local delta = (Mouse_UI.mouse - start):Length()
		if delta >= (item.form_click_drag_px or 5) then
			panel.form_press = nil
			panel.drag = {
				kind = "form_card",
				uid = press.uid,
				from = press.from,
				grab_offset = press.grab_offset,
				pos = Mouse_UI.mouse - press.grab_offset,
				w = press.w,
				h = press.h,
				rec = press.rec,
				active = press.active,
			}
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.45, 1, false, 0, 2)
		end
		return
	end

	-- 共用主蓄力条：外包络线性映射后投影到 active domain 并集。
	if panel.craft and ui.charge_sliders then
		for _, info in ipairs(ui.charge_sliders) do
			if info.rect and (Mouse_UI.is_active(info.id) or Mouse_UI.is_pressed(info.id)) then
				local x = math.max(0, math.min(1, (Mouse_UI.mouse.X - info.rect.x) / math.max(1, info.rect.w)))
				local live = info.profile or BP.live_charge_profile(panel.craft)
				panel.craft[info.key] = CraftProfile.ratio_from_slider_x(x, live)
				panel.focus_id = info.id
				panel.nav_group = "body"
				panel.body_focus_mem = info.id
				return
			end
		end
	end

	if BP.input_locked(panel) then return end

	if Mouse_UI.is_pressed("tut_yes") then
		BP.get_tutorial().accept(panel.player)
		BP.lock_actions(panel)
		return
	end
	if Mouse_UI.is_pressed("tut_no") then
		BP.get_tutorial().decline(panel.player)
		BP.lock_actions(panel)
		return
	end

	if panel.craft then
		for _, tok in ipairs(panel.craft.tokens) do
			if Mouse_UI.is_pressed(tok.id) then
				panel.pad_carry = nil
				BP.clear_token_slot(panel.craft, tok)
				panel.drag = {
					token_id = tok.id,
					grab_offset = Mouse_UI.mouse - tok.pos,
				}
				tok.anim = nil
				tok.vel = Vector(0, 0)
				panel.focus_id = tok.id
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.45, 1, false, 0, 2)
				BP.lock_actions(panel)
				return
			end
		end
		if Mouse_UI.is_pressed("btn_back") then
			if panel.view == "edit" then BP.cancel_edit(panel) else BP.leave_craft_view(panel) end
			BP.lock_actions(panel)
			return
		end
		if Mouse_UI.is_pressed("btn_confirm") then
			BP.confirm_craft(panel)
			BP.lock_actions(panel)
			return
		end
		if Mouse_UI.is_pressed("btn_quality") then
			BP.toggle_show_quality(panel)
			BP.lock_actions(panel)
			return
		end
		if Mouse_UI.is_pressed("btn_mode") then
			BP.toggle_all_items_mode(panel)
			BP.lock_actions(panel)
			return
		end
		if Mouse_UI.is_pressed("btn_tag_all") then
			BP.enable_all_audit_tags(panel)
			BP.lock_actions(panel)
			return
		end
		if Mouse_UI.is_pressed("btn_tag_invert") then
			BP.invert_audit_tags(panel)
			BP.lock_actions(panel)
			return
		end
		if panel.ui and panel.ui.craft_geom and panel.ui.craft_geom.tag_col then
			for _, def in ipairs(panel.ui.craft_geom.tag_col.defs or {}) do
				if Mouse_UI.is_pressed("btn_tag_"..def.key) then
					BP.toggle_audit_tag(panel, def.key)
					BP.lock_actions(panel)
					return
				end
			end
		end
		if Mouse_UI.is_pressed("btn_prev") then
			panel.craft.bag_page = math.max(0, (panel.craft.bag_page or 0) - 1)
			BP.clear_bag_tokens_keep_busy(panel.craft, panel)
			panel.nav_graph = nil
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.35, 1, false, 0, 2)
			BP.lock_actions(panel)
			return
		end
		if Mouse_UI.is_pressed("btn_next") then
			local pages = panel.craft.bag_pages or 1
			panel.craft.bag_page = math.min(pages - 1, (panel.craft.bag_page or 0) + 1)
			BP.clear_bag_tokens_keep_busy(panel.craft, panel)
			panel.nav_graph = nil
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.35, 1, false, 0, 2)
			BP.lock_actions(panel)
			return
		end
	end

	if Mouse_UI.was_clicked(1) or Mouse_UI.is_pressed("modal_dim") then
		local tut = BP.get_tutorial()
		local advanced = tut.note_close_attempt and tut.note_close_attempt(panel.player) == true
		if tut.blocks_close(panel.player) then
			if advanced then
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.45, 1, false, 0, 2)
			else
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.45, 1.2, false, 0, 2)
			end
			BP.lock_actions(panel)
			return
		end
		if panel.pad_carry then
			BP.cancel_pad_carry(panel)
			BP.lock_actions(panel)
			return
		end
		if panel.craft then
			if panel.view == "edit" then BP.cancel_edit(panel) else BP.leave_craft_view(panel) end
		else
			BP.close_panel()
		end
		BP.lock_actions(panel)
		return
	end

	for i = 1, #item.tabs do
		if Mouse_UI.is_pressed("tab_"..i) then
			BP.set_tab(panel, i)
			BP.lock_actions(panel)
			return
		end
	end

	for _, lay in ipairs(ui.layouts) do
		local e = lay.entry
		if e and e.kind == "form_page" and Mouse_UI.is_pressed(e.uid) then
			BP.handle_formation_id(panel, e.uid)
			BP.lock_actions(panel)
			return
		end
		if e and e.kind == "form_dock" and Mouse_UI.is_pressed(e.uid) then
			if panel.form_carry then
				BP.handle_formation_id(panel, "form_queue")
				BP.lock_actions(panel)
			end
			return
		end
		if e and e.kind == "form_card" and Mouse_UI.is_pressed(e.uid) and e.rec then
			panel.form_carry = nil
			panel.form_press = {
				uid = e.rec.uid,
				entry_uid = e.uid,
				start_pos = Vector(Mouse_UI.mouse.X, Mouse_UI.mouse.Y),
				start_frame = Game():GetFrameCount(),
				from = e.zone,
				grab_offset = Mouse_UI.mouse - Vector(lay.rect.x, lay.rect.y),
				pos = Vector(lay.rect.x, lay.rect.y),
				w = lay.rect.w,
				h = lay.rect.h,
				rec = e.rec,
				active = e.active,
			}
			BP.lock_actions(panel)
			return
		end
		if e and e.del_uid and Mouse_UI.is_pressed(e.del_uid) then
			BP.try_confirm_delete_stock(panel, e.rec.uid)
			BP.lock_actions(panel)
			return
		end
		if e and Mouse_UI.is_pressed(e.uid) then
			panel.delete_confirm_uid = nil
			if e.kind == "build_target" then
				BP.open_craft_view(panel, e.target, nil)
			elseif e.kind == "stock" then
				BP.open_craft_view(panel, e.rec.target, e.rec.uid)
			end
			BP.lock_actions(panel)
			return
		end
	end
end

function BP.update_panel_input(player)
	BP.scrub_stale_panel()
	local panel = item.panel
	if not BP.same_panel_player(player) then return end
	if Game():GetFrameCount() <= panel.opened_frame then return end
	local ctrlid = player.ControllerIndex

	-- 暂停被关掉后：按着的 ESC/确认/方向等一律不计入，松手前保持 was_paused 防连触
	if panel.was_paused then
		BP.disarm_until_release(panel)
		if BP.pause_menu_open() or BP.panel_keys_held(ctrlid, player) then return end
		panel.was_paused = false
		panel.input_armed = true
		panel.wait_drop_release = false
		return
	end
	if BP.pause_menu_open() or Game():IsPaused() then return end

	if not panel.input_armed then
		if not BP.panel_keys_held(ctrlid, player) then panel.input_armed = true end
		return
	end

	if panel.wait_drop_release then
		if not BP.exit_key_held(ctrlid, player) then
			panel.wait_drop_release = false
		end
	elseif BP.exit_key_triggered(ctrlid, player) then
		BP.try_panel_exit(panel)
	end
end

--- Render 回调时序内的输入（滚轮必须在 POST_RENDER 读）。不改 callback 注册。
function BP.handle_render_phase_input(panel, ui, can_read_wheel)
	-- 滚轮只改背包页 / 编队备选条；不需要等待升起动画或键盘 input_armed。
	if can_read_wheel then
		if panel.craft and ui.craft_geom then
			BP.try_mouse_wheel_page(panel, ui)
		else
			BP.try_mouse_wheel_formation(panel, ui)
		end
		if not item.panel then return nil end
		ui = panel.ui or BP.build_and_register_ui(panel)
	end
	local can_interact = panel.input_armed
		and item.panel_rise_finished()
		and Game():GetFrameCount() > panel.opened_frame
		and not Game():IsPaused()
		and not panel.was_paused
	if can_interact then
		BP.handle_mouse_actions(panel, ui)
		if not item.panel then return nil end
		ui = panel.ui or BP.build_and_register_ui(panel)
		BP.handle_pad_actions(panel, ui)
		if not item.panel then return nil end
		ui = panel.ui or ui
	end
	return ui
end

end

return M
