-- 通用 Tear 快照 / 恢复：优先走 Variant + Flags 让引擎刷新贴图，禁止整 Sprite 硬拷。
local M = {}

local function normalize_angle_deg(a)
	while a > 180 do a = a - 360 end
	while a < -180 do a = a + 360 end
	return a
end

--- opts.aim_dir：用于记录相对散射角（度）
function M.capture(tear, opts)
	if not tear then return nil end
	opts = opts or {}
	local vel = tear.Velocity or Vector(0, 0)
	local speed = vel:Length()
	local relative_angle = 0
	local aim = opts.aim_dir
	if aim and aim:LengthSquared() > 0.001 and speed > 0.01 then
		relative_angle = normalize_angle_deg(vel:GetAngleDegrees() - aim:GetAngleDegrees())
	end
	local sprite_scale = nil
	if tear.SpriteScale then
		sprite_scale = Vector(tear.SpriteScale.X, tear.SpriteScale.Y)
	end
	return {
		damage = tear.CollisionDamage,
		flags = tear.TearFlags,
		variant = tear.Variant,
		scale = tear.Scale,
		sprite_scale = sprite_scale,
		height = tear.Height,
		falling_speed = tear.FallingSpeed,
		falling_accel = tear.FallingAcceleration,
		color = tear.Color,
		speed = speed,
		velocity = Vector(vel.X, vel.Y),
		relative_angle = relative_angle,
		side = nil,
	}
end

--- 先 Variant（引擎重建贴图），再 Flags / 物理量 / Color；ResetSpriteScale 后再恢复 recorded SpriteScale。
function M.apply(tear, snap, opts)
	if not tear or type(snap) ~= "table" then return tear end
	opts = opts or {}

	if snap.variant ~= nil and tear.ChangeVariant and tear.Variant ~= snap.variant then
		pcall(function()
			tear:ChangeVariant(snap.variant)
		end)
	end

	if snap.flags ~= nil then
		tear.TearFlags = snap.flags
	end
	if snap.scale ~= nil then
		tear.Scale = snap.scale
	end
	if snap.height ~= nil then
		tear.Height = snap.height
	end
	if snap.falling_speed ~= nil then
		tear.FallingSpeed = snap.falling_speed
	end
	if snap.falling_accel ~= nil then
		tear.FallingAcceleration = snap.falling_accel
	end
	if snap.color ~= nil then
		tear.Color = snap.color
	end
	if snap.damage ~= nil and opts.skip_damage ~= true then
		tear.CollisionDamage = snap.damage
	end

	if tear.ResetSpriteScale then
		pcall(function()
			tear:ResetSpriteScale(true)
		end)
	end
	-- After ResetSpriteScale: restore recorded visual size if present.
	local ss = snap.sprite_scale
	if ss and tear.SpriteScale then
		local sx, sy
		if type(ss) == "userdata" or (ss.X ~= nil) then
			sx, sy = ss.X, ss.Y
		elseif type(ss) == "table" then
			sx, sy = ss.x or ss[1], ss.y or ss[2]
		end
		if sx ~= nil and sy ~= nil then
			tear.SpriteScale = Vector(tonumber(sx) or 1, tonumber(sy) or 1)
		end
	end
	local spr = tear:GetSprite()
	if spr and spr.LoadGraphics then
		pcall(function()
			spr:LoadGraphics()
		end)
	end

	return tear
end

M.normalize_angle_deg = normalize_angle_deg

return M
