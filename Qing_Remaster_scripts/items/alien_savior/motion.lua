-- UFO Workflow V3: waypoints, viewport-based entry/exit, beam modes.
local C = require("Qing_Remaster_scripts.items.alien_savior.constants")

local M = {}

local dbg = {
	enabled = false,
	scale = nil,
	hover_height = nil,
	beam_width = nil,
	beam_opacity = nil,
	force_beam_mode = nil, -- pickup|work|release|off|nil
	-- Beam layers: core off by default (ugly center strip). Probe can re-enable.
	beam_show_cone = true,
	beam_show_core = false,
	beam_show_ground = true,
	capture_frame = nil, -- override LightTravel scrub end
	show_path = false,
	show_mouth = false,
	show_bounds = false,
	show_pass = false, -- annotate front/back
	show_beam_seam = false,
	beam_freeze = false,
	paused = false,
	step_pending = 0,
}

local function clamp01(t)
	if t < 0 then return 0 end
	if t > 1 then return 1 end
	return t
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function ease_out_cubic(t)
	t = clamp01(t)
	local u = 1 - t
	return 1 - u * u * u
end

local function ease_in_cubic(t)
	t = clamp01(t)
	return t * t * t
end

local function lerp_vec(a, b, t)
	return Vector(lerp(a.X, b.X, t), lerp(a.Y, b.Y, t))
end

function M.get_debug()
	return dbg
end

function M.set_debug(patch)
	if not patch then return end
	for k, v in pairs(patch) do
		dbg[k] = v
	end
end

function M.reset_debug()
	dbg.scale = nil
	dbg.hover_height = nil
	dbg.beam_width = nil
	dbg.beam_opacity = nil
	dbg.force_beam_mode = nil
	dbg.beam_show_cone = true
	dbg.beam_show_core = false
	dbg.beam_show_ground = true
	dbg.capture_frame = nil
	dbg.show_path = false
	dbg.show_mouth = false
	dbg.show_bounds = false
	dbg.show_pass = false
	dbg.show_beam_seam = false
	dbg.beam_freeze = false
	dbg.paused = false
	dbg.step_pending = 0
	dbg.enabled = false
end

function M.beam_layer_visible(name)
	if name == "cone" then
		return dbg.beam_show_cone ~= false
	end
	if name == "core" then
		return dbg.beam_show_core == true
	end
	if name == "ground" then
		return dbg.beam_show_ground ~= false
	end
	return true
end

function M.capture_frame()
	local v = dbg.capture_frame
	if v == nil then
		v = C.LIGHTTRAVEL_CAPTURE_FRAME or 32
	end
	local last = C.LIGHTTRAVEL_LAST_FRAME or 35
	v = math.floor(tonumber(v) or 32)
	if v < 1 then
		v = 1
	elseif v > last then
		v = last
	end
	return v
end

function M.scale()
	local s = dbg.scale
	if s == nil then s = C.UFO_SCALE or 1 end
	if s < 0.75 then s = 0.75 elseif s > 1.25 then s = 1.25 end
	return s
end

function M.hover_height()
	return dbg.hover_height or C.UFO_HOVER_HEIGHT or 84
end

local function mouth_local(scale)
	local m = C.MOUTH_OFFSET or Vector(0, 22)
	return Vector(m.X * scale, m.Y * scale)
end

function M.beam_width()
	return dbg.beam_width or C.BEAM_WIDTH or 1.0
end

function M.beam_opacity()
	return dbg.beam_opacity or C.BEAM_OPACITY or 0.85
end

