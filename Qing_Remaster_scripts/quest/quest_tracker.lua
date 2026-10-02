-- Detect StoryProgress changes and push HUD events. No separate QuestProgress save.

local enums = require("Qing_Remaster_scripts.core.enums")
local registry = require("Qing_Remaster_scripts.quest.quest_registry")

local tracker = {
	ToCall = {},
	myToCall = {},
	own_key = "Quest_Tracker_",
	_cache = nil,
	_poll_divider = 0,
	_suspend_reasons = {},
}

local function story()
	local ok, mod = pcall(require, "Qing_Remaster_scripts.story.story_state")
	if ok then return mod end
	return nil
end

local function hud()
	local ok, mod = pcall(require, "Qing_Remaster_scripts.quest.quest_hud")
	if ok then return mod end
	return nil
end

function tracker.is_suspended()
	return next(tracker._suspend_reasons) ~= nil
end

--- Pause Quest snapshots/toasts while a presentation owns the screen.
--- Reasons are a set: multiple systems may suspend without clobbering each other.
function tracker.suspend(reason)
	reason = tostring(reason or "default")
	tracker._suspend_reasons[reason] = true
	return true
end

--- opts.refresh (default true): force first snapshot after resume.
function tracker.resume(reason, opts)
	opts = opts or {}
	reason = tostring(reason or "default")
	tracker._suspend_reasons[reason] = nil
	if tracker.is_suspended() then
		return false
	end
	if opts.refresh ~= false then
		tracker.refresh(true, opts)
	end
	return true
end

function tracker.clear_suspend()
	tracker._suspend_reasons = {}
end

local function snapshot()
	local scope = require("Qing_Remaster_scripts.quest.quest_run_scope")
	if not scope.allows_story_quests() then
		return {
			allowed = false,
			revealed = false,
			chapter_id = nil,
			main_id = nil,
		}
	end
	local st = story()
	if not st then return nil end
	if not registry.is_quest_system_revealed(st) then
		return {
			allowed = true,
			revealed = false,
			chapter_id = nil,
			main_id = nil,
		}
	end
	local main = registry.resolve_main_view(st)
	local side = registry.resolve_side_view(st)
	local chapter_id = registry.resolve_current_chapter(st)
	return {
		allowed = true,
		revealed = true,
		chapter_id = chapter_id,
		main_id = main and main.id or nil,
		main_title = main and main.title or nil,
		main_objective = main and main.objective or nil,
		main_progress = main and main.progress_key or nil,
		main_progress_text = main and main.progress_text or nil,
		main_toast_kind = main and main.toast_kind or nil,
		main_optional = main and main.optional == true or false,
		side_id = side and side.id or nil,
		side_title = side and side.title or nil,
		side_objective = side and side.objective or nil,
	}
end

local function push(ui, toast)
	if ui.enqueue_toast then
		ui.enqueue_toast(toast)
	else
		ui.push_toast(toast)
	end
end

local function emit_complete_toast(ui, completed_main)
	if not ui or type(completed_main) ~= "table" then return end
	local title = completed_main.title or ""
	local objective = completed_main.objective or ""
	if title == "" and objective == "" then return end
	push(ui, {
		kind = "complete",
		line1 = title,
		line2 = objective,
		line3 = "",
		completed = true,
		duration = 60, -- logic frames @30Hz
	})
end

