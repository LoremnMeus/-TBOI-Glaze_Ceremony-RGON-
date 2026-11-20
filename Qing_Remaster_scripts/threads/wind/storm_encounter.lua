-- Storm Story V2 — eye discovery → tip reveal → surge, dive, solid cover → arena.
-- Never spawns a real Zennith NPC in the eye room.
-- Arena boss stays INTRO_LOCKED until cover-out finishes.
-- Story material settlement is owned here (story_owned), not by room-index equality.

local save = require("Qing_Remaster_scripts.core.savedata")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local enums = require("Qing_Remaster_scripts.core.enums")
local env_wind = require("Qing_Remaster_scripts.threads.wind.environment_controller")
local boss_wind = require("Qing_Remaster_scripts.bosses.Zennith.boss_wind_controller")
local wind = require("Qing_Remaster_scripts.threads.wind.wind_runtime")
local Zennith = require("Qing_Remaster_scripts.bosses.Zennith.Zennith")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")
local arena_room = require("Qing_Remaster_scripts.threads.wind.arena_room")
local arrival = require("Qing_Remaster_scripts.threads.wind.zennith_arrival_visual")
local gust = require("Qing_Remaster_scripts.threads.wind.arrival_gust_visual")
local tornado = require("Qing_Remaster_scripts.threads.wind.tornado_visual")
local wind_visual = require("Qing_Remaster_scripts.threads.wind.wind_visual")
local arena_visual = require("Qing_Remaster_scripts.threads.wind.arena_visual")

local function tornado_layer_enabled()
	local mask = wind_visual.get_layer_mask and wind_visual.get_layer_mask()
	if not mask then return true end
	return mask.tornado ~= false
end

local M = {
	own_key = "thread_wind_enc_",
	ToCall = {},
	myToCall = {},
	last_error = nil,
}

local PHASE = {
	SEARCHING = "SEARCHING",
	EYE_DISCOVERED = "EYE_DISCOVERED",
	EYE_FORMING = "EYE_FORMING",
	ZENNITH_REVEAL = "ZENNITH_REVEAL",
	ZENNITH_DESCENDING = "ZENNITH_DESCENDING",
	IMPACT = "IMPACT",
	COVER_IN = "COVER_IN",
	COVERED = "COVERED",
	ARENA_PREPARED = "ARENA_PREPARED",
	TRANSFER_REQUESTED = "TRANSFER_REQUESTED",
	ARENA_LOADING = "ARENA_LOADING",
	ARENA_CONFIRMED = "ARENA_CONFIRMED",
	COVER_OUT = "COVER_OUT",
	INTRO_LOCKED = "INTRO_LOCKED",
	BATTLE = "BATTLE",
	COMPLETED = "COMPLETED",
	FAILED = "FAILED",
}

M.PHASE = PHASE

local BEAT = {
	-- Grow volumetric tornado before Zennith silhouette appears at the tip.
	form_end = 100,
	-- Tip opening hold (opening mode) before descent starts.
	reveal = 18,
	cover_in = 12,
	cover_out = 22,
	-- After cover clears: hold Idle before unlocking AI.
	intro_lock = 16,
	-- Arena transfer fail-safe (logic frames @ 30Hz).
	arena_wait_warn = 150,
	arena_wait_fail = 300,
}

local function key(name)
	return M.own_key .. name
end

local function runtime()
	M._runtime = M._runtime or {}
	return M._runtime
end

function M.get_phase()
	return save.elses[key("phase")] or PHASE.SEARCHING
end

function M.set_phase(phase)
	save.elses[key("phase")] = phase
	save.elses[key("phase_frame")] = 0
end

function M.get_phase_frame()
	return tonumber(save.elses[key("phase_frame")]) or 0
end

local function bump_phase_frame()
	save.elses[key("phase_frame")] = M.get_phase_frame() + 1
end

function M.get_arena_sgid()
	return save.elses[key("arena_sgid")] or arena_room.get_sgid()
end

function M.is_arena_room(sgid)
	sgid = sgid or (Game():GetLevel():GetCurrentRoomDesc() and Game():GetLevel():GetCurrentRoomDesc().SafeGridIndex)
	local arena = M.get_arena_sgid()
	return sgid and arena and sgid == arena
end

function M.is_eye_room(sgid)
	sgid = sgid or (Game():GetLevel():GetCurrentRoomDesc() and Game():GetLevel():GetCurrentRoomDesc().SafeGridIndex)
	return sgid and save.elses["Zennith_room"] == sgid
end

function M.is_story_owned()
	return save.elses[key("story_owned")] == true
end

function M.mark_story_owned(owned)
	save.elses[key("story_owned")] = owned == true or nil
end

function M.get_cover_alpha()
	return tonumber(save.elses[key("cover_alpha")]) or 0
end

local function set_cover(alpha)
	alpha = math.max(0, math.min(1, tonumber(alpha) or 0))
	save.elses[key("cover_alpha")] = alpha
	-- The story veil is the solid transition cover, not the old ring ribbons.
	wind.set_cover_alpha(0)
end

local function cover_state()
	return save.elses[key("cover_state")] or "none"
end

function M.cover_draw_enabled()
	return save.elses[key("cover_draw")] == true
end

