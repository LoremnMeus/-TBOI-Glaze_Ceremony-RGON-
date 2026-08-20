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
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local grid_wall = require("Qing_Remaster_scripts.grids.grid_wall")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Faint,
	own_key = "Thoth_cd13_Fai_",
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

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	if save.elses[item.own_key.."effect"] then
		grid_wall.ChangeRoomGfx({Backdrops = BackdropType.DARK_CLOSET,})
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = 380,
Function = function(_,ent,col,low)
	local player = col:ToPlayer()
	if player then
		local d = ent:GetData()
		local succ = consistance_holder.try_check_entity(ent,item.own_key)
		if succ then
			if auxi.can_sleep(player) then 
				if d[item.own_key.."effect2"] then player:UseCard(51,1|(1<<8)) end
				save.elses[item.own_key.."effect"] = true
				if d[item.own_key.."effect3"] == nil then
					local rng = player:GetCardRNG(item.entity)
					rng = auxi.rng_for_sake(rng)
					local seed = rng:GetSeed()
					rng:Next()
					local roomidx = Game():GetLevel():GetRandomRoomIndex(true,seed)
					delay_buffer.addeffe(function(params)
						if player and player:Exists() then
							if player:GetEffectiveMaxHearts() == 0 then	player:AddSoulHearts(6)
							else player:SetFullHearts()	end
							Room_holder.Trans_to(roomidx,0,RoomTransitionAnim.FADE,player)
						end
					end,{},120,true)
				else
					delay_buffer.addeffe(function(params)
						local n_entity = Isaac.GetRoomEntities()
						for u,v in pairs(n_entity) do
							if v.Type == 5 and ent.Variant == 380 then
								if consistance_holder.try_check_entity(v,item.own_key) then v:Remove() end
							end
						end
						grid_wall.ChangeRoomGfx({Backdrops = BackdropType.DARK_CLOSET,})
					end,{},120,true)
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = 380,
Function = function(_,ent)
	local succ = consistance_holder.try_check_entity(ent,item.own_key)
	-- 小退会重建床：故意 Remove，避免堵唯一的门。离房后床本就不会留在布局里。
	if succ then
		consistance_holder.try_remove_entity(ent,item.own_key)
		ent:Remove()
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = 380,
Function = function(_,ent)
	local s = ent:GetSprite()
	if s:IsFinished("Appear") then
		s:Play("Idle",true)
	end
	if s:IsEventTriggered("Drop") then
		ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL 
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	local rng = player:GetCardRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local q = Isaac.Spawn(5,380,0,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
		local s = q:GetSprite()
		s:Load("gfx/cards/cd13_Faint_Bed.anm2",true)
		s:Play("Appear",true)
		q.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
		local d = q:GetData()
		consistance_holder.try_hold_entity(q,item.own_key)
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then d[item.own_key.."effect2"] = true end
		if rng:RandomInt(1000) > 800 then
			s:ReplaceSpritesheet(0,"gfx/effects/isaacbed_barren.png")
			s:LoadGraphics()
			d[item.own_key.."effect3"] = true
		end
	end
end,
})

return item