local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Challenges.Louvre_puzzle,
	pause_counter = 0,
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = nil,
Function = function(_,ent)
	if Game().Challenge == item.entity then
		if ent.Type == 5 and ent.Variant == 100 and (ent.SubType ~= 0) then
			local collectible = Isaac.GetItemConfig():GetCollectible(ent.SubType)
			local del_pos = 1000
			for playerNum = 1, Game():GetNumPlayers() do
				local player = Game():GetPlayer(playerNum - 1)
				del_pos = math.min((player.Position - ent.Position):Length(),del_pos)
			end
			local d = ent:GetData()
			local s = ent:GetSprite()
			if d.morph_counter == nil then d.morph_counter = 0 end
			if item.pause_counter <= 0 then
				d.morph_counter = d.morph_counter + 1
			end
			if d.morph_counter > del_pos * 0.1 then
				d.morph_counter = 0
				local roomPool = g.ItemPool:GetPoolForRoom(g.game:GetRoom():GetType(), g.game:GetLevel():GetCurrentRoomDesc().SpawnSeed)
				if roomPool == -1 then roomPool = ItemPoolType.POOL_TREASURE end
				local targetItem = g.ItemPool:GetCollectible(roomPool, true, ent.InitSeed)
				ent.SubType = targetItem
				ent.Touched = false
				local target_collectible = Isaac.GetItemConfig():GetCollectible(targetItem)
				ent.Charge = target_collectible.MaxCharges
				if auxi.isBlindPickup(ent) == false then
					s:ReplaceSpritesheet(1, target_collectible.GfxFileName)
					s:LoadGraphics()
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_,ent)
	if Game().Challenge == item.entity then
		if item.pause_counter > 0 then item.pause_counter = item.pause_counter - 1 end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = nil,
Function = function(_,ent)
	if Game().Challenge == item.entity then
		if ent.Type == 5 and ent.Variant == 100 and (ent.SubType == CollectibleType.COLLECTIBLE_BREAKFAST) then
			return false
		end
	end
end,
})

--table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	if Game().Challenge == item.entity then
		local player = Game():GetPlayer(0)
		player:UseActiveItem(CollectibleType.COLLECTIBLE_DEATH_CERTIFICATE, UseFlag.USE_NOANIM)
		player:StopExtraAnimation()
		--Game():StartRoomTransition(80,Direction.NO_DIRECTION, RoomTransitionAnim.MINECART, player,2)
		delay_buffer.addeffe(function(params)
			if auxi.GetDimension() ~= 2 then
				Room_holder.Trans_to(80,Direction.NO_DIRECTION,RoomTransitionAnim.MINECART,player,2,{On_Arrive = function() 
					for playerNum = 1, Game():GetNumPlayers() do
						local player = Game():GetPlayer(playerNum - 1)
						player.Position = Game():GetRoom():GetCenterPos()
						player:PlayExtraAnimation("Appear")
						player:AddControlsCooldown(30)
					end
				end,})
			end
		end,{},1)
	end
end,
})
--l local Room_holder = require("Qing_Remaster_scripts.others.Room_holder") Room_holder.Trans_to(83,Direction.NO_DIRECTION, RoomTransitionAnim.MINECART,Game():GetPlayer(0),-1)
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		if Game().Challenge == item.entity then
			local player = Game():GetPlayer(0)
			player:SetPocketActiveItem(CollectibleType.COLLECTIBLE_PAUSE)
		end
	end
	item.pause_counter = 0
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = nil,
Function = function(_, collid, rng, player, flags, slot, data)
	if Game().Challenge == item.entity then
		if collid == CollectibleType.COLLECTIBLE_PAUSE then
			item.pause_counter = item.pause_counter + 60
		end
	end
end,
})

return item
