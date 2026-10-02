local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Boss_Glaze = require("Qing_Remaster_scripts.bosses.Boss_Glaze")
local Screen_Filter = require("Qing_Remaster_scripts.others.Screen_Filter")
local grid_trapdoor = require("Qing_Remaster_scripts.grids.grid_trapdoor")
local grid_wall = require("Qing_Remaster_scripts.grids.grid_wall")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")
local grid_door = require("Qing_Remaster_scripts.grids.grid_doors")
local End2_displayer = require("Qing_Remaster_scripts.threads.thread_End2_2")

local function chapter1_runtime_allowed()
	local ok, scope = pcall(require, "Qing_Remaster_scripts.core.release_scope")
	if not ok or not scope or not scope.allows_story_chapter then
		return true
	end
	return scope.allows_story_chapter("chapter1") == true
end

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	own_key = "Thread_End2_",
	-- Legacy physical Shard targets retired. Alchemy readiness is Story token based.
	target = {},
	Element_info = {
		[1] = {color = Color(0,0,0,0,0.3,0.1,0),vel = -1.2,sound = SoundEffect.SOUND_FLASHBACK,},
		[2] = {color = Color(0,0,0,0,1,0.85,0),vel = 1,sound = SoundEffect.SOUND_CASH_REGISTER,},
		[3] = {color = Color(0,0,0,0,0,0.4,0.6),vel = -0.75,sound = SoundEffect.SOUND_MIRROR_ENTER,},
		[4] = {color = Color(0,0,0,0,0.4,0,1),vel = -0.3,sound = SoundEffect.SOUND_BALL_AND_CHAIN_HIT,},
	},
	light_info = {
		{frame = 0,val = 0,},
		{frame = 10,val = 1,},
		{frame = 20,val = 0.1,},
		{frame = 30,val = 0,},
		total = 30,
	},
	explode_info = {
		{frame = 0,val = 0,},
		{frame = 5,val = 0,},
		{frame = 7,val = 1,},
		{frame = 10,val = 0,},
		{frame = 12,val = 0,},
		{frame = 14,val = 1,},
		{frame = 16,val = -1,},
		{frame = 17,val = -1,},
		{frame = 18,val = 1,},
		{frame = 19,val = -1,},
		{frame = 20,val = 1,},
		total = 30,
		sound = {
			[7] = 1,
			[14] = 1,
			[18] = 1,
			[20] = 1,
		},
	},
	wait_time = 5 * 30,
	realms_room = {
		[25001] = {
			init = function()
				local room = Game():GetRoom()
				local pos = room:GetGridPosition(97)
				for playerNum = 1, Game():GetNumPlayers() do
					local player = Game():GetPlayer(playerNum - 1)
					player.Position = pos + auxi.get_by_rotate(nil,playerNum/Game():GetNumPlayers() * 360,10)
					player.Velocity = Vector(0,0)
				end
				Game():GetLevel().EnterDoor = 3
			end,
			doors = {
				[1] = {
					slot = 1,
					indx = nil,
					targ = function(item) 
						return function(doorinfo,player) Room_holder.Trans_to(item.find_realms_id(2),Direction.NO_DIRECTION,RoomTransitionAnim.WALK,player) end
					end,
					doorname = "gfx/thread/End2/door.anm2",
					dooranim = "Opened",
					dir = 1,
					special_reminder = function()
						local room = Game():GetRoom()
						local pos = room:GetGridPosition(405)
						for playerNum = 1, Game():GetNumPlayers() do
							local player = Game():GetPlayer(playerNum - 1)
							player.Position = pos + auxi.get_by_rotate(nil,playerNum/Game():GetNumPlayers() * 360,10)
							player.Velocity = Vector(0,0)
						end
						return 10
					end,
				},
			},
			act = 0,
		},
		[25002] = {
			init = function()
				local room = Game():GetRoom()
				local pos = room:GetGridPosition(377)
				for playerNum = 1, Game():GetNumPlayers() do
					local player = Game():GetPlayer(playerNum - 1)
					player.Position = pos + auxi.get_by_rotate(nil,playerNum/Game():GetNumPlayers() * 360,10)
					player.Velocity = Vector(0,0)
				end
				Game():GetLevel().EnterDoor = 3
			end,
			doors = {
				[1] = {
					slot = nil,
					indx = 433,
					targ = function(item) 
						return function(doorinfo,player) Room_holder.Trans_to(item.find_realms_id(1),Direction.NO_DIRECTION,RoomTransitionAnim.WALK,player) end
					end,
					doorname = "gfx/thread/End2/door.anm2",
					dooranim = "Opened",
					dir = 3,
					special_reminder = function()
						local room = Game():GetRoom()
						local pos = room:GetGridPosition(22)
						for playerNum = 1, Game():GetNumPlayers() do
							local player = Game():GetPlayer(playerNum - 1)
							player.Position = pos + auxi.get_by_rotate(nil,playerNum/Game():GetNumPlayers() * 360,10)
							player.Velocity = Vector(0,0)
						end
						return 10
					end,
				},
				[2] = {
					slot = nil,
					indx = 13,
					targ = function(item) 
						return function(doorinfo,player) Room_holder.Trans_to(item.find_realms_id(3),Direction.NO_DIRECTION,RoomTransitionAnim.WALK,player) end
					end,
					doorname = "gfx/thread/End2/door.anm2",
					dooranim = "Opened",
					dir = 1,
					special_reminder = function()
						local room = Game():GetRoom()
						local pos = room:GetGridPosition(217)
						for playerNum = 1, Game():GetNumPlayers() do
							local player = Game():GetPlayer(playerNum - 1)
							player.Position = pos + auxi.get_by_rotate(nil,playerNum/Game():GetNumPlayers() * 360,10)
							player.Velocity = Vector(0,0)
						end
						return 10
					end,
				},
			},
			act = 1,
		},
		[25003] = {
			init = function()
				local room = Game():GetRoom()
				local pos = room:GetGridPosition(202)
				for playerNum = 1, Game():GetNumPlayers() do
					local player = Game():GetPlayer(playerNum - 1)
					player.Position = pos + auxi.get_by_rotate(nil,playerNum/Game():GetNumPlayers() * 360,10)
					player.Velocity = Vector(0,0)
				end
				Game():GetLevel().EnterDoor = 3
			end,
			doors = {
				[1] = {
					slot = 3,
					indx = nil,
					targ = function(item) 
						return function(doorinfo,player) Room_holder.Trans_to(item.find_realms_id(2),Direction.NO_DIRECTION,RoomTransitionAnim.WALK,player) end
					end,
					doorname = "gfx/thread/End2/door.anm2",
					dooranim = "Opened",
					dir = 3,
					special_reminder = function()
						local room = Game():GetRoom()
						local pos = room:GetGridPosition(41)
						for playerNum = 1, Game():GetNumPlayers() do
							local player = Game():GetPlayer(playerNum - 1)
							player.Position = pos + auxi.get_by_rotate(nil,playerNum/Game():GetNumPlayers() * 360,10)
							player.Velocity = Vector(0,0)
						end
						return 10
					end,
				},
				[2] = {
					slot = 1,
					indx = nil,
					targ = function(item) 
						return function(doorinfo,player) Room_holder.Trans_to(item.find_realms_id(4),Direction.NO_DIRECTION,RoomTransitionAnim.WALK,player) end
					end,
					doorname = "gfx/thread/End2/door.anm2",
					dooranim = "Opened",
					dir = 1,
					special_reminder = function()
						local room = Game():GetRoom()
						local pos = room:GetGridPosition(112)
						for playerNum = 1, Game():GetNumPlayers() do
							local player = Game():GetPlayer(playerNum - 1)
							player.Position = pos + auxi.get_by_rotate(nil,playerNum/Game():GetNumPlayers() * 360,10)
							player.Velocity = Vector(0,0)
						end
						return 10
					end,
				},
			},
			act = 2,
		},
		[25004] = {
			init = function()
				local room = Game():GetRoom()
				local pos = room:GetGridPosition(97)
				for playerNum = 1, Game():GetNumPlayers() do
					local player = Game():GetPlayer(playerNum - 1)
					player.Position = pos + auxi.get_by_rotate(nil,playerNum/Game():GetNumPlayers() * 360,10)
					player.Velocity = Vector(0,0)
				end
				Game():GetLevel().EnterDoor = 3
			end,
			doors = {
				[1] = {
					slot = 3,
					indx = nil,
					targ = function(item)
						return function(doorinfo,player) Room_holder.Trans_to(item.find_realms_id(3),Direction.NO_DIRECTION,RoomTransitionAnim.WALK,player) end
					end,
					doorname = "gfx/thread/End2/door.anm2",
					dooranim = "Opened",
					dir = 3,
					special_reminder = function()
						local room = Game():GetRoom()
						local pos = room:GetGridPosition(22)
						for playerNum = 1, Game():GetNumPlayers() do
							local player = Game():GetPlayer(playerNum - 1)
							player.Position = pos + auxi.get_by_rotate(nil,playerNum/Game():GetNumPlayers() * 360,10)
							player.Velocity = Vector(0,0)
						end
						return 10
					end,
				},
			},
			act = 3,
		},
	},
}
--1.收集炼金素材 token 后，生成法阵。
--2.在法阵上放上炼金道具，打开“他界“通道。
--3.开启小青 Boss 战（道中 / midboss）。
--4.真相揭露（story revelation）。
--5.开启琉璃王子 Boss 战（第一章终盘）。
--l local thread_End2 = require("Qing_Remaster_scripts.threads.thread_End2") thread_End2.goto_realms()
function item.has_alchemy()
	local ok, story_state = pcall(require, "Qing_Remaster_scripts.story.story_state")
	if ok and story_state and story_state.has_required_materials then
		return story_state.has_required_materials() == true
	end
	-- No collectible fallback: dormant Shards must not gate alchemy.
	return false
