-- Route queries over planned Stone path (existing Mines rooms).

local defs = require("Qing_Remaster_scripts.threads.stone.stone_defs")
local runtime = require("Qing_Remaster_scripts.threads.stone.stone_runtime")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local route = {}

local function current_sgi()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	return desc and desc.SafeGridIndex
end

function route.get_path()
	local r = runtime.get()
	return (r.route and r.route.path) or {}
end

function route.get_room_info(sgi)
	sgi = sgi or current_sgi()
	local r = runtime.get()
	if not r.route or not r.route.rooms then return nil end
	return r.route.rooms[tostring(sgi)] or r.route.rooms[sgi]
end

function route.is_route_room(desc)
	desc = desc or Game():GetLevel():GetCurrentRoomDesc()
	if not desc then return false end
	return route.get_room_info(desc.SafeGridIndex) ~= nil
end

function route.is_trigger_room(desc)
	desc = desc or Game():GetLevel():GetCurrentRoomDesc()
	local r = runtime.get()
	return r.trigger and desc and desc.SafeGridIndex == r.trigger.safe_grid_index
end

function route.is_terminal_room(desc)
	desc = desc or Game():GetLevel():GetCurrentRoomDesc()
	local r = runtime.get()
	return r.terminal and desc and desc.SafeGridIndex == r.terminal.safe_grid_index
end

function route.get_incoming_slot(desc)
	local info = route.get_room_info(desc and desc.SafeGridIndex)
	return info and info.incoming_slot
end

function route.get_outgoing_slot(desc)
	local info = route.get_room_info(desc and desc.SafeGridIndex)
	return info and info.outgoing_slot
end

function route.get_progress(desc)
	local path = route.get_path()
	if #path < 1 then return 0 end
	local sgi = desc and desc.SafeGridIndex or current_sgi()
	for i, id in ipairs(path) do
		if id == sgi then
			if #path == 1 then return 1 end
			return (i - 1) / (#path - 1)
		end
	end
	return 0
end

function route.get_current_room_route()
	return route.get_room_info(current_sgi())
end

--- Build rooms table from path + per-step door slots.
function route.build_rooms_table(path, slot_steps)
	local rooms = {}
	for i, sgi in ipairs(path) do
		local prev = path[i - 1]
		local nxt = path[i + 1]
		local key = tostring(sgi)
		rooms[key] = {
			order = i,
			prev = prev,
			next = nxt,
			incoming_slot = slot_steps and slot_steps[i] and slot_steps[i].incoming or nil,
			outgoing_slot = slot_steps and slot_steps[i] and slot_steps[i].outgoing or nil,
		}
	end
	return rooms
end

--- Resolve which DoorSlot on `from` leads to `to`.
function route.slot_between(from_sgi, to_sgi)
	local level = Game():GetLevel()
	local desc = level:GetRoomByIdx(from_sgi)
	if not desc or not desc.Data then return nil end
	local move_info = auxi.get_moves_in_gridroom(desc.Data.Shape)
	for slot, step in pairs(move_info) do
		if auxi.is_safe_move_in_grids(from_sgi, step) then
			local tdesc = level:GetRoomByIdx(from_sgi + step)
			if tdesc and tdesc.Data and tdesc.SafeGridIndex == to_sgi then
				return slot
			end
		end
	end
	return nil
end

return route
