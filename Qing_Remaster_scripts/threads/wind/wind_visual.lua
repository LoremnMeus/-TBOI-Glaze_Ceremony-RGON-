-- Storm V7.7 visuals:
--   Update prepares column draw_stamps; Render only consumes
--   Per-logic-frame census cache + density ring buffer
--   Motion samples ≠ draw samples (≤4 stamps); column_visual hard absorb
-- Physics / Story untouched.

local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local env_config = require("Qing_Remaster_scripts.threads.wind.environment_config")
local physics = require("Qing_Remaster_scripts.threads.wind.wind_physics")
local flow = require("Qing_Remaster_scripts.threads.wind.wind_flow_field")
local emission = require("Qing_Remaster_scripts.threads.wind.wind_emission")
local life = require("Qing_Remaster_scripts.threads.wind.wind_particle_life")
local streamline = require("Qing_Remaster_scripts.threads.wind.cyclone_streamline")
local particle_frames = require("Qing_Remaster_scripts.threads.wind.wind_particles_frames")
local tornado = require("Qing_Remaster_scripts.threads.wind.tornado_visual")

local PROBE_PATH = "Qing_Remaster_scripts.threads.wind.wind_pipeline_probe"
local function probe()
	local mod = package.loaded[PROBE_PATH]
	if type(mod) == "table" and mod.is_listening and mod.is_listening() then
		return mod
	end
	return nil
end

local M = {
	particles = {},
	cover_alpha = 0,
	eye_radius_scale = 1,
	phase = "directional",
	force_white = false,
	pulse = nil,
	emit = nil, -- per-layer next emit frame
	particle_reset_count = 0,
	last_reset_reason = nil,
	intro_fade = 0,
	_v63 = nil,
	_v66 = nil,
	_mote = nil,
	impact = nil,
	tornado = tornado,
	_density_log = nil,
	metrics = nil,
	-- Layer isolation (debug / acceptance). Default: all on.
	layer_mask = {airflow = true, gust = true, motes = true, tornado = true},
	_edge_rr = 0,
}

local TIP_N, BODY_N, TAIL_N = 6, 6, 6
local TEX_W = 32
local HARD_MAX_AGE = 360 -- safety only; normal recycle is off-screen
local ENTRY_TIMEOUT = life.ENTRY_TIMEOUT

-- Emit intervals (Game frames @ 30Hz). Jitter applied per spawn.
-- cap_mul applies to *inbound* slots only; column particles use COLUMN_CAP.
local EMIT = {
	airflow = { interval = 2, jitter = 2, cap_mul = 1.45 },
	gust = { interval = 14, jitter = 8, cap_mul = 1.5 },
	motes = { interval = 9, jitter = 5, cap_mul = 1.35 },
}
-- Hard caps for *drawn* column visuals (do not block inbound emit).
local COLUMN_CAP = {
	airflow = 22,
	gust = 5,
	motes = 10,
}
local INBOUND_BLANK_ALARM = 45 -- ~1.5s @ 30Hz with zero inbound draw
local MAX_DRAW_STAMPS = 4 -- high-value arcs per column particle (motion samples stay denser)
local DENSITY_CAP = 300

-- Scratch / reuse (never share mutable arrays across particles).
local _scale_tmp = Vector(1, 1)
local _rot_tmp = Vector(1, 0)
local _chord_pick = {} -- index scratch for draw-sample selection

local function now_ns()
	if Isaac.GetNanoTime then
		return Isaac.GetNanoTime()
	end
	if Isaac.GetTime then
		return Isaac.GetTime() * 1000000
	end
	return 0
end

local function ns_to_ms(ns)
	return (tonumber(ns) or 0) / 1e6
end

local function layer_enabled(layer)
	local mask = M.layer_mask
	if not mask then return true end
	if layer == "tornado" then return mask.tornado ~= false end
	return mask[layer] ~= false
end

function M.set_layer_mask(opts)
	opts = opts or {}
	M.layer_mask = M.layer_mask or {airflow = true, gust = true, motes = true, tornado = true}
	for _, key in ipairs({"airflow", "gust", "motes", "tornado"}) do
		if opts[key] ~= nil then
			M.layer_mask[key] = opts[key] == true
		end
	end
	return M.layer_mask
end

function M.get_layer_mask()
	return M.layer_mask
end

--- Solo layer test: only one visual class + optional tornado.
function M.set_solo_layer(layer)
	local mask = {airflow = false, gust = false, motes = false, tornado = false}
	if layer == "all" or layer == nil then
		mask = {airflow = true, gust = true, motes = true, tornado = true}
	elseif layer == "tornado" then
		mask.tornado = true
	elseif layer == "airflow" or layer == "gust" or layer == "motes" then
		mask[layer] = true
	elseif layer == "combo" then
		mask = {airflow = true, gust = true, motes = true, tornado = true}
	end
	M.layer_mask = mask
	return mask
end

local function restore_all_layers()
	M.layer_mask = {airflow = true, gust = true, motes = true, tornado = true}
end

local STAGE = {
	GROWING = "growing",
	FLOWING = "flowing",
	DISSOLVING = "dissolving", -- story/shutdown only
}

local function clamp01(x)
	return math.max(0, math.min(1, x or 0))
end

local function ensure_v63()
	if M._v63 then return M._v63 end
	local s = Sprite()
	s:Load("gfx/boss/Zennith/storm/storm_v63.anm2", true)
	M._v63 = s
	return s
end

local function ensure_v66()
	if M._v66 then return M._v66 end
	local s = Sprite()
	s:Load("gfx/boss/Zennith/storm/storm_v66.anm2", true)
	M._v66 = s
	return s
end

local function ensure_mote()
	if M._mote then return M._mote end
	local s = Sprite()
	s:Load(particle_frames.ANM2, true)
	M._mote = s
	return s
end

local function rotation_of_vec(v)
	if not v or v:LengthSquared() < 1e-8 then return 90 end
	return v:GetAngleDegrees()
end

local function rotation_of_xy(dx, dy)
	if (dx * dx + dy * dy) < 1e-8 then return 90 end
	_rot_tmp.X = dx
	_rot_tmp.Y = dy
	return _rot_tmp:GetAngleDegrees()
end

local MAX_COLUMN_SEG_LEN = 26 -- refuse long chords that stab through the funnel

local function stamp_slot(list, idx)
	local st = list[idx]
	if not st then
		st = {mid = Vector(0, 0), rot = 0, sx = 1, sy = 1}
		list[idx] = st
	elseif not st.mid then
		st.mid = Vector(0, 0)
	end
	return st
end

--- Write one short arc into list[idx]. Returns true if accepted.
local function write_column_stamp(list, idx, apos, bpos)
	if not apos or not bpos then return false end
	local dx = bpos.X - apos.X
	local dy = bpos.Y - apos.Y
	local dist = math.sqrt(dx * dx + dy * dy)
	if dist < 2.0 or dist > MAX_COLUMN_SEG_LEN then
		return false
	end
	local st = stamp_slot(list, idx)
	st.mid.X = (apos.X + bpos.X) * 0.5
	st.mid.Y = (apos.Y + bpos.Y) * 0.5
	st.rot = rotation_of_xy(dx, dy)
	st.sx = math.min(1.05, dist / 22)
	st.sy = 0.55 + 0.35 * math.min(1, dist / 18)
	return true
end

local function append_column_stamp(list, apos, bpos)
	local n = #list + 1
	if write_column_stamp(list, n, apos, bpos) then
		return true
	end
	list[n] = nil
	return false
end

local function clear_draw_stamps(p)
	local ds = p.draw_stamps
	if not ds then
		p.draw_stamps = {}
		p.draw_stamps_n = 0
		return p.draw_stamps
	end
	for i = #ds, 1, -1 do
		ds[i] = nil
	end
	p.draw_stamps_n = 0
	return ds
end

local function room_bounds()
	local room = Game():GetRoom()
	return room:GetTopLeftPos(), room:GetBottomRightPos(), room:GetCenterPos()
end

local function room_outer_radius()
	local tl, br = room_bounds()
	return 0.42 * math.min(math.abs(br.X - tl.X), math.abs(br.Y - tl.Y))
end

local function storm_color(alpha, kind)
	if M.force_white then return Color(1, 1, 1, 1) end
	if kind == "motes" then return Color(1, 1, 1, alpha) end
	if kind == "gust" then return Color(0.94, 0.93, 0.98, alpha) end
	if kind == "impact" then return Color(0.96, 0.95, 1.0, alpha) end
	return Color(0.95, 0.94, 0.99, alpha)
end

local function reset_emit_clock()
	local now = Game():GetFrameCount()
	M.emit = {
		airflow = now,
		gust = now + 4,
		motes = now + 2,
	}
end

local function reset_metrics()
	M.metrics = {
		edge_spawn_attempt = 0,
		edge_spawn_inward = 0,
		edge_spawn_rejected = 0,
		spawned = 0,
		entered_view = 0,
		entered_visible = 0,
		entry_timeout = 0,
		natural_exit = 0,
		absorbed_into_column = 0,
		exited_visible = 0,
		visible_now = 0,
		inbound_visible = 0,
		inbound_incoming = 0,
		column_visible = 0,
		column_renderable_segments = 0,
		top_eject_visible = 0,
		motes_visible = 0,
		emit_attempt = 0,
		emit_success = 0,
		emit_blocked_budget = 0,
		emit_blocked_interval = 0,
		rendered_inbound_segments = 0,
		rendered_column_stamps = 0,
		render_sprite_attempts = 0,
		render_sprite_success = 0,
		column_geometry_builds = 0,
		census_calls = 0,
		temporary_table_allocations = 0,
		update_time_ms = 0,
		render_time_ms = 0,
		gc_kb = 0,
		total_particles = 0,
		inbound_particles = 0,
		column_particles = 0,
		diag = nil,
		diag_frames = 0,
		remove = {
			natural_exit = 0,
			entry_timeout = 0,
			outside_before_visible = 0,
			room_change = 0,
		},
		by_layer = {
			airflow = {spawned = 0, visible = 0, incoming_valid = 0, incoming_failed = 0, exiting = 0,
				inbound_active = 0, column_total = 0, remove = {}},
			gust = {spawned = 0, visible = 0, incoming_valid = 0, incoming_failed = 0, exiting = 0,
				inbound_active = 0, column_total = 0, remove = {}},
			motes = {spawned = 0, visible = 0, incoming_valid = 0, incoming_failed = 0, exiting = 0,
				inbound_active = 0, column_total = 0, remove = {}},
		},
		edge_by_side = emission.empty_edge_stats and emission.empty_edge_stats() or {
			[0] = {attempt = 0, ok = 0, fail = 0},
			[1] = {attempt = 0, ok = 0, fail = 0},
			[2] = {attempt = 0, ok = 0, fail = 0},
			[3] = {attempt = 0, ok = 0, fail = 0},
		},
	}
	M._inbound_blank_frames = 0
end

local function metric_inc(key, n)
	if not M.metrics then reset_metrics() end
	M.metrics[key] = (M.metrics[key] or 0) + (n or 1)
end

