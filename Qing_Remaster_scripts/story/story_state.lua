-- StoryProgress persistence + chapter/node/token API.
-- Stored in PermanentData (profile-persistent).
-- UnlockData Ending1/2 are write-only mirrors of Story completion; Story never reads them back.
-- Story Test Lab may overlay an in-memory root via get_effective_root().

local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local registry = require("Qing_Remaster_scripts.story.story_registry")
local defs = require("Qing_Remaster_scripts.story.story_defs")

local story = {
	ToCall = {},
	myToCall = {},
	SCHEMA_VERSION = defs.SCHEMA_VERSION or 1,
	STATUS = defs.CHAPTER_STATUS,
}

local _notify_batch_depth = 0
local _notify_batch_pending = false
local _notify_batch_opts = nil

local function notify_quest(opts)
	if _notify_batch_depth > 0 then
		_notify_batch_pending = true
		if type(opts) == "table" then
			_notify_batch_opts = opts
		end
		return
	end
	local ok, tracker = pcall(require, "Qing_Remaster_scripts.quest.quest_tracker")
	if ok and tracker and tracker.notify_story_changed then
		tracker.notify_story_changed(opts)
	end
end

--- Batch Story mutations so Quest sees one final state (avoids mid-transition toasts).
function story.begin_notify_batch()
	_notify_batch_depth = _notify_batch_depth + 1
end

--- opts.suppress: discard pending notify. opts.completed_main: complete→new toast handoff.
function story.end_notify_batch(opts)
	opts = opts or {}
	_notify_batch_depth = math.max(0, _notify_batch_depth - 1)
	if _notify_batch_depth > 0 then
		if type(opts) == "table" and opts.completed_main then
			_notify_batch_opts = opts
		end
		return
	end
	local pending = _notify_batch_pending
	_notify_batch_pending = false
	local stored = _notify_batch_opts
	_notify_batch_opts = nil
	if opts.suppress then
		return
	end
	local payload = opts
	if type(opts.completed_main) ~= "table" and type(stored) == "table" then
		payload = stored
	end
	if pending or (type(payload) == "table" and payload.completed_main) then
		notify_quest(payload)
	end
end

local function try_test_session()
	local ok, session = pcall(require, "Qing_Remaster_scripts.story_test.story_test_session")
	if ok then return session end
	return nil
end

local function empty_chapter()
	return {
		status = story.STATUS.LOCKED,
		current_node = nil,
		objective = nil,
		flags = {},
		discovered = {},
		completed = {},
	}
end

local function ensure_chapter_shape(ch)
	if type(ch) ~= "table" then return empty_chapter() end
	ch.status = ch.status or story.STATUS.LOCKED
	ch.flags = type(ch.flags) == "table" and ch.flags or {}
	ch.discovered = type(ch.discovered) == "table" and ch.discovered or {}
	ch.completed = type(ch.completed) == "table" and ch.completed or {}
	-- Permanent chapter must not store run materials (those live in StoryRun).
	ch.tokens = nil
	ch.materials = nil
	return ch
end

local function migrate_prologue_presentation_nodes(root)
	-- SCHEMA 5: glaze_intervention / qing_glaze_conflict / qing_defeated → ending phases.
	local ch = root.chapters and root.chapters.prologue
	if type(ch) ~= "table" then return end
	ch.completed = type(ch.completed) == "table" and ch.completed or {}
	ch.discovered = type(ch.discovered) == "table" and ch.discovered or {}
	local legacy = {
		"prologue.glaze_intervention",
		"prologue.qing_glaze_conflict",
		"prologue.qing_defeated",
	}
	local had_legacy = false
	for _, id in ipairs(legacy) do
		if ch.completed[id] or ch.discovered[id] or ch.current_node == id then
			had_legacy = true
		end
	end
	if not had_legacy then return end
	local progressed = ch.completed["prologue.glaze_intervention"]
		or ch.completed["prologue.qing_glaze_conflict"]
		or ch.completed["prologue.qing_defeated"]
	if progressed then
		ch.discovered["prologue.ending"] = true
		if ch.status == story.STATUS.COMPLETED or ch.completed["prologue.qing_defeated"] then
			ch.completed["prologue.ending"] = true
		elseif ch.current_node == "prologue.glaze_intervention"
			or ch.current_node == "prologue.qing_glaze_conflict"
			or ch.current_node == "prologue.qing_defeated" then
			ch.current_node = "prologue.ending"
		end
	end
	for _, id in ipairs(legacy) do
		ch.completed[id] = nil
		ch.discovered[id] = nil
	end
end

--- SCHEMA 6: Chapter1 AVAILABLE waiting state must not carry accept_commission objective.
local function migrate_chapter1_waiting_state(root)
	local ch = root.chapters and root.chapters.chapter1
	if type(ch) ~= "table" then return end
	ch.flags = type(ch.flags) == "table" and ch.flags or {}
	if ch.flags.commission_accepted == true then
		return
	end
	if ch.objective == "chapter1.accept_commission" then
		ch.objective = nil
	end
	if ch.status == story.STATUS.AVAILABLE and ch.current_node == "chapter1.commission" then
		ch.current_node = nil
	end
end

--- SCHEMA 7: Drop redundant materials_complete / qing_encounter story nodes.
local DELETED_CHAPTER1_NODE_REMAP = {
	["chapter1.materials_complete"] = "chapter1.alchemy_setup",
	["chapter1.qing_encounter"] = "chapter1.qing_midboss",
}

