local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local dropping_holder = require("Qing_Remaster_scripts.others.Dropping_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local Achievement_Display_holder = require("Qing_Remaster_scripts.others.Achievement_Display_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Star,
	own_key = "Thoth_cd17_Sta_",
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = nil,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	
	if useFlags & UseFlag.USE_OWNED == UseFlag.USE_OWNED and (useFlags & UseFlag.USE_CARBATTERY ~= UseFlag.USE_CARBATTERY) then
		save.elses[item.own_key.."effect"][idx] = true
	else
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[item.own_key.."effect"] = {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		if save.elses[item.own_key.."effect"][idx] then
			local q = Isaac.Spawn(5,10,2,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
			q:Morph(5,10,2,true,true,true)
		else
			local q = Isaac.Spawn(5,10,1,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
			q:Morph(5,10,1,true,true,true)
			local q = Isaac.Spawn(5,10,3,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
			q:Morph(5,10,3,true,true,true)
			local q = Isaac.Spawn(5,10,4,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
			q:Morph(5,10,4,true,true,true)
			if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
				local q = Isaac.Spawn(5,10,6,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
				q:Morph(5,10,6,true,true,true)
				local q = Isaac.Spawn(5,10,10,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
				q:Morph(5,10,10,true,true,true)
				local q = Isaac.Spawn(5,10,11,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
				q:Morph(5,10,11,true,true,true)
			end
		end
	end
end,
})


return item