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

local STAFF_BODY = {
	"StaffBack",
	"StaffFront",
}

local STAFF_OUTLINE = {
	"StaffOutlineBack",
	"StaffOutlineFront",
}

-- Per-Boss show/hide only. ANM2 owns StaffBack/StaffFront Visible; Lua only sets Color alpha.
local STAFF_VISIBLE_KEY = "QingFloraineStaffVisible"
local STAFF_CATCH_HOLD_KEY = "QingFloraineStaffCatchHold"

local function layer_by_name(s, name)
	if not s or not s.GetLayer or not name then
		return nil
	end
	local ok, layer = pcall(function()
		return s:GetLayer(name)
	end)
	if ok then
		return layer
	end
	return nil
end

local function layer_frame_data(s, layer)
	if not s or not s.GetLayerFrameData or not layer then
		return nil
	end
	local lid = nil
	if layer.GetLayerID then
		lid = layer:GetLayerID()
	elseif layer.GetId then
		lid = layer:GetId()
	end
	if lid == nil then
		return nil
	end
	local ok, fd = pcall(function()
		return s:GetLayerFrameData(lid)
	end)
	if ok then
		return fd
	end
	return nil
end

local function staff_visible_of(ent)
	if not ent then
		return true
	end
	local d = ent:GetData()
	if d[STAFF_VISIBLE_KEY] == nil then
		return true
	end
	return d[STAFF_VISIBLE_KEY] == true
end

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
	if name == "Idle" or name == "Idle2" then return 61 end
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
		-- Peak at Call@5 (thrust apex), then settle toward 0.45.
		if frame <= 5 then
			return lerp(0.65, 1.0, frame / 5)
		end
		return lerp(1.0, 0.45, clamp01((frame - 5) / math.max(1, n - 6)))
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

local function set_layers_alpha(s, names, alpha, rgb)
	if not s then
		return
	end
	alpha = clamp01(alpha or 0)
	local r = (rgb and rgb[1]) or 1
	local g = (rgb and rgb[2]) or 1
	local b = (rgb and rgb[3]) or 1
	for i = 1, #names do
		local layer = layer_by_name(s, names[i])
		if layer and layer.SetColor then
			-- Never SetVisible: ANM2 owns back/front handoff.
			layer:SetColor(Color(r, g, b, alpha, 0, 0, 0))
		end
	end
end

--- Apply Boss-held staff Color alpha from the per-entity visible flag.
--- Does not touch animation, frame, or Layer Visible.
local function apply_staff_visibility(ent)
	local s = sprite(ent)
	if not s or not s.GetLayer then
		return
	end
	if staff_visible_of(ent) then
		set_layers_alpha(s, STAFF_BODY, 1, { 1, 1, 1 })
		local anim = s:GetAnimation()
		local a = visual.staff_outline_alpha_for(anim, anim_frame(s))
		local cfg = visual.STAFF_OUTLINE or {}
		set_layers_alpha(s, STAFF_OUTLINE, a, cfg.color or { 0.55, 0.95, 0.75 })
	else
		set_layers_alpha(s, STAFF_BODY, 0, { 1, 1, 1 })
		set_layers_alpha(s, STAFF_OUTLINE, 0, { 1, 1, 1 })
	end
end

function visual.set_staff_outline(ent, alpha, color)
	local s = sprite(ent)
	if not s or not s.GetLayer then
		return
	end
	if not staff_visible_of(ent) then
		alpha = 0
	end
	local cfg = visual.STAFF_OUTLINE or {}
	set_layers_alpha(s, STAFF_OUTLINE, alpha, color or cfg.color or { 1, 1, 1 })
end

--- Sole Boss-staff display controller: show/hide via Alpha only.
--- true  → body Alpha 1, outline follows current anim rule
--- false → body + outline Alpha 0 (proxy may draw instead)
--- Same instruction twice is a no-op on state; still re-applies Alpha (safe after anim changes).
function visual.set_staff_visible(ent, visible)
	if not ent then
		return
	end
	local want = visible ~= false
	local d = ent:GetData()
	d[STAFF_VISIBLE_KEY] = want
	apply_staff_visibility(ent)
end

function visual.is_staff_visible(ent)
	return staff_visible_of(ent)
end

--- Outline + body Alpha maintenance for the current anim. Never re-enters hide/show.
function visual.tick_staff_outline(ent)
	local s = sprite(ent)
	if not s then return end
	apply_staff_visibility(ent)
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
--- force=true restarts Raise even if already mid-command (opening Owner only).
function visual.command(ent, force)
	local anim = current_anim(ent)
	if not force and IN_COMMAND[anim] then
		visual.tick_staff_outline(ent)
		return
	end
	if force then
		visual.play(ent, "Raise", true)
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

