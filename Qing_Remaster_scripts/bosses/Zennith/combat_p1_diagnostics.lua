-- Zennith P1 combat diagnostics / inspect text
-- Behavior-equivalent extract from combat_p1.lua (structural only).

local function register(Env)
	function Env.inspect_session(boss)
		local sess = Env.get_sess(boss, false)
		if not sess then
			return {
				has_session = false,
				combat_phase = "-",
				attack_state = "-",
			}
		end
		local obj_n = 0
		for _, ent in pairs(sess.objects) do
			if ent and ent.Exists and ent:Exists() then obj_n = obj_n + 1 end
		end
		local combat_phase = "P1"
		if sess.complete and not sess.force_p1 then
			combat_phase = "P1_COMPLETE"
		elseif sess.force_p1 then
			combat_phase = "P1_LOOP"
		end
		local wall = sess.wall
		local info = {
			has_session = true,
			combat_phase = combat_phase,
			attack_state = sess.attack and sess.phase or "idle",
			attack = sess.attack or "-",
			age = sess.age,
			cooldown = sess.cooldown or 0,
			last_attack = sess.last_attack or "-",
			force_p1 = sess.force_p1 == true,
			complete = sess.complete == true,
			frozen = sess.frozen == true,
			objects = obj_n,
			hp_ratio = Env.living(sess.boss) and Env.hp_ratio(sess.boss) or 0,
			wind_from = sess.wind_from or 0,
			wind_target = sess.wind_target or sess.ambient_ang or 0,
			wind_ang = sess.ambient_ang or 0,
			phase = sess.attack and sess.phase or "idle",
		}
		if wall then
			info.wall_form = wall.form_t or 0
			info.wall_density = wall.density or 0
			info.wall_leading = wall.leading
			info.wall_trailing = wall.trailing
			info.wall_thickness = math.abs((wall.leading or 0) - (wall.trailing or 0))
			info.wall_damaging = wall.damaging == true
			info.travel_dir = wall.travel_dir or wall.dir
			info.trail_frac = wall.trail_frac
			info.wall_hit_y0 = wall.y0
			info.wall_hit_y1 = wall.y1
			info.wall_vis_y0 = wall.vis_y0
			info.wall_vis_y1 = wall.vis_y1
			info.gap_count = wall.gaps and #wall.gaps or 0
			if wall.gaps and wall.gaps[1] then
				info.gap1 = string.format("%.0f-%.0f", wall.gaps[1].y0, wall.gaps[1].y1)
			end
			if wall.gaps and wall.gaps[2] then
				info.gap2 = string.format("%.0f-%.0f", wall.gaps[2].y0, wall.gaps[2].y1)
			end
		end
		if sess.retreat then
			info.retreat_age = sess.retreat.age
			info.retreat_frames = sess.retreat.frames
			info.retreat_request_dist = sess.retreat.request_dist
			info.retreat_target_dist = sess.retreat.target_dist
			info.retreat_completed_dist = sess.retreat.completed_dist
			if sess.retreat.from and sess.retreat.to then
				info.retreat_from = string.format("%.0f,%.0f", sess.retreat.from.X, sess.retreat.from.Y)
				info.retreat_to = string.format("%.0f,%.0f", sess.retreat.to.X, sess.retreat.to.Y)
			end
		end
		local meta = sess.meta
		if meta then
			-- Stance / split (may persist through the attack session).
			info.stance_request_dist = meta.stance_request_dist
			info.stance_target_dist = meta.stance_target_dist
			info.stance_completed_dist = meta.stance_completed_dist or info.retreat_completed_dist
			info.stance_from = meta.stance_from or info.retreat_from
			info.stance_to = meta.stance_to or info.retreat_to
			info.split_aim_locked = meta.aim_locked == true
			info.split_base_angle = meta.base_ang
			info.split_targets = meta.target_list
			info.split_fired = meta.fired
			info.split_volley_fired = meta.volley_fired == true
			info.split_volley_fire_clock = meta.volley_fire_clock
			info.split_shoot_event_clock = meta.shoot_event_clock
			info.split_shoot_fallback = meta.shoot_fallback == true
			info.split_cast_anim = meta.cast_anim_name
			info.split_cast_play_clock = meta.cast_play_clock
			info.split_next_cut = meta.next_cut_idx
			info.split_last_cut_clock = meta.last_cut_clock
			info.split_triangle_edges = meta.triangle_edges
			info.split_triangle_area = meta.triangle_area
			info.split_triangle_scale = meta.triangle_scale
			info.split_fire_downward = meta.fire_downward == true
			info.split_retreat_dir = meta.retreat_dir
			info.split_retreat_shortened = meta.retreat_shortened == true
			info.split_retreat_skipped = meta.retreat_skipped == true
			info.split_last_visual = meta.last_visual_target
			info.split_last_logic = meta.last_logic_pos
			info.split_cut_dir_plan = meta.cut_dir_list
			info.split_cut_angs = meta.actual_cut_ang_list or meta.cut_dir_list
			if meta.cut_fx and #meta.cut_fx > 0 then
				local parts = {}
				for i = 1, #meta.cut_fx do
					local c = meta.cut_fx[i]
					parts[#parts + 1] = string.format(
						"#%s ang=%.0f age=%s/%s hit=%s@%s tip=%s vis=%s %s→%s",
						tostring(c.shot_idx or i),
						tonumber(c.ang) or 0,
						tostring(c.age or 0),
						tostring(c.duration or "-"),
						tostring(c.hit == true),
						tostring(c.hit_clock or "-"),
						tostring(c.tip_str or "-"),
						tostring(c.visual_target_str or "-"),
						tostring(c.start_str or "-"),
						tostring(c.end_str or "-")
					)
				end
				info.split_cut_fx = table.concat(parts, " | ")
			end
			if meta.fire_origin then
				info.split_fire_origin = string.format("%.0f,%.0f", meta.fire_origin.X, meta.fire_origin.Y)
			end
			if meta.aim_target then
				info.split_aim_target = string.format("%.0f,%.0f", meta.aim_target.X, meta.aim_target.Y)
			end
			if meta.split_projectile_positions then
				local parts = {}
				for i = 1, #meta.split_projectile_positions do
					local p = meta.split_projectile_positions[i]
					parts[#parts + 1] = string.format(
						"%.0f,%.0f->%.0f,%.0f",
						p.x, p.y, p.tx or p.x, p.ty or p.y
					)
				end
				info.split_projectile_positions = table.concat(parts, " | ")
			end
			if meta.split_diag then
				info.split_diag = table.concat(meta.split_diag, " | ")
			end
			if meta.bursts then
				local bp = {}
				for i = 1, #meta.bursts do
					local b = meta.bursts[i]
					bp[#bp + 1] = string.format("#%d n=%d @%.0f,%.0f t=%s", b.idx or i, b.n or 0, b.x or 0, b.y or 0, tostring(b.clock or "-"))
				end
				info.split_bursts = table.concat(bp, " | ")
			end
			if meta.child_counts then
				info.split_child_counts = string.format(
					"%d/%d/%d",
					meta.child_counts[1] or 0,
					meta.child_counts[2] or 0,
					meta.child_counts[3] or 0
				)
			end
			-- Live main states
			do
				local states = {}
				local speeds = {}
				local clocks = {}
				for _, ent in pairs(sess.objects) do
					if ent and ent.Exists and ent:Exists() then
						local d = ent:GetData()
						if d[Env.M.own_key .. "split_parent"] then
							states[#states + 1] = string.format(
								"#%s=%s",
								tostring(d[Env.M.own_key .. "shot_idx"] or "?"),
								tostring(d[Env.M.own_key .. "split_state"] or "?")
							)
							clocks[#clocks + 1] = string.format(
								"#%s f=%s a=%s h=%s..%s c=%s",
								tostring(d[Env.M.own_key .. "shot_idx"] or "?"),
								tostring(d[Env.M.own_key .. "fire_clock"] or "-"),
								tostring(d[Env.M.own_key .. "arrive_clock"] or "-"),
								tostring(d[Env.M.own_key .. "hold_start_clock"] or "-"),
								tostring(d[Env.M.own_key .. "hold_end_clock"] or "-"),
								tostring(d[Env.M.own_key .. "cut_clock"] or "-")
							)
						elseif d[Env.M.own_key .. "split_child"] then
							speeds[#speeds + 1] = string.format("%.1f", ent.Velocity:Length())
						end
					end
				end
				if #states > 0 then info.split_main_states = table.concat(states, ",") end
				if #clocks > 0 then info.split_main_clocks = table.concat(clocks, " | ") end
				if meta.mains then
					local mp = {}
					for i = 1, #meta.mains do
						local m = meta.mains[i]
						mp[#mp + 1] = string.format(
							"#%d fire=%s arrive=%s sc=%.2f",
							m.idx or i,
							tostring(m.fire_clock or "-"),
							tostring(m.arrive_clock or "-"),
							tonumber(m.scale) or 0
						)
					end
					info.split_main_plan = table.concat(mp, " | ")
				end
				if #speeds > 0 then
					local sum = 0
					for i = 1, #speeds do sum = sum + (tonumber(speeds[i]) or 0) end
					info.split_child_speed_avg = sum / #speeds
					info.split_child_alive = #speeds
				end
			end
			info.gap_method = meta.gap_method
			info.gap_fallback = meta.gap_fallback == true
			info.gap_widths = meta.gap_widths
			info.gap_bands = meta.gap_bands
			-- Gust flow counters (alive count is observe-only).
			info.gust_spawned = meta.spawned
			info.gust_alive = 0
			info.gust_visible_now = 0
			info.gust_rising_now = 0
			info.gust_offscreen_now = 0
			for _, ent in pairs(sess.objects) do
				if ent and ent.Exists and ent:Exists() and ent:GetData()[Env.M.own_key .. "gust"] then
					info.gust_alive = info.gust_alive + 1
					local gd = ent:GetData()
					local rising = not gd[Env.M.own_key .. "gust_risen"]
					if Env.in_screen_view and Env.in_screen_view(ent.Position, 4) then
						info.gust_visible_now = info.gust_visible_now + 1
						if rising then
							info.gust_rising_now = info.gust_rising_now + 1
						end
					else
						info.gust_offscreen_now = info.gust_offscreen_now + 1
					end
				end
			end
			info.gust_entered_view = meta.entered_view
			info.gust_visible_rising = meta.visible_rising
			info.gust_removed_before_view = meta.removed_before_view
			info.gust_spawn_failed = meta.spawn_failed
			info.gust_burst = meta.gust_on == true
			info.gust_track_lock = meta.track_lock == true
			info.gust_anim_start_count = meta.gust_anim_start_count
			info.gust_batch_index = meta.batch_index
			info.gust_last_batch_count = meta.last_batch_count
			info.gust_frames_since_batch = meta.frames_since_batch
			info.gust_frames_without_spawn = meta.frames_without_spawn
			info.gust_batch_interval = Env.GUST_BATCH_INTERVAL
			info.gust_spawn_mode = meta.spawn_mode
			info.gust_burst_total = meta.burst_total
			info.gust_burst_spawned = meta.burst_spawned
			info.gust_last_batch_mode = meta.last_batch_mode
			info.gust_reassigned = meta.gust_reassigned
			info.gust_spawned_outside = meta.spawned_outside
			info.gust_entered_from_outside = meta.entered_from_outside
			if (meta.enter_delay_n or 0) > 0 then
				info.gust_enter_delay_avg = (meta.enter_delay_sum or 0) / meta.enter_delay_n
			end
			if meta.last_batch_positions and #meta.last_batch_positions > 0 then
				local pp = {}
				local dist_sum, dist_n, up_sum, up_n = 0, 0, 0, 0
				for i = 1, #meta.last_batch_positions do
					local p = meta.last_batch_positions[i]
					local tag = tostring(p.band or "?")
					if p.sub_band then tag = tag .. "/" .. tostring(p.sub_band) end
					if p.spawned_outside then tag = tag .. ">out" end
					if p.reassigned then tag = tag .. "*" end
					pp[#pp + 1] = string.format(
						"%.0f,%.0f:%s d=%.0f u=%.0f",
						p.x or 0, p.y or 0, tag,
						tonumber(p.dist_player) or -1,
						tonumber(p.upwind_dist) or -1
					)
					if p.dist_player then
						dist_sum = dist_sum + p.dist_player
						dist_n = dist_n + 1
					end
					if p.upwind_dist then
						up_sum = up_sum + p.upwind_dist
						up_n = up_n + 1
					end
				end
				info.gust_last_batch_pos = table.concat(pp, " | ")
				if dist_n > 0 then info.gust_last_dist_avg = dist_sum / dist_n end
				if up_n > 0 then info.gust_last_upwind_avg = up_sum / up_n end
			end
			if meta.batch_spawn_log and #meta.batch_spawn_log > 0 then
				local recent = {}
				local start_i = math.max(1, #meta.batch_spawn_log - 3)
				for i = start_i, #meta.batch_spawn_log do
					local b = meta.batch_spawn_log[i]
					recent[#recent + 1] = string.format(
						"#%s %s n=%s@%s",
						tostring(b.idx), tostring(b.mode or "-"), tostring(b.n), tostring(b.clock)
					)
				end
				info.gust_batch_recent = table.concat(recent, " | ")
			end
			info.gust_first_spawn_frame = meta.gust_first_spawn_frame
			info.gust_first_spawn_phase = meta.gust_first_spawn_phase
			info.gust_first_spawn_band = meta.gust_first_spawn_band
			info.gust_last_spawn_frame = meta.gust_last_spawn_frame
			info.gust_last_spawn_phase = meta.gust_last_spawn_phase
			info.gust_last_spawn_age = meta.gust_last_spawn_age
			if meta.gust_first_spawn_frame and meta.gust_last_spawn_frame then
				info.gust_spawn_span = (meta.gust_last_spawn_frame or 0) - (meta.gust_first_spawn_frame or 0)
			end
			info.gust_anim_finished = meta.gust_anim_finished == true
			info.cast_anim_started = meta.cast_anim_started == true
			if meta.gust_band_counts then
				local bc = meta.gust_band_counts
				local ext = bc.screen_upwind_external or 0
				local arena = bc.arena_visible_upwind or 0
				local bias = bc.player_upwind_bias or 0
				local fb = bc.fallback or 0
				-- Legacy keys (pre-V2.6) still sum if present.
				local legacy = (bc.far_upwind or 0) + (bc.near_upwind or 0)
					+ (bc.interior or 0) + (bc.player_upwind or 0)
				local total = ext + arena + bias + fb + legacy
				info.gust_band_counts = string.format(
					"ext=%d arena=%d bias=%d fb=%d",
					ext, arena, bias, fb
				)
				info.gust_spawned_external = ext
				info.gust_spawned_arena = arena
				info.gust_spawned_player = bias
				info.gust_spawned_fallback = fb
				if total > 0 then
					info.gust_external_spawn_ratio = ext / total
					info.gust_visible_spawn_ratio = (arena + bias) / total
					info.gust_player_spawn_ratio = bias / total
					info.gust_upwind_ratio = (ext + arena + bias) / total
				end
			end
		end
		info.facing_locked = sess.facing_locked == true
		info.facing_flip_x = sess.facing_flip_x == true
		local layers = Env.p1_visual.get_layers and Env.p1_visual.get_layers() or nil
		if layers then
			info.wall_layer_front = layers.front
			info.wall_layer_tail = layers.tail
			info.wall_layer_seg = layers.seg
			info.wall_layer_mist = layers.mist
		end
		do
			local ok, arena_visual = pcall(require, "Qing_Remaster_scripts.threads.wind.arena_visual")
			if ok and arena_visual and arena_visual.get_diagnostics then
				local ad = arena_visual.get_diagnostics()
				info.arena_deep_scale = ad.deep_scale
				info.arena_deep_span = ad.deep_span
				info.arena_deep_cover = ad.deep_cover
				info.arena_screen_w = ad.screen_w
				info.arena_screen_h = ad.screen_h
				info.arena_screen_diameter = ad.screen_diameter
				info.arena_room_span = ad.room_span
			end
		end
		-- Live AttackDown1 frame while cast plays.
		if Env.living(boss) then
			local spr = boss:GetSprite()
			if spr then
				info.boss_anim = spr:GetAnimation()
				info.boss_anim_frame = spr:GetFrame()
			end
		end
		info.attack_clock = sess.clock or 0
		return info
	end
	function Env.fmt_num(v, digits)
		if v == nil then return "-" end
		local n = tonumber(v)
		if not n then return tostring(v) end
		digits = digits or 0
		return string.format("%." .. tostring(digits) .. "f", n)
	end

	--- Dedicated Zennith combat diagnostics text for Boss Test Lab.
	function Env.format_combat_diag(info)
		info = info or {}
		local fmt_num = Env.fmt_num
		local lines = {}
		local function add(s) lines[#lines + 1] = s end
		add("=== Zennith 战斗诊断 ===")
		add(string.format(
			"combat=%s  attack=%s  phase=%s  age=%s  clock=%s  frozen=%s",
			tostring(info.combat_phase or "-"),
			tostring(info.attack or "-"),
			tostring(info.attack_state or info.phase or "-"),
			tostring(info.age or "-"),
			tostring(info.attack_clock or "-"),
			tostring(info.frozen)
		))
		add(string.format(
			"HP=%s%%  objects=%s  force_p1=%s  complete=%s",
			fmt_num((info.hp_ratio or 0) * 100, 1),
			tostring(info.objects or 0),
			tostring(info.force_p1),
			tostring(info.complete)
		))
		add("")
		add("-- 风向 / 朝向 --")
		add(string.format(
			"wind_ang=%.1f  wind_target=%.1f  wind_from=%.1f",
			tonumber(info.wind_ang) or 0,
			tonumber(info.wind_target) or 0,
			tonumber(info.wind_from) or 0
		))
		add(string.format(
			"travel_dir=%s  FlipX=%s  facing_locked=%s",
			tostring(info.travel_dir or "-"),
			tostring(info.facing_flip_x),
			tostring(info.facing_locked)
		))
		add("")
		add("-- 风墙 --")
		add(string.format(
			"leading=%s  trailing=%s  thickness=%s  trail_frac=%s",
			fmt_num(info.wall_leading, 0),
			fmt_num(info.wall_trailing, 0),
			fmt_num(info.wall_thickness, 0),
			fmt_num(info.trail_frac, 2)
		))
		add(string.format(
			"density=%s  alpha_form=%s  damaging=%s  hitY=%s..%s  visY=%s..%s",
			fmt_num(info.wall_density, 2),
			fmt_num(info.wall_form, 2),
			tostring(info.wall_damaging),
			fmt_num(info.wall_hit_y0, 0), fmt_num(info.wall_hit_y1, 0),
			fmt_num(info.wall_vis_y0, 0), fmt_num(info.wall_vis_y1, 0)
		))
		add(string.format(
			"gap1=%s  gap2=%s  count=%s",
			tostring(info.gap1 or "-"),
			tostring(info.gap2 or "-"),
			tostring(info.gap_count or "-")
		))
		add(string.format(
			"gap_method=%s  fallback=%s  widths=%s  bands=%s",
			tostring(info.gap_method or "-"),
			tostring(info.gap_fallback),
			tostring(info.gap_widths or "-"),
			tostring(info.gap_bands or "-")
		))
		add(string.format(
			"layers Seg/Mist/Front/Tail=%s/%s/%s/%s",
			tostring(info.wall_layer_seg),
			tostring(info.wall_layer_mist),
			tostring(info.wall_layer_front),
			tostring(info.wall_layer_tail)
		))
		add("")
		add("-- 站位 / 后撤 --")
		add(string.format(
			"retreat age=%s/%s  req=%s  tgt=%s  done=%s",
			tostring(info.retreat_age or "-"),
			tostring(info.retreat_frames or "-"),
			fmt_num(info.retreat_request_dist or info.stance_request_dist, 0),
			fmt_num(info.retreat_target_dist or info.stance_target_dist, 0),
			fmt_num(info.retreat_completed_dist or info.stance_completed_dist, 0)
		))
		add(string.format(
			"from=%s  to=%s",
			tostring(info.retreat_from or info.stance_from or "-"),
			tostring(info.retreat_to or info.stance_to or "-")
		))
		add("")
		add("-- 风切血雨 --")
		add(string.format(
			"anim=%s frame=%s  cast=%s@%s  volley=%s fire_clock=%s",
			tostring(info.boss_anim or "-"),
			tostring(info.boss_anim_frame or "-"),
			tostring(info.split_cast_anim or info.cast_anim_started),
			tostring(info.split_cast_play_clock or "-"),
			tostring(info.split_volley_fired),
			tostring(info.split_volley_fire_clock or "-")
		))
		add(string.format(
			"Shoot_event=%s  fallback=%s  fired=%s  next_cut=%s  last_cut=%s",
			tostring(info.split_shoot_event_clock or "-"),
			tostring(info.split_shoot_fallback),
			tostring(info.split_fired or "-"),
			tostring(info.split_next_cut or "-"),
			tostring(info.split_last_cut_clock or "-")
		))
		add(string.format(
			"aim_locked=%s  base_ang=%s  downward=%s  origin=%s",
			tostring(info.split_aim_locked),
			fmt_num(info.split_base_angle, 1),
			tostring(info.split_fire_downward),
			tostring(info.split_fire_origin or "-")
		))
		add(string.format(
			"retreat_dir=%s  shortened=%s  skipped=%s",
			tostring(info.split_retreat_dir or info.retreat_to or "-"),
			tostring(info.split_retreat_shortened),
			tostring(info.split_retreat_skipped)
		))
		add("targets=" .. tostring(info.split_targets or info.split_aim_target or "-"))
		add(string.format(
			"triangle edges=%s  area=%s  scale=%s",
			tostring(info.split_triangle_edges or "-"),
			fmt_num(info.split_triangle_area, 0),
			fmt_num(info.split_triangle_scale, 1)
		))
		add("mains=" .. tostring(info.split_projectile_positions or "-"))
		add("plan=" .. tostring(info.split_main_plan or "-"))
		add("states=" .. tostring(info.split_main_states or "-"))
		add("clocks=" .. tostring(info.split_main_clocks or "-"))
		add(string.format(
			"cut_dirs plan=%s  actual=%s",
			tostring(info.split_cut_dir_plan or "-"),
			tostring(info.split_cut_angs or "-")
		))
		add(string.format(
			"logic=%s  visual=%s",
			tostring(info.split_last_logic or "-"),
			tostring(info.split_last_visual or "-")
		))
		add("cut_fx=" .. tostring(info.split_cut_fx or "-"))
		add("cuts=" .. tostring(info.split_diag or "-"))
		add("bursts=" .. tostring(info.split_bursts or "-"))
		add(string.format(
			"child_plan=%s  alive=%s  spd_avg=%s",
			tostring(info.split_child_counts or "-"),
			tostring(info.split_child_alive or "-"),
			fmt_num(info.split_child_speed_avg, 1)
		))
		add("")
		add("-- 骤风 --")
		add(string.format(
			"spawned=%s  alive=%s  visible=%s  rising=%s  offscreen=%s  failed=%s",
			tostring(info.gust_spawned or "-"),
			tostring(info.gust_alive or "-"),
			tostring(info.gust_visible_now or "-"),
			tostring(info.gust_rising_now or "-"),
			tostring(info.gust_offscreen_now or "-"),
			tostring(info.gust_spawn_failed or "-")
		))
		add(string.format(
			"mode=%s  burst=%s/%s  batch=#%s n=%s(%s)  since=%s/%s  no_spawn=%s",
			tostring(info.gust_spawn_mode or "-"),
			tostring(info.gust_burst_spawned or "-"),
			tostring(info.gust_burst_total or "-"),
			tostring(info.gust_batch_index or "-"),
			tostring(info.gust_last_batch_count or "-"),
			tostring(info.gust_last_batch_mode or "-"),
			tostring(info.gust_frames_since_batch or "-"),
			tostring(info.gust_batch_interval or "-"),
			tostring(info.gust_frames_without_spawn or "-")
		))
		add("batch_pos=" .. tostring(info.gust_last_batch_pos or "-"))
		add(string.format(
			"dist_avg=%s  upwind_avg=%s  reassigned=%s",
			fmt_num(info.gust_last_dist_avg, 0),
			fmt_num(info.gust_last_upwind_avg, 0),
			tostring(info.gust_reassigned or "-")
		))
		add("batch_recent=" .. tostring(info.gust_batch_recent or "-"))
		add(string.format(
			"sources ext=%s arena=%s bias=%s  ratios ext=%s bias=%s",
			tostring(info.gust_spawned_external or "-"),
			tostring(info.gust_spawned_arena or "-"),
			tostring(info.gust_spawned_player or "-"),
			info.gust_external_spawn_ratio and string.format("%.0f%%", info.gust_external_spawn_ratio * 100) or "-",
			info.gust_player_spawn_ratio and string.format("%.0f%%", info.gust_player_spawn_ratio * 100) or "-"
		))
		add(string.format(
			"entered_view=%s  from_out=%s/%s  enter_delay_avg=%s  rising=%s  removed_before=%s",
			tostring(info.gust_entered_view or "-"),
			tostring(info.gust_entered_from_outside or "-"),
			tostring(info.gust_spawned_outside or "-"),
			fmt_num(info.gust_enter_delay_avg, 1),
			tostring(info.gust_visible_rising or "-"),
			tostring(info.gust_removed_before_view or "-")
		))
		add(string.format(
			"track_lock=%s  animStarts=%s  finished=%s",
			tostring(info.gust_track_lock),
			tostring(info.gust_anim_start_count or "-"),
			tostring(info.gust_anim_finished)
		))
		add(string.format(
			"first_spawn frame=%s phase=%s band=%s",
			tostring(info.gust_first_spawn_frame or "-"),
			tostring(info.gust_first_spawn_phase or "-"),
			tostring(info.gust_first_spawn_band or "-")
		))
		add(string.format(
			"last_spawn frame=%s phase=%s age=%s  span=%s",
			tostring(info.gust_last_spawn_frame or "-"),
			tostring(info.gust_last_spawn_phase or "-"),
			tostring(info.gust_last_spawn_age or "-"),
			tostring(info.gust_spawn_span or "-")
		))
		add(string.format(
			"bands %s  visible_spawn=%s  upwind=%s",
			tostring(info.gust_band_counts or "-"),
			info.gust_visible_spawn_ratio and string.format("%.0f%%", info.gust_visible_spawn_ratio * 100) or "-",
			info.gust_upwind_ratio and string.format("%.0f%%", info.gust_upwind_ratio * 100) or "-"
		))
		add("")
		add("-- Arena Deep --")
		add(string.format(
			"screen=%sx%s  diameter=%s  room_span=%s",
			tostring(info.arena_screen_w or "-"),
			tostring(info.arena_screen_h or "-"),
			fmt_num(info.arena_screen_diameter, 0),
			fmt_num(info.arena_room_span, 0)
		))
		add(string.format(
			"deep_scale=%s  deep_span=%s  cover=%s",
			fmt_num(info.arena_deep_scale, 3),
			fmt_num(info.arena_deep_span, 0),
			fmt_num(info.arena_deep_cover, 2)
		))
		return table.concat(lines, "\n")
	end

end

return {
	register = register,
}
