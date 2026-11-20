-- One spray session. Visual only: no damage, no item charge, no damage bonus.
-- Simulation advances on the 30 Hz probe update. Render does not move pieces.

local C = require("Qing_Remaster_scripts.items.incandescence_flame.constants")
local particles = require("Qing_Remaster_scripts.items.incandescence_flame.flame_particles")
local stream = require("Qing_Remaster_scripts.items.incandescence_flame.flame_stream")
local regions = require("Qing_Remaster_scripts.items.incandescence_flame.flame_regions")
local region_renderer = require("Qing_Remaster_scripts.items.incandescence_flame.flame_region_renderer")

local session = {}

local function default_cfg()
	return {
		length = C.LENGTH,
		half_width = C.HALF_WIDTH,
		mouth_width = C.MOUTH_WIDTH,
		flow = C.FLOW,
		density = 1,
		curl = 0.35,
		jet_frames = C.logic_frames(C.JET_SECONDS),
		afterglow_frames = C.logic_frames(C.AFTERGLOW_SECONDS),
		body_cap = C.BODY_CAP,
		core_cap = C.CORE_CAP,
		tongue_cap = C.TONGUE_CAP,
		ember_cap = C.EMBER_CAP,
		core_frac = C.CORE_FRAC,
		orange_frac = C.ORANGE_FRAC,
		gold_frac = C.GOLD_FRAC,
		white_frac = C.WHITE_FRAC,
		wave_large = C.WAVE_LARGE,
		wave_mid = C.WAVE_MID,
		wave_small = C.WAVE_SMALL,
		bulge_amp = C.BULGE_AMP,
		mid_amp = C.MID_AMP,
		edge_amp = C.EDGE_AMP,
		bulge_speed = C.BULGE_SPEED,
		bulge_count = C.BULGE_COUNT,
		head_curl = C.HEAD_CURL,
		tongue_density = C.TONGUE_DENSITY,
		spacing = C.SPACING,
		turn_extent = C.TURN_EXTENT,
		closed_tip_width_scale = C.CLOSED_TIP_WIDTH_SCALE,
		stream_cap = C.STREAM_CAP,
		hard_stream_cap = C.HARD_STREAM_CAP,
		segment_cap = C.SEGMENT_CAP,
		mid_segment_cap = C.MID_SEGMENT_CAP,
		hard_segment_cap = C.HARD_SEGMENT_CAP,
		show_outer = true,
		show_orange = true,
		show_gold = true,
		show_white = true,
		show_ember = true,
		show_boundaries = false,
		show_segments = false,
		show_stream = false,
		static_solid = false,
		gate0_test = false,
		branch_cap = 3,
		show_head = false,
		show_orb_birth = false,
		show_orb_trace = false,
		orb_uniform = false,
		birth_depth = 10,
		emerge_frames = 6,
		orb_scale = 1,
		perf_stats = false,
		perf_profile = "normal",
		renderer_backend = "sprite_scanline",
		front_reach = 1,
		front_bloom = 1,
		front_asym = 0.35,
		layer_wave = 1,
		layer_margin = 1.5,
		fill_skip_diag = false,
		cap_multi_peak = false,
		heat_view = false,
		heat_regions = true,
		orb_rate = 3,
		shed_rate = 1.15,
		front_rate = 0.6,
		bulge_cool = 10,
		orb_large = 0.18,
		front_scatter = 1.4,
		edge_scatter = 1.6,
		orb_life = 1,
		audit_screen = false,
		scanline_height = 2,
		max_raster_rows = 420,
		color_test = "all",
		lock_origin = false,
		forced_dir = nil,
	}
end

local cfg = default_cfg()

local function blank_state()
	return {
		id = 0,
		phase = "idle",
		emitting = false,
		continuous = false,
		frozen = false,
		step_once = false,
		origin = { x = 0, y = 0 },
		dir = { x = 1, y = 0 },
		head = 0,
		time = 0,
		emit_left = 0,
		afterglow = 0,
		serial = 1,
		body = {},
		core = {},
		tongue = {},
		ember = {},
		curves = {},
		stream = {},
		fade_cut = 0,
		stream_peak = 0,
		stream_discontinuity_count = 0,
		region_build = nil,
		stream_preview = nil,
		render_primitive_count = 0,
		region_draw_ns = nil,
		boundary_jump = {},
		prev_widths = nil,
		spawned = 0,
		recycled = 0,
		nan_count = 0,
		budget_clamped = false,
		gap_frames = 0,
		jump_count = 0,
		silhouette_jump = 0,
		prev_head = 0,
		prev_env = nil,
		centerline_occupancy = 1,
		cross_section_coverage = 1,
		core_continuity = 1,
		detached_tongue_count = 0,
		offscreen = 0,
	}
end

local state = blank_state()
local heat_memory = {}

local function remember_heat(reason)
	if not state.tracked_slice_id then
		return
	end
	local end_reason = reason or "cleared"
	if not state.heat_track_alive and state.heat_track_end then
		end_reason = state.heat_track_end
	end
	heat_memory = {
		tracked_id = state.tracked_slice_id,
		alive = false,
		end_reason = end_reason,
		travelled_distance = state.heat_travelled or 0,
		age = state.heat_age or 0,
		temperature_min = state.heat_tmin or 0,
		temperature_max = state.heat_tmax or 0,
		heat_center_offset = state.heat_center or 0,
		heat_spread = state.heat_spread or 0,
		temperature_update_us = state.temperature_update_us,
		active_slice_count = state.active_slice_count or 0,
		x = state.heat_x,
		y = state.heat_y,
		seed = state.heat_seed,
		shift = state.heat_shift,
		drift = state.heat_drift_value,
		profile = state.heat_profile,
		trail = state.heat_trail,
	}
end

local function unit(x, y)
	local len = math.sqrt(x * x + y * y)
	if len < 0.0001 then
		return nil
	end
	return { x = x / len, y = y / len }
end

local remembered_dir = nil
local item_owner = false

local function remember_dir(d)
	if d and d.x then
		remembered_dir = { x = d.x, y = d.y }
	end
end

