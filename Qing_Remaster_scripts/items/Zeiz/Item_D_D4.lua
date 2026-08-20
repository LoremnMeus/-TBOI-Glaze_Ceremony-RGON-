local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Dull = require("Qing_Remaster_scripts.items.Zeiz.Item_Dull_items")

local item = {
	ToCall = {},
	pre_ToCall = {},
	post_ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	post_myToCall = {},
	entity = enums.Items.DI_III,
	own_key = "Item_DI_III_",
}

function item.reroll_items(player,rng)
	local n_item = auxi.getothers(Isaac.GetRoomEntities(),5,100)
	local tbl = {}
	local rng2 = player:GetCollectibleRNG(item.entity)
	for u,v in pairs(n_item) do
		local ent = v:ToPickup()
		local id = ent.SubType
		local succ = false
		if id > 0 then succ = true
		else
			if Dull.get_point(player) > 15 then succ = true end
		end
		if succ then
			local colid = 0
			if auxi.should_do_belial(player) and rng2:RandomFloat() < 0.2 then colid = auxi.get_item_from_pool(3,true,rng) end
			ent:Morph(5,100,colid,true,false,false)
			Dull.add_point(player,1)
			auxi.initialize_item(ent)
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,colid,rng,player,useFlags,activeSlot,customVarData)
	local ret = true
	item.reroll_items(player,rng)
	return ret
end,
})

return item