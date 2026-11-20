-- Floraine Boss V2 combat constants (arena + phases + temp assault).

local piece_defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")

local defs = {}

defs.DATA_KEY = "QingFloraineV2"
defs.TEMP_DATA_KEY = "QingFloraineTempPiece"
defs.DIRECTOR_ID = "floraine_boss"

defs.STATE = {
	WAITING = "WAITING",
	INTRO = "INTRO",
	FORMATION_ENTER = "FORMATION_ENTER", -- matte army marches in from side doors
	OPENING_SELECTION = "OPENING_SELECTION",
	COMBAT = "COMBAT",
	PHASE_TRANSITION = "PHASE_TRANSITION",
	DEFEAT = "DEFEAT",
	REWARD_PENDING = "REWARD_PENDING",
	CLEARED = "CLEARED",
}

-- Arena return-door policy (V2.2: no mid-fight retreat).
defs.DOOR = {
	INTRO = "INTRO",
	CLOSING = "CLOSING", -- playing Close on Boss-room DOWN0
	SEALED = "SEALED",
	CLEARED = "CLEARED",
}

defs.PHASE = {
	P1 = 1,
	P2 = 2,
	P3 = 3,
}

-- HP bands: P1 100–70, P2 70–35, P3 35–0.
defs.PHASE_HP = {
	[1] = { lo = 0.70, hi = 1.00 },
	[2] = { lo = 0.35, hi = 0.70 },
	[3] = { lo = 0.00, hi = 0.35 },
}

defs.BOSS_MAX_HP = 600
defs.INTRO_FRAMES = 24 -- raise staff / seal beat before side march
defs.FORMATION_MARCH = {
	STAGGER = 2, -- frames between successive matte entries (fast lineup)
	DURATION = 16, -- lerp frames door → home per piece
}
defs.OPENING_SETTLE_FRAMES = 18 -- land stabilize before P1 combat
defs.OPENING_TIMEOUT_FRAMES = 320 -- safety/degrade if zero lands; never permanent stuck
defs.TRANSITION_FRAMES = 40
-- Synced to Floraine.anm2 command chain: Raise(18) + Cast(Call@2) + Settle(14).
-- Windup = frames until Call; recover = remaining Cast after Call + Settle.
defs.COMMAND_WINDUP = 20
defs.COMMAND_RECOVER = 24
defs.COMMAND_VULN_FRAMES = 44 -- softens guard DR for the full Raise→Cast→Settle cast
defs.RECOVER_FRAMES = 28
defs.DEFEAT_FRAMES = 50

-- P1 opening: three command souls (授令); death inheritance replaces timed reinforce.
defs.P1_OPENING_COUNT = 3
defs.P1_COMMAND_COUNT = 3

