-- Floraine V2 main state machine. Exclusive owner when DATA_KEY is set.

local enums = require("Qing_Remaster_scripts.core.enums")
local runtime = require("Qing_Remaster_scripts.threads.stone.stone_runtime")
local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")
local phase_mod = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.phase")
local arena = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.arena")
local director = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.director")
local attacks = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.attacks")
local visual = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.visual")
local rewards = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.rewards")
local scheduler = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.scheduler")
local temp_piece = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.temp_piece")
local reserve_controller = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_controller")
local deployment = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.deployment")
local command_souls = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.command_souls")
local command_particles = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.command_particles")
local occupancy = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_occupancy")
local phase_transition = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.phase_transition")
local staff_transition = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.staff_transition")
local p2_columns = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_columns")
local p2_promotion = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_promotion")
local royal_drop = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.royal_drop")

local controller = {}

local session = {
	state = defs.STATE.WAITING,
	phase = defs.PHASE.P1,
	frame = 0,
	boss_ptr = nil,
	boss = nil,
	force_phase = nil,
	transition_stage = nil,
	pending_phase = nil,
	transition_reason = nil,
	commands_returned = 0,
	command_return_chunk = 0,
	p1_hp_start = nil,
	returned_ids = {},
	p2_summon_started = false,
}

local function data_of(ent)
	if not ent then return nil end
	local d = ent:GetData()
	local row = d[defs.DATA_KEY]
	if type(row) ~= "table" then
		row = {}
		d[defs.DATA_KEY] = row
	end
	return row
end

function controller.is_owned(ent)
	return ent and ent:GetData()[defs.DATA_KEY] ~= nil
end

function controller.get_session()
	return session
end

local function refresh_boss_wrapper()
	if not session.boss_ptr then
		session.boss = nil
		return nil
	end
	for _, ent in ipairs(Isaac.FindByType(996, enums.Enemies.Floraine, -1, false, false)) do
		if GetPtrHash(ent) == session.boss_ptr and ent:Exists() then
			session.boss = ent
			return ent
		end
	end
	session.boss = nil
	return nil
end

function controller.find_boss()
	return refresh_boss_wrapper()
end

function controller.spawn_boss(pos)
	pos = pos or arena.boss_spawn_pos()
	for _, ent in ipairs(Isaac.FindByType(996, enums.Enemies.Floraine, -1, false, false)) do
		if not controller.is_owned(ent) then
			ent:Remove()
		end
	end
	local ent = Isaac.Spawn(996, enums.Enemies.Floraine, 0, pos, Vector.Zero, nil):ToNPC()
	if not ent then
		return nil
	end
	local data = data_of(ent)
	data.home = Vector(pos.X, pos.Y)
	data.v2 = true
	ent.MaxHitPoints = defs.BOSS_MAX_HP
	ent.HitPoints = defs.BOSS_MAX_HP
	ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_PLAYEROBJECTS
	ent:AddEntityFlags(EntityFlag.FLAG_NO_STATUS_EFFECTS)
	ent.State = NpcState.STATE_IDLE
	-- Contact damage off; Royal uses scripted hit window.
	if ent.CollisionDamage ~= nil then
		ent.CollisionDamage = 0
	end
	visual.idle(ent)
	session.boss_ptr = GetPtrHash(ent)
	session.boss = ent
	return ent
end

local function init_p1_return_budget(ent)
	session.commands_returned = 0
	session.returned_ids = {}
	if not ent or not ent.MaxHitPoints then
		session.command_return_chunk = 0
		session.p1_hp_start = nil
		return
	end
	local h2 = phase_mod.threshold_hp(ent, defs.PHASE.P2)
	session.p1_hp_start = ent.HitPoints
	local d = math.max(0, session.p1_hp_start - h2)
	local n = defs.P1_COMMAND_COUNT or 3
	session.command_return_chunk = d / math.max(1, n)
end

local function begin_combat()
	session.state = defs.STATE.COMBAT
	session.frame = 0
	session.phase = defs.PHASE.P1
	session.transition_stage = nil
	session.transition_reason = nil
	session.p2_summon_started = false
	session.opening_retried = false
	deployment.clear_opening_flag()
	director.resume_orders()
	director.mark_initial_done(defs.PHASE.P1)
	scheduler.reset(session.phase)
	local ent = refresh_boss_wrapper()
	if ent then
		local data = data_of(ent)
		if data then
			data.invulnerable = false
			-- Keep boss at designed top home for P1/P2.
			local home = arena.boss_spawn_pos()
			data.home = Vector(home.X, home.Y)
			ent.Position = home
		end
		init_p1_return_budget(ent)
		visual.idle2(ent)
	end
