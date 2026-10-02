local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local Ghost = require("Qing_Remaster_scripts.others.player_appearance_ghost")

-- 世末天依：清房后有概率路过。身体用 character_Tianyi.png，头发仍叠在 head 上。
local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Tianyi,
	own_key = "Item_TianYi_",
	NOTICE_DIST = 64,
	WALK_SPEED = 2.4,
	LEAVE_SPEED = 2.7,
	WALK_ANIM_SPEED = 1.0,
	EXIT_SPEED = 1.2,
	APPEAR_DUR = 12,
	NOTICE_DUR = 10,
	LIFT_HOLD_DUR = 36,
	GIVE_HOLD_FRAME = 14,
	LIFT_FALLBACK = 16,
	HIDE_FALLBACK = 12,
	AFTER_HIDE_DUR = 8,
	DISAPPEAR_DUR = 18,
	PENDING_DELAY = 8,
	EFFECT_SUB = 30,
	DOOR_INSET = 28,
	DOOR_FADE = 8,
	HAIR_ANM2 = "gfx/characters/TianYi_Hair.anm2",
}

local PLAYER_ANM2 = "gfx/001.000_player.anm2"
local TIANYI_SKIN = "gfx/characters/costumes/character_Tianyi.png"
-- base_sheets 的 key 是 Sprite Layer ID。0–12 与 14 是角色图；13 是 ghost.png，不替换。
local TIANYI_BASE_SHEETS = {}
for _, layer_id in ipairs({
	0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14,
}) do
	TIANYI_BASE_SHEETS[tostring(layer_id)] = TIANYI_SKIN
end
local TIANYI_APPEARANCE = {
	player_type = PlayerType.PLAYER_ISAAC,
	base_anm2 = PLAYER_ANM2,
	base_sheets = TIANYI_BASE_SHEETS,
	costumes = {
		{
			anm2 = "gfx/characters/TianYi_Hair.anm2",
			priority = 99,
		},
	},
}

--- Shared Validation Suite / debug consumers may read TianYi traveler appearance without cloning constants.
function item.get_traveler_appearance()
	return Ghost.sanitize(TIANYI_APPEARANCE) or TIANYI_APPEARANCE
end

local PROC_CHANCE = {
	[1] = 0.20,
	[2] = 0.30,
	[3] = 0.38,
	[4] = 0.45,
}
local PROC_CHANCE_LATER = 0.50
local PROC_FORBIDDEN_ROOM = {
	[RoomType.ROOM_ERROR] = true,
	[RoomType.ROOM_DUNGEON] = true,
	[RoomType.ROOM_BOSSRUSH] = true,
	[RoomType.ROOM_BLACK_MARKET] = true,
}
local GIFT_CATEGORIES = {
	{id = "coin", weight = 21},
	{id = "heart", weight = 21},
	{id = "bomb", weight = 13},
	{id = "key", weight = 13},
	{id = "battery", weight = 9},
	{id = "card", weight = 9},
	{id = "chest", weight = 9},
	{id = "collectible", weight = 5},
}
local GIFT_COIN = {
	{subtype = CoinSubType.COIN_NICKEL, weight = 65, gfx = "gfx/items/pick ups/pickup_001_coin.png"},
	{subtype = CoinSubType.COIN_DIME, weight = 20, gfx = "gfx/items/pick ups/pickup_001_coin.png"},
	{subtype = CoinSubType.COIN_LUCKYPENNY, weight = 15, gfx = "gfx/items/pick ups/pickup_001_coin.png"},
}
local GIFT_BOMB = {
	{subtype = BombSubType.BOMB_DOUBLEPACK, weight = 85, gfx = "gfx/items/pick ups/pickup_016_bomb.png"},
	{subtype = BombSubType.BOMB_GOLDEN, weight = 15, gfx = "gfx/items/pick ups/pickup_016_bomb.png"},
}
local GIFT_KEY = {
	{subtype = KeySubType.KEY_CHARGED, weight = 85, gfx = "gfx/items/pick ups/pickup_011_key.png"},
	{subtype = KeySubType.KEY_GOLDEN, weight = 15, gfx = "gfx/items/pick ups/pickup_011_key.png"},
}
local GIFT_HEART = {
	{subtype = HeartSubType.HEART_SOUL, weight = 55, gfx = "gfx/items/pick ups/pickup_001_heart.png"},
	{subtype = HeartSubType.HEART_BLACK, weight = 30, gfx = "gfx/items/pick ups/pickup_001_heart.png"},
	{subtype = HeartSubType.HEART_ETERNAL, weight = 15, gfx = "gfx/items/pick ups/pickup_001_heart.png"},
}
local GIFT_BATTERY = {
	{subtype = BatterySubType.BATTERY_NORMAL, weight = 75, gfx = "gfx/items/pick ups/pickup_054_battery.png"},
	{subtype = BatterySubType.BATTERY_MEGA, weight = 25, gfx = "gfx/items/pick ups/pickup_054_battery.png"},
}
local GIFT_CHEST = {
	{variant = PickupVariant.PICKUP_LOCKEDCHEST, weight = 1, gfx = "gfx/items/pick ups/pickup_053_chest.png"},
	{variant = PickupVariant.PICKUP_OLDCHEST, weight = 1, gfx = "gfx/items/pick ups/pickup_053_chest.png"},
	{variant = PickupVariant.PICKUP_ETERNALCHEST, weight = 1, gfx = "gfx/items/pick ups/pickup_053_chest.png"},
}
item.debug_stats = {rolls = 0, procs = 0}
item.pending_spawn = nil

local function total_copies()
	local n = 0
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player then
			n = n + player:GetCollectibleNum(item.entity)
		end
	end
	return n
end

local function proc_chance(copies)
	if not copies or copies <= 0 then return 0 end
	return PROC_CHANCE[copies] or PROC_CHANCE_LATER
end

