-- Story Dev Lab (DEV only): task-oriented thread testing.
-- Primary: go to floor / start test / checkpoints. Sandbox sinks to Advanced.

local imgui_layout = require("Qing_Remaster_scripts.debug.imgui_debug_layout")
local runner = require("Qing_Remaster_scripts.story_test.story_test_runner")
local session = require("Qing_Remaster_scripts.story_test.story_test_session")
local test_defs = require("Qing_Remaster_scripts.story_test.story_test_defs")

local lab = {}

local function tr(zh, en)
	return (Options and Options.Language == "en") and en or zh
end

local function pick(tbl)
	if type(tbl) ~= "table" then return tostring(tbl or "-") end
	if Options and Options.Language == "en" and tbl.en then return tbl.en end
	return tbl.zh or tbl.en or "-"
end

local function floor_label(preset_id)
	local preset = test_defs.level_presets and test_defs.level_presets[preset_id]
	if preset and preset.label then return pick(preset.label) end
	return tostring(preset_id or "-")
end

local function go_to_floor(preset_id)
	runner.ensure_session()
	local preset = test_defs.level_presets and test_defs.level_presets[preset_id]
	if not preset or not preset.command then
		session.last_message = tr("此支线无固定测试楼层（使用当前层）", "No fixed floor (use current)")
		return false
	end
	Isaac.ExecuteCommand("stage " .. tostring(preset.command))
	session.last_message = tr("已前往 ", "Went to ") .. floor_label(preset_id)
	return true
end

local function start_test(desc)
	if not desc or not desc.start_step then return false end
	runner.ensure_session()
	local ok, msg = runner.prepare_and_enter(desc.start_step)
	session.last_message = msg or (ok and tr("测试已开始", "Test started") or tr("开始失败", "Start failed"))
	return ok
end

local function run_checkpoint(cp)
	if not cp then return end
	runner.ensure_session()
	if type(cp.action) == "function" then
		cp.action()
		session.last_message = pick(cp.label)
		return
	end
	if cp.step then
		local ok, msg = runner.prepare_and_enter(cp.step)
		session.last_message = msg or pick(cp.label)
		return ok
	end
end

