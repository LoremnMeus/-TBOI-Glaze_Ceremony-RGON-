-- Stone map-layer debug helpers (Story Test + console).

local defs = require("Qing_Remaster_scripts.threads.stone.stone_defs")
local runtime = require("Qing_Remaster_scripts.threads.stone.stone_runtime")
local layout = require("Qing_Remaster_scripts.threads.stone.stone_layout")
local route = require("Qing_Remaster_scripts.threads.stone.stone_route")
local rooms = require("Qing_Remaster_scripts.threads.stone.stone_rooms")
local imgui_layout = require("Qing_Remaster_scripts.debug.imgui_debug_layout")
local grid_door = require("Qing_Remaster_scripts.grids.grid_doors")
local gate = require("Qing_Remaster_scripts.story.story_runtime_gate")

local debug = {}

local function tr(zh, en)
	local language = Options and Options.Language
	return (language == "en") and en or zh
end

local function change_room(index)
	if index == nil then return false, "nil" end
	if REPENTOGON then
		Game():ChangeRoom(index)
	else
		Game():GetLevel():ChangeRoom(index)
	end
	return true
end

function debug.ensure_layout(opts)
	return layout.ensure_for_current_floor(opts or { force = true, ignore_gate = true })
end

local function maybe_ensure_layout(opts)
	opts = opts or {}
	if opts.skip_layout then
		if runtime.has_layout() and runtime.floor_matches() then
			return true, "exists"
		end
		return false, "layout_missing"
	end
	return debug.ensure_layout({ force = true, ignore_gate = true })
end

function debug.goto_trigger(opts)
	opts = opts or {}
	local ok_l, err_l = maybe_ensure_layout(opts)
	if not ok_l then return false, err_l or "layout_failed" end
	local r = runtime.get()
	if not r.trigger then return false, "no trigger" end
	return change_room(r.trigger.safe_grid_index)
end

function debug.goto_origin(opts)
	return debug.goto_trigger(opts)
end

function debug.activate(opts)
	opts = opts or {}
	local ok_l, err_l = maybe_ensure_layout(opts)
	if not ok_l then return false, err_l or "layout_failed" end
	rooms.clear_origin_placeholder()
	local ok = runtime.activate_board("debug")
	local board = require("Qing_Remaster_scripts.threads.stone.stone_board")
	local origin_pos = rooms.resolve_origin_anchor()
	board.begin_expand(origin_pos, Game():GetFrameCount())
	local encounter = require("Qing_Remaster_scripts.threads.stone.stone_encounter")
	encounter.on_board_activated()
	return ok
end

-- ── Staged floor prepare (cross-floor Story Test; sole owner) ───────────────
local PREPARE = {
	IDLE = "IDLE",
	REQUEST_STAGE = "REQUEST_STAGE",
	WAIT_LEVEL_READY = "WAIT_LEVEL_READY",
	PREPARE_LAYOUT = "PREPARE_LAYOUT",
	WAIT_ROOM_READY = "WAIT_ROOM_READY",
	VERIFY = "VERIFY",
	READY = "READY",
	FAILED = "FAILED",
}

local STATUS = {
	IDLE = "idle",
	QUEUED = "queued",
	PREPARING = "preparing",
	READY = "ready",
	FAILED = "failed",
}

local prepare_job = nil
local prepare_gen = 0
--- Survives after READY/FAILED so Dev Lab status still shows the last attempt.
local last_prepare_diag = nil
-- Chess-piece pick state for board piece tools (not a "sandbox" product).
local piece_pick = {
	selected_ptr = nil,
	selected_debug_id = nil,
	next_debug_id = 1,
	debug_ids = {}, -- PtrHash -> temp id
}
-- LEGACY alias while console helpers settle.
local sandbox = piece_pick

local function result_ok(code, message)
	return {ok = true, code = code or "ok", message = message or code}
end

local function result_err(code, message)
	return {ok = false, code = code or "error", message = message or code}
end

local function current_sgi()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	return desc and desc.SafeGridIndex or nil
end

local function classify_status(phase)
	if phase == nil or phase == PREPARE.IDLE then
		return STATUS.IDLE
	end
	if phase == PREPARE.READY then
		return STATUS.READY
	end
	if phase == PREPARE.FAILED then
		return STATUS.FAILED
	end
	if phase == PREPARE.REQUEST_STAGE then
		return STATUS.QUEUED
	end
	return STATUS.PREPARING
end

local function snapshot_prepare_diag(job)
	if not job then return nil end
	local status = classify_status(job.phase)
	return {
		phase = job.phase,
		status = status,
		ok = job.phase ~= PREPARE.FAILED,
		arrived = job.phase == PREPARE.READY,
		queued = status == STATUS.QUEUED or status == STATUS.PREPARING,
		gen = job.gen,
		message = job.message,
		error = job.error,
		preset = job.preset_id,
		target = job.target,
		suppress_boss = job.suppress_boss == true,
		stage_ready = job.stage_ready,
		layout_result = job.layout_result,
		trigger_sgi = job.trigger_sgi,
		terminal_sgi = job.terminal_sgi,
		warp_issued = job.warp_issued,
		warp_target = job.warp_target,
		warp_error = job.warp_error,
		current_sgi = job.current_sgi or current_sgi(),
		last_error = job.error,
		paused_hint = job.paused_hint,
	}
end

function debug.prepare_status()
	local job = prepare_job or last_prepare_diag
	if not job then
		return {
			phase = PREPARE.IDLE,
			status = STATUS.IDLE,
			ok = true,
			arrived = false,
			queued = false,
			message = "idle",
		}
	end
	if prepare_job then
		return snapshot_prepare_diag(prepare_job)
	end
	return job
end

function debug.has_prepare_job()
	return prepare_job ~= nil
end

function debug.cancel_prepare(reason)
	if not prepare_job then
		return result_ok("idle", "no prepare job")
	end
	local job = prepare_job
	job.phase = PREPARE.FAILED
	job.error = "cancelled"
	job.message = tostring(reason or "cancelled")
	job.current_sgi = current_sgi()
	last_prepare_diag = snapshot_prepare_diag(job)
	prepare_job = nil
	prepare_gen = prepare_gen + 1
	return result_ok("cancelled", job.message)
end

function debug.start_prepare(opts)
	opts = opts or {}
	local transport = require("Qing_Remaster_scripts.story_test.story_test_transport")
	local preset_id = opts.preset_id or "mines_ashpit"
	local reuse_floor = opts.reuse_floor
	if reuse_floor == nil then reuse_floor = true end
	local on_floor = transport.floor_matches_preset(preset_id)

	-- Supersede any in-flight job so rapid checkpoint clicks cannot deadlock.
	if prepare_job then
		local old = prepare_job
		old.phase = PREPARE.FAILED
		old.error = "superseded"
		old.message = "superseded by new prepare gen"
		old.current_sgi = current_sgi()
		last_prepare_diag = snapshot_prepare_diag(old)
		prepare_job = nil
	end
	prepare_gen = prepare_gen + 1

	local phase = PREPARE.REQUEST_STAGE
	local message = "queued: request floor"
	local status = STATUS.QUEUED
	-- skip_stage: caller already issued stage (or floor already correct).
	if opts.skip_stage == true then
		phase = PREPARE.WAIT_LEVEL_READY
		message = on_floor and "queued: reuse floor" or "queued: wait level after stage"
		status = STATUS.QUEUED
	elseif reuse_floor and on_floor then
		phase = PREPARE.WAIT_LEVEL_READY
		message = "queued: reuse floor"
		status = STATUS.QUEUED
	end

	prepare_job = {
		gen = prepare_gen,
		phase = phase,
		status = status,
		preset_id = preset_id,
		target = opts.target or "origin",
		suppress_boss = opts.suppress_boss == true,
		wait_frames = 0,
		message = message,
		error = nil,
		reuse_floor = reuse_floor,
		reuse_layout = opts.reuse_layout ~= false,
		reset_encounter = opts.reset_encounter ~= false,
		skip_stage = opts.skip_stage == true,
		stage_ready = false,
		layout_result = nil,
		trigger_sgi = nil,
		terminal_sgi = nil,
		warp_issued = false,
		warp_target = nil,
		warp_error = nil,
		current_sgi = current_sgi(),
		paused_hint = nil,
	}
	last_prepare_diag = snapshot_prepare_diag(prepare_job)
	return {
		ok = true,
		code = "queued",
		status = STATUS.QUEUED,
		arrived = false,
		message = "Stone prepare QUEUED: " .. tostring(preset_id)
			.. " → " .. tostring(prepare_job.target) .. " (" .. message .. ")",
		gen = prepare_gen,
	}
