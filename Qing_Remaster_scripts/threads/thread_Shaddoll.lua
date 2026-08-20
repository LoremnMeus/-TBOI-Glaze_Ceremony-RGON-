local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local grid_door = require("Qing_Remaster_scripts.grids.grid_doors")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local console_holder = require("Qing_Remaster_scripts.others.Console_holder")
local Screen_Filter = require("Qing_Remaster_scripts.others.Screen_Filter")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")
local grid_wall = require("Qing_Remaster_scripts.grids.grid_wall")
local thread_Zeis = require("Qing_Remaster_scripts.threads.thread_Zeis")
local Unlocker = require("Qing_Remaster_scripts.core.unlock_manager")
local player_Zeis = require("Qing_Remaster_scripts.player.player_Zeis")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	target_item = enums.Items.Reversal_Film,
	own_key = "Thread_Shadoll_",
	reload_item = {
		[GridEntityType.GRID_DECORATION] = "gfx/stage/detail/props_shadow.png",
		[GridEntityType.GRID_PIT] = "gfx/stage/detail/grid_pit_shadow.png",
		[GridEntityType.GRID_DOOR] = function(grid,item) return item.Door_info[string.lower(grid:GetSprite():GetFilename())] end,
	},
	Door_info = {
		["gfx/grid/door_01_normaldoor.anm2"] = "gfx/dolls/door/door_01_normaldoor.png",
		["gfx/grid/door_02_treasureroomdoor.anm2"] = "gfx/dolls/door/door_02_treasureroomdoor.png",
		["gfx/grid/door_00_diceroomdoor.anm2"] = "gfx/dolls/door/door_00_diceroomdoor.png",
		["gfx/grid/door_00_sacrificeroomdoor.anm2"] = "gfx/dolls/door/door_00_sacrificeroomdoor.png",
		["gfx/grid/door_00_shopdoor.anm2"] = "gfx/dolls/door/door_00_shopdoor.png",
		["gfx/grid/door_00x_planetariumdoor.anm2"] = "gfx/dolls/door/door_00x_planetariumdoor.png",
		["gfx/grid/door_02_treasureroomdoor_devil.anm2"] = "gfx/dolls/door/door_02_treasureroomdoor_devil.png",
		["gfx/grid/door_02b_chestroomdoor.anm2"] = "gfx/dolls/door/door_02b_chestroomdoor.png",
		["gfx/grid/door_03_ambushroomdoor.anm2"] = "gfx/dolls/door/door_03_ambushroomdoor.png",
		["gfx/grid/door_04_selfsacrificeroomdoor.anm2"] = "gfx/dolls/door/door_04_selfsacrificeroomdoor.png",
		["gfx/grid/door_05_arcaderoomdoor.anm2"] = "gfx/dolls/door/door_05_arcaderoomdoor.png",
		["gfx/grid/door_07_devilroomdoor.anm2"] = "gfx/dolls/door/door_07_devilroomdoor.png",
		["gfx/grid/door_07_holyroomdoor.anm2"] = "gfx/dolls/door/door_07_holyroomdoor.png",
		["gfx/grid/door_09_bossambushroomdoor.anm2"] = "gfx/dolls/door/door_09_bossambushroomdoor.png",
		["gfx/grid/door_10_bossroomdoor.anm2"] = "gfx/dolls/door/door_10_bossroomdoor.png",
		["gfx/grid/door_15_bossrushdoor.anm2"] = "gfx/dolls/door/door_15_bossrushdoor.png",
	},
	save_info = {
		"Start",
		"Start2",
		"Item",
		"Door_v1",
		"Door_v2",
	},
	room_mapper = {
		[RoomType.ROOM_DEFAULT] = "default",
		[RoomType.ROOM_SHOP] = "shop",
		[RoomType.ROOM_ERROR] = "error",
		[RoomType.ROOM_TREASURE] = "treasure",
		[RoomType.ROOM_BOSS] = "boss",
		[RoomType.ROOM_SECRET] = "secret",
		[RoomType.ROOM_SUPERSECRET] = "supersecret",
		[RoomType.ROOM_ULTRASECRET] = "ultrasecret",
	},
	room_replacer = {
		[RoomType.ROOM_DEFAULT] = {
			[RoomShape.ROOMSHAPE_1x1] = {
				Function = function(info,diff)
					return auxi.random_in_weighed_table({
						{name = "2400" .. auxi.choose(0,1,2,3,4,5,6,7),weigh = 7,},
						{name = "2402" .. auxi.choose(0,1,2,3,4,5,6,7),weigh = 7,},
						{name = "2404" .. auxi.choose(0,1,2,3,4,5,6,7),weigh = 7,},
					}).name
				end,
			},
			[RoomShape.ROOMSHAPE_IH] = {
				Function = function(info,diff)
					return auxi.random_in_weighed_table({
						{name = "2410" .. auxi.choose(0,1,2,3,4,5,6,7,8,9),weigh = 10,},
						{name = "2411" .. auxi.choose(0),weigh = 1,},
					}).name
				end,
			},
			[RoomShape.ROOMSHAPE_IV] = {
				Function = function(info,diff)
					return auxi.random_in_weighed_table({
						{name = "2412" .. auxi.choose(0,1,2,3,4,5,6,7,8,9),weigh = 10,},
						{name = "2413" .. auxi.choose(0),weigh = 1,},
					}).name
				end,
			},
			[RoomShape.ROOMSHAPE_1x2] = {
				Function = function(info,diff)
					return auxi.random_in_weighed_table({
						{name = "2414" .. auxi.choose(0,1,2,3,4,5,6,7,8,9),weigh = 10,},
						{name = "2415" .. auxi.choose(0,1,2,3),weigh = 4,},
					}).name
				end,
			},
			[RoomShape.ROOMSHAPE_IIV] = {
				Function = function(info,diff)
					return auxi.random_in_weighed_table({
						{name = "2416" .. auxi.choose(0,1,2,3,4,5,6,7,8,9),weigh = 10,},
						{name = "2417" .. auxi.choose(0),weigh = 1,},
					}).name
				end,
			},
			[RoomShape.ROOMSHAPE_2x1] = {
				Function = function(info,diff)
					return auxi.random_in_weighed_table({
						{name = "2418" .. auxi.choose(0,1,2,3,4,5,6,7,8,9),weigh = 10,},
					}).name
				end,
			},
			[RoomShape.ROOMSHAPE_IIH] = {
				Function = function(info,diff)
					return auxi.random_in_weighed_table({
						{name = "2420" .. auxi.choose(0,1,2,3,4,5,6),weigh = 7,},
					}).name
				end,
			},
			[RoomShape.ROOMSHAPE_2x2] = {
				Function = function(info,diff)
					return auxi.random_in_weighed_table({
						{name = "2422" .. auxi.choose(0),weigh = 1,},
					}).name
				end,
			},
			[RoomShape.ROOMSHAPE_LTL] = {
				Function = function(info,diff)
					return auxi.random_in_weighed_table({
						{name = "2424" .. auxi.choose(0),weigh = 1,},
					}).name
				end,
			},
			[RoomShape.ROOMSHAPE_LTR] = {
				Function = function(info,diff)
					return auxi.random_in_weighed_table({
						{name = "2426" .. auxi.choose(0),weigh = 1,},
					}).name
				end,
			},
			[RoomShape.ROOMSHAPE_LBL] = {
				Function = function(info,diff)
					return auxi.random_in_weighed_table({
						{name = "2428" .. auxi.choose(0),weigh = 1,},
					}).name
				end,
			},
			[RoomShape.ROOMSHAPE_LBR] = {
				Function = function(info,diff)
					return auxi.random_in_weighed_table({
						{name = "2430" .. auxi.choose(0),weigh = 1,},
					}).name
				end,
			},
		},
		[RoomType.ROOM_SHOP] = {
			[RoomShape.ROOMSHAPE_1x1] = {
				Function = function(info,diff)
					return auxi.random_in_weighed_table({
						{name = "2452" .. auxi.choose(0,1,2),weigh = 3,},
					}).name
				end,
			},
		},
		[RoomType.ROOM_ERROR] = {
			[RoomShape.ROOMSHAPE_1x1] = {
				Function = function(info,diff)
					return auxi.random_in_weighed_table({
						{name = "2454" .. auxi.choose(0,1),weigh = 1,},
					}).name
				end,
			},
		},
		[RoomType.ROOM_TREASURE] = {
			[RoomShape.ROOMSHAPE_1x1] = {
				Function = function(info,diff)
					return auxi.random_in_weighed_table({
						{name = "2440" .. auxi.choose(0),weigh = 1,},
					}).name
				end,
			},
		},
		[RoomType.ROOM_BOSS] = {
			[RoomShape.ROOMSHAPE_1x1] = {
				Function = function(info,diff)
					return auxi.random_in_weighed_table({
						{name = "2450" .. auxi.choose(0,1),weigh = 2,},
					}).name
				end,
			},
		},
		[RoomType.ROOM_SECRET] = {
			[RoomShape.ROOMSHAPE_1x1] = {
				Function = function(info,diff)
					return auxi.random_in_weighed_table({
						{name = "2456" .. auxi.choose(0,1),weigh = 1,},
					}).name
				end,
			},
		},
		[RoomType.ROOM_SUPERSECRET] = {
			[RoomShape.ROOMSHAPE_1x1] = {
				Function = function(info,diff)
					return auxi.random_in_weighed_table({
						{name = "2458" .. auxi.choose(0),weigh = 1,},
					}).name
				end,
			},
		},
		[RoomType.ROOM_ULTRASECRET] = {
			[RoomShape.ROOMSHAPE_1x1] = {
				Function = function(info,diff)
					return auxi.random_in_weighed_table({
						{name = "2460" .. auxi.choose(0),weigh = 1,},
					}).name
				end,
			},
		},
		[RoomType.ROOM_MINIBOSS] = {
			[RoomShape.ROOMSHAPE_1x1] = {
				Function = function(info,diff)
					return auxi.random_in_weighed_table({
						{name = "2462" .. auxi.choose(0),weigh = 1,},
					}).name
				end,
			},
		},
	},
}