--- Full white after the burst. Ready/fade/released are one-shot and are not pulled back to hold.
local function begin_white_hold()
	local st = cover_state()
	if st == "fade" or st == "released" then return end
	if save.elses[key("ready_for_reveal")] == true then return end
	save.elses[key("cover_state")] = "hold"
	save.elses[key("cover_draw")] = true
	save.elses[key("fade_frame")] = nil
	set_cover(1)
end

local function begin_white_fade()
	if cover_state() == "fade" then return end
	save.elses[key("cover_state")] = "fade"
	save.elses[key("cover_draw")] = true
	save.elses[key("fade_frame")] = 0
	set_cover(1)
end

local function release_cover()
	save.elses[key("cover_state")] = "released"
	save.elses[key("cover_draw")] = nil
	save.elses[key("fade_frame")] = nil
	set_cover(0)
end

local function tick_arrival_gust(shown)
	if shown ~= "offscreen_hold" and shown ~= "dive" and shown ~= "impact_cover" and shown ~= "done" then
		return
	end
	if not gust.is_active() then
		gust.begin()
	end
	if shown == "impact_cover" or shown == "done" then
		gust.wind_down()
	end
	gust.update()
end

local function sync_arrival_column()
	if not tornado.is_active() then return end
	if tornado.set_surge_scale_y then
		tornado.set_surge_scale_y(arrival.get_surge and arrival.get_surge() or 1)
	end
	local top = tornado.get_top_anchor()
	if top and arrival.set_anchor then
		arrival.set_anchor(top)
	end
end

function M.clear()
	save.elses[key("phase")] = nil
	save.elses[key("phase_frame")] = nil
	save.elses[key("timer")] = nil
	save.elses[key("arena_sgid")] = nil
	save.elses[key("eye_sgid")] = nil
	save.elses[key("boss_spawned")] = nil
	save.elses[key("transfer_request_id")] = nil
	save.elses[key("cover_alpha")] = nil
	save.elses[key("cover_state")] = nil
	save.elses[key("cover_draw")] = nil
	save.elses[key("fade_frame")] = nil
	save.elses[key("ready_for_reveal")] = nil
	save.elses[key("cover_block")] = nil
	save.elses[key("visual_wait")] = nil
	save.elses[key("last_error")] = nil
	save.elses[key("reward_done")] = nil
	-- story_owned cleared only on full cleanup / new floor — keep across arena load.
	M.last_error = nil
	M._runtime = nil
	M._direct_battle = nil
	M._cover_draw_trace = nil
	arrival.clear()
	gust.clear()
	tornado.clear()
	local visual = require("Qing_Remaster_scripts.threads.wind.wind_visual")
	if visual.clear_impact then visual.clear_impact() end
	arena_room.clear()
	arena_visual.shutdown()
	wind.set_cover_alpha(0)
	wind.set_phase("directional")
end

function M.clear_story_flags()
	save.elses[key("story_owned")] = nil
	save.elses[key("reward_done")] = nil
end

local function fail(code)
	M.last_error = code
	save.elses[key("last_error")] = code
	M.set_phase(PHASE.FAILED)
	release_cover()
	arrival.clear()
	gust.clear()
	tornado.clear()
	arena_visual.shutdown()
	return false, code
end

local function remove_greed_plates()
	local room = Game():GetRoom()
	local size = room:GetGridSize()
	for i = 0, size - 1 do
		local gent = room:GetGridEntity(i)
		if gent and gent:GetType() == GridEntityType.GRID_PRESSURE_PLATE and gent:GetVariant() == 9 then
			Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, room:GetGridPosition(i), Vector(0, 0), nil)
			room:RemoveGridEntity(i, 0, true)
		end
	end
end

local function wind_test_owns_exploration()
	local ok_tw, thread_wind = pcall(require, "Qing_Remaster_scripts.threads.thread_Wind")
	if not ok_tw or type(thread_wind) ~= "table" or not thread_wind.wind_test_owns_active_exploration then
		return false
	end
	return thread_wind.wind_test_owns_active_exploration() == true
end

function M.begin_eye_discovery()
	local room = Game():GetRoom()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if not desc then return fail("no_room") end
	local phase = M.get_phase()
	if phase ~= PHASE.SEARCHING and phase ~= PHASE.EYE_DISCOVERED then
		return false, "bad_phase:" .. tostring(phase)
	end
	if M.is_arena_room(desc.SafeGridIndex) then
		return false, "arena_room"
	end
	-- Cinematic may run for a wind test. Formal material ownership stays false.
	local test_ok, test_session = pcall(require, "Qing_Remaster_scripts.story_test.story_test_session")
	local testing = test_ok and test_session and test_session.is_active and test_session.is_active()
	if save.elses["thread_wind_spawn"] == true and not testing and not wind_test_owns_exploration() then
		M.mark_story_owned(true)
	end
	save.elses[key("eye_sgid")] = desc.SafeGridIndex
	M.set_phase(PHASE.EYE_DISCOVERED)
	save.elses[key("timer")] = 0
	remove_greed_plates()
	env_wind.begin_room({
		distance = 0,
		mode = 2,
		pos = room:GetCenterPos(),
		intensity = 0.55,
		phase = "eye",
		eye_radius_scale = 0.35,
	})
	arrival.clear()
	return true
