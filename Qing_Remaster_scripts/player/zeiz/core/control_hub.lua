local M = {
	ToCall = {},
	core = nil,
}

function M.bind(core)
	M.core = core
end

function M.is_open()
	if M.core.hub_room and M.core.hub_room.is_current() then return true end
	return M.core.save.data().hub.open == true
end

function M.legal_room()
	local room = Game():GetRoom()
	local level = Game():GetLevel()
	if not room or not level then return false end
	local idx = level:GetCurrentRoomIndex()
	if idx < 0 then return false end
	local rt = room:GetType()
	if rt == RoomType.ROOM_DUNGEON or rt == RoomType.ROOM_BOSS then return false end
	if rt == RoomType.ROOM_ERROR or rt == RoomType.ROOM_BLACK_MARKET then return false end
	if rt == RoomType.ROOM_DEVIL or rt == RoomType.ROOM_ANGEL then return false end
	if Game():GetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH) then return false end
	return true
end

function M.roll_candidates()
	local core = M.core
	local data = core.save.data()
	local pool = core.admins.unappointed_candidates()
	local picked = {}
	local used = {}
	if data.debug.forceCainCandidate and not core.admins.is_appointed("CAIN") then
		picked[#picked + 1] = "CAIN"
		used.CAIN = true
	end
	local rng = core.util.rng(Game():GetSeeds():GetStartSeed(), core.util.floor_id() + 7701)
	while #picked < 3 do
		local remain = {}
		for i = 1, #pool do
			local id = pool[i]
			if not used[id] then remain[#remain + 1] = id end
		end
		if #remain == 0 then break end
		local choice = remain[(rng:RandomInt(#remain) + 1)]
		picked[#picked + 1] = choice
		used[choice] = true
	end
	data.hub.currentCandidates = picked
	data.hub.selectIndex = 1
	data.hub.appointedThisVisit = false
	return picked
end

function M.open()
	if M.core.hub_room then
		return M.core.hub_room.enter()
	end
	return false
end

function M.close()
	if M.core.hub_room and M.core.hub_room.is_current() then
		return M.core.hub_room.leave()
	end
	local data = M.core.save.data()
	data.hub.open = false
	data.hub.transitionLock = false
	M.core.util.each_zeiz(function(player)
		player.ControlsEnabled = true
	end)
end

function M.schedule()
	if not M.core.util.any_zeiz() then return end
	local data = M.core.save.data()
	data.hub.pendingEntry = true
	data.hub.delay = 8
	data.hub.currentCandidates = {}
	data.hub.appointedThisVisit = false
	if M.core.hub_room then M.core.hub_room.ensure_placed() end
end

function M.appoint_id(id)
	local data = M.core.save.data()
	if data.hub.appointedThisVisit then return false end
	if not id then return false end
	if not M.core.energy.request(0, "APPOINT") then return false end
	if M.core.admins.appoint(id) then
		data.hub.appointedThisVisit = true
		return true
	end
	return false
end

function M.appoint_selected()
	local data = M.core.save.data()
	local idx = data.hub.selectIndex or 1
	return M.appoint_id(data.hub.currentCandidates[idx])
end

function M.try_enter()
	local data = M.core.save.data()
	if not data.hub.pendingEntry then return end
	if M.is_open() then return end
	if (data.hub.delay or 0) > 0 then
		data.hub.delay = data.hub.delay - 1
		return
	end
	if M.core.hub_room then
		M.core.hub_room.try_spawn_entrance()
	end
end

table.insert(M.ToCall, #M.ToCall + 1, {CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_, continue)
	local core = M.core
	if continue then
		core.admins.ensure_all()
		if core.save.data().hub.pendingEntry then M.schedule() end
		return
	end
	core.save.reset()
	core.admins.ensure_all()
	local data = core.save.data()
	data.hub.skipNextLevel = true
	if core.util.any_zeiz() then M.schedule() end
end,
})

table.insert(M.ToCall, #M.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
Function = function()
	local core = M.core
	if not core.util.any_zeiz() then return end
	core.interest.on_new_floor()
	local data = core.save.data()
	if data.hub.skipNextLevel then
		data.hub.skipNextLevel = false
		return
	end
	if core.hub_room then core.hub_room.reset_floor() end
	M.schedule()
end,
})

table.insert(M.ToCall, #M.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function()
	local data = M.core.save.data()
	if M.core.hub_room and M.core.hub_room.is_current() then
		M.core.util.each_zeiz(function(player)
			player.ControlsEnabled = true
		end)
		return
	end
	data.hub.open = false
	data.hub.transitionLock = false
	if data.hub.pendingEntry then data.hub.delay = math.max(data.hub.delay or 0, 6) end
	M.core.util.each_zeiz(function(player)
		player.ControlsEnabled = true
	end)
end,
})

table.insert(M.ToCall, #M.ToCall + 1, {CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function()
	M.try_enter()
end,
})

table.insert(M.ToCall, #M.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function()
	local data = M.core.save.data()
	data.hub.open = false
	data.hub.transitionLock = false
end,
})

return M
