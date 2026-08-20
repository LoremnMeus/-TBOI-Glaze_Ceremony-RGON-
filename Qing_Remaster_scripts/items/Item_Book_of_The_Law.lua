local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local dropping_holder = require("Qing_Remaster_scripts.others.Dropping_holder")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Items.Book_of_The_Law,
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,coltyp,rng,player,useFlags,activeSlot,customVarData)
	local ret = true
	if coltyp == item.entity then
		if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
		else
		end
		if save.elses.book_of_the_law == nil then save.elses.book_of_the_law = {} end
		local typ = Game():GetItemPool():GetPoolForRoom(Game():GetRoom():GetType(),Game():GetLevel():GetCurrentRoomDesc().SpawnSeed)
		if typ == -1 then typ = 0 end
		table.insert(save.elses.book_of_the_law,typ)
		if auxi.should_do_belial(player) and typ == 3 then for i = 1,2 do table.insert(save.elses.book_of_the_law,typ) end end
		return ret
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = nil,
Function = function(_,ent)
	if ent.Type == 3 and ent.Variant == FamiliarVariant.WISP and ent.SubType == item.entity then
		local rng = ent:GetDropRNG()
		rng = auxi.rng_for_sake(rng)
		local player = ent.Player
		if player then
			player:UseActiveItem(item.entity,11,-1)
		end
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GET_COLLECTIBLE, params = nil,
Function = function(_,pooltp,decrease,seed)
	if save.elses.book_of_the_law and (#save.elses.book_of_the_law) > 0 and Game():GetFrameCount() > 5 then
		local typ = save.elses.book_of_the_law[1]
		if typ ~= pooltp and save.elses.book_of_the_law_mutex ~= true then
			save.elses.book_of_the_law_mutex = true
			local colid = Game():GetItemPool():GetCollectible(typ,decrease,seed)
			if decrease then
				table.remove(save.elses.book_of_the_law,1)
			end
			save.elses.book_of_the_law_mutex = nil
			return colid
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses.book_of_the_law = {}
		save.elses.book_of_the_law_mutex = nil
	end
end,
})

return item