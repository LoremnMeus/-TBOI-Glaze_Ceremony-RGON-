return function(core)
	core.admins.register({
		id = "BETHANY",
		name = "Bethany",
		name_zh = "伯大尼",
		player_type = PlayerType.PLAYER_BETHANY,
		folly = nil,
		proposal_item = nil,
		candidate = true,
		eid_folly = {
			zh = "#{{Player18}} 愚见尚未揭示。",
			en = "#{{Player18}} Folly not yet revealed.",
		},
		interest = {
			ENERGY_USE = 2.0,
			CHAIN = 0.8,
		},
	})
end
