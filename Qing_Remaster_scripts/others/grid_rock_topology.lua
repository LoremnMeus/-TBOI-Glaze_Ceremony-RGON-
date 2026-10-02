-- Grid Rock Topology: big-rock frame / neighbor disconnect / rock replace.
-- Behavior reference (study only, no runtime dependency):
--   CuerLib Grids.DisconnectBigRocks
--   Reverie PebblePiles:SetPebblePiles (SetBigRockFrame(-1) then Disconnect)
--
-- GridEntityRock visual state is not only Type/Variant/Sprite anim.
-- BigRockFrame is an independent topology field; mutating rocks without
-- detach + disconnect leaves orphaned "big" half-sprites.

local RockTopology = {}

RockTopology.ROCK_TYPES = {
	[GridEntityType.GRID_ROCK] = true,
	[GridEntityType.GRID_ROCK_ALT] = true,
	[GridEntityType.GRID_ROCK_ALT2] = true,
	[GridEntityType.GRID_ROCK_BOMB] = true,
	[GridEntityType.GRID_ROCK_GOLD] = true,
	[GridEntityType.GRID_ROCK_SPIKED] = true,
	[GridEntityType.GRID_ROCK_SS] = true,
	[GridEntityType.GRID_ROCKT] = true,
}

-- BigRockFrame identity (not neighbor-of-center naming).
-- 0/1/2/3 = single-axis extension; 4..7 = corner / 2x2 corner roles.
RockTopology.BIG_FRAME = {
	RIGHT = 0,
	LEFT = 1,
	UP = 2,
	DOWN = 3,
	RIGHT_DOWN = 4,
	LEFT_DOWN = 5,
	RIGHT_UP = 6,
	LEFT_UP = 7,
}

-- Partner offsets relative to the rock that owns the frame.
local BIG_FRAME_PARTNERS = {
	[0] = {{1, 0}},
	[1] = {{-1, 0}},
	[2] = {{0, -1}},
	[3] = {{0, 1}},
	[4] = {{1, 0}, {0, 1}},
	[5] = {{-1, 0}, {0, 1}},
	[6] = {{1, 0}, {0, -1}},
	[7] = {{-1, 0}, {0, -1}},
}

-- Optional debug listener: fn(phase, payload)
-- Phases: before_detach, after_detach, after_mutate,
--         after_topology_sync, after_visual, after_validate
RockTopology.debug_listener = nil

function RockTopology.set_debug_listener(fn)
	if fn == nil or type(fn) == "function" then
		RockTopology.debug_listener = fn
		return true
	end
	return false
end

local function emit(phase, payload)
	local listener = RockTopology.debug_listener
	if listener then
		listener(phase, payload)
	end
end

function RockTopology.is_rock_type(tp)
	return tp ~= nil and RockTopology.ROCK_TYPES[tp] == true
end

function RockTopology.is_rock(grid)
	return grid ~= nil and RockTopology.is_rock_type(grid:GetType())
end

function RockTopology.get_anim_name(sprite)
	if not sprite then return nil end
	return sprite:GetAnimation()
end

function RockTopology.sprite_is_big(sprite)
	if not sprite then return false end
	if sprite:IsPlaying("big") == true then
		return true
	end
	local anim = sprite:GetAnimation()
	return anim ~= nil and string.lower(tostring(anim)) == "big"
end

function RockTopology.is_big(grid)
	if not grid then return false end
	local frame = RockTopology.get_big_frame(grid)
	if frame ~= nil and frame >= 0 then
		return true
	end
	return RockTopology.sprite_is_big(grid:GetSprite())
end

function RockTopology.get_big_frame(grid)
	local rock = grid and grid:ToRock()
	if not rock or not rock.GetBigRockFrame then
		return nil
	end
	return rock:GetBigRockFrame()
end

function RockTopology.set_big_frame(grid, frame)
	local rock = grid and grid:ToRock()
	if not rock or not rock.SetBigRockFrame then
		return false
	end
	rock:SetBigRockFrame(frame)
	return true
end

