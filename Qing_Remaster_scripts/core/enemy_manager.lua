local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")

local modReference
local Enemy_manager = {
	items = {},
}

--- enemies/ = ordinary enemies only.
--- Boss encounters and Boss modules register via boss_manager.
--- enemy_shadollee is a shaddoll helper (not a Boss); kept here temporarily until
--- its owning system is confirmed (TODO migrate out of enemies/).
function Enemy_manager.Init(mod)
	modReference = mod
	table.insert(Enemy_manager.items, #Enemy_manager.items + 1,
		require("Qing_Remaster_scripts.enemies.enemy_shadollee"))
end

function Enemy_manager.MakeEnemies()
	for i = 1, #Enemy_manager.items do
		if Enemy_manager.items[i].ToCall then
			for j = 1, #(Enemy_manager.items[i].ToCall) do
				if Enemy_manager.items[i].ToCall[j] ~= nil
					and Enemy_manager.items[i].ToCall[j].Function ~= nil
					and Enemy_manager.items[i].ToCall[j].CallBack ~= nil then
					if Enemy_manager.items[i].ToCall[j].params == nil then
						modReference:AddCallback(
							Enemy_manager.items[i].ToCall[j].CallBack,
							Enemy_manager.items[i].ToCall[j].Function
						)
					else
						modReference:AddCallback(
							Enemy_manager.items[i].ToCall[j].CallBack,
							Enemy_manager.items[i].ToCall[j].Function,
							Enemy_manager.items[i].ToCall[j].params
						)
					end
				end
			end
		end
	end
end

return Enemy_manager
