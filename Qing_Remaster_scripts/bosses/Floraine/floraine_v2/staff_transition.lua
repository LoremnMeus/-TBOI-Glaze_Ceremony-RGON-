-- Floraine P1→P2 staff handoff: temporary detached staff Sprite.
-- Proxy whitelist: StaffBack / StaffFront only (no Body, CastingFX, or outline layers).

local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")
local visual = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.visual")

local staff = {}

local PHASE = {
	ATTACHED = "ATTACHED",
	DETACHING = "DETACHING",
	FALLING = "FALLING",
	LANDED = "LANDED",
	LEVITATING = "LEVITATING",
	RETURNING = "RETURNING",
	REATTACHING = "REATTACHING",
}

-- Whitelist: Staff* only. Body / CastingFX (and any unknown layer) stay hidden.
local PROXY_SHOW = {
	StaffBack = true,
	StaffFront = true,
	StaffOutlineBack = true,
	StaffOutlineFront = true,
}

local PROXY_HIDE = {
	"Body",
	"CastingFX",
}

local state = {
	phase = PHASE.ATTACHED,
	elapsed = 0,
	session_id = 0,
	position = nil,
	rotation = 0,
	scale = 1,
	alpha = 1,
	height = 0,
	land_pos = nil,
	start_pos = nil,
	sprite = nil,
	active = false,
}

local function apply_proxy_layers(s)
	if not s or not s.GetLayer then
		return
	end
	for name in pairs(PROXY_SHOW) do
		local ok, layer = pcall(function()
			return s:GetLayer(name)
		end)
		if ok and layer then
			if layer.SetVisible then layer:SetVisible(true) end
			if layer.SetColor then layer:SetColor(Color(1, 1, 1, 1, 0, 0, 0)) end
		end
	end
	for _, name in ipairs(PROXY_HIDE) do
		local ok, layer = pcall(function()
			return s:GetLayer(name)
		end)
		if ok and layer then
			if layer.SetVisible then layer:SetVisible(false) end
			if layer.SetColor then layer:SetColor(Color(1, 1, 1, 0, 0, 0, 0)) end
		end
	end
end

local function ensure_sprite()
	if state.sprite then
		apply_proxy_layers(state.sprite)
		return state.sprite
	end
	local s = Sprite()
	s:Load(defs.ANM2 or "gfx/boss/Floraine/Floraine.anm2", true)
	s:Play("Idle2", true)
	apply_proxy_layers(s)
	state.sprite = s
	return s
end

local function bezier(p0, p1, p2, t)
	local u = 1 - t
	return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t)
end

local function grip_world(boss_ent)
	if visual.staff_tip_world then
		local tip = visual.staff_tip_world(boss_ent)
		if tip and boss_ent then
			return Vector(tip.X, tip.Y + 28)
		end
	end
	if boss_ent then
		return boss_ent.Position + Vector(-14, -55)
	end
	return Vector.Zero
end

local function restore_boss_staff(boss_ent)
	if visual.set_staff_detached then
		visual.set_staff_detached(boss_ent, false)
	end
	if boss_ent and visual.idle2 then
		visual.idle2(boss_ent)
	end
	if boss_ent and visual.tick_staff_outline then
		visual.tick_staff_outline(boss_ent)
	end
end

function staff.is_detached()
	return state.active and state.phase ~= PHASE.ATTACHED
end

function staff.get_phase()
	return state.phase
end

function staff.begin(boss_ent, session_id)
	state.session_id = session_id or (state.session_id + 1)
	state.active = true
	state.elapsed = 0
	state.phase = PHASE.DETACHING
	state.scale = 1
	state.alpha = 1
	state.height = 0
	state.rotation = -18
	state.start_pos = grip_world(boss_ent)
	state.position = Vector(state.start_pos.X, state.start_pos.Y)
	local forward = 40
	if boss_ent then
		state.land_pos = Vector(boss_ent.Position.X + forward * 0.15, boss_ent.Position.Y + 48)
	else
		state.land_pos = state.start_pos + Vector(8, 50)
	end
	ensure_sprite()
	-- Proxy ↔ body staff mutual exclusion.
	if visual.set_staff_detached then
		visual.set_staff_detached(boss_ent, true)
	end
	return true
end

function staff.clear(boss_ent)
	restore_boss_staff(boss_ent)
	state.active = false
	state.phase = PHASE.ATTACHED
	state.sprite = nil
	state.position = nil
