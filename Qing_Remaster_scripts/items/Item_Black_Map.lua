local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Black_Map,
	own_key = "Item_black_map",
	compass = {
		[RoomType.ROOM_SHOP] = true,
		[RoomType.ROOM_TREASURE] = true,
		[RoomType.ROOM_BOSS] = true,
		[RoomType.ROOM_MINIBOSS] = true,
		[RoomType.ROOM_ARCADE] = true,
		[RoomType.ROOM_CURSE] = true,
		[RoomType.ROOM_CHALLENGE] = true,
		[RoomType.ROOM_LIBRARY] = true,
		[RoomType.ROOM_SACRIFICE] = true,
		[RoomType.ROOM_DEVIL] = true,
		[RoomType.ROOM_ANGEL] = true,
		[RoomType.ROOM_ISAACS] = true,
		[RoomType.ROOM_BARREN] = true,
		[RoomType.ROOM_CHEST] = true,
		[RoomType.ROOM_DICE] = true,
		[RoomType.ROOM_GREED_EXIT] = true,
		[RoomType.ROOM_PLANETARIUM] = true,
	},
	bluemap = {
		[RoomType.ROOM_ERROR] = true,
		[RoomType.ROOM_SECRET] = true,
		[RoomType.ROOM_SUPERSECRET] = true,
	},
	map = {
		[RoomType.ROOM_DEFAULT] = true,
	},
	description = {
		zh_cn = {
			[21] = {desc = "特殊房间不再消失",},
			[54] = {desc = "普通房间不再消失",},
			[246] = {desc = "隐藏房间不再消失",},
			[333] = {desc = "距离2以上的房间不再消失",},
		},
		en_us = {
			[21] = {desc = "Special rooms won't disappear in map",},
			[54] = {desc = "Normal rooms won't disappear in map",},
			[246] = {desc = "Secret rooms won't disappear in map",},
			[333] = {desc = "All rooms will no longer disappear in map",},
		},
	},
}
auxi.add_EID_item_synic(item.entity,item.description,true)

function item.clear_flag(desc)
	local level = Game():GetLevel()
	if level:GetStateFlag(LevelStateFlag.STATE_FULL_MAP_EFFECT) then return 7 end
	if desc.Data and item.compass[desc.Data.Type] and level:GetStateFlag(LevelStateFlag.STATE_COMPASS_EFFECT) then return 7 end
	if desc.Data and item.bluemap[desc.Data.Type] and level:GetStateFlag(LevelStateFlag.STATE_BLUE_MAP_EFFECT) then return 7 end
	if desc.Data and item.map[desc.Data.Type] and level:GetStateFlag(LevelStateFlag.STATE_MAP_EFFECT) then return 7 end
	return 0
end

function item.update_black_map()
	local level = Game():GetLevel()
	local rooms = level:GetRooms()
	local current_desc = level:GetCurrentRoomDesc()
	save.elses[item.own_key] = save.elses[item.own_key] or {}
	local room_states = save.elses[item.own_key]
	local changed = false
	if current_desc.ListIndex and room_states[current_desc.ListIndex] ~= 2 then
		room_states[current_desc.ListIndex] = 2
		changed = true
	end

	for i = 0, rooms.Size - 1 do
		local targ = rooms:Get(i)
		if targ ~= nil and targ.SafeGridIndex >= 0 and targ.ListIndex >= 0 then
			if room_states[targ.ListIndex] == nil then
				room_states[targ.ListIndex] = 0
			end
			if room_states[targ.ListIndex] == 0 then
				local desc = level:GetRoomByIdx(targ.SafeGridIndex)
				if desc ~= nil and desc.SafeGridIndex >= 0 and desc.ListIndex == targ.ListIndex and desc.DisplayFlags ~= 5 then
					desc.DisplayFlags = 5
					changed = true
				end
				room_states[targ.ListIndex] = 1
			end
		end
	end

	local function hide_visited_rooms()
		local hidden_changed = false
		for i = 0, rooms.Size - 1 do
			local targ = rooms:Get(i)
			if targ ~= nil and targ.SafeGridIndex >= 0 and targ.ListIndex >= 0 and room_states[targ.ListIndex] == 2 then
				local desc = level:GetRoomByIdx(targ.SafeGridIndex)
				if desc ~= nil and desc.SafeGridIndex >= 0 and desc.ListIndex == targ.ListIndex then
					local target_flags = desc.DisplayFlags & item.clear_flag(desc)
					if desc.DisplayFlags ~= target_flags then
						desc.DisplayFlags = target_flags
						hidden_changed = true
					end
				end
			end
		end
		return hidden_changed
	end

	if hide_visited_rooms() then changed = true end
	if changed then
		level:UpdateVisibility()
		-- UpdateVisibility restores normal adjacent-room visibility, so clear
		-- visited rooms again after the engine has rebuilt the minimap state.
		hide_visited_rooms()
		if REPENTOGON and Minimap and Minimap.Refresh then
			Minimap.Refresh()
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if auxi.have_player_has_collectible(item.entity) then
		item.update_black_map()
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key] = {}
	end
	save.elses[item.own_key] = save.elses[item.own_key] or {}
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[item.own_key] = {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	if auxi.have_player_has_collectible(item.entity) then
		item.update_black_map()
	end
end,
})

return item