local function player_dir(player)
	if cfg.forced_dir then
		return cfg.forced_dir
	end
	if player and player.GetAimDirection then
		local aim = player:GetAimDirection()
		if aim then
			local d = unit(aim.X or 0, aim.Y or 0)
			if d then
				remember_dir(d)
				return d
			end
		end
	end
	if state.dir and unit(state.dir.x or 0, state.dir.y or 0) then
		return state.dir
	end
	if remembered_dir and unit(remembered_dir.x or 0, remembered_dir.y or 0) then
		return remembered_dir
	end
	return { x = 1, y = 0 }
end

local function player_origin(player, dir)
	local pos = player.Position
	return {
		x = pos.X + dir.x * 16,
		y = pos.Y - 18 + dir.y * 16,
	}
end

function session.config()
	return cfg
end

function session.state()
	return state
end

function session.restore_defaults()
	local frozen = state.frozen
	cfg = default_cfg()
	state.frozen = frozen
end

function session.set_dir(x, y)
	local d = unit(x, y)
	if d then
		cfg.forced_dir = d
		state.dir = d
		remember_dir(d)
	end
end

function session.note_dir(x, y)
	local d = unit(x, y)
	if d then
		remember_dir(d)
		state.dir = { x = d.x, y = d.y }
	end
end

function session.clear_forced_dir()
	cfg.forced_dir = nil
end

function session.draws_behind_player()
	local dir = state.dir
	return dir ~= nil and (dir.y or 0) < 0
end

function session.set_item_owner(on)
	item_owner = on == true
end

function session.item_owner()
	return item_owner
end

function session.set_lock_origin(on)
	cfg.lock_origin = on == true
end

function session.set_layer(name, on)
	local value = on == true
	if name == "outer" then cfg.show_outer = value end
	if name == "orange" or name == "body" then cfg.show_orange = value end
	if name == "gold" or name == "core" then cfg.show_gold = value end
	if name == "white" then cfg.show_white = value end
	if name == "ember" then cfg.show_ember = value end
	if name == "boundaries" or name == "geometry" then cfg.show_boundaries = value end
	if name == "segments" then cfg.show_segments = value end
	if name == "stream" then cfg.show_stream = value end
	if name == "static" then cfg.static_solid = value end
	if name == "gate0" then cfg.gate0_test = value end
	if name == "head" then cfg.show_head = value end
	if name == "orb_birth" then cfg.show_orb_birth = value end
	if name == "orb_trace" then cfg.show_orb_trace = value end
	if name == "orb_uniform" then cfg.orb_uniform = value end
	if name == "perf_stats" then cfg.perf_stats = value end
	if name == "audit_screen" then cfg.audit_screen = value end
	if name == "fill_skip_diag" then cfg.fill_skip_diag = value end
	if name == "cap_multi_peak" then cfg.cap_multi_peak = value end
	if name == "heat_view" then cfg.heat_view = value end
	if name == "width_regions" then
		cfg.heat_regions = not value
		state.rebuild_visual = true
	end
end

function session.arm_heat_track()
	stream.arm_heat_track(state)
end

function session.layer_override_text()
	local profile = cfg.perf_profile or "normal"
	if profile == "sim_only" then
		return "性能对照是「只模拟」，四个色层复选框不会产生填充。"
	end
	if profile == "orange" then
		return "性能对照是「只橙色」，四个色层复选框被覆盖，实际只画橙色主体。"
	end
	if profile == "layers" or profile == "layers_particles" or profile == "stress" then
		return "性能对照正在强制四层都显示，四个色层复选框当前不生效。"
	end
	if (cfg.color_test or "all") ~= "all" then
		return "颜色层不是「全部」，四个色层复选框被覆盖。请改回「全部」再逐层开关。"
	end
	return "四个色层复选框当前直接控制填充。颜色层保持「全部」，性能对照保持「正常」。"
end

function session.set_renderer_backend(name)
	if name == "sprite_scanline" or name == "sprite_scanline_composited" then
		cfg.renderer_backend = name
	end
end

function session.set_perf_profile(name)
	local allowed = {
		normal = true,
		sim_only = true,
		orange = true,
		layers = true,
		layers_particles = true,
		stress = true,
	}
	if allowed[name] then
		cfg.perf_profile = name
	end
end

function session.set_color_test(mode)
	local map = {
		all = "all",
		outer = "outer",
		orange = "orange",
		gold = "gold",
		white = "white",
		particles = "particles",
		body = "orange",
		core = "gold",
		tongue = "outer",
		ember = "particles",
	}
	if map[mode] then
		cfg.color_test = map[mode]
	end
end

