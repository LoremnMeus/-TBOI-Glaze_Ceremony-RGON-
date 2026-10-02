local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local save_elses_access = require("Qing_Remaster_scripts.auxiliary.save_elses_access")

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

-- A: root containers only. Does not imply lock[idx] / snapshots[idx] are complete.
local function get_roots()
	local buff_key = item.own_key .. "buff"
	local lock_key = item.own_key .. "lock"
	local save_key = item.own_key .. "save"
	local buff = save.elses[buff_key]
	if type(buff) ~= "table" then
		buff = {}
		save.elses[buff_key] = buff
	end
	local lock = save.elses[lock_key]
	if type(lock) ~= "table" then
		lock = {}
		save.elses[lock_key] = lock
	end
	local snapshots = save.elses[save_key]
	if type(snapshots) ~= "table" then
		snapshots = {}
		save.elses[save_key] = snapshots
	end
	return buff, lock, snapshots
end

-- Nested default: missing buff[idx] == no accumulated bonus.
local function get_or_create_player_buff(buff_root, idx)
	local buff = buff_root[idx]
	if type(buff) ~= "table" then
		buff = {}
		buff_root[idx] = buff
	end
	return buff
end

-- B: lock[idx] => snapshots[idx] must be a table. Never invent {value=0.5}.
local function require_locked_snapshot(lock, snapshots, idx)
	if lock[idx] ~= true then
		return nil
	end
	local snapshot = snapshots[idx]
	if type(snapshot) ~= "table" then
		return save_elses_access.state_invariant_fail(
			"Item_Tiramisu invariant broken: lock[" .. tostring(idx) .. "] exists without saved snapshot"
		)
	end
	return snapshot
end

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if auxi.has_have_coll(player,item.entity) then
		local idx = player:GetData().__Index
		if idx == nil then return end
		local buff_root, lock = get_roots()
		if lock[idx] then
			local buff = get_or_create_player_buff(buff_root, idx)
			if cacheFlag == CacheFlag.CACHE_DAMAGE then
				player.Damage = player.Damage + math.min(10,(buff.damage or 0))
			end
			if cacheFlag == CacheFlag.CACHE_FIREDELAY then
				player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay,(buff.tear or 0))
			end
			if cacheFlag == CacheFlag.CACHE_RANGE then
				player.TearRange = player.TearRange + (buff.range or 0)
			end
			if cacheFlag == CacheFlag.CACHE_SPEED then
				player.MoveSpeed = player.MoveSpeed + (buff.speed or 0)
			end
			if cacheFlag == CacheFlag.CACHE_LUCK then
				player.Luck = player.Luck + (buff.luck or 0)
			end
			if cacheFlag == CacheFlag.CACHE_SHOTSPEED then
				player.ShotSpeed = player.ShotSpeed + (buff.shotspeed or 0)
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	local buff_root, lock, snapshots = get_roots()
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.has_have_coll(player,item.entity) then
			local idx = player:GetData().__Index
			if idx and Game():GetFrameCount() % 10 == 5 and lock[idx] then
				local snapshot = require_locked_snapshot(lock, snapshots, idx)
				if snapshot then
				local buff = get_or_create_player_buff(buff_root, idx)
				for i = 1,6 do
					local info = item.buffs[i]
					if (buff[info.name] or 0) > 0 then
						buff[info.name] = buff[info.name] * 0.99
						player:AddCacheFlags(info.cache)
						player:GetData().should_evaluate_on_update_once = true
					end
				end
				if snapshot.valued then
				else
					snapshot.value = (snapshot.value or 0.5) * 0.9 + 0.5 * 0.1
				end
				snapshot.valued = nil
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if auxi.has_have_coll(player,item.entity) then
		local idx = player:GetData().__Index
		if idx == nil then return end
		local buff_root, lock, snapshots = get_roots()
		if not lock[idx] then return end
		local snapshot = require_locked_snapshot(lock, snapshots, idx)
		if not snapshot then return end
		local buff = get_or_create_player_buff(buff_root, idx)
		local sval = snapshot.value or 0.5
		local should_eval = nil
		for i = 1,6 do
			local info = item.buffs[i]
			local val = info.toget(player)
			if val > (snapshot[info.name] or 0) then
				buff[info.name] = (buff[info.name] or 0) + sval * (val - (snapshot[info.name] or 0))
				player:AddCacheFlags(info.cache)
				player:GetData().should_evaluate_on_update_once = true
				snapshot.valued = true
				should_eval = true
			end
			if val ~= (snapshot[info.name] or 0) then snapshot[info.name] = val end
		end
		if should_eval then
			snapshot.value = snapshot.value * 0.5
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = item.entity,
Function = function(_,player,collid,cnt,lastnumber)
	local idx = player:GetData().__Index
	if idx == nil then return end
	local buff_root, lock, snapshots = get_roots()
	if cnt > 0 and lastnumber == 0 then
		snapshots[idx] = {value = 0.5,}
		for u,v in pairs(item.buffs) do snapshots[idx][v.name] = v.toget(player) end
		lock[idx] = true
	end
	if cnt < 0 and lastnumber == cnt then
		lock[idx] = nil
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if not continue then
		save.elses[item.own_key.."save"] = {}
		save.elses[item.own_key.."buff"] = {}
		save.elses[item.own_key.."lock"] = {}
	end
	get_roots()
end,
})

return item
