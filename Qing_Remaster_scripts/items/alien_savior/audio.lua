-- Alien Savior V1 SFX: SOS + UFO arrival/hover. Dedicated SFXManager for hover fade/stop.
local enums = require("Qing_Remaster_scripts.core.enums")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local C = require("Qing_Remaster_scripts.items.alien_savior.constants")

local A = {}

local sfx = SFXManager()
local warned = {}
local hover_active = false
local hover_fading = false
local hover_fade_left = 0
local hover_vol_current = 0
local hover_armed = false
local hover_start_at = nil
local arrival_playing = false
local tech_sec_sfx_cd = 0

local function tech_laser_sfx_id()
	-- Vanilla Technology fire: SoundEffect.SOUND_HAND_LASERS (211).
	if SoundEffect and SoundEffect.SOUND_HAND_LASERS then
		return SoundEffect.SOUND_HAND_LASERS
	end
	return 211
end

local function sid(key)
	local id = enums.SoundEffect and enums.SoundEffect[key]
	if type(id) ~= "number" or id < 0 then
		if not warned[key] then
			warned[key] = true
			print("[AlienSavior][SFX] missing sound id: " .. tostring(key) .. " (check sounds.xml / GetSoundIdByName)")
		end
		return nil
	end
	return id
end

local function play_oneshot(key, vol)
	local id = sid(key)
	if not id then
		return false
	end
	sound_tracker.PlayStackedSound(id, vol or 1, 1, false, 0, 2)
	return true
end

function A.play_sos_search()
	return play_oneshot("Alien_Savior_SOS_Search", C.SFX.SOS_SEARCH_VOL)
end

function A.play_sos_connected()
	return play_oneshot("Alien_Savior_SOS_Connected", C.SFX.SOS_CONNECTED_VOL)
end

function A.play_ufo_arrival()
	local id = sid("Alien_Savior_UFO_Arrival")
	if not id then
		return false
	end
	-- Dedicated manager so we can Stop this ID without touching stacked one-shots of other events.
	sfx:Play(id, C.SFX.UFO_ARRIVAL_VOL, 0, false, 1, 0)
	arrival_playing = true
	return true
end

local function stop_arrival()
	local id = sid("Alien_Savior_UFO_Arrival")
	if id and (arrival_playing or sfx:IsPlaying(id)) then
		sfx:Stop(id)
	end
	arrival_playing = false
end

local function stop_hover_now()
	local id = sid("Alien_Savior_UFO_Hover")
	if id and (hover_active or sfx:IsPlaying(id)) then
		sfx:Stop(id)
	end
	hover_active = false
	hover_fading = false
	hover_fade_left = 0
	hover_vol_current = 0
end

function A.start_hover()
	if hover_active or hover_fading then
		return false
	end
	local id = sid("Alien_Savior_UFO_Hover")
	if not id then
		return false
	end
	hover_vol_current = C.SFX.UFO_HOVER_VOL
	sfx:Play(id, hover_vol_current, 0, false, 1, 0)
	hover_active = true
	hover_fading = false
	return true
end

function A.begin_hover_fade()
	if not hover_active then
		hover_fading = false
		return
	end
	if hover_fading then
		return
	end
	hover_fading = true
	hover_fade_left = C.SFX.HOVER_FADE_FRAMES
end

--- Call once when a rescue transaction successfully starts.
function A.on_rescue_started()
	A.play_sos_connected()
	A.play_ufo_arrival()
	hover_armed = true
	hover_start_at = (Game():GetFrameCount() or 0) + (C.SFX.HOVER_START_DELAY or 45)
end

--- 30Hz tick from controller while a rescue is active.
function A.on_update(txn)
	if hover_armed and hover_start_at and not hover_active and not hover_fading then
		local now = Game():GetFrameCount() or 0
		if now >= hover_start_at then
			A.start_hover()
			hover_start_at = nil
		end
	end

	if hover_fading and hover_active then
		hover_fade_left = (hover_fade_left or 0) - 1
		local id = sid("Alien_Savior_UFO_Hover")
		local total = math.max(1, C.SFX.HOVER_FADE_FRAMES)
		local t = math.max(0, hover_fade_left) / total
		hover_vol_current = C.SFX.UFO_HOVER_VOL * t
		if id and sfx.AdjustVolume then
			sfx:AdjustVolume(id, hover_vol_current)
		end
		if hover_fade_left <= 0 then
			stop_hover_now()
		end
	end

	-- Phase cues: release / depart start fade-out.
	if txn then
		if txn.phase == C.PHASE.RELEASE_PLAYER or txn.phase == C.PHASE.DEPARTING then
			A.begin_hover_fade()
		end
	end
end

--- Abort / room exit / finish: stop managed UFO beds without touching unrelated SFX stacks.
function A.stop_all(opts)
	opts = opts or {}
	hover_armed = false
	hover_start_at = nil
	if opts.fade_hover and hover_active then
		A.begin_hover_fade()
	else
		stop_hover_now()
	end
	if opts.keep_arrival ~= true then
		stop_arrival()
	end
end

--- Main cone volley: one Technology fire SFX at extend start (not per-beam).
function A.play_tech_laser_main()
	local id = tech_laser_sfx_id()
	local vol = (C.SFX and C.SFX.TECH_LASER_MAIN_VOL) or 0.8
	sound_tracker.PlayStackedSound(id, vol, 1, false, 0, 2)
	return true
end

--- Secondary lamp fire: shared throttle so multi-lamp frames do not stack.
function A.tick_tech_laser_sfx()
	if tech_sec_sfx_cd > 0 then
		tech_sec_sfx_cd = tech_sec_sfx_cd - 1
	end
end

function A.play_tech_laser_secondary()
	local cd = (C.SFX and C.SFX.TECH_LASER_SEC_COOLDOWN) or 6
	if tech_sec_sfx_cd > 0 then
		return false
	end
	tech_sec_sfx_cd = cd
	local id = tech_laser_sfx_id()
	local vol = (C.SFX and C.SFX.TECH_LASER_SEC_VOL) or 0.4
	sound_tracker.PlayStackedSound(id, vol, 1, false, 0, 2)
	return true
end

function A.reset_tech_laser_sfx()
	tech_sec_sfx_cd = 0
end

function A.probe_play(which)
	if which == "search" then
		return A.play_sos_search()
	elseif which == "connected" then
		return A.play_sos_connected()
	elseif which == "arrival" then
		return A.play_ufo_arrival()
	elseif which == "hover" then
		return A.start_hover()
	elseif which == "tech_main" then
		return A.play_tech_laser_main()
	elseif which == "tech_sec" then
		tech_sec_sfx_cd = 0
		return A.play_tech_laser_secondary()
	end
	return false
end

function A.probe_stop()
	A.stop_all({ fade_hover = false })
end

function A.summary()
	return string.format(
		"hover=%s fade=%s armed=%s start_at=%s",
		tostring(hover_active),
		tostring(hover_fading),
		tostring(hover_armed),
		tostring(hover_start_at)
	)
end

return A