end

--- Unified checkpoint entry for Dev Lab / Story Test. Never reports arrived until VERIFY.
function debug.goto_checkpoint(target, opts)
	opts = opts or {}
	local t = tostring(target or "origin")
	local allowed = {
		origin = true, trigger = true, mid = true, ["end"] = true,
		terminal = true, ante = true, boss = true,
	}
	if not allowed[t] then
		return { ok = false, code = "invalid_target", status = STATUS.FAILED,
			arrived = false, message = "invalid checkpoint: " .. t }
	end
	return debug.start_prepare({
		preset_id = opts.preset_id or "mines_ashpit",
		target = t == "trigger" and "origin" or t,
		reuse_floor = opts.reuse_floor ~= false,
		reuse_layout = opts.reuse_layout ~= false,
		reset_encounter = opts.reset_encounter == true,
		skip_stage = opts.skip_stage == true,
		suppress_boss = opts.suppress_boss == true,
	})
end

function debug.start_full_test(opts)
	opts = opts or {}
	-- Do NOT wipe layout when reusing; only clear encounter bags if requested.
	if opts.reuse_layout == false then
		runtime.reset()
	elseif opts.reset_encounter ~= false then
		local r = runtime.get()
		r.encounters = {}
		if r.board and opts.keep_board ~= true then
			-- Origin test: board should be inactive so giant pawn appears.
			r.board.activated = false
		end
	end
	return debug.start_prepare({
		preset_id = opts.preset_id or "mines_ashpit",
		target = opts.target or "origin",
		reuse_floor = opts.reuse_floor ~= false,
		reuse_layout = opts.reuse_layout ~= false,
		reset_encounter = opts.reset_encounter ~= false,
	})
end

local function stage_matches_preset(preset_id)
	local transport = require("Qing_Remaster_scripts.story_test.story_test_transport")
	return transport.floor_matches_preset(preset_id)
end

local function fail_prepare(job, code, message)
	if not job or (job.gen and job.gen ~= prepare_gen) then
		return
	end
	job.phase = PREPARE.FAILED
	job.error = tostring(code or "error")
	job.message = tostring(message or code)
	job.current_sgi = current_sgi()
	last_prepare_diag = snapshot_prepare_diag(job)
	if prepare_job and prepare_job.gen == job.gen then
		prepare_job = nil
	end
end

local function finish_prepare_ready(job, message)
	if not job or (job.gen and job.gen ~= prepare_gen) then
		return
	end
	job.phase = PREPARE.READY
	job.message = message
	job.error = nil
	job.current_sgi = current_sgi()
	last_prepare_diag = snapshot_prepare_diag(job)
	if prepare_job and prepare_job.gen == job.gen then
		prepare_job = nil
	end
	if debug._pending_activate_after_ready then
		debug._pending_activate_after_ready = nil
		debug.activate({ skip_layout = true })
		if last_prepare_diag then
			last_prepare_diag.message = tostring(last_prepare_diag.message or "") .. " + board activated"
		end
	end
end

local function target_room_arrived(target)
	if target == "origin" or target == "trigger" then
		return route.is_trigger_room() == true
	end
	if target == "terminal" then
		return route.is_terminal_room and route.is_terminal_room() == true
	end
	if target == "ante" then
		return rooms.is_antechamber() == true
	end
	if target == "boss" then
		return rooms.is_floraine_room() == true
	end
	if target == "mid" or target == "end" then
		return route.is_route_room and route.is_route_room() == true
	end
	return true
end