end

local function prepare_arena()
	local sgid, err = arena_room.ensure_room()
	if not sgid then
		return fail("arena_prepare:" .. tostring(err))
	end
	save.elses[key("arena_sgid")] = sgid
	M.set_phase(PHASE.ARENA_PREPARED)
	return true, sgid
end

local function request_transfer()
	local sgid = M.get_arena_sgid()
	if not sgid then
		local ok = prepare_arena()
		if not ok then return false end
		sgid = M.get_arena_sgid()
	end
	local dim = auxi.GetDimension and auxi.GetDimension() or 0
	local req = (tonumber(save.elses[key("transfer_request_id")]) or 0) + 1
	save.elses[key("transfer_request_id")] = req
	M.set_phase(PHASE.TRANSFER_REQUESTED)
	local player = Game():GetPlayer(0)
	Room_holder.Trans_to(sgid, Direction.NO_DIRECTION, RoomTransitionAnim.PIXELATION, player, dim)
	M.set_phase(PHASE.ARENA_LOADING)
	return true
end

local function lock_boss_intro(boss, locked)
	if not boss or not Zennith.set_intro_locked then return false end
	return Zennith.set_intro_locked(boss, locked) == true
end

local function tag_test_boss(boss, spawned_now)
	if not spawned_now or M._test_request == nil or not boss or not boss.GetData then
		return
	end
	boss:GetData().qing_wind_test_request = M._test_request
end

function M.set_test_request(id)
	M._test_request = id
	M._direct_token = id
end

function M.cleanup_test_attempt(plan)
	if type(plan) ~= "table" then return end
	if plan.remove_request ~= nil then
		local list = Isaac.FindByType(996, enums.Enemies.Zennith, -1, false, false)
		for i = 1, #list do
			local ent = list[i]
			if ent and ent.GetData then
				local data = ent:GetData()
				if data and data.qing_wind_test_request == plan.remove_request and ent.Remove then
					ent:Remove()
				end
			end
		end
	end
	if plan.reset_cover then
		release_cover()
	end
	if plan.shutdown_arena then
		arrival.clear()
		tornado.clear()
		arena_visual.shutdown()
		if wind_visual.clear_impact then wind_visual.clear_impact() end
	end
	if plan.reset_phase then
		M.set_phase(PHASE.SEARCHING)
	end
	if plan.shutdown_arena or plan.reset_phase then
		M._direct_battle = nil
		M._direct_token = nil
		M._test_request = nil
	end
end

local function find_living_boss()
	local list = Isaac.FindByType(996, enums.Enemies.Zennith, -1, false, false)
	for i = 1, #list do
		local ent = list[i]
		if auxi.check_all_exists(ent) then
			return ent
		end
	end
	return nil
end

function M.boss_encounter_settled()
	return save.elses[key("reward_done")] == true or M.get_phase() == PHASE.COMPLETED
end

function M.enter_arena_battle()
	local ok, why = arena_room.validate_current()
	if not ok then
		return fail("arena_unconfirmed:" .. tostring(why))
	end
	if M.boss_encounter_settled() then
		release_cover()
		if M.get_phase() ~= PHASE.COMPLETED then
			M.set_phase(PHASE.COMPLETED)
		end
		arena_visual.notify_battle_ended()
		return true, "settled"
	end
	local phase_now = M.get_phase()
	local already_out = phase_now == PHASE.COVER_OUT
		or phase_now == PHASE.INTRO_LOCKED
		or phase_now == PHASE.BATTLE
	-- Keep the confirm timer running across retries. Resetting it would hide a stuck spawn.
	if not already_out and phase_now ~= PHASE.ARENA_CONFIRMED then
		M.set_phase(PHASE.ARENA_CONFIRMED)
	end
	if save.elses[key("ready_for_reveal")] ~= true then
		begin_white_hold()
	end
	arrival.release_actor()
	remove_greed_plates()
	env_wind.pause_for_combat()
	wind.set_phase("combat")

	local boss, spawned_now = Zennith.start_(Game():GetRoom():GetCenterPos())
	if Zennith.duplicate_error then
		M.last_error = Zennith.duplicate_error
		save.elses[key("last_error")] = Zennith.duplicate_error
	end
	tag_test_boss(boss, spawned_now == true)
	if not auxi.check_all_exists(boss) then
		save.elses[key("boss_spawned")] = nil
		save.elses[key("last_error")] = "boss_missing"
		return false, "boss_missing"
	end
	save.elses[key("boss_spawned")] = true
	runtime().boss = boss
	if not lock_boss_intro(boss, true) then
		save.elses[key("last_error")] = "boss_lock_failed"
		return false, "boss_lock_failed"
	end
	boss_wind.set_vortex({ent = boss, delta_pos = Vector(0, -20), intensity = 0.55})

	local ready, vwhy = arena_visual.ensure_ready()
	if not ready then
		save.elses[key("cover_block")] = "visual_ready:" .. tostring(vwhy)
		save.elses[key("last_error")] = save.elses[key("cover_block")]
		return false, vwhy
	end
	local bosses = arrival.count_real_boss()
	local locked = Zennith.is_intro_locked and Zennith.is_intro_locked(boss) == true
	if bosses == 1 and locked then
		save.elses[key("ready_for_reveal")] = true
		save.elses[key("cover_block")] = nil
	else
		save.elses[key("cover_block")] = string.format(
			"cover_blocked:boss_count=%s,boss_locked=%s",
			tostring(bosses), tostring(locked)
		)
		save.elses[key("last_error")] = save.elses[key("cover_block")]
	end
	if not already_out then
		M.set_phase(PHASE.COVER_OUT)
	end
	return true
