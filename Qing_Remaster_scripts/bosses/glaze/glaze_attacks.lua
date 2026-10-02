local G = require("Qing_Remaster_scripts.bosses.glaze.glaze_geometry")
local P = require("Qing_Remaster_scripts.bosses.glaze.glaze_placeholder")
local Mirror = require("Qing_Remaster_scripts.bosses.glaze.glaze_mirror")
local Shard = require("Qing_Remaster_scripts.bosses.glaze.glaze_shard")
local Palace = require("Qing_Remaster_scripts.bosses.glaze.glaze_palace")
local M = {by_id = {}, pools = {[1] = {}, [2] = {}, [3] = {}, finale = {}}}

local function palace_pos(ctx, name, fallback)
	return Palace.get_anchor_position(ctx, name) or fallback
end

local function target(ctx) return ctx.boss:GetPlayerTarget().Position end
local function register(phase, id, duration, recovery, tags, position, setup, update)
	local attack = {id = id, duration = duration, recovery = recovery, cooldown = duration + recovery + 90,
		weight = 1, min_phase_time = tags.signature and 240 or 0, tags = tags,
		can_repeat = false, preferred_position = position or "CENTER", setup = setup, update = update,
		cleanup = function(ctx) ctx.perfect = false end}
	M.by_id[id] = attack
	M.pools[phase][#M.pools[phase] + 1] = attack
end

local function make_ray(ctx, source, pos, orientation, warning, number)
	local mirror = Mirror.spawn(ctx, pos, orientation, warning + 90)
	local incoming = G.direction(source, pos)
	local outgoing = G.reflect_velocity(incoming, orientation)
	P.line(ctx, source, pos, warning, tostring(number or "RAY"))
	P.line(ctx, pos, pos + outgoing * 650, warning)
	return {source = source, mirror = mirror, velocity = incoming * 13}
end

local function fire_ray(ctx, ray)
	Shard.fire(ctx, ray.source, ray.velocity, {mirrors = {[ray.mirror.id] = true}})
end

register(1, "p1.refracted_ray", 110, 35, {basic = true, mirror = true}, "TOP",
	function(ctx)
		local pos = ctx.room:GetCenterPos() + Vector(100, 30)
		ctx.work.ray = make_ray(ctx, ctx.boss.Position, pos, "DIAGONAL_A", 60)
	end,
	function(ctx, f) if f >= 60 and f < 70 and f % 2 == 0 then fire_ray(ctx, ctx.work.ray) end end)

register(1, "p1.crown_shards", 120, 35, {basic = true}, "TOP",
	function(ctx)
		ctx.work.crowns = {}
		for i = 1, 5 do
			ctx.work.crowns[i] = Shard.spawn(ctx, ctx.boss.Position + Vector(0, -50):Rotated(i * 72), Vector(0, 1), 150, "CROWN " .. i)
		end
	end,
	function(ctx, f)
		for i, obj in ipairs(ctx.work.crowns) do
			local lock = 10 + (i - 1) * 20
			if f == lock then
				obj.direction = G.direction(obj.position, target(ctx))
				P.label(obj, "CROWN " .. i .. " LOCK")
				P.line(ctx, obj.position, obj.position + obj.direction * 600, 12)
			elseif f == lock + 12 then Shard.consume(ctx, obj) end
		end
	end)

register(1, "p1.glazed_field", 190, 45, {field = true}, "TOP",
	function(ctx)
		Mirror.field(ctx, ctx.room:GetCenterPos(), Vector(120, 45), 30, 30, 150)
		ctx.work.aim = ctx.room:GetCenterPos() + Vector(0, 180)
	end,
	function(ctx, f)
		if f == 30 then
			P.label(ctx.field, "GLAZE FIELD +30")
			local start = ctx.boss.Position
			local dir = G.direction(start, ctx.work.aim)
			local point = ctx.room:GetCenterPos()
			P.line(ctx, start, point, 30)
			P.line(ctx, point, point + dir:Rotated(30) * 450, 30)
		end
		if f >= 60 and f <= 140 and f % 20 == 0 then Shard.volley(ctx, ctx.boss.Position, ctx.work.aim, 3, 12, 6) end
	end)

register(1, "p1.kings_light", 160, 60, {signature = true, high_pressure = true}, "TOP",
	function(ctx)
		local source = ctx.boss.Position
		ctx.work.direct = G.direction(source, target(ctx))
		P.line(ctx, source, source + ctx.work.direct * 650, 50, "1")
		local c = ctx.room:GetCenterPos()
		ctx.work.left = make_ray(ctx, source, c + Vector(-120, 20), "DIAGONAL_A", 80, 2)
		ctx.work.right = make_ray(ctx, source, c + Vector(120, 20), "DIAGONAL_B", 110, 3)
	end,
	function(ctx, f)
		if f >= 50 and f < 60 and f % 2 == 0 then Shard.fire(ctx, ctx.boss.Position, ctx.work.direct * 13, {no_mirror = true}) end
		if f >= 80 and f < 90 and f % 2 == 0 then fire_ray(ctx, ctx.work.left) end
		if f >= 110 and f < 120 and f % 2 == 0 then fire_ray(ctx, ctx.work.right) end
	end)

register(2, "p2.mirror_self", 140, 40, {basic = true, mirror = true}, "TOP_LEFT",
	function(ctx)
		local fallback = G.mirror_position(ctx.boss.Position, ctx.center)
		local mirror_anchor = palace_pos(ctx, "TOP_RIGHT_WINDOW", fallback)
		ctx.work.clone = P.spawn(ctx, "MIRROR GLAZE", mirror_anchor, {lifetime = 140})
		ctx.work.aim = Vector(target(ctx).X, target(ctx).Y)
		ctx.work.use_palace = Palace.get_anchor(ctx, "TOP_RIGHT_WINDOW") ~= nil
	end,
	function(ctx, f)
		local clone = ctx.work.clone
		if ctx.work.use_palace then
			local pos = palace_pos(ctx, "TOP_RIGHT_WINDOW", G.mirror_position(ctx.boss.Position, ctx.center))
			P.move(clone, pos)
		else
			P.move(clone, G.mirror_position(ctx.boss.Position, ctx.center))
		end
		if f == 15 then
			P.line(ctx, ctx.boss.Position, ctx.work.aim, 30, "BODY")
			P.line(ctx, clone.position, G.mirror_position(ctx.work.aim, ctx.center), 65, "MIRROR")
		end
		if f == 45 then Shard.volley(ctx, ctx.boss.Position, ctx.work.aim, 3, 15, 6, {no_mirror = true}) end
		if f == 80 then Shard.volley(ctx, clone.position, G.mirror_position(ctx.work.aim, ctx.center), 3, 15, 6, {no_mirror = true}) end
	end)

register(2, "p2.echo_ray", 150, 45, {basic = true, mirror = true}, "TOP_LEFT",
	function(ctx)
		ctx.work.aim = Vector(target(ctx).X, target(ctx).Y)
		ctx.work.origin = palace_pos(ctx, "TOP_LEFT_WINDOW", ctx.boss.Position)
		P.line(ctx, ctx.work.origin, ctx.work.aim, 30, "ORIGINAL")
	end,
	function(ctx, f)
		if f == 30 then Shard.volley(ctx, ctx.work.origin or ctx.boss.Position, ctx.work.aim, 5, 10, 7, {echo = true, lifetime = 30, no_mirror = true}) end
	end)

register(2, "p2.mirror_array", 160, 50, {mirror = true}, "CENTER",
	function(ctx)
		local positions = {Vector(0, -90), Vector(140, 0), Vector(0, 90), Vector(-140, 0)}
		ctx.work.array = {}
		for i, v in ipairs(positions) do
			ctx.work.array[i] = Mirror.spawn(ctx, ctx.center + v, i % 2 == 0 and "VERTICAL" or "HORIZONTAL", 160)
		end
		-- Top reflection returns through the room; bottom reflection is the final allowed bend.
		P.line(ctx, ctx.center, ctx.center + positions[1], 40, "1")
		P.line(ctx, ctx.center + positions[1], ctx.center + positions[3], 40, "2")
		P.line(ctx, ctx.center + positions[3], ctx.center + Vector(0, -600), 40, "EXIT")
	end,
	function(ctx, f)
		if f >= 40 and f <= 70 and f % 5 == 0 then
			local a = ctx.work.array
			Shard.fire(ctx, ctx.center, Vector(0, -8), {mirrors = {[a[1].id] = true, [a[3].id] = true}, lifetime = 110})
		end
	end)

register(2, "p2.kaleidoscope", 220, 70, {signature = true, high_pressure = true, mirror = true}, "CENTER",
	function(ctx)
		ctx.work.nodes, ctx.work.aims = {}, {}
		ctx.work.order = {2, 5, 1}
		local anchors = Palace.get_available_anchors(ctx, "mirror")
		for i = 1, 6 do
			local fallback = ctx.center + Vector(150, 0):Rotated((i - 1) * 60)
			local pos = (anchors[i] and anchors[i].position) or fallback
			ctx.work.nodes[i] = Mirror.spawn(ctx, pos, "DIAGONAL_A", 220)
			P.spawn(ctx, "MIRROR GLAZE " .. i, pos + Vector(0, -18), {lifetime = 210})
		end
	end,
	function(ctx, f)
		for order, i in ipairs(ctx.work.order) do
			local node = ctx.work.nodes[i]
			if f == order * 15 then
				ctx.work.aims[i] = Vector(target(ctx).X, target(ctx).Y)
				P.label(node, "FLASH " .. order .. " / " .. i)
				P.line(ctx, node.position, ctx.work.aims[i], 80, tostring(order))
			end
			if f == 80 + order * 20 then Shard.volley(ctx, node.position, ctx.work.aims[i], 3, 12, 7, {no_mirror = true}) end
		end
		local ray_pos = palace_pos(ctx, "RIGHT_DIAMOND", ctx.center + Vector(110, 50))
		if f == 150 then ctx.work.ray = make_ray(ctx, ctx.boss.Position, ray_pos, "DIAGONAL_B", 30, "KING") end
		if f >= 180 and f < 190 and f % 2 == 0 then fire_ray(ctx, ctx.work.ray) end
	end)

register(3, "p3.shatter_light", 80, 25, {basic = true}, "TOP",
	function(ctx)
		ctx.work.remnants = {}
		for _, obj in pairs(ctx.objects) do
			if ctx.mirrors[obj.id] or ctx.shards[obj.id] then ctx.work.remnants[#ctx.work.remnants + 1] = obj end
		end
		if #ctx.work.remnants == 0 then
			for _, pos in ipairs(ctx.remnant_positions) do
				ctx.work.remnants[#ctx.work.remnants + 1] = Shard.spawn(ctx, pos, G.direction(pos, target(ctx)), 90, "REMNANT")
			end
		end
		for _, obj in ipairs(ctx.work.remnants) do P.label(obj, "CRACK"); P.line(ctx, obj.position, obj.position + obj.direction * 600, 20) end
	end,
	function(ctx, f) if f == 20 then for _, obj in ipairs(ctx.work.remnants) do Shard.consume(ctx, obj) end end end)

local function crown_setup(ctx)
	ctx.work.built, ctx.work.crowns, ctx.work.progress = 0, {}, 0
	ctx.work.damage_progress = 0
end
local function build_crown(ctx, f, limit, interval)
	ctx.work.progress = ctx.work.progress + 1
	local count = math.min(limit, math.floor((ctx.work.progress + ctx.work.damage_progress) / interval))
	while ctx.work.built < count do
		ctx.work.built = ctx.work.built + 1
		local i = ctx.work.built
		ctx.work.crowns[i] = Shard.spawn(ctx, ctx.boss.Position + Vector(0, -55):Rotated(i * 72), Vector(0, 1), 300, "CROWN " .. i .. "/" .. limit)
		SFXManager():Play(SoundEffect.SOUND_STONE_IMPACT, .35, 0, false, 1 + i * .1)
	end
	for i, obj in ipairs(ctx.work.crowns) do P.move(obj, ctx.boss.Position + Vector(0, -55):Rotated(i * 72 + f)) end
end
local function break_crown(ctx, count)
	for _, obj in ipairs(ctx.work.crowns) do P.remove(ctx, obj); ctx.shards[obj.id] = nil end
	Shard.shatter(ctx, ctx.boss.Position, count)
	ctx.last_shatter = ctx.clock
end

register(3, "p3.shatter_crown", 170, 35, {basic = true, high_pressure = true}, "CENTER", crown_setup,
	function(ctx, f)
		if not ctx.work.broken then
			build_crown(ctx, f, 5, 24)
			if ctx.work.built == 5 and ctx.clock - ctx.last_shatter >= 90 and f >= 90 then
				break_crown(ctx, 5); ctx.work.broken = f
			end
		elseif f == ctx.work.broken + 20 then Shard.shatter(ctx, ctx.boss.Position, 3, true) end
	end)

register(3, "p3.falling_crystal", 145, 35, {mirror = true}, "TOP",
	function(ctx)
		ctx.work.crystals = {}
		local aim = Vector(target(ctx).X, target(ctx).Y)
		for i = -1, 1 do
			local pos = ctx.room:GetClampedPosition(aim + Vector(i * 85, 0), 40)
			ctx.work.crystals[#ctx.work.crystals + 1] = P.spawn(ctx, "FALLING CRYSTAL", pos, {lifetime = 36})
		end
	end,
	function(ctx, f)
		if f == 35 then
			for i, obj in ipairs(ctx.work.crystals) do
				local pos = obj.position
				P.remove(ctx, obj)
				ctx.work.crystals[i] = Mirror.spawn(ctx, pos, "DIAGONAL_A", 100, "TEMP MIRROR")
			end
		end
		if f == 60 then Shard.volley(ctx, ctx.boss.Position, ctx.work.crystals[2].position, 3, 10, 6) end
		if f == 95 then for _, obj in ipairs(ctx.work.crystals) do P.label(obj, "CRACK"); P.line(ctx, obj.position, obj.position + obj.direction * 600, 20) end end
		if f == 115 then for _, obj in ipairs(ctx.work.crystals) do Shard.consume(ctx, obj) end end
	end)

register(3, "p3.until_it_shatters", 210, 55, {signature = true, high_pressure = true}, "CENTER",
	function(ctx) ctx.perfect = true; crown_setup(ctx) end,
	function(ctx, f)
		if f < 60 then build_crown(ctx, f, 5, 10) end
		if f == 60 then ctx.work.ray = make_ray(ctx, ctx.boss.Position, ctx.center + Vector(110, 30), "DIAGONAL_A", 30) end
		if f >= 90 and f < 100 and f % 2 == 0 then fire_ray(ctx, ctx.work.ray) end
		if f == 110 then ctx.work.aim = Vector(target(ctx).X, target(ctx).Y); P.line(ctx, ctx.boss.Position, ctx.work.aim, 25, "ECHO") end
		if f == 135 then Shard.volley(ctx, ctx.boss.Position, ctx.work.aim, 3, 14, 7, {echo = true, lifetime = 20, no_mirror = true}) end
		if f == 185 then for _, obj in ipairs(ctx.work.crowns) do P.label(obj, "CRACK") end end
		if f == 205 then break_crown(ctx, 5); ctx.perfect = false end
	end)

register("finale", "finale.short_shard_volley", 65, 18, {basic = true}, "TOP",
	function(ctx) ctx.work.aim = Vector(target(ctx).X, target(ctx).Y); P.line(ctx, ctx.boss.Position, ctx.work.aim, 25) end,
	function(ctx, f) if f == 25 then Shard.volley(ctx, ctx.boss.Position, ctx.work.aim, 3, 15, 8, {no_mirror = true}) end end)

register("finale", "finale.failed_refraction", 90, 20, {mirror = true}, "CENTER",
	function(ctx)
		local pos = ctx.center + Vector(100, 40)
		ctx.work.mirror = Mirror.spawn(ctx, pos, "VERTICAL", 90)
		ctx.work.failure = G.reflect_velocity(G.direction(ctx.boss.Position, pos), "VERTICAL"):Rotated(30)
		P.line(ctx, pos, pos + ctx.work.failure * 650, 40, "FAILED +30")
	end,
	function(ctx, f)
		if f == 10 then P.label(ctx.work.mirror, "CRACK") end
		if f == 40 then
			Shard.fire(ctx, ctx.work.mirror.position, ctx.work.failure * 10, {no_mirror = true})
			P.remove(ctx, ctx.work.mirror)
		end
	end)

register("finale", "finale.incomplete_crown", 130, 20, {basic = true}, "CENTER", crown_setup,
	function(ctx, f)
		if f <= 60 then build_crown(ctx, f, 3, 20) end
		if f == 65 then for _, obj in ipairs(ctx.work.crowns) do P.label(obj, "INCOMPLETE 3/5") end end
		if f == 90 then break_crown(ctx, 3) end
	end)

return M
