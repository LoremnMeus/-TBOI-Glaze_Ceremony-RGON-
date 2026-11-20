-- One continuous outline per color. Inner layers stay inside the outer edge.
-- Normals come from the local tangent, not from a single attack vector.

local C = require("Qing_Remaster_scripts.items.incandescence_flame.constants")
local geom = require("Qing_Remaster_scripts.items.incandescence_flame.flame_geometry")

local regions = {}

local LAYERS = {
	{ key = "outer", frac = 1, fall_start = 0.9, fall_end = 1.02, r = C.COLOR.outer.r, g = C.COLOR.outer.g, b = C.COLOR.outer.b },
	{ key = "orange", frac_key = "orange_frac", fall_start = 0.84, fall_end = 0.98, r = C.COLOR.orange.r, g = C.COLOR.orange.g, b = C.COLOR.orange.b },
	{ key = "gold", frac_key = "gold_frac", fall_start = 0.7, fall_end = 0.9, r = C.COLOR.gold.r, g = C.COLOR.gold.g, b = C.COLOR.gold.b },
	{ key = "white", frac_key = "white_frac", fall_start = 0.42, fall_end = 0.72, r = C.COLOR.white.r, g = C.COLOR.white.g, b = C.COLOR.white.b },
}

local function smooth(u)
	if u < 0 then u = 0 end
	if u > 1 then u = 1 end
	return u * u * (3 - 2 * u)
end

local function falloff(s, length, start_u, end_u)
	local u = 0
	if length > 0 then
		u = s / length
	end
	if u <= start_u then
		return 1
	end
	if u >= end_u then
		return 0
	end
	return 1 - smooth((u - start_u) / (end_u - start_u))
end

local function base_half(s, cfg)
	local u = 0
	if cfg.length > 0 then
		u = s / cfg.length
	end
	if u < 0 then u = 0 end
	if u > 1 then u = 1 end
	return cfg.mouth_width + (cfg.half_width - cfg.mouth_width) * smooth(u)
end

local function bell(d, radius)
	if radius < 1 then radius = 1 end
	local u = d / radius
	if u <= -1 or u >= 1 then
		return 0
	end
	return 0.5 * (1 + math.cos(math.pi * u))
end

local function life_of(age)
	local life = 1
	if age < 0.12 then life = age / 0.12 end
	if age > 0.84 then life = (1 - age) / 0.16 end
	if life < 0 then life = 0 end
	return life
end

local function center_of(time, speed, stagger, shift, cycle)
	local c = (time * speed + stagger + shift) % cycle
	if c < 0 then c = c + cycle end
	return c
end

