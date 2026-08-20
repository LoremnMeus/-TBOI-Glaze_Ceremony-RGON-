local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Trinkets.Transition_Symbol,
	own_key = "Trinkets_Transition_Symbol_",
	limit = 0.02,
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GET_TELEPORT, params = "door",
Function = function(_,player,tp,data)
	local room = Game():GetRoom()
	local level = Game():GetLevel()
	local door = data.door
	local player = auxi.have_player_has_trinket(item.entity)
	if door and door.TargetRoomIndex > 0 and player then
		local rng = player:GetTrinketRNG(item.entity)
		local tg = level:GetRoomByIdx(door.TargetRoomIndex)
		local desc = level:GetCurrentRoomDesc()
		local num = player:GetTrinketMultiplier(item.entity)
		if rng:RandomFloat() < item.limit * num and tg and tg.VisitedCount == 0 then 
			local dir = door.Direction
			Room_holder.Trans_to(-2,dir,RoomTransitionAnim.WALK,player,-1)
		end
	end
end,
})

return item