end

local function begin_opening_selection()
	session.state = defs.STATE.OPENING_SELECTION
	session.frame = 0
	session.transition_stage = nil
	session.opening_retried = false
	session.opening_first_land_frame = nil
	session.opening_command_played = false
	local ent = refresh_boss_wrapper()
	if ent then
		local data = data_of(ent)
		if data then
			data.invulnerable = true
		end
		visual.command(ent)
		session.opening_command_played = true
		director.begin_command_vuln(defs.COMMAND_VULN_FRAMES)
	end
	-- Three command souls + staff red lights (not legacy staggered deploy_opening).
	command_souls.begin_opening(ent)
end

local function begin_formation_enter()
	session.state = defs.STATE.FORMATION_ENTER
	session.frame = 0
	session.transition_stage = nil
	arena.seal_combat_doors()
	local ent = refresh_boss_wrapper()
	if ent then
		local data = data_of(ent)
		if data then
			data.invulnerable = true
		end
		visual.command(ent)
	end
	if not reserve_controller.is_prepared or not reserve_controller.is_prepared() then
		reserve_controller.prepare_formation()
	end
	local ok, why = reserve_controller.begin_march()
	if not ok then
		Isaac.DebugString("[FloraineV2] formation march failed: " .. tostring(why) .. "; fallback spawn_formation")
		reserve_controller.spawn_formation()
		begin_opening_selection()
	end
end

local function begin_intro()
	session.state = defs.STATE.INTRO
	session.frame = 0
	session.phase = defs.PHASE.P1
	session.transition_stage = nil
	temp_piece.clear_all("intro")
	command_souls.clear("intro")
	deployment.cancel_all("intro")
	-- Layout only — no matte pieces until FORMATION_ENTER march.
	reserve_controller.prepare_formation()
	director.bind()
	director.stop_orders()
	director.clear_command_vuln()
	local ent = controller.spawn_boss()
	if ent then
		local data = data_of(ent)
		if data then
			data.invulnerable = true
		end
		visual.idle(ent)
		visual.flash(ent, 0.3, 0.25, 0.1, 24)
	end
end

--- One-shot Raise→Cast chain for 点将 (scheduler / deploy path may also call).
function controller.on_command_cast(_reason)
	local ent = refresh_boss_wrapper()
	if ent then
		visual.command(ent)
	end
end

local function begin_defeat(ent)
	session.state = defs.STATE.DEFEAT
	session.frame = 0
	session.transition_stage = nil
	scheduler.on_defeat_or_leave()
	director.stop_orders()
	command_souls.set_suppress_death(true)
	director.kill_guards()
	command_souls.clear("defeat")
	command_souls.set_suppress_death(false)
	deployment.cancel_all("defeat")
	temp_piece.clear_all("defeat")
	clear_p2_systems("defeat")
	phase_transition.clear(ent)
	staff_transition.clear(ent)
	attacks.clear_royal_hits()
	runtime.mark_boss_defeated()
	if ent then
		visual.defeat(ent)
		local data = data_of(ent)
		if data then
			data.invulnerable = true
			data.attack = nil
		end
	end
end

local function begin_reward_pending()
	session.state = defs.STATE.REWARD_PENDING
	session.frame = 0
	arena.open_return_door()
	if rewards.should_offer_unlock() then
		rewards.spawn_seal()
	else
		session.state = defs.STATE.CLEARED
	end
end

local function clear_p2_systems(reason)
	p2_promotion.clear(reason or "clear")
	p2_columns.clear(reason or "clear")
end

