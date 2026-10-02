-- Applies Story Test Definitions onto session overlays + transport + thread adapters.
-- Must NOT touch Thread private save.elses keys directly.

local registry = require("Qing_Remaster_scripts.story_test.story_test_registry")
local session = require("Qing_Remaster_scripts.story_test.story_test_session")
local transport = require("Qing_Remaster_scripts.story_test.story_test_transport")
local story_state = require("Qing_Remaster_scripts.story.story_state")
local story_defs = require("Qing_Remaster_scripts.story.story_defs")
local quest_registry = require("Qing_Remaster_scripts.quest.quest_registry")
local scenes = require("Qing_Remaster_scripts.story.story_scenes")

local runner = {}

local function empty_chapter(status)
	return {
		status = status or "locked",
		current_node = nil,
		objective = nil,
		flags = {},
		discovered = {},
		completed = {},
		tokens = {},
		materials = {},
	}
end

local function empty_run()
	return {
		schema_version = story_defs.SCHEMA_VERSION,
		story_run = true,
		tokens = {},
		materials = {},
		events = {},
	}
end

local function set_list_map(dst, list)
	for _, id in ipairs(list or {}) do
		dst[id] = true
	end
end

local function build_overlays(step, prereq_mode)
	prereq_mode = prereq_mode or session.get_prereq_mode()
	local story_root = {
		schema_version = story_defs.SCHEMA_VERSION,
		story_test = true,
		chapters = {
			prologue = empty_chapter("locked"),
			chapter1 = empty_chapter("locked"),
		},
	}
	local run_root = empty_run()
	local spec = step.story or {}

	local completed = {}
	local discovered = {}
	local flags = {}
	local run_tokens = {}

	if step.chapter == "prologue" then
		story_root.chapters.prologue = empty_chapter(spec.status or "active")
		story_root.chapters.prologue.current_node = spec.current_node
		story_root.chapters.prologue.objective = spec.objective
		set_list_map(story_root.chapters.prologue.completed, spec.completed_nodes)
		set_list_map(story_root.chapters.prologue.discovered, spec.discovered_nodes)
		return story_root, run_root
	end

	-- Chapter1 tests assume prologue completed.
	local prologue = empty_chapter("completed")
	prologue.completed["prologue.complete"] = true
	prologue.discovered["prologue.complete"] = true
	story_root.chapters.prologue = prologue

	local ch = empty_chapter(spec.status or "active")
	ch.current_node = spec.current_node
	ch.objective = spec.objective

	if prereq_mode == "minimal" then
		flags.commission_accepted = true
	else
		local before = tonumber(step.canonical_materials_before)
		if before == nil then before = 0 end
		local mats = registry.material_tokens_before(before)
		for _, token in ipairs(mats) do
			run_tokens[token] = true
		end
		for _, node_id in ipairs(registry.material_nodes_for_tokens(mats)) do
			completed[node_id] = true
			discovered[node_id] = true
		end
		if before > 0 or spec.commission_accepted ~= false then
			flags.commission_accepted = true
			completed["chapter1.commission"] = true
			discovered["chapter1.commission"] = true
		end
		if before >= 5 then
			completed["chapter1.material_phase"] = true
			discovered["chapter1.material_phase"] = true
			flags.materials_complete = true
			flags.alchemy_ready = true
		end
	end

	if spec.commission_accepted == true then flags.commission_accepted = true end
	if spec.commission_accepted == false then flags.commission_accepted = nil end
	if spec.truth_revealed == true then flags.truth_revealed = true end
	set_list_map(completed, spec.completed_nodes)
	set_list_map(discovered, spec.discovered_nodes)
	set_list_map(run_tokens, spec.tokens)
	if type(spec.flags) == "table" then
		for k, v in pairs(spec.flags) do
			if v then flags[k] = true else flags[k] = nil end
		end
	end
	for _, token in ipairs(spec.absent_tokens or {}) do
		run_tokens[token] = nil
	end
	if step.force_tokens then
		set_list_map(run_tokens, step.force_tokens)
	end

	-- Repeat acquisition: permanent first clear, no run token.
	if step.id == "chapter1.coin.repeat_acquisition" then
		completed["chapter1.coin"] = true
		discovered["chapter1.coin"] = true
		run_tokens["chapter1.material.coin"] = nil
	end

	local materials = {}
	for token, owned in pairs(run_tokens) do
		if owned then
			local key = token:match("^chapter1%.material%.(.+)$")
			if key then materials[key] = true end
		end
	end

	ch.completed = completed
	ch.discovered = discovered
	ch.flags = flags
	story_root.chapters.chapter1 = ch
	run_root.tokens = run_tokens
	run_root.materials = materials
	return story_root, run_root
