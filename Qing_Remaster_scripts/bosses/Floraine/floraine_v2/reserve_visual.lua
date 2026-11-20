-- Boss-room reserve / deployment visuals via matte Effects (native Y-sort).
-- Logic tick owns Effect sync + blockers/GridPath. POST_RENDER only draws ground ellipses.

local piece_defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")
local reserve_defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_defs")
local matte_fx = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.piece_matte_fx")

local visual = {}

local shadow_sprite = nil
-- Debug overrides: "white" | "red" | nil (normal pulse)
local outline_force = nil

local function ensure_shadow()
	if shadow_sprite then return shadow_sprite end
	local s = Sprite()
	s:Load(piece_defs.GROUND_SHADOW_ANM2 or "gfx/boss/Floraine/piece_ground_shadow.anm2", true)
	s:Play("Idle", true)
	s.Offset = Vector.Zero
	s.Rotation = 0
	s.Scale = Vector(1, 1)
	shadow_sprite = s
	return s
end

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
function visual.sync_piece(row)
	if not row then
		return
	end
	local st = row.state
	if st == reserve_defs.STATE.ACTIVE or st == reserve_defs.STATE.DEFEATED or row.hidden then
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
	local a = outline_alpha(style, row.outline_pulse, row.phase_elapsed, land_fade)
	local rgb = outline_rgb(style)
	local progress = row.visual_color_progress or 0
	local tilt = row.visual_tilt or 0
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
			visual_height = row.visual_height or 0,
			visual_tilt = tilt,
		})
		return
	end
	matte_fx.sync(row.effect, {
		ground_pos = sort_pos,
		visual_height = row.visual_height or 0,
		color_progress = progress,
		outline_alpha = a,
		outline_rgb = rgb,
		visual_tilt = tilt,
		hidden = false,
	})
end

--- Logic-frame sync: Effect pose/color + incremental blockers/GridPath. Never from Render.
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
	ctrl.for_each_visible(function(row)
		visual.sync_piece(row)
	end)
end

-- LEGACY alias: older debug callers.
function visual.sync_all()
	visual.tick()
end

--- Ground ellipse only (POST_RENDER OK — decoration underfoot, not piece body).
-- Must not Spawn / LoadGraphics / SetGridPath / mutate reserve state.
function visual.render()
	local ok, ctrl = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_controller")
	if not ok or not ctrl or not ctrl.for_each_visible then
		return
	end
	ctrl.for_each_visible(function(row)
		local st = row.state
		local height = row.visual_height or 0
		if height > 0.5 or st == reserve_defs.STATE.LIFTING
			or st == reserve_defs.STATE.TRANSFERRING
			or st == reserve_defs.STATE.HOVERING
			or st == reserve_defs.STATE.DROPPING
			or st == reserve_defs.STATE.LANDING then
			local ground = row.home_pos or row.pos
			if st == reserve_defs.STATE.TRANSFERRING
				or st == reserve_defs.STATE.HOVERING
				or st == reserve_defs.STATE.DROPPING
				or st == reserve_defs.STATE.LANDING then
				-- Shadow follows transfer target cell under the piece's ground projection.
				ground = row.pos or ground
			end
			local sh = ensure_shadow()
			local alpha = math.max(0.12, 0.55 - height * 0.02)
			sh.Color = Color(1, 1, 1, alpha, 0, 0, 0)
			sh:Render(Isaac.WorldToScreen(ground), Vector.Zero, Vector.Zero)
		end
	end)
end

return visual
