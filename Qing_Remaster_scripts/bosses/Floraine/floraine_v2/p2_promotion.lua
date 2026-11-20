-- P2 dual promotion chase: lock matte → red command → spawn NPC → limited chase → demote in place.

local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")
local piece_defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")
local piece_controller = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_controller")
local particles = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.command_particles")
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
	active = {},
	pending = {}, -- inbound particle jobs { slot_id, token, session }
	force_kind = nil,
	session = 0,
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
	if cells <= 1 then
		return 40, 12
	elseif cells <= 3 then
		return 22, 9
	end
	return 8, 5
end

local function new_cycle_target()
	local c = cfg()
	local base = c.CYCLE_MIN or 180
	local span = c.CYCLE_SPAN or 60
	return base + rng():RandomInt(math.max(1, span))
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
	for i = 1, #state.active do
		local rec = state.active[i]
		if rec.ent and rec.ent.Exists and rec.ent:Exists() then
			occupancy.unregister(GetPtrHash(rec.ent))
			rec.ent:Remove()
		end
	end
	state.active = {}
	state.phase = "IDLE"
	state.cycle_elapsed = 0
	state.cycle_target = new_cycle_target()
	state.cast_left = 0
	state.session = state.session + 1
end

function promo.clear(reason)
	promo.reset()
	return true, reason
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

--- One-shot Poof at a successful promote / demote. Never used for ordinary chase steps.
local function spawn_poof(pos, tint)
	if not pos then
		return nil
	end
	local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, pos, Vector.Zero, nil)
	if fx then
		local s = fx:GetSprite()
		if s then
			if tint == "red" then
				s.Color = Color(1, 0.22, 0.28, 1, 0.45, 0.05, 0.05)
			elseif tint == "grey" then
				s.Color = Color(0.75, 0.75, 0.8, 0.85, 0.05, 0.05, 0.08)
			end
		end
		local eff = fx:ToEffect()
		if eff then
			eff:SetTimeout(20)
		end
	end
	return fx
end

local function spawn_promoted(slot_id, token, kind_id, kind_name, stagger, sid)
	if not session_ok(sid) then
		columns.unlock_target(slot_id, token)
		return nil, "session"
	end
	local slot = columns.get_slot_by_id(slot_id)
	if not slot or slot.state ~= columns.SLOT.TARGET_LOCKED then
		columns.unlock_target(slot_id, token)
		return nil, "target_gone"
	end
	if token and slot.promote_token and slot.promote_token ~= token then
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
	})
	if not ent then
		columns.rollback_promote(slot_id, token)
		return nil, "spawn_failed"
	end
	local ok_c, why = columns.commit_promote(slot_id, token)
	if not ok_c then
		occupancy.unregister(GetPtrHash(ent))
		ent:Remove()
		columns.rollback_promote(slot_id, token)
		return nil, why or "commit_failed"
	end
	spawn_poof(pos, "red")

	local steps = (cfg().CHASE_STEPS and cfg().CHASE_STEPS[kind_name]) or 3
	local rec = {
		ent = ent,
		ptr = GetPtrHash(ent),
		kind = kind_id,
		kind_name = kind_name,
		from_side = from_side,
		steps_left = steps,
		wait_left = stagger or 0,
		phase = "WINDUP",
		slot_id = slot_id,
		session = sid,
	}
	state.active[#state.active + 1] = rec
	local keep = {}
	for i = 1, #state.pending do
		if state.pending[i].slot_id ~= slot_id then
			keep[#keep + 1] = state.pending[i]
		end
	end
	state.pending = keep
	return rec
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
			spawn_promoted(slot_id, token, kind_id, kind_name, delay, sid)
		end,
	})
	return true, kind_name
end

local function launch_pair(boss_ent)
	local left = columns.pick_matte("left")
	local right = columns.pick_matte("right")
	if not left or not right then
		return false, "no_targets"
	end
	local tip = (visual.staff_tip_world and visual.staff_tip_world(boss_ent))
		or (boss_ent and boss_ent.Position + Vector(-16, -90))
		or Vector.Zero
	if boss_ent and visual.command then
		visual.command(boss_ent)
	end
	local stagger = cfg().HIT_STAGGER or 10
	local ok_l = fire_at_slot(left, tip, -1, 0)
	local ok_r = fire_at_slot(right, tip, 1, stagger)
	if not ok_l and not ok_r then
		return false, "lock_failed"
	end
	return true
end

local function demote_in_place(rec)
	local ent = rec.ent
	if not ent or not ent.Exists or not ent:Exists() then
		return false, "gone"
	end
	local pos = Vector(ent.Position.X, ent.Position.Y)
	freeze_for_demote(ent)
	local stray, why = columns.demote_at(pos)
	if not stray then
		-- Cannot seat: despawn without leaving a matte (no overwrite).
		ent:Remove()
		return false, why or "demote_failed"
	end
	spawn_poof(stray.pos or pos, "grey")
	ent:Remove()
	return true, stray
end

local function tick_chase(rec)
	if not session_ok(rec.session) then
		if rec.ent and rec.ent.Exists and rec.ent:Exists() then
			occupancy.unregister(GetPtrHash(rec.ent))
			rec.ent:Remove()
		end
		return false
	end

	local ent = rec.ent
	if not ent or not ent.Exists or not ent:Exists() or ent:IsDead() then
		if ent and ent.Exists and ent:Exists() then
			occupancy.unregister(GetPtrHash(ent))
		end
		return false
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
			rec.phase = "GREY"
			rec.wait_left = cfg().DEMOTE_GREY or 12
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

	if rec.phase == "GREY" then
		rec.wait_left = (rec.wait_left or 0) - 1
		local data = ent:GetData().QingChessPiece
		if data then
			data.attack_enabled = false
		end
		ent:SetColor(Color(0.75, 0.75, 0.8, 1, 0, 0, 0), 8, 1, true, false)
		-- Soft lift while greying.
		local lift_t = 1 - math.max(0, rec.wait_left) / math.max(1, cfg().DEMOTE_GREY or 12)
		ent.PositionOffset = Vector(0, -18 * lift_t)
		ent.Velocity = Vector.Zero
		if rec.wait_left <= 0 then
			demote_in_place(rec)
			return false
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

	local keep = {}
	for i = 1, #state.active do
		if tick_chase(state.active[i]) then
			keep[#keep + 1] = state.active[i]
		end
	end
	state.active = keep

	-- Pause new casts during march / entrance; finish in-flight only.
	local marching = columns.is_motion_busy and columns.is_motion_busy()
	local ready = columns.is_combat_ready and columns.is_combat_ready()

	if state.phase == "CAST" then
		if marching or not ready then
			return
		end
		state.cast_left = (state.cast_left or 0) - 1
		if state.cast_left <= 0 then
			launch_pair(boss_ent)
			state.phase = "CHASE"
			state.cycle_elapsed = 0
		end
		return
	end

	if #state.active > 0 or #state.pending > 0 then
		state.phase = "CHASE"
		return
	end

	if marching or not ready then
		state.phase = "IDLE"
		return
	end

	state.phase = "IDLE"
	state.cycle_elapsed = state.cycle_elapsed + 1
	if state.cycle_elapsed >= (state.cycle_target or 200) then
		state.phase = "CAST"
		state.cast_left = cfg().CAST_WINDUP or 25
		state.cycle_target = new_cycle_target()
		if boss_ent and visual.command then
			visual.command(boss_ent)
		end
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
		spawn_poof(stray.pos, "grey")
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
		list = list,
		force_kind = state.force_kind,
	}
end

return promo
