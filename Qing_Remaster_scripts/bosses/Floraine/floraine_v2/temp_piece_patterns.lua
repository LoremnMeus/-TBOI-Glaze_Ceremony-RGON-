-- Path planners for Floraine temp assaults. Room-bounds driven; leave dodge gaps.

local piece_defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")
local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")
local temp_piece = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.temp_piece")

local patterns = {}

local BUFFER = 28 -- half-piece outside playable edge

local function play_bounds()
	local room = Game():GetRoom()
	local tl = room:GetTopLeftPos()
	local br = room:GetBottomRightPos()
	return {
		left = tl.X,
		right = br.X,
		top = tl.Y,
		bottom = br.Y,
		cx = (tl.X + br.X) * 0.5,
		cy = (tl.Y + br.Y) * 0.5,
		w = br.X - tl.X,
		h = br.Y - tl.Y,
	}
end

local function player_pos()
	local p = Game():GetPlayer(0)
	return p and p.Position or Game():GetRoom():GetCenterPos()
end

local function rng()
	return Game():GetPlayer(0):GetCollectibleRNG(CollectibleType.COLLECTIBLE_DADS_KEY)
end

local function clamp_lane(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

--- Horizontal or vertical rook pierce (two staggered lines).
function patterns.plan_rook_pierce()
	local b = play_bounds()
	local ppos = player_pos()
	local r = rng()
	local horizontal = (r:RandomInt(2) == 0)
	local paths = {}
	local g = piece_defs.GRID
	if horizontal then
		local y1 = clamp_lane(ppos.Y - g * 0.5, b.top + 40, b.bottom - 40)
		local y2 = clamp_lane(ppos.Y + g * 1.5, b.top + 40, b.bottom - 40)
		if math.abs(y2 - y1) < g then
			y2 = clamp_lane(y1 + g * 2, b.top + 40, b.bottom - 40)
		end
		local from_left = ppos.X > b.cx
		local x0 = from_left and (b.left - BUFFER) or (b.right + BUFFER)
		local x1 = from_left and (b.right + BUFFER) or (b.left - BUFFER)
		paths[1] = {
			kind = piece_defs.KIND.VEHICLE,
			start = Vector(x0, y1),
			dest = Vector(x1, y1),
			delay = 0,
			pattern = defs.PATTERN.ROOK_PIERCE,
		}
		paths[2] = {
			kind = piece_defs.KIND.VEHICLE,
			start = Vector(x0, y2),
			dest = Vector(x1, y2),
			delay = 10,
			pattern = defs.PATTERN.ROOK_PIERCE,
		}
	else
		local x1 = clamp_lane(ppos.X - g * 0.5, b.left + 40, b.right - 40)
		local x2 = clamp_lane(ppos.X + g * 1.5, b.left + 40, b.right - 40)
		if math.abs(x2 - x1) < g then
			x2 = clamp_lane(x1 + g * 2, b.left + 40, b.right - 40)
		end
		local from_top = ppos.Y > b.cy
		local y0 = from_top and (b.top - BUFFER) or (b.bottom + BUFFER)
		local y1 = from_top and (b.bottom + BUFFER) or (b.top - BUFFER)
		paths[1] = {
			kind = piece_defs.KIND.VEHICLE,
			start = Vector(x1, y0),
			dest = Vector(x1, y1),
			delay = 0,
			pattern = defs.PATTERN.ROOK_PIERCE,
		}
		paths[2] = {
			kind = piece_defs.KIND.VEHICLE,
			start = Vector(x2, y0),
			dest = Vector(x2, y1),
			delay = 10,
			pattern = defs.PATTERN.ROOK_PIERCE,
		}
	end
	return paths, defs.PATTERN.ROOK_PIERCE
end

function patterns.plan_rook_single()
	local paths, name = patterns.plan_rook_pierce()
	-- Keep only first path for P3.
	return { paths[1] }, defs.PATTERN.ROOK_SINGLE
end

--- Two diagonal bishop crosses, staggered.
function patterns.plan_bishop_cross()
	local b = play_bounds()
	local ppos = player_pos()
	local paths = {}
	-- Diagonal A: top-left → bottom-right through near player.
	local span = math.min(b.w, b.h) * 0.55
	local c1 = Vector(ppos.X - 20, ppos.Y - 20)
	paths[1] = {
		kind = piece_defs.KIND.BISHOP,
		start = Vector(c1.X - span, c1.Y - span),
		dest = Vector(c1.X + span, c1.Y + span),
		delay = 0,
		pattern = defs.PATTERN.BISHOP_CROSS,
	}
	-- Diagonal B: top-right → bottom-left, delayed.
	local c2 = Vector(ppos.X + 20, ppos.Y - 10)
	paths[2] = {
		kind = piece_defs.KIND.BISHOP,
		start = Vector(c2.X + span, c2.Y - span),
		dest = Vector(c2.X - span, c2.Y + span),
		delay = 12,
		pattern = defs.PATTERN.BISHOP_CROSS,
	}
	-- Clamp starts/dests slightly outside bounds.
	for _, path in ipairs(paths) do
		-- Extend endpoints to outside buffer along their direction.
		local dir = (path.dest - path.start)
		if dir:Length() > 1 then
			dir = dir:Normalized()
			path.start = path.start - dir * BUFFER
			path.dest = path.dest + dir * BUFFER
		end
	end
	return paths, defs.PATTERN.BISHOP_CROSS
end

--- Pawn tide from top with 1–2 safe gaps.
function patterns.plan_pawn_tide()
	local b = play_bounds()
	local r = rng()
	local lanes = 5
	local gap_a = (r:RandomInt(lanes)) + 1
	local gap_b = ((gap_a + 1 + r:RandomInt(lanes - 2)) % lanes) + 1
	local paths = {}
	local margin = 50
	local usable = b.w - margin * 2
	local step = usable / (lanes - 1)
	local y0 = b.top - BUFFER
	local y1 = b.bottom + BUFFER
	local delay = 0
	for i = 1, lanes do
		if i ~= gap_a and i ~= gap_b then
			local x = b.left + margin + (i - 1) * step
			paths[#paths + 1] = {
				kind = piece_defs.KIND.PAWN,
				start = Vector(x, y0),
				dest = Vector(x, y1),
				delay = delay,
				pattern = defs.PATTERN.PAWN_TIDE,
			}
			delay = delay + 4
		end
	end
	if #paths < 1 then
		-- Fallback: two pawns with center gap.
		paths[1] = {
			kind = piece_defs.KIND.PAWN,
			start = Vector(b.left + 80, y0),
			dest = Vector(b.left + 80, y1),
			delay = 0,
			pattern = defs.PATTERN.PAWN_TIDE,
		}
		paths[2] = {
			kind = piece_defs.KIND.PAWN,
			start = Vector(b.right - 80, y0),
			dest = Vector(b.right - 80, y1),
			delay = 6,
			pattern = defs.PATTERN.PAWN_TIDE,
		}
	end
	return paths, defs.PATTERN.PAWN_TIDE
end

--- Single queen judgment along row/col/diag through player lane.
function patterns.plan_queen_judgment()
	local b = play_bounds()
	local ppos = player_pos()
	local r = rng()
	local mode = r:RandomInt(3) -- 0 horiz 1 vert 2 diag
	local path
	if mode == 0 then
		local y = clamp_lane(ppos.Y, b.top + 40, b.bottom - 40)
		local from_left = ppos.X > b.cx
		path = {
			kind = piece_defs.KIND.QUEEN,
			start = Vector(from_left and (b.left - BUFFER) or (b.right + BUFFER), y),
			dest = Vector(from_left and (b.right + BUFFER) or (b.left - BUFFER), y),
			delay = 0,
			pattern = defs.PATTERN.QUEEN_JUDGMENT,
			hit_radius = 24,
		}
	elseif mode == 1 then
		local x = clamp_lane(ppos.X, b.left + 40, b.right - 40)
		path = {
			kind = piece_defs.KIND.QUEEN,
			start = Vector(x, b.top - BUFFER),
			dest = Vector(x, b.bottom + BUFFER),
			delay = 0,
			pattern = defs.PATTERN.QUEEN_JUDGMENT,
			hit_radius = 24,
		}
	else
		local span = math.min(b.w, b.h) * 0.6
		local dir = (r:RandomInt(2) == 0) and 1 or -1
		path = {
			kind = piece_defs.KIND.QUEEN,
			start = Vector(ppos.X - span, ppos.Y - span * dir),
			dest = Vector(ppos.X + span, ppos.Y + span * dir),
			delay = 0,
			pattern = defs.PATTERN.QUEEN_JUDGMENT,
			hit_radius = 24,
		}
		local d = (path.dest - path.start):Normalized()
		path.start = path.start - d * BUFFER
		path.dest = path.dest + d * BUFFER
	end
	return { path }, defs.PATTERN.QUEEN_JUDGMENT
end

local P2_WEIGHTS = {
	{ name = defs.PATTERN.ROOK_PIERCE, plan = patterns.plan_rook_pierce, w = 35 },
	{ name = defs.PATTERN.BISHOP_CROSS, plan = patterns.plan_bishop_cross, w = 30 },
	{ name = defs.PATTERN.PAWN_TIDE, plan = patterns.plan_pawn_tide, w = 20 },
	{ name = defs.PATTERN.QUEEN_JUDGMENT, plan = patterns.plan_queen_judgment, w = 15 },
}

local P3_WEIGHTS = {
	{ name = defs.PATTERN.ROOK_SINGLE, plan = patterns.plan_rook_single, w = 55 },
	{ name = defs.PATTERN.QUEEN_JUDGMENT, plan = patterns.plan_queen_judgment, w = 45 },
}

local function pick_weighted(list)
	local r = rng()
	local total = 0
	for i = 1, #list do
		total = total + list[i].w
	end
	local roll = r:RandomInt(math.max(1, total))
	local acc = 0
	for i = 1, #list do
		acc = acc + list[i].w
		if roll < acc then
			return list[i]
		end
	end
	return list[1]
end

function patterns.plan_for_phase(phase, force_name)
	if force_name == defs.PATTERN.ROOK_PIERCE then
		return patterns.plan_rook_pierce()
	elseif force_name == defs.PATTERN.BISHOP_CROSS then
		return patterns.plan_bishop_cross()
	elseif force_name == defs.PATTERN.PAWN_TIDE then
		return patterns.plan_pawn_tide()
	elseif force_name == defs.PATTERN.QUEEN_JUDGMENT then
		return patterns.plan_queen_judgment()
	elseif force_name == defs.PATTERN.ROOK_SINGLE then
		return patterns.plan_rook_single()
	end
	local list = (tonumber(phase) or 2) >= 3 and P3_WEIGHTS or P2_WEIGHTS
	local pick = pick_weighted(list)
	return pick.plan()
end

--- Spawn planned paths; returns count, pattern name.
function patterns.execute(phase, force_name)
	local paths, name = patterns.plan_for_phase(phase, force_name)
	if not paths or #paths < 1 then
		return 0, nil, "empty_plan"
	end
	local n = 0
	for i = 1, #paths do
		local ent, why = temp_piece.spawn(paths[i])
		if ent then
			n = n + 1
		end
	end
	if n < 1 then
		return 0, name, "spawn_failed"
	end
	return n, name, "ok"
end

return patterns
