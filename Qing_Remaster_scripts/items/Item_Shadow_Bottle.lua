local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Level_Shaddoll = require("Qing_Remaster_scripts.level.Level_Shaddoll")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Shadow_Bottle,
	own_key = "Item_Shadow_Bottle_",
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_)
	for u,v in pairs(Isaac.GetRoomEntities()) do
        if v:GetData()[item.own_key.."effect"] then
            v:ClearEntityFlags(EntityFlag.FLAG_FRIENDLY)
            v:Remove()
        end
    end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local cnt = auxi.get_player_have_collectible_num(item.entity)
	local room = Game():GetRoom()
	if room:IsFirstVisit() and room:IsClear() == false then
		for i = 1,cnt do
			local q = Level_Shaddoll.spawn_random_shadow(nil,{level = function() return auxi.random_in_weighed_table(Level_Shaddoll.weigh_table[1]).id end,})
			q:AddEntityFlags(EntityFlag.FLAG_FRIENDLY | EntityFlag.FLAG_CHARM)
			local d = q:GetData()
			d[item.own_key.."effect"] = true
		end
	end
end,
})

return item