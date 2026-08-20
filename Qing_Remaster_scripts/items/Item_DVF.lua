local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")
local grid_door = require("Qing_Remaster_scripts.grids.grid_doors")
local grid_wall = require("Qing_Remaster_scripts.grids.grid_wall")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Shader_holder = require("Qing_Remaster_scripts.others.Shader_holder")
local Nil_holder = require("Qing_Remaster_scripts.others.Nil_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")

local item = {
	ToCall = {},
	pre_ToCall = {},
	pre_myToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.DVF,
	own_key = "Item_DVF_",
	hub_room_variant = 24820,
	hub_backdrop = BackdropType.DARKROOM, -- 16
	foil_anm2 = "gfx/mimics/DVF/DVF.anm2",
	foil_anim = "Idle",
	squash_shader = "Qing_DVF_Squash",
	throw_distance = 140,
	flight_frames = 40,
	countdown_frames = 210, -- 7 秒（30fps 更新）
	squash_wave_frames = 24,
	squash_hold_frames = 8,
	squash_blur_frames = 60,
	wake_hold_frames = 20,
	-- 画面基本清晰后再允许苏醒（black/blur/mosaic 同步淡出）
	wake_clarity = 0.15,
	land_sound = SoundEffect.SOUND_ROCK_CRUMBLE,
	-- 普通房间→hub 重定向（关闭时仍记 catch/leak，便于对照）
	enable_erased_door_redirect = true,
	-- 门/房间诊断日志与 jsonl 采集已关闭（避免 log.txt 刷屏）
	enable_door_log = false,
	enable_room_id_log = false,
	-- 与 Day Dreamer 一致：昏迷/苏醒期间屏蔽移动与射击等
	banish_button = {
		[0] = true, [1] = true, [2] = true, [3] = true,
		[4] = true, [5] = true, [6] = true, [7] = true,
		[8] = true, [9] = true, [10] = true, [11] = true,
	},
	direction_slots = {
		[0] = DoorSlot.LEFT0,
		[1] = DoorSlot.UP0,
		[2] = DoorSlot.RIGHT0,
		[3] = DoorSlot.DOWN0,
	},
	inward_vectors = {
		[0] = Vector(1, 0),
		[1] = Vector(0, 1),
		[2] = Vector(-1, 0),
		[3] = Vector(0, -1),
	},
}

local LOST_CURSE = 1 << 2

-- 倒计时用方形描边字（eid9 偏扁）
local countdown_font = Font()
countdown_font:Load("font/luaminioutlined.fnt")

-- 前向声明：configure_hub / redirect_to_hub 等早于定义处调用
local get_squash, set_squash, begin_hub_reveal, player_in_hub
local append_room_id_log

-- 仅暂停菜单打开时旁路 shader；房间切换时 IsPaused() 也会为 true，绝不能用来关特效
local function menu_paused()
	if REPENTOGON and Game().IsPauseMenuOpen then
		return Game():IsPauseMenuOpen()
	end
	return false
end

local function clear_stale_hub_door_indices(effect)
	if not effect or not effect.routes then return end
	for direction = 0, 3 do
		for _, route in ipairs(effect.routes[direction] or {}) do
			route.hub_grid_index = nil
		end
	end
end

local function reset_hub_wall_cell(room, grid_index)
	local grid = room:GetGridEntity(grid_index)
	if not grid or grid:GetType() ~= GridEntityType.GRID_WALL then return end
	local variant = grid:GetVariant()
	room:RemoveGridEntity(grid_index, 0, false)
	room:SpawnGridEntity(grid_index, GridEntityType.GRID_WALL, variant, 1, 0)
end

