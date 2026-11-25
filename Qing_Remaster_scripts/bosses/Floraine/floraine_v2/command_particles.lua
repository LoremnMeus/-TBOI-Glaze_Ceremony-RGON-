-- Red command-soul particles (pure VFX). Staff launch / death inheritance / royal drop.
-- Motion: RISING → HOLDING → FLYING → ENTERING → finished.
-- Gold reward: SCATTERING → HOLDING → FLYING → ENTERING → TRAIL_FADE.
-- Gold uses a short-lived MeusNil carrier so sprite_trail_presets can sync SPRITE_TRAIL.
-- Logic tick advances; Render only draws (red) or reads carrier (gold).

local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Trails = require("Qing_Remaster_scripts.others.sprite_trail_presets")

local particles = {}

local PHASE = {
	RISING = "RISING",
	SCATTERING = "SCATTERING",
	HOLDING = "HOLDING",
	FLYING = "FLYING",
	ENTERING = "ENTERING",
	TRAIL_FADE = "TRAIL_FADE",
}

-- Pawn-only command atlas (offline gen): 32×64 sheet, top body / bottom outline.
-- Content is aspect-preserved inside each 32×32 cell; runtime display Scale = 0.5.
local COMMAND_ANM2 = "gfx/boss/Floraine/command_piece.anm2"
local COMMAND_DISPLAY_SCALE = 0.5
local ORB_ANM2 = defs.GOLD_REWARD_ORB_ANM2 or "gfx/cards/cd03_emp_tear.anm2"
local ORB_ANIM = defs.GOLD_REWARD_ORB_ANIM or "RegularTear6"
local ORB_DISPLAY_SCALE = 0.55

local active = {}
local serial = 0
local last_tick_frame = -1

local PRESETS = {
	opening = defs.PARTICLE_OPENING or { rise = 8, hold = 8, fly = 24, enter = 5 },
	inherit = defs.PARTICLE_INHERIT or { rise = 12, hold = 10, fly = 26, enter = 5 },
	royal = defs.PARTICLE_ROYAL or { rise = 10, hold = 8, fly = 22, enter = 5 },
	["return"] = defs.PARTICLE_RETURN or { rise = 0, hold = 10, fly = 22, enter = 4 },
	gold_reward = defs.PARTICLE_GOLD_REWARD or { scatter = 10, hold = 6, fly = 18, enter = 4 },
	default = { rise = 8, hold = 6, fly = 20, enter = 4 },
}

local GOLD_TRAIL = defs.P1_GOLD_TRAIL or {
	min_radius = 0.12,
	max_radius = 0.08,
	scale = 0.45,
	local_offset = { x = 0, y = 0 },
	color = { r = 1, g = 1, b = 1, a = 1, ro = 0, go = 0, bo = 0 },
	colorize = { r = 1, g = 0.82, b = 0.28, a = 1 },
	reapply_color_each_sync = true,
}
local GOLD_TRAIL_FADE = math.max(1, tonumber(defs.P1_GOLD_TRAIL_FADE) or 10)

-- Shared settle bookkeeping for multi-particle gold reward bursts.
local gold_reward_groups = {}
-- Opening orbit batches: wait until all slots HOLDING, then shared hover, then fly.
local orbit_batches = {}

local function bezier(p0, p1, p2, t)
	local u = 1 - t
	return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t)
end

local function set_layer_color(sprite, layer_id, rgb, alpha)
	if not sprite or not sprite.GetLayer then
		return
	end
	local ok, layer = pcall(function()
		return sprite:GetLayer(layer_id) or sprite:GetLayer(layer_id == "outline" and 1 or 0)
	end)
	if not ok or not layer then
		return
	end
	local r = (rgb and rgb[1]) or 1
	local g = (rgb and rgb[2]) or 1
	local b = (rgb and rgb[3]) or 1
	local a = alpha or 1
	if layer.SetVisible then
		layer:SetVisible(a > 0.01)
	end
	if layer.SetColor then
		layer:SetColor(Color(r, g, b, a, 0, 0, 0))
	end
end

