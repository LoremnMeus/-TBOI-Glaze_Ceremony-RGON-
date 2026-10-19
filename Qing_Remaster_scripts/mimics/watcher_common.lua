-- Shared Watcher math / phase enums for player Watcher + Craft Watcher Network.
-- Visual ownership stays in Item_The_Watcher / Craft_Watcher_holder.

local M = {}

M.PHASE = {
	DORMANT = "DORMANT",
	AWAKE = "AWAKE",
	TRACKING = "TRACKING",
	WARNING = "WARNING",
	CRITICAL = "CRITICAL",
	CONFIRMING = "CONFIRMING",
	FIRING = "FIRING",
	RELEASING = "RELEASING",
	CLOSING = "CLOSING",
}

M.TRACK = {
	SPAWN = "SPAWN",
	TRAVEL = "TRAVEL",
	LAND = "LAND",
	LOCK = "LOCK",
	CONFIRM = "CONFIRM",
	LOCKED = "LOCKED",
	FADE = "FADE",
	RETRACT = "RETRACT",
	SHATTER = "SHATTER",
}

function M.clamp01(x)
	x = tonumber(x) or 0
	if x < 0 then return 0 end
	if x > 1 then return 1 end
	return x
end

function M.lerp(a, b, t)
	return a + (b - a) * M.clamp01(t)
end

function M.lerp_vec(a, b, t)
	t = M.clamp01(t)
	return Vector(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t)
end

function M.smoothstep(t)
	t = M.clamp01(t)
	return t * t * (3 - 2 * t)
end

function M.ease_out_cubic(t)
	t = M.clamp01(t)
	local u = 1 - t
	return 1 - u * u * u
end

function M.lock_speed_mul(dist, distance_max)
	distance_max = tonumber(distance_max) or 195
	dist = tonumber(dist) or 9999
	if dist <= 90 then
		return 1.25
	elseif dist <= 130 then
		return 1.0
	elseif dist <= 165 then
		return 0.7
	elseif dist <= distance_max + 8 then
		return 0.45
	end
	return 0
end

--- Node counter ratio → acquisition radius (same curve as player Watcher).
function M.acquisition_range(counter, player_limit, cfg, frozen_acq)
	if frozen_acq then return frozen_acq end
	cfg = cfg or {}
	local lim = math.max(1, tonumber(player_limit) or 240)
	local t = M.clamp01((tonumber(counter) or 0) / lim)
	local dmin = tonumber(cfg.distance_min) or 110
	local dmax = tonumber(cfg.distance_max) or 195
	if t <= 0.25 then
		return M.lerp(dmin, 140, t / 0.25)
	elseif t <= 0.5 then
		return M.lerp(140, 165, (t - 0.25) / 0.25)
	elseif t <= 0.75 then
		return M.lerp(165, 185, (t - 0.5) / 0.25)
	end
	return M.lerp(185, dmax, (t - 0.75) / 0.25)
end

function M.retention_range(acq, retention_mul)
	return (tonumber(acq) or 110) * (tonumber(retention_mul) or 1.35)
end

function M.phase_from_ratio(ratio)
	ratio = M.clamp01(ratio)
	if ratio >= 0.8 then return M.PHASE.CRITICAL end
	if ratio >= 0.5 then return M.PHASE.WARNING end
	if ratio > 0 then return M.PHASE.TRACKING end
	return M.PHASE.DORMANT
end

function M.track_is_fire_locked(tr)
	if not tr then return false end
	local p = tr.phase
	return p == M.TRACK.CONFIRM or p == M.TRACK.LOCKED or p == M.TRACK.FADE
end

function M.filter_pos(prev, cur, rate)
	if not cur then return prev end
	if not prev then return Vector(cur.X, cur.Y) end
	rate = tonumber(rate) or 0.25
	return Vector(
		prev.X + (cur.X - prev.X) * rate,
		prev.Y + (cur.Y - prev.Y) * rate
	)
end

return M
