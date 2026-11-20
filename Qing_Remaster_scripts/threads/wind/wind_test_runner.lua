-- Async storm test entry. Buttons only queue work.
-- Floor changes and room transfers finish on a later callback before any cinematic starts.

local session = require("Qing_Remaster_scripts.story_test.story_test_session")
local transport = require("Qing_Remaster_scripts.story_test.story_test_transport")
local thread_wind = require("Qing_Remaster_scripts.threads.thread_Wind")
local encounter = require("Qing_Remaster_scripts.threads.wind.storm_encounter")
local arena_room = require("Qing_Remaster_scripts.threads.wind.arena_room")
local wind = require("Qing_Remaster_scripts.threads.wind.wind_runtime")
local policy = require("Qing_Remaster_scripts.threads.wind.wind_start_policy")

local PRESET = "mausoleum_gehenna_1"
local FLOOR_TIMEOUT = 300
local ROOM_TIMEOUT = 300

local M = {
	phases = {
		{id = "eye", zh = "风眼形成", en = "Eye forming"},
		{id = "reveal", zh = "顶部显现", en = "Tip reveal"},
		{id = "descent", zh = "升空俯冲", en = "Surge and dive"},
		{id = "ascend", zh = "风柱升空", en = "Ascend"},
		{id = "dive", zh = "高速俯冲", en = "Dive"},
		{id = "impact", zh = "白色爆发", en = "Impact cover"},
		{id = "transfer", zh = "转场进 Arena", en = "Transfer to arena"},
	},
	selected = 1,
}

local job = nil
local next_request = 0

local function frame()
	return Game():GetFrameCount()
end

local function current_sgid()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	return desc and desc.SafeGridIndex or nil
end

local function apply_cleanup(target)
	if not target then return end
	encounter.cleanup_test_attempt(policy.failure_cleanup_plan(target))
end

local function fail(reason)
	if not job or job.status == "FAILED" then return end
	local dying = job
	apply_cleanup(dying)
	job = dying
	job.status = "FAILED"
	job.error = tostring(reason or "failed")
	job.step = "failed"
	session.last_message = "FAILED: " .. job.error
end

local function ensure_session()
	session.start()
	session.touch_thread("wind")
	session.adapter_snapshots = session.adapter_snapshots or {}
	if session.adapter_snapshots.wind == nil and thread_wind.story_test and thread_wind.story_test.snapshot then
		session.adapter_snapshots.wind = thread_wind.story_test.snapshot()
	end
end

local PHASE_READY = {
	eye = {
		[encounter.PHASE.EYE_DISCOVERED] = true,
		[encounter.PHASE.EYE_FORMING] = true,
	},
	reveal = {[encounter.PHASE.ZENNITH_REVEAL] = true},
	descent = {[encounter.PHASE.ZENNITH_DESCENDING] = true},
	ascend = {[encounter.PHASE.ZENNITH_DESCENDING] = true},
	dive = {[encounter.PHASE.ZENNITH_DESCENDING] = true},
	impact = {
		[encounter.PHASE.IMPACT] = true,
		[encounter.PHASE.COVER_IN] = true,
	},
}

local function phase_is_ready(action)
	local phase = encounter.get_phase()
	local ready = PHASE_READY and PHASE_READY[action]
	return ready and ready[phase] == true
end

local function start_phase_in_room()
	if not job or job.step ~= "room" then return end
	if current_sgid() ~= job.expect then
		return
	end
	job.status = "ARRIVED"
	local action = job.room_action
	local ok, err = true, nil
	if action == "full" or action == "arrive" then
		if encounter.get_phase() ~= encounter.PHASE.SEARCHING
			and encounter.get_phase() ~= encounter.PHASE.EYE_DISCOVERED then
			encounter.set_phase(encounter.PHASE.SEARCHING)
		end
		ok, err = encounter.begin_eye_discovery()
	elseif action == "eye" then
		ok, err = encounter.test_play_eye()
	elseif action == "reveal" then
		ok, err = encounter.test_play_reveal()
	elseif action == "descent" then
		ok, err = encounter.test_play_descent()
	elseif action == "ascend" then
		ok, err = encounter.test_play_ascend()
	elseif action == "dive" then
		ok, err = encounter.test_play_dive()
	elseif action == "impact" then
		ok, err = encounter.test_play_impact()
	elseif action == "transfer" then
		ok, err = encounter.test_play_transfer()
	else
		ok, err = false, "unknown_phase"
	end
	encounter.mark_story_owned(false)
	if not ok then
		fail(err or action)
		return
	end
	if action == "arrive" then
		job.status = "ARRIVED"
		job.step = "done"
		job.error = nil
		session.last_message = "已到达风眼"
		return
	end
	job.step = "cinematic"
	job.status = "RUNNING"
	job.since = frame()
	job.error = nil
	session.last_message = "RUNNING: " .. tostring(action)
