local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")

local modReference
local manager = {
	items = {},
}

function manager.Init(mod)
	modReference = mod
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_All"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_00_Fool"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_00r_Fool"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_01_Witch"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_01_Invoker"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_01_Wizard"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_01r_Sage"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_02_Priestess"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_02r_Priestess"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_03_Empress"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_03r_Empress"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_04_Emperor"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_04r_Emperor"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_05_Hierophant"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_05r_Hierophant"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_06_Lover"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_06r_lover"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_07_Chariot"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_07r_Chariot"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_08_Adjustment"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_08r_Adjustment"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_09_Hermit"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_09r_Hermit"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_10_Wheel_of_Destiny"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_10r_Wheel_of_Destiny"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_11_Lure"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_11r_Lure"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_12_Hanged_Man"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_12r_Hanged_Man"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_13_Faint"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_13r_Faint"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_13r_Corpse"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_13r_Death"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_14_Art"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_14r_Art"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_15_Devil"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_15r_Devil"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_16_Tower"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_16r_Tower"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_17_Star"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_17r_Star"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_18_Moon"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_18r_Moon"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_19_Sun"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_19r_Sun"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_20_Aeon"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_20r_Aeon"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_21_Universe"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_21r_Universe"))
	
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.sins.rune_Qing_s_soul"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.sins.rune_Tecro_s_soul"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.sins.rune_Anna_s_soul"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.sins.rune_Zeis_s_soul"))
	
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_19_Eclipse"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_19r_Eclipse"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_21_Profound"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_21r_Profound"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_05_Sting"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.cards.Card_05r_Sting"))
	--manager.Make()
end

function manager.Make()				--没有传入参数。
	for i = 1,#manager.items do
		if manager.items[i].ToCall then
			for j = 1,#(manager.items[i].ToCall) do
				if manager.items[i].ToCall[j] ~= nil and manager.items[i].ToCall[j].Function ~= nil and manager.items[i].ToCall[j].CallBack ~= nil then
					if manager.items[i].ToCall[j].params == nil then
						modReference:AddCallback(manager.items[i].ToCall[j].CallBack,manager.items[i].ToCall[j].Function)
					else
						modReference:AddCallback(manager.items[i].ToCall[j].CallBack,manager.items[i].ToCall[j].Function,manager.items[i].ToCall[j].params)
					end
				end
			end
		end
	end
end

return manager