local function begin_transition(to_phase, reason)
	if session.state == defs.STATE.PHASE_TRANSITION then
		return false, "already_transitioning"
	end
	to_phase = tonumber(to_phase) or (session.phase + 1)
	reason = reason or "hp_threshold"
	local ent = refresh_boss_wrapper()

	-- Clamp HP to the destination threshold before the show.
	if ent and ent.MaxHitPoints then
		local floor_hp = phase_mod.threshold_hp(ent, to_phase)
		if ent.HitPoints < floor_hp then
			ent.HitPoints = floor_hp
		end
	end

	royal_drop.clear("phase_transition")
	scheduler.on_defeat_or_leave()

	if session.phase == defs.PHASE.P2 or to_phase == defs.PHASE.P3 then
		clear_p2_systems("to_p3")
	end

	if to_phase == defs.PHASE.P2 and session.phase == defs.PHASE.P1 then
		phase_transition.begin(session, ent, to_phase, reason)
		return true
	end

	-- P2→P3 (or other): shorter lock without full staff show.
	session.state = defs.STATE.PHASE_TRANSITION
	session.frame = 0
	session.pending_phase = to_phase
	session.transition_reason = reason
	session.transition_stage = defs.TRANSITION_STAGE.LOCK
	session.p2_summon_started = false
	director.stop_orders()
	command_souls.stop_phase()
	temp_piece.clear_all("phase_transition")
	clear_p2_systems("phase_transition")
	if ent then
		visual.command(ent)
		visual.phase_tint(ent, to_phase)
	end
	return true
end

local function finish_transition()
	local ent = refresh_boss_wrapper()
	phase_transition.clear(ent)
	session.phase = session.pending_phase or session.phase
	session.pending_phase = nil
	session.transition_stage = nil
	session.transition_reason = nil
	session.p2_summon_started = false
	session.state = defs.STATE.COMBAT
	session.frame = 0
	director.resume_orders()
	director.on_phase_enter(session.phase)
	scheduler.reset(session.phase)
	if ent then
		local data = data_of(ent)
		if data then
			data.invulnerable = false
		end
		-- Snap HP to phase band top (P2 start = 70%, P3 = 35%).
		if ent.MaxHitPoints then
			local floor_hp = phase_mod.threshold_hp(ent, session.phase)
			if session.phase == defs.PHASE.P2 or session.phase == defs.PHASE.P3 then
				ent.HitPoints = math.max(ent.HitPoints, floor_hp)
				-- Also cap at previous band so we don't sit above the band we entered.
				local hi = defs.PHASE_HP[session.phase] and defs.PHASE_HP[session.phase].hi
				if hi then
					ent.HitPoints = math.min(ent.HitPoints, ent.MaxHitPoints * hi)
				end
			end
		end
		visual.phase_tint(ent, session.phase)
		if session.phase == defs.PHASE.P1 or session.phase == defs.PHASE.P2 then
			local home = arena.boss_spawn_pos()
			if data then
				data.home = Vector(home.X, home.Y)
			end
			ent.Position = home
		elseif session.phase == defs.PHASE.P3 then
			local room = Game():GetRoom()
			local dest = room:GetClampedPosition(ent.Position + Vector(0, 60), 20)
			if data then
				data.home = Vector(dest.X, dest.Y)
			end
			ent.Position = dest
		end
		if session.phase == defs.PHASE.P2 and not p2_columns.is_active() then
			local ok, why = p2_columns.begin()
			if not ok then
				Isaac.DebugString("[FloraineV2] finish_transition p2 begin fail: " .. tostring(why))
			end
			p2_promotion.reset()
		end
	end
end

--- One-shot command return settle (from command_souls). Idempotent per command id.
function controller.on_command_returned(cmd_id, _cmd)
	if session.phase ~= defs.PHASE.P1 then
		return false, "not_p1"
	end
	if session.state == defs.STATE.PHASE_TRANSITION then
		return false, "transitioning"
	end
	cmd_id = tonumber(cmd_id) or 0
	if session.returned_ids[cmd_id] then
		return false, "already"
	end
	session.returned_ids[cmd_id] = true
	session.commands_returned = (session.commands_returned or 0) + 1
	local ent = refresh_boss_wrapper()
	if not ent then
		return false, "no_boss"
	end
	local h2 = phase_mod.threshold_hp(ent, defs.PHASE.P2)
	local chunk = session.command_return_chunk or 0
	local next_hp = math.max(h2, ent.HitPoints - chunk)
	ent.HitPoints = next_hp
	local idx = math.min(3, session.commands_returned)
	local scale = (defs.P1_RETURN_BLEED and defs.P1_RETURN_BLEED[idx]) or 1
	visual.flash(ent, 0.55 * scale, 0.05, 0.05, math.floor(10 + 6 * scale))
	Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BLOOD_EXPLOSION, 0,
		ent.Position + Vector(0, -18), Vector.Zero, ent)
	if idx >= 3 then
		Game():ShakeScreen(math.floor(6 * scale))
	end
	if session.commands_returned >= (defs.P1_COMMAND_COUNT or 3)
		or ent.HitPoints <= h2 + 0.01 then
		ent.HitPoints = h2
		begin_transition(defs.PHASE.P2, "commands_exhausted")
	end
	return true
