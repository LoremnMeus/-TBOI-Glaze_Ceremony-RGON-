-- Debug → 视觉 → HUD Layout Audit.
-- Sliders live in ui.debug_hud_tune only. They do not enter ModConfigSettings or optional_maker.

local M = {}

local function vec_text(v)
	if not v then return "nil" end
	return string.format("%.1f, %.1f", v.X, v.Y)
end

local function add_xy(ImGui, group, prefix, label_x, label_y, ui, kind, state)
	local xid = prefix .. "X"
	local yid = prefix .. "Y"
	-- Drag step 0.5 only. Direct values such as 0.25 remain accepted.
	ImGui.AddDragFloat(group, xid, label_x, function(value)
		ui.SetHudDebugTune(kind, state, "x", value)
	end, 0, 0.5, -100, 100, "%.1f")
	ImGui.AddCallback(xid, ImGuiCallback.Render, function()
		ImGui.UpdateData(xid, ImGuiData.Value, ui.GetHudDebugTune(kind, state).X)
	end)
	ImGui.AddDragFloat(group, yid, label_y, function(value)
		ui.SetHudDebugTune(kind, state, "y", value)
	end, 0, 0.5, -100, 100, "%.1f")
	ImGui.AddCallback(yid, ImGuiCallback.Render, function()
		ImGui.UpdateData(yid, ImGuiData.Value, ui.GetHudDebugTune(kind, state).Y)
	end)
end

local function add_live_xy(ImGui, group, prefix, label_x, label_y, ui, kind)
	local xid = prefix .. "X"
	local yid = prefix .. "Y"
	ImGui.AddDragFloat(group, xid, label_x, function(value)
		ui.SetHudDebugTune(kind, ui.GetHudAuditResourceState(), "x", value)
	end, 0, 0.5, -100, 100, "%.1f")
	ImGui.AddCallback(xid, ImGuiCallback.Render, function()
		ImGui.UpdateData(xid, ImGuiData.Value, ui.GetHudDebugTune(kind, ui.GetHudAuditResourceState()).X)
	end)
	ImGui.AddDragFloat(group, yid, label_y, function(value)
		ui.SetHudDebugTune(kind, ui.GetHudAuditResourceState(), "y", value)
	end, 0, 0.5, -100, 100, "%.1f")
	ImGui.AddCallback(yid, ImGuiCallback.Render, function()
		ImGui.UpdateData(yid, ImGuiData.Value, ui.GetHudDebugTune(kind, ui.GetHudAuditResourceState()).Y)
	end)
end