local function clear_stats()
	for u,v in pairs(item.save_info) do save.elses[item.own_key..v] = nil end
	save.elses.shadoll_level = math.max(0,(save.elses.shadoll_level or 1) - 1)
end

function item.spawn_own_door_to_death(params)
	if player_Zeis.get_zeis() == nil then thread_Zeis.pre_start() end
	params = params or {}
	grid_door.try_spawn_grid_door(Game():GetRoom(),1,nil,{check_and_leave = function(doorinfo)
		local door = doorinfo.door
		local s = door:GetSprite()
		if s:IsPlaying("Opened") or s:IsFinished("Opened") then
			local player = Game():GetPlayer(0)
			player:UseActiveItem(CollectibleType.COLLECTIBLE_DEATH_CERTIFICATE,UseFlag.USE_NOANIM)
			player:StopExtraAnimation()
			Room_holder.Trans_to(80, Direction.UP, RoomTransitionAnim.WALK, player,2,{On_Arrive = function() 
				for playerNum = 1, Game():GetNumPlayers() do
					local player = Game():GetPlayer(playerNum - 1)
					player.Position = Game():GetRoom():GetGridPosition(85)
				end
			end,})
		end
	end,should_update = true,loadname = "gfx/grid/Door_Mausoleum_Alt_shaddoll.anm2",playname = params.playname or "Open",should_not_allow = params.should_not_allow or true,on_update = function(doorinfo)
		local door = doorinfo.door
		local s = door:GetSprite()
		if s:IsFinished("Open") then
			door.CollisionClass = GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER
			s:Play("Opened",true)
		end
	end,mov = 15,})
