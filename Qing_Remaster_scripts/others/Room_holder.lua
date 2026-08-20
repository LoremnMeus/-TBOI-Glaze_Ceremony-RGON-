local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Screen_Filter = require("Qing_Remaster_scripts.others.Screen_Filter")

local item = {
	ToCall = {},
	pre_myToCall = {},
	myToCall = {},
	buffer = {},
	buffer2 = {},
	own_key = "Room_holder_",
	recorder = {},
}
--已完成：将未访问过的房间替换为任意房间；将已访问过的房间替换为任意房间（稍有瑕疵）
function item.Trans_to(sgid,dir,anim,player,dim,params)
	params = params or {}
	item.pre_work()
	Game():StartRoomTransition(sgid,dir,anim,player or Game():GetPlayer(0),dim)
	for j = #item.buffer,1,-1 do 
		local v = item.buffer[j]
		if v.sgid ~= sgid then table.remove(item.buffer,j) end
	end
	if params.Record_place then
		params.Record_place = {}
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			params.Record_place[player:GetData().__Index] = player.Position
		end
	end
	table.insert(item.buffer,#item.buffer + 1,{sgid = sgid,dim = dim,params = params,})
end

function item.Replace_with(sgid,dim,params)
	params = params or {}
	local desc = params.desc or Game():GetLevel():GetRoomByIdx(sgid,dim)
	if sgid == -1 and desc.Data == nil then Game():GetLevel():InitializeDevilAngelRoom(false,false) end
	if desc then 
		desc.Data = auxi.check_if_any(params.data) or desc.Data
		if params.others then for u,v in pairs(params.others) do desc[u] = v end end
		local idix = auxi.get_acceptible_index(sgid,dim)
		save.elses[item.own_key.."Shift"] = save.elses[item.own_key.."Shift"] or {}
		if desc.VisitedCount ~= 0 then save.elses[item.own_key.."Shift"][idix] = true end
	end
end

function item.Try_replace_with(sgid,dim,params)
	table.insert(item.buffer2,#item.buffer2 + 1,{sgid = sgid,dim = dim,params = params,})
end

function item.Allocate(i)
	local level = Game():GetLevel()
	local desc = level:GetRoomByIdx(i)
	if desc and desc.Data == nil then 
		local succ = auxi.make_red_room(i)
		if succ then return i end
	end
end

function item.Allocate_with(params)
	params = params or {}
	if params.perference then local succ = item.Allocate(params.perference) if succ then return succ end end
	for i = 0,168 do
		local succ = item.Allocate(i)
		if succ then return succ end
	end
	return -1
end

--l local Room_holder = require("Qing_Remaster_scripts.others.Room_holder") Room_holder.Allocate_with()
--l local desc = Game():GetLevel():GetRoomByIdx(97) local spawndatas = desc.OverrideData.Spawns for i = 1,spawndatas.Size do local info = spawndatas:Get(i-1) local eent = info:PickEntry(0) print(eent.Type.." "..eent.Variant.." "..eent.Subtype.." "..info.X.." "..info.Y) end
--l local desc = Game():GetLevel():GetRoomByIdx(97) local desc2 = Game():GetLevel():GetRoomByIdx(84) desc.Data = desc2.Data
--l local room_holder = require("Qing_Remaster_scripts.others.Room_holder") room_holder.Replace_with(84,nil,{data = Game():GetLevel():GetRoomByIdx(-1).Data,})
--l local auxi = require("Qing_Remaster_scripts.auxiliary.functions") local save = require("Qing_Remaster_scripts.core.savedata") auxi.PrintTable(save.elses["Room_holder_".."Shift"])
function item.pre_work()
	local succ = false
	for u,v in pairs(item.buffer2 or {}) do
		item.Replace_with(v.sgid,v.dim,v.params) 
		succ = true
	end
	item.buffer2 = {}
	return succ
end

table.insert(item.pre_myToCall,#item.pre_myToCall + 1,{CallBack = enums.Callbacks.PRE_GET_TELEPORT, params = "door",priority = -1000,
Function = function(_,player,tp,data)
	local door = data.door
	local level = Game():GetLevel()
	if door and level:GetRoomByIdx(door.TargetRoomIndex) then
		local tgid = door.TargetRoomIndex
		local succ = item.pre_work()
		if succ then Game():StartRoomTransition(tgid,door.Direction,RoomTransitionAnim.WALK, player) end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local sgid = Game():GetLevel():GetCurrentRoomDesc().SafeGridIndex
	local dim = auxi.GetDimension()
	local succ2 = false
	for i = #item.buffer2,1,-1 do
		local v = item.buffer2[i]
		if sgid == v.sgid and auxi.check_equal(dim,v.dim) then 
			item.Replace_with(v.sgid,v.dim,v.params) 
			succ2 = true 
			table.remove(item.buffer2,i)
		end
	end
	if succ2 then 
		item.Trans_to(sgid,Direction.NO_DIRECTION, RoomTransitionAnim.MINECART,Game():GetPlayer(0),nil,{Record_place = true,})
		Screen_Filter.add_filter(8) 
		return
	end
	item.Room_Shifter = nil
	local idix = auxi.get_acceptible_index()
	local succ = save.elses[item.own_key.."Shift"][idix]
	save.elses[item.own_key.."Shift"][idix] = nil
	if succ then 
		Game():GetRoom():RespawnEnemies()
		item.Trans_to(Game():GetLevel():GetCurrentRoomDesc().SafeGridIndex,Direction.NO_DIRECTION, RoomTransitionAnim.MINECART,Game():GetPlayer(0),nil,{Record_place = true,})
		return
	end
	for u,v in pairs(item.buffer) do
		if sgid == v.sgid then 
			local ret = auxi.check_if_any(v.params.On_Arrive)
			if v.params.Record_place then
				for playerNum = 1, Game():GetNumPlayers() do
					local player = Game():GetPlayer(playerNum - 1)
					if v.params.Record_place[player:GetData().__Index] then player.Position = v.params.Record_place[player:GetData().__Index] end
				end
			end
		end
	end
	item.buffer = {}
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_EVERY_ENTITY_INIT, params = nil,
Function = function(_,ent)
	if item.Room_Shifter then
		--print("Find "..ent.Type.." "..ent.Variant.." "..ent.SubType)
		ent:Remove()
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_ROOM_ENTITY_SPAWN, params = nil,
Function = function(_,tp,vr,st,grididx,seed)
	--return {999,enums.Entities.Remover,0}
	local idix = auxi.get_acceptible_index()
	if save.elses[item.own_key.."Shift"] and save.elses[item.own_key.."Shift"][idix] then
		--print("Spawn "..tp.." "..vr.." "..st.." "..seed)
		local ret = nil
		if tp <= 999 then ret = {999,enums.Entities.Remover,0} end
		if item.Room_Shifter ~= true then
			item.Room_Shifter = true
			local room = Game():GetRoom()
			for i = 1,room:GetGridSize() do
				local grid = room:GetGridEntity(i)
				if grid then room:RemoveGridEntity(i,0,false) end
			end
			room:Update()
			Screen_Filter.add_filter(8)
		end
		if ret then return ret end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_INIT, params = enums.Entities.Remover,
Function = function(_,ent)
	ent:Remove()
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	item.buffer = {}
	item.buffer2 = {}
	if continue then
	else
		save.elses[item.own_key.."Shift"] = {}
	end
	save.elses[item.own_key.."Shift"] = save.elses[item.own_key.."Shift"] or {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_,shouldsave)
	item.buffer = {}
	item.buffer2 = {}
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	item.buffer = {}
	item.buffer2 = {}
	save.elses[item.own_key.."Shift"] = {}
end,
})

return item