end

function runner.ensure_session()
	if not session.is_active() then
		session.start()
	end
	return session.is_active()
end

function runner.apply_story_state(step, prereq_mode)
	local story_root, run_root = build_overlays(step, prereq_mode)
	session.set_override_root(story_root)
	session.set_run_override(run_root)
	session.notify_quest()
	return story_root, run_root
end

function runner.prepare(step_id, opts)
	opts = opts or {}
	local step = registry.get_step(step_id)
	if not step then return false, "unknown step" end
	if registry.step_has_errors(step_id) then
		return false, "step has audit errors"
	end
	if (step.implementation_status or "implemented") == "planned"
		and (step.entry and (step.entry.mode == "natural" or step.entry.mode == "direct")) then
		-- Allow state prepare for planned steps; transport/trigger stay blocked in UI.
	end
	runner.ensure_session()
	session.set_selected_step(step_id)
	runner.apply_story_state(step, opts.prereq_mode or session.get_prereq_mode())
	if step.entry and step.entry.mode == "boss_glaze" then
		local id = "boss.glaze"
		session.touch_thread(id)
		if not session.adapter_snapshots[id] then
			local snapshot = session.call_adapter(id, "snapshot", {test_active = true})
			if type(snapshot) == "table" then session.store_adapter_snapshot(id, snapshot) end
		end
		local ok, msg = session.call_adapter(id, "prepare", {test_active = true})
		if ok == false then return false, msg end
	end

	if step.thread and step.thread.id then
		session.touch_thread(step.thread.id)
		if not session.adapter_snapshots[step.thread.id] then
			local snap = session.call_adapter(step.thread.id, "snapshot", {test_active = true})
			if snap ~= false and type(snap) == "table" then
				session.store_adapter_snapshot(step.thread.id, snap)
			end
		end
		local ctx = {
			phase = step.thread.phase,
			step = step,
			test_active = true,
			prereq_mode = session.get_prereq_mode(),
		}
		if step.thread.reset then
			session.call_adapter(step.thread.id, "reset", ctx)
		end
		session.call_adapter(step.thread.id, "prepare", ctx)
	end

	local validation = runner.validate(step)
	session.last_validation = validation
	session.last_message = "Prepared " .. step_id
	return true, session.last_message, validation
end

