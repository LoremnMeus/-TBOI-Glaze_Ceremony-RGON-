local M = {
	core = nil,
	KINDS = {
		LOCK = true,
		PRICE = true,
		CONVERT = true,
		DENY = true,
		WASTE = true,
		REDIRECT = true,
		OVERRIDE = true,
		CHAIN = true,
		ENERGY_USE = true,
	},
}

function M.bind(core)
	M.core = core
end

local function history(data)
	data.management = data.management or {}
	data.management.eventHistory = data.management.eventHistory or {}
	return data.management.eventHistory
end

function M.emit(kind, payload, opts)
	opts = opts or {}
	if not kind or not M.KINDS[kind] then return false end
	payload = payload or {}
	payload.kind = kind
	payload.frame = Game():GetFrameCount()
	payload.floor = M.core.util.floor_id()
	payload.room = payload.room or M.core.util.room_index()
	if M.core.hooks.allow("BeforeManagementEvent", kind, payload) == false then
		return false
	end
	local data = M.core.save.data()
	local list = history(data)
	list[#list + 1] = {
		kind = kind,
		source = payload.source,
		frame = payload.frame,
		floor = payload.floor,
		room = payload.room,
		target = payload.targetId,
	}
	while #list > 20 do table.remove(list, 1) end
	if not opts.silent then
		M.core.interest.on_event(kind, payload)
	end
	M.core.hooks.run("AfterManagementEvent", kind, payload)
	return true
end

return M