local function tint_command_sprite(sprite, gold)
	local pal = defs.COMMAND_PARTICLE_TINT or {}
	local pack = gold and pal.gold or pal.normal
	if not pack then
		return
	end
	set_layer_color(sprite, "body", pack.body, 1)
	set_layer_color(sprite, "outline", pack.outline, 1)
	-- Keep root tint neutral so layer colors win on the white mask atlas.
	sprite.Color = Color(1, 1, 1, 1, 0, 0, 0)
end

local function ensure_command_sprite(gold)
	local s = Sprite()
	s:Load(COMMAND_ANM2, true)
	s:Play("Idle", true)
	local sc = COMMAND_DISPLAY_SCALE
	s.Scale = Vector(sc, sc)
	tint_command_sprite(s, gold == true)
	return s
end

local function ensure_orb_sprite()
	local s = Sprite()
	s:Load(ORB_ANM2, true)
	if s:GetAnimation() ~= ORB_ANIM then
		s:Play(ORB_ANIM, true)
	end
	local sc = ORB_DISPLAY_SCALE
	s.Scale = Vector(sc, sc)
	-- Bright pale-gold core + warm rim via offset.
	s.Color = Color(1.0, 0.92, 0.55, 0.95, 0.35, 0.22, 0.05)
	return s
end

local function resolve_timing(opts)
	local preset_name = opts.preset or "default"
	local base = PRESETS[preset_name] or PRESETS.default
	return {
		rise = math.max(0, math.floor(tonumber(opts.rise) or base.rise or 8)),
		scatter = math.max(0, math.floor(tonumber(opts.scatter) or base.scatter or 0)),
		hold = math.max(0, math.floor(tonumber(opts.hold) or base.hold or 6)),
		fly = math.max(1, math.floor(tonumber(opts.fly) or opts.duration or base.fly or 20)),
		enter = math.max(1, math.floor(tonumber(opts.enter) or base.enter or 4)),
	}
end

local function rebuild_control(rec)
	local start = rec.origin
	local finish = rec.finish
	local mid = (start + finish) * 0.5
	local bias = rec.control_bias or 0
	local side = Vector(-(finish.Y - start.Y), finish.X - start.X)
	if side:Length() > 0.1 then
		side = side:Normalized() * (40 + bias * 18)
	else
		side = Vector(30 + bias * 12, -50)
	end
	rec.control = mid + side + Vector(0, -35)
end

local function orbit_cfg()
	return defs.P1_OPENING_ORBIT or {}
end

local function compute_orbit_hold(center, angle_deg, radius)
	if not center then
		return nil
	end
	local rad = math.rad(tonumber(angle_deg) or 270)
	local r = math.max(1, tonumber(radius) or 32)
	-- Isaac Y-down: cos/sin of 210/270/330 → left-up / up / right-up.
	return Vector(
		center.X + r * math.cos(rad),
		center.Y + r * math.sin(rad)
	)
end

local function ensure_orbit_batch(batch_id, expected)
	if not batch_id then
		return nil
	end
	local batch = orbit_batches[batch_id]
	if not batch then
		batch = {
			id = batch_id,
			expected = math.max(1, tonumber(expected) or 1),
			ready_frame = nil,
		}
		orbit_batches[batch_id] = batch
	elseif expected and expected > (batch.expected or 0) then
		batch.expected = expected
	end
	return batch
end

--- True when every live orbit member is HOLDING (or already past hold).
local function orbit_batch_all_holding(batch_id)
	if not batch_id then
		return true
	end
	local seen = 0
	for i = 1, #active do
		local p = active[i]
		if p and p.orbit_batch_id == batch_id and not p.cancelled then
			seen = seen + 1
			if p.phase == PHASE.RISING then
				return false
			end
			if p.phase ~= PHASE.HOLDING
				and p.phase ~= PHASE.FLYING
				and p.phase ~= PHASE.ENTERING
				and p.phase ~= PHASE.TRAIL_FADE then
				return false
			end
		end
	end
	local batch = orbit_batches[batch_id]
	local need = batch and batch.expected or seen
	return seen >= need and seen > 0
end

