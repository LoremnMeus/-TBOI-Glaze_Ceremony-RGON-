-- Stone map-layer debug helpers (Story Test + console).

local defs = require("Qing_Remaster_scripts.threads.stone.stone_defs")
local runtime = require("Qing_Remaster_scripts.threads.stone.stone_runtime")
local layout = require("Qing_Remaster_scripts.threads.stone.stone_layout")
local route = require("Qing_Remaster_scripts.threads.stone.stone_route")
local rooms = require("Qing_Remaster_scripts.threads.stone.stone_rooms")
local imgui_layout = require("Qing_Remaster_scripts.debug.imgui_debug_layout")
local grid_door = require("Qing_Remaster_scripts.grids.grid_doors")
local gate = require("Qing_Remaster_scripts.story.story_runtime_gate")

local debug = {}

local function tr(zh, en)
	local language = Options and Options.Language
	return (language == "en") and en or zh
end

local function change_room(index)
	if index == nil then return false, "nil" end
	if REPENTOGON then
		Game():ChangeRoom(index)
	else
		Game():GetLevel():ChangeRoom(index)
	end
	return true
end

function debug.ensure_layout(opts)
	return layout.ensure_for_current_floor(opts or { force = true, ignore_gate = true })
end

function debug.goto_trigger()
	debug.ensure_layout({ force = true, ignore_gate = true })
	local r = runtime.get()
	if not r.trigger then return false, "no trigger" end
	return change_room(r.trigger.safe_grid_index)
end

function debug.goto_origin(opts)
	return debug.goto_trigger(opts)
end

function debug.activate()
	debug.ensure_layout({ force = true, ignore_gate = true })
	rooms.clear_origin_placeholder()
	return runtime.activate_board("debug")
end

