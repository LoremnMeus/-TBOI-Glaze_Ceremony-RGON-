local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")

local modReference
local item = {
	items = {},
}

local initialized = false

local THREADS = {
	{id = "glaze", scope = "floor", enabled = true, path = "Qing_Remaster_scripts.threads.thread_Glaze"},
	{id = "coin", scope = "run", enabled = true, path = "Qing_Remaster_scripts.threads.thread_Coin"},
	{id = "meat", scope = "floor", enabled = true, path = "Qing_Remaster_scripts.threads.thread_Meat"},
	{id = "stone", scope = "floor", enabled = true, path = "Qing_Remaster_scripts.threads.thread_Stone"},
	{id = "wind", scope = "floor", enabled = true, path = "Qing_Remaster_scripts.threads.thread_Wind"},
	{id = "ending1", scope = "run", enabled = true, path = "Qing_Remaster_scripts.threads.thread_End1"},
	{id = "ending2", scope = "run", enabled = true, path = "Qing_Remaster_scripts.threads.thread_End2"},
	{id = "ending2_display", scope = "run", enabled = true, path = "Qing_Remaster_scripts.threads.thread_End2_2"},
	{id = "start", scope = "floor", enabled = false, path = "Qing_Remaster_scripts.threads.thread_Start"},
	{id = "shaddoll", scope = "run", enabled = false, path = "Qing_Remaster_scripts.threads.thread_Shaddoll"},
	{id = "zeis", scope = "run", enabled = false, path = "Qing_Remaster_scripts.threads.thread_Zeis"},
	{id = "ending3", scope = "run", enabled = false, path = "Qing_Remaster_scripts.threads.thread_End3"},
}

function item.Init(mod)
	if initialized then return end
	initialized = true
	modReference = mod
	local runtime = require("Qing_Remaster_scripts.core.thread_runtime")
	table.insert(item.items, runtime)
	for _, definition in ipairs(THREADS) do
		local module = nil
		if definition.enabled then
			module = require(definition.path)
			table.insert(item.items, module)
		end
		runtime.register({
			id = definition.id,
			version = 1,
			scope = definition.scope,
			enabled = definition.enabled,
			module = module,
			module_path = definition.path,
		})
	end
end

return item
