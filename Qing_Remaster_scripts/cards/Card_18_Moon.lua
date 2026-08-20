local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local card_01_wizard = require("Qing_Remaster_scripts.cards.Card_01_Wizard")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Moon,
	own_key = "Thoth_cd18_Moo_",
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

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = 1000,
Function = function(_,ent)
	local succ = consistance_holder.try_check_entity(ent,item.own_key)
	if succ then
		local level = Game():GetLevel()
		local rooms = level:GetRooms()
		local dimen = auxi.GetDimension()
		for i = 1, rooms.Size do
			local targ = rooms:Get(i - 1)
			if targ and dimen == auxi.GetDimension(targ) then
				local desc = level:GetRoomByIdx(targ.SafeGridIndex)
				if desc then
					local tp = desc.Data.Type
					if tp == 7 then 
						local q = card_01_wizard.spawn_a_fool_port(ent.Position,{info = {id = i,gidx = targ.SafeGridIndex,tp = 7,},})
						break
					end
				end
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
		local pos = room:FindFreePickupSpawnPosition(player.Position + Vector(0,-60),10,true)
		local q = Isaac.Spawn(1000,39,1,pos,Vector(0,0),nil):ToEffect()
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then 
			consistance_holder.try_hold_entity(q,item.own_key)
		end
	end
end,
})


return item