end

function controller.on_arena_enter()
	director.unbind()
	command_souls.clear("arena_enter")
	deployment.cancel_all("arena_enter")
	reserve_controller.clear("arena_enter")
	occupancy.clear_blocker("floraine_boss")
	occupancy.clear()
	temp_piece.clear_all("arena_enter")
	clear_p2_systems("arena_enter")
	phase_transition.clear(nil)
	staff_transition.clear(nil)
	scheduler.on_defeat_or_leave()
	session.frame = 0
	session.force_phase = nil
	session.transition_stage = nil
	session.commands_returned = 0
	session.returned_ids = {}

	if runtime.is_boss_defeated() then
		session.state = runtime.is_unlock_pending() and defs.STATE.REWARD_PENDING or defs.STATE.CLEARED
		arena.open_return_door()
		rewards.restore_if_pending()
		return
	end

	local r = runtime.get()
	if r.suppress_floraine then
		session.state = defs.STATE.WAITING
		arena.open_return_door()
		return
	end

	begin_intro()
end

function controller.on_arena_leave()
	scheduler.on_defeat_or_leave()
	director.unbind()
	command_souls.set_suppress_death(true)
	command_souls.clear("arena_leave")
	command_souls.set_suppress_death(false)
	deployment.cancel_all("arena_leave")
	reserve_controller.clear("arena_leave")
	occupancy.clear_blocker("floraine_boss")
	occupancy.clear()
	temp_piece.clear_all("arena_leave")
	clear_p2_systems("arena_leave")
	phase_transition.clear(nil)
	staff_transition.clear(nil)
	if session.state == defs.STATE.COMBAT
		or session.state == defs.STATE.INTRO
		or session.state == defs.STATE.FORMATION_ENTER
		or session.state == defs.STATE.OPENING_SELECTION
		or session.state == defs.STATE.PHASE_TRANSITION then
		director.kill_guards()
		local ent = refresh_boss_wrapper()
		if ent then
			ent:Remove()
		end
		session.boss_ptr = nil
		session.boss = nil
		session.state = defs.STATE.WAITING
	end
end