local function migrate_chapter1_deleted_nodes(root)
	local ch = root.chapters and root.chapters.chapter1
	if type(ch) ~= "table" then return end
	ch.completed = type(ch.completed) == "table" and ch.completed or {}
	ch.discovered = type(ch.discovered) == "table" and ch.discovered or {}

	local current = ch.current_node
	local remap = current and DELETED_CHAPTER1_NODE_REMAP[current]
	if remap then
		ch.current_node = remap
		ch.discovered[remap] = true
	end

	-- materials_complete meant "ready for alchemy", NOT "alchemy already done".
	if ch.discovered["chapter1.materials_complete"] or ch.completed["chapter1.materials_complete"] then
		ch.discovered["chapter1.alchemy_setup"] = true
	end
	-- Heal first Schema-7 bug that wrongly completed alchemy_setup while still there.
	if ch.completed["chapter1.alchemy_setup"]
		and ch.current_node == "chapter1.alchemy_setup"
		and (ch.objective == "chapter1.prepare_alchemy" or ch.objective == nil)
	then
		ch.completed["chapter1.alchemy_setup"] = nil
	end

	-- Old runtime completed qing_encounter together with midboss defeat.
	if ch.completed["chapter1.qing_encounter"] then
		ch.completed["chapter1.qing_midboss"] = true
		ch.discovered["chapter1.qing_midboss"] = true
	elseif ch.discovered["chapter1.qing_encounter"] then
		ch.discovered["chapter1.qing_midboss"] = true
	end

	-- Drop deleted keys so migration stays idempotent and cannot revive wrong completed.
	ch.completed["chapter1.materials_complete"] = nil
	ch.discovered["chapter1.materials_complete"] = nil
	ch.completed["chapter1.qing_encounter"] = nil
	ch.discovered["chapter1.qing_encounter"] = nil
end

local function shape_root(root)
	if type(root) ~= "table" then return nil end
	root.schema_version = root.schema_version or story.SCHEMA_VERSION
	root.chapters = root.chapters or {}
	for _, chapter in ipairs(registry.list_chapters()) do
		root.chapters[chapter.id] = ensure_chapter_shape(root.chapters[chapter.id])
	end
	migrate_prologue_presentation_nodes(root)
	migrate_chapter1_waiting_state(root)
	migrate_chapter1_deleted_nodes(root)
	root.schema_version = story.SCHEMA_VERSION
	return root
end

local function empty_run_root()
	return {
		schema_version = story.SCHEMA_VERSION,
		story_run = true,
		chapters = {},
		-- LEGACY-SAVE-002: flat mirrors kept in sync for older consumers.
		tokens = {},
		materials = {},
		events = {},
	}
end

local function ensure_run_node(run, chapter_id, node_id)
	run.chapters = type(run.chapters) == "table" and run.chapters or {}
	local ch = run.chapters[chapter_id]
	if type(ch) ~= "table" then
		ch = {nodes = {}}
		run.chapters[chapter_id] = ch
	end
	ch.nodes = type(ch.nodes) == "table" and ch.nodes or {}
	local node = ch.nodes[node_id]
	if type(node) ~= "table" then
		node = {tokens = {}}
		ch.nodes[node_id] = node
	end
	node.tokens = type(node.tokens) == "table" and node.tokens or {}
	return node
end

local function rebuild_flat_mirrors(run)
	local tokens = {}
	local materials = {}
	local events = type(run.events) == "table" and run.events or {}
	for chapter_id, ch in pairs(run.chapters or {}) do
		if type(ch) == "table" and type(ch.nodes) == "table" then
			for node_id, node in pairs(ch.nodes) do
				if type(node) == "table" then
					if type(node.tokens) == "table" then
						for token, owned in pairs(node.tokens) do
							if owned then
								tokens[token] = true
								local material_key = token:match("%.material%.(.+)$")
								if material_key then
									materials[material_key] = true
								end
							end
						end
					end
					if node.stage ~= nil then
						events[node_id] = events[node_id] or {}
						events[node_id].stage = node.stage
					end
				end
			end
		end
	end
	run.tokens = tokens
	run.materials = materials
	run.events = events
end

--- LEGACY-SAVE-002: migrate flat StoryRun.tokens/events into chapters.nodes.
local function migrate_flat_run_into_nodes(run)
	for token, owned in pairs(run.tokens or {}) do
		if owned == true then
			local owner = registry.get_token_owner(token)
			if owner then
				local node = ensure_run_node(run, owner.chapter, owner.node)
				node.tokens[token] = true
			end
		end
	end
	for node_id, ev in pairs(run.events or {}) do
		if type(ev) == "table" and ev.stage ~= nil then
			local node_def = registry.get_node(node_id)
			local chapter_id = node_def and node_def.chapter
			if chapter_id then
				local node = ensure_run_node(run, chapter_id, node_id)
				if node.stage == nil then
					node.stage = ev.stage
				end
			end
		end
	end
end

local function shape_run(root)
	if type(root) ~= "table" then return empty_run_root() end
	root.schema_version = root.schema_version or story.SCHEMA_VERSION
	root.chapters = type(root.chapters) == "table" and root.chapters or {}
	root.tokens = type(root.tokens) == "table" and root.tokens or {}
	root.materials = type(root.materials) == "table" and root.materials or {}
	root.events = type(root.events) == "table" and root.events or {}
	-- Always absorb any remaining flat entries into node buckets (LEGACY-SAVE-002).
	migrate_flat_run_into_nodes(root)
	rebuild_flat_mirrors(root)
	root.schema_version = story.SCHEMA_VERSION
	return root
end

--- Permanent profile root only (never the test overlay).
function story.get_permanent_root(create)
	if type(save.PermanentData) ~= "table" then
		if not create then return nil end
		save.PermanentData = {}
	end
	local root = save.PermanentData.StoryProgress
	if type(root) ~= "table" and create then
		root = {
			schema_version = story.SCHEMA_VERSION,
			chapters = {},
		}
		save.PermanentData.StoryProgress = root
	end
	root = shape_root(root)
	if root and type(save.elses) == "table" then
		if not story.is_test_active() then
			save.elses.StoryProgress = root
		end
	end
	return root
end

