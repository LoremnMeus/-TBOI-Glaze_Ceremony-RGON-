-- Air Flight crash FSM / crash FX.
-- Structural extract from Item_Air_Flight.lua. No gameplay/UI semantic changes.
local save = require("Qing_Remaster_scripts.core.savedata")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Craft_Ludovico_holder = require("Qing_Remaster_scripts.mimics.Craft_Ludovico_holder")

local M = {}

function M.attach(item, Air)

-- 制造飞行器坠毁：fail→fall→impact→tumble→revive/dead
-- 自管高度与朝向；坠毁中禁止走 apply_air_aim_visual。
-- 复活账本见 CraftProfile.CRAFT_REVIVE_*；视觉参数见 item.crash_fx。
-- 方案：codex_work/notes/air_flight_crash_visual_design.md

local CRASH_FX_DEFAULTS = {
	fail_frames = 7,
	gravity = 0.38,
	max_fall_speed = 7.5,
	drift_retain = 0.985,
	side_slip_max = 1.8,
	fall_smoke_interval = 5,
	tumble_friction = 0.90,
	tumble_max_frames = 24,
	impact_dust_count = 8,
	dead_smoke_min = 18,
	dead_smoke_max = 30,
	screen_shake = 4,
	particle_cap = 10,
	fail_z_vel_target = 1.2,
	impact_frames = 6,
	revive_frames = 14,
	margin = 20,
}

item.crash_fx = item.crash_fx or {}

local function crash_fx_get(key)
	local override = item.crash_fx[key]
	if override ~= nil then return override end
	local root = save.ModConfigSettings
	local debug_settings = root and root.QingRemasterOptions and root.QingRemasterOptions.Debug
	local cfg_key = "FlightCrash_" .. tostring(key)
	local from_cfg = debug_settings and debug_settings[cfg_key]
	if from_cfg ~= nil then return from_cfg end
	return CRASH_FX_DEFAULTS[key]
end

function item.crash_fx_restore_defaults()
	for k, v in pairs(CRASH_FX_DEFAULTS) do
		item.crash_fx[k] = v
		local root = save.ModConfigSettings
		if root and root.QingRemasterOptions and root.QingRemasterOptions.Debug then
			root.QingRemasterOptions.Debug["FlightCrash_" .. k] = v
		end
	end
end

local function air_crash_fx_list(d)
	d[item.own_key.."CrashFx"] = d[item.own_key.."CrashFx"] or {}
	return d[item.own_key.."CrashFx"]
end

