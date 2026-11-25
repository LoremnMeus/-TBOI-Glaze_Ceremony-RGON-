-- Boss-room reserve / deployment visuals via matte Effects (native Y-sort).
-- Logic tick owns Effect sync + blockers/GridPath.
-- No extra ground ellipse: NPC shadow comes from entities2 shadowSize only.

local reserve_defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_defs")
local matte_fx = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.piece_matte_fx")

local visual = {}

-- Debug overrides: "white" | "red" | nil (normal pulse)
local outline_force = nil
-- glow_elapsed advances at most once per Game frame (not per sync_all call).
local last_glow_logic_frame = -1

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function outline_alpha(style, pulse_t, phase_elapsed, land_fade)
	if outline_force == "white" or outline_force == "red" then
		return 1
	end
	if not style or not style.visible then
		return 0
	end
	local amin = style.alpha_min or 0
	local amax = style.alpha_max or 1
	if style.fade_out and land_fade then
		return lerp(amax, amin, math.max(0, math.min(1, land_fade)))
	end
	local frames = math.max(1, style.pulse_frames or 10)
	local t = pulse_t
	if t == nil then
		t = (phase_elapsed or 0) / frames
	end
	local wave = 0.5 + 0.5 * math.sin(t * math.pi * 2)
	return lerp(amin, amax, wave)
end

local function outline_rgb(style)
	if outline_force == "white" then
		return { 1, 1, 1 }
	end
	if outline_force == "red" then
		return { 1, 0, 0 }
	end
	return (style and style.color) or { 1, 1, 1 }
end

local function glow_cfg_for(row)
	if row and row.command_kind == "GOLD" then
		return reserve_defs.COMMAND_GLOW_GOLD or reserve_defs.COMMAND_GLOW or {}
	end
	return reserve_defs.COMMAND_GLOW or {}
end

--- Start continuous command-soul glow (INFUSING → deploy → LANDING).
-- Always resets fade bookkeeping so a new command never inherits the previous LANDING fade.
-- opts.kind: "GOLD" | "NORMAL" — stamped onto row.command_kind when provided.
function visual.begin_command_glow(row, opts)
	if not row then
		return
	end
	opts = opts or {}
	if opts.kind == "GOLD" or opts.kind == "NORMAL" then
		row.command_kind = opts.kind
	end
	row.command_glow = true
	row.glow_elapsed = 0
	row.glow_alpha = 0
	row.glow_fade_start = nil
end

function visual.clear_command_glow(row)
	if not row then
		return
	end
	row.command_glow = nil
	row.glow_elapsed = nil
	row.glow_alpha = nil
	row.glow_fade_start = nil
end

--- Sample continuous glow. advance=true consumes one logic frame of glow_elapsed.
-- LANDING uses a fixed glow_fade_start (never re-lerp from the decaying glow_alpha).
-- Gold commands blend toward persistent outline alpha instead of extinguishing.
local function sample_command_glow(row, st, land_fade, advance)
	local G = glow_cfg_for(row)
	local ramp = math.max(1, G.RAMP_FRAMES or 7)
	local hold = G.HOLD_ALPHA or 0.92
	if advance then
		row.glow_elapsed = (row.glow_elapsed or 0) + 1
	end
	local a
	if st == reserve_defs.STATE.LANDING or st == reserve_defs.STATE.DROPPING then
		if row.glow_fade_start == nil then
			local start = row.glow_alpha
			if start == nil or start <= 0 then
				start = hold
			end
			row.glow_fade_start = start
		end
		local t = math.max(0, math.min(1, land_fade or 0))
		if G.LAND_TO_PERSIST then
			local persist = tonumber(G.PERSIST_ALPHA) or hold
			a = row.glow_fade_start + (persist - row.glow_fade_start) * t
		else
			a = row.glow_fade_start * (1 - t)
			if t >= 1 then
				a = 0
			end
		end
	elseif (row.glow_elapsed or 0) <= ramp then
		local t = (row.glow_elapsed or 0) / ramp
		t = 1 - (1 - t) * (1 - t)
		a = hold * t
	else
		a = hold
	end
	row.glow_alpha = a
	return a
end

function visual.set_outline_force(mode)
	if mode == "white" or mode == "red" or mode == "pulse" or mode == nil or mode == false then
		outline_force = (mode == "pulse" or mode == false) and nil or mode
	end
	return outline_force
end

function visual.get_outline_force()
	return outline_force
end

