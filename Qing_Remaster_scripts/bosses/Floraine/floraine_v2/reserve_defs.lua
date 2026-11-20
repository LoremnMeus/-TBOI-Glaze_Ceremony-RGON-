-- Fixed 20-piece black formation: ante 13×7 + Boss reserve slots.
-- Visual / identity only — not Chess Piece NPCs.
-- Positions always come from Room:GetGridPosition(gridIndex).

local piece_defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")

local defs = {}

defs.COUNT = 20 -- real reserve / Boss identities (unchanged)
defs.ANTE_VISUAL_COUNT = 24 -- antechamber display: 20 real + 4 decorative matte
defs.GRID = piece_defs.GRID or 40
defs.ANTE_COLS = 13
-- Staggered ante needs playable rows 0–6.
defs.ANTE_MIN_ROWS = 7
defs.CORRIDOR_COLS = { 5, 6, 7 } -- 0-based; center three of 0..12
-- Ante staggered wing (left). Right mirrors with col' = 12 - col.
-- Avoids contiguous vertical walls (adjacent pieces skip one grid on the same column).
defs.ANTE_LEFT_LAYOUT = {
	{ row = 0, cols = { 1 } },
	{ row = 1, cols = { 0, 3 } },
	{ row = 2, cols = { 2, 4 } },
	{ row = 3, cols = { 0, 3 } },
	{ row = 4, cols = { 1, 4 } },
	{ row = 5, cols = { 0, 3 } },
	{ row = 6, cols = { 2 } },
}
-- Boss-room reserve still uses classic top two rows, 5+5 side columns.
defs.RESERVE_LEFT_COLS = { 0, 1, 2, 3, 4 }
defs.RESERVE_RIGHT_COLS = { 8, 9, 10, 11, 12 }
-- Legacy aliases (reserve layout / older callers).
defs.LEFT_COLS = defs.RESERVE_LEFT_COLS
defs.RIGHT_COLS = defs.RESERVE_RIGHT_COLS
defs.ANTE_ROWS = 2 -- reserve row count (not ante wing depth)

