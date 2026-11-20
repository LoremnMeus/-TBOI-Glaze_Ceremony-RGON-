-- Debug → Items → 焚火. Spray controls and visual parameters.
-- Diagnostics stay on the probe page.

local session = require("Qing_Remaster_scripts.items.incandescence_flame.flame_session")

local ui = {}

local function player()
	if not Isaac.IsInGame or not Isaac.IsInGame() then
		return nil
	end
	return Isaac.GetPlayer(0)
end

local function drag(group, id, label, key, default, speed, min_v, max_v, fmt)
	ImGui.AddDragFloat(group, id, label, function(value)
		session.set_number(key, value)
	end, default, speed, min_v, max_v, fmt or "%.0f")
	ImGui.AddCallback(id, ImGuiCallback.Render, function()
		local cfg = session.config()
		local value = cfg[key]
		if key == "jet_seconds" then
			value = (cfg.jet_frames or 22) / 30
		end
		ImGui.UpdateData(id, ImGuiData.Value, tonumber(value) or default)
	end)
end

local function check(group, id, label, getter, setter)
	ImGui.AddCheckbox(group, id, label, nil, getter() == true)
	ImGui.AddCallback(id, ImGuiCallback.Edited, function(value)
		setter(value == true)
	end)
	ImGui.AddCallback(id, ImGuiCallback.Render, function()
		ImGui.UpdateData(id, ImGuiData.Value, getter() == true)
	end)
end

