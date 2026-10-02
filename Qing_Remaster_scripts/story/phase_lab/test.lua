-- Phase Lab Story Dev / Test Lab panel.

local imgui_layout = require("Qing_Remaster_scripts.debug.imgui_debug_layout")
local controller = require("Qing_Remaster_scripts.story.phase_lab.controller")
local state = require("Qing_Remaster_scripts.story.phase_lab.state")
local puzzle = require("Qing_Remaster_scripts.story.phase_lab.puzzle")
local materials = require("Qing_Remaster_scripts.story.phase_lab.materials")
local anchor = require("Qing_Remaster_scripts.story.phase_lab.anchor")
local defs = require("Qing_Remaster_scripts.story.phase_lab.defs")

local test = {}

local function tr(zh, en)
	return (Options and Options.Language == "en") and en or zh
end

local function status_text()
	local snap = state.debug_snapshot()
	local p = snap.permanent
	local r = snap.run
	local n, max = materials.count_summary()
	local lines = {
		tr("炼金实验室 / Phase Lab", "Phase Lab"),
		"────────────────",
		tr("永久：发现=", "Perm discovered=") .. tostring(p.discovered)
			.. tr(" 谜题=", " puzzle=") .. tostring(p.puzzle_solved)
			.. tr(" 锚=", " anchor=") .. tostring(p.anchor_activated_once),
		tr("本局：Replay=", "Run: Replay=") .. tostring(r.replay_mode)
			.. tr(" 已解=", " solved=") .. tostring(r.puzzle_solved)
			.. tr(" 锚=", " anchor=") .. tostring(r.anchor),
		tr("材料投入：", "Inserted: ") .. tostring(n) .. " / " .. tostring(max),
		"A=" .. tostring(r.states.A)
			.. " B=" .. tostring(r.states.B)
			.. " C=" .. tostring(r.states.C)
			.. " D=" .. tostring(r.states.D)
			.. " E=" .. tostring(r.states.E)
			.. " F=" .. tostring(r.states.F),
	}
	return table.concat(lines, "\n")
end

local function after_mutate()
	if controller.is_active() then
		controller.rebuild_entities()
		anchor.refresh_ready()
	end
end

function test.get_test_descriptor()
	return {
		id = "chapter1.phase_anchor",
		title = {zh = "炼金实验室 / 相位锚", en = "Phase Lab / Anchor"},
		floor_preset = "mausoleum_gehenna_2",
		start_step = nil,
		checkpoints = {
			{
				label = {zh = "传送到实验室（覆盖当前房）", en = "Teleport to Lab (overlay)"},
				action = function()
					controller.teleport_to_lab()
				end,
			},
			{
				label = {zh = "初始谜题", en = "Fresh puzzle"},
				action = function()
					state.set_permanent_flags({puzzle_solved = false})
					puzzle.load_initial()
					after_mutate()
				end,
			},
			{
				label = {zh = "已完成布局", en = "Solved layout"},
				action = function()
					puzzle.force_complete({permanent = true})
					after_mutate()
				end,
			},
			{
				label = {zh = "Reset / Replay", en = "Reset / Replay"},
				action = function()
					puzzle.reset_to_initial()
					after_mutate()
				end,
			},
		},
		notes = tr(
			"实验室可在任意房间覆盖调试。正式入口：Mausoleum/Gehenna II Boss 后。",
			"Lab can overlay any room for debug. Formal entry: post Mausoleum/Gehenna II boss."
		),
		build_advanced = function(parent_id)
			test.build_advanced(parent_id)
		end,
	}
end

