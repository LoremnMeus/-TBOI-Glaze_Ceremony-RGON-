-- Plan trigger / terminal / route on an existing Mines floor (no Floraine placement).

local defs = require("Qing_Remaster_scripts.threads.stone.stone_defs")
local runtime = require("Qing_Remaster_scripts.threads.stone.stone_runtime")
local route = require("Qing_Remaster_scripts.threads.stone.stone_route")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local gate = require("Qing_Remaster_scripts.story.story_runtime_gate")

local layout = {}

local function room_ok_for_event(desc)
	if not desc or not desc.Data then return false end
	if desc.SafeGridIndex < 0 then return false end
	if desc.Data.Type ~= RoomType.ROOM_DEFAULT then return false end
	if defs.BANISH_ROOM[desc.Data.Type] then return false end
	if desc.Data.Shape ~= RoomShape.ROOMSHAPE_1x1 then return false end
	return true
end

local function count_doors(desc)
	local doors = desc.Data.Doors or 0
	local n = 0
	for slot = 0, 7 do
		if (doors & (1 << slot)) ~= 0 then
			n = n + 1
		end
	end
	return n
end

local function neighbors(sgi)
	local level = Game():GetLevel()
	local desc = level:GetRoomByIdx(sgi)
	local out = {}
	if not desc or not desc.Data then return out end
	local move_info = auxi.get_moves_in_gridroom(desc.Data.Shape)
	for slot, step in pairs(move_info) do
		if auxi.is_safe_move_in_grids(sgi, step) then
			local tdesc = level:GetRoomByIdx(sgi + step)
			if tdesc and tdesc.Data and not defs.BANISH_TRAVERSE[tdesc.Data.Type] then
				out[#out + 1] = {
					sgi = tdesc.SafeGridIndex,
					slot = slot,
				}
			end
		end
	end
	return out
end

