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
	entity = enums.Cards.Faint_r,
	own_key = "Thoth_cd13r_Fai_",
}
table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local d = player:GetData()
	local idx = d.__Index
	if idx ~= nil then
		local val = d[item.own_key.."effect"]
		if val then
			if cacheFlag == CacheFlag.CACHE_DAMAGE then
				if val == 1 then
					player.Damage = player.Damage * 0.7
				elseif val == 2 then
					player.Damage = player.Damage * 0.4
				end
			end
			if cacheFlag == CacheFlag.CACHE_FIREDELAY then
				if val == 1 then
					player.MaxFireDelay = math.abs(player.MaxFireDelay) * 1.5
				elseif val == 2 then
					player.MaxFireDelay = math.abs(player.MaxFireDelay) * 2
				end
			end
			if cacheFlag == CacheFlag.CACHE_RANGE then
				if val == 1 then
					player.TearRange = math.abs(player.TearRange - 4 * 40) * 0.5 + 4 * 40
				elseif val == 2 then
					player.TearRange = math.abs(player.TearRange - 4 * 40) * 0.3 + 4 * 40
				end
			end
			if cacheFlag == CacheFlag.CACHE_SPEED then
				if val == 1 then
					player.MoveSpeed = math.abs(player.MoveSpeed - 0.5) * 0.7 + 0.5
				elseif val == 2 then
					player.MoveSpeed = math.abs(player.MoveSpeed - 0.5) * 0.5 + 0.5
				end
			end
			if cacheFlag == CacheFlag.CACHE_LUCK then
				if val == 1 then
					player.Luck = math.abs(player.Luck - 2) * 1.5 + 2
				elseif val == 2 then
					player.Luck = math.abs(player.Luck - 4) * 2 + 4
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local d = player:GetData()
		d[item.own_key.."effect"] = 0
		player:AddCacheFlags(CacheFlag.CACHE_ALL)
		player:GetData().should_evaluate_on_update_once = true
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_,ent,amt,flag,source,cooldown)
	local player = ent:ToPlayer()
	if player then
		local rng = player:GetCardRNG(item.entity)
		rng = auxi.rng_for_sake(rng)
		local room = Game():GetRoom()
		local d = player:GetData()
		if d[item.own_key.."effect"] then
			local rnd = 0
			if d[item.own_key.."effect"] == 1 then
				rnd = rng:RandomInt(1000)
			elseif d[item.own_key.."effect"] == 2 then
				rnd = rng:RandomInt(1400)
			end
			if rnd > 550 then
				if d[item.own_key.."effect"] == 2 and rnd > 1300 then
					Isaac.Spawn(5,0,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
				else
					if auxi.is_player_only_soul_hearts(player) then
						local rnd = rng:RandomInt(1000)
						if rnd > 700 then
							Isaac.Spawn(5,10,3,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
						else
							Isaac.Spawn(5,10,8,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
						end
					elseif auxi.is_player_only_coin_hearts(player) then
						Isaac.Spawn(5,20,1,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
					elseif auxi.is_player_only_red_hearts(player) then
						if rnd > 950 then
							Isaac.Spawn(5,10,5,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
						elseif rnd > 700 then
							Isaac.Spawn(5,10,1,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
						else
							Isaac.Spawn(5,10,2,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
						end
					else
						Isaac.Spawn(5,10,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
					end
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local rng = player:GetCardRNG(cardtype)
	rng = auxi.rng_for_sake(rng)
	local d = player:GetData()
	local idx = d.__Index
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		d[item.own_key.."effect"] = 1
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
			d[item.own_key.."effect"] = 2
		end
		player:AddCacheFlags(CacheFlag.CACHE_ALL)
		player:GetData().should_evaluate_on_update_once = true
	end
end,
})

return item