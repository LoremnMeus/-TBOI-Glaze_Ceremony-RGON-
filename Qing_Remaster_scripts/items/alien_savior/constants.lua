-- Alien Savior tunable constants (30Hz game logic clock).
local C = {}

C.ITEM_GFX = "gfx/items/collectibles/collectibles_Alien_Savior.png"
C.UFO_ANM2 = "gfx/mimics/Alien_savior/Alien_UFO.anm2"
C.BEAM_ANM2 = "gfx/mimics/Alien_savior/beam/Alien_beam.anm2"

C.PHASE = {
	INACTIVE = "INACTIVE",
	ARRIVING = "ARRIVING",
	ABDUCT_PLAYER = "ABDUCT_PLAYER",
	TRANSIT_TO_CENTER = "TRANSIT_TO_CENTER",
	ABDUCT_TARGETS = "ABDUCT_TARGETS",
	LASER_SWEEP = "LASER_SWEEP",
	RELEASE_PLAYER = "RELEASE_PLAYER",
	DEPARTING = "DEPARTING",
}

-- Workflow budgets @ MC_POST_UPDATE (30Hz). Beam open/close windows included.
C.DUR = {
	ARRIVING = 50,
	-- LightTravel scrub ~1:1 with capture_frame; beam must already be open (ARRIVING).
	ABDUCT_PLAYER = 35,
	-- First BEAM_TRANSIT_CLOSE frames hold at pickup while beam closes, then fly.
	TRANSIT_TO_CENTER = 32,
	-- Scan budget only; actual phase ends when suction jobs finish (see C.SUCTION).
	ABDUCT_TARGETS = 45,
	LASER_SWEEP = 65,
	-- travel + settle + LightTravel drop + close (no reopen; see beam.release_timeline).
	RELEASE_PLAYER = 77,
	DEPARTING = 40,
}

C.COOLDOWN_ROOMS = 3
C.SMALL_NPC_SIZE = 16
-- Legacy single-target tick (removed from live path; kept for probe/history).
C.LASER_TICK = 5
C.LASER_DAMAGE_MULT = 2
C.POST_RELEASE_SAFE = 30

-- LASER_SWEEP (V10.4): cone mains + lamp secs; visual extend/retract past screen.
C.LASER = {
	-- Legacy alias; cone COUNT is authoritative for mains.
	MAIN_COUNT = 6,
	MAIN_ROTATE_DEG = 3, -- cone SPEED_DEG alias
	MAIN_DMG_MULT = 1.5,
	SEC_DMG_MULT = 0.5,
	SEC_ACTIVE_MAX = 10,
	-- Secondary fire includes extend+stable+retract (was 8–12).
	SEC_FIRE_MIN = 14,
	SEC_FIRE_MAX = 20,
	SEC_CD_MIN = 18,
	SEC_CD_MAX = 28,
	SEC_ANGLE_JITTER = 25,
	SEC_START = 8,
	SEC_STOP = 56,
	MAIN_WIND_DOWN = 56,
	-- Visual lifecycle (POST_UPDATE 30Hz).
	MAIN_EXTEND_FRAMES = 5,
	MAIN_RETRACT_FRAMES = 7,
	SEC_EXTEND_FRAMES = 3,
	SEC_RETRACT_FRAMES = 4,
	VISUAL_SCREEN_OVERSHOOT_PX = 72,
	-- Tech laser fire SFX (SoundEffect.SOUND_HAND_LASERS = Technology).
	TECH_SFX_ID = nil, -- resolved at runtime; fallback SoundEffect.SOUND_HAND_LASERS
	TECH_SFX_MAIN_VOL = 0.80,
	TECH_SFX_SEC_VOL = 0.40,
	TECH_SFX_SEC_COOLDOWN = 6,
	-- Technology collision variant (LaserVariant.THIN_RED=2). Visual is custom ANM2.
	TECH_VARIANT_FALLBACK = 2,
	-- Main: fixed bright cyan-white (assembled gray-white tech sheet).
	MAIN_COLORIZE = {
		r = 0.90, g = 1.00, b = 1.00, a = 1.00,
		ro = 0.18, go = 0.35, bo = 0.30,
		cr = 0.65, cg = 1.00, cb = 0.92, amount = 1.00,
	},
	SEC_COLORIZE_AMOUNT = 1.0,
	SEC_OFFSET_FLOOR = { ro = 0.14, go = 0.22, bo = 0.16 },
	OWN_VISUAL = true,
	VISUAL_ANM2 = "gfx/mimics/Alien_savior/laser/alien_tech_laser.anm2",
	-- Cone main array (guide ellipse defines direction only; lasers extend for damage).
	CONE = {
		COUNT = 6,
		SPEED_DEG = 3,
		PHASE0 = 0,
		BASE_OFFSET_Y = 70,
		RADIUS_X = 95,
		RADIUS_Y = 28,
		BACK_WIDTH = 0.82,
		FRONT_WIDTH = 1.10,
		BACK_ALPHA = 0.65,
		FRONT_ALPHA = 1.00,
		BACK_BRIGHTNESS = 0.75,
		FRONT_BRIGHTNESS = 1.00,
	},
	-- Traction beam fade when entering LASER_SWEEP (frames @ 30Hz).
	BEAM_FADE_FRAMES = 8,
	BEAM_FADE_ALPHA = 0.10,
	BEAM_FADE_WIDTH = 0.60,
	MUZZLE_OUT = 5,
	SEC_DEPTH = 900,
	MAIN_DEPTH_FRONT = 500,
	MAIN_DEPTH_BACK = -200,
	LAMP_FLASH_FRAMES = 6,
	PIVOT_X = 128,
	PIVOT_Y = 64,
}

