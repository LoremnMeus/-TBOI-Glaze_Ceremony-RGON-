-- ImGui panel for Story Dev Lab (DEV). UI only — no Story rules.
-- Tabs: 流程验证 → 支线沙盒 → 任务/UI → 审计/诊断
-- Player-facing progress edits live in debug/story_progress_ui.lua.

local registry = require("Qing_Remaster_scripts.story_test.story_test_registry")
local imgui_layout = require("Qing_Remaster_scripts.debug.imgui_debug_layout")
local session = require("Qing_Remaster_scripts.story_test.story_test_session")
local runner = require("Qing_Remaster_scripts.story_test.story_test_runner")
local scenes = require("Qing_Remaster_scripts.story.story_scenes")
local quest_registry = require("Qing_Remaster_scripts.quest.quest_registry")
local pause_ui = require("Qing_Remaster_scripts.auxiliary.pause_ui")
local bank_debug = require("Qing_Remaster_scripts.threads.bank.bank_debug")
local stone_debug = require("Qing_Remaster_scripts.threads.stone.stone_debug")

local imgui = {}

local ui = {
	chapter_index = 0,
	step_index = 0,
	prereq_index = 0,
	show_advanced = false,
	quest_ox = 0,
	quest_oy = 0,
	hint_ox = 0,
	hint_oy = 0,
}

local function lang()
	return registry.lang()
end

local function tr(zh, en)
	return lang() == "en" and en or zh
end

local function pick(tbl)
	return registry.pick_lang(tbl, lang())
end

local function d(category, key)
	return registry.display(category, key, lang())
end

local function chapter_options()
	local list = registry.list_chapters()
	local labels = {}
	local story_registry = require("Qing_Remaster_scripts.story.story_registry")
	for i, id in ipairs(list) do
		local ch = story_registry.get_chapter(id)
		labels[i] = (ch and pick(ch.title)) or id
	end
	return list, labels
end

local function step_options(chapter_id)
	local steps = registry.list_steps(chapter_id)
	local labels = {}
	for i, step in ipairs(steps) do
		local status = step.implementation_status or "implemented"
		local mark = registry.result_mark(
			status == "implemented" and "ok"
				or status == "partial" and "partial"
				or status == "wip" and "wip"
				or "blocked"
		)
		labels[i] = mark .. " " .. pick(step.label)
	end
	return steps, labels
end

local function selected_chapter()
	local chapters = registry.list_chapters()
	return chapters[ui.chapter_index + 1] or chapters[1]
end

local function selected_step()
	local steps = registry.list_steps(selected_chapter())
	return steps[ui.step_index + 1]
end

local function chapter_title_of(id)
	local story_registry = require("Qing_Remaster_scripts.story.story_registry")
	local ch = story_registry.get_chapter(id)
	return (ch and pick(ch.title)) or tostring(id or "-")
end

