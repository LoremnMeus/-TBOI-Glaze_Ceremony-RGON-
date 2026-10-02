-- Shared pocket / active owned-use semantics.
-- Real owned use = USE_OWNED and not mimic / noanim / carbattery.
local M = {}

function M.is_real_owned_use(use_flags)
	use_flags = use_flags or 0
	if use_flags & UseFlag.USE_MIMIC ~= 0 then return false end
	if use_flags & UseFlag.USE_NOANIM ~= 0 then return false end
	if use_flags & UseFlag.USE_CARBATTERY ~= 0 then return false end
	if use_flags & UseFlag.USE_OWNED == 0 then return false end
	return true
end

function M.is_simulated_use(use_flags)
	return not M.is_real_owned_use(use_flags)
end

return M
