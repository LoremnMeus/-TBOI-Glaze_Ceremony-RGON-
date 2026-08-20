local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")

local modReference
local manager = {
	items = {},
	functs = {},
}

function manager.Init(mod)
	modReference = mod
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.grids.grid_doors"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.grids.grid_entity"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.grids.grid_wall"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.grids.grid_morpher"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.grids.grid_trapdoor"))
	manager.MakeItems()
end

function manager.MakeItems()
	for i = 1,#manager.items do
		if manager.items[i].Tofun then
			for j = 1,#manager.items[i].Tofun do
				if manager.items[i].Tofun[j].name then
					manager.functs[manager.items[i].Tofun[j].name] = manager.items[i].Tofun[j].Function
				end
			end
		end
	end
end

return manager
