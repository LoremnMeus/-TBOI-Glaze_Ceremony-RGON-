-- Material-thread Story adapter.
-- Thread / Boss completion may fire anytime; Story advances only when story_owned.
local story = require("Qing_Remaster_scripts.story.story_state")

local M = {}

--- Grant material node + token when this encounter is Story-owned.
-- @param thread_id string coin|glaze|stone|wind
-- @param ctx table|nil {story_owned=bool, story_test=bool}
function M.on_thread_complete(thread_id, ctx)
	ctx = ctx or {}
	local story_owned = ctx.story_owned == true
		or (ctx.story_test == true and story.is_test_active and story.is_test_active())
	if not story_owned then
		return false
	end
	return story.notify_thread_complete(thread_id)
end

return M
