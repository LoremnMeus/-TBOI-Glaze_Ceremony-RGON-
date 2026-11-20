-- Sprite scanline fill. Screen rectangles only; no DestinationQuad.
-- World outlines are projected with WorldToScreen on this render frame.
-- Mirror world: flip the whole projected spray on screen X (draw only).
-- Screen positions are not written back into the stream or the regions.

local C = require("Qing_Remaster_scripts.items.incandescence_flame.constants")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local renderer = {
	backend = "sprite_scanline",
	source_sprite_loaded = false,
	error_count = 0,
	first_error = nil,
	first_error_phase = nil,
	raster_rows = 0,
	raster_intervals = 0,
	sprite_draw_calls = 0,
	invalid_intersection_count = 0,
	odd_intersection_count = 0,
	raster_budget_clamped = false,
	scanline_height = 2,
}

local ORDER = { "outer", "orange", "gold", "white" }
local sprite = nil
local load_failed = false

local function note_error(phase, err)
	renderer.error_count = renderer.error_count + 1
	if not renderer.first_error then
		renderer.first_error_phase = phase
		renderer.first_error = tostring(phase) .. ": " .. tostring(err)
	end
end

function renderer.reset_errors()
	renderer.error_count = 0
	renderer.first_error = nil
	renderer.first_error_phase = nil
end

local function begin_frame(cfg)
	local step = cfg and cfg.scanline_height or 2
	if step ~= 1 and step ~= 2 and step ~= 4 then
		step = 2
	end
	renderer.scanline_height = step
	renderer.raster_rows = 0
	renderer.raster_intervals = 0
	renderer.sprite_draw_calls = 0
	renderer.invalid_intersection_count = 0
	renderer.odd_intersection_count = 0
	renderer.raster_budget_clamped = false
	renderer.odd_scanlines = {}
	renderer.last_odd_scanline = nil
	renderer.geometry_skip_count = 0
	renderer.self_intersection_count = 0
	renderer.local_fold_count = 0
	renderer.scanline_edge_tests = 0
	renderer.region_vertex_count = 0
	renderer.active_edge_peak = 0
	renderer.screen_projection_ns = 0
	renderer.scanline_fill_ns = 0
	renderer.sprite_submit_ns = 0
	renderer.time_submits = cfg and cfg.perf_stats ~= false
	renderer.intervals_before = 0
	renderer.intervals_after = 0
	renderer.fill_layers = {}
	renderer.fill_spans = {}
	renderer.segment_intervals = {}
	renderer.segment_raster_skips = {}
	renderer.paint_rects = {}
	renderer.paint_rects_truncated = false
	renderer.keep_paint = false
	renderer.segment_coverage = {}
	renderer.segment_poly = {}
	renderer.coverage_rows = 0
	renderer.coverage_ys = {}
	renderer.raster_rows_estimate = 0
	renderer.raster_calls_estimate = 0
	renderer.raster_step_used = step
	renderer.raster_front_step = 1
	renderer.raster_degraded = false
	renderer.raster_over_soft_budget = false
	renderer.raster_clamp_layer = nil
	renderer.raster_clamp_y = nil
	renderer.timer_ready = Isaac.GetNanoTime ~= nil
	return step
end

local function nano()
	if Isaac.GetNanoTime then
		return Isaac.GetNanoTime()
	end
	return nil
end

local function ensure()
	if sprite then
		return sprite
	end
	if load_failed then
		return nil
	end
	local sp = Sprite()
	local ok, err = pcall(function()
		local loaded = sp:Load(C.SOLID_ANM2, true)
		if loaded == false then
			error("Load returned false")
		end
		sp:Play("Solid", true)
		sp:SetFrame("Solid", 0)
	end)
	if not ok then
		load_failed = true
		renderer.backend = "unavailable"
		renderer.source_sprite_loaded = false
		note_error("sprite_load", err)
		return nil
	end
	sprite = sp
	renderer.source_sprite_loaded = true
	if renderer.backend == "unavailable" or not renderer.backend then
		renderer.backend = "sprite_scanline"
	end
	return sprite
end

