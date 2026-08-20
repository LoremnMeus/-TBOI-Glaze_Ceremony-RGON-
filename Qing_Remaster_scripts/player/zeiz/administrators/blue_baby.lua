return function(core)
	core.admins.register({
		id = "BLUE_BABY",
		name = "???",
		name_zh = "???",
		player_type = PlayerType.PLAYER_BLUEBABY,
		folly = nil,
		proposal_item = nil,
		candidate = true,
		eid_folly = {
			zh = "#{{Player4}} 愚见尚未揭示。",
			en = "#{{Player4}} Folly not yet revealed.",
		},
		interest = {
			CONVERT = 1.0,
			DENY = 0.8,
			LOCK = 0.3,
		},
	})
end
