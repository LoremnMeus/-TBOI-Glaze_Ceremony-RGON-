local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")

local modReference
local player_manager = {
	items = {},
}

function player_manager.Init(mod)
	modReference = mod
	-- 确保攻击列表计算模块进入 package.loaded（避免回调中懒 require 失败）
	require("Qing_Remaster_scripts.player.attack_list_calculator")
	table.insert(player_manager.items,#player_manager.items + 1,require("Qing_Remaster_scripts.player.custom_attack_manager"))
	table.insert(player_manager.items,#player_manager.items + 1,require("Qing_Remaster_scripts.player.player_All"))
	table.insert(player_manager.items,#player_manager.items + 1,require("Qing_Remaster_scripts.player.player_wq"))
	table.insert(player_manager.items,#player_manager.items + 1,require("Qing_Remaster_scripts.player.player_Spwq"))
	table.insert(player_manager.items,#player_manager.items + 1,require("Qing_Remaster_scripts.player.player_Tecro"))
	table.insert(player_manager.items,#player_manager.items + 1,require("Qing_Remaster_scripts.player.player_Anna"))
	table.insert(player_manager.items,#player_manager.items + 1,require("Qing_Remaster_scripts.player.player_Autio"))
	table.insert(player_manager.items,#player_manager.items + 1,require("Qing_Remaster_scripts.player.player_Zeis"))
	table.insert(player_manager.items,#player_manager.items + 1,require("Qing_Remaster_scripts.player.player_Zeiz"))
	table.insert(player_manager.items,#player_manager.items + 1,require("Qing_Remaster_scripts.player.player_Tecrorun"))
	table.insert(player_manager.items,#player_manager.items + 1,require("Qing_Remaster_scripts.player.player_Anna2"))
end

return player_manager
