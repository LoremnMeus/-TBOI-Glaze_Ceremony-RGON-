-- Off-screen wind particle lifetime. No Isaac API.
-- Incoming streaks may be born outside the simulation rect and must not be
-- recycled until they have been visible, or until ENTRY_TIMEOUT expires.

local M = {}

-- Game frames @ 30Hz. Covers a wide room's short-axis upwind gap at intensity 0.25.
M.ENTRY_TIMEOUT = 64
M.SIM_MARGIN = 56
M.UPWIND_MARGIN_EXTRA = 12
-- Slow end of airflow spawn jitter and directional gust_mul.
M.AIRFLOW_SPAWN_FLOOR = 0.94
M.AIRFLOW_GUST_FLOOR = 0.95

function M.incoming_expired(p, timeout)
	timeout = timeout or M.ENTRY_TIMEOUT
	if not p or p.was_visible then return false end
	if (p.life_state or "incoming") ~= "incoming" then return false end
	return (p.age or 0) > timeout
end

--- Outside-sim decision for AIRFLOW / GUST streaks.
-- "keep" includes an incoming particle that has not yet reached the screen.
function M.streak_outside_decision(p, outside_sim, timeout)
	if not outside_sim then return "keep" end
	if p and p.was_visible then return "natural_exit" end
	if M.incoming_expired(p, timeout) then return "entry_timeout" end
	return "keep"
end

--- MOTES keep their own rule: outside does not remove an incoming mote early.
function M.mote_decision(p, outside_sim, in_view, timeout)
	p = p or {}
	local state = p.life_state or (p.was_visible and "visible" or "incoming")
	if state == "incoming" and not p.was_visible then
		if in_view then return "enter" end
		if (p.age or 0) > (timeout or M.ENTRY_TIMEOUT) then return "entry_timeout" end
		return "keep"
	end
	if outside_sim then return "natural_exit" end
	if in_view then return "visible" end
	return "keep"
end

function M.room_should_clear(particle_sgid, current_sgid)
	return particle_sgid ~= current_sgid
end

function M.upwind_along(span_x, span_y)
	return math.max(span_x, span_y) * 0.52 + M.SIM_MARGIN + M.UPWIND_MARGIN_EXTRA
end

--- On-axis pixels from an upwind birth to the near view edge.
-- blow_axis is "x" or "y": the axis the wind travels along.
function M.upwind_view_gap(span_x, span_y, blow_axis)
	local along = M.upwind_along(span_x, span_y)
	local span_along = blow_axis == "y" and span_y or span_x
	return math.max(0, along - span_along * 0.5)
end

function M.airflow_min_speed(intensity)
	return (9 + intensity * 6) * M.AIRFLOW_SPAWN_FLOOR * M.AIRFLOW_GUST_FLOOR
end

function M.entry_frames(distance, speed)
	if not speed or speed <= 0 then return math.huge end
	return distance / speed
end

function M.timeout_covers(distance, speed, timeout)
	return M.entry_frames(distance, speed) <= (timeout or M.ENTRY_TIMEOUT)
end

return M
