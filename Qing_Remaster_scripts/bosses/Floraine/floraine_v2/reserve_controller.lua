-- Boss Arena reserve queue: 20 dormant identities + select / deploy requests.
-- Combat NPCs are created only by deployment.lua on LAND.
-- Visuals: Floraine Matte Piece Effects (native Y-sort), not POST_RENDER sprites.
-- Entrance: prepare_formation (layout only) → begin_march (door → home) → RESERVE.

local piece_defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")
local reserve_defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_defs")
local matte_fx = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.piece_matte_fx")
local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")
local occupancy = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_occupancy")
local soft_collision = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.chess_piece_soft_collision")

local ctrl = {}

local pieces = {} -- id -> row
local order = {} -- array of ids for stable iteration
local layout = nil
local active = false
local march_active = false
local march_start_frame = nil -- Game():GetFrameCount() when begin_march fired
local deployed_total = 0
local deploying_count = 0
local selected_count = 0
local last_fail = "none"
local path_saved = {} -- gridIndex -> previous GridPath (only set when first claimed)
local path_owner = {} -- gridIndex -> blocker owner_id currently renewing this cell
local perf = {
	enabled = false,
	blocker_refresh = 0,
	gridpath_writes = 0,
	blocker_releases = 0,
	sync_calls = 0,
}

local function row_of(id)
	return pieces[id]
end

function ctrl.set_perf_enabled(on)
	perf.enabled = on == true
end

function ctrl.get_perf()
	return {
		enabled = perf.enabled,
		blocker_refresh = perf.blocker_refresh,
		gridpath_writes = perf.gridpath_writes,
		blocker_releases = perf.blocker_releases,
		sync_calls = perf.sync_calls,
	}
end

function ctrl.reset_perf()
	perf.blocker_refresh = 0
	perf.gridpath_writes = 0
	perf.blocker_releases = 0
	perf.sync_calls = 0
end

local function count_state(st)
	local n = 0
	for _, id in ipairs(order) do
		local r = pieces[id]
		if r and r.state == st then
			n = n + 1
		end
	end
	return n
end

function ctrl.is_active()
	return active
end

local function clear_grid_path()
	local room = Game():GetRoom()
	if room and room.SetGridPath then
		for idx, prev in pairs(path_saved) do
			if type(idx) == "number" and type(prev) == "number" then
				room:SetGridPath(idx, prev)
			end
		end
	end
	path_saved = {}
	path_owner = {}
end

function ctrl.note_sync()
	if perf.enabled then
		perf.sync_calls = perf.sync_calls + 1
	end
end

local function blocker_id(row)
	return "reserve_" .. tostring(row.id)
end

local function restore_path_at(room, gidx)
	if type(gidx) ~= "number" or gidx < 0 then
		return
	end
	local prev = path_saved[gidx]
	path_saved[gidx] = nil
	path_owner[gidx] = nil
	if not room or not room.SetGridPath or prev == nil then
		return
	end
	local cost = reserve_defs.gridpath_cost()
	local cur = room.GetGridPath and room:GetGridPath(gidx)
	-- Only restore if we still own the stamped cost (do not clobber newer writers).
	if type(cur) == "number" and cur >= cost then
		room:SetGridPath(gidx, prev)
	elseif type(cur) ~= "number" then
		room:SetGridPath(gidx, prev)
	end
end

local function renew_path_at(room, gidx, bid)
	if not room or not room.SetGridPath or type(gidx) ~= "number" or gidx < 0 then
		return
	end
	local cost = reserve_defs.gridpath_cost()
	if path_saved[gidx] == nil then
		local prev = room.GetGridPath and room:GetGridPath(gidx)
		if type(prev) ~= "number" then
			prev = 0
		end
		if prev < cost then
			path_saved[gidx] = prev
		else
			path_saved[gidx] = cost
		end
	end
	path_owner[gidx] = bid
	room:SetGridPath(gidx, cost)
	if perf.enabled then
		perf.gridpath_writes = perf.gridpath_writes + 1
	end
end

