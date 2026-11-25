-- P2 dual promotion chase: lock matte → red command → ghost morph → chase → reverse morph demote.

local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")
local piece_defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")
local piece_controller = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_controller")
local particles = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.command_particles")
local piece_matte = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.piece_matte_fx")
local visual = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.visual")
local columns = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_columns")
local occupancy = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_occupancy")

local promo = {}

local KIND_MAP = {
	knight = piece_defs.KIND.KNIGHT,
	bishop = piece_defs.KIND.BISHOP,
	vehicle = piece_defs.KIND.VEHICLE,
	queen = piece_defs.KIND.QUEEN,
}

local state = {
	cycle_elapsed = 0,
	cycle_target = 200,
	phase = "IDLE",
	cast_left = 0,
	cast_queued = false, -- cycle expired while columns marching; wait for IDLE
	active = {},
	pending = {}, -- inbound particle jobs { slot_id, token, session }
	morphing = {}, -- promote morph jobs before NPC handoff
	force_kind = nil,
	session = 0,
	first_cycle_pending = true,
}

local function cfg()
	return defs.P2_PROMOTION or {}
end

local function rng()
	local r = RNG()
	r:SetSeed(Random() + 1, 35)
	return r
end

local function pick_weighted_kind(forced)
	if forced and KIND_MAP[forced] then
		return KIND_MAP[forced], forced
	end
	local weights = cfg().WEIGHTS or {}
	local total = 0
	local order = { "knight", "bishop", "vehicle", "queen" }
	for i = 1, #order do
		total = total + (weights[order[i]] or 0)
	end
	if total < 1 then
		return piece_defs.KIND.KNIGHT, "knight"
	end
	local roll = rng():RandomInt(total)
	local acc = 0
	for i = 1, #order do
		acc = acc + (weights[order[i]] or 0)
		if roll < acc then
			return KIND_MAP[order[i]], order[i]
		end
	end
	return piece_defs.KIND.KNIGHT, "knight"
end

local function player_pos()
	local p = Game():GetPlayer(0)
	if p and p:Exists() and not p:IsDead() then
		return p.Position
	end
	return Game():GetRoom():GetCenterPos()
end

local function strategy_cells(from, toward)
	local grid = piece_defs.GRID or 40
	local dx = math.abs(toward.X - from.X) / grid
	local dy = math.abs(toward.Y - from.Y) / grid
	return math.max(1, math.floor(dx + dy + 0.5))
end

local function pick_landing(from, kind, toward)
	local landings = piece_controller.legal_landings_at(from, kind, nil)
	if #landings < 1 then
		return nil
	end
	local best, best_d = landings[1], (landings[1] - toward):LengthSquared()
	for i = 2, #landings do
		local d2 = (landings[i] - toward):LengthSquared()
		if d2 < best_d then
			best_d = d2
			best = landings[i]
		end
	end
	return best
end

local function cadence_for_distance(cells)
	local cad = cfg().CADENCE or {}
	local near = cad.near or { wait = 12, travel = 9 }
	local mid = cad.mid or { wait = 10, travel = 8 }
	local far = cad.far or { wait = 8, travel = 7 }
	if cells <= 1 then
		return near.wait or 12, near.travel or 9
	elseif cells <= 3 then
		return mid.wait or 10, mid.travel or 8
	end
	return far.wait or 8, far.travel or 7
end

local function new_cycle_target()
	local c = cfg()
	if state.first_cycle_pending then
		state.first_cycle_pending = false
		local base = c.FIRST_CYCLE_MIN or 15
		local span = c.FIRST_CYCLE_SPAN or 16
		return base + rng():RandomInt(math.max(1, span))
	end
	local base = c.CYCLE_MIN or 105
	local span = c.CYCLE_SPAN or 30
	return base + rng():RandomInt(math.max(1, span))
end

local function active_budget_used()
	return #state.active + #state.pending + #state.morphing
end

