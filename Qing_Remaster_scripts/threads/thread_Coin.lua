local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local grid_door = require("Qing_Remaster_scripts.grids.grid_doors")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local Achievement_Display_holder = require("Qing_Remaster_scripts.others.Achievement_Display_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Screen_Filter = require("Qing_Remaster_scripts.others.Screen_Filter")
local record_holder = require("Qing_Remaster_scripts.others.Record_holder")

local function change_room(room_index)
	if REPENTOGON then
		Game():ChangeRoom(room_index)
	else
		Game():GetLevel():ChangeRoom(room_index)
	end
end

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	beggar = {
		[1] = {Type = 6,Variant = 4,},
		[2] = {Type = 6,Variant = 13,},
		[3] = {Type = 6,Variant = 7,},
		[4] = {Type = 6,Variant = 5,},
		[5] = {Type = 6,Variant = 18,},
		[6] = {Type = 6,Variant = 9,},
	},
	info = {
		
	},
	offset = {
		[1] = Vector(-40,0),
		[2] = Vector(40,0),
		[3] = Vector(-40,40),
		[4] = Vector(40,40),
	},
	this_square = nil,
	own_key = "Thread_Coin",
	room_door_replacement = {
		[23503] = {Type = 9,},
		[23504] = {
			Type = 9,
			door = {
				[1] = {
					slot = 1,
					indx = nil,
					targ = "s.arcade.23509",
					doorname = "gfx/grid/door_bankdoor.anm2",
					dooranim = "Opened",
				},
			},
		},
		[23505] = {
			Type = 9,
			door = {
				[1] = {
					slot = 1,
					indx = nil,
					targ = "s.arcade.23509",
					doorname = "gfx/grid/door_bankdoor2.anm2",
					dooranim = "Opened",
					tp = 9,
					vr = 23509,
					special_reminder = function()
						local room = Game():GetRoom()
						local pos = room:GetGridPosition(145)
						for playerNum = 1, Game():GetNumPlayers() do
							local player = Game():GetPlayer(playerNum - 1)
							player.Position = pos
							player.Velocity = Vector(0,0)
						end
						return 10
					end,
				},
			},
		},
		[23506] = {
			Type = 9,
			door = {
				[1] = {
					slot = 1,
					indx = nil,
					targ = "s.arcade.23509",
					doorname = "gfx/grid/door_bankdoor2.anm2",
					dooranim = "Opened",
					tp = 9,
					vr = 23509,
					special_reminder = function()
						local room = Game():GetRoom()
						local pos = room:GetGridPosition(150)
						for playerNum = 1, Game():GetNumPlayers() do
							local player = Game():GetPlayer(playerNum - 1)
							player.Position = pos
							player.Velocity = Vector(0,0)
						end
						return 10
					end,
				},
			},
		},
		[23507] = {
			Type = 9,
			door = {
				[1] = {
					slot = 1,
					indx = nil,
					targ = "s.arcade.23509",
					doorname = "gfx/grid/door_bankdoor2.anm2",
					dooranim = "Opened",
					tp = 9,
					vr = 23509,
					special_reminder = function()
						local room = Game():GetRoom()
						local pos = room:GetGridPosition(156)
						for playerNum = 1, Game():GetNumPlayers() do
							local player = Game():GetPlayer(playerNum - 1)
							player.Position = pos
							player.Velocity = Vector(0,0)
						end
						return 10
					end,
				},
			},
		},
		[23508] = {
			Type = 9,
			door = {
				[1] = {
					slot = 1,
					indx = nil,
					targ = "s.arcade.23509",
					doorname = "gfx/grid/door_bankdoor2.anm2",
					dooranim = "Opened",
					tp = 9,
					vr = 23509,
					special_reminder = function()
						local room = Game():GetRoom()
						local pos = room:GetGridPosition(162)
						for playerNum = 1, Game():GetNumPlayers() do
							local player = Game():GetPlayer(playerNum - 1)
							player.Position = pos
							player.Velocity = Vector(0,0)
						end
						return 10
					end,
				},
			},
		},
		[23509] = {
			Type = 9,
			door = {
				[1] = {
					slot = nil,
					indx = 173,
					targ = "s.arcade.23505",
					doorname = "gfx/grid/door_bankdoor2.anm2",
					dooranim = "Opened",
					dir = 3,
				},
				[2] = {
					slot = nil,
					indx = 178,
					targ = "s.arcade.23506",
					doorname = "gfx/grid/door_bankdoor2.anm2",
					dooranim = "Opened",
					dir = 3,
				},
				[3] = {
					slot = nil,
					indx = 184,
					targ = "s.arcade.23507",
					doorname = "gfx/grid/door_bankdoor2.anm2",
					dooranim = "Opened",
					dir = 3,
				},
				[4] = {
					slot = nil,
					indx = 190,
					targ = "s.arcade.23508",
					doorname = "gfx/grid/door_bankdoor2.anm2",
					dooranim = "Opened",
					dir = 3,
				},
				[5] = {
					slot = 0,
					indx = nil,
					targ = function() 
						local level = Game():GetLevel()
						if level:GetStage() == LevelStage.STAGE7_GREED then
							change_room(45)
						else
							change_room(84)
						end
					end,
					doorname = "gfx/grid/door_bankdoor3.anm2",
					dooranim = "Opened",
					tp = nil,
					vr = nil,
					special_reminder = function()
						local room = Game():GetRoom()
						local pos = room:GetGridPosition(178)
						for playerNum = 1, Game():GetNumPlayers() do
							local player = Game():GetPlayer(playerNum - 1)
							player.Position = pos
							player.Velocity = Vector(0,0)
						end
						return 10
					end,
				},
			},
		},
		[23520] = {
			Type = 20,
			door = {
				[1] = {
					slot = 1,
					indx = nil,
					targ = function() 
						local level = Game():GetLevel()
						if level:GetStage() == LevelStage.STAGE7_GREED then
							change_room(45)
						else
							change_room(84)
						end
					end,
					doorname = "gfx/grid/door_bankdoor3.anm2",
					dooranim = "Opened",
					tp = nil,
					vr = nil,
					special_reminder = function()
						local room = Game():GetRoom()
						local pos = room:GetGridPosition(178)
						for playerNum = 1, Game():GetNumPlayers() do
							local player = Game():GetPlayer(playerNum - 1)
							player.Position = pos
							player.Velocity = Vector(0,0)
						end
						return 10
					end,
				},
			},
		},
	},
}

