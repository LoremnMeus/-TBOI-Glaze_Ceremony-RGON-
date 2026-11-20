-- Room-local chess piece occupancy: current cell + target reservation.
-- Not saved across rooms. pieceId = GetPtrHash (native lifetime); clear on remove / new room.

local occupancy = {}

local state = {
	current = {}, -- gridIndex -> pieceId
	target = {}, -- gridIndex -> pieceId
	pieces = {}, -- pieceId -> {id, current_index, target_index, moving, command_id}
	-- Override overlaps: gridIndex -> {pieceId, ...} when more than one piece shares a cell.
	conflicts = {},
	-- Hard blockers (Boss / reserve matte). Never skipped by OVERRIDE.
	blockers = {}, -- gridIndex -> { owner=, owner_id=, gidx= }
	blocker_by_id = {}, -- owner_id -> gidx
}

local function new_state()
	return {
		current = {},
		target = {},
		pieces = {},
		conflicts = {},
		blockers = {},
		blocker_by_id = {},
	}
end

function occupancy.clear()
	state = new_state()
end

function occupancy.get_state()
	return state
end

local function piece_row(id)
	local row = state.pieces[id]
	if not row then
		row = {
			id = id,
			current_index = nil,
			target_index = nil,
			moving = false,
			command_id = nil,
		}
		state.pieces[id] = row
	end
	return row
end

