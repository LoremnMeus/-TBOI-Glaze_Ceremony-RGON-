-- P1 signature attack「重落子」: Floraine temporarily steers one active combat NPC.
-- Same Entity / floraine_command / generation — never rematerialize.
-- Flow: RAISE → PARTICLE → EMPOWER → LIFT → TRANSFER → ALIGN → HOVER → RELEASE → DROP → IMPACT → RECOVER
-- V4: same-kind outline ghost (auxiliary) + hard 40×40 dest-cell fill/border until impact.
-- Cell binds to job.dest / dest_gidx; never uses piece_ground_shadow as telegraph.

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
	ALIGN = "ALIGN",
	HOVER = "HOVER",
	RELEASE = "RELEASE",
	DROP = "DROP",
	IMPACT = "IMPACT",
	RECOVER = "RECOVER",
}

local OUTLINE = {
	HIDDEN = "HIDDEN",
	APPEARING = "APPEARING",
	HOLDING = "HOLDING",
	MATCHED = "MATCHED",
	DONE = "DONE",
}

local job = nil
local job_serial = 0
local last_fail = "none"
local target_outline_sprite = nil
local target_outline_kind = nil
local ring_shots = {}
local bullet_diag = { fired = 0, culled_dist = 0, culled_gone = 0, last_dist = 0 }

local function cell_cfg()
	return defs.P1_ROYAL_CELL or {}
end

