-- Visual → Quest UI debug: independent Hint / Panel / Toast offsets + persistent previews.

local imgui_layout = require("Qing_Remaster_scripts.debug.imgui_debug_layout")
local pause_ui = require("Qing_Remaster_scripts.auxiliary.pause_ui")

local mod = {}

local function tr(zh, en)
	return (Options and Options.Language == "en") and en or zh
end

local function hud_mod()
	local ok, hud = pcall(require, "Qing_Remaster_scripts.quest.quest_hud")
	if ok then return hud end
	return nil
end

local function panel_mod()
	local ok, panel = pcall(require, "Qing_Remaster_scripts.quest.quest_panel")
	if ok then return panel end
	return nil
end

local function draw_mod()
	local ok, draw = pcall(require, "Qing_Remaster_scripts.quest.quest_draw")
	if ok then return draw end
	return nil
end

local function add_slider(parent, id, label, getter, setter, min_v, max_v)
	local add = ImGui.AddSliderInteger or ImGui.AddSliderInt
	if not add then return end
	add(parent, id, label, function(v)
		setter(math.floor((v or 0) + 0.5))
	end, getter(), min_v, max_v)
	ImGui.AddCallback(id, ImGuiCallback.Render, function()
		ImGui.UpdateData(id, ImGuiData.Value, getter())
	end)
end

