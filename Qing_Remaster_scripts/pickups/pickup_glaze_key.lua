local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local glaze_curse = require("Qing_Remaster_scripts.pickups.pickup_glaze_curse")
local Unlocker = require("Qing_Remaster_scripts.core.unlock_manager")
local glaze_crown = require("Qing_Remaster_scripts.items.Item_Crown_of_the_Glaze")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")

local item = {
	pickup = enums.Pickups.Glaze_key,
	ToCall = {}
}

function item.reveal_map(player, rng)
	local level = Game():GetLevel()
	local specials = {}
	local normals = {}
	local rooms = level:GetRooms()
	rng = auxi.rng_for_sake(rng)
	local current = level:GetCurrentRoomDesc()
	for i = 0, rooms.Size do
		local targ = rooms:Get(i)
		if targ ~= nil and targ.SafeGridIndex >= 0 then
			local desc = level:GetRoomByIdx(targ.SafeGridIndex, auxi.GetDimension() or 0)
			if desc ~= nil and desc.Data and desc.SafeGridIndex >= 0 and desc.VisitedCount == 0
				and (desc.DisplayFlags & 5) == 0 and desc.SafeGridIndex ~= current.SafeGridIndex then
				local rtype = desc.Data and desc.Data.Type or RoomType.ROOM_DEFAULT
				if rtype == RoomType.ROOM_DEFAULT then
					normals[#normals + 1] = desc
				else
					specials[#specials + 1] = desc
				end
			end
		end
	end
	local candidates = #specials > 0 and specials or normals
	if #candidates > 0 then
		local chosen = candidates[rng:RandomInt(#candidates) + 1]
		chosen.DisplayFlags = chosen.DisplayFlags | 7
		level:UpdateVisibility()
	end
end

function item.try_collect(player,ent)
	if ent:IsShopItem() and auxi.check_shop_pickup(ent,player) then return nil end
	player:AddKeys(1)
	item.reveal_map(player, ent:GetDropRNG())
	glaze_crown.notify_pickup(player, ent and ent.Position)
	return true
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = item.pickup.Variant,
Function = function(_,ent, col, low)
    local player = col:ToPlayer()
	if ent.SubType == item.pickup.SubType then
		if player then
			local should_collect = item.try_collect(player,ent)
			if should_collect == true then
				glaze_curse.cast_a_glaze(player,ent)
				ent.Velocity = Vector(0,0)
				ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_KEYPICKUP_GAUNTLET,1,1,false,0,2)
				option_index_holder.commit_selection(ent, player, {
					skip_will_collect = true,
					remove_siblings = true,
				})
				if ent:IsShopItem() then auxi.buy_a_pickup(ent,player)
				else ent:GetSprite():Play("Collect", true) end
				return true
			elseif ent:IsShopItem() then return nil 
			else return false end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = item.pickup.Variant,
Function = function(_,ent)
	if ent.SubType == item.pickup.SubType then
		if ent:GetSprite():IsEventTriggered("DropSound") then
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_KEY_DROP0,1,1,false,0,2)
		end
		if ent:GetSprite():IsFinished("Collect") or ent:GetSprite():IsEventTriggered("Remove") then
			ent:Remove()
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = 30,
Function = function(_,ent)
	if Unlocker.should_any_be_done("Pickup","Glaze_Key",nil,"Pickup_allow") then
		if ent.SubType == 1 then
			local rng = ent:GetDropRNG()
			rng = auxi.rng_for_sake(rng)
			if glaze_crown.roll_convert(rng, 15) then		-- 原 1/15
				ent:Morph(5,item.pickup.Variant,item.pickup.SubType,true)
			end
		end
	end
end,
})

return item