local function card_text(ui)
	local lines = {}
	local rows = {
		{ ui.CARD_UI_STATE.NORMAL, "NORMAL" },
		{ ui.CARD_UI_STATE.MAIN_TWIN, "MAIN_TWIN" },
		{ ui.CARD_UI_STATE.OTHER_TWIN, "OTHER_TWIN" },
	}
	for _, row in ipairs(rows) do
		local values = ui.GetHudAuditValues("card", row[1])
		if values then
			lines[#lines + 1] = row[2]
			lines[#lines + 1] = "  Base:  (" .. vec_text(values.base) .. ")"
			lines[#lines + 1] = "  Tune:  (" .. vec_text(values.tune) .. ")"
			lines[#lines + 1] = "  Final: (" .. vec_text(values.final) .. ")"
		end
	end
	local game = Game()
	for i = 0, game:GetNumPlayers() - 1 do
		local player = game:GetPlayer(i)
		local info = player and ui.DescribePrimaryCardHud(player)
		if info then
			lines[#lines + 1] = string.format("P%d %s  %s", i, info.state_name, vec_text(info.pos))
		end
	end
	if #lines == 0 then return "no player" end
	return table.concat(lines, "\n")
end

local function environment_text(ui)
	local screen = ui.GetScreenSize()
	local lines = {
		string.format("Screen: %.0f x %.0f", screen.X, screen.Y),
		string.format("HUDOffset: %.2f", tonumber(Options.HUDOffset) or 0),
		"REPENTANCE_PLUS: " .. tostring(not not REPENTANCE_PLUS),
		"REPENTOGON: " .. tostring(not not REPENTOGON),
	}
	local game = Game()
	local count = game:GetNumPlayers()
	lines[#lines + 1] = "Players: " .. tostring(count)
	for i = 0, count - 1 do
		local player = game:GetPlayer(i)
		local info = player and ui.DescribePrimaryCardHud(player)
		if info then
			lines[#lines + 1] = string.format(
				"P%d type=%s layout=%s card=%s pos=%s",
				i,
				tostring(info.player_type),
				info.layout_name,
				info.state_name,
				vec_text(info.pos)
			)
		end
	end
	return table.concat(lines, "\n")
end

local function heart_text(ui, zh)
	local cap = ui.debug_hud_audit and ui.debug_hud_audit.heart
	local seat1 = ui.UIHeartPos(0, 1)
	local seat2 = ui.UIHeartPos(0, 2)
	local lines = {
		zh and "对照，不手调。" or "Comparison only. No slider.",
		"UIHeartPos seat1: " .. vec_text(seat1),
		"UIHeartPos seat2: " .. vec_text(seat2),
	}
	if not cap or not cap.position then
		lines[#lines + 1] = zh and "RGON: 尚无捕获" or "RGON: no capture"
	else
		lines[#lines + 1] = string.format("RGON Position: %s  scale=%s  seat=%s", vec_text(cap.position), tostring(cap.scale), tostring(cap.seat))
		if cap.offset then
			lines[#lines + 1] = "RGON Offset: " .. vec_text(cap.offset)
		end
		if seat1 then
			local d = cap.position - seat1
			lines[#lines + 1] = "Delta vs seat1: " .. vec_text(d)
		end
		if seat2 then
			local d = cap.position - seat2
			lines[#lines + 1] = "Delta vs seat2: " .. vec_text(d)
		end
	end
	return table.concat(lines, "\n")
end

local function active_text(ui, auxi, zh)
	local lines = {
		zh and "对照捕获值，不新手调。" or "Captured vs calculated. No slider.",
	}
	local game = Game()
	local slot = ActiveSlot and ActiveSlot.SLOT_PRIMARY or 0
	for i = 0, game:GetNumPlayers() - 1 do
		local player = game:GetPlayer(i)
		if player then
			local order = auxi.GetPlayerOrder and auxi.GetPlayerOrder(player) or 0
			local captured = ui.GetActiveSlotRenderInfo(player, slot)
			local calc = ui.PlayerActiveUIPos(player, slot, order, nil, { ignore_capture = true })
			if not captured or not captured.offset then
				lines[#lines + 1] = string.format("P%d RGON: no capture", i)
			else
				local scale = tonumber(captured.scale) or 1
				local center = captured.offset + Vector(16 * scale, 16 * scale)
				lines[#lines + 1] = string.format(
					"P%d RGON offset=%s scale=%.2f alpha=%s",
					i,
					vec_text(captured.offset),
					scale,
					tostring(captured.alpha)
				)
				lines[#lines + 1] = "  RGON center: " .. vec_text(center)
			end
			lines[#lines + 1] = string.format("  Qing calc: %s", vec_text(calc))
			if captured and captured.offset and calc then
				local scale = tonumber(captured.scale) or 1
				local center = captured.offset + Vector(16 * scale, 16 * scale)
				lines[#lines + 1] = "  Delta center-calc: " .. vec_text(center - calc)
			end
		end
	end
	return table.concat(lines, "\n")
end

function M.build(api)
	local ui = require("Qing_Remaster_scripts.auxiliary.ui")
	local ImGui = api.ImGui
	local imgui_layout = api.imgui_layout
	local add_separator = api.add_separator
	local language_key = api.language_key
	local auxi = api.auxi
	local zh = language_key() == "zh"
	local group = api.start_mod(
		"visual_hud_layout_audit",
		api.DEBUG_PAGE.visual,
		zh and "HUD Layout Audit" or "HUD Layout Audit",
		"QingRemasterOptions_GroupHudLayoutAudit",
		{ path = { "HUD Layout Audit" }, kind = "tool" }
	)
	if not group then return end

	local env_id = "QingRemasterOptions_HudAuditEnv"
	imgui_layout.add_plain_text(group, env_id, "")
	ImGui.AddCallback(env_id, ImGuiCallback.Render, function()
		local ok, text = pcall(environment_text, ui)
		imgui_layout.update_text(env_id, ok and text or tostring(text))
	end)

	add_separator(group)
	imgui_layout.add_plain_text(group, "QingRemasterOptions_HudAuditCardHead", zh and "Card" or "Card")
	local card_id = "QingRemasterOptions_HudAuditCard"
	imgui_layout.add_plain_text(group, card_id, "")
	ImGui.AddCallback(card_id, ImGuiCallback.Render, function()
		local ok, text = pcall(card_text, ui)
		imgui_layout.update_text(card_id, ok and text or tostring(text))
	end)

	local guide_id = "QingRemasterOptions_HudAuditCardGuide"
	ImGui.AddCheckbox(group, guide_id, zh and "显示卡牌锚点" or "Draw card anchor", nil, false)
	ImGui.AddCallback(guide_id, ImGuiCallback.Render, function()
		ImGui.UpdateData(guide_id, ImGuiData.Value, ui.debug_hud_audit.draw_card_guide == true)
	end)
	ImGui.AddCallback(guide_id, ImGuiCallback.Edited, function(value)
		ui.debug_hud_audit.draw_card_guide = value == true
	end)

	local card = ui.CARD_UI_STATE
	add_xy(ImGui, group, "QingRemasterOptions_HudCardNormal", "Normal X", "Normal Y", ui, "card", card.NORMAL)
	add_xy(ImGui, group, "QingRemasterOptions_HudCardMain", "Main Twin X", "Main Twin Y", ui, "card", card.MAIN_TWIN)
	add_xy(ImGui, group, "QingRemasterOptions_HudCardOther", "Other Twin X", "Other Twin Y", ui, "card", card.OTHER_TWIN)

	imgui_layout.add_plain_text(
		group,
		"QingRemasterOptions_HudAuditCardHint",
		zh and "滑条只改 Tune。Base 已固化；改完后请 Reset Card Tune，避免 base+tune 二次叠加。Print 输出 Final = Base + Tune。"
			or "Sliders change Tune only. After freezing Base, Reset Card Tune so Base+Tune do not stack. Print writes Final = Base + Tune."
	)
	ImGui.AddButton(group, "QingRemasterOptions_HudCardReset", zh and "Reset Card Tune" or "Reset Card Tune", function()
		ui.ResetHudDebugTune("card")
	end)
	ImGui.AddElement(group, "", ImGuiElement.SameLine)
	ImGui.AddButton(group, "QingRemasterOptions_HudCardPrint", zh and "Print Card Positions" or "Print Card Positions", function()
		ui.PrintCardHudAudit()
	end)

	add_separator(group)
	imgui_layout.add_plain_text(group, "QingRemasterOptions_HudAuditResHead", zh and "Resources" or "Resources")
	local state_id = "QingRemasterOptions_HudAuditResState"
	imgui_layout.add_plain_text(group, state_id, "")
	ImGui.AddCallback(state_id, ImGuiCallback.Render, function()
		local ok, text = pcall(function()
			local state = ui.GetHudAuditResourceState()
			local name = state == 2 and "TWIN" or "NORMAL"
			return (zh and "Current: " or "Current: ") .. name
		end)
		imgui_layout.update_text(state_id, ok and text or tostring(text))
	end)
	local combo_id = "QingRemasterOptions_HudAuditResMode"
	local modes = { "Auto", "Normal", "Twin" }
	ImGui.AddCombobox(group, combo_id, zh and "Resource State" or "Resource State", function(index)
		index = tonumber(index) or 0
		if index == 1 then
			ui.debug_hud_audit.resource_state = 1
		elseif index == 2 then
			ui.debug_hud_audit.resource_state = 2
		else
			ui.debug_hud_audit.resource_state = nil
		end
	end, modes, 0)
	ImGui.AddCallback(combo_id, ImGuiCallback.Render, function()
		local forced = ui.debug_hud_audit.resource_state
		local index = 0
		if forced == 1 then index = 1
		elseif forced == 2 then index = 2 end
		ImGui.UpdateData(combo_id, ImGuiData.Value, index)
	end)

	local res_guide = "QingRemasterOptions_HudAuditResGuide"
	ImGui.AddCheckbox(group, res_guide, zh and "显示资源准星" or "Draw resource guides", nil, false)
	ImGui.AddCallback(res_guide, ImGuiCallback.Render, function()
		ImGui.UpdateData(res_guide, ImGuiData.Value, ui.debug_hud_audit.draw_resource_guide == true)
	end)
	ImGui.AddCallback(res_guide, ImGuiCallback.Edited, function(value)
		ui.debug_hud_audit.draw_resource_guide = value == true
	end)

	add_live_xy(ImGui, group, "QingRemasterOptions_HudCoin", "Coin X", "Coin Y", ui, "coin")
	add_live_xy(ImGui, group, "QingRemasterOptions_HudBomb", "Bomb X", "Bomb Y", ui, "bomb")
	add_live_xy(ImGui, group, "QingRemasterOptions_HudKey", "Key X", "Key Y", ui, "key")
	ImGui.AddButton(group, "QingRemasterOptions_HudResReset", zh and "Reset Current" or "Reset Current", function()
		local state = ui.GetHudAuditResourceState()
		ui.ResetHudDebugTuneState("coin", state)
		ui.ResetHudDebugTuneState("bomb", state)
		ui.ResetHudDebugTuneState("key", state)
	end)
	ImGui.AddElement(group, "", ImGuiElement.SameLine)
	ImGui.AddButton(group, "QingRemasterOptions_HudResResetAll", zh and "Reset All" or "Reset All", function()
		ui.ResetHudDebugTune("coin")
		ui.ResetHudDebugTune("bomb")
		ui.ResetHudDebugTune("key")
	end)
	ImGui.AddElement(group, "", ImGuiElement.SameLine)
	ImGui.AddButton(group, "QingRemasterOptions_HudResPrint", zh and "Print All" or "Print All", function()
		ui.PrintResourceHudAudit()
	end)

	add_separator(group)
	imgui_layout.add_plain_text(group, "QingRemasterOptions_HudAuditHeartHead", zh and "Health" or "Health")
	local heart_id = "QingRemasterOptions_HudAuditHeart"
	imgui_layout.add_plain_text(group, heart_id, "")
	ImGui.AddCallback(heart_id, ImGuiCallback.Render, function()
		local ok, text = pcall(heart_text, ui, zh)
		imgui_layout.update_text(heart_id, ok and text or tostring(text))
	end)

	add_separator(group)
	imgui_layout.add_plain_text(group, "QingRemasterOptions_HudAuditActiveHead", zh and "Active" or "Active")
	local active_id = "QingRemasterOptions_HudAuditActive"
	imgui_layout.add_plain_text(group, active_id, "")
	ImGui.AddCallback(active_id, ImGuiCallback.Render, function()
		local ok, text = pcall(active_text, ui, auxi, zh)
		imgui_layout.update_text(active_id, ok and text or tostring(text))
	end)
end

return M
