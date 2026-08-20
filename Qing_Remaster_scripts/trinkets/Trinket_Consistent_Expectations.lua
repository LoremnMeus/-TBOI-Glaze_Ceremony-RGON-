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
	post_myToCall = {},
	post_ToCall = {},
	entity = enums.Trinkets.Consistent_Expectations,
	own_key = "Trinkets_Consistent_Expectations_",
	buffers = {},
	marker = nil,
}

table.insert(item.post_myToCall,#item.post_myToCall + 1,{CallBack = enums.Callbacks.PRE_CHECK_PRICE, params = nil,
Function = function(_,ent,val)
	local d = ent:GetData()
	if auxi.have_player_has_trinket(item.entity) then
		if val > 1 then	
			d[item.own_key.."effect"] = val
			return 1
		else d[item.own_key.."effect"] = nil end
	elseif d[item.own_key.."effect"] then d[item.own_key.."effect"] = nil end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = nil,
Function = function(_,ent)
	if ent:IsShopItem() and auxi.have_player_has_trinket(item.entity) then
		price_holder.try_catch_price(ent)
	end
	local d = ent:GetData()
	if d[item.own_key.."success"] then
		d[item.own_key.."success"].counter = (d[item.own_key.."success"].counter or 0) + 1
		if d[item.own_key.."success"].counter > 3 and ent.Price ~= 0 then ent.Price = 0 end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = nil, priority = -95,
Function = function(_,ent,col,low)
	local player = col:ToPlayer()
	local d = ent:GetData()
	if player and auxi.will_pick_up(player,ent) and d[item.own_key.."effect"] and ent:IsShopItem() and auxi.can_buy(ent,player) then
		local rng = ent:GetDropRNG()
		if rng:RandomFloat() > 1.0/d[item.own_key.."effect"] then
			rng:Next()
			auxi.buy_a_pickup(ent,player,{no_remove = true,})
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_POWERUP1,1,1,false,0,2)
			auxi.try_start_ambush()
			--player:AnimateCollectible(st,"Pickup","PlayerPickupSparkle")
			--item_displaying_holder.display_item(player,st)
			return true
		else d[item.own_key.."success"] = {} end
	end
end,
})

return item