--- Sync one reserve Effect to row state (logic tick only).
-- advance_glow: when true, consume one glow logic frame (Boss tick path only).
function visual.sync_piece(row, advance_glow)
	if not row then
		return
	end
	local st = row.state
	if st == reserve_defs.STATE.ACTIVE or st == reserve_defs.STATE.DEFEATED or row.hidden then
		visual.clear_command_glow(row)
		if row.effect then
			matte_fx.remove(row.effect)
			row.effect = nil
		end
		return
	end
	local style = reserve_defs.outline_style_for_state(st)
	local land_fade = nil
	if st == reserve_defs.STATE.LANDING or st == reserve_defs.STATE.DROPPING then
		local dur = reserve_defs.DEPLOY.LAND or 10
		land_fade = (row.phase_elapsed or 0) / math.max(1, dur)
	end
	local a
	local rgb
	-- Identity (command_kind) only picks palette inside command_glow.
	-- Stamping GOLD early must NOT light the outline before the soul arrives.
	if row.command_glow then
		a = sample_command_glow(row, st, land_fade, advance_glow == true)
		local G = glow_cfg_for(row)
		rgb = outline_rgb({ color = G.COLOR or (style and style.color) })
	else
		a = outline_alpha(style, row.outline_pulse, row.phase_elapsed, land_fade)
		rgb = outline_rgb(style)
	end
	-- Cache last displayed outline for Matte→NPC handoff continuity.
	row._last_outline_alpha = a
	row._last_outline_rgb = rgb
	local progress = row.visual_color_progress or 0
	local tilt = row.visual_tilt or 0
	local height = row.visual_height or 0
	-- Y-sort uses board-plane position (feet). Lift is PositionOffset only — never
	-- rewrite Position.Y solely to fake height.
	local sort_pos = row.pos or row.home_pos
	if not (row.effect and matte_fx.is_matte(row.effect)) then
		row.effect = matte_fx.spawn(row.kind, sort_pos, {
			owner = "reserve",
			piece_id = row.id,
			color_progress = progress,
			outline_alpha = a,
			outline_rgb = rgb,
			visual_height = height,
			visual_tilt = tilt,
		})
		row._sync_pos_x = sort_pos and sort_pos.X
		row._sync_pos_y = sort_pos and sort_pos.Y
		row._sync_height = height
		row._sync_progress = progress
		row._sync_outline_a = a
		row._sync_tilt = tilt
		return
	end
	local same = row._sync_pos_x == (sort_pos and sort_pos.X)
		and row._sync_pos_y == (sort_pos and sort_pos.Y)
		and row._sync_height == height
		and row._sync_progress == progress
		and row._sync_outline_a == a
		and row._sync_tilt == tilt
	if same then
		return
	end
	matte_fx.sync(row.effect, {
		ground_pos = sort_pos,
		visual_height = height,
		color_progress = progress,
		outline_alpha = a,
		outline_rgb = rgb,
		visual_tilt = tilt,
		hidden = false,
	})
	row._sync_pos_x = sort_pos and sort_pos.X
	row._sync_pos_y = sort_pos and sort_pos.Y
	row._sync_height = height
	row._sync_progress = progress
	row._sync_outline_a = a
	row._sync_tilt = tilt
end

--- Logic-frame sync: Effect pose/color + incremental blockers/GridPath. Never from Render.
-- Advances command-glow elapsed at most once per Game():GetFrameCount().
function visual.tick()
	local ok, ctrl = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_controller")
	if not ok or not ctrl or not ctrl.for_each_visible then
		return
	end
	if ctrl.note_sync then
		ctrl.note_sync()
	end
	if ctrl.refresh_blockers_and_path then
		ctrl.refresh_blockers_and_path()
	end
	local frame = Game():GetFrameCount()
	local advance_glow = frame ~= last_glow_logic_frame
	if advance_glow then
		last_glow_logic_frame = frame
	end
	ctrl.for_each_visible(function(row)
		visual.sync_piece(row, advance_glow)
	end)
end

-- Sprite-only refresh: does NOT advance glow_elapsed (safe for debug spam).
function visual.sync_all()
	local ok, ctrl = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_controller")
	if not ok or not ctrl or not ctrl.for_each_visible then
		return
	end
	ctrl.for_each_visible(function(row)
		visual.sync_piece(row, false)
	end)
end

--- POST_RENDER hook kept as no-op (extra deploy ground ellipse removed).
function visual.render()
end

return visual
