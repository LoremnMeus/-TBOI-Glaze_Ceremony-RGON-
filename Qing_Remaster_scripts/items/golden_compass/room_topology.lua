-- Golden Compass: door descriptor links + topology normalize.
-- No own MC_* callbacks.

local M = {}

local runtime
local push_event
local ENTRY_ROOM_SGID
local EXTRA_DOOR_LINKS_BASE
local ROOM_72_SGID
local CORRIDOR_LEFT
local CORRIDOR_RIGHT
local CORRIDOR_ROW
local OPPOSITE_DOOR_SLOT
local DOOR_NORMALIZE_FOCUS
local FORCE_PLACE_DOOR_LINKS
local grid_index
local read_desc_doors_array
local resolve_special_quest_door_rule
local should_reserve_mirror_left0_allowed
local should_reserve_mineshaft_up0_allowed

local function set_desc_door_slot(desc, slot, target_grid)
	if not desc then
		return false, "no_desc"
	end
	local ok, err = pcall(function()
		desc.Doors[slot] = target_grid
	end)
	if not ok then
		return false, tostring(err)
	end
	local readback = nil
	pcall(function()
		readback = desc.Doors[slot]
	end)
	if readback ~= target_grid then
		return false, "readback_" .. tostring(readback)
	end
	return true, nil
end

local function or_allowed_door(desc, slot)
	if not desc then
		return false, "no_desc"
	end
	local ok, err = pcall(function()
		local cur = desc.AllowedDoors or 0
		desc.AllowedDoors = cur | (1 << slot)
	end)
	return ok == true, ok and nil or tostring(err)
end

--- Write mutual Doors[] + AllowedDoors for one adjacency. Optional MakeDoor if current room.
--- dimension: 0/1 (default 0). Mirror corridor links must pass Dimension.KNIFE_PUZZLE.
local function link_room_pair(from_sgid, slot, to_sgid, dimension)
	dimension = tonumber(dimension)
	if dimension == nil then
		dimension = 0
	end
	local level = Game():GetLevel()
	local room = Game():GetRoom()
	local from_desc = level:GetRoomByIdx(from_sgid, dimension)
	local to_desc = level:GetRoomByIdx(to_sgid, dimension)
	local opp = OPPOSITE_DOOR_SLOT[slot]
	local row = {
		from = from_sgid,
		slot = slot,
		to = to_sgid,
		dimension = dimension,
		opposite_slot = opp,
		from_exists = from_desc ~= nil and from_desc.Data ~= nil,
		to_exists = to_desc ~= nil and to_desc.Data ~= nil,
		from_safe = from_desc and from_desc.SafeGridIndex or nil,
		to_safe = to_desc and to_desc.SafeGridIndex or nil,
	}
	if not row.from_exists or not row.to_exists or opp == nil then
		row.ok = false
		row.error = (not row.from_exists and "missing_from")
			or (not row.to_exists and "missing_to")
			or "bad_slot"
		return row
	end

	local ok_a, err_a = set_desc_door_slot(from_desc, slot, to_sgid)
	local ok_b, err_b = set_desc_door_slot(to_desc, opp, from_sgid)
	local ok_aa, err_aa = or_allowed_door(from_desc, slot)
	local ok_ba, err_ba = or_allowed_door(to_desc, opp)
	row.doors_from_ok = ok_a
	row.doors_from_err = err_a
	row.doors_to_ok = ok_b
	row.doors_to_err = err_b
	row.allowed_from_ok = ok_aa
	row.allowed_from_err = err_aa
	row.allowed_to_ok = ok_ba
	row.allowed_to_err = err_ba
	row.doors_from_after = read_desc_doors_array(from_desc)
	row.doors_to_after = read_desc_doors_array(to_desc)
	row.allowed_from_after = from_desc.AllowedDoors
	row.allowed_to_after = to_desc.AllowedDoors

	local cur = level:GetCurrentRoomDesc()
	local cur_sgid = cur and cur.SafeGridIndex
	local cur_dim = nil
	pcall(function()
		if level.GetDimension then
			cur_dim = level:GetDimension()
		end
	end)
	row.make_door = nil
	if room and room.MakeDoor
		and tonumber(cur_dim) == dimension
		and (cur_sgid == from_sgid or cur_sgid == to_sgid)
	then
		local make_slot = (cur_sgid == from_sgid) and slot or opp
		local mok, merr = pcall(function()
			room:MakeDoor(make_slot)
		end)
		row.make_door = {
			slot = make_slot,
			ok = mok == true,
			error = mok and nil or tostring(merr),
			has_door_after = room:GetDoor(make_slot) ~= nil,
		}
	end

	row.ok = ok_a and ok_b and ok_aa and ok_ba
	return row
