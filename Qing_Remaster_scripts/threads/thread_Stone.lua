local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local grid_door = require("Qing_Remaster_scripts.grids.grid_doors")
local Unlocker = require("Qing_Remaster_scripts.core.unlock_manager")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local Dialog_holder = require("Qing_Remaster_scripts.others.Dialog_holder")
local board = require("Qing_Remaster_scripts.enemies.Floraine.Enemy_chess_board")

local item = {
	ToCall = {},
	own_key = "Thread_Stone_",
	start_str = {
		zh = {
			[1] = {
				"棋盘已开启",
			},
			[2] = {
				"以撒：",
				"棋盘？发生了什么？",
				"我最好顺着这些黑白格子看一看",
			},
		},
		en = {
			[1] = {
				"The Chess Board Has Appeared in the Level.",
			},
			[2] = {
				"Isaac：",
				"What's the chess board?",
				"I'd better take a look along these black and white grids.",
			},
		},
	},
	banish_room_list = {
		--[1] = true,
		[5] = true,
		[7] = true,
		[8] = true,
		[11] = true,
		[29] = true,
	},
	banish_move_room_list = {
		[7] = true,
		[8] = true,
	},
}
--这个也要重写
function item.set_off()
	save.elses[item.own_key.."spawn"] = nil
	save.elses[item.own_key.."effect"] = nil
	save.elses[item.own_key.."map"] = nil
end

function item.set_on()
	save.elses[item.own_key.."spawn"] = true
	item.plan_a_bfs()
	item.generate_chess_broad()
end

function item.can_spawn()
	local level = Game():GetLevel() local stageType = level:GetStageType()
	return level:GetStage() == LevelStage.STAGE2_1 and stageType >= StageType.STAGETYPE_REPENTANCE
end

function item.should_spawn()
	return item.can_spawn() and save.elses[item.own_key.."spawn"] == true
end

