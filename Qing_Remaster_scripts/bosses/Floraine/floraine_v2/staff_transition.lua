-- Floraine P1→P2 staff handoff: temporary detached staff Sprite.
-- Pose clock is TRANSITION_TIMELINE (phase_transition passes absolute frame).
-- Proxy whitelist: StaffBack / StaffFront (+ outlines); no Body / CastingFX.

local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")
local visual = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.visual")
local arena = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.arena")

local staff = {}

local PHASE = {
	ARMED = "ARMED",
	FALLING = "FALLING",
	LANDED = "LANDED",
	FLOAT = "FLOAT",
	HOVER = "HOVER",
	RECALL = "RECALL",
	ATTACHED = "ATTACHED",
}

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
	session_id = 0,
	position = nil,
	rotation = 0,
	scale = 1,
	alpha = 1,
	height = 0,
	land_pos = nil,
	start_pos = nil,
	start_rot = 0,
	land_rot = 92,
	sprite = nil,
	active = false,
	drive = "timeline", -- "timeline" | "standalone"
	local_frame = 0,
	detached_applied = false,
	catch_pose_held = false,
	recall_start_pos = nil,
	outline_alpha = 0,
}

local function outline_rgb()
	local cfg = defs.STAFF_TRANSITION or {}
	local rgb = cfg.OUTLINE_GLOW or { 0.85, 0.92, 1.0 }
	return rgb[1] or 0.85, rgb[2] or 0.92, rgb[3] or 1.0
end

local function apply_proxy_layers(s, outline_a)
	if not s or not s.GetLayer then
		return
	end
	outline_a = tonumber(outline_a) or state.outline_alpha or 0
	if outline_a < 0 then outline_a = 0 end
	if outline_a > 1 then outline_a = 1 end
	local or_, og, ob = outline_rgb()
	for name in pairs(PROXY_SHOW) do
		local ok, layer = pcall(function()
			return s:GetLayer(name)
		end)
		if ok and layer then
			if layer.SetVisible then layer:SetVisible(true) end
			if layer.SetColor then
				if name == "StaffOutlineBack" or name == "StaffOutlineFront" then
					layer:SetColor(Color(or_, og, ob, outline_a, 0.08 * outline_a, 0.05 * outline_a, 0.1 * outline_a))
				else
					layer:SetColor(Color(1, 1, 1, 1, 0, 0, 0))
				end
			end
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
		apply_proxy_layers(state.sprite, state.outline_alpha)
		return state.sprite
	end
	local s = Sprite()
	s:Load(defs.ANM2 or "gfx/boss/Floraine/Floraine.anm2", true)
	s:Play("Idle2", true)
	apply_proxy_layers(s, state.outline_alpha)
	state.sprite = s
	return s
end

local function bezier(p0, p1, p2, t)
	local u = 1 - t
	return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t)
end

local function clamp01(x)
	if x < 0 then return 0 end
	if x > 1 then return 1 end
	return x
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function smoothstep(t)
	t = clamp01(t)
	return t * t * (3 - 2 * t)
end

local function grip_world(boss_ent)
	if visual.staff_grip_pose then
		local pose = visual.staff_grip_pose(boss_ent)
		if pose and pose.pos then
			return Vector(pose.pos.X, pose.pos.Y), pose.rotation or 0, pose.scale or 1
		end
	end
	if boss_ent then
		return boss_ent.Position + Vector(-14, -55), -18, 1
	end
	return Vector.Zero, 0, 1
end

local function resolve_land_pos(boss_ent)
	local cfg = defs.STAFF_TRANSITION or {}
	local room = Game():GetRoom()
	local origin = boss_ent and boss_ent.Position or room:GetCenterPos()
	local dx = tonumber(cfg.DROP_LEFT_X) or -32
	local dy = tonumber(cfg.DROP_DOWN_Y) or 42
	local candidate = Vector(origin.X + dx, origin.Y + dy)
	candidate = room:GetClampedPosition(candidate, 20)
	-- Prefer a near left-side snap; never large-radius search that pulls right of Boss.
	if arena.nearest_walkable then
		local snapped = arena.nearest_walkable(candidate, 1)
		if snapped and snapped.X <= origin.X + 8 then
			return snapped
		end
	end
	return candidate
