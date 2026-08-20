local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local console_holder = require("Qing_Remaster_scripts.others.Console_holder")

local modReference
local item = {
	ToCall = {},
	challange = enums.Challenges.Feels_Like_Dead_Ashes,
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local room = Game():GetRoom()
	local level = Game():GetLevel()
	if Game().Challenge == item.challange and room:IsFirstVisit() then
		local desc = level:GetRoomByIdx(level:GetCurrentRoomDesc().SafeGridIndex)
		if desc then
			desc.Flags = desc.Flags | RoomDescriptor.FLAG_CURSED_MIST
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue == false and Game().Challenge == item.challange then
		console_holder.try_close_console()
	end
end,
})

return item
