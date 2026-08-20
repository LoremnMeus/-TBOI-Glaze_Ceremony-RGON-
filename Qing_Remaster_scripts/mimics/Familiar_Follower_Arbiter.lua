-- Familiar follower/delayed 队列裁断器。
-- 多个控制器共享首次脱队前的原始状态；任一请求仍存在时保持脱队，最后一个释放时恢复。
local item = {
	own_key = "Familiar_Follower_Arbiter_",
}

local STATE_KEY = item.own_key.."state"

local function state_of(fam, create)
	if not fam then return nil end
	local d = fam:GetData()
	local state = d[STATE_KEY]
	if not state and create then
		local delay = nil
		if fam.GetMoveDelayNum then
			local ok, value = pcall(function() return fam:GetMoveDelayNum() end)
			if ok then delay = value end
		end
		state = {
			original_follower = fam.IsFollower == true,
			original_delayed = fam.IsDelayed == true,
			original_move_delay = delay,
			claims = {},
		}
		d[STATE_KEY] = state
	end
	return state
end

local function apply_claims(fam, state)
	local detach_follower, detach_delayed = false, false
	for _, claim in pairs(state.claims) do
		detach_follower = detach_follower or claim.followers == true
		detach_delayed = detach_delayed or claim.delayed == true
	end
	if detach_follower and fam.RemoveFromFollowers then fam:RemoveFromFollowers() end
	if detach_delayed then
		if fam.RemoveFromDelayed then fam:RemoveFromDelayed() end
		if fam.SetMoveDelayNum then pcall(function() fam:SetMoveDelayNum(0) end) end
	end
end

function item.claim(fam, owner, opts)
	if not fam or owner == nil then return false end
	opts = opts or {}
	local state = state_of(fam, true)
	state.claims[tostring(owner)] = {
		followers = opts.followers ~= false,
		delayed = opts.delayed == true,
	}
	apply_claims(fam, state)
	return true
end

function item.maintain(fam)
	local state = state_of(fam, false)
	if not state then return false end
	apply_claims(fam, state)
	return true
end

function item.original_state(fam)
	local state = state_of(fam, false)
	if not state then
		return {
			is_follower = fam and fam.IsFollower == true or false,
			is_delayed = fam and fam.IsDelayed == true or false,
			move_delay_num = nil,
		}
	end
	return {
		is_follower = state.original_follower,
		is_delayed = state.original_delayed,
		move_delay_num = state.original_move_delay,
	}
end

function item.release(fam, owner)
	if not fam or owner == nil then return false end
	local d = fam:GetData()
	local state = d[STATE_KEY]
	if not state then return false end
	state.claims[tostring(owner)] = nil
	if next(state.claims) ~= nil then
		apply_claims(fam, state)
		return true
	end
	if state.original_follower then
		if fam.AddToFollowers then fam:AddToFollowers() end
	elseif fam.RemoveFromFollowers then
		fam:RemoveFromFollowers()
	end
	if state.original_delayed then
		if fam.AddToDelayed then fam:AddToDelayed() end
		if state.original_move_delay ~= nil and fam.SetMoveDelayNum then
			pcall(function() fam:SetMoveDelayNum(state.original_move_delay) end)
		end
	elseif fam.RemoveFromDelayed then
		fam:RemoveFromDelayed()
	end
	d[STATE_KEY] = nil
	return true
end

return item
