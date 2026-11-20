-- Alien Savior suction eligibility. Whitelist only; pickups permanently excluded.
-- NPC: nature-based (hostile non-boss) — Size only scales motion, not eligibility.
local C = require("Qing_Remaster_scripts.items.alien_savior.constants")
local rock_topology = require("Qing_Remaster_scripts.others.grid_rock_topology")

local P = {}

-- Explicit hard skips (not Size-based). Extend only with verified special cases.
local NPC_SKIP_TYPE = {
	[EntityType.ENTITY_FAMILIAR] = "familiar",
	[EntityType.ENTITY_PLAYER] = "player",
}

--- Detailed NPC verdict for suction / laser / skip.
--- @return string result "abduct"|"laser"|"skip"
--- @return string reason
function P.evaluate_npc(npc)
	if not npc or not npc.Exists or not npc:Exists() then
		return "skip", "missing"
	end
	if npc:IsDead() then
		return "skip", "dead"
	end
	local skip_tag = NPC_SKIP_TYPE[npc.Type]
	if skip_tag then
		return "skip", skip_tag
	end
	if not npc:ToNPC() then
		return "skip", "not_npc"
	end
	if npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
		return "skip", "friendly"
	end
	if npc:HasEntityFlags(EntityFlag.FLAG_CHARM) then
		return "skip", "charm"
	end
	-- Prefer IsEnemy over IsVulnerableEnemy so brief invuln phases still qualify.
	local is_enemy = false
	if npc.IsEnemy then
		is_enemy = npc:IsEnemy() == true
	elseif npc.IsVulnerableEnemy then
		is_enemy = npc:IsVulnerableEnemy() == true
	end
	if not is_enemy then
		return "skip", "not_enemy"
	end
	if npc:IsBoss() then
		return "laser", "boss"
	end
	-- Ordinary hostile NPC: always abduct. Size does not gate eligibility.
	return "abduct", "hostile_npc"
end

--- Classify NPC for suction vs laser. Thin wrapper over evaluate_npc.
function P.classify_npc(npc)
	local result = P.evaluate_npc(npc)
	return result
end

function P.is_enemy_projectile(ent)
	if not ent or ent.Type ~= EntityType.ENTITY_PROJECTILE then
		return false
	end
	if not ent.Exists or not ent:Exists() then
		return false
	end
	if ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
		return false
	end
	return true
end

--- Rock vs poop kind for suction. Poop is not a rock — do not feed rock_topology.
--- @return string|nil "rock"|"poop"
function P.grid_kind(grid)
	if not grid then
		return nil
	end
	local tp = grid:GetType()
	if tp == GridEntityType.GRID_DECORATION then
		return nil
	end
	if rock_topology.is_rock_type(tp) or (C.ROCK_OK and C.ROCK_OK[tp] == true) then
		return "rock"
	end
	if tp == GridEntityType.GRID_POOP then
		return "poop"
	end
	return nil
end

--- Rocks only (topology registry). Never decorations / doors / pits / traps / poop.
function P.is_safe_rock(grid)
	return P.grid_kind(grid) == "rock"
end

--- Rocks or GRID_POOP (separate remove path in suction).
function P.is_safe_grid(grid)
	return P.grid_kind(grid) ~= nil
end

--- Entity-level suction decision. Returns kind or nil.
--- Pickups are permanently excluded (loot stays on the floor).
function P.entity_kind(ent)
	if not ent or not ent.Exists or not ent:Exists() then
		return nil
	end
	if ent.Type == EntityType.ENTITY_PLAYER then
		return nil
	end
	if ent.Type == EntityType.ENTITY_FAMILIAR then
		return nil
	end
	if ent:ToPickup() then
		return nil
	end
	if P.is_enemy_projectile(ent) then
		return "projectile"
	end
	if ent:ToNPC() then
		local c = P.classify_npc(ent)
		if c == "abduct" then
			return "npc"
		end
		return nil
	end
	return nil
end

--- Motion scale from Size (eligibility is independent).
function P.npc_motion_scale(npc_or_size)
	local sz = 16
	if type(npc_or_size) == "number" then
		sz = npc_or_size
	elseif npc_or_size and npc_or_size.Size then
		sz = npc_or_size.Size or 16
	end
	if sz < 8 then
		sz = 8
	elseif sz > 48 then
		sz = 48
	end
	return sz / 16
end

function P.reserve_key_entity(ent)
	if not ent then
		return nil
	end
	return "e:" .. tostring(GetPtrHash(ent))
end

function P.reserve_key_grid(index)
	return "g:" .. tostring(index)
end

return P
