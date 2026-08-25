local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local dev_env = require("Qing_Remaster_scripts.core.dev_environment")

local modReference
local Others_manager = {
	items = {},
	params = {},
}

function Others_manager.Init(mod)
	modReference = mod
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.auxiliary.delay_buffer"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Time_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.core.globals"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.core.savedata"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.core.completion_marks_manager"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.core.achievement_tracker"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.core.unlock_manager"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Input_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Console_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Dropping_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Attribute_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Charging_Bar_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.HUD_Chargebar_Overlay_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Costume_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Consistance_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Tarot_Cloth_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Option_Index_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Record_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Damage_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.craft_dynamic_stats"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.blueprint_craft_eid"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.blueprint_tutorial"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.craft_on_hurt_router"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.craft_aura_effects"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.craft_charge_weapons"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.craft_orbiting_tears"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.craft_zodiac"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.craft_taurus"))
	do
		local probes = {
			"Qing_Remaster_scripts.others.craft_orbiting_tear_offset_probe",
			"Qing_Remaster_scripts.others.craft_laser_flag_probe",
			"Qing_Remaster_scripts.others.craft_knife_path_probe",
			"Qing_Remaster_scripts.others.craft_evil_eye_vanilla_probe",
			"Qing_Remaster_scripts.others.vengeful_spirit_vanilla_probe",
			"Qing_Remaster_scripts.others.vengeful_craft_lifecycle_probe",
			"Qing_Remaster_scripts.others.craft_path_tear_vanilla_probe",
			"Qing_Remaster_scripts.others.craft_floor_stat_counter_probe",
			"Qing_Remaster_scripts.others.time_stop_probe",
			"Qing_Remaster_scripts.others.destiny_anchor_probe",
		}
		for _, path in ipairs(probes) do
			local mod = dev_env.require_probe(path)
			if mod then table.insert(Others_manager.items,#Others_manager.items + 1,mod) end
		end
	end
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Achievement_Display_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.GiantBook_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Screen_Filter"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.selection_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.fullscreen_select_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Unique_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Nil_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Color_cross_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Completion_Marks_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Console_hack_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Pause_Screen_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Mod_Config_Menu_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Room_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.EID_description_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Reverie_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Entity_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Shader_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.dynamic_lighting_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Chinese_input_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Eraser_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Dialog_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Boss_Sprite_holder"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Item_color_holder"))
	--table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.others.Imitate_item_holder"))		--已转移
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.translations.zh"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.translations.EID"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.translations.Encyclopedia"))
	table.insert(Others_manager.items,#Others_manager.items + 1,require("Qing_Remaster_scripts.auxiliary.ui"))
	Others_manager.MakeItems()
end

function Others_manager.MakeItems()	--没有传入参数。
	for i = 1,#Others_manager.items do
		if Others_manager.items[i].Init then
			Others_manager.items[i].Init(modReference)
		end
	end
end

return Others_manager