function test.build_advanced(parent_id)
	if not ImGui or not parent_id then return end
	local prefix = parent_id .. "_PhaseLab"

	ImGui.AddElement(
		parent_id, "", ImGuiElement.SeparatorText or ImGuiElement.Separator,
		tr("炼金实验室", "Phase Lab")
	)
	imgui_layout.add_wrapped_text(parent_id, prefix .. "_Status", "")
	ImGui.AddCallback(prefix .. "_Status", ImGuiCallback.Render, function()
		imgui_layout.update_text(prefix .. "_Status", status_text())
	end)

	ImGui.AddButton(parent_id, prefix .. "_TP", tr("传送到实验室", "Teleport to Lab"), function()
		controller.teleport_to_lab()
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_Overlay", tr("仅覆盖当前房", "Overlay current"), function()
		controller.teleport_overlay()
	end)

	local perm = imgui_layout.add_section(parent_id, prefix .. "_Perm", tr("永久状态", "Permanent"))
	ImGui.AddButton(perm, prefix .. "_Undisc", tr("未发现", "Undiscovered"), function()
		state.set_permanent_flags({discovered = false, puzzle_solved = false, anchor_activated_once = false})
	end)
	ImGui.AddElement(perm, "", ImGuiElement.SameLine)
	ImGui.AddButton(perm, prefix .. "_Disc", tr("已发现", "Discovered"), function()
		state.set_permanent_flags({discovered = true})
	end)
	ImGui.AddButton(perm, prefix .. "_PUnsolved", tr("谜题未完成", "Puzzle unsolved"), function()
		state.set_permanent_flags({puzzle_solved = false})
		puzzle.load_initial()
		after_mutate()
	end)
	ImGui.AddElement(perm, "", ImGuiElement.SameLine)
	ImGui.AddButton(perm, prefix .. "_PSolved", tr("谜题已完成", "Puzzle solved"), function()
		puzzle.force_complete({permanent = true})
		after_mutate()
	end)

	local pz = imgui_layout.add_section(parent_id, prefix .. "_Puzzle", tr("谜题", "Puzzle"))
	ImGui.AddButton(pz, prefix .. "_Init", tr("初始状态", "Initial"), function()
		puzzle.load_initial()
		after_mutate()
	end)
	ImGui.AddElement(pz, "", ImGuiElement.SameLine)
	ImGui.AddButton(pz, prefix .. "_Sol", tr("正确状态", "Solution"), function()
		puzzle.load_solved()
		after_mutate()
	end)
	ImGui.AddButton(pz, prefix .. "_Reset", tr("重置", "Reset"), function()
		puzzle.reset_to_initial()
		after_mutate()
	end)
	ImGui.AddElement(pz, "", ImGuiElement.SameLine)
	ImGui.AddButton(pz, prefix .. "_Replay", tr("进入 Replay", "Enter Replay"), function()
		state.set_permanent_flags({puzzle_solved = true})
		puzzle.reset_to_initial({force_replay = true})
		after_mutate()
	end)
	ImGui.AddButton(pz, prefix .. "_Force", tr("强制完成", "Force complete"), function()
		puzzle.force_complete({permanent = true})
		after_mutate()
	end)
	ImGui.AddElement(pz, "", ImGuiElement.SameLine)
	ImGui.AddButton(pz, prefix .. "_Dbg", tr("切换拼图辅助线", "Toggle puzzle overlay"), function()
		puzzle.set_debug_overlay(not puzzle.get_debug_overlay())
	end)

	local blocks = imgui_layout.add_section(parent_id, prefix .. "_Blocks", tr("单块控制", "Per-block"))
	for _, id in ipairs(defs.BLOCK_IDS) do
		ImGui.AddButton(blocks, prefix .. "_" .. id .. "M", id .. " -", function()
			local st = puzzle.get_states()
			local b = defs.BLOCKS[id]
			local cur = tonumber(st[id]) or 0
			local count = math.max(1, b.count or 1)
			st[id] = (cur - 1 + count) % count
			puzzle.apply_states(st)
			after_mutate()
		end)
		ImGui.AddElement(blocks, "", ImGuiElement.SameLine)
		ImGui.AddButton(blocks, prefix .. "_" .. id .. "Z", id .. " 0", function()
			local st = puzzle.get_states()
			st[id] = 0
			puzzle.apply_states(st)
			after_mutate()
		end)
		ImGui.AddElement(blocks, "", ImGuiElement.SameLine)
		ImGui.AddButton(blocks, prefix .. "_" .. id .. "P", id .. " +", function()
			local center = controller.room_center()
			puzzle.try_advance(id, center, {force = true})
			after_mutate()
		end)
		if id ~= "F" then
			ImGui.AddElement(blocks, "", ImGuiElement.SameLine)
		end
	end

	local mat = imgui_layout.add_section(parent_id, prefix .. "_Mat", tr("材料", "Materials"))
	ImGui.AddButton(mat, prefix .. "_M0", "0 / 5", function()
		materials.clear_all()
		after_mutate()
	end)
	ImGui.AddElement(mat, "", ImGuiElement.SameLine)
	ImGui.AddButton(mat, prefix .. "_M1", "1 / 5", function()
		materials.debug_grant_count(1)
		materials.clear_all()
		after_mutate()
	end)
	ImGui.AddElement(mat, "", ImGuiElement.SameLine)
	ImGui.AddButton(mat, prefix .. "_M4", "4 / 5", function()
		materials.debug_grant_count(4)
		materials.clear_all()
		for _, k in ipairs({"property_1", "property_2", "property_3", "property_4"}) do
			materials.insert(k)
		end
		after_mutate()
	end)
	ImGui.AddElement(mat, "", ImGuiElement.SameLine)
	ImGui.AddButton(mat, prefix .. "_M5", "5 / 5", function()
		materials.debug_grant_all()
		materials.set_all(true)
		after_mutate()
	end)
	for _, key in ipairs({"property_1", "property_2", "property_3", "property_4", "catalyst"}) do
		local def = defs.MATERIALS[key]
		ImGui.AddButton(mat, prefix .. "_Ins_" .. key, def.short or key, function()
			materials.debug_grant_all()
			materials.insert(key)
			after_mutate()
		end)
		ImGui.AddElement(mat, "", ImGuiElement.SameLine)
	end
	ImGui.AddButton(mat, prefix .. "_MClear", tr("清空投入", "Clear inserted"), function()
		materials.clear_all()
		after_mutate()
	end)

	local an = imgui_layout.add_section(parent_id, prefix .. "_Anchor", tr("相位锚", "Anchor"))
	ImGui.AddButton(an, prefix .. "_AIdle", "Idle", function()
		anchor.set_state("idle")
	end)
	ImGui.AddElement(an, "", ImGuiElement.SameLine)
	ImGui.AddButton(an, prefix .. "_AReady", "Ready", function()
		puzzle.force_complete({permanent = true})
		materials.debug_grant_all()
		materials.set_all(true)
		anchor.refresh_ready()
		after_mutate()
	end)
	ImGui.AddButton(an, prefix .. "_APlay", tr("播放启动", "Play activation"), function()
		anchor.play_activation_stub()
	end)
	ImGui.AddElement(an, "", ImGuiElement.SameLine)
	ImGui.AddButton(an, prefix .. "_AOpen", tr("强制打开", "Force open"), function()
		anchor.force_open()
	end)
end

return test
