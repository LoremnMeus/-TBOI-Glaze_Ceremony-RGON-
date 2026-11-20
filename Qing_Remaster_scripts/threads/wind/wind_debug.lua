-- Storm / wind field DEV playtest panel (Story Dev Lab only).

local save = require("Qing_Remaster_scripts.core.savedata")
local imgui_layout = require("Qing_Remaster_scripts.debug.imgui_debug_layout")
local wind = require("Qing_Remaster_scripts.threads.wind.wind_runtime")
local session = require("Qing_Remaster_scripts.story_test.story_test_session")
local encounter = require("Qing_Remaster_scripts.threads.wind.storm_encounter")
local thread_wind = require("Qing_Remaster_scripts.threads.thread_Wind")

local debug = {}

local PRESET_ORDER = {
	{id = "none", zh = "无风", en = "None"},
	{id = "weak", zh = "弱风", en = "Weak"},
	{id = "mid", zh = "中风", en = "Medium"},
	{id = "strong", zh = "强风", en = "Strong"},
}

local PRESET_LABEL = {
	none = {zh = "无风", en = "None"},
	weak = {zh = "弱风", en = "Weak"},
	mid = {zh = "中风", en = "Medium"},
	strong = {zh = "强风", en = "Strong"},
}

local function tr(zh, en)
	local language = Options and Options.Language
	return (language == "en") and en or zh
end

local function pick_label(row)
	return tr(row.zh, row.en)
end

local function require_test_session()
	if session.is_active and session.is_active() then
		return true
	end
	session.last_message = tr(
		"请先开始支线测试，再调节风场。",
		"Start the side-event test before adjusting wind."
	)
	return false
end

local function current_override()
	return wind.get_debug_override and wind.get_debug_override() or nil
end