local function air_crash_prune_fx(d)
	local list = air_crash_fx_list(d)
	local kept = {}
	for i = 1, #list do
		local fx = list[i]
		if auxi.check_all_exists(fx) then
			kept[#kept + 1] = fx
		end
	end
	d[item.own_key.."CrashFx"] = kept
	return kept
end

local function air_crash_cleanup_fx(d)
	if not d then return end
	local list = air_crash_fx_list(d)
	for i = 1, #list do
		local fx = list[i]
		if auxi.check_all_exists(fx) then
			fx:Remove()
		end
	end
	d[item.own_key.."CrashFx"] = {}
end

local function air_crash_stop_normal_trail(ent, d)
	local trail = d[item.own_key.."Trail"]
	if auxi.check_all_exists(trail) then
		trail.Parent = nil
		trail:Remove()
	end
	d[item.own_key.."Trail"] = nil
	d[item.own_key.."TrailSuppress"] = true
end

local function air_crash_rng(ent, crash, salt)
	crash.fx_serial = (tonumber(crash.fx_serial) or 0) + 1
	local rng = RNG()
	local seed = (ent.InitSeed or 1) + crash.fx_serial * 1103515245 + (salt or 0)
	seed = math.floor(seed % 2147483647)
	if seed <= 0 then seed = seed + 2147483646 end
	rng:SetSeed(seed, 35)
	return rng
end

local function air_crash_can_spawn(d)
	local list = air_crash_prune_fx(d)
	local cap = tonumber(crash_fx_get("particle_cap")) or 10
	return #list < cap, list
end

local function air_crash_track(d, fx)
	if not fx then return end
	local list = air_crash_fx_list(d)
	list[#list + 1] = fx
end

local function air_crash_spawn_smoke(ent, d, crash, kind)
	local ok = air_crash_can_spawn(d)
	if not ok then return nil end
	local rng = air_crash_rng(ent, crash, kind == "dead" and 77 or (kind == "fall" and 33 or 11))
	-- 视觉烟：DUST_CLOUD（59）。勿用 SMOKE_CLOUD（毒气伤）/ DARK_BALL_SMOKE（黑球粒子）。
	-- 参考 Reverie/Epiphany：必须同时设 LifeSpan + Timeout。
	local variant = EffectVariant.DUST_CLOUD or EffectVariant.POOF02 or EffectVariant.POOF01
	local face = crash.face or Vector(0, 1)
	local back = Vector(-face.X, -face.Y)
	if back:Length() < 0.01 then back = Vector(0, 1) end
	back = back:Normalized():Resized(3 + rng:RandomFloat() * 5)
	local pos = ent.Position + back
	local drift = Vector(
		(rng:RandomFloat() - 0.5) * 0.6,
		-0.2 - rng:RandomFloat() * 0.35
	)
	-- Spawner 用 nil，避免跟随飞行器 PositionOffset 把烟抬飞
	local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, variant, 0, pos, drift, nil)
	if not fx then return nil end
	fx = fx:ToEffect() or fx
	local scale = 0.65
	local life = 14
	if kind == "fail" then
		scale = 0.55 + rng:RandomFloat() * 0.2
		life = 10 + rng:RandomInt(6)
		fx:SetColor(Color(0.45, 0.45, 0.48, 0.7, 0, 0, 0), -1, 0)
	elseif kind == "fall" then
		scale = 0.7 + rng:RandomFloat() * 0.25
		life = 12 + rng:RandomInt(8)
		fx:SetColor(Color(0.5, 0.38, 0.35, 0.75, 0.05, 0, 0), -1, 0)
	elseif kind == "revive" then
		scale = 0.4 + rng:RandomFloat() * 0.2
		life = 8 + rng:RandomInt(6)
		fx:SetColor(Color(0.7, 0.95, 0.8, 0.5, 0, 0.08, 0.04), -1, 0)
		fx.Velocity = Vector((rng:RandomFloat() - 0.5) * 0.4, 0.5 + rng:RandomFloat() * 0.5)
	else -- dead：低频残骸烟
		scale = 0.65 + rng:RandomFloat() * 0.3
		life = 20 + rng:RandomInt(12)
		fx:SetColor(Color(0.4, 0.4, 0.42, 0.55, 0, 0, 0), -1, 0)
	end
	fx.SpriteScale = Vector(scale, scale)
	if fx.LifeSpan ~= nil then fx.LifeSpan = life end
	if fx.Timeout ~= nil then fx.Timeout = life end
	fx.DepthOffset = -30
	air_crash_track(d, fx)
	return fx
end

local function air_crash_spawn_sparks(ent, d, crash, count)
	count = math.max(1, math.floor(tonumber(count) or 4))
	local rng = air_crash_rng(ent, crash, 91)
	local face = crash.face or Vector(0, 1)
	local back = Vector(-face.X, -face.Y)
	if back:Length() < 0.01 then back = Vector(0, 1) end
	back = back:Normalized()
	-- 碎屑/火花：小 poof，勿用泪弹消失特效
	local variant = EffectVariant.BULLET_POOF or EffectVariant.POOF01
	for i = 1, count do
		local ok = air_crash_can_spawn(d)
		if not ok then break end
		local ang = (rng:RandomFloat() * 70 - 35)
		local dir = back:Rotated(ang):Resized(2.2 + rng:RandomFloat() * 2.5)
		local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, variant, 0, ent.Position, dir, nil)
		if fx then
			fx = fx:ToEffect() or fx
			fx:SetColor(Color(1, 0.7, 0.3, 0.85, 0.15, 0.04, 0), -1, 0)
			fx.SpriteScale = Vector(0.4 + rng:RandomFloat() * 0.2, 0.4)
			local life = 8 + rng:RandomInt(8)
			if fx.LifeSpan ~= nil then fx.LifeSpan = life end
			if fx.Timeout ~= nil then fx.Timeout = life end
			air_crash_track(d, fx)
		end
	end
end

