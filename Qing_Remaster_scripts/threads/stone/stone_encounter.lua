-- Route encounters: door ENTER_ROOM initial + reinforcements; off-route pursuit.
-- Combat cadence is owned by chess_piece_director (Stone instance only).

local defs = require("Qing_Remaster_scripts.threads.stone.stone_defs")
local runtime = require("Qing_Remaster_scripts.threads.stone.stone_runtime")
local route = require("Qing_Remaster_scripts.threads.stone.stone_route")
local piece_defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")
local controller = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_controller")
local director = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_director")

local encounter = {}

-- Off-route pursuit: continuous but capped (not infinite pile / farm).
local OFFROUTE_MAX_ALIVE = 3
local OFFROUTE_INTERVAL_MIN = 150
local OFFROUTE_INTERVAL_SPAN = 90 -- + RandomInt → 150–240

local room_runtime = {
	sgi = nil,
	next_reinforce_frame = nil,
	alive_hashes = {},
	spawn_fail_streak = 0,
	entry_slot = nil,
	next_offroute_frame = nil,
	offroute_diag = nil,
}

local function room_key(sgi)
	return tostring(sgi)
end

local function ensure_encounter_bag()
	local r = runtime.get()
	r.encounters = r.encounters or {}
	return r.encounters
end

function encounter.get_room_state(sgi)
	sgi = sgi or (Game():GetLevel():GetCurrentRoomDesc() and Game():GetLevel():GetCurrentRoomDesc().SafeGridIndex)
	if sgi == nil then return nil end
	local bag = ensure_encounter_bag()
	local key = room_key(sgi)
	bag[key] = bag[key] or {
		activated = false,
		initial_spawned = false,
		reinforcements_spawned = 0,
		reinforcement_budget = 0,
		pending_reinforcements = {},
		pending_spawn = false,
		exhausted = false,
		defeated = false,
		resolved = false,
	}
	bag[key].pending_reinforcements = bag[key].pending_reinforcements or {}
	-- LEGACY field aliases kept readable for older StoneRun bags.
	if bag[key].reinforcements and not bag[key].reinforcements_spawned then
		bag[key].reinforcements_spawned = bag[key].reinforcements
	end
	return bag[key], key
end

local function progress_of_current()
	return route.get_progress()
end

local function budget_for_progress(p)
	if p < 0.2 then return {initial = 1, max_alive = 2, max_reinforcements = 2, kinds = {piece_defs.KIND.PAWN, piece_defs.KIND.KNIGHT}} end
	if p < 0.45 then return {initial = 2, max_alive = 3, max_reinforcements = 3, kinds = {piece_defs.KIND.PAWN, piece_defs.KIND.KNIGHT, piece_defs.KIND.VEHICLE}} end
	if p < 0.75 then return {initial = 2, max_alive = 3, max_reinforcements = 4, kinds = {piece_defs.KIND.VEHICLE, piece_defs.KIND.BISHOP, piece_defs.KIND.PAWN}} end
	return {initial = 3, max_alive = 4, max_reinforcements = 4, kinds = {piece_defs.KIND.QUEEN, piece_defs.KIND.BISHOP, piece_defs.KIND.VEHICLE, piece_defs.KIND.KING}}
end

--- Raw door-edge entry (no Occupancy search). Used by first-wave door_entry only.
local function raw_door_entry_pos(slot)
	if slot == nil then return nil end
	local room = Game():GetRoom()
	local door = room:GetDoor(slot)
	local pos
	if door then
		pos = door.Position
	else
		local center = room:GetCenterPos()
		if slot == DoorSlot.LEFT0 or slot == DoorSlot.LEFT1 then
			pos = Vector(room:GetTopLeftPos().X + 40, center.Y)
		elseif slot == DoorSlot.RIGHT0 or slot == DoorSlot.RIGHT1 then
			pos = Vector(room:GetBottomRightPos().X - 40, center.Y)
		elseif slot == DoorSlot.UP0 or slot == DoorSlot.UP1 then
			pos = Vector(center.X, room:GetTopLeftPos().Y + 40)
		else
			pos = Vector(center.X, room:GetBottomRightPos().Y - 40)
		end
	end
	local center = room:GetCenterPos()
	local delta = center - pos
	if delta:LengthSquared() < 1 then
		delta = Vector(0, 1)
	end
	-- Slightly inside the doorway; still door-adjacent for ENTER_ROOM start.
	local preferred = room:GetClampedPosition(pos + delta:Normalized() * 28, 16)
	return preferred