--- Advance prepare FSM. Safe under pause via POST_RENDER (opts.from_render).
function debug.tick_prepare(opts)
	opts = opts or {}
	if not prepare_job then return end
	local job = prepare_job
	if job.gen and job.gen ~= prepare_gen then
		return
	end

	local game = Game()
	local paused = game and game.IsPaused and game:IsPaused() == true
	if opts.from_render == true and not paused then
		-- Live gameplay: MC_POST_UPDATE owns the clock (avoid double-step).
		return
	end
	if paused then
		job.paused_hint = "game_paused_unpause_to_finish_stage"
	else
		job.paused_hint = nil
	end

	local transport = require("Qing_Remaster_scripts.story_test.story_test_transport")
	job.current_sgi = current_sgi()
	last_prepare_diag = snapshot_prepare_diag(job)

	if job.phase == PREPARE.REQUEST_STAGE then
		local ok, msg, plog = transport.goto_level_preset(job.preset_id, {
			reuse_current_floor = job.reuse_floor ~= false,
			reseed = true,
		})
		if not ok then
			fail_prepare(job, msg, "stage failed: " .. tostring(msg))
			return
		end
		if plog and plog.reused then
			job.stage_ready = true
			job.phase = PREPARE.PREPARE_LAYOUT
			job.message = "preparing: reused floor → layout"
			return
		end
		job.phase = PREPARE.WAIT_LEVEL_READY
		job.wait_frames = 0
		job.message = "preparing: waiting for level"
			.. (paused and " (unpause required)" or "")
		return
	end

	if job.phase == PREPARE.WAIT_LEVEL_READY then
		job.wait_frames = (job.wait_frames or 0) + 1
		local min_wait = paused and 2 or 8
		if job.wait_frames < min_wait then return end
		if not stage_matches_preset(job.preset_id) then
			if job.wait_frames > 180 then
				fail_prepare(job, "stage_mismatch",
					"floor did not match preset " .. tostring(job.preset_id)
						.. (paused and " — unpause and retry" or ""))
			else
				job.message = "preparing: waiting floor match f=" .. tostring(job.wait_frames)
			end
			return
		end
		local rooms_list = Game():GetLevel():GetRooms()
		if not rooms_list or rooms_list.Size < 1 then
			if job.wait_frames > 180 then
				fail_prepare(job, "no_rooms", "level rooms not ready")
			end
			return
		end
		job.stage_ready = true
		job.phase = PREPARE.PREPARE_LAYOUT
		job.message = "preparing: planning layout"
		return
	end

	if job.phase == PREPARE.PREPARE_LAYOUT then
		local ok, err
		if job.reuse_layout and runtime.has_layout() and runtime.floor_matches() then
			ok, err = true, "reused_layout"
		else
			ok, err = debug.ensure_layout({ force = true, ignore_gate = true })
		end
		local r = runtime.get()
		job.layout_result = ok and tostring(err or "ok") or tostring(err or "layout_failed")
		job.trigger_sgi = r.trigger and r.trigger.safe_grid_index or nil
		job.terminal_sgi = r.terminal and r.terminal.safe_grid_index or nil
		if not ok or not r.trigger then
			local fail_code = tostring(err or "layout_failed")
			local layout_fail = r.layout_fail
			if layout_fail then
				fail_code = tostring(layout_fail)
			end
			fail_prepare(job, fail_code, "layout failed: " .. fail_code)
			return
		end
		if job.reset_encounter then
			r.encounters = {}
		end
		local target = job.target or "origin"
		if target == "origin" or target == "trigger" then
			if r.board then r.board.activated = false end
		end
		job.phase = PREPARE.WAIT_ROOM_READY
		job.wait_frames = 0
		job.message = "preparing: warping to " .. tostring(target)
		job.warp_target = target
		local warp_opts = { skip_layout = true }
		local warp_ok, warp_err
		if target == "mid" then
			warp_ok, warp_err = debug.goto_route_middle(warp_opts)
		elseif target == "end" then
			warp_ok, warp_err = debug.goto_route_end(warp_opts)
		elseif target == "terminal" then
			warp_ok, warp_err = debug.goto_terminal({
				unlock = true, activate = true, skip_layout = true,
			})
		elseif target == "ante" then
			warp_ok, warp_err = debug.goto_antechamber(warp_opts)
		elseif target == "boss" then
			warp_ok, warp_err = debug.goto_floraine({
				suppress_boss = job.suppress_boss == true,
				skip_layout = true,
			})
		else
			warp_ok, warp_err = debug.goto_trigger(warp_opts)
		end
		job.warp_issued = warp_ok == true
		job.warp_error = warp_ok and nil or tostring(warp_err)
		job.current_sgi = current_sgi()
		if not warp_ok then
			fail_prepare(job, warp_err, "warp failed: " .. tostring(warp_err))
		end
		return
	end

	if job.phase == PREPARE.WAIT_ROOM_READY then
		job.wait_frames = (job.wait_frames or 0) + 1
		local target = job.target or "origin"
		-- goto-command targets are async; wait until room type matches.
		local async_target = (target == "ante" or target == "boss")
		if async_target then
			if target_room_arrived(target) then
				job.phase = PREPARE.VERIFY
				job.message = "preparing: verifying arrival"
				return
			end
			if job.wait_frames > 180 then
				fail_prepare(job, "room_timeout",
					"did not arrive at " .. tostring(target)
						.. " SGI=" .. tostring(job.current_sgi))
			else
				job.message = "preparing: wait room " .. tostring(target)
					.. " f=" .. tostring(job.wait_frames)
			end
			return
		end
		if job.wait_frames < 4 then return end
		job.phase = PREPARE.VERIFY
		job.message = "preparing: verifying arrival"
		return
	end

	if job.phase == PREPARE.VERIFY then
		local r = runtime.get()
		job.current_sgi = current_sgi()
		job.trigger_sgi = r.trigger and r.trigger.safe_grid_index or job.trigger_sgi
		job.terminal_sgi = r.terminal and r.terminal.safe_grid_index or job.terminal_sgi
		if not r.trigger or not r.terminal then
			fail_prepare(job, "layout_incomplete", "trigger/terminal missing after warp")
			return
		end
		local path = route.get_path()
		if #path < 1 then
			fail_prepare(job, "empty_route", "route empty")
			return
		end
		local target = job.target or "origin"
		if not target_room_arrived(target) then
			fail_prepare(job, "wrong_room",
				string.format(
					"expected %s, loc=%s SGI=%s",
					tostring(target),
					tostring(rooms.current_location and rooms.current_location() or "?"),
					tostring(job.current_sgi)
				))
			return
		end
		if target == "origin" or target == "trigger" then
			local origin = require("Qing_Remaster_scripts.threads.stone.stone_origin")
			local ok_p, why = origin.ensure({ allow_fallback = false })
			if not ok_p and why ~= "exists" then
				fail_prepare(job, why, "giant pawn failed: " .. tostring(why))
				return
			end
			local anchor = rooms.resolve_origin_anchor()
			finish_prepare_ready(job, string.format(
				"READY %s / route %d / trigger %s / anchor (%.0f,%.0f)",
				tostring(job.preset_id),
				#path,
				tostring(r.trigger.safe_grid_index),
				anchor.X, anchor.Y
			))
		else
			finish_prepare_ready(job, string.format(
				"READY %s / target %s / loc=%s / SGI %s",
				tostring(job.preset_id),
				tostring(target),
				tostring(rooms.current_location and rooms.current_location() or "?"),
				tostring(job.current_sgi)
			))
		end
		return
	end
end

function debug.spawn_piece(kind)
	local encounter = require("Qing_Remaster_scripts.threads.stone.stone_encounter")
	return encounter.debug_force_wave(kind)
end

