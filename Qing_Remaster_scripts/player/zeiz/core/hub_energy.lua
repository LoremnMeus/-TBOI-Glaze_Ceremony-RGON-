local M = {
	core = nil,
}

function M.bind(core)
	M.core = core
end

function M.get()
	local data = M.core.save.data()
	data.hub.energy = data.hub.energy or { stored = 0 }
	return data.hub.energy
end

-- 第一阶段永远成功，不扣任何资源。Bethany 之后再改成抽取主动充能。
function M.request(amount, reason)
	amount = tonumber(amount) or 0
	reason = reason or "UNSPECIFIED"
	amount = M.core.hooks.modify("ModifyEnergyCost", amount, reason)
	if amount <= 0 then return true end
	return true
end

return M
