-- Boss Test Lab ImGui page.
-- Pure combat practice UI. Story progression stays in Story Test.
-- Adapters come from boss_test_registry; capability flags drive optional panels.
-- Force State ≠ Play Performance (must not share one button path).

local boss_test_registry = require("Qing_Remaster_scripts.bosses.boss_test_registry")
local imgui_layout = require("Qing_Remaster_scripts.debug.imgui_debug_layout")

local M = {}

local function tr(zh, en)
	local lang = Options and Options.Language
	if lang == "zh" or lang == nil then return zh end
	return en
end

local function cap(adapter, name)
	return adapter and adapter.capabilities and adapter.capabilities[name] == true
end

local function fmt_inspect(adapter)
	if not adapter or not adapter.inspect then return tr("无遭遇", "No encounter") end
	local s = adapter.inspect()
	if not s or s.state == "absent" or s.alive == false then
		return tr("状态：未生成", "State: absent")
	end
	local lines = {
		string.format("Phase %s  state=%s", tostring(s.phase), tostring(s.state)),
		string.format("HP %.1f%%  attack=%s f=%s", (s.hp_ratio or s.hp or 0) * 100, tostring(s.current_attack or s.attack), tostring(s.attack_frame)),
		string.format("Transition=%s f=%s  Finale=%s", tostring(s.transition), tostring(s.transition_frame), tostring(s.finale or s.final_state)),
		string.format("Crown=%s  Freeze=%s", tostring(s.crown_visible), tostring(s.frozen)),
	}
	if s.palace then
		local p = s.palace
		lines[#lines + 1] = string.format(
			"Palace build=%.2f stability=%.2f palette=%s pieces=%s/%s anchors=%s",
			p.build or 0, p.stability or 0, tostring(p.palette),
			tostring(p.visible_piece_count), tostring(p.piece_count), tostring(p.anchor_count)
		)
	end
	if s.objects then
		local o = s.objects
		lines[#lines + 1] = string.format(
			"Objects mirrors=%s shards=%s fields=%s echoes=%s",
			tostring(o.mirrors), tostring(o.shards), tostring(o.fields), tostring(o.echoes)
		)
	else
		lines[#lines + 1] = string.format(
			"Objects mirrors=%s shards=%s fields=%s echoes=%s",
			tostring(s.mirrors), tostring(s.shards), tostring(s.fields), tostring(s.echoes)
		)
	end
	return table.concat(lines, "\n")
end