end

function M.direct_battle_ready()
	local arena_ok = select(1, arena_room.validate_current()) == true
	local bosses = arrival.count_real_boss()
	local boss = find_living_boss()
	local locked = false
	if boss and Zennith.is_intro_locked then
		locked = Zennith.is_intro_locked(boss) == true
	end
	local ready = arena_ok
		and arena_visual.is_ready()
		and bosses == 1
		and locked == false
		and M.get_phase() == PHASE.BATTLE
	return ready, {
		arena = arena_ok,
		visual = arena_visual.is_ready(),
		bosses = bosses,
		locked = locked,
		phase = M.get_phase(),
	}
end

--- Dev entry: place the arena, then wait for the real room callback before the fight starts.
function M.arm_direct_battle()
	M.clear()
	M.mark_story_owned(false)
	M._direct_battle = true
	begin_white_hold()
	local ok, err = prepare_arena()
	if not ok then
		M._direct_battle = nil
		return false, err
	end
	M.set_phase(PHASE.ARENA_PREPARED)
	local moved = request_transfer()
	if not moved then
		M._direct_battle = nil
		return false, save.elses[key("last_error")] or "transfer_failed"
	end
	return true
end

--- Called only after the arena room identity is already confirmed.
function M.open_battle_now()
	if not select(1, arena_room.validate_current()) then
		return false, "not_in_arena"
	end
	if M.boss_encounter_settled() then
		return false, "already_settled"
	end
	local ready = select(1, M.direct_battle_ready())
	if ready then
		release_cover()
		return true
	end
	local entered, err = M.enter_arena_battle()
	if M.boss_encounter_settled() then
		return false, "already_settled"
	end
	if not entered then
		return false, err or save.elses[key("last_error")] or "boss_or_visual"
	end
	local boss = find_living_boss()
	if not auxi.check_all_exists(boss) then
		return false, "boss_missing"
	end
	lock_boss_intro(boss, false)
	release_cover()
	M.set_phase(PHASE.BATTLE)
	local done, report = M.direct_battle_ready()
	if not done then
		return false, "checklist"
	end
	return true, report
end

--- Called only on verified Boss defeat (not room unload / abort).
function M.notify_boss_defeated(ent)
	local ph = M.get_phase()
	if ph ~= PHASE.BATTLE and ph ~= PHASE.COVER_OUT and ph ~= PHASE.ARENA_CONFIRMED and ph ~= PHASE.INTRO_LOCKED then
		-- Allow defeat during battle; ignore if not in combat flow.
		if not M.is_arena_room() and not M.is_story_owned() then
			return false, "not_battle"
		end
	end
	boss_wind.fade_out()
	if save.elses[key("reward_done")] then
		M.set_phase(PHASE.COMPLETED)
		arena_visual.notify_battle_ended()
		return true, "already_rewarded"
	end
	if M.is_story_owned() and not wind_test_owns_exploration() then
		local ok, material_adapter = pcall(require, "Qing_Remaster_scripts.story.material_story_adapter")
		if ok and material_adapter and material_adapter.on_thread_complete then
			material_adapter.on_thread_complete("wind", {story_owned = true})
		end
		save.elses[key("reward_done")] = true
		save.elses.Zennith_end = true
	end
	M.set_phase(PHASE.COMPLETED)
	arena_visual.notify_battle_ended()
	return true
end

function M.notify_boss_aborted()
	boss_wind.clear()
	return true
end