end

local function request_eye(action)
	local triggered, terr = thread_wind.activate_explore({deterministic = true})
	if not triggered then
		fail(terr or "formal_trigger_failed")
		return
	end
	job.touched_scene = true
	encounter.mark_story_owned(false)
	if encounter.get_phase() ~= encounter.PHASE.SEARCHING then
		encounter.set_phase(encounter.PHASE.SEARCHING)
	end
	local sgid = thread_wind.find_exact_room(0)
	if sgid == nil then
		fail("eye_room_missing")
		return
	end
	job.expect = sgid
	job.step = "room"
	job.room_action = action
	job.travel_token = job.request_id
	job.status = "QUEUED"
	job.since = frame()
	job.error = nil
	session.last_message = "QUEUED: moving to eye " .. tostring(sgid)
	local ok, err = thread_wind.goto_eye_room()
	if not ok then
		fail(err or "goto_eye_failed")
		return
	end
	if current_sgid() == sgid then
		start_phase_in_room()
	end
end

local function after_floor()
	if not job then return end
	if job.id == "storm" then
		local ok, err = thread_wind.activate_explore({deterministic = true})
		if not ok then
			fail(err or "storm_start_failed")
			return
		end
		job.status = "COMPLETED"
		job.step = "done"
		job.error = nil
		if err == "already_active" then
			session.last_message = "风暴已启动"
		else
			session.last_message = "COMPLETED: storm exploring"
		end
		return
	end
	if job.id == "eye_goto" then
		request_eye("arrive")
		return
	end
	if job.id == "battle" then
		job.touched_scene = true
		local ok, err = encounter.arm_direct_battle()
		if not ok then
			fail(err or "arena_prepare_failed")
			return
		end
		job.since = frame()
		if select(1, encounter.direct_battle_ready()) then
			job.step = "done"
			job.status = "COMPLETED"
			job.error = nil
			session.last_message = "COMPLETED: arena battle"
			return
		end
		job.step = "battle"
		job.status = select(1, arena_room.validate_current()) and "RUNNING" or "QUEUED"
		session.last_message = "QUEUED: arena transfer requested"
		return
	end
	if job.id == "full" then
		request_eye("full")
		return
	end
	if job.id == "phase" then
		request_eye(job.phase_id)
		return
	end
	fail("bad_job")
end

local function begin(id, phase_id)
	local decision = policy.click_action(job, id)
	if decision == "ignore_same" then
		return
	end
	if decision == "busy" then
		session.last_message = "已有测试进行中: " .. tostring(job and job.id)
		return
	end
	if job then
		apply_cleanup(job)
	end
	ensure_session()
	next_request = next_request + 1
	job = {
		id = id,
		phase_id = phase_id,
		status = "QUEUED",
		step = "floor",
		since = frame(),
		error = nil,
		request_id = next_request,
		may_spawn_boss = (id == "battle" or id == "full" or (id == "phase" and phase_id == "transfer")),
		touched_scene = false,
	}
	encounter.set_test_request(next_request)
	session.last_message = "QUEUED: " .. id
	if id == "wind" then
		job.step = "wind"
		job.status = "RUNNING"
		wind.set_solo_visual_layer("all")
		local ok_dbg, err_dbg = wind.set_debug_override({
			preset = "strong",
			show_particles = true,
			force_white_debug = false,
		})
		if not ok_dbg then
			fail(err_dbg or "wind_override_failed")
			return
		end
		job.visible_run = 0
		local center = Game():GetRoom():GetCenterPos()
		wind.begin({
			kind = "environment",
			intensity = 0.75,
			phase = "eye",
			pos = center,
			eye_radius_scale = 1,
			prefill = true,
		})
		local tornado = require("Qing_Remaster_scripts.threads.wind.tornado_visual")
		tornado.begin(center, {growth = 1, intensity = 0.85})
		if tornado.set_external_compose then tornado.set_external_compose(false) end
		if tornado.set_mode then tornado.set_mode("looping") end
		session.last_message = "RUNNING: wind visibility"
		return
	end
	if transport.floor_matches_preset(PRESET) and thread_wind.can_spawn() then
		after_floor()
		return
	end
	local ok, err = transport.goto_level_preset(PRESET, {
		reseed = true,
		reuse_current_floor = true,
	})
	if not ok then
		fail(err or "floor_command_failed")
		return
	end
	if transport.floor_matches_preset(PRESET) and thread_wind.can_spawn() then
		after_floor()
	end
