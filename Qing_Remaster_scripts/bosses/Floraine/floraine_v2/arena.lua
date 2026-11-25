-- Floraine Arena: room entry, doors, spawn anchors. No attack selection.
-- Door policy: INTRO (return Opened) → CLOSING (Close anim) → SEALED → CLEARED (post-defeat Opened).

local enums = require("Qing_Remaster_scripts.core.enums")
local stone_defs = require("Qing_Remaster_scripts.threads.stone.stone_defs")
local runtime = require("Qing_Remaster_scripts.threads.stone.stone_runtime")
local rooms = require("Qing_Remaster_scripts.threads.stone.stone_rooms")
local grid_door = require("Qing_Remaster_scripts.grids.grid_doors")
local door_arrival = require("Qing_Remaster_scripts.threads.stone.stone_door_arrival")
local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")

local arena = {}

local door_state = defs.DOOR.INTRO
local close_job = nil -- { phase, elapsed, close_started }

local function door_anm2()
	return stone_defs.DOOR_ANM2
end

function arena.get_door_state()
	return door_state
end

function arena.is_arena_room(desc)
	desc = desc or Game():GetLevel():GetCurrentRoomDesc()
	return rooms.is_floraine_room(desc)
end

--- Debug-only fallback near DOWN0. Normal play uses stone_door_arrival pending transfer.
--- Never uses FLORAINE_ENTRY (Boss marker).
function arena.player_spawn_pos()
	local marker = rooms.find_marker(stone_defs.MARKER.PLAYER_ENTRY)
	if marker then
		return marker.Position
	end
	local pos = select(1, door_arrival.resolve_arrival_pos(DoorSlot.DOWN0))
	if pos then
		return pos
	end
	local room = Game():GetRoom()
	return room:GetClampedPosition(room:GetCenterPos() + Vector(0, room:GetGridHeight() * 10), 20)
end

--- Top playable row + one grid down, horizontal center. Slightly elevated via home.
function arena.boss_home_grid_pos()
	local room = Game():GetRoom()
	local tl = room:GetTopLeftPos()
	local br = room:GetBottomRightPos()
	local grid = 40
	-- First standable row under the top wall, then one cell further down.
	local y = tl.Y + grid * 1.5
	local x = (tl.X + br.X) * 0.5
	return room:GetClampedPosition(Vector(x, y), 20)
end

--- Snap any raw world point to its grid-cell center (stable Home identity).
local function snap_boss_home(raw)
	local room = Game():GetRoom()
	if not raw then
		return arena.boss_home_grid_pos()
	end
	local idx = room:GetGridIndex(raw)
	if idx ~= nil and idx >= 0 then
		local p = room:GetGridPosition(idx)
		return Vector(p.X, p.Y)
	end
	return room:GetClampedPosition(raw, 20)
end

--- Canonical Boss Home: fixed top-grid rule only (no FLORAINE_ENTRY Marker).
--- Room XML may still contain the marker as unused layout leftover.
function arena.resolve_boss_home()
	return snap_boss_home(arena.boss_home_grid_pos())
end

function arena.boss_spawn_pos()
	return arena.resolve_boss_home()
end

--- World point fully left of the current camera (sprite half-width + pad).
function arena.world_offscreen_left(target_y, sprite_half, pad)
	sprite_half = sprite_half or 24
	pad = pad or 8
	local room = Game():GetRoom()
	local x = room:GetTopLeftPos().X
	for _ = 1, 48 do
		local scr = Isaac.WorldToScreen(Vector(x, target_y))
		if scr.X < -(sprite_half + pad) then
			return Vector(x, target_y)
		end
		x = x - 40
	end
	return Vector(x, target_y)
end

--- World point fully right of the current camera.
function arena.world_offscreen_right(target_y, sprite_half, pad)
	sprite_half = sprite_half or 24
	pad = pad or 8
	local room = Game():GetRoom()
	local x = room:GetBottomRightPos().X
	local limit = Isaac.GetScreenWidth() + sprite_half + pad
	for _ = 1, 48 do
		local scr = Isaac.WorldToScreen(Vector(x, target_y))
		if scr.X > limit then
			return Vector(x, target_y)
		end
		x = x + 40
	end
	return Vector(x, target_y)
end

