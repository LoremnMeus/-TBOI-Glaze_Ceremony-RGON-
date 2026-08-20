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
	entity = enums.Items.Contemplation,
	own_key = "Item_Contemplation_",
	limit = 0.04,
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GET_TELEPORT, params = "door",
Function = function(_,player,tp,data)
	local room = Game():GetRoom()
	local level = Game():GetLevel()
	local door = data.door
	local player = auxi.have_player_has_collectible(item.entity)
	if door and door.TargetRoomIndex > 0 and player and auxi.GetDimension() ~= 2 then
		local rng = player:GetCollectibleRNG(item.entity)
		local tg = level:GetRoomByIdx(door.TargetRoomIndex)
		local desc = level:GetCurrentRoomDesc()
		local num = auxi.get_player_have_collectible_num(item.entity)
		if rng:RandomFloat() < item.limit * num and tg and tg.VisitedCount == 0 then 
			player:UseActiveItem(CollectibleType.COLLECTIBLE_DEATH_CERTIFICATE,UseFlag.USE_NOANIM)
			player:StopExtraAnimation()
			local dir = door.Direction
			local rooms = level:GetRooms()
			local tbl = {}	
			for i = 1, rooms.Size do
				local targ = rooms:Get(i - 1)
				if auxi.GetDimension(targ) == 2 and targ.Data and (targ.Data.Doors & (1<<dir) == (1<< dir) or targ.Data.Doors & (1<<(dir + 4)) == (1<<(dir + 4))) then table.insert(tbl,#tbl + 1,targ) end
			end
			local rnd = auxi.random_in_table(tbl,rng)
			if rnd.Data.Doors & (1<<dir) == (1<<dir) then level.LeaveDoor = dir
			else level.LeaveDoor = dir + 4 end
			Room_holder.Trans_to(rnd.SafeGridIndex,dir,RoomTransitionAnim.WALK,player,2)
			if not auxi.has_zeis() then 
				save.elses[item.own_key.."effect"] = {dim = auxi.GetDimension(),sgid = door.TargetRoomIndex,counter = auxi.choose(30,60,90),}
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if save.elses[item.own_key.."effect"] then
		save.elses[item.own_key.."effect"].counter = (save.elses[item.own_key.."effect"].counter or 0) - 1
		if save.elses[item.own_key.."effect"].counter <= 0 then
			local player = auxi.have_player_has_collectible(item.entity) or Game():GetPlayer(0)
			Room_holder.Trans_to(save.elses[item.own_key.."effect"].sgid,-1,RoomTransitionAnim.TELEPORT,player,save.elses[item.own_key.."effect"].dim)
			save.elses[item.own_key.."effect"] = nil
		end
		if auxi.GetDimension() ~= 2 then save.elses[item.own_key.."effect"] = nil end
	end
end,
})

return item