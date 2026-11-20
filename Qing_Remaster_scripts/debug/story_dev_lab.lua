-- Story Dev Lab (DEV only): task-oriented thread testing.
-- Primary: go to floor / start test / checkpoints / per-thread tools.
-- No "高级沙盒" mixed dump — each thread mounts its own named tools.

local imgui_layout = require("Qing_Remaster_scripts.debug.imgui_debug_layout")
local runner = require("Qing_Remaster_scripts.story_test.story_test_runner")
local session = require("Qing_Remaster_scripts.story_test.story_test_session")
local registry = require("Qing_Remaster_scripts.story_test.story_test_registry")
local transport = require("Qing_Remaster_scripts.story_test.story_test_transport")

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
	local preset = registry.get_level_preset(preset_id)
	if preset and preset.label then return pick(preset.label) end
	return tostring(preset_id or "-")
end

local function format_action_result(result, fallback)
	if type(result) == "table" then
		local status = result.status
			or (result.arrived and "ready")
			or (result.ok == false and "failed")
			or (result.code == "queued" and "queued")
			or "ok"
		local msg = result.message or result.code or fallback
		return string.format("[%s] %s", tostring(status), tostring(msg))
	end
	if result == false then
		return tr("[failed] ", "[failed] ") .. tostring(fallback or "failed")
	end
	return tostring(fallback or result or "ok")
end

local function go_to_floor(preset_id)
	runner.ensure_session()
	local preset = registry.get_level_preset(preset_id)
	if not preset or not preset.command then
		session.last_message = tr("此支线无固定测试楼层（使用当前层）", "No fixed floor (use current)")
		return false
	end
	local ok, msg = transport.goto_level_preset(preset_id, { reseed = true })
	session.last_message = ok
		and (tr("已前往 ", "Went to ") .. floor_label(preset_id) .. tr("（仅楼层，未进目标房）", " (floor only, not target room)"))
		or (tr("楼层切换失败：", "Floor travel failed: ") .. tostring(msg))
	return ok
end

local function start_test(desc)
	if not desc then return false end
	runner.ensure_session()
	-- Stone: reliable entry that reuses floor/layout and never reseeds when already correct.
	if desc.id == "chapter1.stone" or desc.use_stone_entry then
		local ok_stone, stone = pcall(require, "Qing_Remaster_scripts.threads.stone.stone_debug")
		if ok_stone and stone and stone.start_full_test then
			local result = stone.start_full_test({
				preset_id = desc.floor_preset or "mines_ashpit",
				reuse_floor = true,
				reuse_layout = true,
				reset_encounter = true,
				target = "origin",
			})
			session.last_message = format_action_result(
				result,
				tr("已排队棋盘测试（未到达）", "Chess test QUEUED (not arrived)")
			)
			return result and result.ok ~= false
		end
	end
	if not desc.start_step then return false end
	local ok, msg = runner.prepare_and_enter(desc.start_step, {
		reuse_current_floor = true,
		reuse_layout = true,
	})
	session.last_message = msg or (ok and tr("测试已开始", "Test started") or tr("开始失败", "Start failed"))
	return ok
end

