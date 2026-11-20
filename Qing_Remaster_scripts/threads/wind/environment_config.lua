-- Environment wind tuning. Distance is BFS rooms-from-source; intensity is 0–1.
-- Visual V3 budgets are independent from V2 physics drag.

local config = {
	-- Source rooms use intensity 0.75; drag maps that to a full 25% against-wind cut.
	MAX_INTENSITY = 0.75,
	MAX_DRAG = 0.25,
	-- Legacy V2 particle budgets (simultaneous).
	MAIN_MIN = 5,
	MAIN_MAX = 22,
	DUST_MIN = 3,
	DUST_MAX = 12,
	-- Visual V6.2 budgets (simultaneous). Physics unchanged.
	-- AIRFLOW (streak) dominant; GUST few; MOTES (user atlas) secondary.
	STREAK_MIN = 18,
	STREAK_MAX = 26,
	GUST_MIN = 2,
	GUST_MAX = 4,
	VEIL_MIN = 0,
	VEIL_MAX = 2,
	MOTES_MIN = 6,
	MOTES_MAX = 10,
	-- Legacy alias kept for older callers.
	DEBRIS_MIN = 6,
	DEBRIS_MAX = 10,
	EYE_ARC_MIN = 22,
	EYE_ARC_MAX = 36,
	-- Pulse period in Game frames (30 Hz). Visual only; does not change drag.
	PULSE_MIN = 90,
	PULSE_MAX = 210,
	PULSE_BOOST = 0.22,
}

function config.distance_to_intensity(distance)
	distance = tonumber(distance)
	if distance == nil then return 0 end
	if distance <= 0 then return 0.75 end
	if distance <= 1 then return 0.65 end
	if distance <= 3 then return 0.50 end
	if distance <= 5 then return 0.35 end
	if distance <= 10 then return 0.25 end
	if distance >= 26 then return 0 end
	return 0.20
end

function config.drag_ratio(intensity)
	local max_i = config.MAX_INTENSITY
	if max_i <= 0 then return 0 end
	local t = math.max(0, math.min(1, (tonumber(intensity) or 0) / max_i))
	return t * config.MAX_DRAG
end

function config.main_budget(intensity)
	local t = math.max(0, math.min(1, tonumber(intensity) or 0))
	return math.floor(config.MAIN_MIN + t * (config.MAIN_MAX - config.MAIN_MIN) + 0.5)
end

function config.dust_budget(intensity)
	local t = math.max(0, math.min(1, tonumber(intensity) or 0))
	return math.floor(config.DUST_MIN + t * (config.DUST_MAX - config.DUST_MIN) + 0.5)
end

local function lerp_budget(lo, hi, intensity)
	local t = math.max(0, math.min(1, tonumber(intensity) or 0))
	return math.floor(lo + t * (hi - lo) + 0.5)
end

function config.streak_budget(intensity)
	return lerp_budget(config.STREAK_MIN, config.STREAK_MAX, intensity)
end

function config.gust_budget(intensity)
	return lerp_budget(config.GUST_MIN, config.GUST_MAX, intensity)
end

function config.veil_budget(intensity)
	return lerp_budget(config.VEIL_MIN, config.VEIL_MAX, intensity)
end

function config.motes_budget(intensity)
	return lerp_budget(config.MOTES_MIN or 6, config.MOTES_MAX or 10, intensity)
end

function config.debris_budget(intensity)
	-- Legacy name → motes.
	return config.motes_budget(intensity)
end

function config.eye_arc_budget(intensity)
	return lerp_budget(config.EYE_ARC_MIN, config.EYE_ARC_MAX, intensity)
end

return config
