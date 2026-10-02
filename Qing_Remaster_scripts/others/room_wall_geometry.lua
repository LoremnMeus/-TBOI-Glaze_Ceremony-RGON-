-- Room boundary wall geometry (not obstacle/rock collision).
-- Algorithm adapted from the verified wall-scan pattern in Card_21r_Profound.lua:
-- GRID_WALL whose grid position is outside IsPositionInRoom(..., 0), then find
-- cardinal neighbors that lie inside the room. That handles L-rooms and non-rect shapes.
--
-- This module only serves Game():GetRoom() (current room). Do not pass other Room objects.
--
-- TODO: Card_21r_Profound wall-door candidate discovery can later reuse this module.
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local WallGeometry = {}

local cache = {
	key = nil,
	interfaces = nil,
}

local function current_room_key(room)
	room = room or Game():GetRoom()
	local level = Game():GetLevel()
	local desc = level:GetCurrentRoomDesc()
	local dim = auxi.GetDimension(desc)
	if dim == nil then dim = 0 end
	local shape = (room.GetRoomShape and room:GetRoomShape()) or 0
	local deco = (room.GetDecorationSeed and room:GetDecorationSeed()) or 0
	local list_index = desc.ListIndex
	if list_index == nil then list_index = -1 end
	return table.concat({
		tostring(desc.SafeGridIndex),
		tostring(dim),
		tostring(list_index),
		tostring(shape),
		tostring(deco),
	}, ":")
end

function WallGeometry.invalidate()
	cache.key = nil
	cache.interfaces = nil
end

--- Returns wall-to-interior interface records for the current room.
--- Each entry: wall_index, wall_pos, inner_index, inner_pos, inward, outward
function WallGeometry.get_wall_interfaces()
	local room = Game():GetRoom()
	local key = current_room_key(room)
	if cache.key == key and cache.interfaces then
		return cache.interfaces
	end

	local result = {}
	local size = room:GetGridSize()
	for i = 0, size - 1 do
		local grid = room:GetGridEntity(i)
		if grid and grid:GetType() == GridEntityType.GRID_WALL then
			local wall_pos = room:GetGridPosition(i)
			if room:IsPositionInRoom(wall_pos, 0) == false then
				for _, inner_index in ipairs(auxi.get_cardinal_grid_neighbor_indexes(room, i)) do
					if inner_index >= 0 and inner_index < size then
						local inner_pos = room:GetGridPosition(inner_index)
						if room:IsPositionInRoom(inner_pos, 0) then
							local delta = inner_pos - wall_pos
							local len = delta:Length()
							if len > 0.001 then
								local inward = delta / len
								result[#result + 1] = {
									wall_index = i,
									wall_pos = Vector(wall_pos.X, wall_pos.Y),
									inner_index = inner_index,
									inner_pos = Vector(inner_pos.X, inner_pos.Y),
									inward = inward,
									outward = -inward,
								}
							end
						end
					end
				end
			end
		end
	end

	cache.key = key
	cache.interfaces = result
	return result
end

--- Nearest room-boundary wall from pos (current room only).
--- opts.inset (default 10): target sits inward from wall_pos along inward normal.
--- Returns nil if no interfaces exist.
function WallGeometry.get_nearest_wall(pos, opts)
	opts = opts or {}
	local inset = tonumber(opts.inset)
	if inset == nil then inset = 10 end

	local interfaces = WallGeometry.get_wall_interfaces()
	local best = nil
	local best_dist = nil
	for _, wall in ipairs(interfaces) do
		local target = wall.wall_pos + wall.inward * inset
		local dist = (target - pos):Length()
		if not best_dist or dist < best_dist then
			best_dist = dist
			best = {
				wall_index = wall.wall_index,
				wall_pos = wall.wall_pos,
				inner_index = wall.inner_index,
				inner_pos = wall.inner_pos,
				inward = wall.inward,
				outward = wall.outward,
				target_pos = target,
				distance = dist,
			}
		end
	end
	return best
end

return WallGeometry
