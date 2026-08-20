local M = {
	core = nil,
}

function M.bind(core)
	M.core = core
end

function M.ready_list()
	local list = {}
	for i = 1, #M.core.admins.order do
		local id = M.core.admins.order[i]
		local st = M.core.admins.state(id)
		if st and st.appointed and st.proposal and st.proposal.ready and not st.proposal.approved and not st.proposal.rejected then
			list[#list + 1] = id
		end
	end
	return list
end

function M.offer_pending()
	local list = M.ready_list()
	for i = 1, #list do
		local id = list[i]
		local info = M.core.admins.get(id)
		local st = M.core.admins.state(id)
		if info and st and not st.proposal.offered then
			if M.core.hooks.allow("BeforeProposalOffer", id, info) then
				st.proposal.offered = true
			end
		end
	end
	return list
end

function M.approve(id, player)
	local info = M.core.admins.get(id)
	local st = M.core.admins.state(id)
	if not info or not st or not st.proposal or not st.proposal.ready then return false end
	if st.proposal.approved then return false end
	local item_id = M.core.hooks.modify("ModifyProposal", info.proposal_item, id)
	player = player or M.core.util.zeiz_player()
	if player and item_id and item_id > 0 then
		player:AddCollectible(item_id, 0, false)
	end
	st.proposal.approved = true
	st.proposal.ready = false
	M.core.hooks.run("AfterProposalDecision", id, true, item_id)
	return true
end

function M.reject(id)
	local st = M.core.admins.state(id)
	if not st or not st.proposal then return false end
	st.proposal.rejected = true
	st.proposal.ready = false
	M.core.hooks.run("AfterProposalDecision", id, false, nil)
	return true
end

function M.force_ready(id)
	local st = M.core.admins.state(id)
	if not st then return false end
	st.proposal = st.proposal or {}
	st.proposal.ready = true
	st.proposal.offered = false
	st.proposal.approved = false
	st.proposal.rejected = false
	st.interest = M.core.interest.threshold
	st.interestState = M.core.save.INTEREST_PROPOSAL
	return true
end

return M
