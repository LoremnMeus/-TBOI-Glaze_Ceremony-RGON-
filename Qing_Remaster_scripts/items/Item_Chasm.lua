local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local player_offset_holder = require("Qing_Remaster_scripts.callbacks.player_offset_holder")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")
local thread_shaddoll = require("Qing_Remaster_scripts.threads.thread_Shaddoll")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Chasm,
	own_key = "Item_Chasm_",
	moveoffset = {
		{frame = 1,pos = Vector(0,0),alpha = 1,},
		{frame = 6,pos = Vector(0,-94),alpha = 1,},
		{frame = 14,pos = Vector(0,-144),alpha = 0,},
		total = 14,
	},
	moveoffset2 = {
		{frame = 1,pos = Vector(0,-144),alpha = 0,},
		{frame = 8,pos = Vector(0,-94),alpha = 1,},
		{frame = 14,pos = Vector(0,0),alpha = 1,},
		total = 14,
	},
	Chasm_room = {
		total = 13,
		greedtotal = 7,
	},
}

function item.random_chasm_room()
	if Game():IsGreedMode() then return 24800 + math.random(item.Chasm_room.greedtotal) - 1
	else return 24800 + math.random(item.Chasm_room.total) - 1 end
end

function item.is_chasm_room(desc)
	desc = desc or Game():GetLevel():GetCurrentRoomDesc()
	if not desc or not desc.Data then return false end
	local vr = desc.Data.Variant
	local total = item.Chasm_room.total
	if Game():IsGreedMode() then total = item.Chasm_room.greedtotal end
	if vr >= 24800 and vr < 24800 + total and desc.Data.Type == 1 then return true end
	return false
end

function item.find_chasm_room()
	local level = Game():GetLevel()
	local rooms = level:GetRooms()
	for i = 0, rooms.Size - 1 do
		local tg = rooms:Get(i)
		if item.is_chasm_room(tg) and auxi.GetDimension(tg) == auxi.GetDimension() then return tg.SafeGridIndex end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.Chasm_Hanger,
Function = function(_,ent)
	local s = ent:GetSprite()
	if s:IsFinished("Appear") then 
		--if auxi.safe_gridindex() == Game():GetLevel():GetCurrentRoomDesc().SafeGridIndex then s:Play("Leave",true) end
		s:Play("Idle",true) 
	end
	local d = ent:GetData()
	if d[item.own_key.."effect2"] then
		local tg = d[item.own_key.."effect2"].tg
		if auxi.check_all_exists(tg) then ent.DepthOffset = tg.DepthOffset - 10 end
		if s:GetAnimation() == "Appear" then return end
		d[item.own_key.."effect2"].counter = (d[item.own_key.."effect2"].counter or 0) - 1
		if (d[item.own_key.."effect2"].counter or 0) >= 0 then return 
		else d[item.own_key.."effect2"] = nil end
	end
	if Game():GetRoom():GetFrameCount() <= 3 then return end
	if d[item.own_key.."effect"] == nil or auxi.check_all_exists(d[item.own_key.."effect"].tg) ~= true then
		if s:GetAnimation() == "Idle" then
			for playerNum = 1, Game():GetNumPlayers() do
				local player = Game():GetPlayer(playerNum - 1)
				if (player.Position - ent.Position):Length() < 20 then
					player:GetData()[item.own_key.."effect"] = {tg = ent,}
					d[item.own_key.."effect"] = {tg = player,}
					break
				end
			end
		end
	else
		local tg = d[item.own_key.."effect"].tg
		if (ent.Position - tg.Position):Length() > 1 then ent.Velocity = (ent.Position - tg.Position) * (-0.3)
		else ent.Velocity = ent.Velocity * 0.3 end
		ent.DepthOffset = tg.DepthOffset - 10
		if d[item.own_key.."effect"].go then
			d[item.own_key.."effect"].go = nil
			s:Play("Leave",true)
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHECK_PLAYER_POSITIONOFFSET, params = nil,
Function = function(_,player,value)
	local d = player:GetData()
	if d[item.own_key.."effect"] then
		value.Remove = false
		local tg = d[item.own_key.."effect"].tg
		if auxi.check_all_exists(tg) then d[item.own_key.."effect"].frame = tg:GetSprite():GetFrame() end
		local frame = d[item.own_key.."effect"].frame
		local info = auxi.check_lerp(frame,item.moveoffset)
		value.Offset = value.Offset + info.pos
		return value
	elseif d[item.own_key.."effect2"] then
		value.Remove = false
		local tg = d[item.own_key.."effect2"].tg
		if auxi.check_all_exists(tg) and tg:GetSprite():GetAnimation() == "Appear" then d[item.own_key.."effect2"].frame = tg:GetSprite():GetFrame() end
		local frame = d[item.own_key.."effect2"].frame
		local info = auxi.check_lerp(frame,item.moveoffset2)
		value.Offset = value.Offset + info.pos
		return value
	end
