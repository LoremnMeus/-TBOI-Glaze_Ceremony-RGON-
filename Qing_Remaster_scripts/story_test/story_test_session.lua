-- In-memory Story Test sandbox. Never writes permanent StoryProgress while active.

local save = require("Qing_Remaster_scripts.core.savedata")
local defs = require("Qing_Remaster_scripts.story.story_defs")

local session = {
	ToCall = {},
	myToCall = {},
	active = false,
	story_override = nil,
	run_override = nil,
	snapshot_permanent = nil,
	snapshot_run = nil,
	adapter_snapshots = {},
	touched_threads = {},
	selected_step_id = nil,
	prereq_mode = "auto",
	last_validation = nil,
	last_message = nil,
	last_transport_log = nil,
	suppress_unlocks = true,
}

local function deep_copy(value, seen)
	if type(value) ~= "table" then return value end
	seen = seen or {}
	if seen[value] then return seen[value] end
	local out = {}
	seen[value] = out
	for k, v in pairs(value) do
		out[deep_copy(k, seen)] = deep_copy(v, seen)
	end
	return out
end

local function empty_chapter()
	return {
		status = "locked",
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
		schema_version = defs.SCHEMA_VERSION,
		story_run = true,
		tokens = {},
		materials = {},
		events = {},
	}
end

local function empty_story_root()
	return {
		schema_version = defs.SCHEMA_VERSION,
		story_test = true,
		chapters = {
			prologue = empty_chapter(),
			chapter1 = empty_chapter(),
		},
	}
end

function session.is_active()
	return session.active == true
end

function session.suppress_permanent_unlocks()
	return session.active == true and session.suppress_unlocks ~= false
end

function session.get_story_override()
	if not session.active then return nil end
	return session.story_override
end

function session.get_run_override()
	if not session.active then return nil end
	return session.run_override
end

function session.ensure_story_override()
	if type(session.story_override) ~= "table" then
		session.story_override = empty_story_root()
	end
	return session.story_override
end

function session.ensure_run_override()
	if type(session.run_override) ~= "table" then
		session.run_override = empty_run()
	end
	return session.run_override
end

function session.touch_thread(thread_id)
	if type(thread_id) == "string" and thread_id ~= "" then
		session.touched_threads[thread_id] = true
	end
end

function session.get_touched_threads()
	local out = {}
	for id, _ in pairs(session.touched_threads) do
		out[#out + 1] = id
	end
	return out
end

function session.start()
	if session.active then
		session.last_message = "Story Test already active"
		return true
	end
	session.snapshot_permanent = deep_copy(save.PermanentData and save.PermanentData.StoryProgress)
	session.snapshot_run = deep_copy(save.elses and save.elses.StoryRun)
	session.adapter_snapshots = {}
	session.touched_threads = {}
	session.story_override = empty_story_root()
	session.run_override = empty_run()
	session.active = true
	session.last_message = "STORY TEST ACTIVE"
	session.notify_quest()
	return true
end

local THREAD_PATH = {
	["boss.glaze"] = "Qing_Remaster_scripts.bosses.Boss_Glaze",
	wind = "Qing_Remaster_scripts.threads.thread_Wind",
	stone = "Qing_Remaster_scripts.threads.thread_Stone",
	coin = "Qing_Remaster_scripts.threads.thread_Coin",
	glaze = "Qing_Remaster_scripts.threads.thread_Glaze",
}

function session.call_adapter(thread_id, method, ctx)
	local path = THREAD_PATH[thread_id]
	if not path then return false, "unknown thread" end
	local ok, mod = pcall(require, path)
	if not ok or type(mod) ~= "table" or type(mod.story_test) ~= "table" then
		return false, "no adapter"
	end
	local fn = mod.story_test[method]
	if type(fn) ~= "function" then
		return false, "no " .. tostring(method)
	end
	local cok, a, b = pcall(fn, ctx or {})
	if not cok then return false, tostring(a) end
	return a, b
end

function session.restore()
	if not session.active then
		session.last_message = "Story Test not active"
		return false
	end
	-- Cleanup while overlay still active so gates still see test story.
	for _, thread_id in ipairs(session.get_touched_threads()) do
		session.call_adapter(thread_id, "cleanup", {test_active = true})
		local snap = session.adapter_snapshots[thread_id]
		if snap ~= nil then
			session.call_adapter(thread_id, "restore", snap)
		end
	end
	session.active = false
	session.story_override = nil
	session.run_override = nil
	session.adapter_snapshots = {}
	session.touched_threads = {}
	session.selected_step_id = nil
	session.last_validation = nil
	session.last_transport_log = nil
	session.snapshot_permanent = nil
	session.snapshot_run = nil
	session.last_message = "Story Test restored (overlay cleared)"
	session.notify_quest()
	return true
end

function session.set_override_root(root)
	session.story_override = root
end

function session.set_run_override(root)
	session.run_override = root
end

function session.store_adapter_snapshot(thread_id, snap)
	session.adapter_snapshots[thread_id] = snap
end

function session.notify_quest()
	local ok, tracker = pcall(require, "Qing_Remaster_scripts.quest.quest_tracker")
	if ok and tracker and tracker.notify_story_changed then
		tracker.notify_story_changed()
	end
end

function session.set_selected_step(id)
	session.selected_step_id = id
end

function session.get_selected_step()
	return session.selected_step_id
end

function session.set_prereq_mode(mode)
	if mode == "minimal" or mode == "custom" or mode == "auto" then
		session.prereq_mode = mode
	end
end

function session.get_prereq_mode()
	return session.prereq_mode or "auto"
end

local enums = require("Qing_Remaster_scripts.core.enums")
table.insert(session.myToCall, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	params = nil,
	priority = 70,
	Function = function()
		if session.active then
			session.active = false
			session.story_override = nil
			session.run_override = nil
			session.touched_threads = {}
			session.last_message = "Story Test cleared on game start"
		end
	end,
})

if ModCallbacks and ModCallbacks.MC_PRE_GAME_EXIT then
	table.insert(session.ToCall, {
		CallBack = ModCallbacks.MC_PRE_GAME_EXIT,
		params = nil,
		Function = function()
			if session.active then
				session.active = false
				session.story_override = nil
				session.run_override = nil
				session.touched_threads = {}
			end
		end,
	})
end

return session
