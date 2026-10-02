-- Player-facing Story Progress page.
-- One expandable record page per player-visible story record (incl. virtual before).
-- MUST NOT render a flat checkpoint button list for the same records.

local imgui_layout = require("Qing_Remaster_scripts.debug.imgui_debug_layout")
local control = require("Qing_Remaster_scripts.story.story_progress_control")
local registry = require("Qing_Remaster_scripts.story.story_registry")

local ui_mod = {}

local SIDE_LABELS = {
	undiscovered = {zh = "未发现", en = "Undiscovered"},
	discovered = {zh = "已发现", en = "Discovered"},
	progressing = {zh = "进行中", en = "In Progress"},
	completed = {zh = "已完成", en = "Completed"},
}

local function lang()
	return (Options and Options.Language == "en") and "en" or "zh"
end

local function tr(zh, en)
	return lang() == "en" and en or zh
end

local function pick(tbl)
	if type(tbl) ~= "table" then return tostring(tbl or "-") end
	if lang() == "en" and tbl.en then return tbl.en end
	return tbl.zh or tbl.en or "-"
end

local function side_label(state)
	return pick(SIDE_LABELS[state] or {zh = state, en = state})
end

local function status_phrase(node_view)
	if not node_view then return tr("未知", "Unknown") end
	if node_view.is_current then return tr("当前", "Current") end
	if node_view.completed then return tr("已完成", "Completed") end
	if node_view.mode == "event" then
		return side_label(node_view.side_state)
	end
	if node_view.discovered then return tr("已发现", "Discovered") end
	return tr("尚未到达", "Not reached")
end

local function add_side_combo(parent, id, node_id)
	local states = control.list_side_states()
	local labels = {}
	for i, s in ipairs(states) do
		labels[i] = side_label(s)
	end
	ImGui.AddCombobox(parent, id, tr("永久剧情状态", "Permanent progress"), function(index)
		local state = states[(index or 0) + 1]
		if state then control.set_side_state(node_id, state) end
	end, labels, 0)
	ImGui.AddCallback(id, ImGuiCallback.Render, function()
		local live = control.get_node_view(node_id)
		local idx = 0
		if live then
			for i, s in ipairs(states) do
				if s == live.side_state then idx = i - 1 break end
			end
		end
		ImGui.UpdateData(id, ImGuiData.Value, idx)
	end)
end

local function add_token_checks(parent, prefix, node_view)
	for i, tok in ipairs(node_view.tokens or {}) do
		local tid = prefix .. "_Tok" .. i
		local label = pick(tok.title)
		ImGui.AddCheckbox(parent, tid, label, function(checked)
			control.set_node_token(node_view.id, tok.id, checked == true)
		end, tok.owned == true)
		ImGui.AddCallback(tid, ImGuiCallback.Render, function()
			local live = control.get_node_view(node_view.id)
			local owned = false
			if live then
				for _, t in ipairs(live.tokens or {}) do
					if t.id == tok.id then owned = t.owned break end
				end
			end
			ImGui.UpdateData(tid, ImGuiData.Value, owned and true or false)
		end)
	end
end