local function get_effect()
	local effect = save.elses[item.own_key.."effect"]
	if not effect then return nil end
	-- 续关后数字键/标量偶发仍是字符串；先纠正再比较，避免误清或 hub/抹除全失效
	local hub = tonumber(effect.hub_index)
	if hub then effect.hub_index = hub end
	local dim = tonumber(effect.dimension)
	if dim then effect.dimension = dim end
	local floor_seed = tonumber(effect.floor_seed)
	if floor_seed then effect.floor_seed = floor_seed end
	local function heal_index_map(map)
		if type(map) ~= "table" then return map end
		-- 若 unpack 未展开，残留 {__f=m,k,v}
		if map.__f == "m" then
			return auxi.unpack_from_save(map)
		end
		local moved = {}
		for k, v in pairs(map) do
			if type(k) == "string" then
				local n = tonumber(k)
				if n and n == math.floor(n) and tostring(n) == k then
					moved[#moved + 1] = {n, v, k}
				end
			end
		end
		for i = 1, #moved do
			local n, v, sk = moved[i][1], moved[i][2], moved[i][3]
			if map[n] == nil then map[n] = v end
			map[sk] = nil
		end
		return map
	end
	effect.erased_rooms = heal_index_map(effect.erased_rooms)
	effect.erased_cells = heal_index_map(effect.erased_cells)
	effect.routes = heal_index_map(effect.routes)
	-- 续关加载早期 seed 可能尚未就绪（0）；不要误清 effect
	if effect.floor_seed then
		local seed = Game():GetLevel():GetDungeonPlacementSeed()
		if seed and seed ~= 0 and effect.floor_seed ~= seed then
			if item.enable_room_id_log then
				append_room_id_log("get_effect_seed_clear", {
					note = "floor_seed_mismatch_cleared_effect",
					old_effect_seed = effect.floor_seed,
					new_dungeon_seed = seed,
					old_hub = effect.hub_index,
				})
			end
			save.elses[item.own_key.."effect"] = nil
			return nil
		end
	end
	return effect
end

local function index_flag_true(map, idx)
	if not map or idx == nil then return false end
	if map[idx] then return true end
	local n = tonumber(idx)
	if n ~= nil and map[n] then return true end
	return map[tostring(idx)] == true
end

local function room_is_erased(effect, grid_index)
	if not effect or grid_index == nil then return false end
	if index_flag_true(effect.erased_cells, grid_index) then return true end
	local idx = tonumber(grid_index) or grid_index
	local desc = Game():GetLevel():GetRoomByIdx(idx, effect.dimension)
	return desc and index_flag_true(effect.erased_rooms, desc.SafeGridIndex)
end

-- 门内侧指向房间中心（与 teleport_holder 一致）
local door_inward = {
	[0] = Vector(1, 0),
	[1] = Vector(0, 1),
	[2] = Vector(-1, 0),
	[3] = Vector(0, -1),
}
-- 与 teleport_holder 相同：|pos - (door.Position - inward*18)| < 25
local DOOR_CATCH_DIST = 25
-- 靠近阶段采样半径（只记日志，不拦截）
local DOOR_APPROACH_LOG_DIST = 80
local approach_ring = {}
local APPROACH_RING_MAX = 48

local function json_escape(s)
	return tostring(s):gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("\n", "\\n")
end

local function encode_log_row(tbl)
	local parts = {}
	local keys = {}
	for k in pairs(tbl) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	for _, k in ipairs(keys) do
		local v = tbl[k]
		if type(v) == "number" then
			if v == math.floor(v) and math.abs(v) < 1e12 then
				table.insert(parts, string.format("\"%s\":%d", k, v))
			else
				table.insert(parts, string.format("\"%s\":%.4f", k, v))
			end
		elseif type(v) == "boolean" then
			table.insert(parts, string.format("\"%s\":%s", k, v and "true" or "false"))
		elseif v == nil then
			table.insert(parts, string.format("\"%s\":null", k))
		else
			table.insert(parts, string.format("\"%s\":\"%s\"", k, json_escape(v)))
		end
	end
	return "{"..table.concat(parts, ",").."}"
end

local function ensure_door_log_session()
	if item._door_log_session then return item._door_log_session end
	item._door_log_session = string.format(
		"s%d_%d",
		Isaac.GetFrameCount() or 0,
		Game():GetFrameCount() or 0
	)
	return item._door_log_session
end

local function write_jsonl_line(filename, line, path_cache_key)
	-- 正式运行禁用：不再 DebugString / 写磁盘 jsonl
	return
end

local function append_dvf_door_log(row)
	-- 采集关闭
	return
end

local function keys_csv(t)
	local ks = {}
	for k in pairs(t or {}) do
		ks[#ks + 1] = tostring(k)
	end
	table.sort(ks, function(a, b)
		local na, nb = tonumber(a), tonumber(b)
		if na and nb then return na < nb end
		return a < b
	end)
	return table.concat(ks, ",")
end

local function fill_desc_fields(row, desc, prefix)
	prefix = prefix or ""
	if not desc then
		row[prefix.."missing"] = true
		return
	end
	row[prefix.."safe"] = desc.SafeGridIndex
	row[prefix.."grid"] = desc.GridIndex
	row[prefix.."list"] = desc.ListIndex
	row[prefix.."visited"] = desc.VisitedCount or 0
	row[prefix.."display"] = desc.DisplayFlags or 0
	local data = desc.Data
	if data then
		row[prefix.."type"] = data.Type
		row[prefix.."variant"] = data.Variant
		row[prefix.."subtype"] = data.Subtype
		row[prefix.."name"] = data.Name or ""
		row[prefix.."shape"] = data.Shape
	else
		row[prefix.."data_nil"] = true
	end
end

--- 房间识别快照 → codex_work/logs/dvf_room_id.jsonl
append_room_id_log = function(via, extra)
	if not item.enable_room_id_log then return end
	local level = Game():GetLevel()
	local room = Game():GetRoom()
	local desc = level:GetCurrentRoomDesc()
	local seed = level:GetDungeonPlacementSeed()
	local dim = auxi.GetDimension()
	local raw_effect = save.elses[item.own_key.."effect"]
	local row = {
		event = "room_id",
		via = via or "unknown",
		game_frame = Game():GetFrameCount(),
		isaac_frame = Isaac.GetFrameCount(),
		session = ensure_door_log_session(),
		dungeon_seed = seed or 0,
		dim = dim,
		room_type_api = room and room:GetType() or -1,
		expected_hub_variant = item.hub_room_variant,
		stage = level:GetStage(),
		stage_type = level:GetStageType(),
	}
	fill_desc_fields(row, desc, "cur_")
	if raw_effect then
		row.has_effect = true
		row.effect_seed = raw_effect.floor_seed or 0
		row.effect_dim = raw_effect.dimension
		row.hub_index = raw_effect.hub_index
		row.seed_match = (raw_effect.floor_seed == nil) or (seed == 0) or (raw_effect.floor_seed == seed)
		row.is_hub = desc and raw_effect.hub_index ~= nil and desc.SafeGridIndex == raw_effect.hub_index
		row.is_erased = room_is_erased(raw_effect, desc and desc.SafeGridIndex)
		row.erased_rooms = keys_csv(raw_effect.erased_rooms)
		row.erased_cells = keys_csv(raw_effect.erased_cells)
		row.route_dirs = ""
		do
			local bits = {}
			for d = 0, 3 do
				local n = raw_effect.routes and raw_effect.routes[d] and #raw_effect.routes[d] or 0
				bits[#bits + 1] = tostring(n)
			end
			row.route_counts = table.concat(bits, ",")
		end
		if raw_effect.hub_index and raw_effect.hub_index >= 0 then
			local hub_desc = level:GetRoomByIdx(raw_effect.hub_index, raw_effect.dimension)
			fill_desc_fields(row, hub_desc, "hub_")
			row.hub_variant_ok = hub_desc and hub_desc.Data and hub_desc.Data.Variant == item.hub_room_variant
		end
	else
		row.has_effect = false
	end
	-- 勿再调 get_effect()：seed 不一致时会递归清 effect / 写日志
	if raw_effect then
		local fs = raw_effect.floor_seed
		row.get_effect_ok = (fs == nil) or (seed == 0) or (fs == seed)
	else
		row.get_effect_ok = false
	end
	if extra then
		for k, v in pairs(extra) do row[k] = v end
	end
	-- 分类标签：当前判定路径
	if row.is_hub then
		row.classify = "hub"
	elseif row.is_erased then
		row.classify = "erased"
	elseif row.has_effect and row.get_effect_ok then
		row.classify = "normal_with_effect"
	else
		row.classify = "no_effect_or_other"
	end
	write_jsonl_line("dvf_room_id.jsonl", encode_log_row(row), "_room_id_log_path")
end

local function door_catch_pos(door)
	local inward = door_inward[door.Direction] or Vector(1, 0)
	return door.Position - inward * 18, inward
end

local function sample_door_player(player, door, dist)
	local current = Game():GetLevel():GetCurrentRoomDesc()
	return {
		px = player.Position.X,
		py = player.Position.Y,
		vx = player.Velocity.X,
		vy = player.Velocity.Y,
		vlen = player.Velocity:Length(),
		dx = door.Position.X,
		dy = door.Position.Y,
		dist = dist,
		door_dir = door.Direction,
		slot = door.Slot or -1,
		target = door.TargetRoomIndex,
		from_safe = current and current.SafeGridIndex or -1,
		coll = door.CollisionClass,
		is_open = door:IsOpen() and true or false,
	}
end

local function push_approach_ring(sample)
	if not item.enable_door_log then return end
	table.insert(approach_ring, sample)
	while #approach_ring > APPROACH_RING_MAX do
		table.remove(approach_ring, 1)
	end
end

local function flush_approach_ring_as(event, extra)
	if not item.enable_door_log then
		approach_ring = {}
		return
	end
	extra = extra or {}
	for _, sample in ipairs(approach_ring) do
		local row = {}
		for k, v in pairs(sample) do row[k] = v end
		for k, v in pairs(extra) do row[k] = v end
		row.event = event
		append_dvf_door_log(row)
	end
	approach_ring = {}
end

local function mark_erased_rooms_cleared(erased_rooms, dimension)
	local level = Game():GetLevel()
	for safe_index in pairs(erased_rooms or {}) do
		local desc = level:GetRoomByIdx(safe_index, dimension)
		if desc then
			desc.Clear = true
			if (desc.ClearCount or 0) < 1 then
				desc.ClearCount = 1
			end
		end
	end
end

local ERASED_SECRET_DOOR_TYPES = {
	[RoomType.ROOM_SECRET] = true,
	[RoomType.ROOM_SUPERSECRET] = true,
	[RoomType.ROOM_ULTRASECRET] = true,
}

-- 抹除区边界上通往隐藏/超隐的门：只 SetRoomTypes 换成普通门再 Open，绝不 TryBlowOpen（会播破坏）
function item.open_doors_into_erased()
	local effect = get_effect()
	if not effect then return end
	local level = Game():GetLevel()
	local current = level:GetCurrentRoomDesc()
	if not current or auxi.GetDimension() ~= effect.dimension then return end
	if current.SafeGridIndex == effect.hub_index then return end
	if room_is_erased(effect, current.SafeGridIndex) then return end

	local room = Game():GetRoom()
	local current_type = room:GetType()
	for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
		local door = room:GetDoor(slot)
		if door and room_is_erased(effect, door.TargetRoomIndex) then
			if ERASED_SECRET_DOOR_TYPES[door.TargetRoomType] then
				door:SetRoomTypes(current_type, RoomType.ROOM_DEFAULT)
			end
			if door:IsLocked() then
				door:SetLocked(false)
			end
			if not door:IsOpen() then
				door:Open()
			end
		end
	end
end

function item.hide_erased_rooms(force_refresh)
	local effect = get_effect()
	if not effect then return end
	local level = Game():GetLevel()
	local changed = false

	local function clear_room_state(record_changes)
		for safe_index in pairs(effect.erased_rooms or {}) do
			local desc = level:GetRoomByIdx(safe_index, effect.dimension)
			if desc then
				if record_changes and (desc.DisplayFlags ~= 0 or desc.VisitedCount ~= 0) then changed = true end
				desc.DisplayFlags = 0
				desc.VisitedCount = 0
			end
		end

		if effect.hub_index and effect.hub_index >= 0 then
			local hub_desc = level:GetRoomByIdx(effect.hub_index, effect.dimension)
			if hub_desc then
				if record_changes and (hub_desc.DisplayFlags ~= 0 or hub_desc.VisitedCount ~= 0) then changed = true end
				hub_desc.DisplayFlags = 0
				hub_desc.VisitedCount = 0
			end
		end
	end

	clear_room_state(true)
	if changed or force_refresh then
		-- 续关 PRE_GAME_STARTED 时关卡未就绪，UpdateVisibility 会直接崩
		local ok = pcall(function() level:UpdateVisibility() end)
		if not ok then return end
		clear_room_state(false)
		if REPENTOGON and Minimap and Minimap.Refresh then
			pcall(function() Minimap.Refresh() end)
		end
	end
end

function item.set_hub_map_hidden(hidden)
	local effect = get_effect()
	if not effect then return end
	local level = Game():GetLevel()
	if hidden then
		if level:GetCurses() & LOST_CURSE ~= LOST_CURSE then
			level:AddCurse(LOST_CURSE, false)
			effect.added_lost_curse = true
		end
	elseif effect.added_lost_curse then
		effect.added_lost_curse = nil
		level:RemoveCurses(LOST_CURSE)
	end
end

local function get_hub_room_config()
	if not REPENTOGON then return nil end
	local holder = rawget(_G, "RoomConfig") or rawget(_G, "RoomConfigHolder")
	if not holder or not holder.GetRoomByStageTypeAndVariant then return nil end
	local mode = Game():IsGreedMode() and 1 or 0
	local success, room_config = pcall(
		holder.GetRoomByStageTypeAndVariant,
		StbType.SPECIAL_ROOMS,
		RoomType.ROOM_DEFAULT,
		item.hub_room_variant,
		mode
	)
	if success then return room_config end
	return nil
end

function item.create_hub_room(dimension)
	local level = Game():GetLevel()
	local room_config = get_hub_room_config()
	if room_config and level.TryPlaceRoom then
		local seed = level:GetDungeonPlacementSeed()
		for grid_index = 0, 168 do
			local desc = level:GetRoomByIdx(grid_index, dimension)
			if desc and desc.Data == nil then
				local success, placed = pcall(function()
					return level:TryPlaceRoom(
						room_config,
						grid_index,
						dimension,
						seed + grid_index,
						true,
						true,
						true
					)
				end)
				if success and placed then return placed.SafeGridIndex, true end
			end
		end
	end

	local hub_index = Room_holder.Allocate_with()
	if hub_index and hub_index >= 0 then
		return hub_index, false
	end
	return nil, false
end

function item.queue_hub_room_replacement(hub_index, dimension)
	Room_holder.Try_replace_with(hub_index, dimension, {
		data = function()
			local room_config = get_hub_room_config()
			if room_config then return room_config end

			-- Non-REPENTOGON compatibility: obtain the registered room through
			-- the vanilla debug-room descriptor when RoomConfig is unavailable.
			Isaac.ExecuteCommand("goto s.default."..tostring(item.hub_room_variant))
			local debug_desc = Game():GetLevel():GetRoomByIdx(-3)
			return debug_desc and debug_desc.Data
		end,
	})
end

function item.record_hub_entry(source_slot, source_index, erased_index)
	local effect = get_effect()
	if not effect or type(source_slot) ~= "number" or source_slot < 0 then return end
	local source_direction = source_slot % 4
	local entry_direction = (source_direction + 2) % 4
	effect.hub_entry = {
		direction = entry_direction,
		source_index = source_index,
		erased_index = erased_index,
	}
end

function item.position_players_at_hub_center()
	local room = Game():GetRoom()
	local center = room:GetCenterPos()
	local player_count = Game():GetNumPlayers()
	for player_index = 0, player_count - 1 do
		local player = Game():GetPlayer(player_index)
		local offset = (player_index - (player_count - 1) * 0.5) * 18
		player.Position = room:GetClampedPosition(center + Vector(offset, 0), 20)
		player.Velocity = Vector.Zero
	end
end

function item.position_players_at_hub_entry()
	local effect = get_effect()
	if not effect or not effect.hub_entry then return end
	local room = Game():GetRoom()
	local entry = effect.hub_entry
	local direction = entry.direction
	local inward = item.inward_vectors[direction]
	local tangent = Vector(-inward.Y, inward.X)
	local player_count = Game():GetNumPlayers()
	local base_position

	for _, route in ipairs(effect.routes[direction] or {}) do
		if route.hub_grid_index and
			(entry.source_index == nil or route.target == entry.source_index) and
			(entry.erased_index == nil or route.source == entry.erased_index) then
			-- 与 grid_doors 精灵 Offset(mov=15) 同轴：站在门内侧，勿用 GetClampedPosition
			-- （margin 会把人从非标准门槽墙位掰开，造成与门错位）
			base_position = room:GetGridPosition(route.hub_grid_index) + inward * 40
			break
		end
	end
	if not base_position then
		local slot = item.direction_slots[direction]
		base_position = room:GetDoorSlotPosition(slot) + inward * 45
	end

	for player_index = 0, player_count - 1 do
		local player = Game():GetPlayer(player_index)
		local offset = (player_index - (player_count - 1) * 0.5) * 18
		player.Position = base_position + tangent * offset
		player.Velocity = Vector.Zero
	end
	-- 勿在此处清 hub_entry：On_Arrive / POST_NEW_ROOM 可能各跑一次 configure_hub，
	-- 清早了第二次只会重铺门、不再摆人，玩家停在默认门槽而门在 floor 分布墙位上。
end

local function build_region(center_index)
	local region = {}
	local center_x = center_index % 13
	local center_y = math.floor(center_index / 13)
	for y = center_y - 1, center_y + 1 do
		for x = center_x - 1, center_x + 1 do
			if x >= 0 and x < 13 and y >= 0 and y < 13 then
				region[x + y * 13] = true
			end
		end
	end
	return region
end

local function collect_erased_rooms(center_index, dimension)
	local level = Game():GetLevel()
	local rooms = level:GetRooms()
	local region = build_region(center_index)
	local erased_rooms = {}
	local erased_cells = {}
	local seen = {}

	for i = 0, rooms.Size - 1 do
		local desc = rooms:Get(i)
		if desc and desc.Data and desc.SafeGridIndex >= 0 and
			auxi.GetDimension(desc) == dimension and not seen[desc.SafeGridIndex] then
			seen[desc.SafeGridIndex] = true
			local occupied = auxi.get_all_gridindexs(desc)
			local intersects = false
			for _, grid_index in pairs(occupied) do
				if region[grid_index] then
					intersects = true
					break
				end
			end
			if intersects then
				erased_rooms[desc.SafeGridIndex] = true
				for _, grid_index in pairs(occupied) do
					erased_cells[grid_index] = true
				end
			end
		end
	end

	return erased_rooms, erased_cells
end

-- 同侧多门时，按目标房在地图上的方位排序，与墙格从左→右 / 上→下一致
local function sort_routes_along_wall(routes, direction)
	table.sort(routes, function(a, b)
		local ax, ay = a.target % 13, math.floor(a.target / 13)
		local bx, by = b.target % 13, math.floor(b.target / 13)
		if direction == 0 or direction == 2 then
			-- 左右墙：上→下
			if ay ~= by then return ay < by end
			return ax < bx
		end
		-- 上下墙：左→右
		if ax ~= bx then return ax < bx end
		return ay < by
	end)
end

local function collect_boundary_routes(erased_rooms, erased_cells, dimension)
	local level = Game():GetLevel()
	local routes = {[0] = {}, [1] = {}, [2] = {}, [3] = {}}
	local seen = {}

	for safe_index in pairs(erased_rooms) do
		local desc = level:GetRoomByIdx(safe_index, dimension)
		if desc and desc.Data then
			for door_slot, offset in pairs(auxi.get_moves_in_gridroom(desc.Data.Shape)) do
				if desc.Data.Doors & (1 << door_slot) ~= 0 then
					local target_index = safe_index + offset
					local direction = door_slot % 4
					if target_index >= 0 and target_index <= 168 and not erased_cells[target_index] then
						local target_desc = level:GetRoomByIdx(target_index, dimension)
						if target_desc and target_desc.Data and not erased_rooms[target_desc.SafeGridIndex] then
							local route_key = table.concat({
								tostring(safe_index),
								tostring(door_slot),
								tostring(target_desc.SafeGridIndex),
							}, ":")
							if not seen[route_key] then
								seen[route_key] = true
								table.insert(routes[direction], {
									source = safe_index,
									target = target_desc.SafeGridIndex,
									direction = direction,
									leave_slot = door_slot,
									room_type = target_desc.Data.Type,
								})
							end
						end
					end
				end
			end
		end
	end

	-- pairs 遍历无序；不排序会出现「左下门进右下房」
	for direction = 0, 3 do
		sort_routes_along_wall(routes[direction], direction)
	end

	return routes
end

local function collect_hub_wall_positions(room)
	local width = room:GetGridWidth()
	local inward_steps = {
		[0] = 1,
		[1] = width,
		[2] = -1,
		[3] = -width,
	}
	local positions = {[0] = {}, [1] = {}, [2] = {}, [3] = {}}

	for grid_index = 0, room:GetGridSize() - 1 do
		local grid = room:GetGridEntity(grid_index)
		if grid and grid:GetType() == GridEntityType.GRID_WALL and
			not room:IsPositionInRoom(room:GetGridPosition(grid_index), 0) then
			for direction = 0, 3 do
				local inner_index = grid_index + inward_steps[direction]
				if inner_index >= 0 and inner_index < room:GetGridSize() and
					room:IsPositionInRoom(room:GetGridPosition(inner_index), 0) then
					table.insert(positions[direction], grid_index)
					break
				end
			end
		end
	end

	for direction = 0, 3 do table.sort(positions[direction]) end
	return positions
end

local function erased_final_boss(erased_rooms, dimension)
	local level = Game():GetLevel()
	local rooms = level:GetRooms()
	local list_index = level:GetLastBossRoomListIndex()
	if list_index == nil or list_index < 0 then return false end
	local desc = rooms:Get(list_index)
	return desc and auxi.GetDimension(desc) == dimension and
		erased_rooms[desc.SafeGridIndex] == true
end

function item.configure_hub()
	local effect = get_effect()
	if not effect then
		append_room_id_log("configure_hub_skip", {note = "no_effect"})
		return
	end
	local level = Game():GetLevel()
	local desc = level:GetCurrentRoomDesc()
	if not desc then
		append_room_id_log("configure_hub_skip", {note = "no_desc"})
		return
	end
	if auxi.GetDimension() ~= effect.dimension or desc.SafeGridIndex ~= effect.hub_index then
		append_room_id_log("configure_hub_skip", {
			note = "not_in_hub",
			want_hub = effect.hub_index,
			got_safe = desc.SafeGridIndex,
			want_dim = effect.dimension,
			got_dim = auxi.GetDimension(),
		})
		return
	end
	append_room_id_log("configure_hub_enter", {note = "configuring"})

	local room = Game():GetRoom()
	grid_wall.ChangeBackdrop(item.hub_backdrop)

	-- 同逻辑帧只铺门一次（On_Arrive 与 POST_NEW_ROOM 常双触）；跨帧重进仍要重铺
	local doors_ready = effect.hub_configure_frame == Game():GetFrameCount()
	if not doors_ready then
		effect.hub_configure_frame = Game():GetFrameCount()
		local stale_indices = {}
		for direction = 0, 3 do
			for _, route in ipairs(effect.routes[direction] or {}) do
				if route.hub_grid_index then
					stale_indices[route.hub_grid_index] = true
					route.hub_grid_index = nil
				end
			end
		end
		for i = #grid_door.doors, 1, -1 do
			local door_info = grid_door.doors[i]
			if door_info.safe_grid_index == effect.hub_index then
				stale_indices[door_info.idx] = true
				table.remove(grid_door.doors, i)
			end
		end
		for grid_index in pairs(stale_indices) do
			reset_hub_wall_cell(room, grid_index)
		end
		if next(stale_indices) then
			room:Update()
		end

		local wall_positions = collect_hub_wall_positions(room)
		for direction = 0, 3 do
			local routes = effect.routes[direction] or {}
			sort_routes_along_wall(routes, direction)
			local positions = wall_positions[direction]
			for route_index, route in ipairs(routes) do
				if #positions == 0 then break end
				-- 墙格已按 grid_index 排序（左→右 / 上→下）；routes 已按目标房地图坐标同序
				local position_index = math.floor(route_index * (#positions + 1) / (#routes + 1))
				position_index = math.max(1, math.min(#positions, position_index))
				local grid_index = positions[position_index]
				route.hub_grid_index = grid_index
				local target_index = route.target
				local door_direction = direction
				grid_door.try_spawn_grid_door(room, nil, grid_index, {
					check_and_leave = function(_, player)
						-- hub→普通：MAZE + hub 门朝向；目标由 route 决定（同侧多门已按地图坐标排序）
						Room_holder.Trans_to(
							target_index,
							door_direction,
							RoomTransitionAnim.MAZE,
							player,
							effect.dimension
						)
					end,
					should_update = true,
					playname = "Opened",
					dir = door_direction,
					refer_slot = item.direction_slots[door_direction],
					tp = route.room_type,
				})
			end
		end
	end

	local squash = get_squash()
	if squash and (squash.phase == "hold" or squash.phase == "travel"
		or squash.phase == "blur" or squash.phase == "wake") then
		item.position_players_at_hub_center()
		effect.hub_entry = nil
	elseif effect.hub_entry then
		item.position_players_at_hub_entry()
		effect.hub_entry = nil
	end

	if effect.final_boss_erased then
		local center_index = room:GetGridIndex(room:GetCenterPos())
		local grid = room:GetGridEntity(center_index)
		if not grid or grid:GetType() ~= GridEntityType.GRID_TRAPDOOR then
			if grid then room:RemoveGridEntity(center_index, 0, false) end
			room:SpawnGridEntity(center_index, GridEntityType.GRID_TRAPDOOR, 0, 1, 0)
		end
	end
end

function item.redirect_to_hub(player, force)
	local effect = get_effect()
	if not effect or effect.hub_index == nil or effect.hub_index < 0 then return end
	if not force and item.redirect_frame == Game():GetFrameCount() then return end
	item.redirect_frame = Game():GetFrameCount()
	-- 普通房间→hub：只用无方向 FADE，避免与原版进门叠成带方向滑过抹除区
	Room_holder.Trans_to(
		effect.hub_index,
		Direction.NO_DIRECTION,
		RoomTransitionAnim.FADE,
		player or Game():GetPlayer(0),
		effect.dimension,
		{On_Arrive = function()
			item.configure_hub()
			local squash = get_squash()
			if squash and (squash.phase == "travel" or squash.phase == "hold" or squash.phase == "blur") then
				-- force：进房当帧重新钉昏迷，避免切换期间半截状态
				begin_hub_reveal(squash, true)
			end
		end}
	)
end

-- 拉回 + 挡碰撞 + FADE 进 hub
local function intercept_door_to_erased(player, door, via, dist)
	local effect = get_effect()
	if not effect or not player or not door then return false end
	if auxi.GetDimension() ~= effect.dimension then return false end
	if not room_is_erased(effect, door.TargetRoomIndex) then return false end
	if item.redirect_frame == Game():GetFrameCount() then return false end

	local level = Game():GetLevel()
	local current = level:GetCurrentRoomDesc()
	local target_desc = level:GetRoomByIdx(door.TargetRoomIndex, effect.dimension)
	local sample = sample_door_player(player, door, dist or -1)
	sample.event = "catch"
	sample.via = via or "unknown"
	sample.target_safe = target_desc and target_desc.SafeGridIndex or -1
	sample.hub = effect.hub_index
	append_dvf_door_log(sample)
	approach_ring = {}

	if not item.enable_erased_door_redirect then
		return false
	end

	item.record_hub_entry(
		door.Direction,
		current and current.SafeGridIndex,
		target_desc and target_desc.SafeGridIndex or door.TargetRoomIndex
	)

	local inward = door_inward[door.Direction] or Vector(1, 0)
	player.Position = door.Position + inward * 28
	player.Velocity = Vector.Zero
	door.CollisionClass = GridCollisionClass.COLLISION_WALL
	append_dvf_door_log({
		event = "redirect_hub",
		via = via or "unknown",
		door_dir = door.Direction,
		from_safe = current and current.SafeGridIndex or -1,
		target_safe = target_desc and target_desc.SafeGridIndex or door.TargetRoomIndex,
		hub = effect.hub_index,
		anim = "FADE",
	})
	item.redirect_to_hub(player, true)
	return false
end

-- 在玩家更新帧检测（玩家约 2× 逻辑帧）；距离公式与 teleport_holder 一致
local function check_erased_doors_on_player_update(player)
	if not player or player:IsDead() then return end
	if get_squash() then return end
	if player:GetData()[item.own_key.."wake"] then return end
	local effect = get_effect()
	if not effect or auxi.GetDimension() ~= effect.dimension then return end
	if item.redirect_frame == Game():GetFrameCount() then return end
	local room = Game():GetRoom()
	for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
		local door = room:GetDoor(slot)
		if door and door:IsOpen() and room_is_erased(effect, door.TargetRoomIndex) then
			local catch_pos = door_catch_pos(door)
			local dist = (player.Position - catch_pos):Length()
			if item.enable_door_log and dist < DOOR_APPROACH_LOG_DIST then
				local sample = sample_door_player(player, door, dist)
				sample.hub = effect.hub_index
				push_approach_ring(sample)
				local row = {}
				for k, v in pairs(sample) do row[k] = v end
				row.event = "approach"
				row.via = "pre_player_update"
				append_dvf_door_log(row)
			end
			if dist < DOOR_CATCH_DIST then
				intercept_door_to_erased(player, door, "pre_player_update", dist)
				return
			end
		end
	end
end

function item.erase_space(position)
	local level = Game():GetLevel()
	local dimension = auxi.GetDimension()
	local center_index = auxi.pos2safegridindex(position)
	if center_index < 0 or center_index > 168 then return false end

	local erased_rooms, erased_cells = collect_erased_rooms(center_index, dimension)
	if next(erased_rooms) == nil then return false end

	local hub_index, clean_placement = item.create_hub_room(dimension)
	if hub_index == nil or hub_index < 0 then return false end

	local effect = {
		center_index = center_index,
		dimension = dimension,
		floor_seed = level:GetDungeonPlacementSeed(),
		erased_rooms = erased_rooms,
		erased_cells = erased_cells,
		routes = collect_boundary_routes(erased_rooms, erased_cells, dimension),
		hub_index = hub_index,
		clean_placement = clean_placement,
		final_boss_erased = erased_final_boss(erased_rooms, dimension),
	}
	save.elses[item.own_key.."effect"] = effect

	mark_erased_rooms_cleared(erased_rooms, dimension)
	item.hide_erased_rooms(true)
	item.open_doors_into_erased()
	if not clean_placement then
		item.queue_hub_room_replacement(hub_index, dimension)
	end
	return true
end

function item.clear_floor_effect()
	local effect = save.elses[item.own_key.."effect"]
	if effect and effect.added_lost_curse then
		Game():GetLevel():RemoveCurses(LOST_CURSE)
	end
	save.elses[item.own_key.."effect"] = nil
	save.elses[item.own_key.."pending"] = nil
	save.elses[item.own_key.."squash"] = nil
	item.redirect_frame = nil
	item.squash = nil
	item.foil_ent = nil
	if Shader_holder and Shader_holder.torsion_info then
		Shader_holder.torsion_info = {}
	end
	for player_num = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(player_num)
		local d = player:GetData()
		d[item.own_key.."holding"] = nil
		if d[item.own_key.."wake"] then
			d[item.own_key.."wake"] = nil
			player:StopExtraAnimation()
		end
	end
end

local function get_pending()
	local pending = save.elses[item.own_key.."pending"]
	if pending and pending.center_index and not pending.region then
		pending.region = build_region(pending.center_index)
	end
	return pending
end

get_squash = function()
	if item.squash then return item.squash end
	item.squash = save.elses[item.own_key.."squash"]
	return item.squash
end

set_squash = function(state)
	item.squash = state
	save.elses[item.own_key.."squash"] = state
end

local function clear_pending()
	save.elses[item.own_key.."pending"] = nil
	if item.foil_ent and item.foil_ent:Exists() then
		item.foil_ent:Remove()
	end
	item.foil_ent = nil
end

-- 与 Squiresaga / Shader_holder 完全同一套：
-- TexCoord = WorldToScreen / (check_screen_multi(1,1) * 256)
-- 绝不能用 / GetScreenSize()：多数分辨率下会得到 >1 的假 UV，再被出屏逻辑钳到右下角。
local function shader_screen_metrics()
	local size = auxi.GetScreenSize()
	local mult = auxi.check_screen_multi(Vector(1, 1)) * 256
	local max_u = size.X / math.max(1e-4, mult.X)
	local max_v = size.Y / math.max(1e-4, mult.Y)
	return {
		size = size,
		mult = mult,
		max_u = max_u,
		max_v = max_v,
		center_u = max_u * 0.5,
		center_v = max_v * 0.5,
		reach = math.sqrt(max_u * max_u + max_v * max_v) * 1.15,
	}
end

local function world_to_shader_uv(world_pos)
	local screen = Isaac.WorldToScreen(world_pos)
	local m = shader_screen_metrics()
	local u = screen.X / m.mult.X
	local v = screen.Y / m.mult.Y
	if Game():GetRoom():IsMirrorWorld() then
		-- 对齐 Shader_holder：sz 收束到 ≤256 后再 /256
		local sz = m.size.X
		while sz > 256 do sz = sz / 2 end
		u = (sz / 256) - u
	end
	return u, v, m
end

-- 箔片在屏上 → 实时 UV；出屏 → 地图相对方向对应的屏幕边缘
local function resolve_crush_center_uv(squash)
	local m = shader_screen_metrics()
	if not squash then return m.center_u, m.center_v, m end

	local land = Vector(squash.land_x or 0, squash.land_y or 0)
	local u, v = world_to_shader_uv(land)
	local current = Game():GetLevel():GetCurrentRoomDesc()
	local same_room = current
		and squash.source_room
		and current.SafeGridIndex == squash.source_room
		and auxi.GetDimension() == (squash.dimension or auxi.GetDimension())
	local margin = 0.02
	local on_screen = u >= -margin and u <= m.max_u + margin
		and v >= -margin and v <= m.max_v + margin

	if same_room and on_screen then
		squash.cu, squash.cv = u, v
		return u, v, m
	end

	local foil_idx = squash.center_index
	if foil_idx == nil then
		foil_idx = auxi.pos2safegridindex(land)
		squash.center_index = foil_idx
	end
	local cur_idx = current and current.SafeGridIndex or foil_idx or 0
	local fx = foil_idx % 13
	local fy = math.floor(foil_idx / 13)
	local cx = cur_idx % 13
	local cy = math.floor(cur_idx / 13)
	local dx = fx - cx
	local dy = fy - cy

	if same_room then
		local du = u - m.center_u
		local dv = v - m.center_v
		local adu, adv = math.abs(du), math.abs(dv)
		if adu < 1e-4 and adv < 1e-4 then
			u, v = m.center_u, 0
		else
			local scale_u = adu > 1e-4 and (m.center_u / adu) or 1e9
			local scale_v = adv > 1e-4 and (m.center_v / adv) or 1e9
			local scale = math.min(scale_u, scale_v)
			u = m.center_u + du * scale
			v = m.center_v + dv * scale
		end
	elseif math.abs(dx) > math.abs(dy) then
		u = dx > 0 and m.max_u or 0
		v = m.center_v
	elseif math.abs(dy) > 0 then
		u = m.center_u
		v = dy > 0 and m.max_v or 0
	else
		u = math.max(0, math.min(m.max_u, u))
		v = math.max(0, math.min(m.max_v, v))
	end
	u = math.max(0, math.min(m.max_u, u))
	v = math.max(0, math.min(m.max_v, v))
	squash.cu, squash.cv = u, v
	return u, v, m
end

local function keep_foil_alive(foil)
	if not foil or not foil:Exists() then return end
	local data = foil:GetData()
	-- Nil_holder 默认 removecd=60 会清掉 MeusNil；箔片需长驻到倒计时结束
	if (data.removecd or 0) < 500000 then
		data.removecd = 999999
	end
end

local function spawn_foil_visual(pos)
	local foil = Isaac.Spawn(EntityType.ENTITY_EFFECT, enums.Entities.ID_EFFECT_MeusNIL, 0, pos, Vector.Zero, nil)
	foil:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
	foil.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	foil.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	local sprite = foil:GetSprite()
	sprite:Load(item.foil_anm2, true)
	sprite:Play(item.foil_anim, true)
	sprite.Rotation = 0
	local data = foil:GetData()
	data[item.own_key.."foil"] = true
	data.nil_mode = "visual_only"
	data.skip_nil_distance_cull = true
	-- 跳过 Nil_holder 运动段（箔片只靠自己的 UPDATE 位移）
	data[Nil_holder.own_key.."work"] = function() return true end
	keep_foil_alive(foil)
	item.foil_ent = foil
	return foil
end

local function ease_out_cubic(t)
	local u = 1 - t
	return 1 - u * u * u
end

local function throw_foil(player, direction)
	direction = direction:Normalized()
	local room = Game():GetRoom()
	local start = player.Position
	local target = room:GetClampedPosition(start + direction * item.throw_distance, 24)
	local foil = spawn_foil_visual(start)
	local data = foil:GetData()
	-- 用逻辑帧计时，避免 effect 双更导致飞行忽快忽慢/发卡
	data[item.own_key.."fly"] = {
		start = Vector(start.X, start.Y),
		target = Vector(target.X, target.Y),
		start_frame = Game():GetFrameCount(),
		max = item.flight_frames,
		angle = direction:GetAngleDegrees(),
		spin = 14,
	}
	foil:GetSprite().Rotation = data[item.own_key.."fly"].angle
	return foil
end

local function arm_pending(land_pos)
	local center_index = auxi.pos2safegridindex(land_pos)
	local dimension = auxi.GetDimension()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	save.elses[item.own_key.."pending"] = {
		land_x = land_pos.X,
		land_y = land_pos.Y,
		center_index = center_index,
		dimension = dimension,
		source_room = desc and desc.SafeGridIndex or -1,
		timer = item.countdown_frames,
		timer_max = item.countdown_frames,
		ticking = false, -- 落地当帧先显示 7:000，下一帧再开始扣
		region = build_region(center_index),
	}
end

local function player_in_danger_region()
	local pending = get_pending()
	if not pending or not pending.region then return false end
	if auxi.GetDimension() ~= pending.dimension then return false end
	local current = Game():GetLevel():GetCurrentRoomDesc()
	if not current then return false end
	local occupied = auxi.get_all_gridindexs(current)
	for _, grid_index in pairs(occupied) do
		if pending.region[grid_index] then return true end
	end
	return pending.region[current.SafeGridIndex] == true or pending.region[current.GridIndex] == true
end

local function finish_safe_erase(land_pos)
	clear_pending()
	if not item.erase_space(land_pos) then return end
	local effect = get_effect()
	if not effect then return end
	local current = Game():GetLevel():GetCurrentRoomDesc()
	if current and room_is_erased(effect, current.SafeGridIndex) then
		item.redirect_to_hub(Game():GetPlayer(0), true)
	end
end

local function finish_caught_squash(land_pos)
	local pending = get_pending()
	local source_room = pending and pending.source_room
	local dimension = pending and pending.dimension or auxi.GetDimension()
	clear_pending()
	if not item.erase_space(land_pos) then return end
	local effect = get_effect()
	if not effect then return end
	item.record_hub_entry(
		Game():GetLevel().LeaveDoor,
		Game():GetLevel():GetCurrentRoomDesc().SafeGridIndex,
		source_room
	)
	local center_index = pending and pending.center_index or auxi.pos2safegridindex(land_pos)
	set_squash({
		phase = "crush",
		frames = 0,
		crush = 1,
		wave = 0,
		blur = 0,
		mosaic = 0,
		black = 0,
		land_x = land_pos.X,
		land_y = land_pos.Y,
		center_index = center_index,
		source_room = source_room,
		dimension = dimension,
	})
	Game():ShakeScreen(20)
	Game():MakeShockwave(land_pos, 0.12, 0.05, 30)
	Game():Darken(0.6, 20)
end

local function resolve_countdown()
	local pending = get_pending()
	if not pending then return end
	local land_pos = Vector(pending.land_x, pending.land_y)
	if player_in_danger_region() then
		finish_caught_squash(land_pos)
	else
		finish_safe_erase(land_pos)
	end
end

local function clear_distort_shaders()
	if Shader_holder and Shader_holder.torsion_info then
		Shader_holder.torsion_info = {}
	end
end

player_in_hub = function()
	local effect = get_effect()
	if not effect or effect.hub_index == nil then return false end
	if auxi.GetDimension() ~= effect.dimension then return false end
	local current = Game():GetLevel():GetCurrentRoomDesc()
	return current and current.SafeGridIndex == effect.hub_index
end

-- 仅在 POST_NEW_ROOM / On_Arrive 确认进 hub 后开始：黑屏淡出 + 昏迷钉帧
-- 苏醒动画对齐 Day Dreamer effect / effect2（DeathTeleport 钉末 → 倒放 → AnimateSad）
begin_hub_reveal = function(squash, force)
	if not squash then return end
	if not player_in_hub() then return end
	if squash.reveal_started and not force then return end
	squash.reveal_started = true
	clear_distort_shaders()
	item.position_players_at_hub_center()
	squash.phase = "blur"
	squash.frames = 0
	squash.crush = 0
	squash.wave = 0
	squash.blur = 1
	squash.mosaic = 1
	squash.black = 1
	-- 渲染时钟从进房揭幕当帧起算；房间切换期间绝不能提前开始
	squash.blur_t0 = Isaac.GetFrameCount()
	squash.blur_pause_mark = nil
	for player_num = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(player_num)
		local d = player:GetData()
		player.Velocity = Vector.Zero
		player:PlayExtraAnimation("DeathTeleport")
		local s = player:GetSprite()
		s:SetLastFrame()
		local max_fr = math.max(0, s:GetFrame())
		-- waking=false：昏迷钉末帧；ready 由黑屏淡出置位后再倒放
		d[item.own_key.."wake"] = {
			waking = false,
			ready = false,
			held = 0,
			max_fr = max_fr,
			c1 = max_fr,
		}
		if max_fr > 0 then
			s:SetFrame("DeathTeleport", max_fr)
		end
	end
	save.elses[item.own_key.."squash"] = squash
end

-- 倒放至帧 0 后直接停 Extra，不再 AnimateSad
local function finish_player_wake(player)
	local d = player:GetData()
	if not d[item.own_key.."wake"] then return end
	d[item.own_key.."wake"] = nil
	local s = player:GetSprite()
	s:SetFrame("DeathTeleport", 0)
	player:StopExtraAnimation()
end

local function start_wake_playing()
	for player_num = 0, Game():GetNumPlayers() - 1 do
		local wake = Game():GetPlayer(player_num):GetData()[item.own_key.."wake"]
		if wake and not wake.waking then
			wake.ready = true
		end
	end
end

local function any_player_waking()
	for player_num = 0, Game():GetNumPlayers() - 1 do
		if Game():GetPlayer(player_num):GetData()[item.own_key.."wake"] then
			return true
		end
	end
	return false
end

local function clear_all_player_wake()
	for player_num = 0, Game():GetNumPlayers() - 1 do
		finish_player_wake(Game():GetPlayer(player_num))
	end
end

-- 渲染帧时长：约 60fps 下对应 ~2s（blur_frames 按 30fps 更新帧语义 ×2）
local function blur_duration_render_frames()
	return math.max(1, item.squash_blur_frames * 2)
end

local function sync_blur_from_clock(squash)
	if not squash or squash.phase ~= "blur" then return end
	-- 只有真正打开暂停菜单才冻结淡出时钟；房间切换的 IsPaused 必须继续保持黑幕参数
	if menu_paused() then
		squash.blur_pause_mark = squash.blur_pause_mark or Isaac.GetFrameCount()
		return
	end
	if squash.blur_pause_mark then
		local paused_for = Isaac.GetFrameCount() - squash.blur_pause_mark
		squash.blur_t0 = (squash.blur_t0 or Isaac.GetFrameCount()) + paused_for
		squash.blur_pause_mark = nil
	end
	local t0 = squash.blur_t0 or Isaac.GetFrameCount()
	local elapsed = math.max(0, Isaac.GetFrameCount() - t0)
	local dur = blur_duration_render_frames()
	local t = math.min(1, elapsed / dur)
	local fade = 1 - t
	squash.frames = elapsed
	squash.crush = 0
	squash.wave = 0
	squash.blur = fade
	-- 马赛克更快消退，减少大格块感；黑幕与模糊同步
	squash.mosaic = fade * fade
	squash.black = fade
	-- 画面大致清楚后再允许苏醒；玩家侧仍需钉住 held 帧
	if fade <= item.wake_clarity then
		start_wake_playing()
	end
	if t >= 1 then
		squash.blur = 0
		squash.mosaic = 0
		squash.black = 0
		start_wake_playing()
		if any_player_waking() then
			squash.phase = "wake"
			squash.frames = 0
		else
			set_squash(nil)
			return
		end
	end
	save.elses[item.own_key.."squash"] = squash
end

local function update_squash()
	local squash = get_squash()
	if not squash then return end
	-- 菜单暂停才停逻辑；房间切换期间 POST_UPDATE 本来就不会跑
	if menu_paused() then return end

	local _, _, m = resolve_crush_center_uv(squash)
	local reach = m.reach

	if squash.phase == "crush" then
		squash.frames = (squash.frames or 0) + 1
		local t = math.min(1, squash.frames / item.squash_wave_frames)
		squash.crush = 1
		squash.wave = t * reach
		squash.blur = 0
		squash.mosaic = 0
		squash.black = 0
		if squash.frames % 4 == 0 then
			local land = Vector(squash.land_x, squash.land_y)
			Game():MakeShockwave(land, 0.04 + t * 0.08, 0.03 + t * 0.04, 10)
			Game():ShakeScreen(math.floor(4 + t * 10))
		end
		if t >= 1 then
			-- 压扁完成后保持纯黑，直至 POST_NEW_ROOM 确认进 hub
			squash.phase = "hold"
			squash.frames = 0
			squash.wave = reach
			squash.crush = 1
			squash.black = 1
			clear_distort_shaders()
		end
	elseif squash.phase == "hold" then
		squash.frames = (squash.frames or 0) + 1
		squash.crush = 1
		squash.wave = reach
		squash.blur = 0
		squash.mosaic = 0
		squash.black = 1
		if squash.frames >= item.squash_hold_frames then
			squash.phase = "travel"
			squash.frames = 0
			item.redirect_to_hub(Game():GetPlayer(0), true)
		end
	elseif squash.phase == "travel" then
		squash.frames = (squash.frames or 0) + 1
		squash.crush = 1
		squash.wave = reach
		squash.blur = 0
		squash.mosaic = 0
		squash.black = 1
		-- 揭幕只在 POST_NEW_ROOM / On_Arrive；此处仅保持黑幕并在未进房时重试传送
		if not player_in_hub() and squash.frames > 0 and squash.frames % 45 == 0 then
			item.redirect_to_hub(Game():GetPlayer(0), true)
		end
	elseif squash.phase == "blur" then
		sync_blur_from_clock(squash)
	elseif squash.phase == "wake" then
		squash.crush = 0
		squash.wave = 0
		squash.blur = 0
		squash.mosaic = 0
		squash.black = 0
		if not any_player_waking() then
			set_squash(nil)
			return
		end
	else
		clear_all_player_wake()
		set_squash(nil)
		return
	end
	if get_squash() then
		save.elses[item.own_key.."squash"] = squash
	end
end

local function update_pending_distort(pending)
	local urgency = 1 - (pending.timer / math.max(1, pending.timer_max))
	local land = Vector(pending.land_x, pending.land_y)
	local current = Game():GetLevel():GetCurrentRoomDesc()
	local in_source = current
		and auxi.GetDimension() == pending.dimension
		and current.SafeGridIndex == pending.source_room
	local frame = Game():GetFrameCount()

	if in_source then
		local interval = math.max(3, math.floor(16 - urgency * 13))
		if frame % interval == 0 then
			local offset = auxi.random_r() * (12 + urgency * 55)
			Game():MakeShockwave(
				land + offset,
				0.012 + urgency * 0.07,
				0.012 + urgency * 0.045,
				5 + math.floor(urgency * 28)
			)
			Shader_holder.Add_torsion({
				id = auxi.random_0(),
				pos = Isaac.WorldToScreen(land + offset * 0.35),
				dir = auxi.random_r(),
				alpha = 3 + urgency * 16,
				step = 0.025 + urgency * 0.18,
				total = 10 + math.floor(urgency * 14),
				P3A = -1,
				no_overwrite = true,
			})
		end
		if urgency > 0.35 and frame % math.max(6, math.floor(28 - urgency * 22)) == 0 then
			Game():ShakeScreen(math.floor(2 + urgency * 14))
		end
		if urgency > 0.7 and frame % 18 == 0 then
			Game():Darken(0.25 + urgency * 0.45, 10)
		end
	elseif urgency > 0.5 and frame % 20 == 0 then
		Game():ShakeScreen(math.floor(1 + urgency * 6))
	end
end

local function format_countdown_text(timer)
	-- 秒:毫秒；timer 按 30 更新帧/秒
	local total_ms = math.max(0, math.floor(timer * 1000 / 30 + 0.5))
	local sec = math.floor(total_ms / 1000)
	local ms = total_ms % 1000
	return string.format("%d:%03d", sec, ms)
end

local function render_countdown(pending)
	if not Game():GetHUD():IsVisible() then return end
	local text = format_countdown_text(pending.timer)
	local urgency = 1 - pending.timer / math.max(1, pending.timer_max)
	urgency = math.max(0, math.min(1, urgency))
	-- 浅黄白 → 橙 → 纯红
	local fade = (1 - urgency) ^ 1.25
	local col = KColor(1, 0.82 * fade, 0.22 * fade, 0.75 + 0.25 * urgency)
	local scale = 1.8 + 0.35 * urgency
	local font = countdown_font
	local width = font:GetStringWidthUTF8(text) * scale
	local size = auxi.GetScreenSize()
	local x = size.X * 0.5 - width * 0.5
	local y = size.Y * 0.04
	gui.draw_ch(Vector(x, y), text, scale, scale, col, true, font)
end

local function shader_params_from_squash(squash)
	-- 只有暂停菜单打开才直通；房间切换 IsPaused 时必须继续输出黑幕/淡出参数
	if menu_paused() then
		return {P1 = {0, 0, 0, 0}, P2 = {0, 0, 0, 0}}
	end
	local m = shader_screen_metrics()
	if not squash then
		return {P1 = {0, 0, 0, 0}, P2 = {m.center_u, m.center_v, 0, 0}}
	end
	-- 揭幕不在 shader 回调里触发（避免切换动画期间抢跑）；只推进已开始的 blur 淡出
	if squash.phase == "blur" then
		sync_blur_from_clock(squash)
		squash = get_squash()
		if not squash then
			return {P1 = {0, 0, 0, 0}, P2 = {m.center_u, m.center_v, 0, 0}}
		end
	end
	local cu, cv
	-- 恢复阶段必须锚屏幕中心；落点 UV 在 hub 里会偏到边缘，看起来像角落放大
	if squash.phase == "blur" or squash.phase == "wake" then
		cu, cv = m.center_u, m.center_v
	else
		cu, cv = resolve_crush_center_uv(squash)
	end
	local crush = squash.crush or 0
	local wave = squash.wave or 0
	local blur = squash.blur or 0
	local mosaic = squash.mosaic or 0
	local black = squash.black or 0
	local enabled = 1
	if crush < 0.001 and wave < 0.001 and blur < 0.001 and mosaic < 0.001 and black < 0.001 then
		enabled = 0
	end
	return {
		P1 = {crush, wave, blur, enabled},
		P2 = {cu or m.center_u, cv or m.center_v, mosaic, black},
	}
end

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_, _, _, player, use_flags)
	if use_flags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then return end
	if use_flags & UseFlag.USE_MIMIC ~= 0 and use_flags & UseFlag.USE_NOANIM ~= 0 then
		return {Discharge = false, Remove = false, ShowAnim = false}
	end
	local d = player:GetData()
	if d[item.own_key.."holding"] then
		player:AnimateCollectible(item.entity, "HideItem", "PlayerPickup")
		d[item.own_key.."holding"] = nil
		return {Discharge = false, Remove = false, ShowAnim = false}
	end
	if get_pending() or item.squash then
		return {Discharge = false, Remove = false, ShowAnim = false}
	end
	player:AnimateCollectible(item.entity, "LiftItem", "PlayerPickup")
	d[item.own_key.."holding"] = true
	return {Discharge = false, Remove = false, ShowAnim = false}
end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_, player)
	-- Day Dreamer effect（昏迷钉末）/ effect2（c1-=0.5 倒放）/ 结束 StopExtraAnimation
	local d = player:GetData()
	local wake = d[item.own_key.."wake"]
	if wake then
		-- 禁止 AddControlsCooldown(999)；只补到极短冷却，真正锁输入靠 MC_INPUT_ACTION
		player:AddControlsCooldown(math.max(0, 3 - player.ControlsCooldown))
		player.Velocity = Vector.Zero
		player:PlayExtraAnimation("DeathTeleport")
		local s = player:GetSprite()
		if not wake.waking then
			s:SetLastFrame()
			local fr = s:GetFrame()
			if fr > (wake.max_fr or 0) then
				wake.max_fr = fr
			end
			if (wake.max_fr or 0) > 0 then
				s:SetFrame("DeathTeleport", wake.max_fr)
			end
			wake.held = (wake.held or 0) + 1
			-- 至少钉住一段时间再倒放，避免传送当帧 max_fr=0 导致瞬间结束仍躺着
			if wake.ready and wake.held >= item.wake_hold_frames then
				if (wake.max_fr or 0) < 1 then
					s:SetLastFrame()
					wake.max_fr = math.max(s:GetFrame(), 24)
				end
				wake.c1 = wake.max_fr
				wake.waking = true
			end
		else
			-- 同 Day Dreamer effect2 / Zeis Teleported：先减 c1，再 SetFrame
			wake.c1 = (wake.c1 or 0) - 0.5
			local fr = math.max(0, math.floor(wake.c1))
			s:SetFrame("DeathTeleport", fr)
			if fr <= 0 then
				finish_player_wake(player)
			end
		end
	end

	if not d[item.own_key.."holding"] then return end
	if not player:IsHoldingItem() then
		d[item.own_key.."holding"] = nil
		return
	end
	local ctrlid = player.ControllerIndex
	-- CTRL / Drop：放下并取消举起（不消耗）
	if Input.IsActionTriggered(ButtonAction.ACTION_DROP, ctrlid) then
		player:AnimateCollectible(item.entity, "HideItem", "PlayerPickup")
		d[item.own_key.."holding"] = nil
		return
	end
	local dir = Vector.Zero
	for action = ButtonAction.ACTION_SHOOTLEFT, ButtonAction.ACTION_SHOOTDOWN do
		if Input.IsActionTriggered(action, ctrlid) then
			if action == ButtonAction.ACTION_SHOOTLEFT then dir = dir + Vector(-1, 0)
			elseif action == ButtonAction.ACTION_SHOOTRIGHT then dir = dir + Vector(1, 0)
			elseif action == ButtonAction.ACTION_SHOOTUP then dir = dir + Vector(0, -1)
			elseif action == ButtonAction.ACTION_SHOOTDOWN then dir = dir + Vector(0, 1) end
		end
	end
	if Game():GetRoom():IsMirrorWorld() then dir = Vector(-dir.X, dir.Y) end
	if dir:Length() < 0.1 then return end

	player:AnimateCollectible(item.entity, "HideItem", "PlayerPickup")
	d[item.own_key.."holding"] = nil
	player:RemoveCollectible(item.entity)
	throw_foil(player, dir)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_SHELLGAME, 1, 1, false, 0, 2)
end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_INPUT_ACTION, params = nil,
Function = function(_, ent, hook, button)
	if ent == nil then return end
	local player = ent:ToPlayer()
	if not player then return end
	local d = player:GetData()
	-- 压扁传送全程 + 苏醒期间锁控制；结束后清除 wake / squash 即释放
	if not d[item.own_key.."wake"] and not item.squash then return end
	if not item.banish_button[button] then return end
	if hook == InputHook.IS_ACTION_TRIGGERED or hook == InputHook.IS_ACTION_PRESSED then
		return false
	elseif hook == InputHook.GET_ACTION_VALUE then
		return 0
	end
end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.ID_EFFECT_MeusNIL,
Function = function(_, effect)
	local data = effect:GetData()
	if not data[item.own_key.."foil"] then return end
	keep_foil_alive(effect)
	effect.Velocity = Vector.Zero
	local fly = data[item.own_key.."fly"]
	local sprite = effect:GetSprite()
	if not fly then
		if data[item.own_key.."rest_angle"] then
			sprite.Rotation = data[item.own_key.."rest_angle"]
		end
		return
	end
	local start_frame = fly.start_frame or Game():GetFrameCount()
	fly.start_frame = start_frame
	local elapsed = Game():GetFrameCount() - start_frame
	local t = math.min(1, elapsed / math.max(1, fly.max))
	local ease = ease_out_cubic(t)
	effect.Position = fly.start + (fly.target - fly.start) * ease
	-- 按进度插值旋转，避免双更时每回调狂加角度
	local base_angle = fly.base_angle or fly.angle or 0
	fly.base_angle = base_angle
	fly.angle = base_angle + (fly.spin or 14) * 8 * ease
	sprite.Rotation = fly.angle
	if t >= 1 then
		effect.Position = fly.target
		data[item.own_key.."rest_angle"] = fly.angle
		sprite.Rotation = fly.angle
		data[item.own_key.."fly"] = nil
		data[item.own_key.."armed"] = true
		arm_pending(fly.target)
		sound_tracker.PlayStackedSound(item.land_sound, 0.85, 0.85, false, 0, 2)
	end
end,
})

-- 抹除门拦截：挂玩家更新帧（不再依赖 door 的 POST_GRID_UPDATE / PRE_GET_TELEPORT 时机）
if REPENTOGON and ModCallbacks.MC_PRE_PLAYER_UPDATE then
	table.insert(item.pre_ToCall, {CallBack = ModCallbacks.MC_PRE_PLAYER_UPDATE, params = 0,
	Function = function(_, player)
		check_erased_doors_on_player_update(player)
	end,
	})
else
	table.insert(item.pre_ToCall, {CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil, priority = -1000,
	Function = function(_, player)
		check_erased_doors_on_player_update(player)
	end,
	})
end

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if get_squash() then
		update_squash()
		return
	end
	if get_effect() and Game():GetFrameCount() % 10 == 0 then
		item.hide_erased_rooms(false)
	end
	local pending = get_pending()
	if not pending then return end
	if item.foil_ent and item.foil_ent:Exists() then
		keep_foil_alive(item.foil_ent)
	end
	if pending.ticking then
		pending.timer = pending.timer - 1
	else
		pending.ticking = true
	end
	update_pending_distort(pending)
	if pending.timer <= 0 then
		resolve_countdown()
	end
end,
})

