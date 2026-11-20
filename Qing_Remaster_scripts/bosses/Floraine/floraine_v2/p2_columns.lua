-- P2 dual side-bands (3-col random) + shared march + entrance + stray demote pawns.
-- Column slots + strays share one LIFT/HOVER/TRANSFER/LAND/SETTLE clock.
-- No return_queue / cross-column seat booking (use demote_at for in-place demote).

local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")
local arena = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.arena")
local piece_defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")
local piece_matte = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.piece_matte_fx")
local occupancy = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_occupancy")
local soft_collision = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.chess_piece_soft_collision")

local columns = {}

local OWNER = (defs.P2_COLUMN and defs.P2_COLUMN.OWNER) or "floraine_p2_column"
local STRAY_OWNER = (defs.P2_COLUMN and defs.P2_COLUMN.STRAY_OWNER) or "floraine_p2_stray"

local SLOT = {
	MATTE = "MATTE",
	TARGET_LOCKED = "TARGET_LOCKED",
	EMPTY = "EMPTY",
}

local PHASE = {
	IDLE = "IDLE",
	ENTRANCE_FLY = "ENTRANCE_FLY",
	ENTRANCE_HOVER = "ENTRANCE_HOVER",
	ENTRANCE_LAND = "ENTRANCE_LAND",
	ENTRANCE_SETTLE = "ENTRANCE_SETTLE",
	LIFT = "LIFT",
	HOVER = "HOVER",
	TRANSFER = "TRANSFER",
	LAND = "LAND",
	SETTLE = "SETTLE",
}

local state = {
	active = false,
	step_elapsed = 0,
	step_interval = 75,
	paused = false,
	next_id = 1,
	layout_seed = 1,
	entrance_done = false,
	left = { side = "left", slots = {} },
	right = { side = "right", slots = {} },
	strays = {}, -- free-board demoted mattes
	motion = {
		phase = PHASE.IDLE,
		elapsed = 0,
		cycle_id = 0,
		logic_committed = false,
		layout = nil,
		left_plan = nil,
		right_plan = nil,
		stray_plan = nil,
		exit_pending = {}, -- pieces still flying off-screen after logic commit
	},
}

local function cfg()
	return defs.P2_COLUMN or {}
end

local function ease_out(t)
	t = math.max(0, math.min(1, t))
	return 1 - (1 - t) * (1 - t)
end

local function ease_in(t)
	t = math.max(0, math.min(1, t))
	return t * t
end

local function lerp_vec(a, b, t)
	return Vector(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t)
end

local function new_id()
	state.next_id = state.next_id + 1
	return state.next_id
end

local function make_rng(seed)
	local r = RNG()
	r:SetSeed((seed % 2147483646) + 1, 35)
	return r
end

local function layout_rng()
	return make_rng(state.layout_seed + state.next_id * 17 + state.motion.cycle_id * 31)
end

local function blocker_id(piece_id)
	return OWNER .. "_" .. tostring(piece_id)
end

local function stray_blocker_id(piece_id)
	return STRAY_OWNER .. "_" .. tostring(piece_id)
end

local function motion_cfg_durations()
	local c = cfg()
	return {
		lift = c.LIFT or 14,
		hover = c.HOVER or 12,
		transfer = c.TRANSFER or 20,
		land = c.LAND or 14,
		settle = c.SETTLE or 10,
		height = c.LIFT_HEIGHT or 32,
		exit_fly_max = c.EXIT_FLY_MAX or 90,
		top_offset = c.TOP_SPAWN_OFFSET or 40,
		entrance_fly = c.ENTRANCE_FLY or 24,
		entrance_hover = c.ENTRANCE_HOVER or 12,
		entrance_land = c.ENTRANCE_LAND or 15,
		entrance_settle = c.ENTRANCE_SETTLE or 10,
		side_offset = c.ENTRANCE_SIDE_OFFSET or 80,
		band = c.BAND_WIDTH or 3,
	}
end

