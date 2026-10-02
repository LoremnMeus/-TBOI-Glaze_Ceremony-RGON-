-- Prologue runtime: BACKWARDS_PATH_INIT floor → hunt; first Home → home_encounter.
-- Story mutations go through story_state public APIs only.

local enums = require("Qing_Remaster_scripts.core.enums")
local story = require("Qing_Remaster_scripts.story.story_state")

local controller = {
	ToCall = {},
	myToCall = {},
	own_key = "Prologue_Controller_",
}

local function run_prologue(create)
	local run = story.get_run_root(create == true)
	if not run then return nil end
	run.prologue = type(run.prologue) == "table" and run.prologue or {}
	return run.prologue
end

local function opening_already_triggered(flags)
	if not flags then return false end
	if flags.opening_triggered then return true end
	-- LEGACY-SAVE-003: older runs used ascent_entered for the same one-shot gate.
	if flags.ascent_entered then
		flags.opening_triggered = true
		flags.ascent_entered = nil
		return true
	end
	return false
end

local function is_eligible_player()
	if Isaac.GetChallenge() > 0 then return false end
	local game = Game()
	if game:GetVictoryLap() > 0 then return false end
	local player = Isaac.GetPlayer(0)
	if not player then return false end
	return player:GetPlayerType() == enums.Players.wq
end

--- Enter Mausoleum/Gehenna II via photo door (Dad's Note floor), before Ascent starts.
local function try_start_prologue()
	if not is_eligible_player() then return false end
	local level = Game():GetLevel()
	if not level or level:GetStage() ~= LevelStage.STAGE3_2 then return false end
	if not Game():GetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH_INIT) then return false end

	local flags = run_prologue(true)
	if not flags or opening_already_triggered(flags) then return false end
	if story.is_chapter_completed("prologue") then
		flags.opening_triggered = true
		return false
	end
	local ch = story.get_chapter("prologue", false)
	if ch and ch.status == story.STATUS.ACTIVE and ch.current_node then
		flags.opening_triggered = true
		return false
	end
	flags.opening_triggered = true
	return story.start_prologue_hunt({play_opening = true})
end

local function try_home_arrival()
	if not is_eligible_player() then return false end
	local level = Game():GetLevel()
	if not level or level:GetStage() ~= LevelStage.STAGE8 then return false end
	if story.get_current_node("prologue") ~= "prologue.hunt" then return false end
	local flags = run_prologue(true)
	if not flags or flags.home_arrived then return false end
	flags.home_arrived = true
	local ok = story.on_prologue_home_arrived()
	if ok then
		local tok, home = pcall(require, "Qing_Remaster_scripts.story.prologue.home_encounter")
		if tok and home and home.request_bed_sync then
			home.request_bed_sync()
		end
	end
	return ok
end

--- Clear this-run prologue gates only (not whole StoryRun).
--- Used by Progress UI "prologue.before" and Debug reset so permanent wipe + run gate stay in sync.
function controller.reset_run_state()
	local flags = run_prologue(true)
	if not flags then return false end
	flags.opening_triggered = nil
	flags.ascent_entered = nil
	flags.home_arrived = nil
	return true
end

--- Debug / Story Test: formal opening without needing the photo-door floor.
function controller.debug_start_prologue(opts)
	opts = opts or {}
	controller.reset_run_state()
	if opts.reset_story then
		local ch = story.get_chapter("prologue", true)
		if ch then
			ch.status = story.STATUS.LOCKED
			ch.current_node = nil
			ch.discovered = {}
			ch.completed = {}
			ch.flags = {}
		end
	end
	-- Consume the one-shot gate: this Debug path is itself the "enter" event.
	local f = run_prologue(true)
	if f then f.opening_triggered = true end
	return story.start_prologue_hunt({
		play_opening = opts.play_opening ~= false,
	})
end

-- Compatibility alias for older Story Test wiring.
function controller.debug_enter_ascent(opts)
	return controller.debug_start_prologue(opts)
end

--- Debug / Story Test: simulate first Home arrival transition.
function controller.debug_home_arrival()
	local flags = run_prologue(true)
	if flags then flags.home_arrived = false end
	local ok = story.on_prologue_home_arrived()
	if ok then
		local tok, home = pcall(require, "Qing_Remaster_scripts.story.prologue.home_encounter")
		if tok and home and home.request_bed_sync then
			home.request_bed_sync()
		end
	end
	return ok
end

table.insert(controller.ToCall, {
	CallBack = ModCallbacks.MC_POST_NEW_LEVEL,
	params = nil,
	Function = function()
		try_start_prologue()
		try_home_arrival()
	end,
})

table.insert(controller.ToCall, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		-- Home can be entered mid-floor via special routes; also catch room 0 of STAGE8.
		try_home_arrival()
	end,
})

table.insert(controller.myToCall, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	params = nil,
	Function = function(_, continued)
		if continued then return end
		controller.reset_run_state()
	end,
})

return controller
