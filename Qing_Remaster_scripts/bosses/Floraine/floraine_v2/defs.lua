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
-- Synced to Floraine.anm2 command chain: Raise(18) + Cast(Call@5) + Settle(14).
-- Windup = frames until Call; recover = remaining Cast after Call + Settle.
defs.COMMAND_WINDUP = 23
defs.COMMAND_RECOVER = 21
defs.COMMAND_VULN_FRAMES = 44 -- softens guard DR for the full Raise→Cast→Settle cast
defs.RECOVER_FRAMES = 28
defs.DEFEAT_FRAMES = 50

-- P1 opening: three NORMAL command souls; gold extras unlock by kill thresholds.
defs.P1_OPENING_COUNT = 3
defs.P1_OPENING_COMMAND_COUNT = 3
-- LEGACY name kept as opening/normal pool size (not theoretical max capacity).
defs.P1_COMMAND_COUNT = 3
-- Effective combat kills unlock one GOLD command each (one-shot, no inherit).
defs.P1_GOLD_KILL_THRESHOLDS = { 5, 8, 10, 12 }
-- HP bailout unlocks the first two gold quotas (by threshold index). Same quota never double-fires.
defs.P1_GOLD_HP_GUARANTEES = {
	{ ratio = 0.90, index = 1 }, -- first gold if not yet unlocked
	{ ratio = 0.80, index = 2 }, -- second gold if not yet unlocked
}
defs.P1_GOLD_DAMAGE_RATIO = 0.05 -- MaxHitPoints fraction per gold kill (floor at P2 HP)
-- Secondary NORMAL return bleed (no longer the main P1 push / forced P2 trigger).
defs.P1_RETURN_DAMAGE_RATIO = 0.02
defs.P1_GOLD_OUTLINE = {
	color = { 1.0, 0.82, 0.28 },
	alpha = 0.72,
	pulse = 0.10,
}
-- Gold afterimage: per-sample distance_remaining (param1) then fade_remaining (param2).
-- α = alpha0 * (floor + span * d_remain/life) while ACTIVE; FADING has no damage.
defs.P1_GOLD_AFTERIMAGE = {
	sample_distance = 32,
	fade_start_distance = 160, -- param1 life (world px of subsequent travel)
	fade_frames = 10, -- param2 after distance hits 0
	alpha_floor_mul = 0.65,
	alpha_distance_mul = 0.35,
	max_samples = 16,
	hit_radius = 15,
	hit_cooldown = 30,
	alpha0 = 0.85,
	outline_alpha = 0.90,
	draw_mul = 1.0,
	color = { 1.0, 0.82, 0.28 },
	outline_color = { 1.0, 0.92, 0.55 },
}
-- Royal-drop target cell: hard 40×40 fill + border (not ground-shadow soft ellipse).
defs.P1_ROYAL_CELL = {
	fill = { 1.0, 0.22, 0.28 },
	border = { 1.0, 0.48, 0.50 },
	fill_alpha = 0.40,
	border_alpha = 0.95,
	appear_frames = 5, -- late LIFT
	release_alpha = 0.48,
	drop_alpha = 0.58,
	impact_alpha = 0.85,
	fade_frames = 7, -- IMPACT flash then fade (visible into RECOVER)
	border_thickness = 2,
}
-- Gold pawn action overrides (do not mutate normal pawn defs).
defs.P1_GOLD_PAWN_ACTION = {
	windup_frames = 3,
	travel_frames = 6,
	land_frames = 2,
	recover_frames = 4,
}
defs.P1_GOLD_REWARD_COUNT = 7
-- scatter: real outward motion from death; hold/fly/enter: gather → boss → absorb.
defs.PARTICLE_GOLD_REWARD = { scatter = 10, hold = 6, fly = 18, enter = 4 }
-- SpriteTrail preset for gold reward carriers (hand-tinted; no Psy Fly offset).
defs.P1_GOLD_TRAIL = {
	min_radius = 0.12,
	max_radius = 0.08,
	scale = 0.45,
	local_offset = { x = 0, y = 0 },
	color = { r = 1, g = 1, b = 1, a = 1, ro = 0, go = 0, bo = 0 },
	colorize = { r = 1, g = 0.82, b = 0.28, a = 1 },
	reapply_color_each_sync = true,
}
defs.P1_GOLD_TRAIL_FADE = 10
-- Command-piece atlas is a white mask; runtime tints body/outline separately.
-- Suggested V1 test palette (not locked brand colors).
defs.COMMAND_PARTICLE_TINT = {
	normal = {
		body = { 0xB7 / 255, 0x3B / 255, 0x50 / 255 }, -- #B73B50
		outline = { 0xFF / 255, 0x9B / 255, 0xA0 / 255 }, -- #FF9BA0
	},
	gold = {
		body = { 0xC1 / 255, 0x8A / 255, 0x30 / 255 }, -- #C18A30
		outline = { 0xFF / 255, 0xE2 / 255, 0x9A / 255 }, -- #FFE29A
	},
}
defs.GOLD_REWARD_ORB_ANM2 = "gfx/cards/cd03_emp_tear.anm2"
defs.GOLD_REWARD_ORB_ANIM = "RegularTear6"

