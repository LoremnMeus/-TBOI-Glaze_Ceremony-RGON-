-- Phase Lab puzzle: discrete state machine only (not Sokoban).

local defs = require("Qing_Remaster_scripts.story.phase_lab.defs")
local state = require("Qing_Remaster_scripts.story.phase_lab.state")

local puzzle = {
	_tween = {}, -- id -> {from_pos, to_pos, frame, max}
	_debug_overlay = false,
}

local function run()
	return state.get_run(true)
end

function puzzle.set_debug_overlay(on)
	puzzle._debug_overlay = on == true
end

function puzzle.get_debug_overlay()
	return puzzle._debug_overlay == true
end

function puzzle.get_states()
	local r = run()
	return r.puzzle.states
end

function puzzle.is_solved()
	local r = run()
	return r.puzzle.solved == true
end

function puzzle.is_active()
	local r = run()
	return r.puzzle.active == true and not r.puzzle.solved
end

function puzzle.is_replay()
	local r = run()
	return r.puzzle.replay_mode == true
end

function puzzle.is_transitioning()
	local r = run()
	if r.puzzle.transitioning then return true end
	for _, _ in pairs(puzzle._tween) do
		return true
	end
	return false
end

function puzzle.matches_solution(states)
	states = states or puzzle.get_states()
	for id, target in pairs(defs.SOLUTION) do
		if (tonumber(states[id]) or -1) ~= target then
			return false
		end
	end
	return true
end

function puzzle.apply_states(states, opts)
	opts = opts or {}
	local r = run()
	for _, id in ipairs(defs.BLOCK_IDS) do
		local b = defs.BLOCKS[id]
		local n = tonumber(states and states[id])
		if n == nil then n = b.initial or 0 end
		n = math.floor(n) % math.max(1, b.count or 1)
		r.puzzle.states[id] = n
	end
	puzzle._tween = {}
	if opts.mark_solved then
		r.puzzle.solved = true
		r.puzzle.active = false
		r.puzzle.replay_mode = false
	elseif opts.clear_solved then
		r.puzzle.solved = false
	end
end

function puzzle.load_initial(opts)
	opts = opts or {}
	local r = run()
	puzzle.apply_states(defs.initial_states(), {clear_solved = true})
	r.puzzle.active = true
	r.puzzle.solved = false
	r.puzzle.transitioning = false
	r.puzzle.complete_timer = 0
	if opts.replay then
		r.puzzle.replay_mode = true
	end
end

function puzzle.load_solved(opts)
	opts = opts or {}
	local r = run()
	puzzle.apply_states(defs.solved_states(), {mark_solved = true})
	r.puzzle.active = false
	r.puzzle.replay_mode = false
	r.puzzle.transitioning = false
	r.puzzle.complete_timer = 0
	if opts.permanent then
		state.mark_puzzle_solved_permanent()
	end
end

--- RESET: runtime only. Never touches permanent puzzle_solved / materials.
function puzzle.reset_to_initial(opts)
	opts = opts or {}
	local r = run()
	local permanent_solved = state.is_puzzle_solved_permanent()
	puzzle.load_initial({replay = permanent_solved or opts.force_replay == true})
	r.puzzle.replay_mode = permanent_solved or opts.force_replay == true
	r.anchor.state = "idle"
	r.anchor.activate_timer = 0
	return true
end

function puzzle.force_complete(opts)
	opts = opts or {}
	puzzle.load_solved({permanent = opts.permanent ~= false})
	local r = run()
	r.puzzle.complete_timer = 0
	r.puzzle.transitioning = false
	return true
end

local function next_state(id)
	local b = defs.BLOCKS[id]
	local r = run()
	local cur = tonumber(r.puzzle.states[id]) or 0
	local count = math.max(1, b.count or 1)
	return (cur + 1) % count
end

function puzzle.try_advance(id, center, opts)
	opts = opts or {}
	if not id or not defs.BLOCKS[id] then return false, "bad_id" end
	local r = run()
	if r.puzzle.solved then return false, "already_solved" end
	if not r.puzzle.active and not opts.force then
		return false, "inactive"
	end
	if puzzle._tween[id] then return false, "busy" end
	if r.puzzle.transitioning then return false, "transitioning" end

	local from = tonumber(r.puzzle.states[id]) or 0
	local to = next_state(id)
	local from_pos = defs.block_world_pos(center, id, from)
	local to_pos = defs.block_world_pos(center, id, to)
	r.puzzle.states[id] = to
	puzzle._tween[id] = {
		from = from_pos,
		to = to_pos,
		frame = 0,
		max = defs.MOVE_FRAMES,
		kind = defs.BLOCKS[id].type,
	}

	if puzzle.matches_solution(r.puzzle.states) then
		r.puzzle.transitioning = true
		r.puzzle.complete_timer = defs.COMPLETE_HOLD_FRAMES
	end
	return true
end

function puzzle.presented_pos(center, id)
	local tw = puzzle._tween[id]
	if tw and tw.from and tw.to then
		local t = tw.frame / math.max(1, tw.max)
		if t < 0 then t = 0 end
		if t > 1 then t = 1 end
		return Vector(
			tw.from.X + (tw.to.X - tw.from.X) * t,
			tw.from.Y + (tw.to.Y - tw.from.Y) * t
		)
	end
	local r = run()
	return defs.block_world_pos(center, id, r.puzzle.states[id])
end

function puzzle.tick()
	local r = run()
	for id, tw in pairs(puzzle._tween) do
		tw.frame = (tw.frame or 0) + 1
		if tw.frame >= (tw.max or defs.MOVE_FRAMES) then
			puzzle._tween[id] = nil
		end
	end
	if r.puzzle.transitioning and r.puzzle.complete_timer > 0 then
		r.puzzle.complete_timer = r.puzzle.complete_timer - 1
		if r.puzzle.complete_timer <= 0 then
			r.puzzle.transitioning = false
			r.puzzle.solved = true
			r.puzzle.active = false
			r.puzzle.replay_mode = false
			state.mark_puzzle_solved_permanent()
			return "solved"
		end
	end
	return nil
end

function puzzle.completion_progress()
	local r = run()
	if not r.puzzle.transitioning then
		if r.puzzle.solved then return 1 end
		return 0
	end
	local max = defs.COMPLETE_HOLD_FRAMES
	return 1 - (r.puzzle.complete_timer / math.max(1, max))
end

function puzzle.segment_lit(id)
	local r = run()
	if r.puzzle.solved or r.puzzle.transitioning then return true end
	return (tonumber(r.puzzle.states[id]) or -1) == (defs.SOLUTION[id] or -2)
end

return puzzle