end,
})

function item.finish_chasm(player)
	local d = player:GetData()
	if d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] then Attribute_holder.try_rewind_attribute(player,"ENTITY_FLAG_NO_DAMAGE_BLINK",d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"],Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_DAMAGE_BLINK)) d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] = nil end
	if d[item.own_key.."EntityCollision"] then Attribute_holder.try_rewind_attribute(player,"EntityCollisionClass",d[item.own_key.."EntityCollision"]) d[item.own_key.."EntityCollision"] = nil end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	for i = 1,1 do if d[item.own_key.."effect"] then
		local s = player:GetSprite()
		local tg = d[item.own_key.."effect"].tg
		if auxi.check_all_exists(tg) ~= true then item.finish_chasm(player) d[item.own_key.."effect"] = nil break end
		player:AddControlsCooldown(math.max(0,3 - player.ControlsCooldown))
		player:SetMinDamageCooldown(math.max(0,3 - player:GetDamageCooldown()))
		if d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] == nil then d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] = Attribute_holder.try_hold_attribute(player,"ENTITY_FLAG_NO_DAMAGE_BLINK",true,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_DAMAGE_BLINK)) end
		if d[item.own_key.."EntityCollision"] == nil then d[item.own_key.."EntityCollision"] = Attribute_holder.try_hold_attribute(player,"EntityCollisionClass",EntityCollisionClass.ENTCOLL_NONE)	end
		d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) + 1
		if d[item.own_key.."effect"].counter == 15 then player:AnimateSad()	end
		if d[item.own_key.."effect"].counter == 30 then
			local d2 = tg:GetData()
			d2[item.own_key.."effect"] = (d2[item.own_key.."effect"] or {})
			d2[item.own_key.."effect"].go = true
			player_offset_holder.LoadPlayer(player,true)
		end
		if tg:GetSprite():IsFinished("Leave") and d[item.own_key.."effect"].leave == nil then
			d[item.own_key.."effect"].leave = true
			item.finish_chasm(player)
			item.NoTaken = true
			local succ = nil
			local kick = item.is_chasm_room()
			if not kick then 
				succ = item.find_chasm_room() 
				if succ then 
				else 
					succ = Room_holder.Allocate_with()
					Room_holder.Try_replace_with(succ,auxi.GetDimension(),{data = function() Isaac.ExecuteCommand("goto s.default."..tostring(item.random_chasm_room())) return Game():GetLevel():GetRoomByIdx(-3).Data end,}) 
				end
			end
			local tid = succ or auxi.safe_gridindex()
			Room_holder.Trans_to(tid, -1, RoomTransitionAnim.FADE, player,-1,{On_Arrive = function()
				local data = Game():GetLevel():GetCurrentRoomDesc().Data
				local pos = Game():GetRoom():GetCenterPos()
				if Game():IsGreedMode() then pos = Vector(pos.X,pos.Y * 0.5) end
				pos = auxi.find_in(data) or pos
				for playerNum = Game():GetNumPlayers(),1,-1 do
					local player = Game():GetPlayer(playerNum - 1)
					player.Position = pos + (player.Position - Game():GetPlayer(0).Position)
					local q2 = Isaac.Spawn(1000,enums.Entities.Chasm_Hanger,0,player.Position,Vector(0,0),nil):ToEffect()
					player:GetData()[item.own_key.."effect2"] = {tg = q2,}
					player_offset_holder.LoadPlayer(player,true)
					q2:GetData()[item.own_key.."effect2"] = {tg = player,counter = 5 * 30,}
				end
			end,})
		end
	end end
	for i = 1,1 do if d[item.own_key.."effect2"] then
		local tg = d[item.own_key.."effect2"].tg
		if auxi.check_all_exists(tg) ~= true then item.finish_chasm(player) d[item.own_key.."effect2"] = nil break end
		player:AddControlsCooldown(math.max(0,3 - player.ControlsCooldown))
		player:SetMinDamageCooldown(math.max(0,3 - player:GetDamageCooldown()))
		if d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] == nil then d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] = Attribute_holder.try_hold_attribute(player,"ENTITY_FLAG_NO_DAMAGE_BLINK",true,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_DAMAGE_BLINK)) end
		if d[item.own_key.."EntityCollision"] == nil then d[item.own_key.."EntityCollision"] = Attribute_holder.try_hold_attribute(player,"EntityCollisionClass",EntityCollisionClass.ENTCOLL_NONE)	end
		if tg:GetSprite():GetAnimation() ~= "Appear" then
			item.finish_chasm(player)
			d[item.own_key.."effect2"] = nil
		end
	end end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_INIT, params = 154,