end

function staff.tick(boss_ent)
	if not state.active then
		return false
	end
	state.elapsed = state.elapsed + 1
	local cfg = defs.STAFF_TRANSITION or {}
	local e = state.elapsed

	if state.phase == PHASE.DETACHING then
		local n = cfg.DETACH or 8
		local t = math.min(1, e / math.max(1, n))
		state.rotation = -18 - 25 * t
		state.scale = 1 - 0.04 * t
		state.height = 6 * t
		state.position = state.start_pos + Vector(6 * t, 4 * t)
		if e >= n then
			state.phase = PHASE.FALLING
			state.elapsed = 0
			state.start_pos = Vector(state.position.X, state.position.Y)
		end
	elseif state.phase == PHASE.FALLING then
		local n = (cfg.FALL or 14) + (cfg.BOUNCE or 10)
		local t = math.min(1, e / math.max(1, n))
		local ease = t * t
		state.position = state.start_pos * (1 - ease) + state.land_pos * ease
		state.rotation = -45 + 120 * t
		state.scale = (cfg.FALL_SCALE or 0.88) + 0.07 * t
		state.height = 8 * (1 - t)
		if e >= n then
			state.phase = PHASE.LANDED
			state.elapsed = 0
			state.position = Vector(state.land_pos.X, state.land_pos.Y)
			state.scale = cfg.LAND_SCALE or 0.95
			state.height = 0
			state.rotation = 92
			if boss_ent then
				Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BLOOD_EXPLOSION, 0,
					state.position, Vector.Zero, boss_ent)
			end
		end
	elseif state.phase == PHASE.LANDED then
		local n = cfg.GROUND or 16
		state.rotation = 92 + math.sin(e * 0.45) * 2.5
		if e >= n then
			state.phase = PHASE.LEVITATING
			state.elapsed = 0
		end
	elseif state.phase == PHASE.LEVITATING then
		local n = cfg.LEVITATE or 12
		local t = math.min(1, e / math.max(1, n))
		state.height = 18 * t
		state.rotation = 92 - 40 * t
		state.alpha = 0.85 + 0.15 * math.sin(e * 0.8)
		if e >= n then
			state.phase = PHASE.RETURNING
			state.elapsed = 0
			state.start_pos = Vector(state.position.X, state.position.Y - state.height)
		end
	elseif state.phase == PHASE.RETURNING then
		local n = cfg.RETURN or 20
		local t = math.min(1, e / math.max(1, n))
		local te = t * t * (3 - 2 * t)
		local grip = grip_world(boss_ent)
		local ctrl = Vector(
			(state.start_pos.X + grip.X) * 0.5,
			math.min(state.start_pos.Y, grip.Y) - 50
		)
		state.position = bezier(state.start_pos, ctrl, grip, te)
		state.height = 0
		state.rotation = 50 * (1 - te) - 10 * te
		state.scale = (cfg.LAND_SCALE or 0.95) + (1 - (cfg.LAND_SCALE or 0.95)) * te
		state.alpha = 1
		if e >= n then
			state.phase = PHASE.REATTACHING
			state.elapsed = 0
			state.position = grip
		end
	elseif state.phase == PHASE.REATTACHING then
		local n = cfg.REATTACH or 12
		state.position = grip_world(boss_ent)
		state.rotation = state.rotation * 0.7
		state.scale = 1
		if e >= n then
			restore_boss_staff(boss_ent)
			state.phase = PHASE.ATTACHED
			state.active = false
			state.sprite = nil
			return true
		end
	end
	return false
end

function staff.render()
	if not state.active or not state.position or state.phase == PHASE.ATTACHED then
		return
	end
	local s = ensure_sprite()
	if not s then
		return
	end
	apply_proxy_layers(s)
	s.Color = Color(1, 1, 1, state.alpha or 1, 0.08, 0.01, 0.01)
	s.Scale = Vector(state.scale or 1, state.scale or 1)
	s.Rotation = state.rotation or 0
	local draw = Vector(state.position.X, state.position.Y - (state.height or 0))
	s:Render(Isaac.WorldToScreen(draw), Vector.Zero, Vector.Zero)
end

function staff.diag()
	return {
		active = state.active,
		phase = state.phase,
		elapsed = state.elapsed,
		session_id = state.session_id,
		proxy_layers = "Staff*",
	}
end

staff.PHASE = PHASE

return staff
