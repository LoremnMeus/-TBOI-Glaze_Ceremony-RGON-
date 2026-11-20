-- Per-kind motion curves for chess pieces.
-- Ground Position = collision / board path; PositionOffset height is visual only.

local defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")

local motion = {}

local function clamp01(t)
	if t < 0 then return 0 end
	if t > 1 then return 1 end
	return t
end

function motion.ease_out_cubic(t)
	t = clamp01(t)
	local u = 1 - t
	return 1 - u * u * u
end

function motion.ease_in_cubic(t)
	t = clamp01(t)
	return t * t * t
end

function motion.ease_in_out(t)
	t = clamp01(t)
	if t < 0.5 then
		return 2 * t * t
	end
	return 1 - ((-2 * t + 2) ^ 2) / 2
end

-- Vehicle: slow windup then fast dash along the path.
function motion.ease_charge(t)
	t = clamp01(t)
	if t < 0.25 then
		return (t / 0.25) * 0.08
	end
	local u = (t - 0.25) / 0.75
	return 0.08 + 0.92 * (u * u)
end

-- Queen: smooth fast glide.
function motion.ease_glide(t)
	return motion.ease_in_out(t)
end

-- Bishop: near-linear slide with soft ends.
function motion.ease_slide(t)
	t = clamp01(t)
	return t * t * (3 - 2 * t)
end

--- Knight leap: fast rise, brief hang, fast fall (not a plain sine).
function motion.knight_leap_height(t)
	t = clamp01(t)
	local peak = 35
	if t < 0.35 then
		local u = t / 0.35
		return peak * motion.ease_out_cubic(u)
	elseif t < 0.55 then
		return peak
	else
		local u = (t - 0.55) / 0.45
		return peak * (1 - motion.ease_in_cubic(u))
	end
end

--- Height by motion kind. Never use a single sine for every piece.
function motion.height_for_motion(kind_motion, t, phase)
	t = clamp01(t)
	kind_motion = kind_motion or "short_hop"
	if phase == "WINDUP" then
		if kind_motion == "short_hop" then
			return -3 * t -- crouch
		elseif kind_motion == "high_leap" then
			return -4 * t
		elseif kind_motion == "heavy_step" then
			return -5 * t
		elseif kind_motion == "tilt_dash" then
			return 0
		end
		return 0
	end
	if phase == "LANDING" then
		if kind_motion == "high_leap" then
			return 3 * (1 - t)
		elseif kind_motion == "heavy_step" then
			return 2 * (1 - t)
		elseif kind_motion == "short_hop" then
			return 1.5 * (1 - t)
		end
		return 0
	end
	if phase ~= "MOVING" and phase ~= "ATTACKING" and phase ~= "TRAVEL" then
		return 0
	end
	if kind_motion == "short_hop" then
		return 15 * math.sin(math.pi * t)
	elseif kind_motion == "high_leap" then
		return motion.knight_leap_height(t)
	elseif kind_motion == "heavy_step" then
		return 5 * math.sin(math.pi * t)
	elseif kind_motion == "diag_slide" then
		return 2 * math.sin(math.pi * t)
	elseif kind_motion == "glide" or kind_motion == "tilt_dash" then
		return 0
	end
	return 0
end

function motion.tilt_for(profile, kind_motion, phase, t, facing)
	local max_tilt = (profile and profile.tilt_max) or 6
	local dir = 1
	if facing and facing.X < 0 then dir = -1 end
	t = clamp01(t)
	kind_motion = kind_motion or "short_hop"

	if kind_motion == "tilt_dash" then
		-- Vehicle: lean back on windup, lean into the dash, snap upright.
		if phase == "WINDUP" then
			return -max_tilt * dir * motion.ease_out_cubic(t)
		elseif phase == "MOVING" or phase == "ATTACKING" then
			return max_tilt * 0.9 * dir * (1 - t * 0.25)
		elseif phase == "LANDING" or phase == "RECOVERY" then
			return max_tilt * 0.35 * dir * (1 - t)
		end
	elseif kind_motion == "diag_slide" then
		if phase == "WINDUP" then
			return max_tilt * 0.35 * dir * t
		elseif phase == "MOVING" or phase == "ATTACKING" then
			return max_tilt * 0.55 * dir
		elseif phase == "LANDING" then
			return max_tilt * 0.25 * dir * (1 - t)
		end
	elseif kind_motion == "glide" then
		if phase == "WINDUP" then
			return max_tilt * 0.25 * dir * t
		elseif phase == "MOVING" or phase == "ATTACKING" then
			return max_tilt * 0.35 * dir * math.sin(math.pi * t)
		elseif phase == "LANDING" then
			return max_tilt * 0.15 * dir * (1 - t)
		end
	elseif kind_motion == "high_leap" then
		if phase == "WINDUP" then
			return -max_tilt * 0.55 * dir * t -- lean back
		elseif phase == "MOVING" or phase == "ATTACKING" then
			return max_tilt * 0.25 * dir
		elseif phase == "LANDING" then
			return max_tilt * 0.2 * dir * (1 - t)
		end
	elseif kind_motion == "heavy_step" then
		if phase == "WINDUP" then
			return 0
		elseif phase == "MOVING" or phase == "ATTACKING" then
			return max_tilt * 0.3 * dir * math.sin(math.pi * t)
		end
	elseif kind_motion == "short_hop" then
		if phase == "MOVING" or phase == "ATTACKING" then
			return max_tilt * 0.35 * dir * math.sin(math.pi * t)
		end
	end
	return 0
end

function motion.path_ease(kind_motion, t)
	kind_motion = kind_motion or "short_hop"
	if kind_motion == "tilt_dash" then
		return motion.ease_charge(t)
	elseif kind_motion == "short_hop" then
		-- Front-loaded acceleration.
		return motion.ease_out_cubic(t)
	elseif kind_motion == "heavy_step" then
		return motion.ease_in_out(t)
	elseif kind_motion == "high_leap" then
		return motion.ease_in_out(t)
	elseif kind_motion == "diag_slide" then
		return motion.ease_slide(t)
	elseif kind_motion == "glide" then
		return motion.ease_glide(t)
	end
	return motion.ease_in_out(t)
end

--- Horizontal board path is linear (fast, even dash). Height/tilt keep per-kind curves.
function motion.sample(profile, start_pos, end_pos, t, phase)
	profile = profile or defs.get(defs.KIND.PAWN)
	local kind_motion = profile.motion or "short_hop"
	t = clamp01(t)
	local pos = start_pos + (end_pos - start_pos) * t
	local height = motion.height_for_motion(kind_motion, t, phase)
	local facing = end_pos - start_pos
	local tilt = motion.tilt_for(profile, kind_motion, phase, t, facing)
	return pos, height, tilt
end

function motion.lerp_frames(elapsed, total)
	total = math.max(1, total or 1)
	return clamp01(elapsed / total)
end

return motion