local function cfg()
	local cc = cell_cfg()
	return {
		raise = defs.P1_ROYAL_RAISE or 12,
		empower = defs.P1_ROYAL_EMPOWER or 8,
		lift = defs.P1_ROYAL_LIFT or 14,
		transfer = defs.P1_ROYAL_TRANSFER or 13,
		align = defs.P1_ROYAL_ALIGN or 4,
		outline_appear = defs.P1_ROYAL_OUTLINE_APPEAR or 5,
		outline_hold = defs.P1_ROYAL_OUTLINE_HOLD or 0.55,
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
		cell_appear = cc.appear_frames or 5,
		cell_fill_alpha = cc.fill_alpha or 0.40,
		cell_release_alpha = cc.release_alpha or 0.48,
		cell_drop_alpha = cc.drop_alpha or 0.58,
		cell_impact_alpha = cc.impact_alpha or 0.85,
		cell_fade_frames = cc.fade_frames or 7,
		cell_border_thickness = cc.border_thickness or 2,
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

local function clear_cell_mark()
	if job then
		job.cell_alpha = 0
		job.cell_fade_left = nil
		job.cell_fade_armed = nil
		job.cell_flash_left = nil
	end
end

--- Phase-driven fill alpha for the dest cell (no breathing scale).
local function resolve_cell_alpha(c)
	if not job or not job.dest then
		return 0, 0
	end
	-- Impact/recover fade owns the mark after smash.
	if job.cell_fade_left ~= nil then
		local fade_n = math.max(1, c.cell_fade_frames or 7)
		local left = math.max(0, job.cell_fade_left)
		local t = left / fade_n
		local flash = (job.cell_flash_left or 0) > 0
		local base = (c.cell_impact_alpha or 0.85) * t
		if flash then
			base = math.min(1, base + 0.15)
		end
		return base, math.min(1, base + 0.2)
	end
	local phase = job.phase
	if phase == PHASE.RAISE or phase == PHASE.PARTICLE or phase == PHASE.EMPOWER then
		return 0, 0
	end
	if phase == PHASE.LIFT then
		local appear = math.max(1, c.cell_appear or 5)
		local start = math.max(0, (c.lift or 14) - appear)
		if (job.elapsed or 0) < start then
			return 0, 0
		end
		local t = ((job.elapsed or 0) - start) / appear
		local a = (c.cell_fill_alpha or 0.40) * math.max(0, math.min(1, t))
		return a, math.min(1, a + 0.35)
	end
	local hold = c.cell_fill_alpha or 0.40
	if phase == PHASE.TRANSFER or phase == PHASE.ALIGN or phase == PHASE.HOVER then
		return hold, math.min(1, hold + 0.4)
	end
	if phase == PHASE.RELEASE then
		local a = c.cell_release_alpha or 0.48
		return a, math.min(1, a + 0.4)
	end
	if phase == PHASE.DROP then
		local a = c.cell_drop_alpha or 0.58
		return a, math.min(1, a + 0.35)
	end
	return 0, 0
end

local function tick_cell_mark(c)
	if not job then
		return
	end
	if job.cell_fade_left ~= nil then
		job.cell_fade_left = (job.cell_fade_left or 0) - 1
		if (job.cell_flash_left or 0) > 0 then
			job.cell_flash_left = job.cell_flash_left - 1
		end
		if job.cell_fade_left < 0 then
			clear_cell_mark()
		end
		return
	end
	local fill_a = select(1, resolve_cell_alpha(c))
	job.cell_alpha = fill_a
end

local function set_layer_vis_color(sprite, layer_id, visible, color)
	if not sprite or not sprite.GetLayer then
		return
	end
	local ok, layer = pcall(function()
		if type(layer_id) == "string" then
			return sprite:GetLayer(layer_id) or sprite:GetLayer(layer_id == "outline" and 1 or 0)
		end
		return sprite:GetLayer(layer_id)
	end)
	if not (ok and layer) then
		return
	end
	if layer.SetVisible then
		layer:SetVisible(visible == true)
	end
	if layer.SetColor and color then
		layer:SetColor(color)
	end
end

--- Outline-only ghost using the same ANM2 / pivot / scale as the real piece.
local function ensure_target_outline(kind)
	kind = tonumber(kind) or piece_defs.KIND.PAWN
	if target_outline_sprite and target_outline_kind == kind then
		return target_outline_sprite
	end
	local s = Sprite()
	local profile = piece_defs.get(kind)
	s:Load(piece_defs.ANM2 or "gfx/boss/Floraine/pieces.anm2", true)
	s:ReplaceSpritesheet(0, profile.spritesheet)
	s:ReplaceSpritesheet(1, piece_defs.outline_sheet(kind))
	s:LoadGraphics()
	s:Play("Idle", true)
	s.Offset = Vector.Zero
	s.Rotation = 0
	s.Scale = Vector(1, 1)
	s.Color = Color(1, 1, 1, 1, 0, 0, 0)
	set_layer_vis_color(s, "body", false, Color(1, 1, 1, 0, 0, 0, 0))
	set_layer_vis_color(s, "outline", false, Color(1, 1, 1, 0, 0, 0, 0))
	target_outline_sprite = s
	target_outline_kind = kind
	return s
end

local function apply_target_outline_alpha(alpha)
	local s = target_outline_sprite
	if not s then
		return
	end
	local a = math.max(0, math.min(1, alpha or 0))
	local visible = a > 0.01
	set_layer_vis_color(s, "body", false, Color(1, 1, 1, 0, 0, 0, 0))
	-- Soft red/white outline; body stays hidden.
	set_layer_vis_color(s, "outline", visible, Color(1.0, 0.28, 0.32, visible and a or 0, 0.12, 0.02, 0.02))
end

local function clear_target_outline()
	if job and job.target_outline then
		job.target_outline.alpha = 0
		job.target_outline.phase = OUTLINE.DONE
	end
	apply_target_outline_alpha(0)
end

local function tick_target_outline_lift(c)
	local to = job and job.target_outline
	if not to then
		return
	end
	local appear = math.max(1, c.outline_appear or 5)
	local start = math.max(0, (c.lift or 14) - appear)
	if job.elapsed < start then
		to.phase = OUTLINE.HIDDEN
		to.alpha = 0
		return
	end
	to.phase = OUTLINE.APPEARING
	local t = (job.elapsed - start) / appear
	t = math.max(0, math.min(1, t))
	to.alpha = (c.outline_hold or 0.55) * t
	if t >= 1 then
		to.phase = OUTLINE.HOLDING
		to.alpha = c.outline_hold or 0.55
	end
end

local function tick_target_outline_hold(c)
	local to = job and job.target_outline
	if not to or to.phase == OUTLINE.DONE or to.phase == OUTLINE.HIDDEN then
		return
	end
	to.phase = OUTLINE.HOLDING
	-- Mild breath; must not overpower the real piece.
	local pulse = 0.5 + 0.5 * math.sin((job.elapsed or 0) * 0.35)
	local hold = c.outline_hold or 0.55
	to.alpha = hold * (0.92 + 0.08 * pulse)
end

local function tick_target_outline_align(c)
	local to = job and job.target_outline
	if not to then
		return
	end
	to.phase = OUTLINE.MATCHED
	local dur = math.max(1, c.align or 4)
	local t = math.max(0, math.min(1, (job.elapsed or 0) / dur))
	-- Brief brighten on match, then collapse to transparent.
	local hold = c.outline_hold or 0.55
	if t < 0.25 then
		to.alpha = math.min(1, hold + 0.25)
	else
		local u = (t - 0.25) / 0.75
		to.alpha = hold * (1 - u)
	end
	if t >= 1 then
		to.alpha = 0
		to.phase = OUTLINE.DONE
	end
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

local function clear_piece_job_fields(data, ent)
	if not data then
		return
	end
	data.royal_drop = nil
	-- Sprite outline/body must reset BEFORE dropping royal_drop_visual ownership.
	local ok_v, piece_visual = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.chess_piece_visual")
	if ok_v and piece_visual and piece_visual.clear_royal_drop_visual and ent then
		piece_visual.clear_royal_drop_visual(ent, data)
	else
		data.royal_drop_visual = nil
		data.visual_height = 0
		data.visual_tilt = 0
		data.visual_squash = nil
	end
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
		clear_piece_job_fields(data, ent)
	elseif job.piece_ptr and job.occ_committed then
		occupancy.release_target(job.piece_ptr)
		occupancy.release_current(job.piece_ptr)
	end
	clear_target_outline()
	clear_cell_mark()
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
		target_outline = {
			kind = data.kind or piece_defs.KIND.PAWN,
			pos = Vector(dest.X, dest.Y),
			alpha = 0,
			phase = OUTLINE.HIDDEN,
		},
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
	ensure_target_outline(job.target_outline.kind)
	apply_target_outline_alpha(0)
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
	tick_cell_mark(c)
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
		tick_target_outline_lift(c)
		if job.elapsed >= c.lift then
			occupancy.release_current(job.piece_ptr)
			-- Snap outline to hold so TRANSFER never starts with a half-faded ghost.
			if job.target_outline then
				job.target_outline.phase = OUTLINE.HOLDING
				job.target_outline.alpha = c.outline_hold or 0.55
			end
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
		tick_target_outline_hold(c)
		-- Near arrival: slightly brighten the fixed ghost (still not moving).
		if job.target_outline and t > 0.75 then
			local hold = c.outline_hold or 0.55
			job.target_outline.alpha = math.min(0.85, hold + 0.2 * ((t - 0.75) / 0.25))
		end
		if job.elapsed >= c.transfer then
			ent.Position = Vector(job.dest.X, job.dest.Y)
			set_phase(PHASE.ALIGN)
		end
		return
	end

	if job.phase == PHASE.ALIGN then
		-- Exact airborne overlap: no XY drift, tilt zero, height held.
		ent.Position = Vector(job.dest.X, job.dest.Y)
		rdv.color_progress = 1
		rdv.outline_alpha = 1
		sync_piece_visual(ent, data, c.height, 0)
		tick_target_outline_align(c)
		if job.elapsed >= (c.align or 4) then
			clear_target_outline()
			set_phase(PHASE.HOVER)
		end
		return
	end

	if job.phase == PHASE.HOVER then
		ent.Position = Vector(job.dest.X, job.dest.Y)
		rdv.color_progress = 1
		rdv.outline_alpha = 1
		sync_piece_visual(ent, data, c.height, 0)
		-- Ghost already finished its job in ALIGN.
		if job.target_outline and job.target_outline.phase ~= OUTLINE.DONE then
			clear_target_outline()
		end
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
			-- One-shot exclusive slam SFX (death uses ROCK_CRUMBLE separately).
			local drop_sfx = enums.SoundEffect and enums.SoundEffect.Floraine_Royal_Drop
			if drop_sfx and drop_sfx >= 0 then
				sound_tracker.PlayStackedSound(drop_sfx, 1.05, 1.0, false, 0, 2)
			else
				-- Fallback if content/sounds.xml not loaded yet.
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_STONE_IMPACT, 1.0, 0.85, false, 0, 2)
			end
			fire_ring(ent.Position, ent)
			rdv.impact_progress = 1
			-- Cell mark: flash then fade (continues into RECOVER). Armed after tick_cell_mark.
			job.cell_fade_armed = true
			job.cell_fade_left = c.cell_fade_frames or 7
			job.cell_flash_left = 2
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
			clear_piece_job_fields(data, ent)
			data.action_state = "IDLE"
			last_fail = "landed"
			job = nil
		end
		return
	end