local function pick_weighted(rng, entries)
	local total = 0
	for _, entry in ipairs(entries) do
		total = total + entry.weight
	end
	if total <= 0 then return entries[#entries] end
	local roll = rng:RandomFloat() * total
	local acc = 0
	for _, entry in ipairs(entries) do
		acc = acc + entry.weight
		if roll < acc then return entry end
	end
	return entries[#entries]
end

local function current_room_desc()
	local level = Game():GetLevel()
	return {
		room_index = level:GetCurrentRoomIndex(),
		stage = level:GetStage(),
		stage_type = level:GetStageType(),
	}
end

local function same_room_desc(desc)
	if not desc then return false end
	local now = current_room_desc()
	return now.room_index == desc.room_index
		and now.stage == desc.stage
		and now.stage_type == desc.stage_type
end

local function room_proc_forbidden()
	return PROC_FORBIDDEN_ROOM[Game():GetRoom():GetType()] == true
end

local function collect_eligible_doors(from_pos)
	local room = Game():GetRoom()
	local ret = {}
	for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
		if room:IsDoorSlotAllowed(slot) then
			local door = room:GetDoor(slot)
			if door then
				local is_open = false
				local ok = pcall(function()
					is_open = door:IsOpen()
				end)
				if ok and is_open then
					local pos = room:GetDoorSlotPosition(slot)
					ret[#ret + 1] = {
						slot = slot,
						door = door,
						pos = pos,
						dist = (pos - from_pos):Length(),
					}
				end
			end
		end
	end
	return ret
end

local function door_inside_position(entry, distance)
	local room = Game():GetRoom()
	local center = room:GetCenterPos()
	local delta = center - entry.pos
	if delta:Length() < 0.001 then
		return entry.pos
	end
	return entry.pos + delta:Resized(distance or item.DOOR_INSET)
end

local function nearest_player(pos)
	local best, best_d
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if p and p:Exists() and not p:IsDead() then
			local dist = (p.Position - pos):Length()
			if not best_d or dist < best_d then
				best = p
				best_d = dist
			end
		end
	end
	return best, best_d or 9999
end

local GRID_DIRS = {
	{ x = 1, y = 0 },
	{ x = -1, y = 0 },
	{ x = 0, y = 1 },
	{ x = 0, y = -1 },
}
local STEP_COST = 10
local TURN_PENALTY = 5
local MIN_STRAIGHT_RUN = 2
local SHORT_RUN_TURN_PENALTY = 10
local DIR_NONE = 0

local function is_walkable_grid(room, index)
	if not room or index == nil or index < 0 or index >= room:GetGridSize() then
		return false
	end
	return room:GetGridCollision(index) == GridCollisionClass.COLLISION_NONE
end

local function inward_step(pos)
	local center = Game():GetRoom():GetCenterPos()
	local delta = center - pos
	if math.abs(delta.X) >= math.abs(delta.Y) then
		if delta.X >= 0 then return 1, 0 end
		return -1, 0
	end
	if delta.Y >= 0 then return 0, 1 end
	return 0, -1
end

local function walkable_index_near(room, pos)
	local index = room:GetGridIndex(pos)
	if type(index) ~= "number" then return nil end
	if is_walkable_grid(room, index) then return index end
	local width = room:GetGridWidth()
	local x = index % width
	local y = math.floor(index / width)
	local sx, sy = inward_step(pos)
	for step = 1, 3 do
		local nx, ny = x + sx * step, y + sy * step
		if nx >= 0 and ny >= 0 then
			local ni = nx + ny * width
			if is_walkable_grid(room, ni) then return ni end
		end
	end
	return nil
end

local function compress_grid_path(nodes)
	if not nodes or #nodes <= 2 then return nodes end
	local out = { nodes[1] }
	for i = 2, #nodes - 1 do
		local prev, cur, nxt = nodes[i - 1], nodes[i], nodes[i + 1]
		local dx1, dy1 = cur.X - prev.X, cur.Y - prev.Y
		local dx2, dy2 = nxt.X - cur.X, nxt.Y - cur.Y
		local turn = (math.abs(dx1) > 0.5 and math.abs(dy2) > 0.5)
			or (math.abs(dy1) > 0.5 and math.abs(dx2) > 0.5)
		if turn then
			out[#out + 1] = cur
		end
	end
	out[#out + 1] = nodes[#nodes]
	return out
end

local function grid_manhattan(index, other, width)
	local x, y = index % width, math.floor(index / width)
	local ox, oy = other % width, math.floor(other / width)
	return math.abs(x - ox) + math.abs(y - oy)
end

local function grid_clearance_penalty(room, index, start_i, goal_i)
	if index == start_i or index == goal_i then return 0 end
	local width = room:GetGridWidth()
	local size = room:GetGridSize()
	local x = index % width
	local y = math.floor(index / width)
	local blocked = 0
	for _, dir in ipairs(GRID_DIRS) do
		local nx, ny = x + dir.x, y + dir.y
		if nx < 0 or ny < 0 then
			blocked = blocked + 1
		else
			local ni = nx + ny * width
			if ni >= size or not is_walkable_grid(room, ni) then
				blocked = blocked + 1
			end
		end
	end
	local penalty = 0
	if blocked == 1 then
		penalty = 4
	elseif blocked == 2 then
		penalty = 8
	elseif blocked > 2 then
		penalty = 12
	end
	if grid_manhattan(index, start_i, width) <= 1 or grid_manhattan(index, goal_i, width) <= 1 then
		penalty = math.floor(penalty * 0.5)
	end
	return penalty
end

local function grid_center_penalty(index, center_i, width)
	if not center_i then return 0 end
	local d = grid_manhattan(index, center_i, width)
	if d <= 1 then return 0 end
	if d <= 3 then return 1 end
	if d <= 5 then return 2 end
	if d <= 7 then return 3 end
	return 4
end

local function run_bucket(run_len)
	if not run_len or run_len <= 1 then return 1 end
	if run_len == 2 then return 2 end
	return 3
end

local function state_key(index, dir_id, bucket)
	return tostring(index) .. ":" .. tostring(dir_id) .. ":" .. tostring(bucket or 0)
end

local function grid_dir_between(a, b, width)
	local dx = (b % width) - (a % width)
	local dy = math.floor(b / width) - math.floor(a / width)
	if dx == 1 and dy == 0 then return 1 end
	if dx == -1 and dy == 0 then return 2 end
	if dx == 0 and dy == 1 then return 3 end
	if dx == 0 and dy == -1 then return 4 end
	return nil
end

local function step_grid_index(index, dir_id, width, size)
	local dir = GRID_DIRS[dir_id]
	if not dir then return nil end
	local x = index % width
	local y = math.floor(index / width)
	local nx, ny = x + dir.x, y + dir.y
	if nx < 0 or ny < 0 then return nil end
	local ni = nx + ny * width
	if ni >= size then return nil end
	return ni
end

local function cell_near_end(index, start_i, goal_i, width)
	return grid_manhattan(index, start_i, width) <= 1 or grid_manhattan(index, goal_i, width) <= 1
end

-- 左→下1格→左：把这一格横竖折线挪到直线段的一端，且替代格可走、净空不更差。
local function collapse_micro_jogs(indices, room, start_i, goal_i)
	if not indices or #indices < 4 then return indices end
	local width = room:GetGridWidth()
	local size = room:GetGridSize()
	local guard = 0
	local changed = true
	while changed and guard < 8 do
		changed = false
		guard = guard + 1
		local i = 1
		while i <= #indices - 3 do
			local a, b, c, d = indices[i], indices[i + 1], indices[i + 2], indices[i + 3]
			local d1 = grid_dir_between(a, b, width)
			local d2 = grid_dir_between(b, c, width)
			local d3 = grid_dir_between(c, d, width)
			local near = cell_near_end(b, start_i, goal_i, width) or cell_near_end(c, start_i, goal_i, width)
			if d1 and d2 and d1 == d3 and d1 ~= d2 and not near then
				local late = step_grid_index(b, d1, width, size)
				local early = step_grid_index(a, d2, width, size)
				local function acceptable(idx, removed)
					if not idx or not is_walkable_grid(room, idx) then return false end
					return grid_clearance_penalty(room, idx, start_i, goal_i)
						<= grid_clearance_penalty(room, removed, start_i, goal_i)
				end
				local use_late = acceptable(late, c) and grid_dir_between(late, d, width) == d2
				local use_early = acceptable(early, b) and grid_dir_between(early, c, width) == d1
				if use_late or use_early then
					local pick_late = use_late
					if use_late and use_early then
						local late_c = grid_clearance_penalty(room, late, start_i, goal_i)
						local early_c = grid_clearance_penalty(room, early, start_i, goal_i)
						pick_late = late_c <= early_c
					end
					if pick_late then
						indices[i + 2] = late
					else
						indices[i + 1] = early
					end
					changed = true
				end
			end
			i = i + 1
		end
	end
	return indices
end

local function build_grid_path(from_pos, to_pos)
	local room = Game():GetRoom()
	local start_i = walkable_index_near(room, from_pos)
	local goal_i = walkable_index_near(room, to_pos)
	if not start_i or not goal_i then return nil end
	local empty_cost = {
		base = 0, clearance = 0, turn = 0, short = 0, center = 0, total = 0, steps = 0, turns = 0,
	}
	if start_i == goal_i then
		return {}, empty_cost
	end
	local width = room:GetGridWidth()
	local size = room:GetGridSize()
	local center_i = walkable_index_near(room, room:GetCenterPos())
	local function heuristic(index)
		return grid_manhattan(index, goal_i, width) * STEP_COST
	end
	local start_key = state_key(start_i, DIR_NONE, 0)
	local open = { start_key }
	local in_open = { [start_key] = true }
	local closed = {}
	local came = {}
	local gscore = { [start_key] = 0 }
	local fscore = { [start_key] = heuristic(start_i) }
	local meta = {
		[start_key] = {
			index = start_i, dir = DIR_NONE, run_len = 0,
			base = 0, clearance = 0, turn_cost = 0, short_cost = 0, center = 0, turns = 0, steps = 0,
		},
	}
	local function better_state(a, b)
		local fa = fscore[a] or 99999
		local fb = fscore[b] or 99999
		if fa ~= fb then return fa < fb end
		local ta = meta[a] and meta[a].turns or 0
		local tb = meta[b] and meta[b].turns or 0
		if ta ~= tb then return ta < tb end
		local ca = meta[a] and meta[a].center or 0
		local cb = meta[b] and meta[b].center or 0
		if ca ~= cb then return ca < cb end
		local ia = meta[a] and meta[a].index or start_i
		local ib = meta[b] and meta[b].index or start_i
		return heuristic(ia) < heuristic(ib)
	end
	while #open > 0 do
		local best_n, best_key = 1, open[1]
		for n = 2, #open do
			if better_state(open[n], best_key) then
				best_n, best_key = n, open[n]
			end
		end
		table.remove(open, best_n)
		in_open[best_key] = nil
		local best = meta[best_key]
		if best.index == goal_i then
			local rev = {}
			local cur = best_key
			while cur do
				rev[#rev + 1] = cur
				cur = came[cur]
			end
			local indices = { start_i }
			for i = #rev - 1, 1, -1 do
				indices[#indices + 1] = meta[rev[i]].index
			end
			indices = collapse_micro_jogs(indices, room, start_i, goal_i)
			local nodes = {}
			for i = 2, #indices do
				nodes[#nodes + 1] = room:GetGridPosition(indices[i])
			end
			return compress_grid_path(nodes), {
				base = best.base,
				clearance = best.clearance,
				turn = best.turn_cost,
				short = best.short_cost,
				center = best.center,
				total = gscore[best_key] or 0,
				steps = best.steps,
				turns = best.turns,
			}
		end
		closed[best_key] = true
		local x = best.index % width
		local y = math.floor(best.index / width)
		for dir_id, dir in ipairs(GRID_DIRS) do
			local nx, ny = x + dir.x, y + dir.y
			if nx >= 0 and ny >= 0 then
				local ni = nx + ny * width
				local new_run = (best.dir == dir_id) and (best.run_len + 1) or 1
				local nk = state_key(ni, dir_id, run_bucket(new_run))
				if ni < size and not closed[nk] and is_walkable_grid(room, ni) then
					local penalty = grid_clearance_penalty(room, ni, start_i, goal_i)
					local center_p = grid_center_penalty(ni, center_i, width)
					local turn = 0
					local short = 0
					if best.dir ~= DIR_NONE and best.dir ~= dir_id then
						turn = TURN_PENALTY
						local near = cell_near_end(best.index, start_i, goal_i, width)
							or cell_near_end(ni, start_i, goal_i, width)
						if best.run_len < MIN_STRAIGHT_RUN and not near then
							short = SHORT_RUN_TURN_PENALTY
						end
					end
					local next_g = gscore[best_key] + STEP_COST + penalty + turn + short + center_p
					local new_turns = best.turns + (turn > 0 and 1 or 0)
					local new_center = best.center + center_p
					local new_short = best.short_cost + short
					local old = meta[nk]
					local replace = not gscore[nk] or next_g < gscore[nk]
					if not replace and old and next_g == gscore[nk] then
						if new_turns < old.turns then
							replace = true
						elseif new_turns == old.turns and new_center < old.center then
							replace = true
						end
					end
					if replace then
						came[nk] = best_key
						gscore[nk] = next_g
						fscore[nk] = next_g + heuristic(ni)
						meta[nk] = {
							index = ni,
							dir = dir_id,
							run_len = new_run,
							base = best.base + STEP_COST,
							clearance = best.clearance + penalty,
							turn_cost = best.turn_cost + turn,
							short_cost = new_short,
							center = new_center,
							turns = new_turns,
							steps = best.steps + 1,
						}
						if not in_open[nk] then
							open[#open + 1] = nk
							in_open[nk] = true
						end
					end
				end
			end
		end
	end
	return nil
end

local function path_exists(from_pos, to_pos)
	return build_grid_path(from_pos, to_pos) ~= nil
end

local function grid_step_pos(room, origin_index, ix, iy, steps, lateral)
	if type(origin_index) ~= "number" or origin_index < 0 then return nil end
	local width = room:GetGridWidth()
	local x = origin_index % width
	local y = math.floor(origin_index / width)
	local lx, ly = -iy, ix
	local nx = x + ix * steps + lx * lateral
	local ny = y + iy * steps + ly * lateral
	if nx < 0 or ny < 0 then return nil end
	local ni = nx + ny * width
	if not is_walkable_grid(room, ni) then return nil end
	return room:GetGridPosition(ni)
end

local function pick_pass_point(entry_pos, door, player_pos)
	local room = Game():GetRoom()
	local origin = room:GetGridIndex(door.pos)
	if type(origin) ~= "number" or origin < 0 or not is_walkable_grid(room, origin) then
		origin = walkable_index_near(room, door.pos) or walkable_index_near(room, entry_pos)
	end
	if not origin then return nil end
	local ix, iy = inward_step(door.pos)
	local best, best_d
	for steps = 2, 4 do
		for lateral = -1, 1 do
			local pos = grid_step_pos(room, origin, ix, iy, steps, lateral)
			if pos and path_exists(entry_pos, pos) then
				local d = player_pos and (pos - player_pos):Length() or (math.abs(steps - 3) * 40 + math.abs(lateral) * 20)
				if not best_d or d < best_d then
					best = pos
					best_d = d
				end
			end
		end
	end
	return best
end

local function rng_index(rng, count)
	if rng and rng.RandomInt then
		return rng:RandomInt(count) + 1
	end
	return math.random(1, count)
end

local function shuffle_doors(doors, rng)
	local order = {}
	for i = 1, #doors do order[i] = doors[i] end
	for i = #order, 2, -1 do
		local j = rng_index(rng, i)
		order[i], order[j] = order[j], order[i]
	end
	return order
end

local function route_from_entry(entry_door, order, player_pos)
	local entry = door_inside_position(entry_door, item.DOOR_INSET)
	local interior = pick_pass_point(entry, entry_door, player_pos)
	if not interior then return nil end
	if #order == 1 then
		return {
			kind = "return",
			entry = entry,
			interior = interior,
			exit = entry,
			fade = door_inside_position(entry_door, item.DOOR_FADE),
			entry_slot = entry_door.slot,
			exit_slot = entry_door.slot,
		}
	end
	for _, door in ipairs(order) do
		if door.slot ~= entry_door.slot then
			local exit_pos = door_inside_position(door, item.DOOR_INSET)
			if path_exists(interior, exit_pos) then
				return {
					kind = "through",
					entry = entry,
					interior = interior,
					exit = exit_pos,
					fade = door_inside_position(door, item.DOOR_FADE),
					entry_slot = entry_door.slot,
					exit_slot = door.slot,
				}
			end
		end
	end
	return nil
end

local function build_traveler_route(rng)
	local room = Game():GetRoom()
	local doors = collect_eligible_doors(room:GetCenterPos())
	if #doors == 0 then return nil end
	local player = nearest_player(room:GetCenterPos())
	local player_pos = player and player.Position or nil
	local order = shuffle_doors(doors, rng)
	local best, best_d
	for _, door in ipairs(order) do
		local route = route_from_entry(door, order, player_pos)
		if route and route.interior then
			local d = player_pos and (route.interior - player_pos):Length() or 0
			if not best or (player_pos and d < best_d) then
				best = route
				best_d = d
			end
			if not player_pos then
				return route
			end
		end
	end
	return best
end

local function traveler_tint(alpha)
	if alpha == nil then alpha = 1 end
	return Color(0.55, 1.00, 0.95, alpha, 0.05, 0.18, 0.22)
end

local function tuned_number(key, fallback)
	local root = save.ModConfigSettings
	local dbg = root and root.QingRemasterOptions and root.QingRemasterOptions.Debug
	local value = dbg and tonumber(dbg[key])
	if value and value > 0 then return value end
	return fallback
end

local function walk_speed()
	return tuned_number("TianYiWalkSpeed", item.WALK_SPEED)
end

local function leave_speed()
	return item.LEAVE_SPEED
end

local function anim_speed()
	return tuned_number("TianYiAnimSpeed", item.WALK_ANIM_SPEED)
end

local function debug_show_path()
	local root = save.ModConfigSettings
	local dbg = root and root.QingRemasterOptions and root.QingRemasterOptions.Debug
	return dbg and dbg.TianYiShowPath == true
end

local function walk_anim_for_delta(delta)
	if math.abs(delta.X) >= math.abs(delta.Y) then
		if delta.X < 0 then return "WalkLeft" end
		return "WalkRight"
	end
	if delta.Y < 0 then return "WalkUp" end
	return "WalkDown"
end

local function apply_walk_anim(active, anim, force)
	local ghost = active.ghost
	if not ghost or not ghost:Exists() then return end
	anim = anim or active.anim or "WalkDown"
	if force then
		local cache = ghost:GetData()
		if cache.anim == anim then
			cache.anim = nil
		end
	end
	active.anim = anim
	ghost.FlipX = false
	Ghost.play_animation(ghost, anim)
	Ghost.sync_walk_head(ghost, anim)
	ghost:GetSprite().PlaybackSpeed = anim_speed()
end

local function reward_held_visual(reward)
	if reward and reward.collectible then
		local cfg = Isaac.GetItemConfig():GetCollectible(reward.collectible)
		local gfx = cfg and cfg.GfxFileName
		if type(gfx) == "string" and gfx ~= "" then
			return { kind = "collectible", gfx = gfx }
		end
	end
	return {
		kind = "pickup",
		variant = reward and reward.variant or PickupVariant.PICKUP_COIN,
		subtype = reward and reward.subtype or CoinSubType.COIN_NICKEL,
	}
end

local function roll_rune_subtype(rng)
	local seed = rng:Next()
	if not seed or seed < 1 then seed = 1 end
	local card = Game():GetItemPool():GetCard(seed, false, true, true)
	if card and card > 0 then return card end
	return nil
end

local function make_pickup(kind, variant, subtype)
	return {
		kind = kind,
		variant = variant,
		subtype = subtype or 0,
		count = 1,
	}
end

local function roll_collectible_reward(rng)
	local seed = rng:Next()
	if not seed or seed < 1 then seed = 1 end
	local id = Game():GetItemPool():GetCollectible(
		ItemPoolType.POOL_TREASURE,
		true,
		seed,
		CollectibleType.COLLECTIBLE_BREAKFAST
	)
	if not id or id <= 0 then return nil end
	local cfg = Isaac.GetItemConfig():GetCollectible(id)
	if not cfg then return nil end
	return {
		kind = "collectible",
		variant = PickupVariant.PICKUP_COLLECTIBLE,
		subtype = id,
		collectible = id,
		count = 1,
	}
end

local function roll_reward(rng)
	local category = pick_weighted(rng, GIFT_CATEGORIES)
	local id = category and category.id or "coin"
	if id == "coin" then
		local pick = pick_weighted(rng, GIFT_COIN)
		return make_pickup("coin", PickupVariant.PICKUP_COIN, pick.subtype)
	end
	if id == "bomb" then
		local pick = pick_weighted(rng, GIFT_BOMB)
		return make_pickup("bomb", PickupVariant.PICKUP_BOMB, pick.subtype)
	end
	if id == "key" then
		local pick = pick_weighted(rng, GIFT_KEY)
		return make_pickup("key", PickupVariant.PICKUP_KEY, pick.subtype)
	end
	if id == "heart" then
		local pick = pick_weighted(rng, GIFT_HEART)
		return make_pickup("heart", PickupVariant.PICKUP_HEART, pick.subtype)
	end
	if id == "battery" then
		local pick = pick_weighted(rng, GIFT_BATTERY)
		return make_pickup("battery", PickupVariant.PICKUP_LIL_BATTERY, pick.subtype)
	end
	if id == "card" then
		local subtype = roll_rune_subtype(rng)
		if subtype then
			return make_pickup("rune", PickupVariant.PICKUP_TAROTCARD, subtype)
		end
		local heart = GIFT_HEART[1]
		return make_pickup("heart", PickupVariant.PICKUP_HEART, heart.subtype)
	end
	if id == "collectible" then
		local reward = roll_collectible_reward(rng)
		if reward then return reward end
		local heart = GIFT_HEART[1]
		return make_pickup("heart", PickupVariant.PICKUP_HEART, heart.subtype)
	end
	local chest = pick_weighted(rng, GIFT_CHEST)
	return make_pickup("chest", chest.variant, 0)
end

local function spread_offset(index, total)
	if total <= 1 then return Vector.Zero end
	if total == 2 then
		return index == 1 and Vector(-8, 0) or Vector(8, 0)
	end
	if total == 3 then
		if index == 1 then return Vector(-10, 0) end
		if index == 2 then return Vector.Zero end
		return Vector(10, 0)
	end
	local cross = {
		Vector(0, -8),
		Vector(-8, 0),
		Vector(8, 0),
		Vector(0, 8),
	}
	if cross[index] then return cross[index] end
	local step = (index - 1) - (total - 1) * 0.5
	return Vector(step * 8, 0)
end

local function spawn_reward_list(pos, entries, velocity)
	local total = #entries
	local vel = velocity or Vector.Zero
	for i, entry in ipairs(entries) do
		Isaac.Spawn(EntityType.ENTITY_PICKUP, entry.variant, entry.subtype or 0, pos + spread_offset(i, total), vel, nil)
	end
end

local function push_spawn(list, variant, subtype, count)
	for _ = 1, (count or 1) do
		list[#list + 1] = { variant = variant, subtype = subtype or 0 }
	end
end

local function drop_reward(pos, reward, velocity)
	local list = {}
	if reward.parts then
		for _, part in ipairs(reward.parts) do
			push_spawn(list, part.variant, part.subtype, part.count or 1)
		end
	else
		push_spawn(list, reward.variant, reward.subtype or 0, reward.count or 1)
	end
	spawn_reward_list(pos, list, velocity or Vector.Zero)
end

local function clear_active_traveler()
	if item.active and item.active.ghost then
		Ghost.destroy(item.active.ghost)
	end
	item.active = nil
end

local DEBUG_HELD_REWARD = {
	kind = "coin",
	variant = PickupVariant.PICKUP_COIN,
	subtype = CoinSubType.COIN_NICKEL,
	count = 1,
	gfx = "gfx/items/pick ups/pickup_001_coin.png",
}

local function report_path(active)
	if not debug_show_path() then return end
	local path = active.path or {}
	print("[TianYi Path]")
	print("Entry slot = " .. tostring(active.entry_slot))
	print("Exit slot = " .. tostring(active.exit_slot))
	print("Nodes = " .. tostring(#path))
	local cost = active.path_cost or {}
	print("GridSteps = " .. tostring(cost.steps or 0))
	print("Turns = " .. tostring(cost.turns or 0))
	print("BaseCost = " .. tostring(cost.base or 0))
	print("ClearancePenalty = " .. tostring(cost.clearance or 0))
	print("TurnPenalty = " .. tostring(cost.turn or 0))
	print("ShortRunPenalty = " .. tostring(cost.short or 0))
	print("CenterPenalty = " .. tostring(cost.center or 0))
	print("TotalCost = " .. tostring(cost.total or 0))
	local origin = active.ghost and active.ghost.Position
	if origin then
		local room = Game():GetRoom()
		local width = room:GetGridWidth()
		local prev = room:GetGridIndex(origin)
		local parts = {}
		for _, node in ipairs(path) do
			local idx = room:GetGridIndex(node)
			if type(prev) == "number" and type(idx) == "number" and prev >= 0 and idx >= 0 then
				parts[#parts + 1] = tostring(grid_manhattan(prev, idx, width))
				prev = idx
			end
		end
		print("Segments = " .. (#parts > 0 and table.concat(parts, ",") or "0"))
	end
	for _, node in ipairs(path) do
		print(string.format("(%d,%d)", math.floor(node.X + 0.5), math.floor(node.Y + 0.5)))
	end
end

local function set_move_target(active, pos)
	active.target = pos
	active.approaching_door = false
	local path, cost = build_grid_path(active.ghost.Position, pos)
	if path == nil then
		print("[TianYi] path_failed")
		active.path = nil
		active.path_cost = nil
		return false
	end
	active.path = path
	active.path_cost = cost
	active.path_index = 1
	report_path(active)
	return true
end

local function apply_traveler_alpha(active)
	local ghost = active.ghost
	if not ghost or not ghost:Exists() then return end
	Ghost.set_tint(ghost, traveler_tint(active.alpha or 1))
end

local function freeze_pose(active)
	local ghost = active.ghost
	local anim = active.anim or "WalkDown"
	apply_walk_anim(active, anim, false)
	local spr = ghost:GetSprite()
	spr:SetFrame(anim, 0)
	spr.PlaybackSpeed = 0
	active.walk_needs_restart = true
	active.move_speed = 0
	ghost.Velocity = Vector.Zero
end

local function restart_walk_animation(active, force)
	apply_walk_anim(active, active.anim or "WalkDown", force == true)
end

local function cardinal_dir(delta)
	if math.abs(delta.X) >= math.abs(delta.Y) then
		if math.abs(delta.X) >= 4 then
			return Vector(delta.X > 0 and 1 or -1, 0)
		end
		if math.abs(delta.Y) >= 4 then
			return Vector(0, delta.Y > 0 and 1 or -1)
		end
	else
		if math.abs(delta.Y) >= 4 then
			return Vector(0, delta.Y > 0 and 1 or -1)
		end
		if math.abs(delta.X) >= 4 then
			return Vector(delta.X > 0 and 1 or -1, 0)
		end
	end
	return nil
end

local function update_walk_playback(active)
	active.ghost:GetSprite().PlaybackSpeed = anim_speed()
end

local function face_delta(active, delta)
	local anim = walk_anim_for_delta(delta)
	if anim ~= active.anim then
		apply_walk_anim(active, anim, true)
	end
end

local function follow_path(active)
	local ghost = active.ghost
	local path = active.path
	if not path then
		return "blocked"
	end
	if not path[active.path_index] then
		return "arrived"
	end
	local waypoint = path[active.path_index]
	local dir = cardinal_dir(waypoint - ghost.Position)
	if not dir then
		active.path_index = active.path_index + 1
		if not path[active.path_index] then
			return "arrived"
		end
		dir = cardinal_dir(path[active.path_index] - ghost.Position)
		if not dir then
			return "arrived"
		end
	end
	active.last_dir = dir
	face_delta(active, dir)
	if active.walk_needs_restart then
		restart_walk_animation(active, true)
		active.walk_needs_restart = false
	end
	local desired = (active.state == "LEAVE") and leave_speed() or walk_speed()
	active.move_speed = desired
	ghost.Velocity = dir * desired
	update_walk_playback(active)
	return "moving"
end

local function begin_disappear(active)
	active.state = "DISAPPEAR"
	active.phase_frame = 0
	active.alpha = 1
	active.approaching_door = false
	active.ghost.Velocity = (active.last_dir or Vector.Zero) * item.EXIT_SPEED
end

local function approach_door(active)
	local ghost = active.ghost
	local fade = active.fade_pos or active.fade or active.exit
	local delta = fade - ghost.Position
	if delta:Length() <= 12 then
		begin_disappear(active)
		return
	end
	local dir = cardinal_dir(delta)
	if not dir then
		begin_disappear(active)
		return
	end
	active.last_dir = dir
	face_delta(active, dir)
	if active.walk_needs_restart then
		restart_walk_animation(active, true)
		active.walk_needs_restart = false
	end
	local desired = (active.state == "LEAVE") and leave_speed() or walk_speed()
	active.move_speed = desired
	ghost.Velocity = dir * desired
	update_walk_playback(active)
end

local function begin_leave(active)
	active.state = "LEAVE"
	active.phase_frame = 0
	active.walk_needs_restart = true
	if not set_move_target(active, active.exit) then
		begin_disappear(active)
	end
end

local function on_path_arrived(active)
	if active.state == "WALK" and active.interior and not active.passed_window then
		active.passed_window = true
		active.state = "LEAVE"
		if not set_move_target(active, active.exit) then
			begin_disappear(active)
		end
		return
	end
	active.approaching_door = true
	active.fade_pos = active.fade or active.exit
end

local function begin_lift(active)
	local ghost = active.ghost
	if not ghost or not ghost:Exists() then return end
	active.state = "LIFT"
	active.phase_frame = 0
	active.reward_given = false
	ghost.Velocity = Vector.Zero
	active.move_speed = 0
	active.walk_needs_restart = true
	Ghost.clear_overlay(ghost)
	Ghost.play_animation(ghost, "LiftItem")
	ghost:GetSprite().PlaybackSpeed = 1
	Ghost.ensure_held(ghost, reward_held_visual(active.reward))
end

local function begin_hide(active)
	local ghost = active.ghost
	if not ghost or not ghost:Exists() then return end
	active.state = "HIDE"
	active.phase_frame = 0
	ghost.Velocity = Vector.Zero
	active.move_speed = 0
	active.walk_needs_restart = true
	Ghost.hide_held(ghost)
	Ghost.clear_overlay(ghost)
	Ghost.play_animation(ghost, "HideItem")
	ghost:GetSprite().PlaybackSpeed = 1
end

local function begin_after_hide(active)
	local ghost = active.ghost
	if not ghost or not ghost:Exists() then return end
	active.state = "AFTER_HIDE"
	active.phase_frame = 0
	ghost.Velocity = Vector.Zero
	active.move_speed = 0
	active.walk_needs_restart = true
	-- HideItem finished; restore ordinary Walk pose only now.
	apply_walk_anim(active, active.anim or "WalkDown", true)
	local spr = ghost:GetSprite()
	spr:SetFrame(active.anim or "WalkDown", 0)
	spr.PlaybackSpeed = 0
end

local function give_reward(active)
	if active.reward_given then return end
	active.reward_given = true
	local ghost = active.ghost
	if not active.suppress_reward and active.reward then
		local give_pos = ghost.Position
		local player = active.offer_player
		if player and player.Exists and player:Exists() then
			local delta = player.Position - ghost.Position
			local len = delta:Length()
			if len > 1 then
				give_pos = ghost.Position + delta:Resized(math.min(26, len * 0.45))
			end
		end
		local room = Game():GetRoom()
		if room.FindFreePickupSpawnPosition then
			give_pos = room:FindFreePickupSpawnPosition(give_pos, 8, true)
		end
		drop_reward(give_pos, active.reward, Vector.Zero)
	end
	Ghost.hide_held(ghost)
end

local function spawn_traveler(player, route, opts)
	opts = opts or {}
	if not player or not route then return end
	clear_active_traveler()
	local reward = opts.reward
	if not reward then
		if opts.suppress_reward then
			reward = DEBUG_HELD_REWARD
		else
			local rng = opts.rng or player:GetCollectibleRNG(item.entity)
			reward = roll_reward(rng)
		end
	elseif opts.suppress_reward then
		reward = DEBUG_HELD_REWARD
	end
	local appearance = Ghost.sanitize(TIANYI_APPEARANCE) or TIANYI_APPEARANCE
	local ghost = Ghost.spawn(route.entry, appearance, {
		anim = "WalkDown",
		subtype = item.entity + item.EFFECT_SUB,
		owner_key = item.own_key,
		tint = traveler_tint(1),
	})
	if not ghost then return end
	local dest = route.interior or route.exit
	local anim = walk_anim_for_delta((dest or route.exit) - route.entry)
	item.active = {
		ghost = ghost,
		reward = reward,
		reward_given = false,
		route_kind = route.kind,
		entry = route.entry,
		exit = route.exit,
		interior = route.interior,
		fade = route.fade,
		entry_slot = route.entry_slot,
		exit_slot = route.exit_slot,
		state = "APPEAR",
		phase_frame = 0,
		alpha = 0,
		target = nil,
		path = nil,
		path_index = 1,
		move_speed = 0,
		last_dir = Vector.Zero,
		facing = "Down",
		anim = anim,
		appearance = appearance,
		offer_player = nil,
		debug = opts.debug == true,
		suppress_reward = opts.suppress_reward == true,
	}
	apply_traveler_alpha(item.active)
	if not set_move_target(item.active, dest) then
		clear_active_traveler()
		return
	end
	local first = item.active.path and item.active.path[1]
	if first then
		local step = first - ghost.Position
		if step:Length() > 1 then
			item.active.anim = walk_anim_for_delta(step)
		end
	end
	apply_walk_anim(item.active, item.active.anim, true)
	ghost:GetSprite().PlaybackSpeed = 0
end

local function traveler_busy()
	if item.pending_spawn then return true end
	return item.active and item.active.ghost and item.active.ghost:Exists() or false
end

local function pick_owner_index(rng)
	local owners = {}
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player and player:HasCollectible(item.entity) then
			owners[#owners + 1] = i
		end
	end
	if #owners == 0 then return nil end
	return owners[rng:RandomInt(#owners) + 1]
end

local function route_rng_from_seed(seed)
	local rng = RNG()
	if not seed or seed < 1 then seed = 1 end
	rng:SetSeed(seed, 35)
	return rng
end

function item.try_proc_clear_reward(rng, opts)
	opts = opts or {}
	if not rng then return end
	item.debug_stats = item.debug_stats or {rolls = 0, procs = 0}
	if not opts.force then
		item.debug_stats.rolls = (item.debug_stats.rolls or 0) + 1
	end
	if total_copies() <= 0 then return end
	if traveler_busy() then return end
	if room_proc_forbidden() then return end
	if not opts.force and rng:RandomFloat() >= proc_chance(total_copies()) then
		return
	end
	local owner_index = pick_owner_index(rng)
	if not owner_index then return end
	local reward = roll_reward(rng)
	if not reward then return end
	local seed = rng:Next()
	if not seed or seed < 1 then seed = 1 end
	local room = current_room_desc()
	item.pending_spawn = {
		owner_index = owner_index,
		reward = reward,
		seed = seed,
		frame = Game():GetFrameCount() + item.PENDING_DELAY,
		room_index = room.room_index,
		stage = room.stage,
		stage_type = room.stage_type,
		debug = opts.debug == true,
		suppress_reward = opts.suppress_reward == true,
	}
	if not opts.force then
		item.debug_stats.procs = (item.debug_stats.procs or 0) + 1
	end
end

local function tick_pending_spawn()
	local pending = item.pending_spawn
	if not pending then return end
	if Game():GetFrameCount() < (pending.frame or 0) then return end
	item.pending_spawn = nil
	if not same_room_desc(pending) then return end
	if item.active and item.active.ghost and item.active.ghost:Exists() then return end
	if room_proc_forbidden() then return end
	local rng = route_rng_from_seed(pending.seed)
	local route = build_traveler_route(rng)
	if not route then return end
	local player = Game():GetPlayer(pending.owner_index)
	if not player or not player:Exists() then
		player = nearest_player(Game():GetRoom():GetCenterPos())
	end
	if not player then return end
	spawn_traveler(player, route, {
		reward = pending.reward,
		debug = pending.debug == true,
		suppress_reward = pending.suppress_reward == true,
		rng = rng,
	})
end

local function try_notice(active)
	if active.reward_given or active.approaching_door then return false end
	if active.state ~= "WALK" then return false end
	local player, dist = nearest_player(active.ghost.Position)
	if not player or dist > item.NOTICE_DIST then return false end
	active.state = "NOTICE"
	active.phase_frame = 0
	active.offer_player = player
	local look = player.Position - active.ghost.Position
	if look:Length() > 0.01 then
		active.anim = walk_anim_for_delta(look)
	end
	return true
end

local function tick_traveler()
	local active = item.active
	if not active or not active.ghost or not active.ghost:Exists() then
		item.active = nil
		return
	end
	local ghost = active.ghost
	if active.state == "APPEAR" then
		active.phase_frame = (active.phase_frame or 0) + 1
		active.alpha = math.min(1, active.phase_frame / item.APPEAR_DUR)
		apply_traveler_alpha(active)
		freeze_pose(active)
		if active.phase_frame >= item.APPEAR_DUR then
			active.alpha = 1
			apply_traveler_alpha(active)
			active.state = "WALK"
			active.phase_frame = 0
		end
		return
	end
	if active.state == "NOTICE" then
		active.phase_frame = (active.phase_frame or 0) + 1
		active.alpha = 1
		apply_traveler_alpha(active)
		freeze_pose(active)
		if active.phase_frame >= item.NOTICE_DUR then
			begin_lift(active)
		end
		return
	end
	if active.state == "LIFT" then
		active.phase_frame = (active.phase_frame or 0) + 1
		active.alpha = 1
		apply_traveler_alpha(active)
		ghost.Velocity = Vector.Zero
		active.move_speed = 0
		Ghost.sync_held(ghost, false)
		if Ghost.anim_done(ghost, "LiftItem", active.phase_frame, item.LIFT_FALLBACK) then
			active.state = "LIFT_HOLD"
			active.phase_frame = 0
		end
		return
	end
	if active.state == "LIFT_HOLD" then
		active.phase_frame = (active.phase_frame or 0) + 1
		active.alpha = 1
		apply_traveler_alpha(active)
		ghost.Velocity = Vector.Zero
		active.move_speed = 0
		Ghost.sync_held(ghost, true)
		if active.phase_frame == item.GIVE_HOLD_FRAME then
			give_reward(active)
		end
		if active.phase_frame >= item.LIFT_HOLD_DUR then
			begin_hide(active)
		end
		return
	end
	if active.state == "HIDE" then
		active.phase_frame = (active.phase_frame or 0) + 1
		active.alpha = 1
		apply_traveler_alpha(active)
		ghost.Velocity = Vector.Zero
		active.move_speed = 0
		if Ghost.anim_done(ghost, "HideItem", active.phase_frame, item.HIDE_FALLBACK) then
			begin_after_hide(active)
		end
		return
	end
	if active.state == "AFTER_HIDE" then
		active.phase_frame = (active.phase_frame or 0) + 1
		active.alpha = 1
		apply_traveler_alpha(active)
		ghost.Velocity = Vector.Zero
		active.move_speed = 0
		ghost:GetSprite().PlaybackSpeed = 0
		if active.phase_frame >= item.AFTER_HIDE_DUR then
			begin_leave(active)
		end
		return
	end
	if active.state == "DISAPPEAR" then
		active.phase_frame = (active.phase_frame or 0) + 1
		local t = math.min(1, active.phase_frame / item.DISAPPEAR_DUR)
		active.alpha = 1 - t
		apply_traveler_alpha(active)
		ghost:GetSprite().PlaybackSpeed = anim_speed()
		ghost.Velocity = (active.last_dir or Vector.Zero) * item.EXIT_SPEED
		if active.alpha <= 0 then
			Ghost.destroy(ghost)
			item.active = nil
		end
		return
	end
	active.alpha = 1
	apply_traveler_alpha(active)
	if active.approaching_door then
		approach_door(active)
		return
	end
	if try_notice(active) then
		freeze_pose(active)
		return
	end
	local step = follow_path(active)
	if step == "arrived" then
		on_path_arrived(active)
	elseif step == "blocked" then
		print("[TianYi] path_failed")
		begin_disappear(active)
	end
end
table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function()
	item.pending_spawn = nil
	item.active = nil
	item.debug_stats = {rolls = 0, procs = 0}
	if item.player_hair_probe and item.debug_set_player_hair then
		item.debug_set_player_hair(false)
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_NEW_ROOM, params = nil,
Function = function()
	item.pending_spawn = nil
	clear_active_traveler()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, params = nil,
Function = function(_, rng)
	local roll_rng = rng
	if rng and rng.GetSeed then
		local seed = rng:GetSeed()
		roll_rng = RNG()
		if not seed or seed < 1 then seed = 1 end
		roll_rng:SetSeed(seed, 35)
	end
	item.try_proc_clear_reward(roll_rng)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function()
	local debug_show = item.active and item.active.debug
	if not debug_show and total_copies() <= 0 then
		item.pending_spawn = nil
		clear_active_traveler()
		return
	end
	tick_pending_spawn()
	tick_traveler()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function()
	if not debug_show_path() then return end
	local active = item.active
	if not active or not active.path or not Isaac.DrawLine or not Isaac.WorldToScreen then return end
	local col = KColor(0.45, 0.95, 0.9, 0.9)
	local col_now = KColor(1, 0.85, 0.2, 1)
	local prev = nil
	for i, node in ipairs(active.path) do
		local screen = Isaac.WorldToScreen(node)
		if prev then
			Isaac.DrawLine(prev, screen, col, col, 2)
		end
		prev = screen
		local mark = (i == active.path_index) and col_now or col
		Isaac.DrawLine(screen - Vector(3, 0), screen + Vector(3, 0), mark, mark, 2)
		Isaac.DrawLine(screen - Vector(0, 3), screen + Vector(0, 3), mark, mark, 2)
	end
	if active.entry and Isaac.WorldToScreen then
		local entry = Isaac.WorldToScreen(active.entry)
		local exit_pos = Isaac.WorldToScreen(active.exit or active.entry)
		local entry_col = KColor(0.3, 0.7, 1, 1)
		local exit_col = KColor(1, 0.45, 0.35, 1)
		Isaac.DrawLine(entry - Vector(6, 6), entry + Vector(6, 6), entry_col, entry_col, 2)
		Isaac.DrawLine(exit_pos - Vector(6, 6), exit_pos + Vector(6, 6), exit_col, exit_col, 2)
	end
end,
})

local function first_living_player()
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if p and p:Exists() and not p:IsDead() then
			return p
		end
	end
	return nil
end

local function debug_route_rng()
	local rng = RNG()
	local seed = ((Isaac.GetTime() or 1) + (Game():GetFrameCount() or 0) * 17) % 4294967295
	if seed < 1 then seed = 1 end
	rng:SetSeed(seed, 35)
	return rng
end

function item.debug_force_spawn(opts)
	opts = opts or {}
	item.pending_spawn = nil
	if item.active and item.active.ghost and item.active.ghost:Exists() then
		clear_active_traveler()
	end
	if room_proc_forbidden() then
		return false, "forbidden_room"
	end
	local player = first_living_player()
	if not player then
		return false, "no_player"
	end
	local route = build_traveler_route(debug_route_rng())
	if not route then
		local doors = collect_eligible_doors(Game():GetRoom():GetCenterPos())
		if #doors == 0 then return false, "no_open_door" end
		return false, "path_failed"
	end
	local suppress = opts.suppress_reward ~= false
	spawn_traveler(player, route, {
		debug = true,
		suppress_reward = suppress,
		rng = suppress and nil or debug_route_rng(),
	})
	return item.active ~= nil, route
end

function item.debug_force_clear_proc()
	if item.active and item.active.ghost and item.active.ghost:Exists() then
		return false, "busy"
	end
	if item.pending_spawn then
		return false, "pending"
	end
	if total_copies() <= 0 then
		return false, "no_copies"
	end
	if room_proc_forbidden() then
		return false, "forbidden_room"
	end
	item.try_proc_clear_reward(debug_route_rng(), {force = true})
	if item.pending_spawn then
		return true
	end
	return false, "failed"
end

function item.debug_clear()
	item.pending_spawn = nil
	clear_active_traveler()
end

function item.debug_snapshot()
	local active = item.active
	local pending = item.pending_spawn
	local reward = (active and active.reward) or (pending and pending.reward)
	local cost = active and active.path_cost
	local copies = total_copies()
	local stats = item.debug_stats or {}
	return {
		copies = copies,
		chance = proc_chance(copies),
		state = active and active.state or "none",
		reward_kind = reward and reward.kind or "",
		reward_subtype = reward and reward.subtype or 0,
		reward_variant = reward and reward.variant or 0,
		route = active and active.route_kind or "",
		entry_slot = active and active.entry_slot,
		exit_slot = active and active.exit_slot,
		path_cost = cost and cost.total or 0,
		pending = pending ~= nil,
		rolls = stats.rolls or 0,
		procs = stats.procs or 0,
	}
end

function item.debug_inspect_room()
	local room = Game():GetRoom()
	local center = room:GetCenterPos()
	local eligible_slots = {}
	for _, entry in ipairs(collect_eligible_doors(center)) do
		eligible_slots[entry.slot] = true
	end
	local doors = {}
	for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
		local allowed = room:IsDoorSlotAllowed(slot)
		local door = allowed and room:GetDoor(slot) or nil
		local is_open = false
		if door then
			local ok = pcall(function()
				is_open = door:IsOpen()
			end)
			if not ok then is_open = false end
		end
		doors[#doors + 1] = {
			slot = slot,
			allowed = allowed and true or false,
			exists = door ~= nil,
			open = is_open and true or false,
			eligible = eligible_slots[slot] == true,
		}
	end
	local forbidden = room_proc_forbidden()
	local route = (not forbidden) and build_traveler_route(debug_route_rng()) or nil
	local reason = "ok"
	if forbidden then
		reason = "forbidden_room"
	elseif #collect_eligible_doors(center) == 0 then
		reason = "no_open_door"
	elseif not route then
		reason = "path_failed"
	end
	return {
		room_type = room:GetType(),
		forbidden = forbidden,
		reason = reason,
		doors = doors,
		route = route,
	}
end

function item.debug_reroll()
	clear_active_traveler()
	return item.debug_force_spawn()
end

item.player_hair_probe = false

function item.debug_set_player_hair(enabled)
	local costume = enums.Costumes and enums.Costumes.TianYi_Hair
	if not costume or costume < 0 then
		return false, "costume_missing"
	end
	item.player_hair_probe = enabled == true
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player and player.Exists and player:Exists() then
			if enabled then
				player:AddNullCostume(costume)
			else
				player:TryRemoveNullCostume(costume)
			end
		end
	end
	return true
end

return item
