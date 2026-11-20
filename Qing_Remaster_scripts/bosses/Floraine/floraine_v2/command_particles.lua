-- Red command-soul particles (pure VFX). Staff launch / death inheritance / royal drop.
-- Motion: RISING → HOLDING → FLYING → ENTERING → finished.
-- Logic tick advances; Render only draws. No MeusNil.

local piece_defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")
local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")

local particles = {}

local PHASE = {
	RISING = "RISING",
	HOLDING = "HOLDING",
	FLYING = "FLYING",
	ENTERING = "ENTERING",
}

local active = {}
local serial = 0
local last_tick_frame = -1

local PRESETS = {
	opening = defs.PARTICLE_OPENING or { rise = 8, hold = 8, fly = 24, enter = 5 },
	inherit = defs.PARTICLE_INHERIT or { rise = 12, hold = 10, fly = 26, enter = 5 },
	royal = defs.PARTICLE_ROYAL or { rise = 10, hold = 8, fly = 22, enter = 5 },
	["return"] = defs.PARTICLE_RETURN or { rise = 0, hold = 10, fly = 22, enter = 4 },
	default = { rise = 8, hold = 6, fly = 20, enter = 4 },
}

local function bezier(p0, p1, p2, t)
	local u = 1 - t
	return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t)
end

local function ensure_sprite()
	local s = Sprite()
	s:Load(piece_defs.ANM2 or "gfx/boss/Floraine/pieces.anm2", true)
	s:Play("Idle", true)
	s.Scale = Vector(0.22, 0.22)
	return s
end

local function resolve_timing(opts)
	local preset_name = opts.preset or "default"
	local base = PRESETS[preset_name] or PRESETS.default
	return {
		rise = math.max(0, math.floor(tonumber(opts.rise) or base.rise or 8)),
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

--- Launch one particle.
-- opts: start, finish, preset|rise/hold/fly/enter, command_id, on_arrive,
--       control_bias, finish_follow (EntityRef or getter), token
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
		sprite = ensure_sprite(),
		scale = 0.85,
		pos = start,
		hold_pulse = 0,
	}
	rebuild_control(rec)
	active[#active + 1] = rec
	return rec.id, rec
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
		if p.cancelled then
			-- drop
		else
		if p.validate then
			local ok_v, valid = pcall(p.validate, p)
			if not ok_v or valid == false then
				p.cancelled = true
			end
		end
		if p.cancelled then
			-- drop without on_arrive
		else
		p.elapsed = (p.elapsed or 0) + 1
		p.phase_elapsed = (p.phase_elapsed or 0) + 1
		local tmg = p.timing
		local alive = true

		if p.phase == PHASE.RISING then
			local t = math.min(1, p.phase_elapsed / math.max(1, tmg.rise))
			local rise = 10 * t
			p.pos = Vector(p.origin.X, p.origin.Y - rise)
			p.scale = 0.85 + 0.2 * t
			if p.phase_elapsed >= tmg.rise then
				advance_phase(p, PHASE.HOLDING)
			end
		elseif p.phase == PHASE.HOLDING then
			p.hold_pulse = (p.hold_pulse or 0) + 1
			local pulse = 0.5 + 0.5 * math.sin(p.hold_pulse * 0.55)
			local hover = (p.preset == "return") and 4 or 10
			local pulse_amp = (p.preset == "return") and 0.22 or 0.12
			p.pos = Vector(p.origin.X, p.origin.Y - hover)
			p.scale = 1.05 + pulse_amp * pulse
			if p.phase_elapsed >= tmg.hold then
				-- Lock flight start from current hover; refresh finish/control.
				p.fly_start = Vector(p.pos.X, p.pos.Y)
				local fin = resolve_finish(p)
				if not fin then
					alive = false
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
						end
					end
					if alive then
						p.arrived = true
						if not p.arrive_fired then
							p.arrive_fired = true
							if p.on_arrive then
								pcall(p.on_arrive, p)
							end
						end
						alive = false
					end
				end
			end
		else
			alive = false
		end

		if alive then
			keep[#keep + 1] = p
		end
		end -- not cancelled after validate
		end -- not cancelled at start
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
		if p.sprite and p.pos then
			local sc = p.scale or 1
			p.sprite.Scale = Vector(0.22 * sc, 0.22 * sc)
			p.sprite.Color = Color(1, 0.18, 0.22, math.min(1, 0.55 + 0.45 * sc), 0.35, 0.05, 0.05)
			p.sprite:Render(Isaac.WorldToScreen(p.pos), Vector.Zero, Vector.Zero)
		end
	end
end

function particles.clear()
	active = {}
end

function particles.count()
	return #active
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
		}
	end
	return { count = #active, list = list, presets = PRESETS }
end

particles.PHASE = PHASE
particles.PRESETS = PRESETS

return particles
