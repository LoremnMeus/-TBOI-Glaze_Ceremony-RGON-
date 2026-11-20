-- Canonical Wind Runtime Owner (Storm V5).
-- begin / update / set_phase / stop — update never rebuilds Session or clears particles.
-- Unique POST_UPDATE + POST_RENDER scheduling (no wildwind Effect dependency).

local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local env_config = require("Qing_Remaster_scripts.threads.wind.environment_config")
local physics = require("Qing_Remaster_scripts.threads.wind.wind_physics")
local visual = require("Qing_Remaster_scripts.threads.wind.wind_visual")

local PROBE_PATH = "Qing_Remaster_scripts.threads.wind.wind_pipeline_probe"
local function probe()
	local mod = package.loaded[PROBE_PATH]
	if type(mod) == "table" and mod.is_listening and mod.is_listening() then
		return mod
	end
	return nil
end

local M = {
	ToCall = {},
	myToCall = {},
	-- Keep legacy tag key so Zennith projectile writers stay valid.
	own_key = "Enemies_Zennith_wind",
	session = nil,
	physics_enabled = true,
	visual_fade = nil,
	debug_override = nil,
	session_generation = 0,
	_boss_tick = 0,
}

local OWNER_ENV = "environment"
local OWNER_BOSS = "boss"

local DEBUG_PRESETS = {
	none = 0,
	weak = 0.20,
	mid = 0.50,
	strong = 0.75,
}

local function clamp01(x)
	return math.max(0, math.min(1, x or 0))
end

local function story_test_active()
	local ok, sess = pcall(require, "Qing_Remaster_scripts.story_test.story_test_session")
	return ok and sess and sess.is_active and sess.is_active() == true
end

local function resolve_intensity(sess)
	if not sess then return 0 end
	local base = clamp01(sess.intensity or 0)
	local dbg = M.debug_override
	if dbg and dbg.active and dbg.preset then
		local forced = DEBUG_PRESETS[dbg.preset]
		if forced ~= nil then
			base = clamp01(forced)
		end
	end
	if M.visual_fade then
		base = base * clamp01(1 - (M.visual_fade.t or 0))
	end
	return base
end

local function build_env_session(opts)
	opts = opts or {}
	local distance = opts.distance
	local intensity = opts.intensity
	if intensity == nil then
		intensity = env_config.distance_to_intensity(distance)
	end
	local ang = opts.ang
	if ang == nil then
		ang = ((opts.dir or 1) * 90 - 90)
	end
	local mode = opts.mode or 1
	if opts.pos and mode == 1 then
		mode = 2
	end
	return {
		kind = OWNER_ENV,
		mode = mode,
		ang = ang,
		pos = opts.pos,
		distance = distance,
		intensity = clamp01(intensity),
		delta_rotation = opts.delta_rotation or 0,
		follower = nil,
		visual_source = opts.visual_source,
		visual_bend = opts.visual_bend,
		room_cells = opts.room_cells,
	}
end

local function build_boss_session(opts)
	opts = opts or {}
	local mode = opts.mode or (opts.ent and 3) or (opts.pos and 2) or 1
	local ang = opts.ang
	if ang == nil and opts.dir ~= nil then
		ang = ((opts.dir or 1) * 90 - 90)
	end
	local intensity = opts.intensity
	if intensity == nil and opts.power ~= nil then
		intensity = math.max(0.2, math.min(1, 0.2 + (tonumber(opts.power) or 2) * 0.12))
	end
	return {
		kind = OWNER_BOSS,
		mode = mode,
		ang = ang or 0,
		pos = opts.pos,
		follower = opts.ent,
		delta_rotation = opts.delta_rotation or 0,
		delta_pos = opts.delta_pos,
		intensity = clamp01(intensity or 0.5),
		legacy_power = opts.power,
	}
end

--- Begin a new Session. Clears particles once. Use for room enter / ownership change.
function M.begin(config)
	config = config or {}
	local kind = config.kind or OWNER_ENV
	M.visual_fade = nil
	M.physics_enabled = config.physics_enabled ~= false
	if kind == OWNER_BOSS then
		M.session = build_boss_session(config)
	else
		M.session = build_env_session(config)
	end
	M.session_generation = (M.session_generation or 0) + 1
	visual.reset_particles("new_session")
	if config.phase then
		visual.set_phase(config.phase)
	elseif M.session.pos and kind == OWNER_ENV then
		visual.set_phase("eye")
	else
		visual.set_phase(kind == OWNER_BOSS and "combat" or "directional")
	end
	if config.eye_radius_scale then
		visual.set_eye_radius_scale(config.eye_radius_scale)
	end
	-- Explicit visual warm-start (not a clear+rebuild loop).
	if config.prefill ~= false then
		visual.prefill(M.session, resolve_intensity(M.session), config.prefill_frames or 6)
	end
	local p = probe()
	if p and p.note_begin then
		p.note_begin(config.probe_reason or ("begin_" .. tostring(kind)), {
			kind = kind,
			intensity = resolve_intensity(M.session),
			generation = M.session_generation,
		})
	end
	return true
