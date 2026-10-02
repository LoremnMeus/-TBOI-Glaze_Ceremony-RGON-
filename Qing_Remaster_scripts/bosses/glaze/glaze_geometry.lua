-- Pure, preset geometry. All arguments/returns are world-space vectors.
local M = {}

function M.reflect_velocity(v, orientation)
	if orientation == "VERTICAL" then return Vector(-v.X, v.Y) end
	if orientation == "HORIZONTAL" then return Vector(v.X, -v.Y) end
	if orientation == "DIAGONAL_A" then return Vector(v.Y, v.X) end
	if orientation == "DIAGONAL_B" then return Vector(-v.Y, -v.X) end
	error("Unknown Glaze mirror orientation: " .. tostring(orientation))
end

function M.mirror_position(p, center)
	return Vector(2 * center.X - p.X, p.Y)
end

function M.segment_distance(p, a, b)
	local delta = b - a
	local length2 = delta.X * delta.X + delta.Y * delta.Y
	if length2 < 0.0001 then return p:Distance(a) end
	local rel = p - a
	local t = math.max(0, math.min(1, (rel.X * delta.X + rel.Y * delta.Y) / length2))
	return p:Distance(a + delta * t)
end

function M.position(room, name)
	local c = room:GetCenterPos()
	local tl, br = room:GetTopLeftPos(), room:GetBottomRightPos()
	local x, y = math.min(150, (br.X - tl.X) * .25), math.min(90, (br.Y - tl.Y) * .25)
	local offsets = {
		CENTER = Vector.Zero, TOP = Vector(0, -y), LEFT = Vector(-x, 0), RIGHT = Vector(x, 0),
		TOP_LEFT = Vector(-x, -y), TOP_RIGHT = Vector(x, -y),
		BOTTOM_LEFT = Vector(-x, y), BOTTOM_RIGHT = Vector(x, y),
	}
	return room:GetClampedPosition(c + assert(offsets[name], name), 40)
end

function M.direction(a, b)
	local v = b - a
	return v:Length() > .001 and v:Normalized() or Vector(0, 1)
end

return M