local function id_2_beggar(id)
	if type(id) == "string" then id = tonumber(id) end
	return item.beggar[id]
end

local rnd_square_4_tbl = {}

local function get_rnd_square_4_tbl()
	if(#rnd_square_4_tbl ~= 625) then
		for i = 1,5 do
			for j = 1,5 do
				for k = 1,5 do
					for l = 1,5 do
						table.insert(rnd_square_4_tbl,tostring(i) .. tostring(j) .. tostring(k) .. tostring(l))
					end
				end
			end
		end
	end
	return rnd_square_4_tbl
end

local function get_this_square(rng)
	local tbl = auxi.randomTable(get_rnd_square_4_tbl(), rng)
	local ret = {}
	for i = 1,23 do
		table.insert(ret,tbl[i])
	end
	table.insert(ret,"6543")
	ret = auxi.randomTable(ret, rng)
	return ret
end

local function spawn_targets(str,posidx)
	local room = Game():GetRoom()
	local pos = room:GetGridPosition(posidx)
	local q1 = Isaac.Spawn(1000,74,0,pos,Vector(0,0),nil)
	for i = 1,4 do
		local info = item.beggar[tonumber(string.sub(str,i,i))]
		local q = Isaac.Spawn(info.Type,info.Variant,0,item.offset[i] + pos,Vector(0,0),nil)
	end
	return q1
end

local function get_idx_pos(id)
	local idx = ((id - 1) % 6) + 1
	local idy = (id - idx) / 6 
	local ret = 28 * 2 + 3 + (idx - 1) * 4 + idy * 3 * 28
	if id > 12 then ret = ret + 28 * 2 end
	return ret
end

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if Game():IsGreedMode() then
		local level = Game():GetLevel()
		local desc = level:GetCurrentRoomDesc()
		if desc and desc.Data and desc.Data.Type == 9 and (desc.Data.Variant <= 23509 and desc.Data.Variant >= 23506) then
			if cacheFlag == CacheFlag.CACHE_FLYING then
				player.CanFly = false
			end
			if cacheFlag == CacheFlag.CACHE_SPEED then
				player.MoveSpeed = 1
			end
		end
	end
end,
})

