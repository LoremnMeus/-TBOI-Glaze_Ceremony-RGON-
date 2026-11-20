-- Map heading for explore wind. Pure: no Isaac API.
-- Grid is 13 cells wide. +X is east, +Y is south.
-- Blow is from the eye toward the room. ang is the wind_runtime value
-- whose wind_blow_dir(ang) matches that blow (the runtime adds 90 degrees).

local M = { GRID = 13 }

local BFS_BLOW = {
	[0] = { 1, 0 },
	[1] = { 0, 1 },
	[2] = { -1, 0 },
	[3] = { 0, -1 },
}

function M.sgid_to_xy(sgid)
	sgid = tonumber(sgid) or 0
	return sgid % M.GRID, math.floor(sgid / M.GRID)
end

function M.center_of(cells)
	if type(cells) ~= "table" or #cells == 0 then return nil, nil end
	local sx, sy = 0, 0
	for i = 1, #cells do
		local x, y = M.sgid_to_xy(cells[i])
		sx = sx + x
		sy = sy + y
	end
	return sx / #cells, sy / #cells
end

function M.normalize(x, y)
	local len = math.sqrt((x or 0) * (x or 0) + (y or 0) * (y or 0))
	if len < 1e-6 then return nil, nil end
	return x / len, y / len
end

function M.bfs_blow(dir)
	local v = BFS_BLOW[dir]
	if not v then return nil, nil end
	return v[1], v[2]
end

--- Geometric heading wins. BFS only tilts it when the two are not opposed.
function M.mix(geo_x, geo_y, bfs_x, bfs_y)
	local gx, gy = M.normalize(geo_x, geo_y)
	if not gx then return nil, nil end
	local bx, by = nil, nil
	if bfs_x ~= nil and bfs_y ~= nil then
		bx, by = M.normalize(bfs_x, bfs_y)
	end
	if not bx then return gx, gy end
	if gx * bx + gy * by < 0 then
		return gx, gy
	end
	return M.normalize(0.8 * gx + 0.2 * bx, 0.8 * gy + 0.2 * by)
end

local function atan2(y, x)
	if math.atan2 then return math.atan2(y, x) end
	return math.atan(y, x)
end

function M.blow_to_ang(x, y)
	local nx, ny = M.normalize(x, y)
	if not nx then return nil end
	return math.deg(atan2(ny, nx)) - 90
end

function M.heading(eye_cells, room_cells, bfs_dir)
	local ex, ey = M.center_of(eye_cells)
	local rx, ry = M.center_of(room_cells)
	if not ex or not rx then return nil end
	local bx, by = M.bfs_blow(bfs_dir)
	local dx, dy = M.mix(rx - ex, ry - ey, bx, by)
	if not dx then return nil end
	return {
		x = dx,
		y = dy,
		ang = M.blow_to_ang(dx, dy),
		cells = #room_cells,
		eye_x = ex,
		eye_y = ey,
		room_x = rx,
		room_y = ry,
	}
end

return M
