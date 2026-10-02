-- Stitch Edition Base_holder.init(nil, ent) was NOT a light NPC reinit.
-- It ran the full POST_NPC_INIT stitch pipeline (mix.fast_search +
-- mix.generate_mixture / ControlData spawn chances / Deli_holder checks).
--
-- Runtime Stitch has no equivalent auto-restitch-on-phase-morph.
-- Callers must treat a false return as unsupported, not as a successful no-op.

local M = {
	schema = "native_reinit",
	schema_version = 1,
	status = "UNSUPPORTED_BASE_HOLDER_INIT",
}

--- @return boolean success
--- @return string|nil reason
function M.reinitialize(ent, reason)
	return false, "UNSUPPORTED_BASE_HOLDER_INIT:" .. tostring(reason or "unknown")
end

function M.is_supported()
	return false
end

return M