local function run_checkpoint(cp)
	if not cp then return end
	runner.ensure_session()
	if type(cp.action) == "function" then
		local result = cp.action()
		session.last_message = format_action_result(result, pick(cp.label))
		if Isaac and Isaac.ConsoleOutput then
			Isaac.ConsoleOutput("[StoryDev] " .. tostring(session.last_message) .. "\n")
		end
		return
	end
	if cp.step then
		local ok, msg = runner.prepare_and_enter(cp.step, {
			reuse_current_floor = true,
			reuse_layout = true,
		})
		session.last_message = msg or pick(cp.label)
		if Isaac and Isaac.ConsoleOutput then
			Isaac.ConsoleOutput("[StoryDev] " .. tostring(session.last_message) .. "\n")
		end
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
	-- Live Stone prepare status when available.
	local ok_s, stone = pcall(require, "Qing_Remaster_scripts.threads.stone.stone_debug")
	if ok_s and stone and stone.prepare_status then
		if stone.has_prepare_job and stone.has_prepare_job() then
			stone.tick_prepare({ from_render = true })
		end
		local s = stone.prepare_status()
		if s and s.status and s.status ~= "idle" then
			lines[#lines + 1] = string.format(
				"Stone prepare: %s · %s · %s",
				tostring(s.status), tostring(s.target), tostring(s.message)
			)
			if s.error then
				lines[#lines + 1] = "Stone error: " .. tostring(s.error)
			end
			if s.paused_hint then
				lines[#lines + 1] = tr(
					"提示：游戏暂停时楼层切换可能未完成，请取消暂停。",
					"Hint: unpause — stage travel may not finish while paused."
				)
			end
		end
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
	local ok_lab, phase_lab = pcall(require, "Qing_Remaster_scripts.story.phase_lab.test")
	if ok_lab and phase_lab and phase_lab.get_test_descriptor then
		list[#list + 1] = phase_lab.get_test_descriptor()
	end
	local ok_wind, wind_dbg = pcall(require, "Qing_Remaster_scripts.threads.wind.wind_debug")
	if ok_wind and wind_dbg and wind_dbg.get_test_descriptor then
		list[#list + 1] = wind_dbg.get_test_descriptor()
	else
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
	end
	return list
end

local function build_thread_panel(parent_id, prefix, desc)
	local title = pick(desc.title)
	local hdr = imgui_layout.add_section(parent_id, prefix .. "_T_" .. desc.id:gsub("%.", "_"), title)

	imgui_layout.add_wrapped_text(hdr, hdr .. "_Env", "")
	ImGui.AddCallback(hdr .. "_Env", ImGuiCallback.Render, function()
		local lines = {}
		if desc.floor_preset then
			lines[#lines + 1] = tr("目标楼层：", "Target floor: ") .. floor_label(desc.floor_preset)
		elseif desc.go_to_test_location then
			lines[#lines + 1] = tr("目标：银行总部入口（到达结果在贪婪银行测试台核对）", "Target: bank HQ entrance")
		end
		if desc.notes then lines[#lines + 1] = tostring(desc.notes) end
		imgui_layout.update_text(hdr .. "_Env", table.concat(lines, "\n"))
	end)

	if not desc.hide_flow_validation then
		ImGui.AddElement(
			hdr, "", ImGuiElement.SeparatorText or ImGuiElement.Separator,
			tr("流程验证", "Flow validation")
		)
		ImGui.AddButton(hdr, hdr .. "_Floor", tr("前往测试楼层", "Go to test floor"), function()
			if type(desc.go_to_test_location) == "function" then
				local ok, msg = desc.go_to_test_location()
				session.last_message = msg or (ok and tr("已提交银行传送", "Bank travel submitted") or tr("银行传送失败", "Bank travel failed"))
				return
			end
			if not desc.floor_preset then
				session.last_message = tr("此支线没有可前往的测试位置", "This thread has no test location")
				return
			end
			go_to_floor(desc.floor_preset)
		end)
		ImGui.AddButton(hdr, hdr .. "_Start", tr("开始支线测试", "Start side-event test"), function()
			start_test(desc)
		end)
		ImGui.AddElement(hdr, "", ImGuiElement.SameLine)
		ImGui.AddButton(hdr, hdr .. "_Restore", tr("结束测试并恢复", "End test & restore"), function()
			local ok_s, stone = pcall(require, "Qing_Remaster_scripts.threads.stone.stone_debug")
			if ok_s and stone and stone.cancel_prepare then
				stone.cancel_prepare("end_test")
			end
			session.restore()
			session.last_message = tr("已恢复原始状态", "Original state restored")
		end)

		for i, cp in ipairs(desc.checkpoints or {}) do
			local cid = hdr .. "_CP" .. i
			ImGui.AddButton(hdr, cid, pick(cp.label), function()
				run_checkpoint(cp)
			end)
		end
	end

	-- Per-thread tools with explicit business names (never a generic sandbox dump).
	local tools_fn = desc.build_thread_tools or desc.build_tools
	if type(tools_fn) == "function" then
		tools_fn(hdr)
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
			"按支线测试：流程验证点可从任意合法楼层出发。Stone 跨楼层会先切矿层再进目标房；只有 prepare=ready 才算到达。Floraine 战斗请用 Boss Test。",
			"Per-thread testing: checkpoints work from any valid floor. Stone cross-floor goes Mines first, then the room; only prepare=ready means arrived. Floraine combat: Boss Test."
		)
	)
	imgui_layout.add_wrapped_text(parent_id, prefix .. "_Session", "")
	ImGui.AddCallback(prefix .. "_Session", ImGuiCallback.Render, function()
		imgui_layout.update_text(prefix .. "_Session", session_text())
	end)

	local sess = imgui_layout.add_section(
		parent_id, prefix .. "_SessAdv",
		tr("测试会话", "Test session")
	)
	ImGui.AddButton(sess, prefix .. "_StartSess", tr("开始测试会话", "Start test session"), function()
		session.start()
	end)
	ImGui.AddElement(sess, "", ImGuiElement.SameLine)
	ImGui.AddButton(sess, prefix .. "_RestoreSess", tr("恢复原始状态", "Restore original"), function()
		local ok_s, stone = pcall(require, "Qing_Remaster_scripts.threads.stone.stone_debug")
		if ok_s and stone and stone.cancel_prepare then
			stone.cancel_prepare("session_restore")
		end
		session.restore()
	end)

	for _, desc in ipairs(load_descriptors()) do
		build_thread_panel(parent_id, prefix, desc)
	end
end

return lab
