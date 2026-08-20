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
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder") 

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Universe_r,
	own_key = "Thoth_cd21r_Uni_",
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
Function = function(_)
	local room = Game():GetRoom()
	local player = Game():GetPlayer(0)
	if save.elses[item.own_key.."effect_s"] ~= nil and save.elses[item.own_key.."effect_s"] ~= false and save.elses[item.own_key.."effect"]~= nil and save.elses[item.own_key.."effect"] ~= 0 then
		local q = Isaac.Spawn(5,300,item.entity,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
		q:Morph(5,300,item.entity,true,true,true)
		q.PositionOffset = Vector(0,-600)
		q:GetData()[item.own_key.."effect"] = true
		save.elses[item.own_key.."effect_s"] = false
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_,shouldsave)
	if shouldsave then
	else
		save.elses[item.own_key.."effect_s"] = nil
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = 0
		save.elses[item.own_key.."effect_s"] = nil
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or 0
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = 300,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then 
		if d.add_vel == nil then d.add_vel = 0 end
		if d.add_acce == nil then d.add_acce = 7 end
		d.add_vel = d.add_vel + d.add_acce
		local ymx = ent.PositionOffset.Y + d.add_vel
		if ymx > 0 then 
			d.add_vel = - d.add_vel * 0.7 
			if d.add_vel < 10 then
				d.add_acce = 0
				d.add_vel = 0
			end
			ymx = 0
		end
		ent.PositionOffset = Vector(ent.PositionOffset.X,ymx)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local rng = player:GetCardRNG(cardtype)
	rng = auxi.rng_for_sake(rng)
	local d = player:GetData()
	local idx = d.__Index
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		save.elses[item.own_key.."effect_s"] = true
		if save.elses[item.own_key.."effect"] == nil or save.elses[item.own_key.."effect"] == 0 then
			local col = auxi.get_random_item_that_player_has(player,rng,{ignore_pocket_item = true,by_weight = function(val,id) local collectible = Isaac:GetItemConfig():GetCollectible(id) if collectible then return collectible.Quality + 2 end end})
			if col then
				player:AnimateCollectible(col,"LiftItem","PlayerPickup")
				delay_buffer.addeffe(function(params)
					if player:IsHoldingItem() then
						player:AnimateCollectible(col,"HideItem","PlayerPickup")
						player:RemoveCollectible(col)
						save.elses[item.own_key.."effect"] = col
						sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLACK_POOF,1,1,false,0,2)
						local e1 = Isaac.Spawn(1000,16,2,player.Position,Vector(0,0),player)
						local e2 = Isaac.Spawn(1000,16,1,player.Position,Vector(0,0),player)
					end
				end,{},15)
			end
		else
			unique_holder.Hold_for_missing(true) 
			local q = Isaac.Spawn(5,100,save.elses[item.own_key.."effect"],room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
			if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
			else
				auxi.self_morph(q,{5,100,save.elses[item.own_key.."effect"],})
				q.Touched = true
				q.Charge = 0
			end
			unique_holder.Hold_for_missing()
		end
	end
end,
})

return item