function RockTopology.snapshot(room, index)
	room = room or Game():GetRoom()
	local grid = room:GetGridEntity(index)
	local sprite = grid and grid:GetSprite()
	local anim = RockTopology.get_anim_name(sprite)
	local sprite_frame = sprite and sprite:GetFrame() or nil
	local filename = nil
	if sprite and sprite.GetFilename then
		local ok, name = pcall(function() return sprite:GetFilename() end)
		if ok then filename = name end
	end
	local big_frame = RockTopology.get_big_frame(grid)
	local row = {
		index = index,
		grid_index = index,
		type = grid and grid:GetType() or nil,
		variant = grid and grid:GetVariant() or nil,
		state = grid and grid.State or nil,
		collision = grid and grid.CollisionClass or nil,
		big_frame = big_frame,
		anim = anim,
		sprite_frame = sprite_frame,
		filename = filename,
		is_big = RockTopology.sprite_is_big(sprite)
			or (big_frame ~= nil and big_frame >= 0),
		frame_count = Game():GetFrameCount(),
	}
	if grid then
		local pos = grid.Position
		row.x = pos and pos.X or nil
		row.y = pos and pos.Y or nil
	end
	return row
end

function RockTopology.snapshot_neighborhood(room, indices, radius)
	room = room or Game():GetRoom()
	radius = radius or 1
	local width = room:GetGridWidth()
	local size = room:GetGridSize()
	local set = {}
	local list = {}
	local function mark(idx)
		if idx == nil or set[idx] then return end
		if idx < 0 or idx >= size then return end
		set[idx] = true
		list[#list + 1] = idx
	end
	for _, index in ipairs(indices or {}) do
		local col = index % width
		local row = math.floor(index / width)
		for dy = -radius, radius do
			for dx = -radius, radius do
				local r = row + dy
				local c = col + dx
				if r >= 0 and c >= 0 and c < width then
					mark(r * width + c)
				end
			end
		end
	end
	table.sort(list)
	local rows = {}
	for _, idx in ipairs(list) do
		rows[#rows + 1] = RockTopology.snapshot(room, idx)
	end
	return rows, list, set
end

local function mark_changed(changed_list, changed_set, idx)
	if idx == nil or changed_set[idx] then return end
	changed_set[idx] = true
	changed_list[#changed_list + 1] = idx
end

local function apply_big_frame_change(adj_rock, adj_index, new_frame, changed_list, changed_set)
	local old_frame = adj_rock:GetBigRockFrame()
	if old_frame == new_frame then
		return false
	end
	adj_rock:SetBigRockFrame(new_frame)
	mark_changed(changed_list, changed_set, adj_index)
	return true
end

--- Faithful port of CuerLib Grids.DisconnectBigRocks(index).
--- Clears / degrades neighboring rocks whose BigRockFrame still references `index`.
--- Returns list of indices whose BigRockFrame actually changed.
function RockTopology.disconnect_big_rocks(room, index)
	room = room or Game():GetRoom()
	local width = room:GetGridWidth()
	local height = room:GetGridHeight()
	local center_x = index % width
	local center_y = math.floor(index / width)
	local changed_list = {}
	local changed_set = {}

	for x = -1, 1 do
		for y = -1, 1 do
			local adj_x = center_x + x
			local adj_y = center_y + y
			if adj_x >= 0 and adj_x < width and adj_y >= 0 and adj_y < height then
				local adj_index = adj_x + adj_y * width
				if adj_index ~= index then
					local adj_grid = room:GetGridEntity(adj_index)
					local adj_rock = adj_grid and adj_grid:ToRock()
					if adj_rock and adj_rock.GetBigRockFrame and adj_rock.SetBigRockFrame then
						local frame = adj_rock:GetBigRockFrame()
						if (frame == 0 and x == -1 and y == 0)
							or (frame == 1 and x == 1 and y == 0)
							or (frame == 2 and x == 0 and y == -1)
							or (frame == 3 and x == 0 and y == 1)
						then
							apply_big_frame_change(adj_rock, adj_index, -1, changed_list, changed_set)
						elseif frame == 4 then -- right-down
							if x == -1 and y == 0 then
								apply_big_frame_change(adj_rock, adj_index, -1, changed_list, changed_set)
							elseif y == -1 then
								apply_big_frame_change(adj_rock, adj_index, 0, changed_list, changed_set)
							end
						elseif frame == 5 then -- left-down
							if x == 1 and y == 0 then
								apply_big_frame_change(adj_rock, adj_index, -1, changed_list, changed_set)
							elseif y == -1 then
								apply_big_frame_change(adj_rock, adj_index, 1, changed_list, changed_set)
							end
						elseif frame == 6 then -- right-up
							if x == -1 and y == 0 then
								apply_big_frame_change(adj_rock, adj_index, -1, changed_list, changed_set)
							elseif y == 1 then
								apply_big_frame_change(adj_rock, adj_index, 0, changed_list, changed_set)
							end
						elseif frame == 7 then -- left-up
							if x == 1 and y == 0 then
								apply_big_frame_change(adj_rock, adj_index, -1, changed_list, changed_set)
							elseif y == 1 then
								apply_big_frame_change(adj_rock, adj_index, 1, changed_list, changed_set)
							end
						end
					end
				end
			end
		end
	end

	return changed_list, changed_set
end

--- Reverie order: self BigRockFrame=-1, then DisconnectBigRocks(index).
--- Returns {ok, center, changed_indices, changed_set}.
function RockTopology.detach_from_big_rock(room, index)
	room = room or Game():GetRoom()
	local grid = room:GetGridEntity(index)
	local rock = grid and grid:ToRock()
	if not rock then
		return {
			ok = false,
			center = index,
			changed_indices = {},
			changed_set = {},
		}
	end

	local changed_list = {}
	local changed_set = {}
	if rock.GetBigRockFrame and rock.SetBigRockFrame then
		local old_frame = rock:GetBigRockFrame()
		if old_frame ~= -1 then
			rock:SetBigRockFrame(-1)
			mark_changed(changed_list, changed_set, index)
		else
			-- Explicit clear even when already -1 (matches Reverie); not a topology change.
			rock:SetBigRockFrame(-1)
		end
	end

	local neighbor_changed = RockTopology.disconnect_big_rocks(room, index)
	for _, idx in ipairs(neighbor_changed) do
		mark_changed(changed_list, changed_set, idx)
	end

	return {
		ok = true,
		center = index,
		changed_indices = changed_list,
		changed_set = changed_set,
	}
end

--- Non-destructive visual sync for cells whose BigRockFrame already changed.
--- Uses UpdateAnimFrame only. NEVER UpdateNeighbors (that API breaks big links).
function RockTopology.sync_changed_visuals(room, indices)
	room = room or Game():GetRoom()
	for _, idx in ipairs(indices or {}) do
		local grid = room:GetGridEntity(idx)
		local rock = grid and grid:ToRock()
		if rock and rock.UpdateAnimFrame then
			rock:UpdateAnimFrame()
		end
	end
end

local function partner_index_at(index, dx, dy, width, size)
	local col = index % width
	local row = math.floor(index / width)
	local pc = col + dx
	local pr = row + dy
	if pc < 0 or pc >= width or pr < 0 then
		return nil
	end
	local partner_index = pr * width + pc
	if partner_index < 0 or partner_index >= size then
		return nil
	end
	return partner_index
end

local function frame_partners_include(owner_index, frame, expected_partner, width, size)
	local partners = BIG_FRAME_PARTNERS[frame]
	if not partners or frame == nil or frame < 0 then
		return false
	end
	for _, off in ipairs(partners) do
		local pi = partner_index_at(owner_index, off[1], off[2], width, size)
		if pi == expected_partner then
			return true
		end
	end
	return false
end

--- Undirected big-rock components among rocks with big_frame >= 0.
function RockTopology.build_big_components(room, indices)
	room = room or Game():GetRoom()
	local width = room:GetGridWidth()
	local size = room:GetGridSize()
	local list = indices
	if list == nil then
		list = {}
		for i = 0, size - 1 do
			list[#list + 1] = i
		end
	end

	local members = {}
	local member_set = {}
	for _, index in ipairs(list) do
		local grid = room:GetGridEntity(index)
		local frame = RockTopology.get_big_frame(grid)
		if grid and RockTopology.is_rock(grid) and frame ~= nil and frame >= 0 then
			members[#members + 1] = index
			member_set[index] = true
		end
	end

	local parent = {}
	local function find(a)
		local p = parent[a]
		if p == nil then
			parent[a] = a
			return a
		end
		if p ~= a then
			parent[a] = find(p)
		end
		return parent[a]
	end
	local function union(a, b)
		local ra, rb = find(a), find(b)
		if ra ~= rb then
			parent[rb] = ra
		end
	end

	for _, index in ipairs(members) do
		find(index)
		local frame = RockTopology.get_big_frame(room:GetGridEntity(index))
		local partners = BIG_FRAME_PARTNERS[frame]
		if partners then
			for _, off in ipairs(partners) do
				local pi = partner_index_at(index, off[1], off[2], width, size)
				if pi ~= nil and member_set[pi] then
					union(index, pi)
				end
			end
		end
	end

	local buckets = {}
	for _, index in ipairs(members) do
		local root = find(index)
		local bucket = buckets[root]
		if not bucket then
			bucket = {}
			buckets[root] = bucket
		end
		bucket[#bucket + 1] = index
	end

	local components = {}
	for _, bucket in pairs(buckets) do
		table.sort(bucket)
		components[#components + 1] = bucket
	end
	table.sort(components, function(a, b)
		return (a[1] or 0) < (b[1] or 0)
	end)
	return components
end

local function component_key(component)
	return table.concat(component, ",")
end

local function component_touches_set(component, set)
	for _, idx in ipairs(component) do
		if set[idx] then
			return true
		end
	end
	return false
end

--- Compare before/after snapshots for untouched cells and unrelated big components.
function RockTopology.audit_topology_preservation(before_by_index, after_rows, opts)
	opts = opts or {}
	local target_set = opts.target_set or {}
	local changed_set = opts.changed_set or {}
	local before_components = opts.before_components
	local after_components = opts.after_components
	local issues = {}

	for _, row in ipairs(after_rows or {}) do
		local idx = row.grid_index or row.index
		local before = before_by_index and before_by_index[idx]
		if before
			and not target_set[idx]
			and not changed_set[idx]
			and before.big_frame ~= row.big_frame
		then
			issues[#issues + 1] = {
				index = idx,
				reason = "unexpected_untouched_topology_mutation",
				before_big_frame = before.big_frame,
				after_big_frame = row.big_frame,
				before_anim = before.anim,
				after_anim = row.anim,
			}
		end
	end

	if before_components and after_components then
		local after_keys = {}
		for _, comp in ipairs(after_components) do
			after_keys[component_key(comp)] = true
		end
		for _, comp in ipairs(before_components) do
			if not component_touches_set(comp, target_set)
				and not component_touches_set(comp, changed_set)
			then
				local key = component_key(comp)
				if not after_keys[key] then
					issues[#issues + 1] = {
						reason = "unrelated_big_component_modified",
						component = comp,
						component_key = key,
					}
				end
			end
		end
	end

	return {
		ok = #issues == 0,
		issues = issues,
	}
end
function RockTopology.collect_neighborhood(room, seed_indices, radius)
	room = room or Game():GetRoom()
	radius = radius or 1
	local width = room:GetGridWidth()
	local size = room:GetGridSize()
	local set = {}
	local list = {}
	local function mark(idx)
		if idx == nil or set[idx] then return end
		if idx < 0 or idx >= size then return end
		set[idx] = true
		list[#list + 1] = idx
	end
	if type(seed_indices) == "number" then
		seed_indices = {seed_indices}
	end
	for _, index in ipairs(seed_indices or {}) do
		local col = index % width
		local row = math.floor(index / width)
		for dy = -radius, radius do
			for dx = -radius, radius do
				local r = row + dy
				local c = col + dx
				if r >= 0 and c >= 0 and c < width then
					mark(r * width + c)
				end
			end
		end
	end
	table.sort(list)
	return list, set
end

function RockTopology.collect_cardinal_neighborhood(room, seed_indices, include_center)
	room = room or Game():GetRoom()
	local width = room:GetGridWidth()
	local size = room:GetGridSize()
	local set = {}
	local list = {}
	local function mark(idx)
		if idx == nil or set[idx] then return end
		if idx < 0 or idx >= size then return end
		set[idx] = true
		list[#list + 1] = idx
	end
	if type(seed_indices) == "number" then
		seed_indices = {seed_indices}
	end
	for _, index in ipairs(seed_indices or {}) do
		if include_center then
			mark(index)
		end
		local col = index % width
		local row = math.floor(index / width)
		local candidates = {
			(col > 0) and (index - 1) or nil,
			(col + 1 < width) and (index + 1) or nil,
			(row > 0) and (index - width) or nil,
			index + width,
		}
		for _, nidx in ipairs(candidates) do
			mark(nidx)
		end
	end
	table.sort(list)
	return list, set
end

--- DESTRUCTIVE. Breaks THIS rock's big-rock connections (RGON UpdateNeighbors).
--- Not a visual refresh. Do not call on arbitrary neighbors.
--- Prefer detach_from_big_rock / disconnect_big_rocks for topology mutation.
function RockTopology.break_big_rock_links_destructive(room, indices)
	room = room or Game():GetRoom()
	for _, idx in ipairs(indices or {}) do
		local grid = room:GetGridEntity(idx)
		local rock = grid and grid:ToRock()
		if rock and rock.UpdateNeighbors then
			rock:UpdateNeighbors()
		end
	end
end

-- Deprecated alias kept only so old call sites fail loudly in review.
-- Prefer break_big_rock_links_destructive if an engine destroy/lift path truly needs it.
function RockTopology.update_neighbors(room, indices)
	RockTopology.break_big_rock_links_destructive(room, indices)
end

function RockTopology.validate_neighborhood(room, indices, opts)
	room = room or Game():GetRoom()
	opts = opts or {}
	local width = room:GetGridWidth()
	local size = room:GetGridSize()
	local is_connectable = opts.is_connectable
	local issues = {}

	local function partner_connectable(partner_index)
		if partner_index == nil or partner_index < 0 or partner_index >= size then
			return false, partner_index
		end
		local partner = room:GetGridEntity(partner_index)
		if not partner then
			return false, partner_index
		end
		if is_connectable then
			if not is_connectable(partner, partner_index) then
				return false, partner_index
			end
		elseif not RockTopology.is_rock(partner) then
			return false, partner_index
		end
		return true, partner_index
	end

	local list = indices
	if list == nil then
		list = {}
		for i = 0, size - 1 do
			list[#list + 1] = i
		end
	elseif type(list) == "number" then
		list = {list}
	end

	for _, index in ipairs(list) do
		local grid = room:GetGridEntity(index)
		if grid then
			local frame = RockTopology.get_big_frame(grid)
			if frame ~= nil and frame >= 0 then
				local partners = BIG_FRAME_PARTNERS[frame]
				if partners then
					for _, off in ipairs(partners) do
						local partner_index = partner_index_at(index, off[1], off[2], width, size)
						local ok, missing = partner_connectable(partner_index)
						if not ok then
							issues[#issues + 1] = {
								index = index,
								reason = "dangling_big_reference",
								big_frame = frame,
								missing_index = missing,
							}
						else
							local partner_grid = room:GetGridEntity(partner_index)
							local partner_frame = RockTopology.get_big_frame(partner_grid)
							if not frame_partners_include(partner_index, partner_frame, index, width, size) then
								issues[#issues + 1] = {
									index = index,
									reason = "non_reciprocal_big_reference",
									big_frame = frame,
									partner_index = partner_index,
									partner_big_frame = partner_frame,
								}
							end
						end
					end
				else
					issues[#issues + 1] = {
						index = index,
						reason = "unknown_big_frame",
						big_frame = frame,
					}
				end
			end
		end
	end

	return {
		ok = #issues == 0,
		issues = issues,
	}
end

local function index_snapshots(rows)
	local map = {}
	for _, row in ipairs(rows or {}) do
		local idx = row.grid_index or row.index
		if idx ~= nil then
			map[idx] = row
		end
	end
	return map
end

local function merge_changed(into_list, into_set, from_list)
	for _, idx in ipairs(from_list or {}) do
		mark_changed(into_list, into_set, idx)
	end
end

local function apply_one_mutate(grid, opts)
	if opts.new_type ~= nil then
		grid:SetType(opts.new_type)
	end
	if opts.new_variant ~= nil then
		grid:SetVariant(opts.new_variant)
	end
	if opts.update_anim_frame == true then
		local rock = grid:ToRock()
		if rock then
			if opts.rock_anim ~= nil then
				rock.Anim = opts.rock_anim
			end
			if rock.UpdateAnimFrame then
				rock:UpdateAnimFrame()
			end
		end
	end
end

local function apply_one_visual(room, index, opts)
	local grid = room:GetGridEntity(index)
	if not grid then return false end
	local rock = grid:ToRock()
	if opts.keep_single == true and rock and rock.SetBigRockFrame then
		local old = rock.GetBigRockFrame and rock:GetBigRockFrame() or nil
		rock:SetBigRockFrame(-1)
		if old ~= nil and old ~= -1 and rock.UpdateAnimFrame then
			rock:UpdateAnimFrame()
		end
	end
	if opts.apply_visual then
		opts.apply_visual(grid, rock, grid:GetSprite())
	end
	return true
end

local function run_post_validation(room, affected, opts, target_set, changed_set, before_rows)
	opts = opts or {}
	local validation_opts = {}
	for k, v in pairs(opts.validation_opts or {}) do
		validation_opts[k] = v
	end
	if validation_opts.is_connectable == nil and opts.keep_targets_non_connectable ~= false then
		validation_opts.is_connectable = function(grid, index)
			if target_set and target_set[index] then
				return false
			end
			return RockTopology.is_rock(grid)
		end
	end

	local structural = RockTopology.validate_neighborhood(room, affected, validation_opts)
	local after_rows = {}
	for _, idx in ipairs(affected) do
		after_rows[#after_rows + 1] = RockTopology.snapshot(room, idx)
	end
	local after_components = RockTopology.build_big_components(room, affected)
	local preservation = RockTopology.audit_topology_preservation(
		index_snapshots(before_rows),
		after_rows,
		{
			target_set = target_set or {},
			changed_set = changed_set or {},
			before_components = opts.before_components,
			after_components = after_components,
		}
	)

	local issues = {}
	for _, issue in ipairs(structural.issues or {}) do
		issues[#issues + 1] = issue
	end
	for _, issue in ipairs(preservation.issues or {}) do
		issues[#issues + 1] = issue
	end

	return {
		ok = #issues == 0,
		issues = issues,
		structural = structural,
		preservation = preservation,
		after_components = after_components,
		after_rows = after_rows,
	}
end

--- Single-cell topology-safe rock replace.
function RockTopology.replace_rock(room, index, opts)
	room = room or Game():GetRoom()
	opts = opts or {}
	local grid = room:GetGridEntity(index)
	if not grid then
		return {ok = false, reason = "missing", index = index}
	end
	if opts.validate and not opts.validate(grid, index) then
		return {ok = false, reason = "validation_failed", index = index}
	end

	local before = RockTopology.snapshot(room, index)
	local neighborhood = RockTopology.collect_neighborhood(room, {index}, opts.refresh_radius or 1)
	local before_rows = {}
	for _, idx in ipairs(neighborhood) do
		before_rows[#before_rows + 1] = RockTopology.snapshot(room, idx)
	end
	local before_components = RockTopology.build_big_components(room, neighborhood)

	emit("before_detach", {
		index = index,
		before = before,
		affected_indices = neighborhood,
		rows = before_rows,
		before_components = before_components,
	})

	local detach_info = RockTopology.detach_from_big_rock(room, index)
	local changed_indices = detach_info.changed_indices or {}
	local changed_set = detach_info.changed_set or {}

	emit("after_detach", {
		index = index,
		detached = detach_info.ok,
		changed_indices = changed_indices,
		snapshot = RockTopology.snapshot(room, index),
		affected_indices = neighborhood,
	})

	grid = room:GetGridEntity(index)
	if not grid then
		return {ok = false, reason = "missing_after_detach", index = index, before = before}
	end

	apply_one_mutate(grid, opts)

	emit("after_mutate", {
		index = index,
		snapshot = RockTopology.snapshot(room, index),
		affected_indices = neighborhood,
		changed_indices = changed_indices,
	})

	RockTopology.sync_changed_visuals(room, changed_indices)

	emit("after_topology_sync", {
		index = index,
		snapshot = RockTopology.snapshot(room, index),
		affected_indices = neighborhood,
		changed_indices = changed_indices,
		before_rows = before_rows,
	})

	apply_one_visual(room, index, opts)

	emit("after_visual", {
		index = index,
		snapshot = RockTopology.snapshot(room, index),
		affected_indices = neighborhood,
		changed_indices = changed_indices,
	})

	local after = RockTopology.snapshot(room, index)
	local validation = run_post_validation(
		room,
		neighborhood,
		{
			validation_opts = opts.validation_opts,
			keep_targets_non_connectable = opts.keep_single == true,
			before_components = before_components,
		},
		{[index] = true},
		changed_set,
		before_rows
	)
	emit("after_validate", {
		index = index,
		validation = validation,
		affected_indices = neighborhood,
		changed_indices = changed_indices,
	})

	return {
		ok = validation.ok,
		index = index,
		before = before,
		after = after,
		affected_indices = neighborhood,
		changed_indices = changed_indices,
		changed_set = changed_set,
		detached = detach_info.ok,
		validation = validation,
	}
end

--- Batch topology-safe rock replace.
--- Detach all targets, mutate all, sync only cells whose BigRockFrame changed.
function RockTopology.replace_rocks(room, replacements, opts)
	room = room or Game():GetRoom()
	opts = opts or {}
	replacements = replacements or {}

	local accepted = {}
	local rejected = {}
	local target_set = {}

	for _, rep in ipairs(replacements) do
		local index = rep.index
		local grid = room:GetGridEntity(index)
		if not grid then
			rejected[#rejected + 1] = {
				index = index,
				reason = "missing",
				metadata = rep.metadata,
			}
		elseif rep.validate and not rep.validate(grid, index) then
			rejected[#rejected + 1] = {
				index = index,
				reason = "validation_failed",
				metadata = rep.metadata,
				snapshot = RockTopology.snapshot(room, index),
			}
		else
			accepted[#accepted + 1] = {
				index = index,
				opts = rep,
				before = RockTopology.snapshot(room, index),
				metadata = rep.metadata,
			}
			target_set[index] = true
		end
	end

	if #accepted == 0 then
		return {
			ok = true,
			accepted = {},
			rejected = rejected,
			affected_indices = {},
			target_indices = {},
			changed_indices = {},
		}
	end

	local target_indices = {}
	for _, entry in ipairs(accepted) do
		target_indices[#target_indices + 1] = entry.index
	end

	local refresh_radius = opts.refresh_radius or 1
	local affected = RockTopology.collect_neighborhood(room, target_indices, refresh_radius)

	local before_rows = {}
	for _, idx in ipairs(affected) do
		before_rows[#before_rows + 1] = RockTopology.snapshot(room, idx)
	end
	local before_components = RockTopology.build_big_components(room, affected)

	emit("before_detach", {
		target_indices = target_indices,
		affected_indices = affected,
		rows = before_rows,
		before_components = before_components,
	})

	local changed_indices = {}
	local changed_set = {}
	for _, entry in ipairs(accepted) do
		local detach_info = RockTopology.detach_from_big_rock(room, entry.index)
		entry.detached = detach_info.ok
		entry.detach_info = detach_info
		merge_changed(changed_indices, changed_set, detach_info.changed_indices)
	end

	emit("after_detach", {
		target_indices = target_indices,
		affected_indices = affected,
		changed_indices = changed_indices,
		rows = RockTopology.debug_listener and select(1, RockTopology.snapshot_neighborhood(room, affected, 0)) or nil,
	})

	for _, entry in ipairs(accepted) do
		local grid = room:GetGridEntity(entry.index)
		if grid then
			apply_one_mutate(grid, entry.opts)
			entry.mutated = true
		else
			entry.mutated = false
			entry.fail_reason = "missing_after_detach"
		end
	end

	emit("after_mutate", {
		target_indices = target_indices,
		affected_indices = affected,
		changed_indices = changed_indices,
		rows = RockTopology.debug_listener and select(1, RockTopology.snapshot_neighborhood(room, target_indices, 0)) or nil,
	})

	RockTopology.sync_changed_visuals(room, changed_indices)

	emit("after_topology_sync", {
		target_indices = target_indices,
		affected_indices = affected,
		changed_indices = changed_indices,
		before_rows = before_rows,
		rows = RockTopology.debug_listener and select(1, RockTopology.snapshot_neighborhood(room, affected, 0)) or nil,
	})

	local results = {}
	for _, entry in ipairs(accepted) do
		if entry.mutated then
			apply_one_visual(room, entry.index, entry.opts)
			local after = RockTopology.snapshot(room, entry.index)
			results[#results + 1] = {
				ok = true,
				index = entry.index,
				before = entry.before,
				after = after,
				detached = entry.detached,
				metadata = entry.metadata,
			}
		else
			results[#results + 1] = {
				ok = false,
				index = entry.index,
				reason = entry.fail_reason or "mutate_failed",
				before = entry.before,
				metadata = entry.metadata,
			}
		end
	end

	emit("after_visual", {
		target_indices = target_indices,
		affected_indices = affected,
		changed_indices = changed_indices,
		before_rows = before_rows,
		rows = RockTopology.debug_listener and select(1, RockTopology.snapshot_neighborhood(room, affected, 0)) or nil,
		results = results,
	})

	local validation = run_post_validation(
		room,
		affected,
		{
			validation_opts = opts.validation_opts,
			keep_targets_non_connectable = opts.keep_targets_non_connectable,
			before_components = before_components,
		},
		target_set,
		changed_set,
		before_rows
	)

	emit("after_validate", {
		target_indices = target_indices,
		affected_indices = affected,
		changed_indices = changed_indices,
		validation = validation,
	})

	return {
		ok = validation.ok,
		accepted = results,
		rejected = rejected,
		affected_indices = affected,
		target_indices = target_indices,
		target_set = target_set,
		changed_indices = changed_indices,
		changed_set = changed_set,
		validation = validation,
		before_rows = before_rows,
		before_components = before_components,
	}
end

--- Remove a rock grid after topology detach. No UpdateNeighbors.
function RockTopology.remove_rock(room, index, opts)
	room = room or Game():GetRoom()
	opts = opts or {}
	local grid = room:GetGridEntity(index)
	if not grid then
		return {ok = false, reason = "missing", index = index}
	end

	local before = RockTopology.snapshot(room, index)
	local affected = RockTopology.collect_neighborhood(room, {index}, opts.refresh_radius or 1)
	local before_rows = {}
	for _, idx in ipairs(affected) do
		before_rows[#before_rows + 1] = RockTopology.snapshot(room, idx)
	end
	local before_components = RockTopology.build_big_components(room, affected)

	emit("before_detach", {
		index = index,
		op = "remove",
		before = before,
		affected_indices = affected,
		rows = before_rows,
		before_components = before_components,
	})

	local detach_info = RockTopology.detach_from_big_rock(room, index)
	local changed_indices = detach_info.changed_indices or {}
	local changed_set = detach_info.changed_set or {}

	emit("after_detach", {
		index = index,
		op = "remove",
		affected_indices = affected,
		changed_indices = changed_indices,
	})

	room:RemoveGridEntity(index, opts.path_penalty or 0, opts.keep_decoration == true)

	local sync_list = {}
	for _, idx in ipairs(changed_indices) do
		if idx ~= index then
			sync_list[#sync_list + 1] = idx
		end
	end
	RockTopology.sync_changed_visuals(room, sync_list)

	emit("after_topology_sync", {
		index = index,
		op = "remove",
		affected_indices = affected,
		changed_indices = sync_list,
		before_rows = before_rows,
	})

	local remain = {}
	for _, idx in ipairs(affected) do
		if idx ~= index then
			remain[#remain + 1] = idx
		end
	end
	local validation = run_post_validation(
		room,
		remain,
		{
			validation_opts = opts.validation_opts,
			keep_targets_non_connectable = false,
			before_components = before_components,
		},
		{[index] = true},
		changed_set,
		before_rows
	)
	emit("after_validate", {
		index = index,
		op = "remove",
		validation = validation,
		changed_indices = sync_list,
	})

	return {
		ok = validation.ok,
		index = index,
		before = before,
		affected_indices = remain,
		changed_indices = sync_list,
		changed_set = changed_set,
		validation = validation,
	}
end

return RockTopology
