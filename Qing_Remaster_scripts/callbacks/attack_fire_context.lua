-- Explicit Attack Fire semantics context stack.
-- Adapters Peek() this during POST_FIRE_* / laser init; do not use a single global slot.
-- No dependency on attack_trigger_holder / adapters (avoid init cycles).

local M = {
	own_key = "attack_fire_context_",
}

local stack = {}
local next_token = 1

local VALID_MODES = {
	new_attack = true,
	inherit = true,
	untracked = true,
}

function M.is_valid_mode(mode)
	return mode ~= nil and VALID_MODES[mode] == true
end

function M.validate_mode(mode)
	if M.is_valid_mode(mode) then
		return mode
	end
	return nil
end

local function next_id()
	local t = next_token
	next_token = next_token + 1
	if next_token > 1e9 then
		next_token = 1
	end
	return t
end

--- Normalize legacy spawn-context modes onto fire modes.
function M.normalize_context(ctx)
	ctx = ctx or {}
	local out = {}
	for k, v in pairs(ctx) do
		out[k] = v
	end
	if out.mode == "ignore" then
		out.mode = "untracked"
	end
	if out.attack_ignore == true and (out.mode == nil or out.mode == "untracked") then
		out.mode = "untracked"
	end
	return out
end

function M.Push(ctx)
	local c = M.normalize_context(ctx)
	if not c.token then
		c.token = next_id()
	end
	stack[#stack + 1] = c
	return c
end

--- Pop top only. Token must match stack top — never silently repair nesting.
function M.Pop(token)
	local top = stack[#stack]
	if not top then
		error("attack fire context stack underflow")
	end
	if token == nil or top.token ~= token then
		error("attack fire context stack mismatch")
	end
	stack[#stack] = nil
	return top
end

function M.Peek()
	return stack[#stack]
end

function M.Depth()
	return #stack
end

function M.Reset()
	stack = {}
end

--- Run fn under context; always Pop this frame's token even on error (keeps traceback).
function M.With(ctx, fn)
	local pushed = M.Push(ctx)
	local token = pushed.token
	local ok, a, b, c, d = xpcall(fn, debug.traceback)
	M.Pop(token)
	if not ok then
		error(a)
	end
	return a, b, c, d
end

-- Aliases matching the design doc.
M.PushFireContext = M.Push
M.PopFireContext = M.Pop
M.PeekFireContext = M.Peek
M.WithFireContext = M.With

return M