end

--- Update continuous parameters. NEVER clears particles or bumps session_generation.
function M.update(config)
	config = config or {}
	if not M.session then
		return M.begin(config)
	end
	-- Kind switch requires begin.
	local want_kind = config.kind
	if want_kind and want_kind ~= M.session.kind then
		return M.begin(config)
	end
	if config.intensity ~= nil then
		M.session.intensity = clamp01(config.intensity)
	elseif config.distance ~= nil and M.session.kind == OWNER_ENV then
		M.session.distance = config.distance
		M.session.intensity = clamp01(env_config.distance_to_intensity(config.distance))
	end
	if config.ang ~= nil then
		M.session.ang = config.ang
	elseif config.dir ~= nil then
		M.session.ang = ((config.dir or 1) * 90 - 90)
	end
	if config.pos ~= nil then
		M.session.pos = config.pos
	end
	if config.visual_source ~= nil then
		M.session.visual_source = config.visual_source
	end
	if config.visual_bend ~= nil then
		M.session.visual_bend = config.visual_bend
	end
	if config.room_cells ~= nil then
		M.session.room_cells = config.room_cells
	end
	if config.mode ~= nil then
		M.session.mode = config.mode
	end
	if config.delta_rotation ~= nil then
		M.session.delta_rotation = config.delta_rotation
	end
	if config.delta_pos ~= nil then
		M.session.delta_pos = config.delta_pos
	end
	if config.ent ~= nil then
		M.session.follower = config.ent
	end
	if config.power ~= nil then
		M.session.legacy_power = config.power
		if config.intensity == nil and M.session.kind == OWNER_BOSS then
			M.session.intensity = clamp01(math.max(0.2, math.min(1, 0.2 + (tonumber(config.power) or 2) * 0.12)))
		end
	end
	if config.physics_enabled ~= nil then
		M.physics_enabled = config.physics_enabled == true
	end
	if config.phase then
		visual.set_phase(config.phase)
	end
	if config.eye_radius_scale then
		visual.set_eye_radius_scale(config.eye_radius_scale)
	end
	if config.cover_alpha ~= nil then
		visual.set_cover_alpha(config.cover_alpha)
	end
	return true
end

function M.set_phase(phase)
	visual.set_phase(phase)
end

function M.stop(reason)
	reason = reason or "stop"
	M.last_stop_reason = reason
	local p = probe()
	if p and p.note_stop then
		p.note_stop(reason)
	end
	M.session = nil
	M.physics_enabled = true
	M.visual_fade = nil
	visual.clear(reason)
end

function M.fade_out_visuals()
	M.physics_enabled = false
	M.visual_fade = {t = 0, step = 1 / 26}
end

function M.get_state()
	local vs = visual.get_stats()
	return {
		has_session = M.session ~= nil,
		kind = M.session and M.session.kind or nil,
		intensity = resolve_intensity(M.session),
		ang = M.session and M.session.ang or nil,
		pos = M.session and M.session.pos or nil,
		physics_enabled = M.physics_enabled,
		session_generation = M.session_generation,
		particle_reset_count = vs.particle_reset_count,
		last_reset_reason = vs.last_reset_reason,
		last_stop_reason = M.last_stop_reason,
		visual = vs,
		phase = vs.phase,
		debug_active = M.debug_override and M.debug_override.active or false,
	}
end

function M.get_visual_stats()
	local st = M.get_state()
	local vs = st.visual or {}
	return {
		style = "v7.2",
		mode = vs.phase,
		total = vs.total,
		counts = vs.counts,
		layers = vs.layers,
		layer_mask = vs.layer_mask,
		tornado_active = vs.tornado_active,
		metrics = vs.metrics,
		intensity = st.intensity,
		has_eye = M.session and M.session.pos ~= nil,
		eye_radius_scale = vs.eye_radius_scale,
		cover_alpha = vs.cover_alpha,
		session_generation = st.session_generation,
		particle_reset_count = st.particle_reset_count,
		last_reset_reason = st.last_reset_reason,
		blank_frames = vs.blank_frames or 0,
		blank_reason = vs.blank_reason,
		force_white = vs.force_white == true,
	}
end

function M.set_visual_layer_mask(opts)
	return visual.set_layer_mask(opts)
end

function M.set_solo_visual_layer(layer)
	return visual.set_solo_layer(layer)
end