function item.plan_a_bfs()
	local level = Game():GetLevel()
	local rooms = level:GetRooms()
	local rng = Game():GetPlayer(0):GetCollectibleRNG(333)
	local tbl = {}
	for i = 0,rooms.Size - 1 do
		local targ = rooms:Get(i)
		if targ ~= nil and targ.SafeGridIndex >= 0 then
			local id = targ.SafeGridIndex
			local desc = level:GetRoomByIdx(id)
			if desc and desc.Data and item.banish_room_list[desc.Data.Type] ~= true then
				local doors = desc.Data.Doors
				local move_info = auxi.get_moves_in_gridroom(desc.Data.Shape)
				for slot = 0,7 do
					if doors & (1<<slot) == (1<<slot) then
						local tgid = move_info[slot] or 0 
						if auxi.is_safe_move_in_grids(id,tgid) then
							local tdesc = level:GetRoomByIdx(id + tgid) 
							if tdesc.Data == nil then table.insert(tbl,{id = id,slot = slot,}) end
						else
							table.insert(tbl,{id = id,slot = slot,})
						end
					end
				end
			end
		end
	end
	local ret = auxi.random_in_table(tbl,rng)
	if not ret then
		save.elses[item.own_key.."effect"] = nil
		save.elses[item.own_key.."map"] = nil
		return false
	end
	save.elses[item.own_key.."effect"] = ret
	
	save.elses[item.own_key.."map"] = {}
	local tbl = {}
	table.insert(tbl,{id = ret.id,val = 0,}) save.elses[item.own_key.."map"][ret.id] = 0
	while(#tbl > 0) do
		local tab = tbl[1]
		local desc = level:GetRoomByIdx(tab.id)
		if not desc or not desc.Data then break end
		local move_info = auxi.get_moves_in_gridroom(desc.Data.Shape)
		for u,v in pairs(move_info) do
			if auxi.is_safe_move_in_grids(tab.id,v) then
				local tdesc = level:GetRoomByIdx(tab.id + v)
				if tdesc and tdesc.Data and item.banish_move_room_list[tdesc.Data.Type] ~= true then
					local tsgid = tdesc.SafeGridIndex 
					if save.elses[item.own_key.."map"][tsgid] == nil then table.insert(tbl,{id = tsgid,val = tab.val + 1,}) save.elses[item.own_key.."map"][tsgid] = tab.val + 1 end
				end
			end
		end
		table.remove(tbl,1)
	end
	return true
end

function item.generate_chess_broad()
	local room = Game():GetRoom() local level = Game():GetLevel() local desc = level:GetCurrentRoomDesc()
	local move_info = auxi.get_moves_in_gridroom(desc.Data.Shape)
	local pos = room:GetCenterPos()
	if save.elses[item.own_key.."effect"] == nil and not item.plan_a_bfs() then return end
	if not save.elses[item.own_key.."map"] then return end
	if save.elses[item.own_key.."map"][desc.SafeGridIndex] == 0 then 
		pos = room:GetDoorSlotPosition(save.elses[item.own_key.."effect"].slot)
		item.generate_stone_door(save.elses[item.own_key.."effect"].slot)
	else 
		for u,v in pairs(move_info) do
			if auxi.is_safe_move_in_grids(desc.SafeGridIndex,v) then
				local tdesc = level:GetRoomByIdx(desc.SafeGridIndex + v) 
				if tdesc and tdesc.Data then
					local tsgid = tdesc.SafeGridIndex 
					if (save.elses[item.own_key.."map"][tsgid] or 99) == (save.elses[item.own_key.."map"][desc.SafeGridIndex] or 0) - 1 then pos = room:GetDoorSlotPosition(u) break end
				end
			end
		end
	end
	board.start_(pos)
end

function item.generate_stone_door(slot)		--房间的标记还需要放上去
	local room = Game():GetRoom()
	local rng = Game():GetPlayer(0):GetCollectibleRNG(333)
	if save.elses[item.own_key.."effect"] == nil then return end
	local effect = save.elses[item.own_key.."effect"]
	effect.door_variant = effect.door_variant or (rng:RandomInt(11) + 23752)
	local door_variant = effect.door_variant
	if save.elses[item.own_key.."effect"].loaded_door then
		grid_door.try_spawn_grid_door(room,slot,nil,{check_and_leave = "s.default."..tostring(door_variant),should_update = true,loadname = "gfx/grid/door_checkboarddoor.anm2",playname = "Opened",
		vr = door_variant,special_reminder = function()
			local room = Game():GetRoom()
			local pos = room:GetGridPosition(172)
			for playerNum = 1, Game():GetNumPlayers() do
				local player = Game():GetPlayer(playerNum - 1)
				player.Position = pos
				player.Velocity = Vector(0,0)
			end
			return 10
		end})
	else
		save.elses[item.own_key.."effect"].loaded_door = true
		grid_door.try_spawn_grid_door(room,slot,nil,{check_and_leave = "s.default."..tostring(door_variant),should_update = true,loadname = "gfx/grid/door_checkboarddoor.anm2",playname = "Appear_and_Open",
		vr = door_variant,special_reminder = function()
			local room = Game():GetRoom()
			local pos = room:GetGridPosition(172)
			for playerNum = 1, Game():GetNumPlayers() do
				local player = Game():GetPlayer(playerNum - 1)
				player.Position = pos
				player.Velocity = Vector(0,0)
			end
			return 10
		end,should_not_allow = true,on_update = function(doorinfo)
			local door = doorinfo.door
			local s = door:GetSprite()
			if s:IsFinished("Appear_and_Open") then
				s:Play("Opened",true)
				door.CollisionClass = GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER
			end
			if not s:IsPlaying("Opened") and not s:IsPlaying("Appear_and_Open") then
				s:Play("Appear_and_Open",true)
			end
		end})
		sound_tracker.PlayStackedSound(52,1,0.7,false,0,2)
	end
end
	
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, params = nil,
Function = function(_,rng,spwnpos)
	local room = Game():GetRoom() local level = Game():GetLevel() local desc = level:GetCurrentRoomDesc()
	if Unlocker.should_any_be_done("Thread","Stone",nil,"Boss_allow") -- and auxi.get_alchemy_count() >= 1 and 
	 and room:GetType() == RoomType.ROOM_BOSS and desc.SafeGridIndex > 0 and item.can_spawn() and save.elses[item.own_key.."spawn"] ~= true then
		local language = Options.Language
		local str = (item.start_str[language] or item.start_str["en"])[1][1]
		gui.general_speak(Vector(0,0),str,0,120,{R = 2,G = 0,B = 0,})
		item.set_on()
		delay_buffer.addeffe(function()
			Dialog_holder.add_word({data =(item.start_str[language] or item.start_str["en"])[2],header = {sprite_name = "Isaac"},step_by = true,}) 
		end,{},30 * 3)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
Function = function(_)
	item.set_off()
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	if item.should_spawn() then
		item.generate_chess_broad()
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local room = Game():GetRoom()
	local level = Game():GetLevel()
	local desc = level:GetCurrentRoomDesc()
	local stageType = level:GetStageType()
	if save.UnlockData.Others.Ending1.Unlock == true then
		if stageType >= StageType.STAGETYPE_REPENTANCE and Game():GetLevel():GetCurrentRoomDesc().SafeGridIndex == -11 and desc.Data.Variant == 1000 and room:IsFirstVisit() then
			local n_ent = Isaac.GetRoomEntities()
			local keys = auxi.getothers(n_ent,5,30,1)
			if #keys > 0 then
				local targ = keys[1]:ToPickup()
				targ:Morph(5,100,enums.Items.A_Shard_Of_Rock,false,false,true)
			else end	--local q = Isaac.Spawn(5,100,enums.Items.A_Shard_Of_Rock,room:GetRandomPosition(0),Vector(0,0),nil):ToPickup() auxi.self_morph(q) end
		end
	end
end,
})

return item