-- Opening ritual timings (30Hz) — segmented ~160f design target (event-driven).
defs.P1_RAISE_FRAMES = 20 -- 0–20f raise
defs.P1_CHARGE_FRAMES = 14 -- 20–34f tip charge before particles
defs.P1_PARTICLE_FLIGHT = 24 -- 34–58f-ish flight
defs.P1_INFUSE_FRAMES = 22 -- 58–80f hit + outline hold before lift
defs.P1_POST_LIFT_HOLD = 10 -- 100–110f hover after lift before transfer
defs.P1_PRE_RELEASE_HOLD = 12 -- 138–150f all hovering before Release
defs.P1_HOVER_HOLD = 8 -- inheritance auto-drop hold (non-opening)
defs.P1_DEATH_HOLD = 9 -- red soul condenses at death before seeking
defs.P1_INHERIT_AUTO_DROP = true -- death refill does not wait for Floraine Release
defs.P1_MISSING_GRACE = 45 -- frames without host before anomaly log (no auto inherit)
defs.P1_SLOT_RETRY = 30 -- wait frames when host exists but no landing cell
defs.P1_DIRECTED_ORDER_INTERVAL = 0 -- disabled; P1 signature attack is royal drop
-- 「重落子」P1 signature (30Hz). First attempt after opening settle + delay.
defs.P1_ROYAL_FIRST_DELAY = 90
defs.P1_ROYAL_INTERVAL_MIN = 150
defs.P1_ROYAL_INTERVAL_SPAN = 60 -- + RandomInt → 150–209
defs.P1_ROYAL_RAISE = 12
defs.P1_ROYAL_EMPOWER = 8 -- body/outline fade-in after particle enter
defs.P1_ROYAL_LIFT = 14
defs.P1_ROYAL_TRANSFER = 13
defs.P1_ROYAL_HOVER = 12
defs.P1_ROYAL_DROP = 7 -- cubic ease-in smash
defs.P1_ROYAL_HEIGHT = 30
defs.P1_ROYAL_IMPACT = 3 -- squash + bullets + sfx
defs.P1_ROYAL_RECOVER = 10 -- color/outline fade-out
defs.P1_ROYAL_BULLETS = 8
defs.P1_ROYAL_BULLET_SPEED = 8.5
defs.P1_ROYAL_BULLET_HEIGHT = -26
defs.P1_ROYAL_BULLET_FALL_SPEED = -0.1
defs.P1_ROYAL_BULLET_FALL_ACCEL = -0.03
defs.P1_ROYAL_BULLET_SCALE = 1.10
defs.P1_ROYAL_BULLET_MAX_DIST = 260
-- Command particle presets (rise / hold / fly / enter).
defs.PARTICLE_OPENING = { rise = 8, hold = 8, fly = 24, enter = 5 }
defs.PARTICLE_INHERIT = { rise = 12, hold = 10, fly = 26, enter = 5 }
defs.PARTICLE_ROYAL = { rise = 10, hold = 8, fly = 22, enter = 5 }
-- Exhausted command returns to staff (death hold already spent elsewhere).
defs.PARTICLE_RETURN = { rise = 0, hold = 10, fly = 22, enter = 4 }

-- P1 command-return bleed intensity (native blood scale).
defs.P1_RETURN_BLEED = { 0.7, 1.0, 1.5 }

-- Unified P1→P2 stage machine (30Hz). Overlaps allowed between clear / staff.
defs.TRANSITION_STAGE = {
	LOCK = "LOCK",
	STAGGER = "STAGGER",
	CLEAR_PIECES = "CLEAR_PIECES",
	STAFF_FALL = "STAFF_FALL",
	STAFF_GROUND = "STAFF_GROUND",
	STAFF_RECALL = "STAFF_RECALL",
	P2_SUMMON = "P2_SUMMON",
	FINISH = "FINISH",
}

-- Relative frame windows from transition start (inclusive start, exclusive end).
defs.TRANSITION_TIMELINE = {
	LOCK_END = 4,
	STAGGER_END = 12,
	CLEAR_END = 70,
	STAFF_FALL_START = 64,
	STAFF_FALL_END = 88,
	STAFF_GROUND_END = 110,
	STAFF_RECALL_END = 148,
	P2_SUMMON_END = 205,
	-- Hold room for side-entrance (≈61f after summon) before combat resumes.
	FINISH_END = 240,
}

defs.STAFF_TRANSITION = {
	DETACH = 8,
	FALL = 14,
	BOUNCE = 10,
	GROUND = 16,
	LEVITATE = 12,
	RETURN = 20,
	REATTACH = 12,
	DROP_FORWARD = 42,
	FALL_SCALE = 0.88,
	LAND_SCALE = 0.95,
}

-- P2 side bands (3-col) + promotion chase + shared march / entrance.
defs.P2_COLUMN = {
	STEP_INTERVAL = 75, -- idle frames between march cycles
	BAND_WIDTH = 3, -- outermost legal columns per side
	LIFT = 14,
	HOVER = 12,
	TRANSFER = 20,
	LAND = 14,
	SETTLE = 10,
	LIFT_HEIGHT = 32,
	EXIT_FLY_MAX = 90, -- safety timeout if off-screen check stalls
	TOP_SPAWN_OFFSET = 40,
	ENTRANCE_FLY = 24,
	ENTRANCE_HOVER = 12,
	ENTRANCE_LAND = 15,
	ENTRANCE_SETTLE = 10,
	ENTRANCE_SIDE_OFFSET = 80, -- world px beyond outer band for fly-in start
	TOP_DROP_ANIM = 12, -- LEGACY
	STEP_ANIM = 14, -- LEGACY
	CONTACT_RADIUS = 22,
	CONTACT_DAMAGE = 1,
	CONTACT_COOLDOWN = 30,
	OWNER = "floraine_p2_column",
	STRAY_OWNER = "floraine_p2_stray",
}