end

local function repair_force_place_door_links(tag)
	local rows = {}
	local ok_n = 0
	for _, link in ipairs(FORCE_PLACE_DOOR_LINKS) do
		local row = link_room_pair(link.from, link.slot, link.to)
		rows[#rows + 1] = row
		if row.ok then
			ok_n = ok_n + 1
		end
	end
	local result = {
		tag = tag,
		ok_count = ok_n,
		total = #rows,
		rows = rows,
	}
	runtime.force_place_door_links = result
	push_event("force_place_door_links", result)
	return result
end

local function snapshot_focus_door_state(sgids)
	local level = Game():GetLevel()
	local out = {}
	for _, sgid in ipairs(sgids) do
		local desc = nil
		pcall(function()
			desc = level:GetRoomByIdx(sgid, 0)
		end)
		local data = desc and desc.Data
		out[#out + 1] = {
			sgid = sgid,
			owner_sgid = desc and desc.SafeGridIndex,
			list_index = desc and desc.ListIndex,
			own = desc ~= nil and desc.SafeGridIndex == sgid,
			shape = data and data.Shape,
			type = data and data.Type,
			variant = data and data.Variant,
			allowed_doors = desc and desc.AllowedDoors,
			doors = read_desc_doors_array(desc),
			visited = desc and desc.VisitedCount,
			display_flags = desc and desc.DisplayFlags,
		}
	end
	return out
end

--- Collect unique own rooms (ListIndex dedupe) with SafeGridIndex >= 0.
local function collect_own_room_descs()
	local level = Game():GetLevel()
	local rooms = level:GetRooms()
	local by_list = {}
	local ordered = {}
	local size = rooms and rooms.Size or 0
	for i = 0, size - 1 do
		local desc = rooms:Get(i)
		if desc and desc.Data and desc.SafeGridIndex and desc.SafeGridIndex >= 0 then
			local li = desc.ListIndex
			if li ~= nil and not by_list[li] then
				by_list[li] = desc
				ordered[#ordered + 1] = desc
			elseif li == nil then
				ordered[#ordered + 1] = desc
			end
		end
	end
	return ordered
end

local function clear_desc_all_door_slots(desc)
	local writes = {}
	for slot = 0, 7 do
		local ok, err = set_desc_door_slot(desc, slot, -1)
		writes[#writes + 1] = {slot = slot, ok = ok, error = err}
	end
	local allowed_ok, allowed_err = pcall(function()
		desc.AllowedDoors = 0
	end)
	return writes, allowed_ok == true, allowed_ok and nil or tostring(allowed_err)
end

local function set_allowed_doors_exact(desc, mask)
	local ok, err = pcall(function()
		desc.AllowedDoors = mask
	end)
	return ok == true, ok and nil or tostring(err)
end

--- Side-branch door links for normalize. Includes 85→72 only when curse@72 is active.
--- Also appends Luna/Fragmented north-mirror secret links from pending.north_mirror_links.
local function get_extra_door_links(pending)
	local links = {}
	for _, link in ipairs(EXTRA_DOOR_LINKS_BASE) do
		links[#links + 1] = link
	end
	local want72 = (pending and pending.curse_72_wanted == true)
		or (runtime.curse_72_plan and runtime.curse_72_plan.wanted == true)
		or (runtime.curse_72_place and runtime.curse_72_place.ok == true)
	if want72 then
		links[#links + 1] = {from = 85, slot = DoorSlot.UP0, to = ROOM_72_SGID}
	end
	local north = pending and pending.north_mirror_links
	if type(north) ~= "table" and runtime and runtime.pending then
		north = runtime.pending.north_mirror_links
	end
	if type(north) == "table" then
		for _, link in ipairs(north) do
			links[#links + 1] = link
		end
	end
	return links
end

--- Build undirected adjacency edges for final 1x1 map: corridor chain + side links.
local function build_canonical_door_edges(own_by_sgid, pending)
	local edges = {}
	local seen = {}
	local function add_edge(from_sgid, slot, to_sgid)
		if not own_by_sgid[from_sgid] or not own_by_sgid[to_sgid] then
			return false, "missing_endpoint"
		end
		local opp = OPPOSITE_DOOR_SLOT[slot]
		if opp == nil then
			return false, "bad_slot"
		end
		local key = string.format("%d:%d:%d", math.min(from_sgid, to_sgid), math.max(from_sgid, to_sgid), math.min(slot, opp))
		if seen[key] then
			return false, "dup"
		end
		seen[key] = true
		edges[#edges + 1] = {from = from_sgid, slot = slot, to = to_sgid, opposite = opp}
		return true, nil
	end

	for col = CORRIDOR_LEFT, CORRIDOR_RIGHT - 1 do
		local a = grid_index(col, CORRIDOR_ROW)
		local b = grid_index(col + 1, CORRIDOR_ROW)
		add_edge(a, DoorSlot.RIGHT0, b)
	end
	local skipped = {}
	for _, link in ipairs(get_extra_door_links(pending)) do
		local ok, reason = add_edge(link.from, link.slot, link.to)
		if not ok and reason ~= "dup" then
			skipped[#skipped + 1] = {
				from = link.from,
				slot = link.slot,
				to = link.to,
				reason = reason,
			}
		end
	end
	return edges, skipped
end

--- After TryPlace + PlaceRoom: wipe Shape4/5 residue Doors[0..7], rewrite from final adjacency.
--- AllowedDoors is set to the connected slot mask only (not OR onto old bits).
local function normalize_door_topology(tag)
	local own_list = collect_own_room_descs()
	local own_by_sgid = {}
	for _, desc in ipairs(own_list) do
		own_by_sgid[desc.SafeGridIndex] = desc
	end
	local before = snapshot_focus_door_state(DOOR_NORMALIZE_FOCUS)
	local clear_rows = {}
	for _, desc in ipairs(own_list) do
		local writes, allowed_ok, allowed_err = clear_desc_all_door_slots(desc)
		clear_rows[#clear_rows + 1] = {
			sgid = desc.SafeGridIndex,
			list_index = desc.ListIndex,
			shape = desc.Data and desc.Data.Shape,
			clear_ok = allowed_ok,
			allowed_err = allowed_err,
			slot_writes = writes,
		}
	end

	local edges, skipped = build_canonical_door_edges(own_by_sgid, runtime.pending)
	local link_rows = {}
	local allowed_by_sgid = {}
	local ok_n = 0
	for _, edge in ipairs(edges) do
		local from_desc = own_by_sgid[edge.from]
		local to_desc = own_by_sgid[edge.to]
		local ok_a, err_a = set_desc_door_slot(from_desc, edge.slot, edge.to)
		local ok_b, err_b = set_desc_door_slot(to_desc, edge.opposite, edge.from)
		allowed_by_sgid[edge.from] = (allowed_by_sgid[edge.from] or 0) | (1 << edge.slot)
		allowed_by_sgid[edge.to] = (allowed_by_sgid[edge.to] or 0) | (1 << edge.opposite)
		local row = {
			from = edge.from,
			slot = edge.slot,
			to = edge.to,
			opposite = edge.opposite,
			doors_from_ok = ok_a,
			doors_from_err = err_a,
			doors_to_ok = ok_b,
			doors_to_err = err_b,
			ok = ok_a and ok_b,
		}
		link_rows[#link_rows + 1] = row
		if row.ok then
			ok_n = ok_n + 1
		end
	end

	-- Entry@78: reserve Mirror LEFT0 / Mineshaft UP0 AllowedDoors bit (no Doors[] forge).
	-- Water II 25603 / Mines II 25604: skip force-reserve when layout door exists=False.
	local sq_slot_note = nil
	local sq_rule = resolve_special_quest_door_rule and resolve_special_quest_door_rule() or nil
	if sq_rule and sq_rule.eligible == true and sq_rule.preferred_slot ~= nil then
		local reserve = true
		local pending = runtime and runtime.pending
		local live_variant = nil
		pcall(function()
			local plan = pending and pending.corridor_plan and pending.corridor_plan[ENTRY_ROOM_SGID]
			live_variant = plan and plan.variant
		end)
		if sq_rule.kind == "mirror" and should_reserve_mirror_left0_allowed then
			reserve = should_reserve_mirror_left0_allowed(
				pending and pending.restore_stage,
				pending and pending.restore_stage_type,
				live_variant
			) == true
		elseif sq_rule.kind == "mineshaft" and should_reserve_mineshaft_up0_allowed then
			reserve = should_reserve_mineshaft_up0_allowed(
				pending and pending.restore_stage,
				pending and pending.restore_stage_type,
				live_variant
			) == true
		end
		if reserve then
			local prev = allowed_by_sgid[ENTRY_ROOM_SGID] or 0
			allowed_by_sgid[ENTRY_ROOM_SGID] = prev | (1 << sq_rule.preferred_slot)
			sq_slot_note = {
				sgid = ENTRY_ROOM_SGID,
				kind = sq_rule.kind,
				preferred_slot = sq_rule.preferred_slot,
				allowed_doors = allowed_by_sgid[ENTRY_ROOM_SGID],
				reserved = true,
			}
		else
			sq_slot_note = {
				sgid = ENTRY_ROOM_SGID,
				kind = sq_rule.kind,
				preferred_slot = sq_rule.preferred_slot,
				allowed_doors = allowed_by_sgid[ENTRY_ROOM_SGID] or 0,
				reserved = false,
				note = (sq_rule.kind == "mineshaft")
					and "skip_mineshaft_up0_allowed_mines_ii_25604"
					or "skip_mirror_left0_allowed_water_ii_25603",
			}
		end
	end

	local allowed_rows = {}
	for sgid, desc in pairs(own_by_sgid) do
		local mask = allowed_by_sgid[sgid] or 0
		local ok, err = set_allowed_doors_exact(desc, mask)
		allowed_rows[#allowed_rows + 1] = {
			sgid = sgid,
			allowed_doors = mask,
			ok = ok,
			error = err,
		}
	end
	table.sort(allowed_rows, function(a, b)
		return (a.sgid or 0) < (b.sgid or 0)
	end)

	local after = snapshot_focus_door_state(DOOR_NORMALIZE_FOCUS)
	local result = {
		tag = tag,
		own_room_count = #own_list,
		cleared = #clear_rows,
		edge_count = #edges,
		link_ok = ok_n,
		skipped_links = skipped,
		clear_rows = clear_rows,
		link_rows = link_rows,
		allowed_rows = allowed_rows,
		special_quest_allowed = sq_slot_note,
		before_focus = before,
		after_focus = after,
		note = "Doors[0..7] rebuilt; AllowedDoors exact from connections; Shape4/5 residue dropped",
	}
	runtime.door_topology_normalize = result
	-- Keep legacy field for UI/report consumers that still key off door_links.
	runtime.force_place_door_links = {
		tag = tag,
		ok_count = ok_n,
		total = #edges,
		via = "normalize_door_topology",
		rows = link_rows,
	}
	push_event("door_topology_normalize", result)
	return result
end

function M.install(inject)
	runtime = inject.runtime
	push_event = inject.push_event
	ENTRY_ROOM_SGID = inject.entry_sgid
	EXTRA_DOOR_LINKS_BASE = inject.extra_door_links_base
	ROOM_72_SGID = inject.room_72_sgid
	CORRIDOR_LEFT = inject.corridor_left
	CORRIDOR_RIGHT = inject.corridor_right
	CORRIDOR_ROW = inject.corridor_row
	OPPOSITE_DOOR_SLOT = inject.opposite_door_slot
	DOOR_NORMALIZE_FOCUS = inject.door_normalize_focus
	FORCE_PLACE_DOOR_LINKS = inject.force_place_door_links
	grid_index = inject.grid_index
	read_desc_doors_array = inject.read_desc_doors_array
	resolve_special_quest_door_rule = inject.resolve_special_quest_door_rule
	should_reserve_mirror_left0_allowed = inject.should_reserve_mirror_left0_allowed
	should_reserve_mineshaft_up0_allowed = inject.should_reserve_mineshaft_up0_allowed
	return {
		normalize_door_topology = normalize_door_topology,
		set_desc_door_slot = set_desc_door_slot,
		or_allowed_door = or_allowed_door,
		link_room_pair = link_room_pair,
		repair_force_place_door_links = repair_force_place_door_links,
		get_extra_door_links = get_extra_door_links,
		build_canonical_door_edges = build_canonical_door_edges,
		collect_own_room_descs = collect_own_room_descs,
		clear_desc_all_door_slots = clear_desc_all_door_slots,
		set_allowed_doors_exact = set_allowed_doors_exact,
	}
end

return M
