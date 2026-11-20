-- Continuous tractor-beam visual state (logic tick owns; render reads).
-- Mouth tip binds to UFO each frame; foot/width/alpha/rgb ease toward phase targets.
local C = require("Qing_Remaster_scripts.items.alien_savior.constants")
local motion = require("Qing_Remaster_scripts.items.alien_savior.motion")

local B = {}

-- Measured: Alien_beam_cone.png opaque rows 0..127, ANM2 YPivot=0 → visible H=128.
-- Ground: Alien_beam_ground.png pivot (32,16); opaque ~4..30.
local CONE_VISIBLE_H = C.BEAM_CONE_VISIBLE_H or 128
local SEAM_OVERLAP = C.BEAM_SEAM_OVERLAP_PX or 2

local function clamp01(t)
	if t < 0 then return 0 end
	if t > 1 then return 1 end
	return t
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function approach(cur, tgt, k)
	return cur + (tgt - cur) * k
end

local function phase_progress(txn)
	local dur = math.max(1, txn.phase_dur or 1)
	return clamp01((txn.phase_frame or 0) / dur)
end

local function default_rgb()
	return 0.45, 0.95, 0.78
end

function B.cone_visible_height()
	return CONE_VISIBLE_H
end

function B.seam_overlap_px()
	return SEAM_OVERLAP
end

local function ensure(txn)
	if not txn then
		return nil
	end
	local bv = txn.beam_visual
	if bv then
		return bv
	end
	local r, g, b = default_rgb()
	bv = {
		open = 0,
		width = C.BEAM_WIDTH or 1,
		alpha = 0,
		r = r,
		g = g,
		b = b,
		foot_x = 0,
		foot_y = 0,
		foot_initialized = false,
		tgt_open = 0,
		tgt_width = C.BEAM_WIDTH or 1,
		tgt_alpha = 0,
		tgt_r = r,
		tgt_g = g,
		tgt_b = b,
		tgt_foot_x = 0,
		tgt_foot_y = 0,
		mode = "off",
		seam_delta = 0,
		paused = false,
	}
	txn.beam_visual = bv
	return bv
end

function B.get(txn)
	return txn and txn.beam_visual
end

--- Core lamp tint → soft beam RGB (no Offset copy).
function B.sample_core_rgb(txn)
	local lamp = txn and txn.core_lamp
	if lamp and lamp.tint then
		local t = lamp.tint
		return clamp01(t[1] or 0.5), clamp01(t[2] or 0.95), clamp01(t[3] or 0.8)
	end
	return default_rgb()
end

local function ease_out_cubic(t)
	t = clamp01(t)
	local u = 1 - t
	return 1 - u * u * u
end

local function release_segments()
	local travel = C.BEAM_RELEASE_TRAVEL or 24
	local settle = C.BEAM_RELEASE_SETTLE or 6
	local drop = C.DUR and C.DUR.ABDUCT_PLAYER or 35
	local close = C.BEAM_RELEASE_CLOSE or 12
	return travel, settle, drop, close, travel + settle + drop + close
end

function B.release_timeline()
	local travel, settle, drop, close, total = release_segments()
	return {
		travel = travel,
		settle = settle,
		drop = drop,
		close = close,
		total = total,
		settle_end = travel + settle,
		-- drop_end is nominal; actual drop may start after settle gate.
		drop_end = travel + settle + drop,
	}
end

--- Same 0..1 curve motion.lua uses for RELEASE UFO travel.
function B.release_travel_t(txn)
	local tl = B.release_timeline()
	local f = (txn and txn.phase_frame) or 0
	if f >= tl.travel then
		return 1
	end
	return ease_out_cubic(f / math.max(1, tl.travel))
end

function B.release_segment(txn)
	if not txn or txn.phase ~= C.PHASE.RELEASE_PLAYER then
		return "idle"
	end
	local f = txn.phase_frame or 0
	local tl = B.release_timeline()
	if f < tl.travel then
		return "travel"
	end
	-- Stay in settle until controller arms drop (UFO + beam stable).
	if not txn.release_drop_armed then
		return "settle"
	end
	local drop_start = txn.release_drop_frame or tl.settle_end
	if f < drop_start + tl.drop then
		return "drop"
	end
	return "close"
end

