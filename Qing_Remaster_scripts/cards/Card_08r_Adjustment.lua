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
	entity = enums.Cards.Adjustment_r,
	own_key = "Thoth_cd8r_Adj_",
}

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local d = player:GetData()
	local idx = d.__Index
	if idx ~= nil then
		save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
		save.elses[item.own_key.."effect"][idx] = math.max(save.elses[item.own_key.."effect"][idx] or 0)
		local mul = ((math.sqrt(save.elses[item.own_key.."effect"][idx] + 5) - math.sqrt(5)) * 0.2)
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + auxi.get_damage_multiplier(player) * mul * 1.7
		end
		if cacheFlag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay , auxi.get_mxdelay_multiplier(player) * mul * 0.85)
		end
		if cacheFlag == CacheFlag.CACHE_RANGE then
			player.TearRange = player.TearRange + mul * 40 * 1.5
		end
		if cacheFlag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + mul * 0.26
		end
		if cacheFlag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + mul * 1.74
		end
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

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local rng = player:GetCardRNG(cardtype)
	rng = auxi.rng_for_sake(rng)
	local d = player:GetData()
	local idx = d.__Index
	local room = Game():GetRoom()
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local total = player:GetNumBombs() + player:GetNumKeys() * 0.8 + player:GetNumCoins() * 0.4
		player:AddBombs(- player:GetNumBombs())
		player:AddKeys(- player:GetNumKeys())
		player:AddCoins(- player:GetNumCoins())	
		if idx then
			save.elses[item.own_key.."effect"][idx] = (save.elses[item.own_key.."effect"][idx] or 0) + total
			player:AddCacheFlags(CacheFlag.CACHE_ALL)
			player:GetData().should_evaluate_on_update_once = true
		end
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
			local rnd = rng:RandomInt(100)
			if rnd > 50 then
				local q = Isaac.Spawn(5,300,item.entity,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
				q:Morph(5,300,item.entity,true,true,true)
			end
		end
	end
end,
})

return item