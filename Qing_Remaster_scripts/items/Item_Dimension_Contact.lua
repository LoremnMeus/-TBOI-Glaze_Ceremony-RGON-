local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local danger_data = require("Qing_Remaster_scripts.others.Danger_Data")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Dimension_Contact,
	own_key = "Item_Dimension_Contact_",
	Ignorer = {
		[19] = true,
		[62] = true,
		[239] = true,
	},
}

-- effect may be absent after Hourglass / rewind wholesale restore.
-- nil room/grid entries mean "not yet marked".
local function get_effect_state()
	local key = item.own_key .. "effect"
	if type(save.elses[key]) ~= "table" then
		save.elses[key] = {}
	end
	return save.elses[key]
end

local function get_room_effect_state(ridx)
	local root = get_effect_state()
	if type(root[ridx]) ~= "table" then
		root[ridx] = {}
	end
	return root[ridx]
end


table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = nil
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[item.own_key.."effect"] = nil
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_ROOM_ENTITY_SPAWN, params = nil,
Function = function(_,tp,vr,st,idx,seed)
	local ridx = auxi.get_acceptible_index()
	--print(ridx.." "..tp.." "..vr.." "..st.." "..idx)
	local room_effect = get_room_effect_state(ridx)
	if room_effect[idx] then return {303,enums.Enemies.RemoverToken,0} end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_INIT, params = 303,
Function = function(_,ent)
	if ent.Variant == enums.Enemies.RemoverToken then ent:Remove() end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,colid,rng,player,useFlags,activeSlot,customVarData)
	local ret = true
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local tbl = {}
		local cnt = rng:RandomInt(2) + 2
		local level = Game():GetLevel()
		local rooms = level:GetRooms()
		local desc = level:GetCurrentRoomDesc()
		local room_states = {}
		for i = 1, rooms.Size do 
			local targ = rooms:Get(i - 1) 
			if targ.VisitedCount == 0 then 
				local ridx = auxi.get_acceptible_index(targ.SafeGridIndex,auxi.GetDimension(targ))
				local room_effect = room_states[ridx]
				if not room_effect then
					room_effect = get_room_effect_state(ridx)
					room_states[ridx] = room_effect
				end
				local spawns = targ.Data.Spawns
				local sz = spawns.Size
				local width = targ.Data.Width
				for i = 1,sz do
					local entinfo = spawns:Get(i - 1):PickEntry(rng:RandomFloat())
					local idx = (spawns:Get(i - 1).X + 1) + (spawns:Get(i - 1).Y + 1) * (width + 2)
					if entinfo.Type >= 10 and entinfo.Type < 999 and not item.Ignorer[entinfo.Type] and room_effect[idx] ~= true then
						local tpinfo = {Type = entinfo.Type,Variant = entinfo.Variant,SubType = entinfo.Subtype,}
						local check_info = danger_data.check_data(tpinfo)
						if check_info and (check_info.i1 or "") == "monsters" then table.insert(tbl,#tbl + 1,{ridx = ridx,idx = idx,info = tpinfo,}) end
					end
				end
			end
		end
		if #tbl > 0 then
			local room = Game():GetRoom()
			tbl = auxi.randomTable(tbl,rng)
			cnt = math.min(cnt,#tbl)
			for i = 1,cnt do
				local tpinfo = tbl[i].info
				local marked = room_states[tbl[i].ridx]
				if not marked then
					marked = get_room_effect_state(tbl[i].ridx)
					room_states[tbl[i].ridx] = marked
				end
				marked[tbl[i].idx] = true
				--print(tbl[i].ridx.." "..tbl[i].idx)
				local pos = room:GetRandomPosition(0)
				if (pos - Game():GetPlayer(0).Position):Length() < 30 then pos = room:GetRandomPosition(0) end
				local q = Isaac.Spawn(tpinfo.Type,tpinfo.Variant,tpinfo.SubType,pos,Vector(0,0),nil):ToNPC()
				q:Morph(tpinfo.Type,tpinfo.Variant,tpinfo.SubType,-1)
				q:SetColor(Color(1,1,1,0,1,1,1),30,99,true,false)
				--local q2 = Isaac.Spawn(1000,15,0,q.Position,Vector(0,0),nil) q2:GetSprite().Color = Color(1,1,1,1,0.5,0,0)
			end
			for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
				local door = room:GetDoor(slot)
				if (door) then
					door:Close()
				end
			end
		end
	end
	return ret
end,
})

return item