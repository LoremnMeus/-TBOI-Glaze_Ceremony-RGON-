local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	ToCall = {},
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, params = nil,
Function = function(_,Rng,spwnpos)
	local room = Game():GetRoom()
	local level = Game():GetLevel()
	local desc = level:GetCurrentRoomDesc()
	local stage = Game():GetLevel():GetStage()
	local stageType = level:GetStageType()
	if save.UnlockData.Others.Ending1.Unlock == true then
		if room:GetType() == RoomType.ROOM_BOSSRUSH and stageType >= StageType.STAGETYPE_REPENTANCE then
			local q = Isaac.Spawn(5,100,enums.Items.A_Shard_Of_Meat,room:FindFreeTilePosition(spwnpos + Vector(60,60),10),Vector(0,0),nil):ToPickup()
			q:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
		end
	end
end,
})

return item