local hud_render_cb = (REPENTOGON and ModCallbacks.MC_POST_HUD_RENDER) or ModCallbacks.MC_POST_RENDER
table.insert(item.ToCall, {CallBack = hud_render_cb, params = nil,
Function = function(_)
	local pending = get_pending()
	if pending and not get_squash() then render_countdown(pending) end
end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_GET_SHADER_PARAMS, params = nil,
Function = function(_, name)
	if name ~= item.squash_shader then return end
	return shader_params_from_squash(get_squash())
end,
})

table.insert(item.pre_myToCall, {CallBack = enums.Callbacks.PRE_NEW_ROOM, params = nil, priority = 900,
Function = function(_, _, _, desc)
	local effect = get_effect()
	if not REPENTOGON or not effect or not desc then return end
	if auxi.GetDimension(desc) == effect.dimension and room_is_erased(effect, desc.SafeGridIndex) then
		local leave = Game():GetLevel().LeaveDoor
		local from = Game():GetLevel():GetCurrentRoomDesc()
		local player = Game():GetPlayer(0)
		-- 漏截：把靠近阶段环缓整段输出，便于对照分布
		flush_approach_ring_as("leak_approach_trail", {
			via = "pre_new_room",
			leak_event = "leak_pre_new_room",
			target_safe = desc.SafeGridIndex,
			leave_door = leave or -1,
			hub = effect.hub_index,
		})
		append_dvf_door_log({
			event = "leak_pre_new_room",
			via = "pre_new_room",
			target_safe = desc.SafeGridIndex,
			from_safe = from and from.SafeGridIndex or -1,
			leave_door = leave or -1,
			hub = effect.hub_index,
			px = player.Position.X,
			py = player.Position.Y,
			vx = player.Velocity.X,
			vy = player.Velocity.Y,
			vlen = player.Velocity:Length(),
			note = "vanilla_transition_reached_erased",
		})
		if effect.hub_entry == nil then
			item.record_hub_entry(
				leave,
				from and from.SafeGridIndex,
				desc.SafeGridIndex
			)
		end
		if item.enable_erased_door_redirect then
			append_dvf_door_log({
				event = "redirect_hub",
				via = "pre_new_room",
				leave_door = leave or -1,
				from_safe = from and from.SafeGridIndex or -1,
				target_safe = desc.SafeGridIndex,
				hub = effect.hub_index,
				anim = "FADE",
				note = "leak_fallback",
			})
			item.redirect_to_hub(player, true)
		end
	end
end,
})