--- Active staff layer + AnimationFrame pose (Front preferred when visible).
local function resolve_staff_frame(ent)
	local s = sprite(ent)
	if not s then
		return nil, nil, nil
	end
	local base = ent.Position + (ent.PositionOffset or Vector.Zero)
	local prefer = { "StaffFront", "StaffBack" }
	for i = 1, #prefer do
		local layer = layer_by_name(s, prefer[i])
		local fd = layer_frame_data(s, layer)
		if fd and fd.GetPos then
			local visible = true
			if fd.IsVisible then
				visible = fd:IsVisible() == true
			end
			if visible or i == #prefer then
				return s, fd, base
			end
		end
	end
	-- Layer ids fallback: StaffFront=5
	if s.GetLayerFrameData then
		local ok, fd = pcall(function()
			return s:GetLayerFrameData(5)
		end)
		if ok and fd and fd.GetPos then
			return s, fd, base
		end
	end
	return s, nil, base
end

--- World grip / pivot of the held staff (proxy detach origin). Includes rotation + scale.
function visual.staff_grip_pose(ent)
	if not ent then
		return nil
	end
	local _, fd, base = resolve_staff_frame(ent)
	base = base or (ent.Position + (ent.PositionOffset or Vector.Zero))
	if fd and fd.GetPos then
		local p = fd:GetPos()
		local rot = (fd.GetRotation and fd:GetRotation()) or 0
		local sc = 1
		if fd.GetScale then
			local sv = fd:GetScale()
			if sv then
				sc = tonumber(sv.Y) or tonumber(sv.X) or 1
			end
		end
		return {
			pos = Vector(base.X + p.X, base.Y + p.Y),
			rotation = rot,
			scale = sc,
		}
	end
	return {
		pos = Vector(base.X - 14, base.Y - 55),
		rotation = -18,
		scale = 1,
	}
end

--- World position of the raised staff tip (particle spawn). Falls back to approx offset.
function visual.staff_tip_world(ent)
	if not ent then
		return nil
	end
	local pose = visual.staff_grip_pose(ent)
	if not pose then
		return nil
	end
	local _, fd = resolve_staff_frame(ent)
	local sc = pose.scale or 1
	local rot = pose.rotation or 0
	-- Tip is above staff pivot along staff axis (crop 96 tall, pivot at y=64 → tip -64).
	local tip_len = 64 * sc
	local rad = math.rad(rot)
	if fd and fd.GetPos then
		return Vector(
			pose.pos.X - math.sin(rad) * tip_len,
			pose.pos.Y - math.cos(rad) * tip_len
		)
	end
	return Vector(pose.pos.X - 2, pose.pos.Y - tip_len)
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

--- Freeze Boss on an existing catch-pose frame (no new ANM2). Grip reads this frame.
function visual.hold_catch_pose(ent, anim, frame)
	if not ent then
		return
	end
	local s = sprite(ent)
	if not s then
		return
	end
	local cfg = defs.STAFF_TRANSITION or {}
	anim = anim or cfg.CATCH_ANIM or "RaiseFromIdle2"
	frame = math.max(0, math.floor(tonumber(frame) or cfg.CATCH_FRAME or 0))
	if s:GetAnimation() ~= anim then
		s:Play(anim, true)
	end
	if s.SetFrame then
		s:SetFrame(frame)
	end
	ent:GetData()[STAFF_CATCH_HOLD_KEY] = { anim = anim, frame = frame }
	visual.tick_staff_outline(ent)
end

--- Release catch hold. continue=true keeps current anim/frame (do not restart from 0).
function visual.release_catch_pose(ent, continue_anim)
	if not ent then
		return
	end
	local d = ent:GetData()
	local hold = d[STAFF_CATCH_HOLD_KEY]
	d[STAFF_CATCH_HOLD_KEY] = nil
	if continue_anim == false or not hold then
		return
	end
	local s = sprite(ent)
	if not s then
		return
	end
	if s:GetAnimation() ~= hold.anim then
		s:Play(hold.anim, true)
	end
	if s.SetFrame then
		s:SetFrame(hold.frame)
	end
	visual.tick_staff_outline(ent)
end

function visual.is_catch_pose_held(ent)
	return ent and ent:GetData()[STAFF_CATCH_HOLD_KEY] ~= nil
end

--- Advance Raise→Cast→Settle→Idle2 (and Lower→Idle). Does not force Idle.
function visual.tick_chain(ent)
	local s = sprite(ent)
	if not s then return end
	local hold = ent:GetData()[STAFF_CATCH_HOLD_KEY]
	if hold then
		if s:GetAnimation() ~= hold.anim then
			s:Play(hold.anim, true)
		end
		if s.SetFrame then
			s:SetFrame(hold.frame)
		end
		visual.tick_staff_outline(ent)
		return
	end
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

--- Phase identity is carried by board / staff, not a lasting Boss SetColor filter.
--- P2 intentionally does not apply a tint; hit feedback uses visual.flash elsewhere.
function visual.phase_tint(ent, p)
	if p == 2 then
		return
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
