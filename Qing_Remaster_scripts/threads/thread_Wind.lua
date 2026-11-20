local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local grid_door = require("Qing_Remaster_scripts.grids.grid_doors")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local wind = require("Qing_Remaster_scripts.threads.wind.wind_runtime")
local env_wind = require("Qing_Remaster_scripts.threads.wind.environment_controller")
local boss_wind = require("Qing_Remaster_scripts.bosses.Zennith.boss_wind_controller")
local encounter = require("Qing_Remaster_scripts.threads.wind.storm_encounter")

local PROBE_PATH = "Qing_Remaster_scripts.threads.wind.wind_pipeline_probe"
local function wind_probe_note_trigger(info)
	local mod = package.loaded[PROBE_PATH]
	if type(mod) == "table" and mod.is_listening and mod.is_listening() and mod.note_trigger then
		mod.note_trigger(info)
	end
end
local Unlocker = require("Qing_Remaster_scripts.core.unlock_manager")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Dialog_holder = require("Qing_Remaster_scripts.others.Dialog_holder")
local gate = require("Qing_Remaster_scripts.story.story_runtime_gate")
local bfs_policy = require("Qing_Remaster_scripts.threads.wind.wind_start_policy")
local geo_dir = require("Qing_Remaster_scripts.threads.wind.wind_geo_direction")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "thread_wind_",
	-- Read-only activation trace for Storm Activation Gate Probe (V5.3).
	activation_trace = {
		spawn_events = {},
		last_pre_new_level = nil,
		last_clean_award = nil,
		last_new_room = nil,
		last_begin = nil,
		last_bfs_call = nil,
	},
	word_list = {
		zh = {
			[1] = {
				"风暴开始席卷大地",
			},
			[2] = {
				"以撒：",
				"好猛烈的风啊，到底发生了什么？",
				"我最好回头看一看",
			},
		},
		en = {
			[1] = {
				"The Wind is blowing heavily",
			},
			[2] = {
				"Isaac:",
				"What a fierce wind! What happened?",
				"I'd better turn around and take a look.",
			},
		},
	},
	banish_room_list = {
		--[1] = true,
		[5] = true,
		[7] = true,
		[8] = true,
		[11] = true,
		[29] = true,
	},
	banish_move_room_list = {
		[7] = true,
		[8] = true,
	},
}

-- Encounter owns discovery/arrival/transfer callbacks; register under this thread.
for i = 1, #(encounter.ToCall or {}) do
	table.insert(item.ToCall, #item.ToCall + 1, encounter.ToCall[i])
end
for i = 1, #(encounter.myToCall or {}) do
	table.insert(item.myToCall, #item.myToCall + 1, encounter.myToCall[i])
end

local function activation_push_spawn(action, reason, extra)
	local tr = item.activation_trace
	local list = tr.spawn_events
	if #list >= 32 then
		table.remove(list, 1)
	end
	list[#list + 1] = {
		t = Game():GetFrameCount(),
		action = action,
		reason = reason,
		value = save.elses[item.own_key .. "spawn"],
		extra = extra,
	}
end

local function set_spawn_flag(value, reason, extra)
	local prev = save.elses[item.own_key .. "spawn"]
	save.elses[item.own_key .. "spawn"] = value
	activation_push_spawn(value == true and "set_true" or "clear", reason, {
		prev = prev,
		extra = extra,
	})
end

function item.can_spawn()
	local level = Game():GetLevel() local stageType = level:GetStageType()
	return level:GetStage() == LevelStage.STAGE3_1 and stageType >= StageType.STAGETYPE_REPENTANCE
end

function item.explain_can_spawn()
	local level = Game():GetLevel()
	local stage = level:GetStage()
	local stageType = level:GetStageType()
	local ok = stage == LevelStage.STAGE3_1 and stageType >= StageType.STAGETYPE_REPENTANCE
	if ok then
		return true, "mausoleum_or_gehenna_i", {stage = stage, stage_type = stageType}
	end
	return false, "not_mausoleum_gehenna_i", {stage = stage, stage_type = stageType}
end

function item.should_spawn()
	return item.can_spawn() and save.elses[item.own_key.."spawn"] == true
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, params = nil,
Function = function(_,Rng,spwnpos)
	local room = Game():GetRoom()
	local level = Game():GetLevel()
	local desc = level:GetCurrentRoomDesc()
	local mat_ok, mat_reason = gate.explain_material_event_enabled("chapter1.wind")
	local floor_ok, floor_reason = item.explain_can_spawn()
	local cond = {
		material_event = mat_ok,
		material_reason = mat_reason,
		room_type = room:GetType(),
		is_boss_room = room:GetType() == RoomType.ROOM_BOSS,
		sgid = desc and desc.SafeGridIndex,
		sgid_ok = desc and desc.SafeGridIndex and desc.SafeGridIndex > 0,
		can_spawn = floor_ok,
		can_spawn_reason = floor_reason,
		spawn_already = save.elses[item.own_key .. "spawn"] == true,
	}
	local pass = cond.material_event and cond.is_boss_room and cond.sgid_ok and cond.can_spawn and not cond.spawn_already
	item.activation_trace.last_clean_award = {
		t = Game():GetFrameCount(),
		pass = pass == true,
		conditions = cond,
		blocked_by = (not cond.material_event and "material_event")
			or (not cond.is_boss_room and "not_boss_room")
			or (not cond.sgid_ok and "bad_sgid")
			or (not cond.can_spawn and "can_spawn")
			or (cond.spawn_already and "spawn_already")
			or nil,
	}
	if not pass then
		return
	end
	local language = Options.Language
	local str = (item.word_list[language] or item.word_list["en"])[1][1]
	gui.general_speak(Vector(0,0),str,0,120,{R = 2,G = 2,B = 0,})
	local dialog_gen = (tonumber(save.elses[item.own_key .. "dialog_gen"]) or 0) + 1
	save.elses[item.own_key .. "dialog_gen"] = dialog_gen
	delay_buffer.addeffe(function()
		-- Cancelled by floor reset / wind_clear_map bumping dialog_gen.
		if save.elses[item.own_key .. "dialog_gen"] ~= dialog_gen then return end
		if save.elses[item.own_key .. "spawn"] ~= true then return end
		Dialog_holder.add_word({data =(item.word_list[language] or item.word_list["en"])[2],header = {sprite_name = "Isaac"},step_by = true,})
	end,{},30 * 3)

	set_spawn_flag(true, "MC_PRE_SPAWN_CLEAN_AWARD_boss_clear")
	encounter.set_phase(encounter.PHASE.SEARCHING)
	wind.start_()
	encounter.mark_story_owned(true)
	local sgid = desc.SafeGridIndex
	local ok_env, err_env = item.apply_environment_for_room(sgid, {
		source = "formal_spawn_callback",
		allow_eye_discovery = true,
	})
	if not ok_env then
		print("[thread_Wind] env wind apply failed: " .. tostring(err_env)
			.. " sgid=" .. tostring(sgid)
			.. " eye=" .. tostring(save.elses["Zennith_room"]))
	end
end,
})

