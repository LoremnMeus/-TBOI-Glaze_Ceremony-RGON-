-- Incandescence Flame / 焚火 visual defaults.
-- Probe tunables, not final combat balance. Clocks are game logic frames (30 Hz).

local C = {
	ANM2 = "gfx/mimics/Incandescence_Flame/flame.anm2",
	LENGTH = 300,
	HALF_WIDTH = 95,
	MOUTH_WIDTH = 14,
	FLOW = 16,
	JET_SECONDS = 0.75,
	AFTERGLOW_SECONDS = 0.45,
	BODY_CAP = 100,
	CORE_CAP = 80,
	TONGUE_CAP = 55,
	EMBER_CAP = 62,
	BULGE_AMP = 0.16,
	MID_AMP = 0.07,
	EDGE_AMP = 0.02,
	BULGE_SPEED = 11,
	BULGE_COUNT = 4,
	HEAD_CURL = 0.65,
	TONGUE_DENSITY = 0.45,
	CORE_FRAC = 0.45,
	ORANGE_FRAC = 0.78,
	GOLD_FRAC = 0.47,
	WHITE_FRAC = 0.09,
	CAP_DEPTH = { outer = 0.34, orange = 0.30, gold = 0.22, white = 0.15 },
	CAP_DEPTH_MAX = { outer = 72, orange = 52, gold = 32, white = 14 },
	WAVE_LARGE = 0.35,
	WAVE_MID = 0.20,
	WAVE_SMALL = 0.08,
	SPACING = 5,
	TURN_EXTENT = 40,
	CLOSED_TIP_WIDTH_SCALE = 0.90,
	STREAM_CAP = 192,
	HARD_STREAM_CAP = 320,
	SEGMENT_CAP = 16,
	MID_SEGMENT_CAP = 24,
	HARD_SEGMENT_CAP = 32,
	SOLID = "gfx/mimics/Incandescence_Flame/solid.png",
	SOLID_ANM2 = "gfx/mimics/Incandescence_Flame/solid_pixel.anm2",
	ORB_ANM2 = "gfx/mimics/Incandescence_Flame/fire_orbs.anm2",
	SOLID_PX = 4,
	LOGIC_HZ = 30,
}

C.COLOR = {
	outer = { r = 182 / 255, g = 58 / 255, b = 25 / 255 },
	orange = { r = 244 / 255, g = 119 / 255, b = 32 / 255 },
	gold = { r = 1, g = 192 / 255, b = 47 / 255 },
	white = { r = 1, g = 242 / 255, b = 172 / 255 },
}

C.BODY = {}
C.CORE = {}
C.TONGUE = {}
C.PUFF = {}
C.EMBER = {}
C.SMOKE = {}
for i = 1, 8 do C.BODY[i] = "Body" .. i end
for i = 1, 8 do C.CORE[i] = "Core" .. i end
for i = 1, 12 do C.TONGUE[i] = "Tongue" .. i end
for i = 1, 6 do C.PUFF[i] = "Puff" .. i end
for i = 1, 6 do C.EMBER[i] = "Ember" .. i end
for i = 1, 4 do C.SMOKE[i] = "Smoke" .. i end

function C.logic_frames(seconds)
	return math.max(1, math.floor(seconds * C.LOGIC_HZ + 0.5))
end

return C
