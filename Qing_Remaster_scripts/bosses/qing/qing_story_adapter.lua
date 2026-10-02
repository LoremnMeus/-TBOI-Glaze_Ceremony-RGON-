-- Qing midboss Story adapter.
-- Boss runtime never requires Story. Only story-owned encounters advance Chapter1.
local story = require("Qing_Remaster_scripts.story.story_state")

local M = {}

local function at_qing_story_gate()
	if not story.is_chapter_active("chapter1") then
		return false
	end
	if story.is_node_completed("chapter1", "chapter1.qing_midboss") then
		return false
	end
	local current = story.get_current_node("chapter1")
	local objective = story.get_objective("chapter1")
	if current == "chapter1.qing_midboss" or current == "chapter1.search_qing" then
		return true
	end
	return objective == "chapter1.find_qing"
end

--- Called when a story-owned Qing encounter begins.
function M.on_start(ctx)
	ctx = ctx or {}
	if ctx.story_owned ~= true then
		return false
	end
	if story.chapter1_runtime_allowed and not story.chapter1_runtime_allowed() then
		return false
	end
	if not at_qing_story_gate() then
		return false
	end
	story.start_chapter("chapter1")
	story.set_current_node("chapter1", "chapter1.qing_midboss")
	return true
end

--- Called after Qing encounter defeat. Default: do nothing unless story-owned.
function M.on_defeat(ctx)
	ctx = ctx or {}
	local story_owned = ctx.story_owned == true
		or (ctx.story_test == true and story.is_test_active and story.is_test_active())
	if not story_owned then
		return false
	end
	if not at_qing_story_gate() then
		return false
	end
	return story.on_qing_midboss_defeated()
end

return M