--- World point fully above the current camera (sprite top extent).
function arena.world_offscreen_above(target_x, sprite_extent, pad)
	sprite_extent = sprite_extent or 48
	pad = pad or 8
	local room = Game():GetRoom()
	local y = room:GetTopLeftPos().Y
	for _ = 1, 48 do
		local scr = Isaac.WorldToScreen(Vector(target_x, y))
		if scr.Y < -(sprite_extent + pad) then
			return Vector(target_x, y)
		end
		y = y - 40
	end
	return Vector(target_x, y)
end

--- World point fully below the current camera (sprite top must clear bottom edge).
function arena.world_offscreen_below(target_x, sprite_extent, pad)
	sprite_extent = sprite_extent or 8
	pad = pad or 8
	local room = Game():GetRoom()
	local y = room:GetBottomRightPos().Y
	local limit = Isaac.GetScreenHeight() + pad
	for _ = 1, 64 do
		-- Treat (x,y) as the visual top of the piece.
		local scr = Isaac.WorldToScreen(Vector(target_x, y))
		if scr.Y > limit then
			return Vector(target_x, y + sprite_extent)
		end
		y = y + 40
	end
	return Vector(target_x, y)
end

--- True when the full sprite (approx AABB) is below the screen bottom.
function arena.is_sprite_fully_below_screen(ground, visual_height, half_w, top_extent)
	if not ground then
		return true
	end
	half_w = half_w or 24
	top_extent = top_extent or 48
	local h = visual_height or 0
	-- Pivot ≈ feet; top of art sits above pivot by top_extent, minus lift.
	local top_y = ground.Y - h - top_extent
	local limit = Isaac.GetScreenHeight() + 2
	local samples = {
		Vector(ground.X - half_w, top_y),
		Vector(ground.X, top_y),
		Vector(ground.X + half_w, top_y),
	}
	for i = 1, #samples do
		local scr = Isaac.WorldToScreen(samples[i])
		if scr.Y <= limit then
			return false
		end
	end
	return true
end

local function is_walkable_grid(room, index)
	if index == nil or index < 0 then
		return false
	end
	local col = room:GetGridCollision(index)
	return col == GridCollisionClass.COLLISION_NONE
end

--- Scan outermost walkable floor columns (no artificial wall padding).
local function p2_outer_columns(room)
	local width = room:GetGridWidth()
	local height = room:GetGridHeight()
	local min_x, max_x = nil, nil
	for y = 0, height - 1 do
		for x = 0, width - 1 do
			local idx = y * width + x
			if is_walkable_grid(room, idx) then
				if min_x == nil or x < min_x then
					min_x = x
				end
				if max_x == nil or x > max_x then
					max_x = x
				end
			end
		end
	end
	return min_x, max_x, width, height
end

--- Sample a stable world X for a grid column (mid-height walkable cell).
local function column_world_x(room, col, width, height)
	local mid_y = math.floor(height / 2)
	for dy = 0, height do
		for _, y in ipairs({ mid_y + dy, mid_y - dy }) do
			if y >= 0 and y < height then
				local idx = y * width + col
				if is_walkable_grid(room, idx) then
					return room:GetGridPosition(idx).X
				end
			end
		end
	end
	local mid = math.floor(height / 2) * width + col
	return room:GetGridPosition(mid).X
end

