-- Floraine V2 visuals. Timers drive combat; sprite plays are cosmetic.
-- Formal clips: Idle / Idle2 / Raise / Cast / Settle / Lower / RaiseFromIdle2 / Release / Leave.
-- Shared staff trajectory is authored in ANM2; Lua advances the action chain and
-- drives StaffOutline* layer Color alpha (does not touch whole-sprite Color for glow).

local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")

local visual = {}

-- After a one-shot clip finishes, advance to the next clip in the chain.
local CHAIN_NEXT = {
	Raise = "Cast",
	RaiseFromIdle2 = "Cast",
	Cast = "Settle",
	Release = "Settle",
	Settle = "Idle2",
	Lower = "Idle",
}

local LOOP_OR_HOLD = {
	Idle = true,
	Idle2 = true,
	Leave = true,
}

local IN_COMMAND = {
	Raise = true,
	RaiseFromIdle2 = true,
	Cast = true,
	Release = true,
	Settle = true,
}

local OUTLINE_LAYERS = {
	"StaffOutlineBack",
	"StaffOutlineFront",
}

local STAFF_LAYERS = {
	"StaffBack",
	"StaffFront",
	"StaffOutlineBack",
	"StaffOutlineFront",
}

-- When true, ANM2 staff layers stay hidden (detached proxy owns the visual).
local staff_detached = false

--- Soft cyan-green; Idle2 glow can be disabled via idle2_alpha = 0.
visual.STAFF_OUTLINE = {
	color = { 0.55, 0.95, 0.75 },
	idle2_alpha = 0.12,
}

local function sprite(ent)
	return ent and ent:GetSprite()
end

local function current_anim(ent)
	local s = sprite(ent)
	return s and s:GetAnimation() or nil
end

local function anim_frame(s)
	if not s then return 0 end
	if s.GetFrame then
		return s:GetFrame() or 0
	end
	return 0
end

local function anim_len(name)
	if name == "Idle" or name == "Idle2" then return 60 end
	if name == "Raise" then return 18 end
	if name == "Cast" then return 12 end
	if name == "Settle" then return 14 end
	if name == "Lower" then return 16 end
	if name == "RaiseFromIdle2" then return 10 end
	if name == "Release" then return 8 end
	if name == "Leave" then return 30 end
	return 1
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function clamp01(x)
	if x < 0 then return 0 end
	if x > 1 then return 1 end
	return x
end

--- Outline alpha for the current formal clip + frame (ANM2 Visible still owns layer handoff).
function visual.staff_outline_alpha_for(anim, frame)
	local cfg = visual.STAFF_OUTLINE or {}
	local idle2_a = tonumber(cfg.idle2_alpha) or 0
	anim = anim or "Idle"
	frame = math.max(0, tonumber(frame) or 0)
	local n = anim_len(anim)
	local t = (n > 1) and clamp01(frame / (n - 1)) or 0

	if anim == "Idle" or anim == "Leave" then
		return 0
	end
	if anim == "Idle2" then
		return clamp01(idle2_a)
	end
	if anim == "Raise" then
		return lerp(0, 0.65, t)
	end
	if anim == "RaiseFromIdle2" then
		return lerp(clamp01(idle2_a), 0.65, t)
	end
	if anim == "Cast" then
		-- Peak near Call@2, then settle toward 0.45.
		if frame <= 2 then
			return lerp(0.65, 1.0, frame / 2)
		end
		return lerp(1.0, 0.45, clamp01((frame - 2) / math.max(1, n - 3)))
	end
	if anim == "Release" then
		if frame <= 4 then
			return lerp(clamp01(idle2_a), 1.0, frame / 4)
		end
		return lerp(1.0, 0.5, clamp01((frame - 4) / math.max(1, n - 5)))
	end
	if anim == "Settle" then
		return lerp(0.45, clamp01(idle2_a), t)
	end
	if anim == "Lower" then
		return lerp(clamp01(idle2_a), 0, t)
	end
	return 0