end

function M.start_storm()
	local decision = policy.click_action(job, "storm")
	if decision == "busy" then
		session.last_message = "已有测试进行中: " .. tostring(job and job.id)
		return
	end
	if decision == "ignore_same" then
		return
	end
	if thread_wind.explore_is_active() then
		session.last_message = "风暴已启动"
		return
	end
	begin("storm")
end

function M.start_eye()
	begin("eye_goto")
end

function M.start_battle()
	begin("battle")
end

function M.start_full()
	begin("full")
end

function M.start_wind()
	begin("wind")
end

function M.start_selected_phase()
	local row = M.phases[M.selected] or M.phases[1]
	begin("phase", row.id)
end

function M.select_phase(index)
	local n = (tonumber(index) or 0) + 1
	if n < 1 then n = 1 end
	if n > #M.phases then n = #M.phases end
	M.selected = n
end

function M.cancel()
	if job then
		apply_cleanup(job)
	end
	job = nil
	encounter.set_test_request(nil)
end

function M.on_room()
	if policy.room_event_matches(job, current_sgid()) then
		start_phase_in_room()
	end
end

function M.tick()
	if not job then return end
	if job.status == "FAILED" or job.status == "COMPLETED" or job.step == "done" then return end
	local waited = frame() - (job.since or frame())
	if job.step == "floor" then
		if transport.floor_matches_preset(PRESET) and thread_wind.can_spawn() then
			after_floor()
		elseif waited >= FLOOR_TIMEOUT then
			fail("floor_timeout")
		end
		return
	end
	if job.step == "room" then
		start_phase_in_room()
		if job and job.step == "room" and waited >= ROOM_TIMEOUT then
			fail("room_timeout")
		end
		return
	end
	if job.step == "battle" then
		if select(1, encounter.direct_battle_ready()) then
			job.status = "COMPLETED"
			job.step = "done"
			job.error = nil
			session.last_message = "COMPLETED: arena battle"
			return
		end
		if select(1, arena_room.validate_current()) then
			job.status = "RUNNING"
			local ok, err = encounter.open_battle_now()
			if ok and select(1, encounter.direct_battle_ready()) then
				job.status = "COMPLETED"
				job.step = "done"
				job.error = nil
				session.last_message = "COMPLETED: arena battle"
				return
			end
			job.error = err
		else
			job.status = "QUEUED"
		end
		if waited >= ROOM_TIMEOUT then
			fail(job.error or "battle_timeout")
		end
		return
	end
	if job.step == "cinematic" then
		local phase = encounter.get_phase()
		local in_arena = select(1, arena_room.validate_current())
		if job.room_action == "transfer" or job.id == "full" then
			local diag = encounter.get_diagnostics and encounter.get_diagnostics() or {}
			local revealed = in_arena
				and select(1, encounter.direct_battle_ready())
				and diag.cover_state == "released"
				and diag.cover_draw_enabled ~= true
				and diag.arena_visual_ready == true
			if job.id == "full" then
				revealed = revealed and diag.phase == encounter.PHASE.BATTLE
			elseif job.room_action == "transfer" then
				revealed = in_arena and phase == encounter.PHASE.BATTLE
					and diag.cover_state == "released"
					and diag.cover_draw_enabled ~= true
			end
			if revealed then
				job.status = "COMPLETED"
				job.step = "done"
				job.error = nil
				session.last_message = "COMPLETED: battle revealed"
				return
			end
			job.status = "RUNNING"
			if waited >= 900 then
				fail(table.concat({
					diag.last_error or diag.arena_visual_error or "cinematic_timeout",
					"arena_visual_error=" .. tostring(diag.arena_visual_error or "-"),
					"cover_state=" .. tostring(diag.cover_state),
					"cover_alpha=" .. tostring(diag.cover_alpha),
					"cover_draw_enabled=" .. tostring(diag.cover_draw_enabled),
					"fade_frame=" .. tostring(diag.fade_frame),
					"ready_for_reveal=" .. tostring(diag.ready_for_reveal),
					"boss_count=" .. tostring(diag.real_boss_count),
					"boss_intro_locked=" .. tostring(diag.boss_intro_locked),
					"phase=" .. tostring(diag.phase),
				}, " "))
			end
		elseif phase_is_ready(job.room_action) then
			job.status = "COMPLETED"
			job.step = "done"
			job.error = nil
			session.last_message = "COMPLETED: " .. tostring(job.room_action)
		elseif waited >= 180 then
			fail("phase_not_reached:" .. tostring(phase))
		else
			job.status = "RUNNING"
		end
		return
	end
	if job.step == "wind" then
		local stats = wind.get_visual_stats and wind.get_visual_stats() or {}
		local air = (stats.layers and stats.layers.airflow) or {}
		local visible = (air.inbound_visible or 0) + (air.column_visible or 0)
		if visible > 0 then
			job.visible_run = (job.visible_run or 0) + 1
		else
			job.visible_run = 0
		end
		if (job.visible_run or 0) >= 45 then
			job.status = "COMPLETED"
			job.step = "done"
			job.error = nil
			session.last_message = "COMPLETED: visible wind " .. tostring(visible)
			return
		end
		if (stats.blank_frames or 0) >= 45 or waited >= 180 then
			fail(stats.blank_reason or "no_visible_wind")
		else
			job.status = "RUNNING"
		end
	end