function debug.spawn_all_kinds()
	local piece_defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")
	local controller = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_controller")
	local room = Game():GetRoom()
	local center = room:GetCenterPos()
	local kinds = {
		piece_defs.KIND.PAWN,
		piece_defs.KIND.VEHICLE,
		piece_defs.KIND.KNIGHT,
		piece_defs.KIND.BISHOP,
		piece_defs.KIND.QUEEN,
		piece_defs.KIND.KING,
	}
	for i, kind in ipairs(kinds) do
		local ang = (i / #kinds) * math.pi * 2
		local pos = room:GetClampedPosition(center + Vector(math.cos(ang), math.sin(ang)) * 70, 24)
		controller.spawn({
			kind = kind,
			role = piece_defs.ROLE.ROUTE_ENEMY,
			mode = piece_defs.MODE.AUTONOMOUS,
			position = pos,
		})
	end
	return true
end

function debug.goto_route_index(index, opts)
	opts = opts or {}
	local ok_l, err_l = maybe_ensure_layout(opts)
	if not ok_l then return false, err_l or "layout_failed" end
	local path = route.get_path()
	if #path < 1 then return false, "no route" end
	index = math.max(1, math.min(#path, index or 1))
	return change_room(path[index])
end

function debug.goto_route_start(opts)
	return debug.goto_route_index(1, opts)
end

function debug.goto_route_middle(opts)
	local path = route.get_path()
	return debug.goto_route_index(math.max(1, math.ceil(#path / 2)), opts)
end

function debug.goto_route_end(opts)
	local path = route.get_path()
	return debug.goto_route_index(#path, opts)
end

function debug.goto_terminal(opts)
	opts = opts or {}
	local ok_l, err_l = maybe_ensure_layout(opts)
	if not ok_l then return false, err_l or "layout_failed" end
	local r = runtime.get()
	if not r.terminal then return false, "no terminal" end
	if opts.activate then
		runtime.activate_board("debug")
	end
	if opts.force_reveal then
		r.gate.unlocked = true
		r.gate.reveal_pending = true
	elseif opts.unlock then
		r.gate.unlocked = true
		r.gate.reveal_pending = false
	end
	local ok = change_room(r.terminal.safe_grid_index)
	return ok
end

function debug.goto_antechamber(opts)
	opts = opts or {}
	local ok_l, err_l = maybe_ensure_layout(opts)
	if not ok_l then return false, err_l or "layout_failed" end
	local r = runtime.get()
	if not r.board.activated then
		runtime.activate_board("debug")
	end
	r = runtime.get()
	if not r.hidden then return false, "no hidden" end
	local door_arrival = require("Qing_Remaster_scripts.threads.stone.stone_door_arrival")
	-- Explicit debug arrival — does not pretend to be a terminal door walk.
	door_arrival.begin("DEBUG_ANTE", {
		source = "debug",
		expect_variant = r.hidden.ante_variant,
		debug = true,
	})
	Isaac.ExecuteCommand("goto " .. defs.goto_default(r.hidden.ante_variant))
	return true
end

function debug.goto_floraine(opts)
	opts = opts or {}
	local ok_l, err_l = maybe_ensure_layout(opts)
	if not ok_l then return false, err_l or "layout_failed" end
	local r = runtime.get()
	if not r.board.activated then
		runtime.activate_board("debug")
	end
	r = runtime.get()
	if not r.hidden then return false, "no hidden" end
	-- V2: default allows Boss (suppress only when explicitly requested).
	if opts.suppress_boss == true then
		r.suppress_floraine = true
	else
		r.suppress_floraine = false
	end
	local floraine = runtime.normalize_floraine_variant()
	local door_arrival = require("Qing_Remaster_scripts.threads.stone.stone_door_arrival")
	door_arrival.begin("DEBUG_FLORAINE", {
		source = "debug",
		expect_variant = floraine,
		debug = true,
	})
	Isaac.ExecuteCommand("goto " .. defs.goto_default(floraine))
	return true
end

function debug.preview_door(slot, anim)
	slot = slot or DoorSlot.UP0
	anim = anim or "Opened"
	local room = Game():GetRoom()
	grid_door.try_spawn_grid_door(room, slot, nil, {
		check_and_leave = function() end,
		loadname = defs.DOOR_ANM2,
		playname = anim,
		should_update = anim ~= "Opened" and anim ~= "Closed",
		on_update = function(doorinfo)
			local door = doorinfo.door
			if not door then return end
			local s = door:GetSprite()
			if s:IsFinished(anim) and (anim == "Reveal" or anim == "Open") then
				s:Play("Opened", true)
			end
		end,
	})
	return true
end

function debug.return_to_terminal()
	debug.ensure_layout({ force = true, ignore_gate = true })
	local r = runtime.get()
	if not r.board.activated then
		runtime.activate_board("debug")
	end
	r.gate.unlocked = true
	r.gate.ante_boss_opened = true
	return debug.goto_terminal({ unlock = true })
end

function debug.complete_flow(opts)
	opts = opts or {}
	local thread = require("Qing_Remaster_scripts.threads.thread_Stone")
	if not thread.complete_thread then
		return false, "no complete_thread"
	end
	return thread.complete_thread(opts.reason or "debug_complete", {
		force = true,
		story_test = opts.story_test ~= false,
		story_owned = opts.story_owned ~= false,
	})
end

local function selected_piece()
	if not sandbox.selected_ptr then return nil end
	local enums = require("Qing_Remaster_scripts.core.enums")
	for _, ent in ipairs(Isaac.FindByType(996, enums.Enemies.chess_piece, -1, false, false)) do
		if GetPtrHash(ent) == sandbox.selected_ptr then
			return ent
		end
	end
	sandbox.selected_ptr = nil
	return nil
end

local function ensure_debug_id(ent)
	local h = GetPtrHash(ent)
	if not sandbox.debug_ids[h] then
		sandbox.debug_ids[h] = sandbox.next_debug_id
		sandbox.next_debug_id = sandbox.next_debug_id + 1
	end
	return sandbox.debug_ids[h]
end

function debug.select_piece_by_debug_id(id)
	id = tonumber(id)
	if not id then return result_err("bad_id", "piece select needs numeric id") end
	local enums = require("Qing_Remaster_scripts.core.enums")
	for _, ent in ipairs(Isaac.FindByType(996, enums.Enemies.chess_piece, -1, false, false)) do
		if ensure_debug_id(ent) == id then
			sandbox.selected_ptr = GetPtrHash(ent)
			sandbox.selected_debug_id = id
			return result_ok("selected", "selected piece #" .. tostring(id))
		end
	end
	return result_err("not_found", "no piece with id " .. tostring(id))
end

function debug.select_nearest_piece()
	local player = Game():GetPlayer(0)
	if not player then return result_err("no_player", "no player") end
	local enums = require("Qing_Remaster_scripts.core.enums")
	local best, best_d = nil, 1e12
	for _, ent in ipairs(Isaac.FindByType(996, enums.Enemies.chess_piece, -1, false, false)) do
		local d2 = (ent.Position - player.Position):LengthSquared()
		if d2 < best_d then best_d = d2 best = ent end
	end
	if not best then return result_err("none", "no chess pieces in room") end
	sandbox.selected_ptr = GetPtrHash(best)
	sandbox.selected_debug_id = ensure_debug_id(best)
	return result_ok("selected", "selected nearest #" .. tostring(sandbox.selected_debug_id))
end

function debug.inspect_text()
	local snap = runtime.debug_snapshot()
	local prep = debug.prepare_status()
	local prep_state = "IDLE"
	if prep.phase == PREPARE.FAILED then
		prep_state = "FAILED"
	elseif prep.phase == PREPARE.READY then
		prep_state = "READY"
	elseif prep.queued then
		prep_state = "WAIT"
	elseif prep.phase and prep.phase ~= PREPARE.IDLE then
		prep_state = tostring(prep.phase)
	end
	local lines = {
		tr("棋盘地图层", "Stone Map Layer"),
		"────────────────",
		"Phase: " .. tostring(snap.phase),
		"Location: " .. tostring(rooms.current_location()),
		"Trigger SGI: " .. tostring(snap.trigger or "-"),
		"Terminal SGI: " .. tostring(snap.terminal or "-"),
		"Route: " .. table.concat(snap.route or {}, " → "),
		"Board: " .. tostring(snap.activated),
		"Gate: " .. tostring(snap.gate_unlocked),
		"Ante boss opened: " .. tostring(snap.ante_boss_opened),
		"Ante: " .. tostring(snap.ante or "-"),
		"Floraine: " .. tostring(snap.floraine or "-"),
		"Fail: " .. tostring(snap.fail or "-"),
		"Mines1 success: " .. tostring(snap.mines1_success),
		"Missed: " .. tostring(snap.missed),
		"Gate event: " .. tostring(gate.is_material_event_enabled("chapter1.stone")),
		"────────────────",
		tr("调试传送 / Prepare", "Debug transport / Prepare"),
		"Prepare State: " .. prep_state,
		"Requested Target: " .. tostring(prep.target or "-"),
		"Stage Ready: " .. tostring(prep.stage_ready),
		"Layout Result: " .. tostring(prep.layout_result or "-"),
		"Trigger SGI (job): " .. tostring(prep.trigger_sgi or "-"),
		"Terminal SGI (job): " .. tostring(prep.terminal_sgi or "-"),
		"Warp Issued: " .. tostring(prep.warp_issued),
		"Warp Target: " .. tostring(prep.warp_target or "-"),
		"Current SGI: " .. tostring(prep.current_sgi or current_sgi() or "-"),
		"Prepare: " .. tostring(prep.phase) .. " — " .. tostring(prep.message or ""),
		"Last Error: " .. tostring(prep.last_error or prep.error or prep.warp_error or "-"),
	}
	local cand = layout.origin_candidate_status()
	if cand and cand.lines then
		lines[#lines + 1] = "────────────────"
		for _, row in ipairs(cand.lines) do
			lines[#lines + 1] = row
		end
	end
	local sel = selected_piece()
	if sel then
		local controller = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_controller")
		local st = controller.get_status(sel)
		lines[#lines + 1] = string.format(
			"Selected #%s kind=%s mode=%s state=%s cmd=%s",
			tostring(sandbox.selected_debug_id),
			tostring(st and st.kind),
			tostring(st and st.control_mode),
			tostring(st and st.action_state),
			tostring(st and st.command)
		)
	end
	do
		local enc = require("Qing_Remaster_scripts.threads.stone.stone_encounter")
		local od = enc.get_offroute_diag and enc.get_offroute_diag() or {}
		local r = runtime.get()
		local off_n = 0
		if r.route and type(r.route.offroute_rooms) == "table" then
			for _ in pairs(r.route.offroute_rooms) do
				off_n = off_n + 1
			end
		end
		local info = route.get_room_info()
		lines[#lines + 1] = "────────────────"
		lines[#lines + 1] = tr("回归路线 / 追兵门", "Return route / pursuit door")
		lines[#lines + 1] = "Offroute table size: " .. tostring(off_n)
		lines[#lines + 1] = "Room SGI: " .. tostring(od.sgi or "-")
		lines[#lines + 1] = "On route: " .. tostring(info ~= nil)
			.. " in=" .. tostring(info and info.incoming_slot)
			.. " out=" .. tostring(info and info.outgoing_slot)
		lines[#lines + 1] = "entry_slot(diag): " .. tostring(od.entry_slot)
		lines[#lines + 1] = "return_slot: " .. tostring(od.return_slot)
		lines[#lines + 1] = "return_next: " .. tostring(od.return_next_sgi)
		lines[#lines + 1] = "dist_to_route: " .. tostring(od.distance_to_route)
		lines[#lines + 1] = "join_route: " .. tostring(od.join_route_sgi)
			.. " order=" .. tostring(od.join_route_order)
		lines[#lines + 1] = "pursuit_diag: " .. tostring(od.diag or "-")
	end
	return table.concat(lines, "\n")
end

function debug.get_test_descriptor()
	return {
		id = "chapter1.stone",
		title = {zh = "棋盘 / Floraine", en = "Chess / Floraine"},
		floor_preset = "mines_ashpit",
		use_stone_entry = true,
		start_step = "chapter1.stone.trigger",
		notes = tr(
			"流程验证走统一 goto_checkpoint（跨楼层自动准备）。Floraine 战斗请用 调试→Boss Test→Floraine。",
			"Flow uses goto_checkpoint (cross-floor prepare). Floraine combat: Debug→Boss Test→Floraine."
		),
		checkpoints = {
			{
				label = {zh = "开始完整测试", en = "Start full test"},
				action = function()
					return debug.start_full_test({
						preset_id = "mines_ashpit",
						reuse_floor = true,
						reuse_layout = true,
						reset_encounter = true,
						target = "origin",
					})
				end,
			},
			{
				label = {zh = "黑兵触发前", en = "Before pawn trigger"},
				action = function()
					return debug.goto_checkpoint("origin", { reset_encounter = true })
				end,
			},
			{
				label = {zh = "棋盘展开", en = "Board expand"},
				action = function()
					debug._pending_activate_after_ready = true
					return debug.goto_checkpoint("origin")
				end,
			},
			{
				label = {zh = "路线中段", en = "Route mid"},
				action = function()
					return debug.goto_checkpoint("mid")
				end,
			},
			{
				label = {zh = "终点", en = "Terminal"},
				action = function()
					return debug.goto_checkpoint("terminal")
				end,
			},
			{
				label = {zh = "前厅", en = "Antechamber"},
				action = function()
					return debug.goto_checkpoint("ante")
				end,
			},
			{
				label = {zh = "Boss 正常战斗", en = "Boss live fight"},
				action = function()
					return debug.goto_checkpoint("boss", { suppress_boss = false })
				end,
			},
			{
				label = {zh = "Boss 空房", en = "Boss empty room"},
				action = function()
					return debug.goto_checkpoint("boss", { suppress_boss = true })
				end,
			},
			{
				label = {zh = "前厅→终点", en = "Ante → terminal"},
				action = function()
					local ok, err = debug.return_to_terminal()
					return {
						ok = ok ~= false,
						arrived = ok ~= false,
						status = ok and "ready" or "failed",
						message = ok and "returned terminal" or tostring(err),
					}
				end,
			},
		},
		build_thread_tools = function(parent_id)
			debug.build_thread_tools(parent_id)
		end,
	}
end

local function format_prepare_status()
	local s = debug.prepare_status()
	local lines = {
		string.format("prepare=%s phase=%s target=%s",
			tostring(s.status), tostring(s.phase), tostring(s.target)),
		string.format("msg=%s", tostring(s.message or "-")),
	}
	if s.error then
		lines[#lines + 1] = "error=" .. tostring(s.error)
	end
	if s.paused_hint then
		lines[#lines + 1] = "hint=" .. tostring(s.paused_hint)
	end
	lines[#lines + 1] = string.format(
		"sgi=%s warp=%s layout=%s gen=%s",
		tostring(s.current_sgi), tostring(s.warp_issued),
		tostring(s.layout_result), tostring(s.gen)
	)
	return table.concat(lines, "\n")
end

--- Board / route / piece tools for Story Dev (not a mixed "sandbox").
function debug.build_thread_tools(parent_id)
	if not ImGui or not parent_id then return end
	local prefix = parent_id .. "_StoneTools"

	local st = imgui_layout.add_section(parent_id, prefix .. "_Prep", tr("传送与准备状态", "Transport & prepare"))
	imgui_layout.add_wrapped_text(st, prefix .. "_PrepStatus", "")
	ImGui.AddCallback(prefix .. "_PrepStatus", ImGuiCallback.Render, function()
		-- Advance prepare while ImGui is open even if the game is paused.
		if debug.has_prepare_job and debug.has_prepare_job() then
			debug.tick_prepare({ from_render = true })
			if debug._pending_activate_after_ready then
				local s = debug.prepare_status()
				if s.status == "ready" then
					debug.activate({ skip_layout = true })
					debug._pending_activate_after_ready = nil
				elseif s.status == "failed" then
					debug._pending_activate_after_ready = nil
				end
			end
		end
		imgui_layout.update_text(prefix .. "_PrepStatus", format_prepare_status())
	end)
	ImGui.AddButton(st, prefix .. "_CancelPrep", tr("取消准备任务", "Cancel prepare"), function()
		debug.cancel_prepare("ui_cancel")
	end)

	local board = imgui_layout.add_section(parent_id, prefix .. "_Board", tr("房间与棋盘", "Rooms & board"))
	imgui_layout.add_wrapped_text(board, prefix .. "_Runtime", "")
	ImGui.AddCallback(prefix .. "_Runtime", ImGuiCallback.Render, function()
		imgui_layout.update_text(prefix .. "_Runtime", debug.inspect_text())
	end)
	ImGui.AddButton(board, prefix .. "_Plan", tr("重新规划本层", "Replan floor"), function()
		layout.try_plan_current_floor({ force = true, ignore_gate = true })
	end)
	ImGui.AddElement(board, "", ImGuiElement.SameLine)
	ImGui.AddButton(board, prefix .. "_Act", tr("强制激活棋盘", "Force activate board"), function()
		debug.activate()
	end)
	ImGui.AddElement(board, "", ImGuiElement.SameLine)
	ImGui.AddButton(board, prefix .. "_Reset", tr("重置棋盘运行态", "Reset Stone runtime"), function()
		debug.cancel_prepare("runtime_reset")
		runtime.reset()
	end)

	ImGui.AddButton(board, prefix .. "_Trigger", tr("传送：触发房", "Warp: trigger"), function()
		debug.goto_checkpoint("origin")
	end)
	ImGui.AddElement(board, "", ImGuiElement.SameLine)
	ImGui.AddButton(board, prefix .. "_RMid", tr("传送：路线中段", "Warp: route mid"), function()
		debug.goto_checkpoint("mid")
	end)
	ImGui.AddElement(board, "", ImGuiElement.SameLine)
	ImGui.AddButton(board, prefix .. "_Term", tr("传送：终点", "Warp: terminal"), function()
		debug.goto_checkpoint("terminal")
	end)
	ImGui.AddElement(board, "", ImGuiElement.SameLine)
	ImGui.AddButton(board, prefix .. "_Ante", tr("传送：前厅", "Warp: ante"), function()
		debug.goto_checkpoint("ante")
	end)
	ImGui.AddElement(board, "", ImGuiElement.SameLine)
	ImGui.AddButton(board, prefix .. "_Boss", tr("传送：Boss 战斗", "Warp: boss live"), function()
		debug.goto_checkpoint("boss", { suppress_boss = false })
	end)

	ImGui.AddButton(board, prefix .. "_TLock", tr("终点门关", "Terminal locked"), function()
		local r = runtime.get()
		r.gate.unlocked = false
		debug.goto_terminal({ activate = true, unlock = false })
		r.gate.unlocked = false
	end)
	ImGui.AddElement(board, "", ImGuiElement.SameLine)
	ImGui.AddButton(board, prefix .. "_TOpen", tr("终点门开", "Terminal open"), function()
		debug.goto_terminal({ activate = true, unlock = true })
	end)
	ImGui.AddElement(board, "", ImGuiElement.SameLine)
	ImGui.AddButton(board, prefix .. "_TRev", tr("终点 Reveal", "Terminal Reveal"), function()
		debug.goto_terminal({ activate = true, force_reveal = true })
	end)
	ImGui.AddElement(board, "", ImGuiElement.SameLine)
	ImGui.AddButton(board, prefix .. "_ReturnTerm", tr("前厅→终点", "Ante → terminal"), function()
		debug.return_to_terminal()
	end)

	imgui_layout.add_wrapped_text(
		board, prefix .. "_BossNote",
		tr(
			"Floraine P1/P2/P3、法杖、升变：调试 → Boss Test → Floraine。",
			"Floraine phases/staff/promote: Debug → Boss Test → Floraine."
		)
	)

	ImGui.AddElement(
		board, "", ImGuiElement.SeparatorText or ImGuiElement.Separator,
		tr("巨型黑兵", "Giant black pawn")
	)
	do
		local origin = require("Qing_Remaster_scripts.threads.stone.stone_origin")
		ImGui.AddButton(board, prefix .. "_PlacePawn", tr("当前房间生成黑兵", "Spawn pawn here"), function()
			local ok, why = origin.debug_place_in_current_room()
			if not ok then
				Isaac.ConsoleOutput("[Stone] place pawn failed: " .. tostring(why) .. "\n")
			end
		end)
		ImGui.AddElement(board, "", ImGuiElement.SameLine)
		ImGui.AddButton(board, prefix .. "_PawnHit", tr("扣除 25% 血量", "Hit 25%"), function()
			local ent = origin.find_room_pawn()
			if ent then
				origin.debug_hit(math.max(1, ent.MaxHitPoints * 0.25))
			end
		end)
		ImGui.AddElement(board, "", ImGuiElement.SameLine)
		ImGui.AddButton(board, prefix .. "_PawnHeal", tr("恢复血量", "Heal"), function()
			origin.debug_heal()
		end)
		ImGui.AddElement(board, "", ImGuiElement.SameLine)
		ImGui.AddButton(board, prefix .. "_PawnBreak", tr("强制最终破损", "Force final break"), function()
			origin.debug_break()
		end)
		ImGui.AddElement(board, "", ImGuiElement.SameLine)
		ImGui.AddButton(board, prefix .. "_PawnClear", tr("清除调试黑兵", "Clear debug pawn"), function()
			origin.clear({ sandbox_only = true })
		end)
		ImGui.AddButton(board, prefix .. "_FpInspect", tr("Inspect Footprint", "Inspect Footprint"), function()
			local d = origin.get_footprint_diag and origin.get_footprint_diag() or {}
			Isaac.ConsoleOutput(string.format(
				"[StoneFootprint] exists=%s marked=%s/%s fail=%s\n",
				tostring(d.giant_pawn_exists),
				tostring(d.footprint_marked_count),
				tostring(d.footprint_expected_count),
				tostring(d.last_gridpath_failure)
			))
		end)
		ImGui.AddElement(board, "", ImGuiElement.SameLine)
		ImGui.AddButton(board, prefix .. "_FpReapply", tr("Reapply GridPath", "Reapply GridPath"), function()
			origin.reapply_grid_footprint()
		end)
	end

	ImGui.AddElement(
		board, "", ImGuiElement.SeparatorText or ImGuiElement.Separator,
		tr("追兵 / 回归", "Pursuit / return")
	)
	ImGui.AddButton(board, prefix .. "_RebuildReturn", tr("重建回归表", "Rebuild return table"), function()
		layout.ensure_offroute_returns({ force = true })
	end)
	ImGui.AddElement(board, "", ImGuiElement.SameLine)
	ImGui.AddButton(board, prefix .. "_ForcePursuit", tr("强制回归追兵", "Force return pursuit"), function()
		local encounter = require("Qing_Remaster_scripts.threads.stone.stone_encounter")
		encounter.debug_force_offroute_pursuit()
	end)
	ImGui.AddElement(board, "", ImGuiElement.SameLine)
	ImGui.AddButton(board, prefix .. "_WaveDoor", tr("门口增援", "Door reinforce"), function()
		local encounter = require("Qing_Remaster_scripts.threads.stone.stone_encounter")
		encounter.debug_force_door_wave()
	end)

	local pieces = imgui_layout.add_section(parent_id, prefix .. "_Pieces", tr("棋子调试", "Piece debug"))
	ImGui.AddButton(pieces, prefix .. "_AllKinds", tr("生成六种棋子", "Spawn six kinds"), function()
		debug.spawn_all_kinds()
	end)
	local piece_defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")
	local kind_btns = {
		{piece_defs.KIND.PAWN, "Pawn"},
		{piece_defs.KIND.VEHICLE, "Vehicle"},
		{piece_defs.KIND.KNIGHT, "Knight"},
		{piece_defs.KIND.BISHOP, "Bishop"},
		{piece_defs.KIND.QUEEN, "Queen"},
		{piece_defs.KIND.KING, "King"},
	}
	for i, row in ipairs(kind_btns) do
		ImGui.AddButton(pieces, prefix .. "_K_" .. row[2], row[2], function()
			debug.spawn_piece(row[1])
		end)
		if i < #kind_btns then
			ImGui.AddElement(pieces, "", ImGuiElement.SameLine)
		end
	end
	ImGui.AddButton(pieces, prefix .. "_SelNear", tr("选中最近棋子", "Select nearest"), function()
		debug.select_nearest_piece()
	end)
	ImGui.AddElement(pieces, "", ImGuiElement.SameLine)
	ImGui.AddButton(pieces, prefix .. "_ModeAuto", tr("模式:自主", "Mode:Autonomous"), function()
		local ent = selected_piece()
		if not ent then debug.select_nearest_piece() ent = selected_piece() end
		if ent then
			local controller = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_controller")
			controller.set_control_mode(ent, piece_defs.MODE.AUTONOMOUS)
		end
	end)
	ImGui.AddElement(pieces, "", ImGuiElement.SameLine)
	ImGui.AddButton(pieces, prefix .. "_ModeDir", tr("模式:受控", "Mode:Directed"), function()
		local ent = selected_piece()
		if not ent then debug.select_nearest_piece() ent = selected_piece() end
		if ent then
			local controller = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_controller")
			controller.set_control_mode(ent, piece_defs.MODE.DIRECTED)
		end
	end)
	ImGui.AddButton(pieces, prefix .. "_Atk", tr("指令:攻击", "Cmd:Attack"), function()
		local ent = selected_piece()
		if not ent then debug.select_nearest_piece() ent = selected_piece() end
		if ent then
			local controller = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_controller")
			controller.command(ent, {type = "ATTACK", force = true})
		end
	end)
	ImGui.AddElement(pieces, "", ImGuiElement.SameLine)
	ImGui.AddButton(pieces, prefix .. "_MoveCtr", tr("移动到中心", "Move to center"), function()
		local ent = selected_piece()
		if not ent then debug.select_nearest_piece() ent = selected_piece() end
		if ent then
			local controller = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_controller")
			controller.set_control_mode(ent, piece_defs.MODE.DIRECTED)
			controller.command(ent, {
				type = "MOVE",
				destination = Game():GetRoom():GetCenterPos(),
				force = true,
			})
		end
	end)
	ImGui.AddElement(pieces, "", ImGuiElement.SameLine)
	ImGui.AddButton(pieces, prefix .. "_WaveClr", tr("清除房间棋子", "Clear room pieces"), function()
		local encounter = require("Qing_Remaster_scripts.threads.stone.stone_encounter")
		encounter.debug_clear_room_pieces()
	end)

	ImGui.AddElement(
		pieces, "", ImGuiElement.SeparatorText or ImGuiElement.Separator,
		tr("门动画预览", "Door animation preview")
	)
	local anims = { "Closed", "Open", "Opened", "Close", "Reveal" }
	for i, anim in ipairs(anims) do
		ImGui.AddButton(pieces, prefix .. "_A_" .. anim, anim, function()
			debug.preview_door(DoorSlot.UP0, anim)
		end)
		if i < #anims then
			ImGui.AddElement(pieces, "", ImGuiElement.SameLine)
		end
	end
end

-- Backward-compatible alias (legacy callers only; Dev Lab mounts build_thread_tools).
function debug.build_advanced(parent_id)
	debug.build_thread_tools(parent_id)
end

function debug.build(parent_id)
	debug.build_thread_tools(parent_id)
end

-- Story-test transport selectors
function debug.transport_selector(selector, opts)
	opts = opts or {}
	if selector == "stone_origin" or selector == "stone_trigger" then
		local ok, err = debug.goto_trigger()
		return ok, ok and "stone trigger" or err
	end
	if selector == "stone_route_start" then
		local ok, err = debug.goto_route_start()
		return ok, ok and "route start" or err
	end
	if selector == "stone_route_middle" then
		local ok, err = debug.goto_route_middle()
		return ok, ok and "route mid" or err
	end
	if selector == "stone_route_end" then
		local ok, err = debug.goto_route_end()
		return ok, ok and "route end" or err
	end
	if selector == "stone_terminal" then
		local ok, err = debug.goto_terminal({ activate = true, unlock = true })
		return ok, ok and "terminal" or err
	end
	if selector == "stone_antechamber" then
		local ok, err = debug.goto_antechamber()
		return ok, ok and "antechamber" or err
	end
	if selector == "stone_boss" or selector == "stone_floraine" then
		local ok, err = debug.goto_floraine({ suppress_boss = true })
		return ok, ok and "floraine" or err
	end
	return false, "unknown stone selector"
end

--- Console: `qing story stone …` → stone_debug.console_command(args, start_index)
function debug.console_command(args, start_index)
	args = args or {}
	start_index = start_index or 3
	local cmd = args[start_index] and string.lower(tostring(args[start_index])) or "inspect"
	local piece_defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")
	local controller = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_controller")
	local encounter = require("Qing_Remaster_scripts.threads.stone.stone_encounter")
	local board = require("Qing_Remaster_scripts.threads.stone.stone_board")

	local function speak_warp(ok, err, label)
		if ok then return result_ok(label, label) end
		return result_err(tostring(err or "warp_failed"), "Stone ERROR: " .. tostring(err or "warp_failed"))
	end

	if cmd == "inspect" then
		return result_ok("inspect", debug.inspect_text():gsub("\n", " | "))
	end
	if cmd == "start" then
		return debug.start_full_test({ preset_id = "mines_ashpit" })
	end
	if cmd == "plan" or (cmd == "floor" and not args[start_index + 1]) then
		debug.ensure_layout({ force = true, ignore_gate = true })
		local r = runtime.get()
		if not r.trigger then
			return result_err("layout_not_ready", "Stone ERROR: layout_not_ready")
		end
		return result_ok("plan", "Stone plan ok / route " .. tostring(#(route.get_path())))
	end
	if cmd == "floor" then
		local which = tostring(args[start_index + 1] or "1")
		local preset = (which == "2") and "mines_ashpit_2" or "mines_ashpit"
		return debug.start_prepare({ preset_id = preset, target = "trigger" })
	end
	if cmd == "origin" or cmd == "trigger" then
		local ok, err = debug.goto_trigger()
		return speak_warp(ok, err, "stone origin")
	end
	if cmd == "activate" then
		local ok = debug.activate()
		return ok and result_ok("activate", "stone activate") or result_err("activate_failed", "activate failed")
	end
	if cmd == "expand" then
		local pct = tonumber(args[start_index + 1]) or 100
		if not runtime.is_board_active() then
			runtime.activate_board("debug_expand")
		end
		board.set_expand_progress(pct)
		return result_ok("expand", "expand " .. tostring(pct) .. "%")
	end
	if cmd == "route" then
		local which = args[start_index + 1] and string.lower(tostring(args[start_index + 1])) or "1"
		if which == "mid" or which == "middle" then
			local ok, err = debug.goto_route_middle()
			return speak_warp(ok, err, "route mid")
		elseif which == "end" then
			local ok, err = debug.goto_route_end()
			return speak_warp(ok, err, "route end")
		else
			local ok, err = debug.goto_route_index(tonumber(which) or 1)
			return speak_warp(ok, err, "route " .. which)
		end
	end
	if cmd == "wave" then
		local which = args[start_index + 1] and string.lower(tostring(args[start_index + 1])) or "initial"
		if which == "door" then
			local ent, msg = encounter.debug_force_door_wave()
			return ent and result_ok("wave_door", "door wave") or result_err(tostring(msg), tostring(msg))
		elseif which == "clear" then
			local n = encounter.debug_clear_room_pieces()
			return result_ok("wave_clear", "cleared " .. tostring(n) .. " pieces")
		elseif which == "return" or which == "offroute" or which == "pursuit" then
			local ent, msg = encounter.debug_force_offroute_pursuit()
			return ent and result_ok("wave_return", "return pursuit") or result_err(tostring(msg), tostring(msg))
		else
			encounter.debug_force_wave(piece_defs.KIND.PAWN)
			return result_ok("wave_initial", "initial wave")
		end
	end
	if cmd == "return" or cmd == "offroute" then
		local sub = args[start_index + 1] and string.lower(tostring(args[start_index + 1])) or "inspect"
		if sub == "rebuild" or sub == "build" then
			local ok, why, n = layout.ensure_offroute_returns({ force = true })
			return ok and result_ok("return_rebuild", string.format("built n=%s", tostring(n)))
				or result_err(tostring(why), tostring(why))
		end
		local od = encounter.get_offroute_diag()
		return result_ok("return_inspect", string.format(
			"sgi=%s return=%s next=%s dist=%s join=%s diag=%s",
			tostring(od.sgi), tostring(od.return_slot), tostring(od.return_next_sgi),
			tostring(od.distance_to_route), tostring(od.join_route_sgi), tostring(od.diag)
		))
	end
	if cmd == "director" or cmd == "formation" then
		local sub = args[start_index + 1] and string.lower(tostring(args[start_index + 1])) or "inspect"
		if sub == "round" or sub == "next" then
			local d = encounter.debug_director_round()
			return result_ok("director_round", string.format("round=%s phase=%s tactic=%s", tostring(d.round_id), tostring(d.phase), tostring(d.tactic)))
		end
		if sub == "pause" then
			encounter.debug_director_pause(true)
			return result_ok("director_pause", "director paused")
		end
		if sub == "resume" then
			encounter.debug_director_pause(false)
			return result_ok("director_resume", "director resumed")
		end
		if sub == "flank" or sub == "pin" or sub == "heavy" then
			local map = {flank = "flank", pin = "pin_and_leap", heavy = "heavy_command"}
			encounter.debug_director_tactic(map[sub])
			return result_ok("director_tactic", "force " .. map[sub])
		end
		if sub == "stagnate" or sub == "stall" or sub == "idle" then
			local director = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_director")
			local s = director.get_stagnation_diag()
			local parts = {}
			for i = 1, math.min(8, #(s.pieces or {})) do
				local p = s.pieces[i]
				parts[#parts + 1] = string.format(
					"%s/%s bound=%s st=%s task=%s land=%s prep=%s why=%s",
					tostring(p.kind), tostring(p.mode), tostring(p.director_bound),
					tostring(p.action_state), tostring(p.task), tostring(p.legal_landings),
					tostring(p.prepare_streak), tostring(p.reason)
				)
			end
			local fw = encounter.get_first_wave_diag and encounter.get_first_wave_diag() or {}
			return result_ok("director_stagnate", string.format(
				"round=%s phase=%s maxPrep=%s firstWave={pending=%s done=%s phase=%s fail=%s} pieces={%s}",
				tostring(s.round_id), tostring(s.phase), tostring(s.max_prepare_streak),
				tostring(fw.pending), tostring(fw.done), tostring(fw.phase), tostring(fw.fail),
				(#parts > 0) and table.concat(parts, " | ") or "none"
			))
		end
		local d = encounter.debug_director()
		local reasons = d.command_rejection_reasons or {}
		local reason_s = ""
		for k, v in pairs(reasons) do
			reason_s = reason_s .. tostring(k) .. "=" .. tostring(v) .. " "
		end
		if reason_s == "" then reason_s = "none" end
		local moves = d.move_choices or {}
		local move_s = ""
		for i = 1, math.min(6, #moves) do
			local m = moves[i]
			move_s = move_s .. string.format("%s:%s L=%s c=%s s=%s %s→%s; ",
				tostring(m.role), tostring(m.kind), tostring(m.landings),
				tostring(m.cells), tostring(m.score), tostring(m.from), tostring(m.to))
		end
		if move_s == "" then move_s = "none" end
		return result_ok("director", string.format(
			"en=%s phase=%s round=%s members=%s ready=%s tactic=%s atk=%s/%s man=%s movMan=%s acc=%s rej=%s queued=%s reasons={%s} moves={%s}",
			tostring(d.enabled), tostring(d.phase), tostring(d.round_id),
			tostring(d.member_count), tostring(d.ready_count), tostring(d.tactic),
			tostring(d.primary_count), tostring(d.secondary_count), tostring(d.maneuver_count),
			tostring(d.moving_maneuvers),
			tostring(d.commands_accepted), tostring(d.commands_rejected),
			tostring(d.queued_reinforcements or d.pending_reinforcements),
			reason_s, move_s
		))
	end
	if cmd == "arrival" or cmd == "doorarrival" then
		local door_arrival = require("Qing_Remaster_scripts.threads.stone.stone_door_arrival")
		local d = door_arrival.get_diag()
		local pos = d.arrival_position
		local pos_s = pos and string.format("%.1f,%.1f", pos.x, pos.y) or "nil"
		return result_ok("arrival", string.format(
			"pending=%s src=%s dest=%s srcSlot=%s arrSlot=%s pos=%s applied=%s reject=%s",
			tostring(door_arrival.has_pending()),
			tostring(d.source_room), tostring(d.destination_room),
			tostring(d.source_door_slot), tostring(d.arrival_door_slot),
			pos_s, tostring(d.arrival_applied), tostring(d.arrival_reject_reason)
		))
	end
	if cmd == "ante" or cmd == "antechamber" then
		local ok, err = debug.goto_antechamber()
		return speak_warp(ok, err, "ante")
	end
	if cmd == "boss" or cmd == "floraine" then
		local which = args[start_index + 1] and string.lower(tostring(args[start_index + 1])) or "empty"
		local live = which == "live"
		local ok, err = debug.goto_floraine({ suppress_boss = not live })
		return speak_warp(ok, err, live and "boss live" or "boss empty")
	end
	if cmd == "reset" then
		runtime.reset()
		prepare_job = nil
		return result_ok("reset", "Stone runtime reset (test run state only; not permanent story unlocks)")
	end
	if cmd == "pawn" then
		local origin = require("Qing_Remaster_scripts.threads.stone.stone_origin")
		local sub = args[start_index + 1] and string.lower(tostring(args[start_index + 1])) or "inspect"
		if sub == "spawn" then
			local ok, why = origin.debug_place_in_current_room()
			return ok and result_ok("pawn_spawn", "pawn spawned") or result_err(tostring(why), "pawn spawn: " .. tostring(why))
		end
		if sub == "inspect" then
			return result_ok("pawn_inspect", origin.inspect_text())
		end
		if sub == "hit" then
			local amt = tonumber(args[start_index + 2]) or 5
			local ok, hp = origin.debug_hit(amt)
			return ok and result_ok("pawn_hit", "hit " .. tostring(amt) .. " → HP " .. tostring(hp))
				or result_err(tostring(hp), "pawn hit failed")
		end
		if sub == "heal" then
			local ok = origin.debug_heal()
			return ok and result_ok("pawn_heal", "healed") or result_err("no_pawn", "no pawn")
		end
		if sub == "break" then
			local ok = origin.debug_break()
			return ok and result_ok("pawn_break", "sandbox break") or result_err("no_pawn", "no pawn")
		end
		if sub == "clear" then
			origin.clear({ sandbox_only = true })
			return result_ok("pawn_clear", "cleared sandbox pawns")
		end
		return result_err("unknown_pawn", "unknown pawn subcommand " .. sub)
	end
	if cmd == "piece" then
		local sub = args[start_index + 1] and string.lower(tostring(args[start_index + 1])) or "inspect"
		if sub == "all" then
			debug.spawn_all_kinds()
			return result_ok("piece_all", "spawned six kinds")
		end
		if sub == "spawn" then
			local name = args[start_index + 2] and string.lower(tostring(args[start_index + 2])) or "pawn"
			local map = {
				pawn = piece_defs.KIND.PAWN,
				vehicle = piece_defs.KIND.VEHICLE,
				rook = piece_defs.KIND.VEHICLE,
				knight = piece_defs.KIND.KNIGHT,
				bishop = piece_defs.KIND.BISHOP,
				queen = piece_defs.KIND.QUEEN,
				king = piece_defs.KIND.KING,
			}
			local kind = map[name]
			if not kind then return result_err("bad_kind", "unknown kind " .. name) end
			debug.spawn_piece(kind)
			return result_ok("piece_spawn", "spawned " .. name)
		end
		if sub == "select" then
			return debug.select_piece_by_debug_id(args[start_index + 2])
		end
		if sub == "inspect" then
			local ent = selected_piece()
			if not ent then
				local r = debug.select_nearest_piece()
				if not r.ok then return r end
				ent = selected_piece()
			end
			local st = controller.get_status(ent)
			return result_ok("piece_inspect", string.format(
				"#%s kind=%s mode=%s state=%s",
				tostring(sandbox.selected_debug_id),
				tostring(st.kind),
				tostring(st.control_mode),
				tostring(st.action_state)
			))
		end
		local ent = selected_piece()
		if not ent then
			return result_err("no_selection", "Stone ERROR: no piece selected (piece select <id> / spawn first)")
		end
		if sub == "mode" then
			local mode_name = args[start_index + 2] and string.upper(tostring(args[start_index + 2])) or "AUTONOMOUS"
			local mode = piece_defs.MODE[mode_name] or mode_name
			controller.set_control_mode(ent, mode)
			return result_ok("piece_mode", "mode " .. tostring(mode))
		end
		if sub == "attack" then
			local ok, why = controller.command(ent, {type = "ATTACK", force = true})
			return ok and result_ok("piece_attack", "attack") or result_err(tostring(why), tostring(why))
		end
		if sub == "move" then
			local x = tonumber(args[start_index + 2])
			local y = tonumber(args[start_index + 3])
			if not x or not y then
				return result_err("bad_pos", "piece move needs world X Y")
			end
			controller.set_control_mode(ent, piece_defs.MODE.DIRECTED)
			local ok, why = controller.command(ent, {
				type = "MOVE",
				destination = Vector(x, y),
				force = true,
			})
			return ok and result_ok("piece_move", "move " .. x .. " " .. y) or result_err(tostring(why), tostring(why))
		end
		if sub == "interrupt" then
			controller.interrupt(ent, "console")
			return result_ok("piece_interrupt", "interrupted")
		end
		if sub == "clear" then
			local n = encounter.debug_clear_room_pieces()
			sandbox.selected_ptr = nil
			return result_ok("piece_clear", "cleared " .. tostring(n))
		end
		return result_err("unknown_piece", "unknown piece subcommand " .. sub)
	end
	return result_err("unknown", "unknown stone cmd " .. tostring(cmd))
end

return debug