-- Opening camera (30Hz). Formation → pan-up → Boss hold → soft release.
defs.OPENING_CAMERA = {
	PAN_UP_FRAMES = 27,
	BOSS_HOLD_FRAMES = 10,
	-- After command launch: linger on Boss, then soft-release.
	RELEASE_DELAY_FRAMES = 15,
	RELEASE_FRAMES = 40,
}
-- Opening launch authority is Floraine.anm2 Cast event "Call" (frame 5), not these timers.
-- Kept as legacy labels / fallback reference only — do not drive opening particle launch.
defs.P1_RAISE_FRAMES = 20 -- LEGACY: was independent Raise clock; superseded by Cast.Call
defs.P1_CHARGE_FRAMES = 14 -- LEGACY: was tip-charge clock; superseded by Cast.Call
defs.P1_PARTICLE_FLIGHT = 24 -- 34–58f-ish flight
defs.CAST_CALL_FALLBACK_FRAME = 5 -- one-shot if Cast.Call event missed

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
defs.P1_ROYAL_ALIGN = 4 -- airborne exact overlap pause before HOVER / Release
defs.P1_ROYAL_OUTLINE_APPEAR = 5 -- target ghost fade-in during late LIFT
defs.P1_ROYAL_OUTLINE_HOLD = 0.55 -- stable target-outline alpha while holding
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
-- Opening multi-command orbit (staff tip → upper arc slots). Opening batch only.
-- Angles: standard cos/sin with Isaac Y-down → 210/270/330 = left-up / up / right-up.
defs.P1_OPENING_ORBIT = {
	radius = 32,
	angles = { 210, 270, 330 },
	center_offset = { x = 0, y = -18 }, -- tip → orbit center (frozen at Call)
	shared_hold = 9, -- frames all slots hover together before fly
}
-- Command particle presets (rise / hold / fly / enter).
defs.PARTICLE_OPENING = { rise = 10, hold = 8, fly = 24, enter = 5 }
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
-- Staff detaches immediately with piece scatter; float/hover overlaps P2 summon.
defs.TRANSITION_TIMELINE = {
	LOCK_END = 6,
	STAGGER_END = 6,
	CLEAR_END = 66,
	STAFF_FALL_START = 0,
	STAFF_FALL_END = 30,
	STAFF_GROUND_END = 66,
	STAFF_FLOAT_END = 96,
	STAFF_HOVER_END = 108,
	STAFF_RECALL_END = 132,
	P2_SUMMON_END = 180,
	-- Hold room for side-entrance before combat resumes.
	FINISH_END = 200,
}

-- Compact P2→P3 evacuate windows (30Hz). Finish waits on evac completion, not a hard cut.
defs.P2_TO_P3_TIMELINE = {
	LOCK_END = 8,
	SCATTER_END = 24,
	MIN_FINISH = 28,
}

