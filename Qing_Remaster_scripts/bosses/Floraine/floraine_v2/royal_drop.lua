-- P1 signature attack「重落子」: Floraine temporarily steers one active combat NPC.
-- Same Entity / floraine_command / generation — never rematerialize.
-- Flow: RAISE → PARTICLE → EMPOWER → LIFT → TRANSFER → HOVER → RELEASE → DROP → IMPACT → RECOVER
-- Drop waits on Release Drop event. Empower only after particle ENTERING completes.

local enums = require("Qing_Remaster_scripts.core.enums")
local piece_defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")
local piece_controller = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_controller")
local occupancy = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_occupancy")
local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")
local visual = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.visual")
local particles = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.command_particles")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local royal = {}

local PHASE = {
	RAISE = "RAISE",
	PARTICLE = "PARTICLE",
	EMPOWER = "EMPOWER",
	LIFT = "LIFT",
	TRANSFER = "TRANSFER",
	HOVER = "HOVER",
	RELEASE = "RELEASE",
	DROP = "DROP",
	IMPACT = "IMPACT",
	RECOVER = "RECOVER",
}

local job = nil
local job_serial = 0
local last_fail = "none"
local telegraph_sprite = nil
local ring_shots = {}
local bullet_diag = { fired = 0, culled_dist = 0, culled_gone = 0, last_dist = 0 }

local function cfg()
	return {
		raise = defs.P1_ROYAL_RAISE or 12,
		empower = defs.P1_ROYAL_EMPOWER or 8,
		lift = defs.P1_ROYAL_LIFT or 14,
		transfer = defs.P1_ROYAL_TRANSFER or 13,
		hover_min = defs.P1_ROYAL_HOVER or 12,
		drop = defs.P1_ROYAL_DROP or 7,
		impact = defs.P1_ROYAL_IMPACT or 3,
		recover = defs.P1_ROYAL_RECOVER or 10,
		height = defs.P1_ROYAL_HEIGHT or 30,
		bullets = defs.P1_ROYAL_BULLETS or 8,
		bullet_speed = defs.P1_ROYAL_BULLET_SPEED or 8.5,
		bullet_height = defs.P1_ROYAL_BULLET_HEIGHT or -26,
		bullet_fall_speed = defs.P1_ROYAL_BULLET_FALL_SPEED or -0.1,
		bullet_fall_accel = defs.P1_ROYAL_BULLET_FALL_ACCEL or -0.03,
		bullet_scale = defs.P1_ROYAL_BULLET_SCALE or 1.10,
		bullet_max_dist = defs.P1_ROYAL_BULLET_MAX_DIST or 260,
		tilt = 8,
		particle_timeout = 120, -- safety only; never treated as hit
	}
end

local function ease_out(t)
	t = math.max(0, math.min(1, t))
	return 1 - (1 - t) * (1 - t)
end

local function ease_in_cubic(t)
	t = math.max(0, math.min(1, t))
	return t * t * t
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function find_piece(ptr_hash)
	if not ptr_hash then
		return nil
	end
	for _, ent in ipairs(Isaac.FindByType(996, enums.Enemies.chess_piece, -1, false, false)) do
		if GetPtrHash(ent) == ptr_hash and ent:Exists() and not ent:IsDead() then
			return ent
		end
	end
	return nil
end