local function draw_solid_rect(sp, x, y, w, h, r, g, b)
	if w < 1 or h < 1 then
		return false
	end
	if renderer.keep_paint then
		local box = renderer.paint_rects
		if #box < 800 then
			box[#box + 1] = { x = x, y = y, w = w, h = h }
		else
			renderer.paint_rects_truncated = true
		end
	end
	sp.Color = Color(r, g, b, 1)
	sp.Scale = Vector(w / C.SOLID_PX, h / C.SOLID_PX)
	sp.Rotation = 0
	if renderer.time_submits then
		local t0 = nano()
		local ok, err = pcall(function()
			sp:Render(Vector(x + w * 0.5, y + h * 0.5), Vector(0, 0), Vector(0, 0))
		end)
		if t0 then
			renderer.sprite_submit_ns = (renderer.sprite_submit_ns or 0) + (Isaac.GetNanoTime() - t0)
		end
		if not ok then
			note_error("sprite_render", err)
			return false
		end
	else
		sp:Render(Vector(x + w * 0.5, y + h * 0.5), Vector(0, 0), Vector(0, 0))
	end
	renderer.sprite_draw_calls = renderer.sprite_draw_calls + 1
	return true
end

-- Draw-only. Same horizontal remap family as Shader_holder / Remaster UV mirror.
function renderer.world_to_screen(x, y)
	local screen = Isaac.WorldToScreen(Vector(x, y))
	local room = Game():GetRoom()
	if not room or room:IsMirrorWorld() ~= true then
		return screen
	end
	local size = auxi.GetScreenSize()
	local mult = auxi.check_screen_multi(Vector(1, 1))
	local sz = size.X
	while sz > 256 do
		sz = sz / 2
	end
	return Vector(sz * mult.X - screen.X, screen.Y)
end

local function screen_of(point)
	return renderer.world_to_screen(point.x, point.y)
end

local function push_poly(poly, x, y)
	if x ~= x or y ~= y then
		return false
	end
	local prev = poly[#poly]
	if prev then
		local dx = x - prev.x
		local dy = y - prev.y
		if dx * dx + dy * dy < 0.25 then
			return true
		end
	end
	poly[#poly + 1] = { x = x, y = y }
	return true
end

local function polygon_from(upper, lower, a, b, caps)
	local poly = {}
	for i = a, b do
		local p = upper[i]
		if not p or p.break_chain then
			return nil
		end
		local s = screen_of(p)
		if not push_poly(poly, s.X, s.Y) then
			return nil, "nan"
		end
	end
	local cap = caps and caps[b]
	if cap then
		for i = 1, #cap do
			local s = screen_of(cap[i])
			if not push_poly(poly, s.X, s.Y) then
				return nil, "nan"
			end
		end
	end
	for i = b, a, -1 do
		local p = lower[i]
		if not p or p.break_chain then
			return nil, "degenerate"
		end
		local s = screen_of(p)
		if not push_poly(poly, s.X, s.Y) then
			return nil, "nan"
		end
	end
	if #poly >= 2 then
		local first = poly[1]
		local last = poly[#poly]
		local dx = first.x - last.x
		local dy = first.y - last.y
		if dx * dx + dy * dy < 0.25 then
			poly[#poly] = nil
		end
	end
	if #poly < 3 then
		return nil, "degenerate"
	end
	return poly
end

local function edge_cross(a, b, c)
	return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
end

local function proper_cross(a, b, c, d)
	local ab_c = edge_cross(a, b, c)
	local ab_d = edge_cross(a, b, d)
	local cd_a = edge_cross(c, d, a)
	local cd_b = edge_cross(c, d, b)
	return ab_c * ab_d < 0 and cd_a * cd_b < 0
end

local function classify_polygon(poly)
	local n = #poly
	local folds = 0
	local self_hit = false
	if n < 3 then
		return 0, false
	end
	for i = 1, n do
		local a = poly[i]
		local b = poly[i % n + 1]
		local c = poly[(i + 1) % n + 1]
		local abx, aby = b.x - a.x, b.y - a.y
		local bcx, bcy = c.x - b.x, c.y - b.y
		local ab = math.sqrt(abx * abx + aby * aby)
		local bc = math.sqrt(bcx * bcx + bcy * bcy)
		if ab > 0.5 and bc > 0.5 then
			local dot = (abx * bcx + aby * bcy) / (ab * bc)
			if dot < -0.2 then
				folds = folds + 1
			end
		end
	end
	for i = 1, n do
		local a = poly[i]
		local b = poly[i % n + 1]
		local j0 = i + 2
		for j = j0, n do
			local jn = j % n + 1
			if not (i == 1 and j == n) and jn ~= i then
				local c = poly[j]
				local d = poly[jn]
				if proper_cross(a, b, c, d) then
					self_hit = true
					break
				end
			end
		end
		if self_hit then
			break
		end
	end
	return folds, self_hit
end

local function crossings(poly, y)
	local hits = {}
	local n = #poly
	for i = 1, n do
		local p = poly[i]
		local q = poly[i % n + 1]
		local y0, y1 = p.y, q.y
		if y0 ~= y1 then
			local ymin, ymax = y0, y1
			if ymin > ymax then
				ymin, ymax = ymax, ymin
			end
			if y >= ymin and y < ymax then
				local t = (y - y0) / (y1 - y0)
				local x = p.x + (q.x - p.x) * t
				if x ~= x then
					renderer.invalid_intersection_count = renderer.invalid_intersection_count + 1
				else
					hits[#hits + 1] = { x = x, edge = i }
				end
			end
		end
	end
	table.sort(hits, function(a, b)
		return a.x < b.x
	end)
	renderer.scanline_edge_tests = (renderer.scanline_edge_tests or 0) + n
	return hits
end

local function remember_odd(layer, y, poly, hits, kind)
	local xs = {}
	local edges = {}
	for i = 1, #hits do
		xs[i] = hits[i].x
		edges[i] = hits[i].edge
	end
	local row = {
		layer = layer,
		scanline_y = y,
		polygon_id = poly.id or 0,
		intersection_count = #hits,
		intersection_x_values = xs,
		crossed_edge_indices = edges,
		polygon_self_intersection = poly.self_hit == true,
		local_fold_count = poly.fold_count or 0,
		kind = kind,
	}
	renderer.last_odd_scanline = row
	if kind == "odd" then
		local slots = renderer.fill_layers
		local slot = slots and slots[layer]
		if slot then
			slot.odd_rows = (slot.odd_rows or 0) + 1
		end
	end
	local list = renderer.odd_scanlines or {}
	list[#list + 1] = row
	if #list > 8 then
		table.remove(list, 1)
	end
	renderer.odd_scanlines = list
end

local function mark_coverage(y)
	local seen = renderer.coverage_ys
	if not seen then
		seen = {}
		renderer.coverage_ys = seen
	end
	if not seen[y] then
		seen[y] = true
		renderer.coverage_rows = (renderer.coverage_rows or 0) + 1
	end
end

local function note_layer_scan(key, y)
	local slots = renderer.fill_layers
	local slot = slots and slots[key]
	if not slot then
		return
	end
	slot.raster_rows = (slot.raster_rows or 0) + 1
	slot.last_scanline_y = y
end

local function note_budget_clamp(key, y)
	renderer.raster_budget_clamped = true
	if not renderer.raster_clamp_layer then
		renderer.raster_clamp_layer = key
		renderer.raster_clamp_y = y
	end
	local slots = renderer.fill_layers
	local slot = slots and key and slots[key]
	if slot and not slot.clamped then
		slot.clamped = true
		slot.clamp_scanline_y = y
	end
end

local function fill_polygon(sp, poly, step, color, budget, show_rows)
	local min_y = poly[1].y
	local max_y = poly[1].y
	for i = 2, #poly do
		if poly[i].y < min_y then min_y = poly[i].y end
		if poly[i].y > max_y then max_y = poly[i].y end
	end
	local y = math.floor(min_y / step) * step
	local y_end = math.ceil(max_y / step) * step
	while y < y_end do
		if renderer.sprite_draw_calls >= budget.calls then
			note_budget_clamp(color.key or "region", y)
			return
		end
		renderer.raster_rows = renderer.raster_rows + 1
		note_layer_scan(color.key or "region", y)
		local sample = y + step * 0.5
		local hits = crossings(poly, sample)
		if #hits % 2 == 1 then
			renderer.odd_intersection_count = renderer.odd_intersection_count + 1
			remember_odd(color.key or "region", sample, poly, hits, "odd")
		end
		local i = 1
		while #hits % 2 == 0 and i < #hits do
			if renderer.sprite_draw_calls >= budget.calls then
				note_budget_clamp(color.key or "region", y)
				return
			end
			local x0 = math.floor(math.min(hits[i].x, hits[i + 1].x) + 1e-4)
			local x1 = math.ceil(math.max(hits[i].x, hits[i + 1].x) - 1e-4)
			if x1 <= x0 then
				x1 = x0 + 1
			end
			if draw_solid_rect(sp, x0, y, x1 - x0, step, color.r, color.g, color.b) then
				renderer.raster_intervals = renderer.raster_intervals + 1
				mark_coverage(y)
				if poly and poly.coverage_key == "outer" and poly.segment_id then
					local boxes = renderer.segment_coverage
					if not boxes then
						boxes = {}
						renderer.segment_coverage = boxes
					end
					local box = boxes[poly.segment_id]
					local y1 = y + step
					local span_w = x1 - x0
					if not box then
						box = { min_x = x0, max_x = x1, min_y = y, max_y = y1, span_min = span_w, span_max = span_w, span_n = 1 }
						boxes[poly.segment_id] = box
					else
						if x0 < box.min_x then box.min_x = x0 end
						if x1 > box.max_x then box.max_x = x1 end
						if y < box.min_y then box.min_y = y end
						if y1 > box.max_y then box.max_y = y1 end
						if not box.span_min or span_w < box.span_min then box.span_min = span_w end
						if not box.span_max or span_w > box.span_max then box.span_max = span_w end
						box.span_n = (box.span_n or 0) + 1
					end
				end
				if show_rows and Isaac.DrawLine then
					local mark = KColor(1, 0, 1, 0.35)
					local y_mid = y + step * 0.5
					Isaac.DrawLine(Vector(x0, y_mid), Vector(x1, y_mid), mark, mark, 1)
				end
			end
			i = i + 2
		end
		y = y + step
	end
end

local function each_span(region, fn)
	local upper = region.upper
	local lower = region.lower
	if not upper or not lower then
		return
	end
	local n = #upper
	if #lower < n then
		n = #lower
	end
	local a = 1
	local i = 1
	while i <= n do
		local up = upper[i]
		local lo = lower[i]
		if (up and up.break_chain) or (lo and lo.break_chain) then
			if i > a then
				fn(a, i - 1)
			end
			a = i + 1
		end
		i = i + 1
	end
	if n >= a then
		fn(a, n)
	end
end

local function visible(cfg, key)
	local test = cfg.color_test or "all"
	if test == "particles" then
		return false
	end
	if test ~= "all" then
		return test == key
	end
	if key == "outer" then return cfg.show_outer ~= false end
	if key == "orange" then return cfg.show_orange ~= false end
	if key == "gold" then return cfg.show_gold ~= false end
	if key == "white" then return cfg.show_white ~= false end
	return true
end

local function draw_chain_lines(points, col)
	local prev = nil
	for i = 1, #points do
		local p = points[i]
		if p.break_chain then
			prev = nil
		else
			local screen = screen_of(p)
			if prev then
				Isaac.DrawLine(prev, screen, col, col, 1)
			end
			prev = screen
		end
	end
end

function renderer.draw_gate0(anchor)
	local cfg = { scanline_height = 2 }
	begin_frame(cfg)
	local sp = ensure()
	if not sp then
		return 0
	end
	local ox, oy = 16, 16
	local swatch = {
		{ C.COLOR.outer, 0 },
		{ C.COLOR.orange, 1 },
		{ C.COLOR.gold, 2 },
		{ C.COLOR.white, 3 },
	}
	for i = 1, #swatch do
		local color = swatch[i][1]
		draw_solid_rect(sp, ox + (i - 1) * 34, oy, 28, 28, color.r, color.g, color.b)
	end
	draw_solid_rect(sp, ox, oy + 36, 140, 8, C.COLOR.orange.r, C.COLOR.orange.g, C.COLOR.orange.b)
	draw_solid_rect(sp, ox + 148, oy + 36, 8, 72, C.COLOR.gold.r, C.COLOR.gold.g, C.COLOR.gold.b)
	draw_solid_rect(sp, ox, oy + 52, 48, 1, C.COLOR.white.r, C.COLOR.white.g, C.COLOR.white.b)
	draw_solid_rect(sp, ox, oy + 56, 48, 2, C.COLOR.white.r, C.COLOR.white.g, C.COLOR.white.b)
	draw_solid_rect(sp, ox, oy + 62, 48, 4, C.COLOR.outer.r, C.COLOR.outer.g, C.COLOR.outer.b)
	for n = 1, 40 do
		local col = (n - 1) % 20
		local row = math.floor((n - 1) / 20)
		draw_solid_rect(sp, ox + col * 6, oy + 78 + row * 6, 4, 4, C.COLOR.orange.r, C.COLOR.orange.g, C.COLOR.orange.b)
	end
	if anchor and Isaac.WorldToScreen then
		local screen = renderer.world_to_screen(anchor.x, anchor.y)
		draw_solid_rect(sp, screen.X - 8, screen.Y - 8, 16, 16, C.COLOR.gold.r, C.COLOR.gold.g, C.COLOR.gold.b)
	end
	return renderer.sprite_draw_calls
end

local PRIORITY = { outer = 1, orange = 2, gold = 3, white = 4 }

local function layer_slot(key)
	local slots = renderer.fill_layers or {}
	renderer.fill_layers = slots
	local slot = slots[key]
	if not slot then
		slot = {
			generated = 0,
			audit_skipped = 0,
			polygon_failed = 0,
			rasterized = 0,
			raster_intervals = 0,
			odd_rows = 0,
			source_audit = 0,
		}
		slots[key] = slot
	end
	return slot
end

local function push_fill_span(row)
	local list = renderer.fill_spans or {}
	if #list < 24 then
		list[#list + 1] = row
	end
	renderer.fill_spans = list
end

local function attach_fill_span(key, span_index, edges, err)
	if (not edges or edges == "") and not err then
		return
	end
	local list = renderer.fill_spans or {}
	for i = #list, 1, -1 do
		local row = list[i]
		if row.layer == key and row.span_index == span_index then
			if edges and edges ~= "" then
				row.self_intersection_edges = edges
			end
			if err then
				row.scanline_error = err
			end
			return
		end
	end
	push_fill_span({
		layer = key,
		span_index = span_index,
		audit_skip = false,
		source_audit_skip = false,
		bypassed = false,
		self_intersection_edges = edges or "",
		scanline_error = err,
	})
end

local function first_cross_pair(poly)
	if not poly then
		return nil
	end
	local n = #poly
	for i = 1, n do
		local a = poly[i]
		local b = poly[i % n + 1]
		if a and b and a.x and b.x then
			for j = i + 2, n do
				local jn = j % n + 1
				if not (i == 1 and j == n) and jn ~= i then
					local c = poly[j]
					local d = poly[jn]
					if c and d and c.x and d.x and proper_cross(a, b, c, d) then
						return tostring(i) .. "-" .. tostring(j)
					end
				end
			end
		end
	end
	return nil
end

local function note_span_mark(cfg, key, mark, span_index)
	local slot = layer_slot(key)
	slot.generated = slot.generated + 1
	local flagged = mark and mark.audit_skip == true
	local sourced = mark and mark.source_audit_skip == true
	if sourced then
		slot.source_audit = slot.source_audit + 1
	end
	local bypass = cfg and cfg.fill_skip_diag == true
	local block = flagged and not bypass and not (cfg and cfg.audit_screen == true)
	if block then
		slot.audit_skipped = slot.audit_skipped + 1
	end
	if flagged or sourced then
		push_fill_span({
			layer = key,
			span_index = span_index,
			audit_skip = flagged,
			source_audit_skip = sourced == true,
			bypassed = bypass and flagged or false,
			self_intersection_edges = "",
			scanline_error = block and "audit_skip" or nil,
		})
	end
	local want_edges = bypass or flagged or sourced
	return block, slot, want_edges
end

local function draw_composited(sp, built, cfg, step, budget)
	local polys = {}
	for layer = 1, #ORDER do
		local key = ORDER[layer]
		local region = built[key]
		if region and visible(cfg, key) then
			each_span(region, function(a, b)
				local mark = region.upper and region.upper[a]
				local block, slot, want_edges = note_span_mark(cfg, key, mark, a)
				local ok, poly, why = pcall(polygon_from, region.upper, region.lower, a, b, region.caps)
				if not ok or not poly then
					slot.polygon_failed = slot.polygon_failed + 1
					if why == "nan" then
						renderer.invalid_intersection_count = renderer.invalid_intersection_count + 1
					end
					if not ok then
						note_error("project", poly)
						attach_fill_span(key, a, nil, "project")
					else
						attach_fill_span(key, a, nil, why or "empty")
					end
					if block then
						renderer.geometry_skip_count = (renderer.geometry_skip_count or 0) + 1
					end
					return
				end
				if why == "nan" then
					slot.polygon_failed = slot.polygon_failed + 1
					renderer.invalid_intersection_count = renderer.invalid_intersection_count + 1
					attach_fill_span(key, a, nil, "nan")
					return
				end
				if want_edges then
					attach_fill_span(key, a, first_cross_pair(poly), nil)
				end
				if block then
					renderer.geometry_skip_count = (renderer.geometry_skip_count or 0) + 1
					return
				end
				polys[#polys + 1] = {
					poly = poly,
					key = key,
					priority = PRIORITY[key] or 1,
					r = region.r,
					g = region.g,
					b = region.b,
				}
				slot.rasterized = slot.rasterized + 1
				renderer.region_vertex_count = (renderer.region_vertex_count or 0) + #poly
			end)
		end
	end
	if #polys == 0 then
		return
	end
	local min_y = polys[1].poly[1].y
	local max_y = min_y
	for i = 1, #polys do
		local poly = polys[i].poly
		for k = 1, #poly do
			if poly[k].y < min_y then min_y = poly[k].y end
			if poly[k].y > max_y then max_y = poly[k].y end
		end
	end
	renderer.intervals_before = 0
	renderer.intervals_after = 0
	local function rows_for(span_step)
		local y0 = math.floor(min_y / span_step) * span_step
		local y1 = math.ceil(max_y / span_step) * span_step
		if y1 <= y0 then
			return 0
		end
		return math.floor((y1 - y0) / span_step)
	end
	local use_step = step
	local est = rows_for(use_step)
	local degraded = false
	if est > budget.rows and use_step < 4 then
		use_step = 4
		degraded = true
		est = rows_for(use_step)
	end
	renderer.raster_rows_estimate = est
	renderer.raster_calls_estimate = est * 2
	renderer.raster_step_used = use_step
	renderer.raster_front_step = use_step
	renderer.raster_degraded = degraded
	renderer.raster_over_soft_budget = est > budget.rows
	local y = math.floor(min_y / use_step) * use_step
	local y_end = math.ceil(max_y / use_step) * use_step
	while y < y_end do
		if renderer.sprite_draw_calls >= budget.calls then
			note_budget_clamp("all", y)
			return
		end
		renderer.raster_rows = renderer.raster_rows + 1
		local sample = y + use_step * 0.5
		local spans = {}
		for i = 1, #polys do
			local item = polys[i]
			note_layer_scan(item.key, y)
			local hits = crossings(item.poly, sample)
			if #hits % 2 == 1 then
				renderer.odd_intersection_count = renderer.odd_intersection_count + 1
				remember_odd(item.key, sample, item.poly, hits, "odd")
			else
				local k = 1
				while k < #hits do
					local x0 = math.floor(math.min(hits[k].x, hits[k + 1].x) + 1e-4)
					local x1 = math.ceil(math.max(hits[k].x, hits[k + 1].x) - 1e-4)
					if x1 > x0 then
						spans[#spans + 1] = {
							x0 = x0,
							x1 = x1,
							priority = item.priority,
							r = item.r,
							g = item.g,
							b = item.b,
						}
						renderer.intervals_before = renderer.intervals_before + 1
					end
					k = k + 2
				end
			end
		end
		local marks = {}
		for i = 1, #spans do
			marks[#marks + 1] = spans[i].x0
			marks[#marks + 1] = spans[i].x1
		end
		table.sort(marks)
		local uniq = {}
		for i = 1, #marks do
			if #uniq == 0 or marks[i] ~= uniq[#uniq] then
				uniq[#uniq + 1] = marks[i]
			end
		end
		local prev = nil
		local function flush()
			if not prev then
				return
			end
			if draw_solid_rect(sp, prev.x0, y, prev.x1 - prev.x0, use_step, prev.r, prev.g, prev.b) then
				renderer.raster_intervals = renderer.raster_intervals + 1
				renderer.intervals_after = renderer.intervals_after + 1
				mark_coverage(y)
			end
			prev = nil
		end
		for i = 1, #uniq - 1 do
			local x0 = uniq[i]
			local x1 = uniq[i + 1]
			if x1 > x0 then
				local mid = (x0 + x1) * 0.5
				local best = nil
				for s = 1, #spans do
					local span = spans[s]
					if mid >= span.x0 and mid < span.x1 and (not best or span.priority > best.priority) then
						best = span
					end
				end
				if best then
					if prev and prev.x1 == x0 and prev.r == best.r and prev.g == best.g and prev.b == best.b then
						prev.x1 = x1
					else
						flush()
						prev = { x0 = x0, x1 = x1, r = best.r, g = best.g, b = best.b }
					end
				else
					flush()
				end
			end
		end
		flush()
		y = y + use_step
	end
end

local function poly_rows(poly, span_step)
	if not poly or not poly[1] or not poly[1].y or span_step < 1 then
		return 0
	end
	local min_y = poly[1].y
	local max_y = min_y
	for i = 2, #poly do
		local py = poly[i].y
		if py < min_y then min_y = py end
		if py > max_y then max_y = py end
	end
	local y0 = math.floor(min_y / span_step) * span_step
	local y1 = math.ceil(max_y / span_step) * span_step
	if y1 <= y0 then
		return 0
	end
	return math.floor((y1 - y0) / span_step)
end

local function plan_fill(jobs, base_step, budget)
	local function measure(body_step, front_step)
		local rows = 0
		for i = 1, #jobs do
			local job = jobs[i]
			local span_step = job.fine and front_step or body_step
			rows = rows + poly_rows(job.poly, span_step)
		end
		return rows, rows * 2
	end
	local body = base_step
	if body ~= 1 and body ~= 2 and body ~= 4 then
		body = 2
	end
	local front = 1
	local rows, calls = measure(body, front)
	local degraded = false
	while (rows > budget.rows or calls > budget.calls) and body < 4 do
		if body == 1 then
			body = 2
		else
			body = 4
		end
		if front < 2 then
			front = 2
		end
		degraded = true
		rows, calls = measure(body, front)
	end
	local over = rows > budget.rows or calls > budget.calls
	return body, front, rows, calls, degraded, over
end

function renderer.draw(built, cfg, stream_points)
	local step = begin_frame(cfg)
	local sp = ensure()
	if sp then
		if cfg and cfg.renderer_backend == "sprite_scanline_composited" then
			renderer.backend = "sprite_scanline_composited"
		else
			renderer.backend = "sprite_scanline"
		end
	end
	if sp and built then
		renderer.keep_paint = true
		local budget = {
			rows = cfg.max_raster_rows or 420,
			calls = 2400,
		}
		if cfg.renderer_backend == "sprite_scanline_composited" then
			draw_composited(sp, built, cfg, step, budget)
		else
		local jobs = {}
		for layer = 1, #ORDER do
			local key = ORDER[layer]
			local region = built[key]
			if region and visible(cfg, key) then
				each_span(region, function(a, b)
					local mark = region.upper and region.upper[a]
					local block, slot, want_edges = note_span_mark(cfg, key, mark, a)
					local bypass = cfg.fill_skip_diag == true
					local t_project = nano()
					local ok, poly, why = pcall(polygon_from, region.upper, region.lower, a, b, region.caps)
					if t_project then
						renderer.screen_projection_ns = (renderer.screen_projection_ns or 0) + (Isaac.GetNanoTime() - t_project)
					end
					if not ok or not poly then
						slot.polygon_failed = slot.polygon_failed + 1
						if why == "nan" then
							renderer.invalid_intersection_count = renderer.invalid_intersection_count + 1
						end
						if not ok then
							note_error("project", poly)
							attach_fill_span(key, a, nil, "project")
						else
							attach_fill_span(key, a, nil, why or "empty")
						end
						if block then
							renderer.self_intersection_count = (renderer.self_intersection_count or 0) + 1
							renderer.geometry_skip_count = (renderer.geometry_skip_count or 0) + 1
						end
						return
					end
					if why == "nan" then
						slot.polygon_failed = slot.polygon_failed + 1
						renderer.invalid_intersection_count = renderer.invalid_intersection_count + 1
						attach_fill_span(key, a, nil, "nan")
						return
					end
					poly.id = (renderer.polygon_serial or 0) + 1
					renderer.polygon_serial = poly.id
					poly.closed = true
					poly.segment_id = mark and mark.segment_id
					poly.coverage_key = key
					if key == "outer" and poly.segment_id and poly[1] then
						local boxes = renderer.segment_poly or {}
						renderer.segment_poly = boxes
						local box = boxes[poly.segment_id]
						for pi = 1, #poly do
							local point = poly[pi]
							local px, py = point.x, point.y
							if not box then
								box = { min_x = px, max_x = px, min_y = py, max_y = py, n = 1 }
								boxes[poly.segment_id] = box
							else
								if px < box.min_x then box.min_x = px end
								if px > box.max_x then box.max_x = px end
								if py < box.min_y then box.min_y = py end
								if py > box.max_y then box.max_y = py end
								box.n = box.n + 1
							end
						end
					end
					renderer.region_vertex_count = (renderer.region_vertex_count or 0) + #poly
					if want_edges then
						attach_fill_span(key, a, first_cross_pair(poly), nil)
					end
					local skip = block
					if skip then
						renderer.self_intersection_count = (renderer.self_intersection_count or 0) + 1
						renderer.geometry_skip_count = (renderer.geometry_skip_count or 0) + 1
						remember_odd(key, 0, { id = a, self_hit = true, fold_count = mark and mark.fold_count or 0 }, {}, "self_intersection")
					elseif cfg.audit_screen == true then
						local folds, self_hit = classify_polygon(poly)
						poly.fold_count = folds
						poly.self_hit = self_hit
						renderer.local_fold_count = (renderer.local_fold_count or 0) + folds
						if self_hit then
							attach_fill_span(key, a, first_cross_pair(poly), bypass and "screen_self_intersection_bypassed" or "screen_self_intersection")
							if not bypass then
								skip = true
								slot.audit_skipped = slot.audit_skipped + 1
								renderer.self_intersection_count = (renderer.self_intersection_count or 0) + 1
								renderer.geometry_skip_count = (renderer.geometry_skip_count or 0) + 1
								remember_odd(key, 0, poly, {}, "self_intersection")
							end
						end
					end
					if not skip then
						jobs[#jobs + 1] = {
							poly = poly,
							key = key,
							region = region,
							fine = mark and mark.fine or false,
							span_index = a,
						}
					end
				end)
			end
		end
		local body_step, front_step, est_rows, est_calls, degraded, over = plan_fill(jobs, step, budget)
		renderer.raster_rows_estimate = est_rows
		renderer.raster_calls_estimate = est_calls
		renderer.raster_step_used = body_step
		renderer.raster_front_step = front_step
		renderer.raster_degraded = degraded
		renderer.raster_over_soft_budget = over
		for ji = 1, #jobs do
			local job = jobs[ji]
			local slot = layer_slot(job.key)
			local sprite_before = renderer.sprite_submit_ns or 0
			local t_fill = nano()
			local use_step = job.fine and front_step or body_step
			local intervals_before = renderer.raster_intervals or 0
			local odd_before = renderer.odd_intersection_count or 0
			local filled, err = pcall(fill_polygon, sp, job.poly, use_step, job.region, budget, cfg.show_segments == true)
			slot.rasterized = slot.rasterized + 1
			local added = (renderer.raster_intervals or 0) - intervals_before
			slot.raster_intervals = slot.raster_intervals + added
			local src = job.region
			local sid = src and src.upper and src.upper[job.span_index] and src.upper[job.span_index].segment_id
			if sid then
				renderer.segment_intervals = renderer.segment_intervals or {}
				renderer.segment_raster_skips = renderer.segment_raster_skips or {}
				renderer.segment_intervals[sid] = (renderer.segment_intervals[sid] or 0) + added
				if not filled then
					renderer.segment_raster_skips[sid] = (renderer.segment_raster_skips[sid] or 0) + 1
				end
			end
			if (renderer.odd_intersection_count or 0) > odd_before then
				attach_fill_span(job.key, job.span_index, nil, "odd")
			end
			if t_fill then
				local spent = Isaac.GetNanoTime() - t_fill
				local sprite_spent = (renderer.sprite_submit_ns or 0) - sprite_before
				renderer.scanline_fill_ns = (renderer.scanline_fill_ns or 0) + spent - sprite_spent
			end
			if not filled then
				slot.polygon_failed = slot.polygon_failed + 1
				note_error("scanline", err)
				attach_fill_span(job.key, job.span_index, nil, "scanline")
			end
		end
		end
	end
	renderer.keep_paint = false
	if cfg.show_boundaries and built and Isaac.DrawLine then
		local bound_color = {
			outer = KColor(0.72, 0.18, 0.08, 0.95),
			orange = KColor(1, 0.48, 0.12, 0.95),
			gold = KColor(1, 0.82, 0.25, 0.95),
			white = KColor(1, 0.96, 0.78, 0.95),
		}
		for layer = 1, #ORDER do
			local key = ORDER[layer]
			local region = built[key]
			if region and visible(cfg, key) then
				local col = bound_color[key]
				draw_chain_lines(region.upper, col)
				draw_chain_lines(region.lower, col)
				if region.caps and region.upper and region.lower then
					for index, cap in pairs(region.caps) do
						local prev = region.upper[index]
						if prev and prev.x and cap then
							local screen = screen_of(prev)
							for ci = 1, #cap do
								local nxt = screen_of(cap[ci])
								Isaac.DrawLine(screen, nxt, col, col, 1)
								screen = nxt
							end
							local tail = region.lower[index]
							if tail and tail.x then
								Isaac.DrawLine(screen, screen_of(tail), col, col, 1)
							end
						end
					end
				end
			end
		end
	end
	if cfg.show_stream and stream_points and Isaac.DrawLine then
		local col = KColor(1, 1, 1, 0.8)
		for n = 1, #stream_points do
			local chain = stream_points[n]
			local prev = nil
			for i = 1, #chain do
				local screen = screen_of(chain[i])
				if prev then
					Isaac.DrawLine(prev, screen, col, col, 1)
				end
				prev = screen
			end
		end
	end
	return renderer.sprite_draw_calls
end

return renderer