function M.tick()
	local phase = M.get_phase()
	if phase == PHASE.SEARCHING or phase == PHASE.BATTLE or phase == PHASE.COMPLETED or phase == PHASE.FAILED then
		return
	end
	bump_phase_frame()
	save.elses[key("timer")] = (tonumber(save.elses[key("timer")]) or 0) + 1
	local t = tonumber(save.elses[key("timer")]) or 0
	local room = Game():GetRoom()
	local center = room:GetCenterPos()
	local pf = M.get_phase_frame()

	if phase == PHASE.EYE_DISCOVERED then
		M.set_phase(PHASE.EYE_FORMING)
		env_wind.update_room({
			distance = 0, mode = 2, pos = center, intensity = 0.6,
			phase = "eye", eye_radius_scale = 0.4,
		})
	elseif phase == PHASE.EYE_FORMING then
		local intensity = 0.55 + math.min(0.25, t / BEAT.form_end * 0.25)
		local growth = math.min(1, t / BEAT.form_end)
		env_wind.update_room({
			distance = 0, mode = 2, pos = center, intensity = intensity,
			phase = "eye", eye_radius_scale = math.max(0.2, growth),
		})
		if tornado.is_active() then
			tornado.set_external_compose(true)
			tornado.set_mode("forming")
			tornado.set_growth(growth)
			tornado.set_intensity(intensity)
			tornado.set_spread(0)
		end
		if t >= BEAT.form_end then
			M.set_phase(PHASE.ZENNITH_REVEAL)
			local top = tornado.get_top_anchor() or Vector(center.X, center.Y - 160)
			local base = tornado.get_base_anchor() or center
			if tornado.is_active() then
				tornado.set_mode("opening")
				tornado.set_growth(1)
				tornado.set_spread(0.14)
			end
			-- Tip silhouette only — hover before any fall.
			arrival.begin(center, {
				top_anchor = top,
				base_anchor = base,
				occlusion = 0.3,
				hover_frames = BEAT.reveal,
			})
		end
	elseif phase == PHASE.ZENNITH_REVEAL then
		arrival.update()
		env_wind.update_room({
			distance = 0, mode = 2, pos = center, intensity = 0.78,
			phase = "eye", eye_radius_scale = 1.0,
		})
		if tornado.is_active() then
			tornado.set_external_compose(true)
			tornado.set_mode("opening")
			tornado.set_growth(1)
			tornado.set_intensity(0.85)
			tornado.set_spread(0.14 + 0.04 * math.min(1, pf / BEAT.reveal))
		end
		sync_arrival_column()
		local shown = arrival.get_phase()
		if shown ~= "hover" and shown ~= "idle" then
			M.set_phase(PHASE.ZENNITH_DESCENDING)
			if tornado.is_active() then
				tornado.set_mode("looping")
			end
		end
	elseif phase == PHASE.ZENNITH_DESCENDING then
		arrival.update()
		env_wind.update_room({
			distance = 0, mode = 2, pos = center, intensity = 0.8,
			phase = "eye", eye_radius_scale = 1.0,
		})
		if tornado.is_active() then
			tornado.set_external_compose(true)
			tornado.set_mode("looping")
			tornado.set_growth(1)
			tornado.set_intensity(0.9)
			tornado.set_spread(0.16)
		end
		sync_arrival_column()
		local shown = arrival.get_phase()
		tick_arrival_gust(shown)
		if shown == "impact_cover" or shown == "done" or arrival.is_screen_covered() then
			tornado.clear()
			M.set_phase(PHASE.IMPACT)
		end
	elseif phase == PHASE.IMPACT then
		arrival.update()
		tick_arrival_gust(arrival.get_phase())
		if arrival.is_screen_covered() or arrival.is_finished() then
			gust.clear()
			begin_white_hold()
			arrival.release_actor()
			M.set_phase(PHASE.COVER_IN)
		end
	elseif phase == PHASE.COVER_IN then
		begin_white_hold()
		arrival.release_actor()
		gust.clear()
		if tornado.is_active() then
			tornado.set_mode("collapsing")
		end
		if pf >= 4 then
			tornado.clear()
			local visual = require("Qing_Remaster_scripts.threads.wind.wind_visual")
			if visual.clear_impact then visual.clear_impact() end
			M.set_phase(PHASE.COVERED)
		end
	elseif phase == PHASE.COVERED then
		begin_white_hold()
		tornado.clear()
		local visual = require("Qing_Remaster_scripts.threads.wind.wind_visual")
		if visual.clear_impact then visual.clear_impact() end
		if not M.get_arena_sgid() then
			prepare_arena()
		else
			M.set_phase(PHASE.ARENA_PREPARED)
		end
	elseif phase == PHASE.ARENA_PREPARED then
		begin_white_hold()
		arrival.release_actor()
		request_transfer()
	elseif phase == PHASE.TRANSFER_REQUESTED or phase == PHASE.ARENA_LOADING then
		begin_white_hold()
		arrival.release_actor()
		-- Fail-safe: do not leave the player under permanent cover.
		if pf >= BEAT.arena_wait_warn then
			local room_ok = select(1, arena_room.validate_current())
			if room_ok then
				M.enter_arena_battle()
			elseif pf >= BEAT.arena_wait_fail then
				fail("arena_timeout")
			else
				save.elses[key("last_error")] = "waiting_arena:timeout_pending"
			end
		end
	elseif phase == PHASE.ARENA_CONFIRMED then
		begin_white_hold()
		arrival.release_actor()
		local entered = M.enter_arena_battle()
		if not entered and pf >= BEAT.arena_wait_fail then
			fail("arena_boss_or_visual_timeout")
		end
	elseif phase == PHASE.COVER_OUT then
		local boss = find_living_boss()
		if not auxi.check_all_exists(boss) then
			M.enter_arena_battle()
			boss = find_living_boss()
		end
		if auxi.check_all_exists(boss) then
			runtime().boss = boss
			lock_boss_intro(boss, true)
		end
		local st = cover_state()
		if save.elses[key("ready_for_reveal")] ~= true and st ~= "fade" and st ~= "released" then
			local arena_ok = select(1, arena_room.validate_current()) == true
			local visual_ready = arena_visual.is_ready()
			if not visual_ready then
				arena_visual.ensure_ready()
				visual_ready = arena_visual.is_ready()
			end
			local bosses = arrival.count_real_boss()
			local locked = boss and Zennith.is_intro_locked and Zennith.is_intro_locked(boss) == true
			if arena_ok and visual_ready and locked and bosses == 1 then
				save.elses[key("ready_for_reveal")] = true
				save.elses[key("cover_block")] = nil
			else
				local block = string.format(
					"cover_blocked:arena_ok=%s,visual_ready=%s,boss_locked=%s,boss_count=%s",
					tostring(arena_ok), tostring(visual_ready), tostring(locked), tostring(bosses)
				)
				save.elses[key("cover_block")] = block
				save.elses[key("last_error")] = block
				begin_white_hold()
				local waited = (tonumber(save.elses[key("visual_wait")]) or 0) + 1
				save.elses[key("visual_wait")] = waited
				if waited >= BEAT.arena_wait_fail then
					fail("arena_visual_timeout")
				end
				return
			end
		end
		if st == "released" then
			return
		end
		if cover_state() ~= "fade" then
			begin_white_fade()
		end
		local ff = (tonumber(save.elses[key("fade_frame")]) or 0) + 1
		save.elses[key("fade_frame")] = ff
		local a = math.max(0, 1 - ff / BEAT.cover_out)
		set_cover(a)
		if ff >= BEAT.cover_out or a <= 0.02 then
			release_cover()
			arrival.clear()
			gust.clear()
			M.set_phase(PHASE.INTRO_LOCKED)
		end
	elseif phase == PHASE.INTRO_LOCKED then
		release_cover()
		local boss = find_living_boss()
		if not auxi.check_all_exists(boss) then
			if M.boss_encounter_settled() then
				M.set_phase(PHASE.COMPLETED)
				arena_visual.notify_battle_ended()
			else
				M.enter_arena_battle()
			end
			return
		end
		runtime().boss = boss
		lock_boss_intro(boss, true)
		if pf >= BEAT.intro_lock then
			lock_boss_intro(boss, false)
			M.set_phase(PHASE.BATTLE)
		end
	end