end

function item.goto_shadow()
	save.elses.shadoll_level = 2 --if Game():GetLevel():GetStage() ~= 6 then save.elses.shadoll_level = save.elses.shadoll_level + 1 end
	Game():GetLevel():SetStage(6,0)
	Isaac.ExecuteCommand("reseed")
end

function item.spawn_own_door_to_shadoll()
	local room = Game():GetRoom()
	if save.elses[item.own_key.."Door_v1"] == nil then
		grid_door.try_spawn_grid_door(room,1,nil,{check_and_leave = function(doorinfo)
			local door = doorinfo.door
			local s = door:GetSprite()
			local player = Game():GetPlayer(0)
			for i = 1,3 do
				if s:IsPlaying("Opened"..tostring(i)) or s:IsFinished("Opened"..tostring(i)) then
					if i == 1 then
						item.goto_shadow()
						return
					else
						local cmd = "goto s.angel.24901"
						if i == 3 then cmd = "goto s.devil.24900" end
						if save.elses[item.own_key.."Door_v2"] ~= true then
							Isaac.ExecuteCommand(cmd)
							Room_holder.Replace_with(-1,nil,{data = Game():GetLevel():GetRoomByIdx(-3).Data})
							save.elses[item.own_key.."Door_v2"] = true
						end
						Room_holder.Trans_to(-1,Direction.UP,RoomTransitionAnim.WALK,player,nil)
						return
					end
				end
			end
		end,should_update = true,loadname = "gfx/grid/Door_Mausoleum_Alt_shaddoll2.anm2",playname = "KeyClosed",should_not_allow = true,on_update = function(doorinfo)
			local door = doorinfo.door
			local s = door:GetSprite()
			if s:IsPlaying("KeyClosed") or s:IsFinished("KeyClosed") then
				for playerNum = 1, Game():GetNumPlayers() do
					local player = Game():GetPlayer(playerNum - 1)
					if (player.Position - door.Position):Length() <= 35 then
						if player:GetCollectibleNum(item.target_item,true) > 0 then
							player:RemoveCollectible(item.target_item)
							s:Play("Open1",true)
							save.elses[item.own_key.."Door_v1"] = 1
							sound_tracker.PlayStackedSound(52,1,1,false,0,2)
							break
						elseif player:GetCollectibleNum(CollectibleType.COLLECTIBLE_POLAROID,true) > 0 then
							player:RemoveCollectible(CollectibleType.COLLECTIBLE_POLAROID)
							s:Play("Open2",true)
							save.elses[item.own_key.."Door_v1"] = 2
							sound_tracker.PlayStackedSound(52,1,0.5,false,0,2)
							break
						elseif player:GetCollectibleNum(CollectibleType.COLLECTIBLE_NEGATIVE,true) > 0 then
							player:RemoveCollectible(CollectibleType.COLLECTIBLE_NEGATIVE)
							s:Play("Open3",true)
							save.elses[item.own_key.."Door_v1"] = 3
							sound_tracker.PlayStackedSound(52,1,1.5,false,0,2)
							break
						end
					end
				end
			end
			for i = 1,3 do
				if s:IsFinished("Open"..tostring(i)) then
					door.CollisionClass = GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER
					s:Play("Opened"..tostring(i),true)
				end
			end
		end,mov = 15,})
	else
		grid_door.try_spawn_grid_door(room,1,nil,{check_and_leave = function(doorinfo)
			local door = doorinfo.door
			local s = door:GetSprite()
			local player = Game():GetPlayer(0)
			for i = 1,3 do
				if s:IsPlaying("Opened"..tostring(i)) or s:IsFinished("Opened"..tostring(i)) then
					if i == 1 then
						item.goto_shadow()
						return
					else
						local cmd = "goto s.angel.24901"
						if i == 3 then cmd = "goto s.devil.24900" end
						if save.elses[item.own_key.."Door_v2"] ~= true then
							Isaac.ExecuteCommand(cmd)
							Room_holder.Replace_with(-1,nil,{data = Game():GetLevel():GetRoomByIdx(-3).Data})
							save.elses[item.own_key.."Door_v2"] = true
						end
						Room_holder.Trans_to(-1,Direction.UP,RoomTransitionAnim.WALK,player,nil)
						return
					end
				end
			end
		end,should_update = true,loadname = "gfx/grid/Door_Mausoleum_Alt_shaddoll2.anm2",playname = "Opened"..tostring(save.elses[item.own_key.."Door_v1"]),on_update = function(doorinfo)
			local door = doorinfo.door
			local s = door:GetSprite()
			for i = 1,3 do
				if s:IsFinished("Open"..tostring(i)) then
					door.CollisionClass = GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER
					s:Play("Opened"..tostring(i),true)
				end
			end
		end,mov = 15,})
	end
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		clear_stats()
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	clear_stats()
	if (save.elses.shadoll_level or 0) > 0 then
		delay_buffer.addeffe(function(params)
			local gidx = Game():GetLevel():GetCurrentRoomIndex()
			local level = Game():GetLevel()
			local rooms = level:GetRooms()
			for i = 1,rooms.Size do
				local targ = rooms:Get(i - 1)
				local desc = level:GetRoomByIdx(targ.SafeGridIndex)
				if targ.SafeGridIndex ~= 84 and desc and desc.Data then
					local info = auxi.check_if_any((item.room_replacer[desc.Data.Type] or {})[desc.Data.Shape],0)
					if info and item.room_mapper[desc.Data.Type] then 
						info = "goto s."..item.room_mapper[desc.Data.Type].."."..info
						Isaac.ExecuteCommand(info)
						Room_holder.Replace_with(targ.SafeGridIndex,nil,{data = Game():GetLevel():GetRoomByIdx(-3).Data,})
					end
				end
			end
			local gx = gidx % 13
			local gy = (gidx - gx)/ 13
			local cmd = "goto "..gx.." "..gy.." 0"
			Isaac.ExecuteCommand(cmd)
			level:UpdateVisibility()
			Screen_Filter.add_filter(8)
		end,{},1,true)
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_LOSE_COLLECTIBLE, params = CollectibleType.COLLECTIBLE_NEGATIVE,
Function = function(_,player,col,num,curNum)
	if Unlocker.should_any_be_done("Thread","Shadoll",nil,"Boss_allow") and 
	auxi.get_acceptible_level() == 6 and num == 1 then
		local door = Game():GetRoom():GetDoor(1)
		if door and door.TargetRoomIndex == -10 and (player.Position - door.Position):Length() <= 50 then
			local s = door:GetSprite()
			if s:GetFilename() == "gfx/grid/Door_Mausoleum_Alt.anm2" and s:IsPlaying("Open") then
				save.elses[item.own_key.."Start"] = true
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if auxi.has_have_coll(player,item.target_item) and auxi.get_acceptible_level() == 6 then
		local level = Game():GetLevel()
		local room = Game():GetRoom()
		if level:GetCurrentRoomIndex() == 84 then
			local door = room:GetDoor(1)
			if door and door.TargetRoomIndex == -10 and (player.Position - door.Position):Length() <= 35 then
				local s = door:GetSprite()
				if s:GetFilename() == "gfx/grid/Door_Mausoleum_Alt.anm2" and (s:IsPlaying("Closed") or s:IsFinished("Closed") or s:IsPlaying("KeyClosed") or s:IsFinished("KeyClosed")) then
					room:RemoveDoor(1)
					player:RemoveCollectible(item.target_item)
					save.elses[item.own_key.."Start2"] = true
					item.spawn_own_door_to_death()
					
					sound_tracker.PlayStackedSound(52,1,0.7,false,0,2)
					delay_buffer.addeffe(function(params) sound_tracker.PlayStackedSound(enums.SoundEffect.Betray,1,1,false,0,5) end,{},2)
				end
			end
		end
	end