local function prepare_motion(time, cfg)
	local motion = {
		events = {},
		wave_count = 0,
		tongue_attached = 0,
		bulges = {},
		mid = {},
		tongues = {},
	}
	if cfg.static_solid then
		return motion
	end
	local cycle = cfg.length
	if cycle < 40 then cycle = 40 end
	local speed = cfg.bulge_speed or 11
	local count = math.floor((cfg.bulge_count or 4) + 0.5)
	if count < 3 then count = 3 end
	if count > 5 then count = 5 end
	local density = cfg.tongue_density or 0.45
	local tongue_n = 2
	if density > 0.66 then
		tongue_n = 4
	elseif density > 0.33 then
		tongue_n = 3
	end
	for side = 0, 1 do
		local shift = side * cycle * 0.41
		for i = 1, count do
			local stagger = (i - 1) / count * cycle
			local center = center_of(time, speed, stagger, shift, cycle)
			local prev = center_of(time - 1, speed, stagger, shift, cycle)
			local life = life_of(center / cycle)
			if life > 0.25 then
				motion.wave_count = motion.wave_count + 1
			end
			motion.bulges[#motion.bulges + 1] = {
				side = side,
				center = center,
				radius = 39,
				amp = cfg.bulge_amp or 0.16,
				life = life,
			}
			if prev < cycle * 0.62 and center >= cycle * 0.62 and center - prev < cycle * 0.5 and life > 0.2 then
				motion.events[#motion.events + 1] = { role = "spark", side = side, s = center }
			end
		end
		for i = 1, 3 do
			local stagger = (i - 0.5) / 3 * cycle
			local center = center_of(time, speed * 1.25, stagger, shift + cycle * 0.17, cycle)
			motion.mid[#motion.mid + 1] = {
				side = side,
				center = center,
				radius = 18,
				amp = cfg.mid_amp or 0.07,
				life = life_of(center / cycle),
			}
		end
		for i = 1, tongue_n do
			local stagger = (i - 0.5) / tongue_n * cycle
			local center = center_of(time, speed * 0.85, stagger, side * cycle * 0.23 + 40, cycle)
			local prev = center_of(time - 1, speed * 0.85, stagger, side * cycle * 0.23 + 40, cycle)
			local life = life_of(center / cycle)
			if life > 0.3 then
				motion.tongue_attached = motion.tongue_attached + 1
			end
			motion.tongues[#motion.tongues + 1] = {
				side = side,
				center = center,
				radius = 24,
				amp = 0.12 + 0.2 * density,
				life = life,
			}
			if prev < cycle * 0.9 and center >= cycle * 0.9 and center - prev < cycle * 0.5 then
				motion.events[#motion.events + 1] = { role = "flame", side = side, s = center }
			end
		end
	end
	return motion
end

local function bump_sum(s, side, list)
	local sum = 0
	for i = 1, #list do
		local item = list[i]
		if item.side == side then
			sum = sum + bell(s - item.center, item.radius) * item.amp * item.life
		end
	end
	return sum
end

local function head_shape(s, cfg, time, side)
	local length = cfg.length
	if length < 1 then
		return 1, 0
	end
	local u = s / length
	if u <= 0.82 then
		return 1, 0
	end
	local h = (u - 0.82) / 0.18
	if h > 1 then h = 1 end
	local lead = math.sin(time * 0.11 + side * 1.7)
	local decay = smooth(h) * (0.62 - 0.2 * lead)
	if decay < 0.12 then decay = 0.12 end
	if decay > 0.88 then decay = 0.88 end
	local curl = cfg.head_curl or 0.65
	local lean = h * h * (6 + 12 * curl) * (0.3 + 0.7 * math.max(lead, 0))
	return 1 - decay, lean
end

local function dynamic_outer(s, time, cfg, side, motion)
	local base = base_half(s, cfg)
	local travel = s - time * (cfg.bulge_speed or 11) * 0.65
	local n = geom.noise(travel * 0.07, side * 3 + 1, 23) - 0.5
	local mul = 1 + bump_sum(s, side, motion.bulges) + bump_sum(s, side, motion.mid) + bump_sum(s, side, motion.tongues) + n * 2 * (cfg.edge_amp or 0.02)
	if mul < 0.62 then mul = 0.62 end
	if mul > 1.4 then mul = 1.4 end
	local scale, lean = head_shape(s, cfg, time, side)
	return base * mul * scale, lean
end

local function stamp_event(motion, side, s, x, y, nx, ny, tx, ty)
	for i = 1, #motion.events do
		local event = motion.events[i]
		if not event.x and event.side == side and math.abs((event.s or 0) - s) < 14 then
			event.x = x
			event.y = y
			event.nx = nx
			event.ny = ny
			event.vx = tx * 6 + nx * 1.6
			event.vy = ty * 6 + ny * 1.6
		end
	end
end

local function with_frame(points)
	local out = {}
	local arc = 0
	for i = 1, #points do
		local p = points[i]
		local tx, ty = 1, 0
		local function span(a, b)
			if not a or not b or not a.x or not b.x then
				return 81
			end
			local dx = b.x - a.x
			local dy = b.y - a.y
			return math.sqrt(dx * dx + dy * dy)
		end
		local back = i > 1 and span(points[i - 1], p) or 81
		local fore = i < #points and span(p, points[i + 1]) or 81
		local use_back = back <= 80
		local use_fore = fore <= 80
		if use_back and use_fore then
			tx = points[i + 1].x - points[i - 1].x
			ty = points[i + 1].y - points[i - 1].y
		elseif use_fore then
			tx = points[i + 1].x - p.x
			ty = points[i + 1].y - p.y
		elseif use_back then
			tx = p.x - points[i - 1].x
			ty = p.y - points[i - 1].y
		elseif i > 1 and i < #points then
			if back <= fore then
				tx = p.x - points[i - 1].x
				ty = p.y - points[i - 1].y
			else
				tx = points[i + 1].x - p.x
				ty = points[i + 1].y - p.y
			end
		elseif i < #points then
			tx = points[i + 1].x - p.x
			ty = points[i + 1].y - p.y
		elseif i > 1 then
			tx = p.x - points[i - 1].x
			ty = p.y - points[i - 1].y
		end
		if i > 1 then
			local dx = p.x - points[i - 1].x
			local dy = p.y - points[i - 1].y
			arc = arc + math.sqrt(dx * dx + dy * dy)
		end
		local len = math.sqrt(tx * tx + ty * ty)
		if len < 0.0001 then
			tx, ty = 1, 0
		else
			tx, ty = tx / len, ty / len
		end
		out[i] = {
			x = p.x,
			y = p.y,
			tx = tx,
			ty = ty,
			nx = -ty,
			ny = tx,
			heat = p.heat or 1,
			s = p.travel ~= nil and p.travel or arc,
			ru = p.ru,
			rl = p.rl,
			extra_u = p.extra_u or 0,
			extra_l = p.extra_l or 0,
			lean_u = p.lean_u or 0,
			lean_l = p.lean_l or 0,
			temperature = p.temperature or p.heat or 1,
			age = p.age or 0,
			vx = p.vx or 0,
			vy = p.vy or 0,
			id = p.id,
			from_rear = p.from_rear or 0,
			release_s = p.release_s or p.from_rear or 0,
			temp_profile = p.temp_profile,
			render_profile = p.render_profile,
			sway_phase = p.sway_phase,
			form = p.form,
			segment_id = p.segment_id or points.segment_id,
		}
	end
	local raw_tx = {}
	local raw_ty = {}
	for i = 1, #out do
		raw_tx[i] = out[i].tx
		raw_ty[i] = out[i].ty
	end
	for i = 2, #out - 1 do
		local function span(a, b)
			if not a or not b or not a.x or not b.x then
				return 81
			end
			local dx = b.x - a.x
			local dy = b.y - a.y
			return math.sqrt(dx * dx + dy * dy)
		end
		local function align(ax, ay)
			if ax * raw_tx[i] + ay * raw_ty[i] < 0 then
				return -ax, -ay
			end
			return ax, ay
		end
		local ax, ay = 0, 0
		local bx, by = 0, 0
		if span(points[i - 1], points[i]) <= 80 then
			ax, ay = align(raw_tx[i - 1], raw_ty[i - 1])
		end
		if span(points[i], points[i + 1]) <= 80 then
			bx, by = align(raw_tx[i + 1], raw_ty[i + 1])
		end
		local tx = ax + raw_tx[i] * 2 + bx
		local ty = ay + raw_ty[i] * 2 + by
		local len = math.sqrt(tx * tx + ty * ty)
		if len > 0.0001 then
			out[i].tx = tx / len
			out[i].ty = ty / len
			out[i].nx = -out[i].ty
			out[i].ny = out[i].tx
		end
	end
	out.segment_id = points.segment_id
	out.closed_rear = points.closed_rear == true
	out.phase = points.phase
	out.wave_time = points.wave_time
	out.piece_id = points.piece_id
	out.visual_class = points.visual_class
	out.rear_exposed = points.rear_exposed == true
	out.front_gap = points.front_gap == true
	out.piece_arc = points.piece_arc
	out.piece_width = points.piece_width
	out.piece = points.piece
	out.split_reason = points.split_reason
	out.lod = points.lod or 0
	out.area_ratio = points.area_ratio or 1
	out.residual = points.residual or 0
	out.dissipate_front = points.dissipate_front or 0
	out.area_hold = points.area_hold or 0
	out.area_origin = points.area_origin or 0
	out.segment_ref = points.segment_ref
	out.piece = points.piece
	out.force_compact = points.force_compact == true
	return out
end

local LAYER_ID = { outer = 1, orange = 2, gold = 3, white = 4 }

local function smooth01(u)
	if u < 0 then u = 0 end
	if u > 1 then u = 1 end
	return u * u * (3 - 2 * u)
end

local function layer_wave(s, time, key, amount)
	local freq = key == "outer" and 0.05 or key == "orange" and 0.012 or key == "gold" and 0.018 or 0.04
	local speed = key == "outer" and 0.12 or key == "orange" and 0.04 or key == "gold" and 0.03 or 0.05
	local amp = key == "outer" and 0.22 or key == "orange" and 0.07 or key == "gold" and 0.05 or 0.035
	local seed = key == "gold" and 11 or key == "white" and 17 or 4
	local n = geom.noise(s * freq - time * speed, (LAYER_ID[key] or 1) + seed, seed)
	return (n - 0.5) * 2 * amp * (amount or 1)
end

local function front_u(dist, length)
	if not length or length <= 0 or dist >= length then
		return 0
	end
	return smooth01(1 - dist / length)
end

local function clamp_num(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

local function front_extent(key, side, u, seed, cfg)
	if u <= 0 then
		return 0
	end
	local reach = cfg.front_reach or 1
	local bloom = cfg.front_bloom or 1
	local phase = cfg and cfg.front_phase
	local asym_wob = phase and math.sin(phase) or ((geom.hash01(seed, 2, 9) - 0.5) * 2)
	local asym = ((cfg.front_asym or 0.35) * asym_wob)
	local base = { outer = 3, orange = 1, gold = -2, white = -6 }
	local amp = { outer = 3, orange = 2, gold = 1, white = 0.6 }
	local wob = phase and math.sin(phase + side * 1.7) or ((geom.hash01(seed, side + 5, LAYER_ID[key] or 1) - 0.5) * 2)
	local side_sign = side == 0 and 1 or -1
	local ext = ((base[key] or 0) + (amp[key] or 0) * wob * bloom + asym * side_sign * 2.5) * u * reach
	if ext > 8 then ext = 8 end
	if ext < -10 then ext = -10 end
	return ext
end

local function layer_factor(key, temp, wave, progress)
	if progress < 0 then progress = 0 end
	if progress > 1 then progress = 1 end
	local u = smooth01(progress)
	local tail = 0
	if progress > 0.75 then
		tail = smooth01((progress - 0.75) / 0.25)
	end
	if key == "outer" then
		return clamp_num(1 + wave * 1.15, 0.82, 1.28)
	end
	if key == "orange" then
		local base = 0.86 + (0.70 - 0.86) * u - 0.04 * tail
		local f = base + 0.02 * (temp - 0.5) + wave * 0.035
		return clamp_num(f, 0.62, 0.90)
	end
	if key == "gold" then
		local base = 0.58 + (0.36 - 0.58) * u - 0.10 * tail
		local f = base + 0.02 * (temp - 0.5) + wave * 0.035
		return clamp_num(f, 0.16, 0.60)
	end
	local base = 0.12 + (0.06 - 0.12) * u
	local f = (base + 0.012 * (temp - 0.5) + wave * 0.01) * (1 - 0.7 * tail)
	return clamp_num(f, 0, 0.13)
end

local function lobe(t, center, width)
	local u = (t - center) / width
	return math.exp(-u * u * 1.15)
end

local function single_peak_shape(t, peak_position)
	local span = peak_position
	if t >= peak_position then
		span = 1 - peak_position
	end
	if span < 0.05 then
		span = 0.05
	end
	local u = (t - peak_position) / span
	local bell = 1 - u * u
	if bell < 0 then
		bell = 0
	end
	return bell * bell * (3 - 2 * bell)
end

local function build_cap(up, lo, tx, ty, seed, key, cfg, time)
	local dx = lo.x - up.x
	local dy = lo.y - up.y
	local width = math.sqrt(dx * dx + dy * dy)
	local frac = (C.CAP_DEPTH and C.CAP_DEPTH[key]) or 0.22
	local depth = width * frac * (cfg.front_bloom or 1)
	local limit = (C.CAP_DEPTH_MAX and C.CAP_DEPTH_MAX[key]) or 48
	if depth > limit then depth = limit end
	if depth < 1.5 then depth = 1.5 end
	local count = key == "outer" and 9 or key == "orange" and 8 or key == "gold" and 7 or 5
	local phase = up.sway_phase
	if not phase then
		phase = ((seed or 1) % 97) * 0.07
	end
	local drift = math.sin(phase) * 0.06
	local legacy = cfg.cap_multi_peak == true
	local peak_position = 0.52 + drift
	if peak_position < 0.38 then peak_position = 0.38 end
	if peak_position > 0.62 then peak_position = 0.62 end
	local main_c = 0.58 + drift
	local upper_c = 0.22 + drift * 0.4
	local caps = {}
	local shapes = {}
	local peak = 0.001
	for i = 1, count do
		local t = i / (count + 1)
		local shape
		if legacy then
			shape = lobe(t, main_c, 0.20) + 0.78 * lobe(t, upper_c, 0.09) + 0.30 * lobe(t, 0.84, 0.11) - 0.24 * lobe(t, 0.97, 0.055)
			if shape < 0 then shape = 0 end
		else
			shape = single_peak_shape(t, peak_position)
		end
		shapes[i] = shape
		if shape > peak then peak = shape end
	end
	local nx = -ty
	local ny = tx
	for i = 1, count do
		local t = i / (count + 1)
		local hump = depth * (shapes[i] / peak)
		local side = 0
		if legacy then
			side = (geom.hash01(seed, i + 3, LAYER_ID[key] or 1) - 0.5) * math.min(width * 0.035, 2.5)
		end
		caps[i] = {
			x = up.x + dx * t + tx * hump + nx * side,
			y = up.y + dy * t + ty * hump + ny * side,
		}
	end
	return caps
end

local function prepare_head(frame)
	local n = #frame
	if n < 2 then
		return
	end
	local dist = {}
	dist[n] = 0
	for i = n - 1, 1, -1 do
		local dx = frame[i + 1].x - frame[i].x
		local dy = frame[i + 1].y - frame[i].y
		dist[i] = dist[i + 1] + math.sqrt(dx * dx + dy * dy)
	end
	local width_ref = 0
	for i = n, 1, -1 do
		local w = (frame[i].ru or 0) + (frame[i].rl or 0) + (frame[i].extra_u or 0) + (frame[i].extra_l or 0)
		if w > width_ref then
			width_ref = w
		end
		if dist[i] > 28 then
			break
		end
	end
	local length = width_ref * 0.85
	if length < 30 then length = 30 end
	if length > 55 then length = 55 end
	local total = dist[1] or 0
	if total < length then
		length = math.max(12, total * 0.7)
	end
	local tip = frame[n]
	local front_i = n
	for i = 1, n do
		frame[i].dist_to_tip = dist[i]
		frame[i].chain_span = total
	end
	for i = 1, n do
		if dist[i] <= length then
			front_i = i
			break
		end
	end
	frame.head_length = length
	frame.head_width = width_ref
	frame.front_index = front_i
	frame.front_seed = tip.form or tip.id or tip.age or 1
	frame.sway_phase = tip.sway_phase or 0
	frame.head_taper = { x = frame[front_i].x, y = frame[front_i].y }
	frame.head_tip = {
		x = tip.x,
		y = tip.y,
		vx = tip.vx or 0,
		vy = tip.vy or 0,
		temp = tip.temperature or tip.heat or 1,
	}
end

local function edge_cross(a, b, c)
	return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
end

local function proper_cross(a, b, c, d)
	if not a or not b or not c or not d then
		return false
	end
	if not a.x or not b.x or not c.x or not d.x then
		return false
	end
	if a.x ~= a.x or b.x ~= b.x or c.x ~= c.x or d.x ~= d.x then
		return false
	end
	local ab_c = edge_cross(a, b, c)
	local ab_d = edge_cross(a, b, d)
	local cd_a = edge_cross(c, d, a)
	local cd_b = edge_cross(c, d, b)
	return ab_c * ab_d < 0 and cd_a * cd_b < 0
end

local function outline_of(upper, lower)
	local poly = {}
	for i = 1, #upper do
		poly[#poly + 1] = upper[i]
	end
	for i = #lower, 1, -1 do
		poly[#poly + 1] = lower[i]
	end
	return poly
end

local function audit_local(upper, lower)
	local folds = 0
	local tests = 0
	local hit = false
	local n = #upper
	if #lower < n then
		n = #lower
	end
	for i = 1, n - 1 do
		local u0, u1 = upper[i], upper[i + 1]
		local l0, l1 = lower[i], lower[i + 1]
		if u0 and u1 and l0 and l1 and u0.x and u1.x and l0.x and l1.x and u0.heat_open ~= false and u1.heat_open ~= false then
		tests = tests + 2
		if proper_cross(u0, u1, l0, l1) then
			hit = true
		end
		if proper_cross(u0, l0, u1, l1) then
			hit = true
		end
		local abx = u1.x - u0.x
		local aby = u1.y - u0.y
		local bcx = l1.x - l0.x
		local bcy = l1.y - l0.y
		local ab = math.sqrt(abx * abx + aby * aby)
		local bc = math.sqrt(bcx * bcx + bcy * bcy)
		if ab > 0.5 and bc > 0.5 then
			local dot = (abx * bcx + aby * bcy) / (ab * bc)
			if dot < -0.2 then
				folds = folds + 1
			end
		end
		end
	end
	return folds, hit, tests
end

local function audit_full(upper, lower)
	local poly = outline_of(upper, lower)
	local n = #poly
	local tests = 0
	local hit = false
	for i = 1, n do
		local a = poly[i]
		local b = poly[i % n + 1]
		for j = i + 2, n do
			local jn = j % n + 1
			if not (i == 1 and j == n) and jn ~= i then
				tests = tests + 1
				local c = poly[j]
				local d = poly[jn]
				if proper_cross(a, b, c, d) then
					hit = true
					return hit, tests, tostring(i) .. "-" .. tostring(j)
				end
			end
		end
	end
	return hit, tests
end

local PARENT_LAYER = { orange = "outer", gold = "orange", white = "gold" }
local HEAT_N = 9
local HEAT_CUT = { outer = 0.08, orange = 0.20, gold = 0.40, white = 0.62 }

local function heat_u(index)
	return (index - 1) / (HEAT_N - 1) * 2 - 1
end

local function heat_lateral(u, ru, rl)
	if u >= 0 then
		return u * (ru or 0)
	end
	return u * (rl or 0)
end

local function heat_sample(profile, index)
	local v = profile and profile[index] or 0
	if v ~= v or v == math.huge or v == -math.huge then
		return 0
	end
	if v < 0 then return 0 end
	if v > 1 then return 1 end
	return v
end

function regions.primary_heat_offsets(profile, ru, rl, threshold)
	if not threshold then
		threshold = 0.2
	end
	local peak_i = 1
	local peak = -1
	for i = 1, HEAT_N do
		local t = heat_sample(profile, i)
		if t > peak then
			peak = t
			peak_i = i
		end
	end
	if peak < threshold then
		local collapsed = heat_lateral(heat_u(peak_i), ru, rl)
		return collapsed, collapsed, false, false, peak
	end
	local lo = peak_i
	while lo > 1 and heat_sample(profile, lo - 1) >= threshold do
		lo = lo - 1
	end
	local hi = peak_i
	while hi < HEAT_N and heat_sample(profile, hi + 1) >= threshold do
		hi = hi + 1
	end
	local function edge_low()
		if lo <= 1 then
			return heat_u(1)
		end
		local t0 = heat_sample(profile, lo - 1)
		local t1 = heat_sample(profile, lo)
		local denom = t1 - t0
		local frac = 0
		if denom ~= 0 then
			frac = (threshold - t0) / denom
		end
		if frac < 0 then frac = 0 end
		if frac > 1 then frac = 1 end
		return heat_u(lo - 1) + (heat_u(lo) - heat_u(lo - 1)) * frac
	end
	local function edge_high()
		if hi >= HEAT_N then
			return heat_u(HEAT_N)
		end
		local t0 = heat_sample(profile, hi)
		local t1 = heat_sample(profile, hi + 1)
		local denom = t1 - t0
		local frac = 0
		if denom ~= 0 then
			frac = (threshold - t0) / denom
		end
		if frac < 0 then frac = 0 end
		if frac > 1 then frac = 1 end
		return heat_u(hi) + (heat_u(hi + 1) - heat_u(hi)) * frac
	end
	local split = false
	for i = 1, HEAT_N do
		if (i < lo or i > hi) and heat_sample(profile, i) >= threshold then
			split = true
		end
	end
	local u_lo = edge_low()
	local u_hi = edge_high()
	if u_hi < u_lo then
		u_hi = u_lo
	end
	return heat_lateral(u_hi, ru, rl), heat_lateral(u_lo, ru, rl), split, true, peak
end

local function vis_slot(built, id)
	if not built or not id then
		return nil
	end
	built.segment_vis = built.segment_vis or {}
	local slot = built.segment_vis[id]
	if not slot then
		slot = {
			segment_id = id,
			outer_heat_open_count = 0,
			residual_open_count = 0,
			generated_polygon_count = 0,
			core_polygon_count = 0,
			residual_candidate_count = 0,
			residual_run_count = 0,
			residual_reject_reason = "",
			thermal_area = 0,
			residual_area = 0,
			visible_outer_area = 0,
			temperature_threshold_failures = 0,
			geometry_failures = 0,
			geometry_failures_drawn = 0,
			raster_skips = 0,
			offscreen_clips = 0,
			submitted_raster_intervals = 0,
			invisible_reason = "",
		}
		built.segment_vis[id] = slot
	end
	return slot
end

local function note_layer_draw(slot, key, frame, upper, lower)
	if not slot or not key or not upper or not frame then
		return
	end
	local n = #upper
	if n < 1 or #frame < 1 then
		return
	end
	local want = {}
	want[1] = true
	want[n] = true
	local prev_open = nil
	for i = 1, n do
		local up = upper[i]
		local open = up and up.heat_open ~= false
		if prev_open ~= nil and open ~= prev_open then
			want[i] = true
			if i > 1 then
				want[i - 1] = true
			end
		end
		prev_open = open
	end
	local marks = { 0.25, 0.5, 0.75 }
	for m = 1, #marks do
		local index = math.floor(n * marks[m] + 0.5)
		if index < 1 then
			index = 1
		elseif index > n then
			index = n
		end
		want[index] = true
	end
	local picked = {}
	for i = 1, n do
		if want[i] then
			picked[#picked + 1] = i
		end
	end
	if #picked > 16 then
		local slim = { picked[1] }
		local span = #picked - 1
		for k = 1, 14 do
			local at = 1 + math.floor(span * k / 15 + 0.5)
			if at > 1 and at < #picked then
				slim[#slim + 1] = picked[at]
			end
		end
		slim[#slim + 1] = picked[#picked]
		picked = slim
	end
	local samples = {}
	for p = 1, #picked do
		local i = picked[p]
		local up = upper[i]
		local lo = lower and lower[i]
		local src = frame[i]
		local open = up and up.heat_open ~= false or false
		local width = 0
		if open and up and lo and up.x and lo.x then
			local dx = up.x - lo.x
			local dy = up.y - lo.y
			width = math.sqrt(dx * dx + dy * dy)
		end
		samples[#samples + 1] = {
			i = i,
			id = (up and up.id) or (src and src.id) or 0,
			open = open,
			width = width,
			ru = src and src.ru or 0,
			rl = src and src.rl or 0,
			peak = up and up.heat_peak or 0,
			source = up and up.heat_source or "",
		}
	end
	local head = frame[1] and frame[1].id or 0
	local tail = frame[n] and frame[n].id or 0
	slot.draw_pieces = slot.draw_pieces or {}
	local piece = nil
	for i = 1, #slot.draw_pieces do
		local one = slot.draw_pieces[i]
		if one.head == head and one.tail == tail then
			piece = one
			break
		end
	end
	if not piece then
		piece = {
			head = head,
			tail = tail,
			phase = frame.phase or "",
			visual_class = frame.visual_class or "",
			n = #frame,
			layers = {},
		}
		slot.draw_pieces[#slot.draw_pieces + 1] = piece
	end
	piece.layers[key] = samples
end

local function note_pre_split(built, key, edges)
	built.pre_split_audit = built.pre_split_audit or {}
	built.pre_split_audit[key] = (built.pre_split_audit[key] or 0) + 1
	local slot = vis_slot(built, built.current_segment_id)
	if slot then
		slot.geometry_failures = slot.geometry_failures + 1
	end
	local list = built.fill_faults or {}
	if #list < 24 then
		list[#list + 1] = {
			layer = key,
			span_index = 0,
			where = "pre_split",
			audit_skip = true,
			self_intersection_edges = edges or "",
			scanline_error = nil,
		}
	end
	built.fill_faults = list
end

local function neighborhood_half(edge, i, sign, radius)
	if not edge then
		return nil
	end
	local acc = 0
	local n = 0
	local i0 = i - radius
	if i0 < 1 then
		i0 = 1
	end
	for k = i0, i + radius do
		local slot = edge[k]
		local bound = slot and slot.outer
		if bound then
			local w = sign > 0 and bound.u or -bound.l
			if w < 0 then
				w = 0
			end
			acc = acc + w
			n = n + 1
		end
	end
	if n == 0 then
		return nil
	end
	return acc / n
end

local function contain_offsets(u, l, pu, pl, margin)
	local lo = pl + margin
	local hi = pu - margin
	if hi < lo then
		local mid = (pu + pl) * 0.5
		lo = mid
		hi = mid
	end
	local hit = false
	if l < lo then
		l = lo
		hit = true
	end
	if u > hi then
		u = hi
		hit = true
	end
	if l > u then
		local mid = (lo + hi) * 0.5
		l = mid
		u = mid
		hit = true
	end
	return u, l, hit
end

local function smooth_offsets(arr, passes, limit, open)
	local clamped = 0
	for _ = 1, passes do
		local pu = {}
		local pl = {}
		for i = 1, #arr do
			pu[i] = arr[i].u
			pl[i] = arr[i].l
		end
		local function side(src, i, j)
			if open and open[j] == false then
				return src[i]
			end
			return src[j]
		end
		for i = 2, #arr - 1 do
			if open and open[i] == false then
				-- A closed section is not a color boundary.
			else
			local u = (side(pu, i, i - 1) + pu[i] * 2 + side(pu, i, i + 1)) * 0.25
			local l = (side(pl, i, i - 1) + pl[i] * 2 + side(pl, i, i + 1)) * 0.25
			local du = u - pu[i]
			local dl = l - pl[i]
			if du > limit then
				du = limit
				clamped = clamped + 1
			elseif du < -limit then
				du = -limit
				clamped = clamped + 1
			end
			if dl > limit then
				dl = limit
				clamped = clamped + 1
			elseif dl < -limit then
				dl = -limit
				clamped = clamped + 1
			end
			arr[i].u = pu[i] + du
			arr[i].l = pl[i] + dl
			end
		end
	end
	return clamped
end

local function point_in_poly(pt, poly)
	if not pt or not pt.x or not poly or #poly < 3 then
		return false
	end
	local inside = false
	local j = #poly
	for i = 1, #poly do
		local a = poly[i]
		local b = poly[j]
		if a and b and a.x and b.x and a.y ~= b.y then
			if (a.y > pt.y) ~= (b.y > pt.y) then
				local x = (b.x - a.x) * (pt.y - a.y) / (b.y - a.y) + a.x
				if pt.x < x then
					inside = not inside
				end
			end
		end
		j = i
	end
	return inside
end

local function poly_holds(pt, poly)
	if not poly or not poly[1] then
		return false
	end
	if poly[1].x then
		return point_in_poly(pt, poly)
	end
	for i = 1, #poly do
		if point_in_poly(pt, poly[i]) then
			return true
		end
	end
	return false
end

local function parent_ready(parent)
	if not parent or not parent[1] then
		return false
	end
	if parent[1].x then
		return #parent >= 3
	end
	return parent[1][1] and parent[1][1].x and #parent[1] >= 3
end

local function ray_fit(pt, origin, poly, margin)
	if poly_holds(pt, poly) then
		return pt.x, pt.y, false, true
	end
	local lo = 0
	local hi = 1
	for _ = 1, 8 do
		local mid = (lo + hi) * 0.5
		local q = {
			x = origin.x + (pt.x - origin.x) * mid,
			y = origin.y + (pt.y - origin.y) * mid,
		}
		if poly_holds(q, poly) then
			lo = mid
		else
			hi = mid
		end
	end
	local x = origin.x + (pt.x - origin.x) * lo
	local y = origin.y + (pt.y - origin.y) * lo
	if not poly_holds({ x = x, y = y }, poly) then
		return pt.x, pt.y, false, false
	end
	if margin > 0 and lo > 0 then
		local dx = x - origin.x
		local dy = y - origin.y
		local len = math.sqrt(dx * dx + dy * dy)
		if len > margin + 0.05 then
			local ix = x - dx / len * margin
			local iy = y - dy / len * margin
			if poly_holds({ x = ix, y = iy }, poly) then
				x = ix
				y = iy
			end
		end
	end
	return x, y, true, true
end

local function poly_rings(poly)
	if not poly or not poly[1] then
		return {}
	end
	if poly[1].x then
		return { poly }
	end
	return poly
end

local function snap_inside(pt, poly, margin)
	if poly_holds(pt, poly) then
		return pt.x, pt.y, true
	end
	local best = nil
	local best_d = nil
	local rings = poly_rings(poly)
	for r = 1, #rings do
		local ring = rings[r]
		local sx, sy, sc = 0, 0, 0
		for i = 1, #ring do
			local a = ring[i]
			if a and a.x then
				sx = sx + a.x
				sy = sy + a.y
				sc = sc + 1
			end
		end
		local cx = pt.x
		local cy = pt.y
		if sc > 0 then
			cx = sx / sc
			cy = sy / sc
		end
		for i = 1, #ring do
			local a = ring[i]
			local b = ring[(i % #ring) + 1]
			if a and b and a.x and b.x then
				local abx = b.x - a.x
				local aby = b.y - a.y
				local ab2 = abx * abx + aby * aby
				local t = 0
				if ab2 > 0.00000001 then
					t = ((pt.x - a.x) * abx + (pt.y - a.y) * aby) / ab2
					if t < 0 then
						t = 0
					elseif t > 1 then
						t = 1
					end
				end
				local x = a.x + abx * t
				local y = a.y + aby * t
				local dx = x - pt.x
				local dy = y - pt.y
				local d = dx * dx + dy * dy
				if not best_d or d < best_d then
					best_d = d
					best = { x = x, y = y, cx = cx, cy = cy }
				end
			end
		end
	end
	if not best then
		return pt.x, pt.y, false
	end
	local x, y = best.x, best.y
	local ix = best.cx - x
	local iy = best.cy - y
	local il = math.sqrt(ix * ix + iy * iy)
	if il > 0.001 and margin > 0 then
		local nx = x + ix / il * margin
		local ny = y + iy / il * margin
		if poly_holds({ x = nx, y = ny }, poly) then
			x, y = nx, ny
		end
	end
	if not poly_holds({ x = x, y = y }, poly) then
		local nx = x + (best.cx - x) * 0.05
		local ny = y + (best.cy - y) * 0.05
		if poly_holds({ x = nx, y = ny }, poly) then
			x, y = nx, ny
		end
	end
	if not poly_holds({ x = x, y = y }, poly) then
		return pt.x, pt.y, false
	end
	return x, y, true
end

local function heat_open_runs(upper)
	local runs = {}
	local start_i = nil
	for i = 1, #upper do
		local open = upper[i] and upper[i].heat_open ~= false
		if open and not start_i then
			start_i = i
		elseif not open and start_i then
			runs[#runs + 1] = { a = start_i, b = i - 1 }
			start_i = nil
		end
	end
	if start_i then
		runs[#runs + 1] = { a = start_i, b = #upper }
	end
	return runs
end

local function termination_tip(upper, lower, index, threshold)
	local nxt = index + 1
	if not upper[nxt] or upper[nxt].heat_open ~= false or not lower[index] or not lower[nxt] then
		return nil
	end
	local peak_a = upper[index].heat_peak or threshold
	local peak_b = upper[nxt].heat_peak or 0
	local denom = peak_a - peak_b
	local f = 1
	if denom ~= 0 then
		f = (peak_a - threshold) / denom
	end
	if f < 0 then
		f = 0
	elseif f > 1 then
		f = 1
	end
	if f < 0.02 then
		return nil
	end
	local function moved(src, toward)
		local dx = (toward.cx - src.cx) * f
		local dy = (toward.cy - src.cy) * f
		return {
			x = src.x + dx,
			y = src.y + dy,
			cx = src.cx + dx,
			cy = src.cy + dy,
			nx = src.nx,
			ny = src.ny,
			tx = src.tx,
			ty = src.ty,
			vx = src.vx,
			vy = src.vy,
			off_u = src.off_u,
			off_l = src.off_l,
			extra = src.extra,
			heat = src.heat,
			temperature = src.temperature,
			along = 1,
			front = true,
			heat_open = true,
			id = src.id,
			sway_phase = src.sway_phase,
		}, src.cx + dx, src.cy + dy
	end
	local up, x, y = moved(upper[index], upper[nxt])
	local lo = moved(lower[index], lower[nxt])
	return up, lo, f, x, y
end

local function ease_layer_end(memory, chain_index, upper, lower, runs, key)
	if not memory or not runs or #runs == 0 then
		return
	end
	memory.layers = memory.layers or {}
	local slot = memory.layers[chain_index] or {}
	memory.layers[chain_index] = slot
	slot.travel = slot.travel or {}
	slot.width = slot.width or {}
	local run = runs[#runs]
	local raw_b = run.b
	local raw_s = upper[raw_b] and upper[raw_b].s or 0
	local remembered = slot.travel[key]
	local held = memory.hold and memory.hold[chain_index] == true
	if held and remembered then
		local delta = raw_s - remembered
		if delta > 8 then
			delta = 8
		elseif delta < -8 then
			delta = -8
		end
		local want = remembered + delta
		if want > raw_s + 0.5 and upper[raw_b] and lower[raw_b] then
			local cx = upper[raw_b].cx or upper[raw_b].x
			local cy = upper[raw_b].cy or upper[raw_b].y
			local found = false
			local prev = upper[1]
			for i = 2, #upper do
				local here = upper[i]
				local a = prev.s or 0
				local b = here.s or 0
				if a <= want and b >= want and b > a then
					local t = (want - a) / (b - a)
					cx = (prev.cx or prev.x) + ((here.cx or here.x) - (prev.cx or prev.x)) * t
					cy = (prev.cy or prev.y) + ((here.cy or here.y) - (prev.cy or prev.y)) * t
					found = true
					break
				end
				prev = here
			end
			if not found then
				want = raw_s
			end
			local function shift_end(src)
				return {
					x = src.x + (cx - (src.cx or src.x)),
					y = src.y + (cy - (src.cy or src.y)),
					cx = cx,
					cy = cy,
					nx = src.nx,
					ny = src.ny,
					tx = src.tx,
					ty = src.ty,
					vx = src.vx,
					vy = src.vy,
					sway_phase = src.sway_phase,
					heat_open = true,
					s = want,
					id = src.id,
				}
			end
			run.tip_u = shift_end(upper[raw_b])
			run.tip_l = shift_end(lower[raw_b])
			run.end_x = cx
			run.end_y = cy
			slot.travel[key] = want
		else
			local best = raw_b
			local best_d = math.abs(raw_s - want)
			for i = run.a, raw_b do
				if upper[i] and upper[i].heat_open ~= false then
					local d = math.abs((upper[i].s or 0) - want)
					if d < best_d then
						best_d = d
						best = i
					end
				end
			end
			run.b = best
			slot.travel[key] = upper[best] and upper[best].s or want
		end
	elseif upper[raw_b] then
		slot.travel[key] = raw_s
	end
	local up = upper[run.b]
	local lo = lower[run.b]
	if up and lo and (key == "outer" or key == "orange") then
		local dx = up.x - lo.x
		local dy = up.y - lo.y
		local width = math.sqrt(dx * dx + dy * dy)
		local prev_w = slot.width[key]
		local target = width
		if prev_w then
			local delta = width - prev_w
			if delta > 4 then
				delta = 4
			elseif delta < -4 then
				delta = -4
			end
			target = prev_w + delta
			if width > 0.001 then
				local scale = target / width
				local mx = (up.x + lo.x) * 0.5
				local my = (up.y + lo.y) * 0.5
				up.x = mx + (up.x - mx) * scale
				up.y = my + (up.y - my) * scale
				lo.x = mx + (lo.x - mx) * scale
				lo.y = my + (lo.y - my) * scale
			end
		end
		slot.width[key] = target
	end
end

local LAYER_REAR_SCALE = {
	outer = 1,
	orange = 0.74,
	gold = 0.50,
	white = 0.28,
}

local function compact_front_cap(up, lo, depth)
	if not up or not lo or not up.x or not lo.x then
		return nil
	end
	local sx = up.x - lo.x
	local sy = up.y - lo.y
	local width = math.sqrt(sx * sx + sy * sy)
	if width < 2 then
		return nil
	end
	local wx = sx / width
	local wy = sy / width
	local mx = (up.x + lo.x) * 0.5
	local my = (up.y + lo.y) * 0.5
	local tx = up.tx or 1
	local ty = up.ty or 0
	local len = math.sqrt(tx * tx + ty * ty)
	if len < 0.0001 then
		tx, ty = 1, 0
	else
		tx, ty = tx / len, ty / len
	end
	if depth < 2 then depth = 2 end
	if depth > 14 then depth = 14 end
	local steps = 4
	local function k_at(t)
		local shaped = t * t * (3 - 2 * t)
		local k = 1 - shaped
		if k < 0 then k = 0 end
		return math.sqrt(k)
	end
	local pts = {}
	for i = 1, steps do
		local t = i / (steps + 0.2)
		local half = width * 0.5 * k_at(t)
		local cx = mx + tx * depth * t
		local cy = my + ty * depth * t
		pts[#pts + 1] = { x = cx + wx * half, y = cy + wy * half, tx = tx, ty = ty }
	end
	pts[#pts + 1] = { x = mx + tx * depth, y = my + ty * depth, tx = tx, ty = ty }
	for i = steps, 1, -1 do
		local t = i / (steps + 0.2)
		local half = width * 0.5 * k_at(t)
		local cx = mx + tx * depth * t
		local cy = my + ty * depth * t
		pts[#pts + 1] = { x = cx - wx * half, y = cy - wy * half, tx = tx, ty = ty }
	end
	return pts
end

local function solve_rear_envelope(up, lo, ahead, ahead2, chains, chain_index, frame, built)
	if not up or not lo or not up.x or not lo.x then
		return nil
	end
	local sx = up.x - lo.x
	local sy = up.y - lo.y
	local width = math.sqrt(sx * sx + sy * sy)
	if width < 2 then
		return nil
	end
	local wx = sx / width
	local wy = sy / width
	local mx = (up.x + lo.x) * 0.5
	local my = (up.y + lo.y) * 0.5
	local tx = up.tx or 1
	local ty = up.ty or 0
	local along_face = math.abs(tx * wx + ty * wy)
	local back_x, back_y
	if along_face < 0.75 then
		back_x, back_y = -tx, -ty
	else
		back_x, back_y = -wy, wx
	end
	local blen = math.sqrt(back_x * back_x + back_y * back_y)
	if blen < 0.0001 then
		back_x, back_y = -wy, wx
	else
		back_x, back_y = back_x / blen, back_y / blen
	end
	if ahead and ahead.x then
		local bx = ahead.x - mx
		local by = ahead.y - my
		if back_x * bx + back_y * by > 0 then
			back_x, back_y = -back_x, -back_y
		end
	end
	local class_name = frame and frame.visual_class or "stream"
	local arc = frame and frame.piece_arc or width
	local depth
	if class_name == "short" then
		depth = math.min(width * 0.22, arc * 0.28)
		if depth < 2.5 then depth = 2.5 end
		if depth > 10 then depth = 10 end
	elseif class_name == "blob" then
		depth = math.min(width * 0.32, arc * 0.40)
		if depth < 3 then depth = 3 end
		if depth > 16 then depth = 16 end
	else
		depth = width * 0.30
		if depth < 8 then depth = 8 end
		if depth > 32 then depth = 32 end
	end
	if ahead and ahead2 and ahead.x and ahead2.x and class_name ~= "short" then
		local ax = ahead.x - mx
		local ay = ahead.y - my
		local bx = ahead2.x - ahead.x
		local by = ahead2.y - ahead.y
		local al = math.sqrt(ax * ax + ay * ay)
		local cl = math.sqrt(bx * bx + by * by)
		if al > 0.001 and cl > 0.001 then
			local dot = (ax * bx + ay * by) / (al * cl)
			if dot > 1 then dot = 1 end
			if dot < -1 then dot = -1 end
			local curve = math.acos(dot)
			if curve > 0.45 then
				local radius = al / curve
				if depth > radius then
					depth = radius
				end
			end
		end
	end
	local shortened = false
	if chains and chain_index then
		local best = nil
		local lateral_limit = width * 0.65 + 10
		if lateral_limit < 28 then
			lateral_limit = 28
		end
		local reach = depth + lateral_limit
		local reach_sq = reach * reach
		if built then
			built.rear_envelope_solves = (built.rear_envelope_solves or 0) + 1
		end
		for i = 1, #chains do
			if i ~= chain_index then
				local pts = chains[i]
				local near = false
				if pts and #pts > 0 then
					local sample_i = { 1, #pts, math.floor((#pts + 1) / 2) }
					for s = 1, #sample_i do
						local p = pts[sample_i[s]]
						if p and p.x then
							local dx = p.x - mx
							local dy = p.y - my
							if dx * dx + dy * dy <= reach_sq then
								near = true
								break
							end
						end
					end
				end
				if near then
					if built then
						built.rear_search_candidates = (built.rear_search_candidates or 0) + 1
					end
					for j = 1, #pts do
						local p = pts[j]
						if p and p.x then
							local px = p.x - mx
							local py = p.y - my
							local along = px * back_x + py * back_y
							if along > 2 then
								local lat = math.abs(-px * back_y + py * back_x)
								if lat < lateral_limit and (not best or along < best) then
									best = along
								end
							end
						end
					end
				end
			end
		end
		if best and depth > best * 0.72 then
			depth = best * 0.72
			shortened = true
		end
	end
	if class_name == "short" or class_name == "blob" then
		if depth < 2 then depth = 2 end
	else
		if not shortened and depth < 4 then
			depth = 4
		end
		if depth < 1.5 then
			depth = 1.5
		end
	end
	local rec = frame and frame.piece
	if rec then
		local target = depth
		local hold = rec.depth_hold
		if hold == nil then
			hold = target
		elseif target < hold - 0.05 then
			hold = target
		else
			local step = (target - hold) * 0.4
			if step > 4 then step = 4 end
			hold = hold + step
		end
		rec.depth_hold = hold
		depth = hold
		rec.tight = shortened and (class_name == "short" or class_name == "blob") and depth < width * 0.16
	end
	return {
		back_x = back_x,
		back_y = back_y,
		safe_depth = depth,
		width = width,
		shortened = shortened,
		mx = mx,
		my = my,
	}
end

local function build_rear_cap(up, lo, layer_key, envelope)
	if not envelope or not up or not lo or not up.x or not lo.x then
		return nil
	end
	local sx = up.x - lo.x
	local sy = up.y - lo.y
	local width = math.sqrt(sx * sx + sy * sy)
	if width < 2 then
		return nil
	end
	local wx = sx / width
	local wy = sy / width
	local mx = (up.x + lo.x) * 0.5
	local my = (up.y + lo.y) * 0.5
	local tx = up.tx or 1
	local ty = up.ty or 0
	local tlen = math.sqrt(tx * tx + ty * ty)
	if tlen < 0.0001 then
		tx, ty = 1, 0
	else
		tx, ty = tx / tlen, ty / tlen
	end
	local back_x = envelope.back_x or -tx
	local back_y = envelope.back_y or -ty
	local want_x, want_y = -tx, -ty
	if back_x * want_x + back_y * want_y < 0.85 then
		back_x, back_y = want_x, want_y
	end
	local blen = math.sqrt(back_x * back_x + back_y * back_y)
	if blen < 0.0001 then
		back_x, back_y = -tx, -ty
	else
		back_x, back_y = back_x / blen, back_y / blen
	end
	local scale = LAYER_REAR_SCALE[layer_key or "outer"] or 1
	local depth = (envelope.safe_depth or 4) * scale
	if envelope.shortened then
		if depth < 1.2 then depth = 1.2 end
	elseif depth < 1.5 then
		depth = 1.5
	end
	local function k_at(t)
		if t <= 0 then
			return 1
		end
		local shaped = t * t * (3 - 2 * t)
		local k = 1 - shaped
		if k < 0 then k = 0 end
		return math.sqrt(k)
	end
	local function inset_at(t)
		if layer_key == "outer" or t <= 0 then
			return 1
		end
		local shaped = t * t * (3 - 2 * t)
		return 1 - 0.06 * shaped
	end
	local function point_from(src, x, y, nx, ny)
		return {
			x = x,
			y = y,
			nx = nx,
			ny = ny,
			tx = back_x,
			ty = back_y,
			vx = src.vx or up.vx or 0,
			vy = src.vy or up.vy or 0,
			id = up.id,
			segment_id = up.segment_id,
			temperature = src.temperature or src.heat or up.temperature or up.heat or 0.5,
			s = up.s or 0,
		}
	end
	local function make(use_depth)
		local steps = 7
		if use_depth < 12 then
			steps = 6
		end
		local upper_pts = {}
		local lower_pts = {}
		local halves = { width * 0.5 }
		for step = 1, steps do
			halves[#halves + 1] = width * 0.5 * k_at(step / steps) * inset_at(step / steps)
		end
		for step = steps, 0, -1 do
			local t = step / steps
			if step == 0 then
				upper_pts[#upper_pts + 1] = point_from(up, up.x, up.y, wx, wy)
				lower_pts[#lower_pts + 1] = point_from(lo, lo.x, lo.y, -wx, -wy)
			else
				local half = width * 0.5 * k_at(t) * inset_at(t)
				local shaped = t * t * (3 - 2 * t)
				local axis_x, axis_y = mx, my
				local outer_axis = envelope.outer_cap
				if outer_axis and layer_key ~= "outer" and outer_axis.mx then
					axis_x, axis_y = outer_axis.mx, outer_axis.my
				end
				local cx = mx + (axis_x - mx) * shaped + back_x * use_depth * t
				local cy = my + (axis_y - my) * shaped + back_y * use_depth * t
				upper_pts[#upper_pts + 1] = point_from(up, cx + wx * half, cy + wy * half, wx, wy)
				lower_pts[#lower_pts + 1] = point_from(lo, cx - wx * half, cy - wy * half, -wx, -wy)
			end
		end
		return upper_pts, lower_pts, halves, steps
	end
	local function crossed(upper_pts, lower_pts)
		for i = 1, #upper_pts - 1 do
			if proper_cross(upper_pts[i], upper_pts[i + 1], lower_pts[i], lower_pts[i + 1]) then
				return true
			end
		end
		if #upper_pts >= 1 and proper_cross(up, lo, upper_pts[1], lower_pts[1]) then
			return true
		end
		return false
	end
	local function contain_count(upper_pts, lower_pts)
		local outer = envelope.outer_cap
		if not outer or layer_key == "outer" or not outer.back_x or (outer.depth or 0) < 1 then
			return 0
		end
		local fails = 0
		local function check_pt(p)
			local dx = p.x - outer.mx
			local dy = p.y - outer.my
			local along = dx * outer.back_x + dy * outer.back_y
			local lat = math.abs(-dx * outer.back_y + dy * outer.back_x)
			local t = 0
			if outer.depth > 0.001 then
				t = along / outer.depth
			end
			if t < 0 then t = 0 end
			if t > 1 then t = 1 end
			local limit = (outer.width or width) * 0.5 * k_at(t) + 1.25
			if along > (outer.depth or 0) + 1.25 or lat > limit then
				fails = fails + 1
			end
		end
		for i = 1, #upper_pts - 1 do
			check_pt(upper_pts[i])
			check_pt(lower_pts[i])
		end
		return fails
	end
	local function pull_inside(upper_pts, lower_pts)
		local outer = envelope.outer_cap
		if not outer or layer_key == "outer" or not outer.back_x or (outer.depth or 0) < 1 then
			return
		end
		local function pull(p)
			local dx = p.x - outer.mx
			local dy = p.y - outer.my
			local along = dx * outer.back_x + dy * outer.back_y
			local lat_x = -outer.back_y
			local lat_y = outer.back_x
			local lat = dx * lat_x + dy * lat_y
			local t = 0
			if outer.depth > 0.001 then
				t = along / outer.depth
			end
			if t < 0 then t = 0 end
			if t > 1 then t = 1 end
			local limit = (outer.width or width) * 0.5 * k_at(t) - 0.35
			if limit < 0.8 then
				limit = 0.8
			end
			if math.abs(lat) > limit or along > (outer.depth or 0) + 0.75 then
				local clamped = along
				if clamped < 0 then clamped = 0 end
				if clamped > outer.depth then clamped = outer.depth end
				local sign = lat >= 0 and 1 or -1
				local use = math.abs(lat)
				if use > limit then use = limit end
				p.x = outer.mx + outer.back_x * clamped + lat_x * use * sign
				p.y = outer.my + outer.back_y * clamped + lat_y * use * sign
			end
		end
		for i = 1, #upper_pts - 1 do
			pull(upper_pts[i])
			pull(lower_pts[i])
		end
	end
	local upper_pts, lower_pts, halves, steps = make(depth)
	pull_inside(upper_pts, lower_pts)
	local cross = crossed(upper_pts, lower_pts)
	if cross then
		depth = depth * 0.6
		if depth < 1.5 then depth = 1.5 end
		upper_pts, lower_pts, halves, steps = make(depth)
		pull_inside(upper_pts, lower_pts)
		cross = crossed(upper_pts, lower_pts)
	end
	if cross then
		depth = math.min(depth, math.max(2, width * 0.16))
		upper_pts, lower_pts, halves, steps = make(depth)
		pull_inside(upper_pts, lower_pts)
		cross = crossed(upper_pts, lower_pts)
	end
	if cross then
		return nil
	end
	local contain = contain_count(upper_pts, lower_pts)
	if contain > 0 then
		depth = depth * 0.72
		if depth < 1.5 then depth = 1.5 end
		upper_pts, lower_pts, halves, steps = make(depth)
		pull_inside(upper_pts, lower_pts)
		if crossed(upper_pts, lower_pts) then
			return nil
		end
		contain = contain_count(upper_pts, lower_pts)
	end
	local function pair_gap(a, b)
		if not a or not b then
			return 999
		end
		local dx = (a.x or 0) - (b.x or 0)
		local dy = (a.y or 0) - (b.y or 0)
		return math.sqrt(dx * dx + dy * dy)
	end
	local join_u = pair_gap(upper_pts[#upper_pts], up)
	local join_l = pair_gap(lower_pts[#lower_pts], lo)
	local tangent = 0
	local prev = upper_pts[#upper_pts - 1]
	if prev then
		local ex = up.x - prev.x
		local ey = up.y - prev.y
		local el = math.sqrt(ex * ex + ey * ey)
		if el > 0.001 then
			local align = (ex * tx + ey * ty) / el
			if align > 1 then align = 1 end
			if align < -1 then align = -1 end
			tangent = 1 - align
		end
	end
	return {
		upper = upper_pts,
		lower = lower_pts,
		width = width,
		depth = depth,
		halves = halves,
		steps = steps,
		cross = false,
		mx = mx,
		my = my,
		back_x = back_x,
		back_y = back_y,
		tip_x = mx + back_x * depth,
		tip_y = my + back_y * depth,
		join_upper = join_u,
		join_lower = join_l,
		tangent = tangent,
		containment_failures = contain,
	}
end

local function closed_outline(upper, lower, cap)
	local poly = {}
	for i = 1, #upper do
		local p = upper[i]
		if p and p.x == p.x and p.y == p.y then
			poly[#poly + 1] = p
		end
	end
	if cap then
		for i = 1, #cap do
			local p = cap[i]
			if p and p.x == p.x and p.y == p.y then
				poly[#poly + 1] = p
			end
		end
	end
	for i = #lower, 1, -1 do
		local p = lower[i]
		if p and p.x == p.x and p.y == p.y then
			poly[#poly + 1] = p
		end
	end
	return poly
end

local function keep_fit_outline(built, frame, key, outline)
	if not outline or not outline[1] then
		return
	end
	local seg = frame.segment_id or 0
	built.fit_outlines = built.fit_outlines or {}
	local slot = built.fit_outlines[seg]
	if not slot then
		slot = {}
		built.fit_outlines[seg] = slot
	end
	local rings = {}
	if outline[1].x then
		rings[1] = outline
	else
		for i = 1, #outline do
			rings[#rings + 1] = outline[i]
		end
	end
	slot[key] = rings
end

local function fit_body(upper, lower, parent, margin, built, frame, key)
	if not parent_ready(parent) then
		return 0, 0
	end
	local moved = 0
	local unresolved = 0
	for i = 1, #upper do
		local up = upper[i]
		local lo = lower[i]
		if up and up.heat_open == false then
			up = nil
			lo = nil
		end
		if up and up.cx and up.x == up.x then
			local x, y, hit, held = ray_fit({ x = up.x, y = up.y }, { x = up.cx, y = up.cy }, parent, margin)
			if hit then
				up.x = x
				up.y = y
				local dx = x - up.cx
				local dy = y - up.cy
				up.off_u = dx * (up.nx or 0) + dy * (up.ny or 0)
				up.ext_u = dx * (up.tx or 0) + dy * (up.ty or 0)
				moved = moved + 1
				if frame.edge and frame.edge[i] and frame.edge[i][key] then
					frame.edge[i][key].u = up.off_u
					frame.edge[i][key].ext_u = up.ext_u
				end
				if frame.is_lead and built.sections[i] then
					built.sections[i][key .. "_upper"] = up.off_u
				end
			elseif held == false then
				local sx, sy, ok = snap_inside({ x = up.x, y = up.y }, parent, margin)
				if ok then
					up.x = sx
					up.y = sy
					local dx = sx - up.cx
					local dy = sy - up.cy
					up.off_u = dx * (up.nx or 0) + dy * (up.ny or 0)
					up.ext_u = dx * (up.tx or 0) + dy * (up.ty or 0)
					moved = moved + 1
				else
					unresolved = unresolved + 1
				end
			end
		end
		if lo and up and lo.cx and lo.x == lo.x then
			local x, y, hit, held = ray_fit({ x = lo.x, y = lo.y }, { x = lo.cx, y = lo.cy }, parent, margin)
			if hit then
				lo.x = x
				lo.y = y
				local dx = x - lo.cx
				local dy = y - lo.cy
				lo.off_l = dx * (up.nx or 0) + dy * (up.ny or 0)
				lo.ext_l = dx * (up.tx or 0) + dy * (up.ty or 0)
				moved = moved + 1
				if frame.edge and frame.edge[i] and frame.edge[i][key] then
					frame.edge[i][key].l = lo.off_l
					frame.edge[i][key].ext_l = lo.ext_l
				end
				if frame.is_lead and built.sections[i] then
					built.sections[i][key .. "_lower"] = lo.off_l
				end
			elseif held == false then
				local sx, sy, ok = snap_inside({ x = lo.x, y = lo.y }, parent, margin)
				if ok then
					lo.x = sx
					lo.y = sy
					local dx = sx - lo.cx
					local dy = sy - lo.cy
					lo.off_l = dx * (up.nx or 0) + dy * (up.ny or 0)
					lo.ext_l = dx * (up.tx or 0) + dy * (up.ty or 0)
					moved = moved + 1
				else
					unresolved = unresolved + 1
				end
			end
		end
	end
	return moved, unresolved
end

local function fit_cap(cap, up, lo, parent, margin)
	if not cap or not up or not lo or not parent_ready(parent) then
		return 0, 0
	end
	local origin = {
		x = (up.x + lo.x) * 0.5,
		y = (up.y + lo.y) * 0.5,
	}
	local moved = 0
	local unresolved = 0
	for i = 1, #cap do
		local pt = cap[i]
		if pt and pt.x == pt.x then
			local x, y, hit, held = ray_fit(pt, origin, parent, margin)
			if hit then
				pt.x = x
				pt.y = y
				moved = moved + 1
			elseif held == false then
				local sx, sy, ok = snap_inside(pt, parent, margin)
				if ok then
					pt.x = sx
					pt.y = sy
					moved = moved + 1
				else
					unresolved = unresolved + 1
				end
			end
		end
	end
	return moved, unresolved
end

local function note_bands(built, frame, upper, key)
	if not frame.is_lead or key == "outer" or not frame.edge then
		return
	end
	built.bands = built.bands or { mouth = {}, mid = {}, far = {} }
	for i = 1, #upper do
		local slot = frame.edge[i]
		local outer = slot and slot.outer
		local mine = slot and slot[key]
		local up = upper[i]
		if outer and mine and up and up.heat_open ~= false then
			local span = (outer.u or 0) - (outer.l or 0)
			if span > 2 then
				local progress = up.progress or 0
				local bin = "far"
				if progress < 0.28 then
					bin = "mouth"
				elseif progress < 0.72 then
					bin = "mid"
				end
				local rec = built.bands[bin]
				rec[key] = (rec[key] or 0) + ((mine.u or 0) - (mine.l or 0)) / span
				rec[key .. "_n"] = (rec[key .. "_n"] or 0) + 1
			end
		end
	end
end

local function cap_reach(cap, up, lo, tx, ty)
	if not cap or not up or not lo then
		return 0, 0
	end
	local mx = (up.x + lo.x) * 0.5
	local my = (up.y + lo.y) * 0.5
	local width = math.sqrt((lo.x - up.x) ^ 2 + (lo.y - up.y) ^ 2)
	local depth = 0
	for i = 1, #cap do
		local p = cap[i]
		if p and p.x then
			local f = (p.x - mx) * tx + (p.y - my) * ty
			if f > depth then
				depth = f
			end
		end
	end
	return depth, width
end

local function ribbon_area(upper, lower, accept)
	local total = 0
	local n = #upper
	local i = 1
	while i <= n do
		if not accept(i) then
			i = i + 1
		else
			local j = i
			while j < n and accept(j + 1) do
				j = j + 1
			end
			if j > i then
				local area = 0
				local function add(a, b)
					area = area + a.x * b.y - b.x * a.y
				end
				for k = i, j - 1 do
					add(upper[k], upper[k + 1])
				end
				add(upper[j], lower[j])
				for k = j, i + 1, -1 do
					add(lower[k], lower[k - 1])
				end
				add(lower[i], upper[i])
				if area < 0 then
					area = -area
				end
				total = total + area * 0.5
			end
			i = j + 1
		end
	end
	return total
end

local function residual_between_heat(flags, index)
	if flags[index] then
		return false
	end
	local left = false
	local right = false
	for j = index - 1, 1, -1 do
		if flags[j] then
			left = true
			break
		end
	end
	for j = index + 1, #flags do
		if flags[j] then
			right = true
			break
		end
	end
	if not (left and right) then
		return false
	end
	local prev_closed = index > 1 and not flags[index - 1]
	local next_closed = index < #flags and not flags[index + 1]
	return prev_closed or next_closed
end

local function place_outer(upper, lower, index, off_u, off_l)
	local up = upper[index]
	local lo = lower[index]
	if not up or not lo or not up.cx or not up.nx then
		return
	end
	up.off_u = off_u
	lo.off_l = off_l
	up.x = up.cx + up.nx * off_u + (up.tx or 0) * (up.ext_u or 0)
	up.y = up.cy + up.ny * off_u + (up.ty or 0) * (up.ext_u or 0)
	lo.x = (lo.cx or up.cx) + up.nx * off_l + (up.tx or 0) * (lo.ext_l or 0)
	lo.y = (lo.cy or up.cy) + up.ny * off_l + (up.ty or 0) * (lo.ext_l or 0)
	up.heat_open = true
	lo.heat_open = true
end

local function apply_outer_residual(frame, upper, lower, built)
	local n = #upper
	if n < 2 or frame.phase == "emitting" then
		local slot = vis_slot(built, frame.segment_id)
		if slot and frame.phase == "emitting" then
			local open_n = 0
			for i = 1, n do
				if upper[i].thermal_open == true then
					open_n = open_n + 1
				end
			end
			slot.outer_heat_open_count = slot.outer_heat_open_count + open_n
			slot.temperature_threshold_failures = slot.temperature_threshold_failures + (n - open_n)
			local area = ribbon_area(upper, lower, function(i)
				return upper[i].thermal_open == true
			end)
			slot.thermal_area = slot.thermal_area + area
			slot.visible_outer_area = slot.visible_outer_area + area
		end
		return
	end
	local flags = {}
	local open_n = 0
	local candidate_n = 0
	local suppressed_n = 0
	local seg = frame.segment_ref
	local visuals = seg and seg.slice_visual or nil
	for i = 1, n do
		flags[i] = upper[i].thermal_open == true
		if flags[i] then
			open_n = open_n + 1
		end
		local sample = frame[i]
		local visual = visuals and sample and sample.id and visuals[sample.id] or nil
		local strength = visual and visual.strength or 0
		if not visual and (frame.residual or 0) > 0.02 then
			strength = 1
		end
		local caught = false
		if frame.phase ~= "emitting" then
			local along = 0
			if sample then
				if sample.release_s ~= nil then
					along = sample.release_s
				else
					along = sample.from_rear or 0
				end
			end
			caught = along <= (frame.dissipate_front or 0)
		end
		local env_u = visual and visual.envelope_u or (sample and sample.ru) or 0
		local env_l = visual and visual.envelope_l or (sample and sample.rl) or 0
		local now_u = sample and sample.ru or env_u
		local now_l = sample and sample.rl or env_l
		if now_u < env_u then
			env_u = now_u
		end
		if now_l < env_l then
			env_l = now_l
		end
		if env_u < 0 then
			env_u = 0
		end
		if env_l < 0 then
			env_l = 0
		end
		local cap_u = visual and visual.envelope_u or env_u
		local cap_l = visual and visual.envelope_l or env_l
		if cap_u < env_u then
			cap_u = env_u
		end
		if cap_l < env_l then
			cap_l = env_l
		end
		upper[i].residual_v = strength
		upper[i].caught = caught
		upper[i].geo_u = env_u
		upper[i].geo_l = env_l
		upper[i].envelope_u = cap_u
		upper[i].envelope_l = cap_l
		if strength > 0.02 then
			candidate_n = candidate_n + 1
		end
	end
	local thermal_area = ribbon_area(upper, lower, function(i)
		return flags[i] == true
	end)
	local residual_n = 0
	for i = 1, n do
		local up = upper[i]
		local strength = up.residual_v or 0
		local between = residual_between_heat(flags, i)
		if flags[i] and not up.caught then
			up.heat_source = "thermal"
		elseif flags[i] and up.caught then
			if strength <= 0.02 then
				up.heat_open = false
				if lower[i] then
					lower[i].heat_open = false
				end
				up.heat_source = "closed"
			else
				up.heat_source = "thermal"
			end
		elseif between then
			suppressed_n = suppressed_n + 1
			up.heat_source = "closed"
		elseif strength > 0.02 then
			place_outer(upper, lower, i, up.geo_u or 0, -(up.geo_l or 0))
			up.heat_source = "residual"
			residual_n = residual_n + 1
		else
			up.heat_source = "closed"
		end
	end
	local function combined()
		return ribbon_area(upper, lower, function(i)
			return upper[i].heat_open ~= false
		end)
	end
	local area = combined()
	frame._outer_ribbon_area = area
	if candidate_n > 0 and residual_n == 0 and open_n == 0 then
		frame.residual_block = suppressed_n > 0 and "cold_gap" or "no_place"
	else
		frame.residual_block = nil
	end
	local residual_area = ribbon_area(upper, lower, function(i)
		return upper[i].heat_source == "residual"
	end)
	local rec = frame.piece
	if rec then
		if (rec.outer_area_0 or 0) < 1 and area > 1 then
			rec.outer_area_0 = area
		end
		rec.outer_area_prev = area
	end
	if seg and frame.phase ~= "emitting" then
		if seg._area_frame ~= built then
			seg._area_frame = built
			seg._area_sum = 0
		end
		seg._area_sum = (seg._area_sum or 0) + area
		seg.outer_area_prev = seg._area_sum
		if (seg.outer_area_0 or 0) < seg._area_sum then
			seg.outer_area_0 = seg._area_sum
		end
	end
	local slot = vis_slot(built, frame.segment_id)
	if slot then
		slot.outer_heat_open_count = slot.outer_heat_open_count + open_n
		slot.residual_candidate_count = (slot.residual_candidate_count or 0) + candidate_n
		slot.residual_open_count = slot.residual_open_count + residual_n
		slot.temperature_threshold_failures = slot.temperature_threshold_failures + (n - open_n)
		slot.thermal_area = slot.thermal_area + thermal_area
		slot.residual_area = slot.residual_area + residual_area
		slot.visible_outer_area = slot.visible_outer_area + area
		local best = nil
		for i = 1, n do
			local up = upper[i]
			local lo = lower[i]
			if up and lo and up.heat_open ~= false and up.x and lo.x then
				local dx = up.x - lo.x
				local dy = up.y - lo.y
				local face = math.sqrt(dx * dx + dy * dy)
				if not best or face < best.face then
					local sample = frame[i]
					local along = 0
					if sample then
						if sample.release_s ~= nil then
							along = sample.release_s
						else
							along = sample.from_rear or 0
						end
					end
					best = {
						face = face,
						geo = (up.geo_u or 0) + (up.geo_l or 0),
						off = math.abs(up.off_u or 0) + math.abs(lo.off_l or 0),
						strength = up.residual_v or 0,
						release_s = along,
						caught = up.caught == true,
					}
				end
			end
		end
		if best and (not slot.min_face or best.face < slot.min_face) then
			slot.min_face = best.face
			slot.min_face_geo = best.geo
			slot.min_face_off = best.off
			slot.min_face_strength = best.strength
			slot.min_face_release_s = best.release_s
			slot.min_face_caught = best.caught
			slot.visual_class = frame.visual_class
		end
	end
end

local BLOB_LAYER_SCALE = {
	outer = 1,
	orange = 0.72,
	gold = 0.48,
	white = 0.26,
}

local function visible_open_runs(upper)
	local runs = {}
	local a = nil
	for i = 1, #upper do
		local open = upper[i] and upper[i].heat_open ~= false
		if open then
			if not a then
				a = i
			end
		elseif a then
			runs[#runs + 1] = { a = a, b = i - 1 }
			a = nil
		end
	end
	if a then
		runs[#runs + 1] = { a = a, b = #upper }
	end
	return runs
end

local function run_should_round(arc, width, count)
	if count < 2 or width < 1.5 then
		return false
	end
	if arc >= 160 and arc >= width * 1.6 then
		return false
	end
	if arc < 130 then
		return true
	end
	if arc < width * 1.35 then
		return true
	end
	if count <= 5 and arc < 150 then
		return true
	end
	return false
end

local function measure_open_run(upper, lower, run)
	local a, b = run.a, run.b
	local count = b - a + 1
	local sx, sy, arc = 0, 0, 0
	local face_sum = 0
	local prev_x, prev_y = nil, nil
	local first_x, first_y = nil, nil
	local last_x, last_y = nil, nil
	for i = a, b do
		local up = upper[i]
		local lo = lower[i]
		local px = up and (up.cx or up.x) or 0
		local py = up and (up.cy or up.y) or 0
		sx = sx + px
		sy = sy + py
		if not first_x then
			first_x, first_y = px, py
		end
		last_x, last_y = px, py
		if prev_x then
			local dx = px - prev_x
			local dy = py - prev_y
			arc = arc + math.sqrt(dx * dx + dy * dy)
		end
		prev_x, prev_y = px, py
		if up and lo and up.x and lo.x then
			local dx = up.x - lo.x
			local dy = up.y - lo.y
			face_sum = face_sum + math.sqrt(dx * dx + dy * dy)
		end
	end
	return {
		count = count,
		arc = arc,
		width = count > 0 and (face_sum / count) or 0,
		mx = count > 0 and (sx / count) or 0,
		my = count > 0 and (sy / count) or 0,
		first_x = first_x or 0,
		first_y = first_y or 0,
		last_x = last_x or 0,
		last_y = last_y or 0,
		tx = upper[a] and upper[a].tx or 1,
		ty = upper[a] and upper[a].ty or 0,
	}
end

local function closed_run_is_compact(frame, upper, lower, run)
	if not run or not upper then
		return false
	end
	if upper[run.a] and upper[run.a].compact_run then
		return true
	end
	if upper[run.b] and upper[run.b].compact_run then
		return true
	end
	return false
end

local function reshape_compact_blob(frame, upper, lower, built, layer_key)
	if frame.phase == "emitting" and not frame.force_compact then
		return
	end
	if not frame.force_compact and frame.visual_class ~= "short" and frame.visual_class ~= "blob" then
		return
	end
	local n = #upper
	if n < 2 then
		return
	end
	if frame.compact_runs == nil and layer_key == "outer" then
		local found = {}
		local life = frame.thermal_peak or 0
		if (frame.residual or 0) > life then
			life = frame.residual or 0
		end
		if life < 0 then
			life = 0
		end
		if life > 1 then
			life = 1
		end
		local life_scale = 0.42 + 0.58 * life
		for _, run in ipairs(visible_open_runs(upper)) do
			local seed = measure_open_run(upper, lower, run)
			if run.b == run.a then
				local a, b = run.a, run.b
				while (b - a + 1) < 4 and (a > 1 or b < n) do
					if a > 1 then
						a = a - 1
					end
					if (b - a + 1) < 4 and b < n then
						b = b + 1
					end
				end
				run.a, run.b = a, b
			end
			local measured = measure_open_run(upper, lower, run)
			if measured.width < seed.width then
				measured.width = seed.width
			end
			if frame.force_compact or run_should_round(measured.arc, measured.width, measured.count) then
				local cross = measured.width * 0.5 * life_scale
				local along = measured.arc * 0.5
				if along < cross then
					along = cross
				end
				along = along * life_scale
				local aspect = measured.arc / math.max(measured.width, 0.01)
				local round_u = 0.45
				if aspect < 1.5 then
					round_u = 0.85
				elseif aspect < 2.2 then
					round_u = 0.65
				end
				along = along * (1 - round_u) + cross * round_u
				local tx, ty = measured.tx, measured.ty
				local dx = measured.last_x - measured.first_x
				local dy = measured.last_y - measured.first_y
				local len = math.sqrt(dx * dx + dy * dy)
				if len >= 0.5 then
					tx, ty = dx / len, dy / len
				end
				local tlen = math.sqrt(tx * tx + ty * ty)
				if tlen < 0.001 then
					tx, ty = 1, 0
				else
					tx, ty = tx / tlen, ty / tlen
				end
				local suppress = cross < 2.2 or along < 2.2
				if suppress and (life > 0.15 or (frame.thermal_peak or 0) > 0.20) then
					if cross < 2.2 then
						cross = 2.2
					end
					if along < 2.2 then
						along = 2.2
					end
					suppress = false
				end
				found[#found + 1] = {
					a = run.a,
					b = run.b,
					mx = measured.mx,
					my = measured.my,
					tx = tx,
					ty = ty,
					nx = -ty,
					ny = tx,
					along = along,
					cross = cross,
					suppress = suppress,
				}
			end
		end
		frame.compact_runs = found
	end
	local runs = frame.compact_runs
	if not runs or #runs == 0 then
		return
	end
	frame.compact_blob = true
	local scale = BLOB_LAYER_SCALE[layer_key] or 1
	local drew = false
	local function clone_edge(src)
		local copy = {}
		if src then
			for k, v in pairs(src) do
				copy[k] = v
			end
		end
		return copy
	end
	for r = #runs, 1, -1 do
		local geom = runs[r]
		local along = geom.along * scale
		local cross = geom.cross * scale
		local suppress = geom.suppress or cross < 2.2 or along < 2.2
		local have = geom.b - geom.a + 1
		local add = 0
		if not suppress and have < 12 then
			add = 12 - have
			local at = geom.b
			for _ = 1, add do
				table.insert(upper, at, clone_edge(upper[at]))
				table.insert(lower, at, clone_edge(lower[at]))
			end
		end
		local count = have + add
		local last = geom.a + count - 1
		for i = geom.a, last do
			local up = upper[i]
			local lo = lower[i]
			if suppress then
				if up then
					up.heat_open = false
				end
				if lo then
					lo.heat_open = false
				end
			else
				local t = 0.5
				if count > 1 then
					t = (i - geom.a) / (count - 1)
				end
				local ang = math.pi * (1 - t)
				local along_pos = math.cos(ang) * along
				local half = math.sin(ang) * cross
				if half < 0 then
					half = 0
				end
				local floor_half = cross * 0.42
				if half < floor_half then
					half = floor_half
				end
				local px = geom.mx + geom.tx * along_pos
				local py = geom.my + geom.ty * along_pos
				local open_outer = layer_key == "outer"
				if up and (open_outer or up.heat_open ~= false) then
					up.x = px + geom.nx * half
					up.y = py + geom.ny * half
					up.cx = px
					up.cy = py
					up.tx = geom.tx
					up.ty = geom.ty
					up.nx = geom.nx
					up.ny = geom.ny
					up.compact_run = true
					if open_outer then
						up.heat_open = true
					end
				end
				if lo and up and (open_outer or lo.heat_open ~= false) then
					lo.x = px - geom.nx * half
					lo.y = py - geom.ny * half
					lo.cx = px
					lo.cy = py
					lo.tx = geom.tx
					lo.ty = geom.ty
					lo.compact_run = true
					if open_outer then
						lo.heat_open = true
					end
				end
				drew = true
			end
		end
		if layer_key == "outer" and not suppress then
			local slot = vis_slot(built, frame.segment_id)
			if slot then
				local thick = cross * 2
				if not slot.outer_thickness or thick < slot.outer_thickness then
					slot.outer_thickness = thick
				end
				slot.compact_blob = true
				slot.visual_class = frame.visual_class
			end
			built.compact_blob_count = (built.compact_blob_count or 0) + 1
		end
	end
	if layer_key == "outer" and drew then
		local new_area = ribbon_area(upper, lower, function(i)
			return upper[i] and upper[i].heat_open ~= false
		end)
		local slot = vis_slot(built, frame.segment_id)
		if slot and frame._outer_ribbon_area then
			slot.visible_outer_area = slot.visible_outer_area - frame._outer_ribbon_area + new_area
			frame._outer_ribbon_area = new_area
		end
	end
end

function regions.build(chains, cfg, time, emitting)
	local built = {
		outer = nil,
		orange = nil,
		gold = nil,
		white = nil,
		segment_count = 0,
		crossing = 0,
		invalid = 0,
		widths = { outer = {}, orange = {}, gold = {}, white = {} },
		events = {},
		wave_count = 0,
		tongue_attached = 0,
		head = nil,
		edge_samples = {},
		edge_by_id = {},
		edge_by_key = {},
		containment = 0,
		section_containment_failures = 0,
		front_containment_failures = 0,
		region_pierce_count = 0,
		region_pierce_unresolved = 0,
		front_depth = 0,
		front_width = 0,
		front_depth_ratio = 0,
		boundary_intersection_count = 0,
		boundary_smoothing_clamped = 0,
		sections = {},
		local_fold_count = 0,
		local_fold_repaired = 0,
		geometry_frame_us = 0,
		geometry_fit_us = 0,
		heat_split_count = 0,
		heat_zero_width = 0,
		heat_terminations = 0,
		head_valid_width = 0,
		heat_layers = {},
		validation_edge_tests = 0,
		validation_full_count = 0,
		geometry_validation_us = nil,
	}
	local motion = {
		events = {},
		wave_count = 0,
		tongue_attached = 0,
		bulges = {},
		mid = {},
		tongues = {},
	}
	built.wave_count = 0
	built.tongue_attached = 0
	built.events = motion.events
	local merged = {
		outer = { upper = {}, lower = {} },
		orange = { upper = {}, lower = {} },
		gold = { upper = {}, lower = {} },
		white = { upper = {}, lower = {} },
	}
	for c = 1, #chains do
		local t_frame = Isaac.GetNanoTime and Isaac.GetNanoTime() or nil
		local frame = with_frame(chains[c])
		if t_frame and Isaac.GetNanoTime then
			built.geometry_frame_us = built.geometry_frame_us + (Isaac.GetNanoTime() - t_frame) / 1000
		end
		built.current_segment_id = frame.segment_id
		local peak = 0
		for pi = 1, #frame do
			local profile = frame[pi].render_profile or frame[pi].temp_profile
			if profile then
				for hk = 1, 9 do
					local sample = profile[hk] or 0
					if sample > peak then
						peak = sample
					end
				end
			elseif (frame[pi].temperature or 0) > peak then
				peak = frame[pi].temperature
			end
		end
		frame.thermal_peak = peak
		frame.residual_only = frame.phase ~= "emitting" and peak < 0.08 and (frame.residual or 0) > 0.02
		if frame.phase ~= "emitting" and peak < 0.08 and (frame.residual or 0) <= 0.02 then
			local slot = vis_slot(built, frame.segment_id)
			if slot and slot.invisible_reason == "" then
				slot.invisible_reason = "temperature_closed"
				slot.temperature_threshold_failures = slot.temperature_threshold_failures + #frame
			end
		end
		if #frame >= 2 then
			local tip = frame[#frame]
			local tip_point = {
				x = tip.x + tip.tx * 8,
				y = tip.y + tip.ty * 8,
				heat = tip.heat,
			}
			if cfg.static_solid then
				tip_point.x = tip.x + tip.tx * 8
				tip_point.y = tip.y + tip.ty * 8
			else
				prepare_head(frame)
				cfg.front_phase = frame.sway_phase
				frame.edge = {}
				frame.front_pts = {}
				frame.outline = {}
				local info = frame.head_tip
				if info and (not built.head or (tip.s or 0) > (built.head.travel or -1)) then
					frame.is_lead = true
					built.head = {
						travel = tip.s or 0,
						length = frame.head_length,
						width = frame.head_width,
						cool = 1 - (info.temp or 1),
						tip_x = info.x,
						tip_y = info.y,
						taper_x = frame.head_taper.x,
						taper_y = frame.head_taper.y,
						vx = info.vx or 0,
						vy = info.vy or 0,
						speed = math.sqrt((info.vx or 0) ^ 2 + (info.vy or 0) ^ 2),
					}
				end
			end
			for li = 1, #LAYERS do
				local spec = LAYERS[li]
				local skip_layer = frame.lod and frame.lod >= 2 and spec.key == "white"
				if spec.key ~= "outer" and (frame.thermal_peak or 1) < (HEAT_CUT[spec.key] or 1) then
					skip_layer = true
				end
				if frame.residual_only and spec.key ~= "outer" then
					skip_layer = true
				end
				if frame.phase ~= "emitting" and (frame.thermal_peak or 1) < 0.08 and (frame.residual or 0) <= 0.02 then
					skip_layer = true
				end
				if not skip_layer then
				local upper = {}
				local lower = {}
				for i = 1, #frame do
					local p = frame[i]
					if p.x ~= p.x or p.y ~= p.y then
						built.invalid = built.invalid + 1
					else
						local base = base_half(p.s, cfg)
						local outer_u, outer_l, lean_u, lean_l = base, base, 0, 0
						local temp = p.temperature or p.heat or 1
						if temp < 0 then temp = 0 end
						if temp > 1 then temp = 1 end
						if not cfg.static_solid then
							outer_u = (p.ru or base) + (p.extra_u or 0)
							outer_l = (p.rl or base) + (p.extra_l or 0)
							lean_u = p.lean_u or 0
							lean_l = p.lean_l or 0
							lean_u, lean_l = 0, 0
							if outer_u < 0 then outer_u = 0 end
							if outer_l < 0 then outer_l = 0 end
						end
						local progress = 0
						if cfg.length and cfg.length > 0 then
							progress = (p.s or 0) / cfg.length
						end
						if progress < 0 then progress = 0 end
						if progress > 1 then progress = 1 end
						local frac = spec.frac or cfg[spec.frac_key] or 1
						local gate = falloff(p.s, cfg.length, spec.fall_start, spec.fall_end)
						local shift = 0
						local ext_u, ext_l = 0, 0
						if not cfg.static_solid then
							frac = 1
							local wave = layer_wave(p.s or 0, time, spec.key, cfg.layer_wave or 1)
							gate = layer_factor(spec.key, temp, wave, progress)
							if spec.frac_key then
								local base = spec.key == "orange" and C.ORANGE_FRAC or spec.key == "gold" and C.GOLD_FRAC or C.WHITE_FRAC
								local want = cfg[spec.frac_key] or base
								if base > 0 then
									gate = gate * (want / base)
								end
							end
							local ufront = front_u(p.dist_to_tip or 0, frame.head_length)
							ext_u = front_extent(spec.key, 0, ufront, frame.front_seed or 1, cfg)
							ext_l = front_extent(spec.key, 1, ufront, frame.front_seed or 1, cfg)
							local smooth_u = outer_u
							local smooth_l = outer_l
							if spec.key ~= "outer" and frame.edge then
								local radius = spec.key == "gold" and 6 or spec.key == "white" and 5 or 4
								local su = neighborhood_half(frame.edge, i, 1, radius)
								local sl = neighborhood_half(frame.edge, i, -1, radius)
								if su then
									smooth_u = su
								end
								if sl then
									smooth_l = sl
								end
							end
							if spec.key == "gold" then
								shift = wave * smooth_u * 0.12
							elseif spec.key == "white" then
								shift = wave * smooth_u * 0.08
							elseif spec.key == "orange" then
								shift = wave * smooth_u * 0.06
							end
							p._smooth_u = smooth_u
							p._smooth_l = smooth_l
						end
						local core_bump = 0
						local core_shift = 0
						local function contained(outer_w)
							local w = outer_w * frac * gate * (1 + core_bump)
							if w > outer_w then
								built.crossing = built.crossing + 1
								w = outer_w
							end
							if w < 0 then
								w = 0
							end
							return w
						end
						local function clamp_side(w, outer_w)
							if w > outer_w then
								built.crossing = built.crossing + 1
								w = outer_w
							end
							if w < 0 then
								w = 0
							end
							return w
						end
						local wu = contained(outer_u)
						local wl = contained(outer_l)
						if not cfg.static_solid and spec.key == "outer" then
							wu, wl = outer_u * gate, outer_l * gate
						elseif not cfg.static_solid then
							wu = (p._smooth_u or outer_u) * gate
							wl = (p._smooth_l or outer_l) * gate
						elseif spec.key ~= "outer" then
							wu = clamp_side(wu, outer_u)
							wl = clamp_side(wl, outer_l)
						end
						if cfg.static_solid and i == #frame then
							wu, wl = 0, 0
							shift = 0
						end
						local off_u = shift + wu
						local off_l = shift - wl
						local heat_profile = p.render_profile or p.temp_profile
						local heat_on = cfg.heat_regions ~= false and not cfg.static_solid and heat_profile
						local heat_open = true
						local heat_peak = nil
						if heat_on then
							local hi, lo, split, valid, peak = regions.primary_heat_offsets(heat_profile, outer_u, outer_l, HEAT_CUT[spec.key])
							heat_peak = peak
							if valid then
								off_u = hi
								off_l = lo
							elseif cfg.heat_legacy_collapse then
								off_u = hi
								off_l = lo
							else
								heat_open = false
								off_u = 0
								off_l = 0
							end
							if split then
								built.heat_split_count = built.heat_split_count + 1
							end
						end
						local use_lean_u = cfg.static_solid and spec.key == "outer" and lean_u or 0
						local use_lean_l = cfg.static_solid and spec.key == "outer" and lean_l or 0
						upper[i] = {
							x = p.x + p.nx * off_u + p.tx * (use_lean_u + ext_u),
							y = p.y + p.ny * off_u + p.ty * (use_lean_u + ext_u),
							off_u = off_u,
							ext_u = use_lean_u + ext_u,
							nx = p.nx,
							ny = p.ny,
							tx = p.tx,
							ty = p.ty,
							vx = p.vx or 0,
							vy = p.vy or 0,
							extra = p.extra_u or 0,
							heat = p.heat,
							temperature = temp,
							id = p.id,
							cx = p.x,
							cy = p.y,
							along = p.chain_span and p.chain_span > 0 and (1 - (p.dist_to_tip or 0) / p.chain_span) or 0,
							s = p.s,
							front = frame.head_length and (p.dist_to_tip or 9999) < frame.head_length or false,
							progress = progress,
							heat_open = heat_open,
							thermal_open = heat_open,
							heat_peak = heat_peak,
							sway_phase = p.sway_phase,
							dist_to_tip = p.dist_to_tip,
							segment_id = p.segment_id,
						}
						lower[i] = {
							x = p.x + p.nx * off_l + p.tx * (use_lean_l + ext_l),
							y = p.y + p.ny * off_l + p.ty * (use_lean_l + ext_l),
							off_l = off_l,
							ext_l = use_lean_l + ext_l,
							nx = -p.nx,
							ny = -p.ny,
							tx = p.tx,
							ty = p.ty,
							vx = p.vx or 0,
							vy = p.vy or 0,
							extra = p.extra_l or 0,
							heat = p.heat,
							temperature = temp,
							id = p.id,
							cx = p.x,
							cy = p.y,
							along = upper[i].along,
							front = upper[i].front,
							heat_open = heat_open,
							thermal_open = heat_open,
							heat_peak = heat_peak,
						}
						if spec.key == "outer" and heat_open then
							stamp_event(motion, 0, p.s, upper[i].x, upper[i].y, p.nx, p.ny, p.tx, p.ty)
							stamp_event(motion, 1, p.s, lower[i].x, lower[i].y, -p.nx, -p.ny, p.tx, p.ty)
						end
						local bucket = built.widths[spec.key]
						if heat_open then
							bucket[#bucket + 1] = (off_u - off_l) * 0.5
						end
					end
				end
				if spec.key == "outer" and not cfg.static_solid then
					apply_outer_residual(frame, upper, lower, built)
				end
				if not cfg.static_solid and #upper >= 2 then
					local offs = {}
					local open_flags = {}
					for i = 1, #upper do
						offs[i] = {
							u = upper[i].off_u or 0,
							l = lower[i] and lower[i].off_l or 0,
						}
						open_flags[i] = upper[i].heat_open ~= false
					end
					local passes = spec.key == "outer" and 1 or spec.key == "orange" and 2 or spec.key == "gold" and 3 or 2
					local limit = spec.key == "outer" and 10 or spec.key == "orange" and 4 or spec.key == "gold" and 2.5 or 1.5
					if cfg.heat_regions ~= false and not cfg.static_solid then
						if spec.key == "white" then
							passes = 0
						elseif spec.key == "gold" then
							passes = 1
							limit = 6
						elseif spec.key == "orange" then
							passes = 1
							limit = 8
						else
							passes = 1
							limit = 14
						end
					end
					local smooth_open = nil
					if cfg.heat_regions ~= false and not cfg.static_solid and not cfg.heat_legacy_collapse then
						smooth_open = open_flags
					end
					built.boundary_smoothing_clamped = (built.boundary_smoothing_clamped or 0) + smooth_offsets(offs, passes, limit, smooth_open)
					local parent_key = PARENT_LAYER[spec.key]
					local margin = cfg.layer_margin or 1.5
					frame.edge = frame.edge or {}
					for i = 1, #offs do
						local parent_bound = parent_key and frame.edge[i] and frame.edge[i][parent_key]
						if parent_bound then
							local u, l, hit = contain_offsets(offs[i].u, offs[i].l, parent_bound.u, parent_bound.l, margin)
							offs[i].u = u
							offs[i].l = l
							if hit then
								built.section_containment_failures = (built.section_containment_failures or 0) + 1
								built.containment = (built.containment or 0) + 1
							end
						end
						if offs[i].l > offs[i].u then
							local mid = (offs[i].u + offs[i].l) * 0.5
							offs[i].u = mid
							offs[i].l = mid
						end
						frame.edge[i] = frame.edge[i] or {}
						local up = upper[i]
						local lo = lower[i]
						local eu = up and up.ext_u or 0
						local el = lo and lo.ext_l or 0
						if parent_bound then
							if parent_bound.ext_u and eu > parent_bound.ext_u then
								eu = parent_bound.ext_u
							end
							if parent_bound.ext_l and el > parent_bound.ext_l then
								el = parent_bound.ext_l
							end
						end
						frame.edge[i][spec.key] = { u = offs[i].u, l = offs[i].l, ext_u = eu, ext_l = el }
						if up and up.cx then
							up.off_u = offs[i].u
							up.ext_u = eu
							up.x = up.cx + up.nx * offs[i].u + up.tx * eu
							up.y = up.cy + up.ny * offs[i].u + up.ty * eu
						end
						if lo and up and lo.cx then
							lo.off_l = offs[i].l
							lo.ext_l = el
							lo.x = lo.cx + up.nx * offs[i].l + up.tx * el
							lo.y = lo.cy + up.ny * offs[i].l + up.ty * el
						end
						if frame.is_lead then
							built.sections[i] = built.sections[i] or { index = i }
							built.sections[i].slice_id = up and up.id or nil
							if up and up.heat_open == false then
								built.sections[i][spec.key .. "_open"] = false
							else
								built.sections[i][spec.key .. "_open"] = true
								built.sections[i][spec.key .. "_upper"] = offs[i].u
								built.sections[i][spec.key .. "_lower"] = offs[i].l
							end
						end
					end
				end
				if #upper >= 2 then
					local t_audit = Isaac.GetNanoTime and Isaac.GetNanoTime() or nil
					local folds, local_hit, tests = 0, false, 0
					local self_hit = false
					local edge_pair = nil
					folds, local_hit, tests = audit_local(upper, lower)
					self_hit = local_hit
					local coarse = frame.lod and frame.lod >= 2
					local full = local_hit or (cfg.audit_screen == true and not coarse)
					if full then
						local hit2, tests2, edges = audit_full(upper, lower)
						self_hit = hit2
						edge_pair = edges
						tests = tests + tests2
						built.validation_full_count = built.validation_full_count + 1
					end
					if t_audit and Isaac.GetNanoTime then
						local us = (Isaac.GetNanoTime() - t_audit) / 1000
						built.geometry_validation_us = (built.geometry_validation_us or 0) + us
					end
					built.local_fold_count = built.local_fold_count + folds
					built.validation_edge_tests = built.validation_edge_tests + tests
					if self_hit and upper[1] then
						upper[1].audit_skip = true
						upper[1].fold_count = folds
						note_pre_split(built, spec.key, edge_pair or "local")
					end
					if spec.key == "outer" and cfg.static_solid then
						upper[#upper] = tip_point
						lower[#lower] = tip_point
					end
					if not cfg.static_solid then
						local parent_key = PARENT_LAYER[spec.key]
						local parent_poly = parent_key and frame.outline and frame.outline[parent_key]
						if parent_poly then
							local t_fit = Isaac.GetNanoTime and Isaac.GetNanoTime() or nil
							local moved, unresolved = fit_body(upper, lower, parent_poly, cfg.layer_margin or 1.5, built, frame, spec.key)
							if t_fit and Isaac.GetNanoTime then
								built.geometry_fit_us = built.geometry_fit_us + (Isaac.GetNanoTime() - t_fit) / 1000
							end
							built.region_pierce_count = (built.region_pierce_count or 0) + moved
							built.region_pierce_unresolved = (built.region_pierce_unresolved or 0) + unresolved
						end
						local last = #upper
						if #lower < last then
							last = #lower
						end
						local step = 1
						if frame.lod and frame.lod >= 2 then
							step = 2
						end
						local function scan_cross(stride)
							for i = 1, last - 1, stride do
								local a = upper[i]
								local b = upper[i + 1]
								local c = lower[i]
								local d = lower[i + 1]
								if a and b and c and d and a.heat_open ~= false and b.heat_open ~= false and a.x and b.x and c.x and d.x and proper_cross(a, b, c, d) then
									return i
								end
							end
							return nil
						end
						local hit = scan_cross(step)
						if hit and step > 1 then
							hit = scan_cross(1)
						end
						if hit then
							built.boundary_intersection_count = (built.boundary_intersection_count or 0) + 1
							if upper[1] then
								upper[1].audit_skip = true
								note_pre_split(built, spec.key, "u" .. hit .. "-" .. (hit + 1) .. "xl" .. hit)
							end
						end
						note_bands(built, frame, upper, spec.key)
					end
					local heat_terminate = cfg.heat_regions ~= false and not cfg.static_solid and not cfg.heat_legacy_collapse
					local heat_runs = nil
					local run_caps = nil
					local head_u = nil
					local head_l = nil
					local cap = nil
					if heat_terminate then
						reshape_compact_blob(frame, upper, lower, built, spec.key)
						local open_before = 0
						local closed_thin = 0
						for i = 1, #upper do
							local up = upper[i]
							local lo = lower[i]
							if up and lo and up.heat_open ~= false then
								open_before = open_before + 1
								local dx = up.x - lo.x
								local dy = up.y - lo.y
								if dx * dx + dy * dy < 2.25 then
									local prev_open = i > 1 and upper[i - 1] and upper[i - 1].heat_open ~= false
									local next_open = upper[i + 1] and upper[i + 1].heat_open ~= false
									if not (prev_open and next_open) then
										up.heat_open = false
										lo.heat_open = false
										closed_thin = closed_thin + 1
									end
								end
							end
						end
						heat_runs = heat_open_runs(upper)
						note_layer_draw(vis_slot(built, frame.segment_id), spec.key, frame, upper, lower)
						local slot = vis_slot(built, frame.segment_id)
						if slot then
							if spec.key == "outer" then
								if not slot.visible_runs then
									slot.visible_runs = {}
									slot.visible_run_arc = 0
								end
								for ri = 1, #heat_runs do
									local run = heat_runs[ri]
									local arc = 0
									local prev = nil
									for i = run.a, run.b do
										local sample = frame[i]
										if prev and sample then
											local dx = (sample.x or 0) - (prev.x or 0)
											local dy = (sample.y or 0) - (prev.y or 0)
											arc = arc + math.sqrt(dx * dx + dy * dy)
										end
										prev = sample
									end
									local head = frame[run.a]
									local tail = frame[run.b]
									slot.visible_runs[#slot.visible_runs + 1] = {
										a = head and head.id or 0,
										b = tail and tail.id or 0,
										a_s = head and head.release_s or 0,
										b_s = tail and tail.release_s or 0,
										n = run.b - run.a + 1,
										arc = arc,
									}
									slot.visible_run_arc = (slot.visible_run_arc or 0) + arc
								end
								slot.residual_run_count = (slot.residual_run_count or 0) + #heat_runs
								slot.generated_polygon_count = slot.generated_polygon_count + #heat_runs
								if #heat_runs > 0 then
									slot.invisible_reason = ""
									slot.residual_reject_reason = ""
									if slot.geometry_failures > 0 then
										slot.geometry_failures_drawn = slot.geometry_failures
									end
								elseif slot.generated_polygon_count == 0 and ((slot.residual_candidate_count or 0) > 0 or (slot.residual_open_count or 0) > 0 or (slot.outer_heat_open_count or 0) > 0) then
									local reject = frame.residual_block
									if not reject then
										if closed_thin > 0 and closed_thin >= open_before then
											reject = "width_closed"
										elseif slot.geometry_failures > 0 then
											reject = "invalid_geometry"
										else
											reject = "heat_runs_empty"
										end
									end
									slot.residual_reject_reason = reject
									slot.invisible_reason = reject
								elseif slot.geometry_failures > 0 then
									slot.invisible_reason = "invalid_geometry"
									slot.residual_reject_reason = "invalid_geometry"
								elseif slot.outer_heat_open_count == 0 and slot.residual_open_count == 0 then
									slot.invisible_reason = "temperature_closed"
									slot.residual_reject_reason = ""
								end
							elseif spec.key == "gold" or spec.key == "white" then
								slot.core_polygon_count = slot.core_polygon_count + #heat_runs
							end
						end
						if not frame.compact_blob then
							local segment_id = frame.segment_id or c
							-- The held tip owns this segment's travel and width. A gap fragment
							-- shares segment_id, but its far face is a different slice: reading
							-- the tip slot stretches that face, and writing it collapses the tip.
							local memory_id = segment_id
							if frame.front_gap then
								local own = frame[#frame]
								memory_id = "end:" .. tostring(own and own.id or 0)
							end
							local ease_before = nil
							local ease_held = false
							local ease_remembered = nil
							local ease_before_w = nil
							if spec.key == "outer" and heat_runs[1] then
								local last = heat_runs[#heat_runs]
								local tail = upper[last.b]
								local face = lower[last.b]
								ease_before = {
									b = last.b,
									n = last.b - last.a + 1,
									s = tail and tail.s or 0,
									id = tail and tail.id or 0,
								}
								if tail and face and tail.x and face.x then
									local dx = tail.x - face.x
									local dy = tail.y - face.y
									ease_before_w = math.sqrt(dx * dx + dy * dy)
								end
								local memory = chains.layer_memory
								local hold = memory and memory.hold
								ease_held = hold and hold[memory_id] == true or false
								local layer = memory and memory.layers and memory.layers[memory_id]
								local travel = layer and layer.travel
								ease_remembered = travel and travel.outer or nil
							end
							ease_layer_end(chains.layer_memory, memory_id, upper, lower, heat_runs, spec.key)
							if ease_before then
								local last = heat_runs[#heat_runs]
								local head = upper[last.a]
								local tail = upper[last.b]
								local face = lower[last.b]
								local after_w = nil
								if tail and face and tail.x and face.x then
									local dx = tail.x - face.x
									local dy = tail.y - face.y
									after_w = math.sqrt(dx * dx + dy * dy)
								end
								local slot = vis_slot(built, segment_id)
								if slot then
									local list = slot.emit_runs
									if not list then
										list = {}
										slot.emit_runs = list
									end
									if #list < 4 then
										local min_x, max_x = nil, nil
										for ei = last.a, last.b do
											local point = upper[ei]
											local x = point and (point.cx or point.x)
											if x then
												if not min_x or x < min_x then min_x = x end
												if not max_x or x > max_x then max_x = x end
											end
										end
										list[#list + 1] = {
											before_n = ease_before.n,
											before_id = ease_before.id,
											before_s = math.floor(ease_before.s + 0.5),
											after_n = last.b - last.a + 1,
											after_id = tail and tail.id or 0,
											after_s = math.floor(((tail and tail.s) or 0) + 0.5),
											head_id = head and head.id or 0,
											head_s = math.floor(((head and head.s) or 0) + 0.5),
											held = ease_held,
											own = frame.front_gap == true,
											remembered = ease_remembered and math.floor(ease_remembered + 0.5) or nil,
											before_w = ease_before_w and math.floor(ease_before_w + 0.5) or nil,
											after_w = after_w and math.floor(after_w + 0.5) or nil,
											world_x = { math.floor((min_x or 0) + 0.5), math.floor((max_x or 0) + 0.5) },
										}
									end
								end
							end
						end
						run_caps = {}
						local polys = {}
						local valid = 0
						local zero = 0
						local first_i = nil
						local last_i = nil
						for i = 1, #upper do
							if upper[i].heat_open == false then
								zero = zero + 1
							else
								valid = valid + 1
								first_i = first_i or i
								last_i = i
							end
						end
						local term = 0
						local end_x, end_y = nil, nil
						for r = 1, #heat_runs do
							local run = heat_runs[r]
							local up = upper[run.b]
							local lo = lower[run.b]
							local tip_u, tip_l, frac, tx, ty = run.tip_u, run.tip_l, nil, run.end_x, run.end_y
							if not tip_u then
								tip_u, tip_l, frac, tx, ty = termination_tip(upper, lower, run.b, HEAT_CUT[spec.key])
							end
							if tip_u then
								run.tip_u = tip_u
								run.tip_l = tip_l
								run.frac = frac
								up = tip_u
								lo = tip_l
								end_x, end_y = tx, ty
								term = term + 1
							else
								end_x, end_y = up.cx, up.cy
							end
							local dx = up.x - lo.x
							local dy = up.y - lo.y
							local one = nil
							local compact_owned = closed_run_is_compact(frame, upper, lower, run)
							local compact_front = (not compact_owned) and (frame.front_gap or ((frame.phase ~= "emitting") and (frame.visual_class == "short" or frame.visual_class == "blob")))
							if not compact_owned and dx * dx + dy * dy >= 2.25 then
								if compact_front then
									if run.b == #upper then
										local face_w = math.sqrt(dx * dx + dy * dy)
										local arc = frame.piece_arc or face_w
										local depth = face_w * 0.22
										if frame.visual_class == "blob" then
											depth = face_w * 0.32
										elseif frame.front_gap and frame.visual_class ~= "short" then
											depth = face_w * 0.26
										end
										if depth > arc * 0.35 then
											depth = arc * 0.35
										end
										one = compact_front_cap(up, lo, depth)
									end
								else
									one = build_cap(up, lo, up.tx or tip.tx, up.ty or tip.ty, frame.front_seed or 1, spec.key, cfg, time)
									local parent_key = PARENT_LAYER[spec.key]
									local parent_poly = parent_key and frame.outline and frame.outline[parent_key]
									if parent_poly and one then
										local t_fit = Isaac.GetNanoTime and Isaac.GetNanoTime() or nil
										local moved, unresolved = fit_cap(one, up, lo, parent_poly, cfg.layer_margin or 1.5)
										if t_fit and Isaac.GetNanoTime then
											built.geometry_fit_us = built.geometry_fit_us + (Isaac.GetNanoTime() - t_fit) / 1000
										end
										built.region_pierce_count = (built.region_pierce_count or 0) + moved
										built.front_containment_failures = (built.front_containment_failures or 0) + moved
										built.region_pierce_unresolved = (built.region_pierce_unresolved or 0) + unresolved
									end
								end
							end
							run_caps[r] = one
							local slice_u = {}
							local slice_l = {}
							for i = run.a, run.b do
								slice_u[#slice_u + 1] = upper[i]
								slice_l[#slice_l + 1] = lower[i]
							end
							if run.tip_u then
								slice_u[#slice_u + 1] = run.tip_u
								slice_l[#slice_l + 1] = run.tip_l
							end
							polys[#polys + 1] = closed_outline(slice_u, slice_l, one)
							cap = one
							head_u = up
							head_l = lo
						end
						if #polys == 1 then
							frame.outline[spec.key] = polys[1]
						elseif #polys > 1 then
							frame.outline[spec.key] = polys
						end
						keep_fit_outline(built, frame, spec.key, frame.outline[spec.key])
						built.heat_layers = built.heat_layers or {}
						built.heat_layers[spec.key] = {
							valid = valid,
							zero_width = zero,
							first = first_i,
							last = last_i,
							terminations = term,
							end_x = end_x,
							end_y = end_y,
						}
						built.heat_zero_width = (built.heat_zero_width or 0) + zero
						built.heat_terminations = (built.heat_terminations or 0) + term
						if spec.key == "outer" and head_u and head_l then
							local hx = head_u.x - head_l.x
							local hy = head_u.y - head_l.y
							built.head_valid_width = math.sqrt(hx * hx + hy * hy)
						end
					elseif not cfg.static_solid and upper[#upper] and lower[#lower] then
						note_layer_draw(vis_slot(built, frame.segment_id), spec.key, frame, upper, lower)
						cap = build_cap(upper[#upper], lower[#lower], tip.tx, tip.ty, frame.front_seed or 1, spec.key, cfg, time)
						local parent_key = PARENT_LAYER[spec.key]
						local parent_poly = parent_key and frame.outline and frame.outline[parent_key]
						if parent_poly then
							local t_fit = Isaac.GetNanoTime and Isaac.GetNanoTime() or nil
							local moved, unresolved = fit_cap(cap, upper[#upper], lower[#lower], parent_poly, cfg.layer_margin or 1.5)
							if t_fit and Isaac.GetNanoTime then
								built.geometry_fit_us = built.geometry_fit_us + (Isaac.GetNanoTime() - t_fit) / 1000
							end
							built.region_pierce_count = (built.region_pierce_count or 0) + moved
							built.front_containment_failures = (built.front_containment_failures or 0) + moved
							built.region_pierce_unresolved = (built.region_pierce_unresolved or 0) + unresolved
						end
						if upper[#upper] and lower[#lower] then
							local prev = upper[#upper]
							local chord_a = upper[#upper]
							local chord_b = lower[#lower]
							for ci = 1, #cap do
								if proper_cross(prev, cap[ci], chord_a, chord_b) then
									built.boundary_intersection_count = (built.boundary_intersection_count or 0) + 1
									if upper[1] then
										upper[1].audit_skip = true
										note_pre_split(built, spec.key, "cap" .. ci)
									end
								end
								prev = cap[ci]
							end
							if #cap >= 1 and proper_cross(cap[#cap], chord_b, chord_a, chord_b) then
								built.boundary_intersection_count = (built.boundary_intersection_count or 0) + 1
							end
						end
						frame.outline = frame.outline or {}
						frame.outline[spec.key] = closed_outline(upper, lower, cap)
						keep_fit_outline(built, frame, spec.key, frame.outline[spec.key])
						local front_poly = { upper[#upper] }
						for ci = 1, #cap do
							front_poly[#front_poly + 1] = cap[ci]
						end
						front_poly[#front_poly + 1] = lower[#lower]
						frame.front_pts[spec.key] = front_poly
					end
					if spec.key == "outer" and not cfg.static_solid and frame.is_lead and (head_u or not heat_terminate) then
						local up = head_u or upper[#upper]
						local lo = head_l or lower[#lower]
						local info = frame.head_tip or {}
						built.head = built.head or {}
						built.head.length = frame.head_length
						built.head.width = frame.head_width
						built.head.cool = 1 - (info.temp or 1)
						built.head.tip_x = info.x
						built.head.tip_y = info.y
						built.head.upper_x = up.x
						built.head.upper_y = up.y
						built.head.lower_x = lo.x
						built.head.lower_y = lo.y
						built.head.break_x = (up.x + lo.x) * 0.5 + tip.tx * 12 * (cfg.front_bloom or 1)
						built.head.break_y = (up.y + lo.y) * 0.5 + tip.ty * 12 * (cfg.front_bloom or 1)
						built.head.vx = info.vx or 0
						built.head.vy = info.vy or 0
						built.head.speed = math.sqrt((info.vx or 0) ^ 2 + (info.vy or 0) ^ 2)
						built.head.travel = tip.s or 0
						built.head.taper_x = frame.head_taper.x
						built.head.taper_y = frame.head_taper.y
						built.front_cap_count = cap and #cap or 0
						local depth, width = cap_reach(cap, up, lo, tip.tx, tip.ty)
						built.front_depth = depth
						built.front_width = width
						built.front_depth_ratio = width > 1 and depth / width or 0
						built.front_core_distance = tip.s or 0
						built.front_outer_upper_distance = (tip.s or 0) + (up.x - info.x) * tip.tx + (up.y - info.y) * tip.ty
						built.front_outer_lower_distance = (tip.s or 0) + (lo.x - info.x) * tip.tx + (lo.y - info.y) * tip.ty
						local visual = built.front_core_distance
						if built.front_outer_upper_distance > visual then visual = built.front_outer_upper_distance end
						if built.front_outer_lower_distance > visual then visual = built.front_outer_lower_distance end
						built.front_visual_extent = visual
					end
					if spec.key == "outer" and not cfg.static_solid then
						built.edge_samples = built.edge_samples or {}
						local samples = built.edge_samples
						local function push_segment(a, b, ix, iy, side, force_front)
							if not a or not b or not a.x or not b.x then
								return
							end
							local sx = b.x - a.x
							local sy = b.y - a.y
							local len = math.sqrt(sx * sx + sy * sy)
							if len < 0.35 then
								return
							end
							local tx = sx / len
							local ty = sy / len
							local nx = -ty
							local ny = tx
							local mx = (a.x + b.x) * 0.5
							local my = (a.y + b.y) * 0.5
							local dx = mx - ix
							local dy = my - iy
							if nx * dx + ny * dy < 0 then
								nx, ny = -nx, -ny
							end
							if dx * dx + dy * dy < 0.04 then
								local ex = (a.nx or 0) + (b.nx or 0)
								local ey = (a.ny or 0) + (b.ny or 0)
								local nlen = math.sqrt(ex * ex + ey * ey)
								if nlen > 0.001 then
									ex, ey = ex / nlen, ey / nlen
									local ox, oy = dx, dy
									if ox * ox + oy * oy < 0.04 then
										ox, oy = nx, ny
									end
									if ex * ox + ey * oy < 0 then
										ex, ey = -ex, -ey
									end
									nx, ny = ex, ey
								end
							end
							local prev_tx = a.tx or tx
							local prev_ty = a.ty or ty
							local sample = {
								x = mx,
								y = my,
								nx = nx,
								ny = ny,
								tx = tx,
								ty = ty,
								length = len,
								vx = ((a.vx or 0) + (b.vx or 0)) * 0.5,
								vy = ((a.vy or 0) + (b.vy or 0)) * 0.5,
								along = ((a.along or 0) + (b.along or 0)) * 0.5,
								front = force_front or a.front == true or b.front == true,
								bulge = ((a.extra or 0) + (b.extra or 0)) * 0.5,
								curvature = math.abs(prev_tx * ty - prev_ty * tx),
								temperature = ((a.temperature or a.heat or 0.5) + (b.temperature or b.heat or 0.5)) * 0.5,
								side = side,
								id = a.id or b.id,
								id_b = b.id,
								segment_id = a.segment_id or b.segment_id,
								edge_key = a.edge_key,
								jet_x = a.jet_x or b.jet_x,
								jet_y = a.jet_y or b.jet_y,
								ax = a.x,
								ay = a.y,
								bx = b.x,
								by = b.y,
								half = math.sqrt(dx * dx + dy * dy),
								travel = ((a.s or 0) + (b.s or 0)) * 0.5,
							}
							samples[#samples + 1] = sample
							local function put_edge(id)
								if not id then
									return
								end
								local slot = built.edge_by_id[id]
								if not slot then
									slot = { upper = {}, lower = {}, front = {}, rear = {} }
									built.edge_by_id[id] = slot
								end
								local list = slot[side]
								if not list then
									list = slot.front
								end
								list[#list + 1] = sample
							end
							put_edge(sample.id)
							if sample.id_b and sample.id_b ~= sample.id then
								put_edge(sample.id_b)
							end
							if sample.edge_key then
								built.edge_by_key[sample.edge_key] = sample
							end
						end
						local function walk_side(points, side)
							for i = 1, #points - 1 do
								local a = points[i]
								local b = points[i + 1]
								if a.heat_open == false or b.heat_open == false then
									a = nil
								end
								if not a or not b then
									-- Closed sections do not continue the edge.
								else
								local ix = ((a.cx or a.x) + (b.cx or b.x)) * 0.5
								local iy = ((a.cy or a.y) + (b.cy or b.y)) * 0.5
								push_segment(a, b, ix, iy, side, false)
								end
							end
						end
						walk_side(upper, "upper")
						walk_side(lower, "lower")
						if cap and (head_u or upper[#upper]) and (head_l or lower[#lower]) then
							local info = frame.head_tip or {}
							local ix = info.x or tip.x
							local iy = info.y or tip.y
							local temp = info.temp or 0.5
							local vx = info.vx or 0
							local vy = info.vy or 0
							local tip_pt = head_u or upper[#upper]
							local tip_id = tip_pt and tip_pt.id
							local tail_pt = head_l or lower[#lower]
							local seg_id = (tip_pt and tip_pt.segment_id) or (tail_pt and tail_pt.segment_id)
							local chain = { tip_pt }
							for i = 1, #cap do
								chain[#chain + 1] = {
									x = cap[i].x,
									y = cap[i].y,
									vx = vx,
									vy = vy,
									along = 1,
									front = true,
									extra = 12,
									temperature = temp,
									tx = tip.tx,
									ty = tip.ty,
									id = tip_id,
									segment_id = seg_id,
									jet_x = tip.tx,
									jet_y = tip.ty,
									s = tip.s,
								}
							end
							chain[#chain + 1] = tail_pt
							for i = 1, #chain - 1 do
								local node = chain[i]
								local nxt = chain[i + 1]
								if node and not node.segment_id then
									node.segment_id = seg_id
								end
								if nxt and not nxt.segment_id then
									nxt.segment_id = seg_id
								end
								if node and not node.jet_x then
									node.jet_x = tip.tx
									node.jet_y = tip.ty
								end
								if node then
									node.edge_key = tostring(seg_id or 0) .. ":front:" .. tostring(i)
								end
								push_segment(node, nxt, ix, iy, "front", true)
							end
						end
					end
					local pack = merged[spec.key]
					local dest_u = pack.upper
					local dest_l = pack.lower
					local function copy_pt(p, fine)
						return {
							x = p.x, y = p.y, nx = p.nx, ny = p.ny,
							tx = p.tx, ty = p.ty, vx = p.vx, vy = p.vy,
							extra = p.extra, heat = p.heat, along = p.along,
							front = p.front, fine = fine or nil,
							segment_id = p.segment_id,
							cx = p.cx, cy = p.cy,
							off_u = p.off_u, off_l = p.off_l,
							ext_u = p.ext_u, ext_l = p.ext_l,
							heat_open = p.heat_open,
							source_audit_skip = p.audit_skip == true or nil,
						}
					end
					local function emit(from, to, fine, use_cap, tip_u, tip_l, rear)
						if rear and rear.upper and rear.lower then
							for i = 1, #rear.upper do
								dest_u[#dest_u + 1] = copy_pt(rear.upper[i], false)
								dest_l[#dest_l + 1] = copy_pt(rear.lower[i], false)
							end
							if spec.key == "outer" then
								built.rear_cap_count = (built.rear_cap_count or 0) + 1
							end
						end
						for i = from, to do
							dest_u[#dest_u + 1] = copy_pt(upper[i], fine and i == from)
							dest_l[#dest_l + 1] = copy_pt(lower[i], false)
							if i < to then
								built.segment_count = built.segment_count + 1
							end
						end
						if tip_u and tip_l then
							dest_u[#dest_u + 1] = copy_pt(tip_u, false)
							dest_l[#dest_l + 1] = copy_pt(tip_l, false)
							built.segment_count = built.segment_count + 1
						end
						if use_cap then
							pack.caps = pack.caps or {}
							pack.caps[#dest_u] = use_cap
						end
						dest_u[#dest_u + 1] = { break_chain = true }
						dest_l[#dest_l + 1] = { break_chain = true }
					end
					local split = frame.front_index or #upper
					if heat_runs then
						local rear_outer = nil
						for r = 1, #heat_runs do
							local run = heat_runs[r]
							local fine = upper[run.b] and (upper[run.b].dist_to_tip or 9999) < (frame.head_length or 0)
							local rear = nil
							local prefix_caught = run.a == 1
							if r == 1 and run.a > 1 then
								prefix_caught = true
								for i = 1, run.a - 1 do
									if not upper[i] or not upper[i].caught then
										prefix_caught = false
										break
									end
								end
							end
							local geometric_rear = frame.rear_exposed and prefix_caught and upper[run.a] and not closed_run_is_compact(frame, upper, lower, run) and upper[run.a].heat_open ~= false
							if geometric_rear and upper[run.a] and lower[run.a] then
								local rear_face = 0
								if spec.key == "outer" then
									local up = upper[run.a]
									local lo = lower[run.a]
									local sx = (up.x or 0) - (lo.x or 0)
									local sy = (up.y or 0) - (lo.y or 0)
									rear_face = math.sqrt(sx * sx + sy * sy)
								end
								if spec.key == "outer" and run.a > 1 then
									built.dissipation_tail_caps = (built.dissipation_tail_caps or 0) + 1
								end
								if spec.key == "outer" and rear_face >= 2 then
									built.rear_cap_required = (built.rear_cap_required or 0) + 1
									frame.rear_envelope = solve_rear_envelope(
										upper[run.a], lower[run.a],
										upper[run.a + 1], upper[run.a + 2],
										chains, c, frame, built
									)
								end
								if frame.rear_envelope then
									rear = build_rear_cap(upper[run.a], lower[run.a], spec.key, frame.rear_envelope)
								end
								if rear and spec.key == "outer" then
									rear_outer = rear
									if frame.rear_envelope then
										frame.rear_envelope.outer_cap = rear
									end
									built.rear_cap_width = rear.width
									built.rear_cap_depth = rear.depth
									built.rear_profiles = built.rear_profiles or {}
									built.rear_profiles[#built.rear_profiles + 1] = {
										segment_id = frame.segment_id,
										piece_id = frame.piece_id,
										visual_class = frame.visual_class,
										arc = frame.piece_arc,
										width = rear.width,
										depth = rear.depth,
										halves = rear.halves,
										cross = rear.cross == true,
										tip_x = rear.tip_x,
										tip_y = rear.tip_y,
										mx = rear.mx,
										my = rear.my,
										rear_upper_join_error = rear.join_upper or 0,
										rear_lower_join_error = rear.join_lower or 0,
										rear_tangent_discontinuity = rear.tangent or 0,
										rear_polygon_crossing = rear.cross == true,
										rear_parent_containment_failures = rear.containment_failures or 0,
									}
								end
								if rear then
									local function take_max(key, value)
										local prev = built[key]
										if not prev or value > prev then
											built[key] = value
										end
									end
									take_max("rear_upper_join_error", rear.join_upper or 0)
									take_max("rear_lower_join_error", rear.join_lower or 0)
									take_max("rear_tangent_discontinuity", rear.tangent or 0)
									if rear.cross then
										built.rear_polygon_crossing = (built.rear_polygon_crossing or 0) + 1
									end
									built.rear_parent_containment_failures = (built.rear_parent_containment_failures or 0) + (rear.containment_failures or 0)
								end
							elseif frame.rear_exposed and run.a > 1 and spec.key == "outer" then
								built.temperature_gap_starts = (built.temperature_gap_starts or 0) + 1
							end
							if rear then
								built.rear_layers = built.rear_layers or {}
								built.rear_layers[#built.rear_layers + 1] = {
									segment_id = frame.segment_id,
									piece_id = frame.piece_id,
									layer = spec.key,
									depth = rear.depth,
									width = rear.width,
									rear_upper_join_error = rear.join_upper or 0,
									rear_lower_join_error = rear.join_lower or 0,
									rear_tangent_discontinuity = rear.tangent or 0,
									rear_polygon_crossing = rear.cross == true,
									rear_parent_containment_failures = rear.containment_failures or 0,
								}
							end
							emit(run.a, run.b, fine, run_caps[r], run.tip_u, run.tip_l, rear)
						end
						if rear_outer and spec.key == "outer" and built.edge_samples then
							local samples = built.edge_samples
							local ix = rear_outer.mx or 0
							local iy = rear_outer.my or 0
							local function push_rear(a, b)
								if not a or not b or not a.x or not b.x then
									return
								end
								local sx = b.x - a.x
								local sy = b.y - a.y
								local len = math.sqrt(sx * sx + sy * sy)
								if len < 0.35 then
									return
								end
								local tx = sx / len
								local ty = sy / len
								local nx = -ty
								local ny = tx
								local mx = (a.x + b.x) * 0.5
								local my = (a.y + b.y) * 0.5
								local dx = mx - ix
								local dy = my - iy
								if nx * dx + ny * dy < 0 then
									nx, ny = -nx, -ny
								end
								local sample = {
									x = mx, y = my, nx = nx, ny = ny, tx = tx, ty = ty,
									length = len,
									vx = ((a.vx or 0) + (b.vx or 0)) * 0.5,
									vy = ((a.vy or 0) + (b.vy or 0)) * 0.5,
									along = 0,
									front = false,
									temperature = ((a.temperature or 0.5) + (b.temperature or 0.5)) * 0.5,
									side = "rear",
									id = a.id or b.id,
									id_b = b.id,
									segment_id = a.segment_id or b.segment_id,
									ax = a.x, ay = a.y, bx = b.x, by = b.y,
									half = math.sqrt(dx * dx + dy * dy),
									travel = ((a.s or 0) + (b.s or 0)) * 0.5,
								}
								samples[#samples + 1] = sample
								local id = sample.id
								if id then
									local slot = built.edge_by_id[id]
									if not slot then
										slot = { upper = {}, lower = {}, front = {}, rear = {} }
										built.edge_by_id[id] = slot
									end
									slot.rear = slot.rear or {}
									slot.rear[#slot.rear + 1] = sample
								end
							end
							local function walk_rear(points)
								for i = 1, #points - 1 do
									push_rear(points[i], points[i + 1])
								end
							end
							walk_rear(rear_outer.upper)
							walk_rear(rear_outer.lower)
						end
					elseif cfg.static_solid or split <= 1 or split >= #upper then
						emit(1, #upper, not cfg.static_solid, cap)
					else
						emit(1, split, false, nil)
						emit(split, #upper, true, cap)
					end
				end
				end
			end
		end
	end
	for li = 1, #LAYERS do
		local spec = LAYERS[li]
		local pack = merged[spec.key]
		if #pack.upper >= 2 then
			built[spec.key] = {
				key = spec.key,
				upper = pack.upper,
				lower = pack.lower,
				caps = pack.caps,
				r = spec.r,
				g = spec.g,
				b = spec.b,
			}
		end
	end
	local samples = built.edge_samples or {}
	local total = 0
	local length_sum = 0
	local function position_w(along)
		if along < 0.2 then
			return 0.15
		end
		if along < 0.6 then
			return 0.75
		end
		if along < 0.85 then
			return 1.2
		end
		return 1.7
	end
	for i = 1, #samples do
		local sample = samples[i]
		local w = (sample.length or 0) * position_w(sample.along or 0)
		w = w * (1 + math.min(sample.curvature or 0, 1.2) * 0.65)
		if sample.front then
			w = w * (cfg.front_scatter or 1.4)
		end
		if (sample.bulge or 0) > 8 then
			w = w * (cfg.edge_scatter or 1.6)
		end
		if w < 0 then
			w = 0
		end
		sample.weight = w
		total = total + w
		sample.cumulative = total
		length_sum = length_sum + (sample.length or 0)
	end
	built.edge_weight_total = total
	built.edge_length = length_sum
	built.band_frac = {}
	local bins = { "mouth", "mid", "far" }
	local band_keys = { "orange", "gold", "white" }
	for b = 1, #bins do
		local rec = built.bands and built.bands[bins[b]] or {}
		for k = 1, #band_keys do
			local key = band_keys[k]
			local n = rec[key .. "_n"] or 0
			local avg = 0
			if n > 0 then
				avg = (rec[key] or 0) / n
			end
			built.band_frac[bins[b] .. "_" .. key] = avg
		end
	end
	return built
end

local function point_in_poly(x, y, poly)
	local inside = false
	local j = #poly
	for i = 1, #poly do
		local a = poly[i]
		local b = poly[j]
		local ay = a.y or 0
		local by = b.y or 0
		if (ay > y) ~= (by > y) then
			local ax = a.x or 0
			local bx = b.x or 0
			local denom = by - ay
			if denom == 0 then
				denom = 0.0000001
			end
			if x < (bx - ax) * (y - ay) / denom + ax then
				inside = not inside
			end
		end
		j = i
	end
	return inside
end

local function dist_to_segment(px, py, ax, ay, bx, by)
	local dx = bx - ax
	local dy = by - ay
	local len2 = dx * dx + dy * dy
	local t = 0
	if len2 > 0.0000001 then
		t = ((px - ax) * dx + (py - ay) * dy) / len2
		if t < 0 then
			t = 0
		elseif t > 1 then
			t = 1
		end
	end
	local ex = px - (ax + dx * t)
	local ey = py - (ay + dy * t)
	return math.sqrt(ex * ex + ey * ey)
end

local function circle_hits(poly, x, y, radius)
	if #poly < 3 then
		return false
	end
	if point_in_poly(x, y, poly) then
		return true
	end
	if radius <= 0 then
		return false
	end
	for i = 1, #poly do
		local a = poly[i]
		local b = poly[i % #poly + 1]
		if dist_to_segment(x, y, a.x or 0, a.y or 0, b.x or 0, b.y or 0) <= radius then
			return true
		end
	end
	return false
end

function regions.overlaps_circle(built, x, y, radius)
	local outer = built and built.outer
	if not outer or not outer.upper or not outer.lower then
		return false
	end
	local upper = outer.upper
	local lower = outer.lower
	local n = #upper
	if #lower < n then
		n = #lower
	end
	radius = radius or 0
	if radius < 0 then
		radius = 0
	end
	local a = 1
	local i = 1
	while i <= n do
		local up = upper[i]
		local lo = lower[i]
		if (up and up.break_chain) or (lo and lo.break_chain) then
			if i > a and regions.span_hits(upper, lower, a, i - 1, x, y, radius) then
				return true
			end
			a = i + 1
		end
		i = i + 1
	end
	if n >= a and regions.span_hits(upper, lower, a, n, x, y, radius) then
		return true
	end
	return false
end

function regions.span_hits(upper, lower, a, b, x, y, radius)
	if b - a < 1 then
		return false
	end
	local poly = {}
	for k = a, b do
		local p = upper[k]
		if p and not p.break_chain then
			poly[#poly + 1] = p
		end
	end
	for k = b, a, -1 do
		local p = lower[k]
		if p and not p.break_chain then
			poly[#poly + 1] = p
		end
	end
	return circle_hits(poly, x, y, radius)
end

return regions
