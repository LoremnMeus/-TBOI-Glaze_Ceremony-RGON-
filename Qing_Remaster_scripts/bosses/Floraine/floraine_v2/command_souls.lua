-- P1 command souls: opening NORMAL orders + dynamic GOLD one-shots.
-- Event notify + per-frame host verification. Sole P1 reinforce owner.

local enums = require("Qing_Remaster_scripts.core.enums")
local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")
local piece_defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")
local reserve_defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_defs")
local reserve_controller = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_controller")
local deployment = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.deployment")
local particles = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.command_particles")
local visual = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.visual")

local souls = {}

souls.STATE = {
	DORMANT = "DORMANT",
	LAUNCHING = "LAUNCHING",
	SEEKING = "SEEKING",
	INFUSING = "INFUSING",
	DEPLOYING = "DEPLOYING",
	ACTIVE = "ACTIVE",
	MISSING = "MISSING", -- host gone without death evidence
	RELEASED = "RELEASED",
	WAITING_SLOT = "WAITING_SLOT", -- host locked, no legal landing yet
	RETURNING = "RETURNING", -- no reserve left; red light flies back to staff
	RETURNED = "RETURNED", -- settled once; HP bleed already requested
	EXHAUSTED = "EXHAUSTED", -- legacy alias kept for diag / old saves
	CONSUMED = "CONSUMED", -- GOLD one-shot spent (no inherit / no return)
}

souls.KIND = {
	NORMAL = "NORMAL",
	GOLD = "GOLD",
}

local session_id = 0
local commands = {}
local next_command_id = 1
local kill_count = 0
local unlocked_gold = 0 -- number of gold thresholds fired (0..4)
local gold_threshold_fired = {} -- threshold value → true
local pending_gold_orders = {} -- FIFO { threshold=, order_id= }
local gold_host_kind_rr = 0 -- rotates among available non-pawn kinds
local gold_order_serial = 0
local opening = {
	active = false,
	elapsed = 0,
	-- await_cast (Cast.Call) → launch → await_hover → release → done
	phase = "idle",
	launched = false,
	call_triggered = false,
	call_fallback_used = false,
	drop_signaled = false,
	release_played = false,
	drop_armed = false,
	hover_ready_frame = nil,
	batch_id = nil,
	expected = 0,
	landed = 0,
}
local suppress_death = false
local last_anomaly = "none"

local function opening_command_count()
	return defs.P1_OPENING_COMMAND_COUNT or defs.P1_COMMAND_COUNT or 3
end

local function gold_thresholds()
	return defs.P1_GOLD_KILL_THRESHOLDS or { 5, 8, 10, 12 }
end

local function new_session()
	session_id = session_id + 1
	return session_id
end

local function make_command(id, kind)
	return {
		id = id,
		kind = kind or souls.KIND.NORMAL,
		state = souls.STATE.DORMANT,
		session_id = session_id,
		piece_id = nil,
		carrier_ptr = nil,
		entity_ref = nil,
		generation = 0,
		last_death_pos = nil,
		last_alive_pos = nil,
		last_alive_frame = 0,
		pending_target_id = nil,
		job_id = nil,
		particle_launched = false,
		handled_death_gen = 0,
		death_reported = false,
		release_reason = nil,
		missing_frames = 0,
		slot_retry = 0,
		gold_reward_settled = false,
		gold_threshold = nil,
	}
end

local function ensure_commands(n)
	n = n or opening_command_count()
	commands = {}
	next_command_id = 1
	for i = 1, n do
		commands[i] = make_command(i, souls.KIND.NORMAL)
		next_command_id = i + 1
	end
end

local function is_gold(cmd)
	return cmd and cmd.kind == souls.KIND.GOLD
end

local function is_combat_death_reason(reason)
	return reason == "npc_death"
		or reason == "host_dead_poll"
		or reason == "missing_then_death"
end

local function piece_head(row)
	if not row then
		return nil
	end
	local pos = row.pos or row.home_pos
	if not pos then
		return nil
	end
	local h = row.visual_height or 0
	return Vector(pos.X, pos.Y - 18 - h)
end

