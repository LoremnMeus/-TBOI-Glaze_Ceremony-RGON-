local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Item_Disequilibrium = require("Qing_Remaster_scripts.items.Item_Disequilibrium")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Heart_Change,
	costumes = {
		[1] = enums.Costumes.Heart_Change_1,
		[2] = enums.Costumes.Heart_Change_2,
		[3] = enums.Costumes.Heart_Change_3,
		[4] = enums.Costumes.Heart_Change_4,
	},
	own_key = "Item_Heart_Change_"
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if auxi.has_have_coll(player,item.entity) then
		if cacheFlag == CacheFlag.CACHE_FLYING then
			local idx = player:GetData().__Index
			if idx then
				save.elses[item.own_key.."state"] = save.elses[item.own_key.."state"] or {}
				if (save.elses[item.own_key.."state"][idx] or 0) == 0 then
					player.CanFly = true
				end
			end
		end
	end
end,
})

local function check_costume(player)
	for i = 1,4 do
		player:TryRemoveNullCostume(item.costumes[i])
	end
	local idx = player:GetData().__Index
	if idx then
		save.elses[item.own_key.."state"] = save.elses[item.own_key.."state"] or {}
		player:AddNullCostume(item.costumes[(save.elses[item.own_key.."state"][idx] or 0) + 1])
	end
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = item.entity,
Function = function(_,player,collid,count,lastnumber)
	if count < 0 and auxi.has_have_coll(player,item.entity) == false then
		for i = 1,4 do
			player:TryRemoveNullCostume(item.costumes[i])
		end
	end
	if count > 0 and player:GetCollectibleNum(item.entity,true) == count then
		local idx = player:GetData().__Index
		if idx then
			player:AddNullCostume(item.costumes[(save.elses[item.own_key.."state"][idx] or 0) + 1])
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."state"] = {}
	end
	save.elses[item.own_key.."state"] = save.elses[item.own_key.."state"] or {}
end,
})


table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local level = Game():GetLevel()
	local room = Game():GetRoom()
	local desc = level:GetCurrentRoomDesc()
	if room:IsFirstVisit() and desc then
		if desc.Data.Type == 14 or Item_Disequilibrium.is_dual_room() then
			for playerNum = 1, Game():GetNumPlayers() do
				local player = Game():GetPlayer(playerNum - 1)
				if auxi.has_have_coll(player,item.entity) then
					local idx = player:GetData().__Index
					if idx then
						save.elses[item.own_key.."state"] = save.elses[item.own_key.."state"] or {}
						if (save.elses[item.own_key.."state"][idx] or 0) & 1 == 0 then
							save.elses[item.own_key.."state"][idx] = (save.elses[item.own_key.."state"][idx] or 0) | 1
							player:AddCacheFlags(CacheFlag.CACHE_FLYING)
							player:GetData().should_evaluate_on_update_once = true
							local q = Isaac.Spawn(5,10,6,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
						end
					end
					check_costume(player)
				end
			end
		end
		if desc.Data.Type == 15 or Item_Disequilibrium.is_dual_room() then
			for playerNum = 1, Game():GetNumPlayers() do
				local player = Game():GetPlayer(playerNum - 1)
				if auxi.has_have_coll(player,item.entity) then
					local idx = player:GetData().__Index
					if idx then
						save.elses[item.own_key.."state"] = save.elses[item.own_key.."state"] or {}
						if (save.elses[item.own_key.."state"][idx] or 0) & 2 == 0 then
							save.elses[item.own_key.."state"][idx] = (save.elses[item.own_key.."state"][idx] or 0) | 2
							player:AddCacheFlags(CacheFlag.CACHE_FLYING)
							player:GetData().should_evaluate_on_update_once = true
							local q = Isaac.Spawn(5,10,4,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
						end
					end
					check_costume(player)
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
Function = function(_)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.has_have_coll(player,item.entity) then
			local idx = player:GetData().__Index
			if idx then
				save.elses[item.own_key.."state"] = save.elses[item.own_key.."state"] or {}
				if (save.elses[item.own_key.."state"][idx] or 0) == 3 then
					local room = Game():GetRoom()
					save.elses[item.own_key.."state"][idx] = 0
					player:AddCacheFlags(CacheFlag.CACHE_FLYING)
					player:GetData().should_evaluate_on_update_once = true
					check_costume(player)
					player:AnimateHappy()
					local rng = player:GetCollectibleRNG(item.entity)
					rng = auxi.rng_for_sake(rng)
					local itempool = Game():GetItemPool()
					local col1 = itempool:GetCollectible (3,true,rng:GetSeed())
					rng:Next()
					local col2 = itempool:GetCollectible (4,true,rng:GetSeed())
					rng:Next()
					local q = Isaac.Spawn(5,100,col1,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
					local q2 = Isaac.Spawn(5,100,col2,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
				end
			end
		end
	end
end,
})

return item