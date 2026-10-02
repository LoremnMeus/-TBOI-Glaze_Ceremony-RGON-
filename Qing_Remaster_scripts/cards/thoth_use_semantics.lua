-- 透特牌使用语义：Attempt ≠ Commit / Abort。
-- 「真正成功使用」才算一次透特牌使用；MC_USE_CARD 只表示开始尝试。
-- policy: immediate（默认）/ deferred / no_effect

local card_registry = require("Qing_Remaster_scripts.cards.card_registry")

local M = {}

local VALID = {
	immediate = true,
	deferred = true,
	no_effect = true,
}

-- GetPtrHash(player) -> { card_id, state="pending", frame, reason }
local pending = {}
local commit_listeners = {}
local last_event = nil

local function player_key(player)
	if not player then return nil end
	local ok, h = pcall(function() return GetPtrHash(player) end)
	if ok and h then return h end
	return nil
end

local function game_frame()
	local ok, n = pcall(function() return Game():GetFrameCount() end)
	if ok then return n end
	return -1
end

local function note(kind, player, card_id, reason, extra)
	last_event = {
		kind = kind,
		card_id = card_id,
		reason = reason,
		frame = game_frame(),
		extra = extra,
	}
	return last_event
end

function M.get_policy(card_id)
	local meta = card_registry.get(card_id)
	local res = meta and meta.use_resolution or nil
	if type(res) == "string" and VALID[res] then
		return res
	end
	return "immediate"
end

function M.get_last_event()
	return last_event
end

function M.format_last_event()
	local ev = last_event
	if not ev then
		return "尚无透特牌使用记录"
	end
	local lines = {
		string.format("状态：%s", tostring(ev.kind)),
		string.format("卡牌：%s", tostring(ev.card_id)),
		string.format("原因：%s", tostring(ev.reason or "-")),
		string.format("帧：%s", tostring(ev.frame)),
	}
	if ev.extra then
		for k, v in pairs(ev.extra) do
			lines[#lines + 1] = string.format("%s：%s", tostring(k), tostring(v))
		end
	end
	return table.concat(lines, "\n")
end

function M.on_commit(fn)
	if type(fn) ~= "function" then return false end
	commit_listeners[#commit_listeners + 1] = fn
	return true
end

function M.clear_pending(player)
	local key = player_key(player)
	if key then pending[key] = nil end
end

function M.begin(player, card_id, reason)
	local key = player_key(player)
	if not key or card_id == nil then return false end
	pending[key] = {
		card_id = card_id,
		state = "pending",
		frame = game_frame(),
		reason = reason or "begin",
	}
	note("PENDING", player, card_id, reason or "begin")
	return true
end

--- 幂等：同一 pending 只成功一次；无 pending 时仅 immediate 允许直提。
function M.commit(player, card_id, reason)
	local key = player_key(player)
	if not key or card_id == nil then return false end
	local txn = pending[key]
	if txn then
		if txn.state ~= "pending" then
			return false
		end
		if txn.card_id ~= card_id then
			return false
		end
		pending[key] = nil
	else
		if M.get_policy(card_id) == "deferred" then
			return false
		end
	end

	note("COMMITTED", player, card_id, reason or "commit")
	for i = 1, #commit_listeners do
		local fn = commit_listeners[i]
		pcall(fn, player, card_id, reason or "commit")
	end
	return true
end

function M.abort(player, card_id, reason)
	local key = player_key(player)
	if key then
		local txn = pending[key]
		if txn and (card_id == nil or txn.card_id == card_id) then
			pending[key] = nil
		end
	end
	note("ABORTED", player, card_id, reason or "abort")
	return true
end

function M.note_no_effect(player, card_id, reason)
	local key = player_key(player)
	if key then pending[key] = nil end
	note("NO_EFFECT", player, card_id, reason or "no_effect")
	return true
end

--- Book / consumers：在已过滤的真实实体 MC_USE_CARD 上调用。
function M.resolve_use_card(player, card_id)
	local policy = M.get_policy(card_id)
	if policy == "immediate" then
		M.begin(player, card_id, "use_card")
		return M.commit(player, card_id, "immediate")
	elseif policy == "deferred" then
		return M.begin(player, card_id, "use_card")
	elseif policy == "no_effect" then
		return M.note_no_effect(player, card_id, "use_resolution_no_effect")
	end
	return false
end

return M