local function air_crash_spawn_impact_dust(ent, d, crash)
	local n = math.floor(tonumber(crash_fx_get("impact_dust_count")) or 8)
	local rng = air_crash_rng(ent, crash, 55)
	-- 接地大团：POOF02（常见尘爆）；径向：DUST_CLOUD
	local core_var = EffectVariant.POOF02 or EffectVariant.ROCK_POOF or EffectVariant.POOF01
	local ok = air_crash_can_spawn(d)
	if ok then
		-- subtype 1：多数模组用作落地/受击尘团
		local core = Isaac.Spawn(EntityType.ENTITY_EFFECT, core_var, 1, ent.Position, Vector.Zero, nil)
		if core then
			core = core:ToEffect() or core
			core.SpriteScale = Vector(1.05, 1.05)
			local life = 16
			if core.LifeSpan ~= nil then core.LifeSpan = life end
			if core.Timeout ~= nil then core.Timeout = life end
			air_crash_track(d, core)
		end
	end
	local dust = EffectVariant.DUST_CLOUD or EffectVariant.POOF01
	for i = 1, n do
		ok = air_crash_can_spawn(d)
		if not ok then break end
		local ang = (360 / n) * (i - 1) + rng:RandomFloat() * 12
		local dir = auxi.MakeVector(ang):Resized(1.4 + rng:RandomFloat() * 2.0)
		local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, dust, 0, ent.Position, dir, nil)
		if fx then
			fx = fx:ToEffect() or fx
			fx:SetColor(Color(0.55, 0.5, 0.42, 0.8, 0, 0, 0), -1, 0)
			local sc = 0.5 + rng:RandomFloat() * 0.3
			fx.SpriteScale = Vector(sc, sc)
			local life = 12 + rng:RandomInt(8)
			if fx.LifeSpan ~= nil then fx.LifeSpan = life end
			if fx.Timeout ~= nil then fx.Timeout = life end
			fx.DepthOffset = -20
			air_crash_track(d, fx)
		end
	end
end

local function air_crash_safe_steer(ent, crash, room)
	if not room then return Vector(0, 0) end
	local margin = tonumber(crash_fx_get("margin")) or 20
	local z = math.abs(tonumber(crash.z) or 0)
	local zv = math.max(0.4, tonumber(crash.z_vel) or 1)
	local remaining = math.max(1, math.ceil(z / zv))
	local predicted = ent.Position + (ent.Velocity or Vector.Zero) * remaining
	local clamped = room:GetClampedPosition(predicted, margin)
	local free = room:FindFreePickupSpawnPosition(clamped, 10, true)
	if not free then return Vector(0, 0) end
	if (free - predicted):Length() <= 10 then return Vector(0, 0) end
	local to_safe = free - ent.Position
	if to_safe:Length() < 1 then return Vector(0, 0) end
	return to_safe:Normalized() * 0.4
end

local function air_crash_clamp_tumble(ent, room)
	if not room then return end
	local margin = tonumber(crash_fx_get("margin")) or 20
	local before = ent.Position
	local clamped = room:GetClampedPosition(before, margin)
	if (clamped - before):Length() > 0.5 then
		local push = clamped - before
		local vel = ent.Velocity or Vector.Zero
		-- 削去朝墙外的法向分量，保留切向
		if push:Length() > 0.01 and vel:Length() > 0.01 then
			local n = push:Normalized()
			local into = (vel.X * (-n.X) + vel.Y * (-n.Y))
			if into > 0 then
				vel = vel + n * into
			end
			ent.Velocity = vel * 0.85
		end
		ent.Position = clamped
	end
end

