local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")

local modReference
local manager = {
	items = {},
	params = {},
}

function manager.Init(mod)
	modReference = mod
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Keeper_Sack_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Restock_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Heart_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Knife_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Epic_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Tainted_Cain_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Ice_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Damo_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Isaacs_Tear_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Flat_Stone_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Crane_Game_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Habit_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Plug_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Book_of_Belial_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Lung_laser_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Bomb_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Laser_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Akeldama_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Bed_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Aquarius_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Projectile_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Damage_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Horn_hand_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Punch_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Jacob_ladder_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Dark_Art_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Time_Freeze_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Craft_Familiar_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Craft_Tear_Babies_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Craft_Laser_Babies_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Craft_Advanced_Familiars_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Character_Advanced_Familiars_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Character_Gello_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Craft_Charged_Familiars_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Craft_Dash_Familiars_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Craft_Projectile_Familiars_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Craft_Orbital_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Craft_Orbital_Batch2_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Craft_Follow_Extras_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Craft_Resource_Familiars_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Craft_Bobby_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Craft_Paschal_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Craft_Crown_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Craft_Ludovico_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Craft_Evil_Eye_holder"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.mimics.Craft_Aux_Entities_holder"))
	--manager.MakeItems()
end

function manager.MakeItems()	--没有传入参数。
	for i = 1,#manager.items do
		if manager.items[i].Init then
			manager.items[i].Init(modReference)
		end
	end
end

return manager
