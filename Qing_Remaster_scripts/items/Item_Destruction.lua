local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local card_04_Emperor = require("Qing_Remaster_scripts.cards.Card_04_Emperor")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Destruction,
	own_key = "Item_Destruction",
	Ignore_room = {
		[RoomType.ROOM_DEFAULT] = true,
		[RoomType.ROOM_BOSS] = true,
		[RoomType.ROOM_MINIBOSS] = true,
	},
}

function item.random_red_room()
	return auxi.choose(0,1,2,3,4,5,6,7,8)
end

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	if save.elses[item.own_key.."effect"] then
		local level = Game():GetLevel()
		local desc = level:GetCurrentRoomDesc()
		if auxi.GetDimension() == 0 and save.elses[item.own_key.."effect"][desc.SafeGridIndex] then
			local info = save.elses[item.own_key.."effect"][desc.SafeGridIndex]
			if info.T == false then
				local succ = false
				for i = 0,3 do
					local idx = auxi.move_in_gridroom(desc.SafeGridIndex,i)
					local d2 = level:GetRoomByIdx(idx)
					if d2 and d2.Data and d2.Flags & (1<<10) == (1<<10) then succ = true break end
				end
				if not succ and info.from then 
					level:MakeRedRoomDoor(desc.SafeGridIndex,auxi.move2dir(info.from - desc.SafeGridIndex))
					save.elses[item.own_key.."effect"][desc.SafeGridIndex] = nil
				end
				if Game():GetRoom():IsFirstVisit() then local q = Isaac.Spawn(5,300,78,Game():GetRoom():FindFreePickupSpawnPosition(Game():GetPlayer(0).Position,10,true),Vector(0,0),Game():GetPlayer(0)):ToPickup() end
			end
		end
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,priority = 100,
Function = function(_)
	local player = auxi.have_player_has_collectible(item.entity)
	local muls = auxi.get_player_have_trinket_num(enums.Trinkets.Torn_Moon_) 
	if player or muls > 0 then
		player = player or auxi.have_player_has_trinket(enums.Trinkets.Torn_Moon_) or Game():GetPlayer(0)
		local room = Game():GetRoom()
		local cnt = auxi.get_player_have_collectible_num(item.entity)
		if cnt > 0 then for i = 1,cnt + 2 do local q = Isaac.Spawn(5,300,78,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup() end end
		local rng = player:GetCollectibleRNG(item.entity)
		local tbl = {}
		local sel = {}
		local Masker = nil
		local UltraSecret = nil
		local level = Game():GetLevel()
		local rooms = level:GetRooms()
		local dimen = auxi.GetDimension()
		for i = 1, rooms.Size do
			local tgroom = rooms:Get(i - 1)
			if tgroom and tgroom.Data and auxi.GetDimension(tgroom) == dimen then
				local tret = {val = 1,}
				if tgroom.Data.Shape == 1 and tgroom.Data.Doors & 15 == 15 then
					if not item.Ignore_room[tgroom.Data.Type] then tret.Sel = 1
					elseif tgroom.Data.Type == 1 then Masker = level:GetRoomByIdx(tgroom.SafeGridIndex).Data end
					if tgroom.Data.Type == 29 then UltraSecret = level:GetRoomByIdx(tgroom.SafeGridIndex) end
				end
				if tgroom.Data.Type == RoomType.ROOM_BOSS then tret.Boss = true end
				local sgids = auxi.get_all_gridindexs(tgroom)
				for u,v in pairs(sgids) do tbl[v] = auxi.copy(tret) end
			end
		end
		local tb = {level:GetCurrentRoomDesc().SafeGridIndex,}
		while(#tb > 0) do
			local ret = tb[1]
			tbl[ret].val = 2
			for i = 0,3 do 
				local idx = auxi.move_in_gridroom(ret,i)
				if tbl[idx] and (tbl[idx].val or 0) == 1 then 
					table.insert(tb,#tb + 1,idx) 
					tbl[idx].val = 2 
					if tbl[idx].Sel then table.insert(sel,#sel + 1,idx) end
				end
			end
			table.remove(tb,1)
		end
		local dmap = {}
		local dstack = {}
		for u,v in pairs(tbl) do 
			if v.val == 2 then 
				table.insert(dstack,#dstack + 1,{id = u,val = 3,})
				dmap[u] = {val = 3,boss = v.Boss,}
			end
		end
		while(#dstack > 0) do
			local ret = dstack[1]
			if ret.val == ((dmap[ret.id] or {}).val or 0) then
				for i = 0,3 do 
					local idx = auxi.move_in_gridroom(ret.id,i)
					local safe = auxi.is_safe_move_in_gridroom(ret.id,idx)
					if idx ~= ret.id then
						if ((dmap[idx] or {}).val or 0) < dmap[ret.id].val - 1 and safe then 
							table.insert(dstack,#dstack + 1,{id = idx,val = dmap[ret.id].val - 1})
							dmap[idx] = dmap[idx] or {}
							dmap[idx].val = dmap[ret.id].val - 1
							dmap[idx].from = ret.id
							if dmap[ret.id].boss then dmap[idx].boss = true end
						elseif not safe then
							dmap[idx] = dmap[idx] or {val = dmap[ret.id].val - 1,}
							if dmap[ret.id].val == 3 and dmap[idx].val ~= 3 then dmap[idx].boss = true end
						elseif (dmap[idx] and (dmap[idx].val or 0) == dmap[ret.id].val - 1) then
							if dmap[ret.id].boss and dmap[ret.id].val == 3 then dmap[idx].boss = true end
							if dmap[ret.id].val == 2 and dmap[idx].boss and not dmap[ret.id].boss then 
								dmap[idx].boss = nil 
								dmap[idx].from = ret.id
							end
						end
					end
				end
			end
			table.remove(dstack,1)
		end
		local selected = {}
		for u,v in pairs(dmap) do 
			if v.val == 1 and v.boss ~= true and ((tbl[u] or {}).val or 0) ~= 1 then
				table.insert(selected,#selected + 1,u)
			end
		end
		save.elses[item.own_key.."effect"] = {}
		selected = auxi.randomOverTable(selected,rng)
		sel = auxi.randomOverTable(sel,rng)
		local mx = math.min(cnt + 3,math.min(#selected,#sel))	
		if cnt > 0 then 
			for i = 1,mx do
				local succ = auxi.make_red_room(selected[i])
				if not succ then 
				else
					local desc = level:GetRoomByIdx(selected[i])
					if desc and desc.Data then
						if desc.Data.Type ~= 1 and Masker then desc.Data = Masker end
						local desc2 = level:GetRoomByIdx(sel[i])
						local Ddata = desc2.Data 
						desc2.Data = desc.Data
						local smb = desc.SurpriseMiniboss
						desc.SurpriseMiniboss = desc2.SurpriseMiniboss
						desc2.SurpriseMiniboss = smb
						desc.Data = Ddata
						desc.Flags = desc.Flags & ~(1<<10) 
						if desc2.DisplayFlags == 4 then desc2.DisplayFlags = 5 end
						save.elses[item.own_key.."effect"][sel[i]] = {id = selected[i],T = true,}
						save.elses[item.own_key.."effect"][selected[i]] = {id = sel[i],T = false,from = dmap[selected[i]].from,}
					end
				end
			end
		end
		--for u,v in pairs(selected) do auxi.make_red_room(v) end
		local t1 = level:GetCurrentRoomDesc().Data.Type
		for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
			local door = room:GetDoor(slot)
			if door then
				local d2 = level:GetRoomByIdx(door.TargetRoomIndex)
				if d2 and d2.Data then 
					if save.elses[item.own_key.."effect"][d2.SafeGridIndex] then 
						door:SetRoomTypes(t1,d2.Data.Type) 
						door:SetLocked(false)
						door:Open()
					end
				end
			end
		end
		for i = 1,muls do
			if i + mx <= #selected and UltraSecret then
				local succ = auxi.make_red_room(selected[i + mx])
				if not succ then 
				else
					local desc = level:GetRoomByIdx(selected[i + mx])
					if desc and desc.Data then
						desc.Data = UltraSecret.Data
						desc.Flags = desc.Flags & ~(1<<10) 
						desc.DisplayFlags = UltraSecret.DisplayFlags
						Room_holder.Try_replace_with(desc.SafeGridIndex,auxi.GetDimension(),{data = function() Isaac.ExecuteCommand("goto s.ultrasecret."..tostring(item.random_red_room())) return Game():GetLevel():GetRoomByIdx(-3).Data end,}) 
					end
				end
			else break end
		end
		level:UpdateVisibility()
	else save.elses[item.own_key.."effect"] = nil end
end,
})
--l local door = Game():GetRoom():GetDoor(3) door:Init()
--l local auxi = require("Qing_Remaster_scripts.auxiliary.functions") local level = Game():GetLevel() local rooms = level:GetRooms() local dimen = auxi.GetDimension() for i = 1, rooms.Size do local tgroom = rooms:Get(i - 1) if tgroom and tgroom.Data and auxi.GetDimension(tgroom) == dimen then print(tgroom.SafeGridIndex) end end
--l local level = Game():GetLevel() level:MakeRedRoomDoor(82, DoorSlot.LEFT0)
--l local level = Game():GetLevel() local desc = level:GetRoomByIdx(84) local desc = level:GetRoomByIdx(84) local desc2 = level:GetRoomByIdx(83) 

return item