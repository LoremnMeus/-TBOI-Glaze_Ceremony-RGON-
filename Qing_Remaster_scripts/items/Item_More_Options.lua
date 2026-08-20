local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.More_Options___,
	own_key = "Item_more_option_",
}
auxi.add_to_seija(item.entity)

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_CHECK_PRICE, params = nil,
Function = function(_,ent,val)
	local d = ent:GetData()
	local succ = consistance_holder.try_check_entity(ent,item.own_key)
	if succ then
		local rng = RNG()
		rng:SetSeed(ent:GetDropRNG():GetSeed(),0)
		rng = auxi.rng_for_sake(rng)
		if val > 0 then
			local rnd = rng:RandomInt(math.ceil(val * 0.35)) + 1
			if auxi.should_do_Seija(auxi.have_player_has_collectible(item.entity) or Game():GetPlayer(0)) then rnd = val * 2 end
			return val + rnd
		end
		if val < 0 and val > -10 and val ~= -5 then
			local rnd = rng:RandomInt(1000)
			if rnd < 750 then
				local price = auxi.get_acceptible_devil_price(ent,-2,{ignore_flesh = true,})
				return price
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local should_count = false
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.has_have_coll(player,item.entity) then
			should_count = true
		end
	end
	if should_count then
		local room = Game():GetRoom()
		if room:IsFirstVisit() then
			local n_entity = Isaac.GetRoomEntities()
			local n_shop_pickups = auxi.getothers(n_entity,5)
			for u,v in pairs(n_shop_pickups) do
				local vv = v:ToPickup()
				if vv:IsShopItem() then
					local q = Isaac.Spawn(5,150,0,room:FindFreePickupSpawnPosition(vv.Position + Vector(-20,0),10,true),Vector(0,0),nil):ToPickup()
					if vv.Price ~= -5 then
						vv.Position = room:FindFreePickupSpawnPosition(vv.Position + Vector(20,0),10,true)
					end
					local ndx = option_index_holder.find_a_new_index()
					for u1,v1 in pairs({q,vv}) do
						v1.OptionsPickupIndex = ndx
						price_holder.catch_price_over(v1)
						consistance_holder.try_hold_entity(v1,item.own_key)
					end
				end
			end
		end
	end
end,
})

return item