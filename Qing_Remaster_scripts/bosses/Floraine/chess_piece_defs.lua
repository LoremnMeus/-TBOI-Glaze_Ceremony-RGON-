-- Chess piece kind definitions. SubType 1-5 keep Boss compatibility; King = 6.
-- Foot origin is calibrated in pieces.anm2 — no per-kind Lua pivot field.

local defs = {}

defs.KIND = {
	QUEEN = 1,
	VEHICLE = 2,
	BISHOP = 3,
	KNIGHT = 4,
	PAWN = 5,
	KING = 6,
}

defs.KIND_NAME = {
	[1] = "queen",
	[2] = "vehicle",
	[3] = "bishop",
	[4] = "knight",
	[5] = "pawn",
	[6] = "king",
}

defs.MODE = {
	AUTONOMOUS = "AUTONOMOUS",
	DIRECTED = "DIRECTED",
	SCRIPTED = "SCRIPTED",
}

defs.ROLE = {
	COMBAT = "combat",
	ROUTE_ENEMY = "route_enemy",
	ORIGIN = "origin",
	NAVIGATION = "navigation",
}

-- Movement policy for controller.command / command_group.
defs.MOVEMENT_POLICY = {
	NORMAL = "normal", -- respect busy + occupancy
	INTERRUPT = "interrupt", -- break busy, still respect occupancy
	OVERRIDE = "override", -- break busy + ignore occupancy (boss / formation)
}

-- Director task kinds (Stone formation).
defs.TASK = {
	STRIKE = "STRIKE",
	FOLLOW_UP = "FOLLOW_UP",
	MANEUVER = "MANEUVER",
	PREPARE = "PREPARE",
}

defs.ANM2 = "gfx/boss/Floraine/pieces.anm2"
-- Ground shadow: entities2.xml Chess Piece shadowSize (native).

-- Timings are NPC Update clocks (30Hz). Horizontal travel is linear; height/tilt stay per-kind.
defs.PIECES = {
	[defs.KIND.QUEEN] = {
		name = "queen",
		spritesheet = "gfx/boss/Floraine/Queen.png",
		windup_frames = 11,
		travel_frames = 14,
		land_frames = 4,
		recover_frames = 20,
		jump_height = 0,
		tilt_max = 6,
		motion = "glide",
		attack = "queen_sweep",
		hp = 50,
		contact_damage = 1,
		afterimage_count = 4,
		land_sound = "soft",
		land_volume = 0.35,
	},
	[defs.KIND.VEHICLE] = {
		name = "vehicle",
		spritesheet = "gfx/boss/Floraine/Vehicle.png",
		windup_frames = 12,
		travel_frames = 7,
		land_frames = 3,
		recover_frames = 16,
		jump_height = 0,
		tilt_max = 14,
		motion = "tilt_dash",
		attack = "rook_charge",
		hp = 60,
		contact_damage = 1,
		afterimage_count = 4,
		land_sound = "heavy",
		land_volume = 0.55,
	},
	[defs.KIND.BISHOP] = {
		name = "bishop",
		spritesheet = "gfx/boss/Floraine/Bishop.png",
		windup_frames = 8,
		travel_frames = 12,
		land_frames = 3,
		recover_frames = 13,
		jump_height = 2,
		tilt_max = 8,
		motion = "diag_slide",
		attack = "bishop_slide",
		hp = 45,
		contact_damage = 1,
		afterimage_count = 4,
		land_sound = "soft",
		land_volume = 0.4,
	},
	[defs.KIND.KNIGHT] = {
		name = "knight",
		spritesheet = "gfx/boss/Floraine/Knight.png",
		windup_frames = 11,
		travel_frames = 17,
		land_frames = 6,
		recover_frames = 16,
		jump_height = 35,
		tilt_max = 7,
		motion = "high_leap",
		attack = "knight_leap",
		hp = 45,
		contact_damage = 1,
		afterimage_count = 3,
		land_sound = "impact",
		land_volume = 0.65,
	},
	[defs.KIND.PAWN] = {
		name = "pawn",
		spritesheet = "gfx/boss/Floraine/Pawn.png",
		windup_frames = 6,
		travel_frames = 10,
		land_frames = 3,
		recover_frames = 10,
		jump_height = 15,
		tilt_max = 4,
		motion = "short_hop",
		attack = "pawn_lunge",
		hp = 30,
		contact_damage = 1,
		afterimage_count = 3,
		land_sound = "light",
		land_volume = 0.3,
	},
	[defs.KIND.KING] = {
		name = "king",
		spritesheet = "gfx/boss/Floraine/King.png",
		windup_frames = 17,
		travel_frames = 12,
		land_frames = 7,
		recover_frames = 28,
		jump_height = 5,
		tilt_max = 4,
		motion = "heavy_step",
		attack = "king_quake",
		hp = 80,
		contact_damage = 1,
		afterimage_count = 2,
		land_sound = "heavy",
		land_volume = 0.7,
	},
}

