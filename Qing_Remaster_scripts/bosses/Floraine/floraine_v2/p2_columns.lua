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

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function lerp_vec(a, b, t)
	return Vector(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t)
end

local function march_cfg()
	return (cfg().MARCH_VISUAL) or {}
end

--- TRANSFER: ~3f accel, cruise, ~3f decel (shared by whole column).
local function ease_march_transfer(t, frames)
	t = math.max(0, math.min(1, t or 0))
	frames = math.max(1, frames or 20)
	local mv = march_cfg()
	local a = math.max(0.01, (mv.TRANSFER_ACCEL or 3) / frames)
	local d = math.max(0.01, (mv.TRANSFER_DECEL or 3) / frames)
	if a + d >= 0.95 then
		a, d = 0.15, 0.15
	end
	local v = 1 / (1 - 0.5 * a - 0.5 * d)
	local cruise_end = 1 - d
	if t < a then
		local u = t / a
		return 0.5 * v * a * u * u
	elseif t <= cruise_end then
		return 0.5 * v * a + v * (t - a)
	end
	local u = (t - cruise_end) / d
	return 0.5 * v * a + v * (cruise_end - a) + v * d * (u - 0.5 * u * u)
end

--- Shared squash / silver outline for on-board march (not entrance / exit flight).
local function compute_march_pose(phase, elapsed, durs)
	local mv = march_cfg()
	local sx, sy = 1, 1
	local oa = 0
	local rgb = mv.OUTLINE_RGB or { 0.85, 0.81, 0.82 }
	local omax = mv.OUTLINE_MAX or 0.80
	elapsed = math.max(0, elapsed or 0)

	if phase == PHASE.LIFT then
		local n = math.max(1, durs.lift or 14)
		local t = math.min(1, elapsed / n)
		local ant_n = math.min(n - 1, mv.ANTICIPATE_FRAMES or 3)
		local ax = mv.ANTICIPATE_X or 1.04
		local ay = mv.ANTICIPATE_Y or 0.94
		local airx = mv.AIR_X or 0.98
		local airy = mv.AIR_Y or 1.05
		if elapsed <= ant_n then
			local u = ant_n > 0 and (elapsed / ant_n) or 1
			sx = lerp(1, ax, u)
			sy = lerp(1, ay, u)
			oa = omax * 0.25 * u
		else
			local u = (elapsed - ant_n) / math.max(1, n - ant_n)
			sx = lerp(ax, airx, ease_out(u))
			sy = lerp(ay, airy, ease_out(u))
			oa = omax * (0.25 + 0.75 * ease_out(u))
		end
	elseif phase == PHASE.HOVER then
		sx = mv.AIR_X or 0.98
		sy = mv.AIR_Y or 1.05
		oa = omax
	elseif phase == PHASE.TRANSFER then
		sx = mv.TRANSFER_X or mv.AIR_X or 0.98
		sy = mv.TRANSFER_Y or 1.04
		oa = omax
	elseif phase == PHASE.LAND then
		local n = math.max(1, durs.land or 14)
		local t = math.min(1, elapsed / n)
		local imp_n = math.min(n, mv.IMPACT_FRAMES or 3)
		local airx = mv.TRANSFER_X or mv.AIR_X or 0.98
		local airy = mv.TRANSFER_Y or mv.AIR_Y or 1.04
		local ix = mv.IMPACT_X or 1.10
		local iy = mv.IMPACT_Y or 0.88
		if elapsed > n - imp_n then
			local u = imp_n > 0 and ((elapsed - (n - imp_n)) / imp_n) or 1
			sx = lerp(airx, ix, u)
			sy = lerp(airy, iy, u)
		else
			local u = (n - imp_n) > 0 and (elapsed / (n - imp_n)) or 1
			sx = airx
			sy = airy
			-- Slight pre-impact lean as height drops.
			sx = lerp(airx, ix, 0.15 * ease_in(u))
			sy = lerp(airy, iy, 0.15 * ease_in(u))
		end
		oa = omax * (1 - 0.35 * t)
	elseif phase == PHASE.SETTLE then
		local n = math.max(1, durs.settle or 10)
		local reb_n = math.min(n, mv.REBOUND_FRAMES or 3)
		local ix = mv.IMPACT_X or 1.10
		local iy = mv.IMPACT_Y or 0.88
		local rx = mv.REBOUND_X or 0.97
		local ry = mv.REBOUND_Y or 1.04
		if elapsed <= reb_n then
			local u = reb_n > 0 and (elapsed / reb_n) or 1
			sx = lerp(ix, rx, u)
			sy = lerp(iy, ry, u)
			oa = omax * 0.45 * (1 - u)
		else
			local u = (n - reb_n) > 0 and ((elapsed - reb_n) / (n - reb_n)) or 1
			sx = lerp(rx, 1, ease_out(u))
			sy = lerp(ry, 1, ease_out(u))
			oa = 0
		end
	end

	return {
		scale_x = sx,
		scale_y = sy,
		outline_alpha = oa,
		outline_rgb = rgb,
	}
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
	-- Promote lock red outline always wins over march silver.
	local outline_a, outline_rgb
	if slot.state == SLOT.TARGET_LOCKED then
		outline_a = 0.55
		outline_rgb = { 1, 0.2, 0.25 }
	else
		outline_a = slot.march_outline_alpha or 0
		outline_rgb = slot.march_outline_rgb
	end
	local sx = slot.march_scale_x or 1
	local sy = slot.march_scale_y or 1
	local opts = {
		ground_pos = ground_pos,
		visual_height = slot.visual_height or 0,
		color_progress = 0,
		outline_alpha = outline_a,
		outline_rgb = outline_rgb,
		scale_x = sx,
		scale_y = sy,
	}
	if slot.fx and slot.fx.Exists and slot.fx:Exists() then
		piece_matte.sync(slot.fx, opts)
		return slot.fx
	end
	local ent = piece_matte.spawn(piece_defs.KIND.PAWN, ground_pos, {
		owner = slot.is_stray and STRAY_OWNER or OWNER,
		piece_id = slot.id,
		color_progress = 0,
		outline_alpha = outline_a,
		outline_rgb = outline_rgb,
		visual_height = slot.visual_height or 0,
		scale_x = sx,
		scale_y = sy,
	})
	slot.fx = ent
	return ent
