local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Keeper_Sack_",
	chance_list = {
		[1] = {name = "damage",weigh = 5,},
		[2] = {name = "range",weigh = 5,},
		[3] = {name = "speed",weigh = 5,},
	},
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."buff"] = {}
	end
	save.elses[item.own_key.."buff"] = save.elses[item.own_key.."buff"] or {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local idx = player:GetData().__Index
	if idx and save.elses[item.own_key.."buff"] and save.elses[item.own_key.."buff"][idx] then
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + auxi.get_damage_multiplier(player) * (math.sqrt(0.6 * (save.elses[item.own_key.."buff"][idx].damage or 0) + 1) - 1)		--我们稍微改变一下参数啊
		end
		if cacheFlag == CacheFlag.CACHE_RANGE then
			player.TearRange = player.TearRange + (save.elses[item.own_key.."buff"][idx].range or 0) * 10
		end
		if cacheFlag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + (save.elses[item.own_key.."buff"][idx].speed or 0) * 0.03
		end
	end
end,
})

--- 累计消费；每满 3¢ 返回可抽取次数，并写回 spent_remainder
function item.add_spent(state, price)
	state = state or {}
	price = math.max(0, math.floor(tonumber(price) or 0))
	state.spent_remainder = (tonumber(state.spent_remainder) or 0) + price
	local rolls = math.floor(state.spent_remainder / 3)
	state.spent_remainder = state.spent_remainder % 3
	return rolls, state
end

function item.roll_sack_bonus(state, rng, count)
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

--- 与玩家 cache 路径一致的自定义层数值
function item.stats_from_layers(state)
	state = state or {}
	return {
		damage = math.sqrt(0.6 * (state.damage or 0) + 1) - 1,
		range = (state.range or 0) * 10,
		speed = (state.speed or 0) * 0.03,
	}
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local rng = player:GetCollectibleRNG(CollectibleType.COLLECTIBLE_KEEPERS_SACK)
	if (d[item.own_key.."adder"] or 0) >= 3 then		--多出来的我才懒得记呢
		local mul = math.floor(d[item.own_key.."adder"]/3)
		local idx = d.__Index
		save.elses[item.own_key.."buff"][idx] = save.elses[item.own_key.."buff"][idx] or {}
		item.roll_sack_bonus(save.elses[item.own_key.."buff"][idx], rng, mul)
		d[item.own_key.."adder"] = d[item.own_key.."adder"] - 3 * mul
		player:AddCacheFlags(CacheFlag.CACHE_ALL)
		player:GetData().should_evaluate_on_update_once = true
	end
end,
})

return item