local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Devil_r,
	own_key = "Thoth_cd15r_Dev_",
	buff_info = {
		[1] = {weigh = 6,work = function(player,rng,info,item)
			local d = player:GetData()
			local idx = d.__Index
			save.elses[item.own_key.."effect1"][idx] = (save.elses[item.own_key.."effect1"][idx] or 0) + 1
		end,},
		[2] = {weigh = 16,work = function(player,rng,info,item)
			local d = player:GetData()
			local idx = d.__Index
			save.elses[item.own_key.."effect2"][idx] = (save.elses[item.own_key.."effect2"][idx] or 0) + 1
		end,},
		[3] = {weigh = 26,work = function(player,rng,info,item)
			local d = player:GetData()
			local idx = d.__Index
			save.elses[item.own_key.."effect3"][idx] = (save.elses[item.own_key.."effect3"][idx] or 0) + 1
		end,},
		[4] = {weigh = 26,work = function(player,rng,info,item)
			local d = player:GetData()
			local idx = d.__Index
			save.elses[item.own_key.."effect4"][idx] = (save.elses[item.own_key.."effect4"][idx] or 0) + 30 * 60
		end,},
		[5] = {weigh = 26,work = function(player,rng,info,item)
			local d = player:GetData()
			local idx = d.__Index
			save.elses[item.own_key.."effect5"][idx] = (save.elses[item.own_key.."effect5"][idx] or 0) + 10
		end,},
	},
}

local function reward(player)
	local rng = player:GetCardRNG(item.entity)
	local tbl = auxi.deepCopy(item.buff_info)
	local ret = auxi.random_in_weighed_table(tbl,rng)
	if ret and ret.work then ret.work(player,rng,ret,item) end
	player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
	player:GetData().should_evaluate_on_update_once = true
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect1"] = {}
		save.elses[item.own_key.."effect2"] = {}
		save.elses[item.own_key.."effect3"] = {}
		save.elses[item.own_key.."effect4"] = {}
		save.elses[item.own_key.."effect5"] = {}
	end
	save.elses[item.own_key.."effect1"] = save.elses[item.own_key.."effect1"] or {}
	save.elses[item.own_key.."effect2"] = save.elses[item.own_key.."effect2"] or {}
	save.elses[item.own_key.."effect3"] = save.elses[item.own_key.."effect3"] or {}
	save.elses[item.own_key.."effect4"] = save.elses[item.own_key.."effect4"] or {}
	save.elses[item.own_key.."effect5"] = save.elses[item.own_key.."effect5"] or {}
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local d = player:GetData()
	local idx = d.__Index
	if idx ~= nil then
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + (save.elses[item.own_key.."effect1"][idx] or 0) + (save.elses[item.own_key.."effect2"][idx] or 0) + (save.elses[item.own_key.."effect3"][idx] or 0)
			if (save.elses[item.own_key.."effect4"][idx] or 0) > 0 then player.Damage = player.Damage + 1 end
			if (save.elses[item.own_key.."effect5"][idx] or 0) > 0 then player.Damage = player.Damage + 1 end
		end
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	save.elses[item.own_key.."effect3"] = {}
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[item.own_key.."effect2"] = {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local idx = d.__Index
	if save.elses[item.own_key.."effect4"][idx] then
		if save.elses[item.own_key.."effect4"][idx] > 0 then save.elses[item.own_key.."effect4"][idx] = save.elses[item.own_key.."effect4"][idx] - 1 end
		if save.elses[item.own_key.."effect4"][idx] <= 0 then 
			save.elses[item.own_key.."effect4"][idx] = nil 
			player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
			player:GetData().should_evaluate_on_update_once = true
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = nil,
Function = function(_,ent)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local d = player:GetData()
		local idx = d.__Index
		if save.elses[item.own_key.."effect5"][idx] then
			if save.elses[item.own_key.."effect5"][idx] > 0 then save.elses[item.own_key.."effect5"][idx] = save.elses[item.own_key.."effect5"][idx] - 1 end
			if save.elses[item.own_key.."effect5"][idx] <= 0 then 
				save.elses[item.own_key.."effect5"][idx] = nil 
				player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
				player:GetData().should_evaluate_on_update_once = true
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	local rng = player:GetCardRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then reward(player) end
		reward(player)
		delay_buffer.addeffe(function(params)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_SATAN_GROW,1,1,false,0,2)
		end,{},15)
		delay_buffer.addeffe(function(params)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_SATAN_BLAST,1,1,false,0,2)
		end,{},25)
		delay_buffer.addeffe(function(params)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_SATAN_APPEAR,1,1,false,0,2)
		end,{},35)
	end
end,
})


return item