local function pick_option(opts, rng, avoid_col)
	if not opts or #opts < 1 then
		return nil
	end
	local preferred = {}
	for i = 1, #opts do
		if opts[i].col ~= avoid_col then
			preferred[#preferred + 1] = opts[i]
		end
	end
	local pool = (#preferred >= 1) and preferred or opts
	local idx = (rng:RandomInt(#pool) % #pool) + 1
	return pool[idx]
end

local function spawn_matte_at(slot, ground_pos)
	if not slot or slot.state == SLOT.EMPTY then
		return nil
	end
	ground_pos = ground_pos or slot.visual_pos or slot.pos
	local outline_a = slot.state == SLOT.TARGET_LOCKED and 0.55 or 0
	local outline_rgb = slot.state == SLOT.TARGET_LOCKED and { 1, 0.2, 0.25 } or nil
	if slot.fx and slot.fx.Exists and slot.fx:Exists() then
		piece_matte.sync(slot.fx, {
			ground_pos = ground_pos,
			visual_height = slot.visual_height or 0,
			color_progress = 0,
			outline_alpha = outline_a,
			outline_rgb = outline_rgb,
		})
		return slot.fx
	end
	local ent = piece_matte.spawn(piece_defs.KIND.PAWN, ground_pos, {
		owner = slot.is_stray and STRAY_OWNER or OWNER,
		piece_id = slot.id,
		color_progress = 0,
		outline_alpha = outline_a,
		outline_rgb = outline_rgb,
		visual_height = slot.visual_height or 0,
	})
	slot.fx = ent
	return ent
end

local function refresh_blockers_side(side)
	for _, slot in ipairs(side.slots) do
		if (slot.state == SLOT.MATTE or slot.state == SLOT.TARGET_LOCKED) and slot.pos then
			occupancy.set_blocker(OWNER, blocker_id(slot.id), slot.pos)
		else
			occupancy.clear_blocker(blocker_id(slot.id))
		end
	end
end

local function refresh_stray_blockers()
	for _, slot in ipairs(state.strays) do
		if (slot.state == SLOT.MATTE or slot.state == SLOT.TARGET_LOCKED) and slot.pos then
			occupancy.set_blocker(STRAY_OWNER, stray_blocker_id(slot.id), slot.pos)
		else
			occupancy.clear_blocker(stray_blocker_id(slot.id))
		end
	end
end

local function clear_side(side)
	for _, slot in ipairs(side.slots) do
		if slot.id then
			occupancy.clear_blocker(blocker_id(slot.id))
		end
		if slot.fx then
			piece_matte.remove(slot.fx)
			slot.fx = nil
		end
	end
	side.slots = {}
end

local function clear_strays()
	for _, slot in ipairs(state.strays) do
		if slot.id then
			occupancy.clear_blocker(stray_blocker_id(slot.id))
		end
		if slot.fx then
			piece_matte.remove(slot.fx)
			slot.fx = nil
		end
	end
	state.strays = {}
end

local function make_slot(side_name, row, pos, opts)
	opts = opts or {}
	local slot = {
		id = new_id(),
		side = side_name,
		row = row,
		grid_col = opts.grid_col,
		state = opts.state or SLOT.MATTE,
		kind = "pawn",
		pos = Vector(pos.X, pos.Y),
		visual_pos = Vector(pos.X, pos.Y),
		visual_height = opts.visual_height or 0,
		promote_token = nil,
		fx = nil,
		exiting = false,
		entering = opts.entering == true,
		is_stray = opts.is_stray == true,
	}
	if slot.state == SLOT.MATTE or slot.state == SLOT.TARGET_LOCKED then
		spawn_matte_at(slot, slot.visual_pos)
	end
	return slot
end

local function occupied_keys()
	local keys = {}
	local function mark(pos)
		if not pos then return end
		local room = Game():GetRoom()
		local idx = room:GetGridIndex(pos)
		if idx and idx >= 0 then
			keys[idx] = true
		end
	end
	for _, side in ipairs({ state.left, state.right }) do
		for _, s in ipairs(side.slots) do
			if s.state == SLOT.MATTE or s.state == SLOT.TARGET_LOCKED then
				mark(s.pos)
			end
		end
	end
	for _, s in ipairs(state.strays) do
		if s.state == SLOT.MATTE or s.state == SLOT.TARGET_LOCKED then
			mark(s.pos)
		end
	end
	return keys
end

local function is_screen_fully_below(ground, visual_height)
	if not ground then
		return true
	end
	-- Approximate sprite bottom (ground + half body), accounting for lift offset.
	local sprite_bottom = Vector(ground.X, ground.Y - (visual_height or 0) + 36)
	local screen = Isaac.WorldToScreen(sprite_bottom)
	return screen.Y > Isaac.GetScreenHeight() + 4
end

local function offscreen_start(side_name, target, side_offset)
	local room = Game():GetRoom()
	local tl = room:GetTopLeftPos()
	local br = room:GetBottomRightPos()
	local x
	if side_name == "left" then
		x = tl.X - (side_offset or 80)
	else
		x = br.X + (side_offset or 80)
	end
	return Vector(x, target.Y)
end

--- Build initial slots with per-row random band X (anti-adjacent same col).
local function build_initial_slots(layout, play_entrance)
	local rng = layout_rng()
	local durs = motion_cfg_durations()
	local left_avoid, right_avoid = nil, nil
	state.left.slots = {}
	state.right.slots = {}
	for i = 1, #layout do
		local row = layout[i]
		local lo = pick_option(row.left, rng, left_avoid)
		local ro = pick_option(row.right, rng, right_avoid)
		if lo then
			left_avoid = lo.col
			local slot = make_slot("left", i, lo.pos, {
				grid_col = lo.col,
				visual_height = play_entrance and durs.height or 0,
			})
			if play_entrance then
				local start = offscreen_start("left", lo.pos, durs.side_offset)
				slot.visual_pos = start
				slot.entering = true
				spawn_matte_at(slot, start)
			end
			state.left.slots[i] = slot
		end
		if ro then
			right_avoid = ro.col
			local slot = make_slot("right", i, ro.pos, {
				grid_col = ro.col,
				visual_height = play_entrance and durs.height or 0,
			})
			if play_entrance then
				local start = offscreen_start("right", ro.pos, durs.side_offset)
				slot.visual_pos = start
				slot.entering = true
				spawn_matte_at(slot, start)
			end
			state.right.slots[i] = slot
		end
	end
end

function columns.is_active()
	return state.active == true
end

function columns.is_entrance_busy()
	local p = state.motion.phase
	return p == PHASE.ENTRANCE_FLY
		or p == PHASE.ENTRANCE_HOVER
		or p == PHASE.ENTRANCE_LAND
		or p == PHASE.ENTRANCE_SETTLE
end

function columns.is_entrance_done()
	return state.entrance_done == true
end

function columns.is_motion_busy()
	return state.motion.phase ~= PHASE.IDLE
end

function columns.is_combat_ready()
	return state.active and state.entrance_done and not columns.is_motion_busy()
end

function columns.motion_phase()
	return state.motion.phase
end

function columns.get_side(name)
	if name == "right" then
		return state.right
	end
	return state.left
end

function columns.get_slot_by_id(slot_id)
	if not slot_id then
		return nil
	end
	for _, side in ipairs({ state.left, state.right }) do
		for _, slot in ipairs(side.slots) do
			if slot.id == slot_id then
				return slot, side
			end
		end
	end
	for _, slot in ipairs(state.strays) do
		if slot.id == slot_id then
			return slot, nil
		end
	end
	local m = state.motion
	for _, plan in ipairs({ m.left_plan, m.right_plan }) do
		if plan then
			if plan.enter and plan.enter.slot and plan.enter.slot.id == slot_id then
				return plan.enter.slot, columns.get_side(plan.enter.slot.side)
			end
			if plan.exit and plan.exit.slot and plan.exit.slot.id == slot_id then
				return plan.exit.slot, columns.get_side(plan.exit.slot.side)
			end
		end
	end
	if m.stray_plan then
		for _, mv in ipairs(m.stray_plan.moves or {}) do
			if mv.slot and mv.slot.id == slot_id then
				return mv.slot, nil
			end
		end
		for _, ex in ipairs(m.stray_plan.exits or {}) do
			if ex.slot and ex.slot.id == slot_id then
				return ex.slot, nil
			end
		end
	end
	return nil
end

local function set_motion_phase(phase)
	state.motion.phase = phase
	state.motion.elapsed = 0
end

--- opts.entrance = false skips side fly-in (still lands ready). Default true.
function columns.begin(opts)
	opts = opts or {}
	local play_entrance = opts.entrance ~= false
	columns.clear("rebuild")
	local durs = motion_cfg_durations()
	local layout = arena.p2_row_layout(durs.band)
	if not layout or #layout < 1 then
		return false, "no_rows"
	end
	local room = Game():GetRoom()
	state.layout_seed = room:GetSpawnSeed()
	state.step_interval = cfg().STEP_INTERVAL or 75
	state.step_elapsed = 0
	state.paused = false
	state.active = true
	state.entrance_done = not play_entrance
	state.motion.phase = PHASE.IDLE
	state.motion.elapsed = 0
	state.motion.logic_committed = false
	state.motion.left_plan = nil
	state.motion.right_plan = nil
	state.motion.stray_plan = nil
	state.motion.exit_pending = {}
	state.motion.layout = layout

	build_initial_slots(layout, play_entrance)
	refresh_blockers_side(state.left)
	refresh_blockers_side(state.right)

	if play_entrance then
		set_motion_phase(PHASE.ENTRANCE_FLY)
	end
	return true
end

function columns.clear(reason)
	clear_side(state.left)
	clear_side(state.right)
	clear_strays()
	occupancy.clear_blockers_by_owner(OWNER)
	occupancy.clear_blockers_by_owner(STRAY_OWNER)
	state.active = false
	state.step_elapsed = 0
	state.entrance_done = false
	state.motion.phase = PHASE.IDLE
	state.motion.elapsed = 0
	state.motion.left_plan = nil
	state.motion.right_plan = nil
	state.motion.stray_plan = nil
	state.motion.exit_pending = {}
	state.motion.logic_committed = false
	return true, reason
end

function columns.set_paused(p)
	state.paused = p == true
end

function columns.is_paused()
	return state.paused == true
end

function columns.lock_target(slot)
	if not slot or slot.state ~= SLOT.MATTE then
		return nil, "bad_slot"
	end
	if columns.is_motion_busy() then
		return nil, "marching"
	end
	if not state.entrance_done then
		return nil, "entrance"
	end
	if (slot.visual_height or 0) > 0.5 then
		return nil, "airborne"
	end
	slot.state = SLOT.TARGET_LOCKED
	slot.promote_token = "p2_lock_" .. tostring(slot.id) .. "_" .. tostring(Game():GetFrameCount())
	spawn_matte_at(slot, slot.visual_pos or slot.pos)
	return slot.promote_token
end

function columns.unlock_target(slot_id, token)
	local slot = columns.get_slot_by_id(slot_id)
	if not slot then
		return false, "gone"
	end
	if token and slot.promote_token and slot.promote_token ~= token then
		return false, "token_mismatch"
	end
	if slot.state == SLOT.TARGET_LOCKED then
		slot.state = SLOT.MATTE
		slot.promote_token = nil
		spawn_matte_at(slot, slot.visual_pos or slot.pos)
		if slot.is_stray then
			refresh_stray_blockers()
		else
			local side = columns.get_side(slot.side)
			refresh_blockers_side(side)
		end
		return true
	end
	return false, "not_locked"
end

function columns.commit_promote(slot_id, token)
	local slot = columns.get_slot_by_id(slot_id)
	if not slot then
		return false, "gone"
	end
	if slot.state ~= SLOT.TARGET_LOCKED and slot.state ~= SLOT.MATTE then
		return false, "bad_state"
	end
	if token and slot.promote_token and slot.promote_token ~= token then
		return false, "token_mismatch"
	end
	if slot.is_stray then
		occupancy.clear_blocker(stray_blocker_id(slot.id))
	else
		occupancy.clear_blocker(blocker_id(slot.id))
	end
	if slot.fx then
		piece_matte.remove(slot.fx)
		slot.fx = nil
	end
	slot.state = SLOT.EMPTY
	slot.promote_token = nil
	-- Column EMPTY holes scroll off; strays are removed from the stray list.
	if slot.is_stray then
		local keep = {}
		for _, s in ipairs(state.strays) do
			if s.id ~= slot.id then
				keep[#keep + 1] = s
			end
		end
		state.strays = keep
	end
	return true, slot
end

function columns.rollback_promote(slot_id, token)
	local slot = columns.get_slot_by_id(slot_id)
	if not slot then
		return false, "gone"
	end
	if token and slot.promote_token and slot.promote_token ~= token then
		return false, "token_mismatch"
	end
	if slot.state == SLOT.TARGET_LOCKED or slot.state == SLOT.EMPTY then
		slot.state = SLOT.MATTE
		slot.promote_token = nil
		slot.visual_height = 0
		slot.visual_pos = Vector(slot.pos.X, slot.pos.Y)
		spawn_matte_at(slot, slot.pos)
		if slot.is_stray then
			refresh_stray_blockers()
		else
			refresh_blockers_side(columns.get_side(slot.side))
		end
		return true
	end
	return false, "bad_state"
end

--- Demote a promoted NPC in-place into a stray matte pawn.
--- Returns stray slot or nil, why.
function columns.demote_at(pos, opts)
	opts = opts or {}
	if not pos then
		return nil, "no_pos"
	end
	local keys = occupied_keys()
	local room = Game():GetRoom()
	local land, idx = arena.nearest_walkable(pos, opts.search_radius or 4)
	if not land then
		return nil, "no_cell"
	end
	-- Resolve occupancy conflict: search ring if taken.
	if idx and keys[idx] then
		land = nil
		local width = room:GetGridWidth()
		local height = room:GetGridHeight()
		local ox = idx % width
		local oy = math.floor(idx / width)
		for r = 1, (opts.search_radius or 4) do
			for dy = -r, r do
				for dx = -r, r do
					if math.abs(dx) == r or math.abs(dy) == r then
						local x, y = ox + dx, oy + dy
						if x >= 0 and x < width and y >= 0 and y < height then
							local i2 = y * width + x
							local col = room:GetGridCollision(i2)
							if col == GridCollisionClass.COLLISION_NONE and not keys[i2] then
								local p = room:GetGridPosition(i2)
								land = Vector(p.X, p.Y)
								idx = i2
								break
							end
						end
					end
				end
				if land then break end
			end
			if land then break end
		end
	end
	if not land then
		return nil, "occupied"
	end
	local slot = make_slot("stray", 0, land, {
		is_stray = true,
		visual_height = 0,
		state = SLOT.MATTE,
	})
	slot.side = "stray"
	state.strays[#state.strays + 1] = slot
	refresh_stray_blockers()
	return slot
end

local function build_side_plan(side, layout, durs)
	local n = #layout
	local old = side.slots
	local plan = { moves = {}, enter = nil, exit = nil }
	if n < 1 then
		return plan
	end
	local rng = layout_rng()

	local bottom = old[n]
	if bottom and bottom.state ~= SLOT.EMPTY then
		local start = Vector(bottom.pos.X, bottom.pos.Y)
		local transfer_target = Vector(bottom.pos.X, bottom.pos.Y + (durs.top_offset or 40))
		plan.exit = {
			slot = bottom,
			start = start,
			transfer_target = transfer_target,
			-- fly continues until off-screen; initial aim far below
			fly_target = Vector(bottom.pos.X, bottom.pos.Y + 200),
		}
		bottom.exiting = true
	elseif bottom and bottom.state == SLOT.EMPTY then
		-- Empty hole also scrolls off (no fx).
		plan.exit = {
			slot = bottom,
			start = Vector(bottom.pos.X, bottom.pos.Y),
			transfer_target = Vector(bottom.pos.X, bottom.pos.Y + (durs.top_offset or 40)),
			fly_target = Vector(bottom.pos.X, bottom.pos.Y + 200),
			silent = true,
		}
		bottom.exiting = true
	end

	for i = 1, n - 1 do
		local src = old[i]
		if src then
			local target_row = layout[i + 1]
			-- Keep X (grid_col); only Y advances with the row.
			local target = Vector(src.pos.X, target_row.y_world)
			-- Snap to matching col in next row if available.
			local opts = side.side == "left" and target_row.left or target_row.right
			if src.grid_col and opts then
				for _, o in ipairs(opts) do
					if o.col == src.grid_col then
						target = Vector(o.pos.X, o.pos.Y)
						break
					end
				end
			end
			plan.moves[#plan.moves + 1] = {
				slot = src,
				start = Vector(src.pos.X, src.pos.Y),
				target = target,
				new_row = i + 1,
				new_col = src.grid_col,
			}
		end
	end

	-- Top enter: new random X in band.
	local top_row = layout[1]
	local opts = side.side == "left" and top_row.left or top_row.right
	local avoid = old[1] and old[1].grid_col
	local picked = pick_option(opts, rng, avoid)
	if picked then
		local top_target = Vector(picked.pos.X, picked.pos.Y)
		local top_start = Vector(top_target.X, top_target.Y - (durs.top_offset or 40))
		local enter_slot = make_slot(side.side, 1, top_target, {
			grid_col = picked.col,
			visual_height = 0,
			entering = true,
		})
		enter_slot.visual_pos = Vector(top_start.X, top_start.Y)
		spawn_matte_at(enter_slot, enter_slot.visual_pos)
		plan.enter = {
			slot = enter_slot,
			start = top_start,
			target = top_target,
		}
	end
	return plan
end

local function build_stray_plan(durs)
	local plan = { moves = {}, exits = {} }
	local keep_preview = {}
	for _, slot in ipairs(state.strays) do
		if slot.state == SLOT.EMPTY then
			-- skip
		else
			local next_pos = arena.step_down_walkable(slot.pos)
			local keys = occupied_keys()
			-- Temporarily ignore this slot's own cell.
			local room = Game():GetRoom()
			local self_idx = room:GetGridIndex(slot.pos)
			if self_idx and self_idx >= 0 then
				keys[self_idx] = nil
			end
			if next_pos then
				local nidx = room:GetGridIndex(next_pos)
				if nidx and keys[nidx] then
					-- Conflict: try slight lateral search.
					local alt = arena.nearest_walkable(Vector(next_pos.X + 40, next_pos.Y), 2)
						or arena.nearest_walkable(Vector(next_pos.X - 40, next_pos.Y), 2)
					if alt then
						local aidx = room:GetGridIndex(alt)
						if aidx and not keys[aidx] then
							next_pos = alt
							nidx = aidx
						else
							next_pos = nil
						end
					else
						next_pos = nil
					end
				end
			end
			if not next_pos then
				-- Treat as exit if near bottom or no step.
				plan.exits[#plan.exits + 1] = {
					slot = slot,
					start = Vector(slot.pos.X, slot.pos.Y),
					transfer_target = Vector(slot.pos.X, slot.pos.Y + (durs.top_offset or 40)),
					fly_target = Vector(slot.pos.X, slot.pos.Y + 200),
				}
				slot.exiting = true
			else
				plan.moves[#plan.moves + 1] = {
					slot = slot,
					start = Vector(slot.pos.X, slot.pos.Y),
					target = next_pos,
				}
				keep_preview[room:GetGridIndex(next_pos)] = true
			end
		end
	end
	return plan
end

local function apply_visuals_for_plan(plan, height, transfer_t, land_t, phase)
	if not plan then
		return
	end
	transfer_t = transfer_t or 0
	land_t = land_t or 0

	local function set_slot(slot, ground, h)
		if not slot then return end
		slot.visual_pos = Vector(ground.X, ground.Y)
		slot.visual_height = h or 0
		if slot.state ~= SLOT.EMPTY then
			spawn_matte_at(slot, slot.visual_pos)
		end
	end

	for _, mv in ipairs(plan.moves or {}) do
		local ground
		if phase == PHASE.LIFT or phase == PHASE.HOVER then
			ground = mv.start
		elseif phase == PHASE.TRANSFER then
			ground = lerp_vec(mv.start, mv.target, transfer_t)
		else
			ground = mv.target
		end
		local h = height
		if phase == PHASE.LAND then
			h = height * (1 - ease_out(land_t))
		elseif phase == PHASE.SETTLE or phase == PHASE.IDLE then
			h = 0
		end
		set_slot(mv.slot, ground, h)
	end

	if plan.enter then
		local en = plan.enter
		local ground
		if phase == PHASE.LIFT or phase == PHASE.HOVER then
			ground = en.start
		elseif phase == PHASE.TRANSFER then
			ground = lerp_vec(en.start, en.target, transfer_t)
		else
			ground = en.target
		end
		local h = height
		if phase == PHASE.LAND then
			h = height * (1 - ease_out(land_t))
		elseif phase == PHASE.SETTLE or phase == PHASE.IDLE then
			h = 0
		end
		set_slot(en.slot, ground, h)
	end

	local function apply_exit(ex)
		if not ex or not ex.slot then return end
		local slot = ex.slot
		if phase == PHASE.LIFT or phase == PHASE.HOVER then
			set_slot(slot, ex.start, height)
		elseif phase == PHASE.TRANSFER then
			set_slot(slot, lerp_vec(ex.start, ex.transfer_target, transfer_t), height)
		elseif phase == PHASE.LAND then
			local ground = lerp_vec(ex.transfer_target, ex.fly_target, ease_in(math.min(1, land_t)))
			-- Keep accelerating downward past fly_target.
			if land_t >= 1 then
				local extra = (land_t - 1) * 120
				ground = Vector(ex.fly_target.X, ex.fly_target.Y + extra)
			end
			set_slot(slot, ground, height * math.max(0, 1 - 0.35 * math.min(1, land_t)))
		end
	end

	if plan.exit then
		apply_exit(plan.exit)
	end
	for _, ex in ipairs(plan.exits or {}) do
		apply_exit(ex)
	end
end

local function apply_entrance_visuals(t_fly, height, phase)
	local function side_vis(side)
		for _, slot in ipairs(side.slots) do
			if slot.state ~= SLOT.EMPTY then
				local target = slot.pos
				local start = offscreen_start(side.side, target, motion_cfg_durations().side_offset)
				local ground
				if phase == PHASE.ENTRANCE_FLY then
					ground = lerp_vec(start, target, ease_out(t_fly or 0))
				else
					ground = target
				end
				local h = height
				if phase == PHASE.ENTRANCE_LAND then
					h = height * (1 - ease_out(t_fly or 0))
				elseif phase == PHASE.ENTRANCE_SETTLE then
					h = 0
				end
				slot.visual_pos = Vector(ground.X, ground.Y)
				slot.visual_height = h
				spawn_matte_at(slot, slot.visual_pos)
			end
		end
	end
	side_vis(state.left)
	side_vis(state.right)
end

local function commit_logic(plan, side, layout)
	if not plan then return end
	local n = #layout
	local next_slots = {}

	if plan.enter and plan.enter.slot then
		local s = plan.enter.slot
		s.entering = false
		s.row = 1
		s.pos = Vector(plan.enter.target.X, plan.enter.target.Y)
		s.visual_pos = Vector(s.pos.X, s.pos.Y)
		s.grid_col = s.grid_col
		next_slots[1] = s
	end

	for _, mv in ipairs(plan.moves) do
		local s = mv.slot
		s.row = mv.new_row
		s.pos = Vector(mv.target.X, mv.target.Y)
		s.visual_pos = Vector(mv.target.X, mv.target.Y)
		if mv.new_col then s.grid_col = mv.new_col end
		next_slots[mv.new_row] = s
	end

	if plan.exit and plan.exit.slot then
		local s = plan.exit.slot
		occupancy.clear_blocker(blocker_id(s.id))
		s.exiting = true
	end

	local compact = {}
	for i = 1, n do
		compact[i] = next_slots[i]
		if not compact[i] then
			local row = layout[i]
			local sample = (side.side == "left" and row.left[1] or row.right[1])
			local pos = sample and sample.pos or Vector(0, row.y_world)
			compact[i] = make_slot(side.side, i, pos, { state = SLOT.EMPTY })
			compact[i].state = SLOT.EMPTY
		end
	end
	side.slots = compact
	refresh_blockers_side(side)
end

local function commit_stray_logic(plan)
	if not plan then return end
	local exiting_ids = {}
	for _, ex in ipairs(plan.exits or {}) do
		if ex.slot then
			exiting_ids[ex.slot.id] = true
			occupancy.clear_blocker(stray_blocker_id(ex.slot.id))
			ex.slot.exiting = true
		end
	end
	local keep = {}
	for _, mv in ipairs(plan.moves or {}) do
		local s = mv.slot
		if s and not exiting_ids[s.id] then
			s.pos = Vector(mv.target.X, mv.target.Y)
			s.visual_pos = Vector(mv.target.X, mv.target.Y)
			keep[#keep + 1] = s
		end
	end
	-- Exiting strays leave the list; fx lives on exit_pending until off-screen.
	state.strays = keep
	refresh_stray_blockers()
end

local function collect_exits(left_plan, right_plan, stray_plan)
	local list = {}
	if left_plan and left_plan.exit and left_plan.exit.slot and left_plan.exit.slot.state ~= SLOT.EMPTY then
		list[#list + 1] = left_plan.exit
	end
	if right_plan and right_plan.exit and right_plan.exit.slot and right_plan.exit.slot.state ~= SLOT.EMPTY then
		list[#list + 1] = right_plan.exit
	end
	for _, ex in ipairs((stray_plan and stray_plan.exits) or {}) do
		if ex.slot and ex.slot.state ~= SLOT.EMPTY then
			list[#list + 1] = ex
		end
	end
	return list
end

local function finish_exit(ex)
	if not ex or not ex.slot then return end
	local s = ex.slot
	if s.is_stray then
		occupancy.clear_blocker(stray_blocker_id(s.id))
	else
		occupancy.clear_blocker(blocker_id(s.id))
	end
	if s.fx then
		piece_matte.remove(s.fx)
		s.fx = nil
	end
	s.exiting = false
	s.state = SLOT.EMPTY
end

local function tick_exit_flight(durs)
	local m = state.motion
	local pending = m.exit_pending or {}
	if #pending < 1 then
		return true
	end
	local keep = {}
	for _, ex in ipairs(pending) do
		ex.fly_elapsed = (ex.fly_elapsed or 0) + 1
		local t = ex.fly_elapsed / 20
		local ground = lerp_vec(ex.transfer_target, ex.fly_target, ease_in(math.min(1, t)))
		if t > 1 then
			ground = Vector(ex.fly_target.X, ex.fly_target.Y + (t - 1) * 140)
		end
		local h = (durs.height or 32) * math.max(0, 1 - 0.5 * math.min(1, t))
		if ex.slot and ex.slot.state ~= SLOT.EMPTY then
			ex.slot.visual_pos = ground
			ex.slot.visual_height = h
			spawn_matte_at(ex.slot, ground)
		end
		local done = is_screen_fully_below(ground, h)
			or ex.fly_elapsed >= (durs.exit_fly_max or 90)
		if done then
			finish_exit(ex)
		else
			keep[#keep + 1] = ex
		end
	end
	m.exit_pending = keep
	return #keep < 1
end

function columns.step_once()
	if not state.active then
		return false, "inactive"
	end
	if columns.is_motion_busy() then
		return false, "busy"
	end
	if not state.entrance_done then
		return false, "entrance"
	end
	local durs = motion_cfg_durations()
	local layout = arena.p2_row_layout(durs.band)
	if not layout or #layout < 1 then
		return false, "no_rows"
	end
	state.motion.cycle_id = state.motion.cycle_id + 1
	state.motion.layout = layout
	state.motion.logic_committed = false
	state.motion.left_plan = build_side_plan(state.left, layout, durs)
	state.motion.right_plan = build_side_plan(state.right, layout, durs)
	state.motion.stray_plan = build_stray_plan(durs)
	state.motion.exit_pending = {}
	state.step_elapsed = 0
	set_motion_phase(PHASE.LIFT)
	apply_visuals_for_plan(state.motion.left_plan, 0, 0, 0, PHASE.LIFT)
	apply_visuals_for_plan(state.motion.right_plan, 0, 0, 0, PHASE.LIFT)
	apply_visuals_for_plan(state.motion.stray_plan, 0, 0, 0, PHASE.LIFT)
	return true
end

local function tick_entrance()
	local m = state.motion
	local durs = motion_cfg_durations()
	m.elapsed = (m.elapsed or 0) + 1
	local e = m.elapsed
	local height = durs.height

	if m.phase == PHASE.ENTRANCE_FLY then
		local t = e / math.max(1, durs.entrance_fly)
		apply_entrance_visuals(math.min(1, t), height, PHASE.ENTRANCE_FLY)
		if e >= durs.entrance_fly then
			set_motion_phase(PHASE.ENTRANCE_HOVER)
		end
		return
	end
	if m.phase == PHASE.ENTRANCE_HOVER then
		apply_entrance_visuals(1, height, PHASE.ENTRANCE_HOVER)
		if e >= durs.entrance_hover then
			set_motion_phase(PHASE.ENTRANCE_LAND)
		end
		return
	end
	if m.phase == PHASE.ENTRANCE_LAND then
		local t = e / math.max(1, durs.entrance_land)
		apply_entrance_visuals(math.min(1, t), height, PHASE.ENTRANCE_LAND)
		if e >= durs.entrance_land then
			apply_entrance_visuals(1, 0, PHASE.ENTRANCE_SETTLE)
			set_motion_phase(PHASE.ENTRANCE_SETTLE)
		end
		return
	end
	if m.phase == PHASE.ENTRANCE_SETTLE then
		apply_entrance_visuals(1, 0, PHASE.ENTRANCE_SETTLE)
		if e >= durs.entrance_settle then
			for _, side in ipairs({ state.left, state.right }) do
				for _, slot in ipairs(side.slots) do
					slot.entering = false
					slot.visual_height = 0
					slot.visual_pos = Vector(slot.pos.X, slot.pos.Y)
					if slot.state ~= SLOT.EMPTY then
						spawn_matte_at(slot, slot.pos)
					end
				end
			end
			refresh_blockers_side(state.left)
			refresh_blockers_side(state.right)
			state.entrance_done = true
			set_motion_phase(PHASE.IDLE)
		end
	end
end

local function tick_motion()
	local m = state.motion
	if m.phase == PHASE.IDLE then
		return
	end
	if columns.is_entrance_busy() then
		tick_entrance()
		return
	end

	local durs = motion_cfg_durations()
	m.elapsed = (m.elapsed or 0) + 1
	local e = m.elapsed
	local height = durs.height

	if m.phase == PHASE.LIFT then
		local t = ease_out(e / math.max(1, durs.lift))
		local h = height * t
		apply_visuals_for_plan(m.left_plan, h, 0, 0, PHASE.LIFT)
		apply_visuals_for_plan(m.right_plan, h, 0, 0, PHASE.LIFT)
		apply_visuals_for_plan(m.stray_plan, h, 0, 0, PHASE.LIFT)
		if e >= durs.lift then
			set_motion_phase(PHASE.HOVER)
		end
		return
	end

	if m.phase == PHASE.HOVER then
		apply_visuals_for_plan(m.left_plan, height, 0, 0, PHASE.HOVER)
		apply_visuals_for_plan(m.right_plan, height, 0, 0, PHASE.HOVER)
		apply_visuals_for_plan(m.stray_plan, height, 0, 0, PHASE.HOVER)
		if e >= durs.hover then
			set_motion_phase(PHASE.TRANSFER)
		end
		return
	end

	if m.phase == PHASE.TRANSFER then
		local t = ease_out(e / math.max(1, durs.transfer))
		apply_visuals_for_plan(m.left_plan, height, t, 0, PHASE.TRANSFER)
		apply_visuals_for_plan(m.right_plan, height, t, 0, PHASE.TRANSFER)
		apply_visuals_for_plan(m.stray_plan, height, t, 0, PHASE.TRANSFER)
		if e >= durs.transfer then
			if not m.logic_committed then
				m.exit_pending = collect_exits(m.left_plan, m.right_plan, m.stray_plan)
				commit_logic(m.left_plan, state.left, m.layout)
				commit_logic(m.right_plan, state.right, m.layout)
				commit_stray_logic(m.stray_plan)
				-- Detach exits so LAND land-snap does not fight screen-exit flight.
				if m.left_plan then m.left_plan.exit = nil end
				if m.right_plan then m.right_plan.exit = nil end
				if m.stray_plan then m.stray_plan.exits = {} end
				m.logic_committed = true
			end
			set_motion_phase(PHASE.LAND)
		end
		return
	end

	if m.phase == PHASE.LAND then
		local t = e / math.max(1, durs.land)
		apply_visuals_for_plan(m.left_plan, height, 1, math.min(1, t), PHASE.LAND)
		apply_visuals_for_plan(m.right_plan, height, 1, math.min(1, t), PHASE.LAND)
		apply_visuals_for_plan(m.stray_plan, height, 1, math.min(1, t), PHASE.LAND)
		local exits_done = true
		if m.exit_pending and #m.exit_pending > 0 then
			exits_done = tick_exit_flight(durs)
		end
		if e >= durs.land and exits_done then
			apply_visuals_for_plan(m.left_plan, 0, 1, 1, PHASE.SETTLE)
			apply_visuals_for_plan(m.right_plan, 0, 1, 1, PHASE.SETTLE)
			apply_visuals_for_plan(m.stray_plan, 0, 1, 1, PHASE.SETTLE)
			set_motion_phase(PHASE.SETTLE)
		end
		return
	end

	if m.phase == PHASE.SETTLE then
		apply_visuals_for_plan(m.left_plan, 0, 1, 1, PHASE.SETTLE)
		apply_visuals_for_plan(m.right_plan, 0, 1, 1, PHASE.SETTLE)
		apply_visuals_for_plan(m.stray_plan, 0, 1, 1, PHASE.SETTLE)
		if e >= durs.settle then
			m.left_plan = nil
			m.right_plan = nil
			m.stray_plan = nil
			m.exit_pending = {}
			m.logic_committed = false
			set_motion_phase(PHASE.IDLE)
			refresh_blockers_side(state.left)
			refresh_blockers_side(state.right)
			refresh_stray_blockers()
		end
		return
	end
end

local function contact_players()
	if not state.entrance_done then
		return
	end
	local room = Game():GetRoom()
	local center_x = room:GetCenterPos().X
	local radius = soft_collision.default_radius()
	local strength = soft_collision.default_strength()
	local dmg = cfg().CONTACT_DAMAGE or 1
	local marching = columns.is_motion_busy()

	local function slot_ground(slot)
		return slot.visual_pos or slot.pos
	end

	local function can_push(slot)
		if not slot or not slot_ground(slot) then return false end
		if slot.state ~= SLOT.MATTE and slot.state ~= SLOT.TARGET_LOCKED then return false end
		if marching then return true end
		return (slot.visual_height or 0) <= 0.5
	end

	local function can_damage(slot)
		if marching then return false end
		if not slot or (slot.visual_height or 0) > 0.5 then return false end
		return slot.state == SLOT.MATTE or slot.state == SLOT.TARGET_LOCKED
	end

	local function try_list(list, player)
		for _, slot in ipairs(list) do
			local ground = slot_ground(slot)
			if can_push(slot) and soft_collision.push_player(player, ground, center_x, strength, radius) then
				if can_damage(slot) then
					local src = (slot.fx and EntityRef(slot.fx)) or EntityRef(nil)
					player:TakeDamage(dmg, 0, src, 0)
				end
				return true
			end
		end
		return false
	end

	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player and player:Exists() and not player:IsDead() then
			if not try_list(state.left.slots, player) then
				if not try_list(state.right.slots, player) then
					try_list(state.strays, player)
				end
			end
		end
	end
end

function columns.tick()
	if not state.active then
		return
	end

	if not state.paused then
		tick_motion()
	elseif columns.is_motion_busy() then
		local m = state.motion
		local durs = motion_cfg_durations()
		local h = durs.height
		if m.phase == PHASE.SETTLE or m.phase == PHASE.IDLE
			or m.phase == PHASE.ENTRANCE_SETTLE then
			h = 0
		elseif m.phase == PHASE.LIFT or m.phase == PHASE.ENTRANCE_FLY then
			h = durs.height * ease_out((m.elapsed or 0) / math.max(1, durs.lift))
		end
		if columns.is_entrance_busy() then
			apply_entrance_visuals(1, h, m.phase)
		else
			apply_visuals_for_plan(m.left_plan, h, 1, 0, m.phase)
			apply_visuals_for_plan(m.right_plan, h, 1, 0, m.phase)
			apply_visuals_for_plan(m.stray_plan, h, 1, 0, m.phase)
		end
	else
		for _, slot in ipairs(state.left.slots) do
			if slot.state ~= SLOT.EMPTY then
				spawn_matte_at(slot, slot.visual_pos or slot.pos)
			end
		end
		for _, slot in ipairs(state.right.slots) do
			if slot.state ~= SLOT.EMPTY then
				spawn_matte_at(slot, slot.visual_pos or slot.pos)
			end
		end
		for _, slot in ipairs(state.strays) do
			if slot.state ~= SLOT.EMPTY then
				spawn_matte_at(slot, slot.visual_pos or slot.pos)
			end
		end
	end

	if not columns.is_motion_busy() then
		refresh_blockers_side(state.left)
		refresh_blockers_side(state.right)
		refresh_stray_blockers()
	end
	contact_players()

	if state.paused or columns.is_motion_busy() then
		return
	end
	state.step_elapsed = state.step_elapsed + 1
	if state.step_elapsed >= state.step_interval then
		columns.step_once()
	end
end

function columns.pick_matte(side_name)
	if columns.is_motion_busy() or not state.entrance_done then
		return nil
	end
	local side = columns.get_side(side_name)
	local candidates = {}
	for _, slot in ipairs(side.slots) do
		if slot.state == SLOT.MATTE
			and (slot.visual_height or 0) <= 0.5
			and not slot.promote_token
			and not slot.exiting
			and not slot.entering then
			candidates[#candidates + 1] = slot
		end
	end
	if #candidates < 1 then
		return nil
	end
	return candidates[math.ceil(#candidates / 2)]
end

function columns.debug_set_phase(phase_name)
	if not state.active then
		return false, "inactive"
	end
	phase_name = tostring(phase_name or "")
	if phase_name == PHASE.IDLE then
		state.motion.left_plan = nil
		state.motion.right_plan = nil
		state.motion.stray_plan = nil
		state.motion.exit_pending = {}
		state.motion.logic_committed = false
		set_motion_phase(PHASE.IDLE)
		state.entrance_done = true
		return true, PHASE.IDLE
	end
	if columns.is_entrance_busy() then
		-- Fast-forward entrance to done before march debug.
		state.entrance_done = true
		for _, side in ipairs({ state.left, state.right }) do
			for _, slot in ipairs(side.slots) do
				slot.entering = false
				slot.visual_height = 0
				slot.visual_pos = Vector(slot.pos.X, slot.pos.Y)
				if slot.state ~= SLOT.EMPTY then
					spawn_matte_at(slot, slot.pos)
				end
			end
		end
		set_motion_phase(PHASE.IDLE)
	end
	if not columns.is_motion_busy() then
		local ok, why = columns.step_once()
		if not ok then
			return false, why
		end
	end
	local allowed = {
		[PHASE.LIFT] = true,
		[PHASE.HOVER] = true,
		[PHASE.TRANSFER] = true,
		[PHASE.LAND] = true,
		[PHASE.SETTLE] = true,
	}
	if not allowed[phase_name] then
		return false, "bad_phase"
	end
	local m = state.motion
	if (phase_name == PHASE.LAND or phase_name == PHASE.SETTLE) and not m.logic_committed then
		commit_logic(m.left_plan, state.left, m.layout)
		commit_logic(m.right_plan, state.right, m.layout)
		commit_stray_logic(m.stray_plan)
		m.exit_pending = collect_exits(m.left_plan, m.right_plan, m.stray_plan)
		m.logic_committed = true
	end
	set_motion_phase(phase_name)
	return true, phase_name
end

function columns.diag()
	local function side_diag(side)
		local matte, locked, empty = 0, 0, 0
		local cols_used = {}
		local top_y, bot_y = nil, nil
		for _, s in ipairs(side.slots) do
			if s.state == SLOT.MATTE then matte = matte + 1
			elseif s.state == SLOT.TARGET_LOCKED then locked = locked + 1
			elseif s.state == SLOT.EMPTY then empty = empty + 1 end
			if s.grid_col then cols_used[s.grid_col] = true end
			if s.pos then
				if not top_y or s.pos.Y < top_y then top_y = s.pos.Y end
				if not bot_y or s.pos.Y > bot_y then bot_y = s.pos.Y end
			end
		end
		local x = side.slots[1] and side.slots[1].pos and side.slots[1].pos.X
		local ncol = 0
		for _ in pairs(cols_used) do ncol = ncol + 1 end
		return {
			count = #side.slots,
			matte = matte,
			locked = locked,
			empty = empty,
			band_cols = ncol,
			x = x,
			top_y = top_y,
			bot_y = bot_y,
		}
	end
	local m = state.motion
	return {
		active = state.active,
		paused = state.paused,
		entrance_done = state.entrance_done,
		step_elapsed = state.step_elapsed,
		step_interval = state.step_interval,
		motion_phase = m.phase,
		motion_elapsed = m.elapsed,
		motion_cycle = m.cycle_id,
		logic_committed = m.logic_committed == true,
		strays = #state.strays,
		exit_pending = #(m.exit_pending or {}),
		left = side_diag(state.left),
		right = side_diag(state.right),
	}
end

columns.SLOT = SLOT
columns.PHASE = PHASE

return columns