--- Left / right outermost BAND_WIDTH walkable grid columns (outer→inward).
--- Returns left_cols[], right_cols[] of grid X indices.
function arena.p2_side_band_cols(band_width)
	band_width = math.max(1, math.floor(tonumber(band_width) or 3))
	local room = Game():GetRoom()
	local min_x, max_x, width, height = p2_outer_columns(room)
	local left, right = {}, {}
	if min_x == nil or max_x == nil then
		return left, right
	end
	for i = 0, band_width - 1 do
		local lc = min_x + i
		local rc = max_x - i
		if lc <= max_x then
			left[#left + 1] = lc
		end
		if rc >= min_x and (rc ~= lc or #right == 0) then
			-- Avoid duplicating the same col on both sides in tiny rooms.
			local dup = false
			for _, c in ipairs(left) do
				if c == rc then dup = true break end
			end
			if not dup then
				right[#right + 1] = rc
			end
		end
	end
	return left, right, width, height
end

--- Per-row layout for P2: each walkable Y with left/right candidate cells in the side bands.
--- Entry: { y_grid, y_world, left={{col,pos},...}, right={{col,pos},...} }
function arena.p2_row_layout(band_width)
	local room = Game():GetRoom()
	local left_cols, right_cols, width, height = arena.p2_side_band_cols(band_width)
	local rows = {}
	if not width or #left_cols < 1 then
		return rows
	end
	-- Union of Y rows that have any walkable cell in either band.
	local y_seen = {}
	local y_list = {}
	local function consider(col)
		for y = 0, height - 1 do
			local idx = y * width + col
			if is_walkable_grid(room, idx) and not y_seen[y] then
				y_seen[y] = true
				y_list[#y_list + 1] = y
			end
		end
	end
	for _, c in ipairs(left_cols) do consider(c) end
	for _, c in ipairs(right_cols) do consider(c) end
	table.sort(y_list)
	for _, y in ipairs(y_list) do
		local left_opts, right_opts = {}, {}
		for _, c in ipairs(left_cols) do
			local idx = y * width + c
			if is_walkable_grid(room, idx) then
				local p = room:GetGridPosition(idx)
				left_opts[#left_opts + 1] = { col = c, pos = Vector(p.X, p.Y) }
			end
		end
		for _, c in ipairs(right_cols) do
			local idx = y * width + c
			if is_walkable_grid(room, idx) then
				local p = room:GetGridPosition(idx)
				right_opts[#right_opts + 1] = { col = c, pos = Vector(p.X, p.Y) }
			end
		end
		if #left_opts >= 1 and #right_opts >= 1 then
			local sample = left_opts[1].pos
			rows[#rows + 1] = {
				y_grid = y,
				y_world = sample.Y,
				left = left_opts,
				right = right_opts,
			}
		end
	end
	return rows
end

--- LEGACY: outermost left/right wall-edge X only (single column). Prefer p2_row_layout.
function arena.p2_column_grid_xs()
	local room = Game():GetRoom()
	local min_x, max_x, width, height = p2_outer_columns(room)
	if min_x == nil or max_x == nil then
		local tl = room:GetTopLeftPos()
		local br = room:GetBottomRightPos()
		local grid = 40
		return tl.X + grid * 0.5, br.X - grid * 0.5
	end
	return column_world_x(room, min_x, width, height), column_world_x(room, max_x, width, height)
end

--- LEGACY: full-height row Y list on left outer column. Prefer p2_row_layout.
function arena.p2_column_row_ys()
	local layout = arena.p2_row_layout(1)
	local rows = {}
	for i = 1, #layout do
		rows[i] = layout[i].y_world
	end
	if #rows < 3 then
		local room = Game():GetRoom()
		local tl = room:GetTopLeftPos()
		local br = room:GetBottomRightPos()
		local grid = 40
		local y = tl.Y + grid * 0.5
		rows = {}
		while y <= br.Y - grid * 0.5 + 0.5 do
			local pos = room:GetClampedPosition(Vector(room:GetCenterPos().X, y), 0)
			rows[#rows + 1] = pos.Y
			y = y + grid
		end
		if #rows < 3 then
			local mid = room:GetCenterPos().Y
			rows = { mid - grid, mid, mid + grid }
		end
	end
	return rows
end

--- Resolve nearest walkable grid cell near world pos (for stray demote / march).
function arena.nearest_walkable(pos, max_radius)
	if not pos then
		return nil
	end
	local room = Game():GetRoom()
	max_radius = max_radius or 3
	local origin = room:GetGridIndex(pos)
	if origin >= 0 and is_walkable_grid(room, origin) then
		local p = room:GetGridPosition(origin)
		return Vector(p.X, p.Y), origin
	end
	local width = room:GetGridWidth()
	local height = room:GetGridHeight()
	local ox = origin % width
	local oy = math.floor(origin / width)
	for r = 1, max_radius do
		for dy = -r, r do
			for dx = -r, r do
				if math.abs(dx) == r or math.abs(dy) == r then
					local x, y = ox + dx, oy + dy
					if x >= 0 and x < width and y >= 0 and y < height then
						local idx = y * width + x
						if is_walkable_grid(room, idx) then
							local p = room:GetGridPosition(idx)
							return Vector(p.X, p.Y), idx
						end
					end
				end
			end
		end
	end
	return nil
end

--- One grid-step below pos (walkable). Returns nil if none within search.
function arena.step_down_walkable(pos)
	if not pos then
		return nil
	end
	local room = Game():GetRoom()
	local grid = 40
	local try = Vector(pos.X, pos.Y + grid)
	local found = arena.nearest_walkable(try, 2)
	if found and found.Y > pos.Y + 8 then
		return found
	end
	-- Prefer exact same X column one row down.
	local width = room:GetGridWidth()
	local idx = room:GetGridIndex(pos)
	if idx >= 0 then
		local x = idx % width
		local y = math.floor(idx / width) + 1
		local height = room:GetGridHeight()
		for yy = y, math.min(height - 1, y + 3) do
			local i2 = yy * width + x
			if is_walkable_grid(room, i2) then
				local p = room:GetGridPosition(i2)
				return Vector(p.X, p.Y)
			end
		end
	end
	return found
end

function arena.unlock_spawn_pos()
	local marker = rooms.find_marker(stone_defs.MARKER.CENTER)
	if marker then return marker.Position end
	return Game():GetRoom():GetCenterPos()
end

--- Debug / Story Test only. Normal door entry must not call this.
function arena.place_players_debug()
	local pos = arena.player_spawn_pos()
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if p then
			p.Position = pos
			p.Velocity = Vector.Zero
		end
	end
end

-- LEGACY alias kept for older debug callers.
function arena.place_players()
	arena.place_players_debug()
end

local function find_down_door_info()
	local room = Game():GetRoom()
	local idx = room:GetGridIndex(room:GetDoorSlotPosition(DoorSlot.DOWN0))
	for _, v in ipairs(grid_door.doors or {}) do
		if v.idx == idx then
			return v, room:GetGridEntity(idx)
		end
	end
	return nil, room:GetGridEntity(idx)
end

local function players_clear_of_down_door()
	local room = Game():GetRoom()
	local door_pos = room:GetDoorSlotPosition(DoorSlot.DOWN0)
	local min_d = 48
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if p and p:Exists() and not p:IsDead() then
			if (p.Position - door_pos):Length() < min_d then
				return false
			end
		end
	end
	return true
end

local function disable_leave_only(info)
	if info then
		info.targ = function() end
	end
end

local function begin_close_anim()
	local info, door = find_down_door_info()
	if not info or not door then
		-- No managed door: fall back to hard seal.
		door_state = defs.DOOR.SEALED
		close_job = nil
		return false
	end
	disable_leave_only(info)
	info.should_update = true
	info.on_update = function(doorinfo)
		local d = doorinfo.door
		if not d then
			return
		end
		local s = d:GetSprite()
		if s:GetAnimation() == "Close" and s:IsFinished("Close") then
			s:Play("Closed", true)
			d.CollisionClass = GridCollisionClass.COLLISION_WALL
			doorinfo.should_update = false
			door_state = defs.DOOR.SEALED
			close_job = nil
		end
	end
	local s = door:GetSprite()
	s:Play("Close", true)
	door.CollisionClass = GridCollisionClass.COLLISION_WALL
	if close_job then
		close_job.close_started = true
		close_job.phase = "closing"
	end
	return true
end

local function remove_all_doors()
	local room = Game():GetRoom()
	for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
		if room:GetDoor(slot) then
			room:RemoveDoor(slot)
		end
	end
	-- Drop managed teleports so stale leave handlers cannot fire.
	local list = grid_door.doors
	if type(list) == "table" then
		for i = #list, 1, -1 do
			local v = list[i]
			if v then
				v.targ = nil
				v.should_kill_me = true
			end
		end
	end
end

local function spawn_return_door()
	local r = runtime.get()
	if not r.hidden then return end
	remove_all_doors()
	close_job = nil
	local room = Game():GetRoom()
	local leave = door_arrival.wrap_leave(
		"FLORAINE_TO_ANTE",
		stone_defs.goto_default(r.hidden.ante_variant),
		{
			source_door_slot = DoorSlot.DOWN0,
			expect_variant = r.hidden.ante_variant,
		}
	)
	grid_door.try_spawn_grid_door(room, DoorSlot.DOWN0, nil, {
		check_and_leave = leave,
		loadname = door_anm2(),
		playname = "Opened",
		should_update = false,
		tp = RoomType.ROOM_DEFAULT,
		_stone_style = stone_defs.DOOR_STYLE.ROUTE_GATE,
	})
end

--- Begin sealing: wait for player clear, then play real Close (do not RemoveDoor).
function arena.seal_combat_doors()
	if door_state == defs.DOOR.SEALED or door_state == defs.DOOR.CLOSING then
		return
	end
	door_state = defs.DOOR.CLOSING
	close_job = {
		phase = "wait_clear",
		elapsed = 0,
		close_started = false,
	}
	-- Immediately disable leave (logic seal), anim waits for clear.
	local info = select(1, find_down_door_info())
	disable_leave_only(info)
	local ok, ante = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.ante_formation")
	if ok and ante and ante.clear then
		ante.clear("arena_sealed")
	end
end

-- LEGACY name: now seals (no mid-fight retreat). Prefer seal_combat_doors.
function arena.close_combat_doors()
	arena.seal_combat_doors()
end

--- Advance CLOSING. Call once per Boss logic frame.
function arena.tick()
	if door_state ~= defs.DOOR.CLOSING or not close_job then
		return
	end
	close_job.elapsed = (close_job.elapsed or 0) + 1
	if close_job.phase == "wait_clear" then
		if players_clear_of_down_door() or close_job.elapsed >= 45 then
			begin_close_anim()
		end
		return
	end
	-- closing: on_update on grid_door advances sprite; safety force Closed.
	if close_job.close_started and close_job.elapsed >= 90 then
		local info, door = find_down_door_info()
		if door then
			door:GetSprite():Play("Closed", true)
			door.CollisionClass = GridCollisionClass.COLLISION_WALL
		end
		if info then
			info.should_update = false
			info.targ = function() end
		end
		door_state = defs.DOOR.SEALED
		close_job = nil
	end
end

function arena.open_return_door()
	spawn_return_door()
	door_state = defs.DOOR.CLEARED
end

function arena.spawn_intro_door()
	spawn_return_door()
	door_state = defs.DOOR.INTRO
	close_job = nil
end

--- Debug: force Floraine-room DOWN0 anim (Close / Closed / Opened).
function arena.debug_door_anim(anim)
	anim = tostring(anim or "Close")
	local info, door = find_down_door_info()
	if not door then
		return false, "no_door"
	end
	local s = door:GetSprite()
	s:Play(anim, true)
	if info then
		info.should_update = anim ~= "Opened" and anim ~= "Closed"
		if anim == "Close" or anim == "Closed" then
			info.targ = function() end
			door.CollisionClass = GridCollisionClass.COLLISION_WALL
			if anim == "Close" then
				info.on_update = function(doorinfo)
					local d = doorinfo.door
					if d and d:GetSprite():IsFinished("Close") then
						d:GetSprite():Play("Closed", true)
						d.CollisionClass = GridCollisionClass.COLLISION_WALL
						doorinfo.should_update = false
						door_state = defs.DOOR.SEALED
					end
				end
				door_state = defs.DOOR.CLOSING
			else
				door_state = defs.DOOR.SEALED
			end
		elseif anim == "Opened" or anim == "Open" then
			door.CollisionClass = GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER
			door_state = defs.DOOR.INTRO
		end
	end
	return true, anim
end

function arena.get_close_diag()
	return {
		door_state = door_state,
		close_job = close_job and {
			phase = close_job.phase,
			elapsed = close_job.elapsed,
			close_started = close_job.close_started == true,
		} or nil,
	}
end

--- Enter Floraine room: apply pending door arrival (if any), ensure return door, hand off.
function arena.on_enter()
	runtime.normalize_floraine_variant()
	runtime.advance_phase(stone_defs.PHASE.BOSS_ENTERED, "enter_floraine_v2")
	door_arrival.apply_if_pending()
	arena.spawn_intro_door()
	local controller = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.controller")
	controller.on_arena_enter()
end

function arena.on_leave()
	close_job = nil
	local controller = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.controller")
	controller.on_arena_leave()
	local ok, reserve = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_controller")
	if ok and reserve and reserve.clear then
		reserve.clear("arena_leave")
	end
	local ok_d, deployment = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.deployment")
	if ok_d and deployment and deployment.cancel_all then
		deployment.cancel_all("arena_leave")
	end
end

-- Silence unused if enums not needed at load.
local _ = enums.Enemies

return arena
