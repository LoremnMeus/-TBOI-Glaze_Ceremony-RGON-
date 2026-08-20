local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Sun,
	own_key = "Thoth_cd19_Sun_",
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
		save.elses[item.own_key.."effect2"] = {}
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	save.elses[item.own_key.."effect2"] = save.elses[item.own_key.."effect2"] or {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	save.elses[item.own_key.."effect"] = {}
	save.elses[item.own_key.."effect2"] = {}
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local d = player:GetData()
		d[item.own_key.."effect"] = {}
		d[item.own_key.."counter"] = 0
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	if #(d[item.own_key.."effect"] or {}) > 0 then
		if player:IsExtraAnimationFinished() then
			player:UseCard(d[item.own_key.."effect"][1].id,0)
			table.remove(d[item.own_key.."effect"],1)
			d[item.own_key.."counter"] = (d[item.own_key.."counter"] or 0) + 1
			if d[item.own_key.."counter"] == 3 then
				local q = Isaac.Spawn(5,300,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
			end
			if save.elses[item.own_key.."effect2"][idx] and d[item.own_key.."counter"] == 10 then
				local q = Isaac.Spawn(5,100,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
				--q:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
			end
		end
	else
		if d[item.own_key.."counter"] then d[item.own_key.."counter"] = nil end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = nil,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	local rng = player:GetCardRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		save.elses[item.own_key.."effect"][idx] = save.elses[item.own_key.."effect"][idx] or {}
		table.insert(save.elses[item.own_key.."effect"][idx],#save.elses[item.own_key.."effect"][idx] + 1,{id = cardtype,})
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	local rng = player:GetCardRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then save.elses[item.own_key.."effect2"][idx] = true end
		save.elses[item.own_key.."effect"][idx] = save.elses[item.own_key.."effect"][idx] or {}
		d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}
		for i = 1,#save.elses[item.own_key.."effect"][idx] do
			local v = save.elses[item.own_key.."effect"][idx][i]
			if v.id ~= cardtype then
				table.insert(d[item.own_key.."effect"],#d[item.own_key.."effect"] + 1,{id = v.id})
			end
		end
		save.elses[item.own_key.."effect"][idx] = {}
	end
end,
})

return item