end

--- Reinforcement / debug: soft search near the outgoing door (may leave exact door edge).
local function door_spawn_pos(slot)
	local preferred = raw_door_entry_pos(slot)
	if not preferred then return nil end
	return controller.find_spawn_position({
		preferred_position = preferred,
		min_player_distance = 48,
		avoid_doors = false,
		avoid_entities = true,
	})
end

--- Actual entry door: nearest door to player on room enter (fallback: route incoming).
local function resolve_player_entry_slot(desc)
	local room = Game():GetRoom()
	local player = Game():GetPlayer(0)
	local best, best_d = nil, math.huge
	if player and DoorSlot and DoorSlot.NUM_DOOR_SLOTS then
		for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
			local door = room:GetDoor(slot)
			if door then
				local d = (player.Position - door.Position):LengthSquared()
				if d < best_d then
					best_d = d
					best = slot
				end
			end
		end
	end
	if best ~= nil and best_d <= (140 * 140) then
		return best, "player_near_door"
	end
	local incoming = route.get_incoming_slot(desc)
	if incoming ~= nil then
		return incoming, "route_incoming"
	end
	local outgoing = route.get_outgoing_slot(desc)
	if outgoing ~= nil then
		return outgoing, "route_outgoing_fallback"
	end
	return nil, "no_entry_door"
end

local function first_wave_land_pos(entry_pos)
	local room = Game():GetRoom()
	local center = room:GetCenterPos()
	local delta = center - entry_pos
	if delta:LengthSquared() < 1 then
		delta = Vector(0, 1)
	end
	local preferred = room:GetClampedPosition(entry_pos + delta:Normalized() * 72, 24)
	local land = controller.find_spawn_position({
		preferred_position = preferred,
		min_player_distance = 40,
		avoid_doors = true,
		avoid_entities = true,
	})
	if not land then
		return nil, "no_land"
	end
	if (land - entry_pos):LengthSquared() < (36 * 36) then
		return nil, "land_too_close"
	end
	return land
end

local function count_alive()
	local enums = require("Qing_Remaster_scripts.core.enums")
	local n = 0
	local hashes = {}
	for _, ent in ipairs(Isaac.FindByType(996, enums.Enemies.chess_piece, -1, false, false)) do
		local d = controller.get_data(ent)
		if d and d.role == piece_defs.ROLE.ROUTE_ENEMY and ent:Exists() and not ent:IsDead() then
			n = n + 1
			hashes[GetPtrHash(ent)] = true
		end
	end
	room_runtime.alive_hashes = hashes
	return n
end

