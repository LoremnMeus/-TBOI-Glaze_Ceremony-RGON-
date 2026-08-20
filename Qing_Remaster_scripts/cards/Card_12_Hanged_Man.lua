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
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local r_Hanged_Man = require("Qing_Remaster_scripts.cards.Card_12r_Hanged_Man")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Hanged_Man,
	own_key = "Thoth_cd12_Han_",
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = nil
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[item.own_key.."effect"] = nil
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_RENDER, params = 300,
Function = function(_,ent)
	if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
		local d = ent:GetData()
		if d[item.own_key.."effect"] then 
			local s = d[item.own_key.."sprite2"]
			if (d[item.own_key.."alter"] or 0) == 0 then s = d[item.own_key.."sprite1"] end
			s:Render(Isaac.WorldToScreen(ent.Position),Vector(0,0),Vector(0,0))
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = 300,
Function = function(_,ent)
	if auxi.is_maped_card(ent) then
		if save.elses[item.own_key.."effect"] and save.elses[r_Hanged_Man.own_key.."effect"] then
			local d = ent:GetData()
			if d[item.own_key.."effect"] then 
				local s1 = ent:GetSprite()
				s1:Play("Appear",true)
				local s = d[item.own_key.."sprite2"]
				if (d[item.own_key.."alter"] or 0) == 0 then s = d[item.own_key.."sprite1"] end
				for i = 1,(d[item.own_key.."counter"] or 1) do
					s:Update()
				end
				if s:IsFinished("Appear") then 
					d[item.own_key.."alter"] = 1 - (d[item.own_key.."alter"] or 0)
					s:Play("Appear",true) 
					d[item.own_key.."counter"] = (d[item.own_key.."counter"] or 1) + 1
					if d[item.own_key.."counter"] > 35 then
						local room = Game():GetRoom()
						room:MamaMegaExplosion(ent.Position)
						local rng = ent:GetDropRNG()
						if rng:RandomInt(1000) > 900 then 
							save.elses[item.own_key.."effect"] = nil
							save.elses[r_Hanged_Man.own_key.."effect"] = nil
							Room_holder.Trans_to(-2, Direction.NO_DIRECTION, RoomTransitionAnim.TELEPORT, player)
						end
						ent:Remove()
					end
				end
			else
				local s1 = ent:GetSprite()
				local filename1 = s1:GetFilename()
				ent:Morph(5,300,auxi.get_reversed_card(ent,ent:GetDropRNG()),true,true,true)
				local d = ent:GetData()
				local s2 = ent:GetSprite()
				local filename2 = s1:GetFilename()
				d[item.own_key.."sprite1"] = Sprite()
				d[item.own_key.."sprite1"]:Load(filename1,true)
				d[item.own_key.."sprite1"]:Play("Appear",true)
				d[item.own_key.."sprite2"] = Sprite()
				d[item.own_key.."sprite2"]:Load(filename2,true)
				d[item.own_key.."sprite2"]:Play("Appear",true)
				d[item.own_key.."effect"] = Attribute_holder.try_hold_attribute(ent,"EntityCollisionClass",EntityCollisionClass.ENTCOLL_NONE)
			end
		else
			if auxi.is_reversed_card(ent) ~= true then
				if save.elses[item.own_key.."effect"] then
					ent:Morph(5,300,auxi.get_reversed_card(ent,ent:GetDropRNG()),true,true,true)
				end
			elseif save.elses[r_Hanged_Man.own_key.."effect"] then
				ent:Morph(5,300,auxi.get_reversed_card(ent,ent:GetDropRNG()),true,true,true)
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
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
			local q = Isaac.Spawn(5,300,item.entity,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
			q:Morph(5,300,item.entity,true,true,true)
		end
		save.elses[item.own_key.."effect"] = true
	end
end,
})

return item