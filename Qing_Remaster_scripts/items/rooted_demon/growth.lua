-- Rooted Demon phase two. Only numbers and plain tables belong in saved state;
-- world positions and attack flashes are rebuilt for the current room.
local growth = {}
local flashes = {}
local global_attacks = {}
local node_cooldowns = {}
local debug_runs = {}
local structure_cache = {}
local node_cache = {}
local burst_target_positions = {}
local profile_enabled = false
local profile_stats = {}
local profile_latest = {}
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local history_visual = require("Qing_Remaster_scripts.items.rooted_demon.visual")
local brush
local ROOT_APPEAR_FRAMES = 12
local EXTEND_FRAMES = 24
local WRAP_FRAMES = 10
local WAVE_FRAMES = 30
local HUNT_FRAMES = 40
local FLASH_APPEAR_FRAMES = 3
local FLASH_PROBE_FRAMES = 3
local FLASH_AIM_FRAMES = 11
local FLASH_STRIKE_FRAMES = 3
local FLASH_HOLD_FRAMES = 5
local FLASH_RETRACT_FRAMES = 7
local PROBE_END = FLASH_APPEAR_FRAMES + FLASH_PROBE_FRAMES
local AIM_END = PROBE_END + FLASH_AIM_FRAMES
local STRIKE_END = AIM_END + FLASH_STRIKE_FRAMES
local HOLD_END = STRIKE_END + FLASH_HOLD_FRAMES
local FLASH_END = HOLD_END + FLASH_RETRACT_FRAMES
local NODE_RANGE = 65
local NODE_COOLDOWN = 60
local ATTACK_GAP = 8
local BURST_MAX_BRANCHES = 17
local BURST_FULL_NODES = 41
local BURST_GROWTH_EXPONENT = 0.72
local BURST_EARLY_BRANCHES = {2, 3, 4, 4, 5}
local STRIKE_HIT_RADIUS = 22
local STRIKE_KNOCKBACK = 4
local hud_nodes

local function profile_time()
	if not profile_enabled then return nil end
	return os and os.clock and os.clock() * 1000 or Isaac.GetTime()
end

local function profile_record(name, start)
	if not start then return end
	local elapsed = profile_time() - start
	local row = profile_stats[name] or {calls = 0, total_ms = 0, max_ms = 0}
	row.calls, row.total_ms = row.calls + 1, row.total_ms + elapsed
	row.max_ms = math.max(row.max_ms, elapsed)
	profile_stats[name] = row
end

function growth.set_profile_enabled(value)
	profile_enabled = value == true
	profile_stats = {}
	profile_latest = {}
end

function growth.profile_snapshot()
	local result = {}
	for name, row in pairs(profile_stats) do
		result[name] = {calls = row.calls, total_ms = row.total_ms, max_ms = row.max_ms}
	end
	return result
end

function growth.profile_metrics()
	local result = {}
	for key, value in pairs(profile_latest) do result[key] = value end
	return result
end

local function alive(ent)
	local npc = ent:ToNPC()
	return npc and npc:IsActiveEnemy(false) and npc:IsVulnerableEnemy()
		and not npc:IsDead() and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
end

local function visible_enemy(ent)
	if not alive(ent) then return false end
	local point, screen = Isaac.WorldToScreen(ent.Position), ui.GetScreenSize()
	local margin = math.max(12, Isaac.WorldToScreenDistance(Vector(ent.Size, 0)):Length())
	return point.X >= -margin and point.Y >= -margin
		and point.X <= screen.X + margin and point.Y <= screen.Y + margin
end

local function bounds()
	local room = Game():GetRoom()
	local a, b = room:GetTopLeftPos(), room:GetBottomRightPos()
	return a + Vector(28, 28), b - Vector(28, 28)
end

local function root_brush()
	if not brush then brush = history_visual.make_root_brush() end
	return brush
end