--- Diagnostics for requested vs clamped hover.
function M.hover_above_info(feet, scale)
	scale = scale or M.scale()
	feet = feet or Vector.Zero
	local ml = mouth_local(scale)
	local requested_h = M.hover_height()
	local unclamped = Vector(feet.X - ml.X, feet.Y - requested_h - ml.Y)
	local hover = unclamped
	local top_clamped = false
	local room = Game():GetRoom()
	if room and room.GetTopLeftPos then
		local top = room:GetTopLeftPos()
		local min_y = top.Y - 48 * scale
		if hover.Y < min_y then
			hover = Vector(hover.X, min_y)
			top_clamped = true
		end
	end
	local mouth = hover + ml
	local actual_h = feet.Y - mouth.Y
	return {
		requested_height = requested_h,
		actual_height = actual_h,
		top_clamped = top_clamped,
		hover = hover,
		mouth = mouth,
		feet = feet,
	}
end

--- Hover pivot so mouth sits `hover_height` above feet and shares feet.X.
function M.hover_above(feet, scale)
	return M.hover_above_info(feet, scale).hover
end

local function screen_size()
	local w = (Isaac.GetScreenWidth and Isaac.GetScreenWidth()) or 480
	local h = (Isaac.GetScreenHeight and Isaac.GetScreenHeight()) or 270
	return w, h
end

local function world_to_screen(pos)
	local room = Game():GetRoom()
	if room and room.WorldToScreenPosition then
		return room:WorldToScreenPosition(pos)
	end
	return Isaac.WorldToScreen(pos)
end

--- True if UFO hull centered at `pos` is fully outside the visible screen.
function M.is_fully_offscreen(pos, scale)
	scale = scale or M.scale()
	local s = world_to_screen(pos)
	local w, h = screen_size()
	local hw = (C.UFO_HALF_W or 110) * scale + (C.UFO_OFFSCREEN_MARGIN or 24)
	local hh = (C.UFO_HALF_H or 50) * scale + (C.UFO_OFFSCREEN_MARGIN or 24)
	return s.X < -hw or s.X > w + hw or s.Y < -hh or s.Y > h + hh
end

--- Walk from `from` along `dir` until hull is off-screen.
function M.offscreen_along(from, dir, scale)
	scale = scale or M.scale()
	from = from or Vector.Zero
	dir = dir or Vector(40, -30)
	local len = math.sqrt(dir.X * dir.X + dir.Y * dir.Y)
	if len < 1e-3 then
		dir = Vector(40, -30)
		len = math.sqrt(dir.X * dir.X + dir.Y * dir.Y)
	end
	dir = Vector(dir.X / len * 48, dir.Y / len * 48)
	local p = Vector(from.X, from.Y)
	for _ = 1, 48 do
		p = p + dir
		if M.is_fully_offscreen(p, scale) then
			-- Extra step so the whole body clears with room to spare.
			return p + dir
		end
	end
	return p
end

function M.prepare_txn(txn, player_origin)
	if not txn then return end
	local scale = M.scale()
	local origin = player_origin or txn.player_origin or Vector.Zero
	txn.player_origin = Vector(origin.X, origin.Y)
	txn.park_pos = Vector(origin.X, origin.Y)

	txn.pickup_hover_pos = M.hover_above(txn.player_origin, scale)
	local room = Game():GetRoom()
	local center = (room and room.GetCenterPos and room:GetCenterPos()) or txn.player_origin
	txn.work_feet = Vector(center.X, center.Y)
	txn.work_hover_pos = M.hover_above(txn.work_feet, scale)

	-- Entry: come from the side with more space, fully off-screen.
	local side = 1
	if room and room.GetCenterPos then
		if txn.player_origin.X > center.X then
			side = -1
		end
	end
	txn.entry_pos = M.offscreen_along(txn.pickup_hover_pos, Vector(side * 80, -55), scale)
	txn.exit_pos = nil -- filled when DEPARTING begins
	txn.release_pos = nil
	txn.release_hover_pos = nil
	txn.motion_overshoot = C.UFO_OVERSHOOT or 6

	-- Legacy alias used by older summary / probes.
	txn.hover_pos = txn.pickup_hover_pos
	txn.beam_foot = Vector(origin.X, origin.Y)
end

