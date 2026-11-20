-- Zennith Combat P1 — Phase 1 storm cadence (modular orchestrator).
-- WIND_SHIFT → FORM → RELEASE → DISSOLVE → REST
-- Structural split only: attack behavior owned by combat_p1_*.lua modules.

local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local wind = require("Qing_Remaster_scripts.threads.wind.wind_runtime")
local wind_physics = require("Qing_Remaster_scripts.threads.wind.wind_physics")
local wind_emission = require("Qing_Remaster_scripts.threads.wind.wind_emission")
local boss_wind = require("Qing_Remaster_scripts.bosses.Zennith.boss_wind_controller")
local p1_visual = require("Qing_Remaster_scripts.bosses.Zennith.combat_p1_visual")

local common = require("Qing_Remaster_scripts.bosses.Zennith.combat_p1_common")
local movement = require("Qing_Remaster_scripts.bosses.Zennith.combat_p1_movement")
local projectiles = require("Qing_Remaster_scripts.bosses.Zennith.combat_p1_projectiles")
local sweep = require("Qing_Remaster_scripts.bosses.Zennith.combat_p1_sweep")
local split = require("Qing_Remaster_scripts.bosses.Zennith.combat_p1_split")
local gust = require("Qing_Remaster_scripts.bosses.Zennith.combat_p1_gust")
local diagnostics = require("Qing_Remaster_scripts.bosses.Zennith.combat_p1_diagnostics")

local M = {
	own_key = "Enemies_Zennith_p1_",
	P1_FLOOR = 0.65,
	BLOOD_ANM2 = "gfx/boss/Zennith/zennith_blood_tear.anm2",
	HOLD_HEIGHT = -23,
}

local Env = {
	M = M,
	auxi = auxi,
	wind = wind,
	wind_physics = wind_physics,
	wind_emission = wind_emission,
	boss_wind = boss_wind,
	p1_visual = p1_visual,
}

common.register(Env)
movement.register(Env)
projectiles.register(Env)
sweep.register(Env)
split.register(Env)
gust.register(Env)
diagnostics.register(Env)

