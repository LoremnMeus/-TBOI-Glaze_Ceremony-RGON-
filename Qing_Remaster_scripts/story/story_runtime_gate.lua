-- Thin runtime gate: "should this chapter-1 content run right now?"
-- StoryProgress is authoritative. UnlockData Ending* are write-only mirrors of Story completion.
-- Token ownership comes from story_registry (node.related.story_tokens) — no duplicate maps.
-- Challenge runs: blocked via quest_run_scope (Story Test may bypass).

local story = require("Qing_Remaster_scripts.story.story_state")
local registry = require("Qing_Remaster_scripts.story.story_registry")
local quest_run_scope = require("Qing_Remaster_scripts.quest.quest_run_scope")
local release_scope = require("Qing_Remaster_scripts.core.release_scope")

local gate = {}

function gate.is_story_test_active()
	return story.is_test_active and story.is_test_active() == true
end

--- Formal Chapter1 / Story Quest runtime. Story Test sessions stay allowed.
function gate.is_story_runtime_allowed()
	if gate.is_story_test_active() then
		return true
	end
	return quest_run_scope.allows_story_quests() == true
end

function gate.is_chapter1_available()
	if not release_scope.allows_story_chapter("chapter1") then return false end
	if not gate.is_story_runtime_allowed() then return false end
	return story.is_chapter_available("chapter1") == true
end

function gate.is_commission_accepted()
	return story.get_flag("chapter1", "commission_accepted") == true
end

function gate.is_material_phase_active()
	if not gate.is_story_runtime_allowed() then return false end
	if not gate.is_chapter1_available() then return false end
	if story.is_chapter_completed("chapter1") then return false end
	if not gate.is_commission_accepted() then return false end
	local obj = story.get_objective("chapter1")
	if obj == "chapter1.collect_materials" or obj == "chapter1.prepare_alchemy" then
		return true
	end
	return story.is_chapter_active("chapter1") == true
		or story.is_chapter_available("chapter1") == true
end

function gate.has_material(token)
	return story.has_token(token) == true
end

function gate.material_count()
	return story.count_material_tokens() or 0
end

function gate.is_event_first_cleared(event_id)
	return story.is_node_completed("chapter1", event_id) == true
end

function gate.requires_first_clear_boss(event_id)
	return not gate.is_event_first_cleared(event_id)
end

--- Story bank / material route vs standalone boss spawn.
-- story_owned=true  → only spawn on first Story clear
-- otherwise         → always allow spawn (Boss Test / rematch / standalone)
function gate.should_spawn_event_boss(event_id, opts)
	opts = opts or {}
	if opts.story_owned == true then
		return gate.requires_first_clear_boss(event_id)
	end
	return true
end

function gate.token_for_event(event_id)
	local tokens = registry.get_story_tokens(event_id)
	return tokens[1]
end

--- Soft enable: chapter1 open + commission + this-run token absent.
function gate.is_material_event_enabled(event_id)
	if not gate.is_story_runtime_allowed() then return false end
	if not gate.is_chapter1_available() then return false end
	if not gate.is_commission_accepted() then return false end
	local token = gate.token_for_event(event_id)
	if not token then return false end
	if gate.has_material(token) then
		return false
	end
	if event_id == "chapter1.phase_anchor" then
		local node = registry.get_node(event_id)
		local required = node and node.prerequisites and node.prerequisites.required_run_tokens
		if type(required) == "table" then
			for _, t in ipairs(required) do
				if not gate.has_material(t) then
					return false
				end
			end
		end
	end
	return true
end

function gate.get_event_stage(event_id)
	return story.get_event_stage and story.get_event_stage("chapter1", event_id) or nil
end

return gate