end

--- Board-cell overlay for stone_board (drawn after the base chess tile on dest_gidx).
--- Returns nil when idle / wrong index. Does not draw by itself.
function royal.get_board_cell_overlay(index)
	if not job or job.dest_gidx == nil then
		return nil
	end
	if index ~= job.dest_gidx then
		return nil
	end
	local c = cfg()
	local fill_a, border_a = resolve_cell_alpha(c)
	if fill_a <= 0.01 and border_a <= 0.01 then
		return nil
	end
	local cc = cell_cfg()
	return {
		fill = cc.fill or { 1.0, 0.22, 0.28 },
		border = cc.border or { 1.0, 0.48, 0.50 },
		fill_alpha = fill_a,
		border_alpha = border_a,
		border_thickness = c.cell_border_thickness or 2,
		dest_gidx = job.dest_gidx,
	}
end

--- Airborne same-kind outline only (POST_RENDER). Ground mark is owned by stone_board.
function royal.render_air_cues()
	if not job then
		return
	end
	local c = cfg()
	local to = job.target_outline
	if to and to.phase ~= OUTLINE.DONE and to.phase ~= OUTLINE.HIDDEN and (to.alpha or 0) > 0.01 then
		local kind = to.kind or piece_defs.KIND.PAWN
		local s = ensure_target_outline(kind)
		apply_target_outline_alpha(to.alpha)
		local visual_point = Vector(job.dest.X, job.dest.Y - (job.height or c.height))
		s:Render(Isaac.WorldToScreen(visual_point), Vector.Zero, Vector.Zero)
	end
