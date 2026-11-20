-- Single owner of Alien Savior UFO rescue timeline.
local C = require("Qing_Remaster_scripts.items.alien_savior.constants")
local state = require("Qing_Remaster_scripts.items.alien_savior.state")
local ops = require("Qing_Remaster_scripts.items.alien_savior.ops")
local visual = require("Qing_Remaster_scripts.items.alien_savior.visual")
local audio = require("Qing_Remaster_scripts.items.alien_savior.audio")
local lights = require("Qing_Remaster_scripts.items.alien_savior.light_controller")
local motion = require("Qing_Remaster_scripts.items.alien_savior.motion")
local beam = require("Qing_Remaster_scripts.items.alien_savior.beam")
local suction = require("Qing_Remaster_scripts.items.alien_savior.suction")
local laser_ctrl = require("Qing_Remaster_scripts.items.alien_savior.laser_controller")
local g = require("Qing_Remaster_scripts.core.globals")

local Ctrl = {}

local active = nil
local next_id = 1
local last_cancel = "none"
local log_note = "idle"

local PHASE_ORDER = {
	C.PHASE.ARRIVING,
	C.PHASE.ABDUCT_PLAYER,
	C.PHASE.TRANSIT_TO_CENTER,
	C.PHASE.ABDUCT_TARGETS,
	C.PHASE.LASER_SWEEP,
	C.PHASE.RELEASE_PLAYER,
	C.PHASE.DEPARTING,
}

local function dur_of(phase)
	return C.DUR[phase] or 15
end

local function exit_phase(txn, phase, reason)
	if not txn or not phase then
		return
	end
	if phase == C.PHASE.ABDUCT_TARGETS then
		-- Normal advance settles mid-flight proxies; abort restores unfinished NPCs.
		if reason == "advance" then
			suction.finalize(txn, { settle = true })
		else
			suction.abort(txn)
		end
	elseif phase == C.PHASE.LASER_SWEEP then
		laser_ctrl.cleanup(txn, reason or "exit_laser")
	end
end

local function finish_rescue(reason)
	if not active then
		return
	end
	local txn = active
	exit_phase(txn, txn.phase, reason or "abort")
	ops.cleanup_rescue_entities(txn)
	ops.force_restore_player(txn)
	audio.stop_all({ fade_hover = false })
	active = nil
	last_cancel = reason or "finish"
	log_note = "ended:" .. tostring(last_cancel)
end