local function bfs_distances(origin)
	local dist = { [origin] = 0 }
	local parent = {}
	local parent_slot = {}
	local q = { origin }
	local qi = 1
	while qi <= #q do
		local cur = q[qi]
		qi = qi + 1
		for _, edge in ipairs(neighbors(cur)) do
			if dist[edge.sgi] == nil then
				dist[edge.sgi] = dist[cur] + 1
				parent[edge.sgi] = cur
				parent_slot[edge.sgi] = edge.slot
				q[#q + 1] = edge.sgi
			end
		end
	end
	return dist, parent, parent_slot
end

local function rebuild_path(origin, terminal, parent)
	local path = { terminal }
	local cur = terminal
	while cur ~= origin do
		cur = parent[cur]
		if cur == nil then return nil end
		table.insert(path, 1, cur)
	end
	return path
end

local function find_empty_gate_slot(sgi)
	local level = Game():GetLevel()
	local desc = level:GetRoomByIdx(sgi)
	if not desc or not desc.Data then return nil end
	local doors = desc.Data.Doors or 0
	local move_info = auxi.get_moves_in_gridroom(desc.Data.Shape)
	local candidates = {}
	for slot = 0, 7 do
		if (doors & (1 << slot)) ~= 0 then
			local step = move_info[slot]
			local empty = true
			if step and auxi.is_safe_move_in_grids(sgi, step) then
				local tdesc = level:GetRoomByIdx(sgi + step)
				if tdesc and tdesc.Data then
					empty = false
				end
			end
			if empty then
				candidates[#candidates + 1] = slot
			end
		end
	end
	if #candidates > 0 then
		return candidates[1]
	end
	-- No fallback onto connected Mines doors — that would overwrite a real exit.
	return nil
end

--- True when every Entry at a spawn is a plain replaceable enemy (not prop/pickup/effect).
local function entry_is_replaceable_enemy(entry)
	if not entry then return false end
	local t = entry.Type
	if t == nil then return false end
	if t < 10 then return false end
	if t >= 1000 then return false end
	-- Fixtures / non-combat props that must not be replaced.
	if t == EntityType.ENTITY_FIREPLACE then return false end
	if t == EntityType.ENTITY_SHOPKEEPER then return false end
	if t == 42 or t == 44 or t == 201 or t == 202 or t == 203
		or t == 218 or t == 235 or t == 236 or t == 302 then
		return false
	end
	return true
end

local function spawn_entries_list(spawn)
	local out = {}
	local n = tonumber(spawn.EntryCount) or 0
	if n <= 0 then return out end
	local entries = spawn.Entries
	if entries and entries.Get then
		local size = tonumber(entries.Size) or n
		for i = 0, size - 1 do
			local e = entries:Get(i)
			if e then out[#out + 1] = e end
		end
	end
	if #out == 0 then
		-- Fallback: sample PickEntry across the weight range (all must agree).
		for i = 0, n - 1 do
			local e = spawn:PickEntry((i + 0.5) / n)
			if e then out[#out + 1] = e end
		end
	end
	return out
end

local CARDINAL_OFFSETS = {
	{dx = 0, dy = -1},
	{dx = 0, dy = 1},
	{dx = -1, dy = 0},
	{dx = 1, dy = 0},
}

local function cell_key(x, y)
	return tostring(x) .. "," .. tostring(y)
end

--- Classify one RoomConfig spawn's entry list: empty / replaceable enemy / blocked.
local function classify_spawn_entries(list)
	if not list or #list < 1 then
		return "empty", nil, nil
	end
	local first = list[1]
	for _, e in ipairs(list) do
		if not entry_is_replaceable_enemy(e) then
			return "blocked", "center_non_enemy", nil
		end
		if e.Type ~= first.Type or e.Variant ~= first.Variant
			or (e.Subtype or 0) ~= (first.Subtype or 0) then
			return "blocked", "center_entry_mismatch", nil
		end
	end
	return "enemy", nil, {
		type = first.Type,
		variant = first.Variant or 0,
		subtype = first.Subtype or 0,
	}
end

--- Giant Pawn planning probe (RoomConfig):
--- - Center cell empty, or exactly one replaceable enemy (single replace).
--- - At least one N/S/E/W neighbor cell free of spawns.
--- Diagonals are ignored; they do not reject a candidate.
function layout.assess_origin_center(desc)
	local cfg = desc and desc.Data
	if not cfg then
		return {
			ok_clear = false,
			ok_replace = false,
			why = "missing_room_config",
			center_spawns = 0,
			free_cardinal = false,
		}
	end
	local spawns = cfg.Spawns
	if not spawns then
		return {
			ok_clear = false,
			ok_replace = false,
			why = "missing_room_config",
			center_spawns = 0,
			free_cardinal = false,
		}
	end
	local width = tonumber(cfg.Width) or 13
	local height = tonumber(cfg.Height) or 7
	local cx = math.floor(width / 2)
	local cy = math.floor(height / 2)
	local n = tonumber(cfg.SpawnCount)
	if n == nil and spawns.Size ~= nil then
		n = spawns.Size
	end
	n = n or 0

	-- Only center + cardinals matter. kind: enemy | blocked
	local cells = {}
	local function mark_cell(sx, sy, kind, why, enemy, spawn)
		local k = cell_key(sx, sy)
		local cur = cells[k]
		if not cur then
			cells[k] = {
				kind = kind,
				why = why,
				enemy = enemy,
				spawn = spawn,
				count = kind == "enemy" and 1 or 0,
			}
			return
		end
		if cur.kind == "blocked" or kind == "blocked" then
			cur.kind = "blocked"
			cur.why = cur.why or why or "center_blocked"
			cur.enemy = nil
			return
		end
		-- Two enemy spawns on the same cell → unsafe replace.
		cur.kind = "blocked"
		cur.why = "center_multi_enemy"
		cur.enemy = nil
		cur.count = (cur.count or 0) + 1
	end

	for i = 0, n - 1 do
		local spawn = spawns:Get(i)
		if spawn and spawn.X ~= nil and spawn.Y ~= nil then
			local sx = spawn.X + 1
			local sy = spawn.Y + 1
			local dx = sx - cx
			local dy = sy - cy
			local on_center = dx == 0 and dy == 0
			local on_cardinal = (math.abs(dx) + math.abs(dy)) == 1
			if on_center or on_cardinal then
				local list = spawn_entries_list(spawn)
				local kind, why, enemy = classify_spawn_entries(list)
				if kind ~= "empty" then
					mark_cell(sx, sy, kind, why, enemy and {
						x = spawn.X,
						y = spawn.Y,
						grid_x = sx,
						grid_y = sy,
						type = enemy.type,
						variant = enemy.variant,
						subtype = enemy.subtype,
					} or nil, spawn)
				end
			end
		end
	end

	local center = cells[cell_key(cx, cy)]
	local center_spawns = 0
	local ok_clear = false
	local ok_replace = false
	local replace = nil
	local why = nil

	if not center then
		ok_clear = true
		why = "center_clear"
		center_spawns = 0
	elseif center.kind == "blocked" then
		why = center.why or "center_blocked"
		center_spawns = center.count or 1
	elseif center.kind == "enemy" and center.enemy then
		ok_replace = true
		replace = center.enemy
		why = "center_single_enemy"
		center_spawns = 1
	else
		why = "center_blocked"
		center_spawns = center.count or 1
	end

	local free_cardinal = false
	local free_dirs = {}
	for _, off in ipairs(CARDINAL_OFFSETS) do
		local k = cell_key(cx + off.dx, cy + off.dy)
		if not cells[k] then
			free_cardinal = true
			free_dirs[#free_dirs + 1] = {dx = off.dx, dy = off.dy}
		end
	end

	if (ok_clear or ok_replace) and not free_cardinal then
		ok_clear = false
		ok_replace = false
		replace = nil
		why = "no_free_cardinal"
	end

	return {
		ok_clear = ok_clear,
		ok_replace = ok_replace,
		why = why or "center_blocked",
		center_spawns = center_spawns,
		replace = replace,
		free_cardinal = free_cardinal,
		free_dirs = free_dirs,
		cx = cx,
		cy = cy,
	}
end

--- Planning-time placeable: empty center or single replaceable center enemy, plus a free cardinal.
function layout.origin_room_config_clear(desc)
	local a = layout.assess_origin_center(desc)
	if a.ok_clear or a.ok_replace then
		return true, a.why or "center_ok", a.center_spawns or 0
	end
	return false, a.why or "center_occupied", a.center_spawns or 0
end

local function collect_candidates(start_sgi, boss_sgi)
	local level = Game():GetLevel()
	local rooms = level:GetRooms()
	local list = {}
	local dist_start = select(1, bfs_distances(start_sgi))
	local dist_boss = boss_sgi and select(1, bfs_distances(boss_sgi)) or {}
	for i = 0, rooms.Size - 1 do
		local desc = rooms:Get(i)
		if room_ok_for_event(desc) then
			local sgi = desc.SafeGridIndex
			if sgi ~= start_sgi then
				local d_start = dist_start[sgi]
				local d_boss = dist_boss[sgi]
				local doors = count_doors(desc)
				if d_start and d_start >= 2 and doors >= 2 then
					if d_boss == nil or d_boss >= 2 then
						list[#list + 1] = {
							sgi = sgi,
							doors = doors,
							d_start = d_start,
							d_boss = d_boss or 99,
						}
					end
				end
			end
		end
	end
	table.sort(list, function(a, b)
		if a.doors ~= b.doors then return a.doors < b.doors end
		if a.d_start ~= b.d_start then return a.d_start < b.d_start end
		return a.sgi < b.sgi
	end)
	return list
end

local function collect_origin_pool(candidates)
	local level = Game():GetLevel()
	local clear_pool = {}
	local clear_two_door = {}
	local replace_pool = {}
	local replace_two_door = {}
	for _, c in ipairs(candidates) do
		local desc = level:GetRoomByIdx(c.sgi)
		local assess = layout.assess_origin_center(desc)
		c.center_clear = assess.ok_clear == true
		c.center_replace = assess.ok_replace == true
		c.center_why = assess.why
		c.center_spawns = assess.center_spawns or 0
		c.replace_enemy = assess.replace
		c.room_variant = desc and desc.Data and desc.Data.Variant
		if assess.ok_clear then
			clear_pool[#clear_pool + 1] = c
			if c.doors == 2 then
				clear_two_door[#clear_two_door + 1] = c
			end
		elseif assess.ok_replace then
			replace_pool[#replace_pool + 1] = c
			if c.doors == 2 then
				replace_two_door[#replace_two_door + 1] = c
			end
		end
	end
	if #clear_two_door > 0 then
		return clear_two_door, "center_clear_two_door"
	end
	if #clear_pool > 0 then
		return clear_pool, "center_clear"
	end
	if #replace_two_door > 0 then
		return replace_two_door, "center_replace_two_door"
	end
	if #replace_pool > 0 then
		return replace_pool, "center_replace_enemy"
	end
	return {}, "no_center_clear_origin"
end

local function collect_terminals_for_trigger(trigger_sgi, candidates, dist, accept_dist2)
	local terminals = {}
	local function try_add(c, d)
		if not d then return end
		local gate_slot = find_empty_gate_slot(c.sgi)
		if gate_slot == nil then return end
		terminals[#terminals + 1] = {
			sgi = c.sgi,
			dist = d,
			gate_slot = gate_slot,
		}
	end
	for _, c in ipairs(candidates) do
		if c.sgi ~= trigger_sgi then
			local d = dist[c.sgi]
			if d and d >= defs.ROUTE_DIST_MIN and d <= defs.ROUTE_DIST_MAX then
				try_add(c, d)
			end
		end
	end
	if #terminals < 1 and accept_dist2 then
		for _, c in ipairs(candidates) do
			if c.sgi ~= trigger_sgi then
				local d = dist[c.sgi]
				if d == 2 then
					try_add(c, d)
				end
			end
		end
	end
	return terminals
end

local function pick_pair(rng)
	local level = Game():GetLevel()
	local start_sgi = level:GetStartingRoomIndex()
	local boss_sgi = nil
	local rooms = level:GetRooms()
	for i = 0, rooms.Size - 1 do
		local desc = rooms:Get(i)
		if desc and desc.Data and desc.Data.Type == RoomType.ROOM_BOSS and desc.SafeGridIndex >= 0 then
			boss_sgi = desc.SafeGridIndex
			break
		end
	end
	local candidates = collect_candidates(start_sgi, boss_sgi)
	if #candidates < 2 then
		return nil, "no_origin_candidate"
	end

	-- Origin/trigger only: center placeable + ≥1 free cardinal. Mid-route rooms stay unfiltered.
	local pool, pool_why = collect_origin_pool(candidates)
	if #pool < 1 then
		return nil, pool_why or "no_center_clear_origin"
	end

	local saw_path_without_gate = false
	local tries = math.min(24, #pool * 3)
	for _ = 1, tries do
		local trigger = pool[(rng:RandomInt(#pool)) + 1]
		local dist, parent = bfs_distances(trigger.sgi)
		local terminals = collect_terminals_for_trigger(trigger.sgi, candidates, dist, true)
		if #terminals < 1 then
			-- Distances may exist but every candidate lacks an empty gate slot.
			for _, c in ipairs(candidates) do
				if c.sgi ~= trigger.sgi then
					local d = dist[c.sgi]
					if d and d >= 2 and d <= defs.ROUTE_DIST_MAX then
						saw_path_without_gate = true
						break
					end
				end
			end
		else
			local term = terminals[(rng:RandomInt(#terminals)) + 1]
			local path = rebuild_path(trigger.sgi, term.sgi, parent)
			if path and #path >= 2 then
				return {
					trigger_sgi = trigger.sgi,
					terminal_sgi = term.sgi,
					gate_slot = term.gate_slot,
					path = path,
					replace_enemy = trigger.replace_enemy,
					center_why = trigger.center_why,
				}, nil
			end
		end
	end
	if saw_path_without_gate then
		return nil, "no_terminal_gate_slot"
	end
	return nil, "no_terminal_gate_slot"
end

local function door_bit_open(desc, slot)
	if not desc or not desc.Data or slot == nil then
		return false
	end
	local doors = desc.Data.Doors or 0
	return (doors & (1 << slot)) ~= 0
end

local function is_return_blocked_room(desc)
	if not desc or not desc.Data then
		return true
	end
	if defs.BANISH_TRAVERSE[desc.Data.Type] then
		return true
	end
	if defs.BANISH_ROOM[desc.Data.Type] then
		return true
	end
	if defs.is_ante_variant and defs.is_ante_variant(desc.Data.Variant) then
		return true
	end
	if defs.is_floraine_variant and defs.is_floraine_variant(desc.Data.Variant) then
		return true
	end
	return false
end

--- Passable neighbors for return-route BFS: door bit open on both sides + not special rooms.
local function return_neighbors(sgi)
	local level = Game():GetLevel()
	local desc = level:GetRoomByIdx(sgi)
	local out = {}
	if not desc or not desc.Data then
		return out
	end
	local move_info = auxi.get_moves_in_gridroom(desc.Data.Shape)
	for slot, step in pairs(move_info) do
		if door_bit_open(desc, slot) and auxi.is_safe_move_in_grids(sgi, step) then
			local tdesc = level:GetRoomByIdx(sgi + step)
			if tdesc and tdesc.Data and not is_return_blocked_room(tdesc) then
				local back = route.slot_between(tdesc.SafeGridIndex, sgi)
				if back ~= nil and door_bit_open(tdesc, back) then
					out[#out + 1] = {
						sgi = tdesc.SafeGridIndex,
						slot = slot,
						back_slot = back,
					}
				end
			end
		end
	end
	return out
end

--- Multi-source BFS from main-route rooms → off-route return table.
--- Seeds terminal-first so equal-distance joins prefer later route nodes (not the origin).
function layout.build_offroute_returns(path)
	path = path or {}
	local offroute = {}
	if #path < 1 then
		return offroute
	end
	local route_set = {}
	local route_order = {}
	for i, sgi in ipairs(path) do
		route_set[sgi] = true
		route_order[sgi] = i
	end

	local dist = {}
	local q = {}
	for i = #path, 1, -1 do
		local sgi = path[i]
		dist[sgi] = 0
		q[#q + 1] = sgi
	end

	local qi = 1
	while qi <= #q do
		local cur = q[qi]
		qi = qi + 1
		local join = route_set[cur] and cur or nil
		if not join then
			local cur_info = offroute[tostring(cur)]
			join = cur_info and cur_info.join_route_sgi
		end
		for _, edge in ipairs(return_neighbors(cur)) do
			local nxt = edge.sgi
			if dist[nxt] ~= nil then
				-- already reached (prefer first visit = terminal-seeded expansion)
			elseif route_set[nxt] then
				-- main-route rooms are pre-seeded
			else
				local back = edge.back_slot or route.slot_between(nxt, cur)
				if back ~= nil and join ~= nil then
					dist[nxt] = (dist[cur] or 0) + 1
					offroute[tostring(nxt)] = {
						return_next_sgi = cur,
						return_slot = back,
						distance_to_route = dist[nxt],
						join_route_sgi = join,
						join_route_order = route_order[join],
					}
					q[#q + 1] = nxt
				end
			end
		end
	end
	return offroute
end

--- Rebuild return table from saved main path (Continue / legacy saves missing offroute_rooms).
function layout.ensure_offroute_returns(opts)
	opts = opts or {}
	local r = runtime.get()
	if not r.route or type(r.route.path) ~= "table" or #(r.route.path) < 1 then
		return false, "no_route"
	end
	if not opts.force and type(r.route.offroute_rooms) == "table" and next(r.route.offroute_rooms) ~= nil then
		return true, "exists"
	end
	r.route.offroute_rooms = layout.build_offroute_returns(r.route.path)
	local n = 0
	for _ in pairs(r.route.offroute_rooms) do
		n = n + 1
	end
	return true, "built", n
end

local function apply_plan(plan)
	local r = runtime.get()
	local level = Game():GetLevel()
	local slot_steps = {}
	for i, sgi in ipairs(plan.path) do
		local incoming, outgoing
		if plan.path[i - 1] then
			incoming = route.slot_between(sgi, plan.path[i - 1])
		end
		if plan.path[i + 1] then
			outgoing = route.slot_between(sgi, plan.path[i + 1])
		end
		slot_steps[i] = { incoming = incoming, outgoing = outgoing }
	end
	r.floor = {
		stage = level:GetStage(),
		stage_type = level:GetStageType(),
		dimension = 0,
		seed = level:GetDungeonPlacementSeed(),
	}
	r.trigger = {
		safe_grid_index = plan.trigger_sgi,
		center_why = plan.center_why,
	}
	if plan.replace_enemy then
		r.trigger.replace_enemy = {
			x = plan.replace_enemy.x,
			y = plan.replace_enemy.y,
			grid_x = plan.replace_enemy.grid_x,
			grid_y = plan.replace_enemy.grid_y,
			type = plan.replace_enemy.type,
			variant = plan.replace_enemy.variant,
			subtype = plan.replace_enemy.subtype,
			done = false,
		}
	end
	r.terminal = {
		safe_grid_index = plan.terminal_sgi,
		gate_slot = plan.gate_slot,
	}
	r.route = {
		path = plan.path,
		rooms = route.build_rooms_table(plan.path, slot_steps),
		offroute_rooms = layout.build_offroute_returns(plan.path),
	}
	r.layout_fail = nil
	r.board = { activated = false }
	r.gate = { unlocked = false, reveal_pending = false, ante_boss_opened = false }
	r.hidden = nil
	r.attempts.missed = false
	if level:GetStage() == LevelStage.STAGE2_1 then
		r.attempts.mines1_success = true
	end
	runtime.set_phase(defs.PHASE.LAYOUT_READY, {force = true, reason = "layout_ready"})
	return true
end

function layout.try_plan_current_floor(opts)
	opts = opts or {}
	if not opts.force then
		if not gate.is_material_event_enabled("chapter1.stone") and not opts.ignore_gate then
			return false, "gate_off"
		end
		local ok, why = runtime.should_try_layout()
		if not ok then
			return false, why
		end
	end

	local level = Game():GetLevel()
	runtime.mark_attempt(level:GetStage())

	local rng = Game():GetPlayer(0):GetCollectibleRNG(CollectibleType.COLLECTIBLE_DADS_KEY)
	local plan, err = pick_pair(rng)
	if not plan then
		local r = runtime.get()
		r.layout_fail = err or "unknown"
		-- Mines II exhausted → unavailable. Same-floor retries are blocked by attempts flags.
		if level:GetStage() == LevelStage.STAGE2_2 or (r.attempts.mines1 and r.attempts.mines2) then
			runtime.set_phase(defs.PHASE.UNAVAILABLE, {force = true, reason = "layout_fail"})
		else
			runtime.set_phase(defs.PHASE.DORMANT, {force = true, reason = "layout_fail"})
		end
		return false, err
	end
	apply_plan(plan)
	return true, plan
end

function layout.ensure_for_current_floor(opts)
	if runtime.has_layout() and runtime.floor_matches() then
		layout.ensure_offroute_returns()
		return true, "exists"
	end
	return layout.try_plan_current_floor(opts)
end

--- Debug / Advanced status: planning + live clearance for the current trigger candidate.
function layout.origin_candidate_status(sgi)
	local level = Game():GetLevel()
	sgi = sgi or (runtime.get().trigger and runtime.get().trigger.safe_grid_index)
	if sgi == nil then
		return {
			ok = false,
			why = "no_trigger",
			lines = {
				"Stone Origin Candidate",
				"Room SGI: (none)",
			},
		}
	end
	local desc = level:GetRoomByIdx(sgi)
	local cfg = desc and desc.Data
	local assess = layout.assess_origin_center(desc)
	local ok_cfg = assess.ok_clear == true or assess.ok_replace == true
	local why_cfg = assess.why
	local n = assess.center_spawns or 0
	local live_ok, live_why, live_detail = nil, "not_in_room", nil
	local anchor = nil
	local room = Game():GetRoom()
	local cur = level:GetCurrentRoomDesc()
	if cur and cur.SafeGridIndex == sgi then
		local rooms_mod = require("Qing_Remaster_scripts.threads.stone.stone_rooms")
		anchor = room:GetCenterPos()
		local clear, blocked = rooms_mod.probe_anchor_clearance(anchor)
		live_ok = clear
		live_why = clear and "PASS" or "FAIL"
		live_detail = blocked
	end
	local variant = cfg and cfg.Variant
	local config_name = cfg and (cfg.Name or cfg.StageID)
	local mode = assess.ok_clear and "clear" or (assess.ok_replace and "replace" or "reject")
	local lines = {
		"Stone Origin Candidate",
		"Room SGI: " .. tostring(sgi),
		"Room Variant: " .. tostring(variant or "-"),
		"Room Config: " .. tostring(config_name or "-"),
		"Center Spawns: " .. tostring(n),
		"Plan Mode: " .. mode .. " (" .. tostring(why_cfg) .. ")",
		"Free Cardinal: " .. tostring(assess.free_cardinal == true),
		"Center Clearance: " .. (ok_cfg and "PASS" or ("FAIL (" .. tostring(why_cfg) .. ")")),
	}
	if live_ok ~= nil then
		local detail = ""
		if not live_ok and type(live_detail) == "table" and #live_detail > 0 then
			local first = live_detail[1]
			detail = " (" .. tostring(first.why or first.door or first.coll or "blocked") .. ")"
		end
		lines[#lines + 1] = "Live Grid Clearance: " .. tostring(live_why) .. detail
	end
	if anchor then
		lines[#lines + 1] = string.format("Anchor: (%.0f, %.0f)", anchor.X, anchor.Y)
	else
		local r = runtime.get()
		if r.trigger and r.trigger.anchor then
			lines[#lines + 1] = string.format(
				"Anchor: (%.0f, %.0f) %s",
				r.trigger.anchor.x,
				r.trigger.anchor.y,
				tostring(r.trigger.anchor_reason or "")
			)
		else
			lines[#lines + 1] = "Anchor: (planned; enter room to probe)"
		end
	end
	return {
		ok = ok_cfg == true,
		why = why_cfg,
		center_spawns = n,
		free_cardinal = assess.free_cardinal,
		live_ok = live_ok,
		lines = lines,
	}
end

return layout