local function visible_history_nodes(player, layout, members)
	local hud = Game():GetHUD()
	local history_hud = hud and hud:GetHistoryHUD()
	if not layout or not hud or not hud:IsVisible() or not history_hud
		or (history_hud.IsVisible and not history_hud:IsVisible())
		or (Options.ExtraHUDStyle or 0) <= 0 then return {}, {} end
	local roots = {}
	for _, member in ipairs(members or {}) do
		roots[tostring(growth.item_id) .. ":" .. member.key] = member
	end
	local rows, visible_roots = {}, {}
	local screen = ui.GetScreenSize()
	for _, row in ipairs(layout.rows or {}) do
		local pos = row.pos or layout.positions[row.key]
		if row.kind == "collectible" and pos and layout.visible[row.key]
			and pos.X >= 0 and pos.X <= screen.X and pos.Y >= 0 and pos.Y <= screen.Y then
			local id = row.id
			if id == growth.item_id then
				if roots[row.key] then
					rows[#rows + 1] = {id = id, key = row.key, pos = pos, root = true}
					visible_roots[row.key] = true
				end
			elseif player:GetCollectibleNum(id, true) > 0 then
				local config = Isaac.GetItemConfig():GetCollectible(id)
				local quest = ItemConfig.TAG_QUEST or (1 << 15)
				if config and not config.Hidden and not config:HasTags(quest)
					and (config.Type == ItemType.ITEM_PASSIVE or config.Type == ItemType.ITEM_FAMILIAR) then
					rows[#rows + 1] = {id = id, key = row.key, pos = pos}
				end
			end
		end
	end
	return rows, visible_roots
end

local function nearest(origin, radius)
	local chosen, distance
	for _, ent in ipairs(Isaac.FindInRadius(origin, radius, EntityPartition.ENEMY)) do
		if visible_enemy(ent) then
			local d = ent.Position:Distance(origin)
			if not distance or d < distance then chosen, distance = ent, d end
		end
	end
	return chosen
end

local function least_targeted(origin, radius, owner, excluded)
	local chosen, best_count, best_distance
	for _, ent in ipairs(Isaac.FindInRadius(origin, radius, EntityPartition.ENEMY)) do
		if visible_enemy(ent) then
			local identity, count = GetPtrHash(ent), 0
			for _, flash in ipairs(flashes) do
				if flash ~= excluded and flash.owner == owner and flash.target
					and flash.target:Exists() and GetPtrHash(flash.target) == identity then
					count = count + 1
				end
			end
			local distance = ent.Position:Distance(origin)
			if not best_count or count < best_count
				or (count == best_count and distance < best_distance) then
				chosen, best_count, best_distance = ent, count, distance
			end
		end
	end
	return chosen
end

local function strike(player, origin, target, multiplier, screen_origin, initial_direction, debug_only, owner)
	local target_position = target and target.Position or burst_target_positions[owner]
	if not target_position then return end
	local delta = target_position - origin
	if delta:Length() < 1 then return end
	local direction = initial_direction and initial_direction:Length() > 0
		and initial_direction:Normalized() or delta:Normalized()
	flashes[#flashes + 1] = {a = screen_origin or auxi.world_to_ui_screen(origin),
		world_a = origin, target = target, world_target = target_position,
		direction = direction,
		player = player, multiplier = multiplier, debug_only = debug_only, owner = owner,
		hit = {}, impacts = {}, age = 0}
end

local function burst_path(nodes)
	local top_node = nodes[1].pos
	for i = 2, #nodes do
		if nodes[i].pos.Y < top_node.Y then top_node = nodes[i].pos end
	end
	local screen = ui.GetScreenSize()
	return {top_node, Vector(top_node.X, 8), Vector(8, 8),
		Vector(8, screen.Y - 8), Vector(screen.X - 8, screen.Y - 8),
		Vector(screen.X - 8, 8)}
end

local function border_point(path, fraction)
	local lengths, total = {}, 0
	for i = 1, #path - 1 do
		lengths[i] = path[i]:Distance(path[i + 1])
		total = total + lengths[i]
	end
	local remaining = math.max(0, math.min(1, fraction)) * total
	for i, length in ipairs(lengths) do
		if remaining <= length then
			return path[i] + (path[i + 1] - path[i]) * (remaining / length),
				(path[i + 1] - path[i]):Normalized()
		end
		remaining = remaining - length
	end
	return path[#path]
end

local function world_direction(screen_origin, screen_tangent)
	local delta = auxi.ui_screen_to_world(screen_origin + screen_tangent * 24)
		- auxi.ui_screen_to_world(screen_origin)
	return delta:Length() > 0 and delta:Normalized() or Vector(0, -1)
end

local function path_length(path)
	local length = 0
	for i = 1, #path - 1 do length = length + path[i]:Distance(path[i + 1]) end
	return length
end

local function burst_length(nodes)
	local path = burst_path(nodes)
	local to_top = path[1]:Distance(path[2])
	local fraction = math.min(1, math.max(0, (#nodes - 1) / (BURST_FULL_NODES - 1)))
	return to_top + (path_length(path) - to_top) * fraction^BURST_GROWTH_EXPONENT
end

local function burst_branch_count(nodes)
	local count = #nodes
	if count <= #BURST_EARLY_BRANCHES then
		return BURST_EARLY_BRANCHES[math.max(1, count)]
	end
	local later = (count - #BURST_EARLY_BRANCHES)
		/ (BURST_FULL_NODES - #BURST_EARLY_BRANCHES)
	local extra = math.floor(math.min(1, later)
		* (BURST_MAX_BRANCHES - BURST_EARLY_BRANCHES[#BURST_EARLY_BRANCHES]) + 0.5)
	return BURST_EARLY_BRANCHES[#BURST_EARLY_BRANCHES] + extra
end

local function hunt_key(player, state)
	return tostring(player:GetData().__Index) .. ":rooted_demon_growth"
end

local function has_enemy()
	for _, ent in ipairs(Isaac.GetRoomEntities()) do
		if visible_enemy(ent) then return ent end
	end
	return false
end

local function attack_ready(player)
	local index = player:GetData().__Index
	if index == nil then return false end
	local frame = Game():GetFrameCount()
	if frame - (global_attacks[index] or -ATTACK_GAP) < ATTACK_GAP then return false end
	global_attacks[index] = frame
	return true
end

function growth.update(player, state, history, layout, members)
	local profile_start = profile_time()
	-- LEGACY-SAVE-005: existing V1 phase-two saves need one visible replay of the new growth timeline.
	if state.visual_epoch ~= 4 then
		state.visual_epoch, state.phase, state.tick, state.progress = 4, "grow", 0, 0
	end
	state.age = (state.age or 0) + 1
	local visual_nodes, _, duration = hud_nodes(player, state, history, layout, members)
	local key = hunt_key(player, state)
	local parts = {}
	for _, node in ipairs(visual_nodes) do
		parts[#parts + 1] = table.concat({node.key, node.grid_x, node.grid_y}, ":")
	end
	local signature = table.concat(parts, "|")
	if structure_cache[key] and structure_cache[key] ~= signature then
		state.phase, state.tick, state.progress, state.covered = "grow", 0, 0, 0
		state.hunt_fired = 0
		state.growth_cycle = (state.growth_cycle or 0) + 1
		burst_target_positions[key] = nil
		for i = #flashes, 1, -1 do
			if flashes[i].owner == key then table.remove(flashes, i) end
		end
		visual_nodes, _, duration = hud_nodes(player, state, history, layout, members)
	end
	structure_cache[key] = signature
	if #visual_nodes == 0 then
		state.phase, state.tick, state.progress, state.covered = "grow", 0, 0, 0
		burst_target_positions[key] = nil
		if profile_enabled then profile_latest = {nodes = 0, phase = "grow", burst_planned = 0, burst_fired = 0} end
		profile_record("growth_update", profile_start)
		return
	end
	state.phase = state.phase or "grow"
	state.tick = (state.tick or 0) + 1
	if state.phase == "grow" then
		state.progress = 0
		for _, node in ipairs(visual_nodes) do
			if state.tick >= node.finish_frame then state.progress = state.progress + 1 end
		end
		if state.tick >= duration then state.phase, state.tick, state.progress = "ready", 0, #visual_nodes end
	elseif state.phase == "ready" then
		if #visual_nodes > (state.progress or 0) then
			state.phase, state.tick, state.progress = "grow", 0, 0
		else
			local enemy = has_enemy()
			if enemy then
				burst_target_positions[key] = enemy.Position
				state.phase, state.tick, state.hunt_fired = "burst", 0, 0
			end
		end
	elseif state.phase == "burst" then
		if state.tick >= 36 then state.phase, state.tick = "hunt", 0 end
	elseif state.phase == "hunt" then
		if state.tick >= HUNT_FRAMES then
			local active = false
			for _, flash in ipairs(flashes) do
				if flash.owner == hunt_key(player, state) then active = true break end
			end
			if not active then state.phase, state.tick = "retract", 0 end
		end
	elseif state.phase == "retract" then
		if state.tick >= 12 + #visual_nodes * 5 then
			state.phase, state.tick = "recover", 0
			state.growth_cycle = (state.growth_cycle or 0) + 1
			structure_cache[key] = nil
		end
	elseif state.phase == "recover" then
		if state.tick >= 24 then state.phase, state.tick, state.progress = "grow", 0, 0 end
	end
	if (state.phase == "burst" or state.phase == "hunt") and #visual_nodes > 0 then
		local branches = burst_branch_count(visual_nodes)
		local fired = state.hunt_fired or 0
		local length = burst_length(visual_nodes)
		local available = state.phase == "burst" and length * math.min(1, state.tick / 36) or length
		local path = burst_path(visual_nodes)
		while fired < branches do
			local branch_distance = length * ((fired + 0.5) / branches)
			if available < branch_distance then break end
			local screen_origin, tangent = border_point(path, branch_distance / path_length(path))
			local origin = auxi.ui_screen_to_world(screen_origin)
			local initial_direction = world_direction(screen_origin, tangent)
			if state.debug then
				strike(player, origin, player, 0, screen_origin, initial_direction, true,
					hunt_key(player, state))
				fired = fired + 1
			else
				local top, bottom = bounds()
				local enemy = least_targeted(origin, top:Distance(bottom) + 40,
					hunt_key(player, state))
				if enemy then burst_target_positions[key] = enemy.Position end
				if enemy or burst_target_positions[key] then
					strike(player, origin, enemy, 0.66, screen_origin, initial_direction, false,
						hunt_key(player, state))
					fired = fired + 1
				else
					break
				end
			end
		end
		state.hunt_fired = fired
	end
	state.covered = math.min(state.progress or 0, #visual_nodes)
	if not state.debug and (state.phase == "grow" or state.phase == "ready") then
		local reached = {}
		for _, node in ipairs(visual_nodes) do
			if state.phase == "ready" or state.tick >= node.finish_frame then reached[node.key] = true end
		end
		for _, node in ipairs(visual_nodes) do
			if reached[node.key] and node.pos.X >= 0 and node.pos.Y >= 0
				and node.pos.X <= ui.GetScreenSize().X and node.pos.Y <= ui.GetScreenSize().Y then
				local cooldown_key = table.concat({tostring(player:GetData().__Index),
					tostring(state.root_time), tostring(state.root_occurrence), node.key}, ":")
				if state.age - (state.last_attack or -ATTACK_GAP) >= ATTACK_GAP
					and Game():GetFrameCount() >= (node_cooldowns[cooldown_key] or 0) then
					local origin = auxi.ui_screen_to_world(node.pos)
					local enemy = nearest(origin, NODE_RANGE)
					if enemy and attack_ready(player) then
						local parent = node.source_index and visual_nodes[node.source_index]
						local tangent = parent and (node.pos - parent.pos) or Vector(0, -1)
						if tangent:Length() < 1 then tangent = Vector(0, -1) end
						strike(player, origin, enemy, 0.3, node.pos,
							world_direction(node.pos, tangent:Normalized()))
						node_cooldowns[cooldown_key] = Game():GetFrameCount() + NODE_COOLDOWN
						state.last_attack = state.age
					end
				end
			end
		end
	end
	if profile_enabled then
		local length = burst_length(visual_nodes)
		profile_latest = {nodes = #visual_nodes, phase = state.phase,
			burst_path_px = length,
			burst_planned = burst_branch_count(visual_nodes),
			burst_fired = state.hunt_fired or 0, active_spikes = #flashes}
	end
	profile_record("growth_update", profile_start)
end

local function branch_rng(player, state, nodes)
	local seed = player:GetCollectibleRNG(growth.item_id):GetSeed() & 0xffffffff
	local function mix(value)
		for i = 1, #value do
			seed = (seed ~ string.byte(value, i)) & 0xffffffff
			seed = (((seed << 5) | (seed >> 27)) + seed * 33 + 17) & 0xffffffff
		end
	end
	mix(tostring(state.root_time) .. ":" .. tostring(state.root_occurrence)
		.. ":" .. tostring(state.growth_cycle or 0))
	for _, node in ipairs(nodes) do mix(tostring(node.key)) end
	local rng = RNG()
	rng:SetSeed(seed == 0 and 1 or seed, 35)
	return rng
end

hud_nodes = function(player, state, history, layout, members)
	local profile_start = profile_time()
	local rows, visible_roots = visible_history_nodes(player, layout, members)
	if #rows == 0 or not members or #members == 0 then
		profile_record("node_filter", profile_start)
		return {}, false, 0
	end
	local signature_parts = {tostring(state.growth_cycle or 0),
		tostring(state.root_time), tostring(state.root_occurrence)}
	for _, member in ipairs(members) do
		signature_parts[#signature_parts + 1] = member.key .. ":" .. member.history_index
	end
	for _, row in ipairs(rows) do
		signature_parts[#signature_parts + 1] = table.concat({row.key,
			row.pos.X, row.pos.Y}, ":")
	end
	local signature = table.concat(signature_parts, "|")
	local cache_key = hunt_key(player, state)
	local cached = node_cache[cache_key]
	if cached and cached.signature == signature then
		profile_record("node_cache_hit", profile_start)
		return cached.nodes, cached.offscreen, cached.duration
	end
	local screen = ui.GetScreenSize()
	local grid_step = (Options.ExtraHUDStyle or 0) == 2 and 16 or 32
	local min_x, bottom_y = screen.X, 0
	local lanes = {}
	for _, node in ipairs(rows) do
		min_x, bottom_y = math.min(min_x, node.pos.X), math.max(bottom_y, node.pos.Y)
		local found = false
		for _, x in ipairs(lanes) do
			if math.abs(x - node.pos.X) < 4 then found = true break end
		end
		if not found then lanes[#lanes + 1] = node.pos.X end
	end
	table.sort(lanes)
	local lane_limit = (Options.ExtraHUDStyle or 0) == 2 and 4 or 2
	while #lanes > lane_limit do table.remove(lanes) end
	local result, candidates = {}, {}
	for _, node in ipairs(rows) do
		node.grid_x = math.floor((node.pos.X - min_x) / grid_step + 0.5)
		node.grid_y = math.floor((bottom_y - node.pos.Y) / grid_step + 0.5) + 1
		if node.root then result[#result + 1] = node
		else candidates[#candidates + 1] = node end
	end
	local virtual_lanes, virtual_count = {}, 0
	for _, member in ipairs(members) do
		local key = tostring(growth.item_id) .. ":" .. member.key
		if not visible_roots[key] then
			local lane = ((member.history_index - 1) % #lanes) + 1
			if not virtual_lanes[lane] then
				virtual_lanes[lane] = true
				virtual_count = virtual_count + 1
				local x = lanes[lane]
				result[#result + 1] = {id = growth.item_id, key = key,
					pos = Vector(x, screen.Y + 24),
					grid_x = math.floor((x - min_x) / grid_step + 0.5),
					grid_y = 0, root = true, virtual = true}
			end
		end
	end
	if #result == 0 then return {}, false, 0 end
	table.sort(candidates, function(a, b)
		if a.grid_y ~= b.grid_y then return a.grid_y < b.grid_y end
		local da, db = math.abs(a.grid_x), math.abs(b.grid_x)
		if da ~= db then return da < db end
		if a.grid_x ~= b.grid_x then return a.grid_x < b.grid_x end
		return a.key < b.key
	end)
	for _, root in ipairs(result) do
		root.depth, root.finish_frame = 0, ROOT_APPEAR_FRAMES
	end
	local duration = ROOT_APPEAR_FRAMES
	local rng = branch_rng(player, state, rows)
	local pending = candidates
	while #pending > 0 do
		local next_pending, progressed = {}, false
		for _, node in ipairs(pending) do
			local available = {}
			for j = 1, #result do
				local candidate = result[j]
				local dx = candidate.grid_x - node.grid_x
				local dy = candidate.grid_y - node.grid_y
				if (math.abs(dx) == 1 and dy == 0) or (dx == 0 and dy == -1) then
					available[#available + 1] = j
				end
			end
			if #available > 0 then
				local source = available[rng:RandomInt(#available) + 1]
				node.source_index = source
				node.depth = result[source].depth + 1
				node.start_frame = ROOT_APPEAR_FRAMES + (node.depth - 1) * WAVE_FRAMES
				node.arrive_frame = node.start_frame + EXTEND_FRAMES
				node.finish_frame = node.arrive_frame + WRAP_FRAMES
				duration = math.max(duration, node.finish_frame)
				result[#result + 1] = node
				progressed = true
			else
				next_pending[#next_pending + 1] = node
			end
		end
		if not progressed then break end
		pending = next_pending
	end
	node_cache[cache_key] = {signature = signature, nodes = result,
		offscreen = virtual_count > 0, duration = duration}
	profile_record("node_rebuild", profile_start)
	return result, virtual_count > 0, duration
end

function growth.render(player, state, history, layout, draw_icon, members)
	local profile_start = profile_time()
	local room = Game():GetRoom()
	if room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	local nodes = hud_nodes(player, state, history, layout, members)
	if #nodes == 0 then
		profile_record("growth_render", profile_start)
		return
	end
	local art = root_brush()
	local function smooth(value)
		local t = math.max(0, math.min(1, value))
		return t * t * (3 - 2 * t)
	end
	local function breathe(envelope, index)
		return envelope * (1 + 0.08 * smooth(envelope)
			* math.sin((state.age or 0) * 0.16 + index))
	end
	local max_depth = 0
	for _, node in ipairs(nodes) do max_depth = math.max(max_depth, node.depth) end
	local root_envelope = 1
	if state.phase == "grow" then
		root_envelope = smooth(state.tick / ROOT_APPEAR_FRAMES)
	elseif state.phase == "retract" then
		root_envelope = 1 - smooth((state.tick - 12 - max_depth * 5) / 5)
	elseif state.phase == "recover" then
		root_envelope = 0
	end
	local root_draw_start = profile_time()
	for i, node in ipairs(nodes) do
		if node.root then
			if root_envelope > 0 then
				if node.virtual then
					history_visual.draw_root_path(art, node.pos + Vector(0, 12), node.pos,
						root_envelope, 1, -8)
				end
				history_visual.draw_root_knot(art, node.pos, breathe(root_envelope, i))
			end
			node.icon_alpha = node.virtual and 0 or root_envelope
		else
		local extent, bubble, icon_alpha = 0, 0, 0
		if state.phase == "grow" then
			extent = smooth((state.tick - nodes[i].start_frame) / EXTEND_FRAMES)
			bubble = smooth((state.tick - nodes[i].arrive_frame) / WRAP_FRAMES)
			icon_alpha = smooth((state.tick - nodes[i].start_frame - 4) / 10)
		elseif state.phase == "retract" then
			local start = 12 + (max_depth - nodes[i].depth) * 5
			extent = 1 - smooth((state.tick - start) / 5)
			bubble = extent
			icon_alpha = extent
		elseif state.phase ~= "recover" then
			extent, bubble, icon_alpha = 1, 1, 1
		end
		if extent > 0 then
			local parent = nodes[node.source_index]
			local source, target = parent.pos, node.pos
			local sections = parent.virtual and 9 or 3
			local bend = source.X == target.X and 0 or (i % 2 == 0 and 12 or -12)
			history_visual.draw_root_path(art, source, target, extent, 1, bend, sections)
			history_visual.draw_root_path(art, source + Vector(3, 0), target + Vector(3, 0),
				math.max(0, (extent - 0.2) / 0.8), 0.55, -bend, sections)
		end
		if bubble > 0 then history_visual.draw_root_knot(art, nodes[i].pos, breathe(bubble, i)) end
		nodes[i].icon_alpha = icon_alpha
		end
	end
	profile_record("root_draw", root_draw_start)
	if state.phase == "burst" or state.phase == "hunt" or state.phase == "retract" then
		local extent = state.phase == "burst" and math.min(1, (state.tick or 0) / 36)
			or (state.phase == "hunt" and 1 or math.max(0, 1 - (state.tick or 0) / 12))
		local path = burst_path(nodes)
		local remaining = burst_length(nodes) * extent
		for i = 1, #path - 1 do
			local length = path[i]:Distance(path[i + 1])
			local portion = length > 0 and math.min(1, remaining / length) or 0
			history_visual.draw_root_path(art, path[i], path[i + 1], portion, 1.1, 0)
			remaining = remaining - length
			if remaining <= 0 then break end
		end
	end
	if draw_icon then
		local player_index = player and player.GetData and player:GetData().__Index
		for i, node in ipairs(nodes) do
			if not node.virtual and (node.icon_alpha or 0) > 0
				and layout and layout.visible[node.key] then
				local time, occurrence = tostring(node.key or ""):match("^%d+:(%-?%d+):(%-?%d+)$")
				draw_icon(node.id, node.pos, node.icon_alpha, {
					player_index = player_index,
					time = tonumber(time),
					occurrence = tonumber(occurrence),
				})
			end
		end
	end
	profile_record("growth_render", profile_start)
end

local function strike_front(frame)
	if frame <= 0 then return 0 end
	if frame == 1 then return 0.58 end
	if frame == 2 then return 0.88 end
	return 1
end

function growth.render_flashes()
	if #flashes == 0 then return end
	local profile_start = profile_time()
	local art = root_brush()
	for _, flash in ipairs(flashes) do
		local node_alpha = flash.age <= FLASH_APPEAR_FRAMES
			and flash.age / FLASH_APPEAR_FRAMES
			or (flash.age > HOLD_END and math.max(0, 1 - (flash.age - HOLD_END)
				/ FLASH_RETRACT_FRAMES) or 1)
		local node_scale = 0.9
		if flash.age <= FLASH_APPEAR_FRAMES then
			node_scale = 0.9 + 0.2 * math.sin(math.pi * flash.age / FLASH_APPEAR_FRAMES)
		elseif flash.age > PROBE_END and flash.age <= AIM_END then
			node_scale = 0.9 - 0.18 * (flash.age - PROBE_END) / FLASH_AIM_FRAMES
		end
		if flash.age > FLASH_APPEAR_FRAMES and flash.age <= AIM_END then
			local probe_length, bend, width, tip_width, tip_scale
			if flash.age <= PROBE_END then
				probe_length = 16 * (flash.age - FLASH_APPEAR_FRAMES) / FLASH_PROBE_FRAMES
				bend, width, tip_width, tip_scale = 0, 1.35, 0.43, 0.85
			else
				local charge = (flash.age - PROBE_END) / FLASH_AIM_FRAMES
				probe_length = 16 - 13 * charge
				bend = math.min(2.5, probe_length * 0.2) * charge
				width = 1.35 + 0.75 * charge
				tip_width, tip_scale = 0.43 - 0.09 * charge, 0.85 - 0.08 * charge
			end
			local probe_world = flash.world_a + flash.direction * 20
			local radial = auxi.world_to_ui_screen(probe_world) - auxi.world_to_ui_screen(flash.world_a)
			if radial:Length() > 0 then
				history_visual.draw_root_strike(art, flash.a,
					flash.a + radial:Normalized() * probe_length, 1, width,
					{bend = bend, tip_width = tip_width, tip_scale = tip_scale})
			end
		elseif flash.age > AIM_END and flash.world_b then
			local tip_extent, trunk_extent = 1, 1
			if flash.age <= STRIKE_END then
				local frame = flash.age - AIM_END
				tip_extent = strike_front(frame)
				trunk_extent = frame >= FLASH_STRIKE_FRAMES and 1
					or math.max(0, tip_extent - 0.12)
			elseif flash.age > HOLD_END then
				tip_extent = math.max(0, 1 - (flash.age - HOLD_END) / FLASH_RETRACT_FRAMES)
				trunk_extent = tip_extent
			end
			if tip_extent > 0 then
				local screen_end = flash.a + auxi.world_to_ui_screen(flash.world_b)
					- auxi.world_to_ui_screen(flash.world_a)
				if flash.age > STRIKE_END and flash.age <= HOLD_END then
					local recoil = math.sin(math.pi * (flash.age - STRIKE_END)
						/ (FLASH_HOLD_FRAMES + 1)) * 5
					local delta = screen_end - flash.a
					if delta:Length() > 0 then screen_end = screen_end - delta:Normalized() * recoil end
				end
				history_visual.draw_root_strike(art, flash.a, screen_end,
					trunk_extent, 1.8, {tip_extent = tip_extent, branches = true})
			end
		end
		for _, impact in ipairs(flash.impacts) do
			local age = flash.age - impact.age
			if age >= 0 and age <= 6 then
				local screen_pos = flash.a + auxi.world_to_ui_screen(impact.position)
					- auxi.world_to_ui_screen(flash.world_a)
				history_visual.draw_root_impact(art, screen_pos, flash.direction, 1 - age / 6)
			end
		end
		if node_alpha > 0 then
			history_visual.draw_root_junction(art, flash.a,
				node_scale * node_alpha, node_alpha)
		end
	end
	profile_record("spike_draw", profile_start)
end

function growth.advance_flashes()
	local profile_start = profile_time()
	for i = #flashes, 1, -1 do
		local flash = flashes[i]
		flash.age = flash.age + 1
		if flash.age > PROBE_END and flash.age <= AIM_END then
			local tracked = flash.target
			if not flash.debug_only and (not tracked or not tracked:Exists()
				or not visible_enemy(tracked)) then
				local top, bottom = bounds()
				tracked = flash.owner and least_targeted(flash.world_a,
					top:Distance(bottom) + 40, flash.owner, flash)
					or nearest(flash.world_a, top:Distance(bottom) + 40)
				flash.target = tracked
			end
			local target = tracked and tracked.Position or flash.world_target
			if target then
				flash.world_target = target
				local delta = target - flash.world_a
				if delta:Length() > 0 then
					local angle, wanted = flash.direction:GetAngleDegrees(), delta:GetAngleDegrees()
					local turn = (wanted - angle + 540) % 360 - 180
					local radians = math.rad(angle + turn * 0.28)
					flash.direction = Vector(math.cos(radians), math.sin(radians))
					if flash.age == AIM_END then flash.direction = delta:Normalized() end
				end
			end
		end
		if flash.age == AIM_END + 1 then
			local distance = flash.world_a:Distance(flash.world_target)
			local screen_per_100_world = Isaac.WorldToScreenDistance(flash.direction * 100):Length()
			local minimum = ui.GetScreenSize().X * 100 / (3 * screen_per_100_world)
			local length = math.max(minimum, distance + 90)
			flash.world_b = flash.world_a + flash.direction * length
		end
		if not flash.debug_only and flash.world_b and flash.age > AIM_END
			and flash.age <= STRIKE_END then
			local delta = flash.world_b - flash.world_a
			local previous = strike_front(flash.age - AIM_END - 1)
			local current = strike_front(flash.age - AIM_END)
			local start_pos = flash.world_a + delta * previous
			local end_pos = flash.world_a + delta * current
			local segment = end_pos - start_pos
			for _, ent in ipairs(Isaac.GetRoomEntities()) do
				if visible_enemy(ent) then
					local key = GetPtrHash(ent)
					if not flash.hit[key] then
						local along = segment:LengthSquared() > 0
							and math.max(0, math.min(1, (ent.Position - start_pos):Dot(segment)
								/ segment:LengthSquared())) or 0
						local closest = start_pos + segment * along
						if ent.Position:Distance(closest) <= ent.Size + STRIKE_HIT_RADIUS then
							flash.hit[key] = true
							local hit_pos = ent.Position
							local push = hit_pos - closest
							if push:Length() < 1 then push = flash.direction end
							if ent:TakeDamage(flash.player.Damage * flash.multiplier, 0,
								EntityRef(flash.player), 0) then
								flash.impacts[#flash.impacts + 1] = {position = hit_pos, age = flash.age}
								ent:AddVelocity(push:Normalized() * STRIKE_KNOCKBACK)
							end
						end
					end
				end
			end
		end
		if flash.age >= FLASH_END then
			table.remove(flashes, i)
		end
	end
	profile_record("spike_update", profile_start)
end

function growth.debug_burst(player, state, history, layout, members)
	if not player or not state then return false end
	local nodes = hud_nodes(player, state, history, layout, members)
	if #nodes == 0 then return false end
	local key = hunt_key(player, state)
	debug_runs[key] = {root_time = state.root_time, root_occurrence = state.root_occurrence,
		player_index = player:GetData().__Index,
		visual_epoch = 4, phase = "burst", tick = 0, progress = #nodes,
		covered = #nodes, hunt_fired = 0, age = state.age or 0, debug = true}
	return true
end

function growth.debug_active(player, state)
	return debug_runs[hunt_key(player, state)] ~= nil
end

function growth.update_debug(player, history, layout, members)
	for key, state in pairs(debug_runs) do
		if state.player_index == player:GetData().__Index then
			growth.update(player, state, history, layout, members)
			if state.phase == "recover" then debug_runs[key] = nil end
		end
	end
end

function growth.render_debug(player, history, layout, draw_icon, members)
	for _, state in pairs(debug_runs) do
		if state.player_index == player:GetData().__Index then
			growth.render(player, state, history, layout, draw_icon, members)
		end
	end
end

function growth.clear_visuals()
	flashes, global_attacks, node_cooldowns, debug_runs, structure_cache, node_cache,
		burst_target_positions = {}, {}, {}, {}, {}, {}, {}
end

return growth