function mod.build(api)
	if not ImGui or not api or not api.start_mod then return end
	local DEBUG_PAGE = api.DEBUG_PAGE
	local text = api.text
	local start_mod = api.start_mod

	local group = start_mod(
		"visual_quest_ui",
		DEBUG_PAGE.visual,
		tr("任务界面", "Quest UI"),
		"QingRemasterOptions_GroupQuestUI",
		{path = {"Quest UI"}, kind = "tool"}
	)
	if not group then return end

	local prefix = group .. "_QUI"
	imgui_layout.add_wrapped_text(
		group, prefix .. "_Note",
		tr(
			"分别调节任务页签 / 暂停任务面板 / 游戏内 Toast。调满意后把 Final 写回 LAYOUTS，再归零临时偏移。",
			"Tune page toggle / Pause panel / gameplay Toast separately. Bake Final locals into LAYOUTS, then zero temp offsets."
		)
	)

	local state = {
		toggle_open_x = 0, toggle_open_y = 0,
		toggle_close_x = 0, toggle_close_y = 0,
		panel_x = 0, panel_y = 0,
		paper_fine_x = 0, paper_fine_y = 0,
		content_fine_x = 0, content_fine_y = 0,
		middle_n = 1,
		inset_l = 36, inset_r = 36, inset_t = 28, inset_b = 24,
		toast_x = 0, toast_y = 0,
		surface_x = 0, surface_y = 0,
		key_y = 0, ornament_y = 0, glyph_y = -3, label_y = 0, row_gap = 10,
		title_centered = true,
		title_spacing = 1,
		title_y = 0,
		ornament_y_toast = 0,
		ornament_half = 24,
		body_y = 0,
		body_row = 10,
		fade_in = 5,
		fade_out = 12,
		enter_y = 4,
		shift_test = 40,
		shift_approach = 25,
	}

	local function sync()
		local off = pause_ui.get_debug_offsets()
		state.toggle_open_x = math.floor((off.toggle_open and off.toggle_open.X or off.hint and off.hint.X or 0) + 0.5)
		state.toggle_open_y = math.floor((off.toggle_open and off.toggle_open.Y or off.hint and off.hint.Y or 0) + 0.5)
		state.toggle_close_x = math.floor((off.toggle_close and off.toggle_close.X or 0) + 0.5)
		state.toggle_close_y = math.floor((off.toggle_close and off.toggle_close.Y or 0) + 0.5)
		state.panel_x = math.floor((off.panel and off.panel.X or 0) + 0.5)
		state.panel_y = math.floor((off.panel and off.panel.Y or 0) + 0.5)
		state.paper_fine_x = math.floor((off.paper_fine and off.paper_fine.X or 0) + 0.5)
		state.paper_fine_y = math.floor((off.paper_fine and off.paper_fine.Y or 0) + 0.5)
		state.content_fine_x = math.floor((off.content_fine and off.content_fine.X or 0) + 0.5)
		state.content_fine_y = math.floor((off.content_fine and off.content_fine.Y or 0) + 0.5)
		state.surface_x = math.floor((off.surface and off.surface.X or 0) + 0.5)
		state.surface_y = math.floor((off.surface and off.surface.Y or 0) + 0.5)
		local eff = pause_ui.get_paper_effective and pause_ui.get_paper_effective()
		if eff then
			state.middle_n = eff.middle_count or 1
			state.inset_l = eff.content_inset_left or 36
			state.inset_r = eff.content_inset_right or 36
			state.inset_t = eff.content_inset_top or 28
			state.inset_b = eff.content_inset_bottom or 24
		end
		local hud = hud_mod()
		if hud and hud.get_toast_layout then
			local tl0 = hud.get_toast_layout()
			local d = tl0.debug_offset
			state.toast_x = math.floor((d and d.X or 0) + 0.5)
			state.toast_y = math.floor((d and d.Y or 0) + 0.5)
		state.fade_in = tl0.fade_in or 5
		state.fade_out = tl0.fade_out or 12
			state.enter_y = tl0.enter_y or 4
		end
		if hud and hud.get_debug_title_layout then
			local tl = hud.get_debug_title_layout()
			state.title_centered = tl.centered == true
			state.title_spacing = tl.letter_spacing or 1
			state.title_y = tl.y_offset or 0
			state.ornament_y_toast = tl.ornament_y_offset or 0
			state.ornament_half = tl.ornament_half_width or 24
			state.body_y = tl.body_y_offset or 0
			state.body_row = tl.body_row_h or 10
		end
		local panel = panel_mod()
		_ = panel
		if pause_ui.get_content_shift_approach then
			state.shift_approach = math.floor((pause_ui.get_content_shift_approach() or 0.25) * 100 + 0.5)
		end
		local ot = pause_ui.get_debug_shift_test and pause_ui.get_debug_shift_test()
		if ot ~= nil then state.shift_test = ot end
	end
	sync()

	-- Pause completion-anchor status (shared by all characters)
	local anchor_sec = imgui_layout.add_section(group, prefix .. "_Anchor", tr("暂停锚点", "Pause Anchor"))
	imgui_layout.add_wrapped_text(
		anchor_sec, prefix .. "_AnchorNote",
		tr(
			"Completion Marks PRE 只提供锚点；Quest UI 在 POST_PAUSE_SCREEN_RENDER 绘制。",
			"Completion Marks PRE only supplies the anchor; Quest UI draws in POST_PAUSE_SCREEN_RENDER."
		)
	)
	imgui_layout.add_wrapped_text(anchor_sec, prefix .. "_AnchorSnap", "")
	ImGui.AddCallback(prefix .. "_AnchorSnap", ImGuiCallback.Render, function()
		local info = pause_ui.get_completion_anchor_info and pause_ui.get_completion_anchor_info()
		local shift_x = pause_ui.get_native_pause_shift_x and pause_ui.get_native_pause_shift_x() or 0
		local lines
		if not info then
			lines = {
				tr("无锚点（未开 Pause / PRE 未触发）", "No anchor (Pause closed / PRE not fired)"),
				string.format("Pause Shift: %s px", tostring(shift_x)),
			}
		else
			local pos = info.position
			local sc = info.scale
			local eff_x = (pos and pos.X or 0) + (shift_x or 0)
			local eff_y = pos and pos.Y or 0
			lines = {
				string.format("source: %s", tostring(info.source or "?")),
				string.format("player_type: %s", tostring(info.player_type)),
				string.format("frame age: %s%s", tostring(info.age), info.fresh and "" or " (STALE)"),
				string.format(
					"renderPos: (%.1f, %.1f)",
					pos and pos.X or 0, pos and pos.Y or 0
				),
				string.format(
					"renderScale: (%.2f, %.2f)",
					sc and sc.X or 1, sc and sc.Y or 1
				),
				string.format("Pause Shift: %s px", tostring(shift_x)),
				string.format(
					"Custom Marks effective: (%.1f, %.1f) = renderPos + shift",
					eff_x, eff_y
				),
			}
		end
		imgui_layout.update_text(prefix .. "_AnchorSnap", table.concat(lines, "\n"))
	end)

	local function apply_panel()
		pause_ui.set_debug_panel_offset(state.panel_x, state.panel_y)
	end
	local function apply_size()
		pause_ui.set_paper_tune({
			middle_count = state.middle_n,
			content_inset_left = state.inset_l,
			content_inset_right = state.inset_r,
			content_inset_top = state.inset_t,
			content_inset_bottom = state.inset_b,
		})
	end
	local function apply_toast()
		local hud = hud_mod()
		if hud and hud.set_debug_toast_offset then
			hud.set_debug_toast_offset(state.toast_x, state.toast_y)
		end
	end
	local function apply_title()
		local hud = hud_mod()
		if hud and hud.set_debug_title_layout then
			hud.set_debug_title_layout({
				centered = state.title_centered,
				letter_spacing = state.title_spacing,
				y_offset = state.title_y,
				ornament_y_offset = state.ornament_y_toast,
				ornament_half_width = state.ornament_half,
				body_y_offset = state.body_y,
				body_row_h = state.body_row,
			})
		end
	end

	-- A. Page toggle tabs (replaces text hint / footer)
	local draw = draw_mod() or {}
	local toggle = imgui_layout.add_section(group, prefix .. "_Toggle", tr("任务页签", "Page Toggle"))
	imgui_layout.add_wrapped_text(
		toggle, prefix .. "_ToggleNote",
		tr(
			"开启/关闭页签锚点为贴图中心（EN 64 / ZH 128 共用偏移）。预览语言只影响页签贴图，不改模组语言。",
			"Open/Close anchors are sprite centers (EN 64 / ZH 128 share offsets). Preview language affects tab art only, not mod language."
		)
	)

	local lang_labels = {
		tr("跟随语言", "Follow language"),
		tr("中文", "Chinese"),
		"English",
	}
	local lang_modes = {"auto", "zh", "en"}
	ImGui.AddCombobox(toggle, prefix .. "_LangPreview", tr("预览语言", "Preview language"), function(index)
		local mode = lang_modes[(index or 0) + 1] or "auto"
		if draw.set_toggle_language_override then
			draw.set_toggle_language_override(mode)
		end
	end, lang_labels, 0)
	ImGui.AddCallback(prefix .. "_LangPreview", ImGuiCallback.Render, function()
		local cur = draw.get_toggle_language_override and draw.get_toggle_language_override() or "auto"
		local idx = 0
		for i, m in ipairs(lang_modes) do
			if m == cur then idx = i - 1 break end
		end
		ImGui.UpdateData(prefix .. "_LangPreview", ImGuiData.Value, idx)
	end)

	ImGui.AddCheckbox(toggle, prefix .. "_ForceOpenTab", tr("强制预览开启页签", "Force preview open tab"), function(checked)
		local panel = panel_mod()
		if panel and panel.set_debug_preview then
			panel.set_debug_preview({force_toggle_open = checked == true})
		end
	end, false)
	ImGui.AddCheckbox(toggle, prefix .. "_ForceCloseTab", tr("强制预览关闭页签", "Force preview close tab"), function(checked)
		local panel = panel_mod()
		if panel and panel.set_debug_preview then
			panel.set_debug_preview({force_toggle_close = checked == true})
		end
	end, false)

	ImGui.AddElement(toggle, "", ImGuiElement.SeparatorText or ImGuiElement.Separator, tr("开启页签 X/Y（面板关闭时）", "Open tab X/Y (when closed)"))
	add_slider(toggle, prefix .. "_OpenX", "X", function() return state.toggle_open_x end, function(v)
		state.toggle_open_x = v
		pause_ui.set_debug_toggle_open_offset(state.toggle_open_x, state.toggle_open_y)
	end, -160, 160)
	add_slider(toggle, prefix .. "_OpenY", "Y", function() return state.toggle_open_y end, function(v)
		state.toggle_open_y = v
		pause_ui.set_debug_toggle_open_offset(state.toggle_open_x, state.toggle_open_y)
	end, -120, 120)

	ImGui.AddElement(toggle, "", ImGuiElement.SeparatorText or ImGuiElement.Separator, tr("关闭页签 X/Y（面板打开时）", "Close tab X/Y (when open)"))
	add_slider(toggle, prefix .. "_CloseX", "X", function() return state.toggle_close_x end, function(v)
		state.toggle_close_x = v
		pause_ui.set_debug_toggle_close_offset(state.toggle_close_x, state.toggle_close_y)
	end, -120, 120)
	add_slider(toggle, prefix .. "_CloseY", "Y", function() return state.toggle_close_y end, function(v)
		state.toggle_close_y = v
		pause_ui.set_debug_toggle_close_offset(state.toggle_close_x, state.toggle_close_y)
	end, -80, 200)

	imgui_layout.add_wrapped_text(toggle, prefix .. "_ToggleSnap", "")
	ImGui.AddCallback(prefix .. "_ToggleSnap", ImGuiCallback.Render, function()
		local layout = pause_ui.get_last_layout and pause_ui.get_last_layout()
		local info = draw.get_toggle_last_info and draw.get_toggle_last_info() or nil
		local eff = draw.effective_toggle_language and draw.effective_toggle_language() or "?"
		local override = draw.get_toggle_language_override and draw.get_toggle_language_override() or "auto"
		local lang_label = (eff == "en") and "English" or tr("中文", "Chinese")
		local lines = {
			string.format(tr("当前语言：%s", "Language: %s") .. " (override=%s)", lang_label, tostring(override)),
		}
		if info then
			lines[#lines + 1] = string.format(tr("动画：%s", "Anim: %s"), tostring(info.anim))
			lines[#lines + 1] = string.format(tr("尺寸：%d × %d", "Size: %d × %d"), info.width or 0, info.height or 0)
		elseif draw.get_toggle_animation then
			local anim, w, h = draw.get_toggle_animation("open")
			lines[#lines + 1] = string.format(tr("动画：%s", "Anim: %s"), tostring(anim))
			lines[#lines + 1] = string.format(tr("尺寸：%d × %d", "Size: %d × %d"), w or 0, h or 0)
		end
		lines[#lines + 1] = string.format("Open debug = (%d, %d)", state.toggle_open_x, state.toggle_open_y)
		lines[#lines + 1] = string.format("Close debug = (%d, %d)", state.toggle_close_x, state.toggle_close_y)
		if layout then
			local op = layout.toggle_open_pos
			local cp = layout.toggle_close_pos
			if op then
				lines[#lines + 1] = string.format("Open anchor = (%.0f, %.0f)", op.X, op.Y)
			end
			if cp then
				lines[#lines + 1] = string.format("Close anchor = (%.0f, %.0f)", cp.X, cp.Y)
			end
			local cf = layout.toggle_close_offset_final
			if cf then
				lines[#lines + 1] = string.format("Close offset vs paper = (%s, %s)", tostring(cf.X), tostring(cf.Y))
			end
		end
		imgui_layout.update_text(prefix .. "_ToggleSnap", table.concat(lines, "\n"))
	end)
	ImGui.AddButton(toggle, prefix .. "_ToggleZero", tr("重置页签偏移", "Reset toggle offsets"), function()
		pause_ui.reset_toggle_offsets()
		sync()
	end)

	-- B. Pause panel (whole-panel transform + size; fine offsets in Advanced)
	local pan = imgui_layout.add_section(group, prefix .. "_Panel", tr("暂停页任务面板", "Pause quest panel"))
	ImGui.AddCheckbox(pan, prefix .. "_ForcePanel", tr("强制展开预览", "Force open preview"), function(checked)
		local panel = panel_mod()
		if panel and panel.set_debug_preview then
			panel.set_debug_preview({force_panel = checked == true})
		end
		if checked then
			pause_ui.set_quest_open_amount(1)
		else
			pause_ui.set_quest_open_amount(0)
		end
	end, false)
	ImGui.AddCheckbox(pan, prefix .. "_Sample", tr("使用示例内容", "Use sample content"), function(checked)
		local panel = panel_mod()
		if panel and panel.set_debug_preview then
			panel.set_debug_preview({use_sample = checked == true})
		end
	end, false)
	ImGui.AddCheckbox(pan, prefix .. "_PaperBounds", tr("显示边界", "Show bounds"), function(checked)
		pause_ui.set_debug_paper_bounds(checked == true)
	end, false)

	ImGui.AddElement(pan, "", ImGuiElement.SeparatorText or ImGuiElement.Separator, tr("整体位置", "Position"))
	add_slider(pan, prefix .. "_PX", tr("面板 X", "Panel X"), function() return state.panel_x end, function(v)
		state.panel_x = v
		apply_panel()
	end, -160, 160)
	add_slider(pan, prefix .. "_PY", tr("面板 Y", "Panel Y"), function() return state.panel_y end, function(v)
		state.panel_y = v
		apply_panel()
	end, -120, 120)

	ImGui.AddElement(pan, "", ImGuiElement.SeparatorText or ImGuiElement.Separator, tr("纸页高度", "Paper height"))
	add_slider(pan, prefix .. "_MidN", tr("中段数量 N", "Middle count N"), function() return state.middle_n end, function(v)
		state.middle_n = v
		apply_size()
	end, 0, 4)
	imgui_layout.add_wrapped_text(
		pan, prefix .. "_SizeNote",
		tr(
			"宽度固定 256（1:1）。高度 = 256 + 32×N → 256/288/320/352/…",
			"Width fixed 256 (1:1). Height = 256 + 32×N → 256/288/320/352/…"
		)
	)

	imgui_layout.add_wrapped_text(pan, prefix .. "_PanelSnap", "")
	ImGui.AddCallback(prefix .. "_PanelSnap", ImGuiCallback.Render, function()
		local snap = pause_ui.get_audit_snapshot()
		local eff = pause_ui.get_paper_effective and pause_ui.get_paper_effective() or {}
		local po = snap.panel_offset_final
		local pf = snap.paper_local_final
		local qf = snap.quest_local_final
		local pr = pause_ui.get_last_paper_rect and pause_ui.get_last_paper_rect()
		local h = eff.height or (256 + 32 * (eff.middle_count or 0))
		local lines = {
			string.format(
				"Panel Offset = (%s, %s)",
				tostring(po and po.x or state.panel_x),
				tostring(po and po.y or state.panel_y)
			),
			string.format(
				"Paper = 256 × %d  (N=%d)   ContentW = %d",
				h, eff.middle_count or 0, eff.content_width or 0
			),
			string.format(
				"Insets L/R/T/B = %d / %d / %d / %d",
				eff.content_inset_left or 0, eff.content_inset_right or 0,
				eff.content_inset_top or 0, eff.content_inset_bottom or 0
			),
		}
		if pr then
			lines[#lines + 1] = string.format(
				"Paper Rect TL: (%d,%d)  H=%d%s",
				pr.full_left or pr.left, pr.full_top or pr.top,
				pr.height or 0,
				pr.overflow and " OVERFLOW" or ""
			)
		end
		if pf and qf then
			lines[#lines + 1] = string.format(
				"Paper local TL=(%s,%s)  Content center=(%s,%s)",
				tostring(pf.x), tostring(pf.y), tostring(qf.x), tostring(qf.y)
			)
		end
		local ok, qd = pcall(require, "Qing_Remaster_scripts.quest.quest_draw")
		if ok and qd and qd.get_paper_style then
			lines[#lines + 1] = "style=" .. tostring(qd.get_paper_style())
		end
		imgui_layout.update_text(prefix .. "_PanelSnap", table.concat(lines, "\n"))
	end)

	ImGui.AddButton(pan, prefix .. "_LayoutReset", tr("恢复当前布局默认值", "Reset layout defaults"), function()
		pause_ui.reset_panel_layout_defaults()
		sync()
	end)
	ImGui.AddElement(pan, "", ImGuiElement.SameLine)
	ImGui.AddButton(pan, prefix .. "_Anchors", tr("显示布局辅助线", "Show layout guides"), function()
		pause_ui.set_debug_anchors(not pause_ui.get_debug_anchors())
	end)

	local fine = imgui_layout.add_section(pan, prefix .. "_Fine", tr("高级：内部布局", "Advanced: internal layout"))
	add_slider(fine, prefix .. "_InsetL", tr("正文 Left inset", "Content Left inset"), function() return state.inset_l end, function(v)
		state.inset_l = v
		apply_size()
	end, 8, 80)
	add_slider(fine, prefix .. "_InsetR", tr("正文 Right inset", "Content Right inset"), function() return state.inset_r end, function(v)
		state.inset_r = v
		apply_size()
	end, 8, 80)
	add_slider(fine, prefix .. "_InsetT", tr("正文 Top inset", "Content Top inset"), function() return state.inset_t end, function(v)
		state.inset_t = v
		apply_size()
	end, 8, 80)
	add_slider(fine, prefix .. "_InsetB", tr("正文 Bottom inset", "Content Bottom inset"), function() return state.inset_b end, function(v)
		state.inset_b = v
		apply_size()
	end, 8, 80)
	add_slider(fine, prefix .. "_PaperFineX", tr("背景微调 X", "Paper fine X"), function() return state.paper_fine_x end, function(v)
		state.paper_fine_x = v
		pause_ui.set_debug_paper_fine_offset(state.paper_fine_x, state.paper_fine_y)
	end, -80, 80)
	add_slider(fine, prefix .. "_PaperFineY", tr("背景微调 Y", "Paper fine Y"), function() return state.paper_fine_y end, function(v)
		state.paper_fine_y = v
		pause_ui.set_debug_paper_fine_offset(state.paper_fine_x, state.paper_fine_y)
	end, -80, 80)
	add_slider(fine, prefix .. "_ContentFineX", tr("正文微调 X", "Content fine X"), function() return state.content_fine_x end, function(v)
		state.content_fine_x = v
		pause_ui.set_debug_content_fine_offset(state.content_fine_x, state.content_fine_y)
	end, -80, 80)
	add_slider(fine, prefix .. "_ContentFineY", tr("正文微调 Y", "Content fine Y"), function() return state.content_fine_y end, function(v)
		state.content_fine_y = v
		pause_ui.set_debug_content_fine_offset(state.content_fine_x, state.content_fine_y)
	end, -80, 80)
	ImGui.AddButton(fine, prefix .. "_PaperParts", tr("样式: parts", "Style: parts"), function()
		local ok, qd = pcall(require, "Qing_Remaster_scripts.quest.quest_draw")
		if ok and qd and qd.set_paper_style then qd.set_paper_style("parts") end
	end)
	ImGui.AddElement(fine, "", ImGuiElement.SameLine)
	ImGui.AddButton(fine, prefix .. "_PaperDebug", tr("样式: debug", "Style: debug"), function()
		local ok, qd = pcall(require, "Qing_Remaster_scripts.quest.quest_draw")
		if ok and qd and qd.set_paper_style then qd.set_paper_style("debug") end
	end)
	ImGui.AddElement(fine, "", ImGuiElement.SameLine)
	ImGui.AddButton(fine, prefix .. "_PaperLegacy", tr("样式: legacy", "Style: legacy"), function()
		local ok, qd = pcall(require, "Qing_Remaster_scripts.quest.quest_draw")
		if ok and qd and qd.set_paper_style then qd.set_paper_style("legacy") end
	end)

	ImGui.AddElement(pan, "", ImGuiElement.SeparatorText or ImGuiElement.Separator, tr("Pause 展开", "Pause expand"))
	ImGui.AddCheckbox(pan, prefix .. "_ShiftEn", tr("展开时移动原暂停页", "Shift Pause on open"), function(checked)
		pause_ui.set_content_shift_enabled(checked == true)
	end, pause_ui.is_content_shift_enabled and pause_ui.is_content_shift_enabled())
	add_slider(pan, prefix .. "_ShiftAp", tr("展开动画速度%", "Expand speed %"), function()
		return state.shift_approach
	end, function(v)
		state.shift_approach = v
		pause_ui.set_content_shift_approach((v or 25) / 100)
	end, 5, 100)

	local shift_probe = imgui_layout.add_section(
		pan, prefix .. "_ShiftProbe",
		tr("Pause Sprite Probe", "Pause Sprite Probe")
	)
	imgui_layout.add_wrapped_text(
		shift_probe, prefix .. "_ShiftNote",
		tr(
			"测试 Body/Stats/Marks/MyStuff 是否一起 Offset。完整采样见 Probes → Pause Sprite Shift。",
			"Test whether Body/Stats/Marks/MyStuff move together. Full sampling: Probes → Pause Sprite Shift."
		)
	)
	add_slider(shift_probe, prefix .. "_ShiftPx", tr("测试 Shift X", "Test Shift X"), function()
		return state.shift_test
	end, function(v)
		state.shift_test = v
	end, 0, 80)
	ImGui.AddButton(shift_probe, prefix .. "_ShiftApply", tr("测试偏移", "Apply test shift"), function()
		pause_ui.set_debug_shift_test(state.shift_test)
	end)
	ImGui.AddElement(shift_probe, "", ImGuiElement.SameLine)
	ImGui.AddButton(shift_probe, prefix .. "_ShiftClear", tr("恢复", "Restore"), function()
		pause_ui.set_debug_shift_test(nil)
		sync()
	end)
	imgui_layout.add_wrapped_text(shift_probe, prefix .. "_ShiftSnap", "")
	ImGui.AddCallback(prefix .. "_ShiftSnap", ImGuiCallback.Render, function()
		local s = pause_ui.get_content_shift_snapshot and pause_ui.get_content_shift_snapshot() or {}
		local bases = s.bases or {}
		local lines = {
			string.format("open=%.2f → %d px (max %s)", s.open_amount or s.current_t or 0, s.applied_x or 0, tostring(s.max_px)),
			string.format("override=%s enabled=%s", tostring(s.override_px), tostring(s.feature_enabled)),
		}
		for _, key in ipairs({"body", "stats", "marks", "mystuff"}) do
			local b = bases[key]
			if b then
				lines[#lines + 1] = string.format("%s base=(%d,%d)", key, b.x or 0, b.y or 0)
			else
				lines[#lines + 1] = key .. " = (missing)"
			end
		end
		imgui_layout.update_text(prefix .. "_ShiftSnap", table.concat(lines, "\n"))
	end)

	-- C. Toast
	local toast = imgui_layout.add_section(group, prefix .. "_Toast", tr("游戏内任务 Toast", "Gameplay toast"))
	ImGui.AddCheckbox(toast, prefix .. "_Persist", tr("持续显示", "Keep showing"), function(checked)
		local hud = hud_mod()
		if not hud then return end
		if checked then
			local d = hud.get_debug_preview and hud.get_debug_preview()
			hud.set_debug_preview(true, (d and d.kind) or "new")
		else
			hud.set_debug_preview(false)
		end
	end, false)
	ImGui.AddButton(toast, prefix .. "_TNew", tr("新任务", "New"), function()
		local hud = hud_mod()
		if hud then hud.set_debug_preview(true, "new") end
	end)
	ImGui.AddElement(toast, "", ImGuiElement.SameLine)
	ImGui.AddButton(toast, prefix .. "_TUpd", tr("更新", "Update"), function()
		local hud = hud_mod()
		if hud then hud.set_debug_preview(true, "update") end
	end)
	ImGui.AddElement(toast, "", ImGuiElement.SameLine)
	ImGui.AddButton(toast, prefix .. "_TProg", tr("进度", "Progress"), function()
		local hud = hud_mod()
		if hud then hud.set_debug_preview(true, "progress") end
	end)
	ImGui.AddElement(toast, "", ImGuiElement.SameLine)
	ImGui.AddButton(toast, prefix .. "_TSide", tr("支线", "Side"), function()
		local hud = hud_mod()
		if hud then hud.set_debug_preview(true, "side") end
	end)
	ImGui.AddElement(toast, "", ImGuiElement.SameLine)
	ImGui.AddButton(toast, prefix .. "_TDone", tr("完成", "Complete"), function()
		local hud = hud_mod()
		if hud then hud.set_debug_preview(true, "complete") end
	end)
	ImGui.AddElement(toast, "", ImGuiElement.SameLine)
	ImGui.AddButton(toast, prefix .. "_TOpt", tr("可选", "Optional"), function()
		local hud = hud_mod()
		if hud then hud.set_debug_preview(true, "optional") end
	end)
	ImGui.AddButton(toast, prefix .. "_TSeq", tr("预览：任务完成 → 下一任务", "Preview: complete → next"), function()
		local hud = hud_mod()
		if hud then
			if hud.set_debug_preview then hud.set_debug_preview(false) end
			if hud.debug_push_complete_then_new then
				hud.debug_push_complete_then_new()
			end
		end
	end)
	ImGui.AddElement(toast, "", ImGuiElement.SameLine)
	ImGui.AddButton(toast, prefix .. "_TTimedNew", tr("推送：新任务", "Push: New"), function()
		local hud = hud_mod()
		if hud and hud.debug_push_sample then hud.debug_push_sample("new") end
	end)
	ImGui.AddElement(toast, "", ImGuiElement.SameLine)
	ImGui.AddButton(toast, prefix .. "_TTimedDone", tr("推送：完成", "Push: Complete"), function()
		local hud = hud_mod()
		if hud and hud.debug_push_sample then hud.debug_push_sample("complete") end
	end)

	ImGui.AddElement(toast, "", ImGuiElement.SeparatorText or ImGuiElement.Separator, tr("位置", "Position"))
	add_slider(toast, prefix .. "_TX", "X", function() return state.toast_x end, function(v) state.toast_x = v apply_toast() end, -80, 80)
	add_slider(toast, prefix .. "_TY", "Y", function() return state.toast_y end, function(v) state.toast_y = v apply_toast() end, -60, 60)
	imgui_layout.add_wrapped_text(toast, prefix .. "_ToastFinal", "")
	ImGui.AddCallback(prefix .. "_ToastFinal", ImGuiCallback.Render, function()
		local hud = hud_mod()
		local text = "-"
		if hud and hud.get_toast_layout then
			local tl = hud.get_toast_layout()
			local b = tl.base
			local d = tl.debug_offset
			local fx = (b and b.X or 0) + (d and d.X or 0)
			local fy = (b and b.Y or 0) + (d and d.Y or 0)
			text = string.format(
				tr("Base = (%d, %d)\nFinal = (%d, %d)", "Base = (%d, %d)\nFinal = (%d, %d)"),
				math.floor((b and b.X or 0) + 0.5), math.floor((b and b.Y or 0) + 0.5),
				math.floor(fx + 0.5), math.floor(fy + 0.5)
			)
		end
		imgui_layout.update_text(prefix .. "_ToastFinal", text)
	end)

	ImGui.AddElement(toast, "", ImGuiElement.SeparatorText or ImGuiElement.Separator, tr("标题", "Title"))
	ImGui.AddCheckbox(toast, prefix .. "_TCenter", tr("标题居中", "Title centered"), function(checked)
		state.title_centered = checked == true
		apply_title()
	end, true)
	add_slider(toast, prefix .. "_TTitleY", tr("标题 Y 偏移", "Title Y"), function() return state.title_y end, function(v)
		state.title_y = v
		apply_title()
	end, -8, 8)
	add_slider(toast, prefix .. "_TSpace", tr("标题字间距", "Title letter spacing"), function() return state.title_spacing end, function(v)
		state.title_spacing = v
		apply_title()
	end, 0, 4)

	local toast_adv = imgui_layout.add_section(toast, prefix .. "_ToastAdv", tr("高级", "Advanced"))
	add_slider(toast_adv, prefix .. "_OrnY", tr("装饰 Y", "Ornament Y"), function() return state.ornament_y_toast end, function(v)
		state.ornament_y_toast = v
		apply_title()
	end, -8, 8)
	add_slider(toast_adv, prefix .. "_OrnW", tr("装饰半宽", "Ornament half-width"), function() return state.ornament_half end, function(v)
		state.ornament_half = v
		apply_title()
	end, 12, 40)
	add_slider(toast_adv, prefix .. "_BodyY", tr("正文起始 Y", "Body start Y"), function() return state.body_y end, function(v)
		state.body_y = v
		apply_title()
	end, -8, 16)
	add_slider(toast_adv, prefix .. "_BodyRow", tr("正文行距", "Body row height"), function() return state.body_row end, function(v)
		state.body_row = v
		apply_title()
	end, 8, 16)

	local toast_anim = imgui_layout.add_section(toast, prefix .. "_ToastAnim", tr("出现动画", "Appear animation"))
	add_slider(toast_anim, prefix .. "_FadeIn", tr("淡入（逻辑帧@30Hz）", "Fade In (logic frames @30Hz)"), function() return state.fade_in end, function(v)
		state.fade_in = v
		local hud = hud_mod()
		if hud and hud.set_toast_fade then hud.set_toast_fade({fade_in = v}) end
	end, 0, 30)
	add_slider(toast_anim, prefix .. "_FadeOut", tr("淡出（逻辑帧@30Hz）", "Fade Out (logic frames @30Hz)"), function() return state.fade_out end, function(v)
		state.fade_out = v
		local hud = hud_mod()
		if hud and hud.set_toast_fade then hud.set_toast_fade({fade_out = v}) end
	end, 0, 60)
	add_slider(toast_anim, prefix .. "_EnterY", tr("Enter Y", "Enter Y"), function() return state.enter_y end, function(v)
		state.enter_y = v
		local hud = hud_mod()
		if hud and hud.set_toast_fade then hud.set_toast_fade({enter_y = v}) end
	end, 0, 12)
	imgui_layout.add_wrapped_text(
		toast_anim, prefix .. "_AnimNote",
		tr(
			"Persistent 预览固定 alpha=1 / offset=0；正式 Toast 才播动画。",
			"Persistent preview stays alpha=1 / offset=0; only live toasts animate."
		)
	)

	ImGui.AddButton(toast, prefix .. "_ToastStop", tr("停止预览", "Stop preview"), function()
		local hud = hud_mod()
		if hud then hud.set_debug_preview(false) end
	end)
	ImGui.AddElement(toast, "", ImGuiElement.SameLine)
	ImGui.AddButton(toast, prefix .. "_ToastZero", tr("重置 Toast 偏移", "Reset toast offset"), function()
		local hud = hud_mod()
		if hud and hud.reset_debug_toast_offset then hud.reset_debug_toast_offset() end
		if hud and hud.reset_debug_title_layout then hud.reset_debug_title_layout() end
		if hud and hud.reset_toast_fade then hud.reset_toast_fade() end
		sync()
		apply_title()
	end)

	-- Advanced surface
	local adv = imgui_layout.add_section(group, prefix .. "_Adv", tr("高级：Pause Surface 整体偏移", "Advanced: Pause surface offset"))
	add_slider(adv, prefix .. "_SX", "Surface X", function() return state.surface_x end, function(v)
		state.surface_x = v
		pause_ui.set_debug_surface_offset(state.surface_x, state.surface_y)
	end, -120, 120)
	add_slider(adv, prefix .. "_SY", "Surface Y", function() return state.surface_y end, function(v)
		state.surface_y = v
		pause_ui.set_debug_surface_offset(state.surface_x, state.surface_y)
	end, -100, 100)
	ImGui.AddButton(adv, prefix .. "_AllZero", tr("归零全部临时偏移", "Zero all temp offsets"), function()
		pause_ui.reset_debug_offsets()
		if pause_ui.reset_toggle_offsets then pause_ui.reset_toggle_offsets() end
		pause_ui.set_debug_shift_test(nil)
		pause_ui.set_paper_tune({clear = true})
		local hud = hud_mod()
		if hud and hud.reset_debug_toast_offset then hud.reset_debug_toast_offset() end
		if hud and hud.reset_debug_title_layout then hud.reset_debug_title_layout() end
		if hud and hud.reset_toast_fade then hud.reset_toast_fade() end
		local panel = panel_mod()
		if panel and panel.reset_debug_preview then panel.reset_debug_preview() end
		if hud then hud.set_debug_preview(false) end
		sync()
		apply_title()
	end)

	-- Chapter Transition (independent of Quest Toast layout)
	local ct_ok, chapter_transition = pcall(require, "Qing_Remaster_scripts.story.chapter_transition")
	if ct_ok and chapter_transition then
		local ct_group = start_mod(
			"visual_chapter_transition",
			DEBUG_PAGE.visual,
			tr("章节揭幕", "Chapter Transition"),
			"QingRemasterOptions_GroupChapterTransition",
			{path = {"Chapter Transition"}, kind = "tool"}
		)
		if ct_group then
			local ctp = ct_group .. "_CT"
			local ct_state = {
				font_index = 1, -- yozai_medium default among FONT_IDS
			}
			local font_ids = chapter_transition.FONT_IDS or {"runtime_cjk", "yozai_medium", "xiaolai", "cef_cjk"}
			for i, id in ipairs(font_ids) do
				if id == (chapter_transition.config and chapter_transition.config.font_id) then
					ct_state.font_index = i - 1
					break
				end
			end
			local function font_labels()
				local out = {}
				for i, id in ipairs(font_ids) do
					local lab = chapter_transition.FONT_LABELS and chapter_transition.FONT_LABELS[id]
					out[i] = (lab and tr(lab.zh, lab.en)) or id
				end
				return out
			end
			local function cfg()
				return chapter_transition.get_config and chapter_transition.get_config() or chapter_transition.config
			end
			local function set_cfg(key, value)
				if chapter_transition.set_config then
					chapter_transition.set_config({[key] = value})
				elseif chapter_transition.config then
					chapter_transition.config[key] = value
				end
			end

			imgui_layout.add_wrapped_text(
				ct_group, ctp .. "_Note",
				tr(
					"独立章节标题字体（默认 Yozai Medium soft，约 36px，无白色膨胀）。可切 Yozai hard=alpha128 做 A/B。Quest 揭幕期间 suspend。",
					"Chapter fonts (default Yozai Medium soft ~36px, no white expand). Switch Yozai hard=alpha128 for A/B. Quest suspends during reveal."
				)
			)
			ImGui.AddButton(ct_group, ctp .. "_PlayHunt", tr("仅预览标题", "Title only"), function()
				chapter_transition.debug_play_title()
			end)
			ImGui.AddElement(ct_group, "", ImGuiElement.SameLine)
			ImGui.AddButton(ct_group, ctp .. "_PlaySeq", tr("预览：标题 → 任务", "Preview: title → quest"), function()
				-- Formal path: start_prologue_hunt() owns suspend → title → resume.
				chapter_transition.debug_play_title_then_quest()
			end)
			ImGui.AddElement(ct_group, "", ImGuiElement.SameLine)
			ImGui.AddCheckbox(ct_group, ctp .. "_GlyphTest", tr("字体 Glyph Test", "Font glyph test"), function(checked)
				if chapter_transition.set_glyph_test then
					chapter_transition.set_glyph_test(checked == true)
				end
			end, false)

			ImGui.AddCombobox(ct_group, ctp .. "_Font", tr("字体", "Font"), function(index)
				ct_state.font_index = index or 0
				local id = font_ids[ct_state.font_index + 1]
				if id then set_cfg("font_id", id) end
			end, font_labels(), ct_state.font_index)
			ImGui.AddCallback(ctp .. "_Font", ImGuiCallback.Render, function()
				ImGui.UpdateData(ctp .. "_Font", ImGuiData.ListValues, font_labels())
				ImGui.UpdateData(ctp .. "_Font", ImGuiData.Value, ct_state.font_index)
			end)

			imgui_layout.add_wrapped_text(ct_group, ctp .. "_FontStatus", "")
			ImGui.AddCallback(ctp .. "_FontStatus", ImGuiCallback.Render, function()
				local id = font_ids[ct_state.font_index + 1] or "yozai_medium"
				local st = chapter_transition.get_font_status and chapter_transition.get_font_status(id)
				local text_out = "-"
				if st then
					local gw = {}
					for _, g in ipairs(st.glyphs or {}) do
						gw[#gw + 1] = string.format("%s=%s", tostring(g.ch), tostring(g.width or "?"))
					end
					local lines = {
						string.format("Requested: %s", tostring(st.requested_id or st.id)),
						string.format("Requested loaded: %s", tostring(st.loaded)),
						string.format("Resolved: %s", tostring(st.resolved or st.path or "?")),
						string.format("call_ok=%s reason=%s", tostring(st.call_ok), tostring(st.reason or "-")),
						string.format("ModRoot: %s", tostring(st.mod_root or "?")),
					}
					if st.is_runtime_fallback then
						lines[#lines + 1] = string.format(
							"Fallback: %s (eff=%s) SampleW=%s LineH=%s",
							tostring(st.fallback_id or "gui.f2"),
							tostring(st.effective_id),
							tostring(st.fallback_sample_width or "?"),
							tostring(st.fallback_line_height or "?")
						)
					else
						lines[#lines + 1] = string.format(
							"Effective: %s  SampleW=%s  ASCII=%s  LineH=%s",
							tostring(st.effective_id or st.id),
							tostring(st.sample_width or "?"),
							tostring(st.ascii_width or "?"),
							tostring(st.line_height or "?")
						)
						if #gw > 0 then
							lines[#lines + 1] = table.concat(gw, "  ")
						end
					end
					text_out = table.concat(lines, "\n")
				end
				imgui_layout.update_text(ctp .. "_FontStatus", text_out)
			end)

			local scale_choices = chapter_transition.SCALE_CHOICES or {0.5, 1, 2}
			local function scale_index(value)
				for i, s in ipairs(scale_choices) do
					if math.abs((tonumber(value) or 0) - s) < 0.01 then
						return i - 1
					end
				end
				return 1
			end
			local function scale_labels()
				local out = {}
				for i, s in ipairs(scale_choices) do
					out[i] = tostring(s) .. "x"
				end
				return out
			end
			ct_state.ch_scale_index = scale_index(cfg().chapter_scale)
			ct_state.ti_scale_index = scale_index(cfg().title_scale)
			ImGui.AddCombobox(ct_group, ctp .. "_ChScale", tr("章节字号", "Chapter scale"), function(index)
				ct_state.ch_scale_index = index or 0
				local s = scale_choices[ct_state.ch_scale_index + 1]
				if s then set_cfg("chapter_scale", s) end
			end, scale_labels(), ct_state.ch_scale_index)
			ImGui.AddCallback(ctp .. "_ChScale", ImGuiCallback.Render, function()
				ct_state.ch_scale_index = scale_index(cfg().chapter_scale)
				ImGui.UpdateData(ctp .. "_ChScale", ImGuiData.ListValues, scale_labels())
				ImGui.UpdateData(ctp .. "_ChScale", ImGuiData.Value, ct_state.ch_scale_index)
			end)
			ImGui.AddCombobox(ct_group, ctp .. "_TiScale", tr("标题字号", "Title scale"), function(index)
				ct_state.ti_scale_index = index or 0
				local s = scale_choices[ct_state.ti_scale_index + 1]
				if s then set_cfg("title_scale", s) end
			end, scale_labels(), ct_state.ti_scale_index)
			ImGui.AddCallback(ctp .. "_TiScale", ImGuiCallback.Render, function()
				ct_state.ti_scale_index = scale_index(cfg().title_scale)
				ImGui.UpdateData(ctp .. "_TiScale", ImGuiData.ListValues, scale_labels())
				ImGui.UpdateData(ctp .. "_TiScale", ImGuiData.Value, ct_state.ti_scale_index)
			end)
			add_slider(ct_group, ctp .. "_Spacing", tr("字距", "Letter spacing"), function()
				return cfg().letter_spacing or 0
			end, function(v) set_cfg("letter_spacing", math.max(0, math.min(8, v))) end, 0, 8)
			add_slider(ct_group, ctp .. "_Hold", tr("Hold frames", "Hold frames"), function()
				return cfg().hold or 40
			end, function(v) set_cfg("hold", math.max(0, v)) end, 0, 120)
			add_slider(ct_group, ctp .. "_Fade", tr("Fade frames", "Fade frames"), function()
				return cfg().fade or 18
			end, function(v) set_cfg("fade", math.max(0, v)) end, 0, 60)
			add_slider(ct_group, ctp .. "_After", tr("Post delay frames", "Post delay frames"), function()
				return cfg().after_delay or 18
			end, function(v) set_cfg("after_delay", math.max(0, v)) end, 0, 60)
			add_slider(ct_group, ctp .. "_ChY", tr("章节 Y% ×100", "Chapter Y% ×100"), function()
				return math.floor(((cfg().chapter_y_frac or 0.40) * 100) + 0.5)
			end, function(v) set_cfg("chapter_y_frac", v / 100) end, 20, 70)
			add_slider(ct_group, ctp .. "_TiY", tr("标题 Y% ×100", "Title Y% ×100"), function()
				return math.floor(((cfg().title_y_frac or 0.50) * 100) + 0.5)
			end, function(v) set_cfg("title_y_frac", v / 100) end, 25, 80)

			ImGui.AddButton(ct_group, ctp .. "_Reset", tr("重置参数", "Reset params"), function()
				if chapter_transition.reset_config then chapter_transition.reset_config() end
				if chapter_transition.clear_font_cache then chapter_transition.clear_font_cache() end
				ct_state.font_index = 1
				for i, id in ipairs(font_ids) do
					if id == "yozai_medium" then
						ct_state.font_index = i - 1
						break
					end
				end
				ct_state.ch_scale_index = scale_index(cfg().chapter_scale)
				ct_state.ti_scale_index = scale_index(cfg().title_scale)
			end)
		end
	end

	_ = text -- silence unused when language helpers unused
end

return mod
