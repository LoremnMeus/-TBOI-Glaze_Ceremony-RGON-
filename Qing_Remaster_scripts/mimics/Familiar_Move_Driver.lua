-- 原版 AI 后的 familiar 强驱动公共原语。
-- 以 My Emblem 的已验证实现为唯一信源；需要同类行为的控制器必须调用这里，禁止复制近似弹簧。
local driver = {}

function driver.drive_to_position(ent, target, target_velocity, options)
	if not ent or not target then return end
	options = options or {}
	local min_speed = tonumber(options.min_speed) or 10
	local speed_gain = tonumber(options.speed_gain) or 0.35
	local speed_margin = tonumber(options.speed_margin) or 12
	local reach_distance = tonumber(options.reach_distance) or 14

	if ent.FollowPosition then
		ent:FollowPosition(target)
	end
	local delta = target - ent.Position
	local dist = delta:Length()
	if dist > 0.1 then
		local current_speed = ent.Velocity:Length()
		local speed
		local blend = 0.55
		if target_velocity then
			local target_speed = target_velocity:Length()
			speed = math.max(target_speed, dist * speed_gain)
			if dist > reach_distance * 2 then
				speed = math.max(min_speed, speed)
			end
			speed = math.min(speed, current_speed + speed_margin)
			if dist <= reach_distance * 2 then
				blend = 0.7
			end
		else
			speed = math.max(min_speed, current_speed)
			speed = math.min(math.max(speed, dist * speed_gain), current_speed + speed_margin)
		end
		local desired_velocity = delta:Normalized() * speed
		if target_velocity and dist <= reach_distance * 2 then
			local proximity = math.max(0, 1 - dist / (reach_distance * 2))
			desired_velocity = desired_velocity * (1 - proximity) + target_velocity * proximity
		end
		ent.Velocity = ent.Velocity * (1 - blend) + desired_velocity * blend
	elseif target_velocity then
		ent.Velocity = ent.Velocity * 0.3 + target_velocity * 0.7
	end
end

return driver
