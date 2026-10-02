-- Delirium Boss animation name → Mixture entry mapping.
-- Stitch Edition kept this as Boss_Mixturer.Bossanimlist.
-- Not ported yet; Runtime Stitch does not ship a fake table.

local M = {
	schema = "delirium_anim_registry",
	schema_version = 1,
	status = "UNSUPPORTED_DELIRIUM_ANIM_REGISTRY",
}

--- @return any|nil mapped mixture entry id/info when available
function M.get(_skip_name)
	return nil
end

function M.is_available()
	return false
end

return M
