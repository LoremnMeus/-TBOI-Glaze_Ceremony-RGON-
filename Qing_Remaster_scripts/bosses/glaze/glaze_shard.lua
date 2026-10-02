local P = require("Qing_Remaster_scripts.bosses.glaze.glaze_placeholder")
local G = require("Qing_Remaster_scripts.bosses.glaze.glaze_geometry")
local Assets = require("Qing_Remaster_scripts.bosses.glaze.glaze_visual_assets")
local M = {max_stacks = 5, shard_counts = {6, 8, 10, 12, 16}}

function M.spawn(ctx, pos, direction, lifetime, label)
	local obj = P.spawn(ctx, "CROWN_SHARD", pos, {direction = direction, lifetime = lifetime, label = label})
	ctx.shards[obj.id] = obj
	-- Attack shards share crown-shard art with the item; gameplay entity stays a Tear placeholder.
	if obj.entity and obj.entity.Exists and obj.entity:Exists() then
		ctx.serial = ctx.serial or 0
		local info = Assets.crown_shard(obj.id)
		local spr = obj.entity:GetSprite()
		spr:Load(info.anm2, true)
		spr:Play(info.animation, true)
	end
	return obj
end

function M.fire(ctx, pos, velocity, opts)
	opts = opts or {}
	local e = Isaac.Spawn(EntityType.ENTITY_PROJECTILE, 0, 0, pos, velocity, ctx.boss):ToProjectile()
	e.FallingAccel, e.FallingSpeed, e.Height = 0, 0, -10
	e:GetData().glaze_boss_projectile = true
	ctx.projectiles[GetPtrHash(e)] = {entity = e, origin = Vector(pos.X, pos.Y), velocity = velocity,
		previous = pos, reflections = 0, visited = {}, lifetime = opts.lifetime or 90,
		echo = opts.echo == true, no_mirror = opts.no_mirror == true, allowed_mirrors = opts.mirrors}
	return e
end

function M.volley(ctx, pos, target, count, spread, speed, opts)
	local dir = G.direction(pos, target)
	for i = 1, count do M.fire(ctx, pos, dir:Rotated((i - (count + 1) / 2) * spread) * speed, opts) end
end

function M.shatter(ctx, pos, stacks, secondary)
	local count = M.shard_counts[stacks] or 6
	for i = 1, count do
		M.fire(ctx, pos, Vector(0, 1):Rotated((i - .5) * 360 / count) * (secondary and 5 or 7), {no_mirror = true})
	end
	SFXManager():Play(SoundEffect.SOUND_GLASS_BREAK, .8, 0, false, 1)
end

function M.consume(ctx, obj)
	M.fire(ctx, obj.position, obj.direction * 8, {no_mirror = true})
	ctx.mirrors[obj.id], ctx.shards[obj.id] = nil, nil
	P.remove(ctx, obj)
end

return M
