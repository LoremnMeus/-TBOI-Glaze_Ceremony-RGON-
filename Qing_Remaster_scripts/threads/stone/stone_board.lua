-- Chessboard floor fill + Manhattan door-origin expand (per-cell Smoothstep fade).
-- Draw: per-cell Sprite overlay routed by terrain ownership
--   EMPTY  → Stone Board Overlay Effect (all floor cells without blocking Grid)
--   GRID_PRE → Rock/Poop/Spikes/Door/… PRE_RENDER (board under obstacle)
--   PIT_POST → Pit POST_RENDER (board over abyss, visual only)
-- V3.3: one shared render frame context (visibility + ownership verify + colors + sprite).
-- Not FLAG_RENDER_FLOOR stamps. Not MC_POST_RENDER for production.
-- See codex_work/notes/ff_floor_render_path.md.

local enums = require("Qing_Remaster_scripts.core.enums")
local runtime = require("Qing_Remaster_scripts.threads.stone.stone_runtime")
local route = require("Qing_Remaster_scripts.threads.stone.stone_route")
local board_perf = require("Qing_Remaster_scripts.threads.stone.stone_board_perf")

local board = {}

local CELL = 40
local FILL_ANM2 = "gfx/effects/chess/fill_tile.anm2"
local OVERLAY_DATA = "QingStoneBoardOverlay"
-- fill_tile.png / ANM2 = 48×48 full alpha (verified). Sprite:Render ≠ world px 1:1.
-- In-game seam check locked production to 2/3 of 40/48 (≈0.5556).
local ANM2_PX = 48
local TILE_SCALE_DEFAULT = CELL / ANM2_PX * (2 / 3) -- ≈ 0.5556
local tile_scale = TILE_SCALE_DEFAULT

-- Manhattan ring expand: adjacent ring delay + per-cell Smoothstep fade (30Hz Game frames).
local FRAMES_PER_RING = 4
local FADE_FRAMES = 12

local OWNER = {
	SKIP = "SKIP",
	EMPTY = "EMPTY_HELPER",
	GRID_PRE = "GRID_PRE",
	PIT_POST = "GRID_PIT_POST",
}

local expand = {
	active = false,
	origin = nil,
	origin_index = nil,
	normal = nil,
	slot = nil,
	start_frame = 0,
	duration = 0,
	max_manhattan = 0,
	why = nil,
}

local tile_sprite = nil
-- Optional render probe hook (set only while stone_render_probe is enabled).
local render_probe = nil

-- Room-level ownership cache + per-render visibility (Stone Board Render V3).
local owner_cache = {
	list_index = -1,
	grid_size = 0,
	grid_width = 0,
	shape = nil,
	by_index = nil,
	version = 0,
	dirty = true,
	rebuilds = 0,
	reclassifications = 0,
}

-- Cull modes (V3.1): never use ScreenToWorld corner → GetGridIndex as the sole bounds source.
local CULL_MODE = {
	FULL = "full", -- no culling (correctness baseline)
	PROJECTION = "projection", -- Zeis-style WorldToScreen per cell
	OPTIMIZED = "optimized", -- coarse candidates + projection refine
}

local cull_mode = CULL_MODE.OPTIMIZED

local visible_cache = {
	render_serial = -1,
	focus_x = nil,
	focus_y = nil,
	sw = 0,
	sh = 0,
	mode = nil,
	min_col = 0,
	max_col = 0,
	min_row = 0,
	max_row = 0,
	indices = nil,
	count = 0,
}

local render_perf = {
	total_cells = 0,
	visible_cells = 0,
	culled_cells = 0,
	render_calls = 0,
	owner_rebuilds = 0,
	owner_reclassifications = 0,
	world_to_screen_calls = 0,
}

-- V3.3: one shared render context per Isaac render frame (Isaac.GetFrameCount).
local frame_ctx = {
	key = nil,
	value = nil,
	owner_version = -1,
}

local function current_render_frame_key()
	-- Prefer RGON/render clock (~60Hz). Game():GetFrameCount is 30Hz logic and can
	-- alias multiple PRE/POST Grid draws into one key incorrectly under pause/interpolation.
	if Isaac.GetFrameCount then
		return Isaac.GetFrameCount()
	end
	return Game():GetFrameCount()
end

local function invalidate_frame_ctx()
	frame_ctx.key = nil
	frame_ctx.value = nil
	frame_ctx.owner_version = -1
end

local function resolve_tile_scale()
	local P = render_probe
	if P and type(P.tile_scale) == "number" and P.tile_scale > 0 then
		return P.tile_scale
	end
	return tile_scale
end

local function apply_tile_scale(spr)
	local s = resolve_tile_scale()
	spr.Scale = Vector(s, s)
	return s
end

local function ensure_tile_sprite()
	if not tile_sprite then
		tile_sprite = Sprite()
		tile_sprite:Load(FILL_ANM2, true)
		tile_sprite:Play("Idle", true)
	end
	apply_tile_scale(tile_sprite)
	return tile_sprite
end

--- Production / probe tile Scale (Sprite screen space). Default = 40/48×2/3.
function board.get_tile_scale()
	return resolve_tile_scale()
end

function board.set_tile_scale(scale)
	local s = tonumber(scale)
	if not s or s <= 0 then
		return board.get_tile_scale()
	end
	tile_scale = s
	if tile_sprite then
		apply_tile_scale(tile_sprite)
	end
	return tile_scale
end

function board.get_tile_scale_presets()
	-- Relative to naive 40/48: 100% / 80% / 67% (production) / 50%.
	local base = CELL / ANM2_PX
	return {
		s100 = base, -- 0.8333 — old overlapping
		s80 = base * 0.8, -- 0.6667
		s67 = base * (2 / 3), -- 0.5556 — production (verified seam)
		s50 = base * 0.5, -- 0.4167
		default = TILE_SCALE_DEFAULT,
		anm2_px = ANM2_PX,
		cell = CELL,
	}
end

--- Probe-only. Pass nil to detach. Not part of gameplay API.
function board.set_render_probe(hook)
	render_probe = hook
	if tile_sprite then
		apply_tile_scale(tile_sprite)
	end
end

function board.is_active()
	return runtime.is_board_active()
end