Function = function(_,ent)
	if item.is_chasm_room() then ent:Remove() end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local player = auxi.have_player_has_collectible(item.entity)
	local room = Game():GetRoom()
	if player and (room:GetType() == 7 or (Game():IsGreedMode() and room:GetType() == 8)) then	--room:IsFirstVisited() and 
		local q = Isaac.Spawn(1000,enums.Entities.Chasm_Hanger,0,room:FindFreePickupSpawnPosition(room:GetCenterPos(),10,true),Vector(0,0),nil)
	end
	local level = Game():GetLevel()
	local curse = level:GetCurses()
	if item.is_chasm_room() then
		item_displaying_holder.check_and_description("Level","Chasm","Chasm","",player,false)
		thread_shaddoll.shift_room(1)
		if not item.NoTaken then
			local pos = auxi.find_in() or Game():GetRoom():GetCenterPos()
			local q = Isaac.Spawn(1000,enums.Entities.Chasm_Hanger,0,pos,Vector(0,0),nil)
		end
		if curse & (1<<2) ~= (1<<2) and save.elses[item.own_key.."curse"] == nil then
			save.elses[item.own_key.."curse"] = true
			level:AddCurse(1<<2,false)
		end
		for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
			local door = room:GetDoor(slot)
			if door then room:RemoveDoor(slot) end 
		end
	else
		if save.elses[item.own_key.."curse"] then
			save.elses[item.own_key.."curse"] = nil
			level:RemoveCurses(1<<2)
		end
		local desc = Game():GetLevel():GetCurrentRoomDesc()
		if desc.SafeGridIndex > 0 then
			for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
				local door = room:GetDoor(slot)
				if door and door.TargetRoomIndex then 
					local desc = level:GetRoomByIdx(door.TargetRoomIndex)
					if desc and item.is_chasm_room(desc) then room:RemoveDoor(slot) end
				end 
			end
		end
		local lastdesc = level:GetLastRoomDesc()
		if item.is_chasm_room(lastdesc) then 
			local desc = level:GetRoomByIdx(lastdesc.SafeGridIndex,auxi.GetDimension(lastdesc))
			desc.DisplayFlags = 0
			desc.VisitedCount = 0
			level:UpdateVisibility()
		end
	end
	item.NoTaken = nil
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[item.own_key.."curse"] = nil
end,
})

return item