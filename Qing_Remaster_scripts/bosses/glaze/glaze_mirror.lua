local G = require("Qing_Remaster_scripts.bosses.glaze.glaze_geometry")
local P = require("Qing_Remaster_scripts.bosses.glaze.glaze_placeholder")
local M = {reflect_velocity = G.reflect_velocity, mirror_position = G.mirror_position}

function M.spawn(ctx, pos, orientation, lifetime, kind)
	local obj = P.spawn(ctx, kind or "MIRROR", pos, {lifetime = lifetime, label = (kind or "MIRROR") .. " " .. orientation})
	obj.orientation, obj.radius = orientation, 19
	obj.direction = G.reflect_velocity(G.direction(ctx.boss.Position, pos), orientation)
	ctx.mirrors[obj.id] = obj
	return obj
end

function M.field(ctx, pos, half, angle, delay, lifetime)
	if ctx.field then P.remove(ctx, ctx.field) end
	local obj = P.spawn(ctx, "GLAZE FIELD", pos, {lifetime = delay + lifetime})
	obj.half, obj.angle, obj.active_at = half, angle, ctx.clock + delay
	ctx.field = obj
	local a, b = pos - half, pos + half
	P.line(ctx, a, Vector(b.X, a.Y), delay + lifetime)
	P.line(ctx, Vector(b.X, a.Y), b, delay + lifetime)
	P.line(ctx, b, Vector(a.X, b.Y), delay + lifetime)
	P.line(ctx, Vector(a.X, b.Y), a, delay + lifetime)
	return obj
end

function M.process(ctx, shot)
	local e = shot.entity
	local prev = shot.previous or e.Position
	if not shot.no_mirror and shot.reflections < 2 then
		for id, mirror in pairs(ctx.mirrors) do
			if ctx.objects[id] and (not shot.allowed_mirrors or shot.allowed_mirrors[id]) and not shot.visited[id] and G.segment_distance(mirror.position, prev, e.Position) <= mirror.radius then
				e.Velocity = G.reflect_velocity(e.Velocity, mirror.orientation)
				shot.visited[id] = true
				shot.reflections = shot.reflections + 1
				if shot.reflections >= 2 then break end
			end
		end
	end
	local field = ctx.field
	if field and ctx.objects[field.id] and ctx.clock >= field.active_at and not shot.field_used then
		local d = e.Position - field.position
		if math.abs(d.X) <= field.half.X and math.abs(d.Y) <= field.half.Y then
			e.Velocity = e.Velocity:Rotated(field.angle)
			shot.field_used = true
		end
	end
	shot.previous = e.Position
end

function M.tick(ctx)
	for id in pairs(ctx.mirrors) do if not ctx.objects[id] then ctx.mirrors[id] = nil end end
	if ctx.field and not ctx.objects[ctx.field.id] then ctx.field = nil end
end

return M