function board.is_current_room_on_floor()
	return runtime.has_layout() and runtime.floor_matches()
end

function board.door_inward_normal(slot)
	if slot == DoorSlot.LEFT0 or slot == DoorSlot.LEFT1 then
		return Vector(1, 0)
	elseif slot == DoorSlot.RIGHT0 or slot == DoorSlot.RIGHT1 then
		return Vector(-1, 0)
	elseif slot == DoorSlot.UP0 or slot == DoorSlot.UP1 then
		return Vector(0, 1)
	elseif slot == DoorSlot.DOWN0 or slot == DoorSlot.DOWN1 then
		return Vector(0, -1)
	end
	return Vector(0, 1)
end

--- Door mouth position + inward inset (matches encounter spawn side).
function board.resolve_door_origin(slot)
	local room = Game():GetRoom()
	local why = "ok"
	if slot == nil then
		return room:GetCenterPos(), Vector(0, 1), nil, "missing_outgoing_slot"
	end
	local door = room:GetDoor(slot)
	local pos
	if door then
		pos = door.Position
	else
		why = "door_missing_fallback"
		local center = room:GetCenterPos()
		local tl = room:GetTopLeftPos()
		local br = room:GetBottomRightPos()
		if slot == DoorSlot.LEFT0 or slot == DoorSlot.LEFT1 then
			pos = Vector(tl.X + 20, center.Y)
		elseif slot == DoorSlot.RIGHT0 or slot == DoorSlot.RIGHT1 then
			pos = Vector(br.X - 20, center.Y)
		elseif slot == DoorSlot.UP0 or slot == DoorSlot.UP1 then
			pos = Vector(center.X, tl.Y + 20)
		else
			pos = Vector(center.X, br.Y - 20)
		end
	end
	local n = board.door_inward_normal(slot)
	local origin = room:GetClampedPosition(pos + n * 24, 16)
	return origin, n, slot, why
end

local function grid_xy(index, width)
	return index % width, math.floor(index / width)
end

local function manhattan_cells(a, b, width)
	local ax, ay = grid_xy(a, width)
	local bx, by = grid_xy(b, width)
	return math.abs(ax - bx) + math.abs(ay - by)
end

local function resolve_origin_index(world)
	local room = Game():GetRoom()
	local idx = room:GetGridIndex(world)
	if room:IsPositionInRoom(room:GetGridPosition(idx), 0) then
		return idx
	end
	-- Nearest in-room cell (door inset can sit on wall collision).
	local best_idx, best_d = idx, math.huge
	local size = room:GetGridSize()
	for i = 0, size - 1 do
		local pos = room:GetGridPosition(i)
		if room:IsPositionInRoom(pos, 0) then
			local d = (pos.X - world.X) * (pos.X - world.X) + (pos.Y - world.Y) * (pos.Y - world.Y)
			if d < best_d then
				best_d = d
				best_idx = i
			end
		end
	end
	return best_idx
end

local function compute_max_manhattan(origin_index)
	local room = Game():GetRoom()
	local width = room:GetGridWidth()
	local best = 0
	for i = 0, room:GetGridSize() - 1 do
		local world = room:GetGridPosition(i)
		if room:IsPositionInRoom(world, 0) then
			local d = manhattan_cells(i, origin_index, width)
			if d > best then
				best = d
			end
		end
	end
	return best
end

local function hydrate_expand_metrics()
	if not expand.origin then
		expand.origin_index = nil
		expand.max_manhattan = 0
		expand.duration = 0
		return
	end
	expand.origin_index = resolve_origin_index(expand.origin)
	expand.max_manhattan = compute_max_manhattan(expand.origin_index)
	expand.duration = expand.max_manhattan * FRAMES_PER_RING + FADE_FRAMES
end

local function persist_expand()
	local r = runtime.get()
	r.board = r.board or {}
	if expand.origin then
		r.board.expand_origin = {x = expand.origin.X, y = expand.origin.Y}
	end
	if expand.normal then
		r.board.expand_normal = {x = expand.normal.X, y = expand.normal.Y}
	end
	r.board.expand_slot = expand.slot
	r.board.expand_start_frame = expand.start_frame
	r.board.expand_why = expand.why
	r.board.expand_origin_index = expand.origin_index
	r.board.expand_max_manhattan = expand.max_manhattan
	r.board.expand_complete = not expand.active
end

--- Official expand: Manhattan rings from door-inward origin cell.
function board.begin_expand_from_door(slot, frame)
	local origin, normal, resolved_slot, why = board.resolve_door_origin(slot)
	expand.active = true
	expand.origin = origin
	expand.normal = normal
	expand.slot = resolved_slot
	expand.why = why
	expand.start_frame = frame or Game():GetFrameCount()
	hydrate_expand_metrics()
	persist_expand()
	local r = runtime.get()
	r.board.expand_complete = false
	return why == "ok" or why == "door_missing_fallback", why
end

--- Legacy / debug: still door-origin when slot known; otherwise records missing.
function board.begin_expand(origin_ignored, frame)
	local slot = route.get_outgoing_slot()
	return board.begin_expand_from_door(slot, frame)
end

function board.clear_expand()
	expand.active = false
	expand.origin = nil
	expand.origin_index = nil
	expand.normal = nil
	expand.slot = nil
	expand.why = nil
	expand.max_manhattan = 0
	expand.duration = 0
end

-- LEGACY-SAVE-004: room_expand / prior expand_origin → once-per-activation expand_complete.
local function migrate_expand_flags(r)
	if not r.board or not r.board.activated then
		return
	end
	if r.board.expand_complete == true then
		return
	end
	local had_room = r.board.room_expand and next(r.board.room_expand) ~= nil
	if had_room or r.board.expand_origin ~= nil or r.board.expand_start_frame ~= nil then
		r.board.expand_complete = true
	end
end

local function hydrate_expand_inactive_from_run(r)
	if r.board.expand_origin then
		expand.origin = Vector(r.board.expand_origin.x, r.board.expand_origin.y)
		if r.board.expand_normal then
			expand.normal = Vector(r.board.expand_normal.x, r.board.expand_normal.y)
		else
			expand.normal = Vector(0, 1)
		end
		expand.slot = r.board.expand_slot
		expand.why = r.board.expand_why
	else
		local desc = Game():GetLevel():GetCurrentRoomDesc()
		local slot = route.get_outgoing_slot(desc) or r.board.expand_slot
		local origin, normal, resolved_slot = board.resolve_door_origin(slot)
		expand.origin = origin
		expand.normal = normal
		expand.slot = resolved_slot or slot
	end
	hydrate_expand_metrics()
	expand.active = false