local function air_begin_crash(ent, d)
	if d[item.own_key.."Crash"] then return end
	local face = d[item.own_key.."RotDir"] or d[item.own_key.."FaceU"] or ent.Velocity
	if not face or face:Length() < 0.01 then face = Vector(0, 1) end
	face = face:Normalized()
	local z = tonumber(d[item.own_key.."OffsetZ"])
	if z == nil then
		z = (ent.PositionOffset and ent.PositionOffset.Y) or Air.AIR_AIM_VIS.base_offset
	end
	local spin = (((ent.InitSeed or 1) % 2 == 0) and 1) or -1
	local drift = Vector((ent.Velocity and ent.Velocity.X) or 0, (ent.Velocity and ent.Velocity.Y) or 0)
	d[item.own_key.."Crash"] = {
		phase = "fail",
		t = 0,
		phase_t = 0,
		face = Vector(face.X, face.Y),
		spin = spin,
		start_z = z,
		z = z,
		z_vel = 0,
		gravity = tonumber(crash_fx_get("gravity")) or 0.38,
		max_fall_speed = tonumber(crash_fx_get("max_fall_speed")) or 7.5,
		drift_vel = drift,
		roll_vel = Vector(0, 0),
		roll_angle = 0,
		roll_speed = 4 * spin,
		smoke_cd = 0,
		fx_serial = 0,
		final_rotation = nil,
		impact_done = false,
	}
	air_crash_stop_normal_trail(ent, d)
	Air.clear_passway(d)
	d[item.own_key.."Flourish"] = nil
	d[item.own_key.."AuxAimDirection"] = nil
	d[item.own_key.."AuxAimPos"] = nil
	d[item.own_key.."AuxShouldShoot"] = false
	d[item.own_key.."cursed_queue"] = nil
	d[item.own_key.."kidney_cooldown"] = nil
	d[item.own_key.."kidney_block_frames"] = nil
	d[item.own_key.."kidney_burst_remaining"] = nil
	d[item.own_key.."kidney_burst_tick"] = nil
	d[item.own_key.."kidney_release"] = nil
	d[item.own_key.."kidney_active"] = nil
	Air.seal_kidney_attack(d)
	if Craft_Ludovico_holder and Craft_Ludovico_holder.release then
		Craft_Ludovico_holder.release(ent)
	end
	Air.clear_owned_laser(d, "Tech2")
	Air.clear_engine_knives(ent)
	local list = d[item.own_key.."Brimstones"]
	if type(list) == "table" then
		for _, entry in pairs(list) do
			local q = (type(entry) == "table" and entry.ent) or entry
			if auxi.check_all_exists(q) and q.SetTimeout then
				q:SetTimeout(1)
			end
		end
		d[item.own_key.."Brimstones"] = {}
	end
	d[item.own_key.."FaceU"] = face
	d[item.own_key.."RotDir"] = face
	d[item.own_key.."AimU"] = face
	d[item.own_key.."AimSm"] = face
	d[item.own_key.."FireAimSm"] = face
	if SoundEffect.SOUND_THUMBS_DOWN then
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBS_DOWN, 0.85, 0.85, false, 0, 2)
	end
end

