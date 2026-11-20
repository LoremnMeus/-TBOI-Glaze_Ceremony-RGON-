-- 隐藏房间托管。按「维度:格子」记住需要离开地图的房间。
-- hide：常态不画在小地图上。hide_map：人在这间房里时加上迷失诅咒，离开后撤掉。
local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Hidden_room_holder_",
}

local LOST_CURSE = LevelCurse.CURSE_OF_THE_LOST
local RED_ROOM_FLAG = 1 << 10

local function get_book()
	local book = save.elses[item.own_key]
	if type(book) ~= "table" then
		book = {}
		save.elses[item.own_key] = book
	end
	if type(book.rooms) ~= "table" then
		book.rooms = {}
	end
	return book
end

local function room_key(index, dimension)
	return tostring(dimension or 0) .. ":" .. tostring(index)
end

function item.keep(index, dimension, opts)
	index = tonumber(index)
	if not index then
		return
	end
	dimension = tonumber(dimension) or 0
	opts = opts or {}
	local book = get_book()
	local key = room_key(index, dimension)
	local row = book.rooms[key]
	if type(row) ~= "table" then
		row = {}
	end
	row.index = index
	row.dimension = dimension
	row.hide = opts.hide ~= false
	row.hide_map = opts.hide_map == true
	if opts.owner ~= nil then
		row.owner = opts.owner
	end
	book.rooms[key] = row
end

function item.release(index, dimension)
	index = tonumber(index)
	if not index then
		return
	end
	local book = save.elses[item.own_key]
	if type(book) ~= "table" or type(book.rooms) ~= "table" then
		return
	end
	book.rooms[room_key(index, tonumber(dimension) or 0)] = nil
end

function item.release_owner(owner)
	local book = save.elses[item.own_key]
	if type(book) ~= "table" or type(book.rooms) ~= "table" then
		return
	end
	for key, row in pairs(book.rooms) do
		if type(row) == "table" and row.owner == owner then
			book.rooms[key] = nil
		end
	end
end

function item.note_map_curse(owned)
	local book = get_book()
	book.lost_curse = owned == true or nil
end

local function current_row()
	local book = save.elses[item.own_key]
	if type(book) ~= "table" or type(book.rooms) ~= "table" then
		return nil
	end
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if not desc then
		return nil
	end
	return book.rooms[room_key(desc.SafeGridIndex, auxi.GetDimension() or 0)]
end

local function clear_hidden()
	local book = save.elses[item.own_key]
	if type(book) ~= "table" or type(book.rooms) ~= "table" then
		return
	end
	local level = Game():GetLevel()
	for _, row in pairs(book.rooms) do
		if type(row) == "table" and row.hide ~= false and row.index ~= nil then
			local desc = level:GetRoomByIdx(row.index, row.dimension or 0)
			if desc then
				desc.DisplayFlags = 0
				desc.VisitedCount = 0
				if desc.Flags then
					desc.Flags = desc.Flags & ~RED_ROOM_FLAG
				end
			end
		end
	end
end

local function sync_map_curse()
	local book = save.elses[item.own_key]
	if type(book) ~= "table" then
		return
	end
	local level = Game():GetLevel()
	local curse = level:GetCurses()
	local has_lost = curse & LOST_CURSE == LOST_CURSE
	local row = current_row()
	if row and row.hide_map == true then
		if not has_lost then
			level:AddCurse(LOST_CURSE, false)
			book.lost_curse = true
		end
	elseif book.lost_curse then
		level:RemoveCurses(LOST_CURSE)
		book.lost_curse = nil
	end
end

local function hidden_dirty()
	local book = save.elses[item.own_key]
	if type(book) ~= "table" or type(book.rooms) ~= "table" then
		return false
	end
	local level = Game():GetLevel()
	for _, row in pairs(book.rooms) do
		if type(row) == "table" and row.hide ~= false and row.index ~= nil then
			local desc = level:GetRoomByIdx(row.index, row.dimension or 0)
			if desc and (desc.DisplayFlags ~= 0 or desc.VisitedCount ~= 0) then
				return true
			end
			if desc and desc.Flags and (desc.Flags & RED_ROOM_FLAG) ~= 0 then
				return true
			end
		end
	end
	return false
end

function item.refresh(force)
	if not g.is_gameplay_world_active() then
		return
	end
	if force == nil then
		force = true
	end
	local book = save.elses[item.own_key]
	local any = type(book) == "table" and type(book.rooms) == "table"
	if any then
		any = false
		for _, row in pairs(book.rooms) do
			if type(row) == "table" then
				any = true
				break
			end
		end
	end
	if any and (force or hidden_dirty()) then
		clear_hidden()
		local ok = pcall(function()
			Game():GetLevel():UpdateVisibility()
		end)
		if ok then
			clear_hidden()
		end
		if REPENTOGON and Minimap and Minimap.Refresh then
			pcall(function()
				Minimap.Refresh()
			end)
		end
	end
	sync_map_curse()
end

local function drop_floor()
	local book = save.elses[item.own_key]
	if type(book) == "table" and book.lost_curse and g.is_gameplay_world_active() then
		pcall(function()
			Game():GetLevel():RemoveCurses(LOST_CURSE)
		end)
	end
	save.elses[item.own_key] = nil
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		item.refresh()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	params = nil,
	Function = function()
		item.refresh()
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_LEVEL,
	params = nil,
	Function = function()
		drop_floor()
	end,
})

return item