local function emit_diffs(prev, now, opts)
	opts = opts or {}
	local ui = hud()
	if not ui then return end
	if not now or now.allowed == false then
		ui.clear_tracker()
		if ui.clear_toast then ui.clear_toast() end
		return
	end
	if not now.revealed or not now.main_id then
		ui.clear_tracker()
		return
	end

	-- Boot / Continue: restore tracker + remind with "当前目标" (not "新的目标").
	if opts.initial_restore then
		ui.set_tracker({
			title = now.main_title,
			objective = now.main_objective,
			progress = now.main_progress_text,
			side_title = now.side_title,
			side_objective = now.side_objective,
			optional = now.main_optional,
		})
		push(ui, {
			kind = "current",
			line1 = (registry.lang() == "en") and "Current Objective" or "当前目标",
			line2 = now.main_title,
			line3 = now.main_objective,
			duration = 75, -- logic frames @30Hz
		})
		return
	end

	if opts.completed_main then
		emit_complete_toast(ui, opts.completed_main)
	end

	local chapter_changed = prev and prev.chapter_id and now.chapter_id and prev.chapter_id ~= now.chapter_id
	local main_changed = chapter_changed or not prev or prev.main_id ~= now.main_id

	if main_changed then
		local kind = now.main_toast_kind or "new"
		if chapter_changed then
			kind = "major"
		elseif opts.completed_main then
			-- After an explicit complete, next main is a fresh objective.
			kind = now.main_toast_kind or "new"
		elseif not prev or not prev.main_id then
			kind = "new"
		elseif kind ~= "new" and kind ~= "major" then
			kind = "update"
		end
		if kind == "major" then
			push(ui, {
				kind = "major",
				line1 = (registry.lang() == "en") and "Objective changed" or "目标改变",
				line2 = now.main_title,
				line3 = now.main_objective,
				duration = 105, -- logic frames @30Hz
			})
		elseif kind == "new" or not prev or not prev.main_id or opts.completed_main then
			push(ui, {
				kind = "new",
				line1 = (registry.lang() == "en") and "New objective" or "新的目标",
				line2 = now.main_title,
				line3 = now.main_objective,
				duration = 75, -- logic frames @30Hz
			})
		else
			push(ui, {
				kind = "update",
				line1 = (registry.lang() == "en") and "Objective updated" or "目标更新",
				line2 = now.main_title,
				line3 = now.main_objective,
				duration = 70, -- logic frames @30Hz
			})
		end
	elseif prev.main_progress ~= now.main_progress and now.main_progress_text then
		push(ui, {
			kind = "progress",
			line1 = (registry.lang() == "en") and "Alchemical materials" or "炼金素材",
			line2 = now.main_progress_text,
			duration = 50, -- logic frames @30Hz
		})
	end

	if now.side_id and (not prev or prev.side_id ~= now.side_id) then
		push(ui, {
			kind = "side",
			line1 = (registry.lang() == "en") and "Event discovered" or "发现事件",
			line2 = now.side_title,
			line3 = now.side_objective,
			duration = 70, -- logic frames @30Hz
		})
	elseif prev and prev.side_id and not now.side_id then
		push(ui, {
			kind = "side_done",
			line1 = (registry.lang() == "en") and "Event complete" or "事件完成",
			line2 = prev.side_title,
			duration = 50, -- logic frames @30Hz
		})
	end

	ui.set_tracker({
		title = now.main_title,
		objective = now.main_objective,
		progress = now.main_progress_text,
		side_title = now.side_title,
		side_objective = now.side_objective,
		optional = now.main_optional,
	})
end

function tracker.refresh(force, opts)
	if tracker.is_suspended() then
		return
	end
	opts = opts or {}
	local now = snapshot()
	local prev = tracker._cache
	if force or not prev then
		emit_diffs(prev, now, opts)
	else
		local changed = (prev.chapter_id ~= (now and now.chapter_id))
			or (prev.main_id ~= (now and now.main_id))
			or (prev.main_progress ~= (now and now.main_progress))
			or (prev.side_id ~= (now and now.side_id))
			or (prev.main_objective ~= (now and now.main_objective))
			or (prev.revealed ~= (now and now.revealed))
			or (prev.allowed ~= (now and now.allowed))
			or (opts.completed_main ~= nil)
		if changed then
			emit_diffs(prev, now, opts)
		elseif now and now.allowed == false then
			local ui = hud()
			if ui then
				ui.clear_tracker()
				if ui.clear_toast then ui.clear_toast() end
			end
		elseif now and now.main_id then
			local ui = hud()
			if ui then
				ui.set_tracker({
					title = now.main_title,
					objective = now.main_objective,
					progress = now.main_progress_text,
					side_title = now.side_title,
					side_objective = now.side_objective,
					optional = now.main_optional,
				})
			end
		elseif now and not now.revealed then
			local ui = hud()
			if ui then ui.clear_tracker() end
		end
	end
	tracker._cache = now
end

--- opts.completed_main = {id, title, objective} for complete → new toast sequence.
function tracker.notify_story_changed(opts)
	if tracker.is_suspended() then
		return
	end
	tracker.refresh(true, opts)
end

--- Explicit Story event (preferred over guessing main_id diffs).
function tracker.on_story_event(ev)
	if type(ev) ~= "table" then return end
	if ev.type == "main_complete" then
		tracker.refresh(true, {
			completed_main = {
				id = ev.node or ev.id,
				title = ev.title,
				objective = ev.objective,
			},
		})
		return
	end
	tracker.refresh(true)
end

function tracker.get_audit_snapshot()
	local panel_ok, panel = pcall(require, "Qing_Remaster_scripts.quest.quest_panel")
	local reasons = {}
	for reason in pairs(tracker._suspend_reasons or {}) do
		reasons[#reasons + 1] = reason
	end
	table.sort(reasons)
	return {
		cache = tracker._cache,
		suspended = tracker.is_suspended(),
		suspend_reasons = reasons,
		main = registry.resolve_main_view(story()),
		side = registry.resolve_side_view(story()),
		sides = registry.resolve_side_views(story()),
		panel = panel_ok and panel.get_audit_snapshot and panel.get_audit_snapshot() or nil,
		coverage = registry.audit_coverage(),
	}
end

table.insert(tracker.myToCall, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	params = nil,
	priority = 90,
	Function = function()
		tracker._cache = nil
		tracker.clear_suspend()
		-- Sole PRE_GAME Quest owner: restore with "当前目标" (not "新的目标").
		tracker.refresh(true, {initial_restore = true})
	end,
})

table.insert(tracker.ToCall, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		if tracker.is_suspended() then
			return
		end
		tracker._poll_divider = (tracker._poll_divider or 0) + 1
		if tracker._poll_divider % 15 == 0 then
			tracker.refresh(false)
		end
	end,
})

return tracker