-- Pose / land params only. Duration windows live in TRANSITION_TIMELINE (STAFF_*).
defs.STAFF_TRANSITION = {
	DROP_LEFT_X = -32,
	DROP_DOWN_Y = 42,
	DROP_FORWARD = 42, -- LEGACY alias
	FALL_SCALE = 0.88,
	LAND_SCALE = 0.95,
	CATCH_ANIM = "RaiseFromIdle2",
	CATCH_FRAME = 0,
	OUTLINE_GLOW = { 0.85, 0.92, 1.0 },
	-- LEGACY duration fields (unused; kept so old probes don't nil-index):
	DETACH = 8,
	FALL = 14,
	BOUNCE = 10,
	GROUND = 16,
	LEVITATE = 12,
	RETURN = 20,
	REATTACH = 12,
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
	EXIT_FLY_MAX = 300, -- absolute failsafe only; normal remove is full off-screen
	TOP_SPAWN_OFFSET = 40, -- LEGACY march step; top enter uses screen-edge helper
	ENTRANCE_FLY = 24,
	ENTRANCE_HOVER = 12,
	ENTRANCE_LAND = 15,
	ENTRANCE_SETTLE = 10,
	ENTRANCE_SIDE_OFFSET = 80, -- LEGACY; entrance uses screen-edge helper
	SPRITE_HALF = 24, -- approx half-width / top extent for off-screen tests
	TOP_DROP_ANIM = 12, -- LEGACY
	STEP_ANIM = 14, -- LEGACY
	CONTACT_RADIUS = 22,
	CONTACT_DAMAGE = 1,
	CONTACT_COOLDOWN = 30,
	OWNER = "floraine_p2_column",
	STRAY_OWNER = "floraine_p2_stray",
	-- Shared march squash / silver outline (whole column, one clock).
	MARCH_VISUAL = {
		OUTLINE_RGB = { 0.85, 0.81, 0.82 }, -- #D8CFD1
		OUTLINE_MAX = 0.80,
		ANTICIPATE_X = 1.04,
		ANTICIPATE_Y = 0.94,
		AIR_X = 0.98,
		AIR_Y = 1.05,
		TRANSFER_X = 0.98,
		TRANSFER_Y = 1.04,
		IMPACT_X = 1.10,
		IMPACT_Y = 0.88,
		REBOUND_X = 0.97,
		REBOUND_Y = 1.04,
		ANTICIPATE_FRAMES = 3, -- LIFT crouch before rise
		IMPACT_FRAMES = 3, -- LAND squash hold
		REBOUND_FRAMES = 3, -- SETTLE rebound
		TRANSFER_ACCEL = 3,
		TRANSFER_DECEL = 3,
	},
}

-- Combat-clock promotion (not idle-only). Cap allows overlapping batches; each cast still picks 2.
defs.P2_PROMOTION = {
	FIRST_CYCLE_MIN = 15, -- first cast after P2 combat starts
	FIRST_CYCLE_SPAN = 16, -- 15–30
	CYCLE_MIN = 105,
	CYCLE_SPAN = 30, -- subsequent 105–135
	CAST_WINDUP = 18,
	HIT_STAGGER = 8,
	MAX_ACTIVE = 6, -- concurrent chase + morph + pending
	PICK_COUNT = 2, -- targets per cast (from columns + strays)
	WEIGHTS = {
		knight = 35,
		bishop = 30,
		vehicle = 25,
		queen = 10,
	},
	-- Rolled once per promote (inclusive). Legacy CHASE_STEPS kept as fallback midpoints.
	CHASE_STEPS_RANGE = {
		knight = { 4, 7 },
		bishop = { 4, 6 },
		vehicle = { 4, 6 },
		queen = { 3, 5 },
	},
	CHASE_STEPS = {
		knight = 5,
		bishop = 5,
		vehicle = 5,
		queen = 4,
	},
	-- wait / travel by Manhattan cells to player
	CADENCE = {
		near = { wait = 12, travel = 9 }, -- ≤1
		mid = { wait = 10, travel = 8 }, -- 2–3
		far = { wait = 8, travel = 7 }, -- ≥4
	},
	-- Continuous ghost morph (promote / demote). No Poof handoff.
	MORPH = {
		GHOST = 6,
		SQUASH = 6,
		GROW = 10,
		SETTLE = 4,
	},
	DEMOTE_GREY = 12, -- LEGACY alias; demote uses MORPH total
}

-- P2「棋落」: staff sink → red cells → matte fall → persist as strays.
defs.P2_CHESS_DROP = {
	INTERVAL_MIN = 240,
	INTERVAL_SPAN = 60, -- 240–300 combat frames
	FIRST_DELAY_MIN = 75,
	FIRST_DELAY_SPAN = 31, -- 75–105
	FIRST_DELAY = 90, -- mid default / legacy
	SINK = 10,
	WARN = 22,
	FALL = 10,
	IMPACT = 4,
	SETTLE = 8,
	MIN_CELLS = 3,
	MAX_CELLS = 5,
	MATTE_SOFT_CAP = 24,
	IMPACT_DAMAGE = 2, -- one full heart
	IMPACT_RADIUS = 22,
	OWNER = "floraine_p2_chess_drop",
	FILL = { 1.0, 0.22, 0.28 },
	BORDER = { 1.0, 0.48, 0.50 },
	WARN_ALPHA = 0.42,
}

-- Permanent roster caps (not infinite refill).
-- P1 uses runtime cap = opening + unlocked gold (see command_souls.get_p1_guard_cap).
defs.GUARD_CAP = {
	[1] = 7, -- theoretical P1 max (3 + 4 gold); phase.guard_cap reads dynamic for P1
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
-- Extended for up to 7 pieces; slightly softer than old 3-cap curve.
defs.GUARD_DAMAGE_FACTOR = {
	[0] = 1.00,
	[1] = 0.85,
	[2] = 0.72,
	[3] = 0.60,
	[4] = 0.52,
	[5] = 0.46,
	[6] = 0.42,
	[7] = 0.40,
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
	P2_CHESS_DROP = "P2_CHESS_DROP",
}

defs.ANM2 = "gfx/boss/Floraine/Floraine.anm2"

return defs
