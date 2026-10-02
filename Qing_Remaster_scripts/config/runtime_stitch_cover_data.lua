-- Hand-annotated cover ranges from Stitch Edition (AttributeDetail / CoverDetail).
-- Source: Mixturer resources/gfx/output/018_000_attack fly.lua
-- CoverDetail overrides AttributeDetail when present; Attack Fly uses AttributeDetail as-is.
-- st/ed = opaque Y extent inside the spritesheet frame (sheet pixels).

local cover = {
	-- EntityType.ATTACKFLY = 18
	["18.0.0"] = {
		id = "18.0.0",
		label = "Attack Fly",
		-- Layer 0 AttributeDetail keyed by CombinationID.
		attribute_detail = {
			[1] = { st = 12, ed = 20 }, -- Fly frame 0
			[2] = { st = 6, ed = 20 }, -- Fly frame 1 (wings up)
			[3] = { st = 12, ed = 20 }, -- Fly frame 2
			[4] = { st = 6, ed = 20 }, -- Fly frame 3 (wings up)
			[5] = { st = 25, ed = 37 },
			[6] = { st = 24, ed = 42 },
			[7] = { st = 18, ed = 42 },
			[8] = { st = 16, ed = 44 },
			[9] = { st = 21, ed = 47 },
			[10] = { st = 21, ed = 48 },
			[11] = { st = 20, ed = 49 },
			[12] = { st = 27, ed = 49 },
			[13] = { st = 26, ed = 28 },
			[16] = { st = 12, ed = 20 },
		},
		-- AttributeCombinations for layer 0 (crop → CombinationID).
		attribute_combinations = {
			[1] = { height = 32, width = 32, xcrop = 0, ycrop = 32, xpivot = 16, ypivot = 16 },
			[2] = { height = 32, width = 32, xcrop = 32, ycrop = 32, xpivot = 16, ypivot = 16 },
			[3] = { height = 32, width = 32, xcrop = 64, ycrop = 32, xpivot = 16, ypivot = 16 },
			[4] = { height = 32, width = 32, xcrop = 96, ycrop = 32, xpivot = 16, ypivot = 16 },
			[5] = { height = 64, width = 64, xcrop = 0, ycrop = 64, xpivot = 32, ypivot = 32 },
			[6] = { height = 64, width = 64, xcrop = 64, ycrop = 64, xpivot = 32, ypivot = 32 },
			[7] = { height = 64, width = 64, xcrop = 128, ycrop = 64, xpivot = 32, ypivot = 32 },
			[8] = { height = 64, width = 64, xcrop = 192, ycrop = 64, xpivot = 32, ypivot = 32 },
			[9] = { height = 64, width = 64, xcrop = 0, ycrop = 128, xpivot = 32, ypivot = 32 },
			[10] = { height = 64, width = 64, xcrop = 64, ycrop = 128, xpivot = 32, ypivot = 32 },
			[11] = { height = 64, width = 64, xcrop = 128, ycrop = 128, xpivot = 32, ypivot = 32 },
			[12] = { height = 64, width = 64, xcrop = 192, ycrop = 128, xpivot = 32, ypivot = 32 },
			[13] = { height = 64, width = 64, xcrop = 0, ycrop = 192, xpivot = 32, ypivot = 32 },
			[16] = { height = 32, width = 32, xcrop = 0, ycrop = 0, xpivot = 16, ypivot = 16 },
		},
		-- Fast path for the Fly loop (animation frame → CombinationID).
		anim_combination = {
			Fly = { [0] = 1, [1] = 2, [2] = 3, [3] = 4 },
		},
	},
}

function cover.get(type_id, variant, subtype)
	local key = string.format("%d.%d.%d", type_id or 0, variant or 0, subtype or 0)
	return cover[key]
end

return cover
