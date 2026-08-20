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
	entity = enums.Cards.Lure_r,
	own_key = "Thoth_cd11r_Lur_",
	mxn = 3,
	ignore_flag = {
		[301998464] = true,
	},
}

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_,ent,amt,flag,source,cooldown)
	local player = ent:ToPlayer()
	local room = Game():GetRoom()
	if player then
		if auxi.has_card(player,item.entity) then
			local mxn = item.mxn
			if flag & DamageFlag.DAMAGE_CLONES == 0 and amt < mxn and item.ignore_flag[flag] ~= true then
				ent:TakeDamage(mxn,flag | DamageFlag.DAMAGE_CLONES,source,cooldown / math.max(1,amt) * mxn)
				return false
			end
		end
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_,ent,amt,flag,source,cooldown)
	local player = ent:ToPlayer()
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	if player then
		if auxi.has_card(player,item.entity) then
			save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
			save.elses[item.own_key.."effect"][idx] = (save.elses[item.own_key.."effect"][idx] or 0) + 1
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
	local rng = player:GetCardRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		save.elses[item.own_key.."effect"][idx] = (save.elses[item.own_key.."effect"][idx] or 0)
		local info = {vr = 10,st = 3,}
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then info.st = 10 end
		for i = 1,save.elses[item.own_key.."effect"][idx] do
			local q = Isaac.Spawn(5,info.vr,info.st,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
			q:Morph(5,info.vr,info.st,true,true,true)
		end
	end
end,
})

return item