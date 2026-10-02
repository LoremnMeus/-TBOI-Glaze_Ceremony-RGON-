-- Canonical Sprite/Image splice geometry (pure texture math).
-- Does not know Entity / Player / WorldToScreen / Suture Needle profiles.
-- Consumers: sprite_splice façade, Runtime Stitch adapter, UI Preview, probes.

local charm_filter = require("Qing_Remaster_scripts.auxiliary.runtime_stitch_charm_filter")

local M = {
	MIN_SCALE = 0.50,
	MAX_SCALE = 1.55,
	FRAME_WEIGHT = 0.65,
	REF_WEIGHT = 0.35,
	MIN_VALID_INTERFACE_SPAN = 2,
	MIN_INTERFACE_SAMPLES = 3,
	DEFAULT_SIZE = 128,
}

local CUT_CANDIDATE_RATIOS = { 0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.65 }
M.CUT_CANDIDATE_RATIOS = CUT_CANDIDATE_RATIOS

-- ---------------------------------------------------------------------------
-- Texel / alpha / cut interface (migrated from Gate3D runtime_stitch_renderer)
-- ---------------------------------------------------------------------------

local function read_texel_blob(image, size)
	if not image or not image.GetTexelRegion then
		return nil, "GetTexelRegion unavailable"
	end
	local ok, data = pcall(function()
		return image:GetTexelRegion(0, 0, size, size)
	end)
	if not ok or type(data) ~= "string" then
		return nil, "GetTexelRegion failed: " .. tostring(data)
	end
	local pixels = size * size
	local bytes = #data
	local fmt, bpp
	if bytes >= pixels * 16 then
		fmt, bpp = "f32", 16
	elseif bytes >= pixels * 4 then
		fmt, bpp = "u8", 4
	else
		return nil, string.format("short texel bytes=%d need>=%d", bytes, pixels * 4)
	end
	local row = size
	local padded = size
	if image.GetPaddedWidth then
		local pw = tonumber(image:GetPaddedWidth()) or size
		if pw > size and bytes >= pw * size * bpp then
			padded = pw
			row = pw
		end
	end
	return {
		data = data,
		bytes = bytes,
		fmt = fmt,
		bpp = bpp,
		size = size,
		row = row,
		padded = padded,
	}, nil
end

local PERF = {
	get_texel_region = 0,
	centerline_scans = 0,
	decoded_texels = 0,
	charm_rgb_tests = 0,
	full_alpha_scans = 0,
	interface_scans = 0,
}

function M.get_perf_counters()
	return {
		get_texel_region = PERF.get_texel_region,
		centerline_scans = PERF.centerline_scans,
		decoded_texels = PERF.decoded_texels,
		charm_rgb_tests = PERF.charm_rgb_tests,
		full_alpha_scans = PERF.full_alpha_scans,
		interface_scans = PERF.interface_scans,
	}
end

function M.reset_perf_counters()
	PERF.get_texel_region = 0
	PERF.centerline_scans = 0
	PERF.decoded_texels = 0
	PERF.charm_rgb_tests = 0
	PERF.full_alpha_scans = 0
	PERF.interface_scans = 0
end

--- One decode: RGB 0–255, alpha 0–1. Counts as one decoded texel.
local function texel_rgba_at(blob, x, y)
	PERF.decoded_texels = PERF.decoded_texels + 1
	local row = blob.row or blob.size
	local idx = y * row + x
	if blob.fmt == "f32" then
		local off = idx * 16 + 1
		if off + 15 > #blob.data then
			return 0, 0, 0, 0
		end
		local r = string.unpack("<f", blob.data, off) or 0
		local g = string.unpack("<f", blob.data, off + 4) or 0
		local b = string.unpack("<f", blob.data, off + 8) or 0
		local a = string.unpack("<f", blob.data, off + 12) or 0
		return math.floor(r * 255 + 0.5),
			math.floor(g * 255 + 0.5),
			math.floor(b * 255 + 0.5),
			a
	end
	local off = idx * 4 + 1
	local r = string.byte(blob.data, off) or 0
	local g = string.byte(blob.data, off + 1) or 0
	local b = string.byte(blob.data, off + 2) or 0
	local a = (string.byte(blob.data, off + 3) or 0) / 255
	return r, g, b, a
end

local function texel_alpha_at(blob, x, y)
	local row = blob.row or blob.size
	local idx = y * row + x
	if blob.fmt == "f32" then
		local off = idx * 16 + 1
		if off + 15 > #blob.data then return 0 end
		local a = string.unpack("<f", blob.data, off + 12)
		return a or 0
	end
	local off = idx * 4 + 4
	return (string.byte(blob.data, off) or 0) / 255
end

local function is_soft_shadow_rgba(r, g, b, a)
	if not a or a < 0.05 or a >= 0.55 then
		return false
	end
	return ((r + g + b) / (3 * 255)) < 0.18
end

local function is_soft_shadow_texel(blob, x, y, a)
	if not a or a < 0.05 or a >= 0.55 then
		return false
	end
	local r, g, b = texel_rgba_at(blob, x, y)
	return ((r + g + b) / (3 * 255)) < 0.18
end

--- Alpha-only bbox / centroid (registration). No charm dual-pass.
local function analyze_image_alpha_blob(blob, size, step)
	step = math.max(1, tonumber(step) or 2)
	if not blob then return nil, "no blob" end
	PERF.full_alpha_scans = PERF.full_alpha_scans + 1
	local minx, miny, maxx, maxy = size, size, -1, -1
	local nonzero = 0
	local sum_ax, sum_ay, sum_a = 0, 0, 0
	for y = 0, size - 1, step do
		for x = 0, size - 1, step do
			local a = texel_alpha_at(blob, x, y)
			if a > 0.18 and not is_soft_shadow_texel(blob, x, y, a) then
				nonzero = nonzero + 1
				if x < minx then minx = x end
				if y < miny then miny = y end
				if x > maxx then maxx = x end
				if y > maxy then maxy = y end
				sum_ax = sum_ax + x * a
				sum_ay = sum_ay + y * a
				sum_a = sum_a + a
			end
		end
	end
	local bbox = (maxx >= 0) and { minx = minx, miny = miny, maxx = maxx, maxy = maxy } or nil
	local half = size * 0.5
	local bbox_center_px = nil
	local bbox_center_local = nil
	if bbox then
		local bcx = (bbox.minx + bbox.maxx + 1) * 0.5
		local bcy = (bbox.miny + bbox.maxy + 1) * 0.5
		bbox_center_px = { bcx, bcy }
		bbox_center_local = { bcx - half, bcy - half }
	end
	local centroid_px = nil
	local centroid_local = nil
	local centroid_source = nil
	if sum_a > 1e-6 then
		local cpx = sum_ax / sum_a
		local cpy = sum_ay / sum_a
		centroid_px = { cpx, cpy }
		centroid_local = { cpx - half, cpy - half }
		centroid_source = "alpha_weighted"
	elseif bbox_center_local then
		centroid_px = bbox_center_px
		centroid_local = bbox_center_local
		centroid_source = "bbox"
	end
	return {
		size = size,
		step = step,
		nonzero_samples = nonzero,
		fmt = blob.fmt,
		bytes = blob.bytes,
		bbox = bbox,
		bbox_center_px = bbox_center_px,
		bbox_center_local = bbox_center_local,
		centroid_px = centroid_px,
		centroid_local = centroid_local,
		centroid_source = centroid_source,
		_blob = blob,
	}, nil
end

