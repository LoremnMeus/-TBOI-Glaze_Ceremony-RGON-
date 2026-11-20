-- 放逐边境的整数格陈列。自动规则：1–15 为 1×1 棋盘，16–20 为 1×1 隔行，21–32 为 1×2 棋盘。
-- 棋盘格满足 (x+y) 同相位，因此任意两件的曼哈顿距离至少为 2。坐标都是房间内部从 0 开始的整数格。
local M = {}

local SHAPES = {
	["1x1"] = { key = "1x1", variant = 24851, room_shape = 1, w = 13, h = 7 },
	["1x2"] = { key = "1x2", variant = 24852, room_shape = 4, w = 13, h = 14 },
	["2x1"] = { key = "2x1", variant = 24853, room_shape = 6, w = 26, h = 7 },
	["2x2"] = { key = "2x2", variant = 24850, room_shape = 8, w = 26, h = 14 },
}

local VARIANT_SHAPE = {
	[24851] = "1x1",
	[24852] = "1x2",
	[24853] = "2x1",
	[24850] = "2x2",
}

local function profile_for(shape)
	if shape == "1x1" then
		return {
			shape = shape, w = 13, h = 7, axis = 6, even = false,
			x0 = 1, x1 = 11, y0 = 1, y1 = 4, parity = 1,
			center = { x = 6, y = 3 },
			spawn = { x = 6, y = 5 },
			door = { x = 6, y = 7 },
			door_front = { x = 6, y = 6 },
			door_slot = "down0",
			row_ys = { 2, 4 },
			row_cap = 10,
			reserved = { ["6:5"] = true, ["6:6"] = true, ["5:6"] = true, ["7:6"] = true },
		}
	elseif shape == "1x2" then
		return {
			shape = shape, w = 13, h = 14, axis = 6, even = false,
			x0 = 1, x1 = 11, y0 = 2, y1 = 10, parity = 0,
			center = { x = 6, y = 6 },
			spawn = { x = 6, y = 12 },
			door = { x = 6, y = 14 },
			door_front = { x = 6, y = 13 },
			door_slot = "down0",
			row_ys = { 3, 5, 8, 10 },
			row_cap = 10,
			reserved = { ["6:12"] = true, ["6:13"] = true, ["5:13"] = true, ["7:13"] = true, ["6:11"] = true },
		}
	elseif shape == "2x1" then
		return {
			shape = shape, w = 26, h = 7, axis = nil, even = true,
			x0 = 1, x1 = 11, y0 = 1, y1 = 4, parity = 1,
			center = { x = 12.5, y = 3 },
			spawn = { x = 12, y = 5 },
			door = { x = 12, y = 7 },
			door_front = { x = 12, y = 6 },
			door_slot = nil,
			row_ys = { 2, 4 },
			row_cap = 10,
			reserved = { ["12:5"] = true, ["12:6"] = true, ["11:6"] = true, ["13:6"] = true },
		}
	elseif shape == "2x2" then
		return {
			shape = shape, w = 26, h = 14, axis = nil, even = true,
			x0 = 1, x1 = 11, y0 = 2, y1 = 10, parity = 0,
			center = { x = 12.5, y = 6 },
			spawn = { x = 12, y = 12 },
			door = { x = 12, y = 14 },
			door_front = { x = 12, y = 13 },
			door_slot = nil,
			row_ys = { 3, 5, 8, 10 },
			row_cap = 10,
			reserved = { ["12:12"] = true, ["12:13"] = true, ["11:13"] = true, ["13:13"] = true, ["12:11"] = true },
		}
	end
	return nil
end

local function cell_key(x, y)
	return tostring(x) .. ":" .. tostring(y)
end

local function mirror_x(x, w)
	return (w - 1) - x
end

local function dist2(cell, center)
	local dx = cell.x - center.x
	local dy = cell.y - center.y
	return dx * dx + dy * dy
end

local function copy_cell(x, y)
	return { x = x, y = y }
end

function M.shape_info(shape)
	return SHAPES[shape]
end

function M.shape_by_variant(variant)
	return VARIANT_SHAPE[tonumber(variant) or -1]
end

function M.profile(shape)
	return profile_for(shape)
end

function M.auto_shape(count)
	count = tonumber(count) or 0
	if count >= 21 then
		return "1x2"
	end
	return "1x1"
end

function M.grid_index(grid_width, x, y)
	return (y + 1) * grid_width + (x + 1)
end

function M.world_position(room, x, y)
	local width = room:GetGridWidth()
	return room:GetGridPosition(M.grid_index(width, x, y))
end