local function ensure_bank_entrance()
	local level = Game():GetLevel()
	local room = Game():GetRoom()
	if level:GetStage() == LevelStage.STAGE7_GREED and room:GetType() == RoomType.ROOM_BOSS and level:GetCurrentRoomDesc().SafeGridIndex == 45 and room:IsClear() then
		save.elses.coins = true
		local slot = 6
		grid_door.try_spawn_grid_door(room,slot,nil,{check_and_leave = "s.arcade.23509",loadname = "gfx/grid/door_bankdoor.anm2",playname = "Opened",})
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, params = nil,
Function = function(_)
	ensure_bank_entrance()
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	ensure_bank_entrance()
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses.coin = false
	save.elses.coins = false
	save.elses[item.own_key.."this_square"] = nil
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local level = Game():GetLevel()
	local room = Game():GetRoom()
	local desc = level:GetCurrentRoomDesc()
	if Game():IsGreedMode() then
		local gidx = level:GetCurrentRoomDesc().SafeGridIndex
		if gidx < 0 then 
			local desc = level:GetRoomByIdx(gidx)
			if desc then desc.Flags = desc.Flags & (~ RoomDescriptor.FLAG_CURSED_MIST) end
			--l print(Game():GetLevel():GetCurrentRoomDesc().SafeGridIndex
		end
		if desc.Data.Type == 20 and desc.Data.Variant == 23520 then
			room:TurnGold()
			local desc = level:GetRoomByIdx(level:GetCurrentRoomDesc().SafeGridIndex)
			if desc then desc.Flags = desc.Flags | RoomDescriptor.FLAG_CURSED_MIST end
			local q = Isaac.Spawn(5,100,enums.Items.A_Shard_Of_Coin,Vector(320,690),Vector(0,0),nil):ToPickup()
			q:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
		end
		if desc.Data.Type == 16 and level:GetStage() == LevelStage.STAGE7_GREED then
			if save.elses.coins then
				Isaac.ExecuteCommand("goto s.arcade.23503")
				Screen_Filter.add_filter(10)
			end
		end
		local info = item.room_door_replacement[desc.Data.Variant]
		if info and info.Type == desc.Data.Type then
			for i= 0, 7 do
				if info.door_filter == nil or info.door_filter[i] == nil then 
					room:RemoveDoor(i)
				end
			end
			if info.door then
				for u,v in pairs(info.door) do
					grid_door.try_spawn_grid_door(room,v.slot,v.indx,{check_and_leave = v.targ,loadname = v.doorname,playname = v.dooranim,dir = v.dir,tp = v.tp,vr = v.vr,special_reminder = v.special_reminder})
				end
			end
		end
		if desc.Data.Type == 9 and ((desc.Data.Variant <= 23509 and desc.Data.Variant >= 23505) or desc.Data.Variant == 23502) then		--目标房间。
			room:TurnGold()
			local desc = level:GetRoomByIdx(level:GetCurrentRoomDesc().SafeGridIndex)
			if desc then desc.Flags = desc.Flags | RoomDescriptor.FLAG_CURSED_MIST end
			--l local level = Game():GetLevel() local desc = level:GetRoomByIdx(level:GetCurrentRoomDesc().SafeGridIndex) print(desc.Flags)
		end
		if desc.Data.Type == 9 and desc.Data.Variant == 23509 then
			local door = room:GetDoor(0)
			if (door) then
				local s = door:GetSprite()
				s:Load("gfx/grid/door_bankdoor3.anm2",true)
				s:Play("Opened",true)
			end
		end
		if desc.Data.Type == 9 and desc.Data.Variant == 23503 then
			local center = room:GetCenterPos()
			local posX = center.X
			local posY = center.Y
			local t_n = 1
			for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
				if room:IsDoorSlotAllowed(slot) then
					local pos = room:GetDoorSlotPosition(slot)
					if pos.Y > posY + 5 then
						t_n = 1
						posX = pos.X
						posY = pos.Y
					elseif pos.Y > posY - 5 and pos.Y < posY + 5 then
						posX = pos.X + posX
						t_n = t_n + 1
					end
				end
			end
			local pos = room:GetClampedPosition(Vector(posX,posY),10)
			for playerNum = 1, Game():GetNumPlayers() do
				local player = Game():GetPlayer(playerNum - 1)
				player.Position = pos
				player.Velocity = Vector(0,0)
				Screen_Filter.add_filter(10)
			end
			local q = Isaac.Spawn(996,enums.Enemies.Bum_Emperor,0,Vector(0,0),Vector(0,0),nil)
			for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
				local door = room:GetDoor(slot)
				if (door) then
					room:RemoveDoor(slot)
				end
			end
		end
		if desc.Data.Type == 9 and desc.Data.Variant == 23505 then
			item.this_square = save.elses[item.own_key.."this_square"]
			if item.this_square == nil then
				local rng = Game():GetPlayer(0):GetCollectibleRNG(enums.Items.A_Shard_Of_Coin)
				item.this_square = get_this_square(rng)
				save.elses[item.own_key.."this_square"] = item.this_square
			end
			for i = 1,24 do
				local posid = get_idx_pos(i)
				local q = spawn_targets(item.this_square[i],posid)
			end
		end
	else
		if desc.Data.Type == 9 and desc.Data.Variant == 23800 then
			local pos = room:GetGridPosition(82)
			for playerNum = 1, Game():GetNumPlayers() do
				local player = Game():GetPlayer(playerNum - 1)
				player.Position = pos
				player.Velocity = Vector(0,0)
				Screen_Filter.add_filter(10)
			end
			local q = Isaac.Spawn(996,enums.Enemies.Bum_Emperor,0,Vector(0,0),Vector(0,0),nil)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	local level = Game():GetLevel()
	local room = Game():GetRoom()
	local desc = level:GetCurrentRoomDesc()
	if Game():IsGreedMode() then
		if desc.Data.Type == 9 and (desc.Data.Variant <= 23508 and desc.Data.Variant >= 23506) then		--目标房间。
			local n_entity = Isaac.GetRoomEntities()
			if item.coin_counter == nil then item.coin_counter = 0 end
			item.coin_counter = item.coin_counter + 3
			local count = math.sin(math.rad(item.coin_counter - 90)) * 0.5 + 0.5
			for u,v in pairs(n_entity) do
				if v.Type ~= 1 and v.Type ~= 996 then
					if v.Type == 7 then
						if v.Parent and v.Parent.Type <= 10 then
						else
							v:GetSprite().Color = Color(1,1,1,1,1,0.84,0)
						end
					else
						local s = v:GetSprite()
						s.Color = auxi.AddColor(s.Color,Color(1,1,1,1,1 * count,0.84 * count,0),0.95,0.05)
					end
				end
			end
		end
		if desc.Data.Type == 9 and desc.Data.Variant == 23505 then
			
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = enums.Items.A_Shard_Of_Coin,
Function = function(_,player,collid,count,touched,curnum,real)
	if real == false and Game():IsGreedMode() == false then
		Isaac.ExecuteCommand("goto s.arcade.23800")
		player:PlayExtraAnimation("DeathTeleport")
		Game():StartRoomTransition(-3, Direction.NO_DIRECTION, RoomTransitionAnim.PIXELATION, player)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses.coin = false
		save.elses.coins = false
		save.elses[item.own_key.."this_square"] = nil
		item.this_square = nil
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if save.UnlockData.Others.Coin.Unlock ~= true then
		save.UnlockData.Others.Coin.Unlock = false
	else
		local targs = Isaac.FindByType(EntityType.ENTITY_SLOT, 8)
		for _,targ in pairs(targs) do
			local s = targ:GetSprite()
			if (s:IsPlaying("Death") or s:IsPlaying("Broken") or s:IsFinished("Death") or s:IsFinished("Broken")) then
				local q1 = Isaac.Spawn(5,100,enums.Items.A_Shard_Of_Coin,targ.Position,targ.Velocity,nil):ToPickup()
				q1:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
				local s1 = q1:GetSprite()
				local d1 = q1:GetData()
				consistance_holder.try_hold_entity(q1,item.own_key,{ignore_subtype = true})
				item.hold_by_record(q1)
				s1:ReplaceSpritesheet(5,"gfx/items/to_item_altar.png")
				s1:LoadGraphics()
				s1:SetOverlayFrame("Alternates", 1)
				Game():Darken(1,60)
				Game():ShakeScreen(30)
				targ:Remove()
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	local level = Game():GetLevel()
	local room = Game():GetRoom()
	local desc = level:GetCurrentRoomDesc()
	if desc.Data.Type == 20 and desc.Data.Variant == 23502 then		--目标房间。
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			if (not player:IsItemQueueEmpty()) then
				local item = player.QueuedItem
				if item.Touched == false and item.Item.Type == ItemType.ITEM_PASSIVE and item.Item.ID == enums.Items.A_Shard_Of_Coin then
					if save.UnlockData.Others.Coin.Unlock ~= true then
						Achievement_Display_holder.PlayAchievement("gfx/ui/Some achievements/achievement_Coin_Shard.png")
					end
					save.UnlockData.Others.Coin.Unlock = true
				end
			end
		end
	end
end,
})