end

local function clear_stats()
	save.elses.realms_level = math.max(0,(save.elses.realms_level or 1) - 1)
end

function item.goto_realms()
	if not chapter1_runtime_allowed() then
		return false
	end
	save.elses.realms_level = 2 --if Game():GetLevel():GetStage() ~= 9 then save.elses.realms_level = save.elses.realms_level + 1 end
	local ok, story_state = pcall(require, "Qing_Remaster_scripts.story.story_state")
	if ok and story_state and story_state.on_enter_realms then
		story_state.on_enter_realms()
	end
	Game():GetLevel():SetStage(9,0)
	Isaac.ExecuteCommand("reseed")
	Screen_Filter.add_filter(30,3)
end

function item.is_realms() return (save.elses.realms_level or 0) > 0 and auxi.get_acceptible_level() == 9 end
function item.is_realms_room() 
	local desc = Game():GetLevel():GetCurrentRoomDesc() --if save.elses[item.own_key.."realms"].room[desc.ListIndex] then end
	if desc.Data and item.realms_room[desc.Data.Variant] then return true end
	return false
end

function item.find_realms_id(id)
	local level = Game():GetLevel() local rooms = level:GetRooms()
	for i = 1,rooms.Size do
		local targ = rooms:Get(i - 1) local desc = level:GetRoomByIdx(targ.SafeGridIndex)
		if desc.Data and desc.Data.Variant == 25000 + id then return targ.SafeGridIndex end
	end