-- 13x13 floor map. SafeGridIndex runs 0..168.
local MAP_INDEX_LAST = 13 * 13 - 1

function item.clear_bfs_labels()
	for i = 0, MAP_INDEX_LAST do
		save.elses["Zennith_room_conter_" .. i] = nil
		save.elses["Zennith_room_dir_" .. i] = nil
	end
	save.elses["Zennith_room"] = nil
	save.elses["Zennith_bfs_stage"] = nil
	save.elses["Zennith_bfs_stage_type"] = nil
	save.elses["Zennith_bfs_seed"] = nil
end

local function room_neighbors(level, sgid)
	local edges = {}
	local pos_rou = auxi.move_in_rou(sgid, 13, 13)
	local pos_tg = {sgid}
	for _, v1 in pairs(pos_rou) do
		local same_desc = level:GetRoomByIdx(v1)
		if same_desc and same_desc.Data and same_desc.SafeGridIndex == sgid then
			pos_tg[#pos_tg + 1] = v1
		end
	end
	for _, v1 in pairs(pos_tg) do
		local pos_pos = auxi.move_in_sq(v1, 13, 13)
		for _, v2 in pairs(pos_pos) do
			local tar = level:GetRoomByIdx(v2.id)
			local n = tar and tar.Data and tar.SafeGridIndex or -1
			if n > 0 and tar.Data.Type ~= 7 then
				edges[#edges + 1] = {id = n, dir = v2.dir}
			end
		end
	end
	return edges
end

--- Every map cell that belongs to this SafeGridIndex, not just the index cell.
local function occupied_cells(level, sgid)
	local cells = {sgid}
	local seen = {[sgid] = true}
	local cursor = 1
	while cells[cursor] and #cells < 16 do
		local ring = auxi.move_in_rou(cells[cursor], 13, 13)
		for _, idx in pairs(ring or {}) do
			if not seen[idx] then
				local desc = level:GetRoomByIdx(idx)
				if desc and desc.SafeGridIndex == sgid then
					seen[idx] = true
					cells[#cells + 1] = idx
				end
			end
		end
		cursor = cursor + 1
	end
	return cells
end

--- Continuous heading for a reachable non-eye room. Nil keeps the old cardinal path.
function item.environment_heading(sgid)
	sgid = tonumber(sgid)
	if not sgid or sgid <= 0 then return nil end
	local distance = save.elses["Zennith_room_conter_" .. sgid]
	if distance == nil or distance == 0 then return nil end
	local eye = save.elses["Zennith_room"]
	if eye == nil then return nil end
	local level = Game():GetLevel()
	local head = geo_dir.heading(
		occupied_cells(level, eye),
		occupied_cells(level, sgid),
		save.elses["Zennith_room_dir_" .. sgid]
	)
	if not head or head.ang == nil then return nil end
	local room = Game():GetRoom()
	local center = room:GetCenterPos()
	local tl = room:GetTopLeftPos()
	local br = room:GetBottomRightPos()
	local span = math.max(math.abs(br.X - tl.X), math.abs(br.Y - tl.Y), 1)
	local cells = head.cells or 1
	local mul = cells <= 1 and 4 or 2.4
	local bend = cells <= 1 and 0.06 or 0.18
	return {
		ang = head.ang,
		visual_source = center - Vector(head.x, head.y) * (span * mul),
		visual_bend = bend,
		room_cells = cells,
		geo_x = head.x,
		geo_y = head.y,
	}
end

function item.selected_eye_sgid()
	return save.elses["Zennith_room"]
end

function item.heading_debug()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local sgid = desc and desc.SafeGridIndex
	local eye = save.elses["Zennith_room"]
	local out = {
		room_sgid = sgid,
		eye_sgid = eye,
		bfs_distance = sgid and save.elses["Zennith_room_conter_" .. sgid] or nil,
		bfs_dir = sgid and save.elses["Zennith_room_dir_" .. sgid] or nil,
	}
	if eye and sgid and sgid > 0 then
		local level = Game():GetLevel()
		local ex, ey = geo_dir.center_of(occupied_cells(level, eye))
		local rx, ry = geo_dir.center_of(occupied_cells(level, sgid))
		if ex and rx then
			out.eye_center = string.format("%.2f,%.2f", ex, ey)
			out.room_center = string.format("%.2f,%.2f", rx, ry)
			local gx, gy = geo_dir.normalize(rx - ex, ry - ey)
			out.geo_heading = gx and string.format("%.2f,%.2f", gx, gy) or "-"
			local bx, by = geo_dir.bfs_blow(out.bfs_dir)
			out.bfs_heading = bx and string.format("%.2f,%.2f", bx, by) or "-"
			local mx, my = geo_dir.mix(rx - ex, ry - ey, bx, by)
			out.mixed_heading = mx and string.format("%.2f,%.2f", mx, my) or "-"
		end
	end
	local st = wind.get_state and wind.get_state() or {}
	out.runtime_ang = st.ang
	out.wind_phase = st.phase
	out.session_generation = st.session_generation
	out.debug_active = st.debug_active == true
	if st.ang ~= nil then
		local physics = require("Qing_Remaster_scripts.threads.wind.wind_physics")
		local blow = physics.wind_blow_dir(st.ang)
		if blow then
			out.visual_blow = string.format("%.2f,%.2f", blow.X, blow.Y)
		end
	end
	local vs = st.visual or {}
	out.last_reset = vs.last_reset_reason
	out.room_trace = vs.room_trace
	out.prefill = vs.last_prefill
	return out
end

local function directional_room_opts(sgid, distance)
	local opts = {
		distance = distance,
		dir = save.elses["Zennith_room_dir_" .. sgid],
	}
	local head = item.environment_heading(sgid)
	if head then
		opts.ang = head.ang
		opts.visual_source = head.visual_source
		opts.visual_bend = head.visual_bend
		opts.room_cells = head.room_cells
	end
	return opts
end

function item.bfs_floor_identity_matches()
	local level = Game():GetLevel()
	local eye = save.elses["Zennith_room"]
	if save.elses["Zennith_bfs_stage"] ~= level:GetStage() then return false end
	if save.elses["Zennith_bfs_stage_type"] ~= level:GetStageType() then return false end
	if save.elses["Zennith_bfs_seed"] ~= Game():GetSeeds():GetStageSeed(level:GetStage()) then return false end
	if eye == nil or save.elses["Zennith_room_conter_" .. eye] ~= 0 then return false end
	return true
end

function item.bfs_matches_floor()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local sgid = desc and desc.SafeGridIndex
	if not item.bfs_floor_identity_matches() then return false end
	if sgid == nil or save.elses["Zennith_room_conter_" .. sgid] == nil then return false end
	return true
end

local function story_test_session()
	local ok, session = pcall(require, "Qing_Remaster_scripts.story_test.story_test_session")
	if ok and type(session) == "table" then return session end
	return nil
end

local function wind_thread_touched()
	local session = story_test_session()
	if not session or not session.is_active or session.is_active() ~= true then return false end
	local touched = session.get_touched_threads and session.get_touched_threads() or {}
	for i = 1, #touched do
		if touched[i] == "wind" then return true end
	end
	return false
end

--- Live storm-test ownership. A generic Story Test, a finished test, or a bare spawn flag is not enough.
function item.wind_test_owns_active_exploration()
	if not wind_thread_touched() then return false end
	if save.elses[item.own_key .. "spawn"] ~= true then return false end
	if not item.can_spawn() then return false end
	if not item.bfs_floor_identity_matches() then return false end
	return true
end

--- Same answer for starting a storm and for keeping it across rooms.
function item.explain_wind_runtime_allowed(opts)
	opts = opts or {}
	local ch_ok, ch_reason, ch_detail = gate.explain_chapter1_available()
	local source = nil
	local allowed = false
	if ch_ok then
		allowed = true
		source = "formal_chapter"
	elseif opts.for_start == true and wind_thread_touched() and item.can_spawn() then
		allowed = true
		source = "wind_story_test"
	elseif item.wind_test_owns_active_exploration() then
		allowed = true
		source = "wind_story_test"
	end
	local session = story_test_session()
	local session_on = session and session.is_active and session.is_active() == true
	item.last_wind_permission = {
		allowed = allowed,
		source = source,
		chapter_ok = ch_ok == true,
		chapter_reason = ch_reason,
		chapter_detail = ch_detail,
		test_session_active = session_on == true,
		wind_test_owned = item.wind_test_owns_active_exploration(),
	}
	if allowed then
		return true, source, ch_reason, ch_detail
	end
	return false, ch_reason, ch_detail
end

function item.current_bfs_distance()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local sgid = desc and desc.SafeGridIndex
	if sgid == nil then return nil end
	return save.elses["Zennith_room_conter_" .. sgid]
end

function item.explore_is_active()
	return item.can_spawn()
		and save.elses[item.own_key .. "spawn"] == true
		and item.bfs_matches_floor()
end

function item.plan_a_bfs(opts)
	opts = opts or {}
	local level = Game():GetLevel()
	local current = level:GetCurrentRoomDesc()
	local current_sgid = current and current.SafeGridIndex
	local rng = RNG()
	rng:SetSeed(Game():GetSeeds():GetStageSeed(level:GetStage()), 0)

	local rooms = level:GetRooms()
	local tg = {}
	local room_total = 0
	for i = 0, rooms.Size do
		local targ = rooms:Get(i)
		if targ ~= nil and targ.SafeGridIndex >= 0 then
			room_total = room_total + 1
			local id = targ.SafeGridIndex
			local rdesc = level:GetRoomByIdx(id)
			if rdesc and rdesc.Data and item.banish_room_list[rdesc.Data.Type] ~= true then
				table.insert(tg, #tg + 1, targ)
			end
		end
	end
	local report = {
		ok = false,
		candidate_count = #tg,
		room_total = room_total,
		current_sgid = current_sgid,
		eye_sgid = nil,
		labeled_count = 0,
		current_covered = false,
		current_distance = nil,
		fail_reason = nil,
	}
	if #tg == 0 then
		report.fail_reason = "no_bfs_candidates"
		item.last_bfs_report = report
		item.activation_trace.last_bfs_call = {
			t = Game():GetFrameCount(),
			ok = false,
			report = report,
		}
		return false, report.fail_reason
	end
	local ids = {}
	for i, targ in ipairs(tg) do
		ids[i] = targ.SafeGridIndex
	end
	local eye, dist, dir, reason = bfs_policy.choose_eye(ids, function(sgid)
		return room_neighbors(level, sgid)
	end, current_sgid, {
		deterministic = opts.deterministic == true,
		first_index = rng:RandomInt(#ids) + 1,
	})
	if not eye then
		report.fail_reason = reason or "current_room_unreachable_from_eye"
		item.last_bfs_report = report
		item.activation_trace.last_bfs_call = {
			t = Game():GetFrameCount(),
			ok = false,
			report = report,
		}
		return false, report.fail_reason
	end
	-- Commit only a finished map. A missed room must not leave a half-written storm.
	item.clear_bfs_labels()
	local labeled = 0
	for sgid, distance in pairs(dist) do
		save.elses["Zennith_room_conter_" .. sgid] = distance
		save.elses["Zennith_room_dir_" .. sgid] = dir[sgid]
		labeled = labeled + 1
	end
	save.elses["Zennith_room"] = eye
	save.elses["Zennith_bfs_stage"] = level:GetStage()
	save.elses["Zennith_bfs_stage_type"] = level:GetStageType()
	save.elses["Zennith_bfs_seed"] = Game():GetSeeds():GetStageSeed(level:GetStage())
	report.eye_sgid = eye
	report.labeled_count = labeled
	report.current_distance = current_sgid and dist[current_sgid] or nil
	report.current_covered = report.current_distance ~= nil
	report.deterministic = opts.deterministic == true
	if current_sgid ~= nil and not report.current_covered then
		item.clear_bfs_labels()
		report.fail_reason = "storm_bfs_distance_missing"
		report.ok = false
		item.last_bfs_report = report
		item.activation_trace.last_bfs_call = {
			t = Game():GetFrameCount(),
			ok = false,
			report = report,
		}
		return false, report.fail_reason
	end
	report.ok = true
	item.last_bfs_report = report
	item.activation_trace.last_bfs_call = {
		t = Game():GetFrameCount(),
		ok = true,
		report = report,
	}
	return true, report
end

--- Strict env wind apply: nil distance is a hard failure (never treat as weak wind).
function item.apply_environment_for_room(sgid, opts)
	opts = opts or {}
	sgid = sgid or (Game():GetLevel():GetCurrentRoomDesc() and Game():GetLevel():GetCurrentRoomDesc().SafeGridIndex)
	if not sgid or sgid <= 0 then
		item.activation_trace.last_begin = {
			t = Game():GetFrameCount(),
			ok = false,
			reason = "storm_invalid_sgid",
			source = opts.source,
			sgid = sgid,
		}
		return false, "storm_invalid_sgid"
	end
	local distance = save.elses["Zennith_room_conter_" .. sgid]
	if distance == nil then
		wind_probe_note_trigger({
			source = opts.source or "apply_environment_for_room",
			sgid = sgid,
			distance = nil,
			fail = "storm_bfs_distance_missing",
		})
		item.activation_trace.last_begin = {
			t = Game():GetFrameCount(),
			ok = false,
			reason = "storm_bfs_distance_missing",
			source = opts.source,
			sgid = sgid,
		}
		return false, "storm_bfs_distance_missing"
	end
	wind_probe_note_trigger({
		source = opts.source or "apply_environment_for_room",
		sgid = sgid,
		distance = distance,
		dir = save.elses["Zennith_room_dir_" .. sgid],
	})
	if distance == 0 and opts.keep_searching then
		env_wind.begin_room({
			distance = 0,
			dir = save.elses["Zennith_room_dir_" .. sgid],
			mode = 2,
			pos = Game():GetRoom():GetCenterPos(),
			intensity = 0.55,
			phase = "eye",
			eye_radius_scale = 0.35,
		})
		item.activation_trace.last_begin = {
			t = Game():GetFrameCount(),
			ok = true,
			reason = "explore_at_eye",
			source = opts.source,
			sgid = sgid,
			distance = 0,
		}
		return true
	end
	if distance == 0 then
		if opts.allow_eye_discovery == false then
			item.activation_trace.last_begin = {
				t = Game():GetFrameCount(),
				ok = false,
				reason = "storm_at_eye_no_discovery",
				source = opts.source,
				sgid = sgid,
				distance = 0,
			}
			return false, "storm_at_eye_no_discovery"
		end
		local ok_eye, err_eye = encounter.begin_eye_discovery()
		item.activation_trace.last_begin = {
			t = Game():GetFrameCount(),
			ok = ok_eye ~= false,
			reason = (ok_eye ~= false) and "begin_eye_discovery" or tostring(err_eye),
			source = opts.source,
			sgid = sgid,
			distance = 0,
		}
		return ok_eye, err_eye
	end
	env_wind.begin_room(directional_room_opts(sgid, distance))
	item.activation_trace.last_begin = {
		t = Game():GetFrameCount(),
		ok = true,
		reason = "begin_room",
		source = opts.source,
		sgid = sgid,
		distance = distance,
		dir = save.elses["Zennith_room_dir_" .. sgid],
	}
	return true
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	set_spawn_flag(nil, "PRE_NEW_LEVEL_clear")
	local ch_ok, ch_reason = gate.explain_chapter1_available()
	local unlock = Unlocker.should_any_be_done("Thread", "Wind", nil, "Boss_allow")
	local floor_ok, floor_reason = item.explain_can_spawn()
	local bfs_ran = false
	local bfs_ok, bfs_err = nil, nil
	if ch_ok and unlock then
		item.clear_bfs_labels()
		if floor_ok then
			bfs_ran = true
			bfs_ok, bfs_err = item.plan_a_bfs()
		end
	end
	item.activation_trace.last_pre_new_level = {
		t = Game():GetFrameCount(),
		chapter_ok = ch_ok,
		chapter_reason = ch_reason,
		unlocker_boss_allow = unlock == true,
		floor_ok = floor_ok,
		floor_reason = floor_reason,
		bfs_ran = bfs_ran,
		bfs_ok = bfs_ok,
		bfs_err = bfs_err,
		blocked_by = (not ch_ok and "chapter_gate")
			or (not unlock and "unlocker_boss_allow")
			or (not floor_ok and "can_spawn")
			or nil,
	}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local room = Game():GetRoom()
	local level = Game():GetLevel()
	local desc = level:GetCurrentRoomDesc()
	local ch_ok, ch_reason, ch_detail = gate.explain_chapter1_available()
	local allowed, permission_source = item.explain_wind_runtime_allowed()
	local floor_ok, floor_reason = item.explain_can_spawn()
	local sgid = desc and desc.SafeGridIndex
	local spawn = save.elses[item.own_key .. "spawn"] == true
	local bfs_dist = sgid and save.elses["Zennith_room_conter_" .. sgid] or nil
	local nr = {
		t = Game():GetFrameCount(),
		chapter_ok = ch_ok,
		chapter_reason = ch_reason,
		chapter_detail = ch_detail,
		permission_allowed = allowed == true,
		permission_source = permission_source,
		floor_ok = floor_ok,
		floor_reason = floor_reason,
		sgid = sgid,
		spawn = spawn,
		bfs_distance = bfs_dist,
		entered_wind_branch = false,
		begin_called = false,
		blocked_by = nil,
	}
	local function release_room_wind(reason)
		local st = wind.get_state and wind.get_state() or {}
		if st.kind == "boss" then return end
		wind.stop(reason)
	end
	local function begin_eye_environment(scale)
		env_wind.begin_room({
			distance = 0,
			mode = 2,
			pos = room:GetCenterPos(),
			intensity = 0.7,
			phase = "eye",
			eye_radius_scale = scale or 0.35,
		})
	end
	if not allowed then
		nr.blocked_by = "chapter_gate"
		release_room_wind("chapter_gate")
	elseif not floor_ok then
		nr.blocked_by = "can_spawn"
		release_room_wind("can_spawn")
	elseif not (sgid and sgid > 0) then
		nr.blocked_by = "bad_sgid"
		release_room_wind("bad_sgid")
	elseif not spawn then
		nr.blocked_by = "spawn_flag_false"
		release_room_wind("spawn_flag_false")
	elseif bfs_dist == nil then
		nr.blocked_by = "bfs_distance_nil"
		nr.entered_wind_branch = true
		release_room_wind("bfs_distance_nil")
	else
		nr.entered_wind_branch = true
		if encounter.is_arena_room(sgid) then
			nr.blocked_by = "arena_room"
			release_room_wind("arena_room")
		else
			wind.start_()
			if bfs_dist ~= 0 then
				env_wind.begin_room(directional_room_opts(sgid, bfs_dist))
				nr.begin_called = true
				nr.begin_kind = "directional"
				item.activation_trace.last_begin = {
					t = nr.t,
					ok = true,
					reason = "begin_room",
					source = "MC_POST_NEW_ROOM",
					sgid = sgid,
					distance = bfs_dist,
					dir = save.elses["Zennith_room_dir_" .. sgid],
				}
			elseif encounter.should_start_discovery(sgid)
				and (encounter.is_story_owned() or item.wind_test_owns_active_exploration()) then
				local ok_eye, err_eye = encounter.begin_eye_discovery()
				nr.begin_called = true
				nr.begin_kind = (ok_eye ~= false) and "eye_discovery" or "eye_discovery_failed"
				nr.story_owned = encounter.is_story_owned()
				item.activation_trace.last_begin = {
					t = nr.t,
					ok = ok_eye ~= false,
					reason = (ok_eye ~= false) and "begin_eye_discovery" or tostring(err_eye),
					source = "MC_POST_NEW_ROOM",
					sgid = sgid,
					distance = 0,
				}
				if ok_eye == false then
					begin_eye_environment(0.35)
				end
			else
				begin_eye_environment(0.35)
				nr.begin_called = true
				nr.begin_kind = "eye_environment"
				item.activation_trace.last_begin = {
					t = nr.t,
					ok = true,
					reason = "eye_environment",
					source = "MC_POST_NEW_ROOM",
					sgid = sgid,
					distance = 0,
				}
			end
		end
	end
	item.activation_trace.last_new_room = nr
end,
})

--l print(Game():GetLevel():GetCurrentRoomDesc().Data.Variant)
--l local room = Game():GetRoom();local size = room:GetGridSize();for i = 0,size - 1 do local gent = room:GetGridEntity(i);if (gent) then if gent:GetType() == GridEntityType.GRID_PRESSURE_PLATE and gent:GetVariant() == 9 then gent:Destroy(true); end end end

local function wind_clear_map()
	item.clear_bfs_labels()
	set_spawn_flag(nil, "wind_clear_map")
	save.elses[item.own_key .. "dialog_gen"] = (tonumber(save.elses[item.own_key .. "dialog_gen"]) or 0) + 1
	encounter.clear()
	env_wind.clear()
	boss_wind.clear()
end

item.story_test = {
	snapshot = function(_ctx)
		local snap = {
			spawn = save.elses[item.own_key .. "spawn"],
			zennith_room = save.elses["Zennith_room"],
			counters = {},
			dirs = {},
		}
		for i = 0, MAP_INDEX_LAST do
			if save.elses["Zennith_room_conter_" .. i] ~= nil then
				snap.counters[i] = save.elses["Zennith_room_conter_" .. i]
			end
			if save.elses["Zennith_room_dir_" .. i] ~= nil then
				snap.dirs[i] = save.elses["Zennith_room_dir_" .. i]
			end
		end
		snap.reward_done = save.elses["thread_wind_enc_reward_done"]
		snap.story_owned = save.elses["thread_wind_enc_story_owned"]
		snap.zennith_end = save.elses.Zennith_end
		snap.bfs_stage = save.elses["Zennith_bfs_stage"]
		snap.bfs_stage_type = save.elses["Zennith_bfs_stage_type"]
		snap.bfs_seed = save.elses["Zennith_bfs_seed"]
		return snap
	end,
	restore = function(snap, _ctx)
		wind_clear_map()
		if type(snap) ~= "table" then return end
		save.elses[item.own_key .. "spawn"] = snap.spawn
		save.elses["Zennith_room"] = snap.zennith_room
		for i, v in pairs(snap.counters or {}) do
			save.elses["Zennith_room_conter_" .. i] = v
		end
		for i, v in pairs(snap.dirs or {}) do
			save.elses["Zennith_room_dir_" .. i] = v
		end
		save.elses["thread_wind_enc_reward_done"] = snap.reward_done
		save.elses["thread_wind_enc_story_owned"] = snap.story_owned
		save.elses.Zennith_end = snap.zennith_end
		save.elses["Zennith_bfs_stage"] = snap.bfs_stage
		save.elses["Zennith_bfs_stage_type"] = snap.bfs_stage_type
		save.elses["Zennith_bfs_seed"] = snap.bfs_seed
	end,
	reset = function(_ctx)
		wind_clear_map()
		return true
	end,
	prepare = function(ctx)
		ctx = ctx or {}
		local phase = ctx.phase or "pre_trigger"
		wind_clear_map()
		if phase == "pre_trigger" then
			if item.can_spawn() then
				item.plan_a_bfs()
			end
			save.elses[item.own_key .. "spawn"] = nil
			encounter.set_phase(encounter.PHASE.SEARCHING)
		elseif phase == "storm_active" then
			if item.can_spawn() then
				item.plan_a_bfs()
			end
			save.elses[item.own_key .. "spawn"] = true
			encounter.set_phase(encounter.PHASE.SEARCHING)
		elseif phase == "discovered" then
			if item.can_spawn() then
				item.plan_a_bfs()
			end
			save.elses[item.own_key .. "spawn"] = true
			-- Ready for eye discovery when player arrives; do not auto-start cinematic here.
			encounter.set_phase(encounter.PHASE.SEARCHING)
		elseif phase == "boss" then
			if item.can_spawn() then
				item.plan_a_bfs()
			end
			save.elses[item.own_key .. "spawn"] = true
			encounter.set_phase(encounter.PHASE.SEARCHING)
		end
		return true
	end,
	trigger = function(ctx)
		ctx = ctx or {}
		if ctx.phase == "boss" or ctx.phase == "storm_active" or ctx.phase == "discovered" then
			save.elses[item.own_key .. "spawn"] = true
			if item.can_spawn() and not save.elses["Zennith_room"] then
				item.plan_a_bfs()
			end
			encounter.set_phase(encounter.PHASE.SEARCHING)
			return true
		end
		return false, "no trigger for phase"
	end,
	inspect = function(_ctx)
		return {
			phase = encounter.get_phase(),
			story_spawn = save.elses[item.own_key .. "spawn"] == true,
			target_room = save.elses["Zennith_room"],
			arena_room = encounter.get_arena_sgid(),
			spawn = save.elses[item.own_key .. "spawn"] == true,
			can_spawn = item.can_spawn(),
			gate = gate.is_material_event_enabled("chapter1.wind"),
		}
	end,
	cleanup = function(_ctx)
		wind_clear_map()
		return true
	end,
}

local function room_descriptor(sgid)
	if sgid == nil then return nil end
	local desc = Game():GetLevel():GetRoomByIdx(sgid)
	if desc and desc.Data then return desc end
	return nil
end

local function each_floor_room(fn)
	local rooms = Game():GetLevel():GetRooms()
	for i = 0, rooms.Size - 1 do
		local desc = rooms:Get(i)
		if desc and desc.Data and desc.SafeGridIndex ~= nil then
			if fn(desc.SafeGridIndex, desc) then return end
		end
	end
end

--- Jump helpers for Story Dev Lab (formal BFS data required).
function item.find_room_by_distance(target_dist)
	target_dist = tonumber(target_dist)
	if target_dist == nil then return nil end
	local exact = item.find_exact_room(target_dist)
	if exact ~= nil then return exact end
	local best, best_gap = nil, nil
	each_floor_room(function(sgid)
		local d = save.elses["Zennith_room_conter_" .. sgid]
		if d == nil then return end
		local gap = math.abs(d - target_dist)
		if best == nil or gap < best_gap then
			best = sgid
			best_gap = gap
		end
	end)
	return best
end

function item.goto_bfs_distance(target_dist)
	if not save.elses[item.own_key .. "spawn"] then
		return false, "storm not active"
	end
	if not save.elses["Zennith_room"] then
		if item.can_spawn() then
			local planned, perr = item.plan_a_bfs()
			if not planned then
				return false, perr or "no BFS / wrong floor"
			end
		else
			return false, "no BFS / wrong floor"
		end
	end
	local sgid = item.find_room_by_distance(target_dist)
	if sgid == nil then
		return false, "no room near distance " .. tostring(target_dist)
	end
	local ok, err = pcall(function()
		Game():ChangeRoom(sgid)
	end)
	if not ok then
		return false, tostring(err)
	end
	return true, sgid
end

function item.find_exact_room(target_dist)
	target_dist = tonumber(target_dist)
	if target_dist == nil then return nil end
	if target_dist == 0 then
		local eye = save.elses["Zennith_room"]
		if eye ~= nil
			and save.elses["Zennith_room_conter_" .. eye] == 0
			and room_descriptor(eye) then
			return eye
		end
		return nil
	end
	local found = nil
	each_floor_room(function(sgid)
		if save.elses["Zennith_room_conter_" .. sgid] == target_dist then
			found = sgid
			return true
		end
	end)
	return found
end

function item.goto_eye_room()
	local eye = save.elses["Zennith_room"]
	local desc = room_descriptor(eye)
	item.last_eye_jump = {
		selected = eye,
		target = eye,
		descriptor = desc ~= nil,
		distance = eye ~= nil and save.elses["Zennith_room_conter_" .. eye] or nil,
	}
	if not save.elses[item.own_key .. "spawn"] then
		return false, "storm not active"
	end
	if eye == nil then
		return false, "eye_unset"
	end
	if not desc then
		return false, "eye_room_missing"
	end
	if save.elses["Zennith_room_conter_" .. eye] ~= 0 then
		return false, "eye_distance_not_zero"
	end
	local ok, err = pcall(function()
		Game():ChangeRoom(eye)
	end)
	if not ok then
		return false, tostring(err)
	end
	return true, eye
end

function item.activate_explore(opts)
	opts = opts or {}
	if not item.can_spawn() then
		return false, "need Mausoleum/Gehenna I"
	end
	local allowed, _source, deny_reason = item.explain_wind_runtime_allowed({for_start = true})
	if not allowed and not item.explore_is_active() then
		return false, deny_reason or "chapter_gate"
	end
	if item.explore_is_active() then
		return true, "already_active"
	end
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local sgid = desc and desc.SafeGridIndex
	local planned, perr = item.plan_a_bfs({deterministic = opts.deterministic == true})
	if not planned then
		item.clear_bfs_labels()
		set_spawn_flag(nil, "activate_explore_rollback")
		return false, perr or "storm_bfs_distance_missing"
	end
	local gate_ok, gate_err = bfs_policy.storm_commit_gate({
		floor_ok = true,
		eye = save.elses["Zennith_room"],
		current_distance = item.current_bfs_distance(),
	})
	if not gate_ok then
		item.clear_bfs_labels()
		set_spawn_flag(nil, "activate_explore_rollback")
		return false, gate_err
	end
	set_spawn_flag(true, "activate_explore")
	encounter.mark_story_owned(false)
	if encounter.get_phase() ~= encounter.PHASE.SEARCHING then
		encounter.set_phase(encounter.PHASE.SEARCHING)
	end
	local ok_env, err_env = item.apply_environment_for_room(sgid, {
		source = "activate_explore",
		allow_eye_discovery = false,
		keep_searching = true,
	})
	if not ok_env then
		set_spawn_flag(nil, "activate_explore_rollback")
		return false, err_env or "storm_bfs_distance_missing"
	end
	if encounter.get_phase() ~= encounter.PHASE.SEARCHING then
		encounter.set_phase(encounter.PHASE.SEARCHING)
	end
	wind.start_()
	return true
end

function item.force_formal_trigger(opts)
	return item.activate_explore(opts)
end

function item.get_bfs_report()
	return item.last_bfs_report
end

local function json_encode_safe(value)
	local ok, json = pcall(require, "json")
	if not ok or not json or not json.encode then
		return nil
	end
	local ok2, text = pcall(json.encode, value)
	if ok2 then return text end
	return nil
end

--- Instant read-only snapshot for Activation Gate Probe (no story writes).
function item.build_activation_check()
	local level = Game():GetLevel()
	local desc = level:GetCurrentRoomDesc()
	local room = Game():GetRoom()
	local sgid = desc and desc.SafeGridIndex
	local tr = item.activation_trace or {}
	local floor_ok, floor_reason, floor_detail = item.explain_can_spawn()
	local ch_ok, ch_reason, ch_detail = gate.explain_chapter1_available()
	local mat_ok, mat_reason, mat_detail = gate.explain_material_event_enabled("chapter1.wind")
	local unlock = Unlocker.should_any_be_done("Thread", "Wind", nil, "Boss_allow")
	local ModConfig = require("Qing_Remaster_scripts.others.Mod_Config_Menu_holder")
	local unlock_detail = {
		ending1 = save.UnlockData and save.UnlockData.Others and save.UnlockData.Others.Ending1 and save.UnlockData.Others.Ending1.Unlock,
		boss_allow_setting = ModConfig.ModConfigSettings and ModConfig.ModConfigSettings.Boss_allow,
	}
	local bfs = item.last_bfs_report
	local dist = sgid and save.elses["Zennith_room_conter_" .. sgid] or nil
	local dir = sgid and save.elses["Zennith_room_dir_" .. sgid] or nil
	local spawn = save.elses[item.own_key .. "spawn"] == true
	local sess = nil
	do
		local ok_s, session = pcall(require, "Qing_Remaster_scripts.story_test.story_test_session")
		if ok_s and session then
			sess = {
				active = session.is_active and session.is_active() == true,
				has_story_override = type(session.get_story_override and session.get_story_override()) == "table",
				gate_sees_test = gate.is_story_test_active() == true,
			}
		end
	end
	local wind_st = nil
	do
		local ok_w, wr = pcall(require, "Qing_Remaster_scripts.threads.wind.wind_runtime")
		if ok_w and wr and wr.get_state then
			wind_st = wr.get_state()
		end
	end

	local function row(id, status, detail)
		return {id = id, status = status, detail = detail}
	end

	local rows = {}
	rows[#rows + 1] = row("C01_FLOOR", floor_ok and "PASS" or "FAIL",
		tostring(floor_reason) .. " " .. (json_encode_safe(floor_detail) or ""))
	rows[#rows + 1] = row("C02_CHAPTER_GATE", ch_ok and "PASS" or "FAIL",
		tostring(ch_reason) .. " " .. (json_encode_safe(ch_detail) or ""))
	rows[#rows + 1] = row("C03_MATERIAL_GATE", mat_ok and "PASS" or "FAIL",
		tostring(mat_reason) .. " " .. (json_encode_safe(mat_detail) or ""))
	rows[#rows + 1] = row("C04_UNLOCKER", unlock and "PASS" or "FAIL",
		"Boss_allow=" .. tostring(unlock) .. " " .. (json_encode_safe(unlock_detail) or ""))

	if tr.last_pre_new_level then
		local p = tr.last_pre_new_level
		if p.bfs_ran then
			rows[#rows + 1] = row("C05_BFS_INIT", p.bfs_ok and "PASS" or "FAIL",
				"ran ok=" .. tostring(p.bfs_ok) .. " err=" .. tostring(p.bfs_err))
		else
			rows[#rows + 1] = row("C05_BFS_INIT", "NOT REACHED",
				"PRE_NEW_LEVEL blocked_by=" .. tostring(p.blocked_by))
		end
	else
		rows[#rows + 1] = row("C05_BFS_INIT", "NOT REACHED", "PRE_NEW_LEVEL not observed this session")
	end

	if dist ~= nil then
		rows[#rows + 1] = row("C06_BFS_CURRENT", "PASS",
			"sgid=" .. tostring(sgid) .. " distance=" .. tostring(dist) .. " dir=" .. tostring(dir)
				.. " eye=" .. tostring(save.elses["Zennith_room"]))
	elseif bfs and bfs.eye_sgid then
		rows[#rows + 1] = row("C06_BFS_CURRENT", "FAIL",
			"sgid=" .. tostring(sgid) .. " distance=nil eye=" .. tostring(bfs.eye_sgid)
				.. " labeled=" .. tostring(bfs.labeled_count)
				.. " current_covered=" .. tostring(bfs.current_covered)
				.. " fail=" .. tostring(bfs.fail_reason))
	else
		rows[#rows + 1] = row("C06_BFS_CURRENT", "FAIL",
			"sgid=" .. tostring(sgid) .. " distance=nil (no BFS report)")
	end

	if tr.last_clean_award then
		local c = tr.last_clean_award
		rows[#rows + 1] = row("C07_BOSS_CLEAR", c.pass and "PASS" or "FAIL",
			"blocked_by=" .. tostring(c.blocked_by) .. " " .. (json_encode_safe(c.conditions) or ""))
	else
		local waiting = room:GetType() ~= RoomType.ROOM_BOSS
		rows[#rows + 1] = row("C07_BOSS_CLEAR", waiting and "WAITING" or "NOT REACHED",
			waiting and "not in boss room; clear callback not fired yet"
				or "in boss room but clean award not observed")
	end

	rows[#rows + 1] = row("C08_SPAWN_FLAG", spawn and "PASS" or "FAIL",
		"thread_wind_spawn=" .. tostring(spawn)
			.. " last_events=" .. tostring(#(tr.spawn_events or {})))

	if tr.last_new_room then
		local n = tr.last_new_room
		if n.begin_called then
			rows[#rows + 1] = row("C09_NEW_ROOM", "PASS",
				"begin_kind=" .. tostring(n.begin_kind) .. " dist=" .. tostring(n.bfs_distance))
		elseif n.blocked_by then
			rows[#rows + 1] = row("C09_NEW_ROOM", "FAIL",
				"blocked_by=" .. tostring(n.blocked_by) .. " spawn=" .. tostring(n.spawn))
		else
			rows[#rows + 1] = row("C09_NEW_ROOM", "FAIL", json_encode_safe(n) or "?")
		end
	else
		rows[#rows + 1] = row("C09_NEW_ROOM", "NOT REACHED", "MC_POST_NEW_ROOM not observed")
	end

	if tr.last_begin then
		local b = tr.last_begin
		rows[#rows + 1] = row("C10_WIND_BEGIN", b.ok and "PASS" or "FAIL",
			"reason=" .. tostring(b.reason) .. " source=" .. tostring(b.source)
				.. " dist=" .. tostring(b.distance))
	else
		rows[#rows + 1] = row("C10_WIND_BEGIN", "NOT REACHED", "begin_room not called")
	end

	local blocking = {}
	for _, r in ipairs(rows) do
		if r.status == "FAIL" then
			blocking[#blocking + 1] = r.id
		end
	end

	return {
		rows = rows,
		blocking = blocking,
		story_test = sess,
		runtime = wind_st,
		trace = {
			pre_new_level = tr.last_pre_new_level,
			clean_award = tr.last_clean_award,
			new_room = tr.last_new_room,
			begin = tr.last_begin,
			bfs_call = tr.last_bfs_call,
			spawn_events = tr.spawn_events,
		},
		bfs_report = bfs,
	}
end

package.loaded["Qing_Remaster_scripts.threads.thread_Wind"] = item
require("Qing_Remaster_scripts.threads.wind.wind_test_runner")

return item
