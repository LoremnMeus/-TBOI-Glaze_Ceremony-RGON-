-- Golden Compass Boss pool audit (read-only).
-- Candidate sources mirror corridor_plan: stage STB + SPECIAL_ROOMS.
-- Does not enable Boss@89 selection or mark encounters.

local catalog = require("Qing_Remaster_scripts.items.golden_compass.boss_pool_catalog")

local M = {}

local SHAPE_1X1 = RoomShape.ROOMSHAPE_1x1
local SCHEMA_VERSION = 7
-- Fixed seed for StageAPI GetValidRoomsForLayout offline scans (avoid current-room SpawnSeed drift).
local STAGEAPI_AUDIT_SEED = 0x514E4753 -- 'QNGS'
M.STAGEAPI_AUDIT_SEED = STAGEAPI_AUDIT_SEED
local STAGEAPI_ROOMS_SCHEMA_VERSION = 3
M.STAGEAPI_ROOMS_SCHEMA_VERSION = STAGEAPI_ROOMS_SCHEMA_VERSION
-- StageAPI native GenerateBossRoom does NOT set RequireRoomType; GC formal filter matches that.
-- RoomDescriptor.Type must still be ROOM_BOSS at 89 (descriptor vs Lua layout Type are different layers).
local STAGEAPI_FORMAL_REQUIRE_ROOM_TYPE = false
M.STAGEAPI_FORMAL_REQUIRE_ROOM_TYPE = STAGEAPI_FORMAL_REQUIRE_ROOM_TYPE

local CONFIDENT_MATCH = {
	["subtype+spawn"] = true,
	["subtype+spawn_disambiguated"] = true,
}
local WEAK_MATCH = {
	subtype_only = true,
	spawn_only = true,
}

local function room_config_holder()
	return rawget(_G, "RoomConfig") or rawget(_G, "RoomConfigHolder")
end

local function door_sets()
	local dm = catalog.DOOR_MASK
	return {
		{key = "ALL", need = 0, label = "1x1 any doors"},
		{key = "LR", need = dm.LR, label = "LEFT0|RIGHT0 (Boss@89)"},
		{key = "UD", need = dm.UD, label = "UP0|DOWN0"},
		{key = "LRUD", need = dm.LRUD, label = "four doors"},
		{key = "LEFT", need = dm.LEFT, label = "LEFT0"},
		{key = "RIGHT", need = dm.RIGHT, label = "RIGHT0"},
		{key = "UP", need = dm.UP, label = "UP0"},
		{key = "DOWN", need = dm.DOWN, label = "DOWN0"},
	}
end

local function foreach_spawn_entry(cfg, fn)
	if not cfg or not cfg.Spawns or type(fn) ~= "function" then
		return
	end
	local n = tonumber(cfg.SpawnCount) or 0
	pcall(function()
		for i = 0, n - 1 do
			local spawn = cfg.Spawns:Get(i)
			if spawn then
				local ec = tonumber(spawn.EntryCount) or 0
				local entries = spawn.Entries
				if entries and entries.Get then
					local size = tonumber(entries.Size) or ec
					for j = 0, size - 1 do
						local e = entries:Get(j)
						if e then
							fn(e)
						end
					end
				elseif spawn.PickEntry and ec > 0 then
					for j = 0, ec - 1 do
						local e = spawn:PickEntry((j + 0.5) / ec)
						if e then
							fn(e)
						end
					end
				end
			end
		end
	end)
end

