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
local item_pool_holder = require("Qing_Remaster_scripts.callbacks.item_pool_holder")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder") 

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Universe,
	own_key = "Thoth_cd21_Uni_",
	Star_items = {
		588,589,590,591,592,593,594,595,596,597,598,enums.Items.Pendulum_Star,
		233,651,
		299,300,301,302,303,304,305,306,307,308,309,318,
	},
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_CHECK_ITEMPOOL, params = nil,
Function = function(_,name,val)
	local tbl = {}
	for u,v in pairs(item.Star_items) do tbl[v] = {id = v,weigh = 1,} end
	val[item.own_key] = {list = tbl,default = 233,}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local rng = player:GetCardRNG(cardtype)
	rng = auxi.rng_for_sake(rng)
	local n_entity = Isaac.GetRoomEntities()
	local n_enemy = auxi.getenemies(n_entity)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local col = auxi.get_random_item_that_player_has(player,rng,{ignore_pocket_item = true,by_weight = function(val,id) local collectible = Isaac:GetItemConfig():GetCollectible(id) if collectible then return collectible.Quality + 2 end end})
		if col then
			player:AnimateCollectible(col,"LiftItem","PlayerPickup")
			local targ1 = item_pool_holder.get_coll_from(item.own_key,true,rng)
			if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
				local targ2 = item_pool_holder.get_coll_from(item.own_key,true,rng)
				delay_buffer.addeffe(function(params)
					if player:IsHoldingItem() then
						player:AnimateCollectible(col,"HideItem","PlayerPickup")
						player:RemoveCollectible(col)
						unique_holder.Hold_for_missing(true) 
						local q1 = Isaac.Spawn(5,100,targ1,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
						local q2 = Isaac.Spawn(5,100,targ2,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
						auxi.self_morph(q1,{5,100,targ1,no_morph = true,no_dul = true,})
						auxi.self_morph(q2,{5,100,targ2,no_morph = true,no_dul = true,})
						unique_holder.Hold_for_missing() 
						sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLACK_POOF,1,1,false,0,2)
						local e1 = Isaac.Spawn(1000,16,2,player.Position,Vector(0,0),player)
						local e2 = Isaac.Spawn(1000,16,1,player.Position,Vector(0,0),player)
						local ndx = option_index_holder.find_a_new_index()
						q1.OptionsPickupIndex = ndx
						q2.OptionsPickupIndex = ndx
					end
				end,{},15)
			else
				delay_buffer.addeffe(function(params)
					if player:IsHoldingItem() then
						player:AnimateCollectible(col,"HideItem","PlayerPickup")
						player:RemoveCollectible(col)
						unique_holder.Hold_for_missing(true) 
						local q = Isaac.Spawn(5,100,targ1,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
						auxi.self_morph(q,{5,100,targ1,no_morph = true,no_dul = true,})
						unique_holder.Hold_for_missing() 
						sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLACK_POOF,1,1,false,0,2)
						local e1 = Isaac.Spawn(1000,16,2,player.Position,Vector(0,0),player)
						local e2 = Isaac.Spawn(1000,16,1,player.Position,Vector(0,0),player)
					end
				end,{},15)
			end
		end
	end
end,
})

return item