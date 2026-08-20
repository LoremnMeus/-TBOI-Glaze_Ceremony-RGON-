local M = {
	ToCall = {},
	core = nil,
}

function M.bind(core)
	M.core = core
end

return M
