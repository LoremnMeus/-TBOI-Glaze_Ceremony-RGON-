local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local Nil_holder = require("Qing_Remaster_scripts.others.Nil_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Lover,
	own_key = "Thoth_cd6_Lov_",
	record_type = {
		[10] = true,
		[20] = true,
		[30] = true,
		[40] = true,
		[42] = true,
		[90] = true,
	},
	buffs = {
		[1] = {name = "damage",weigh = 5,},
		[2] = {name = "tear",weigh = 4,},
		[3] = {name = "range",weigh = 7,},
		[4] = {name = "luck",weigh = 6,},
		[5] = {name = "speed",weigh = 6,},
	},
}

function item.reward(player)
	local rng = player:GetCardRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	local idx = player:GetData().__Index
	local tbl = auxi.deepCopy(item.buffs)
	local rnd = auxi.random_in_weighed_table(tbl,rng)
	save.elses[item.own_key.."buff"][idx] = save.elses[item.own_key.."buff"][idx] or {}
	save.elses[item.own_key.."buff"][idx][rnd.name] = (save.elses[item.own_key.."buff"][idx][rnd.name] or 0) + 1
	player:AddCacheFlags(CacheFlag.CACHE_ALL)
	player:GetData().should_evaluate_on_update_once = true
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local idx = player:GetData().__Index
	if idx and save.elses[item.own_key.."buff"] and save.elses[item.own_key.."buff"][idx] then
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + auxi.get_damage_multiplier(player) * (save.elses[item.own_key.."buff"][idx].damage or 0) * 0.4
		end
		if cacheFlag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay,auxi.get_mxdelay_multiplier(player) * (save.elses[item.own_key.."buff"][idx].tear or 0) * 0.25)
		end
		if cacheFlag == CacheFlag.CACHE_RANGE then
			player.TearRange = player.TearRange + (save.elses[item.own_key.."buff"][idx].range or 0) * 10
		end
		if cacheFlag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + math.sqrt((save.elses[item.own_key.."buff"][idx].speed or 0)) * 0.1
		end
		if cacheFlag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + (save.elses[item.own_key.."buff"][idx].luck or 0) * 0.75
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = nil
		save.elses[item.own_key.."effect2"] = nil
		save.elses[item.own_key.."buff"] = {}
	end
	save.elses[item.own_key.."buff"] = save.elses[item.own_key.."buff"] or {}
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_ROOM, params = nil,
Function = function(_)
	save.elses[item.own_key.."effect"] = nil
	save.elses[item.own_key.."effect2"] = nil
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if Game():GetFrameCount() % 20 == 5 then
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			local idx = player:GetData().__Index
			if save.elses[item.own_key.."buff"][idx] then
				for u,v in pairs(item.buffs) do
					if save.elses[item.own_key.."buff"][idx][v.name] then
						save.elses[item.own_key.."buff"][idx][v.name] = save.elses[item.own_key.."buff"][idx][v.name] * 0.98
						if save.elses[item.own_key.."buff"][idx][v.name] < 0.01 then save.elses[item.own_key.."buff"][idx][v.name] = nil end
					end
				end
				player:AddCacheFlags(CacheFlag.CACHE_ALL)
				player:GetData().should_evaluate_on_update_once = true
			end
		end
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = nil,
Function = function(_,ent,col,low)
	if item.record_type[ent.Variant] and ent.Price == 0 then
		local player = col:ToPlayer()
		if player and save.elses[item.own_key.."effect"] then
			local room = Game():GetRoom()
			ent:PlayPickupSound()
			item.reward(player)
			local rng = ent:GetDropRNG()
			local mxn = 500 
			if save.elses[item.own_key.."effect2"] then mxn = 750 end
			if rng:RandomInt(1000) < mxn then
				local q = Isaac.Spawn(5,0,1,room:FindFreePickupSpawnPosition(room:GetRandomPosition(0),10,true),Vector(0,0),ent):ToPickup()
			end
			local q = auxi.fire_nil(ent.Position,Vector(0,0),{cooldown = 30,})
			local s2 = q:GetSprite()
			local d3 = q:GetData()
			d3.nil_mode = "card_06_lover"
			d3[item.own_key.."effect"] = true
			auxi.copy_sprite(ent:GetSprite(),s2)
			s2:Play("Collect",true)
			ent:Remove()
			return false
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
		save.elses[item.own_key.."effect"] = true
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
			save.elses[item.own_key.."effect2"] = true
		end
	end
end,
})


Nil_holder.register("card_06_lover", {
	detect = function(d) return d[item.own_key.."effect"] end,
	update = function(ent, d, s)
		if s:IsFinished("Collect") then ent:Remove() return end
	end,
})

return item