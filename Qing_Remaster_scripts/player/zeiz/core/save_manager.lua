local save = require("Qing_Remaster_scripts.core.savedata")

local M = {
	core = nil,
}

local INTEREST_NORMAL = "NORMAL"
local INTEREST_INTERESTED = "INTERESTED"
local INTEREST_PROPOSAL = "PROPOSAL"

function M.bind(core)
	M.core = core
end

function M.blank_admin()
	return {
		appointed = false,
		floorAppointed = nil,
		interest = 0,
		interestState = INTEREST_NORMAL,
		floorInterestGain = 0,
		proposal = {
			ready = false,
			offered = false,
			approved = false,
			rejected = false,
		},
		follyData = {},
		follyEnabled = true,
	}
end

function M.default()
	return {
		hub = {
			initialized = false,
			pendingEntry = false,
			currentCandidates = {},
			energy = {},
			open = false,
			transitionLock = false,
			appointedThisVisit = false,
			delay = 0,
			skipNextLevel = false,
			selectIndex = 1,
			last_open_dir = 9,
			last_open_dir_counter = 0,
			hub_index = nil,
			hub_dimension = 0,
			hub_floor = nil,
			origin_index = nil,
			origin_dimension = 0,
			origin_x = nil,
			origin_y = nil,
			trapdoor_room = nil,
		},
		administrators = {},
		management = {
			eventHistory = {},
			currentChain = nil,
			entityOnce = {},
			roomEventCounts = {},
			roomIndex = nil,
		},
		meta = {},
		debug = {
			forceCainCandidate = true,
			listenUnappointed = false,
		},
	}
end

function M.data()
	save.elses = save.elses or {}
	if type(save.elses.zeiz) ~= "table" then
		save.elses.zeiz = M.default()
	end
	local data = save.elses.zeiz
	data.hub = data.hub or M.default().hub
	data.administrators = data.administrators or {}
	data.management = data.management or M.default().management
	data.meta = data.meta or {}
	data.debug = data.debug or M.default().debug
	return data
end

function M.reset()
	save.elses = save.elses or {}
	save.elses.zeiz = M.default()
	if M.core and M.core.admins then
		M.core.admins.ensure_all()
	end
	return save.elses.zeiz
end

function M.admin(id)
	local data = M.data()
	data.administrators[id] = data.administrators[id] or M.blank_admin()
	local st = data.administrators[id]
	st.proposal = st.proposal or M.blank_admin().proposal
	st.follyData = st.follyData or {}
	if st.follyEnabled == nil then st.follyEnabled = true end
	if st.interestState == nil then st.interestState = INTEREST_NORMAL end
	return st
end

M.INTEREST_NORMAL = INTEREST_NORMAL
M.INTEREST_INTERESTED = INTEREST_INTERESTED
M.INTEREST_PROPOSAL = INTEREST_PROPOSAL

return M
