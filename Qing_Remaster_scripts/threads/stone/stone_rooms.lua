-- Stone origin / terminal / antechamber / Floraine room logic (goto-based hidden chain).

local enums = require("Qing_Remaster_scripts.core.enums")
local defs = require("Qing_Remaster_scripts.threads.stone.stone_defs")
local runtime = require("Qing_Remaster_scripts.threads.stone.stone_runtime")
local route = require("Qing_Remaster_scripts.threads.stone.stone_route")
local grid_door = require("Qing_Remaster_scripts.grids.grid_doors")
local Screen_Filter = require("Qing_Remaster_scripts.others.Screen_Filter")

local rooms = {}

local origin_mod = require("Qing_Remaster_scripts.threads.stone.stone_origin")
local encounter_mod = require("Qing_Remaster_scripts.threads.stone.stone_encounter")
local board_mod = require("Qing_Remaster_scripts.threads.stone.stone_board")
local door_arrival = require("Qing_Remaster_scripts.threads.stone.stone_door_arrival")

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

local CELL = 40
local CARDINAL_OFFSETS = {
	{dx = 0, dy = -1},
	{dx = 0, dy = 1},
	{dx = -1, dy = 0},
	{dx = 1, dy = 0},
}

--- Giant-pawn live probe: center cell walkable + ≥1 free cardinal neighbor.
--- Does not require a full 3×3 clear. Does not destroy obstacles.
--- `radius_cells` is retained for API compatibility and ignored (legacy 3×3 callers).
function rooms.probe_anchor_clearance(pos, _radius_cells)
	local room = Game():GetRoom()
	pos = pos or room:GetCenterPos()
	local blocked = {}

	local function cell_free(dx, dy)
		local p = pos + Vector(dx * CELL, dy * CELL)
		local gidx = room:GetGridIndex(p)
		local coll = room:GetGridCollision(gidx)
		if coll ~= GridCollisionClass.COLLISION_NONE then
			blocked[#blocked + 1] = {x = dx, y = dy, gidx = gidx, coll = coll}
			return false
		end
		return true
	end

	if not cell_free(0, 0) then
		blocked[#blocked + 1] = {why = "center_blocked"}
		return false, blocked
	end

	local free_cardinal = false
	for _, off in ipairs(CARDINAL_OFFSETS) do
		if cell_free(off.dx, off.dy) then
			free_cardinal = true
			break
		end
	end
	if not free_cardinal then
		blocked[#blocked + 1] = {why = "no_free_cardinal"}
		return false, blocked
	end

	-- Doorway keep-clear: reject anchors too close to door mouths.
	for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
		local door = room:GetDoor(slot)
		if door and door.Position:Distance(pos) < 56 then
			blocked[#blocked + 1] = {door = slot, why = "near_door"}
			return false, blocked
		end
	end
	return true, blocked
end

--- Prefer marker / stored runtime anchor / room center, then spiral search.
--- Never deletes room obstacles. Returns pos, reason.
function rooms.find_safe_origin_anchor(opts)
	opts = opts or {}
	local room = Game():GetRoom()
	local r = runtime.get()
	local preferred = nil
	local marker = rooms.first_marker(defs.MARKER.ORIGIN_ANCHOR) or rooms.first_marker(defs.MARKER.CENTER)
	if marker then
		preferred = marker.Position
	elseif r.trigger and r.trigger.anchor then
		preferred = Vector(r.trigger.anchor.x, r.trigger.anchor.y)
	else
		preferred = room:GetCenterPos()
	end
	preferred = room:GetClampedPosition(preferred, 24)
	local ok = select(1, rooms.probe_anchor_clearance(preferred))
	if ok then
		return preferred, "preferred"
	end
	for ring = 1, 4 do
		for ang = 0, 7 do
			local a = ang * (math.pi / 4)
			local cand = room:GetClampedPosition(
				preferred + Vector(math.cos(a), math.sin(a)) * (ring * CELL),
				24
			)
			if select(1, rooms.probe_anchor_clearance(cand)) then
				return cand, "nearby_" .. tostring(ring)
			end
		end
	end
	-- Formal generation must not force a blocked preferred spot.
	if opts.allow_fallback then
		return preferred, "fallback_blocked"
	end
	return nil, "origin_no_safe_anchor"
end

--- Shared black-pawn anchor for placeholder / HUD. Does not claim blocked centers as safe.
function rooms.resolve_origin_anchor()
	local pos, why = rooms.find_safe_origin_anchor({ allow_fallback = false })
	if pos then
		local r = runtime.get()
		if r.trigger then
			r.trigger.anchor = {x = pos.X, y = pos.Y}
			r.trigger.anchor_reason = why
		end
		return pos
	end
	return Game():GetRoom():GetCenterPos()
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

--- Spatial location only. Does not rewrite progress phase.
function rooms.current_location(desc)
	desc = desc or Game():GetLevel():GetCurrentRoomDesc()
	if not desc or not desc.Data then return "other" end
	if rooms.is_antechamber(desc) then return "ante" end
	if rooms.is_floraine_room(desc) then return "floraine" end
	if route.is_terminal_room(desc) then return "terminal" end
	if route.is_trigger_room(desc) then return "trigger" end
	if route.is_route_room(desc) then return "route" end
	return "other"
end

--- Debug / marker fallback only — normal play uses stone_door_arrival.
function rooms.entry_pos_floraine()
	local pos = select(1, door_arrival.resolve_arrival_pos(DoorSlot.DOWN0))
	if pos then return pos end
	local room = Game():GetRoom()
	return room:GetClampedPosition(room:GetCenterPos() + Vector(0, 120), 20)
end

function rooms.entry_pos_ante()
	local pos = select(1, door_arrival.resolve_arrival_pos(DoorSlot.DOWN0))
	if pos then return pos end
	local room = Game():GetRoom()
	return room:GetClampedPosition(room:GetCenterPos() + Vector(0, 80), 20)
end

--- spawn_gate(slot, targ, playname, style, arrival_route_key)
local function spawn_gate(slot, targ, playname, style, arrival_route)
	local room = Game():GetRoom()
	local anim = playname or "Opened"
	local need_update = anim ~= "Opened" and anim ~= "Closed"
	local leave = targ
	if arrival_route then
		local r = runtime.get()
		local expect_variant = nil
		if arrival_route == "TERMINAL_TO_ANTE" or arrival_route == "FLORAINE_TO_ANTE" then
			expect_variant = r.hidden and r.hidden.ante_variant
		elseif arrival_route == "ANTE_TO_FLORAINE" then
			expect_variant = runtime.normalize_floraine_variant()
		end
		leave = door_arrival.wrap_leave(arrival_route, targ, {
			source_door_slot = slot,
			expect_variant = expect_variant,
		})
	end
	grid_door.try_spawn_grid_door(room, slot, nil, {
		check_and_leave = leave,
		loadname = defs.DOOR_ANM2,
		playname = anim,
		should_update = need_update,
		tp = RoomType.ROOM_DEFAULT,
		vr = nil,
		special_reminder = function()
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
	spawn_gate(
		slot,
		defs.goto_default(r.hidden.ante_variant),
		anim,
		defs.DOOR_STYLE.ROUTE_GATE,
		"TERMINAL_TO_ANTE"
	)
end

function rooms.spawn_ante_doors(boss_open)
	local r = runtime.get()
	if not r.hidden then return end
	local room = Game():GetRoom()
	for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
		room:RemoveDoor(slot)
	end
	local term_sgi = r.terminal and r.terminal.safe_grid_index
	local leave_terminal = door_arrival.wrap_leave("ANTE_TO_TERMINAL", function()
		if term_sgi then
			if REPENTOGON then
				Game():ChangeRoom(term_sgi)
			else
				Game():GetLevel():ChangeRoom(term_sgi)
			end
		end
	end, {
		source_door_slot = DoorSlot.DOWN0,
		expect_sgi = term_sgi,
	})
	grid_door.try_spawn_grid_door(room, DoorSlot.DOWN0, nil, {
		check_and_leave = leave_terminal,
		loadname = defs.DOOR_ANM2,
		playname = "Opened",
		should_update = false,
	})
	local floraine = runtime.normalize_floraine_variant()
	if boss_open then
		spawn_gate(
			DoorSlot.UP0,
			defs.goto_default(floraine),
			"Opened",
			defs.DOOR_STYLE.BOSS_GATE,
			"ANTE_TO_FLORAINE"
		)
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
	local floraine = runtime.normalize_floraine_variant()
	spawn_gate(
		DoorSlot.UP0,
		defs.goto_default(floraine),
		"Open",
		defs.DOOR_STYLE.BOSS_GATE,
		"ANTE_TO_FLORAINE"
	)
	runtime.mark_ante_boss_opened()
end

--- Replace the single planned center enemy (exact Type/Variant/Subtype near center). Once per run.
function rooms.apply_planned_enemy_replace()
	local r = runtime.get()
	local plan = r.trigger and r.trigger.replace_enemy
	if not plan or plan.done then
		return false, plan and "already" or "none"
	end
	if not route.is_trigger_room() then
		return false, "not_trigger"
	end
	local room = Game():GetRoom()
	local center = room:GetCenterPos()
	local want_t = tonumber(plan.type)
	local want_v = tonumber(plan.variant) or 0
	local want_s = tonumber(plan.subtype) or 0
	local best, best_d = nil, 1e9
	for _, ent in ipairs(Isaac.GetRoomEntities()) do
		if ent and ent:Exists() and not ent:IsDead()
			and ent.Type == want_t
			and ent.Variant == want_v
			and (ent.SubType or 0) == want_s then
			local d = ent.Position:Distance(center)
			if d < best_d then
				best_d = d
				best = ent
			end
		end
	end
	-- Must be near room center (3×3 cells ≈ 120px).
	if not best or best_d > 120 then
		return false, "target_missing"
	end
	best:Remove()
	plan.done = true
	return true, "replaced"
end

function rooms.ensure_origin_placeholder()
	origin_mod.cache_room_floor_tint()
	rooms.apply_planned_enemy_replace()
	origin_mod.ensure()
end

function rooms.clear_origin_placeholder()
	origin_mod.clear()
end

--- Safety net if NPC somehow dies; official path is finish_breaking at stage 3.
function rooms.try_activate_from_origin_kill(ent)
	if not origin_mod.is_giant_pawn_type(ent) then
		return false
	end
	return origin_mod.on_giant_pawn_death(ent)
end

--- Per-player prompt / input only. Scene logic lives in tick_scene.
function rooms.tick_origin_prompt(_player)
end

--- Room-level scene update: once per game frame (MC_POST_UPDATE / 30Hz).
function rooms.tick_scene()
	origin_mod.tick()
	-- Same-room interrupt recovery (activate succeeded, expand/first-wave never finished).
	if runtime.is_board_active() then
		local r = runtime.get()
		if r.board and r.board.bootstrap_complete ~= true then
			encounter_mod.ensure_bootstrap_after_interrupt()
		end
		board_mod.tick_expand()
	end
	encounter_mod.tick()
end

function rooms.render_origin_label()
	origin_mod.render()
end

function rooms.render_room_fx()
	local combat = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_combat")
	combat.tick_telegraphs()
	combat.render_telegraphs()
	local ok_ante, ante = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.ante_formation")
	if ok_ante and ante and ante.render then
		ante.render()
	end
	local ok_rv, rv = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_visual")
	if ok_rv and rv and rv.render then
		rv.render()
	end
end

function rooms.on_enter_mines_room()
	if not runtime.has_layout() or not runtime.floor_matches() then return end
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local location = rooms.current_location(desc)

	if location == "trigger" then
		runtime.advance_phase(defs.PHASE.ORIGIN_FOUND, "enter_trigger")
		rooms.ensure_origin_placeholder()
	end

	if not runtime.is_board_active() then return end

	if location == "route" then
		runtime.advance_phase(defs.PHASE.APPROACHING, "enter_route")
	elseif location == "terminal" then
		-- Progress only; revisiting terminal after BOSS_READY / BOSS_ENTERED must not regress.
		runtime.advance_phase(defs.PHASE.BOSS_READY, "enter_terminal")
		door_arrival.apply_if_pending()
		rooms.spawn_terminal_gate(false)
	end
	-- Returning to trigger after activation must not re-lock the board.
end

-- Short-lived open wait for ante UP boss gate. Persist on StoneRun.gate.ante_boss_opened.
-- Ante DOWN door stays Opened (players may return to terminal). Boss-room Close is arena.lua.
local ante_boss_open_frame = nil

local function find_grid_door_info(slot)
	local room = Game():GetRoom()
	local idx = room:GetGridIndex(room:GetDoorSlotPosition(slot))
	for _, v in ipairs(grid_door.doors or {}) do
		if v.idx == idx then
			return v
		end
	end
	return nil
end

function rooms.clear_ante_wait()
	ante_boss_open_frame = nil
end

function rooms.on_enter_antechamber()
	if not runtime.has_hidden_chain() then return end
	-- Only relocate when a Stone door transfer is pending (never a fixed center/marker).
	door_arrival.apply_if_pending()
	Screen_Filter.add_filter(8)
	if runtime.is_ante_boss_opened() then
		ante_boss_open_frame = nil
		rooms.spawn_ante_doors(true)
	else
		ante_boss_open_frame = Game():GetFrameCount() + 24
		rooms.spawn_ante_doors(false)
	end
	-- V2.2: dormant matte formation (scene only). Cleared when combat seals the arena.
	local ok, ante = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.ante_formation")
	if ok and ante and ante.spawn then
		ante.spawn()
	end
end

function rooms.tick_antechamber()
	if not rooms.is_antechamber() then
		rooms.clear_ante_wait()
		local ok, ante = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.ante_formation")
		if ok and ante and ante.is_active and ante.is_active() and ante.clear then
			ante.clear("left_ante")
		end
		return
	end
	if ante_boss_open_frame and Game():GetFrameCount() >= ante_boss_open_frame then
		ante_boss_open_frame = nil
		rooms.open_ante_boss_gate()
	end
	local ok, ante = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.ante_formation")
	if ok and ante and ante.tick then
		ante.tick()
	end
end

--- Debug: force ante DOWN door anim (must not confuse with Floraine-room door).
function rooms.debug_ante_door_anim(anim)
	anim = tostring(anim or "Opened")
	local info = find_grid_door_info(DoorSlot.DOWN0)
	if not info then
		return false, "no_down_door"
	end
	local door = Game():GetRoom():GetGridEntity(info.idx)
	if not door then
		return false, "no_grid"
	end
	door:GetSprite():Play(anim, true)
	local need_update = anim ~= "Opened" and anim ~= "Closed"
	info.should_update = need_update
	if anim == "Opened" or anim == "Open" then
		door.CollisionClass = GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER
	elseif anim == "Closed" or anim == "Close" then
		-- Debug only — production ante down door stays open for return travel.
		door.CollisionClass = GridCollisionClass.COLLISION_WALL
		info.targ = function() end
	end
	return true, anim
end

function rooms.on_enter_floraine()
	if not runtime.has_hidden_chain() then return end
	Screen_Filter.add_filter(10)
	-- Floraine V2 owns spawn, doors, intro, and combat.
	local ok, v2 = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.init")
	if ok and v2 and v2.on_enter_room then
		v2.on_enter_room()
		return
	end
	-- LEGACY fallback if V2 failed to load.
	runtime.advance_phase(defs.PHASE.BOSS_ENTERED, "enter_floraine")
	door_arrival.apply_if_pending()
	local room = Game():GetRoom()
	for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
		if room:GetDoor(slot) then
			room:RemoveDoor(slot)
		end
	end
	local r = runtime.get()
	if r.hidden then
		spawn_gate(
			DoorSlot.DOWN0,
			defs.goto_default(r.hidden.ante_variant),
			"Opened",
			defs.DOOR_STYLE.ROUTE_GATE,
			"FLORAINE_TO_ANTE"
		)
	end
end

function rooms.on_new_room()
	for _, ent in ipairs(rooms.collect_markers(-1)) do
		hide_marker(ent)
	end
	if board_mod.invalidate_owner_cache then
		board_mod.invalidate_owner_cache("new_room")
	end
	-- Restore expand first so mid-leave / expand_complete wins before bootstrap can begin.
	board_mod.restore_expand_from_run()
	-- Interrupted activate (board on, expand never started): repair without re-shatter.
	if runtime.is_board_active() then
		encounter_mod.ensure_bootstrap_after_interrupt()
	end
	encounter_mod.on_new_room()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if not desc or not desc.Data then
		rooms.clear_ante_wait()
		local ok, v2 = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.init")
		if ok and v2 and v2.on_leave_room then v2.on_leave_room() end
		return
	end
	if rooms.is_antechamber(desc) then
		local ok, v2 = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.init")
		if ok and v2 and v2.on_leave_room then v2.on_leave_room() end
		rooms.on_enter_antechamber()
		return
	end
	rooms.clear_ante_wait()
	if rooms.is_floraine_room(desc) then
		rooms.on_enter_floraine()
		return
	end
	local ok, v2 = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.init")
	if ok and v2 and v2.on_leave_room then v2.on_leave_room() end
	rooms.on_enter_mines_room()
end

return rooms