--- Incremental hard blockers + GridPath 900 renew (logic frame only; never from Render).
-- Soft push + GridPath occupancy only while RESERVE (SELECTED+ releases space immediately).
function ctrl.refresh_blockers_and_path()
	if perf.enabled then
		perf.blocker_refresh = perf.blocker_refresh + 1
	end
	local room = Game():GetRoom()
	local S = reserve_defs.STATE
	local grounded = {
		[S.RESERVE] = true,
	}
	local want = {} -- owner_id -> gidx
	local function path_gidx_for(bid)
		for gidx, owner in pairs(path_owner) do
			if owner == bid then
				return gidx
			end
		end
		return nil
	end
	for _, id in ipairs(order) do
		local row = pieces[id]
		if not row then
			-- skip
		elseif grounded[row.state] and row.home_pos then
			local bid = blocker_id(row)
			local old_gidx = path_gidx_for(bid)
			local ok, gidx = occupancy.set_blocker("reserve_piece", bid, row.home_pos)
			if ok and type(gidx) == "number" and gidx >= 0 then
				want[bid] = gidx
				if old_gidx and old_gidx ~= gidx then
					restore_path_at(room, old_gidx)
				end
				renew_path_at(room, gidx, bid)
			end
		else
			local bid = blocker_id(row)
			local prev_gidx = path_gidx_for(bid)
			occupancy.clear_blocker(bid)
			if prev_gidx then
				restore_path_at(room, prev_gidx)
				if perf.enabled then
					perf.blocker_releases = perf.blocker_releases + 1
				end
			end
		end
	end
	ctrl.soft_block_players()
end

--- Push players out of RESERVE matte cells only (no damage). One push per player per frame.
function ctrl.soft_block_players()
	if not active then
		return
	end
	local room = Game():GetRoom()
	local center_x = room:GetCenterPos().X
	local radius = soft_collision.default_radius()
	local strength = soft_collision.default_strength()
	local S = reserve_defs.STATE
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player and player:Exists() and not player:IsDead() then
			for _, id in ipairs(order) do
				local row = pieces[id]
				if row and row.state == S.RESERVE and row.pos then
					if soft_collision.push_player(player, row.pos, center_x, strength, radius) then
						break
					end
				elseif row and row.state == S.RESERVE and row.home_pos then
					if soft_collision.push_player(player, row.home_pos, center_x, strength, radius) then
						break
					end
				end
			end
		end
	end
end

function ctrl.release_home_blocker(id)
	local row = row_of(id)
	if not row then
		return
	end
	local bid = blocker_id(row)
	local prev_gidx = nil
	for gidx, owner in pairs(path_owner) do
		if owner == bid then
			prev_gidx = gidx
			break
		end
	end
	occupancy.clear_blocker(bid)
	if prev_gidx then
		restore_path_at(Game():GetRoom(), prev_gidx)
	end
end

function ctrl.clear(reason)
	clear_grid_path()
	path_owner = {}
	occupancy.clear_blockers_by_owner("reserve_piece")
	for _, id in ipairs(order) do
		local row = pieces[id]
		if row and row.effect then
			matte_fx.remove(row.effect)
			row.effect = nil
		end
	end
	pieces = {}
	order = {}
	layout = nil
	active = false
	march_active = false
	march_start_frame = nil
	deployed_total = 0
	deploying_count = 0
	selected_count = 0
	last_fail = reason or "cleared"
end

