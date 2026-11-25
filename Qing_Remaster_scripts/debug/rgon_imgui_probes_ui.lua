-- Probes ImGui builders (extracted from rgon_imgui_options_holder).
-- Must only use start_probe_module; never start_mod.

local M = {}

function M.build(api)
	local item = api.item
	local text = api.text
	local add_text = api.add_text
	local add_checkbox = api.add_checkbox
	local add_drag_float = api.add_drag_float
	local add_drag_pair_path = api.add_drag_pair_path
	local add_group = api.add_group
	local add_separator = api.add_separator
	local add_reset_button = api.add_reset_button
	local imgui_layout = api.imgui_layout
	local ImGui = api.ImGui
	local enums = api.enums
	local auxi = api.auxi
	local save = api.save
	local ModConfig = api.ModConfig
	local translations = api.translations
	local item_color_holder = api.item_color_holder
	local achievement_tracker = api.achievement_tracker
	local CompletionMarks = api.CompletionMarks
	local unlock_board = api.unlock_board
	local dev_env = api.dev_env
	local probe_registry = api.probe_registry
	local push_notice = api.push_notice
	local error_notice_type = api.error_notice_type
	local language_key = api.language_key
	local setup_window = api.setup_window
	local save_mod_data = api.save_mod_data
	local DEBUG_PAGE = api.DEBUG_PAGE
	local register_debug_module = api.register_debug_module
	local set_module_footer = api.set_module_footer
	local start_mod = api.start_mod
	local start_probe_module = api.start_probe_module
	local page_parent = api.page_parent
	local recent_tab = api.recent_tab
	local items_tab = api.items_tab
	local characters_tab = api.characters_tab
	local systems_tab = api.systems_tab
	local visual_tab = api.visual_tab
	local data_tab = api.data_tab
	local story_test_tab = api.story_test_tab

	-- RGON AddDragFloat(parent, id, label, cb, default, speed, min, max, format).
	-- Never omit speed. See codex_work/notes/rgon_imgui_dragfloat_signature_pitfall.md
	-- While dragging: Edited applies live; skip Render→UpdateData so we don't
	-- rubber-band the widget back to the pre-drag getter every frame.
	local probe_drag_active = {}
	local function add_probe_drag(parent, id, label, setter, getter, default, speed, min_v, max_v, fmt)
		local function apply(value)
			if setter then setter(value) end
		end
		ImGui.AddDragFloat(
			parent,
			id,
			label,
			apply,
			default,
			speed,
			min_v,
			max_v,
			fmt or "%.0f"
		)
		ImGui.AddCallback(id, ImGuiCallback.Edited, function(value)
			probe_drag_active[id] = true
			apply(value)
		end)
		if ImGuiCallback.DeactivatedAfterEdit then
			ImGui.AddCallback(id, ImGuiCallback.DeactivatedAfterEdit, function()
				probe_drag_active[id] = nil
			end)
		end
		if ImGuiCallback.Deactivated then
			ImGui.AddCallback(id, ImGuiCallback.Deactivated, function()
				probe_drag_active[id] = nil
			end)
		end
		ImGui.AddCallback(id, ImGuiCallback.Render, function()
			if probe_drag_active[id] then
				return
			end
			local v = getter and getter() or default
			ImGui.UpdateData(id, ImGuiData.Value, tonumber(v) or default or 0)
		end)
	end

local function add_attack_audit_group(group)
	if not group then return end
	local function probe_mod()
		return dev_env.require_probe("Qing_Remaster_scripts.others.attack_audit_probe")
	end
	local function refresh_status()
		local mod = probe_mod()
		local body = (mod and mod.get_summary and mod.get_summary()) or "Attack Audit unavailable"
		imgui_layout.update_text("QingRemasterOptions_AttackAuditStatus", body)
	end
	add_text(group, "Attack Holder audit. Overlay + in-memory Events; Export writes codex_work/logs. No save writes.")
	imgui_layout.add_wrapped_text(group, "QingRemasterOptions_AttackAuditStatus", "Attack Audit 关闭")
	ImGui.AddCallback("QingRemasterOptions_AttackAuditStatus", ImGuiCallback.Render, refresh_status)

	local enable_id = "QingRemasterOptions_AttackAuditEnabled"
	ImGui.AddCheckbox(group, enable_id, "Enabled", nil, false)
	ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
		local mod = probe_mod()
		local on = mod and mod.get_config and mod.get_config().enabled == true
		ImGui.UpdateData(enable_id, ImGuiData.Value, on == true)
	end)
	ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
		local mod = probe_mod()
		if mod and mod.set_enabled then mod.set_enabled(value == true) end
	end)
	ImGui.AddElement(group, "", ImGuiElement.SameLine)
	local overlay_id = "QingRemasterOptions_AttackAuditOverlay"
	ImGui.AddCheckbox(group, overlay_id, "Overlay", nil, false)
	ImGui.AddCallback(overlay_id, ImGuiCallback.Render, function()
		local mod = probe_mod()
		local on = mod and mod.get_config and mod.get_config().overlay == true
		ImGui.UpdateData(overlay_id, ImGuiData.Value, on == true)
	end)
	ImGui.AddCallback(overlay_id, ImGuiCallback.Edited, function(value)
		local mod = probe_mod()
		if mod and mod.set_overlay then mod.set_overlay(value == true) end
	end)
	ImGui.AddElement(group, "", ImGuiElement.SameLine)
	local rec_id = "QingRemasterOptions_AttackAuditRecording"
	ImGui.AddCheckbox(group, rec_id, "Recording", nil, false)
	ImGui.AddCallback(rec_id, ImGuiCallback.Render, function()
		local mod = probe_mod()
		local on = mod and mod.get_config and mod.get_config().recording == true
		ImGui.UpdateData(rec_id, ImGuiData.Value, on == true)
	end)
	ImGui.AddCallback(rec_id, ImGuiCallback.Edited, function(value)
		local mod = probe_mod()
		if mod and mod.set_recording then mod.set_recording(value == true) end
	end)

	local overlay_sec = imgui_layout.add_section(group, "QingRemasterOptions_AttackAuditOverlaySec", "Overlay")
	local function flag_checkbox(parent, id, label, key)
		ImGui.AddCheckbox(parent, id, label, nil, false)
		ImGui.AddCallback(id, ImGuiCallback.Render, function()
			local mod = probe_mod()
			local cfg = mod and mod.get_config and mod.get_config() or {}
			ImGui.UpdateData(id, ImGuiData.Value, cfg[key] == true)
		end)
		ImGui.AddCallback(id, ImGuiCallback.Edited, function(value)
			local mod = probe_mod()
			if mod and mod.set_flag then mod.set_flag(key, value == true) end
		end)
	end
	flag_checkbox(overlay_sec, "QingRemasterOptions_AttackAuditLabels", "Labels", "labels")
	ImGui.AddElement(overlay_sec, "", ImGuiElement.SameLine)
	flag_checkbox(overlay_sec, "QingRemasterOptions_AttackAuditTags", "Show Tags (G)", "show_tags")
	ImGui.AddElement(overlay_sec, "", ImGuiElement.SameLine)
	flag_checkbox(overlay_sec, "QingRemasterOptions_AttackAuditSource", "Show Source", "show_source")
	flag_checkbox(overlay_sec, "QingRemasterOptions_AttackAuditLinks", "Group Links", "group_links")

	local capture_sec = imgui_layout.add_section(group, "QingRemasterOptions_AttackAuditCaptureSec", "Capture")
	imgui_layout.add_action_row(capture_sec, {
		{id = "QingRemasterOptions_AttackAuditCapSummary", label = "Summary", on_click = function()
			local mod = probe_mod()
			if mod and mod.set_capture then mod.set_capture("summary") end
		end},
		{id = "QingRemasterOptions_AttackAuditCapEvents", label = "Events", on_click = function()
			local mod = probe_mod()
			if mod and mod.set_capture then mod.set_capture("events") end
		end},
		{id = "QingRemasterOptions_AttackAuditCapDeep", label = "Deep", on_click = function()
			local mod = probe_mod()
			if mod and mod.set_capture then mod.set_capture("deep") end
		end},
	})
	local focus_id = "QingRemasterOptions_AttackAuditFocus"
	ImGui.AddDragFloat(capture_sec, focus_id, "Focus Attack ID (0=all)", function(value)
		local mod = probe_mod()
		if mod and mod.set_focus_id then mod.set_focus_id(value) end
	end, 1, 0, 0, 99999, "%.0f")
	ImGui.AddCallback(focus_id, ImGuiCallback.Render, function()
		local mod = probe_mod()
		local cfg = mod and mod.get_config and mod.get_config() or {}
		ImGui.UpdateData(focus_id, ImGuiData.Value, tonumber(cfg.focus_id) or 0)
	end)
	flag_checkbox(capture_sec, "QingRemasterOptions_AttackAuditRecent", "Recently Ended", "recent_ended")
	ImGui.AddElement(capture_sec, "", ImGuiElement.SameLine)
	flag_checkbox(capture_sec, "QingRemasterOptions_AttackAuditOpenPanel", "Open Attack Panel", "open_panel")

	local adv_sec = imgui_layout.add_section(group, "QingRemasterOptions_AttackAuditAdvSec", "Advanced")
	flag_checkbox(adv_sec, "QingRemasterOptions_AttackAuditVerbose", "Verbose Labels", "verbose")
	ImGui.AddElement(adv_sec, "", ImGuiElement.SameLine)
	flag_checkbox(adv_sec, "QingRemasterOptions_AttackAuditMeasure", "Measure Maintenance Cost", "measure_maintenance")

	local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
	probe_output.add_probe_output_controls(group, probe_mod, {
		id_prefix = "QingRemasterOptions_AttackAuditOut",
		export_label = "Export JSONL",
	})
	ImGui.AddButton(group, "QingRemasterOptions_AttackAuditExportSummary", "Export Summary", function()
		local mod = probe_mod()
		if mod and mod.export_summary then mod.export_summary() end
	end)
	ImGui.AddElement(group, "", ImGuiElement.SameLine)
	ImGui.AddButton(group, "QingRemasterOptions_AttackAuditExportDisable", "Export & Disable", function()
		local mod = probe_mod()
		if mod and mod.export_and_disable then mod.export_and_disable() end
	end)
	ImGui.AddElement(group, "", ImGuiElement.SameLine)
	ImGui.AddButton(group, "QingRemasterOptions_AttackAuditDisable", "Disable all", function()
		local mod = probe_mod()
		if mod and mod.disable_all then mod.disable_all() end
	end)
