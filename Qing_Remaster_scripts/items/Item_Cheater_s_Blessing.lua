local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder") 

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Cheater_s_Blessing,
	own_key = "Item_Cheater_s_Blessing_",
	buffs = {
		[1] = {name = "speed",cache = CacheFlag.CACHE_SPEED,
			toget = function(player) return player.MoveSpeed end,mul = 0.01,},
		[2] = {name = "tear",cache = CacheFlag.CACHE_FIREDELAY,
			toget = function(player) return 30 / (player.MaxFireDelay + 1) end,mul = 0.01,},
		[3] = {name = "damage",cache = CacheFlag.CACHE_DAMAGE,
			toget = function(player) return player.Damage end,mul = 0.01,},
		[4] = {name = "range",cache = CacheFlag.CACHE_RANGE,
			toget = function(player) return player.TearRange end,mul = 0.01 * 40,},
		[5] = {name = "luck",cache = CacheFlag.CACHE_LUCK,
			toget = function(player) return player.Luck end,mul = 0.01,},
		[6] = {name = "shotspeed",cache = CacheFlag.CACHE_SHOTSPEED,
			toget = function(player) return player.ShotSpeed end,mul = 0.01,},
	},
}
auxi.add_to_seija(item.entity)

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_,ent,amt,flag,source,cooldown)
	local player = ent:ToPlayer()
	if player and auxi.has_have_coll(player,item.entity) then
		if auxi.should_do_Seija(player) then
			player:UseActiveItem(422,UseFlag.USE_MIMIC,-1)
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_REWIND, params = nil,
Function = function(_,tp,data)
	if tp == "Rewind" then
		--Isaac.DebugString("Previous Cheater Counter:"..tostring(data[item.own_key.."Counter"]))
		save.elses[item.own_key.."Counter"] = (data[item.own_key.."Counter"] or 0) + 1
		if save.elses[item.own_key.."Counter"] == 3 then
			delay_buffer.addeffe(function(params)
				local room = Game():GetRoom()
				local player = Game():GetPlayer(0)
				unique_holder.Hold_for_missing(true) 
				local q = Isaac.Spawn(5,100,item.entity,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
				auxi.self_morph(q,{5,100,item.entity,})
				unique_holder.Hold_for_missing() 
				player:AnimateHappy()
			end,{},1)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if auxi.has_have_coll(player,item.entity) then
		local mul = player:GetCollectibleNum(item.entity)
		if cacheFlag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + mul * item.buffs[1].mul
		end
		if cacheFlag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay,auxi.get_mxdelay_multiplier(player) * mul * item.buffs[2].mul)
		end
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + auxi.get_damage_multiplier(player) * mul * item.buffs[3].mul
		end
		if cacheFlag == CacheFlag.CACHE_RANGE then
			player.TearRange = player.TearRange + mul * item.buffs[4].mul
		end
		if cacheFlag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + mul * item.buffs[5].mul
		end
		if cacheFlag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + mul * item.buffs[6].mul
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = item.entity,
Function = function(_,player,collid,cnt,touched)
	if touched == false then player:UseCard(51,1|(1<<8)) end
end,
})

return item