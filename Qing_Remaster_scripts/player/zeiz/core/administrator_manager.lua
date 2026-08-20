local M = {
	core = nil,
	registry = {},
	order = {},
}

function M.bind(core)
	M.core = core
end

function M.register(info)
	if not info or not info.id then return end
	if M.registry[info.id] == nil then
		M.order[#M.order + 1] = info.id
	end
	M.registry[info.id] = info
	M.core.save.admin(info.id)
end

function M.ensure_all()
	for i = 1, #M.order do
		M.core.save.admin(M.order[i])
	end
end

function M.get(id)
	return M.registry[id]
end

function M.state(id)
	return M.core.save.admin(id)
end

function M.is_appointed(id)
	local st = M.state(id)
	return st and st.appointed == true
end

function M.appointed_ids()
	local list = {}
	for i = 1, #M.order do
		local id = M.order[i]
		if M.is_appointed(id) then list[#list + 1] = id end
	end
	return list
end

function M.unappointed_candidates()
	local list = {}
	for i = 1, #M.order do
		local id = M.order[i]
		local info = M.registry[id]
		if info and info.candidate ~= false and not M.is_appointed(id) then
			if info.can_appear == nil or info.can_appear() then
				list[#list + 1] = id
			end
		end
	end
	return list
end

function M.appoint(id)
	local info = M.registry[id]
	if not info then return false end
	local st = M.state(id)
	if st.appointed then return false end
	st.appointed = true
	st.floorAppointed = M.core.util.floor_id()
	return true
end

function M.display_name(id)
	local info = M.get(id)
	if not info then return tostring(id or "?") end
	if M.core.util.zh() then return info.name_zh or info.name or info.id end
	return info.name or info.id
end

function M.folly_eid(id)
	local info = M.get(id)
	local name = M.display_name(id)
	local zh = M.core.util.zh()
	local desc
	if info and info.eid_folly then
		desc = zh and info.eid_folly.zh or info.eid_folly.en
	end
	if desc == nil or desc == "" then
		desc = zh and "愚见尚未揭示。" or "Folly not yet revealed."
	end
	return { Name = name, Description = desc }
end

function M.clear_all()
	local data = M.core.save.data()
	data.administrators = {}
	M.ensure_all()
	data.hub.currentCandidates = {}
	data.hub.appointedThisVisit = false
end

return M