function session.set_number(key, value)
	local n = tonumber(value)
	if not n then
		return
	end
	if key == "length" then cfg.length = math.max(40, n) end
	if key == "half_width" then cfg.half_width = math.max(8, n) end
	if key == "flow" then cfg.flow = math.max(1, n) end
	if key == "density" then cfg.density = math.max(0.2, math.min(2, n)) end
	if key == "curl" then cfg.curl = math.max(0, math.min(1.5, n)) end
	if key == "jet_seconds" then cfg.jet_frames = C.logic_frames(n) end
	if key == "body_cap" then cfg.body_cap = math.floor(math.max(10, n)) end
	if key == "core_cap" then cfg.core_cap = math.floor(math.max(8, n)) end
	if key == "tongue_cap" then cfg.tongue_cap = math.floor(math.max(0, n)) end
	if key == "ember_cap" then cfg.ember_cap = math.floor(math.max(0, n)) end
	if key == "core_frac" then cfg.core_frac = math.max(0.35, math.min(0.55, n)) end
	if key == "orange_frac" then cfg.orange_frac = math.max(0.62, math.min(0.90, n)) end
	if key == "gold_frac" then cfg.gold_frac = math.max(0.28, math.min(0.62, n)) end
	if key == "white_frac" then cfg.white_frac = math.max(0.03, math.min(0.16, n)) end
	if key == "wave_large" then cfg.wave_large = math.max(0, math.min(1, n)) end
	if key == "wave_mid" then cfg.wave_mid = math.max(0, math.min(0.6, n)) end
	if key == "wave_small" then cfg.wave_small = math.max(0, math.min(0.3, n)) end
	if key == "bulge_amp" then cfg.bulge_amp = math.max(0.10, math.min(0.22, n)) end
	if key == "mid_amp" then cfg.mid_amp = math.max(0.04, math.min(0.10, n)) end
	if key == "edge_amp" then cfg.edge_amp = math.max(0.01, math.min(0.03, n)) end
	if key == "bulge_speed" then cfg.bulge_speed = math.max(8, math.min(15, n)) end
	if key == "bulge_count" then cfg.bulge_count = math.floor(math.max(3, math.min(5, n)) + 0.5) end
	if key == "head_curl" then cfg.head_curl = math.max(0, math.min(1, n)) end
	if key == "tongue_density" then cfg.tongue_density = math.max(0, math.min(1, n)) end
	if key == "spacing" then cfg.spacing = math.max(3, math.min(12, n)) end
	if key == "turn_extent" then cfg.turn_extent = math.max(32, math.min(240, n)) end
	if key == "closed_tip_width_scale" then cfg.closed_tip_width_scale = math.max(0.5, math.min(1, n)) end
	if key == "stream_cap" then cfg.stream_cap = math.floor(math.max(16, math.min(400, n))) end
	if key == "scanline_height" then
		local h = math.floor(n + 0.5)
		if h <= 1 then
			cfg.scanline_height = 1
		elseif h <= 2 then
			cfg.scanline_height = 2
		else
			cfg.scanline_height = 4
		end
	end
	if key == "max_raster_rows" then cfg.max_raster_rows = math.floor(math.max(80, math.min(1600, n))) end
	if key == "front_reach" then cfg.front_reach = math.max(0, math.min(2, n)) end
	if key == "front_bloom" then cfg.front_bloom = math.max(0, math.min(2, n)) end
	if key == "front_asym" then cfg.front_asym = math.max(0, math.min(1, n)) end
	if key == "layer_wave" then cfg.layer_wave = math.max(0, math.min(2, n)) end
	if key == "layer_margin" then cfg.layer_margin = math.max(0, math.min(4, n)) end
	if key == "orb_rate" then cfg.orb_rate = math.floor(math.max(0, math.min(12, n)) + 0.5) end
	if key == "orb_large" then cfg.orb_large = math.max(0, math.min(0.6, n)) end
	if key == "front_scatter" then cfg.front_scatter = math.max(0, math.min(3, n)) end
	if key == "edge_scatter" then cfg.edge_scatter = math.max(0, math.min(3, n)) end
	if key == "orb_life" then cfg.orb_life = math.max(0.4, math.min(2, n)) end
	if key == "birth_depth" then cfg.birth_depth = math.max(2, math.min(28, n)) end
	if key == "emerge_frames" then cfg.emerge_frames = math.floor(math.max(2, math.min(12, n)) + 0.5) end
	if key == "orb_scale" then cfg.orb_scale = math.max(0.5, math.min(2, n)) end
end

local function begin(player, continuous)
	if not player then
		return false
	end
	if state.tracked_slice_id then
		remember_heat("new_spray")
	end
	local armed = state.heat_arm == true
	state.tracked_slice_id = nil
	state.heat_trail = {}
	state.heat_track_alive = false
	state.heat_track_end = nil
	state.heat_arm = armed
	local dir = player_dir(player)
	state.id = state.id + 1
	state.phase = "spray"
	state.emitting = true
	state.continuous = continuous == true
	state.dir = dir
	state.origin = player_origin(player, dir)
	state.locked_origin = cfg.lock_origin and { x = state.origin.x, y = state.origin.y } or nil
	state.head = cfg.mouth_width
	state.time = 0
	state.emit_left = cfg.jet_frames
	state.afterglow = 0
	state.serial = state.serial + 1
	state.body = {}
	state.core = {}
	state.tongue = {}
	state.ember = {}
	state.curves = {}
	stream.clear(state)
	state.region_build = nil
	state.stream_preview = nil
	state.prev_widths = nil
	state.boundary_jump = {}
	state.prev_head_x = nil
	state.prev_head_y = nil
	state.head_position_delta = 0
	state.tail_recession = 0
	state.stream_motion_valid = false
	state.tongue_detached_count = 0
	state.spark_sources = { flame = 0, spark = 0, cinder = 0, smoke = 0 }
	region_renderer.reset_errors()
	state.spawned = 0
	state.recycled = 0
	state.orb_acc = { shed = 0, front = 0 }
	state.edge_prev = {}
	state.bulge_cool = {}
	state.source_lost = 0
	state.spawn_attempted = 0
	state.spawn_accepted = 0
	state.spawn_rejected = 0
	state.bulge_events = 0
	state.budget_clamped = false
	state.gap_frames = 0
	state.silhouette_jump = 0
	state.prev_head = state.head
	state.prev_env = nil
	state.centerline_occupancy = 1
	state.cross_section_coverage = 1
	state.core_continuity = 1
	state.detached_tongue_count = 0
	return true
end

function session.fire_once(player)
	return begin(player, false)
end

function session.fire_continuous(player)
	return begin(player, true)
end

function session.stop()
	if state.emitting then
		state.input_release_count = (state.input_release_count or 0) + 1
		state.emitting = false
		state.continuous = false
		state.afterglow = cfg.afterglow_frames
		state.phase = "fade"
	end
end

function session.clear(reason)
	remember_heat(reason or "cleared")
	local id = state.id
	local frozen = state.frozen
	state = blank_state()
	state.id = id
	state.frozen = frozen
	state.phase = "idle"
end

function session.set_frozen(on)
	state.frozen = on == true
end

function session.step()
	state.step_once = true
end

local function refresh_source(player)
	if not player then
		return
	end
	state.dir = player_dir(player)
	if not cfg.lock_origin then
		state.origin = player_origin(player, state.dir)
	elseif state.locked_origin then
		state.origin = state.locked_origin
	end
end

local JUMP_KEYS = { "outer", "orange", "gold", "white" }

