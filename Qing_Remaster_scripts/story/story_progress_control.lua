-- Safe player-facing Story progress edits.
-- Uses story.edit_* APIs only — never runtime complete_node / grant_token transitions.

local story = require("Qing_Remaster_scripts.story.story_state")
local registry = require("Qing_Remaster_scripts.story.story_registry")
local cp_defs = require("Qing_Remaster_scripts.story.story_checkpoint_defs")

local control = {
	_backup_permanent = nil,
	_backup_run = nil,
	_backup_taken = false,
}

local SIDE_STATES = {"undiscovered", "discovered", "progressing", "completed"}

local function deep_copy(tbl)
	if type(tbl) ~= "table" then return tbl end
	local out = {}
	for k, v in pairs(tbl) do
		out[k] = deep_copy(v)
	end
	return out
end

local function pick_lang(tbl)
	if type(tbl) ~= "table" then return tostring(tbl or "-") end
	local language = Options and Options.Language
	if language == "en" and tbl.en then return tbl.en end
	return tbl.zh or tbl.en or "-"
end

local function pick_title(node)
	local player = node and node.record and node.record.player
	if player and type(player.title) == "table" then
		return pick_lang(player.title)
	end
	if not node or type(node.title) ~= "table" then
		return node and node.id or "-"
	end
	return pick_lang(node.title)
end

local function player_cfg(node)
	return node and node.record and node.record.player or nil
end

local function side_display_state(chapter_id, node_id)
	local completed = story.is_node_completed(chapter_id, node_id)
	local discovered = story.is_discovered(chapter_id, node_id)
	local stage = story.get_event_stage(chapter_id, node_id)
	if completed then return "completed" end
	if stage and stage ~= "" and stage ~= "idle" and stage ~= "complete" then
		return "progressing"
	end
	if discovered then return "discovered" end
	return "undiscovered"
end

local function clear_chapter_records(ch)
	ch.current_node = nil
	ch.objective = nil
	ch.flags = {}
	ch.discovered = {}
	ch.completed = {}
end

local function virtual_by_id(id)
	for _, v in ipairs(cp_defs.VIRTUAL or {}) do
		if v.id == id then return v end
	end
	return nil
end

function control.list_side_states()
	return SIDE_STATES
end

function control.ensure_backup()
	if control._backup_taken then return true end
	local perm = story.get_permanent_root(false)
	local run = story.get_permanent_run_root(false)
	control._backup_permanent = perm and deep_copy(perm) or nil
	control._backup_run = run and deep_copy(run) or nil
	control._backup_taken = true
	return true
end

function control.has_backup()
	return control._backup_taken == true
end

function control.clear_backup()
	control._backup_permanent = nil
	control._backup_run = nil
	control._backup_taken = false
end

function control.restore_backup(opts)
	opts = opts or {}
	if not control._backup_taken then return false, "no_backup" end
	local save = require("Qing_Remaster_scripts.core.savedata")
	if opts.permanent ~= false and control._backup_permanent then
		if type(save.PermanentData) ~= "table" then save.PermanentData = {} end
		save.PermanentData.StoryProgress = deep_copy(control._backup_permanent)
	end
	if opts.run ~= false and control._backup_run then
		if type(save.elses) ~= "table" then save.elses = {} end
		save.elses.StoryRun = deep_copy(control._backup_run)
	end
	local ok, tracker = pcall(require, "Qing_Remaster_scripts.quest.quest_tracker")
	if ok and tracker and tracker.notify_story_changed then
		tracker.notify_story_changed()
	end
	return true
end

--- Player-facing chapter phase id: before | locked | active | completed
function control.resolve_chapter_phase(chapter_id)
	local ch = story.get_chapter(chapter_id, false)
	if not ch then
		return "before"
	end
	if ch.status == story.STATUS.COMPLETED then
		return "completed"
	end
	if chapter_id == "prologue" then
		if ch.status == story.STATUS.LOCKED
			or (not ch.current_node and not next(ch.completed or {})) then
			return "before"
		end
		return "active"
	end
	if chapter_id == "chapter1" then
		if ch.status == story.STATUS.LOCKED then
			return "locked"
		end
		if ch.status == story.STATUS.AVAILABLE
			and not story.get_flag("chapter1", "commission_accepted") then
			if story.get_flag("chapter1", "opening_seen") then
				return "opened"
			end
			return "before"
		end
		if ch.status == story.STATUS.ACTIVE
			or story.get_flag("chapter1", "commission_accepted") then
			return "active"
		end
		return "before"
	end
	if ch.status == story.STATUS.LOCKED then return "locked" end
	if ch.status == story.STATUS.AVAILABLE then return "before" end
	if ch.status == story.STATUS.ACTIVE then return "active" end
	return "before"
