-- Player-attack mimic familiars (whitelist only). No GetWeapon inference.
-- Shared by Attack Trigger Holder; Blueprint may require the same table later.
local M = {}

-- Independent Attack rounds (Incubus / Twisted / Cain's Other Eye / Gello).
-- Fate's Reward is reactive — see REACTIVE_FAMILIAR_VARIANTS.
M.PLAYER_ATTACK_MIMIC_VARIANTS = {
	[FamiliarVariant.INCUBUS] = true,
	[FamiliarVariant.TWISTED_BABY] = true,
	[FamiliarVariant.CAINS_OTHER_EYE] = true,
}
if FamiliarVariant.UMBILICAL_BABY then
	M.PLAYER_ATTACK_MIMIC_VARIANTS[FamiliarVariant.UMBILICAL_BABY] = true
end
-- Numeric fallbacks if enums missing in older loads.
M.PLAYER_ATTACK_MIMIC_VARIANTS[76] = M.PLAYER_ATTACK_MIMIC_VARIANTS[76] or true -- CAINS_OTHER_EYE
M.PLAYER_ATTACK_MIMIC_VARIANTS[80] = M.PLAYER_ATTACK_MIMIC_VARIANTS[80] or true -- INCUBUS
M.PLAYER_ATTACK_MIMIC_VARIANTS[235] = M.PLAYER_ATTACK_MIMIC_VARIANTS[235] or true -- TWISTED_BABY
M.PLAYER_ATTACK_MIMIC_VARIANTS[240] = M.PLAYER_ATTACK_MIMIC_VARIANTS[240] or true -- Gello / UMBILICAL_BABY
if FamiliarVariant.CAINS_OTHER_EYE then
	M.PLAYER_ATTACK_MIMIC_VARIANTS[FamiliarVariant.CAINS_OTHER_EYE] = true
end

-- Reactive familiars: respond to player attacks; no independent Attack / Once / source_id round.
M.REACTIVE_FAMILIAR_VARIANTS = {
	[FamiliarVariant.FATES_REWARD] = true,
}
M.REACTIVE_FAMILIAR_VARIANTS[81] = M.REACTIVE_FAMILIAR_VARIANTS[81] or true -- FATES_REWARD

function M.is_player_attack_mimic(fam)
	if not fam or fam.Type ~= EntityType.ENTITY_FAMILIAR then
		return false
	end
	return M.PLAYER_ATTACK_MIMIC_VARIANTS[fam.Variant] == true
end

function M.is_reactive_familiar(fam)
	if not fam or fam.Type ~= EntityType.ENTITY_FAMILIAR then
		return false
	end
	return M.REACTIVE_FAMILIAR_VARIANTS[fam.Variant] == true
end

return M