defs.GRID = 40

function defs.get(kind)
	kind = tonumber(kind) or defs.KIND.PAWN
	return defs.PIECES[kind] or defs.PIECES[defs.KIND.PAWN]
end

function defs.name_of(kind)
	return defs.KIND_NAME[tonumber(kind) or 0] or "pawn"
end

--- White alpha-ring outline sheet for Body+Outline dual-layer ANM2 (layer "outline"/1).
function defs.outline_sheet(kind)
	local profile = defs.get(kind)
	local sheet = profile.spritesheet or "gfx/boss/Floraine/Pawn.png"
	return (sheet:gsub("%.png$", "_outline.png"))
end

defs.GROUND_SHADOW = "gfx/boss/Floraine/piece_ground_shadow.png"
defs.GROUND_SHADOW_ANM2 = "gfx/boss/Floraine/piece_ground_shadow.anm2"

local function clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

--- Distance-driven travel frames (30Hz). Long slides stay snappy; short hops keep profile default.
-- opts.is_gold: gold pawns use a snappier base travel.
function defs.travel_frames_for(kind, from, to, opts)
	opts = opts or {}
	kind = tonumber(kind) or defs.KIND.PAWN
	local profile = defs.get(kind)
	local base = profile.travel_frames or 10
	if opts.is_gold and kind == defs.KIND.PAWN then
		local fdefs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")
		local g = fdefs.P1_GOLD_PAWN_ACTION or {}
		base = tonumber(g.travel_frames) or 6
	end
	if not from or not to then
		return base
	end
	local cells = math.max(1, math.floor((to - from):Length() / defs.GRID + 0.5))
	if kind == defs.KIND.VEHICLE then
		return math.floor(clamp(4 + 0.7 * cells, 5, 10) + 0.5)
	elseif kind == defs.KIND.BISHOP then
		return math.floor(clamp(5 + 0.9 * cells, 6, 12) + 0.5)
	elseif kind == defs.KIND.QUEEN then
		return math.floor(clamp(5 + 1.0 * cells, 6, 13) + 0.5)
	elseif opts.is_gold and kind == defs.KIND.PAWN then
		return math.floor(clamp(base + 0.35 * (cells - 1), 4, 8) + 0.5)
	end
	return base
end

--- Runtime action timing for a live piece (gold pawn overrides only).
function defs.action_timing(data)
	local kind = data and data.kind or defs.KIND.PAWN
	local profile = defs.get(kind)
	if data and data.is_gold and kind == defs.KIND.PAWN then
		local fdefs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")
		local g = fdefs.P1_GOLD_PAWN_ACTION or {}
		return {
			windup_frames = tonumber(g.windup_frames) or 3,
			travel_frames = tonumber(g.travel_frames) or 6,
			land_frames = tonumber(g.land_frames) or 2,
			recover_frames = tonumber(g.recover_frames) or 4,
			jump_height = profile.jump_height,
			tilt_max = profile.tilt_max,
			motion = profile.motion,
		}
	end
	return profile
end

return defs
