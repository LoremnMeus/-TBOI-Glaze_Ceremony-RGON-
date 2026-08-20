return function(core)
	core.admins.register({
		id = "META",
		name = "Meta-Administrator",
		name_zh = "元管理员",
		folly = nil,
		proposal_item = nil,
		candidate = false,
		interest = {
			CHAIN = 1.0,
			OVERRIDE = 1.0,
			ENERGY_USE = 0.5,
		},
	})
end
