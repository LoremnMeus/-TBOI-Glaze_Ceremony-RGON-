local M = {
	core = nil,
	lists = {},
}

local NAMES = {
	"BeforeFollyExecution",
	"AfterFollyExecution",
	"BeforeManagementEvent",
	"AfterManagementEvent",
	"ModifyInterestGain",
	"BeforeProposalOffer",
	"ModifyProposal",
	"AfterProposalDecision",
	"ModifyEnergyCost",
	"CanContinueManagementChain",
	"ModifyFollyPriority",
}

function M.bind(core)
	M.core = core
	for i = 1, #NAMES do
		M.lists[NAMES[i]] = M.lists[NAMES[i]] or {}
	end
end

function M.add(name, fn)
	if not name or type(fn) ~= "function" then return end
	M.lists[name] = M.lists[name] or {}
	M.lists[name][#M.lists[name] + 1] = fn
end

function M.run(name, ...)
	local list = M.lists[name]
	if not list then return end
	for i = 1, #list do
		list[i](...)
	end
end

function M.allow(name, ...)
	local list = M.lists[name]
	if not list then return true end
	for i = 1, #list do
		if list[i](...) == false then return false end
	end
	return true
end

function M.modify(name, value, ...)
	local list = M.lists[name]
	if not list then return value end
	for i = 1, #list do
		local next_value = list[i](value, ...)
		if next_value ~= nil then value = next_value end
	end
	return value
end

return M
