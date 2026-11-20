-- World-space emission history. Old fire stays where it was born.
-- New samples start at the current mouth. Render does not move this table.

local geom = require("Qing_Remaster_scripts.items.incandescence_flame.flame_geometry")

local stream = {}

function stream.clear(state)
	state.stream = {}
	state.branches = {}
	state.pending_events = {}
	state.fade_cut = 0
	state.stream_peak = 0
	state.stream_discontinuity_count = 0
	state.segments = {}
	state.active_segment_id = nil
	state.segment_serial = 0
	state.front_pin = nil
	state.segment_created_total = 0
	state.segment_finished_total = 0
	state.direction_break_count = 0
	state.position_break_count = 0
	state.geometry_break_count = 0
	state.piece_serial = 0
	state.piece_stats = nil
	state.piece_rows = nil
	state.removed_by_distance = 0
	state.removed_by_temperature = 0
	state.removed_by_age = 0
	state.removed_by_budget = 0
	state.removed_by_distance_total = 0
	state.removed_by_temperature_total = 0
	state.removed_by_age_total = 0
	state.removed_by_budget_total = 0
	state.coasting_frames = 0
	state.dissipating_frames = 0
	state.watch_length_at_close = 0
	state.watch_length_now = 0
	state.watch_width_at_close = 0
	state.watch_width_now = 0
	state.watch_phase = nil
	state.segment_rows = nil
	state.segment_log = nil
	state.removed_by_hard_cap = 0
	state.removed_by_hard_cap_total = 0
	state.hard_cap_trips = 0
	state.hard_cap_trips_total = 0
	state.removed_by_residual = 0
	state.removed_by_residual_total = 0
	state.lod_transition_count = 0
	state.lod_transition_total = 0
	state.lod_counts = nil
	state.lod_area_ratio = 1
	state.lod_component_count = 0
end

local COS_45 = math.cos(math.rad(45))
local COS_EPS = 1e-4

local function unit_dot(ax, ay, bx, by)
	local al = math.sqrt(ax * ax + ay * ay)
	local bl = math.sqrt(bx * bx + by * by)
	if al < 0.0001 or bl < 0.0001 then
		return 1
	end
	local d = (ax * bx + ay * by) / (al * bl)
	if d > 1 then d = 1 end
	if d < -1 then d = -1 end
	return d
end

local function segment_extent(state, id, mouth)
	if not id or not mouth then
		return 0
	end
	local max_d = 0
	local mx = mouth.x or 0
	local my = mouth.y or 0
	local list = state.stream or {}
	for i = 1, #list do
		local slice = list[i]
		if slice.segment_id == id and slice.x then
			local dx = slice.x - mx
			local dy = slice.y - my
			local dist = math.sqrt(dx * dx + dy * dy)
			if dist > max_d then
				max_d = dist
			end
		end
	end
	return max_d
end

local function retire_segments(state, list)
	local alive = {}
	for i = 1, #list do
		local id = list[i].segment_id
		if id then
			alive[id] = true
		end
	end
	local pins = state.front_pin
	local segs = state.segments or {}
	for id, _ in pairs(segs) do
		if not alive[id] then
			local finished = segs[id]
			state.segment_log = state.segment_log or {}
			local log = state.segment_log
			log[#log + 1] = {
				segment_id = id,
				end_reason = finished and finished.end_reason or "cooled",
				phase = finished and finished.phase or "",
				mature = finished and finished.mature == true,
				removed_budget = finished and finished.removed_budget or 0,
			}
			while #log > 8 do
				table.remove(log, 1)
			end
			segs[id] = nil
			state.segment_finished_total = (state.segment_finished_total or 0) + 1
			if pins then
				if pins.hold then
					pins.hold[id] = nil
				end
				if pins.layers then
					pins.layers[id] = nil
				end
			end
		end
	end
	local stale = 0
	if pins and pins.layers then
		for id, _ in pairs(pins.layers) do
			if not alive[id] then
				if type(id) == "number" then
					stale = stale + 1
				end
				pins.layers[id] = nil
				if pins.hold then
					pins.hold[id] = nil
				end
			end
		end
	end
	state.stale_front_memory_count = stale
end

local function release_busy(state)
	local n = 0
	local now = state.time or 0
	local segs = state.segments or {}
	for _, seg in pairs(segs) do
		local rel = seg.release
		if rel and (rel.budget or 0) > (rel.spawned or 0) then
			local age = now - (rel.start_frame or 0)
			if age >= 0 and age <= (rel.duration or 0) then
				n = n + 1
			end
		end
	end
	return n
end

local function arm_release(state, seg, reason, source_id, dot)
	if not seg or reason == "birth" or seg.release then
		return
	end
	local budget, duration = 2, 6
	if reason == "position" then
		budget, duration = 0, 0
	elseif reason == "direction" then
		if (dot or 1) < -0.3 then
			budget, duration = 4, 5
		else
			budget, duration = 3, 6
		end
	elseif reason == "geometry" then
		budget, duration = 3, 5
	elseif reason == "stop" then
		budget, duration = 4, 8
	else
		budget, duration = 0, 0
	end
	if budget > 0 and release_busy(state) >= 3 then
		budget = 0
	end
	seg.release = {
		start_frame = state.time or 0,
		reason = reason,
		duration = duration,
		source_slice_id = source_id,
		budget = budget,
		spawned = 0,
	}
	seg.closed_reason = reason
end

local function newest_slice_id(state, id)
	local list = state.stream or {}
	for i = #list, 1, -1 do
		if list[i].segment_id == id then
			return list[i].id
		end
	end
	return nil
end

local function span_of(pts)
	local arc = 0
	local width = 0
	for i = 1, #pts do
		local slice = pts[i]
		width = width + (slice.ru or 0) + (slice.rl or 0)
		if i > 1 then
			local dx = slice.x - pts[i - 1].x
			local dy = slice.y - pts[i - 1].y
			arc = arc + math.sqrt(dx * dx + dy * dy)
		end
	end
	local n = #pts
	local mean = n > 0 and (width / n) or 0
	local aspect = mean > 1 and (arc / mean) or 0
	return n, arc, mean, aspect
end

