local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")

local modReference
local Challanges_manager = {
	items = {},
	params = {},
}

function Challanges_manager.Init(mod)
	modReference = mod
	table.insert(Challanges_manager.items,#Challanges_manager.items + 1,require("Qing_Remaster_scripts.challanges.Fusion_Destiny"))
	table.insert(Challanges_manager.items,#Challanges_manager.items + 1,require("Qing_Remaster_scripts.challanges.Fans_Service"))
	table.insert(Challanges_manager.items,#Challanges_manager.items + 1,require("Qing_Remaster_scripts.challanges.Heterothermal_Concentric"))
	table.insert(Challanges_manager.items,#Challanges_manager.items + 1,require("Qing_Remaster_scripts.challanges.Feels_Like_Dead_Ashes"))
	table.insert(Challanges_manager.items,#Challanges_manager.items + 1,require("Qing_Remaster_scripts.challanges.Fake_Image"))
	table.insert(Challanges_manager.items,#Challanges_manager.items + 1,require("Qing_Remaster_scripts.challanges.Louvre_puzzle"))
	table.insert(Challanges_manager.items,#Challanges_manager.items + 1,require("Qing_Remaster_scripts.challanges.Unstable_State"))
	table.insert(Challanges_manager.items,#Challanges_manager.items + 1,require("Qing_Remaster_scripts.challanges.Cookie_Clicker"))
	table.insert(Challanges_manager.items,#Challanges_manager.items + 1,require("Qing_Remaster_scripts.challanges.Invisible"))
	table.insert(Challanges_manager.items,#Challanges_manager.items + 1,require("Qing_Remaster_scripts.challanges.Safe_Driving"))
	table.insert(Challanges_manager.items,#Challanges_manager.items + 1,require("Qing_Remaster_scripts.challanges.Swallow_The_Sun"))
	table.insert(Challanges_manager.items,#Challanges_manager.items + 1,require("Qing_Remaster_scripts.challanges.Dragon_Flight"))
	--Challanges_manager.MakeItems()
end

function Challanges_manager.MakeItems()	--没有传入参数。
	for i = 1,#Challanges_manager.items do
		if Challanges_manager.items[i].ToCall then
			for j = 1,#(Challanges_manager.items[i].ToCall) do
				if Challanges_manager.items[i].ToCall[j] ~= nil and Challanges_manager.items[i].ToCall[j].Function ~= nil and Challanges_manager.items[i].ToCall[j].CallBack ~= nil then
					if Challanges_manager.items[i].ToCall[j].params == nil then
						modReference:AddCallback(Challanges_manager.items[i].ToCall[j].CallBack,Challanges_manager.items[i].ToCall[j].Function)
					else
						modReference:AddCallback(Challanges_manager.items[i].ToCall[j].CallBack,Challanges_manager.items[i].ToCall[j].Function,Challanges_manager.items[i].ToCall[j].params)
					end
				end
			end
		end
	end
end

return Challanges_manager