local function note_boundary_jumps(built)
	local prev = state.prev_widths
	local stored = {}
	for i = 1, #JUMP_KEYS do
		local key = JUMP_KEYS[i]
		local now = built.widths[key] or {}
		stored[key] = now
		local old = prev and prev[key]
		if old and #old == #now and #now > 4 then
			local jumps = 0
			for n = 1, #now do
				if math.abs(now[n] - old[n]) > 28 then
					jumps = jumps + 1
				end
			end
			if jumps >= 3 then
				state.boundary_jump[key] = (state.boundary_jump[key] or 0) + 1
			end
		end
	end
	state.prev_widths = stored
end

local function rebuild_regions()
	local t0 = Isaac.GetNanoTime and Isaac.GetNanoTime() or nil
	local chains = stream.prepared_chains(state, cfg)
	state.stream_preview = chains
	state.region_build = regions.build(chains, cfg, state.time, state.emitting)
	local built = state.region_build
	local valid_us = built and built.geometry_validation_us or 0
	if t0 and Isaac.GetNanoTime then
		local total = (Isaac.GetNanoTime() - t0) / 1000
		state.geometry_validation_us = valid_us
		state.geometry_build_us = total - valid_us
		if state.geometry_build_us < 0 then
			state.geometry_build_us = 0
		end
	else
		state.geometry_build_us = nil
		state.geometry_validation_us = nil
	end
	note_boundary_jumps(state.region_build)
	local vis = built and built.segment_vis or {}
	local raster = state.segment_raster or {}
	local skips = state.segment_raster_skips or {}
	local rows = state.segment_rows or {}
	local function copy_length(row, slot)
		local seg = state.segments and state.segments[row.segment_id]
		local diag = seg and seg.length_diag
		row.length_axis = seg and seg.length_axis or 0
		row.length_now = seg and seg.length_now or 0
		row.cooling_front_s = seg and seg.cooling_front_s or 0
		row.birth_class = seg and seg.birth_class or ""
		row.chain_arc = diag and diag.chain_arc or 0
		row.chain_n = diag and diag.chain_n or 0
		row.split_n = diag and diag.split_n or 0
		row.gap_dropped = diag and diag.gap_dropped or 0
		row.thin_dropped = diag and diag.thin_dropped or 0
		row.view_skipped = diag and diag.view_skipped or 0
		row.draw_dropped = diag and diag.draw_dropped or 0
		row.kept_arc = diag and diag.kept_arc or 0
		row.visible_run_arc = slot and slot.visible_run_arc or 0
		row.visible_runs = slot and slot.visible_runs or nil
		row.compact_blob = slot and slot.compact_blob == true
		local classes = {}
		local pieces = state.piece_rows or {}
		for n = 1, #pieces do
			if pieces[n].segment_id == row.segment_id then
				classes[#classes + 1] = pieces[n].visual_class or ""
			end
		end
		row.visual_class = table.concat(classes, "+")
	end
	for i = 1, #rows do
		local row = rows[i]
		local slot = vis[row.segment_id]
		row.raw_slice_count = row.live or 0
		if slot then
			row.outer_heat_open_count = slot.outer_heat_open_count or 0
			row.residual_open_count = slot.residual_open_count or 0
			row.residual_candidate_count = slot.residual_candidate_count or 0
			row.residual_run_count = slot.residual_run_count or 0
			row.residual_reject_reason = slot.residual_reject_reason or ""
			row.generated_polygon_count = slot.generated_polygon_count or 0
			row.core_polygon_count = slot.core_polygon_count or 0
			row.thermal_area = slot.thermal_area or 0
			row.residual_area = slot.residual_area or 0
			row.visible_outer_area = slot.visible_outer_area or 0
			row.temperature_threshold_failures = slot.temperature_threshold_failures or 0
			row.geometry_failures = slot.geometry_failures or 0
			row.geometry_failures_drawn = slot.geometry_failures_drawn or 0
			row.invisible_reason = slot.invisible_reason or ""
			local submitted = raster[row.segment_id]
			row.submitted_raster_intervals = submitted or 0
			row.raster_skips = skips[row.segment_id] or 0
			row.offscreen_clips = slot.offscreen_clips or 0
			if state.render_ran and (slot.generated_polygon_count or 0) > 0 and (submitted or 0) == 0 and row.invisible_reason == "" then
				row.invisible_reason = "fill_skipped"
			end
			copy_length(row, slot)
		else
			row.outer_heat_open_count = 0
			row.residual_open_count = 0
			row.residual_candidate_count = 0
			row.residual_run_count = 0
			row.generated_polygon_count = 0
			row.visible_outer_area = 0
			row.thermal_area = 0
			row.residual_area = 0
			row.submitted_raster_intervals = 0
			row.raster_skips = 0
			row.offscreen_clips = 0
			row.geometry_failures = 0
			row.temperature_threshold_failures = 0
			local seg = state.segments and state.segments[row.segment_id]
			if seg and seg.visual_skip then
				row.invisible_reason = "offscreen"
				row.residual_reject_reason = "offscreen"
			elseif (row.live or 0) > 0 and row.phase ~= "emitting" then
				row.invisible_reason = "chain_omitted"
				row.residual_reject_reason = "chain_omitted"
			else
				row.invisible_reason = ""
				row.residual_reject_reason = ""
			end
			copy_length(row, nil)
		end
	end
end

local function measure_motion()
	local list = state.stream or {}
	local age_max = 0
	local temp_sum = 0
	local radius_sum = 0
	local speed_sum = 0
	local nearest = nil
	local best = nil
	local best_d = -1
	for i = 1, #list do
		local sample = list[i]
		local travelled = sample.distance or 0
		local heat = sample.heat or 0
		if heat > 0.04 then
			local age = sample.age or 0
			if age > age_max then age_max = age end
			temp_sum = temp_sum + (sample.temperature or heat)
			radius_sum = radius_sum + ((sample.ru or 0) + (sample.rl or 0)) * 0.5
			local vx = sample.vx or 0
			local vy = sample.vy or 0
			speed_sum = speed_sum + math.sqrt(vx * vx + vy * vy)
			if sample.x and state.origin then
				local dx = sample.x - state.origin.x
				local dy = sample.y - state.origin.y
				local dist = math.sqrt(dx * dx + dy * dy)
				if not nearest or dist < nearest then
					nearest = dist
				end
			end
			if travelled > best_d then
				best = sample
				best_d = travelled
			end
		end
	end
	local count = 0
	for i = 1, #list do
		if (list[i].heat or 0) > 0.04 then
			count = count + 1
		end
	end
	state.slice_count = count
	state.slice_age_max = age_max
	state.slice_temp_avg = count > 0 and temp_sum / count or 0
	state.slice_radius_avg = count > 0 and radius_sum / count or 0
	state.slice_speed_avg = count > 0 and speed_sum / count or 0
	state.branch_count = #(state.branches or {})
	if state.emitting then
		state.tail_recession = 0
	else
		state.tail_recession = nearest or 0
	end
	if cfg.static_solid then
		state.stream_motion_valid = false
		state.head_position_delta = 0
		return
	end
	if not best or not best.x then
		state.stream_motion_valid = false
		return
	end
	local x = best.x
	local y = best.y
	if state.prev_head_x then
		local dx = x - state.prev_head_x
		local dy = y - state.prev_head_y
		state.head_position_delta = math.sqrt(dx * dx + dy * dy)
		state.stream_motion_valid = state.head_position_delta > 0.25
	else
		state.head_position_delta = 0
		state.stream_motion_valid = false
	end
	state.prev_head_x = x
	state.prev_head_y = y
end

function session.tick(player)
	local advance = (not state.frozen) or state.step_once
	state.step_once = false
	if not advance then
		if state.rebuild_visual and state.phase ~= "idle" then
			state.rebuild_visual = false
			rebuild_regions()
		end
		return
	end
	if state.phase == "idle" then
		return
	end
	state.time = state.time + 1
	state.serial = state.serial + 1
	state.budget_clamped = false
	if state.emitting then
		refresh_source(player)
		if cfg.static_solid then
			state.head = cfg.length
		elseif state.head < cfg.length then
			state.head = math.min(cfg.length, state.head + cfg.flow)
		end
		if not cfg.static_solid then
			stream.advance(state, cfg, true, state.origin, state.dir)
		end
		if not state.continuous then
			state.emit_left = state.emit_left - 1
			if state.emit_left <= 0 then
				session.stop()
			end
		end
	else
		state.phase = "fade"
		if cfg.static_solid then
			state.fade_cut = (state.fade_cut or 0) + cfg.flow * 0.5
		else
			stream.advance(state, cfg, false, state.origin, state.dir)
		end
		if state.afterglow > 0 then
			state.afterglow = state.afterglow - 1
		end
	end
	if cfg.static_solid then
		state.heat_sim_active = false
		state.temperature_update_us = nil
	else
		state.heat_sim_active = true
	end
	stream.observe_heat(state)
	measure_motion()
	rebuild_regions()
	state.rebuild_visual = false
	local built_now = state.region_build
	if built_now and not cfg.static_solid then
		local pending = state.pending_events or {}
		built_now.events = built_now.events or {}
		for i = 1, #pending do
			built_now.events[#built_now.events + 1] = pending[i]
		end
		state.pending_events = {}
		local branches = state.branches or {}
		built_now.tongue_attached = #branches
		built_now.wave_count = #branches
	end
	local aim = state.dir
	if aim and aim.x and aim.y then
		local ang = math.atan(aim.y, aim.x)
		if state.prev_aim_angle then
			local turn = ang - state.prev_aim_angle
			while turn > math.pi do
				turn = turn - math.pi * 2
			end
			while turn < -math.pi do
				turn = turn + math.pi * 2
			end
			state.accumulated_rotation = (state.accumulated_rotation or 0) + math.abs(turn)
		end
		state.prev_aim_angle = ang
	end
	particles.integrate(state, state.region_build)
	particles.consume(state, cfg, state.region_build)
	local built = state.region_build
	local has_fill = built and (built.segment_count or 0) > 0
	local has_stream = state.stream and #state.stream > 0
	if not state.emitting and not has_fill and not has_stream and #state.ember == 0 then
		state.phase = "idle"
	end
end

function session.on_room_change()
	session.clear("room_change")
end

function session.snapshot()
	local built = state.region_build
	local jumps = state.boundary_jump or {}
	local draw_ns = state.region_draw_ns
	local birth = state.orb_birth or {}
	local temp_sum = 0
	local emerge_sum = 0
	local relative_sum = 0
	local phase_attached = 0
	local phase_emerging = 0
	local phase_detached = 0
	local phase_cooling = 0
	for i = 1, #state.ember do
		local piece = state.ember[i]
		temp_sum = temp_sum + (piece.temperature or 0)
		emerge_sum = emerge_sum + (piece.emergence or 0)
		relative_sum = relative_sum + (piece.edge_relative or 0)
		local phase = piece.phase
		if phase == "attached" then
			phase_attached = phase_attached + 1
		elseif phase == "emerging" then
			phase_emerging = phase_emerging + 1
		elseif phase == "cooling" then
			phase_cooling = phase_cooling + 1
		else
			phase_detached = phase_detached + 1
		end
	end
	local ember_n = #state.ember
	local function mean(sum)
		if ember_n <= 0 then
			return 0
		end
		return sum / ember_n
	end
	local function width_average(source, key)
		local bucket = source and source.widths and source.widths[key]
		if not bucket or #bucket == 0 then
			return 0
		end
		local sum = 0
		for i = 1, #bucket do
			sum = sum + (bucket[i] or 0)
		end
		return sum / #bucket
	end
	local function role_count(role)
		local n = 0
		for i = 1, #state.ember do
			if state.ember[i].role == role then
				n = n + 1
			end
		end
		return n
	end
	local function copy_nums(src)
		if type(src) ~= "table" then
			return nil
		end
		local out = {}
		for i = 1, #src do
			out[i] = src[i]
		end
		return out
	end
	local function copy_trail(src)
		local out = {}
		if type(src) ~= "table" then
			return out
		end
		for i = 1, #src do
			local point = src[i]
			out[i] = {
				age = point.age,
				x = point.x,
				y = point.y,
				dist = point.dist,
				tmax = point.tmax,
				center = point.center,
				spread = point.spread,
			}
		end
		return out
	end
	local live_track = state.tracked_slice_id ~= nil
	local show_memory = (not live_track) and state.heat_arm ~= true and heat_memory.tracked_id ~= nil
	local heat_source = show_memory and heat_memory or nil
	local tracked_id = live_track and state.tracked_slice_id or (heat_source and heat_source.tracked_id or nil)
	local heat_alive = live_track and state.heat_track_alive == true
	local heat_end = "none"
	if live_track then
		heat_end = state.heat_track_end or "none"
	elseif heat_source then
		heat_end = heat_source.end_reason or "none"
	end
	local heat_profile = copy_nums(live_track and state.heat_profile or (heat_source and heat_source.profile))
	local heat_trail = copy_trail(live_track and state.heat_trail or (heat_source and heat_source.trail))
	local function heat_num(live_value, memory_key)
		if live_track then
			return live_value or 0
		end
		if heat_source then
			return heat_source[memory_key] or 0
		end
		return 0
	end
	local heat_us = nil
	if state.heat_sim_active or live_track then
		heat_us = state.temperature_update_us
	elseif heat_source then
		heat_us = heat_source.temperature_update_us
	end
	local active_slices = state.active_slice_count
	if active_slices == nil then
		active_slices = heat_source and heat_source.active_slice_count or 0
	end
	local release_id = nil
	local release_rec = nil
	for id, seg in pairs(state.segments or {}) do
		local rel = seg.release
		if rel and (not release_rec or (rel.start_frame or 0) > (release_rec.start_frame or 0) or ((rel.start_frame or 0) == (release_rec.start_frame or 0) and id > release_id)) then
			release_rec = rel
			release_id = id
		end
	end
	local release_age = 0
	if release_rec then
		release_age = (state.time or 0) - (release_rec.start_frame or 0)
		if release_age < 0 then
			release_age = 0
		end
	end
	return {
		session_id = state.id,
		phase = state.phase,
		emitting = state.emitting,
		continuous = state.continuous,
		frozen = state.frozen,
		static_solid = cfg.static_solid == true,
		elapsed_frames = state.time,
		head_distance = state.head,
		body_length = cfg.length,
		max_half_width = cfg.half_width,
		ember_count = #state.ember,
		spawned_total = state.spawned,
		recycled_total = state.recycled,
		gate0_test = cfg.gate0_test == true,
		renderer_backend = region_renderer.backend,
		source_sprite_loaded = region_renderer.source_sprite_loaded == true,
		solid_rect_test_passed = "unverified",
		raster_rows = state.raster_rows or 0,
		raster_intervals = state.raster_intervals or 0,
		sprite_draw_calls = state.sprite_draw_calls or 0,
		invalid_intersection_count = state.invalid_intersection_count or 0,
		odd_intersection_count = state.odd_intersection_count or 0,
		scanline_height = region_renderer.scanline_height or cfg.scanline_height,
		max_raster_rows = cfg.max_raster_rows,
		raster_budget_clamped = state.raster_budget_clamped == true,
		world_geometry_valid = (not built) and "unverified" or ((built.invalid or 0) == 0 and (built.segment_count or 0) > 0),
		camera_projection_valid = "unverified",
		render_error_count = region_renderer.error_count or 0,
		render_first_error = region_renderer.first_error or "none",
		render_error_phase = region_renderer.first_error_phase or "none",
		render_primitive_count = state.render_primitive_count or 0,
		region_count = built and ((built.outer and 1 or 0) + (built.orange and 1 or 0) + (built.gold and 1 or 0) + (built.white and 1 or 0)) or 0,
		region_segment_count = built and built.segment_count or 0,
		stream_sample_count = #(state.stream or {}),
		slice_count = state.slice_count or 0,
		tracked_slice_id = tracked_id,
		heat_track_alive = heat_alive == true,
		heat_track_end = heat_end,
		heat_arm = state.heat_arm == true,
		heat_view = cfg.heat_view == true,
		heat_regions = cfg.heat_regions ~= false,
		heat_split_count = built and built.heat_split_count or 0,
		heat_zero_width = built and built.heat_zero_width or 0,
		heat_terminations = built and built.heat_terminations or 0,
		head_valid_width = built and built.head_valid_width or 0,
		heat_layers = built and built.heat_layers or {},
		heat_sim_active = state.heat_sim_active == true,
		travelled_distance = heat_num(state.heat_travelled, "travelled_distance"),
		heat_age = heat_num(state.heat_age, "age"),
		temperature_min = heat_num(state.heat_tmin, "temperature_min"),
		temperature_max = heat_num(state.heat_tmax, "temperature_max"),
		heat_center_offset = heat_num(state.heat_center, "heat_center_offset"),
		heat_spread = heat_num(state.heat_spread, "heat_spread"),
		temperature_update_us = heat_us == nil and "unverified" or heat_us,
		active_slice_count = active_slices,
		heat_x = heat_num(state.heat_x, "x"),
		heat_y = heat_num(state.heat_y, "y"),
		heat_seed = heat_num(state.heat_seed, "seed"),
		heat_shift = heat_num(state.heat_shift, "shift"),
		heat_drift = heat_num(state.heat_drift_value, "drift"),
		heat_profile = heat_profile,
		heat_trail = heat_trail,
		slice_age_max = state.slice_age_max or 0,
		slice_temp_avg = state.slice_temp_avg or 0,
		slice_radius_avg = state.slice_radius_avg or 0,
		slice_speed_avg = state.slice_speed_avg or 0,
		branch_count = state.branch_count or 0,
		stream_sample_peak = state.stream_peak or 0,
		stream_discontinuity_count = state.stream_discontinuity_count or 0,
		stream_motion_valid = state.stream_motion_valid == true,
		envelope_wave_count = built and built.wave_count or 0,
		tongue_attached_count = built and built.tongue_attached or 0,
		tongue_detached_count = state.tongue_detached_count or 0,
		spark_spawn_by_source = state.spark_sources or { flame = 0, spark = 0, cinder = 0, smoke = 0 },
		head_position_delta = state.head_position_delta or 0,
		tail_recession = state.tail_recession or 0,
		outer_boundary_jump = jumps.outer or 0,
		orange_boundary_jump = jumps.orange or 0,
		gold_boundary_jump = jumps.gold or 0,
		white_boundary_jump = jumps.white or 0,
		odd_scanline_capture = state.odd_scanline_capture,
		geometry_skip_count = state.geometry_skip_count or 0,
		self_intersection_count = state.self_intersection_count or 0,
		fill_layers = state.fill_layers or {},
		fill_spans = state.fill_spans or {},
		pre_split_audit = built and built.pre_split_audit or {},
		pre_split_faults = built and built.fill_faults or {},
		fill_skip_diag = cfg.fill_skip_diag == true,
		cap_multi_peak = cfg.cap_multi_peak == true,
		layer_override = session.layer_override_text(),
		coverage_rows = state.coverage_rows or 0,
		raster_rows_estimate = state.raster_rows_estimate or 0,
		raster_calls_estimate = state.raster_calls_estimate or 0,
		raster_step_used = state.raster_step_used or 0,
		raster_front_step = state.raster_front_step or 0,
		raster_degraded = state.raster_degraded == true,
		raster_over_soft_budget = state.raster_over_soft_budget == true,
		raster_clamp_layer = state.raster_clamp_layer or "none",
		raster_clamp_y = state.raster_clamp_y or "none",
		local_fold_count = built and built.local_fold_count or state.local_fold_count or 0,
		head_length = built and built.head and built.head.length or 0,
		head_width = built and built.head and built.head.width or 0,
		head_cool = built and built.head and built.head.cool or 0,
		head_speed = built and built.head and built.head.speed or 0,
		head_tip = built and built.head and { x = built.head.tip_x, y = built.head.tip_y } or nil,
		aim_x = state.dir and state.dir.x or 0,
		aim_y = state.dir and state.dir.y or 0,
		tip_slice_id = state.stream and state.stream[1] and state.stream[1].id or nil,
		head_taper = built and built.head and { x = built.head.taper_x, y = built.head.taper_y } or nil,
		head_upper = built and built.head and { x = built.head.upper_x, y = built.head.upper_y } or nil,
		head_lower = built and built.head and { x = built.head.lower_x, y = built.head.lower_y } or nil,
		head_break = built and built.head and { x = built.head.break_x, y = built.head.break_y } or nil,
		front_core_distance = built and built.front_core_distance or 0,
		front_outer_upper_distance = built and built.front_outer_upper_distance or 0,
		front_outer_lower_distance = built and built.front_outer_lower_distance or 0,
		front_visual_extent = built and built.front_visual_extent or 0,
		front_cap_count = built and built.front_cap_count or 0,
		front_depth = built and built.front_depth or 0,
		front_width = built and built.front_width or 0,
		front_depth_ratio = built and built.front_depth_ratio or 0,
		layer_containment_failures = built and built.containment or 0,
		section_containment_failures = built and built.section_containment_failures or 0,
		front_containment_failures = built and built.front_containment_failures or 0,
		region_pierce_count = built and built.region_pierce_count or 0,
		region_pierce_unresolved = built and built.region_pierce_unresolved or 0,
		boundary_intersection_count = built and built.boundary_intersection_count or 0,
		boundary_smoothing_clamped = built and built.boundary_smoothing_clamped or 0,
		mouth_orange_frac = built and built.band_frac and built.band_frac.mouth_orange or 0,
		mouth_gold_frac = built and built.band_frac and built.band_frac.mouth_gold or 0,
		mouth_white_frac = built and built.band_frac and built.band_frac.mouth_white or 0,
		mid_orange_frac = built and built.band_frac and built.band_frac.mid_orange or 0,
		mid_gold_frac = built and built.band_frac and built.band_frac.mid_gold or 0,
		mid_white_frac = built and built.band_frac and built.band_frac.mid_white or 0,
		far_orange_frac = built and built.band_frac and built.band_frac.far_orange or 0,
		far_gold_frac = built and built.band_frac and built.band_frac.far_gold or 0,
		far_white_frac = built and built.band_frac and built.band_frac.far_white or 0,
		sections = built and built.sections or {},
		white_width_average = width_average(built, "white"),
		gold_width_average = width_average(built, "gold"),
		orange_width_average = width_average(built, "orange"),
		outer_width_average = width_average(built, "outer"),
		particle_count_small = role_count("small"),
		particle_count_medium = role_count("medium"),
		particle_count_large = role_count("large"),
		particle_count_xlarge = role_count("xlarge"),
		particle_birth_upper = birth.upper or 0,
		particle_birth_lower = birth.lower or 0,
		particle_birth_front = birth.front or 0,
		particle_birth_event = birth.event or 0,
		particle_birth_bulge = birth.bulge or 0,
		particle_temp_average = mean(temp_sum),
		particle_emergence_average = mean(emerge_sum),
		spawn_attempted = state.spawn_attempted_frame or 0,
		spawn_accepted = state.spawn_accepted_frame or 0,
		spawn_rejected = state.spawn_rejected_frame or 0,
		phase_attached = phase_attached,
		phase_emerging = phase_emerging,
		phase_detached = phase_detached,
		phase_cooling = phase_cooling,
		source_lost = state.source_lost or 0,
		edge_relative_distance = mean(relative_sum),
		orb_build_us = state.orb_build_us or 0,
		orb_render_us = state.orb_render_us or 0,
		orb_normal_birth = (state.orb_motion and state.orb_motion.normal) or 0,
		orb_tangent_birth = (state.orb_motion and state.orb_motion.tangent) or 0,
		orb_bulge_birth = (state.orb_motion and state.orb_motion.bulge) or 0,
		stream_segment_count = (function()
			local n = 0
			local segs = state.segments or {}
			for _ in pairs(segs) do
				n = n + 1
			end
			return n
		end)(),
		segment_created_total = state.segment_created_total or 0,
		segment_finished_total = state.segment_finished_total or 0,
		direction_break_count = state.direction_break_count or 0,
		aim_turn_degrees = state.aim_turn_degrees or 0,
		segment_extent = state.segment_extent or 0,
		turn_extent = cfg.turn_extent or C.TURN_EXTENT,
		last_split_reason = state.last_split_reason or "none",
		max_turn_degrees = state.max_turn_degrees or 0,
		max_neighbor_gap = state.max_neighbor_gap or 0,
		max_neighbor_turn = state.max_neighbor_turn or 0,
		input_release_count = state.input_release_count or 0,
		accumulated_rotation_degrees = ((state.accumulated_rotation or 0) * 180 / math.pi),
		removed_by_residual = state.removed_by_residual or 0,
		removed_by_residual_total = state.removed_by_residual_total or 0,
		position_break_count = state.position_break_count or 0,
		geometry_break_count = state.geometry_break_count or 0,
		stale_front_memory_count = state.stale_front_memory_count or 0,
		rear_cap_count = built and built.rear_cap_count or 0,
		rear_cap_required = built and built.rear_cap_required or 0,
		rear_cap_width = built and built.rear_cap_width or 0,
		rear_cap_depth = built and built.rear_cap_depth or 0,
		rear_envelope_solves = built and built.rear_envelope_solves or 0,
		rear_search_candidates = built and built.rear_search_candidates or 0,
		temperature_gap_starts = built and built.temperature_gap_starts or 0,
		piece_count = state.piece_stats and state.piece_stats.n or 0,
		piece_short = state.piece_stats and state.piece_stats.short or 0,
		piece_blob = state.piece_stats and state.piece_stats.blob or 0,
		piece_fragment = state.piece_stats and state.piece_stats.fragment or 0,
		piece_stream = state.piece_stats and state.piece_stats.stream or 0,
		removed_by_distance = state.removed_by_distance or 0,
		removed_by_temperature = state.removed_by_temperature or 0,
		removed_by_age = state.removed_by_age or 0,
		removed_by_budget = state.removed_by_budget or 0,
		removed_by_hard_cap = state.removed_by_hard_cap or 0,
		removed_by_hard_cap_total = state.removed_by_hard_cap_total or 0,
		hard_cap_trips = state.hard_cap_trips or 0,
		hard_cap_trips_total = state.hard_cap_trips_total or 0,
		render_vertices = state.render_vertices or 0,
		lod_l0 = state.lod_counts and state.lod_counts[1] or 0,
		lod_l1 = state.lod_counts and state.lod_counts[2] or 0,
		lod_l2 = state.lod_counts and state.lod_counts[3] or 0,
		visible_area_ratio = state.lod_area_ratio or 1,
		connected_component_count = state.lod_component_count or 0,
		lod_transition_count = state.lod_transition_count or 0,
		lod_transition_total = state.lod_transition_total or 0,
		removed_by_distance_total = state.removed_by_distance_total or 0,
		removed_by_temperature_total = state.removed_by_temperature_total or 0,
		removed_by_age_total = state.removed_by_age_total or 0,
		removed_by_budget_total = state.removed_by_budget_total or 0,
		coasting_frames = state.coasting_frames or 0,
		dissipating_frames = state.dissipating_frames or 0,
		segment_length_at_close = state.watch_length_at_close or 0,
		segment_length_after_close = state.watch_length_now or 0,
		slice_width_at_close = state.watch_width_at_close or 0,
		slice_width_after_close = state.watch_width_now or 0,
		closed_phase = state.watch_phase or "none",
		rear_upper_join_error = built and built.rear_upper_join_error or 0,
		rear_lower_join_error = built and built.rear_lower_join_error or 0,
		rear_tangent_discontinuity = built and built.rear_tangent_discontinuity or 0,
		rear_polygon_crossing = built and built.rear_polygon_crossing or 0,
		rear_parent_containment_failures = built and built.rear_parent_containment_failures or 0,
		segment_rows = state.segment_rows or {},
		segment_log = state.segment_log or {},
		release_segment_id = release_id or 0,
		release_reason = release_rec and release_rec.reason or "none",
		release_age = release_age,
		release_particle_count = state.release_births_frame or 0,
		edge_length = built and built.edge_length or 0,
		edge_weight_total = built and built.edge_weight_total or 0,
		particle_draw_calls = state.particle_draw_calls or 0,
		scanline_intervals_before_merge = state.scanline_intervals_before or 0,
		scanline_intervals_after_merge = state.scanline_intervals_after or 0,
		renderer_backend_cfg = cfg.renderer_backend or "sprite_scanline",
		geometry_build_us = state.geometry_build_us or "unverified",
		geometry_frame_us = built and built.geometry_frame_us or 0,
		geometry_fit_us = built and built.geometry_fit_us or 0,
		geometry_validation_us = state.geometry_validation_us or "unverified",
		screen_projection_us = state.screen_projection_us or "unverified",
		scanline_fill_us = state.scanline_fill_us or "unverified",
		sprite_submit_us = state.sprite_submit_us or "unverified",
		region_vertex_count = state.region_vertex_count or 0,
		scanline_edge_tests = state.scanline_edge_tests or 0,
		validation_edge_tests = built and built.validation_edge_tests or 0,
		validation_full_count = built and built.validation_full_count or 0,
		active_edge_peak = state.active_edge_peak or 0,
		active_edge_table = false,
		frame_time_p50 = state.frame_time_p50 or "unverified",
		frame_time_p95 = state.frame_time_p95 or "unverified",
		frame_time_max = state.frame_time_max or "unverified",
		frame_time_source = state.frame_time_source or "unverified",
		perf_profile = cfg.perf_profile or "normal",
		region_crossing_count = built and built.crossing or 0,
		region_invalid_geometry_count = built and built.invalid or 0,
		region_raster_gap_count = "unverified",
		region_draw_ns = draw_ns or "unverified",
		particle_draw_time = "unverified",
		camera_offset_mismatch = "unverified",
		unexpected_reset_count = "unverified",
		nan_count = state.nan_count,
		budget_clamped = state.budget_clamped,
		color_test = cfg.color_test,
		clock = "MC_POST_UPDATE 30Hz",
	}
end

return session
