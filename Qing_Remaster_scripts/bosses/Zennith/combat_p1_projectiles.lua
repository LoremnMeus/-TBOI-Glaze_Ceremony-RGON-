-- Zennith P1 projectile spawn / lifecycle
-- Behavior-equivalent extract from combat_p1.lua (structural only).

local function register(Env)
	function Env.keep_ambient(sess, ang, intensity)
		sess.ambient_ang = ang or sess.ambient_ang or 0
		Env.boss_wind.set_ambient({ang = sess.ambient_ang, intensity = intensity or 0.22})
	end

	function Env.set_wind_ang(sess, ang, intensity)
		sess.ambient_ang = ang
		Env.boss_wind.set_direction({ang = ang, intensity = intensity or 0.55})
	end
	function Env.track_obj(sess, ent, kind)
		if not sess or not ent then return end
		local key = Env.ptr(ent)
		if not key then return end
		sess.objects[key] = ent
		local d = ent:GetData()
		d[Env.OBJ_KEY] = kind or true
		d[Env.M.own_key .. "owner"] = sess.boss_ptr
	end

	function Env.is_lingering_projectile(ent)
		if not ent or not ent.GetData then return false end
		local d = ent:GetData()
		return d[Env.M.own_key .. "gust"] == true
			or d[Env.M.own_key .. "split_child"] == true
	end

	--- Hard clear: cancel / death / leave room / shutdown.
	function Env.clear_objects(sess)
		if not sess then return end
		for key, ent in pairs(sess.objects) do
			if ent and ent.Exists and ent:Exists() and ent.Remove then
				ent:Remove()
			end
			sess.objects[key] = nil
		end
		sess.wall = nil
		Env.p1_visual.clear()
	end

	--- Soft prepare for next attack: keep flying gust / split_child; drop wall/FX helpers.
	function Env.clear_ephemeral_objects(sess)
		if not sess then return end
		for key, ent in pairs(sess.objects) do
			if not (ent and ent.Exists and ent:Exists()) then
				sess.objects[key] = nil
			elseif Env.is_lingering_projectile(ent) then
				ent:GetData()[Env.M.own_key .. "orphan"] = true
			else
				if ent.Remove then
					ent:Remove()
				end
				sess.objects[key] = nil
			end
		end
		sess.wall = nil
		Env.p1_visual.clear()
	end

	--- True when the projectile sprite bbox has fully left the screen simulation rect.
	function Env.projectile_fully_offscreen(ent)
		if not ent or not ent.Position then return true end
		local half = Env.wind_emission.sprite_half()
		if ent.Scale then
			half = half * math.max(0.5, ent.Scale)
		end
		return Env.wind_emission.bbox_fully_outside(
			ent.Position,
			half,
			Env.wind_emission.simulation_rect()
		)
	end

	-- Natural end: mode-aware. Attack end ≠ projectile death.
	-- Gust: soft nudge only; lifetime owned by offscreen cull / maintain.
	-- Split children: keep flying until room exit.
	-- Sweep: drop wall helpers; never timer-delete lingering projectiles.
	function Env.release_objects(sess, mode)
		if not sess then return end
		mode = mode or "auto"
		if mode == "auto" then
			if sess.attack == "wind_split" then
				mode = "split"
			elseif sess.attack == "wind_gust" then
				mode = "gust"
			elseif sess.attack == "wind_sweep" then
				mode = "sweep"
			else
				mode = "sweep"
			end
		end
		if mode == "hard" then
			Env.clear_objects(sess)
			sess.release_frames = nil
			return
		end
		local dir = Env.wind_dir_vec(sess.ambient_ang or 0)
		for key, ent in pairs(sess.objects) do
			if ent and ent.Exists and ent:Exists() then
				local d = ent:GetData()
				if mode == "split" then
					if d[Env.M.own_key .. "split_parent"]
						or d[Env.M.own_key .. "cut_fx"]
						or d[Env.M.own_key .. "split_shatter"]
					then
						ent:Remove()
						sess.objects[key] = nil
					elseif d[Env.M.own_key .. "split_child"] then
						-- Independent flight: no fall_mode, no phase-end damage cancel.
						d[Env.M.own_key .. "fall_mode"] = nil
						local age = d[Env.M.own_key .. "fan_age"] or 0
						if age >= Env.SPLIT_CHILD_HARMLESS then
							ent.CollisionDamage = 1
						end
						d[Env.RATE_KEY] = d[Env.RATE_KEY] or (Env.SPLIT_WIND_RATE * 0.45)
					elseif not Env.is_lingering_projectile(ent) then
						ent:Remove()
						sess.objects[key] = nil
					end
				elseif mode == "gust" then
					if d[Env.M.own_key .. "gust"] then
						-- Soft wind nudge; keep damage if already risen. No forced timer cull.
						local cur = ent.Velocity or Vector(0, 0)
						local speed = math.max(3.2, cur:Length())
						local blended = cur * 0.7 + dir:Resized(speed) * 0.3
						if blended:Length() < 0.15 then
							blended = dir:Resized(speed)
						end
						ent.Velocity = blended:Resized(math.min(speed + 0.8, blended:Length() + 0.4))
						d[Env.RATE_KEY] = (d[Env.RATE_KEY] or Env.GUST_RATE_BURST) * 0.55
						d[Env.M.own_key .. "release_vel"] = true
						d[Env.M.own_key .. "orphan"] = true
						if d[Env.M.own_key .. "gust_risen"] then
							ent.CollisionDamage = 1
						end
					elseif not Env.is_lingering_projectile(ent) then
						ent:Remove()
						sess.objects[key] = nil
					end
				else
					-- Sweep / default soft end: drop non-lingering helpers only.
					if Env.is_lingering_projectile(ent) then
						d[Env.M.own_key .. "orphan"] = true
					else
						ent:Remove()
						sess.objects[key] = nil
					end
				end
			else
				sess.objects[key] = nil
			end
		end
		sess.release_mode = mode
		-- Never force-delete gust / sweep leftovers on a Boss timer.
		sess.release_frames = nil
	end

	function Env.hold_projectile_height(ent)
		if not ent or not ent.Exists or not ent:Exists() then return end
		local d = ent:GetData()
		if d[Env.M.own_key .. "fall_mode"] then return end
		local h = d[Env.HOLD_KEY] or Env.M.HOLD_HEIGHT
		ent.Height = h
		ent.FallingSpeed = 0
		ent.FallingAccel = -0.1
	end

	function Env.out_of_storm(pos, margin)
		-- Cull against storm simulation rect (screen view + margin), not room floor only.
		local rect = Env.wind_emission.simulation_rect()
		margin = margin or 0
		return pos.X < rect.minx - margin or pos.X > rect.maxx + margin
			or pos.Y < rect.miny - margin or pos.Y > rect.maxy + margin
	end

	--- True once projectile center has fully left the room floor (+ margin).
	function Env.out_of_room(pos, margin)
		local tl, br = Env.room_bounds()
		margin = margin or Env.ROOM_EXIT_MARGIN
		return pos.X < tl.X - margin or pos.X > br.X + margin
			or pos.Y < tl.Y - margin or pos.Y > br.Y + margin
	end

	function Env.spawn_blade(boss, pos, vel, opts)
		opts = opts or {}
		local q = Isaac.Spawn(EntityType.ENTITY_PROJECTILE, 0, 0, pos, vel or Vector(0, 0), boss):ToProjectile()
		if not q then return nil end
		q.ProjectileFlags = q.ProjectileFlags | ProjectileFlags.NO_WALL_COLLIDE
		q.Height = opts.height or Env.M.HOLD_HEIGHT
		q.FallingSpeed = 0
		q.FallingAccel = -0.1
		q.Scale = opts.scale or 1.1
		q.CollisionDamage = opts.damage or 0
		local s = q:GetSprite()
		if s then
			s:Load(Env.M.BLOOD_ANM2, true)
			local anim = opts.anim or "BloodTear6"
			s:Play(anim, true)
			local a = opts.alpha or 1
			s.Color = Color(1, 1, 1, a, 0, 0, 0)
			if vel and vel:Length() > 0.1 then
				s.Rotation = vel:GetAngleDegrees()
			elseif opts.rot then
				s.Rotation = opts.rot
			end
		end
		local d = q:GetData()
		d[Env.M.own_key .. "blade"] = true
		d[Env.M.own_key .. "effect"] = true
		d[Env.HOLD_KEY] = opts.height or Env.M.HOLD_HEIGHT
		if opts.wind_rate then
			d[Env.RATE_KEY] = opts.wind_rate
		end
		Env.hold_projectile_height(q)
		return q
	end

end

return {
	register = register,
}
