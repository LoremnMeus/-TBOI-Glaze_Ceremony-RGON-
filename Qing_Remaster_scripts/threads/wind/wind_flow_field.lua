-- Storm V6.6 visual flow field (advection only). Does not affect physics drag.
-- Eye/cyclone: far-field keeps minimum inward pull (never pure directional).
-- Impact remains independent radial outflow.

local physics = require("Qing_Remaster_scripts.threads.wind.wind_physics")

local M = {}

local function clamp(x, lo, hi)
	return math.max(lo, math.min(hi, x))
end

local function smoothstep(t)
	t = clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function safe_norm(v, fallback)
	if not v or v:LengthSquared() < 1e-8 then
		return fallback or Vector(0, 1)
	end
	return v:Normalized()
end

local function noise2(pos, time, seed)
	seed = seed or 0
	local t = (time or 0) * 0.035
	local x = pos.X * 0.008 + seed * 0.11
	local y = pos.Y * 0.007 - seed * 0.09
	local nx = math.sin(x + t) * math.cos(y * 0.9 + t * 0.6)
	local ny = math.cos(x * 0.85 - t * 0.8) * math.sin(y + t * 0.55)
	return Vector(nx, ny)
end

local function intensity_safe(opts)
	return clamp(opts and opts.intensity or 0.7, 0, 1)
end

function M.airflow_speed_mul(time, seed)
	time = time or Game():GetFrameCount()
	seed = seed or 0
	return 1 + 0.05 * math.sin(time * 0.018 + seed * 0.13)
end

function M.gust_speed_mul(time)
	time = time or Game():GetFrameCount()
	local slow = 0.5 + 0.5 * math.sin(time * 0.07)
	local beat = 0.5 + 0.5 * math.sin(time * 0.025 + 1.7)
	return 0.92 + 0.28 * slow + 0.18 * beat
end

function M.sample_directional_flow(pos, time, opts)
	opts = opts or {}
	local blow = opts.blow
	if not blow then
		blow = physics.wind_blow_dir(opts.ang or 0)
	end
	blow = safe_norm(blow, Vector(0, 1))
	local source = opts.visual_source
	local bend = tonumber(opts.visual_bend) or 0
	if source and bend > 0 then
		local away = pos - source
		away = safe_norm(away, blow)
		blow = safe_norm(blow * (1 - bend) + away * bend, blow)
	end
	local side = Vector(-blow.Y, blow.X)
	local speed = opts.speed or 1
	local gust = opts.gust_mul
	if gust == nil then
		gust = 1
	end
	local lambda = opts.noise
	if lambda == nil then
		lambda = 0.07
	end
	local n = noise2(pos, time, opts.seed or 0)
	local v = blow * (speed * gust) + side * (n.X * lambda * speed)
	if v:LengthSquared() < 1e-8 then
		return blow * (speed * gust)
	end
	return v
end

--- Cyclone / eye.
-- Far field: minimum radial inflow (never w=0 → pure ambient).
-- Mid: inflow + tangential. Rim: tangential dominant. Core: swirl (climb elsewhere).
function M.sample_cyclone_flow(pos, center, time, opts)
	opts = opts or {}
	center = center or Vector(0, 0)
	local inten = intensity_safe(opts)
	local speed = opts.speed or 10
	local ambient = M.sample_directional_flow(pos, time, {
		ang = opts.ang,
		blow = opts.blow,
		speed = speed * 0.35,
		noise = 0.04,
		seed = opts.seed,
		gust_mul = opts.gust_mul or 1,
	})

	local d = pos - center
	local r = d:Length()
	if r < 2.5 then
		r = 2.5
		d = Vector(2.5, 0)
	end
	local R_hat = d * (1 / r)
	local T_hat = Vector(-R_hat.Y, R_hat.X)
	local R_core = math.max(20, opts.core_radius or 45)
	local R_far = math.max(R_core * 2.8, opts.far_radius or 220)
	local u = r / R_core

	-- Influence weight: still rises near core, but floor keeps cyclone active far away.
	local w
	if r >= R_far then
		w = 0.42
	elseif r <= R_core * 0.95 then
		w = 1
	else
		local t = (r - R_core * 0.95) / math.max(1, R_far - R_core * 0.95)
		w = 1 - 0.58 * smoothstep(t)
	end

	-- Radial inward: slow falloff so periphery still pulls in.
	-- Peak near ~1.2 R_core; floor ~0.28*speed even at large u.
	local vr_shape = math.exp(-((u - 1.15) ^ 2) / 1.35)
	local vr = speed * (0.40 + 0.35 * inten) * (0.32 + 0.68 * vr_shape)
	vr = math.max(speed * (0.22 + 0.08 * inten), vr)

	-- Tangential: peaks at rim, stays meaningful mid-ring.
	local vt_shape = math.exp(-((u - 1.05) ^ 2) / 0.85)
	local vt = speed * (0.55 + 0.4 * inten) * (0.25 + 0.75 * vt_shape)

	if u < 0.55 then
		vr = vr * 0.2
		vt = vt * (0.75 + 0.25 * u)
	end

	local n = noise2(pos, time, (opts.seed or 1) + 5)
	local cyclone = T_hat * (vt * (1 + n.X * 0.08)) - R_hat * (vr * (1 + n.Y * 0.06))

	-- Ambient never dominates eye mode.
	local ambient_w = (1 - w) * 0.22
	return ambient * ambient_w + cyclone * (1 - ambient_w)