function story.is_test_active()
	local session = try_test_session()
	return session ~= nil and session.is_active and session.is_active() == true
end

function story.chapter1_runtime_allowed()
	local ok, scope = pcall(require, "Qing_Remaster_scripts.core.release_scope")
	if not ok or not scope or not scope.allows_story_chapter then
		return true
	end
	return scope.allows_story_chapter("chapter1") == true
end

function story.suppress_permanent_unlocks()
	if not story.is_test_active() then return false end
	local session = try_test_session()
	if session and session.suppress_permanent_unlocks then
		return session.suppress_permanent_unlocks() == true
	end
	return true
end

--- Effective Story root: test overlay when Story Test Lab is active.
function story.get_effective_root(create)
	local session = try_test_session()
	if session and session.is_active and session.is_active() then
		local override = session.get_story_override and session.get_story_override()
		if type(override) == "table" then
			return shape_root(override)
		end
		if create and session.ensure_story_override then
			override = session.ensure_story_override()
			return shape_root(override)
		end
	end
	return story.get_permanent_root(create)
end

function story.get_root(create)
	return story.get_effective_root(create)
end

--- Run-scoped story (materials / event stages). Not PermanentData.
function story.get_permanent_run_root(create)
	if type(save.elses) ~= "table" then
		if not create then return nil end
		save.elses = {}
	end
	local root = save.elses.StoryRun
	if type(root) ~= "table" and create then
		root = empty_run_root()
		save.elses.StoryRun = root
	end
	if type(root) ~= "table" then return nil end
	return shape_run(root)
end

function story.get_effective_run_root(create)
	local session = try_test_session()
	if session and session.is_active and session.is_active() then
		local override = session.get_run_override and session.get_run_override()
		if type(override) == "table" then
			return shape_run(override)
		end
		if create and session.ensure_run_override then
			return shape_run(session.ensure_run_override())
		end
	end
	return story.get_permanent_run_root(create)
end

function story.get_run_root(create)
	return story.get_effective_run_root(create)
end

function story.clear_run_materials()
	local root = story.get_run_root(true)
	if not root then return false end
	root.chapters = {}
	root.tokens = {}
	root.materials = {}
	root.events = {}
	notify_quest()
	return true
end

function story.get_node_run_state(chapter_id, node_id, create)
	if type(chapter_id) ~= "string" or type(node_id) ~= "string" then return nil end
	local run = story.get_run_root(create == true)
	if not run then return nil end
	if create then
		return ensure_run_node(run, chapter_id, node_id)
	end
	local ch = run.chapters and run.chapters[chapter_id]
	if type(ch) ~= "table" or type(ch.nodes) ~= "table" then return nil end
	return ch.nodes[node_id]
end


function story.get_chapter(id, create)
	local root = story.get_root(create)
	if not root then return nil end
	if not registry.get_chapter(id) then return nil end
	root.chapters[id] = ensure_chapter_shape(root.chapters[id])
	return root.chapters[id]
end

function story.is_chapter_available(id)
	local ch = story.get_chapter(id, false)
	if not ch then return false end
	return ch.status == story.STATUS.AVAILABLE
		or ch.status == story.STATUS.ACTIVE
		or ch.status == story.STATUS.COMPLETED
end

function story.is_chapter_active(id)
	local ch = story.get_chapter(id, false)
	return ch ~= nil and ch.status == story.STATUS.ACTIVE
end

function story.is_chapter_completed(id)
	local ch = story.get_chapter(id, false)
	return ch ~= nil and ch.status == story.STATUS.COMPLETED
end

function story.start_chapter(id)
	if id == "chapter1" and not story.chapter1_runtime_allowed() then
		return false, "release_scope_disallows_chapter1"
	end
	local ch = story.get_chapter(id, true)
	if not ch then return false end
	if ch.status == story.STATUS.COMPLETED then return false end
	if ch.status == story.STATUS.ACTIVE then return true end
	ch.status = story.STATUS.ACTIVE
	if id == "chapter1" then
		-- Do NOT invent accept_commission while waiting for Glaze.
		-- begin_chapter1_commission() owns ACTIVE + commission node.
		if story.get_flag("chapter1", "commission_accepted") then
			if not ch.objective then
				story.set_objective("chapter1", "chapter1.collect_materials")
			end
			if not ch.current_node then
				story.set_current_node("chapter1", "chapter1.material_phase")
			end
		end
	elseif id == "prologue" then
		if not ch.current_node then
			story.set_current_node("prologue", "prologue.hunt")
		end
	end
	return true
end

local function quest_view_for_node(node_id)
	local ok, qreg = pcall(require, "Qing_Remaster_scripts.quest.quest_registry")
	if not ok or not qreg then return nil end
	local def = qreg.main_by_node and qreg.main_by_node[node_id]
	if not def then return nil end
	local lang = qreg.lang and qreg.lang() or "zh"
	local function pick(tbl)
		if type(tbl) ~= "table" then return tostring(tbl or "") end
		if lang == "en" then return tbl.en or tbl.zh or "" end
		return tbl.zh or tbl.en or ""
	end
	return {
		id = def.id,
		title = pick(def.title),
		objective = pick(def.objective),
		optional = def.optional == true,
	}
end