end

local function ensure_catch_pose(boss_ent)
	if state.catch_pose_held or not boss_ent then
		return
	end
	if visual.hold_catch_pose then
		local cfg = defs.STAFF_TRANSITION or {}
		visual.hold_catch_pose(boss_ent, cfg.CATCH_ANIM, cfg.CATCH_FRAME)
		state.catch_pose_held = true
	end
end

--- Reattach Boss-held staff on the catch frame; continue raise from that frame.
local function restore_boss_staff(boss_ent)
	if visual.set_staff_visible then
		visual.set_staff_visible(boss_ent, true)
	end
	if visual.release_catch_pose then
		visual.release_catch_pose(boss_ent, true)
	end
	state.catch_pose_held = false
end

local function timeline_windows()
	local tl = defs.TRANSITION_TIMELINE or {}
	return {
		fall0 = tl.STAFF_FALL_START or 64,
		fall1 = tl.STAFF_FALL_END or 88,
		ground1 = tl.STAFF_GROUND_END or 110,
		float1 = tl.STAFF_FLOAT_END or 128,
		hover1 = tl.STAFF_HOVER_END or 140,
		recall1 = tl.STAFF_RECALL_END or 164,
	}
end

function staff.is_detached()
	return state.active and state.phase ~= PHASE.ATTACHED and state.phase ~= PHASE.ARMED
end

function staff.is_active()
	return state.active == true
end

function staff.get_phase()
	return state.phase
end

--- Arm staff handoff. Does not detach until STAFF_FALL_START (timeline) / first standalone tick.
--- opts.standalone = true → local frame clock mapped onto staff windows (Boss Test / debug).
function staff.begin(boss_ent, session_id, opts)
	opts = opts or {}
	state.session_id = session_id or (state.session_id + 1)
	state.active = true
	state.drive = (opts.standalone == true) and "standalone" or "timeline"
	state.local_frame = 0
	state.detached_applied = false
	state.catch_pose_held = false
	state.outline_alpha = 0
	state.phase = PHASE.ARMED
	state.alpha = 1
	state.height = 0
	state.recall_start_pos = nil
	local grip, rot, sc = grip_world(boss_ent)
	state.start_pos = Vector(grip.X, grip.Y)
	state.position = Vector(grip.X, grip.Y)
	state.start_rot = rot or -18
	state.rotation = state.start_rot
	state.scale = sc or 1
	state.land_pos = resolve_land_pos(boss_ent)
	-- Counter-clockwise tip-down toward lower-left (negative delta from grip).
	state.land_rot = state.start_rot - 110
	ensure_sprite()
	return true
end

function staff.clear(boss_ent)
	restore_boss_staff(boss_ent)
	state.active = false
	state.phase = PHASE.ATTACHED
	state.sprite = nil
	state.position = nil
	state.detached_applied = false
	state.catch_pose_held = false
	state.outline_alpha = 0
	state.drive = "timeline"
	state.local_frame = 0
end

