-- Shared visual/gameplay constants for reversed Sting (倒位密仪).
local C = {}

C.LINK_ANM2 = "gfx/cards/Card_Sting/ritual_link.anm2"
C.LINK_TEX_H = 64
C.TARGET_COLOR = Color(1, 0.2, 0.2, 1, 0.35, 0, 0)
C.COLOR_REFRESH = 3
C.HIT_FLASH_COLOR = Color(1, 0.45, 0.45, 1, 0.55, 0, 0)
C.HIT_FLASH_FRAMES = 4

-- Initial / fill-driven base dye (dark wine → brighter red).
C.BASE_R0, C.BASE_G0, C.BASE_B0, C.BASE_RO0 = 0.45, 0.16, 0.18, 0.05
C.BASE_R1, C.BASE_G1, C.BASE_B1, C.BASE_RO1 = 0.95, 0.22, 0.22, 0.28

-- Absorb flash timer (MC_POST_EFFECT_UPDATE / 30 Hz).
C.ABSORB_FLASH_FRAMES = 6
C.ABSORB_FLASH_ADD = 4
C.ABSORB_FLASH_MAX_FRAMES = 10

-- Extra-damage SFX (only when bonus > 0).
C.EXTRA_DMG_SFX_VOL = 0.85
C.EXTRA_DMG_SFX_PITCH_MIN = 0.95
C.EXTRA_DMG_SFX_PITCH_MAX = 1.05

-- Strand root sampling ellipse (inner ~75% of pentagram visual radii).
C.ANCHOR_RADIUS_X = 77
C.ANCHOR_RADIUS_Y = 26
C.STRAND_INNER_SCALE = 0.75
C.STRAND_MIN_SPACING = 12

-- Enemy attach (collision Size is only an approximation).
C.ENEMY_EMBED = 4
C.ENEMY_RADIUS_MIN = 8
C.ENEMY_RADIUS_MAX = 22
C.ENEMY_RADIUS_SCALE = 0.55

-- Link state timing (MC_POST_EFFECT_UPDATE / 30 Hz).
C.EXTEND_FRAMES = 10
C.RETRACT_FRAMES = 8
C.BEZIER_SAMPLES = 10
C.CURVE_BASE = 5.5
C.CURVE_SWAY = 1.2
C.LINK_BASE_WIDTH = 0.85
C.LINK_BASE_ALPHA = 0.72

-- Blood flight (cosmetic).
C.BLOOD_SPRAY_FRAMES = 5
C.BLOOD_PULL_FRAMES = 18
C.BLOOD_ABSORB_DIST = 30
C.BLOOD_FILL_PER_ORB = 0.045
C.BLOOD_FILL_DEATH = 0.035
C.BLOOD_FILL_VISUAL_LERP = 0.08
C.BLOOD_SCALE_MUL = 0.82
C.BLOOD_TRAIL = {
	min_radius = 0.16,
	max_radius = 0.08,
	scale = 0.55,
	local_offset = { x = 0, y = 0 },
	color = { r = 1, g = 1, b = 1, a = 1, ro = 0, go = 0, bo = 0 },
	colorize = { r = 1, g = 0.05, b = 0.05, a = 1 },
	reapply_color_each_sync = true,
}

-- Layer ids in Pentagram2_reversed.anm2
C.LAYER_BASE = 0
C.LAYER_BLOOD = 1
C.LAYER_GLOW = 2

return C