defs.P2_PROMOTION = {
	CYCLE_MIN = 180,
	CYCLE_SPAN = 60,
	CAST_WINDUP = 25,
	HIT_STAGGER = 10,
	WEIGHTS = {
		knight = 35,
		bishop = 30,
		vehicle = 25,
		queen = 10,
	},
	CHASE_STEPS = {
		knight = 4,
		bishop = 3,
		vehicle = 3,
		queen = 3,
	},
	DEMOTE_GREY = 12, -- frames of grey-out before matte spawn
}

-- Permanent roster caps (not infinite refill).
defs.GUARD_CAP = {
	[1] = 3,
	[2] = 4,
	[3] = 2,
}

-- Mid-combat reinforce budget. P1 is reserve-limited (nil = no numeric budget).
defs.REINFORCE_BUDGET = {
	[1] = nil,
	[2] = 3,
	[3] = 0,
}

defs.REINFORCE_INTERVAL = 150 -- P2+ default interval
defs.P1_REINFORCE_INTERVAL_MIN = 90
defs.P1_REINFORCE_INTERVAL_SPAN = 30 -- + RandomInt → 90–119

-- Active combat NPCs → Boss damage taken multiplier (P1 guard shield).
defs.GUARD_DAMAGE_FACTOR = {
	[0] = 1.00,
	[1] = 0.80,
	[2] = 0.60,
	[3] = 0.40,
}
-- During command/deploy cast, take at least this much (softens the shield).
defs.COMMAND_VULN_FLOOR = 0.70

defs.TEMP_RECOVER_FRAMES = 20
defs.P3_ATTACK_COOLDOWN = 90
defs.P2_ASSAULT_COOLDOWN = 110
defs.P3_TEMP_COOLDOWN = 150

defs.P1_KINDS = {
	piece_defs.KIND.PAWN,
	piece_defs.KIND.KNIGHT,
	piece_defs.KIND.VEHICLE,
	piece_defs.KIND.BISHOP,
}

defs.P2_KINDS = {
	piece_defs.KIND.PAWN,
	piece_defs.KIND.KNIGHT,
	piece_defs.KIND.VEHICLE,
	piece_defs.KIND.BISHOP,
	piece_defs.KIND.QUEEN,
}

defs.P3_KINDS = {
	piece_defs.KIND.KNIGHT,
	piece_defs.KIND.VEHICLE,
	piece_defs.KIND.QUEEN,
}

defs.TEMP_PHASE = {
	SUMMON = "SUMMON",
	PREPARE = "PREPARE",
	DASH = "DASH",
	FADE = "FADE",
}

defs.TEMP_TIMING = {
	SUMMON = 10,
	PREPARE = 14,
	FADE = 8,
}

-- px per logic frame (30Hz).
defs.TEMP_SPEED = {
	vehicle = 28,
	bishop = 24,
	queen = 25,
	pawn = 22,
	knight = 26,
}

defs.PATTERN = {
	ROOK_PIERCE = "rook_pierce",
	BISHOP_CROSS = "bishop_cross",
	PAWN_TIDE = "pawn_tide",
	QUEEN_JUDGMENT = "queen_judgment",
	ROOK_SINGLE = "rook_single", -- P3
}

defs.SCHED = {
	FORMATION = "FORMATION",
	COMMAND = "COMMAND",
	TEMP_ASSAULT = "TEMP_ASSAULT",
	BOSS_ACTION = "BOSS_ACTION",
	RECOVER = "RECOVER",
	ROYAL_DROP = "ROYAL_DROP",
	P2_COLUMNS = "P2_COLUMNS",
}

defs.ANM2 = "gfx/boss/Floraine/Floraine.anm2"

return defs