end

function M.sample_eye_flow(pos, center, time, opts)
	return M.sample_cyclone_flow(pos, center, time, opts)
end

function M.sample_impact_flow(pos, center, time, opts)
	opts = opts or {}
	center = center or Vector(0, 0)
	local d = pos - center
	local r = d:Length()
	if r < 2.5 then
		local ang = ((opts.seed or 0) % 360) + (time or 0) * 0.5
		d = Vector(math.cos(math.rad(ang)), math.sin(math.rad(ang))) * 2.5
		r = 2.5
	end
	local out = d * (1 / r)
	local tang = Vector(-out.Y, out.X)
	local age = opts.impact_age or 0
	local radial_peak = opts.speed or 14
	local radial
	if age < 6 then
		radial = radial_peak * (0.35 + age / 6 * 0.65)
	elseif age < 14 then
		radial = radial_peak
	elseif age < 30 then
		radial = radial_peak * (1 - (age - 14) / 16 * 0.55)
	elseif age < 48 then
		radial = radial_peak * 0.45 * (1 - (age - 30) / 18)
	else
		radial = radial_peak * 0.08
	end
	local tang_amt = radial_peak * 0.18 * math.max(0, 1 - age / 22)
	local n = noise2(pos, time, opts.seed or 2)
	return out * radial + tang * (tang_amt * (0.7 + 0.3 * n.X)) + out * (n.Y * 0.4)
end

function M.sample_flow(pos, sess, time, opts)
	opts = opts or {}
	local phase = opts.phase or "directional"
	local intensity = clamp(opts.intensity or 0.5, 0, 1)
	local base_speed = opts.base_speed or (8 + intensity * 7)

	if phase == "impact" then
		local center = opts.impact_center or opts.center or (sess and sess.pos) or Game():GetRoom():GetCenterPos()
		return M.sample_impact_flow(pos, center, time, {
			impact_age = opts.impact_age or 0,
			speed = base_speed * 1.15,
			seed = opts.seed,
		})
	end

	if phase == "eye" then
		local center = opts.center or (sess and sess.pos) or Game():GetRoom():GetCenterPos()
		return M.sample_cyclone_flow(pos, center, time, {
			ang = sess and sess.ang or 0,
			blow = opts.blow,
			speed = base_speed,
			intensity = intensity,
			core_radius = opts.core_radius or opts.radius or 48,
			far_radius = opts.far_radius or ((opts.radius or 48) * 4.2),
			seed = opts.seed,
			gust_mul = opts.gust_mul,
		})
	end

	local eps = 0.05 + intensity * 0.04
	return M.sample_directional_flow(pos, time, {
		ang = sess and sess.ang or 0,
		blow = opts.blow,
		speed = base_speed,
		noise = opts.noise or eps,
		seed = opts.seed,
		gust_mul = opts.gust_mul,
		visual_source = opts.visual_source,
		visual_bend = opts.visual_bend,
	})
end

return M
