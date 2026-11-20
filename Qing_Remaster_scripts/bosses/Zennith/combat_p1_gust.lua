-- Zennith P1 gust / blood rain
-- Behavior-equivalent extract from combat_p1.lua (structural only).

local function register(Env)
	-- ---------- wind_gust (dust rain) ----------

	function Env.gust_pos_safe(sess, pos)
		if Env.nearest_player_dist(pos) < Env.GUST_SAFE then return false end
		local boss = sess.boss
		if Env.living(boss) and (pos - boss.Position):Length() < Env.GUST_SAFE_BOSS then
			return false
		end
		return true
	end

	function Env.in_screen_view(pos, pad)
		local view = Env.wind_emission.screen_view_rect()
		pad = pad or 0
		return pos.X >= view.minx + pad and pos.X <= view.maxx - pad
			and pos.Y >= view.miny + pad and pos.Y <= view.maxy - pad
	end

	--- V2.6 zones: screen edge entry / broad visible rise / light player bias.
	function Env.pick_gust_zone(sess)
		local r = Env.boss_rand(sess)
		local ext = Env.GUST_SCREEN_EXTERNAL_RATIO or 0.30
		local vis = Env.GUST_ARENA_VISIBLE_RATIO or 0.60
		if r < ext then
			return "screen_upwind_external"
		elseif r < ext + vis then
			return "arena_visible_upwind"
		end
		return "player_upwind_bias"
	end

	function Env.gust_in_view_loose(pos, view, inset)
		inset = inset or 10
		return pos.X >= view.minx + inset and pos.X <= view.maxx - inset
			and pos.Y >= view.miny + inset and pos.Y <= view.maxy - inset
	end

	--- Screen edge index that is upwind of blow (particles enter from this edge).
	--- 0=top 1=bottom 2=left 3=right — matches wind_emission.spawn_on_edge.
	function Env.gust_upwind_edge(blow)
		local ax, ay = math.abs(blow.X), math.abs(blow.Y)
		if ay >= ax then
			return (blow.Y >= 0) and 0 or 1
		end
		return (blow.X >= 0) and 2 or 3
	end

	--- True if a point outside the view will cross into it when moving with blow.
	function Env.gust_will_enter_view(pos, blow, view)
		local half = Env.wind_emission.sprite_half()
		if not Env.wind_emission.bbox_fully_outside(pos, half, view) then
			return false
		end
		local step = blow:Resized(32)
		local p = pos
		for _ = 1, 40 do
			p = p + step
			if Env.wind_emission.intersects_view(p, half, view) then
				return true
			end
		end
		return false
	end

	function Env.sample_screen_upwind_external(sess, view, blow, slot, batch_n, attempt)
		local edge = Env.gust_upwind_edge(blow)
		batch_n = math.max(1, tonumber(batch_n) or 4)
		slot = tonumber(slot) or 1
		local lane_t = (slot - 0.5) / batch_n
		local jitter = (Env.boss_rand(sess) - 0.5) * (0.7 / batch_n)
		local t = lane_t + jitter
		if attempt > 10 then
			t = Env.boss_rand(sess)
		end
		t = math.max(0.03, math.min(0.97, t))
		local m0 = Env.GUST_EXTERNAL_MARGIN_MIN or 22
		local m1 = Env.GUST_EXTERNAL_MARGIN_MAX or 56
		if m1 < m0 then m1 = m0 end
		local outside = m0 + Env.boss_rand(sess) * (m1 - m0)
		local pos
		if edge == 0 then
			pos = Vector(view.minx + t * (view.maxx - view.minx), view.miny - outside)
		elseif edge == 1 then
			pos = Vector(view.minx + t * (view.maxx - view.minx), view.maxy + outside)
		elseif edge == 2 then
			pos = Vector(view.minx - outside, view.miny + t * (view.maxy - view.miny))
		else
			pos = Vector(view.maxx + outside, view.miny + t * (view.maxy - view.miny))
		end
		return pos, edge, outside
	end

	--- Sample a candidate in zone. Reject instead of edge-clamp.
	function Env.sample_gust_candidate(sess, zone, slot, batch_n, attempt)
		local blow = Env.wind_dir_vec(sess.ambient_ang or sess.wind_target or 0)
		local view = Env.wind_emission.screen_view_rect()
		local side = Vector(-blow.Y, blow.X)
		local cx = (view.minx + view.maxx) * 0.5
		local cy = (view.miny + view.maxy) * 0.5
		local center = Vector(cx, cy)
		local span = math.max(view.maxx - view.minx, view.maxy - view.miny)
		local lat_span = Env.GUST_LAT_SPAN or 0.48
		slot = tonumber(slot) or 1
		batch_n = math.max(1, tonumber(batch_n) or 4)
		local lane = ((slot - 0.5) / batch_n) * 2 - 1
		local player = Env.auxi.get_acceptible_target(sess.boss) or Game():GetPlayer(0)
		local pos
		local band = zone
		local sub_band = nil
		local along_from_player = nil
		local spawned_outside = false
		local edge = nil

		if zone == "screen_upwind_external" then
			pos, edge = Env.sample_screen_upwind_external(sess, view, blow, slot, batch_n, attempt)
			band = "screen_upwind_external"
			spawned_outside = true
		elseif zone == "player_upwind_bias" and player then
			-- Mild bias only: short lead + wide lateral — not a player-locked corridor.
			local lmin = Env.GUST_PLAYER_BIAS_L_MIN or 100
			local lmax = Env.GUST_PLAYER_BIAS_L_MAX or 170
			local L = lmin + Env.boss_rand(sess) * (lmax - lmin)
			local S = (lane * 0.55 + (Env.boss_rand(sess) * 2 - 1) * 0.55)
				* math.min(160, span * 0.62)
			if attempt > 10 then
				S = (Env.boss_rand(sess) * 2 - 1) * math.min(170, span * 0.65)
				L = lmin + Env.boss_rand(sess) * (lmax - lmin)
			end
			pos = player.Position - blow * L + side * S
			along_from_player = L
			band = "player_upwind_bias"
		else
			-- Broad visible upwind field; player is not the common focus.
			local along_bands = {
				{0.04, 0.15},
				{0.12, 0.26},
				{0.22, 0.38},
				{0.30, 0.46},
			}
			local band_i = ((slot - 1) % #along_bands) + 1
			local ab = along_bands[band_i]
			local along = span * (ab[1] + Env.boss_rand(sess) * (ab[2] - ab[1]))
			local lat = (lane * lat_span + (Env.boss_rand(sess) * 2 - 1) * 0.14) * span
			if attempt > 12 then
				lat = (Env.boss_rand(sess) * 2 - 1) * span * lat_span
			end
			pos = center - blow * along + side * lat
			band = "arena_visible_upwind"
			sub_band = (along < span * 0.20) and "near_upwind" or "interior"
		end
		return pos, band, sub_band, along_from_player, view, player, blow, spawned_outside, edge
	end

	--- Zone-aware spawn. Reassign on reject; never edge-clamp into view.
	function Env.pick_gust_pos(sess, zone, slot, batch_n)
		zone = zone or "arena_visible_upwind"
		local requested = zone
		local order
		if zone == "screen_upwind_external" then
			order = {"screen_upwind_external", "arena_visible_upwind"}
		elseif zone == "player_upwind_bias" then
			order = {"player_upwind_bias", "arena_visible_upwind", "screen_upwind_external"}
		else
			order = {"arena_visible_upwind", "screen_upwind_external"}
		end

		local half = Env.wind_emission.sprite_half()
		for oi = 1, #order do
			local try_zone = order[oi]
			local attempts = (try_zone == "screen_upwind_external") and 24 or 22
			for attempt = 1, attempts do
				local pos, band, sub_band, along_from_player, view, player, blow, spawned_outside, edge =
					Env.sample_gust_candidate(sess, try_zone, slot, batch_n, attempt)
				if not pos then
					break
				end
				local ok = false
				if try_zone == "screen_upwind_external" then
					-- Must stay outside the visible rect; reject if sampling somehow lands inside.
					ok = Env.wind_emission.bbox_fully_outside(pos, half, view)
						and Env.gust_will_enter_view(pos, blow, view)
						and Env.gust_pos_safe(sess, pos)
				else
					ok = Env.gust_in_view_loose(pos, view, 12)
						and Env.gust_pos_safe(sess, pos)
				end
				if ok then
					local dist_player = player and (pos - player.Position):Length() or nil
					local upwind_dist = along_from_player
					if player and upwind_dist == nil then
						upwind_dist = (player.Position - pos):Dot(blow)
					end
					return pos, band, {
						requested_zone = requested,
						final_zone = try_zone,
						sub_band = sub_band,
						clamped = false,
						reassigned = try_zone ~= requested,
						dist_player = dist_player,
						upwind_dist = upwind_dist,
						spawned_outside = spawned_outside == true or try_zone == "screen_upwind_external",
						edge = edge,
					}
				end
			end
		end

		-- Last resort: one more screen-edge sample, then broad visible — never claim player bias.
		local blow = Env.wind_dir_vec(sess.ambient_ang or sess.wind_target or 0)
		local view = Env.wind_emission.screen_view_rect()
		local pos, edge = Env.sample_screen_upwind_external(sess, view, blow, slot, batch_n, 99)
		local band = "fallback"
		local spawned_outside = true
		if not (Env.wind_emission.bbox_fully_outside(pos, half, view)
			and Env.gust_will_enter_view(pos, blow, view)
			and Env.gust_pos_safe(sess, pos)) then
			local side = Vector(-blow.Y, blow.X)
			local cx = (view.minx + view.maxx) * 0.5
			local cy = (view.miny + view.maxy) * 0.5
			local span = math.max(view.maxx - view.minx, view.maxy - view.miny)
			pos = Vector(cx, cy) - blow * (span * 0.22) + side * ((Env.boss_rand(sess) * 2 - 1) * span * 0.3)
			spawned_outside = false
			edge = nil
		end
		local player = Env.auxi.get_acceptible_target(sess.boss) or Game():GetPlayer(0)
		local dist_player = player and (pos - player.Position):Length() or nil
		local upwind_dist = player and (player.Position - pos):Dot(blow) or nil
		return pos, band, {
			requested_zone = requested,
			final_zone = "fallback",
			clamped = false,
			reassigned = true,
			dist_player = dist_player,
			upwind_dist = upwind_dist,
			spawned_outside = spawned_outside,
			edge = edge,
		}
	end

	function Env.count_gust_active(sess)
		local n = 0
		for _, ent in pairs(sess.objects) do
			if ent and ent.Exists and ent:Exists() and ent:GetData()[Env.M.own_key .. "gust"] then
				n = n + 1
			end
		end
		return n
	end

	function Env.aim_wind_toward_player(sess)
		local boss = sess.boss
		local player = Env.auxi.get_acceptible_target(boss) or Game():GetPlayer(0)
		if not player then return sess.wind_target or sess.ambient_ang or 0 end
		local aim = (player.Position - boss.Position)
		if aim:Length() < 1 then return sess.wind_target or 0 end
		return Env.travel_to_wind_ang(aim:GetAngleDegrees())
	end

	function Env.chase_wind_toward_player(sess, max_step)
		max_step = max_step or 6
		local meta = sess.meta
		if meta.track_lock then
			Env.set_wind_ang(sess, sess.wind_target or sess.ambient_ang or 0, 0.7)
			return
		end
		meta.chase_cd = (meta.chase_cd or 0) - 1
		if (meta.chase_cd or 0) <= 0 then
			meta.chase_cd = 6
			sess.wind_target = Env.aim_wind_toward_player(sess)
		end
		local cur = sess.ambient_ang or 0
		local tgt = sess.wind_target or cur
		local d = tgt - cur
		while d > 180 do d = d - 360 end
		while d < -180 do d = d + 360 end
		if d > max_step then d = max_step end
		if d < -max_step then d = -max_step end
		local ang = cur + d
		local intensity = 0.4
		if sess.phase == "release" then
			intensity = 0.75
		elseif sess.phase == "form" then
			intensity = 0.45
		end
		Env.set_wind_ang(sess, ang, intensity)
		meta.ang = ang
	end

	function Env.gust_spawn_window(sess)
		if sess.phase == "form" and sess.age > Env.GUST_ROAR_FRAME then
			return true
		end
		if sess.phase == "release" and sess.age <= Env.GUST_SPAWN_RELEASE_END then
			return true
		end
		return false
	end

	function Env.tick_gust_particles(sess)
		local blow = Env.wind_dir_vec(sess.ambient_ang or 0)
		local meta = sess.meta
		for key, ent in pairs(sess.objects) do
			if not (ent and ent.Exists and ent:Exists()) then
				sess.objects[key] = nil
			else
				local d = ent:GetData()
				if d[Env.M.own_key .. "gust"] then
					local t = (d[Env.M.own_key .. "rise_t"] or 0) + 1
					d[Env.M.own_key .. "rise_t"] = t
					local need = d[Env.M.own_key .. "rise_need"] or 24
					local u = Env.ease_out_quad(math.min(1, t / need))
					local h = Env.GUST_RISE_FROM + (Env.M.HOLD_HEIGHT - Env.GUST_RISE_FROM) * u
					d[Env.HOLD_KEY] = h
					ent.Height = h
					ent.FallingSpeed = 0
					ent.FallingAccel = -0.1
					local drift = 0.12 + 2.4 * (u * u)
					if t >= 9 then
						drift = drift + 1.2 * math.min(1, (t - 8) / 12)
					end
					local add = blow:Resized(drift * 0.35)
					ent.Velocity = ent.Velocity * 0.92 + add
					if t < 18 or u < 0.85 then
						ent.CollisionDamage = 0
						d[Env.RATE_KEY] = (t >= 9) and (Env.GUST_RATE_TRACTION * (0.35 + 0.65 * u)) or nil
					else
						d[Env.M.own_key .. "gust_risen"] = true
						d[Env.RATE_KEY] = Env.GUST_RATE_BURST * (0.55 + 0.45 * math.min(1, (t - 18) / 20))
						ent.CollisionDamage = 1
					end
					local spr = ent:GetSprite()
					if spr then
						local a = math.min(1, u)
						local glow = math.max(0, (u - 0.4) / 0.6)
						spr.Color = Color(1, 1, 1, a, 0.08 * glow, 0.12 * glow, 0.2 * glow)
					end
					if meta then
						if Env.in_screen_view(ent.Position, 4) then
							if not d[Env.M.own_key .. "entered_view"] then
								d[Env.M.own_key .. "entered_view"] = true
								meta.entered_view = (meta.entered_view or 0) + 1
								local spawn_clock = d[Env.M.own_key .. "gust_spawn_clock"]
								if spawn_clock ~= nil then
									local delay = (sess.clock or 0) - spawn_clock
									d[Env.M.own_key .. "enter_delay"] = delay
									meta.enter_delay_sum = (meta.enter_delay_sum or 0) + delay
									meta.enter_delay_n = (meta.enter_delay_n or 0) + 1
								end
								if d[Env.M.own_key .. "gust_spawned_outside"] then
									meta.entered_from_outside = (meta.entered_from_outside or 0) + 1
								end
							end
							if not d[Env.M.own_key .. "visible_rising"] and u < 0.85 then
								d[Env.M.own_key .. "visible_rising"] = true
								meta.visible_rising = (meta.visible_rising or 0) + 1
							end
						elseif d[Env.M.own_key .. "gust_spawned_outside"]
							and t > 45
							and not d[Env.M.own_key .. "entered_view"] then
							-- Outside spawn still alive but never entered; counted on cull.
						end
					end
				end
			end
		end
	end

	function Env.setup_gust(sess)
		local burst = (Env.GUST_BURST_MIN or 12)
			+ math.floor(Env.boss_rand(sess) * ((Env.GUST_BURST_MAX or 18) - (Env.GUST_BURST_MIN or 12) + 1))
		sess.meta = {
			spawned = 0,
			spawn_failed = 0,
			entered_view = 0,
			visible_rising = 0,
			removed_before_view = 0,
			armed = false,
			gust_on = false,
			damage_on = false,
			chase_cd = 0,
			track_lock = false,
			ang = sess.ambient_ang or -90,
			spawn_mode = "burst",
			burst_total = burst,
			burst_spawned = 0,
			burst_subs_left = Env.GUST_BURST_SUBS or 3,
			batch_index = 0,
			last_batch_clock = nil,
			last_batch_count = 0,
			frames_since_batch = 0,
			frames_without_spawn = 0,
			gust_reassigned = 0,
			batch_spawn_log = {},
			enter_delay_sum = 0,
			enter_delay_n = 0,
			entered_from_outside = 0,
			spawned_outside = 0,
			gust_band_counts = {
				screen_upwind_external = 0,
				arena_visible_upwind = 0,
				player_upwind_bias = 0,
				fallback = 0,
			},
		}
		sess.wind_target = Env.aim_wind_toward_player(sess)
		sess.wind_from = sess.ambient_ang or 0
	end

	function Env.try_spawn_gust_tear(sess, meta, _tl, _br, slot, batch_n)
		local spawned = meta.spawned or 0
		local zone = Env.pick_gust_zone(sess)
		local pos, band, place = Env.pick_gust_pos(sess, zone, slot, batch_n)
		band = band or "fallback"
		place = place or {}
		local q = Env.spawn_blade(sess.boss, pos, Vector(0, 0), {
			damage = 0,
			scale = 0.95,
			alpha = 0.05,
			anim = "BloodTear4",
			height = Env.GUST_RISE_FROM,
		})
		if not q then
			meta.spawn_failed = (meta.spawn_failed or 0) + 1
			return false, nil
		end
		Env.track_obj(sess, q, "gust_drop")
		local d = q:GetData()
		d[Env.M.own_key .. "gust"] = true
		d[Env.M.own_key .. "gust_band"] = band
		d[Env.M.own_key .. "gust_sub_band"] = place.sub_band
		d[Env.M.own_key .. "gust_spawn_clock"] = sess.clock or sess.age or 0
		d[Env.M.own_key .. "gust_spawned_outside"] = place.spawned_outside == true
		d[Env.M.own_key .. "rise_t"] = 0
		local rise_extra = (meta.spawn_mode == "burst") and math.floor(Env.boss_rand(sess) * 8) or 0
		d[Env.M.own_key .. "rise_need"] = 16 + math.floor(Env.boss_rand(sess) * 18) + rise_extra
		d[Env.HOLD_KEY] = Env.GUST_RISE_FROM
		q.Height = Env.GUST_RISE_FROM
		local blow = Env.wind_dir_vec(sess.ambient_ang or sess.wind_target or 0)
		q.Velocity = blow:Resized(0.35 + Env.boss_rand(sess) * 0.45)
		meta.gust_band_counts = meta.gust_band_counts or {
			screen_upwind_external = 0,
			arena_visible_upwind = 0,
			player_upwind_bias = 0,
			fallback = 0,
		}
		meta.gust_band_counts[band] = (meta.gust_band_counts[band] or 0) + 1
		if place.spawned_outside then
			meta.spawned_outside = (meta.spawned_outside or 0) + 1
		end
		if place.reassigned then
			meta.gust_reassigned = (meta.gust_reassigned or 0) + 1
		end
		meta.spawned = spawned + 1
		meta.gust_last_spawn_frame = sess.clock or sess.age
		meta.gust_last_spawn_phase = sess.phase
		meta.gust_last_spawn_age = sess.age
		if Env.in_screen_view(pos, 4) then
			d[Env.M.own_key .. "entered_view"] = true
			d[Env.M.own_key .. "visible_rising"] = true
			d[Env.M.own_key .. "enter_delay"] = 0
			meta.entered_view = (meta.entered_view or 0) + 1
			meta.visible_rising = (meta.visible_rising or 0) + 1
			-- enter_delay_avg tracks outside→view only; in-view births skip that sample.
		end
		if not meta.gust_first_spawn_frame then
			meta.gust_first_spawn_frame = sess.clock or sess.age
			meta.gust_first_spawn_phase = sess.phase
			meta.gust_first_spawn_age = sess.age
			meta.gust_first_spawn_band = band
		end
		return true, {
			x = pos.X,
			y = pos.Y,
			band = band,
			sub_band = place.sub_band,
			slot = slot,
			zone = place.final_zone or zone,
			requested = place.requested_zone or zone,
			reassigned = place.reassigned == true,
			dist_player = place.dist_player,
			upwind_dist = place.upwind_dist,
			spawned_outside = place.spawned_outside == true,
			edge = place.edge,
		}
	end

	--- Burst then sustain cadence. Alive count never gates fire; missed intervals are not dumped.
	function Env.try_spawn_gust_batch(sess, meta, tl, br)
		local clock = sess.clock or 0
		local mode = meta.spawn_mode or "sustain"
		local interval = Env.GUST_BATCH_INTERVAL or 5
		if mode == "burst" then
			interval = Env.GUST_BURST_INTERVAL or 3
		end
		if meta.last_batch_clock ~= nil and (clock - meta.last_batch_clock) < interval then
			meta.frames_since_batch = clock - meta.last_batch_clock
			return false
		end
		local n
		if mode == "burst" then
			local left = math.max(0, (meta.burst_total or 12) - (meta.burst_spawned or 0))
			local subs = math.max(1, meta.burst_subs_left or 1)
			n = math.max(3, math.ceil(left / subs))
			n = math.min(n, left)
			if n <= 0 then
				meta.spawn_mode = "sustain"
				mode = "sustain"
			end
		end
		if mode ~= "burst" then
			local bmin = Env.GUST_BATCH_MIN or 4
			local bmax = Env.GUST_BATCH_MAX or 5
			if bmax < bmin then bmax = bmin end
			n = bmin + math.floor(Env.boss_rand(sess) * (bmax - bmin + 1))
		end
		meta.batch_index = (meta.batch_index or 0) + 1
		meta.last_batch_clock = clock
		meta.frames_since_batch = 0
		local got = 0
		local positions = {}
		for slot = 1, n do
			local ok, info = Env.try_spawn_gust_tear(sess, meta, tl, br, slot, n)
			if ok then
				got = got + 1
				if mode == "burst" then
					meta.burst_spawned = (meta.burst_spawned or 0) + 1
				end
				if info then
					positions[#positions + 1] = info
				end
			end
		end
		if mode == "burst" then
			meta.burst_subs_left = math.max(0, (meta.burst_subs_left or 1) - 1)
			if (meta.burst_spawned or 0) >= (meta.burst_total or 12) or (meta.burst_subs_left or 0) <= 0 then
				meta.spawn_mode = "sustain"
			end
		end
		meta.last_batch_count = got
		meta.last_batch_positions = positions
		meta.last_batch_mode = mode
		meta.batch_spawn_log = meta.batch_spawn_log or {}
		meta.batch_spawn_log[#meta.batch_spawn_log + 1] = {
			idx = meta.batch_index,
			n = got,
			clock = clock,
			mode = mode,
			positions = positions,
		}
		while #meta.batch_spawn_log > 12 do
			table.remove(meta.batch_spawn_log, 1)
		end
		if got > 0 then
			meta.frames_without_spawn = 0
		else
			meta.frames_without_spawn = (meta.frames_without_spawn or 0) + 1
		end
		return got > 0
	end

	function Env.tick_gust(sess)
		local meta = sess.meta
		local tl, br = Env.room_bounds()
		if sess.phase == "wind_shift" and sess.age == 1 then
			Env.setup_gust(sess)
			meta = sess.meta
		end
		if sess.phase == "wind_shift" then
			Env.chase_wind_toward_player(sess, 6)
		elseif sess.phase == "form" then
			local lim = (Env.ATTACK.wind_gust and Env.ATTACK.wind_gust.form) or 60
			if sess.age <= lim * 0.5 then
				Env.chase_wind_toward_player(sess, 6)
			else
				meta.track_lock = true
				Env.chase_wind_toward_player(sess, 3)
			end
		end
		if sess.phase == "form" and sess.age == 1 then
			Env.start_retreat(sess, 35 + Env.boss_rand(sess) * 15, 16 + math.floor(Env.boss_rand(sess) * 6))
		end
		if meta and Env.gust_spawn_window(sess) then
			Env.try_spawn_gust_batch(sess, meta, tl, br)
		elseif meta then
			if meta.last_batch_clock then
				meta.frames_since_batch = (sess.clock or 0) - meta.last_batch_clock
			end
		end
		if sess.phase == "form" or sess.phase == "release" then
			Env.tick_gust_particles(sess)
		end
		if sess.phase == "release" and sess.age == 1 then
			Env.boss_wind.pulse({intensity = 0.2})
		end
		if sess.phase == "dissolve" then
			Env.tick_gust_particles(sess)
			if sess.age == 1 then
				for _, ent in pairs(sess.objects) do
					if ent and ent.Exists and ent:Exists() and ent:GetData()[Env.M.own_key .. "gust"] then
						ent:GetData()[Env.RATE_KEY] = Env.GUST_RATE_BURST * 0.4
					end
				end
				Env.release_objects(sess, "gust")
			end
		end
	end

end

return {
	register = register,
}
