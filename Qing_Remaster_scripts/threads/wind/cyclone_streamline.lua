-- Storm V7.4 — deterministic cyclone streamlines with continuous handoff.
-- Stages: OUTSIDE → INFLOW → SPIRAL → ASCENDING → TOP_EXIT → DONE
-- Birth frame pos == birth_pos. Ascending inherits inbound r/θ/h (no radius jump).
-- Ascending advances with angle-limited visual samples (no long chords).

local M = {}

local STAGE = {
	OUTSIDE = "outside",
	INFLOW = "inflow",
	SPIRAL = "spiral",
	ASCENDING = "ascending",
	TOP_EXIT = "top_exit",
	DONE = "done",
}
M.STAGE = STAGE

local TWO_PI = math.pi * 2
local MAX_VIS_DTHETA = math.rad(12) -- ~12° visual substep
local MAX_VIS_STEPS = 6

local function clamp01(x)
	return math.max(0, math.min(1, x or 0))
end

local function atan2(y, x)
	return math.atan(y, x)
end

local function vcopy(p)
	return Vector(p.X, p.Y)
end

local function funnel_radius(h, profile)
	h = clamp01(h)
	local s = h * h * (3 - 2 * h)
	local rb = profile.r_bot or 22
	local rt = profile.r_top or 58
	return rb + (rt - rb) * s
end
M.funnel_radius = funnel_radius

function M.default_profile(opts)
	opts = opts or {}
	local scale = opts.visual_scale or 0.85
	local growth = math.max(0.05, opts.growth or 1)
	local s = scale * (0.55 + 0.45 * growth)
	return {
		r_bot = (opts.r_bot or 19) * s,
		r_top = (opts.r_top or 70) * s,
		column_h = (opts.column_h or 178) * s,
		capture = opts.capture,
		turn_angle = opts.turn_angle or (math.pi * 0.85),
		-- ~11° per 8 world units — safe for short arc stamps.
		ascend_omega = opts.ascend_omega or 0.024,
		depth_squash = opts.depth_squash or 0.18,
		-- Height only appears near the column (keeps birth on the edge plane).
		height_u0 = 0.55,
		height_max = 0.14,
	}
end

local function ensure_capture(profile)
	if not profile.capture then
		profile.capture = (profile.r_bot + profile.r_top) * 0.42
	end
	return profile.capture
end

--- Pure planar ring (no height / depth) — matches off-screen edge births.
local function planar_world(center, r, theta)
	return Vector(center.X + r * math.cos(theta), center.Y + r * math.sin(theta))
end

--- Funnel projection with height + mild depth squash (column volume space).
function M.sample_world(center, r, theta, h, profile)
	profile = profile or M.default_profile()
	h = clamp01(h or 0)
	local depth = r * math.sin(theta) * (profile.depth_squash or 0.18)
	local x = center.X + r * math.cos(theta)
	local y = center.Y - h * (profile.column_h or 150) + depth
	return Vector(x, y)
end

--- Height weight along inbound progress: 0 at birth → full near capture.
local function inbound_height(u, profile)
	local u0 = profile.height_u0 or 0.55
	local hmax = profile.height_max or 0.14
	if u <= u0 then return 0 end
	local t = (u - u0) / math.max(1e-6, 1 - u0)
	t = t * t * (3 - 2 * t)
	return hmax * t
end

--- Blend planar → funnel projection so u=0 stays on birth plane.
local function inbound_world(center, r, theta, u, profile)
	local planar = planar_world(center, r, theta)
	local h = inbound_height(u, profile)
	if h <= 1e-6 then
		return planar, h
	end
	local lifted = M.sample_world(center, r, theta, h, profile)
	-- Smooth in lift without yanking the first frames.
	local w = clamp01(h / math.max(1e-6, profile.height_max or 0.14))
	return Vector(
		planar.X * (1 - w) + lifted.X * w,
		planar.Y * (1 - w) + lifted.Y * w
	), h
end

local function inbound_speed_du(r0, rc, A, u)
	u = clamp01(u)
	local dr = -(r0 - rc)
	local dtheta = A * (0.15 + 1.7 * u)
	local r = r0 - (r0 - rc) * u
	local rt = r * dtheta
	return math.sqrt(dr * dr + rt * rt)
end