end

--- Compatibility alias: air cues only (ground mark via stone_board provider).
function royal.render()
	royal.render_air_cues()
end

--- LEGACY no-op: ground mark no longer draws from Backdrop / POST_RENDER.
function royal.render_dest_cell()
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
	local to = job and job.target_outline
	local c = cfg()
	local cell_fill, cell_border = 0, 0
	if job then
		cell_fill, cell_border = resolve_cell_alpha(c)
	end
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
		dest_gidx = job and job.dest_gidx,
		cell_mark = job and {
			fill_alpha = cell_fill,
			border_alpha = cell_border,
			fade_left = job.cell_fade_left,
			flash_left = job.cell_flash_left,
		} or nil,
		target_outline = to and {
			kind = to.kind,
			alpha = to.alpha,
			phase = to.phase,
			pos = to.pos and { x = to.pos.X, y = to.pos.Y },
		} or nil,
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

--- Debug: start (or reuse) a royal drop and jump to late LIFT so outline + align can be inspected.
function royal.debug_align_preview(boss_ent)
	if job then
		royal.cancel("debug_align_preview")
	end
	local ok, why = royal.try_begin(boss_ent)
	if not ok then
		return false, why or last_fail
	end
	local ent = find_piece(job.piece_ptr)
	local data = ent and piece_controller.get_data(ent)
	if not ent or not data then
		royal.cancel("debug_no_piece")
		return false, "no_piece"
	end
	local c = cfg()
	local rdv = ensure_rdv(data)
	rdv.empowered = true
	rdv.color_progress = 1
	rdv.outline_alpha = 1
	job.particle_sent = true
	job.particle_hit = true
	-- Jump into the outline appear window of LIFT.
	job.phase = PHASE.LIFT
	job.elapsed = math.max(0, (c.lift or 14) - (c.outline_appear or 5))
	sync_piece_visual(ent, data, c.height * ease_out(job.elapsed / math.max(1, c.lift)), c.tilt * 0.5)
	tick_target_outline_lift(c)
	last_fail = "debug_align_preview"
	return true, "ok"
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
	target_outline_sprite = nil
	target_outline_kind = nil
end


royal.PHASE = PHASE
royal.OUTLINE = OUTLINE

return royal