end

function control.phase_label(chapter_id, phase)
	phase = phase or control.resolve_chapter_phase(chapter_id)
	local map = cp_defs.PHASE_LABELS[chapter_id]
	if map and map[phase] then
		return pick_lang(map[phase])
	end
	return phase
end

--- Single semantic source for "where is this chapter now?"
function control.resolve_chapter_checkpoint(chapter_id)
	local phase = control.resolve_chapter_phase(chapter_id)
	if phase == "before" or phase == "locked" or phase == "opened" then
		if chapter_id == "prologue" then
			return "prologue.before"
		end
		if chapter_id == "chapter1" then
			if phase == "locked" then
				return nil
			end
			if phase == "opened" then
				return "chapter1.opened"
			end
			return "chapter1.before"
		end
	end
	if phase == "completed" then
		if chapter_id == "prologue" then return "prologue.complete" end
		if chapter_id == "chapter1" then return "chapter1.complete" end
	end
	local ch = story.get_chapter(chapter_id, false)
	local current = ch and ch.current_node
	if current and registry.is_player_visible(current) then
		-- If current is a child, highlight the parent group.
		local node = registry.get_node(current)
		if node and node.parent and registry.is_player_visible(node.parent) then
			return node.parent
		end
		return current
	end
	-- Fallback: first incomplete player-visible top-level node.
	for _, node in ipairs(registry.list_player_records(chapter_id)) do
		if not story.is_node_completed(chapter_id, node.id) then
			return node.id
		end
	end
	return nil
end

function control.list_chapter_checkpoints(chapter_id)
	local out = {}
	local current_id = control.resolve_chapter_checkpoint(chapter_id)
	for _, v in ipairs(cp_defs.VIRTUAL or {}) do
		if v.chapter == chapter_id then
			out[#out + 1] = {
				id = v.id,
				chapter = chapter_id,
				virtual = true,
				title = pick_lang(v.title),
				order = v.order or 0,
				is_current = current_id == v.id,
				preview_scene = v.preview_scene,
				preview_label = v.preview_label and pick_lang(v.preview_label) or nil,
			}
		end
	end
	for _, node in ipairs(registry.list_player_records(chapter_id)) do
		out[#out + 1] = {
			id = node.id,
			chapter = chapter_id,
			virtual = false,
			node_id = node.id,
			title = pick_title(node),
			order = node.order or 0,
			mode = (node.record and node.record.player and node.record.player.mode) or "checkpoint",
			is_current = current_id == node.id,
			completed = story.is_node_completed(chapter_id, node.id),
		}
	end
	table.sort(out, function(a, b)
		return (a.order or 0) < (b.order or 0)
	end)
	return out
end

local function notify_quest()
	local ok, tracker = pcall(require, "Qing_Remaster_scripts.quest.quest_tracker")
	if ok and tracker and tracker.notify_story_changed then
		tracker.notify_story_changed()
	end
end

local function apply_virtual_prologue_before()
	local pro = story.get_chapter("prologue", true)
	local c1 = story.get_chapter("chapter1", true)
	if not pro or not c1 then return false end
	pro.status = story.STATUS.LOCKED
	clear_chapter_records(pro)
	c1.status = story.STATUS.LOCKED
	clear_chapter_records(c1)
	-- Permanent wipe alone is not enough: clear this-run opening/home gates too.
	local ok, ctrl = pcall(require, "Qing_Remaster_scripts.story.prologue.controller")
	if ok and ctrl and ctrl.reset_run_state then
		ctrl.reset_run_state()
	end
	notify_quest()
	return true
end

local function apply_virtual_chapter1_before()
	local pro = story.get_chapter("prologue", true)
	local c1 = story.get_chapter("chapter1", true)
	if not pro or not c1 then return false end
	pro.status = story.STATUS.COMPLETED
	pro.current_node = nil
	pro.objective = nil
	for _, node in ipairs(registry.list_nodes("prologue")) do
		pro.discovered[node.id] = true
		pro.completed[node.id] = true
	end
	c1.status = story.STATUS.AVAILABLE
	clear_chapter_records(c1)
	c1.objective = nil
	c1.current_node = nil
	c1.flags = {}
	notify_quest()
	return true
end

local function apply_virtual_chapter1_opened()
	local ok = apply_virtual_chapter1_before()
	if not ok then return false end
	local c1 = story.get_chapter("chapter1", true)
	if c1 then
		c1.flags.opening_seen = true
	end
	notify_quest()
	return true
