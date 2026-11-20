-- Entombed Demon: once each floor, devour the earliest valid item gained after
-- this coffin, then place that coffin's sealed devil-room items as new offers.
local enums = require("Qing_Remaster_scripts.core.enums")
local save = require("Qing_Remaster_scripts.core.savedata")
local g = require("Qing_Remaster_scripts.core.globals")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local identity = require("Qing_Remaster_scripts.items.entombed_demon.identity")
local visual = require("Qing_Remaster_scripts.items.entombed_demon.visual")
local player_visual_render = require("Qing_Remaster_scripts.callbacks.player_visual_render_holder")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Entombed_Demon,
	own_key = "Item_Entombed_Demon_",
}

local SLOT_CAP = 4
local force_seija = false
local STATE_KEY = item.own_key .. "run"
local notes = {}
local pending_start = {}

auxi.add_to_seija(item.entity)

local function seija_nerf(player)
	if force_seija then return true end
	return player and auxi.should_do_Seija(player) == true
end

local function slot_cap(player)
	return seija_nerf(player) and 1 or SLOT_CAP
end

local function spawn_slots(slots, cap)
	local out = {}
	local n = math.min(#slots, cap)
	for i = 1, n do
		out[i] = slots[i]
	end
	return out
end
local probe_events = {}

local function probe(label, detail)
	probe_events[#probe_events + 1] = string.format("F%d %s %s", Game():GetFrameCount(), label, detail or "")
	if #probe_events > 16 then table.remove(probe_events, 1) end
end

local function player_index(player)
	if not player or not player.GetData then return nil end
	local data = player:GetData()
	return data and data.__Index or nil
end

local function state_root()
	save.elses = save.elses or {}
	local root = save.elses[STATE_KEY]
	if type(root) ~= "table" then
		root = {schema = 1, players = {}}
		save.elses[STATE_KEY] = root
	end
	root.players = root.players or {}
	return root
end

local function player_state(player)
	local index = player_index(player)
	if index == nil then return nil, nil end
	local root = state_root()
	local key = tostring(index)
	local ps = root.players[key]
	if type(ps) ~= "table" then
		ps = {coffins = {}, floors = {}}
		root.players[key] = ps
	end
	ps.coffins = ps.coffins or {}
	ps.floors = ps.floors or {}
	return ps, key
end

local function note(pkey, text)
	notes[pkey or "?"] = text
end

local function record_result(row, result, room)
	row.last_result = result
	row.last_room = room
	row.last_frame = Game():GetFrameCount()
end

local function raw_floor_key()
	local level = Game():GetLevel()
	local dim = auxi.GetDimension and auxi.GetDimension() or 0
	return string.format(
		"%d:%d:%d:%d",
		level:GetStage(),
		level:GetStageType(),
		dim or 0,
		level:GetDungeonPlacementSeed()
	)
end

local function floor_key()
	local raw = raw_floor_key()
	local root = state_root()
	return root.floor_raw == raw and root.floor_current or raw
end

local function advance_floor_visit()
	local root = state_root()
	local raw = raw_floor_key()
	root.floor_visits = root.floor_visits or {}
	local previous = root.floor_visits[raw]
	if previous == nil then
		previous = 0
		-- LEGACY-SAVE-007: an earlier run recorded floor rows before floor_visits existed.
		for _, ps in pairs(root.players) do
			if ps.floors and ps.floors[raw] then previous = 1 break end
		end
	end
	local visit = previous + 1
	root.floor_visits[raw] = visit
	root.floor_raw = raw
	root.floor_current = visit == 1 and raw or raw .. "#" .. tostring(visit)
	return raw, visit
end

local function room_key()
	local level = Game():GetLevel()
	local desc = level:GetCurrentRoomDesc()
	local list = desc and desc.ListIndex or -1
	return floor_key() .. ":" .. tostring(list)
end

local function eligible(player, id)
	if not id or id <= 0 or id == item.entity then return false end
	if player:GetCollectibleNum(id, true) <= 0 then return false end
	local config = Isaac.GetItemConfig():GetCollectible(id)
	if not config or config.Hidden then return false end
	if config.Type ~= ItemType.ITEM_PASSIVE and config.Type ~= ItemType.ITEM_FAMILIAR then
		return false
	end
	local quest = ItemConfig.TAG_QUEST or (1 << 15)
	if config.HasTags and config:HasTags(quest) then return false end
	return true
end

local function history_snapshot(player)
	if not player.GetHistory then return nil end
	local history = player:GetHistory():GetCollectiblesHistory()
	if type(history) ~= "table" then return nil end
	local snapshot = {}
	for i, entry in ipairs(history) do
		snapshot[i] = {
			id = entry:GetItemID(),
			trinket = entry:IsTrinket(),
			time = entry:GetTime(),
		}
	end
	return snapshot
end

local function occurrence_at(snapshot, index)
	local row = snapshot[index]
	local count = 0
	for j = 1, index do
		local other = snapshot[j]
		if not other.trinket and other.id == row.id and other.time == row.time then
			count = count + 1
		end
	end
	return count
end

local function legacy_key(time, occurrence)
	return tostring(time) .. ":" .. tostring(occurrence)
end

local function current_rows(snapshot)
	local rows = {}
	for i, row in ipairs(snapshot) do
		rows[i] = {
			id = row.id,
			time = row.time,
			trinket = row.trinket and true or false,
			coffin = (not row.trinket) and row.id == item.entity or false,
		}
	end
	return rows
end

local function move_floor_key(ps, old_key, new_key)
	for _, floor in pairs(ps.floors or {}) do
		if type(floor) == "table" and floor[old_key] and old_key ~= new_key then
			floor[new_key] = floor[old_key]
			floor[old_key] = nil
		end
	end
end

local function migrate_legacy(ps, snapshot)
	if type(ps.stamp) == "table" then return end
	ps.coffins = ps.coffins or {}
	ps.floors = ps.floors or {}
	local seen = {}
	local at_index = {}
	local next_id = 0
	for i, row in ipairs(snapshot) do
		if not row.trinket and row.id == item.entity then
			seen[row.time] = (seen[row.time] or 0) + 1
			next_id = next_id + 1
			local id = tostring(next_id)
			local old_key = legacy_key(row.time, seen[row.time])
			if ps.coffins[old_key] then
				ps.coffins[id] = ps.coffins[old_key]
				ps.coffins[old_key] = nil
				move_floor_key(ps, old_key, id)
			end
			at_index[i] = id
		end
	end
	local stamp = {}
	for i, row in ipairs(current_rows(snapshot)) do
		stamp[i] = {
			id = row.id,
			time = row.time,
			trinket = row.trinket,
			coffin = row.coffin,
			instance = at_index[i],
		}
	end
	ps.stamp = stamp
	ps.next_instance = next_id + 1
end

local function bind_coffins(ps, snapshot)
	migrate_legacy(ps, snapshot)
	local current = current_rows(snapshot)
	local assigned = identity.align(ps.stamp, current)
	local list, stamp = {}, {}
	for i, row in ipairs(current) do
		local instance = assigned[i]
		if row.coffin and not instance then
			instance = tostring(ps.next_instance or 1)
			ps.next_instance = (ps.next_instance or 1) + 1
		end
		if row.coffin then
			list[#list + 1] = {index = i, key = instance, time = row.time}
		end
		stamp[i] = {
			id = row.id,
			time = row.time,
			trinket = row.trinket,
			coffin = row.coffin,
			instance = instance,
		}
	end
	if not identity.same_stamp(ps.stamp, stamp) then
		ps.stamp = stamp
	end
	return list
end

local function ensure_coffin(ps, key)
	local coffin = ps.coffins[key]
	if type(coffin) ~= "table" then
		coffin = {slots = {}, sacrifices = 0}
		ps.coffins[key] = coffin
	end
	coffin.slots = coffin.slots or {}
	coffin.sacrifices = math.max(0, math.floor(tonumber(coffin.sacrifices) or 0))
	return coffin
end

local function floor_row(ps, fkey, ckey)
	local floor = ps.floors[fkey]
	if type(floor) ~= "table" then
		floor = {}
		ps.floors[fkey] = floor
	end
	local row = floor[ckey]
	if type(row) ~= "table" then
		row = {phase = nil, pending = nil}
		floor[ckey] = row
	end
	row.rooms = nil
	return row
end

local function candidate_key(candidate)
	return tostring(candidate.id) .. ":" .. tostring(candidate.time) .. ":" .. tostring(candidate.occurrence)
end

local function find_next_sacrifice(player, coffin, snapshot, reserved)
	snapshot = snapshot or history_snapshot(player)
	if not snapshot or not coffin then return nil, 0 end
	local found = nil
	local future = 0
	for i = coffin.index + 1, #snapshot do
		local candidate = snapshot[i]
		if not candidate.trinket and candidate.id ~= item.entity and eligible(player, candidate.id) then
			future = future + 1
			local choice = {
				id = candidate.id,
				time = candidate.time,
				occurrence = occurrence_at(snapshot, i),
				history_index = i,
			}
			if not found and not (reserved and reserved[candidate_key(choice)]) then
				found = choice
			end
		end
	end
	return found, future
end

local function resolve_history_index(player, candidate, snapshot, relax_count)
	snapshot = snapshot or history_snapshot(player)
	if not snapshot then return nil end
	local seen = 0
	local total = 0
	for _, row in ipairs(snapshot) do
		if not row.trinket and row.id == candidate.id and row.time == candidate.time then total = total + 1 end
	end
	if not relax_count and candidate.same_count and total ~= candidate.same_count then return nil end
	for i, row in ipairs(snapshot) do
		if not row.trinket and row.id == candidate.id and row.time == candidate.time then
			seen = seen + 1
			if seen == candidate.occurrence then return i - 1 end
		end
	end
	return nil
end

local function same_count(snapshot, id, time)
	local count = 0
	for _, row in ipairs(snapshot) do
		if not row.trinket and row.id == id and row.time == time then count = count + 1 end
	end
	return count
end

local function commit_sacrifice(player, candidate, relax_count)
	local index = resolve_history_index(player, candidate, nil, relax_count)
	if index == nil then return false, "missing history" end
	local before = player:GetCollectibleNum(candidate.id, true)
	if before <= 0 then return false, "not owned" end
	player:RemoveCollectibleByHistoryIndex(index)
	if player:GetCollectibleNum(candidate.id, true) ~= before - 1 then
		return false, "remove mismatched"
	end
	return true
end

local function roll_devil(player)
	local rng = player:GetCollectibleRNG(item.entity)
	-- Pentagram replaces the null-item fallback, so an empty devil pool does not
	-- drop through the treasure pool and Breakfast.
	local id = Game():GetItemPool():GetCollectible(
		ItemPoolType.POOL_DEVIL,
		true,
		rng:GetSeed(),
		CollectibleType.COLLECTIBLE_PENTAGRAM
	)
	rng:Next()
	id = math.floor(tonumber(id) or 0)
	if id <= 0 then return nil end
	return id
end

local function blocked_position(pos, planned)
	for i = 1, #planned do
		if planned[i]:Distance(pos) < 36 then return true end
	end
	local existing = Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)
	for i = 1, #existing do
		if existing[i].Position:Distance(pos) < 36 then return true end
	end
	return false
end

local function plan_positions(count, occupied)
	if count <= 0 then return {} end
	local room = Game():GetRoom()
	if not room then return nil end
	local center = room:GetCenterPos()
	local planned = {}
	occupied = occupied or {}
	local function taken(pos)
		return blocked_position(pos, occupied) or blocked_position(pos, planned)
	end
	for i = 1, count do
		local placed = nil
		for attempt = 0, 11 do
			local alone = #occupied == 0 and attempt == 0
			local radius = (alone and count == 1) and 0 or (48 + (attempt + #occupied) * 18)
			local angle = (alone and count > 1) and (((i - 1) / count) * 360 - 90)
				or ((i + attempt * count - 1) * 47 - 90)
			local guess = center + Vector.FromAngle(angle) * radius
			local pos = room:FindFreePickupSpawnPosition(guess, 40, true)
			if pos and not taken(pos) then
				placed = pos
				break
			end
		end
		if not placed then return nil end
		planned[i] = placed
	end
	for i = 1, #planned do occupied[#occupied + 1] = planned[i] end
	return planned
end

local function positions_clear(positions)
	if not positions or #positions == 0 then return false end
	for i = 1, #positions do
		if blocked_position(positions[i], {}) then return false end
	end
	return true
end

-- NEW OFFER. A live collectible pedestal counts as spawned. Later modifiers may
-- change its subtype; that is still a successful offer, not a missed spawn.
local function spawn_offer(player, id, pos)
	local ent = Isaac.Spawn(
		EntityType.ENTITY_PICKUP,
		PickupVariant.PICKUP_COLLECTIBLE,
		id,
		pos,
		Vector.Zero,
		player
	)
	if not ent or (ent.Exists and not ent:Exists()) then return false end
	local pickup = ent.ToPickup and ent:ToPickup()
	if not pickup or pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then
		if ent.Remove then ent:Remove() end
		return false
	end
	return true
end

local function deliver(player, ids, positions)
	if #ids == 0 then return {}, nil end
	if not positions or #positions ~= #ids then
		positions = plan_positions(#ids)
	end
	if not positions then return ids, "no space" end
	local left = {}
	for i = 1, #ids do
		if not spawn_offer(player, ids[i], positions[i]) then
			for j = i, #ids do
				left[#left + 1] = ids[j]
			end
			return left, "spawn failed"
		end
	end
	return left, nil
end

local function copy_slots(slots)
	local out = {}
	for i = 1, #slots do
		out[i] = slots[i]
	end
	return out
end

local function finish_delivery(player, row, ids, positions)
	if #ids == 0 then
		row.phase = "delivered"
		row.pending = nil
		return "delivered"
	end
	local left, why = deliver(player, ids, positions)
	row.pending = left
	if #left == 0 then
		row.phase = "delivered"
		row.pending = nil
		return "delivered " .. tostring(#ids)
	end
	row.phase = "reward_pending"
	return why or "reward pending"
end

local function live_job(player, job, relax_count)
	if not player or not player.GetHistory or room_key() ~= job.physical_room then
		return nil, nil, nil, "room/history unavailable"
	end
	local ps = player_state(player)
	local snapshot = history_snapshot(player)
	if not ps or not snapshot then return nil, nil, nil, "player/history unavailable" end
	local found
	for _, coffin in ipairs(bind_coffins(ps, snapshot)) do
		if coffin.key == job.coffin_key then found = coffin break end
	end
	if not found then return nil, nil, nil, "coffin instance vanished" end
	if not relax_count and same_count(snapshot, item.entity, found.time) ~= job.coffin_same_count then
		return nil, nil, nil, "coffin occurrence changed"
	end
	local target_index = resolve_history_index(player, job.target, snapshot, relax_count)
	if target_index == nil then return nil, nil, nil, "target history occurrence vanished" end
	if not eligible(player, job.target.id) then return nil, nil, nil, "target no longer eligible" end
	job.coffin_time = found.time
	job.coffin_hud_occurrence = occurrence_at(snapshot, found.index)
	job.target.hud_occurrence = job.target.occurrence
	return ps, found, snapshot
end

function item.commit_ritual(player, job)
	local ps, coffin, _, why = live_job(player, job, true)
	if not ps then return false, why end
	local row = floor_row(ps, job.floor_key, job.coffin_key)
	if row.phase == "delivered" or row.phase == "reward_pending" then return false, "already committed" end
	local saved = ensure_coffin(ps, job.coffin_key)
	if #saved.slots ~= job.slots_before then return false, "sealed slots changed" end
	local cap = slot_cap(player)
	local output = math.min(cap, #saved.slots + 1)
	local positions = job.positions
	if not positions or #positions ~= output or not positions_clear(positions) then
		row.phase = "await_space"
		record_result(row, "commit failed: landing space changed", job.room_key)
		return false, "no space"
	end
	local rolled
	if #saved.slots < cap then
		rolled = roll_devil(player)
		if not rolled then
			row.phase = "roll_failed"
			record_result(row, "commit failed: devil roll", job.room_key)
			return false, "roll failed"
		end
	end
	local removed, why = commit_sacrifice(player, job.target, true)
	if not removed then
		record_result(row, "commit failed: sacrifice " .. tostring(why), job.room_key)
		return false, "sacrifice failed: " .. tostring(why)
	end
	saved.sacrifices = saved.sacrifices + 1
	if rolled then saved.slots[#saved.slots + 1] = rolled end
	local result = finish_delivery(player, row, spawn_slots(saved.slots, cap), positions)
	record_result(row, "committed: " .. result, job.room_key)
	return true, job.coffin_key .. " sacrificed " .. tostring(job.target.id) .. " " .. result
end

local function process_coffin(player, ps, coffin, fkey, rkey, debug, snapshot, reserved, occupied)
	local row = floor_row(ps, fkey, coffin.key)
	if row.phase == "delivered" or row.phase == "skipped" then
		return coffin.key .. " " .. row.phase, false
	end
	local saved = ensure_coffin(ps, coffin.key)
	if row.phase == "reward_pending" then
		local result = finish_delivery(player, row, row.pending or {})
		record_result(row, "delivery retry: " .. result, rkey)
		return coffin.key .. " " .. result, false
	end
	local candidate = find_next_sacrifice(player, coffin, snapshot, reserved)
	if not candidate then
		row.phase = "await_target"
		record_result(row, "prepare failed: no eligible item after coffin", rkey)
		return coffin.key .. " no target", false
	end
	if reserved then reserved[candidate_key(candidate)] = true end
	local cap = slot_cap(player)
	local output = math.min(cap, #saved.slots + 1)
	local positions = plan_positions(output, occupied)
	if not positions then
		row.phase = "await_space"
		record_result(row, "prepare failed: no landing space", rkey)
		return coffin.key .. " no space", false
	end
	candidate.same_count = same_count(snapshot, candidate.id, candidate.time)
	-- HistoryHUD's occurrence key already matches the native history occurrence.
	candidate.hud_occurrence = candidate.occurrence
	local job = {
		coffin_key = coffin.key, coffin_id = item.entity, coffin_time = coffin.time,
		player_index = player_index(player),
		coffin_same_count = same_count(snapshot, item.entity, coffin.time),
		floor_key = fkey, room_key = rkey, physical_room = room_key(),
		target = candidate, positions = positions, slots_before = #saved.slots, debug = debug,
	}
	job.coffin_hud_occurrence = occurrence_at(snapshot, coffin.index)
	local started = visual.start(player, job, {
		valid = function(current, pending)
			local ps, _, _, reason = live_job(current, pending)
			return ps ~= nil, reason
		end,
		commit = function(current, pending)
			local ok, result = item.commit_ritual(current, pending)
			note(player_index(current) and tostring(player_index(current)), result)
			return ok
		end,
		cancel = function(reason)
			note(tostring(job.player_index), coffin.key .. " canceled: " .. tostring(reason))
			local current = state_root().players[tostring(job.player_index)]
			local floor = current and current.floors[job.floor_key]
			local latest = floor and floor[coffin.key]
			if latest and latest.phase == "ritual_pending" then
				latest.phase = reason == "room changed" and nil or "interrupted"
			end
			if latest then record_result(latest, "animation canceled: " .. tostring(reason), job.room_key) end
		end,
	})
	if started then
		row.phase = "ritual_pending"
		record_result(row, "animation queued", rkey)
	else
		record_result(row, "prepare failed: animation busy", rkey)
	end
	return coffin.key .. (started and " ritual queued" or " ritual busy"), started
end

function item.process_floor(player, opts)
	opts = opts or {}
	local ps, pkey = player_state(player)
	if not ps then return "no player index" end
	if not player.GetHistory then return "no history" end
	local snapshot = history_snapshot(player)
	if not snapshot then return "no history" end
	local fkey = opts.floor_key or floor_key()
	local rkey = opts.room_key or room_key()
	if visual.has_job(player_index(player)) then return "ritual active" end
	local parts = {}
	local reserved, occupied = {}, {}
	for _, coffin in ipairs(bind_coffins(ps, snapshot)) do
		local result = process_coffin(player, ps, coffin, fkey, rkey, opts.debug == true, snapshot, reserved, occupied)
		parts[#parts + 1] = result
	end
	local text = #parts > 0 and table.concat(parts, " | ") or "no coffin"
	note(pkey, text)
	probe("process_floor", "key=" .. fkey .. " room=" .. rkey .. " result=" .. text)
	return text
end

function item.preview(player)
	local ps = player_state(player)
	local snapshot = history_snapshot(player)
	if not ps or not snapshot then return {} end
	local rows = {}
	local reserved = {}
	local floor = ps.floors[floor_key()]
	for _, coffin in ipairs(bind_coffins(ps, snapshot)) do
		local state = floor and floor[coffin.key]
		local finished = state and (state.phase == "delivered" or state.phase == "skipped" or state.phase == "reward_pending")
		local candidate, future = find_next_sacrifice(player, coffin, snapshot, finished and nil or reserved)
		if candidate and not finished then reserved[candidate_key(candidate)] = true end
		rows[#rows + 1] = {
			key = coffin.key,
			index = coffin.index,
			next_id = candidate and candidate.id or nil,
			future = future,
		}
	end
	return rows
end

function item.debug_status(player)
	player = player or Isaac.GetPlayer(0)
	local ps, pkey = player_state(player)
	if not ps then return "not in game" end
	local cap = slot_cap(player)
	local lines = {
		"Player: P" .. tostring(pkey),
		"Floor: " .. floor_key(),
		"Seija: " .. (seija_nerf(player) and ("减益，生成上限 " .. tostring(cap)) or "关闭")
			.. (force_seija and "（强制）" or ""),
		"Due: " .. tostring(ps.ritual_due == true) .. " / queued: " .. tostring(pending_start[pkey] ~= nil),
		"Ritual: " .. visual.status(player_index(player)),
		"Smoke: " .. visual.smoke_status(),
		"Last: " .. tostring(notes[pkey] or "-"),
	}
	lines[#lines + 1] = "Raw floor: " .. raw_floor_key()
	lines[#lines + 1] = "Recent floor events:"
	for i = 1, #probe_events do lines[#lines + 1] = "  " .. probe_events[i] end
	local preview = item.preview(player)
	if #preview == 0 then
		lines[#lines + 1] = "Coffins: 0"
		return table.concat(lines, "\n")
	end
	lines[#lines + 1] = "Coffins: " .. tostring(#preview)
	for _, row in ipairs(preview) do
		local coffin = ps.coffins[row.key]
		local slots = coffin and coffin.slots or {}
		local sacrifices = coffin and coffin.sacrifices or 0
		local shown = math.min(cap, #slots)
		lines[#lines + 1] = string.format(
			"%s  history #%d  sealed %d/%d  sacrifices %d  next %s  after %d%s",
			row.key,
			row.index,
			shown,
			cap,
			sacrifices,
			tostring(row.next_id or "-"),
			row.future,
			#slots > cap and string.format("  stored %d", #slots) or ""
		)
		if #slots > 0 then
			lines[#lines + 1] = "  slots " .. table.concat(slots, ", ")
		end
		local floor = ps.floors[floor_key()]
		local state = floor and floor[row.key]
		if state then
			lines[#lines + 1] = string.format("  phase %s / result %s / room %s / frame %s",
				tostring(state.phase), tostring(state.last_result or "-"),
				tostring(state.last_room or "-"), tostring(state.last_frame or "-"))
		end
	end
	return table.concat(lines, "\n")
end

function item.debug_trigger(player)
	player = player or Isaac.GetPlayer(0)
	local ps, pkey = player_state(player)
	if not ps then return "no player index" end
	local serial = (tonumber(notes[pkey .. ":serial"]) or 0) + 1
	notes[pkey .. ":serial"] = serial
	return item.process_floor(player, {
		floor_key = "debug:" .. tostring(pkey) .. ":" .. tostring(serial),
		room_key = "debug-room:" .. tostring(serial),
		debug = true,
	})
end

function item.debug_cancel(player)
	player = player or Isaac.GetPlayer(0)
	visual.cancel(player_index(player), "debug canceled")
end

function item.debug_shift_target(player)
	player = player or Isaac.GetPlayer(0)
	visual.simulate_shift(player_index(player))
end

function item.debug_missing_target(player)
	player = player or Isaac.GetPlayer(0)
	visual.simulate_missing(player_index(player))
end

function item.debug_get_visual(key) return visual.get_config(key) end
function item.debug_set_visual(key, value) visual.set_config(key, value) end
function item.debug_force_seija() return force_seija == true end
function item.debug_set_force_seija(value) force_seija = value == true end

function item.debug_prepare(player)
	player = player or Isaac.GetPlayer(0)
	if not player then return end
	player:AddCollectible(item.entity, 0, true)
	for _, id in ipairs({1, 2, 3, 4}) do
		player:AddCollectible(id, 0, true)
	end
end

function item.debug_reset(player)
	player = player or Isaac.GetPlayer(0)
	local ps, pkey = player_state(player)
	if not ps then return end
	ps.coffins = {}
	ps.floors = {}
	ps.stamp = nil
	ps.next_instance = nil
	ps.ritual_due = nil
	pending_start[pkey] = nil
	visual.cancel(player_index(player), "debug reset")
	note(pkey, "reset")
end

table.insert(item.myToCall, {CallBack = enums.Callbacks.PRE_PRE_NEW_LEVEL,
	Function = function()
		probe("PRE_PRE_NEW_LEVEL", "raw=" .. raw_floor_key() .. " key=" .. floor_key())
	end})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_LEVEL,
	params = nil,
	Function = function()
		local raw, visit = advance_floor_visit()
		probe("PRE_NEW_LEVEL", "raw=" .. raw .. " visit=" .. visit .. " key=" .. floor_key())
		for i = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(i)
			if player and player:GetCollectibleNum(item.entity, true) > 0 then
				local ps = player_state(player)
				if ps then ps.ritual_due = true end
			end
		end
	end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_NEW_LEVEL,
	Function = function()
		probe("MC_POST_NEW_LEVEL", "raw=" .. raw_floor_key() .. " key=" .. floor_key())
	end})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		probe("MC_POST_NEW_ROOM", "raw=" .. raw_floor_key() .. " key=" .. floor_key() .. " room=" .. room_key())
		for i = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(i)
			local had_ritual = player and visual.has_job(player_index(player))
			if player then visual.cancel(player_index(player), "room changed") end
			if player and player:GetCollectibleNum(item.entity, true) > 0 then
				local ps, pkey = player_state(player)
				local fkey = floor_key()
				local floor = ps and ps.floors and ps.floors[fkey]
				local retry = had_ritual == true
				if type(floor) == "table" then
					for _, row in pairs(floor) do
						if type(row) == "table" and (row.phase == "await_space" or row.phase == "await_target" or row.phase == "reward_pending" or row.phase == "roll_failed" or row.phase == "ritual_pending" or row.phase == "interrupted") then
							retry = true
							break
						end
					end
				end
				if ps and ps.ritual_due then retry = true end
				if retry and pkey then
					pending_start[pkey] = {floor = fkey, room = room_key(), frame = Game():GetFrameCount() + 2}
					note(pkey, "floor ritual scheduled after room update")
					probe("schedule", "player=" .. pkey .. " due=" .. tostring(ps.ritual_due) .. " key=" .. fkey)
				end
			end
		end
	end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_UPDATE,
	Function = function()
		for i = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(i)
			if player and player:GetCollectibleNum(item.entity, true) > 0 then
				local ps, pkey = player_state(player)
				if ps and pkey then
					local fkey, rkey = floor_key(), room_key()
					if ps.last_floor_seen ~= fkey then
						probe("floor_seen_change", "player=" .. pkey .. " old=" .. tostring(ps.last_floor_seen) .. " new=" .. fkey)
						ps.last_floor_seen = fkey
					end
					if ps.ritual_due and not pending_start[pkey] then
						pending_start[pkey] = {floor = fkey, room = rkey, frame = Game():GetFrameCount() + 2}
						probe("schedule_due", "player=" .. pkey .. " key=" .. fkey)
					end
					local pending = pending_start[pkey]
					if pending and Game():GetFrameCount() >= pending.frame then
						pending_start[pkey] = nil
						if pending.floor == fkey and pending.room == rkey then
							ps.ritual_due = nil
							probe("execute", "player=" .. pkey .. " key=" .. fkey)
							item.process_floor(player, {floor_key = fkey, room_key = rkey})
						else
							probe("drop_stale", "player=" .. pkey .. " planned=" .. pending.floor .. " current=" .. fkey)
						end
					end
				end
			end
		end
	end})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE,
	Function = function(_, player) visual.update(player) end})
table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_HUD_RENDER,
	Function = function() visual.render() end})

player_visual_render.register({
	id = "entombed_demon",
	behind = {
		active = function(player)
			return visual.wants_behind(player) == true
		end,
		render = function(ctx)
			if g.is_gameplay_world_active and g.is_gameplay_world_active() then
				visual.render_behind(ctx.player)
			end
		end,
	},
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	Function = function(_, continued)
		visual.reset()
		pending_start = {}
		probe_events = {}
		probe("MC_POST_GAME_STARTED", "continue=" .. tostring(continued) .. " raw=" .. raw_floor_key())
	end})
table.insert(item.myToCall, {CallBack = enums.Callbacks.POST_REWIND,
	Function = function()
		visual.reset()
		pending_start = {}
		probe("POST_REWIND", "key=" .. floor_key())
	end})

return item
