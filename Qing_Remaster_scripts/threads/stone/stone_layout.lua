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

	local pool = {}
	for _, c in ipairs(candidates) do
		if c.doors == 2 then
			pool[#pool + 1] = c
		end
	end
	if #pool < 1 then
		pool = candidates
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
				}, nil
			end
		end
	end
	if saw_path_without_gate then
		return nil, "no_terminal_gate_slot"
	end
	return nil, "no_terminal_gate_slot"
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
	}
	r.terminal = {
		safe_grid_index = plan.terminal_sgi,
		gate_slot = plan.gate_slot,
	}
	r.route = {
		path = plan.path,
		rooms = route.build_rooms_table(plan.path, slot_steps),
	}
	r.layout_fail = nil
	r.board = { activated = false }
	r.gate = { unlocked = false, reveal_pending = false }
	r.hidden = nil
	if level:GetStage() == LevelStage.STAGE2_1 then
		r.attempts.mines1_success = true
	end
	runtime.set_phase(defs.PHASE.LAYOUT_READY)
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
		-- Mines II exhausted → unavailable.
		if level:GetStage() == LevelStage.STAGE2_2 or (r.attempts.mines1 and r.attempts.mines2) then
			runtime.set_phase(defs.PHASE.UNAVAILABLE)
		else
			runtime.set_phase(defs.PHASE.DORMANT)
		end
		return false, err
	end
	apply_plan(plan)
	return true, plan
end

function layout.ensure_for_current_floor(opts)
	if runtime.has_layout() and runtime.floor_matches() then
		return true, "exists"
	end
	return layout.try_plan_current_floor(opts)
end

return layout
