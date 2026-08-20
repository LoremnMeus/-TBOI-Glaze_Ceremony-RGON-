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
	entity = enums.Cards.Sun_r,
	own_key = "Thoth_cd19r_Sun_",
}

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local d = player:GetData()
	local idx = d.__Index
	if idx ~= nil then
		save.elses[item.own_key.."counter"] = save.elses[item.own_key.."counter"] or {}
		local mul = save.elses[item.own_key.."counter"][idx] or 0
		if cacheFlag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + mul * 0.1
		end
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + mul * 0.4
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
		save.elses[item.own_key.."counter"] = {}
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	save.elses[item.own_key.."counter"] = save.elses[item.own_key.."counter"] or {}
	save.elses[item.own_key.."effect2"] = {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	save.elses[item.own_key.."effect2"] = {}
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[item.own_key.."effect"] = {}
	save.elses[item.own_key.."counter"] = {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local idx = d.__Index
	if save.elses[item.own_key.."effect"][idx] then
		local should_work = false
		d[item.own_key.."effect"] = (d[item.own_key.."effect"] or 0) + 1
		if save.elses[item.own_key.."effect2"][idx] and d[item.own_key.."effect"] == 30 * 60 then should_work = true end
		if d[item.own_key.."effect"] >= 60 * 60 then d[item.own_key.."effect"] = 0 should_work = true end
		if should_work then
			local q = Isaac.Spawn(1000,49,0,player.Position + Vector(0,0.1),Vector(0,0),player):ToEffect()
			q:GetSprite().Offset = Vector(0,-40)
			sound_tracker.PlayStackedSound(157,1,1,false,0,2)
			player:AddHearts(1)
			save.elses[item.own_key.."counter"][idx] = (save.elses[item.own_key.."counter"][idx] or 0) + 1
			player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
			player:AddCacheFlags(CacheFlag.CACHE_SPEED)
			player:GetData().should_evaluate_on_update_once = true
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
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then save.elses[item.own_key.."effect2"][idx] = true end
		save.elses[item.own_key.."effect"][idx] = true
	end
end,
})


return item