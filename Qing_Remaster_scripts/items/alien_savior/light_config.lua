-- Alien Savior UFO light layer map / palette / semantic groups (runtime config only).
local CFG = {}

CFG.UFO_ANM2 = "gfx/mimics/Alien_savior/Alien_UFO.anm2"
CFG.ANIM = "Idle"

-- ANM2 layer order (bottom → top). Ids match Alien_UFO.anm2 / Alien_layer_test.anm2.
CFG.LAYERS = {
	{ id = 0, name = "body", group = "body" },
	{ id = 1, name = "cabin", group = "cabin" },
	{ id = 2, name = "bottom_core", group = "bottom_core" },
	{ id = 3, name = "p2_01", group = "bottom_blink_green" },
	{ id = 4, name = "p2_02", group = "ring_red_markers" },
	{ id = 5, name = "p2_03", group = "bottom_blink_green" },
	{ id = 6, name = "p2_04", group = "bottom_blink_green" },
	{ id = 7, name = "p2_05", group = "bottom_blink_green" },
	{ id = 8, name = "p2_06", group = "bottom_blink_green" },
	{ id = 9, name = "p2_07", group = "navigation_red" },
	{ id = 10, name = "p2_08", group = "ring_red_markers" },
	{ id = 11, name = "p2_09", group = "navigation_red" },
	{ id = 12, name = "p2_10", group = "bottom_blink_green" },
	{ id = 13, name = "p2_11", group = "navigation_red" },
	{ id = 14, name = "p2_12", group = "central_auxiliary" },
	{ id = 15, name = "p2_13", group = "navigation_red" },
	{ id = 16, name = "p2_14", group = "navigation_red" },
	{ id = 17, name = "p2_15", group = "navigation_red" },
	{ id = 18, name = "p2_16", group = "navigation_red" },
	{ id = 19, name = "p2_17", group = "central_auxiliary" },
	{ id = 20, name = "p2_18", group = "navigation_red" },
	{ id = 21, name = "p2_19", group = "bottom_blink_green" },
	{ id = 22, name = "p2_20", group = "navigation_red" },
	{ id = 23, name = "p2_21", group = "navigation_red" },
	{ id = 24, name = "p2_22", group = "navigation_red" },
	{ id = 25, name = "p2_23", group = "ring_red_markers" },
	{ id = 26, name = "p2_24", group = "navigation_red" },
	{ id = 27, name = "p2_25", group = "bottom_blink_green" },
	{ id = 28, name = "p2_26", group = "bottom_blink_green" },
	{ id = 29, name = "p2_27", group = "bottom_blink_green" },
	{ id = 30, name = "p2_28", group = "bottom_blink_green" },
	{ id = 31, name = "p2_29", group = "ring_red_markers" },
	{ id = 32, name = "p2_30", group = "bottom_blink_green" },
	{ id = 33, name = "ring_m120", group = "ring_main" },
	{ id = 34, name = "ring_m90", group = "ring_main" },
	{ id = 35, name = "ring_m60", group = "ring_main" },
	{ id = 36, name = "ring_base", group = "ring_main" },
	{ id = 37, name = "ring_p60", group = "ring_main" },
	{ id = 38, name = "ring_p90", group = "ring_main" },
	{ id = 39, name = "ring_p120", group = "ring_main" },
	-- V4: tip indicators split from bottom_core; keep Id=40 (append, do not renumber 0–39).
	{ id = 40, name = "bottom_core_indicators", group = "bottom_core_indicators" },
}

-- Runtime render pass (ANM2 order is not the player sandwich order).
CFG.RENDER_PASS = {
	bottom_core = "back",
	bottom_core_indicators = "front",
}

-- Screen-front spatial order (left → right). Not hue-tag order.
CFG.RING_SPATIAL = {
	"ring_p60",
	"ring_p120",
	"ring_p90",
	"ring_base",
	"ring_m90",
	"ring_m120",
	"ring_m60",
}

-- Confirmed by user (ANM2 toggle QA).
CFG.RING_RED_MARKERS = {
	"p2_02",
	"p2_08",
	"p2_23",
	"p2_29",
}