end

--- Once per board activation: play Manhattan expand, then keep full board forever.
--- room_expand is legacy-only (LEGACY-SAVE-004); it must not drive replay.
function board.restore_expand_from_run()
	local r = runtime.get()
	if not r.board or not r.board.activated then
		board.clear_expand()
		return
	end
	migrate_expand_flags(r)

	if r.board.expand_complete == true then
		hydrate_expand_inactive_from_run(r)
		return
	end

	-- Left mid-animation, Continue mid-anim, or any prior start → never replay.
	if expand.active or r.board.expand_origin ~= nil or r.board.expand_start_frame ~= nil then
		r.board.expand_complete = true
		hydrate_expand_inactive_from_run(r)
		persist_expand()
		return
	end

	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if route.is_route_room(desc) or route.is_trigger_room(desc) then
		board.begin_expand_from_door(route.get_outgoing_slot(desc), Game():GetFrameCount())
	end
end

function board.set_expand_progress(percent)
	percent = math.max(0, math.min(100, tonumber(percent) or 100))
	if not expand.origin then
		board.begin_expand_from_door(route.get_outgoing_slot(), Game():GetFrameCount())
	end
	if expand.duration <= 0 then
		hydrate_expand_metrics()
	end
	if percent >= 100 then
		expand.active = false
		local r = runtime.get()
		if r.board then r.board.expand_complete = true end
		persist_expand()
		return
	end
	expand.active = true
	local r = runtime.get()
	if r.board then r.board.expand_complete = false end
	local dur = math.max(1, expand.duration)
	expand.start_frame = Game():GetFrameCount() - math.floor(dur * (percent / 100))
end

--- Legacy hook.
function board.start_(_pos)
end

local function probe_force()
	local P = render_probe
	return P and (P.force_full_board == true or P.magenta_tile == true or P.grid_routing_test == true)
end

local function smoothstep01(t)
	t = math.max(0, math.min(1, t))
	return t * t * (3 - 2 * t)
end

--- Advance expand_complete on the 30Hz game Update clock (not Render).
function board.tick_expand()
	if not expand.active then
		return
	end
	local dur = expand.duration or 0
	if dur <= 0 then
		return
	end
	if Game():GetFrameCount() - expand.start_frame >= dur then
		expand.active = false
		local r = runtime.get()
		if r.board then
			r.board.expand_complete = true
		end
		persist_expand()
	end
end

--- Per-cell reveal alpha in [0,1]. Applies to EMPTY / GRID_PRE / PIT_POST.
function board.cell_reveal_alpha(index)
	if probe_force() then
		return 1
	end
	if not expand.active then
		return 1
	end
	local dur = expand.duration or 0
	if dur > 0 and Game():GetFrameCount() - expand.start_frame >= dur then
		return 1
	end
	local origin_index = expand.origin_index
	if origin_index == nil then
		return 1
	end
	local room = Game():GetRoom()
	local width = room:GetGridWidth()
	local d = manhattan_cells(index, origin_index, width)
	local delay = d * FRAMES_PER_RING
	local elapsed = Game():GetFrameCount() - expand.start_frame - delay
	if elapsed <= 0 then
		return 0
	end
	return smoothstep01(elapsed / FADE_FRAMES)
end

local function kcolor_to_sprite_color(kc, alpha_mul)
	local r = kc.R or kc.Red or 1
	local g = kc.G or kc.Green or 1
	local b = kc.B or kc.Blue or 1
	local a = kc.A or kc.Alpha or 1
	alpha_mul = alpha_mul or 1
	return Color(r, g, b, a * alpha_mul, 0, 0, 0)
end

--- True when activate succeeded but expand never persisted (interrupted bootstrap).
function board.needs_expand_bootstrap()
	local r = runtime.get()
	if not r.board or not r.board.activated then
		return false
	end
	if r.board.bootstrap_complete == true then
		return false
	end
	if r.board.expand_complete == true then
		return false
	end
	return r.board.expand_origin == nil
end

--- Complete expand after interrupted activate (does not re-shatter the pawn).
function board.ensure_bootstrap_from_activation()
	local r = runtime.get()
	if not r.board or not r.board.activated then
		return false, "inactive"
	end
	if not board.needs_expand_bootstrap() and r.board.expand_origin then
		r.board.bootstrap_complete = true
		return false, "already"
	end
	local slot = route.get_outgoing_slot() or r.board.expand_slot
	local ok, why = board.begin_expand_from_door(slot, Game():GetFrameCount())
	r.board.bootstrap_complete = true
	return ok, why or "bootstrapped"
end

function board.mark_bootstrap_complete()
	local r = runtime.get()
	if r.board then
		r.board.bootstrap_complete = true
	end
end

local function resolve_gate()
	local active = board.is_active()
	local on_floor = board.is_current_room_on_floor()
	local has_layout = runtime.has_layout()
	local floor_ok = runtime.floor_matches()
	local force = probe_force()
	local fail = "none"
	if not active and not force then
		fail = "not_active"
	elseif not on_floor and not force then
		fail = "room_gate"
	end
	return {
		board_active = active,
		has_layout = has_layout,
		floor_matches = floor_ok,
		is_current_room_on_floor = on_floor,
		fail_reason = fail,
		force = force == true,
	}
end

local function is_wall_collision(coll)
	return coll == GridCollisionClass.COLLISION_WALL
		or coll == GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER
end

local function classify_grid_entity(ge)
	if not ge then
		return OWNER.EMPTY
	end
	local t = ge:GetType()
	if t == GridEntityType.GRID_PIT then
		return OWNER.PIT_POST
	end
	if t == GridEntityType.GRID_WALL then
		return OWNER.SKIP
	end
	-- Obstacles / doors / fixtures: board drawn under them via PRE_RENDER.
	return OWNER.GRID_PRE
end

local function lerp3(a, b, t)
	return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
end