--- Drop progress 0..1 only during RELEASE drop segment.
function B.release_drop_progress(txn)
	if B.release_segment(txn) ~= "drop" then
		return 0
	end
	local tl = B.release_timeline()
	local drop_start = txn.release_drop_frame or tl.settle_end
	local f = (txn.phase_frame or 0) - drop_start
	return clamp01(f / math.max(1, tl.drop))
end

--- True when UFO/beam are stable enough to reverse LightTravel.
function B.release_ready(txn)
	if not txn or txn.phase ~= C.PHASE.RELEASE_PLAYER then
		return false
	end
	local tl = B.release_timeline()
	if (txn.phase_frame or 0) < tl.settle_end then
		return false
	end
	local bv = ensure(txn)
	local mouth = motion.mouth_world_pos(txn)
	local dest_hover = txn.release_hover_pos
	local ufo = motion.ufo_world_pos(txn)
	local hover_err = 99
	if dest_hover then
		hover_err = (ufo - dest_hover):Length()
	end
	local release_y = (txn.release_pos and txn.release_pos.Y) or bv.foot_y
	local foot_err = math.abs((bv.foot_y or 0) - release_y) + math.abs((bv.foot_x or 0) - mouth.X)
	local base_w = motion.beam_width()
	local width_err = math.abs((bv.width or base_w) - base_w)
	return hover_err <= 3.5
		and foot_err <= 5
		and width_err <= 0.12
		and (bv.open or 0) >= 0.9
end

local function transit_close_frac()
	local close_f = C.BEAM_TRANSIT_CLOSE or 10
	local dur = (C.DUR and C.DUR.TRANSIT_TO_CENTER) or 32
	return clamp01(close_f / math.max(1, dur))
end

local function work_open_frames()
	return C.BEAM_WORK_OPEN or 15
end

