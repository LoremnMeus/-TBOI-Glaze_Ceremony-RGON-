-- Unified chess piece controller: AUTONOMOUS / DIRECTED / SCRIPTED.
-- Occupancy: current cell + target reservation (room-local).

local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")
local motion = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_motion")
local visual = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_visual")
local combat = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_combat")
local occupancy = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_occupancy")
local afterimage = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_afterimage")

local controller = {}

local DATA_KEY = "QingChessPiece"
local next_command_serial = 1

local function ptr(ent)
	return GetPtrHash(ent)
end

local function data_of(ent)
	if not ent then return nil end
	local d = ent:GetData()
	local row = d[DATA_KEY]
	if type(row) ~= "table" then
		row = {}
		d[DATA_KEY] = row
	end
	return row
end

function controller.clear_room_occupancy()
	occupancy.clear()
	combat.clear_room()
end

-- LEGACY alias for callers still naming reservations.
function controller.clear_room_reservations()
	controller.clear_room_occupancy()
end

local function apply_combat_collision(ent, data)
	ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_PLAYEROBJECTS
	ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_WALLS
	if ent.CollisionDamage ~= nil then
		ent.CollisionDamage = 0
	end
	-- Door-lock: entities2 shutdoors="false" is the spawn default; pin on EntityNPC.
	-- Isaac.Spawn returns Entity — callers must :ToNPC() before this (see initialize/spawn).
	if ent.CanShutDoors ~= nil then
		ent.CanShutDoors = false
	end
end

local function resolve_policy(command)
	local p = command and (command.movement_policy or command.policy)
	if command and command.force == true and not p then
		-- LEGACY force=true → interrupt (busy only). Prefer explicit override for occupancy.
		p = defs.MOVEMENT_POLICY.INTERRUPT
	end
	if p == defs.MOVEMENT_POLICY.OVERRIDE or p == "override" then
		return defs.MOVEMENT_POLICY.OVERRIDE
	end
	if p == defs.MOVEMENT_POLICY.INTERRUPT or p == "interrupt" then
		return defs.MOVEMENT_POLICY.INTERRUPT
	end
	return defs.MOVEMENT_POLICY.NORMAL
end

local function snap_dest(pos)
	local room = Game():GetRoom()
	local snapped, gidx = occupancy.snap_world(pos, room)
	if gidx < 0 then
		return room:GetClampedPosition(pos, 20), -1
	end
	return snapped, gidx
end

--- Sliding pieces: path cells between start and end must be free (knight jumps over).
local function path_clear_from(self_id, start_pos, end_pos, kind, policy)
	local profile = defs.get(kind)
	local km = profile.motion or "short_hop"
	if km == "high_leap" or km == "short_hop" then
		return true
	end
	if policy == defs.MOVEMENT_POLICY.OVERRIDE then
		return true
	end
	local cells = combat.line_cells(start_pos, end_pos, defs.GRID)
	for i = 2, #cells - 1 do
		local ok, why = occupancy.can_enter(self_id, cells[i], {
			ignore_occupancy = false,
			allow_self = true,
		})
		if not ok and why ~= "oob" then
			local room = Game():GetRoom()
			local gidx = room:GetGridIndex(cells[i])
			if room:GetGridCollision(gidx) ~= GridCollisionClass.COLLISION_NONE then
				return false, "path_blocked"
			end
			if why == "occupied" or why == "reserved" then
				return false, "path_occupied"
			end
		end
	end
	return true
end

local function path_clear(ent, start_pos, end_pos, kind, policy)
	return path_clear_from(ptr(ent), start_pos, end_pos, kind, policy)
end