local function match_boss_id(cfg, entity_index)
	local subtype_id = catalog.boss_id_from_subtype(cfg and cfg.Subtype)
	local spawn_set = {}
	foreach_spawn_entry(cfg, function(e)
		local typ = tonumber(e.Type) or 0
		local var = tonumber(e.Variant) or 0
		local sub = tonumber(e.Subtype) or 0
		local ids = catalog.lookup_entity_ids(entity_index, typ, var, sub)
		for i = 1, #ids do
			local cid = catalog.canonical_boss_id(ids[i])
			if cid then
				spawn_set[cid] = true
			end
		end
	end)
	local hit_list = {}
	for id in pairs(spawn_set) do
		hit_list[#hit_list + 1] = id
	end
	table.sort(hit_list)

	local resolved = nil
	local match_kind = "unmatched"
	local ambiguous = false

	if subtype_id and spawn_set[subtype_id] then
		resolved = subtype_id
		if #hit_list > 1 then
			-- Shared entity (e.g. Larry Jr / Tuff Twins): Subtype disambiguates.
			match_kind = "subtype+spawn_disambiguated"
		else
			match_kind = "subtype+spawn"
		end
	elseif subtype_id and #hit_list == 0 then
		resolved = subtype_id
		match_kind = "subtype_only"
	elseif subtype_id and #hit_list > 0 and not spawn_set[subtype_id] then
		resolved = subtype_id
		match_kind = "subtype_spawn_conflict"
		ambiguous = true
	elseif not subtype_id and #hit_list == 1 then
		resolved = hit_list[1]
		match_kind = "spawn_only"
	elseif not subtype_id and #hit_list > 1 then
		ambiguous = true
		match_kind = "spawn_ambiguous"
	end

	return {
		resolved = resolved,
		subtype_id = subtype_id,
		spawn_id = (#hit_list == 1) and hit_list[1] or nil,
		spawn_hits = hit_list,
		match_kind = match_kind,
		ambiguous = ambiguous,
	}
end

local function layout_dedupe_key(lay)
	return string.format(
		"%s:%s:%s:%s:%s",
		tostring(lay.stb),
		tostring(lay.type or RoomType.ROOM_BOSS),
		tostring(lay.variant),
		tostring(lay.subtype),
		tostring(lay.doors)
	)
end

local function layout_ref_id(lay)
	return string.format(
		"L:%s:%s:%s",
		tostring(lay.stb),
		tostring(lay.variant),
		tostring(lay.subtype)
	)
end

--- Enumerate ROOM_BOSS layouts from an STB.
--- opts.require_1x1 (default true). Returns 1x1 list, other-shape list.
function M.enumerate_boss_layouts(stb, opts)
	opts = opts or {}
	local require_1x1 = opts.require_1x1 ~= false
	local out = {}
	local other_shape = {}
	local holder = room_config_holder()
	if not holder or not holder.GetStage or stb == nil then
		return out, other_shape
	end
	local stage_cfg = nil
	local ok = pcall(function()
		stage_cfg = holder.GetStage(stb)
	end)
	if not (ok and stage_cfg and stage_cfg.GetRoomSet) then
		return out, other_shape
	end
	local set = nil
	ok = pcall(function()
		set = stage_cfg:GetRoomSet(0)
	end)
	if not (ok and set) then
		return out, other_shape
	end
	local size = 0
	pcall(function()
		size = set.Size or #set or 0
	end)
	local entity_index = opts.entity_index or catalog.build_entity_index()
	local source = opts.source or ("stb:" .. tostring(stb))
	for i = 0, size - 1 do
		local room = nil
		pcall(function()
			room = set:Get(i)
		end)
		if room and room.Type == RoomType.ROOM_BOSS then
			local shape = room.Shape
			local doors = room.Doors or 0
			local weight = 1
			local spawn_count = 0
			pcall(function()
				spawn_count = room.SpawnCount or 0
			end)
			pcall(function()
				weight = tonumber(room.Weight) or tonumber(room.weight) or tonumber(room.InitialWeight) or 1
			end)
			local match = match_boss_id(room, entity_index)
			local row = {
				stb = stb,
				source = source,
				type = room.Type,
				variant = room.Variant,
				subtype = room.Subtype,
				shape = shape,
				doors = doors,
				difficulty = room.Difficulty,
				name = room.Name,
				spawn_count = spawn_count,
				weight = weight,
				match = match,
				boss_id = match.resolved,
				ref = nil,
			}
			row.ref = layout_ref_id(row)
			if require_1x1 and shape ~= SHAPE_1X1 then
				other_shape[#other_shape + 1] = row
			else
				out[#out + 1] = row
			end
		end
	end
	return out, other_shape
end

local function empty_door_counts()
	local c = {}
	for _, ds in ipairs(door_sets()) do
		c[ds.key] = 0
	end
	return c
end

local function bump_door_counts(counts, doors)
	doors = tonumber(doors) or 0
	for _, ds in ipairs(door_sets()) do
		if ds.need == 0 or (doors & ds.need) == ds.need then
			counts[ds.key] = (counts[ds.key] or 0) + 1
		end
	end
end

local function has_lr(doors)
	local need = catalog.DOOR_MASK.LR
	return ((tonumber(doors) or 0) & need) == need
end

local function classify_special_role(def, boss_id)
	if def.role_89 == "mother_gate" and boss_id == "Mother" then
		return "mother_gate_neg10"
	end
	if catalog.is_unsupported_shape_for_89(boss_id) then
		return "unsupported_shape"
	end
	if def.fixed then
		return "fixed_endgame_review"
	end
	return "normal_fight_89"
end

--- StageAPI DoLayoutDoorsMatch: doors[slot]=true means Level needs that slot.
--- Layouts with extra Exists=true doors remain valid; only missing required slots fail.
--- So LEFT0+RIGHT0 true / others false accepts 2-door and 4-door LR layouts.
local function stageapi_lr_door_mask()
	local doors = {}
	local slot_n = DoorSlot.NUM_DOOR_SLOTS or 8
	for s = 0, slot_n - 1 do
		doors[s] = false
	end
	doors[DoorSlot.LEFT0] = true
	doors[DoorSlot.RIGHT0] = true
	return doors
end

local function layout_doors_bits(layout)
	local doors_bits = 0
	if not layout or type(layout.Doors) ~= "table" then
		return doors_bits
	end
	for _, d in ipairs(layout.Doors) do
		if d and d.Exists and d.Slot ~= nil then
			doors_bits = doors_bits | (1 << d.Slot)
		end
	end
	return doors_bits
end

--- Mirror StageAPI.DoLayoutDoorsMatch (required slots must Exists on layout).
local function stageapi_doors_match(layout, doors)
	if StageAPI and StageAPI.DoLayoutDoorsMatch then
		local ok, match = pcall(function()
			local does_match = StageAPI.DoLayoutDoorsMatch(layout, doors)
			return does_match
		end)
		if ok then
			return match == true
		end
	end
	if type(layout) ~= "table" or type(layout.Doors) ~= "table" or type(doors) ~= "table" then
		return false
	end
	for _, door in ipairs(layout.Doors) do
		if door and door.Slot and not door.Exists and doors[door.Slot] then
			return false
		end
	end
	return true
end

local function stageapi_layout_missing_required_slots(layout, doors)
	local missing_left = false
	local missing_right = false
	if type(layout) ~= "table" or type(layout.Doors) ~= "table" or type(doors) ~= "table" then
		return missing_left, missing_right
	end
	local left = DoorSlot.LEFT0
	local right = DoorSlot.RIGHT0
	for _, door in ipairs(layout.Doors) do
		if door and door.Slot and not door.Exists and doors[door.Slot] then
			if door.Slot == left then
				missing_left = true
			elseif door.Slot == right then
				missing_right = true
			end
		end
	end
	return missing_left, missing_right
end

local function stageapi_post_check_passes(layout, room_list, seed, shape, rtype, require_room_type)
	if not (StageAPI and StageAPI.GetCallbacks) then
		return true, 0
	end
	local callbacks = nil
	pcall(function()
		callbacks = StageAPI.GetCallbacks("POST_CHECK_VALID_ROOM")
	end)
	if type(callbacks) ~= "table" or #callbacks == 0 then
		return true, 0
	end
	local rejected = false
	for _, callback in ipairs(callbacks) do
		-- Mirror StageAPI.GetValidRoomsForLayout: TryCallback(callback, layout, roomList, seed, shape, rtype, requireRoomType)
		local success, ret = nil, nil
		pcall(function()
			success, ret = StageAPI.TryCallback(
				callback,
				layout,
				room_list,
				seed,
				shape,
				rtype,
				require_room_type
			)
		end)
		if success and ret == false then
			rejected = true
			break
		end
	end
	return not rejected, #callbacks
end

local function push_sample(bucket, sample, limit)
	limit = limit or 3
	if type(bucket) ~= "table" or #bucket >= limit then
		return
	end
	bucket[#bucket + 1] = sample
end

--- Funnel for Boss@89 StageAPI formal filter (matches GenerateBossRoom / native path):
--- Shape 1x1 → LR doors → POST_CHECK_VALID_ROOM.
--- ROOM_BOSS Type on Lua layout is diagnostic only (formal RequireRoomType = false).
local function stageapi_layout_filter_breakdown(room_list, doors, seed, require_room_type)
	if require_room_type == nil then
		require_room_type = STAGEAPI_FORMAL_REQUIRE_ROOM_TYPE
	end
	local bd = {
		rooms_list_total = 0,
		rooms_1x1 = 0,
		after_room_type = 0,
		after_doors = 0,
		after_callbacks = 0,
		fail_not_1x1 = 0,
		fail_room_type = 0,
		fail_doors = 0,
		fail_callback = 0,
		rooms_1x1_type_boss = 0,
		rooms_1x1_doors_lr = 0,
		rooms_1x1_type_and_doors = 0,
		formal_require_room_type = require_room_type == true,
		--- Diagnostic: survivors if one gate were ignored.
		would_pass_ignore_type = 0,
		would_pass_ignore_doors = 0,
		would_pass_ignore_callbacks = 0,
		type_histogram = {},
		shape_histogram = {},
		door_fail_missing_left = 0,
		door_fail_missing_right = 0,
		callback_count = 0,
		samples = {
			room_type = {},
			doors = {},
			callback = {},
		},
		primary_reject = nil,
	}
	if type(room_list) ~= "table" then
		bd.primary_reject = "no_Rooms"
		return bd
	end

	local all = nil
	pcall(function()
		if room_list.GetRooms then
			all = room_list:GetRooms(-1)
		elseif type(room_list.All) == "table" then
			all = room_list.All
		end
	end)
	if type(all) ~= "table" then
		all = {}
	end
	bd.rooms_list_total = #all

	local one_by_one = nil
	pcall(function()
		if room_list.GetRooms then
			one_by_one = room_list:GetRooms(SHAPE_1X1)
		end
	end)
	if type(one_by_one) ~= "table" then
		one_by_one = {}
	end
	bd.rooms_1x1 = #one_by_one
	bd.fail_not_1x1 = math.max(0, bd.rooms_list_total - bd.rooms_1x1)

	for _, layout in ipairs(all) do
		local shape = layout and layout.Shape
		local key = tostring(shape)
		bd.shape_histogram[key] = (bd.shape_histogram[key] or 0) + 1
	end

	local rtype = RoomType.ROOM_BOSS
	for list_id, layout in ipairs(one_by_one) do
		local ltype = layout and layout.Type
		local type_key = tostring(ltype)
		bd.type_histogram[type_key] = (bd.type_histogram[type_key] or 0) + 1

		local is_boss_type = ltype == rtype
		local doors_ok = stageapi_doors_match(layout, doors)
		local sample = {
			list_id = list_id,
			name = layout and (layout.Name or layout.name),
			type = ltype,
			shape = layout and layout.Shape,
			doors = layout_doors_bits(layout),
			subtype = layout and layout.SubType,
		}

		if is_boss_type then
			bd.rooms_1x1_type_boss = bd.rooms_1x1_type_boss + 1
		end
		if doors_ok then
			bd.rooms_1x1_doors_lr = bd.rooms_1x1_doors_lr + 1
		end
		if is_boss_type and doors_ok then
			bd.rooms_1x1_type_and_doors = bd.rooms_1x1_type_and_doors + 1
		end

		-- Callbacks see requireRoomType matching formal filter (StageAPI passes it through).
		local cb_ok, cb_n = stageapi_post_check_passes(
			layout,
			room_list,
			seed,
			SHAPE_1X1,
			rtype,
			require_room_type == true
		)
		bd.callback_count = cb_n
		if doors_ok and cb_ok then
			bd.would_pass_ignore_type = bd.would_pass_ignore_type + 1
		end
		if is_boss_type and cb_ok then
			bd.would_pass_ignore_doors = bd.would_pass_ignore_doors + 1
		end
		if (not require_room_type or is_boss_type) and doors_ok then
			bd.would_pass_ignore_callbacks = bd.would_pass_ignore_callbacks + 1
		end

		-- Type gate is diagnostic when formal_require_room_type=false.
		if not is_boss_type then
			bd.fail_room_type = bd.fail_room_type + 1
			push_sample(bd.samples.room_type, sample)
		else
			bd.after_room_type = bd.after_room_type + 1
		end

		local type_ok = (require_room_type ~= true) or is_boss_type
		if not type_ok then
			-- Formal type reject path (only when RequireRoomType=true).
		elseif not doors_ok then
			bd.fail_doors = bd.fail_doors + 1
			local miss_l, miss_r = stageapi_layout_missing_required_slots(layout, doors)
			if miss_l then
				bd.door_fail_missing_left = bd.door_fail_missing_left + 1
			end
			if miss_r then
				bd.door_fail_missing_right = bd.door_fail_missing_right + 1
			end
			sample.missing_left0 = miss_l
			sample.missing_right0 = miss_r
			push_sample(bd.samples.doors, sample)
		else
			bd.after_doors = bd.after_doors + 1
			if not cb_ok then
				bd.fail_callback = bd.fail_callback + 1
				push_sample(bd.samples.callback, sample)
			else
				bd.after_callbacks = bd.after_callbacks + 1
			end
		end
	end

	if bd.rooms_1x1 == 0 then
		bd.primary_reject = "no_shape_1x1"
	elseif require_room_type == true and bd.after_room_type == 0 then
		bd.primary_reject = "no_room_type_boss"
	elseif bd.after_doors == 0 then
		bd.primary_reject = "no_lr_doors"
	elseif bd.after_callbacks == 0 then
		bd.primary_reject = "post_check_valid_room"
	else
		bd.primary_reject = nil
	end
	return bd
end

local function summarize_stageapi_bosses(bosses)
	local candidates = 0
	local usable_lr = 0
	local rejected = {}
	local reject_reason_counts = {}
	for i = 1, #(bosses or {}) do
		local row = bosses[i]
		if row and row.base_game ~= true then
			candidates = candidates + 1
			if (tonumber(row.valid_lr) or 0) > 0 then
				usable_lr = usable_lr + 1
			else
				local reason = row.reject or "no_valid_lr"
				reject_reason_counts[reason] = (reject_reason_counts[reason] or 0) + 1
				rejected[#rejected + 1] = {
					id = row.id,
					reject = reason,
					rooms_list_count = row.rooms_list_count,
					rooms_list_total = row.rooms_list_total,
					has_rooms = row.has_rooms == true,
					layout_filter = row.layout_filter,
				}
			end
		end
	end
	return candidates, usable_lr, rejected, reject_reason_counts
end

local function stageapi_has_valid_room_callbacks()
	local n = 0
	pcall(function()
		if StageAPI and StageAPI.GetCallbacks then
			-- StageAPI callback id is the string "POST_CHECK_VALID_ROOM" (registry key).
			local list = StageAPI.GetCallbacks("POST_CHECK_VALID_ROOM")
			n = type(list) == "table" and #list or 0
		end
	end)
	return n > 0, n
end

local function stageapi_extension_for_floor(stage, stage_type)
	local has_cb, cb_count = stageapi_has_valid_room_callbacks()
	local ext = {
		available = false,
		pool_count = 0,
		bosses = {},
		errors = {},
		reason = nil,
		audit_seed = STAGEAPI_AUDIT_SEED,
		post_check_valid_room_callbacks = cb_count,
		layout_filter_may_use_callbacks = has_cb,
		stageapi_boss_candidates = 0,
		stageapi_usable_lr = 0,
		stageapi_rejected = {},
		stageapi_reject_reason_counts = {},
	}
	if StageAPI == nil then
		ext.reason = "stageapi_not_loaded"
		ext.errors[#ext.errors + 1] = "stageapi_not_loaded"
		return ext
	end
	if not StageAPI.GetBaseFloorInfo then
		ext.reason = "stageapi_missing_GetBaseFloorInfo"
		ext.errors[#ext.errors + 1] = ext.reason
		return ext
	end
	local ok, err = pcall(function()
		local info = StageAPI.GetBaseFloorInfo(stage, stage_type, false)
		if not info then
			ext.reason = "floor_info_missing"
			ext.errors[#ext.errors + 1] = "floor_info_missing"
			return
		end
		ext.available = true
		local pool = info.Bosses and info.Bosses.Pool
		if type(pool) ~= "table" or #pool == 0 then
			ext.reason = "boss_pool_empty"
			ext.errors[#ext.errors + 1] = "boss_pool_empty"
			return
		end
		for i = 1, #pool do
			local entry = pool[i]
			local boss_id = entry and (entry.BossID or entry.bossID)
			if type(boss_id) == "string" then
				boss_id = catalog.canonical_boss_id(boss_id)
				local boss = StageAPI.GetBossData and StageAPI.GetBossData(boss_id)
				local rooms_list_name = nil
				pcall(function()
					if boss and boss.Rooms then
						rooms_list_name = boss.Rooms.Name or boss.Rooms.name or boss.Rooms.RoomListName
					end
				end)
				local boss_cond = boss and (boss.ConditionFunc ~= nil or boss.Condition ~= nil)
				local pool_cond = entry and entry.ConditionFunc ~= nil
				local row = {
					id = boss_id,
					weight = entry.Weight or 1,
					base_game = boss and boss.BaseGameBoss == true,
					has_rooms = boss and boss.Rooms ~= nil,
					rooms_list_name = rooms_list_name,
					rooms_list_count = nil,
					rooms_list_total = nil,
					valid_lr = nil,
					reject = nil,
					layouts = nil,
					layout_filter = nil,
					audit_seed = STAGEAPI_AUDIT_SEED,
					has_condition_func = boss_cond == true or pool_cond == true,
					dynamic_condition = boss_cond == true or pool_cond == true,
					layout_filter_may_use_callbacks = has_cb,
					-- Offline structure OK ≠ live ConditionFunc / POST_CHECK_VALID_ROOM at final 89.
					needs_live_89_recheck = (boss_cond == true or pool_cond == true or has_cb),
				}
				if boss and boss.Rooms and StageAPI.GetValidRoomsForLayout then
					local doors = stageapi_lr_door_mask()
					local breakdown = stageapi_layout_filter_breakdown(
						boss.Rooms,
						doors,
						STAGEAPI_AUDIT_SEED,
						STAGEAPI_FORMAL_REQUIRE_ROOM_TYPE
					)
					row.layout_filter = breakdown
					row.rooms_list_total = breakdown.rooms_list_total
					row.rooms_list_count = breakdown.rooms_1x1
					local ok2, pack = pcall(function()
						local rooms, weights, err_msg = StageAPI.GetValidRoomsForLayout({
							RoomList = boss.Rooms,
							Shape = SHAPE_1X1,
							IgnoreShape = false,
							IgnoreDoors = false,
							Doors = doors,
							-- Match StageAPI.GenerateBossRoom native semantics (not RequireRoomType).
							RequireRoomType = STAGEAPI_FORMAL_REQUIRE_ROOM_TYPE,
							RoomType = RoomType.ROOM_BOSS,
							Seed = STAGEAPI_AUDIT_SEED,
						})
						return {rooms = rooms, weights = weights, err = err_msg}
					end)
					if ok2 and type(pack) == "table" and type(pack.rooms) == "table" then
						row.valid_lr = #pack.rooms
						local layouts = {}
						for j = 1, #pack.rooms do
							local pack_row = pack.rooms[j]
							local meta = pack_row and pack_row[1]
							local weight = pack_row and pack_row[2]
							local layout = meta and meta.Layout
							local list_id = meta and meta.ListID
							layouts[#layouts + 1] = {
								list_id = list_id,
								shape = layout and layout.Shape,
								doors = layout_doors_bits(layout),
								weight = weight,
								name = layout and (layout.Name or layout.name),
								subtype = layout and layout.SubType,
								type = layout and layout.Type,
								audit_seed = STAGEAPI_AUDIT_SEED,
								needs_live_89_recheck = row.needs_live_89_recheck == true,
							}
						end
						row.layouts = layouts
						if #pack.rooms == 0 then
							-- Prefer funnel primary_reject over opaque no_valid_lr / shape err string.
							row.reject = breakdown.primary_reject
								or tostring(pack.err or "no_valid_lr")
						elseif breakdown.after_callbacks ~= #pack.rooms then
							-- Keep formal GetValidRoomsForLayout as authority; note funnel drift.
							row.layout_filter_mismatch = {
								funnel_after_callbacks = breakdown.after_callbacks,
								get_valid_rooms = #pack.rooms,
							}
						end
					else
						row.reject = breakdown.primary_reject
							or ("GetValidRoomsForLayout_failed:" .. tostring(pack))
					end
				elseif boss and not boss.BaseGameBoss then
					row.reject = "no_Rooms"
				elseif not boss then
					row.reject = "boss_data_missing"
				end
				ext.bosses[#ext.bosses + 1] = row
			end
		end
		ext.pool_count = #ext.bosses
		local cand, usable, rejected, reason_counts = summarize_stageapi_bosses(ext.bosses)
		ext.stageapi_boss_candidates = cand
		ext.stageapi_usable_lr = usable
		ext.stageapi_rejected = rejected
		ext.stageapi_reject_reason_counts = reason_counts or {}
		ext.reason = (ext.pool_count == 0) and "boss_pool_empty" or "ok"
	end)
	if not ok then
		ext.available = false
		ext.reason = "stageapi_error"
		ext.errors[#ext.errors + 1] = tostring(err)
	end
	return ext
end

M.stageapi_extension_for_floor = stageapi_extension_for_floor
M.stageapi_lr_door_mask = stageapi_lr_door_mask

--- Formal StageAPI layout validity count for Boss@89 (1x1 + LR doors; no RequireRoomType).
function M.count_stageapi_valid_lr(rooms_list, seed)
	if not (StageAPI and StageAPI.GetValidRoomsForLayout and rooms_list) then
		return 0, "unavailable"
	end
	local doors = stageapi_lr_door_mask()
	local ok, pack = pcall(function()
		local rooms, weights, err_msg = StageAPI.GetValidRoomsForLayout({
			RoomList = rooms_list,
			Shape = SHAPE_1X1,
			IgnoreShape = false,
			IgnoreDoors = false,
			Doors = doors,
			RequireRoomType = STAGEAPI_FORMAL_REQUIRE_ROOM_TYPE,
			RoomType = RoomType.ROOM_BOSS,
			Seed = seed or STAGEAPI_AUDIT_SEED,
		})
		return {rooms = rooms, weights = weights, err = err_msg}
	end)
	if not ok or type(pack) ~= "table" or type(pack.rooms) ~= "table" then
		return 0, "GetValidRoomsForLayout_failed:" .. tostring(pack)
	end
	return #pack.rooms, pack.err
end

local function format_layout_filter_short(lf)
	if type(lf) ~= "table" then
		return "filter=n/a"
	end
	return string.format(
		"total=%s 1x1=%s typeBoss=%s doorsLR=%s afterType=%s afterDoors=%s afterCb=%s failType=%s failDoors=%s failCb=%s ignType=%s ignDoors=%s ignCb=%s",
		tostring(lf.rooms_list_total),
		tostring(lf.rooms_1x1),
		tostring(lf.rooms_1x1_type_boss),
		tostring(lf.rooms_1x1_doors_lr),
		tostring(lf.after_room_type),
		tostring(lf.after_doors),
		tostring(lf.after_callbacks),
		tostring(lf.fail_room_type),
		tostring(lf.fail_doors),
		tostring(lf.fail_callback),
		tostring(lf.would_pass_ignore_type),
		tostring(lf.would_pass_ignore_doors),
		tostring(lf.would_pass_ignore_callbacks)
	)
end

local function format_type_histogram(hist, limit)
	if type(hist) ~= "table" then
		return ""
	end
	local bits = {}
	for k, v in pairs(hist) do
		bits[#bits + 1] = {k = tostring(k), v = tonumber(v) or 0}
	end
	table.sort(bits, function(a, b)
		if a.v ~= b.v then
			return a.v > b.v
		end
		return a.k < b.k
	end)
	limit = limit or 6
	local out = {}
	for i = 1, math.min(#bits, limit) do
		out[#out + 1] = bits[i].k .. "=" .. tostring(bits[i].v)
	end
	if #bits > limit then
		out[#out + 1] = "..."
	end
	return table.concat(out, ",")
end

--- Offline StageAPI room-resource scan only (no floor change, no bind, no descriptor writes).
function M.scan_stageapi_rooms()
	local targets = catalog.list_scan_targets()
	local floors = {}
	local cand_ids = {}
	local usable_ids = {}
	local rejected = {}
	local dynamic_ids = {}
	local reject_reason_counts = {}
	local stageapi_loaded = StageAPI ~= nil
	local has_cb, cb_count = stageapi_has_valid_room_callbacks()
	for i = 1, #targets do
		local def = targets[i]
		local ext = stageapi_extension_for_floor(def.stage, def.stage_type)
		local floor_bosses = {}
		for _, eb in ipairs(ext.bosses or {}) do
			if eb and eb.base_game ~= true then
				floor_bosses[#floor_bosses + 1] = eb
				if type(eb.id) == "string" then
					cand_ids[eb.id] = true
					if eb.needs_live_89_recheck then
						dynamic_ids[eb.id] = true
					end
					if (tonumber(eb.valid_lr) or 0) > 0 then
						usable_ids[eb.id] = true
						rejected[eb.id] = nil -- usable on any floor wins over reject elsewhere
					elseif not usable_ids[eb.id] and not rejected[eb.id] then
						local reason = eb.reject or "no_valid_lr"
						rejected[eb.id] = {
							id = eb.id,
							reject = reason,
							rooms_list_name = eb.rooms_list_name,
							rooms_list_count = eb.rooms_list_count,
							rooms_list_total = eb.rooms_list_total,
							layout_filter = eb.layout_filter,
							sample_stage = def.stage,
							sample_stage_type = def.stage_type,
						}
					end
				end
			end
		end
		floors[#floors + 1] = {
			stage = def.stage,
			stage_type = def.stage_type,
			stb = def.stb or def.prefix,
			prefix = def.prefix,
			reason = ext.reason,
			audit_seed = STAGEAPI_AUDIT_SEED,
			stageapi_boss_candidates = ext.stageapi_boss_candidates or 0,
			stageapi_usable_lr = ext.stageapi_usable_lr or 0,
			stageapi_rejected_count = #(ext.stageapi_rejected or {}),
			stageapi_reject_reason_counts = ext.stageapi_reject_reason_counts or {},
			bosses = floor_bosses,
		}
	end
	local function count_map(t)
		local n = 0
		for _ in pairs(t) do
			n = n + 1
		end
		return n
	end
	local rej_list = {}
	for _, v in pairs(rejected) do
		rej_list[#rej_list + 1] = v
		local reason = v.reject or "no_valid_lr"
		reject_reason_counts[reason] = (reject_reason_counts[reason] or 0) + 1
	end
	table.sort(rej_list, function(a, b)
		local ra = tostring(a.reject or "")
		local rb = tostring(b.reject or "")
		if ra ~= rb then
			return ra < rb
		end
		return tostring(a.id) < tostring(b.id)
	end)
	local dyn_list = {}
	for id in pairs(dynamic_ids) do
		dyn_list[#dyn_list + 1] = id
	end
	table.sort(dyn_list)
	return {
		schema = "golden_compass_stageapi_rooms_audit",
		schema_version = STAGEAPI_ROOMS_SCHEMA_VERSION,
		audit_seed = STAGEAPI_AUDIT_SEED,
		stageapi_loaded = stageapi_loaded,
		layout_filter_may_use_callbacks = has_cb,
		post_check_valid_room_callbacks = cb_count,
		note = "Offline structure scan via GetBaseFloorInfo/GetBossData/GetValidRoomsForLayout; fixed Seed. Formal StageAPI filter: 1x1+LR doors+POST_CHECK (RequireRoomType=false, matches GenerateBossRoom). Lua layout Type=ROOM_BOSS is diagnostic only; RoomDescriptor@89 must still be ROOM_BOSS. Dynamic ConditionFunc needs live 89 recheck.",
		scanned_at_game_frame = (function()
			local n = 0
			pcall(function()
				n = Game():GetFrameCount()
			end)
			return n
		end)(),
		floor_count = #floors,
		stageapi_boss_candidates = stageapi_loaded and count_map(cand_ids) or nil,
		stageapi_usable_lr = stageapi_loaded and count_map(usable_ids) or nil,
		stageapi_rejected = stageapi_loaded and rej_list or nil,
		stageapi_reject_reason_counts = stageapi_loaded and reject_reason_counts or nil,
		needs_live_89_recheck_bosses = stageapi_loaded and dyn_list or nil,
		floors = floors,
	}
end

function M.format_stageapi_rooms_summary(report)
	if not report then
		return "stageapi_rooms_audit: no report"
	end
	local lines = {
		string.format("StageAPI Rooms Audit v%s", tostring(report.schema_version)),
		string.format(
			"loaded=%s seed=0x%08X floors=%s callbacks=%s",
			tostring(report.stageapi_loaded),
			tonumber(report.audit_seed) or 0,
			tostring(report.floor_count),
			tostring(report.post_check_valid_room_callbacks)
		),
		string.format(
			"extension unique: candidates=%s usable_lr=%s rejected=%s dynamic=%s",
			tostring(report.stageapi_boss_candidates),
			tostring(report.stageapi_usable_lr),
			tostring(report.stageapi_rejected and #report.stageapi_rejected or 0),
			tostring(report.needs_live_89_recheck_bosses and #report.needs_live_89_recheck_bosses or 0)
		),
	}
	local reason_bits = {}
	for k, v in pairs(report.stageapi_reject_reason_counts or {}) do
		reason_bits[#reason_bits + 1] = tostring(k) .. "=" .. tostring(v)
	end
	table.sort(reason_bits)
	lines[#lines + 1] = "reject reasons: " .. (#reason_bits > 0 and table.concat(reason_bits, ", ") or "none")
	lines[#lines + 1] = "formal funnel: total → 1x1 → LR doors → POST_CHECK (=valid_lr); RequireRoomType="
		.. tostring(STAGEAPI_FORMAL_REQUIRE_ROOM_TYPE)
	lines[#lines + 1] = "diagnostic: typeBoss / 1x1 types / ign* (Lua Type≠descriptor Type)"
	lines[#lines + 1] = ""
	lines[#lines + 1] = "Rejected bosses (unique; with filter breakdown):"
	local rej = report.stageapi_rejected or {}
	local rej_limit = 40
	for i = 1, math.min(#rej, rej_limit) do
		local r = rej[i]
		local lf = r.layout_filter
		lines[#lines + 1] = string.format(
			"  - %s rej=%s list=%s stage=%s/%s",
			tostring(r.id),
			tostring(r.reject),
			tostring(r.rooms_list_name),
			tostring(r.sample_stage),
			tostring(r.sample_stage_type)
		)
		lines[#lines + 1] = "      " .. format_layout_filter_short(lf)
		if type(lf) == "table" and type(lf.type_histogram) == "table" then
			local hist = format_type_histogram(lf.type_histogram, 8)
			if hist ~= "" then
				lines[#lines + 1] = "      1x1 types: " .. hist
			end
		end
	end
	if #rej > rej_limit then
		lines[#lines + 1] = string.format("  ... (+%s rejected; see full JSON)", tostring(#rej - rej_limit))
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = "Per floor (extension only; summary truncates to 24 floors × 6 bosses; full JSON untruncated):"
	local floor_limit = 24
	local boss_limit = 6
	for i = 1, math.min(#(report.floors or {}), floor_limit) do
		local f = report.floors[i]
		lines[#lines + 1] = string.format(
			"  stage=%s type=%s cand=%s lr=%s rej=%s reason=%s",
			tostring(f.stage),
			tostring(f.stage_type),
			tostring(f.stageapi_boss_candidates),
			tostring(f.stageapi_usable_lr),
			tostring(f.stageapi_rejected_count),
			tostring(f.reason)
		)
		for j = 1, math.min(#(f.bosses or {}), boss_limit) do
			local b = f.bosses[j]
			local lf = b.layout_filter
			lines[#lines + 1] = string.format(
				"    - %s lr=%s list=%s dyn=%s rej=%s",
				tostring(b.id),
				tostring(b.valid_lr),
				tostring(b.rooms_list_name),
				tostring(b.needs_live_89_recheck),
				tostring(b.reject)
			)
			if type(lf) == "table" then
				lines[#lines + 1] = string.format(
					"      funnel 1x1=%s type=%s doors=%s cb=%s | ignType=%s ignDoors=%s",
					tostring(lf.rooms_1x1),
					tostring(lf.after_room_type),
					tostring(lf.after_doors),
					tostring(lf.after_callbacks),
					tostring(lf.would_pass_ignore_type),
					tostring(lf.would_pass_ignore_doors)
				)
			end
		end
		if #(f.bosses or {}) > boss_limit then
			lines[#lines + 1] = string.format("    ... (+%s bosses)", tostring(#f.bosses - boss_limit))
		end
	end
	if #(report.floors or {}) > floor_limit then
		lines[#lines + 1] = string.format(
			"  ... (+%s floors; see full JSON)",
			tostring(#report.floors - floor_limit)
		)
	end
	return table.concat(lines, "\n")
end

local function ensure_boss_row(by_boss, id, def)
	id = catalog.canonical_boss_id(id)
	if not id then
		return nil
	end
	if not by_boss[id] then
		by_boss[id] = {
			id = id,
			in_pool = false,
			weight = 0,
			fixed = def.fixed == true,
			special_role = classify_special_role(def, id),
			unsupported_shape = catalog.is_unsupported_shape_for_89(id),
			layouts_total = 0,
			layouts_stage = 0,
			layouts_special = 0,
			layouts_other_shape = 0,
			door_counts = empty_door_counts(),
			match_kinds = {},
			usable_lr_confident = 0,
			usable_lr_weak = 0,
			layout_refs = {},
			sample_variants = {},
			sample_other_shape = {},
		}
	end
	return by_boss[id]
end

local function ingest_layout(by_boss, lay, def, counts, pool_ids)
	local mk = lay.match and lay.match.match_kind or "unmatched"
	counts.match_kinds[mk] = (counts.match_kinds[mk] or 0) + 1
	counts.raw = counts.raw + 1
	if lay.source == "special_rooms" then
		counts.raw_special = counts.raw_special + 1
	else
		counts.raw_stage = counts.raw_stage + 1
	end

	local id = catalog.canonical_boss_id(lay.boss_id)
	lay.boss_id = id
	if not id then
		counts.unmatched = counts.unmatched + 1
		return
	end
	counts.identified = counts.identified + 1
	if lay.match and lay.match.ambiguous then
		counts.ambiguous = counts.ambiguous + 1
	end
	if mk == "subtype_spawn_conflict" then
		counts.conflict = counts.conflict + 1
	end

	local row = ensure_boss_row(by_boss, id, def)
	row.layouts_total = row.layouts_total + 1
	if lay.source == "special_rooms" then
		row.layouts_special = row.layouts_special + 1
	else
		row.layouts_stage = row.layouts_stage + 1
	end
	bump_door_counts(row.door_counts, lay.doors)
	row.match_kinds[mk] = (row.match_kinds[mk] or 0) + 1
	if lay.ref and #row.layout_refs < 24 then
		row.layout_refs[#row.layout_refs + 1] = lay.ref
	end

	local in_pool = pool_ids[id] == true
	if in_pool then
		counts.in_pool = counts.in_pool + 1
		local lr_ok = has_lr(lay.doors)
		if lr_ok and CONFIDENT_MATCH[mk] then
			row.usable_lr_confident = row.usable_lr_confident + 1
			counts.usable_lr_confident = counts.usable_lr_confident + 1
		elseif lr_ok and WEAK_MATCH[mk] then
			row.usable_lr_weak = row.usable_lr_weak + 1
			counts.usable_lr_weak = counts.usable_lr_weak + 1
		end
	end

	if #row.sample_variants < 4 then
		row.sample_variants[#row.sample_variants + 1] = {
			ref = lay.ref,
			variant = lay.variant,
			subtype = lay.subtype,
			doors = lay.doors,
			weight = lay.weight,
			match_kind = mk,
			source = lay.source,
			in_pool = in_pool,
		}
	end
end

local function ingest_other_shape(by_boss, lay, def, pool_ids)
	local id = catalog.canonical_boss_id(lay.boss_id)
	if not id or not pool_ids[id] then
		return
	end
	local row = ensure_boss_row(by_boss, id, def)
	row.layouts_other_shape = row.layouts_other_shape + 1
	if #row.sample_other_shape < 4 then
		row.sample_other_shape[#row.sample_other_shape + 1] = {
			ref = lay.ref,
			variant = lay.variant,
			subtype = lay.subtype,
			doors = lay.doors,
			shape = lay.shape,
			source = lay.source,
			match_kind = lay.match and lay.match.match_kind,
		}
	end
end

--- selectable_for_89: pool + confident 1x1 LR + positive weight + not horseman-only + not unsupported_shape.
local function compute_selectable(boss_rows, def)
	local selectable = {}
	local blocked = {}
	for _, row in ipairs(boss_rows) do
		if row.in_pool then
			local reason = nil
			if row.unsupported_shape or row.special_role == "unsupported_shape" then
				reason = "unsupported_shape"
			elseif row.special_role == "mother_gate_neg10" then
				reason = "mother_gate_not_89_fight"
			elseif row.only_replace_horsemen then
				reason = "horseman_only_replace"
			elseif (tonumber(row.weight) or 0) <= 0 then
				reason = "zero_weight"
			elseif (row.usable_lr_confident or 0) <= 0 then
				if (row.usable_lr_weak or 0) > 0 then
					reason = "weak_identity_only"
				elseif (row.layouts_other_shape or 0) > 0 then
					reason = "other_shape_only"
				elseif (row.layouts_total or 0) == 0 then
					reason = "no_layout"
				else
					reason = "no_confident_lr"
				end
			end
			if reason then
				blocked[#blocked + 1] = {id = row.id, reason = reason}
			else
				selectable[#selectable + 1] = {
					id = row.id,
					weight = row.weight,
					usable_lr_confident = row.usable_lr_confident,
				}
			end
		end
	end
	table.sort(selectable, function(a, b)
		return tostring(a.id) < tostring(b.id)
	end)
	table.sort(blocked, function(a, b)
		return tostring(a.id) < tostring(b.id)
	end)
	return selectable, blocked
end

local function lookup_fixed_variant(stb, room_type, variant)
	local holder = room_config_holder()
	if not holder or not holder.GetRoomByStageTypeAndVariant then
		return nil, "no_RoomConfig"
	end
	local cfg = nil
	pcall(function()
		cfg = holder.GetRoomByStageTypeAndVariant(stb, room_type, variant, 0)
	end)
	if not cfg then
		pcall(function()
			cfg = holder.GetRoomByStageTypeAndVariant(stb, room_type, variant, -1)
		end)
	end
	if not cfg then
		return nil, "variant_not_found"
	end
	return {
		stb = stb,
		type = cfg.Type,
		variant = cfg.Variant,
		subtype = cfg.Subtype,
		shape = cfg.Shape,
		doors = cfg.Doors,
		name = cfg.Name,
		spawn_count = cfg.SpawnCount,
	}, nil
end

local function audit_mother_corpse_ii(entity_index)
	local plan = catalog.MOTHER_CORPSE_II
	local report = {
		status = "pending",
		entry_89 = nil,
		arena_neg10 = {},
		notes = {},
	}
	if not plan then
		report.status = "no_plan"
		return report
	end
	local entry_cfg, entry_err = lookup_fixed_variant(
		plan.entry_89.source_stb,
		RoomType.ROOM_BOSS,
		plan.entry_89.variant
	)
	if not entry_cfg then
		-- Also try ROOM_DEFAULT / other types for gate rooms.
		local alt = nil
		pcall(function()
			local holder = room_config_holder()
			alt = holder.GetRoomByStageTypeAndVariant(plan.entry_89.source_stb, RoomType.ROOM_DEFAULT, plan.entry_89.variant, 0)
		end)
		if alt then
			entry_cfg = {
				stb = plan.entry_89.source_stb,
				type = alt.Type,
				variant = alt.Variant,
				subtype = alt.Subtype,
				shape = alt.Shape,
				doors = alt.Doors,
				name = alt.Name,
				spawn_count = alt.SpawnCount,
			}
			report.notes[#report.notes + 1] = "entry_6000_is_ROOM_DEFAULT"
		else
			report.notes[#report.notes + 1] = "entry_6000_missing:" .. tostring(entry_err)
		end
	end
	if entry_cfg then
		report.entry_89 = entry_cfg
		report.notes[#report.notes + 1] = string.format(
			"entry_6000 type=%s shape=%s doors=%s subtype=%s",
			tostring(entry_cfg.type),
			tostring(entry_cfg.shape),
			tostring(entry_cfg.doors),
			tostring(entry_cfg.subtype)
		)
	end

	local corpse_1x1, corpse_other = M.enumerate_boss_layouts(plan.arena_neg10.source_stb, {
		source = "corpse",
		entity_index = entity_index,
		require_1x1 = true,
	})
	local prefer = {}
	for _, sh in ipairs(plan.arena_neg10.prefer_shapes or {}) do
		prefer[sh] = true
	end
	local arenas = {}
	local function consider(lay)
		local id = catalog.canonical_boss_id(lay.boss_id)
		if id ~= plan.arena_neg10.boss_id then
			-- Also accept subtype Mother.
			if catalog.boss_id_from_subtype(lay.subtype) ~= plan.arena_neg10.boss_id then
				return
			end
		end
		arenas[#arenas + 1] = {
			ref = lay.ref,
			variant = lay.variant,
			subtype = lay.subtype,
			shape = lay.shape,
			doors = lay.doors,
			preferred_shape = prefer[lay.shape] == true,
			match_kind = lay.match and lay.match.match_kind,
		}
	end
	for i = 1, #corpse_1x1 do
		consider(corpse_1x1[i])
	end
	for i = 1, #corpse_other do
		consider(corpse_other[i])
	end
	table.sort(arenas, function(a, b)
		if a.preferred_shape ~= b.preferred_shape then
			return a.preferred_shape
		end
		return (tonumber(a.variant) or 0) < (tonumber(b.variant) or 0)
	end)
	report.arena_neg10 = arenas
	report.notes[#report.notes + 1] = "corpse_mother_layouts=" .. tostring(#arenas)
	if entry_cfg and #arenas > 0 then
		report.status = "configs_found"
	elseif entry_cfg then
		report.status = "entry_ok_arena_missing"
	elseif #arenas > 0 then
		report.status = "arena_ok_entry_missing"
	else
		report.status = "missing"
	end
	return report
end

function M.audit_floor(def, shared)
	shared = shared or {}
	local stage = def.stage
	local stage_type = def.stage_type
	if def.all_types then
		stage_type = stage_type or StageType.STAGETYPE_ORIGINAL
	end
	local stb = catalog.stage_to_stb(stage, stage_type)
	local entity_index = shared.entity_index or catalog.build_entity_index()
	shared.entity_index = entity_index

	local stage_layouts = M.enumerate_boss_layouts(stb, {
		source = "stage",
		entity_index = entity_index,
		require_1x1 = true,
	})
	if not shared.special_1x1 then
		local special_1x1, special_other = M.enumerate_boss_layouts(StbType.SPECIAL_ROOMS, {
			source = "special_rooms",
			entity_index = entity_index,
			require_1x1 = true,
		})
		shared.special_1x1 = special_1x1
		shared.special_other_shape = special_other or {}
	end
	local special_layouts = shared.special_1x1 or {}
	local special_other = shared.special_other_shape or {}

	local merged = {}
	local seen = {}
	local function add_list(list)
		for i = 1, #list do
			local lay = list[i]
			local key = layout_dedupe_key(lay)
			if not seen[key] then
				seen[key] = true
				merged[#merged + 1] = lay
			end
		end
	end
	add_list(stage_layouts)
	add_list(special_layouts)

	-- Register unique layouts into shared registry (once per scan).
	shared.layout_registry = shared.layout_registry or {}
	for i = 1, #merged do
		local lay = merged[i]
		local ref = lay.ref
		if ref and not shared.layout_registry[ref] then
			shared.layout_registry[ref] = {
				ref = ref,
				stb = lay.stb,
				source = lay.source,
				variant = lay.variant,
				subtype = lay.subtype,
				shape = lay.shape,
				doors = lay.doors,
				weight = lay.weight,
				difficulty = lay.difficulty,
				name = lay.name,
				spawn_count = lay.spawn_count,
				boss_id = lay.boss_id,
				match_kind = lay.match and lay.match.match_kind,
				spawn_hits = lay.match and lay.match.spawn_hits,
			}
		end
	end
	for i = 1, #special_other do
		local lay = special_other[i]
		local ref = lay.ref
		if ref and not shared.layout_registry[ref] then
			shared.layout_registry[ref] = {
				ref = ref,
				stb = lay.stb,
				source = lay.source,
				variant = lay.variant,
				subtype = lay.subtype,
				shape = lay.shape,
				doors = lay.doors,
				weight = lay.weight,
				boss_id = lay.boss_id,
				match_kind = lay.match and lay.match.match_kind,
				other_shape = true,
			}
		end
	end

	local pool_ids = {}
	local by_boss = {}
	for _, be in ipairs(def.bosses or {}) do
		local cid = catalog.canonical_boss_id(be.id)
		if cid then
			pool_ids[cid] = true
			local row = ensure_boss_row(by_boss, cid, def)
			row.in_pool = true
			row.weight = tonumber(be.weight) or 1
			row.horseman = be.horseman == true
			row.only_replace_horsemen = be.only_replace_horsemen == true
			row.only_replace_subtype = be.only_replace_subtype
			row.special_role = classify_special_role(def, cid)
			row.unsupported_shape = catalog.is_unsupported_shape_for_89(cid)
		end
	end

	local counts = {
		raw = 0,
		raw_stage = 0,
		raw_special = 0,
		identified = 0,
		in_pool = 0,
		usable_lr_confident = 0,
		usable_lr_weak = 0,
		unmatched = 0,
		ambiguous = 0,
		conflict = 0,
		match_kinds = {},
	}

	for i = 1, #merged do
		ingest_layout(by_boss, merged[i], def, counts, pool_ids)
	end
	for i = 1, #special_other do
		ingest_other_shape(by_boss, special_other[i], def, pool_ids)
	end

	local boss_rows = {}
	for _, row in pairs(by_boss) do
		-- Floor report: only pool bosses (+ conflicts that hit pool? keep pool-only for compact).
		if row.in_pool then
			boss_rows[#boss_rows + 1] = row
		end
	end
	table.sort(boss_rows, function(a, b)
		return tostring(a.id) < tostring(b.id)
	end)

	local selectable, blocked = compute_selectable(boss_rows, def)

	local pool_with_lr = 0
	local pool_with_lr_confident = 0
	local pool_no_layout = 0
	local pool_no_lr = 0
	local pool_only_weak_lr = 0
	local pool_other_shape_only = 0
	local pool_unsupported_shape = 0
	for _, row in ipairs(boss_rows) do
		local conf = row.usable_lr_confident or 0
		local weak = row.usable_lr_weak or 0
		if row.unsupported_shape then
			pool_unsupported_shape = pool_unsupported_shape + 1
		elseif row.layouts_total == 0 and (row.layouts_other_shape or 0) == 0 then
			pool_no_layout = pool_no_layout + 1
		elseif conf > 0 then
			pool_with_lr_confident = pool_with_lr_confident + 1
			pool_with_lr = pool_with_lr + 1
		elseif weak > 0 then
			pool_only_weak_lr = pool_only_weak_lr + 1
			pool_with_lr = pool_with_lr + 1
		elseif (row.layouts_other_shape or 0) > 0 then
			pool_other_shape_only = pool_other_shape_only + 1
		else
			pool_no_lr = pool_no_lr + 1
		end
	end

	local anomalies = {}
	if #(def.bosses or {}) == 0 and def.pool_mode ~= "void_mixed" then
		anomalies[#anomalies + 1] = "empty_pool"
	end
	if def.role_89 == "mother_gate" then
		anomalies[#anomalies + 1] = "mother_gate_89_neg10_split"
	end
	if def.role_89 == "delirium" then
		anomalies[#anomalies + 1] = "delirium_void_3414_2x2"
	end
	if def.pool_mode == "weighted" or def.pool_mode == "inherit" then
		if pool_no_layout > 0 then
			anomalies[#anomalies + 1] = "pool_boss_without_layout:" .. tostring(pool_no_layout)
		end
		if pool_no_lr > 0 then
			anomalies[#anomalies + 1] = "pool_boss_without_lr:" .. tostring(pool_no_lr)
		end
		if pool_only_weak_lr > 0 then
			anomalies[#anomalies + 1] = "pool_boss_only_weak_lr:" .. tostring(pool_only_weak_lr)
		end
		if pool_unsupported_shape > 0 then
			anomalies[#anomalies + 1] = "pool_boss_unsupported_shape:" .. tostring(pool_unsupported_shape)
		end
		if #selectable == 0 and def.role_89 ~= "mother_gate" and def.role_89 ~= "delirium" then
			anomalies[#anomalies + 1] = "no_selectable_boss_for_89"
		end
	elseif def.fixed and def.role_89 ~= "mother_gate" and def.role_89 ~= "delirium" then
		if pool_with_lr_confident == 0 and pool_only_weak_lr == 0 then
			if pool_other_shape_only > 0 then
				anomalies[#anomalies + 1] = "fixed_boss_other_shape_only"
			else
				anomalies[#anomalies + 1] = "fixed_boss_no_1x1_lr_review"
			end
		elseif pool_with_lr_confident == 0 and pool_only_weak_lr > 0 then
			anomalies[#anomalies + 1] = "fixed_boss_only_weak_lr_review"
		end
	end
	if counts.conflict > 0 then
		anomalies[#anomalies + 1] = "match_conflicts:" .. tostring(counts.conflict)
	end

	local ext = stageapi_extension_for_floor(stage, stage_type)
	for _, eb in ipairs(ext.bosses or {}) do
		if eb.base_game ~= true and eb.has_rooms and (eb.valid_lr == 0 or eb.valid_lr == nil) then
			anomalies[#anomalies + 1] = "stageapi_ext_no_lr:" .. tostring(eb.id)
		end
	end

	return {
		stage = stage,
		stage_type = stage_type,
		stb = stb,
		prefix = def.prefix,
		pool_mode = def.pool_mode,
		fixed = def.fixed == true,
		role_89 = def.role_89,
		role_neg10 = def.role_neg10,
		note = def.note,
		pool_boss_count = #(def.bosses or {}),
		layout_count_stage = #stage_layouts,
		layout_count_special = #special_layouts,
		layout_count_merged = #merged,
		layout_count_other_shape_special = #special_other,
		layouts_identified = counts.identified,
		layouts_in_pool = counts.in_pool,
		layouts_usable_lr_confident = counts.usable_lr_confident,
		layouts_usable_lr_weak = counts.usable_lr_weak,
		match_kind_counts = counts.match_kinds,
		layout_count = #merged,
		special_layout_count = #special_layouts,
		pool_with_lr = pool_with_lr,
		pool_with_lr_confident = pool_with_lr_confident,
		pool_only_weak_lr = pool_only_weak_lr,
		pool_no_layout = pool_no_layout,
		pool_no_lr = pool_no_lr,
		pool_other_shape_only = pool_other_shape_only,
		pool_unsupported_shape = pool_unsupported_shape,
		selectable_bosses_for_89 = selectable,
		selectable_count = #selectable,
		blocked_bosses_for_89 = blocked,
		unmatched_layouts = counts.unmatched,
		ambiguous_matches = counts.ambiguous,
		conflict_matches = counts.conflict,
		anomalies = anomalies,
		bosses = boss_rows,
		stageapi = ext,
		door_set_labels = door_sets(),
		candidate_sources = {"stage", "special_rooms"},
	}
end

local function collect_unique_issues(floors)
	local groups = {
		identity_conflicts = {},
		unsupported_shape = {},
		weak_identity = {},
		no_selectable = {},
		fixed_review = {},
		mother = {},
		other = {},
	}
	local function add_unique(bucket, key, sample)
		if not bucket[key] then
			bucket[key] = {key = key, count = 0, sample = sample}
		end
		bucket[key].count = bucket[key].count + 1
	end
	for _, f in ipairs(floors) do
		for _, b in ipairs(f.bosses or {}) do
			if b.in_pool then
				if (b.match_kinds and b.match_kinds.subtype_spawn_conflict or 0) > 0 then
					add_unique(groups.identity_conflicts, b.id, {
						stage = f.stage,
						stage_type = f.stage_type,
					})
				end
				if b.unsupported_shape then
					add_unique(groups.unsupported_shape, b.id, {
						other_shape = b.layouts_other_shape,
					})
				end
				if (b.usable_lr_confident or 0) == 0 and (b.usable_lr_weak or 0) > 0 then
					add_unique(groups.weak_identity, b.id, {
						weak = b.usable_lr_weak,
					})
				end
			end
		end
		if f.role_89 == "mother_gate" then
			add_unique(groups.mother, "corpse_ii_mother_gate", {
				stage = f.stage,
				stage_type = f.stage_type,
			})
		end
		for _, a in ipairs(f.anomalies or {}) do
			if a:find("no_selectable", 1, true) then
				add_unique(groups.no_selectable, tostring(f.stage) .. ":" .. tostring(f.stage_type), {anomaly = a})
			elseif a:find("fixed_boss", 1, true) then
				add_unique(groups.fixed_review, a, {stage = f.stage})
			elseif a:find("match_conflicts", 1, true) then
				-- counted via bosses
			elseif a:find("unsupported_shape", 1, true) then
				-- counted via bosses
			elseif a:find("mother_gate", 1, true) then
				-- counted
			else
				add_unique(groups.other, a, {stage = f.stage, stage_type = f.stage_type})
			end
		end
	end
	local function flatten(bucket)
		local list = {}
		for _, v in pairs(bucket) do
			list[#list + 1] = v
		end
		table.sort(list, function(a, b)
			return tostring(a.key) < tostring(b.key)
		end)
		return list
	end
	return {
		identity_conflicts = flatten(groups.identity_conflicts),
		unsupported_shape = flatten(groups.unsupported_shape),
		weak_identity = flatten(groups.weak_identity),
		no_selectable = flatten(groups.no_selectable),
		fixed_review = flatten(groups.fixed_review),
		mother = flatten(groups.mother),
		other = flatten(groups.other),
	}
end

function M.scan_all()
	local targets = catalog.list_scan_targets()
	local floors = {}
	local anomaly_total = 0
	local summary_rows = {}
	local shared = {}
	local stageapi_reasons = {}
	local sa_cand_ids = {}
	local sa_usable_ids = {}
	local sa_rejected = {}
	local sa_reject_reason_counts = {}
	local stageapi_loaded = StageAPI ~= nil
	for i = 1, #targets do
		local def = targets[i]
		local row = M.audit_floor(def, shared)
		floors[#floors + 1] = row
		anomaly_total = anomaly_total + #(row.anomalies or {})
		local reason = row.stageapi and row.stageapi.reason or "unknown"
		stageapi_reasons[reason] = (stageapi_reasons[reason] or 0) + 1
		for _, eb in ipairs((row.stageapi and row.stageapi.bosses) or {}) do
			if eb and eb.base_game ~= true and type(eb.id) == "string" then
				sa_cand_ids[eb.id] = true
				if (tonumber(eb.valid_lr) or 0) > 0 then
					sa_usable_ids[eb.id] = true
					sa_rejected[eb.id] = nil
				elseif not sa_usable_ids[eb.id] and not sa_rejected[eb.id] then
					sa_rejected[eb.id] = {
						id = eb.id,
						reject = eb.reject or "no_valid_lr",
						sample_stage = row.stage,
						sample_stage_type = row.stage_type,
						rooms_list_name = eb.rooms_list_name,
						rooms_list_count = eb.rooms_list_count,
						rooms_list_total = eb.rooms_list_total,
						layout_filter = eb.layout_filter,
					}
				end
			end
		end
		summary_rows[#summary_rows + 1] = {
			stage = row.stage,
			stage_type = row.stage_type,
			stb = row.stb,
			pool = row.pool_boss_count,
			layouts_stage = row.layout_count_stage,
			layouts_merged = row.layout_count_merged,
			identified = row.layouts_identified,
			in_pool = row.layouts_in_pool,
			usable_lr = row.layouts_usable_lr_confident,
			usable_lr_weak = row.layouts_usable_lr_weak,
			selectable = row.selectable_count,
			pool_lr_confident = row.pool_with_lr_confident,
			unsupported_shape = row.pool_unsupported_shape,
			no_layout = row.pool_no_layout,
			anomalies = row.anomalies,
			role_89 = row.role_89,
			fixed = row.fixed,
			stageapi_reason = reason,
			stageapi_boss_candidates = row.stageapi and row.stageapi.stageapi_boss_candidates or 0,
			stageapi_usable_lr = row.stageapi and row.stageapi.stageapi_usable_lr or 0,
			stageapi_rejected_count = row.stageapi and #(row.stageapi.stageapi_rejected or {}) or 0,
		}
	end

	local layouts = {}
	for _, v in pairs(shared.layout_registry or {}) do
		layouts[#layouts + 1] = v
	end
	table.sort(layouts, function(a, b)
		return tostring(a.ref) < tostring(b.ref)
	end)

	local unique_issues = collect_unique_issues(floors)
	local mother = audit_mother_corpse_ii(shared.entity_index)

	local sa_cand_n, sa_usable_n = 0, 0
	for _ in pairs(sa_cand_ids) do
		sa_cand_n = sa_cand_n + 1
	end
	for _ in pairs(sa_usable_ids) do
		sa_usable_n = sa_usable_n + 1
	end
	local sa_rej_list = {}
	for _, v in pairs(sa_rejected) do
		sa_rej_list[#sa_rej_list + 1] = v
		local rr = v.reject or "no_valid_lr"
		sa_reject_reason_counts[rr] = (sa_reject_reason_counts[rr] or 0) + 1
	end
	table.sort(sa_rej_list, function(a, b)
		local ra = tostring(a.reject or "")
		local rb = tostring(b.reject or "")
		if ra ~= rb then
			return ra < rb
		end
		return tostring(a.id) < tostring(b.id)
	end)

	return {
		schema = "golden_compass_boss_pool_audit",
		schema_version = SCHEMA_VERSION,
		catalog_source = catalog.SOURCE,
		catalog_schema = catalog.SCHEMA_VERSION,
		candidate_sources = {"stage_stb", "SPECIAL_ROOMS"},
		scanned_at_game_frame = (function()
			local n = 0
			pcall(function()
				n = Game():GetFrameCount()
			end)
			return n
		end)(),
		floor_count = #floors,
		anomaly_total = anomaly_total,
		unique_layout_count = #layouts,
		stageapi_reason_counts = stageapi_reasons,
		stageapi_loaded = stageapi_loaded,
		stageapi_audit_seed = STAGEAPI_AUDIT_SEED,
		stageapi_boss_candidates = stageapi_loaded and sa_cand_n or nil,
		stageapi_usable_lr = stageapi_loaded and sa_usable_n or nil,
		stageapi_rejected = stageapi_loaded and sa_rej_list or nil,
		stageapi_reject_reason_counts = stageapi_loaded and sa_reject_reason_counts or nil,
		unique_issues = unique_issues,
		mother_corpse_ii = mother,
		summary = summary_rows,
		-- Deduped global layout table; floors reference via boss.layout_refs.
		layouts = layouts,
		floors = floors,
	}
end

--- Compact human summary (Copy Summary).
function M.format_summary(report)
	if not report then
		return "boss_pool_audit: no report"
	end
	local ui = report.unique_issues or {}
	local function n(list)
		return #(list or {})
	end
	local sa = report.stageapi_reason_counts or {}
	local sa_bits = {}
	for k, v in pairs(sa) do
		sa_bits[#sa_bits + 1] = tostring(k) .. "=" .. tostring(v)
	end
	table.sort(sa_bits)
	local lines = {
		string.format("Boss Pool Audit v%s", tostring(report.schema_version)),
		string.format(
			"Floors: %s | Unique layouts: %s | Anomaly rows: %s",
			tostring(report.floor_count),
			tostring(report.unique_layout_count),
			tostring(report.anomaly_total)
		),
		"StageAPI: " .. (#sa_bits > 0 and table.concat(sa_bits, ", ") or "n/a"),
		string.format(
			"StageAPI extension unique: candidates=%s usable_lr=%s rejected=%s seed=0x%08X",
			tostring(report.stageapi_boss_candidates),
			tostring(report.stageapi_usable_lr),
			tostring(n(report.stageapi_rejected)),
			tonumber(report.stageapi_audit_seed or STAGEAPI_AUDIT_SEED) or 0
		),
	}
	local sa_rej_bits = {}
	for k, v in pairs(report.stageapi_reject_reason_counts or {}) do
		sa_rej_bits[#sa_rej_bits + 1] = tostring(k) .. "=" .. tostring(v)
	end
	table.sort(sa_rej_bits)
	lines[#lines + 1] = "StageAPI reject reasons: "
		.. (#sa_rej_bits > 0 and table.concat(sa_rej_bits, ", ") or "none")
	local sa_rej = report.stageapi_rejected or {}
	if #sa_rej > 0 then
		lines[#lines + 1] = "StageAPI rejected (formal: total→1x1→LR→POST_CHECK; Type diagnostic):"
		local lim = 30
		for i = 1, math.min(#sa_rej, lim) do
			local r = sa_rej[i]
			local lf = r.layout_filter
			lines[#lines + 1] = string.format(
				"  - %s rej=%s list=%s",
				tostring(r.id),
				tostring(r.reject),
				tostring(r.rooms_list_name)
			)
			if type(lf) == "table" then
				lines[#lines + 1] = "      " .. format_layout_filter_short(lf)
				local hist = format_type_histogram(lf.type_histogram, 6)
				if hist ~= "" then
					lines[#lines + 1] = "      1x1 types: " .. hist
				end
			end
		end
		if #sa_rej > lim then
			lines[#lines + 1] = string.format("  ... (+%s; see full JSON)", tostring(#sa_rej - lim))
		end
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = string.format("Identity conflict bosses: %s", n(ui.identity_conflicts))
	lines[#lines + 1] = string.format("Unsupported-shape bosses: %s", n(ui.unsupported_shape))
	lines[#lines + 1] = string.format("Weak-identity bosses: %s", n(ui.weak_identity))
	lines[#lines + 1] = string.format("Floors with no selectable boss: %s", n(ui.no_selectable))
	lines[#lines + 1] = string.format("Fixed-boss review flags: %s", n(ui.fixed_review))
	local function dump_keys(title, list, limit)
		if n(list) == 0 then
			return
		end
		lines[#lines + 1] = title
		limit = limit or 12
		for i = 1, math.min(#list, limit) do
			local it = list[i]
			lines[#lines + 1] = string.format("  - %s (floors=%s)", tostring(it.key), tostring(it.count))
		end
		if #list > limit then
			lines[#lines + 1] = "  ..."
		end
	end
	dump_keys("Conflicts:", ui.identity_conflicts)
	dump_keys("Unsupported shape:", ui.unsupported_shape)
	dump_keys("Weak identity:", ui.weak_identity)
	dump_keys("No selectable:", ui.no_selectable)

	local mother = report.mother_corpse_ii
	if mother then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Mother gate/arena: " .. tostring(mother.status)
		for _, note in ipairs(mother.notes or {}) do
			lines[#lines + 1] = "  " .. tostring(note)
		end
		if mother.entry_89 then
			lines[#lines + 1] = string.format(
				"  entry_89 variant=%s type=%s shape=%s doors=%s",
				tostring(mother.entry_89.variant),
				tostring(mother.entry_89.type),
				tostring(mother.entry_89.shape),
				tostring(mother.entry_89.doors)
			)
		end
		lines[#lines + 1] = string.format("  arena candidates=%s", tostring(#(mother.arena_neg10 or {})))
		for i = 1, math.min(3, #(mother.arena_neg10 or {})) do
			local a = mother.arena_neg10[i]
			lines[#lines + 1] = string.format(
				"    v=%s shape=%s doors=%s preferred=%s",
				tostring(a.variant),
				tostring(a.shape),
				tostring(a.doors),
				tostring(a.preferred_shape)
			)
		end
	end

	-- Fixed bosses quick OK line
	lines[#lines + 1] = ""
	lines[#lines + 1] = "Fixed bosses (confident LR):"
	for _, f in ipairs(report.floors or {}) do
		if f.fixed and f.role_89 ~= "mother_gate" then
			local bits = {}
			for _, b in ipairs(f.bosses or {}) do
				if b.in_pool then
					bits[#bits + 1] = string.format("%s=%s", b.id, tostring(b.usable_lr_confident or 0))
				end
			end
			lines[#lines + 1] = string.format(
				"  stage=%s type=%s %s",
				tostring(f.stage),
				tostring(f.stage_type),
				table.concat(bits, ", ")
			)
		end
	end
	return table.concat(lines, "\n")
end

return M
