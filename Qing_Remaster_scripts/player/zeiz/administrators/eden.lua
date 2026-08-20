return function(core)
	core.admins.register({
		id = "EDEN",
		name = "Eden",
		name_zh = "伊甸",
		player_type = PlayerType.PLAYER_EDEN,
		folly = nil,
		proposal_item = nil,
		candidate = true,
		eid_folly = {
			zh = "#{{Player9}} 愚见尚未揭示。",
			en = "#{{Player9}} Folly not yet revealed.",
		},
		interest = {
			CONVERT = 1.0,
			OVERRIDE = 1.0,
			CHAIN = 1.5,
		},
	})
end