end

function visual.set_staff_outline(ent, alpha, color)
	local s = sprite(ent)
	if not s or not s.GetLayer then
		return
	end
	if staff_detached then
		alpha = 0
	end
	alpha = clamp01(alpha or 0)
	local cfg = visual.STAFF_OUTLINE or {}
	local rgb = color or cfg.color or { 1, 1, 1 }
	local r, g, b = rgb[1] or 1, rgb[2] or 1, rgb[3] or 1
	for i = 1, #OUTLINE_LAYERS do
		local ok, layer = pcall(function()
			return s:GetLayer(OUTLINE_LAYERS[i])
		end)
		if ok and layer and layer.SetColor then
			-- Do not SetVisible(true): ANM2 owns back/front handoff.
			layer:SetColor(Color(r, g, b, alpha, 0, 0, 0))
		end
	end
end

--- Hide / restore all ANM2 staff layers for detached proxy handoff.
function visual.set_staff_detached(ent, detached)
	staff_detached = detached == true
	local s = sprite(ent)
	if not s or not s.GetLayer then
		return
	end
	for i = 1, #STAFF_LAYERS do
		local ok, layer = pcall(function()
			return s:GetLayer(STAFF_LAYERS[i])
		end)
		if ok and layer then
			if layer.SetVisible then
				layer:SetVisible(not staff_detached)
			end
			if staff_detached and layer.SetColor then
				layer:SetColor(Color(1, 1, 1, 0, 0, 0, 0))
			end
		end
	end
	if not staff_detached then
		visual.tick_staff_outline(ent)
	end
end

function visual.is_staff_detached()
	return staff_detached == true
end

function visual.tick_staff_outline(ent)
	local s = sprite(ent)
	if not s then return end
	if staff_detached then
		visual.set_staff_detached(ent, true)
		return
	end
	local anim = s:GetAnimation()
	local a = visual.staff_outline_alpha_for(anim, anim_frame(s))
	visual.set_staff_outline(ent, a)
end

function visual.play(ent, anim, force)
	local s = sprite(ent)
	if not s then return end
	if force or s:GetAnimation() ~= anim then
		s:Play(anim, true)
	end
	visual.tick_staff_outline(ent)
end

function visual.idle(ent)
	visual.play(ent, "Idle", false)
end

function visual.idle2(ent)
	visual.play(ent, "Idle2", false)
end

--- Prefer planted command stance during combat; fall back to Idle.
function visual.rest(ent)
	local anim = current_anim(ent)
	if anim == "Idle2" or IN_COMMAND[anim] then
		visual.tick_staff_outline(ent)
		return
	end
	if anim == "Idle" or anim == "Lower" or anim == "Leave" or not anim then
		visual.idle(ent)
		return
	end
	visual.idle2(ent)
end

--- Raise staff / 点将. From Idle2 uses the short RaiseFromIdle2 clip.
function visual.command(ent)
	local anim = current_anim(ent)
	if IN_COMMAND[anim] then
		visual.tick_staff_outline(ent)
		return
	end
	if anim == "Idle2" then
		visual.play(ent, "RaiseFromIdle2", false)
	else
		visual.play(ent, "Raise", false)
	end
end

--- Short battlefield order (from Idle2). Same chain entry as continuous command.
function visual.order(ent)
	visual.command(ent)
end

--- Unified drop signal (opening batch). From Idle2 / Settle → Release → Settle → Idle2.
function visual.release(ent)
	local anim = current_anim(ent)
	if anim == "Release" then
		visual.tick_staff_outline(ent)
		return
	end
	visual.play(ent, "Release", true)
end

