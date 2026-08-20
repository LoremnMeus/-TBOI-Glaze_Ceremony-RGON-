local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")
local grid_door = require("Qing_Remaster_scripts.grids.grid_doors")
local card_01_wizard = require("Qing_Remaster_scripts.cards.Card_01_Wizard")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Profound_r,
	own_key = "Thoth_cd21r_Pro_",
	door_info = {
		[0] = {num = 3,snd = SoundEffect.SOUND_HEARTBEAT,frame = 30,mul = 1,},
		[1] = {num = 5,snd = SoundEffect.SOUND_HEARTBEAT,frame = 20,mul = 1.25,},
		[2] = {num = 10,snd = SoundEffect.SOUND_HEARTBEAT_FASTER,frame = 20,mul = 1.5,},
		[3] = {num = 15,snd = SoundEffect.SOUND_HEARTBEAT_FASTER,frame = 15,mul = 1.75,},
	},
	dis2vol = {
		{frame = 0,vol = 2,},
		{frame = 100,vol = 1.5,},
		{frame = 300,vol = 1,},
		{frame = 600,vol = 0.5,},
	},
	allow_grid = {
		[GridEntityType.GRID_DECORATION] = true,
		[GridEntityType.GRID_SPIKES] = true,
		[GridEntityType.GRID_SPIKES_ONOFF] = true,
		[GridEntityType.GRID_SPIDERWEB] = true,
		[GridEntityType.GRID_TNT] = true,
		[GridEntityType.GRID_POOP] = true,
		[GridEntityType.GRID_TRAPDOOR] = true,
		[GridEntityType.GRID_STAIRS] = true,
		[GridEntityType.GRID_PRESSURE_PLATE] = true,
		[GridEntityType.GRID_TELEPORTER] = true,
		
		[GridEntityType.GRID_PIT] = true,
		[GridEntityType.GRID_ROCK] = true,
		[GridEntityType.GRID_ROCKB] = true,
		[GridEntityType.GRID_ROCKT] = true,
		[GridEntityType.GRID_ROCK_BOMB] = true,
		[GridEntityType.GRID_ROCK_ALT] = true,
		[GridEntityType.GRID_ROCK_SS] = true,
		[GridEntityType.GRID_ROCK_SPIKED] = true,
		[GridEntityType.GRID_ROCK_ALT2] = true,
		[GridEntityType.GRID_ROCK_GOLD] = true,
	},
}

function item.is_profound_room(desc)
	desc = desc or Game():GetLevel():GetCurrentRoomDesc()
	if desc and desc.Data then 
		local vr = desc.Data.Variant
		if vr == 24840 and desc.Data.Type == 8 then return true end
	end
	return false
end

function item.find_profound_room()
	local level = Game():GetLevel()
	local rooms = level:GetRooms()
	for i = 0, rooms.Size - 1 do
		local tg = rooms:Get(i)
		if item.is_profound_room(tg) and auxi.GetDimension(tg) == auxi.GetDimension() then return tg.SafeGridIndex end
	end
end

