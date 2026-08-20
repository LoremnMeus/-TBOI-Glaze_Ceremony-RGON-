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
	entity = enums.Cards.Aeon_r,
	own_key = "Thoth_cd20r_Aeon_",
}

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local d = player:GetData()
	local idx = d.__Index
	if idx ~= nil then
		save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
		save.elses[item.own_key.."effect"][idx] = save.elses[item.own_key.."effect"][idx] or 0
		local mul = math.sqrt(save.elses[item.own_key.."effect"][idx])
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + auxi.get_damage_multiplier(player) * mul * 1.2
		end
		if cacheFlag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay , auxi.get_mxdelay_multiplier(player) * mul * 0.7)
		end
		if cacheFlag == CacheFlag.CACHE_RANGE then
			player.TearRange = player.TearRange + mul * 10 * 4
		end
		if cacheFlag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + mul * 0.13 * 1.2
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = nil,
Function = function(_,player,collid,count)
	local idx = player:GetData().__Index
	if idx then
		save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
		save.elses[item.own_key.."effect"][idx] = save.elses[item.own_key.."effect"][idx] or 0
		if save.elses[item.own_key.."effect"][idx] > 0 then
			save.elses[item.own_key.."effect"][idx] = math.max(0,save.elses[item.own_key.."effect"][idx] - math.abs(count) * 1.5)
			player:AddCacheFlags(CacheFlag.CACHE_ALL)
			player:GetData().should_evaluate_on_update_once = true
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_BASIC, params = nil,
Function = function(_,player,changetype,count)
	local idx = player:GetData().__Index
	if idx then
		save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
		save.elses[item.own_key.."effect"][idx] = save.elses[item.own_key.."effect"][idx] or 0
		if save.elses[item.own_key.."effect"][idx] > 0 then
			save.elses[item.own_key.."effect"][idx] = math.max(0,save.elses[item.own_key.."effect"][idx] - math.abs(count))
			player:AddCacheFlags(CacheFlag.CACHE_ALL)
			player:GetData().should_evaluate_on_update_once = true
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_PICKUP_TRINKET, params = nil,
Function = function(_,player,trinket,isgolden,touched)
	local idx = player:GetData().__Index
	if idx then
		save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
		save.elses[item.own_key.."effect"][idx] = save.elses[item.own_key.."effect"][idx] or 0
		save.elses[item.own_key.."effect"][idx] = math.max(0,save.elses[item.own_key.."effect"][idx] - 1)
		player:AddCacheFlags(CacheFlag.CACHE_ALL)
		player:GetData().should_evaluate_on_update_once = true
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_PICKUP_POCKET_ITEM, params = nil,
Function = function(_,player,variant,subtype)
	local idx = player:GetData().__Index
	if idx then
		save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
		save.elses[item.own_key.."effect"][idx] = save.elses[item.own_key.."effect"][idx] or 0
		save.elses[item.own_key.."effect"][idx] = math.max(0,save.elses[item.own_key.."effect"][idx] - 1)
		player:AddCacheFlags(CacheFlag.CACHE_ALL)
		player:GetData().should_evaluate_on_update_once = true
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, params = nil,
Function = function(_,rng,pos)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local idx = player:GetData().__Index
		if idx then
			if save.elses[item.own_key.."effect"][idx] and save.elses[item.own_key.."effect"][idx] > 0 then
				save.elses[item.own_key.."effect"][idx] = save.elses[item.own_key.."effect"][idx] + 0.1
				player:AddCacheFlags(CacheFlag.CACHE_ALL)
				player:GetData().should_evaluate_on_update_once = true
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local rng = player:GetCardRNG(cardtype)
	rng = auxi.rng_for_sake(rng)
	local n_entity = Isaac.GetRoomEntities()
	local n_enemy = auxi.getenemies(n_entity)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		if idx then
			local mxid = 7
			if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
				mxid = 15
			end
			save.elses[item.own_key.."effect"][idx] = math.max(mxid,(save.elses[item.own_key.."effect"][idx] or 0) + 2)
			player:AddCacheFlags(CacheFlag.CACHE_ALL)
			player:GetData().should_evaluate_on_update_once = true
		end
	end
end,
})

return item