--- World position of the raised staff tip (particle spawn). Falls back to approx offset.
function visual.staff_tip_world(ent)
	if not ent then
		return nil
	end
	local s = sprite(ent)
	local base = ent.Position + (ent.PositionOffset or Vector.Zero)
	if s and s.GetLayerFrameData then
		local lid = nil
		if s.GetLayer then
			local ok, layer = pcall(function()
				return s:GetLayer("StaffFront") or s:GetLayer("StaffBack")
			end)
			if ok and layer and layer.GetId then
				lid = layer:GetId()
			elseif ok and layer and layer.GetLayerID then
				lid = layer:GetLayerID()
			end
		end
		-- Layer ids: OutlineBack=0 StaffBack=1 Body=2 CastingFX=3 OutlineFront=4 StaffFront=5
		lid = lid or 5
		local ok, fd = pcall(function()
			return s:GetLayerFrameData(lid)
		end)
		if ok and fd and fd.GetPos then
			local p = fd:GetPos()
			local rot = (fd.GetRotation and fd:GetRotation()) or 0
			local sc = 1
			if fd.GetScale then
				local sv = fd:GetScale()
				sc = (sv and (sv.Y or sv.X)) or 1
				if type(sc) ~= "number" then
					sc = 1
				end
			end
			-- Tip is above staff pivot along staff axis (crop 96 tall, pivot at y=64 → tip -64).
			local tip_len = 64 * sc
			local rad = math.rad(rot)
			-- Staff rot 0 = upright; ANM2 rot is clockwise degrees.
			local ox = p.X - math.sin(rad) * tip_len
			local oy = p.Y - math.cos(rad) * tip_len
			return Vector(base.X + ox, base.Y + oy)
		end
	end
	return Vector(base.X - 16, base.Y - 90)
end

--- Explicitly return staff behind the body (Idle2 → Lower → Idle).
function visual.lower(ent)
	local anim = current_anim(ent)
	if anim == "Lower" or anim == "Idle" or anim == "Leave" then
		visual.tick_staff_outline(ent)
		return
	end
	if IN_COMMAND[anim] then
		return
	end
	visual.play(ent, "Lower", false)
end

--- Brief recoil /失势: flash only (no alternate Idle clip).
function visual.stagger(ent)
	visual.flash(ent, 0.35, 0.1, 0.1, 10)
end

function visual.is_playing(ent, anim)
	local s = sprite(ent)
	if not s then return false end
	if s:GetAnimation() ~= anim then return false end
	if s.IsFinished and s:IsFinished(anim) then
		return false
	end
	return true
end

--- Advance Raise→Cast→Settle→Idle2 (and Lower→Idle). Does not force Idle.
function visual.tick_chain(ent)
	local s = sprite(ent)
	if not s then return end
	local anim = s:GetAnimation()
	if not LOOP_OR_HOLD[anim] then
		if s.IsFinished and s:IsFinished(anim) then
			local next_anim = CHAIN_NEXT[anim]
			if next_anim then
				s:Play(next_anim, true)
			else
				visual.idle2(ent)
			end
		end
	end
	visual.tick_staff_outline(ent)
end

--- Compatibility alias: chain advance, never auto-Idle from Raise/Cast.
function visual.tick_to_idle(ent)
	visual.tick_chain(ent)
end

function visual.flash(ent, r, g, b, frames)
	if not ent then return end
	ent:SetColor(Color(1, 1, 1, 1, r or 0.35, g or 0.2, b or 0.05), frames or 12, 8, true, false)
end

function visual.phase_tint(ent, p)
	if p == 2 then
		visual.flash(ent, 0.15, 0.05, 0.35, 24)
	elseif p == 3 then
		visual.flash(ent, 0.4, 0.05, 0.05, 24)
	else
		visual.flash(ent, 0.2, 0.2, 0.1, 16)
	end
end

function visual.defeat(ent)
	visual.play(ent, "Leave", true)
	visual.set_staff_outline(ent, 0)
	if ent then
		ent:SetColor(Color(1, 1, 1, 0.55, 0, 0, 0), 90, 12, true, false)
	end
end

local _ = defs.STATE

return visual