local function note_remove(layer, reason)
	if not M.metrics then reset_metrics() end
	M.metrics.remove = M.metrics.remove or {}
	M.metrics.remove[reason] = (M.metrics.remove[reason] or 0) + 1
	local bl = M.metrics.by_layer and M.metrics.by_layer[layer]
	if not bl then return end
	bl.remove = bl.remove or {}
	bl.remove[reason] = (bl.remove[reason] or 0) + 1
end

function M.note_room_event(name)
	local frame = 0
	local ok, n = pcall(function()
		return Game():GetFrameCount()
	end)
	if ok then frame = n or 0 end
	M.room_trace = M.room_trace or {}
	M.room_trace[#M.room_trace + 1] = tostring(name) .. "@" .. tostring(frame)
	while #M.room_trace > 8 do
		table.remove(M.room_trace, 1)
	end
end

function M.reset_particles(reason)
	M.particles = {}
	M.particle_reset_count = (M.particle_reset_count or 0) + 1
	M.last_reset_reason = reason or "unknown"
	M.note_room_event("reset:" .. tostring(M.last_reset_reason))
	M._edge_rr = 0
	reset_emit_clock()
	reset_metrics()
	local p = probe()
	if p and p.note_reset then p.note_reset(M.last_reset_reason) end
end

function M.clear(reason)
	M.reset_particles(reason or "clear")
	tornado.clear()
	M.impact = nil
	M.cover_alpha = 0
	M.pulse = nil
	M.phase = "directional"
	M.eye_radius_scale = 1
	M.intro_fade = 0
	M._density_log = nil
	M._density_ring = nil
	M._census_cache = nil
	M._edge_rr = 0
end

function M.set_phase(phase)
	M.phase = phase or "directional"
	-- Formal eye / full storm always restores every visual layer.
	if M.phase == "eye" then
		restore_all_layers()
	end
end

function M.set_eye_radius_scale(scale)
	M.eye_radius_scale = math.max(0.2, math.min(1.4, tonumber(scale) or 1))
	if tornado.is_active() then
		tornado.set_growth(math.min(1, M.eye_radius_scale))
	end
end

function M.set_cover_alpha(alpha)
	M.cover_alpha = math.max(0, math.min(1, tonumber(alpha) or 0))
end

function M.set_force_white(on)
	M.force_white = on == true
end

function M.begin_impact(center, opts)
	opts = opts or {}
	center = center or Game():GetRoom():GetCenterPos()
	M.impact = {
		center = Vector(center.X, center.Y),
		age = 0,
		rings = {},
		sprays = {},
	}
	for i = 1, 6 do
		local ang = (i / 6) * 360 + auxi.random_1() * 20
		M.impact.rings[#M.impact.rings + 1] = {
			ang = ang,
			radius = 8,
			anim = "IRing" .. tostring(1 + ((i - 1) % 4)),
			arc_anim = "IArc" .. tostring(1 + ((i - 1) % 4)),
			life = 42,
			age = 0,
		}
	end
	for i = 1, 14 do
		local ang = auxi.random_1() * 360
		M.impact.sprays[#M.impact.sprays + 1] = {
			ang = ang,
			dist = 6 + auxi.random_1() * 10,
			speed = 9 + auxi.random_1() * 7,
			anim = "ISpray" .. tostring(1 + math.floor(auxi.random_1() * 6)),
			life = 18 + math.floor(auxi.random_1() * 14),
			age = 0,
			alpha = 0.55 + auxi.random_1() * 0.25,
		}
	end
	if opts.collapse_tornado ~= false and tornado.is_active() then
		tornado.set_spread(0.2)
	end
end

function M.clear_impact()
	M.impact = nil
end

--- Story / shutdown fade: dissolve remaining trails then clear.
function M.begin_shutdown_fade()
	for _, p in ipairs(M.particles) do
		if p.layer ~= "motes" and p.stage ~= STAGE.DISSOLVING then
			p.stage = STAGE.DISSOLVING
			p.dissolve_age = 0
			p.exiting = true
		elseif p.layer == "motes" then
			p.exiting = true
		end
	end
end

local function blow_of(sess)
	return physics.wind_blow_dir(sess and sess.ang or 0)
end

local function room_span_along(blow)
	local tl, br = room_bounds()
	local b = blow:Normalized()
	local corners = {tl, Vector(br.X, tl.Y), br, Vector(tl.X, br.Y)}
	local min_p, max_p = math.huge, -math.huge
	for i = 1, 4 do
		local p = corners[i]:Dot(b)
		if p < min_p then min_p = p end
		if p > max_p then max_p = p end
	end
	return math.max(80, max_p - min_p)
end

local function safe_norm(v)
	if not v or v:LengthSquared() < 1e-8 then return Vector(0, 1) end
	return v:Normalized()
end

local function flow_opts(sess, intensity, seed, base_speed, layer)
	local phase = M.phase or "directional"
	local core = room_outer_radius() * 0.28 * (M.eye_radius_scale or 1)
	if tornado.is_active() and tornado.get_core_radius then
		core = math.max(core, tornado.get_core_radius())
	end
	local time = Game():GetFrameCount()
	local gust_mul = 1
	if layer == "gust" then
		gust_mul = flow.gust_speed_mul(time)
	elseif layer == "airflow" or layer == "motes" then
		gust_mul = flow.airflow_speed_mul(time, seed)
	end
	local opts = {
		phase = phase,
		intensity = intensity,
		base_speed = base_speed,
		blow = blow_of(sess),
		center = sess and sess.pos,
		radius = core,
		core_radius = core,
		far_radius = core * 3.8,
		seed = seed or 0,
		gust_mul = gust_mul,
	}
	if phase ~= "eye" and phase ~= "impact" and sess then
		opts.visual_source = sess.visual_source
		opts.visual_bend = sess.visual_bend
	end
	if phase == "impact" and M.impact then
		opts.impact_center = M.impact.center
		opts.impact_age = M.impact.age or 0
		opts.phase = "impact"
	end
	return opts
end

local function eye_core_radius()
	local core = room_outer_radius() * 0.28 * (M.eye_radius_scale or 1)
	if tornado.is_active() and tornado.get_core_radius then
		core = math.max(core, tornado.get_core_radius())
	end
	return core
end

local function funnel_profile()
	local g = math.min(1, M.eye_radius_scale or 1)
	local vs = tornado.visual_scale or 0.85
	local core = eye_core_radius()
	local profile = streamline.default_profile({
		growth = g,
		visual_scale = vs,
		r_bot = tornado.R_bot or 19,
		r_top = tornado.R_top or 70,
		column_h = 178,
	})
	-- Capture near the live core radius so inflow meets the visible column.
	profile.capture = math.max(profile.r_bot * 1.05, core * 0.92)
	return profile
end

--- Layer-specific spawn. Eye: deterministic edge birth + analytical stream (never fails).
-- returns tip, source, spawn_v, edge, birth_mode ("edge"|"column"|"upwind"|"impact")
local function pick_spawn_for_layer(sess, blow, layer)
	local phase = M.phase or "directional"
	local _, _, center = room_bounds()
	center = (sess and sess.pos) or center

	if phase == "impact" and M.impact then
		local ang = auxi.random_1() * 360
		local r = 8 + auxi.random_1() * 28
		return center + auxi.MakeVector(ang) * r, "impact", nil, nil, "impact"
	end

	if phase == "eye" then
		-- MOTES only: minority already-on-column ascending debris.
		if layer == "motes" and auxi.random_1() < 0.18 then
			metric_inc("edge_spawn_attempt")
			metric_inc("edge_spawn_inward")
			return center, "column", nil, nil, "column"
		end

		metric_inc("edge_spawn_attempt")
		if not M.metrics then reset_metrics() end
		local edge = (M._edge_rr or 0) % 4
		M._edge_rr = (M._edge_rr or 0) + 1
		local t = 0.08 + auxi.random_1() * 0.84
		local pos = emission.spawn_on_edge(edge, t)
		metric_inc("edge_spawn_inward")
		local es = M.metrics.edge_by_side[edge]
		if es then
			es.spawn_attempt = (es.spawn_attempt or 0) + 1
			es.spawn_success = (es.spawn_success or 0) + 1
		end
		-- Initial tangent guessed toward center; stream overwrites on attach.
		local toward = center - pos
		local v0 = toward:Length() > 1e-3 and toward:Normalized() * 8 or Vector(0, 1)
		return pos, "edge", v0, edge, "edge"
	end

	return emission.spawn_upwind_rng(blow, auxi.random_1()), "upwind", nil, nil, "upwind"
end

local function visual_mode_of(p)
	return p.visual_mode or "streak"
end

local function is_column_mode(p)
	local m = visual_mode_of(p)
	return m == "column_arc" or m == "top_eject"
end

local function is_inbound_mode(p)
	return not is_column_mode(p)
end

local function count_column_stamps(samples)
	if not samples or #samples < 2 then return 0 end
	local n = 0
	for i = 1, #samples - 1 do
		local a, b = samples[i].pos, samples[i + 1].pos
		if a and b then
			local dist = (b - a):Length()
			if dist >= 2.0 and dist <= MAX_COLUMN_SEG_LEN then
				n = n + 1
			end
		end
	end
	return n
end

--- Guarantee ≥1 drawable short arc before fading out the inbound streak (Update only).
local function ensure_column_drawable(p, pos, tang)
	p.column_samples = p.column_samples or {}
	local stamps = count_column_stamps(p.column_samples)
	if stamps > 0 then return stamps end
	if not tang or tang:LengthSquared() < 1e-8 then
		tang = Vector(0, -1)
	else
		tang = tang:Normalized()
	end
	local tip = Vector(pos.X, pos.Y)
	local back = Vector(tip.X - tang.X * 10, tip.Y - tang.Y * 10)
	local samples = p.column_samples
	if #samples == 1 then
		local only = samples[1].pos
		local d = only and (tip - only):Length() or 0
		if only and d >= 2.0 and d <= MAX_COLUMN_SEG_LEN then
			samples[2] = samples[2] or {}
			samples[2].pos = tip
			samples[2].tang = tang
		else
			samples[1] = samples[1] or {}
			samples[1].pos = back
			samples[1].tang = tang
			samples[2] = samples[2] or {}
			samples[2].pos = tip
			samples[2].tang = tang
			for i = #samples, 3, -1 do samples[i] = nil end
		end
	else
		samples[1] = samples[1] or {}
		samples[1].pos = back
		samples[1].tang = tang
		samples[2] = samples[2] or {}
		samples[2].pos = tip
		samples[2].tang = tang
		for i = #samples, 3, -1 do samples[i] = nil end
	end
	return count_column_stamps(p.column_samples)
end

--- Motion samples stay dense; draw_stamps pick ≤ MAX_DRAW_STAMPS high-value arcs.
local function prepare_column_draw(p)
	if M.metrics then
		M.metrics.column_geometry_builds = (M.metrics.column_geometry_builds or 0) + 1
	end
	local ds = clear_draw_stamps(p)
	if not is_column_mode(p) or p.column_visual == false then
		p.column_renderable = 0
		return
	end
	local tang = p.velocity
	if (not tang) or tang:LengthSquared() < 1e-8 then
		tang = (p.stream and p.stream.tangent) or Vector(0, -1)
	end
	ensure_column_drawable(p, p.pos, tang)
	local samples = p.column_samples
	local n = samples and #samples or 0
	if n < 2 then
		p.column_renderable = 0
		return
	end
	local chords = n - 1
	local want = math.min(MAX_DRAW_STAMPS, chords)
	-- Evenly pick chord starts into scratch (1-based sample index of chord start).
	for i = #_chord_pick, 1, -1 do _chord_pick[i] = nil end
	for i = 1, want do
		local idx = 1 + math.floor(((i - 0.5) / want) * chords)
		if idx < 1 then idx = 1 end
		if idx > chords then idx = chords end
		_chord_pick[i] = idx
	end
	local written = 0
	for i = 1, want do
		local idx = _chord_pick[i]
		local a = samples[idx] and samples[idx].pos
		local b = samples[idx + 1] and samples[idx + 1].pos
		if write_column_stamp(ds, written + 1, a, b) then
			written = written + 1
		end
	end
	-- Fallback: forced short tangent stamp if every chord was rejected.
	if written == 0 then
		local tip = p.pos
		local t = tang:Normalized()
		local back = Vector(tip.X - t.X * 10, tip.Y - t.Y * 10)
		if write_column_stamp(ds, 1, back, tip) then
			written = 1
		end
	end
	for i = #ds, written + 1, -1 do ds[i] = nil end
	p.draw_stamps = ds
	p.draw_stamps_n = written
	p.column_renderable = written
end

local function inbound_trail_drawable(p)
	local trail = p.trail
	if not trail or #trail < 2 then return false end
	for s = 1, #trail - 1 do
		local dist = (trail[s + 1] - trail[s]):Length()
		if dist >= 3.0 then return true end
	end
	return false
end

local function any_pos_list_visible(list, half, rect, get_pos)
	if not list then return false end
	for i = 1, #list do
		local pos = get_pos and get_pos(list[i]) or list[i]
		if pos and emission.intersects_view(pos, half, rect) then
			return true
		end
	end
	return false
end

local function particle_visible(p, rect)
	local half_m = emission.sprite_half()
	local half_t = emission.trail_half()
	rect = rect or emission.screen_view_rect()
	if p.layer == "motes" then
		return emission.intersects_view(p.pos, half_m, rect)
	end
	if is_column_mode(p) then
		if p.draw_stamps_n and p.draw_stamps_n > 0 and p.draw_stamps then
			if any_pos_list_visible(p.draw_stamps, half_t, rect, function(st) return st.mid end) then
				return true
			end
		end
		if p.column_samples and #p.column_samples > 0 then
			if any_pos_list_visible(p.column_samples, half_t, rect, function(s) return s.pos end) then
				return true
			end
		end
		if (p.trail_fade or 0) > 0.04 and p.trail and emission.any_point_visible(p.trail, half_t, rect) then
			return true
		end
		return false
	end
	if p.trail and #p.trail > 0 then
		return emission.any_point_visible(p.trail, half_t, rect)
	end
	return emission.intersects_view(p.pos, half_t, rect)
end

local function inbound_renderable(p, rect)
	if not is_inbound_mode(p) then return false end
	if p.layer == "motes" then
		return particle_visible(p, rect)
	end
	if not inbound_trail_drawable(p) then return false end
	return particle_visible(p, rect)
end

local function column_renderable(p, rect)
	if not is_column_mode(p) then return false end
	if p.column_visual == false then
		return (p.trail_fade or 0) > 0.04 and inbound_trail_drawable(p) and particle_visible(p, rect)
	end
	if p.layer == "motes" then
		return particle_visible(p, rect)
	end
	local stamps = p.draw_stamps_n or p.column_renderable or 0
	if stamps >= 1 and particle_visible(p, rect) then return true end
	if (p.trail_fade or 0) > 0.04 and inbound_trail_drawable(p) and particle_visible(p, rect) then
		return true
	end
	return false
end

local function classify_particle(p, rect)
	if p.life_state == "exiting" or p.exiting or p.stage == STAGE.DISSOLVING then
		return "exiting"
	end
	if p.life_state == "incoming" then
		if p.incoming_valid == false then
			return "incoming_failed"
		end
		return "incoming_valid"
	end
	if particle_visible(p, rect) then
		return "visible"
	end
	if p.was_visible then
		return "exiting"
	end
	return "incoming_valid"
end

local function empty_census()
	return {
		total = 0, visible = 0, incoming = 0, incoming_valid = 0,
		incoming_failed = 0, exiting = 0,
		inbound_total = 0, inbound_visible = 0, inbound_incoming = 0, inbound_active = 0,
		column_total = 0, column_visible = 0, column_renderable = 0, column_visual = 0,
		top_eject = 0, active = 0,
	}
end

local function reset_census_into(c)
	c.total = 0
	c.visible = 0
	c.incoming = 0
	c.incoming_valid = 0
	c.incoming_failed = 0
	c.exiting = 0
	c.inbound_total = 0
	c.inbound_visible = 0
	c.inbound_incoming = 0
	c.inbound_active = 0
	c.column_total = 0
	c.column_visible = 0
	c.column_renderable = 0
	c.column_visual = 0
	c.top_eject = 0
	c.active = 0
	return c
end

local function ensure_census_cache()
	if M._census_cache and M._census_cache.layers then
		return M._census_cache
	end
	M._census_cache = {
		frame = -1,
		layers = {
			airflow = empty_census(),
			gust = empty_census(),
			motes = empty_census(),
		},
	}
	return M._census_cache
end

--- Single full scan of all particles → three layer buckets (per logic frame).
local function refresh_census_cache(rect, force)
	rect = rect or emission.screen_view_rect()
	local cache = ensure_census_cache()
	local frame = Game():GetFrameCount()
	if not force and cache.frame == frame then
		return cache.layers
	end
	if M.metrics then
		M.metrics.census_calls = (M.metrics.census_calls or 0) + 1
	end
	local layers = cache.layers
	reset_census_into(layers.airflow)
	reset_census_into(layers.gust)
	reset_census_into(layers.motes)
	for _, p in ipairs(M.particles) do
		local layer = p.layer
		local c = layers[layer]
		if c then
			c.total = c.total + 1
			local k = classify_particle(p, rect)
			if k == "incoming_valid" then
				c.incoming_valid = c.incoming_valid + 1
				c.incoming = c.incoming + 1
			elseif k == "incoming_failed" then
				c.incoming_failed = c.incoming_failed + 1
			elseif k == "visible" then
				c.visible = c.visible + 1
			elseif k == "exiting" then
				c.exiting = c.exiting + 1
			end
			if is_column_mode(p) then
				c.column_total = c.column_total + 1
				if p.column_visual ~= false then
					c.column_visual = c.column_visual + 1
				end
				if visual_mode_of(p) == "top_eject" then
					c.top_eject = c.top_eject + 1
				end
				c.column_renderable = c.column_renderable + (p.draw_stamps_n or p.column_renderable or 0)
				if column_renderable(p, rect) then
					c.column_visible = c.column_visible + 1
				end
			else
				c.inbound_total = c.inbound_total + 1
				if k == "incoming_valid" then
					c.inbound_incoming = c.inbound_incoming + 1
				elseif k == "visible" or inbound_renderable(p, rect) then
					c.inbound_visible = c.inbound_visible + 1
				elseif k ~= "exiting" and k ~= "incoming_failed" then
					c.inbound_incoming = c.inbound_incoming + 1
				end
			end
		end
	end
	for _, name in ipairs({"airflow", "gust", "motes"}) do
		local c = layers[name]
		c.inbound_active = c.inbound_visible + c.inbound_incoming
		c.active = c.inbound_active
	end
	cache.frame = frame
	return layers
end

local function layer_census(layer, rect)
	local layers = refresh_census_cache(rect, false)
	return layers[layer] or empty_census()
end

local function bump_census_spawn(layer, p)
	local cache = ensure_census_cache()
	local c = cache.layers and cache.layers[layer]
	if not c then return end
	c.total = c.total + 1
	if is_column_mode(p) then
		c.column_total = c.column_total + 1
		if p.column_visual ~= false then
			c.column_visual = c.column_visual + 1
		end
	else
		c.inbound_total = c.inbound_total + 1
		c.inbound_incoming = c.inbound_incoming + 1
		c.inbound_active = c.inbound_visible + c.inbound_incoming
		c.active = c.inbound_active
		c.incoming_valid = c.incoming_valid + 1
		c.incoming = c.incoming + 1
	end
end

local function target_visible(layer, intensity, phase)
	phase = phase or M.phase or "directional"
	if layer == "airflow" then
		local n = env_config.streak_budget(intensity)
		if phase == "eye" then return math.max(16, math.floor(n * 1.05)) end
		if phase == "combat" then return math.max(8, math.floor(n * 0.5)) end
		if phase == "impact" then return n + 4 end
		return n
	elseif layer == "gust" then
		local n = env_config.gust_budget(intensity)
		if phase == "eye" then return math.max(2, n) end
		if phase == "impact" then return n + 2 end
		return n
	else
		local n = env_config.motes_budget(intensity)
		if phase == "eye" then return math.max(3, math.floor(n * 0.55)) end
		if phase == "combat" then return math.floor(n * 0.5) end
		if phase == "impact" then return math.floor(n * 0.7) end
		return n
	end
end

local function column_cap_for(layer)
	return COLUMN_CAP[layer] or 12
end

local function count_column_visual(layer)
	local n = 0
	for _, p in ipairs(M.particles) do
		if p.layer == layer and is_column_mode(p) and p.column_visual ~= false then
			n = n + 1
		end
	end
	return n
end

--- Only on-screen column stamps occupy a draw slot. Off-screen holders must not
--- erase the inbound streak and then sit invisible until the cap frees.
local function count_visible_column_slots(layer, rect)
	local n = 0
	for _, p in ipairs(M.particles) do
		if p.layer == layer and p.column_visual ~= false and column_renderable(p, rect) then
			n = n + 1
		end
	end
	return n
end

local function attach_eye_stream(p, sess, tip, source)
	if (M.phase or "") ~= "eye" or not sess then return end
	local center = sess.pos or Game():GetRoom():GetCenterPos()
	local profile = funnel_profile()
	local speed = p.speed or 8
	if source == "column" then
		p.stream = streamline.begin_ascending(center, {
			profile = profile,
			speed = speed * 0.9,
			ang01 = auxi.random_1(),
			h0 = 0.08 + auxi.random_1() * 0.22,
			layer = p.layer,
			turn_sign = 1,
		})
		p.in_column = true
		p.visual_mode = "column_arc"
		p.column_visual = count_column_visual(p.layer) < column_cap_for(p.layer)
	else
		local sector = streamline.sector_opts_for_edge and streamline.sector_opts_for_edge(p.edge or 0) or {}
		sector.center = center
		sector.profile = profile
		sector.speed = speed
		sector.layer = p.layer
		sector.turn_sign = 1
		sector.speed_jitter = (auxi.random_1() - 0.5) * 0.1
		p.stream = streamline.begin(tip, sector)
		p.visual_mode = "streak"
		p.column_visual = nil
	end
	p.column_samples = p.column_samples or {}
	p.trail_fade = 1
	p.draw_stamps_n = 0
	if p.stream and p.stream.pos then
		p.pos = Vector(p.stream.pos.X, p.stream.pos.Y)
		local tang = p.stream.tangent or Vector(0, 1)
		p.velocity = tang * speed
	end
	if p.visual_mode == "column_arc" and p.column_visual ~= false then
		prepare_column_draw(p)
	end
end

local function make_particle(sess, layer, intensity)
	local blow = blow_of(sess)
	local seed = math.floor(auxi.random_1() * 100000)
	local span = room_span_along(blow)
	local tip, source, spawn_v, edge = pick_spawn_for_layer(sess, blow, layer)
	if not tip then
		return nil
	end

	local p
	if layer == "motes" then
		local speed = 4.5 + intensity * 4.5
		local frame = particle_frames.pick(auxi.random_1())
		local v0 = spawn_v or flow.sample_flow(tip, sess, Game():GetFrameCount(), flow_opts(sess, intensity, seed, speed, "motes"))
		local soft_life = math.floor((span / math.max(4, speed)) * (0.9 + auxi.random_1() * 0.4))
		soft_life = math.max(40, math.min(120, soft_life))
		p = {
			layer = "motes",
			age = 0,
			sgid = Game():GetLevel():GetCurrentRoomDesc().SafeGridIndex,
			seed = seed,
			pos = tip,
			source = source,
			edge = edge,
			speed = speed,
			velocity = v0,
			was_visible = false,
			life_state = "incoming",
			incoming_valid = true,
			in_column = source == "column",
			anim = (frame and frame.anim) or "Particle001",
			life = soft_life,
			Rotation = rotation_of_vec(v0) + (auxi.random_1() * 50 - 25),
			spin = (auxi.random_1() * 2 - 1) * (2.2 + auxi.random_1() * 2.5),
			Scale = Vector(0.95 + auxi.random_1() * 0.2, 0.95 + auxi.random_1() * 0.2),
			Color = storm_color(0.75 + intensity * 0.2, "motes"),
			stage = STAGE.FLOWING,
			kind = "motes",
			exiting = false,
		}
	else
		local is_gust = layer == "gust"
		local speed = (is_gust and (11 + intensity * 7) or (9 + intensity * 6)) * (0.94 + auxi.random_1() * 0.12)
		local trail_max = is_gust and 6 or 7
		local grow = 6 + math.floor(auxi.random_1() * 4)
		local tip_i = 1 + math.floor(auxi.random_1() * TIP_N)
		local body_i = 1 + math.floor(auxi.random_1() * BODY_N)
		local tail_i = 1 + math.floor(auxi.random_1() * TAIL_N)
		local v0 = spawn_v or flow.sample_flow(tip, sess, Game():GetFrameCount(), flow_opts(sess, intensity, seed, speed, layer))
		local back = tip - safe_norm(v0) * (speed * 0.5)
		p = {
			layer = layer,
			age = 0,
			sgid = Game():GetLevel():GetCurrentRoomDesc().SafeGridIndex,
			seed = seed,
			pos = tip,
			source = source,
			edge = edge,
			speed = speed,
			velocity = v0,
			trail = {back, Vector(tip.X, tip.Y)},
			trail_max = trail_max,
			life = math.floor((span / math.max(4, speed)) * 1.4) + 40,
			grow_frames = grow,
			dissolve_frames = 14,
			dissolve_age = 0,
			stage = STAGE.GROWING,
			Rotation = rotation_of_vec(v0),
			Scale = is_gust and Vector(1.05, 1.0) or Vector(0.95, 0.9),
			Color = storm_color(is_gust and (0.40 + intensity * 0.22) or (0.42 + intensity * 0.28), is_gust and "gust" or "airflow"),
			kind = is_gust and "gust" or "airflow",
			tip_anim = "Tip" .. tostring(tip_i),
			body_anim = "Body" .. tostring(body_i),
			tail_anim = "Tail" .. tostring(tail_i),
			tex_w = TEX_W,
			exiting = false,
			was_visible = false,
			life_state = "incoming",
			incoming_valid = true,
			in_column = source == "column",
			reached_cyclone = false,
		}
	end
	attach_eye_stream(p, sess, tip, source)
	return p
end

local function apply_eye_climb(p, sess, intensity)
	if (M.phase or "") ~= "eye" or not sess or not sess.pos then return end
	local d = p.pos - sess.pos
	local r = d:Length()
	local core = room_outer_radius() * 0.28 * (M.eye_radius_scale or 1)
	if tornado.is_active() and tornado.get_core_radius then
		core = math.max(core, tornado.get_core_radius())
	end
	if r < core * 0.95 then
		local climb = (2.2 + intensity * 2.8) * (1 - r / math.max(1, core))
		p.pos = p.pos + Vector(0, -climb)
		if p.velocity then
			p.velocity = p.velocity + Vector(0, -climb * 0.35)
		end
		p.climbing = true
	else
		p.climbing = false
	end
end

local function steer_exit(p, sess, intensity)
	local dir = p.velocity
	if p.climbing then
		dir = Vector(0, -1)
	elseif not dir or dir:LengthSquared() < 1e-6 then
		dir = blow_of(sess)
	end
	local target = emission.exit_target(p.pos, dir)
	local toward = safe_norm(target - p.pos)
	local spd = math.max(7, (p.speed or 8) * 1.25)
	local v = toward * spd
	local opts = flow_opts(sess, intensity, p.seed, p.speed or 8, p.layer)
	local flow_v = flow.sample_flow(p.pos, sess, Game():GetFrameCount(), opts)
	return flow_v * 0.25 + v * 0.75
end

local function blend_vel(prev, target, k)
	prev = prev or target
	return prev * (1 - k) + target * k
end

local function tick_pulse()
	local now = Game():GetFrameCount()
	M.pulse = M.pulse or {}
	local p = M.pulse
	if p.until_frame and now <= p.until_frame then
		return p.boost or env_config.PULSE_BOOST or 0.2
	end
	if not p.next then p.next = now + env_config.PULSE_MIN end
	if now >= p.next then
		p.until_frame = now + math.floor(18 + auxi.random_1() * 24)
		p.boost = env_config.PULSE_BOOST or 0.22
		p.next = now + env_config.PULSE_MIN
			+ math.floor(auxi.random_1() * math.max(1, env_config.PULSE_MAX - env_config.PULSE_MIN))
		return p.boost
	end
	return 0
end

local function advance_particle(p, sess, intensity, frames)
	frames = math.max(0, math.floor(frames or 0))
	local time0 = Game():GetFrameCount()
	for f = 1, frames do
		p.age = (p.age or 0) + 1
		if p.stream then
			local spd = p.speed or 8
			local pos, tang = streamline.advance(p.stream, spd)
			p.pos = pos
			p.velocity = tang * spd
			if p.layer == "motes" then
				if p.spin then p.Rotation = (p.Rotation or 0) + p.spin end
			else
				if p.stage == STAGE.GROWING and p.age >= (p.grow_frames or 7) then
					p.stage = STAGE.FLOWING
				end
				p.Rotation = rotation_of_vec(p.velocity)
				local trail = p.trail or {Vector(p.pos.X, p.pos.Y)}
				trail[#trail + 1] = Vector(p.pos.X, p.pos.Y)
				local maxn = p.trail_max or 7
				while #trail > maxn do table.remove(trail, 1) end
				p.trail = trail
			end
		else
			local opts = flow_opts(sess, intensity, p.seed, p.speed or 8, p.layer)
			local v = flow.sample_flow(p.pos, sess, time0 + f, opts)
			if p.layer == "motes" then
				p.velocity = blend_vel(p.velocity, v, 0.18)
				p.pos = p.pos + p.velocity
				apply_eye_climb(p, sess, intensity)
				if p.spin then p.Rotation = (p.Rotation or 0) + p.spin end
			else
				if p.stage == STAGE.GROWING and p.age >= (p.grow_frames or 7) then
					p.stage = STAGE.FLOWING
				end
				p.velocity = v
				p.pos = p.pos + v
				apply_eye_climb(p, sess, intensity)
				p.Rotation = rotation_of_vec(v)
				local trail = p.trail or {Vector(p.pos.X, p.pos.Y)}
				trail[#trail + 1] = Vector(p.pos.X, p.pos.Y)
				local maxn = p.trail_max or 7
				while #trail > maxn do table.remove(trail, 1) end
				p.trail = trail
			end
		end
	end
end

local function absorb_column_visual(p)
	-- Keep logical stream; funnel Back/Core/Front carries density. No extra arc sprites.
	p.column_visual = false
	p.draw_stamps_n = 0
	p.column_renderable = 0
	clear_draw_stamps(p)
	p.exiting = true
	p.speed = math.min((p.speed or 8) * 1.25, 18)
	if p.stream then p.stream.speed = p.speed end
	if (p.trail_fade or 1) > 0.35 then
		p.trail_fade = 0.35
	end
end

local function release_column_to_streak(p)
	p.visual_mode = "streak"
	p.column_visual = nil
	p.trail_fade = 1
	p._col_miss = 0
	p.column_renderable = 0
	clear_draw_stamps(p)
end

local function cull_column_overflow(layer)
	local cap = column_cap_for(layer)
	local rect = emission.screen_view_rect()
	local shown = {}
	for _, p in ipairs(M.particles) do
		if p.layer == layer and is_column_mode(p) and p.column_visual ~= false then
			if column_renderable(p, rect) then
				shown[#shown + 1] = p
			else
				-- Off-screen column holders were keeping the cap full while their
				-- trails faded, so the whole field went blank.
				release_column_to_streak(p)
			end
		end
	end
	local overflow = #shown - cap
	if overflow <= 0 then return end
	for k = 1, overflow do
		local p = shown[k]
		if p then absorb_column_visual(p) end
	end
end

local function schedule_emit(sess, intensity, layer, ignore_chance)
	if not layer_enabled(layer) then return end
	if not M.emit then reset_emit_clock() end
	if not M.metrics then reset_metrics() end
	local now = Game():GetFrameCount()
	local cfg = EMIT[layer]
	if not cfg then return end
	if now < (M.emit[layer] or 0) then
		return
	end

	-- Use frame census snapshot (filled by spawn_budgeted / update). No extra full scans.
	local census = layer_census(layer, nil)
	local need_vis = target_visible(layer, intensity, M.phase)
	local inbound_cap = math.floor(need_vis * cfg.cap_mul + 0.5) + 4
	cull_column_overflow(layer)

	local inbound_slots = census.inbound_active
	local should = inbound_slots < need_vis and inbound_slots < inbound_cap
	if census.inbound_visible < math.max(2, math.floor(need_vis * 0.45)) then
		should = true
	end

	local interval = cfg.interval
	if (M.phase or "") == "eye" and layer == "airflow" then
		interval = math.max(1, interval - 1)
	end
	if census.inbound_visible < need_vis * 0.55 then
		interval = math.max(1, math.floor(interval * 0.5))
	elseif census.inbound_visible >= need_vis then
		interval = interval + math.floor(cfg.jitter * 0.5)
	end

	M.emit[layer] = now + interval + math.floor(auxi.random_1() * (cfg.jitter + 1))
	metric_inc("emit_attempt")

	if not should then
		metric_inc("emit_blocked_budget")
		if M.metrics.by_layer and M.metrics.by_layer[layer] then
			M.metrics.by_layer[layer].inbound_active = inbound_slots
			M.metrics.by_layer[layer].column_total = census.column_total
		end
		return
	end
	if not ignore_chance then
		local chance = 0.9
		if layer == "gust" then chance = 0.6 + tick_pulse() * 0.45 end
		if layer == "motes" then
			chance = ((M.phase or "") == "eye") and 0.45 or 0.65
		end
		if auxi.random_1() > chance then return end
	end

	local p = make_particle(sess, layer, intensity)
	if not p then
		local pr = probe()
		if pr and pr.note_spawn then pr.note_spawn({attempt = 1, success = false, count = 0, layer = layer}) end
		return
	end
	metric_inc("spawned")
	metric_inc("emit_success")
	bump_census_spawn(layer, p)
	if M.metrics.by_layer and M.metrics.by_layer[layer] then
		M.metrics.by_layer[layer].spawned = (M.metrics.by_layer[layer].spawned or 0) + 1
		M.metrics.by_layer[layer].inbound_active = census.inbound_active
		M.metrics.by_layer[layer].column_total = census.column_total
	end
	M.particles[#M.particles + 1] = p
	local pr = probe()
	if pr and pr.note_spawn then pr.note_spawn({attempt = 1, success = true, count = 1, layer = layer}) end
end

function M.ensure_eye_structure(center, intensity)
	intensity = clamp01(intensity or 0.7)
	center = center or Game():GetRoom():GetCenterPos()
	restore_all_layers()
	if not tornado.is_active() then
		tornado.begin(center, {
			growth = math.min(1, M.eye_radius_scale or 0.4),
			intensity = intensity,
		})
	else
		tornado.set_center(center)
		tornado.set_intensity(intensity)
		tornado.set_growth(math.min(1, M.eye_radius_scale or 1))
	end
end

function M.release_eye_structure()
	tornado.clear()
end

function M.prefill(sess, intensity, frames)
	if not sess then return end
	intensity = clamp01(intensity or 0.5)
	local blow = blow_of(sess)
	local span = room_span_along(blow)
	-- Full crossing window so ages/positions are naturally staggered.
	local cross = math.max(36, math.floor(span / 9))
	-- Ignore short caller defaults (e.g. runtime prefill_frames=6) — need full window.
	if not frames or frames < math.floor(cross * 0.6) then
		frames = cross
	end
	local phase = M.phase or "directional"
	M.particles = {}
	M.intro_fade = 8
	reset_emit_clock()

	local plans = {}
	if phase == "eye" then
		M.ensure_eye_structure(sess.pos or Game():GetRoom():GetCenterPos(), intensity)
		plans = {
			{"airflow", target_visible("airflow", intensity, phase)},
			{"gust", target_visible("gust", intensity, phase)},
			{"motes", target_visible("motes", intensity, phase)},
		}
	elseif phase == "impact" then
		plans = {
			{"airflow", target_visible("airflow", intensity, phase)},
			{"gust", target_visible("gust", intensity, phase)},
		}
	elseif phase == "combat" then
		M.release_eye_structure()
		plans = {
			{"airflow", target_visible("airflow", intensity, phase)},
			{"gust", target_visible("gust", intensity, phase)},
			{"motes", target_visible("motes", intensity, phase)},
		}
	else
		M.release_eye_structure()
		plans = {
			{"airflow", target_visible("airflow", intensity, phase)},
			{"gust", target_visible("gust", intensity, phase)},
			{"motes", target_visible("motes", intensity, phase)},
		}
	end

	for _, plan in ipairs(plans) do
		local layer, need = plan[1], plan[2]
		if layer_enabled(layer) then
			for i = 1, need do
				local p = make_particle(sess, layer, intensity)
				if p then
					-- Spread ages across full crossing window (not just 0..16).
					local adv = math.floor(((i - 0.5) / need) * frames + (auxi.random_1() - 0.5) * (frames * 0.15))
					adv = math.max(0, math.min(frames, adv))
					-- Eye: keep prefill mostly inbound so slots are not already in the column.
					if phase == "eye" and (layer == "airflow" or layer == "gust") then
						adv = math.min(adv, math.max(8, math.floor(frames * 0.28)))
					end
					advance_particle(p, sess, intensity, adv)
					if particle_visible(p, emission.screen_view_rect()) then
						p.was_visible = true
						p.life_state = "visible"
					else
						p.life_state = "incoming"
						p.incoming_valid = true
					end
					metric_inc("spawned")
					M.particles[#M.particles + 1] = p
				end
			end
		end
	end
	local rect = emission.screen_view_rect()
	local goals = {}
	for i = 1, #plans do
		goals[plans[i][1]] = plans[i][2]
	end
	local function keep_prefill(p)
		if p.life_state == "exiting" or p.exiting then return false end
		if phase == "eye" or phase == "impact" or phase == "combat" or p.layer == "motes" then
			return particle_visible(p, rect) or p.life_state == "incoming"
		end
		return inbound_renderable(p, rect) or column_renderable(p, rect)
	end
	local kept = {}
	local drawable = {airflow = 0, gust = 0}
	for i = 1, #M.particles do
		local p = M.particles[i]
		if keep_prefill(p) then
			kept[#kept + 1] = p
			if drawable[p.layer] ~= nil then
				drawable[p.layer] = drawable[p.layer] + 1
			end
		end
	end
	M.particles = kept
	if phase ~= "eye" and phase ~= "impact" and phase ~= "combat" then
		for _, layer in ipairs({"airflow", "gust"}) do
			local goal = math.floor((goals[layer] or 0) * 0.7)
			local tries = 0
			local limit = math.max(4, (goals[layer] or 0) * 3)
			while layer_enabled(layer) and drawable[layer] < goal and tries < limit do
				tries = tries + 1
				local p = make_particle(sess, layer, intensity)
				if p then
					local adv = math.max(12, math.floor(frames * (0.4 + auxi.random_1() * 0.35)))
					advance_particle(p, sess, intensity, adv)
					if keep_prefill(p) then
						metric_inc("spawned")
						M.particles[#M.particles + 1] = p
						drawable[layer] = drawable[layer] + 1
					end
				end
			end
		end
	end
	M.last_prefill = {
		frame = Game():GetFrameCount(),
		airflow = drawable.airflow,
		gust = drawable.gust,
		airflow_goal = math.floor((goals.airflow or 0) * 0.7),
		gust_goal = math.floor((goals.gust or 0) * 0.7),
		total = #M.particles,
	}
	M.note_room_event("prefill")
end

function M.spawn_budgeted(sess, intensity, ignore_chance)
	if not sess then return end
	local vis = clamp01(intensity) -- no global intensity pulse for continuous wind
	if vis <= 0.01 then return end
	local phase = M.phase or "directional"

	if phase == "eye" then
		M.ensure_eye_structure(sess.pos or Game():GetRoom():GetCenterPos(), vis)
	elseif phase == "impact" then
		if not M.impact then
			M.begin_impact((sess and sess.pos) or Game():GetRoom():GetCenterPos())
		end
	else
		M.release_eye_structure()
	end

	-- One census snapshot for this emit wave; schedule_emit bumps counts incrementally.
	refresh_census_cache(emission.screen_view_rect(), true)
	cull_column_overflow("airflow")
	cull_column_overflow("gust")
	cull_column_overflow("motes")
	-- Independent schedules — MOTES count never gates AIRFLOW/GUST.
	schedule_emit(sess, vis, "airflow", ignore_chance)
	schedule_emit(sess, vis, "gust", ignore_chance)
	schedule_emit(sess, vis, "motes", ignore_chance)
end

function M.update_particles(sess, intensity)
	local t0 = now_ns()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local time = Game():GetFrameCount()
	intensity = clamp01(intensity or (sess and sess.intensity) or 0.5)
	local half_m = emission.sprite_half()
	local half_t = emission.trail_half()
	local view = emission.screen_view_rect()
	local sim = emission.simulation_rect()
	M._fade_blow = blow_of(sess)
	if not M.metrics then reset_metrics() end
	M.metrics.visible_now = 0
	M.metrics.temporary_table_allocations = M.metrics.temporary_table_allocations or 0

	if M.intro_fade and M.intro_fade > 0 then
		M.intro_fade = M.intro_fade - 1
	end

	if M.impact then
		M.impact.age = (M.impact.age or 0) + 1
		for _, ring in ipairs(M.impact.rings) do
			ring.age = (ring.age or 0) + 1
			local a = ring.age
			local spd = (a < 14) and 7.5 or (a < 30 and 4.5 or 2.2)
			ring.radius = (ring.radius or 8) + spd
		end
		for i = #M.impact.sprays, 1, -1 do
			local sp = M.impact.sprays[i]
			sp.age = (sp.age or 0) + 1
			sp.dist = (sp.dist or 0) + (sp.speed or 10)
			if sp.age > (sp.life or 20) then
				table.remove(M.impact.sprays, i)
			end
		end
		if tornado.is_active() then
			local a = M.impact.age
			if a < 6 then
				tornado.set_spread(0.15 + a * 0.05)
				tornado.set_growth(math.max(0.25, 1 - a * 0.08))
			elseif a < 30 then
				tornado.set_spread(math.min(1, 0.45 + (a - 6) * 0.04))
				tornado.set_growth(math.max(0.1, 0.7 - (a - 6) * 0.025))
			else
				tornado.set_growth(math.max(0, 0.35 - (a - 30) * 0.02))
			end
		end
	end

	local eye_center = (M.phase == "eye" and sess and sess.pos) or nil
	local eye_core = eye_center and eye_core_radius() or nil

	for i = #M.particles, 1, -1 do
		local p = M.particles[i]
		local remove = false
		if life.room_should_clear(p.sgid, desc.SafeGridIndex) then
			note_remove(p.layer, "room_change")
			remove = true
		elseif not layer_enabled(p.layer) then
			note_remove(p.layer, "layer_mask")
			remove = true
		else
			p.age = (p.age or 0) + 1
			local used_stream = false

			-- Eye analytical stream: O(1) advance + angle-limited visual samples.
			if p.stream and (M.phase or "") == "eye" and p.stage ~= STAGE.DISSOLVING then
				used_stream = true
				-- MOTES soft-life must NOT rewrite stream.u / stage (no teleport).
				-- Soft-life only marks exiting for TOP_EXIT after natural ascent.
				if p.layer == "motes" and (not p.exiting) and p.age >= (p.life or 90) then
					p.exiting = true
					p.life_state = "exiting"
					-- Slight continuous speed-up along the same path; never jump stages.
					p.speed = math.min((p.speed or 8) * 1.08, 14)
					if p.stream then p.stream.speed = p.speed end
				end
				local spd = p.speed or 8
				if p.layer == "gust" then spd = spd * 1.2 end
				local pos, tang, stg, samples = streamline.advance(p.stream, spd)
				p.pos = pos
				p.velocity = tang * spd
				local prev_mode = p.visual_mode
				local kept_streak = false
				if stg == streamline.STAGE.ASCENDING or stg == streamline.STAGE.TOP_EXIT then
					if p.column_visual == true and not column_renderable(p, view) then
						p._col_miss = (p._col_miss or 0) + 1
					else
						p._col_miss = 0
					end
					local already = p.column_visual == true and (p._col_miss or 0) == 0
					local slot_open = already or count_visible_column_slots(p.layer, view) < column_cap_for(p.layer)
					if (p._col_miss or 0) >= 8 or not slot_open then
						-- Keep the streak. Off-screen column holders must not consume the cap
						-- and then fade every inbound line.
						kept_streak = true
						p.visual_mode = "streak"
						p.column_visual = nil
						p.trail_fade = 1
						p._col_miss = 0
						clear_draw_stamps(p)
					else
						p.visual_mode = (stg == streamline.STAGE.TOP_EXIT) and "top_eject" or "column_arc"
						if prev_mode == "streak" or p.column_visual == nil then
							p.column_visual = true
						end
					end
				end
				if stg == streamline.STAGE.ASCENDING or stg == streamline.STAGE.TOP_EXIT then
					if kept_streak then
						-- Streak path below owns the trail.
					else
					p.column_samples = p.column_samples or {}
					if samples then
						for si = 1, #samples do
							local s = samples[si]
							local ni = #p.column_samples + 1
							local slot = p.column_samples[ni]
							if not slot then
								slot = {}
								p.column_samples[ni] = slot
							end
							slot.pos = Vector(s.pos.X, s.pos.Y)
							slot.tang = s.tang
						end
					else
						local ni = #p.column_samples + 1
						local slot = p.column_samples[ni]
						if not slot then
							slot = {}
							p.column_samples[ni] = slot
						end
						slot.pos = Vector(pos.X, pos.Y)
						slot.tang = tang
					end
					while #p.column_samples > 8 do table.remove(p.column_samples, 1) end
					-- Update-only geometry: build draw_stamps for Render.
					if p.column_visual ~= false then
						prepare_column_draw(p)
					else
						clear_draw_stamps(p)
						p.column_renderable = 0
					end
					local stamps = p.draw_stamps_n or 0
					if prev_mode == "streak" then
						p.trail_fade = math.min(p.trail_fade or 1, 0.92)
					end
					if p.column_visual == false then
						p.trail_fade = (p.trail_fade or 1) * 0.82
					elseif stamps >= 1 then
						p.trail_fade = (p.trail_fade or 1) * 0.88
						if p.trail and #p.trail > 3 then
							while #p.trail > 3 do table.remove(p.trail, 1) end
						end
					else
						p.trail_fade = math.max(p.trail_fade or 1, 0.7)
					end
					end
				else
					p.visual_mode = "streak"
					p.trail_fade = 1
					p.column_visual = nil
					p.column_renderable = 0
					clear_draw_stamps(p)
				end

				if p.layer == "motes" then
					if p.spin then p.Rotation = (p.Rotation or 0) + p.spin end
				else
					if p.stage == STAGE.GROWING and p.age >= (p.grow_frames or 7) then
						p.stage = STAGE.FLOWING
					end
					p.Rotation = rotation_of_vec(p.velocity)
					if p.visual_mode == "streak" then
						local trail = p.trail or {Vector(p.pos.X, p.pos.Y)}
						-- Prefer dense samples on spiral; never store a single huge jump.
						if samples and #samples > 0 then
							for si = 1, #samples do
								local sp = samples[si].pos
								local last = trail[#trail]
								if (not last) or (sp - last):LengthSquared() >= 2.25 then
									trail[#trail + 1] = Vector(sp.X, sp.Y)
								end
							end
						else
							trail[#trail + 1] = Vector(p.pos.X, p.pos.Y)
						end
						local maxn = p.trail_max or 7
						if p.stage == STAGE.GROWING then
							local allow = 2 + math.floor((p.age / math.max(1, p.grow_frames or 7)) * maxn)
							maxn = math.min(maxn, math.max(2, allow))
						end
						while #trail > maxn do table.remove(trail, 1) end
						p.trail = trail
					end
				end

				local in_view
				if p.layer == "motes" then
					in_view = emission.intersects_view(p.pos, half_m, view)
				elseif p.visual_mode ~= "streak" then
					in_view = particle_visible(p, view)
				else
					in_view = emission.any_point_visible(p.trail, half_t, view)
				end
				local outside_sim
				if p.layer == "motes" then
					outside_sim = emission.bbox_fully_outside(p.pos, half_m, sim)
				elseif p.visual_mode ~= "streak" then
					outside_sim = (not particle_visible(p, sim))
						and (not p.trail or emission.trail_draw_fully_outside(p.trail, half_t, sim))
				else
					outside_sim = emission.trail_draw_fully_outside(p.trail, half_t, sim)
				end
				p.life_state = p.life_state or (p.was_visible and "visible" or "incoming")
				if in_view and not p.was_visible then
					p.was_visible = true
					p.life_state = "visible"
					metric_inc("entered_view")
					metric_inc("entered_visible")
					if p.edge ~= nil and M.metrics.edge_by_side[p.edge] then
						M.metrics.edge_by_side[p.edge].entered_view =
							(M.metrics.edge_by_side[p.edge].entered_view or 0) + 1
					end
				elseif in_view then
					M.metrics.visible_now = (M.metrics.visible_now or 0) + 1
					if p.exiting then p.life_state = "exiting" end
				end
				if stg == streamline.STAGE.ASCENDING or stg == streamline.STAGE.SPIRAL then
					if not p.reached_cyclone then
						p.reached_cyclone = true
						if p.edge ~= nil and M.metrics.edge_by_side[p.edge] then
							M.metrics.edge_by_side[p.edge].reached_cyclone =
								(M.metrics.edge_by_side[p.edge].reached_cyclone or 0) + 1
						end
					end
				end
				if stg == streamline.STAGE.ASCENDING and not p.in_column then
					p.in_column = true
					metric_inc("absorbed_into_column")
					if p.edge ~= nil and M.metrics.edge_by_side[p.edge] then
						M.metrics.edge_by_side[p.edge].captured_by_column =
							(M.metrics.edge_by_side[p.edge].captured_by_column or 0) + 1
					end
				end
				if outside_sim and (stg == streamline.STAGE.TOP_EXIT or stg == streamline.STAGE.DONE or p.was_visible) then
					metric_inc("natural_exit")
					if p.was_visible then metric_inc("exited_visible") end
					if p.edge ~= nil and M.metrics.edge_by_side[p.edge] then
						M.metrics.edge_by_side[p.edge].recycled =
							(M.metrics.edge_by_side[p.edge].recycled or 0) + 1
					end
					note_remove(p.layer, p.was_visible and "natural_exit" or "outside_before_visible")
					remove = true
				elseif p.age > HARD_MAX_AGE then
					-- Continuous timeout: accelerate along path; never teleport stage.
					p.speed = math.min((p.speed or 8) * 1.12, 16)
					if p.stream then p.stream.speed = p.speed end
					p.exiting = true
				end
			end

			if not used_stream then
			local opts = flow_opts(sess, intensity, p.seed, p.speed or 8, p.layer)
			local v = flow.sample_flow(p.pos, sess, time, opts)

			if p.layer == "motes" then
				if not p.exiting and p.age >= (p.life or 60) then
					p.exiting = true
					if p.life_state == "visible" then
						p.life_state = "exiting"
					end
				end
				local target
				if p.exiting then
					target = steer_exit(p, sess, intensity)
					p.velocity = blend_vel(p.velocity, target, 0.42)
				else
					target = v
					p.velocity = blend_vel(p.velocity, target, 0.18)
				end
				p.pos = p.pos + p.velocity
				apply_eye_climb(p, sess, intensity)
				if p.spin then p.Rotation = (p.Rotation or 0) + p.spin end

				local in_view = emission.intersects_view(p.pos, half_m, view)
				local outside_sim = emission.bbox_fully_outside(p.pos, half_m, sim)
				p.life_state = p.life_state or (p.was_visible and "visible" or "incoming")

				if p.life_state == "incoming" then
					if in_view then
						p.life_state = "visible"
						p.was_visible = true
						metric_inc("entered_view")
						metric_inc("entered_visible")
						if p.edge ~= nil and M.metrics.edge_by_side[p.edge] then
							M.metrics.edge_by_side[p.edge].entered_view =
								(M.metrics.edge_by_side[p.edge].entered_view or 0) + 1
						end
					elseif life.incoming_expired(p, ENTRY_TIMEOUT) then
						p.incoming_valid = false
						metric_inc("entry_timeout")
						if M.metrics.by_layer and M.metrics.by_layer.motes then
							M.metrics.by_layer.motes.incoming_failed =
								(M.metrics.by_layer.motes.incoming_failed or 0) + 1
						end
						note_remove("motes", outside_sim and "outside_before_visible" or "entry_timeout")
						remove = true
					end
				elseif p.life_state == "visible" or p.life_state == "exiting" then
					if in_view then
						M.metrics.visible_now = (M.metrics.visible_now or 0) + 1
					end
					if p.exiting then
						p.life_state = "exiting"
					end
					if life.mote_decision(p, outside_sim, in_view, ENTRY_TIMEOUT) == "natural_exit" then
						metric_inc("natural_exit")
						metric_inc("exited_visible")
						if p.edge ~= nil and M.metrics.edge_by_side[p.edge] then
							M.metrics.edge_by_side[p.edge].recycled =
								(M.metrics.edge_by_side[p.edge].recycled or 0) + 1
						end
						note_remove("motes", "natural_exit")
						remove = true
					end
				end

				if not remove and eye_center and not p.in_column then
					local rr = (p.pos - eye_center):Length()
					if rr < eye_core * 0.9 then
						p.in_column = true
						metric_inc("absorbed_into_column")
						if p.edge ~= nil and M.metrics.edge_by_side[p.edge] then
							M.metrics.edge_by_side[p.edge].captured_by_column =
								(M.metrics.edge_by_side[p.edge].captured_by_column or 0) + 1
						end
					end
				end

				if not remove and p.age > HARD_MAX_AGE then
					p.exiting = true
					p.life_state = "exiting"
					p.velocity = blend_vel(p.velocity, steer_exit(p, sess, intensity), 0.55)
					p.pos = p.pos + p.velocity * 1.4
					if emission.bbox_fully_outside(p.pos, half_m, sim) then
						metric_inc("natural_exit")
						if p.was_visible then metric_inc("exited_visible") end
						note_remove("motes", p.was_visible and "natural_exit" or "outside_before_visible")
						remove = true
					end
				end
			else
				if p.stage == STAGE.GROWING and p.age >= (p.grow_frames or 7) then
					p.stage = STAGE.FLOWING
				end

				if p.stage == STAGE.DISSOLVING then
					local target = steer_exit(p, sess, intensity)
					p.velocity = blend_vel(p.velocity, target, 0.5)
					p.pos = p.pos + p.velocity
					p.dissolve_age = (p.dissolve_age or 0) + 1
					if p.trail and #p.trail > 0 and (p.dissolve_age % 2 == 0) then
						table.remove(p.trail, 1)
					end
					if p.trail then
						for ti = 1, #p.trail do
							p.trail[ti] = p.trail[ti] + p.velocity * 0.9
						end
					end
					if emission.trail_draw_fully_outside(p.trail, half_t, rect)
						or (not p.trail or #p.trail < 1)
					then
						note_remove(p.layer, "dissolve")
						remove = true
					end
				else
					if p.exiting then
						v = steer_exit(p, sess, intensity)
					end
					p.velocity = v
					p.pos = p.pos + v
					apply_eye_climb(p, sess, intensity)
					p.Rotation = rotation_of_vec(p.velocity)

					local trail = p.trail or {Vector(p.pos.X, p.pos.Y)}
					trail[#trail + 1] = Vector(p.pos.X, p.pos.Y)
					local maxn = p.trail_max or 7
					if p.stage == STAGE.GROWING then
						local allow = 2 + math.floor((p.age / math.max(1, p.grow_frames or 7)) * maxn)
						maxn = math.min(maxn, math.max(2, allow))
					end
					while #trail > maxn do table.remove(trail, 1) end
					p.trail = trail

					local vis_now = emission.any_point_visible(p.trail, half_t, view)
					local outside_sim = emission.trail_draw_fully_outside(p.trail, half_t, sim)
					p.life_state = p.life_state or "incoming"
					if vis_now and not p.was_visible then
						p.was_visible = true
						p.life_state = "visible"
						metric_inc("entered_view")
						metric_inc("entered_visible")
						if p.edge ~= nil and M.metrics.edge_by_side[p.edge] then
							M.metrics.edge_by_side[p.edge].entered_view =
								(M.metrics.edge_by_side[p.edge].entered_view or 0) + 1
						end
					elseif vis_now then
						M.metrics.visible_now = (M.metrics.visible_now or 0) + 1
						p.life_state = p.exiting and "exiting" or "visible"
					elseif life.incoming_expired(p, ENTRY_TIMEOUT) then
						p.incoming_valid = false
						metric_inc("entry_timeout")
						local bl = M.metrics.by_layer and M.metrics.by_layer[p.layer]
						if bl then bl.incoming_failed = (bl.incoming_failed or 0) + 1 end
						note_remove(p.layer, outside_sim and "outside_before_visible" or "entry_timeout")
						remove = true
					end
					if not remove and eye_center then
						local rr = (p.pos - eye_center):Length()
						if not p.reached_cyclone and rr < eye_core * 1.85 then
							p.reached_cyclone = true
							if p.edge ~= nil and M.metrics.edge_by_side[p.edge] then
								M.metrics.edge_by_side[p.edge].reached_cyclone =
									(M.metrics.edge_by_side[p.edge].reached_cyclone or 0) + 1
							end
						end
						if not p.in_column and rr < eye_core * 0.9 then
							p.in_column = true
							metric_inc("absorbed_into_column")
							if p.edge ~= nil and M.metrics.edge_by_side[p.edge] then
								M.metrics.edge_by_side[p.edge].captured_by_column =
									(M.metrics.edge_by_side[p.edge].captured_by_column or 0) + 1
							end
						end
					end

					if not remove and outside_sim
						and life.streak_outside_decision(p, true, ENTRY_TIMEOUT) == "natural_exit"
					then
						metric_inc("natural_exit")
						metric_inc("exited_visible")
						if p.edge ~= nil and M.metrics.edge_by_side[p.edge] then
							M.metrics.edge_by_side[p.edge].recycled =
								(M.metrics.edge_by_side[p.edge].recycled or 0) + 1
						end
						note_remove(p.layer, "natural_exit")
						remove = true
					elseif not remove and p.age > HARD_MAX_AGE then
						p.exiting = true
						p.life_state = "exiting"
					end
				end
			end
			end -- not used_stream

		end
		if remove then
			table.remove(M.particles, i)
		end
	end

	-- End-of-frame census (one scan) → density ring + emit readers next frame.
	local layers = refresh_census_cache(emission.screen_view_rect(), true)
	local air = layers.airflow
	local motes_c = layers.motes
	if M.metrics then
		M.metrics.inbound_visible = air.inbound_visible
		M.metrics.inbound_incoming = air.inbound_incoming
		M.metrics.column_visible = air.column_visible
		M.metrics.column_renderable_segments = air.column_renderable
		M.metrics.top_eject_visible = air.top_eject
		M.metrics.motes_visible = motes_c.visible
		M.metrics.total_particles = #M.particles
		M.metrics.inbound_particles = air.inbound_total
		M.metrics.column_particles = air.column_total
	end
	M._density_ring = M._density_ring or {i = 0, n = 0, buf = {}}
	local ring = M._density_ring
	ring.i = (ring.i % DENSITY_CAP) + 1
	local slot = ring.buf[ring.i]
	if not slot then
		slot = {}
		ring.buf[ring.i] = slot
		if M.metrics then
			M.metrics.temporary_table_allocations = (M.metrics.temporary_table_allocations or 0) + 1
		end
	end
	slot.t = time
	slot.air_v = air.inbound_visible
	slot.air_i = air.inbound_incoming
	slot.air_e = air.exiting
	slot.air_n = air.total
	slot.air_col = air.column_visible
	slot.air_col_seg = air.column_renderable
	slot.air_col_vis = air.column_visual
	slot.motes = motes_c.visible
	if ring.n < DENSITY_CAP then ring.n = ring.n + 1 end
	-- Legacy alias for get_density_log consumers.
	M._density_log = ring.buf

	local visible_now = (air.inbound_visible or 0) + (air.column_visible or 0)
	if not layer_enabled("airflow") then
		M._blank_frames = (M._blank_frames or 0) + 1
		M._blank_reason = "layer_masked"
	elseif intensity > 0.2 and visible_now <= 0 then
		M._blank_frames = (M._blank_frames or 0) + 1
		if M._blank_frames >= 45 then
			local reason = "transparent_or_offscreen"
			if (air.total or 0) <= 0 then
				reason = "spawn_starved"
			elseif (air.column_total or 0) > 0 and (air.column_renderable or 0) <= 0 then
				reason = "column_geometry"
			elseif (air.inbound_total or 0) > 0 then
				reason = "offscreen"
			end
			M._blank_reason = reason
		end
	else
		M._blank_frames = 0
		M._blank_reason = nil
	end
	if M.metrics then
		M.metrics.blank_frames = M._blank_frames or 0
		M.metrics.blank_reason = M._blank_reason
	end

	if tornado.is_active() then
		if sess and sess.pos and M.phase ~= "impact" then
			tornado.set_center(sess.pos)
		elseif M.impact then
			tornado.set_center(M.impact.center)
		end
		tornado.set_intensity(intensity)
		tornado.update()
	end

	if M.metrics then
		M.metrics.update_time_ms = ns_to_ms(now_ns() - t0)
		-- Sample GC sparsely (avoid measuring collectgarbage every frame).
		if (time % 30) == 0 and collectgarbage then
			M.metrics.gc_kb = collectgarbage("count")
		end
	end
end

local function draw_sprite(spr, anim, pos, rotation, scale, color)
	if not pos then return false end
	local ok = pcall(function()
		spr:Play(anim, true)
		spr:SetFrame(anim, 0)
		spr.Rotation = rotation or 0
		spr.Scale = scale or Vector(1, 1)
		spr.Color = color or Color(1, 1, 1, 0.45)
		spr:Render(Isaac.WorldToScreen(pos), Vector(0, 0), Vector(0, 0))
	end)
	return ok == true
end

local function intro_mul()
	local f = M.intro_fade or 0
	if f <= 0 then return 1 end
	return clamp01(1 - f / 8)
end

local function segment_alpha(p, seg_index, seg_count, edge_a)
	local base = (p.Color and p.Color.A) or 0.4
	if M.force_white then return 1 end
	local along = seg_index / math.max(1, seg_count) -- 0 tail … 1 tip
	local im = intro_mul()
	local len_a = 0.40 + 0.60 * along -- tip brighter; tail softer
	edge_a = edge_a or 1
	if p.stage == STAGE.GROWING then
		local g = clamp01((p.age or 0) / math.max(1, p.grow_frames or 7))
		return base * g * len_a * im * edge_a
	end
	if p.stage == STAGE.DISSOLVING then
		local d = 1 - clamp01((p.dissolve_age or 0) / math.max(1, p.dissolve_frames or 14))
		return base * d * len_a * im * edge_a
	end
	return base * len_a * im * edge_a
end

local function segment_thickness(seg_index, seg_count, base_sy)
	local along = seg_index / math.max(1, seg_count)
	-- Tail thin → tip full; avoids rigid constant-width bars.
	return (base_sy or 0.9) * (0.55 + 0.50 * along)
end

function M.render()
	local t0 = now_ns()
	local attempts, draws = 0, 0
	local spr = ensure_v63()
	local mote = ensure_mote()
	local im = intro_mul()

	-- When storm_encounter composes Zennith between layers, skip here.
	if layer_enabled("tornado") and tornado.is_active() and not tornado.external_compose then
		local tr = tornado.render()
		attempts = attempts + (tr.attempts or 0)
		draws = draws + (tr.draws or 0)
	end

	if M.impact then
		local ic = M.impact.center
		for _, ring in ipairs(M.impact.rings) do
			local a = ring.age or 0
			local fade = 1
			if a > 30 then fade = math.max(0, 1 - (a - 30) / 18) end
			if a < 6 then fade = a / 6 end
			local rad = ring.radius or 20
			local pos = ic + auxi.MakeVector(ring.ang) * rad
			local tang = auxi.MakeVector(ring.ang + 90)
			attempts = attempts + 1
			if draw_sprite(
				spr, ring.anim or "IRing1", pos, tang:GetAngleDegrees(),
				Vector(1.2 + rad * 0.004, 1.0),
				storm_color((0.45 + 0.2 * fade) * fade * im, "impact")
			) then draws = draws + 1 end
			if a > 8 and a < 36 then
				attempts = attempts + 1
				if draw_sprite(
					spr, ring.arc_anim or "IArc1", pos + tang * 6, tang:GetAngleDegrees(),
					Vector(1.0, 0.95),
					storm_color(0.35 * fade * im, "impact")
				) then draws = draws + 1 end
			end
		end
		for _, sp in ipairs(M.impact.sprays) do
			local fade = 1 - clamp01((sp.age or 0) / math.max(1, sp.life or 20))
			local pos = ic + auxi.MakeVector(sp.ang) * (sp.dist or 10)
			attempts = attempts + 1
			if draw_sprite(
				spr, sp.anim or "ISpray1", pos, sp.ang,
				Vector(0.9, 0.85),
				storm_color((sp.alpha or 0.5) * fade * im, "impact")
			) then draws = draws + 1 end
		end
	end

	-- Fade uses real rendered viewport — never room-only playfield masquerading as screen.
	local fade_rect = emission.screen_view_rect()
	local fade_blow = M._fade_blow or Vector(0, 1)

	local colspr = ensure_v66()
	local rendered_inbound = 0
	local rendered_column = 0

	for i = 1, #M.particles do
		local v = M.particles[i]
		if not layer_enabled(v.layer) then
			-- skip
		elseif v.layer == "motes" then
			-- MOTES: no edge_fade. Keep authored alpha (+ optional intro / brief birth fade-in).
			local a = (v.Color and v.Color.A) or 0.7
			if not M.force_white then
				if v.age < 2 and not (M.intro_fade and M.intro_fade > 0) then
					a = a * (v.age / 2)
				end
				a = a * im
			else
				a = 1
			end
			attempts = attempts + 1
			if draw_sprite(mote, v.anim or "Particle001", v.pos, v.Rotation, v.Scale, Color(1, 1, 1, a)) then
				draws = draws + 1
			end
		else
			local blow = (M.phase == "eye") and safe_norm(v.velocity) or fade_blow
			local mode = v.visual_mode or "streak"
			local col = v.Color or Color(1, 1, 1, 0.4)

			-- Residual outer streak during handoff (fading; never long column chords).
			local trail = v.trail
			local trail_a_mul = (mode == "streak") and 1 or (v.trail_fade or 0)
			if trail and #trail >= 2 and trail_a_mul > 0.04 then
				local n = #trail
				for s = 1, n - 1 do
					local apos, bpos = trail[s], trail[s + 1]
					local delta = bpos - apos
					local dist = delta:Length()
					local max_chord = (mode == "streak") and 1e9 or (MAX_COLUMN_SEG_LEN + 8)
					if dist >= 3.0 and dist <= max_chord then
						local mid = (apos + bpos) * 0.5
						local rot = rotation_of_vec(delta)
						local sx = math.min(1.25, dist / math.max(10, TEX_W * 0.5))
						local sy = segment_thickness(s, n - 1, (v.Scale and v.Scale.Y) or 0.9)
						local anim = v.body_anim or "Body1"
						if s == n - 1 then anim = v.tip_anim or "Tip1" end
						if s == 1 then anim = v.tail_anim or "Tail1" end
						local edge_a = emission.edge_fade_alpha(mid, blow, fade_rect)
						local a = segment_alpha(v, s, n - 1, edge_a) * trail_a_mul
						if a >= 0.02 then
							attempts = attempts + 1
							_scale_tmp.X = sx
							_scale_tmp.Y = sy
							if draw_sprite(spr, anim, mid, rot, _scale_tmp, Color(col.R, col.G, col.B, a)) then
								draws = draws + 1
								if mode == "streak" then
									rendered_inbound = rendered_inbound + 1
								end
							end
						end
					end
				end
			end

			-- Column: consume Update-prepared draw_stamps only (no geometry / state mutation).
			if (mode == "column_arc" or mode == "top_eject") and v.column_visual ~= false then
				local stamps = v.draw_stamps
				local sn = v.draw_stamps_n or (stamps and #stamps) or 0
				local base_a = (col.A or 0.4) * im * ((mode == "top_eject") and 0.7 or 0.85)
				for si = 1, sn do
					local st = stamps[si]
					if st and st.mid then
						local along = si / math.max(1, sn)
						local a = base_a * (0.45 + 0.55 * along)
						if M.force_white then a = 1 end
						if a >= 0.02 then
							attempts = attempts + 1
							if mode == "top_eject" then
								_scale_tmp.X = st.sx * 0.85
								_scale_tmp.Y = st.sy
								if draw_sprite(
									spr, "IArc" .. tostring(1 + ((si - 1) % 4)),
									st.mid, st.rot, _scale_tmp,
									Color(col.R, col.G, col.B, a * 0.75)
								) then
									draws = draws + 1
									rendered_column = rendered_column + 1
								end
							else
								_scale_tmp.X = st.sx
								_scale_tmp.Y = st.sy
								if draw_sprite(
									colspr, "Spiral" .. tostring(1 + ((si - 1) % 4)),
									st.mid, st.rot, _scale_tmp,
									Color(col.R, col.G, col.B, a)
								) then
									draws = draws + 1
									rendered_column = rendered_column + 1
								end
							end
						end
					end
				end
			end
		end
	end

	spr.Color = Color(1, 1, 1, 1)
	spr.Scale = Vector(1, 1)
	colspr.Color = Color(1, 1, 1, 1)
	colspr.Scale = Vector(1, 1)
	mote.Color = Color(1, 1, 1, 1)

	if not M.metrics then reset_metrics() end
	M.metrics.rendered_inbound_segments = rendered_inbound
	M.metrics.rendered_column_stamps = rendered_column
	M.metrics.render_sprite_attempts = attempts
	M.metrics.render_sprite_success = draws
	M.metrics.render_time_ms = ns_to_ms(now_ns() - t0)

	-- Lightweight starvation / handoff diagnostics (uses cached census; no extra full scan unless forced).
	if (M.phase or "") == "eye" then
		if rendered_inbound <= 0 then
			M._inbound_blank_frames = (M._inbound_blank_frames or 0) + 1
		else
			M._inbound_blank_frames = 0
			if M.metrics.diag == "AIRFLOW_BUDGET_STARVATION"
				or M.metrics.diag == "AIRFLOW_EMITTER_INACTIVE"
				or M.metrics.diag == "AIRFLOW_ENTRY_FAILURE"
			then
				M.metrics.diag = nil
				M.metrics.diag_frames = 0
			end
		end
		if (M._inbound_blank_frames or 0) >= INBOUND_BLANK_ALARM then
			local air = layer_census("airflow", fade_rect)
			local reason
			if (M.metrics.emit_attempt or 0) <= 0 then
				reason = "AIRFLOW_EMITTER_INACTIVE"
			elseif (M.metrics.emit_blocked_budget or 0) > (M.metrics.emit_success or 0)
				and air.inbound_active >= target_visible("airflow", 0.7, "eye") * 0.9
				and air.column_total > air.inbound_total
			then
				reason = "AIRFLOW_BUDGET_STARVATION"
			elseif air.column_total > 0 and rendered_column <= 0 and rendered_inbound <= 0 then
				reason = "COLUMN_RENDER_HANDOFF_FAILURE"
			elseif (M.metrics.emit_success or 0) > 0 and (M.metrics.entered_view or 0) <= 0 then
				reason = "AIRFLOW_ENTRY_FAILURE"
			elseif air.inbound_active > 0 and rendered_inbound <= 0 then
				reason = "COLUMN_RENDER_HANDOFF_FAILURE"
			else
				reason = "AIRFLOW_BUDGET_STARVATION"
			end
			M.metrics.diag = reason
			M.metrics.diag_frames = M._inbound_blank_frames
		end
	else
		M._inbound_blank_frames = 0
	end

	local cover = M.cover_alpha or 0
	if cover > 0.02 then
		local _, _, c = room_bounds()
		for i = 1, 4 do
			attempts = attempts + 1
			if draw_sprite(
				spr, "Body" .. tostring(1 + ((i - 1) % BODY_N)),
				c + Vector((i - 2.5) * 30, ((i % 2) * 2 - 1) * 18),
				(i * 40 + Game():GetFrameCount()) % 360,
				Vector(1.5, 1.1),
				Color(0.88, 0.86, 0.94, cover * (0.1 + 0.05 * (i % 3)) * im)
			) then draws = draws + 1 end
		end
	end
	return {
		sprite_attempts = attempts,
		sprite_draws = draws,
		rendered_inbound_segments = rendered_inbound,
		rendered_column_stamps = rendered_column,
		diag = M.metrics and M.metrics.diag or nil,
	}
end

function M.get_stats()
	local rect = emission.screen_view_rect()
	local counts = {}
	local sources = {}
	local stages = {}
	local layers = refresh_census_cache(rect, false)
	for _, layer in ipairs({"airflow", "gust", "motes"}) do
		if M.metrics and M.metrics.by_layer and M.metrics.by_layer[layer] and layers[layer] then
			local bl = M.metrics.by_layer[layer]
			bl.visible = layers[layer].visible
			bl.incoming_valid = layers[layer].incoming_valid
			bl.exiting = layers[layer].exiting
			bl.inbound_active = layers[layer].inbound_active
			bl.column_total = layers[layer].column_total
		end
	end
	for _, p in ipairs(M.particles) do
		counts[p.layer or "?"] = (counts[p.layer or "?"] or 0) + 1
		stages[p.stage or "?"] = (stages[p.stage or "?"] or 0) + 1
		sources[p.source or "?"] = (sources[p.source or "?"] or 0) + 1
	end
	counts.tornado = tornado.is_active() and 1 or 0
	counts.eye_ring = counts.tornado

	local dens = nil
	local ring = M._density_ring
	if ring and ring.n and ring.n > 0 then
		local sum_v, n = 0, ring.n
		local min_v, max_v = 1e9, 0
		for i = 1, n do
			local e = ring.buf[i]
			local v = (e and e.air_v) or 0
			sum_v = sum_v + v
			if v < min_v then min_v = v end
			if v > max_v then max_v = v end
		end
		dens = {
			samples = n,
			air_visible_avg = sum_v / n,
			air_visible_min = min_v,
			air_visible_max = max_v,
		}
	end

	return {
		total = #M.particles,
		counts = counts,
		stages = stages,
		sources = sources,
		layers = layers,
		density = dens,
		metrics = M.metrics,
		diag = M.metrics and M.metrics.diag or nil,
		perf = M.metrics and {
			update_time_ms = M.metrics.update_time_ms,
			render_time_ms = M.metrics.render_time_ms,
			render_sprite_attempts = M.metrics.render_sprite_attempts,
			render_sprite_success = M.metrics.render_sprite_success,
			column_geometry_builds = M.metrics.column_geometry_builds,
			census_calls = M.metrics.census_calls,
			gc_kb = M.metrics.gc_kb,
			rendered_inbound_segments = M.metrics.rendered_inbound_segments,
			rendered_column_stamps = M.metrics.rendered_column_stamps,
		} or nil,
		phase = M.phase,
		layer_mask = M.layer_mask,
		tornado_active = tornado.is_active(),
		impact_age = M.impact and M.impact.age or nil,
		eye_radius_scale = M.eye_radius_scale,
		cover_alpha = M.cover_alpha,
		blank_frames = M._blank_frames or 0,
		blank_reason = M._blank_reason,
		force_white = M.force_white == true,
		intro_fade = M.intro_fade,
		particle_reset_count = M.particle_reset_count,
		last_reset_reason = M.last_reset_reason,
		last_prefill = M.last_prefill,
		room_trace = M.room_trace and table.concat(M.room_trace, ",") or "",
		tornado_growth = tornado.growth,
		mote_pool = particle_frames.COUNT,
	}
end

function M.get_density_log()
	local ring = M._density_ring
	if not ring or not ring.n or ring.n <= 0 then
		return M._density_log
	end
	-- Chronological view without shifting the ring.
	local out = {}
	local start = (ring.n < DENSITY_CAP) and 1 or (ring.i % DENSITY_CAP) + 1
	for k = 0, ring.n - 1 do
		local idx = ((start + k - 1) % DENSITY_CAP) + 1
		out[k + 1] = ring.buf[idx]
	end
	return out
end

function M.get_metrics()
	return M.metrics
end

return M