local function enter_phase(txn, phase)
	txn.phase = phase
	txn.phase_frame = 0
	txn.phase_dur = dur_of(phase)
	-- Do not reset txn.light_age here: ring phase must stay continuous across phases.

	if phase == C.PHASE.ABDUCT_PLAYER then
		txn.abduct_ticks = 0
		txn.abduct_beam_ready = false
		ops.begin_light_travel(txn, "capture")
		if txn.player and txn.player:Exists() and not txn.player_released then
			-- Anchor feet for the whole capture; do not lerp Position upward.
			local origin = txn.player_origin or txn.player.Position
			txn.player_origin = Vector(origin.X, origin.Y)
			txn.park_pos = Vector(origin.X, origin.Y)
			txn.player.Position = txn.player_origin
			txn.beam_foot = txn.player_origin
		end
	elseif phase == C.PHASE.TRANSIT_TO_CENTER then
		-- Carry stowed player from pickup hover to room-center work hover; beam off.
		if txn.player and txn.player:Exists() and not txn.player_released then
			ops.stow_player(txn.player, txn)
		end
		txn.hover_pos = txn.work_hover_pos
	elseif phase == C.PHASE.ABDUCT_TARGETS then
		if txn.player and txn.player:Exists() and not txn.player_released then
			ops.stow_player(txn.player, txn)
		end
		txn.hover_pos = txn.work_hover_pos
		txn.beam_foot = txn.work_feet or (txn.work_hover_pos and Vector(txn.work_hover_pos.X, txn.work_hover_pos.Y + (C.UFO_HOVER_HEIGHT or 72)))
		-- Ceiling only; actual exit uses suction.phase_ready (dynamic job wait).
		txn.phase_dur = (C.SUCTION and C.SUCTION.MAX_WORK) or 150
		suction.begin(txn)
	elseif phase == C.PHASE.LASER_SWEEP then
		txn.hover_pos = txn.work_hover_pos
		if txn.player and txn.player:Exists() and not txn.player_released and not txn.player_stowed then
			ops.stow_player(txn.player, txn)
		end
		ops.begin_laser_sweep(txn, txn.player)
	elseif phase == C.PHASE.RELEASE_PLAYER then
		audio.begin_hover_fade()
		laser_ctrl.cleanup(txn, "release_start")
		txn.laser_from = nil
		txn.laser_to = nil
		txn.release_unlocked = false
		txn.release_drop_armed = false
		txn.release_drop_frame = nil
		if not txn.player_released then
			-- Capture lit work foot so travel lerps it to release_pos (beam stays on).
			local bv = txn.beam_visual
			if bv and bv.foot_initialized then
				txn.work_beam_foot = Vector(bv.foot_x, bv.foot_y)
			else
				txn.work_beam_foot = txn.work_feet
					and Vector(txn.work_feet.X, txn.work_feet.Y)
					or nil
			end
			motion.begin_release_route(txn)
			txn.release_ticks = 0
			txn.beam_foot = txn.release_pos
			ops.begin_light_travel(txn, "release")
			if txn.player and txn.player:Exists() then
				local dest = txn.release_pos or txn.player_origin or txn.player.Position
				txn.player.Position = dest
				if not txn.player_stowed then
					ops.stow_player(txn.player, txn)
				end
			end
		end
	elseif phase == C.PHASE.DEPARTING then
		audio.begin_hover_fade()
		motion.begin_depart_route(txn)
		if txn.player and txn.player:Exists() and not txn.player_released then
			ops.force_restore_player(txn)
		end
	end
end

local function advance_phase(txn)
	local cur = txn.phase
	local idx = nil
	for i, p in ipairs(PHASE_ORDER) do
		if p == cur then
			idx = i
			break
		end
	end
	if not idx then
		finish_rescue("bad_phase")
		return
	end
	exit_phase(txn, cur, "advance")
	if idx >= #PHASE_ORDER then
		finish_rescue("complete")
		return
	end
	enter_phase(txn, PHASE_ORDER[idx + 1])
end

function Ctrl.is_active()
	return active ~= nil
end

function Ctrl.get_active()
	return active
end

function Ctrl.get_note()
	return log_note
end

function Ctrl.get_last_cancel()
	return last_cancel
end

function Ctrl.protects_player(player)
	if not active or not player or active.player_released then
		return false
	end
	if ops.is_protected(player) then
		return true
	end
	local pkey = state.player_key(player)
	return pkey ~= nil and pkey == active.pkey
end

function Ctrl.start_rescue(player, opts)
	opts = opts or {}
	if active then
		log_note = "busy"
		return false, "busy"
	end
	if not player or not player:ToPlayer() then
		return false, "no_player"
	end
	player = player:ToPlayer()
	local pkey = state.player_key(player)
	if not pkey then
		return false, "no_pkey"
	end

	local origin = Vector(player.Position.X, player.Position.Y)
	local txn = {
		id = next_id,
		pkey = pkey,
		player = player,
		player_hash = GetPtrHash(player),
		player_origin = origin,
		park_pos = Vector(origin.X, origin.Y),
		stats = { abducted = 0, rocks = 0, laser_hits = 0 },
		forced = opts.force == true,
		player_released = false,
		light_age = 0,
		light_phase_color = 0,
		light_phase_chase = 0,
		core_lamp = {},
		indicator_lamp = {},
		beam_visual = nil, -- filled on first beam.tick
		beam_foot = Vector(origin.X, origin.Y),
	}
	motion.prepare_txn(txn, origin)
	beam.tick(txn)
	next_id = next_id + 1
	active = txn
	ops.lock_player(player, txn)
	enter_phase(txn, C.PHASE.ARRIVING)
	state.mark_rescue_room(pkey)
	-- Real UFO arrival supersedes the first-SOS silhouette flyover.
	visual.clear_sos_shadow()
	audio.on_rescue_started()
	log_note = "rescue#" .. tostring(txn.id)
	return true, txn.id