function item.hold_by_record(ent)
	local seed = ent.InitSeed
	record_holder.try_hold(ent,{check = function(et) 
		if et.InitSeed ~= seed then return true,"Turn" end
		return false,nil
	end,Function = function(tp,et)
		if tp == "Turn" and auxi.check_all_exists(et) then
			consistance_holder.try_hold_entity(et,item.own_key,{ignore_subtype = true})
			local s = et:GetSprite()
			s:ReplaceSpritesheet(5,"gfx/items/to_item_altar.png")
			s:LoadGraphics()
			s:SetOverlayFrame("Alternates", 1)
		end
	end,})
end
--l local ent = Isaac.Spawn(5,100,1,Vector(200,200),Vector(0,0),nil) local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder") consistance_holder.try_hold_entity(ent,"Thread_Coin",{ignore_subtype = true}) local s = ent:GetSprite() s:ReplaceSpritesheet(5,"gfx/items/to_item_altar.png") s:LoadGraphics() s:SetOverlayFrame("Alternates", 1)
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = 100,
Function = function(_,ent)
	if ent.Type == 5 and ent.Variant == 100 then
		if consistance_holder.try_check_entity(ent,item.own_key) then
			item.hold_by_record(ent)
			local d = ent:GetData()
			local s = ent:GetSprite()
			s:ReplaceSpritesheet(5,"gfx/items/to_item_altar.png")
			s:LoadGraphics()
			s:SetOverlayFrame("Alternates", 1)
		end
	end
end,
})

return item
