-- Damage → member binding snapshot → POST_ATTACK_DAMAGE (event fully built before dispatch).
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local registry = require("Qing_Remaster_scripts.callbacks.attack_registry")

local M = {
	ToCall = {},
	own_key = "attack_damage_binding_",
}

local function ref_entity(source)
	if not source then return nil end
	if source.Entity then return source.Entity end
	if source.GetData and source.Type then return source end
	return nil
end

local function resolve_member(source, extra_source, target_ent)
	local function try_ent(ent)
		if not ent then return nil, nil, nil end
		local attack, binding = registry.GetAttackForMember(ent)
		if attack and binding then
			return ent, attack, binding
		end
		-- Bomb/Epic explosion may damage after ENTITY_REMOVE unbound the member.
		attack, binding = registry.lookup_recent_for_damage(ent)
		if attack and binding then
			return ent, attack, binding
		end
		return nil, nil, nil
	end

	local function try_knife_chain(ent)
		local member, attack, binding = try_ent(ent)
		if attack then return member, attack, binding end
		if not ent or ent.Type ~= EntityType.ENTITY_KNIFE then
			return nil, nil, nil
		end
		-- CLUB_HITBOX → parent blade (ExtraSource is often the hitbox knife).
		local parent = nil
		if ent.GetHitboxParentKnife then
			local ok, p = pcall(function() return ent:GetHitboxParentKnife() end)
			if ok then parent = p end
		end
		if not parent and ent.Parent and ent.Parent.Type == EntityType.ENTITY_KNIFE then
			parent = ent.Parent
		end
		if parent then
			local _, attack2, binding2 = try_ent(parent)
			if attack2 then
				return ent, attack2, binding2
			end
		end
		return nil, nil, nil
	end

	local member, attack, binding = try_knife_chain(ref_entity(extra_source))
	if attack then return member, attack, binding end
	member, attack, binding = try_knife_chain(ref_entity(source))
	if attack then return member, attack, binding end

	-- Epic/Dr: Source is frequently the player, not the rocket/bomb entity.
	local src = ref_entity(extra_source) or ref_entity(source)
	local player = nil
	if src then
		if src.ToPlayer and src:ToPlayer() then
			player = src:ToPlayer()
		else
			player = auxi.check_spawner_player(src) or auxi.check_near_spawner_player(src)
		end
	end
	if player then
		local pos = target_ent and target_ent.Position
		attack, binding = registry.lookup_recent_player_blast(player, pos)
		if attack and binding then
			return src, attack, binding
		end
	end
	return nil, nil, nil
end

function M.on_take_damage(ent, amount, flags, source, countdown, extra_source)
	if not auxi.isenemies(ent) then return end
	-- Snapshot immediately before any other logic can Unbind.
	local member, attack, binding = resolve_member(source, extra_source, ent)
	if not attack or not binding then return end

	local event = registry.make_event(attack, {
		member = member,
		generation = binding.generation,
		target = ent,
		damage = amount,
		source = extra_source or source,
		position = ent.Position,
		player = attack.player,
		family = attack.family,
		reason = "damage",
	})
	-- Flags for consumers that care (optional field).
	event.flags = flags
	event.countdown = countdown

	registry.dispatch(enums.Callbacks.POST_ATTACK_DAMAGE, event)
end

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG,
	params = nil,
	Function = function(_, ent, amount, flags, source, countdown, extra_source)
		M.on_take_damage(ent, amount, flags, source, countdown, extra_source)
	end,
})

return M
