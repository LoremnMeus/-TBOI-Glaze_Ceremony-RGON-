-- Region fill first. Detached sparks are optional and never fill the column.

local C = require("Qing_Remaster_scripts.items.incandescence_flame.constants")
local region_renderer = require("Qing_Remaster_scripts.items.incandescence_flame.flame_region_renderer")
local stream = require("Qing_Remaster_scripts.items.incandescence_flame.flame_stream")

local visual = {}
local sprite = nil
local loaded = false

local ORB_ANIM = { small = "Orb3", medium = "Orb5", large = "Orb7", xlarge = "Orb9" }
local ORB_SCALE = { small = 1, medium = 1.4, large = 1.7, xlarge = 2 }

local function ensure()
	if loaded then
		return sprite
	end
	loaded = true
	sprite = Sprite()
	sprite:Load(C.ORB_ANM2, true)
	return sprite
end

local RING = 1800
local ring = {}
local ring_n = 0
local ring_i = 0
local since_sort = 0
local last_render_ns = nil
local seen_session = nil

local function sparks_on(cfg)
	if not cfg or cfg.static_solid then
		return false
	end
	local profile = cfg.perf_profile or "normal"
	if profile == "layers_particles" or profile == "stress" then
		return true
	end
	if profile == "sim_only" or profile == "orange" or profile == "layers" then
		return false
	end
	if cfg.show_ember ~= true then
		return false
	end
	local test = cfg.color_test or "all"
	return test == "all" or test == "particles"
end

local function view_cfg(cfg)
	local profile = cfg.perf_profile or "normal"
	if profile == "orange" then
		return setmetatable({ color_test = "orange" }, { __index = cfg })
	end
	if profile == "layers" or profile == "layers_particles" or profile == "stress" then
		return setmetatable({
			color_test = "all",
			show_outer = true,
			show_orange = true,
			show_gold = true,
			show_white = true,
		}, { __index = cfg })
	end
	return cfg
end