function ui.install(parent, start_mod, add_text, page)
	local group = start_mod(
		"item_incandescence_flame",
		page,
		"焚火",
		"QingRemasterOptions_GroupIncandescenceFlame",
		{ path = { "Incandescence Flame" }, kind = "tool" }
	)
	if not group then
		return
	end
	add_text(group, "先关独立粒子和显示边界，看纯色火柱。前缘按头部实际宽度鼓出，子层整条轮廓必须落在父层多边形里。稳定区大约是橙色 0.78、金黄 0.47、火心 0.09，远端金黄会再收。显示边界时暗红是外焰，橙色是主体，金色是内焰，浅色是火心。伤害和蓄力尚未接入。")
	local status_id = "QingRemasterOptions_IncandescenceFlameStatus"
	local imgui_layout = require("Qing_Remaster_scripts.debug.imgui_debug_layout")
	imgui_layout.add_wrapped_text(group, status_id, "idle")
	ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
		local row = session.snapshot()
		local live = require("Qing_Remaster_scripts.debug.probe_live_cache")
		local head = row.gate0_test and "Gate0" or tostring(row.phase)
		live.update_text_if_changed(status_id, string.format(
			"%s  绘制 %d  扫描 %s/%s 步 %s 降精度 %s 截断 %s  错误 %s",
			head,
			row.sprite_draw_calls or 0,
			tostring(row.raster_rows or 0),
			tostring(row.max_raster_rows or 0),
			tostring(row.raster_step_used or 0),
			tostring(row.raster_degraded == true),
			tostring(row.raster_budget_clamped == true),
			tostring(row.render_first_error)
		))
	end)

	ImGui.AddButton(group, "QingRemasterOptions_IncandescenceFireOnce", "发射一次", function()
		session.fire_once(player())
	end)
	ImGui.AddButton(group, "QingRemasterOptions_IncandescenceFireHold", "持续喷射", function()
		session.fire_continuous(player())
	end)
	ImGui.AddButton(group, "QingRemasterOptions_IncandescenceStop", "停止发射", function()
		session.stop()
	end)
	ImGui.AddButton(group, "QingRemasterOptions_IncandescenceClear", "立即清空", function()
		session.clear()
	end)
	check(group, "QingRemasterOptions_IncandescenceFreeze", "冻结当前视觉帧", function()
		return session.state().frozen
	end, function(on)
		session.set_frozen(on)
	end)
	ImGui.AddButton(group, "QingRemasterOptions_IncandescenceStep", "单步", function()
		session.step()
	end)
	check(group, "QingRemasterOptions_IncandescenceHeatView", "温度实验显示", function()
		return session.config().heat_view
	end, function(on)
		session.set_layer("heat_view", on)
	end)
	check(group, "QingRemasterOptions_IncandescenceWidthRegions", "旧宽度色域", function()
		return session.config().heat_regions == false
	end, function(on)
		session.set_layer("width_regions", on)
	end)
	ImGui.AddButton(group, "QingRemasterOptions_IncandescenceHeatArm", "标记下一出生截面", function()
		session.arm_heat_track()
	end)
	local heat_id = "QingRemasterOptions_IncandescenceHeatStatus"
	imgui_layout.add_wrapped_text(group, heat_id, "热斑未标记")
	ImGui.AddCallback(heat_id, ImGuiCallback.Render, function()
		local row = session.snapshot()
		local live = require("Qing_Remaster_scripts.debug.probe_live_cache")
		local us = row.temperature_update_us
		live.update_text_if_changed(heat_id, string.format(
			"热斑 id=%s 存活=%s 位移=%.1f 龄=%s 温=%.3f–%.3f 中心=%.3f 展宽=%.3f 更新=%s 截面=%s 结束=%s",
			tostring(row.tracked_slice_id or "none"),
			tostring(row.heat_track_alive == true),
			tonumber(row.travelled_distance) or 0,
			tostring(row.heat_age or 0),
			tonumber(row.temperature_min) or 0,
			tonumber(row.temperature_max) or 0,
			tonumber(row.heat_center_offset) or 0,
			tonumber(row.heat_spread) or 0,
			tostring(us),
			tostring(row.active_slice_count or 0),
			row.heat_arm and "等待出生" or tostring(row.heat_track_end or "none")
		))
	end)
	add_text(group, "正式火柱默认按截面温度分布取色层边界。温度不够的层会在该处结束，不再连成零宽度的线；火心先灭，外焰可以更远。勾选「旧宽度色域」回到原来的宽度比例；冻结后切换，火流不会重算。温度实验显示只画诊断色块。静态纯色不会推进温度场。")

	ImGui.AddButton(group, "QingRemasterOptions_IncandescenceRight", "向右", function()
		session.set_dir(1, 0)
	end)
	ImGui.AddButton(group, "QingRemasterOptions_IncandescenceLeft", "向左", function()
		session.set_dir(-1, 0)
	end)
	ImGui.AddButton(group, "QingRemasterOptions_IncandescenceUp", "向上", function()
		session.set_dir(0, -1)
	end)
	ImGui.AddButton(group, "QingRemasterOptions_IncandescenceDown", "向下", function()
		session.set_dir(0, 1)
	end)
	ImGui.AddButton(group, "QingRemasterOptions_IncandescenceAim", "跟随瞄准", function()
		session.clear_forced_dir()
	end)

	check(group, "QingRemasterOptions_IncandescenceLock", "锁定位置", function()
		return session.config().lock_origin
	end, session.set_lock_origin)
	check(group, "QingRemasterOptions_IncandescenceGate0", "Gate 0 矩形测试", function()
		return session.config().gate0_test
	end, function(on)
		session.set_layer("gate0", on)
	end)
	check(group, "QingRemasterOptions_IncandescenceStatic", "静态纯色", function()
		return session.config().static_solid
	end, function(on)
		session.set_layer("static", on)
	end)
	check(group, "QingRemasterOptions_IncandescenceHead", "末端诊断", function()
		return session.config().show_head
	end, function(on)
		session.set_layer("head", on)
	end)
	check(group, "QingRemasterOptions_IncandescenceCapMulti", "旧多峰前缘", function()
		return session.config().cap_multi_peak
	end, function(on)
		session.set_layer("cap_multi_peak", on)
	end)
	check(group, "QingRemasterOptions_IncandescenceAudit", "屏幕空间全量自交抽检", function()
		return session.config().audit_screen
	end, function(on)
		session.set_layer("audit_screen", on)
	end)
	check(group, "QingRemasterOptions_IncandescenceFillSkipDiag", "跳过填充诊断", function()
		return session.config().fill_skip_diag
	end, function(on)
		session.set_layer("fill_skip_diag", on)
	end)
	local perf_keys = { "normal", "sim_only", "orange", "layers", "layers_particles", "stress" }
	local perf_labels = { "正常", "只模拟", "只橙色", "四层", "四层加粒子", "粒子压力" }
	local perf_id = "QingRemasterOptions_IncandescencePerf"
	ImGui.AddCombobox(group, perf_id, "性能对照", function(index)
		session.set_perf_profile(perf_keys[(index or 0) + 1] or "normal")
	end, perf_labels, 0)
	ImGui.AddCallback(perf_id, ImGuiCallback.Render, function()
		local mode = session.config().perf_profile or "normal"
		local index = 0
		for i = 1, #perf_keys do
			if perf_keys[i] == mode then
				index = i - 1
			end
		end
		ImGui.UpdateData(perf_id, ImGuiData.Value, index)
	end)
	check(group, "QingRemasterOptions_IncandescenceOuter", "外焰", function()
		return session.config().show_outer
	end, function(on)
		session.set_layer("outer", on)
	end)
	check(group, "QingRemasterOptions_IncandescenceOrange", "橙色主体", function()
		return session.config().show_orange
	end, function(on)
		session.set_layer("orange", on)
	end)
	check(group, "QingRemasterOptions_IncandescenceGold", "金黄内焰", function()
		return session.config().show_gold
	end, function(on)
		session.set_layer("gold", on)
	end)
	check(group, "QingRemasterOptions_IncandescenceWhite", "浅黄火心", function()
		return session.config().show_white
	end, function(on)
		session.set_layer("white", on)
	end)
	local override_id = "QingRemasterOptions_IncandescenceLayerOverride"
	imgui_layout.add_wrapped_text(group, override_id, "四个色层复选框当前直接控制填充。")
	ImGui.AddCallback(override_id, ImGuiCallback.Render, function()
		local live = require("Qing_Remaster_scripts.debug.probe_live_cache")
		live.update_text_if_changed(override_id, session.layer_override_text())
	end)
	check(group, "QingRemasterOptions_IncandescenceEmber", "独立粒子", function()
		return session.config().show_ember
	end, function(on)
		session.set_layer("ember", on)
	end)
	check(group, "QingRemasterOptions_IncandescenceOrbBirth", "粒子出生点", function()
		return session.config().show_orb_birth
	end, function(on)
		session.set_layer("orb_birth", on)
	end)
	check(group, "QingRemasterOptions_IncandescenceOrbTrace", "粒子轨迹", function()
		return session.config().show_orb_trace
	end, function(on)
		session.set_layer("orb_trace", on)
	end)
	check(group, "QingRemasterOptions_IncandescenceOrbUniform", "统一小球", function()
		return session.config().orb_uniform
	end, function(on)
		session.set_layer("orb_uniform", on)
	end)
	check(group, "QingRemasterOptions_IncandescencePerfStats", "性能统计", function()
		return session.config().perf_stats
	end, function(on)
		session.set_layer("perf_stats", on)
	end)
	local backend_keys = { "sprite_scanline", "sprite_scanline_composited" }
	local backend_labels = { "旧扫描线", "合并色段扫描线" }
	local backend_id = "QingRemasterOptions_IncandescenceBackend"
	ImGui.AddCombobox(group, backend_id, "扫描线后端", function(index)
		session.set_renderer_backend(backend_keys[(index or 0) + 1] or "sprite_scanline")
	end, backend_labels, 0)
	ImGui.AddCallback(backend_id, ImGuiCallback.Render, function()
		local mode = session.config().renderer_backend or "sprite_scanline"
		local index = 0
		for i = 1, #backend_keys do
			if backend_keys[i] == mode then
				index = i - 1
			end
		end
		ImGui.UpdateData(backend_id, ImGuiData.Value, index)
	end)
	check(group, "QingRemasterOptions_IncandescenceBounds", "显示边界", function()
		return session.config().show_boundaries
	end, function(on)
		session.set_layer("boundaries", on)
	end)
	check(group, "QingRemasterOptions_IncandescenceSegments", "显示分段", function()
		return session.config().show_segments
	end, function(on)
		session.set_layer("segments", on)
	end)
	check(group, "QingRemasterOptions_IncandescenceStream", "显示流线", function()
		return session.config().show_stream
	end, function(on)
		session.set_layer("stream", on)
	end)
	local color_keys = { "all", "outer", "orange", "gold", "white", "particles" }
	local color_labels = { "全部", "仅外焰", "仅橙色", "仅金黄", "仅火心", "仅粒子" }
	local color_id = "QingRemasterOptions_IncandescenceColorTest"
	ImGui.AddCombobox(group, color_id, "颜色层", function(index)
		session.set_color_test(color_keys[(index or 0) + 1] or "all")
	end, color_labels, 0)
	ImGui.AddCallback(color_id, ImGuiCallback.Render, function()
		local mode = session.config().color_test or "all"
		local index = 0
		for i = 1, #color_keys do
			if color_keys[i] == mode then
				index = i - 1
			end
		end
		ImGui.UpdateData(color_id, ImGuiData.Value, index)
	end)

	drag(group, "QingRemasterOptions_IncandescenceLength", "最大长度", "length", 300, 1, 120, 420, "%.0f")
	drag(group, "QingRemasterOptions_IncandescenceWidth", "最大半宽", "half_width", 95, 1, 30, 130, "%.0f")
	drag(group, "QingRemasterOptions_IncandescenceFlow", "前端推进", "flow", 16, 0.1, 8, 25, "%.1f")
	drag(group, "QingRemasterOptions_IncandescenceTurnExtent", "转向距离", "turn_extent", 40, 1, 32, 240, "%.0f")
	drag(group, "QingRemasterOptions_IncandescenceJet", "喷射时间", "jet_seconds", 0.75, 0.01, 0.3, 1.5, "%.2f")
	drag(group, "QingRemasterOptions_IncandescenceOrangeFrac", "橙色主体宽度比例", "orange_frac", 0.78, 0.01, 0.62, 0.90, "%.2f")
	drag(group, "QingRemasterOptions_IncandescenceGoldFrac", "金黄色内焰宽度比例", "gold_frac", 0.47, 0.01, 0.28, 0.62, "%.2f")
	drag(group, "QingRemasterOptions_IncandescenceWhiteFrac", "浅黄色火心宽度比例", "white_frac", 0.09, 0.01, 0.03, 0.16, "%.2f")
	drag(group, "QingRemasterOptions_IncandescenceFrontReach", "外焰前伸强度", "front_reach", 1, 0.01, 0, 2, "%.2f")
	drag(group, "QingRemasterOptions_IncandescenceFrontBloom", "前缘膨胀强度", "front_bloom", 1, 0.01, 0, 2, "%.2f")
	drag(group, "QingRemasterOptions_IncandescenceFrontAsym", "上下前缘不对称", "front_asym", 0.35, 0.01, 0, 1, "%.2f")
	drag(group, "QingRemasterOptions_IncandescenceLayerWave", "热层局部扰动", "layer_wave", 1, 0.01, 0, 2, "%.2f")
	drag(group, "QingRemasterOptions_IncandescenceLayerMargin", "色带间距", "layer_margin", 1.5, 0.05, 0, 4, "%.2f")
	drag(group, "QingRemasterOptions_IncandescenceOrbRate", "粒子密度", "orb_rate", 3, 1, 0, 12, "%.0f")
	drag(group, "QingRemasterOptions_IncandescenceOrbLarge", "大火球比例", "orb_large", 0.18, 0.01, 0, 0.6, "%.2f")
	drag(group, "QingRemasterOptions_IncandescenceFrontScatter", "前缘逸散倍率", "front_scatter", 1.4, 0.01, 0, 3, "%.2f")
	drag(group, "QingRemasterOptions_IncandescenceEdgeScatter", "外边缘逸散倍率", "edge_scatter", 1.6, 0.01, 0, 3, "%.2f")
	drag(group, "QingRemasterOptions_IncandescenceOrbLife", "粒子寿命倍率", "orb_life", 1, 0.01, 0.4, 2, "%.2f")
	drag(group, "QingRemasterOptions_IncandescenceBirthDepth", "粒子出生深度", "birth_depth", 10, 0.1, 2, 28, "%.1f")
	drag(group, "QingRemasterOptions_IncandescenceEmerge", "脱离时间", "emerge_frames", 6, 1, 2, 12, "%.0f")
	drag(group, "QingRemasterOptions_IncandescenceOrbScale", "粒子尺寸倍率", "orb_scale", 1, 0.01, 0.5, 2, "%.2f")
	drag(group, "QingRemasterOptions_IncandescenceScanline", "扫描线高度", "scanline_height", 2, 1, 1, 4, "%.0f")
	drag(group, "QingRemasterOptions_IncandescenceRasterRows", "最大扫描行数", "max_raster_rows", 420, 1, 80, 1600, "%.0f")
	drag(group, "QingRemasterOptions_IncandescenceSpacing", "色域截面采样间距", "spacing", 5, 0.1, 3, 12, "%.1f")
	drag(group, "QingRemasterOptions_IncandescenceStreamCap", "最大历史流线样本", "stream_cap", 128, 1, 16, 128, "%.0f")
	drag(group, "QingRemasterOptions_IncandescenceEmberCap", "粒子总上限", "ember_cap", 62, 1, 4, 62, "%.0f")

	ImGui.AddButton(group, "QingRemasterOptions_IncandescenceRestore", "恢复默认", function()
		session.restore_defaults()
	end)
	ImGui.AddButton(group, "QingRemasterOptions_IncandescenceCopy", "复制参数", function()
		local cfg = session.config()
		local text = string.format(
			"length=%s half=%s flow=%s orange=%s gold=%s white=%s reach=%s bloom=%s asym=%s wave=%s orbs=%s static=%s",
			tostring(cfg.length),
			tostring(cfg.half_width),
			tostring(cfg.flow),
			tostring(cfg.orange_frac),
			tostring(cfg.gold_frac),
			tostring(cfg.white_frac),
			tostring(cfg.front_reach),
			tostring(cfg.front_bloom),
			tostring(cfg.front_asym),
			tostring(cfg.layer_wave),
			tostring(cfg.show_ember),
			tostring(cfg.static_solid)
		)
		if ImGui.SetClipboardText then
			ImGui.SetClipboardText(text)
		end
	end)
end

return ui
