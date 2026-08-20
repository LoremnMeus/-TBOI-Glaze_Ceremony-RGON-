local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	entity = enums.Items.Hyper_Velocity,
	pickup = enums.Cards.Round_trip_Rail_Ticket,
	pickup2 = enums.Cards.One_way_Rail_Ticket,
	ToCall = {},
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.pickup,
Function = function(_,card,player,useflags)
	if card == item.pickup then
		local room = Game():GetRoom()
		local d = player:GetData()
		player:AnimateCard(item.pickup,"LiftItem")
		d.is_holding_H_V_item = true
		d.is_holding_H_V_card = item.pickup2
		Isaac.Spawn(5,300,item.pickup2,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.pickup2,
Function = function(_,card,player,useflags)
	if card == item.pickup2 then
		local room = Game():GetRoom()
		local d = player:GetData()
		d.is_holding_H_V_card = item.pickup2
		player:AnimateCard(item.pickup2,"LiftItem")
		d.is_holding_H_V_item = true
	end
end,
})

return item