local function note_interval(state, cfg)
	if not Isaac.GetNanoTime then
		state.frame_time_p50 = "unverified"
		state.frame_time_p95 = "unverified"
		state.frame_time_max = "unverified"
		state.frame_time_source = "GetNanoTime missing"
		return
	end
	if cfg and cfg.perf_stats == false then
		return
	end
	if state.id ~= seen_session then
		ring = {}
		ring_n = 0
		ring_i = 0
		since_sort = 0
		last_render_ns = nil
		seen_session = state.id
	end
	local now = Isaac.GetNanoTime()
	if last_render_ns then
		ring_i = ring_i % RING + 1
		ring[ring_i] = (now - last_render_ns) / 1000
		if ring_n < RING then
			ring_n = ring_n + 1
		end
		since_sort = since_sort + 1
		if since_sort >= 90 and ring_n > 0 then
			since_sort = 0
			local copy = {}
			local start = ring_i - ring_n + 1
			for n = 0, ring_n - 1 do
				local idx = (start + n - 1) % RING + 1
				copy[n + 1] = ring[idx]
			end
			table.sort(copy)
			local function pick(p)
				local idx = math.floor((#copy - 1) * p) + 1
				if idx < 1 then idx = 1 end
				if idx > #copy then idx = #copy end
				return copy[idx]
			end
			state.frame_time_p50 = pick(0.5)
			state.frame_time_p95 = pick(0.95)
			state.frame_time_max = copy[#copy]
			state.frame_time_source = "POST_RENDER interval us"
		end
	end
	last_render_ns = now
end

local function heat_color(heat, alpha)
	if heat > 0.82 then
		return Color(1, 0.95, 0.67, alpha)
	end
	if heat > 0.62 then
		return Color(1, 0.75, 0.18, alpha)
	end
	if heat > 0.4 then
		return Color(1, 0.47, 0.13, alpha)
	end
	return Color(0.72, 0.23, 0.1, alpha)
end

local function draw_orb(sp, p, cfg)
	local kind = p.kind or p.role or "medium"
	local anim = ORB_ANIM[kind] or "Orb5"
	local scale = ORB_SCALE[kind] or 1.4
	if cfg and cfg.orb_uniform then
		anim = "Orb3"
		scale = 1
	end
	scale = scale * ((cfg and cfg.orb_scale) or 1)
	sp:Play(anim, true)
	sp:SetFrame(anim, 0)
	local t = 0
	if p.life and p.life > 0 then
		t = p.age / p.life
	end
	if t < 0 then t = 0 end
	if t > 1 then t = 1 end
	local emerge = p.emergence or 0
	if emerge < 0 then emerge = 0 end
	if emerge > 1 then emerge = 1 end
	local grow = 0.38 + 0.62 * emerge
	scale = scale * grow
	local hold = p.hold or 0.55
	if emerge >= 1 and t > hold then
		local u = (t - hold) / (1 - hold)
		scale = scale * (1 - 0.7 * u)
	end
	local alpha = 0.45 + 0.55 * emerge
	if t > 0.72 then
		alpha = alpha * (1 - t) / 0.28
	end
	if alpha < 0 then alpha = 0 end
	sp.Color = heat_color(p.temperature or p.temp0 or 0.45, alpha)
	sp.Scale = Vector(scale, scale)
	sp.Rotation = 0
	sp:Render(region_renderer.world_to_screen(p.x, p.y), Vector(0, 0), Vector(0, 0))
end

local function copy_stats(state, drawn)
	state.render_primitive_count = drawn or 0
	state.raster_rows = region_renderer.raster_rows or 0
	state.raster_intervals = region_renderer.raster_intervals or 0
	state.sprite_draw_calls = region_renderer.sprite_draw_calls or 0
	state.invalid_intersection_count = region_renderer.invalid_intersection_count or 0
	state.odd_intersection_count = region_renderer.odd_intersection_count or 0
	state.raster_budget_clamped = region_renderer.raster_budget_clamped == true
	state.odd_scanline_capture = region_renderer.last_odd_scanline
	state.odd_scanlines = region_renderer.odd_scanlines or {}
	state.geometry_skip_count = region_renderer.geometry_skip_count or 0
	state.self_intersection_count = region_renderer.self_intersection_count or 0
	state.fill_layers = region_renderer.fill_layers or {}
	state.fill_spans = region_renderer.fill_spans or {}
	state.coverage_rows = region_renderer.coverage_rows or 0
	state.raster_rows_estimate = region_renderer.raster_rows_estimate or 0
	state.raster_calls_estimate = region_renderer.raster_calls_estimate or 0
	state.raster_step_used = region_renderer.raster_step_used or 0
	state.raster_front_step = region_renderer.raster_front_step or 0
	state.raster_degraded = region_renderer.raster_degraded == true
	state.raster_over_soft_budget = region_renderer.raster_over_soft_budget == true
	state.raster_clamp_layer = region_renderer.raster_clamp_layer
	state.raster_clamp_y = region_renderer.raster_clamp_y
	state.local_fold_count = region_renderer.local_fold_count or 0
	local function us(ns)
		if not region_renderer.timer_ready then
			return nil
		end
		return (ns or 0) / 1000
	end
	state.screen_projection_us = us(region_renderer.screen_projection_ns)
	state.scanline_fill_us = us(region_renderer.scanline_fill_ns)
	state.sprite_submit_us = us(region_renderer.sprite_submit_ns)
	state.region_vertex_count = region_renderer.region_vertex_count or 0
	state.scanline_edge_tests = region_renderer.scanline_edge_tests or 0
	state.active_edge_peak = region_renderer.active_edge_peak or 0
	state.active_edge_table = false
	state.segment_raster = region_renderer.segment_intervals or {}
	state.segment_raster_skips = region_renderer.segment_raster_skips or {}
	state.render_ran = true
	state.scanline_intervals_before = region_renderer.intervals_before or 0
	state.scanline_intervals_after = region_renderer.intervals_after or 0
end

local function mark_world(x, y, col)
	if not x or not Isaac.DrawLine or not Isaac.WorldToScreen then
		return
	end
	local s = region_renderer.world_to_screen(x, y)
	Isaac.DrawLine(Vector(s.X - 5, s.Y), Vector(s.X + 5, s.Y), col, col, 1)
	Isaac.DrawLine(Vector(s.X, s.Y - 5), Vector(s.X, s.Y + 5), col, col, 1)
end

local function player_anchor()
	if not Isaac.GetPlayer then
		return nil
	end
	local player = Isaac.GetPlayer(0)
	if player and player.Position then
		return { x = player.Position.X, y = player.Position.Y }
	end
	return nil
end

local function heat_block(x, y, heat, tracked)
	if not Isaac.WorldToScreen or not Isaac.DrawLine then
		return
	end
	local screen = region_renderer.world_to_screen(x, y)
	local t = heat or 0
	if t < 0 then t = 0 end
	if t > 1 then t = 1 end
	local col = KColor(0.28 + 0.72 * t, 0.04 + 0.9 * t * t, 0.02 + 0.45 * t * t * t, tracked and 1 or 0.8)
	local half = tracked and 4 or 3
	Isaac.DrawLine(Vector(screen.X - half, screen.Y - 1), Vector(screen.X + half, screen.Y - 1), col, col, 2)
	Isaac.DrawLine(Vector(screen.X - half, screen.Y + 1), Vector(screen.X + half, screen.Y + 1), col, col, 2)
end

local function draw_heat_field(state)
	local list = state.stream
	if not list or not stream.sample_world then
		return
	end
	local tracked = state.tracked_slice_id
	local order = { 1, 2, 3, 4, 9, 8, 7, 6, 5 }
	for pass = 1, 2 do
		for n = 1, #list do
			local slice = list[n]
			local marked = slice.id == tracked
			local show = slice.temp_profile and ((pass == 1 and not marked) or (pass == 2 and marked))
			if show then
				for k = 1, #order do
					local index = order[k]
					local x, y = stream.sample_world(slice, index)
					heat_block(x, y, slice.temp_profile[index], marked)
				end
				if marked and slice.x and Isaac.WorldToScreen then
					local screen = region_renderer.world_to_screen(slice.x, slice.y)
					if Isaac.RenderText then
						Isaac.RenderText(tostring(slice.id), screen.X + 8, screen.Y - 12, 1, 0.95, 0.7, 1)
					end
					if slice.ox and Isaac.DrawLine then
						local born = region_renderer.world_to_screen(slice.ox, slice.oy)
						local col = KColor(0.55, 0.9, 1, 0.9)
						Isaac.DrawLine(born, screen, col, col, 1)
					end
				end
			end
		end
	end
end

local function face_painted(slice, rects)
	if not rects or #rects == 0 or not slice.x or not Isaac.WorldToScreen then
		return false
	end
	local bx = slice.birth_dx or slice.dx or 1
	local by = slice.birth_dy or slice.dy or 0
	local len = math.sqrt(bx * bx + by * by)
	local nx, ny = 0, 1
	if len > 0.001 then
		nx, ny = -by / len, bx / len
	end
	local reach = 6
	local pts = {
		{ slice.x, slice.y },
		{ slice.x + nx * reach, slice.y + ny * reach },
		{ slice.x - nx * reach, slice.y - ny * reach },
	}
	for p = 1, 3 do
		local screen = region_renderer.world_to_screen(pts[p][1], pts[p][2])
		local px, py = screen.X, screen.Y
		for r = 1, #rects do
			local rect = rects[r]
			if px >= rect.x - 2 and px < rect.x + rect.w + 2 and py >= rect.y - 2 and py < rect.y + rect.h + 2 then
				return true
			end
		end
	end
	return false
end

local function section_lengths(state, rects)
	local groups = {}
	local order = {}
	local list = state.stream or {}
	for i = 1, #list do
		local slice = list[i]
		local id = slice.segment_id
		if id then
			local group = groups[id]
			if not group then
				group = { segment_id = id, slices = {} }
				groups[id] = group
				order[#order + 1] = id
			end
			group.slices[#group.slices + 1] = slice
		end
	end
	table.sort(order)
	local out = {}
	for n = 1, #order do
		local group = groups[order[n]]
		local slices = group.slices
		local axis = "arc_s"
		for i = 1, #slices do
			if slices[i].release_s ~= nil then
				axis = "release_s"
				break
			end
		end
		local near, far = nil, nil
		local painted = {}
		for i = 1, #slices do
			local slice = slices[i]
			local s = axis == "release_s" and (slice.release_s or 0) or (slice.arc_s or 0)
			s = math.floor(s + 0.5)
			if not near or s < near then
				near = s
			end
			if not far or s > far then
				far = s
			end
			if face_painted(slice, rects) then
				painted[#painted + 1] = s
			end
		end
		table.sort(painted)
		local runs = {}
		local run_a, prev = nil, nil
		for i = 1, #painted do
			local s = painted[i]
			if not run_a then
				run_a = s
				prev = s
			elseif s - prev > 32 then
				runs[#runs + 1] = { run_a, prev }
				run_a = s
				prev = s
			else
				prev = s
			end
		end
		if run_a then
			runs[#runs + 1] = { run_a, prev }
		end
		out[#out + 1] = {
			segment_id = group.segment_id,
			sections = #slices,
			axis = axis,
			extent = { near or 0, far or 0 },
			drawn_sections = #painted,
			drawn = runs,
		}
	end
	return out
end

local function fill_bounds(state)
	local built = state.region_build
	local vis = built and built.segment_vis or {}
	local cover = region_renderer.segment_coverage or {}
	local polys = region_renderer.segment_poly or {}
	local seen = {}
	local ids = {}
	local function add_id(id)
		if id and not seen[id] then
			seen[id] = true
			ids[#ids + 1] = id
		end
	end
	for id in pairs(vis) do
		add_id(id)
	end
	for id in pairs(cover) do
		add_id(id)
	end
	for id in pairs(polys) do
		add_id(id)
	end
	table.sort(ids)
	local function iround(v)
		return math.floor((v or 0) + 0.5)
	end
	local out = {}
	for n = 1, #ids do
		local id = ids[n]
		local slot = vis[id]
		local box = cover[id]
		local poly = polys[id]
		local paint = nil
		if box then
			paint = {
				x0 = iround(box.min_x),
				y0 = iround(box.min_y),
				x1 = iround(box.max_x),
				y1 = iround(box.max_y),
				span_min = iround(box.span_min),
				span_max = iround(box.span_max),
				spans = box.span_n or 0,
			}
		end
		local outline = nil
		if poly then
			outline = {
				x0 = iround(poly.min_x),
				y0 = iround(poly.min_y),
				x1 = iround(poly.max_x),
				y1 = iround(poly.max_y),
				verts = poly.n or 0,
			}
		end
		out[#out + 1] = {
			segment_id = id,
			emit = slot and slot.emit_runs or nil,
			poly = outline,
			paint = paint,
		}
	end
	return out
end

function visual.render(state, cfg)
	if not state or not cfg then
		return 0
	end
	local t0 = nil
	if Isaac.GetNanoTime then
		t0 = Isaac.GetNanoTime()
	end
	note_interval(state, cfg)
	local drawn = 0
	local profile = cfg.perf_profile or "normal"
	if profile == "sim_only" then
		drawn = 0
	elseif cfg.gate0_test then
		drawn = region_renderer.draw_gate0(player_anchor())
	else
		drawn = region_renderer.draw(state.region_build, view_cfg(cfg), state.stream_preview)
	end
	local rects = nil
	if profile ~= "sim_only" and not cfg.gate0_test then
		rects = region_renderer.paint_rects
	end
	state.section_lengths = section_lengths(state, rects)
	state.paint_rects_truncated = region_renderer.paint_rects_truncated == true
	state.fill_bounds = fill_bounds(state)
	if cfg.show_head and profile ~= "sim_only" and state.region_build and state.region_build.head then
		local head = state.region_build.head
		mark_world(head.tip_x, head.tip_y, KColor(1, 0.95, 0.55, 0.95))
		mark_world(head.upper_x, head.upper_y, KColor(1, 0.45, 0.12, 0.95))
		mark_world(head.lower_x, head.lower_y, KColor(1, 0.72, 0.2, 0.95))
		mark_world(head.break_x, head.break_y, KColor(0.85, 0.2, 0.12, 0.95))
	end
	if cfg.show_orb_birth and profile ~= "sim_only" and state.region_build and state.region_build.edge_samples and Isaac.WorldToScreen and Isaac.DrawLine then
		local samples = state.region_build.edge_samples
		local col = KColor(1, 0.85, 0.4, 0.7)
		for i = 1, #samples do
			local sample = samples[i]
			mark_world(sample.x, sample.y, col)
			local nx = sample.nx or 0
			local ny = sample.ny or 0
			local a = region_renderer.world_to_screen(sample.x, sample.y)
			local b = region_renderer.world_to_screen(sample.x + nx * 14, sample.y + ny * 14)
			Isaac.DrawLine(a, b, col, col, 1)
		end
	end
	if t0 and Isaac.GetNanoTime then
		state.region_draw_ns = Isaac.GetNanoTime() - t0
	else
		state.region_draw_ns = nil
	end
	copy_stats(state, drawn)
	if cfg.heat_view and not cfg.gate0_test then
		draw_heat_field(state)
	end
	if profile == "sim_only" then
		state.sprite_draw_calls = 0
		state.raster_rows = 0
		state.raster_intervals = 0
		state.screen_projection_us = 0
		state.scanline_fill_us = 0
		state.sprite_submit_us = 0
		state.scanline_edge_tests = 0
		state.region_vertex_count = 0
	end
	state.particle_draw_calls = 0
	if cfg.gate0_test or not sparks_on(cfg) or not state.ember then
		state.orb_render_us = 0
		return drawn
	end
	local orb_t0 = nil
	if Isaac.GetNanoTime then
		orb_t0 = Isaac.GetNanoTime()
	end
	local sp = ensure()
	if sp then
		for i = 1, #state.ember do
			local piece = state.ember[i]
			draw_orb(sp, piece, cfg)
			state.particle_draw_calls = state.particle_draw_calls + 1
			if cfg.show_orb_trace and piece.birth_x and Isaac.DrawLine and Isaac.WorldToScreen then
				local a = region_renderer.world_to_screen(piece.birth_x, piece.birth_y)
				local b = region_renderer.world_to_screen(piece.x, piece.y)
				local col = KColor(1, 0.55, 0.2, 0.65)
				Isaac.DrawLine(a, b, col, col, 1)
			end
		end
		sp.Color = Color(1, 1, 1, 1)
		sp.Scale = Vector(1, 1)
		sp.Rotation = 0
	end
	if orb_t0 and Isaac.GetNanoTime then
		state.orb_render_us = (Isaac.GetNanoTime() - orb_t0) / 1000
	else
		state.orb_render_us = 0
	end
	return drawn
end

return visual