--- Formal prologue start (BACKWARDS_PATH_INIT floor / Story Test).
--- opts.play_opening (default true): suspend Quest → chapter title → after_delay → resume Quest.
function story.start_prologue_hunt(opts)
	opts = opts or {}
	local ch = story.get_chapter("prologue", true)
	if not ch then return false end
	if ch.status == story.STATUS.COMPLETED then return false end
	if ch.completed["prologue.hunt"] then return false end

	local play_opening = opts.play_opening ~= false
	local already_hunt = ch.current_node == "prologue.hunt" and ch.status == story.STATUS.ACTIVE

	local function suspend_quest()
		local ok, tracker = pcall(require, "Qing_Remaster_scripts.quest.quest_tracker")
		if ok and tracker and tracker.suspend then
			tracker.suspend("chapter_transition")
		end
	end

	local function resume_quest()
		local ok, tracker = pcall(require, "Qing_Remaster_scripts.quest.quest_tracker")
		if ok and tracker and tracker.resume then
			tracker.resume("chapter_transition", {refresh = true})
		else
			notify_quest()
		end
	end

	-- Replay opening while already on hunt (Debug / Story Test): still suspend + play title.
	if already_hunt and not play_opening then
		return true
	end

	if play_opening then
		suspend_quest()
	end

	story.begin_notify_batch()
	if ch.status ~= story.STATUS.ACTIVE then
		ch.status = story.STATUS.ACTIVE
	end
	ch.current_node = "prologue.hunt"
	ch.discovered["prologue.hunt"] = true
	-- Opening owns first reveal via resume(); non-opening notifies normally.
	story.end_notify_batch({suppress = play_opening})

	if play_opening then
		local ok, transition = pcall(require, "Qing_Remaster_scripts.story.chapter_transition")
		if ok and transition and transition.play_chapter then
			transition.play_chapter("prologue", {
				after_delay = 18,
				on_complete = function()
					resume_quest()
				end,
			})
		elseif ok and transition and transition.play then
			local lang = (Options and Options.Language == "en") and "en" or "zh"
			transition.play({
				chapter = (lang == "en") and "Prologue" or "序章",
				title = (lang == "en") and "The Hunt" or "狩猎",
				after_delay = 18,
				on_complete = function()
					resume_quest()
				end,
			})
		else
			resume_quest()
		end
	elseif opts.notify ~= false then
		notify_quest()
	end
	return true
end

--- First arrival at Home while hunting: complete hunt → home_encounter (batched + complete toast).
function story.on_prologue_home_arrived()
	local ch = story.get_chapter("prologue", true)
	if not ch then return false end
	if ch.status ~= story.STATUS.ACTIVE then return false end
	if ch.completed["prologue.hunt"] then
		if ch.current_node ~= "prologue.home_encounter" then
			story.begin_notify_batch()
			ch.current_node = "prologue.home_encounter"
			ch.discovered["prologue.home_encounter"] = true
			story.end_notify_batch()
		end
		return true
	end
	if ch.current_node ~= "prologue.hunt" then return false end

	local completed_view = quest_view_for_node("prologue.hunt")
	story.begin_notify_batch()
	ch.completed["prologue.hunt"] = true
	ch.discovered["prologue.hunt"] = true
	ch.current_node = "prologue.home_encounter"
	ch.discovered["prologue.home_encounter"] = true
	story.end_notify_batch({
		completed_main = completed_view or {
			id = "prologue.hunt",
			title = "狩猎",
			objective = "继续前进",
		},
	})
	return true
end

--- Optional Home encounter finished (Isaac dialogue done). Permanent flag for later chapters.
function story.on_prologue_home_encounter_completed()
	local ch = story.get_chapter("prologue", true)
	if not ch then return false end
	if ch.status ~= story.STATUS.ACTIVE then return false end
	if ch.current_node ~= "prologue.home_encounter" then return false end
	story.set_flag("prologue", "met_isaac_before_beast", true)
	ch.flags.home_encounter_skipped = nil
	return story.complete_node("prologue", "prologue.home_encounter")
end

--- Left bedroom without finishing Isaac dialogue: discover but do NOT complete optional node.
function story.on_prologue_home_encounter_skipped()
	local ch = story.get_chapter("prologue", true)
	if not ch then return false end
	if ch.status ~= story.STATUS.ACTIVE then return false end
	if ch.current_node ~= "prologue.home_encounter" then return false end
	if ch.completed["prologue.home_encounter"] then return false end
	story.begin_notify_batch()
	ch.discovered["prologue.home_encounter"] = true
	story.set_flag("prologue", "home_encounter_skipped", true)
	ch.current_node = "prologue.beast_battle"
	ch.discovered["prologue.beast_battle"] = true
	story.end_notify_batch()
	return true
end

--- Beast defeated (Story truth). Presentation handoff is separate (ending_scene).
function story.on_prologue_beast_defeated()
	local ch = story.get_chapter("prologue", true)
	if not ch then return false end
	if ch.status ~= story.STATUS.ACTIVE then return false end
	if ch.current_node ~= "prologue.beast_battle" then return false end
	return story.complete_node("prologue", "prologue.beast_battle")
end

--- Ending1 scene finished formally. Does not bulk-forge optional home_encounter.
function story.on_prologue_ending_complete()
	local ch = story.get_chapter("prologue", true)
	if not ch then return false, "no_chapter" end
	if ch.status == story.STATUS.COMPLETED then return true end
	if not ch.completed["prologue.hunt"] then
		return false, "invalid_prologue_state"
	end
	local home_ok = ch.completed["prologue.home_encounter"] == true
		or story.get_flag("prologue", "home_encounter_skipped") == true
	if not home_ok then
		return false, "invalid_prologue_state"
	end
	if not ch.completed["prologue.beast_battle"] then
		return false, "invalid_prologue_state"
	end
	-- Formal runtime requires current == ending; no silent drift repair.
	if ch.current_node ~= "prologue.ending" then
		return false, "invalid_prologue_state"
	end
	story.begin_notify_batch()
	if not ch.completed["prologue.ending"] then
		story.complete_node("prologue", "prologue.ending")
	end
	local ok = story.complete_chapter("prologue")
	story.end_notify_batch()
	if ok then return true end
	return false, "complete_failed"
end

