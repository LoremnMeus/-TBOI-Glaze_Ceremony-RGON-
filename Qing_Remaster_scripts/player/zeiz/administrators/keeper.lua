return function(core)
	core.admins.register({
		id = "KEEPER",
		name = "Keeper",
		name_zh = "店长",
		player_type = PlayerType.PLAYER_KEEPER,
		folly = nil,
		proposal_item = CollectibleType.COLLECTIBLE_BREAKFAST,
		candidate = true,
		eid_folly = {
			zh = "#{{Player14}} 愚见尚未揭示。",
			en = "#{{Player14}} Folly not yet revealed.",
		},
		interest = {
			PRICE = 2.0,
			LOCK = 1.0,
			WASTE = 1.0,
		},
	})
end