local function inbound_pose(track, u)
	u = clamp01(u)
	local r0, rc, A = track.r0, track.rc, track.A
	local r = r0 - (r0 - rc) * u
	local th = track.theta0 + A * (0.15 * u + 0.85 * u * u)
	local profile = track.profile
	local pos, h
	if u <= 1e-6 and track.birth_pos then
		pos = vcopy(track.birth_pos)
		h = 0
	else
		pos, h = inbound_world(track.center, r, th, u, profile)
	end
	local du = 0.002
	local u2 = math.min(1, u + du)
	local r2 = r0 - (r0 - rc) * u2
	local th2 = track.theta0 + A * (0.15 * u2 + 0.85 * u2 * u2)
	local pos2 = inbound_world(track.center, r2, th2, u2, profile)
	local tang = pos2 - pos
	if tang:LengthSquared() < 1e-8 then
		tang = Vector(-math.sin(th), math.cos(th))
	else
		tang = tang:Normalized()
	end
	-- Late inbound: ease tangent toward the column helix so ASCENDING does not kink.
	if u > 0.72 then
		local sign = (A >= 0) and 1 or -1
		local helix = Vector(0, -1) * 0.72 + Vector(-math.sin(th) * sign, math.cos(th) * sign * 0.2) * 0.55
		if helix:LengthSquared() > 1e-8 then
			helix = helix:Normalized()
			local w = clamp01((u - 0.72) / 0.28)
			w = w * w * (3 - 2 * w)
			local mixed = tang * (1 - w) + helix * w
			if mixed:LengthSquared() > 1e-8 then
				tang = mixed:Normalized()
			end
		end
	end
	return pos, tang, r, th, h
end

--- Optional mid control: pull spiral through a visible sector waypoint (not a search).
local function apply_sector_mid(track, opts)
	opts = opts or {}
	if not opts.mid_r_frac then return end
	-- Bias theta0 slightly so different edges sweep distinct visual corridors.
	local bias = opts.theta_bias or 0
	track.theta0 = track.theta0 + bias
	track.A = track.A * (opts.turn_mul or 1)
end

--- Begin from an off-screen birth. Frame 0 pos == birth_pos.
function M.begin(birth_pos, opts)
	opts = opts or {}
	local center = opts.center or Game():GetRoom():GetCenterPos()
	local profile = opts.profile or M.default_profile(opts)
	local rc = ensure_capture(profile)
	local birth = Vector(birth_pos.X, birth_pos.Y)
	local dx = birth.X - center.X
	local dy = birth.Y - center.Y
	local r0 = math.sqrt(dx * dx + dy * dy)
	if r0 < 1e-3 then
		r0 = rc + 40
		dx, dy = r0, 0
		birth = planar_world(center, r0, 0)
	end
	local theta0 = atan2(dy, dx)

	-- Three-node shape: birth → mid ring → capture (analytical spiral still owns motion).
	local mid_frac = opts.mid_r_frac or 0.42
	local mid_r = rc + (r0 - rc) * mid_frac

	local stage = STAGE.INFLOW
	local u = 0
	if r0 <= rc + 2 then
		stage = STAGE.ASCENDING
		u = 1
	end

	local A = (opts.turn_angle or profile.turn_angle or (math.pi * 0.85))
	local sign = opts.turn_sign or 1
	if sign < 0 then A = -math.abs(A) else A = math.abs(A) end

	local speed = opts.speed or 9
	if opts.speed_jitter then
		speed = speed * (1 + opts.speed_jitter)
	end

	local track = {
		center = Vector(center.X, center.Y),
		profile = profile,
		birth_pos = birth,
		p0 = birth,
		p1 = planar_world(center, mid_r, theta0 + (opts.mid_theta_bias or 0)),
		p2 = planar_world(center, rc, theta0 + A * 0.55),
		r0 = r0,
		theta0 = theta0,
		rc = rc,
		A = A,
		u = u,
		h = 0,
		theta = theta0,
		r = r0,
		speed = speed,
		stage = stage,
		layer = opts.layer or "airflow",
		age = 0,
		_ascend_s = 0,
		visual_samples = nil,
	}
	apply_sector_mid(track, opts)

	if stage == STAGE.ASCENDING then
		local h0 = opts.h0 or 0.08
		track.h = h0
		track.r = funnel_radius(h0, profile)
		track.theta = theta0
		track.pos = M.sample_world(center, track.r, theta0, h0, profile)
		track.birth_pos = vcopy(track.pos)
		local sgn = (A >= 0) and 1 or -1
		track.tangent = Vector(-math.sin(theta0) * sgn, -0.9):Normalized()
		track._ascend_r0 = track.r
		track._ascend_h0 = h0
	else
		local pos, tang, r, th, h = inbound_pose(track, 0)
		-- Hard guarantee: birth frame matches caller spawn.
		track.pos = birth
		track.tangent = tang
		track.r = r
		track.theta = th
		track.h = h
	end
	return track
end