--- Desired beam mode / open / foot for this logic frame (targets only).
function B.compute_targets(txn)
	local mouth = motion.mouth_world_pos(txn)
	local base_w = motion.beam_width()
	local base_op = motion.beam_opacity()
	local r, g, b = B.sample_core_rgb(txn)
	local foot = txn.beam_foot or txn.player_origin or Vector(mouth.X, mouth.Y + 80)
	local mode = "off"
	local open = 0
	local width = base_w
	local alpha = 0

	local dbg = motion.get_debug()
	if dbg.force_beam_mode then
		mode = dbg.force_beam_mode
		if mode == "off" then
			open = 0
			alpha = 0
		else
			open = 1
			alpha = base_op
			if mode == "work" then
				width = base_w * (C.BEAM_WORK_WIDTH or 1.85)
				foot = Vector(mouth.X, mouth.Y + (C.BEAM_WORK_LENGTH or 110))
			elseif mode == "release" and txn.release_pos then
				foot = Vector(mouth.X, txn.release_pos.Y)
			elseif mode == "pickup" then
				foot = Vector(mouth.X, (txn.player_origin or foot).Y)
			end
		end
		return {
			mode = mode,
			open = open,
			width = width,
			alpha = alpha,
			r = r,
			g = g,
			b = b,
			foot = foot,
			mouth = mouth,
		}
	end

	local phase = txn.phase
	local p = phase_progress(txn)

	if phase == C.PHASE.ARRIVING then
		-- Open during the last ARRIVING window so ABDUCT starts with a full beam.
		local open_start = C.BEAM_OPEN_START or 0.55
		if p >= open_start then
			mode = "pickup"
			open = clamp01((p - open_start) / math.max(0.001, 1 - open_start))
			alpha = base_op * open
			foot = Vector(mouth.X, (txn.player_origin or foot).Y)
		end
	elseif phase == C.PHASE.ABDUCT_PLAYER then
		mode = "pickup"
		open = 1
		alpha = base_op
		foot = Vector(mouth.X, (txn.player_origin or foot).Y)
	elseif phase == C.PHASE.TRANSIT_TO_CENTER then
		local cf = transit_close_frac()
		if p < cf then
			-- Hold over pickup while closing.
			mode = "pickup"
			open = 1 - clamp01(p / math.max(0.001, cf))
			alpha = base_op * open
			foot = Vector(mouth.X, (txn.player_origin or foot).Y)
		else
			mode = "off"
			open = 0
			alpha = 0
		end
	elseif phase == C.PHASE.ABDUCT_TARGETS or phase == C.PHASE.LASER_SWEEP then
		mode = "work"
		width = base_w * (C.BEAM_WORK_WIDTH or 1.85)
		foot = Vector(mouth.X, mouth.Y + (C.BEAM_WORK_LENGTH or 110))
		if phase == C.PHASE.ABDUCT_TARGETS then
			-- Absolute frames so dynamic ABDUCT duration does not stretch the open ramp.
			local open_f = math.max(1, work_open_frames())
			local pf = txn.phase_frame or 0
			open = pf < open_f and clamp01(pf / open_f) or 1
			alpha = base_op * open
		else
			-- LASER_SWEEP: fade traction beam so cone mains own the mouth emitter.
			local fade_n = (C.LASER and C.LASER.BEAM_FADE_FRAMES) or 8
			local fade_a = (C.LASER and C.LASER.BEAM_FADE_ALPHA) or 0.10
			local fade_w = (C.LASER and C.LASER.BEAM_FADE_WIDTH) or 0.60
			local pf = txn.phase_frame or 0
			local t = fade_n > 0 and clamp01(pf / fade_n) or 1
			open = lerp(1, fade_w, t)
			alpha = base_op * lerp(1, fade_a, t)
			width = width * lerp(1, fade_w, t)
			r = lerp(r, 0.55, 0.35)
			g = lerp(g, 0.82, 0.35)
			b = lerp(b, 1.0, 0.45)
		end
	elseif phase == C.PHASE.RELEASE_PLAYER then
		-- Carry lit beam with UFO: travel → settle → drop → close (no reopen).
		local seg = B.release_segment(txn)
		local t = B.release_travel_t(txn)
		local work_w = base_w * (C.BEAM_WORK_WIDTH or 1.85)
		local from = txn.work_beam_foot or txn.work_feet or Vector(mouth.X, mouth.Y + 80)
		local to = txn.release_pos or from
		local foot_y = lerp(from.Y, to.Y, t)
		if seg ~= "travel" then
			foot_y = to.Y
		end
		-- Vertical beam: foot X always matches mouth (same travel progress as UFO).
		foot = Vector(mouth.X, foot_y)
		mode = "release"
		width = lerp(work_w, base_w, t)
		if seg == "close" then
			local tl = B.release_timeline()
			local drop_start = txn.release_drop_frame or tl.settle_end
			local close_start = drop_start + tl.drop
			local u = ((txn.phase_frame or 0) - close_start) / math.max(1, tl.close)
			open = 1 - clamp01(u)
			alpha = base_op * open
			width = base_w
			foot = Vector(mouth.X, to.Y)
		else
			open = 1
			alpha = base_op
		end
	elseif phase == C.PHASE.DEPARTING then
		-- Beam already closed at end of RELEASE; never re-light.
		mode = "off"
		open = 0
		alpha = 0
		foot = Vector(mouth.X, (txn.release_pos or foot).Y)
	end

	return {
		mode = mode,
		open = open,
		width = width,
		alpha = alpha,
		r = r,
		g = g,
		b = b,
		foot = foot,
		mouth = mouth,
		-- During RELEASE pathing, snap foot to shared travel progress (no lag chase).
		lock_foot = phase == C.PHASE.RELEASE_PLAYER,
	}
end

