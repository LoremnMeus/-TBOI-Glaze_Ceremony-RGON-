-- Zennith P1 wind-cut blood rain
-- Behavior-equivalent extract from combat_p1.lua (structural only).

local function register(Env)
	function Env.ease_out_quad(t)
		if t < 0 then return 0 end
		if t > 1 then return 1 end
		return 1 - (1 - t) * (1 - t)
	end
	-- ---------- wind_split (Wind Split V2: 风切血雨) ----------

	--- Shuffle three slash templates for this attack (distinct poses, not parallel cuts).
	function Env.roll_split_cut_dirs(sess)
		local templates = Env.SPLIT_CUT_TEMPLATES or {-45, 45, -90}
		local dirs = {templates[1], templates[2], templates[3]}
		for i = #dirs, 2, -1 do
			local j = 1 + math.floor(Env.boss_rand(sess) * i)
			if j < 1 then j = 1 end
			if j > i then j = i end
			dirs[i], dirs[j] = dirs[j], dirs[i]
		end
		local out = {}
		local labels = {}
		for i = 1, 3 do
			local jitter = (Env.boss_rand(sess) * 2 - 1) * 12
			out[i] = (dirs[i] or -90) + jitter
			labels[i] = string.format("%.0f", out[i])
		end
		return out, table.concat(labels, "/")
	end

	function Env.setup_split(sess)
		local boss = sess.boss
		local player = Env.auxi.get_acceptible_target(boss) or Game():GetPlayer(0)
		local aim = player and (player.Position - boss.Position) or Vector(0, 1)
		if aim:Length() < 1 then aim = Vector(0, 1) end
		aim = aim:Normalized()
		local hint = aim:GetAngleDegrees()
		local cut_dirs, cut_dir_list = Env.roll_split_cut_dirs(sess)
		sess.meta = {
			fired = 0,
			aim_locked = false,
			wind_hint_ang = hint,
			mains = {},
			bursts = {},
			volley_fired = false,
			volley_fire_clock = nil,
			shoot_event_clock = nil,
			shoot_fallback = false,
			next_cut_idx = 1,
			last_cut_clock = nil,
			cut_fx = {},
			cut_dirs = cut_dirs,
			cut_dir_list = cut_dir_list,
			actual_cut_angs = {},
			child_counts = {
				4 + math.floor(Env.boss_rand(sess) * 2),
				5 + math.floor(Env.boss_rand(sess) * 2),
				6 + math.floor(Env.boss_rand(sess) * 3),
			},
		}
		sess.wind_target = Env.travel_to_wind_ang(hint)
		sess.wind_from = sess.ambient_ang or 0
	end

	function Env.clamp_aim_to_center_box(pt, tl, br, center)
		local box_w = (br.X - tl.X) * Env.SPLIT_AIM_BOX
		local box_h = (br.Y - tl.Y) * Env.SPLIT_AIM_BOX
		local half_w = box_w * 0.5
		local half_h = box_h * 0.5
		local x = math.max(center.X - half_w, math.min(center.X + half_w, pt.X))
		local y = math.max(center.Y - half_h, math.min(center.Y + half_h, pt.Y))
		return Vector(x, y)
	end

	function Env.split_triangle_metrics(pts)
		local e12 = (pts[1] - pts[2]):Length()
		local e23 = (pts[2] - pts[3]):Length()
		local e31 = (pts[3] - pts[1]):Length()
		local area = math.abs(
			(pts[1].X * (pts[2].Y - pts[3].Y)
				+ pts[2].X * (pts[3].Y - pts[1].Y)
				+ pts[3].X * (pts[1].Y - pts[2].Y)) * 0.5
		)
		return e12, e23, e31, area
	end

	function Env.split_points_in_legal(pts, tl, br, center, min_front_y, pad)
		pad = pad or 28
		local box_w = (br.X - tl.X) * Env.SPLIT_AIM_BOX
		local box_h = (br.Y - tl.Y) * Env.SPLIT_AIM_BOX
		local half_w = box_w * 0.5
		local half_h = box_h * 0.5
		local minx = math.max(tl.X + pad, center.X - half_w)
		local maxx = math.min(br.X - pad, center.X + half_w)
		local miny = math.max(min_front_y, center.Y - half_h)
		local maxy = math.min(br.Y - pad, center.Y + half_h)
		for i = 1, 3 do
			local p = pts[i]
			if p.X < minx or p.X > maxx or p.Y < miny or p.Y > maxy then
				return false
			end
		end
		return true, minx, maxx, miny, maxy
	end

	--- Build three hold targets as one wide triangle (scale/shift as a whole).
	function Env.build_split_triangle(sess, aim_pt, base_ang, tl, br, center, min_front_y, player)
		-- Local (fwd, side) vertices: left-back, forward apex, right-mid (asymmetric wide).
		local local_shape = {
			{f = 0.28, s = -1.00},
			{f = 1.00, s = 0.08},
			{f = 0.48, s = 0.96},
		}
		local min_edge = Env.SPLIT_TRI_MIN_EDGE or 55
		local min_area = Env.SPLIT_TRI_MIN_AREA or 1200
		local base_scale = Env.SPLIT_TRI_BASE_SCALE or 62
		local ang_try = {0, -12, 12, -22, 22, -8, 8}
		local scale_try = {1.0, 0.92, 0.84, 0.76, 0.68, 0.60}
		local best = nil
		local best_score = -1e9

		for ai = 1, #ang_try do
			local ang = base_ang + ang_try[ai]
			if ang < 40 then ang = 40 end
			if ang > 140 then ang = 140 end
			local fwd = Vector.FromAngle(ang)
			local side = Vector(-fwd.Y, fwd.X)
			for si = 1, #scale_try do
				local scale = base_scale * scale_try[si]
				local origin = Vector(aim_pt.X, aim_pt.Y)
				-- Whole-shape player push: shift origin, never collapse points independently.
				if player then
					local probe = {}
					for i = 1, 3 do
						local sh = local_shape[i]
						probe[i] = origin + fwd * (sh.f * scale) + side * (sh.s * scale)
					end
					local push = Vector(0, 0)
					for i = 1, 3 do
						local dlt = probe[i] - player.Position
						local dist = dlt:Length()
						local need = Env.SPLIT_SAFE_PLAYER or 52
						if dist < need then
							local dir = dist > 1 and dlt:Normalized() or side
							push = push + dir * (need - dist)
						end
					end
					if push:Length() > 1 then
						origin = origin + push:Resized(math.min(36, push:Length() * 0.55))
					end
				end
				local pts = {}
				for i = 1, 3 do
					local sh = local_shape[i]
					pts[i] = origin + fwd * (sh.f * scale) + side * (sh.s * scale)
				end
				-- Fit as a whole: shrink toward centroid if any vertex is out of legal box.
				local ok = Env.split_points_in_legal(pts, tl, br, center, min_front_y, 28)
				if not ok then
					local cx = (pts[1].X + pts[2].X + pts[3].X) / 3
					local cy = (pts[1].Y + pts[2].Y + pts[3].Y) / 3
					local centroid = Vector(cx, cy)
					local fitted = false
					for shrink = 1, 6 do
						local u = 1 - shrink * 0.08
						for i = 1, 3 do
							pts[i] = centroid + (pts[i] - centroid) * u
						end
						if Env.split_points_in_legal(pts, tl, br, center, min_front_y, 28) then
							fitted = true
							break
						end
					end
					if not fitted then
						local boxed = Env.clamp_aim_to_center_box(centroid, tl, br, center)
						if boxed.Y < min_front_y then
							boxed = Vector(boxed.X, min_front_y + 8)
						end
						local s2 = scale * 0.55
						for i = 1, 3 do
							local sh = local_shape[i]
							pts[i] = boxed + fwd * (sh.f * s2) + side * (sh.s * s2)
						end
						fitted = Env.split_points_in_legal(pts, tl, br, center, min_front_y, 24)
					end
					ok = fitted
				end
				if ok then
					local e12, e23, e31, area = Env.split_triangle_metrics(pts)
					local min_e = math.min(e12, e23, e31)
					local peri = e12 + e23 + e31
					local valid = min_e >= min_edge * 0.85
						and area >= min_area * 0.7
						and area >= peri * 2.2
					if valid then
						local score = area * 0.08 + min_e * 2.5
						local front_bonus = 0
						for i = 1, 3 do
							if pts[i].Y >= min_front_y then front_bonus = front_bonus + 8 end
						end
						score = score + front_bonus
						if score > best_score then
							best_score = score
							best = {
								pts = {
									Vector(pts[1].X, pts[1].Y),
									Vector(pts[2].X, pts[2].Y),
									Vector(pts[3].X, pts[3].Y),
								},
								ang = ang,
								origin = origin,
								edges = {e12, e23, e31},
								area = area,
								scale = scale,
							}
						end
					end
				end
			end
		end
		return best
	end

	--- Lock fire axis + three hold targets as one triangle ahead of Zennith.
	function Env.lock_split_aim(sess)
		local meta = sess.meta
		if not meta or meta.aim_locked then return end
		local boss = sess.boss
		if not Env.living(boss) then return end
		local tl, br, center = Env.room_bounds()
		local player = Env.auxi.get_acceptible_target(boss) or Game():GetPlayer(0)
		local p_player = player and player.Position or center
		local blend = center * Env.SPLIT_AIM_CENTER_W + p_player * Env.SPLIT_AIM_PLAYER_W
		local aim_pt = Env.clamp_aim_to_center_box(blend, tl, br, center)
		local min_front_y = boss.Position.Y + 48
		if aim_pt.Y < min_front_y then
			aim_pt = Vector(
				aim_pt.X,
				math.min(br.Y - 40, math.max(min_front_y, center.Y + 16))
			)
		end
		aim_pt = Env.clamp_aim_to_center_box(aim_pt, tl, br, center)
		local delta = aim_pt - boss.Position
		if delta.Y < 28 then
			aim_pt = Vector(
				math.max(tl.X + 48, math.min(br.X - 48, center.X + (p_player.X - center.X) * 0.28)),
				math.min(br.Y - 40, math.max(min_front_y, center.Y + 24))
			)
			aim_pt = Env.clamp_aim_to_center_box(aim_pt, tl, br, center)
			delta = aim_pt - boss.Position
		end
		if delta:Length() < 1 or delta.Y <= 0 then
			delta = Vector(0, 1)
			aim_pt = Vector(boss.Position.X, math.min(br.Y - 40, boss.Position.Y + 90))
		end
		local base = delta:GetAngleDegrees()
		if base < 45 then base = 45 end
		if base > 135 then base = 135 end

		local tri = Env.build_split_triangle(sess, aim_pt, base, tl, br, center, min_front_y, player)
		local targets
		local target_strs = {}
		if tri and tri.pts then
			targets = tri.pts
			base = tri.ang or base
			meta.triangle_edges = string.format(
				"%.0f/%.0f/%.0f",
				tri.edges[1], tri.edges[2], tri.edges[3]
			)
			meta.triangle_area = tri.area
			meta.triangle_scale = tri.scale
			aim_pt = tri.origin or aim_pt
		else
			-- Extremely constrained room: still place a minimal staggered set without per-point collapse.
			local fwd = Vector.FromAngle(base)
			local side = Vector(-fwd.Y, fwd.X)
			local o = Env.clamp_aim_to_center_box(
				Vector(aim_pt.X, math.max(min_front_y + 10, aim_pt.Y)),
				tl, br, center
			)
			targets = {
				o + fwd * 20 + side * (-36),
				o + fwd * 54 + side * 4,
				o + fwd * 28 + side * 38,
			}
			local e12, e23, e31, area = Env.split_triangle_metrics(targets)
			meta.triangle_edges = string.format("%.0f/%.0f/%.0f", e12, e23, e31)
			meta.triangle_area = area
			meta.triangle_scale = 0
		end
		for i = 1, 3 do
			target_strs[i] = string.format("%.0f,%.0f", targets[i].X, targets[i].Y)
		end
		meta.aim_locked = true
		meta.base_ang = base
		meta.aim_target = Vector(aim_pt.X, aim_pt.Y)
		meta.fire_origin = Vector(boss.Position.X, boss.Position.Y)
		meta.targets = targets
		meta.target_list = table.concat(target_strs, " | ")
		meta.fire_downward = true
		meta.split_projectile_positions = {}
		meta.split_diag = {}
		meta.cut_fx = {}
		sess.wind_target = Env.travel_to_wind_ang(base)
	end

	--- Projectile visual point for overlays (does not alter collision Position).
	--- Prefer live PositionOffset; if empty, derive height2offset_projectile(Height, FA).
	function Env.projectile_visual_point(ent)
		if not (ent and ent.Exists and ent:Exists()) then return nil end
		local po = ent.PositionOffset or Vector.Zero
		if math.abs(po.X) > 0.05 or math.abs(po.Y) > 0.05 then
			return ent.Position + po
		end
		local h = ent.Height
		if h ~= nil and Env.auxi.height2offset_projectile then
			local fa = ent.FallingAccel or -0.1
			local oy = Env.auxi.height2offset_projectile(h, fa)
			return ent.Position + Vector(0, oy)
		end
		return Vector(ent.Position.X, ent.Position.Y)
	end

	function Env.find_split_main(sess, shot_idx)
		for _, ent in pairs(sess.objects) do
			if ent and ent.Exists and ent:Exists() then
				local d = ent:GetData()
				if d[Env.M.own_key .. "split_parent"]
					and (d[Env.M.own_key .. "shot_idx"] or 0) == shot_idx
				then
					return ent
				end
			end
		end
		return nil
	end

	function Env.split_cut_tip(cut)
		if not cut or not cut.target or not cut.dir then return nil end
		local dur = math.max(1, cut.duration or 5)
		local u = math.min(1, (cut.age or 0) / dur)
		local approach = cut.approach or 72
		local exit = cut.exit or 80
		-- Leading tip rides the front of a short blade.
		local mid = cut.target - cut.dir * approach + cut.dir * ((approach + exit) * u)
		local half = (cut.blade_len or 38) * 0.42
		return mid + cut.dir * half, mid
	end

	--- Pure-visual short blade + trail. Hit when tip crosses visual center.
	function Env.spawn_split_cut_fx(sess, visual_target, cut_ang, shot_idx, logic_pos)
		local meta = sess.meta
		if not meta then return nil end
		meta.cut_fx = meta.cut_fx or {}
		local dir = Vector.FromAngle(cut_ang or 0)
		if dir:Length() < 0.1 then dir = Vector(1, 0) end
		dir = dir:Normalized()
		local approach = Env.SPLIT_CUT_APPROACH or 72
		local tip0 = visual_target - dir * approach
		local cut = {
			shot_idx = shot_idx or 0,
			target = Vector(visual_target.X, visual_target.Y),
			logic_pos = logic_pos and Vector(logic_pos.X, logic_pos.Y) or nil,
			dir = dir,
			ang = cut_ang or 0,
			age = 0,
			duration = Env.SPLIT_CUT_DURATION or 5,
			trail_life = Env.SPLIT_CUT_TRAIL or 4,
			approach = approach,
			exit = Env.SPLIT_CUT_EXIT or 80,
			blade_len = Env.SPLIT_CUT_BLADE_LEN or 38,
			hit = false,
			done = false,
			prev_along = -approach,
			trail = {},
			create_clock = sess.clock or sess.age,
			hit_clock = nil,
			end_clock = nil,
			visual_target_str = string.format("%.0f,%.0f", visual_target.X, visual_target.Y),
			logic_pos_str = logic_pos and string.format("%.0f,%.0f", logic_pos.X, logic_pos.Y) or "-",
		}
		cut.trail[1] = {x = tip0.X, y = tip0.Y, a = 0.9}
		meta.cut_fx[#meta.cut_fx + 1] = cut
		return cut
	end

	function Env.spawn_split_shatter(sess, pos, height)
		local boss = sess.boss
		local n = Env.SPLIT_CUT_SHARD_N or 5
		for i = 1, n do
			local ang = (i - 0.5) / n * 360 + Env.boss_rand(sess) * 20
			local spd = 2.2 + Env.boss_rand(sess) * 3.5
			local q = Env.spawn_blade(boss, pos, Vector.FromAngle(ang) * spd, {
				damage = 0,
				scale = 0.38 + Env.boss_rand(sess) * 0.18,
				alpha = 0.95,
				anim = "BloodTear4",
				height = height or Env.M.HOLD_HEIGHT,
				wind_rate = nil,
			})
			if q then
				Env.track_obj(sess, q, "split_shatter")
				local d = q:GetData()
				d[Env.M.own_key .. "split_shatter"] = true
				d[Env.M.own_key .. "shatter_t"] = 0
				d[Env.RATE_KEY] = nil
				q.CollisionDamage = 0
				local spr = q:GetSprite()
				if spr then
					spr.Color = Color(1, 0.55, 0.55, 1, 0.25, 0.02, 0.02)
				end
			end
		end
	end

	function Env.spawn_split_fan(sess, parent, shot_idx)
		local boss = sess.boss
		local meta = sess.meta
		local d = parent:GetData()
		local pos = Vector(parent.Position.X, parent.Position.Y)
		local player = Env.auxi.get_acceptible_target(boss) or Game():GetPlayer(0)
		local toward = player and (player.Position - pos) or Vector.FromAngle(d[Env.M.own_key .. "split_ang"] or 90)
		if toward:Length() < 1 then toward = Vector(0, 1) end
		local center_ang = toward:GetAngleDegrees()
		local fan = Env.SPLIT_FAN_DEG + Env.boss_rand(sess) * 15
		local counts = meta.child_counts or {5, 6, 7}
		local n = counts[shot_idx] or (4 + shot_idx)
		local h = d[Env.HOLD_KEY] or Env.M.HOLD_HEIGHT
		meta.bursts = meta.bursts or {}
		meta.bursts[#meta.bursts + 1] = {
			idx = shot_idx,
			n = n,
			x = pos.X,
			y = pos.Y,
			clock = sess.clock or sess.age,
		}
		for i = 1, n do
			local t = (i - 0.5) / n - 0.5
			local ang = center_ang + t * fan
			local edge = 1 - math.abs(t) * 0.28
			local spd0 = Env.SPLIT_SPEED_START * (0.9 + 0.2 * edge)
			local spd1 = (Env.SPLIT_SPEED_END - 0.6 + Env.boss_rand(sess) * 1.4) * edge
			local vel = Vector.FromAngle(ang) * spd0
			local q = Env.spawn_blade(boss, pos + Vector.FromAngle(ang) * 3, vel, {
				damage = 0,
				scale = 0.72,
				alpha = 0.35,
				anim = "BloodTear6",
				height = h,
				wind_rate = Env.SPLIT_WIND_RATE * 0.3,
			})
			if q then
				Env.track_obj(sess, q, "split_child")
				local cd = q:GetData()
				cd[Env.M.own_key .. "split_child"] = true
				cd[Env.M.own_key .. "fan_age"] = 0
				cd[Env.M.own_key .. "fan_accel_need"] = 8 + math.floor(Env.boss_rand(sess) * 5)
				cd[Env.M.own_key .. "fan_spd0"] = spd0
				cd[Env.M.own_key .. "fan_spd1"] = spd1
				cd[Env.M.own_key .. "fan_ang"] = ang
				cd[Env.HOLD_KEY] = h
			end
		end
	end

	function Env.tick_split_children(sess)
		local blow = Env.wind_dir_vec(sess.ambient_ang or 0)
		for key, ent in pairs(sess.objects) do
			if not (ent and ent.Exists and ent:Exists()) then
				sess.objects[key] = nil
			else
				local d = ent:GetData()
				if d[Env.M.own_key .. "split_shatter"] then
					local t = (d[Env.M.own_key .. "shatter_t"] or 0) + 1
					d[Env.M.own_key .. "shatter_t"] = t
					ent.Velocity = ent.Velocity * 0.88
					ent.CollisionDamage = 0
					local spr = ent:GetSprite()
					if spr then
						local a = math.max(0, 1 - t * 0.18)
						spr.Color = Color(1, 0.5, 0.5, a, 0.2 * a, 0.02, 0.02)
						local sc = 0.45 * (1 - t * 0.08)
						spr.Scale = Vector(sc, sc)
					end
					if t >= 7 then
						ent:Remove()
						sess.objects[key] = nil
					end
				elseif d[Env.M.own_key .. "split_child"] then
					local t = (d[Env.M.own_key .. "fan_age"] or 0) + 1
					d[Env.M.own_key .. "fan_age"] = t
					local need = d[Env.M.own_key .. "fan_accel_need"] or Env.SPLIT_ACCEL_FRAMES
					local u = Env.ease_out_quad(math.min(1, t / need))
					local spd0 = d[Env.M.own_key .. "fan_spd0"] or Env.SPLIT_SPEED_START
					local spd1 = d[Env.M.own_key .. "fan_spd1"] or Env.SPLIT_SPEED_END
					local spd = spd0 + (spd1 - spd0) * u
					local ang = d[Env.M.own_key .. "fan_ang"]
					local base = ang and Vector.FromAngle(ang) or (
						ent.Velocity:Length() > 0.1 and ent.Velocity:Normalized() or blow
					)
					ent.Velocity = base:Resized(spd) + blow:Resized(0.08 + 0.18 * u)
					local spr = ent:GetSprite()
					if spr then
						local a = 0.35 + 0.65 * math.min(1, t / 6)
						local glow = 0.18 * (1 - u * 0.4)
						spr.Color = Color(1, 1, 1, a, glow, glow * 1.2, glow * 1.6)
						local sc = 0.72 + 0.18 * math.min(1, t / 8)
						spr.Scale = Vector(sc, sc)
					end
					if t < Env.SPLIT_CHILD_HARMLESS then
						ent.CollisionDamage = 0
						d[Env.RATE_KEY] = Env.SPLIT_WIND_RATE * 0.2
					else
						ent.CollisionDamage = 1
						d[Env.RATE_KEY] = Env.SPLIT_WIND_RATE * (0.35 + 0.25 * u)
					end
					if Env.out_of_room(ent.Position, Env.ROOM_EXIT_MARGIN) then
						ent:Remove()
						sess.objects[key] = nil
					end
				end
			end
		end
	end

	function Env.tick_split_mains(sess)
		local meta = sess.meta
		if not meta then return end
		for key, ent in pairs(sess.objects) do
			if not (ent and ent.Exists and ent:Exists()) then
				sess.objects[key] = nil
			else
				local d = ent:GetData()
				if d[Env.M.own_key .. "split_parent"] then
					local state = d[Env.M.own_key .. "split_state"] or "launch"
					local target = d[Env.M.own_key .. "split_target"]
					d[Env.M.own_key .. "split_age"] = (d[Env.M.own_key .. "split_age"] or 0) + 1
					if state == "launch" or state == "decelerate" then
						if not target then
							d[Env.M.own_key .. "split_state"] = "hold"
							d[Env.M.own_key .. "hold_t"] = 0
						else
							local to = target - ent.Position
							local dist = to:Length()
							if state == "launch" then
								if dist < 30 then
									d[Env.M.own_key .. "split_state"] = "decelerate"
								else
									local launch = d[Env.M.own_key .. "launch_spd"] or 9
									ent.Velocity = to:Resized(launch)
								end
							end
							if d[Env.M.own_key .. "split_state"] == "decelerate" then
								local spd = math.max(0.6, ent.Velocity:Length() * 0.86)
								if dist < 10 or spd < 1.15 then
									ent.Velocity = Vector(0, 0)
									ent.Position = Vector(target.X, target.Y)
									d[Env.M.own_key .. "split_state"] = "hold"
									d[Env.M.own_key .. "hold_t"] = 0
									d[Env.M.own_key .. "arrive_clock"] = sess.clock or sess.age
									d[Env.RATE_KEY] = nil
									local idx = d[Env.M.own_key .. "shot_idx"] or 0
									if meta.mains and meta.mains[idx] then
										meta.mains[idx].arrived = true
										meta.mains[idx].arrive_clock = d[Env.M.own_key .. "arrive_clock"]
										meta.mains[idx].state = "hold"
									end
								else
									ent.Velocity = to:Resized(spd)
								end
							end
						end
					elseif state == "hold" then
						ent.Velocity = Vector(0, 0)
						if target then
							ent.Position = Vector(target.X, target.Y)
						end
						local ht = (d[Env.M.own_key .. "hold_t"] or 0) + 1
						d[Env.M.own_key .. "hold_t"] = ht
						if ht == 1 then
							d[Env.M.own_key .. "hold_start_clock"] = sess.clock or sess.age
						end
						local need = d[Env.M.own_key .. "hold_need"] or Env.SPLIT_HOLD_FRAMES
						local next_cut = meta.next_cut_idx or 1
						local is_next = (d[Env.M.own_key .. "shot_idx"] or 0) == next_cut
						local spr = ent:GetSprite()
						if spr then
							-- Blood-red body by default; briefly lift Glow when this main is next to cut.
							if is_next and ht >= need - 4 then
								local g = math.min(1, (ht - (need - 4)) / 4)
								spr.Color = Color(1, 1, 1, 1, 0.05 * g, 0.08 * g, 0.14 * g)
							else
								spr.Color = Color(1, 1, 1, 1, 0, 0, 0)
							end
						end
						if is_next and ht >= need - 3 and not d[Env.M.own_key .. "cut_warned"] then
							d[Env.M.own_key .. "cut_warned"] = true
							Env.boss_wind.pulse({intensity = 0.14})
						end
						-- Cut is scheduled by Env.try_split_cuts (sequential gap), not per-main auto.
					elseif state == "cutting" then
						-- Blade approaching; burst happens in Env.tick_split_cut_fx at hit_age.
						ent.Velocity = Vector(0, 0)
						if target then
							ent.Position = Vector(target.X, target.Y)
						end
						ent.CollisionDamage = 0
					end
				end
			end
		end
	end

	--- One Shoot event → three mains at once. Owned by movement Shoot poll.
	function Env.split_fire_volley(sess)
		local meta = sess.meta
		local boss = sess.boss
		if not meta or meta.volley_fired then return false end
		if not Env.living(boss) then return false end
		if not meta.aim_locked then
			Env.lock_split_aim(sess)
		end
		local targets = meta.targets or {}
		local fire_clock = sess.clock or sess.age
		meta.volley_fire_clock = fire_clock
		meta.split_projectile_positions = {}
		meta.mains = {}
		local spawned = 0
		for i = 1, 3 do
			local tgt = targets[i]
			local ang = meta.base_ang or 90
			if tgt then
				local delta = tgt - boss.Position
				if delta:Length() > 1 then
					ang = delta:GetAngleDegrees()
				end
			else
				local offsets = {-10, 0, 12}
				ang = (meta.base_ang or 90) + (offsets[i] or 0)
			end
			local dir = Vector.FromAngle(ang)
			local spawn_pos = boss.Position + dir * (14 + (i - 1) * 2)
			local launch_spd = 8.5 + Env.boss_rand(sess) * 1.4
			local scale = Env.SPLIT_MAIN_SCALE or 1.12
			local hold_need = Env.SPLIT_HOLD_FRAMES + math.floor(Env.boss_rand(sess) * 2)
			if i == 3 then
				scale = scale + 0.06
			end
			local q = Env.spawn_blade(boss, spawn_pos, dir * launch_spd, {
				damage = 1, scale = scale, alpha = 1, anim = "BloodTear8",
				wind_rate = nil,
			})
			if q then
				Env.track_obj(sess, q, "split_main")
				local d = q:GetData()
				d[Env.M.own_key .. "split_parent"] = true
				d[Env.M.own_key .. "split_state"] = "launch"
				d[Env.M.own_key .. "split_ang"] = ang
				d[Env.M.own_key .. "split_age"] = 0
				d[Env.M.own_key .. "shot_idx"] = i
				d[Env.M.own_key .. "launch_spd"] = launch_spd
				d[Env.M.own_key .. "hold_need"] = hold_need
				d[Env.M.own_key .. "main_scale"] = scale
				d[Env.M.own_key .. "fire_clock"] = fire_clock
				if tgt then
					d[Env.M.own_key .. "split_target"] = Vector(tgt.X, tgt.Y)
				end
				local spr = q:GetSprite()
				if spr then
					spr.Color = Color(1, 1, 1, 1, 0, 0, 0)
				end
				meta.split_projectile_positions[#meta.split_projectile_positions + 1] = {
					x = spawn_pos.X, y = spawn_pos.Y, ang = ang,
					tx = tgt and tgt.X or spawn_pos.X,
					ty = tgt and tgt.Y or spawn_pos.Y,
				}
				meta.mains[#meta.mains + 1] = {
					idx = i,
					state = "launch",
					fire_clock = fire_clock,
					scale = scale,
					hold_need = hold_need,
				}
				spawned = spawned + 1
			end
		end
		meta.fired = spawned
		meta.volley_fired = true
		meta.next_cut_idx = 1
		meta.last_cut_clock = nil
		return spawned > 0
	end

	function Env.split_all_mains_settled(sess)
		local meta = sess.meta
		if not meta or not meta.volley_fired then return false end
		local need = 3
		local settled = 0
		for _, ent in pairs(sess.objects) do
			if ent and ent.Exists and ent:Exists() then
				local d = ent:GetData()
				if d[Env.M.own_key .. "split_parent"] then
					local st = d[Env.M.own_key .. "split_state"]
					if st == "hold" or st == "cutting" or st == "cut" then
						settled = settled + 1
					end
				end
			end
		end
		-- Also count already-removed mains that finished (bursts recorded).
		local bursts = meta.bursts and #meta.bursts or 0
		if settled + bursts >= need then return true end
		return settled >= need
	end

	function Env.begin_split_cut(sess, ent)
		local meta = sess.meta
		local d = ent:GetData()
		if d[Env.M.own_key .. "split_state"] ~= "hold" then return false end
		local idx = d[Env.M.own_key .. "shot_idx"] or 0
		-- Distinct slash pose from attack shuffle — not split_ang+90 (which made parallel cuts).
		local cut_ang = (meta.cut_dirs and meta.cut_dirs[idx]) or -90
		local logic = d[Env.M.own_key .. "split_target"] or ent.Position
		local visual = Env.projectile_visual_point(ent) or logic
		d[Env.M.own_key .. "split_state"] = "cutting"
		d[Env.M.own_key .. "cut_t"] = 0
		d[Env.M.own_key .. "hold_end_clock"] = sess.clock or sess.age
		d[Env.M.own_key .. "cut_clock"] = sess.clock or sess.age
		d[Env.M.own_key .. "cut_hit"] = false
		d[Env.M.own_key .. "cut_ang"] = cut_ang
		ent.CollisionDamage = 0
		local cut = Env.spawn_split_cut_fx(sess, visual, cut_ang, idx, logic)
		if cut then
			d[Env.M.own_key .. "cut_fx_ref"] = cut
			meta.last_visual_target = cut.visual_target_str
			meta.last_logic_pos = cut.logic_pos_str
			local approach = cut.approach or 72
			local exit = cut.exit or 80
			cut.start_pos = cut.target - cut.dir * approach
			cut.end_pos = cut.target + cut.dir * exit
			cut.start_str = string.format("%.0f,%.0f", cut.start_pos.X, cut.start_pos.Y)
			cut.end_str = string.format("%.0f,%.0f", cut.end_pos.X, cut.end_pos.Y)
		end
		meta.actual_cut_angs = meta.actual_cut_angs or {}
		meta.actual_cut_angs[idx] = cut_ang
		meta.actual_cut_ang_list = string.format(
			"%.0f/%.0f/%.0f",
			meta.actual_cut_angs[1] or (meta.cut_dirs and meta.cut_dirs[1]) or 0,
			meta.actual_cut_angs[2] or (meta.cut_dirs and meta.cut_dirs[2]) or 0,
			meta.actual_cut_angs[3] or (meta.cut_dirs and meta.cut_dirs[3]) or 0
		)
		if meta.mains and meta.mains[idx] then
			meta.mains[idx].state = "cutting"
			meta.mains[idx].cut_clock = d[Env.M.own_key .. "cut_clock"]
			meta.mains[idx].cut_ang = cut_ang
		end
		meta.last_cut_clock = sess.clock or sess.age
		meta.next_cut_idx = (meta.next_cut_idx or idx) + 1
		return true
	end

	function Env.apply_split_cut_hit(sess, cut)
		if not cut or cut.hit then return false end
		cut.hit = true
		cut.hit_clock = sess.clock or sess.age
		local meta = sess.meta
		local shot_idx = cut.shot_idx or 0
		local ent = Env.find_split_main(sess, shot_idx)
		if not ent then return false end
		local d = ent:GetData()
		if d[Env.M.own_key .. "cut_hit"] then return false end
		d[Env.M.own_key .. "cut_hit"] = true
		d[Env.M.own_key .. "burst_clock"] = cut.hit_clock
		local burst_pos = Vector(ent.Position.X, ent.Position.Y)
		local h = d[Env.HOLD_KEY] or Env.M.HOLD_HEIGHT
		Env.spawn_split_shatter(sess, burst_pos, h)
		Env.spawn_split_fan(sess, ent, shot_idx)
		meta.split_diag = meta.split_diag or {}
		meta.split_diag[#meta.split_diag + 1] = string.format(
			"#%d create@%s hit@%s burst@%s tip_cross visual=%s logic=%s n=%d",
			shot_idx,
			tostring(cut.create_clock or "-"),
			tostring(cut.hit_clock or "-"),
			tostring(d[Env.M.own_key .. "burst_clock"] or "-"),
			tostring(cut.visual_target_str or "-"),
			tostring(cut.logic_pos_str or "-"),
			(meta.child_counts and meta.child_counts[shot_idx]) or 0
		)
		if meta.mains and meta.mains[shot_idx] then
			meta.mains[shot_idx].state = "burst"
			meta.mains[shot_idx].burst_clock = cut.hit_clock
		end
		local key = Env.ptr(ent)
		ent:Remove()
		if key and sess.objects then
			sess.objects[key] = nil
		end
		return true
	end

	function Env.tick_split_cut_fx(sess)
		local meta = sess.meta
		if not meta or not meta.cut_fx then return end
		local alive = {}
		for i = 1, #meta.cut_fx do
			local cut = meta.cut_fx[i]
			if cut and not cut.done then
				cut.age = (cut.age or 0) + 1
				-- Keep target on live projectile visual center until hit.
				if not cut.hit then
					local main = Env.find_split_main(sess, cut.shot_idx or 0)
					if main then
						local vis = Env.projectile_visual_point(main)
						if vis then
							cut.target = vis
							cut.visual_target_str = string.format("%.0f,%.0f", vis.X, vis.Y)
						end
						cut.logic_pos = Vector(main.Position.X, main.Position.Y)
						cut.logic_pos_str = string.format("%.0f,%.0f", main.Position.X, main.Position.Y)
					end
				end
				local tip = Env.split_cut_tip(cut)
				if tip then
					local along = (tip - cut.target):Dot(cut.dir)
					cut.tip_pos = tip
					cut.tip_str = string.format("%.0f,%.0f", tip.X, tip.Y)
					cut.trail = cut.trail or {}
					cut.trail[#cut.trail + 1] = {x = tip.X, y = tip.Y, a = 1}
					while #cut.trail > 6 do
						table.remove(cut.trail, 1)
					end
					if not cut.hit then
						local prev = cut.prev_along
						if prev ~= nil and prev < 0 and along >= 0 then
							Env.apply_split_cut_hit(sess, cut)
						elseif cut.age >= (cut.duration or 5) and not cut.hit then
							-- Bounded recovery if frame skip missed the zero-cross.
							Env.apply_split_cut_hit(sess, cut)
						end
						cut.prev_along = along
					end
				end
				local life = (cut.duration or 5) + (cut.trail_life or 4)
				if cut.age >= life then
					cut.done = true
					cut.end_clock = sess.clock or sess.age
				else
					alive[#alive + 1] = cut
				end
			end
		end
		meta.cut_fx = alive
	end

	--- Sequential wind cuts after all mains settle; gap ≈ SPLIT_CUT_GAP.
	function Env.try_split_cuts(sess)
		local meta = sess.meta
		if not meta or not meta.volley_fired then return end
		local next_idx = meta.next_cut_idx or 1
		if next_idx > 3 then return end
		if next_idx == 1 then
			if not Env.split_all_mains_settled(sess) then return end
		else
			local gap = Env.SPLIT_CUT_GAP or 12
			local last = meta.last_cut_clock
			if last and (sess.clock or 0) < last + gap then return end
		end
		for _, ent in pairs(sess.objects) do
			if ent and ent.Exists and ent:Exists() then
				local d = ent:GetData()
				if d[Env.M.own_key .. "split_parent"]
					and (d[Env.M.own_key .. "shot_idx"] or 0) == next_idx
					and d[Env.M.own_key .. "split_state"] == "hold"
				then
					local ht = d[Env.M.own_key .. "hold_t"] or 0
					local need = d[Env.M.own_key .. "hold_need"] or Env.SPLIT_HOLD_FRAMES
					if ht >= need then
						Env.begin_split_cut(sess, ent)
					end
					return
				end
			end
		end
	end

	function Env.tick_split(sess)
		if sess.phase == "wind_shift" and sess.age == 1 then
			Env.setup_split(sess)
		end
		local meta = sess.meta
		if sess.phase == "form" and sess.age == 1 then
			Env.start_split_retreat(sess)
		end
		if meta and not meta.aim_locked and not sess.retreat then
			if sess.phase == "form" or sess.phase == "release" then
				Env.lock_split_aim(sess)
			end
		end
		if sess.phase == "form" or sess.phase == "release" then
			Env.tick_split_mains(sess)
			Env.try_split_cuts(sess)
			Env.tick_split_cut_fx(sess)
			Env.tick_split_children(sess)
		end
		if sess.phase == "dissolve" then
			Env.tick_split_mains(sess)
			Env.try_split_cuts(sess)
			Env.tick_split_cut_fx(sess)
			Env.tick_split_children(sess)
			if sess.age == 1 then
				Env.release_objects(sess, "split")
			end
		end
	end

end

return {
	register = register,
}