-- Route palette: neutral entry → cool blue along path; terminal is separate warm red.
local PALETTE = {
	neutral_dark = {0.08, 0.08, 0.1},
	neutral_light = {0.88, 0.88, 0.9},
	blue_dark = {0.1, 0.12, 0.22},
	blue_light = {0.78, 0.82, 0.95},
	terminal_dark = {0.28, 0.11, 0.12},
	terminal_light = {0.86, 0.58, 0.46},
}

local function route_blue_weight(progress)
	progress = math.max(0, math.min(1, tonumber(progress) or 0))
	local keys = {
		{0.00, 0.00},
		{0.25, 0.20},
		{0.50, 0.35},
		{0.75, 0.50},
		{1.00, 0.65},
	}
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if progress <= b[1] then
			local span = b[1] - a[1]
			local u = span > 0 and ((progress - a[1]) / span) or 0
			return a[2] + (b[2] - a[2]) * u
		end
	end
	return keys[#keys][2]
end

local function classify_index(room, index)
	local world = room:GetGridPosition(index)
	if not room:IsPositionInRoom(world, 0) then
		return OWNER.SKIP
	end
	local coll = room:GetGridCollision(index)
	if is_wall_collision(coll) then
		return OWNER.SKIP
	end
	return classify_grid_entity(room:GetGridEntity(index))
end

--- Rebuild per-index ownership for the current room (room-scoped; not every render).
function board.rebuild_owner_map()
	local room = Game():GetRoom()
	local size = room:GetGridSize()
	local by_index = {}
	for index = 0, size - 1 do
		by_index[index] = classify_index(room, index)
	end
	owner_cache.by_index = by_index
	owner_cache.grid_size = size
	owner_cache.grid_width = room:GetGridWidth()
	owner_cache.shape = room:GetRoomShape()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	owner_cache.list_index = desc and desc.ListIndex or -1
	owner_cache.version = (owner_cache.version or 0) + 1
	owner_cache.dirty = false
	owner_cache.rebuilds = (owner_cache.rebuilds or 0) + 1
	render_perf.owner_rebuilds = owner_cache.rebuilds
	invalidate_frame_ctx()
	-- If a mid-frame callback still holds a ctx, keep its map pointer current.
	if frame_ctx.value then
		frame_ctx.value.map = by_index
	end
	return by_index
end

function board.invalidate_owner_cache(why)
	owner_cache.dirty = true
	owner_cache.dirty_why = why
	invalidate_frame_ctx()
end

local function ensure_owner_room_identity()
	local room = Game():GetRoom()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local li = desc and desc.ListIndex or -1
	local size = room:GetGridSize()
	local width = room:GetGridWidth()
	local shape = room:GetRoomShape()
	if owner_cache.dirty
		or owner_cache.by_index == nil
		or owner_cache.list_index ~= li
		or owner_cache.grid_size ~= size
		or owner_cache.grid_width ~= width
		or owner_cache.shape ~= shape then
		board.rebuild_owner_map()
		invalidate_frame_ctx()
	end
end

--- Full visible-set ownership pass (at most once per shared frame ctx build).
local function verify_owner_indices(indices)
	local done = board_perf.scope("ownership_ns")
	ensure_owner_room_identity()
	local room = Game():GetRoom()
	local map = owner_cache.by_index
	if not map or not indices then
		done()
		return map
	end
	board_perf.inc("verify_owner_calls", 1)
	local changed = 0
	local visited = 0
	for index in pairs(indices) do
		visited = visited + 1
		local fresh = classify_index(room, index)
		if map[index] ~= fresh then
			map[index] = fresh
			changed = changed + 1
		end
	end
	board_perf.inc("owner_verified_indices", visited)
	if changed > 0 then
		owner_cache.reclassifications = (owner_cache.reclassifications or 0) + changed
		render_perf.owner_reclassifications = owner_cache.reclassifications
	end
	done()
	return map
end

--- Per-Grid callback: reclassify only this index (map shared with frame ctx).
local function verify_owner_index(index)
	if index == nil then
		return nil
	end
	local done = board_perf.scope("ownership_ns")
	ensure_owner_room_identity()
	local map = owner_cache.by_index
	if not map then
		done()
		return nil
	end
	board_perf.inc("verify_owner_local_calls", 1)
	board_perf.inc("owner_verified_indices", 1)
	local room = Game():GetRoom()
	local fresh = classify_index(room, index)
	if map[index] ~= fresh then
		map[index] = fresh
		owner_cache.reclassifications = (owner_cache.reclassifications or 0) + 1
		render_perf.owner_reclassifications = owner_cache.reclassifications
	end
	done()
	return map[index]
end

board.CULL_MODE = CULL_MODE

function board.set_cull_mode(mode)
	if mode == CULL_MODE.FULL or mode == CULL_MODE.PROJECTION or mode == CULL_MODE.OPTIMIZED then
		cull_mode = mode
	end
	visible_cache.render_serial = -1
	visible_cache.indices = nil
	invalidate_frame_ctx()
	return cull_mode
end

function board.get_cull_mode()
	return cull_mode
end

local function screen_size()
	if Isaac.GetScreenWidth and Isaac.GetScreenHeight then
		return Isaac.GetScreenWidth(), Isaac.GetScreenHeight()
	end
	return 480, 270
end

--- Zeis-style: world grid center → WorldToScreen, then AABB vs render screen.
local function is_grid_on_screen(room, index, sw, sh, margin)
	local world = room:GetGridPosition(index)
	if not world then
		return false
	end
	local sp = Isaac.WorldToScreen(world)
	render_perf.world_to_screen_calls = (render_perf.world_to_screen_calls or 0) + 1
	return sp.X >= -margin
		and sp.Y >= -margin
		and sp.X <= sw + margin
		and sp.Y <= sh + margin
end

local function collect_full_indices(size)
	local indices = {}
	for i = 0, size - 1 do
		indices[i] = true
	end
	return indices, size
end

local function collect_projection_indices(room, size, sw, sh, margin)
	local indices = {}
	local count = 0
	for i = 0, size - 1 do
		if is_grid_on_screen(room, i, sw, sh, margin) then
			indices[i] = true
			count = count + 1
		end
	end
	return indices, count, 0, room:GetGridWidth() - 1, 0, math.floor((size - 1) / math.max(1, room:GetGridWidth()))
end

--- Coarse candidates from screen-center focus (in-room), then projection refine.
-- Never treats screen-corner ScreenToWorld + GetGridIndex as authoritative bounds.
local function collect_optimized_indices(room, size, sw, sh, margin)
	local width = room:GetGridWidth()
	local height = math.floor((size - 1) / math.max(1, width)) + 1
	local focus = Isaac.ScreenToWorld(Vector(sw * 0.5, sh * 0.5))
	local focus_idx = room:GetGridIndex(focus)
	if type(focus_idx) ~= "number" or focus_idx < 0 then
		focus_idx = room:GetGridIndex(room:GetCenterPos())
	end
	local focus_col = focus_idx % width
	local focus_row = math.floor(focus_idx / width)
	-- Generous radius: cover a full screen of 40px cells plus pad (never under-cover).
	local rad_col = math.ceil(sw / CELL) + 3
	local rad_row = math.ceil(sh / CELL) + 3
	local min_col = math.max(0, focus_col - rad_col)
	local max_col = math.min(width - 1, focus_col + rad_col)
	local min_row = math.max(0, focus_row - rad_row)
	local max_row = math.min(height - 1, focus_row + rad_row)
	local indices = {}
	local count = 0
	for row = min_row, max_row do
		for col = min_col, max_col do
			local index = row * width + col
			if index >= 0 and index < size and is_grid_on_screen(room, index, sw, sh, margin) then
				indices[index] = true
				count = count + 1
			end
		end
	end
	return indices, count, min_col, max_col, min_row, max_row
end

function board.get_visible_grid_bounds()
	board_perf.touch_frame()
	local done = board_perf.scope("visibility_ns")
	local room = Game():GetRoom()
	local serial = Isaac.GetFrameCount and Isaac.GetFrameCount() or Game():GetFrameCount()
	local sw, sh = screen_size()
	local focus = Isaac.ScreenToWorld(Vector(sw * 0.5, sh * 0.5))
	local fx = math.floor(focus.X + 0.5)
	local fy = math.floor(focus.Y + 0.5)
	local mode = cull_mode
	local P = render_probe
	if P and P.force_full_board == true then
		mode = CULL_MODE.FULL
	elseif P and P.cull_mode then
		mode = P.cull_mode
	end
	if visible_cache.render_serial == serial
		and visible_cache.indices ~= nil
		and visible_cache.mode == mode
		and visible_cache.sw == sw
		and visible_cache.sh == sh
		and visible_cache.focus_x == fx
		and visible_cache.focus_y == fy then
		board_perf.inc("visibility_cache_hits", 1)
		done()
		return visible_cache
	end
	board_perf.inc("visibility_cache_misses", 1)

	local size = room:GetGridSize()
	local scale = resolve_tile_scale()
	local margin = CELL * math.max(1, scale) * 0.75 + 8
	local indices, count, min_col, max_col, min_row, max_row
	if mode == CULL_MODE.FULL then
		indices, count = collect_full_indices(size)
		min_col, max_col = 0, room:GetGridWidth() - 1
		min_row, max_row = 0, math.floor((size - 1) / math.max(1, room:GetGridWidth()))
	elseif mode == CULL_MODE.PROJECTION then
		indices, count, min_col, max_col, min_row, max_row = collect_projection_indices(room, size, sw, sh, margin)
	else
		indices, count, min_col, max_col, min_row, max_row = collect_optimized_indices(room, size, sw, sh, margin)
	end

	visible_cache.render_serial = serial
	visible_cache.focus_x = fx
	visible_cache.focus_y = fy
	visible_cache.sw = sw
	visible_cache.sh = sh
	visible_cache.mode = mode
	visible_cache.min_col = min_col or 0
	visible_cache.max_col = max_col or 0
	visible_cache.min_row = min_row or 0
	visible_cache.max_row = max_row or 0
	visible_cache.indices = indices
	visible_cache.count = count
	render_perf.total_cells = size
	render_perf.visible_cells = count
	render_perf.culled_cells = math.max(0, size - count)
	done()
	return visible_cache
end

--- Build a fresh visible set for a specific mode (probe compare; bypasses cache).
function board.compute_visible_for_mode(mode)
	local room = Game():GetRoom()
	local sw, sh = screen_size()
	local size = room:GetGridSize()
	local scale = resolve_tile_scale()
	local margin = CELL * math.max(1, scale) * 0.75 + 8
	mode = mode or cull_mode
	if mode == CULL_MODE.FULL then
		local indices, count = collect_full_indices(size)
		return { mode = mode, indices = indices, count = count }
	elseif mode == CULL_MODE.PROJECTION then
		local indices, count = collect_projection_indices(room, size, sw, sh, margin)
		return { mode = mode, indices = indices, count = count }
	end
	local indices, count = collect_optimized_indices(room, size, sw, sh, margin)
	return { mode = mode, indices = indices, count = count }
end

--- Assert Optimized never misses a Projection-visible cell. Returns missing list.
function board.assert_cull_coverage()
	local proj = board.compute_visible_for_mode(CULL_MODE.PROJECTION)
	local opt = board.compute_visible_for_mode(CULL_MODE.OPTIMIZED)
	local missing = {}
	for index in pairs(proj.indices or {}) do
		if not (opt.indices and opt.indices[index]) then
			missing[#missing + 1] = index
		end
	end
	return {
		ok = #missing == 0,
		missing = missing,
		projection_count = proj.count or 0,
		optimized_count = opt.count or 0,
	}
end

function board.is_cell_visible(index)
	if index == nil then
		return false
	end
	local vis = board.get_visible_grid_bounds()
	return vis.indices and vis.indices[index] == true
end

--- Build once: visibility + full ownership verify + route colors + sprite.
local function build_frame_ctx()
	local done = board_perf.scope("render_ctx_ns")
	board_perf.inc("render_context_builds", 1)
	ensure_owner_room_identity()
	local vis = board.get_visible_grid_bounds()
	verify_owner_indices(vis.indices)
	local room = Game():GetRoom()
	local gate = resolve_gate()
	local on_route = route.is_route_room()
	local is_terminal = route.is_terminal_room()
	local progress = on_route and route.get_progress() or 0
	local a = on_route and 0.55 or 0.4
	if is_terminal then a = 0.62 end
	local dark_c, light_c
	if is_terminal then
		local d, l = PALETTE.terminal_dark, PALETTE.terminal_light
		dark_c = KColor(d[1], d[2], d[3], a)
		light_c = KColor(l[1], l[2], l[3], a * 0.9)
	elseif on_route then
		local t = route_blue_weight(progress)
		local nd, nl = PALETTE.neutral_dark, PALETTE.neutral_light
		local bd, bl = PALETTE.blue_dark, PALETTE.blue_light
		local r1, g1, b1 = lerp3(nd, bd, t)
		local r2, g2, b2 = lerp3(nl, bl, t)
		dark_c = KColor(r1, g1, b1, a)
		light_c = KColor(r2, g2, b2, a * 0.9)
	else
		local d, l = PALETTE.neutral_dark, PALETTE.neutral_light
		dark_c = KColor(d[1], d[2], d[3], a)
		light_c = KColor(l[1], l[2], l[3], a * 0.9)
	end
	local ctx = {
		room = room,
		gate = gate,
		source = nil,
		width = room:GetGridWidth(),
		sprite = ensure_tile_sprite(),
		vis = vis,
		map = owner_cache.by_index,
		dark_c = dark_c,
		light_c = light_c,
		force = gate.force == true,
		on_route = on_route,
		is_terminal = is_terminal,
		route_progress = progress,
	}
	done()
	return ctx
end

--- Shared per render-frame context (V3.3). Hit path skips visibility/ownership/color rebuild.
local function get_frame_ctx(source)
	board_perf.touch_frame()
	local key = current_render_frame_key()
	local ver = owner_cache.version or 0
	if frame_ctx.key == key
		and frame_ctx.value ~= nil
		and frame_ctx.owner_version == ver
		and owner_cache.dirty ~= true then
		board_perf.inc("frame_ctx_hits", 1)
		local ctx = frame_ctx.value
		ctx.map = owner_cache.by_index
		if source then
			ctx.source = source
		end
		return ctx
	end
	board_perf.inc("frame_ctx_misses", 1)
	local ctx = build_frame_ctx()
	frame_ctx.key = key
	frame_ctx.value = ctx
	frame_ctx.owner_version = owner_cache.version or 0
	if source then
		ctx.source = source
	end
	return ctx
end

-- Compat alias: all board draw paths share get_frame_ctx.
local function begin_render_ctx(source)
	return get_frame_ctx(source)
end

function board.owner_for_index(index)
	ensure_owner_room_identity()
	local map = owner_cache.by_index
	if not map then
		return OWNER.SKIP
	end
	return map[index] or OWNER.SKIP
end

function board.should_render_cell(index)
	local gate = resolve_gate()
	if gate.fail_reason ~= "none" then
		return false, gate.fail_reason
	end
	local owner = board.owner_for_index(index)
	if owner == OWNER.SKIP then
		return false, "skip"
	end
	local alpha = board.cell_reveal_alpha(index)
	if not gate.force and alpha <= 0 then
		return false, "expand"
	end
	return true, owner
end

local function cell_color_from_ctx(index, owner, ctx)
	local P = render_probe
	if P and P.grid_routing_test == true then
		if owner == OWNER.EMPTY then
			return KColor(1, 0, 1, 0.75)
		elseif owner == OWNER.GRID_PRE then
			return KColor(0, 1, 1, 0.75)
		elseif owner == OWNER.PIT_POST then
			return KColor(1, 1, 0, 0.75)
		end
	end
	if P and P.magenta_tile == true and P._magenta_drawn ~= true then
		P._magenta_drawn = true
		return KColor(1, 0, 1, 0.9)
	end
	local width = ctx.width
	local col = index % width
	local row = math.floor(index / width)
	local dark = ((col + row) % 2) == 0
	return dark and ctx.dark_c or ctx.light_c
end

local function cell_color(index, owner)
	local ctx = begin_render_ctx("cell_color")
	return cell_color_from_ctx(index, owner, ctx)
end

local function render_cell_fast(index, owner, ctx, source)
	source = source or ctx.source or "cell"
	-- Prefer the shared visible set from begin_render_ctx (same for EMPTY/GRID/PIT).
	if ctx and ctx.vis and ctx.vis.indices then
		if ctx.vis.indices[index] ~= true then
			return false
		end
	elseif not board.is_cell_visible(index) then
		return false
	end
	if ctx.gate.fail_reason ~= "none" then
		return false
	end
	if owner == OWNER.SKIP then
		return false
	end
	local alpha = board.cell_reveal_alpha(index)
	if not ctx.force and alpha <= 0 then
		return false
	end
	local room = ctx.room
	local world = room:GetGridPosition(index)
	local spr = ctx.sprite
	local kc = cell_color_from_ctx(index, owner, ctx)
	if owner == OWNER.PIT_POST then
		local P = render_probe
		if not (P and (P.grid_routing_test == true or P.magenta_tile == true)) then
			alpha = alpha * 0.5
		end
	end
	spr.Color = kcolor_to_sprite_color(kc, alpha)
	local screen = Isaac.WorldToScreen(world)
	render_perf.world_to_screen_calls = (render_perf.world_to_screen_calls or 0) + 1
	local P = render_probe
	local skip_sprite = P and P.no_sprite_draw == true
	if skip_sprite then
		board_perf.inc("sprite_renders_skipped", 1)
	else
		local done_spr = board_perf.scope("sprite_render_ns")
		spr:Render(screen, Vector.Zero, Vector.Zero)
		done_spr()
		board_perf.inc("sprite_renders", 1)
	end
	render_perf.render_calls = (render_perf.render_calls or 0) + 1
	board_perf.mark_draw(index, source)
	if P and P.on_cell_draw then
		P.on_cell_draw({
			index = index,
			owner = owner,
			source = source,
			screen = {x = screen.X, y = screen.Y},
		})
	end
	return true
end

--- Draw a single room-grid cell. Clip via Grid-aligned 40px center (no spill intent).
function board.render_cell(index, source)
	source = source or "cell"
	if not board.is_cell_visible(index) then
		return false
	end
	local ok, owner_or_why = board.should_render_cell(index)
	if not ok then
		return false
	end
	local ctx = begin_render_ctx(source)
	return render_cell_fast(index, owner_or_why, ctx, source)
end

--- GridEntity → room grid index for PRE/POST Grid render callbacks.
local function resolve_grid_index(grid)
	if not grid then
		return nil
	end
	local ok, index = pcall(function()
		return grid:GetGridIndex()
	end)
	if ok and type(index) == "number" and index >= 0 then
		board_perf.inc("resolve_index_direct", 1)
		return index
	end
	local pos_ok, pos = pcall(function()
		return grid.Position
	end)
	if pos_ok and pos then
		local room = Game():GetRoom()
		local grid_index = room:GetGridIndex(pos)
		if type(grid_index) == "number" and grid_index >= 0 then
			board_perf.inc("resolve_index_position", 1)
			return grid_index
		end
	end
	-- P2: full-room PtrHash scan stays behind probe flag. Hot path skips it;
	-- V3.2 counters still record when a fullscan would have been needed.
	local allow_fullscan = render_probe and render_probe.allow_index_fullscan == true
	if not allow_fullscan then
		board_perf.inc("resolve_index_fullscan_skipped", 1)
		return nil
	end
	local hash_ok, hash = pcall(function()
		return GetPtrHash(grid)
	end)
	if hash_ok and hash then
		local done_fb = board_perf.scope("fallback_scan_ns")
		board_perf.inc("resolve_index_fullscan", 1)
		local room = Game():GetRoom()
		local visits = 0
		for i = 0, room:GetGridSize() - 1 do
			visits = visits + 1
			local ge = room:GetGridEntity(i)
			if ge then
				local ge_ok, ge_hash = pcall(function()
					return GetPtrHash(ge)
				end)
				if ge_ok and ge_hash == hash then
					board_perf.inc("fullscan_grid_visits", visits)
					done_fb()
					return i
				end
			end
		end
		board_perf.inc("fullscan_grid_visits", visits)
		done_fb()
	end
	return nil
end

function board.render_grid_cell(grid, source)
	local P = render_probe
	if P and (P.no_board_render == true or P.no_stone_visuals == true) then
		return false
	end
	board_perf.touch_frame()
	board_perf.inc("grid_callbacks", 1)
	local done_cb = board_perf.scope("grid_callback_ns")
	local done_path = board_perf.scope_path(source or "GRID_PRE")
	if not grid then
		done_path()
		done_cb()
		return false
	end
	local index = resolve_grid_index(grid)
	if index == nil then
		done_path()
		done_cb()
		return false
	end
	-- Shared frame ctx: visibility + full ownership + colors built at most once per render frame.
	local expected = (source == "PIT_POST") and OWNER.PIT_POST or OWNER.GRID_PRE
	local ctx = get_frame_ctx(source or expected)
	if ctx.gate.fail_reason ~= "none" then
		done_path()
		done_cb()
		return false
	end
	if not (ctx.vis and ctx.vis.indices and ctx.vis.indices[index] == true) then
		done_path()
		done_cb()
		return false
	end
	-- Mid-frame Grid destroy/spawn: reclassify only this index (does not rebuild frame ctx).
	local owner = verify_owner_index(index) or OWNER.SKIP
	if owner ~= expected then
		done_path()
		done_cb()
		return false
	end
	local ok = render_cell_fast(index, owner, ctx, source or expected)
	done_path()
	done_cb()
	return ok
end

function board.render_empty_cells(source)
	source = source or "EMPTY_HELPER"
	local P = render_probe
	if P and (P.no_board_render == true or P.no_stone_visuals == true) then
		return 0
	end
	board_perf.touch_frame()
	board_perf.inc("empty_overlay_calls", 1)
	local done_ov = board_perf.scope("empty_overlay_ns")
	local done_path = board_perf.scope_path(source)
	render_perf.render_calls = 0
	render_perf.world_to_screen_calls = 0
	if P then
		P._magenta_drawn = false
		if P.on_enter then
			P.on_enter(source)
		end
	end
	local gate = resolve_gate()
	if P and P.on_gate then
		P.on_gate(gate)
	end
	if gate.fail_reason ~= "none" then
		done_path()
		done_ov()
		return 0
	end
	local ctx = begin_render_ctx(source)
	local map = ctx.map
	if not map then
		done_path()
		done_ov()
		return 0
	end
	local drawn = 0
	local first_screen = nil
	local vis = ctx.vis
	for index in pairs(vis.indices or {}) do
		if map[index] == OWNER.EMPTY then
			if render_cell_fast(index, OWNER.EMPTY, ctx, source) then
				drawn = drawn + 1
				if not first_screen then
					local screen = Isaac.WorldToScreen(ctx.room:GetGridPosition(index))
					first_screen = {x = screen.X, y = screen.Y}
				end
			end
		end
	end
	if P and P.magenta_tile == true and drawn == 0 then
		local room = Game():GetRoom()
		local world = room:GetCenterPos()
		local spr = ensure_tile_sprite()
		spr.Color = Color(1, 0, 1, 0.9, 0.25, 0, 0.25)
		local screen = Isaac.WorldToScreen(world)
		spr:Render(screen, Vector.Zero, Vector.Zero)
		drawn = 1
		first_screen = {x = screen.X, y = screen.Y}
	end
	if P and P.on_draw then
		local spr = ensure_tile_sprite()
		local anim = nil
		if spr.GetAnimation then
			local ok, name = pcall(function() return spr:GetAnimation() end)
			if ok then anim = name end
		end
		P.on_draw({
			visible_cells = drawn,
			sprite_loaded = spr ~= nil,
			animation = anim or "Idle",
			render_pos = first_screen,
			source = source,
			perf = board.get_render_perf(),
		})
	end
	done_path()
	done_ov()
	return drawn
end


--- Overlay Effect: empty appearance, owns EMPTY cell draw timing only.
function board.overlay_variant()
	return enums.Entities.Stone_Board_Overlay
end

function board.is_overlay_effect(ent)
	local v = board.overlay_variant()
	if not ent or not v or v < 0 then return false end
	return ent.Type == EntityType.ENTITY_EFFECT
		and ent.Variant == v
		and ent:GetData()[OVERLAY_DATA] == true
end

function board.remove_overlay_helper()
	local v = board.overlay_variant()
	if not v or v < 0 then return end
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, v, -1, false, false)) do
		if ent and ent.Exists and ent:Exists() then
			ent:Remove()
		end
	end