function controller.update(ent)
	if not controller.is_owned(ent) then
		return
	end
	session.boss_ptr = GetPtrHash(ent)
	session.boss = ent
	local data = data_of(ent)
	if not attacks.is_busy(data) then
		ent.Velocity = ((data.home or ent.Position) - ent.Position) * 0.15
	end
	-- Boss hard-block follows current grid (P3 shift included).
	occupancy.set_blocker("floraine_boss", "floraine_boss", ent.Position)
	session.frame = session.frame + 1
	-- Advance Boss-room door Close (logic seal + Close anim).
	if arena.tick then
		arena.tick()
	end

	-- Sole owner of command_particles advance (frame-deduped inside tick).
	if session.state == defs.STATE.OPENING_SELECTION
		or session.state == defs.STATE.COMBAT
		or session.state == defs.STATE.PHASE_TRANSITION then
		command_particles.tick()
	end

	local function tick_reserve_visual()
		local ok_rv, rv = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_visual")
		if ok_rv and rv and rv.tick then
			rv.tick()
		end
	end

	if session.state == defs.STATE.INTRO then
		-- Brief idle on throne; raise staff near the end of the hold.
		if session.frame == math.max(1, (defs.INTRO_FRAMES or 24) - 8) then
			visual.command(ent)
		else
			visual.tick_chain(ent)
		end
		if session.frame >= (defs.INTRO_FRAMES or 24) then
			begin_formation_enter()
		end
		return
	end

	if session.state == defs.STATE.FORMATION_ENTER then
		visual.tick_chain(ent)
		local done = reserve_controller.tick_march()
		tick_reserve_visual()
		if done then
			begin_opening_selection()
		end
		return
	end

	if session.state == defs.STATE.OPENING_SELECTION then
		visual.tick_chain(ent)
		command_souls.tick(ent)
		deployment.tick()
		tick_reserve_visual()
		local ost = command_souls.opening_status()
		local timed_out = session.frame >= (defs.OPENING_TIMEOUT_FRAMES or 240)
		-- Wait for the full opening batch to hand off before combat.
		if ost.complete then
			local settle = defs.OPENING_SETTLE_FRAMES or 15
			if not session.opening_first_land_frame then
				session.opening_first_land_frame = session.frame
			end
			if (session.frame - session.opening_first_land_frame) >= settle then
				begin_combat()
			end
		elseif (ost.landed or 0) > 0 and not ost.busy then
			-- Partial success (some souls exhausted): still enter combat after settle.
			if not session.opening_first_land_frame then
				session.opening_first_land_frame = session.frame
			end
			local settle = defs.OPENING_SETTLE_FRAMES or 15
			if (session.frame - session.opening_first_land_frame) >= settle then
				begin_combat()
			end
		elseif timed_out then
			if not session.opening_retried then
				session.opening_retried = true
				Isaac.DebugString("[FloraineV2] opening timeout; retry command souls")
				command_souls.begin_opening(ent)
				visual.command(ent)
			else
				Isaac.DebugString("[FloraineV2] opening still empty after retry; forcing combat (safety)")
				begin_combat()
			end
		end
		return
	end

	if session.state == defs.STATE.PHASE_TRANSITION then
		director.clear_command_vuln()
		-- Full P1→P2 show.
		if (session.pending_phase or 0) == defs.PHASE.P2 and (session.phase or 0) == defs.PHASE.P1 then
			local done = phase_transition.tick(session, ent)
			if done then
				finish_transition()
			end
			return
		end
		-- Compact P2→P3 (and debug skips).
		visual.tick_chain(ent)
		if session.frame >= (defs.TRANSITION_FRAMES or 40) then
			finish_transition()
		end
		return
	end

	if session.state == defs.STATE.DEFEAT then
		ent.HitPoints = math.max(1, ent.HitPoints)
		if session.frame >= defs.DEFEAT_FRAMES then
			begin_reward_pending()
			ent:Remove()
			session.boss_ptr = nil
			session.boss = nil
		end
		return
	end

	if session.state == defs.STATE.REWARD_PENDING or session.state == defs.STATE.CLEARED then
		return
	end

	if session.state ~= defs.STATE.COMBAT then
		return
	end

	local want = session.force_phase or phase_mod.next_target(session.phase, ent)
	session.force_phase = nil
	if want > session.phase then
		begin_transition(want, "hp_threshold")
		return
	end

	scheduler.tick(ent, data, session.frame, session.phase)
	visual.tick_chain(ent)
	tick_reserve_visual()
end

function controller.on_take_damage(ent, amt, flag, source, cooldown)
	if not controller.is_owned(ent) then
		return nil
	end
	local data = data_of(ent)
	if data.invulnerable then
		return false
	end
	if session.state == defs.STATE.INTRO
		or session.state == defs.STATE.FORMATION_ENTER
		or session.state == defs.STATE.OPENING_SELECTION
		or session.state == defs.STATE.PHASE_TRANSITION
		or session.state == defs.STATE.DEFEAT
		or session.state == defs.STATE.REWARD_PENDING
		or session.state == defs.STATE.CLEARED then
		return false
	end
	if amt > 50000 then
		ent.HitPoints = 1
		return false
	end

	local function check_lethal(incoming)
		local projected = ent.HitPoints - incoming
		if projected <= 0 or ent:HasMortalDamage() then
			begin_defeat(ent)
			ent.HitPoints = 1
			return true
		end
		return false
	end

	-- Floor: ordinary damage cannot push below the next-phase threshold.
	local floor_hp = phase_mod.floor_hp_for_current(ent, session.phase)
	local function clamp_to_floor(incoming)
		local projected = ent.HitPoints - incoming
		if projected < floor_hp then
			local allowed = math.max(0, ent.HitPoints - floor_hp)
			if allowed <= 0.01 then
				-- Already at floor: start transition instead of eating more HP.
				if session.phase < defs.PHASE.P3 then
					begin_transition(session.phase + 1, "hp_threshold")
				end
				return true, 0
			end
			return false, allowed
		end
		return false, incoming
	end

	-- Reduced hits re-enter with DAMAGE_CLONES; allow them through with floor clamp.
	if (flag & DamageFlag.DAMAGE_CLONES) ~= 0 then
		local at_floor, clamped = clamp_to_floor(amt)
		if at_floor then
			ent.HitPoints = floor_hp
			return false
		end
		if clamped < amt - 0.01 then
			ent.HitPoints = math.max(floor_hp, ent.HitPoints - clamped)
			if ent.HitPoints <= floor_hp + 0.01 and session.phase < defs.PHASE.P3 then
				begin_transition(session.phase + 1, "hp_threshold")
			end
			return false
		end
		if check_lethal(clamped) then
			return false
		end
		return nil
	end

	-- P1 guard shield: scale damage by active combat pieces (not redirected onto pieces).
	local factor = 1
	if session.phase == defs.PHASE.P1 and session.state == defs.STATE.COMBAT then
		factor = director.guard_damage_factor()
	end
	local taken = amt * factor
	local at_floor, clamped = clamp_to_floor(taken)
	if at_floor then
		ent.HitPoints = floor_hp
		return false
	end
	if factor < 0.999 or clamped < taken - 0.01 then
		ent:TakeDamage(clamped, flag | DamageFlag.DAMAGE_CLONES, source, cooldown)
		return false
	end

	if check_lethal(taken) then
		return false
	end
	return nil
