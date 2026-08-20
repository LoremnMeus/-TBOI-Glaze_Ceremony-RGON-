local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Procrastination,
	own_key = "Item_Procrastination_",
	damage_per_tick = 0.1,
	frames_per_tick = 30 * 30, -- 30 秒
	floor_cap = 1,
}

local function bonus_bucket()
	save.elses = save.elses or {}
	save.elses[item.own_key.."bonus"] = save.elses[item.own_key.."bonus"] or {}
	return save.elses[item.own_key.."bonus"]
end

local function floor_bucket()
	save.elses = save.elses or {}
	save.elses[item.own_key.."floor"] = save.elses[item.own_key.."floor"] or {}
	return save.elses[item.own_key.."floor"]
end

function item.get_bonus(player)
	local idx = player and player:GetData().__Index
	if idx == nil then return 0 end
	return math.max(0, tonumber(bonus_bucket()[idx]) or 0)
end

function item.get_floor_gain(player)
	local idx = player and player:GetData().__Index
	if idx == nil then return 0 end
	local floor = floor_bucket()
	floor.gain = floor.gain or {}
	return math.max(0, tonumber(floor.gain[idx]) or 0)
end

function item.is_growth_stopped()
	return floor_bucket().stopped == true
end

function item.stop_growth_this_floor()
	floor_bucket().stopped = true
end

local function reset_floor_counters()
	local floor = floor_bucket()
	floor.stopped = nil
	floor.gain = {}
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		player:GetData()[item.own_key.."timer"] = 0
	end
end

local function keep_boss_room_doors_open()
	if not auxi.have_player_has_collectible(item.entity) then return end
	local room = Game():GetRoom()
	if room:GetAliveBossesCount() <= 0 then return end
	for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
		local door = room:GetDoor(slot)
		if door then
			door:SetLocked(false)
			if not door:IsOpen() then
				door:Open()
			end
		end
	end
end

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if cacheFlag ~= CacheFlag.CACHE_DAMAGE then return end
	if not auxi.has_have_coll(player,item.entity) then return end
	local bonus = item.get_bonus(player)
	if bonus <= 0 then return end
	player.Damage = player.Damage + bonus * auxi.get_damage_multiplier(player)
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if not continue then
		save.elses[item.own_key.."bonus"] = {}
		save.elses[item.own_key.."floor"] = {}
	end
	save.elses[item.own_key.."bonus"] = save.elses[item.own_key.."bonus"] or {}
	save.elses[item.own_key.."floor"] = save.elses[item.own_key.."floor"] or {}
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	reset_floor_counters()
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if not auxi.has_have_coll(player,item.entity) then return end
	if item.is_growth_stopped() then return end
	local idx = player:GetData().__Index
	if idx == nil then return end
	local floor_gain = item.get_floor_gain(player)
	if floor_gain >= item.floor_cap - 1e-6 then return end

	local d = player:GetData()
	d[item.own_key.."timer"] = (d[item.own_key.."timer"] or 0) + 1
	if d[item.own_key.."timer"] < item.frames_per_tick then return end
	d[item.own_key.."timer"] = 0

	local cnt = math.max(1, player:GetCollectibleNum(item.entity))
	local add = math.min(item.damage_per_tick * cnt, item.floor_cap - floor_gain)
	if add <= 0 then return end

	local bonus = bonus_bucket()
	bonus[idx] = (bonus[idx] or 0) + add
	local floor = floor_bucket()
	floor.gain = floor.gain or {}
	floor.gain[idx] = floor_gain + add

	player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
	player:GetData().should_evaluate_on_update_once = true
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	keep_boss_room_doors_open()
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_DEATH, params = nil,
Function = function(_,npc)
	if not npc or not npc:IsBoss() then return end
	if not auxi.have_player_has_collectible(item.entity) then return end
	item.stop_growth_this_floor()
end,
})

return item
