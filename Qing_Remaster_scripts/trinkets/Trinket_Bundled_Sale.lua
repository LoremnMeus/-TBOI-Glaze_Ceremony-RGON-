local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Trinkets.Bundled_Sale,
	own_key = "Trinkets_Bundled_Sale_",
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_CHECK_PRICE, params = nil,
Function = function(_,ent,val)
	local d = ent:GetData()
	if auxi.have_player_has_trinket(item.entity) then
		if val >= 0 then return val * 2 end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = nil,
Function = function(_,ent)
	if ent:IsShopItem() and auxi.have_player_has_trinket(item.entity) then
		price_holder.try_catch_price(ent)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = nil, priority = 105,
Function = function(_,ent,col,low)
	local player = col:ToPlayer()
	local d = ent:GetData()
	if player and auxi.will_pick_up(player,ent) and ent:IsShopItem() and auxi.can_buy(ent,player) and auxi.have_player_has_trinket(item.entity) then
		delay_buffer.addeffe(function()
			if auxi.check_all_exists(ent) ~= true or ent.Price == 0 then
				local rng = player:GetTrinketRNG(item.entity)
				local tgs = auxi.getothers(nil,5,nil,nil,function(et) if auxi.check_all_exists(et) and et:ToPickup():IsShopItem() and et:ToPickup().Price > 0 then return true end end)
				if #tgs > 0 then
					local tg = auxi.random_in_table(tgs,rng):ToPickup()
					rng:Next()
					tg.Price = 0
				end
			end
		end,{},1)
	end
end,
})

return item