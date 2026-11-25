-- Floraine opening camera: thin Boss-local focus owner (RGON Camera:SetFocusPosition).
-- Timeline: HOLD_FORMATION → PAN_TO_BOSS → HOLD_BOSS → RELEASE_WAIT → RELEASE → idle.
-- Lifecycle owned by floraine_v2/controller. Must apply every update frame while active.

local arena = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.arena")
local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")

local cam = {}

local PHASE = {
	IDLE = "IDLE",
	HOLD_FORMATION = "HOLD_FORMATION",
	PAN_TO_BOSS = "PAN_TO_BOSS",
	HOLD_BOSS = "HOLD_BOSS",
	RELEASE_WAIT = "RELEASE_WAIT", -- linger on Boss after command launch
	RELEASE = "RELEASE",
}

local function cam_cfg()
	return defs.OPENING_CAMERA or {}
end

local function pan_up_frames()
	return math.max(1, tonumber(cam_cfg().PAN_UP_FRAMES) or 27)
end

local function boss_hold_frames()
	return math.max(0, tonumber(cam_cfg().BOSS_HOLD_FRAMES) or 10)
end

local function release_delay_frames()
	return math.max(0, tonumber(cam_cfg().RELEASE_DELAY_FRAMES) or 15)
end

local function release_frames()
	return math.max(1, tonumber(cam_cfg().RELEASE_FRAMES) or 40)
end


local state = {
	active = false,
	phase = PHASE.IDLE,
	elapsed = 0,
	phase_elapsed = 0,
	formation_focus = nil,
	boss_focus = nil,
	pan_from = nil,
	token = 0,
}

local function room_camera()
	local room = Game():GetRoom()
	if not room or not room.GetCamera then
		return nil
	end
	local ok, camera = pcall(function()
		return room:GetCamera()
	end)
	if ok then
		return camera
	end
	return nil
end

local function player_focus()
	local p = Isaac.GetPlayer(0)
	if p and p.Position then
		return Vector(p.Position.X, p.Position.Y)
	end
	return nil
end

local function boss_focus_from(boss_ent)
	if boss_ent and boss_ent.Position then
		-- Slightly below head so staff tip / command launch stay readable.
		return Vector(boss_ent.Position.X, boss_ent.Position.Y + 12)
	end
	local home = arena.boss_spawn_pos and arena.boss_spawn_pos()
	if home then
		return Vector(home.X, home.Y + 12)
	end
	return nil
end

local function ease(t)
	t = math.max(0, math.min(1, t))
	return t * t * (3 - 2 * t)
end

local function lerp_vec(a, b, t)
	if not a then
		return b
	end
	if not b then
		return a
	end
	return a * (1 - t) + b * t
end

function cam.is_active()
	return state.active == true
end

function cam.get_phase()
	return state.phase
end

--- True after pan-up + short Boss hold — safe to start Raise once.
function cam.is_ready_for_command()
	return state.active == true and state.phase == PHASE.HOLD_BOSS
		and (state.phase_elapsed or 0) >= boss_hold_frames()
end

function cam.get_diag()
	return {
		active = state.active,
		phase = state.phase,
		elapsed = state.elapsed,
		phase_elapsed = state.phase_elapsed,
		token = state.token,
		has_formation = state.formation_focus ~= nil,
		has_boss = state.boss_focus ~= nil,
		ready_for_command = cam.is_ready_for_command(),
		pan_up_frames = pan_up_frames(),
		boss_hold_frames = boss_hold_frames(),
		release_delay_frames = release_delay_frames(),
		release_frames = release_frames(),

	}
end

--- Stage A: lock on reserve formation center while pieces march in.
function cam.begin_formation(focus)
	if not focus or not focus.X then
		return false, "no_formation_focus"
	end
	state.active = true
	state.phase = PHASE.HOLD_FORMATION
	state.elapsed = 0
	state.phase_elapsed = 0
	state.formation_focus = Vector(focus.X, focus.Y)
	state.boss_focus = nil
	state.pan_from = nil
	state.token = (state.token or 0) + 1
	return true
end

--- Stage B: smooth pan from current/formation focus to Boss.
function cam.begin_pan_to_boss(boss_ent)
	local focus = boss_focus_from(boss_ent)
	if not focus then
		return false, "no_focus"
	end
	state.active = true
	state.boss_focus = focus
	if state.formation_focus then
		state.pan_from = Vector(state.formation_focus.X, state.formation_focus.Y)
	else
		state.pan_from = Vector(focus.X, focus.Y)
	end
	state.phase = PHASE.PAN_TO_BOSS
	state.phase_elapsed = 0
	state.token = (state.token or 0) + 1
	return true
end