end

function controller.debug_set_phase(p)
	-- Legacy: request transition toward p (forward only via force_phase).
	session.force_phase = math.max(1, math.min(3, tonumber(p) or 1))
end

function controller.debug_transition_to_phase(target_phase)
	target_phase = math.max(1, math.min(3, tonumber(target_phase) or 1))
	local ent = refresh_boss_wrapper()
	if not ent then
		return false, "no_boss"
	end
	if session.state == defs.STATE.PHASE_TRANSITION then
		return false, "transition_busy"
	end
	if target_phase == session.phase and session.state == defs.STATE.COMBAT then
		return false, "already_phase"
	end
	if target_phase < session.phase then
		return controller.debug_load_phase(target_phase)
	end
	-- Step forward one phase at a time with full transition when leaving P1.
	local next_p = session.phase + 1
	if next_p > target_phase then
		next_p = target_phase
	end
	begin_transition(next_p, "debug_full")
	return true
end

function controller.debug_load_phase(target_phase)
	target_phase = math.max(1, math.min(3, tonumber(target_phase) or 1))
	local ent = refresh_boss_wrapper()
	if not ent then
		-- Try spawn into arena.
		ent = controller.spawn_boss()
	end
	if not ent then
		return false, "no_boss"
	end
	phase_transition.clear(ent)
	staff_transition.clear(ent)
	clear_p2_systems("debug_load")
	royal_drop.clear("debug_load")
	temp_piece.clear_all("debug_load")
	command_souls.set_suppress_death(true)
	director.kill_guards()
	command_souls.clear("debug_load")
	command_souls.set_suppress_death(false)
	deployment.cancel_all("debug_load")
	reserve_controller.clear("debug_load")
	director.bind()
	director.stop_orders()

	session.force_phase = nil
	session.pending_phase = nil
	session.transition_stage = nil
	session.transition_reason = nil
	session.p2_summon_started = false
	session.phase = target_phase
	session.state = defs.STATE.COMBAT
	session.frame = 0

	local ratio = 1
	if target_phase == defs.PHASE.P2 then
		ratio = defs.PHASE_HP[1].lo
	elseif target_phase == defs.PHASE.P3 then
		ratio = defs.PHASE_HP[2].lo
	end
	ent.HitPoints = ent.MaxHitPoints * ratio
	local data = data_of(ent)
	if data then
		data.invulnerable = false
	end
	visual.set_staff_detached(ent, false)
	visual.idle2(ent)
	visual.phase_tint(ent, target_phase)

	if target_phase == defs.PHASE.P1 then
		local home = arena.boss_spawn_pos()
		if data then data.home = Vector(home.X, home.Y) end
		ent.Position = home
		reserve_controller.spawn_formation()
		command_souls.begin_opening(ent)
		-- Skip opening wait for debug: mark combat-ready souls after a beat is heavy;
		-- keep opening path so particles work. Force combat flag.
		init_p1_return_budget(ent)
		director.mark_initial_done(defs.PHASE.P1)
	elseif target_phase == defs.PHASE.P2 then
		local home = arena.boss_spawn_pos()
		if data then data.home = Vector(home.X, home.Y) end
		ent.Position = home
		local ok, why = p2_columns.begin()
		if not ok then
			return false, why or "p2_begin_failed"
		end
		p2_promotion.reset()
		director.mark_initial_done(defs.PHASE.P2)
	else
		local room = Game():GetRoom()
		local dest = room:GetClampedPosition(arena.boss_spawn_pos() + Vector(0, 60), 20)
		if data then data.home = Vector(dest.X, dest.Y) end
		ent.Position = dest
		director.mark_initial_done(defs.PHASE.P3)
	end
	scheduler.reset(session.phase)
	director.resume_orders()
	return true