function M.begin_ascending(center, opts)
	opts = opts or {}
	local profile = opts.profile or M.default_profile(opts)
	ensure_capture(profile)
	local ang = (opts.ang01 or 0) * TWO_PI
	local h0 = opts.h0 or 0.12
	local rr = funnel_radius(h0, profile) * (0.85 + (opts.r_mul or 0.15))
	local birth = M.sample_world(center, rr, ang, h0, profile)
	local track = M.begin(birth, {
		center = center,
		profile = profile,
		speed = opts.speed or 7,
		turn_sign = opts.turn_sign or 1,
		turn_angle = opts.turn_angle,
		layer = opts.layer or "motes",
		h0 = h0,
	})
	-- begin() may have treated birth as inbound; force ascending shell state.
	track.stage = STAGE.ASCENDING
	track.u = 1
	track.h = h0
	track.theta = ang
	track.r = rr
	track.pos = birth
	track.birth_pos = vcopy(birth)
	track._ascend_r0 = rr
	track._ascend_h0 = h0
	track._ascend_s = 0
	local sign = (track.A >= 0) and 1 or -1
	track.tangent = Vector(-math.sin(ang) * sign, -0.9):Normalized()
	return track
end

local function enter_ascending(track)
	-- Inherit exact handoff pose — do not snap r to funnel_radius yet.
	track.stage = STAGE.ASCENDING
	track._ascend_r0 = track.r
	track._ascend_h0 = track.h
	track._ascend_theta0 = track.theta
	track._ascend_pos0 = vcopy(track.pos)
	track._ascend_tang0 = track.tangent and vcopy(track.tangent) or Vector(0, -1)
	track._ascend_s = 0
	-- Solve a funnel height whose radius is close to current r (for later blend target).
	local best_h, best_err = track.h, 1e9
	for i = 0, 20 do
		local hi = i / 20
		local err = math.abs(funnel_radius(hi, track.profile) - track.r)
		if err < best_err then
			best_err = err
			best_h = hi
		end
	end
	track._ascend_h_target0 = best_h
end