function debug.goto_route_index(index)
	debug.ensure_layout({ force = true, ignore_gate = true })
	local path = route.get_path()
	if #path < 1 then return false, "no route" end
	index = math.max(1, math.min(#path, index or 1))
	return change_room(path[index])
end

function debug.goto_route_start()
	return debug.goto_route_index(1)
end

function debug.goto_route_middle()
	local path = route.get_path()
	return debug.goto_route_index(math.max(1, math.ceil(#path / 2)))
end

function debug.goto_route_end()
	local path = route.get_path()
	return debug.goto_route_index(#path)
end

function debug.goto_terminal(opts)
	opts = opts or {}
	debug.ensure_layout({ force = true, ignore_gate = true })
	local r = runtime.get()
	if not r.terminal then return false, "no terminal" end
	if opts.activate then
		runtime.activate_board("debug")
	end
	if opts.force_reveal then
		r.gate.unlocked = true
		r.gate.reveal_pending = true
	elseif opts.unlock then
		r.gate.unlocked = true
		r.gate.reveal_pending = false
	end
	local ok = change_room(r.terminal.safe_grid_index)
	return ok
end

function debug.goto_antechamber(opts)
	opts = opts or {}
	debug.ensure_layout({ force = true, ignore_gate = true })
	local r = runtime.get()
	if not r.board.activated then
		runtime.activate_board("debug")
	end
	r = runtime.get()
	if not r.hidden then return false, "no hidden" end
	Isaac.ExecuteCommand("goto " .. defs.goto_default(r.hidden.ante_variant))
	return true
end

function debug.goto_floraine(opts)
	opts = opts or {}
	debug.ensure_layout({ force = true, ignore_gate = true })
	local r = runtime.get()
	if not r.board.activated then
		runtime.activate_board("debug")
	end
	r = runtime.get()
	if not r.hidden then return false, "no hidden" end
	r.suppress_floraine = opts.suppress_boss ~= false
	Isaac.ExecuteCommand("goto " .. defs.goto_default(r.hidden.floraine_variant))
	return true
end

function debug.preview_door(slot, anim)
	slot = slot or DoorSlot.UP0
	anim = anim or "Opened"
	local room = Game():GetRoom()
	grid_door.try_spawn_grid_door(room, slot, nil, {
		check_and_leave = function() end,
		loadname = defs.DOOR_ANM2,
		playname = anim,
		should_update = anim ~= "Opened" and anim ~= "Closed",
		on_update = function(doorinfo)
			local door = doorinfo.door
			if not door then return end
			local s = door:GetSprite()
			if s:IsFinished(anim) and (anim == "Reveal" or anim == "Open") then
				s:Play("Opened", true)
			end
		end,
	})
	return true
end

function debug.inspect_text()
	local snap = runtime.debug_snapshot()
	local lines = {
		tr("棋盘地图层", "Stone Map Layer"),
		"────────────────",
		"Phase: " .. tostring(snap.phase),
		"Trigger SGI: " .. tostring(snap.trigger or "-"),
		"Terminal SGI: " .. tostring(snap.terminal or "-"),
		"Route: " .. table.concat(snap.route or {}, " → "),
		"Board: " .. tostring(snap.activated),
		"Gate: " .. tostring(snap.gate_unlocked),
		"Ante: " .. tostring(snap.ante or "-"),
		"Floraine: " .. tostring(snap.floraine or "-"),
		"Fail: " .. tostring(snap.fail or "-"),
		"Mines1 success: " .. tostring(snap.mines1_success),
		"Gate event: " .. tostring(gate.is_material_event_enabled("chapter1.stone")),
	}
	return table.concat(lines, "\n")
end

function debug.get_test_descriptor()
	return {
		id = "chapter1.stone",
		title = {zh = "棋盘 / Floraine", en = "Chess / Floraine"},
		floor_preset = "mines_ashpit",
		-- Start at trigger room with board NOT activated (player can shatter pawn).
		start_step = "chapter1.stone.trigger",
		checkpoints = {
			{step = "chapter1.stone.trigger", label = {zh = "黑兵触发前", en = "Before pawn trigger"}},
			{step = "chapter1.stone.activate", label = {zh = "棋盘展开后", en = "After board opens"}},
			{step = "chapter1.stone.route_mid", label = {zh = "路线中段", en = "Route mid"}},
			{step = "chapter1.stone.terminal", label = {zh = "路线终点", en = "Route end"}},
			{
				label = {zh = "终点门出现后", en = "After terminal Reveal"},
				action = function()
					debug.goto_terminal({activate = true, force_reveal = true})
				end,
			},
			{step = "chapter1.stone.antechamber", label = {zh = "前厅", en = "Antechamber"}},
			{step = "chapter1.stone.boss", label = {zh = "Floraine 战前", en = "Before Floraine"}},
		},
		build_advanced = function(parent_id)
			debug.build_advanced(parent_id)
		end,
	}
end

--- Advanced sandbox only (Dev Lab sinks primary workflow above).
function debug.build_advanced(parent_id)
	if not ImGui or not parent_id then return end
	local prefix = parent_id .. "_StoneAdv"

	imgui_layout.add_wrapped_text(parent_id, prefix .. "_Status", "")
	ImGui.AddCallback(prefix .. "_Status", ImGuiCallback.Render, function()
		imgui_layout.update_text(prefix .. "_Status", debug.inspect_text())
	end)

	ImGui.AddButton(parent_id, prefix .. "_Plan", tr("重新规划本层", "Replan floor"), function()
		layout.try_plan_current_floor({ force = true, ignore_gate = true })
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_Act", tr("强制激活棋盘", "Force activate board"), function()
		debug.activate()
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_Reset", tr("重置棋盘运行态", "Reset Stone runtime"), function()
		runtime.reset()
	end)

	ImGui.AddButton(parent_id, prefix .. "_Trigger", tr("传送：触发房", "Warp: trigger"), function()
		debug.goto_trigger()
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_R1", tr("传送：路线起点", "Warp: route start"), function()
		debug.goto_route_start()
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_RMid", tr("传送：路线中段", "Warp: route mid"), function()
		debug.goto_route_middle()
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_REnd", tr("传送：路线终点", "Warp: route end"), function()
		debug.goto_route_end()
	end)

	ImGui.AddButton(parent_id, prefix .. "_TLock", tr("终点门关", "Terminal locked"), function()
		local r = runtime.get()
		r.gate.unlocked = false
		debug.goto_terminal({ activate = true, unlock = false })
		r.gate.unlocked = false
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_TOpen", tr("终点门开", "Terminal open"), function()
		debug.goto_terminal({ activate = true, unlock = true })
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_TRev", tr("终点 Reveal", "Terminal Reveal"), function()
		debug.goto_terminal({ activate = true, force_reveal = true })
	end)

	ImGui.AddButton(parent_id, prefix .. "_Ante", tr("传送：前厅", "Warp: ante"), function()
		debug.goto_antechamber()
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_Flor", tr("传送：Floraine(无Boss)", "Warp: Floraine (no boss)"), function()
		debug.goto_floraine({ suppress_boss = true })
	end)

	ImGui.AddElement(
		parent_id, "", ImGuiElement.SeparatorText or ImGuiElement.Separator,
		tr("门动画预览", "Door animation preview")
	)
	local anims = { "Closed", "Open", "Opened", "Close", "Reveal" }
	for i, anim in ipairs(anims) do
		ImGui.AddButton(parent_id, prefix .. "_A_" .. anim, anim, function()
			debug.preview_door(DoorSlot.UP0, anim)
		end)
		if i < #anims then
			ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
		end
	end
	local slots = {
		{ DoorSlot.LEFT0, "L" },
		{ DoorSlot.UP0, "U" },
		{ DoorSlot.RIGHT0, "R" },
		{ DoorSlot.DOWN0, "D" },
	}
	for i, row in ipairs(slots) do
		ImGui.AddButton(parent_id, prefix .. "_S_" .. row[2], row[2], function()
			debug.preview_door(row[1], "Opened")
		end)
		if i < #slots then
			ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
		end
	end
end

function debug.build(parent_id)
	-- Backward-compatible: full advanced panel when mounted alone.
	debug.build_advanced(parent_id)
end

-- Story-test transport selectors
function debug.transport_selector(selector, opts)
	opts = opts or {}
	if selector == "stone_origin" or selector == "stone_trigger" then
		local ok, err = debug.goto_trigger()
		return ok, ok and "stone trigger" or err
	end
	if selector == "stone_route_start" then
		local ok, err = debug.goto_route_start()
		return ok, ok and "route start" or err
	end
	if selector == "stone_route_middle" then
		local ok, err = debug.goto_route_middle()
		return ok, ok and "route mid" or err
	end
	if selector == "stone_route_end" then
		local ok, err = debug.goto_route_end()
		return ok, ok and "route end" or err
	end
	if selector == "stone_terminal" then
		local ok, err = debug.goto_terminal({ activate = true, unlock = true })
		return ok, ok and "terminal" or err
	end
	if selector == "stone_antechamber" then
		local ok, err = debug.goto_antechamber()
		return ok, ok and "antechamber" or err
	end
	if selector == "stone_boss" or selector == "stone_floraine" then
		local ok, err = debug.goto_floraine({ suppress_boss = true })
		return ok, ok and "floraine" or err
	end
	return false, "unknown stone selector"
end

return debug