function M.begin_release_route(txn)
	if not txn then return end
	local ops = require("Qing_Remaster_scripts.items.alien_savior.ops")
	local release = ops.pick_release_pos(txn)
	txn.release_pos = release
	txn.release_hover_pos = M.hover_above(release, M.scale())
	-- Remember where the hull is now; RELEASE travel lerps here → release_hover.
	txn.release_travel_from = Vector(
		(txn.work_hover_pos or M.ufo_world_pos(txn)).X,
		(txn.work_hover_pos or M.ufo_world_pos(txn)).Y
	)
	-- Do not snap hover_pos to release yet — travel segment owns the move.
	txn.hover_pos = txn.release_travel_from
end

function M.begin_depart_route(txn)
	if not txn then return end
	local start = txn.release_hover_pos or txn.work_hover_pos or M.ufo_world_pos(txn)
	local room = Game():GetRoom()
	local center = (room and room.GetCenterPos and room:GetCenterPos()) or start
	local side = (start.X >= center.X) and 1 or -1
	txn.exit_pos = M.offscreen_along(start, Vector(side * 90, -70), M.scale())
	txn.depart_start_pos = Vector(start.X, start.Y)
end

local function phase_progress(txn)
	local dur = math.max(1, txn.phase_dur or 1)
	local frame = txn.phase_frame or 0
	return clamp01(frame / dur)
end

local function arriving_pos(txn, p)
	local entry = txn.entry_pos or txn.pickup_hover_pos
	local hover = txn.pickup_hover_pos or Vector.Zero
	local over = txn.motion_overshoot or 6
	local overshoot = Vector(hover.X, hover.Y + over)
	if p < 0.72 then
		local t = ease_out_cubic(p / 0.72)
		return lerp_vec(entry, overshoot, t)
	end
	local t = ease_out_cubic((p - 0.72) / 0.28)
	return lerp_vec(overshoot, hover, t)
end

local function transit_pos(txn, p)
	local a = txn.pickup_hover_pos or Vector.Zero
	local b = txn.work_hover_pos or a
	-- Hold at pickup while beam closes, then fly (see C.BEAM_TRANSIT_CLOSE).
	local close_f = C.BEAM_TRANSIT_CLOSE or 10
	local dur = math.max(1, txn.phase_dur or (C.DUR and C.DUR.TRANSIT_TO_CENTER) or 32)
	local cf = clamp01(close_f / dur)
	if p < cf then
		return a
	end
	local t = ease_out_cubic((p - cf) / math.max(0.001, 1 - cf))
	return lerp_vec(a, b, t)
end

local function departing_pos(txn, p)
	local a = txn.depart_start_pos or txn.release_hover_pos or txn.work_hover_pos or Vector.Zero
	local b = txn.exit_pos or a
	return lerp_vec(a, b, ease_in_cubic(p))
end

function M.ufo_world_pos(txn)
	if not txn then return Vector.Zero end
	local phase = txn.phase
	local p = phase_progress(txn)
	if phase == C.PHASE.ARRIVING then
		return arriving_pos(txn, p)
	end
	if phase == C.PHASE.ABDUCT_PLAYER then
		local hover = txn.pickup_hover_pos or Vector.Zero
		local bob = math.sin((txn.light_age or 0) * 0.15) * (C.UFO_HOVER_BOB or 1.5)
		return Vector(hover.X, hover.Y + bob)
	end
	if phase == C.PHASE.TRANSIT_TO_CENTER then
		return transit_pos(txn, p)
	end
	if phase == C.PHASE.ABDUCT_TARGETS or phase == C.PHASE.LASER_SWEEP then
		local hover = txn.work_hover_pos or Vector.Zero
		local bob = math.sin((txn.light_age or 0) * 0.15) * (C.UFO_HOVER_BOB or 1.5)
		return Vector(hover.X, hover.Y + bob)
	end
	if phase == C.PHASE.RELEASE_PLAYER then
		local beam = require("Qing_Remaster_scripts.items.alien_savior.beam")
		local from = txn.release_travel_from or txn.work_hover_pos or Vector.Zero
		local dest = txn.release_hover_pos or from
		local t = beam.release_travel_t(txn)
		local hover = lerp_vec(from, dest, t)
		if t >= 1 then
			txn.hover_pos = dest
			hover = dest
		end
		local bob = math.sin((txn.light_age or 0) * 0.15) * (C.UFO_HOVER_BOB or 1.5)
		return Vector(hover.X, hover.Y + bob)
	end
	if phase == C.PHASE.DEPARTING then
		return departing_pos(txn, p)
	end
	return txn.work_hover_pos or txn.pickup_hover_pos or Vector.Zero