end

function board.should_keep_overlay()
	local gate = resolve_gate()
	return gate.fail_reason == "none"
end

function board.ensure_overlay_helper()
	local gate = resolve_gate()
	if gate.fail_reason ~= "none" then
		board.remove_overlay_helper()
		return nil
	end
	local v = board.overlay_variant()
	if not v or v < 0 then return nil end
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, v, -1, false, false)) do
		if ent and ent.Exists and ent:Exists() then
			ent:GetData()[OVERLAY_DATA] = true
			-- Visible must stay true so MC_POST_EFFECT_RENDER still runs; body sprite is fully transparent.
			ent.Visible = true
			ent.DepthOffset = -8000
			local spr = ent:GetSprite()
			if spr then
				spr.Color = Color(1, 1, 1, 0, 0, 0, 0)
			end
			return ent
		end
	end
	local room = Game():GetRoom()
	local ent = Isaac.Spawn(EntityType.ENTITY_EFFECT, v, 0, room:GetCenterPos(), Vector.Zero, nil)
	if not ent then return nil end
	ent:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
	ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	ent.Visible = true
	ent.DepthOffset = -8000
	ent:GetData()[OVERLAY_DATA] = true
	local spr = ent:GetSprite()
	if spr then
		spr.Color = Color(1, 1, 1, 0, 0, 0, 0)
	end
	return ent
