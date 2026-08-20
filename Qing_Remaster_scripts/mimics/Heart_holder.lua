local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Heart_holder_",
	chance_list = {
		[1] = {name = "damage",weigh = 5,},
		[2] = {name = "range",weigh = 5,},
		[3] = {name = "speed",weigh = 5,},
		[4] = {name = "tear",weigh = 5,},
		[5] = {name = "shotspeed",weigh = 5,},
		[6] = {name = "luck",weigh = 5,},
	},
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."buff"] = {}
		save.elses[item.own_key.."buff2"] = {}
	end
	save.elses[item.own_key.."buff"] = save.elses[item.own_key.."buff"] or {}
	save.elses[item.own_key.."buff2"] = save.elses[item.own_key.."buff2"] or {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local idx = player:GetData().__Index
	if idx then
		if save.elses[item.own_key.."buff"] and save.elses[item.own_key.."buff"][idx] and auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_CANDY_HEART) then
			if cacheFlag == CacheFlag.CACHE_SPEED then
				player.MoveSpeed = player.MoveSpeed + 0.02 * (save.elses[item.own_key.."buff"][idx].speed or 0)
			elseif cacheFlag == CacheFlag.CACHE_DAMAGE then
				player.Damage = player.Damage + auxi.get_damage_multiplier(player) * 0.1 * (save.elses[item.own_key.."buff"][idx].damage or 0)
			elseif cacheFlag == CacheFlag.CACHE_FIREDELAY then
				player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay,auxi.get_mxdelay_multiplier(player) * 0.05 * (save.elses[item.own_key.."buff"][idx].tear or 0))
			elseif cacheFlag == CacheFlag.CACHE_RANGE then
				player.TearRange = player.TearRange + 10 * (save.elses[item.own_key.."buff"][idx].range or 0)
			elseif cacheFlag == CacheFlag.CACHE_SHOTSPEED then
				player.ShotSpeed = player.ShotSpeed + 0.02 * (save.elses[item.own_key.."buff"][idx].shotspeed or 0)
			elseif cacheFlag == CacheFlag.CACHE_LUCK then
				player.Luck = player.Luck + 0.1 * (save.elses[item.own_key.."buff"][idx].luck or 0)
			end
		end
		if save.elses[item.own_key.."buff2"] and save.elses[item.own_key.."buff2"][idx] and auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_SOUL_LOCKET) then
			if cacheFlag == CacheFlag.CACHE_SPEED then
				player.MoveSpeed = player.MoveSpeed + 0.04 * (save.elses[item.own_key.."buff2"][idx].speed or 0)
			elseif cacheFlag == CacheFlag.CACHE_DAMAGE then
				player.Damage = player.Damage + auxi.get_damage_multiplier(player) * 0.2 * (save.elses[item.own_key.."buff2"][idx].damage or 0)
			elseif cacheFlag == CacheFlag.CACHE_FIREDELAY then
				player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay,auxi.get_mxdelay_multiplier(player) * 0.1 * (save.elses[item.own_key.."buff2"][idx].tear or 0))
			elseif cacheFlag == CacheFlag.CACHE_RANGE then
				player.TearRange = player.TearRange + 20 * (save.elses[item.own_key.."buff2"][idx].range or 0)
			elseif cacheFlag == CacheFlag.CACHE_SHOTSPEED then
				player.ShotSpeed = player.ShotSpeed + 0.04 * (save.elses[item.own_key.."buff2"][idx].shotspeed or 0)
			elseif cacheFlag == CacheFlag.CACHE_LUCK then
				player.Luck = player.Luck + 0.2 * (save.elses[item.own_key.."buff2"][idx].luck or 0)
			end
		end
	end
end,
})

--- 纯函数：在 state 上累计 cnt 次等权抽取（供 Flight 独立模拟复用）
function item.roll_heart_bonus(state, rng, count)
	state = state or {}
	count = math.max(0, math.floor(tonumber(count) or 0))
	if rng then rng = auxi.rng_for_sake(rng) end
	for _ = 1, count do
		local rnd = auxi.random_in_weighed_table(item.chance_list, rng)
		if rnd and rnd.name then
			state[rnd.name] = (state[rnd.name] or 0) + 1
		end
	end
	return state
end

--- scale=1 糖心层；scale=2 魂匣层。返回加算表（tear 为 Fire Rate 加算）
function item.bonus_from_layers(state, scale)
	scale = tonumber(scale) or 1
	state = state or {}
	return {
		damage = 0.1 * scale * (state.damage or 0),
		range = 10 * scale * (state.range or 0),
		speed = 0.02 * scale * (state.speed or 0),
		tear = 0.05 * scale * (state.tear or 0),
		shotspeed = 0.02 * scale * (state.shotspeed or 0),
		luck = 0.1 * scale * (state.luck or 0),
	}
end

function item.add_heart_buff(player,cnt)
	if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_CANDY_HEART) then
		local idx = player:GetData().__Index
		save.elses[item.own_key.."buff"] = save.elses[item.own_key.."buff"] or {}
		save.elses[item.own_key.."buff"][idx] = save.elses[item.own_key.."buff"][idx] or {}
		local rng = player:GetCollectibleRNG(CollectibleType.COLLECTIBLE_CANDY_HEART)
		item.roll_heart_bonus(save.elses[item.own_key.."buff"][idx], rng, cnt)
		player:AddCacheFlags(CacheFlag.CACHE_ALL)
		player:GetData().should_evaluate_on_update_once = true
	end
	-- 釉心等非原版拾取：同步喂给未持有糖心的 Flight 档案
	local Dyn = require("Qing_Remaster_scripts.others.craft_dynamic_stats")
	if Dyn and Dyn.on_craft_heart_pickup then
		Dyn.on_craft_heart_pickup(player, cnt, 0)
	end
end

function item.add_soul_buff(player,cnt)
	if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_SOUL_LOCKET) then
		local idx = player:GetData().__Index
		save.elses[item.own_key.."buff2"] = save.elses[item.own_key.."buff2"] or {}
		save.elses[item.own_key.."buff2"][idx] = save.elses[item.own_key.."buff2"][idx] or {}
		local rng = player:GetCollectibleRNG(CollectibleType.COLLECTIBLE_SOUL_LOCKET)
		item.roll_heart_bonus(save.elses[item.own_key.."buff2"][idx], rng, cnt)
		player:AddCacheFlags(CacheFlag.CACHE_ALL)
		player:GetData().should_evaluate_on_update_once = true
	end
	local Dyn = require("Qing_Remaster_scripts.others.craft_dynamic_stats")
	if Dyn and Dyn.on_craft_heart_pickup then
		Dyn.on_craft_heart_pickup(player, 0, cnt)
	end
end

return item