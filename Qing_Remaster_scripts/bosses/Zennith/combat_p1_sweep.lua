-- Zennith P1 wind wall / sweep attack
-- Behavior-equivalent extract from combat_p1.lua (structural only).

local function register(Env)
	function Env.blend_dir_degrees(a_deg, b_deg, wa, wb)
		wa = wa or 0.5
		wb = wb or 0.5
		local va = Vector.FromAngle(a_deg) * wa
		local vb = Vector.FromAngle(b_deg) * wb
		local v = va + vb
		if v:Length() < 0.001 then
			return a_deg
		end
		return v:GetAngleDegrees()
	end
	function Env.pick_two_gaps(sess, y0, y1)
		local span = math.max(120, y1 - y0)
		local min_gap = 42
		local max_gap = 78
		local min_sep = 30
		local margin = 6
		local mode = Env.boss_rand(sess)
		-- Prefer distinct spatial pairs so walls don't all look "upper / mid / lower thirds".
		local function sample_center(lo_frac, hi_frac, w)
			local lo = y0 + margin + w * 0.5 + span * lo_frac
			local hi = y0 + span * hi_frac - margin - w * 0.5
			if hi <= lo then
				return y0 + span * ((lo_frac + hi_frac) * 0.5)
			end
			return lo + Env.boss_rand(sess) * (hi - lo)
		end
		local gaps = nil
		local method = "free2"
		for _ = 1, 72 do
			local w1 = min_gap + Env.boss_rand(sess) * (max_gap - min_gap)
			local w2 = min_gap + Env.boss_rand(sess) * (max_gap - min_gap)
			local c1, c2
			if mode < 0.34 then
				-- Near-top + lower half
				c1 = sample_center(0.00, 0.38, w1)
				c2 = sample_center(0.45, 0.98, w2)
			elseif mode < 0.67 then
				-- Upper-mid + near-bottom
				c1 = sample_center(0.08, 0.48, w1)
				c2 = sample_center(0.55, 1.00, w2)
			else
				-- Fully free
				c1 = sample_center(0.00, 1.00, w1)
				c2 = sample_center(0.00, 1.00, w2)
			end
			if math.abs(c1 - c2) >= (w1 + w2) * 0.5 + min_sep then
				gaps = {
					{y0 = c1 - w1 * 0.5, y1 = c1 + w1 * 0.5},
					{y0 = c2 - w2 * 0.5, y1 = c2 + w2 * 0.5},
				}
				table.sort(gaps, function(a, b) return a.y0 < b.y0 end)
				-- Clamp into hit range.
				for i = 1, 2 do
					gaps[i].y0 = math.max(y0 + margin, gaps[i].y0)
					gaps[i].y1 = math.min(y1 - margin, gaps[i].y1)
				end
				if gaps[2].y0 - gaps[1].y1 >= min_sep * 0.7
					and gaps[1].y1 - gaps[1].y0 >= 38
					and gaps[2].y1 - gaps[2].y0 >= 38 then
					break
				end
				gaps = nil
			end
		end
		if not gaps then
			-- Soft recover: still random, just force separation — never a fixed layout table.
			method = "free2_sep"
			local w1 = 48 + Env.boss_rand(sess) * 18
			local w2 = 48 + Env.boss_rand(sess) * 18
			local c1 = sample_center(0.02, 0.40, w1)
			local c2 = sample_center(0.55, 0.98, w2)
			if c2 < c1 then
				c1, c2 = c2, c1
				w1, w2 = w2, w1
			end
			gaps = {
				{y0 = c1 - w1 * 0.5, y1 = c1 + w1 * 0.5},
				{y0 = c2 - w2 * 0.5, y1 = c2 + w2 * 0.5},
			}
		end
		if sess and sess.meta then
			sess.meta.gap_fallback = (method == "free2_sep")
			sess.meta.gap_method = method
			sess.meta.gap_widths = string.format(
				"%.0f,%.0f",
				gaps[1].y1 - gaps[1].y0,
				gaps[2].y1 - gaps[2].y0
			)
			sess.meta.gap_bands = string.format(
				"top=%.0f mid=%.0f bot=%.0f",
				gaps[1].y0 - y0,
				gaps[2].y0 - gaps[1].y1,
				y1 - gaps[2].y1
			)
		end
		return gaps
	end

	-- Projectile lifecycle (clear/release/spawn_blade/out_of_*) lives in combat_p1_projectiles.lua.
	-- Do not redefine those APIs here — sweep.register runs after projectiles and would overwrite.

	function Env.y_in_gap(wall, y)
		local gaps = wall.gaps or {}
		for i = 1, #gaps do
			local g = gaps[i]
			if y >= g.y0 and y <= g.y1 then return true end
		end
		return false
	end

	function Env.build_bands(y0, y1, gaps)
		local cuts = {{y = y0, open = true}}
		for i = 1, #gaps do
			cuts[#cuts + 1] = {y = gaps[i].y0, open = false}
			cuts[#cuts + 1] = {y = gaps[i].y1, open = true}
		end
		cuts[#cuts + 1] = {y = y1, open = false}
		table.sort(cuts, function(a, b) return a.y < b.y end)
		local bands = {}
		local open = true
		local start = y0
		for i = 1, #cuts do
			local c = cuts[i]
			if open and c.y > start + 6 then
				bands[#bands + 1] = {y0 = start, y1 = c.y}
			end
			start = c.y
			open = c.open
		end
		return bands
	end

	function Env.setup_wall(sess, opts)
		opts = opts or {}
		local tl, br = Env.room_bounds()
		-- travel_dir: +1 = L→R (spawn left), -1 = R→L (spawn right).
		local dir = opts.travel_dir
		if dir ~= 1 and dir ~= -1 then
			if opts.left ~= nil then
				dir = opts.left and 1 or -1
			elseif sess.force_travel_dir == 1 or sess.force_travel_dir == -1 then
				dir = sess.force_travel_dir
			else
				dir = (Env.boss_rand(sess) < 0.5) and 1 or -1
			end
		end
		local travel_ang = (dir > 0) and 0 or 180
		local wind_ang = Env.travel_to_wind_ang(travel_ang)
		-- Hit covers full combat floor; visuals overscan past the screen edges.
		local hit_y0 = tl.Y
		local hit_y1 = br.Y
		local vis_y0 = tl.Y - Env.WALL_OVERSCAN
		local vis_y1 = br.Y + Env.WALL_OVERSCAN
		local thickness = 220 + Env.boss_rand(sess) * 80
		local trail_frac = 0.26 + Env.boss_rand(sess) * 0.08
		local trail_len = thickness * trail_frac
		local gaps = Env.pick_two_gaps(sess, hit_y0, hit_y1)
		local bands = Env.build_bands(hit_y0, hit_y1, gaps)
		-- Spawn fully off the birth side so the wall enters from outside.
		local spawn_margin = 48
		local leading = (dir > 0) and (tl.X - spawn_margin) or (br.X + spawn_margin)
		local trailing = leading - dir * thickness
		local origin_x = leading

		local function gap_curl(y)
			for i = 1, #gaps do
				local g = gaps[i]
				if y >= g.y0 and y <= g.y1 then return 0, true end
				local curl = 16
				if y >= g.y0 - curl and y < g.y0 then
					return (y - (g.y0 - curl)) / curl, false
				end
				if y > g.y1 and y <= g.y1 + curl then
					return 1 - (y - g.y1) / curl, false
				end
			end
			return 1, false
		end

		-- Dense staggered streaks form the whole wall (no Front/Tail light columns).
		local streaks = {}
		local streak_n = 150 + math.floor(Env.boss_rand(sess) * 45)
		for _ = 1, streak_n do
			local y = vis_y0 + Env.boss_rand(sess) * (vis_y1 - vis_y0)
			local curl, in_gap = gap_curl(y)
			if y < hit_y0 or y > hit_y1 then
				in_gap = false
				curl = 1
			end
			local roll = Env.boss_rand(sess)
			local role = "body"
			if roll < 0.22 then role = "front"
			elseif roll < 0.38 then role = "bright"
			elseif roll < 0.55 then role = "tail" end
			local bend = 0
			if curl < 1 and curl > 0 then
				bend = (y < (gaps[1].y0 + gaps[1].y1) * 0.5) and -8 or 8
				if y > gaps[2].y0 then
					bend = (y < (gaps[2].y0 + gaps[2].y1) * 0.5) and -8 or 8
				end
				bend = bend * (1 - curl)
			end
			local seed = Env.boss_rand(sess)
			-- Stagger birth along X so many streams don't appear/disappear on one line.
			streaks[#streaks + 1] = {
				y = y,
				y0 = y,
				vy = (Env.boss_rand(sess) - 0.5) * 0.35,
				along_u = -0.22 + seed * 1.25,
				delay = Env.boss_rand(sess) * 22,
				seed = seed,
				length = 55 + Env.boss_rand(sess) * 110,
				speed = 0.65 + Env.boss_rand(sess) * 1.85,
				role = role,
				thick = 0.3 + Env.boss_rand(sess) * 0.55,
				in_gap = in_gap,
				curl = math.max(0.15, curl),
				bend = bend,
			}
		end

		-- Soft mist washes with their own along_u (never a shared vertical stack X).
		local mist = {}
		local mist_n = 36 + math.floor(Env.boss_rand(sess) * 14)
		for _ = 1, mist_n do
			local y = vis_y0 + Env.boss_rand(sess) * (vis_y1 - vis_y0)
			local curl, in_gap = gap_curl(y)
			if y < hit_y0 or y > hit_y1 then
				in_gap = false
				curl = 1
			end
			local seed = Env.boss_rand(sess)
			mist[#mist + 1] = {
				y = y,
				y0 = y,
				vy = (Env.boss_rand(sess) - 0.5) * 0.2,
				along_u = -0.1 + seed * 1.05,
				delay = Env.boss_rand(sess) * 16,
				seed = seed,
				length = 40 + Env.boss_rand(sess) * 36,
				speed = 0.45 + Env.boss_rand(sess) * 0.9,
				phase = seed,
				in_gap = in_gap,
				curl = math.max(0.2, curl),
			}
		end
		local soft_slots = mist

		local travel = (br.X - tl.X) + spawn_margin * 2
		sess.wall = {
			travel_dir = dir,
			dir = dir,
			travel_ang = travel_ang,
			wind_ang = wind_ang,
			thickness = thickness,
			trail_frac = trail_frac,
			trail_len = trail_len,
			leading = leading,
			trailing = trailing,
			y0 = hit_y0,
			y1 = hit_y1,
			vis_y0 = vis_y0,
			vis_y1 = vis_y1,
			gaps = gaps,
			bands = bands,
			streaks = streaks,
			mist = mist,
			soft_slots = soft_slots,
			gaps_locked = true,
			origin_x = origin_x,
			exit_x = (dir > 0) and (br.X + 40) or (tl.X - 40),
			-- Match thicker wall + longer RELEASE so the front fully exits.
			speed = travel / 68,
			flow_speed = 12,
			density = 0,
			alpha = 0,
			front_glow = 0,
			spawn_enabled = true,
			damaging = false,
			visible = true,
			phase = "form",
			form_t = 0,
			dissolve_t = 1,
		}
		sess.wind_target = wind_ang
		sess.meta.travel_dir = dir
		sess.meta.travel_ang = travel_ang
		sess.meta.wind_ang = wind_ang
		Env.apply_wall_facing(sess, dir)
		return sess.wall
	end

	function Env.update_wall_visual_state(sess)
		local wall = sess.wall
		if not wall then return end
		wall.phase = sess.phase
		if sess.phase == "form" then
			local def = Env.ATTACK[sess.attack]
			local lim = def and def.form or 24
			local t = sess.age / math.max(1, lim)
			wall.form_t = t
			if t < 0.33 then
				wall.density = t / 0.33 * 0.35
				wall.alpha = 0.25 + t * 0.3
				wall.front_glow = 0.1
			elseif t < 0.66 then
				wall.density = 0.35 + (t - 0.33) / 0.33 * 0.4
				wall.alpha = 0.45 + (t - 0.33) * 0.5
				wall.front_glow = 0.25
			else
				wall.density = 0.75 + (t - 0.66) / 0.34 * 0.25
				wall.alpha = 0.75 + (t - 0.66) * 0.4
				wall.front_glow = 0.35 + (t - 0.66) * 1.2
			end
			wall.damaging = false
		elseif sess.phase == "release" then
			wall.density = 1
			wall.alpha = 0.95
			wall.front_glow = 1
			wall.damaging = true
			wall.leading = wall.leading + wall.dir * wall.speed
			wall.trailing = wall.leading - wall.dir * wall.thickness
		elseif sess.phase == "dissolve" then
			local def = Env.ATTACK[sess.attack]
			local lim = def and def.dissolve or 18
			local t = sess.age / math.max(1, lim)
			wall.dissolve_t = 1 - t
			wall.damaging = false
			wall.spawn_enabled = false
			wall.front_glow = math.max(0, 1 - t * 1.2)
			-- Keep existing streams visible while they fly out; do not hard-clear sprites.
			wall.density = math.max(0.12, 1 - t * 0.75)
			wall.alpha = math.max(0.08, 0.95 * (1 - t * 0.85))
			wall.leading = wall.leading + wall.dir * wall.speed * 0.9
			local thick = wall.thickness * math.max(0.35, 1 - t * 0.55)
			wall.trailing = wall.leading - wall.dir * thick
		else
			wall.damaging = false
			wall.spawn_enabled = false
			wall.alpha = 0
			wall.density = 0
			wall.visible = sess.phase == "wind_shift" and false or wall.visible
			if sess.phase == "rest" or sess.phase == "idle" then
				wall.visible = false
			end
		end
		if sess.phase == "form" or sess.phase == "release" then
			wall.spawn_enabled = true
		end
		Env.p1_visual.update_wall(wall, 1)
	end

	function Env.hurt_players_wall(boss, wall)
		if not wall or not wall.damaging then return end
		local frame = Game():GetFrameCount()
		-- Soft trail near trailing edge is visual-only (harmless).
		local trail = wall.trail_len or ((wall.thickness or 100) * 0.32)
		local dir = wall.dir or 1
		local core_trailing = wall.trailing + dir * trail
		local lo = math.min(wall.leading, core_trailing)
		local hi = math.max(wall.leading, core_trailing)
		for i = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(i)
			if player and player:Exists() and not player:IsDead() then
				local d = player:GetData()
				if (d[Env.HIT_CD] or 0) <= frame then
					local r = math.max(10, player.Size or 12)
					local x, y = player.Position.X, player.Position.Y
					if x + r >= lo and x - r <= hi then
						local hit = false
						local bands = wall.bands or {}
						for b = 1, #bands do
							local band = bands[b]
							if y + r * 0.35 >= band.y0 and y - r * 0.35 <= band.y1 then
								hit = true
								break
							end
						end
						if hit then
							player:TakeDamage(1, 0, EntityRef(boss), 24)
							d[Env.HIT_CD] = frame + 16
						end
					end
				end
			end
		end
	end

	function Env.nearest_player_dist(pos)
		local best = 1e9
		for i = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(i)
			if player and player:Exists() and not player:IsDead() then
				local d = (player.Position - pos):Length()
				if d < best then best = d end
			end
		end
		return best
	end
	-- ---------- wind_sweep ----------

	function Env.tick_sweep(sess)
		local meta = sess.meta
		if sess.phase == "wind_shift" and sess.age == 1 then
			local dir = sess.force_travel_dir
			if dir ~= 1 and dir ~= -1 then
				dir = (Env.boss_rand(sess) < 0.5) and 1 or -1
			end
			meta.travel_dir = dir
			meta.left = dir > 0
			meta.travel_ang = (dir > 0) and 0 or 180
			meta.wind_ang = Env.travel_to_wind_ang(meta.travel_ang)
			sess.wind_target = meta.wind_ang
			sess.wind_from = sess.ambient_ang or 0
			Env.apply_wall_facing(sess, dir)
		end
		if sess.phase == "form" and sess.age == 1 then
			Env.setup_wall(sess, {travel_dir = meta.travel_dir})
		end
		if sess.wall and (sess.phase == "form" or sess.phase == "release" or sess.phase == "dissolve") then
			Env.update_wall_visual_state(sess)
			if sess.phase == "release" then
				Env.hurt_players_wall(sess.boss, sess.wall)
			end
		end
	end

end

return {
	register = register,
}