end

--- Probe / debug snapshot of the EMPTY-cell helper Effect.
function board.get_overlay_diag()
	local v = board.overlay_variant()
	if not v or v < 0 then
		return {exists = false, visible = false, variant = v, reason = "bad_variant"}
	end
	local found = nil
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, v, -1, false, false)) do
		if ent and ent.Exists and ent:Exists() and ent:GetData()[OVERLAY_DATA] == true then
			found = ent
			break
		end
	end
	if not found then
		return {exists = false, visible = false, variant = v}
	end
	return {
		exists = true,
		visible = found.Visible == true,
		variant = v,
		ptr = GetPtrHash(found),
		depth_offset = found.DepthOffset,
	}
end

--- Legacy full-board entry (probe / non-RGON fallback only). Prefer routing APIs.
--- Uses the same visibility culling as EMPTY / Grid paths (never full-room draw).
function board.render_floor_overlay(source)
	source = source or "legacy_full"
	local P = render_probe
	if P and (P.no_board_render == true or P.no_stone_visuals == true) then
		return
	end
	render_perf.render_calls = 0
	render_perf.world_to_screen_calls = 0
	if P then
		P._magenta_drawn = false
		if P.on_enter then
			P.on_enter(source)
		end
	end
	local gate = resolve_gate()
	if P and P.on_gate then
		P.on_gate(gate)
	end
	if gate.fail_reason ~= "none" then
		return
	end
	local ctx = begin_render_ctx(source)
	local map = ctx.map
	if not map then return end
	local drawn = 0
	local first_screen = nil
	for index in pairs(ctx.vis.indices or {}) do
		local owner = map[index]
		if owner ~= OWNER.SKIP then
			if render_cell_fast(index, owner, ctx, source) then
				drawn = drawn + 1
				if not first_screen then
					local screen = Isaac.WorldToScreen(ctx.room:GetGridPosition(index))
					first_screen = {x = screen.X, y = screen.Y}
				end
			end
		end
	end
	if P and P.magenta_tile == true and drawn == 0 then
		local room = Game():GetRoom()
		local spr = ensure_tile_sprite()
		spr.Color = Color(1, 0, 1, 0.9, 0.25, 0, 0.25)
		local screen = Isaac.WorldToScreen(room:GetCenterPos())
		spr:Render(screen, Vector.Zero, Vector.Zero)
		drawn = 1
		first_screen = {x = screen.X, y = screen.Y}
	end
	if P and P.on_draw then
		P.on_draw({
			visible_cells = drawn,
			sprite_loaded = true,
			animation = "Idle",
			render_pos = first_screen,
			source = source,
			perf = board.get_render_perf(),
		})
	end
