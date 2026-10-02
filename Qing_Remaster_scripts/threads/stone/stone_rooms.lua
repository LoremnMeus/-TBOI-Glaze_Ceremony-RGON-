-- Stone origin / terminal / antechamber / Floraine room logic (goto-based hidden chain).

local enums = require("Qing_Remaster_scripts.core.enums")
local defs = require("Qing_Remaster_scripts.threads.stone.stone_defs")
local runtime = require("Qing_Remaster_scripts.threads.stone.stone_runtime")
local route = require("Qing_Remaster_scripts.threads.stone.stone_route")
local grid_door = require("Qing_Remaster_scripts.grids.grid_doors")
local Screen_Filter = require("Qing_Remaster_scripts.others.Screen_Filter")

local rooms = {}

local ORIGIN_DATA = "StoneOriginPawn"
local PROMPT_R = 48

function rooms.marker_type()
	return defs.MARKER_RUNTIME_TYPE
end

function rooms.marker_variant()
	return enums.Entities.Stone_Room_Marker
end

function rooms.collect_markers(subtype)
	local out = {}
	local variant = rooms.marker_variant()
	if not variant then return out end
	for _, ent in ipairs(Isaac.FindByType(rooms.marker_type(), variant, subtype or -1, false, false)) do
		out[#out + 1] = ent
	end
	table.sort(out, function(a, b)
		if a.Position.Y ~= b.Position.Y then return a.Position.Y < b.Position.Y end
		return a.Position.X < b.Position.X
	end)
	return out
end

function rooms.first_marker(subtype)
	return rooms.collect_markers(subtype)[1]
end

function rooms.find_marker(subtype)
	return rooms.first_marker(subtype)
end

local function hide_marker(ent)
	if not ent then return end
	ent.Visible = false
	ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	ent:AddEntityFlags(EntityFlag.FLAG_NO_SPRITE_UPDATE | EntityFlag.FLAG_NO_TARGET)
end

function rooms.is_origin_room(desc)
	return route.is_trigger_room(desc)
end

function rooms.is_antechamber(desc)
	desc = desc or Game():GetLevel():GetCurrentRoomDesc()
	return desc and desc.Data and defs.is_ante_variant(desc.Data.Variant)
end

function rooms.is_floraine_room(desc)
	desc = desc or Game():GetLevel():GetCurrentRoomDesc()
	return desc and desc.Data and defs.is_floraine_variant(desc.Data.Variant)
end

local function place_players(pos)
	if not pos then return end
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if p then
			p.Position = pos
			p.Velocity = Vector.Zero
		end
	end
end

function rooms.entry_pos_floraine()
	local marker = rooms.find_marker(defs.MARKER.FLORAINE_ENTRY)
	if marker then return marker.Position end
	local room = Game():GetRoom()
	return room:GetClampedPosition(room:GetCenterPos() + Vector(0, 120), 20)
end

function rooms.entry_pos_ante()
	local marker = rooms.find_marker(defs.MARKER.PLAYER_ENTRY)
	if marker then return marker.Position end
	local room = Game():GetRoom()
	return room:GetClampedPosition(room:GetCenterPos() + Vector(0, 80), 20)
end

local function spawn_gate(slot, targ, playname, style)
	local room = Game():GetRoom()
	local anim = playname or "Opened"
	local need_update = anim ~= "Opened" and anim ~= "Closed"
	grid_door.try_spawn_grid_door(room, slot, nil, {
		check_and_leave = targ,
		loadname = defs.DOOR_ANM2,
		playname = anim,
		should_update = need_update,
		tp = RoomType.ROOM_DEFAULT,
		vr = nil,
		special_reminder = function()
			-- Target room positions players via room enter handlers.
			return 8
		end,
		on_update = need_update and function(doorinfo)
			local door = doorinfo.door
			if not door then return end
			local s = door:GetSprite()
			local name = s:GetAnimation()
			if s:IsFinished(name) then
				if name == "Reveal" or name == "Open" then
					s:Play("Opened", true)
					door.CollisionClass = GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER
				elseif name == "Close" then
					s:Play("Closed", true)
				end
			end
		end or nil,
		_stone_style = style,
	})
end

function rooms.spawn_terminal_gate(force_reveal)
	local r = runtime.get()
	if not r.terminal or not r.hidden then return end
	if not r.gate.unlocked then return end
	local slot = r.terminal.gate_slot
	if slot == nil then return end
	local anim = "Opened"
	if force_reveal or runtime.consume_gate_reveal_request() then
		anim = "Reveal"
	end
	spawn_gate(slot, defs.goto_default(r.hidden.ante_variant), anim, defs.DOOR_STYLE.ROUTE_GATE)
end

function rooms.spawn_ante_doors(boss_open)
	local r = runtime.get()
	if not r.hidden then return end
	local room = Game():GetRoom()
	-- Clear native doors; rebuild return + boss.
	for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
		room:RemoveDoor(slot)
	end
	-- Return: DOWN0 → back to terminal via ChangeRoom.
	local term_sgi = r.terminal and r.terminal.safe_grid_index
	grid_door.try_spawn_grid_door(room, DoorSlot.DOWN0, nil, {
		check_and_leave = function()
			if term_sgi then
				if REPENTOGON then
					Game():ChangeRoom(term_sgi)
				else
					Game():GetLevel():ChangeRoom(term_sgi)
				end
			end
		end,
		loadname = defs.DOOR_ANM2,
		playname = "Opened",
		should_update = false,
	})
	local boss_anim = boss_open and "Opened" or "Closed"
	local floraine = r.hidden.floraine_variant
	if boss_open then
		spawn_gate(DoorSlot.UP0, defs.goto_default(floraine), boss_anim, defs.DOOR_STYLE.BOSS_GATE)
	else
		grid_door.try_spawn_grid_door(Game():GetRoom(), DoorSlot.UP0, nil, {
			check_and_leave = function() end,
			loadname = defs.DOOR_ANM2,
			playname = "Closed",
			should_update = false,
			should_not_allow = true,
		})
	end
end

function rooms.open_ante_boss_gate()
	local r = runtime.get()
	if not r.hidden then return end
	spawn_gate(DoorSlot.UP0, defs.goto_default(r.hidden.floraine_variant), "Open", defs.DOOR_STYLE.BOSS_GATE)
end

--- Placeholder giant black pawn in trigger room (map-layer only).
function rooms.ensure_origin_placeholder()
	if runtime.is_board_active() then
		rooms.clear_origin_placeholder()
		return
	end
	if not route.is_trigger_room() then return end
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, -1, -1, false, false)) do
		if ent:GetData()[ORIGIN_DATA] then return end
	end
	local pos = Game():GetRoom():GetCenterPos()
	local marker = rooms.first_marker(defs.MARKER.ORIGIN_ANCHOR) or rooms.first_marker(defs.MARKER.CENTER)
	if marker then pos = marker.Position end
	-- Visible placeholder: invisible anchor + on-screen label (no Chess Piece entity —
	-- Floraine pawn AI would claim variant 23751).
	local ent = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BOMB_CRATER, 0, pos, Vector.Zero, nil)
	ent:GetData()[ORIGIN_DATA] = true
	ent.Visible = false
	ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
