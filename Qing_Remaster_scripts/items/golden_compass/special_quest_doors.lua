-- Golden Compass: Entry Mirror / Abandoned Mineshaft doors.
-- Mirror: grid_doors virtual door + Room_holder FADE_MIRROR dimension swap (no StageAPI).
-- Mines II: custom virtual UP0 planks door (door_mines_mineshaft_light + door_mines_planks);
--   0→1→2 boom hits floor-persist; enter validates Dim1 SGID 162 then Room_holder.Trans_to.
-- Other mineshaft (Ashpit): native Room:TrySpawnSpecialQuestDoor.
-- No TargetRoomIndex=-100 forge. No own MC_* callbacks.

local M = {}

local deps = nil
-- deps: runtime, compass_floor, corridor_plan, read_level_identity, push_event,
--       entry_sgid, snapshot_special_door, grid_door, Room_holder

local MIRROR_DOOR_ID = "gc_entry_mirror"
local MIRROR_ANM2 = "gfx/grid/door_downpour_mirror.anm2"
local MINESHAFT_DOOR_ID = "gc_entry_mineshaft"
local MINESHAFT_RETURN_DOOR_ID = "gc_mineshaft_reward_return"
-- Outer (Mines II 78): dark ANM2 has Collapse/Collapsed. Inner (reward 162): light.
local MINESHAFT_DOOR_ANM2_OUTER = "gfx/grid/door_mines_mineshaft_dark.anm2"
local MINESHAFT_DOOR_ANM2_INNER = "gfx/grid/door_mines_mineshaft_light.anm2"
local MINESHAFT_PLANKS_ANM2 = "gfx/grid/door_18_crackeddoor.anm2"
local MINESHAFT_TARGET_SGID = 162
local MINESHAFT_PLANKS_MAX = 2
local MINESHAFT_REWARD_VARIANT = 25605
local KNIFE_PIECE_2 = (CollectibleType and CollectibleType.COLLECTIBLE_KNIFE_PIECE_2) or 627
local mineshaft_dim_observer = nil
local virtual_door_life_observer = nil
local VIRTUAL_DOOR_DEPTH = -1000
local MINESHAFT_TEXTURE_FLAGS = (EntityFlag.FLAG_RENDER_WALL or 0) | (EntityFlag.FLAG_RENDER_FLOOR or 0)
local MINESHAFT_COLLAPSE_FX_MODE = "gc_mineshaft_collapse_fx"
local SORTING_NORMAL = (SortingLayer and SortingLayer.SORTING_NORMAL) or 2
-- Forward decls (used by read_special_quest_dimension before definitions).
local mines_ii_custom_door_enabled
local mineshaft_target_ready
local DIM_NORMAL = (Dimension and Dimension.NORMAL) or 0
local DIM_KNIFE = (Dimension and Dimension.KNIFE_PUZZLE) or 1
local NULL_LOST_CURSE = (NullItemID and NullItemID.ID_LOST_CURSE) or 112
local PT_LOST = (PlayerType and PlayerType.PLAYER_THELOST) or 10
local PT_LOST_B = (PlayerType and PlayerType.PLAYER_THELOST_B) or 31
local PT_JACOB2_B = (PlayerType and PlayerType.PLAYER_JACOB2_B) or 39
local PT_SOUL_B = (PlayerType and PlayerType.PLAYER_THESOUL_B) or 40

local function d()
	return deps
end

local function is_mirror_shattered()
	local ok, broken = pcall(function()
		return Game():GetLevel():GetStateFlag(LevelStateFlag.STATE_MIRROR_BROKEN) == true
	end)
	return ok and broken == true
end

--- k91 Soul of the Lost applies NullItemID.ID_LOST_CURSE (confirmed via Docs + FFG IsPlayerLosted).
local function is_player_losted(player)
	if not player then
		return false
	end
	local pt = nil
	pcall(function()
		pt = player:GetPlayerType()
	end)
	if pt == PT_LOST or pt == PT_LOST_B or pt == PT_JACOB2_B or pt == PT_SOUL_B then
		return true
	end
	local lost_curse = false
	pcall(function()
		local effects = player:GetEffects()
		if effects and effects.HasNullEffect then
			lost_curse = effects:HasNullEffect(NULL_LOST_CURSE) == true
		end
	end)
	return lost_curse
end

local function any_player_losted()
	local n = Game():GetNumPlayers()
	for i = 0, n - 1 do
		if is_player_losted(Game():GetPlayer(i)) then
			return true
		end
	end
	return false
end

local function any_player_has_knife_piece_1(item_id)
	item_id = tonumber(item_id) or 626
	local n = Game():GetNumPlayers()
	for i = 0, n - 1 do
		local p = Game():GetPlayer(i)
		if p and p:HasCollectible(item_id) then
			return true
		end
	end
	return false
end

local function slot_allowed(room, slot)
	local ok, allowed = pcall(function()
		return room:IsDoorSlotAllowed(slot) == true
	end)
	return ok and allowed == true
end

local function snapshot_door_slots(room)
	local slots = {}
	pcall(function()
		local n = (DoorSlot and DoorSlot.NUM_DOOR_SLOTS) or 8
		for s = 0, n - 1 do
			local door = room:GetDoor(s)
			local allowed = slot_allowed(room, s)
			if door or allowed then
				slots[#slots + 1] = {
					slot = s,
					allowed = allowed,
					present = door ~= nil,
					target = door and door.TargetRoomIndex or nil,
					variant = door and door.Variant or nil,
					open = door and (door:IsOpen() == true) or nil,
				}
			end
		end
	end)
	return slots
end

local function read_room_env(level, room, desc)
	local id = d().read_level_identity()
	local starting = id.starting_room_index
	local current = id.current_room_index
	local abs_stage, dimension = nil, nil
	pcall(function()
		if level.GetAbsoluteStage then
			abs_stage = level:GetAbsoluteStage()
		end
	end)
	pcall(function()
		if level.GetDimension then
			dimension = level:GetDimension()
		end
	end)
	local data_doors = nil
	pcall(function()
		if desc and desc.Data and desc.Data.Doors ~= nil then
			data_doors = desc.Data.Doors
		end
	end)
	return {
		stage = id.stage,
		stage_type = id.stage_type,
		absolute_stage = abs_stage,
		dimension = dimension,
		current_room_index = current,
		starting_room_index = starting,
		is_starting_room = starting ~= nil and current ~= nil and tonumber(current) == tonumber(starting),
		room_type = desc and desc.Data and desc.Data.Type,
		room_variant = desc and desc.Data and desc.Data.Variant,
		room_shape = desc and desc.Data and desc.Data.Shape,
		allowed_doors = desc and desc.AllowedDoors,
		data_doors = data_doors,
		door_slots = snapshot_door_slots(room),
	}
end

local function current_dimension(level)
	local dim = nil
	pcall(function()
		if level and level.GetDimension then
			dim = level:GetDimension()
		end
	end)
	if dim ~= nil then
		return tonumber(dim)
	end
	local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
	if auxi.GetDimension then
		return tonumber(auxi.GetDimension())
	end
	return DIM_NORMAL
end

local function room_index_for_transition(level)
	local idx = nil
	pcall(function()
		idx = level:GetCurrentRoomIndex()
	end)
	if idx ~= nil then
		return idx
	end
	return d().entry_sgid
end

local function read_desc_seeds(desc)
	local spawn_seed, decoration_seed, award_seed, visited = nil, nil, nil, nil
	if not desc then
		return spawn_seed, decoration_seed, award_seed, visited, false
	end
	pcall(function()
		spawn_seed = desc.SpawnSeed
		decoration_seed = desc.DecorationSeed
		award_seed = desc.AwardSeed
		visited = desc.VisitedCount
	end)
	local seeds_ok = tonumber(spawn_seed) ~= nil and spawn_seed > 0
		and tonumber(decoration_seed) ~= nil and decoration_seed > 0
		and tonumber(award_seed) ~= nil and award_seed > 0
	return spawn_seed, decoration_seed, award_seed, visited, seeds_ok == true
end

local function read_dimension_room(level, room_index, dimension)
	local desc = nil
	local err = nil
	local ok, ret = pcall(function()
		return level:GetRoomByIdx(room_index, dimension)
	end)
	if ok then
		desc = ret
	else
		err = tostring(ret)
	end
	local has_data = desc ~= nil and desc.Data ~= nil
	local spawn_seed, decoration_seed, award_seed, visited, seeds_ok = read_desc_seeds(desc)
	local safe = desc and desc.SafeGridIndex or nil
	local list_index = desc and desc.ListIndex or nil
	local safe_ok = true
	-- Normal grid rooms must keep SafeGridIndex == requested index (Data-only stubs often get -1).
	if room_index ~= nil and tonumber(room_index) >= 0 then
		safe_ok = tonumber(safe) == tonumber(room_index)
	end
	local list_ok = list_index ~= nil and tonumber(list_index) >= 0
	return {
		-- Ready for FADE_MIRROR only when registered: Data + seeds + SafeGridIndex + ListIndex.
		ok = has_data == true and seeds_ok == true and safe_ok == true and list_ok == true,
		error = err,
		room_index = room_index,
		dimension = dimension,
		has_desc = desc ~= nil,
		has_data = has_data,
		seeds_ok = seeds_ok == true,
		safe_ok = safe_ok == true,
		list_ok = list_ok == true,
		safe_grid_index = safe,
		list_index = list_index,
		spawn_seed = spawn_seed,
		decoration_seed = decoration_seed,
		award_seed = award_seed,
		room_type = has_data and desc.Data.Type or nil,
		room_variant = has_data and desc.Data.Variant or nil,
		visited = visited,
		has_override = desc ~= nil and desc.OverrideData ~= nil,
	}
end

function M.resolve_special_quest_door_rule()
	local runtime = d().runtime
	local stage, stage_type = nil, nil
	if runtime.pending then
		stage = runtime.pending.restore_stage
		stage_type = runtime.pending.restore_stage_type
	end
	if stage == nil then
		local id = d().read_level_identity()
		stage = id.stage
		stage_type = id.stage_type
	end
	local plan = d().corridor_plan
	if plan and plan.get_special_quest_door_rule then
		return plan.get_special_quest_door_rule(stage, stage_type)
	end
	return {
		eligible = false,
		reason = "no_rule_api",
		stage = stage,
		stage_type = stage_type,
	}
end

function M.find_special_quest_door(room, target_idx)
	if not room or target_idx == nil then
		return nil, nil
	end
	local found_door, found_slot = nil, nil
	pcall(function()
		local n = (DoorSlot and DoorSlot.NUM_DOOR_SLOTS) or 8
		for slot = 0, n - 1 do
			local door = room:GetDoor(slot)
			if door and tonumber(door.TargetRoomIndex) == tonumber(target_idx) then
				found_door = door
				found_slot = slot
				break
			end
		end
	end)
	return found_door, found_slot
end

function M.read_special_quest_dimension(rule)
	local level = Game():GetLevel()
	local has_mirror, has_mineshaft = nil, nil
	local force_quest = nil
	pcall(function()
		if level.HasMirrorDimension then
			has_mirror = level:HasMirrorDimension() == true
		end
	end)
	pcall(function()
		if level.HasAbandonedMineshaft then
			has_mineshaft = level:HasAbandonedMineshaft() == true
		end
	end)
	pcall(function()
		if level.GetForceSpecialQuest then
			force_quest = level:GetForceSpecialQuest()
		end
	end)
	local dim_ok = false
	local reward = nil
	if rule and rule.kind == "mirror" then
		dim_ok = has_mirror == true
	elseif rule and rule.kind == "mineshaft" then
		if mines_ii_custom_door_enabled() then
			-- Mines II: our Dim1/162 reward room — not vanilla HasAbandonedMineshaft.
			reward = mineshaft_target_ready(level)
			dim_ok = reward.ok == true
		else
			dim_ok = has_mineshaft == true
		end
	end
	return {
		has_mirror = has_mirror,
		has_mineshaft = has_mineshaft,
		force_quest = force_quest,
		dimension_ready = dim_ok,
		mineshaft_reward = reward,
	}
end

local function mark_attempted(runtime, visit_key)
	runtime.special_quest_door_attempted_sgid = visit_key
	runtime.special_quest_door_attempted_this_visit = true
end

local function notify_virtual_door_life(kind, extra)
	if not virtual_door_life_observer then
		return
	end
	local row = {
		kind = kind,
		game_frame = Game():GetFrameCount(),
	}
	pcall(function()
		row.room_frame = Game():GetRoom():GetFrameCount()
	end)
	if type(extra) == "table" then
		for k, v in pairs(extra) do
			row[k] = v
		end
	end
	pcall(function()
		virtual_door_life_observer(row)
	end)
end

local function find_custom_mirror_entry()
	local grid_door = d().grid_door
	if grid_door and grid_door.find_door_by_id then
		return grid_door.find_door_by_id(MIRROR_DOOR_ID)
	end
	return nil
end

local function find_custom_mineshaft_entry()
	local grid_door = d().grid_door
	if grid_door and grid_door.find_door_by_id then
		return grid_door.find_door_by_id(MINESHAFT_DOOR_ID)
	end
	return nil
end

local function virtual_entry_anchor_alive(entry)
	return entry
		and entry.anchor
		and entry.anchor.Exists
		and entry.anchor:Exists() == true
		and not (entry.anchor.IsDead and entry.anchor:IsDead())
end

--- Attempted visit key ≠ live door. Virtual mirror/mineshaft must re-check anchor.
local function current_virtual_entry_alive(rule)
	if not rule then
		return false, nil, nil
	end
	if rule.kind == "mirror" then
		local entry = find_custom_mirror_entry()
		return virtual_entry_anchor_alive(entry), entry, MIRROR_DOOR_ID
	end
	if rule.kind == "mineshaft" and mines_ii_custom_door_enabled() then
		local entry = find_custom_mineshaft_entry()
		return virtual_entry_anchor_alive(entry), entry, MINESHAFT_DOOR_ID
	end
	-- Native special-quest door: keep attempt dedupe (no MeusNil owner).
	return true, nil, nil
end

mines_ii_custom_door_enabled = function()
	local plan = d().corridor_plan
	local id = nil
	pcall(function()
		id = d().read_level_identity and d().read_level_identity() or nil
	end)
	if plan and plan.is_mines_ii and id and plan.is_mines_ii(id.stage, id.stage_type) then
		return true
	end
	local cur = Game():GetLevel():GetCurrentRoomDesc()
	local v = cur and cur.Data and tonumber(cur.Data.Variant)
	return v == 25604
		or (plan and plan.ROOM_VARIANT_MINES_II_MINESHAFT_ENTRY and v == plan.ROOM_VARIANT_MINES_II_MINESHAFT_ENTRY)
end

local function get_mineshaft_plank_hits()
	local runtime = d().runtime
	local hits = tonumber(runtime.mineshaft_plank_hits)
	if hits == nil then
		local floor = nil
		pcall(function()
			local state = require("Qing_Remaster_scripts.items.golden_compass.state")
			floor = state.get_floor_persist and state.get_floor_persist() or nil
		end)
		hits = floor and tonumber(floor.mineshaft_plank_hits) or 0
		runtime.mineshaft_plank_hits = hits
	end
	if hits < 0 then
		hits = 0
	elseif hits > MINESHAFT_PLANKS_MAX then
		hits = MINESHAFT_PLANKS_MAX
	end
	return hits
end

local function set_mineshaft_plank_hits(hits)
	hits = math.max(0, math.min(MINESHAFT_PLANKS_MAX, math.floor(tonumber(hits) or 0)))
	local runtime = d().runtime
	runtime.mineshaft_plank_hits = hits
	if d().compass_floor and d().compass_floor.sync_persist then
		d().compass_floor.sync_persist()
	end
	return hits
end

local function mineshaft_target_sgid()
	local plan = d().corridor_plan
	return (plan and tonumber(plan.MINESHAFT_TARGET_SGID)) or MINESHAFT_TARGET_SGID
end

--- Validate Dimension 1 / SGID 162 reward room (no silent fallback to -101).
mineshaft_target_ready = function(level)
	level = level or Game():GetLevel()
	local sgid = mineshaft_target_sgid()
	local desc = nil
	pcall(function()
		desc = level:GetRoomByIdx(sgid, DIM_KNIFE)
	end)
	local row = {
		ok = false,
		room_index = sgid,
		dimension = DIM_KNIFE,
		has_desc = desc ~= nil,
		has_data = desc ~= nil and desc.Data ~= nil,
		safe_grid_index = desc and desc.SafeGridIndex or nil,
		list_index = desc and desc.ListIndex or nil,
	}
	if not desc then
		row.note = "missing_desc"
		return row
	end
	if not desc.Data then
		row.note = "missing_data"
		return row
	end
	if tonumber(desc.SafeGridIndex) ~= tonumber(sgid) then
		row.note = "safe_grid_mismatch"
		return row
	end
	if desc.ListIndex == nil or tonumber(desc.ListIndex) < 0 then
		row.note = "bad_list_index"
		return row
	end
	row.ok = true
	row.note = "ok"
	row.data_type = desc.Data.Type
	row.data_variant = desc.Data.Variant
	local expect_v = MINESHAFT_REWARD_VARIANT
	local plan = d().corridor_plan
	if plan and plan.ROOM_VARIANT_MINES_II_KNIFE2_REWARD then
		expect_v = plan.ROOM_VARIANT_MINES_II_KNIFE2_REWARD
	end
	row.expect_variant = expect_v
	row.variant_ok = tonumber(desc.Data.Variant) == tonumber(expect_v)
	return row
end

