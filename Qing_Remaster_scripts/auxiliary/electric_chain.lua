-- Shared short ELECTRIC chain (Jacob's Ladder / 220 Volt style).
-- Owner of LaserVariant.ELECTRIC hops, EndPoint continuation, same-frame dedup.
-- Consumers must not copy fire_volt_laser / THIN_RED recolors.
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local attack_holder = require("Qing_Remaster_scripts.callbacks.attack_trigger_holder")

local item = {
	ToCall = {},
	own_key = "electric_chain_",
}

local hit_window = {} -- [ptr] = game frame; same-frame visual-only duplicates

local function copy_po(v)
	if not v then return Vector(0, 0) end
	return Vector(v.X, v.Y)
end

local function visual_pos(pos, po)
	pos = pos or Vector(0, 0)
	po = po or Vector(0, 0)
	return Vector(pos.X + po.X, pos.Y + po.Y)
end

local function prune_hit_window(frame)
	if frame % 30 ~= 0 then return end
	for k, f in pairs(hit_window) do
		if (tonumber(f) or 0) < frame - 2 then
			hit_window[k] = nil
		end
	end
end

local function apply_same_frame_damage(ptr, dmg, enabled)
	dmg = tonumber(dmg) or 0
	if not enabled then return dmg end
	local frame = Game():GetFrameCount()
	if (tonumber(hit_window[ptr]) or -1) == frame then
		return 0
	end
	hit_window[ptr] = frame
	return dmg
end

function item.pick_target(origin, radius, blacklist)
	if not origin then return nil end
	blacklist = blacklist or {}
	radius = tonumber(radius) or 0
	local best, best_dist = nil, radius + 1
	for _, npc in ipairs(Isaac.FindInRadius(origin, radius, EntityPartition.ENEMY)) do
		if npc:IsVulnerableEnemy() and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
			local ptr = GetPtrHash(npc)
			if not blacklist[ptr] then
				local dist = (npc.Position - origin):Length()
				if dist < best_dist then
					best, best_dist = npc, dist
				end
			end
		end
	end
	return best
end

local function fire_leg(from_pos, from_po, target, source, dmg, hop_range, hop_dmg, blacklist, hops_left, timeout, one_hit, color, can_continue, dedup)
	if not from_pos or not target or not source then return nil end
	from_po = copy_po(from_po)
	local to_po = copy_po(target.PositionOffset)
	local dir = visual_pos(target.Position, to_po) - visual_pos(from_pos, from_po)
	local leg = dir:Length() + (tonumber(target.Size) or 0)
	if leg < 1 then leg = 1 end
	local laser_var = LaserVariant.ELECTRIC or 10
	local ent = Isaac.Spawn(EntityType.ENTITY_LASER, laser_var, 0, from_pos, Vector.Zero, source)
	if not ent then return nil end
	local q = ent:ToLaser()
	if not q then return nil end
	attack_holder.MarkIgnore(q)
	q.Parent = source
	q.SpawnerEntity = source
	q.Angle = dir:GetAngleDegrees()
	if q.SetMaxDistance then
		q:SetMaxDistance(leg)
	else
		q.MaxDistance = leg
	end
	local life = math.max(1, math.floor(tonumber(timeout) or 2))
	if q.SetTimeout then
		q:SetTimeout(life)
	else
		q.Timeout = life
	end
	q.OneHit = one_hit ~= false
	q.CollisionDamage = tonumber(dmg) or 0
	q.PositionOffset = from_po
	if color then
		q.Color = color
	end
	if q.SetDisableFollowParent then
		pcall(function() q:SetDisableFollowParent(true) end)
	elseif q.DisableFollowParent ~= nil then
		q.DisableFollowParent = true
	end
	q:GetData()[item.own_key.."shot"] = {
		hops = math.max(0, math.floor(tonumber(hops_left) or 0)),
		blacklist = blacklist,
		range = hop_range,
		source = source,
		hop_dmg = tonumber(hop_dmg) or tonumber(dmg) or 0,
		next_from_po = to_po,
		hit_ptr = GetPtrHash(target),
		timeout = life,
		one_hit = one_hit ~= false,
		color = color,
		can_continue = can_continue,
		dedup = dedup == true,
	}
	return q
end

--- Straight electric segment. Does not pick a target or chain.
--- opts: source_entity, from_pos, from_offset, angle, length,
--- damage, timeout, one_hit, color, data
function item.fire_segment(opts)
	opts = opts or {}
	local source = opts.source_entity
	local from_pos = opts.from_pos
	if not source or not from_pos then
		return nil
	end
	local angle = tonumber(opts.angle) or 0
	local length = math.max(1, tonumber(opts.length) or 1)
	local laser_var = LaserVariant.ELECTRIC or 10
	local ent = Isaac.Spawn(EntityType.ENTITY_LASER, laser_var, 0, from_pos, Vector.Zero, source)
	local laser = ent and ent:ToLaser()
	if not laser then
		return nil
	end
	attack_holder.MarkIgnore(laser)
	laser.Parent = source
	laser.SpawnerEntity = source
	laser.Angle = angle
	if laser.SetMaxDistance then
		laser:SetMaxDistance(length)
	else
		laser.MaxDistance = length
	end
	local timeout = math.max(1, math.floor(tonumber(opts.timeout) or 2))
	if laser.SetTimeout then
		laser:SetTimeout(timeout)
	else
		laser.Timeout = timeout
	end
	laser.OneHit = opts.one_hit ~= false
	laser.CollisionDamage = tonumber(opts.damage) or 0
	laser.PositionOffset = copy_po(opts.from_offset)
	if opts.color then
		laser.Color = opts.color
	end
	if laser.SetDisableFollowParent then
		pcall(function()
			laser:SetDisableFollowParent(true)
		end)
	elseif laser.DisableFollowParent ~= nil then
		laser.DisableFollowParent = true
	end
	if type(opts.data) == "table" then
		local d = laser:GetData()
		for k, v in pairs(opts.data) do
			d[k] = v
		end
	end
	return laser
end

function item.fire(opts)
	opts = opts or {}
	local source = opts.source_entity
	local from_pos = opts.from_pos
	if not source or not from_pos then return nil end
	local frame = Game():GetFrameCount()
	prune_hit_window(frame)
	local range = tonumber(opts.range) or 80
	local chain_range = tonumber(opts.chain_range) or range
	local blacklist = opts.blacklist or {}
	local target = opts.first_target
	if not target then
		target = item.pick_target(from_pos, range, blacklist)
	end
	if not target then return nil end
	local ptr = GetPtrHash(target)
	blacklist[ptr] = true
	local dmg = tonumber(opts.damage) or 0
	local hop_dmg = tonumber(opts.chain_damage)
	if hop_dmg == nil then hop_dmg = dmg end
	local hit_dmg = apply_same_frame_damage(ptr, dmg, opts.dedup_same_frame == true)
	return fire_leg(
		from_pos,
		opts.from_offset or Vector.Zero,
		target,
		source,
		hit_dmg,
		chain_range,
		hop_dmg,
		blacklist,
		math.max(0, math.floor(tonumber(opts.max_hops) or 0)),
		opts.timeout,
		opts.one_hit,
		opts.color,
		opts.can_continue,
		opts.dedup_same_frame == true
	)
end

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_LASER_UPDATE,
	params = nil,
	Function = function(_, laser)
		if not laser then return end
		local vd = laser:GetData()[item.own_key.."shot"]
		if not vd then return end
		local hops = math.floor(tonumber(vd.hops) or 0)
		if hops <= 0 then
			vd.hops = nil
			return
		end
		local source = vd.source
		if not source or not auxi.check_all_exists(source) then
			vd.hops = nil
			return
		end
		if vd.can_continue and not vd.can_continue(source) then
			vd.hops = nil
			return
		end
		local blacklist = vd.blacklist or {}
		local range = tonumber(vd.range) or 80
		local origin = laser.EndPoint or laser.Position
		if not origin then
			vd.hops = nil
			return
		end
		local target = item.pick_target(origin, range, blacklist)
		if not target then
			vd.hops = nil
			return
		end
		local ptr = GetPtrHash(target)
		blacklist[ptr] = true
		local hop_dmg = apply_same_frame_damage(ptr, tonumber(vd.hop_dmg) or 0, vd.dedup == true)
		vd.hops = nil
		fire_leg(
			origin,
			copy_po(vd.next_from_po),
			target,
			source,
			hop_dmg,
			range,
			vd.hop_dmg,
			blacklist,
			hops - 1,
			vd.timeout,
			vd.one_hit,
			vd.color,
			vd.can_continue,
			vd.dedup == true
		)
	end,
})

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		hit_window = {}
	end,
})

return item
