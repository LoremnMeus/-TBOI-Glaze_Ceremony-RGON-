-- Story owns narrative progression; Boss only consumes material visuals and reports victory.
-- Advance Chapter1 only when the encounter is explicitly story-owned.
local defs = require("Qing_Remaster_scripts.story.story_defs")
local story = require("Qing_Remaster_scripts.story.story_state")
local M = {}

function M.get_chapter1_material_visuals()
	local out = {}
	for i, token in ipairs(defs.alchemy.canonical_material_route) do
		local name = token:match("([^.]+)$") or tostring(i)
		out[i] = {token = token, label = "MATERIAL: " .. name:upper():gsub("_", " ")}
	end
	return out
end

function M.on_defeat(ctx)
	ctx = ctx or {}
	local story_owned = ctx.story_owned == true
		or (ctx.story_test == true and story.is_test_active and story.is_test_active())
	if not story_owned then
		return
	end
	if story.is_chapter_active("chapter1") and story.get_objective("chapter1") == "chapter1.defeat_glaze" then
		story.on_chapter1_complete()
	end
end

return M