end

function item.spawn_trapdoor()
	local q = grid_trapdoor.spawn_trapdoor(Game():GetRoom():GetCenterPos(),{Function = function(player)
		item.goto_realms()
	end,})
	local d2 = q:GetData() local s2 = q:GetSprite() 
	s2:Load("gfx/thread/End2/Trapdoor.anm2",true) s2:Play("Opened",true)
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if not chapter1_runtime_allowed() then
		save.elses.realms_level = 0
	end
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
		clear_stats()
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	if not chapter1_runtime_allowed() then
		save.elses.realms_level = 0
		save.elses[item.own_key.."curse"] = nil
		return
	end
	clear_stats()
	save.elses[item.own_key.."curse"] = nil
	if (save.elses.realms_level or 0) > 0 then
		delay_buffer.addeffe(function()
			local gidx = Game():GetLevel():GetCurrentRoomIndex()
			local level = Game():GetLevel()
			local rooms = level:GetRooms()
			for i = 1,rooms.Size do
				local targ = rooms:Get(i - 1)
				local desc = level:GetRoomByIdx(targ.SafeGridIndex)
				if targ.SafeGridIndex ~= 84 and desc and desc.Data then
					info = "goto s.default.25000"
					Isaac.ExecuteCommand(info)
					Room_holder.Replace_with(targ.SafeGridIndex,nil,{data = Game():GetLevel():GetRoomByIdx(-3).Data,})
					desc.DisplayFlags = 0 --desc.VisitedCount = 0
				end
			end
			local tbl = {}
			for i = 1,4 do
				tbl[i] = Room_holder.Allocate_with()
				info = "goto s.default."..tostring(25000 + i)
				Isaac.ExecuteCommand(info)
				Room_holder.Replace_with(tbl[i],nil,{data = Game():GetLevel():GetRoomByIdx(-3).Data,})
				--if tbl[i] then Room_holder.Try_replace_with(tbl[i],auxi.GetDimension(),{data = function() Isaac.ExecuteCommand("goto s.default."..tostring(25000 + i)) return Game():GetLevel():GetRoomByIdx(-3).Data end,}) end
				local desc = level:GetRoomByIdx(tbl[i]) desc.Flags = desc.Flags & ~(1<<10) 
			end
			local level = Game():GetLevel()
			local gx = tbl[1] % 13
			local gy = (tbl[1] - gx)/ 13
			local cmd = "goto "..gx.." "..gy.." 0"
			Isaac.ExecuteCommand(cmd)
			local desc = level:GetRoomByIdx(84) desc.DisplayFlags = 0 --desc.VisitedCount = 0
			item.Realms_Arrive = true
			level:UpdateVisibility()
			item_displaying_holder.check_and_description("Level","The Realms","The Realms","",Game():GetPlayer(0),false)
		end,{},1,true)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,priority = -20,