end

function board.get_render_perf()
	return {
		total_cells = render_perf.total_cells or 0,
		visible_cells = render_perf.visible_cells or 0,
		culled_cells = render_perf.culled_cells or 0,
		render_calls = render_perf.render_calls or 0,
		owner_rebuilds = owner_cache.rebuilds or 0,
		owner_reclassifications = owner_cache.reclassifications or 0,
		world_to_screen_calls = render_perf.world_to_screen_calls or 0,
		owner_version = owner_cache.version or 0,
		owner_dirty = owner_cache.dirty == true,
	}
end

--- Probe-only performance attribution module (default OFF).
function board.get_board_perf()
	return board_perf
end

--- Isolation mode from attached render probe (normal / no_sprite_draw / no_board_render / no_stone_visuals).
function board.get_isolation_mode()
	local P = render_probe
	if not P then
		return "normal"
	end
	if P.no_stone_visuals == true then
		return "no_stone_visuals"
	end
	if P.no_board_render == true then
		return "no_board_render"
	end
	if P.no_sprite_draw == true then
		return "no_sprite_draw"
	end
	return "normal"
end

function board.should_skip_stone_visuals()
	return render_probe ~= nil and render_probe.no_stone_visuals == true
end

function board.get_expand_diag()
	local r = runtime.get()
	local now = Game():GetFrameCount()
	local elapsed = expand.active and (now - expand.start_frame) or nil
	return {
		active = expand.active,
		slot = expand.slot,
		why = expand.why,
		origin = expand.origin and {x = expand.origin.X, y = expand.origin.Y} or nil,
		origin_index = expand.origin_index,
		normal = expand.normal and {x = expand.normal.X, y = expand.normal.Y} or nil,
		max_manhattan = expand.max_manhattan,
		duration = expand.duration,
		start_frame = expand.start_frame,
		elapsed = elapsed,
		frames_per_ring = FRAMES_PER_RING,
		fade_frames = FADE_FRAMES,
		expand_complete = r.board and r.board.expand_complete == true,
		bootstrap = r.board and r.board.bootstrap_complete,
	}
end

board.OWNER = OWNER

return board
