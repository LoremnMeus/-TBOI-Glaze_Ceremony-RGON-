-- Environment headwind drag + boss tagged-projectile force.
-- Pure functions / tick helpers. No session ownership.

local env_config = require("Qing_Remaster_scripts.threads.wind.environment_config")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local PROBE_PATH = "Qing_Remaster_scripts.threads.wind.wind_pipeline_probe"
local function probe()
	local mod = package.loaded[PROBE_PATH]
	if type(mod) == "table" and mod.is_listening and mod.is_listening() then
		return mod
	end
	return nil
end

local M = {}

local function clamp01(x)
	return math.max(0, math.min(1, x or 0))
end

function M.wind_blow_dir(ang)
	return auxi.MakeVector((ang or 0) + 90)
end

function M.apply_environment_drag(velocity, wind_dir, intensity)
	if not velocity or velocity:LengthSquared() < 0.0001 then
		return velocity
	end
	if not wind_dir or wind_dir:LengthSquared() < 0.0001 then
		return velocity
	end
	local direction = wind_dir:Normalized()
	local projection = velocity:Dot(direction)
	if projection >= 0 then
		return velocity
	end
	local drag = env_config.drag_ratio(intensity)
	if drag <= 0 then
		return velocity
	end
	local against = direction * projection
	return velocity - against * drag
end

--- Apply player drag for an environment session.
function M.tick_environment(sess, intensity, enable_drag)
	local p = probe()
	local function skip(reason)
		if p and p.note_physics then
			p.note_physics({skip = reason})
		end
	end
	if enable_drag == false then
		skip("enable_drag_false")
		return
	end
	intensity = clamp01(intensity)
	if intensity <= 0.01 then
		skip("intensity_low")
		return
	end
	local blow = M.wind_blow_dir(sess.ang or 0)
	local drag = env_config.drag_ratio(intensity)
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if not (player and player:Exists() and not player:IsDead()) then
			skip("no_player")
		elseif not player:AreControlsEnabled() then
			skip("controls_off")
		elseif player.IsExtraAnimationFinished and not player:IsExtraAnimationFinished() then
			skip("extra_anim")
		else
			local before = player.Velocity
			local before_len2 = before:LengthSquared()
			if before_len2 < 0.0001 then
				skip("stationary")
			else
				local direction = blow:Normalized()
				local projection = before:Dot(direction)
				if projection >= 0 then
					skip("downwind_or_side")
				elseif drag <= 0 then
					skip("drag_zero")
				else
					-- Snapshot scalars first: Velocity userdata may alias across assign.
					local before_snap = {x = before.X, y = before.Y}
					local calculated = M.apply_environment_drag(before, blow, intensity)
					local calc_snap = {x = calculated.X, y = calculated.Y}
					player.Velocity = calculated
					local assigned = player.Velocity
					local after_snap = {x = assigned.X, y = assigned.Y}
					local dx = calc_snap.x - before_snap.x
					local dy = calc_snap.y - before_snap.y
					local calc_delta2 = dx * dx + dy * dy
					local ax = after_snap.x - calc_snap.x
					local ay = after_snap.y - calc_snap.y
					local assign_delta2 = ax * ax + ay * ay
					if p and p.note_physics then
						p.note_physics({
							against_wind = true,
							velocity_changed = calc_delta2 > 1e-8,
							calc_delta2 = calc_delta2,
							assign_delta2 = assign_delta2,
							dot = projection,
							drag = drag,
							before = before_snap,
							calculated = calc_snap,
							after_assignment = after_snap,
						})
					end
				end
			end
		end
	end
end

--- Apply force to projectiles tagged with rate_key.
function M.tick_boss(sess, intensity, rate_key, test_remove_key, try_remove_key)
	intensity = clamp01(intensity)
	if intensity <= 0.01 then return end
	rate_key = rate_key or "Enemies_Zennith_windrate"
	local n_entity = Isaac.GetRoomEntities()
	for i = 1, #n_entity do
		local tent = n_entity[i]
		local td = tent:GetData()
		local rate = td[rate_key]
		if rate then
			local ang = sess.ang or 0
			if sess.pos then
				ang = (sess.pos - tent.Position):GetAngleDegrees() + 90 + (sess.delta_rotation or 0)
			end
			if sess.pos and td[test_remove_key] then
				if (sess.pos - tent.Position):Length() < 80 then
					td[try_remove_key] = true
				end
			end
			local force = 0.055 * intensity * rate
			tent.Velocity = tent.Velocity + M.wind_blow_dir(ang) * force
			local max_spd = 14
			local len = tent.Velocity:Length()
			if len > max_spd then
				tent.Velocity = tent.Velocity:Resized(max_spd)
			end
		end
	end
end

return M