Function = function(_)
	if item.Realms_Arrive then item.Realms_Arrive = nil 
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			player.Position = Game():GetRoom():GetClampedPosition(Game():GetRoom():GetCenterPos() + Vector(0,60) + auxi.get_by_rotate(nil,playerNum/Game():GetNumPlayers() * 360,20),0)
			delay_buffer.addeffe(function()
				player:AnimateAppear()
				player:AddControlsCooldown(60)
			end,{},1)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,priority = -20,
Function = function(_)
	if not chapter1_runtime_allowed() then
		save.elses.realms_level = 0
		return
	end
	local level = Game():GetLevel()
	local curse = level:GetCurses()
	if item.is_realms() or item.is_realms_room() then
		local desc = Game():GetLevel():GetCurrentRoomDesc() 
		local info = item.realms_room[desc.Data.Variant]
		local room = Game():GetRoom()
		if info then 
			if room:IsFirstVisit() then auxi.check_if_any(info.init_) end
			auxi.check_if_any(info.init)
			for i= 0,7 do if info.door_filter == nil or info.door_filter[i] == nil then room:RemoveDoor(i) end end
			if info.doors then
				for u,v in pairs(info.doors) do
					grid_door.try_spawn_grid_door(room,v.slot,v.indx,{check_and_leave = auxi.check_if_once(v.targ,item),loadname = v.doorname,playname = v.dooranim,dir = v.dir,tp = v.tp,vr = v.vr,special_reminder = v.special_reminder,On_Arrive = v.on_arrive,})
				end
			end
		else
			local tg = item.find_realms_id(1)
			if tg then Room_holder.Trans_to(tg,Direction.NO_DIRECTION,RoomTransitionAnim.WALK,Game():GetPlayer(0)) end
		end
		if item.is_realms() and item.is_realms_room() then
			if info.act == 1 then
				End2_displayer.try_start(1)		--第一幕
			end
			if info.act == 2 then
				End2_displayer.try_start(2)		--第二幕
			end
		end
		grid_wall.ChangeRoomGfx({Backdrops = {WallVariants = {{"gfx/stage/The Realms/backdrop.png",},},FloorVariants = {{"gfx/stage/The Realms/backdrop.png",},},},})
		if curse & (1<<2) ~= (1<<2) and save.elses[item.own_key.."curse"] == nil then
			save.elses[item.own_key.."curse"] = true
			level:AddCurse(1<<2,false)
		end
		local size = room:GetGridSize()
		for i = 0,size - 1 do
			local gent = room:GetGridEntity(i)
			if gent and gent:GetType() == 1 then
				local s2 = gent:GetSprite()
				s2:ReplaceSpritesheet(0,"gfx/effects/nill.png")
				s2:LoadGraphics()
			end
		end
	else
		if save.elses[item.own_key.."curse"] then
			save.elses[item.own_key.."curse"] = nil
			level:RemoveCurses(1<<2)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local level = Game():GetLevel()
	local room = Game():GetRoom()
	if level:GetStage() == 6 and level:GetStageType() > 2 and room:IsCurrentRoomLastBoss() and room:IsClear() and (save.elses[item.own_key.."effect"].Begin_1 or item.has_alchemy()) and not level:IsPreAscent() then
		--local q = Boss_Glaze.start()
		if save.elses[item.own_key.."effect"].Begin_2 then item.spawn_trapdoor()
		else
			local q = Isaac.Spawn(1000,enums.Entities.ElementPentagram,0,room:GetCenterPos(),Vector(0,0),nil):ToEffect()
			if save.elses[item.own_key.."effect"].Begin_1 then q:GetData()[item.own_key.."Fast"] = true else save.elses[item.own_key.."effect"].Begin_1 = true end
		end
	end
	local tgs = auxi.getothers(nil,960,enums.Entities.ElementCrystal) for u,v in pairs(tgs) do v:Remove() end 
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_RENDER, params = 960,
Function = function(_,ent,offset)
	if ent.Variant == enums.Entities.ElementCrystal then
		local d = ent:GetData() local s = ent:GetSprite()
		if d[item.own_key.."effect"] then
			local s0 = d[item.own_key.."effect"].s0 if s0 == nil then s0 = Sprite() s0:Load("gfx/thread/End2/Crystal.anm2",true) s0:Play("Ball",true) s0.Color = Color(1,1,1,0) end
			local rpos = Isaac.WorldToScreen(ent.Position + ent.PositionOffset) + Vector(0,-90 + 10 * math.sin(math.rad(d[item.own_key.."effect"].counter or 0) * 3))
			s0.Rotation = (d[item.own_key.."effect"].counter or 0) * 5
			s0.Color = s.Color
			s0:Render(rpos,Vector(0,0),Vector(0,0))
			d[item.own_key.."effect"].s0 = s0
			for i = #item.target,1,-1 do
				local info = item.Element_info[i]
				local si = d[item.own_key.."effect"]["sprite_"..tostring(i)] if si == nil then si = Sprite() si:Load("gfx/thread/End2/Crystal.anm2",true) si:Play("Ele"..tostring(i),true) end
				d[item.own_key.."effect"].vel = d[item.own_key.."effect"].vel or (auxi.random_1() * 0.5 + 0.75)
				si.Rotation = s0.Rotation * info.vel * d[item.own_key.."effect"].vel 
				local col_delta = 0.65 + 0.35 * math.sin(math.rad(si.Rotation * 1.7)) 
				local basecolor = auxi.AddColor(info.color,s.Color,col_delta,col_delta)
				if save.elses[item.own_key.."effect"]["handed_"..tostring(i)] then else basecolor = Color(1,1,1,0) end
				d[item.own_key.."effect"]["Color_"..tostring(i)] = auxi.AddColor(d[item.own_key.."effect"]["Color_"..tostring(i)] or basecolor,basecolor,0.4,0.6)
				si.Color = d[item.own_key.."effect"]["Color_"..tostring(i)]
				local col_delta2 = 1 + 0.15 * math.sin(math.rad(si.Rotation * 0.44)) si.Scale = Vector(col_delta2,col_delta2)
				si:Render(rpos,Vector(0,0),Vector(0,0))
				d[item.own_key.."effect"]["sprite_"..tostring(i)] = si
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_INIT, params = 154,
Function = function(_,ent)
	if item.is_realms() then ent:Remove() end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_INIT, params = enums.Entities.ElementPentagram,
