local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Trinkets.Equality_Agreement,
	own_key = "Trinkets_Equality_Agreement_",
}

function item.work(player,effect)
	local tgs = auxi.getothers(5,nil,nil,nil,function(ent) if ent:ToPickup().Price ~= 0 and ent.Variant ~= 100 then return true else return false end end)
	for u,v in pairs(tgs) do
		if v.Variant ~= 100 then 
			local colid = auxi.get_item_from_pool(nil,true,player:GetTrinketRNG(item.entity))
			v:ToPickup():Morph(5,100,colid,true,true,true)
			auxi.initialize_item(v,{NoEffecr = effect,})
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,priority = -30,
Function = function(_)
	local player = auxi.have_player_has_trinket(item.entity)
	if player and player:GetNumCoins() == 0 and Game():GetRoom():GetType() == 2 then item.work(player,true) end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GAIN_TRINKET, params = item.entity,
Function = function(_,player,tid,cnt,touched,curNum,known,golden)
	if player:GetNumCoins() == 0 and Game():GetRoom():GetType() == 2 then item.work(player,false) end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_ALL_BASIC, params = nil,
Function = function(_,player)
	if auxi.have_player_has_trinket(item.entity) and player:GetNumCoins() == 0 and Game():GetRoom():GetType() == 2 then item.work(player,false) end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = nil,priority = -30,
Function = function(_,ent)
	local player = auxi.have_player_has_trinket(item.entity)
	if ent.FrameCount == 1 and player and player:GetNumCoins() == 0 and Game():GetRoom():GetType() == 2 and ent.Price ~= 0 and ent.Variant ~= 100 then
		local colid = auxi.get_item_from_pool(nil,true,player:GetTrinketRNG(item.entity))
		ent:ToPickup():Morph(5,100,colid,true,true,true)
		auxi.initialize_item(ent,{NoEffecr = true,})
	end
end,
})

return item