--- Future: Glaze commission scene begins (no Quest yet).
function story.begin_chapter1_commission()
	if not story.chapter1_runtime_allowed() then
		return false, "release_scope_disallows_chapter1"
	end
	local ch = story.get_chapter("chapter1", true)
	if not ch then return false, "no_chapter" end
	if ch.status == story.STATUS.COMPLETED then return false, "chapter_completed" end
	if ch.status == story.STATUS.LOCKED then
		return false, "chapter_locked"
	end
	if story.get_flag("chapter1", "commission_accepted") then
		return false, "already_accepted"
	end
	story.begin_notify_batch()
	ch.status = story.STATUS.ACTIVE
	ch.objective = nil
	ch.current_node = "chapter1.commission"
	ch.discovered["chapter1.commission"] = true
	story.end_notify_batch({suppress = true})
	return true
end

--- Commission scene finished: first real Chapter1 quest = collect materials.
function story.accept_chapter1_commission()
	if not story.chapter1_runtime_allowed() then
		return false, "release_scope_disallows_chapter1"
	end
	local ch = story.get_chapter("chapter1", true)
	if not ch then return false, "no_chapter" end
	if ch.status ~= story.STATUS.ACTIVE then
		return false, "chapter_not_active"
	end
	if ch.current_node ~= "chapter1.commission" then
		return false, "commission_not_in_progress"
	end
	story.begin_notify_batch()
	story.complete_node("chapter1", "chapter1.commission")
	story.set_flag("chapter1", "commission_accepted", true)
	story.set_current_node("chapter1", "chapter1.material_phase")
	story.set_objective("chapter1", "chapter1.collect_materials")
	story.end_notify_batch()
	return true
end

function story.complete_chapter(id)
	if id == "chapter1" and not story.chapter1_runtime_allowed() then
		return false, "release_scope_disallows_chapter1"
	end
	local ch = story.get_chapter(id, true)
	if not ch then return false end
	if ch.status == story.STATUS.COMPLETED then return false end
	ch.status = story.STATUS.COMPLETED
	ch.current_node = nil
	if id == "prologue" then
		story.complete_node("prologue", "prologue.complete")
		local next_ch = story.get_chapter("chapter1", true)
		if next_ch and (next_ch.status == story.STATUS.LOCKED or next_ch.status == story.STATUS.AVAILABLE) then
			if next_ch.status == story.STATUS.LOCKED then
				next_ch.status = story.STATUS.AVAILABLE
			end
			-- Waiting for Glaze: no objective, no current commission node.
			if not story.get_flag("chapter1", "commission_accepted") then
				next_ch.current_node = nil
				next_ch.objective = nil
			end
		end
		if not story.suppress_permanent_unlocks() then
			local unlock = save.UnlockData and save.UnlockData.Others and save.UnlockData.Others.Ending1
			if type(unlock) == "table" and unlock.Unlock ~= true then
				unlock.Unlock = true
			end
		end
	elseif id == "chapter1" then
		story.complete_node("chapter1", "chapter1.complete")
		if not story.suppress_permanent_unlocks() then
			local unlock = save.UnlockData and save.UnlockData.Others and save.UnlockData.Others.Ending2
			if type(unlock) == "table" and unlock.Unlock ~= true then
				unlock.Unlock = true
			end
		end
	end
	return true
end

function story.set_current_node(chapter_id, node_id)
	local ch = story.get_chapter(chapter_id, true)
	if not ch then return false end
	if node_id ~= nil and not registry.get_node(node_id) then return false end
	ch.current_node = node_id
	if node_id then
		story.discover(chapter_id, node_id)
	end
	return true
end

function story.get_current_node(chapter_id)
	local ch = story.get_chapter(chapter_id, false)
	if not ch then return nil end
	return ch.current_node
end

function story.set_flag(chapter_id, flag, value)
	local ch = story.get_chapter(chapter_id, true)
	if not ch or type(flag) ~= "string" or flag == "" then return false end
	if value == false then
		ch.flags[flag] = nil
	else
		ch.flags[flag] = true
	end
	return true
end

function story.get_flag(chapter_id, flag)
	local ch = story.get_chapter(chapter_id, false)
	if not ch then return nil end
	return ch.flags[flag]
end

function story.discover(chapter_id, node_id)
	local ch = story.get_chapter(chapter_id, true)
	if not ch or type(node_id) ~= "string" then return false end
	if ch.discovered[node_id] then return false end
	ch.discovered[node_id] = true
	notify_quest()
	return true
end

function story.is_discovered(chapter_id, node_id)
	local ch = story.get_chapter(chapter_id, false)
	return ch ~= nil and ch.discovered[node_id] == true
end

function story.complete_node(chapter_id, node_id)
	local ch = story.get_chapter(chapter_id, true)
	if not ch or type(node_id) ~= "string" then return false end
	if ch.completed[node_id] then return false end
	ch.completed[node_id] = true
	story.discover(chapter_id, node_id)
	if ch.current_node == node_id then
		local node = registry.get_node(node_id)
		if node and node.next then
			local next_node = registry.get_node(node.next)
			if next_node and next_node.chapter == chapter_id then
				ch.current_node = node.next
				story.discover(chapter_id, node.next)
			else
				ch.current_node = nil
			end
		else
			ch.current_node = nil
		end
	end
	notify_quest()
	return true
end

function story.is_node_completed(chapter_id, node_id)
	local ch = story.get_chapter(chapter_id, false)
	return ch ~= nil and ch.completed[node_id] == true
end

function story.set_objective(chapter_id, objective_id)
	local ch = story.get_chapter(chapter_id, true)
	if not ch then return false end
	ch.objective = objective_id
	notify_quest()
	return true
end

function story.get_objective(chapter_id)
	local ch = story.get_chapter(chapter_id, false)
	return ch and ch.objective or nil
end