local function air_tick_crash(ent, s, d, opts)
	local crash = d[item.own_key.."Crash"]
	if type(crash) ~= "table" then return "none" end
	local room = Game():GetRoom()
	crash.t = (tonumber(crash.t) or 0) + 1
	crash.phase_t = (tonumber(crash.phase_t) or 0) + 1
	local face = crash.face or Vector(0, 1)
	local spin = crash.spin or 1
	local yaw0 = Air.AIR_AIM_VIS.yaw_art_offset or -90
	local function paint_sprite(extra_deg)
		if not s then return end
		s.PlaybackSpeed = 0
		if s.SetFrame then
			s:SetFrame(Air.AIR_AIM_VIS.anim, Air.AIR_AIM_VIS.out_frame or 2)
		end
		s.Rotation = face:GetAngleDegrees() + yaw0 + (extra_deg or 0)
		s.FlipX = false
		s.FlipY = false
	end

	local function set_phase(name)
		crash.phase = name
		crash.phase_t = 0
	end

	-- ---- fail：失控预备 ----
	if crash.phase == "fail" then
		local fail_n = math.max(4, math.floor(tonumber(crash_fx_get("fail_frames")) or 7))
		local u = math.min(1, crash.phase_t / fail_n)
		local z_target = tonumber(crash_fx_get("fail_z_vel_target")) or 1.2
		crash.z_vel = z_target * u
		crash.z = (tonumber(crash.z) or crash.start_z or Air.AIR_AIM_VIS.base_offset) + crash.z_vel * 0.35
		local retain = 0.8 + 0.2 * (1 - u)
		local drift = crash.drift_vel or Vector(0, 0)
		local yaw = face:Rotated(spin * u * 8)
		local desired = drift * retain + yaw:Resized(drift:Length() * 0.05 * u)
		ent.Velocity = (ent.Velocity or Vector.Zero) * 0.85 + desired * 0.15
		local shake = math.sin(crash.t * (1.2 + u * 2.2)) * (0.8 + u * 1.5)
		d[item.own_key.."OffsetZ"] = math.min(0, crash.z)
		d[item.own_key.."PassAlt"] = 0
		ent.PositionOffset = Vector(shake, d[item.own_key.."OffsetZ"])
		local pulse = (crash.t % math.max(2, math.floor(5 - u * 3)) < 2) and (0.2 + u * 0.25) or 0.08
		ent:SetColor(Color(1, 0.25, 0.25, 1, pulse, 0, 0), 2, 60, false, false)
		crash.roll_angle = (tonumber(crash.roll_angle) or 0) + crash.roll_speed * 0.35
		paint_sprite(crash.roll_angle)
		d[item.own_key.."FaceU"] = face
		d[item.own_key.."RotDir"] = face
		if crash.phase_t == 1 then
			air_crash_spawn_smoke(ent, d, crash, "fail")
			air_crash_spawn_sparks(ent, d, crash, 3)
		end
		if crash.phase_t >= fail_n then
			set_phase("fall")
		end
		return "busy"

	-- ---- fall：惯性螺旋下坠 ----
	elseif crash.phase == "fall" then
		local grav = tonumber(crash.gravity) or tonumber(crash_fx_get("gravity")) or 0.38
		local vmax = tonumber(crash.max_fall_speed) or tonumber(crash_fx_get("max_fall_speed")) or 7.5
		crash.z_vel = math.min(vmax, (tonumber(crash.z_vel) or 0) + grav)
		crash.z = math.min(0, (tonumber(crash.z) or Air.AIR_AIM_VIS.base_offset) + crash.z_vel)
		local retain = tonumber(crash_fx_get("drift_retain")) or 0.985
		local slip_max = tonumber(crash_fx_get("side_slip_max")) or 1.8
		local tangent = Vector(-face.Y, face.X) * spin
		local drift = crash.drift_vel or Vector(0, 0)
		drift = drift * retain
		crash.drift_vel = drift
		local desired = drift + tangent * math.min(slip_max, crash.phase_t * 0.07)
		desired = desired + air_crash_safe_steer(ent, crash, room)
		ent.Velocity = (ent.Velocity or Vector.Zero) * 0.78 + desired * 0.22
		local near_g = math.min(1, math.abs(crash.z) < 12 and (1 - math.abs(crash.z) / 12) or 0)
		local shake = math.sin(crash.t * 1.7) * math.min(3, 0.8 + near_g * 2.2)
		d[item.own_key.."OffsetZ"] = math.min(0, crash.z)
		d[item.own_key.."PassAlt"] = 0
		ent.PositionOffset = Vector(shake, d[item.own_key.."OffsetZ"])
		crash.roll_speed = math.min(18, math.abs(tonumber(crash.roll_speed) or 4) + 0.35)
		if spin < 0 then crash.roll_speed = -math.abs(crash.roll_speed)
		else crash.roll_speed = math.abs(crash.roll_speed) end
		crash.roll_angle = (tonumber(crash.roll_angle) or 0) + crash.roll_speed
		-- 落地前压机头朝速度
		local look = face
		if near_g > 0.2 and ent.Velocity and ent.Velocity:Length() > 0.4 then
			look = face * (1 - near_g * 0.65) + ent.Velocity:Normalized() * (near_g * 0.65)
			if look:Length() > 0.01 then
				look = look:Normalized()
				crash.face = look
				face = look
			end
		end
		local pulse = (crash.t % 3 < 2) and 0.35 or 0.12
		ent:SetColor(Color(1, 0.22, 0.22, 1, pulse, 0, 0), 2, 60, false, false)
		paint_sprite(crash.roll_angle)
		d[item.own_key.."FaceU"] = face
		d[item.own_key.."RotDir"] = face
		crash.smoke_cd = (tonumber(crash.smoke_cd) or 0) - 1
		if crash.smoke_cd <= 0 then
			air_crash_spawn_smoke(ent, d, crash, "fall")
			crash.smoke_cd = math.max(3, math.floor(tonumber(crash_fx_get("fall_smoke_interval")) or 5))
		end
		if crash.z >= -0.5 then
			crash.z = 0
			crash.impact_pos = Vector(ent.Position.X, ent.Position.Y)
			crash.impact_speed = (ent.Velocity and ent.Velocity:Length()) or 0
			-- 翻滚初速：接地平面速度，勿强行 face*3.4
			local rv = Vector((ent.Velocity and ent.Velocity.X) or 0, (ent.Velocity and ent.Velocity.Y) or 0)
			if rv:Length() < 0.35 then
				rv = Vector(face.X, face.Y):Resized(1.2)
			elseif rv:Length() > 5.5 then
				rv = rv:Resized(5.5)
			end
			crash.roll_vel = rv
			d[item.own_key.."OffsetZ"] = 0
			ent.PositionOffset = Vector(0, 0)
			set_phase("impact")
		end
		return "busy"

	-- ---- impact：接地冲击 ----
	elseif crash.phase == "impact" then
		local impact_n = math.max(4, math.floor(tonumber(crash_fx_get("impact_frames")) or 6))
		ent.Velocity = (crash.roll_vel or Vector.Zero) * 0.55
		d[item.own_key.."OffsetZ"] = 0
		-- 2px 回弹（避免改 Sprite.Scale）
		local bounce = 0
		if crash.phase_t == 1 then
			bounce = 2
		elseif crash.phase_t <= 4 then
			bounce = 2 * (1 - (crash.phase_t - 1) / 3)
		end
		ent.PositionOffset = Vector(0, -bounce)
		if crash.phase_t == 1 and not crash.impact_done then
			crash.impact_done = true
			air_crash_spawn_impact_dust(ent, d, crash)
			air_crash_spawn_sparks(ent, d, crash, 4)
			local shake = math.floor(tonumber(crash_fx_get("screen_shake")) or 4)
			if shake > 0 and Game().ShakeScreen then
				Game():ShakeScreen(shake)
			end
			if SoundEffect.SOUND_ROCK_CRUMBLE then
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_ROCK_CRUMBLE, 0.8, 0.95, false, 0, 2)
			end
			if SoundEffect.SOUND_DEATH_BURST_SMALL then
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_DEATH_BURST_SMALL, 0.45, 0.85, false, 0, 1)
			end
		end
		ent:SetColor(Color(1, 0.28, 0.28, 1, 0.25, 0, 0), 2, 60, false, false)
		paint_sprite(crash.roll_angle)
		air_crash_clamp_tumble(ent, room)
		if crash.phase_t >= impact_n then
			set_phase("tumble")
		end
		return "busy"

	-- ---- tumble：擦地翻滚 ----
	elseif crash.phase == "tumble" then
		local fric = tonumber(crash_fx_get("tumble_friction")) or 0.90
		local max_t = math.floor(tonumber(crash_fx_get("tumble_max_frames")) or 24)
		local roll = crash.roll_vel or Vector(face.X, face.Y)
		roll = roll * fric
		crash.roll_vel = roll
		ent.Velocity = roll
		crash.roll_speed = (tonumber(crash.roll_speed) or 12) * 0.9
		crash.roll_angle = (tonumber(crash.roll_angle) or 0) + crash.roll_speed
		local fade = math.max(0, 1 - crash.phase_t / max_t)
		ent.PositionOffset = Vector(math.sin(crash.phase_t * 2.2) * (2.2 * fade), 0)
		d[item.own_key.."OffsetZ"] = 0
		ent:SetColor(Color(1, 0.3, 0.3, 1, 0.16 * fade, 0, 0), 2, 60, false, false)
		paint_sprite(crash.roll_angle)
		air_crash_clamp_tumble(ent, room)
		crash.smoke_cd = (tonumber(crash.smoke_cd) or 0) - 1
		if crash.smoke_cd <= 0 and roll:Length() > 0.4 then
			local back = roll:Length() > 0.01 and roll:Normalized() * -6 or Vector(0, 6)
			local old = ent.Position
			ent.Position = old + back
			air_crash_spawn_smoke(ent, d, crash, "fall")
			ent.Position = old
			crash.smoke_cd = 3 + (crash.phase_t % 2)
		end
		local stop = roll:Length() < 0.25 or crash.phase_t >= max_t
		if stop then
			ent.Velocity = Vector(0, 0)
			ent.PositionOffset = Vector(0, 0)
			-- 吸附最终残骸角，避免跳到固定 70*spin
			local final = crash.roll_angle or (70 * spin)
			-- 归一到相近的侧倒角
			local target = 55 * spin
			if math.abs(final - target) > 90 then
				target = final
			else
				final = final * 0.35 + target * 0.65
			end
			crash.final_rotation = final
			crash.roll_angle = final
			if opts and opts.can_revive then
				set_phase("revive")
			else
				set_phase("dead")
				local rng = air_crash_rng(ent, crash, 101)
				local mn = math.floor(tonumber(crash_fx_get("dead_smoke_min")) or 18)
				local mx = math.floor(tonumber(crash_fx_get("dead_smoke_max")) or 30)
				if mx < mn then mx = mn end
				crash.smoke_cd = mn + rng:RandomInt(math.max(1, mx - mn + 1))
			end
		end
		return "busy"

	-- ---- revive：ease-out 抬升 ----
	elseif crash.phase == "revive" then
		local rev_n = math.max(8, math.floor(tonumber(crash_fx_get("revive_frames")) or 14))
		crash.revive_t = (tonumber(crash.revive_t) or 0) + 1
		if crash.revive_t == 1 and opts and type(opts.on_revive_start) == "function" then
			opts.on_revive_start()
			air_crash_cleanup_fx(d)
		end
		local t = math.min(1, crash.revive_t / rev_n)
		local u = 1 - (1 - t) ^ 3
		d[item.own_key.."OffsetZ"] = Air.AIR_AIM_VIS.base_offset * u
		d[item.own_key.."OffsetZVel"] = nil
		ent.PositionOffset = Vector(0, d[item.own_key.."OffsetZ"])
		ent.Velocity = Vector(0, 0)
		-- 灰红 → 淡绿
		local r = 0.55 + 0.45 * (1 - u)
		local gcol = 0.35 + 0.65 * u
		ent:SetColor(Color(r, gcol, 0.4 + 0.2 * u, 1, 0, 0.25 * (1 - u), 0), 3, 60, false, false)
		paint_sprite((crash.final_rotation or 0) * (1 - u))
		d[item.own_key.."FaceU"] = face
		d[item.own_key.."RotDir"] = face
		d[item.own_key.."AimU"] = face
		d[item.own_key.."AimSm"] = face
		d[item.own_key.."FireAimSm"] = face
		if crash.revive_t >= 4 and crash.revive_t <= 8 and (crash.revive_t % 2 == 0) then
			air_crash_spawn_smoke(ent, d, crash, "revive")
		end
		if crash.revive_t >= rev_n then
			d[item.own_key.."Crash"] = nil
			d[item.own_key.."ForceCrash"] = nil
			d[item.own_key.."TrailSuppress"] = nil
			ent:SetColor(Color(1, 1, 1, 1, 0, 0, 0), 1, 50, false, false)
			air_crash_cleanup_fx(d)
			if opts and type(opts.on_revive_done) == "function" then
				opts.on_revive_done()
			end
			return "revived"
		end
		return "busy"

	-- ---- dead：残骸间歇冒烟 ----
	else
		ent.Velocity = Vector(0, 0)
		d[item.own_key.."OffsetZ"] = 0
		ent.PositionOffset = Vector(0, 0)
		ent:SetColor(Color(1, 0.32, 0.32, 1, 0.12, 0, 0), 2, 50, false, false)
		local ang = crash.final_rotation or crash.roll_angle or (70 * spin)
		paint_sprite(ang)
		crash.smoke_cd = (tonumber(crash.smoke_cd) or 0) - 1
		if crash.smoke_cd <= 0 then
			air_crash_spawn_smoke(ent, d, crash, "dead")
			local rng = air_crash_rng(ent, crash, 121)
			local mn = math.floor(tonumber(crash_fx_get("dead_smoke_min")) or 18)
			local mx = math.floor(tonumber(crash_fx_get("dead_smoke_max")) or 30)
			if mx < mn then mx = mn end
			crash.smoke_cd = mn + rng:RandomInt(math.max(1, mx - mn + 1))
		end
		return "dead"
	end
end

function item.debug_force_crash(opts)
	opts = opts or {}
	for _, fam in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, item.familiar, -1, false, false)) do
		local d = fam:GetData()
		air_crash_cleanup_fx(d)
		d[item.own_key.."Crash"] = nil
		d[item.own_key.."ForceCrash"] = true
		air_begin_crash(fam, d)
		local crash = d[item.own_key.."Crash"]
		if crash and opts.revive then
			crash.will_revive = true
		end
	end
end

function item.debug_clear_crash_fx()
	for _, fam in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, item.familiar, -1, false, false)) do
		local d = fam:GetData()
		air_crash_cleanup_fx(d)
		d[item.own_key.."Crash"] = nil
		d[item.own_key.."ForceCrash"] = nil
		d[item.own_key.."TrailSuppress"] = nil
		d[item.own_key.."WasBroken"] = nil
		fam:SetColor(Color(1, 1, 1, 1, 0, 0, 0), 1, 50, false, false)
	end
end



Air.begin_crash = air_begin_crash
Air.tick_crash = air_tick_crash
Air.crash_cleanup_fx = air_crash_cleanup_fx

end

return M