end

function Ctrl.abort(reason)
	finish_rescue(reason or "abort")
end

function Ctrl.force_phase(phase_name)
	if not active then
		return false
	end
	local found = false
	for _, p in ipairs(PHASE_ORDER) do
		if p == phase_name then
			found = true
			break
		end
	end
	if not found then
		return false
	end
	-- Skip/abort current phase cleanup (restore unfinished abductees).
	exit_phase(active, active.phase, "force")
	enter_phase(active, phase_name)
	log_note = "force:" .. phase_name
	return true
end

function Ctrl.on_update()
	if not active then
		return
	end
	if not g.is_gameplay_world_active or not g.is_gameplay_world_active() then
		finish_rescue("world_inactive")
		return
	end
	local txn = active
	if txn.player_hash then
		for i = 0, Game():GetNumPlayers() - 1 do
			local p = Game():GetPlayer(i)
			if p and GetPtrHash(p) == txn.player_hash then
				txn.player = p
				break
			end
		end
	end
	if not txn.player or not txn.player:Exists() then
		finish_rescue("player_gone")
		return
	end

	-- Attr rewind may lag unlock; keep retrying without re-locking the player.
	if txn.attr and txn.player_released then
		ops.retry_pending_attr_rewind(txn.player, txn)
	end

	local phase = txn.phase

	-- Tick lights first so beam can sample core_lamp RGB this frame.
	lights.on_rescue_tick(txn)
	beam.tick(txn)

	-- Freeze ABDUCT clock until pickup beam is ready (avoids compressing LightTravel).
	local tick_phase = true
	if phase == C.PHASE.ABDUCT_PLAYER and not txn.abduct_beam_ready then
		if beam.is_open_enough(txn, 0.92) then
			txn.abduct_beam_ready = true
			txn.phase_frame = 0
		else
			tick_phase = false
		end
	elseif phase == C.PHASE.RELEASE_PLAYER and not txn.release_drop_armed then
		local tl = beam.release_timeline()
		if (txn.phase_frame or 0) >= tl.settle_end then
			if beam.release_ready(txn) then
				txn.release_drop_armed = true
				txn.release_drop_frame = tl.settle_end
				txn.phase_frame = tl.settle_end
				-- Spend this frame as drop progress 0 (do not skip into mid-drop).
				tick_phase = false
			else
				-- Hold settle until UFO/beam stable; do not burn LightTravel budget.
				tick_phase = false
				txn.phase_frame = tl.settle_end
			end
		end
	end
	if tick_phase then
		txn.phase_frame = (txn.phase_frame or 0) + 1
	end

	if phase == C.PHASE.ARRIVING and not txn.player_released then
		ops.lock_player(txn.player, txn)
	elseif phase == C.PHASE.ABDUCT_TARGETS then
		suction.update(txn)
	elseif phase == C.PHASE.LASER_SWEEP then
		ops.update_laser(txn, txn.player)
	end

	audio.on_update(txn)

	if phase == C.PHASE.DEPARTING then
		if motion.depart_ready_to_finish(txn) then
			advance_phase(txn)
		end
	elseif phase == C.PHASE.ABDUCT_TARGETS then
		local max_work = (C.SUCTION and C.SUCTION.MAX_WORK) or 150
		if suction.phase_ready(txn) then
			advance_phase(txn)
		elseif (txn.phase_frame or 0) >= max_work then
			suction.timeout(txn)
			advance_phase(txn)
		end
	elseif txn.phase_frame >= (txn.phase_dur or 1) then
		advance_phase(txn)
	end
end