local function pick_kind(rng, kinds)
	return kinds[(rng:RandomInt(#kinds)) + 1]
end

local function reinforce_load(state)
	return (state.reinforcements_spawned or 0) + #(state.pending_reinforcements or {})
end

local function ensure_director(state)
	if not director.is_enabled() or director.get_diag().id ~= director.ID_STONE then
		director.bind(director.ID_STONE)
	end
	if state then
		state.pending_reinforcements = state.pending_reinforcements or {}
		director.attach_reinforce_queue(state.pending_reinforcements)
	end
end

local function spawn_route_piece(kind, pos, mode, opts)
	opts = opts or {}
	local safe, why
	if opts.spawn_policy == "door_entry" then
		-- First-wave only: stay on the supplied door entry; never fall back to center.
		if not pos then
			return nil, "no_door_entry"
		end
		local room = Game():GetRoom()
		safe = room:GetClampedPosition(pos, 16)
		local occupancy = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_occupancy")
		local tok = select(1, occupancy.terrain_ok(safe, {
			room = room,
			avoid_doors = false,
			min_player_distance = 24,
		}))
		if not tok then
			return nil, "door_entry_blocked"
		end
	else
		safe, why = controller.find_spawn_position({
			preferred_position = pos,
			min_player_distance = 60,
			avoid_doors = true,
			avoid_entities = true,
		})
		if not safe then
			return nil, why or "no_spawn"
		end
	end
	local under_director = opts.skip_director ~= true
	if under_director then
		ensure_director(opts.state or encounter.get_room_state())
	end
	local ent = controller.spawn({
		kind = kind,
		role = piece_defs.ROLE.ROUTE_ENEMY,
		mode = mode or (under_director and piece_defs.MODE.DIRECTED or piece_defs.MODE.AUTONOMOUS),
		position = safe,
		director_id = under_director and director.ID_STONE or nil,
	})
	if ent and under_director then
		director.register(ent)
	end
	return ent
end

--- Unified door entry: spawn at door edge + ENTER_ROOM into interior (no center spawn).
--- opts.lane_index / lane_count: stagger landings so multi-spawn from one door does not stack.
local function spawn_enter_from_slot(kind, slot, state, rng, opts)
	opts = opts or {}
	local entry = raw_door_entry_pos(slot)
	if not entry then
		return nil, "no_door_entry"
	end
	local ent, why = spawn_route_piece(kind, entry, piece_defs.MODE.DIRECTED, {
		spawn_policy = "door_entry",
		state = state,
	})
	if not ent then
		return nil, why or "spawn_failed"
	end
	local room = Game():GetRoom()
	local land = first_wave_land_pos(entry)
	if not land then
		land = controller.find_spawn_position({
			preferred_position = entry + (room:GetCenterPos() - entry):Normalized() * (50 + (rng and rng:RandomInt(40) or 20)),
			min_player_distance = 40,
			avoid_doors = true,
		})
	end
	if not land then
		ent:Remove()
		return nil, "no_land"
	end
	local lane_n = tonumber(opts.lane_count) or 1
	local lane_i = tonumber(opts.lane_index) or 1
	if lane_n > 1 then
		local inward = room:GetCenterPos() - entry
		if inward:LengthSquared() < 1 then
			inward = Vector(0, 1)
		else
			inward = inward:Normalized()
		end
		local tangent = Vector(-inward.Y, inward.X)
		local mid = (lane_n + 1) * 0.5
		land = room:GetClampedPosition(land + tangent * ((lane_i - mid) * 28), 16)
	end
	local ok_cmd, cmd_why = controller.command(ent, {
		type = "ENTER_ROOM",
		destination = land,
		entry_position = entry,
		attack_enabled = false,
	})
	if not ok_cmd then
		ent:Remove()
		return nil, cmd_why or "enter_cmd_failed"
	end
	return ent, "ok"
end

local FIRST_WAVE_SECOND_GAP = 20
local FIRST_WAVE_ENTRY_CLEAR = 52

local function first_piece_cleared_entry(fw)
	if not fw or not fw.first_hash or not fw.entry_pos then
		return false
	end
	local enums = require("Qing_Remaster_scripts.core.enums")
	for _, ent in ipairs(Isaac.FindByType(996, enums.Enemies.chess_piece, -1, false, false)) do
		if GetPtrHash(ent) == fw.first_hash and ent:Exists() and not ent:IsDead() then
			return (ent.Position - fw.entry_pos):Length() >= FIRST_WAVE_ENTRY_CLEAR
		end
	end
	-- First piece gone: allow second to proceed.
	return true
end

--- Trigger-room first wave: sequential door entry under Stone Director (not try_start_room budget).
local function tick_first_wave(state, desc)
	if not state then return end
	local now = Game():GetFrameCount()

	if state.pending_first_wave and now >= (state.first_wave_frame or 0) then
		state.pending_first_wave = false
		if not route.is_trigger_room(desc) then
			state.first_wave_done = true
			state.first_wave_entry = nil
			return
		end
		local slot = route.get_outgoing_slot(desc)
		local entry = raw_door_entry_pos(slot)
		if not entry then
			-- Never spawn at room center; defer and keep trying.
			state.pending_first_wave = true
			state.first_wave_frame = now + 15
			state.first_wave_fail = "no_door_entry"
			return
		end
		state.first_wave_entry = {
			slot = slot,
			entry_pos = entry,
			phase = "spawn_first",
			second_due = nil,
			first_hash = nil,
			retry = 0,
		}
		state.first_wave_fail = nil
	end

	local fw = state.first_wave_entry
	if not fw then return end
	if not route.is_trigger_room(desc) then
		state.first_wave_done = true
		state.first_wave_entry = nil
		return
	end

	ensure_director(state)

	if fw.phase == "spawn_first" then
		local ent, why = spawn_route_piece(
			piece_defs.KIND.PAWN,
			fw.entry_pos,
			piece_defs.MODE.DIRECTED,
			{spawn_policy = "door_entry", state = state}
		)
		if not ent then
			fw.retry = (fw.retry or 0) + 1
			state.first_wave_fail = why or "spawn_first_failed"
			if fw.retry >= 12 then
				state.first_wave_done = true
				state.first_wave_entry = nil
			end
			return
		end
		local land, land_why = first_wave_land_pos(fw.entry_pos)
		if not land then
			ent:Remove()
			fw.retry = (fw.retry or 0) + 1
			state.first_wave_fail = land_why or "no_land"
			if fw.retry >= 12 then
				state.first_wave_done = true
				state.first_wave_entry = nil
			end
			return
		end
		controller.command(ent, {
			type = "ENTER_ROOM",
			destination = land,
			entry_position = fw.entry_pos,
			attack_enabled = false,
		})
		fw.first_hash = GetPtrHash(ent)
		fw.phase = "wait_second"
		fw.second_due = now + FIRST_WAVE_SECOND_GAP
		fw.retry = 0
		return
	end

	if fw.phase == "wait_second" then
		local due = now >= (fw.second_due or 0)
		if due or first_piece_cleared_entry(fw) then
			fw.phase = "spawn_second"
		end
		return
	end

	if fw.phase == "spawn_second" then
		local ent2, why = spawn_route_piece(
			piece_defs.KIND.PAWN,
			fw.entry_pos,
			piece_defs.MODE.DIRECTED,
			{spawn_policy = "door_entry", state = state}
		)
		if not ent2 then
			fw.retry = (fw.retry or 0) + 1
			state.first_wave_fail = why or "spawn_second_failed"
			if fw.retry >= 12 then
				state.first_wave_done = true
				state.first_wave_entry = nil
			end
			return
		end
		local land, land_why = first_wave_land_pos(fw.entry_pos)
		if not land then
			ent2:Remove()
			fw.retry = (fw.retry or 0) + 1
			state.first_wave_fail = land_why or "no_land"
			if fw.retry >= 12 then
				state.first_wave_done = true
				state.first_wave_entry = nil
			end
			return
		end
		controller.command(ent2, {
			type = "ENTER_ROOM",
			destination = land,
			entry_position = fw.entry_pos,
			attack_enabled = false,
		})
		state.first_wave_done = true
		state.first_wave_entry = nil
		state.activated = true
		state.initial_spawned = true
		state.first_wave_fail = nil
	end
end

function encounter.on_board_activated()
	local state = encounter.get_room_state()
	if state then
		if state.first_wave_done then
			return
		end
		state.pending_first_wave = true
		state.first_wave_frame = Game():GetFrameCount() + 130
	end
end

--- Interrupted activate: board on, expand/first-wave never finished. No re-shatter.
function encounter.ensure_bootstrap_after_interrupt()
	if not runtime.is_board_active() then
		return false, "inactive"
	end
	local board = require("Qing_Remaster_scripts.threads.stone.stone_board")
	local did = false
	if board.needs_expand_bootstrap() then
		board.ensure_bootstrap_from_activation()
		did = true
	end
	local state = encounter.get_room_state()
	if state and not state.first_wave_done and not state.pending_first_wave then
		encounter.on_board_activated()
		did = true
	end
	local r = runtime.get()
	if r.board and not r.board.bootstrap_complete then
		board.mark_bootstrap_complete()
		did = true
	end
	return did, did and "recovered" or "ok"
end

function encounter.try_start_room()
	if not runtime.is_board_active() then return end
	if not runtime.floor_matches() then return end
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if not desc then return end
	if not route.is_route_room(desc) then return end
	-- Trigger room first wave owns initial pieces; do not consume route initial budget.
	if route.is_trigger_room(desc) then return end
	local state = encounter.get_room_state(desc.SafeGridIndex)
	if state.defeated then
		return
	end
	-- Allow retry when activated but initial door spawn has not succeeded yet.
	if state.activated and state.initial_spawned then
		return
	end
	local budget = budget_for_progress(progress_of_current())
	if not state.activated then
		state.activated = true
		state.reinforcement_budget = budget.max_reinforcements
		state.reinforcements_spawned = 0
		state.pending_reinforcements = state.pending_reinforcements or {}
		state.exhausted = false
		state.pending_spawn = false
	end
	local rng = Game():GetPlayer(0):GetCollectibleRNG(CollectibleType.COLLECTIBLE_DADS_KEY)
	-- Correct-route initials / reinforce come from the forward exit (outgoing), NOT the door the player used.
	-- Player-entry door is reserved for off-route pursuit only.
	local spawn_slot = route.get_outgoing_slot(desc)
	room_runtime.offroute_diag = nil
	if spawn_slot == nil then
		-- Terminal / missing exit: do not invent a center spawn.
		state.initial_spawned = false
		Isaac.DebugString("[StoneEncounter] initial deferred: missing_outgoing_slot")
		room_runtime.sgi = desc.SafeGridIndex
		room_runtime.next_reinforce_frame = Game():GetFrameCount() + 90
		return
	end
	ensure_director(state)
	local spawned = 0
	local last_why = nil
	for i = 1, budget.initial do
		local ent, why = spawn_enter_from_slot(
			pick_kind(rng, budget.kinds),
			spawn_slot,
			state,
			rng,
			{lane_index = i, lane_count = budget.initial}
		)
		if ent then
			spawned = spawned + 1
		else
			last_why = why
		end
	end
	state.initial_spawned = spawned > 0
	if spawned == 0 then
		Isaac.DebugString(string.format(
			"[StoneEncounter] initial door spawn failed slot=%s why=%s",
			tostring(spawn_slot), tostring(last_why)
		))
	end
	room_runtime.sgi = desc.SafeGridIndex
	room_runtime.next_reinforce_frame = Game():GetFrameCount() + 180 + rng:RandomInt(180)
	room_runtime.spawn_fail_streak = 0
end

local function mark_exhausted(state)
	state.exhausted = true
	state.pending_spawn = #(state.pending_reinforcements or {}) > 0
end

--- Partial consume: success → confirm + spawned++; at cap → defer; fail → retry/drop without budget.
local function flush_pending_reinforcements(state, budget, slot, rng)
	if not director.in_settle_or_assemble() then
		return
	end
	ensure_director(state)
	local alive = count_alive()
	local budget_max = state.reinforcement_budget or budget.max_reinforcements
	while director.peek_reinforcement() do
		if alive >= budget.max_alive then
			director.defer_reinforcement()
			break
		end
		local spec = director.peek_reinforcement()
		local spawn_pos = (spec and spec.pos) or door_spawn_pos(slot)
		if not spawn_pos then
			local outcome = director.fail_reinforcement(5)
			if outcome == "retry" then
				break
			end
			-- dropped after retries: no reinforcements_spawned bump
		else
			local kind = (spec and spec.kind) or pick_kind(rng, budget.kinds)
			local ent = spawn_route_piece(kind, spawn_pos, piece_defs.MODE.DIRECTED, {state = state})
			if ent then
				director.confirm_reinforcement_spawned()
				state.reinforcements_spawned = (state.reinforcements_spawned or 0) + 1
				state.reinforcements = state.reinforcements_spawned
				local land = controller.find_spawn_position({
					preferred_position = spawn_pos + (Game():GetRoom():GetCenterPos() - spawn_pos):Normalized() * (50 + rng:RandomInt(40)),
					min_player_distance = 40,
					avoid_doors = true,
				}) or spawn_pos
				controller.command(ent, {type = "ENTER_ROOM", destination = land, attack_enabled = false})
				alive = alive + 1
			else
				local outcome = director.fail_reinforcement(5)
				if outcome == "retry" then
					break
				end
			end
		end
	end
	state.pending_spawn = director.has_pending_reinforcements()
	if (state.reinforcements_spawned or 0) >= budget_max and not state.pending_spawn then
		mark_exhausted(state)
	end
end

-- Encounter progress only (rewards / bookkeeping). Pieces use XML shutdoors
-- plus NPC CanShutDoors after :ToNPC(); this defeated flag must never hold doors.
local function try_mark_defeated(state, alive)
	if state.exhausted and not state.pending_spawn and alive == 0 then
		state.defeated = true
		state.resolved = true
		return true
	end
	return false
end

local function room_location(desc)
	local ok, rooms = pcall(require, "Qing_Remaster_scripts.threads.stone.stone_rooms")
	if ok and rooms and rooms.current_location then
		return rooms.current_location(desc)
	end
	if route.is_terminal_room(desc) then return "terminal" end
	if route.is_trigger_room(desc) then return "trigger" end
	if route.is_route_room(desc) then return "route" end
	return "other"
end

--- Wrong-route pursuit: from planned return_slot (toward main route), not player entry door.
local function tick_offroute_pursuit(state, desc)
	local loc = room_location(desc)
	if loc ~= "other" then
		return
	end
	-- Legacy / Continue: rebuild return table from saved main path if missing.
	do
		local ok_lay, lay = pcall(require, "Qing_Remaster_scripts.threads.stone.stone_layout")
		if ok_lay and lay and lay.ensure_offroute_returns then
			lay.ensure_offroute_returns()
		end
	end
	-- entry_slot kept for diagnostics only (does not choose spawn door).
	if room_runtime.entry_slot == nil then
		local slot, why = resolve_player_entry_slot(desc)
		room_runtime.entry_slot = slot
		room_runtime.offroute_diag = "entry_diag=" .. tostring(why or slot)
	end
	local off = route.get_offroute_info(desc)
	local return_slot = off and off.return_slot
	if return_slot == nil then
		room_runtime.offroute_diag = "no_return_slot"
		return
	end
	local rng = Game():GetPlayer(0):GetCollectibleRNG(CollectibleType.COLLECTIBLE_DADS_KEY)
	local now = Game():GetFrameCount()
	ensure_director(state)
	director.tick()
	local alive = count_alive()
	if alive >= OFFROUTE_MAX_ALIVE then
		return
	end
	if not room_runtime.next_offroute_frame then
		room_runtime.next_offroute_frame = now + OFFROUTE_INTERVAL_MIN + rng:RandomInt(OFFROUTE_INTERVAL_SPAN)
		return
	end
	if now < room_runtime.next_offroute_frame then
		return
	end
	local kinds = { piece_defs.KIND.PAWN, piece_defs.KIND.KNIGHT, piece_defs.KIND.VEHICLE }
	local ent, why = spawn_enter_from_slot(pick_kind(rng, kinds), return_slot, state, rng)
	if not ent then
		room_runtime.offroute_diag = why or "spawn_fail"
		room_runtime.next_offroute_frame = now + 60
		return
	end
	room_runtime.offroute_diag = string.format(
		"spawned return_slot=%s dist=%s next=%s join=%s",
		tostring(return_slot),
		tostring(off.distance_to_route),
		tostring(off.return_next_sgi),
		tostring(off.join_route_sgi)
	)
	room_runtime.next_offroute_frame = now + OFFROUTE_INTERVAL_MIN + rng:RandomInt(OFFROUTE_INTERVAL_SPAN)
end

function encounter.tick()
	if not runtime.is_board_active() then return end
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if not desc then return end
	local state = encounter.get_room_state(desc.SafeGridIndex)
	local loc = room_location(desc)

	-- First-wave entry runs for the trigger room even when Director route filters differ.
	tick_first_wave(state, desc)

	-- Trigger room: always tick Stone Director for first-wave (and survivors on re-entry).
	-- Do not run normal route initial/reinforce budgets here.
	if loc == "trigger" or route.is_trigger_room(desc) then
		ensure_director(state)
		director.tick()
		return
	end

	-- Ante / Floraine / special: no route or off-route pursuit.
	if loc == "ante" or loc == "floraine" then
		return
	end

	-- Wrong-route rooms: continuous pursuit from entry door (independent of route budgets).
	if loc == "other" then
		tick_offroute_pursuit(state, desc)
		return
	end

	if not route.is_route_room(desc) then return end
	if not state.activated or not state.initial_spawned then
		encounter.try_start_room()
		state = encounter.get_room_state(desc.SafeGridIndex)
	end
	if state.defeated then return end

	ensure_director(state)
	director.tick()

	local budget = budget_for_progress(progress_of_current())
	if (state.reinforcement_budget or 0) <= 0 then
		state.reinforcement_budget = budget.max_reinforcements
	end
	local alive = count_alive()
	local rng = Game():GetPlayer(0):GetCollectibleRNG(CollectibleType.COLLECTIBLE_DADS_KEY)

	-- Route reinforcements prefer outgoing (ahead). Terminal: no outgoing reinforce.
	local info = route.get_room_info(desc.SafeGridIndex)
	local slot = info and info.outgoing_slot
	if route.is_terminal_room(desc) or loc == "terminal" then
		slot = nil
	end

	flush_pending_reinforcements(state, budget, slot, rng)
	alive = count_alive()

	local budget_max = state.reinforcement_budget or budget.max_reinforcements
	local load = reinforce_load(state)
	if slot == nil then
		if not state.pending_spawn then
			mark_exhausted(state)
		end
		try_mark_defeated(state, alive)
		return
	end
	if load >= budget_max and not state.pending_spawn then
		mark_exhausted(state)
		try_mark_defeated(state, alive)
		return
	end

	if alive >= budget.max_alive then
		try_mark_defeated(state, alive)
		return
	end

	local now = Game():GetFrameCount()
	if not room_runtime.next_reinforce_frame or now < room_runtime.next_reinforce_frame then
		try_mark_defeated(state, alive)
		return
	end

	if reinforce_load(state) >= budget_max then
		try_mark_defeated(state, alive)
		return
	end

	-- Due: queue only (budget counted as queued load, spawned bumps on success).
	local spawn_pos = door_spawn_pos(slot)
	if not spawn_pos then
		room_runtime.spawn_fail_streak = (room_runtime.spawn_fail_streak or 0) + 1
		room_runtime.next_reinforce_frame = now + 60
		if room_runtime.spawn_fail_streak >= 5 then
			room_runtime.spawn_fail_streak = 0
			room_runtime.next_reinforce_frame = now + 180 + rng:RandomInt(120)
		end
		try_mark_defeated(state, alive)
		return
	end

	director.queue_reinforcement({
		kind = pick_kind(rng, budget.kinds),
		pos = spawn_pos,
	})
	state.pending_spawn = true
	room_runtime.spawn_fail_streak = 0
	room_runtime.next_reinforce_frame = now + 180 + rng:RandomInt(180)
	try_mark_defeated(state, count_alive())
end

function encounter.on_new_room()
	director.unbind()
	room_runtime.next_reinforce_frame = nil
	room_runtime.next_offroute_frame = nil
	room_runtime.sgi = nil
	room_runtime.spawn_fail_streak = 0
	room_runtime.entry_slot = nil
	room_runtime.offroute_diag = nil
	if runtime.is_board_active() and runtime.floor_matches() then
		local desc = Game():GetLevel():GetCurrentRoomDesc()
		local loc = desc and room_location(desc) or "other"
		if loc == "route" or loc == "terminal" then
			encounter.try_start_room()
		elseif loc == "other" then
			-- Capture entry door immediately for off-route pursuit.
			local slot = resolve_player_entry_slot(desc)
			room_runtime.entry_slot = slot
		end
		-- Re-bind survivors in route / trigger / off-route pursuit rooms.
		if desc and (route.is_route_room(desc) or route.is_trigger_room(desc) or loc == "other") then
			local state = encounter.get_room_state(desc.SafeGridIndex)
			ensure_director(state)
			local enums = require("Qing_Remaster_scripts.core.enums")
			for _, ent in ipairs(Isaac.FindByType(996, enums.Enemies.chess_piece, -1, false, false)) do
				local d = controller.get_data(ent)
				if d and d.role == piece_defs.ROLE.ROUTE_ENEMY and ent:Exists() and not ent:IsDead() then
					director.register(ent)
				end
			end
		end
	end
end

function encounter.debug_force_wave(kind)
	local pos = Game():GetRoom():GetCenterPos()
	-- Isolated spawn keeps autonomous AI (no Director bind).
	return spawn_route_piece(kind or piece_defs.KIND.PAWN, pos, piece_defs.MODE.AUTONOMOUS, {skip_director = true})
end

function encounter.debug_director()
	return director.get_diag()
end

function encounter.debug_director_round()
	ensure_director()
	director.request_round()
	return director.get_diag()
end

function encounter.debug_director_pause(v)
	director.set_paused(v == true)
	return director.get_diag()
end

function encounter.debug_director_tactic(name)
	director.force_tactic(name)
	return director.get_diag()
end

function encounter.debug_force_door_wave()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if not desc then return nil, "no_room" end
	local slot = route.get_outgoing_slot(desc)
	local pos = raw_door_entry_pos(slot)
	if not pos then
		return nil, "no_door_entry"
	end
	local ent = spawn_route_piece(piece_defs.KIND.PAWN, pos, piece_defs.MODE.DIRECTED, {
		spawn_policy = "door_entry",
	})
	if not ent then
		return nil, "no_spawn"
	end
	local land = first_wave_land_pos(pos)
	if not land then
		ent:Remove()
		return nil, "no_land"
	end
	controller.command(ent, {
		type = "ENTER_ROOM",
		destination = land,
		entry_position = pos,
		attack_enabled = false,
	})
	return ent, "ok"
end

function encounter.get_first_wave_diag()
	local state = encounter.get_room_state()
	if not state then
		return {ok = false, why = "no_state"}
	end
	local fw = state.first_wave_entry
	return {
		ok = true,
		pending = state.pending_first_wave == true,
		done = state.first_wave_done == true,
		fail = state.first_wave_fail,
		phase = fw and fw.phase or nil,
		second_due = fw and fw.second_due or nil,
		retry = fw and fw.retry or nil,
		has_entry = fw and fw.entry_pos ~= nil,
	}
end

function encounter.get_offroute_diag()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local off = desc and route.get_offroute_info(desc) or nil
	return {
		sgi = desc and desc.SafeGridIndex,
		entry_slot = room_runtime.entry_slot,
		return_slot = off and off.return_slot,
		return_next_sgi = off and off.return_next_sgi,
		distance_to_route = off and off.distance_to_route,
		join_route_sgi = off and off.join_route_sgi,
		join_route_order = off and off.join_route_order,
		next_frame = room_runtime.next_offroute_frame,
		diag = room_runtime.offroute_diag,
		max_alive = OFFROUTE_MAX_ALIVE,
		interval = { OFFROUTE_INTERVAL_MIN, OFFROUTE_INTERVAL_MIN + OFFROUTE_INTERVAL_SPAN },
	}
end

--- Debug: force one pursuit piece from return_slot (or fail with why).
function encounter.debug_force_offroute_pursuit()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if not desc then
		return nil, "no_room"
	end
	do
		local ok_lay, lay = pcall(require, "Qing_Remaster_scripts.threads.stone.stone_layout")
		if ok_lay and lay and lay.ensure_offroute_returns then
			lay.ensure_offroute_returns()
		end
	end
	local off = route.get_offroute_info(desc)
	if not off or off.return_slot == nil then
		return nil, "no_return_slot"
	end
	local state = encounter.get_room_state(desc.SafeGridIndex)
	local rng = Game():GetPlayer(0):GetCollectibleRNG(CollectibleType.COLLECTIBLE_DADS_KEY)
	local ent, why = spawn_enter_from_slot(piece_defs.KIND.PAWN, off.return_slot, state, rng)
	return ent, why or (ent and "ok")
end

function encounter.debug_clear_room_pieces()
	local enums = require("Qing_Remaster_scripts.core.enums")
	local n = 0
	for _, ent in ipairs(Isaac.FindByType(996, enums.Enemies.chess_piece, -1, false, false)) do
		local d = controller.get_data(ent)
		if d and d.role == piece_defs.ROLE.ROUTE_ENEMY then
			ent:Remove()
			n = n + 1
		end
	end
	return n
end

return encounter