local function morph_cfg()
	local m = cfg().MORPH or {}
	return {
		ghost = m.GHOST or 6,
		squash = m.SQUASH or 6,
		grow = m.GROW or 10,
		settle = m.SETTLE or 4,
	}
end

local function morph_total()
	local m = morph_cfg()
	return m.ghost + m.squash + m.grow + m.settle
end

local function roll_chase_steps(kind_name)
	local ranges = cfg().CHASE_STEPS_RANGE or {}
	local pair = ranges[kind_name]
	if pair and pair[1] and pair[2] then
		local lo = math.floor(tonumber(pair[1]) or 3)
		local hi = math.floor(tonumber(pair[2]) or lo)
		if hi < lo then
			hi = lo
		end
		return lo + rng():RandomInt(hi - lo + 1)
	end
	local fixed = cfg().CHASE_STEPS or {}
	return math.max(1, math.floor(tonumber(fixed[kind_name]) or 3))
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function clamp01(x)
	if x < 0 then return 0 end
	if x > 1 then return 1 end
	return x
end

local function sync_matte_pose(ent, opts)
	if not ent then
		return
	end
	piece_matte.sync(ent, opts)
end

local function remove_ghost(job)
	if job and job.ghost then
		piece_matte.remove(job.ghost)
		job.ghost = nil
	end
end

local function session_ok(sid)
	return sid == state.session and columns.is_active()
end

local function clear_pending_all()
	for i = 1, #state.pending do
		local job = state.pending[i]
		if job.token then
			particles.cancel_by_token(job.token)
		end
		columns.unlock_target(job.slot_id, job.token)
	end
	state.pending = {}
	particles.cancel_by_session(state.session)
end

function promo.reset()
	clear_pending_all()
	for i = 1, #state.morphing do
		remove_ghost(state.morphing[i])
		local job = state.morphing[i]
		if job.token then
			columns.unlock_target(job.slot_id, job.token)
		end
	end
	state.morphing = {}
	for i = 1, #state.active do
		local rec = state.active[i]
		remove_ghost(rec)
		if rec.ent and rec.ent.Exists and rec.ent:Exists() then
			occupancy.unregister(GetPtrHash(rec.ent))
			rec.ent:Remove()
		end
	end
	state.active = {}
	state.phase = "IDLE"
	state.cycle_elapsed = 0
	state.cast_queued = false
	state.first_cycle_pending = true
	state.cycle_target = new_cycle_target()
	state.cast_left = 0
	state.session = state.session + 1
end

--- True while promote cast / particle / morph still owns board mattes (not chase NPCs).
function promo.is_board_busy()
	if state.phase == "CAST" or state.cast_queued then
		return true
	end
	if #state.pending > 0 or #state.morphing > 0 then
		return true
	end
	return false
end

function promo.clear(reason)
	promo.reset()
	return true, reason
end