function controller.find_spawn_position(opts)
	opts = opts or {}
	local room = opts.room or Game():GetRoom()
	local preferred = opts.preferred_position or room:GetCenterPos()
	local min_player = opts.min_player_distance or 60
	local g = defs.GRID
	local candidates = {preferred}
	for r = 1, 4 do
		local dist = r * g
		for ang = 0, 7 do
			local a = ang * (math.pi / 4)
			candidates[#candidates + 1] = preferred + Vector(math.cos(a), math.sin(a)) * dist
		end
	end
	for _, raw in ipairs(candidates) do
		local pos = select(1, snap_dest(raw))
		local tok = select(1, occupancy.terrain_ok(pos, {
			room = room,
			avoid_doors = opts.avoid_doors ~= false,
			min_player_distance = min_player,
		}))
		local free = tok and select(1, occupancy.can_enter(nil, pos, {
			ignore_occupancy = false,
			allow_self = true,
		}))
		local entity_ok = true
		if free and opts.avoid_entities ~= false then
			for _, ent in ipairs(Isaac.FindInRadius(pos, 28, EntityPartition.ENEMY)) do
				if ent:Exists() and not ent:IsDead() then
					entity_ok = false
					break
				end
			end
		end
		if free and entity_ok then
			return pos, "ok"
		end
	end
	-- No silent occupied fallback — caller must decide.
	return nil, "no_spawn"
end

local ROOK_DIRS = {
	Vector(1, 0), Vector(-1, 0), Vector(0, 1), Vector(0, -1),
}
local BISHOP_DIRS = {
	Vector(1, 1), Vector(1, -1), Vector(-1, 1), Vector(-1, -1),
}
local MAX_RAY_STEPS = 14

local function sliding_dirs(kind)
	if kind == defs.KIND.VEHICLE then
		return ROOK_DIRS
	elseif kind == defs.KIND.BISHOP then
		return BISHOP_DIRS
	elseif kind == defs.KIND.QUEEN then
		local dirs = {}
		for i = 1, #ROOK_DIRS do dirs[#dirs + 1] = ROOK_DIRS[i] end
		for i = 1, #BISHOP_DIRS do dirs[#dirs + 1] = BISHOP_DIRS[i] end
		return dirs
	end
	return nil
end

local function fixed_offsets(kind)
	local g = defs.GRID
	if kind == defs.KIND.KNIGHT then
		return {
			Vector(2 * g, g), Vector(2 * g, -g), Vector(-2 * g, g), Vector(-2 * g, -g),
			Vector(g, 2 * g), Vector(g, -2 * g), Vector(-g, 2 * g), Vector(-g, -2 * g),
		}
	end
	-- King / Pawn / fallback: adjacent 1 cell.
	return {
		Vector(g, 0), Vector(-g, 0), Vector(0, g), Vector(0, -g),
		Vector(g, g), Vector(g, -g), Vector(-g, g), Vector(-g, -g),
	}
end

--- Legal landings from an arbitrary board position (Director threat probes).
function controller.legal_landings_at(from_pos, kind, self_id)
	local out = {}
	if not from_pos then
		return out
	end
	kind = tonumber(kind) or defs.KIND.PAWN
	from_pos = select(1, snap_dest(from_pos))
	local dirs = sliding_dirs(kind)
	if dirs then
		local g = defs.GRID
		for _, dir in ipairs(dirs) do
			local prev_gidx = nil
			for n = 1, MAX_RAY_STEPS do
				local raw = from_pos + Vector(dir.X * g * n, dir.Y * g * n)
				local dest, gidx = snap_dest(raw)
				if gidx < 0 or gidx == prev_gidx then
					break
				end
				prev_gidx = gidx
				local ok = select(1, occupancy.can_enter(self_id, dest, {}))
				if not ok then
					break
				end
				local path_ok = path_clear_from(self_id, from_pos, dest, kind, defs.MOVEMENT_POLICY.NORMAL)
				if not path_ok then
					break
				end
				out[#out + 1] = dest
			end
		end
		return out
	end
	for _, off in ipairs(fixed_offsets(kind)) do
		local dest = select(1, snap_dest(from_pos + off))
		local ok = select(1, occupancy.can_enter(self_id, dest, {}))
		if ok then
			local path_ok = path_clear_from(self_id, from_pos, dest, kind, defs.MOVEMENT_POLICY.NORMAL)
			if path_ok then
				out[#out + 1] = dest
			end
		end
	end
	return out
end

function controller.legal_landings(ent, kind)
	if not ent then
		return {}
	end
	local data = data_of(ent)
	kind = kind or (data and data.kind) or defs.KIND.PAWN
	return controller.legal_landings_at(ent.Position, kind, ptr(ent))
end

function controller.initialize(ent, spec)
	if not ent then return nil end
	-- NPC-only members (e.g. CanShutDoors). Local rebind does not change caller's wrapper.
	ent = ent:ToNPC()
	if not ent then return nil end
	spec = spec or {}
	local data = data_of(ent)
	if data.kind and not spec.force then
		apply_combat_collision(ent, data)
		return data
	end
	local kind = tonumber(spec.kind or ent.SubType) or defs.KIND.PAWN
	if kind < 1 or kind > 6 then kind = defs.KIND.PAWN end
	local profile = visual.apply_sheet(ent, kind)
	data.kind = kind
	data.role = spec.role or defs.ROLE.COMBAT
	data.control_mode = spec.mode or defs.MODE.AUTONOMOUS
	data.action_state = spec.action_state or "SPAWNING"
	data.current_command = nil
	data.command_elapsed = 0
	data.phase_elapsed = 0
	data.start_position = Vector(ent.Position.X, ent.Position.Y)
	data.landing_position = nil
	data.visual_height = 0
	data.visual_tilt = 0
	data.visual_scale = spec.scale or 1
	data.director_id = spec.director_id
	data.forward_axis = spec.forward_axis
	data.contact_damage = profile.contact_damage or 1
	data.attack_active = false
	data.damageable = spec.damageable ~= false
	data.spawn_frame = Game():GetFrameCount()
	ent.HitPoints = profile.hp or ent.HitPoints
	ent.MaxHitPoints = profile.hp or ent.MaxHitPoints
	apply_combat_collision(ent, data)
	ent:AddEntityFlags(EntityFlag.FLAG_NO_STATUS_EFFECTS)
	if spec.skip_occupancy ~= true then
		local ok, a, b = occupancy.register_current(ptr(ent), ent.Position, {})
		if ok and b then
			ent.Position = b
			data.current_grid = a
		elseif not ok then
			data.occupancy_why = a
		end
	else
		data.occupancy_deferred = true
	end
	return data
end

function controller.spawn(spec)
	spec = spec or {}
	local kind = tonumber(spec.kind) or defs.KIND.PAWN
	if type(spec.kind) == "string" then
		for id, name in pairs(defs.KIND_NAME) do
			if name == spec.kind then kind = id break end
		end
	end
	local pos = spec.position or Game():GetRoom():GetCenterPos()
	pos = select(1, snap_dest(pos))
	local ent = Isaac.Spawn(996, enums.Enemies.chess_piece, kind, pos, spec.vel or Vector.Zero, spec.spawner):ToNPC()
	if not ent then
		return nil, "spawn_not_npc"
	end
	-- Deployment handoff already played lift/transfer/land; never replay native Appear.
	if spec.no_appear then
		ent:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
	end
	local data = controller.initialize(ent, {
		kind = kind,
		role = spec.role,
		mode = spec.mode,
		director_id = spec.director_id,
		forward_axis = spec.forward_axis,
		scale = spec.scale,
		damageable = spec.damageable,
		skip_occupancy = spec.skip_occupancy == true,
		force = true,
	})
	if not data then
		return nil, "init_failed"
	end
	if spec.no_appear then
		ent:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
		local s = ent:GetSprite()
		if s then
			s:Play("Idle", true)
		end
	end
	data.action_state = "IDLE"
	return ent, data
end

function controller.get_data(ent)
	return data_of(ent)
end

function controller.set_control_mode(ent, mode)
	local data = data_of(ent)
	if not data then return false, "no_data" end
	data.control_mode = mode or defs.MODE.AUTONOMOUS
	return true
end

function controller.is_busy(ent)
	local data = data_of(ent)
	if not data then return false end
	local st = data.action_state
	return st == "WINDUP" or st == "MOVING" or st == "ATTACKING" or st == "LANDING"
		or st == "SPAWNING" or st == "ROYAL_DROP"
end

function controller.get_status(ent)
	local data = data_of(ent)
	if not data then return nil end
	local row = occupancy.get_piece(ptr(ent))
	return {
		kind = data.kind,
		role = data.role,
		control_mode = data.control_mode,
		action_state = data.action_state,
		command = data.current_command and data.current_command.type,
		attack_active = data.attack_active == true,
		director_id = data.director_id,
		current_index = row and row.current_index,
		target_index = row and row.target_index,
	}
end

local function apply_move_acceptance(ent, data, dest_pos, dest_gidx, opts)
	opts = opts or {}
	data.reservation_id = dest_gidx
	data.start_position = Vector(ent.Position.X, ent.Position.Y)
	data.landing_position = dest_pos
	data.phase_elapsed = 0
	data.action_state = "WINDUP"
	data.move_is_attack = opts.attack == true
	data.attack_enabled = opts.attack_enabled ~= false
	data.movement_policy = opts.policy or defs.MOVEMENT_POLICY.NORMAL
	data.task = opts.task
	if opts.travel_frames ~= nil then
		data.travel_frames_override = math.max(3, math.floor(tonumber(opts.travel_frames) or 3))
	else
		data.travel_frames_override = defs.travel_frames_for(data.kind, data.start_position, dest_pos)
	end
	-- Spread afterimage samples along long dashes (not clustered at the start).
	local travel_len = (dest_pos - data.start_position):Length()
	local profile = defs.get(data.kind)
	local cap = math.max(2, math.min(4, tonumber(profile.afterimage_count) or 3))
	data._ai_min_dist = math.max(10, travel_len / (cap + 1))
	data._land_fx_id = (data._land_fx_id or 0) + 1
	data.landing_sound_token = data._land_fx_id
	data._land_sound_played = nil
	afterimage.clear(data)
	combat.begin_attack(data)
end

local function begin_move(ent, data, dest, opts)
	opts = opts or {}
	local policy = opts.policy or defs.MOVEMENT_POLICY.NORMAL
	dest = select(1, snap_dest(dest))
	local self_id = ptr(ent)
	local ignore = policy == defs.MOVEMENT_POLICY.OVERRIDE
	if not opts.skip_path then
		local path_ok, path_why = path_clear(ent, ent.Position, dest, data.kind, policy)
		if not path_ok then
			return false, path_why
		end
	end
	if opts.precommitted then
		-- Target already stamped by occupancy.commit_group_moves.
		local gidx = opts.precommitted_gidx or select(2, snap_dest(dest))
		apply_move_acceptance(ent, data, dest, gidx, {
			attack = opts.attack,
			attack_enabled = opts.attack_enabled,
			policy = policy,
			travel_frames = opts.travel_frames,
			task = opts.task,
		})
		return true, "accepted"
	end
	next_command_serial = next_command_serial + 1
	local ok, why_or_gidx, snap = occupancy.commit_move(self_id, dest, {
		ignore_occupancy = ignore,
		command_id = next_command_serial,
	})
	if not ok then
		return false, why_or_gidx
	end
	apply_move_acceptance(ent, data, snap or dest, why_or_gidx, {
		attack = opts.attack,
		attack_enabled = opts.attack_enabled,
		policy = policy,
		travel_frames = opts.travel_frames,
	})
	return true, "accepted"
end

function controller.command(ent, command)
	local data = data_of(ent)
	if not data then return false, "no_data" end
	command = command or {}
	local ctype = command.type
	local policy = resolve_policy(command)

	if ctype == "SET_MODE" then
		return controller.set_control_mode(ent, command.mode)
	end
	if ctype == "WAIT" then
		data.current_command = command
		data.action_state = "IDLE"
		data.phase_elapsed = 0
		return true, "accepted"
	end
	if ctype == "FACE" then
		if command.facing then
			data.forward_axis = command.facing
		end
		return true, "accepted"
	end
	if ctype == "DISAPPEAR" then
		occupancy.unregister(ptr(ent))
		ent:Remove()
		return true, "completed"
	end

	if controller.is_busy(ent) then
		if policy == defs.MOVEMENT_POLICY.NORMAL then
			return false, "busy"
		end
		-- interrupt / override: cancel current move occupancy then continue.
		occupancy.resync(ptr(ent), ent.Position, {
			allow_conflict = policy == defs.MOVEMENT_POLICY.OVERRIDE,
		})
		data.action_state = "IDLE"
		data.current_command = nil
		combat.set_active(data, false)
		visual.clear_tint(ent)
	end

	if ctype == "APPEAR" or ctype == "ENTER_ROOM" or ctype == "MOVE" or ctype == "ATTACK" then
		local dest = command.destination or command.target
		if dest and dest.X == nil and dest.Position then
			local landings = controller.legal_landings(ent, data.kind)
			local best = ent.Position
			local best_d = 1e12
			for _, p in ipairs(landings) do
				local d2 = (p - dest.Position):LengthSquared()
				if d2 < best_d then best_d = d2 best = p end
			end
			dest = best
		elseif dest == nil and ctype == "ATTACK" then
			local target = auxi.get_acceptible_target(ent)
			if not target then return false, "invalid_target" end
			local landings = controller.legal_landings(ent, data.kind)
			if #landings < 1 then return false, "blocked" end
			local best = landings[1]
			local best_d = (best - target.Position):LengthSquared()
			for i = 2, #landings do
				local d2 = (landings[i] - target.Position):LengthSquared()
				if d2 < best_d then best_d = d2 best = landings[i] end
			end
			dest = best
		end
		if not dest then return false, "invalid_target" end
		if ctype == "ENTER_ROOM" then
			dest = select(1, snap_dest(dest))
			local entry = command.entry_position
			if entry then
				if (dest - entry):LengthSquared() < (36 * 36) then
					return false, "entry_equals_land"
				end
			end
			local land_ok, land_why = occupancy.can_enter(ptr(ent), dest, {
				ignore_occupancy = false,
				allow_self = true,
			})
			if not land_ok then
				return false, land_why or "land_occupied"
			end
		end
		data.current_command = command
		data.control_mode = data.control_mode or defs.MODE.DIRECTED
		if ctype == "ENTER_ROOM" then
			data.control_mode = defs.MODE.DIRECTED
		end
		return begin_move(ent, data, dest, {
			attack = ctype == "ATTACK",
			attack_enabled = command.attack_enabled ~= false and ctype ~= "ENTER_ROOM",
			policy = policy,
			task = command.task,
			travel_frames = command.travel_frames,
		})
	end
	return false, "unknown"
end

--- Batch command: two-phase — plan all (with swap vacate), then atomic commit.
-- Any failure → no piece starts moving.
function controller.command_group(entries, opts)
	opts = opts or {}
	local policy = resolve_policy(opts)
	entries = entries or {}
	local planned = {}
	for _, e in ipairs(entries) do
		local ent = e.piece or e.ent
		if ent and ent:Exists() then
			local data = data_of(ent)
			local dest = e.destination or e.target
			if data and dest then
				dest = select(1, snap_dest(dest))
				planned[#planned + 1] = {ent = ent, data = data, dest = dest, command = e}
			end
		end
	end
	if #planned < 1 then return false, "empty" end

	-- Busy gate before any occupancy mutation.
	for _, row in ipairs(planned) do
		if controller.is_busy(row.ent) then
			if policy == defs.MOVEMENT_POLICY.NORMAL then
				return false, "busy"
			end
		end
	end

	-- Interrupt busy members first (resync only; no begin_move yet).
	if policy ~= defs.MOVEMENT_POLICY.NORMAL then
		for _, row in ipairs(planned) do
			if controller.is_busy(row.ent) then
				occupancy.resync(ptr(row.ent), row.ent.Position, {
					allow_conflict = policy == defs.MOVEMENT_POLICY.OVERRIDE,
				})
				row.data.action_state = "IDLE"
				row.data.current_command = nil
				combat.set_active(row.data, false)
				visual.clear_tint(row.ent)
			end
		end
	end

	-- Path checks with vacating set (other movers' current cells free for path).
	local vacating_current = {}
	for _, row in ipairs(planned) do
		local prow = occupancy.get_piece(ptr(row.ent))
		if prow and prow.current_index then
			vacating_current[prow.current_index] = ptr(row.ent)
		end
	end
	if policy ~= defs.MOVEMENT_POLICY.OVERRIDE then
		for _, row in ipairs(planned) do
			local profile = defs.get(row.data.kind)
			local km = profile.motion or "short_hop"
			if km ~= "high_leap" and km ~= "short_hop" then
				local cells = combat.line_cells(row.ent.Position, row.dest, defs.GRID)
				for i = 2, #cells - 1 do
					local room = Game():GetRoom()
					local gidx = room:GetGridIndex(cells[i])
					if room:GetGridCollision(gidx) ~= GridCollisionClass.COLLISION_NONE then
						return false, "path_blocked"
					end
					local st = occupancy.get_state()
					local cur = st.current[gidx]
					if cur and cur ~= ptr(row.ent) and vacating_current[gidx] ~= cur then
						return false, "path_occupied"
					end
					local tgt = st.target[gidx]
					if tgt and tgt ~= ptr(row.ent) and not vacating_current[gidx] then
						-- Outside reservation blocks path unless it's a vacating current cell.
						local blocking = true
						for _, other in ipairs(planned) do
							if ptr(other.ent) == tgt then blocking = false break end
						end
						if blocking then
							return false, "path_reserved"
						end
					end
				end
			end
		end
	end

	local move_specs = {}
	for _, row in ipairs(planned) do
		move_specs[#move_specs + 1] = {
			piece_id = ptr(row.ent),
			destination = row.dest,
		}
	end
	local ok_plan, why_plan, resolved = occupancy.plan_group_moves(move_specs, {
		ignore_occupancy = policy == defs.MOVEMENT_POLICY.OVERRIDE,
	})
	if not ok_plan then
		return false, why_plan or "blocked"
	end

	next_command_serial = next_command_serial + 1
	local ok_commit = occupancy.commit_group_moves(resolved, {
		command_id = next_command_serial,
	})
	if not ok_commit then
		return false, "commit_failed"
	end

	-- Map piece_id → resolved row for acceptance.
	local by_id = {}
	for _, r in ipairs(resolved) do
		by_id[r.piece_id] = r
	end

	local results = {}
	for _, row in ipairs(planned) do
		local id = ptr(row.ent)
		local res = by_id[id]
		local cmd = row.command or {}
		cmd.type = cmd.type or "MOVE"
		cmd.destination = row.dest
		cmd.movement_policy = policy
		row.data.current_command = cmd
		begin_move(row.ent, row.data, res.pos, {
			attack = cmd.type == "ATTACK",
			attack_enabled = cmd.attack_enabled ~= false and cmd.type ~= "ENTER_ROOM",
			policy = policy,
			precommitted = true,
			precommitted_gidx = res.gidx,
			skip_path = true,
			task = cmd.task,
		})
		results[#results + 1] = {ok = true, why = "accepted", ent = row.ent}
	end
	return true, results
end

function controller.interrupt(ent, reason)
	local data = data_of(ent)
	if not data then return false end
	occupancy.resync(ptr(ent), ent.Position, {})
	combat.clear_telegraph(ptr(ent))
	combat.set_active(data, false)
	data.current_command = nil
	data.action_state = "IDLE"
	data.visual_height = 0
	data.visual_tilt = 0
	data.interrupt_reason = reason
	visual.apply_pose(ent, data)
	return true
end

local function finish_move(ent, data)
	local allow_conflict = data.movement_policy == defs.MOVEMENT_POLICY.OVERRIDE
	occupancy.finish_move(ptr(ent), {
		pos = data.landing_position or ent.Position,
		allow_conflict = allow_conflict,
	})
	if data.landing_position then
		ent.Position = data.landing_position
	end
	data.visual_height = 0
	data.visual_tilt = 0
	combat.set_active(data, false)
	if data.move_is_attack and data.attack_enabled then
		combat.set_active(data, true)
		combat.try_hit_players(ent, data, data.kind == defs.KIND.KING and 36 or 24)
		combat.set_active(data, false)
	end
	data.action_state = "RECOVERY"
	data.phase_elapsed = 0
	local cmd = data.current_command
	if cmd and cmd.on_complete then
		pcall(cmd.on_complete, ent, data)
	end
	if cmd and cmd.type == "ENTER_ROOM" then
		-- Stay under Director when registered; otherwise resume autonomous debug AI.
		if data.director_bound then
			controller.set_control_mode(ent, defs.MODE.DIRECTED)
		else
			controller.set_control_mode(ent, defs.MODE.AUTONOMOUS)
		end
	end
	data.current_command = nil
	data.movement_policy = nil
	data.travel_frames_override = nil
	data._ai_min_dist = nil
end

local function tick_action(ent, data)
	local profile = defs.get(data.kind)
	data.phase_elapsed = (data.phase_elapsed or 0) + 1
	local st = data.action_state
	-- P1 重落子: motion owned by floraine_v2.royal_drop (still apply pose each frame).
	if st == "ROYAL_DROP" or data.royal_drop then
		visual.apply_pose(ent, data)
		return
	end
	if st == "WINDUP" then
		local t = motion.lerp_frames(data.phase_elapsed, profile.windup_frames)
		local _, height, tilt = motion.sample(profile, data.start_position, data.landing_position or ent.Position, t, "WINDUP")
		data.visual_height = height
		data.visual_tilt = tilt
		visual.flash_tint(ent, 0.25 * t)
		if data.phase_elapsed >= profile.windup_frames then
			data.action_state = data.move_is_attack and "ATTACKING" or "MOVING"
			data.phase_elapsed = 0
			combat.set_active(data, data.move_is_attack and data.attack_enabled == true)
			visual.clear_tint(ent)
		end
	elseif st == "MOVING" or st == "ATTACKING" then
		local travel = data.travel_frames_override or profile.travel_frames
		local t = motion.lerp_frames(data.phase_elapsed, travel)
		local pos, height, tilt = motion.sample(profile, data.start_position, data.landing_position or ent.Position, t, st)
		ent.Position = pos
		ent.Velocity = Vector.Zero
		data.visual_height = height
		data.visual_tilt = tilt
		if data.attack_active then
			combat.try_hit_players(ent, data, 20)
		end
		if data.phase_elapsed >= travel then
			data.action_state = "LANDING"
			data.phase_elapsed = 0
		end
	elseif st == "LANDING" then
		local land_frames = math.max(1, profile.land_frames or 5)
		local t = motion.lerp_frames(data.phase_elapsed, land_frames)
		local _, height, tilt = motion.sample(profile, data.start_position, data.landing_position or ent.Position, t, "LANDING")
		data.visual_height = height
		data.visual_tilt = tilt
		if data.landing_position then
			ent.Position = data.landing_position
		end
		if data.phase_elapsed == 1 then
			visual.on_landing(ent, data, profile)
		end
		if data.phase_elapsed >= land_frames then
			finish_move(ent, data)
		end
	elseif st == "RECOVERY" then
		data.visual_height = 0
		data.visual_tilt = (data.visual_tilt or 0) * 0.7
		if data.phase_elapsed >= profile.recover_frames then
			data.action_state = "IDLE"
			data.phase_elapsed = 0
			data.visual_tilt = 0
			data.task = nil
			apply_combat_collision(ent, data)
		end
	elseif st == "SPAWNING" then
		if data.phase_elapsed >= 8 then
			data.action_state = "IDLE"
		end
	end
	visual.apply_pose(ent, data)
	afterimage.record(ent, data)
	afterimage.tick(data)
end

local function autonomous_decide(ent, data)
	if data.control_mode ~= defs.MODE.AUTONOMOUS then return end
	-- Stone Director owns route pieces; do not self-attack while registered.
	if data.director_id and data.director_bound == true then
		return
	end
	if data.action_state ~= "IDLE" then return end
	if (data.think_cd or 0) > 0 then
		data.think_cd = data.think_cd - 1
		return
	end
	data.think_cd = 10 + (ptr(ent) % 8)
	local target = auxi.get_acceptible_target(ent)
	if not target then return end
	controller.command(ent, {type = "ATTACK", target = target, movement_policy = defs.MOVEMENT_POLICY.NORMAL})
end

function controller.update(ent)
	if not ent or not ent:Exists() or ent:IsDead() then return end
	if ent.Variant ~= enums.Enemies.chess_piece then return end
	local data = data_of(ent)
	if not data.kind then
		controller.initialize(ent, {kind = ent.SubType, role = defs.ROLE.COMBAT, mode = defs.MODE.AUTONOMOUS})
		data = data_of(ent)
	end
	ent.Velocity = Vector.Zero
	apply_combat_collision(ent, data)
	tick_action(ent, data)
	if data.control_mode == defs.MODE.AUTONOMOUS then
		autonomous_decide(ent, data)
	end
end

function controller.render_afterimages(ent)
	if not ent or not ent:Exists() then return end
	local data = data_of(ent)
	if data then
		afterimage.render(ent, data)
	end
end

function controller.on_remove(ent)
	local data = data_of(ent)
	if data then
		local ok_r, royal = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.royal_drop")
		if ok_r and royal and royal.on_piece_removed then
			royal.on_piece_removed(ent)
		end
		occupancy.unregister(ptr(ent))
		combat.clear_telegraph(ptr(ent))
		afterimage.clear(data)
		if data.director_id and data.director_bound then
			local ok, director = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.chess_piece_director")
			if ok and director and director.unregister then
				director.unregister(ent)
			end
		end
	end
end

--- True when piece can take a new Director order (must not interrupt mid-move).
function controller.can_accept_order(ent)
	local data = data_of(ent)
	if not data then return false end
	if data.royal_drop or data.action_state == "ROYAL_DROP" then
		return false
	end
	return data.action_state == "IDLE"
end

function controller.generate_pawn(id, pos, vel_or_params, maybe_params)
	local params
	local vel = Vector.Zero
	if type(vel_or_params) == "userdata" and vel_or_params.X then
		vel = vel_or_params
		params = maybe_params or {}
	else
		params = vel_or_params or {}
		vel = params.vel or Vector.Zero
	end
	params = params or {}
	params.kind = id or defs.KIND.QUEEN
	params.position = pos
	params.vel = vel
	params.spawner = params.spawner
	params.role = params.role or defs.ROLE.COMBAT
	params.mode = params.mode or defs.MODE.AUTONOMOUS
	local ent = controller.spawn(params)
	return ent
end

-- Expose occupancy for debug / probes.
controller.occupancy = occupancy

return controller