end

function M.status()
	if not job then
		return {status = "IDLE", error = nil, step = nil, id = nil}
	end
	return {
		status = job.status,
		error = job.error,
		step = job.step,
		id = job.id,
		phase_id = job.phase_id,
		request_id = job.request_id,
	}
end

function M.report_text()
	local diag = encounter.get_diagnostics and encounter.get_diagnostics() or {}
	local st = M.status()
	local wind_state = wind.get_state and wind.get_state() or {}
	local stats = wind.get_visual_stats and wind.get_visual_stats() or {}
	local air = (stats.layers and stats.layers.airflow) or {}
	local ready = select(1, encounter.direct_battle_ready())
	local head = thread_wind.heading_debug and thread_wind.heading_debug() or {}
	local prefill = head.prefill or {}
	local live_note = "-"
	if st.status == "COMPLETED" or st.status == "ARRIVED" then
		live_note = "job_status_is_not_live_encounter"
	end
	local perm = thread_wind.explain_wind_runtime_allowed and select(1, thread_wind.explain_wind_runtime_allowed())
	local perm_row = thread_wind.last_wind_permission or {}
	local storm_live = wind_state.has_session and "ACTIVE" or "STOPPED"
	local lines = {
		"status=" .. tostring(st.status),
		"storm_start=" .. tostring(st.id == "storm" and st.status or "-"),
		"storm_live=" .. storm_live,
		"runtime_owner=" .. tostring(perm_row.source or "-"),
		"chapter_gate=" .. tostring(perm_row.chapter_ok and "OPEN" or "BLOCKED"),
		"chapter_gate_reason=" .. tostring(perm_row.chapter_reason or "-"),
		"gate_override=" .. tostring(perm_row.source == "wind_story_test" and "wind_test_only" or "-"),
		"test_session_active=" .. tostring(perm_row.test_session_active),
		"wind_test_owned=" .. tostring(perm_row.wind_test_owned),
		"runtime_permission_allowed=" .. tostring(perm == true),
		"runtime_has_session=" .. tostring(wind_state.has_session),
		"session_kind=" .. tostring(wind_state.kind),
		"last_wind_stop_reason=" .. tostring(wind_state.last_stop_reason or "-"),
		"step=" .. tostring(st.step),
		"job=" .. tostring(st.id),
		"live_note=" .. live_note,
		"error=" .. tostring(st.error or diag.last_error or "-"),
		"floor_ok=" .. tostring(thread_wind.can_spawn()),
		"room_sgid=" .. tostring(head.room_sgid or current_sgid()),
		"selected_eye_sgid=" .. tostring(head.eye_sgid or "-"),
		"eye_jump_target=" .. tostring((thread_wind.last_eye_jump or {}).target or "-"),
		"eye_jump_descriptor=" .. tostring((thread_wind.last_eye_jump or {}).descriptor),
		"encounter_eye=" .. tostring(diag.eye_sgid or "-"),
		"request=" .. tostring(st.request_id or "-"),
		"explore=" .. tostring(thread_wind.explore_is_active and thread_wind.explore_is_active()),
		"bfs_distance=" .. tostring(head.bfs_distance),
		"bfs_dir=" .. tostring(head.bfs_dir),
		"eye_center=" .. tostring(head.eye_center or "-"),
		"room_center=" .. tostring(head.room_center or "-"),
		"geo_heading=" .. tostring(head.geo_heading or "-"),
		"bfs_heading=" .. tostring(head.bfs_heading or "-"),
		"mixed_heading=" .. tostring(head.mixed_heading or "-"),
		"runtime_ang=" .. tostring(head.runtime_ang),
		"visual_blow=" .. tostring(head.visual_blow or "-"),
		"debug_override=" .. tostring(head.debug_active),
		"phase=" .. tostring(diag.phase),
		"story_owned=" .. tostring(diag.story_owned),
		"reward_done=" .. tostring(diag.reward_done),
		"arena_valid=" .. tostring(diag.room_identity_valid),
		"arena_sgid=" .. tostring(diag.arena_sgid or "-"),
		"arena_visual_error=" .. tostring(diag.arena_visual_error or "-"),
		"bosses=" .. tostring(diag.real_boss_count),
		"boss_locked=" .. tostring(diag.boss_intro_locked),
		"visual_ready=" .. tostring(diag.arena_visual_ready),
		"black_draws=" .. tostring(diag.arena_black_draws or 0),
		"render_back=" .. tostring(diag.arena_render_back or "-"),
		"render_front=" .. tostring(diag.arena_render_front or "-"),
		"arena_sprites=" .. tostring(diag.arena_sprites or 0),
		"arena_bolt=" .. tostring(diag.arena_bolt or "-"),
		"arena_thunder_id=" .. tostring(diag.arena_thunder_id or -1),
		"arena_thunder_played=" .. tostring(diag.arena_thunder_played),
		"arena_thunder_volume=" .. tostring(diag.arena_thunder_volume or 0),
		"arena_thunder_replaced=" .. tostring(diag.arena_thunder_replaced),
		"arena_thunder_skipped=" .. tostring(diag.arena_thunder_skipped or "-"),
		"render_carrier=" .. tostring(diag.arena_render_carrier),
		"ready_for_reveal=" .. tostring(diag.ready_for_reveal),
		"cover_state=" .. tostring(diag.cover_state),
		"cover_alpha=" .. tostring(diag.cover_alpha),
		"cover_draw_enabled=" .. tostring(diag.cover_draw_enabled),
		"fade_frame=" .. tostring(diag.fade_frame),
		"battle_ready=" .. tostring(ready),
		"wind_phase=" .. tostring(wind_state.phase),
		"intensity=" .. tostring(wind_state.intensity),
		"wind_session_generation=" .. tostring(head.session_generation or wind_state.session_generation),
		"particles=" .. tostring(stats.total),
		"inbound_visible=" .. tostring(air.inbound_visible or 0),
		"prefill_drawable=" .. tostring(prefill.airflow) .. "/" .. tostring(prefill.airflow_goal),
		"prefill_gust=" .. tostring(prefill.gust) .. "/" .. tostring(prefill.gust_goal),
		"prefill_total=" .. tostring(prefill.total),
		"column_visual=" .. tostring(air.column_visual or 0),
		"column_segments=" .. tostring(air.column_renderable or 0),
		"blank=" .. tostring(stats.blank_reason or "-") .. " frames=" .. tostring(stats.blank_frames or 0),
		"force_white=" .. tostring(stats.force_white),
		"last_reset=" .. tostring(head.last_reset or stats.last_reset_reason or "-"),
		"room_trace=" .. tostring(head.room_trace or "-"),
	}
	return table.concat(lines, "\n")
end

return M
