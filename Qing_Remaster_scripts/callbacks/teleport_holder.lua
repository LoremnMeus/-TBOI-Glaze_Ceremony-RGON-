local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local callback_manager = require("Qing_Remaster_scripts.core.callback_manager")
local input_holder = require("Qing_Remaster_scripts.others.Input_holder")

local item = {
	ToCall = {},
	myToCall = {},
	check_card_type_list = {
		[Card.CARD_FOOL] = true,
		[Card.CARD_EMPEROR] = true,
		[Card.CARD_HERMIT] = true,
		[Card.CARD_STARS] = true,
		[Card.CARD_MOON] = true,
		[Card.CARD_JOKER] = true,
		[Card.CARD_QUESTIONMARK] = function(player)
			if player:GetActiveItem() == CollectibleType.COLLECTIBLE_BLANK_CARD then return true end
			return false
		end,
		[Card.CARD_REVERSE_EMPEROR] = true,
		[Card.CARD_REVERSE_MOON] = true,
	},
	check_pill_type_list = {
		[PillEffect.PILLEFFECT_TELEPILLS] = true,
	},
	check_collid_type_list = {
		[CollectibleType.COLLECTIBLE_TELEPORT] = true,
		[CollectibleType.COLLECTIBLE_FORGET_ME_NOW] = true,
		[CollectibleType.COLLECTIBLE_UNDEFINED] = true,
		[CollectibleType.COLLECTIBLE_TELEPORT_2] = true,
		[CollectibleType.COLLECTIBLE_GLOWING_HOUR_GLASS] = true,
		[CollectibleType.COLLECTIBLE_D7] = function(player,item)
			local room = Game():GetRoom()
			if item.check_D7_room[room:GetType()] then return true end
			return false
		end,
		[CollectibleType.COLLECTIBLE_GENESIS] = true,
		[CollectibleType.COLLECTIBLE_DEATH_CERTIFICATE] = true,
		[CollectibleType.COLLECTIBLE_R_KEY] = true,
	},
	check_D7_room = {
		[RoomType.ROOM_BOSS] = true,
		[RoomType.ROOM_DEVIL] = true,
		[RoomType.ROOM_ANGEL] = true,
	},
	slot_dir_map = {
		[DoorSlot.LEFT0] = 0,
		[DoorSlot.UP0] = 1,
		[DoorSlot.RIGHT0] = 2,
		[DoorSlot.DOWN0] = 3,
		[DoorSlot.LEFT1] = 0,
		[DoorSlot.UP1] = 1,
		[DoorSlot.RIGHT1] = 2,
		[DoorSlot.DOWN1] = 3,
	},
	dir_map = {
		[0] = Vector(1,0),
		[1] = Vector(0,1),
		[2] = Vector(-1,0),
		[3] = Vector(0,-1),
	},
}

--离开房间的方式有：使用卡牌、药丸（回声(不需要了))、主动（破传(不需要了))、接近门、地下室、传送黑洞、读卡、手术刀坑、5点骰子、天梯、地梯、持有诅咒之眼(无法处理豆浆诅咒眼的情况)或诅咒头骨时受伤、持有诅咒硬币时拾取硬币(不需要了)、骨哥按ctrl、被妈手抓走、碰到红箱子、献祭6次以及第11次后、各类复活。
--离开房间的方式有：使用卡牌、药丸、主动、接近门、地下室、传送黑洞、读卡、手术刀坑、5点骰子、天梯、地梯、持有诅咒之眼或诅咒头骨时受伤、持有诅咒硬币时拾取硬币、骨哥长子权按ctrl、被妈手抓走、碰到红箱子传恶魔房、献祭6次以及第11次后、各类复活。
--无法处理TM的情况。当持有TM，且触发了传送动画时，总是认为是发生传送。

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = nil,
Function = function(_,cardtype,player,useflags)
	local means_teleport = item.check_card_type_list[cardtype] 
	if type(means_teleport) == "function" then means_teleport = means_teleport(player) end
	if means_teleport then
		local ty = "card"
		local res = callback_manager.work("PRE_GET_TELEPORT",function(funct,params) if params == nil or params == ty then funct(nil,player,ty,{id = cardtype,}) end end,false)
		if res == false then
			
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_PILL, params = nil,
Function = function(_,pill,player,flag)	
	local means_teleport = item.check_pill_type_list[pill] 
	if type(means_teleport) == "function" then means_teleport = means_teleport(player) end
	if means_teleport then
		local ty = "pill"
		local res = callback_manager.work("PRE_GET_TELEPORT",function(funct,params) if params == nil or params == ty then funct(nil,player,ty,{id = pill,}) end end,false)
		if res == false then
			
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = nil,
Function = function(_, collid, rng, player, flags, slot, data)
	local means_teleport = auxi.check_if_any(item.check_collid_type_list[collid],player,item)
	if means_teleport then
		local ty = "active"
		local res = callback_manager.work("PRE_GET_TELEPORT",function(funct,params) if params == nil or params == ty then funct(nil,player,ty,{id = collid,}) end end,false)
		if res == false then
			
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = EntityType.ENTITY_PLAYER,
Function = function(_,ent, amt, flag, source, cooldown)
	local player = ent:ToPlayer()
	if player then
		if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_CURSED_EYE) then
			if auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_BLACK_CANDLE) then
			else
				if player:HasWeaponType(1) then
					local means_teleport = false
					local ikey = tostring(player.ControllerIndex)
					if input_holder.actionsData_r[ikey] and input_holder.actionsData_r[ikey][51] and input_holder.actionsData_r[ikey][51].ActionHoldTime and input_holder.actionsData_r[ikey][51].ActionHoldTime > 0 then
						if input_holder.actionsData_r[ikey][51].ActionHoldTime <= 4 * player.MaxFireDelay then
							means_teleport = true
						elseif auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_SOY_MILK) then		--放弃了，手测不出来
						end
					end
					if means_teleport then
						local ty = "passive"
						local res = callback_manager.work("PRE_GET_TELEPORT",function(funct,params) if params == nil or params == ty then funct(nil,player,ty,{id = CollectibleType.COLLECTIBLE_CURSED_EYE,}) end end,false)
						if res == false then
							
						end
					end
				end
			end
		end
		if player:HasTrinket(TrinketType.TRINKET_CURSED_SKULL) or player:GetEffects():HasTrinketEffect(TrinketType.TRINKET_CURSED_SKULL) then
			
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GET_TELEPORT, params = nil,
Function = function(_,player, tp, params)
	--print(tp.." "..params.id)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	--print(Game():GetPlayer(0):GetSprite():GetAnimation())
	if player:GetSprite():GetAnimation() == "Trapdoor" and player:GetSprite():GetFrame() == 15 then
		local n_entity = Isaac.GetRoomEntities()
		for u,v in pairs(n_entity) do
			if v.Type == 1000 and v.Variant == 161 then
				if (v.Position - player.Position):Length() == 0 then
					local ty = "portal"
					callback_manager.work("PRE_GET_TELEPORT",function(funct,params) if params == nil or params == ty then funct(nil,player,ty,{id = v.SubType,ent = v,}) end end,false)		--有可能不进行传送
				end
			end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GRID_UPDATE, params = 16,