local function snapshot_dim1_room(desc, source, queried_sgid)
	if not desc then
		return nil
	end
	local dim = nil
	pcall(function()
		if desc.GetDimension then
			dim = desc:GetDimension()
		end
	end)
	local data = desc.Data
	local name = nil
	pcall(function()
		name = data and data.Name or nil
	end)
	return {
		source = source,
		queried_sgid = queried_sgid,
		safe_grid_index = desc.SafeGridIndex,
		grid_index = desc.GridIndex,
		list_index = desc.ListIndex,
		dimension = dim,
		has_data = data ~= nil,
		data_type = data and data.Type or nil,
		data_variant = data and data.Variant or nil,
		data_subtype = data and data.Subtype or nil,
		data_name = name,
		visited_count = desc.VisitedCount,
	}
end

local function dim1_room_fingerprint(rooms)
	local keys = {}
	for i = 1, #(rooms or {}) do
		local r = rooms[i]
		keys[#keys + 1] = table.concat({
			tostring(r.list_index),
			tostring(r.safe_grid_index),
			tostring(r.data_type),
			tostring(r.data_variant),
			tostring(r.data_subtype),
		}, ":")
	end
	table.sort(keys)
	return table.concat(keys, "|")
end

--- Full Dimension.KNIFE_PUZZLE room inventory (GetRooms + GetRoomByIdx cross-check).
function M.scan_mineshaft_dimension1(tag)
	local level = Game():GetLevel()
	local id = d().read_level_identity and d().read_level_identity() or nil
	local force_quest, has_mineshaft = nil, nil
	pcall(function()
		if level.GetForceSpecialQuest then
			force_quest = level:GetForceSpecialQuest()
		end
	end)
	pcall(function()
		if level.HasAbandonedMineshaft then
			has_mineshaft = level:HasAbandonedMineshaft() == true
		end
	end)
	local target_sgid = mineshaft_target_sgid()
	local by_list = {}
	local rooms = {}

	local function consider(desc, source, queried_sgid)
		local snap = snapshot_dim1_room(desc, source, queried_sgid)
		if not snap then
			return
		end
		if tonumber(snap.dimension) ~= tonumber(DIM_KNIFE) then
			return
		end
		if snap.has_data ~= true then
			return
		end
		local list = tonumber(snap.list_index)
		if list == nil or list < 0 then
			return
		end
		local prev = by_list[list]
		if prev then
			prev.sources = prev.sources or {prev.source}
			prev.sources[#prev.sources + 1] = source
			return
		end
		snap.sources = {source}
		by_list[list] = snap
		rooms[#rooms + 1] = snap
	end

	pcall(function()
		local list = level:GetRooms()
		local size = list and (list.Size or 0) or 0
		for i = 0, size - 1 do
			local desc = list:Get(i)
			consider(desc, "get_rooms", nil)
		end
	end)

	for sgid = 0, 168 do
		local desc = nil
		pcall(function()
			desc = level:GetRoomByIdx(sgid, DIM_KNIFE)
		end)
		consider(desc, "get_room_by_idx", sgid)
	end
	local mineshaft_idx = (GridRooms and GridRooms.ROOM_MINESHAFT_IDX) or -101
	do
		local desc = nil
		pcall(function()
			desc = level:GetRoomByIdx(mineshaft_idx, DIM_KNIFE)
		end)
		consider(desc, "get_room_by_idx", mineshaft_idx)
	end

	table.sort(rooms, function(a, b)
		local la = tonumber(a.list_index) or 0
		local lb = tonumber(b.list_index) or 0
		if la ~= lb then
			return la < lb
		end
		return (tonumber(a.safe_grid_index) or 0) < (tonumber(b.safe_grid_index) or 0)
	end)

	local target = mineshaft_target_ready(level)
	local target_case = "unknown"
	if (#rooms == 0) then
		target_case = "dim1_empty"
	elseif target.ok == true then
		target_case = "sgid162_ok"
	else
		local found_other = false
		for i = 1, #rooms do
			if tonumber(rooms[i].safe_grid_index) == tonumber(target_sgid) then
				found_other = true
				break
			end
		end
		if found_other then
			target_case = "sgid162_invalid_registration"
		else
			target_case = "dim1_has_rooms_but_no_162"
		end
	end

	local candidates = {}
	for i = 1, math.min(12, #rooms) do
		local r = rooms[i]
		candidates[#candidates + 1] = {
			sgid = r.safe_grid_index,
			list = r.list_index,
			type = r.data_type,
			variant = r.data_variant,
			subtype = r.data_subtype,
			name = r.data_name,
		}
	end

	local summary = {
		tag = tag,
		stage = id and id.stage or nil,
		stage_type = id and id.stage_type or nil,
		force_special_quest = force_quest,
		has_abandoned_mineshaft = has_mineshaft,
		target_sgid = target_sgid,
		target_dimension = DIM_KNIFE,
		dimension1_room_count = #rooms,
		sgid162 = target,
		target_case = target_case,
		candidates = candidates,
		fingerprint = dim1_room_fingerprint(rooms),
		game_frame = Game():GetFrameCount(),
	}
	local full = {
		summary = summary,
		rooms = rooms,
	}
	local runtime = d().runtime
	runtime.mineshaft_dim1_scan = full
	runtime.mineshaft_dim1_scan_summary = summary
	return full
end

function M.maybe_scan_mineshaft_dimension1(tag, opts)
	opts = opts or {}
	if not mines_ii_custom_door_enabled() and opts.force ~= true then
		-- Still allow floor_finalize / explicit force; otherwise only on Mines II.
		local plan = d().corridor_plan
		local id = d().read_level_identity and d().read_level_identity() or nil
		if not (plan and plan.is_mines_ii and id and plan.is_mines_ii(id.stage, id.stage_type)) then
			if opts.allow_non_mines ~= true then
				return nil
			end
		end
	end
	local full = M.scan_mineshaft_dimension1(tag or "scan")
	local runtime = d().runtime
	local fp = full and full.summary and full.summary.fingerprint or ""
	local prev_fp = runtime.mineshaft_dim1_scan_fingerprint
	local changed = fp ~= prev_fp
	runtime.mineshaft_dim1_scan_fingerprint = fp
	if changed or opts.force == true then
		-- Compact event by default; full room list stays on runtime / probe capture.
		d().push_event("special_quest_mineshaft_dim1", full.summary)
		if mineshaft_dim_observer then
			pcall(mineshaft_dim_observer, tag or "scan", full)
		end
	end
	return full
end

function M.set_mineshaft_dim_observer(cb)
	mineshaft_dim_observer = type(cb) == "function" and cb or nil
end

function M.set_virtual_door_life_observer(cb)
	virtual_door_life_observer = type(cb) == "function" and cb or nil
end

local function mirror_passable_for_player(player)
	-- Shattered mirror: never enter from normal dim (design). Return from knife dim still OK.
	if is_mirror_shattered() then
		if current_dimension(Game():GetLevel()) == DIM_KNIFE then
			return true, "in_mirror_dimension"
		end
		return false, "mirror_shattered"
	end
	if current_dimension(Game():GetLevel()) == DIM_KNIFE then
		return true, "in_mirror_dimension"
	end
	if is_player_losted(player) then
		return true, "lost_curse_or_lost_type"
	end
	return false, "need_lost_curse"
end

local function apply_virtual_door_depth(anchor)
	if not anchor then
		return
	end
	pcall(function()
		anchor.DepthOffset = VIRTUAL_DOOR_DEPTH
		anchor.SortingLayer = 0
	end)
end

local function mirror_target_ready(level)
	local from_dim = current_dimension(level)
	local to_dim = (from_dim == DIM_KNIFE) and DIM_NORMAL or DIM_KNIFE
	local room_index = room_index_for_transition(level)
	return read_dimension_room(level, room_index, to_dim), to_dim, room_index
end

local function snapshot_mirror_room_identity(desc, expect_sgid)
	local spawn_seed, deco_seed, award_seed, visited, seeds_ok = read_desc_seeds(desc)
	local safe = desc and desc.SafeGridIndex or nil
	local list_index = desc and desc.ListIndex or nil
	local grid_index = desc and desc.GridIndex or nil
	local dim = nil
	pcall(function()
		if desc and desc.GetDimension then
			dim = desc:GetDimension()
		end
	end)
	local safe_ok = tonumber(safe) == tonumber(expect_sgid)
	local list_ok = list_index ~= nil and tonumber(list_index) >= 0
	local registered = desc ~= nil
		and desc.Data ~= nil
		and safe_ok
		and list_ok
		and seeds_ok == true
	return {
		has_desc = desc ~= nil,
		has_data = desc ~= nil and desc.Data ~= nil,
		has_override = desc ~= nil and desc.OverrideData ~= nil,
		safe_grid_index = safe,
		grid_index = grid_index,
		list_index = list_index,
		descriptor_dimension = dim,
		safe_ok = safe_ok,
		list_ok = list_ok == true,
		seeds_ok = seeds_ok == true,
		spawn_seed = spawn_seed,
		decoration_seed = deco_seed,
		award_seed = award_seed,
		visited = visited,
		registered = registered == true,
		room_type = desc and desc.Data and desc.Data.Type or nil,
		room_variant = desc and desc.Data and desc.Data.Variant or nil,
		room_subtype = desc and desc.Data and desc.Data.Subtype or nil,
		room_shape = desc and desc.Data and desc.Data.Shape or nil,
	}
end

local function link_mirror_room_pair(from_sgid, slot, to_sgid)
	local level = Game():GetLevel()
	local from_desc = level:GetRoomByIdx(from_sgid, DIM_KNIFE)
	local to_desc = level:GetRoomByIdx(to_sgid, DIM_KNIFE)
	local opp = (slot == DoorSlot.LEFT0 and DoorSlot.RIGHT0)
		or (slot == DoorSlot.RIGHT0 and DoorSlot.LEFT0)
		or (slot == DoorSlot.UP0 and DoorSlot.DOWN0)
		or (slot == DoorSlot.DOWN0 and DoorSlot.UP0)
		or nil
	local row = {
		from = from_sgid,
		to = to_sgid,
		slot = slot,
		opposite = opp,
		dimension = DIM_KNIFE,
		ok = false,
	}
	if not from_desc or not from_desc.Data or not to_desc or not to_desc.Data or opp == nil then
		row.error = "missing_desc_or_slot"
		return row
	end
	if tonumber(from_desc.SafeGridIndex) ~= tonumber(from_sgid)
		or tonumber(to_desc.SafeGridIndex) ~= tonumber(to_sgid)
	then
		row.error = "not_own_room"
		row.from_safe = from_desc.SafeGridIndex
		row.to_safe = to_desc.SafeGridIndex
		return row
	end
	local ok_a = pcall(function()
		from_desc.Doors[slot] = to_sgid
		from_desc.AllowedDoors = (from_desc.AllowedDoors or 0) | (1 << slot)
	end)
	local ok_b = pcall(function()
		to_desc.Doors[opp] = from_sgid
		to_desc.AllowedDoors = (to_desc.AllowedDoors or 0) | (1 << opp)
	end)
	row.ok = ok_a == true and ok_b == true
	row.from_safe = from_desc.SafeGridIndex
	row.to_safe = to_desc.SafeGridIndex
	return row
end

local MIRROR_ENTRY_SGID = 78
local MIRROR_BOSS_SGID = 89
local MIRROR_DEAL_SGID = 90

local function read_desc_doors_slots(desc)
	local doors = {}
	if not desc then
		return doors
	end
	pcall(function()
		for slot = 0, 7 do
			doors[slot] = desc.Doors[slot]
		end
	end)
	return doors
end

local function snapshot_dim_room_probe(sgid, dimension)
	local level = Game():GetLevel()
	local desc = nil
	pcall(function()
		desc = level:GetRoomByIdx(sgid, dimension)
	end)
	local snap = snapshot_mirror_room_identity(desc, sgid)
	snap.dimension = dimension
	snap.sgid = sgid
	snap.doors = read_desc_doors_slots(desc)
	snap.allowed_doors = desc and desc.AllowedDoors or nil
	return snap
end

--- Special / north extras owned in normal dim (never 78–90 main path).
local function collect_expected_mirror_special_sgids()
	local level = Game():GetLevel()
	local runtime = d().runtime
	local set = {}
	local list = {}
	local function try_add(sgid)
		sgid = tonumber(sgid)
		if not sgid or sgid < 0 or set[sgid] then
			return
		end
		if sgid >= MIRROR_ENTRY_SGID and sgid <= MIRROR_DEAL_SGID then
			return
		end
		local desc = nil
		pcall(function()
			desc = level:GetRoomByIdx(sgid, DIM_NORMAL)
		end)
		if not desc or not desc.Data or tonumber(desc.SafeGridIndex) ~= sgid then
			return
		end
		set[sgid] = true
		list[#list + 1] = sgid
	end
	-- Base south cluster + north Luna/Fragmented slots (only if normal owns them).
	local seeds = {
		95, 97, 98, 108, 109, 110, 122, 72,
		71, 69, 58, 56, 57, 44,
	}
	local nm = runtime and runtime.north_mirror_place
	if nm and type(nm.placed_ok) == "table" then
		for _, sgid in ipairs(nm.placed_ok) do
			seeds[#seeds + 1] = sgid
		end
	end
	local pending = runtime and runtime.pending
	local north_links = pending and pending.north_mirror_links
	if type(north_links) == "table" then
		for _, link in ipairs(north_links) do
			seeds[#seeds + 1] = link.from
			seeds[#seeds + 1] = link.to
		end
	end
	for _, sgid in ipairs(seeds) do
		try_add(sgid)
	end
	-- Walk normal Doors[] from corridor + discovered specials for any extra owned targets.
	local walk = {}
	for sgid = MIRROR_ENTRY_SGID, MIRROR_DEAL_SGID do
		walk[#walk + 1] = sgid
	end
	for _, sgid in ipairs(list) do
		walk[#walk + 1] = sgid
	end
	for _, sgid in ipairs(walk) do
		local desc = nil
		pcall(function()
			desc = level:GetRoomByIdx(sgid, DIM_NORMAL)
		end)
		if desc and desc.Data and tonumber(desc.SafeGridIndex) == sgid then
			for slot = 0, 7 do
				local target = nil
				pcall(function()
					target = desc.Doors[slot]
				end)
				try_add(target)
			end
		end
	end
	table.sort(list)
	return list
end

--- Copy normal-dim door adjacencies into knife dim for rooms present in both.
local function link_mirror_doors_from_normal(present_knife)
	local level = Game():GetLevel()
	local seen = {}
	local links = {}
	local function undirected_key(a, b, slot, opp)
		local lo, hi = a, b
		if lo > hi then
			lo, hi = hi, lo
		end
		local s0, s1 = slot, opp
		if s0 > s1 then
			s0, s1 = s1, s0
		end
		return string.format("%d:%d:%d:%d", lo, hi, s0, s1)
	end
	for sgid, _ in pairs(present_knife) do
		local src = nil
		pcall(function()
			src = level:GetRoomByIdx(sgid, DIM_NORMAL)
		end)
		if src and src.Data and tonumber(src.SafeGridIndex) == tonumber(sgid) then
			for slot = 0, 7 do
				local target = nil
				pcall(function()
					target = src.Doors[slot]
				end)
				target = tonumber(target)
				if target and target >= 0 and present_knife[target] then
					local opp = (slot == DoorSlot.LEFT0 and DoorSlot.RIGHT0)
						or (slot == DoorSlot.RIGHT0 and DoorSlot.LEFT0)
						or (slot == DoorSlot.UP0 and DoorSlot.DOWN0)
						or (slot == DoorSlot.DOWN0 and DoorSlot.UP0)
						or nil
					if opp ~= nil then
						local key = undirected_key(sgid, target, slot, opp)
						if not seen[key] then
							seen[key] = true
							links[#links + 1] = link_mirror_room_pair(sgid, slot, target)
						end
					end
				end
			end
		end
	end
	return links
end

local function knife_specials_still_registered(expected_sgids)
	local level = Game():GetLevel()
	if type(expected_sgids) ~= "table" then
		return true, {}
	end
	local missing = {}
	for _, sgid in ipairs(expected_sgids) do
		local snap = snapshot_mirror_room_identity(
			level:GetRoomByIdx(sgid, DIM_KNIFE),
			sgid
		)
		if not snap.registered then
			missing[#missing + 1] = sgid
		end
	end
	return #missing == 0, missing
end

--- Place / validate one corridor cell in Dimension.KNIFE_PUZZLE from Dimension 0 layout.
--- place_opts.allow_no_neighbors: match normal-dim deal@90 preplace (RGON rejects deal beside boss).
local function ensure_mirror_corridor_room(sgid, root, place_opts)
	place_opts = place_opts or {}
	local allow_no_neighbors = place_opts.allow_no_neighbors == true
	local level = Game():GetLevel()
	local src = nil
	local dst = nil
	pcall(function()
		src = level:GetRoomByIdx(sgid, DIM_NORMAL)
	end)
	pcall(function()
		dst = level:GetRoomByIdx(sgid, DIM_KNIFE)
	end)
	local before = snapshot_mirror_room_identity(dst, sgid)
	local row = {
		sgid = sgid,
		before = before,
		ok = false,
		place_kind = place_opts.kind,
		allow_no_neighbors = allow_no_neighbors,
	}
	if not src or not src.Data then
		row.note = "missing_source"
		return row
	end
	row.src_variant = src.Data.Variant
	row.src_type = src.Data.Type

	-- Already a real knife-dim room: keep visit state; only patch zero seeds if unvisited.
	if before.registered then
		local visited_n = tonumber(before.visited) or 0
		if visited_n > 0 then
			row.ok = true
			row.note = "keep_visited_registered"
			row.after = snapshot_mirror_room_identity(dst, sgid)
			return row
		end
		if before.seeds_ok then
			row.ok = true
			row.note = "already_registered"
			row.after = before
			return row
		end
	end

	local cfg = src.Data
	local place_seed = root
	if d().derive_seed then
		place_seed = d().derive_seed(root, "mirror_place", sgid, 1) or root
	end

	-- Own broken stub (SafeGridIndex==sgid but invalid) may be cleared if never visited.
	-- Never wipe an aliased special room (GetRoomByIdx(sgid) → -1 devil still has Data).
	local visited_n = tonumber(before.visited) or 0
	if dst and dst.Data and before.safe_ok ~= true and visited_n <= 0 then
		if tonumber(dst.SafeGridIndex) == tonumber(sgid) then
			pcall(function()
				dst.Data = nil
				dst.OverrideData = nil
			end)
			row.cleared_broken_stub = true
		else
			row.skipped_clear_alias = true
			row.alias_owner = dst.SafeGridIndex
			row.alias_list_index = dst.ListIndex
		end
	end

	local placed = nil
	local place_err = nil
	local can_place = nil
	if level.TryPlaceRoom then
		if level.CanPlaceRoom then
			local ok_can, can_val = pcall(function()
				return level:CanPlaceRoom(cfg, sgid, DIM_KNIFE, true, true, allow_no_neighbors)
			end)
			can_place = ok_can and can_val == true
			row.can_place = can_place
		end
		if can_place ~= false then
			local ok_p, ret = pcall(function()
				return level:TryPlaceRoom(cfg, sgid, DIM_KNIFE, place_seed, true, true, allow_no_neighbors)
			end)
			if ok_p then
				placed = ret
			else
				place_err = tostring(ret)
			end
			row.try_place_ok = ok_p and placed ~= nil
			row.try_place_error = place_err
		end
	end

	pcall(function()
		dst = level:GetRoomByIdx(sgid, DIM_KNIFE)
	end)
	local after_place = snapshot_mirror_room_identity(dst, sgid)

	-- Fallback Data write only onto a descriptor that claims this sgid — never onto aliases.
	if not after_place.registered and dst and visited_n <= 0 then
		if tonumber(dst.SafeGridIndex) == tonumber(sgid) then
			local writer = d().write_desc_config
			local ok_w = false
			if writer then
				ok_w = writer(dst, cfg, nil, sgid)
			else
				ok_w = pcall(function()
					dst.Data = cfg
					dst.OverrideData = cfg
				end)
			end
			row.fallback_data_write = ok_w == true
			row.via = "fallback_data_assign"
		else
			row.fallback_skipped_alias = true
			row.alias_owner = dst.SafeGridIndex
			row.via = "skip_alias_fallback"
		end
	elseif after_place.registered then
		row.via = row.try_place_ok and "try_place" or "preexisting"
	end

	-- Seeds: required for Init; never wipe visited rooms.
	pcall(function()
		dst = level:GetRoomByIdx(sgid, DIM_KNIFE)
	end)
	local _, _, _, visited_now, seeds_ok_now = read_desc_seeds(dst)
	visited_n = tonumber(visited_now) or 0
	if dst and dst.Data and not seeds_ok_now then
		local init_fn = d().init_desc_runtime
		if init_fn and root then
			row.runtime_init = init_fn(dst, {
				idx = sgid,
				base_seed = root,
				domain_spawn = "mirror_spawn",
				domain_deco = "mirror_deco",
				domain_award = "mirror_award",
				stream = 1,
				fresh_room = visited_n <= 0,
			})
		end
	end

	row.after = snapshot_mirror_room_identity(dst, sgid)
	row.ok = row.after.registered == true
	if row.ok then
		row.note = row.via or "ready"
	elseif row.after.has_data and not row.after.safe_ok then
		row.note = "data_without_safe_grid_index"
		row.retryable = true
	else
		row.note = "place_failed"
		row.retryable = true
	end
	return row
end

--- Build Dimension 1 corridor 78–90 + normal-dim special/north extras + door links.
local function prepare_mirror_corridor(tag)
	local runtime = d().runtime
	local level = Game():GetLevel()
	-- Fast path: entry + expected specials must still be registered in knife dim.
	if runtime.mirror_corridor_ready == true then
		local entry = snapshot_mirror_room_identity(
			level:GetRoomByIdx(d().entry_sgid, DIM_KNIFE),
			d().entry_sgid
		)
		local cached = runtime.special_quest_mirror_corridor
		local specials_ok, missing = knife_specials_still_registered(
			cached and cached.expected_special_sgids
		)
		if entry.registered and specials_ok and cached and cached.ok then
			cached.tag = tag
			cached.entry = entry
			cached.note = "mirror_corridor_ready_cached"
			return cached
		end
		runtime.mirror_corridor_ready = false
		if cached then
			cached.cache_invalid_missing_specials = missing
		end
	end
	local root = d().require_root_seed and d().require_root_seed("mirror_corridor")
	local plan = d().corridor_plan
	local expected_specials = collect_expected_mirror_special_sgids()
	local row = {
		tag = tag,
		ok = false,
		rooms = {},
		special_rooms = {},
		links = {},
		special_links = {},
		special_compare = {},
		expected_special_sgids = expected_specials,
		root_seed = root,
	}
	if not root then
		row.note = "missing_root_seed"
		runtime.special_quest_mirror_corridor = row
		d().push_event("special_quest_mirror_corridor", row)
		return row
	end

	local ok_count = 0
	local total = 0
	local function place_one(sgid, place_opts, special_bucket)
		if place_opts and place_opts.require_corridor_sgid == true then
			if plan and plan.is_corridor_sgid and not plan.is_corridor_sgid(sgid) then
				return nil
			end
		end
		total = total + 1
		local room_row = ensure_mirror_corridor_room(sgid, root, place_opts)
		row.rooms[#row.rooms + 1] = room_row
		if special_bucket then
			special_bucket[#special_bucket + 1] = room_row
		end
		if room_row.ok then
			ok_count = ok_count + 1
		end
		return room_row
	end

	-- Order: deal@90 (AllowNoNeighbors) → entry@78 seed (AllowNoNeighbors) →
	-- 79–88 grow with neighbors → boss@89 last → specials from normal dim.
	-- 90-first avoids deal-beside-boss reject; 78 seed gives the left chain a start.
	row.placement_order = "deal90_then_entry78_seed_then_79_88_then_boss89_then_specials"
	local row90 = place_one(MIRROR_DEAL_SGID, {
		kind = "deal_90_preplace",
		allow_no_neighbors = true,
		require_corridor_sgid = true,
	})
	row.deal_90_preplace = row90
	local row78 = place_one(MIRROR_ENTRY_SGID, {
		kind = "entry_78_seed",
		allow_no_neighbors = true,
		require_corridor_sgid = true,
	})
	row.entry_78_seed = row78
	for sgid = MIRROR_ENTRY_SGID + 1, MIRROR_BOSS_SGID - 1 do
		place_one(sgid, {
			kind = "mirror_main_path",
			allow_no_neighbors = false,
			require_corridor_sgid = true,
		})
	end
	local row89 = place_one(MIRROR_BOSS_SGID, {
		kind = "boss_89_place",
		allow_no_neighbors = false,
		require_corridor_sgid = true,
	})
	row.boss_89_place = row89
	row.main_ok_count = ok_count
	row.main_total = total

	-- Special / north extras: reuse same place path; allow_no_neighbors for deep secrets.
	local special_ok = 0
	for _, sgid in ipairs(expected_specials) do
		local srow = place_one(sgid, {
			kind = "mirror_special",
			allow_no_neighbors = true,
			require_corridor_sgid = false,
		}, row.special_rooms)
		if srow and srow.ok then
			special_ok = special_ok + 1
		end
	end
	row.special_ok_count = special_ok
	row.special_total = #expected_specials
	row.ok_count = ok_count
	row.total = total

	-- Present knife set for door sync (main + specials that registered).
	local present_knife = {}
	for sgid = MIRROR_ENTRY_SGID, MIRROR_DEAL_SGID do
		local snap = snapshot_mirror_room_identity(
			level:GetRoomByIdx(sgid, DIM_KNIFE),
			sgid
		)
		if snap.registered then
			present_knife[sgid] = true
		end
	end
	for _, srow in ipairs(row.special_rooms) do
		if srow and srow.ok and srow.sgid then
			present_knife[srow.sgid] = true
		end
	end

	-- Dual-dimension probe rows for specials (incl. Luna 71/58 and south 95/97/108/110).
	for _, sgid in ipairs(expected_specials) do
		row.special_compare[#row.special_compare + 1] = {
			sgid = sgid,
			normal = snapshot_dim_room_probe(sgid, DIM_NORMAL),
			knife = snapshot_dim_room_probe(sgid, DIM_KNIFE),
		}
	end

	-- Door links: copy normal-dim adjacencies for rooms present in both dims.
	local all_links = link_mirror_doors_from_normal(present_knife)
	local link_ok = 0
	local special_link_ok = 0
	for _, link in ipairs(all_links) do
		row.links[#row.links + 1] = link
		local is_special = (link.from < MIRROR_ENTRY_SGID or link.from > MIRROR_DEAL_SGID)
			or (link.to < MIRROR_ENTRY_SGID or link.to > MIRROR_DEAL_SGID)
		if is_special then
			row.special_links[#row.special_links + 1] = link
			if link.ok then
				special_link_ok = special_link_ok + 1
			end
		end
		if link.ok then
			link_ok = link_ok + 1
		end
	end
	row.link_ok_count = link_ok
	row.link_total = #all_links
	row.special_link_ok_count = special_link_ok
	row.special_link_total = #row.special_links

	-- Neighbor identity check for 89↔90 after ordered place.
	local after89 = snapshot_mirror_room_identity(level:GetRoomByIdx(MIRROR_BOSS_SGID, DIM_KNIFE), MIRROR_BOSS_SGID)
	local after90 = snapshot_mirror_room_identity(level:GetRoomByIdx(MIRROR_DEAL_SGID, DIM_KNIFE), MIRROR_DEAL_SGID)
	row.neighbor_89_90 = {
		boss_registered = after89.registered == true,
		deal_registered = after90.registered == true,
		boss_type = after89.room_type,
		deal_type = after90.room_type,
	}
	if row89 then
		row89.neighbor_90 = after90.registered == true
	end
	if row90 then
		row90.neighbor_89 = after89.registered == true
	end

	local entry = snapshot_mirror_room_identity(level:GetRoomByIdx(d().entry_sgid, DIM_KNIFE), d().entry_sgid)
	row.entry = entry
	local main_complete = row.main_ok_count == row.main_total
		and entry.registered == true
		and after89.registered == true
		and after90.registered == true
	local specials_complete = special_ok == #expected_specials
	row.ok = main_complete and specials_complete
	if row.ok then
		row.note = "mirror_corridor_ready"
	elseif main_complete and not specials_complete then
		row.note = "mirror_corridor_incomplete_specials"
	elseif after89.registered and not after90.registered then
		-- Legacy wrong-order residue: boss already present blocks deal place.
		row.deal_blocked_by_boss = true
		row.note = "mirror_corridor_incomplete_deal_blocked_by_boss"
	else
		row.note = "mirror_corridor_incomplete"
	end
	runtime.special_quest_mirror_corridor = row
	runtime.mirror_corridor_ready = row.ok == true
	d().push_event("special_quest_mirror_corridor", row)
	return row
end

--- Ensure knife-dim entry@78 is a *registered* room (SafeGridIndex==78 + seeds), and
--- the full 78–90 mirror corridor exists. Data-only stubs are not enough.
local function prepare_mirror_dimension_entry(tag)
	local runtime = d().runtime
	local corridor = prepare_mirror_corridor(tag)
	local entry = corridor and corridor.entry or nil
	local row = {
		tag = tag,
		entry_sgid = d().entry_sgid,
		ok = corridor and corridor.ok == true and entry and entry.registered == true,
		corridor_ok = corridor and corridor.ok == true,
		corridor_ok_count = corridor and corridor.ok_count,
		corridor_total = corridor and corridor.total,
		entry = entry,
		spawn_seed_after = entry and entry.spawn_seed,
		decoration_seed_after = entry and entry.decoration_seed,
		award_seed_after = entry and entry.award_seed,
		visited_after = entry and entry.visited,
		seeds_ok_after = entry and entry.seeds_ok,
		safe_grid_index = entry and entry.safe_grid_index,
		list_index = entry and entry.list_index,
		note = nil,
		retryable = false,
	}
	if row.ok then
		row.note = "ready_registered_entry"
	else
		row.note = (entry and not entry.safe_ok and "entry_safe_grid_index_invalid")
			or (corridor and corridor.note)
			or "mirror_entry_not_ready"
		row.retryable = true
	end
	runtime.special_quest_mirror_prepare = row
	d().push_event("special_quest_mirror_prepare", row)
	return row
end

local function set_mirror_sprite_pose(entry, want_open, shattered)
	if not entry or not entry.anchor or not entry.anchor.Exists or not entry.anchor:Exists() then
		return
	end
	pcall(function()
		local spr = entry.anchor:GetSprite()
		if not spr then
			return
		end
		local anim = shattered and "BrokenOpen" or (want_open and "Opened" or "Closed")
		local cur = spr.GetAnimation and spr:GetAnimation() or nil
		if cur == anim then
			return
		end
		if spr.Play then
			spr:Play(anim, true)
		elseif spr.SetFrame then
			spr:SetFrame(anim, 0)
		end
	end)
end

-- Optional observer for mirror-door physics probe (default nil / off).
local mirror_physics_observer = nil

function M.set_mirror_physics_observer(cb)
	mirror_physics_observer = type(cb) == "function" and cb or nil
end

local function notify_mirror_physics(phase, payload)
	if not mirror_physics_observer then
		return
	end
	pcall(mirror_physics_observer, phase, payload)
end

--- LEFT0 descriptor / native door / grid collision triple (physics probe).
--- Does not imply final player physics; raw engine reads only.
local function sample_authored_blue_fires(room)
	-- Template 25603: Blue Fire Place (33.2) at room corners (0,0) / (0,6).
	local out = {
		top_left = {grid_x = 0, grid_y = 0, found = false},
		bottom_left = {grid_x = 0, grid_y = 6, found = false},
		total_blue = 0,
	}
	if not room then
		return out
	end
	local width = nil
	pcall(function()
		width = room:GetGridWidth()
	end)
	local fires = {}
	pcall(function()
		fires = Isaac.FindByType(EntityType.ENTITY_FIREPLACE, 2, -1, false, false) or {}
	end)
	out.total_blue = #fires
	for _, fire in ipairs(fires) do
		local gx, gy = nil, nil
		pcall(function()
			local idx = room:GetGridIndex(fire.Position)
			if width and width > 0 and idx ~= nil then
				gx = idx % width
				gy = math.floor(idx / width)
			end
		end)
		if gx == 0 and gy == 0 then
			out.top_left.found = true
			out.top_left.entity_index = fire.Index
		elseif gx == 0 and gy == 6 then
			out.bottom_left.found = true
			out.bottom_left.entity_index = fire.Index
		end
	end
	out.both_corners = out.top_left.found == true and out.bottom_left.found == true
	return out
end

--- Water II 25603: do not OR LEFT0 into AllowedDoors (layout LEFT exists=False).
local function skip_force_mirror_left0_allowed(cur)
	local plan = d().corridor_plan
	local id = nil
	pcall(function()
		id = d().read_level_identity and d().read_level_identity() or nil
	end)
	local live_variant = cur and cur.Data and tonumber(cur.Data.Variant) or nil
	if plan and plan.should_reserve_mirror_left0_allowed then
		return plan.should_reserve_mirror_left0_allowed(
			id and id.stage,
			id and id.stage_type,
			live_variant
		) ~= true
	end
	if live_variant == 25603 then
		return true
	end
	if plan and plan.is_water_ii and id and plan.is_water_ii(id.stage, id.stage_type) then
		return true
	end
	return false
end

function M.snapshot_left0_slot_context(phase, room, preferred)
	preferred = preferred or DoorSlot.LEFT0
	room = room or Game():GetRoom()
	local level = Game():GetLevel()
	local cur = nil
	pcall(function()
		cur = level:GetCurrentRoomDesc()
	end)
	local snap = {
		phase = phase or "snapshot",
		frame = nil,
		sgid = cur and cur.SafeGridIndex or nil,
		list_index = cur and cur.ListIndex or nil,
		dimension = current_dimension(level),
		slot = preferred,
	}
	pcall(function()
		snap.frame = Game():GetFrameCount()
	end)
	pcall(function()
		local data = cur and cur.Data
		snap.data_type = data and data.Type or nil
		snap.data_variant = data and data.Variant or nil
		snap.data_doors_mask = data and data.Doors or nil
		if snap.data_doors_mask ~= nil then
			snap.data_doors_has_left0 = ((snap.data_doors_mask or 0) & (1 << preferred)) ~= 0
		end
		local doors = cur and cur.Doors
		snap.desc_target = doors and doors[preferred] or nil
		snap.is_door_slot_allowed = slot_allowed(room, preferred)
		snap.allowed = snap.is_door_slot_allowed
		if cur and cur.AllowedDoors ~= nil then
			snap.allowed_doors_mask = cur.AllowedDoors
			snap.allowed_bit = ((cur.AllowedDoors or 0) & (1 << preferred)) ~= 0
		end
	end)
	local native = nil
	pcall(function()
		native = room:GetDoor(preferred)
	end)
	if native then
		snap.native_exists = true
		snap.native_type = native.GetType and native:GetType() or nil
		snap.native_target = native.TargetRoomIndex
		snap.native_collision = native.CollisionClass
		if native.IsOpen then
			snap.native_is_open = native:IsOpen() == true
		end
		if native.IsLocked then
			snap.native_is_locked = native:IsLocked() == true
		end
	else
		snap.native_exists = false
	end
	local grid_index, ge = nil, nil
	pcall(function()
		local pos = room:GetDoorSlotPosition(preferred)
		snap.slot_pos = pos and {x = pos.X, y = pos.Y} or nil
		if pos then
			grid_index = room:GetGridIndex(pos)
			ge = room:GetGridEntity(grid_index)
		end
	end)
	snap.grid_index = grid_index
	if ge then
		snap.grid_type = ge.GetType and ge:GetType() or nil
		snap.grid_collision = ge.CollisionClass
		snap.grid_var_data = ge.VarData
	else
		snap.grid_type = nil
		snap.grid_collision = nil
	end
	pcall(function()
		if grid_index ~= nil and room.GetGridCollision then
			snap.room_grid_collision = room:GetGridCollision(grid_index)
		end
		if snap.slot_pos and room.GetGridCollisionAtPos then
			local sp = Vector(snap.slot_pos.x, snap.slot_pos.y)
			snap.room_grid_collision_at_pos = room:GetGridCollisionAtPos(sp)
			if room.IsPositionInRoom then
				snap.slot_in_room = room:IsPositionInRoom(sp, 0) == true
			end
		end
	end)
	snap.blue_fires = sample_authored_blue_fires(room)
	snap.water_ii_template = snap.data_variant == 25603
	return snap
end

local function emit_left0_physics(phase, room, preferred, extra)
	if not mirror_physics_observer then
		return nil
	end
	local snap = M.snapshot_left0_slot_context(phase, room, preferred)
	if type(extra) == "table" then
		for k, v in pairs(extra) do
			snap[k] = v
		end
	end
	notify_mirror_physics(phase, snap)
	return snap
end

local function push_mirror_interact(sample)
	local runtime = d().runtime
	runtime.special_quest_mirror_interact = sample
	-- Change-only log: avoid filling the queue with identical mirror_status rows.
	local key = table.concat({
		tostring(sample.tag),
		tostring(sample.want_open),
		tostring(sample.confirmed_door_hit),
		tostring(sample.any_losted),
		tostring(sample.native_is_open),
		tostring(sample.native_is_locked),
		tostring(sample.under_collision),
		tostring(sample.can_enter),
		tostring(sample.can_enter_reason),
		tostring(sample.applied_open),
		tostring(sample.applied_unlock),
		tostring(sample.applied_close_lock),
		tostring(sample.trans_to_executed),
	}, "|")
	if runtime.special_quest_mirror_interact_key == key then
		notify_mirror_physics("mirror_status_quiet", sample)
		return
	end
	runtime.special_quest_mirror_interact_key = key
	local log = runtime.special_quest_mirror_interact_log
	if type(log) ~= "table" then
		log = {}
		runtime.special_quest_mirror_interact_log = log
	end
	log[#log + 1] = sample
	while #log > 16 do
		table.remove(log, 1)
	end
	-- Event queue: gated by runtime detail_logging (VERBOSE_EVENT_KINDS).
	d().push_event("special_quest_mirror_interact", sample)
	notify_mirror_physics("mirror_status_change", sample)
end

local function evaluate_mirror_can_enter(player)
	local lv = Game():GetLevel()
	prepare_mirror_dimension_entry("can_enter_prepare")
	local dest = mirror_target_ready(lv)
	if dest.ok ~= true then
		return false, "target_room_missing", dest
	end
	local passable, pass_reason = mirror_passable_for_player(player)
	if not passable then
		return false, pass_reason or "need_lost_curse", dest
	end
	return true, "ok", dest
end

local function tick_mirror_door_state(entry)
	if not entry then
		return
	end
	local shattered = is_mirror_shattered()
	local dim = current_dimension(Game():GetLevel())
	-- Intact + (in mirror dim or losted) → open. Shattered in normal dim → closed/blocked.
	local want_open = (not shattered) and (dim == DIM_KNIFE or any_player_losted())
	if shattered and dim == DIM_KNIFE then
		want_open = true
	end
	entry.want_open = want_open == true

	-- Visual + collision must stay in sync. Virtual door owns FADE_MIRROR.
	-- Closed: Close+Lock (blocks walk-in while Target is invalid).
	-- Open: must *reverse* that state — SetLocked(false) + Open() when needed —
	-- then reassert TargetRoomIndex=-1, hide native sprite, and set EXCEPT_PLAYER.
	-- Only stopping Close/Lock left IsOpen=false / IsLocked=true (log: min X≈68).
	local native_is_open, native_is_locked = nil, nil
	local native_target = nil
	local applied_close_lock = false
	local applied_unlock = false
	local applied_open = false
	if entry.under_grid then
		pcall(function()
			local under = entry.under_grid
			local function hide_native_sprite()
				local ns = under:GetSprite()
				if ns and ns.GetFilename and ns:GetFilename() ~= "gfx/effects/nil_effect.anm2" then
					ns:Load("gfx/effects/nil_effect.anm2", true)
					ns:Play("Idle", true)
				end
			end
			hide_native_sprite()
			-- Do not Bar(): Bar forces solid wall and would undo player-pass collision.
			local as_door = under.ToDoor and under:ToDoor() or nil
			if as_door then
				pcall(function()
					native_target = as_door.TargetRoomIndex
				end)
				if want_open then
					-- Keep invalid target so native walk-in cannot claim a real room.
					pcall(function()
						as_door.TargetRoomIndex = -1
					end)
					if as_door.SetLocked then
						as_door:SetLocked(false)
						applied_unlock = true
					end
					-- Open only while still closed; Open() may restore native sprite.
					if as_door.Open and as_door.IsOpen and not as_door:IsOpen() then
						as_door:Open()
						applied_open = true
					end
					pcall(function()
						as_door.TargetRoomIndex = -1
					end)
					hide_native_sprite()
					under.CollisionClass = GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER
				else
					if as_door.Close then
						as_door:Close(true)
					end
					if as_door.SetLocked then
						as_door:SetLocked(true)
					end
					applied_close_lock = true
					under.CollisionClass = GridCollisionClass.COLLISION_WALL
				end
				if as_door.IsOpen then
					native_is_open = as_door:IsOpen() == true
				end
				if as_door.IsLocked then
					native_is_locked = as_door:IsLocked() == true
				end
				pcall(function()
					native_target = as_door.TargetRoomIndex
				end)
			else
				under.CollisionClass = want_open
					and GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER
					or GridCollisionClass.COLLISION_WALL
			end
		end)
	end
	entry.skip_close_lock_while_open = want_open == true
	entry.applied_close_lock = applied_close_lock
	entry.applied_unlock = applied_unlock
	entry.applied_open = applied_open
	set_mirror_sprite_pose(entry, want_open, shattered and dim ~= DIM_KNIFE)

	-- Status sample does NOT require confirmed_door hit (k91 / collision diagnostics).
	local teleport_holder = require("Qing_Remaster_scripts.callbacks.teleport_holder")
	local slot = entry.refer_slot or entry.slot or DoorSlot.LEFT0
	local room = Game():GetRoom()
	local door_pos = nil
	local approach_center = nil
	pcall(function()
		door_pos = room and room:GetDoorSlotPosition(slot) or nil
		if door_pos and teleport_holder.door_approach_center then
			local dir_id = teleport_holder.slot_dir_map[slot]
			local dir = teleport_holder.dir_map[dir_id] or Vector(0, 0)
			approach_center = teleport_holder.door_approach_center(door_pos, dir)
		end
	end)

	local spr_anim, collision = nil, nil
	pcall(function()
		if entry.anchor then
			local spr = entry.anchor:GetSprite()
			spr_anim = spr and spr:GetAnimation() or nil
		end
	end)
	pcall(function()
		if entry.under_grid then
			collision = entry.under_grid.CollisionClass
		end
	end)

	local players = {}
	local nearest = nil
	local nearest_dist = nil
	local any_hit = false
	local hit_player = nil
	local player_min_x = nil
	local n = Game():GetNumPlayers()
	for i = 0, n - 1 do
		local p = Game():GetPlayer(i)
		if p then
			local hit, dist, center = teleport_holder.player_in_slot_approach(p, slot, 25)
			local has_null = false
			pcall(function()
				local effects = p:GetEffects()
				if effects and effects.HasNullEffect then
					has_null = effects:HasNullEffect(NULL_LOST_CURSE) == true
				end
			end)
			local pt = nil
			pcall(function()
				pt = p:GetPlayerType()
			end)
			local losted = is_player_losted(p)
			local pos = p.Position
			local dist_to_center = dist
			if dist_to_center == nil and approach_center and pos then
				dist_to_center = (pos - approach_center):Length()
			end
			if pos and (player_min_x == nil or pos.X < player_min_x) then
				player_min_x = pos.X
			end
			local row_p = {
				index = i,
				player_type = pt,
				has_null_lost_curse = has_null,
				player_losted = losted == true,
				confirmed_door_hit = hit == true,
				distance_to_approach = dist_to_center,
				pos = pos and {x = pos.X, y = pos.Y} or nil,
			}
			players[#players + 1] = row_p
			if hit then
				any_hit = true
				hit_player = p
			end
			if dist_to_center ~= nil and (nearest_dist == nil or dist_to_center < nearest_dist) then
				nearest = row_p
				nearest_dist = dist_to_center
				if not hit_player then
					hit_player = p
				end
			end
		end
	end

	-- can_enter only when a player is in range (avoids prepare spam every status tick).
	local can, reason = nil, nil
	if any_hit and hit_player then
		can, reason = evaluate_mirror_can_enter(hit_player)
	end

	local lost_changed = false
	local runtime = d().runtime
	local prev_any = runtime.special_quest_mirror_last_any_losted
	local now_any = any_player_losted()
	if prev_any ~= nil and prev_any ~= now_any then
		lost_changed = true
	end
	runtime.special_quest_mirror_last_any_losted = now_any

	-- Physics probe: want_open / under_collision edges (observer-gated).
	local prev_want = entry._physics_want_open
	if prev_want ~= nil and prev_want ~= (want_open == true) then
		emit_left0_physics("want_open_changed", room, slot, {
			want_open = want_open == true,
			prev_want_open = prev_want,
			under_collision = collision,
		})
	end
	entry._physics_want_open = want_open == true
	local prev_col = entry._physics_under_collision
	if collision ~= nil and prev_col ~= nil and prev_col ~= collision then
		emit_left0_physics("under_collision_changed", room, slot, {
			want_open = want_open == true,
			under_collision = collision,
			prev_under_collision = prev_col,
		})
	end
	entry._physics_under_collision = collision

	-- Change-only interact log (identical statuses are dropped inside push_mirror_interact).
	push_mirror_interact({
		tag = any_hit and "near_mirror" or "mirror_status",
		want_open = want_open == true,
		shattered = shattered,
		dimension = dim,
		any_losted = now_any == true,
		lost_changed = lost_changed == true,
		slot = slot,
		door_position = door_pos and {x = door_pos.X, y = door_pos.Y} or nil,
		approach_center = approach_center and {x = approach_center.X, y = approach_center.Y} or nil,
		approach_radius = 25,
		confirmed_door_hit = any_hit == true,
		nearest = nearest,
		players = players,
		player_min_x = player_min_x,
		sprite_animation = spr_anim,
		under_collision = collision,
		native_is_open = native_is_open,
		native_is_locked = native_is_locked,
		native_door_open = native_is_open,
		skip_close_lock_while_open = want_open == true,
		applied_close_lock = applied_close_lock == true,
		applied_unlock = applied_unlock == true,
		applied_open = applied_open == true,
		native_target = native_target
			or (entry.under_grid and entry.under_grid.TargetRoomIndex)
			or nil,
		can_enter = can,
		can_enter_reason = reason,
		can_enter_evaluated = any_hit == true,
		enter_locked = entry.enter_locked == true,
		enter_detection = entry.enter_detection,
	})

	-- Bomb shatter near door (FFG-style); sets vanilla level flag.
	if not shattered then
		pcall(function()
			local pos = entry.anchor.Position
			for _, boom in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.BOMB_EXPLOSION)) do
				if boom and boom.FrameCount <= 1 and boom.Position:Distance(pos) < (80 * boom.SpriteScale.X) then
					Game():GetLevel():SetStateFlag(LevelStateFlag.STATE_MIRROR_BROKEN, true)
					if SFXManager then
						SFXManager():Play(SoundEffect.SOUND_MIRROR_BREAK, 1, 0, false, 1)
					end
					set_mirror_sprite_pose(entry, true, true)
					break
				end
			end
		end)
	end
end

local MIRROR_ARRIVAL_SLOT = DoorSlot.LEFT0
local MIRROR_ARRIVAL_INWARD = 45

--- Place all players just inside LEFT0 (teleport_holder inward = dir_map[slot]).
--- Geometry alone keeps them outside the 25px approach radius so reverse enter is intentional.
local function place_players_at_mirror_arrival(slot)
	slot = slot or MIRROR_ARRIVAL_SLOT
	local room = Game():GetRoom()
	if not room then
		return false
	end
	local teleport_holder = require("Qing_Remaster_scripts.callbacks.teleport_holder")
	local door_pos = room:GetDoorSlotPosition(slot)
	if not door_pos then
		return false
	end
	local dir_id = teleport_holder.slot_dir_map[slot]
	local inward = teleport_holder.dir_map[dir_id] or Vector(1, 0)
	local base = room:GetClampedPosition(door_pos + inward * MIRROR_ARRIVAL_INWARD, 20)
	local n = Game():GetNumPlayers()
	for i = 0, n - 1 do
		local p = Game():GetPlayer(i)
		if p then
			local offset = Vector(0, (i - (n - 1) * 0.5) * 18)
			p.Position = base + offset
			p.Velocity = Vector.Zero
		end
	end
	return true
end

local function enter_custom_mirror_door(_doorinfo, player)
	local runtime = d().runtime
	local level = Game():GetLevel()
	-- Final gate: same-frame bomb shatter must not slip past.
	if is_mirror_shattered() and current_dimension(level) ~= DIM_KNIFE then
		local row_block = {
			tag = "mirror_enter",
			ok = false,
			note = "mirror_shattered",
			passable = false,
			pass_reason = "mirror_shattered",
		}
		runtime.special_quest_mirror_enter = row_block
		d().push_event("special_quest_mirror_enter", row_block)
		local entry = find_custom_mirror_entry()
		if entry then
			entry.enter_locked = false
		end
		return
	end
	prepare_mirror_dimension_entry("pre_enter")
	local target, to_dim, room_index = mirror_target_ready(level)
	local from_dim = current_dimension(level)
	local passable, pass_reason = mirror_passable_for_player(player)
	local row = {
		tag = "mirror_enter",
		from_dimension = from_dim,
		to_dimension = to_dim,
		room_index = room_index,
		source_slot = MIRROR_ARRIVAL_SLOT,
		arrival_slot = MIRROR_ARRIVAL_SLOT,
		target = target,
		passable = passable,
		pass_reason = pass_reason,
		ok = false,
	}
	if not passable then
		row.note = pass_reason or "blocked_not_lost"
		runtime.special_quest_mirror_enter = row
		d().push_event("special_quest_mirror_enter", row)
		local entry = find_custom_mirror_entry()
		if entry then
			entry.enter_locked = false
		end
		return
	end
	if target.ok ~= true then
		row.note = "target_room_missing"
		runtime.special_quest_mirror_enter = row
		d().push_event("special_quest_mirror_enter", row)
		local entry = find_custom_mirror_entry()
		if entry then
			entry.enter_locked = false
		end
		return
	end
	local Room_holder = d().Room_holder
	local anim = (RoomTransitionAnim and RoomTransitionAnim.FADE_MIRROR) or 18
	-- NO_DIRECTION: do not let the engine infer LeaveDoor from motion; On_Arrive places LEFT0.
	local dir = (Direction and Direction.NO_DIRECTION) or -1
	local expect_sgid = tonumber(room_index)
	local expect_dim = tonumber(to_dim)
	local ok, err = pcall(function()
		Room_holder.Trans_to(room_index, dir, anim, player, to_dim, {
			On_Arrive = function()
				local lv = Game():GetLevel()
				if current_dimension(lv) ~= expect_dim then
					return
				end
				local cur = lv:GetCurrentRoomDesc()
				if not cur or tonumber(cur.SafeGridIndex) ~= expect_sgid then
					return
				end
				place_players_at_mirror_arrival(MIRROR_ARRIVAL_SLOT)
			end,
		})
	end)
	row.ok = ok == true
	row.error = ok and nil or tostring(err)
	row.note = ok and "transition_started" or "transition_failed"
	row.trans_to_executed = ok == true
	runtime.special_quest_mirror_enter = row
	d().push_event("special_quest_mirror_enter", row)
	push_mirror_interact({
		tag = "mirror_enter_attempt",
		want_open = true,
		passable = passable,
		pass_reason = pass_reason,
		can_enter = passable and target.ok == true,
		can_enter_reason = row.note,
		trans_to_executed = ok == true,
		from_dimension = from_dim,
		to_dimension = to_dim,
		room_index = room_index,
		target_ok = target.ok == true,
		player_losted = is_player_losted(player),
		player_type = player and player.GetPlayerType and player:GetPlayerType() or nil,
	})
	if not ok then
		local entry = find_custom_mirror_entry()
		if entry then
			entry.enter_locked = false
		end
	end
end

local function fill_mirror_spawn_probe(row, preferred)
	local grid_door = d().grid_door
	local snap = grid_door and grid_door.snapshot_door_entry and grid_door.snapshot_door_entry(MIRROR_DOOR_ID)
	row.virtual = snap and snap.virtual
	row.force_virtual = snap and snap.force_virtual
	row.anchor_exists = snap and snap.anchor_exists
	row.sprite_filename = snap and snap.sprite_filename
	row.sprite_animation = snap and snap.sprite_animation
	row.under_grid_type = snap and snap.under_grid_type
	row.under_collision = snap and snap.under_collision
	row.slot = (snap and snap.slot) or preferred
	local room = Game():GetRoom()
	local native = nil
	pcall(function()
		native = room:GetDoor(preferred)
	end)
	if native then
		row.native_left0 = {
			present = true,
			type = native.GetType and native:GetType() or nil,
			target = native.TargetRoomIndex,
			collision = native.CollisionClass,
		}
	else
		local ge = nil
		pcall(function()
			local idx = room:GetGridIndex(room:GetDoorSlotPosition(preferred))
			ge = room:GetGridEntity(idx)
		end)
		row.native_left0 = {
			present = ge ~= nil,
			type = ge and ge.GetType and ge:GetType() or nil,
			target = nil,
			collision = ge and ge.CollisionClass or nil,
		}
	end
end

local function ensure_custom_mirror_door(tag, row, room, preferred)
	local grid_door = d().grid_door
	if not grid_door or not grid_door.try_spawn_virtual_door then
		row.note = "no_grid_door_api"
		return row
	end
	local level = Game():GetLevel()
	local prepare = prepare_mirror_dimension_entry((tag or "spawn") .. "_prepare")
	row.mirror_prepare = prepare
	local target, to_dim, room_index = mirror_target_ready(level)
	local from_dim = current_dimension(level)
	row.mirror_target = target
	row.current_dimension = from_dim
	row.target_dimension = to_dim
	row.transition_room_index = room_index
	row.implementation = "custom_virtual_mirror"
	row.shattered = is_mirror_shattered()
	row.any_losted = any_player_losted()

	local existing = find_custom_mirror_entry()
	if existing and existing.virtual == true
		and existing.anchor and existing.anchor.Exists and existing.anchor:Exists()
	then
		apply_virtual_door_depth(existing.anchor)
		row.physics_before = emit_left0_physics("already_present_before_tick", room, preferred)
		tick_mirror_door_state(existing)
		row.physics_after_first_tick = emit_left0_physics("already_present_after_tick", room, preferred, {
			want_open = existing.want_open,
			under_collision = existing.under_grid and existing.under_grid.CollisionClass or nil,
		})
		row.already_present = true
		row.spawned = true
		row.ok = existing.virtual == true and target.ok == true
		row.slot_matches_preferred = (existing.slot or preferred) == preferred
		row.note = target.ok and "custom_mirror_already_present" or "custom_mirror_present_target_missing"
		row.mirror_target_ok = target.ok == true
		fill_mirror_spawn_probe(row, preferred)
		return row
	end

	if preferred ~= nil then
		local cur = nil
		pcall(function()
			cur = level:GetCurrentRoomDesc()
		end)
		-- Water II 25603: do not force-enable LEFT0 AllowedDoors (layout LEFT exists=False).
		if cur and not skip_force_mirror_left0_allowed(cur) then
			pcall(function()
				cur.AllowedDoors = (cur.AllowedDoors or 0) | (1 << preferred)
			end)
			row.forced_allowed_left0 = true
		else
			row.forced_allowed_left0 = false
			row.forced_allowed_skip_reason = "water_ii_25603_no_left0_allowed"
		end
		row.allowed_doors = cur and cur.AllowedDoors or nil
		row.preferred_slot_allowed = slot_allowed(room, preferred)
		row.data_variant = cur and cur.Data and cur.Data.Variant or nil
	end

	local shattered = is_mirror_shattered()
	local initial_anim = "Closed"
	if shattered and from_dim ~= DIM_KNIFE then
		-- Keep broken look; collision stays sealed (no BrokenClosed in ANM2).
		initial_anim = "BrokenOpen"
	elseif from_dim == DIM_KNIFE or any_player_losted() then
		initial_anim = "Opened"
	end

	-- Physics probe: LEFT0 before virtual door creation (GRID_DOOR origin timing).
	row.physics_before = emit_left0_physics("before_virtual_spawn", room, preferred)

	local spawned = nil
	local err = nil
	local ok, ret = pcall(function()
		return grid_door.try_spawn_virtual_door(room, preferred, nil, {
			door_id = MIRROR_DOOR_ID,
			force_virtual = true,
			hide_native_sprite = true,
			-- Initial seal; tick_mirror_door_state opens collision when want_open.
			seal_native_collision = true,
			-- Native-door geometry via teleport_holder (not legacy check_pos_for_door).
			enter_detection = "confirmed_door",
			refer_slot = DoorSlot.LEFT0,
			loadname = MIRROR_ANM2,
			playname = initial_anim,
			lifecycle_tag = tag or "ensure_mirror",
			should_update = true,
			enter_once = true,
			tp = RoomType.ROOM_DEFAULT,
			check_and_leave = enter_custom_mirror_door,
			on_update = tick_mirror_door_state,
			can_enter = function(_info, player)
				local ok_enter, reason = evaluate_mirror_can_enter(player)
				return ok_enter == true
			end,
		})
	end)
	if ok then
		spawned = ret
	else
		err = tostring(ret)
	end

	row.physics_after_spawn = emit_left0_physics("after_virtual_spawn", room, preferred)

	local entry = find_custom_mirror_entry()
	if entry then
		apply_virtual_door_depth(entry.anchor)
		tick_mirror_door_state(entry)
		row.physics_after_first_tick = emit_left0_physics("after_first_tick", room, preferred, {
			want_open = entry.want_open,
			under_collision = entry.under_grid and entry.under_grid.CollisionClass or nil,
		})
	end
	fill_mirror_spawn_probe(row, preferred)

	row.spawned = entry ~= nil and entry.virtual == true and row.anchor_exists == true
	row.ok = row.spawned == true and target.ok == true
	row.slot_matches_preferred = row.spawned == true
	row.spawn_error = err
	row.mirror_target_ok = target.ok == true
	row.returned_entity_is_anchor = spawned ~= nil and entry ~= nil and entry.anchor ~= nil
		and GetPtrHash and GetPtrHash(spawned) == GetPtrHash(entry.anchor)
	if row.spawned then
		if target.ok then
			row.note = "custom_mirror_spawned"
		else
			row.note = "custom_mirror_spawned_target_missing"
			row.hint = "independent virtual door up; FADE_MIRROR still blocked until knife-dim 78 has Data"
			row.retryable = true
		end
	else
		row.note = "custom_mirror_spawn_failed"
		row.retryable = true
	end
	return row
end

function M.snapshot_special_quest_door_probe(tag)
	local runtime = d().runtime
	local rule = M.resolve_special_quest_door_rule()
	local level = Game():GetLevel()
	local room = Game():GetRoom()
	local desc = level:GetCurrentRoomDesc()
	local dim = M.read_special_quest_dimension(rule)
	local env = read_room_env(level, room, desc)
	local door, slot = nil, nil
	if rule and rule.target_room_index ~= nil then
		door, slot = M.find_special_quest_door(room, rule.target_room_index)
	end
	local custom = find_custom_mirror_entry()
	local room_index = room_index_for_transition(level)
	local cur_dim = current_dimension(level)
	local other_dim = (cur_dim == DIM_KNIFE) and DIM_NORMAL or DIM_KNIFE
	return {
		tag = tag,
		rule = rule,
		env = env,
		dimension = dim,
		has_knife_piece_1 = any_player_has_knife_piece_1(rule and rule.knife_piece_1),
		allowed_doors = env.allowed_doors,
		door_present = door ~= nil,
		slot = slot,
		door = d().snapshot_special_door(door),
		custom_mirror = (function()
			local grid_door = d().grid_door
			local snap = grid_door and grid_door.snapshot_door_entry and grid_door.snapshot_door_entry(MIRROR_DOOR_ID)
			local interact = runtime.special_quest_mirror_interact
			return {
				present = custom ~= nil,
				slot = custom and custom.slot or nil,
				door_id = MIRROR_DOOR_ID,
				enter_locked = custom and custom.enter_locked == true,
				enter_detection = custom and custom.enter_detection,
				virtual = snap and snap.virtual,
				force_virtual = snap and snap.force_virtual,
				anchor_exists = snap and snap.anchor_exists,
				sprite_filename = snap and snap.sprite_filename,
				sprite_animation = snap and snap.sprite_animation,
				under_grid_type = snap and snap.under_grid_type,
				under_collision = snap and snap.under_collision,
				shattered = is_mirror_shattered(),
				any_losted = any_player_losted(),
				want_open = custom and custom.want_open,
				last_status = interact,
			}
		end)(),
		mirror_target = read_dimension_room(level, room_index, other_dim),
		mirror_prepare = runtime.special_quest_mirror_prepare,
		mirror_corridor = runtime.special_quest_mirror_corridor,
		mirror_interact = runtime.special_quest_mirror_interact,
		mirror_interact_log = runtime.special_quest_mirror_interact_log,
		all_doors = env.door_slots,
		last = runtime.special_quest_door,
		last_enter = runtime.special_quest_mirror_enter,
		attempted_this_visit = runtime.special_quest_door_attempted_this_visit == true,
		force_applied = runtime.special_quest_force,
		mineshaft_plank_hits = runtime.mineshaft_plank_hits,
		mineshaft_planks_visual = runtime.special_quest_mineshaft_planks_visual,
		mineshaft_dim1_summary = runtime.mineshaft_dim1_scan_summary,
		custom_mineshaft = (function()
			local entry = find_custom_mineshaft_entry()
			local grid_door = d().grid_door
			local snap = grid_door and grid_door.snapshot_door_entry and grid_door.snapshot_door_entry(MINESHAFT_DOOR_ID)
			local ad = entry and entry.anchor and entry.anchor:GetData() or nil
			return {
				present = entry ~= nil,
				door_id = MINESHAFT_DOOR_ID,
				plank_hits = entry and entry.plank_hits or get_mineshaft_plank_hits(),
				want_open = entry and entry.want_open,
				planks_sprite = entry and entry.planks_sprite ~= nil,
				planks_anim = entry and entry.planks_sprite and entry.planks_sprite.GetAnimation and entry.planks_sprite:GetAnimation() or nil,
				anchor_depth = entry and entry.anchor and entry.anchor.DepthOffset or nil,
				planks_render_count = ad and ad.gc_mineshaft_planks_render_count or 0,
				floor_sample = entry and entry.floor_sample or nil,
				virtual = snap and snap.virtual,
				anchor_exists = snap and snap.anchor_exists,
				sprite_filename = snap and snap.sprite_filename,
				sprite_animation = snap and snap.sprite_animation,
			}
		end)(),
	}
end

function M.apply_force_special_quest(tag)
	local runtime = d().runtime
	local rule = M.resolve_special_quest_door_rule()
	local level = Game():GetLevel()
	local before = nil
	pcall(function()
		if level.GetForceSpecialQuest then
			before = level:GetForceSpecialQuest()
		end
	end)
	local row = {
		tag = tag,
		rule = rule,
		before = before,
		applied = false,
		after = before,
	}
	if not rule or rule.eligible ~= true or rule.force_quest == nil then
		row.note = "not_eligible"
		runtime.special_quest_force = row
		d().push_event("special_quest_force", row)
		return row
	end
	if not level.SetForceSpecialQuest then
		row.note = "no_SetForceSpecialQuest"
		runtime.special_quest_force = row
		d().push_event("special_quest_force", row)
		return row
	end
	local ok, err = pcall(function()
		level:SetForceSpecialQuest(rule.force_quest)
	end)
	row.applied = ok == true
	row.error = ok and nil or tostring(err)
	pcall(function()
		row.after = level:GetForceSpecialQuest()
	end)
	row.note = ok and "set_force_special_quest" or "set_failed"
	runtime.special_quest_force = row
	d().push_event("special_quest_force", row)
	return row
end

local function try_native_spawn(room, ignore_stage_type)
	local api_ok, api_ret_or_err = pcall(function()
		return room:TrySpawnSpecialQuestDoor(ignore_stage_type == true)
	end)
	if api_ok then
		return api_ret_or_err == true, nil
	end
	return false, tostring(api_ret_or_err)
end

local function any_player_has_knife_piece_2()
	local id = KNIFE_PIECE_2
	local n = Game():GetNumPlayers()
	for i = 0, n - 1 do
		local p = Game():GetPlayer(i)
		if p and p.HasCollectible and p:HasCollectible(id) then
			return true
		end
	end
	return false
end

local function get_mineshaft_collapsed()
	local runtime = d().runtime
	if runtime.mineshaft_collapsed == true then
		return true
	end
	local floor = nil
	pcall(function()
		local state = require("Qing_Remaster_scripts.items.golden_compass.state")
		floor = state.get_floor_persist and state.get_floor_persist() or nil
	end)
	if floor and floor.mineshaft_collapsed == true then
		runtime.mineshaft_collapsed = true
		return true
	end
	return false
end

--- True after Collapse has finished once this floor (persisted). Subsequent visits skip to Collapsed.
local function get_mineshaft_collapse_anim_done()
	local runtime = d().runtime
	if runtime.mineshaft_collapse_anim_done == true then
		return true
	end
	local floor = nil
	pcall(function()
		local state = require("Qing_Remaster_scripts.items.golden_compass.state")
		floor = state.get_floor_persist and state.get_floor_persist() or nil
	end)
	if floor and floor.mineshaft_collapse_anim_done == true then
		runtime.mineshaft_collapse_anim_done = true
		return true
	end
	return false
end

local function set_mineshaft_collapse_anim_done(on)
	local runtime = d().runtime
	runtime.mineshaft_collapse_anim_done = on == true
	if d().compass_floor and d().compass_floor.sync_persist then
		d().compass_floor.sync_persist()
	end
end

local function set_mineshaft_collapsed(on)
	local runtime = d().runtime
	runtime.mineshaft_collapsed = on == true
	if on ~= true then
		runtime.mineshaft_collapse_anim_done = false
	end
	if d().compass_floor and d().compass_floor.sync_persist then
		d().compass_floor.sync_persist()
	end
end

local function apply_mineshaft_door_depth(anchor)
	apply_virtual_door_depth(anchor)
end

local function copy_mineshaft_sprite_pose(dst, src)
	if not dst or not src then
		return
	end
	pcall(function()
		dst.Rotation = src.Rotation
		dst.Offset = src.Offset or Vector(0, 15)
		dst.Scale = src.Scale or Vector(1, 1)
		dst.Color = Color(1, 1, 1, 1, 0, 0, 0)
	end)
end

local function purge_orphan_mineshaft_collapse_fx()
	local variant = nil
	pcall(function()
		local e = require("Qing_Remaster_scripts.core.enums")
		variant = e.Entities.ID_EFFECT_MeusNIL
	end)
	if not variant then
		return
	end
	pcall(function()
		local ents = Isaac.FindByType(EntityType.ENTITY_EFFECT, variant, -1, false, false)
		for _, ent in ipairs(ents) do
			if ent and ent:Exists() then
				local ad = ent:GetData()
				if ad and ad.gc_mineshaft_collapse_fx == true then
					ent:Remove()
				end
			end
		end
	end)
end

local function snapshot_mineshaft_collapse_fx(fx)
	local row = {
		door_id = MINESHAFT_DOOR_ID,
		fx_exists = false,
	}
	if not fx then
		return row
	end
	pcall(function()
		row.fx_ptr = GetPtrHash(fx)
		row.fx_init_seed = fx.InitSeed
		row.fx_exists = fx.Exists and fx:Exists() == true
		row.depth_offset = fx.DepthOffset
		row.sorting_layer = fx.SortingLayer
		local spr = fx:GetSprite()
		if spr then
			row.animation = spr.GetAnimation and spr:GetAnimation() or nil
			row.animation_frame = spr.GetFrame and spr:GetFrame() or nil
		end
		local ad = fx:GetData()
		if ad then
			row.update_count = ad.gc_mineshaft_collapse_fx_update_count or 0
			row.render_count = ad.gc_mineshaft_collapse_fx_render_count or 0
		end
	end)
	return row
end

local function destroy_mineshaft_collapse_fx(entry, reason)
	local fx = entry and entry.collapse_fx
	-- No FX → silent (avoid per-frame spam from apply_mineshaft_visuals cleanup paths).
	if not fx then
		if entry then
			entry.collapse_fx_playing = false
		end
		return
	end
	local snap = snapshot_mineshaft_collapse_fx(fx)
	snap.action = "collapse_fx_destroy"
	snap.reason = reason or "destroy"
	snap.game_frame = Game():GetFrameCount()
	pcall(function()
		if fx.Exists and fx:Exists() and fx.Remove then
			fx:Remove()
		end
	end)
	if entry then
		entry.collapse_fx = nil
		entry.collapse_fx_playing = false
	end
	local runtime = d().runtime
	if runtime then
		runtime.mineshaft_collapse_fx_active = false
	end
	d().push_event("special_quest_mineshaft_collapse_fx", snap)
	notify_virtual_door_life("collapse_fx_destroy", snap)
end

--- Hide main door texture path during Collapse FX (Clear WALL/FLOOR → invisible on this carrier).
local function hide_mineshaft_main_for_collapse(entry)
	local anchor = entry and entry.anchor
	if not virtual_entry_anchor_alive(entry) then
		return
	end
	if entry.collapse_visual_hidden == true then
		return
	end
	pcall(function()
		anchor:ClearEntityFlags(MINESHAFT_TEXTURE_FLAGS)
	end)
	entry.collapse_visual_hidden = true
	notify_virtual_door_life("collapse_main_hide", {
		door_id = MINESHAFT_DOOR_ID,
		anchor_ptr = GetPtrHash(anchor),
	})
end

local function show_mineshaft_main_after_collapse(entry)
	local anchor = entry and entry.anchor
	if not virtual_entry_anchor_alive(entry) then
		return
	end
	if entry.collapse_visual_hidden ~= true then
		pcall(function()
			anchor:AddEntityFlags(MINESHAFT_TEXTURE_FLAGS)
		end)
		return
	end
	pcall(function()
		anchor:AddEntityFlags(MINESHAFT_TEXTURE_FLAGS)
	end)
	entry.collapse_visual_hidden = false
	notify_virtual_door_life("collapse_main_show", {
		door_id = MINESHAFT_DOOR_ID,
		anchor_ptr = GetPtrHash(anchor),
	})
end

local function ensure_mineshaft_collapse_fx(entry)
	if not virtual_entry_anchor_alive(entry) then
		return nil
	end
	local fx = entry.collapse_fx
	if fx and fx.Exists and fx:Exists() and not (fx.IsDead and fx:IsDead()) then
		return fx
	end
	local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
	local pos = entry.anchor.Position
	fx = auxi.fire_nil(pos, Vector(0, 0), {cooldown = 30 * 60 * 30})
	if not fx then
		return nil
	end
	-- Temp FX: ordinary entity render — never WALL/FLOOR texture bake.
	-- SortingLayer 0 = SORTING_BACKGROUND (behind grid); use SORTING_NORMAL.
	pcall(function()
		fx:ClearEntityFlags(MINESHAFT_TEXTURE_FLAGS)
		if EntityFlag.FLAG_NO_REMOVE_ON_TEX_RENDER then
			fx:ClearEntityFlags(EntityFlag.FLAG_NO_REMOVE_ON_TEX_RENDER)
		end
		fx.DepthOffset = 0
		fx.SortingLayer = SORTING_NORMAL
	end)
	local main_spr = entry.anchor:GetSprite()
	local spr = fx:GetSprite()
	if spr then
		spr:Load(MINESHAFT_DOOR_ANM2_OUTER, true)
		copy_mineshaft_sprite_pose(spr, main_spr)
		spr:Play("Collapse", true)
	end
	local ad = fx:GetData()
	ad.gc_mineshaft_collapse_fx = true
	ad.nil_mode = MINESHAFT_COLLAPSE_FX_MODE
	ad.skip_nil_distance_cull = true
	ad.removecd = 30 * 60 * 30
	ad.collapse_owner_door_id = MINESHAFT_DOOR_ID
	ad.gc_mineshaft_collapse_fx_update_count = 0
	ad.gc_mineshaft_collapse_fx_render_count = 0
	entry.collapse_fx = fx
	entry.collapse_fx_playing = true
	entry.collapse_started = true
	d().runtime.mineshaft_collapse_fx_active = true
	local payload = snapshot_mineshaft_collapse_fx(fx)
	payload.action = "collapse_fx_create"
	payload.anchor_ptr = GetPtrHash(entry.anchor)
	payload.game_frame = Game():GetFrameCount()
	d().push_event("special_quest_mineshaft_collapse_fx", payload)
	notify_virtual_door_life("collapse_fx_create", payload)
	return fx
end

--- Advance FX; on finish → Collapsed main visible + persist + remove FX.
local function tick_mineshaft_collapse_fx(entry)
	if not entry then
		return false
	end
	local fx = entry.collapse_fx
	if not (fx and fx.Exists and fx:Exists()) then
		entry.collapse_fx = nil
		return false
	end
	pcall(function()
		fx.Position = entry.anchor.Position
		fx.PositionOffset = entry.anchor.PositionOffset or Vector.Zero
	end)
	local spr = fx:GetSprite()
	local main_spr = entry.anchor and entry.anchor:GetSprite()
	copy_mineshaft_sprite_pose(spr, main_spr)
	-- Entity Sprite clock = engine; Nil_holder only ticks finish handoff.
	if spr and spr:IsFinished("Collapse") then
		local finished = snapshot_mineshaft_collapse_fx(fx)
		finished.action = "collapse_fx_finished"
		finished.game_frame = Game():GetFrameCount()
		if main_spr then
			if main_spr.GetFilename and main_spr:GetFilename() ~= MINESHAFT_DOOR_ANM2_OUTER then
				main_spr:Load(MINESHAFT_DOOR_ANM2_OUTER, true)
			end
			if main_spr:GetAnimation() ~= "Collapsed" then
				main_spr:Play("Collapsed", true)
			end
		end
		set_mineshaft_collapse_anim_done(true)
		show_mineshaft_main_after_collapse(entry)
		d().push_event("special_quest_mineshaft_collapse_fx", finished)
		notify_virtual_door_life("collapse_fx_finished", finished)
		destroy_mineshaft_collapse_fx(entry, "collapse_finished")
		return true
	end
	return false
end

local function note_mineshaft_planks_once(entry, spr, hits)
	if not entry or entry.planks_diag_logged then
		return
	end
	entry.planks_diag_logged = true
	local runtime = d().runtime
	local row = {
		filename = spr and spr.GetFilename and spr:GetFilename() or nil,
		animation = spr and spr.GetAnimation and spr:GetAnimation() or nil,
		hits = hits,
		load_ok = spr ~= nil and (not spr.GetFilename or spr:GetFilename() == MINESHAFT_PLANKS_ANM2),
		anchor_depth = entry.anchor and entry.anchor.DepthOffset or nil,
		game_frame = Game():GetFrameCount(),
	}
	runtime.special_quest_mineshaft_planks_visual = row
	d().push_event("special_quest_mineshaft_planks_visual", row)
end

--- Planks are a Sprite owned by the main door MeusNil (drawn in POST_EFFECT_RENDER), not a second Effect.
local function ensure_mineshaft_planks_sprite(entry, hits)
	if not entry or not entry.anchor then
		return nil
	end
	hits = tonumber(hits) or 0
	if hits >= MINESHAFT_PLANKS_MAX then
		entry.planks_sprite = nil
		local ad = entry.anchor:GetData()
		ad.front_linked_sprite = nil
		return nil
	end
	local spr = entry.planks_sprite
	if not spr then
		spr = Sprite()
		spr:Load(MINESHAFT_PLANKS_ANM2, true)
		spr:Play(hits >= 1 and "Damaged" or "Idle", true)
		spr.Scale = Vector(1, 1)
		entry.planks_sprite = spr
		note_mineshaft_planks_once(entry, spr, hits)
	end
	local want = hits >= 1 and "Damaged" or "Idle"
	pcall(function()
		if spr:GetAnimation() ~= want then
			spr:Play(want, true)
		end
	end)
	local ad = entry.anchor:GetData()
	ad.front_linked_sprite = spr
	ad.gc_mineshaft_door = true
	ad.nil_mode = "gc_mineshaft_door"
	ad.skip_nil_distance_cull = true
	return spr
end

local function bind_mineshaft_door_owner(entry)
	if not entry or not entry.anchor then
		return
	end
	apply_mineshaft_door_depth(entry.anchor)
	local ad = entry.anchor:GetData()
	ad.gc_mineshaft_door = true
	ad.nil_mode = "gc_mineshaft_door"
	ad.skip_nil_distance_cull = true
	ad.is_virtual_grid_door = true
	ad.is_grid_door_sprite = true
	ad.grid_door_id = MINESHAFT_DOOR_ID
	if entry.removecd_boost ~= true then
		ad.removecd = 30 * 60 * 30
		entry.removecd_boost = true
	end
end

local function apply_mineshaft_visuals(entry, hits)
	hits = tonumber(hits) or 0
	local collapsed = get_mineshaft_collapsed()
	local anim_done = get_mineshaft_collapse_anim_done()
	local open = (not collapsed) and hits >= MINESHAFT_PLANKS_MAX
	bind_mineshaft_door_owner(entry)
	pcall(function()
		if not entry.anchor then
			return
		end
		local spr = entry.anchor:GetSprite()
		if not spr then
			return
		end
		-- Outer door must stay on dark ANM2 (Collapse/Collapsed live here).
		if spr.GetFilename and spr:GetFilename() ~= MINESHAFT_DOOR_ANM2_OUTER then
			spr:Load(MINESHAFT_DOOR_ANM2_OUTER, true)
		end
		if not collapsed then
			destroy_mineshaft_collapse_fx(entry, "not_collapsed")
			show_mineshaft_main_after_collapse(entry)
			local want = open and "Opened" or "Closed"
			if spr:GetAnimation() ~= want then
				spr:Play(want, true)
			end
			return
		end
		-- Collapsed already played this floor: static main only.
		if anim_done then
			destroy_mineshaft_collapse_fx(entry, "anim_already_done")
			show_mineshaft_main_after_collapse(entry)
			if spr:GetAnimation() ~= "Collapsed" then
				spr:Play("Collapsed", true)
			end
			return
		end
		-- First collapse: main → Collapsed (hidden), temp MeusNil plays Collapse via Nil_holder.
		if spr:GetAnimation() ~= "Collapsed" then
			spr:Play("Collapsed", true)
		end
		hide_mineshaft_main_for_collapse(entry)
		ensure_mineshaft_collapse_fx(entry)
		-- Sprite clock + finish handoff: Nil_holder collapse_fx update (avoid double Update).
	end)
	if collapsed or open then
		entry.planks_sprite = nil
		if entry.anchor then
			entry.anchor:GetData().front_linked_sprite = nil
		end
		return
	end
	ensure_mineshaft_planks_sprite(entry, hits)
end

local function apply_mineshaft_slot_collision(entry, open)
	local room = Game():GetRoom()
	local idx = entry and entry.idx
	if idx == nil and room then
		pcall(function()
			local slot = entry.refer_slot or entry.slot or DoorSlot.UP0
			idx = room:GetGridIndex(room:GetDoorSlotPosition(slot))
		end)
	end
	local ge = entry and entry.under_grid or nil
	if not ge and room and idx ~= nil then
		pcall(function()
			ge = room:GetGridEntity(idx)
		end)
	end
	if not ge then
		return
	end
	-- Never Open/Close/SetLocked — only CollisionClass (StageAPI-style / Water II lesson).
	pcall(function()
		local ns = ge:GetSprite()
		if ns and ns.GetFilename and ns:GetFilename() ~= "gfx/effects/nil_effect.anm2" then
			ns:Load("gfx/effects/nil_effect.anm2", true)
			ns:Play("Idle", true)
		end
	end)
	ge.CollisionClass = open
		and GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER
		or GridCollisionClass.COLLISION_WALL
end

local function try_count_mineshaft_plank_hit(entry)
	local hits = get_mineshaft_plank_hits()
	if get_mineshaft_collapsed() or hits >= MINESHAFT_PLANKS_MAX or not entry or not entry.anchor then
		return hits, false
	end
	local runtime = d().runtime
	local seen = runtime.mineshaft_boom_seen
	if type(seen) ~= "table" then
		seen = {}
		runtime.mineshaft_boom_seen = seen
	end
	local changed = false
	pcall(function()
		local pos = entry.anchor.Position
		for _, boom in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.BOMB_EXPLOSION)) do
			if boom and boom.FrameCount <= 1 then
				local key = tostring(GetPtrHash(boom))
				if not seen[key] and boom.Position:Distance(pos) < (80 * boom.SpriteScale.X) then
					seen[key] = true
					hits = set_mineshaft_plank_hits(hits + 1)
					changed = true
					if SFXManager then
						SFXManager():Play(SoundEffect.SOUND_ROCK_CRUMBLE, 1, 0, false, 1)
					end
					break
				end
			end
		end
	end)
	return hits, changed
end

local function evaluate_mineshaft_can_enter(player)
	if get_mineshaft_collapsed() then
		return false, "mineshaft_collapsed", nil
	end
	local hits = get_mineshaft_plank_hits()
	if hits < MINESHAFT_PLANKS_MAX then
		return false, "planks_intact", nil
	end
	local dest = mineshaft_target_ready(Game():GetLevel())
	if dest.ok ~= true then
		return false, dest.note or "target_room_missing", dest
	end
	return true, "ok", dest
end

local function get_mineshaft_reward_cfg()
	local plan = d().corridor_plan
	local variant = (plan and plan.ROOM_VARIANT_MINES_II_KNIFE2_REWARD) or MINESHAFT_REWARD_VARIANT
	local holder = rawget(_G, "RoomConfig") or rawget(_G, "RoomConfigHolder")
	if not holder or not holder.GetRoomByStageTypeAndVariant then
		return nil, variant
	end
	local cfg = nil
	pcall(function()
		cfg = holder.GetRoomByStageTypeAndVariant(StbType.SPECIAL_ROOMS, RoomType.ROOM_DEFAULT, variant, 0)
	end)
	if not cfg then
		pcall(function()
			cfg = holder.GetRoomByStageTypeAndVariant(StbType.SPECIAL_ROOMS, RoomType.ROOM_DEFAULT, variant, -1)
		end)
	end
	return cfg, variant
end

--- Place fixed Knife Piece 2 reward at Dim1 / SGID 162 (AllowNoNeighbors).
function M.ensure_mineshaft_reward_room(tag)
	local runtime = d().runtime
	local level = Game():GetLevel()
	local sgid = mineshaft_target_sgid()
	local cfg, variant = get_mineshaft_reward_cfg()
	local before = snapshot_mirror_room_identity(level:GetRoomByIdx(sgid, DIM_KNIFE), sgid)
	local row = {
		tag = tag or "mineshaft_reward",
		sgid = sgid,
		dimension = DIM_KNIFE,
		variant = variant,
		before = before,
		ok = false,
	}
	if before.registered and tonumber(before.room_variant) == tonumber(variant) then
		row.ok = true
		row.note = "already_registered"
		row.after = before
		runtime.mineshaft_reward_place = row
		return row
	end
	if not cfg then
		row.note = "missing_roomconfig_" .. tostring(variant)
		row.retryable = true
		runtime.mineshaft_reward_place = row
		d().push_event("special_quest_mineshaft_reward_place", row)
		return row
	end
	local root = d().require_root_seed and d().require_root_seed("mineshaft_reward")
	local place_seed = root or 1
	if d().derive_seed and root then
		place_seed = d().derive_seed(root, "mineshaft_reward_place", sgid, 1) or root
	end
	local dst = level:GetRoomByIdx(sgid, DIM_KNIFE)
	local visited_n = tonumber(before.visited) or 0
	if dst and dst.Data and before.safe_ok ~= true and visited_n <= 0 then
		if tonumber(dst.SafeGridIndex) == tonumber(sgid) then
			pcall(function()
				dst.Data = nil
				dst.OverrideData = nil
			end)
			row.cleared_broken_stub = true
		else
			row.skipped_clear_alias = true
			row.alias_owner = dst.SafeGridIndex
		end
	end
	local placed, place_err = nil, nil
	if level.TryPlaceRoom then
		local can_place = nil
		if level.CanPlaceRoom then
			local ok_c, cv = pcall(function()
				return level:CanPlaceRoom(cfg, sgid, DIM_KNIFE, true, true, true)
			end)
			can_place = ok_c and cv == true
			row.can_place = can_place
		end
		if can_place ~= false then
			local ok_p, ret = pcall(function()
				return level:TryPlaceRoom(cfg, sgid, DIM_KNIFE, place_seed, true, true, true)
			end)
			if ok_p then
				placed = ret
			else
				place_err = tostring(ret)
			end
			row.try_place_ok = ok_p and placed ~= nil
			row.try_place_error = place_err
		end
	else
		row.note = "no_TryPlaceRoom"
	end
	pcall(function()
		dst = level:GetRoomByIdx(sgid, DIM_KNIFE)
	end)
	local after = snapshot_mirror_room_identity(dst, sgid)
	-- Never write Data onto an alias descriptor that is not SGID 162.
	if not after.registered then
		row.note = place_err or "try_place_failed"
		row.retryable = true
		row.after = after
		runtime.mineshaft_reward_place = row
		d().push_event("special_quest_mineshaft_reward_place", row)
		return row
	end
	if dst and dst.Data then
		local _, _, _, visited_now, seeds_ok = read_desc_seeds(dst)
		if not seeds_ok and d().init_desc_runtime and root then
			row.runtime_init = d().init_desc_runtime(dst, {
				idx = sgid,
				base_seed = root,
				domain_spawn = "mineshaft_reward_spawn",
				domain_deco = "mineshaft_reward_deco",
				domain_award = "mineshaft_reward_award",
				stream = 1,
				fresh_room = (tonumber(visited_now) or 0) <= 0,
			})
		end
	end
	row.after = snapshot_mirror_room_identity(dst, sgid)
	row.ok = row.after.registered == true
	row.note = row.ok and "reward_room_ready" or "registration_incomplete"
	row.retryable = not row.ok
	runtime.mineshaft_reward_place = row
	d().push_event("special_quest_mineshaft_reward_place", row)
	return row
end

local function place_players_at_mineshaft_arrival(slot)
	slot = slot or DoorSlot.UP0
	return place_players_at_mirror_arrival(slot)
end

local function find_mineshaft_return_entry()
	local grid_door = d().grid_door
	if grid_door and grid_door.find_door_by_id then
		return grid_door.find_door_by_id(MINESHAFT_RETURN_DOOR_ID)
	end
	return nil
end

local function enter_mineshaft_return_door(_doorinfo, player)
	local runtime = d().runtime
	local entry_sgid = d().entry_sgid or 78
	local row = {
		tag = "mineshaft_return",
		from_dimension = DIM_KNIFE,
		to_dimension = DIM_NORMAL,
		room_index = entry_sgid,
		ok = false,
	}
	if any_player_has_knife_piece_2() then
		runtime.mineshaft_reward_visited = true
	end
	local Room_holder = d().Room_holder
	local anim = (RoomTransitionAnim and RoomTransitionAnim.FADE) or 2
	local dir = (Direction and Direction.NO_DIRECTION) or -1
	local ok, err = pcall(function()
		Room_holder.Trans_to(entry_sgid, dir, anim, player, DIM_NORMAL, {
			On_Arrive = function()
				local lv = Game():GetLevel()
				if current_dimension(lv) ~= DIM_NORMAL then
					return
				end
				local cur = lv:GetCurrentRoomDesc()
				if not cur or tonumber(cur.SafeGridIndex) ~= tonumber(entry_sgid) then
					return
				end
				if any_player_has_knife_piece_2() then
					set_mineshaft_collapsed(true)
				end
				place_players_at_mineshaft_arrival(DoorSlot.UP0)
			end,
		})
	end)
	row.ok = ok == true
	row.error = ok and nil or tostring(err)
	row.note = ok and "transition_started" or "transition_failed"
	runtime.special_quest_mineshaft_return = row
	d().push_event("special_quest_mineshaft_return", row)
	if not ok then
		local entry = find_mineshaft_return_entry()
		if entry then
			entry.enter_locked = false
		end
	end
end

local function tick_mineshaft_return_door(entry)
	if not entry or not entry.anchor then
		return
	end
	apply_virtual_door_depth(entry.anchor)
	-- Inner door stays open for exit; light ANM2, no floor tint.
	pcall(function()
		local spr = entry.anchor:GetSprite()
		if spr and spr:GetAnimation() ~= "Opened" then
			spr:Play("Opened", true)
		end
	end)
	apply_mineshaft_slot_collision(entry, true)
end

--- Reward room (Dim1 / 162): virtual DOWN0 return to Mines II entry 78.
--- Identity = Dim1 + SGID 162 (+ optional 25605). Do not require live 25604 / mines_ii template.
local function ensure_mineshaft_return_door(tag)
	local runtime = d().runtime
	if not runtime.corridor_active then
		return nil
	end
	local level = Game():GetLevel()
	if current_dimension(level) ~= DIM_KNIFE then
		return nil
	end
	local cur = level:GetCurrentRoomDesc()
	local sgid = mineshaft_target_sgid()
	if not cur or tonumber(cur.SafeGridIndex) ~= tonumber(sgid) then
		return nil
	end
	-- Optional layout check: prefer 25605 when Data is present; do not hard-fail without it.
	local plan = d().corridor_plan
	local expect_v = (plan and plan.ROOM_VARIANT_MINES_II_KNIFE2_REWARD) or MINESHAFT_REWARD_VARIANT
	local live_v = cur.Data and tonumber(cur.Data.Variant) or nil
	if live_v ~= nil and live_v ~= tonumber(expect_v) then
		return nil
	end
	runtime.mineshaft_reward_visited = true
	local grid_door = d().grid_door
	if not grid_door or not grid_door.try_spawn_virtual_door then
		return nil
	end
	local room = Game():GetRoom()
	-- 25605: DOWN0 exists=False — never force-reserve AllowedDoors DOWN0.
	local preferred = DoorSlot.DOWN0
	local existing = find_mineshaft_return_entry()
	if existing and existing.anchor and existing.anchor.Exists and existing.anchor:Exists() then
		tick_mineshaft_return_door(existing)
		return existing
	end
	pcall(function()
		return grid_door.try_spawn_virtual_door(room, preferred, nil, {
			door_id = MINESHAFT_RETURN_DOOR_ID,
			force_virtual = true,
			hide_native_sprite = true,
			seal_native_collision = true,
			enter_detection = "confirmed_door",
			refer_slot = DoorSlot.DOWN0,
			loadname = MINESHAFT_DOOR_ANM2_INNER,
			playname = "Opened",
			lifecycle_tag = tag or "ensure_mineshaft_return",
			should_update = true,
			enter_once = true,
			tp = RoomType.ROOM_DEFAULT,
			check_and_leave = enter_mineshaft_return_door,
			on_update = tick_mineshaft_return_door,
			can_enter = function()
				return true
			end,
		})
	end)
	local entry = find_mineshaft_return_entry()
	if entry then
		apply_virtual_door_depth(entry.anchor)
		tick_mineshaft_return_door(entry)
		d().push_event("special_quest_mineshaft_return_door", {
			tag = tag or "spawn",
			ok = true,
			sgid = sgid,
			slot = preferred,
			variant = live_v,
		})
	end
	return entry
end

local function enter_custom_mineshaft_door(_doorinfo, player)
	local runtime = d().runtime
	local can, reason, dest = evaluate_mineshaft_can_enter(player)
	local from_dim = current_dimension(Game():GetLevel())
	local row = {
		tag = "mineshaft_enter",
		from_dimension = from_dim,
		to_dimension = DIM_KNIFE,
		room_index = mineshaft_target_sgid(),
		plank_hits = get_mineshaft_plank_hits(),
		target = dest,
		can_enter = can == true,
		can_enter_reason = reason,
		ok = false,
	}
	if not can then
		row.note = reason or "blocked"
		runtime.special_quest_mineshaft_enter = row
		d().push_event("special_quest_mineshaft_enter", row)
		local entry = find_custom_mineshaft_entry()
		if entry then
			entry.enter_locked = false
		end
		return
	end
	local Room_holder = d().Room_holder
	local anim = (RoomTransitionAnim and RoomTransitionAnim.FADE) or 2
	local dir = (Direction and Direction.NO_DIRECTION) or -1
	local expect_sgid = tonumber(dest.room_index)
	local expect_dim = DIM_KNIFE
	local ok, err = pcall(function()
		Room_holder.Trans_to(expect_sgid, dir, anim, player, expect_dim, {
			On_Arrive = function()
				local lv = Game():GetLevel()
				if current_dimension(lv) ~= expect_dim then
					return
				end
				local cur = lv:GetCurrentRoomDesc()
				if not cur or tonumber(cur.SafeGridIndex) ~= expect_sgid then
					return
				end
				d().runtime.mineshaft_reward_visited = true
				-- 78 leaves UP0 → arrive 162 from DOWN0 (toward room center).
				place_players_at_mineshaft_arrival(DoorSlot.DOWN0)
			end,
		})
	end)
	row.ok = ok == true
	row.error = ok and nil or tostring(err)
	row.note = ok and "transition_started" or "transition_failed"
	row.trans_to_executed = ok == true
	runtime.special_quest_mineshaft_enter = row
	d().push_event("special_quest_mineshaft_enter", row)
	if not ok then
		local entry = find_custom_mineshaft_entry()
		if entry then
			entry.enter_locked = false
		end
	end
end

local function tick_mineshaft_door_state(entry)
	if not entry then
		return
	end
	-- After claiming Knife Piece 2 and returning, seal the entry permanently.
	if (not get_mineshaft_collapsed())
		and any_player_has_knife_piece_2()
		and d().runtime.mineshaft_reward_visited == true
	then
		set_mineshaft_collapsed(true)
		d().push_event("special_quest_mineshaft_collapsed", {
			frame = Game():GetFrameCount(),
			reason = "knife2_claimed_and_returned",
		})
	end
	local hits, hit_changed = try_count_mineshaft_plank_hit(entry)
	local collapsed = get_mineshaft_collapsed()
	local open = (not collapsed) and hits >= MINESHAFT_PLANKS_MAX
	entry.plank_hits = hits
	entry.want_open = open
	entry.collapsed = collapsed
	apply_mineshaft_visuals(entry, hits)
	apply_mineshaft_slot_collision(entry, open)
	if hit_changed then
		local runtime = d().runtime
		runtime.special_quest_mineshaft_plank = {
			hits = hits,
			open = open,
			frame = Game():GetFrameCount(),
		}
		d().push_event("special_quest_mineshaft_plank", runtime.special_quest_mineshaft_plank)
		if open then
			M.maybe_scan_mineshaft_dimension1("planks_open", {force = true})
		end
	end
end

local function ensure_custom_mineshaft_door(tag, row, room, preferred)
	local grid_door = d().grid_door
	if not grid_door or not grid_door.try_spawn_virtual_door then
		row.note = "no_grid_door_api"
		return row
	end
	preferred = preferred or DoorSlot.UP0
	local level = Game():GetLevel()
	row.mineshaft_reward_place = M.ensure_mineshaft_reward_room((tag or "spawn") .. "_reward")
	local target = mineshaft_target_ready(level)
	row.mineshaft_target = target
	row.implementation = "custom_virtual_mineshaft"
	row.plank_hits = get_mineshaft_plank_hits()
	row.collapsed = get_mineshaft_collapsed()

	local existing = find_custom_mineshaft_entry()
	if existing and existing.virtual == true
		and existing.anchor and existing.anchor.Exists and existing.anchor:Exists()
	then
		bind_mineshaft_door_owner(existing)
		tick_mineshaft_door_state(existing)
		row.already_present = true
		row.spawned = true
		row.ok = existing.virtual == true
		row.slot_matches_preferred = (existing.slot or preferred) == preferred
		row.note = target.ok and "custom_mineshaft_already_present" or "custom_mineshaft_present_target_missing"
		row.target_ok = target.ok == true
		row.retryable = target.ok ~= true
		row.anchor_depth = existing.anchor and existing.anchor.DepthOffset or nil
		row.planks_sprite = existing.planks_sprite ~= nil
		M.maybe_scan_mineshaft_dimension1((tag or "present") .. "_enter_78")
		row.mineshaft_dim1 = d().runtime.mineshaft_dim1_scan_summary
		return row
	end

	local cur = level:GetCurrentRoomDesc()
	-- Mines II 25604: do not force-enable UP0 AllowedDoors.
	if cur and preferred ~= nil then
		local plan = d().corridor_plan
		local id = d().read_level_identity and d().read_level_identity() or nil
		local live_variant = cur.Data and tonumber(cur.Data.Variant)
		local reserve = true
		if plan and plan.should_reserve_mineshaft_up0_allowed then
			reserve = plan.should_reserve_mineshaft_up0_allowed(
				id and id.stage,
				id and id.stage_type,
				live_variant
			) == true
		elseif mines_ii_custom_door_enabled() then
			reserve = false
		end
		if reserve then
			pcall(function()
				cur.AllowedDoors = (cur.AllowedDoors or 0) | (1 << preferred)
			end)
			row.forced_allowed_up0 = true
		else
			row.forced_allowed_up0 = false
			row.forced_allowed_skip_reason = "mines_ii_25604_no_up0_allowed"
		end
		row.allowed_doors = cur.AllowedDoors
		row.preferred_slot_allowed = slot_allowed(room, preferred)
		row.data_variant = live_variant
	end

	local hits = get_mineshaft_plank_hits()
	local collapsed = get_mineshaft_collapsed()
	-- Main door never plays Collapse (temp FX owns that). Collapsed when collapsed; FX if anim not done.
	local initial_anim
	if collapsed then
		initial_anim = "Collapsed"
	elseif hits >= MINESHAFT_PLANKS_MAX then
		initial_anim = "Opened"
	else
		initial_anim = "Closed"
	end
	local spawned = nil
	local err = nil
	local ok, ret = pcall(function()
		return grid_door.try_spawn_virtual_door(room, preferred, nil, {
			door_id = MINESHAFT_DOOR_ID,
			force_virtual = true,
			hide_native_sprite = true,
			seal_native_collision = true,
			enter_detection = "confirmed_door",
			refer_slot = DoorSlot.UP0,
			loadname = MINESHAFT_DOOR_ANM2_OUTER,
			playname = initial_anim,
			lifecycle_tag = tag or "ensure_mineshaft",
			should_update = true,
			enter_once = true,
			tp = RoomType.ROOM_DEFAULT,
			check_and_leave = enter_custom_mineshaft_door,
			on_update = tick_mineshaft_door_state,
			can_enter = function(_info, player)
				local ok_enter = evaluate_mineshaft_can_enter(player)
				return ok_enter == true
			end,
		})
	end)
	if ok then
		spawned = ret
	else
		err = tostring(ret)
	end

	local entry = find_custom_mineshaft_entry()
	if entry then
		bind_mineshaft_door_owner(entry)
		tick_mineshaft_door_state(entry)
		row.anchor_depth = entry.anchor and entry.anchor.DepthOffset or nil
		row.planks_sprite = entry.planks_sprite ~= nil
	end

	-- Refresh target after place attempt.
	target = mineshaft_target_ready(level)
	row.mineshaft_target = target
	row.spawned = entry ~= nil and entry.virtual == true
	row.ok = row.spawned == true
	row.slot_matches_preferred = row.spawned == true
	row.spawn_error = err
	row.target_ok = target.ok == true
	row.retryable = target.ok ~= true
	row.plank_hits = get_mineshaft_plank_hits()
	if row.spawned then
		if target.ok then
			row.note = "custom_mineshaft_spawned"
		else
			row.note = "custom_mineshaft_spawned_target_missing"
			row.hint = "virtual door up; enter blocked until Dim1 SGID 162 reward is registered"
		end
	else
		row.note = "custom_mineshaft_spawn_failed"
	end
	row.returned_entity_is_anchor = spawned ~= nil and entry ~= nil and entry.anchor ~= nil
		and GetPtrHash and GetPtrHash(spawned) == GetPtrHash(entry.anchor)
	M.maybe_scan_mineshaft_dimension1((tag or "spawn") .. "_enter_78")
	row.mineshaft_dim1 = d().runtime.mineshaft_dim1_scan_summary
	return row
end

local function ensure_native_mineshaft_door(tag, row, room, cur, preferred, rule)
	local existing, existing_slot = M.find_special_quest_door(room, rule.target_room_index)
	if existing then
		row.already_present = true
		row.spawned = true
		row.ok = true
		row.slot = existing_slot
		row.slot_matches_preferred = existing_slot == preferred
		row.door = d().snapshot_special_door(existing)
		row.note = "already_present"
		row.implementation = "native_special_quest"
		return row
	end

	if preferred ~= nil then
		pcall(function()
			cur.AllowedDoors = (cur.AllowedDoors or 0) | (1 << preferred)
		end)
		row.allowed_doors = cur.AllowedDoors
		row.preferred_slot_allowed = slot_allowed(room, preferred)
	end

	local force_reapply = M.apply_force_special_quest((tag or "spawn") .. "_pre_try")
	row.force_reapply = {
		applied = force_reapply and force_reapply.applied,
		after = force_reapply and force_reapply.after,
		note = force_reapply and force_reapply.note,
	}

	local api_false, err_false = try_native_spawn(room, false)
	row.api_attempts[#row.api_attempts + 1] = {
		ignore_stage_type = false,
		returned = api_false,
		error = err_false,
		doors_after = snapshot_door_slots(room),
	}
	row.api_returned = api_false

	local door, slot = M.find_special_quest_door(room, rule.target_room_index)
	if not door then
		local api_true, err_true = try_native_spawn(room, true)
		row.api_attempts[#row.api_attempts + 1] = {
			ignore_stage_type = true,
			returned = api_true,
			error = err_true,
			doors_after = snapshot_door_slots(room),
			note = "diagnostic_ignore_stage_type",
		}
		row.api_returned_ignore_stage = api_true
		door, slot = M.find_special_quest_door(room, rule.target_room_index)
	end

	row.slot = slot
	row.door = d().snapshot_special_door(door)
	row.spawned = door ~= nil
	row.slot_matches_preferred = door ~= nil and slot == preferred
	row.ok = row.spawned == true
	row.implementation = "native_special_quest"
	if row.spawned then
		row.note = row.slot_matches_preferred and "spawned_preferred_slot" or "spawned_other_slot"
	elseif row.api_returned or row.api_returned_ignore_stage then
		row.note = "api_true_but_door_missing"
	elseif row.preferred_slot_allowed == false then
		row.note = "preferred_slot_not_allowed"
	else
		row.note = "spawn_failed"
	end
	return row
end

--- Spawn room: entry 78 only (design).
--- Mirror: custom virtual. Mines II: custom planks virtual. Other mineshaft (Ashpit): native.
function M.ensure_special_quest_door(tag, opts)
	opts = opts or {}
	local runtime = d().runtime
	if not runtime.corridor_active then
		return nil
	end
	local level = Game():GetLevel()
	local cur = level:GetCurrentRoomDesc()
	if not cur then
		return nil
	end
	local entry_sgid = d().entry_sgid
	local sgid = cur.SafeGridIndex
	local cur_idx = nil
	pcall(function()
		cur_idx = level:GetCurrentRoomIndex()
	end)
	-- Prefer SafeGridIndex; fall back to CurrentRoomIndex when identity was corrupted (-1).
	local at_entry = sgid == entry_sgid
		or tonumber(cur_idx) == tonumber(entry_sgid)
	if not at_entry then
		return nil
	end
	if sgid ~= entry_sgid and tonumber(cur_idx) == tonumber(entry_sgid) then
		sgid = entry_sgid
	end

	local visit_key = tostring(entry_sgid) .. "@" .. tostring(current_dimension(level) or 0)
	local rule = M.resolve_special_quest_door_rule()
	if runtime.special_quest_door_attempted_sgid == visit_key then
		local last = runtime.special_quest_door
		local live, live_entry, door_id = current_virtual_entry_alive(rule)
		local retryable = last and last.retryable == true
		local gate = {
			tag = tag,
			entry_sgid = entry_sgid,
			visit_key = visit_key,
			attempted_sgid = runtime.special_quest_door_attempted_sgid,
			last_attempt_retryable = retryable == true,
			existing_anchor = live == true,
			door_id = door_id,
			rule_kind = rule and rule.kind,
			anchor_ptr = live_entry and live_entry.anchor and GetPtrHash(live_entry.anchor) or nil,
		}
		pcall(function()
			gate.room_frame = Game():GetRoom():GetFrameCount()
		end)
		-- Attempted only dedupes when the live virtual door still exists.
		if live and not retryable then
			gate.early_return = "attempted_and_live"
			gate.note = "reuse_last_without_respawn"
			d().push_event("special_quest_door_ensure_gate", gate)
			notify_virtual_door_life("ensure_gate", gate)
			return last
		end
		if not live then
			gate.early_return = "attempted_but_missing_recreate"
			runtime.special_quest_door_attempted_sgid = nil
			runtime.special_quest_door_attempted_this_visit = false
		elseif retryable then
			gate.early_return = "attempted_retryable_recreate"
			runtime.special_quest_door_attempted_sgid = nil
			runtime.special_quest_door_attempted_this_visit = false
		end
		d().push_event("special_quest_door_ensure_gate", gate)
		notify_virtual_door_life("ensure_gate", gate)
	end

	local room = Game():GetRoom()
	local dim = M.read_special_quest_dimension(rule)
	local has_knife = any_player_has_knife_piece_1(rule and rule.knife_piece_1)
	local env_before = read_room_env(level, room, cur)
	local preferred = rule and rule.preferred_slot
	local row = {
		tag = tag,
		sgid = sgid,
		spawn_room_role = "entry",
		rule = rule,
		env_before = env_before,
		dimension = dim,
		has_knife_piece_1 = has_knife,
		preferred_slot = preferred,
		preferred_slot_allowed = preferred ~= nil and slot_allowed(room, preferred) or nil,
		target_room_index = rule and rule.target_room_index,
		ok = false,
		spawned = false,
		already_present = false,
		api_attempts = {},
		api_returned = nil,
		api_returned_ignore_stage = nil,
		slot = nil,
		slot_matches_preferred = nil,
		allowed_doors = cur.AllowedDoors,
		note = nil,
		retryable = false,
	}

	if not rule or rule.eligible ~= true then
		row.note = (rule and rule.reason) or "ineligible"
		runtime.special_quest_door = row
		d().push_event("special_quest_door", row)
		-- Permanent for this floor visit: do not spam.
		mark_attempted(runtime, visit_key)
		return row
	end
	if rule.requires_knife_piece_1 and not has_knife then
		row.note = "mineshaft_requires_knife_piece_1"
		row.retryable = true
		runtime.special_quest_door = row
		d().push_event("special_quest_door", row)
		-- Soft fail: knife may be acquired later this visit.
		return row
	end
	if rule.kind == "mineshaft" and mines_ii_custom_door_enabled() then
		row.mineshaft_reward_place = M.ensure_mineshaft_reward_room((tag or "spawn") .. "_precheck")
		dim = M.read_special_quest_dimension(rule)
		row.dimension = dim
	end
	if dim.dimension_ready ~= true then
		row.note = "dimension_not_ready"
		row.retryable = true
		runtime.special_quest_door = row
		d().push_event("special_quest_door", row)
		-- Soft fail: reward room / dimension readiness may settle later.
		return row
	end

	-- Real attempt starts here.
	mark_attempted(runtime, visit_key)

	if rule.kind == "mirror" then
		ensure_custom_mirror_door(tag, row, room, preferred or DoorSlot.LEFT0)
	elseif rule.kind == "mineshaft" and mines_ii_custom_door_enabled() then
		ensure_custom_mineshaft_door(tag, row, room, preferred or DoorSlot.UP0)
	else
		ensure_native_mineshaft_door(tag, row, room, cur, preferred, rule)
	end

	row.env_after = read_room_env(level, room, cur)
	runtime.special_quest_door = row
	d().push_event("special_quest_door", row)
	return row
end

-- Back-compat name used by runtime enter-78 call sites.
function M.ensure_entry_78_special_quest_door(tag)
	return M.ensure_special_quest_door(tag, {prefer_entry = true})
end

local MIRROR_79_SGID = 79
local KNIFE_PIECE_1 = (CollectibleType and CollectibleType.COLLECTIBLE_KNIFE_PIECE_1) or 626

--- Collectible spawn markers from RoomConfig Spawns (Type=5 Variant=100 SubType=0).
local function collect_collectible_spawn_markers(desc)
	local markers = {}
	if not desc or not desc.Data or not desc.Data.Spawns then
		return markers
	end
	local spawns = desc.Data.Spawns
	local size = spawns.Size or 0
	for i = 0, size - 1 do
		local info = spawns:Get(i)
		if info then
			local entry = nil
			pcall(function()
				if info.PickEntry then
					entry = info:PickEntry(0)
				end
			end)
			if entry
				and tonumber(entry.Type) == EntityType.ENTITY_PICKUP
				and tonumber(entry.Variant) == PickupVariant.PICKUP_COLLECTIBLE
				and tonumber(entry.Subtype) == 0
			then
				markers[#markers + 1] = {
					x = tonumber(info.X) or 0,
					y = tonumber(info.Y) or 0,
					index = i,
				}
			end
		end
	end
	table.sort(markers, function(a, b)
		if a.y ~= b.y then
			return a.y < b.y
		end
		if a.x ~= b.x then
			return a.x < b.x
		end
		return a.index < b.index
	end)
	return markers
end

local function find_collectible_near(pos, max_dist)
	max_dist = max_dist or 24
	local best, best_d = nil, max_dist + 1
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, -1, false, false)) do
		local ped = ent:ToPickup()
		if ped and ped.Position:Distance(pos) < best_d then
			best = ped
			best_d = ped.Position:Distance(pos)
		end
	end
	return best
end

--- Mirror Dim1 SGID 79 first-enter quest reward: Knife Piece 1 (626) at layout collectible marker.
--- Floor-persist only; does not touch normal-dimension 79 or fixed_84_options.
function M.try_spawn_mirror_79_knife_piece(tag)
	local runtime = d().runtime
	if not runtime.corridor_active then
		return nil
	end
	if runtime.mirror_79_knife_piece_spawned == true then
		return nil
	end
	local level = Game():GetLevel()
	if current_dimension(level) ~= DIM_KNIFE then
		return nil
	end
	local cur = level:GetCurrentRoomDesc()
	if not cur or tonumber(cur.SafeGridIndex) ~= MIRROR_79_SGID then
		return nil
	end

	local row = {
		tag = tag,
		sgid = MIRROR_79_SGID,
		dimension = DIM_KNIFE,
		ok = false,
		note = nil,
	}

	-- Legacy Continue: room already visited without persist flag → seal, never re-reward.
	local visited = tonumber(cur.VisitedCount) or 0
	row.visited_count = visited
	local existing_knife = nil
	for _, ent in ipairs(Isaac.FindByType(
		EntityType.ENTITY_PICKUP,
		PickupVariant.PICKUP_COLLECTIBLE,
		KNIFE_PIECE_1,
		false,
		false
	)) do
		existing_knife = ent:ToPickup()
		if existing_knife then
			break
		end
	end
	if existing_knife or visited > 1 then
		runtime.mirror_79_knife_piece_spawned = true
		if d().compass_floor and d().compass_floor.sync_persist then
			d().compass_floor.sync_persist()
		end
		row.ok = true
		row.note = existing_knife and "legacy_seal_existing_knife" or "legacy_seal_revisited"
		row.collectible = KNIFE_PIECE_1
		runtime.special_quest_mirror_79_knife = row
		d().push_event("special_quest_mirror_79_knife", row)
		return row
	end

	local markers = collect_collectible_spawn_markers(cur)
	row.marker_count = #markers
	if #markers == 0 then
		row.note = "no_collectible_spawn_marker"
		runtime.special_quest_mirror_79_knife = row
		d().push_event("special_quest_mirror_79_knife", row)
		return row
	end

	local marker = markers[1]
	local room = Game():GetRoom()
	local width = (cur.Data and cur.Data.Width) or room:GetGridWidth() - 2
	local gidx = (width + 2) * (marker.y + 1) + marker.x + 1
	local pos = room:GetGridPosition(gidx)
	row.marker_x = marker.x
	row.marker_y = marker.y
	row.grid_index = gidx

	local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
	local ped = find_collectible_near(pos, 28)
	local created = false
	if not ped then
		local spawned = Isaac.Spawn(
			EntityType.ENTITY_PICKUP,
			PickupVariant.PICKUP_COLLECTIBLE,
			0,
			pos,
			Vector.Zero,
			nil
		)
		ped = spawned and spawned:ToPickup() or nil
		created = ped ~= nil
	end
	if not ped then
		row.note = "pedestal_missing"
		runtime.special_quest_mirror_79_knife = row
		d().push_event("special_quest_mirror_79_knife", row)
		return row
	end

	auxi.self_morph(ped, {
		EntityType.ENTITY_PICKUP,
		PickupVariant.PICKUP_COLLECTIBLE,
		KNIFE_PIECE_1,
	})
	local final_st = ped.SubType
	local ok = tonumber(final_st) == KNIFE_PIECE_1
	row.created_new = created
	row.collectible = final_st
	row.ok = ok == true
	row.note = ok and "knife_piece_1_ready" or "morph_subtype_mismatch"
	if ok then
		runtime.mirror_79_knife_piece_spawned = true
		if d().compass_floor and d().compass_floor.sync_persist then
			d().compass_floor.sync_persist()
		end
	end
	runtime.special_quest_mirror_79_knife = row
	d().push_event("special_quest_mirror_79_knife", row)
	return row
end

function M.on_leave_spawn_room(prev_sgid)
	local runtime = d().runtime
	local entry_sgid = d().entry_sgid
	if prev_sgid == entry_sgid then
		runtime.special_quest_door_attempted_this_visit = false
		runtime.special_quest_door_attempted_sgid = nil
		-- Collapse FX must not linger across rooms; re-enter replays if anim not done.
		local entry = find_custom_mineshaft_entry()
		if entry then
			destroy_mineshaft_collapse_fx(entry, "leave_spawn_room")
			-- Keep main Collapsed+hidden until re-enter tick; show if already done.
			if get_mineshaft_collapse_anim_done() then
				show_mineshaft_main_after_collapse(entry)
			end
		end
		purge_orphan_mineshaft_collapse_fx()
	end
end

--- Dim1 / 162 return door — public for POST_NEW_ROOM early create (idempotent).
function M.ensure_mineshaft_return_door(tag)
	return ensure_mineshaft_return_door(tag)
end

--- Debug: force Collapse FX at entry door without needing Knife Piece 2 return.
function M.force_mineshaft_collapse_playback(tag)
	tag = tag or "force_collapse_ui"
	local runtime = d().runtime
	local row = {
		tag = tag,
		ok = false,
	}
	if not runtime or not runtime.corridor_active then
		row.note = "corridor_inactive"
		d().push_event("special_quest_mineshaft_force_collapse", row)
		return row
	end
	if not mines_ii_custom_door_enabled() then
		row.note = "not_mines_ii"
		d().push_event("special_quest_mineshaft_force_collapse", row)
		return row
	end
	runtime.mineshaft_reward_visited = true
	set_mineshaft_collapse_anim_done(false)
	set_mineshaft_collapsed(true)
	-- Ensure entry door exists (may recreate after attempted/missing gate).
	M.ensure_special_quest_door(tag .. "_ensure")
	local entry = find_custom_mineshaft_entry()
	if not virtual_entry_anchor_alive(entry) then
		row.note = "no_mineshaft_door"
		d().push_event("special_quest_mineshaft_force_collapse", row)
		return row
	end
	destroy_mineshaft_collapse_fx(entry, "force_restart")
	entry.collapse_started = false
	entry.collapse_visual_hidden = false
	apply_mineshaft_visuals(entry, get_mineshaft_plank_hits())
	row.ok = entry.collapse_fx ~= nil
	row.fx_ptr = entry.collapse_fx and GetPtrHash(entry.collapse_fx) or nil
	row.note = row.ok and "collapse_fx_started" or "collapse_fx_missing"
	row.sgid = d().entry_sgid
	d().push_event("special_quest_mineshaft_force_collapse", row)
	notify_virtual_door_life("force_collapse", row)
	return row
end

--- Per-frame: keep anim/collision in sync; respawn carrier if rematerialize cleared it.
function M.tick_mirror_door(tag)
	local runtime = d().runtime
	if not runtime.corridor_active then
		return nil
	end
	local rule = M.resolve_special_quest_door_rule()
	if not rule then
		return nil
	end
	local level = Game():GetLevel()
	local cur = level:GetCurrentRoomDesc()
	-- Dim1 / 162 reward return door first — must not require entry SGID 78.
	if rule.kind == "mineshaft"
		and current_dimension(level) == DIM_KNIFE
		and cur
		and tonumber(cur.SafeGridIndex) == tonumber(mineshaft_target_sgid())
	then
		return ensure_mineshaft_return_door(tag or "tick_return")
	end
	if not cur or cur.SafeGridIndex ~= d().entry_sgid then
		return nil
	end
	if rule.kind == "mirror" then
		local entry = find_custom_mirror_entry()
		if entry and entry.anchor and entry.anchor.Exists and entry.anchor:Exists() then
			tick_mirror_door_state(entry)
			return entry
		end
		runtime.special_quest_door_attempted_sgid = nil
		runtime.special_quest_door_attempted_this_visit = false
		return M.ensure_special_quest_door(tag or "tick_mirror_respawn")
	end
	if rule.kind == "mineshaft" and mines_ii_custom_door_enabled() then
		local entry = find_custom_mineshaft_entry()
		if entry and entry.anchor and entry.anchor.Exists and entry.anchor:Exists() then
			tick_mineshaft_door_state(entry)
			return entry
		end
		runtime.special_quest_door_attempted_sgid = nil
		runtime.special_quest_door_attempted_this_visit = false
		return M.ensure_special_quest_door(tag or "tick_mineshaft_respawn")
	end
	return nil
end

function M.install(inject)
	deps = inject
	local cf = inject.compass_floor
	cf.resolve_special_quest_door_rule = M.resolve_special_quest_door_rule
	cf.find_special_quest_door = M.find_special_quest_door
	cf.read_special_quest_dimension = M.read_special_quest_dimension
	cf.snapshot_special_quest_door_probe = M.snapshot_special_quest_door_probe
	cf.apply_force_special_quest = M.apply_force_special_quest
	cf.ensure_entry_78_special_quest_door = M.ensure_entry_78_special_quest_door
	cf.ensure_special_quest_door = M.ensure_special_quest_door
	cf.ensure_mineshaft_return_door = M.ensure_mineshaft_return_door
	cf.force_mineshaft_collapse_playback = M.force_mineshaft_collapse_playback
	cf.special_quest_on_leave_spawn_room = M.on_leave_spawn_room
	cf.tick_mirror_door = M.tick_mirror_door
	cf.try_spawn_mirror_79_knife_piece = M.try_spawn_mirror_79_knife_piece
	cf.set_mirror_physics_observer = M.set_mirror_physics_observer
	cf.set_mineshaft_dim_observer = M.set_mineshaft_dim_observer
	cf.set_virtual_door_life_observer = M.set_virtual_door_life_observer
	cf.scan_mineshaft_dimension1 = M.scan_mineshaft_dimension1
	cf.maybe_scan_mineshaft_dimension1 = M.maybe_scan_mineshaft_dimension1
	cf.ensure_mineshaft_reward_room = M.ensure_mineshaft_reward_room
	cf.snapshot_left0_slot_context = M.snapshot_left0_slot_context
	cf.prepare_mirror_corridor = function(tag)
		return prepare_mirror_corridor(tag or "manual")
	end
	cf.snapshot_mirror_special_rooms_compare = function()
		local expected = collect_expected_mirror_special_sgids()
		local rows = {}
		for _, sgid in ipairs(expected) do
			rows[#rows + 1] = {
				sgid = sgid,
				normal = snapshot_dim_room_probe(sgid, DIM_NORMAL),
				knife = snapshot_dim_room_probe(sgid, DIM_KNIFE),
			}
		end
		return {
			expected_special_sgids = expected,
			rows = rows,
		}
	end

	local Nil_holder = require("Qing_Remaster_scripts.others.Nil_holder")
	Nil_holder.register("gc_mineshaft_door", {
		detect = function(data)
			return data.gc_mineshaft_door == true
		end,
		render = function(ent, data, spr, _player, offset)
			local planks = data.front_linked_sprite
			if not planks then
				return
			end
			-- Scenario A: same-entity POST_EFFECT_RENDER overlay in front of the door sprite.
			local base = Isaac.WorldToRenderPosition(
				ent.Position + (ent.PositionOffset or Vector.Zero)
			)
			local pos = base + (offset or Vector.Zero)
			planks.Rotation = spr and spr.Rotation or 0
			planks.Offset = spr and spr.Offset or Vector(0, 15)
			planks.Scale = spr and spr.Scale or Vector(1, 1)
			planks.Color = Color(1, 1, 1, 1, 0, 0, 0)
			planks:Render(pos, Vector.Zero, Vector.Zero)
			data.gc_mineshaft_planks_render_count = (data.gc_mineshaft_planks_render_count or 0) + 1
		end,
	})
	-- Temp Collapse FX: no WALL/FLOOR; engine advances entity Sprite (do not spr:Update here).
	Nil_holder.register(MINESHAFT_COLLAPSE_FX_MODE, {
		detect = function(data)
			return data.gc_mineshaft_collapse_fx == true
		end,
		update = function(ent, data, spr, _player)
			data.gc_mineshaft_collapse_fx_update_count = (data.gc_mineshaft_collapse_fx_update_count or 0) + 1
			-- Entity sprite clock = engine only. Manual Update caused 2x Collapse speed.
			local entry = find_custom_mineshaft_entry()
			if entry and entry.collapse_fx and GetPtrHash(entry.collapse_fx) == GetPtrHash(ent) then
				tick_mineshaft_collapse_fx(entry)
			end
		end,
		render = function(ent, data, spr, _player, offset)
			if not spr then
				return
			end
			local base = Isaac.WorldToRenderPosition(
				ent.Position + (ent.PositionOffset or Vector.Zero)
			)
			local pos = base + (offset or Vector.Zero)
			spr:Render(pos, Vector.Zero, Vector.Zero)
			data.gc_mineshaft_collapse_fx_render_count = (data.gc_mineshaft_collapse_fx_render_count or 0) + 1
		end,
	})
	return M
end

return M