--- Hand chase NPCs / morph ghosts to evacuate. Returns items + slot ids claimed by morph ghosts
--- so columns can drop the underlying pawn Effect without double-drawing.
function promo.take_evac_entities()
	state.cast_queued = false
	state.phase = "IDLE"
	state.cast_left = 0

	local items = {}
	local claimed_slots = {}
	local seen = {}

	local function push_ent(kind, ent, start, height0, tilt)
		if not ent or not ent.Exists or not ent:Exists() then
			return
		end
		local h = GetPtrHash(ent)
		if seen[h] then
			return
		end
		seen[h] = true
		items[#items + 1] = {
			kind = kind,
			ent = ent,
			start = start or Vector(ent.Position.X, ent.Position.Y),
			height0 = height0 or -(ent.PositionOffset and ent.PositionOffset.Y or 0),
			tilt = tilt or 0,
			elapsed = 0,
			alpha = 1,
		}
	end

	-- Cancel inbound particles; unlock so columns can reclaim or skip as claimed.
	for i = 1, #state.pending do
		local job = state.pending[i]
		if job.token then
			particles.cancel_by_token(job.token)
		end
		if job.slot_id and job.token then
			columns.unlock_target(job.slot_id, job.token)
		end
	end
	state.pending = {}
	particles.cancel_by_session(state.session)

	for i = 1, #state.morphing do
		local job = state.morphing[i]
		local ghost = job.ghost
		job.ghost = nil
		if ghost and ghost.Exists and ghost:Exists() then
			if job.slot_id then
				claimed_slots[job.slot_id] = true
			end
			push_ent("matte", ghost, job.pos and Vector(job.pos.X, job.pos.Y) or nil, 0, 0)
			-- Do not unlock (would respawn pawn matte under the ghost).
			local slot = job.slot_id and columns.get_slot_by_id(job.slot_id)
			if slot then
				slot.promote_token = nil
			end
		elseif job.slot_id and job.token then
			-- No ghost yet: restore matte so columns.take can evacuate the pawn.
			columns.unlock_target(job.slot_id, job.token)
		end
	end
	state.morphing = {}

	for i = 1, #state.active do
		local rec = state.active[i]
		local ghost = rec.ghost
		rec.ghost = nil
		if ghost and ghost.Exists and ghost:Exists() then
			-- Demote morph: evacuate the visible ghost; remove hidden NPC.
			push_ent("matte", ghost,
				rec.ent and Vector(rec.ent.Position.X, rec.ent.Position.Y) or nil, 0, 0)
			if rec.ent and rec.ent.Exists and rec.ent:Exists() then
				occupancy.unregister(GetPtrHash(rec.ent))
				rec.ent:Remove()
			end
		elseif rec.ent and rec.ent.Exists and rec.ent:Exists() then
			freeze_for_demote(rec.ent)
			local spr = rec.ent.GetSprite and rec.ent:GetSprite()
			push_ent("npc", rec.ent,
				Vector(rec.ent.Position.X, rec.ent.Position.Y),
				-(rec.ent.PositionOffset and rec.ent.PositionOffset.Y or 0),
				spr and spr.Rotation or 0)
		end
	end
	state.active = {}
	state.session = state.session + 1
	return items, claimed_slots
end

function promo.set_force_kind(name)
	state.force_kind = name
end

local function freeze_for_demote(ent)
	if not ent then
		return
	end
	local data = ent:GetData().QingChessPiece
	if data then
		data.action_state = "IDLE"
		data.current_command = nil
		data.attack_enabled = false
		data.attack_active = false
		data.p2_demoting = true
	end
	ent.Velocity = Vector.Zero
	if ent.CollisionDamage ~= nil then
		ent.CollisionDamage = 0
	end
	ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	occupancy.unregister(GetPtrHash(ent))
end