local function walkable_bfs(profile, positions)
	local occupied = {}
	for _, cell in ipairs(positions) do
		occupied[cell_key(cell.x, cell.y)] = true
	end
	local spawn = profile.spawn
	if occupied[cell_key(spawn.x, spawn.y)] then
		return false
	end
	local seen = { [cell_key(spawn.x, spawn.y)] = true }
	local queue = { { x = spawn.x, y = spawn.y } }
	local head = 1
	while queue[head] do
		local cell = queue[head]
		head = head + 1
		local steps = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
		for i = 1, 4 do
			local nx = cell.x + steps[i][1]
			local ny = cell.y + steps[i][2]
			if nx >= 0 and ny >= 0 and nx < profile.w and ny < profile.h then
				local key = cell_key(nx, ny)
				if not occupied[key] and not seen[key] then
					seen[key] = true
					queue[#queue + 1] = { x = nx, y = ny }
				end
			end
		end
	end
	local front = profile.door_front
	if front.y >= 0 and front.y < profile.h then
		if not seen[cell_key(front.x, front.y)] then
			return false
		end
	elseif front.y == profile.h then
		if not seen[cell_key(front.x, profile.h - 1)] then
			return false
		end
	else
		return false
	end
	for _, cell in ipairs(positions) do
		local open = false
		local steps = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
		for i = 1, 4 do
			local nx = cell.x + steps[i][1]
			local ny = cell.y + steps[i][2]
			if nx >= 0 and ny >= 0 and nx < profile.w and ny < profile.h and seen[cell_key(nx, ny)] then
				open = true
				break
			end
		end
		if not open then
			return false
		end
	end
	return true
end

local function checker_groups(profile)
	local have = {}
	local cells = {}
	for y = profile.y0, profile.y1 do
		for x = profile.x0, profile.x1 do
			if not profile.reserved[cell_key(x, y)] and (x + y) % 2 == profile.parity then
				local mx = mirror_x(x, profile.w)
				if profile.even and profile.reserved[cell_key(mx, y)] then
				else
					have[cell_key(x, y)] = true
					cells[#cells + 1] = copy_cell(x, y)
				end
			end
		end
	end
	local groups = {}
	for _, cell in ipairs(cells) do
		local mx = mirror_x(cell.x, profile.w)
		if not profile.even and cell.x == profile.axis then
			groups[#groups + 1] = { dist = dist2(cell, profile.center), kind = 0, cells = { cell } }
		elseif profile.even and cell.x < mx and not profile.reserved[cell_key(mx, cell.y)] then
			groups[#groups + 1] = {
				dist = dist2(cell, profile.center),
				kind = 1,
				cells = { cell, copy_cell(mx, cell.y) },
			}
		elseif not profile.even and cell.x < mx and have[cell_key(mx, cell.y)] then
			groups[#groups + 1] = {
				dist = dist2(cell, profile.center),
				kind = 1,
				cells = { cell, copy_cell(mx, cell.y) },
			}
		end
	end
	table.sort(groups, function(a, b)
		if a.dist ~= b.dist then
			return a.dist < b.dist
		end
		if a.kind ~= b.kind then
			return a.kind < b.kind
		end
		if a.cells[1].y ~= b.cells[1].y then
			return a.cells[1].y < b.cells[1].y
		end
		return a.cells[1].x < b.cells[1].x
	end)
	return groups
end

local function row_groups(profile)
	local groups = {}
	local pair_n = math.floor(profile.row_cap / 2)
	for _, y in ipairs(profile.row_ys) do
		if not profile.even and profile.axis ~= nil then
			local center = copy_cell(profile.axis, y)
			if not profile.reserved[cell_key(center.x, center.y)] then
				groups[#groups + 1] = { dist = dist2(center, profile.center), cells = { center } }
			end
			for i = 1, pair_n do
				local left_x = profile.axis - i
				local right_x = profile.axis + i
				if left_x >= 0 and right_x < profile.w
					and not profile.reserved[cell_key(left_x, y)]
					and not profile.reserved[cell_key(right_x, y)] then
					local left = copy_cell(left_x, y)
					groups[#groups + 1] = { dist = dist2(left, profile.center), cells = { left, copy_cell(right_x, y) } }
				end
			end
		else
			for x = profile.x0, profile.x1 do
				local mx = mirror_x(x, profile.w)
				if x < mx and not profile.reserved[cell_key(x, y)] and not profile.reserved[cell_key(mx, y)] then
					local left = copy_cell(x, y)
					groups[#groups + 1] = { dist = dist2(left, profile.center), cells = { left, copy_cell(mx, y) } }
				end
			end
		end
	end
	table.sort(groups, function(a, b)
		if a.dist ~= b.dist then
			return a.dist < b.dist
		end
		if a.cells[1].y ~= b.cells[1].y then
			return a.cells[1].y < b.cells[1].y
		end
		return a.cells[1].x < b.cells[1].x
	end)
	return groups
end

local function take_groups(profile, groups, count, allow_singles)
	local chosen = {}
	local used_single = false
	for _, group in ipairs(groups) do
		if #chosen >= count then
			break
		end
		local size = #group.cells
		if size == 1 and not allow_singles then
		elseif size == 1 then
			if count % 2 == 0 or used_single or #chosen + 1 > count then
			else
				local trial = { table.unpack(chosen) }
				trial[#trial + 1] = group.cells[1]
				if walkable_bfs(profile, trial) then
					chosen = trial
					used_single = true
				end
			end
		elseif size == 2 then
			if #chosen + 2 > count then
			elseif count % 2 == 1 and allow_singles and not used_single and #chosen + 2 == count then
			else
				local trial = { table.unpack(chosen) }
				trial[#trial + 1] = group.cells[1]
				trial[#trial + 1] = group.cells[2]
				if walkable_bfs(profile, trial) then
					chosen = trial
				end
			end
		end
	end
	table.sort(chosen, function(a, b)
		local da = dist2(a, profile.center)
		local db = dist2(b, profile.center)
		if da ~= db then
			return da < db
		end
		if a.y ~= b.y then
			return a.y < b.y
		end
		return a.x < b.x
	end)
	return chosen
end

local function min_manhattan(positions)
	if #positions < 2 then
		return 99
	end
	local best = 99
	for i = 1, #positions do
		for j = i + 1, #positions do
			local dist = math.abs(positions[i].x - positions[j].x) + math.abs(positions[i].y - positions[j].y)
			if dist < best then
				best = dist
			end
		end
	end
	return best
end

local function mirror_ok(profile, positions)
	local have = {}
	for _, cell in ipairs(positions) do
		have[cell_key(cell.x, cell.y)] = true
	end
	for _, cell in ipairs(positions) do
		if not have[cell_key(mirror_x(cell.x, profile.w), cell.y)] then
			return false
		end
	end
	return true
end

local function parity_ok(profile, positions, mode)
	if mode ~= "checker" or #positions == 0 then
		return true
	end
	if profile.even then
		for _, cell in ipairs(positions) do
			local mx = mirror_x(cell.x, profile.w)
			local left = cell.x < mx and cell.x or mx
			if (left + cell.y) % 2 ~= profile.parity then
				return false
			end
		end
		return true
	end
	local phase = nil
	for _, cell in ipairs(positions) do
		local value = (cell.x + cell.y) % 2
		if phase == nil then
			phase = value
		elseif phase ~= value then
			return false
		end
	end
	return true
end

local function door_clear(profile, positions)
	local occupied = {}
	for _, cell in ipairs(positions) do
		occupied[cell_key(cell.x, cell.y)] = true
	end
	local points = { profile.spawn, profile.door_front }
	for _, point in ipairs(points) do
		if point.y >= 0 and point.y < profile.h and occupied[cell_key(point.x, point.y)] then
			return false
		end
	end
	return true
end

function M.plan(shape, count, algorithm)
	local profile = profile_for(shape)
	count = math.max(0, tonumber(count) or 0)
	algorithm = algorithm or "auto"
	if not profile then
		return {
			shape = shape, mode = "none", positions = {}, placed = 0, missing = count,
			mirror_ok = false, reachable = false, door_clear = false, parity_ok = false,
			min_manhattan = 0, capacity = 0,
		}
	end
	if algorithm == "auto" then
		if shape == "1x1" and count >= 16 then
			algorithm = "rows"
		else
			algorithm = "checker"
		end
	end
	local groups = algorithm == "rows" and row_groups(profile) or checker_groups(profile)
	local allow_singles = (not profile.even) and (algorithm == "checker" or algorithm == "rows")
	local positions = take_groups(profile, groups, count, allow_singles)
	local reachable = walkable_bfs(profile, positions)
	return {
		shape = shape,
		variant = SHAPES[shape].variant,
		mode = algorithm,
		positions = positions,
		placed = #positions,
		missing = math.max(0, count - #positions),
		mirror_ok = mirror_ok(profile, positions),
		reachable = reachable,
		door_clear = door_clear(profile, positions),
		parity_ok = parity_ok(profile, positions, algorithm),
		min_manhattan = min_manhattan(positions),
		spawn = profile.spawn,
		door = profile.door,
		door_front = profile.door_front,
		door_slot = profile.door_slot,
		capacity = #groups,
	}
end

function M.audit_auto()
	local failed = {}
	for count = 1, 32 do
		local shape = M.auto_shape(count)
		local plan = M.plan(shape, count, "auto")
		local reasons = {}
		if plan.missing > 0 then
			reasons[#reasons + 1] = "missing"
		end
		if not plan.mirror_ok then
			reasons[#reasons + 1] = "mirror"
		end
		if not plan.reachable then
			reasons[#reasons + 1] = "reach"
		end
		if not plan.door_clear then
			reasons[#reasons + 1] = "door"
		end
		if plan.mode == "checker" and plan.min_manhattan < 2 then
			reasons[#reasons + 1] = "manhattan"
		end
		if plan.mode == "checker" and not plan.parity_ok then
			reasons[#reasons + 1] = "parity"
		end
		if #reasons > 0 then
			failed[#failed + 1] = { count = count, shape = shape, reasons = reasons }
		end
	end
	return failed
end

return M
