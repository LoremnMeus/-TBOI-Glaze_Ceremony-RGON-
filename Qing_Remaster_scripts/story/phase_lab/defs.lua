-- Phase Lab constants + puzzle defs (data-driven).
-- Positions are offsets from room center (world units).

local defs = {}

defs.SCHEMA = 1
defs.OWN_KEY = "PhaseLab_"
defs.ROOM_VARIANT = 23610
defs.ROOM_TYPE = 1 -- ROOM_DEFAULT special-room pool entry
defs.GOTO = "s.default.23610"
defs.ROOM_NAME = "Phase_Lab"

-- Effect room markers: XML/BR Type 999; runtime ENTITY_EFFECT 1000.
defs.MARKER_ROOM_XML_TYPE = 999
defs.MARKER_RUNTIME_TYPE = EntityType.ENTITY_EFFECT
defs.ROOM_MARKER_NAME = "Phase Lab Room Marker"
defs.FIXTURE_NAME = "Phase Lab Fixture"

defs.MARKER = {
	CENTER = 1,
	ENTRY = 2,
	RESET = 3,
	TERMINAL = 4,
}

-- Fixture SubType
defs.FIX = {
	BLOCK_A = 1,
	BLOCK_B = 2,
	BLOCK_C = 3,
	BLOCK_D = 4,
	BLOCK_E = 5,
	BLOCK_F = 6,
	RESET = 10,
	SLOT_P1 = 11,
	SLOT_P2 = 12,
	SLOT_P3 = 13,
	SLOT_P4 = 14,
	SLOT_CAT = 15,
	ANCHOR = 16,
	TERMINAL = 17,
}

defs.BLOCK_IDS = {"A", "B", "C", "D", "E", "F"}

defs.BLOCK_FIX = {
	A = defs.FIX.BLOCK_A,
	B = defs.FIX.BLOCK_B,
	C = defs.FIX.BLOCK_C,
	D = defs.FIX.BLOCK_D,
	E = defs.FIX.BLOCK_E,
	F = defs.FIX.BLOCK_F,
}

defs.FIX_TO_BLOCK = {
	[defs.FIX.BLOCK_A] = "A",
	[defs.FIX.BLOCK_B] = "B",
	[defs.FIX.BLOCK_C] = "C",
	[defs.FIX.BLOCK_D] = "D",
	[defs.FIX.BLOCK_E] = "E",
	[defs.FIX.BLOCK_F] = "F",
}

defs.PROMPT_RADIUS = 36
defs.BLOCK_RADIUS = 18
defs.MOVE_FRAMES = 8 -- 30Hz → ~0.27s
defs.COMPLETE_HOLD_FRAMES = 50 -- ~1.7s complete sequence
defs.INTERACT = ButtonAction.ACTION_DROP

-- Material token map (4 Properties + Catalyst).
defs.MATERIALS = {
	property_1 = {
		token = "chapter1.material.coin",
		label = {zh = "P1 交换", en = "P1 Exchange"},
		short = "P1",
		fix = defs.FIX.SLOT_P1,
		offset = Vector(-90, -48),
	},
	property_2 = {
		token = "chapter1.material.glaze",
		label = {zh = "P2 映射", en = "P2 Mapping"},
		short = "P2",
		fix = defs.FIX.SLOT_P2,
		offset = Vector(90, -48),
	},
	property_3 = {
		token = "chapter1.material.stone",
		label = {zh = "P3 结构", en = "P3 Structure"},
		short = "P3",
		fix = defs.FIX.SLOT_P3,
		offset = Vector(-90, 48),
	},
	property_4 = {
		token = "chapter1.material.wind",
		label = {zh = "P4 方向", en = "P4 Direction"},
		short = "P4",
		fix = defs.FIX.SLOT_P4,
		offset = Vector(90, 48),
	},
	catalyst = {
		-- Not a chapter1 inventory token; Glaze holds Beast Residue after prologue.
		token = nil,
		catalyst = true,
		label = {zh = "催化剂", en = "Catalyst"},
		short = "CAT",
		fix = defs.FIX.SLOT_CAT,
		offset = Vector(0, -108),
	},
}

defs.LAYOUT = {
	anchor = Vector(0, 0),
	reset = Vector(-170, 118),
	terminal = Vector(170, 118),
	entry = Vector(0, 140),
}

-- Discrete puzzle pieces. Visual push → state + 1 (cyclic).
defs.BLOCKS = {
	A = {
		id = "A",
		type = "horizontal",
		origin = Vector(-100, -42),
		step = Vector(40, 0),
		count = 3,
		initial = 0,
		target = 1,
		label = "A",
	},
	B = {
		id = "B",
		type = "horizontal",
		origin = Vector(20, -42),
		step = Vector(40, 0),
		count = 3,
		initial = 0,
		target = 2,
		label = "B",
	},
	C = {
		id = "C",
		type = "vertical",
		origin = Vector(-44, -62),
		step = Vector(0, 40),
		count = 3,
		initial = 0,
		target = 1,
		label = "C",
	},
	D = {
		id = "D",
		type = "vertical",
		origin = Vector(44, -22),
		step = Vector(0, 40),
		count = 2,
		initial = 1,
		target = 0,
		label = "D",
	},
	E = {
		id = "E",
		type = "rotate",
		origin = Vector(-78, 42),
		count = 4, -- 0/90/180/270
		initial = 0,
		target = 3,
		label = "E",
	},
	F = {
		id = "F",
		type = "phase",
		origin = Vector(78, 42),
		count = 2,
		initial = 0,
		target = 1,
		label = "F",
	},
}

defs.SOLUTION = {
	A = 1,
	B = 2,
	C = 1,
	D = 0,
	E = 3,
	F = 1,
}

function defs.initial_states()
	local out = {}
	for _, id in ipairs(defs.BLOCK_IDS) do
		out[id] = defs.BLOCKS[id].initial or 0
	end
	return out
end

function defs.solved_states()
	local out = {}
	for _, id in ipairs(defs.BLOCK_IDS) do
		out[id] = defs.SOLUTION[id] or 0
	end
	return out
end

function defs.block_world_pos(center, id, state)
	local b = defs.BLOCKS[id]
	if not b or not center then return center end
	state = tonumber(state) or 0
	if b.type == "rotate" or b.type == "phase" then
		return center + b.origin
	end
	local step = b.step or Vector(0, 0)
	return center + b.origin + Vector(step.X * state, step.Y * state)
end

function defs.is_lab_variant(variant)
	return tonumber(variant) == defs.ROOM_VARIANT
end

return defs
