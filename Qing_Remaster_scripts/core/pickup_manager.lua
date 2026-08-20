local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")

local modReference
local Pickup_manager = {
	items = {},
}

function Pickup_manager.Init(mod)
	modReference = mod
	table.insert(Pickup_manager.items,#Pickup_manager.items + 1,require("Qing_Remaster_scripts.pickups.pickup_glaze_heart"))
	table.insert(Pickup_manager.items,#Pickup_manager.items + 1,require("Qing_Remaster_scripts.pickups.pickup_glaze_key"))
	table.insert(Pickup_manager.items,#Pickup_manager.items + 1,require("Qing_Remaster_scripts.pickups.pickup_glaze_bomb"))
	table.insert(Pickup_manager.items,#Pickup_manager.items + 1,require("Qing_Remaster_scripts.pickups.pickup_glaze_coin"))
	table.insert(Pickup_manager.items,#Pickup_manager.items + 1,require("Qing_Remaster_scripts.pickups.pickup_glaze_dice_shard"))
	table.insert(Pickup_manager.items,#Pickup_manager.items + 1,require("Qing_Remaster_scripts.pickups.pickup_glaze_battery"))
	table.insert(Pickup_manager.items,#Pickup_manager.items + 1,require("Qing_Remaster_scripts.pickups.pickup_glaze_grabbag"))
	table.insert(Pickup_manager.items,#Pickup_manager.items + 1,require("Qing_Remaster_scripts.pickups.pickup_glaze_spider"))
	table.insert(Pickup_manager.items,#Pickup_manager.items + 1,require("Qing_Remaster_scripts.pickups.pickup_glaze_enemy"))		--10
	table.insert(Pickup_manager.items,#Pickup_manager.items + 1,require("Qing_Remaster_scripts.pickups.pickup_glaze_poop"))
	table.insert(Pickup_manager.items,#Pickup_manager.items + 1,require("Qing_Remaster_scripts.pickups.pickup_glaze_chest"))
	table.insert(Pickup_manager.items,#Pickup_manager.items + 1,require("Qing_Remaster_scripts.pickups.pickup_glaze_Trip_Ticket"))
	table.insert(Pickup_manager.items,#Pickup_manager.items + 1,require("Qing_Remaster_scripts.pickups.pickup_glaze_curse"))
	table.insert(Pickup_manager.items,#Pickup_manager.items + 1,require("Qing_Remaster_scripts.pickups.pickup_blueprint_prototype"))
	--Pickup_manager.MakeItems()
end

function Pickup_manager.MakeItems()	--没有传入参数。
	for i = 1,#Pickup_manager.items do
		if Pickup_manager.items[i].ToCall then
			for j = 1,#(Pickup_manager.items[i].ToCall) do
				if Pickup_manager.items[i].ToCall[j] ~= nil and Pickup_manager.items[i].ToCall[j].Function ~= nil and Pickup_manager.items[i].ToCall[j].CallBack ~= nil then
					if Pickup_manager.items[i].ToCall[j].params == nil then
						modReference:AddCallback(Pickup_manager.items[i].ToCall[j].CallBack,Pickup_manager.items[i].ToCall[j].Function)
					else
						modReference:AddCallback(Pickup_manager.items[i].ToCall[j].CallBack,Pickup_manager.items[i].ToCall[j].Function,Pickup_manager.items[i].ToCall[j].params)
					end
				end
			end
		end
	end
end

return Pickup_manager
