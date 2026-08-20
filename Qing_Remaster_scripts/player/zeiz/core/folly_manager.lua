local M = {
	core = nil,
	follies = {},
	order = {},
}

function M.bind(core)
	M.core = core
end

function M.register(id, spec)
	if not id or not spec then return end
	spec.id = id
	if M.follies[id] == nil then
		M.order[#M.order + 1] = id
	end
	M.follies[id] = spec
end

function M.active_list()
	local list = {}
	for i = 1, #M.order do
		local id = M.order[i]
		local spec = M.follies[id]
		if spec then
			local owner = spec.owner
			local st = owner and M.core.admins.state(owner)
			local enabled = (not owner) or (st and st.appointed and st.follyEnabled ~= false)
			if enabled then
				local pri = M.core.hooks.modify("ModifyFollyPriority", i, id)
				list[#list + 1] = { spec = spec, priority = pri or i }
			end
		end
	end
	table.sort(list, function(a, b) return (a.priority or 0) < (b.priority or 0) end)
	return list
end

function M.dispatch(hook, ctx)
	ctx = ctx or {}
	local list = M.active_list()
	for i = 1, #list do
		local spec = list[i].spec
		if spec[hook] then
			if M.core.hooks.allow("BeforeFollyExecution", spec.id, hook, ctx) then
				spec[hook](ctx)
				M.core.hooks.run("AfterFollyExecution", spec.id, hook, ctx)
			end
		end
	end
end

function M.set_enabled(admin_id, enabled)
	local st = M.core.admins.state(admin_id)
	if st then st.follyEnabled = enabled and true or false end
end

return M
