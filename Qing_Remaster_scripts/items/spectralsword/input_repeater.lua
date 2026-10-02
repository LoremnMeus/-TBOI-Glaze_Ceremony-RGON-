-- 妖刀·逢魔输入层：Triggered 当帧立即 fire；Pressed 只做 hold-repeat。
-- 缓冲至多一项 pending_nav / pending_action（不覆盖、不积压）。
-- 时钟相对 MC_POST_PLAYER_UPDATE（约 60Hz）。
-- 对齐蓝图 / 透特之书面板基线：点按立即；约 22 帧后开始连发；之后每 6 帧一次。无二段加速。

local M = {}

M.DEFAULT_INITIAL_REPEAT_DELAY = 22
M.DEFAULT_REPEAT_INTERVAL = 6

M.INITIAL_REPEAT_DELAY = M.DEFAULT_INITIAL_REPEAT_DELAY
M.REPEAT_INTERVAL = M.DEFAULT_REPEAT_INTERVAL

local SLOT_KEYS = {"up", "down", "left", "right", "decrease", "increase"}

function M.create()
	local slots = {}
	for _, key in ipairs(SLOT_KEYS) do
		slots[key] = {held = 0}
	end
	return {
		slots = slots,
		pending_nav = nil,
		pending_action = nil, -- "extract" | "inject"
	}
end

function M.set_repeat_config(initial, interval)
	M.INITIAL_REPEAT_DELAY = math.max(1, math.floor(tonumber(initial) or M.DEFAULT_INITIAL_REPEAT_DELAY))
	M.REPEAT_INTERVAL = math.max(1, math.floor(tonumber(interval) or M.DEFAULT_REPEAT_INTERVAL))
end

function M.reset_repeat_config()
	M.INITIAL_REPEAT_DELAY = M.DEFAULT_INITIAL_REPEAT_DELAY
	M.REPEAT_INTERVAL = M.DEFAULT_REPEAT_INTERVAL
end

function M.get_repeat_config()
	return {
		initial = M.INITIAL_REPEAT_DELAY,
		interval = M.REPEAT_INTERVAL,
		default_initial = M.DEFAULT_INITIAL_REPEAT_DELAY,
		default_interval = M.DEFAULT_REPEAT_INTERVAL,
	}
end

local function slot_repeat_fire(slot)
	local h = slot.held or 0

	if h == M.INITIAL_REPEAT_DELAY then
		return true
	end

	if h > M.INITIAL_REPEAT_DELAY then
		return ((h - M.INITIAL_REPEAT_DELAY) % M.REPEAT_INTERVAL) == 0
	end

	return false
end

--- state = {
---   triggered = { up=bool, ... },
---   pressed = { up=bool, ... },
--- }
--- 返回 { nav=, action=, fired={...}, held_frames={...} }
function M.tick(input, state)
	state = state or {}
	local triggered = state.triggered or {}
	local pressed = state.pressed or {}
	local fired = {}
	local held_frames = {}

	for _, key in ipairs(SLOT_KEYS) do
		local slot = input.slots[key]
		local is_trig = triggered[key] == true
		local is_press = pressed[key] == true
		local fire = false

		if is_trig then
			fire = true
		end

		if is_press then
			slot.held = (slot.held or 0) + 1
			if not is_trig and slot_repeat_fire(slot) then
				fire = true
			end
		else
			slot.held = 0
		end

		fired[key] = fire
		held_frames[key] = slot.held or 0
	end

	local nav = nil
	if fired.up then nav = "up"
	elseif fired.down then nav = "down"
	elseif fired.left then nav = "left"
	elseif fired.right then nav = "right"
	end

	local action = nil
	if fired.decrease then action = "extract"
	elseif fired.increase then action = "inject"
	end

	return {
		nav = nav,
		action = action,
		fired = fired,
		held_frames = held_frames,
	}
end

function M.buffer_nav(input, direction)
	if direction and input.pending_nav == nil then
		input.pending_nav = direction
	end
end

function M.buffer_action(input, action)
	if input.pending_action == nil
		and (action == "extract" or action == "inject")
	then
		input.pending_action = action
	end
end

function M.clear(input)
	if not input then return end
	input.pending_nav = nil
	input.pending_action = nil
	for _, slot in pairs(input.slots or {}) do
		slot.held = 0
	end
end

--- @deprecated use M.clear
function M.clear_buffers(input)
	M.clear(input)
end

--- 在 HOVER 时消费缓冲；返回 {nav=, action=}（至多各一个）
function M.consume_buffers(input)
	local nav = input.pending_nav
	local action = input.pending_action
	input.pending_nav = nil
	input.pending_action = nil
	return {nav = nav, action = action}
end

M.SLOT_KEYS = SLOT_KEYS

return M