end,
})

function item.is_shadow() return (save.elses.shadoll_level or 0) > 0 and auxi.get_acceptible_level() == 6 end

function item.reload_grids() 
	local room = Game():GetRoom()
	for i = 1,room:GetGridSize() do
		local grid = room:GetGridEntity(i)
		if grid then 
			local info = auxi.check_if_any(item.reload_item[grid:GetType()],grid,item)
			if type(info) == "string" then 
				for i = 0,4 do grid:GetSprite():ReplaceSpritesheet(i,info) end grid:GetSprite():LoadGraphics()
			end
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, params = nil,
Function = function(_,rng,pos)
	if item.is_shadow() then item.reload_grids() end
end,
})

function item.shift_room(id)
	if (id or 1) == 1 then
		grid_wall.ChangeRoomGfx({
			Backdrops = {
				WallVariants = {{"gfx/stage/backdrop/shadow_mausoleum entrance_1.png","gfx/stage/backdrop/shadow_mausoleum entrance_2.png","gfx/stage/backdrop/shadow_mausoleum entrance_3.png","gfx/stage/backdrop/shadow_mausoleum entrance_4.png",},},
				FloorVariants = {{"gfx/stage/backdrop/shadow_mausoleum entrance_1.png","gfx/stage/backdrop/shadow_mausoleum entrance_2.png","gfx/stage/backdrop/shadow_mausoleum entrance_3.png","gfx/stage/backdrop/shadow_mausoleum entrance_4.png",},},
				LFloors = {"gfx/stage/backdrop/shadow_mausoleum_lfloor.png",},
				NFloors = {"gfx/stage/backdrop/shadow_mausoleum_nfloor.png",},
				Corners = {"gfx/stage/corner/shadow_mausoleum entrance_corner.png",},
			},
		})
	else
		grid_wall.ChangeRoomGfx({
			Backdrops = {
				WallVariants = {{"gfx/stage/backdrop/dark_shadow_room.png",},},
				FloorVariants = {{"gfx/stage/backdrop/dark_shadow_room.png",},},
				LFloors = {"gfx/stage/backdrop/shadow_mausoleum_lfloor.png",},
				NFloors = {"gfx/stage/backdrop/shadow_mausoleum_nfloor.png",},
				Corners = {"gfx/stage/corner/shadow_mausoleum entrance_corner.png",},
			},
		})
	end
	item.reload_grids()
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local level = Game():GetLevel()
	local room = Game():GetRoom()
	local desc = level:GetCurrentRoomDesc()
	local player = Game():GetPlayer(0)
	
	if auxi.get_acceptible_level() == 6 then
		if item.is_shadow() then		--影子层
			if level:GetCurrentRoomIndex() == 84 and room:GetDoor(1) then
				local door = room:GetDoor(1)
				local s = door:GetSprite()
				if s:GetFilename() == "gfx/grid/Door_Mausoleum_Alt.anm2" then room:RemoveDoor(1) end
			end
			if desc.Data.Type ~= 5 then	item.shift_room(1)
			else item.shift_room(2)	end
		else
			if save.elses[item.own_key.."Start2"] then
				if level:GetCurrentRoomIndex() == 84 and auxi.GetDimension() == 0 and room:GetDoor(1) then
					local door = room:GetDoor(1)
					local s = door:GetSprite()
					if s:GetFilename() == "gfx/grid/Door_Mausoleum_Alt.anm2" and door.TargetRoomIndex == -10 then
						room:RemoveDoor(1)
						item.spawn_own_door_to_death({playname = "Opened",should_not_allow = 1,})
					end
				end
				if desc.Data.Variant == 100 and Game():GetLevel():GetCurrentRoomIndex() == 80 and auxi.GetDimension() == 2 and not thread_Zeis.has_started() then
					grid_door.try_spawn_grid_door(room,nil,100,{check_and_leave = function(doorinfo)
						Room_holder.Trans_to(84, Direction.DOWN, RoomTransitionAnim.WALK, player,0,{On_Arrive = function() 
							for playerNum = 1, Game():GetNumPlayers() do
								local player = Game():GetPlayer(playerNum - 1)
								player.Position = Game():GetRoom():GetGridPosition(22)
							end
						end,})
					end,loadname = "gfx/grid/Door_Mausoleum_Alt_shaddoll.anm2",playname = "Opened",dir = 3,})
				end
				--[[
					grid_wall.ChangeRoomGfx({
						Backdrops = {
							WallVariants = {{"gfx/stage/backdrop/shadow_closet_1.png","gfx/stage/backdrop/shadow_closet_2.png","gfx/stage/backdrop/shadow_closet_3.png","gfx/stage/backdrop/shadow_closet_4.png",},},
							FloorVariants = {{"gfx/stage/backdrop/shadow_closet_1.png","gfx/stage/backdrop/shadow_closet_2.png","gfx/stage/backdrop/shadow_closet_3.png","gfx/stage/backdrop/shadow_closet_4.png",},},
							corners = {{"gfx/stage/shadow_room.png",},},
						},
					})
				--]]
			end
			if save.elses[item.own_key.."Start"] then
				if level:GetCurrentRoomIndex() == -10 and desc.Data.Type == 27 then
					local desc = level:GetRoomByIdx(level:GetCurrentRoomDesc().SafeGridIndex)
					if desc then desc.Flags = desc.Flags | RoomDescriptor.FLAG_PITCH_BLACK end
					item.spawn_own_door_to_shadoll()
					grid_wall.ChangeRoomGfx({
						Backdrops = {
							WallVariants = {{"gfx/stage/backdrop/shadow_mausoleum entrance_1.png","gfx/stage/backdrop/shadow_mausoleum entrance_2.png","gfx/stage/backdrop/shadow_mausoleum entrance_3.png","gfx/stage/backdrop/shadow_mausoleum entrance_4.png",},},
							FloorVariants = {{"gfx/stage/backdrop/shadow_mausoleum entrance_1.png","gfx/stage/backdrop/shadow_mausoleum entrance_2.png","gfx/stage/backdrop/shadow_mausoleum entrance_3.png","gfx/stage/backdrop/shadow_mausoleum entrance_4.png",},},
							Corners = {"gfx/stage/corner/shadow_mausoleum entrance_corner.png",},
						},
					})
				end
				if desc.Data.Type == 5 and room:IsCurrentRoomLastBoss() and room:IsClear() then
					if save.elses[item.own_key.."Item"] == nil then
						local q1 = Isaac.Spawn(5,100, item.target_item, room:FindFreePickupSpawnPosition(room:GetCenterPos(),10,true), Vector.Zero, nil):ToPickup()
						q1:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
						local d1 = q1:GetData()
						save.elses[item.own_key.."Item"] = true
					end
				end
			end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = item.target_item,