local function orbit_batch_can_fly(batch_id, frame)
	if not batch_id then
		return true
	end
	local batch = orbit_batches[batch_id]
	if not batch then
		return true
	end
	if not orbit_batch_all_holding(batch_id) then
		batch.ready_frame = nil
		return false
	end
	if not batch.ready_frame then
		batch.ready_frame = frame
	end
	local shared = math.max(1, tonumber(orbit_cfg().shared_hold) or 9)
	return (frame - batch.ready_frame) >= shared
end


local function gold_trail_preset_copy()
	local src = GOLD_TRAIL
	return {
		min_radius = src.min_radius,
		max_radius = src.max_radius,
		scale = src.scale,
		local_offset = src.local_offset,
		color = src.color,
		colorize = src.colorize,
		reapply_color_each_sync = true,
	}
end

local function teardown_gold_visual(rec, immediate)
	if not rec then
		return
	end
	if rec.trail_store then
		Trails.clear(rec.trail_store, "trail")
	end
	local carrier = rec.carrier
	rec.carrier = nil
	rec.trail_store = nil
	rec.trail_preset = nil
	if carrier and auxi.check_all_exists(carrier) then
		if immediate then
			carrier:Remove()
		else
			local d = carrier:GetData()
			d.removecd = 1
		end
	end
end

local function ensure_gold_carrier(rec)
	if not rec or not rec.pos then
		return nil
	end
	local carrier = rec.carrier
	if auxi.check_all_exists(carrier) then
		return carrier
	end
	carrier = auxi.fire_nil(rec.pos, Vector.Zero, { cooldown = 9999 })
	if not carrier then
		return nil
	end
	carrier.Velocity = Vector.Zero
	carrier.PositionOffset = Vector.Zero
	carrier.DepthOffset = 30
	carrier.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	if carrier.ClearEntityFlags then
		carrier:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
	end
	-- Invisible carrier: command sprite still renders; MeusNil only hosts SpriteTrail.
	local s = carrier:GetSprite()
	if s then
		s.Color = Color(1, 1, 1, 0, 0, 0, 0)
	end
	rec.carrier = carrier
	rec.trail_store = rec.trail_store or {}
	rec.trail_preset = rec.trail_preset or gold_trail_preset_copy()
	return carrier
end

local function sync_gold_carrier(rec, opts)
	opts = opts or {}
	local carrier = ensure_gold_carrier(rec)
	if not carrier then
		return
	end
	carrier.Position = Vector(rec.pos.X, rec.pos.Y)
	carrier.Velocity = Vector.Zero
	carrier.PositionOffset = Vector.Zero
	local d = carrier:GetData()
	d.removecd = 9999
	local spr = carrier:GetSprite()
	if spr then
		if opts.hide then
			spr.Color = Color(1, 1, 1, 0, 0, 0, 0)
		else
			spr.Color = Color(1, 1, 1, 0, 0, 0, 0)
		end
	end
	local preset = rec.trail_preset or gold_trail_preset_copy()
	rec.trail_preset = preset
	if opts.fade_t then
		local t = math.max(0, math.min(1, opts.fade_t))
		local keep = 1 - t
		preset.min_radius = (GOLD_TRAIL.min_radius or 0.12) * keep
		preset.max_radius = (GOLD_TRAIL.max_radius or 0.08) * keep
		preset.scale = (GOLD_TRAIL.scale or 0.45) * keep
		local cz = GOLD_TRAIL.colorize or {}
		preset.colorize = {
			r = cz.r or 1,
			g = cz.g or 0.82,
			b = cz.b or 0.28,
			a = (cz.a or 1) * keep,
		}
	end
	local trail = Trails.sync(carrier, rec.trail_store, "trail", preset)
	if trail then
		trail.PositionOffset = Vector.Zero
		trail.Velocity = Vector.Zero
	end
end

