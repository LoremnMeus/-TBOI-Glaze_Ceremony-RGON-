-- Alien Savior assembled tech-laser renderer (body / tip / muzzle).
-- Visual length is screen-exit based; collision stays on EntityLaser.
local C = require("Qing_Remaster_scripts.items.alien_savior.constants")

local LV = {}

local ANM2 = "gfx/mimics/Alien_savior/laser/alien_tech_laser.anm2"
local BODY_NATIVE_H = 64
local LAYER_BODY = 0
local LAYER_TIP = 1
local LAYER_MUZZLE = 2
local MAX_WORLD_LEN = 2400

local sprite = nil
local load_ok = false

local function cfg()
	return C.LASER or {}
end

local function clamp01(x)
	if x < 0 then
		return 0
	end
	if x > 1 then
		return 1
	end
	return x
end

local function world_to_render(pos)
	local room = Game():GetRoom()
	if room and room.WorldToScreenPosition then
		return room:WorldToScreenPosition(pos)
	end
	return Isaac.WorldToScreen(pos)
end

local function ensure_sprite()
	if sprite and load_ok then
		return sprite
	end
	sprite = Sprite()
	local path = (cfg().VISUAL_ANM2) or ANM2
	sprite:Load(path, true)
	if sprite.Play then
		sprite:Play("Idle", true)
	end
	load_ok = true
	return sprite
end

--- Tint + Offset + Colorize with brightness / alpha multipliers.
function LV.build_color(spec, alpha_mul, bright_mul)
	spec = spec or {}
	alpha_mul = alpha_mul or 1
	bright_mul = bright_mul or 1
	local r = (spec.r ~= nil and spec.r or 1) * bright_mul
	local g = (spec.g ~= nil and spec.g or 1) * bright_mul
	local b = (spec.b ~= nil and spec.b or 1) * bright_mul
	local a = (spec.a ~= nil and spec.a or 1) * alpha_mul
	local ro = (spec.ro ~= nil and spec.ro or 0) * bright_mul
	local go = (spec.go ~= nil and spec.go or 0) * bright_mul
	local bo = (spec.bo ~= nil and spec.bo or 0) * bright_mul
	local col = Color(
		clamp01(r),
		clamp01(g),
		clamp01(b),
		clamp01(a),
		math.min(1, ro),
		math.min(1, go),
		math.min(1, bo)
	)
	if col.SetColorize then
		col:SetColorize(
			spec.cr ~= nil and spec.cr or 0,
			spec.cg ~= nil and spec.cg or 0,
			spec.cb ~= nil and spec.cb or 0,
			spec.amount ~= nil and spec.amount or 0
		)
	end
	return col
end

local function reset_sprite(sp)
	sp.Scale = Vector(1, 1)
	sp.Rotation = 0
	sp.Color = Color(1, 1, 1, 1, 0, 0, 0)
	if sp.Color.SetColorize then
		sp.Color:SetColorize(0, 0, 0, 0)
	end
end

local function render_layer(sp, layer_id, screen, rotation, sx, sy, color)
	if not sp.RenderLayer then
		return
	end
	sp.Rotation = rotation
	sp.Scale = Vector(sx, sy)
	sp.Color = color
	sp:RenderLayer(layer_id, screen)
end

--- Ray vs AABB slab. Returns t_enter, t_exit (may be -inf/+inf). Nil if miss.
local function ray_aabb(ox, oy, dx, dy, minx, miny, maxx, maxy)
	local t0, t1 = -math.huge, math.huge
	-- X slab
	if math.abs(dx) < 1e-8 then
		if ox < minx or ox > maxx then
			return nil, nil
		end
	else
		local inv = 1 / dx
		local a = (minx - ox) * inv
		local b = (maxx - ox) * inv
		if a > b then
			a, b = b, a
		end
		t0 = math.max(t0, a)
		t1 = math.min(t1, b)
		if t0 > t1 then
			return nil, nil
		end
	end
	-- Y slab
	if math.abs(dy) < 1e-8 then
		if oy < miny or oy > maxy then
			return nil, nil
		end
	else
		local inv = 1 / dy
		local a = (miny - oy) * inv
		local b = (maxy - oy) * inv
		if a > b then
			a, b = b, a
		end
		t0 = math.max(t0, a)
		t1 = math.min(t1, b)
		if t0 > t1 then
			return nil, nil
		end
	end
	return t0, t1
end

