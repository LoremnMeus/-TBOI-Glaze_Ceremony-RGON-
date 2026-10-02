-- Shared laser utilities for Craft / Aeon: origin relocate + recorded stats / scale.
-- Thickness authority: EntityLaser GetScale/SetScale (RGON). SpriteScale is derived / fallback.
-- Do not invent a third Fire* path; callers still use attack_holder.Fire*.

local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")

local M = {}

local function as_laser(ent)
	if not ent then return nil end
	if ent.ToLaser then
		local laser = ent:ToLaser()
		if laser then return laser end
	end
	return ent
end

--- Emergency / special post-spawn rigid translation of already-initialized beam geometry
--- (Position + Samples + EndPoint).
---
--- Use ONLY when a factory must spawn at the wrong origin (e.g. player Fire* then move to
--- familiar) AND Position alone is proven insufficient.
---
--- NOT for:
--- - Tech X (ring geometry owned by FireTechXLaser)
--- - Lasers already spawned at the target world position (ShootAngle / FireTech* with pos)
--- - Ordinary Aeon replay initialization
function M.relocate_origin(laser, desired)
	laser = as_laser(laser)
	if not laser or not desired then return false end
	local old = laser.Position
	if not old then
		laser.Position = desired
		return true
	end
	local delta = desired - old
	if delta:LengthSquared() < 1e-4 then
		return false
	end
	laser.Position = desired

	local function shift_list(getter)
		if not getter then return end
		local ok, samples = pcall(getter)
		if not ok or not samples or #samples < 1 then return end
		for i = 0, #samples - 1 do
			local v = samples:Get(i)
			if v and v.X ~= nil then
				v.X = v.X + delta.X
				v.Y = v.Y + delta.Y
			end
		end
	end

	if laser.GetSamples then
		shift_list(function() return laser:GetSamples() end)
	end
	if laser.GetNonOptimizedSamples then
		shift_list(function() return laser:GetNonOptimizedSamples() end)
	end
	if laser.EndPoint then
		pcall(function()
			laser.EndPoint = laser.EndPoint + delta
		end)
	end
	return true
end

function M.detach_parent(laser)
	laser = as_laser(laser)
	if not laser then return end
	laser.Parent = nil
	if laser.SetDisableFollowParent then
		pcall(function() laser:SetDisableFollowParent(true) end)
	elseif laser.DisableFollowParent ~= nil then
		laser.DisableFollowParent = true
	end
end

local function read_homing_type(laser)
	if laser.GetHomingType then
		local ok, v = pcall(function() return laser:GetHomingType() end)
		if ok then return tonumber(v) end
	end
	if laser.HomingType ~= nil then
		return tonumber(laser.HomingType)
	end
	return nil
end

--- Probe / debug only. Not Replay authority — do not restore these fields.
function M.capture_motion_fields(laser)
	laser = as_laser(laser)
	if not laser then return nil, nil end
	return read_homing_type(laser), tonumber(laser.CurveStrength)
end

--- RGON EntityLaser thickness authority (internal Scale). SpriteScale is derived.
function M.read_laser_scale(laser)
	laser = as_laser(laser)
	if not laser or not laser.GetScale then
		return nil
	end
	local ok, scale = pcall(function()
		return laser:GetScale()
	end)
	if ok then
		return tonumber(scale)
	end
	return nil
end

--- Factory-level DamageMultiplier (not CollisionDamage). Never invent from player.Damage.
function M.read_damage_multiplier(laser)
	laser = as_laser(laser)
	if not laser or not laser.GetDamageMultiplier then
		return nil
	end
	local ok, value = pcall(function()
		return laser:GetDamageMultiplier()
	end)
	if ok then
		return tonumber(value)
	end
	return nil
end

--- Prefer SetScale (triggers ResetSpriteScale). Never write SetScale then SpriteScale.
--- sprite_scale is legacy / non-RGON fallback only when laser_scale is absent.
--- WARNING: Do not call for factory FireBrimstone / FireTechXLaser replay — SetScale
--- resets factory-initialized beam width via ResetSpriteScale. Technology may still use it.
function M.apply_recorded_laser_scale(laser, base)
	laser = as_laser(laser)
	if not laser then
		return false
	end
	base = type(base) == "table" and base or {}
	local scale = tonumber(base.laser_scale)
	if scale ~= nil then
		if laser.SetScale then
			pcall(function()
				laser:SetScale(scale)
			end)
			return true
		end
		if laser.SpriteScale then
			laser.SpriteScale = Vector(scale, scale)
			return true
		end
		return false
	end
	local ss = base.sprite_scale
	if type(ss) == "table" and laser.SpriteScale then
		laser.SpriteScale = Vector(tonumber(ss.x) or 1, tonumber(ss.y) or 1)
		return true
	end
	return false
end

--- Frozen external laser stats only. Never touch HomingType / CurveStrength.
function M.apply_recorded_laser_stats(laser, base, tear_flags)
	laser = as_laser(laser)
	if not laser then return end
	base = type(base) == "table" and base or {}
	local flags = tear_flags
	if flags == nil and base.tear_flags ~= nil then
		flags = base.tear_flags
	end
	if flags ~= nil and CraftProfile.write_entity_tear_flags then
		CraftProfile.write_entity_tear_flags(laser, flags)
	elseif flags ~= nil and laser.TearFlags ~= nil then
		laser.TearFlags = flags
	end
	if base.collision_damage ~= nil and laser.CollisionDamage ~= nil then
		laser.CollisionDamage = base.collision_damage
	end
	-- DO NOT TOUCH: CurveStrength, HomingType (engine owns Mirror/Homing after factory).
end

--- Legacy alias: stats only (no motion internals).
function M.apply_recorded_exact_motion(laser, base, tear_flags)
	return M.apply_recorded_laser_stats(laser, base, tear_flags)
end

function M.apply_recorded_motion(laser, base, tear_flags)
	return M.apply_recorded_laser_stats(laser, base, tear_flags)
end

function M.apply_variant_skin(laser, variant)
	if CraftProfile.apply_laser_variant_skin then
		return CraftProfile.apply_laser_variant_skin(laser, variant)
	end
	return false
end

function M.apply_stable_position_offset(laser, base, st)
	laser = as_laser(laser)
	if not laser or laser.PositionOffset == nil then return end
	local po = base and base.position_offset
	if type(po) == "table" then
		laser.PositionOffset = Vector(tonumber(po.x) or 0, tonumber(po.y) or 0)
		return
	end
	if st and (st.pox ~= nil or st.dynamic_pox ~= nil) then
		local px = st.dynamic_pox ~= nil and st.dynamic_pox or st.pox
		local py = st.dynamic_poy ~= nil and st.dynamic_poy or st.poy
		laser.PositionOffset = Vector(tonumber(px) or 0, tonumber(py) or 0)
	end
end

function M.reassert_stable_position_offset(laser, stable)
	laser = as_laser(laser)
	if not laser or not stable or laser.PositionOffset == nil then return end
	local cur = laser.PositionOffset
	if (cur - stable):Length() > 0.5 then
		laser.PositionOffset = Vector(stable.X, stable.Y)
	end
end

return M
