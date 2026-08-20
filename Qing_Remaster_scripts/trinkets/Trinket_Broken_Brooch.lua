local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Trinkets.Broken_Brooch,
	own_key = "Trinkets_Broken_Brooch_",
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
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, params = nil,
Function = function(_)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if player:HasTrinket(item.entity) then
			local cnt = player:GetTrinketMultiplier(item.entity)
			for i = 1,cnt do
				if auxi.check_rand(player.Luck,66,3,15) then
					item.add_player(player)
					player:AnimateHappy()
				end
			end
		end
	end
end,
})

function item.add_player(player)
	local a = player.MoveSpeed local b = 30/(player.MaxFireDelay + 1) local c = player.Damage local d = player.TearRange/40
	local x = 1/4 * (a + (4 * d + 1)/27) + 1/2 * (b * c/(30/11)/3.5)^(13/40)
	--local A = x local B = 30/11 * x^(4/3) local C = 3.5 * x^(100/56) local D = (27 * x - 1)/4
	local Ds = {[3] = x - a,[2] = x - (11/30 * b)^(3/4),[1] = x - (c/3.5)^(56/100),[4] = x - (4 * d + 1)/27,}
	local mxu,mxv = auxi.get_mx_pair(Ds)
	local idx = player:GetData().__Index
	save.elses[item.own_key.."buff"] = save.elses[item.own_key.."buff"] or {}
	save.elses[item.own_key.."buff"][idx] = save.elses[item.own_key.."buff"][idx] or {}
	local info = item.buffs[mxu]
	save.elses[item.own_key.."buff"][idx][info.name] = (save.elses[item.own_key.."buff"][idx][info.name] or 0) + 0.25
	player:AddCacheFlags(info.cache)
	player:GetData().should_evaluate_on_update_once = true
end
--l local Trinket_Broken_Brooch = require("Qing_Remaster_scripts.trinkets.Trinket_Broken_Brooch") Trinket_Broken_Brooch.add_player(Game():GetPlayer(0))

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if save.elses[item.own_key.."buff"] then
		local idx = player:GetData().__Index
		if idx ~= nil and save.elses[item.own_key.."buff"][idx] then
			if cacheFlag == CacheFlag.CACHE_DAMAGE then
				player.Damage = player.Damage + (save.elses[item.own_key.."buff"][idx].damage or 0)
			end
			if cacheFlag == CacheFlag.CACHE_FIREDELAY then
				player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay,(save.elses[item.own_key.."buff"][idx].tear or 0))
			end
			if cacheFlag == CacheFlag.CACHE_RANGE then
				player.TearRange = player.TearRange + (save.elses[item.own_key.."buff"][idx].range or 0) * 40
			end
			if cacheFlag == CacheFlag.CACHE_SPEED then
				player.MoveSpeed = player.MoveSpeed + (save.elses[item.own_key.."buff"][idx].speed or 0) * 0.2
			end
			if cacheFlag == CacheFlag.CACHE_LUCK then
				player.Luck = player.Luck + (save.elses[item.own_key.."buff"][idx].luck or 0)
			end
			if cacheFlag == CacheFlag.CACHE_SHOTSPEED then
				player.ShotSpeed = player.ShotSpeed + (save.elses[item.own_key.."buff"][idx].shotspeed or 0)
			end
		end
	end
end,
})

return item