Function = function(_,idx,gent)
	local room = Game():GetRoom()
	local door = gent:ToDoor()
	if door then
		local player = auxi.get_nearest(auxi.GetPlayers(),gent.Position).tg
		local dir = item.dir_map[door.Direction] or Vector(0,0)
		if player and (player.Position - (door.Position - dir * 18)):Length() < 25 and (item.Leave_frame or -1) ~= Game():GetFrameCount() then		--有时候似乎会重复2次
			item.Leave_frame = Game():GetFrameCount()
			local ty = "door"
			-- 必须回传回调返回值，否则 return false 无法 stop
			callback_manager.work("PRE_GET_TELEPORT",function(funct,params)
				if params == nil or params == ty then
					return funct(nil,player,ty,{door = door,dist = (player.Position - (door.Position - dir * 18)):Length(),})
				end
			end,false)
		end
	end
end,
})

function item.try_leave_room(door,player)
	local dir = door.Direction
	local ty = "door"
	if door and Game():GetLevel():GetRoomByIdx(door.TargetRoomIndex) and door.TargetRoomIndex > -16 then
		--print(door.TargetRoomIndex.." "..dir)
		local room = Game():GetRoom()
		if auxi.check_for_the_same(room:GetDoor(dir),door) ~= true then dir = dir + 4 end
		local blocked = callback_manager.work("PRE_GET_TELEPORT",function(funct,params)
			if params == nil or params == ty then
				return funct(nil,player,ty,{door = door,via = "try_leave_room",})
			end
		end,false)
		if blocked == false then return end
		Game():GetLevel().LeaveDoor = dir 
		Game():StartRoomTransition(door.TargetRoomIndex,door.Direction,RoomTransitionAnim.WALK, player)
	end
end

--[[
local cnt = 10
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if Game():IsPaused() == false then
		local ikey = tostring(player.ControllerIndex)
		if input_holder.actionsData_r[ikey] and input_holder.actionsData_r[ikey][51] and input_holder.actionsData_r[ikey][51].ActionHoldTime and input_holder.actionsData_r[ikey][51].ActionHoldTime > 0 then
			if input_holder.actionsData_r[ikey][51].ActionHoldTime == cnt then player:TakeDamage(1,0,EntityRef(player),0) end
			print(input_holder.actionsData_r[ikey][51].ActionHoldTime)
		end
	end
	--if input_holder.actionsData[ikey] and input_holder.actionsData[ikey][51] and input_holder.actionsData[ikey][51].ActionHoldTime and input_holder.actionsData[ikey][51].ActionHoldTime > 0 then
	--	print(input_holder.actionsData[ikey][51].ActionHoldTime)
	--end
end,
})
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EXECUTE_CMD, params = nil,
Function = function(_,str,params)
	if string.lower(str) == "meus" and params ~= nil then
		local args={}
		for str in string.gmatch(params, "([^ ]+)") do
			table.insert(args, str)
		end
		if args[1] then
			if string.lower(args[1]) == "tele" then
				if args[2] then
					cnt = tonumber(args[2])
				end
			end
		end
	end
end,
})
--]]

return item