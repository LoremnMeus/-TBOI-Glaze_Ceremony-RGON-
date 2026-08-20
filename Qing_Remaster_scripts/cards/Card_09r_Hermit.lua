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
	entity = enums.Cards.Hermit_r,
	own_key = "Thoth_cd9r_Her_",
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
		save.elses[item.own_key.."counter"] = {}
		save.elses[item.own_key.."counter2"] = {}
		save.elses[item.own_key.."counter3"] = {}
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	save.elses[item.own_key.."counter"] = save.elses[item.own_key.."counter"] or {}
	save.elses[item.own_key.."counter2"] = save.elses[item.own_key.."counter2"] or {}
	save.elses[item.own_key.."counter3"] = save.elses[item.own_key.."counter3"] or {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = 100,
Function = function(_,ent)
	if ent.FrameCount == 1 then
		local d = ent:GetData()
		local room = Game():GetRoom()
		if #save.elses[item.own_key.."effect"] > 0 then
			if d.first_appear and ent.Touched == false then
				for i = #save.elses[item.own_key.."effect"],1,-1 do
					local v = save.elses[item.own_key.."effect"][i]
					v.cnt = (v.cnt or 7) - 1
					if v.cnt <= 0 then
						unique_holder.Hold_for_missing(true) 
						local q = Isaac.Spawn(5,100,v.id,room:FindFreePickupSpawnPosition(ent.Position,10,true),Vector(0,0),ent):ToPickup()
						auxi.self_morph(q,{5,100,v.id,})
						unique_holder.Hold_for_missing()
						q.Touched = true
						q.Charge = (v.Charge or 0)
						table.remove(save.elses[item.own_key.."effect"],i)
					end
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local idx = d.__Index
	save.elses[item.own_key.."counter"] = save.elses[item.own_key.."counter"] or {}
	if (save.elses[item.own_key.."counter"][idx] or 0) > 0 then
		if player:IsExtraAnimationFinished() then
			local rng = player:GetCardRNG(item.entity)
			rng = auxi.rng_for_sake(rng)
			local col = auxi.get_random_item_that_player_has(player,rng,{ignore_pocket_item = true,})
			if col then 
				player:AnimateCollectible(col,"LiftItem","PlayerPickup")
				delay_buffer.addeffe(function(params)
					if player:IsHoldingItem() then
						player:AnimateCollectible(col,"HideItem","PlayerPickup")
						local tbl = {cnt = 7,id = col,}
						for slot = 0,1 do if player:GetActiveItem(slot) == col then tbl.Charge = player:GetActiveCharge(slot) + player:GetBatteryCharge(slot) break end end
						table.insert(save.elses[item.own_key.."effect"],#save.elses[item.own_key.."effect"] + 1,tbl)
						player:RemoveCollectible(col)
						sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLACK_POOF,1,1,false,0,2)
						local e1 = Isaac.Spawn(1000,16,2,player.Position,Vector(0,0),player)
						local e2 = Isaac.Spawn(1000,16,1,player.Position,Vector(0,0),player)
						save.elses[item.own_key.."counter"][idx] = save.elses[item.own_key.."counter"][idx] - 1
					end
				end,{},15)
			else
				player:AnimateSad()
				save.elses[item.own_key.."counter"][idx] = save.elses[item.own_key.."counter"][idx] - 1
			end
		end
	elseif save.elses[item.own_key.."counter"][idx] then
		local room = Game():GetRoom()
		for i = 1,save.elses[item.own_key.."counter2"][idx] do
			local q = Isaac.Spawn(5,100,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
			if (save.elses[item.own_key.."counter3"][idx] or 0) > 0 then
				local ndx = option_index_holder.find_a_new_index()
				q.OptionsPickupIndex = ndx
				local q2 = Isaac.Spawn(5,100,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
				q2.OptionsPickupIndex = ndx
				save.elses[item.own_key.."counter3"][idx] = save.elses[item.own_key.."counter3"][idx] - 1
			end
		end
		save.elses[item.own_key.."counter2"][idx] = nil
		save.elses[item.own_key.."counter"][idx] = nil
		save.elses[item.own_key.."counter3"][idx] = nil
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local cnt = 3
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then 
			cnt = 5 
			save.elses[item.own_key.."counter3"][idx] = (save.elses[item.own_key.."counter3"][idx] or 0) + 1
		end
		save.elses[item.own_key.."counter"][idx] = (save.elses[item.own_key.."counter"][idx] or 0) + cnt
		save.elses[item.own_key.."counter2"][idx] = (save.elses[item.own_key.."counter2"][idx] or 0) + 1
	end
end,
})


return item