local function list_reserve_hosts()
	local out = {}
	local order = reserve_controller.get_order and reserve_controller.get_order() or {}
	for _, id in ipairs(order) do
		local r = reserve_controller.get_row(id)
		if r and r.state == reserve_defs.STATE.RESERVE then
			out[#out + 1] = r
		end
	end
	return out
end

local function lock_opening_targets(count)
	local picked = {}
	if reserve_controller.pick_opening_three then
		picked = reserve_controller.pick_opening_three() or {}
	end
	local used = {}
	for _, r in ipairs(picked) do
		used[r.id] = true
	end
	for _, r in ipairs(list_reserve_hosts()) do
		if #picked >= count then
			break
		end
		if not used[r.id] then
			used[r.id] = true
			picked[#picked + 1] = r
		end
	end
	local locked = {}
	for i = 1, math.min(count, #picked) do
		local row = picked[i]
		local target, gidx = deployment.claim_target_for_piece(row.id)
		if not target then
			break
		end
		reserve_controller.begin_target(row.id)
		locked[#locked + 1] = {
			piece_id = row.id,
			target = target,
			target_gidx = gidx,
		}
	end
	return locked
end

local function start_deploy_for(cmd, opts)
	opts = opts or {}
	local ok, why = deployment.start(cmd.piece_id, {
		target = opts.target or cmd.pending_target,
		command_id = cmd.id,
		generation = cmd.generation,
		session_id = cmd.session_id,
		batch_id = opts.batch_id,
		is_opening = opts.is_opening == true,
		wait_for_drop = opts.wait_for_drop == true,
		auto_drop = opts.auto_drop == true,
		from_infuse = true,
	})
	if ok then
		cmd.state = souls.STATE.DEPLOYING
		cmd.job_id = cmd.piece_id
		return true
	end
	return false, why
end

local function begin_piece_command_glow(row, kind)
	if not row then
		return
	end
	local ok_rv, rv = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_visual")
	if ok_rv and rv and rv.begin_command_glow then
		rv.begin_command_glow(row, { kind = kind })
	end
end

local function stamp_command_kind(row, cmd)
	if not row then
		return
	end
	row.command_kind = is_gold(cmd) and "GOLD" or "NORMAL"
end

local function on_staff_arrive(cmd_id)
	local cmd = commands[cmd_id]
	if not cmd or cmd.state ~= souls.STATE.LAUNCHING then
		return
	end
	cmd.state = souls.STATE.INFUSING
	local row = reserve_controller.get_row(cmd.piece_id)
	if row then
		reserve_controller.set_state(cmd.piece_id, reserve_defs.STATE.INFUSING)
		row.phase_elapsed = 0
		stamp_command_kind(row, cmd)
		-- Both NORMAL and GOLD use the continuous command-glow timeline (color differs).
		begin_piece_command_glow(row, row.command_kind)
	end
	cmd.infuse_left = defs.P1_INFUSE_FRAMES or reserve_defs.DEPLOY.INFUSE or 22
end

local function launch_staff_particle(cmd, start_pos, bias)
	local row = reserve_controller.get_row(cmd.piece_id)
	local finish = piece_head(row)
	if not start_pos or not finish then
		return false
	end
	cmd.state = souls.STATE.LAUNCHING
	cmd.particle_launched = true
	local orbit = cmd._orbit
	particles.launch({
		start = start_pos,
		finish = finish,
		preset = "opening",
		command_id = cmd.id,
		control_bias = bias or 0,
		orbit_center = orbit and orbit.center or nil,
		orbit_angle = orbit and orbit.angle or nil,
		orbit_radius = orbit and orbit.radius or nil,
		orbit_batch_id = orbit and orbit.batch_id or nil,
		orbit_index = orbit and orbit.index or nil,
		orbit_count = orbit and orbit.count or nil,
		on_arrive = function()
			on_staff_arrive(cmd.id)
		end,
	})
	return true
end


function souls.begin_opening(boss_ent)
	souls.clear("reopen")
	new_session()
	kill_count = 0
	unlocked_gold = 0
	gold_threshold_fired = {}
	pending_gold_orders = {}
	ensure_commands(opening_command_count())
	local locked = lock_opening_targets(defs.P1_OPENING_COUNT or 3)
	if #locked < 1 then
		return 0, "no_targets"
	end
	opening.active = true
	opening.elapsed = 0
	opening.phase = "await_cast"
	opening.launched = false
	opening.call_triggered = false
	opening.call_fallback_used = false
	opening.drop_signaled = false
	opening.release_played = false
	opening.drop_armed = false
	opening.drop_fallback_used = false
	opening.hover_ready_frame = nil
	opening.batch_id = "opening_" .. tostring(session_id)
	opening.expected = #locked
	opening.landed = 0
	opening.boss_ptr = boss_ent and GetPtrHash(boss_ent) or nil
	for i, entry in ipairs(locked) do
		local cmd = commands[i]
		if cmd then
			cmd.session_id = session_id
			cmd.generation = 1
			cmd.piece_id = entry.piece_id
			cmd.pending_target = entry.target
			cmd.pending_gidx = entry.target_gidx
			cmd.state = souls.STATE.DORMANT
			cmd.kind = souls.KIND.NORMAL
		end
	end
	for i = #locked + 1, opening_command_count() do
		if commands[i] then
			commands[i].state = souls.STATE.EXHAUSTED
		end
	end
	return #locked, "ok"
end

function souls.on_handoff(piece_id, ent, data)
	for _, cmd in pairs(commands) do
		if cmd.piece_id == piece_id and (cmd.state == souls.STATE.DEPLOYING or cmd.state == souls.STATE.INFUSING) then
			cmd.state = souls.STATE.ACTIVE
			cmd.carrier_ptr = ent and GetPtrHash(ent) or nil
			cmd.entity_ref = ent and EntityRef(ent) or nil
			cmd.job_id = nil
			cmd.death_reported = false
			cmd.missing_frames = 0
			if ent then
				cmd.last_alive_pos = Vector(ent.Position.X, ent.Position.Y)
				cmd.last_alive_frame = Game():GetFrameCount()
			end
			if data then
				data.is_gold = is_gold(cmd)
				data.floraine_command = {
					session_id = cmd.session_id,
					command_id = cmd.id,
					reserve_piece_id = piece_id,
					generation = cmd.generation,
					kind = cmd.kind,
				}
				-- Gold handoff keeps continuous gold outline; deployment seeds settle alpha.
			end
			if opening.active and opening.batch_id then
				opening.landed = (opening.landed or 0) + 1
			end
			return true
		end
	end
	return false
end

local function pick_inherit_host(prefer_kind)
	local candidates = list_reserve_hosts()
	if #candidates < 1 then
		return nil
	end
	if prefer_kind then
		for _, r in ipairs(candidates) do
			if r.kind ~= prefer_kind then
				return r
			end
		end
	end
	return candidates[1]
end

--- Gold hosts prefer non-pawn specials with kind rotation; pawns only as fallback.
local function pick_gold_host()
	local candidates = list_reserve_hosts()
	if #candidates < 1 then
		return nil
	end
	local pawn_kind = piece_defs.KIND.PAWN
	local specials = {}
	local pawns = {}
	local kinds = {}
	local by_kind = {}
	for _, r in ipairs(candidates) do
		if r.kind == pawn_kind then
			pawns[#pawns + 1] = r
		else
			specials[#specials + 1] = r
			if not by_kind[r.kind] then
				by_kind[r.kind] = {}
				kinds[#kinds + 1] = r.kind
			end
			by_kind[r.kind][#by_kind[r.kind] + 1] = r
		end
	end
	if #specials < 1 then
		return pawns[1]
	end
	table.sort(kinds)
	gold_host_kind_rr = (gold_host_kind_rr % #kinds) + 1
	local prefer = kinds[gold_host_kind_rr]
	local pool = by_kind[prefer]
	return pool and pool[1] or specials[1]
end

local function begin_released(cmd, death_pos, reason)
	cmd.state = souls.STATE.RELEASED
	cmd.carrier_ptr = nil
	cmd.entity_ref = nil
	cmd.release_reason = reason or "death"
	cmd.last_death_pos = death_pos and Vector(death_pos.X, death_pos.Y)
		or (cmd.last_alive_pos and Vector(cmd.last_alive_pos.X, cmd.last_alive_pos.Y))
		or nil
	cmd.seek_hold = defs.P1_DEATH_HOLD or 9
	cmd.piece_id = nil
	cmd.pending_target_id = nil
	cmd.pending_target = nil
end

local function try_claim_host(cmd, host)
	if not host then
		return false, "no_host"
	end
	local target, gidx, why = deployment.claim_target_for_piece(host.id)
	if not target then
		return false, why or "no_slot"
	end
	reserve_controller.begin_target(host.id)
	cmd.piece_id = host.id
	cmd.pending_target = target
	cmd.pending_gidx = gidx
	cmd.pending_target_id = host.id
	cmd.generation = (cmd.generation or 0) + 1
	return true
end

local function staff_return_target(boss_ent)
	if boss_ent and visual.staff_tip_world then
		local tip = visual.staff_tip_world(boss_ent)
		if tip then
			return tip
		end
	end
	if boss_ent then
		return boss_ent.Position + Vector(-16, -90)
	end
	return nil
end

local function notify_command_returned(cmd)
	if cmd.return_settled then
		return
	end
	cmd.return_settled = true
	cmd.state = souls.STATE.RETURNED
	cmd.release_reason = cmd.release_reason or "reserve_empty"
	local ok_c, controller = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.controller")
	if ok_c and controller and controller.on_command_returned then
		controller.on_command_returned(cmd.id, cmd)
	end
end

local function launch_command_return(cmd, boss_ent)
	if cmd.state == souls.STATE.RETURNING or cmd.state == souls.STATE.RETURNED then
		return false, "already_returning"
	end
	-- Do not inherit once phase transition has begun.
	local ok_c, controller = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.controller")
	if ok_c and controller and controller.get_session then
		local sess = controller.get_session()
		if sess and sess.state == defs.STATE.PHASE_TRANSITION then
			cmd.state = souls.STATE.RETURNED
			cmd.return_settled = true
			return false, "transition_busy"
		end
	end
	cmd.state = souls.STATE.RETURNING
	cmd.release_reason = "reserve_empty"
	local start = cmd.last_death_pos
		or (cmd.last_alive_pos and Vector(cmd.last_alive_pos.X, cmd.last_alive_pos.Y))
		or (boss_ent and boss_ent.Position)
		or Vector.Zero
	local finish = staff_return_target(boss_ent) or (start + Vector(0, -40))
	local sid = session_id
	local cid = cmd.id
	particles.launch({
		start = start,
		finish = finish,
		preset = "return",
		command_id = cmd.id,
		control_bias = (cmd.id - 2) * 0.5,
		finish_follow = function()
			local ok2, ctrl = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.controller")
			if ok2 and ctrl and ctrl.find_boss then
				return staff_return_target(ctrl.find_boss())
			end
			return finish
		end,
		on_arrive = function()
			if session_id ~= sid then
				return
			end
			local c = commands[cid]
			if not c or c.state ~= souls.STATE.RETURNING then
				return
			end
			notify_command_returned(c)
		end,
	})
	return true
end

local function launch_death_seek(cmd, boss_ent)
	local host = pick_inherit_host(cmd.last_kind)
	if not host then
		return launch_command_return(cmd, boss_ent)
	end
	local ok, why = try_claim_host(cmd, host)
	if not ok then
		-- Host exists but no landing: wait and retry; do not EXHAUST.
		cmd.state = souls.STATE.WAITING_SLOT
		cmd.slot_retry = defs.P1_SLOT_RETRY or 30
		cmd.waiting_host_id = host.id
		last_anomaly = "wait_slot:" .. tostring(why)
		return false, why
	end
	cmd.state = souls.STATE.SEEKING
	local finish = piece_head(host)
	particles.launch({
		start = cmd.last_death_pos or finish,
		finish = finish,
		preset = "inherit",
		command_id = cmd.id,
		control_bias = (cmd.id - 2),
		on_arrive = function()
			if cmd.state ~= souls.STATE.SEEKING then
				return
			end
			cmd.state = souls.STATE.INFUSING
			reserve_controller.set_state(cmd.piece_id, reserve_defs.STATE.INFUSING)
			local host_row = reserve_controller.get_row(cmd.piece_id)
			if host_row then
				host_row.phase_elapsed = 0
				stamp_command_kind(host_row, cmd)
				begin_piece_command_glow(host_row, host_row.command_kind)
			end
			cmd.infuse_left = defs.P1_INFUSE_FRAMES or 22
			cmd.inherit = true
		end,
	})
	return true
end

--- Unlock one gold quota by threshold value. Idempotent: each threshold fires at most once.
local function enqueue_gold_unlock(threshold, reason)
	local th = tonumber(threshold) or 0
	if th <= 0 or gold_threshold_fired[th] then
		return false
	end
	gold_threshold_fired[th] = true
	unlocked_gold = unlocked_gold + 1
	gold_order_serial = gold_order_serial + 1
	pending_gold_orders[#pending_gold_orders + 1] = {
		threshold = th,
		order_id = gold_order_serial,
		reason = reason or "kill",
	}
	return true
end

local function enqueue_gold_orders_for_kills()
	local thresholds = gold_thresholds()
	for i = 1, #thresholds do
		local th = tonumber(thresholds[i]) or 0
		if th > 0 and kill_count >= th then
			enqueue_gold_unlock(th, "kill")
		end
	end
end

local function note_effective_kill(cmd, reason)
	if not is_combat_death_reason(reason) then
		return
	end
	-- Opening ritual deaths should not unlock gold.
	if opening.active then
		return
	end
	kill_count = kill_count + 1
	enqueue_gold_orders_for_kills()
end

--- P1 HP bailout: unlock early gold quotas by boss HP ratio without faking kill_count.
function souls.notify_hp_ratio(ratio)
	ratio = tonumber(ratio)
	if ratio == nil then
		return
	end
	if opening.active then
		return
	end
	local thresholds = gold_thresholds()
	local guarantees = defs.P1_GOLD_HP_GUARANTEES or {
		{ ratio = 0.90, index = 1 },
		{ ratio = 0.80, index = 2 },
	}
	for i = 1, #guarantees do
		local g = guarantees[i]
		local need = tonumber(g.ratio) or 1
		local idx = math.floor(tonumber(g.index) or i)
		if ratio <= need and idx >= 1 and idx <= #thresholds then
			enqueue_gold_unlock(thresholds[idx], "hp")
		end
	end
end

local function consume_gold_command(cmd, pos, reason)
	cmd.state = souls.STATE.CONSUMED
	cmd.carrier_ptr = nil
	cmd.entity_ref = nil
	cmd.release_reason = reason or "gold_death"
	cmd.last_death_pos = pos and Vector(pos.X, pos.Y)
		or (cmd.last_alive_pos and Vector(cmd.last_alive_pos.X, cmd.last_alive_pos.Y))
		or nil
	cmd.piece_id = nil
	cmd.pending_target_id = nil
	cmd.pending_target = nil
	if cmd.gold_reward_settled then
		return
	end
	local death_pos = cmd.last_death_pos or Vector.Zero
	local sid = session_id
	local cid = cmd.id
	particles.launch_gold_reward({
		start = death_pos,
		count = defs.P1_GOLD_REWARD_COUNT or 7,
		command_id = cid,
		session_id = sid,
		finish_follow = function()
			local ok_c, controller = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.controller")
			if ok_c and controller and controller.find_boss then
				local boss = controller.find_boss()
				if boss then
					return staff_return_target(boss) or (boss.Position + Vector(-16, -90))
				end
			end
			return nil
		end,
		validate = function()
			return session_id == sid
		end,
		on_settle = function(command_id)
			if session_id ~= sid then
				return
			end
			local c = commands[command_id or cid]
			if not c or c.gold_reward_settled then
				return
			end
			c.gold_reward_settled = true
			local ok_c, controller = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.controller")
			if ok_c and controller and controller.apply_gold_reward then
				controller.apply_gold_reward(c.id, c)
			end
		end,
	})
end

local function release_from_active(cmd, pos, reason)
	if cmd.handled_death_gen == cmd.generation then
		return false
	end
	cmd.handled_death_gen = cmd.generation
	cmd.death_reported = true
	if cmd.piece_id then
		reserve_controller.mark_defeated(cmd.piece_id)
	elseif cmd.pending_target_id then
		reserve_controller.mark_defeated(cmd.pending_target_id)
	end
	note_effective_kill(cmd, reason)
	if is_gold(cmd) then
		consume_gold_command(cmd, pos, reason)
		return true
	end
	begin_released(cmd, pos, reason)
	return true
end

local function director_begin_vuln()
	local ok, director = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.director")
	if ok and director and director.begin_command_vuln then
		director.begin_command_vuln(defs.COMMAND_VULN_FRAMES or 44)
	end
end

local function can_cast_gold(boss_ent)
	if opening.active then
		return false, "opening"
	end
	local ok_c, controller = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.controller")
	if ok_c and controller and controller.get_session then
		local sess = controller.get_session()
		if not sess or sess.phase ~= defs.PHASE.P1 then
			return false, "not_p1"
		end
		if sess.state == defs.STATE.PHASE_TRANSITION then
			return false, "transition"
		end
		if sess.state ~= defs.STATE.COMBAT then
			return false, "not_combat"
		end
	end
	if not boss_ent then
		return false, "no_boss"
	end
	local s = boss_ent:GetSprite()
	local anim = s and s:GetAnimation() or nil
	if anim and anim ~= "Idle" and anim ~= "Idle2" then
		return false, "busy_anim"
	end
	return true
end

local function append_gold_command(threshold)
	local id = next_command_id
	next_command_id = next_command_id + 1
	local cmd = make_command(id, souls.KIND.GOLD)
	cmd.session_id = session_id
	cmd.gold_threshold = threshold
	commands[id] = cmd
	return cmd
end

local function try_start_pending_gold(boss_ent)
	if #pending_gold_orders < 1 then
		return false
	end
	local ok, why = can_cast_gold(boss_ent)
	if not ok then
		return false, why
	end
	local host = pick_gold_host()
	if not host then
		last_anomaly = "gold_wait_reserve"
		return false, "no_reserve"
	end
	local order = table.remove(pending_gold_orders, 1)
	local cmd = append_gold_command(order.threshold)
	local claimed, claim_why = try_claim_host(cmd, host)
	if not claimed then
		-- Put order back at front; do not lose the threshold unlock.
		table.insert(pending_gold_orders, 1, order)
		commands[cmd.id] = nil
		last_anomaly = "gold_no_slot:" .. tostring(claim_why)
		return false, claim_why
	end
	-- Stamp GOLD identity before particle flight so reserve visuals never use red fallback.
	stamp_command_kind(host, cmd)
	if visual.release then
		visual.release(boss_ent)
	elseif visual.command then
		visual.command(boss_ent)
	end
	director_begin_vuln()
	local tip = visual.staff_tip_world and visual.staff_tip_world(boss_ent)
		or (boss_ent.Position + Vector(-16, -90))
	cmd.state = souls.STATE.LAUNCHING
	cmd.particle_launched = true
	particles.launch({
		start = tip,
		finish = piece_head(host),
		preset = "inherit",
		gold = true,
		command_id = cmd.id,
		session_id = session_id,
		control_bias = 0.5,
		on_arrive = function()
			on_staff_arrive(cmd.id)
		end,
	})
	return true, cmd.id
end

--- True combat death notify (early path). Phase 1 only.
function souls.notify_npc_death(ent)
	if suppress_death or not ent then
		return false
	end
	local ok_c, controller = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.controller")
	if ok_c and controller and controller.get_session then
		local sess = controller.get_session()
		if not sess or sess.phase ~= defs.PHASE.P1 then
			return false
		end
	end
	local ok, piece_controller = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.chess_piece_controller")
	if not ok or not piece_controller then
		return false
	end
	local data = piece_controller.get_data(ent)
	if not data or not data.floraine_command then
		return false
	end
	local fc = data.floraine_command
	if fc.session_id ~= session_id then
		return false
	end
	local cmd = commands[fc.command_id]
	if not cmd then
		return false
	end
	if cmd.state ~= souls.STATE.ACTIVE and cmd.state ~= souls.STATE.MISSING then
		return false
	end
	if cmd.generation ~= fc.generation then
		return false
	end
	cmd.last_kind = data.kind
	if fc.reserve_piece_id then
		cmd.piece_id = fc.reserve_piece_id
	end
	local pos = ent.Position
	if cmd.last_alive_pos then
		pos = cmd.last_alive_pos
	end
	return release_from_active(cmd, pos, "npc_death")
end

function souls.set_suppress_death(v)
	suppress_death = v == true
end

local function resolve_carrier(cmd)
	if cmd.entity_ref and cmd.entity_ref.Entity then
		local e = cmd.entity_ref.Entity
		if e and e.Exists and e:Exists() then
			return e:ToNPC() or e
		end
	end
	if not cmd.carrier_ptr then
		return nil
	end
	for _, ent in ipairs(Isaac.FindByType(996, enums.Enemies.chess_piece, -1, false, false)) do
		if GetPtrHash(ent) == cmd.carrier_ptr then
			return ent
		end
	end
	return nil
end

local function verify_active_hosts()
	for _, cmd in pairs(commands) do
		if cmd.state == souls.STATE.ACTIVE then
			local ent = resolve_carrier(cmd)
			if ent then
				cmd.entity_ref = EntityRef(ent)
				cmd.carrier_ptr = GetPtrHash(ent)
				cmd.last_alive_pos = Vector(ent.Position.X, ent.Position.Y)
				cmd.last_alive_frame = Game():GetFrameCount()
				cmd.missing_frames = 0
				if ent:IsDead() or (ent.HitPoints ~= nil and ent.HitPoints <= 0) then
					local data_ok, piece_controller = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.chess_piece_controller")
					if data_ok and piece_controller then
						local d = piece_controller.get_data(ent)
						if d then
							cmd.last_kind = d.kind
							if d.floraine_command and d.floraine_command.reserve_piece_id then
								cmd.piece_id = d.floraine_command.reserve_piece_id
							end
						end
					end
					release_from_active(cmd, cmd.last_alive_pos, "host_dead_poll")
				end
			else
				cmd.state = souls.STATE.MISSING
				cmd.missing_frames = 0
				cmd.release_reason = "host_missing"
				last_anomaly = "missing_cmd_" .. tostring(cmd.id)
			end
		elseif cmd.state == souls.STATE.MISSING then
			cmd.missing_frames = (cmd.missing_frames or 0) + 1
			-- If death was reported while MISSING, seek already started via notify.
			-- Without death evidence: do not inherit; wait grace then stay anomalous.
			if cmd.death_reported then
				release_from_active(cmd, cmd.last_alive_pos, "missing_then_death")
			elseif cmd.missing_frames >= (defs.P1_MISSING_GRACE or 45) then
				-- Still no death evidence (Remove / cleanup). Do not spawn inheritance.
				last_anomaly = "missing_timeout_cmd_" .. tostring(cmd.id)
			end
		end
	end
end

local function boss_sprite_drop_event(boss_ent)
	if not boss_ent then
		return false
	end
	local s = boss_ent:GetSprite()
	if not s then
		return false
	end
	if s:GetAnimation() ~= "Release" then
		return false
	end
	if s.IsEventTriggered and s:IsEventTriggered("Drop") then
		return true
	end
	-- One-shot fallback if Drop event missing from sheet.
	if not opening.drop_fallback_used and s.GetFrame and (s:GetFrame() or 0) >= 4 then
		opening.drop_fallback_used = true
		return true
	end
	return false
end

--- Arm staggered opening particle launches (Cast.Call authority).
--- Idempotent: second call while already launched returns false.
function souls.trigger_opening_launch(boss_ent)
	if not opening.active then
		return false, "inactive"
	end
	if opening.launched then
		return false, "already"
	end
	if opening.phase ~= "await_cast" then
		return false, "bad_phase"
	end
	local tip = visual.staff_tip_world and visual.staff_tip_world(boss_ent)
		or (boss_ent and (boss_ent.Position + Vector(-16, -90)) or Vector.Zero)
	local stagger = reserve_defs.DEPLOY.STAGGER or 4
	local orbit_cfg = defs.P1_OPENING_ORBIT or {}
	local angles = orbit_cfg.angles or { 210, 270, 330 }
	local radius = tonumber(orbit_cfg.radius) or 32
	local off = orbit_cfg.center_offset or {}
	-- Freeze orbit center at Call — do not re-read Boss head each frame.
	local orbit_center = Vector(
		tip.X + (tonumber(off.x) or 0),
		tip.Y + (tonumber(off.y) or -18)
	)
	local batch_id = "opening_orbit_" .. tostring(session_id)
	local slots = {}
	for id = 1, opening_command_count() do
		local cmd = commands[id]
		if cmd and cmd.piece_id and cmd.state == souls.STATE.DORMANT then
			slots[#slots + 1] = cmd
		end
	end
	local n = #slots
	for i, cmd in ipairs(slots) do
		cmd.launch_delay = (i - 1) * stagger
		cmd._tip = tip
		cmd._bias = i - (n + 1) * 0.5
		cmd._orbit = {
			batch_id = batch_id,
			center = Vector(orbit_center.X, orbit_center.Y),
			radius = radius,
			angle = angles[i] or (210 + (i - 1) * 60),
			index = i,
			count = n,
		}
	end
	opening.phase = "launch"
	opening.launched = true
	opening.call_triggered = true
	opening.orbit_batch_id = batch_id
	return true, n
end

local function boss_sprite_call_event(boss_ent)
	if not boss_ent or not boss_ent.GetSprite then
		return false
	end
	local s = boss_ent:GetSprite()
	if not s then
		return false
	end
	if s:GetAnimation() ~= "Cast" then
		return false
	end
	if s.IsEventTriggered and s:IsEventTriggered("Call") then
		return true
	end
	-- One-shot fallback bound to Cast frame (not an independent Raise+Charge clock).
	local fb = defs.CAST_CALL_FALLBACK_FRAME or 5
	if not opening.call_fallback_used and s.GetFrame and (s:GetFrame() or 0) >= fb then
		opening.call_fallback_used = true
		return true
	end
	return false
end

function souls.tick(boss_ent)
	-- Particle advance is owned by controller (once per game frame).
	verify_active_hosts()
	try_start_pending_gold(boss_ent)

	-- Opening ritual: wait Cast.Call → staggered launch → Release.Drop.
	if opening.active then
		opening.elapsed = (opening.elapsed or 0) + 1

		if opening.phase == "await_cast" then
			if boss_sprite_call_event(boss_ent) then
				souls.trigger_opening_launch(boss_ent)
			end
		end

		if opening.phase == "launch" or opening.phase == "await_hover" then
			local pending_launch = 0
			local launched_n = 0
			for id = 1, opening_command_count() do
				local cmd = commands[id]
				if cmd and cmd.launch_delay ~= nil and cmd.state == souls.STATE.DORMANT then
					if cmd.launch_delay <= 0 then
						launch_staff_particle(cmd, cmd._tip, cmd._bias)
						cmd.launch_delay = nil
					else
						cmd.launch_delay = cmd.launch_delay - 1
						pending_launch = pending_launch + 1
					end
				end
				if cmd and cmd.particle_launched then
					launched_n = launched_n + 1
				end
			end
			if pending_launch < 1 and opening.orbit_batch_id and launched_n > 0
				and particles.set_orbit_batch_expected then
				particles.set_orbit_batch_expected(opening.orbit_batch_id, launched_n)
			end
			if opening.phase == "launch" then
				opening.phase = "await_hover"
			end

			if not opening.release_played and opening.batch_id
				and deployment.batch_all_hovering and deployment.batch_all_hovering(opening.batch_id) then
				if not opening.hover_ready_frame then
					opening.hover_ready_frame = opening.elapsed
				end
				local hold = defs.P1_PRE_RELEASE_HOLD or 12
				if (opening.elapsed - opening.hover_ready_frame) >= hold then
					if boss_ent and visual.release then
						visual.release(boss_ent)
					end
					opening.release_played = true
					opening.drop_armed = true
					opening.phase = "release"
				end
			end
		elseif opening.phase == "release" then
			if opening.drop_armed and not opening.drop_signaled then
				if boss_sprite_drop_event(boss_ent) then
					deployment.signal_batch_drop(opening.batch_id)
					opening.drop_signaled = true
					opening.drop_armed = false
					opening.phase = "done"
				end
			end
		end
	end

	-- Per-command infuse / released / waiting_slot.
	for _, cmd in pairs(commands) do
		if cmd.state == souls.STATE.INFUSING then
			cmd.infuse_left = (cmd.infuse_left or 0) - 1
			local row = reserve_controller.get_row(cmd.piece_id)
			if row then
				row.phase_elapsed = (row.phase_elapsed or 0) + 1
				row.visual_color_progress = 0
				row.visual_height = 0
			end
			if cmd.infuse_left <= 0 then
				local wait = opening.active and not cmd.inherit
				start_deploy_for(cmd, {
					target = cmd.pending_target,
					batch_id = wait and opening.batch_id or nil,
					is_opening = wait,
					wait_for_drop = wait,
					auto_drop = (not wait) and (defs.P1_INHERIT_AUTO_DROP ~= false),
				})
			end
		elseif cmd.state == souls.STATE.RELEASED then
			if is_gold(cmd) then
				-- Safety: gold must never inherit.
				consume_gold_command(cmd, cmd.last_death_pos, cmd.release_reason or "gold_released")
			else
				cmd.seek_hold = (cmd.seek_hold or 0) - 1
				if cmd.seek_hold <= 0 then
					launch_death_seek(cmd, boss_ent)
				end
			end
		elseif cmd.state == souls.STATE.WAITING_SLOT then
			if is_gold(cmd) then
				consume_gold_command(cmd, cmd.last_death_pos, "gold_no_slot")
			else
				cmd.slot_retry = (cmd.slot_retry or 0) - 1
				if cmd.slot_retry <= 0 then
					cmd.state = souls.STATE.RELEASED
					cmd.seek_hold = 0
				end
			end
		end
	end
end

function souls.count_by_state(state)
	local n = 0
	for _, cmd in pairs(commands) do
		if cmd.state == state then
			n = n + 1
		end
	end
	return n
end

function souls.count_returned()
	local n = 0
	for _, cmd in pairs(commands) do
		if not is_gold(cmd)
			and (cmd.state == souls.STATE.RETURNED or cmd.state == souls.STATE.EXHAUSTED) then
			n = n + 1
		end
	end
	return n
end

function souls.all_commands_returned()
	-- Only NORMAL opening commands participate in return exhaustion.
	local need = 0
	local n = 0
	for _, cmd in pairs(commands) do
		if not is_gold(cmd) then
			need = need + 1
			if cmd.state == souls.STATE.RETURNED or cmd.state == souls.STATE.EXHAUSTED then
				n = n + 1
			end
		end
	end
	return need > 0 and n >= need
end

function souls.get_unlocked_gold_count()
	return unlocked_gold
end

function souls.get_kill_count()
	return kill_count
end

function souls.get_pending_gold_count()
	return #pending_gold_orders
end

function souls.get_live_command_count()
	local n = 0
	for _, cmd in pairs(commands) do
		if cmd.state == souls.STATE.ACTIVE
			or cmd.state == souls.STATE.DEPLOYING
			or cmd.state == souls.STATE.INFUSING
			or cmd.state == souls.STATE.LAUNCHING
			or cmd.state == souls.STATE.SEEKING
			or cmd.state == souls.STATE.WAITING_SLOT
			or cmd.state == souls.STATE.MISSING then
			n = n + 1
		end
	end
	return n
end

function souls.get_p1_guard_cap()
	return opening_command_count() + (unlocked_gold or 0)
end

--- Debug / test: force one NORMAL active-or-released command into return path.
function souls.debug_force_return_one(boss_ent)
	local ids = {}
	for id in pairs(commands) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local cmd = commands[id]
		if cmd and not is_gold(cmd)
			and cmd.state ~= souls.STATE.RETURNED
			and cmd.state ~= souls.STATE.RETURNING
			and cmd.state ~= souls.STATE.EXHAUSTED
			and cmd.state ~= souls.STATE.CONSUMED then
			cmd.last_death_pos = cmd.last_alive_pos
				or (boss_ent and boss_ent.Position)
				or Vector.Zero
			begin_released(cmd, cmd.last_death_pos, "debug_force_return")
			cmd.seek_hold = 0
			launch_command_return(cmd, boss_ent)
			return true, id
		end
	end
	return false, "none"
end

--- Debug: enqueue next gold threshold (or force kill_count to next).
function souls.debug_trigger_next_gold()
	local thresholds = gold_thresholds()
	for i = 1, #thresholds do
		local th = tonumber(thresholds[i]) or 0
		if th > 0 and not gold_threshold_fired[th] then
			if kill_count < th then
				kill_count = th
			end
			enqueue_gold_orders_for_kills()
			return true, th
		end
	end
	return false, "all_unlocked"
end

function souls.debug_spawn_gold_now(boss_ent)
	local ok, th = souls.debug_trigger_next_gold()
	if not ok then
		return false, th
	end
	-- Prefer immediate cast; if busy, leave in pending queue.
	local started, why = try_start_pending_gold(boss_ent)
	return started == true, started and why or ("queued:" .. tostring(th) .. ":" .. tostring(why))
end

function souls.debug_exhaust_reserves()
	local ok, rc = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_controller")
	if ok and rc and rc.debug_clear_reserves then
		return rc.debug_clear_reserves()
	end
	-- Fallback: mark every reserve row defeated so pick_inherit_host finds none.
	if ok and rc and rc.get_order and rc.mark_defeated then
		local order = rc.get_order() or {}
		for _, id in ipairs(order) do
			rc.mark_defeated(id)
		end
		return true, #order
	end
	return false, "no_api"
end

function souls.opening_status()
	local hovering = 0
	if opening.batch_id and deployment.batch_hover_count then
		hovering = select(1, deployment.batch_hover_count(opening.batch_id))
	end
	local wave_busy = deployment.is_opening_wave_busy and deployment.is_opening_wave_busy()
	local pending = opening.active and (opening.landed or 0) < (opening.expected or 0)
	local launch_count = 0
	for _, cmd in pairs(commands) do
		if cmd and cmd.particle_launched then
			launch_count = launch_count + 1
		end
	end
	return {
		active = opening.active,
		phase = opening.phase,
		expected = opening.expected,
		landed = opening.landed,
		launched = opening.launched,
		call_triggered = opening.call_triggered == true,
		call_fallback_used = opening.call_fallback_used == true,
		launch_count = launch_count,
		drop_signaled = opening.drop_signaled,
		release_played = opening.release_played,
		batch_id = opening.batch_id,
		hovering = hovering,
		busy = wave_busy == true or pending == true,
		complete = opening.active
			and (opening.expected or 0) > 0
			and (opening.landed or 0) >= (opening.expected or 0)
			and not wave_busy,
		session_id = session_id,
	}
end


function souls.has_opening_complete()
	return souls.opening_status().complete == true
end

function souls.has_opening_guard_landed()
	return (opening.landed or 0) > 0
end

function souls.clear_opening_flag()
	opening.active = false
end

function souls.clear(reason)
	particles.clear()
	deployment.cancel_all(reason or "souls_clear")
	commands = {}
	next_command_id = 1
	kill_count = 0
	unlocked_gold = 0
	gold_threshold_fired = {}
	pending_gold_orders = {}
	gold_order_serial = 0
	opening = {
		active = false,
		elapsed = 0,
		phase = "idle",
		launched = false,
		call_triggered = false,
		call_fallback_used = false,
		drop_signaled = false,
		release_played = false,
		drop_armed = false,
		drop_fallback_used = false,
		hover_ready_frame = nil,
		batch_id = nil,
		expected = 0,
		landed = 0,
	}
	local ok_ai, afterimage = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.chess_piece_afterimage")
	if ok_ai and afterimage and afterimage.clear_player_cooldowns then
		afterimage.clear_player_cooldowns()
	end
end

function souls.stop_phase()
	suppress_death = true
	souls.clear("phase_stop")
	suppress_death = false
end

function souls.get_session_id()
	return session_id
end

function souls.diag()
	local list = {}
	for id, cmd in pairs(commands) do
		list[#list + 1] = {
			id = id,
			kind = cmd.kind,
			state = cmd.state,
			piece_id = cmd.piece_id,
			generation = cmd.generation,
			carrier_ptr = cmd.carrier_ptr,
			release_reason = cmd.release_reason,
			missing_frames = cmd.missing_frames,
			gold_threshold = cmd.gold_threshold,
			gold_reward_settled = cmd.gold_reward_settled == true,
			last_alive = cmd.last_alive_pos and { x = cmd.last_alive_pos.X, y = cmd.last_alive_pos.Y },
		}
	end
	table.sort(list, function(a, b) return a.id < b.id end)
	return {
		session_id = session_id,
		opening = souls.opening_status(),
		commands = list,
		kill_count = kill_count,
		unlocked_gold = unlocked_gold,
		pending_gold = #pending_gold_orders,
		p1_guard_cap = souls.get_p1_guard_cap(),
		live_commands = souls.get_live_command_count(),
		particles = particles.diag(),
		last_anomaly = last_anomaly,
		suppress_death = suppress_death,
	}
end

return souls