end

local function apply_pose_to_slot(slot, pose, skip_march)
	if not slot then
		return
	end
	if skip_march or not pose then
		slot.march_scale_x = 1
		slot.march_scale_y = 1
		slot.march_outline_alpha = 0
		slot.march_outline_rgb = nil
		return
	end
	slot.march_scale_x = pose.scale_x or 1
	slot.march_scale_y = pose.scale_y or 1
	slot.march_outline_alpha = pose.outline_alpha or 0
	slot.march_outline_rgb = pose.outline_rgb
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
	local spawn_ground = opts.spawn_ground
	local slot = {
		id = new_id(),
		side = side_name,
		row = row,
		grid_col = opts.grid_col,
		state = opts.state or SLOT.MATTE,
		kind = "pawn",
		pos = Vector(pos.X, pos.Y),
		visual_pos = spawn_ground and Vector(spawn_ground.X, spawn_ground.Y) or Vector(pos.X, pos.Y),
		visual_height = opts.visual_height or 0,
		promote_token = nil,
		fx = opts.adopt_fx,
		exiting = false,
		entering = opts.entering == true,
		is_stray = opts.is_stray == true,
	}
	if opts.defer_spawn then
		return slot
	end
	if slot.state == SLOT.MATTE or slot.state == SLOT.TARGET_LOCKED then
		if opts.adopt_fx and opts.adopt_fx.Exists and opts.adopt_fx:Exists() then
			slot.fx = opts.adopt_fx
			spawn_matte_at(slot, slot.visual_pos)
		else
			spawn_matte_at(slot, slot.visual_pos)
		end
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

local function sprite_half()
	return (cfg().SPRITE_HALF or 24)
end

local function is_screen_fully_below(ground, visual_height)
	return arena.is_sprite_fully_below_screen(ground, visual_height, sprite_half(), 48)
end

--- Full sprite starts beyond the real camera edge (not merely room bounds ±80).
local function offscreen_start(side_name, target, _side_offset)
	local half = sprite_half()
	if side_name == "left" then
		return arena.world_offscreen_left(target.Y, half, 8)
	end
	return arena.world_offscreen_right(target.Y, half, 8)
end

local function offscreen_above(target)
	return arena.world_offscreen_above(target.X, 48, 8)
end