local function session_text()
	local active = session.is_active and session.is_active()
	local lines = {
		tr("测试会话：", "Test session: ")
			.. (active and tr("已开启", "Active") or tr("未开启（开始测试时会自动开启）", "Inactive (auto-starts with Start Test)")),
	}
	if session.last_message then
		lines[#lines + 1] = tr("消息：", "Msg: ") .. tostring(session.last_message)
	end
	return table.concat(lines, "\n")
end

local function load_descriptors()
	local list = {}
	local ok_bank, bank = pcall(require, "Qing_Remaster_scripts.threads.bank.bank_debug")
	if ok_bank and bank and bank.get_test_descriptor then
		list[#list + 1] = bank.get_test_descriptor()
	end
	list[#list + 1] = {
		id = "chapter1.glaze",
		title = {zh = "琉璃 / Mirror", en = "Glaze / Mirror"},
		floor_preset = "downpour_dross_2",
		start_step = "chapter1.glaze.floor_entry",
		checkpoints = {
			{step = "chapter1.glaze.white_fire_room", label = {zh = "白火房", en = "White Fire Room"}},
			{step = "chapter1.glaze.mirror_white_fire", label = {zh = "镜像白火", en = "Mirror White Fire"}},
			{step = "chapter1.glaze.bomb_interact", label = {zh = "琉璃火交互前", en = "Before Glaze Interact"}},
			{step = "chapter1.glaze.mirror_reward", label = {zh = "返回奖励后", en = "After Return Reward"}},
		},
	}
	local ok_stone, stone = pcall(require, "Qing_Remaster_scripts.threads.stone.stone_debug")
	if ok_stone and stone and stone.get_test_descriptor then
		list[#list + 1] = stone.get_test_descriptor()
	end
	local ok_lab, lab = pcall(require, "Qing_Remaster_scripts.story.phase_lab.test")
	if ok_lab and lab and lab.get_test_descriptor then
		list[#list + 1] = lab.get_test_descriptor()
	end
	list[#list + 1] = {
		id = "chapter1.wind",
		title = {zh = "风暴 / Zennith", en = "Wind / Zennith"},
		floor_preset = "mausoleum_gehenna_1",
		start_step = "chapter1.wind.before",
		checkpoints = {
			{step = "chapter1.wind.discover", label = {zh = "风暴初现", en = "Storm Appears"}},
			{step = "chapter1.wind.complete", label = {zh = "风暴完成后", en = "After Storm Complete"}},
		},
		notes = tr("完整验证点将随 Zennith 实装补齐。", "Full checkpoints TBD with Zennith implementation."),
	}
	return list
end

local function build_thread_panel(parent_id, prefix, desc)
	local title = pick(desc.title)
	local hdr = imgui_layout.add_section(parent_id, prefix .. "_T_" .. desc.id:gsub("%.", "_"), title)

	imgui_layout.add_wrapped_text(hdr, hdr .. "_Env", "")
	ImGui.AddCallback(hdr .. "_Env", ImGuiCallback.Render, function()
		local lines = {
			tr("目标楼层：", "Target floor: ") .. floor_label(desc.floor_preset),
		}
		if desc.notes then lines[#lines + 1] = tostring(desc.notes) end
		imgui_layout.update_text(hdr .. "_Env", table.concat(lines, "\n"))
	end)

	ImGui.AddElement(
		hdr, "", ImGuiElement.SeparatorText or ImGuiElement.Separator,
		tr("测试入口", "Test entry")
	)
	ImGui.AddButton(hdr, hdr .. "_Floor", tr("前往测试楼层", "Go to test floor"), function()
		go_to_floor(desc.floor_preset)
	end)
	ImGui.AddButton(hdr, hdr .. "_Start", tr("开始支线测试", "Start side-event test"), function()
		start_test(desc)
	end)
	ImGui.AddElement(hdr, "", ImGuiElement.SameLine)
	ImGui.AddButton(hdr, hdr .. "_Restore", tr("结束测试并恢复", "End test & restore"), function()
		session.restore()
		session.last_message = tr("已恢复原始状态", "Original state restored")
	end)

	ImGui.AddElement(
		hdr, "", ImGuiElement.SeparatorText or ImGuiElement.Separator,
		tr("快速验证点", "Checkpoints")
	)
	for i, cp in ipairs(desc.checkpoints or {}) do
		local cid = hdr .. "_CP" .. i
		ImGui.AddButton(hdr, cid, pick(cp.label), function()
			run_checkpoint(cp)
		end)
	end

	if type(desc.build_advanced) == "function" then
		local adv = imgui_layout.add_section(hdr, hdr .. "_Adv", tr("高级沙盒", "Advanced sandbox"))
		imgui_layout.add_wrapped_text(
			adv, hdr .. "_AdvNote",
			tr(
				"底层运行态工具。不等于正式剧情路径。",
				"Low-level runtime tools. Not the canonical story path."
			)
		)
		desc.build_advanced(adv)
	end
end

function lab.build(parent_id)
	if not ImGui or not parent_id then return end
	local prefix = parent_id .. "_StoryDevLab"

	ImGui.AddElement(
		parent_id, "", ImGuiElement.SeparatorText or ImGuiElement.Separator,
		tr("支线调试 · DEV", "Story Dev · DEV")
	)
	imgui_layout.add_wrapped_text(
		parent_id, prefix .. "_Banner",
		tr(
			"按支线测试：先前往楼层，再开始测试。沙盒工具在各支线的「高级沙盒」里。",
			"Per-thread testing: go to floor, then Start Test. Sandbox tools live under Advanced."
		)
	)
	imgui_layout.add_wrapped_text(parent_id, prefix .. "_Session", "")
	ImGui.AddCallback(prefix .. "_Session", ImGuiCallback.Render, function()
		imgui_layout.update_text(prefix .. "_Session", session_text())
	end)

	local adv_session = imgui_layout.add_section(
		parent_id, prefix .. "_SessAdv",
		tr("高级：测试会话", "Advanced: test session")
	)
	ImGui.AddButton(adv_session, prefix .. "_StartSess", tr("开始测试会话", "Start test session"), function()
		session.start()
	end)
	ImGui.AddElement(adv_session, "", ImGuiElement.SameLine)
	ImGui.AddButton(adv_session, prefix .. "_RestoreSess", tr("恢复原始状态", "Restore original"), function()
		session.restore()
	end)

	for _, desc in ipairs(load_descriptors()) do
		build_thread_panel(parent_id, prefix, desc)
	end
	-- Quest UI tuning: Debug → Visual → Quest UI (quest_ui_debug.lua).
end

return lab