--- Flatten left or mirrored-right ante slots (row-major).
function defs.flatten_ante_slots(side)
	local out = {}
	for _, rowdef in ipairs(defs.ANTE_LEFT_LAYOUT) do
		for _, col in ipairs(rowdef.cols) do
			local c = (side == "right") and (12 - col) or col
			out[#out + 1] = { row = rowdef.row, col = c, side = side }
		end
	end
	return out
end

-- Top row (row 0, nearer Boss door in ante / nearer fight in reserve).
defs.TOP_LEFT_KINDS = {
	piece_defs.KIND.VEHICLE,
	piece_defs.KIND.KNIGHT,
	piece_defs.KIND.BISHOP,
	piece_defs.KIND.QUEEN,
	piece_defs.KIND.PAWN,
}
defs.TOP_RIGHT_KINDS = {
	piece_defs.KIND.PAWN,
	piece_defs.KIND.QUEEN,
	piece_defs.KIND.BISHOP,
	piece_defs.KIND.KNIGHT,
	piece_defs.KIND.VEHICLE,
}

defs.STATE = {
	PENDING = "PENDING", -- layout only; not yet marching / visible
	MARCHING = "MARCHING", -- door → home (entrance lifecycle; not a deploy phase)
	RESERVE = "RESERVE",
	TARGETED = "TARGETED", -- locked by a command soul; waiting for red light
	INFUSING = "INFUSING", -- red light entered; outline on, still grounded
	SELECTED = "SELECTED",
	PULSING = "PULSING",
	LIFTING = "LIFTING",
	TRANSFERRING = "TRANSFERRING",
	HOVERING = "HOVERING", -- over target cell; waiting for drop signal
	DROPPING = "DROPPING", -- unified / inheritance drop (alias before LAND)
	LANDING = "LANDING",
	ACTIVE = "ACTIVE",
	DEFEATED = "DEFEATED",
}

-- Relative phase lengths (MC_POST_UPDATE / Boss update = 30Hz).
defs.DEPLOY = {
	SELECTED = 6,
	PULSE = 10,
	INFUSE = 22,
	LIFT = 20,
	POST_LIFT = 10,
	TRANSFER = 28,
	HOVER = 12,
	LAND = 10,
	SETTLE = 12,
	LIFT_HEIGHT = 22,
	STAGGER = 4, -- particle launch stagger (opening); not per-piece deploy stagger
	TILT_DEG = 8,
}

defs.OPENING_KINDS = {
	piece_defs.KIND.PAWN,
	piece_defs.KIND.KNIGHT,
	piece_defs.KIND.VEHICLE,
}

-- Matte dormant tint (dark gray, low contrast).
defs.MATTE_COLOR = Color(0.22, 0.22, 0.24, 1, 0, 0, 0)

-- Outline styles: white mask layer tinted at runtime (Body+Outline dual layer).
defs.OUTLINE_STYLES = {
	dormant = {
		visible = false,
		color = { 1, 1, 1 },
		alpha = 0,
	},
	selected = {
		visible = true,
		color = { 1.0, 0.22, 0.26 },
		alpha_min = 0.35,
		alpha_max = 0.75,
		pulse_frames = 10,
	},
	pulsing = {
		visible = true,
		color = { 1.0, 0.22, 0.26 },
		alpha_min = 0.35,
		alpha_max = 1.0,
		pulse_frames = 10,
	},
	lifting = {
		visible = true,
		color = { 1.0, 0.30, 0.32 },
		alpha_min = 0.7,
		alpha_max = 1.0,
		pulse_frames = 16,
	},
	transferring = {
		visible = true,
		color = { 1.0, 0.28, 0.30 },
		alpha_min = 0.85,
		alpha_max = 1.0,
		pulse_frames = 20,
	},
	landing = {
		visible = true,
		color = { 1.0, 0.22, 0.26 },
		alpha_min = 0.0,
		alpha_max = 0.7,
		pulse_frames = 10,
		fade_out = true,
	},
}

defs.GROUND_SHADOW = piece_defs.GROUND_SHADOW

local GRIDPATH_COST = 900

function defs.gridpath_cost()
	return GRIDPATH_COST
end

local function is_corridor_col(col)
	return col == 5 or col == 6 or col == 7
end

--- Build the immutable 20-piece roster.
-- ante_* = antechamber wings; reserve_* = Boss-room two-row array (independent).
function defs.build_roster()
	local pieces = {}
	local slot = 0

	local function push(side, ante_row, ante_col, reserve_row, reserve_col, kind)
		slot = slot + 1
		pieces[#pieces + 1] = {
			id = string.format("%s_R%d_C%d", side == "left" and "L" or "R", ante_row, ante_col),
			kind = kind,
			side = side,
			ante_col = ante_col,
			ante_row = ante_row,
			reserve_col = reserve_col,
			reserve_row = reserve_row,
			reserve_slot = slot,
		}
	end

	-- Real roster uses first 10 staggered slots per side (2 decorative slots remain for ante only).
	local left_slots = defs.flatten_ante_slots("left")
	for i = 1, 10 do
		local slot = left_slots[i]
		local reserve_row = i <= 5 and 0 or 1
		local reserve_col = defs.RESERVE_LEFT_COLS[((i - 1) % 5) + 1]
		local kind = i <= 5 and defs.TOP_LEFT_KINDS[i] or piece_defs.KIND.PAWN
		push("left", slot.row, slot.col, reserve_row, reserve_col, kind)
	end
	local right_slots = defs.flatten_ante_slots("right")
	for i = 1, 10 do
		local slot = right_slots[i]
		local reserve_row = i <= 5 and 0 or 1
		local reserve_col = defs.RESERVE_RIGHT_COLS[((i - 1) % 5) + 1]
		local kind = i <= 5 and defs.TOP_RIGHT_KINDS[i] or piece_defs.KIND.PAWN
		push("right", slot.row, slot.col, reserve_row, reserve_col, kind)
	end

	return pieces
end

local function playable_origin(room)
	room = room or Game():GetRoom()
	local tl = room:GetTopLeftPos()
	local br = room:GetBottomRightPos()
	local w = room:GetGridWidth()
	local tl_gidx = room:GetGridIndex(tl)
	local br_gidx = room:GetGridIndex(br)
	if tl_gidx < 0 or br_gidx < 0 then
		return nil, "bad_corners"
	end
	local tl_x = tl_gidx % w
	local tl_y = math.floor(tl_gidx / w)
	local br_x = br_gidx % w
	local br_y = math.floor(br_gidx / w)
	local cols = br_x - tl_x + 1
	local rows = br_y - tl_y + 1
	return {
		w = w,
		tl_gidx = tl_gidx,
		br_gidx = br_gidx,
		tl_x = tl_x,
		tl_y = tl_y,
		br_x = br_x,
		br_y = br_y,
		cols = cols,
		rows = rows,
	}, "ok"
end

local function gidx_at(origin, col, row_y)
	return row_y * origin.w + (origin.tl_x + col)
end

local function cell_from_gidx(room, gidx, piece)
	if gidx < 0 then
		return nil, "oob"
	end
	if room:GetGridCollision(gidx) ~= GridCollisionClass.COLLISION_NONE then
		return nil, "blocked"
	end
	local pos = room:GetGridPosition(gidx)
	if not pos then
		return nil, "no_pos"
	end
	return {
		id = piece.id,
		kind = piece.kind,
		side = piece.side,
		ante_col = piece.ante_col,
		ante_row = piece.ante_row,
		reserve_col = piece.reserve_col,
		reserve_row = piece.reserve_row,
		reserve_slot = piece.reserve_slot,
		pos = Vector(pos.X, pos.Y),
		grid_index = gidx,
	}, "ok"
end

local function validate_unique(cells, expect_count)
	expect_count = expect_count or defs.COUNT
	if #cells ~= expect_count then
		return false, string.format("count_%d", #cells)
	end
	local seen = {}
	for _, cell in ipairs(cells) do
		local g = cell.grid_index
		if type(g) ~= "number" or g < 0 then
			return false, "bad_gidx:" .. tostring(cell.id)
		end
		if seen[g] then
			return false, "dup_gidx:" .. tostring(cell.id) .. "->" .. tostring(seen[g])
		end
		seen[g] = cell.id
		if is_corridor_col(cell.ante_col) then
			return false, "corridor:" .. tostring(cell.id)
		end
	end
	return true, "ok"
end

--- Ante: staggered left/right wings (24 visual = 20 roster + 4 deco), corridor 5–7 clear.
function defs.resolve_ante_layout(room)
	room = room or Game():GetRoom()
	local origin, why = playable_origin(room)
	if not origin then
		return nil, why or "origin"
	end
	local diag = {
		cols = origin.cols,
		rows = origin.rows,
		tl_gidx = origin.tl_gidx,
		br_gidx = origin.br_gidx,
	}
	if origin.cols < defs.ANTE_COLS then
		return nil, "cols_" .. tostring(origin.cols), diag
	end
	local need = defs.ANTE_MIN_ROWS or 7
	if origin.rows < need then
		return nil, "rows_" .. tostring(origin.rows), diag
	end

	local roster = defs.build_roster()
	local by_side = { left = {}, right = {} }
	for _, piece in ipairs(roster) do
		local bucket = by_side[piece.side]
		if bucket then
			bucket[#bucket + 1] = piece
		end
	end

	local cells = {}
	local deco_n = 0
	for _, side in ipairs({ "left", "right" }) do
		local slots = defs.flatten_ante_slots(side)
		local real = by_side[side] or {}
		for i, slot in ipairs(slots) do
			local piece = real[i]
			local decorative = piece == nil
			if decorative then
				deco_n = deco_n + 1
				piece = {
					id = string.format("DECO_%s_R%d_C%d", side == "left" and "L" or "R", slot.row, slot.col),
					kind = piece_defs.KIND.PAWN,
					side = side,
					ante_col = slot.col,
					ante_row = slot.row,
					reserve_col = nil,
					reserve_row = nil,
					reserve_slot = nil,
					decorative = true,
				}
			end
			local gidx = gidx_at(origin, slot.col, origin.tl_y + slot.row)
			local cell, cell_why = cell_from_gidx(room, gidx, piece)
			if not cell then
				diag.fail_id = piece.id
				diag.fail_gidx = gidx
				diag.fail_why = cell_why
				return nil, cell_why or "cell", diag
			end
			cell.decorative = decorative == true
			cell.ante_col = slot.col
			cell.ante_row = slot.row
			cells[#cells + 1] = cell
		end
	end
	local expect = defs.ANTE_VISUAL_COUNT or 24
	local ok, vwhy = validate_unique(cells, expect)
	if not ok then
		return nil, vwhy, diag
	end
	diag.count = #cells
	diag.deco = deco_n
	diag.layout = "ante_staggered"
	return cells, "ok", diag
end

--- Boss reserve: two safe rows near DOWN door; RESERVE_* columns (not ante wings).
function defs.resolve_reserve_layout(room)
	room = room or Game():GetRoom()
	local origin, why = playable_origin(room)
	if not origin then
		return nil, why or "origin"
	end
	local diag = {
		cols = origin.cols,
		rows = origin.rows,
		tl_gidx = origin.tl_gidx,
		br_gidx = origin.br_gidx,
	}
	if origin.cols < defs.ANTE_COLS or origin.rows < 3 then
		return nil, "room_shape", diag
	end

	local door_gidx = room:GetGridIndex(room:GetDoorSlotPosition(DoorSlot.DOWN0))
	local chosen = nil
	for up = 0, math.max(0, origin.rows - 3) do
		local y1 = origin.br_y - up -- nearer door
		local y0 = y1 - 1 -- toward fight
		if y0 < origin.tl_y then
			break
		end
		local blocked = false
		local sample = {}
		for _, col in ipairs(defs.RESERVE_LEFT_COLS) do
			sample[#sample + 1] = gidx_at(origin, col, y0)
			sample[#sample + 1] = gidx_at(origin, col, y1)
		end
		for _, col in ipairs(defs.RESERVE_RIGHT_COLS) do
			sample[#sample + 1] = gidx_at(origin, col, y0)
			sample[#sample + 1] = gidx_at(origin, col, y1)
		end
		for _, gidx in ipairs(sample) do
			if room:GetGridCollision(gidx) ~= GridCollisionClass.COLLISION_NONE then
				blocked = true
				break
			end
			if door_gidx >= 0 and gidx == door_gidx then
				blocked = true
				break
			end
		end
		if not blocked and #sample >= defs.COUNT then
			chosen = { y0 = y0, y1 = y1 }
			break
		end
	end
	if not chosen then
		return nil, "no_safe_rows", diag
	end

	local roster = defs.build_roster()
	local cells = {}
	for _, piece in ipairs(roster) do
		local row_y = (piece.reserve_row or 0) == 0 and chosen.y0 or chosen.y1
		local col = piece.reserve_col
		if col == nil then
			col = piece.ante_col
		end
		local gidx = gidx_at(origin, col, row_y)
		local cell, cell_why = cell_from_gidx(room, gidx, piece)
		if not cell then
			diag.fail_id = piece.id
			diag.fail_gidx = gidx
			diag.fail_why = cell_why
			return nil, cell_why or "cell", diag
		end
		cells[#cells + 1] = cell
	end
	local ok, vwhy = validate_unique(cells)
	if not ok then
		return nil, vwhy, diag
	end

	local p0 = room:GetGridPosition(gidx_at(origin, 0, chosen.y0))
	local p1 = room:GetGridPosition(gidx_at(origin, 0, chosen.y1))
	diag.count = #cells
	diag.row0_y = chosen.y0
	diag.row1_y = chosen.y1
	diag.layout = "boss_reserve"
	return {
		row0_y = p0 and p0.Y or 0,
		row1_y = p1 and p1.Y or 0,
		row0_idx = chosen.y0,
		row1_idx = chosen.y1,
		cells = cells,
		diag = diag,
	}, "ok"
end

function defs.is_corridor_col(col)
	return is_corridor_col(col)
end

function defs.outline_style_for_state(st)
	if st == defs.STATE.TARGETED then
		return defs.OUTLINE_STYLES.dormant
	elseif st == defs.STATE.INFUSING or st == defs.STATE.SELECTED then
		return defs.OUTLINE_STYLES.selected
	elseif st == defs.STATE.PULSING then
		return defs.OUTLINE_STYLES.pulsing
	elseif st == defs.STATE.LIFTING then
		return defs.OUTLINE_STYLES.lifting
	elseif st == defs.STATE.TRANSFERRING or st == defs.STATE.HOVERING then
		return defs.OUTLINE_STYLES.transferring
	elseif st == defs.STATE.DROPPING or st == defs.STATE.LANDING then
		return defs.OUTLINE_STYLES.landing
	end
	-- PENDING / MARCHING / RESERVE: dormant matte, no outline.
	return defs.OUTLINE_STYLES.dormant
end

return defs