-- 门枚举 PRE_GET_TELEPORT 只记对照日志，不再拦截（拦截改走 PRE_PLAYER_UPDATE）
table.insert(item.myToCall, {CallBack = enums.Callbacks.PRE_GET_TELEPORT, params = "door", priority = 900,
Function = function(_, player, _, data)
	local effect = get_effect()
	local door = data.door
	if not effect or not door then return end
	if auxi.GetDimension() ~= effect.dimension then return end
	if not room_is_erased(effect, door.TargetRoomIndex) then return end
	local dist = data.dist
	if dist == nil then
		local catch_pos = door_catch_pos(door)
		dist = (player.Position - catch_pos):Length()
	end
	local sample = sample_door_player(player, door, dist)
	sample.event = "pre_teleport_seen"
	sample.via = data.via or "pre_get_teleport"
	sample.hub = effect.hub_index
	append_dvf_door_log(sample)
end,
})

table.insert(item.post_ToCall, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	for player_num = 0, Game():GetNumPlayers() - 1 do
		Game():GetPlayer(player_num):GetData()[item.own_key.."holding"] = nil
	end

	local pending = get_pending()
	if pending then
		local current = Game():GetLevel():GetCurrentRoomDesc()
		if current and auxi.GetDimension() == pending.dimension and current.SafeGridIndex == pending.source_room then
			if not (item.foil_ent and item.foil_ent:Exists()) then
				local foil = spawn_foil_visual(Vector(pending.land_x, pending.land_y))
				-- 重进房时没有飞行态，保持 Idle 朝向即可
				foil:GetSprite().Rotation = 0
			end
		else
			item.foil_ent = nil
		end
	end

	local effect = get_effect()
	if not effect or auxi.GetDimension() ~= effect.dimension then
		append_room_id_log("post_new_room", {
			note = (not effect) and "no_effect" or "wrong_dimension",
		})
		approach_ring = {}
		return
	end
	local current_desc = Game():GetLevel():GetCurrentRoomDesc()
	local current_index = current_desc.SafeGridIndex
	local hub_data = current_desc.Data
	local branch = "normal"
	if current_index == effect.hub_index then
		branch = "hub"
		if hub_data and hub_data.Variant ~= item.hub_room_variant then
			branch = "hub_variant_mismatch"
		elseif not hub_data then
			branch = "hub_data_nil"
		end
	elseif room_is_erased(effect, current_index) then
		branch = "erased"
	end
	append_room_id_log("post_new_room", {
		note = "classify",
		branch = branch,
		hub_variant_now = hub_data and hub_data.Variant or -1,
	})
	if current_index == effect.hub_index then
		approach_ring = {}
		item.set_hub_map_hidden(true)
		-- 续关后 Room_holder 可能先替换房型再 MINECART 重进；房型未就绪时跳过挂门
		if (not hub_data) or hub_data.Variant == item.hub_room_variant then
			item.configure_hub()
		else
			append_room_id_log("post_new_room_hub_wait", {
				note = "skip_configure_until_variant_ready",
				hub_variant_now = hub_data.Variant,
			})
		end
		local squash = get_squash()
		if squash and (squash.phase == "travel" or squash.phase == "hold" or squash.phase == "blur") then
			begin_hub_reveal(squash, true)
		end
	elseif room_is_erased(effect, current_index) then
		item.set_hub_map_hidden(false)
		local leave = Game():GetLevel().LeaveDoor
		local player = Game():GetPlayer(0)
		flush_approach_ring_as("leak_approach_trail", {
			via = "post_new_room",
			leak_event = "leak_post_new_room",
			target_safe = current_index,
			leave_door = leave or -1,
			hub = effect.hub_index,
		})
		append_dvf_door_log({
			event = "leak_post_new_room",
			via = "post_new_room",
			target_safe = current_index,
			leave_door = leave or -1,
			hub = effect.hub_index,
			px = player.Position.X,
			py = player.Position.Y,
			vx = player.Velocity.X,
			vy = player.Velocity.Y,
			vlen = player.Velocity:Length(),
			note = "entered_erased_before_redirect",
		})
		if item.enable_erased_door_redirect then
			append_dvf_door_log({
				event = "redirect_hub",
				via = "post_new_room",
				leave_door = leave or -1,
				target_safe = current_index,
				hub = effect.hub_index,
				anim = "FADE",
				note = "leak_fallback",
			})
			-- 漏进抹除房时用无方向 FADE 拉回 hub（不再带方向 WALK）
			item.redirect_to_hub(player, true)
		end
	else
		item.set_hub_map_hidden(false)
		item.open_doors_into_erased()
	end
	if item._defer_hide_erased then
		item._defer_hide_erased = nil
		mark_erased_rooms_cleared(effect.erased_rooms, effect.dimension)
	end
	item.hide_erased_rooms(true)
end,
})