end

local function normalize_prologue_complete()
	local pro = story.get_chapter("prologue", true)
	local c1 = story.get_chapter("chapter1", true)
	if not pro then return end
	pro.status = story.STATUS.COMPLETED
	pro.current_node = nil
	for _, node in ipairs(registry.list_nodes("prologue")) do
		pro.discovered[node.id] = true
		pro.completed[node.id] = true
	end
	if c1 and c1.status == story.STATUS.LOCKED then
		c1.status = story.STATUS.AVAILABLE
		if not story.get_flag("chapter1", "commission_accepted") then
			c1.objective = nil
			c1.current_node = nil
		end
	end
end

function control.apply_chapter_checkpoint(chapter_id, checkpoint_id)
	control.ensure_backup()
	local virt = virtual_by_id(checkpoint_id)
	if virt then
		if checkpoint_id == "prologue.before" then
			return apply_virtual_prologue_before()
		end
		if checkpoint_id == "chapter1.before" then
			return apply_virtual_chapter1_before()
		end
		if checkpoint_id == "chapter1.opened" then
			return apply_virtual_chapter1_opened()
		end
		return false
	end
	return control.apply_checkpoint(checkpoint_id)
end

function control.get_chapter_view(chapter_id)
	local chapter = registry.get_chapter(chapter_id)
	if not chapter then return nil end
	local phase = control.resolve_chapter_phase(chapter_id)
	local checkpoint_id = control.resolve_chapter_checkpoint(chapter_id)
	local reqs = {}
	if chapter_id == "chapter1" then
		reqs = story.evaluate_node_requirements("chapter1.material_phase")
	end
	local progress = reqs[1]
	local cp_title = nil
	if checkpoint_id then
		local virt = virtual_by_id(checkpoint_id)
		if virt then
			cp_title = pick_lang(virt.title)
		else
			cp_title = pick_title(registry.get_node(checkpoint_id))
		end
	end
	return {
		id = chapter_id,
		title = chapter.title,
		phase = phase,
		phase_label = control.phase_label(chapter_id, phase),
		checkpoint_id = checkpoint_id,
		checkpoint_title = cp_title,
		material_progress = progress and {
			current = progress.current,
			target = progress.target,
			complete = progress.complete,
		} or nil,
	}
end