end

function M.on_new_room()
	local ok_runner, test_runner = pcall(require, "Qing_Remaster_scripts.threads.wind.wind_test_runner")
	if ok_runner and test_runner and test_runner.on_room then
		test_runner.on_room()
	end
	local phase = M.get_phase()
	local in_arena = select(1, arena_room.validate_current())
	if M._direct_battle then
		if M._direct_token == nil or M._direct_token ~= M._test_request then
			M._direct_battle = nil
		else
			if in_arena then
				local opened = select(1, M.open_battle_now())
				if opened then
					M._direct_battle = nil
				end
			end
			return
		end
	end
	if in_arena then
		arrival.release_actor()
		gust.clear()
	end
	if not in_arena then
		if arena_visual.is_active() then
			arena_visual.shutdown()
		end
		if phase == PHASE.ARENA_LOADING or phase == PHASE.TRANSFER_REQUESTED or phase == PHASE.ARENA_PREPARED then
			local _, why = arena_room.validate_current()
			save.elses[key("last_error")] = "waiting_arena:" .. tostring(why)
		end
		return
	end
	if phase == PHASE.ARENA_LOADING or phase == PHASE.TRANSFER_REQUESTED
		or phase == PHASE.ARENA_PREPARED or phase == PHASE.ARENA_CONFIRMED then
		M.enter_arena_battle()
		return
	end
	if phase == PHASE.COVER_OUT or phase == PHASE.INTRO_LOCKED then
		local boss = find_living_boss()
		if boss then
			runtime().boss = boss
			lock_boss_intro(boss, true)
			arena_visual.ensure_ready()
		elseif M.boss_encounter_settled() then
			release_cover()
			M.set_phase(PHASE.COMPLETED)
			arena_visual.notify_battle_ended()
		else
			M.enter_arena_battle()
		end
		return
	end
	if phase == PHASE.BATTLE then
		local boss = find_living_boss()
		if not boss and not M.boss_encounter_settled() then
			local spawned = false
			boss, spawned = Zennith.start_(Game():GetRoom():GetCenterPos())
			tag_test_boss(boss, spawned == true)
		end
		if auxi.check_all_exists(boss) then
			runtime().boss = boss
			save.elses[key("boss_spawned")] = true
			boss_wind.set_vortex({ent = boss, delta_pos = Vector(0, -20), intensity = 0.55})
		end
		arena_visual.ensure_ready()
		return
	end
	if phase == PHASE.COMPLETED then
		arena_visual.ensure_ready()
		arena_visual.notify_battle_ended()
	end
end

function M.should_start_discovery(sgid)
	if not save.elses["thread_wind_spawn"] then return false end
	if M.is_arena_room(sgid) then return false end
	if save.elses["Zennith_room"] ~= sgid then return false end
	if save.elses[key("boss_spawned")] then return false end
	return M.get_phase() == PHASE.SEARCHING
end

function M.test_prepare_eye()
	M.clear()
	save.elses["thread_wind_spawn"] = true
	M.mark_story_owned(true)
	M.set_phase(PHASE.SEARCHING)
	return M.begin_eye_discovery()
end

function M.test_play_eye()
	local ok, err = M.test_prepare_eye()
	if not ok then return false, err end
	M.set_phase(PHASE.EYE_FORMING)
	save.elses[key("timer")] = 0
	return true
end

