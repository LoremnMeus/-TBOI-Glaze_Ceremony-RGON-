local M = {
	core = nil,
	threshold = 5,
	interested_at = 3,
	floor_cap = 8,
}

function M.bind(core)
	M.core = core
end

local function refresh_state(st)
	if st.proposal and st.proposal.ready then
		st.interestState = M.core.save.INTEREST_PROPOSAL
	elseif (st.interest or 0) >= M.interested_at then
		st.interestState = M.core.save.INTEREST_INTERESTED
	else
		st.interestState = M.core.save.INTEREST_NORMAL
	end
end

function M.on_event(kind, payload)
	local core = M.core
	local data = core.save.data()
	local mgmt = data.management
	mgmt.roomEventCounts = mgmt.roomEventCounts or {}
	mgmt.entityOnce = mgmt.entityOnce or {}
	local room = payload.room or core.util.room_index()
	if mgmt.roomIndex ~= room then
		mgmt.roomIndex = room
		mgmt.roomEventCounts = {}
	end
	mgmt.roomEventCounts[kind] = (mgmt.roomEventCounts[kind] or 0) + 1
	local room_n = mgmt.roomEventCounts[kind]
	local dim = 1 / (2 ^ (room_n - 1))
	local target_id = payload.targetId
	if target_id then
		local once_key = kind.."|"..tostring(target_id)
		if mgmt.entityOnce[once_key] then return end
		mgmt.entityOnce[once_key] = true
	end
	local listen_unappointed = data.debug and data.debug.listenUnappointed
	for i = 1, #core.admins.order do
		local id = core.admins.order[i]
		local info = core.admins.get(id)
		local st = core.admins.state(id)
		if info and st then
			local listening = st.appointed or listen_unappointed
			if listening and not (st.proposal and st.proposal.ready) then
				local weight = (info.interest and info.interest[kind]) or 0
				if weight > 0 then
					local gain = weight * dim
					gain = core.hooks.modify("ModifyInterestGain", gain, id, kind, payload)
					st.floorInterestGain = st.floorInterestGain or 0
					local remain = M.floor_cap - st.floorInterestGain
					if remain > 0 and gain > 0 then
						gain = math.min(gain, remain)
						st.interest = (st.interest or 0) + gain
						st.floorInterestGain = st.floorInterestGain + gain
						if st.interest >= M.threshold then
							st.proposal = st.proposal or {}
							st.proposal.ready = true
							st.interest = M.threshold
						end
						refresh_state(st)
					end
				end
			end
		end
	end
end

function M.add(id, amount)
	local st = M.core.admins.state(id)
	if not st then return end
	st.interest = math.max(0, (st.interest or 0) + (amount or 0))
	if st.interest >= M.threshold then
		st.proposal = st.proposal or {}
		st.proposal.ready = true
		st.interest = M.threshold
	end
	refresh_state(st)
end

function M.on_new_floor()
	for i = 1, #M.core.admins.order do
		local st = M.core.admins.state(M.core.admins.order[i])
		if st then st.floorInterestGain = 0 end
	end
	local mgmt = M.core.save.data().management
	mgmt.entityOnce = {}
	mgmt.roomEventCounts = {}
end

return M
