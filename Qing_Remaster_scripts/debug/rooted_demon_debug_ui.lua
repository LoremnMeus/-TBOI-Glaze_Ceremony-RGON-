-- Debug -> Items -> Rooted Demon. Test inventory actions belong to this item.
local layout = require("Qing_Remaster_scripts.debug.imgui_debug_layout")
local live = require("Qing_Remaster_scripts.debug.probe_live_cache")

local ui = {}

local function grant_sequence(ids)
	if not Isaac.IsInGame or not Isaac.IsInGame() then return end
	local player = Isaac.GetPlayer(0)
	if not player then return end
	for _, id in ipairs(ids) do player:AddCollectible(id, 0, true) end
end

function ui.install(start_mod, page)
	local group = start_mod("item_rooted_demon", page, "根植之魔", "QingRemasterOptions_GroupRootedDemon", {
		path = {"Rooted Demon"}, kind = "tool",
	})
	if not group then return end
	local rooted = require("Qing_Remaster_scripts.items.Item_Rooted_Demon")
	layout.add_wrapped_text(group, "QingRemasterOptions_RootedDemonHelp",
		"在新游戏中准备测试序列，再进入未访问房间。多根系并行生长；普通队列按钮加入 A -> 根植之魔。撞击时成功生成底座并移除道具即标记已提交；后续 poof 和根系收回只是视觉收尾。测试播放仅在真实动画未运行时预览，不移除道具或生成底座。十字：R 根植、T 目标、M 移动图标、L 落点。")
	local anchors_id = "QingRemasterOptions_RootedDemonAnchors"
	ImGui.AddCheckbox(group, anchors_id, "标记根植之魔与目标锚点", nil, rooted.debug_get_anchors())
	ImGui.AddCallback(anchors_id, ImGuiCallback.Edited, function(value)
		rooted.debug_set_anchors(value == true)
	end)
	ImGui.AddCallback(anchors_id, ImGuiCallback.Render, function()
		ImGui.UpdateData(anchors_id, ImGuiData.Value, rooted.debug_get_anchors())
	end)
	ImGui.AddButton(group, "QingRemasterOptions_RootedDemonGrant", "准备三根测试序列", function()
		grant_sequence({1, rooted.entity, 2, rooted.entity, 3, rooted.entity})
	end)
	ImGui.AddButton(group, "QingRemasterOptions_RootedDemonStandard", "准备普通队列测试", function()
		grant_sequence({1, rooted.entity})
	end)
	ImGui.AddButton(group, "QingRemasterOptions_RootedDemonPreview", "测试播放动画", function()
		if Isaac.IsInGame and Isaac.IsInGame() then rooted.debug_preview(Isaac.GetPlayer(0)) end
	end)
	ImGui.AddButton(group, "QingRemasterOptions_RootedDemonGrowthBurst", "立刻触发二阶段大招", function()
		if Isaac.IsInGame and Isaac.IsInGame() then rooted.debug_growth_burst(Isaac.GetPlayer(0)) end
	end)
	ImGui.AddButton(group, "QingRemasterOptions_RootedDemonDuplicate", "准备同 ID 双根序列", function()
		grant_sequence({1, rooted.entity, 1, rooted.entity})
	end)
	ImGui.AddButton(group, "QingRemasterOptions_RootedDemonAdjacent", "准备连续双根序列", function()
		grant_sequence({1, 2, rooted.entity, rooted.entity})
	end)
	ImGui.AddButton(group, "QingRemasterOptions_RootedDemonClear", "清除当前动画", function()
		rooted.debug_clear_visuals()
	end)
	local status_id = "QingRemasterOptions_RootedDemonStatus"
	layout.add_plain_text(group, status_id, "动画队列 0")
	ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
		local queued, tick, phase, pending, committed, details = rooted.debug_status()
		local plan = Isaac.IsInGame and Isaac.IsInGame() and rooted.debug_plan(Isaac.GetPlayer(0)) or "not in game"
		live.update_text_if_changed(status_id,
			string.format("阶段 %s / 动画 %d / 待提交 %d / 已提交 %d / 运行帧 %d\n%s\n%s",
				tostring(phase), queued, pending, committed, tick, details, plan))
	end)
end

return ui