end


	local incandescence_flame_group = start_probe_module(
		"audit_incandescence_flame",
		"焚火视觉探针",
		"QingRemasterOptions_GroupIncandescenceFlameProbe"
	)
	if incandescence_flame_group then
		local flame_probe = dev_env.require_probe("Qing_Remaster_scripts.debug.incandescence_flame_probe")
		if flame_probe and flame_probe.install_ui then
			flame_probe.install_ui(incandescence_flame_group, add_text)
		end
	end

	local seeker_wall_probe_group = start_probe_module("item_seeker_wall_probe", text("group_seeker_wall_probe"), "QingRemasterOptions_GroupSeekerWallProbe")
	do
		local status_id = "QingRemasterOptions_SeekerWallProbeStatus"
		local function seeker_mod()
			local ok, mod = pcall(require, "Qing_Remaster_scripts.items.Item_Seeker_s_Eye")
			if ok then return mod end
			return nil
		end
		local function refresh_status()
			local mod = seeker_mod()
			local body = (mod and mod.get_wall_probe_summary and mod.get_wall_probe_summary()) or text("seeker_wall_probe_status")
			imgui_layout.update_text(status_id, body)
		end
		add_text(seeker_wall_probe_group, text("seeker_wall_probe_help"))
		imgui_layout.add_wrapped_text(seeker_wall_probe_group, status_id, text("seeker_wall_probe_status"))
		local enable_id = "QingRemasterOptions_SeekerWallProbeEnable"
		ImGui.AddCheckbox(seeker_wall_probe_group, enable_id, text("seeker_wall_probe_enable"), nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local mod = seeker_mod()
			local on = mod and mod.wall_probe_enabled == true
			ImGui.UpdateData(enable_id, ImGuiData.Value, on == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local mod = seeker_mod()
			if mod and mod.set_wall_probe_enabled then mod.set_wall_probe_enabled(value == true) end
			refresh_status()
		end)
		ImGui.AddButton(seeker_wall_probe_group, "QingRemasterOptions_SeekerWallProbeRefresh", text("seeker_wall_probe_export"), refresh_status)
		ImGui.AddButton(seeker_wall_probe_group, "QingRemasterOptions_SeekerWallProbeClear", text("seeker_wall_probe_clear"), function()
			local mod = seeker_mod()
			if mod and mod.clear_wall_probe then mod.clear_wall_probe() end
			refresh_status()
		end)
		ImGui.AddButton(seeker_wall_probe_group, "QingRemasterOptions_SeekerWallProbeRestore", text("restore_item_defaults"), function()
			local mod = seeker_mod()
			if mod and mod.set_wall_probe_enabled then mod.set_wall_probe_enabled(false) end
			if mod and mod.clear_wall_probe then mod.clear_wall_probe() end
			refresh_status()
		end)
	end
	do
		local anna_range_group = start_probe_module(
			"audit_anna_attack_range",
			"里安娜攻击范围",
			"QingRemasterOptions_GroupAnnaAttackRange"
		)
		if anna_range_group then
			local live = require("Qing_Remaster_scripts.debug.probe_live_cache")
			local function anna_probe()
				return dev_env.require_probe("Qing_Remaster_scripts.debug.anna_attack_range_probe")
			end
			add_text(anna_range_group, "环不继承角色或幻影的动画 Scale。两项射程系数都以 260 为参考射程：0 表示射程不影响大小，1 表示按 √(当前射程 / 260) 缩放。判定半径 = 实际判定大小 × 武器 rangerate × 射程倍率；角色射程增量通过属性缓存写入。测试参数仅在探针启用时生效。")
			if ImGui.AddInputFloat then
				local controls = {
					{"ring_base_scale", "环基础大小比例", 1, 0, 3},
					{"ring_range_scale", "射程对环的放缩比例", 1, 0, 2},
					{"range_delta", "角色射程增量", 0, -300, 600},
					{"hit_base_size", "实际判定大小", 50, 0, 200},
					{"hit_range_scale", "射程对判定大小的放缩比例", 1, 0, 3},
				}
				for _, control in ipairs(controls) do
					local key, label, initial = control[1], control[2], control[3]
					local id = "QingRemasterOptions_AnnaAttackRange_" .. key
					ImGui.AddInputFloat(anna_range_group, id, label, function(value)
						local p = anna_probe()
						if p and p.set_tuning then p.set_tuning(key, value) end
					end, initial, key == "range_delta" and 10 or 0.1, key == "range_delta" and 100 or 1)
				end
			end
			ImGui.AddButton(anna_range_group, "QingRemasterOptions_AnnaAttackRangeResetTuning", "重置范围参数", function()
				local p = anna_probe()
				if p and p.reset_tuning then
					p.reset_tuning()
					for key, value in pairs(p.get_tuning()) do
						ImGui.UpdateData("QingRemasterOptions_AnnaAttackRange_" .. key, ImGuiData.Value, value)
					end
				end
			end)
			add_text(anna_range_group, "只在里安娜 anna_attack 真正结算时画本次攻击圆。青色是判定圆心和半径。洋红十字是 params.pos，只有它和判定圆心分开时才出现。绿色敌人圆是旧中心点规则和新碰撞圆都会命中；黄色是只有算上 Size 才命中；红色是未命中。轮廓保留 18 个游戏帧。记录会一直留着，Copy Full Report 包含本段开启后的每一次攻击。默认关闭。")
			local status_id = "QingRemasterOptions_AnnaAttackRangeStatus"
			imgui_layout.add_wrapped_text(anna_range_group, status_id, "off")
			local enable_id = "QingRemasterOptions_AnnaAttackRangeEnable"
			ImGui.AddCheckbox(anna_range_group, enable_id, "启用里安娜攻击范围", nil, false)
			ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
				local p = anna_probe()
				live.update_checkbox_if_changed(enable_id, p and p.is_enabled and p.is_enabled() == true)
				imgui_layout.update_text(status_id, (p and p.get_summary and p.get_summary()) or "off")
			end)
			ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
				local p = anna_probe()
				if p and p.set_enabled then p.set_enabled(value == true) end
			end)
			ImGui.AddButton(anna_range_group, "QingRemasterOptions_AnnaAttackRangeCopy", "Copy Summary", function()
				local p = anna_probe()
				if p and p.copy_summary then p.copy_summary() end
			end)
			ImGui.AddElement(anna_range_group, "", ImGuiElement.SameLine)
			ImGui.AddButton(anna_range_group, "QingRemasterOptions_AnnaAttackRangeFull", "Copy Full Report", function()
				local p = anna_probe()
				if p and p.copy_full_report then p.copy_full_report() end
			end)
			ImGui.AddButton(anna_range_group, "QingRemasterOptions_AnnaAttackRangeClear", "清空", function()
				local p = anna_probe()
				if p and p.clear then p.clear() end
			end)
			ImGui.AddElement(anna_range_group, "", ImGuiElement.SameLine)
			ImGui.AddButton(anna_range_group, "QingRemasterOptions_AnnaAttackRangeExport", "Export", function()
				local p = anna_probe()
				if p and p.export then p.export() end
			end)
		end
	end
	do
		local attack_audit_group = start_probe_module("audit_attack_audit", "Attack Audit", "QingRemasterOptions_GroupAttackAudit")
		add_attack_audit_group(attack_audit_group)
	end

	local player_identity_group = start_probe_module(
		"audit_player_identity",
		"玩家身份识别",
		"QingRemasterOptions_GroupPlayerIdentity"
	)
	if player_identity_group then
	do
		local live = require("Qing_Remaster_scripts.debug.probe_live_cache")
		local function id_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.player_identity_probe")
		end
		add_text(
			player_identity_group,
			"三层对照：实体分类模拟（Variant/BabySkin/auxi/双生）· 引擎身份（RGON index/Controller/Seed）· 模组 __Index。不改匹配规则。keep_existing_index 已边沿去重。"
		)
		local enable_id = "QingRemasterOptions_PlayerIdentityEnabled"
		ImGui.AddCheckbox(player_identity_group, enable_id, "启用玩家身份探针", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = id_probe()
			live.update_checkbox_if_changed(enable_id, p and p.is_enabled and p.is_enabled() == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = id_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		local overlay_id = "QingRemasterOptions_PlayerIdentityOverlay"
		ImGui.AddCheckbox(player_identity_group, overlay_id, "在玩家头顶显示 ID", nil, true)
		ImGui.AddCallback(overlay_id, ImGuiCallback.Render, function()
			local p = id_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			live.update_checkbox_if_changed(overlay_id, cfg.overlay == true)
		end)
		ImGui.AddCallback(overlay_id, ImGuiCallback.Edited, function(value)
			local p = id_probe()
			if p and p.set_overlay then p.set_overlay(value == true) end
		end)
		local class_id = "QingRemasterOptions_PlayerIdentityShowClass"
		ImGui.AddCheckbox(player_identity_group, class_id, "头顶显示分类模拟（FS?/SM?/…）", nil, true)
		ImGui.AddCallback(class_id, ImGuiCallback.Render, function()
			local p = id_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			live.update_checkbox_if_changed(class_id, cfg.show_class ~= false)
		end)
		ImGui.AddCallback(class_id, ImGuiCallback.Edited, function(value)
			local p = id_probe()
			if p and p.set_show_class then p.set_show_class(value == true) end
		end)
		local seed_id = "QingRemasterOptions_PlayerIdentityShowSeed"
		ImGui.AddCheckbox(player_identity_group, seed_id, "头顶显示详细 Seed 信息", nil, false)
		ImGui.AddCallback(seed_id, ImGuiCallback.Render, function()
			local p = id_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			live.update_checkbox_if_changed(seed_id, cfg.show_seed == true)
		end)
		ImGui.AddCallback(seed_id, ImGuiCallback.Edited, function(value)
			local p = id_probe()
			if p and p.set_show_seed then p.set_show_seed(value == true) end
		end)
		local rec_id = "QingRemasterOptions_PlayerIdentityRecord"
		ImGui.AddCheckbox(player_identity_group, rec_id, "记录身份变化事件", nil, true)
		ImGui.AddCallback(rec_id, ImGuiCallback.Render, function()
			local p = id_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			live.update_checkbox_if_changed(rec_id, cfg.record_events ~= false)
		end)
		ImGui.AddCallback(rec_id, ImGuiCallback.Edited, function(value)
			local p = id_probe()
			if p and p.set_record_events then p.set_record_events(value == true) end
		end)
		ImGui.AddButton(player_identity_group, "QingRemasterOptions_PlayerIdentityClear", "Clear Events", function()
			local p = id_probe(); if p and p.clear then p.clear() end
		end)
		local status_id = "QingRemasterOptions_PlayerIdentityStatus"
		imgui_layout.add_wrapped_text(player_identity_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = id_probe()
			local text_body = p and p.status_text and p.status_text() or "idle"
			ImGui.UpdateData(status_id, ImGuiData.Label, text_body)
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(player_identity_group, id_probe, {
			id_prefix = "QingRemasterOptions_PlayerIdentityOut",
			export_label = "Export JSONL",
		})
	end
	end

	local attribute_group = start_probe_module("audit_attribute_holder", "属性裁断器探针", "QingRemasterOptions_GroupAttributeHolder")
	do
		add_text(attribute_group, "默认关闭。启用后仅展示活动委托计数；自检按钮使用假实体核对嵌套释放、动态值、外部改值和 getter/setter，不写文件、不扫描房间实体。")
		local enable_id = "QingRemasterOptions_AttributeHolderProbeEnabled"
		ImGui.AddCheckbox(attribute_group, enable_id, "启用实时状态", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local holder = require("Qing_Remaster_scripts.others.Attribute_holder")
			ImGui.UpdateData(enable_id, ImGuiData.Value, holder.debug.probe_enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local holder = require("Qing_Remaster_scripts.others.Attribute_holder")
			holder.debug.probe_enabled = value == true
		end)
		ImGui.AddButton(attribute_group, "QingRemasterOptions_AttributeHolderRun", "运行一次复杂场景自检", function()
			require("Qing_Remaster_scripts.others.Attribute_holder").run_self_test()
		end)
		local status_id = "QingRemasterOptions_AttributeHolderStatus"
		imgui_layout.add_wrapped_text(attribute_group, status_id, "探针关闭；尚未自检。")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local holder = require("Qing_Remaster_scripts.others.Attribute_holder")
			local report = holder.debug.last_report
			local body = holder.debug.probe_enabled and "实时状态已开启" or "实时状态已关闭"
			if holder.debug.probe_enabled then
				local s = holder.get_debug_stats()
				body = body .. string.format("\n实体=%d binder=%d 属性=%d 委托=%d 错误=%d", s.entities,s.binders,s.attrs,s.claims,s.errors)
			end
			if report then
				body = body .. string.format("\n最近自检：%d/%d 通过，frame=%d",report.passed,report.total,report.frame)
				if #report.failures > 0 then body = body .. "\n失败：" .. table.concat(report.failures, ", ") end
			else body = body .. "\n尚未运行自检。" end
			imgui_layout.update_text(status_id, body)
		end)
		ImGui.AddButton(attribute_group, "QingRemasterOptions_AttributeHolderReset", "关闭并清除探针结果", function()
			local holder = require("Qing_Remaster_scripts.others.Attribute_holder")
			holder.debug.probe_enabled = false; holder.debug.last_report = nil
		end)
	end
local runtime_stitch_group = start_probe_module("audit_runtime_stitch", "Sprite Splice / Runtime Stitch 基础设施", "QingRemasterOptions_GroupRuntimeStitchProbe")
	if runtime_stitch_group then
	do
		add_text(runtime_stitch_group, "底层 sprite_splice / Gate1～Gate3D 验证。缝合针玩法请用「缝合针」探针。默认关闭。见 runtime_stitch_gates.md。")
		local enable_id = "QingRemasterOptions_RuntimeStitchProbeEnabled"
		ImGui.AddCheckbox(runtime_stitch_group, enable_id, "启用基础设施探针", nil, false)
		local function get_stitch_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.others.runtime_stitch_test_probe")
		end
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local probe = get_stitch_probe()
			local cfg = probe and probe.get_config and probe.get_config() or {enabled = false}
			ImGui.UpdateData(enable_id, ImGuiData.Value, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local probe = get_stitch_probe()
			if probe and probe.set_enabled then probe.set_enabled(value == true) end
		end)
		local status_id = "QingRemasterOptions_RuntimeStitchProbeStatus"
		imgui_layout.add_wrapped_text(runtime_stitch_group, status_id, "探针关闭。")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local probe = get_stitch_probe()
			imgui_layout.update_text(status_id, (probe and probe.get_summary and probe.get_summary()) or "开发探针不可用。")
		end)
		local angle_id = "QingRemasterOptions_RuntimeStitchCutAngle"
		ImGui.AddDragFloat(runtime_stitch_group, angle_id, "裁切角(度)", function(value)
			local probe = get_stitch_probe()
			if probe and probe.set_cut_angle then probe.set_cut_angle(value) end
		end, 0, 5, -180, 180, "%.0f")
		ImGui.AddCallback(angle_id, ImGuiCallback.Render, function()
			local probe = get_stitch_probe()
			local cfg = probe and probe.get_config and probe.get_config() or {}
			ImGui.UpdateData(angle_id, ImGuiData.Value, tonumber(cfg.cut_angle_deg) or 0)
		end)
		ImGui.AddButton(runtime_stitch_group, "QingRemasterOptions_RuntimeStitchGate1", "Gate1 挂接（无裁切）", function()
			local probe = get_stitch_probe()
			if probe and probe.attach_gate1 then probe.attach_gate1() end
		end)
		ImGui.AddButton(runtime_stitch_group, "QingRemasterOptions_RuntimeStitchGate2", "Gate2 挂接（动态裁切）", function()
			local probe = get_stitch_probe()
			if probe and probe.attach_gate2 then probe.attach_gate2() end
		end)
		ImGui.AddButton(runtime_stitch_group, "QingRemasterOptions_RuntimeStitchGate25", "Gate2.5 缝器官（边缘+front）", function()
			local probe = get_stitch_probe()
			if probe and probe.attach_gate2_5 then probe.attach_gate2_5() end
		end)
		ImGui.AddButton(runtime_stitch_group, "QingRemasterOptions_RuntimeStitchGate3A", "Gate3A 染色验证（应发绿）", function()
			local probe = get_stitch_probe()
			if probe and probe.attach_gate3a then probe.attach_gate3a() end
		end)
		ImGui.AddButton(runtime_stitch_group, "QingRemasterOptions_RuntimeStitchGate3ABlank", "Gate3A 空白验证（应变消失）", function()
			local probe = get_stitch_probe()
			if probe and probe.attach_gate3a_blank then probe.attach_gate3a_blank() end
		end)
		ImGui.AddButton(runtime_stitch_group, "QingRemasterOptions_RuntimeStitchGate3AMatch", "Gate3A 原样回贴（+标记）", function()
			local probe = get_stitch_probe()
			if probe and probe.attach_gate3a_match then probe.attach_gate3a_match() end
		end)
		ImGui.AddButton(runtime_stitch_group, "QingRemasterOptions_RuntimeStitchGate3B", "Gate3B Host 裁半（无 donor）", function()
			local probe = get_stitch_probe()
			if probe and probe.attach_gate3b then probe.attach_gate3b() end
		end)
		ImGui.AddButton(runtime_stitch_group, "QingRemasterOptions_RuntimeStitchGate3C", "Gate3C Host+Fly 互补拼接", function()
			local probe = get_stitch_probe()
			if probe and probe.attach_gate3c then probe.attach_gate3c() end
		end)
		ImGui.AddButton(runtime_stitch_group, "QingRemasterOptions_RuntimeStitchGate3D", "Gate3D 诊断模式（非 PASS）", function()
			local probe = get_stitch_probe()
			if probe and probe.attach_gate3d then probe.attach_gate3d() end
		end)
		ImGui.AddButton(runtime_stitch_group, "QingRemasterOptions_RuntimeStitchGate3DDiag", "导出 Gate3D 诊断（RT/层/残差）", function()
			local probe = get_stitch_probe()
			if probe and probe.export_gate3d_diagnostics then probe.export_gate3d_diagnostics() end
		end)
		ImGui.AddButton(runtime_stitch_group, "QingRemasterOptions_RuntimeStitchGate3AExport", "导出 Gate3A 快照 JSON", function()
			local probe = get_stitch_probe()
			if probe and probe.export_gate3a then probe.export_gate3a() end
		end)

		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(runtime_stitch_group, get_stitch_probe, {
			id_prefix = "QingRemasterOptions_RuntimeStitchOut",
			export_label = "Export Status JSON",
			clear_label = "Clear grafts/takeovers",
		})
	end
	end

	local suture_needle_probe_group = start_probe_module("audit_suture_needle", "缝合针", "QingRemasterOptions_GroupSutureNeedleProbe")
	if suture_needle_probe_group then
	do
		add_text(suture_needle_probe_group, "缝合针运行时测试。常规使用只需「生成缝合体」与「Linker 正常致死」；其余诊断按模块展开。默认关闭。")
		local function get_suture_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.others.suture_needle_probe")
		end

		-- 1) 基础测试
		local base_sec = imgui_layout.add_section(suture_needle_probe_group, "QingRemasterOptions_SutureNeedleBaseSec", "基础测试")
		local suture_probe_path = "Qing_Remaster_scripts.others.suture_needle_probe"
		local enable_id = "QingRemasterOptions_SutureNeedleProbeEnabled"
		ImGui.AddCheckbox(base_sec, enable_id, "启用缝合针探针", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local probe = get_suture_probe()
			local cfg = probe and probe.get_config and probe.get_config() or {enabled = false}
			ImGui.UpdateData(enable_id, ImGuiData.Value, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local probe = get_suture_probe()
			if probe and probe.set_enabled then probe.set_enabled(value == true) end
		end)

		local move_combo = "QingRemasterOptions_SutureNeedleMoveCombo"
		local atk_combo = "QingRemasterOptions_SutureNeedleAtkCombo"
		ImGui.AddCombobox(base_sec, move_combo, "移动类型", function(index)
			local probe = get_suture_probe()
			if probe and probe.set_move_index then probe.set_move_index(index) end
		end, {"追逐", "冲锋", "游荡"}, 0)
		ImGui.AddCallback(move_combo, ImGuiCallback.Render, function()
			local probe = get_suture_probe()
			local opts = (probe and probe.get_move_options and probe.get_move_options()) or {"追逐", "冲锋", "游荡"}
			ImGui.UpdateData(move_combo, ImGuiData.ListValues, opts)
			ImGui.UpdateData(move_combo, ImGuiData.Value, (probe and probe.get_move_index and probe.get_move_index()) or 0)
		end)
		ImGui.AddCombobox(base_sec, atk_combo, "攻击类型", function(index)
			local probe = get_suture_probe()
			if probe and probe.set_attack_index then probe.set_attack_index(index) end
		end, {"单发", "连射", "散射"}, 0)
		ImGui.AddCallback(atk_combo, ImGuiCallback.Render, function()
			local probe = get_suture_probe()
			local opts = (probe and probe.get_attack_options and probe.get_attack_options()) or {"单发", "连射", "散射"}
			ImGui.UpdateData(atk_combo, ImGuiData.ListValues, opts)
			ImGui.UpdateData(atk_combo, ImGuiData.Value, (probe and probe.get_attack_index and probe.get_attack_index()) or 0)
		end)

		imgui_layout.add_action_row(base_sec, {
			{id = "QingRemasterOptions_SutureNeedleSpawn", label = "生成缝合体", on_click = function()
				local p = get_suture_probe(); if p and p.spawn_selected then p.spawn_selected() end
			end},
		})
		imgui_layout.add_action_row(base_sec, {
			{id = "QingRemasterOptions_SutureNeedleClear", label = "清除缝合体", on_click = function()
				local p = get_suture_probe(); if p and p.clear_pairs then p.clear_pairs() end
			end},
		})
		imgui_layout.add_action_row(base_sec, {
			{id = "QingRemasterOptions_SutureNeedleCopySnapshot", label = "复制当前状态", on_click = function()
				local p = get_suture_probe(); if p and p.copy_snapshot then p.copy_snapshot() end
			end},
		})

		local status_id = "QingRemasterOptions_SutureNeedleStatus"
		imgui_layout.add_wrapped_text(base_sec, status_id, "探针关闭。")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local probe = get_suture_probe()
			if not probe then
				imgui_layout.update_text(
					status_id,
					dev_env.format_probe_unavailable
						and dev_env.format_probe_unavailable(suture_probe_path)
						or "开发探针不可用。"
				)
				return
			end
			imgui_layout.update_text(status_id, (probe.get_status_text and probe.get_status_text()) or "开发探针不可用。")
		end)

		-- 2) 生命 / 死亡（正式 Linker 致死链）
		local death_sec = imgui_layout.add_section(suture_needle_probe_group, "QingRemasterOptions_SutureNeedleDeathSec", "生命 / 死亡")
		local death_status_id = "QingRemasterOptions_SutureNeedleDeathStatus"
		imgui_layout.add_wrapped_text(death_sec, death_status_id, "尚未捕获死亡链。")
		ImGui.AddCallback(death_status_id, ImGuiCallback.Render, function()
			local probe = get_suture_probe()
			if not probe then
				imgui_layout.update_text(
					death_status_id,
					dev_env.format_probe_unavailable
						and dev_env.format_probe_unavailable(suture_probe_path)
						or "开发探针不可用。"
				)
				return
			end
			imgui_layout.update_text(
				death_status_id,
				(probe.get_death_status_text and probe.get_death_status_text()) or "开发探针不可用。"
			)
		end)
		imgui_layout.add_action_row(death_sec, {
			{id = "QingRemasterOptions_SutureNeedleLinkerLethal", label = "Linker 正常致死", on_click = function()
				local p = get_suture_probe(); if p and p.test_linker_lethal_normal then p.test_linker_lethal_normal() end
			end},
		})
		imgui_layout.add_action_row(death_sec, {
			{id = "QingRemasterOptions_SutureNeedleSplitVerify", label = "拆开并验证 Globin", on_click = function()
				local p = get_suture_probe(); if p and p.split_and_verify_globin then p.split_and_verify_globin() end
			end},
		})
		imgui_layout.add_action_row(death_sec, {
			{id = "QingRemasterOptions_SutureNeedleCopyDeath", label = "复制死亡链", on_click = function()
				local p = get_suture_probe(); if p and p.copy_native_death_trace then p.copy_native_death_trace() end
			end},
			{id = "QingRemasterOptions_SutureNeedleClearDeath", label = "清空死亡记录", on_click = function()
				local p = get_suture_probe(); if p and p.clear_native_death_trace then p.clear_native_death_trace() end
			end},
		})

		-- 3) Geometry / Visual
		local geom_sec = imgui_layout.add_section(suture_needle_probe_group, "QingRemasterOptions_SutureNeedleGeomSec", "Geometry / Visual")
		local charm_filter_id = "QingRemasterOptions_SutureNeedleCharmFilter"
		ImGui.AddCheckbox(geom_sec, charm_filter_id, "清理魅惑爱心（Charm Pixel Filter）", nil, true)
		ImGui.AddCallback(charm_filter_id, ImGuiCallback.Render, function()
			local probe = get_suture_probe()
			local on = probe and probe.is_charm_pixel_filter_on and probe.is_charm_pixel_filter_on()
			ImGui.UpdateData(charm_filter_id, ImGuiData.Value, on ~= false)
		end)
		ImGui.AddCallback(charm_filter_id, ImGuiCallback.Edited, function(value)
			local probe = get_suture_probe()
			if probe and probe.set_charm_pixel_filter then probe.set_charm_pixel_filter(value == true) end
		end)

		local dis_cap_id = "QingRemasterOptions_SutureNeedleDisableRuntimeCapture"
		ImGui.AddCheckbox(geom_sec, dis_cap_id, "A/B：禁用 Runtime Capture（只画旧解）", nil, false)
		ImGui.AddCallback(dis_cap_id, ImGuiCallback.Render, function()
			local probe = get_suture_probe()
			local on = probe and probe.get_disable_runtime_capture and probe.get_disable_runtime_capture()
			ImGui.UpdateData(dis_cap_id, ImGuiData.Value, on == true)
		end)
		ImGui.AddCallback(dis_cap_id, ImGuiCallback.Edited, function(value)
			local probe = get_suture_probe()
			if probe and probe.set_disable_runtime_capture then probe.set_disable_runtime_capture(value == true) end
		end)

		local dis_geom_id = "QingRemasterOptions_SutureNeedleDisableGeometryRefresh"
		ImGui.AddCheckbox(geom_sec, dis_geom_id, "A/B：禁用 Geometry Refresh（有解则跳过 solve）", nil, false)
		ImGui.AddCallback(dis_geom_id, ImGuiCallback.Render, function()
			local probe = get_suture_probe()
			local on = probe and probe.get_disable_geometry_refresh and probe.get_disable_geometry_refresh()
			ImGui.UpdateData(dis_geom_id, ImGuiData.Value, on == true)
		end)
		ImGui.AddCallback(dis_geom_id, ImGuiCallback.Edited, function(value)
			local probe = get_suture_probe()
			if probe and probe.set_disable_geometry_refresh then probe.set_disable_geometry_refresh(value == true) end
		end)

		local trace_id = "QingRemasterOptions_SutureNeedleGeomTrace"
		ImGui.AddCheckbox(geom_sec, trace_id, "记录几何数据", nil, false)
		ImGui.AddCallback(trace_id, ImGuiCallback.Render, function()
			local probe = get_suture_probe()
			local on = probe and probe.is_geometry_trace_on and probe.is_geometry_trace_on()
			ImGui.UpdateData(trace_id, ImGuiData.Value, on == true)
		end)
		ImGui.AddCallback(trace_id, ImGuiCallback.Edited, function(value)
			local probe = get_suture_probe()
			if probe and probe.set_geometry_trace then probe.set_geometry_trace(value == true) end
		end)

		local geom_status_id = "QingRemasterOptions_SutureNeedleGeomStatus"
		imgui_layout.add_wrapped_text(geom_sec, geom_status_id, "Geometry / Visual")
		ImGui.AddCallback(geom_status_id, ImGuiCallback.Render, function()
			local probe = get_suture_probe()
			imgui_layout.update_text(
				geom_status_id,
				(probe and probe.get_geometry_status_text and probe.get_geometry_status_text()) or "开发探针不可用。"
			)
		end)
		imgui_layout.add_action_row(geom_sec, {
			{id = "QingRemasterOptions_SutureNeedleCopyGeom", label = "复制几何链", on_click = function()
				local p = get_suture_probe(); if p and p.copy_geometry_trace then p.copy_geometry_trace() end
			end},
			{id = "QingRemasterOptions_SutureNeedleClearTrace", label = "清空几何链", on_click = function()
				local p = get_suture_probe(); if p and p.clear_geometry_trace then p.clear_geometry_trace() end
			end},
		})

		-- 4) 高级 Physics / Water
		local adv_sec = imgui_layout.add_section(suture_needle_probe_group, "QingRemasterOptions_SutureNeedleAdvSec", "高级 Physics / Water")
		local water_probe_id = "QingRemasterOptions_SutureNeedleWaterPassProbe"
		ImGui.AddCheckbox(adv_sec, water_probe_id, "水下 Pass 诊断（十字 + RenderMode 采样）", nil, false)
		ImGui.AddCallback(water_probe_id, ImGuiCallback.Render, function()
			local probe = get_suture_probe()
			local on = probe and probe.get_water_pass_probe and probe.get_water_pass_probe()
			ImGui.UpdateData(water_probe_id, ImGuiData.Value, on == true)
		end)
		ImGui.AddCallback(water_probe_id, ImGuiCallback.Edited, function(value)
			local probe = get_suture_probe()
			if probe and probe.set_water_pass_probe then probe.set_water_pass_probe(value == true) end
		end)

		local reflect_flip_combo = "QingRemasterOptions_SutureNeedleReflectFlipMode"
		ImGui.AddCombobox(adv_sec, reflect_flip_combo, "倒影 Flip 模式 A/B", function(index)
			local probe = get_suture_probe()
			if probe and probe.set_reflect_flip_mode then
				probe.set_reflect_flip_mode(index)
			end
		end, {"none", "destination", "source"}, 2)
		ImGui.AddCallback(reflect_flip_combo, ImGuiCallback.Render, function()
			local probe = get_suture_probe()
			local opts = (probe and probe.get_reflect_flip_mode_options and probe.get_reflect_flip_mode_options())
				or {"none", "destination", "source"}
			ImGui.UpdateData(reflect_flip_combo, ImGuiData.ListValues, opts)
			ImGui.UpdateData(
				reflect_flip_combo,
				ImGuiData.Value,
				(probe and probe.get_reflect_flip_mode and probe.get_reflect_flip_mode()) or 2
			)
		end)

		local adv_status_id = "QingRemasterOptions_SutureNeedleAdvStatus"
		imgui_layout.add_wrapped_text(adv_sec, adv_status_id, "Advanced")
		ImGui.AddCallback(adv_status_id, ImGuiCallback.Render, function()
			local probe = get_suture_probe()
			imgui_layout.update_text(
				adv_status_id,
				(probe and probe.get_advanced_status_text and probe.get_advanced_status_text()) or "开发探针不可用。"
			)
		end)
		imgui_layout.add_action_row(adv_sec, {
			{id = "QingRemasterOptions_SutureNeedleCopyPhysics", label = "复制 Physics", on_click = function()
				local p = get_suture_probe(); if p and p.copy_physics_trace then p.copy_physics_trace() end
			end},
		})
	end
	end

	local native_sprite_cmp_group = start_probe_module("audit_native_sprite_render_compare", "Native Sprite Render 对比", "QingRemasterOptions_GroupNativeSpriteCmp")
	if native_sprite_cmp_group then
	do
		add_text(native_sprite_cmp_group, "Native Entity Capture：PRE 抑制自动出屏；POST 主动 Entity:Render→RT。entity_render=正式；sprite_render=对照。默认关闭。")
		local enable_id = "QingRemasterOptions_NativeSpriteCmpEnabled"
		ImGui.AddCheckbox(native_sprite_cmp_group, enable_id, "启用 Native Entity Capture Parity", nil, false)
		local function get_cmp_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.native_sprite_render_compare_probe")
		end
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local probe = get_cmp_probe()
			local cfg = probe and probe.get_config and probe.get_config() or {enabled = false}
			ImGui.UpdateData(enable_id, ImGuiData.Value, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local probe = get_cmp_probe()
			if probe and probe.set_enabled then probe.set_enabled(value == true) end
		end)
		local status_id = "QingRemasterOptions_NativeSpriteCmpStatus"
		imgui_layout.add_wrapped_text(native_sprite_cmp_group, status_id, "探针关闭。")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local probe = get_cmp_probe()
			imgui_layout.update_text(status_id, (probe and probe.get_summary and probe.get_summary()) or "开发探针不可用。")
		end)
		imgui_layout.add_small_action_row(native_sprite_cmp_group, {
			{id = "QingRemasterOptions_NativeSpriteCmpCapture", label = "Capture nearest", on_click = function()
				local p = get_cmp_probe(); if p and p.capture_nearest then p.capture_nearest() end
			end},
			{id = "QingRemasterOptions_NativeSpriteCmpCycle", label = "Cycle Target", on_click = function()
				local p = get_cmp_probe(); if p and p.cycle_target then p.cycle_target() end
			end},
			{id = "QingRemasterOptions_NativeSpriteCmpOverlay", label = "Overlay", on_click = function()
				local p = get_cmp_probe(); if p and p.set_mode_overlay then p.set_mode_overlay() end
			end},
			{id = "QingRemasterOptions_NativeSpriteCmpTakeover", label = "Takeover", on_click = function()
				local p = get_cmp_probe(); if p and p.set_mode_takeover then p.set_mode_takeover() end
			end},
		})
		imgui_layout.add_small_action_row(native_sprite_cmp_group, {
			{id = "QingRemasterOptions_NativeSpriteCmpEnt", label = "capture=entity", on_click = function()
				local p = get_cmp_probe(); if p and p.set_capture_entity then p.set_capture_entity() end
			end},
			{id = "QingRemasterOptions_NativeSpriteCmpSpr", label = "capture=sprite", on_click = function()
				local p = get_cmp_probe(); if p and p.set_capture_sprite then p.set_capture_sprite() end
			end},
			{id = "QingRemasterOptions_NativeSpriteCmpExportRT", label = "Export full RT", on_click = function()
				local p = get_cmp_probe(); if p and p.export_full_rt then p.export_full_rt() end
			end},
		})
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(native_sprite_cmp_group, get_cmp_probe, {
			id_prefix = "QingRemasterOptions_NativeSpriteCmpOut",
		})
	end
	end

	local pause_shift_group = start_probe_module(
		"audit_pause_sprite_shift",
		"Pause Sprite Shift",
		"QingRemasterOptions_GroupPauseSpriteShift"
	)
	if pause_shift_group then
	do
		add_text(
			pause_shift_group,
			"验证 Pause Body / Stats / Marks / MyStuff 的 Offset 是否一起平移。打开暂停 → Capture baseline → Apply +40 → 看 Verdict。默认关闭。"
		)
		local function get_ps_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.pause_sprite_shift_probe")
		end
		local enable_id = "QingRemasterOptions_PauseSpriteShiftEnabled"
		ImGui.AddCheckbox(pause_shift_group, enable_id, "Enable", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = get_ps_probe()
			local cfg = p and p.get_config and p.get_config() or {enabled = false}
			ImGui.UpdateData(enable_id, ImGuiData.Value, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = get_ps_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		imgui_layout.add_small_action_row(pause_shift_group, {
			{id = "QingRemasterOptions_PauseSpriteShiftBase", label = "Capture baseline", on_click = function()
				local p = get_ps_probe(); if p and p.capture_baseline then p.capture_baseline() end
			end},
			{id = "QingRemasterOptions_PauseSpriteShiftApply", label = "Apply +40", on_click = function()
				local p = get_ps_probe()
				if p and p.set_test_px then p.set_test_px(40) end
				if p and p.apply_test_shift then p.apply_test_shift() end
			end},
			{id = "QingRemasterOptions_PauseSpriteShiftRestore", label = "Restore", on_click = function()
				local p = get_ps_probe(); if p and p.restore_shift then p.restore_shift() end
			end},
			{id = "QingRemasterOptions_PauseSpriteShiftClear", label = "Clear", on_click = function()
				local p = get_ps_probe(); if p and p.clear then p.clear() end
			end},
		})
		local status_id = "QingRemasterOptions_PauseSpriteShiftStatus"
		imgui_layout.add_wrapped_text(pause_shift_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = get_ps_probe()
			imgui_layout.update_text(status_id, (p and p.get_summary and p.get_summary()) or "n/a")
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(pause_shift_group, get_ps_probe, {
			id_prefix = "QingRemasterOptions_PauseSpriteShiftOut",
			export_label = "Export Report",
		})
	end
	end

	local tarot_pool_group = start_probe_module(
		"audit_tarot_reverse_pool",
		"倒位塔罗卡池",
		"QingRemasterOptions_GroupTarotReversePool"
	)
	if tarot_pool_group then
		add_text(
			tarot_pool_group,
			"只记录倒位牌是否登记、MC_GET_CARD 原始类别，以及 GetCard 与 GetCardEx 的对照。不替换抽到的牌。"
		)
		local function get_tarot_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.tarot_reverse_pool_probe")
		end
		local enable_id = "QingRemasterOptions_TarotReversePoolEnabled"
		ImGui.AddCheckbox(tarot_pool_group, enable_id, "Enable", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = get_tarot_probe()
			local cfg = p and p.get_config and p.get_config() or {enabled = false}
			ImGui.UpdateData(enable_id, ImGuiData.Value, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = get_tarot_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		ImGui.AddDragInteger(
			tarot_pool_group,
			"QingRemasterOptions_TarotReversePoolCount",
			"API 抽样次数",
			function(value)
				local p = get_tarot_probe()
				if p and p.set_sample_count then p.set_sample_count(value) end
			end,
			100,
			1,
			1,
			1000,
			"%d"
		)
		imgui_layout.add_small_action_row(tarot_pool_group, {
			{id = "QingRemasterOptions_TarotReversePoolSnap", label = "检查登记", on_click = function()
				local p = get_tarot_probe()
				if p and p.snapshot_registration then p.snapshot_registration() end
			end},
			{id = "QingRemasterOptions_TarotReversePoolSample", label = "抽样 GetCard", on_click = function()
				local p = get_tarot_probe()
				if p and p.sample_apis then p.sample_apis() end
			end},
		})
		local status_id = "QingRemasterOptions_TarotReversePoolStatus"
		imgui_layout.add_wrapped_text(tarot_pool_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = get_tarot_probe()
			imgui_layout.update_text(status_id, (p and p.get_summary and p.get_summary()) or "n/a")
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(tarot_pool_group, get_tarot_probe, {
			id_prefix = "QingRemasterOptions_TarotReversePoolOut",
			export_label = "Export Report",
		})
	end

	local nihilistic_eye_record_group = start_probe_module(
		"audit_nihilistic_eye_record",
		"虚无假眼记录",
		"QingRemasterOptions_GroupNihilisticEyeRecordProbe"
	)
	if nihilistic_eye_record_group then
	do
		add_text(
			nihilistic_eye_record_group,
			"追踪 Cycle 回显时 Consistance 记录命中、companions 快照与伴生复用/重实体化。默认关闭，不写存档，不改玩法。多 Case 追加。"
		)
		local function eye_record_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.others.nihilistic_eye_record_probe")
		end
		local enable_id = "QingRemasterOptions_NihilisticEyeRecordEnabled"
		ImGui.AddCheckbox(nihilistic_eye_record_group, enable_id, "Enable", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = eye_record_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData(enable_id, ImGuiData.Value, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = eye_record_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		local status_id = "QingRemasterOptions_NihilisticEyeRecordStatus"
		imgui_layout.add_wrapped_text(nihilistic_eye_record_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = eye_record_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			imgui_layout.update_text(
				status_id,
				string.format(
					"en=%s ev=%d cases=%d create=%d hit=%d miss=%d remat=%d rem=%d verdict=%s last=%s",
					tostring(cfg.enabled),
					tonumber(cfg.event_count) or 0,
					tonumber(cfg.case_count) or 0,
					tonumber(cfg.create_count) or 0,
					tonumber(cfg.lookup_hit) or 0,
					tonumber(cfg.lookup_miss) or 0,
					tonumber(cfg.rematerialize_count) or 0,
					tonumber(cfg.slot_removed_count) or 0,
					tostring(cfg.last_verdict),
					tostring(cfg.last_result)
				)
			)
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(nihilistic_eye_record_group, eye_record_probe, {
			id_prefix = "QingRemasterOptions_NihilisticEyeRecordOut",
			export_label = "Export Report",
		})
	end
	end

	local celestial_stars_group = start_probe_module(
		"audit_celestial_stars",
		"计都星 / 罗喉星",
		"QingRemasterOptions_GroupCelestialStarsProbe"
	)
	if celestial_stars_group then
	do
		add_text(
			celestial_stars_group,
			"双星轨道 / History 分行留白 / 主动下延接金币 / 饰品短区间。拖进度自动暂停（可逆向）。标记：品红锚/青投影。"
		)
		local function celestial_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.others.celestial_stars_probe")
		end
		local enable_id = "QingRemasterOptions_CelestialStarsEnabled"
		ImGui.AddCheckbox(celestial_stars_group, enable_id, "Enable", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = celestial_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData(enable_id, ImGuiData.Value, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = celestial_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		local function add_bool(id, label, getter, setter)
			ImGui.AddCheckbox(celestial_stars_group, id, label, nil, true)
			ImGui.AddCallback(id, ImGuiCallback.Render, function()
				local p = celestial_probe()
				local cfg = p and p.get_config and p.get_config() or {}
				ImGui.UpdateData(id, ImGuiData.Value, cfg[getter] ~= false)
			end)
			ImGui.AddCallback(id, ImGuiCallback.Edited, function(value)
				local p = celestial_probe()
				if p and p[setter] then p[setter](value == true) end
			end)
		end
		add_bool("QingRemasterOptions_CelestialDrawTracks", "Draw Tracks (仅有效区间)", "draw_tracks", "set_draw_tracks")
		ImGui.AddCheckbox(celestial_stars_group, "QingRemasterOptions_CelestialDrawNodes", "Draw HUD Nodes", nil, false)
		ImGui.AddCallback("QingRemasterOptions_CelestialDrawNodes", ImGuiCallback.Render, function()
			local p = celestial_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData("QingRemasterOptions_CelestialDrawNodes", ImGuiData.Value, cfg.draw_nodes == true)
		end)
		ImGui.AddCallback("QingRemasterOptions_CelestialDrawNodes", ImGuiCallback.Edited, function(value)
			local p = celestial_probe()
			if p and p.set_draw_nodes then p.set_draw_nodes(value == true) end
		end)
		add_bool(
			"QingRemasterOptions_CelestialDrawIntervals",
			"Draw Stage Regions (起 + 道具ID)",
			"draw_intervals",
			"set_draw_intervals"
		)
		ImGui.AddCheckbox(
			celestial_stars_group,
			"QingRemasterOptions_CelestialDrawMarkers",
			"Draw Markers (品红=HUD锚 / 青=轨道投影)",
			nil,
			true
		)
		ImGui.AddCallback("QingRemasterOptions_CelestialDrawMarkers", ImGuiCallback.Render, function()
			local p = celestial_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData("QingRemasterOptions_CelestialDrawMarkers", ImGuiData.Value, cfg.draw_markers ~= false)
		end)
		ImGui.AddCallback("QingRemasterOptions_CelestialDrawMarkers", ImGuiCallback.Edited, function(value)
			local p = celestial_probe()
			if p and p.set_draw_markers then p.set_draw_markers(value == true) end
		end)
		add_bool("QingRemasterOptions_CelestialDrawBlank", "Draw Blank Segments", "draw_blank", "set_draw_blank")
		add_bool("QingRemasterOptions_CelestialDrawWobble", "Draw Logical/Render Wobble", "draw_wobble", "set_draw_wobble")
		ImGui.AddCheckbox(celestial_stars_group, "QingRemasterOptions_CelestialOrbitPaused", "Pause Orbit (方便拖进度)", nil, false)
		ImGui.AddCallback("QingRemasterOptions_CelestialOrbitPaused", ImGuiCallback.Render, function()
			local p = celestial_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData("QingRemasterOptions_CelestialOrbitPaused", ImGuiData.Value, cfg.orbit_paused == true)
		end)
		ImGui.AddCallback("QingRemasterOptions_CelestialOrbitPaused", ImGuiCallback.Edited, function(value)
			local p = celestial_probe()
			if p and p.set_orbit_paused then p.set_orbit_paused(value == true) end
		end)
		ImGui.AddCheckbox(
			celestial_stars_group,
			"QingRemasterOptions_CelestialSimulateSeija",
			"Simulate Seija (计都星时间强化)",
			nil,
			false
		)
		ImGui.AddCallback("QingRemasterOptions_CelestialSimulateSeija", ImGuiCallback.Render, function()
			local p = celestial_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData("QingRemasterOptions_CelestialSimulateSeija", ImGuiData.Value, cfg.force_seija == true)
		end)
		ImGui.AddCallback("QingRemasterOptions_CelestialSimulateSeija", ImGuiCallback.Edited, function(value)
			local p = celestial_probe()
			if p and p.set_force_seija then p.set_force_seija(value == true) end
		end)
		local time_status_id = "QingRemasterOptions_CelestialTimeAccelStatus"
		imgui_layout.add_wrapped_text(celestial_stars_group, time_status_id, "time accel: idle")
		ImGui.AddCallback(time_status_id, ImGuiCallback.Render, function()
			local p = celestial_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			local ta = cfg.time_accel or {}
			local text = string.format(
				"time accel: %s | watch=%s | extra_frames=%s | measured_rate=%s | force_seija=%s",
				ta.active and "ON" or "off",
				tostring(ta.broken_watch),
				tostring(ta.extra_frames or 0),
				ta.measured_rate ~= nil and string.format("%.3f", ta.measured_rate) or "pending",
				tostring(cfg.force_seija == true)
			)
			ImGui.UpdateData(time_status_id, ImGuiData.Label, text)
		end)
		-- min/max slightly past [0,1] so drag can cross the seam; setter floor-wraps.
		add_probe_drag(
			celestial_stars_group,
			"QingRemasterOptions_CelestialKetuProgress",
			"Ketu Progress (0-1)",
			function(v)
				local p = celestial_probe()
				if p and p.set_ketu_progress then p.set_ketu_progress(v) end
			end,
			function()
				local p = celestial_probe()
				local cfg = p and p.get_config and p.get_config() or {}
				return cfg.ketu_progress or 0
			end,
			0, 0.005, -0.05, 1.05, "%.3f"
		)
		add_probe_drag(
			celestial_stars_group,
			"QingRemasterOptions_CelestialRahuProgress",
			"Rahu Progress (0-1)",
			function(v)
				local p = celestial_probe()
				if p and p.set_rahu_progress then p.set_rahu_progress(v) end
			end,
			function()
				local p = celestial_probe()
				local cfg = p and p.get_config and p.get_config() or {}
				return cfg.rahu_progress or 0
			end,
			0, 0.005, -0.05, 1.05, "%.3f"
		)
		imgui_layout.add_action_row(celestial_stars_group, {
			{id = "QingRemasterOptions_CelestialKetuNudgeFwd", label = "Ketu +5%", on_click = function()
				local p = celestial_probe()
				if p and p.nudge_ketu_progress then p.nudge_ketu_progress(0.05) end
			end},
			{id = "QingRemasterOptions_CelestialKetuNudgeBack", label = "Ketu -5%", on_click = function()
				local p = celestial_probe()
				if p and p.nudge_ketu_progress then p.nudge_ketu_progress(-0.05) end
			end},
			{id = "QingRemasterOptions_CelestialRahuNudgeFwd", label = "Rahu +5%", on_click = function()
				local p = celestial_probe()
				if p and p.nudge_rahu_progress then p.nudge_rahu_progress(0.05) end
			end},
			{id = "QingRemasterOptions_CelestialRahuNudgeBack", label = "Rahu -5%", on_click = function()
				local p = celestial_probe()
				if p and p.nudge_rahu_progress then p.nudge_rahu_progress(-0.05) end
			end},
		})
		add_probe_drag(
			celestial_stars_group,
			"QingRemasterOptions_CelestialBaseSpeed",
			"Base Speed",
			function(v)
				local p = celestial_probe()
				if p and p.set_base_speed then p.set_base_speed(v) end
			end,
			function()
				local p = celestial_probe()
				local cfg = p and p.get_config and p.get_config() or {}
				return cfg.base_speed or 24
			end,
			24, 0.5, 1, 120, "%.1f"
		)
		add_probe_drag(
			celestial_stars_group,
			"QingRemasterOptions_CelestialBlankMult",
			"Blank Speed Multiplier",
			function(v)
				local p = celestial_probe()
				if p and p.set_blank_mult then p.set_blank_mult(v) end
			end,
			function()
				local p = celestial_probe()
				local cfg = p and p.get_config and p.get_config() or {}
				return cfg.blank_mult or 2.5
			end,
			2.5, 0.05, 1, 6, "%.2f"
		)
		add_probe_drag(
			celestial_stars_group,
			"QingRemasterOptions_CelestialMiniOX",
			"Minimap Offset X",
			function(v)
				local p = celestial_probe()
				if p and p.set_minimap_offset_x then p.set_minimap_offset_x(v) end
			end,
			function()
				local p = celestial_probe()
				local cfg = p and p.get_config and p.get_config() or {}
				return cfg.minimap_ox or -8
			end,
			-8, 0.5, -80, 80, "%.1f"
		)
		add_probe_drag(
			celestial_stars_group,
			"QingRemasterOptions_CelestialMiniOY",
			"Minimap Offset Y",
			function(v)
				local p = celestial_probe()
				if p and p.set_minimap_offset_y then p.set_minimap_offset_y(v) end
			end,
			function()
				local p = celestial_probe()
				local cfg = p and p.get_config and p.get_config() or {}
				return cfg.minimap_oy or 8
			end,
			8, 0.5, -80, 80, "%.1f"
		)
		add_text(celestial_stars_group, "—— Found HUD / 饰品标定 ——")
		add_probe_drag(
			celestial_stars_group,
			"QingRemasterOptions_CelestialStatOX",
			"Stat Column Offset X",
			function(v)
				local p = celestial_probe()
				if p and p.set_stat_column_offset_x then p.set_stat_column_offset_x(v) end
			end,
			function()
				local p = celestial_probe()
				local cfg = p and p.get_config and p.get_config() or {}
				return cfg.stat_ox or 0
			end,
			0, 0.5, -40, 40, "%.1f"
		)
		add_probe_drag(
			celestial_stars_group,
			"QingRemasterOptions_CelestialStatOY",
			"Stat Column Offset Y",
			function(v)
				local p = celestial_probe()
				if p and p.set_stat_column_offset_y then p.set_stat_column_offset_y(v) end
			end,
			function()
				local p = celestial_probe()
				local cfg = p and p.get_config and p.get_config() or {}
				return cfg.stat_oy or 8
			end,
			8, 0.5, -40, 40, "%.1f"
		)
		add_probe_drag(
			celestial_stars_group,
			"QingRemasterOptions_CelestialTrinketRadius",
			"Trinket Own Radius",
			function(v)
				local p = celestial_probe()
				if p and p.set_trinket_own_radius then p.set_trinket_own_radius(v) end
			end,
			function()
				local p = celestial_probe()
				local cfg = p and p.get_config and p.get_config() or {}
				return cfg.trinket_own_radius or 16
			end,
			16, 0.5, 1, 40, "%.1f"
		)

		-- Map Formation: session-only Cell X/Y + geometry overlays (runtime, not probe capture).
		add_text(
			celestial_stars_group,
			"—— Map Formation ——  默认世界 Cell 11/11（实测）；GoodTrip 8x7 仅屏距参考。Scale=1。不写存档。"
		)
		local function celestial_runtime()
			return require("Qing_Remaster_scripts.items.celestial.runtime")
		end
		add_probe_drag(
			celestial_stars_group,
			"QingRemasterOptions_RahuMapCellX",
			"Cell X",
			function(v)
				local rt = celestial_runtime()
				if rt and rt.set_map_cell_x then rt.set_map_cell_x(v) end
			end,
			function()
				local rt = celestial_runtime()
				local cfg = rt and rt.get_map_formation_debug and rt.get_map_formation_debug() or {}
				return cfg.cell_x or 11
			end,
			11, 0.5, 6, 30, "%.1f"
		)
		add_probe_drag(
			celestial_stars_group,
			"QingRemasterOptions_RahuMapCellY",
			"Cell Y",
			function(v)
				local rt = celestial_runtime()
				if rt and rt.set_map_cell_y then rt.set_map_cell_y(v) end
			end,
			function()
				local rt = celestial_runtime()
				local cfg = rt and rt.get_map_formation_debug and rt.get_map_formation_debug() or {}
				return cfg.cell_y or 11
			end,
			11, 0.5, 6, 30, "%.1f"
		)
		local function add_map_bool(id, label, getter_key, setter_name)
			ImGui.AddCheckbox(celestial_stars_group, id, label, nil, false)
			ImGui.AddCallback(id, ImGuiCallback.Render, function()
				local rt = celestial_runtime()
				local cfg = rt and rt.get_map_formation_debug and rt.get_map_formation_debug() or {}
				ImGui.UpdateData(id, ImGuiData.Value, cfg[getter_key] == true)
			end)
			ImGui.AddCallback(id, ImGuiCallback.Edited, function(value)
				local rt = celestial_runtime()
				if rt and rt[setter_name] then rt[setter_name](value == true) end
			end)
		end
		add_map_bool(
			"QingRemasterOptions_RahuMapShowAnchors",
			"Show Formation Anchors",
			"show_anchors",
			"set_map_show_anchors"
		)
		add_map_bool(
			"QingRemasterOptions_RahuMapShowSpriteBounds",
			"Show Sprite Bounds",
			"show_sprite_bounds",
			"set_map_show_sprite_bounds"
		)
		add_map_bool(
			"QingRemasterOptions_RahuMapShowLogicalCells",
			"Show Logical Occupied Cells",
			"show_logical_cells",
			"set_map_show_logical_cells"
		)
		add_map_bool(
			"QingRemasterOptions_RahuMapShowSpritePivot",
			"Show Sprite Pivot",
			"show_sprite_pivot",
			"set_map_show_sprite_pivot"
		)
		imgui_layout.add_action_row(celestial_stars_group, {
			{id = "QingRemasterOptions_RahuMapResetFormation", label = "Reset Formation", on_click = function()
				local rt = celestial_runtime()
				if rt and rt.reset_map_formation_debug then rt.reset_map_formation_debug() end
			end},
			{id = "QingRemasterOptions_RahuMapFireVolley", label = "立刻发射地图子弹", on_click = function()
				local rt = celestial_runtime()
				if rt and rt.debug_fire_map_volley then
					rt.debug_fire_map_volley(Isaac.GetPlayer(0))
				end
			end},
		})

		local status_id = "QingRemasterOptions_CelestialStarsStatus"
		imgui_layout.add_wrapped_text(celestial_stars_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = celestial_probe()
			local body = (p and p.get_summary and p.get_summary()) or "unavailable"
			imgui_layout.update_text(status_id, body)
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(celestial_stars_group, celestial_probe, {
			id_prefix = "QingRemasterOptions_CelestialStarsOut",
			export_label = "Export Report",
		})
	end
	end

	local celestial_tear_life_group = start_probe_module(
		"audit_celestial_tear_lifecycle",
		"Celestial Stars · Tear Lifecycle",
		"QingRemasterOptions_GroupCelestialTearLifecycle"
	)
	if celestial_tear_life_group then
	do
		add_text(
			celestial_tear_life_group,
			"v4 原版射程物理校准。Test Mode：Vanilla Range / FS Calibration / Rahu Comparison。默认轻量 Summary；Detailed 手动开。自动 Sweep 一次只飞一颗。不改罗喉/falling_for_range/Air Flight。"
		)
		local function tear_life_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.others.celestial_tear_lifecycle_probe")
		end
		local enable_id = "QingRemasterOptions_CelestialTearLifeEnabled"
		ImGui.AddCheckbox(celestial_tear_life_group, enable_id, "Enable", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = tear_life_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData(enable_id, ImGuiData.Value, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = tear_life_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		local mode_combo = "QingRemasterOptions_CelestialTearLifeMode"
		ImGui.AddCombobox(celestial_tear_life_group, mode_combo, "Test Mode", function(index)
			local p = tear_life_probe()
			if p and p.set_test_mode then p.set_test_mode(index) end
		end, {"Vanilla Range", "FS Calibration", "Rahu Comparison"}, 0)
		ImGui.AddCallback(mode_combo, ImGuiCallback.Render, function()
			local p = tear_life_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData(mode_combo, ImGuiData.Value, tonumber(cfg.test_mode) or 0)
		end)
		add_probe_drag(
			celestial_tear_life_group,
			"QingRemasterOptions_CelestialTearLifeRangeDisp",
			"Test Player Range (display)",
			function(v)
				local p = tear_life_probe()
				if p and p.set_range_display then p.set_range_display(v) end
			end,
			function()
				local p = tear_life_probe()
				local cfg = p and p.get_config and p.get_config() or {}
				return cfg.range_display or 6.5
			end,
			6.5, 0.1, 0.5, 50, "%.2f"
		)
		local native_id = "QingRemasterOptions_CelestialTearLifeNativeRange"
		ImGui.AddCheckbox(celestial_tear_life_group, native_id, "使用玩家原始射程", nil, false)
		ImGui.AddCallback(native_id, ImGuiCallback.Render, function()
			local p = tear_life_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData(native_id, ImGuiData.Value, cfg.use_native_range == true)
		end)
		ImGui.AddCallback(native_id, ImGuiCallback.Edited, function(value)
			local p = tear_life_probe()
			if p and p.set_use_native_range then p.set_use_native_range(value == true) end
		end)
		local fix_ss_id = "QingRemasterOptions_CelestialTearLifeFixShot"
		ImGui.AddCheckbox(celestial_tear_life_group, fix_ss_id, "Fix ShotSpeed (Vanilla)", nil, true)
		ImGui.AddCallback(fix_ss_id, ImGuiCallback.Render, function()
			local p = tear_life_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData(fix_ss_id, ImGuiData.Value, cfg.fix_shot_speed ~= false)
		end)
		ImGui.AddCallback(fix_ss_id, ImGuiCallback.Edited, function(value)
			local p = tear_life_probe()
			if p and p.set_fix_shot_speed then p.set_fix_shot_speed(value == true) end
		end)
		add_probe_drag(
			celestial_tear_life_group,
			"QingRemasterOptions_CelestialTearLifeShotSpd",
			"ShotSpeed (when fixed)",
			function(v)
				local p = tear_life_probe()
				if p and p.set_shot_speed_display then p.set_shot_speed_display(v) end
			end,
			function()
				local p = tear_life_probe()
				local cfg = p and p.get_config and p.get_config() or {}
				return cfg.shot_speed_display or 1
			end,
			1, 0.05, 0.2, 3, "%.2f"
		)
		add_text(celestial_tear_life_group, "—— FS Calibration tear ——")
		add_probe_drag(
			celestial_tear_life_group,
			"QingRemasterOptions_CelestialTearLifeCalibH",
			"Calib Height",
			function(v)
				local p = tear_life_probe(); if p and p.set_calib_height then p.set_calib_height(v) end
			end,
			function()
				local p = tear_life_probe(); local cfg = p and p.get_config and p.get_config() or {}
				return cfg.calib_height or -23.75
			end,
			-23.75, 0.25, -150, -5, "%.2f"
		)
		add_probe_drag(
			celestial_tear_life_group,
			"QingRemasterOptions_CelestialTearLifeCalibFS",
			"Calib FallingSpeed",
			function(v)
				local p = tear_life_probe(); if p and p.set_calib_fs then p.set_calib_fs(v) end
			end,
			function()
				local p = tear_life_probe(); local cfg = p and p.get_config and p.get_config() or {}
				return cfg.calib_fs or 0
			end,
			0, 0.1, -20, 5, "%.2f"
		)
		add_probe_drag(
			celestial_tear_life_group,
			"QingRemasterOptions_CelestialTearLifeCalibFA",
			"Calib FallingAcceleration",
			function(v)
				local p = tear_life_probe(); if p and p.set_calib_fa then p.set_calib_fa(v) end
			end,
			function()
				local p = tear_life_probe(); local cfg = p and p.get_config and p.get_config() or {}
				return cfg.calib_fa or 0
			end,
			0, 0.005, -0.05, 0.5, "%.3f"
		)
		add_probe_drag(
			celestial_tear_life_group,
			"QingRemasterOptions_CelestialTearLifeCalibSpd",
			"Calib Horizontal Speed",
			function(v)
				local p = tear_life_probe(); if p and p.set_calib_hspeed then p.set_calib_hspeed(v) end
			end,
			function()
				local p = tear_life_probe(); local cfg = p and p.get_config and p.get_config() or {}
				return cfg.calib_hspeed or 10
			end,
			10, 0.5, 5, 25, "%.1f"
		)
		local detailed_id = "QingRemasterOptions_CelestialTearLifeDetailed"
		ImGui.AddCheckbox(celestial_tear_life_group, detailed_id, "Detailed Mode", nil, false)
		ImGui.AddCallback(detailed_id, ImGuiCallback.Render, function()
			local p = tear_life_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData(detailed_id, ImGuiData.Value, cfg.detailed_mode == true)
		end)
		ImGui.AddCallback(detailed_id, ImGuiCallback.Edited, function(value)
			local p = tear_life_probe()
			if p and p.set_detailed_mode then p.set_detailed_mode(value == true) end
		end)
		local status_id = "QingRemasterOptions_CelestialTearLifeStatus"
		imgui_layout.add_wrapped_text(celestial_tear_life_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = tear_life_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			local body = string.format(
				"last=%s mode=%s active=%s done=%s sweep=%s TearRange=%s TearH=%s TearFS=%s ShotSpd=%s fit=%s",
				tostring(cfg.last_result or "idle"),
				tostring(cfg.test_mode),
				tostring(cfg.active or 0),
				tostring(cfg.completed or 0),
				tostring(cfg.sweep_running == true),
				tostring(cfg.actual_tear_range),
				tostring(cfg.player_tear_height),
				tostring(cfg.player_tear_fs),
				tostring(cfg.player_shot_speed),
				tostring(cfg.fit_ok == true)
			)
			imgui_layout.update_text(status_id, body)
		end)
		imgui_layout.add_action_row(celestial_tear_life_group, {
			{id = "QingRemasterOptions_CelestialTearLifeFireCalib", label = "Fire Calibration Tear", on_click = function()
				local p = tear_life_probe()
				if p and p.fire_calibration_tear then p.fire_calibration_tear() end
			end},
			{id = "QingRemasterOptions_CelestialTearLifeFit", label = "Compute Fit", on_click = function()
				local p = tear_life_probe()
				if p and p.compute_fit then p.compute_fit() end
			end},
		})
		imgui_layout.add_action_row(celestial_tear_life_group, {
			{id = "QingRemasterOptions_CelestialTearLifeSweepV", label = "Vanilla Range Sweep", on_click = function()
				local p = tear_life_probe()
				if p and p.start_vanilla_range_sweep then p.start_vanilla_range_sweep() end
			end},
			{id = "QingRemasterOptions_CelestialTearLifeSweepFS", label = "Initial FS Sweep", on_click = function()
				local p = tear_life_probe()
				if p and p.start_fs_sweep then p.start_fs_sweep() end
			end},
		})
		imgui_layout.add_small_action_row(celestial_tear_life_group, {
			{id = "QingRemasterOptions_CelestialTearLifeSweepFA", label = "FA Sweep", on_click = function()
				local p = tear_life_probe()
				if p and p.start_fa_sweep then p.start_fa_sweep() end
			end},
			{id = "QingRemasterOptions_CelestialTearLifeSweepStop", label = "Stop Sweep", on_click = function()
				local p = tear_life_probe()
				if p and p.stop_sweep then p.stop_sweep() end
			end},
			{id = "QingRemasterOptions_CelestialTearLifeClear", label = "Clear Records", on_click = function()
				local p = tear_life_probe()
				if p and p.clear then p.clear() end
			end},
		})
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(celestial_tear_life_group, tear_life_probe, {
			id_prefix = "QingRemasterOptions_CelestialTearLifeOut",
			summary_label = "Copy Summary",
			full_label = "Copy Detailed Trace",
			export_label = "Export JSONL",
		})
	end
	end

	local isolation_spawn_group = start_probe_module(
		"audit_isolation_spawn",
		"孤立生成",
		"QingRemasterOptions_GroupIsolationSpawnProbe"
	)
	if isolation_spawn_group then
	do
		add_text(
			isolation_spawn_group,
			"记录 Encounter / Cycle / D6 Morph / 自适应布局 V2。默认关闭。商店可展开。Force Next=下一次 Encounter 临时十人名单。看 LAYOUT_SELECTED / LAYOUT_FALLBACK。"
		)
		local function iso_spawn_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.others.isolation_spawn_probe")
		end
		local function iso_item()
			return require("Qing_Remaster_scripts.items.Item_Isolation")
		end
		local enable_id = "QingRemasterOptions_IsolationSpawnEnabled"
		ImGui.AddCheckbox(isolation_spawn_group, enable_id, "Enable", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = iso_spawn_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData(enable_id, ImGuiData.Value, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = iso_spawn_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		local overlay_id = "QingRemasterOptions_IsolationSpawnOverlay"
		ImGui.AddCheckbox(isolation_spawn_group, overlay_id, "Overlay crosses", nil, true)
		ImGui.AddCallback(overlay_id, ImGuiCallback.Render, function()
			local p = iso_spawn_probe()
			local cfg = p and p.get_config and p.get_config() or {overlay = true}
			ImGui.UpdateData(overlay_id, ImGuiData.Value, cfg.overlay ~= false)
		end)
		ImGui.AddCallback(overlay_id, ImGuiCallback.Edited, function(value)
			local p = iso_spawn_probe()
			if p and p.set_overlay then p.set_overlay(value == true) end
		end)
		local force_id = "QingRemasterOptions_IsolationForceNextEncounter"
		ImGui.AddCheckbox(
			isolation_spawn_group,
			force_id,
			"Force Next Eligible Encounter as Clique Member",
			nil,
			false
		)
		ImGui.AddCallback(force_id, ImGuiCallback.Render, function()
			local iso = iso_item()
			local armed = iso and iso.is_force_next_encounter_as_member
				and iso.is_force_next_encounter_as_member() == true
			ImGui.UpdateData(force_id, ImGuiData.Value, armed)
		end)
		ImGui.AddCallback(force_id, ImGuiCallback.Edited, function(value)
			local iso = iso_item()
			if iso and iso.set_force_next_encounter_as_member then
				iso.set_force_next_encounter_as_member(value == true)
			end
			local p = iso_spawn_probe()
			if p and p.note and p.get_config and p.get_config().enabled then
				p.note("FORCE_ARM", {
					armed = value == true,
				})
			end
		end)
		local status_id = "QingRemasterOptions_IsolationSpawnStatus"
		imgui_layout.add_wrapped_text(isolation_spawn_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = iso_spawn_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			local iso = iso_item()
			local force_armed = iso and iso.is_force_next_encounter_as_member
				and iso.is_force_next_encounter_as_member() == true
			local force_ov = iso and iso.has_test_members_override
				and iso.has_test_members_override() == true
			imgui_layout.update_text(
				status_id,
				string.format(
					"en=%s ov=%s force=%s fov=%s ev=%d spawn_ok=%d spawn_fail=%d settle_ok=%d settle_fail=%d exp_noenc=%d d6m=%d d6mem=%d d6blk=%d last=%s id=%s",
					tostring(cfg.enabled),
					tostring(cfg.overlay),
					tostring(force_armed),
					tostring(force_ov),
					tonumber(cfg.event_count) or 0,
					tonumber(cfg.success_count) or 0,
					tonumber(cfg.fail_count) or 0,
					tonumber(cfg.settle_ok_count) or 0,
					tonumber(cfg.settle_fail_count) or 0,
					tonumber(cfg.expected_no_enc_count) or 0,
					tonumber(cfg.d6_morph_count) or 0,
					tonumber(cfg.d6_member_count) or 0,
					tonumber(cfg.d6_blocked_count) or 0,
					tostring(cfg.last_result),
					tostring(cfg.last_collectible)
				)
			)
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(isolation_spawn_group, iso_spawn_probe, {
			id_prefix = "QingRemasterOptions_IsolationSpawnOut",
			export_label = "Export Report",
		})
	end
	end

	local alien_savior_group = start_probe_module(
		"audit_alien_savior",
		"天外救星",
		"QingRemasterOptions_GroupAlienSaviorProbe"
	)
	if alien_savior_group then
	do
		add_text(alien_savior_group, "天外救星 SOS / UFO 状态机探针。默认关闭。Force 按钮会调用道具公开 API。")
		local function as_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.alien_savior_probe")
		end
		local enable_id = "QingRemasterOptions_AlienSaviorEnabled"
		ImGui.AddCheckbox(alien_savior_group, enable_id, "Enable", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = as_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData(enable_id, ImGuiData.Value, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = as_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		local function ensure_rescue(p)
			local c = require("Qing_Remaster_scripts.items.alien_savior.controller")
			if not c.is_active() then
				p.force_rescue()
			end
		end
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorForceSos", "Force SOS", function()
			local p = as_probe()
			if p and p.force_sos then p.force_sos() end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorForceFirstSosFx", "Force First SOS FX", function()
			local p = as_probe()
			if p and p.force_first_sos_fx then p.force_first_sos_fx() end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorReplayFirstSosFx", "Replay First SOS FX", function()
			local p = as_probe()
			if p and p.replay_first_sos_fx then p.replay_first_sos_fx() end
		end)
		local skip_sos_fx_id = "QingRemasterOptions_AlienSaviorSkipFirstSosFx"
		ImGui.AddCheckbox(alien_savior_group, skip_sos_fx_id, "Skip First SOS FX", nil, false)
		ImGui.AddCallback(skip_sos_fx_id, ImGuiCallback.Render, function()
			local p = as_probe()
			local a = p and p.get_first_sos_audit and p.get_first_sos_audit() or {}
			ImGui.UpdateData(skip_sos_fx_id, ImGuiData.Value, a.skip == true)
		end)
		ImGui.AddCallback(skip_sos_fx_id, ImGuiCallback.Edited, function(value)
			local p = as_probe()
			if p and p.set_skip_first_sos_fx then p.set_skip_first_sos_fx(value == true) end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorCopyFirstSosAudit", "Copy First SOS Audit", function()
			local p = as_probe()
			if p and p.copy_first_sos_audit then p.copy_first_sos_audit() end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorForceRescue", "Force Rescue", function()
			local p = as_probe()
			if p and p.force_rescue then p.force_rescue() end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorForceAbduct", "Force Abduction", function()
			local p = as_probe()
			if p then ensure_rescue(p); p.force_phase("ABDUCT_PLAYER") end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorForceTransit", "Force Transit to Center", function()
			local p = as_probe()
			if p then ensure_rescue(p); p.force_phase("TRANSIT_TO_CENTER") end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorForceCleanup", "Force Work / Cleanup", function()
			local p = as_probe()
			if p then ensure_rescue(p); p.force_phase("ABDUCT_TARGETS") end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorForceDepart", "Force Departing", function()
			local p = as_probe()
			if p then ensure_rescue(p); p.force_phase("DEPARTING") end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorForceLaser", "Force LASER_SWEEP", function()
			local p = as_probe()
			if p then ensure_rescue(p); p.force_phase("LASER_SWEEP") end
		end)
		local show_main_origin_id = "QingRemasterOptions_AlienSaviorShowMainLaserOrigins"
		ImGui.AddCheckbox(alien_savior_group, show_main_origin_id, "Show Main Laser Origins", nil, false)
		ImGui.AddCallback(show_main_origin_id, ImGuiCallback.Render, function()
			local laser = require("Qing_Remaster_scripts.items.alien_savior.laser_controller")
			local d = laser.get_debug and laser.get_debug() or {}
			ImGui.UpdateData(show_main_origin_id, ImGuiData.Value, d.show_main_origins == true)
		end)
		ImGui.AddCallback(show_main_origin_id, ImGuiCallback.Edited, function(value)
			local p = as_probe()
			if p and p.set_laser_debug then p.set_laser_debug({ show_main_origins = value == true }) end
		end)
		local show_lamp_origin_id = "QingRemasterOptions_AlienSaviorShowLampLaserOrigins"
		ImGui.AddCheckbox(alien_savior_group, show_lamp_origin_id, "Show Lamp Laser Origins", nil, false)
		ImGui.AddCallback(show_lamp_origin_id, ImGuiCallback.Render, function()
			local laser = require("Qing_Remaster_scripts.items.alien_savior.laser_controller")
			local d = laser.get_debug and laser.get_debug() or {}
			ImGui.UpdateData(show_lamp_origin_id, ImGuiData.Value, d.show_lamp_origins == true)
		end)
		ImGui.AddCallback(show_lamp_origin_id, ImGuiCallback.Edited, function(value)
			local p = as_probe()
			if p and p.set_laser_debug then p.set_laser_debug({ show_lamp_origins = value == true }) end
		end)
		add_text(alien_savior_group, "—— Laser Render（V10.2 着色/层级诊断）——")
		local laser_presets = { "default", "bright_cyan", "pure_white" }
		local laser_preset_labels = { "Default", "Bright Cyan", "Pure White" }
		local laser_preset_id = "QingRemasterOptions_AlienSaviorLaserColorPreset"
		ImGui.AddCombobox(alien_savior_group, laser_preset_id, "Laser Color", function(index)
			local p = as_probe()
			local key = laser_presets[(index or 0) + 1] or "default"
			if p and p.set_laser_debug then p.set_laser_debug({ color_preset = key }) end
		end, laser_preset_labels, 0)
		ImGui.AddCallback(laser_preset_id, ImGuiCallback.Render, function()
			local laser = require("Qing_Remaster_scripts.items.alien_savior.laser_controller")
			local d = laser.get_debug and laser.get_debug() or {}
			local map = { default = 0, bright_cyan = 1, pure_white = 2 }
			ImGui.UpdateData(laser_preset_id, ImGuiData.Value, map[d.color_preset or "default"] or 0)
		end)
		local laser_targets = { "both", "entity", "sprite" }
		local laser_target_labels = { "Both", "Entity", "Sprite" }
		local laser_target_id = "QingRemasterOptions_AlienSaviorLaserColorTarget"
		ImGui.AddCombobox(alien_savior_group, laser_target_id, "Laser Color Target", function(index)
			local p = as_probe()
			local key = laser_targets[(index or 0) + 1] or "both"
			if p and p.set_laser_debug then p.set_laser_debug({ color_target = key }) end
		end, laser_target_labels, 0)
		ImGui.AddCallback(laser_target_id, ImGuiCallback.Render, function()
			local laser = require("Qing_Remaster_scripts.items.alien_savior.laser_controller")
			local d = laser.get_debug and laser.get_debug() or {}
			local map = { both = 0, entity = 1, sprite = 2 }
			ImGui.UpdateData(laser_target_id, ImGuiData.Value, map[d.color_target or "both"] or 0)
		end)
		local laser_layers = { "ufo_foreground", "native" }
		local laser_layer_labels = { "UFO Foreground", "Native" }
		local laser_layer_id = "QingRemasterOptions_AlienSaviorLaserLayerTest"
		ImGui.AddCombobox(alien_savior_group, laser_layer_id, "Laser Layer Test", function(index)
			local p = as_probe()
			local key = laser_layers[(index or 0) + 1] or "ufo_foreground"
			if p and p.set_laser_debug then p.set_laser_debug({ layer_test = key }) end
		end, laser_layer_labels, 0)
		ImGui.AddCallback(laser_layer_id, ImGuiCallback.Render, function()
			local laser = require("Qing_Remaster_scripts.items.alien_savior.laser_controller")
			local d = laser.get_debug and laser.get_debug() or {}
			local map = { ufo_foreground = 0, native = 1 }
			ImGui.UpdateData(laser_layer_id, ImGuiData.Value, map[d.layer_test or "ufo_foreground"] or 0)
		end)
		local show_cone_id = "QingRemasterOptions_AlienSaviorShowConeGeometry"
		ImGui.AddCheckbox(alien_savior_group, show_cone_id, "Show Cone Geometry", nil, false)
		ImGui.AddCallback(show_cone_id, ImGuiCallback.Render, function()
			local laser = require("Qing_Remaster_scripts.items.alien_savior.laser_controller")
			local d = laser.get_debug and laser.get_debug() or {}
			ImGui.UpdateData(show_cone_id, ImGuiData.Value, d.show_cone_geometry == true)
		end)
		ImGui.AddCallback(show_cone_id, ImGuiCallback.Edited, function(value)
			local p = as_probe()
			if p and p.set_laser_debug then p.set_laser_debug({ show_cone_geometry = value == true }) end
		end)
		add_probe_drag(alien_savior_group, "QingRemasterOptions_AlienSaviorConeRadiusX", "Cone Radius X", function(v)
			local p = as_probe(); if p and p.set_laser_debug then p.set_laser_debug({ cone_radius_x = v }) end
		end, function()
			local laser = require("Qing_Remaster_scripts.items.alien_savior.laser_controller")
			local d = laser.get_debug and laser.get_debug() or {}; return d.cone_radius_x or 95
		end, 95, 1, 40, 160, "%.0f")
		add_probe_drag(alien_savior_group, "QingRemasterOptions_AlienSaviorConeRadiusY", "Cone Radius Y", function(v)
			local p = as_probe(); if p and p.set_laser_debug then p.set_laser_debug({ cone_radius_y = v }) end
		end, function()
			local laser = require("Qing_Remaster_scripts.items.alien_savior.laser_controller")
			local d = laser.get_debug and laser.get_debug() or {}; return d.cone_radius_y or 28
		end, 28, 1, 10, 80, "%.0f")
		add_probe_drag(alien_savior_group, "QingRemasterOptions_AlienSaviorConeHeight", "Cone Height", function(v)
			local p = as_probe(); if p and p.set_laser_debug then p.set_laser_debug({ cone_height = v }) end
		end, function()
			local laser = require("Qing_Remaster_scripts.items.alien_savior.laser_controller")
			local d = laser.get_debug and laser.get_debug() or {}; return d.cone_height or 70
		end, 70, 1, 30, 140, "%.0f")
		add_probe_drag(alien_savior_group, "QingRemasterOptions_AlienSaviorConeSpeed", "Cone Speed deg/f", function(v)
			local p = as_probe(); if p and p.set_laser_debug then p.set_laser_debug({ cone_speed = v }) end
		end, function()
			local laser = require("Qing_Remaster_scripts.items.alien_savior.laser_controller")
			local d = laser.get_debug and laser.get_debug() or {}; return d.cone_speed or 3
		end, 3, 0.25, 0.5, 12, "%.2f")
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorCopyLaserAudit", "Copy Laser Render Audit", function()
			local p = as_probe()
			if p and p.copy_laser_render_audit then
				p.copy_laser_render_audit()
			elseif p and p.copy_laser_audit then
				p.copy_laser_audit()
			end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorForceRelease", "Force Release", function()
			local p = as_probe()
			if p then ensure_rescue(p); p.force_phase("RELEASE_PLAYER") end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorAbort", "Abort Rescue", function()
			local p = as_probe()
			if p and p.abort_rescue then p.abort_rescue() end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorReset", "Reset State", function()
			local p = as_probe()
			if p and p.reset_state then p.reset_state() end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorPlaySearch", "Play SOS Search", function()
			local p = as_probe()
			if p and p.play_sfx then p.play_sfx("search") end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorPlayConnected", "Play SOS Connected", function()
			local p = as_probe()
			if p and p.play_sfx then p.play_sfx("connected") end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorPlayArrival", "Play UFO Arrival", function()
			local p = as_probe()
			if p and p.play_sfx then p.play_sfx("arrival") end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorPlayHover", "Play UFO Hover", function()
			local p = as_probe()
			if p and p.play_sfx then p.play_sfx("hover") end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorStopAudio", "Stop Alien Savior Audio", function()
			local p = as_probe()
			if p and p.stop_sfx then p.stop_sfx() end
		end)

		add_text(alien_savior_group, "—— UFO Motion（默认关；Scale/悬停/入场偏移/光柱）——")
		local motion_en_id = "QingRemasterOptions_AlienSaviorMotionEnabled"
		ImGui.AddCheckbox(alien_savior_group, motion_en_id, "Enable Motion Debug", nil, false)
		ImGui.AddCallback(motion_en_id, ImGuiCallback.Render, function()
			local p = as_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData(motion_en_id, ImGuiData.Value, cfg.motion_enabled == true)
		end)
		ImGui.AddCallback(motion_en_id, ImGuiCallback.Edited, function(value)
			local p = as_probe()
			if p and p.set_motion_enabled then p.set_motion_enabled(value == true) end
		end)
		add_probe_drag(alien_savior_group, "QingRemasterOptions_AlienSaviorUfoScale", "UFO Scale", function(v)
			local p = as_probe(); if p and p.set_ufo_scale then p.set_ufo_scale(v) end
		end, function()
			local p = as_probe(); local cfg = p and p.get_config and p.get_config() or {}; return cfg.ufo_scale or 1
		end, 1.0, 0.05, 0.75, 1.25, "%.2f")
		add_probe_drag(alien_savior_group, "QingRemasterOptions_AlienSaviorHoverH", "Hover Height", function(v)
			local p = as_probe(); if p and p.set_hover_height then p.set_hover_height(v) end
		end, function()
			local p = as_probe(); local cfg = p and p.get_config and p.get_config() or {}; return cfg.hover_height or 72
		end, 72, 1, 40, 140, "%.0f")
		add_probe_drag(alien_savior_group, "QingRemasterOptions_AlienSaviorEntryX", "Entry X Offset", function(v)
			local p = as_probe(); if p and p.set_entry_x then p.set_entry_x(v) end
		end, function()
			local p = as_probe(); local cfg = p and p.get_config and p.get_config() or {}; return cfg.entry_x or -140
		end, -140, 1, -220, 220, "%.0f")
		add_probe_drag(alien_savior_group, "QingRemasterOptions_AlienSaviorEntryY", "Entry Y Offset", function(v)
			local p = as_probe(); if p and p.set_entry_y then p.set_entry_y(v) end
		end, function()
			local p = as_probe(); local cfg = p and p.get_config and p.get_config() or {}; return cfg.entry_y or -110
		end, -110, 1, -220, 40, "%.0f")
		add_probe_drag(alien_savior_group, "QingRemasterOptions_AlienSaviorBeamW", "Beam Width", function(v)
			local p = as_probe(); if p and p.set_beam_width then p.set_beam_width(v) end
		end, function()
			local p = as_probe(); local cfg = p and p.get_config and p.get_config() or {}; return cfg.beam_width or 1
		end, 1.0, 0.05, 0.4, 2.5, "%.2f")
		add_probe_drag(alien_savior_group, "QingRemasterOptions_AlienSaviorBeamOp", "Beam Opacity", function(v)
			local p = as_probe(); if p and p.set_beam_opacity then p.set_beam_opacity(v) end
		end, function()
			local p = as_probe(); local cfg = p and p.get_config and p.get_config() or {}; return cfg.beam_opacity or 0.85
		end, 0.85, 0.01, 0, 1, "%.2f")
		local path_id = "QingRemasterOptions_AlienSaviorShowPath"
		ImGui.AddCheckbox(alien_savior_group, path_id, "Show Motion Path", nil, false)
		ImGui.AddCallback(path_id, ImGuiCallback.Render, function()
			local p = as_probe(); local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData(path_id, ImGuiData.Value, cfg.show_path == true)
		end)
		ImGui.AddCallback(path_id, ImGuiCallback.Edited, function(value)
			local p = as_probe(); if p and p.set_show_path then p.set_show_path(value == true) end
		end)
		local mouth_id = "QingRemasterOptions_AlienSaviorShowMouth"
		ImGui.AddCheckbox(alien_savior_group, mouth_id, "Show Mouth Anchor", nil, false)
		ImGui.AddCallback(mouth_id, ImGuiCallback.Render, function()
			local p = as_probe(); local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData(mouth_id, ImGuiData.Value, cfg.show_mouth == true)
		end)
		ImGui.AddCallback(mouth_id, ImGuiCallback.Edited, function(value)
			local p = as_probe(); if p and p.set_show_mouth then p.set_show_mouth(value == true) end
		end)
		local beam_modes = { "auto", "pickup", "work", "release", "off" }
		local beam_mode_id = "QingRemasterOptions_AlienSaviorBeamMode"
		ImGui.AddCombobox(alien_savior_group, beam_mode_id, "Beam Mode", function(index)
			local p = as_probe()
			local key = beam_modes[(index or 0) + 1] or "auto"
			if p and p.set_beam_mode then
				if key == "auto" then p.set_beam_mode(nil) else p.set_beam_mode(key) end
			end
		end, beam_modes, 0)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorBeamClear", "Clear Beam Override", function()
			local p = as_probe(); if p and p.set_beam_mode then p.set_beam_mode(nil) end
		end)
		add_text(alien_savior_group, "Beam Layers（默认 Cone+Ground；Core=中央长条，默认关）")
		local function beam_layer_box(id, label, key)
			ImGui.AddCheckbox(alien_savior_group, id, label, nil, key ~= "core")
			ImGui.AddCallback(id, ImGuiCallback.Render, function()
				local md = require("Qing_Remaster_scripts.items.alien_savior.motion").get_debug()
				local on = true
				if key == "cone" then on = md.beam_show_cone ~= false
				elseif key == "core" then on = md.beam_show_core == true
				elseif key == "ground" then on = md.beam_show_ground ~= false
				end
				ImGui.UpdateData(id, ImGuiData.Value, on)
			end)
			ImGui.AddCallback(id, ImGuiCallback.Edited, function(value)
				local p = as_probe(); if p and p.set_beam_layer then p.set_beam_layer(key, value == true) end
			end)
		end
		beam_layer_box("QingRemasterOptions_AlienSaviorBeamCone", "Show Beam Cone", "cone")
		beam_layer_box("QingRemasterOptions_AlienSaviorBeamCore", "Show Beam Core (strip)", "core")
		beam_layer_box("QingRemasterOptions_AlienSaviorBeamGround", "Show Beam Ground", "ground")
		local seam_id = "QingRemasterOptions_AlienSaviorBeamSeam"
		ImGui.AddCheckbox(alien_savior_group, seam_id, "Show Beam Seam Marks", nil, false)
		ImGui.AddCallback(seam_id, ImGuiCallback.Render, function()
			local md = require("Qing_Remaster_scripts.items.alien_savior.motion").get_debug()
			ImGui.UpdateData(seam_id, ImGuiData.Value, md.show_beam_seam == true)
		end)
		ImGui.AddCallback(seam_id, ImGuiCallback.Edited, function(value)
			local p = as_probe(); if p and p.set_show_beam_seam then p.set_show_beam_seam(value == true) end
		end)
		local beam_frz_id = "QingRemasterOptions_AlienSaviorBeamFreeze"
		ImGui.AddCheckbox(alien_savior_group, beam_frz_id, "Freeze Beam Transition", nil, false)
		ImGui.AddCallback(beam_frz_id, ImGuiCallback.Render, function()
			local md = require("Qing_Remaster_scripts.items.alien_savior.motion").get_debug()
			ImGui.UpdateData(beam_frz_id, ImGuiData.Value, md.beam_freeze == true)
		end)
		ImGui.AddCallback(beam_frz_id, ImGuiCallback.Edited, function(value)
			local p = as_probe(); if p and p.set_beam_freeze then p.set_beam_freeze(value == true) end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorBeamAudit", "Copy Beam Audit", function()
			local p = as_probe(); if p and p.copy_beam_audit then p.copy_beam_audit() end
		end)

		add_text(alien_savior_group, "—— Player LightTravel（固定 Position；无 SpriteOffset 拉升）——")
		add_probe_drag(alien_savior_group, "QingRemasterOptions_AlienSaviorCaptureFrame", "Capture Frame", function(v)
			local p = as_probe(); if p and p.set_capture_frame then p.set_capture_frame(v) end
		end, function()
			return require("Qing_Remaster_scripts.items.alien_savior.motion").capture_frame()
		end, 32, 1, 1, 35)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorAnimAudit", "Copy Animation Audit", function()
			local p = as_probe(); if p and p.copy_anim_audit then p.copy_anim_audit() end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorProbeAnimateLT", "Probe AnimateLightTravel()", function()
			local p = as_probe(); if p and p.probe_animate_light_travel then p.probe_animate_light_travel() end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorProbePlayExtra", "Probe PlayExtraAnimation(LightTravel)", function()
			local p = as_probe(); if p and p.probe_play_extra_light_travel then p.probe_play_extra_light_travel() end
		end)

		add_text(alien_savior_group, "—— Protection / Control Release（Attribute_holder + fallback）——")
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorProtAudit", "Copy Protection Audit", function()
			local p = as_probe(); if p and p.copy_protection_audit then p.copy_protection_audit() end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorCtrlAudit", "Copy Control Release Audit", function()
			local p = as_probe(); if p and p.copy_control_release_audit then p.copy_control_release_audit() end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorClearLegacyCd", "Clear Legacy Cooldown (debug)", function()
			local p = as_probe(); if p and p.clear_legacy_cooldown then p.clear_legacy_cooldown() end
		end)

		add_text(alien_savior_group, "—— Suction（环形扫描 / 代理吸入；默认关）——")
		local suc_en = "QingRemasterOptions_AlienSaviorSuctionEnabled"
		ImGui.AddCheckbox(alien_savior_group, suc_en, "Enable Suction Debug", nil, false)
		ImGui.AddCallback(suc_en, ImGuiCallback.Edited, function(value)
			local p = as_probe(); if p and p.set_suction_debug then p.set_suction_debug({ enabled = value == true }) end
		end)
		local suc_ring = "QingRemasterOptions_AlienSaviorSuctionRings"
		ImGui.AddCheckbox(alien_savior_group, suc_ring, "Show Scan Rings", nil, false)
		ImGui.AddCallback(suc_ring, ImGuiCallback.Edited, function(value)
			local p = as_probe(); if p and p.set_suction_debug then p.set_suction_debug({ show_rings = value == true, enabled = true }) end
		end)
		local suc_pause = "QingRemasterOptions_AlienSaviorSuctionPause"
		ImGui.AddCheckbox(alien_savior_group, suc_pause, "Pause / Step Jobs", nil, false)
		ImGui.AddCallback(suc_pause, ImGuiCallback.Edited, function(value)
			local p = as_probe(); if p and p.set_suction_debug then p.set_suction_debug({ paused = value == true }) end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorForceScan", "Force Scan Complete", function()
			local p = as_probe(); if p and p.set_suction_debug then p.set_suction_debug({ force_scan = true }) end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorSuctionAudit", "Copy Suction Audit", function()
			local p = as_probe(); if p and p.copy_suction_audit then p.copy_suction_audit() end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorReapplyGrids", "Reapply Absorbed Grids", function()
			local p = as_probe(); if p and p.reapply_absorbed_grids then p.reapply_absorbed_grids() end
		end)
		local bounds_id = "QingRemasterOptions_AlienSaviorShowBounds"
		ImGui.AddCheckbox(alien_savior_group, bounds_id, "Show Flight Bounds", nil, false)
		ImGui.AddCallback(bounds_id, ImGuiCallback.Render, function()
			local md = require("Qing_Remaster_scripts.items.alien_savior.motion").get_debug()
			ImGui.UpdateData(bounds_id, ImGuiData.Value, md.show_bounds == true)
		end)
		ImGui.AddCallback(bounds_id, ImGuiCallback.Edited, function(value)
			local p = as_probe(); if p and p.set_show_bounds then p.set_show_bounds(value == true) end
		end)
		local pass_id = "QingRemasterOptions_AlienSaviorShowPass"
		ImGui.AddCheckbox(alien_savior_group, pass_id, "Show Front/Back Pass Mark", nil, false)
		ImGui.AddCallback(pass_id, ImGuiCallback.Render, function()
			local md = require("Qing_Remaster_scripts.items.alien_savior.motion").get_debug()
			ImGui.UpdateData(pass_id, ImGuiData.Value, md.show_pass == true)
		end)
		ImGui.AddCallback(pass_id, ImGuiCallback.Edited, function(value)
			local p = as_probe(); if p and p.set_show_pass then p.set_show_pass(value == true) end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorMotionReset", "Reset Motion Defaults", function()
			local p = as_probe(); if p and p.reset_motion then p.reset_motion() end
		end)

		add_text(alien_savior_group, "—— Bottom Core V4（Tint/Offset/Colorize 平滑；默认关）——")
		local core_freeze_id = "QingRemasterOptions_AlienSaviorCoreFreeze"
		ImGui.AddCheckbox(alien_savior_group, core_freeze_id, "Freeze Core State", nil, false)
		ImGui.AddCallback(core_freeze_id, ImGuiCallback.Render, function()
			local dbg = require("Qing_Remaster_scripts.items.alien_savior.light_controller").get_debug()
			ImGui.UpdateData(core_freeze_id, ImGuiData.Value, dbg.core_freeze == true)
		end)
		ImGui.AddCallback(core_freeze_id, ImGuiCallback.Edited, function(value)
			local p = as_probe(); if p and p.set_core_freeze then p.set_core_freeze(value == true) end
		end)
		local core_phases = { "auto", "ARRIVING", "ABDUCT_PLAYER", "TRANSIT_TO_CENTER", "ABDUCT_TARGETS", "LASER_SWEEP", "RELEASE_PLAYER", "DEPARTING" }
		local core_phase_id = "QingRemasterOptions_AlienSaviorCorePhase"
		ImGui.AddCombobox(alien_savior_group, core_phase_id, "Force Core Target Phase", function(index)
			local p = as_probe()
			local key = core_phases[(index or 0) + 1] or "auto"
			if p and p.set_core_force_phase then p.set_core_force_phase(key) end
		end, core_phases, 0)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorCoreReset", "Reset Core Defaults", function()
			local p = as_probe(); if p and p.reset_core_defaults then p.reset_core_defaults() end
		end)

		add_text(alien_savior_group, "—— Light Controls（默认关；仅影响当前救援视觉，不写存档）——")
		local light_en_id = "QingRemasterOptions_AlienSaviorLightEnabled"
		ImGui.AddCheckbox(alien_savior_group, light_en_id, "Enable Light Debug", nil, false)
		ImGui.AddCallback(light_en_id, ImGuiCallback.Render, function()
			local p = as_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData(light_en_id, ImGuiData.Value, cfg.light_enabled == true)
		end)
		ImGui.AddCallback(light_en_id, ImGuiCallback.Edited, function(value)
			local p = as_probe()
			if p and p.set_light_enabled then p.set_light_enabled(value == true) end
		end)

		local mode_labels = { "彩色环绕扫描", "全部白色常亮", "关闭全部灯光" }
		local mode_keys = { "rainbow", "white", "off" }
		local mode_id = "QingRemasterOptions_AlienSaviorLightMode"
		ImGui.AddCombobox(alien_savior_group, mode_id, "预览模式", function(index)
			local p = as_probe()
			local key = mode_keys[(index or 0) + 1] or "rainbow"
			if p and p.set_light_mode then p.set_light_mode(key) end
		end, mode_labels, 0)
		ImGui.AddCallback(mode_id, ImGuiCallback.Render, function()
			local p = as_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			local idx = 0
			for i, key in ipairs(mode_keys) do
				if cfg.light_mode == key then idx = i - 1 break end
			end
			ImGui.UpdateData(mode_id, ImGuiData.Value, idx)
		end)

		add_probe_drag(alien_savior_group, "QingRemasterOptions_AlienSaviorBright", "整体灯光亮度", function(v)
			local p = as_probe(); if p and p.set_master_brightness then p.set_master_brightness(v) end
		end, function()
			local p = as_probe(); local cfg = p and p.get_config and p.get_config() or {}; return cfg.master_brightness or 0.75
		end, 0.75, 0.01, 0.0, 1.0, "%.2f")

		add_probe_drag(alien_savior_group, "QingRemasterOptions_AlienSaviorColorCycle", "颜色轮转周期(f)", function(v)
			local p = as_probe(); if p and p.set_color_cycle then p.set_color_cycle(v) end
		end, function()
			local p = as_probe(); local cfg = p and p.get_config and p.get_config() or {}; return cfg.color_cycle or 90
		end, 90, 1, 15, 240, "%.0f")

		add_probe_drag(alien_savior_group, "QingRemasterOptions_AlienSaviorChaseCycle", "亮度追逐周期(f)", function(v)
			local p = as_probe(); if p and p.set_chase_cycle then p.set_chase_cycle(v) end
		end, function()
			local p = as_probe(); local cfg = p and p.get_config and p.get_config() or {}; return cfg.chase_cycle or 45
		end, 45, 1, 10, 180, "%.0f")

		local pause_id = "QingRemasterOptions_AlienSaviorLightPause"
		ImGui.AddCheckbox(alien_savior_group, pause_id, "Pause Light Anim", nil, false)
		ImGui.AddCallback(pause_id, ImGuiCallback.Render, function()
			local p = as_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData(pause_id, ImGuiData.Value, cfg.paused == true)
		end)
		ImGui.AddCallback(pause_id, ImGuiCallback.Edited, function(value)
			local p = as_probe()
			if p and p.set_light_paused then p.set_light_paused(value == true) end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorLightStep", "Step Light +1f", function()
			local p = as_probe()
			if p and p.step_light then p.step_light(1) end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorLightReset", "Reset Light Config", function()
			local p = as_probe()
			if p and p.reset_lights then p.reset_lights() end
		end)

		local layer_combo = "QingRemasterOptions_AlienSaviorLayerSelect"
		local layer_labels_cache = nil
		local function layer_labels()
			if layer_labels_cache then return layer_labels_cache end
			local p = as_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			layer_labels_cache = cfg.layer_names or { "body" }
			return layer_labels_cache
		end
		ImGui.AddCombobox(alien_savior_group, layer_combo, "Select Layer", function(index)
			local p = as_probe()
			if p and p.select_layer_index then p.select_layer_index(index) end
		end, layer_labels(), 0)
		ImGui.AddCallback(layer_combo, ImGuiCallback.Render, function()
			local p = as_probe()
			local idx = (p and p.get_selected_layer_index and p.get_selected_layer_index()) or 0
			ImGui.UpdateData(layer_combo, ImGuiData.Value, idx)
		end)

		add_probe_drag(alien_savior_group, "QingRemasterOptions_AlienSaviorLayerR", "Layer R", function(v)
			local p = as_probe()
			if not p then return end
			local dbg = require("Qing_Remaster_scripts.items.alien_savior.light_controller").get_debug()
			local ov = (dbg.layer_override[dbg.selected_layer]) or {}
			if p.set_selected_rgba then p.set_selected_rgba(v, ov.g or 1, ov.b or 1, ov.a or 1) end
		end, function()
			local dbg = require("Qing_Remaster_scripts.items.alien_savior.light_controller").get_debug()
			local ov = dbg.layer_override[dbg.selected_layer]
			return (ov and ov.r) or 1
		end, 1, 0.01, 0, 1, "%.2f")
		add_probe_drag(alien_savior_group, "QingRemasterOptions_AlienSaviorLayerG", "Layer G", function(v)
			local p = as_probe()
			if not p then return end
			local dbg = require("Qing_Remaster_scripts.items.alien_savior.light_controller").get_debug()
			local ov = (dbg.layer_override[dbg.selected_layer]) or {}
			if p.set_selected_rgba then p.set_selected_rgba(ov.r or 1, v, ov.b or 1, ov.a or 1) end
		end, function()
			local dbg = require("Qing_Remaster_scripts.items.alien_savior.light_controller").get_debug()
			local ov = dbg.layer_override[dbg.selected_layer]
			return (ov and ov.g) or 1
		end, 1, 0.01, 0, 1, "%.2f")
		add_probe_drag(alien_savior_group, "QingRemasterOptions_AlienSaviorLayerB", "Layer B", function(v)
			local p = as_probe()
			if not p then return end
			local dbg = require("Qing_Remaster_scripts.items.alien_savior.light_controller").get_debug()
			local ov = (dbg.layer_override[dbg.selected_layer]) or {}
			if p.set_selected_rgba then p.set_selected_rgba(ov.r or 1, ov.g or 1, v, ov.a or 1) end
		end, function()
			local dbg = require("Qing_Remaster_scripts.items.alien_savior.light_controller").get_debug()
			local ov = dbg.layer_override[dbg.selected_layer]
			return (ov and ov.b) or 1
		end, 1, 0.01, 0, 1, "%.2f")
		add_probe_drag(alien_savior_group, "QingRemasterOptions_AlienSaviorLayerA", "Layer A", function(v)
			local p = as_probe()
			if not p then return end
			local dbg = require("Qing_Remaster_scripts.items.alien_savior.light_controller").get_debug()
			local ov = (dbg.layer_override[dbg.selected_layer]) or {}
			if p.set_selected_rgba then p.set_selected_rgba(ov.r or 1, ov.g or 1, ov.b or 1, v) end
		end, function()
			local dbg = require("Qing_Remaster_scripts.items.alien_savior.light_controller").get_debug()
			local ov = dbg.layer_override[dbg.selected_layer]
			return (ov and ov.a) or 1
		end, 1, 0.01, 0, 1, "%.2f")

		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorHideLayer", "Hide Selected Layer", function()
			local p = as_probe(); if p and p.hide_selected_layer then p.hide_selected_layer(true) end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorShowLayer", "Show Selected Layer", function()
			local p = as_probe(); if p and p.hide_selected_layer then p.hide_selected_layer(false) end
		end)
		ImGui.AddButton(alien_savior_group, "QingRemasterOptions_AlienSaviorClearLayerOv", "Clear Selected Override", function()
			local p = as_probe(); if p and p.clear_selected_override then p.clear_selected_override() end
		end)

		local status_id = "QingRemasterOptions_AlienSaviorStatus"
		imgui_layout.add_wrapped_text(alien_savior_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = as_probe()
			imgui_layout.update_text(status_id, (p and p.get_summary and p.get_summary()) or "n/a")
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(alien_savior_group, as_probe, {
			id_prefix = "QingRemasterOptions_AlienSaviorOut",
			export_label = "Export Report",
		})
	end
	end

	local rooted_perf_group = start_probe_module(
		"audit_rooted_demon_performance", "根植之魔二阶段性能",
		"QingRemasterOptions_GroupRootedDemonPerformance")
	if rooted_perf_group then
		add_text(rooted_perf_group, "运行 40 道具场景后查看各步骤耗时。默认关闭；每 30 游戏帧采样一次，最多 120 次。")
		local function perf_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.rooted_demon_performance_probe")
		end
		local enable_id = "QingRemasterOptions_RootedDemonPerfEnabled"
		ImGui.AddCheckbox(rooted_perf_group, enable_id, "采集性能", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local probe = perf_probe()
			ImGui.UpdateData(enable_id, ImGuiData.Value,
				probe and probe.get_config and probe.get_config().enabled == true or false)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local probe = perf_probe()
			if probe and probe.set_enabled then probe.set_enabled(value == true) end
		end)
		local status_id = "QingRemasterOptions_RootedDemonPerfStatus"
		imgui_layout.add_wrapped_text(rooted_perf_group, status_id, "未采集")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local probe = perf_probe()
			imgui_layout.update_text(status_id,
				(probe and probe.get_summary and probe.get_summary()) or "n/a")
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(rooted_perf_group, perf_probe, {
			id_prefix = "QingRemasterOptions_RootedDemonPerfOut",
			export_label = "导出报告",
		})
	end

	local tiny_charge_group = start_probe_module(
		"audit_tiny_update_charge",
		"Tiny Update Charge",
		"QingRemasterOptions_GroupTinyUpdateCharge"
	)
	if tiny_charge_group then
	do
		add_text(tiny_charge_group, "观察微型更新的一次性充能修正。默认关闭，不写存档，不改充能。")
		local function charge_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.tiny_update_charge_probe")
		end
		local enable_id = "QingRemasterOptions_TinyUpdateChargeEnabled"
		ImGui.AddCheckbox(tiny_charge_group, enable_id, "Enable", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local probe = charge_probe()
			local cfg = probe and probe.get_config and probe.get_config() or {}
			ImGui.UpdateData(enable_id, ImGuiData.Value, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local probe = charge_probe()
			if probe and probe.set_enabled then probe.set_enabled(value == true) end
		end)
		local status_id = "QingRemasterOptions_TinyUpdateChargeStatus"
		imgui_layout.add_wrapped_text(tiny_charge_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local probe = charge_probe()
			imgui_layout.update_text(status_id, (probe and probe.get_summary and probe.get_summary()) or "n/a")
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(tiny_charge_group, charge_probe, {
			id_prefix = "QingRemasterOptions_TinyUpdateChargeOut",
			export_label = "Export Report",
		})
	end
	end

	local tiny_commit_group = start_probe_module(
		"audit_tiny_update_commit",
		"Tiny Update Commit",
		"QingRemasterOptions_GroupTinyUpdateCommit"
	)
	if tiny_commit_group then
	do
		add_text(tiny_commit_group, "读取最近 10 次微型更新提交。只看 GetSeed，不额外消耗 RNG。")
		local function commit_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.tiny_update_commit_probe")
		end
		local status_id = "QingRemasterOptions_TinyUpdateCommitStatus"
		imgui_layout.add_wrapped_text(tiny_commit_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local probe = commit_probe()
			imgui_layout.update_text(status_id, (probe and probe.get_summary and probe.get_summary()) or "n/a")
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(tiny_commit_group, commit_probe, {
			id_prefix = "QingRemasterOptions_TinyUpdateCommitOut",
			export_label = "Export Report",
		})
	end
	end

	local marble_group = start_probe_module(
		"audit_matryoshka_marbles_split",
		"Matryoshka Marbles Split",
		"QingRemasterOptions_GroupMatryoshkaMarblesSplit"
	)
	if marble_group then
	do
		add_text(marble_group, "套娃弹珠探针。默认关闭。Summary 记录分裂、寿命、视觉和悬浮验收。逐帧轨迹需另开 Full。不改变弹珠物理。")
		local function marble_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.matryoshka_marbles_split_probe")
		end
		local enable_id = "QingRemasterOptions_MatryoshkaSplitEnabled"
		ImGui.AddCheckbox(marble_group, enable_id, "Enable", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local probe = marble_probe()
			local cfg = probe and probe.get_config and probe.get_config() or {}
			ImGui.UpdateData(enable_id, ImGuiData.Value, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local probe = marble_probe()
			if probe and probe.set_enabled then probe.set_enabled(value == true) end
		end)
		local full_id = "QingRemasterOptions_MatryoshkaSplitFull"
		ImGui.AddCheckbox(marble_group, full_id, "Full trajectory", nil, false)
		ImGui.AddCallback(full_id, ImGuiCallback.Render, function()
			local probe = marble_probe()
			local cfg = probe and probe.get_config and probe.get_config() or {}
			ImGui.UpdateData(full_id, ImGuiData.Value, cfg.full_trajectory == true)
		end)
		ImGui.AddCallback(full_id, ImGuiCallback.Edited, function(value)
			local probe = marble_probe()
			if probe and probe.set_full_trajectory then probe.set_full_trajectory(value == true) end
		end)
		local status_id = "QingRemasterOptions_MatryoshkaSplitStatus"
		imgui_layout.add_wrapped_text(marble_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local probe = marble_probe()
			imgui_layout.update_text(status_id, (probe and probe.get_summary and probe.get_summary()) or "n/a")
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(marble_group, marble_probe, {
			id_prefix = "QingRemasterOptions_MatryoshkaSplitOut",
			export_label = "Export Report",
		})
	end
	end

	local sprite_splice_group = start_probe_module("audit_sprite_splice", "通用 Sprite 拼接 · sprite_splice", "QingRemasterOptions_GroupSpriteSpliceProbe")
	if sprite_splice_group then
	do
		add_text(sprite_splice_group, "独立于 NPC/Friend。Host full | 拼接 | Donor full。验证 canonical solve（cut-lock + tangent slide）。默认关闭，不写存档。")
		local enable_id = "QingRemasterOptions_SpriteSpliceProbeEnabled"
		ImGui.AddCheckbox(sprite_splice_group, enable_id, "启用 sprite_splice 独立探针", nil, false)
		local function get_splice_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.sprite_splice_probe")
		end
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local probe = get_splice_probe()
			local cfg = probe and probe.get_config and probe.get_config() or {enabled = false}
			ImGui.UpdateData(enable_id, ImGuiData.Value, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local probe = get_splice_probe()
			if probe and probe.set_enabled then probe.set_enabled(value == true) end
		end)
		local status_id = "QingRemasterOptions_SpriteSpliceProbeStatus"
		imgui_layout.add_wrapped_text(sprite_splice_group, status_id, "探针关闭。")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local probe = get_splice_probe()
			imgui_layout.update_text(status_id, (probe and probe.get_summary and probe.get_summary()) or "开发探针不可用。")
		end)
		imgui_layout.add_action_row(sprite_splice_group, {
			{id = "QingRemasterOptions_SSP_CS", label = "Gaper×Horf", on_click = function()
				local p = get_splice_probe(); if p and p.spawn_move_chase__attack_single then p.spawn_move_chase__attack_single() end
			end},
			{id = "QingRemasterOptions_SSP_CB", label = "Gaper×Pooter", on_click = function()
				local p = get_splice_probe(); if p and p.spawn_move_chase__attack_burst then p.spawn_move_chase__attack_burst() end
			end},
			{id = "QingRemasterOptions_SSP_CSp", label = "Gaper×Host", on_click = function()
				local p = get_splice_probe(); if p and p.spawn_move_chase__attack_spread then p.spawn_move_chase__attack_spread() end
			end},
		})
		imgui_layout.add_action_row(sprite_splice_group, {
			{id = "QingRemasterOptions_SSP_PS", label = "Charger×Horf", on_click = function()
				local p = get_splice_probe(); if p and p.spawn_move_pursuit__attack_single then p.spawn_move_pursuit__attack_single() end
			end},
			{id = "QingRemasterOptions_SSP_PB", label = "Charger×Pooter", on_click = function()
				local p = get_splice_probe(); if p and p.spawn_move_pursuit__attack_burst then p.spawn_move_pursuit__attack_burst() end
			end},
			{id = "QingRemasterOptions_SSP_PSp", label = "Charger×Host", on_click = function()
				local p = get_splice_probe(); if p and p.spawn_move_pursuit__attack_spread then p.spawn_move_pursuit__attack_spread() end
			end},
		})
		imgui_layout.add_action_row(sprite_splice_group, {
			{id = "QingRemasterOptions_SSP_WS", label = "Globin×Horf", on_click = function()
				local p = get_splice_probe(); if p and p.spawn_move_wander__attack_single then p.spawn_move_wander__attack_single() end
			end},
			{id = "QingRemasterOptions_SSP_WB", label = "Globin×Pooter", on_click = function()
				local p = get_splice_probe(); if p and p.spawn_move_wander__attack_burst then p.spawn_move_wander__attack_burst() end
			end},
			{id = "QingRemasterOptions_SSP_WSp", label = "Globin×Host", on_click = function()
				local p = get_splice_probe(); if p and p.spawn_move_wander__attack_spread then p.spawn_move_wander__attack_spread() end
			end},
		})
		imgui_layout.add_small_action_row(sprite_splice_group, {
			{id = "QingRemasterOptions_SSP_Clear", label = "Clear Pairs", on_click = function()
				local p = get_splice_probe(); if p and p.clear then p.clear() end
			end},
		})
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(sprite_splice_group, get_splice_probe, {
			id_prefix = "QingRemasterOptions_SpriteSpliceOut",
			export_label = "Export JSON",
			clear_label = "Clear pairs",
		})
	end
	end

	local consistance_group = start_probe_module("audit_consistance_holder", "实体一致性 V2 探针", "QingRemasterOptions_GroupConsistanceHolder")
	do
		add_text(consistance_group, "Family 生命周期验收探针。Core / Pedestal / Trace 为本轮主验收；Advanced 含 evidence / duplicate InitSeed 等。默认关闭实时汇总。")
		local enable_id = "QingRemasterOptions_ConsistanceHolderProbeEnabled"
		ImGui.AddCheckbox(consistance_group, enable_id, "启用实时汇总", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local holder = require("Qing_Remaster_scripts.others.Consistance_holder")
			ImGui.UpdateData(enable_id, ImGuiData.Value, holder.debug.probe_enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local holder = require("Qing_Remaster_scripts.others.Consistance_holder")
			holder.debug.probe_enabled = value == true
		end)
		ImGui.AddElement(consistance_group, "", ImGuiElement.SameLine)
		ImGui.AddButton(consistance_group, "QingRemasterOptions_ConsistanceHolderRefresh", "Refresh", function()
			require("Qing_Remaster_scripts.others.Consistance_holder").run_integrity_audit()
		end, false)
		ImGui.AddElement(consistance_group, "", ImGuiElement.SameLine)
		ImGui.AddButton(consistance_group, "QingRemasterOptions_ConsistanceHolderResetProbe", "关闭并清除", function()
			local holder = require("Qing_Remaster_scripts.others.Consistance_holder")
			holder.debug.probe_enabled = false
			holder.clear_family_probe()
			holder.reset_debug_stats()
			local rh = require("Qing_Remaster_scripts.others.Record_holder")
			if rh.reset_debug_stats then rh.reset_debug_stats() end
		end, true)

		local core_hdr = add_group(consistance_group, "QingRemasterOptions_ConsistanceCore", "Core")
		local core_id = "QingRemasterOptions_ConsistanceHolderCoreStatus"
		imgui_layout.add_wrapped_text(core_hdr, core_id, "探针关闭。")
		ImGui.AddCallback(core_id, ImGuiCallback.Render, function()
			local holder = require("Qing_Remaster_scripts.others.Consistance_holder")
			if not holder.debug.probe_enabled then
				imgui_layout.update_text(core_id, "实时汇总已关闭。")
				return
			end
			local s = holder.get_debug_snapshot()
			local integ = "尚未审计"
			if s.integrity_ok == true then integ = "OK"
			elseif s.integrity_ok == false then integ = "FAIL("..tostring(s.integrity_failures or 0)..")" end
			local body = string.format(
				"Records=%d  Buckets=%d  Links=%d\nClaims=%d  Pending=%d\nFamily supersede=%d  records dropped=%d\nFamily states dropped=%d  Empty family GC=%d\nMorph callbacks=%d (->0=%d)\nMorph Policy: SUPERSEDE=%d STATE_SWITCH=%d EMPTY=%d SAME=%d UNK=%d\nErrors=%d  Integrity=%s\n最近事件=%s",
				s.records, s.index_buckets, s.index_links,
				s.claims, s.pending_remove,
				s.family_supersedes, s.family_records_dropped,
				s.family_states_dropped, s.empty_collectible_families_cleaned,
				s.morph_callbacks, s.morph_callbacks_to_empty,
				(s.morph_policy and s.morph_policy.supersede) or 0,
				(s.morph_policy and s.morph_policy.state_switch) or 0,
				(s.morph_policy and s.morph_policy.empty_pending) or 0,
				(s.morph_policy and s.morph_policy.same_lifetime) or 0,
				(s.morph_policy and s.morph_policy.unknown) or 0,
				s.errors, integ, tostring(s.last_event or "none")
			)
			if s.last_error then body = body .. "\n最近错误：" .. tostring(s.last_error) end
			if s.top_owners and #s.top_owners > 0 then
				local parts = {}
				for _, row in ipairs(s.top_owners) do
					parts[#parts + 1] = string.format("%s=%d", row.owner, row.records)
				end
				body = body .. "\nTop Owners：" .. table.concat(parts, "；")
			end
			local rh = require("Qing_Remaster_scripts.others.Record_holder")
			if rh.get_debug_snapshot then
				local r = rh.get_debug_snapshot()
				body = body .. string.format("\nRecord_holder watchers=%d remove=%d", r.active_watchers, r.remove_triggers)
			end
			imgui_layout.update_text(core_id, body)
		end)

		local ped_hdr = add_group(consistance_group, "QingRemasterOptions_ConsistancePedestal", "Current Pedestal")
		local ped_id = "QingRemasterOptions_ConsistanceHolderPedestalStatus"
		imgui_layout.add_wrapped_text(ped_hdr, ped_id, "靠近道具底座后开启实时汇总。")
		ImGui.AddCallback(ped_id, ImGuiCallback.Render, function()
			local holder = require("Qing_Remaster_scripts.others.Consistance_holder")
			if not holder.debug.probe_enabled then
				imgui_layout.update_text(ped_id, "实时汇总已关闭。")
				return
			end
			local info = holder.inspect_nearest_collectible(160)
			if not info then
				imgui_layout.update_text(ped_id, "附近无 collectible pedestal。")
				return
			end
			local cycle = info.collectible_cycle or {}
			local cycle_txt = #cycle > 0 and table.concat(cycle, ",") or "(none)"
			local body = string.format(
				"Ptr=%s  Dist=%.0f\nInitSeed=%s  T/V/S=%s/%s/%s\nFamily Key=%s\nFamily Marker=%s\nOptionsPickupIndex=%s\nCycle=[%s]",
				tostring(info.ptr), tonumber(info.distance) or 0,
				tostring(info.init_seed), tostring(info.type), tostring(info.variant), tostring(info.subtype),
				tostring(info.family_key), tostring(info.family_marker or "(none)"),
				tostring(info.options_pickup_index), cycle_txt
			)
			body = body .. "\nBindings:"
			if #(info.bindings or {}) == 0 then
				body = body .. " (none)"
			else
				for _, b in ipairs(info.bindings) do
					body = body .. string.format("\n  %s -> id=%s subtype=%s mode=%s retain=%s",
						tostring(b.owner), tostring(b.id), tostring(b.record_subtype), tostring(b.match_mode), tostring(b.retain))
				end
			end
			body = body .. "\nFamily States:"
			if #(info.family_states or {}) == 0 then
				body = body .. " (none)"
			else
				for _, st in ipairs(info.family_states) do
					body = body .. string.format("\n  SubType %s -> [%s]", tostring(st.subtype), table.concat(st.owners or {}, ","))
				end
			end
			local probe = holder.debug.family_probe_last
			if probe then
				body = body .. string.format("\nFamily Probe：ok=%s mode=%s stored=%s display=%s visits=%s family=%s",
					tostring(probe.ok), tostring(probe.mode), tostring(probe.stored_subtype), tostring(probe.subtype),
					tostring(probe.visit_count), tostring(probe.family))
			end
			imgui_layout.update_text(ped_id, body)
		end)

		local trace_hdr = add_group(consistance_group, "QingRemasterOptions_ConsistanceTrace", "Lifecycle Trace")
		local trace_id = "QingRemasterOptions_ConsistanceHolderTraceStatus"
		imgui_layout.add_wrapped_text(trace_hdr, trace_id, "尚无事件。")
		ImGui.AddCallback(trace_id, ImGuiCallback.Render, function()
			local holder = require("Qing_Remaster_scripts.others.Consistance_holder")
			if not holder.debug.probe_enabled then
				imgui_layout.update_text(trace_id, "实时汇总已关闭。")
				return
			end
			local s = holder.get_debug_snapshot()
			local lines = {}
			for _, row in ipairs(s.lifecycle_trace or {}) do
				lines[#lines + 1] = string.format(
					"f%d r%s %s ptr=%s old=%s new=%s os=%s ns=%s drop=%s owner=%s",
					tonumber(row.frame) or 0, tostring(row.room), tostring(row.event),
					tostring(row.ptr or "-"), tostring(row.old_family or "-"), tostring(row.new_family or "-"),
					tostring(row.old_subtype or "-"), tostring(row.new_subtype or "-"),
					tostring(row.dropped or "-"), tostring(row.owner or "-")
				)
			end
			imgui_layout.update_text(trace_id, #lines > 0 and table.concat(lines, "\n") or "尚无 lifecycle 事件。")
		end)

		local test_hdr = add_group(consistance_group, "QingRemasterOptions_ConsistanceTests", "Tests")
		imgui_layout.add_action_row(test_hdr, {
			{id = "QingRemasterOptions_ConsistanceHolderAudit", label = "Integrity Audit", on_click = function()
				require("Qing_Remaster_scripts.others.Consistance_holder").run_integrity_audit()
			end},
			{id = "QingRemasterOptions_ConsistanceHolderResetCounters", label = "Reset Counters", on_click = function()
				require("Qing_Remaster_scripts.others.Consistance_holder").reset_debug_stats()
			end},
			{id = "QingRemasterOptions_ConsistanceClearFamilyProbe", label = "Clear Family Probe", on_click = function()
				require("Qing_Remaster_scripts.others.Consistance_holder").clear_family_probe()
			end},
		})
		ImGui.AddButton(test_hdr, "QingRemasterOptions_ConsistanceAttachFamilyProbe", "Attach Family Probe（最近底座）", function()
			require("Qing_Remaster_scripts.others.Consistance_holder").attach_family_probe()
		end, true)

		local adv_hdr = add_group(consistance_group, "QingRemasterOptions_ConsistanceAdvanced", "Advanced")
		local adv_id = "QingRemasterOptions_ConsistanceHolderAdvancedStatus"
		imgui_layout.add_wrapped_text(adv_hdr, adv_id, "展开后显示 evidence / scopes / match modes。")
		ImGui.AddCallback(adv_id, ImGuiCallback.Render, function()
			local holder = require("Qing_Remaster_scripts.others.Consistance_holder")
			if not holder.debug.probe_enabled then
				imgui_layout.update_text(adv_id, "实时汇总已关闭。")
				return
			end
			local s = holder.get_debug_snapshot()
			local body = string.format(
				"schema=%d  scopes room/level/run=%d/%d/%d  retained=%d  orphans=%d\nevidence records/groups=%d/%d\nparam conflicts=%d  ambiguous=%d  similarity=%d  fallback=%d\nmatch exact/S/V/T=%d/%d/%d/%d\nentity supersede=%d drop=%d empty_snap=%d",
				s.schema_version, s.room, s.level, s.run, s.retained, s.orphans,
				s.evidence_records, s.evidence_groups,
				s.parameter_conflicts, s.ambiguous_matches, s.similarity_resolutions, s.ambiguous_fallbacks,
				s.match_modes.exact, s.match_modes.ignore_subtype, s.match_modes.ignore_variant, s.match_modes.ignore_type,
				s.supersedes, s.supersede_records_dropped, s.supersede_empty_snapshots
			)
			local report = holder.debug.last_report
			if report then
				body = body .. string.format("\n最近审计：%s failures=%d frame=%d", report.ok and "OK" or "FAIL", report.failure_count or #report.failures, report.frame)
				if report.failures and #report.failures > 0 then body = body .. "\n" .. table.concat(report.failures, "；") end
			end
			local duplicate = holder.debug.last_duplicate_test
			if duplicate then
				body = body .. string.format("\nDuplicate InitSeed：%s phase=%s", tostring(duplicate.ok), tostring(duplicate.phase))
			end
			imgui_layout.update_text(adv_id, body)
		end)
		ImGui.AddButton(adv_hdr, "QingRemasterOptions_ConsistanceHolderDuplicateTest", "Duplicate InitSeed Test", function()
			require("Qing_Remaster_scripts.others.Consistance_holder").run_duplicate_spawn_test()
		end)
	end
	local empress_d6_group = start_probe_module("audit_empress_d6_timeline", "Empress D6 Timeline", "QingRemasterOptions_GroupEmpressD6Timeline")
	if empress_d6_group then
	do
		local function emp_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.empress_d6_timeline_probe")
		end
		add_text(empress_d6_group, "Run T1/T2 后请立刻取消暂停。探针会等 Morph 后首帧 UPDATE 再 Copy。")
		local emp_status_id = "QingRemasterOptions_EmpressD6Status"
		imgui_layout.add_wrapped_text(empress_d6_group, emp_status_id, "Idle")
		ImGui.AddCallback(emp_status_id, ImGuiCallback.Render, function()
			local p = emp_probe()
			local body = (p and p.get_status_text and p.get_status_text()) or "probe unavailable"
			imgui_layout.update_text(emp_status_id, body)
		end)
		imgui_layout.add_action_row(empress_d6_group, {
			{id = "QingRemasterOptions_EmpressD6RunT1", label = "Run T1", on_click = function()
				local p = emp_probe(); if p and p.run_case_t1 then p.run_case_t1() end
			end},
			{id = "QingRemasterOptions_EmpressD6RunT2", label = "Run T2", on_click = function()
				local p = emp_probe(); if p and p.run_case_t2 then p.run_case_t2() end
			end},
			{id = "QingRemasterOptions_EmpressD6RunT3", label = "Run T3", on_click = function()
				local p = emp_probe(); if p and p.run_case_t3 then p.run_case_t3() end
			end},
			{id = "QingRemasterOptions_EmpressD6RunT4", label = "Run T4", on_click = function()
				local p = emp_probe(); if p and p.run_case_t4 then p.run_case_t4() end
			end},
		})
		add_text(empress_d6_group, "手动（可选）：只 Arm 最近底座，再自己放 D6。")
		imgui_layout.add_small_action_row(empress_d6_group, {
			{id = "QingRemasterOptions_EmpressD6ArmTouched", label = "Arm Touched", on_click = function()
				local p = emp_probe(); if p and p.arm_touched_d6 then p.arm_touched_d6() end
			end},
			{id = "QingRemasterOptions_EmpressD6ArmUntouched", label = "Arm Untouched", on_click = function()
				local p = emp_probe(); if p and p.arm_untouched_d6 then p.arm_untouched_d6() end
			end},
			{id = "QingRemasterOptions_EmpressD6ArmHold", label = "Arm Hold", on_click = function()
				local p = emp_probe(); if p and p.arm_touched_hold then p.arm_touched_hold() end
			end},
			{id = "QingRemasterOptions_EmpressD6ArmEngine", label = "Arm Engine T4", on_click = function()
				local p = emp_probe(); if p and p.arm_engine_only_touched_d6 then p.arm_engine_only_touched_d6() end
			end},
		})
		imgui_layout.add_small_action_row(empress_d6_group, {
			{id = "QingRemasterOptions_EmpressD6CopyTimeline", label = "Copy Timeline Text", on_click = function()
				local p = emp_probe(); if p and p.copy_timeline then p.copy_timeline() end
			end},
		})
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(empress_d6_group, emp_probe, {
			id_prefix = "QingRemasterOptions_EmpressD6Out",
			export_label = "Export JSONL",
		})
	end
	end

	local tianyi_walk_group = start_probe_module(
		"audit_tianyi_walk_clock",
		"Tianyi Walk Clock",
		"QingRemasterOptions_GroupTianyiWalkClock"
	)
	if tianyi_walk_group then
	do
		local function walk_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.tianyi_walk_clock_probe")
		end
		add_text(tianyi_walk_group, "Walk* only. body_anim must equal render_anim, and body_frame must advance.")
		local enable_id = "QingRemasterOptions_TianyiWalkClockEnabled"
		ImGui.AddCheckbox(tianyi_walk_group, enable_id, "Enable", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = walk_probe()
			local cfg = p and p.get_config and p.get_config() or {enabled = false}
			ImGui.UpdateData(enable_id, ImGuiData.Value, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = walk_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		local status_id = "QingRemasterOptions_TianyiWalkClockStatus"
		imgui_layout.add_wrapped_text(tianyi_walk_group, status_id, "off")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = walk_probe()
			imgui_layout.update_text(status_id, (p and p.get_summary and p.get_summary()) or "n/a")
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(tianyi_walk_group, walk_probe, {
			id_prefix = "QingRemasterOptions_TianyiWalkClockOut",
			export_label = "Export JSONL",
		})
	end
	end

	local pag_group = start_probe_module(
		"audit_player_appearance_ghost",
		"Player Appearance Ghost Validation",
		"QingRemasterOptions_GroupPlayerAppearanceGhost"
	)
	if pag_group then
	do
		local function pag_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.player_appearance_ghost_probe")
		end
		add_text(
			pag_group,
			"One-click suite for shared ghost clocks (idle/walk/head/fly/Extra/TianYi). Does not change player inventory."
		)
		imgui_layout.add_small_action_row(pag_group, {
			{id = "QingRemasterOptions_PAGRun", label = "Run Full Suite", on_click = function()
				local p = pag_probe(); if p and p.run_full_suite then p.run_full_suite() end
			end},
			{id = "QingRemasterOptions_PAGStop", label = "Stop", on_click = function()
				local p = pag_probe(); if p and p.stop then p.stop() end
			end},
			{id = "QingRemasterOptions_PAGCopy", label = "Copy Last Report", on_click = function()
				local p = pag_probe(); if p and p.copy_full_report then p.copy_full_report() end
			end},
		})
		local show_id = "QingRemasterOptions_PAGShowGhosts"
		ImGui.AddCheckbox(pag_group, show_id, "Show Probe Ghosts", nil, true)
		ImGui.AddCallback(show_id, ImGuiCallback.Render, function()
			local p = pag_probe()
			local cfg = p and p.get_config and p.get_config() or {show_ghosts = true}
			ImGui.UpdateData(show_id, ImGuiData.Value, cfg.show_ghosts ~= false)
		end)
		ImGui.AddCallback(show_id, ImGuiCallback.Edited, function(value)
			local p = pag_probe()
			if p and p.set_show_ghosts then p.set_show_ghosts(value == true) end
		end)
		local verbose_id = "QingRemasterOptions_PAGVerbose"
		ImGui.AddCheckbox(pag_group, verbose_id, "Verbose Overlay", nil, false)
		ImGui.AddCallback(verbose_id, ImGuiCallback.Render, function()
			local p = pag_probe()
			local cfg = p and p.get_config and p.get_config() or {verbose = false}
			ImGui.UpdateData(verbose_id, ImGuiData.Value, cfg.verbose == true)
		end)
		ImGui.AddCallback(verbose_id, ImGuiCallback.Edited, function(value)
			local p = pag_probe()
			if p and p.set_verbose then p.set_verbose(value == true) end
		end)
		local status_id = "QingRemasterOptions_PAGStatus"
		imgui_layout.add_wrapped_text(pag_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = pag_probe()
			imgui_layout.update_text(status_id, (p and p.get_summary and p.get_summary()) or "n/a")
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(pag_group, pag_probe, {
			id_prefix = "QingRemasterOptions_PAGOut",
			export_label = "Export Report",
		})
	end
	end

	local remaster_ghost_group = start_probe_module(
		"audit_remaster_ghost_render",
		"Remaster Ghost Az Repro",
		"QingRemasterOptions_GroupRemasterGhostRender"
	)
	if remaster_ghost_group then
	do
		local function ghost_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.remaster_ghost_render_probe")
		end
		add_text(
			remaster_ghost_group,
			"Az Walk / Composite (includes Hit keep-overlay). Spawn 2spooky or Spoon Bender then Run 4 Directions / Composite Suite. Summary: family_base, participation, 2spooky_idle, overlay_extra, hit_no_head."
		)
		imgui_layout.add_small_action_row(remaster_ghost_group, {
			{id = "QingRemasterOptions_RemasterGhostSpawnAz", label = "Spawn Az Ghost", on_click = function()
				local p = ghost_probe(); if p and p.spawn_az_ghost then p.spawn_az_ghost() end
			end},
			{id = "QingRemasterOptions_RemasterGhostSpawnSpooky", label = "Spawn 2spooky", on_click = function()
				local p = ghost_probe(); if p and p.spawn_2spooky_ghost then p.spawn_2spooky_ghost() end
			end},
			{id = "QingRemasterOptions_RemasterGhostSpawnOverlay", label = "Spawn Head Overlay", on_click = function()
				local p = ghost_probe(); if p and p.spawn_overlay_head_ghost then p.spawn_overlay_head_ghost() end
			end},
			{id = "QingRemasterOptions_RemasterGhostStop", label = "Stop", on_click = function()
				local p = ghost_probe(); if p and p.stop then p.stop() end
			end},
		})
		imgui_layout.add_small_action_row(remaster_ghost_group, {
			{id = "QingRemasterOptions_RemasterGhostRun4", label = "Run 4 Directions", on_click = function()
				local p = ghost_probe(); if p and p.run_four_directions then p.run_four_directions() end
			end},
			{id = "QingRemasterOptions_RemasterGhostRunSuite", label = "Run Composite Suite", on_click = function()
				local p = ghost_probe(); if p and p.run_composite_suite then p.run_composite_suite() end
			end},
		})
		ImGui.AddButton(remaster_ghost_group, "QingRemasterOptions_RemasterGhostSpawnCap", "Spawn Captured Player Ghost", function()
			local p = ghost_probe(); if p and p.spawn_captured_player_ghost then p.spawn_captured_player_ghost() end
		end)
		local status_id = "QingRemasterOptions_RemasterGhostStatus"
		imgui_layout.add_wrapped_text(remaster_ghost_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = ghost_probe()
			imgui_layout.update_text(status_id, (p and p.get_summary and p.get_summary()) or "n/a")
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(remaster_ghost_group, ghost_probe, {
			id_prefix = "QingRemasterOptions_RemasterGhostOut",
			export_label = "Export JSONL",
		})
	end
	end

	local player_vfx_layer_group = start_probe_module(
		"audit_player_vfx_layer",
		"玩家特效前后层深度",
		"QingRemasterOptions_GroupPlayerVfxLayer"
	)
	if player_vfx_layer_group then
	do
		local function get_pvfx_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.player_vfx_layer_probe")
		end
		add_text(
			player_vfx_layer_group,
			"Phase1：不透明红方块 B=背后，青方块 F=身前。先切 Behind only / Front only 看遮挡，再 Both。Effect 标记与 PRE/POST 对照可分开关。无敌时 Effect 不应闪；PRE 可能闪。启用 → 选层 → Arm case → Finish Case。默认关闭。"
		)
		local enable_id = "QingRemasterOptions_PlayerVfxLayerEnabled"
		ImGui.AddCheckbox(player_vfx_layer_group, enable_id, "启用", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = get_pvfx_probe()
			local cfg = p and p.get_config and p.get_config() or {enabled = false}
			ImGui.UpdateData(enable_id, ImGuiData.Value, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = get_pvfx_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		local show_fx_id = "QingRemasterOptions_PlayerVfxLayerShowFx"
		ImGui.AddCheckbox(player_vfx_layer_group, show_fx_id, "显示 Effect 标记", nil, true)
		ImGui.AddCallback(show_fx_id, ImGuiCallback.Render, function()
			local p = get_pvfx_probe()
			local cfg = p and p.get_config and p.get_config() or {show_effect = true}
			ImGui.UpdateData(show_fx_id, ImGuiData.Value, cfg.show_effect ~= false)
		end)
		ImGui.AddCallback(show_fx_id, ImGuiCallback.Edited, function(value)
			local p = get_pvfx_probe()
			if p and p.set_show_effect then p.set_show_effect(value == true) end
		end)
		local show_cb_id = "QingRemasterOptions_PlayerVfxLayerShowCb"
		ImGui.AddCheckbox(player_vfx_layer_group, show_cb_id, "显示 PRE/POST 对照标记", nil, true)
		ImGui.AddCallback(show_cb_id, ImGuiCallback.Render, function()
			local p = get_pvfx_probe()
			local cfg = p and p.get_config and p.get_config() or {show_player_cb = true}
			ImGui.UpdateData(show_cb_id, ImGuiData.Value, cfg.show_player_cb ~= false)
		end)
		ImGui.AddCallback(show_cb_id, ImGuiCallback.Edited, function(value)
			local p = get_pvfx_probe()
			if p and p.set_show_player_cb then p.set_show_player_cb(value == true) end
		end)
		imgui_layout.add_small_action_row(player_vfx_layer_group, {
			{id = "QingRemasterOptions_PlayerVfxLayerBehindOnly", label = "Behind only", on_click = function()
				local p = get_pvfx_probe(); if p and p.set_layer_mode then p.set_layer_mode("behind") end
			end},
			{id = "QingRemasterOptions_PlayerVfxLayerFrontOnly", label = "Front only", on_click = function()
				local p = get_pvfx_probe(); if p and p.set_layer_mode then p.set_layer_mode("front") end
			end},
			{id = "QingRemasterOptions_PlayerVfxLayerBoth", label = "Both", on_click = function()
				local p = get_pvfx_probe(); if p and p.set_layer_mode then p.set_layer_mode("both") end
			end},
		})
		imgui_layout.add_small_action_row(player_vfx_layer_group, {
			{id = "QingRemasterOptions_PlayerVfxLayerArmNormal", label = "Arm Normal", on_click = function()
				local p = get_pvfx_probe(); if p and p.arm_normal then p.arm_normal() end
			end},
			{id = "QingRemasterOptions_PlayerVfxLayerArmInvuln", label = "Arm Invuln", on_click = function()
				local p = get_pvfx_probe(); if p and p.arm_invuln then p.arm_invuln() end
			end},
			{id = "QingRemasterOptions_PlayerVfxLayerArmOffset", label = "Arm Offset", on_click = function()
				local p = get_pvfx_probe(); if p and p.arm_offset then p.arm_offset() end
			end},
			{id = "QingRemasterOptions_PlayerVfxLayerFinish", label = "Finish Case", on_click = function()
				local p = get_pvfx_probe(); if p and p.finish_case then p.finish_case() end
			end},
		})
		imgui_layout.add_small_action_row(player_vfx_layer_group, {
			{id = "QingRemasterOptions_PlayerVfxLayerClear", label = "Clear Suite", on_click = function()
				local p = get_pvfx_probe(); if p and p.clear then p.clear() end
			end},
		})
		local status_id = "QingRemasterOptions_PlayerVfxLayerStatus"
		imgui_layout.add_wrapped_text(player_vfx_layer_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = get_pvfx_probe()
			imgui_layout.update_text(status_id, (p and p.get_summary and p.get_summary()) or "n/a")
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(player_vfx_layer_group, get_pvfx_probe, {
			id_prefix = "QingRemasterOptions_PlayerVfxLayerOut",
			export_label = "Export JSONL",
		})
	end
	end

	local held_group = start_probe_module(
		"audit_held_reward_consistency",
		"Held Reward Consistency",
		"QingRemasterOptions_GroupHeldRewardConsistency"
	)
	if held_group then
	do
		local function held_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.held_reward_consistency_probe")
		end
		add_text(
			held_group,
			"Checks Ghost held preview subtype/family vs spawned pickup for fixed rewards (rune/tarot/collectible/...)."
		)
		imgui_layout.add_small_action_row(held_group, {
			{id = "QingRemasterOptions_HeldRewardRun", label = "Run Suite", on_click = function()
				local p = held_probe(); if p and p.run_suite then p.run_suite() end
			end},
			{id = "QingRemasterOptions_HeldRewardStop", label = "Clear", on_click = function()
				local p = held_probe(); if p and p.clear then p.clear() end
			end},
			{id = "QingRemasterOptions_HeldRewardCopy", label = "Copy Summary", on_click = function()
				local p = held_probe(); if p and p.copy_summary then p.copy_summary() end
			end},
		})
		local status_id = "QingRemasterOptions_HeldRewardStatus"
		imgui_layout.add_wrapped_text(held_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = held_probe()
			imgui_layout.update_text(status_id, (p and p.get_summary and p.get_summary()) or "n/a")
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(held_group, held_probe, {
			id_prefix = "QingRemasterOptions_HeldRewardOut",
			export_label = "Export Report",
		})
	end
	end

	local pill_vis_group = start_probe_module(
		"audit_pocket_pill_visual",
		"Pocket Pill Visual",
		"QingRemasterOptions_GroupPocketPillVisual"
	)
	if pill_vis_group then
	do
		local function pill_vis_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.pocket_pill_visual_probe")
		end
		add_text(
			pill_vis_group,
			"EntityConfig vs XML strict subtype for PillColor (gold/horse included). No dummy spawn."
		)
		imgui_layout.add_small_action_row(pill_vis_group, {
			{id = "QingRemasterOptions_PocketPillRun", label = "Run Suite", on_click = function()
				local p = pill_vis_probe(); if p and p.run_suite then p.run_suite() end
			end},
			{id = "QingRemasterOptions_PocketPillClear", label = "Clear", on_click = function()
				local p = pill_vis_probe(); if p and p.clear then p.clear() end
			end},
			{id = "QingRemasterOptions_PocketPillCopy", label = "Copy Summary", on_click = function()
				local p = pill_vis_probe(); if p and p.copy_summary then p.copy_summary() end
			end},
		})
		local status_id = "QingRemasterOptions_PocketPillStatus"
		imgui_layout.add_wrapped_text(pill_vis_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = pill_vis_probe()
			imgui_layout.update_text(status_id, (p and p.get_summary and p.get_summary()) or "n/a")
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(pill_vis_group, pill_vis_probe, {
			id_prefix = "QingRemasterOptions_PocketPillOut",
			export_label = "Export JSONL",
		})
	end
	end

	local devil_heart_group = start_probe_module(
		"audit_devils_heart_debt",
		"Devil's Heart Debt",
		"QingRemasterOptions_GroupDevilsHeartDebt"
	)
	if devil_heart_group then
	do
		local function dh_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.devils_heart_debt_probe")
		end
		add_text(
			devil_heart_group,
			"Multi-pact + 3 followers + random debt warning. Force pact/convert/kill, Fast Warning/Final/Collect."
		)
		local enable_id = "QingRemasterOptions_DevilsHeartDebtEnabled"
		ImGui.AddCheckbox(devil_heart_group, enable_id, "Enable", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = dh_probe()
			local cfg = p and p.get_config and p.get_config() or {enabled = false}
			ImGui.UpdateData(enable_id, ImGuiData.Value, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = dh_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		imgui_layout.add_small_action_row(devil_heart_group, {
			{id = "QingRemasterOptions_DevilsHeartForcePact", label = "Force Pact Nearest", on_click = function()
				local p = dh_probe(); if p and p.force_pact_nearest then p.force_pact_nearest() end
			end},
			{id = "QingRemasterOptions_DevilsHeartForceHostile", label = "Pact Hostile", on_click = function()
				local p = dh_probe(); if p and p.force_pact_nearest_hostile then p.force_pact_nearest_hostile() end
			end},
			{id = "QingRemasterOptions_DevilsHeartForceFriendly", label = "Pact Friendly", on_click = function()
				local p = dh_probe(); if p and p.force_pact_nearest_friendly then p.force_pact_nearest_friendly() end
			end},
		})
		imgui_layout.add_small_action_row(devil_heart_group, {
			{id = "QingRemasterOptions_DevilsHeartFriendlyUp", label = "Test Friendly Upgrade", on_click = function()
				local p = dh_probe(); if p and p.test_friendly_upgrade then p.test_friendly_upgrade() end
			end},
		})
		imgui_layout.add_small_action_row(devil_heart_group, {
			{id = "QingRemasterOptions_DevilsHeartConvert", label = "Convert Host", on_click = function()
				local p = dh_probe(); if p and p.convert_host then p.convert_host() end
			end},
			{id = "QingRemasterOptions_DevilsHeartKillHost", label = "Kill Host", on_click = function()
				local p = dh_probe(); if p and p.kill_host then p.kill_host() end
			end},
			{id = "QingRemasterOptions_DevilsHeartLethal", label = "Lethal Host Hit", on_click = function()
				local p = dh_probe(); if p and p.damage_host_to_lethal then p.damage_host_to_lethal() end
			end},
		})
		imgui_layout.add_small_action_row(devil_heart_group, {
			{id = "QingRemasterOptions_DevilsHeartKill", label = "Kill Player", on_click = function()
				local p = dh_probe(); if p and p.force_player_kill then p.force_player_kill() end
			end},
			{id = "QingRemasterOptions_DevilsHeartPlus", label = "Debt +1", on_click = function()
				local p = dh_probe(); if p and p.debt_plus then p.debt_plus() end
			end},
			{id = "QingRemasterOptions_DevilsHeartMinus", label = "Debt -1", on_click = function()
				local p = dh_probe(); if p and p.debt_minus then p.debt_minus() end
			end},
		})
		imgui_layout.add_small_action_row(devil_heart_group, {
			{id = "QingRemasterOptions_DevilsHeartFastWarn", label = "Fast Warning", on_click = function()
				local p = dh_probe(); if p and p.fast_warning then p.fast_warning() end
			end},
			{id = "QingRemasterOptions_DevilsHeartFastFinal", label = "Fast Final", on_click = function()
				local p = dh_probe(); if p and p.fast_final then p.fast_final() end
			end},
			{id = "QingRemasterOptions_DevilsHeartForceCollect", label = "Force Collect", on_click = function()
				local p = dh_probe(); if p and p.force_collect then p.force_collect() end
			end},
		})
		imgui_layout.add_small_action_row(devil_heart_group, {
			{id = "QingRemasterOptions_DevilsHeartForceSeija", label = "Force Seija On", on_click = function()
				local p = dh_probe(); if p and p.set_force_seija then p.set_force_seija(true) end
			end},
			{id = "QingRemasterOptions_DevilsHeartForceSeijaOff", label = "Force Seija Off", on_click = function()
				local p = dh_probe(); if p and p.set_force_seija then p.set_force_seija(false) end
			end},
			{id = "QingRemasterOptions_DevilsHeartSeijaKeep", label = "Test Seija Debt Keep", on_click = function()
				local p = dh_probe(); if p and p.test_seija_debt_keep then p.test_seija_debt_keep() end
			end},
		})
		imgui_layout.add_small_action_row(devil_heart_group, {
			{id = "QingRemasterOptions_DevilsHeartSeijaZero", label = "Test Seija Debt Zero", on_click = function()
				local p = dh_probe(); if p and p.test_seija_debt_zero then p.test_seija_debt_zero() end
			end},
		})
		local status_id = "QingRemasterOptions_DevilsHeartDebtStatus"
		imgui_layout.add_wrapped_text(devil_heart_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = dh_probe()
			imgui_layout.update_text(status_id, (p and p.get_summary and p.get_summary()) or "n/a")
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(devil_heart_group, dh_probe, {
			id_prefix = "QingRemasterOptions_DevilsHeartDebtOut",
			export_label = "Export Report",
		})
	end
	end

	local sting_r_dmg_group = start_probe_module(
		"audit_sting_reversed_damage",
		"Sting Reversed Damage",
		"QingRemasterOptions_GroupStingReversedDamage"
	)
	if sting_r_dmg_group then
	do
		local function sting_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.sting_reversed_damage_probe")
		end
		add_text(
			sting_r_dmg_group,
			"Reversed Sting damage lifecycle: outer+DAMAGE_CLONES, post frames, death, remove, retarget. Damage math unchanged."
		)
		local enable_id = "QingRemasterOptions_StingReversedDamageEnabled"
		ImGui.AddCheckbox(sting_r_dmg_group, enable_id, "Enable", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = sting_probe()
			local cfg = p and p.get_config and p.get_config() or {enabled = false}
			ImGui.UpdateData(enable_id, ImGuiData.Value, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = sting_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		local status_id = "QingRemasterOptions_StingReversedDamageStatus"
		imgui_layout.add_wrapped_text(sting_r_dmg_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = sting_probe()
			imgui_layout.update_text(status_id, (p and p.get_summary and p.get_summary()) or "n/a")
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(sting_r_dmg_group, sting_probe, {
			id_prefix = "QingRemasterOptions_StingReversedDamageOut",
			export_label = "Export JSONL",
		})
	end
	end

	local gold_rush_group = start_probe_module(
		"audit_gold_rush_grid",
		"Gold Rush Grid",
		"QingRemasterOptions_GroupGoldRushGrid"
	)
	if gold_rush_group then
	do
		local function gr_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.gold_rush_grid_probe")
		end
		add_text(
			gold_rush_group,
			"Fools-gold convert via grid_rock_topology.replace_rocks (big members allowed, per-cell). Force Convert Big picks first big member. Phases: before_detach … after_topology_sync … after_visual."
		)
		local enable_id = "QingRemasterOptions_GoldRushGridEnabled"
		ImGui.AddCheckbox(gold_rush_group, enable_id, "Enable", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = gr_probe()
			local cfg = p and p.get_config and p.get_config() or {enabled = false}
			ImGui.UpdateData(enable_id, ImGuiData.Value, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = gr_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		local overlay_id = "QingRemasterOptions_GoldRushGridOverlay"
		ImGui.AddCheckbox(gold_rush_group, overlay_id, "Overlay labels", nil, false)
		ImGui.AddCallback(overlay_id, ImGuiCallback.Render, function()
			local p = gr_probe()
			local cfg = p and p.get_config and p.get_config() or {overlay = false}
			ImGui.UpdateData(overlay_id, ImGuiData.Value, cfg.overlay == true)
		end)
		ImGui.AddCallback(overlay_id, ImGuiCallback.Edited, function(value)
			local p = gr_probe()
			if p and p.set_overlay then p.set_overlay(value == true) end
		end)
		imgui_layout.add_small_action_row(gold_rush_group, {
			{id = "QingRemasterOptions_GoldRushForceConvert", label = "Force Convert Now", on_click = function()
				local p = gr_probe(); if p and p.force_convert_now then p.force_convert_now() end
			end},
			{id = "QingRemasterOptions_GoldRushForceConvertBig", label = "Force Convert Big", on_click = function()
				local p = gr_probe(); if p and p.force_convert_big_member then p.force_convert_big_member() end
			end},
			{id = "QingRemasterOptions_GoldRushCaptureCurrent", label = "Capture Current", on_click = function()
				local p = gr_probe(); if p and p.capture_current_room then p.capture_current_room() end
			end},
			{id = "QingRemasterOptions_GoldRushDumpTracked", label = "Dump Tracked", on_click = function()
				local p = gr_probe(); if p and p.dump_tracked then p.dump_tracked() end
			end},
		})
		imgui_layout.add_small_action_row(gold_rush_group, {
			{id = "QingRemasterOptions_GoldRushSpawnRats", label = "Spawn Rat Nest", on_click = function()
				local p = gr_probe(); if p and p.spawn_rat_nest then p.spawn_rat_nest() end
			end},
		})
		local status_id = "QingRemasterOptions_GoldRushGridStatus"
		imgui_layout.add_wrapped_text(gold_rush_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = gr_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			imgui_layout.update_text(
				status_id,
				string.format(
					"en=%s ov=%s ev=%s anom=%s pend=%s phase=%s aff=%s",
					tostring(cfg.enabled),
					tostring(cfg.overlay),
					tostring(cfg.event_count),
					tostring(cfg.anomaly_count),
					tostring(cfg.pending_audits),
					tostring(cfg.last_phase),
					tostring(cfg.last_affected_count)
				)
			)
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(gold_rush_group, gr_probe, {
			id_prefix = "QingRemasterOptions_GoldRushGridOut",
			export_label = "Export Report",
		})
	end
	end

	local spectralsword_hud_group = start_probe_module(
		"audit_spectralsword_hud",
		"妖刀 · HUD 布局标定",
		"QingRemasterOptions_GroupSpectralswordHud"
	)
	if spectralsword_hud_group then
	do
		local function ss_hud_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.spectralsword_hud_probe")
		end
		add_text(
			spectralsword_hud_group,
			"Display presets 互斥：Native only=只看原版；Native+Fixed/Live=原版+红色 Probe；Production=只看妖刀自绘。正式 layout / 玩法开关在 Debug > Items > 妖刀·逢魔。"
		)
		local enable_id = "QingRemasterOptions_SpectralswordHudEnabled"
		ImGui.AddCheckbox(spectralsword_hud_group, enable_id, "Enable", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = ss_hud_probe()
			ImGui.UpdateData(enable_id, ImGuiData.Value, p and p.is_enabled and p.is_enabled() == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = ss_hud_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)

		local function add_mode_button(id, label, on_click)
			ImGui.AddButton(spectralsword_hud_group, id, label, on_click)
		end

		local function add_flag_checkbox(id, label, getter, setter, default_on)
			ImGui.AddCheckbox(spectralsword_hud_group, id, label, nil, default_on == true)
			ImGui.AddCallback(id, ImGuiCallback.Render, function()
				local p = ss_hud_probe()
				ImGui.UpdateData(id, ImGuiData.Value, p and p[getter] and p[getter]() == true)
			end)
			ImGui.AddCallback(id, ImGuiCallback.Edited, function(value)
				local p = ss_hud_probe()
				if p and p[setter] then p[setter](value == true) end
			end)
		end

		add_separator(spectralsword_hud_group)
		add_text(spectralsword_hud_group, "=== Display ===")
		add_mode_button("QingRemasterOptions_SSHudModeNative", "Native only", function()
			local p = ss_hud_probe(); if p and p.set_display_mode then p.set_display_mode("native_only") end
		end)
		ImGui.AddElement(spectralsword_hud_group, "", ImGuiElement.SameLine)
		add_mode_button("QingRemasterOptions_SSHudModeFixed", "Native + Fixed Probe", function()
			local p = ss_hud_probe(); if p and p.set_display_mode then p.set_display_mode("native_fixed") end
		end)
		add_mode_button("QingRemasterOptions_SSHudModeLive", "Native + Live Probe", function()
			local p = ss_hud_probe(); if p and p.set_display_mode then p.set_display_mode("native_live") end
		end)
		ImGui.AddElement(spectralsword_hud_group, "", ImGuiElement.SameLine)
		add_mode_button("QingRemasterOptions_SSHudModeProd", "Production", function()
			local p = ss_hud_probe(); if p and p.set_display_mode then p.set_display_mode("production") end
		end)

		add_text(spectralsword_hud_group, "Reference groups (Fixed/Live modes)")
		add_flag_checkbox("QingRemasterOptions_SSHudRefRes", "Resource", "get_draw_resource_reference", "set_draw_resource_reference", true)
		add_flag_checkbox("QingRemasterOptions_SSHudRefCap", "Cap", "get_draw_cap_reference", "set_draw_cap_reference", true)
		add_flag_checkbox("QingRemasterOptions_SSHudRefStat", "Stat", "get_draw_stat_reference", "set_draw_stat_reference", true)
		add_flag_checkbox("QingRemasterOptions_SSHudRefDeal", "Deal", "get_draw_deal_reference", "set_draw_deal_reference", true)

		add_text(spectralsword_hud_group, "Overlay")
		add_mode_button("QingRemasterOptions_SSHudOverlaySide", "Side by side", function()
			local p = ss_hud_probe(); if p and p.set_overlay_mode then p.set_overlay_mode("side") end
		end)
		ImGui.AddElement(spectralsword_hud_group, "", ImGuiElement.SameLine)
		add_mode_button("QingRemasterOptions_SSHudOverlayOverlap", "Overlap", function()
			local p = ss_hud_probe(); if p and p.set_overlay_mode then p.set_overlay_mode("overlap") end
		end)
		add_flag_checkbox("QingRemasterOptions_SSHudPlainAB", "Draw plain candidate (red)", "get_draw_plain_candidate", "set_draw_plain_candidate", false)
		add_flag_checkbox("QingRemasterOptions_SSHudOutlineAB", "Draw outlined candidate (cyan)", "get_draw_outlined_candidate", "set_draw_outlined_candidate", false)
		add_flag_checkbox("QingRemasterOptions_SSHudMarkers", "Draw x/o markers", "get_draw_markers", "set_draw_markers", false)

		add_separator(spectralsword_hud_group)
		add_text(spectralsword_hud_group, "=== Probe overlay fonts (observation only) ===")
		add_text(spectralsword_hud_group, "Deal source")
		add_mode_button("QingRemasterOptions_SSHudDealSrcFixed", "Fixed", function()
			local p = ss_hud_probe(); if p and p.set_deal_source then p.set_deal_source("fixed") end
		end)
		ImGui.AddElement(spectralsword_hud_group, "", ImGuiElement.SameLine)
		add_mode_button("QingRemasterOptions_SSHudDealSrcFound", "Found-HUD computed", function()
			local p = ss_hud_probe(); if p and p.set_deal_source then p.set_deal_source("found_hud") end
		end)
		add_text(spectralsword_hud_group, "Probe Stat Font")
		add_mode_button("QingRemasterOptions_SSHudFontPlain", "luamini", function()
			local p = ss_hud_probe(); if p and p.set_stat_font_mode then p.set_stat_font_mode("plain") end
		end)
		ImGui.AddElement(spectralsword_hud_group, "", ImGuiElement.SameLine)
		add_mode_button("QingRemasterOptions_SSHudFontOutline", "luaminioutlined", function()
			local p = ss_hud_probe(); if p and p.set_stat_font_mode then p.set_stat_font_mode("outlined") end
		end)
		add_text(spectralsword_hud_group, "Probe Deal Font")
		add_mode_button("QingRemasterOptions_SSHudDealFontPlain", "luamini", function()
			local p = ss_hud_probe(); if p and p.set_deal_font_mode then p.set_deal_font_mode("plain") end
		end)
		ImGui.AddElement(spectralsword_hud_group, "", ImGuiElement.SameLine)
		add_mode_button("QingRemasterOptions_SSHudDealFontOutline", "luaminioutlined", function()
			local p = ss_hud_probe(); if p and p.set_deal_font_mode then p.set_deal_font_mode("outlined") end
		end)
		add_text(spectralsword_hud_group, "Probe Deal format")
		add_mode_button("QingRemasterOptions_SSHudPctInt", "Integer", function()
			local p = ss_hud_probe(); if p and p.set_deal_percent_mode then p.set_deal_percent_mode("integer") end
		end)
		ImGui.AddElement(spectralsword_hud_group, "", ImGuiElement.SameLine)
		add_mode_button("QingRemasterOptions_SSHudPctDec", "1 decimal", function()
			local p = ss_hud_probe(); if p and p.set_deal_percent_mode then p.set_deal_percent_mode("one_decimal") end
		end)

		local status_id = "QingRemasterOptions_SpectralswordHudStatus"
		imgui_layout.add_wrapped_text(spectralsword_hud_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = ss_hud_probe()
			imgui_layout.update_text(status_id, (p and p.get_status_text and p.get_status_text()) or "n/a")
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(spectralsword_hud_group, ss_hud_probe, {
			id_prefix = "QingRemasterOptions_SpectralswordHudOut",
			export_label = "Export JSONL",
		})
	end
	end

	local spectralsword_input_group = start_probe_module(
		"audit_spectralsword_input",
		"妖刀 · 输入手感",
		"QingRemasterOptions_GroupSpectralswordInput"
	)
	if spectralsword_input_group then
	do
		local function ss_input_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.spectralsword_input_probe")
		end
		add_text(
			spectralsword_input_group,
			"录 MC_POST_PLAYER_UPDATE 面板输入：triggered/pressed/held/pending/executed 与 ghost_state。最近约 180 帧。"
		)
		local enable_id = "QingRemasterOptions_SpectralswordInputEnabled"
		ImGui.AddCheckbox(spectralsword_input_group, enable_id, "Enable", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = ss_input_probe()
			ImGui.UpdateData(enable_id, ImGuiData.Value, p and p.is_enabled and p.is_enabled() == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = ss_input_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		ImGui.AddButton(spectralsword_input_group, "QingRemasterOptions_SpectralswordInputClear", "Clear", function()
			local p = ss_input_probe()
			if p and p.clear then p.clear() end
		end)
		local status_id = "QingRemasterOptions_SpectralswordInputStatus"
		imgui_layout.add_wrapped_text(spectralsword_input_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = ss_input_probe()
			imgui_layout.update_text(status_id, (p and p.get_status_text and p.get_status_text()) or "n/a")
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(spectralsword_input_group, ss_input_probe, {
			id_prefix = "QingRemasterOptions_SpectralswordInputOut",
			export_label = "Export JSONL",
		})
	end
	end

	local spectralsword_lazarus_group = start_probe_module(
		"audit_spectralsword_lazarus_identity",
		"Spectralsword Lazarus Identity",
		"QingRemasterOptions_GroupSpectralswordLazarus"
	)
	if spectralsword_lazarus_group then
	do
		local live = require("Qing_Remaster_scripts.debug.probe_live_cache")
		local function laz_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.spectralsword_lazarus_identity_probe")
		end
		add_text(
			spectralsword_lazarus_group,
			"Narrow Lazarus Flip identity probe. Records PlayerType/Ptr/__Index/InitSeed/Flip and planetarium calc notes. No getter calls."
		)
		local enable_id = "QingRemasterOptions_SpectralswordLazarusEnabled"
		ImGui.AddCheckbox(spectralsword_lazarus_group, enable_id, "Enable", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = laz_probe()
			live.update_checkbox_if_changed(enable_id, p and p.is_enabled and p.is_enabled() == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = laz_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		ImGui.AddButton(spectralsword_lazarus_group, "QingRemasterOptions_SpectralswordLazarusClear", "Clear", function()
			local p = laz_probe(); if p and p.clear then p.clear() end
		end)
		local status_id = "QingRemasterOptions_SpectralswordLazarusStatus"
		imgui_layout.add_wrapped_text(spectralsword_lazarus_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = laz_probe()
			local text = p and p.status_text and p.status_text() or "idle"
			ImGui.UpdateData(status_id, ImGuiData.Label, text)
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(spectralsword_lazarus_group, laz_probe, {
			id_prefix = "QingRemasterOptions_SpectralswordLazarusOut",
			export_label = "Export JSONL",
		})
	end
	end

	local cursed_mask_link_group = start_probe_module(
		"audit_cursed_mask_craft_link",
		"Cursed Mask Craft Linker",
		"QingRemasterOptions_GroupCursedMaskCraftLink"
	)
	if cursed_mask_link_group then
	do
		local live = require("Qing_Remaster_scripts.debug.probe_live_cache")
		local function craft_link_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.cursed_mask_craft_link_probe")
		end
		add_text(
			cursed_mask_link_group,
			"Tracks Flight Cursed_Linker InitSeed / FrameCount. Respawning every frame keeps Idle alpha at 0. Expect one stable seed while rotating."
		)
		local enable_id = "QingRemasterOptions_CursedMaskCraftLinkEnabled"
		ImGui.AddCheckbox(cursed_mask_link_group, enable_id, "Enable", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = craft_link_probe()
			local cfg = p and p.get_config and p.get_config() or {enabled = false}
			live.update_checkbox_if_changed(enable_id, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = craft_link_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		imgui_layout.add_action_row(cursed_mask_link_group, {
			{id = "QingRemasterOptions_CursedMaskCraftLinkClear", label = "Clear", on_click = function()
				local p = craft_link_probe(); if p and p.clear then p.clear() end
			end},
		})
		local status_id = "QingRemasterOptions_CursedMaskCraftLinkStatus"
		imgui_layout.add_wrapped_text(cursed_mask_link_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = craft_link_probe()
			live.update_text_if_changed(status_id, (p and p.get_summary and p.get_summary()) or "n/a")
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(cursed_mask_link_group, craft_link_probe, {
			id_prefix = "QingRemasterOptions_CursedMaskCraftLinkOut",
			export_label = "Export JSONL",
		})
	end
	end

	local pin62_group = start_probe_module(
		"audit_pin_62_visibility",
		"Pin 62 Visibility",
		"QingRemasterOptions_GroupPin62Visibility"
	)
	if pin62_group then
	do
		local live = require("Qing_Remaster_scripts.debug.probe_live_cache")
		local function pin62_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.pin_62_visibility_probe")
		end
		add_text(
			pin62_group,
			"Type 62 event-driven visibility probe (POST_UPDATE only). Transition rows on State/anim/Visible/topology. Overlay default off. Periodic default off."
		)
		local enable_id = "QingRemasterOptions_Pin62Enabled"
		ImGui.AddCheckbox(pin62_group, enable_id, "Enable", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = pin62_probe()
			local cfg = p and p.get_config and p.get_config() or {enabled = false}
			live.update_checkbox_if_changed(enable_id, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = pin62_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		local overlay_id = "QingRemasterOptions_Pin62Overlay"
		ImGui.AddCheckbox(pin62_group, overlay_id, "Overlay", nil, false)
		ImGui.AddCallback(overlay_id, ImGuiCallback.Render, function()
			local p = pin62_probe()
			local cfg = p and p.get_config and p.get_config() or {overlay = false}
			live.update_checkbox_if_changed(overlay_id, cfg.overlay == true)
		end)
		ImGui.AddCallback(overlay_id, ImGuiCallback.Edited, function(value)
			local p = pin62_probe()
			if p and p.set_overlay then p.set_overlay(value == true) end
		end)
		imgui_layout.add_action_row(pin62_group, {
			{id = "QingRemasterOptions_Pin62Clear", label = "Clear", on_click = function()
				local p = pin62_probe(); if p and p.clear then p.clear() end
			end},
		})
		local status_id = "QingRemasterOptions_Pin62Status"
		imgui_layout.add_wrapped_text(pin62_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = pin62_probe()
			live.update_text_if_changed(status_id, (p and p.get_summary and p.get_summary()) or "n/a")
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(pin62_group, pin62_probe, {
			id_prefix = "QingRemasterOptions_Pin62Out",
			export_label = "Export JSONL",
		})
	end
	end

	local monstro20_group = start_probe_module(
		"audit_monstro_20_visibility",
		"Monstro 20 Visibility",
		"QingRemasterOptions_GroupMonstro20Visibility"
	)
	if monstro20_group then
	do
		local live = require("Qing_Remaster_scripts.debug.probe_live_cache")
		local function monstro20_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.monstro_20_visibility_probe")
		end
		add_text(
			monstro20_group,
			"v6: Export/Copy always include rolling timeline (no Dump). Continuous = lightweight only (alpha_scans=0). Deep Capture = one-shot full crop. One timeline row per game frame."
		)
		local enable_id = "QingRemasterOptions_Monstro20Enabled"
		ImGui.AddCheckbox(monstro20_group, enable_id, "Enable", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = monstro20_probe()
			local cfg = p and p.get_config and p.get_config() or {enabled = false}
			live.update_checkbox_if_changed(enable_id, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = monstro20_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		local overlay_id = "QingRemasterOptions_Monstro20Overlay"
		ImGui.AddCheckbox(monstro20_group, overlay_id, "Overlay", nil, true)
		ImGui.AddCallback(overlay_id, ImGuiCallback.Render, function()
			local p = monstro20_probe()
			local cfg = p and p.get_config and p.get_config() or {overlay = true}
			live.update_checkbox_if_changed(overlay_id, cfg.overlay == true)
		end)
		ImGui.AddCallback(overlay_id, ImGuiCallback.Edited, function(value)
			local p = monstro20_probe()
			if p and p.set_overlay then p.set_overlay(value == true) end
		end)
		local timeline_id = "QingRemasterOptions_Monstro20Timeline"
		ImGui.AddCheckbox(monstro20_group, timeline_id, "Continuous Lightweight Timeline", nil, true)
		ImGui.AddCallback(timeline_id, ImGuiCallback.Render, function()
			local p = monstro20_probe()
			local cfg = p and p.get_config and p.get_config() or {continuous_timeline = true}
			live.update_checkbox_if_changed(timeline_id, cfg.continuous_timeline == true)
		end)
		ImGui.AddCallback(timeline_id, ImGuiCallback.Edited, function(value)
			local p = monstro20_probe()
			if p and p.set_continuous_timeline then p.set_continuous_timeline(value == true) end
		end)
		local ghost_id = "QingRemasterOptions_Monstro20Ghost"
		ImGui.AddCheckbox(monstro20_group, ghost_id, "Hat Ghost", nil, true)
		ImGui.AddCallback(ghost_id, ImGuiCallback.Render, function()
			local p = monstro20_probe()
			local cfg = p and p.get_config and p.get_config() or {hat_ghost = true}
			live.update_checkbox_if_changed(ghost_id, cfg.hat_ghost == true)
		end)
		ImGui.AddCallback(ghost_id, ImGuiCallback.Edited, function(value)
			local p = monstro20_probe()
			if p and p.set_hat_ghost then p.set_hat_ghost(value == true) end
		end)
		imgui_layout.add_action_row(monstro20_group, {
			{id = "QingRemasterOptions_Monstro20Deep", label = "Deep Capture Current Frame", on_click = function()
				local p = monstro20_probe(); if p and p.deep_capture_current then p.deep_capture_current() end
			end},
			{id = "QingRemasterOptions_Monstro20Mark", label = "Mark Current Moment", on_click = function()
				local p = monstro20_probe(); if p and p.mark_current_moment then p.mark_current_moment() end
			end},
			{id = "QingRemasterOptions_Monstro20ClearTL", label = "Clear Timeline", on_click = function()
				local p = monstro20_probe(); if p and p.clear_timeline then p.clear_timeline() end
			end},
		})
		imgui_layout.add_action_row(monstro20_group, {
			{id = "QingRemasterOptions_Monstro20Freeze", label = "Freeze Ghost", on_click = function()
				local p = monstro20_probe(); if p and p.freeze_current_ghost then p.freeze_current_ghost() end
			end},
			{id = "QingRemasterOptions_Monstro20Unfreeze", label = "Clear Frozen", on_click = function()
				local p = monstro20_probe(); if p and p.clear_frozen_ghost then p.clear_frozen_ghost() end
			end},
			{id = "QingRemasterOptions_Monstro20Clear", label = "Clear All", on_click = function()
				local p = monstro20_probe(); if p and p.clear then p.clear() end
			end},
		})
		local status_id = "QingRemasterOptions_Monstro20Status"
		imgui_layout.add_wrapped_text(monstro20_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = monstro20_probe()
			live.update_text_if_changed(status_id, (p and p.get_summary and p.get_summary()) or "n/a")
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(monstro20_group, monstro20_probe, {
			id_prefix = "QingRemasterOptions_Monstro20Out",
			export_label = "Export JSONL",
		})
	end
	end

	local swarm884_group = start_probe_module(
		"audit_swarm_spider_884_visibility",
		"Swarm Spider 884 Gate Decomposition",
		"QingRemasterOptions_GroupSwarm884Visibility"
	)
	if swarm884_group then
	do
		local live = require("Qing_Remaster_scripts.debug.probe_live_cache")
		local function swarm884_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.swarm_spider_884_visibility_probe")
		end
		add_text(
			swarm884_group,
			"v4: production ScanScalpY = full_center_column (no coarse Y). Expect scalp hit iff Deep Capture local_with_crop_offset hit on same crop. Idle/Hop must not false-empty; Monstro JumpDown blank column still empty→hide."
		)
		local enable_id = "QingRemasterOptions_Swarm884Enabled"
		ImGui.AddCheckbox(swarm884_group, enable_id, "Enable", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = swarm884_probe()
			local cfg = p and p.get_config and p.get_config() or {enabled = false}
			live.update_checkbox_if_changed(enable_id, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = swarm884_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		local overlay_id = "QingRemasterOptions_Swarm884Overlay"
		ImGui.AddCheckbox(swarm884_group, overlay_id, "Overlay", nil, true)
		ImGui.AddCallback(overlay_id, ImGuiCallback.Render, function()
			local p = swarm884_probe()
			local cfg = p and p.get_config and p.get_config() or {overlay = true}
			live.update_checkbox_if_changed(overlay_id, cfg.overlay == true)
		end)
		ImGui.AddCallback(overlay_id, ImGuiCallback.Edited, function(value)
			local p = swarm884_probe()
			if p and p.set_overlay then p.set_overlay(value == true) end
		end)
		local timeline_id = "QingRemasterOptions_Swarm884Timeline"
		ImGui.AddCheckbox(swarm884_group, timeline_id, "Continuous Lightweight Timeline", nil, true)
		ImGui.AddCallback(timeline_id, ImGuiCallback.Render, function()
			local p = swarm884_probe()
			local cfg = p and p.get_config and p.get_config() or {continuous_timeline = true}
			live.update_checkbox_if_changed(timeline_id, cfg.continuous_timeline == true)
		end)
		ImGui.AddCallback(timeline_id, ImGuiCallback.Edited, function(value)
			local p = swarm884_probe()
			if p and p.set_continuous_timeline then p.set_continuous_timeline(value == true) end
		end)
		local ghost_id = "QingRemasterOptions_Swarm884Ghost"
		ImGui.AddCheckbox(swarm884_group, ghost_id, "Hat Ghost", nil, true)
		ImGui.AddCallback(ghost_id, ImGuiCallback.Render, function()
			local p = swarm884_probe()
			local cfg = p and p.get_config and p.get_config() or {hat_ghost = true}
			live.update_checkbox_if_changed(ghost_id, cfg.hat_ghost == true)
		end)
		ImGui.AddCallback(ghost_id, ImGuiCallback.Edited, function(value)
			local p = swarm884_probe()
			if p and p.set_hat_ghost then p.set_hat_ghost(value == true) end
		end)
		imgui_layout.add_action_row(swarm884_group, {
			{id = "QingRemasterOptions_Swarm884Deep", label = "Deep Capture Current Frame", on_click = function()
				local p = swarm884_probe(); if p and p.deep_capture_current then p.deep_capture_current() end
			end},
			{id = "QingRemasterOptions_Swarm884Mark", label = "Mark Current Moment", on_click = function()
				local p = swarm884_probe(); if p and p.mark_current_moment then p.mark_current_moment() end
			end},
			{id = "QingRemasterOptions_Swarm884ClearTL", label = "Clear Timeline", on_click = function()
				local p = swarm884_probe(); if p and p.clear_timeline then p.clear_timeline() end
			end},
		})
		imgui_layout.add_action_row(swarm884_group, {
			{id = "QingRemasterOptions_Swarm884Freeze", label = "Freeze Ghost", on_click = function()
				local p = swarm884_probe(); if p and p.freeze_current_ghost then p.freeze_current_ghost() end
			end},
			{id = "QingRemasterOptions_Swarm884Unfreeze", label = "Clear Frozen", on_click = function()
				local p = swarm884_probe(); if p and p.clear_frozen_ghost then p.clear_frozen_ghost() end
			end},
			{id = "QingRemasterOptions_Swarm884Clear", label = "Clear All", on_click = function()
				local p = swarm884_probe(); if p and p.clear then p.clear() end
			end},
		})
		local status_id = "QingRemasterOptions_Swarm884Status"
		imgui_layout.add_wrapped_text(swarm884_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = swarm884_probe()
			live.update_text_if_changed(status_id, (p and p.get_summary and p.get_summary()) or "n/a")
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(swarm884_group, swarm884_probe, {
			id_prefix = "QingRemasterOptions_Swarm884Out",
			export_label = "Export JSONL",
		})
	end
	end

	local essm_hg_group = start_probe_module(
		"audit_essm_hourglass",
		"ESSM Hourglass Rollback",
		"QingRemasterOptions_GroupEssmHourglass"
	)
	if essm_hg_group then
	do
		local function hg_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.essm_hourglass_probe")
		end
		add_text(
			essm_hg_group,
			"HG-1：进未访问 B 房 → Arm Write Marker（写 QingEssmHourglassProbe）→ 用发光沙漏回 A → 再进 B。证据在 module-local，不写 save.elses。Copy Summary 看 ESSM_REWINDS / ESSM_DOES_NOT_REWIND。"
		)
		local enable_id = "QingRemasterOptions_EssmHourglassEnabled"
		ImGui.AddCheckbox(essm_hg_group, enable_id, "Enable", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = hg_probe()
			local cfg = p and p.get_config and p.get_config() or {enabled = false}
			ImGui.UpdateData(enable_id, ImGuiData.Value, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = hg_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		imgui_layout.add_action_row(essm_hg_group, {
			{id = "QingRemasterOptions_EssmHourglassArm", label = "Arm Write Marker", on_click = function()
				local p = hg_probe(); if p and p.arm_write_marker then p.arm_write_marker() end
			end},
		})
		local status_id = "QingRemasterOptions_EssmHourglassStatus"
		imgui_layout.add_wrapped_text(essm_hg_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = hg_probe()
			local body = (p and p.get_status_text and p.get_status_text()) or "probe unavailable"
			imgui_layout.update_text(status_id, body)
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(essm_hg_group, hg_probe, {
			id_prefix = "QingRemasterOptions_EssmHourglassOut",
			export_label = "Export JSONL",
		})
	end
	end

	local portal_rw_group = start_probe_module(
		"audit_portal_restore_rewind",
		"Portal Restore Rewind",
		"QingRemasterOptions_GroupPortalRestoreRewind"
	)
	if portal_rw_group then
	do
		local function portal_rw_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.portal_restore_rewind_probe")
		end
		add_text(
			portal_rw_group,
			"Rollback State Probe v5. Enable, spawn a Wizard portal, leave, rewind. Copy Summary: wizard map + portal seed across SAVE / REWIND / GENERATION_CHECK / RESTORE_RESULT."
		)
		local enable_id = "QingRemasterOptions_PortalRestoreRewindEnabled"
		ImGui.AddCheckbox(portal_rw_group, enable_id, "Enable", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = portal_rw_probe()
			local cfg = p and p.get_config and p.get_config() or {enabled = false}
			ImGui.UpdateData(enable_id, ImGuiData.Value, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = portal_rw_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		imgui_layout.add_small_action_row(portal_rw_group, {
			{id = "QingRemasterOptions_PortalRestoreRewindClear", label = "Clear", on_click = function()
				local p = portal_rw_probe(); if p and p.clear then p.clear() end
			end},
			{id = "QingRemasterOptions_PortalRestoreRewindCopy", label = "Copy Summary", on_click = function()
				local p = portal_rw_probe(); if p and p.copy_summary then p.copy_summary() end
			end},
		})
		local status_id = "QingRemasterOptions_PortalRestoreRewindStatus"
		imgui_layout.add_wrapped_text(portal_rw_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = portal_rw_probe()
			imgui_layout.update_text(status_id, (p and p.get_summary and p.get_summary()) or "n/a")
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(portal_rw_group, portal_rw_probe, {
			id_prefix = "QingRemasterOptions_PortalRestoreRewindOut",
			export_label = "Export JSONL",
		})
	end
	end

	local fixed_corridor_group = start_probe_module(
		"audit_fixed_corridor",
		"楼层直道探针",
		"QingRemasterOptions_GroupFixedCorridor"
	)
	if fixed_corridor_group then
	do
		local live = require("Qing_Remaster_scripts.debug.probe_live_cache")
		local function corridor_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.fixed_corridor_probe")
		end
		add_text(
			fixed_corridor_group,
			"楼层直道探针→黄金罗盘正式运行时。武装=预约下一层直道（Root Seed）。正式玩法不依赖本页。"
		)
		imgui_layout.add_small_action_row(fixed_corridor_group, {
			{id = "QingRemasterOptions_FixedCorridorGive", label = "给予黄金罗盘", on_click = function()
				local p = corridor_probe(); if p and p.give_compass then p.give_compass() end
			end},
			{id = "QingRemasterOptions_FixedCorridorArmMain", label = "武装下一层直道测试", on_click = function()
				local p = corridor_probe(); if p and p.arm_main_test then p.arm_main_test() end
			end},
			{id = "QingRemasterOptions_FixedCorridorForceMom", label = "下次直道强制妈腿", on_click = function()
				local p = corridor_probe(); if p and p.arm_force_mom_next then p.arm_force_mom_next() end
			end},
			{id = "QingRemasterOptions_FixedCorridorForceBlueWomb", label = "强制尝试蓝子宫门", on_click = function()
				local p = corridor_probe()
				if p and p.force_try_blue_womb_door then
					p.force_try_blue_womb_door("imgui_force_blue_womb")
				end
			end},
			{id = "QingRemasterOptions_FixedCorridorMirrorSpecials", label = "对照镜子特殊房", on_click = function()
				local p = corridor_probe()
				if p and p.log_mirror_special_compare then
					p.log_mirror_special_compare("imgui_mirror_special_compare")
				elseif p and p.prepare_mirror_corridor then
					p.prepare_mirror_corridor("imgui_prepare_mirror")
				end
			end},
			{id = "QingRemasterOptions_FixedCorridorClear", label = "Clear Events", on_click = function()
				local p = corridor_probe(); if p and p.clear then p.clear() end
			end},
		})
		do
			local seija_id = "QingRemasterOptions_FixedCorridorForceSeija"
			local gc_item = require("Qing_Remaster_scripts.items.Item_Golden_Compass")
			ImGui.AddCheckbox(fixed_corridor_group, seija_id, "强制 Seija", function(value)
				if gc_item.debug_set_force_seija then
					gc_item.debug_set_force_seija(value == true)
				end
			end, gc_item.debug_force_seija and gc_item.debug_force_seija() or false)
			ImGui.AddCallback(seija_id, ImGuiCallback.Render, function()
				if gc_item.debug_force_seija then
					live.update_checkbox_if_changed(seija_id, gc_item.debug_force_seija() == true)
				end
			end)
			ImGui.AddButton(fixed_corridor_group, "QingRemasterOptions_FixedCorridorSeijaRestore", "恢复 Seija 默认", function()
				if gc_item.debug_set_force_seija then
					gc_item.debug_set_force_seija(false)
				end
			end)
		end
		local status_id = "QingRemasterOptions_FixedCorridorStatus"
		imgui_layout.add_wrapped_text(fixed_corridor_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = corridor_probe()
			local text_body = p and p.status_text and p.status_text() or "idle"
			ImGui.UpdateData(status_id, ImGuiData.Label, text_body)
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(fixed_corridor_group, corridor_probe, {
			id_prefix = "QingRemasterOptions_FixedCorridorOut",
			export_label = "Export JSONL",
		})

		-- —— 支线门状态（独立只读探针；默认关闭）——
		local door_sec = imgui_layout.add_section(
			fixed_corridor_group,
			"QingRemasterOptions_FixedCorridorDoorSec",
			"支线门状态"
		)
		local function door_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.golden_compass_door_probe")
		end
		add_text(
			door_sec,
			"只读观察 State/PreviousState/VarData/主Sprite/ExtraSprite。不调用 Open/Close/Play/SetFrame。默认关闭。"
		)
		local door_en = "QingRemasterOptions_FixedCorridorDoorEnabled"
		ImGui.AddCheckbox(door_sec, door_en, "启用支线门探针", nil, false)
		ImGui.AddCallback(door_en, ImGuiCallback.Render, function()
			local p = door_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			live.update_checkbox_if_changed(door_en, cfg.enabled == true)
		end)
		ImGui.AddCallback(door_en, ImGuiCallback.Edited, function(value)
			local p = door_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		local door_burst_mode = "QingRemasterOptions_FixedCorridorDoorBurstMode"
		ImGui.AddCheckbox(door_sec, door_burst_mode, "记录方式：连续90帧（否=状态变化）", nil, false)
		ImGui.AddCallback(door_burst_mode, ImGuiCallback.Render, function()
			local p = door_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			live.update_checkbox_if_changed(door_burst_mode, cfg.record_mode == "burst")
		end)
		ImGui.AddCallback(door_burst_mode, ImGuiCallback.Edited, function(value)
			local p = door_probe()
			if p and p.set_record_mode then
				p.set_record_mode(value == true and "burst" or "change")
			end
		end)
		imgui_layout.add_small_action_row(door_sec, {
			{id = "QingRemasterOptions_FixedCorridorDoorCapture", label = "捕获当前状态", on_click = function()
				local p = door_probe(); if p and p.capture_now then p.capture_now("manual_ui") end
			end},
			{id = "QingRemasterOptions_FixedCorridorDoorBurst", label = "开始90帧记录", on_click = function()
				local p = door_probe(); if p and p.start_burst then p.start_burst(90) end
			end},
		})
		local door_status_id = "QingRemasterOptions_FixedCorridorDoorStatus"
		imgui_layout.add_wrapped_text(door_sec, door_status_id, "idle")
		ImGui.AddCallback(door_status_id, ImGuiCallback.Render, function()
			local p = door_probe()
			local text_body = p and p.status_text and p.status_text() or "idle"
			ImGui.UpdateData(door_status_id, ImGuiData.Label, text_body)
		end)
		probe_output.add_probe_output_controls(door_sec, door_probe, {
			id_prefix = "QingRemasterOptions_FixedCorridorDoorOut",
			export_label = "Export JSONL",
			full_label = "复制完整报告",
			clear_label = "清空记录",
		})

		-- —— 镜像门物理诊断（独立只读；默认关闭；不改通行/进门）——
		local mirror_phys_sec = imgui_layout.add_section(
			fixed_corridor_group,
			"QingRemasterOptions_FixedCorridorMirrorPhysSec",
			"镜像门物理诊断"
		)
		local function mirror_phys_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.golden_compass_mirror_physics_probe")
		end
		add_text(
			mirror_phys_sec,
			"仅 Entry@78 LEFT0。记录 GRID_DOOR 出现时点、玩家撞击 Grid、GetGridCollision。默认关闭。不改 CollisionClass / confirmed_door。"
		)
		local mirror_phys_en = "QingRemasterOptions_FixedCorridorMirrorPhysEnabled"
		ImGui.AddCheckbox(mirror_phys_sec, mirror_phys_en, "启用镜像门碰撞记录", nil, false)
		ImGui.AddCallback(mirror_phys_en, ImGuiCallback.Render, function()
			local p = mirror_phys_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			live.update_checkbox_if_changed(mirror_phys_en, cfg.enabled == true)
		end)
		ImGui.AddCallback(mirror_phys_en, ImGuiCallback.Edited, function(value)
			local p = mirror_phys_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		local detail_log_id = "QingRemasterOptions_FixedCorridorDetailLogging"
		ImGui.AddCheckbox(mirror_phys_sec, detail_log_id, "详细楼层生成日志", nil, false)
		ImGui.AddCallback(detail_log_id, ImGuiCallback.Render, function()
			local p = corridor_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			live.update_checkbox_if_changed(detail_log_id, cfg.detail_logging == true)
		end)
		ImGui.AddCallback(detail_log_id, ImGuiCallback.Edited, function(value)
			local rt = require("Qing_Remaster_scripts.items.golden_compass.runtime")
			if rt and rt.set_detail_logging then
				rt.set_detail_logging(value == true)
			end
		end)
		imgui_layout.add_small_action_row(mirror_phys_sec, {
			{id = "QingRemasterOptions_FixedCorridorMirrorPhysCapture", label = "捕获当前碰撞", on_click = function()
				local p = mirror_phys_probe(); if p and p.capture_now then p.capture_now("manual_ui") end
			end},
		})
		local mirror_phys_status_id = "QingRemasterOptions_FixedCorridorMirrorPhysStatus"
		imgui_layout.add_wrapped_text(mirror_phys_sec, mirror_phys_status_id, "idle")
		ImGui.AddCallback(mirror_phys_status_id, ImGuiCallback.Render, function()
			local p = mirror_phys_probe()
			local text_body = p and p.status_text and p.status_text() or "idle"
			ImGui.UpdateData(mirror_phys_status_id, ImGuiData.Label, text_body)
		end)
		probe_output.add_probe_output_controls(mirror_phys_sec, mirror_phys_probe, {
			id_prefix = "QingRemasterOptions_FixedCorridorMirrorPhysOut",
			export_label = "Export JSONL",
			full_label = "复制完整报告",
			clear_label = "清空记录",
		})

		-- —— 矿井维度诊断（只读；默认关闭详细房间列表）——
		local mines_dim_sec = imgui_layout.add_section(
			fixed_corridor_group,
			"QingRemasterOptions_FixedCorridorMinesDimSec",
			"矿井维度诊断"
		)
		local function mines_dim_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.golden_compass_mineshaft_dim_probe")
		end
		add_text(
			mines_dim_sec,
			"矿二 Dimension 1 房间清单 + SGID 162 校验。默认关闭。开启后接收楼层完成/进78/炸板开放扫描；完整房间列表仅在「详细房间列表」打开时写入事件。"
		)
		local mines_dim_en = "QingRemasterOptions_FixedCorridorMinesDimEnabled"
		ImGui.AddCheckbox(mines_dim_sec, mines_dim_en, "启用矿井维度诊断", nil, false)
		ImGui.AddCallback(mines_dim_en, ImGuiCallback.Render, function()
			local p = mines_dim_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			live.update_checkbox_if_changed(mines_dim_en, cfg.enabled == true)
		end)
		ImGui.AddCallback(mines_dim_en, ImGuiCallback.Edited, function(value)
			local p = mines_dim_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		local mines_dim_detail = "QingRemasterOptions_FixedCorridorMinesDimDetail"
		ImGui.AddCheckbox(mines_dim_sec, mines_dim_detail, "详细房间列表（写入事件）", nil, false)
		ImGui.AddCallback(mines_dim_detail, ImGuiCallback.Render, function()
			local p = mines_dim_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			live.update_checkbox_if_changed(mines_dim_detail, cfg.detail_full == true)
		end)
		ImGui.AddCallback(mines_dim_detail, ImGuiCallback.Edited, function(value)
			local p = mines_dim_probe()
			if p and p.set_detail_full then p.set_detail_full(value == true) end
		end)
		imgui_layout.add_small_action_row(mines_dim_sec, {
			{id = "QingRemasterOptions_FixedCorridorMinesDimCapture", label = "立即扫描 Dim1", on_click = function()
				local p = mines_dim_probe(); if p and p.capture_now then p.capture_now("manual_ui") end
			end},
		})
		local mines_dim_status_id = "QingRemasterOptions_FixedCorridorMinesDimStatus"
		imgui_layout.add_wrapped_text(mines_dim_sec, mines_dim_status_id, "idle")
		ImGui.AddCallback(mines_dim_status_id, ImGuiCallback.Render, function()
			local p = mines_dim_probe()
			local text_body = p and p.status_text and p.status_text() or "idle"
			ImGui.UpdateData(mines_dim_status_id, ImGuiData.Label, text_body)
		end)
		probe_output.add_probe_output_controls(mines_dim_sec, mines_dim_probe, {
			id_prefix = "QingRemasterOptions_FixedCorridorMinesDimOut",
			export_label = "Export JSONL",
			full_label = "复制完整报告",
			clear_label = "清空记录",
		})

		-- —— 虚拟门生命周期（create/reuse/cleanup + 首次绘制帧；默认关闭）——
		local vdoor_life_sec = imgui_layout.add_section(
			fixed_corridor_group,
			"QingRemasterOptions_FixedCorridorVDoorLifeSec",
			"虚拟门生命周期"
		)
		local function vdoor_life_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.golden_compass_virtual_door_life_probe")
		end
		add_text(
			vdoor_life_sec,
			"记录 create/reuse/replace/cleanup、ensure_gate、collapse_fx 交接，以及首次 PRE/POST 绘制帧与存活 MeusNil 数。默认关闭。「直接播放坍塌」在矿二 78 强制播 Collapse FX（SORTING_NORMAL）。"
		)
		local vdoor_life_en = "QingRemasterOptions_FixedCorridorVDoorLifeEnabled"
		ImGui.AddCheckbox(vdoor_life_sec, vdoor_life_en, "启用虚拟门生命周期探针", nil, false)
		ImGui.AddCallback(vdoor_life_en, ImGuiCallback.Render, function()
			local p = vdoor_life_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			live.update_checkbox_if_changed(vdoor_life_en, cfg.enabled == true)
		end)
		ImGui.AddCallback(vdoor_life_en, ImGuiCallback.Edited, function(value)
			local p = vdoor_life_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		imgui_layout.add_small_action_row(vdoor_life_sec, {
			{id = "QingRemasterOptions_FixedCorridorVDoorLifeCapture", label = "立即快照", on_click = function()
				local p = vdoor_life_probe(); if p and p.capture_now then p.capture_now("manual_ui") end
			end},
			{id = "QingRemasterOptions_FixedCorridorForceCollapse", label = "直接播放坍塌", on_click = function()
				local p = corridor_probe()
				if p and p.force_mineshaft_collapse_playback then
					p.force_mineshaft_collapse_playback("manual_ui")
				else
					local rt = require("Qing_Remaster_scripts.items.golden_compass.runtime")
					if rt.force_mineshaft_collapse_playback then
						rt.force_mineshaft_collapse_playback("manual_ui")
					end
				end
			end},
		})
		local vdoor_life_status_id = "QingRemasterOptions_FixedCorridorVDoorLifeStatus"
		imgui_layout.add_wrapped_text(vdoor_life_sec, vdoor_life_status_id, "idle")
		ImGui.AddCallback(vdoor_life_status_id, ImGuiCallback.Render, function()
			local p = vdoor_life_probe()
			local text_body = p and p.status_text and p.status_text() or "idle"
			ImGui.UpdateData(vdoor_life_status_id, ImGuiData.Label, text_body)
		end)
		probe_output.add_probe_output_controls(vdoor_life_sec, vdoor_life_probe, {
			id_prefix = "QingRemasterOptions_FixedCorridorVDoorLifeOut",
			export_label = "Export JSONL",
			full_label = "复制完整报告",
			clear_label = "清空记录",
		})

		-- —— Boss 池审计 ——
		local boss_pool_sec = imgui_layout.add_section(
			fixed_corridor_group,
			"QingRemasterOptions_FixedCorridorBossPoolSec",
			"Boss 池审计"
		)
		local function boss_pool_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.golden_compass_boss_pool_probe")
		end
		add_text(
			boss_pool_sec,
			"只读扫描 v5：目标 STB + SPECIAL_ROOMS；身份别名/共享实体消歧；unsupported_shape 与 selectable_for_89；摘要按独立问题汇总；完整报告 layouts 去重。含 Mother 89/6000 与 -10 专项检查。StageAPI 扩展三项：candidates / usable_lr / rejected（固定 Seed；未安装则跳过）。不启用正式抽选。默认关闭。纯 StageAPI 房间清单也可在「StageAPI 绑定时序」页单独扫描。"
		)
		local boss_pool_en = "QingRemasterOptions_FixedCorridorBossPoolEnabled"
		ImGui.AddCheckbox(boss_pool_sec, boss_pool_en, "启用 Boss 池审计探针", nil, false)
		ImGui.AddCallback(boss_pool_en, ImGuiCallback.Render, function()
			local p = boss_pool_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			live.update_checkbox_if_changed(boss_pool_en, cfg.enabled == true)
		end)
		ImGui.AddCallback(boss_pool_en, ImGuiCallback.Edited, function(value)
			local p = boss_pool_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		imgui_layout.add_small_action_row(boss_pool_sec, {
			{id = "QingRemasterOptions_FixedCorridorBossPoolScan", label = "扫描全部目标楼层", on_click = function()
				local p = boss_pool_probe()
				if p and p.scan_all then p.scan_all("manual_ui") end
			end},
		})
		local boss_pool_status_id = "QingRemasterOptions_FixedCorridorBossPoolStatus"
		imgui_layout.add_wrapped_text(boss_pool_sec, boss_pool_status_id, "idle")
		ImGui.AddCallback(boss_pool_status_id, ImGuiCallback.Render, function()
			local p = boss_pool_probe()
			local text_body = p and p.status_text and p.status_text() or "idle"
			ImGui.UpdateData(boss_pool_status_id, ImGuiData.Label, text_body)
		end)
		probe_output.add_probe_output_controls(boss_pool_sec, boss_pool_probe, {
			id_prefix = "QingRemasterOptions_FixedCorridorBossPoolOut",
			summary_label = "复制摘要",
			export_label = "导出 JSON",
			full_label = "复制完整报告",
			clear_label = "清空报告",
		})

		-- —— StageAPI 绑定时序（只读；确认 89 ListIndex / OverrideData / GetLevelRoom）——
		local sa_bind_sec = imgui_layout.add_section(
			fixed_corridor_group,
			"QingRemasterOptions_FixedCorridorStageApiBindSec",
			"StageAPI 绑定时序"
		)
		local function sa_bind_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.golden_compass_stageapi_bind_probe")
		end
		add_text(
			sa_bind_sec,
			"绑定时序：记录 Boss@89 after_plan / after_replace / layout_ready|failed / post_new_level / enter_89。默认关闭。\n"
				.. "抽取池：预览当前楼层 vanilla/StageAPI 候选与排除原因；走廊生成后快照含 pick_pool_summary。\n"
				.. "强制扩展：一次性把下次直道 Boss@89 指定为 StageAPI 扩展 Boss（不改正式随机权重）。\n"
				.. "房间资源审计：离线扫描扩展 Boss 1×1 LR（固定 Seed），不换层。"
		)
		local sa_bind_en = "QingRemasterOptions_FixedCorridorStageApiBindEnabled"
		ImGui.AddCheckbox(sa_bind_sec, sa_bind_en, "启用 StageAPI 绑定时序探针", nil, false)
		ImGui.AddCallback(sa_bind_en, ImGuiCallback.Render, function()
			local p = sa_bind_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			live.update_checkbox_if_changed(sa_bind_en, cfg.enabled == true)
		end)
		ImGui.AddCallback(sa_bind_en, ImGuiCallback.Edited, function(value)
			local p = sa_bind_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		imgui_layout.add_small_action_row(sa_bind_sec, {
			{id = "QingRemasterOptions_FixedCorridorStageApiBindCapture", label = "立即快照", on_click = function()
				local p = sa_bind_probe(); if p and p.capture_now then p.capture_now("manual_ui") end
			end},
			{id = "QingRemasterOptions_FixedCorridorStageApiRoomsScan", label = "扫描 StageAPI 房间资源", on_click = function()
				local p = sa_bind_probe()
				if p and p.scan_stageapi_rooms then p.scan_stageapi_rooms("manual_ui") end
			end},
		})
		imgui_layout.add_small_action_row(sa_bind_sec, {
			{id = "QingRemasterOptions_FixedCorridorStageApiPickPool", label = "预览当前楼层抽取池", on_click = function()
				local p = sa_bind_probe()
				if p and p.inspect_pick_pool_now then p.inspect_pick_pool_now("manual_ui") end
			end},
			{id = "QingRemasterOptions_FixedCorridorStageApiForceExt", label = "下次强制扩展 Boss@89", on_click = function()
				local p = sa_bind_probe()
				if p and p.arm_force_stageapi_extension_next then p.arm_force_stageapi_extension_next() end
			end},
			{id = "QingRemasterOptions_FixedCorridorStageApiForceClear", label = "清除强制扩展", on_click = function()
				local p = sa_bind_probe()
				if p and p.clear_force_stageapi_extension_next then p.clear_force_stageapi_extension_next() end
			end},
		})
		imgui_layout.add_small_action_row(sa_bind_sec, {
			{id = "QingRemasterOptions_FixedCorridorStageApiPickSummary", label = "复制抽取池摘要", on_click = function()
				local p = sa_bind_probe()
				if p and p.copy_pick_pool_summary then p.copy_pick_pool_summary() end
			end},
			{id = "QingRemasterOptions_FixedCorridorStageApiPickFull", label = "复制抽取池完整 JSON", on_click = function()
				local p = sa_bind_probe()
				if p and p.copy_pick_pool_full then p.copy_pick_pool_full() end
			end},
		})
		local sa_bind_status_id = "QingRemasterOptions_FixedCorridorStageApiBindStatus"
		imgui_layout.add_wrapped_text(sa_bind_sec, sa_bind_status_id, "idle")
		ImGui.AddCallback(sa_bind_status_id, ImGuiCallback.Render, function()
			local p = sa_bind_probe()
			local text_body = p and p.status_text and p.status_text() or "idle"
			ImGui.UpdateData(sa_bind_status_id, ImGuiData.Label, text_body)
		end)
		local sa_rooms_status_id = "QingRemasterOptions_FixedCorridorStageApiRoomsStatus"
		imgui_layout.add_wrapped_text(sa_bind_sec, sa_rooms_status_id, "stageapi_rooms idle")
		ImGui.AddCallback(sa_rooms_status_id, ImGuiCallback.Render, function()
			local p = sa_bind_probe()
			local text_body = p and p.stageapi_rooms_status_text and p.stageapi_rooms_status_text() or "idle"
			ImGui.UpdateData(sa_rooms_status_id, ImGuiData.Label, text_body)
		end)
		imgui_layout.add_small_action_row(sa_bind_sec, {
			{id = "QingRemasterOptions_FixedCorridorStageApiRoomsSummary", label = "复制房间审计摘要", on_click = function()
				local p = sa_bind_probe()
				if p and p.copy_stageapi_rooms_summary then p.copy_stageapi_rooms_summary() end
			end},
			{id = "QingRemasterOptions_FixedCorridorStageApiRoomsFull", label = "复制房间审计完整报告", on_click = function()
				local p = sa_bind_probe()
				if p and p.copy_stageapi_rooms_full then p.copy_stageapi_rooms_full() end
			end},
			{id = "QingRemasterOptions_FixedCorridorStageApiRoomsExport", label = "导出房间审计 JSON", on_click = function()
				local p = sa_bind_probe()
				if p and p.export_stageapi_rooms then p.export_stageapi_rooms() end
			end},
			{id = "QingRemasterOptions_FixedCorridorStageApiRoomsClear", label = "清空房间审计", on_click = function()
				local p = sa_bind_probe()
				if p and p.clear_stageapi_rooms_report then p.clear_stageapi_rooms_report() end
			end},
		})
		probe_output.add_probe_output_controls(sa_bind_sec, sa_bind_probe, {
			id_prefix = "QingRemasterOptions_FixedCorridorStageApiBindOut",
			export_label = "Export JSONL",
			full_label = "复制完整报告",
			clear_label = "清空记录",
		})

		-- —— 见证者测试 ——
		local witness_sec = imgui_layout.add_section(
			fixed_corridor_group,
			"QingRemasterOptions_FixedCorridorWitnessSec",
			"陵墓 II · 见证者路线测试"
		)
		add_text(witness_sec, "默认关闭；手动开启。正式出口规则不变。")
		local witness_id = "QingRemasterOptions_FixedCorridorWitness"
		ImGui.AddCheckbox(witness_sec, witness_id, "见证者测试：绕过陵墓II出口排除", nil, false)
		ImGui.AddCallback(witness_id, ImGuiCallback.Render, function()
			local p = corridor_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			live.update_checkbox_if_changed(witness_id, cfg.witness_mausoleum_test == true)
		end)
		ImGui.AddCallback(witness_id, ImGuiCallback.Edited, function(value)
			local p = corridor_probe()
			if p and p.set_witness_mausoleum_test then
				p.set_witness_mausoleum_test(value == true)
			end
		end)
		imgui_layout.add_small_action_row(witness_sec, {
			{id = "QingRemasterOptions_FixedCorridorForceMomMaus", label = "下次强制强化妈腿(89)", on_click = function()
				local p = corridor_probe()
				if p and p.arm_force_mom_mausoleum_next then p.arm_force_mom_mausoleum_next() end
			end},
			{id = "QingRemasterOptions_FixedCorridorWitnessSnap", label = "快照见证者状态", on_click = function()
				local p = corridor_probe()
				if p and p.snapshot_witness_route then p.snapshot_witness_route("manual_ui") end
			end},
			{id = "QingRemasterOptions_FixedCorridorWitnessSoft", label = "TrySpawnSecretExit(软)", on_click = function()
				local p = corridor_probe()
				if p and p.try_spawn_witness_secret_exit_soft then
					p.try_spawn_witness_secret_exit_soft()
				end
			end},
			{id = "QingRemasterOptions_FixedCorridorWitnessForce", label = "TrySpawnSecretExit(Force)", on_click = function()
				local p = corridor_probe()
				if p and p.try_spawn_witness_secret_exit_force then
					p.try_spawn_witness_secret_exit_force()
				end
			end},
		})

		-- —— 高级对照 ——
		local adv_sec = imgui_layout.add_section(
			fixed_corridor_group,
			"QingRemasterOptions_FixedCorridorAdvSec",
			"高级对照（日常可忽略）"
		)
		local enable_id = "QingRemasterOptions_FixedCorridorEnabled"
		ImGui.AddCheckbox(adv_sec, enable_id, "启用探针（不武装）", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = corridor_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			live.update_checkbox_if_changed(enable_id, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = corridor_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		local api_game_id = "QingRemasterOptions_FixedCorridorApiGame"
		ImGui.AddCheckbox(adv_sec, api_game_id, "入层用 Game:ChangeRoom（否=Level）", nil, true)
		ImGui.AddCallback(api_game_id, ImGuiCallback.Render, function()
			local p = corridor_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			live.update_checkbox_if_changed(api_game_id, cfg.entry_change_api ~= "level")
		end)
		ImGui.AddCallback(api_game_id, ImGuiCallback.Edited, function(value)
			local p = corridor_probe()
			if p and p.set_entry_change_api then
				p.set_entry_change_api(value == true and "game" or "level")
			end
		end)
		imgui_layout.add_small_action_row(adv_sec, {
			{id = "QingRemasterOptions_FixedCorridorArmFull", label = "武装全直道", on_click = function()
				local p = corridor_probe(); if p and p.arm_full_corridor then p.arm_full_corridor() end
			end},
			{id = "QingRemasterOptions_FixedCorridorArmP0", label = "P0", on_click = function()
				local p = corridor_probe(); if p and p.arm_p0 then p.arm_p0() end
			end},
			{id = "QingRemasterOptions_FixedCorridorArmP1", label = "P1", on_click = function()
				local p = corridor_probe(); if p and p.arm_p0_p1 then p.arm_p0_p1() end
			end},
			{id = "QingRemasterOptions_FixedCorridorArmP2A", label = "P2-A", on_click = function()
				local p = corridor_probe(); if p and p.arm_p2a then p.arm_p2a() end
			end},
			{id = "QingRemasterOptions_FixedCorridorArmP2B", label = "P2-B", on_click = function()
				local p = corridor_probe(); if p and p.arm_p2b then p.arm_p2b() end
			end},
		})
		imgui_layout.add_small_action_row(adv_sec, {
			{id = "QingRemasterOptions_FixedCorridorCapture", label = "捕获当前楼层", on_click = function()
				local p = corridor_probe(); if p and p.capture_current_level then p.capture_current_level() end
			end},
			{id = "QingRemasterOptions_FixedCorridorForce", label = "立即 stage 13", on_click = function()
				local p = corridor_probe(); if p and p.force_console_home_now then p.force_console_home_now() end
			end},
			{id = "QingRemasterOptions_FixedCorridorPlace108", label = "实验 Place@108(25601)", on_click = function()
				local p = corridor_probe(); if p and p.experiment_force_place_108 then p.experiment_force_place_108() end
			end},
		})
	end
	end

	local grid_topo_group = start_probe_module(
		"audit_grid_rock_topology",
		"Grid Rock Topology",
		"QingRemasterOptions_GroupGridRockTopology"
	)
	if grid_topo_group then
	do
		local function topo_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.grid_rock_topology_probe")
		end
		add_text(
			grid_topo_group,
			"Listens to grid_rock_topology transactions (before_detach … after_topology_sync … after_validate). Validate Room checks reciprocal BigRockFrame. UpdateNeighbors is never used for refresh."
		)
		local enable_id = "QingRemasterOptions_GridRockTopoEnabled"
		ImGui.AddCheckbox(grid_topo_group, enable_id, "Enable", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = topo_probe()
			local cfg = p and p.get_config and p.get_config() or {enabled = false}
			ImGui.UpdateData(enable_id, ImGuiData.Value, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = topo_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		local overlay_id = "QingRemasterOptions_GridRockTopoOverlay"
		ImGui.AddCheckbox(grid_topo_group, overlay_id, "Overlay labels", nil, false)
		ImGui.AddCallback(overlay_id, ImGuiCallback.Render, function()
			local p = topo_probe()
			local cfg = p and p.get_config and p.get_config() or {overlay = false}
			ImGui.UpdateData(overlay_id, ImGuiData.Value, cfg.overlay == true)
		end)
		ImGui.AddCallback(overlay_id, ImGuiCallback.Edited, function(value)
			local p = topo_probe()
			if p and p.set_overlay then p.set_overlay(value == true) end
		end)
		imgui_layout.add_small_action_row(grid_topo_group, {
			{id = "QingRemasterOptions_GridRockTopoValidate", label = "Validate Room", on_click = function()
				local p = topo_probe(); if p and p.validate_current_room then p.validate_current_room() end
			end},
			{id = "QingRemasterOptions_GridRockTopoCapture", label = "Capture Last Affected", on_click = function()
				local p = topo_probe(); if p and p.capture_neighborhood then p.capture_neighborhood() end
			end},
		})
		local status_id = "QingRemasterOptions_GridRockTopoStatus"
		imgui_layout.add_wrapped_text(grid_topo_group, status_id, "idle")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = topo_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			imgui_layout.update_text(
				status_id,
				string.format(
					"en=%s ov=%s ev=%s anom=%s phase=%s ok=%s",
					tostring(cfg.enabled),
					tostring(cfg.overlay),
					tostring(cfg.event_count),
					tostring(cfg.anomaly_count),
					tostring(cfg.last_phase),
					tostring(cfg.validation_ok)
				)
			)
		end)
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(grid_topo_group, topo_probe, {
			id_prefix = "QingRemasterOptions_GridRockTopoOut",
			export_label = "Export Report",
		})
	end
	end

	local faint_z_corr_group = start_probe_module(
		"audit_faint_projectile_z_corr",
		"Faint? Render Probe",
		"QingRemasterOptions_GroupFaintZCorr"
	)
	if faint_z_corr_group then
	do
		local function z_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.faint_projectile_z_corr_probe")
		end
		add_text(
			faint_z_corr_group,
			"Z: mapping lanes. XY: A sm×s / B sm=1 / C V×s / D vanilla (no Offset; isolates SetSpeedMultiplier)."
		)
		local enable_id = "QingRemasterOptions_FaintZCorrEnabled"
		ImGui.AddCheckbox(faint_z_corr_group, enable_id, "Enable", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = z_probe()
			local cfg = p and p.get_config and p.get_config() or {enabled = false}
			ImGui.UpdateData(enable_id, ImGuiData.Value, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = z_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		local status_id = "QingRemasterOptions_FaintZCorrStatus"
		imgui_layout.add_wrapped_text(faint_z_corr_group, status_id, "off")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = z_probe()
			imgui_layout.update_text(status_id, (p and p.get_summary and p.get_summary()) or "n/a")
		end)
		imgui_layout.add_action_row(faint_z_corr_group, {
			{id = "QingRemasterOptions_FaintModeZ", label = "Mode Z", on_click = function()
				local p = z_probe(); if p and p.set_mode then p.set_mode("z") end
			end},
			{id = "QingRemasterOptions_FaintModeXY", label = "Mode XY", on_click = function()
				local p = z_probe(); if p and p.set_mode then p.set_mode("xy") end
			end},
		})
		add_text(faint_z_corr_group, "XY base Velocity (A/B/D use this; C writes V×scale)")
		imgui_layout.add_action_row(faint_z_corr_group, {
			{id = "QingRemasterOptions_FaintXySpd4", label = "V 4", on_click = function()
				local p = z_probe(); if p and p.set_xy_speed then p.set_xy_speed(4) end
			end},
			{id = "QingRemasterOptions_FaintXySpd8", label = "V 8", on_click = function()
				local p = z_probe(); if p and p.set_xy_speed then p.set_xy_speed(8) end
			end},
			{id = "QingRemasterOptions_FaintXySpd12", label = "V 12", on_click = function()
				local p = z_probe(); if p and p.set_xy_speed then p.set_xy_speed(12) end
			end},
			{id = "QingRemasterOptions_FaintXySpd16", label = "V 16", on_click = function()
				local p = z_probe(); if p and p.set_xy_speed then p.set_xy_speed(16) end
			end},
		})
		add_text(faint_z_corr_group, "Z Profile (scaled branch: FA<=0.001; parabola uses negative FA)")
		imgui_layout.add_action_row(faint_z_corr_group, {
			{id = "QingRemasterOptions_FaintProfFall", label = "Parabola FA=-0.5", on_click = function()
				local p = z_probe(); if p and p.set_z_profile then p.set_z_profile("falling") end
			end},
			{id = "QingRemasterOptions_FaintProfConst", label = "Near-const FA=-0.001", on_click = function()
				local p = z_probe(); if p and p.set_z_profile then p.set_z_profile("constant_fs") end
			end},
			{id = "QingRemasterOptions_FaintProfFA0", label = "FA=0 (h2o)", on_click = function()
				local p = z_probe(); if p and p.set_z_profile then p.set_z_profile("fa0") end
			end},
		})
		add_text(faint_z_corr_group, "Phase Pair (primary)")
		imgui_layout.add_action_row(faint_z_corr_group, {
			{id = "QingRemasterOptions_FaintPhaseZero", label = "0 / 0", on_click = function()
				local p = z_probe(); if p and p.set_phase_mode then p.set_phase_mode("zero") end
			end},
			{id = "QingRemasterOptions_FaintPhaseFwdA", label = "0 / +0.5", on_click = function()
				local p = z_probe(); if p and p.set_phase_mode then p.set_phase_mode("forward_a") end
			end},
			{id = "QingRemasterOptions_FaintPhaseFwdB", label = "+0.5 / 0", on_click = function()
				local p = z_probe(); if p and p.set_phase_mode then p.set_phase_mode("forward_b") end
			end},
			{id = "QingRemasterOptions_FaintPhaseBackA", label = "0 / -0.5", on_click = function()
				local p = z_probe(); if p and p.set_phase_mode then p.set_phase_mode("backward_a") end
			end},
			{id = "QingRemasterOptions_FaintPhaseBackB", label = "-0.5 / 0", on_click = function()
				local p = z_probe(); if p and p.set_phase_mode then p.set_phase_mode("backward_b") end
			end},
			{id = "QingRemasterOptions_FaintPhaseCustom", label = "custom", on_click = function()
				local p = z_probe(); if p and p.set_phase_mode then p.set_phase_mode("custom") end
			end},
		})
		local a0_id = "QingRemasterOptions_FaintCustomA0"
		ImGui.AddDragFloat(faint_z_corr_group, a0_id, "Custom alpha0", function(value)
			local p = z_probe()
			if p and p.set_custom_alpha0 then p.set_custom_alpha0(value) end
		end, 0, 0.05, -1.5, 1.5, "%.2f")
		ImGui.AddCallback(a0_id, ImGuiCallback.Render, function()
			local p = z_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData(a0_id, ImGuiData.Value, tonumber(cfg.custom_alpha0) or 0)
		end)
		local a1_id = "QingRemasterOptions_FaintCustomA1"
		ImGui.AddDragFloat(faint_z_corr_group, a1_id, "Custom alpha1", function(value)
			local p = z_probe()
			if p and p.set_custom_alpha1 then p.set_custom_alpha1(value) end
		end, 0.5, 0.05, -1.5, 1.5, "%.2f")
		ImGui.AddCallback(a1_id, ImGuiCallback.Render, function()
			local p = z_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData(a1_id, ImGuiData.Value, tonumber(cfg.custom_alpha1) or 0.5)
		end)
		add_text(faint_z_corr_group, "FallingSpeed")
		imgui_layout.add_action_row(faint_z_corr_group, {
			{id = "QingRemasterOptions_FaintFS4", label = "FS -4", on_click = function()
				local p = z_probe(); if p and p.set_falling_speed then p.set_falling_speed(-4) end
			end},
			{id = "QingRemasterOptions_FaintFS8", label = "FS -8", on_click = function()
				local p = z_probe(); if p and p.set_falling_speed then p.set_falling_speed(-8) end
			end},
			{id = "QingRemasterOptions_FaintFS12", label = "FS -12", on_click = function()
				local p = z_probe(); if p and p.set_falling_speed then p.set_falling_speed(-12) end
			end},
			{id = "QingRemasterOptions_FaintFS0", label = "FS 0", on_click = function()
				local p = z_probe(); if p and p.set_falling_speed then p.set_falling_speed(0) end
			end},
		})
		add_text(faint_z_corr_group, "FallingAccel negative only (keeps scaled h2o; does not reset H/FS)")
		imgui_layout.add_action_row(faint_z_corr_group, {
			{id = "QingRemasterOptions_FaintFA0", label = "FA 0", on_click = function()
				local p = z_probe(); if p and p.set_falling_accel then p.set_falling_accel(0) end
			end},
			{id = "QingRemasterOptions_FaintFAn0001", label = "FA -0.001", on_click = function()
				local p = z_probe(); if p and p.set_falling_accel then p.set_falling_accel(-0.001) end
			end},
			{id = "QingRemasterOptions_FaintFAn01", label = "FA -0.1", on_click = function()
				local p = z_probe(); if p and p.set_falling_accel then p.set_falling_accel(-0.1) end
			end},
			{id = "QingRemasterOptions_FaintFAn05", label = "FA -0.5", on_click = function()
				local p = z_probe(); if p and p.set_falling_accel then p.set_falling_accel(-0.5) end
			end},
			{id = "QingRemasterOptions_FaintFAn10", label = "FA -1.0", on_click = function()
				local p = z_probe(); if p and p.set_falling_accel then p.set_falling_accel(-1.0) end
			end},
		})
		local scale_id = "QingRemasterOptions_FaintZCorrScale"
		ImGui.AddDragFloat(faint_z_corr_group, scale_id, "Faint projectile scale", function(value)
			local p = z_probe()
			if p and p.set_scale then p.set_scale(value) end
		end, 0.05, 0.01, 0.01, 1, "%.3f")
		ImGui.AddCallback(scale_id, ImGuiCallback.Render, function()
			local p = z_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData(scale_id, ImGuiData.Value, tonumber(cfg.scale) or 0.05)
		end)
		imgui_layout.add_action_row(faint_z_corr_group, {
			{id = "QingRemasterOptions_FaintScale100", label = "100%", on_click = function()
				local p = z_probe(); if p and p.set_scale then p.set_scale(1) end
			end},
			{id = "QingRemasterOptions_FaintScale50", label = "50%", on_click = function()
				local p = z_probe(); if p and p.set_scale then p.set_scale(0.5) end
			end},
			{id = "QingRemasterOptions_FaintScale25", label = "25%", on_click = function()
				local p = z_probe(); if p and p.set_scale then p.set_scale(0.25) end
			end},
			{id = "QingRemasterOptions_FaintScale10", label = "10%", on_click = function()
				local p = z_probe(); if p and p.set_scale then p.set_scale(0.1) end
			end},
			{id = "QingRemasterOptions_FaintScale05", label = "5%", on_click = function()
				local p = z_probe(); if p and p.set_scale then p.set_scale(0.05) end
			end},
		})
		imgui_layout.add_action_row(faint_z_corr_group, {
			{id = "QingRemasterOptions_FaintZCorrSpawn", label = "Spawn / Restart", on_click = function()
				local p = z_probe(); if p and p.spawn then p.spawn() end
			end},
			{id = "QingRemasterOptions_FaintZCorrClear", label = "Clear", on_click = function()
				local p = z_probe(); if p and p.clear then p.clear() end
			end},
		})
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(faint_z_corr_group, z_probe, {
			id_prefix = "QingRemasterOptions_FaintZCorrOut",
			export_label = "Export",
		})
	end
	end

	local faint_npc_motion_group = start_probe_module(
		"audit_faint_npc_motion",
		"Faint? NPC Motion Probe",
		"QingRemasterOptions_GroupFaintNpcMotion"
	)
	if faint_npc_motion_group then
	do
		local function npc_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.faint_npc_motion_probe")
		end
		add_text(
			faint_npc_motion_group,
			"观察同一只 250.0.0。从 Walk 开始录，直到完整 Jump 周期、PO/屏幕越界后再多录 30 逻辑帧，或满 3000 逻辑帧。时长只由 POST_UPDATE 推进。不改正式长眠逻辑。"
		)
		local enable_id = "QingRemasterOptions_FaintNpcMotionEnabled"
		ImGui.AddCheckbox(faint_npc_motion_group, enable_id, "Enable", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = npc_probe()
			local cfg = p and p.get_config and p.get_config() or {enabled = false}
			ImGui.UpdateData(enable_id, ImGuiData.Value, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = npc_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		local status_id = "QingRemasterOptions_FaintNpcMotionStatus"
		imgui_layout.add_wrapped_text(faint_npc_motion_group, status_id, "off")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = npc_probe()
			imgui_layout.update_text(status_id, (p and p.get_summary and p.get_summary()) or "n/a")
		end)
		imgui_layout.add_action_row(faint_npc_motion_group, {
			{id = "QingRemasterOptions_FaintNpcSpawn", label = "Spawn 250.0.0", on_click = function()
				local p = npc_probe(); if p and p.spawn_target then p.spawn_target() end
			end},
			{id = "QingRemasterOptions_FaintNpcCapBase", label = "Start Baseline Capture", on_click = function()
				local p = npc_probe(); if p and p.start_baseline_capture then p.start_baseline_capture() end
			end},
			{id = "QingRemasterOptions_FaintNpcCapFaint", label = "Start Faint Capture", on_click = function()
				local p = npc_probe(); if p and p.start_faint_capture then p.start_faint_capture() end
			end},
		})
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(faint_npc_motion_group, npc_probe, {
			id_prefix = "QingRemasterOptions_FaintNpcMotionOut",
			export_label = "Export",
		})
	end
	end

	local profound_hb_group = start_probe_module(
		"audit_profound_heartbeat",
		"Profound? Heartbeat Tune",
		"QingRemasterOptions_GroupProfoundHeartbeat"
	)
	if profound_hb_group then
	do
		local function hb_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.profound_heartbeat_probe")
		end
		add_text(
			profound_hb_group,
			"V2.5：远距45° guide cadence；近距 Homing 越近越快越响；Lock-on 动态半径。SFX反补偿。默认关。"
		)
		local enable_id = "QingRemasterOptions_ProfoundHbEnabled"
		ImGui.AddCheckbox(profound_hb_group, enable_id, "Enable", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = hb_probe()
			local cfg = p and p.get_config and p.get_config() or {enabled = false}
			ImGui.UpdateData(enable_id, ImGuiData.Value, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = hb_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		local hud_id = "QingRemasterOptions_ProfoundHbHud"
		ImGui.AddCheckbox(profound_hb_group, hud_id, "Show HUD", nil, true)
		ImGui.AddCallback(hud_id, ImGuiCallback.Render, function()
			local p = hb_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData(hud_id, ImGuiData.Value, cfg.show_hud ~= false)
		end)
		ImGui.AddCallback(hud_id, ImGuiCallback.Edited, function(value)
			local p = hb_probe()
			if p and p.set_show_hud then p.set_show_hud(value == true) end
		end)
		local guide_id = "QingRemasterOptions_ProfoundHbGuideDraw"
		ImGui.AddCheckbox(profound_hb_group, guide_id, "Draw guide / homing / lock radii", nil, true)
		ImGui.AddCallback(guide_id, ImGuiCallback.Render, function()
			local p = hb_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData(guide_id, ImGuiData.Value, cfg.show_guide_lines ~= false)
		end)
		ImGui.AddCallback(guide_id, ImGuiCallback.Edited, function(value)
			local p = hb_probe()
			if p and p.set_show_guide_lines then p.set_show_guide_lines(value == true) end
		end)
		local status_id = "QingRemasterOptions_ProfoundHbStatus"
		imgui_layout.add_wrapped_text(profound_hb_group, status_id, "off")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = hb_probe()
			imgui_layout.update_text(status_id, (p and p.get_summary and p.get_summary()) or "n/a")
		end)
		add_text(profound_hb_group, "点击播放（按当前 target_final / Options.SFXVolume 反补偿；不需进迷宫）")
		imgui_layout.add_action_row(profound_hb_group, {
			{id = "QingRemasterOptions_ProfoundHbPrevHb", label = "播放 HEARTBEAT", on_click = function()
				local p = hb_probe(); if p and p.preview_sound then p.preview_sound("heartbeat", 0) end
			end},
			{id = "QingRemasterOptions_ProfoundHbPrevFaster", label = "播放 FASTER", on_click = function()
				local p = hb_probe(); if p and p.preview_sound then p.preview_sound("faster", 0) end
			end},
			{id = "QingRemasterOptions_ProfoundHbPrevFastest", label = "播放 FASTEST", on_click = function()
				local p = hb_probe(); if p and p.preview_sound then p.preview_sound("fastest", 0) end
			end},
		})
		imgui_layout.add_action_row(profound_hb_group, {
			{id = "QingRemasterOptions_ProfoundHbPrevLeft", label = "左声道 HEARTBEAT", on_click = function()
				local p = hb_probe()
				if not (p and p.preview_sound and p.get_config) then return end
				local strength = tonumber(p.get_config().pan_strength) or 1
				p.preview_sound("heartbeat", -strength)
			end},
			{id = "QingRemasterOptions_ProfoundHbPrevCenter", label = "中 HEARTBEAT", on_click = function()
				local p = hb_probe(); if p and p.preview_sound then p.preview_sound("heartbeat", 0) end
			end},
			{id = "QingRemasterOptions_ProfoundHbPrevRight", label = "右声道 HEARTBEAT", on_click = function()
				local p = hb_probe()
				if not (p and p.preview_sound and p.get_config) then return end
				local strength = tonumber(p.get_config().pan_strength) or 1
				p.preview_sound("heartbeat", strength)
			end},
		})
		add_text(profound_hb_group, "Presets")
		imgui_layout.add_action_row(profound_hb_group, {
			{id = "QingRemasterOptions_ProfoundHbPresetV2", label = "v2.5 guide+homing", on_click = function()
				local p = hb_probe(); if p and p.apply_preset then p.apply_preset("v25") end
			end},
			{id = "QingRemasterOptions_ProfoundHbPresetLoose", label = "v2.5 loose", on_click = function()
				local p = hb_probe(); if p and p.apply_preset then p.apply_preset("v2_loose") end
			end},
			{id = "QingRemasterOptions_ProfoundHbPresetV1", label = "v1 stacked", on_click = function()
				local p = hb_probe(); if p and p.apply_preset then p.apply_preset("v1_stacked") end
			end},
			{id = "QingRemasterOptions_ProfoundHbPresetDef", label = "defaults", on_click = function()
				local p = hb_probe(); if p and p.apply_preset then p.apply_preset("defaults") end
			end},
		})
		add_text(profound_hb_group, "Interval mode")
		imgui_layout.add_action_row(profound_hb_group, {
			{id = "QingRemasterOptions_ProfoundHbModeCadence", label = "cadence (V2.5)", on_click = function()
				local p = hb_probe(); if p and p.set_interval_mode then p.set_interval_mode("cadence") end
			end},
			{id = "QingRemasterOptions_ProfoundHbModeFixed", label = "fixed", on_click = function()
				local p = hb_probe(); if p and p.set_interval_mode then p.set_interval_mode("fixed") end
			end},
			{id = "QingRemasterOptions_ProfoundHbModeDist", label = "by distance", on_click = function()
				local p = hb_probe(); if p and p.set_interval_mode then p.set_interval_mode("by_distance") end
			end},
		})
		local function add_hb_drag(id, label, setter, getter_key, def, step, lo, hi, fmt)
			ImGui.AddDragFloat(profound_hb_group, id, label, function(value)
				local p = hb_probe()
				if p and p[setter] then p[setter](value) end
			end, def, step, lo, hi, fmt)
			ImGui.AddCallback(id, ImGuiCallback.Render, function()
				local p = hb_probe()
				local cfg = p and p.get_config and p.get_config() or {}
				ImGui.UpdateData(id, ImGuiData.Value, tonumber(cfg[getter_key]) or def)
			end)
		end
		add_text(profound_hb_group, "Guide-line cadence")
		add_hb_drag("QingRemasterOptions_ProfoundHbGuideInner", "inner_plateau°", "set_guide_inner_deg", "guide_inner_deg", 12, 1, 0, 40, "%.0f")
		add_hb_drag("QingRemasterOptions_ProfoundHbGuideOuter", "outer_falloff°", "set_guide_outer_deg", "guide_outer_deg", 36, 1, 5, 45, "%.0f")
		add_hb_drag("QingRemasterOptions_ProfoundHbCadFast", "cadence_fast", "set_cadence_fast", "cadence_fast", 24, 1, 8, 120, "%.0f")
		add_hb_drag("QingRemasterOptions_ProfoundHbCadSlow", "cadence_slow", "set_cadence_slow", "cadence_slow", 60, 1, 8, 120, "%.0f")
		add_text(profound_hb_group, "Homing / Lock-on")
		add_hb_drag("QingRemasterOptions_ProfoundHbHomingStart", "homing_start px", "set_homing_start", "homing_start", 140, 5, 40, 400, "%.0f")
		add_hb_drag("QingRemasterOptions_ProfoundHbHomingFarIv", "homing_far_interval", "set_homing_far_interval", "homing_far_interval", 60, 1, 8, 120, "%.0f")
		add_hb_drag("QingRemasterOptions_ProfoundHbHomingNearIv", "homing_near/lock iv", "set_homing_near_interval", "homing_near_interval", 22, 1, 8, 120, "%.0f")
		add_hb_drag("QingRemasterOptions_ProfoundHbLockFrac", "lock_spacing_frac", "set_lock_spacing_frac", "lock_spacing_frac", 0.30, 0.01, 0.1, 0.6, "%.2f")
		add_text(profound_hb_group, "Distance tiers / volume targets")
		add_hb_drag("QingRemasterOptions_ProfoundHbDistNear", "dist_near → HB3", "set_dist_near", "dist_near", 70, 5, 20, 400, "%.0f")
		add_hb_drag("QingRemasterOptions_ProfoundHbDistMid", "dist_mid → HB2", "set_dist_mid", "dist_mid", 280, 10, 40, 800, "%.0f")
		add_hb_drag("QingRemasterOptions_ProfoundHbVolFar", "target_final_far", "set_target_final_far", "target_final_far", 0.35, 0.01, 0.0, 1.0, "%.2f")
		add_hb_drag("QingRemasterOptions_ProfoundHbVolNear", "target_final_near/lock", "set_target_final_near", "target_final_near", 1.00, 0.01, 0.0, 1.0, "%.2f")
		add_hb_drag("QingRemasterOptions_ProfoundHbPassedCap", "passed_volume_cap", "set_passed_volume_cap", "passed_volume_cap", 10.0, 0.5, 1.0, 20.0, "%.1f")
		add_text(profound_hb_group, "Sample-safe (whole-range shift)")
		add_hb_drag("QingRemasterOptions_ProfoundHbSafe1", "safe HB1", "set_safe_hb1", "safe_hb1", 48, 1, 8, 120, "%.0f")
		add_hb_drag("QingRemasterOptions_ProfoundHbSafe2", "safe HB2", "set_safe_hb2", "safe_hb2", 40, 1, 8, 120, "%.0f")
		add_hb_drag("QingRemasterOptions_ProfoundHbSafe3", "safe HB3", "set_safe_hb3", "safe_hb3", 15, 1, 8, 120, "%.0f")
		add_text(profound_hb_group, "Pan (coarse only)")
		add_hb_drag("QingRemasterOptions_ProfoundHbPan", "pan_strength", "set_pan_strength", "pan_strength", 1.0, 0.05, 0.0, 1.0, "%.2f")
		imgui_layout.add_action_row(profound_hb_group, {
			{id = "QingRemasterOptions_ProfoundHbClear", label = "Clear log", on_click = function()
				local p = hb_probe(); if p and p.clear then p.clear() end
			end},
		})
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(profound_hb_group, hb_probe, {
			id_prefix = "QingRemasterOptions_ProfoundHbOut",
			export_label = "Export JSON",
		})
	end
	end

	local hb_sfx_group = start_probe_module(
		"audit_heartbeat_sfx_capture",
		"Heartbeat SFX Capture",
		"QingRemasterOptions_GroupHeartbeatSfxCapture"
	)
	if hb_sfx_group then
	do
		local function cap_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.heartbeat_sfx_capture_probe")
		end
		add_text(
			hb_sfx_group,
			"对照：翻页应随时清晰。Qing=V2.5：guide+homing+lock；SFX反补偿；HB3 单 cycle。"
		)
		local enable_id = "QingRemasterOptions_HbSfxCapEnabled"
		ImGui.AddCheckbox(hb_sfx_group, enable_id, "Enable", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = cap_probe()
			local cfg = p and p.get_config and p.get_config() or {enabled = false}
			ImGui.UpdateData(enable_id, ImGuiData.Value, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = cap_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		local status_id = "QingRemasterOptions_HbSfxCapStatus"
		imgui_layout.add_wrapped_text(hb_sfx_group, status_id, "off")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = cap_probe()
			imgui_layout.update_text(status_id, (p and p.get_summary and p.get_summary()) or "n/a")
		end)
		add_text(hb_sfx_group, "Capture mode")
		imgui_layout.add_action_row(hb_sfx_group, {
			{id = "QingRemasterOptions_HbSfxModeHb", label = "heartbeat only", on_click = function()
				local p = cap_probe(); if p and p.set_mode then p.set_mode("heartbeat_only") end
			end},
			{id = "QingRemasterOptions_HbSfxModeAll", label = "all SFX", on_click = function()
				local p = cap_probe(); if p and p.set_mode then p.set_mode("all") end
			end},
		})
		local win_id = "QingRemasterOptions_HbSfxCoWin"
		ImGui.AddDragFloat(hb_sfx_group, win_id, "co_window frames", function(value)
			local p = cap_probe()
			if p and p.set_co_window then p.set_co_window(value) end
		end, 15, 1, 1, 90, "%.0f")
		ImGui.AddCallback(win_id, ImGuiCallback.Render, function()
			local p = cap_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData(win_id, ImGuiData.Value, tonumber(cfg.co_window) or 15)
		end)
		add_text(hb_sfx_group, "对照参考（应随时能听见；心跳若需贴耳=低频问题）")
		imgui_layout.add_action_row(hb_sfx_group, {
			{id = "QingRemasterOptions_HbSfxPrevPage", label = "翻页 PAGE vol1", on_click = function()
				local p = cap_probe(); if p and p.preview_ref then p.preview_ref("page", 1.0) end
			end},
			{id = "QingRemasterOptions_HbSfxPrevPage5", label = "翻页 vol5", on_click = function()
				local p = cap_probe(); if p and p.preview_ref then p.preview_ref("page", 5.0) end
			end},
			{id = "QingRemasterOptions_HbSfxPrevMachine", label = "Machine vol1", on_click = function()
				local p = cap_probe(); if p and p.preview_ref then p.preview_ref("machine", 1.0) end
			end},
			{id = "QingRemasterOptions_HbSfxPrevTear", label = "TEARS_FIRE vol1", on_click = function()
				local p = cap_probe(); if p and p.preview_ref then p.preview_ref("tear", 1.0) end
			end},
		})
		add_text(hb_sfx_group, "A/B Preview — Qing custom（harmonic 40%；需重启吃 wav）")
		imgui_layout.add_action_row(hb_sfx_group, {
			{id = "QingRemasterOptions_HbSfxPrevQHb", label = "Qing HB vol1", on_click = function()
				local p = cap_probe(); if p and p.preview then p.preview("heartbeat", "qing", 1.0) end
			end},
			{id = "QingRemasterOptions_HbSfxPrevQFa", label = "Qing FASTER", on_click = function()
				local p = cap_probe(); if p and p.preview then p.preview("faster", "qing", 1.0) end
			end},
			{id = "QingRemasterOptions_HbSfxPrevQFest", label = "Qing FASTEST", on_click = function()
				local p = cap_probe(); if p and p.preview then p.preview("fastest", "qing", 1.0) end
			end},
		})
		imgui_layout.add_action_row(hb_sfx_group, {
			{id = "QingRemasterOptions_HbSfxPrevQ5", label = "Qing HB vol5", on_click = function()
				local p = cap_probe(); if p and p.preview then p.preview("heartbeat", "qing", 5.0) end
			end},
			{id = "QingRemasterOptions_HbSfxPrevStack", label = "Qing stacked vol1", on_click = function()
				local p = cap_probe(); if p and p.preview_stacked then p.preview_stacked("heartbeat", 1.0) end
			end},
		})
		add_text(hb_sfx_group, "A/B Preview — Vanilla 321–323（纯低音对照）")
		imgui_layout.add_action_row(hb_sfx_group, {
			{id = "QingRemasterOptions_HbSfxPrevVHb", label = "Vanilla HB", on_click = function()
				local p = cap_probe(); if p and p.preview then p.preview("heartbeat", "vanilla", 1.0) end
			end},
			{id = "QingRemasterOptions_HbSfxPrevVFa", label = "Vanilla FASTER", on_click = function()
				local p = cap_probe(); if p and p.preview then p.preview("faster", "vanilla", 1.0) end
			end},
			{id = "QingRemasterOptions_HbSfxPrevVFest", label = "Vanilla FASTEST", on_click = function()
				local p = cap_probe(); if p and p.preview then p.preview("fastest", "vanilla", 1.0) end
			end},
		})
		imgui_layout.add_action_row(hb_sfx_group, {
			{id = "QingRemasterOptions_HbSfxClear", label = "Clear log", on_click = function()
				local p = cap_probe(); if p and p.clear then p.clear() end
			end},
		})
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(hb_sfx_group, cap_probe, {
			id_prefix = "QingRemasterOptions_HbSfxCapOut",
			export_label = "Export JSON",
		})
	end
	end

	local aeon_replay_group = start_probe_module(
		"audit_aeon_replay",
		"Aeon? Replay Lifecycle",
		"QingRemasterOptions_GroupAeonReplayProbe"
	)
	if aeon_replay_group then
	do
		local function aeon_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.others.aeon_replay_probe")
		end
		add_text(
			aeon_replay_group,
			"默认关闭，不写存档。采永恒? 生命周期边沿 + 跨层用例：完成录制→普通换房应保留 record→下一层应清空 runtime/save。启用后玩卡，再 Copy/Export。"
		)
		local aeon_status_id = "QingRemasterOptions_AeonReplayStatus"
		imgui_layout.add_wrapped_text(aeon_replay_group, aeon_status_id, "Idle")
		ImGui.AddCallback(aeon_status_id, ImGuiCallback.Render, function()
			local p = aeon_probe()
			local body = (p and p.get_status_text and p.get_status_text()) or "probe unavailable"
			imgui_layout.update_text(aeon_status_id, body)
		end)
		local enable_id = "QingRemasterOptions_AeonReplayEnabled"
		ImGui.AddCheckbox(aeon_replay_group, enable_id, "启用 Aeon Replay 探针", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = aeon_probe()
			local on = p and p.get_config and p.get_config().enabled == true
			ImGui.UpdateData(enable_id, ImGuiData.Value, on == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = aeon_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		imgui_layout.add_small_action_row(aeon_replay_group, {
			{id = "QingRemasterOptions_AeonReplayClear", label = "Clear Events", on_click = function()
				local p = aeon_probe(); if p and p.clear_events then p.clear_events() end
			end},
			{id = "QingRemasterOptions_AeonReplayArmFloor", label = "Arm Floor Case", on_click = function()
				local p = aeon_probe(); if p and p.arm_floor_boundary_case then p.arm_floor_boundary_case() end
			end},
		})
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		probe_output.add_probe_output_controls(aeon_replay_group, aeon_probe, {
			id_prefix = "QingRemasterOptions_AeonReplayOut",
			export_label = "Export JSONL",
		})
	end
	end

	local glaze_chest_group = start_probe_module("audit_glaze_chest", "琉璃宝箱钥匙审计", "QingRemasterOptions_GroupGlazeChest")
	do
		add_text(glaze_chest_group, "对照 key_cnt / 待合并 fake / 未捡钥匙任务（chest_seed）与本房箱·钥匙实体。默认实时刷新，不写盘。")
		local status_id = "QingRemasterOptions_GlazeChestAuditStatus"
		imgui_layout.add_wrapped_text(glaze_chest_group, status_id, "加载中...")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local ok, chest = pcall(require, "Qing_Remaster_scripts.pickups.pickup_glaze_chest")
			local body = (ok and chest and chest.get_key_audit_text and chest.get_key_audit_text()) or "无法加载 pickup_glaze_chest"
			imgui_layout.update_text(status_id, body)
		end)
	end
	do
		local function orb_mod()
			local ok, mod = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Orbital_holder")
			if ok then return mod end
			return nil
		end
		local orb_probe_group = start_probe_module("item_flight_orbital_probe", "Flight Orbital Inspector", "QingRemasterOptions_GroupFlightOrbitalProbe")
		ImGui.AddButton(orb_probe_group, "QingRemasterOptions_FlightOrbital_Probe", "采样 layer0-4 / 真实环绕", function()
			local mod = orb_mod()
			if mod and mod.probe_orbit_params then mod.probe_orbit_params() end
		end)
		local probe_status_id = "QingRemasterOptions_FlightOrbital_ProbeStatus"
		imgui_layout.add_wrapped_text(orb_probe_group, probe_status_id, "尚未采样")
		ImGui.AddCallback(probe_status_id, ImGuiCallback.Render, function()
			local mod = orb_mod()
			local body = (mod and mod._last_orbit_probe) or "尚未采样"
			imgui_layout.update_text(probe_status_id, body ~= "" and body or "尚未采样")
		end)
	end
	local eid_group = start_probe_module("audit_blueprint_eid", text("group_blueprint_eid_audit"), "QingRemasterOptions_GroupBlueprintEidAudit")
	add_text(eid_group, text("blueprint_eid_audit_help"))
	ImGui.AddButton(eid_group, "QingRemasterOptions_ExportBlueprintEidAudit", text("blueprint_eid_audit_export"), function()
		local ok, copy = pcall(require, "Qing_Remaster_scripts.others.craft_eid_copy")
		if not ok or not copy or not copy.export_eid_audit then
			print("[Qing] blueprint EID audit: craft_eid_copy unavailable")
			return
		end
		local ok_zh, path_zh, payload_zh = copy.export_eid_audit(true)
		local ok_en, path_en, payload_en = copy.export_eid_audit(false)
		local n_zh = payload_zh and payload_zh.count or 0
		local n_en = payload_en and payload_en.count or 0
		local long_zh, long_en = 0, 0
		if payload_zh and payload_zh.rows then
			for _, row in ipairs(payload_zh.rows) do
				if row.too_long then long_zh = long_zh + 1 end
			end
		end
		if payload_en and payload_en.rows then
			for _, row in ipairs(payload_en.rows) do
				if row.too_long then long_en = long_en + 1 end
			end
		end
		print(string.format(
			"[Qing] blueprint EID audit zh=%s (%d rows, %d too_long) en=%s (%d rows, %d too_long)",
			ok_zh and tostring(path_zh) or ("FAIL:"..tostring(path_zh)),
			n_zh, long_zh,
			ok_en and tostring(path_en) or ("FAIL:"..tostring(path_en)),
			n_en, long_en
		))
	end)

	local imitate_group = start_probe_module("audit_imitate", text("group_imitate_items"), "QingRemasterOptions_GroupImitateItems")
	add_text(imitate_group, text("run_only"))
	ImGui.AddButton(imitate_group, "QingRemasterOptions_ReevaluateImitateItems", text("reevaluate_imitate"), function()
		if Isaac.IsInGame and Isaac.IsInGame() then
			local imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")
			imitate_item_holder.Evaluate_Imitate_Items()
			push_notice(text("reevaluated_notice"))
		else
			push_notice(text("start_run_first"), error_notice_type())
		end
	end)
	ImGui.AddButton(imitate_group, "QingRemasterOptions_PrintImitateItems", text("print_imitate"), function()
		local recorder = save.elses and save.elses["Imi_item_r_recorder"] or {}
		for player_idx,records in pairs(recorder) do
			for collid,count in pairs(records or {}) do
				print("QING:: FakeItem player="..tostring(player_idx).." id="..tostring(collid).." count="..tostring(count))
			end
		end
		push_notice(text("printed_notice"))
	end)

	-- Story / Wind: pipeline capture (read-only diagnostics for Storm V5).
	local wind_pipeline_group = start_probe_module(
		"audit_wind_pipeline",
		(Options and Options.Language == "en") and "Wind · Pipeline Probe" or "风场 · 管线探针",
		"QingRemasterOptions_GroupWindPipelineProbe"
	)
	if wind_pipeline_group then
		local function wind_pipeline_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.threads.wind.wind_pipeline_probe")
		end
		add_text(
			wind_pipeline_group,
			"只读 120 帧采样：Story/BFS/Session/Update/Render/Physics。Force 需支线测试会话。Render()≠屏幕可见。"
		)
		local p = wind_pipeline_probe()
		if p and p.build_ui then
			p.build_ui(wind_pipeline_group, "QingRemasterOptions_WindPipeline")
		else
			add_text(wind_pipeline_group, (dev_env.format_probe_unavailable
				and dev_env.format_probe_unavailable(
					"Qing_Remaster_scripts.threads.wind.wind_pipeline_probe",
					"风场管线探针不可用。"
				)) or "风场管线探针不可用。")
		end
	end

	-- Story / Stone: board + burial render diagnosis (authoritative probe UI).
	local stone_render_group = start_probe_module(
		"audit_stone_render",
		(Options and Options.Language == "en") and "Stone · Render Probe" or "Stone · 渲染探针",
		"QingRemasterOptions_GroupStoneRenderProbe"
	)
	if stone_render_group then
		local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
		local function stone_probe()
			return dev_env.require_probe("Qing_Remaster_scripts.debug.stone_render_probe")
		end
		add_text(
			stone_render_group,
			"棋盘回调 / 门禁 / 洋红格 / Burial LayerState 时间线。默认关闭，不写存档，不改正式绘制框架。"
		)
		local enable_id = "QingRemasterOptions_StoneRenderEnabled"
		ImGui.AddCheckbox(stone_render_group, enable_id, "启用探针", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local p = stone_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData(enable_id, ImGuiData.Value, cfg.enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local p = stone_probe()
			if p and p.set_enabled then p.set_enabled(value == true) end
		end)
		local mag_id = "QingRemasterOptions_StoneRenderMagenta"
		ImGui.AddCheckbox(stone_render_group, mag_id, "固定洋红格", nil, false)
		ImGui.AddCallback(mag_id, ImGuiCallback.Render, function()
			local p = stone_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData(mag_id, ImGuiData.Value, cfg.magenta_tile == true)
		end)
		ImGui.AddCallback(mag_id, ImGuiCallback.Edited, function(value)
			local p = stone_probe()
			if p and p.set_mode then p.set_mode({magenta_tile = value == true}) end
		end)
		ImGui.AddElement(stone_render_group, "", ImGuiElement.SameLine)
		local full_id = "QingRemasterOptions_StoneRenderFull"
		ImGui.AddCheckbox(stone_render_group, full_id, "强制满盘", nil, false)
		ImGui.AddCallback(full_id, ImGuiCallback.Render, function()
			local p = stone_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData(full_id, ImGuiData.Value, cfg.force_full_board == true)
		end)
		ImGui.AddCallback(full_id, ImGuiCallback.Edited, function(value)
			local p = stone_probe()
			if p and p.set_mode then p.set_mode({force_full_board = value == true}) end
		end)
		ImGui.AddElement(stone_render_group, "", ImGuiElement.SameLine)
		local cmp_id = "QingRemasterOptions_StoneRenderCompare"
		ImGui.AddCheckbox(stone_render_group, cmp_id, "对比 POST_RENDER", nil, false)
		ImGui.AddCallback(cmp_id, ImGuiCallback.Render, function()
			local p = stone_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData(cmp_id, ImGuiData.Value, cfg.compare_post_render == true)
		end)
		ImGui.AddCallback(cmp_id, ImGuiCallback.Edited, function(value)
			local p = stone_probe()
			if p and p.set_mode then p.set_mode({compare_post_render = value == true}) end
		end)
		ImGui.AddElement(stone_render_group, "", ImGuiElement.SameLine)
		local route_id = "QingRemasterOptions_StoneRenderGridRoute"
		ImGui.AddCheckbox(stone_render_group, route_id, "Grid Routing Test", nil, false)
		ImGui.AddCallback(route_id, ImGuiCallback.Render, function()
			local p = stone_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData(route_id, ImGuiData.Value, cfg.grid_routing_test == true)
		end)
		ImGui.AddCallback(route_id, ImGuiCallback.Edited, function(value)
			local p = stone_probe()
			if p and p.set_mode then p.set_mode({grid_routing_test = value == true}) end
		end)
		add_text(
			stone_render_group,
			"裁剪模式（V3.1）：Full=不裁剪基线；Projection=Zeis 式 WorldToScreen；Optimized=候选+精裁。"
		)
		local function set_cull(mode)
			local p = stone_probe()
			if p and p.set_mode then p.set_mode({cull_mode = mode}) end
		end
		ImGui.AddButton(stone_render_group, "QingRemasterOptions_StoneCullFull", "Cull: Full", function()
			set_cull("full")
		end)
		ImGui.AddElement(stone_render_group, "", ImGuiElement.SameLine)
		ImGui.AddButton(stone_render_group, "QingRemasterOptions_StoneCullProj", "Cull: Projection", function()
			set_cull("projection")
		end)
		ImGui.AddElement(stone_render_group, "", ImGuiElement.SameLine)
		ImGui.AddButton(stone_render_group, "QingRemasterOptions_StoneCullOpt", "Cull: Optimized", function()
			set_cull("optimized")
		end)
		ImGui.AddElement(stone_render_group, "", ImGuiElement.SameLine)
		ImGui.AddButton(stone_render_group, "QingRemasterOptions_StoneCullAssert", "断言 Optimized⊇Projection", function()
			local p = stone_probe()
			local r = p and p.assert_cull_coverage and p.assert_cull_coverage() or {}
			Isaac.ConsoleOutput(string.format(
				"[StoneCull] ok=%s missing=%d proj=%s opt=%s\n",
				tostring(r.ok), #(r.missing or {}), tostring(r.projection_count), tostring(r.optimized_count)
			))
		end)
		add_text(
			stone_render_group,
			"Grid Routing：洋红=EMPTY / 青=GRID_PRE / 黄=PIT_POST。Summary 含各阶段 last frame 与门禁 STALE。"
		)
		add_text(
			stone_render_group,
			"V3.2 性能归因 / V3.3 共享帧上下文：开 Attribution 后看 render_context_builds≈1、frame_ctx hit/miss、verify_owner。隔离模式只影响绘制。"
		)
		local perf_on_id = "QingRemasterOptions_StonePerfAttr"
		ImGui.AddCheckbox(stone_render_group, perf_on_id, "Performance Attribution", nil, false)
		ImGui.AddCallback(perf_on_id, ImGuiCallback.Render, function()
			local p = stone_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData(perf_on_id, ImGuiData.Value, cfg.perf_attr == true)
		end)
		ImGui.AddCallback(perf_on_id, ImGuiCallback.Edited, function(value)
			local p = stone_probe()
			if p and p.set_mode then p.set_mode({perf_attr = value == true}) end
		end)
		ImGui.AddElement(stone_render_group, "", ImGuiElement.SameLine)
		local fv_id = "QingRemasterOptions_StonePerfFixedView"
		ImGui.AddCheckbox(stone_render_group, fv_id, "固定视角采样", nil, false)
		ImGui.AddCallback(fv_id, ImGuiCallback.Render, function()
			local p = stone_probe()
			local cfg = p and p.get_config and p.get_config() or {}
			ImGui.UpdateData(fv_id, ImGuiData.Value, cfg.fixed_view == true)
		end)
		ImGui.AddCallback(fv_id, ImGuiCallback.Edited, function(value)
			local p = stone_probe()
			if p and p.set_mode then p.set_mode({fixed_view = value == true}) end
		end)
		local function set_iso(mode)
			local p = stone_probe()
			if p and p.set_mode then p.set_mode({isolation = mode}) end
		end
		ImGui.AddButton(stone_render_group, "QingRemasterOptions_StoneIsoNormal", "Iso: Normal", function()
			set_iso("normal")
		end)
		ImGui.AddElement(stone_render_group, "", ImGuiElement.SameLine)
		ImGui.AddButton(stone_render_group, "QingRemasterOptions_StoneIsoNoSpr", "No Sprite Draw", function()
			set_iso("no_sprite_draw")
		end)
		ImGui.AddElement(stone_render_group, "", ImGuiElement.SameLine)
		ImGui.AddButton(stone_render_group, "QingRemasterOptions_StoneIsoNoBoard", "No Board Render", function()
			set_iso("no_board_render")
		end)
		ImGui.AddElement(stone_render_group, "", ImGuiElement.SameLine)
		ImGui.AddButton(stone_render_group, "QingRemasterOptions_StoneIsoNoVis", "No Stone Visuals", function()
			set_iso("no_stone_visuals")
		end)
		ImGui.AddButton(stone_render_group, "QingRemasterOptions_StonePerfReset", "Reset Perf Samples", function()
			local p = stone_probe()
			if p and p.reset_perf_samples then p.reset_perf_samples() end
		end)
		ImGui.AddElement(stone_render_group, "", ImGuiElement.SameLine)
		ImGui.AddButton(stone_render_group, "QingRemasterOptions_StonePerfCopy", "Copy Perf Summary", function()
			local p = stone_probe()
			if p and p.copy_perf_summary then p.copy_perf_summary() end
		end)
		local perf_status_id = "QingRemasterOptions_StonePerfStatus"
		imgui_layout.add_wrapped_text(stone_render_group, perf_status_id, "Attribution OFF。")
		ImGui.AddCallback(perf_status_id, ImGuiCallback.Render, function()
			local p = stone_probe()
			local lines = p and p.get_perf_summary_lines and p.get_perf_summary_lines() or { "开发探针不可用。" }
			imgui_layout.update_text(perf_status_id, table.concat(lines, "\n"))
		end)
		add_text(
			stone_render_group,
			"Tile Scale：正式默认 67%≈0.5556。探针对照 100%/80%/67%/50% + 拖动。"
		)
		local function set_tile_preset(key)
			local p = stone_probe()
			local board = require("Qing_Remaster_scripts.threads.stone.stone_board")
			local presets = board.get_tile_scale_presets()
			local v = presets[key]
			if p and p.set_mode and v then p.set_mode({tile_scale = v}) end
		end
		ImGui.AddButton(stone_render_group, "QingRemasterOptions_StoneTile100", "100% 0.8333", function()
			set_tile_preset("s100")
		end)
		ImGui.AddElement(stone_render_group, "", ImGuiElement.SameLine)
		ImGui.AddButton(stone_render_group, "QingRemasterOptions_StoneTile80", "80% 0.6667", function()
			set_tile_preset("s80")
		end)
		ImGui.AddElement(stone_render_group, "", ImGuiElement.SameLine)
		ImGui.AddButton(stone_render_group, "QingRemasterOptions_StoneTile67", "67% 0.5556", function()
			set_tile_preset("s67")
		end)
		ImGui.AddElement(stone_render_group, "", ImGuiElement.SameLine)
		ImGui.AddButton(stone_render_group, "QingRemasterOptions_StoneTile50", "50% 0.4167", function()
			set_tile_preset("s50")
		end)
		add_probe_drag(
			stone_render_group,
			"QingRemasterOptions_StoneTileScaleDrag",
			"Tile Scale",
			function(value)
				local p = stone_probe()
				if p and p.set_mode then p.set_mode({tile_scale = value}) end
			end,
			function()
				local p = stone_probe()
				local cfg = p and p.get_config and p.get_config() or {}
				return cfg.tile_scale_live or (40 / 48)
			end,
			40 / 48,
			0.01,
			0.1,
			1.5,
			"%.4f"
		)
		local origin = require("Qing_Remaster_scripts.threads.stone.stone_origin")
		ImGui.AddButton(stone_render_group, "QingRemasterOptions_StoneBurWhite", "Burial: White", function()
			origin.set_vis({burial_mode = "white"})
		end)
		ImGui.AddElement(stone_render_group, "", ImGuiElement.SameLine)
		ImGui.AddButton(stone_render_group, "QingRemasterOptions_StoneBurFloor", "Burial: FloorColor", function()
			origin.set_vis({burial_mode = "floor_color"})
		end)
		ImGui.AddElement(stone_render_group, "", ImGuiElement.SameLine)
		ImGui.AddButton(stone_render_group, "QingRemasterOptions_StoneBurGreen", "Burial: Pure Green", function()
			origin.set_vis({burial_mode = "pure_green"})
		end)
		local status_id = "QingRemasterOptions_StoneRenderStatus"
		imgui_layout.add_wrapped_text(stone_render_group, status_id, "探针关闭。")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local p = stone_probe()
			imgui_layout.update_text(status_id, (p and p.get_summary and p.get_summary()) or "开发探针不可用。")
		end)
		probe_output.add_probe_output_controls(stone_render_group, stone_probe, {
			id_prefix = "QingRemasterOptions_StoneRenderOut",
			export_label = "Export Report",
		})
	end

end

return M
