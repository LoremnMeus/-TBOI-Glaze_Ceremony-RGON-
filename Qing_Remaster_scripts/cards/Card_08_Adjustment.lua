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
	entity = enums.Cards.Adjustment,
	own_key = "Thoth_cd8_Adj_",
	infos = {
		[1] = {vr = 20,st = 1,},
		[2] = {vr = 30,st = 1,},
		[3] = {vr = 40,st = 1,},
	},
}

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local d = player:GetData()
	local idx = d.__Index
	if idx ~= nil then
		save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
		save.elses[item.own_key.."effect"][idx] = math.max(0,save.elses[item.own_key.."effect"][idx] or 0)
		local mul = ((math.sqrt(save.elses[item.own_key.."effect"][idx] + 10) - math.sqrt(10)) * 0.3)
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + auxi.get_damage_multiplier(player) * mul 
		end
		if cacheFlag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay,auxi.get_mxdelay_multiplier(player) * mul * 0.85)
		end
		if cacheFlag == CacheFlag.CACHE_RANGE then
			player.TearRange = player.TearRange + mul * 40 * 1.5
		end
		if cacheFlag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + mul * 0.25
		end
		if cacheFlag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + mul * 0.9
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
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local total = player:GetNumBombs() + player:GetNumKeys() + player:GetNumCoins()
		local ef2 = math.abs(math.floor(total/3) - player:GetNumBombs()) + math.abs(math.floor(total/3) - player:GetNumKeys()) * 0.6 + math.abs(total - math.floor(total/3) * 2 - player:GetNumCoins()) * 0.3
		local delta = math.floor(total/3)
		player:AddBombs(delta - player:GetNumBombs())
		player:AddKeys(delta - player:GetNumKeys())
		player:AddCoins(delta - player:GetNumCoins())
		local cnt = total - delta * 3
		for i = 1,cnt do
			local free_pos = room:FindFreePickupSpawnPosition(player.Position,10,true)
			local ndx = option_index_holder.find_a_new_index()
			local nidx = math.random(360)
			for j = 1,3 do
				local info = item.infos[j]
				local q = Isaac.Spawn(5,info.vr,info.st,free_pos + auxi.MakeVector(j * 360/3 + nidx) * 5,Vector(0,0),player):ToPickup()
				q:Morph(5,info.vr,info.st,true,true,true)
				q.OptionsPickupIndex = ndx
			end
		end
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
			if idx ~= nil then
				save.elses[item.own_key.."effect"][idx] = (save.elses[item.own_key.."effect"][idx] or 0) + ef2
				player:AddCacheFlags(CacheFlag.CACHE_ALL)
				player:GetData().should_evaluate_on_update_once = true
			end
		end
	end
end,
})


return item