Function = function(_,ent)
	local d = ent:GetData() local s = ent:GetSprite()
	ent.DepthOffset = -200
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.ElementPentagram,
Function = function(_,ent)
	local d = ent:GetData() local s = ent:GetSprite()
	if s:IsFinished("DisAppear") then ent:Remove() return end
	if s:IsFinished("Appear") or d[item.own_key.."Fast"] then s:Play("Idle",true) d[item.own_key.."effect"] = {First = true,Fast = d[item.own_key.."Fast"],} d[item.own_key.."Fast"] = nil end
	if d[item.own_key.."effect"] then
		if auxi.check_all_exists(d[item.own_key.."effect"].Crystal) ~= true then 
			d[item.own_key.."effect"].Crystal = Isaac.Spawn(960,enums.Entities.ElementCrystal,0,ent.Position,Vector(0,0),nil):ToNPC()
			local q = d[item.own_key.."effect"].Crystal 
			q:GetData()[item.own_key.."effect"] = {linker = ent,Fast = d[item.own_key.."effect"].Fast,basecolor = Color(1,1,1,0),}
			local sq = q:GetSprite()
			if d[item.own_key.."effect"].Fast then q:GetData()[item.own_key.."effect"].basecolor = nil else sq.Color = q:GetData()[item.own_key.."effect"].basecolor end
		end
		if auxi.check_all_exists(d[item.own_key.."effect"].Player) then 
			local tg = d[item.own_key.."effect"].Player
			if (tg.Position - ent.Position):Length() > tg.Size + 120 or tg:GetData()[item.own_key.."Hand"] == nil or tg:GetData()[item.own_key.."Hand"].Fail then
				(tg:GetData()[item.own_key.."Hand"] or {}).linker = nil
				d[item.own_key.."effect"].Player = nil
			end
		else
			if auxi.inner_count(ent:GetData(),item.own_key.."Hand",{Update = true,}) then
				-- Legacy collectible Shard hand-in retired (item.target empty / dormant).
				-- Circle completion is Story-token alchemy only (materials + phase_anchor;
				-- Catalyst is prologue-owned and checked via story.has_required_materials).
				-- Never treat empty target as "all handed in".
				if item.has_alchemy() and not save.elses[item.own_key.."effect"].Begin_2 then
					save.elses[item.own_key.."effect"].Begin_2 = true
					s:Play("DisAppear",true)
					local q = d[item.own_key.."effect"].Crystal
					if q then q:GetData()[item.own_key.."explode"] = {} end
					d[item.own_key.."effect"] = nil
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	-- Legacy Shard lift/hand-in disabled while item.target is empty (dormant collectibles).
	if #item.target == 0 then
		local d = player:GetData()
		if d[item.own_key.."Hand"] then
			if d[item.own_key.."Hand"].Available and d[item.own_key.."Hand"].id then
				player:AnimateCollectible(d[item.own_key.."Hand"].id,"HideItem","PlayerPickup")
			end
			d[item.own_key.."Hand"] = nil
		end
		return
	end
	local d = player:GetData() local s = player:GetSprite()
	for i = 1,1 do if d[item.own_key.."Hand"] then
		if auxi.check_all_exists(d[item.own_key.."Hand"].linker) then else if d[item.own_key.."Hand"].Available then player:AnimateCollectible(d[item.own_key.."Hand"].id,"HideItem","PlayerPickup") end d[item.own_key.."Hand"] = nil break end
		if auxi.has_have_coll_(player,d[item.own_key.."Hand"].id) then
			if player:IsExtraAnimationFinished() then
				player:AnimateCollectible(d[item.own_key.."Hand"].id,"LiftItem","PlayerPickup")
				d[item.own_key.."Hand"].Available = true
			else end
		 else if d[item.own_key.."Hand"].Available then player:AnimateCollectible(d[item.own_key.."Hand"].id,"HideItem","PlayerPickup") end d[item.own_key.."Hand"].Available = nil d[item.own_key.."Hand"].Fail = true end
	end end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_NPC_COLLISION, params = 960,
