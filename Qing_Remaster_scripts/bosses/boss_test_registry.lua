-- Boss Test Lab adapter registry.
-- Boss identity/name/status still come from boss_registry. This only maps optional test adapters.
-- Do NOT invent a second Boss canon here.

local boss_registry = require("Qing_Remaster_scripts.bosses.boss_registry")

local M = {
	adapters = {},
}

function M.register(id, adapter)
	if type(id) ~= "string" or type(adapter) ~= "table" then return false end
	adapter.id = adapter.id or id
	M.adapters[id] = adapter
	return true
end

function M.get(id)
	return M.adapters[id]
end

function M.list()
	local out = {}
	for _, boss in ipairs(boss_registry.list()) do
		out[#out + 1] = {
			boss = boss,
			adapter = M.adapters[boss.id],
		}
	end
	return out
end

return M
