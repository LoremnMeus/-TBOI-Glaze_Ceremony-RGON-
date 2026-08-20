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
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Sage_r,
	own_key = "Thoth_cd1r_Sag_",
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_ROOM, params = nil,
Function = function(_)
	save.elses[item.own_key.."effect"] = {}
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_REASSIGN_IMITATE_ITEM, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local idx = d.__Index
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	if (save.elses[item.own_key.."effect"][idx] or 0) == 2 then
		local itemConfig = Isaac.GetItemConfig()
		player:RemoveCostume(itemConfig:GetCollectible(223))
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.MC_EVALUATE_IMITATE_ITEM, params = nil,
Function = function(_,player,colid,value)
	local d = player:GetData()
	local idx = d.__Index
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	if (save.elses[item.own_key.."effect"][idx] or 0) == 2 then
		value[223] = (value[223] or 0) + 1
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_,ent,amt,flag,source,cooldown)
	local player = ent:ToPlayer()
	if player then
		local rng = player:GetCardRNG(item.entity)
		rng = auxi.rng_for_sake(rng)
		local room = Game():GetRoom()
		local d = player:GetData()
		local idx = d.__Index
		save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
		if (save.elses[item.own_key.."effect"][idx] or 0) == 1 then
			if flag & DamageFlag.DAMAGE_EXPLOSION == DamageFlag.DAMAGE_EXPLOSION then
				player:SetMinDamageCooldown(cooldown)
				return false
			end
			if flag & DamageFlag.DAMAGE_FIRE == DamageFlag.DAMAGE_FIRE then
				save.elses[item.own_key.."effect"][idx] = 2
				Imitate_item_holder.Evaluate_Imitate_Items(player)
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
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
			
		end
		save.elses[item.own_key.."effect"][idx] = 1
	end
end,
})


return item