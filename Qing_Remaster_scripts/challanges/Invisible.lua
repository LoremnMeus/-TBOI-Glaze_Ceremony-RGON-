local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local modReference
local item = {
	ToCall = {},
	challange = enums.Challenges.Invisible,
	room_counter = Color(1,1,1,1),
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	if Game().Challenge == item.challange then
		item.room_counter = Color(1,1,1,1)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if Game().Challenge == item.challange then
		local n_entity = Isaac.GetRoomEntities()
		for u,v in pairs(n_entity) do
			local s = v:GetSprite()
			s.Color = auxi.AddColor(s.Color,Color(1,1,1,0),0.9,0.1)
		end
		local room = Game():GetRoom()
		if item.room_counter == nil then item.room_counter = Color(1,1,1,1) end
		item.room_counter = auxi.AddColor(item.room_counter,Color(1,1,1,0),0.9,0.1)
		room:SetFloorColor(item.room_counter)
		room:SetWallColor(item.room_counter)
	end
end,
})

return item