local function session_header_text()
	local info = runner.inspect()
	local step = selected_step()
	local flow = info.flow_node or (step and registry.flow_checks_for_step(step))
	local lines = {}
	lines[#lines + 1] = tr("测试会话：", "Test session: ")
		.. (info.test_active and tr("已开启", "Active") or tr("未开启", "Inactive"))
	lines[#lines + 1] = tr("当前章节：", "Chapter: ") .. chapter_title_of(selected_chapter())
	if step then
		lines[#lines + 1] = tr("当前步骤：", "Step: ") .. pick(step.label)
	end
	if flow then
		lines[#lines + 1] = tr("流程状态：", "Flow: ") .. d("result", flow.result)
	end
	if info.message then
		lines[#lines + 1] = tr("消息：", "Msg: ") .. tostring(info.message)
	end
	return table.concat(lines, "\n")
end

local function flow_check_line(ok, zh_ok, zh_bad, en_ok, en_bad)
	local mark = ok and "✓" or "✗"
	return mark .. " " .. (ok and tr(zh_ok, en_ok) or tr(zh_bad, en_bad))
end

local function current_step_diag_text()
	local step = selected_step()
	if not step then return tr("（无步骤）", "(no step)") end
	local flow = registry.flow_checks_for_step(step)
	local lines = {}
	lines[#lines + 1] = tr("当前步骤", "Current Step")
	lines[#lines + 1] = "────────────────"
	lines[#lines + 1] = "ID：" .. step.id
	lines[#lines + 1] = tr("剧情节点：", "Story node: ")
		.. (flow and flow.title and pick(flow.title) or tostring(step.story_node or "-"))
	lines[#lines + 1] = tr("实现状态：", "Implementation: ")
		.. d("status", (flow and flow.implementation_status) or step.implementation_status or "implemented")
	lines[#lines + 1] = tr("进入方式：", "Entry: ")
		.. d("entry", (flow and flow.entry_mode) or (step.entry and step.entry.mode) or "state_only")
	if step.entry and step.entry.scene then
		local wired = scenes.is_available(step.entry.scene)
		lines[#lines + 1] = tr("场景：", "Scene: ")
			.. tostring(step.entry.scene)
			.. " (" .. d("wired", wired) .. ")"
	end
	if step.thread then
		lines[#lines + 1] = tr("线程：", "Thread: ")
			.. tostring(step.thread.id) .. " / " .. tostring(step.thread.phase)
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = tr("流程检查", "Flow Checks")
	if flow then
		lines[#lines + 1] = flow_check_line(
			flow.story_defined,
			"Story 节点已定义", "Story 节点未定义",
			"Story node defined", "Story node missing"
		)
		lines[#lines + 1] = flow_check_line(
			flow.prepare_ready,
			"测试状态可准备", "测试状态无法准备",
			"State prepare ready", "State prepare missing"
		)
		lines[#lines + 1] = flow_check_line(
			flow.runtime_entry_ready,
			"正式运行入口已接线", "正式运行入口未接线",
			"Runtime entry wired", "Runtime entry missing"
		)
		lines[#lines + 1] = flow_check_line(
			flow.completion_ready,
			"完成后的剧情推进已实现", "完成后的剧情推进缺失",
			"Completion transition ready", "Completion transition missing"
		)
		lines[#lines + 1] = flow_check_line(
			flow.quest_ready,
			"Quest 可正确解析", "Quest 未映射",
			"Quest resolves", "Quest unmapped"
		)
		lines[#lines + 1] = flow_check_line(
			flow.next_ready,
			"下一节点存在", "下一节点缺失",
			"Next node exists", "Next node missing"
		)
		lines[#lines + 1] = ""
		lines[#lines + 1] = tr("结论：", "Result: ") .. d("result", flow.result)
		if flow.primary_blocker then
			lines[#lines + 1] = tr("阻塞原因：", "Blocker: ")
				.. d("blocker", flow.primary_blocker)
		end
	end
	if step.notes then
		lines[#lines + 1] = ""
		lines[#lines + 1] = pick(step.notes)
	end
	return table.concat(lines, "\n")
end

local function flow_overview_text(chapter_id)
	chapter_id = chapter_id or selected_chapter() or "chapter1"
	local flow = registry.audit_story_flow(chapter_id)
	local lines = {}
	lines[#lines + 1] = chapter_title_of(chapter_id) .. tr("流程总览", " Flow Overview")
	lines[#lines + 1] = "────────────────"
	for _, row in ipairs(flow.nodes or {}) do
		local mark = registry.result_mark(row.result)
		local title = row.title and pick(row.title) or row.node_id
		lines[#lines + 1] = string.format("%s %s", mark, title)
	end
	local c = flow.counts or {}
	lines[#lines + 1] = ""
	lines[#lines + 1] = string.format(
		tr("流程节点：%d", "Nodes: %d"), c.total or 0
	)
	lines[#lines + 1] = string.format(
		tr("正常：%d   部分完成：%d   阻塞：%d   开发中：%d",
			"OK: %d   Partial: %d   Blocked: %d   WIP: %d"),
		c.ok or 0, c.partial or 0, c.blocked or 0, c.wip or 0
	)
	return table.concat(lines, "\n")
end

local function side_stage_chain_text(side, st)
	local lines = {}
	local stages = {"discovered", "progressing", "climax"}
	local current = side.stage
	local completed = st and st.is_node_completed
		and st.is_node_completed("chapter1", side.id) == true
	local token_owned = false
	if st and st.has_token then
		-- Best-effort: material token from alchemy map
		local map = registry.get_material_node_map()
		for token, node in pairs(map) do
			if node == side.id then
				token_owned = st.has_token("chapter1", token) == true
				break
			end
		end
	end
	lines[#lines + 1] = (side.title or side.id)
	lines[#lines + 1] = tr("节点：", "Node: ") .. tostring(side.id)
	lines[#lines + 1] = tr("当前阶段：", "Stage: ")
		.. d("side_stage", current or "discovered")
	lines[#lines + 1] = tr("Story 首通：", "Story clear: ")
		.. (completed and tr("已完成", "Done") or tr("未完成", "Not done"))
	lines[#lines + 1] = tr("本局素材：", "Run material: ")
		.. (token_owned and tr("已取得", "Owned") or tr("未取得", "Missing"))
	lines[#lines + 1] = tr("阶段流程：", "Stage chain:")
	local reached = false
	for _, key in ipairs(stages) do
		local mark = "○"
		if completed then
			mark = "✓"
		elseif current == key then
			mark = "✓"
			reached = true
		elseif not reached and current then
			-- prior stages assumed passed if a later stage is active
			local order = {discovered = 1, progressing = 2, climax = 3}
			if (order[current] or 0) > (order[key] or 0) then
				mark = "✓"
			end
		end
		lines[#lines + 1] = string.format("  %s %s", mark, d("side_stage", key))
	end
	if completed then
		lines[#lines + 1] = "  ✓ " .. d("side_stage", "complete")
	else
		lines[#lines + 1] = "  ○ " .. d("side_stage", "complete")
	end
	return table.concat(lines, "\n")
end

local function quest_system_text()
	local info = runner.inspect()
	local gate = info.quest_gate or {}
	local lines = {}
	lines[#lines + 1] = tr("任务系统", "Quest System")
	lines[#lines + 1] = "────────────────"
	lines[#lines + 1] = tr("系统状态：", "Status: ")
		.. (gate.revealed and tr("已解锁", "Unlocked") or tr("未解锁", "Locked"))
	lines[#lines + 1] = tr("当前章节：", "Chapter: ")
		.. chapter_title_of(gate.chapter_id)
	lines[#lines + 1] = tr("剧情节点：", "Story node: ")
		.. tostring(gate.current_node or "-")
	lines[#lines + 1] = tr("剧情目标：", "Story objective: ")
		.. tostring(gate.objective or "-")
	lines[#lines + 1] = ""
	if info.quest_main then
		lines[#lines + 1] = tr("当前任务：", "Current quest: ")
			.. tostring(info.quest_main.title or "-")
		lines[#lines + 1] = tr("任务目标：", "Objective: ")
			.. tostring(info.quest_main.objective or "-")
		if info.quest_main.progress_text then
			lines[#lines + 1] = tr("进度：", "Progress: ")
				.. tostring(info.quest_main.progress_text)
		end
		local src = info.quest_main.resolve_source or gate.resolve_source
		lines[#lines + 1] = tr("解析来源：", "Resolve source: ")
			.. d("resolve_source", src or "-")
		if src == "fallback" then
			local reason = info.quest_main.fallback_reason
				or (info.quest_panel and info.quest_panel.main and info.quest_panel.main.fallback_reason)
			lines[#lines + 1] = tr("⚠ 当前任务使用后备文案", "⚠ Using fallback copy")
			if reason then
				lines[#lines + 1] = tr("原因：", "Reason: ") .. tostring(reason)
			end
		end
	else
		lines[#lines + 1] = tr("当前任务：（无）", "Current quest: (none)")
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = tr("暂停页入口：", "Pause entry: ")
		.. (gate.entry_ok and tr("正常", "OK") or tr("不可用", "Unavailable"))
	local tracker_on = info.quest_prefs and info.quest_prefs.tracker_enabled == true
	lines[#lines + 1] = tr("常驻任务追踪：", "Persistent tracker: ")
		.. (tracker_on and tr("开启", "On") or tr("关闭", "Off"))
	local cov = info.quest_coverage
	if cov then
		lines[#lines + 1] = tr("Quest 映射覆盖：", "Quest coverage: ")
			.. (cov.ok and tr("正常", "OK") or tr("有缺口", "Gaps"))
		if cov.missing and #cov.missing > 0 then
			for i = 1, math.min(6, #cov.missing) do
				lines[#lines + 1] = "  ⚠ " .. tostring(cov.missing[i])
			end
		end
	end

	-- Side quest stage chains
	local sides = info.quest_sides or info.quest_panel and info.quest_panel.sides
	if sides and #sides > 0 then
		lines[#lines + 1] = ""
		lines[#lines + 1] = tr("已发现支线", "Discovered sides")
		lines[#lines + 1] = "────────────────"
		local st = require("Qing_Remaster_scripts.story.story_state")
		for _, side in ipairs(sides) do
			lines[#lines + 1] = side_stage_chain_text(side, st)
			lines[#lines + 1] = ""
		end
	end
	return table.concat(lines, "\n")
end

local function layout_debug_text()
	local pause = pause_ui.get_audit_snapshot()
	local panel_ok, panel = pcall(require, "Qing_Remaster_scripts.quest.quest_panel")
	local audit = panel_ok and panel.get_audit_snapshot and panel.get_audit_snapshot() or {}
	local lines = {}
	lines[#lines + 1] = tr("任务界面布局", "Quest Layout")
	lines[#lines + 1] = "────────────────"
	local variant = pause.variant or "-"
	local variant_label = variant
	if variant == "vanilla" then variant_label = tr("原版", "Vanilla")
	elseif variant == "mini" then variant_label = tr("迷你", "Mini")
	elseif variant == "unintrusive" then variant_label = tr("不打扰", "Unintrusive")
	end
	lines[#lines + 1] = tr("暂停菜单类型：", "Pause variant: ") .. variant_label

	local base = pause.quest_base or {}
	local off = pause.debug_offset or {}
	local fin = pause.quest_local_final or {}
	local screen = pause.quest_screen or {}
	lines[#lines + 1] = string.format(
		tr("任务基准位置：(%s, %s)", "Quest base: (%s, %s)"),
		tostring(base.x or "-"), tostring(base.y or "-")
	)
	lines[#lines + 1] = string.format(
		tr("任务调试偏移：(%s, %s)", "Quest debug offset: (%s, %s)"),
		tostring(off.quest_x or 0), tostring(off.quest_y or 0)
	)
	lines[#lines + 1] = string.format(
		tr("任务最终局部位置：(%s, %s)", "Quest final local: (%s, %s)"),
		tostring(fin.x or "-"), tostring(fin.y or "-")
	)
	lines[#lines + 1] = string.format(
		tr("实际屏幕原点：(%s, %s)", "Screen origin: (%s, %s)"),
		tostring(screen.x or "-"), tostring(screen.y or "-")
	)
	local bounds = audit.content_bounds
	if bounds then
		lines[#lines + 1] = string.format(
			tr("内容范围：%d × %d", "Content size: %d × %d"),
			math.floor(bounds.width or 0), math.floor(bounds.height or 0)
		)
	else
		lines[#lines + 1] = tr("内容范围：（打开暂停任务页后采样）", "Content size: (open Pause Quest to sample)")
	end
	if audit.layout_warning then
		lines[#lines + 1] = string.format(
			tr("⚠ 任务内容超出建议区域 %d px", "⚠ Content overflows safe area by %d px"),
			audit.layout_warning.amount or 0
		)
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = tr("建议回填：", "Suggested preset:")
	lines[#lines + 1] = string.format(
		"%s.quest = Vector(%s, %s)",
		tostring(variant),
		tostring(fin.x or base.x or 0),
		tostring(fin.y or base.y or 0)
	)
	return table.concat(lines, "\n")
end

local function validation_text(results)
	if not results or #results == 0 then
		return tr("（尚无验证结果）", "(no validation yet)")
	end
	local lines = {tr("验证结果", "Validation")}
	for _, v in ipairs(results) do
		local key = v.key or v.name
		local mark = v.pass and "✓" or "✗"
		local label = d("validation", key)
		lines[#lines + 1] = string.format(
			"%s %s：%s",
			mark, label, v.pass and tr("通过", "Pass") or tr("未通过", "Fail")
		)
		if v.actual ~= nil then
			lines[#lines + 1] = tr("  实际值：", "  Actual: ") .. tostring(v.actual)
		elseif v.detail ~= nil then
			lines[#lines + 1] = tr("  详情：", "  Detail: ") .. tostring(v.detail)
		end
		if not v.pass and v.expected ~= nil then
			lines[#lines + 1] = tr("  期望值：", "  Expected: ") .. tostring(v.expected)
		end
	end
	return table.concat(lines, "\n")
end

local function transport_status_text(info)
	local tlog = info and info.transport_log
	if not tlog then
		return tr("（尚无传送日志）", "(no transport log)")
	end
	local lines = {tr("传送状态", "Transport")}
	local readiness = tlog.readiness or "-"
	local mark = "○"
	if readiness == "READY" then mark = "✓"
	elseif readiness == "NEARBY" then mark = "△"
	elseif readiness == "NOT_GENERATED" then mark = "✗"
	end
	lines[#lines + 1] = string.format("%s %s：%s", mark, tr("就绪度", "Readiness"), tostring(readiness))
	if tlog.level and tlog.level.result then
		lines[#lines + 1] = tr("楼层：", "Floor: ") .. tostring(tlog.level.result)
	end
	if tlog.room then
		local r = tlog.room
		lines[#lines + 1] = tr("房间：", "Room: ") .. tostring(r.result or r.selector or "-")
		if r.room_index ~= nil then
			lines[#lines + 1] = tr("  索引：", "  Index: ") .. tostring(r.room_index)
		end
		if r.dimension or r.dimension_id then
			lines[#lines + 1] = tr("  维度：", "  Dimension: ")
				.. tostring(r.dimension or r.dimension_id)
		end
		if r.anchor then
			lines[#lines + 1] = tr("  锚点：", "  Anchor: ") .. tostring(r.anchor)
		end
		if r.mirror_world ~= nil then
			lines[#lines + 1] = tr("  镜像世界：", "  Mirror world: ") .. tostring(r.mirror_world)
		end
	end
	if tlog.player and tlog.player.result then
		lines[#lines + 1] = tr("玩家资源：", "Player: ") .. tostring(tlog.player.result)
	end
	return table.concat(lines, "\n")
end

local function glaze_checklist_text(info)
	local threads = info and info.threads or {}
	local glaze = threads.glaze
	if type(glaze) ~= "table" or type(glaze.checklist) ~= "table" then
		return tr("（琉璃链路检查：需先点「准备并进入」）", "(Glaze checklist: Prepare & Enter first)")
	end
	local lines = {
		tr("镜界 / 琉璃素材", "Mirror / Glaze Material"),
		"────────────────",
	}
	for _, row in ipairs(glaze.checklist) do
		local mark = row.ok and "✓" or "○"
		local label = row.label and pick(row.label) or tostring(row.id)
		local line = mark .. " " .. label
		if row.detail ~= nil and tostring(row.detail) ~= "" then
			line = line .. "  (" .. tostring(row.detail) .. ")"
		end
		lines[#lines + 1] = line
	end
	return table.concat(lines, "\n")
end

local function advanced_diag_text()
	local info = runner.inspect()
	local panel_audit = info.quest_panel_audit or {}
	local pause = (panel_audit.pause) or (info.quest_pause) or {}
	local lines = {}
	lines[#lines + 1] = tr("高级诊断", "Advanced Diagnostics")
	lines[#lines + 1] = "────────────────"
	lines[#lines + 1] = tr("暂停渲染回调次数：", "Pause render callbacks: ")
		.. tostring(panel_audit.pause_render_count or 0)
	lines[#lines + 1] = tr("Q 键当前按下：", "Q physically down: ")
		.. d("bool", panel_audit.q_physically_down == true)
	lines[#lines + 1] = tr("Q 键触发次数：", "Q press count: ")
		.. tostring(panel_audit.q_press_count or 0)
	lines[#lines + 1] = tr("任务面板切换次数：", "Panel toggles: ")
		.. tostring(panel_audit.panel_toggles or 0)
	lines[#lines + 1] = tr("最近输入：", "Last input: ")
		.. tostring(panel_audit.last_input or "-")
	if panel_audit.last_open_gate then
		local gate_row = panel_audit.last_open_gate
		lines[#lines + 1] = tr("最近打开判定：", "Last open gate: ")
			.. (gate_row.ok and tr("通过", "Pass") or tr("拒绝", "Reject"))
		if not gate_row.ok and gate_row.reason then
			lines[#lines + 1] = tr("原因：", "Reason: ") .. tostring(gate_row.reason)
		end
	end
	if pause and pause.anchor then
		local a = pause.anchor
		lines[#lines + 1] = string.format(
			tr("Pause 锚点：(%.1f, %.1f)  scale (%.3f, %.3f)  %s",
				"Pause anchor: (%.1f, %.1f)  scale (%.3f, %.3f)  %s"),
			tonumber(a.origin_x) or 0,
			tonumber(a.origin_y) or 0,
			tonumber(a.scale_x) or 1,
			tonumber(a.scale_y) or 1,
			tostring(a.variant or pause.variant or "-")
		)
	else
		lines[#lines + 1] = tr("Pause 锚点：（尚未捕获，请打开暂停）", "Pause anchor: (none — open pause)")
	end
	lines[#lines + 1] = tr("字体倍率违规：", "Pixel UI violations: ")
		.. tostring(panel_audit.pixel_violations or 0)
	if panel_audit.layout then
		local L = panel_audit.layout
		lines[#lines + 1] = string.format(
			tr("Hint (%.1f, %.1f)  Quest (%.1f, %.1f)",
				"Hint (%.1f, %.1f)  Quest (%.1f, %.1f)"),
			tonumber(L.hint_x) or 0, tonumber(L.hint_y) or 0,
			tonumber(L.quest_x) or 0, tonumber(L.quest_y) or 0
		)
	end

	-- Compact story state dump
	local c = info.chapter1 or {}
	lines[#lines + 1] = ""
	lines[#lines + 1] = string.format(
		tr("第一章状态：%s  节点：%s  目标：%s",
			"Chapter1: %s  node: %s  objective: %s"),
		tostring(c.status), tostring(c.current_node), tostring(c.objective)
	)
	lines[#lines + 1] = tr("本局素材：", "Run tokens:")
	for _, tok in ipairs(info.tokens or {}) do
		lines[#lines + 1] = string.format("  %s %s", tok.owned and "[x]" or "[ ]", tok.id)
	end
	if info.validation and #info.validation > 0 then
		lines[#lines + 1] = ""
		lines[#lines + 1] = validation_text(info.validation)
	end
	local err = registry.audit.error or {}
	if #err > 0 then
		lines[#lines + 1] = ""
		lines[#lines + 1] = tr("定义审计错误：", "Definition audit errors:")
		for i = 1, math.min(6, #err) do
			lines[#lines + 1] = "  ! " .. err[i]
		end
	end
	if info.threads then
		for tid, data in pairs(info.threads) do
			lines[#lines + 1] = tr("线程 ", "Thread ") .. tid .. ":"
			if type(data) == "table" then
				for k, v in pairs(data) do
					lines[#lines + 1] = "  " .. tostring(k) .. "=" .. tostring(v)
				end
			end
		end
	end
	return table.concat(lines, "\n")
end

local function sync_offset_from_pause()
	local off = pause_ui.get_debug_offsets()
	ui.quest_ox = math.floor((off.panel and off.panel.X or 0) + 0.5)
	ui.quest_oy = math.floor((off.panel and off.panel.Y or 0) + 0.5)
	ui.hint_ox = math.floor((off.hint and off.hint.X or 0) + 0.5)
	ui.hint_oy = math.floor((off.hint and off.hint.Y or 0) + 0.5)
end

local function apply_offsets()
	if pause_ui.set_debug_panel_offset then
		pause_ui.set_debug_panel_offset(ui.quest_ox, ui.quest_oy)
	else
		pause_ui.set_debug_quest_offset(ui.quest_ox, ui.quest_oy)
	end
	pause_ui.set_debug_hint_offset(ui.hint_ox, ui.hint_oy)
end

function imgui.build(parent_id)
	if not ImGui or not parent_id then return end
	local prefix = parent_id .. "_StoryDev"
	sync_offset_from_pause()

	-- Shared session bar
	ImGui.AddElement(
		parent_id, "", ImGuiElement.SeparatorText or ImGuiElement.Separator,
		tr("支线调试 · DEV", "Story Dev Lab · DEV")
	)
	imgui_layout.add_wrapped_text(
		parent_id, prefix .. "_Banner",
		tr(
			"开发专用。覆盖层不写入永久剧情/解锁。沙盒按钮≠正式剧情路径；完整路径请用「流程验证」内的验证点。",
			"Dev only. Overlay does not write permanent story/unlocks. Sandbox ≠ canonical path; use Flow checkpoints."
		)
	)
	imgui_layout.add_wrapped_text(parent_id, prefix .. "_Session", "")
	ImGui.AddCallback(prefix .. "_Session", ImGuiCallback.Render, function()
		imgui_layout.update_text(prefix .. "_Session", session_header_text())
	end)
	ImGui.AddButton(parent_id, prefix .. "_Start", tr("开始测试会话", "Start Test Session"), function()
		session.start()
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_Restore", tr("恢复原始状态", "Restore Original State"), function()
		session.restore()
	end)

	local tabbar = prefix .. "_Tabs"
	ImGui.AddTabBar(parent_id, tabbar)
	local flow_tab = tabbar .. "_Flow"
	local threads_tab = tabbar .. "_Threads"
	local quest_tab = tabbar .. "_Quest"
	local audit_tab = tabbar .. "_Audit"
	ImGui.AddTab(tabbar, flow_tab, tr("流程验证", "Flow"))
	ImGui.AddTab(tabbar, threads_tab, tr("支线沙盒", "Thread Sandbox"))
	ImGui.AddTab(tabbar, quest_tab, tr("任务 / UI", "Quest / UI"))
	ImGui.AddTab(tabbar, audit_tab, tr("审计 / 诊断", "Audit"))

	local function act(fn)
		return function()
			local step = selected_step()
			if not step then return end
			if registry.step_has_errors(step.id) then
				session.last_message = tr("已阻止：步骤存在审计错误", "Blocked: step has audit errors")
				return
			end
			session.set_selected_step(step.id)
			fn(step.id)
		end
	end

	-- Flow
	ImGui.AddCombobox(flow_tab, prefix .. "_Chapter", tr("章节", "Chapter"), function(index)
		ui.chapter_index = index or 0
		ui.step_index = 0
	end, select(2, chapter_options()), ui.chapter_index)
	ImGui.AddCallback(prefix .. "_Chapter", ImGuiCallback.Render, function()
		local _, labels = chapter_options()
		ImGui.UpdateData(prefix .. "_Chapter", ImGuiData.ListValues, labels)
		ImGui.UpdateData(prefix .. "_Chapter", ImGuiData.Value, ui.chapter_index)
	end)

	ImGui.AddCombobox(
		flow_tab, prefix .. "_Prereq", tr("前置条件", "Prerequisites"),
		function(index)
			ui.prereq_index = index or 0
			local modes = {"auto", "minimal", "custom"}
			session.set_prereq_mode(modes[ui.prereq_index + 1] or "auto")
		end,
		{
			tr("自动规范", "Auto canonical"),
			tr("最小前置", "Minimal"),
			tr("自定义", "Custom"),
		},
		ui.prereq_index
	)

	ImGui.AddButton(flow_tab, prefix .. "_Enter", tr("准备并进入", "Prepare & Enter"), act(function(id)
		runner.prepare_and_enter(id)
	end))
	ImGui.AddElement(flow_tab, "", ImGuiElement.SameLine)
	ImGui.AddButton(flow_tab, prefix .. "_Validate", tr("验证当前点", "Validate Checkpoint"), act(function(id)
		local step = registry.get_step(id)
		session.last_validation = runner.validate(step)
		session.last_message = tr("已验证 ", "Validated ") .. id
	end))
	ImGui.AddElement(flow_tab, "", ImGuiElement.SameLine)
	ImGui.AddButton(flow_tab, prefix .. "_Prev", tr("上一个", "Prev"), function()
		runner.previous_step()
	end)
	ImGui.AddElement(flow_tab, "", ImGuiElement.SameLine)
	ImGui.AddButton(flow_tab, prefix .. "_Next", tr("下一个", "Next"), function()
		runner.next_step()
	end)

	imgui_layout.add_wrapped_text(flow_tab, prefix .. "_StepDiag", "")
	ImGui.AddCallback(prefix .. "_StepDiag", ImGuiCallback.Render, function()
		imgui_layout.update_text(prefix .. "_StepDiag", current_step_diag_text())
	end)
	imgui_layout.add_wrapped_text(flow_tab, prefix .. "_Validation", "")
	ImGui.AddCallback(prefix .. "_Validation", ImGuiCallback.Render, function()
		local info = runner.inspect()
		imgui_layout.update_text(prefix .. "_Validation", validation_text(info.validation))
	end)

	local story_reg = require("Qing_Remaster_scripts.story.story_registry")
	local route_hdr = imgui_layout.add_section(
		flow_tab, prefix .. "_Routes",
		tr("验证点路线（按剧情节点）", "Checkpoint routes (by story node)")
	)
	local function add_node_route(parent, node_id)
		local node = story_reg.get_node(node_id)
		if not node then return end
		local steps = registry.steps_for_story_node(node_id)
		if #steps == 0 then return end
		local nh = imgui_layout.add_section(
			parent, prefix .. "_Route_" .. node_id:gsub("%.", "_"),
			pick(node.title) or node_id
		)
		for i, step in ipairs(steps) do
			local bid = prefix .. "_REnter_" .. step.id:gsub("%.", "_")
			local label = string.format("%02d  %s", i, pick(step.label))
			ImGui.AddButton(nh, bid, label, function()
				local all = registry.list_steps(selected_chapter())
				for idx, s in ipairs(all) do
					if s.id == step.id then
						ui.step_index = idx - 1
						break
					end
				end
				session.set_selected_step(step.id)
				if registry.step_has_errors(step.id) then
					session.last_message = tr("已阻止：步骤存在审计错误", "Blocked: step has audit errors")
					return
				end
				runner.prepare_and_enter(step.id)
			end)
		end
	end
	add_node_route(route_hdr, "chapter1.commission")
	add_node_route(route_hdr, "chapter1.material_phase")
	for _, child in ipairs(story_reg.list_child_nodes("chapter1.material_phase")) do
		add_node_route(route_hdr, child.id)
	end
	for _, node in ipairs(story_reg.list_record_nodes("chapter1")) do
		if node.id ~= "chapter1.commission" and node.id ~= "chapter1.material_phase" then
			add_node_route(route_hdr, node.id)
		end
	end
	for _, node in ipairs(story_reg.list_record_nodes("prologue")) do
		add_node_route(route_hdr, node.id)
	end

	local prologue_quick = imgui_layout.add_section(
		flow_tab, prefix .. "_PrologueQuick",
		tr("序章快速流程测试", "Prologue quick flow tests")
	)
	imgui_layout.add_wrapped_text(
		prologue_quick, prefix .. "_PrologueQuickHint",
		tr(
			"Prepare 只写前置状态；Trigger 走正式 runtime（章节标题 / Home 到达 transition）。",
			"Prepare writes prerequisites only; Trigger calls formal runtime (opening / Home arrival)."
		)
	)
	ImGui.AddButton(prologue_quick, prefix .. "_TestOpening", tr("测试序章开场", "Test prologue opening"), function()
		session.set_selected_step("prologue.hunt.opening")
		runner.prepare("prologue.hunt.opening")
		runner.apply_transition("prologue.hunt.opening")
	end)
	ImGui.AddElement(prologue_quick, "", ImGuiElement.SameLine)
	ImGui.AddButton(prologue_quick, prefix .. "_TestHome", tr("测试抵达 Home", "Test Home arrival"), function()
		session.set_selected_step("prologue.home_arrival")
		runner.prepare("prologue.home_arrival")
		runner.apply_transition("prologue.home_arrival")
	end)

	local manual = imgui_layout.add_section(
		flow_tab, prefix .. "_Manual",
		tr("手动控制", "Manual Controls")
	)
	ImGui.AddButton(manual, prefix .. "_Prepare", tr("准备状态", "Prepare State"), act(function(id)
		runner.prepare(id)
	end))
	ImGui.AddElement(manual, "", ImGuiElement.SameLine)
	ImGui.AddButton(manual, prefix .. "_PlayScene", tr("播放场景", "Play Scene"), act(function(id)
		runner.play_scene(id)
	end))
	ImGui.AddElement(manual, "", ImGuiElement.SameLine)
	ImGui.AddButton(manual, prefix .. "_Transition", tr("应用剧情推进", "Apply Transition"), act(function(id)
		runner.apply_transition(id)
	end))
	ImGui.AddButton(manual, prefix .. "_Complete", tr("模拟完成", "Simulate Complete"), act(function(id)
		runner.complete_step(id)
	end))
	ImGui.AddElement(manual, "", ImGuiElement.SameLine)
	ImGui.AddButton(manual, prefix .. "_Reset", tr("重置步骤", "Reset Step"), act(function(id)
		runner.reset_step(id)
	end))
	ImGui.AddElement(manual, "", ImGuiElement.SameLine)
	ImGui.AddButton(manual, prefix .. "_Reseed", tr("重新生成本层", "Reseed Floor"), act(function(id)
		runner.reseed_and_retry(id)
	end))
	ImGui.AddElement(manual, "", ImGuiElement.SameLine)
	ImGui.AddButton(manual, prefix .. "_QuestRebuild", tr("刷新任务 HUD", "Rebuild Quest HUD"), function()
		runner.rebuild_quest()
	end)

	local adv_step = imgui_layout.add_section(
		flow_tab, prefix .. "_AdvStep",
		tr("高级：直接选择 Step ID", "Advanced: pick Step ID")
	)
	ImGui.AddCombobox(adv_step, prefix .. "_Step", tr("步骤", "Step"), function(index)
		ui.step_index = index or 0
		local step = selected_step()
		if step then session.set_selected_step(step.id) end
	end, {""}, ui.step_index)
	ImGui.AddCallback(prefix .. "_Step", ImGuiCallback.Render, function()
		local _, labels = step_options(selected_chapter())
		ImGui.UpdateData(prefix .. "_Step", ImGuiData.ListValues, labels)
		if ui.step_index >= #labels then ui.step_index = math.max(0, #labels - 1) end
		ImGui.UpdateData(prefix .. "_Step", ImGuiData.Value, ui.step_index)
	end)

	local tech = imgui_layout.add_section(
		flow_tab, prefix .. "_Tech",
		tr("技术详情", "Technical Details")
	)
	imgui_layout.add_wrapped_text(tech, prefix .. "_Transport", "")
	ImGui.AddCallback(prefix .. "_Transport", ImGuiCallback.Render, function()
		local info = runner.inspect()
		imgui_layout.update_text(prefix .. "_Transport", transport_status_text(info))
	end)
	imgui_layout.add_wrapped_text(tech, prefix .. "_GlazeCheck", "")
	ImGui.AddCallback(prefix .. "_GlazeCheck", ImGuiCallback.Render, function()
		local info = runner.inspect()
		imgui_layout.update_text(prefix .. "_GlazeCheck", glaze_checklist_text(info))
	end)

	-- Thread sandbox
	imgui_layout.add_wrapped_text(
		threads_tab, prefix .. "_ThreadNote",
		tr(
			"此页直接操作运行态，仅用于局部机制验证。完整剧情路径请使用「流程验证」。",
			"Direct runtime tools for local mechanism checks. Canonical path: use Flow."
		)
	)
	local bank_hdr = imgui_layout.add_section(
		threads_tab, prefix .. "_Bank",
		tr("银行 / Bum Emperor", "Bank / Bum Emperor")
	)
	bank_debug.build(bank_hdr)
	local stone_hdr = imgui_layout.add_section(
		threads_tab, prefix .. "_Stone",
		tr("棋盘 / Floraine", "Chess / Floraine")
	)
	stone_debug.build(stone_hdr)
	imgui_layout.add_section(
		threads_tab, prefix .. "_GlazeSoon",
		tr("琉璃 / Mirror（沙盒待补）", "Glaze / Mirror (sandbox TBD)")
	)
	imgui_layout.add_section(
		threads_tab, prefix .. "_WindSoon",
		tr("风暴 / Zennith（沙盒待补）", "Wind / Zennith (sandbox TBD)")
	)

	-- Quest / UI
	local quest_state = imgui_layout.add_section(
		quest_tab, prefix .. "_QuestState",
		tr("Quest 状态", "Quest State")
	)
	imgui_layout.add_wrapped_text(quest_state, prefix .. "_QuestSys", "")
	ImGui.AddCallback(prefix .. "_QuestSys", ImGuiCallback.Render, function()
		imgui_layout.update_text(prefix .. "_QuestSys", quest_system_text())
	end)
	ImGui.AddButton(quest_state, prefix .. "_QuestPrint", tr("打印任务视图", "Print Quest View"), function()
		local info = runner.inspect()
		local main = info.quest_main
		session.last_message = string.format(
			"%s | %s | %s",
			tostring(main and main.id),
			tostring(main and main.title),
			d("resolve_source", main and main.resolve_source)
		)
	end)
	ImGui.AddElement(quest_state, "", ImGuiElement.SameLine)
	ImGui.AddButton(quest_state, prefix .. "_QuestAudit", tr("任务覆盖审计", "Quest Coverage Audit"), function()
		local cov = quest_registry.audit_coverage()
		if cov.ok then
			session.last_message = tr("任务覆盖：全部已映射", "Quest coverage: all mapped")
		else
			session.last_message = tr("任务覆盖缺失: ", "Quest coverage missing: ")
				.. table.concat(cov.missing or {}, ", ")
		end
	end)

	local layout_hdr = imgui_layout.add_section(
		quest_tab, prefix .. "_Layout",
		tr("布局调节", "Layout Tuning")
	)
	imgui_layout.add_wrapped_text(layout_hdr, prefix .. "_LayoutInfo", "")
	ImGui.AddCallback(prefix .. "_LayoutInfo", ImGuiCallback.Render, function()
		imgui_layout.update_text(prefix .. "_LayoutInfo", layout_debug_text())
	end)
	local add_slider = ImGui.AddSliderInteger or ImGui.AddSliderInt
	if add_slider then
		add_slider(layout_hdr, prefix .. "_QOX", tr("任务 X 偏移", "Quest X offset"), function(v)
			ui.quest_ox = math.floor((v or 0) + 0.5)
			apply_offsets()
		end, ui.quest_ox, -120, 120)
		ImGui.AddCallback(prefix .. "_QOX", ImGuiCallback.Render, function()
			ImGui.UpdateData(prefix .. "_QOX", ImGuiData.Value, ui.quest_ox)
		end)
		add_slider(layout_hdr, prefix .. "_QOY", tr("任务 Y 偏移", "Quest Y offset"), function(v)
			ui.quest_oy = math.floor((v or 0) + 0.5)
			apply_offsets()
		end, ui.quest_oy, -100, 100)
		ImGui.AddCallback(prefix .. "_QOY", ImGuiCallback.Render, function()
			ImGui.UpdateData(prefix .. "_QOY", ImGuiData.Value, ui.quest_oy)
		end)
		add_slider(layout_hdr, prefix .. "_HOX", tr("提示 X 偏移", "Hint X offset"), function(v)
			ui.hint_ox = math.floor((v or 0) + 0.5)
			apply_offsets()
		end, ui.hint_ox, -120, 120)
		ImGui.AddCallback(prefix .. "_HOX", ImGuiCallback.Render, function()
			ImGui.UpdateData(prefix .. "_HOX", ImGuiData.Value, ui.hint_ox)
		end)
		add_slider(layout_hdr, prefix .. "_HOY", tr("提示 Y 偏移", "Hint Y offset"), function(v)
			ui.hint_oy = math.floor((v or 0) + 0.5)
			apply_offsets()
		end, ui.hint_oy, -100, 100)
		ImGui.AddCallback(prefix .. "_HOY", ImGuiCallback.Render, function()
			ImGui.UpdateData(prefix .. "_HOY", ImGuiData.Value, ui.hint_oy)
		end)
	end
	ImGui.AddButton(layout_hdr, prefix .. "_OffsetZero", tr("偏移归零", "Reset Offsets"), function()
		pause_ui.reset_debug_offsets()
		sync_offset_from_pause()
		session.last_message = tr("布局偏移已归零", "Layout offsets reset")
	end)
	ImGui.AddElement(layout_hdr, "", ImGuiElement.SameLine)
	ImGui.AddButton(layout_hdr, prefix .. "_Anchors", tr("显示布局辅助线", "Show Layout Guides"), function()
		pause_ui.set_debug_anchors(not pause_ui.get_debug_anchors())
		session.last_message = pause_ui.get_debug_anchors()
			and tr("布局辅助线：开", "Layout guides: ON")
			or tr("布局辅助线：关", "Layout guides: OFF")
	end)

	-- Audit
	local flow_hdr = imgui_layout.add_section(
		audit_tab, prefix .. "_FlowHdr",
		tr("剧情流程覆盖", "Story Flow Coverage")
	)
	imgui_layout.add_wrapped_text(flow_hdr, prefix .. "_FlowOverview", "")
	ImGui.AddCallback(prefix .. "_FlowOverview", ImGuiCallback.Render, function()
		imgui_layout.update_text(prefix .. "_FlowOverview", flow_overview_text())
	end)

	local adv_hdr = imgui_layout.add_section(
		audit_tab, prefix .. "_AdvHdr",
		tr("高级诊断", "Advanced Diagnostics")
	)
	ImGui.AddCheckbox(adv_hdr, prefix .. "_ShowAdv", tr("显示 Pause/UI 探针", "Show Pause/UI probes"), function(v)
		ui.show_advanced = v == true
	end, false)
	imgui_layout.add_wrapped_text(adv_hdr, prefix .. "_AdvBody", "")
	ImGui.AddCallback(prefix .. "_AdvBody", ImGuiCallback.Render, function()
		if ui.show_advanced then
			imgui_layout.update_text(prefix .. "_AdvBody", advanced_diag_text())
		else
			imgui_layout.update_text(
				prefix .. "_AdvBody",
				tr("（勾选上方开关后显示 Pause/输入/像素探针）", "(enable checkbox to show Pause/input/pixel probes)")
			)
		end
	end)
	ImGui.AddButton(adv_hdr, prefix .. "_PixelTest", tr("像素字号测试", "Pixel Font Scale Test"), function()
		local pixel_ui = require("Qing_Remaster_scripts.auxiliary.pixel_ui")
		pixel_ui.set_debug_scale_test(not pixel_ui.get_debug_scale_test())
		session.last_message = pixel_ui.get_debug_scale_test()
			and tr("像素字号测试：开（局内 HUD 叠加）", "Pixel scale test: ON")
			or tr("像素字号测试：关", "Pixel scale test: OFF")
	end)
end

return imgui
