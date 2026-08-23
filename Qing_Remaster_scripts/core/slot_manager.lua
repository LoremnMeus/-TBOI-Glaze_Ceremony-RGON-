local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")

local modReference
local Slot_manager = {
	items = {},
}

function Slot_manager.Init(mod)
	modReference = mod
	table.insert(Slot_manager.items,#Slot_manager.items + 1,require("Qing_Remaster_scripts.slots.Slot_Bard_Beggar"))
	table.insert(Slot_manager.items,#Slot_manager.items + 1,require("Qing_Remaster_scripts.slots.Slot_Tomorrows_Creditor"))
	table.insert(Slot_manager.items,#Slot_manager.items + 1,require("Qing_Remaster_scripts.slots.Slot_Rift_Beggar"))
	table.insert(Slot_manager.items,#Slot_manager.items + 1,require("Qing_Remaster_scripts.slots.Slot_Bloody_Messenger"))
end

function Slot_manager.MakeItems()	--没有传入参数。
	for i = 1,#Slot_manager.items do
		if Slot_manager.items[i].ToCall then
			for j = 1,#(Slot_manager.items[i].ToCall) do
				if Slot_manager.items[i].ToCall[j] ~= nil and Slot_manager.items[i].ToCall[j].Function ~= nil and Slot_manager.items[i].ToCall[j].CallBack ~= nil then
					if Slot_manager.items[i].ToCall[j].params == nil then
						modReference:AddCallback(Slot_manager.items[i].ToCall[j].CallBack,Slot_manager.items[i].ToCall[j].Function)
					else
						modReference:AddCallback(Slot_manager.items[i].ToCall[j].CallBack,Slot_manager.items[i].ToCall[j].Function,Slot_manager.items[i].ToCall[j].params)
					end
				end
			end
		end
	end
end

return Slot_manager