local function resolve_gold_shard(group_id, arrived)
	local g = gold_reward_groups[group_id]
	if not g or g.settled or g.voided then
		return
	end
	g.left = (g.left or 1) - 1
	if arrived then
		g.arrived = (g.arrived or 0) + 1
	end
	if g.left > 0 then
		return
	end
	if (g.arrived or 0) > 0 then
		g.settled = true
		gold_reward_groups[group_id] = nil
		if g.on_settle then
			pcall(g.on_settle, g.command_id)
		end
	else
		g.voided = true
		gold_reward_groups[group_id] = nil
	end
end

local function mark_gold_resolved(rec, arrived)
	if not rec or not rec.reward_group or rec._gold_resolved then
		return
	end
	rec._gold_resolved = true
	resolve_gold_shard(rec.reward_group, arrived == true)
end

local function release_particle(rec, arrived)
	if rec.gold then
		mark_gold_resolved(rec, arrived)
		teardown_gold_visual(rec, true)
	end
end

--- Launch one particle.
-- opts: start, finish, preset|rise/hold/fly/enter, command_id, on_arrive,
--       control_bias, finish_follow (EntityRef or getter), token,
--       orbit_center/orbit_angle/orbit_radius/orbit_batch_id (opening batch only)
function particles.launch(opts)
	opts = opts or {}
	if not opts.start or not opts.finish then
		return nil, "bad_ends"
	end
	serial = serial + 1
	local timing = resolve_timing(opts)
	local start = Vector(opts.start.X, opts.start.Y)
	local finish = Vector(opts.finish.X, opts.finish.Y)
	local rec = {
		id = serial,
		token = opts.token,
		session_id = opts.session_id,
		command_id = opts.command_id,
		preset = opts.preset,
		origin = start,
		finish = finish,
		control_bias = tonumber(opts.control_bias) or 0,
		timing = timing,
		phase = PHASE.RISING,
		phase_elapsed = 0,
		elapsed = 0,
		arrived = false,
		arrive_fired = false,
		cancelled = false,
		on_arrive = opts.on_arrive,
		-- Optional: return false from validate to drop without on_arrive.
		validate = opts.validate,
		finish_follow = opts.finish_follow,
		scale = 0.85,
		pos = start,
		hold_pulse = 0,
		gold = opts.gold == true or opts.preset == "gold_reward",
		reward_orb = opts.preset == "gold_reward",
		scatter_offset = opts.scatter_offset,
		reward_group = opts.reward_group,
	}
	-- Opening multi-command orbit: freeze hold slot at launch (not live Boss follow).
	if opts.orbit_center and opts.orbit_radius then
		local center = Vector(opts.orbit_center.X, opts.orbit_center.Y)
		rec.orbit_center = center
		rec.orbit_angle = tonumber(opts.orbit_angle) or 270
		rec.orbit_radius = tonumber(opts.orbit_radius) or 32
		rec.orbit_hold = compute_orbit_hold(center, rec.orbit_angle, rec.orbit_radius)
		rec.orbit_batch_id = opts.orbit_batch_id
		rec.orbit_index = opts.orbit_index
		rec.orbit_count = opts.orbit_count
		if rec.orbit_batch_id then
			ensure_orbit_batch(rec.orbit_batch_id, rec.orbit_count)
		end
	end
	if rec.reward_orb then
		rec.sprite = ensure_orb_sprite()
	else
		rec.sprite = ensure_command_sprite(rec.gold)
	end
	if rec.scatter_offset then
		-- Real scatter: birth at death position, ease out to scatter end.
		rec.scatter_start = Vector(start.X, start.Y)
		rec.pos = Vector(start.X, start.Y)
		rec.origin = Vector(start.X, start.Y)
		local scatter_frames = timing.scatter
		if scatter_frames < 1 then
			scatter_frames = 10
			timing.scatter = scatter_frames
		end
		rec.phase = PHASE.SCATTERING
		rec.phase_elapsed = 0
	end
	rebuild_control(rec)
	if rec.gold then
		sync_gold_carrier(rec)
	end
	active[#active + 1] = rec
	return rec.id, rec
end


--- Scatter then fly to Boss; settle callback fires once when the group resolves.
-- opts: start, finish|finish_follow, count, command_id, session_id, on_settle, validate
function particles.launch_gold_reward(opts)
	opts = opts or {}
	if not opts.start then
		return nil, "bad_start"
	end
	serial = serial + 1
	local group_id = serial
	local count = math.max(1, math.floor(tonumber(opts.count) or defs.P1_GOLD_REWARD_COUNT or 7))
	gold_reward_groups[group_id] = {
		left = count,
		arrived = 0,
		settled = false,
		voided = false,
		on_settle = opts.on_settle,
		command_id = opts.command_id,
	}
	local start = Vector(opts.start.X, opts.start.Y)
	local finish = opts.finish or start
	local ids = {}
	for i = 1, count do
		local ang = (i - 1) * (360 / count) + (i * 17) % 40
		local rad = ang * math.pi / 180
		local dist = 18 + (i % 3) * 6
		local scatter = Vector(math.cos(rad) * dist, math.sin(rad) * dist - 8)
		local pid = particles.launch({
			start = start,
			finish = finish,
			finish_follow = opts.finish_follow,
			preset = "gold_reward",
			gold = true,
			scatter_offset = scatter,
			command_id = opts.command_id,
			session_id = opts.session_id,
			control_bias = (i - (count + 1) * 0.5) * 0.35,
			validate = opts.validate,
			reward_group = group_id,
		})
		ids[#ids + 1] = pid
	end
	return group_id, ids
end

--- Returns finish Vector, or nil when follow target is gone (caller should cancel).
local function resolve_finish(p)
	local follow = p.finish_follow
	if not follow then
		return p.finish
	end
	if type(follow) == "function" then
		local ok, pos = pcall(follow)
		if ok and pos and pos.X then
			return Vector(pos.X, pos.Y)
		end
		-- Explicit nil from follower = target lost.
		if ok and pos == nil then
			return nil
		end
		return p.finish
	end
	-- EntityRef — head tracks Position + PositionOffset (offset.Y negative when lifted).
	local ent = follow.Entity
	if ent and ent.Exists and ent:Exists() and not (ent.IsDead and ent:IsDead()) then
		local oy = (ent.PositionOffset and ent.PositionOffset.Y) or 0
		return Vector(ent.Position.X, ent.Position.Y - 18 + oy)
	end
	return nil
end

local function advance_phase(p, next_phase)
	p.phase = next_phase
	p.phase_elapsed = 0
end

--- Advance all particles. Idempotent within the same Game():GetFrameCount().
function particles.tick()
	local frame = Game():GetFrameCount()
	if frame == last_tick_frame then
		return
	end
	last_tick_frame = frame

	local keep = {}
	for i = 1, #active do
		local p = active[i]
		local alive = true

		if p.cancelled then
			alive = false
			release_particle(p, false)
		else
			if p.validate then
				local ok_v, valid = pcall(p.validate, p)
				if not ok_v or valid == false then
					p.cancelled = true
					alive = false
					release_particle(p, false)
				end
			end
		end

		if alive then
			p.elapsed = (p.elapsed or 0) + 1
			p.phase_elapsed = (p.phase_elapsed or 0) + 1
			local tmg = p.timing

			if p.phase == PHASE.SCATTERING then
				local scatter_n = math.max(1, tmg.scatter or 10)
				local t = math.min(1, p.phase_elapsed / scatter_n)
				local te = t * t * (3 - 2 * t)
				local origin = p.scatter_start or p.origin
				local off = p.scatter_offset or Vector.Zero
				p.pos = origin + off * te
				p.scale = 0.85 + 0.2 * t
				if p.phase_elapsed >= scatter_n then
					p.origin = origin + off
					p.pos = Vector(p.origin.X, p.origin.Y)
					advance_phase(p, PHASE.HOLDING)
				end
			elseif p.phase == PHASE.RISING then
				local rise_n = math.max(1, tmg.rise)
				local t = math.min(1, p.phase_elapsed / rise_n)
				local te = t * t * (3 - 2 * t)
				p.scale = 0.85 + 0.2 * t
				if p.orbit_hold then
					-- Short arc tip → personal orbit slot (no teleport).
					local hold = p.orbit_hold
					local mid = (p.origin + hold) * 0.5
					local chord = hold - p.origin
					local side = Vector(-chord.Y, chord.X)
					local clen = chord:Length()
					if side:Length() > 0.1 and clen > 0.1 then
						side = side:Normalized() * (clen * 0.28)
					else
						side = Vector(0, -10)
					end
					p.pos = bezier(p.origin, mid + side, hold, te)
				else
					local rise = 10 * t
					p.pos = Vector(p.origin.X, p.origin.Y - rise)
				end
				if p.phase_elapsed >= rise_n then
					if p.orbit_hold then
						p.pos = Vector(p.orbit_hold.X, p.orbit_hold.Y)
					end
					advance_phase(p, PHASE.HOLDING)
				end
			elseif p.phase == PHASE.HOLDING then
				p.hold_pulse = (p.hold_pulse or 0) + 1
				local pulse = 0.5 + 0.5 * math.sin(p.hold_pulse * 0.55)
				local hover = (p.preset == "return") and 4 or 10
				local pulse_amp = (p.preset == "return") and 0.22 or 0.12
				if p.gold then
					hover = 6
					pulse_amp = 0.10
				end
				if p.orbit_hold then
					-- Stay on frozen orbit slot; light vertical bob only.
					local bob = 1.2 * math.sin(p.hold_pulse * 0.45)
					p.pos = Vector(p.orbit_hold.X, p.orbit_hold.Y + bob)
					pulse_amp = 0.08
				else
					p.pos = Vector(p.origin.X, p.origin.Y - hover)
				end
				p.scale = 1.05 + pulse_amp * pulse
				local can_fly = false
				if p.orbit_batch_id then
					-- Opening batch: all slots expand, shared hover, then fly together.
					can_fly = orbit_batch_can_fly(p.orbit_batch_id, frame)
				else
					can_fly = p.phase_elapsed >= tmg.hold
				end
				if can_fly then
					-- Lock flight start from current hover; refresh finish/control.
					p.fly_start = Vector(p.pos.X, p.pos.Y)
					local fin = resolve_finish(p)
					if not fin then
						alive = false
						release_particle(p, false)
					else
						p.finish = fin
						p.origin = p.fly_start
						rebuild_control(p)
						advance_phase(p, PHASE.FLYING)
					end
				end
			elseif p.phase == PHASE.FLYING then
				-- Follow moving target during flight (same piece identity).
				local fin = resolve_finish(p)
				if not fin then
					alive = false
					release_particle(p, false)
				else
					p.finish = fin
					rebuild_control(p)
					local t = math.min(1, p.phase_elapsed / math.max(1, tmg.fly))
					-- Ease-in-out toward target for readable arc.
					local te = t * t * (3 - 2 * t)
					p.pos = bezier(p.fly_start or p.origin, p.control, p.finish, te)
					p.scale = 1.05 - 0.2 * t
					if t >= 1 then
						p.pos = Vector(p.finish.X, p.finish.Y)
						advance_phase(p, PHASE.ENTERING)
					end
				end
			elseif p.phase == PHASE.ENTERING then
				local fin = resolve_finish(p)
				if not fin then
					alive = false
					release_particle(p, false)
				else
					local t = math.min(1, p.phase_elapsed / math.max(1, tmg.enter))
					p.finish = fin
					p.pos = Vector(p.finish.X, p.finish.Y)
					p.scale = 0.85 * (1 - t) + 0.05
					if t >= 1 then
						-- Final validate before settle callback.
						if p.validate then
							local ok_v, valid = pcall(p.validate, p)
							if not ok_v or valid == false then
								alive = false
								release_particle(p, false)
							end
						end
						if alive then
							p.arrived = true
							if not p.arrive_fired then
								p.arrive_fired = true
								mark_gold_resolved(p, true)
								if p.on_arrive then
									pcall(p.on_arrive, p)
								end
							end
							if p.gold then
								-- Visual trail fade only; reward already resolved.
								p.pos = Vector(p.finish.X, p.finish.Y)
								advance_phase(p, PHASE.TRAIL_FADE)
								p.hide_sprite = true
							else
								alive = false
							end
						end
					end
				end
			elseif p.phase == PHASE.TRAIL_FADE then
				local fin = p.finish or p.pos
				p.pos = Vector(fin.X, fin.Y)
				p.hide_sprite = true
				local fade_t = math.min(1, p.phase_elapsed / GOLD_TRAIL_FADE)
				sync_gold_carrier(p, { hide = true, fade_t = fade_t })
				if p.phase_elapsed >= GOLD_TRAIL_FADE then
					teardown_gold_visual(p, true)
					alive = false
				end
			else
				alive = false
				release_particle(p, false)
			end

			if alive and p.gold and p.phase ~= PHASE.TRAIL_FADE then
				sync_gold_carrier(p, { hide = p.hide_sprite == true })
			end
		end

		if alive then
			keep[#keep + 1] = p
		end
	end
	active = keep
end

function particles.cancel_by_token(token)
	if token == nil then
		return 0
	end
	local n = 0
	for i = 1, #active do
		if active[i].token == token then
			active[i].cancelled = true
			n = n + 1
		end
	end
	return n
end

function particles.cancel_by_session(session_id)
	if session_id == nil then
		return 0
	end
	local n = 0
	for i = 1, #active do
		if active[i].session_id == session_id then
			active[i].cancelled = true
			n = n + 1
		end
	end
	return n
end

function particles.render()
	for i = 1, #active do
		local p = active[i]
		if p.hide_sprite then
			-- Gold trail-fade: carrier hosts shrinking trail only.
		elseif p.sprite and p.pos then
			local base_sc = p.reward_orb and ORB_DISPLAY_SCALE or COMMAND_DISPLAY_SCALE
			local sc = base_sc * (p.scale or 1)
			p.sprite.Scale = Vector(sc, sc)
			if p.reward_orb then
				local pulse = math.min(1, 0.75 + 0.25 * (p.scale or 1))
				p.sprite.Color = Color(1.0, 0.92, 0.55, pulse, 0.35, 0.22, 0.05)
			else
				tint_command_sprite(p.sprite, p.gold == true)
			end
			p.sprite:Render(Isaac.WorldToScreen(p.pos), Vector.Zero, Vector.Zero)
		end
	end
end

--- Shrink/fix opening orbit expected count after stagger spawn finishes.
function particles.set_orbit_batch_expected(batch_id, n)
	if not batch_id then
		return
	end
	local batch = ensure_orbit_batch(batch_id, n)
	if batch then
		batch.expected = math.max(1, tonumber(n) or 1)
	end
end

function particles.clear()
	-- Force-clear voids unpaid groups (phase leave / arena exit); never settle here.
	for i = 1, #active do
		teardown_gold_visual(active[i], true)
	end
	active = {}
	for _, g in pairs(gold_reward_groups) do
		g.voided = true
	end
	gold_reward_groups = {}
	orbit_batches = {}
end


function particles.count()
	return #active
end

--- Unsettled gold reward bursts still in flight (blocks soft P1→P2 wrap).
function particles.get_pending_gold_reward_count()
	local n = 0
	for _, g in pairs(gold_reward_groups) do
		if g and not g.settled and not g.voided then
			n = n + 1
		end
	end
	return n
end

function particles.diag()
	local list = {}
	for i = 1, #active do
		local p = active[i]
		list[#list + 1] = {
			id = p.id,
			command_id = p.command_id,
			preset = p.preset,
			phase = p.phase,
			elapsed = p.elapsed,
			phase_elapsed = p.phase_elapsed,
			arrived = p.arrived == true,
			gold = p.gold == true,
			orbit_batch_id = p.orbit_batch_id,
			orbit_index = p.orbit_index,
			orbit_angle = p.orbit_angle,
		}
	end
	local pending_groups = 0
	for _, g in pairs(gold_reward_groups) do
		if g and not g.settled and not g.voided then
			pending_groups = pending_groups + 1
		end
	end
	return {
		count = #active,
		list = list,
		presets = PRESETS,
		pending_gold_rewards = pending_groups,
	}
end

particles.PHASE = PHASE
particles.PRESETS = PRESETS

return particles