--- After leave/join: at most one current holder; conflicts only when 2+.
local function normalize_cell(gidx)
	if gidx == nil then return end
	local list = state.conflicts[gidx]
	local cur = state.current[gidx]
	if type(list) == "table" then
		-- Deduplicate.
		local seen = {}
		local clean = {}
		for _, id in ipairs(list) do
			if id and not seen[id] then
				seen[id] = true
				clean[#clean + 1] = id
			end
		end
		if cur and not seen[cur] then
			clean[#clean + 1] = cur
			seen[cur] = true
		end
		if #clean <= 1 then
			state.conflicts[gidx] = nil
			state.current[gidx] = clean[1]
		else
			state.conflicts[gidx] = clean
			-- Keep a stable primary; prefer existing current if still present.
			if not cur or not seen[cur] then
				state.current[gidx] = clean[1]
			end
		end
	elseif cur == nil then
		state.conflicts[gidx] = nil
	end
end

local function remove_from_conflicts(gidx, id)
	local list = state.conflicts[gidx]
	if type(list) == "table" then
		for i = #list, 1, -1 do
			if list[i] == id then
				table.remove(list, i)
			end
		end
	end
	if state.current[gidx] == id then
		state.current[gidx] = nil
	end
	normalize_cell(gidx)
end

local function note_conflict(gidx, id)
	local list = state.conflicts[gidx]
	if type(list) ~= "table" then
		list = {}
		state.conflicts[gidx] = list
	end
	local cur = state.current[gidx]
	if cur and cur ~= id then
		local found = false
		for _, existing in ipairs(list) do
			if existing == cur then found = true break end
		end
		if not found then
			list[#list + 1] = cur
		end
	end
	local found_self = false
	for _, existing in ipairs(list) do
		if existing == id then found_self = true break end
	end
	if not found_self then
		list[#list + 1] = id
	end
	normalize_cell(gidx)
	local holders = state.conflicts[gidx] or {state.current[gidx]}
	local parts = {}
	for _, h in ipairs(holders) do
		parts[#parts + 1] = tostring(h)
	end
	print(string.format(
		"[Qing Chess Occupancy] conflict at grid %s holders=%s",
		tostring(gidx),
		table.concat(parts, ",")
	))
end

function occupancy.grid_index(pos, room)
	room = room or Game():GetRoom()
	if not pos then return -1 end
	return room:GetGridIndex(pos)
end

function occupancy.grid_position(gidx, room)
	room = room or Game():GetRoom()
	return room:GetGridPosition(gidx)
end

function occupancy.snap_world(pos, room)
	room = room or Game():GetRoom()
	local gidx = occupancy.grid_index(pos, room)
	if gidx < 0 then
		return room:GetClampedPosition(pos, 20), -1
	end
	return occupancy.grid_position(gidx, room), gidx
end

--- Terrain / door / player probes (no piece occupancy mutation).
function occupancy.terrain_ok(pos, opts)
	opts = opts or {}
	local room = opts.room or Game():GetRoom()
	local gidx = occupancy.grid_index(pos, room)
	if gidx < 0 then return false, "oob", gidx end
	if room:GetGridCollision(gidx) ~= GridCollisionClass.COLLISION_NONE then
		return false, "blocked", gidx
	end
	if opts.avoid_doors ~= false then
		for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
			local door = room:GetDoor(slot)
			if door and door.Position:Distance(pos) < 36 then
				return false, "door", gidx
			end
		end
	end
	if opts.min_player_distance then
		local min_d = opts.min_player_distance
		for i = 0, Game():GetNumPlayers() - 1 do
			local p = Game():GetPlayer(i)
			if p and p:Exists() and not p:IsDead() and p.Position:Distance(pos) < min_d then
				return false, "player", gidx
			end
		end
	end
	return true, "ok", gidx
end

--- Hard blocker: Boss / sleeping reserve. OVERRIDE cannot skip these.
function occupancy.set_blocker(owner, owner_id, pos_or_gidx, opts)
	opts = opts or {}
	if not owner_id then
		return false, "no_id"
	end
	local room = opts.room or Game():GetRoom()
	local gidx
	if type(pos_or_gidx) == "number" then
		gidx = pos_or_gidx
	else
		_, gidx = occupancy.snap_world(pos_or_gidx, room)
	end
	if not gidx or gidx < 0 then
		return false, "oob"
	end
	local prev = state.blocker_by_id[owner_id]
	if prev and prev ~= gidx and state.blockers[prev] and state.blockers[prev].owner_id == owner_id then
		state.blockers[prev] = nil
	end
	state.blockers[gidx] = { owner = owner or "blocker", owner_id = owner_id, gidx = gidx }
	state.blocker_by_id[owner_id] = gidx
	return true, gidx
end

function occupancy.clear_blocker(owner_id)
	if not owner_id then
		return
	end
	local gidx = state.blocker_by_id[owner_id]
	if gidx and state.blockers[gidx] and state.blockers[gidx].owner_id == owner_id then
		state.blockers[gidx] = nil
	end
	state.blocker_by_id[owner_id] = nil
end

function occupancy.clear_blockers_by_owner(owner)
	local drop = {}
	for gidx, row in pairs(state.blockers) do
		if row and row.owner == owner then
			drop[#drop + 1] = { gidx = gidx, id = row.owner_id }
		end
	end
	for _, d in ipairs(drop) do
		state.blockers[d.gidx] = nil
		if state.blocker_by_id[d.id] == d.gidx then
			state.blocker_by_id[d.id] = nil
		end
	end
end

function occupancy.get_blocker(gidx)
	return state.blockers[gidx]
end

function occupancy.list_blockers()
	local out = {}
	for gidx, row in pairs(state.blockers) do
		out[#out + 1] = {
			gidx = gidx,
			owner = row.owner,
			owner_id = row.owner_id,
		}
	end
	return out
end

local function hard_blocked(gidx, opts)
	local b = state.blockers[gidx]
	if not b then
		return false
	end
	if opts and opts.allow_blocker_id and opts.allow_blocker_id == b.owner_id then
		return false
	end
	return true, b
end

--- Pure query: can this piece enter destination under policy?
-- opts.ignore_occupancy: override may skip other pieces' current/target, NOT hard blockers.
-- opts.allow_self: treat own current/target as free (default true).
function occupancy.can_enter(piece_id, destination, opts)
	opts = opts or {}
	local room = opts.room or Game():GetRoom()
	local pos, gidx = occupancy.snap_world(destination, room)
	if gidx < 0 then return false, "oob", gidx, pos end
	local tok, why = occupancy.terrain_ok(pos, opts)
	if not tok then return false, why, gidx, pos end
	-- Hard blockers always apply (Boss / reserve array).
	local hb, brow = hard_blocked(gidx, opts)
	if hb then
		return false, "hard_block", gidx, pos, brow
	end
	if opts.ignore_occupancy == true then
		return true, "ok", gidx, pos
	end
	local allow_self = opts.allow_self ~= false
	local cur = state.current[gidx]
	if cur and not (allow_self and cur == piece_id) then
		return false, "occupied", gidx, pos
	end
	local conflict = state.conflicts[gidx]
	if type(conflict) == "table" then
		for _, id in ipairs(conflict) do
			if not (allow_self and id == piece_id) then
				return false, "occupied", gidx, pos
			end
		end
	end
	local tgt = state.target[gidx]
	if tgt and not (allow_self and tgt == piece_id) then
		return false, "reserved", gidx, pos
	end
	return true, "ok", gidx, pos
end

function occupancy.register_current(piece_id, pos, opts)
	opts = opts or {}
	local room = opts.room or Game():GetRoom()
	local snap, gidx = occupancy.snap_world(pos, room)
	if gidx < 0 then return false, "oob" end
	local row = piece_row(piece_id)
	if row.current_index and row.current_index ~= gidx then
		if state.current[row.current_index] == piece_id then
			state.current[row.current_index] = nil
		end
		remove_from_conflicts(row.current_index, piece_id)
	end
	local holder = state.current[gidx]
	if holder and holder ~= piece_id then
		if opts.allow_conflict == true then
			note_conflict(gidx, piece_id)
		else
			return false, "occupied"
		end
	else
		state.current[gidx] = piece_id
		normalize_cell(gidx)
	end
	row.current_index = gidx
	return true, gidx, snap
end

function occupancy.release_current(piece_id)
	local row = state.pieces[piece_id]
	if not row or not row.current_index then return end
	local gidx = row.current_index
	remove_from_conflicts(gidx, piece_id)
	row.current_index = nil
end

function occupancy.release_target(piece_id)
	local row = state.pieces[piece_id]
	if not row or not row.target_index then return end
	local gidx = row.target_index
	if state.target[gidx] == piece_id then
		state.target[gidx] = nil
	end
	row.target_index = nil
	row.moving = false
	row.command_id = nil
end

--- Commit a move reservation: keep current, set target.
function occupancy.commit_move(piece_id, destination, opts)
	opts = opts or {}
	local ok, why, gidx, pos = occupancy.can_enter(piece_id, destination, opts)
	if not ok then
		-- OVERRIDE may force past piece occupancy, never past hard blockers / terrain OOB.
		if opts.ignore_occupancy == true and why ~= "hard_block" and why ~= "oob" and why ~= "blocked" and why ~= "door" then
			local room = opts.room or Game():GetRoom()
			pos, gidx = occupancy.snap_world(destination, room)
			if gidx < 0 then return false, "oob" end
			local hb = hard_blocked(gidx, opts)
			if hb then
				return false, "hard_block", gidx, pos
			end
		else
			return false, why, gidx, pos
		end
	end
	local row = piece_row(piece_id)
	if row.target_index and row.target_index ~= gidx then
		if state.target[row.target_index] == piece_id then
			state.target[row.target_index] = nil
		end
	end
	local holder = state.target[gidx]
	if holder and holder ~= piece_id and opts.ignore_occupancy ~= true then
		return false, "reserved", gidx, pos
	end
	state.target[gidx] = piece_id
	row.target_index = gidx
	row.moving = true
	row.command_id = opts.command_id
	return true, gidx, pos
end

--- Landing finished: migrate current to target, clear reservation.
function occupancy.finish_move(piece_id, opts)
	opts = opts or {}
	local row = state.pieces[piece_id]
	if not row then return false, "no_piece" end
	local dest = row.target_index
	occupancy.release_target(piece_id)
	if dest == nil and opts.pos then
		local _, gidx = occupancy.snap_world(opts.pos)
		dest = gidx
	end
	if dest == nil then return false, "no_dest" end
	local room = opts.room or Game():GetRoom()
	local pos = occupancy.grid_position(dest, room)
	return occupancy.register_current(piece_id, pos, {
		allow_conflict = opts.allow_conflict == true,
		room = room,
	})
end

--- Atomically hand a target reservation from from_id to to_id as current occupancy.
-- On failure, restores the original reservation on from_id.
function occupancy.claim_reserved(from_id, to_id, opts)
	opts = opts or {}
	if from_id == nil or to_id == nil then
		return false, "bad_id"
	end
	local from = state.pieces[from_id]
	if not from or from.target_index == nil then
		return false, "no_reservation"
	end
	local gidx = from.target_index
	if state.target[gidx] ~= from_id then
		return false, "lost_reservation"
	end
	local room = opts.room or Game():GetRoom()
	local pos = occupancy.grid_position(gidx, room)
	if not pos then
		return false, "bad_grid"
	end

	-- Drop reservation first so register_current is not blocked by our own target stamp.
	state.target[gidx] = nil
	from.target_index = nil
	from.moving = false
	from.command_id = nil

	local ok, a, b = occupancy.register_current(to_id, pos, {
		room = room,
		allow_conflict = opts.allow_conflict == true,
	})
	if not ok then
		-- Restore reservation for retry / cancel path.
		state.target[gidx] = from_id
		from.target_index = gidx
		from.moving = true
		return false, a or "register_failed", gidx, pos
	end
	return true, a, b or pos
end

--- Interrupt / cancel: drop target, re-bind current to actual world position.
function occupancy.resync(piece_id, world_pos, opts)
	opts = opts or {}
	occupancy.release_target(piece_id)
	if world_pos then
		return occupancy.register_current(piece_id, world_pos, {
			allow_conflict = opts.allow_conflict == true,
			room = opts.room,
		})
	end
	return true
end

function occupancy.unregister(piece_id)
	occupancy.release_target(piece_id)
	occupancy.release_current(piece_id)
	state.pieces[piece_id] = nil
end

function occupancy.get_piece(piece_id)
	return state.pieces[piece_id]
end

--- Group planning: treat each mover's current cell as vacated for other movers.
-- moves: { {piece_id=, destination=Vector|gidx}, ... }
-- Returns ok, why, resolved where resolved[i] = {piece_id, gidx, pos}
function occupancy.plan_group_moves(moves, opts)
	opts = opts or {}
	local room = opts.room or Game():GetRoom()
	local ignore = opts.ignore_occupancy == true
	local vacating = {} -- piece_id -> current_index (may be nil)
	local resolved = {}
	local claimed = {} -- gidx -> piece_id

	for _, m in ipairs(moves or {}) do
		local id = m.piece_id
		if not id then
			return false, "no_id", nil
		end
		local row = state.pieces[id]
		vacating[id] = row and row.current_index or nil
	end

	local function holder_blocks(gidx, self_id)
		if ignore then return false end
		local cur = state.current[gidx]
		if cur and cur ~= self_id then
			-- Vacating mover frees their current cell for the group.
			if vacating[cur] == gidx then
				return false
			end
			return true, "occupied"
		end
		local conflict = state.conflicts[gidx]
		if type(conflict) == "table" then
			for _, oid in ipairs(conflict) do
				if oid ~= self_id and vacating[oid] ~= gidx then
					return true, "occupied"
				end
			end
		end
		local tgt = state.target[gidx]
		if tgt and tgt ~= self_id and not vacating[tgt] then
			-- Another piece (outside group, or in group but already targeting elsewhere) reserved.
			-- In-group targets are tracked via claimed.
			if not claimed[gidx] then
				return true, "reserved"
			end
		end
		return false
	end

	for _, m in ipairs(moves or {}) do
		local id = m.piece_id
		local pos, gidx
		if type(m.destination) == "number" then
			gidx = m.destination
			pos = occupancy.grid_position(gidx, room)
		else
			pos, gidx = occupancy.snap_world(m.destination, room)
		end
		if gidx < 0 then
			return false, "oob", nil
		end
		local tok, why = occupancy.terrain_ok(pos, opts)
		if not tok then
			return false, why, nil
		end
		local hb = hard_blocked(gidx, opts)
		if hb then
			return false, "hard_block", nil
		end
		if claimed[gidx] and claimed[gidx] ~= id then
			return false, "dup_target", nil
		end
		local blocked, bwhy = holder_blocks(gidx, id)
		if blocked then
			return false, bwhy or "occupied", nil
		end
		claimed[gidx] = id
		resolved[#resolved + 1] = {piece_id = id, gidx = gidx, pos = pos}
	end
	return true, "ok", resolved
end

--- Atomically stamp all group target reservations. Call only after plan_group_moves succeeds.
function occupancy.commit_group_moves(resolved, opts)
	opts = opts or {}
	if type(resolved) ~= "table" or #resolved < 1 then
		return false, "empty"
	end
	-- Clear previous targets for all members first (avoid mid-loop collisions).
	for _, r in ipairs(resolved) do
		occupancy.release_target(r.piece_id)
	end
	for _, r in ipairs(resolved) do
		local row = piece_row(r.piece_id)
		state.target[r.gidx] = r.piece_id
		row.target_index = r.gidx
		row.moving = true
		row.command_id = opts.command_id
	end
	return true, "ok"
end

return occupancy