local function drop_pending_slot(slot_id)
	local keep = {}
	for i = 1, #state.pending do
		if state.pending[i].slot_id ~= slot_id then
			keep[#keep + 1] = state.pending[i]
		end
	end
	state.pending = keep
end

--- Single entity handoff after promote morph finishes.
local function finish_promote_spawn(job)
	local slot_id, token, kind_id, kind_name, sid =
		job.slot_id, job.token, job.kind_id, job.kind_name, job.session
	if not session_ok(sid) then
		columns.unlock_target(slot_id, token)
		remove_ghost(job)
		return nil, "session"
	end
	local slot = columns.get_slot_by_id(slot_id)
	if not slot or slot.state ~= columns.SLOT.TARGET_LOCKED then
		columns.unlock_target(slot_id, token)
		remove_ghost(job)
		return nil, "target_gone"
	end
	if token and slot.promote_token and slot.promote_token ~= token then
		remove_ghost(job)
		return nil, "token_mismatch"
	end

	local pos = Vector(slot.pos.X, slot.pos.Y)
	local from_side = slot.side
	local ent = piece_controller.spawn({
		kind = kind_id,
		position = pos,
		role = piece_defs.ROLE.COMBAT,
		mode = piece_defs.MODE.DIRECTED,
		director_id = defs.DIRECTOR_ID,
		damageable = true,
		no_appear = true,
	})
	if not ent then
		columns.rollback_promote(slot_id, token)
		remove_ghost(job)
		return nil, "spawn_failed"
	end
	local ok_c, why = columns.commit_promote(slot_id, token)
	if not ok_c then
		occupancy.unregister(GetPtrHash(ent))
		ent:Remove()
		columns.rollback_promote(slot_id, token)
		remove_ghost(job)
		return nil, why or "commit_failed"
	end
	remove_ghost(job)

	local rec = {
		ent = ent,
		ptr = GetPtrHash(ent),
		kind = kind_id,
		kind_name = kind_name,
		from_side = from_side,
		steps_left = job.steps_left or roll_chase_steps(kind_name),
		wait_left = job.stagger or 0,
		phase = "WINDUP",
		slot_id = slot_id,
		session = sid,
	}
	return rec
end

local function begin_promote_morph(slot_id, token, kind_id, kind_name, stagger, sid)
	if not session_ok(sid) then
		columns.unlock_target(slot_id, token)
		return nil, "session"
	end
	local slot = columns.get_slot_by_id(slot_id)
	if not slot or slot.state ~= columns.SLOT.TARGET_LOCKED then
		columns.unlock_target(slot_id, token)
		return nil, "target_gone"
	end
	local pos = Vector(slot.pos.X, slot.pos.Y)
	local ghost = piece_matte.spawn(kind_id, pos, {
		owner = "floraine_p2_promote_ghost",
		color_progress = 0.55,
		outline_alpha = 0.35,
		outline_rgb = { 1.0, 0.35, 0.4 },
		scale_x = 1,
		scale_y = 1,
	})
	if ghost then
		sync_matte_pose(ghost, {
			ground_pos = pos,
			body_color = Color(1, 0.85, 0.85, 0, 0.15, 0.02, 0.02),
			outline_alpha = 0,
			scale_x = 1,
			scale_y = 1,
		})
	end
	local job = {
		slot_id = slot_id,
		token = token,
		kind_id = kind_id,
		kind_name = kind_name,
		session = sid,
		stagger = stagger or 0,
		steps_left = roll_chase_steps(kind_name),
		elapsed = 0,
		ghost = ghost,
		pos = pos,
	}
	state.morphing[#state.morphing + 1] = job
	drop_pending_slot(slot_id)
	return job
end

local function tick_promote_morph(job)
	if not session_ok(job.session) then
		columns.unlock_target(job.slot_id, job.token)
		remove_ghost(job)
		return false
	end
	local slot = columns.get_slot_by_id(job.slot_id)
	if not slot or slot.state ~= columns.SLOT.TARGET_LOCKED then
		columns.unlock_target(job.slot_id, job.token)
		remove_ghost(job)
		return false
	end

	job.elapsed = (job.elapsed or 0) + 1
	local e = job.elapsed
	local m = morph_cfg()
	local total = morph_total()
	local pos = Vector(slot.pos.X, slot.pos.Y)
	job.pos = pos
	local matte = slot.fx
	local ghost = job.ghost
	local g1 = m.ghost
	local s1 = g1 + m.squash
	local r1 = s1 + m.grow

	if e <= g1 then
		local u = clamp01(e / math.max(1, g1))
		if ghost then
			sync_matte_pose(ghost, {
				ground_pos = pos,
				body_color = Color(1, 0.9, 0.9, 0.55 * u, 0.12, 0.02, 0.02),
				outline_alpha = 0.4 * u,
				outline_rgb = { 1.0, 0.35, 0.4 },
				scale_x = 1,
				scale_y = 1,
			})
		end
		if matte then
			sync_matte_pose(matte, {
				ground_pos = pos,
				color_progress = 0,
				outline_alpha = 0,
				scale_x = 1,
				scale_y = 1,
			})
		end
	elseif e <= s1 then
		local u = clamp01((e - g1) / math.max(1, m.squash))
		if matte then
			sync_matte_pose(matte, {
				ground_pos = pos,
				color_progress = 0,
				outline_alpha = 0,
				scale_x = lerp(1, 1.14, u),
				scale_y = lerp(1, 0.70, u),
			})
		end
		if ghost then
			sync_matte_pose(ghost, {
				ground_pos = pos,
				body_color = Color(1, 0.9, 0.9, 0.55, 0.12, 0.02, 0.02),
				outline_alpha = 0.4,
				outline_rgb = { 1.0, 0.35, 0.4 },
				scale_x = 1,
				scale_y = 1,
			})
		end
	elseif e <= r1 then
		local u = clamp01((e - s1) / math.max(1, m.grow))
		if matte then
			sync_matte_pose(matte, {
				ground_pos = pos,
				body_color = Color(0.85, 0.85, 0.9, 1 - u, 0, 0, 0),
				outline_alpha = 0,
				scale_x = lerp(1.14, 1.05, u),
				scale_y = lerp(0.70, 0.55, u),
			})
		end
		if ghost then
			local grow = (u < 0.7) and lerp(0.82, 1.08, u / 0.7) or lerp(1.08, 1.0, (u - 0.7) / 0.3)
			sync_matte_pose(ghost, {
				ground_pos = pos,
				body_color = Color(1, 1, 1, lerp(0.55, 1, u), 0.05 * (1 - u), 0, 0),
				outline_alpha = lerp(0.4, 0, u),
				outline_rgb = { 1.0, 0.35, 0.4 },
				scale_x = grow,
				scale_y = grow,
			})
		end
	else
		local u = clamp01((e - r1) / math.max(1, m.settle))
		if matte then
			sync_matte_pose(matte, {
				ground_pos = pos,
				body_color = Color(0.85, 0.85, 0.9, 0, 0, 0, 0),
				outline_alpha = 0,
				scale_x = 1,
				scale_y = 1,
				hidden = true,
			})
		end
		if ghost then
			sync_matte_pose(ghost, {
				ground_pos = pos,
				body_color = Color(1, 1, 1, 1, 0, 0, 0),
				outline_alpha = 0,
				scale_x = 1,
				scale_y = 1,
			})
		end
		if u >= 1 or e >= total then
			local rec = finish_promote_spawn(job)
			if rec then
				state.active[#state.active + 1] = rec
			end
			return false
		end
	end
	return true
end

local function fire_at_slot(slot, tip, bias, delay, kind_forced)
	local kind_id, kind_name = pick_weighted_kind(kind_forced or state.force_kind)
	local token, why = columns.lock_target(slot)
	if not token then
		return false, why or "lock_failed"
	end
	local sid = state.session
	local slot_id = slot.id
	state.pending[#state.pending + 1] = {
		slot_id = slot_id,
		token = token,
		session = sid,
		kind_name = kind_name,
	}
	particles.launch({
		start = tip,
		finish = slot.pos,
		preset = "royal",
		control_bias = bias,
		command_id = slot_id,
		token = token,
		session_id = sid,
		finish_follow = function()
			local s = columns.get_slot_by_id(slot_id)
			if s and s.pos then
				return Vector(s.pos.X, s.pos.Y - 10)
			end
			return nil
		end,
		validate = function()
			if not session_ok(sid) then
				return false
			end
			local s = columns.get_slot_by_id(slot_id)
			if not s or s.state ~= columns.SLOT.TARGET_LOCKED then
				return false
			end
			if s.promote_token ~= token then
				return false
			end
			return true
		end,
		on_arrive = function()
			if not session_ok(sid) then
				columns.unlock_target(slot_id, token)
				return
			end
			begin_promote_morph(slot_id, token, kind_id, kind_name, delay, sid)
		end,
	})
	return true, kind_name
end

local function launch_pair(boss_ent)
	local max_active = cfg().MAX_ACTIVE or 4
	local room_left = max_active - active_budget_used()
	if room_left < 1 then
		return false, "at_cap"
	end
	local want = math.min(cfg().PICK_COUNT or 2, room_left)
	local toward = player_pos()
	local targets = columns.pick_promote_targets and columns.pick_promote_targets(want, toward) or {}
	if #targets < 1 then
		-- Fallback: legacy left/right mid picks.
		local left = columns.pick_matte("left")
		local right = columns.pick_matte("right")
		if left then targets[#targets + 1] = left end
		if right and (#targets < want) then targets[#targets + 1] = right end
	end
	if #targets < 1 then
		return false, "no_targets"
	end
	local tip = (visual.staff_tip_world and visual.staff_tip_world(boss_ent))
		or (boss_ent and boss_ent.Position + Vector(-16, -90))
		or Vector.Zero
	if boss_ent and visual.command then
		visual.command(boss_ent)
	end
	local stagger = cfg().HIT_STAGGER or 8
	local any = false
	for i = 1, #targets do
		local slot = targets[i]
		local bias = (slot.side == "left") and -1 or 1
		if slot.is_stray then
			bias = (slot.pos.X < tip.X) and -1 or 1
		end
		local ok = fire_at_slot(slot, tip, bias, (i - 1) * stagger)
		if ok then
			any = true
		end
	end
	if not any then
		return false, "lock_failed"
	end
	return true
end

local function demote_in_place(rec)
	local ent = rec.ent
	if not ent or not ent.Exists or not ent:Exists() then
		remove_ghost(rec)
		return false, "gone"
	end
	local pos = Vector(ent.Position.X, ent.Position.Y)
	freeze_for_demote(ent)
	local stray, why = columns.demote_at(pos)
	remove_ghost(rec)
	if not stray then
		-- Cannot seat: despawn without leaving a matte (no overwrite).
		ent:Remove()
		return false, why or "demote_failed"
	end
	ent:Remove()
	return true, stray
end

local function begin_demote_morph(rec)
	freeze_for_demote(rec.ent)
	local pos = Vector(rec.ent.Position.X, rec.ent.Position.Y)
	local ghost = piece_matte.spawn(piece_defs.KIND.PAWN, pos, {
		owner = "floraine_p2_demote_ghost",
		color_progress = 0,
		outline_alpha = 0,
		scale_x = 1,
		scale_y = 1,
	})
	if ghost then
		sync_matte_pose(ghost, {
			ground_pos = pos,
			body_color = Color(0.85, 0.85, 0.9, 0, 0, 0, 0),
			outline_alpha = 0,
			scale_x = 1,
			scale_y = 1,
		})
	end
	rec.ghost = ghost
	rec.phase = "DEMOTE_MORPH"
	rec.elapsed = 0
	rec.ent.PositionOffset = Vector.Zero
end

local function set_npc_scale(ent, sx, sy)
	if not ent then
		return
	end
	local s = ent:GetSprite()
	if s then
		s.Scale = Vector(sx or 1, sy or 1)
	end
end

local function tick_demote_morph(rec)
	local ent = rec.ent
	if not ent or not ent.Exists or not ent:Exists() then
		remove_ghost(rec)
		return false
	end
	rec.elapsed = (rec.elapsed or 0) + 1
	local e = rec.elapsed
	local m = morph_cfg()
	local total = morph_total()
	local pos = Vector(ent.Position.X, ent.Position.Y)
	local ghost = rec.ghost
	local g1 = m.ghost
	local s1 = g1 + m.squash
	local r1 = s1 + m.grow

	ent.Velocity = Vector.Zero
	ent:SetColor(Color(0.85, 0.85, 0.9, 1, 0, 0, 0), 2, 1, true, false)

	if e <= g1 then
		local u = clamp01(e / math.max(1, g1))
		if ghost then
			sync_matte_pose(ghost, {
				ground_pos = pos,
				body_color = Color(0.85, 0.85, 0.9, 0.5 * u, 0, 0, 0),
				outline_alpha = 0.25 * u,
				outline_rgb = { 0.75, 0.75, 0.8 },
				scale_x = 1,
				scale_y = 1,
			})
		end
		set_npc_scale(ent, 1, 1)
	elseif e <= s1 then
		local u = clamp01((e - g1) / math.max(1, m.squash))
		set_npc_scale(ent, lerp(1, 1.12, u), lerp(1, 0.72, u))
		if ghost then
			sync_matte_pose(ghost, {
				ground_pos = pos,
				body_color = Color(0.85, 0.85, 0.9, 0.5, 0, 0, 0),
				outline_alpha = 0.25,
				outline_rgb = { 0.75, 0.75, 0.8 },
				scale_x = 1,
				scale_y = 1,
			})
		end
	elseif e <= r1 then
		local u = clamp01((e - s1) / math.max(1, m.grow))
		set_npc_scale(ent, lerp(1.12, 0.9, u), lerp(0.72, 0.55, u))
		ent:SetColor(Color(0.85, 0.85, 0.9, 1 - u, 0, 0, 0), 2, 1, true, false)
		if ghost then
			local grow = (u < 0.7) and lerp(0.85, 1.06, u / 0.7) or lerp(1.06, 1.0, (u - 0.7) / 0.3)
			sync_matte_pose(ghost, {
				ground_pos = pos,
				body_color = Color(0.85, 0.85, 0.9, lerp(0.5, 1, u), 0, 0, 0),
				outline_alpha = lerp(0.25, 0, u),
				outline_rgb = { 0.75, 0.75, 0.8 },
				scale_x = grow,
				scale_y = grow,
			})
		end
	else
		set_npc_scale(ent, 1, 1)
		ent:SetColor(Color(0.85, 0.85, 0.9, 0, 0, 0, 0), 2, 1, true, false)
		if e >= total then
			demote_in_place(rec)
			return false
		end
	end
	return true
end

local function tick_chase(rec)
	if not session_ok(rec.session) then
		remove_ghost(rec)
		if rec.ent and rec.ent.Exists and rec.ent:Exists() then
			occupancy.unregister(GetPtrHash(rec.ent))
			rec.ent:Remove()
		end
		return false
	end

	local ent = rec.ent
	if not ent or not ent.Exists or not ent:Exists() or ent:IsDead() then
		remove_ghost(rec)
		if ent and ent.Exists and ent:Exists() then
			occupancy.unregister(GetPtrHash(ent))
		end
		return false
	end

	if rec.phase == "DEMOTE_MORPH" then
		return tick_demote_morph(rec)
	end

	if rec.phase == "WINDUP" then
		rec.wait_left = (rec.wait_left or 0) - 1
		if rec.wait_left > 0 then
			return true
		end
		rec.phase = "CHASE"
	end

	if rec.phase == "CHASE" then
		if piece_controller.is_busy(ent) then
			return true
		end
		if rec.steps_left <= 0 then
			begin_demote_morph(rec)
			return true
		end
		if (rec.wait_left or 0) > 0 then
			rec.wait_left = rec.wait_left - 1
			return true
		end
		local toward = player_pos()
		local cells = strategy_cells(ent.Position, toward)
		local wait, travel = cadence_for_distance(cells)
		local dest = pick_landing(ent.Position, rec.kind, toward)
		rec.wait_left = wait
		rec.steps_left = rec.steps_left - 1
		if dest then
			piece_controller.command(ent, {
				type = "ATTACK",
				destination = dest,
				policy = piece_defs.MOVEMENT_POLICY.NORMAL,
				travel_frames = travel,
			})
		end
		return true
	end

	return true
end

function promo.tick(boss_ent)
	if not columns.is_active() then
		return
	end

	local pend_keep = {}
	for i = 1, #state.pending do
		local job = state.pending[i]
		local slot = columns.get_slot_by_id(job.slot_id)
		if not session_ok(job.session)
			or not slot
			or slot.state ~= columns.SLOT.TARGET_LOCKED then
			particles.cancel_by_token(job.token)
			if slot and slot.state == columns.SLOT.TARGET_LOCKED then
				columns.unlock_target(job.slot_id, job.token)
			end
		else
			pend_keep[#pend_keep + 1] = job
		end
	end
	state.pending = pend_keep

	local morph_keep = {}
	for i = 1, #state.morphing do
		if tick_promote_morph(state.morphing[i]) then
			morph_keep[#morph_keep + 1] = state.morphing[i]
		end
	end
	state.morphing = morph_keep

	local keep = {}
	for i = 1, #state.active do
		if tick_chase(state.active[i]) then
			keep[#keep + 1] = state.active[i]
		end
	end
	state.active = keep

	-- Real combat clock always advances (does not require idle columns).
	state.cycle_elapsed = (state.cycle_elapsed or 0) + 1

	local at_cap = active_budget_used() >= (cfg().MAX_ACTIVE or 4)
	local entrance_busy = columns.is_entrance_busy and columns.is_entrance_busy()
	local marching = columns.is_motion_busy and columns.is_motion_busy()
	-- Cast / lock only when columns are settled (IDLE after SETTLE).
	local function can_arm_cast()
		return (not entrance_busy) and (not marching) and (not at_cap)
	end

	local function begin_cast()
		state.cast_queued = false
		state.phase = "CAST"
		state.cast_left = cfg().CAST_WINDUP or 18
		if boss_ent and visual.command then
			visual.command(boss_ent)
		end
	end

	if state.phase == "CAST" then
		if not can_arm_cast() then
			-- Hold windup without consuming cast_left until columns settle.
			return
		end
		state.cast_left = (state.cast_left or 0) - 1
		if state.cast_left <= 0 then
			local ok = launch_pair(boss_ent)
			if ok then
				state.phase = "IDLE"
				state.cycle_elapsed = 0
				state.cycle_target = new_cycle_target()
			else
				-- Keep trying next frames without resetting the combat clock to zero.
				state.phase = "IDLE"
				state.cast_left = 0
			end
		end
		return
	end

	if state.cast_queued then
		if can_arm_cast() then
			begin_cast()
		end
		return
	end

	if state.cycle_elapsed >= (state.cycle_target or 120) then
		if not can_arm_cast() then
			-- Do not start staff anim mid-march; remember the request.
			state.cast_queued = true
			state.phase = "IDLE"
			return
		end
		begin_cast()
	else
		state.phase = "IDLE"
	end
end

function promo.force_cast(boss_ent)
	if not columns.is_active() then
		return false, "no_columns"
	end
	state.phase = "CAST"
	state.cast_left = 1
	promo.tick(boss_ent)
	return true
end

function promo.force_promote_side(side, kind_name, boss_ent)
	if not columns.is_active() then
		return false, "no_columns"
	end
	local slot = columns.pick_matte(side)
	if not slot then
		return false, "no_slot"
	end
	local tip = (boss_ent and visual.staff_tip_world and visual.staff_tip_world(boss_ent))
		or (boss_ent and boss_ent.Position + Vector(-16, -90))
		or slot.pos
	if boss_ent and visual.command then
		visual.command(boss_ent)
	end
	return fire_at_slot(slot, tip, side == "left" and -1 or 1, 0, kind_name)
end

--- Debug: demote first active chase NPC in place (or spawn a stray at player).
function promo.force_demote_at(pos)
	if #state.active > 0 then
		local rec = state.active[1]
		local ok = demote_in_place(rec)
		if ok then
			local keep = {}
			for i = 2, #state.active do
				keep[#keep + 1] = state.active[i]
			end
			state.active = keep
		end
		return ok
	end
	pos = pos or player_pos()
	local stray, why = columns.demote_at(pos)
	if stray then
		return true, stray
	end
	return false, why
end

function promo.diag()
	local list = {}
	for i = 1, #state.active do
		local r = state.active[i]
		list[#list + 1] = {
			kind = r.kind_name,
			phase = r.phase,
			steps_left = r.steps_left,
			from = r.from_side,
			alive = r.ent and r.ent.Exists and r.ent:Exists() and not r.ent:IsDead(),
		}
	end
	return {
		phase = state.phase,
		session = state.session,
		cycle_elapsed = state.cycle_elapsed,
		cycle_target = state.cycle_target,
		active = #state.active,
		pending = #state.pending,
		morphing = #state.morphing,
		list = list,
		force_kind = state.force_kind,
	}
end

return promo
