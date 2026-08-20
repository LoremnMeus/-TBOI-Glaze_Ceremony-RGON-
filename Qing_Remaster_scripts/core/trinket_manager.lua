local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")

local modReference
local item = {
	items = {},
}

function item.Init(mod)
	modReference = mod
	table.insert(item.items,#item.items + 1,require("Qing_Remaster_scripts.trinkets.Trinket_Pacification_Mark"))
	table.insert(item.items,#item.items + 1,require("Qing_Remaster_scripts.trinkets.Trinket_Dark_Particle"))
	table.insert(item.items,#item.items + 1,require("Qing_Remaster_scripts.trinkets.Trinket_Torn_Emperor"))
	table.insert(item.items,#item.items + 1,require("Qing_Remaster_scripts.trinkets.Trinket_Devil_s_Joke"))
	table.insert(item.items,#item.items + 1,require("Qing_Remaster_scripts.trinkets.Trinket_Puncture_Symbol"))
	table.insert(item.items,#item.items + 1,require("Qing_Remaster_scripts.trinkets.Trinket_Hoarding_Symbol"))
	table.insert(item.items,#item.items + 1,require("Qing_Remaster_scripts.trinkets.Trinket_Transition_Symbol"))
	table.insert(item.items,#item.items + 1,require("Qing_Remaster_scripts.trinkets.Trinket_Adhesive_Symbol"))
	table.insert(item.items,#item.items + 1,require("Qing_Remaster_scripts.trinkets.Trinket_Straining_Symbol"))
	table.insert(item.items,#item.items + 1,require("Qing_Remaster_scripts.trinkets.Trinket_Allocation_Symbol"))
	table.insert(item.items,#item.items + 1,require("Qing_Remaster_scripts.trinkets.Trinket_Pause_"))
	table.insert(item.items,#item.items + 1,require("Qing_Remaster_scripts.trinkets.Trinket_Equality_Agreement"))
	table.insert(item.items,#item.items + 1,require("Qing_Remaster_scripts.trinkets.Trinket_Consistent_Expectations"))
	table.insert(item.items,#item.items + 1,require("Qing_Remaster_scripts.trinkets.Trinket_Bundled_Sale"))
	table.insert(item.items,#item.items + 1,require("Qing_Remaster_scripts.trinkets.Trinket_Broken_Brooch"))
end

return item