local function offscreen_below(target)
	return arena.world_offscreen_below(target.X, 8, 8)
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
			local start = play_entrance and offscreen_start("left", lo.pos) or nil
			local slot = make_slot("left", i, lo.pos, {
				grid_col = lo.col,
				visual_height = play_entrance and durs.height or 0,
				entering = play_entrance,
				spawn_ground = start,
			})
			state.left.slots[i] = slot
		end
		if ro then
			right_avoid = ro.col
			local start = play_entrance and offscreen_start("right", ro.pos) or nil
			local slot = make_slot("right", i, ro.pos, {
				grid_col = ro.col,
				visual_height = play_entrance and durs.height or 0,
				entering = play_entrance,
				spawn_ground = start,
			})
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
	-- Finish in-flight exits so their Effects are not orphaned across rebuilds.
	for _, ex in ipairs(state.motion.exit_pending or {}) do
		local s = ex and ex.slot
		if s then
			if s.id then
				occupancy.clear_blocker(stray_blocker_id(s.id))
				occupancy.clear_blocker(blocker_id(s.id))
			end
			if s.fx then
				piece_matte.remove(s.fx)
				s.fx = nil
			end
			s.exiting = false
			s.state = SLOT.EMPTY
		end
	end
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

--- Stop writing poses so phase_transition can own visuals. Does not remove Effects.
--- Keeps slot.visual_pos / visual_height / fx pose intact for handoff continuity.
function columns.freeze_for_evac()
	state.paused = true
	state.motion.phase = PHASE.IDLE
	state.motion.elapsed = 0
	-- Drop march plans only; do not rewrite slot visual_pos (mid-TRANSFER must keep last shown pose).
	state.motion.left_plan = nil
	state.motion.right_plan = nil
	state.motion.stray_plan = nil
	state.motion.logic_committed = false
end

--- Hand visible column / stray / exit Effects to the evacuate driver (ownership transfer).
--- skip_ids: optional set of slot.id already claimed by promotion morph visuals.
function columns.take_evac_entities(skip_ids)
	skip_ids = skip_ids or {}
	columns.freeze_for_evac()
	local items = {}
	local seen = {}

	local function take_fx(slot, force)
		if not slot then
			return
		end
		if slot.id and skip_ids[slot.id] then
			-- Promote morph owns the visible ghost; drop pawn Effect quietly.
			if slot.fx then
				piece_matte.remove(slot.fx)
				slot.fx = nil
			end
			if slot.id then
				occupancy.clear_blocker(blocker_id(slot.id))
				occupancy.clear_blocker(stray_blocker_id(slot.id))
			end
			slot.state = SLOT.EMPTY
			slot.exiting = false
			slot.promote_token = nil
			return
		end
		if slot.state == SLOT.EMPTY and not force then
			return
		end
		local fx = slot.fx
		if not fx or not fx.Exists or not fx:Exists() then
			slot.fx = nil
			slot.state = SLOT.EMPTY
			return
		end
		local h = GetPtrHash(fx)
		if seen[h] then
			slot.fx = nil
			return
		end
		seen[h] = true
		-- Live Effect pose = last displayed frame (TRANSFER mid-air). Never snap to slot.pos.
		local ground = Vector(fx.Position.X, fx.Position.Y)
		local height = -(fx.PositionOffset and fx.PositionOffset.Y or 0)
		local spr = fx.GetSprite and fx:GetSprite()
		items[#items + 1] = {
			kind = "matte",
			ent = fx,
			start = Vector(ground.X, ground.Y),
			height0 = height or 0,
			tilt = (spr and spr.Rotation) or 0,
			elapsed = 0,
			alpha = 1,
		}
		slot.fx = nil
		if slot.id then
			occupancy.clear_blocker(blocker_id(slot.id))
			occupancy.clear_blocker(stray_blocker_id(slot.id))
		end
		slot.state = SLOT.EMPTY
		slot.exiting = false
		slot.promote_token = nil
	end

	for _, slot in ipairs(state.left.slots or {}) do
		take_fx(slot)
	end
	for _, slot in ipairs(state.right.slots or {}) do
		take_fx(slot)
	end
	for _, slot in ipairs(state.strays or {}) do
		take_fx(slot)
	end
	for _, ex in ipairs(state.motion.exit_pending or {}) do
		if ex and ex.slot then
			take_fx(ex.slot, true)
		end
	end
	state.motion.exit_pending = {}
	state.strays = {}
	return items
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