Function = function(_,player,collid,count,touched)
	local level = Game():GetLevel()
	local room = Game():GetRoom()
	local desc = level:GetCurrentRoomDesc()
	if Game():IsGreedMode() == false and auxi.get_acceptible_level() == 6 and desc.Data.Type == 5 and room:IsCurrentRoomLastBoss() and room:IsClear() then
		player:PlayExtraAnimation("DeathTeleport")
		Room_holder.Trans_to(84,Direction.NO_DIRECTION,RoomTransitionAnim.PIXELATION,player,nil,{On_Arrive = function() 
			for playerNum = 1, Game():GetNumPlayers() do
				local player = Game():GetPlayer(playerNum - 1)
				player.Position = Game():GetRoom():GetCenterPos()
			end
		end,})
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EXECUTE_CMD, params = nil,
Function = function(_,cmd,params)
	if string.lower(cmd) == "meus" and params ~= nil then
		local args={}
		for str in string.gmatch(params, "([^ ]+)") do
			table.insert(args, str)
		end
		if args[1] then
			if string.lower(args[1]) == "please" then
				if args[2] and args[3] then
					if args[2] == "goto" and args[3] == "shadow" then
						item.goto_shadow() 
						print("Success")
					end
				end
			end
		end
	end
end,
})

return item