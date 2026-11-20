-- Boss combat wind controller. Visual + tagged projectile motion only.
-- Does not apply continuous player push.

local wind = require("Qing_Remaster_scripts.threads.wind.wind_runtime")

local M = {
	own_key = "boss_wind_",
}

local function intensity_from_legacy_power(power)
	power = tonumber(power) or 2
	return math.max(0.2, math.min(1, 0.2 + power * 0.12))
end

function M.set_direction(opts)
	opts = opts or {}
	local cfg = {
		kind = "boss",
		mode = 1,
		ang = opts.ang,
		dir = opts.dir,
		intensity = opts.intensity or intensity_from_legacy_power(opts.power),
		power = opts.power,
		phase = "combat",
	}
	if wind.session and wind.session.kind == "boss" then
		return wind.update_boss(cfg)
	end
	return wind.begin_boss(cfg)
end

function M.set_vortex(opts)
	opts = opts or {}
	local cfg = {
		kind = "boss",
		mode = opts.ent and 3 or 2,
		ent = opts.ent,
		pos = opts.pos,
		delta_rotation = opts.delta_rotation,
		delta_pos = opts.delta_pos,
		intensity = opts.intensity or intensity_from_legacy_power(opts.power),
		power = opts.power,
		phase = "combat",
	}
	if wind.session and wind.session.kind == "boss" then
		return wind.update_boss(cfg)
	end
	return wind.begin_boss(cfg)
end

function M.pulse(opts)
	wind.pulse_boss(opts or {})
end

--- Keep the boss wind session alive at low intensity between attacks.
function M.set_ambient(opts)
	opts = opts or {}
	return M.set_direction({
		ang = opts.ang,
		dir = opts.dir,
		intensity = opts.intensity or 0.22,
		power = opts.power,
	})
end

function M.clear()
	wind.clear_boss()
end

function M.fade_out()
	wind.fade_out_visuals()
end

return M
