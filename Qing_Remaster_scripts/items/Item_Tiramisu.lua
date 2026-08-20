local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Items.Tiramisu,
	buffs = {
		[1] = {name = "damage",cache = CacheFlag.CACHE_DAMAGE,
			toget = function(player) return player.Damage end,},
		[2] = {name = "tear",cache = CacheFlag.CACHE_FIREDELAY,
			toget = function(player) return 30 / (player.MaxFireDelay + 1) end,},
		[3] = {name = "speed",cache = CacheFlag.CACHE_SPEED,
			toget = function(player) return player.MoveSpeed end,},
		[4] = {name = "range",cache = CacheFlag.CACHE_RANGE,
			toget = function(player) return player.TearRange end,},
		[5] = {name = "luck",cache = CacheFlag.CACHE_LUCK,
			toget = function(player) return player.Luck end,},
		[6] = {name = "shotspeed",cache = CacheFlag.CACHE_SHOTSPEED,
			toget = function(player) return player.ShotSpeed end,},
	},
	own_key = "Item_Tiramisu_",
}

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if auxi.has_have_coll(player,item.entity) then
		local idx = player:GetData().__Index
		if idx ~= nil then
			save.elses[item.own_key.."buff"] = save.elses[item.own_key.."buff"] or {}
			save.elses[item.own_key.."lock"] = save.elses[item.own_key.."lock"] or {}
			if save.elses[item.own_key.."lock"][idx] then
				save.elses[item.own_key.."buff"][idx] = save.elses[item.own_key.."buff"][idx] or {}
				if cacheFlag == CacheFlag.CACHE_DAMAGE then
					player.Damage = player.Damage + math.min(10,(save.elses[item.own_key.."buff"][idx].damage or 0))
				end
				if cacheFlag == CacheFlag.CACHE_FIREDELAY then
					player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay,(save.elses[item.own_key.."buff"][idx].tear or 0))
				end
				if cacheFlag == CacheFlag.CACHE_RANGE then
					player.TearRange = player.TearRange + (save.elses[item.own_key.."buff"][idx].range or 0)
				end
				if cacheFlag == CacheFlag.CACHE_SPEED then
					player.MoveSpeed = player.MoveSpeed + (save.elses[item.own_key.."buff"][idx].speed or 0)
				end
				if cacheFlag == CacheFlag.CACHE_LUCK then
					player.Luck = player.Luck + (save.elses[item.own_key.."buff"][idx].luck or 0)
				end
				if cacheFlag == CacheFlag.CACHE_SHOTSPEED then
					player.ShotSpeed = player.ShotSpeed + (save.elses[item.own_key.."buff"][idx].shotspeed or 0)
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.has_have_coll(player,item.entity) then
			local idx = player:GetData().__Index
			if Game():GetFrameCount() % 10 == 5 and save.elses[item.own_key.."lock"][idx] then
				save.elses[item.own_key.."buff"][idx] = save.elses[item.own_key.."buff"][idx] or {}
				for i = 1,6 do
					local info = item.buffs[i]
					if (save.elses[item.own_key.."buff"][idx][info.name] or 0) > 0 then
						save.elses[item.own_key.."buff"][idx][info.name] = save.elses[item.own_key.."buff"][idx][info.name] * 0.99
						player:AddCacheFlags(info.cache)
						player:GetData().should_evaluate_on_update_once = true
					end
				end
				if save.elses[item.own_key.."save"][idx].valued then
				else
					save.elses[item.own_key.."save"][idx].value = (save.elses[item.own_key.."save"][idx].value or 0.5) * 0.9 + 0.5 * 0.1
				end
				save.elses[item.own_key.."save"][idx].valued = nil
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if auxi.has_have_coll(player,item.entity) then
		local idx = player:GetData().__Index
		if idx and save.elses[item.own_key.."lock"][idx] then
			save.elses[item.own_key.."save"][idx] = save.elses[item.own_key.."save"][idx] or {}
			save.elses[item.own_key.."buff"][idx] = save.elses[item.own_key.."buff"][idx] or {}
			local sval = save.elses[item.own_key.."save"][idx].value or 0.5
			local should_eval = nil
			for i = 1,6 do 
				local info = item.buffs[i]
				local val = info.toget(player)
				if val > (save.elses[item.own_key.."save"][idx][info.name] or 0) then
					save.elses[item.own_key.."buff"][idx][info.name] = (save.elses[item.own_key.."buff"][idx][info.name] or 0) + sval * (val - (save.elses[item.own_key.."save"][idx][info.name] or 0))
					player:AddCacheFlags(info.cache)
					player:GetData().should_evaluate_on_update_once = true
					save.elses[item.own_key.."save"][idx].valued = true
					should_eval = true
				end
				if val ~= (save.elses[item.own_key.."save"][idx][info.name] or 0) then save.elses[item.own_key.."save"][idx][info.name] = val end
			end
			if should_eval then 
				save.elses[item.own_key.."save"][idx].value = save.elses[item.own_key.."save"][idx].value * 0.5
			end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = item.entity,
Function = function(_,player,collid,cnt,lastnumber)
	if cnt > 0 and lastnumber == 0 then
		local idx = player:GetData().__Index
		if idx then
			save.elses[item.own_key.."save"] = save.elses[item.own_key.."save"] or {}
			save.elses[item.own_key.."lock"] = save.elses[item.own_key.."lock"] or {}
			save.elses[item.own_key.."save"][idx] = {value = 0.5,}
			for u,v in pairs(item.buffs) do save.elses[item.own_key.."save"][idx][v.name] = v.toget(player) end
			save.elses[item.own_key.."lock"][idx] = true
		end
	end
	if cnt < 0 and lastnumber == cnt then
		save.elses[item.own_key.."lock"] = save.elses[item.own_key.."lock"] or {}
		save.elses[item.own_key.."lock"][idx] = nil
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."save"] = {}
		save.elses[item.own_key.."buff"] = {}
		save.elses[item.own_key.."lock"] = {}
	end
	save.elses[item.own_key.."save"] = save.elses[item.own_key.."save"] or {}
	save.elses[item.own_key.."buff"] = save.elses[item.own_key.."buff"] or {}
	save.elses[item.own_key.."lock"] = save.elses[item.own_key.."lock"] or {}
end,
})

return item