Function = function(_,ent,col,low)
	-- No collectible hand-in while legacy Shard targets are dormant.
	if #item.target == 0 then return end
	if ent.Variant == enums.Entities.ElementCrystal and col:ToPlayer() then
		local player = col:ToPlayer()
		local d = ent:GetData() local d2 = player:GetData()
		if d2[item.own_key.."Hand"] and d2[item.own_key.."Hand"].Available then
			player:RemoveCollectible(d2[item.own_key.."Hand"].id)
			player:AnimateCollectible(d2[item.own_key.."Hand"].id,"HideItem","PlayerPickup")
			save.elses[item.own_key.."effect"]["handed_"..tostring(d2[item.own_key.."Hand"].i)] = true
			d[item.own_key.."Sprite"] = {Color = item.Element_info[d2[item.own_key.."Hand"].i].color,}
			auxi.inner_count(ent:GetData(),item.own_key.."Hand",{Set = item.wait_time,})
			sound_tracker.PlayStackedSound(item.Element_info[d2[item.own_key.."Hand"].i].sound,1,1,false,0,2)
			d2[item.own_key.."Hand"] = nil
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = 960,
Function = function(_,ent)
	if ent.Variant == enums.Entities.ElementCrystal then
		local d = ent:GetData() local s = ent:GetSprite()
		if d[item.own_key.."effect"] then
			d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) + 1
			if auxi.check_all_exists(d[item.own_key.."effect"].linker) ~= true and not d[item.own_key.."explode"] then ent:Remove() return end
			local basecolor = d[item.own_key.."effect"].basecolor or s.Color
			basecolor = auxi.AddColor(basecolor,Color(1,1,1,1),0.8,0.2)
			s.Color = basecolor
			d[item.own_key.."effect"].basecolor = basecolor
		end
		if d[item.own_key.."Sprite"] then
			d[item.own_key.."Sprite"].counter = (d[item.own_key.."Sprite"].counter or 0) + 1
			local info = auxi.check_lerp(d[item.own_key.."Sprite"].counter,item.light_info)
			s.Color = auxi.AddColor(s.Color,d[item.own_key.."Sprite"].Color,1,info.val)
			if d[item.own_key.."Sprite"].counter > item.light_info.total then d[item.own_key.."Sprite"] = nil end
		end
		if d[item.own_key.."explode"] then
			d[item.own_key.."explode"].counter = (d[item.own_key.."explode"].counter or 0) + 1
			local info = auxi.check_lerp(d[item.own_key.."explode"].counter,item.explode_info)
			s.Color = auxi.AddColor(s.Color,Color(0,0,0,0,1,1,1),1,info.val)
			if item.explode_info.sound[d[item.own_key.."explode"].counter] then 
				d[item.own_key.."explode"].scounter = (d[item.own_key.."explode"].scounter or 0) + 1
				if d[item.own_key.."explode"].scounter <= 3 then sound_tracker.PlayStackedSound(SoundEffect.SOUND_MATCHSTICK,1,0.6 + 0.2 * d[item.own_key.."explode"].scounter,false,0,2) 
				else 
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_DARK_ESAU_OPEN,1,1,false,0,2)
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_GROUND_TREMOR,1,1,false,0,2)
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_BEAST_ANGELIC_BLAST,1,1,false,0,2)
					--sound_tracker.PlayStackedSound(enums.SoundEffect.Misc_Fire,1,1,false,0,2)
				end
			end
			if d[item.own_key.."explode"].counter > item.explode_info.total then 
				local q = auxi.fire_nil(Game():GetRoom():GetCenterPos(),Vector(0,0),{cooldown = 60,})
				local d2 = q:GetData() local s2 = q:GetSprite() q.DepthOffset = 1000
				s2:Load("gfx/thread/End2/Blackout.anm2",true) s2:Play("Flash",true)
				delay_buffer.addeffe(function()
					item.spawn_trapdoor()
				end,{},5)
				d[item.own_key.."explode"] = nil ent:Remove() return 
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EXECUTE_CMD, params = nil,
Function = function(_,cmd,params)
	if string.lower(cmd) == "qing" and params ~= nil then
		local args={}
		for str in string.gmatch(params, "([^ ]+)") do
			table.insert(args, str)
		end
		if args[1] and args[2] then
			if args[1] == "goto" and args[2] == "realms" then
				if not chapter1_runtime_allowed() then
					print("Chapter 1 is not in this release scope")
					return
				end
				item.goto_realms() 
				print("Success")
			end
		end
	end
end,
})

return item
