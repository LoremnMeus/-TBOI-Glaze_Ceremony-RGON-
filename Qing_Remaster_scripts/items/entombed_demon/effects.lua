-- Screen-space ritual brush. All coordinates are HistoryHUD/UI pixels.
local M = {}

local function line(a, b, color, width)
	if Isaac.DrawLine then Isaac.DrawLine(a, b, color, color, math.max(1, math.floor(width + 0.5))) end
end

local function point(a, b, t, bend)
	local mid = (a + b) * 0.5 + Vector(0, bend)
	local inv = 1 - t
	return a * (inv * inv) + mid * (2 * inv * t) + b * (t * t)
end

function M.hand(a, b, extent, width, bend, claw)
	if not a or not b or extent <= 0 then return end
	local black = KColor(0.07, 0.025, 0.035, 0.94)
	local inner = KColor(0.36, 0.045, 0.07, 0.36)
	local steps = math.max(2, math.ceil(14 * extent))
	for i = 1, steps do
		local t0, t1 = extent * (i - 1) / steps, extent * i / steps
		local from, to = point(a, b, t0, bend), point(a, b, t1, bend)
		line(from, to, black, width * (1 - 0.52 * t0))
		line(from, to, inner, math.max(1, width * 0.28))
	end
	local tip = point(a, b, extent, bend)
	if claw then
		local direction = (b - a):Normalized()
		local normal = Vector(-direction.Y, direction.X)
		for i = -1, 1 do
			local finger = tip + direction * (5 + (i == 0 and 2 or 0)) + normal * i * 3
			line(tip, finger, black, math.max(1, width * 0.32))
		end
	end
	return tip
end

function M.orb(pos, diameter, tick, alpha)
	if not pos or alpha <= 0 then return end
	local radius = diameter * 0.5
	local outer = KColor(0.035, 0.015, 0.02, alpha)
	local core = KColor(0.48, 0.045, 0.07, alpha * 0.82)
	local points = {}
	for i = 0, 11 do
		local angle = (i / 12) * math.pi * 2 + tick * 0.09
		local r = radius * (1 + 0.12 * math.sin(i * 4 + tick * 0.13))
		points[i + 1] = pos + Vector(math.cos(angle) * r, math.sin(angle) * r)
	end
	for i = 1, 12 do line(points[i], points[i % 12 + 1], outer, 2) end
	line(pos + Vector(-radius * 0.55, 0), pos + Vector(radius * 0.55, 0), core, radius * 0.7)
end

function M.smoke(sprite, pos, trail, diameter, age, foreground, opacity, origin)
	if not sprite then return end
	for i = 1, (foreground and 2 or 4) do
		local base = foreground and pos or (trail and trail[i]) or pos
		local spread = foreground and 0.18 or 0.26
		local jitter = Vector(math.sin(age * 0.31 + i * 2.4), math.cos(age * 0.23 + i * 1.8)) * diameter * spread
		local center = base + jitter
		if origin then
			local travel = pos - origin
			if travel:Length() < 0.5 then
				center = origin
			else
				local direction = travel:Normalized()
				local behind = (center - origin):Dot(direction)
				if behind < 0 then center = center - direction * behind end
			end
			center = Vector(center.X, math.min(center.Y, math.max(origin.Y, pos.Y)))
		end
		local alpha = (foreground and (0.38 + i * 0.09) or (0.62 - i * 0.07)) * (opacity or 1)
		sprite:SetFrame("Clouds", (math.floor(age * 0.2) + i * 3) % 8)
		sprite.Scale = Vector(1, 1) * (diameter / 32) * (foreground and 1.25 or 1.45)
		sprite.Color = i % 2 == 0 and Color(0.48, 0.035, 0.06, alpha)
			or Color(0.075, 0.018, 0.025, alpha)
		sprite:Render(center, Vector.Zero, Vector.Zero)
	end
end

return M