C.UFO_SCALE = 1.0
-- Distance from player/work feet to emitter mouth (world units).
C.UFO_HOVER_HEIGHT = 84
C.UFO_HOVER_Y = -84 -- legacy alias
C.UFO_OVERSHOOT = 6
C.UFO_HOVER_BOB = 1.5
-- Stowed player cabin anchor relative to UFO pivot (world units). Default: pivot itself.
C.UFO_CABIN_OFFSET_Y = 0
-- Half visible size used for off-screen margin (≈216×83 art @ scale 1).
C.UFO_HALF_W = 110
C.UFO_HALF_H = 50
C.UFO_OFFSCREEN_MARGIN = 24

-- Emitter tip relative to ANM2 pivot (128,64) @ scale 1.
C.MOUTH_OFFSET = Vector(0, 22)

C.BEAM_HALF_WIDTH = 18
C.BEAM_WIDTH = 1.0
C.BEAM_OPACITY = 0.85
-- ARRIVING: fraction after which pickup beam begins opening (finishes at phase end).
C.BEAM_OPEN_START = 0.55
C.BEAM_CLOSE_END = 0.35
C.BEAM_NATIVE_HEIGHT = 128
-- Cone PNG opaque 0..127 with YPivot=0 → visible height 128px @ scale 1.
C.BEAM_CONE_VISIBLE_H = 128
-- Pull ground center slightly onto cone bottom (screen px) to hide the seam.
C.BEAM_SEAM_OVERLAP_PX = 2
C.BEAM_WORK_WIDTH = 1.85
C.BEAM_WORK_LENGTH = 110
C.BEAM_TRANSIT_CLOSE = 10
C.BEAM_WORK_OPEN = 15
-- RELEASE: carry lit beam to release point (no shutdown/reopen).
C.BEAM_RELEASE_TRAVEL = 24
C.BEAM_RELEASE_SETTLE = 6
C.BEAM_RELEASE_CLOSE = 12
C.BEAM_SMOOTH = {
	open = 0.14,
	width = 0.14,
	alpha = 0.16,
	color = 0.14,
	foot = 0.18,
}

C.LIGHT_WORK_SPEED = 1.5