function runner.prepare_and_enter(step_id, opts)
	local ok, msg, validation = runner.prepare(step_id, opts)
	if not ok then return false, msg, validation end
	local step = registry.get_step(step_id)
	local mode = step.entry and step.entry.mode
	if mode == "boss_glaze" then
		local spawned, spawn_message = session.call_adapter("boss.glaze", "trigger", {test_active = true})
		return spawned, spawn_message, validation
	end
	if mode == "state_only" or mode == "direct_scene" then
		session.last_message = msg .. " (no transport)"
		return true, session.last_message, validation
	end
	if (step.implementation_status or "") == "planned" then
		session.last_message = msg .. " | transport disabled (planned)"
		return false, session.last_message, validation
	end
	local tok, tmsg, tlog = transport.prepare_run(step, opts)
	session.last_transport_log = tlog
	session.last_message = msg .. " | transport: " .. tostring(tmsg)
	local tval = transport.validate_step(step)
	if tval then
		for _, row in ipairs(tval) do
			validation[#validation + 1] = row
		end
		session.last_validation = validation
	end
	if not tok then return false, session.last_message, validation end
	return true, session.last_message, validation
end

--- Reseed current floor and re-apply room/player targeting for the selected step.
function runner.reseed_and_retry(step_id, _opts)
	step_id = step_id or session.get_selected_step()
	local step = registry.get_step(step_id)
	if not step then return false, "unknown step" end
	runner.ensure_session()
	session.set_selected_step(step_id)

	local ok_reseed, reseed_msg = transport.reseed_floor()
	if not ok_reseed then
		session.last_message = "reseed failed: " .. tostring(reseed_msg)
		return false, session.last_message
	end

	local messages = {"reseed"}
	local log = {
		steps = {},
		readiness = transport.READINESS.READY,
		level = {result = "reseed only", after = nil},
	}
	local room = step.room or (step.run and step.run.room)
	if room and room.selector then
		local ok, msg, rlog = transport.apply_room_selector(room.selector, {
			dimension = room.dimension,
			spawn_anchor = room.spawn_anchor,
		})
		messages[#messages + 1] = tostring(msg)
		log.room = rlog or {selector = room.selector, result = msg}
		if rlog and rlog.readiness then
			log.readiness = rlog.readiness
		end
		if not ok then
			session.last_transport_log = log
			session.last_message = table.concat(messages, "; ")
			return false, session.last_message, log
		end
	end
	if step.player then
		local pok, pmsg = transport.apply_player_loadout(step.player)
		messages[#messages + 1] = tostring(pmsg)
		log.player = {result = pmsg, ok = pok}
		if not pok then
			log.readiness = transport.READINESS.NEARBY
		end
	end
	session.last_transport_log = log

	if step.thread and step.thread.id then
		local ctx = {
			phase = step.thread.phase,
			step = step,
			test_active = true,
			prereq_mode = session.get_prereq_mode(),
		}
		if step.thread.reset then
			session.call_adapter(step.thread.id, "reset", ctx)
		end
		session.call_adapter(step.thread.id, "prepare", ctx)
	end

	local validation = runner.validate(step)
	local tval = transport.validate_step(step)
	if tval then
		for _, row in ipairs(tval) do
			validation[#validation + 1] = row
		end
	end
	session.last_validation = validation
	session.last_message = "Reseed retry: " .. table.concat(messages, "; ")
	return true, session.last_message, validation
end

function runner.play_scene(step_id)
	local step = registry.get_step(step_id or session.get_selected_step())
	if not step then return false, "no step" end
	runner.ensure_session()
	local entry = step.entry or {}
	if entry.mode ~= "direct_scene" or not entry.scene then
		return false, "not a scene step"
	end
	if not scenes.is_available(entry.scene) then
		return false, "scene not wired: " .. tostring(entry.scene)
	end
	local ok, msg = scenes.play(entry.scene)
	session.last_message = tostring(msg)
	session.last_validation = runner.validate(step)
	return ok, session.last_message, session.last_validation
end

function runner.apply_transition(step_id)
	local step = registry.get_step(step_id or session.get_selected_step())
	if not step then return false, "no step" end
	runner.ensure_session()
	local entry = step.entry or {}
	local scene_id = entry.scene or step.complete_hook and step.story_node
	if step.complete_hook == "on_revelation" then
		scene_id = "chapter1.revelation"
	end
	if not scene_id then
		return false, "no transition target"
	end
	local ok, msg = scenes.apply_transition(scene_id)
	-- Chapter opening defers Quest toast until the title fade completes.
	if type(msg) ~= "string" or not msg:find("deferred", 1, true) then
		session.notify_quest()
	end
	session.last_message = tostring(msg)
	local expected = step.expected_after_complete or step.expected
	session.last_validation = runner.validate_expected(expected)
	return ok, session.last_message, session.last_validation
end

function runner.trigger(step_id)
	-- Backward-compatible: prefer scene play, else thread trigger, else transition.
	local step = registry.get_step(step_id or session.get_selected_step())
	if not step then return false, "no step" end
	local entry = step.entry or {}
	if entry.mode == "boss_glaze" then return runner.prepare_and_enter(step.id) end
	if entry.mode == "direct_scene" then
		if scenes.is_available(entry.scene) then
			return runner.play_scene(step.id)
		end
		return runner.apply_transition(step.id)
	end
	if step.thread and step.thread.id then
		session.touch_thread(step.thread.id)
		local ok, msg = session.call_adapter(step.thread.id, "trigger", {
			phase = step.thread.phase,
			step = step,
			test_active = true,
		})
		session.last_message = tostring(msg or (ok and "triggered" or "trigger failed"))
		return ok, session.last_message
	end
	return false, "No trigger for this step"
end

function runner.complete_step(step_id)
	local step = registry.get_step(step_id or session.get_selected_step())
	if not step then return false, "no step" end
	runner.ensure_session()
	if step.complete_hook == "on_revelation" then
		story_state.on_revelation()
	elseif step.story_node then
		story_state.complete_node(step.chapter, step.story_node)
		local map = registry.get_material_node_map()
		for token, node in pairs(map) do
			if node == step.story_node then
				story_state.grant_token("chapter1", token)
			end
		end
	end
	session.notify_quest()
	local expected = step.expected_after_complete or step.expected
	local validation = runner.validate_expected(expected)
	session.last_validation = validation
	session.last_message = "Completed " .. step.id
	return true, session.last_message, validation
end

function runner.reset_step(step_id)
	return runner.prepare(step_id or session.get_selected_step())
end

function runner.previous_step()
	local id = session.get_selected_step()
	local steps = registry.list_steps()
	for i, step in ipairs(steps) do
		if step.id == id and i > 1 then
			return runner.prepare(steps[i - 1].id)
		end
	end
	return false, "no previous"
end

function runner.next_step()
	local id = session.get_selected_step()
	local steps = registry.list_steps()
	for i, step in ipairs(steps) do
		if step.id == id and i < #steps then
			return runner.prepare(steps[i + 1].id)
		end
	end
	return false, "no next"
end

function runner.validate_expected(expected)
	expected = expected or {}
	local results = {}
	local function add(key, pass, actual, expected_value)
		results[#results + 1] = {
			key = key,
			-- legacy alias for older callers / logs
			name = key,
			pass = pass == true,
			actual = actual,
			expected = expected_value,
			detail = actual ~= nil and tostring(actual) or nil,
		}
	end
	if expected.objective then
		local actual = story_state.get_objective("chapter1")
		add("objective", actual == expected.objective, actual, expected.objective)
	end
	if expected.current_node then
		local chapter = expected.chapter or "chapter1"
		local ch = story_state.get_chapter(chapter, false)
		local actual = ch and ch.current_node or nil
		add("current_node", actual == expected.current_node, actual, expected.current_node)
	end
	if expected.material_count ~= nil then
		local count = story_state.count_material_tokens()
		add("material_count", count == expected.material_count, count, expected.material_count)
	end
	if expected.token then
		local owned = story_state.has_token("chapter1", expected.token) == true
		add("token", owned, owned and expected.token or nil, expected.token)
	end
	if expected.token_absent then
		local absent = not story_state.has_token("chapter1", expected.token_absent)
		add("token_absent", absent, absent and "absent" or "present", "absent")
	end
	if expected.flag then
		local on = story_state.get_flag("chapter1", expected.flag) == true
		add("flag", on, on and expected.flag or nil, expected.flag)
	end
	if expected.flag_absent then
		local absent = story_state.get_flag("chapter1", expected.flag_absent) ~= true
		add("flag_absent", absent, absent and "absent" or "present", "absent")
	end
	if expected.side_event then
		local disc = story_state.is_discovered("chapter1", expected.side_event) == true
		add("side_discovered", disc, disc and expected.side_event or nil, expected.side_event)
	end
	if expected.node_completed then
		local chapter = expected.chapter or "chapter1"
		local done = story_state.is_node_completed(chapter, expected.node_completed) == true
		add("node_completed", done, done and expected.node_completed or nil, expected.node_completed)
	end
	if expected.chapter_status then
		local ch = story_state.get_chapter("chapter1", false)
		local actual = ch and ch.status or nil
		add("chapter_status", actual == expected.chapter_status, actual, expected.chapter_status)
	end
	-- Default for story steps with a current_node: Quest must resolve while revealed.
	local want_quest = expected.quest_resolves
	if want_quest == nil and expected.current_node then
		want_quest = true
	end
	if want_quest then
		local main = quest_registry.resolve_main_view(story_state)
		local panel_view = quest_registry.resolve_panel_view(story_state)
		local ok = main ~= nil and panel_view ~= nil and panel_view.main ~= nil
		add("quest_resolves", ok, main and main.id or nil, true)
	end
	return results
end

function runner.validate(step)
	step = step or registry.get_step(session.get_selected_step())
	if not step then return {} end
	return runner.validate_expected(step.expected)
end

function runner.inspect()
	local ch1 = story_state.get_chapter("chapter1", false) or empty_chapter()
	local prologue = story_state.get_chapter("prologue", false) or empty_chapter()
	local main = quest_registry.resolve_main_view(story_state)
	local side = quest_registry.resolve_side_view(story_state)
	local sides = quest_registry.resolve_side_views(story_state)
	local panel_view = quest_registry.resolve_panel_view(story_state)
	local chapter_id = quest_registry.resolve_current_chapter(story_state)
	local revealed = quest_registry.is_quest_system_revealed(story_state)
	local current_node = nil
	local objective = nil
	if chapter_id then
		current_node = story_state.get_current_node and story_state.get_current_node(chapter_id)
		objective = story_state.get_objective and story_state.get_objective(chapter_id)
	end
	local entry_ok, entry_reason = false, "no_panel"
	do
		local ok, panel = pcall(require, "Qing_Remaster_scripts.quest.quest_panel")
		if ok and panel and panel.can_show_entry then
			entry_ok, entry_reason = panel.can_show_entry()
		elseif revealed then
			entry_ok, entry_reason = true, "revealed_offline"
		else
			entry_ok, entry_reason = false, "not_revealed"
		end
	end
	local tokens = {}
	for _, token in ipairs(registry.get_canonical_material_route()) do
		tokens[#tokens + 1] = {
			id = token,
			owned = story_state.has_token("chapter1", token) == true,
		}
	end
	local thread_inspect = {}
	for _, tid in ipairs(session.get_touched_threads()) do
		local ok, data = session.call_adapter(tid, "inspect", {test_active = true})
		thread_inspect[tid] = ok ~= false and data or {error = tostring(data)}
	end
	local step = registry.get_step(session.get_selected_step())
	local quest_prefs = nil
	do
		local ok, hud = pcall(require, "Qing_Remaster_scripts.quest.quest_hud")
		if ok and hud and hud.get_prefs then
			quest_prefs = hud.get_prefs()
		end
	end
	local info = {
		test_active = session.is_active(),
		selected = session.get_selected_step(),
		prereq_mode = session.get_prereq_mode(),
		message = session.last_message,
		validation = session.last_validation,
		transport_log = session.last_transport_log,
		audit = registry.audit_summary(),
		capabilities = registry.step_capabilities(step),
		flow_node = registry.flow_checks_for_step(step),
		flow_chapter = registry.audit_story_flow((step and step.chapter) or "chapter1"),
		prologue = {status = prologue.status, current_node = prologue.current_node},
		chapter1 = {
			status = ch1.status,
			current_node = ch1.current_node,
			objective = ch1.objective,
			flags = ch1.flags,
		},
		tokens = tokens,
		quest_main = main,
		quest_side = side,
		quest_sides = sides,
		quest_panel = panel_view,
		quest_prefs = quest_prefs,
		quest_coverage = quest_registry.audit_coverage(),
		quest_gate = {
			revealed = revealed,
			chapter_id = chapter_id,
			current_node = current_node,
			objective = objective,
			resolve_source = main and main.resolve_source or nil,
			quest_id = main and main.id or nil,
			entry_ok = entry_ok == true,
			entry_reason = entry_reason,
		},
		quest_panel_audit = nil,
		quest_pause = nil,
		threads = thread_inspect,
	}
	do
		local ok, panel = pcall(require, "Qing_Remaster_scripts.quest.quest_panel")
		if ok and panel and panel.get_audit_snapshot then
			info.quest_panel_audit = panel.get_audit_snapshot()
		end
		local ok2, pause_ui = pcall(require, "Qing_Remaster_scripts.auxiliary.pause_ui")
		if ok2 and pause_ui and pause_ui.get_audit_snapshot then
			info.quest_pause = pause_ui.get_audit_snapshot()
		end
	end
	return info
end

function runner.rebuild_quest()
	session.notify_quest()
	return true, "Quest HUD rebuilt from Story"
end

return runner