end

--- Hidden player cabin while stowed. Default: UFO pivot (no SpriteOffset lift).
function M.player_cabin_world_pos(txn)
	local ufo = M.ufo_world_pos(txn)
	local oy = C.UFO_CABIN_OFFSET_Y or 0
	return Vector(ufo.X, ufo.Y + oy)
end

function M.mouth_world_pos(txn)
	local pos = M.ufo_world_pos(txn)
	local ml = mouth_local(M.scale())
	return pos + ml
end

function M.beam_mode(txn)
	if dbg.force_beam_mode then
		return dbg.force_beam_mode
	end
	if not txn then return "off" end
	local phase = txn.phase
	if phase == C.PHASE.ARRIVING then
		local open_start = C.BEAM_OPEN_START or 0.78
		if phase_progress(txn) < open_start then
			return "off"
		end
		return "pickup"
	end
	if phase == C.PHASE.ABDUCT_PLAYER then
		return "pickup"
	end
	if phase == C.PHASE.TRANSIT_TO_CENTER then
		return "off"
	end
	if phase == C.PHASE.ABDUCT_TARGETS or phase == C.PHASE.LASER_SWEEP then
		return "work"
	end
	if phase == C.PHASE.RELEASE_PLAYER then
		return "release"
	end
	if phase == C.PHASE.DEPARTING then
		local close_end = C.BEAM_CLOSE_END or 0.35
		if phase_progress(txn) >= close_end then
			return "off"
		end
		return "release"
	end
	return "off"
end

function M.beam_open01(txn)
	local mode = M.beam_mode(txn)
	if mode == "off" then
		return 0
	end
	if not txn then return 0 end
	if txn.phase == C.PHASE.ARRIVING then
		local open_start = C.BEAM_OPEN_START or 0.78
		local p = phase_progress(txn)
		if p < open_start then return 0 end
		return clamp01((p - open_start) / math.max(0.001, 1 - open_start))
	end
	if txn.phase == C.PHASE.DEPARTING then
		local close_end = C.BEAM_CLOSE_END or 0.35
		local p = phase_progress(txn)
		if p >= close_end then return 0 end
		return 1 - clamp01(p / close_end)
	end
	return 1
end

--- Whether player should sandwich between UFO back/front passes.
function M.use_player_sandwich(txn)
	if not txn then return false end
	if txn.phase == C.PHASE.ABDUCT_PLAYER then
		return true
	end
	if txn.phase == C.PHASE.RELEASE_PLAYER and not txn.player_released then
		return true
	end
	return false
end

function M.path_points(txn)
	if not txn then return nil end
	return {
		entry = txn.entry_pos,
		pickup = txn.pickup_hover_pos,
		work = txn.work_hover_pos,
		release = txn.release_hover_pos,
		exit = txn.exit_pos,
		origin = txn.player_origin,
		release_feet = txn.release_pos,
	}
end

function M.depart_ready_to_finish(txn)
	if not txn or txn.phase ~= C.PHASE.DEPARTING then
		return false
	end
	local pos = M.ufo_world_pos(txn)
	local min_frames = 18
	if (txn.phase_frame or 0) < min_frames then
		return false
	end
	if M.is_fully_offscreen(pos, M.scale()) then
		return true
	end
	return (txn.phase_frame or 0) >= (txn.phase_dur or 35)
end

return M