local function pick_piece()
	local candidates = {}
	for _, ent in ipairs(Isaac.FindByType(996, enums.Enemies.chess_piece, -1, false, false)) do
		local d = piece_controller.get_data(ent)
		if d and d.director_id == defs.DIRECTOR_ID
			and d.floraine_command
			and ent:Exists() and not ent:IsDead()
			and piece_controller.can_accept_order(ent)
			and d.action_state == "IDLE" then
			candidates[#candidates + 1] = ent
		end
	end
	if #candidates < 1 then
		return nil
	end
	local target = nil
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if p and p:Exists() and not p:IsDead() then
			target = p
			break
		end
	end
	if not target then
		return candidates[1]
	end
	local best, best_d = candidates[1], 1e12
	for _, ent in ipairs(candidates) do
		local d = (ent.Position - target.Position):LengthSquared()
		if d < best_d then
			best_d = d
			best = ent
		end
	end
	return best
end

local function pick_dest(ent, data)
	local landings = piece_controller.legal_landings(ent, data.kind)
	if not landings or #landings < 1 then
		return nil
	end
	local self_id = GetPtrHash(ent)
	local legal = {}
	for _, pos in ipairs(landings) do
		local ok = select(1, occupancy.can_enter(self_id, pos, {}))
		if ok then
			local _, g0 = occupancy.snap_world(ent.Position)
			local _, g1 = occupancy.snap_world(pos)
			if g1 ~= g0 then
				legal[#legal + 1] = pos
			end
		end
	end
	if #legal < 1 then
		return nil
	end
	local target = nil
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if p and p:Exists() and not p:IsDead() then
			target = p
			break
		end
	end
	if not target then
		return legal[1]
	end
	local best, best_s = legal[1], -1e9
	local cur_d = (ent.Position - target.Position):Length()
	for _, pos in ipairs(legal) do
		local d = (pos - target.Position):Length()
		local s = (cur_d - d)
		if d < 50 then
			s = s - 40
		end
		if s > best_s then
			best_s = s
			best = pos
		end
	end
	return best
end

local function ensure_telegraph()
	if telegraph_sprite then
		return telegraph_sprite
	end
	local s = Sprite()
	s:Load(piece_defs.GROUND_SHADOW_ANM2 or "gfx/boss/Floraine/piece_ground_shadow.anm2", true)
	s:Play("Idle", true)
	telegraph_sprite = s
	return s
end

local function prune_ring_shots()
	if #ring_shots < 1 then
		return
	end
	local keep = {}
	for _, row in ipairs(ring_shots) do
		local proj = row.ref and row.ref.Entity
		if not proj or not proj:Exists() then
			bullet_diag.culled_gone = (bullet_diag.culled_gone or 0) + 1
		else
			local dist = (proj.Position - row.spawn):Length()
			bullet_diag.last_dist = dist
			if dist >= (row.max_dist or 260) then
				proj:Remove()
				bullet_diag.culled_dist = (bullet_diag.culled_dist or 0) + 1
			else
				keep[#keep + 1] = row
			end
		end
	end
	ring_shots = keep
end

local function fire_ring(pos, spawner)
	local c = cfg()
	local n = c.bullets
	local speed = c.bullet_speed
	ring_shots = {}
	for i = 0, n - 1 do
		local ang = (360 / n) * i
		local vel = Vector.FromAngle(ang) * speed
		local proj = Isaac.Spawn(EntityType.ENTITY_PROJECTILE, 0, 0, pos, vel, spawner):ToProjectile()
		if proj then
			proj.Color = Color(1, 0.2, 0.28, 1, 0.45, 0.02, 0.05)
			proj.Scale = c.bullet_scale or 1.10
			proj.Height = c.bullet_height or -26
			proj.FallingSpeed = c.bullet_fall_speed or -0.1
			proj.FallingAccel = c.bullet_fall_accel or -0.03
			proj:GetData().QingFloraineRoyalDrop = true
			ring_shots[#ring_shots + 1] = {
				ref = EntityRef(proj),
				spawn = Vector(pos.X, pos.Y),
				max_dist = c.bullet_max_dist or 260,
			}
			bullet_diag.fired = (bullet_diag.fired or 0) + 1
		end
	end
end

local function ensure_rdv(data)
	if not data.royal_drop_visual then
		data.royal_drop_visual = {
			empowered = false,
			color_progress = 0,
			outline_alpha = 0,
			impact_progress = 0,
		}
	end
	return data.royal_drop_visual
end

local function clear_piece_job_fields(data)
	if not data then
		return
	end
	data.royal_drop = nil
	data.royal_drop_visual = nil
	data.visual_height = 0
	data.visual_tilt = 0
	data.visual_squash = nil
	if data.action_state == "ROYAL_DROP" then
		data.action_state = "IDLE"
	end
end

function royal.cancel(reason)
	if not job then
		last_fail = reason or "cancel"
		return
	end
	local ent = find_piece(job.piece_ptr)
	if ent then
		local data = piece_controller.get_data(ent)
		if job.occ_committed then
			occupancy.release_target(job.piece_ptr)
			occupancy.resync(job.piece_ptr, ent.Position, {})
		end
		clear_piece_job_fields(data)
		if data then
			-- Restore neutral layers after cancel.
			local s = ent:GetSprite()
			if s then
				s.Color = Color(1, 1, 1, 1, 0, 0, 0)
				s.Scale = Vector(1, 1)
			end
		end
	elseif job.piece_ptr and job.occ_committed then
		occupancy.release_target(job.piece_ptr)
		occupancy.release_current(job.piece_ptr)
	end
	last_fail = reason or "cancelled"
	job = nil
end

function royal.is_busy()
	return job ~= nil
end

function royal.get_job()
	return job
end

function royal.try_begin(boss_ent)
	if job then
		last_fail = "busy"
		return false, last_fail
	end
	local piece = pick_piece()
	if not piece then
		last_fail = "no_piece"
		return false, last_fail
	end
	local data = piece_controller.get_data(piece)
	if not data then
		last_fail = "no_data"
		return false, last_fail
	end
	local dest = pick_dest(piece, data)
	if not dest then
		last_fail = "no_dest"
		return false, last_fail
	end
	local self_id = GetPtrHash(piece)
	local ok, gidx, snap = occupancy.commit_move(self_id, dest, {})
	if not ok then
		last_fail = tostring(gidx)
		return false, last_fail
	end
	dest = snap or dest
	local c = cfg()
	job_serial = job_serial + 1
	job = {
		token = job_serial,
		phase = PHASE.RAISE,
		elapsed = 0,
		piece_ptr = self_id,
		entity_ref = EntityRef(piece),
		start = Vector(piece.Position.X, piece.Position.Y),
		dest = Vector(dest.X, dest.Y),
		dest_gidx = gidx,
		occ_committed = true,
		particle_sent = false,
		particle_hit = false,
		release_played = false,
		drop_armed = false,
		drop_fallback_used = false,
		impact_fired = false,
		boss_ptr = boss_ent and GetPtrHash(boss_ent) or nil,
		height = c.height,
		tilt = c.tilt,
	}
	data.action_state = "ROYAL_DROP"
	data.phase_elapsed = 0
	data.royal_drop = true
	data.visual_height = 0
	data.visual_tilt = 0
	data.visual_squash = 1
	-- No premature SetColor — empower waits for particle ENTERING.
	ensure_rdv(data)
	data.royal_drop_visual.empowered = false
	data.royal_drop_visual.color_progress = 0
	data.royal_drop_visual.outline_alpha = 0
	data.royal_drop_visual.impact_progress = 0
	if boss_ent then
		visual.order(boss_ent)
		visual.flash(boss_ent, 0.3, 0.12, 0.05, c.raise)
	end
	last_fail = "started"
	return true, "ok"
end

local function piece_head(ent, height)
	local h = height or 0
	local po = ent.PositionOffset
	local oy = po and po.Y or -h
	return Vector(ent.Position.X, ent.Position.Y - 18 + oy)
end

local function drop_event(boss_ent)
	if not boss_ent then
		return false
	end
	local s = boss_ent:GetSprite()
	if not s or s:GetAnimation() ~= "Release" then
		return false
	end
	if s.IsEventTriggered and s:IsEventTriggered("Drop") then
		return true
	end
	if not job.drop_fallback_used and s.GetFrame and (s:GetFrame() or 0) >= 4 then
		job.drop_fallback_used = true
		return true
	end
	return false
end

local function sync_piece_visual(ent, data, height, tilt)
	data.visual_height = height or 0
	data.visual_tilt = tilt or 0
	data.action_state = "ROYAL_DROP"
end

function royal.tick_projectiles()
	prune_ring_shots()
end

function royal.tick(boss_ent)
	prune_ring_shots()
	if not job then
		return
	end
	local c = cfg()
	job.elapsed = (job.elapsed or 0) + 1
	local ent = find_piece(job.piece_ptr)
	if not ent then
		royal.cancel("piece_gone")
		return
	end
	if ent:IsDead() or (ent.HitPoints ~= nil and ent.HitPoints <= 0) then
		royal.cancel("piece_dead")
		return
	end
	local data = piece_controller.get_data(ent)
	if not data then
		royal.cancel("no_data")
		return
	end

	local function set_phase(p)
		job.phase = p
		job.elapsed = 0
	end

	ent.Velocity = Vector.Zero
	local rdv = ensure_rdv(data)

	if job.phase == PHASE.RAISE then
		sync_piece_visual(ent, data, 0, 0)
		if job.elapsed >= c.raise then
			set_phase(PHASE.PARTICLE)
		end
		return
	end

	if job.phase == PHASE.PARTICLE then
		if not job.particle_sent then
			job.particle_sent = true
			local tip = visual.staff_tip_world and visual.staff_tip_world(boss_ent)
				or (boss_ent and (boss_ent.Position + Vector(-16, -90)) or ent.Position)
			local token = job.token
			particles.launch({
				start = tip,
				finish = piece_head(ent, 0),
				preset = "royal",
				command_id = "royal_drop",
				token = token,
				control_bias = 0,
				finish_follow = EntityRef(ent),
				on_arrive = function(p)
					if not job or job.token ~= token then
						return
					end
					if job.phase ~= PHASE.PARTICLE then
						return
					end
					if p and p.token and p.token ~= token then
						return
					end
					job.particle_hit = true
				end,
			})
		end
		sync_piece_visual(ent, data, 0, 0)
		if job.particle_hit then
			rdv.empowered = true
			set_phase(PHASE.EMPOWER)
		elseif job.elapsed >= c.particle_timeout then
			-- Timeout ≠ hit: cancel skill (occupancy released; piece stays).
			royal.cancel("particle_timeout")
		end
		return
	end

	if job.phase == PHASE.EMPOWER then
		local t = math.min(1, job.elapsed / math.max(1, c.empower))
		rdv.empowered = true
		rdv.color_progress = t
		rdv.outline_alpha = t
		sync_piece_visual(ent, data, 0, 0)
		if job.elapsed >= c.empower then
			rdv.color_progress = 1
			rdv.outline_alpha = 1
			set_phase(PHASE.LIFT)
		end
		return
	end

	if job.phase == PHASE.LIFT then
		local t = ease_out(job.elapsed / math.max(1, c.lift))
		rdv.color_progress = 1
		rdv.outline_alpha = 1
		sync_piece_visual(ent, data, c.height * t, c.tilt * t)
		if job.elapsed >= c.lift then
			occupancy.release_current(job.piece_ptr)
			set_phase(PHASE.TRANSFER)
		end
		return
	end

	if job.phase == PHASE.TRANSFER then
		local t = ease_out(job.elapsed / math.max(1, c.transfer))
		local pos = Vector(
			lerp(job.start.X, job.dest.X, t),
			lerp(job.start.Y, job.dest.Y, t)
		)
		ent.Position = pos
		rdv.color_progress = 1
		rdv.outline_alpha = 1
		sync_piece_visual(ent, data, c.height, c.tilt * (1 - t))
		if job.elapsed >= c.transfer then
			ent.Position = Vector(job.dest.X, job.dest.Y)
			set_phase(PHASE.HOVER)
		end
		return
	end

	if job.phase == PHASE.HOVER then
		ent.Position = Vector(job.dest.X, job.dest.Y)
		rdv.color_progress = 1
		rdv.outline_alpha = 1
		sync_piece_visual(ent, data, c.height, 0)
		if job.elapsed >= c.hover_min then
			if boss_ent then
				visual.release(boss_ent)
			end
			job.release_played = true
			job.drop_armed = true
			set_phase(PHASE.RELEASE)
		end
		return
	end

	if job.phase == PHASE.RELEASE then
		ent.Position = Vector(job.dest.X, job.dest.Y)
		rdv.color_progress = 1
		rdv.outline_alpha = 1
		sync_piece_visual(ent, data, c.height, 0)
		if job.drop_armed and drop_event(boss_ent) then
			job.drop_armed = false
			set_phase(PHASE.DROP)
		elseif job.elapsed > 45 then
			set_phase(PHASE.DROP)
		end
		return
	end

	if job.phase == PHASE.DROP then
		-- Cubic ease-in: slow start, accelerating smash into the ground.
		local t = ease_in_cubic(job.elapsed / math.max(1, c.drop))
		ent.Position = Vector(job.dest.X, job.dest.Y)
		rdv.color_progress = 1
		rdv.outline_alpha = 1
		sync_piece_visual(ent, data, c.height * (1 - t), 0)
		if job.elapsed >= c.drop then
			ent.Position = Vector(job.dest.X, job.dest.Y)
			occupancy.finish_move(job.piece_ptr, { pos = ent.Position })
			job.occ_committed = false
			set_phase(PHASE.IMPACT)
		end
		return
	end

	if job.phase == PHASE.IMPACT then
		ent.Position = Vector(job.dest.X, job.dest.Y)
		sync_piece_visual(ent, data, 0, 0)
		if not job.impact_fired then
			job.impact_fired = true
			-- One-shot: sfx + bullets share IMPACT.
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_ROCK_CRUMBLE, 1.05, 0.85, false, 0, 2)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_STONE_IMPACT, 0.85, 0.9, false, 0, 2)
			fire_ring(ent.Position, ent)
			rdv.impact_progress = 1
		end
		local t = math.min(1, job.elapsed / math.max(1, c.impact))
		-- Squash then recover: Y scale dips then returns.
		local squash = 1 - 0.18 * math.sin(t * math.pi)
		data.visual_squash = squash
		rdv.impact_progress = 1 - t
		rdv.color_progress = 1
		rdv.outline_alpha = 1
		if job.elapsed >= c.impact then
			data.visual_squash = 1
			rdv.impact_progress = 0
			set_phase(PHASE.RECOVER)
		end
		return
	end

	if job.phase == PHASE.RECOVER then
		ent.Position = Vector(job.dest.X, job.dest.Y)
		sync_piece_visual(ent, data, 0, 0)
		local t = math.min(1, job.elapsed / math.max(1, c.recover))
		rdv.empowered = t < 1
		rdv.color_progress = 1 - t
		rdv.outline_alpha = 1 - t
		rdv.impact_progress = 0
		data.visual_squash = 1
		if job.elapsed >= c.recover then
			clear_piece_job_fields(data)
			data.action_state = "IDLE"
			last_fail = "landed"
			job = nil
		end
		return
	end
end

function royal.render()
	if not job then
		return
	end
	if job.phase ~= PHASE.HOVER and job.phase ~= PHASE.RELEASE and job.phase ~= PHASE.TRANSFER
		and job.phase ~= PHASE.DROP and job.phase ~= PHASE.IMPACT then
		return
	end
	local s = ensure_telegraph()
	local screen = Isaac.WorldToScreen(job.dest)
	local pulse = 0.5 + 0.5 * math.sin((job.elapsed or 0) * 0.45)
	local alpha = 0.4
	local scale = 1.05
	if job.phase == PHASE.TRANSFER then
		alpha = 0.25 + 0.2 * ease_out(math.min(1, (job.elapsed or 0) / math.max(1, cfg().transfer)))
		scale = 0.95
	elseif job.phase == PHASE.HOVER or job.phase == PHASE.RELEASE then
		alpha = 0.45 + 0.4 * pulse
		scale = 1.1 + 0.12 * pulse
	elseif job.phase == PHASE.DROP then
		local t = ease_in_cubic(math.min(1, (job.elapsed or 0) / math.max(1, cfg().drop)))
		alpha = 0.35 + 0.4 * t
		scale = 1.15 + 0.15 * t
	elseif job.phase == PHASE.IMPACT then
		alpha = 0.55 * (1 - math.min(1, (job.elapsed or 0) / math.max(1, cfg().impact)))
		scale = 1.3
	end
	s.Color = Color(1, 0.12, 0.18, alpha * 0.55, 0.45, 0.05, 0.05)
	s.Scale = Vector(scale * 1.35, scale * 1.35)
	s:Render(screen, Vector.Zero, Vector.Zero)
	s.Color = Color(1, 0.18, 0.22, alpha, 0.4, 0.04, 0.04)
	s.Scale = Vector(scale, scale)
	s:Render(screen, Vector.Zero, Vector.Zero)
end

function royal.on_piece_removed(ent)
	if not job or not ent then
		return
	end
	if GetPtrHash(ent) == job.piece_ptr then
		royal.cancel("piece_removed")
	end
end

function royal.diag()
	return {
		busy = job ~= nil,
		last_fail = last_fail,
		phase = job and job.phase,
		elapsed = job and job.elapsed,
		token = job and job.token,
		particle_hit = job and job.particle_hit == true,
		impact_fired = job and job.impact_fired == true,
		piece_ptr = job and job.piece_ptr,
		dest = job and job.dest and { x = job.dest.X, y = job.dest.Y },
		bullets = {
			active = #ring_shots,
			fired = bullet_diag.fired,
			culled_dist = bullet_diag.culled_dist,
			culled_gone = bullet_diag.culled_gone,
			last_dist = bullet_diag.last_dist,
			speed = cfg().bullet_speed,
			max_dist = cfg().bullet_max_dist,
		},
	}
end

function royal.clear(reason)
	royal.cancel(reason or "clear")
	for _, row in ipairs(ring_shots) do
		local proj = row.ref and row.ref.Entity
		if proj and proj.Exists and proj:Exists() then
			proj:Remove()
		end
	end
	ring_shots = {}
end

royal.PHASE = PHASE

return royal