--- Public: registration silhouette. Alpha-only.
--- Charm hearts are NOT removed here (they may still inflate bbox).
--- Scale/seam charm filtering is centerline SEARCH_BODY + exact palette — see measure_centerline.
function M.analyze_image_alpha(image, size, step, opts)
	opts = opts or {}
	size = tonumber(size) or M.DEFAULT_SIZE
	local blob, berr = read_texel_blob(image, size)
	if not blob then
		return nil, berr
	end
	PERF.get_texel_region = PERF.get_texel_region + 1
	return analyze_image_alpha_blob(blob, size, step)
end

local GAP_BRIDGE_PX = 1
local ALPHA_MIN_CENTERLINE = 0.18
local MIN_CENTERLINE_SAMPLES = 3

local function extract_1d_segments(valid, size, gap_bridge)
	gap_bridge = tonumber(gap_bridge) or GAP_BRIDGE_PX
	local segments = {}
	local i = 0
	while i < size do
		while i < size and not valid[i] do
			i = i + 1
		end
		if i >= size then
			break
		end
		local st = i
		local ed = i
		local gap = 0
		i = i + 1
		while i < size do
			if valid[i] then
				ed = i
				gap = 0
				i = i + 1
			elseif gap < gap_bridge then
				gap = gap + 1
				i = i + 1
			else
				break
			end
		end
		local count = 0
		for y = st, ed do
			if valid[y] then
				count = count + 1
			end
		end
		segments[#segments + 1] = {
			st = st,
			ed = ed,
			-- Geometric extent along the centerline (matches prior interface t_max-t_min).
			span = ed - st,
			-- Valid body texel count (confidence / MIN_CENTERLINE_SAMPLES).
			count = count,
			mid = (st + ed) * 0.5,
		}
	end
	return segments
end

local function select_primary_segment(segments, pivot)
	if not segments or #segments == 0 then
		return nil
	end
	pivot = tonumber(pivot) or 0
	local best = nil
	local best_score = -1e18
	for i = 1, #segments do
		local s = segments[i]
		local contains = (pivot >= s.st and pivot <= s.ed)
		local dist = 0
		if pivot < s.st then
			dist = s.st - pivot
		elseif pivot > s.ed then
			dist = pivot - s.ed
		end
		-- Prefer containing pivot, then nearer, then longer.
		local score = (contains and 1e9 or 0) - dist * 1000 + (s.span or 0)
		if score > best_score then
			best_score = score
			best = s
		end
	end
	return best
end