local function segment_points(state, id)
	local pts = {}
	local list = state.stream or {}
	for i = 1, #list do
		if list[i].segment_id == id then
			pts[#pts + 1] = list[i]
		end
	end
	return pts
end

local function segment_span(state, id)
	return span_of(segment_points(state, id))
end

local function close_segment(state, seg, reason, source_id, dot, owned)
	if not seg or seg.emission_closed then
		return
	end
	local pts = owned or segment_points(state, seg.id)
	local n, arc, mean, aspect = span_of(pts)
	local function lock_release_s()
		if #pts == 0 then
			seg.release_ready = true
			return
		end
		pts[#pts].release_s = 0
		pts[#pts].from_rear = 0
		pts[#pts].arc_s = 0
		local acc = 0
		for k = #pts, 2, -1 do
			local dx = (pts[k - 1].x or 0) - (pts[k].x or 0)
			local dy = (pts[k - 1].y or 0) - (pts[k].y or 0)
			acc = acc + math.sqrt(dx * dx + dy * dy)
			pts[k - 1].release_s = acc
			pts[k - 1].from_rear = acc
			pts[k - 1].arc_s = acc
		end
		seg.length_axis = acc
		seg.release_ready = true
	end
	lock_release_s()
	seg.emission_closed = true
	seg.stop_frame = state.time or 0
	seg.length_now = arc
	seg.length_at_close = arc
	seg.width_at_close = mean
	seg.slice_count_at_close = n
	seg.mature = aspect > 1.5 or n >= 8
	seg.removed_distance = 0
	seg.removed_temperature = 0
	seg.removed_age = 0
	seg.removed_budget = 0
	seg.dissipate_front = 0
	seg.cooling_front_s = 0
	seg.cooling_speed = 8
	seg.wave_time = state.time or 0
	seg.arc_locked = true
	if #pts > 0 then
		local marks = {}
		local npts = #pts
		local picks = { npts, math.floor(npts * 0.75 + 0.5), math.floor(npts * 0.5 + 0.5), math.floor(npts * 0.25 + 0.5), 1 }
		for i = 1, #picks do
			local index = picks[i]
			if index < 1 then
				index = 1
			elseif index > npts then
				index = npts
			end
			local slice = pts[index]
			marks[i] = {
				id = slice.id,
				arc_s = slice.arc_s or 0,
				x = slice.x or 0,
				y = slice.y or 0,
				temp = slice.temperature or 0,
			}
		end
		seg.cooling_samples = marks
	end
	seg.slice_visual = seg.slice_visual or {}
	for i = 1, #pts do
		local slice = pts[i]
		if not slice.residual_visual then
			local env_u = slice.ru or 4
			local env_l = slice.rl or 4
			if env_u < 1.2 then
				env_u = 1.2
			end
			if env_l < 1.2 then
				env_l = 1.2
			end
			local visual = {
				envelope_u = env_u,
				envelope_l = env_l,
				strength = 1,
				release_frame = state.time or 0,
			}
			slice.residual_visual = visual
			seg.slice_visual[slice.id] = visual
		end
		slice.temperature_at_stop = slice.temperature or slice.heat or 1
	end
	local birth = "stream"
	if aspect <= 0.7 or n <= 3 then
		birth = "short"
	elseif aspect <= 1.5 and n < 8 then
		birth = "blob"
	end
	seg.birth_class = birth
	seg.mature = birth == "stream" or n >= 8
	seg.residual = seg.mature and 0.9 or 0.62
	if seg.mature then
		seg.phase = "coasting"
	else
		seg.phase = "dissipating"
		seg.dissipate_frame = state.time or 0
	end
	arm_release(state, seg, reason, source_id, dot)
end

local function dot_degrees(dot)
	if dot > 1 then
		dot = 1
	elseif dot < -1 then
		dot = -1
	end
	return math.acos(dot) * 180 / math.pi
end

local function spawn_segment(state, dir, reason)
	state.segment_serial = (state.segment_serial or 0) + 1
	local id = state.segment_serial
	state.segments = state.segments or {}
	state.segments[id] = {
		id = id,
		phase = "emitting",
		birth_frame = state.time or 0,
		stop_frame = nil,
		direction = { x = dir.x, y = dir.y },
		split_reason = reason or "birth",
		emission_closed = false,
		max_turn_degrees = 0,
		max_neighbor_turn = 0,
		max_neighbor_gap = 0,
	}
	state.active_segment_id = id
	state.last_split_reason = reason or "birth"
	state.segment_created_total = (state.segment_created_total or 0) + 1
	if reason == "direction" then
		state.direction_break_count = (state.direction_break_count or 0) + 1
	elseif reason == "position" then
		state.position_break_count = (state.position_break_count or 0) + 1
	elseif reason == "geometry" then
		state.geometry_break_count = (state.geometry_break_count or 0) + 1
	end
	return id
end

local function open_segment(state, dir, reason, source_id, dot)
	local old = state.segments and state.active_segment_id and state.segments[state.active_segment_id]
	if old and not old.emission_closed then
		close_segment(state, old, reason, source_id, dot)
	end
	return spawn_segment(state, dir, reason)
end

local function mark_draining(state)
	local segs = state.segments or {}
	for _, seg in pairs(segs) do
		if seg.phase == "emitting" then
			close_segment(state, seg, "stop", newest_slice_id(state, seg.id), 1)
		end
	end
end

local function grow_rate(age, temp)
	local rate
	if age <= 5 then
		rate = 6
	elseif age <= 12 then
		rate = 4.5
	elseif age <= 20 then
		rate = 1.2
	else
		rate = -2.2
	end
	if temp < 0 then temp = 0 end
	return rate * (0.4 + 0.6 * temp)
end

local function perp(vx, vy)
	local len = math.sqrt(vx * vx + vy * vy)
	if len < 0.001 then
		return 0, 1
	end
	return -vy / len, vx / len
end

local function clamp_radius(value, half)
	if value > half then return half end
	if value < 1.2 then return 1.2 end
	return value
end

-- Lateral heat rides the slice. It is not a room grid and it does not feed the color outlines.
local HEAT_N = 9
local HEAT_KAPPA = 0.08
local HEAT_DRIFT_AMP = 0.025
local HEAT_BIRTH_SHIFT = 1.6
local HEAT_BIRTH_PEAK = 0.92
local HEAT_SIGMA = 1.15

local function finite01(v)
	if v ~= v or v == math.huge or v == -math.huge then
		return 0, true
	end
	if v < 0 then return 0, false end
	if v > 1 then return 1, false end
	return v, false
end

local function profile_at(profile, pos)
	local i0 = math.floor(pos)
	local frac = pos - i0
	local function at(i)
		if i < 1 or i > HEAT_N or not profile then
			return 0
		end
		return profile[i] or 0
	end
	return at(i0) * (1 - frac) + at(i0 + 1) * frac
end

local function birth_heat(seed, shift, drift)
	if not shift then
		shift = (geom.hash01(seed, 1, 41) - 0.5) * (HEAT_BIRTH_SHIFT * 2)
	end
	if not drift then
		drift = (geom.hash01(seed, 2, 43) - 0.5) * (HEAT_DRIFT_AMP * 2)
	end
	local peak = 0
	local raw = {}
	for i = 1, HEAT_N do
		local u = (i - 5) - shift
		local t = math.exp(-0.5 * (u / HEAT_SIGMA) * (u / HEAT_SIGMA))
		raw[i] = t
		if t > peak then
			peak = t
		end
	end
	local profile = {}
	for i = 1, HEAT_N do
		local v = 0
		if peak > 0 then
			v = raw[i] / peak * HEAT_BIRTH_PEAK
		end
		profile[i] = finite01(v)
	end
	return profile, drift, shift
end

local function cheap_cool(profile, cool)
	if not profile then
		return
	end
	local keep = 1 - (cool or 0)
	if keep < 0 then
		keep = 0
	end
	for i = 1, HEAT_N do
		local value = (profile[i] or 0) * keep
		if value < 0.012 then
			value = 0
		end
		profile[i] = value
	end
end

local function step_profile(profile, drift, cool, mode)
	local shifted = {}
	for i = 1, HEAT_N do
		shifted[i] = profile_at(profile, i - (drift or 0))
	end
	local diffused = {}
	for i = 1, HEAT_N do
		local left = shifted[i - 1] or shifted[i]
		local right = shifted[i + 1] or shifted[i]
		local v = shifted[i] + HEAT_KAPPA * (left + right - 2 * shifted[i])
		diffused[i] = finite01(v)
	end
	if not cool or cool < 0 then
		cool = 0
	end
	if cool > 1 then
		cool = 1
	end
	local bad = false
	for i = 1, HEAT_N do
		local raw = diffused[i] - cool
		if mode == "mul" then
			raw = diffused[i] * (1 - cool)
			if raw < 0.012 then
				raw = 0
			end
		end
		local v, nan = finite01(raw)
		profile[i] = v
		if nan then
			bad = true
		end
	end
	return bad
end

local function profile_peak(profile)
	local peak = 0
	if not profile then
		return 0
	end
	for i = 1, HEAT_N do
		local v = profile[i] or 0
		if v > peak then
			peak = v
		end
	end
	return peak
end

function stream.profile_stats(profile)
	local tmin, tmax = 0, 0
	local sum, moment = 0, 0
	for i = 1, HEAT_N do
		local t = finite01(profile and profile[i] or 0)
		if i == 1 or t < tmin then
			tmin = t
		end
		if t > tmax then
			tmax = t
		end
		local u = (i - 1) / (HEAT_N - 1) * 2 - 1
		sum = sum + t
		moment = moment + u * t
	end
	local center = 0
	local spread = 0
	if sum > 1e-8 then
		center = moment / sum
		local var = 0
		for i = 1, HEAT_N do
			local u = (i - 1) / (HEAT_N - 1) * 2 - 1
			local d = u - center
			local t = finite01(profile and profile[i] or 0)
			var = var + d * d * t
		end
		spread = math.sqrt(var / sum)
	end
	return {
		tmin = tmin,
		tmax = tmax,
		center = center,
		spread = spread,
	}
end

local function copy_profile(profile)
	local out = {}
	for i = 1, HEAT_N do
		out[i] = finite01(profile and profile[i] or 0)
	end
	return out
end

local function push_trail(state, slice, stats, travelled)
	local trail = state.heat_trail
	if not trail then
		trail = {}
		state.heat_trail = trail
	end
	trail[#trail + 1] = {
		age = slice.age or 0,
		x = slice.x or 0,
		y = slice.y or 0,
		dist = travelled,
		tmax = stats.tmax,
		center = stats.center,
		spread = stats.spread,
	}
	if #trail > 80 then
		table.remove(trail, 1)
	end
end

local function seal_slice(state, slice, reason)
	if not slice or slice.id ~= state.tracked_slice_id then
		return
	end
	local stats = stream.profile_stats(slice.temp_profile)
	local dx = (slice.x or 0) - (slice.ox or 0)
	local dy = (slice.y or 0) - (slice.oy or 0)
	local travelled = math.sqrt(dx * dx + dy * dy)
	state.heat_track_alive = false
	state.heat_track_end = reason
	state.heat_travelled = travelled
	state.heat_age = slice.age or 0
	state.heat_tmin = stats.tmin
	state.heat_tmax = stats.tmax
	state.heat_center = stats.center
	state.heat_spread = stats.spread
	state.heat_x = slice.x
	state.heat_y = slice.y
	state.heat_seed = slice.seed
	state.heat_shift = slice.heat_shift
	state.heat_drift_value = slice.heat_drift
	state.heat_profile = copy_profile(slice.temp_profile)
	push_trail(state, slice, stats, travelled)
end

function stream.sample_world(slice, index)
	local u = (index - 1) / (HEAT_N - 1) * 2 - 1
	local vx = slice.vx or slice.dx or 1
	local vy = slice.vy or slice.dy or 0
	local nx, ny = perp(vx, vy)
	local reach = slice.rl or 4
	if u >= 0 then
		reach = slice.ru or 4
	end
	return (slice.x or 0) + nx * u * reach, (slice.y or 0) + ny * u * reach
end

stream.HEAT_COUNT = HEAT_N

local function find_slice(list, id)
	for i = 1, #list do
		if list[i].id == id then
			return list[i], i
		end
	end
	return nil, nil
end

local function side_count(state, side)
	local n = 0
	local list = state.branches or {}
	for i = 1, #list do
		if list[i].connected and list[i].side == side then
			n = n + 1
		end
	end
	return n
end

local function push_slice(state, mouth, dir, flow, cfg, break_before)
	state.emission_serial = (state.emission_serial or 0) + 1
	local born = (cfg.mouth_width or 14) * 0.35
	local list = state.stream
	list[#list + 1] = {
		id = state.emission_serial,
		x = mouth.x,
		y = mouth.y,
		ox = mouth.x,
		oy = mouth.y,
		dx = dir.x,
		dy = dir.y,
		vx = dir.x * flow,
		vy = dir.y * flow,
		distance = 0,
		age = 0,
		temperature = 1,
		heat = 1,
		ru = born,
		rl = born,
		extra_u = 0,
		extra_l = 0,
		lean_u = 0,
		lean_l = 0,
		seed = state.emission_serial * 17 + 3,
		emission_id = state.emission_serial,
		break_before = break_before == true,
		segment_id = state.active_segment_id,
		birth_frame = state.time or 0,
		birth_dx = dir.x,
		birth_dy = dir.y,
	}
	local slice = list[#list]
	state.wave = (state.wave or 0) + 0.28
	local shift = math.sin(state.wave) * HEAT_BIRTH_SHIFT
	local drift = math.cos(state.wave * 0.73) * HEAT_DRIFT_AMP
	local profile = birth_heat(slice.seed, shift, drift)
	slice.temp_profile = profile
	slice.heat_drift = drift
	slice.heat_shift = shift
	slice.sway_phase = state.wave
	slice.form = math.floor(state.wave / 1.68)
	if state.heat_arm then
		state.tracked_slice_id = slice.id
		state.heat_arm = false
		state.heat_trail = {}
		state.heat_track_end = nil
		state.heat_track_alive = true
	end
end

local function spawn_branch(state, cfg, slice, side)
	local cap = cfg.branch_cap or 3
	if cap < 2 then cap = 2 end
	if cap > 4 then cap = 4 end
	if side_count(state, side) >= cap then
		return
	end
	if geom.hash01(slice.id, side + 1, 19) > 0.45 then
		return
	end
	state.branches[#state.branches + 1] = {
		id = slice.id * 2 + side,
		side = side,
		parent_id = slice.id,
		age = 0,
		reach = 4,
		root = 6,
		connected = true,
		seed = slice.seed + side * 13,
	}
end

local function advance_branches(state, cfg)
	local list = state.stream
	local branches = state.branches or {}
	state.pending_events = {}
	for i = 1, #list do
		local slice = list[i]
		slice.extra_u = 0
		slice.extra_l = 0
		slice.lean_u = 0
		slice.lean_l = 0
	end
	local kept = {}
	for i = 1, #branches do
		local branch = branches[i]
		if branch.connected then
			branch.age = branch.age + 1
			local parent, index = find_slice(list, branch.parent_id)
			if not parent then
				branch.connected = false
				if branch.tip_x then
					state.pending_events[#state.pending_events + 1] = {
						role = "flame",
						x = branch.tip_x,
						y = branch.tip_y,
						parent_vx = branch.tip_px or 0,
						parent_vy = branch.tip_py or 0,
						nx = branch.tip_nx or 0,
						ny = branch.tip_ny or 0,
						vx = branch.tip_vx or 0,
						vy = branch.tip_vy or 0,
					}
				end
			else
				if branch.age < 7 then
					branch.reach = branch.reach + 1.6
					branch.root = branch.reach * 0.7
				else
					branch.root = branch.root - 2.8
					branch.reach = branch.reach - 0.2
				end
				if branch.reach > 16 then branch.reach = 16 end
				if branch.reach < 0 then branch.reach = 0 end
				if branch.root < 1.2 and branch.age > 8 then
					branch.connected = false
					local nx, ny = perp(parent.vx or parent.dx or 1, parent.vy or parent.dy or 0)
					if branch.side == 1 then
						nx, ny = -nx, -ny
					end
					local radius = branch.side == 0 and parent.ru or parent.rl
					state.pending_events[#state.pending_events + 1] = {
						role = "flame",
						x = parent.x + nx * (radius + branch.reach),
						y = parent.y + ny * (radius + branch.reach),
						parent_vx = parent.vx or 0,
						parent_vy = parent.vy or 0,
						nx = nx,
						ny = ny,
						vx = (parent.vx or 0) * 0.45 + nx * 2.4,
						vy = (parent.vy or 0) * 0.45 + ny * 2.4,
					}
				else
					local function add_extra(slot, amount, lean)
						if not slot then
							return
						end
						if branch.side == 0 then
							slot.extra_u = (slot.extra_u or 0) + amount
							slot.lean_u = (slot.lean_u or 0) + lean
						else
							slot.extra_l = (slot.extra_l or 0) + amount
							slot.lean_l = (slot.lean_l or 0) + lean
						end
					end
					add_extra(parent, branch.root, 0)
					add_extra(list[index - 1], branch.reach * 0.85, 1.5)
					add_extra(list[index - 2], branch.reach * 0.35, 0.5)
					local nx, ny = perp(parent.vx or parent.dx or 1, parent.vy or parent.dy or 0)
					if branch.side == 1 then
						nx, ny = -nx, -ny
					end
					local radius = branch.side == 0 and parent.ru or parent.rl
					branch.tip_x = parent.x + nx * ((radius or 0) + branch.reach)
					branch.tip_y = parent.y + ny * ((radius or 0) + branch.reach)
					branch.tip_vx = (parent.vx or 0) * 0.45 + nx * 2.4
					branch.tip_vy = (parent.vy or 0) * 0.45 + ny * 2.4
					branch.tip_px = parent.vx or 0
					branch.tip_py = parent.vy or 0
					branch.tip_nx = nx
					branch.tip_ny = ny
					kept[#kept + 1] = branch
				end
			end
		end
	end
	state.branches = kept
end

function stream.advance(state, cfg, emitting, mouth, dir)
	local list = state.stream
	if not state.branches then
		state.branches = {}
	end
	local heat_ns = 0
	local function step_heat(slice, cool)
		if not slice.temp_profile then
			return
		end
		local t0 = nil
		if Isaac and Isaac.GetNanoTime then
			t0 = Isaac.GetNanoTime()
		end
		local bad = step_profile(slice.temp_profile, slice.heat_drift or 0, cool, cfg.heat_cool_mode or "mul")
		if bad then
			state.nan_count = (state.nan_count or 0) + 1
		end
		if t0 and Isaac.GetNanoTime then
			heat_ns = heat_ns + (Isaac.GetNanoTime() - t0)
		end
	end
	local function finish_heat()
		if Isaac and Isaac.GetNanoTime then
			state.temperature_update_us = heat_ns / 1000
		else
			state.temperature_update_us = nil
		end
	end
	local cap = cfg.stream_cap or 128
	local flow = cfg.flow or 16
	local half = cfg.half_width or 95
	local function note_remove(seg, reason)
		if reason == "distance" then
			state.removed_by_distance = (state.removed_by_distance or 0) + 1
			state.removed_by_distance_total = (state.removed_by_distance_total or 0) + 1
			if seg then seg.removed_distance = (seg.removed_distance or 0) + 1 end
		elseif reason == "cooled" then
			state.removed_by_temperature = (state.removed_by_temperature or 0) + 1
			state.removed_by_temperature_total = (state.removed_by_temperature_total or 0) + 1
			if seg then seg.removed_temperature = (seg.removed_temperature or 0) + 1 end
		elseif reason == "aged" then
			state.removed_by_age = (state.removed_by_age or 0) + 1
			state.removed_by_age_total = (state.removed_by_age_total or 0) + 1
			if seg then seg.removed_age = (seg.removed_age or 0) + 1 end
		elseif reason == "segment_cap" or reason == "stream_cap" or reason == "budget_ease" then
			state.removed_by_budget = (state.removed_by_budget or 0) + 1
			state.removed_by_budget_total = (state.removed_by_budget_total or 0) + 1
			if seg then seg.removed_budget = (seg.removed_budget or 0) + 1 end
		elseif reason == "hard_cap" then
			state.removed_by_hard_cap = (state.removed_by_hard_cap or 0) + 1
			state.removed_by_hard_cap_total = (state.removed_by_hard_cap_total or 0) + 1
			if seg then seg.removed_hard_cap = (seg.removed_hard_cap or 0) + 1 end
		elseif reason == "residual_done" then
			state.removed_by_residual = (state.removed_by_residual or 0) + 1
			state.removed_by_residual_total = (state.removed_by_residual_total or 0) + 1
			if seg then seg.removed_residual = (seg.removed_residual or 0) + 1 end
		end
	end
	state.removed_by_distance = 0
	state.removed_by_temperature = 0
	state.removed_by_age = 0
	state.removed_by_budget = 0
	state.removed_by_hard_cap = 0
	state.removed_by_residual = 0
	state.hard_cap_trips = 0
	state.lod_transition_count = 0
	state.coasting_frames = 0
	state.dissipating_frames = 0
	if not emitting then
		mark_draining(state)
	end
	local watch = nil
	for _, seg in pairs(state.segments or {}) do
		if seg.emission_closed and seg.phase == "coasting" then
			local since = (state.time or 0) - (seg.stop_frame or 0)
			if since >= 2 then
				seg.phase = "dissipating"
				seg.dissipate_frame = seg.dissipate_frame or (state.time or 0)
			end
		end
		if seg.emission_closed and seg.phase ~= "emitting" then
			local speed = seg.cooling_speed or 8
			local limit = seg.length_axis or 0
			local front = seg.cooling_front_s or 0
			if front < limit then
				front = front + speed
				if front > limit then
					front = limit
				end
			end
			seg.cooling_front_s = front
			seg.dissipate_front = front
		end
		if seg.phase == "coasting" then
			local since = (state.time or 0) - (seg.stop_frame or 0)
			if since > (state.coasting_frames or 0) then
				state.coasting_frames = since
			end
		elseif seg.phase == "dissipating" then
			local since = (state.time or 0) - (seg.dissipate_frame or seg.stop_frame or 0)
			if since > (state.dissipating_frames or 0) then
				state.dissipating_frames = since
			end
		end
		if seg.emission_closed then
			local peak = 0
			local peak_strength = 0
			local tip_s = 0
			for n = 1, #list do
				local slice = list[n]
				if slice.segment_id == seg.id then
					local visual = slice.residual_visual
					if visual then
						local strength = 1
						local along = slice.release_s
						if along == nil then
							along = slice.from_rear or 0
						end
						if along > tip_s then
							tip_s = along
						end
						if along <= (seg.cooling_front_s or 0) then
							strength = profile_peak(slice.temp_profile)
							if not slice.cooling_start_frame then
								slice.cooling_start_frame = state.time or 0
							end
						end
						if seg.visual_skip then
							visual.offscreen = (visual.offscreen or 1) * 0.85
						else
							visual.offscreen = 1
						end
						visual.strength = strength * (visual.offscreen or 1)
						if visual.strength > peak_strength then
							peak_strength = visual.strength
						end
					end
					local hot = profile_peak(slice.temp_profile)
					if hot > peak then
						peak = hot
					end
				end
			end
			local shell = seg.mature and 0.9 or 0.62
			seg.residual = shell * peak_strength
			seg.thermal_peak = peak
			seg.head_release = tip_s
			local n, arc, mean = segment_span(state, seg.id)
			seg.length_now = arc
			seg.width_now = mean
			seg.live_slices = n
			if seg.mature and (not watch or (seg.length_at_close or 0) > (watch.length_at_close or 0)) then
				watch = seg
			end
		end
	end
	if watch then
		state.watch_length_at_close = watch.length_at_close or 0
		state.watch_length_now = watch.length_now or 0
		state.watch_width_at_close = watch.width_at_close or 0
		state.watch_width_now = watch.width_now or 0
		state.watch_phase = watch.phase
	end
	local i = 1
	while i <= #list do
		local slice = list[i]
		local seg = state.segments and state.segments[slice.segment_id]
		local speed = flow
		local bx = slice.birth_dx or slice.dx or dir.x
		local by = slice.birth_dy or slice.dy or dir.y
		local nx, ny = perp(bx, by)
		local phase = (slice.sway_phase or 0) + (slice.age or 0) * 0.16
		local sway_v = math.cos(phase) * 1.15
		slice.vx = bx * speed + nx * sway_v
		slice.vy = by * speed + ny * sway_v
		local dot = slice.vx * bx + slice.vy * by
		if dot < speed * 0.35 then
			slice.vx = bx * speed
			slice.vy = by * speed
		end
		slice.x = (slice.x or slice.ox or mouth.x) + slice.vx
		slice.y = (slice.y or slice.oy or mouth.y) + slice.vy
		slice.age = (slice.age or 0) + 1
		slice.distance = (slice.distance or 0) + speed
		local bias = ((slice.seed or 1) % 17) / 17 - 0.5
		local rate = grow_rate(slice.age, slice.temperature or 1)
		local along = slice.release_s
		if along == nil then
			along = slice.from_rear or 0
		end
		local caught = false
		if seg and seg.emission_closed and seg.phase ~= "emitting" then
			caught = along <= (seg.dissipate_front or 0)
		end
		if seg and seg.emission_closed and not caught then
			rate = 0
		end
		slice.ru = clamp_radius((slice.ru or 4) + rate * (1 + bias * 0.45), half)
		slice.rl = clamp_radius((slice.rl or 4) + rate * (1 - bias * 0.45), half)
		local cool_mode = cfg.heat_cool_mode or "mul"
		local cool = 0
		if slice.age > 12 then
			if cool_mode == "mul" then
				cool = cfg.heat_lambda or 0.04
			else
				cool = 0.035
			end
		end
		local light_sim = seg and seg.sim_light and ((state.time or 0) % 2 == 1)
		local jet_length = cfg.length or 300
		local heat_range = emitting and not (seg and seg.emission_closed)
		if cool_mode ~= "mul" and heat_range and slice.distance > jet_length * 0.75 then
			cool = cool + 0.045
		end
		if caught then
			local depth = (seg.dissipate_front or 0) - along
			local u = depth / 36
			if u < 0 then u = 0 end
			if u > 1 then u = 1 end
			cool = cool + 0.008 + u * 0.018
			if seg and not seg.mature then
				cool = cool + 0.035
			end
			if u > 0.35 then
				local shrink = 1 - 0.01 * u
				slice.ru = clamp_radius((slice.ru or 4) * shrink, half)
				slice.rl = clamp_radius((slice.rl or 4) * shrink, half)
			end
			if seg.pieces and slice.id then
				local rec = seg.pieces[slice.id]
				if rec and rec.tight then
					cool = cool + 0.02
				end
			end
		elseif seg and seg.emission_closed then
			cool = 0
		end
		if seg and seg.emission_closed and not caught then
			local profile = slice.temp_profile
			if profile then
				for sample_i = 1, 9 do
					local value = profile[sample_i]
					if value ~= value or value == math.huge or value == -math.huge then
						profile[sample_i] = 0
					end
				end
			end
		elseif light_sim then
			local t0 = nil
			if Isaac and Isaac.GetNanoTime then
				t0 = Isaac.GetNanoTime()
			end
			cheap_cool(slice.temp_profile, cool)
			if t0 and Isaac.GetNanoTime then
				heat_ns = heat_ns + (Isaac.GetNanoTime() - t0)
			end
		else
			step_heat(slice, cool)
		end
		if cool_mode == "mul" then
			if not (seg and seg.emission_closed and not caught) then
				slice.temperature = profile_peak(slice.temp_profile)
			end
		elseif not (seg and seg.emission_closed and not caught) then
			slice.temperature = (slice.temperature or 1) - cool
		end
		slice.heat = slice.temperature
		if slice.age == 8 and seg and seg.phase == "emitting" and not seg.emission_closed then
			spawn_branch(state, cfg, slice, 0)
			spawn_branch(state, cfg, slice, 1)
		end
		local life_cap = cool_mode == "mul" and 96 or 70
		local reason = nil
		local visual_now = slice.residual_visual
		local slice_strength = visual_now and visual_now.strength or 0
		local residual_keeps = seg and seg.emission_closed and slice_strength > 0.02
		if slice.temperature <= 0.05 and not residual_keeps then
			reason = "cooled"
		elseif slice.age > life_cap then
			reason = "aged"
		elseif slice.distance > (cfg.length or 300) + 48 then
			reason = "distance"
		end
		if reason then
			note_remove(seg, reason)
			seal_slice(state, slice, reason)
			table.remove(list, i)
		else
			i = i + 1
		end
	end
	local j = 1
	while j <= #list do
		local slice = list[j]
		local seg = state.segments and state.segments[slice.segment_id]
		local visual_now = slice.residual_visual
		local slice_strength = visual_now and visual_now.strength or 0
		if seg and seg.emission_closed and visual_now and slice_strength <= 0.02 and profile_peak(slice.temp_profile) < 0.08 then
			note_remove(seg, "residual_done")
			seal_slice(state, slice, "residual_done")
			table.remove(list, j)
		else
			j = j + 1
		end
	end
	local function live_ids()
		local ids = {}
		local seen = {}
		for n = 1, #list do
			local id = list[n].segment_id
			if id and not seen[id] then
				seen[id] = true
				ids[#ids + 1] = id
			end
		end
		table.sort(ids)
		return ids
	end
	local function max_temp(id)
		local peak = 0
		for n = 1, #list do
			local slice = list[n]
			if slice.segment_id == id and (slice.temperature or 0) > peak then
				peak = slice.temperature or 0
			end
		end
		return peak
	end
	local function remove_some(id, limit, pred, why)
		local removed = 0
		local j = 1
		while j <= #list and removed < limit do
			local slice = list[j]
			if slice.segment_id == id and pred(slice) then
				local seg = state.segments and state.segments[id]
				note_remove(seg, why)
				seal_slice(state, slice, why)
				table.remove(list, j)
				removed = removed + 1
				if seg then
					local left = 0
					for n = 1, #list do
						if list[n].segment_id == id then
							left = left + 1
						end
					end
					if left == 0 then
						seg.end_reason = seg.end_reason or why
					end
				end
			else
				j = j + 1
			end
		end
		return removed
	end
	local function apply_budget()
		local soft_seg = cfg.segment_cap or 16
		if soft_seg < 2 then
			soft_seg = 2
		end
		local mid_seg = cfg.mid_segment_cap or (soft_seg + 8)
		local hard_seg = cfg.hard_segment_cap or 32
		local soft_slices = cap
		local hard_slices = cfg.hard_stream_cap or 320
		for _, seg in pairs(state.segments or {}) do
			seg.render_coarse = false
			seg.budget_urge = false
			seg.fade_ease = false
		end
		local function closed_seg(id)
			if id == state.active_segment_id then
				return nil
			end
			local seg = state.segments and state.segments[id]
			if seg and seg.emission_closed then
				return seg
			end
			return nil
		end
		local function coarsen_oldest(limit)
			local marked = 0
			local ids_now = live_ids()
			for k = 1, #ids_now do
				if limit and marked >= limit then
					break
				end
				local seg = closed_seg(ids_now[k])
				if seg then
					seg.render_coarse = true
					marked = marked + 1
				end
			end
		end
		local ids = live_ids()
		for k = 1, #ids do
			local seg = closed_seg(ids[k])
			if seg and max_temp(ids[k]) <= 0.08 and (seg.residual or 0) <= 0.02 then
				remove_some(ids[k], 128, function()
					return true
				end, "residual_done")
				seg.end_reason = seg.end_reason or "residual_done"
			end
		end
		ids = live_ids()
		if #ids > soft_seg or #list > soft_slices then
			local want = #ids - soft_seg
			if #list > soft_slices then
				want = math.max(want, 1)
			end
			if want < 1 then
				want = 1
			end
			coarsen_oldest(want)
		end
		if #ids > mid_seg then
			coarsen_oldest(#ids)
		end
		local geom_us = state.geometry_build_us or 0
		if geom_us > 3000 then
			coarsen_oldest(4)
		end
		ids = live_ids()
		if #ids >= hard_seg - 4 then
			local oldest = closed_seg(ids[1]) or closed_seg(ids[2])
			if oldest then
				oldest.fade_ease = true
				oldest.render_coarse = true
				if oldest.phase == "coasting" then
					oldest.phase = "dissipating"
					oldest.dissipate_frame = oldest.dissipate_frame or (state.time or 0)
				end
			end
		end
		if #list > hard_slices or #ids > hard_seg then
			state.hard_cap_trips = (state.hard_cap_trips or 0) + 1
			state.hard_cap_trips_total = (state.hard_cap_trips_total or 0) + 1
			local eased = 0
			local ease_limit = #ids - soft_seg
			if ease_limit < 1 then
				ease_limit = 1
			end
			for k = 1, #ids do
				local seg = closed_seg(ids[k])
				if seg and eased < ease_limit then
					seg.fade_ease = true
					seg.render_coarse = true
					eased = eased + 1
				end
			end
		end
	end
	local function band_length(id, threshold)
		local pts = {}
		for n = 1, #list do
			if list[n].segment_id == id then
				pts[#pts + 1] = list[n]
			end
		end
		local arc = 0
		local width = 0
		for n = 1, #pts do
			width = width + (pts[n].ru or 0) + (pts[n].rl or 0)
			if n > 1 then
				local shown = (pts[n].temperature or 0) >= threshold or (pts[n - 1].temperature or 0) >= threshold
				if shown then
					local dx = (pts[n].x or 0) - (pts[n - 1].x or 0)
					local dy = (pts[n].y or 0) - (pts[n - 1].y or 0)
					arc = arc + math.sqrt(dx * dx + dy * dy)
				end
			end
		end
		local mean = #pts > 0 and (width / #pts) or 0
		return arc, mean, #pts
	end
	local function publish_rows()
		local seen_arc = {}
		for n = 1, #list do
			local id = list[n].segment_id
			if id and not seen_arc[id] then
				seen_arc[id] = true
				local seg = state.segments and state.segments[id]
				if seg and not seg.arc_locked then
					local pts = segment_points(state, id)
					if #pts > 0 then
						pts[#pts].arc_s = 0
						local acc = 0
						for k = #pts, 2, -1 do
							local dx = (pts[k - 1].x or 0) - (pts[k].x or 0)
							local dy = (pts[k - 1].y or 0) - (pts[k].y or 0)
							acc = acc + math.sqrt(dx * dx + dy * dy)
							pts[k - 1].arc_s = acc
						end
						seg.length_axis = acc
					end
				end
			end
		end
		local rows = {}
		local ids = live_ids()
		for k = 1, #ids do
			local id = ids[k]
			local seg = state.segments and state.segments[id]
			if seg then
				local outer_len, width, live = band_length(id, 0.12)
				local hot_len = band_length(id, 0.42)
				local coast = 0
				local diss = 0
				if seg.emission_closed and seg.stop_frame then
					if seg.phase == "coasting" then
						coast = (state.time or 0) - seg.stop_frame
					else
						diss = (state.time or 0) - (seg.dissipate_frame or seg.stop_frame)
						coast = (seg.dissipate_frame or seg.stop_frame) - seg.stop_frame
					end
				end
				rows[#rows + 1] = {
					segment_id = id,
					phase = seg.phase,
					live = live,
					outer_len = outer_len,
					hot_len = hot_len,
					width = width,
					coast_frames = coast,
					dissipate_frames = diss,
					dissipate_front = seg.dissipate_front or 0,
					cooling_front_s = seg.cooling_front_s or 0,
					cooling_samples = seg.cooling_samples,
					removed_budget = seg.removed_budget or 0,
					end_reason = seg.end_reason or "",
					split_reason = seg.split_reason or "",
					mature = seg.mature == true,
					coarse = seg.render_coarse == true,
					residual = seg.residual or 0,
					thermal_peak = seg.thermal_peak or 0,
				}
			end
		end
		state.segment_rows = rows
	end
	if not emitting then
		state.fade_cut = (state.fade_cut or 0) + 1
		apply_budget()
		publish_rows()
		advance_branches(state, cfg)
		retire_segments(state, list)
		finish_heat()
		return
	end
	state.fade_cut = 0
	local break_before = false
	local split_reason = nil
	local prev = list[#list]
	local active_seg = state.segments and state.active_segment_id and state.segments[state.active_segment_id]
	local extent = active_seg and segment_extent(state, active_seg.id, mouth) or 0
	local ref_x = dir.x
	local ref_y = dir.y
	if active_seg and active_seg.direction then
		ref_x = active_seg.direction.x or dir.x
		ref_y = active_seg.direction.y or dir.y
	end
	local aim_dot = unit_dot(ref_x, ref_y, dir.x, dir.y)
	local aim_deg = dot_degrees(aim_dot)
	local gate = cfg.turn_extent or 80
	if active_seg and not active_seg.emission_closed and aim_deg > (active_seg.max_turn_degrees or 0) then
		active_seg.max_turn_degrees = aim_deg
	end
	local hist = active_seg and active_seg.max_turn_degrees or aim_deg
	local forked_now = false
	local owned = {}
	local cuts = {}
	if not break_before and active_seg and not active_seg.emission_closed then
		local max_gap, max_turn = 0, 0
		local links = {}
		for i = 1, #list do
			local slice = list[i]
			if slice.segment_id == active_seg.id then
				local prev_slice = owned[#owned]
				owned[#owned + 1] = slice
				if prev_slice then
					local sdx = (slice.x or 0) - (prev_slice.x or 0)
					local sdy = (slice.y or 0) - (prev_slice.y or 0)
					local gap = math.sqrt(sdx * sdx + sdy * sdy)
					local turn = dot_degrees(unit_dot(prev_slice.birth_dx or prev_slice.dx or 1, prev_slice.birth_dy or prev_slice.dy or 0, slice.birth_dx or slice.dx or 1, slice.birth_dy or slice.dy or 0))
					if gap > max_gap then
						max_gap = gap
					end
					if turn > max_turn then
						max_turn = turn
					end
					links[#links + 1] = { at = #owned, gap = gap, turn = turn }
				end
			end
		end
		local function travel_since(at)
			local bend = owned[at]
			local tip = owned[#owned]
			if not bend or not tip or not bend.x or not tip.x or bend == tip then
				return 0
			end
			local bx = bend.birth_dx or bend.dx or 0
			local by = bend.birth_dy or bend.dy or 0
			local blen = math.sqrt(bx * bx + by * by)
			if blen < 0.0001 then
				return 0
			end
			bx, by = bx / blen, by / blen
			return (bend.x - tip.x) * bx + (bend.y - tip.y) * by
		end
		for i = 1, #links do
			local link = links[i]
			local angled = link.turn > 45.05 and travel_since(link.at) >= gate
			local isolated_gap = link.gap > gate * 2
			if angled or isolated_gap then
				cuts[#cuts + 1] = link.at
			end
		end
		active_seg.max_neighbor_gap = max_gap
		active_seg.max_neighbor_turn = max_turn
	end
	if #cuts > 0 and not break_before and active_seg and not active_seg.emission_closed then
		local ranges = {}
		local cursor = 1
		local function take_range(a, b)
			local pts = {}
			for i = a, b do
				pts[#pts + 1] = owned[i]
			end
			return pts
		end
		for c = 1, #cuts do
			local start_at = cuts[c]
			if start_at > cursor then
				ranges[#ranges + 1] = take_range(cursor, start_at - 1)
			end
			cursor = start_at
		end
		if cursor <= #owned then
			ranges[#ranges + 1] = take_range(cursor, #owned)
		end
		local function birth_dir(slice)
			return {
				x = slice and (slice.birth_dx or slice.dx) or dir.x,
				y = slice and (slice.birth_dy or slice.dy) or dir.y,
			}
		end
		local function range_peaks(pts)
			local max_gap, max_turn = 0, 0
			for i = 2, #pts do
				local prev_slice = pts[i - 1]
				local slice = pts[i]
				local sdx = (slice.x or 0) - (prev_slice.x or 0)
				local sdy = (slice.y or 0) - (prev_slice.y or 0)
				local gap = math.sqrt(sdx * sdx + sdy * sdy)
				local turn = dot_degrees(unit_dot(prev_slice.birth_dx or prev_slice.dx or 1, prev_slice.birth_dy or prev_slice.dy or 0, slice.birth_dx or slice.dx or 1, slice.birth_dy or slice.dy or 0))
				if gap > max_gap then
					max_gap = gap
				end
				if turn > max_turn then
					max_turn = turn
				end
			end
			return max_gap, max_turn
		end
		local function range_aim(pts)
			local base = pts[1]
			local hx = base and (base.birth_dx or base.dx) or dir.x
			local hy = base and (base.birth_dy or base.dy) or dir.y
			local peak = 0
			for i = 2, #pts do
				local slice = pts[i]
				local turn = dot_degrees(unit_dot(hx, hy, slice.birth_dx or slice.dx or 1, slice.birth_dy or slice.dy or 0))
				if turn > peak then
					peak = turn
				end
			end
			return peak
		end
		local head_gap, head_turn = range_peaks(ranges[1])
		active_seg.max_neighbor_gap = head_gap
		active_seg.max_neighbor_turn = head_turn
		local ids = { active_seg.id }
		for r = 2, #ranges do
			local pts = ranges[r]
			local id = spawn_segment(state, birth_dir(pts[1]), "direction")
			ids[r] = id
			for i = 1, #pts do
				pts[i].segment_id = id
			end
			local gap_peak, turn_peak = range_peaks(pts)
			local born = state.segments[id]
			born.max_turn_degrees = range_aim(pts)
			born.max_neighbor_gap = gap_peak
			born.max_neighbor_turn = turn_peak
		end
		for r = 1, #ranges - 1 do
			local pts = ranges[r]
			local newest = pts[#pts]
			close_segment(state, state.segments[ids[r]], "direction", newest and newest.id, aim_dot, pts)
		end
		forked_now = #ranges > 1
		state.stream_discontinuity_count = (state.stream_discontinuity_count or 0) + math.max(#ranges - 1, 0)
		active_seg = state.segments[state.active_segment_id]
	end
	state.segment_extent = extent
	state.aim_turn_degrees = aim_deg
	state.max_turn_degrees = active_seg and active_seg.max_turn_degrees or hist
	state.max_neighbor_gap = active_seg and active_seg.max_neighbor_gap or 0
	state.max_neighbor_turn = active_seg and active_seg.max_neighbor_turn or 0
	state.turn_extent = gate
	local mouth_jump = false
	if prev and prev.x then
		local jx = mouth.x - prev.x
		local jy = mouth.y - prev.y
		mouth_jump = jx * jx + jy * jy > 90 * 90
	end
	if not break_before and prev and prev.x and (not forked_now or mouth_jump) then
		local dx = mouth.x - prev.x
		local dy = mouth.y - prev.y
		local jumped = dx * dx + dy * dy > 90 * 90
		local folded = false
		local ahead = (prev.x - mouth.x) * (prev.dx or 0) + (prev.y - mouth.y) * (prev.dy or 0)
		if ahead < 0 and dx * dx + dy * dy < 80 * 80 then
			folded = true
		end
		if jumped then
			split_reason = "position"
		end
		if folded and not jumped then
			split_reason = "geometry"
		end
		if split_reason then
			break_before = true
			state.stream_discontinuity_count = (state.stream_discontinuity_count or 0) + 1
			open_segment(state, dir, split_reason, prev.id, aim_dot)
		end
	end
	if not break_before then
		local active = state.segments and state.active_segment_id and state.segments[state.active_segment_id]
		if active and active.emission_closed then
			break_before = true
			open_segment(state, dir, "birth")
		end
	end
	if not state.active_segment_id then
		open_segment(state, dir, "birth")
	end
	if break_before then
		push_slice(state, mouth, dir, flow, cfg, true)
		local bridge = list[#list]
		bridge.x = bridge.x + bridge.dx * (cfg.spacing or 5)
		bridge.y = bridge.y + bridge.dy * (cfg.spacing or 5)
		bridge.age = 1
		push_slice(state, mouth, dir, flow, cfg, false)
	else
		push_slice(state, mouth, dir, flow, cfg, false)
		if #list == 1 then
			local first = list[1]
			first.x = first.x + first.dx * (cfg.spacing or 5)
			first.y = first.y + first.dy * (cfg.spacing or 5)
			first.age = 1
			push_slice(state, mouth, dir, flow, cfg, false)
		end
	end
	apply_budget()
	publish_rows()
	if #list > (state.stream_peak or 0) then
		state.stream_peak = #list
	end
	advance_branches(state, cfg)
	retire_segments(state, list)
	finish_heat()
end

function stream.arm_heat_track(state)
	state.heat_arm = true
end

function stream.observe_heat(state)
	local list = state.stream or {}
	state.active_slice_count = #list
	local id = state.tracked_slice_id
	if not id then
		state.heat_track_alive = false
		return
	end
	local slice = find_slice(list, id)
	if not slice then
		state.heat_track_alive = false
		if not state.heat_track_end then
			state.heat_track_end = "lost"
		end
		return
	end
	local stats = stream.profile_stats(slice.temp_profile)
	local dx = (slice.x or 0) - (slice.ox or 0)
	local dy = (slice.y or 0) - (slice.oy or 0)
	local travelled = math.sqrt(dx * dx + dy * dy)
	state.heat_track_alive = true
	state.heat_track_end = nil
	state.heat_travelled = travelled
	state.heat_age = slice.age or 0
	state.heat_tmin = stats.tmin
	state.heat_tmax = stats.tmax
	state.heat_center = stats.center
	state.heat_spread = stats.spread
	state.heat_x = slice.x
	state.heat_y = slice.y
	state.heat_seed = slice.seed
	state.heat_shift = slice.heat_shift
	state.heat_drift_value = slice.heat_drift
	state.heat_profile = copy_profile(slice.temp_profile)
	push_trail(state, slice, stats, travelled)
end

local function add_point(chain, sample)
	local x = sample.x
	local y = sample.y
	if x == nil then
		x = (sample.ox or 0) + (sample.dx or 0) * (sample.distance or 0)
		y = (sample.oy or 0) + (sample.dy or 0) * (sample.distance or 0)
	end
	chain[#chain + 1] = {
		x = x,
		y = y,
		heat = sample.heat or 1,
		travel = sample.distance or 0,
		ru = sample.ru,
		rl = sample.rl,
		extra_u = sample.extra_u or 0,
		extra_l = sample.extra_l or 0,
		lean_u = sample.lean_u or 0,
		lean_l = sample.lean_l or 0,
		temperature = sample.temperature or sample.heat or 1,
		age = sample.age or 0,
		vx = sample.vx or 0,
		vy = sample.vy or 0,
		id = sample.id,
		birth_dx = sample.birth_dx or sample.dx,
		birth_dy = sample.birth_dy or sample.dy,
		from_rear = sample.from_rear or 0,
		release_s = sample.release_s or sample.from_rear or 0,
		temp_profile = sample.temp_profile,
		sway_phase = sample.sway_phase,
		form = sample.form,
		segment_id = sample.segment_id,
	}
end

function stream.chains(state)
	local chains = {}
	local current = nil
	-- Newest sample is the mouth. A new segment, or break_before, starts its own chain.
	for i = #state.stream, 1, -1 do
		local sample = state.stream[i]
		local seg_keep = state.segments and state.segments[sample.segment_id]
		local own = sample.residual_visual
		local own_strength = own and own.strength or 0
		local keep_slice = seg_keep and seg_keep.emission_closed and own_strength > 0.02
		if sample.heat > 0.04 or keep_slice then
			if current and current.segment_id and sample.segment_id and sample.segment_id ~= current.segment_id then
				current = nil
			end
			if not current then
				current = {}
				current.segment_id = sample.segment_id
				local seg = state.segments and state.segments[sample.segment_id]
				current.phase = seg and seg.phase or "emitting"
				current.wave_time = seg and seg.wave_time or nil
				current.closed_rear = not (seg and seg.phase == "emitting" and not seg.emission_closed)
				current.direction = seg and seg.direction or nil
				chains[#chains + 1] = current
			end
			add_point(current, sample)
			if sample.break_before then
				current = nil
			end
		end
	end
	return chains
end

local function smooth01(u)
	if u < 0 then u = 0 end
	if u > 1 then u = 1 end
	return u * u * (3 - 2 * u)
end

-- Render-only blend. Always a new table, so the slice profiles stay untouched.
local function blend_render_profile(a, b, t)
	if not a and not b then
		return nil
	end
	local s = smooth01(t or 0)
	local out = {}
	for j = 1, 9 do
		local av = a and a[j] or 0
		local bv = b and b[j] or 0
		if not a then av = bv end
		if not b then bv = av end
		local value = av + (bv - av) * s
		if value < 0 then value = 0 end
		if value > 1 then value = 1 end
		out[j] = value
	end
	return out
end

local function resample(points, spacing)
	if #points < 2 then
		return points
	end
	local out = { points[1] }
	local carry = 0
	for i = 2, #points do
		local a = points[i - 1]
		local b = points[i]
		local dx = b.x - a.x
		local dy = b.y - a.y
		local len = math.sqrt(dx * dx + dy * dy)
		if len > 0.001 then
			local function mix(key, amount)
				local av = a[key] or 0
				local bv = b[key] or 0
				return av + (bv - av) * amount
			end
			local walked = carry
			while walked + spacing <= len do
				walked = walked + spacing
				local t = walked / len
				out[#out + 1] = {
					x = a.x + dx * t,
					y = a.y + dy * t,
					heat = mix("heat", t),
					travel = mix("travel", t),
					ru = mix("ru", t),
					rl = mix("rl", t),
					extra_u = mix("extra_u", t),
					extra_l = mix("extra_l", t),
					lean_u = mix("lean_u", t),
					lean_l = mix("lean_l", t),
					temperature = mix("temperature", t),
					age = mix("age", t),
					vx = mix("vx", t),
					vy = mix("vy", t),
					id = t < 0.5 and a.id or b.id,
					from_rear = mix("from_rear", t),
					release_s = mix("release_s", t),
					temp_profile = t < 0.5 and a.temp_profile or b.temp_profile,
					render_profile = blend_render_profile(a.temp_profile, b.temp_profile, t),
					segment_id = a.segment_id or b.segment_id,
					sway_phase = mix("sway_phase", t),
					form = t < 0.5 and a.form or b.form,
				}
			end
			carry = len - walked
		end
	end
	local last = points[#points]
	local prev = out[#out]
	local dx = last.x - prev.x
	local dy = last.y - prev.y
	if dx * dx + dy * dy > 1 then
		out[#out + 1] = last
	end
	return out
end

function stream.static_chain(state, cfg)
	local spacing = cfg.spacing or 5
	if spacing < 3 then spacing = 3 end
	local count = math.floor(cfg.length / spacing)
	if count < 2 then count = 2 end
	if count > 80 then count = 80 end
	local points = {}
	local cut = state.fade_cut or 0
	for i = 0, count do
		local s = i * spacing
		local heat = 1
		if cut > 0 and s < cut then
			heat = 0
		elseif s > cfg.length * 0.94 then
			heat = 1 - (s - cfg.length * 0.94) / (cfg.length * 0.08 + 1)
		end
		if heat > 0.04 then
			points[#points + 1] = {
				x = state.origin.x + state.dir.x * s,
				y = state.origin.y + state.dir.y * s,
				heat = heat,
				travel = s,
			}
		end
	end
	return points
end

local function clip_to_travel(points, pin)
	local prev = points[1]
	for i = 2, #points do
		local here = points[i]
		local a = prev.travel or 0
		local b = here.travel or 0
		if b >= pin and a < pin and b > a then
			local t = (pin - a) / (b - a)
			local function mix(key)
				local av = prev[key] or 0
				local bv = here[key] or 0
				return av + (bv - av) * t
			end
			local tip = {
				x = mix("x"),
				y = mix("y"),
				heat = mix("heat"),
				travel = pin,
				ru = mix("ru"),
				rl = mix("rl"),
				extra_u = mix("extra_u"),
				extra_l = mix("extra_l"),
				lean_u = mix("lean_u"),
				lean_l = mix("lean_l"),
				temperature = mix("temperature"),
				age = mix("age"),
				vx = mix("vx"),
				vy = mix("vy"),
				id = t < 0.5 and prev.id or here.id,
				from_rear = mix("from_rear"),
				release_s = mix("release_s"),
				temp_profile = t < 0.5 and prev.temp_profile or here.temp_profile,
				render_profile = blend_render_profile(prev.temp_profile, here.temp_profile, t),
				segment_id = prev.segment_id or here.segment_id,
				sway_phase = mix("sway_phase"),
				form = t < 0.5 and prev.form or here.form,
			}
			local out = {}
			for j = 1, i - 1 do
				out[j] = points[j]
			end
			out[#out + 1] = tip
			if #out >= 2 then
				return out
			end
			return points
		end
		prev = here
	end
	return points
end

local function hold_front(state, cfg, points, segment_id)
	if cfg.static_solid or not points or #points < 2 then
		return points
	end
	local seg = state.segments and state.segments[segment_id]
	if not seg or seg.emission_closed or seg.phase ~= "emitting" then
		return points
	end
	local length = cfg.length or 300
	local raw = points[#points].travel or 0
	local pins = state.front_pin
	if not pins then
		pins = { hold = {}, layers = {} }
		state.front_pin = pins
	end
	pins.hold = pins.hold or {}
	local key = segment_id
	local hold = pins.hold[key]
	if raw >= length then
		hold = true
	elseif raw < length * 0.75 then
		hold = false
	end
	pins.hold[key] = hold == true
	if hold and raw > length then
		return clip_to_travel(points, length)
	end
	return points
end

local function split_long_gaps(points, limit, neighbor_limit)
	local groups = {}
	local current = nil
	local function begin(exposed)
		current = {}
		current.segment_id = points.segment_id
		current.phase = points.phase
		if exposed then
			current.closed_rear = true
		else
			current.closed_rear = points.closed_rear
		end
		current.direction = points.direction
	end
	begin(false)
	current[1] = points[1]
	local neighbor_gate = neighbor_limit or 80
	for i = 2, #points do
		local dx = points[i].x - points[i - 1].x
		local dy = points[i].y - points[i - 1].y
		local dist2 = dx * dx + dy * dy
		local id_gap = math.abs((points[i].id or 0) - (points[i - 1].id or 0))
		local neighbors = points[i].id and points[i - 1].id and id_gap <= 1
		local cut = false
		if not neighbors and dist2 > limit * limit then
			cut = true
		elseif dist2 > neighbor_gate * neighbor_gate then
			cut = true
		end
		if cut then
			if #current >= 1 then
				groups[#groups + 1] = current
			end
			begin(true)
		end
		current[#current + 1] = points[i]
	end
	if #current >= 1 then
		groups[#groups + 1] = current
	end
	return groups
end

local function taper_closed_tip(piece, scale)
	if not piece or piece.phase == "emitting" or #piece < 1 then
		return
	end
	if scale < 0.5 then
		scale = 0.5
	end
	if scale > 1 then
		scale = 1
	end
	local steps = {
		scale,
		scale + (1 - scale) * 0.6,
		scale + (1 - scale) * 0.8,
	}
	local n = #piece
	for back = 0, 2 do
		local i = n - back
		if i >= 1 then
			local mul = steps[back + 1]
			local point = piece[i]
			if point.ru then
				point.ru = point.ru * mul
			end
			if point.rl then
				point.rl = point.rl * mul
			end
			if point.extra_u then
				point.extra_u = point.extra_u * mul
			end
			if point.extra_l then
				point.extra_l = point.extra_l * mul
			end
			point.tip_scale = mul
		end
	end
end

local function seal_lone_slice(piece)
	if not piece or #piece ~= 1 then
		return
	end
	local src = piece[1]
	local bx = src.birth_dx or src.vx or 1
	local by = src.birth_dy or src.vy or 0
	local len = math.sqrt(bx * bx + by * by)
	if len < 0.001 then
		bx, by = 1, 0
	else
		bx, by = bx / len, by / len
	end
	local twin = {}
	for key, value in pairs(src) do
		twin[key] = value
	end
	twin.x = (src.x or 0) + bx * 6
	twin.y = (src.y or 0) + by * 6
	piece[2] = twin
	piece.force_compact = true
end

local function chain_arc(points)
	local arc = 0
	for i = 2, #points do
		local dx = points[i].x - points[i - 1].x
		local dy = points[i].y - points[i - 1].y
		arc = arc + math.sqrt(dx * dx + dy * dy)
	end
	return arc
end

local function piece_shape(points)
	local arc = chain_arc(points)
	local width = 0
	local n = 0
	for i = 1, #points do
		local w = (points[i].ru or 0) + (points[i].rl or 0)
		if w < 1 then
			w = 8
		end
		width = width + w
		n = n + 1
	end
	local local_w = n > 0 and (width / n) or 8
	if local_w < 6 then
		local_w = 6
	end
	local aspect = arc / local_w
	return arc, local_w, aspect
end

local function bind_piece(state, points, class_name, rear_exposed, front_gap, arc, local_w)
	local seg = state.segments and points.segment_id and state.segments[points.segment_id]
	local anchor = points[1] and points[1].id
	points.visual_class = class_name
	points.rear_exposed = rear_exposed == true
	points.front_gap = front_gap == true
	points.piece_arc = arc
	points.piece_width = local_w
	points.split_reason = seg and (seg.closed_reason or seg.split_reason) or nil
	if not seg or not anchor then
		points.piece_id = points.segment_id or 0
		points.piece = nil
		return
	end
	seg.pieces = seg.pieces or {}
	local rec = seg.pieces[anchor]
	if not rec then
		state.piece_serial = (state.piece_serial or 0) + 1
		rec = {
			piece_id = state.piece_serial,
			anchor_id = anchor,
			birth_frame = state.time or 0,
			depth_hold = nil,
		}
		seg.pieces[anchor] = rec
	end
	rec.segment_id = points.segment_id
	rec.phase = points.phase
	rec.split_reason = points.split_reason
	rec.rear_exposed = points.rear_exposed
	rec.front_gap = points.front_gap
	rec.visual_class = class_name
	rec.seen = state.time or 0
	if points.phase ~= "emitting" then
		rec.closure_frame = rec.closure_frame or (state.time or 0)
	end
	points.piece_id = rec.piece_id
	points.piece = rec
end

local KEEP_L1 = { 1, 3, 5, 7, 9 }
local KEEP_L2 = { 1, 5, 9 }

local function ribbon_area(points)
	local n = #points
	if n < 2 then
		return 0
	end
	local upper = {}
	local lower = {}
	for i = 1, n do
		local p = points[i]
		local tx, ty = 1, 0
		if i < n then
			tx = points[i + 1].x - p.x
			ty = points[i + 1].y - p.y
		else
			tx = p.x - points[i - 1].x
			ty = p.y - points[i - 1].y
		end
		local len = math.sqrt(tx * tx + ty * ty)
		if len < 0.0001 then
			tx, ty = 1, 0
		else
			tx, ty = tx / len, ty / len
		end
		local nx, ny = -ty, tx
		upper[i] = { x = p.x + nx * (p.ru or 0), y = p.y + ny * (p.ru or 0) }
		lower[i] = { x = p.x - nx * (p.rl or 0), y = p.y - ny * (p.rl or 0) }
	end
	local area = 0
	local function add(a, b)
		area = area + (a.x * b.y - b.x * a.y)
	end
	for i = 1, n - 1 do
		add(upper[i], upper[i + 1])
	end
	add(upper[n], lower[n])
	for i = n, 2, -1 do
		add(lower[i], lower[i - 1])
	end
	add(lower[1], upper[1])
	if area < 0 then
		area = -area
	end
	return area * 0.5
end

local function simplify_profile(profile, keys)
	if not profile then
		return nil
	end
	local out = {}
	for i = 1, 9 do
		out[i] = profile[i] or 0
	end
	for k = 1, #keys - 1 do
		local a = keys[k]
		local b = keys[k + 1]
		local va = profile[a] or 0
		local vb = profile[b] or 0
		local span = b - a
		for i = a + 1, b - 1 do
			local t = (i - a) / span
			out[i] = va + (vb - va) * t
		end
	end
	return out
end

local function desired_lod(state, seg, points, class_name, arc, aspect)
	local phase = points.phase
	local since = 999
	if seg and seg.emission_closed and seg.stop_frame then
		since = (state.time or 0) - seg.stop_frame
	end
	local desired = 0
	if phase == "emitting" or since <= 4 then
		desired = 0
	elseif class_name == "short" or class_name == "blob" or arc < 72 or (phase == "dissipating" and aspect < 1.2) then
		desired = 2
	elseif phase ~= "emitting" then
		desired = 1
	end
	if seg and seg.render_coarse and phase ~= "emitting" and since > 4 and desired < 2 then
		desired = desired + 1
	end
	if seg and seg.emission_closed and (seg.thermal_peak or 1) < 0.08 and (seg.residual or 0) > 0.02 then
		desired = 2
	end
	return desired
end

local function commit_lod(state, rec, desired)
	if rec.lod == nil then
		rec.lod = desired
		rec.lod_pending = desired
		rec.lod_hold = 0
		return rec.lod
	end
	if desired == rec.lod then
		rec.lod_hold = 0
		rec.lod_pending = desired
		return rec.lod
	end
	if rec.lod_pending ~= desired then
		rec.lod_pending = desired
		rec.lod_hold = 1
		return rec.lod
	end
	rec.lod_hold = (rec.lod_hold or 0) + 1
	local need = 5
	if desired > rec.lod then
		need = 2
	end
	if rec.lod_hold >= need then
		rec.lod = desired
		rec.lod_hold = 0
		state.lod_transition_count = (state.lod_transition_count or 0) + 1
		state.lod_transition_total = (state.lod_transition_total or 0) + 1
	end
	return rec.lod
end

local function carry_chain(dst, src)
	dst.segment_id = src.segment_id
	dst.phase = src.phase
	dst.wave_time = src.wave_time
	dst.closed_rear = src.closed_rear
	dst.direction = src.direction
	dst.visual_class = src.visual_class
	dst.rear_exposed = src.rear_exposed
	dst.front_gap = src.front_gap
	dst.piece_arc = src.piece_arc
	dst.piece_width = src.piece_width
	dst.piece = src.piece
	dst.piece_id = src.piece_id
	dst.split_reason = src.split_reason
	dst.lod = src.lod
	dst.area_ratio = src.area_ratio
	dst.residual = src.residual
	dst.dissipate_front = src.dissipate_front
	dst.area_hold = src.area_hold
	dst.area_origin = src.area_origin
	dst.segment_ref = src.segment_ref
	dst.force_compact = src.force_compact == true
end

local function decimate_view(points, stride)
	local n = #points
	if stride <= 1 or n <= 4 then
		return points, 1
	end
	local mark = {}
	mark[1] = true
	mark[n] = true
	for i = 1, n, stride do
		mark[i] = true
	end
	mark[n] = true
	for i = 2, n - 1 do
		local w = (points[i].ru or 0) + (points[i].rl or 0)
		local wp = (points[i - 1].ru or 0) + (points[i - 1].rl or 0)
		local wn = (points[i + 1].ru or 0) + (points[i + 1].rl or 0)
		if w >= wp and w >= wn and w > wp + 6 then
			mark[i] = true
		end
		local ax = points[i].x - points[i - 1].x
		local ay = points[i].y - points[i - 1].y
		local bx = points[i + 1].x - points[i].x
		local by = points[i + 1].y - points[i].y
		local al = math.sqrt(ax * ax + ay * ay)
		local bl = math.sqrt(bx * bx + by * by)
		if al > 1 and bl > 1 and (ax * bx + ay * by) / (al * bl) < 0.8 then
			mark[i] = true
		end
	end
	local function pack()
		local out = {}
		for i = 1, n do
			if mark[i] then
				out[#out + 1] = points[i]
			end
		end
		return out
	end
	local full = ribbon_area(points)
	local out = pack()
	local ratio = 1
	if full > 1 then
		ratio = ribbon_area(out) / full
		local guard = 0
		while ratio < 0.92 and guard < 6 do
			guard = guard + 1
			local best_i = nil
			local best_w = -1
			for i = 2, n - 1 do
				if not mark[i] then
					local w = (points[i].ru or 0) + (points[i].rl or 0)
					if w > best_w then
						best_w = w
						best_i = i
					end
				end
			end
			if not best_i then
				break
			end
			mark[best_i] = true
			out = pack()
			ratio = ribbon_area(out) / full
		end
	end
	local keys = KEEP_L1
	if stride >= 3 then
		keys = KEEP_L2
	end
	for i = 1, #out do
		local src = out[i].render_profile or out[i].temp_profile
		if src then
			out[i].render_profile = simplify_profile(src, keys)
		end
	end
	return out, ratio
end

local function leaving_view(points)
	if type(Game) ~= "function" or not points or #points < 1 then
		return false
	end
	local room = Game():GetRoom()
	if not room or not room.GetTopLeftPos or not room.GetBottomRightPos then
		return false
	end
	local tl = room:GetTopLeftPos()
	local br = room:GetBottomRightPos()
	if not tl or not br then
		return false
	end
	local margin = 64
	local left = (tl.X or 0) - margin
	local right = (br.X or 0) + margin
	local top = (tl.Y or 0) - margin
	local bottom = (br.Y or 0) + margin
	local mx = ((tl.X or 0) + (br.X or 0)) * 0.5
	local my = ((tl.Y or 0) + (br.Y or 0)) * 0.5
	local outside_n = 0
	local away_n = 0
	for i = 1, #points do
		local x = points[i].x or 0
		local y = points[i].y or 0
		local outside = x < left or x > right or y < top or y > bottom
		if not outside then
			return false
		end
		outside_n = outside_n + 1
		local vx = points[i].vx or 0
		local vy = points[i].vy or 0
		if (x - mx) * vx + (y - my) * vy > 0 then
			away_n = away_n + 1
		end
	end
	return outside_n == #points and away_n == #points
end

function stream.prepared_chains(state, cfg)
	if cfg.static_solid then
		local points = stream.static_chain(state, cfg)
		if #points >= 2 then
			return { points }
		end
		return {}
	end
	local spacing = cfg.spacing or 5
	if spacing < 3 then spacing = 3 end
	local raw = stream.chains(state)
	for _, seg in pairs(state.segments or {}) do
		seg.sim_light = false
		seg.visual_skip = false
		seg.length_diag = {
			chain_arc = 0,
			chain_n = 0,
			split_n = 0,
			gap_dropped = 0,
			thin_dropped = 0,
			view_skipped = 0,
			draw_dropped = 0,
			kept_arc = 0,
			kept_n = 0,
		}
	end
	local out = {}
	local stats = { n = 0, short = 0, blob = 0, fragment = 0, stream = 0 }
	local rows = {}
	for i = 1, #raw do
		local raw_chain = raw[i]
		local raw_seg = state.segments and state.segments[raw_chain.segment_id]
		local raw_diag = raw_seg and raw_seg.length_diag
		if raw_diag then
			raw_diag.chain_arc = raw_diag.chain_arc + chain_arc(raw_chain)
			raw_diag.chain_n = raw_diag.chain_n + #raw_chain
		end
		local pieces = split_long_gaps(raw_chain, 48, cfg.turn_extent or 80)
		if raw_diag then
			local covered = 0
			raw_diag.split_n = raw_diag.split_n + #pieces
			for p = 1, #pieces do
				covered = covered + #pieces[p]
			end
			raw_diag.gap_dropped = raw_diag.gap_dropped + (#raw_chain - covered)
		end
		for p = 1, #pieces do
			local piece = pieces[p]
			if piece and piece.phase ~= "emitting" and leaving_view(piece) then
				local skipped = state.segments and state.segments[piece.segment_id]
				if skipped then
					skipped.visual_skip = true
					if skipped.length_diag then
						skipped.length_diag.view_skipped = skipped.length_diag.view_skipped + 1
					end
				end
				piece = nil
			end
			if piece then
				if p == #pieces then
					taper_closed_tip(piece, cfg.closed_tip_width_scale or 0.90)
				end
				seal_lone_slice(piece)
				local anchor_id = piece[1] and piece[1].id
				local seg_known = state.segments and state.segments[piece.segment_id]
				local prev_rec = seg_known and seg_known.pieces and anchor_id and seg_known.pieces[anchor_id]
				local prev_lod = prev_rec and prev_rec.lod or 0
				local points
				local built_coarse = false
				if prev_lod >= 1 then
					local step = spacing * (prev_lod >= 2 and 4 or 2)
					if step > 24 then
						step = 24
					end
					local thin
					local rear_n = 4
					if rear_n > #piece then
						rear_n = #piece
					end
					if #piece > rear_n + 1 then
						local head = {}
						for n = 1, rear_n do
							head[n] = piece[n]
						end
						local rest = {}
						for n = rear_n, #piece do
							rest[#rest + 1] = piece[n]
						end
						local head_chain = resample(head, spacing)
						local rest_chain = resample(rest, step)
						thin = head_chain
						for n = 2, #rest_chain do
							thin[#thin + 1] = rest_chain[n]
						end
					else
						thin = resample(piece, spacing)
					end
					local full = ribbon_area(piece)
					local ratio = 1
					if full > 1 then
						ratio = ribbon_area(thin) / full
					end
					if ratio < 0.92 then
						points = hold_front(state, cfg, resample(piece, spacing), piece.segment_id)
						points.area_ratio = 1
					else
						points = hold_front(state, cfg, thin, piece.segment_id)
						points.area_ratio = ratio
						built_coarse = true
					end
				else
					points = hold_front(state, cfg, resample(piece, spacing), piece.segment_id)
					points.area_ratio = 1
				end
				points.segment_id = piece.segment_id
				points.phase = piece.phase
				points.closed_rear = piece.closed_rear
				points.direction = piece.direction
				local keep = #points >= 2
				local kept_seg = state.segments and state.segments[piece.segment_id]
				local kept_diag = kept_seg and kept_seg.length_diag
				if keep then
					if kept_diag then
						kept_diag.kept_arc = kept_diag.kept_arc + chain_arc(piece)
						kept_diag.kept_n = kept_diag.kept_n + 1
					end
					local is_tip = p == #pieces
					local rear_exposed = piece.closed_rear == true
					local front_gap = not is_tip
					local arc, local_w, aspect = piece_shape(built_coarse and piece or points)
					local seg_live = state.segments and state.segments[piece.segment_id]
					local class_name = "stream"
					local shape_n = #points
					if aspect <= 0.7 or shape_n <= 3 then
						class_name = "short"
					elseif aspect <= 1.5 and shape_n < 8 then
						class_name = "blob"
					elseif front_gap then
						class_name = "fragment"
					end
					if piece.force_compact then
						class_name = "short"
					end
					bind_piece(state, points, class_name, rear_exposed, front_gap, arc, local_w)
					local desired = desired_lod(state, seg_live, points, class_name, arc, aspect)
					local lod = 0
					local rec = points.piece
					if rec then
						lod = commit_lod(state, rec, desired)
					end
					local piece_rec = points.piece
					points.residual = seg_live and seg_live.residual or 0
					points.dissipate_front = seg_live and seg_live.dissipate_front or 0
					points.area_hold = piece_rec and piece_rec.outer_area_prev or 0
					points.area_origin = piece_rec and piece_rec.outer_area_0 or 0
					if points.area_hold < 1 and seg_live and (seg_live.outer_area_prev or 0) > 1 then
						points.area_hold = seg_live.outer_area_prev
						if (seg_live.outer_area_0 or 0) > (points.area_origin or 0) then
							points.area_origin = seg_live.outer_area_0
						end
					end
					points.segment_ref = seg_live
					points.force_compact = piece.force_compact == true
					points.lod = lod
					if not built_coarse then
						points.area_ratio = 1
					end
					local view = points
					local head_id = points[1] and points[1].id
					local tail_id = points[#points] and points[#points].id
					local simplified = false
					if lod >= 1 and not (built_coarse and lod == prev_lod) then
						local stride = lod >= 2 and 3 or 2
						local thin, ratio = decimate_view(points, stride)
						if #thin >= 2 and thin[1] and thin[1].id == head_id and thin[#thin] and thin[#thin].id == tail_id then
							carry_chain(thin, points)
							thin.lod = lod
							thin.area_ratio = ratio
							view = thin
							simplified = true
						end
					end
					if lod >= 1 and not simplified then
						local keys = lod >= 2 and KEEP_L2 or KEEP_L1
						for s = 1, #view do
							local src = view[s].render_profile or view[s].temp_profile
							if src then
								view[s].render_profile = simplify_profile(src, keys)
							end
						end
					end
					if seg_live and points.phase ~= "emitting" and (lod >= 2 or seg_live.render_coarse) then
						local since_close = 0
						if seg_live.stop_frame then
							since_close = (state.time or 0) - seg_live.stop_frame
						end
						if since_close > 16 then
							seg_live.sim_light = true
						end
					end
					stats.n = stats.n + 1
					stats[class_name] = (stats[class_name] or 0) + 1
					rows[#rows + 1] = {
						piece_id = points.piece_id,
						segment_id = points.segment_id,
						visual_class = class_name,
						split_reason = points.split_reason,
						rear_exposed = rear_exposed,
						front_gap = front_gap,
						phase = points.phase,
						arc = arc,
						width = local_w,
						lod = view.lod or 0,
						area_ratio = view.area_ratio or 1,
					}
					out[#out + 1] = view
				elseif kept_diag then
					kept_diag.draw_dropped = kept_diag.draw_dropped + 1
				end
			end
		end
	end
	for _, seg in pairs(state.segments or {}) do
		local bag = seg.pieces
		if bag then
			for anchor, rec in pairs(bag) do
				if rec.seen ~= (state.time or 0) then
					bag[anchor] = nil
				end
			end
		end
	end
	local counts = { 0, 0, 0 }
	local ratio_min = 1
	for i = 1, #rows do
		local level = rows[i].lod or 0
		if level < 0 then level = 0 end
		if level > 2 then level = 2 end
		counts[level + 1] = counts[level + 1] + 1
		local ratio = rows[i].area_ratio or 1
		if ratio < ratio_min then
			ratio_min = ratio
		end
	end
	local vertices = 0
	for i = 1, #out do
		vertices = vertices + #out[i]
	end
	state.render_vertices = vertices
	state.piece_stats = stats
	state.piece_rows = rows
	state.lod_counts = counts
	state.lod_area_ratio = ratio_min
	state.lod_component_count = #out
	table.sort(out, function(a, b)
		return (a.segment_id or 0) < (b.segment_id or 0)
	end)
	out.layer_memory = state.front_pin
	return out
end

return stream