function item.angle2pan(ang)
	if ang < -135 or ang > 135 then return 1
	elseif ang < 45 and ang > -45 then return -1 end
	return 0
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	local rng = player:GetCardRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local succ = item.find_profound_room() 
		if succ then 
		else 
			succ = Room_holder.Allocate_with()
			Room_holder.Try_replace_with(succ,auxi.GetDimension(),{data = function() Isaac.ExecuteCommand("goto s.supersecret.24840") return Game():GetLevel():GetRoomByIdx(-3).Data end,})
		end
		player:AnimateTeleport(true)
		Room_holder.Trans_to(succ,Direction.NO_DIRECTION,RoomTransitionAnim.TELEPORT,player,-1)
		save.elses[item.own_key.."effect"] = {tarot = d.tarot_cloth_used,}
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if item.is_profound_room() then
		if save.elses[item.own_key.."effect"] then
			local info = item.door_info[save.elses[item.own_key.."effect"].counter or 0]
			if info then
				if Game():GetRoom():GetFrameCount() % info.frame == 5 then
					local door = (save.elses[item.own_key.."effect"].list or {})[1]
					local room = Game():GetRoom()
					if door then
						local pos = room:GetGridPosition(door.id)
						local dir = Game():GetPlayer(0).Position - pos
						local pan = item.angle2pan(dir:GetAngleDegrees())
						local vol = auxi.check_lerp(dir:Length(),item.dis2vol).vol * info.mul
						if pan ~= 0 then vol = vol * 1.5 end
						sound_tracker.PlayStackedSound(info.snd,vol,1,false,pan,2)
					end
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local room = Game():GetRoom()
	local level = Game():GetLevel()
	local curse = level:GetCurses()
	if item.is_profound_room() then
		local player = Game():GetPlayer(0)
		item_displaying_holder.check_and_description("Level","Profound","Profound","",player,false)
		if curse & (1<<2) ~= (1<<2) and save.elses[item.own_key.."curse"] == nil then
			save.elses[item.own_key.."curse"] = true
			level:AddCurse(1<<2,false)
		end
		for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
			local door = room:GetDoor(slot)
			if door then room:RemoveDoor(slot) end 
		end
		if save.elses[item.own_key.."effect"] then
			local id = (save.elses[item.own_key.."effect"].counter or 0)
			local infos = item.door_info[id] or {}
			local cnt = infos.num
			if cnt then
				if #(save.elses[item.own_key.."effect"].list or {}) ~= cnt then
					local rng = player:GetCardRNG(item.entity)
					save.elses[item.own_key.."effect"].list = {}
					local size = room:GetGridSize()
					local dir_j = room:GetGridWidth()
					local dirs = {[0] = {delta = 1,dir = 0,},[1] = {delta = dir_j,dir = 1,},[2] = {delta = -1,dir = 2,},[3] = {delta = -dir_j,dir = 3,},}
					local succ_tbl = {}
					for i = 0,size - 1 do
						local gent = room:GetGridEntity(i)
						if gent and gent:GetType() == GridEntityType.GRID_WALL and room:IsPositionInRoom(room:GetGridPosition(i),0) == false then
							local dirinfo = nil
							for u,dir in pairs(dirs) do
								local iidx = i + dir.delta
								if room:IsPositionInRoom(room:GetGridPosition(iidx),0) then
									local gent = room:GetGridEntity(iidx)
									if gent == nil or auxi.check_if_any(item.allow_grid[gent:GetType()],player) then
										dirinfo = dir
										break
									end
								end
							end
							if dirinfo then table.insert(succ_tbl,#succ_tbl + 1,{dir = dirinfo.dir,id = i,}) end
						end
					end
					succ_tbl = auxi.randomOverTable(succ_tbl,rng)
					for i = 1,cnt do save.elses[item.own_key.."effect"].list[i] = succ_tbl[i] end
				end
				for i = 1,cnt do
					local v = save.elses[item.own_key.."effect"].list[i]
					if not v then break end
					if i ~= 1 then 
						grid_door.try_spawn_grid_door(room,nil,v.id,{check_and_leave = function(doorinfo,player)
							Room_holder.Trans_to(auxi.safe_gridindex(),Direction.NO_DIRECTION,RoomTransitionAnim.WALK,player)
						end,should_update = true,loadname = "gfx/grid/door_house.anm2",spritename = "gfx/grid/door_closet_red.png",playname = "Opened",dir = v.dir,})
					else
						grid_door.try_spawn_grid_door(room,nil,v.id,{check_and_leave = function(doorinfo,player)
							Room_holder.Trans_to(level:GetCurrentRoomDesc().SafeGridIndex,Direction.NO_DIRECTION,RoomTransitionAnim.WALK,player)
							save.elses[item.own_key.."effect"].counter = (save.elses[item.own_key.."effect"].counter or 0) + 1
							save.elses[item.own_key.."effect"].list = nil
						end,should_update = true,loadname = "gfx/grid/door_house.anm2",spritename = "gfx/grid/door_closet_red.png",playname = "Opened",dir = v.dir,})
					end
				end
			else
				--card_01_wizard.spawn_a_fool_port(room:FindFreePickupSpawnPosition(room:GetCenterPos(),10,true))
				local ndx = option_index_holder.find_a_new_index()
				local cnt = 3
				if save.elses[item.own_key.."effect"].tarot then cnt = 4 end
				for i = 1,cnt do 
					local q = Isaac.Spawn(5,100,0,room:FindFreePickupSpawnPosition(Game():GetRoom():GetCenterPos() + auxi.get_by_rotate(nil,math.random(360),40 * auxi.choose(1,2,3,4,5)),10,true),Vector(0,0),nil):ToPickup()
					q.OptionsPickupIndex = ndx
				end
				save.elses[item.own_key.."effect"] = nil
				grid_door.try_spawn_grid_door(room,nil,127,{check_and_leave = function(doorinfo,player)
					Room_holder.Trans_to(auxi.safe_gridindex(),Direction.NO_DIRECTION,RoomTransitionAnim.WALK,player)
				end,should_update = true,loadname = "gfx/grid/door_house.anm2",spritename = "gfx/grid/door_closet_red.png",playname = "Opened",dir = 3,})
			end
		else card_01_wizard.spawn_a_fool_port(room:FindFreePickupSpawnPosition(room:GetCenterPos(),10,true)) end
	else
		if save.elses[item.own_key.."curse"] then
			save.elses[item.own_key.."curse"] = nil
			level:RemoveCurses(1<<2)
		end
		for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
			local door = room:GetDoor(slot)
			if door and door.TargetRoomIndex then 
				local desc = level:GetRoomByIdx(door.TargetRoomIndex)
				if desc and item.is_profound_room(desc) then room:RemoveDoor(slot) end
			end 
		end
		local lastdesc = level:GetLastRoomDesc()
		if item.is_profound_room(lastdesc) then 
			local desc = level:GetRoomByIdx(lastdesc.SafeGridIndex,auxi.GetDimension(lastdesc))
			desc.DisplayFlags = 0
			desc.VisitedCount = 0
			level:UpdateVisibility()
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_INIT, params = EffectVariant.DOOR_OUTLINE,
Function = function(_,ent)
	if item.is_profound_room() then ent:Remove() end
end,
})

return item