function control.get_node_view(node_id)
	local node = registry.get_node(node_id)
	if not node then return nil end
	local cfg = player_cfg(node)
	if not cfg or cfg.visible ~= true then return nil end

	local chapter_id = node.chapter
	local tokens = {}
	if cfg.show_run_tokens then
		for _, token in ipairs(registry.get_story_tokens(node)) do
			tokens[#tokens + 1] = {
				id = token,
				title = registry.get_token_title(token),
				owned = story.has_token(token) == true,
			}
		end
	end
	local children = {}
	for _, child in ipairs(registry.list_child_nodes(node_id)) do
		local cv = control.get_node_view(child.id)
		if cv then children[#children + 1] = cv end
	end
	local reqs = story.evaluate_node_requirements(node_id)
	local mode = cfg.mode or "checkpoint"
	local current_cp = control.resolve_chapter_checkpoint(chapter_id)
	return {
		id = node_id,
		chapter = chapter_id,
		mode = mode,
		editable = cfg.editable == true,
		display_title = pick_title(node),
		parent = node.parent,
		discovered = story.is_discovered(chapter_id, node_id),
		completed = story.is_node_completed(chapter_id, node_id),
		is_current = current_cp == node_id,
		side_state = side_display_state(chapter_id, node_id),
		tokens = tokens,
		children = children,
		requirements = reqs,
		optional = node.optional == true,
		preview_scene = cfg.preview_scene,
		preview_label = cfg.preview_label and pick_lang(cfg.preview_label) or nil,
	}
end

function control.list_player_records(chapter_id)
	local out = {}
	for _, node in ipairs(registry.list_player_records(chapter_id)) do
		local view = control.get_node_view(node.id)
		if view then out[#out + 1] = view end
	end
	return out
end

function control.set_side_state(node_id, state)
	local node = registry.get_node(node_id)
	if not node then return false end
	control.ensure_backup()
	local chapter_id = node.chapter
	if state == "undiscovered" then
		story.edit_node_discovered(chapter_id, node_id, false)
		story.edit_node_stage(chapter_id, node_id, nil)
		return true
	end
	if state == "discovered" then
		story.edit_node_discovered(chapter_id, node_id, true)
		story.edit_node_completed(chapter_id, node_id, false)
		story.edit_node_stage(chapter_id, node_id, nil)
		return true
	end
	if state == "progressing" then
		story.edit_node_discovered(chapter_id, node_id, true)
		story.edit_node_completed(chapter_id, node_id, false)
		story.edit_node_stage(chapter_id, node_id, "progressing")
		return true
	end
	if state == "completed" then
		story.edit_node_completed(chapter_id, node_id, true)
		story.edit_node_stage(chapter_id, node_id, nil)
		return true
	end
	return false
end

function control.set_node_token(node_id, token, owned)
	local node = registry.get_node(node_id)
	if not node or type(token) ~= "string" then return false end
	control.ensure_backup()
	return story.edit_node_token(node.chapter, node_id, token, owned == true)
end

--- Apply a Story node checkpoint (not virtual).
function control.apply_checkpoint(node_id)
	local node = registry.get_node(node_id)
	if not node then return false end
	control.ensure_backup()
	local chapter_id = node.chapter

	-- Applying a chapter1 node implies prologue is done.
	if chapter_id == "chapter1" then
		apply_virtual_chapter1_before()
	elseif chapter_id == "prologue" then
		local pro = story.get_chapter("prologue", true)
		if pro and pro.status == story.STATUS.LOCKED then
			pro.status = story.STATUS.ACTIVE
		end
	end

	local ch = story.get_chapter(chapter_id, true)
	if not ch then return false end
	if ch.status == story.STATUS.LOCKED then
		ch.status = story.STATUS.AVAILABLE
	end
	if ch.status ~= story.STATUS.COMPLETED then
		ch.status = story.STATUS.ACTIVE
	end

	-- Mark previous player-visible nodes in order as completed when jumping forward.
	for _, n in ipairs(registry.list_player_records(chapter_id)) do
		if n.id == node_id then break end
		story.edit_node_completed(chapter_id, n.id, true)
	end

	story.edit_node_discovered(chapter_id, node_id, true)
	if node.kind == "chapter_end" then
		story.edit_node_completed(chapter_id, node_id, true)
		ch.status = story.STATUS.COMPLETED
		ch.current_node = nil
	else
		story.edit_current_node(chapter_id, node_id)
	end

	local obj = cp_defs.NODE_OBJECTIVE[node_id]
	if obj then
		story.set_objective(chapter_id, obj)
	end

	if node_id == "chapter1.commission" then
		-- Commission scene in progress: ACTIVE, no Quest objective yet.
		story.set_flag(chapter_id, "commission_accepted", false)
		ch.status = story.STATUS.ACTIVE
		ch.objective = nil
	elseif node.parent == "chapter1.material_phase" or node_id == "chapter1.material_phase" then
		story.set_flag(chapter_id, "commission_accepted", true)
		story.edit_node_completed(chapter_id, "chapter1.commission", true)
		story.set_objective(chapter_id, "chapter1.collect_materials")
		if node.parent == "chapter1.material_phase" then
			story.edit_current_node(chapter_id, "chapter1.material_phase")
		end
	elseif node_id == "prologue.complete" then
		normalize_prologue_complete()
	end
	return true
end

function control.advance_requirement(node_id)
	control.ensure_backup()
	return story.refresh_node_requirements(node_id)
end

function control.validate_chapter(chapter_id)
	local issues = {}
	local ch = story.get_chapter(chapter_id, false)
	if not ch then
		return {ok = true, issues = issues}
	end
	for node_id, done in pairs(ch.completed or {}) do
		if done and not ch.discovered[node_id] then
			issues[#issues + 1] = {
				code = "completed_without_discovered",
				node = node_id,
				repairable = true,
			}
		end
	end
	local current = ch.current_node
	if current and not registry.get_node(current) then
		issues[#issues + 1] = {
			code = "invalid_current_node",
			node = current,
			repairable = true,
		}
	end
	local ok = true
	for _, issue in ipairs(issues) do
		if issue.repairable then ok = false end
	end
	return {ok = ok, issues = issues}
end

function control.repair_chapter(chapter_id)
	control.ensure_backup()
	local report = control.validate_chapter(chapter_id)
	local ch = story.get_chapter(chapter_id, true)
	if not ch then return false end
	for _, issue in ipairs(report.issues or {}) do
		if issue.code == "completed_without_discovered" and issue.node then
			ch.discovered[issue.node] = true
		elseif issue.code == "invalid_current_node" then
			ch.current_node = nil
		end
	end
	return true
end

return control