do
	function Env.pick_attack(sess)
		local pool = {}
		for i = 1, #Env.ORDER do
			local id = Env.ORDER[i]
			if id ~= sess.last_attack then
				pool[#pool + 1] = id
			end
		end
		if #pool == 0 then pool = Env.ORDER end
		local idx = 1 + math.floor(Env.boss_rand(sess) * #pool)
		if idx > #pool then idx = #pool end
		return pool[idx]
	end
	function Env.begin_attack(sess, attack_id, forced)
		local def = Env.ATTACK[attack_id]
		if not def then return false, "unknown_attack" end
		local boss = sess.boss
		if not Env.living(boss) then return false, "no_boss" end
		-- Soft prepare: keep on-screen gust / split_child orphans; hard clear is cancel/death only.
		Env.clear_ephemeral_objects(sess)
		Env.clear_retreat(sess)
		sess.release_frames = nil
		sess.attack = attack_id
		sess.phase = "wind_shift"
		sess.age = 0
		sess.forced = forced == true
		sess.last_attack = attack_id
		sess.meta = {}
		sess.wall = nil
		sess.clock = 0
		sess.wind_from = sess.ambient_ang or 0
		sess.wind_target = sess.wind_from
		-- Do not start Attack* here; WIND_SHIFT stays Idle until FORM.
		Env.ensure_idle(boss)
		boss.Velocity = Vector(0, 0)
		Env.keep_ambient(sess, sess.ambient_ang, 0.28)
		return true
	end

	function Env.end_attack(sess, hard)
		local boss = sess.boss
		Env.clear_retreat(sess)
		if hard then
			Env.clear_objects(sess)
		else
			Env.release_objects(sess)
			if sess.wall then
				sess.wall.visible = false
				sess.wall.damaging = false
			end
		end
		Env.keep_ambient(sess, sess.ambient_ang, 0.22)
		sess.attack = nil
		sess.phase = "idle"
		sess.age = 0
		sess.meta = {}
		sess.wall = nil
		sess.force_travel_dir = nil
		Env.clear_facing_lock(sess)
		sess.cooldown = 20
		if Env.living(boss) then
			Env.ensure_idle(boss)
		end
	end
	function Env.tick_attack_body(sess)
		local id = sess.attack
		if id == "wind_sweep" then
			Env.tick_sweep(sess)
		elseif id == "wind_split" then
			Env.tick_split(sess)
		elseif id == "wind_gust" then
			Env.tick_gust(sess)
		end
	end

	function Env.tick_wind_shift(sess)
		local def = Env.ATTACK[sess.attack]
		local lim = def and def.wind_shift or 24
		local t = math.min(1, sess.age / math.max(1, lim))
		-- Finish most of the turn before FORM (ease toward target).
		local eased = t * t * (3 - 2 * t)
		local ang = Env.angle_lerp(sess.wind_from or 0, sess.wind_target or 0, eased)
		local intensity = 0.28 + 0.4 * eased
		Env.set_wind_ang(sess, ang, intensity)
	end

	function Env.advance_phase(sess)
		local def = Env.ATTACK[sess.attack]
		if not def then
			Env.end_attack(sess, true)
			return
		end
		sess.age = sess.age + 1
		sess.clock = (sess.clock or 0) + 1
		-- Attack body first so wind_shift age==1 can choose the target angle
		-- before the smooth turn samples it.
		Env.tick_attack_body(sess)
		if sess.phase == "wind_shift" then
			Env.tick_wind_shift(sess)
		end

		local limit = def[sess.phase]
		if not limit or sess.age < limit then return end

		sess.age = 0
		local idx = 1
		for i = 1, #Env.PHASES do
			if Env.PHASES[i] == sess.phase then idx = i break end
		end
		local next_phase = Env.PHASES[idx + 1]
		if not next_phase then
			Env.end_attack(sess, false)
			return
		end
		sess.phase = next_phase
		if next_phase == "form" then
			Env.set_wind_ang(sess, sess.wind_target or sess.ambient_ang, 0.62)
		elseif next_phase == "release" then
			Env.set_wind_ang(sess, sess.wind_target or sess.ambient_ang, 0.88)
			Env.boss_wind.pulse({intensity = 0.16})
		elseif next_phase == "dissolve" then
			Env.keep_ambient(sess, sess.ambient_ang, 0.35)
			if sess.attack == "wind_sweep" and sess.wall then
				sess.wall.damaging = false
			end
			Env.ensure_idle(sess.boss)
		elseif next_phase == "rest" then
			Env.keep_ambient(sess, sess.ambient_ang, 0.22)
			Env.ensure_idle(sess.boss)
			Env.clear_retreat(sess)
			if sess.wall then
				sess.wall.visible = false
				sess.wall.damaging = false
			end
		end
		Env.sync_boss_anim(sess)
		Env.tick_attack_body(sess)
	end

	function Env.float_idle(sess)
		local boss = sess.boss
		if not Env.living(boss) then return end
		local _, _, center = Env.room_bounds()
		local target = center + Vector(math.sin((sess.float_t or 0) * 0.04) * 40, -12 + math.cos((sess.float_t or 0) * 0.03) * 18)
		local delta = target - boss.Position
		boss.Velocity = boss.Velocity * 0.85 + delta:Resized(math.min(2.2, delta:Length() * 0.04))
		sess.float_t = (sess.float_t or 0) + 1
		Env.ensure_idle(boss)
	end

	function Env.get_sess(boss, create)
		local key = Env.ptr(boss)
		if not key then return nil end
		local sess = Env.sessions[key]
		if sess then
			sess.boss = boss
			return sess
		end
		if not create then return nil end
		sess = {
			boss = boss,
			boss_ptr = key,
			phase = "idle",
			attack = nil,
			age = 0,
			cooldown = 30,
			last_attack = nil,
			objects = {},
			rng = (boss.InitSeed or 1) % 2147483648,
			force_p1 = false,
			frozen = false,
			complete = false,
			float_t = 0,
			meta = {},
			ambient_ang = 0,
			wind_from = 0,
			wind_target = 0,
		}
		Env.sessions[key] = sess
		return sess
	end

	function Env.maintain_projectiles(sess)
		local meta = sess.meta
		local blow = Env.wind_dir_vec(sess.ambient_ang or 0)
		-- Orphan gust tears keep rising/drifting when no active wind_gust body tick owns them.
		if Env.tick_gust_particles and (not sess.attack or sess.attack ~= "wind_gust") then
			Env.tick_gust_particles(sess)
		end
		for key, ent in pairs(sess.objects) do
			if not (ent and ent.Exists and ent:Exists()) then
				sess.objects[key] = nil
			else
				local d = ent:GetData()
				Env.hold_projectile_height(ent)
				-- Keep orphaned fan tears accelerating after the Boss phase ends.
				if d[Env.M.own_key .. "split_child"] and (not sess.attack or sess.attack ~= "wind_split") then
					local t = (d[Env.M.own_key .. "fan_age"] or 0) + 1
					d[Env.M.own_key .. "fan_age"] = t
					local need = d[Env.M.own_key .. "fan_accel_need"] or Env.SPLIT_ACCEL_FRAMES
					local u = Env.ease_out_quad(math.min(1, t / need))
					local spd0 = d[Env.M.own_key .. "fan_spd0"] or Env.SPLIT_SPEED_START
					local spd1 = d[Env.M.own_key .. "fan_spd1"] or Env.SPLIT_SPEED_END
					local spd = spd0 + (spd1 - spd0) * u
					local ang = d[Env.M.own_key .. "fan_ang"]
					local base = ang and Vector.FromAngle(ang) or (
						ent.Velocity:Length() > 0.1 and ent.Velocity:Normalized() or blow
					)
					ent.Velocity = base:Resized(spd) + blow:Resized(0.08 + 0.18 * u)
					if t >= Env.SPLIT_CHILD_HARMLESS then
						ent.CollisionDamage = 1
					end
				end
				local should_cull
				if d[Env.M.own_key .. "gust"] then
					-- Gust: recycle only after sprite fully leaves screen simulation rect.
					should_cull = Env.projectile_fully_offscreen(ent)
				else
					should_cull = Env.out_of_room(ent.Position, Env.ROOM_EXIT_MARGIN)
				end
				if should_cull then
					if meta and d[Env.M.own_key .. "gust"] and not d[Env.M.own_key .. "entered_view"] then
						meta.removed_before_view = (meta.removed_before_view or 0) + 1
					end
					ent:Remove()
					sess.objects[key] = nil
				elseif d[Env.M.own_key .. "effect"] and ent.Velocity and ent.Velocity:Length() > 0.2
					and not d[Env.M.own_key .. "split_parent"] then
					local spr = ent:GetSprite()
					if spr then spr.Rotation = ent.Velocity:GetAngleDegrees() end
				end
			end
		end
	end
end

function M.has_session(boss)
	return Env.get_sess(boss, false) ~= nil
end

function M.begin(boss, opts)
	opts = opts or {}
	if not Env.living(boss) then return false, "no_boss" end
	local sess = Env.get_sess(boss, true)
	Env.clear_objects(sess)
	sess.release_frames = nil
	sess.phase = "idle"
	sess.attack = nil
	sess.age = 0
	sess.cooldown = opts.cooldown or 24
	sess.force_p1 = opts.force_p1 == true
	sess.complete = false
	sess.frozen = false
	sess.meta = {}
	sess.ambient_ang = 0
	sess.wind_from = 0
	sess.wind_target = 0
	Env.keep_ambient(sess, 0, 0.22)
	Env.ensure_idle(boss)
	return true
end

function M.cancel(boss)
	local sess = Env.get_sess(boss, false)
	if not sess then return false, "no_session" end
	Env.end_attack(sess, true)
	sess.complete = false
	return true
end

function M.clear_objects(boss)
	local sess = Env.get_sess(boss, false)
	if not sess then return false, "no_session" end
	Env.clear_objects(sess)
	return true
end

function M.shutdown(boss)
	if boss then
		local sess = Env.get_sess(boss, false)
		if sess then
			Env.clear_objects(sess)
			Env.boss_wind.clear()
			Env.sessions[sess.boss_ptr] = nil
		end
		return true
	end
	for key, sess in pairs(Env.sessions) do
		Env.clear_objects(sess)
		Env.sessions[key] = nil
	end
	Env.boss_wind.clear()
	return true
end

function M.force_attack(boss, attack_id)
	local sess = Env.get_sess(boss, true)
	local dir = nil
	if attack_id == "wind_sweep_lr" then
		attack_id = "wind_sweep"
		dir = 1
	elseif attack_id == "wind_sweep_rl" then
		attack_id = "wind_sweep"
		dir = -1
	end
	sess.force_travel_dir = dir
	return Env.begin_attack(sess, attack_id, true)
end

function M.next_attack(boss)
	local sess = Env.get_sess(boss, true)
	local id = Env.pick_attack(sess)
	return Env.begin_attack(sess, id, true)
end

function M.set_frozen(boss, frozen)
	local sess = Env.get_sess(boss, true)
	sess.frozen = frozen == true
	return true
end

function M.set_force_p1(boss, on)
	local sess = Env.get_sess(boss, true)
	sess.force_p1 = on == true
	if sess.force_p1 then sess.complete = false end
	return true
end

function M.step(boss, frames)
	frames = math.max(1, math.floor(tonumber(frames) or 1))
	local sess = Env.get_sess(boss, true)
	local was = sess.frozen
	sess.frozen = false
	for _ = 1, frames do
		M.tick(boss)
	end
	sess.frozen = was
	return true
end

function M.set_wall_layer(name, on)
	return p1_visual.set_layer(name, on)
end

function M.get_wall_layers()
	return p1_visual.get_layers()
end

function M.attack_defs()
	local out = {
		{id = "wind_sweep", label = "风幕横扫", group = "P1"},
		{id = "wind_sweep_lr", label = "风幕 · 左→右", group = "P1"},
		{id = "wind_sweep_rl", label = "风幕 · 右→左", group = "P1"},
		{id = "wind_split", label = Env.ATTACK.wind_split.label, group = "P1"},
		{id = "wind_gust", label = Env.ATTACK.wind_gust.label, group = "P1"},
	}
	return out
end

function M.render()
	for _, sess in pairs(Env.sessions) do
		if sess.wall and sess.wall.visible then
			p1_visual.render_wall(sess.wall)
		end
		local cuts = sess.meta and sess.meta.cut_fx
		if cuts and #cuts > 0 then
			p1_visual.render_cuts(cuts)
		end
	end
end


function M.inspect(boss)
	return Env.inspect_session(boss)
end

function M.format_combat_diag(info)
	return Env.format_combat_diag(info)
end

function M.on_projectile_update(ent)
	if not ent then return end
	local d = ent:GetData()
	if d[M.own_key .. "hold_h"] ~= nil then
		Env.hold_projectile_height(ent)
	end
end

function M.tick(boss)
	if not Env.living(boss) then
		M.shutdown(boss)
		return
	end
	local sess = Env.get_sess(boss, true)
	sess.boss = boss
	if sess.frozen then
		boss.Velocity = Vector(0, 0)
		return
	end

	-- Legacy release_frames path: never force-delete gust / split_child.
	-- Current release_objects no longer arms this timer for normal soft ends.
	if sess.release_frames then
		sess.release_frames = sess.release_frames - 1
		for key, ent in pairs(sess.objects) do
			if not (ent and ent.Exists and ent:Exists()) then
				sess.objects[key] = nil
			else
				Env.hold_projectile_height(ent)
				local d = ent:GetData()
				if Env.is_lingering_projectile(ent) then
					-- leave for Env.maintain_projectiles / offscreen or room exit
				elseif Env.out_of_room(ent.Position, Env.ROOM_EXIT_MARGIN) then
					ent:Remove()
					sess.objects[key] = nil
				end
			end
		end
		if sess.release_frames <= 0 then
			for key, ent in pairs(sess.objects) do
				if ent and ent.Exists and ent:Exists() then
					if Env.is_lingering_projectile(ent) then
						-- keep flying
					else
						ent:Remove()
						sess.objects[key] = nil
					end
				else
					sess.objects[key] = nil
				end
			end
			sess.release_frames = nil
			sess.release_mode = nil
		end
	end

	Env.maintain_projectiles(sess)

	if not sess.force_p1 and not sess.complete and Env.hp_ratio(boss) <= M.P1_FLOOR then
		Env.end_attack(sess, true)
		sess.complete = true
		boss.Velocity = Vector(0, 0)
		Env.ensure_idle(boss)
		return
	end
	if sess.complete and not sess.force_p1 then
		boss.Velocity = Vector(0, 0)
		Env.ensure_idle(boss)
		return
	end

	if sess.attack then
		-- Shared retreat owns Velocity when active; otherwise freeze horizontal drift.
		if not Env.tick_retreat(sess) then
			boss.Velocity = Vector(0, 0)
		end
		Env.sync_facing(sess)
		Env.advance_phase(sess)
		Env.sync_boss_anim(sess)
		Env.sync_facing(sess)
		return
	end

	Env.float_idle(sess)
	if not (Env.wind.session and Env.wind.session.kind == "boss") then
		Env.keep_ambient(sess, sess.ambient_ang, 0.22)
	end
	sess.cooldown = (sess.cooldown or 0) - 1
	if sess.cooldown <= 0 then
		local id = Env.pick_attack(sess)
		Env.begin_attack(sess, id, false)
	end
end



return M
