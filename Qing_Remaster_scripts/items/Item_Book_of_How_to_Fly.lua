local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local player_offset_holder = require("Qing_Remaster_scripts.callbacks.player_offset_holder")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local Laser_holder = require("Qing_Remaster_scripts.mimics.Laser_holder")
local Akeldama_holder = require("Qing_Remaster_scripts.mimics.Akeldama_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Book_of_How_to_Fly,
	own_key = "Item_Book_of_How_to_Fly_",
	fall_offset = {
		{frame = 0,offset = Vector(0,-5),},
		{frame = 20,offset = Vector(0,0),},
		{frame = 100,offset = Vector(0,20),},
	},
	ignore_familiars = {
		[FamiliarVariant.WISP] = function(ent,item) if ent.SubType == item.entity then return true end end,
	},
	limit = 30,
	limit2 = 30,
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,colid,rng,player,useFlags,activeSlot,customVarData)
	local ret = true
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then		--0充能的道具不会触发这一条
		player_offset_holder.LoadPlayer(player,true)
		player:GetData()[item.own_key.."effect"] = player:GetData()[item.own_key.."effect"] or {}
		player:GetData()[item.own_key.."effect"].counter = 0
	else
		if Game():GetRoom():GetType() == 16 then
			player.Velocity = player.Velocity + Vector(0,-5)
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_CAR_BATTERY) then player.Velocity = player.Velocity + Vector(0,-5) end
		else
			player_offset_holder.LoadPlayer(player,true)
			player:GetData()[item.own_key.."effect"] = player:GetData()[item.own_key.."effect"] or {}
			player:GetData()[item.own_key.."effect"].counter = math.min(player:GetData()[item.own_key.."effect"].counter or 3,5)
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_CAR_BATTERY) then player:GetData()[item.own_key.."effect"].counter = 0 end
		end
		if auxi.should_do_belial(player) then
			Laser_holder.set_remove(true)
			item.SetLaser = true
			local q = player:FireTear(player.Position,Vector(0,0),true,true,true) --Isaac.Spawn(2,1,0,player.Position,Vector(0,0),player):ToTear()
			q.Scale = 1.5
			q:ResetSpriteScale()
			q.FallingAcceleration = math.max(q.FallingAcceleration,0.1)
			q.TearFlags = q.TearFlags & ~(BitSet128(1<<60,0))
			item.SetLaser = nil
			Laser_holder.set_remove(nil)
			if Game().Challenge == enums.Challenges.Dragon_Flight then 
				--q.TearFlags = q.TearFlags | BitSet128(0,1<<(123-64)) 
				Akeldama_holder.Add_2(q,player,1)
				q.FallingAcceleration = 0.01 
				q.Mass = 0.1
			end
			q.Height = auxi.offset2height(player_offset_holder.GetPlayerOffset(player),q.FallingAcceleration)
			q:GetData()[item.own_key.."effect"] = {}
			q.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
		end
	end
	return ret
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHECK_PLAYER_POSITIONOFFSET, params = nil,
Function = function(_,player,value)
	local d = player:GetData()
	if d[item.own_key.."effect"] then
		value.Offset = value.Offset + (d[item.own_key.."effect"].offset or Vector(0,0))
		value.Remove = false
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local s = player:GetSprite()
	if d[item.own_key.."effect"] then
		d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) + 1
		local info = auxi.check_lerp(d[item.own_key.."effect"].counter or 0,item.fall_offset)
		d[item.own_key.."effect"].offset = info.offset + (d[item.own_key.."effect"].offset or Vector(0,0))--(d[item.own_key.."effect"].savedoffset or Vector(0,0))
		if player_offset_holder.GetPlayerOffset(player).Y < -item.limit then
			d[item.own_key.."GridCollision"] = d[item.own_key.."GridCollision"] or Attribute_holder.try_hold_attribute(player,"GridCollisionClass",EntityGridCollisionClass.GRIDCOLL_WALLS)
			d[item.own_key.."EntityCollision"] = d[item.own_key.."EntityCollision"] or Attribute_holder.try_hold_attribute(player,"EntityCollisionClass",EntityCollisionClass.ENTCOLL_NONE)
		else
			if d[item.own_key.."GridCollision"] then Attribute_holder.try_rewind_attribute(player,"GridCollisionClass",d[item.own_key.."GridCollision"]) d[item.own_key.."GridCollision"] = nil end
			if d[item.own_key.."EntityCollision"] then Attribute_holder.try_rewind_attribute(player,"EntityCollisionClass",d[item.own_key.."EntityCollision"]) d[item.own_key.."EntityCollision"] = nil end
		end
		if d[item.own_key.."effect"].offset.Y > 0 then
			if d[item.own_key.."GridCollision"] then Attribute_holder.try_rewind_attribute(player,"GridCollisionClass",d[item.own_key.."GridCollision"]) d[item.own_key.."GridCollision"] = nil end
			if d[item.own_key.."EntityCollision"] then Attribute_holder.try_rewind_attribute(player,"EntityCollisionClass",d[item.own_key.."EntityCollision"]) d[item.own_key.."EntityCollision"] = nil end
			d[item.own_key.."effect"] = nil
			if player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_MEGA_MUSH) then
				local q = Isaac.Spawn(1000,61,0,player.Position,Vector(0,0),player):ToEffect()
				q.Parent = player
				Game():MakeShockwave(player.Position,0.1,0.025,15)
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_INIT, params = FamiliarVariant.WISP,
Function = function(_,ent)
	if ent.Type == 3 and ent.Variant == FamiliarVariant.WISP and ent.SubType == item.entity then
		local d = ent:GetData()
		local s = ent:GetSprite()
		local player = auxi.check_spawner_player(ent) or Game():GetPlayer(0)
		ent.PositionOffset = player_offset_holder.GetPlayerOffset(player) + Vector(0,-10)
		ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
		ent:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_FAMILIAR_COLLISION, params = nil,
Function = function(_,ent,col,low)
	local player = auxi.check_spawner_player(ent) or Game():GetPlayer(0)
	if auxi.has_have_coll(player,item.entity) and player_offset_holder.GetPlayerOffset(player).Y < -item.limit and auxi.check_if_any(item.ignore_familiars[ent.Variant],ent,item) ~= true then
		return true
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_KNIFE_COLLISION, params = nil,
Function = function(_,ent,col,low)
	local player = auxi.check_spawner_player(ent) or Game():GetPlayer(0)
	if auxi.has_have_coll(player,item.entity) and player_offset_holder.GetPlayerOffset(player).Y < -item.limit then
		return true
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = FamiliarVariant.WISP,
Function = function(_,ent)
	if ent.Type == 3 and ent.Variant == FamiliarVariant.WISP and ent.SubType == item.entity then
		local d = ent:GetData()
		local s = ent:GetSprite()
		ent.PositionOffset = ent.PositionOffset + Vector(0,0.5)
		if ent.PositionOffset.Y >= - item.limit then ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ENEMIES end
		if ent.PositionOffset.Y >= 0 then ent:Kill() end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		if ent.PositionOffset.Y >= - item.limit2 then ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ENEMIES
		else ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local n_entity = Isaac.GetRoomEntities()
	for u,v in pairs(n_entity) do
		if v.Type == 3 and v.Variant == FamiliarVariant.WISP and v.SubType == item.entity then
			v:Remove()
		end
	end
end,
})

return item