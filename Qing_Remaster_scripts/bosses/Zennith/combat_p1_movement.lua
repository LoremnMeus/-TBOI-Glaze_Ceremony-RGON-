-- Zennith P1 movement / facing / cast anim
-- Behavior-equivalent extract from combat_p1.lua (structural only).

local function register(Env)
	function Env.clear_retreat(sess)
		sess.retreat = nil
	end

	function Env.clamp_room_pos(pos, pad)
		local tl, br = Env.room_bounds()
		pad = pad or 36
		return Vector(
			math.max(tl.X + pad, math.min(br.X - pad, pos.X)),
			math.max(tl.Y + pad, math.min(br.Y - pad, pos.Y))
		)
	end

	function Env.apply_wall_facing(sess, travel_dir)
		-- travel_dir +1 (L→R): face right FlipX=false; -1 (R→L): face left FlipX=true.
		-- Matches legacy Zennith FlipX = (direction == LEFT).
		sess.facing_locked = true
		sess.facing_flip_x = travel_dir < 0
		local boss = sess.boss
		if Env.living(boss) then
			boss.FlipX = sess.facing_flip_x == true
		end
	end

	function Env.clear_facing_lock(sess)
		sess.facing_locked = false
		sess.facing_flip_x = nil
	end

	function Env.sync_facing(sess)
		if not sess.facing_locked then return end
		local boss = sess.boss
		if Env.living(boss) then
			boss.FlipX = sess.facing_flip_x == true
		end
	end

	--- Tactical stance: pick a reachable fire position, not a naive away-vector clamp.
	--- Wind Split only: retreat toward screen-up (never down / pure horizontal).
	function Env.start_split_retreat(sess)
		local boss = sess.boss
		if not Env.living(boss) then return false end
		local from = Vector(boss.Position.X, boss.Position.Y)
		local want_min = Env.STANCE_DIST_MIN
		local want_max = Env.STANCE_DIST_MAX
		local frames = Env.STANCE_FRAMES + math.floor(Env.boss_rand(sess) * 4)
		local pad = 28
		-- Isaac angle: -90 = up, 90 = down.
		local angles = {-90, -120, -60, -105, -75}
		local dist_try = {
			want_max,
			(want_min + want_max) * 0.5,
			want_min,
			want_min * 0.7,
			48,
			32,
		}
		local best = nil
		local best_dist = -1
		for ai = 1, #angles do
			local dir = Vector.FromAngle(angles[ai])
			for di = 1, #dist_try do
				local req = dist_try[di]
				local target = Env.clamp_room_pos(from + dir * req, pad)
				local delta = target - from
				if delta.Y < -20 then
					local dist = delta:Length()
					if dist > best_dist then
						best_dist = dist
						best = {
							from = from,
							to = target,
							frames = frames,
							age = 0,
							request_dist = req,
							target_dist = dist,
							completed_dist = 0,
						}
					end
				end
			end
		end
		local meta = sess.meta or {}
		sess.meta = meta
		if not best then
			meta.retreat_skipped = true
			meta.retreat_dir = "none"
			meta.retreat_shortened = false
			return false
		end
		sess.retreat = best
		meta.stance_request_dist = best.request_dist
		meta.stance_target_dist = best.target_dist
		meta.stance_from = string.format("%.0f,%.0f", best.from.X, best.from.Y)
		meta.stance_to = string.format("%.0f,%.0f", best.to.X, best.to.Y)
		meta.retreat_dir = string.format(
			"%.0f,%.0f",
			best.to.X - best.from.X,
			best.to.Y - best.from.Y
		)
		meta.retreat_shortened = best.target_dist < want_min - 1
		meta.retreat_skipped = false
		return true
	end

	function Env.start_tactical_stance(sess, opts)
		opts = opts or {}
		local boss = sess.boss
		if not Env.living(boss) then return false end
		local player = Env.auxi.get_acceptible_target(boss) or Game():GetPlayer(0)
		local tl, br, center = Env.room_bounds()
		local from = Vector(boss.Position.X, boss.Position.Y)
		local away = Vector(0, -1)
		if player then
			away = from - player.Position
			if away:Length() < 1 then
				away = Vector(0, -1)
			else
				away = away:Normalized()
			end
		end
		local away_ang = away:GetAngleDegrees()
		local want_min = opts.dist_min or Env.STANCE_DIST_MIN
		local want_max = opts.dist_max or Env.STANCE_DIST_MAX
		local frames = math.max(18, math.floor(opts.frames or Env.STANCE_FRAMES))
		local pad = opts.pad or 36
		local best = nil
		local best_score = -1e9
		local ang_try = {0, 35, -35, 70, -70, 110, -110, 150, -150, 180}
		local dist_try = {want_max, (want_min + want_max) * 0.5, want_min, want_min * 0.75}
		for ai = 1, #ang_try do
			local dir = Vector.FromAngle(away_ang + ang_try[ai])
			for di = 1, #dist_try do
				local req = dist_try[di]
				local raw = from + dir * req
				local target = Env.clamp_room_pos(raw, pad)
				local actual = (target - from):Length()
				if actual >= 18 then
					local to_player = player and (target - player.Position):Length() or 120
					local to_center = (target - center):Length()
					-- Prefer real travel distance, keep player separation, stay able to aim toward center.
					local score = actual * 2.2 + math.min(160, to_player) * 0.55 - to_center * 0.15
					if actual >= want_min then score = score + 40 end
					if score > best_score then
						best_score = score
						best = {
							from = from,
							to = target,
							frames = frames,
							age = 0,
							request_dist = req,
							target_dist = actual,
							completed_dist = 0,
						}
					end
				end
			end
		end
		if not best then
			local fallback = Env.clamp_room_pos(from + away * want_min, pad)
			best = {
				from = from,
				to = fallback,
				frames = frames,
				age = 0,
				request_dist = want_min,
				target_dist = (fallback - from):Length(),
				completed_dist = 0,
			}
		end
		sess.retreat = best
		local meta = sess.meta or {}
		sess.meta = meta
		meta.stance_request_dist = best.request_dist
		meta.stance_target_dist = best.target_dist
		meta.stance_from = string.format("%.0f,%.0f", best.from.X, best.from.Y)
		meta.stance_to = string.format("%.0f,%.0f", best.to.X, best.to.Y)
		return true
	end

	-- Legacy name used by gust; redirects to tactical stance with lighter distance.
	function Env.start_retreat(sess, dist, frames)
		dist = tonumber(dist) or 40
		return Env.start_tactical_stance(sess, {
			dist_min = math.max(40, dist * 0.85),
			dist_max = math.max(55, dist * 1.15),
			frames = frames or 20,
			pad = 34,
		})
	end

	--- Returns true while retreat owns Velocity this frame.
	function Env.tick_retreat(sess)
		local r = sess.retreat
		if not r then return false end
		local boss = sess.boss
		if not Env.living(boss) then
			Env.clear_retreat(sess)
			return false
		end
		r.age = (r.age or 0) + 1
		local t = r.age / math.max(1, r.frames)
		if t > 1 then t = 1 end
		-- Smoothstep ease in/out toward target; Velocity only (no teleport).
		local u = t * t * (3 - 2 * t)
		local pos = r.from * (1 - u) + r.to * u
		local delta = pos - boss.Position
		boss.Velocity = delta * 0.9
		r.completed_dist = (boss.Position - r.from):Length()
		if r.age >= r.frames then
			-- Soft settle: do not hard-zero if still short of target.
			local remain = r.to - boss.Position
			if remain:Length() > 3 then
				boss.Velocity = remain * 0.35
			else
				boss.Velocity = Vector(0, 0)
			end
			if sess.meta then
				sess.meta.stance_completed_dist = r.completed_dist
			end
			Env.clear_retreat(sess)
		end
		return true
	end

	function Env.sync_boss_anim(sess)
		local boss = sess.boss
		if not Env.living(boss) then return end
		local def = Env.ATTACK[sess.attack]
		local anim = def and def.anim
		local s = boss:GetSprite()
		if not s then return end
		local meta = sess.meta
		if not meta then
			meta = {}
			sess.meta = meta
		end

		if sess.phase == "wind_shift" or sess.phase == "rest" then
			Env.ensure_idle(boss)
			return
		end

		-- Wind Split: AttackDown1 starts after retreat, Shoot owns the three-main volley.
		if sess.attack == "wind_split" then
			local split_anim = anim or "AttackDown1"
			-- Wait until retreat finished/skipped; do not start on FORM entry age=0.
			local retreat_done = meta.retreat_skipped == true
				or meta.stance_completed_dist ~= nil
				or (sess.phase == "release" and not sess.retreat)
			if not meta.cast_anim_started
				and not sess.retreat
				and retreat_done
				and (sess.phase == "form" or sess.phase == "release")
			then
				s:Play(split_anim, true)
				meta.cast_anim_started = true
				meta.cast_anim_name = split_anim
				meta.cast_play_clock = sess.clock or sess.age
				meta.cast_play_phase = sess.phase
				meta.cast_play_age = sess.age
			end
			if meta.cast_anim_started and not meta.volley_fired then
				local shoot_now = false
				if s:IsEventTriggered("Shoot") then
					shoot_now = true
					meta.shoot_event_clock = sess.clock or sess.age
					meta.shoot_fallback = false
				else
					-- Bounded recovery if Shoot is skipped by hitch / phase edge.
					local play_clock = meta.cast_play_clock or (sess.clock or 0)
					local elapsed = (sess.clock or 0) - play_clock
					local fallback = Env.SPLIT_SHOOT_FALLBACK_FRAME or 18
					if elapsed >= fallback
						and (s:IsPlaying(split_anim) or s:IsFinished(split_anim)
							or s:GetAnimation() == split_anim)
					then
						shoot_now = true
						meta.shoot_event_clock = sess.clock or sess.age
						meta.shoot_fallback = true
					end
				end
				if shoot_now and Env.split_fire_volley then
					Env.split_fire_volley(sess)
				end
			end
			if meta.cast_anim_started then
				if s:IsFinished(split_anim) then
					Env.ensure_idle(boss)
					return
				end
				if s:IsPlaying(split_anim) then
					return
				end
				if not meta.volley_fired then
					return
				end
				Env.ensure_idle(boss)
				return
			end
			Env.ensure_idle(boss)
			return
		end

		-- Cast is a single session event. Never re-bind Play to FORM/RELEASE length coincidence.
		if sess.phase == "form" and sess.age == 1 and anim and not meta.cast_anim_started then
			s:Play(anim, true)
			meta.cast_anim_started = true
			meta.cast_anim_name = anim
			if sess.attack == "wind_gust" then
				meta.gust_anim_start_count = (meta.gust_anim_start_count or 0) + 1
			end
			return
		end

		if sess.attack == "wind_gust" and meta.cast_anim_started then
			local gust_anim = anim or "AttackDown2"
			if s:IsFinished(gust_anim) then
				meta.gust_anim_finished = true
				Env.ensure_idle(boss)
				return
			end
			if s:IsPlaying(gust_anim) then
				return
			end
			-- Not playing and not finished → recover Idle (do not restart cast).
			Env.ensure_idle(boss)
			return
		end

		-- Wind Sweep: AttackSide1 once in FORM; never re-Play on RELEASE; Idle when finished.
		-- Wall travel continues independently of Boss sprite state.
		if sess.attack == "wind_sweep" and meta.cast_anim_started then
			local sweep_anim = anim or "AttackSide1"
			if s:IsFinished(sweep_anim) then
				meta.sweep_anim_finished = true
				Env.ensure_idle(boss)
				return
			end
			if s:IsPlaying(sweep_anim) then
				return
			end
			Env.ensure_idle(boss)
			return
		end

		if sess.phase == "dissolve" then
			local cur = s:GetAnimation()
			if cur ~= (anim or "") or s:IsFinished(cur) then
				Env.ensure_idle(boss)
			end
			return
		end

		-- Do not re-Play cast anims on RELEASE. Sweep/gust/split own their finish→Idle paths.
	end

end

return {
	register = register,
}
