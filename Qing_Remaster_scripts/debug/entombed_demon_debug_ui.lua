-- 调试 → 道具 → 棺中之魔
local layout = require("Qing_Remaster_scripts.debug.imgui_debug_layout")
local live = require("Qing_Remaster_scripts.debug.probe_live_cache")

local ui = {}

function ui.install(start_mod, page)
	local group = start_mod("item_entombed_demon", page, "棺中之魔", "QingRemasterOptions_GroupEntombedDemon", {
		path = {"Entombed Demon"}, kind = "tool",
	})
	if not group then return end
	local entombed = require("Qing_Remaster_scripts.items.Item_Entombed_Demon")
	layout.add_wrapped_text(group, "QingRemasterOptions_EntombedDemonHelp",
		"正式换层与模拟按钮会让尚未结算的棺材同时播放仪式，并各自吞噬不同的后续道具，最后一帧一起结算。准备序列会先给棺中之魔，再给四件被动。")
	ImGui.AddButton(group, "QingRemasterOptions_EntombedDemonTrigger", "立刻模拟下一层触发", function()
		if not Isaac.IsInGame or not Isaac.IsInGame() then return end
		entombed.debug_trigger(Isaac.GetPlayer(0))
	end)
	ImGui.AddButton(group, "QingRemasterOptions_EntombedDemonPrepare", "准备测试序列", function()
		if Isaac.IsInGame and Isaac.IsInGame() then entombed.debug_prepare(Isaac.GetPlayer(0)) end
	end)
	ImGui.AddButton(group, "QingRemasterOptions_EntombedDemonShift", "模拟目标位置改变", function()
		if Isaac.IsInGame and Isaac.IsInGame() then entombed.debug_shift_target(Isaac.GetPlayer(0)) end
	end)
	ImGui.AddButton(group, "QingRemasterOptions_EntombedDemonMissing", "模拟目标消失并中止", function()
		if Isaac.IsInGame and Isaac.IsInGame() then entombed.debug_missing_target(Isaac.GetPlayer(0)) end
	end)
	ImGui.AddButton(group, "QingRemasterOptions_EntombedDemonCancel", "中止当前仪式", function()
		if Isaac.IsInGame and Isaac.IsInGame() then entombed.debug_cancel(Isaac.GetPlayer(0)) end
	end)
	for _, setting in ipairs({
		{"speed", "动画速度", 0.25, 3, 0.05},
		{"hand_width", "手臂宽度", 2, 16, 0.5},
		{"orb_diameter", "球团直径", 4, 24, 0.5},
		{"arc", "球团弧度", 0, 0.8, 0.02},
	}) do
		local key, label, min_v, max_v, step = table.unpack(setting)
		local id = "QingRemasterOptions_EntombedDemon_" .. key
		ImGui.AddDragFloat(group, id, label, function(value)
			entombed.debug_set_visual(key, value)
		end, entombed.debug_get_visual(key), step, min_v, max_v, "%.2f")
		ImGui.AddCallback(id, ImGuiCallback.Render, function()
			ImGui.UpdateData(id, ImGuiData.Value, entombed.debug_get_visual(key))
		end)
	end
	local seija_id = "QingRemasterOptions_EntombedDemonForceSeija"
	ImGui.AddCheckbox(group, seija_id, "强制 Seija", function(value)
		entombed.debug_set_force_seija(value == true)
	end, entombed.debug_force_seija())
	ImGui.AddCallback(seija_id, ImGuiCallback.Render, function()
		ImGui.UpdateData(seija_id, ImGuiData.Value, entombed.debug_force_seija())
	end)
	layout.add_wrapped_text(group, "QingRemasterOptions_EntombedDemonSeijaHelp",
		"强制开启时，封存生成上限为 1。已封存的更早记录仍保留，只生成最早的一件。")
	ImGui.AddButton(group, "QingRemasterOptions_EntombedDemonRestore", "恢复默认", function()
		entombed.debug_set_force_seija(false)
	end)
	ImGui.AddButton(group, "QingRemasterOptions_EntombedDemonReset", "重置该玩家全部棺材", function()
		if Isaac.IsInGame and Isaac.IsInGame() then entombed.debug_reset(Isaac.GetPlayer(0)) end
	end)
	local status_id = "QingRemasterOptions_EntombedDemonStatus"
	layout.add_plain_text(group, status_id, "棺中之魔")
	ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
		local text = "not in game"
		if Isaac.IsInGame and Isaac.IsInGame() then
			text = entombed.debug_status(Isaac.GetPlayer(0))
		end
		live.update_text_if_changed(status_id, text)
	end)
end

return ui