end

function rooms.clear_origin_placeholder()
	for _, ent in ipairs(Isaac.GetRoomEntities()) do
		if ent:GetData()[ORIGIN_DATA] then
			ent:Remove()
		end
	end
end

function rooms.try_activate_from_origin_kill(ent)
	if not ent or not ent:GetData()[ORIGIN_DATA] then return false end
	rooms.clear_origin_placeholder()
	return runtime.activate_board("origin_destroyed")
end

function rooms.tick_origin_prompt(player)
	if not player or runtime.is_board_active() then return end
	if not route.is_trigger_room() then return end
	local center = Game():GetRoom():GetCenterPos()
	if player.Position:Distance(center) > PROMPT_R then return end
	-- Production: only nearby bomb explosion shatters the placeholder.
	-- Debug activation stays on console / Story Test (`qing story stone activate`).
	for _, bomb in ipairs(Isaac.FindByType(EntityType.ENTITY_BOMB, -1, -1, false, false)) do
		local s = bomb:GetSprite()
		if bomb.Position:Distance(center) < 90
			and s and (s:IsPlaying("Explode") or s:IsFinished("Explode"))
		then
			rooms.clear_origin_placeholder()
			runtime.activate_board("origin_destroyed")
			return
		end
	end
end

function rooms.render_origin_label()
	if runtime.is_board_active() then return end
	if not route.is_trigger_room() then return end
	local font = Font()
	font:Load("font/pftempestasevencondensed.fnt")
	local pos = Isaac.WorldToScreen(Game():GetRoom():GetCenterPos() + Vector(0, -40))
	font:DrawStringScaledUTF8("[GIANT BLACK PAWN]\nBomb to shatter", pos.X - 40, pos.Y, 0.5, 0.5, KColor(1, 1, 1, 1), 0, false)
end

function rooms.on_enter_mines_room()
	local r = runtime.get()
	if not runtime.has_layout() or not runtime.floor_matches() then return end
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if route.is_trigger_room(desc) then
		if r.phase == defs.PHASE.LAYOUT_READY then
			runtime.set_phase(defs.PHASE.ORIGIN_FOUND)
		end
		rooms.ensure_origin_placeholder()
	end
	if runtime.is_board_active() then
		if route.is_route_room(desc) and not route.is_trigger_room(desc) then
			if r.phase == defs.PHASE.BOARD_ACTIVE then
				runtime.set_phase(defs.PHASE.APPROACHING)
			end
		end
		if route.is_terminal_room(desc) then
			runtime.set_phase(defs.PHASE.BOSS_READY)
			rooms.spawn_terminal_gate(false)
		end
	end
end

local ante_boss_open_frame = nil

function rooms.on_enter_antechamber()
	place_players(rooms.entry_pos_ante())
	Screen_Filter.add_filter(8)
	ante_boss_open_frame = Game():GetFrameCount() + 24
	rooms.spawn_ante_doors(false)
end

function rooms.tick_antechamber()
	if not rooms.is_antechamber() then return end
	if ante_boss_open_frame and Game():GetFrameCount() >= ante_boss_open_frame then
		ante_boss_open_frame = nil
		rooms.open_ante_boss_gate()
	end
end

function rooms.on_enter_floraine()
	runtime.set_phase(defs.PHASE.BOSS_ENTERED)
	place_players(rooms.entry_pos_floraine())
	Screen_Filter.add_filter(10)
	local room = Game():GetRoom()
	for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
		if room:GetDoor(slot) then
			room:RemoveDoor(slot)
		end
	end
	-- Return door to antechamber.
	local r = runtime.get()
	if r.hidden then
		spawn_gate(DoorSlot.DOWN0, defs.goto_default(r.hidden.ante_variant), "Opened", defs.DOOR_STYLE.ROUTE_GATE)
	end
end

function rooms.on_new_room()
	for _, ent in ipairs(rooms.collect_markers(-1)) do
		hide_marker(ent)
	end
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if not desc or not desc.Data then return end
	if rooms.is_antechamber(desc) then
		rooms.on_enter_antechamber()
		return
	end
	if rooms.is_floraine_room(desc) then
		rooms.on_enter_floraine()
		return
	end
	rooms.on_enter_mines_room()
end

return rooms