-- 楼层清理只挂自定义 PRE_NEW_LEVEL（由 next_level_holder 保证续关不误发）
table.insert(item.myToCall, {CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	item.clear_floor_effect()
end,
})

table.insert(item.myToCall, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	item._door_log_session = nil
	ensure_door_log_session()
	append_dvf_door_log({
		event = "session_start",
		via = continue and "continue" or "new_run",
		note = "door_log_ready",
	})
	append_room_id_log("pre_game_started", {
		note = continue and "continue" or "new_run",
		continue = continue and true or false,
	})
	if not continue then
		save.elses[item.own_key.."effect"] = nil
		save.elses[item.own_key.."pending"] = nil
		save.elses[item.own_key.."squash"] = nil
		item.squash = nil
	else
		item.squash = save.elses[item.own_key.."squash"]
	end
	item.foil_ent = nil
	item.redirect_frame = nil
	local effect = get_effect()
	if effect then
		-- 失效的 hub 门格索引必须丢掉；续关始终重新挂载 hub 房型，进房后 configure_hub 重挂门
		clear_stale_hub_door_indices(effect)
		-- 此时勿 UpdateVisibility / hide（会崩）；进房 POST_NEW_ROOM 再刷地图
		if continue then
			item._defer_hide_erased = true
		else
			mark_erased_rooms_cleared(effect.erased_rooms, effect.dimension)
			item.hide_erased_rooms(true)
		end
		item.queue_hub_room_replacement(effect.hub_index, effect.dimension)
		append_room_id_log("pre_game_started_after_effect", {
			note = "queued_hub_replace",
			continue = continue and true or false,
			hub = effect.hub_index,
		})
	else
		append_room_id_log("pre_game_started_after_effect", {
			note = "no_effect_after_get",
			continue = continue and true or false,
		})
	end
end,
})

return item