function Ctrl.on_player_update(player)
	if not active or not player then
		return
	end
	local pkey = state.player_key(player)
	if not pkey or pkey ~= active.pkey then
		return
	end
	active.player = player
	active.player_hash = GetPtrHash(player)

	-- After release, UFO departure must not touch the player.
	if active.player_released then
		return
	end

	if active.phase == C.PHASE.ABDUCT_PLAYER then
		ops.update_abduct_player(active, player)
	elseif active.phase == C.PHASE.RELEASE_PLAYER then
		ops.update_release_player(active, player)
	elseif active.phase == C.PHASE.ARRIVING
		or active.phase == C.PHASE.TRANSIT_TO_CENTER
		or active.phase == C.PHASE.ABDUCT_TARGETS
		or active.phase == C.PHASE.LASER_SWEEP
	then
		ops.lock_player(player, active)
		player.Velocity = Vector.Zero
		-- Stowed: follow UFO cabin (do not pin to capture park_pos).
		if active.player_stowed then
			ops.sync_cabin_position(player, active)
		end
	elseif active.phase == C.PHASE.DEPARTING then
		if not active.player_released then
			ops.force_restore_player(active)
		end
	end
end

function Ctrl.on_pre_player_render(player)
	if not active or not player then
		return
	end
	if not motion.use_player_sandwich(active) then
		return
	end
	if active.player_hash and GetPtrHash(player) ~= active.player_hash then
		return
	end
	visual.render_ufo_back(active)
end

function Ctrl.on_post_player_render(player)
	if not active or not player then
		return
	end
	if not motion.use_player_sandwich(active) then
		return
	end
	if active.player_hash and GetPtrHash(player) ~= active.player_hash then
		return
	end
	visual.render_ufo_front(active)
end

function Ctrl.on_render()
	if active then
		visual.render_rescue(active)
		laser_ctrl.render_debug(active)
	end
end

function Ctrl.on_new_room()
	if active then
		finish_rescue("new_room")
	end
	state.clear_room_sos()
	visual.clear_sos_shadow()
	-- Re-assert UFO-absorbed rocks as null decorations if the room restored them.
	state.apply_absorbed_grids()
end

function Ctrl.on_new_level()
	if active then
		finish_rescue("new_level")
	end
	state.reset_floor()
	visual.clear_sos_shadow()
end

function Ctrl.on_game_exit()
	if active then
		finish_rescue("game_exit")
	end
	visual.clear_sos_shadow()
end

function Ctrl.summary()
	local txn = active
	local lines = {
		"note=" .. tostring(log_note),
		"cancel=" .. tostring(last_cancel),
		"active=" .. tostring(txn ~= nil),
	}
	if txn then
		lines[#lines + 1] = string.format(
			"id=%s phase=%s frame=%s/%s stowed=%s released=%s light_age=%s",
			tostring(txn.id),
			tostring(txn.phase),
			tostring(txn.phase_frame),
			tostring(txn.phase_dur),
			tostring(txn.player_stowed),
			tostring(txn.player_released),
			tostring(txn.light_age)
		)
		local st = txn.stats or {}
		lines[#lines + 1] = string.format(
			"abduct=%s rocks=%s proj=%s laser=%s",
			tostring(st.abducted or 0),
			tostring(st.rocks or 0),
			tostring(st.projectiles or 0),
			tostring(st.laser_hits or 0)
		)
		if txn.suction then
			local sa = suction.audit(txn)
			lines[#lines + 1] = string.format(
				"suction scan=%s jobs=%s/%s ready=%s",
				tostring(sa.scan_complete),
				tostring(sa.active_jobs),
				tostring(sa.completed),
				tostring(sa.phase_ready)
			)
		end
		lines[#lines + 1] = lights.summary_line(txn)
		lines[#lines + 1] = string.format(
			"motion scale=%.2f hover_h=%.0f beam=%s open=%.2f sandwich=%s",
			motion.scale(),
			motion.hover_height(),
			tostring(motion.beam_mode(txn)),
			motion.beam_open01(txn),
			tostring(motion.use_player_sandwich(txn))
		)
		lines[#lines + 1] = "sfx=" .. audio.summary()
		local ok, note = visual.ufo_load_status()
		lines[#lines + 1] = "anm2=" .. tostring(note) .. " ok=" .. tostring(ok)
	end
	return table.concat(lines, "\n")
end

return Ctrl
