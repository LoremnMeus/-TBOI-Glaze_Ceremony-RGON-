-- Combat output affiliation (not Attack identity).
-- Answers: which combat system does this entity belong to?
-- Does NOT CreateAttack / Once / source_id rounds.
local registry = require("Qing_Remaster_scripts.callbacks.attack_registry")
local classifier = require("Qing_Remaster_scripts.callbacks.attack_source_classifier")
local fam_class = require("Qing_Remaster_scripts.mimics.familiar_attack_classification")

local M = {
	own_key = "combat_output_classifier_",
}

--- @return table|nil { tier, subtype?, owner_player?, attack?, source?, emitter?, entity }
function M.ClassifyCombatOutput(ent)
	if not ent then
		return nil
	end

	local attack = select(1, registry.GetAttackForMember(ent))
	if attack and attack.active and not attack.ending then
		return {
			tier = "attack_member",
			entity = ent,
			attack = attack,
			source = attack.source,
			owner_player = attack.player or (attack.source and attack.source.owner_player),
		}
	end

	-- Reactive familiar projectiles (Fate's Reward, …): player combat output, no Attack.
	local parent = ent.Parent
	local spawner = ent.SpawnerEntity
	local emitter = nil
	if parent and fam_class.is_reactive_familiar(parent) then
		emitter = parent
	elseif spawner and fam_class.is_reactive_familiar(spawner) then
		emitter = spawner
	end
	if emitter then
		local owner = classifier.resolve_owner_player(emitter)
			or classifier.resolve_owner_player(ent)
		return {
			tier = "auxiliary_player_output",
			subtype = "reactive_familiar_projectile",
			entity = ent,
			emitter = emitter,
			owner_player = owner,
		}
	end

	-- Synthetic / Aquarius-style markers on entity data (optional).
	local d = ent:GetData()
	if d and (d.attack_synthetic_sample == true or d.Qing_auxiliary_player_output == true) then
		local owner = classifier.resolve_owner_player(ent)
		return {
			tier = "auxiliary_player_output",
			subtype = d.Qing_auxiliary_subtype or "synthetic_proc",
			entity = ent,
			owner_player = owner,
		}
	end

	return {
		tier = "other",
		entity = ent,
		owner_player = classifier.resolve_owner_player(ent),
	}
end

function M.IsAuxiliaryPlayerOutput(ent)
	local out = M.ClassifyCombatOutput(ent)
	return out and out.tier == "auxiliary_player_output"
end

function M.IsAttackMember(ent)
	local out = M.ClassifyCombatOutput(ent)
	return out and out.tier == "attack_member"
end

return M