function M.test_play_reveal()
	local ok, err = M.test_prepare_eye()
	if not ok then return false, err end
	local center = Game():GetRoom():GetCenterPos()
	env_wind.begin_room({
		distance = 0, mode = 2, pos = center, intensity = 0.75,
		phase = "eye", eye_radius_scale = 1,
	})
	tornado.begin(center, {growth = 1, intensity = 0.85})
	tornado.set_external_compose(true)
	tornado.set_mode("opening")
	tornado.set_spread(0.14)
	M.set_phase(PHASE.ZENNITH_REVEAL)
	arrival.begin(center, {
		top_anchor = tornado.get_top_anchor(),
		base_anchor = tornado.get_base_anchor() or center,
		hover_frames = BEAT.reveal,
	})
	save.elses[key("timer")] = BEAT.form_end
	return true
end

local function begin_flight(start_phase, encounter_phase)
	local ok, err = M.test_prepare_eye()
	if not ok then return false, err end
	local center = Game():GetRoom():GetCenterPos()
	env_wind.begin_room({
		distance = 0, mode = 2, pos = center, intensity = 0.75,
		phase = "eye", eye_radius_scale = 1,
	})
	tornado.begin(center, {growth = 1, intensity = 0.85})
	tornado.set_external_compose(true)
	tornado.set_mode("looping")
	arrival.begin(center, {
		top_anchor = tornado.get_top_anchor(),
		base_anchor = tornado.get_base_anchor() or center,
		start_phase = start_phase,
		hover_frames = BEAT.reveal,
	})
	sync_arrival_column()
	M.set_phase(encounter_phase)
	save.elses[key("timer")] = BEAT.form_end
	return true
end

function M.test_play_descent()
	return begin_flight("wind_surge", PHASE.ZENNITH_DESCENDING)
end

function M.test_play_ascend()
	return begin_flight("ascend", PHASE.ZENNITH_DESCENDING)
end

function M.test_play_dive()
	local ok, err = begin_flight("dive", PHASE.ZENNITH_DESCENDING)
	if not ok then return false, err end
	gust.begin()
	for _ = 1, 36 do
		gust.update()
	end
	return true
end

function M.test_play_impact()
	return begin_flight("impact_cover", PHASE.IMPACT)
end

--- Solid white burst only. Does not spawn the old ring impact.
function M.test_impact_burst_only()
	local center = Game():GetRoom():GetCenterPos()
	arrival.begin(center, {start_phase = "impact_cover"})
	M.set_phase(PHASE.IMPACT)
	return true
end

function M.test_play_transfer()
	local ok, err = M.test_prepare_eye()
	if not ok then return false, err end
	begin_white_hold()
	arrival.release_actor()
	M.set_phase(PHASE.COVERED)
	return prepare_arena()
end

function M.test_play_full_sequence()
	return M.test_prepare_eye()
end

function M.get_diagnostics()
	local cfg, cfg_reason = arena_room.lookup_config()
	local cfg_ok = cfg ~= nil and select(1, arena_room.validate_config(cfg))
	local room_ok = select(1, arena_room.validate_current())
	local st = wind.get_state()
	return {
		phase = M.get_phase(),
		phase_frame = M.get_phase_frame(),
		eye_sgid = save.elses[key("eye_sgid")],
		arena_sgid = M.get_arena_sgid(),
		arena_config_valid = cfg_ok == true,
		arena_config_reason = cfg_reason,
		room_identity_valid = room_ok == true,
		arrival_visual_active = arrival.is_active(),
		arrival_phase = arrival.get_phase(),
		arrival_surge = arrival.get_surge and arrival.get_surge() or 1,
		real_boss_count = arrival.count_real_boss(),
		duplicate_error = Zennith.duplicate_error,
		boss_intro_locked = (runtime().boss and Zennith.is_intro_locked and Zennith.is_intro_locked(runtime().boss)) or false,
		tornado_mode = tornado.mode,
		tornado_external_compose = tornado.external_compose == true,
		wind_visual_mode = st.phase,
		session_generation = st.session_generation,
		particle_reset_count = st.particle_reset_count,
		last_reset_reason = st.last_reset_reason,
		cover_alpha = M.get_cover_alpha(),
		cover_state = cover_state(),
		cover_draw_enabled = M.cover_draw_enabled(),
		fade_frame = tonumber(save.elses[key("fade_frame")]) or 0,
		ready_for_reveal = save.elses[key("ready_for_reveal")] == true,
		cover_block = save.elses[key("cover_block")],
		cover_render_calls = M._cover_draw_trace and M._cover_draw_trace.calls or 0,
		cover_render_hits = M._cover_draw_trace and M._cover_draw_trace.rendered or 0,
		cover_last_rendered = M._cover_draw_trace and M._cover_draw_trace.last_rendered == true,
		arena_ok = room_ok == true,
		boss_locked = (runtime().boss and Zennith.is_intro_locked and Zennith.is_intro_locked(runtime().boss)) or false,
		gust_alive = gust.alive_count(),
		arena_visual_ready = arena_visual.is_ready(),
		arena_visual_error = arena_visual.get_last_error(),
		arena_black_draws = arena_visual.get_diagnostics and arena_visual.get_diagnostics().black_draws or 0,
		arena_render_back = arena_visual.get_diagnostics and arena_visual.get_diagnostics().render_back or "-",
		arena_render_front = arena_visual.get_diagnostics and arena_visual.get_diagnostics().render_front or "-",
		arena_sprites = arena_visual.get_diagnostics and arena_visual.get_diagnostics().sprites_loaded or 0,
		arena_bolt = arena_visual.get_diagnostics and arena_visual.get_diagnostics().bolt or "-",
		arena_thunder_id = arena_visual.get_diagnostics and arena_visual.get_diagnostics().thunder_id or -1,
		arena_thunder_played = arena_visual.get_diagnostics and arena_visual.get_diagnostics().thunder_played or false,
		arena_thunder_volume = arena_visual.get_diagnostics and arena_visual.get_diagnostics().thunder_volume or 0,
		arena_thunder_replaced = arena_visual.get_diagnostics and arena_visual.get_diagnostics().thunder_replaced or false,
		arena_thunder_skipped = arena_visual.get_diagnostics and arena_visual.get_diagnostics().thunder_skipped or "-",
		arena_render_carrier = arena_visual.get_diagnostics and arena_visual.get_diagnostics().render_carrier or false,
		arena_art_effects = arena_visual.get_diagnostics and (arena_visual.get_diagnostics().art_effects) or 0,
		arena_backdrop_carriers = arena_visual.get_diagnostics and (arena_visual.get_diagnostics().backdrop_carriers) or 0,
		transfer_request_id = save.elses[key("transfer_request_id")],
		story_owned = M.is_story_owned(),
		reward_done = save.elses[key("reward_done")] == true,
		last_error = save.elses[key("last_error")] or M.last_error,
	}