local function advance_inbound(track, ds)
	local r0, rc, A = track.r0, track.rc, track.A
	local u0 = track.u or 0
	local u = u0
	local remain = ds
	for _ = 1, 8 do
		if u >= 1 or remain <= 0 then break end
		local spd = inbound_speed_du(r0, rc, math.abs(A), u)
		if spd < 1e-4 then
			u = 1
			break
		end
		local du = remain / spd
		if u + du >= 1 then
			remain = remain - (1 - u) * spd
			u = 1
			break
		end
		u = u + du
		remain = 0
	end
	-- Curve samples along the inbound arc (SPIRAL / late INFLOW), angle-limited.
	local samples = {}
	local du_total = math.max(0, u - u0)
	local mid_u = (u0 + u) * 0.5
	local th_span = math.abs(A) * (0.15 + 1.7 * mid_u) * du_total
	local steps = math.max(1, math.ceil(th_span / MAX_VIS_DTHETA))
	steps = math.min(steps, MAX_VIS_STEPS)
	for i = 1, steps do
		local ui = u0 + du_total * (i / steps)
		local pos, tang, r, th, h = inbound_pose(track, ui)
		local st = (ui >= 0.35) and STAGE.SPIRAL or STAGE.INFLOW
		if ui >= 1 then st = STAGE.ASCENDING end
		samples[#samples + 1] = {
			pos = vcopy(pos),
			tang = vcopy(tang),
			stage = st,
		}
		if i == steps then
			track.pos = pos
			track.tangent = tang
			track.r = r
			track.theta = th
			track.h = h
		end
	end
	track.u = u
	if u >= 0.35 and track.stage == STAGE.INFLOW then
		track.stage = STAGE.SPIRAL
	end
	if u >= 1 then
		enter_ascending(track)
		-- Final sample already at capture pose; keep it as ASCENDING marker.
		if #samples > 0 then
			samples[#samples].stage = STAGE.ASCENDING
		end
	end
	track.visual_samples = samples
	return remain
end

local function advance_ascending_once(track, ds)
	local profile = track.profile
	local omega_full = profile.ascend_omega or 0.024
	local sign = (track.A >= 0) and 1 or -1
	local col_h = math.max(40, profile.column_h or 150)
	local s0 = track._ascend_s or 0
	-- Ease omega + climb for the first ~28 wu so inbound tangent can join the helix.
	local ease = clamp01(s0 / 28)
	ease = ease * ease * (3 - 2 * ease)
	local omega = omega_full * (0.25 + 0.75 * ease)
	local climb_mul = 0.45 + 0.55 * ease
	track._ascend_s = s0 + ds
	local dh = (ds / col_h) * climb_mul
	track.h = clamp01((track.h or track._ascend_h0 or 0) + dh)
	track.theta = (track.theta or 0) + sign * omega * ds
	-- Blend shell radius from handoff r → funnel_radius(h) over ~36 world units.
	local blend = clamp01((track._ascend_s or 0) / 36)
	blend = blend * blend * (3 - 2 * blend)
	local target_r = funnel_radius(track.h, profile)
	local r0 = track._ascend_r0 or target_r
	track.r = r0 * (1 - blend) + target_r * blend
	track.pos = M.sample_world(track.center, track.r, track.theta, track.h, profile)
	local up = Vector(0, -1)
	local circ = Vector(-math.sin(track.theta) * sign, math.cos(track.theta) * sign * 0.2)
	local helix = up * 0.72 + circ * 0.55
	if helix:LengthSquared() > 1e-8 then
		helix = helix:Normalized()
	end
	local hand = track._ascend_tang0
	if hand and hand:LengthSquared() > 1e-8 then
		hand = hand:Normalized()
		local tang = hand * (1 - ease) + helix * ease
		if tang:LengthSquared() > 1e-8 then
			track.tangent = tang:Normalized()
		else
			track.tangent = helix
		end
	else
		track.tangent = helix
	end
	if track.h >= 0.98 then
		track.stage = STAGE.TOP_EXIT
	end
end

local function advance_ascending(track, ds)
	local omega = (track.profile and track.profile.ascend_omega) or 0.024
	local dtheta = math.abs(omega * ds)
	local steps = math.max(1, math.ceil(dtheta / MAX_VIS_DTHETA))
	steps = math.min(steps, MAX_VIS_STEPS)
	local dsi = ds / steps
	local samples = {}
	for _ = 1, steps do
		if track.stage ~= STAGE.ASCENDING then
			break
		end
		advance_ascending_once(track, dsi)
		samples[#samples + 1] = {
			pos = vcopy(track.pos),
			tang = track.tangent and vcopy(track.tangent) or Vector(0, -1),
			stage = track.stage,
		}
	end
	track.visual_samples = samples
	return samples
end

local function advance_top_exit(track, ds)
	local tang = track.tangent or Vector(0, -1)
	if tang:LengthSquared() < 1e-8 then
		tang = Vector(0, -1)
	else
		tang = tang:Normalized()
	end
	local away = track.pos - track.center
	if away:LengthSquared() > 1e-4 then
		away = away:Normalized()
		tang = (tang * 0.55 + away * 0.45 + Vector(0, -0.35)):Normalized()
	end
	track.tangent = tang
	-- Subsample exit too if moving fast.
	local steps = math.min(MAX_VIS_STEPS, math.max(1, math.ceil(ds / 10)))
	local dsi = ds / steps
	local samples = {}
	for _ = 1, steps do
		track.pos = track.pos + tang * dsi
		track.r = (track.r or 40) + dsi * 0.35
		track.h = math.min(1.15, (track.h or 1) + dsi / math.max(40, track.profile.column_h or 150))
		samples[#samples + 1] = {
			pos = vcopy(track.pos),
			tang = vcopy(tang),
			stage = STAGE.TOP_EXIT,
		}
	end
	track.visual_samples = samples
end

--- returns pos, tangent, stage, visual_samples (array; may be nil for simple inbound)
function M.advance(track, ds)
	if not track or track.stage == STAGE.DONE then
		return track and track.pos, track and track.tangent, STAGE.DONE, nil
	end
	ds = math.max(0, ds or track.speed or 8)
	track.age = (track.age or 0) + 1
	track.visual_samples = nil

	if track.stage == STAGE.OUTSIDE or track.stage == STAGE.INFLOW or track.stage == STAGE.SPIRAL then
		advance_inbound(track, ds)
		-- visual_samples filled by advance_inbound (curve-aware).
	elseif track.stage == STAGE.ASCENDING then
		advance_ascending(track, ds)
	elseif track.stage == STAGE.TOP_EXIT then
		advance_top_exit(track, ds)
	end

	return track.pos, track.tangent, track.stage, track.visual_samples
end

function M.mark_done(track)
	if track then track.stage = STAGE.DONE end
end

--- Edge → sector params so top/bottom keep longer visible corridors.
function M.sector_opts_for_edge(edge)
	-- 0 top 1 bottom 2 left 3 right
	if edge == 0 then
		return {mid_r_frac = 0.55, turn_mul = 0.9, theta_bias = 0.08, mid_theta_bias = 0.12}
	elseif edge == 1 then
		return {mid_r_frac = 0.55, turn_mul = 0.9, theta_bias = -0.08, mid_theta_bias = -0.12}
	elseif edge == 2 then
		return {mid_r_frac = 0.40, turn_mul = 1.05, theta_bias = 0.05, mid_theta_bias = 0.2}
	end
	return {mid_r_frac = 0.40, turn_mul = 1.05, theta_bias = -0.05, mid_theta_bias = -0.2}
end

return M
