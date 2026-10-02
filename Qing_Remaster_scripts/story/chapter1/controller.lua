-- Chapter 1 runtime: first new-run opening title after prologue complete.
-- Does not start commission or set Quest objectives.

local enums = require("Qing_Remaster_scripts.core.enums")
local story = require("Qing_Remaster_scripts.story.story_state")
local release_scope = require("Qing_Remaster_scripts.core.release_scope")

local controller = {
	ToCall = {},
	myToCall = {},
	own_key = "Chapter1_Controller_",
}

local function is_normal_run()
	if Isaac.GetChallenge() > 0 then return false end
	local game = Game()
	if game:GetVictoryLap() > 0 then return false end
	return true
end

local function is_story_test_active()
	local ok, st = pcall(require, "Qing_Remaster_scripts.story.story_state")
	return ok and st and st.is_test_active and st.is_test_active()
end

local function try_play_opening()
	if not release_scope.allows_story_chapter("chapter1") then return false end
	if not is_normal_run() then return false end
	if is_story_test_active() then return false end
	if not story.is_chapter_completed("prologue") then return false end
	local ch = story.get_chapter("chapter1", false)
	if not ch or ch.status ~= story.STATUS.AVAILABLE then return false end
	if ch.current_node ~= nil then return false end
	if story.get_flag("chapter1", "opening_seen") then return false end
	if story.get_flag("chapter1", "commission_accepted") then return false end

	local ok, transition = pcall(require, "Qing_Remaster_scripts.story.chapter_transition")
	if not ok or not transition or not transition.play_chapter then
		return false
	end

	local tok, tracker = pcall(require, "Qing_Remaster_scripts.quest.quest_tracker")
	if tok and tracker and tracker.suspend then
		tracker.suspend("chapter_transition")
	end

	-- Mark seen as soon as presentation is acquired (avoid re-play on mid-title quit).
	story.set_flag("chapter1", "opening_seen", true)

	local played = transition.play_chapter("chapter1", {
		after_delay = 0,
		on_complete = function()
			if tok and tracker and tracker.resume then
				tracker.resume("chapter_transition", {refresh = true})
			end
		end,
	})
	if not played then
		-- Roll back seen if play failed to acquire.
		story.set_flag("chapter1", "opening_seen", false)
		if tok and tracker and tracker.resume then
			tracker.resume("chapter_transition", {refresh = true})
		end
		return false
	end
	return true
end

table.insert(controller.myToCall, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	params = nil,
	Function = function(_, continued)
		if continued then return end
		try_play_opening()
	end,
})

return controller