-- Manifest centroids.X — used for scan phase / left-right flash (not draw offsets).
CFG.LAYER_X = {
	p2_01 = 39.4,
	p2_02 = 49.2,
	p2_03 = 49.4,
	p2_04 = 61.9,
	p2_05 = 65.5,
	p2_06 = 76.3,
	p2_07 = 78.2,
	p2_08 = 80.1,
	p2_09 = 84.5,
	p2_10 = 87.3,
	p2_11 = 107.0,
	p2_12 = 111.0,
	p2_13 = 120.0,
	p2_14 = 121.5,
	p2_15 = 133.5,
	p2_16 = 135.2,
	p2_17 = 144.2,
	p2_18 = 148.2,
	p2_19 = 168.0,
	p2_20 = 173.3,
	p2_21 = 170.5,
	p2_22 = 177.2,
	p2_23 = 175.0,
	p2_24 = 180.5,
	p2_25 = 179.3,
	p2_26 = 189.5,
	p2_27 = 193.1,
	p2_28 = 205.4,
	p2_29 = 206.0,
	p2_30 = 216.0,
	cabin = 128.0,
	bottom_core = 127.8,
	bottom_core_indicators = 127.6,
	ring_p60 = 34.8,
	ring_p120 = 65.1,
	ring_p90 = 99.2,
	ring_base = 127.7,
	ring_m90 = 155.8,
	ring_m120 = 190.2,
	ring_m60 = 219.6,
}

-- Manifest centroids (texture space, UFO pivot 128,64). Laser secondary muzzle table.
CFG.LAYER_XY = {
	p2_01 = { x = 39.40, y = 65.80 },
	p2_02 = { x = 49.25, y = 51.25 },
	p2_03 = { x = 49.38, y = 68.75 },
	p2_04 = { x = 61.94, y = 66.09 },
	p2_05 = { x = 65.50, y = 72.50 },
	p2_06 = { x = 76.28, y = 75.67 },
	p2_07 = { x = 78.20, y = 24.00 },
	p2_08 = { x = 80.12, y = 48.88 },
	p2_09 = { x = 84.50, y = 77.33 },
	p2_10 = { x = 87.26, y = 67.68 },
	p2_11 = { x = 107.00, y = 28.50 },
	p2_12 = { x = 111.00, y = 59.50 },
	p2_13 = { x = 120.00, y = 27.75 },
	p2_14 = { x = 121.50, y = 59.00 },
	p2_15 = { x = 133.50, y = 59.00 },
	p2_16 = { x = 135.25, y = 27.75 },
	p2_17 = { x = 144.25, y = 59.42 },
	p2_18 = { x = 148.20, y = 28.60 },
	p2_19 = { x = 168.00, y = 67.79 },
	p2_20 = { x = 173.33, y = 14.67 },
	p2_21 = { x = 170.50, y = 77.33 },
	p2_22 = { x = 177.20, y = 24.00 },
	p2_23 = { x = 175.00, y = 48.50 },
	p2_24 = { x = 180.50, y = 32.50 },
	p2_25 = { x = 179.28, y = 75.72 },
	p2_26 = { x = 189.50, y = 72.50 },
	p2_27 = { x = 193.14, y = 66.14 },
	p2_28 = { x = 205.44, y = 68.89 },
	p2_29 = { x = 206.00, y = 51.29 },
	p2_30 = { x = 216.00, y = 65.83 },
}

CFG.DEFAULTS = {
	color_cycle = 90,
	chase_cycle = 45,
	master_brightness = 0.75,
	cabin_cycle = 90,
	nav_flash_cycle = 24,
	bottom_chase_cycle = 36,
}

-- Continuous RGB control points (wrap). Avoid HSV yellow spikes.
CFG.RING_PALETTE = {
	{ 0.25, 1.00, 0.75 }, -- teal
	{ 0.35, 0.85, 1.00 }, -- sky
	{ 0.25, 0.45, 1.00 }, -- blue
	{ 0.65, 0.30, 1.00 }, -- violet
	{ 1.00, 0.25, 0.65 }, -- magenta
	{ 1.00, 0.55, 0.25 }, -- warm orange
	{ 0.55, 1.00, 0.45 }, -- light green
}

CFG.CABIN_COLORS = {
	{ 0.55, 0.95, 0.90 },
	{ 0.45, 0.75, 1.00 },
	{ 0.55, 1.00, 0.70 },
}

-- Legacy RGB lookup still used by central_auxiliary.
CFG.CORE_BY_PHASE = {
	ARRIVING = { r = 0.35, g = 0.95, b = 0.70, a = 0.55 },
	ABDUCT_PLAYER = { r = 0.75, g = 1.00, b = 0.90, a = 1.00 },
	TRANSIT_TO_CENTER = { r = 0.55, g = 0.95, b = 0.80, a = 0.75 },
	ABDUCT_TARGETS = { r = 0.85, g = 1.00, b = 0.95, a = 1.00 },
	LASER_SWEEP = { r = 0.55, g = 0.85, b = 1.00, a = 1.00 },
	RELEASE_PLAYER = { r = 0.90, g = 1.00, b = 0.95, a = 1.00 },
	DEPARTING = { r = 0.40, g = 0.80, b = 0.70, a = 0.45 },
}

