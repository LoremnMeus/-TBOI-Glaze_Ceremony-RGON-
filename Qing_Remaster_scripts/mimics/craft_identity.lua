-- Canonical Craft Flight UID + live combat profile keys (Blueprint craft identity).
-- Attack classifier / craft systems must use this module — never Item_Air_Flight.own_key.
-- UID key string stays "Item_Blue_Print_craft_uid" for existing entity GetData compatibility.
local M = {
	CRAFT_UID_KEY = "Item_Blue_Print_craft_uid",
	-- Live craft_combat_profile on the Air Flight familiar (runtime; not save.elses).
	PROFILE_KEY = "CraftIdentity_craft_profile",
}

function M.get_uid(ent)
	if not ent then
		return nil
	end
	return ent:GetData()[M.CRAFT_UID_KEY]
end

function M.set_uid(ent, uid)
	if not ent then
		return
	end
	ent:GetData()[M.CRAFT_UID_KEY] = uid
end

function M.get_profile(ent)
	if not ent or not ent.GetData then
		return nil
	end
	local d = ent:GetData()
	local prof = d[M.PROFILE_KEY]
	if prof ~= nil then
		return prof
	end
	-- Same-commit migration fallback (old Air Flight / Blue_Print GetData keys).
	return d["Item_Air_Flight_craft_profile"] or d["Item_Blue_Print_craft_profile"]
end

function M.set_profile(ent, profile)
	if not ent or not ent.GetData then
		return
	end
	ent:GetData()[M.PROFILE_KEY] = profile
end

return M