end

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		local ok_runner, test_runner = pcall(require, "Qing_Remaster_scripts.threads.wind.wind_test_runner")
		if ok_runner and test_runner and test_runner.tick then
			test_runner.tick()
		end
		arena_visual.update()
		local phase = M.get_phase()
		if phase == PHASE.SEARCHING or phase == PHASE.BATTLE or phase == PHASE.COMPLETED or phase == PHASE.FAILED then
			return
		end
		M.tick()
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		M.on_new_room()
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_RENDER,
	params = nil,
	Function = function()
		-- Explicit compose (independent of wind_runtime callback order):
		-- TornadoBack/Core → Zennith Arrival → TornadoFront.
		-- Peripheral streaks/motes stay in wind_runtime (external_compose skips tornado there).
		local phase = M.get_phase()
		local composing = phase == PHASE.EYE_FORMING
			or phase == PHASE.ZENNITH_REVEAL
			or phase == PHASE.ZENNITH_DESCENDING
			or phase == PHASE.IMPACT
			or phase == PHASE.COVER_IN
		local in_arena = M.is_arena_room()
		local diving = arrival.get_phase() == "dive"
		if composing and not in_arena and tornado.is_active() and tornado_layer_enabled() then
			tornado.set_external_compose(true)
			tornado.render_back()
			tornado.render_core()
		end
		if not in_arena and not diving and arrival.should_draw_actor and arrival.should_draw_actor() then
			arrival.render()
		end
		if composing and not in_arena and tornado.is_active() and tornado_layer_enabled() then
			tornado.render_front()
		end
		if not in_arena and gust.is_active() then
			gust.render()
		end
		if not in_arena and diving and arrival.should_draw_actor and arrival.should_draw_actor() then
			arrival.render()
		end
		if arrival.render_burst and arrival.get_phase() == "impact_cover" then
			arrival.render_burst()
		end
		local trace = M._cover_draw_trace or {calls = 0, rendered = 0, last_alpha = 0, last_rendered = false}
		M._cover_draw_trace = trace
		trace.calls = trace.calls + 1
		local cover = M.get_cover_alpha()
		trace.last_alpha = cover
		local drew = false
		if M.cover_draw_enabled() and cover > 0.01 and arrival.render_solid then
			drew = arrival.render_solid(cover) == true
		end
		trace.last_rendered = drew
		if drew then
			trace.rendered = trace.rendered + 1
		end
	end,
})

if ModCallbacks.MC_PRE_GRID_ENTITY_DECORATION_RENDER then
	table.insert(M.ToCall, #M.ToCall + 1, {
		CallBack = ModCallbacks.MC_PRE_GRID_ENTITY_DECORATION_RENDER,
		params = nil,
		Function = function(_, _decoration, _offset)
			if select(1, arena_room.validate_current()) == true then
				return false
			end
		end,
	})
end

if ModCallbacks.MC_POST_EFFECT_RENDER and enums.Entities.Arena_Render_Anchor then
	table.insert(M.ToCall, #M.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_EFFECT_RENDER,
		params = enums.Entities.Arena_Render_Anchor,
		Function = function(_, effect)
			if arena_visual.is_anchor and arena_visual.is_anchor(effect) then
				arena_visual.render_background()
			end
		end,
	})
end

if ModCallbacks.MC_POST_ROOM_RENDER_ENTITIES then
	table.insert(M.ToCall, #M.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_ROOM_RENDER_ENTITIES,
		params = nil,
		Function = function()
			if arena_visual.render_foreground then
				arena_visual.render_foreground()
			end
		end,
	})
end

table.insert(M.myToCall, #M.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_LEVEL,
	params = nil,
	Function = function()
		M.clear()
		M.clear_story_flags()
	end,
})

return M
