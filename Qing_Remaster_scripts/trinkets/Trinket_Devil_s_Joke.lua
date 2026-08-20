local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Trinkets.Devil_s_Joke,
	own_key = "Trinkets_Devil_s_Joke_",
	Dir_map = {
		[0] = {1,2,3,},
		[1] = {0,2,},
		[2] = {0,1,3,},
		[3] = {0,1,2,},
	},
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GET_TELEPORT, params = "door",
Function = function(_,player,tp,data)
	local room = Game():GetRoom()
	local level = Game():GetLevel()
	local door = data.door
	if door and door.TargetRoomIndex == -1 and auxi.have_player_has_trinket(item.entity) then
		local desc = level:GetRoomByIdx(-1)
		if desc and desc.Data then
		else level:InitializeDevilAngelRoom(false,false) end
		if desc and desc.Data and desc.Data.Type == RoomType.ROOM_DEVIL then
			if math.random(100) > 50 and not door.Direction == 1 then level.LeaveDoor = auxi.flipdirection(door.Direction) or auxi.choose(0,1,2,3)
			else level.LeaveDoor = auxi.choose2(item.Dir_map[door.Direction] or {0,1,2,3,}) end
			Game():StartRoomTransition(-1,door.Direction,RoomTransitionAnim.WALK, player)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if desc.SafeGridIndex == -1 and desc.Data.Type == RoomType.ROOM_DEVIL and Game():GetRoom():IsFirstVisit() then
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			if player:HasTrinket(item.entity) then
				player:AnimateCollectible(105,"Pickup","PlayerPickupSparkle")
				player:SetPocketActiveItem(105,ActiveSlot.SLOT_POCKET2,true)
			end
		end
	end
end,
})

return item