-- Convenience used by environment / boss controllers.
function M.begin_environment(opts)
	opts = opts or {}
	opts.kind = OWNER_ENV
	return M.begin(opts)
end

function M.update_environment(opts)
	opts = opts or {}
	opts.kind = OWNER_ENV
	if not M.session or M.session.kind ~= OWNER_ENV then
		return M.begin_environment(opts)
	end
	return M.update(opts)
end

function M.begin_boss(opts)
	opts = opts or {}
	opts.kind = OWNER_BOSS
	opts.phase = opts.phase or "combat"
	return M.begin(opts)
end

function M.update_boss(opts)
	opts = opts or {}
	opts.kind = OWNER_BOSS
	if not M.session or M.session.kind ~= OWNER_BOSS then
		return M.begin_boss(opts)
	end
	return M.update(opts)
end

function M.pause_environment_physics()
	if M.session and M.session.kind == OWNER_ENV then
		M.physics_enabled = false
	end
end

function M.clear_environment()
	if M.session and M.session.kind == OWNER_ENV then
		M.stop("clear_environment")
	end
end

function M.clear_boss()
	if M.session and M.session.kind == OWNER_BOSS then
		M.physics_enabled = false
		M.session = nil
		visual.reset_particles("clear_boss")
		visual.release_eye_structure()
	end
end

function M.pulse_boss(opts)
	opts = opts or {}
	if not M.session or M.session.kind ~= OWNER_BOSS then
		M.begin_boss(opts)
	end
	-- Visual pulse via temporary intensity bump on session; physics uses intensity.
	M.session.pulse_until = Game():GetFrameCount() + (opts.frames or 45)
	M.session.pulse_boost = clamp01(opts.boost or 0.25)
end

function M.set_cover_alpha(alpha)
	visual.set_cover_alpha(alpha)
end

function M.set_eye_radius_scale(scale)
	visual.set_eye_radius_scale(scale)
end

function M.set_debug_override(opts)
	opts = opts or {}
	if not story_test_active() then
		return false, "story_test_inactive"
	end
	local prev = M.debug_override or {}
	local next_dbg = {
		active = true,
		preset = opts.preset or prev.preset or "mid",
		show_particles = opts.show_particles,
		enable_drag = opts.enable_drag,
		combat_preview = opts.combat_preview == true,
	}
	if next_dbg.show_particles == nil then
		next_dbg.show_particles = (prev.show_particles ~= false)
	end
	if next_dbg.enable_drag == nil then
		next_dbg.enable_drag = (prev.enable_drag ~= false)
	end
	if DEBUG_PRESETS[next_dbg.preset] == nil then
		next_dbg.preset = "mid"
	end
	M.debug_override = next_dbg
	M.visual_fade = nil
	if opts.force_white_debug ~= nil then
		visual.set_force_white(opts.force_white_debug == true)
	end
	local intensity = DEBUG_PRESETS[next_dbg.preset] or 0
	if next_dbg.combat_preview then
		M.begin_boss({ang = opts.ang or 0, intensity = intensity > 0 and intensity or 0.5})
	else
		if M.session and M.session.kind == OWNER_ENV then
			M.update_environment({intensity = intensity, ang = opts.ang, dir = opts.dir})
		else
			M.begin_environment({intensity = intensity, ang = opts.ang, dir = opts.dir, mode = 1})
		end
	end
	M.physics_enabled = true
	if intensity <= 0 or next_dbg.show_particles == false then
		visual.reset_particles("debug_hide")
	end
	return true
end

function M.clear_debug_override(opts)
	opts = opts or {}
	local had = M.debug_override and M.debug_override.active
	M.debug_override = nil
	visual.set_force_white(false)
	if had and opts.reapply_formal then
		local ok_save, save = pcall(require, "Qing_Remaster_scripts.core.savedata")
		local ok_env, env_wind = pcall(require, "Qing_Remaster_scripts.threads.wind.environment_controller")
		if ok_save and save and ok_env and env_wind then
			local desc = Game():GetLevel():GetCurrentRoomDesc()
			local sgid = desc and desc.SafeGridIndex or -1
			if save.elses["thread_wind_spawn"] == true and sgid > 0 then
				local distance = save.elses["Zennith_room_conter_" .. sgid]
				if distance ~= nil then
					if distance ~= 0 then
						local room_opts = {
							distance = distance,
							dir = save.elses["Zennith_room_dir_" .. sgid],
						}
						local ok_tw, thread_wind = pcall(require, "Qing_Remaster_scripts.threads.thread_Wind")
						if ok_tw and thread_wind and thread_wind.environment_heading then
							local head = thread_wind.environment_heading(sgid)
							if head then
								room_opts.ang = head.ang
								room_opts.visual_source = head.visual_source
								room_opts.visual_bend = head.visual_bend
								room_opts.room_cells = head.room_cells
							end
						end
						env_wind.begin_room(room_opts)
					else
						env_wind.pause_for_combat()
					end
				else
					M.stop("debug_restore_clear")
				end
			end
		end
	end