--- Resolve token owner. Supports grant_token(token) or grant_token(chapter, token).
local function resolve_token_owner(chapter_id_or_token, maybe_token)
	local token = maybe_token
	local chapter_hint = chapter_id_or_token
	if maybe_token == nil and type(chapter_id_or_token) == "string" then
		token = chapter_id_or_token
		chapter_hint = nil
	end
	if type(token) ~= "string" or token == "" then return nil, nil end
	local owner = registry.get_token_owner(token)
	if owner then
		return owner, token
	end
	-- Fallback: chapter hint + token without declared owner (dev / future).
	if type(chapter_hint) == "string" and chapter_hint ~= "" then
		return {chapter = chapter_hint, node = chapter_hint, token = token}, token
	end
	return nil, token
end

function story.grant_token(chapter_id_or_token, maybe_token)
	local owner, token = resolve_token_owner(chapter_id_or_token, maybe_token)
	if not owner or not token then return false end
	local run = story.get_run_root(true)
	if not run then return false end
	local node = ensure_run_node(run, owner.chapter, owner.node)
	if node.tokens[token] then return false end
	node.tokens[token] = true
	rebuild_flat_mirrors(run)
	story.refresh_node_requirements(owner.node)
	-- Also refresh container parents (e.g. material_phase).
	local parent = registry.get_parent_node(owner.node)
	if parent then
		story.refresh_node_requirements(parent.id)
	end
	notify_quest()
	return true
end

function story.has_token(chapter_id_or_token, maybe_token)
	local owner, token = resolve_token_owner(chapter_id_or_token, maybe_token)
	if not token then return false end
	local run = story.get_run_root(false)
	if not run then return false end
	if owner then
		local node = story.get_node_run_state(owner.chapter, owner.node, false)
		if node and node.tokens and node.tokens[token] == true then
			return true
		end
	end
	return run.tokens[token] == true
end

function story.revoke_token(chapter_id_or_token, maybe_token)
	local owner, token = resolve_token_owner(chapter_id_or_token, maybe_token)
	if not owner or not token then return false end
	local run = story.get_run_root(true)
	if not run then return false end
	local node = ensure_run_node(run, owner.chapter, owner.node)
	if not node.tokens[token] then return false end
	node.tokens[token] = nil
	rebuild_flat_mirrors(run)
	notify_quest()
	return true
end

function story.grant_node_token(chapter_id, node_id, token)
	if type(chapter_id) ~= "string" or type(node_id) ~= "string" or type(token) ~= "string" then
		return false
	end
	local run = story.get_run_root(true)
	if not run then return false end
	local node = ensure_run_node(run, chapter_id, node_id)
	if node.tokens[token] then return false end
	node.tokens[token] = true
	rebuild_flat_mirrors(run)
	story.refresh_node_requirements(node_id)
	local parent = registry.get_parent_node(node_id)
	if parent then
		story.refresh_node_requirements(parent.id)
	end
	notify_quest()
	return true
end

function story.revoke_node_token(chapter_id, node_id, token)
	if type(chapter_id) ~= "string" or type(node_id) ~= "string" or type(token) ~= "string" then
		return false
	end
	local run = story.get_run_root(true)
	if not run then return false end
	local node = ensure_run_node(run, chapter_id, node_id)
	if not node.tokens[token] then return false end
	node.tokens[token] = nil
	rebuild_flat_mirrors(run)
	notify_quest()
	return true
end

function story.has_node_token(chapter_id, node_id, token)
	local node = story.get_node_run_state(chapter_id, node_id, false)
	return node ~= nil and node.tokens and node.tokens[token] == true
end