function B.tick(txn)
	if not txn then
		return
	end
	local bv = ensure(txn)
	local dbg = motion.get_debug()
	if dbg.beam_freeze then
		return
	end
	local smooth = C.BEAM_SMOOTH or {}
	local tgt = B.compute_targets(txn)
	bv.tgt_open = tgt.open
	bv.tgt_width = tgt.width
	bv.tgt_alpha = tgt.alpha
	bv.tgt_r = tgt.r
	bv.tgt_g = tgt.g
	bv.tgt_b = tgt.b
	bv.tgt_foot_x = tgt.foot.X
	bv.tgt_foot_y = tgt.foot.Y
	bv.mode = tgt.mode

	if not bv.foot_initialized then
		bv.foot_x = tgt.foot.X
		bv.foot_y = tgt.foot.Y
		bv.foot_initialized = true
		bv.open = tgt.open
		bv.width = tgt.width
		bv.alpha = tgt.alpha
		bv.r = tgt.r
		bv.g = tgt.g
		bv.b = tgt.b
		return
	end

	local ko = smooth.open or 0.14
	local kw = smooth.width or 0.14
	local ka = smooth.alpha or 0.16
	local kc = smooth.color or 0.14
	local kf = smooth.foot or 0.18

	bv.open = approach(bv.open, tgt.open, ko)
	bv.width = approach(bv.width, tgt.width, kw)
	bv.alpha = approach(bv.alpha, tgt.alpha, ka)
	bv.r = approach(bv.r, tgt.r, kc)
	bv.g = approach(bv.g, tgt.g, kc)
	bv.b = approach(bv.b, tgt.b, kc)
	if tgt.lock_foot then
		bv.foot_x = tgt.foot.X
		bv.foot_y = tgt.foot.Y
	elseif bv.open < 0.04 and tgt.open < 0.04 then
		bv.foot_x = approach(bv.foot_x, tgt.foot.X, math.max(kf, 0.35))
		bv.foot_y = approach(bv.foot_y, tgt.foot.Y, math.max(kf, 0.35))
	else
		bv.foot_x = approach(bv.foot_x, tgt.foot.X, kf)
		bv.foot_y = approach(bv.foot_y, tgt.foot.Y, kf)
	end
end

function B.is_open_enough(txn, threshold)
	local bv = ensure(txn)
	return (bv.open or 0) >= (threshold or 0.95)
end

function B.is_closed_enough(txn, threshold)
	local bv = ensure(txn)
	return (bv.open or 0) <= (threshold or 0.06)
end

--- Screen-space cone bottom / ground center for seam audit + render.
function B.layout_screen(mouth_world, foot_world, open, width_scale)
	open = clamp01(open or 0)
	width_scale = width_scale or 1
	local room = Game():GetRoom()
	local function w2s(p)
		if room and room.WorldToScreenPosition then
			return room:WorldToScreenPosition(p)
		end
		return Isaac.WorldToScreen(p)
	end
	local mouth_s = w2s(mouth_world)
	local foot_s = w2s(foot_world)
	local full_dy = foot_s.Y - mouth_s.Y
	if full_dy < 8 then
		full_dy = 8
	end
	local len_s = full_dy * open
	local y_scale = len_s / CONE_VISIBLE_H
	-- Cone bottom in screen space (pivot at top).
	local cone_bottom_y = mouth_s.Y + CONE_VISIBLE_H * y_scale
	-- Pull ground center slightly onto the cone so the bright mid-ellipse hides the edge.
	local ground_center = Vector(mouth_s.X, cone_bottom_y - SEAM_OVERLAP * open)
	return {
		mouth_s = mouth_s,
		foot_s = foot_s,
		cone_bottom_y = cone_bottom_y,
		ground_center_s = ground_center,
		y_scale = y_scale,
		width_scale = width_scale,
		len_s = len_s,
		seam_delta = ground_center.Y - cone_bottom_y,
	}
end

function B.audit(txn)
	local bv = ensure(txn)
	local mouth = motion.mouth_world_pos(txn)
	local foot = Vector(bv.foot_x, bv.foot_y)
	local lay = B.layout_screen(mouth, foot, bv.open, bv.width)
	bv.seam_delta = lay.seam_delta
	return {
		open = bv.open,
		tgt_open = bv.tgt_open,
		width = bv.width,
		tgt_width = bv.tgt_width,
		alpha = bv.alpha,
		tgt_alpha = bv.tgt_alpha,
		rgb = { bv.r, bv.g, bv.b },
		tgt_rgb = { bv.tgt_r, bv.tgt_g, bv.tgt_b },
		mode = bv.mode,
		foot = { x = bv.foot_x, y = bv.foot_y },
		tgt_foot = { x = bv.tgt_foot_x, y = bv.tgt_foot_y },
		cone_bottom_y = lay.cone_bottom_y,
		ground_center_y = lay.ground_center_s.Y,
		seam_delta = lay.seam_delta,
		release_segment = B.release_segment(txn),
		release_ready = B.release_ready(txn),
		release_travel_t = B.release_travel_t(txn),
		mouth = { x = mouth.X, y = mouth.Y },
		foot_mouth_x_delta = (bv.foot_x or 0) - mouth.X,
	}
end

return B
