-- Phase Lab permanent + runtime state accessors.
-- Permanent: StoryProgress.phase_lab
-- Runtime:   StoryRun.phase_lab

local save = require("Qing_Remaster_scripts.core.savedata")
local story = require("Qing_Remaster_scripts.story.story_state")
local defs = require("Qing_Remaster_scripts.story.phase_lab.defs")

local state = {}

local function empty_permanent()
	return {
		discovered = false,
		puzzle_solved = false,
		anchor_activated_once = false,
	}
end

local function empty_run()
	return {
		schema = defs.SCHEMA,
		room_initialized = false,
		overlay_force = false,
		puzzle = {
			active = false,
			replay_mode = false,
			states = defs.initial_states(),
			solved = false,
			transitioning = false,
			complete_timer = 0,
		},
		materials = {
			property_1 = false,
			property_2 = false,
			property_3 = false,
			property_4 = false,
			catalyst = false,
		},
		anchor = {
			state = "idle",
			activate_timer = 0,
		},
		debug_catalyst = false,
	}
end

local function shape_permanent(p)
	p = type(p) == "table" and p or empty_permanent()
	if p.discovered == nil then p.discovered = false end
	if p.puzzle_solved == nil then p.puzzle_solved = false end
	if p.anchor_activated_once == nil then p.anchor_activated_once = false end
	return p
end

local function shape_run(r)
	local base = empty_run()
	if type(r) ~= "table" then return base end
	r.schema = r.schema or defs.SCHEMA
	r.room_initialized = r.room_initialized == true
	r.overlay_force = r.overlay_force == true
	r.puzzle = type(r.puzzle) == "table" and r.puzzle or base.puzzle
	r.puzzle.active = r.puzzle.active == true
	r.puzzle.replay_mode = r.puzzle.replay_mode == true
	r.puzzle.solved = r.puzzle.solved == true
	r.puzzle.transitioning = r.puzzle.transitioning == true
	r.puzzle.complete_timer = tonumber(r.puzzle.complete_timer) or 0
	local states = type(r.puzzle.states) == "table" and r.puzzle.states or {}
	local shaped = {}
	for _, id in ipairs(defs.BLOCK_IDS) do
		shaped[id] = tonumber(states[id]) or (defs.BLOCKS[id].initial or 0)
	end
	r.puzzle.states = shaped
	r.materials = type(r.materials) == "table" and r.materials or base.materials
	for key, _ in pairs(base.materials) do
		r.materials[key] = r.materials[key] == true
	end
	r.anchor = type(r.anchor) == "table" and r.anchor or base.anchor
	r.anchor.state = tostring(r.anchor.state or "idle")
	r.anchor.activate_timer = tonumber(r.anchor.activate_timer) or 0
	r.debug_catalyst = r.debug_catalyst == true
	return r
end

function state.get_permanent(create)
	local root = story.get_effective_root(create == true)
	if not root then return nil end
	if type(root.phase_lab) ~= "table" then
		if not create then return nil end
		root.phase_lab = empty_permanent()
	end
	root.phase_lab = shape_permanent(root.phase_lab)
	return root.phase_lab
end

function state.get_run(create)
	local root = story.get_effective_run_root(create == true)
	if not root then return nil end
	if type(root.phase_lab) ~= "table" then
		if not create then return nil end
		root.phase_lab = empty_run()
	end
	root.phase_lab = shape_run(root.phase_lab)
	return root.phase_lab
end

function state.mark_discovered()
	local p = state.get_permanent(true)
	if p then p.discovered = true end
end

function state.mark_puzzle_solved_permanent()
	local p = state.get_permanent(true)
	if p then p.puzzle_solved = true end
end

function state.mark_anchor_activated()
	local p = state.get_permanent(true)
	if p then p.anchor_activated_once = true end
end

function state.is_puzzle_solved_permanent()
	local p = state.get_permanent(false)
	return p and p.puzzle_solved == true
end

function state.set_permanent_flags(flags)
	local p = state.get_permanent(true)
	if not p or type(flags) ~= "table" then return end
	if flags.discovered ~= nil then p.discovered = flags.discovered == true end
	if flags.puzzle_solved ~= nil then p.puzzle_solved = flags.puzzle_solved == true end
	if flags.anchor_activated_once ~= nil then
		p.anchor_activated_once = flags.anchor_activated_once == true
	end
end

function state.reset_run_to_fresh()
	local root = story.get_effective_run_root(true)
	if not root then return nil end
	root.phase_lab = empty_run()
	return root.phase_lab
end

function state.debug_snapshot()
	local p = state.get_permanent(false) or empty_permanent()
	local r = state.get_run(false) or empty_run()
	return {
		permanent = {
			discovered = p.discovered,
			puzzle_solved = p.puzzle_solved,
			anchor_activated_once = p.anchor_activated_once,
		},
		run = {
			overlay_force = r.overlay_force,
			replay_mode = r.puzzle.replay_mode,
			puzzle_active = r.puzzle.active,
			puzzle_solved = r.puzzle.solved,
			states = r.puzzle.states,
			materials = r.materials,
			anchor = r.anchor.state,
		},
	}
end

return state