--- Production scale/seam geometry: narrow centerline only (+ optional ±cols).
--- Charm: exact statuseffects palette only, and only while SEARCH_BODY
--- (before the first non-charm opaque body texel). No head-zone / bbox gate.
function M.measure_centerline(blob, size, opts)
	opts = opts or {}
	size = tonumber(size) or M.DEFAULT_SIZE
	if not blob then
		return nil, "no blob"
	end
	PERF.centerline_scans = PERF.centerline_scans + 1
	local want_charm = opts.charm_filter ~= false and charm_filter.is_enabled()
	local nx = (opts.cut_normal and (opts.cut_normal[1] or opts.cut_normal.x)) or 1
	local ny = (opts.cut_normal and (opts.cut_normal[2] or opts.cut_normal.y)) or 0
	local nlen = math.sqrt(nx * nx + ny * ny)
	if nlen < 1e-6 then
		nx, ny = 1, 0
	else
		nx, ny = nx / nlen, ny / nlen
	end
	local scan_along_y = math.abs(nx) >= math.abs(ny)
	local center = math.floor(size * 0.5)
	local max_half = math.max(0, tonumber(opts.max_half_width) or 2)
	local offsets = { 0 }
	for d = 1, max_half do
		offsets[#offsets + 1] = -d
		offsets[#offsets + 1] = d
	end

	local best = nil
	local sampled_columns = {}
	local charm_skipped_total = 0
	local decoded = 0

	for oi = 1, #offsets do
		local off = offsets[oi]
		local col = center + off
		if col >= 0 and col < size then
			sampled_columns[#sampled_columns + 1] = col
			local valid = {}
			local charm_skipped = 0
			local solid = 0
			local body_started = false
			local body_start_y = nil
			for t = 0, size - 1 do
				local x, y
				if scan_along_y then
					x, y = col, t
				else
					x, y = t, col
				end
				local r, g, b, a = texel_rgba_at(blob, x, y)
				decoded = decoded + 1
				-- a is 0–1; RGB already 0–255 from texel_rgba_at
				if a > ALPHA_MIN_CENTERLINE then
					if is_soft_shadow_rgba(r, g, b, a) then
						-- soft shadow: skip (never body, never charm)
					elseif want_charm and not body_started then
						PERF.charm_rgb_tests = PERF.charm_rgb_tests + 1
						local a255 = math.floor(a * 255 + 0.5)
						if charm_filter.is_candidate(r, g, b, a255) then
							charm_skipped = charm_skipped + 1
						else
							body_started = true
							body_start_y = t
							valid[t] = true
							solid = solid + 1
						end
					else
						-- BODY_STARTED (or charm filter off): never test charm again
						body_started = true
						if body_start_y == nil then
							body_start_y = t
						end
						valid[t] = true
						solid = solid + 1
					end
				end
			end
			charm_skipped_total = charm_skipped_total + charm_skipped
			local segments = extract_1d_segments(valid, size, GAP_BRIDGE_PX)
			local primary = select_primary_segment(segments, center)
			local entry = {
				column = col,
				offset = off,
				solid = solid,
				segments = segments,
				primary = primary,
				charm_skipped = charm_skipped,
				body_start_y = body_start_y,
				body_started = body_started,
			}
			if primary and solid >= MIN_CENTERLINE_SAMPLES then
				best = entry
				break
			end
			if not best or solid > (best.solid or 0) then
				best = entry
			end
		end
	end

	local base = {
		size = size,
		scan_along_y = scan_along_y,
		sampled_columns = sampled_columns,
		charm_pixels_skipped = charm_skipped_total,
		charm_skipped = charm_skipped_total,
		decoded_texels = decoded,
		charm_matcher = "exact_statuseffects_charm",
		charm_palette_hex = { "#FF7373", "#FF4B4B" },
	}

	if not best or not best.primary then
		base.ok = false
		base.chosen_column = best and best.column or nil
		base.body_start_y = best and best.body_start_y or nil
		base.st = nil
		base.ed = nil
		base.mid = nil
		base.span = 0
		base.count = 0
		base.segments = best and best.segments or {}
		base.selected_segment = nil
		return base, nil
	end

	local seg = best.primary
	base.ok = true
	base.chosen_column = best.column
	base.column_offset = best.offset
	base.body_start_y = best.body_start_y
	base.st = seg.st
	base.ed = seg.ed
	base.mid = seg.mid
	base.span = seg.span
	base.count = seg.count
	base.segments = best.segments
	base.selected_segment = seg
	base.centerline_span = seg.span
	base.centerline_st = seg.st
	base.centerline_ed = seg.ed
	base.centerline_mid = seg.mid
	return base, nil
end

--- Progressive centerline: try max_half_width 2 → 8 → 24 (or opts.half_widths).
--- Stops at first ok result with a primary segment.
function M.measure_centerline_progressive(blob, size, opts)
	opts = opts or {}
	local halves = opts.half_widths
	if type(halves) ~= "table" or #halves == 0 then
		halves = { 2, 8, 24 }
	end
	local last = nil
	local last_err = nil
	for i = 1, #halves do
		local try_opts = {}
		for k, v in pairs(opts) do
			try_opts[k] = v
		end
		try_opts.max_half_width = tonumber(halves[i]) or halves[i]
		try_opts.half_widths = nil
		local cl, err = M.measure_centerline(blob, size, try_opts)
		last, last_err = cl, err
		if cl and cl.ok then
			cl.progressive_half_width = try_opts.max_half_width
			cl.progressive_attempt = i
			return cl, nil
		end
	end
	if last then
		last.progressive_failed = true
		return last, last_err
	end
	return nil, last_err or "progressive centerline failed"
end

--- Read texel blob then progressive (or single) centerline measure.
function M.measure_centerline_from_image(image, size, opts)
	opts = opts or {}
	local blob, berr = read_texel_blob(image, size)
	if not blob then
		return nil, berr
	end
	PERF.get_texel_region = PERF.get_texel_region + 1
	if opts.progressive == true or opts.half_widths ~= nil then
		return M.measure_centerline_progressive(blob, size, opts)
	end
	return M.measure_centerline(blob, size, opts)
end

--- Project measured cut onto the COMPOSITE fixed-seam plane:
---   normal = seam_normal_anchor, tangent = measured tangent component.
--- Used when source RT is already registered so seam≈anchor in RT-local space.
--- Interface-first raw RT must NOT call this to zero out source cut_local —
--- preserve measured source interface; composite seam stays at normal=0 via cut_origin.
function M.stabilize_cut_local(measured_cut_local, cut_normal, seam_normal_anchor)
	local mx = 0
	local my = 0
	if type(measured_cut_local) == "table" then
		mx = tonumber(measured_cut_local[1] or measured_cut_local.x) or 0
		my = tonumber(measured_cut_local[2] or measured_cut_local.y) or 0
	end
	local nx = 1
	local ny = 0
	if cut_normal then
		nx = tonumber(cut_normal[1] or cut_normal.x) or 1
		ny = tonumber(cut_normal[2] or cut_normal.y) or 0
	end
	local nlen = math.sqrt(nx * nx + ny * ny)
	if nlen < 1e-6 then
		nx, ny = 1, 0
	else
		nx, ny = nx / nlen, ny / nlen
	end
	local tx, ty = -ny, nx
	local anchor = tonumber(seam_normal_anchor) or 0
	local tcomp = mx * tx + my * ty
	return {
		nx * anchor + tx * tcomp,
		ny * anchor + ty * tcomp,
	}, tcomp
end

function M.resolve_content_cut_origin(bbox, size)
	if not bbox or not size or size <= 0 then
		return { 0.5, 0.5 }
	end
	return {
		(bbox.minx + bbox.maxx + 1) * 0.5 / size,
		(bbox.miny + bbox.maxy + 1) * 0.5 / size,
	}
end

--- Clamp band width from ~10% of the short bbox edge into [2, 6] px.
function M.compute_band_px(bbox)
	if type(bbox) ~= "table" then
		return 3
	end
	local w = (tonumber(bbox.maxx) or 0) - (tonumber(bbox.minx) or 0) + 1
	local h = (tonumber(bbox.maxy) or 0) - (tonumber(bbox.miny) or 0) + 1
	if w < 1 then w = 1 end
	if h < 1 then h = 1 end
	local short = math.min(w, h)
	local band = math.floor(short * 0.1 + 0.5)
	if band < 2 then band = 2 end
	if band > 6 then band = 6 end
	return band
end

--- Prefer measured interface span; fall back to keep span.
--- returns span, source ("interface"|"keep_fallback"|"none")
function M.choose_interface_span(iface)
	if type(iface) ~= "table" then
		return 0, "none"
	end
	local iface_span = tonumber(iface.interface_span_px) or 0
	local keep_span = tonumber(iface.keep_span_px) or 0
	local count = tonumber(iface.count) or 0
	if iface_span >= M.MIN_VALID_INTERFACE_SPAN and count >= M.MIN_INTERFACE_SAMPLES then
		return iface_span, "interface"
	end
	if keep_span >= M.MIN_VALID_INTERFACE_SPAN then
		return keep_span, "keep_fallback"
	end
	if keep_span > 0 then
		return keep_span, "keep_fallback"
	end
	if iface_span > 0 then
		return iface_span, "interface"
	end
	return 0, "none"
end

local function cut_origin_at_ratio(bbox, size, cut_normal, ratio)
	ratio = tonumber(ratio) or 0.5
	local nx = (cut_normal and cut_normal[1]) or 1
	local ny = (cut_normal and cut_normal[2]) or 0
	local minx = tonumber(bbox.minx) or 0
	local maxx = tonumber(bbox.maxx) or (size - 1)
	local miny = tonumber(bbox.miny) or 0
	local maxy = tonumber(bbox.maxy) or (size - 1)
	local cx = (minx + maxx + 1) * 0.5 / size
	local cy = (miny + maxy + 1) * 0.5 / size
	if math.abs(nx) >= math.abs(ny) then
		local px = minx + (maxx - minx) * ratio
		return { (px + 0.5) / size, cy }
	end
	local py = miny + (maxy - miny) * ratio
	return { cx, (py + 0.5) / size }
end

local function score_cut_candidate(iface, ratio)
	local span, source = M.choose_interface_span(iface)
	local count = tonumber(iface and iface.count) or 0
	local keep_count = tonumber(iface and iface.keep_count) or 0
	local dist = math.abs((tonumber(ratio) or 0.5) - 0.5)
	local sparse = count < M.MIN_INTERFACE_SAMPLES
	local score = 0
	if source == "interface" then
		score = score + span * 10 + count
	elseif source == "keep_fallback" then
		score = score + span * 2 + keep_count * 0.05
	else
		score = score - 100
	end
	score = score - dist * 40
	if sparse then
		score = score - 25
	end
	return score, span, source
end

local function analyze_cut_interface(image, size, cut_origin, cut_normal, keep_sign, step, opt_blob, clip_bbox, band_px, charm_ctx)
	PERF.interface_scans = PERF.interface_scans + 1
	step = math.max(1, tonumber(step) or 2)
	local blob = opt_blob
	if not blob then
		local berr
		blob, berr = read_texel_blob(image, size)
		if not blob then return nil, berr end
	end
	local ALPHA_MIN = 0.18
	local ox = (cut_origin and cut_origin[1]) or 0.5
	local oy = (cut_origin and cut_origin[2]) or 0.5
	local nx = (cut_normal and cut_normal[1]) or 1
	local ny = (cut_normal and cut_normal[2]) or 0
	local nlen = math.sqrt(nx * nx + ny * ny)
	if nlen < 1e-6 then
		nx, ny = 1, 0
	else
		nx, ny = nx / nlen, ny / nlen
	end
	local sign = keep_sign or -1
	if math.abs(sign) < 1e-6 then sign = -1 end
	local tx, ty = -ny, nx
	band_px = tonumber(band_px)
	if not band_px or band_px < 1 then
		band_px = M.compute_band_px(clip_bbox)
	end
	local band = band_px / size

	local sumx, sumy, count = 0, 0, 0
	local t_min, t_max = nil, nil
	local keep_t_min, keep_t_max = nil, nil
	local keep_sumx, keep_sumy, keep_count = 0, 0, 0
	local minx, miny, maxx, maxy = size, size, -1, -1
	local nonzero = 0

	local x0, y0, x1, y1 = 0, 0, size - 1, size - 1
	if clip_bbox then
		x0 = math.max(0, tonumber(clip_bbox.minx) or 0)
		y0 = math.max(0, tonumber(clip_bbox.miny) or 0)
		x1 = math.min(size - 1, tonumber(clip_bbox.maxx) or (size - 1))
		y1 = math.min(size - 1, tonumber(clip_bbox.maxy) or (size - 1))
	end
	do
		local cx = ((cut_origin and cut_origin[1]) or 0.5) * size
		local cy = ((cut_origin and cut_origin[2]) or 0.5) * size
		local nnx = (cut_normal and cut_normal[1]) or 1
		local nny = (cut_normal and cut_normal[2]) or 0
		if math.abs(nnx) >= math.abs(nny) then
			x0 = math.max(x0, math.floor(cx - band_px))
			x1 = math.min(x1, math.ceil(cx + band_px))
		else
			y0 = math.max(y0, math.floor(cy - band_px))
			y1 = math.min(y1, math.ceil(cy + band_px))
		end
		if x1 < x0 or y1 < y0 then
			x0, y0, x1, y1 = 0, 0, size - 1, size - 1
		end
	end
	for y = y0, y1, step do
		for x = x0, x1, step do
			local a = texel_alpha_at(blob, x, y)
			if a > ALPHA_MIN and not is_soft_shadow_texel(blob, x, y, a) then
				nonzero = nonzero + 1
				if x < minx then minx = x end
				if y < miny then miny = y end
				if x > maxx then maxx = x end
				if y > maxy then maxy = y end
				local u = (x + 0.5) / size
				local v = (y + 0.5) / size
				local side = (u - ox) * nx + (v - oy) * ny
				local prod = side * sign
				if prod <= 0 then
					keep_count = keep_count + 1
					keep_sumx = keep_sumx + x
					keep_sumy = keep_sumy + y
					local tproj = (u - ox) * tx + (v - oy) * ty
					if keep_t_min == nil or tproj < keep_t_min then keep_t_min = tproj end
					if keep_t_max == nil or tproj > keep_t_max then keep_t_max = tproj end
					if math.abs(side) <= band then
						sumx = sumx + x
						sumy = sumy + y
						count = count + 1
						if t_min == nil or tproj < t_min then t_min = tproj end
						if t_max == nil or tproj > t_max then t_max = tproj end
					end
				end
			end
		end
	end

	local bbox = (maxx >= 0) and { minx = minx, miny = miny, maxx = maxx, maxy = maxy } or nil
	if keep_count < 1 then
		return {
			bbox = bbox,
			nonzero_samples = nonzero,
			count = 0,
			keep_count = 0,
			interface_span_px = 0,
			keep_span_px = 0,
			edge_centroid_from_center = { 0, 0 },
			keep_centroid_from_center = { 0, 0 },
			t_min = nil,
			t_max = nil,
			range_mid_t = nil,
			centroid_t = nil,
			centroid_minus_range_mid = nil,
			sample_step = step,
			mode = "empty",
			band_px = band_px,
			fmt = blob.fmt,
			bytes = blob.bytes,
		}, nil
	end

	local band_span = 0
	if t_min ~= nil and t_max ~= nil then
		band_span = (t_max - t_min) * size
	end
	local keep_span = 0
	if keep_t_min ~= nil and keep_t_max ~= nil then
		keep_span = (keep_t_max - keep_t_min) * size
	end
	if keep_span < M.MIN_VALID_INTERFACE_SPAN and bbox then
		local bw = bbox.maxx - bbox.minx + 1
		local bh = bbox.maxy - bbox.miny + 1
		keep_span = math.abs(ty) >= math.abs(tx) and bh or bw
	end

	local half = size * 0.5
	local kcx = keep_sumx / keep_count
	local kcy = keep_sumy / keep_count
	local mode = "keep"
	local ecx, ecy = kcx, kcy
	if count >= M.MIN_INTERFACE_SAMPLES then
		mode = "band"
		ecx = sumx / count
		ecy = sumy / count
	end
	-- Tangent diagnostics (UV units along cut tangent from cut_origin).
	local range_mid_t = nil
	if t_min ~= nil and t_max ~= nil then
		range_mid_t = (t_min + t_max) * 0.5
	end
	local centroid_t = ((ecx + 0.5) / size - ox) * tx + ((ecy + 0.5) / size - oy) * ty
	local centroid_minus_range_mid = nil
	if range_mid_t ~= nil then
		centroid_minus_range_mid = centroid_t - range_mid_t
	end
	return {
		bbox = bbox,
		nonzero_samples = nonzero,
		count = count,
		keep_count = keep_count,
		interface_span_px = band_span,
		keep_span_px = keep_span,
		edge_centroid_from_center = { ecx - half, ecy - half },
		keep_centroid_from_center = { kcx - half, kcy - half },
		centroid_local = { ecx - half, ecy - half },
		t_min = t_min,
		t_max = t_max,
		range_mid_t = range_mid_t,
		centroid_t = centroid_t,
		centroid_minus_range_mid = centroid_minus_range_mid,
		t_min_px = t_min and (t_min * size) or nil,
		t_max_px = t_max and (t_max * size) or nil,
		range_mid_t_px = range_mid_t and (range_mid_t * size) or nil,
		centroid_t_px = centroid_t * size,
		sample_step = step,
		mode = mode,
		band_px = band_px,
		fmt = blob.fmt,
		bytes = blob.bytes,
	}, nil
end

--- Search cut origin along bbox normal axis for the best interface measurement.
--- Returns best + full candidate table for probes:
---   candidates[{ratio,score,span,count,keep_span,keep_count,source,cut_origin}]
---   previous_ratio / score_margin when opts.previous_ratio is set
function M.find_best_cut(blob, size, bbox, cut_normal, keep_sign, opts)
	opts = opts or {}
	if not blob or not bbox or not size or size <= 0 then
		return nil, "blob/bbox/size required"
	end
	local step = math.max(1, tonumber(opts.step) or tonumber(opts.sample_step) or 2)
	local band_px = tonumber(opts.band_px) or M.compute_band_px(bbox)
	local ratios = opts.ratios or CUT_CANDIDATE_RATIOS
	local charm_ctx = opts.charm_ctx
	local candidates = {}
	local best = nil
	local second = nil
	for i = 1, #ratios do
		local ratio = ratios[i]
		local origin = cut_origin_at_ratio(bbox, size, cut_normal, ratio)
		local iface = analyze_cut_interface(
			nil, size, origin, cut_normal, keep_sign, step, blob, bbox, band_px, charm_ctx
		)
		if iface then
			local score, span, source = score_cut_candidate(iface, ratio)
			local entry = {
				ratio = ratio,
				score = score,
				span = span,
				count = tonumber(iface.count) or 0,
				keep_span = tonumber(iface.keep_span_px) or 0,
				keep_count = tonumber(iface.keep_count) or 0,
				source = source,
				cut_origin = { origin[1], origin[2] },
			}
			candidates[#candidates + 1] = entry
			if not best or score > best.score then
				second = best
				best = {
					cut_origin = origin,
					interface = iface,
					score = score,
					candidate_ratio = ratio,
					band_px = band_px,
					span = span,
					source = source,
				}
			elseif not second or score > second.score then
				second = {
					score = score,
					candidate_ratio = ratio,
				}
			end
		end
	end
	if not best then
		return nil, "no cut candidate"
	end
	best.candidates = candidates
	best.score_margin = second and (best.score - second.score) or nil
	best.runner_up_ratio = second and second.candidate_ratio or nil
	local prev = tonumber(opts.previous_ratio)
	best.previous_ratio = prev
	best.changed = (prev ~= nil) and (math.abs((best.candidate_ratio or 0) - prev) > 1e-6) or false
	return best
end

--- Evaluate a single locked ratio against current bbox (no winner search).
function M.analyze_locked_cut(blob, size, bbox, cut_normal, keep_sign, locked_ratio, opts)
	opts = opts or {}
	if not blob or not bbox or not size or size <= 0 then
		return nil, "blob/bbox/size required"
	end
	local ratio = tonumber(locked_ratio) or 0.5
	local step = math.max(1, tonumber(opts.step) or tonumber(opts.sample_step) or 2)
	local band_px = tonumber(opts.band_px) or M.compute_band_px(bbox)
	local origin = cut_origin_at_ratio(bbox, size, cut_normal, ratio)
	local iface = analyze_cut_interface(
		nil, size, origin, cut_normal, keep_sign, step, blob, bbox, band_px, opts.charm_ctx
	)
	if not iface then
		return nil, "locked cut interface failed"
	end
	local score, span, source = score_cut_candidate(iface, ratio)
	return {
		cut_origin = origin,
		interface = iface,
		score = score,
		candidate_ratio = ratio,
		band_px = band_px,
		span = span,
		source = source,
		locked = true,
	}
end

local function confidence_from_span_source(span_source)
	if span_source == "interface" then
		return 1
	end
	if span_source == "keep_fallback" then
		return 0.3
	end
	return 0
end

--- Analyze one baked Image source. Each source resolves its OWN content cut_origin.
--- opts:
---   cut_normal, keep_sign, cut_origin (seed)
---   lock_content_center (default true) — search best cut among candidates
---   locked_ratio — if set, skip winner search; reproject this ratio onto current bbox
---   collect_candidates (default false) — always fill cut_candidates for probes
---   previous_ratio — for changed/score_margin diagnostics
function M.analyze_source(image, size, opts)
	opts = opts or {}
	size = tonumber(size) or M.DEFAULT_SIZE
	local cut_normal = opts.cut_normal or { 1, 0 }
	local keep_sign = (opts.keep_sign ~= nil) and opts.keep_sign or -1
	local lock = opts.lock_content_center ~= false
	local locked_ratio = tonumber(opts.locked_ratio)
	local collect = opts.collect_candidates == true
	local sample_step = math.max(1, tonumber(opts.sample_step) or tonumber(opts.step) or 2)
	local fixed_seam = opts.fixed_seam_plane == true
	local seam_normal_anchor = tonumber(opts.seam_normal_anchor)
	if fixed_seam and seam_normal_anchor == nil then
		seam_normal_anchor = 0
	end

	local blob, berr = read_texel_blob(image, size)
	if not blob then
		return nil, berr
	end
	PERF.get_texel_region = PERF.get_texel_region + 1

	-- Production fixed seam: centerline-only scale/seam geometry (+ inline charm skip).
	-- No full-image charm sanitizer, no dual alpha passes, no raw interface diagnostic.
	if fixed_seam then
		local nx = cut_normal[1] or 1
		local ny = cut_normal[2] or 0
		local nlen = math.sqrt(nx * nx + ny * ny)
		if nlen < 1e-6 then
			nx, ny = 1, 0
		else
			nx, ny = nx / nlen, ny / nlen
		end
		local cut_origin
		local cut_local
		if type(opts.source_cut_origin) == "table" then
			-- Raw RT with measured interface: cut at source interface UV.
			-- cut_local = same point in RT-local pixels (origin at RT center).
			cut_origin = {
				tonumber(opts.source_cut_origin[1]) or tonumber(opts.source_cut_origin.x) or 0.5,
				tonumber(opts.source_cut_origin[2]) or tonumber(opts.source_cut_origin.y) or 0.5,
			}
			cut_local = {
				(cut_origin[1] - 0.5) * size,
				(cut_origin[2] - 0.5) * size,
			}
		else
			-- Registered RT: composite seam_normal_anchor maps near RT center.
			cut_local = {
				nx * seam_normal_anchor,
				ny * seam_normal_anchor,
			}
			cut_origin = {
				cut_local[1] / size + 0.5,
				cut_local[2] / size + 0.5,
			}
		end
		local cl = opts.precomputed_centerline
		local cerr = nil
		if not (cl and cl.ok) then
			cl, cerr = M.measure_centerline(blob, size, {
				cut_normal = { nx, ny },
				charm_filter = opts.charm_filter,
				max_half_width = tonumber(opts.centerline_half_width) or 2,
			})
		end
		if not cl then
			return nil, cerr or "centerline failed"
		end
		local span = tonumber(cl.span) or 0
		local st = cl.st
		local ed = cl.ed
		local mid = cl.mid
		local half = size * 0.5
		local t_min, t_max, range_mid_t = nil, nil, nil
		local centroid_local = { 0, 0 }
		if st ~= nil and ed ~= nil then
			-- Tangent coordinates are measured relative to the actual source cut origin
			-- (may be ≠0.5 when Interface-first keeps raw RT).
			local ox = cut_origin[1] or 0.5
			local oy = cut_origin[2] or 0.5
			local tx, ty = -ny, nx
			if cl.scan_along_y then
				-- tangent ≈ +Y; sample column x=chosen
				local u = ((cl.chosen_column or half) + 0.5) / size
				local v0 = (st + 0.5) / size
				local v1 = (ed + 0.5) / size
				t_min = (u - ox) * tx + (v0 - oy) * ty
				t_max = (u - ox) * tx + (v1 - oy) * ty
				if t_min > t_max then
					t_min, t_max = t_max, t_min
				end
				range_mid_t = (t_min + t_max) * 0.5
				centroid_local = {
					(cl.chosen_column or half) + 0.5 - half,
					(mid or half) + 0.5 - half,
				}
			else
				local v = ((cl.chosen_column or half) + 0.5) / size
				local u0 = (st + 0.5) / size
				local u1 = (ed + 0.5) / size
				t_min = (u0 - ox) * tx + (v - oy) * ty
				t_max = (u1 - ox) * tx + (v - oy) * ty
				if t_min > t_max then
					t_min, t_max = t_max, t_min
				end
				range_mid_t = (t_min + t_max) * 0.5
				centroid_local = {
					(mid or half) + 0.5 - half,
					(cl.chosen_column or half) + 0.5 - half,
				}
			end
		end
		local span_source = (span >= M.MIN_VALID_INTERFACE_SPAN and (cl.count or 0) >= M.MIN_INTERFACE_SAMPLES)
			and "interface" or ((span > 0) and "interface" or "none")
		local iface = {
			mode = "centerline",
			span_px = span,
			interface_span_px = span,
			keep_span_px = span,
			span_source = span_source,
			band_px = 1,
			candidate_ratio = seam_normal_anchor,
			interface_confidence = (span_source == "interface") and 1 or 0,
			centroid_local = centroid_local,
			edge_centroid_from_center = centroid_local,
			keep_centroid_from_center = centroid_local,
			count = cl.count or 0,
			keep_count = cl.count or 0,
			nonzero_samples = cl.count or 0,
			t_min = t_min,
			t_max = t_max,
			range_mid_t = range_mid_t,
			centroid_t = range_mid_t,
			centroid_minus_range_mid = 0,
			t_min_px = t_min and (t_min * size) or nil,
			t_max_px = t_max and (t_max * size) or nil,
			range_mid_t_px = range_mid_t and (range_mid_t * size) or nil,
			centroid_t_px = range_mid_t and (range_mid_t * size) or nil,
			sample_step = sample_step,
			fmt = blob.fmt,
			bytes = blob.bytes,
		}
		local charm_diag = charm_filter.diag_snapshot({
			active = opts.charm_filter ~= false and charm_filter.is_enabled(),
			removed_pixels = cl.charm_skipped or cl.charm_pixels_skipped or 0,
			charm_skipped = cl.charm_skipped or cl.charm_pixels_skipped or 0,
			body_start_y = cl.body_start_y,
		})
		return {
			size = size,
			bbox = nil,
			alpha = nil,
			centerline = cl,
			charm_filter = charm_diag,
			sample_step = sample_step,
			cut_origin = cut_origin,
			cut_local = cut_local,
			raw_cut_local = { cut_local[1], cut_local[2] },
			seam_normal_anchor = seam_normal_anchor or 0,
			cut_normal = { nx, ny },
			keep_sign = keep_sign,
			band_px = 1,
			candidate_ratio = seam_normal_anchor,
			cut_locked = true,
			cut_score = nil,
			cut_score_margin = nil,
			cut_changed = false,
			cut_candidates = nil,
			would_choose_ratio = nil,
			span_source = span_source,
			interface_confidence = iface.interface_confidence,
			filtered_interface_span = span,
			raw_interface_span = nil,
			interface = iface,
			_iface = iface,
			_blob = blob,
		}, nil
	end

	-- Non-production / probe cut search: single alpha pass (no charm dual scan).
	local alpha = analyze_image_alpha_blob(blob, size, sample_step)
	local bbox = alpha and alpha.bbox

	local cut_origin
	local iface
	local band_px = M.compute_band_px(bbox)
	local candidate_ratio = nil
	local span_source = "none"
	local span = 0
	local cut_candidates = nil
	local cut_score = nil
	local cut_score_margin = nil
	local cut_changed = nil
	local would_choose_ratio = nil
	local cut_locked = false
	local raw_cut_local = nil
	local cut_opts = {
		band_px = band_px,
		sample_step = sample_step,
		previous_ratio = opts.previous_ratio,
	}

	if locked_ratio and bbox then
		cut_locked = true
		local locked, lerr = M.analyze_locked_cut(
			blob, size, bbox, cut_normal, keep_sign, locked_ratio, cut_opts
		)
		if not locked then
			return nil, lerr or "locked cut failed"
		end
		cut_origin = locked.cut_origin
		iface = locked.interface
		band_px = locked.band_px or band_px
		candidate_ratio = locked.candidate_ratio
		cut_score = locked.score
		if collect then
			local probe_best = M.find_best_cut(blob, size, bbox, cut_normal, keep_sign, cut_opts)
			if probe_best then
				cut_candidates = probe_best.candidates
				would_choose_ratio = probe_best.candidate_ratio
				cut_score_margin = probe_best.score_margin
				cut_changed = probe_best.changed
			end
		end
	elseif lock and bbox then
		local best, ferr = M.find_best_cut(blob, size, bbox, cut_normal, keep_sign, cut_opts)
		if not best then
			return nil, ferr or "find_best_cut failed"
		end
		cut_origin = best.cut_origin
		iface = best.interface
		band_px = best.band_px or band_px
		candidate_ratio = best.candidate_ratio
		cut_score = best.score
		cut_score_margin = best.score_margin
		cut_changed = best.changed
		cut_candidates = best.candidates
		would_choose_ratio = best.candidate_ratio
	else
		cut_origin = opts.cut_origin
		if type(cut_origin) ~= "table" then
			cut_origin = bbox and M.resolve_content_cut_origin(bbox, size) or { 0.5, 0.5 }
		end
		local ierr
		iface, ierr = analyze_cut_interface(
			image, size, cut_origin, cut_normal, keep_sign, sample_step, blob, bbox, band_px, nil
		)
		if not iface then
			return nil, ierr
		end
	end

	span, span_source = M.choose_interface_span(iface)
	local interface_confidence = confidence_from_span_source(span_source)

	local cu = cut_origin[1] or 0.5
	local cv = cut_origin[2] or 0.5
	local cut_local = {
		(cu - 0.5) * size,
		(cv - 0.5) * size,
	}
	if raw_cut_local == nil then
		raw_cut_local = { cut_local[1], cut_local[2] }
	end

	local centroid = iface and (iface.edge_centroid_from_center or iface.keep_centroid_from_center) or { 0, 0 }

	return {
		size = size,
		bbox = bbox,
		alpha = alpha,
		sample_step = sample_step,
		cut_origin = { cu, cv },
		cut_local = cut_local,
		raw_cut_local = raw_cut_local,
		seam_normal_anchor = nil,
		cut_normal = { cut_normal[1] or 1, cut_normal[2] or 0 },
		keep_sign = keep_sign,
		band_px = band_px,
		candidate_ratio = candidate_ratio,
		cut_locked = cut_locked,
		cut_score = cut_score,
		cut_score_margin = cut_score_margin,
		cut_changed = cut_changed,
		cut_candidates = cut_candidates,
		would_choose_ratio = would_choose_ratio,
		span_source = span_source,
		interface_confidence = interface_confidence,
		interface = {
			mode = iface.mode,
			span_px = span,
			interface_span_px = iface.interface_span_px or 0,
			keep_span_px = iface.keep_span_px or 0,
			span_source = span_source,
			band_px = band_px,
			candidate_ratio = candidate_ratio,
			interface_confidence = interface_confidence,
			centroid_local = { centroid[1] or 0, centroid[2] or 0 },
			count = iface.count,
			keep_count = iface.keep_count,
			nonzero_samples = iface.nonzero_samples,
			fmt = iface.fmt,
			bytes = iface.bytes,
			edge_centroid_from_center = iface.edge_centroid_from_center,
			keep_centroid_from_center = iface.keep_centroid_from_center,
			t_min = iface.t_min,
			t_max = iface.t_max,
			range_mid_t = iface.range_mid_t,
			centroid_t = iface.centroid_t,
			centroid_minus_range_mid = iface.centroid_minus_range_mid,
			t_min_px = iface.t_min_px,
			t_max_px = iface.t_max_px,
			range_mid_t_px = iface.range_mid_t_px,
			centroid_t_px = iface.centroid_t_px,
			sample_step = iface.sample_step,
		},
		_iface = iface,
	}, nil
end

local function confidence_is_good(c)
	if c == true or c == "interface" then
		return true
	end
	if type(c) == "number" then
		return c >= 0.5
	end
	return false
end

--- Blend frame interface ratio with optional numeric reference spans (not profiles).
--- opts: interface_confidence host/donor, degraded, frame_weight, reference_weight
function M.blend_scale_ratio(frame_ratio, host_reference_span, donor_reference_span, opts)
	opts = opts or {}
	frame_ratio = tonumber(frame_ratio)
	local frame_valid = frame_ratio ~= nil and frame_ratio > 0
	if not frame_valid then
		frame_ratio = 1
	end
	local hs = tonumber(host_reference_span)
	local ds = tonumber(donor_reference_span)
	local reference_ratio = 1
	local has_ref = hs and ds and hs > 0 and ds > 0
	if has_ref then
		reference_ratio = hs / ds
	end

	local host_conf = opts.host_interface_confidence
	if host_conf == nil then host_conf = opts.host_confidence end
	local donor_conf = opts.donor_interface_confidence
	if donor_conf == nil then donor_conf = opts.donor_confidence end
	local both_good = confidence_is_good(host_conf) and confidence_is_good(donor_conf)
	local degraded = opts.degraded == true or not both_good

	local frame_w
	local ref_w
	local span_source = "blend"
	if not frame_valid or not frame_ratio or frame_ratio <= 0 then
		frame_w = 0
		ref_w = 1
		span_source = "reference_only"
		frame_ratio = has_ref and reference_ratio or 1
	elseif not has_ref then
		frame_w = 1
		ref_w = 0
		span_source = "frame_only"
	elseif both_good and not (opts.degraded == true) then
		frame_w = tonumber(opts.frame_weight) or 0.7
		ref_w = tonumber(opts.reference_weight) or 0.3
		span_source = "both_good"
	else
		frame_w = tonumber(opts.frame_weight_degraded) or 0.3
		ref_w = tonumber(opts.reference_weight_degraded) or 0.7
		span_source = degraded and "degraded" or "both_good"
	end

	local ratio = frame_ratio * frame_w + reference_ratio * ref_w
	if frame_w + ref_w <= 0 then
		ratio = has_ref and reference_ratio or frame_ratio
	end
	local min_s = tonumber(opts.min_scale) or M.MIN_SCALE
	local max_s = tonumber(opts.max_scale) or M.MAX_SCALE
	if min_s > max_s then
		min_s, max_s = max_s, min_s
	end
	local clamped = false
	local clamped_lo = false
	local clamped_hi = false
	if ratio < min_s then
		ratio = min_s
		clamped = true
		clamped_lo = true
	elseif ratio > max_s then
		ratio = max_s
		clamped = true
		clamped_hi = true
	end
	return {
		frame_ratio = frame_ratio,
		reference_ratio = reference_ratio,
		final_ratio = ratio,
		clamped = clamped,
		clamped_lo = clamped_lo,
		clamped_hi = clamped_hi,
		min_scale = min_s,
		max_scale = max_s,
		host_ref_span = hs,
		donor_ref_span = ds,
		frame_weight_used = frame_w,
		reference_weight_used = ref_w,
		span_source = span_source,
		degraded = degraded,
		host_interface_confidence = host_conf,
		donor_interface_confidence = donor_conf,
	}
end

--- Gate3D canonical solve: body/cut-lock → tangent-only interface slide.
--- opts: cut_normal, host_reference_span, donor_reference_span, base_scale,
---       body_scale (legacy fixed), locked_scale (GeometryNodePair cached scale),
---       tangent_align ("range_mid"|"centroid"), min_scale, max_scale
--- Production prefers locked_scale from node_pair_scale cache; interface spans
--- drive that cache once per GeometryNodePair, not every Interpolated tick.
function M.solve_pair(host_analysis, donor_analysis, opts)
	opts = opts or {}
	if type(host_analysis) ~= "table" or type(donor_analysis) ~= "table" then
		return nil, "analyses required"
	end
	local hi = host_analysis.interface or {}
	local di = donor_analysis.interface or {}
	local hs, hs_src = M.choose_interface_span(hi)
	local ds, ds_src = M.choose_interface_span(di)
	local frame_ratio = nil
	local frame_valid = hs >= M.MIN_VALID_INTERFACE_SPAN and ds >= M.MIN_VALID_INTERFACE_SPAN
		and hs_src == "interface" and ds_src == "interface"
	if frame_valid then
		frame_ratio = hs / ds
	end

	local hs_ref = tonumber(opts.host_reference_span)
	local ds_ref = tonumber(opts.donor_reference_span)
	local reference_ratio = 1
	if hs_ref and ds_ref and hs_ref > 0 and ds_ref > 0 then
		reference_ratio = hs_ref / ds_ref
	end

	local blend
	local body_scale = tonumber(opts.body_scale)
	local locked_scale = tonumber(opts.locked_scale)
	if body_scale and body_scale > 0 then
		-- Production: fixed body size independent of current interface spans.
		blend = {
			frame_ratio = frame_ratio or 1,
			reference_ratio = reference_ratio,
			final_ratio = body_scale,
			would_be_ratio = frame_ratio,
			clamped = false,
			clamped_lo = false,
			clamped_hi = false,
			min_scale = tonumber(opts.min_scale) or M.MIN_SCALE,
			max_scale = tonumber(opts.max_scale) or M.MAX_SCALE,
			host_ref_span = hs_ref,
			donor_ref_span = ds_ref,
			frame_weight_used = 0,
			reference_weight_used = 0,
			span_source = "body_scale",
			degraded = false,
			locked = true,
			host_interface_confidence = host_analysis.interface_confidence or hi.interface_confidence or hs_src,
			donor_interface_confidence = donor_analysis.interface_confidence or di.interface_confidence or ds_src,
		}
	elseif locked_scale and locked_scale > 0 then
		blend = {
			frame_ratio = frame_ratio or 1,
			reference_ratio = reference_ratio,
			final_ratio = locked_scale,
			would_be_ratio = frame_ratio,
			clamped = false,
			clamped_lo = false,
			clamped_hi = false,
			min_scale = tonumber(opts.min_scale) or M.MIN_SCALE,
			max_scale = tonumber(opts.max_scale) or M.MAX_SCALE,
			host_ref_span = hs_ref,
			donor_ref_span = ds_ref,
			frame_weight_used = 0,
			reference_weight_used = 0,
			span_source = "locked_scale",
			degraded = false,
			locked = true,
			host_interface_confidence = host_analysis.interface_confidence or hi.interface_confidence or hs_src,
			donor_interface_confidence = donor_analysis.interface_confidence or di.interface_confidence or ds_src,
		}
	else
		blend = M.blend_scale_ratio(
			frame_ratio,
			opts.host_reference_span,
			opts.donor_reference_span,
			{
				host_interface_confidence = host_analysis.interface_confidence or hi.interface_confidence or hs_src,
				donor_interface_confidence = donor_analysis.interface_confidence or di.interface_confidence or ds_src,
				degraded = opts.degraded,
				frame_weight = opts.frame_weight,
				reference_weight = opts.reference_weight,
				frame_weight_degraded = opts.frame_weight_degraded,
				reference_weight_degraded = opts.reference_weight_degraded,
				min_scale = opts.min_scale,
				max_scale = opts.max_scale,
			}
		)
	end
	local base = tonumber(opts.base_scale) or 1
	local donor_scale = base * (tonumber(blend.final_ratio) or 1)

	local cn = opts.cut_normal
		or host_analysis.cut_normal
		or donor_analysis.cut_normal
		or { 1, 0 }
	local nx = cn[1] or 1
	local ny = cn[2] or 0
	local nlen = math.sqrt(nx * nx + ny * ny)
	if nlen < 1e-6 then nx, ny = 1, 0 else nx, ny = nx / nlen, ny / nlen end
	local tx, ty = -ny, nx

	local hc = host_analysis.cut_local or { 0, 0 }
	local dc = donor_analysis.cut_local or { 0, 0 }
	local hcx, hcy = hc[1] or 0, hc[2] or 0
	local dcx, dcy = dc[1] or 0, dc[2] or 0

	local hcent = hi.centroid_local or hi.edge_centroid_from_center or { 0, 0 }
	local dcent = di.centroid_local or di.edge_centroid_from_center or { 0, 0 }
	local hx, hy = hcent[1] or 0, hcent[2] or 0
	local dx, dy = dcent[1] or 0, dcent[2] or 0

	-- 1) lock cut origins  2) tangent-only slide
	-- Production uses interface range mid (t_min+t_max)/2 — geometric extent of the seam
	-- cross-section — not alpha-weighted centroid (Head pixel mass must not dominate).
	local ox = hcx - dcx * donor_scale
	local oy = hcy - dcy * donor_scale
	local host_size = tonumber(host_analysis.size) or 128
	local donor_size = tonumber(donor_analysis.size) or 128
	local tangent_mode = opts.tangent_align or "range_mid"
	local host_t, donor_t0, tangent_source
	if tangent_mode == "range_mid"
		and hi.range_mid_t ~= nil
		and di.range_mid_t ~= nil
	then
		host_t = hi.range_mid_t * host_size
		donor_t0 = di.range_mid_t * donor_size * donor_scale
		tangent_source = "range_mid"
	else
		host_t = (hx - hcx) * tx + (hy - hcy) * ty
		donor_t0 = (dx * donor_scale + ox - hcx) * tx + (dy * donor_scale + oy - hcy) * ty
		tangent_source = "centroid"
	end
	local dt = host_t - donor_t0
	ox = ox + tx * dt
	oy = oy + ty * dt

	local cut_dx = hcx - (dcx * donor_scale + ox)
	local cut_dy = hcy - (dcy * donor_scale + oy)
	local normal_residual = cut_dx * nx + cut_dy * ny

	local h_origin = host_analysis.cut_origin or { 0.5, 0.5 }
	local d_origin = donor_analysis.cut_origin or { 0.5, 0.5 }

	local host_band = host_analysis.band_px or hi.band_px
	local donor_band = donor_analysis.band_px or di.band_px

	-- Interface points used for solve diagnostics / draw (range mid in local when available).
	local h_iface_x, h_iface_y = hx, hy
	local d_iface_x, d_iface_y = dx, dy
	if tangent_source == "range_mid" then
		h_iface_x = hcx + tx * host_t
		h_iface_y = hcy + ty * host_t
		d_iface_x = dcx + tx * (di.range_mid_t * donor_size)
		d_iface_y = dcy + ty * (di.range_mid_t * donor_size)
	end

	return {
		cut_normal = { nx, ny },
		tangent = { tx, ty },
		host = {
			cut_origin = { h_origin[1] or 0.5, h_origin[2] or 0.5 },
			cut_local = { hcx, hcy },
			scale = 1,
			offset_local = { 0, 0 },
			interface_local = { h_iface_x, h_iface_y },
			keep_sign = host_analysis.keep_sign or -1,
			size = host_analysis.size,
			bbox = host_analysis.bbox,
		},
		donor = {
			cut_origin = { d_origin[1] or 0.5, d_origin[2] or 0.5 },
			cut_local = { dcx, dcy },
			scale = donor_scale,
			offset_local = { ox, oy },
			interface_local = { d_iface_x, d_iface_y },
			keep_sign = donor_analysis.keep_sign or 1,
			size = donor_analysis.size,
			bbox = donor_analysis.bbox,
		},
		diagnostics = {
			host_span = hs,
			donor_span = ds,
			host_span_source = hs_src,
			donor_span_source = ds_src,
			frame_ratio = blend.frame_ratio,
			reference_ratio = blend.reference_ratio,
			final_ratio = blend.final_ratio,
			chosen_tangent_source = tangent_source,
			host_interface_t = host_t,
			donor_interface_t = donor_t0,
			tangent_dt = dt,
			host_range_mid_t = hi.range_mid_t,
			donor_range_mid_t = di.range_mid_t,
			host_centroid_t = hi.centroid_t,
			donor_centroid_t = di.centroid_t,
			would_be_ratio = blend.would_be_ratio,
			clamped = blend.clamped,
			clamped_lo = blend.clamped_lo,
			clamped_hi = blend.clamped_hi,
			min_scale = blend.min_scale,
			max_scale = blend.max_scale,
			host_ref_span = blend.host_ref_span,
			donor_ref_span = blend.donor_ref_span,
			frame_weight_used = blend.frame_weight_used,
			reference_weight_used = blend.reference_weight_used,
			blend_span_source = blend.span_source,
			degraded = blend.degraded,
			scale_locked = blend.locked == true,
			tangent_slide = dt,
			normal_residual = normal_residual,
			host_band_px = host_band,
			donor_band_px = donor_band,
			host_candidate_ratio = host_analysis.candidate_ratio or hi.candidate_ratio,
			donor_candidate_ratio = donor_analysis.candidate_ratio or di.candidate_ratio,
			host_mode = hi.mode,
			donor_mode = di.mode,
			base_scale = base,
		},
	}, nil
end

local function bbox_to_center_rel(bbox, rt_size)
	if type(bbox) ~= "table" then return nil end
	rt_size = tonumber(rt_size) or 128
	local cx = rt_size * 0.5
	local cy = rt_size * 0.5
	return {
		minx = (tonumber(bbox.minx) or 0) - cx,
		miny = (tonumber(bbox.miny) or 0) - cy,
		maxx = (tonumber(bbox.maxx) or 0) - cx,
		maxy = (tonumber(bbox.maxy) or 0) - cy,
	}
end

local function transform_bbox(bbox, scale, offset)
	if type(bbox) ~= "table" then return nil end
	scale = tonumber(scale) or 1
	offset = offset or { 0, 0 }
	local ox = offset[1] or offset.x or 0
	local oy = offset[2] or offset.y or 0
	return {
		minx = bbox.minx * scale + ox,
		miny = bbox.miny * scale + oy,
		maxx = bbox.maxx * scale + ox,
		maxy = bbox.maxy * scale + oy,
	}
end

local function union_bbox(a, b)
	if not a then return b end
	if not b then return a end
	return {
		minx = math.min(a.minx, b.minx),
		miny = math.min(a.miny, b.miny),
		maxx = math.max(a.maxx, b.maxx),
		maxy = math.max(a.maxy, b.maxy),
	}
end

--- Combined stitched content size from a solve_pair solution.
function M.compute_pair_bbox(solution)
	if type(solution) ~= "table" then return nil end
	local host = solution.host or {}
	local donor = solution.donor or {}
	local host_rel = bbox_to_center_rel(host.bbox, host.size)
	local donor_rel = bbox_to_center_rel(donor.bbox, donor.size)
	if not host_rel and not donor_rel then return nil end
	local host_t = host_rel and transform_bbox(host_rel, host.scale or 1, host.offset_local) or nil
	local donor_t = donor_rel and transform_bbox(donor_rel, donor.scale or 1, donor.offset_local) or nil
	local u = union_bbox(host_t, donor_t)
	if not u then return nil end
	local w = u.maxx - u.minx
	local h = u.maxy - u.miny
	if w < 1 then w = 1 end
	if h < 1 then h = 1 end
	return { width = w, height = h, bbox = u }
end

--- Uniform presentation fit after solve. Does not change relative Host/Donor transform.
--- Scales the solved pair into the box, then applies ONE common translation so the
--- union bbox center lands at the preview origin (screen_pos).
function M.fit_pair_to_box(solution, width, height, opts)
	opts = opts or {}
	width = tonumber(width) or 92
	height = tonumber(height) or 76
	local max_scale = tonumber(opts.max_scale) or 1.35
	local pair = M.compute_pair_bbox(solution)
	local bbox_w = (pair and pair.width) or 32
	local bbox_h = (pair and pair.height) or 32
	if bbox_w < 1 then bbox_w = 1 end
	if bbox_h < 1 then bbox_h = 1 end
	local fit = math.min(width / bbox_w, height / bbox_h, max_scale)
	local host = solution and solution.host or {}
	local donor = solution and solution.donor or {}
	local h_off = host.offset_local or { 0, 0 }
	local d_off = donor.offset_local or { 0, 0 }
	local u = pair and pair.bbox
	local cx = 0
	local cy = 0
	if u then
		cx = ((tonumber(u.minx) or 0) + (tonumber(u.maxx) or 0)) * 0.5
		cy = ((tonumber(u.miny) or 0) + (tonumber(u.maxy) or 0)) * 0.5
	end
	-- Presentation-only common shift: center the scaled union at preview origin.
	local common_x = -cx * fit
	local common_y = -cy * fit
	return {
		fit_scale = fit,
		host_scale = (host.scale or 1) * fit,
		donor_scale = (donor.scale or 1) * fit,
		host_offset = {
			(h_off[1] or 0) * fit + common_x,
			(h_off[2] or 0) * fit + common_y,
		},
		donor_offset = {
			(d_off[1] or 0) * fit + common_x,
			(d_off[2] or 0) * fit + common_y,
		},
		common_offset = { common_x, common_y },
		union_bbox = u,
		union_center = { cx, cy },
		bbox_w = bbox_w,
		bbox_h = bbox_h,
		max_scale = max_scale,
	}
end

-- Public re-exports used by adapters / probes
M.read_texel_blob = read_texel_blob
M.texel_rgba_at = texel_rgba_at
M.analyze_image_alpha_blob = analyze_image_alpha_blob
M.analyze_cut_interface = analyze_cut_interface
M.cut_origin_at_ratio = cut_origin_at_ratio
M.score_cut_candidate = score_cut_candidate
M.bbox_to_center_rel = bbox_to_center_rel
M.transform_bbox = transform_bbox
M.union_bbox = union_bbox

return M