local function build_virtual_page(parent_id, prefix, chapter_id, cp)
	local mark = cp.is_current and "● " or "○ "
	local hdr = imgui_layout.add_section(
		parent_id,
		prefix .. "_V_" .. cp.id:gsub("%.", "_"),
		mark .. cp.title
	)
	imgui_layout.add_wrapped_text(hdr, hdr .. "_Body", "")
	ImGui.AddCallback(hdr .. "_Body", ImGuiCallback.Render, function()
		local live_cp = nil
		for _, row in ipairs(control.list_chapter_checkpoints(chapter_id)) do
			if row.id == cp.id then live_cp = row break end
		end
		local lines = {}
		if chapter_id == "prologue" then
			lines[#lines + 1] = tr("当前状态：剧情尚未开始", "State: story has not started")
			lines[#lines + 1] = tr("序章：锁定 / 空记录", "Prologue: locked / empty")
			lines[#lines + 1] = tr("第一章：锁定", "Chapter 1: locked")
		elseif chapter_id == "chapter1" then
			lines[#lines + 1] = tr("当前状态：", "State:")
			lines[#lines + 1] = tr("序章：已完成", "Prologue: completed")
			lines[#lines + 1] = tr("第一章：已解锁（available）", "Chapter 1: unlocked (available)")
			if cp.id == "chapter1.opened" then
				lines[#lines + 1] = tr("开幕：已看过", "Opening: seen")
			else
				lines[#lines + 1] = tr("开幕：尚未播放", "Opening: not yet")
			end
			lines[#lines + 1] = tr("委托：尚未开始（无主任务）", "Commission: not started (no main quest)")
		end
		if live_cp and live_cp.is_current then
			lines[#lines + 1] = tr("（当前阶段）", "(current phase)")
		end
		imgui_layout.update_text(hdr .. "_Body", table.concat(lines, "\n"))
	end)
	ImGui.AddButton(hdr, hdr .. "_Apply", tr("恢复到此状态", "Restore to this state"), function()
		control.apply_chapter_checkpoint(chapter_id, cp.id)
	end)
	if cp.preview_scene then
		local scenes = require("Qing_Remaster_scripts.story.story_scenes")
		local label = cp.preview_label or tr("▶ 播放", "▶ Play")
		ImGui.AddButton(hdr, hdr .. "_Preview", label, function()
			scenes.play_preview(cp.preview_scene)
		end)
	end
end

local build_record_page

local function build_event_page(parent_id, prefix, node_view)
	local hdr = imgui_layout.add_section(
		parent_id,
		prefix .. "_E_" .. node_view.id:gsub("%.", "_"),
		node_view.display_title .. "  ·  " .. status_phrase(node_view)
	)
	if not node_view.editable then return end
	add_side_combo(hdr, hdr .. "_Side", node_view.id)
	if #(node_view.tokens or {}) > 0 then
		ImGui.AddElement(
			hdr, "", ImGuiElement.SeparatorText or ImGuiElement.Separator,
			tr("本局素材", "This-run materials")
		)
		add_token_checks(hdr, hdr, node_view)
	end
end

local function build_group_page(parent_id, prefix, node_view)
	local prog = node_view.requirements and node_view.requirements[1]
	local title = node_view.display_title .. "  ·  " .. status_phrase(node_view)
	if prog then
		title = string.format("%s  (%d / %d)", title, prog.current or 0, prog.target or 0)
	end
	local hdr = imgui_layout.add_section(
		parent_id, prefix .. "_G_" .. node_view.id:gsub("%.", "_"), title
	)
	imgui_layout.add_wrapped_text(hdr, hdr .. "_Prog", "")
	ImGui.AddCallback(hdr .. "_Prog", ImGuiCallback.Render, function()
		local live = control.get_node_view(node_view.id)
		local r = live and live.requirements and live.requirements[1]
		local text = ""
		if r then
			text = string.format(tr("进度：%d / %d", "Progress: %d / %d"), r.current or 0, r.target or 0)
			if r.complete then
				text = text .. tr("\n已满足下一阶段条件。", "\nReady for the next story stage.")
			end
		end
		imgui_layout.update_text(hdr .. "_Prog", text)
	end)
	ImGui.AddButton(hdr, hdr .. "_Advance", tr("推进到下一剧情阶段", "Advance to next story stage"), function()
		local live = control.get_node_view(node_view.id)
		local r = live and live.requirements and live.requirements[1]
		if r and r.complete then
			control.advance_requirement(node_view.id)
		end
	end)
	ImGui.AddButton(hdr, hdr .. "_Jump", tr("将剧情推进至此", "Advance story to here"), function()
		control.apply_checkpoint(node_view.id)
	end)
	for _, child in ipairs(node_view.children or {}) do
		if child.mode == "event" then
			build_event_page(hdr, prefix, child)
		elseif child.mode == "checkpoint" or child.mode == "group" then
			build_record_page(hdr, prefix, child)
		end
	end
end

local function build_checkpoint_page(parent_id, prefix, node_view)
	local hdr = imgui_layout.add_section(
		parent_id,
		prefix .. "_C_" .. node_view.id:gsub("%.", "_"),
		node_view.display_title .. "  ·  " .. status_phrase(node_view)
	)
	imgui_layout.add_wrapped_text(hdr, hdr .. "_St", "")
	ImGui.AddCallback(hdr .. "_St", ImGuiCallback.Render, function()
		local live = control.get_node_view(node_view.id)
		local text = tr("状态：", "Status: ") .. status_phrase(live)
		local node = require("Qing_Remaster_scripts.story.story_registry").get_node(node_view.id)
		if node and node.optional == true then
			text = text .. tr("\n可选：是", "\nOptional: yes")
		end
		local qok, qreg = pcall(require, "Qing_Remaster_scripts.quest.quest_registry")
		if qok and qreg and qreg.main_by_node and qreg.main_by_node[node_view.id] then
			local qdef = qreg.main_by_node[node_view.id]
			if qdef.optional == true and not (node and node.optional == true) then
				text = text .. tr("\n可选：是", "\nOptional: yes")
			end
		end
		imgui_layout.update_text(hdr .. "_St", text)
	end)
	ImGui.AddButton(hdr, hdr .. "_Jump", tr("将剧情推进至此", "Advance story to here"), function()
		control.apply_checkpoint(node_view.id)
	end)
	if node_view.preview_scene then
		local scenes = require("Qing_Remaster_scripts.story.story_scenes")
		local label = node_view.preview_label
			or tr("▶ 播放", "▶ Play")
		ImGui.AddButton(hdr, hdr .. "_Preview", label, function()
			scenes.play_preview(node_view.preview_scene)
		end)
	end
	if node_view.optional then
		ImGui.AddText(hdr, tr("可选：是", "Optional: yes"))
	end
end

build_record_page = function(parent_id, prefix, node_view)
	if not node_view then return end
	if node_view.mode == "group" then
		build_group_page(parent_id, prefix, node_view)
	elseif node_view.mode == "event" then
		build_event_page(parent_id, prefix, node_view)
	else
		build_checkpoint_page(parent_id, prefix, node_view)
	end
end

function ui_mod.build(parent_id)
	if not ImGui or not parent_id then return end
	local prefix = parent_id .. "_StoryProgress"

	ImGui.AddElement(
		parent_id, "", ImGuiElement.SeparatorText or ImGuiElement.Separator,
		tr("剧情进度", "Story Progress")
	)
	imgui_layout.add_wrapped_text(
		parent_id, prefix .. "_Hint",
		tr(
			"每个玩家可见记录是一个可展开页。「章节前」也是展开页。顶部只显示当前阶段。",
			"Each player-visible record is one expandable page. Chapter-before is also a page. Header shows current phase only."
		)
	)

	local tabbar = prefix .. "_ChTabs"
	ImGui.AddTabBar(parent_id, tabbar)

	for _, ch in ipairs(registry.list_chapters()) do
		local tab = tabbar .. "_" .. ch.id
		ImGui.AddTab(tabbar, tab, pick(ch.title))

		imgui_layout.add_wrapped_text(tab, prefix .. "_Hdr_" .. ch.id, "")
		ImGui.AddCallback(prefix .. "_Hdr_" .. ch.id, ImGuiCallback.Render, function()
			local view = control.get_chapter_view(ch.id)
			local lines = {}
			if view then
				lines[#lines + 1] = tr("当前阶段：", "Current phase: ") .. tostring(view.phase_label or "-")
				if view.material_progress then
					lines[#lines + 1] = string.format(
						tr("素材：%d / %d", "Materials: %d / %d"),
						view.material_progress.current or 0,
						view.material_progress.target or 0
					)
				end
			end
			imgui_layout.update_text(prefix .. "_Hdr_" .. ch.id, table.concat(lines, "\n"))
		end)

		-- Single list: virtual before + player-visible top-level records as expandable pages.
		-- list_chapter_checkpoints only includes player-visible nodes (no hidden Story nodes).
		for _, cp in ipairs(control.list_chapter_checkpoints(ch.id)) do
			if cp.virtual then
				build_virtual_page(tab, prefix, ch.id, cp)
			else
				local view = control.get_node_view(cp.id)
				if view then
					build_record_page(tab, prefix, view)
				end
			end
		end

		local manage = imgui_layout.add_section(
			tab, prefix .. "_Manage_" .. ch.id,
			tr("修改保护", "Edit safety")
		)
		ImGui.AddButton(manage, prefix .. "_Restore_" .. ch.id, tr("恢复修改前状态", "Restore pre-edit state"), function()
			control.restore_backup()
		end)

		imgui_layout.add_wrapped_text(tab, prefix .. "_Val_" .. ch.id, "")
		ImGui.AddCallback(prefix .. "_Val_" .. ch.id, ImGuiCallback.Render, function()
			local report = control.validate_chapter(ch.id)
			if report.ok and #(report.issues or {}) == 0 then
				imgui_layout.update_text(prefix .. "_Val_" .. ch.id, tr("剧情记录：正常", "Story records: OK"))
				return
			end
			local lines = {tr("检测到剧情记录不一致", "Inconsistent story records detected")}
			for _, issue in ipairs(report.issues or {}) do
				lines[#lines + 1] = "- " .. tostring(issue.code)
			end
			imgui_layout.update_text(prefix .. "_Val_" .. ch.id, table.concat(lines, "\n"))
		end)
		ImGui.AddButton(tab, prefix .. "_Repair_" .. ch.id, tr("恢复为有效状态", "Restore to a valid state"), function()
			control.repair_chapter(ch.id)
		end)
	end
end

return ui_mod
