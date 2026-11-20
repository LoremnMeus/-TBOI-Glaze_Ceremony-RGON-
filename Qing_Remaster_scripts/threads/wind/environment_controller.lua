-- Environment wind controller: BFS distance/dir → WindRuntime.
-- begin_room creates Session; update_room mutates without clearing particles.

local wind = require("Qing_Remaster_scripts.threads.wind.wind_runtime")
local config = require("Qing_Remaster_scripts.threads.wind.environment_config")

local M = {
	own_key = "wind_environment_",
}

local function pack(opts)
	opts = opts or {}
	local distance = opts.distance
	local intensity = opts.intensity
	if intensity == nil then
		intensity = config.distance_to_intensity(distance)
	end
	return {
		kind = "environment",
		distance = distance,
		intensity = intensity,
		dir = opts.dir,
		ang = opts.ang,
		pos = opts.pos,
		mode = opts.mode,
		phase = opts.phase,
		eye_radius_scale = opts.eye_radius_scale,
		physics_enabled = opts.physics_enabled,
		visual_source = opts.visual_source,
		visual_bend = opts.visual_bend,
		room_cells = opts.room_cells,
	}
end

--- First apply for a room / ownership change.
function M.begin_room(opts)
	return wind.begin_environment(pack(opts))
end

--- Continuous updates during cinematic / intensity changes.
function M.update_room(opts)
	return wind.update_environment(pack(opts))
end

-- Backward-compatible name: treat as begin (session init). Prefer begin_room/update_room.
function M.apply_room(opts)
	return M.begin_room(opts)
end

function M.clear()
	wind.clear_environment()
end

function M.pause_for_combat()
	wind.pause_environment_physics()
end

return M