--- Demote / register a persistent stray matte pawn.
--- opts.gidx + opts.exact: land on that grid only (棋落 commit; no nearby search).
--- opts.adopt_fx: reuse an existing matte Effect (seamless fall → stray).
--- Returns stray slot or nil, why.
function columns.demote_at(pos, opts)
	opts = opts or {}
	if not pos and opts.gidx == nil then
		return nil, "no_pos"
	end
	local keys = occupied_keys()
	local room = Game():GetRoom()
	local land, idx
	if opts.gidx ~= nil then
		idx = opts.gidx
		local p = room:GetGridPosition(idx)
		land = Vector(p.X, p.Y)
		local col = room:GetGridCollision(idx)
		if col ~= GridCollisionClass.COLLISION_NONE then
			return nil, "blocked"
		end
		if keys[idx] and opts.exact then
			return nil, "occupied"
		end
		if keys[idx] and not opts.exact then
			-- Fall through to ring search from this cell.
			pos = land
			land = nil
		end
	end
	if not land then
		land, idx = arena.nearest_walkable(pos, opts.search_radius or 4)
		if not land then
			return nil, "no_cell"
		end
	end
	-- Resolve occupancy conflict: search ring if taken (unless exact gidx already failed).
	if idx and keys[idx] and not opts.exact then
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
		visual_height = opts.visual_height or 0,
		state = SLOT.MATTE,
		adopt_fx = opts.adopt_fx,
		spawn_ground = land,
	})
	slot.side = "stray"
	state.strays[#state.strays + 1] = slot
	refresh_stray_blockers()
	return slot
end

function columns.count_matte()
	local n = 0
	local function add(list)
		for _, s in ipairs(list or {}) do
			if s.state == SLOT.MATTE or s.state == SLOT.TARGET_LOCKED then
				n = n + 1
			end
		end
	end
	add(state.left.slots)
	add(state.right.slots)
	add(state.strays)
	return n
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
	-- Promote-locked pieces stay put; march must wait via is_board_busy, but skip as safety.
	if bottom and bottom.state == SLOT.TARGET_LOCKED then
		-- hold bottom cell occupied for this cycle
	elseif bottom and bottom.state ~= SLOT.EMPTY then
		local start = Vector(bottom.pos.X, bottom.pos.Y)
		local transfer_target = Vector(bottom.pos.X, bottom.pos.Y + (durs.top_offset or 40))
		plan.exit = {
			slot = bottom,
			start = start,
			transfer_target = transfer_target,
			fly_target = offscreen_below(transfer_target),
		}
		bottom.exiting = true
	elseif bottom and bottom.state == SLOT.EMPTY then
		-- Empty hole also scrolls off (no fx).
		local start = Vector(bottom.pos.X, bottom.pos.Y)
		local transfer_target = Vector(bottom.pos.X, bottom.pos.Y + (durs.top_offset or 40))
		plan.exit = {
			slot = bottom,
			start = start,
			transfer_target = transfer_target,
			fly_target = offscreen_below(transfer_target),
			silent = true,
		}
		bottom.exiting = true
	end

	for i = 1, n - 1 do
		local src = old[i]
		if src and src.state ~= SLOT.TARGET_LOCKED and src.state ~= SLOT.EMPTY then
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
		local top_start = offscreen_above(top_target)
		local enter_slot = make_slot(side.side, 1, top_target, {
			grid_col = picked.col,
			visual_height = 0,
			entering = true,
			spawn_ground = top_start,
		})
		plan.enter = {
			slot = enter_slot,
			start = top_start,
			target = top_target,
		}
	end
	return plan
end

--- Strict one-cell down, same X. "exit" only at true column bottom.
local function stray_down_intent(pos)
	if not pos then
		return "exit", nil
	end
	local room = Game():GetRoom()
	local width = room:GetGridWidth()
	local height = room:GetGridHeight()
	local idx = room:GetGridIndex(pos)
	if not idx or idx < 0 then
		return "exit", nil
	end
	local x = idx % width
	local y = math.floor(idx / width)
	local ny = y + 1
	if ny >= height then
		return "exit", nil
	end
	local cell = room:GetGridPosition(ny * width + x)
	local found = arena.nearest_walkable(cell, 0)
	if found and found.Y > pos.Y + 8 then
		return "move", Vector(found.X, found.Y)
	end
	-- Next cell unwalkable: stay unless no further walkable cells remain below.
	for yy = ny + 1, height - 1 do
		local deeper = arena.nearest_walkable(room:GetGridPosition(yy * width + x), 0)
		if deeper then
			return "blocked", nil
		end
	end
	return "exit", nil
end

local function apply_side_plan_cells(plan, vacating, claimed)
	if not plan then
		return
	end
	local room = Game():GetRoom()
	local function mark(pos, tbl)
		if not pos then return end
		local idx = room:GetGridIndex(pos)
		if idx and idx >= 0 then
			tbl[idx] = true
		end
	end
	if plan.exit and plan.exit.slot and plan.exit.slot.state ~= SLOT.EMPTY then
		mark(plan.exit.start or plan.exit.slot.pos, vacating)
	end
	for _, mv in ipairs(plan.moves or {}) do
		mark(mv.start, vacating)
		mark(mv.target, claimed)
	end
	if plan.enter and plan.enter.target then
		mark(plan.enter.target, claimed)
	end
end

--- Batch stray advance: movers vacate for each other; static blockers still stop the column.
local function build_stray_plan(durs, left_plan, right_plan)
	local plan = { moves = {}, exits = {} }
	local room = Game():GetRoom()
	local static_keys = occupied_keys()
	local vacating = {}
	local claimed = {}
	apply_side_plan_cells(left_plan, vacating, claimed)
	apply_side_plan_cells(right_plan, vacating, claimed)

	local intents = {}
	for _, slot in ipairs(state.strays) do
		if slot.state ~= SLOT.EMPTY and not slot.exiting then
			local kind, next_pos = stray_down_intent(slot.pos)
			local start_idx = room:GetGridIndex(slot.pos)
			intents[#intents + 1] = {
				slot = slot,
				kind = kind,
				next_pos = next_pos,
				start_idx = start_idx,
				y = slot.pos.Y,
			}
		end
	end
	-- Bottom-first so a lower mover/exit frees its cell for the piece above.
	table.sort(intents, function(a, b)
		return (a.y or 0) > (b.y or 0)
	end)

	for _, it in ipairs(intents) do
		if it.kind == "exit" then
			local transfer_target = Vector(it.slot.pos.X, it.slot.pos.Y + (durs.top_offset or 40))
			plan.exits[#plan.exits + 1] = {
				slot = it.slot,
				start = Vector(it.slot.pos.X, it.slot.pos.Y),
				transfer_target = transfer_target,
				fly_target = offscreen_below(transfer_target),
			}
			it.slot.exiting = true
			if it.start_idx and it.start_idx >= 0 then
				vacating[it.start_idx] = true
				static_keys[it.start_idx] = nil
			end
		elseif it.kind == "move" and it.next_pos then
			local nidx = room:GetGridIndex(it.next_pos)
			local blocked = false
			if nidx and nidx >= 0 then
				if claimed[nidx] then
					blocked = true
				elseif static_keys[nidx] and not vacating[nidx] then
					blocked = true
				end
			end
			if blocked then
				-- Stay; keep occupying start cell.
			else
				plan.moves[#plan.moves + 1] = {
					slot = it.slot,
					start = Vector(it.slot.pos.X, it.slot.pos.Y),
					target = it.next_pos,
				}
				if it.start_idx and it.start_idx >= 0 then
					vacating[it.start_idx] = true
					static_keys[it.start_idx] = nil
				end
				if nidx and nidx >= 0 then
					claimed[nidx] = true
					static_keys[nidx] = true
				end
			end
		end
		-- "blocked" intent: stay put (mid-column hole).
	end
	return plan
end

local function apply_visuals_for_plan(plan, height, transfer_t, land_t, phase, pose)
	if not plan then
		return
	end
	transfer_t = transfer_t or 0
	land_t = land_t or 0

	local function set_slot(slot, ground, h, skip_march)
		if not slot then return end
		slot.visual_pos = Vector(ground.X, ground.Y)
		slot.visual_height = h or 0
		apply_pose_to_slot(slot, pose, skip_march == true)
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
			-- Accelerate into the ground (heavy stomp), not ease-out float-down.
			h = height * (1 - ease_in(land_t))
		elseif phase == PHASE.SETTLE or phase == PHASE.IDLE then
			h = 0
		end
		set_slot(mv.slot, ground, h, false)
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
			h = height * (1 - ease_in(land_t))
		elseif phase == PHASE.SETTLE or phase == PHASE.IDLE then
			h = 0
		end
		-- Top refill shares the march clock while joining the column.
		set_slot(en.slot, ground, h, false)
	end

	local function apply_exit(ex)
		if not ex or not ex.slot then return end
		local slot = ex.slot
		if phase == PHASE.LIFT or phase == PHASE.HOVER then
			-- Still with the column until logic commit — keep shared march pose.
			set_slot(slot, ex.start, height, false)
		elseif phase == PHASE.TRANSFER then
			set_slot(slot, lerp_vec(ex.start, ex.transfer_target, transfer_t), height, false)
		elseif phase == PHASE.LAND then
			local ground = lerp_vec(ex.transfer_target, ex.fly_target, ease_in(math.min(1, land_t)))
			-- Keep accelerating downward past fly_target.
			if land_t >= 1 then
				local extra = (land_t - 1) * 120
				ground = Vector(ex.fly_target.X, ex.fly_target.Y + extra)
			end
			-- Exit flight: no stomp squash / march outline (screen-leave path).
			set_slot(slot, ground, height * math.max(0, 1 - 0.35 * math.min(1, land_t)), true)
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
	local old = side.slots

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

	-- Promote-locked / unmoved holdovers keep their row.
	for i = 1, n do
		local s = old[i]
		if s and s.state == SLOT.TARGET_LOCKED and not next_slots[i] and not s.exiting then
			next_slots[i] = s
		end
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

--- Persist all non-exiting strays. moves update pos; exits leave the list (fx → exit_pending).
--- Blocked / idle strays must remain in state.strays or they become orphan Effects.
local function commit_stray_logic(plan)
	if not plan then return end

	local moved = {}
	local exiting = {}
	for _, mv in ipairs(plan.moves or {}) do
		if mv.slot and mv.slot.id and mv.target then
			moved[mv.slot.id] = mv.target
		end
	end
	for _, ex in ipairs(plan.exits or {}) do
		if ex.slot and ex.slot.id then
			exiting[ex.slot.id] = true
			occupancy.clear_blocker(stray_blocker_id(ex.slot.id))
			ex.slot.exiting = true
		end
	end

	local keep = {}
	for _, slot in ipairs(state.strays) do
		if exiting[slot.id] then
			-- Leave list; flight continues on exit_pending until off-screen.
		else
			local target = moved[slot.id]
			if target then
				slot.pos = Vector(target.X, target.Y)
				slot.visual_pos = Vector(target.X, target.Y)
			end
			keep[#keep + 1] = slot
		end
	end

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
		-- Refresh off-screen end so camera pans still clear the sprite.
		if (ex.fly_elapsed % 8) == 1 then
			ex.fly_target = offscreen_below(ex.transfer_target or ex.start)
		end
		local t = ex.fly_elapsed / 24
		local ground = lerp_vec(ex.transfer_target, ex.fly_target, ease_in(math.min(1, t)))
		if t > 1 then
			ground = Vector(ex.fly_target.X, ex.fly_target.Y + (t - 1) * 160)
		end
		local h = (durs.height or 32) * math.max(0, 1 - 0.5 * math.min(1, t))
		if ex.slot and ex.slot.state ~= SLOT.EMPTY then
			ex.slot.visual_pos = ground
			ex.slot.visual_height = h
			apply_pose_to_slot(ex.slot, nil, true)
			spawn_matte_at(ex.slot, ground)
		end
		-- Remove only after the full sprite clears the screen (failsafe is very late).
		local done = is_screen_fully_below(ground, h)
			or ex.fly_elapsed >= (durs.exit_fly_max or 300)
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
	-- Wait for promote cast / particle / morph (not chase NPCs). Keep step_elapsed.
	local ok_p, promo = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_promotion")
	if ok_p and promo and promo.is_board_busy and promo.is_board_busy() then
		return false, "promo_busy"
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
	state.motion.stray_plan = build_stray_plan(durs, state.motion.left_plan, state.motion.right_plan)
	-- Keep any in-flight screen exits; next march must not reclaim them.
	state.step_elapsed = 0
	set_motion_phase(PHASE.LIFT)
	local pose0 = compute_march_pose(PHASE.LIFT, 0, durs)
	apply_visuals_for_plan(state.motion.left_plan, 0, 0, 0, PHASE.LIFT, pose0)
	apply_visuals_for_plan(state.motion.right_plan, 0, 0, 0, PHASE.LIFT, pose0)
	apply_visuals_for_plan(state.motion.stray_plan, 0, 0, 0, PHASE.LIFT, pose0)
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
	local durs = motion_cfg_durations()
	-- Screen exits are independent of LAND/SETTLE rebound.
	if m.exit_pending and #m.exit_pending > 0 then
		tick_exit_flight(durs)
	end
	if m.phase == PHASE.IDLE then
		return
	end
	if columns.is_entrance_busy() then
		tick_entrance()
		return
	end

	m.elapsed = (m.elapsed or 0) + 1
	local e = m.elapsed
	local height = durs.height

	if m.phase == PHASE.LIFT then
		local ant_n = (march_cfg().ANTICIPATE_FRAMES or 3)
		local t = ease_out(math.max(0, e - ant_n) / math.max(1, durs.lift - ant_n))
		if e <= ant_n then
			t = 0
		end
		local h = height * t
		local pose = compute_march_pose(PHASE.LIFT, e, durs)
		apply_visuals_for_plan(m.left_plan, h, 0, 0, PHASE.LIFT, pose)
		apply_visuals_for_plan(m.right_plan, h, 0, 0, PHASE.LIFT, pose)
		apply_visuals_for_plan(m.stray_plan, h, 0, 0, PHASE.LIFT, pose)
		if e >= durs.lift then
			set_motion_phase(PHASE.HOVER)
		end
		return
	end

	if m.phase == PHASE.HOVER then
		local pose = compute_march_pose(PHASE.HOVER, e, durs)
		apply_visuals_for_plan(m.left_plan, height, 0, 0, PHASE.HOVER, pose)
		apply_visuals_for_plan(m.right_plan, height, 0, 0, PHASE.HOVER, pose)
		apply_visuals_for_plan(m.stray_plan, height, 0, 0, PHASE.HOVER, pose)
		if e >= durs.hover then
			set_motion_phase(PHASE.TRANSFER)
		end
		return
	end

	if m.phase == PHASE.TRANSFER then
		local t = ease_march_transfer(e / math.max(1, durs.transfer), durs.transfer)
		local pose = compute_march_pose(PHASE.TRANSFER, e, durs)
		apply_visuals_for_plan(m.left_plan, height, t, 0, PHASE.TRANSFER, pose)
		apply_visuals_for_plan(m.right_plan, height, t, 0, PHASE.TRANSFER, pose)
		apply_visuals_for_plan(m.stray_plan, height, t, 0, PHASE.TRANSFER, pose)
		if e >= durs.transfer then
			if not m.logic_committed then
				local fresh = collect_exits(m.left_plan, m.right_plan, m.stray_plan)
				m.exit_pending = m.exit_pending or {}
				for i = 1, #fresh do
					m.exit_pending[#m.exit_pending + 1] = fresh[i]
				end
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
		local pose = compute_march_pose(PHASE.LAND, e, durs)
		apply_visuals_for_plan(m.left_plan, height, 1, math.min(1, t), PHASE.LAND, pose)
		apply_visuals_for_plan(m.right_plan, height, 1, math.min(1, t), PHASE.LAND, pose)
		apply_visuals_for_plan(m.stray_plan, height, 1, math.min(1, t), PHASE.LAND, pose)
		-- Rebound starts when LAND ends; do not wait for off-screen exits.
		if e >= durs.land then
			local pose_s = compute_march_pose(PHASE.SETTLE, 0, durs)
			apply_visuals_for_plan(m.left_plan, 0, 1, 1, PHASE.SETTLE, pose_s)
			apply_visuals_for_plan(m.right_plan, 0, 1, 1, PHASE.SETTLE, pose_s)
			apply_visuals_for_plan(m.stray_plan, 0, 1, 1, PHASE.SETTLE, pose_s)
			set_motion_phase(PHASE.SETTLE)
		end
		return
	end

	if m.phase == PHASE.SETTLE then
		local pose = compute_march_pose(PHASE.SETTLE, e, durs)
		apply_visuals_for_plan(m.left_plan, 0, 1, 1, PHASE.SETTLE, pose)
		apply_visuals_for_plan(m.right_plan, 0, 1, 1, PHASE.SETTLE, pose)
		apply_visuals_for_plan(m.stray_plan, 0, 1, 1, PHASE.SETTLE, pose)
		if e >= durs.settle then
			-- Ensure idle scale / outline cleared.
			local function clear_pose_side(side)
				for _, slot in ipairs(side.slots or {}) do
					apply_pose_to_slot(slot, nil, true)
					if slot.state ~= SLOT.EMPTY then
						spawn_matte_at(slot, slot.pos)
					end
				end
			end
			clear_pose_side(state.left)
			clear_pose_side(state.right)
			for _, slot in ipairs(state.strays) do
				apply_pose_to_slot(slot, nil, true)
				if slot.state ~= SLOT.EMPTY then
					spawn_matte_at(slot, slot.pos)
				end
			end
			m.left_plan = nil
			m.right_plan = nil
			m.stray_plan = nil
			-- exit_pending continues independently until off-screen.
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
	local cd = cfg().CONTACT_COOLDOWN or 30
	local phase = state.motion.phase
	-- Contact damage only while the shared march is in the air / transfer / land windows.
	local damage_phase = phase == PHASE.LIFT
		or phase == PHASE.HOVER
		or phase == PHASE.TRANSFER
		or phase == PHASE.LAND

	local function slot_ground(slot)
		-- Board-plane visual feet (march uses visual_pos during flight).
		return slot.visual_pos or slot.pos
	end

	--- Solid obstacle whenever the matte is on the board (idle or marching).
	local function can_push(slot)
		if not slot or not slot_ground(slot) then return false end
		if slot.exiting then return false end
		if slot.state ~= SLOT.MATTE and slot.state ~= SLOT.TARGET_LOCKED then return false end
		return true
	end

	--- Extra contact damage only during LIFT / HOVER / TRANSFER / LAND.
	local function can_damage(slot)
		if not damage_phase then return false end
		if not can_push(slot) then return false end
		return true
	end

	local function try_list(list, player)
		for _, slot in ipairs(list) do
			local ground = slot_ground(slot)
			if can_push(slot) and soft_collision.push_player(player, ground, center_x, strength, radius) then
				if can_damage(slot) then
					local src = (slot.fx and EntityRef(slot.fx)) or EntityRef(nil)
					player:TakeDamage(dmg, 0, src, cd)
				end
				return true
			end
		end
		return false
	end

	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player and player:Exists() and not player:IsDead() then
			-- Left / right / central strays share the same push + damage rules.
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
			local pose = compute_march_pose(m.phase, m.elapsed or 0, durs)
			apply_visuals_for_plan(m.left_plan, h, 1, 0, m.phase, pose)
			apply_visuals_for_plan(m.right_plan, h, 1, 0, m.phase, pose)
			apply_visuals_for_plan(m.stray_plan, h, 1, 0, m.phase, pose)
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
		-- On promo_busy, leave step_elapsed >= interval so march starts as soon as free.
		columns.step_once()
	end
end

local function is_promote_candidate(slot)
	return slot
		and slot.state == SLOT.MATTE
		and (slot.visual_height or 0) <= 0.5
		and not slot.promote_token
		and not slot.exiting
		and not slot.entering
end

function columns.pick_matte(side_name)
	if columns.is_motion_busy() or not state.entrance_done then
		return nil
	end
	if side_name == "stray" then
		local candidates = {}
		for _, slot in ipairs(state.strays) do
			if is_promote_candidate(slot) then
				candidates[#candidates + 1] = slot
			end
		end
		if #candidates < 1 then
			return nil
		end
		return candidates[math.ceil(#candidates / 2)]
	end
	local side = columns.get_side(side_name)
	local candidates = {}
	for _, slot in ipairs(side.slots) do
		if is_promote_candidate(slot) then
			candidates[#candidates + 1] = slot
		end
	end
	if #candidates < 1 then
		return nil
	end
	return candidates[math.ceil(#candidates / 2)]
end

--- Up to `count` matte targets from left + right + strays, preferring near the player.
function columns.pick_promote_targets(count, toward)
	count = math.max(1, math.floor(tonumber(count) or 2))
	if columns.is_motion_busy() or not state.entrance_done then
		return {}
	end
	toward = toward or Game():GetRoom():GetCenterPos()
	local candidates = {}
	local function collect(list)
		for _, slot in ipairs(list or {}) do
			if is_promote_candidate(slot) and slot.pos then
				candidates[#candidates + 1] = slot
			end
		end
	end
	collect(state.left.slots)
	collect(state.right.slots)
	collect(state.strays)
	table.sort(candidates, function(a, b)
		local da = (a.pos - toward):LengthSquared()
		local db = (b.pos - toward):LengthSquared()
		return da < db
	end)
	local out = {}
	for i = 1, math.min(count, #candidates) do
		out[i] = candidates[i]
	end
	return out
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