-- V4 bottom_core glow targets (Tint / Offset / Colorize amount). Alpha always 1 at render.
CFG.CORE_GLOW = {
	ARRIVING = {
		tint = { 0.50, 0.85, 0.72 },
		offset = { 0.02, 0.05, 0.04 },
		colorize = { 0.35, 0.95, 0.80, 0.15 },
		pulse_weight = 0.12,
	},
	ABDUCT_PLAYER = {
		tint = { 0.80, 1.00, 0.92 },
		offset = { 0.10, 0.22, 0.17 },
		colorize = { 0.55, 1.00, 0.90, 0.30 },
		pulse_weight = 0.28,
	},
	TRANSIT_TO_CENTER = {
		tint = { 0.60, 0.88, 0.82 },
		offset = { 0.04, 0.09, 0.08 },
		colorize = { 0.40, 0.95, 0.85, 0.20 },
		pulse_weight = 0.10,
	},
	ABDUCT_TARGETS = {
		tint = { 0.85, 1.00, 0.95 },
		offset = { 0.14, 0.25, 0.20 },
		colorize = { 0.45, 1.00, 0.85, 0.35 },
		pulse_weight = 0.18,
	},
	LASER_SWEEP = {
		tint = { 0.70, 0.88, 1.00 },
		offset = { 0.12, 0.18, 0.27 },
		colorize = { 0.55, 0.80, 1.00, 0.35 },
		pulse_weight = 0.06,
	},
	RELEASE_PLAYER = {
		tint = { 0.90, 1.00, 0.94 },
		offset = { 0.16, 0.27, 0.22 },
		colorize = { 0.78, 1.00, 0.92, 0.40 },
		pulse_weight = 0.22,
	},
	DEPARTING = {
		tint = { 0.48, 0.75, 0.72 },
		offset = { 0.01, 0.03, 0.03 },
		colorize = { 0.35, 0.90, 0.80, 0.10 },
		pulse_weight = 0.04,
	},
}

-- Indicators: same family, more stable (less pulse).
CFG.INDICATOR_GLOW = {
	ARRIVING = {
		tint = { 0.45, 0.95, 0.78 },
		offset = { 0.01, 0.04, 0.03 },
		colorize = { 0.30, 1.00, 0.75, 0.18 },
		pulse_weight = 0.04,
	},
	ABDUCT_PLAYER = {
		tint = { 0.85, 1.00, 0.92 },
		offset = { 0.08, 0.16, 0.12 },
		colorize = { 0.55, 1.00, 0.88, 0.28 },
		pulse_weight = 0.08,
	},
	TRANSIT_TO_CENTER = {
		tint = { 0.55, 0.95, 0.85 },
		offset = { 0.03, 0.07, 0.06 },
		colorize = { 0.35, 0.98, 0.82, 0.20 },
		pulse_weight = 0.03,
	},
	ABDUCT_TARGETS = {
		tint = { 0.80, 1.00, 0.90 },
		offset = { 0.08, 0.14, 0.11 },
		colorize = { 0.40, 1.00, 0.82, 0.25 },
		pulse_weight = 0.03,
	},
	LASER_SWEEP = {
		tint = { 0.65, 0.85, 1.00 },
		offset = { 0.06, 0.10, 0.16 },
		colorize = { 0.50, 0.78, 1.00, 0.22 },
		pulse_weight = 0.02,
	},
	RELEASE_PLAYER = {
		tint = { 0.90, 1.00, 0.94 },
		offset = { 0.10, 0.18, 0.14 },
		colorize = { 0.70, 1.00, 0.90, 0.30 },
		pulse_weight = 0.07,
	},
	DEPARTING = {
		tint = { 0.40, 0.70, 0.68 },
		offset = { 0.00, 0.02, 0.02 },
		colorize = { 0.30, 0.85, 0.75, 0.08 },
		pulse_weight = 0.02,
	},
}

CFG.CORE_SMOOTH = {
	tint = 0.16,
	offset = 0.20,
	colorize = 0.14,
	pulse = 0.16,
}

local name_to_layer = {}
for _, layer in ipairs(CFG.LAYERS) do
	name_to_layer[layer.name] = layer
end
CFG.BY_NAME = name_to_layer

local ring_index = {}
for i, name in ipairs(CFG.RING_SPATIAL) do
	ring_index[name] = i
end
CFG.RING_INDEX = ring_index

function CFG.group_of(name)
	local layer = name_to_layer[name]
	return layer and layer.group or "unclassified"
end

return CFG
