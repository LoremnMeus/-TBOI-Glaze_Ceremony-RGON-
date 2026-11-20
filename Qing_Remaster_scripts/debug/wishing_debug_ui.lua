local layout = require("Qing_Remaster_scripts.debug.imgui_debug_layout")
local live = require("Qing_Remaster_scripts.debug.probe_live_cache")

local ui = {}

function ui.install(start_mod, page)
	local group = start_mod("item_wishing", page, "祈愿", "QingRemasterOptions_GroupWishing", {
		path = {"Wishing"}, kind = "tool",
	})
	if not group then return end
	local wishing = require("Qing_Remaster_scripts.items.Item_Wishing")
	local chosen = 1
	ImGui.AddInputInteger(group, "QingRemasterOptions_WishingId", "愿望道具 ID", function(value)
		chosen = math.floor(tonumber(value) or 1)
	end, chosen)
	local function player()
		return Isaac.IsInGame and Isaac.IsInGame() and Isaac.GetPlayer(0) or nil
	end
	ImGui.AddButton(group, "QingRemasterOptions_WishingOpen", "强制生成候选", function()
		wishing.debug_open(player())
	end)
	ImGui.AddButton(group, "QingRemasterOptions_WishingSet", "指定当前愿望", function()
		wishing.debug_set_wish(player(), chosen)
	end)
	ImGui.AddButton(group, "QingRemasterOptions_WishingSpawn", "生成带愿望的测试底座", function()
		wishing.debug_spawn_pedestal(player())
	end)
	ImGui.AddButton(group, "QingRemasterOptions_WishingMorph", "重置测试底座", function()
		wishing.debug_reroll_pedestal(player())
	end)
	local status_id = "QingRemasterOptions_WishingStatus"
	layout.add_plain_text(group, status_id, "祈愿")
	ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
		local p = player()
		live.update_text_if_changed(status_id, p and wishing.debug_status(p) or "not in game")
	end)
end

return ui
