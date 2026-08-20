local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")

local modReference
local Enemy_manager = {
	items = {},
}

function Enemy_manager.Init(mod)
	modReference = mod
	table.insert(Enemy_manager.items,#Enemy_manager.items + 1,require("Qing_Remaster_scripts.enemies.Floraine.Enemy_chess_board"))
	table.insert(Enemy_manager.items,#Enemy_manager.items + 1,require("Qing_Remaster_scripts.enemies.Floraine.Enemy_chess_pawn"))
	table.insert(Enemy_manager.items,#Enemy_manager.items + 1,require("Qing_Remaster_scripts.enemies.Floraine.Enemy_chess_staff"))
	table.insert(Enemy_manager.items,#Enemy_manager.items + 1,require("Qing_Remaster_scripts.enemies.Floraine.Enemy_Floraine"))
	
	table.insert(Enemy_manager.items,#Enemy_manager.items + 1,require("Qing_Remaster_scripts.enemies.Zennith.Zennith"))
	table.insert(Enemy_manager.items,#Enemy_manager.items + 1,require("Qing_Remaster_scripts.enemies.Zennith.Enemy_wind"))
	
	table.insert(Enemy_manager.items,#Enemy_manager.items + 1,require("Qing_Remaster_scripts.enemies.enemy_bum_emperor"))
	table.insert(Enemy_manager.items,#Enemy_manager.items + 1,require("Qing_Remaster_scripts.enemies.enemy_bum_guard"))
	table.insert(Enemy_manager.items,#Enemy_manager.items + 1,require("Qing_Remaster_scripts.enemies.enemy_bum_spear"))
	table.insert(Enemy_manager.items,#Enemy_manager.items + 1,require("Qing_Remaster_scripts.enemies.enemy_bum_arrow"))
	table.insert(Enemy_manager.items,#Enemy_manager.items + 1,require("Qing_Remaster_scripts.enemies.enemy_shadollee"))
	
	table.insert(Enemy_manager.items,#Enemy_manager.items + 1,require("Qing_Remaster_scripts.bosses.Boss_All"))
	table.insert(Enemy_manager.items,#Enemy_manager.items + 1,require("Qing_Remaster_scripts.bosses.Boss_Autio"))
	table.insert(Enemy_manager.items,#Enemy_manager.items + 1,require("Qing_Remaster_scripts.bosses.Boss_Zeistos"))
	table.insert(Enemy_manager.items,#Enemy_manager.items + 1,require("Qing_Remaster_scripts.bosses.Boss_ZeistosHelper"))
	table.insert(Enemy_manager.items,#Enemy_manager.items + 1,require("Qing_Remaster_scripts.bosses.Boss_Glaze"))
	table.insert(Enemy_manager.items,#Enemy_manager.items + 1,require("Qing_Remaster_scripts.bosses.Boss_Qing"))
	table.insert(Enemy_manager.items,#Enemy_manager.items + 1,require("Qing_Remaster_scripts.bosses.Boss_Absurd"))
	--Enemy_manager.MakeEnemies()
end

function Enemy_manager.MakeEnemies()	--没有传入参数。
	for i = 1,#Enemy_manager.items do
		if Enemy_manager.items[i].ToCall then
			for j = 1,#(Enemy_manager.items[i].ToCall) do
				if Enemy_manager.items[i].ToCall[j] ~= nil and Enemy_manager.items[i].ToCall[j].Function ~= nil and Enemy_manager.items[i].ToCall[j].CallBack ~= nil then
					if Enemy_manager.items[i].ToCall[j].params == nil then
						modReference:AddCallback(Enemy_manager.items[i].ToCall[j].CallBack,Enemy_manager.items[i].ToCall[j].Function)
					else
						modReference:AddCallback(Enemy_manager.items[i].ToCall[j].CallBack,Enemy_manager.items[i].ToCall[j].Function,Enemy_manager.items[i].ToCall[j].params)
					end
				end
			end
		end
	end
end

return Enemy_manager
