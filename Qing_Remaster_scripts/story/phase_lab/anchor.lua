-- Phase Lab Phase Anchor: ready / activation stub (no Interstice map).

local defs = require("Qing_Remaster_scripts.story.phase_lab.defs")
local state = require("Qing_Remaster_scripts.story.phase_lab.state")
local puzzle = require("Qing_Remaster_scripts.story.phase_lab.puzzle")
local materials = require("Qing_Remaster_scripts.story.phase_lab.materials")
local story = require("Qing_Remaster_scripts.story.story_state")

local anchor = {
	ACTIVATE_FRAMES = 90, -- 30Hz → 3s stub
}

local function run()
	return state.get_run(true)
end

function anchor.get_state()
	return run().anchor.state or "idle"
end

function anchor.set_state(s)
	run().anchor.state = tostring(s or "idle")
end

function anchor.can_ready()
	if puzzle.is_replay() then return false end
	if not puzzle.is_solved() then return false end
	if not materials.is_complete() then return false end
	local st = anchor.get_state()
	return st == "idle" or st == "ready"
end

function anchor.refresh_ready()
	local r = run()
	if r.anchor.state == "activating" or r.anchor.state == "open" then
		return r.anchor.state
	end
	if puzzle.is_replay() or not puzzle.is_solved() then
		r.anchor.state = "idle"
		return "idle"
	end
	if materials.is_complete() then
		r.anchor.state = "ready"
		return "ready"
	end
	r.anchor.state = "idle"
	return "idle"
end

function anchor.try_activate()
	anchor.refresh_ready()
	if anchor.get_state() ~= "ready" then
		return false, "not_ready"
	end
	local r = run()
	r.anchor.state = "activating"
	r.anchor.activate_timer = anchor.ACTIVATE_FRAMES
	return true
end

function anchor.play_activation_stub()
	return anchor.try_activate()
end

function anchor.force_open()
	local r = run()
	r.anchor.state = "open"
	r.anchor.activate_timer = 0
	state.mark_anchor_activated()
	-- Story progression stub: alchemy setup complete → enter_realms objective.
	pcall(function()
		story.on_alchemy_setup_complete()
	end)
	return true
end

function anchor.tick()
	local r = run()
	if r.anchor.state ~= "activating" then return nil end
	r.anchor.activate_timer = (r.anchor.activate_timer or 0) - 1
	if r.anchor.activate_timer <= 0 then
		anchor.force_open()
		return "open"
	end
	return "activating"
end

function anchor.activation_progress()
	local r = run()
	if r.anchor.state == "open" then return 1 end
	if r.anchor.state ~= "activating" then return 0 end
	local max = anchor.ACTIVATE_FRAMES
	return 1 - ((r.anchor.activate_timer or 0) / math.max(1, max))
end

function anchor.status_lines()
	local lang = (Options and Options.Language == "en") and "en" or "zh"
	local st = anchor.refresh_ready()
	local pc = materials.property_count()
	local cat = materials.catalyst_inserted()
	local cal = puzzle.is_solved() and not puzzle.is_replay()
	local lines
	if lang == "en" then
		lines = {
			"PHASE CALIBRATION  " .. (cal and "STABLE" or "UNSTABLE"),
			"PROPERTY NODES     " .. tostring(pc) .. " / 4",
			"CATALYST           " .. (cat and "READY" or "MISSING"),
			"ANCHOR             " .. string.upper(st),
		}
	else
		lines = {
			"相位校准  " .. (cal and "稳定" or "未校准"),
			"属性节点  " .. tostring(pc) .. " / 4",
			"催化剂    " .. (cat and "就绪" or "缺失"),
			"相位锚    " .. tostring(st),
		}
	end
	return lines
end

return anchor