local function build_rows_from_layout(resolved, initial_state)
	layout = resolved
	pieces = {}
	order = {}
	for _, cell in ipairs(resolved.cells) do
		local row = {
			id = cell.id,
			kind = cell.kind,
			side = cell.side,
			ante_col = cell.ante_col,
			ante_row = cell.ante_row,
			reserve_slot = cell.reserve_slot,
			home_pos = Vector(cell.pos.X, cell.pos.Y),
			pos = Vector(cell.pos.X, cell.pos.Y),
			grid_index = cell.grid_index,
			state = initial_state or reserve_defs.STATE.RESERVE,
			visual_height = 0,
			visual_color_progress = 0,
			outline_pulse = 0,
			phase_elapsed = 0,
			deploy_target = nil,
			deploy_target_gidx = nil,
			hidden = initial_state == reserve_defs.STATE.PENDING,
			npc_ptr = nil,
			freeze_debug = false,
			effect = nil,
			march_start = nil,
			march_t0 = nil,
			march_dur = nil,
		}
		pieces[row.id] = row
		order[#order + 1] = row.id
	end
	return #order
end

local function entry_pos_for(row, room)
	room = room or Game():GetRoom()
	local tl = room:GetTopLeftPos()
	local br = room:GetBottomRightPos()
	local y = row.home_pos.Y
	-- Prefer real side door slots when present; else playable edge just outside.
	if row.side == "left" then
		local door = room:GetDoor(DoorSlot.LEFT0) or room:GetDoor(DoorSlot.LEFT1)
		if door then
			return Vector(door.Position.X, y)
		end
		return Vector(tl.X - 10, y)
	end
	local door = room:GetDoor(DoorSlot.RIGHT0) or room:GetDoor(DoorSlot.RIGHT1)
	if door then
		return Vector(door.Position.X, y)
	end
	return Vector(br.X + 10, y)
end

--- Resolve layout only — no matte Effects yet (empty battlefield on room enter).
function ctrl.prepare_formation()
	ctrl.clear("prepare")
	local room = Game():GetRoom()
	local resolved, why = reserve_defs.resolve_reserve_layout(room)
	if not resolved then
		last_fail = why or "layout_failed"
		Isaac.DebugString(string.format("[FloraineV2] reserve layout failed: %s", tostring(last_fail)))
		return false, last_fail
	end
	local n = build_rows_from_layout(resolved, reserve_defs.STATE.PENDING)
	active = false
	march_active = false
	last_fail = (n == reserve_defs.COUNT) and "prepared" or ("count_" .. tostring(n))
	return n == reserve_defs.COUNT, n
end

--- Start side-door march. Requires prepare_formation() first.
function ctrl.begin_march()
	if #order < 1 then
		local ok = ctrl.prepare_formation()
		if not ok then
			return false, last_fail
		end
	end
	local room = Game():GetRoom()
	local cfg = defs.FORMATION_MARCH or {}
	local stagger = cfg.STAGGER or 2
	local dur = cfg.DURATION or 16
	march_start_frame = Game():GetFrameCount()
	march_active = true
	active = false
	-- Left then right waves for a readable two-column entrance; within side, slot order.
	local left, right = {}, {}
	for _, id in ipairs(order) do
		local row = pieces[id]
		if row then
			if row.side == "left" then
				left[#left + 1] = row
			else
				right[#right + 1] = row
			end
		end
	end
	local function arm(list, wave_offset)
		for i, row in ipairs(list) do
			local start = entry_pos_for(row, room)
			row.march_start = Vector(start.X, start.Y)
			row.pos = Vector(start.X, start.Y)
			row.march_t0 = wave_offset + (i - 1) * stagger
			row.march_dur = dur
			row.state = reserve_defs.STATE.PENDING
			row.hidden = true
			row.visual_height = 0
			row.visual_color_progress = 0
		end
	end
	arm(left, 0)
	arm(right, 1) -- right column starts 1 frame after left for slight offset
	last_fail = "marching"
	return true, #order
end

function ctrl.tick_march()
	if not march_active then
		return true
	end
	-- Absolute Game frame so multi-call per frame (update + render) stays idempotent.
	-- Game():GetFrameCount() is 30Hz — matches INTRO / combat logic clock.
	local march_frame = Game():GetFrameCount() - (march_start_frame or Game():GetFrameCount())
	local all_done = true
	for _, id in ipairs(order) do
		local row = pieces[id]
		if not row then
			-- skip
		elseif row.state == reserve_defs.STATE.RESERVE and not row.march_start then
			-- already settled
		else
			local t0 = row.march_t0 or 0
			local dur = math.max(1, row.march_dur or 16)
			if march_frame < t0 then
				all_done = false
			elseif march_frame <= t0 then
				all_done = false
				row.state = reserve_defs.STATE.MARCHING
				row.hidden = false
				row.pos = Vector(row.march_start.X, row.march_start.Y)
				if not (row.effect and matte_fx.is_matte(row.effect)) then
					row.effect = matte_fx.spawn(row.kind, row.pos, {
						owner = "reserve",
						piece_id = row.id,
						color_progress = 0,
						outline_alpha = 0,
					})
				end
			elseif march_frame < t0 + dur then
				all_done = false
				local t = (march_frame - t0) / dur
				-- ease-out
				t = 1 - (1 - t) * (1 - t)
				local a = row.march_start
				local b = row.home_pos
				row.pos = Vector(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t)
				row.state = reserve_defs.STATE.MARCHING
				row.hidden = false
			else
				row.pos = Vector(row.home_pos.X, row.home_pos.Y)
				row.state = reserve_defs.STATE.RESERVE
				row.hidden = false
				row.march_start = nil
				row.march_t0 = nil
				row.march_dur = nil
			end
		end
	end
	if all_done then
		march_active = false
		march_start_frame = nil
		active = #order == reserve_defs.COUNT
		last_fail = active and "march_done" or ("march_count_" .. tostring(#order))
		return true
	end
	return false
end

function ctrl.is_marching()
	return march_active == true
end

function ctrl.is_prepared()
	return #order > 0 and layout ~= nil
end

--- Instant materialize at home (debug / fallback). Skips door march.
function ctrl.spawn_formation()
	ctrl.clear("respawn")
	local room = Game():GetRoom()
	local resolved, why = reserve_defs.resolve_reserve_layout(room)
	if not resolved then
		last_fail = why or "layout_failed"
		Isaac.DebugString(string.format("[FloraineV2] reserve layout failed: %s", tostring(last_fail)))
		return false, last_fail
	end
	local n = build_rows_from_layout(resolved, reserve_defs.STATE.RESERVE)
	for _, id in ipairs(order) do
		local row = pieces[id]
		row.hidden = false
		row.effect = matte_fx.spawn(row.kind, row.home_pos, {
			owner = "reserve",
			piece_id = row.id,
			color_progress = 0,
			outline_alpha = 0,
		})
	end
	active = n == reserve_defs.COUNT
	march_active = false
	last_fail = active and "ok" or ("count_" .. tostring(n))
	if not active then
		Isaac.DebugString(string.format("[FloraineV2] reserve spawn count=%d expected=%d", n, reserve_defs.COUNT))
	end
	return active, n
end

--- Debug: freeze one piece into a visual state without starting deployment.
function ctrl.debug_set_state(id, st, opts)
	opts = opts or {}
	local row = pieces[id]
	if not row then
		-- pick first visible if id nil
		if id == nil then
			for _, oid in ipairs(order) do
				local r = pieces[oid]
				if r and r.state == reserve_defs.STATE.RESERVE then
					row = r
					break
				end
			end
		end
	end
	if not row then
		return false, "no_piece"
	end
	row.state = st or reserve_defs.STATE.SELECTED
	row.freeze_debug = true
	row.phase_elapsed = opts.phase_elapsed or 0
	row.outline_pulse = opts.outline_pulse or 0.8
	row.visual_height = opts.visual_height or 0
	if opts.pos then
		row.pos = Vector(opts.pos.X, opts.pos.Y)
	else
		row.pos = Vector(row.home_pos.X, row.home_pos.Y)
	end
	row.hidden = false
	return true, row.id
end

function ctrl.for_each_visible(fn)
	-- Visible during march even before active==true (formation settled).
	if not active and not march_active then return end
	for _, id in ipairs(order) do
		local row = pieces[id]
		if row and not row.hidden then
			fn(row)
		end
	end
end

function ctrl.get_row(id)
	return row_of(id)
end

function ctrl.list_by_state(st)
	local out = {}
	for _, id in ipairs(order) do
		local r = pieces[id]
		if r and r.state == st then
			out[#out + 1] = r
		end
	end
	return out
end

function ctrl.count_remaining()
	return count_state(reserve_defs.STATE.RESERVE)
end

function ctrl.count_deploying()
	local n = 0
	local S = reserve_defs.STATE
	for _, id in ipairs(order) do
		local r = pieces[id]
		if r then
			local st = r.state
			if st == S.TARGETED or st == S.INFUSING or st == S.SELECTED or st == S.PULSING
				or st == S.LIFTING or st == S.TRANSFERRING or st == S.HOVERING
				or st == S.DROPPING or st == S.LANDING then
				n = n + 1
			end
		end
	end
	return n
end

function ctrl.count_active_slots()
	return count_state(reserve_defs.STATE.ACTIVE) + ctrl.count_deploying()
end

--- Pick next reserve piece matching preferred kind, else any RESERVE.
function ctrl.pick_for_kind(kind)
	kind = tonumber(kind)
	local fallback = nil
	for _, id in ipairs(order) do
		local r = pieces[id]
		if r and r.state == reserve_defs.STATE.RESERVE then
			if kind and r.kind == kind then
				return r
			end
			if not fallback then
				fallback = r
			end
		end
	end
	return fallback
end

function ctrl.pick_opening_three()
	local picked = {}
	local used = {}
	for _, kind in ipairs(reserve_defs.OPENING_KINDS) do
		for _, id in ipairs(order) do
			local r = pieces[id]
			if r and r.state == reserve_defs.STATE.RESERVE and r.kind == kind and not used[r.id] then
				used[r.id] = true
				picked[#picked + 1] = r
				break
			end
		end
	end
	for _, id in ipairs(order) do
		if #picked >= 3 then
			break
		end
		local r = pieces[id]
		if r and r.state == reserve_defs.STATE.RESERVE and not used[r.id] then
			used[r.id] = true
			picked[#picked + 1] = r
		end
	end
	return picked
end

--- Lock a reserve piece for a command soul (no outline yet — waits for red light).
function ctrl.begin_target(id)
	local row = row_of(id)
	if not row then
		last_fail = "unknown_id"
		return false, last_fail
	end
	if row.state ~= reserve_defs.STATE.RESERVE then
		last_fail = "not_reserve"
		return false, last_fail
	end
	row.state = reserve_defs.STATE.TARGETED
	row.phase_elapsed = 0
	row.outline_pulse = 0
	row.visual_height = 0
	row.visual_tilt = 0
	row.visual_color_progress = 0
	-- Leave RESERVE: free soft-collision + GridPath immediately (not wait for next refresh).
	ctrl.release_home_blocker(id)
	selected_count = selected_count + 1
	last_fail = "ok"
	return true, row
end

--- Begin select→deploy pipeline for one piece. Actual motion in deployment.lua.
function ctrl.begin_select(id)
	local row = row_of(id)
	if not row then
		last_fail = "unknown_id"
		return false, last_fail
	end
	if row.state ~= reserve_defs.STATE.RESERVE and row.state ~= reserve_defs.STATE.TARGETED then
		last_fail = "not_reserve"
		return false, last_fail
	end
	row.state = reserve_defs.STATE.SELECTED
	row.phase_elapsed = 0
	row.outline_pulse = 0
	row.visual_height = 0
	ctrl.release_home_blocker(id)
	selected_count = selected_count + 1
	last_fail = "ok"
	return true, row
end

function ctrl.get_order()
	return order
end

function ctrl.set_state(id, st)
	local row = row_of(id)
	if not row then return false end
	row.state = st
	return true
end

function ctrl.mark_active(id, npc_ptr)
	local row = row_of(id)
	if not row then return false end
	row.state = reserve_defs.STATE.ACTIVE
	row.hidden = true
	row.visual_height = 0
	row.outline_pulse = 0
	row.npc_ptr = npc_ptr
	row.deploy_target = nil
	row.deploy_target_gidx = nil
	occupancy.clear_blocker(blocker_id(row))
	if row.effect then
		matte_fx.remove(row.effect)
		row.effect = nil
	end
	deployed_total = deployed_total + 1
	return true
end

function ctrl.mark_defeated(id)
	local row = row_of(id)
	if not row then return false end
	row.state = reserve_defs.STATE.DEFEATED
	row.hidden = true
	row.npc_ptr = nil
	occupancy.clear_blocker(blocker_id(row))
	return true
end

function ctrl.revert_to_reserve(id)
	local row = row_of(id)
	if not row then return false end
	row.state = reserve_defs.STATE.RESERVE
	row.pos = Vector(row.home_pos.X, row.home_pos.Y)
	row.visual_height = 0
	row.visual_color_progress = 0
	row.outline_pulse = 0
	row.phase_elapsed = 0
	row.deploy_target = nil
	row.deploy_target_gidx = nil
	row.hidden = false
	row.npc_ptr = nil
	if not (row.effect and matte_fx.is_matte(row.effect)) then
		row.effect = matte_fx.spawn(row.kind, row.home_pos, {
			owner = "reserve",
			piece_id = row.id,
			color_progress = 0,
			outline_alpha = 0,
		})
	else
		matte_fx.sync(row.effect, {
			ground_pos = row.home_pos,
			visual_height = 0,
			color_progress = 0,
			outline_alpha = 0,
			hidden = false,
		})
	end
	return true
end

function ctrl.diag()
	return {
		active = active,
		total = #order,
		march_active = march_active,
		march_frame = march_start_frame and (Game():GetFrameCount() - march_start_frame) or 0,
		pending_count = count_state(reserve_defs.STATE.PENDING),
		marching_count = count_state(reserve_defs.STATE.MARCHING),
		reserve_remaining = ctrl.count_remaining(),
		selected_count = count_state(reserve_defs.STATE.SELECTED) + count_state(reserve_defs.STATE.PULSING),
		deploying_count = ctrl.count_deploying(),
		active_guards = count_state(reserve_defs.STATE.ACTIVE),
		defeated_count = count_state(reserve_defs.STATE.DEFEATED),
		deployed_total = deployed_total,
		last_fail = last_fail,
		layout_y0 = layout and layout.row0_y,
		layout_y1 = layout and layout.row1_y,
	}
end

-- Silence unused lint for piece_defs name helper if any.
local _ = piece_defs.KIND

return ctrl