--- Legacy alias: jump straight to Boss hold (debug / fallback).
function cam.begin(boss_ent)
	local focus = boss_focus_from(boss_ent)
	if not focus then
		return false, "no_focus"
	end
	state.active = true
	state.phase = PHASE.HOLD_BOSS
	state.elapsed = 0
	state.phase_elapsed = 0
	state.boss_focus = focus
	state.formation_focus = state.formation_focus
	state.pan_from = nil
	state.token = (state.token or 0) + 1
	return true
end

--- Stage D: after launch, linger on Boss then soft-release toward player.
function cam.notify_command_launched()
	if not state.active then
		return false
	end
	if state.phase == PHASE.RELEASE or state.phase == PHASE.RELEASE_WAIT then
		return true
	end
	local delay = release_delay_frames()
	if delay <= 0 then
		state.phase = PHASE.RELEASE
	else
		state.phase = PHASE.RELEASE_WAIT
	end
	state.phase_elapsed = 0
	return true
end


--- Hard stop (combat start / leave / death / debug skip).
function cam.release(reason)
	state.active = false
	state.phase = PHASE.IDLE
	state.elapsed = 0
	state.phase_elapsed = 0
	state.formation_focus = nil
	state.boss_focus = nil
	state.pan_from = nil
	return true, reason or "released"
end

function cam.clear(reason)
	return cam.release(reason or "clear")
end

local function current_focus()
	if state.phase == PHASE.HOLD_FORMATION then
		return state.formation_focus
	end
	if state.phase == PHASE.PAN_TO_BOSS then
		local t = ease((state.phase_elapsed or 0) / pan_up_frames())
		return lerp_vec(state.pan_from or state.formation_focus, state.boss_focus, t)
	end
	if state.phase == PHASE.HOLD_BOSS or state.phase == PHASE.RELEASE_WAIT then
		return state.boss_focus
	end
	if state.phase == PHASE.RELEASE then
		local p = player_focus() or state.boss_focus
		local t = ease((state.phase_elapsed or 0) / release_frames())
		return lerp_vec(state.boss_focus, p, t)
	end
	return nil
end


--- Apply SetFocusPosition. Call every MC_POST_UPDATE while active (RGON contract).
function cam.apply()
	if not state.active then
		return false
	end
	local camera = room_camera()
	if not camera or not camera.SetFocusPosition then
		return false
	end
	local focus = current_focus()
	if not focus then
		return false
	end
	camera:SetFocusPosition(focus)
	return true
end

--- Advance timeline. Call from Boss update.
function cam.tick(boss_ent)
	if not state.active then
		return
	end
	state.elapsed = (state.elapsed or 0) + 1
	state.phase_elapsed = (state.phase_elapsed or 0) + 1

	if boss_ent and boss_ent.Exists and boss_ent:Exists() and not (boss_ent.IsDead and boss_ent:IsDead()) then
		if state.phase == PHASE.HOLD_BOSS
			or state.phase == PHASE.PAN_TO_BOSS
			or state.phase == PHASE.RELEASE_WAIT
			or state.phase == PHASE.RELEASE then
			state.boss_focus = boss_focus_from(boss_ent) or state.boss_focus
		end
	else
		cam.release("boss_gone")
		return
	end

	if state.phase == PHASE.PAN_TO_BOSS then
		if (state.phase_elapsed or 0) >= pan_up_frames() then
			state.phase = PHASE.HOLD_BOSS
			state.phase_elapsed = 0
		end
	elseif state.phase == PHASE.RELEASE_WAIT then
		if (state.phase_elapsed or 0) >= release_delay_frames() then
			state.phase = PHASE.RELEASE
			state.phase_elapsed = 0
		end
	elseif state.phase == PHASE.RELEASE then
		if (state.phase_elapsed or 0) >= release_frames() then
			cam.release("release_done")
		end
	end
end


--- Debug: formation → pan → hold → release without restarting the whole opening.
function cam.replay(boss_ent)
	local ok_r, reserve = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_controller")
	local focus = nil
	if ok_r and reserve and reserve.formation_focus then
		focus = reserve.formation_focus()
	end
	if focus then
		cam.begin_formation(focus)
	else
		local ok, why = cam.begin(boss_ent)
		if not ok then
			return false, why
		end
	end
	state._replay_pan_at = state.elapsed + 12
	state._replay_boss_ent = boss_ent
	return true, "replay_started"
end

function cam.tick_replay_auto()
	if not state.active then
		return
	end
	local pan_at = state._replay_pan_at
	if pan_at and state.elapsed >= pan_at and state.phase == PHASE.HOLD_FORMATION then
		state._replay_pan_at = nil
		cam.begin_pan_to_boss(state._replay_boss_ent)
		state._replay_release_at = state.elapsed
			+ pan_up_frames()
			+ boss_hold_frames()
			+ release_delay_frames()
			+ 8
	end
	local at = state._replay_release_at
	if at and state.elapsed >= at then
		state._replay_release_at = nil
		cam.notify_command_launched()
	end
end


cam.PHASE = PHASE

return cam
