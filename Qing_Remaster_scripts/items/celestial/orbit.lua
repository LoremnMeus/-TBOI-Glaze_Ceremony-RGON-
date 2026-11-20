-- Closed rounded-rect HUD orbit: arc-length parameterization,
-- mid-point Voronoi ∩ radius intervals, blank-segment speed boost.
local ui = require("Qing_Remaster_scripts.auxiliary.ui")

local M = {}

M.LANE_INNER = "inner"
M.LANE_OUTER = "outer"

-- V1 debug baselines (not permanent balance freeze).
M.base_speed = 24 -- px/s
-- Speed multiplier while outside any node interval (invalid / blank arcs).
M.blank_mult = 2.5
M.margin_inner = 28
M.margin_outer = 14
M.corner_radius = 18
-- Half-width of a node trigger as a fraction of track length (also clamped by Voronoi mids).
M.node_radius_frac = 0.045

local function screen_size()
	return ui.GetScreenSize()
end

local function clamp(v, a, b)
	if v < a then return a end
	if v > b then return b end
	return v
end

--- Build 4 sides + 4 quarter-arcs as polyline samples for a lane.
local function build_poly(margin, corner)
	local ss = screen_size()
	local left = margin
	local top = margin
	local right = ss.X - margin
	local bottom = ss.Y - margin
	corner = math.min(corner, (right - left) * 0.25, (bottom - top) * 0.25)
	local pts = {}
	local function add(x, y)
		pts[#pts + 1] = Vector(x, y)
	end
	add(left + corner, top)
	add(right - corner, top)
	for i = 1, 6 do
		local a = -math.pi / 2 + (i / 6) * (math.pi / 2)
		add(right - corner + math.cos(a) * corner, top + corner + math.sin(a) * corner)
	end
	add(right, top + corner)
	add(right, bottom - corner)
	for i = 1, 6 do
		local a = 0 + (i / 6) * (math.pi / 2)
		add(right - corner + math.cos(a) * corner, bottom - corner + math.sin(a) * corner)
	end
	add(right - corner, bottom)
	add(left + corner, bottom)
	for i = 1, 6 do
		local a = math.pi / 2 + (i / 6) * (math.pi / 2)
		add(left + corner + math.cos(a) * corner, bottom - corner + math.sin(a) * corner)
	end
	add(left, bottom - corner)
	add(left, top + corner)
	for i = 1, 6 do
		local a = math.pi + (i / 6) * (math.pi / 2)
		add(left + corner + math.cos(a) * corner, top + corner + math.sin(a) * corner)
	end
	return pts
end

local function poly_metrics(pts)
	local seg = {}
	local total = 0
	for i = 1, #pts do
		local a = pts[i]
		local b = pts[(i % #pts) + 1]
		local d = a:Distance(b)
		seg[i] = {a = a, b = b, len = d, start = total}
		total = total + d
	end
	return seg, total
end

function M.build_track()
	local inner_pts = build_poly(M.margin_inner, M.corner_radius)
	local outer_pts = build_poly(M.margin_outer, M.corner_radius + 4)
	local inner_seg, inner_len = poly_metrics(inner_pts)
	local outer_seg, outer_len = poly_metrics(outer_pts)
	return {
		inner = {seg = inner_seg, length = math.max(1, inner_len), pts = inner_pts},
		outer = {seg = outer_seg, length = math.max(1, outer_len), pts = outer_pts},
		screen = screen_size(),
	}
end

local function lane_data(track, lane)
	if lane == M.LANE_OUTER then
		return track.outer
	end
	return track.inner
end

function M.get_length(track, lane)
	return lane_data(track, lane).length
end

function M.mod_distance(s, length)
	length = math.max(1, length or 1)
	s = tonumber(s) or 0
	-- Floor-wrap: unambiguous for negative s (e.g. -eps → length-eps).
	s = s - math.floor(s / length) * length
	if s < 0 then
		s = s + length
	elseif s >= length then
		s = s - length
	end
	return s
end

local function segment_at(track, distance, lane)
	local data = lane_data(track, lane)
	local s = M.mod_distance(distance, data.length)
	local segs = data.seg
	for i = 1, #segs do
		local g = segs[i]
		if s <= g.start + g.len or i == #segs then
			local t = 0
			if g.len > 0.001 then
				t = clamp((s - g.start) / g.len, 0, 1)
			end
			return g, t, s, data
		end
	end
	return segs[1], 0, 0, data
end

function M.position_at(track, distance, lane)
	local g, t, s = segment_at(track, distance, lane)
	if not g then
		return Vector(0, 0), 0
	end
	return Vector(
		g.a.X + (g.b.X - g.a.X) * t,
		g.a.Y + (g.b.Y - g.a.Y) * t
	), s
end

function M.tangent_at(track, distance, lane)
	local g = segment_at(track, distance, lane)
	if not g then
		return Vector(1, 0)
	end
	local dx = g.b.X - g.a.X
	local dy = g.b.Y - g.a.Y
	local len = math.sqrt(dx * dx + dy * dy)
	if len < 1e-4 then
		return Vector(1, 0)
	end
	return Vector(dx / len, dy / len)
end

function M.normal_at(track, distance, lane)
	local tan = M.tangent_at(track, distance, lane)
	return Vector(-tan.Y, tan.X)
end

function M.project(track, screen_pos, lane)
	local data = lane_data(track, lane)
	local best_s, best_d = 0, math.huge
	local segs = data.seg
	for i = 1, #segs do
		local g = segs[i]
		local abx = g.b.X - g.a.X
		local aby = g.b.Y - g.a.Y
		local len2 = abx * abx + aby * aby
		local t = 0
		if len2 > 0.001 then
			t = clamp(((screen_pos.X - g.a.X) * abx + (screen_pos.Y - g.a.Y) * aby) / len2, 0, 1)
		end
		local px = g.a.X + abx * t
		local py = g.a.Y + aby * t
		local dx = screen_pos.X - px
		local dy = screen_pos.Y - py
		local d = math.sqrt(dx * dx + dy * dy)
		if d < best_d then
			best_d = d
			best_s = g.start + t * g.len
		end
	end
	return best_s, best_d
end

local function interval_contains(it, s, length)
	if not it then
		return false
	end
	local begin_s = M.mod_distance(it.begin_s, length)
	local end_s = M.mod_distance(it.end_s, length)
	s = M.mod_distance(s, length)
	if begin_s <= end_s then
		return s >= begin_s and s <= end_s
	end
	-- wraps across 0
	return s >= begin_s or s <= end_s
end

local function target_own_radius(target, default_r)
	if target and type(target.own_radius) == "number" and target.own_radius > 0 then
		return target.own_radius
	end
	return default_r
end

local function target_claims_leftover(target)
	return target and target.claim_leftover == true
end

--- Build mid-point Voronoi ∩ radius intervals for projected targets.
--- Pass 1: each side claims min(own_radius, half_gap).
--- Pass 2: unused gap leftover goes to a neighbor with `claim_leftover`
--- (e.g. active eats the rest of the active↔coins gap); else stays blank.
function M.build_intervals(track, lane, targets, radius_frac)
	local length = M.get_length(track, lane)
	radius_frac = tonumber(radius_frac) or M.node_radius_frac
	local radius = length * radius_frac
	local nodes = {}
	for i = 1, #(targets or {}) do
		local t = targets[i]
		if t and t.anchor and t.visible ~= false then
			local s = M.project(track, t.anchor, lane)
			nodes[#nodes + 1] = {
				id = t.id,
				group = t.group,
				center_s = M.mod_distance(s, length),
				target = t,
			}
		end
	end
	table.sort(nodes, function(a, b)
		return a.center_s < b.center_s
	end)
	local intervals = {}
	local n = #nodes
	if n == 0 then
		return intervals, length
	end

	local gap_to_next = {}
	local back = {}
	local fwd = {}
	local node_r = {}
	for i = 1, n do
		local cur = nodes[i]
		local nxt = nodes[i == n and 1 or (i + 1)]
		local gap = M.mod_distance(nxt.center_s - cur.center_s, length)
		gap_to_next[i] = gap
		node_r[i] = target_own_radius(cur.target, radius)
		fwd[i] = math.min(node_r[i], gap * 0.5)
	end
	for i = 1, n do
		local prev_i = i == 1 and n or (i - 1)
		back[i] = math.min(node_r[i], gap_to_next[prev_i] * 0.5)
	end

	-- Leftover middle → claim_leftover neighbor (active); else blank accelerate.
	for i = 1, n do
		local nxt_i = i == n and 1 or (i + 1)
		local leftover = gap_to_next[i] - fwd[i] - back[nxt_i]
		if leftover > 1e-4 then
			if target_claims_leftover(nodes[i].target) then
				fwd[i] = fwd[i] + leftover
			elseif target_claims_leftover(nodes[nxt_i].target) then
				back[nxt_i] = back[nxt_i] + leftover
			end
		end
	end

	for i = 1, n do
		local cur = nodes[i]
		intervals[#intervals + 1] = {
			id = cur.id,
			group = cur.group,
			center_s = cur.center_s,
			begin_s = M.mod_distance(cur.center_s - back[i], length),
			end_s = M.mod_distance(cur.center_s + fwd[i], length),
			target = cur.target,
		}
	end
	return intervals, length
end

function M.interval_at(intervals, s, length)
	for i = 1, #intervals do
		local it = intervals[i]
		if interval_contains(it, s, length) then
			return it
		end
	end
	return nil
end

local function ahead_dist(s, bound, length, forward)
	if forward then
		return M.mod_distance(bound - s, length)
	end
	return M.mod_distance(s - bound, length)
end

--- Next boundary along motion: leaving current interval, or entering next.
local function next_boundary(intervals, s, length, forward)
	local cur = M.interval_at(intervals, s, length)
	if cur then
		-- Leaving current: forward exits at end_s; reverse exits at begin_s.
		return forward and cur.end_s or cur.begin_s, cur
	end
	local best, best_bound = nil, nil
	for i = 1, #(intervals or {}) do
		local it = intervals[i]
		-- Entering next: forward hits begin_s; reverse hits end_s.
		local bound = forward and it.begin_s or it.end_s
		local d = ahead_dist(s, bound, length, forward)
		if d > 1e-3 and (best == nil or d < best) then
			best = d
			best_bound = bound
		end
	end
	return best_bound, nil
end

--- Advance along track with blank-speed segmentation.
--- Outside any interval → `blank_mult`. `forward` false = reverse (Rahu).
function M.advance(track, lane, from_s, dt_sec, intervals, forward)
	if forward == nil then
		forward = true
	end
	local length = M.get_length(track, lane)
	from_s = M.mod_distance(from_s, length)
	dt_sec = math.max(0, tonumber(dt_sec) or 0)
	if dt_sec <= 0 then
		return from_s, {}
	end
	local remaining = dt_sec
	local s = from_s
	local samples = {{s = s, blank = M.interval_at(intervals, s, length) == nil}}
	local guard = 0
	while remaining > 1e-4 and guard < 32 do
		guard = guard + 1
		local cur = M.interval_at(intervals, s, length)
		local blank = cur == nil
		local speed = M.base_speed * (blank and M.blank_mult or 1)
		local next_bound = next_boundary(intervals, s, length, forward)
		if next_bound == nil then
			local step_d = speed * remaining
			if forward then
				s = M.mod_distance(s + step_d, length)
			else
				s = M.mod_distance(s - step_d, length)
			end
			samples[#samples + 1] = {s = s, blank = M.interval_at(intervals, s, length) == nil}
			break
		end
		local dist_to_bound = ahead_dist(s, next_bound, length, forward)
		if dist_to_bound < 1e-3 then
			dist_to_bound = 0.01
		end
		local time_to_bound = dist_to_bound / math.max(0.01, speed)
		local step_t = math.min(remaining, time_to_bound)
		local step_d = speed * step_t
		if forward then
			s = M.mod_distance(s + step_d, length)
		else
			s = M.mod_distance(s - step_d, length)
		end
		remaining = remaining - step_t
		samples[#samples + 1] = {
			s = s,
			blank = M.interval_at(intervals, s, length) == nil,
			crossed_id = cur and cur.id or nil,
		}
	end
	return s, samples
end

function M.query_crossings(intervals, from_s, to_s, length, reverse)
	local hits = {}
	if not intervals or #intervals == 0 then
		return hits
	end
	local forward = not reverse
	from_s = M.mod_distance(from_s, length)
	to_s = M.mod_distance(to_s, length)
	local travel = ahead_dist(from_s, to_s, length, forward)
	if travel < 1e-4 then
		return hits
	end
	for i = 1, #intervals do
		local it = intervals[i]
		local enter = forward and it.begin_s or it.end_s
		local dist_enter = ahead_dist(from_s, enter, length, forward)
		if dist_enter > 1e-4 and dist_enter <= travel + 1e-4 then
			local was_inside = interval_contains(it, from_s, length)
			if not was_inside then
				hits[#hits + 1] = {
					id = it.id,
					group = it.group,
					interval = it,
					at_s = enter,
					dist = dist_enter,
				}
			end
		end
	end
	table.sort(hits, function(a, b)
		return a.dist < b.dist
	end)
	return hits
end

function M.is_blank(intervals, s, length)
	return M.interval_at(intervals, s, length) == nil
end

--- Arc-length range of the straight top edge (first polyline segment).
--- Returns begin_s, end_s, length (non-wrapping for the default track).
function M.top_straight_range(track, lane)
	local data = lane_data(track, lane)
	local length = math.max(1, data.length or 1)
	local seg0 = data.seg and data.seg[1]
	if not seg0 then
		return 0, 0, length
	end
	local begin_s = tonumber(seg0.start) or 0
	local end_s = begin_s + math.max(0, tonumber(seg0.len) or 0)
	return begin_s, end_s, length
end

local function push_covered_overlap(covered, a, b)
	if b - a > 1e-4 then
		covered[#covered + 1] = {a = a, b = b}
	end
end

--- Overlap of a (possibly wrapping) interval with a non-wrapping [range_begin, range_end].
local function collect_interval_overlap(it, length, range_begin, range_end, covered)
	local begin_s = M.mod_distance(it.begin_s, length)
	local end_s = M.mod_distance(it.end_s, length)
	if begin_s <= end_s then
		push_covered_overlap(
			covered,
			math.max(begin_s, range_begin),
			math.min(end_s, range_end)
		)
	else
		-- wraps across 0: [begin, length) U [0, end]
		push_covered_overlap(
			covered,
			math.max(begin_s, range_begin),
			math.min(length, range_end)
		)
		push_covered_overlap(
			covered,
			math.max(0, range_begin),
			math.min(end_s, range_end)
		)
	end
end

--- Fill uncovered leftovers inside a non-wrapping [range_begin, range_end].
--- `make_interval(begin_s, end_s, index)` returns an interval table (or nil to skip).
--- Does not claim outside the range; never shrinks existing intervals.
function M.append_gap_intervals(intervals, length, range_begin, range_end, make_interval)
	intervals = intervals or {}
	length = math.max(1, tonumber(length) or 1)
	range_begin = tonumber(range_begin) or 0
	range_end = tonumber(range_end) or 0
	if range_end - range_begin <= 1e-3 or type(make_interval) ~= "function" then
		return intervals
	end
	local covered = {}
	for i = 1, #intervals do
		collect_interval_overlap(intervals[i], length, range_begin, range_end, covered)
	end
	table.sort(covered, function(a, b)
		return a.a < b.a
	end)
	local merged = {}
	for i = 1, #covered do
		local c = covered[i]
		local last = merged[#merged]
		if last and c.a <= last.b + 1e-4 then
			if c.b > last.b then
				last.b = c.b
			end
		else
			merged[#merged + 1] = {a = c.a, b = c.b}
		end
	end
	local cursor = range_begin
	local index = 0
	local min_gap = math.max(2, length * 0.004)
	local function emit(a, b)
		if b - a < min_gap then
			return
		end
		index = index + 1
		local it = make_interval(a, b, index)
		if it then
			intervals[#intervals + 1] = it
		end
	end
	for i = 1, #merged do
		local m = merged[i]
		emit(cursor, m.a)
		cursor = math.max(cursor, m.b)
	end
	emit(cursor, range_end)
	return intervals
end

return M