local function status_text()
	if not (session.is_active and session.is_active()) then
		return tr("当前：未在测试会话中（覆盖不会生效）", "Status: story test inactive (overrides disabled)")
	end
	local dbg = current_override()
	if not dbg or not dbg.active then
		return tr("当前：正式支线风场（无调试覆盖）", "Status: formal branch wind (no debug overlay)")
	end
	local preset = PRESET_LABEL[dbg.preset] or PRESET_LABEL.mid
	local lines = {
		tr("当前选择：", "Selected: ") .. pick_label(preset),
		tr(
			"风线：" .. ((dbg.show_particles ~= false) and "开启" or "关闭"),
			"Wind lines: " .. ((dbg.show_particles ~= false) and "on" or "off")
		),
		tr(
			"逆风阻力：" .. ((dbg.enable_drag ~= false) and "开启" or "关闭"),
			"Headwind drag: " .. ((dbg.enable_drag ~= false) and "on" or "off")
		),
	}
	if dbg.combat_preview then
		lines[#lines + 1] = tr("战斗风预览：开启", "Combat wind preview: on")
	end
	return table.concat(lines, " · ")
end

local function flow_status_text()
	local diag = encounter.get_diagnostics and encounter.get_diagnostics() or {}
	local insp = thread_wind.story_test and thread_wind.story_test.inspect and thread_wind.story_test.inspect() or {}
	local head = thread_wind.heading_debug and thread_wind.heading_debug() or {}
	local prefill = head.prefill or {}
	return string.format(
		"%s phase=%s cover=%s a=%.2f fade=%s draw=%s ready=%s arena=%s vis=%s lock=%s bosses=%s err=%s | room=%s eye=%s dist=%s geo=%s bfs=%s mix=%s ang=%s blow=%s gen=%s prefill=%s/%s trace=%s",
		tr("流程：", "Flow: "),
		tostring(diag.phase or insp.phase or "?"),
		tostring(diag.cover_state or "none"),
		tonumber(diag.cover_alpha) or 0,
		tostring(diag.fade_frame or 0),
		tostring(diag.cover_draw_enabled == true),
		tostring(diag.ready_for_reveal),
		tostring(diag.arena_ok),
		tostring(diag.arena_visual_ready),
		tostring(diag.boss_locked),
		tostring(diag.real_boss_count),
		tostring(diag.arena_visual_error or diag.cover_block or diag.last_error or "-"),
		tostring(head.room_sgid or "-"),
		tostring(head.eye_sgid or "-"),
		tostring(head.bfs_distance),
		tostring(head.geo_heading or "-"),
		tostring(head.bfs_heading or "-"),
		tostring(head.mixed_heading or "-"),
		tostring(head.runtime_ang),
		tostring(head.visual_blow or "-"),
		tostring(head.session_generation),
		tostring(prefill.airflow),
		tostring(prefill.airflow_goal),
		tostring(head.room_trace or "-")
	)
end

local function report(ok, msg)
	if ok then
		session.last_message = tostring(msg or "ok")
	else
		session.last_message = tr("失败：", "Failed: ") .. tostring(msg or "unknown")
	end
	return ok
end

function debug.clear_override_and_restore()
	wind.clear_debug_override({reapply_formal = true})
	session.last_message = tr("已恢复正式风场", "Formal wind restored")
	return true
end

function debug.apply_preset(preset_id)
	if not require_test_session() then
		return false
	end
	local ok, err = wind.set_debug_override({
		preset = preset_id,
		combat_preview = false,
	})
	if not ok then
		session.last_message = tr("风场覆盖失败：", "Wind override failed: ") .. tostring(err)
		return false
	end
	session.last_message = tr("已切换风力：", "Wind set: ") .. pick_label(PRESET_LABEL[preset_id] or PRESET_LABEL.mid)
	return true
end

function debug.set_show_particles(checked)
	if not require_test_session() then
		return false
	end
	local dbg = current_override()
	local ok, err = wind.set_debug_override({
		preset = (dbg and dbg.preset) or "mid",
		show_particles = checked == true,
		combat_preview = dbg and dbg.combat_preview == true,
	})
	if not ok then
		session.last_message = tr("风线开关失败：", "Wind-line toggle failed: ") .. tostring(err)
		return false
	end
	return true
end

function debug.set_enable_drag(checked)
	if not require_test_session() then
		return false
	end
	local dbg = current_override()
	local ok, err = wind.set_debug_override({
		preset = (dbg and dbg.preset) or "mid",
		enable_drag = checked == true,
		combat_preview = dbg and dbg.combat_preview == true,
	})
	if not ok then
		session.last_message = tr("阻力开关失败：", "Drag toggle failed: ") .. tostring(err)
		return false
	end
	return true
end

function debug.start_combat_preview()
	if not require_test_session() then
		return false
	end
	local dbg = current_override()
	local ok, err = wind.set_debug_override({
		preset = (dbg and dbg.preset) or "mid",
		combat_preview = true,
	})
	if not ok then
		session.last_message = tr("战斗风预览失败：", "Combat wind preview failed: ") .. tostring(err)
		return false
	end
	session.last_message = tr("已进入战斗风预览", "Combat wind preview on")
	return true
end

function debug.get_test_descriptor()
	return {
		id = "chapter1.wind",
		title = {zh = "风暴 / Zennith", en = "Wind / Zennith"},
		floor_preset = "mausoleum_gehenna_1",
		hide_flow_validation = true,
		notes = tr(
			"开始风暴只打开当前楼层的探索风场。前往风眼、战斗和降临是另外的测试。重复点击不会把正在进行的测试清掉。",
			"Start Storm only opens exploration on this floor. Eye, battle, and descent are separate tests. A second click does not clear a test that is still running."
		),
		build_thread_tools = function(parent_id)
			debug.build_thread_tools(parent_id)
		end,
	}
end

function debug.build_thread_tools(parent_id)
	if not ImGui or not parent_id then return end
	local prefix = parent_id .. "_WindField"

	local test_runner = require("Qing_Remaster_scripts.threads.wind.wind_test_runner")

	ImGui.AddElement(
		parent_id, "", ImGuiElement.SeparatorText or ImGuiElement.Separator,
		tr("风暴事件", "Storm event")
	)
	imgui_layout.add_wrapped_text(
		parent_id, prefix .. "_MainHint",
		tr(
			"开始风暴只建立风眼和路径，停留在寻找阶段。传送显示 QUEUED，到达后才继续。正在进行的测试不会被另一个按钮覆盖。",
			"Start Storm builds the eye and paths and stays in SEARCHING. Travel stays QUEUED until the room is real. A running test is not replaced by another button."
		)
	)
	imgui_layout.add_wrapped_text(parent_id, prefix .. "_JobStatus", "")
	ImGui.AddCallback(prefix .. "_JobStatus", ImGuiCallback.Render, function()
		local st = test_runner.status()
		imgui_layout.update_text(
			prefix .. "_JobStatus",
			string.format("%s  %s  %s", tostring(st.status), tostring(st.id or "-"), tostring(st.error or ""))
		)
	end)
	ImGui.AddButton(parent_id, prefix .. "_Storm", tr("开始风暴", "Start storm"), function()
		test_runner.start_storm()
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_GotoEye", tr("前往风眼", "Go to eye"), function()
		test_runner.start_eye()
	end)

	ImGui.AddElement(
		parent_id, "", ImGuiElement.SeparatorText or ImGuiElement.Separator,
		tr("Boss 测试", "Boss tests")
	)
	ImGui.AddButton(parent_id, prefix .. "_Battle", tr("直接开始 Zennith 战斗", "Start Zennith battle"), function()
		test_runner.start_battle()
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_FullStory", tr("播放完整降临剧情", "Play full descent"), function()
		test_runner.start_full()
	end)

	ImGui.AddElement(
		parent_id, "", ImGuiElement.SeparatorText or ImGuiElement.Separator,
		tr("辅助", "Tools")
	)
	ImGui.AddButton(parent_id, prefix .. "_WindOnly", tr("单独测试风场", "Test wind only"), function()
		test_runner.start_wind()
	end)
	local phase_labels = {}
	for i, row in ipairs(test_runner.phases) do
		phase_labels[i] = tr(row.zh, row.en)
	end
	ImGui.AddCombobox(parent_id, prefix .. "_Phase", tr("从指定阶段开始", "Start at phase"), function(index)
		test_runner.select_phase(index)
	end, phase_labels, test_runner.selected - 1)
	ImGui.AddButton(parent_id, prefix .. "_PhaseGo", tr("测试所选阶段", "Run selected phase"), function()
		test_runner.start_selected_phase()
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_EndTest", tr("结束测试并恢复", "End test and restore"), function()
		test_runner.cancel()
		session.restore()
	end)

	ImGui.AddElement(
		parent_id, "", ImGuiElement.SeparatorText or ImGuiElement.Separator,
		tr("运行诊断", "Diagnostics")
	)
	imgui_layout.add_wrapped_text(parent_id, prefix .. "_Diag", "")
	ImGui.AddCallback(prefix .. "_Diag", ImGuiCallback.Render, function()
		imgui_layout.update_text(prefix .. "_Diag", test_runner.report_text())
	end)
	ImGui.AddButton(parent_id, prefix .. "_Copy", tr("复制诊断报告", "Copy diagnostic report"), function()
		local text = test_runner.report_text()
		if ImGui.SetClipboardText then
			ImGui.SetClipboardText(text)
		elseif Isaac and Isaac.SetClipboard then
			Isaac.SetClipboard(text)
		end
		session.last_message = tr("已复制诊断报告", "Diagnostic report copied")
	end)
	imgui_layout.add_wrapped_text(
		parent_id, prefix .. "_ProbeNote",
		tr(
			"采样探针仍在：探针 → 剧情与支线 → 风场 · 管线探针。Render 调用次数不等于屏幕上看得见。",
			"The capture probe remains under Probes → Story → Wind pipeline. Render calls are not the same as pixels on screen."
		)
	)

	ImGui.AddElement(
		parent_id, "", ImGuiElement.SeparatorText or ImGuiElement.Separator,
		tr("Arena 场景", "Arena scene")
	)
	imgui_layout.add_wrapped_text(
		parent_id, prefix .. "_ArenaHint",
		tr(
			"直接开始战斗会自己准备 Arena。纯色覆盖用来核对墙体是否被挡住。分层开关不重建风场。",
			"Start battle prepares the arena itself. Solid cover checks that the basement walls are hidden. Layer toggles do not rebuild the wind."
		)
	)
	local arena_visual = require("Qing_Remaster_scripts.threads.wind.arena_visual")
	local function arena_toggle(id, group, zh, en)
		ImGui.AddCheckbox(parent_id, prefix .. id, tr(zh, en), function(checked)
			arena_visual.set_layer(group, checked == true)
		end, arena_visual.get_mask()[group] ~= false)
	end
	arena_toggle("_ArenaFar", "far", "远景云层", "Far clouds")
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	arena_toggle("_ArenaRings", "rings", "旋转云墙", "Cloud walls")
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	arena_toggle("_ArenaFloor", "floor", "中心地表", "Center floor")
	arena_toggle("_ArenaFront", "front", "前景风幕", "Foreground mist")
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddCheckbox(parent_id, prefix .. "_ArenaSolid", tr("纯色覆盖测试", "Solid cover test"), function(checked)
		arena_visual.set_solid_test(checked == true)
	end, arena_visual.solid_test())
	ImGui.AddButton(parent_id, prefix .. "_ArenaBolt", tr("触发闪电", "Trigger lightning"), function()
		arena_visual.request_lightning()
		session.last_message = tr("已请求一次云中闪电", "Requested one cloud lightning strike")
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_ArenaThunder", tr("试听雷声", "Preview thunder"), function()
		arena_visual.preview_thunder(0.80)
		session.last_message = tr("已试听普通雷声（0.80），不生成闪电", "Previewed normal thunder (0.80), no lightning")
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_ArenaThunderStrong", tr("试听强雷声", "Preview strong thunder"), function()
		arena_visual.preview_thunder(1.00)
		session.last_message = tr("已试听强雷声（1.00），不生成闪电", "Previewed strong thunder (1.00), no lightning")
	end)

	-- B. Field feel
	ImGui.AddElement(
		parent_id, "", ImGuiElement.SeparatorText or ImGuiElement.Separator,
		tr("风场测试", "Wind Field Test")
	)
	imgui_layout.add_wrapped_text(
		parent_id, prefix .. "_Hint",
		tr(
			"仅在支线测试会话中生效。不写入永久剧情进度，也不改 BFS。换层或结束测试会自动撤销。",
			"Active only during a story-test session. Does not write StoryProgress or BFS. Cleared on floor change or end test."
		)
	)
	imgui_layout.add_wrapped_text(parent_id, prefix .. "_Status", "")
	ImGui.AddCallback(prefix .. "_Status", ImGuiCallback.Render, function()
		imgui_layout.update_text(prefix .. "_Status", status_text())
	end)
	imgui_layout.add_wrapped_text(parent_id, prefix .. "_Flow", "")
	ImGui.AddCallback(prefix .. "_Flow", ImGuiCallback.Render, function()
		imgui_layout.update_text(prefix .. "_Flow", flow_status_text())
	end)

	ImGui.AddElement(
		parent_id, "", ImGuiElement.SeparatorText or ImGuiElement.Separator,
		tr("风力", "Wind strength")
	)
	for i, row in ipairs(PRESET_ORDER) do
		local bid = prefix .. "_P_" .. row.id
		if i > 1 then
			ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
		end
		ImGui.AddButton(parent_id, bid, pick_label(row), function()
			debug.apply_preset(row.id)
		end)
	end

	local dbg0 = current_override()
	ImGui.AddCheckbox(
		parent_id,
		prefix .. "_Lines",
		tr("显示风线", "Show wind lines"),
		function(checked)
			debug.set_show_particles(checked)
		end,
		(dbg0 == nil) or (dbg0.show_particles ~= false)
	)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddCheckbox(
		parent_id,
		prefix .. "_Drag",
		tr("启用逆风阻力", "Enable headwind drag"),
		function(checked)
			debug.set_enable_drag(checked)
		end,
		(dbg0 == nil) or (dbg0.enable_drag ~= false)
	)

	ImGui.AddButton(parent_id, prefix .. "_Combat", tr("测试战斗风", "Test combat wind"), function()
		debug.start_combat_preview()
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_Restore", tr("恢复正常", "Restore normal"), function()
		debug.clear_override_and_restore()
	end)

	ImGui.AddElement(
		parent_id, "", ImGuiElement.SeparatorText or ImGuiElement.Separator,
		tr("风场管线探针", "Wind Pipeline Probe")
	)
	imgui_layout.add_wrapped_text(
		parent_id, prefix .. "_ProbePath",
		tr(
			"完整探针：探针 → 剧情与支线 → 风场 · 管线探针。下方为采样/导出（快速测试已在顶部）。",
			"Full probe: Probes → Story → Wind · Pipeline. Capture/export below (quick test is at top)."
		)
	)
	do
		local ok_env, dev_env = pcall(require, "Qing_Remaster_scripts.core.dev_environment")
		local p = ok_env and dev_env.require_probe
			and dev_env.require_probe("Qing_Remaster_scripts.threads.wind.wind_pipeline_probe")
		if p and p.build_ui then
			p.build_ui(parent_id, prefix .. "_WPP", {skip_quick = true})
		else
			imgui_layout.add_wrapped_text(
				parent_id, prefix .. "_ProbeMissing",
				tr("管线探针不可用（未注册或正式包禁用）。", "Pipeline probe unavailable.")
			)
		end
	end

	ImGui.AddElement(
		parent_id, "", ImGuiElement.SeparatorText or ImGuiElement.Separator,
		tr("V7.2 分层隔离", "V7.2 layer isolation")
	)
	imgui_layout.add_wrapped_text(
		parent_id, prefix .. "_LayerHint",
		tr(
			"调用真实 visual 模块开关层，不生成替代贴图。用于核对 AIRFLOW / GUST / MOTES / 风柱是否各自连续工作。",
			"Toggles real visual layers (no placeholder sprites). Verify each class runs on its own."
		)
	)
	local solo = {
		{"airflow", tr("仅 AIRFLOW", "AIRFLOW only")},
		{"gust", tr("仅 GUST", "GUST only")},
		{"motes", tr("仅 MOTES", "MOTES only")},
		{"tornado", tr("仅风柱", "Tornado only")},
		{"all", tr("全部组合", "All layers")},
	}
	for i, row in ipairs(solo) do
		if i > 1 then
			ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
		end
		ImGui.AddButton(parent_id, prefix .. "_Solo_" .. row[1], row[2], function()
			if not require_test_session() then return end
			wind.set_solo_visual_layer(row[1])
			-- "全部组合" restores formal visibility; isolation modes are temporary.
			session.last_message = tr("分层：", "Layer: ") .. row[1]
		end)
	end
	imgui_layout.add_wrapped_text(parent_id, prefix .. "_LayerStats", "")
	ImGui.AddCallback(prefix .. "_LayerStats", ImGuiCallback.Render, function()
		local stats = wind.get_visual_stats and wind.get_visual_stats() or {}
		local layers = stats.layers or {}
		local air = layers.airflow or {}
		local gust = layers.gust or {}
		local motes = layers.motes or {}
		local mask = stats.layer_mask or {}
		local m = stats.metrics or {}
		local line = string.format(
			"v7.6 · air in=%s/%s col=%s/%s(v%s) spr=%s/%s geom=%s cens=%s upd=%.2f ren=%.2f diag=%s",
			tostring(air.inbound_visible or 0), tostring(air.inbound_incoming or 0),
			tostring(air.column_total or 0), tostring(air.column_visible or 0),
			tostring(air.column_visual or 0),
			tostring(m.render_sprite_success or 0), tostring(m.render_sprite_attempts or 0),
			tostring(m.column_geometry_builds or 0), tostring(m.census_calls or 0),
			tonumber(m.update_time_ms) or 0, tonumber(m.render_time_ms) or 0,
			tostring(stats.diag or m.diag or "-")
		)
		imgui_layout.update_text(prefix .. "_LayerStats", line)
	end)

	ImGui.AddElement(
		parent_id, "", ImGuiElement.SeparatorText or ImGuiElement.Separator,
		tr("V5 视觉诊断", "V5 visual diagnostics")
	)
	ImGui.AddButton(parent_id, prefix .. "_White", tr("诊断：强制白/不透明", "Diag: force white"), function()
		if not require_test_session() then return end
		local dbg = current_override()
		wind.set_debug_override({
			preset = (dbg and dbg.preset) or "mid",
			force_white_debug = true,
		})
		session.last_message = tr("诊断模式：白/不透明（结构检查）", "Diag mode: opaque white")
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_WhiteOff", tr("关闭诊断染色", "Diag off"), function()
		if not require_test_session() then return end
		local dbg = current_override()
		wind.set_debug_override({
			preset = (dbg and dbg.preset) or "mid",
			force_white_debug = false,
		})
		session.last_message = tr("已关闭诊断染色", "Diag tint off")
	end)

	imgui_layout.add_wrapped_text(parent_id, prefix .. "_VisStats", "")
	ImGui.AddCallback(prefix .. "_VisStats", ImGuiCallback.Render, function()
		local stats = wind.get_visual_stats and wind.get_visual_stats() or {}
		local counts = stats.counts or {}
		local line = string.format(
			"v5 · gen=%s reset=%s(%s) total=%s streak=%s veil=%s debris=%s eye_ring=%s",
			tostring(stats.session_generation or 0),
			tostring(stats.particle_reset_count or 0),
			tostring(stats.last_reset_reason or "-"),
			tostring(stats.total or 0),
			tostring(counts.streak or 0),
			tostring(counts.veil or 0),
			tostring(counts.debris or 0),
			tostring(counts.eye_ring or 0)
		)
		imgui_layout.update_text(prefix .. "_VisStats", tr("生命周期：", "Lifecycle: ") .. line)
	end)
end

-- Legacy alias for old callers.
function debug.build_advanced(parent_id)
	debug.build_thread_tools(parent_id)
end

return debug
