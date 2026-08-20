local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Pause_Screen_holder = require("Qing_Remaster_scripts.others.Pause_Screen_holder")
local time_holder = require("Qing_Remaster_scripts.others.Time_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Trinkets.Pause_,
	own_key = "Trinkets_Pause__",
	buffs = {
		[1] = {name = "speed",cache = CacheFlag.CACHE_SPEED,
			toget = function(player) return player.MoveSpeed end,mul = 0.05,},
		[2] = {name = "tear",cache = CacheFlag.CACHE_FIREDELAY,
			toget = function(player) return 30 / (player.MaxFireDelay + 1) end,mul = 0.15,},
		[3] = {name = "damage",cache = CacheFlag.CACHE_DAMAGE,
			toget = function(player) return player.Damage end,mul = 0.5,},
		[4] = {name = "range",cache = CacheFlag.CACHE_RANGE,
			toget = function(player) return player.TearRange end,mul = 1 * 40,},
		[5] = {name = "luck",cache = CacheFlag.CACHE_LUCK,
			toget = function(player) return player.Luck end,mul = 1,},
	},
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	if Game():IsPaused() and auxi.have_player_has_trinket(item.entity,true) then 
		if time_holder.IsUpper() ~= true then return end
		local state = Pause_Screen_holder.currentState
		if state.name ~= "UNPAUSED" and state.name ~= "IN_BED" then
			for playerNum = 1, Game():GetNumPlayers() do
				local player = Game():GetPlayer(playerNum - 1)
				if player:HasTrinket(item.entity,true) then
					local idx = player:GetData()
					save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
					save.elses[item.own_key.."effect"][idx] = true
				end
			end
		end
	end 
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local idx = player:GetData()
	if save.elses[item.own_key.."effect"] and save.elses[item.own_key.."effect"][idx] then
		local succ = player:TryRemoveTrinket(item.entity)
		if succ then
			local s = auxi.load_trinket(item.entity)
			player:AnimatePickup(s,true,"LiftItem")
			delay_buffer.addeffe(function(params)
				if player:IsHoldingItem() then
					player:AnimatePickup(s,true,"HideItem")
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLACK_POOF,1,1,false,0,2)
					local e1 = Isaac.Spawn(1000,16,2,player.Position,Vector(0,0),player)
					local e2 = Isaac.Spawn(1000,16,1,player.Position,Vector(0,0),player)
				end
			end,{},15)
		end
		save.elses[item.own_key.."effect"][idx] = nil
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local idx = player:GetData().__Index
	if player:HasTrinket(item.entity) then
		local mul = math.sqrt(player:GetTrinketMultiplier(item.entity))
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
	end
end,
})
--[[
local state = Pause_Screen_holder.currentState
if state.name ~= "UNPAUSED" and Isaac.GetFrameCount() % 60 == 0 then
	Game():GetRoom():Update()
end
--]]
return item