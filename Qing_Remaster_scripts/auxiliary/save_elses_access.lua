-- Shared helpers for sparse save.elses access modes (root / get_or_create / require).
-- See codex_work/notes/run_savedata_rewind_semantics.md.

local save_elses_access = {}

--- Correlated state is broken. Never invent missing required data.
--- Dev tree (probes allowed): hard error. Public release: log + return nil so callers abort the branch.
function save_elses_access.state_invariant_fail(message)
	message = tostring(message or "save.elses invariant broken")
	Isaac.DebugString("[Qing save invariant] " .. message)
	local ok, env = pcall(require, "Qing_Remaster_scripts.core.dev_environment")
	if ok and env and env.probes_allowed and env.probes_allowed() then
		error(message)
	end
	return nil
end

return save_elses_access