C.ANIM_NAME = "LightTravel"
-- Verified from vanilla 001.000_player.anm2 / Qing reloader skins: FrameNum=36.
-- Glow/body: ~13px rise through ~28, fast lift (-30 @32–33), sky-stretch (-200 @34–35).
-- Default capture keeps the takeoff + fast lift, cuts before stretch. Probe may override.
C.LIGHTTRAVEL_FRAME_NUM = 36
C.LIGHTTRAVEL_LAST_FRAME = 35
C.LIGHTTRAVEL_CAPTURE_FRAME = 32
-- Scrubbing uses PlayExtraAnimation+SetFrame (Day Dreamer pattern).
-- AnimateLightTravel() is for natural full play only — do not mix with scrubbing.

-- Align with grid_rock_topology.ROCK_TYPES. Policy prefers is_rock_type(); this is the UFO mirror list.
C.ROCK_OK = {
	[GridEntityType.GRID_ROCK] = true,
	[GridEntityType.GRID_ROCK_ALT] = true,
	[GridEntityType.GRID_ROCK_ALT2] = true,
	[GridEntityType.GRID_ROCK_GOLD] = true,
	[GridEntityType.GRID_ROCKT] = true,
	[GridEntityType.GRID_ROCK_SS] = true,
	[GridEntityType.GRID_ROCK_SPIKED] = true,
	[GridEntityType.GRID_ROCK_BOMB] = true,
}

-- Circular suction (ABDUCT_TARGETS). Durations @ MC_POST_UPDATE 30Hz.
C.SUCTION = {
	SCAN_DURATION = 45,
	MIN_WORK = 45,
	TAIL_GRACE = 8,
	MAX_WORK = 150,
	SHAKE_FRAMES = 3,
	APPROACH_DUR = 12,
	LIFT_DUR = 14,
	APPROACH_JITTER = 4,
	LIFT_SCALE_END = 0.12,
	TINT = { r = 0.82, g = 1.0, b = 0.95, a = 1.0, ro = 0.0, go = 0.04, bo = 0.08 },
	-- Progressive cyan overlay on original Color (smoothstep progress).
	-- shaking=0; approaching→0.75; ascending→1. Continuous at state boundary.
	TINT_APPROACH_PEAK = 0.75,
	TINT_ASCEND_PEAK = 1.0,
	-- Per-kind motion (same Job FSM; only durations differ).
	KIND = {
		projectile = { shake = 2, approach = 8, lift = 8 },
		npc = { shake = 4, approach = 12, lift = 14 },
		grid = { shake = 5, approach = 16, lift = 16 },
	},
	-- During scan, re-scan room every N frames for newly eligible enemies (deduped).
	CANDIDATE_REFRESH = 5,
}

C.SFX = {
	SOS_SEARCH_VOL = 0.7,
	SOS_CONNECTED_VOL = 0.8,
	UFO_ARRIVAL_VOL = 0.8,
	UFO_HOVER_VOL = 0.3,
	HOVER_START_DELAY = 40,
	HOVER_FADE_FRAMES = 12,
	TECH_LASER_MAIN_VOL = 0.80,
	TECH_LASER_SEC_VOL = 0.40,
	TECH_LASER_SEC_COOLDOWN = 6,
}

-- First SOS acknowledgement: UFO silhouette flyover (no entity, no freeze).
-- Path is screen-space (locked at start) so large rooms still see a full cross.
C.SOS_SHADOW_ANM2 = "gfx/mimics/Alien_savior/Alien_shadow.anm2"
C.SOS_SHADOW_DELAY = 12 -- wait after SOS connect before silhouette appears
C.SOS_SHADOW_DURATION = 20 -- fly frames @ MC_POST_UPDATE 30Hz ≈ 0.67s
C.SOS_SHADOW_SCALE = 1.5
C.SOS_SHADOW_ALPHA = 0.18
C.SOS_SHADOW_TEX_W = 256
C.SOS_SHADOW_TEX_H = 128
C.SOS_SHADOW_MARGIN_PX = 16 -- extra screen px beyond half-size so silhouette fully clears
-- path mix: RandomFloat < CROSS_CHANCE → full cross; else corner skim.
C.SOS_SHADOW_CROSS_CHANCE = 0.40
-- Closest approach: ~25%–45% of shadow rectangle inside the screen.
C.SOS_SHADOW_CORNER_INSET = 0.30

return C