end

function M.get_debug_override()
	return M.debug_override
end

function M.debug_preset_intensity(name)
	return DEBUG_PRESETS[name]
end

-- Aliases kept for Zennith projectile tag writers during migration.
-- Prefer M.begin_* / M.update_* / M.stop.
function M.start_()
	return true
end

function M.grow_slow()
	M.fade_out_visuals()
end

local function tick()
	if M.debug_override and M.debug_override.active and not story_test_active() then
		M.clear_debug_override({reapply_formal = true})
	end
	local sess = M.session
	local p = probe()
	if not sess then
		if p and p.on_owner_update then
			p.on_owner_update({
				has_session = false,
				session_generation = M.session_generation,
			})
		end
		return
	end

	if auxi.check_all_exists(sess.follower) then
		sess.pos = sess.follower.Position + sess.follower.Velocity * 0.5 + (sess.delta_pos or Vector(0, 0))
	end

	local intensity = resolve_intensity(sess)
	if sess.pulse_until and Game():GetFrameCount() <= sess.pulse_until then
		intensity = clamp01(intensity + (sess.pulse_boost or 0))
	end

	local dbg = M.debug_override
	local show = not (dbg and dbg.active and dbg.show_particles == false)
	if show then
		visual.update_particles(sess, intensity)
		visual.spawn_budgeted(sess, intensity)
	end

	if M.physics_enabled then
		if sess.kind == OWNER_ENV then
			local enable_drag = not (dbg and dbg.active and dbg.enable_drag == false)
			physics.tick_environment(sess, intensity, enable_drag)
		else
			M._boss_tick = (M._boss_tick or 0) + 1
			if M._boss_tick % 3 == 1 then
				physics.tick_boss(
					sess,
					intensity,
					M.own_key .. "rate",
					M.own_key .. "test_remove",
					M.own_key .. "try_remove"
				)
			end
		end
	elseif p and p.note_physics then
		p.note_physics({skip = "physics_disabled"})
	end

	if p and p.on_owner_update then
		local vs = visual.get_stats and visual.get_stats() or {}
		local player = Game():GetPlayer(0)
		local vel = player and player.Velocity
		local metrics = vs.metrics
		local removal_by_layer = nil
		if metrics and metrics.by_layer then
			removal_by_layer = {
				airflow = metrics.by_layer.airflow and metrics.by_layer.airflow.remove or nil,
				gust = metrics.by_layer.gust and metrics.by_layer.gust.remove or nil,
				motes = metrics.by_layer.motes and metrics.by_layer.motes.remove or nil,
			}
		end
		p.on_owner_update({
			has_session = true,
			kind = sess.kind,
			intensity = intensity,
			physics_enabled = M.physics_enabled,
			session_generation = M.session_generation,
			particle_count = vs.total,
			counts = vs.counts,
			entered_visible = metrics and metrics.entered_visible or 0,
			removals = metrics and metrics.remove or nil,
			removal_by_layer = removal_by_layer,
			eye_rings = vs.counts and vs.counts.eye_ring or 0,
			player_velocity = vel and {x = vel.X, y = vel.Y} or nil,
		})
	end
end

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		tick()
		if M.visual_fade then
			if Game():GetFrameCount() % 15 == 1 then
				M.visual_fade.t = (M.visual_fade.t or 0) + (M.visual_fade.step or 1 / 26)
				if M.visual_fade.t >= 1 then
					M.visual_fade = nil
					M.stop("fade_complete")
				end
			end
		end
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_RENDER,
	params = nil,
	Function = function()
		local draw_stats = nil
		if M.session or (visual.cover_alpha or 0) > 0.02 then
			draw_stats = visual.render()
		end
		local p = probe()
		if p and p.on_owner_render then
			p.on_owner_render({
				sprite_draws = draw_stats and draw_stats.sprite_draws or 0,
				sprite_attempts = draw_stats and draw_stats.sprite_attempts or 0,
			})
		end
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		-- thread_Wind owns the one begin/stop for this room. begin() already
		-- resets and prefills; a second clear here deletes that prefill.
		if visual.note_room_event then
			visual.note_room_event("new_room_seen")
		end
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_LEVEL,
	params = nil,
	Function = function()
		M.clear_debug_override()
		M.stop("floor_exit")
	end,
})

table.insert(M.myToCall, #M.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_LEVEL,
	params = nil,
	Function = function()
		M.stop("floor_exit")
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	params = nil,
	Function = function()
		M.clear_debug_override()
		M.stop("game_start")
	end,
})

return M
