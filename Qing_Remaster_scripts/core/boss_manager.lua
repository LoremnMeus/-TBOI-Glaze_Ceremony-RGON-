-- Runtime callback registration for Boss encounters and Boss modules.
-- Metadata / Wiki / Test Lab remain in boss_defs / boss_registry / boss_test_registry.
-- Do NOT put ordinary enemies here — those stay in enemy_manager.

local Boss_manager = {
	items = {},
}

local modReference

function Boss_manager.Init(mod)
	modReference = mod

	-- Floraine V2: sole Boss owner. Shared chess-piece NPC adapter stays registered.
	table.insert(Boss_manager.items, #Boss_manager.items + 1,
		require("Qing_Remaster_scripts.bosses.Floraine.Enemy_chess_pawn"))
	table.insert(Boss_manager.items, #Boss_manager.items + 1,
		require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.init"))

	-- Zennith encounter (Zennith_post is not registered by historical enemy_manager — keep that)
	table.insert(Boss_manager.items, #Boss_manager.items + 1,
		require("Qing_Remaster_scripts.bosses.Zennith.Zennith"))
	table.insert(Boss_manager.items, #Boss_manager.items + 1,
		require("Qing_Remaster_scripts.threads.wind.wind_runtime"))

	-- Bum Emperor encounter
	table.insert(Boss_manager.items, #Boss_manager.items + 1,
		require("Qing_Remaster_scripts.bosses.Bum_Emperor.enemy_bum_emperor"))
	table.insert(Boss_manager.items, #Boss_manager.items + 1,
		require("Qing_Remaster_scripts.bosses.Bum_Emperor.enemy_bum_guard"))
	table.insert(Boss_manager.items, #Boss_manager.items + 1,
		require("Qing_Remaster_scripts.bosses.Bum_Emperor.enemy_bum_spear"))
	table.insert(Boss_manager.items, #Boss_manager.items + 1,
		require("Qing_Remaster_scripts.bosses.Bum_Emperor.enemy_bum_arrow"))

	-- Existing bosses previously registered via enemy_manager
	table.insert(Boss_manager.items, #Boss_manager.items + 1,
		require("Qing_Remaster_scripts.bosses.Boss_All"))
	table.insert(Boss_manager.items, #Boss_manager.items + 1,
		require("Qing_Remaster_scripts.bosses.Boss_Autio"))
	table.insert(Boss_manager.items, #Boss_manager.items + 1,
		require("Qing_Remaster_scripts.bosses.Boss_Zeistos"))
	table.insert(Boss_manager.items, #Boss_manager.items + 1,
		require("Qing_Remaster_scripts.bosses.Boss_ZeistosHelper"))
	table.insert(Boss_manager.items, #Boss_manager.items + 1,
		require("Qing_Remaster_scripts.bosses.Boss_Glaze"))
	table.insert(Boss_manager.items, #Boss_manager.items + 1,
		require("Qing_Remaster_scripts.bosses.Boss_Qing"))
	table.insert(Boss_manager.items, #Boss_manager.items + 1,
		require("Qing_Remaster_scripts.bosses.Boss_Absurd"))
end

return Boss_manager
