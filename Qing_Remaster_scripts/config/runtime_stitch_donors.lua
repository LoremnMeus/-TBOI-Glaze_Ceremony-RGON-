-- Curated Runtime Stitch donors only. No A×B combinatorial generation.
-- Gate3 still validates with fly_wing alone.
local donors = {
	fly_wing = {
		id = "fly_wing",
		label = "Fly wing (Gate2.5 organ graft / Gate3 splice donor)",
		type = 18,
		variant = 0,
		subtype = 0,
		animation_candidates = { "Fly", "Idle", "WalkHoriz", "WalkVert", "Walk" },
		target_size = 128,
		cut = {
			origin = { 0.5, 0.5 },
			normal = { 1.0, 0.0 },
			keep_sign = -1.0,
			feather = 0.0,
		},
		-- Joint in donor image UV space. Normal points toward host / discarded side.
		donor_joint = {
			uv = { 0.5, 0.5 },
			normal = { -1.0, 0.0 },
		},
		attach = {
			-- Scan direction for FindHostEdge (sprite-local; FlipX/Y applied at runtime).
			scan_direction = { 1.0, -0.2 },
			normalized_host_offset = { 0.85, -0.1 }, -- Size fallback only
			donor_offset = { 0.0, 0.0 },
			rotation = 0,
			scale = 1.0,
			-- Gate3 validation: front so the organ stays visible over the host.
			-- Switch to "behind" only after the joint clearly sticks past the silhouette.
			draw_order = "front",
			use_host_edge = true,
			show_seam = false,
		},
		trait = "wing_placeholder",
	},
}

return donors