local function build_adapter_panel(parent, entry)
	local boss = entry.boss
	local adapter = entry.adapter
	local id = boss.id
	local label = (boss.name and (boss.name.zh or boss.name.en)) or id
	local node = parent .. "_" .. id
	ImGui.AddElement(parent, node, ImGuiElement.CollapsingHeader, label .. "  [" .. tostring(boss.status) .. "]")

	if not adapter then
		imgui_layout.add_wrapped_text(node, node .. "_Missing", tr("暂无 Boss Test 适配器", "No Boss Test adapter yet"))
		return
	end

	-- Encounter
	local enc = node .. "_Enc"
	ImGui.AddElement(node, enc, ImGuiElement.TreeNode, tr("遭遇控制", "Encounter"))
	if adapter.spawn then ImGui.AddButton(enc, enc .. "_Spawn", tr("生成", "Spawn"), adapter.spawn) end
	if adapter.restart then ImGui.AddButton(enc, enc .. "_Restart", tr("重新开始", "Restart"), adapter.restart) end
	if adapter.cleanup then ImGui.AddButton(enc, enc .. "_Cleanup", tr("清理", "Cleanup"), adapter.cleanup) end
	if adapter.kill then ImGui.AddButton(enc, enc .. "_Kill", tr("击杀（测试模式）", "Kill (practice)"), adapter.kill) end

	-- Force State (stable phase, no transition playback)
	if adapter.states and adapter.force_state then
		local st = node .. "_State"
		ImGui.AddElement(node, st, ImGuiElement.TreeNode, tr("状态（直接进入，不播转场）", "State (instant, no transition)"))
		for _, state in ipairs(adapter.states) do
			local sid = state.id
			ImGui.AddButton(st, st .. "_" .. sid, state.label or sid, function() adapter.force_state(sid) end)
		end
	end

	-- HP
	if cap(adapter, "hp_control") and adapter.set_hp_ratio then
		local hp = node .. "_HP"
		ImGui.AddElement(node, hp, ImGuiElement.TreeNode, tr("生命值", "HP"))
		ImGui.AddSliderFloat(hp, hp .. "_Slider", "HP %", function(v)
			adapter.set_hp_ratio((tonumber(v) or 100) / 100)
		end, 100, 1, 100, "%.0f")
		ImGui.AddCallback(hp .. "_Slider", ImGuiCallback.Render, function()
			local s = adapter.inspect and adapter.inspect() or {}
			local ratio = (s.hp_ratio or s.hp or 1) * 100
			ImGui.UpdateData(hp .. "_Slider", ImGuiData.Value, ratio)
		end)
		local thresholds = {66, 65, 33, 32, 11, 10}
		for _, pct in ipairs(thresholds) do
			local n = pct
			ImGui.AddButton(hp, hp .. "_" .. n, n .. "%", function() adapter.set_hp_ratio(n / 100) end)
		end
	end

	-- Performances (real production transitions)
	if adapter.performances and adapter.play_performance then
		local perf = node .. "_Perf"
		ImGui.AddElement(node, perf, ImGuiElement.TreeNode, tr("演出（走生产转场）", "Performance (production transition)"))
		for _, p in ipairs(adapter.performances) do
			local pid = p.id
			ImGui.AddButton(perf, perf .. "_" .. pid, p.label or pid, function() adapter.play_performance(pid) end)
		end
	end

	-- Attacks
	if adapter.attacks and adapter.play_attack then
		local atk = node .. "_Atk"
		ImGui.AddElement(node, atk, ImGuiElement.TreeNode, tr("攻击", "Attacks"))
		local groups = {}
		for _, a in ipairs(adapter.attacks) do
			local g = a.group or "misc"
			groups[g] = groups[g] or {}
			groups[g][#groups[g] + 1] = a
		end
		local order = {"P1", "P2", "P3", "Finale", "misc"}
		for _, gname in ipairs(order) do
			local list = groups[gname]
			if list then
				local gnode = atk .. "_" .. gname
				ImGui.AddElement(atk, gnode, ImGuiElement.TreeNode, gname)
				for _, a in ipairs(list) do
					local aid = a.id
					ImGui.AddButton(gnode, gnode .. "_" .. aid, a.label or aid, function() adapter.play_attack(aid) end)
				end
			end
		end
		if adapter.next_attack then
			ImGui.AddButton(atk, atk .. "_Next", tr("下一攻击", "Next Attack"), adapter.next_attack)
		end
		if adapter.reset_attack then
			ImGui.AddButton(atk, atk .. "_Reset", tr("取消当前攻击", "Cancel Attack"), adapter.reset_attack)
		end
		if adapter.clear_objects then
			ImGui.AddButton(atk, atk .. "_Clear", tr("清除 Boss 生成物", "Clear Objects"), adapter.clear_objects)
		end
	end

	-- Palace
	if cap(adapter, "palace") then
		local pal = node .. "_Palace"
		ImGui.AddElement(node, pal, ImGuiElement.TreeNode, tr("琉璃宫", "Palace"))
		if adapter.set_palace_build then
			ImGui.AddSliderFloat(pal, pal .. "_Build", "Build", function(v)
				adapter.set_palace_build(tonumber(v) or 0)
			end, 0, 0, 1, "%.2f")
			ImGui.AddCallback(pal .. "_Build", ImGuiCallback.Render, function()
				local s = adapter.inspect and adapter.inspect() or {}
				local b = s.palace and s.palace.build or 0
				ImGui.UpdateData(pal .. "_Build", ImGuiData.Value, b)
			end)
		end
		if adapter.set_palace_stability then
			ImGui.AddSliderFloat(pal, pal .. "_Stab", "Stability", function(v)
				adapter.set_palace_stability(tonumber(v) or 1)
			end, 1, 0, 1, "%.2f")
			ImGui.AddCallback(pal .. "_Stab", ImGuiCallback.Render, function()
				local s = adapter.inspect and adapter.inspect() or {}
				local b = s.palace and s.palace.stability or 1
				ImGui.UpdateData(pal .. "_Stab", ImGuiData.Value, b)
			end)
		end
		if adapter.set_palace_build then
			ImGui.AddButton(pal, pal .. "_Full", tr("完整建立", "Fully Built"), function() adapter.set_palace_build(1); if adapter.set_palace_stability then adapter.set_palace_stability(1) end end)
			ImGui.AddButton(pal, pal .. "_Half", tr("半建立", "Half Built"), function() adapter.set_palace_build(0.5) end)
			ImGui.AddButton(pal, pal .. "_Collapse", tr("开始崩坏", "Begin Collapse"), function() if adapter.begin_palace_collapse then adapter.begin_palace_collapse() elseif adapter.set_palace_stability then adapter.set_palace_stability(0) end end)
			ImGui.AddButton(pal, pal .. "_Ruin", tr("废墟", "Ruins"), function() adapter.set_palace_build(1); if adapter.set_palace_stability then adapter.set_palace_stability(0) end end)
		end
		if adapter.preview_palace then
			ImGui.AddButton(pal, pal .. "_Preview", tr("单独预览", "Preview Only"), adapter.preview_palace)
		end
		if adapter.clear_palace then
			ImGui.AddButton(pal, pal .. "_ClearPal", tr("清除宫殿", "Clear Palace"), adapter.clear_palace)
		end
		if adapter.set_palace_palette then
			ImGui.AddButton(pal, pal .. "_PalN", tr("调色：正常", "Palette: Normal"), function() adapter.set_palace_palette("normal") end)
			ImGui.AddButton(pal, pal .. "_PalB", tr("调色：破碎", "Palette: Broken"), function() adapter.set_palace_palette("broken") end)
		end
		if adapter.set_palace_debug then
			ImGui.AddCheckbox(pal, pal .. "_Anch", tr("显示 Anchor", "Show Anchors"), function(v) adapter.set_palace_debug("show_anchors", v) end, false)
			ImGui.AddCheckbox(pal, pal .. "_Pid", tr("显示 Piece ID", "Show Piece IDs"), function(v) adapter.set_palace_debug("show_piece_ids", v) end, false)
			ImGui.AddCheckbox(pal, pal .. "_AtkA", tr("显示攻击 Anchor", "Show Attack Anchors"), function(v) adapter.set_palace_debug("show_attack_anchor", v) end, false)
		end
	end

	-- Simulation freeze/step
	if cap(adapter, "freeze") then
		local sim = node .. "_Sim"
		ImGui.AddElement(node, sim, ImGuiElement.TreeNode, tr("模拟", "Simulation"))
		ImGui.AddCheckbox(sim, sim .. "_Freeze", tr("冻结 Boss 逻辑", "Freeze Boss Logic"), function(v)
			if adapter.set_frozen then adapter.set_frozen(v == true) end
		end, false)
		ImGui.AddCallback(sim .. "_Freeze", ImGuiCallback.Render, function()
			local s = adapter.inspect and adapter.inspect() or {}
			ImGui.UpdateData(sim .. "_Freeze", ImGuiData.Value, s.frozen == true)
		end)
		if adapter.step then
			ImGui.AddButton(sim, sim .. "_Step1", tr("推进 1 帧", "Step 1"), function() adapter.step(1) end)
			ImGui.AddButton(sim, sim .. "_Step10", tr("推进 10 帧", "Step 10"), function() adapter.step(10) end)
		end
	end

	if adapter.labels then
		ImGui.AddCheckbox(node, node .. "_Labels", tr("占位符标签", "Placeholder Labels"), function(v)
			adapter.labels(v == true)
		end, true)
	end

	-- Inspector
	local insp = node .. "_Insp"
	imgui_layout.add_wrapped_text(node, insp, "")
	ImGui.AddCallback(insp, ImGuiCallback.Render, function()
		imgui_layout.update_text(insp, fmt_inspect(adapter))
	end)
end

function M.build(parent_id)
	if not ImGui or not parent_id then return end
	-- Ensure Glaze adapter is registered (Boss_Glaze may already have done this).
	pcall(require, "Qing_Remaster_scripts.bosses.Boss_Glaze")

	ImGui.AddElement(
		parent_id, "", ImGuiElement.SeparatorText or ImGuiElement.Separator,
		tr("Boss 实验室", "Boss Test Lab")
	)
	imgui_layout.add_wrapped_text(
		parent_id, parent_id .. "_Banner",
		tr(
			"纯战斗练习。Practice 不会解锁剧情/成就。Story 推进请用 Story Test。\nForce State = 瞬移稳定阶段；Performance = 真正播放生产转场。",
			"Combat practice only. Practice never unlocks Story/achievements. Use Story Test for narrative.\nForce State = stable phase jump; Performance = real production transition."
		)
	)

	for _, entry in ipairs(boss_test_registry.list()) do
		build_adapter_panel(parent_id, entry)
	end
end

return M