--- Drive pose from absolute transition frame (or standalone local clock).
--- transition_frame: session.frame from phase_transition; ignored in standalone.
function staff.tick(boss_ent, transition_frame)
	if not state.active then
		return false
	end
	local w = timeline_windows()
	local f
	if state.drive == "standalone" then
		state.local_frame = state.local_frame + 1
		f = w.fall0 + state.local_frame - 1
	else
		f = tonumber(transition_frame) or 0
	end

	local cfg = defs.STAFF_TRANSITION or {}
	local fall_scale = cfg.FALL_SCALE or 0.88
	local land_scale = cfg.LAND_SCALE or 0.95

	if f < w.fall0 then
		state.phase = PHASE.ARMED
		return false
	end

	-- First frame in fall window: hide Boss-held staff, show proxy.
	if not state.detached_applied then
		if visual.set_staff_visible then
			visual.set_staff_visible(boss_ent, false)
		end
		-- Re-sample grip so detach matches the live ANM2 pose at fall start.
		local grip, rot, sc = grip_world(boss_ent)
		state.start_pos = Vector(grip.X, grip.Y)
		state.position = Vector(grip.X, grip.Y)
		state.start_rot = rot or state.start_rot
		state.rotation = state.start_rot
		state.scale = sc or state.scale
		state.detached_applied = true
		ensure_sprite()
	end

	if f < w.fall1 then
		state.phase = PHASE.FALLING
		local dur = math.max(1, w.fall1 - w.fall0)
		local t = clamp01((f - w.fall0) / dur)
		local ease = t * t
		state.position = state.start_pos * (1 - ease) + state.land_pos * ease
		state.rotation = state.start_rot + (state.land_rot - state.start_rot) * t
		-- Shrink slightly in flight, settle toward land scale.
		state.scale = fall_scale + (land_scale - fall_scale) * t
		state.height = 10 * (1 - t)
		state.alpha = 1
		state.outline_alpha = 0.08
		return false
	end

	if f < w.ground1 then
		state.phase = PHASE.LANDED
		state.position = Vector(state.land_pos.X, state.land_pos.Y)
		state.scale = land_scale
		state.height = 0
		local wobble = math.sin((f - w.fall1) * 0.45) * 2.5
		state.rotation = state.land_rot + wobble
		state.alpha = 1
		state.outline_alpha = 0.12
		return false
	end

	if f < w.float1 then
		state.phase = PHASE.FLOAT
		ensure_catch_pose(boss_ent)
		local dur = math.max(1, w.float1 - w.ground1)
		local t = clamp01((f - w.ground1) / dur)
		local ease = smoothstep(t)
		state.position = Vector(state.land_pos.X, state.land_pos.Y)
		state.height = 22 * ease
		state.scale = land_scale
		state.rotation = state.land_rot - 28 * ease
		state.outline_alpha = lerp(0.12, 0.95, ease)
		state.alpha = 1
		state.recall_start_pos = Vector(state.land_pos.X, state.land_pos.Y - state.height)
		return false
	end

	if f < w.hover1 then
		state.phase = PHASE.HOVER
		ensure_catch_pose(boss_ent)
		state.position = Vector(state.land_pos.X, state.land_pos.Y)
		state.height = 22 + math.sin((f - w.float1) * 0.55) * 1.5
		state.scale = land_scale
		state.rotation = state.land_rot - 28
		state.outline_alpha = 0.95
		state.alpha = 1
		state.recall_start_pos = Vector(state.land_pos.X, state.land_pos.Y - state.height)
		return false
	end

	if f < w.recall1 then
		state.phase = PHASE.RECALL
		ensure_catch_pose(boss_ent)
		local dur = math.max(1, w.recall1 - w.hover1)
		local t = smoothstep(clamp01((f - w.hover1) / dur))
		local grip, grip_rot, grip_sc = grip_world(boss_ent)
		if not state.recall_start_pos then
			state.recall_start_pos = Vector(state.land_pos.X, state.land_pos.Y - 22)
		end
		local ctrl = Vector(
			(state.recall_start_pos.X + grip.X) * 0.5 - 12,
			math.min(state.recall_start_pos.Y, grip.Y) - 28
		)
		state.position = bezier(state.recall_start_pos, ctrl, grip, t)
		state.height = 0
		state.rotation = (state.land_rot - 28) * (1 - t) + (grip_rot or -10) * t
		state.scale = land_scale + ((grip_sc or 1) - land_scale) * t
		state.outline_alpha = 0.95 * (1 - t)
		state.alpha = 1
		return false
	end

	-- Past STAFF_RECALL_END: same-frame handoff — show Boss staff, drop proxy.
	restore_boss_staff(boss_ent)
	state.phase = PHASE.ATTACHED
	state.active = false
	state.sprite = nil
	state.position = nil
	state.detached_applied = false
	state.outline_alpha = 0
	return true
end

function staff.render()
	if not state.active or not state.position then
		return
	end
	if state.phase == PHASE.ATTACHED or state.phase == PHASE.ARMED then
		return
	end
	local s = ensure_sprite()
	if not s then
		return
	end
	apply_proxy_layers(s, state.outline_alpha)
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
		drive = state.drive,
		local_frame = state.local_frame,
		session_id = state.session_id,
		detached_applied = state.detached_applied == true,
		proxy_layers = "Staff*",
	}
end

staff.PHASE = PHASE

return staff