end

function controller.debug_set_hp_ratio(ratio)
	local ent = refresh_boss_wrapper()
	if not ent then return false, "no_boss" end
	ratio = math.max(0.01, math.min(1, tonumber(ratio) or 1))
	ent.HitPoints = ent.MaxHitPoints * ratio
	return true
end

function controller.begin_transition_public(to_phase, reason)
	return begin_transition(to_phase, reason)
end

function controller.debug_defeat()
	local ent = refresh_boss_wrapper()
	if ent then
		begin_defeat(ent)
	else
		runtime.mark_boss_defeated()
		begin_reward_pending()
	end
end

function controller.debug_start_combat()
	if session.state == defs.STATE.INTRO
		or session.state == defs.STATE.WAITING
		or session.state == defs.STATE.FORMATION_ENTER
		or session.state == defs.STATE.OPENING_SELECTION then
		if not refresh_boss_wrapper() then
			controller.spawn_boss()
		end
		if not reserve_controller.is_active() then
			-- Debug skip: instant formation (no door march).
			reserve_controller.spawn_formation()
		end
		director.bind()
		director.stop_orders()
		if session.state ~= defs.STATE.OPENING_SELECTION then
			arena.seal_combat_doors()
			begin_opening_selection()
		end
	end
end

function controller.debug_force_pattern(name)
	scheduler.force_pattern(name)
	-- Nudge cooldown so next formation tick fires it.
	local st = scheduler.get_state()
	st.next_temp_frame = 0
end

function controller.debug_reset_combat()
	if runtime.is_unlock_pending() or runtime.is_boss_defeated() then
		session.state = runtime.is_unlock_pending() and defs.STATE.REWARD_PENDING or defs.STATE.CLEARED
		arena.open_return_door()
		rewards.restore_if_pending()
		return false, "pending_reward"
	end
	scheduler.on_defeat_or_leave()
	director.unbind()
	command_souls.set_suppress_death(true)
	director.kill_guards()
	command_souls.clear("debug_reset_combat")
	command_souls.set_suppress_death(false)
	deployment.cancel_all("debug_reset_combat")
	reserve_controller.clear("debug_reset_combat")
	temp_piece.clear_all("debug_reset_combat")
	clear_p2_systems("debug_reset_combat")
	phase_transition.clear(nil)
	staff_transition.clear(nil)
	local ent = refresh_boss_wrapper()
	if ent then ent:Remove() end
	session.boss_ptr = nil
	session.boss = nil
	session.state = defs.STATE.WAITING
	session.transition_stage = nil
	begin_intro()
	return true
end

function controller.debug_reset_test_state()
	local r = runtime.get()
	r.boss_defeated = false
	r.unlock_pending = false
	rewards.remove_all_seals()
	scheduler.on_defeat_or_leave()
	director.unbind()
	command_souls.set_suppress_death(true)
	director.kill_guards()
	command_souls.clear("debug_reset_test")
	command_souls.set_suppress_death(false)
	deployment.cancel_all("debug_reset_test")
	reserve_controller.clear("debug_reset_test")
	temp_piece.clear_all("debug_reset_test")
	clear_p2_systems("debug_reset_test")
	phase_transition.clear(nil)
	staff_transition.clear(nil)
	local ent = refresh_boss_wrapper()
	if ent then ent:Remove() end
	session.boss_ptr = nil
	session.boss = nil
	session.state = defs.STATE.WAITING
	session.transition_stage = nil
	begin_intro()
	return true
end

function controller.debug_reset_encounter()
	return controller.debug_reset_combat()
end

return controller