--- World-space length from origin along angle to leave the visible screen + overshoot.
--- Returns length, screen_exit_px (distance along screen ray to exit before overshoot).
function LV.screen_exit_distance(origin, angle_deg)
	if not origin then
		return 400, 0
	end
	local overshoot = (cfg().VISUAL_SCREEN_OVERSHOOT_PX) or 72
	local sw = (Isaac.GetScreenWidth and Isaac.GetScreenWidth()) or 480
	local sh = (Isaac.GetScreenHeight and Isaac.GetScreenHeight()) or 270
	local s0 = world_to_render(origin)
	local rad = math.rad(angle_deg or 0)
	local dir = Vector(math.cos(rad), math.sin(rad))
	-- Probe world→screen scale along the fire direction.
	local probe = 48
	local s1 = world_to_render(origin + dir * probe)
	local sdx = s1.X - s0.X
	local sdy = s1.Y - s0.Y
	local slen = math.sqrt(sdx * sdx + sdy * sdy)
	if slen < 1e-4 then
		return math.min(MAX_WORLD_LEN, 500), 0
	end
	local sdirx = sdx / slen
	local sdiry = sdy / slen
	local world_per_screen = probe / slen

	local t_enter, t_exit = ray_aabb(s0.X, s0.Y, sdirx, sdiry, 0, 0, sw, sh)
	local screen_exit = 0
	if not t_exit then
		-- Ray misses the visible rect entirely — still draw a short stub.
		screen_exit = overshoot
	elseif t_exit < 0 then
		-- Entirely behind the ray origin relative to the box.
		screen_exit = overshoot
	else
		-- If origin is outside, start measuring from max(0, t_enter) visually,
		-- but length from origin still goes through the screen to exit + overshoot.
		screen_exit = t_exit + overshoot
		if screen_exit < overshoot then
			screen_exit = overshoot
		end
	end
	local world_len = screen_exit * world_per_screen
	if world_len < 24 then
		world_len = 24
	end
	if world_len > MAX_WORLD_LEN then
		world_len = MAX_WORLD_LEN
	end
	return world_len, screen_exit
end

--- Length fraction + alpha for extend/hold/retract lifecycle.
--- Returns length01, alpha01, state, extend_progress, retract_progress.
function LV.laser_reveal(age, duration, extend_f, retract_f)
	age = math.max(0, age or 0)
	duration = math.max(1, duration or 1)
	extend_f = math.max(1, extend_f or 5)
	retract_f = math.max(1, retract_f or 7)
	if age < extend_f then
		local t = clamp01(age / extend_f)
		local len = 1 - (1 - t) ^ 3
		return len, 1, "extending", t, 0
	end
	local retract_start = duration - retract_f
	if age >= retract_start then
		local t = clamp01((age - retract_start) / retract_f)
		local len = (1 - t) ^ 2
		local alpha = 1 - t
		return len, alpha, "retracting", 1, t
	end
	return 1, 1, "stable", 1, 0
end

local function collision_length(laser)
	if not laser then
		return 0
	end
	if laser.LaserLength and laser.LaserLength > 0 then
		return laser.LaserLength
	end
	local samples = laser.GetSamples and laser:GetSamples()
	if samples and samples.Size and samples.Size >= 2 and samples.Get then
		local a = samples:Get(0)
		local b = samples:Get(samples.Size - 1)
		if a and b then
			return (b - a):Length()
		end
	end
	return 0
end

--- Draw one beam using visual_current_length along angle (not GetSamples truncate).
function LV.render(spec)
	if not spec or not spec.active then
		return
	end
	local vis_len = spec.visual_current_length or 0
	if vis_len < 0.5 then
		-- Still draw muzzle during earliest extend if requested.
		if (spec.muzzle_always or (spec.visual_age or 0) > 0) and (spec.alpha_multiplier or 1) > 0.02 then
			local sp = ensure_sprite()
			if sp then
				local muzzle_col = LV.build_color(
					spec.color_spec,
					(spec.alpha_multiplier or 1) * 1.1,
					(spec.brightness_multiplier or 1) * 1.25
				)
				local origin = spec.origin
				if origin then
					render_layer(
						sp,
						LAYER_MUZZLE,
						world_to_render(origin),
						(spec.angle or 0) - 90,
						(spec.width_scale or 1) * 0.95,
						(spec.width_scale or 1) * 0.95,
						muzzle_col
					)
					reset_sprite(sp)
				end
			end
		end
		return
	end

	local sp = ensure_sprite()
	if not sp then
		return
	end
	local color = LV.build_color(
		spec.color_spec,
		spec.alpha_multiplier or 1,
		spec.brightness_multiplier or 1
	)
	local w = spec.width_scale or 1
	local origin = spec.origin
	if not origin then
		return
	end
	local ang = spec.angle or 0
	local rad = math.rad(ang)
	local dir = Vector(math.cos(rad), math.sin(rad))

	-- Tile body in fixed native chunks; last segment scaled to remainder.
	local drawn = 0
	while drawn < vis_len - 0.25 do
		local remain = vis_len - drawn
		local seg = math.min(BODY_NATIVE_H, remain)
		local a = origin + dir * drawn
		render_layer(
			sp,
			LAYER_BODY,
			world_to_render(a),
			ang - 90,
			w,
			math.max(0.05, seg / BODY_NATIVE_H),
			color
		)
		drawn = drawn + seg
	end

	-- Tip at current visible front.
	local tip_pos = origin + dir * vis_len
	local tip_bright = LV.build_color(
		spec.color_spec,
		(spec.alpha_multiplier or 1) * 1.05,
		(spec.brightness_multiplier or 1) * 1.1
	)
	render_layer(
		sp,
		LAYER_TIP,
		world_to_render(tip_pos),
		ang - 90,
		w * 1.05,
		1.0,
		tip_bright
	)

	-- Muzzle at emitter (covers hard root).
	local muzzle_col = LV.build_color(
		spec.color_spec,
		(spec.alpha_multiplier or 1) * 1.1,
		(spec.brightness_multiplier or 1) * 1.25
	)
	render_layer(
		sp,
		LAYER_MUZZLE,
		world_to_render(origin),
		ang - 90,
		w * 0.95,
		w * 0.95,
		muzzle_col
	)

	reset_sprite(sp)
end

function LV.collision_length(laser)
	return collision_length(laser)
end

function LV.invalidate()
	sprite = nil
	load_ok = false
end

return LV