function story.list_node_tokens(chapter_id, node_id)
	local node = story.get_node_run_state(chapter_id, node_id, false)
	local out = {}
	if not node or type(node.tokens) ~= "table" then return out end
	for token, owned in pairs(node.tokens) do
		if owned then out[#out + 1] = token end
	end
	table.sort(out)
	return out
end

function story.set_event_stage(chapter_id, node_id, stage)
	if type(chapter_id) ~= "string" or type(node_id) ~= "string" then return false end
	local run = story.get_run_root(true)
	if not run then return false end
	local node = ensure_run_node(run, chapter_id, node_id)
	node.stage = stage
	rebuild_flat_mirrors(run)
	notify_quest()
	return true
end

-- ── Editor / record mutations (NO runtime story transitions) ─────────
-- Player Progress UI and save-repair tools MUST use these.
-- Runtime gameplay continues to use discover / complete_node / grant_token.

function story.edit_node_discovered(chapter_id, node_id, value)
	local ch = story.get_chapter(chapter_id, true)
	if not ch or type(node_id) ~= "string" then return false end
	if value then
		ch.discovered[node_id] = true
	else
		ch.discovered[node_id] = nil
		ch.completed[node_id] = nil
	end
	notify_quest()
	return true
end

function story.edit_node_completed(chapter_id, node_id, value)
	local ch = story.get_chapter(chapter_id, true)
	if not ch or type(node_id) ~= "string" then return false end
	if value then
		ch.completed[node_id] = true
		ch.discovered[node_id] = true
	else
		ch.completed[node_id] = nil
	end
	-- Does NOT advance current_node / next (unlike complete_node).
	notify_quest()
	return true
end

--- Write run token without evaluating requirements / advancing story.
function story.edit_node_token(chapter_id, node_id, token, owned)
	if type(chapter_id) ~= "string" or type(node_id) ~= "string" or type(token) ~= "string" then
		return false
	end
	local run = story.get_run_root(true)
	if not run then return false end
	local node = ensure_run_node(run, chapter_id, node_id)
	if owned then
		if node.tokens[token] then return false end
		node.tokens[token] = true
	else
		if not node.tokens[token] then return false end
		node.tokens[token] = nil
	end
	rebuild_flat_mirrors(run)
	notify_quest()
	return true
end

function story.edit_node_stage(chapter_id, node_id, stage)
	return story.set_event_stage(chapter_id, node_id, stage)
end

--- Set chapter.current_node without completing the previous node.
function story.edit_current_node(chapter_id, node_id)
	local ch = story.get_chapter(chapter_id, true)
	if not ch then return false end
	if node_id ~= nil and not registry.get_node(node_id) then return false end
	ch.current_node = node_id
	if node_id then
		ch.discovered[node_id] = true
	end
	notify_quest()
	return true
end

function story.get_event_stage(chapter_id, node_id)
	if type(chapter_id) ~= "string" or type(node_id) ~= "string" then return nil end
	local node = story.get_node_run_state(chapter_id, node_id, false)
	if node and node.stage ~= nil then return node.stage end
	local run = story.get_run_root(false)
	local ev = run and run.events and run.events[node_id]
	return ev and ev.stage or nil
end

--- Mark permanent first-clear without granting this-run material.
function story.mark_event_first_cleared(chapter_id, node_id)
	return story.complete_node(chapter_id, node_id)
end

--- Evaluate a node's declared requirements against current StoryRun tokens.
function story.evaluate_node_requirements(node_id)
	local node = registry.get_node(node_id)
	if not node then return {} end
	local results = {}
	for _, req in ipairs(registry.list_requirements(node)) do
		local tokens = registry.get_requirement_tokens(node, req)
		local target = tonumber(req.target) or #tokens
		local current = 0
		for _, token in ipairs(tokens) do
			if story.has_token(token) then
				current = current + 1
			end
		end
		results[#results + 1] = {
			id = req.id,
			tokens = tokens,
			current = current,
			target = target,
			complete = target > 0 and current >= target,
			completion_node = req.completion_node,
		}
	end
	return results
end

--- Apply declarative completion when requirements are satisfied (runtime path).
function story.refresh_node_requirements(node_id)
	local node = registry.get_node(node_id)
	if not node then return false end
	local chapter_id = node.chapter
	if not story.is_chapter_available(chapter_id) then return false end
	if story.is_chapter_completed(chapter_id) then return false end

	local results = story.evaluate_node_requirements(node_id)
	if #results == 0 then return false end
	local all_complete = true
	local completion_node = nil
	for _, r in ipairs(results) do
		if not r.complete then
			all_complete = false
		end
		if r.completion_node then
			completion_node = r.completion_node
		end
	end
	if not all_complete then return false end

	-- Chapter1 material_phase keeps existing progression semantics.
	if node_id == "chapter1.material_phase" then
		return story.refresh_material_phase()
	end

	story.complete_node(chapter_id, node_id)
	if completion_node then
		story.complete_node(chapter_id, completion_node)
	end
	return true
end

--- Runtime material gate used by End2 / alchemy helpers.
--- Canon: node requirements on chapter1.material_phase (child_tokens).
--- Falls back to LEGACY chapter.material_plan / required_material_tokens.
--- debug_override incomplete set is Story Test / explicit debug only — never Wiki/Quest canon.
function story.get_runtime_material_requirement(opts)
	opts = opts or {}
	local reqs = story.evaluate_node_requirements("chapter1.material_phase")
	if #reqs > 0 and type(reqs[1].tokens) == "table" and #reqs[1].tokens > 0 then
		return reqs[1].tokens
	end
	local chapter = registry.get_chapter("chapter1")
	if not chapter then return {} end
	local plan = chapter.material_plan
	if type(plan) == "table" and plan.finalized == true then
		local required = chapter.required_material_tokens
		if type(required) == "table" and #required > 0 then
			return required
		end
		return plan.confirmed or {}
	end
	if opts.allow_debug_override == true then
		local dbg = chapter.debug_override
		if type(dbg) == "table" and dbg.allow_incomplete_material_set == true then
			return dbg.incomplete_material_tokens or {}
		end
	end
	return {}
end

function story.has_required_materials()
	local required = story.get_runtime_material_requirement()
	if #required == 0 then return false end
	for _, token in ipairs(required) do
		if not story.has_token(token) then
			return false
		end
	end
	return true
end

function story.count_material_tokens()
	local required = story.get_runtime_material_requirement()
	local count = 0
	for _, token in ipairs(required) do
		if story.has_token(token) then
			count = count + 1
		end
	end
	return count
end

--- Five tokens owned → complete material_phase + prepare_alchemy. Does NOT enter realms.
function story.refresh_material_phase()
	if not story.chapter1_runtime_allowed() then return false end
	if not story.is_chapter_available("chapter1") then return false end
	if story.is_chapter_completed("chapter1") then return false end
	if not story.get_flag("chapter1", "commission_accepted") then return false end
	if not story.is_chapter_active("chapter1") then
		story.start_chapter("chapter1")
	end
	if not story.has_required_materials() then return false end
	story.complete_node("chapter1", "chapter1.material_phase")
	local obj = story.get_objective("chapter1")
	if obj == "chapter1.collect_materials" or obj == nil then
		story.set_objective("chapter1", "chapter1.prepare_alchemy")
	end
	if not story.get_flag("chapter1", "materials_complete") then
		story.set_flag("chapter1", "materials_complete", true)
	end
	-- Legacy flag kept for older End2 checks that still read alchemy_ready.
	if not story.get_flag("chapter1", "alchemy_ready") then
		story.set_flag("chapter1", "alchemy_ready", true)
	end
	story.set_current_node("chapter1", "chapter1.alchemy_setup")
	return true
end

function story.on_alchemy_setup_complete()
	if not story.chapter1_runtime_allowed() then
		return false, "release_scope_disallows_chapter1"
	end
	story.start_chapter("chapter1")
	story.complete_node("chapter1", "chapter1.alchemy_setup")
	story.set_objective("chapter1", "chapter1.enter_realms")
	story.set_current_node("chapter1", "chapter1.enter_realms")
	notify_quest()
	return true
end

--- Thread completion bridge: complete side node + grant material token.
function story.notify_thread_complete(thread_id)
	local map = registry.get_thread_mapping(thread_id)
	if not map or not map.chapter then return false end
	if defs.excluded_from_chapter1[thread_id] then return false end
	if map.chapter == "chapter1" and not story.chapter1_runtime_allowed() then
		return false
	end
	if map.chapter == "chapter1" and not story.is_chapter_available("chapter1") then
		return false
	end
	-- Chapter1 material threads require commission.
	if map.chapter == "chapter1" and map.token then
		if not story.get_flag("chapter1", "commission_accepted") then
			return false
		end
	end
	if map.chapter == "chapter1" then
		story.start_chapter("chapter1")
	end
	local changed = false
	if map.node then
		if story.complete_node(map.chapter, map.node) then changed = true end
	end
	if map.token then
		if story.grant_token(map.chapter, map.token) then changed = true end
	end
	return changed
end

--- LEGACY bulk-complete (migration / old debug). Formal runtime: on_prologue_ending_complete.
--- Does not invent completed home_encounter when home_encounter_skipped is set.
function story.on_prologue_complete()
	story.begin_notify_batch()
	story.start_chapter("prologue")
	story.complete_node("prologue", "prologue.hunt")
	if story.get_flag("prologue", "home_encounter_skipped") then
		local ch = story.get_chapter("prologue", true)
		if ch then
			ch.discovered["prologue.home_encounter"] = true
		end
	else
		story.complete_node("prologue", "prologue.home_encounter")
	end
	story.complete_node("prologue", "prologue.beast_battle")
	story.complete_node("prologue", "prologue.ending")
	local ok = story.complete_chapter("prologue")
	story.end_notify_batch()
	return ok
end

function story.on_qing_midboss_defeated()
	if not story.chapter1_runtime_allowed() then
		return false, "release_scope_disallows_chapter1"
	end
	story.start_chapter("chapter1")
	story.complete_node("chapter1", "chapter1.qing_midboss")
	story.set_current_node("chapter1", "chapter1.post_qing")
	-- Do NOT call on_revelation() here. Post-Qing scene finishes first.
	notify_quest()
	return true
end

function story.on_post_qing_complete()
	if not story.chapter1_runtime_allowed() then
		return false, "release_scope_disallows_chapter1"
	end
	story.complete_node("chapter1", "chapter1.post_qing")
	story.set_current_node("chapter1", "chapter1.revelation")
	notify_quest()
	return true
end

function story.on_revelation()
	if not story.chapter1_runtime_allowed() then
		return false, "release_scope_disallows_chapter1"
	end
	story.complete_node("chapter1", "chapter1.revelation")
	story.set_flag("chapter1", "truth_revealed", true)
	story.set_objective("chapter1", "chapter1.stop_glaze")
	story.set_current_node("chapter1", "chapter1.deep_realms")
	notify_quest()
	return true
end

function story.on_enter_realms()
	if not story.chapter1_runtime_allowed() then
		return false, "release_scope_disallows_chapter1"
	end
	story.start_chapter("chapter1")
	if not story.is_node_completed("chapter1", "chapter1.alchemy_setup") then
		story.complete_node("chapter1", "chapter1.alchemy_setup")
	end
	story.complete_node("chapter1", "chapter1.enter_realms")
	story.set_objective("chapter1", "chapter1.find_qing")
	story.set_current_node("chapter1", "chapter1.search_qing")
	notify_quest()
	return true
end

function story.on_begin_glaze_confrontation()
	if not story.chapter1_runtime_allowed() then
		return false, "release_scope_disallows_chapter1"
	end
	story.set_objective("chapter1", "chapter1.confront_glaze")
	story.set_current_node("chapter1", "chapter1.glaze_confrontation")
	notify_quest()
	return true
end

function story.on_glaze_confrontation_complete()
	if not story.chapter1_runtime_allowed() then
		return false, "release_scope_disallows_chapter1"
	end
	story.complete_node("chapter1", "chapter1.glaze_confrontation")
	story.set_objective("chapter1", "chapter1.defeat_glaze")
	story.set_current_node("chapter1", "chapter1.glaze_boss")
	notify_quest()
	return true
end

function story.on_chapter1_complete()
	if not story.chapter1_runtime_allowed() then
		return false, "release_scope_disallows_chapter1"
	end
	story.complete_node("chapter1", "chapter1.glaze_boss")
	return story.complete_chapter("chapter1")
end

function story.get_audit_snapshot()
	local root = story.get_root(false) or {schema_version = story.SCHEMA_VERSION, chapters = {}}
	local run = story.get_run_root(false) or {tokens = {}}
	local chapters = {}
	for _, chapter_def in ipairs(registry.list_chapters()) do
		local ch = ensure_chapter_shape(root.chapters and root.chapters[chapter_def.id])
		chapters[#chapters + 1] = {
			id = chapter_def.id,
			status = ch.status,
			current_node = ch.current_node,
			objective = ch.objective,
			flags = ch.flags,
			completed = ch.completed,
		}
	end
	local tokens = {}
	for token, owned in pairs(run.tokens or {}) do
		tokens[token] = owned == true
	end
	return {
		schema_version = root.schema_version or story.SCHEMA_VERSION,
		storage = "PermanentData.StoryProgress + elses.StoryRun",
		test_active = story.is_test_active(),
		run_tokens = tokens,
		chapters = chapters,
	}
end

table.insert(story.myToCall, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	params = nil,
	priority = 80,
	Function = function(_, continued)
		story.get_root(true)
		if continued then
			story.get_run_root(true)
		else
			-- New run: clear this-run materials; permanent first clears remain.
			local run = story.get_permanent_run_root(true)
			if run then
				run.tokens = {}
				run.materials = {}
				run.events = {}
			end
		end
		-- Quest first snapshot owns toast/restore: quest_tracker PRE_GAME priority 90.
	end,
})

return story
