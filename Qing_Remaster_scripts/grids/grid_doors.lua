local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Screen_Filter = require("Qing_Remaster_scripts.others.Screen_Filter")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	ToCall = {},
	myToCall = {},
	doors = {},
	special_reminder = nil,
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
	init_work = function(s,params)
		s:Load(params.loadname or "gfx/grid/door_mausoleum.anm2", false)
		if params.spritename then for i = 0,4 do s:ReplaceSpritesheet(i,params.spritename) end end
		s.Color = params.color or Color(1,1,1,1)
		s:LoadGraphics()
		s:Play(params.playname or "Opened",true)
	end,
	movable_roomtype = {
		[3] = true,
		[5] = function(info)
			local desc = Game():GetLevel():GetCurrentRoomDesc()
			if desc.SafeGridIndex == -7 then return true end
		end,
		[24] = true,
	},
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	item.doors = {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local level = Game():GetLevel()
	local room = Game():GetRoom()
	local desc = level:GetCurrentRoomDesc()
	if item.special_reminder then
		if (item.special_reminder.Type == nil or desc.Data.Type == item.special_reminder.Type) and (item.special_reminder.Variant == nil or desc.Data.Variant == item.special_reminder.Variant) then
			local ret = item.special_reminder.Funct()
			if ret then
				local ret2 = 0 if ret > 0 then ret2 = 1 end
				Screen_Filter.add_filter(ret,ret2)
			end
		end
	end
	item.special_reminder = nil
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local room = Game():GetRoom()
	for i = #item.doors,1,-1 do
		local v = item.doors[i]
		if v.safe_grid_index ~= Game():GetLevel():GetCurrentRoomDesc().SafeGridIndex or v.safe_grid_type ~= desc.Data.Type or v.safe_grid_variant ~= desc.Data.Variant or v.should_kill_me then
			table.remove(item.doors,i)
		else
			local door = room:GetGridEntity(v.idx)
			if door then
				if v.should_update then door:GetSprite():Update() end
				if v.on_update then	v.on_update(v) end
				if v.update then item.normal_update(v,door) end
				local player = auxi.check_pos_for_door(v.idx,item.dir_map[v.dir],v.inner)
				if player then
					if v.special_reminder then
						item.special_reminder = {Type = v.Type,Variant = v.Variant,Funct = v.special_reminder,}
					end
					if v.targ then
						Game():GetLevel().LeaveDoor = v.refer_slot or v.slot or 0
						if type(v.targ) == "string" then Isaac.ExecuteCommand("goto ".. v.targ)
						elseif type(v.targ) == "function" then v.targ(v,player)	end
					end
				end
			else
				table.remove(item.doors,i)
			end
		end
	end
end,
})

function item.try_spawn_grid_door(room,slot,indx,params)
	local level = Game():GetLevel()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	room = room or Game():GetRoom()
	params = params or {}
	local ind_pos = indx or -1
	if slot and slot >= 0 then ind_pos = room:GetGridIndex(room:GetDoorSlotPosition(slot)) end
	local door = room:GetGridEntity(ind_pos)
	if door == nil then return end
	local tg = nil
	for u,v in pairs(item.doors) do
		if v.idx == ind_pos and v.safe_grid_type == desc.Data.Type and v.safe_grid_variant == desc.Data.Variant then tg = u break end
	end
	
	local s = door:GetSprite()
	if params.on_render and (not auxi.check_if_any(item.movable_roomtype[desc.Data.Type],nil)) and (not (Game():GetLevel():GetStage() == 11 and Game():GetLevel():GetStageType() == 0)) then 
		local tg = nil
		if tg == nil then 
			tg = auxi.fire_nil(room:GetGridPosition(ind_pos),Vector(0,0),{cooldown = 10 * 30,}) 
			tg:AddEntityFlags(EntityFlag.FLAG_RENDER_WALL | EntityFlag.FLAG_RENDER_FLOOR)
			tg:GetData().is_grid_door_sprite = true
		end
		s:Load("gfx/effects/nil_effect.anm2",true)
		s:Play("Idle",true)
		s = tg:GetSprite()
	end
	
	params.init_work = params.init_work or item.init_work
	params.init_work(s,params)
	local dir = item.slot_dir_map[slot] or params.dir or 0
	local mov = params.mov or 15
	s.Scale = params.scale or Vector(1,1)
	if dir == 0 then
		s.Rotation = 270
		s.Offset = Vector(mov, 0)
	elseif dir == 1 then
		s.Rotation = 0
		s.Offset = Vector(0, mov)
	elseif dir == 2 then
		s.Rotation = 90
		s.Offset = Vector(-mov, 0)
	elseif dir == 3 then
		s.Rotation = 180
		s.Offset = Vector(0, -mov)
	end
	if auxi.check_if_any(params.should_not_allow,params) ~= true then door.CollisionClass = GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER end
	local tbl = {door = door,targ = params.check_and_leave,idx = ind_pos,dir = dir,slot = slot or 0,refer_slot = params.refer_slot or slot or 0,
		safe_grid_index = level:GetCurrentRoomDesc().SafeGridIndex,safe_grid_variant = level:GetCurrentRoomDesc().Data.Variant,safe_grid_type = level:GetCurrentRoomDesc().Data.Type,
		Type = params.tp,Variant = params.vr,special_reminder = params.special_reminder,on_update = params.on_update,should_update = params.should_update,inner = params.inner,
	}
	if tg == nil then table.insert(item.doors,tbl)
	else item.doors[tg] = tbl end
	return door
end

function item.force_door_anim(anim)		--先写个全部关上的
	anim = anim or "Close"
	local room = Game():GetRoom()
	for u,v in pairs(item.doors) do
		local door = room:GetGridEntity(v.idx)
		door:GetSprite():Play(anim,true)
		if v.on_update == nil then v.update = true end
		if anim == "Close" then door.CollisionClass = GridCollisionClass.COLLISION_WALL end
	end
end

function item.normal_update(v,door)
	local room = Game():GetRoom() local grid = room:GetGridEntity(v.idx)
	local s = grid:GetSprite() local anim = s:GetAnimation() s:Update()
	if s:IsFinished(anim) then
		if anim == "Open" then s:Play("Opened",true) grid.CollisionClass = GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER sound_tracker.PlayStackedSound(SoundEffect.SOUND_DOOR_HEAVY_OPEN,1,1,false,0,2) end
		if anim == "Close" then s:Play("Closed",true) end
	end
end

return item
