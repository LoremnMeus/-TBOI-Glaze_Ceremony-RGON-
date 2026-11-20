-- Alien Savior UFO render. Single sprite/light owner; front/back passes for player sandwich.
local C = require("Qing_Remaster_scripts.items.alien_savior.constants")
local CFG = require("Qing_Remaster_scripts.items.alien_savior.light_config")
local LC = require("Qing_Remaster_scripts.items.alien_savior.light_controller")
local motion = require("Qing_Remaster_scripts.items.alien_savior.motion")
local beam = require("Qing_Remaster_scripts.items.alien_savior.beam")
local enums = require("Qing_Remaster_scripts.core.enums")

local V = {}

local ufo_sprite = nil
local ufo_load_ok = false
local ufo_load_note = "unloaded"
local beam_sprite = nil
local beam_load_ok = false

-- Per Isaac render-frame dedupe (multiplayer PRE/POST callbacks).
local drawn = {
	frame = -1,
	back = false,
	front = false,
	full = false,
	pose = nil,
}

local BACK_GROUPS = {}
do
	local pass = CFG.RENDER_PASS or {}
	for group, side in pairs(pass) do
		if side == "back" then
			BACK_GROUPS[group] = true
		end
	end
	if next(BACK_GROUPS) == nil then
		BACK_GROUPS.bottom_core = true
	end
end

-- Lamp / indicator layers painted AFTER tech beams so emitters sit on the muzzle.
local LAMP_GROUPS = {
	bottom_blink_green = true,
	navigation_red = true,
	ring_red_markers = true,
	central_auxiliary = true,
	bottom_core_indicators = true,
}

local function is_hull_group(group)
	return BACK_GROUPS[group] ~= true and LAMP_GROUPS[group] ~= true
end

local function is_lamp_group(group)
	return LAMP_GROUPS[group] == true
end

local function laser_mod()
	local ok, mod = pcall(require, "Qing_Remaster_scripts.items.alien_savior.laser_controller")
	if ok then
		return mod
	end
	return nil
end

local function render_laser_group(txn, group)
	local mod = laser_mod()
	if mod and mod.render_group then
		mod.render_group(txn, group)
	end
end

local function world_to_render(pos)
	local room = Game():GetRoom()
	if room and room.WorldToScreenPosition then
		return room:WorldToScreenPosition(pos)
	end
	return Isaac.WorldToScreen(pos)
end

local function ensure_ufo()
	if ufo_sprite and ufo_load_ok then
		return ufo_sprite
	end
	ufo_sprite = Sprite()
	local path = C.UFO_ANM2 or CFG.UFO_ANM2
	if ufo_sprite.Load then
		ufo_sprite:Load(path, true)
		ufo_load_ok = true
	end
	if ufo_load_ok and ufo_sprite.Play then
		ufo_sprite:Play(CFG.ANIM or "Idle", true)
		if ufo_sprite.SetFrame then
			ufo_sprite:SetFrame(0)
		end
	end
	ufo_load_note = ufo_load_ok and ("loaded:" .. tostring(path)) or ("fail:" .. tostring(path))
	return ufo_sprite
end

local function ensure_beam()
	if beam_sprite and beam_load_ok then
		return beam_sprite
	end
	beam_sprite = Sprite()
	if C.BEAM_ANM2 and beam_sprite.Load then
		beam_sprite:Load(C.BEAM_ANM2, true)
		beam_load_ok = true
	end
	if beam_load_ok and beam_sprite.Play then
		beam_sprite:Play("Idle", true)
		if beam_sprite.SetFrame then
			beam_sprite:SetFrame(0)
		end
	end
	return beam_sprite
end

function V.ufo_load_status()
	return ufo_load_ok, ufo_load_note
end

function V.invalidate_sprite()
	ufo_sprite = nil
	ufo_load_ok = false
	ufo_load_note = "invalidated"
	beam_sprite = nil
	beam_load_ok = false
end

function V.ufo_world_pos(txn)
	return motion.ufo_world_pos(txn)
end

function V.mouth_world_pos(txn)
	return motion.mouth_world_pos(txn)
end

local function render_frame_id()
	return Isaac.GetFrameCount() or 0
end

local function begin_frame(txn)
	local f = render_frame_id()
	if drawn.frame ~= f then
		drawn.frame = f
		drawn.back = false
		drawn.front = false
		drawn.full = false
		local scale = motion.scale()
		local wpos = motion.ufo_world_pos(txn)
		drawn.pose = {
			scale = scale,
			wpos = wpos,
			screen = world_to_render(wpos),
			mouth = motion.mouth_world_pos(txn),
			colors = LC.evaluate(txn),
			beam_mode = motion.beam_mode(txn),
			beam_open = motion.beam_open01(txn),
		}
	end
	return drawn.pose
end

local function build_layer_color(c, is_body)
	if is_body then
		return Color(1, 1, 1, c.a or 1, 0, 0, 0)
	end
	local off = c.offset
	local ro = (off and off[1]) or 0
	local go = (off and off[2]) or 0
	local bo = (off and off[3]) or 0
	local col = Color(c.r or 1, c.g or 1, c.b or 1, c.a or 1, ro, go, bo)
	if c.use_glow and c.colorize and col.SetColorize then
		local cz = c.colorize
		col:SetColorize(cz[1] or 0, cz[2] or 0, cz[3] or 0, cz[4] or 0)
	elseif col.SetColorize then
		-- Clear leftover Colorize from prior glow layers on the shared Sprite.
		col:SetColorize(0, 0, 0, 0)
	end
	return col
end

local function paint_layers(pose, predicate)
	local sp = ensure_ufo()
	if not sp or not pose then
		return
	end
	local scale = pose.scale
	local screen = pose.screen
	local colors = pose.colors or {}
	if not sp.RenderLayer then
		if sp.Render then
			sp.Scale = Vector(scale, scale)
			sp.Color = Color(1, 1, 1, 1)
			sp:Render(screen)
		end
		return
	end
	sp.Scale = Vector(scale, scale)
	for _, layer in ipairs(CFG.LAYERS) do
		if predicate(layer) then
			local c = colors[layer.name] or { r = 1, g = 1, b = 1, a = 1 }
			local a = c.a or 1
			if a > 0.001 or layer.group == "body" then
				sp.Color = build_layer_color(c, layer.group == "body")
				sp:RenderLayer(layer.id, screen)
			end
		end
	end
	sp.Color = Color(1, 1, 1, 1, 0, 0, 0)
	if sp.Color and sp.Color.SetColorize then
		sp.Color:SetColorize(0, 0, 0, 0)
	end
end

local function render_beam(txn, pose)
	local bv = beam.get(txn)
	if not bv then
		return
	end
	local open = bv.open or 0
	if open <= 0.001 and (bv.alpha or 0) <= 0.001 then
		return
	end
	local mouth = pose.mouth
	local foot = Vector(bv.foot_x or mouth.X, bv.foot_y or (mouth.Y + 80))
	local width = bv.width or motion.beam_width()
	local opacity = bv.alpha or 0
	local br = bv.r or 1
	local bg = bv.g or 1
	local bb = bv.b or 1
	local lay = beam.layout_screen(mouth, foot, open, width)
	local mouth_s = lay.mouth_s
	local ground_s = lay.ground_center_s
	local y_scale = lay.y_scale
	local sp = ensure_beam()
	if sp and sp.RenderLayer then
		-- Layer 0 cone + Layer 2 ground. Core strip stays probe-only.
		if motion.beam_layer_visible("cone") then
			sp.Scale = Vector(width, y_scale)
			sp.Color = Color(br, bg, bb, 0.55 * opacity, 0, 0, 0)
			sp:RenderLayer(0, mouth_s)
		end
		if motion.beam_layer_visible("core") then
			sp.Scale = Vector(width * 0.55, y_scale)
			local pulse = 0.75 + 0.25 * math.sin((txn.light_age or 0) * 0.4)
			sp.Color = Color(br, bg, bb, 0.9 * opacity * pulse, 0, 0, 0)
			sp:RenderLayer(1, mouth_s)
		end
		if motion.beam_layer_visible("ground") then
			local gscale = (0.35 + 0.65 * open) * width
			if (bv.mode or "") == "work" then
				gscale = gscale * 1.35
			end
			sp.Scale = Vector(gscale, gscale * 0.85)
			-- Ellipse slightly brighter than cone; same hue family.
			sp.Color = Color(
				math.min(1, br * 1.05),
				math.min(1, bg * 1.05),
				math.min(1, bb * 1.05),
				0.72 * opacity,
				0, 0, 0
			)
			sp:RenderLayer(2, ground_s)
		end
		sp.Color = Color(1, 1, 1, 1, 0, 0, 0)
		sp.Scale = Vector(1, 1)
	elseif Isaac.DrawLine then
		local col = KColor(br, bg, bb, 0.5 * opacity)
		Isaac.DrawLine(mouth_s, ground_s, col, col, math.max(2, math.floor(8 * width)))
	end

	local dbg = motion.get_debug()
	if dbg.show_beam_seam and Isaac.DrawLine then
		local cy = lay.cone_bottom_y
		local gy = ground_s.Y
		Isaac.DrawLine(Vector(mouth_s.X - 10, cy), Vector(mouth_s.X + 10, cy), KColor(1, 1, 0.2, 0.9), KColor(1, 1, 0.2, 0.9), 1)
		Isaac.DrawLine(Vector(ground_s.X - 10, gy), Vector(ground_s.X + 10, gy), KColor(0.2, 1, 1, 0.9), KColor(0.2, 1, 1, 0.9), 1)
	end
end

local function render_debug(txn, pose)
	local dbg = motion.get_debug()
	if not dbg.enabled then
		return
	end
	if dbg.show_mouth and Isaac.DrawLine then
		local s = world_to_render(pose.mouth)
		local col = KColor(1, 0.2, 0.2, 0.9)
		Isaac.DrawLine(s + Vector(-4, 0), s + Vector(4, 0), col, col, 1)
		Isaac.DrawLine(s + Vector(0, -4), s + Vector(0, 4), col, col, 1)
	end
	if dbg.show_path and Isaac.DrawLine then
		local pts = motion.path_points(txn)
		if pts then
			local col = KColor(0.2, 0.85, 1, 0.75)
			local function line(a, b)
				if a and b then
					Isaac.DrawLine(world_to_render(a), world_to_render(b), col, col, 1)
				end
			end
			line(pts.entry, pts.pickup)
			line(pts.pickup, pts.work)
			line(pts.work, pts.release or pts.work)
			line(pts.release or pts.work, pts.exit)
			if pts.origin and pts.pickup then
				Isaac.DrawLine(
					world_to_render(pts.pickup),
					world_to_render(pts.origin),
					KColor(1, 1, 0.2, 0.45),
					KColor(1, 1, 0.2, 0.45),
					1
				)
			end
		end
	end
	if dbg.show_bounds and Isaac.DrawLine then
		local on = motion.is_fully_offscreen(pose.wpos, pose.scale)
		local s = pose.screen
		local col = on and KColor(0.2, 1, 0.3, 0.8) or KColor(1, 0.4, 0.1, 0.8)
		Isaac.DrawLine(s + Vector(-6, -6), s + Vector(6, 6), col, col, 1)
	end
	if dbg.show_pass and Isaac.DrawLine then
		local s = pose.screen
		Isaac.DrawLine(s + Vector(0, -20), s + Vector(0, -8), KColor(1, 1, 1, 0.5), KColor(1, 1, 1, 0.5), 1)
	end
end

function V.render_ufo_back(txn)
	if not txn or txn.phase == C.PHASE.INACTIVE then
		return
	end
	local pose = begin_frame(txn)
	if drawn.back then
		return
	end
	drawn.back = true
	-- Back lamp + traction beam, then cone mains that pass behind the hull.
	paint_layers(pose, function(layer)
		return BACK_GROUPS[layer.group] == true
	end)
	render_beam(txn, pose)
	render_laser_group(txn, "main_back")
end

function V.render_ufo_front(txn)
	if not txn or txn.phase == C.PHASE.INACTIVE then
		return
	end
	local pose = begin_frame(txn)
	if drawn.front then
		return
	end
	drawn.front = true
	-- Hull → lamps → main_front → secondary (muzzle covers roots; lamps no longer occlude beams).
	paint_layers(pose, function(layer)
		return is_hull_group(layer.group)
	end)
	paint_layers(pose, function(layer)
		return is_lamp_group(layer.group)
	end)
	render_laser_group(txn, "main_front")
	render_laser_group(txn, "secondary")
	render_debug(txn, pose)
end

function V.render_ufo_full(txn)
	if not txn or txn.phase == C.PHASE.INACTIVE then
		return
	end
	local pose = begin_frame(txn)
	if drawn.full or (drawn.back and drawn.front) then
		return
	end
	drawn.full = true
	drawn.back = true
	drawn.front = true
	-- V10.4.1: back → beam → main_back → hull → lamps → main_front → secondary.
	paint_layers(pose, function(layer)
		return BACK_GROUPS[layer.group] == true
	end)
	render_beam(txn, pose)
	render_laser_group(txn, "main_back")
	paint_layers(pose, function(layer)
		return is_hull_group(layer.group)
	end)
	paint_layers(pose, function(layer)
		return is_lamp_group(layer.group)
	end)
	render_laser_group(txn, "main_front")
	render_laser_group(txn, "secondary")
	render_debug(txn, pose)
end

-- Lazy require breaks suction→visual→suction cycle (suction tops-requires visual).
local function render_suction_proxies(txn)
	local ok, suction_mod = pcall(require, "Qing_Remaster_scripts.items.alien_savior.suction")
	if ok and suction_mod and suction_mod.render then
		suction_mod.render(txn)
	end
end

--- Legacy entry used by POST_RENDER when not sandwiching the player.
function V.render_rescue(txn)
	if not txn or txn.phase == C.PHASE.INACTIVE then
		return
	end
	if motion.use_player_sandwich(txn) then
		-- Back/front are owned by player render callbacks this frame.
		-- If they somehow did not run, fall through to full draw below.
		local pose = begin_frame(txn)
		if drawn.back and drawn.front then
			-- Lasers drawn inside front pass (hull→lamps→beams).
			render_suction_proxies(txn)
			return
		end
		-- Incomplete sandwich — draw remaining passes.
		if not drawn.back then
			V.render_ufo_back(txn)
		end
		if not drawn.front then
			V.render_ufo_front(txn)
		end
	else
		V.render_ufo_full(txn)
	end
	render_suction_proxies(txn)
end

-- ---------------------------------------------------------------------------
-- First SOS flyover shadow (replaces old head antenna / DrawLine beacon).
-- Runtime-only; cleared on room/level/reset. Does not freeze gameplay.
-- ---------------------------------------------------------------------------
local sos_shadow = nil
local shadow_sprite = nil
local shadow_load_ok = false
local sos_shadow_skip = false

local function ensure_shadow_sprite()
	if shadow_sprite and shadow_load_ok then
		return shadow_sprite
	end
	shadow_sprite = Sprite()
	local path = C.SOS_SHADOW_ANM2 or "gfx/mimics/Alien_savior/Alien_shadow.anm2"
	if shadow_sprite.Load then
		shadow_sprite:Load(path, true)
		shadow_load_ok = true
	end
	if shadow_load_ok and shadow_sprite.Play then
		shadow_sprite:Play("Idle", true)
		if shadow_sprite.SetFrame then
			shadow_sprite:SetFrame(0)
		end
	end
	return shadow_sprite
end

local function screen_size()
	local w = (Isaac.GetScreenWidth and Isaac.GetScreenWidth()) or 480
	local h = (Isaac.GetScreenHeight and Isaac.GetScreenHeight()) or 270
	return w, h
end

local function shadow_render_size(scale)
	local sc = scale or C.SOS_SHADOW_SCALE or 1.5
	local rw = (C.SOS_SHADOW_TEX_W or 256) * sc
	local rh = (C.SOS_SHADOW_TEX_H or 128) * sc
	return rw, rh
end

--- Locked screen-space endpoints so the silhouette fully clears the visible viewport.
--- dir 0: left→right (slight downward slant); dir 1: right→left.
local function screen_shadow_path_cross(dir, scale)
	local sw, sh = screen_size()
	local rw, rh = shadow_render_size(scale)
	local margin = C.SOS_SHADOW_MARGIN_PX or 16
	local half_w = rw * 0.5
	local half_h = rh * 0.5
	local x_out_l = -half_w - margin
	local x_out_r = sw + half_w + margin
	local y_hi = sh * 0.38
	local y_lo = sh * 0.58
	y_hi = math.max(half_h + margin, math.min(sh - half_h - margin, y_hi))
	y_lo = math.max(half_h + margin, math.min(sh - half_h - margin, y_lo))
	if dir == 1 then
		return Vector(x_out_r, y_hi), Vector(x_out_l, y_lo), sw, sh, rw, rh
	end
	return Vector(x_out_l, y_hi), Vector(x_out_r, y_lo), sw, sh, rw, rh
end

--- Corner skim: straight pass near one screen corner (~25–45% peak visible area).
--- corner_id: 0=TL 1=TR 2=BL 3=BR. Does not cross screen center.
local function screen_shadow_path_corner(corner_id, scale)
	local sw, sh = screen_size()
	local rw, rh = shadow_render_size(scale)
	local margin = C.SOS_SHADOW_MARGIN_PX or 16
	local half_w = rw * 0.5
	local half_h = rh * 0.5
	local inset = C.SOS_SHADOW_CORNER_INSET or 0.30
	corner_id = corner_id % 4
	local mid
	local dir
	if corner_id == 0 then
		mid = Vector(rw * inset, rh * inset)
		dir = Vector(1, 1)
	elseif corner_id == 1 then
		mid = Vector(sw - rw * inset, rh * inset)
		dir = Vector(-1, 1)
	elseif corner_id == 2 then
		mid = Vector(rw * inset, sh - rh * inset)
		dir = Vector(1, -1)
	else
		mid = Vector(sw - rw * inset, sh - rh * inset)
		dir = Vector(-1, -1)
	end
	local len = dir:Length()
	if len > 0 then
		dir = dir * (1 / len)
	else
		dir = Vector(1, 0)
	end
	-- Extend far enough that the full silhouette clears the viewport at both ends.
	local travel = math.max(rw, rh) + margin * 2 + math.max(sw, sh) * 0.15
	local from = mid - dir * travel
	local to = mid + dir * travel
	return from, to, sw, sh, rw, rh, mid
end

local function visible_fraction(pos, sw, sh, rw, rh)
	if not pos then
		return 0
	end
	local half_w = (rw or 0) * 0.5
	local half_h = (rh or 0) * 0.5
	local left = pos.X - half_w
	local right = pos.X + half_w
	local top = pos.Y - half_h
	local bottom = pos.Y + half_h
	local vw = math.max(0, math.min(sw, right) - math.max(0, left))
	local vh = math.max(0, math.min(sh, bottom) - math.max(0, top))
	local area = (rw or 1) * (rh or 1)
	if area <= 0 then
		return 0
	end
	return (vw * vh) / area
end

--- Fly progress only (0–1). Waiting returns t=0 and waiting=true.
local function shadow_progress(sh)
	local delay = sh.delay or 0
	local frame = sh.frame or 0
	local dur = math.max(1, sh.duration or 20)
	if frame < delay then
		return 0, dur, true
	end
	local fly = frame - delay
	return math.min(1, fly / dur), dur, false
end

local function shadow_fade(t)
	local fade = math.min(1, t / 0.10, (1 - t) / 0.10)
	if fade < 0 then
		fade = 0
	end
	return fade
end

local function shadow_outside_screen(pos, sw, sh, rw, rh)
	if not pos then
		return true
	end
	local half_w = (rw or 0) * 0.5
	local half_h = (rh or 0) * 0.5
	return (pos.X + half_w) < 0
		or (pos.X - half_w) > sw
		or (pos.Y + half_h) < 0
		or (pos.Y - half_h) > sh
end

local function shadow_rng(opts)
	if opts and opts.rng then
		return opts.rng
	end
	local player = opts and opts.player
	if not player then
		player = Isaac.GetPlayer(0)
	end
	if player and player.GetCollectibleRNG and enums.Items and enums.Items.Alien_Savior then
		return player:GetCollectibleRNG(enums.Items.Alien_Savior)
	end
	local rng = RNG()
	local seed = (Game():GetFrameCount() or 1) + 17
	if seed == 0 then
		seed = 1
	end
	rng:SetSeed(seed, 35)
	return rng
end

function V.set_sos_shadow_skip(skip)
	sos_shadow_skip = skip == true
end

function V.get_sos_shadow_skip()
	return sos_shadow_skip == true
end

--- Start one-shot flyover. Safe to call repeatedly (restarts).
--- Endpoints are screen pixels locked at start (not recomputed each frame).
function V.start_sos_shadow(opts)
	opts = opts or {}
	if sos_shadow_skip and not opts.force then
		return false
	end
	local scale = opts.scale or C.SOS_SHADOW_SCALE or 1.5
	local rng = shadow_rng(opts)
	local path_type = opts.path_type
	local corner_id = opts.corner_id
	local dir = opts.dir
	if path_type ~= "cross" and path_type ~= "corner" then
		local roll = rng.RandomFloat and rng:RandomFloat() or 0.5
		local cross_chance = C.SOS_SHADOW_CROSS_CHANCE or 0.40
		path_type = (roll < cross_chance) and "cross" or "corner"
	end
	local from, to, sw, sh, rw, rh
	if path_type == "corner" then
		if corner_id == nil then
			corner_id = rng.RandomInt and rng:RandomInt(4) or 0
		end
		from, to, sw, sh, rw, rh = screen_shadow_path_corner(corner_id, scale)
	else
		if dir == nil then
			dir = (rng.RandomInt and rng:RandomInt(2)) or 0
		end
		from, to, sw, sh, rw, rh = screen_shadow_path_cross(dir, scale)
		corner_id = nil
	end
	local traveled = (to - from):Length()
	local mid_frac = visible_fraction(from + (to - from) * 0.5, sw, sh, rw, rh)
	sos_shadow = {
		frame = 0,
		delay = opts.delay
			or C.SOS_SHADOW_DELAY
			or 12,
		duration = opts.duration or C.SOS_SHADOW_DURATION or 20,
		from = from,
		to = to,
		dir = dir,
		path_type = path_type,
		corner_id = corner_id,
		scale = scale,
		alpha_max = opts.alpha or C.SOS_SHADOW_ALPHA or 0.18,
		space = "screen",
		screen_w = sw,
		screen_h = sh,
		render_w = rw,
		render_h = rh,
		traveled_pixels = traveled,
		max_visible_fraction = mid_frac,
	}
	ensure_shadow_sprite()
	return true
end

function V.clear_sos_shadow()
	sos_shadow = nil
end

function V.update_sos_shadow()
	if not sos_shadow then
		return
	end
	sos_shadow.frame = (sos_shadow.frame or 0) + 1
	local delay = sos_shadow.delay or 0
	local dur = sos_shadow.duration or 20
	if sos_shadow.frame >= delay + dur then
		sos_shadow = nil
	end
end

function V.is_sos_shadow_active()
	return sos_shadow ~= nil
end

function V.get_sos_shadow_audit()
	if not sos_shadow then
		return { active = false, skip = sos_shadow_skip == true }
	end
	local t, _dur, waiting = shadow_progress(sos_shadow)
	local from = sos_shadow.from or Vector.Zero
	local to = sos_shadow.to or Vector.Zero
	local pos = from + (to - from) * t
	local sw = sos_shadow.screen_w or 0
	local sh = sos_shadow.screen_h or 0
	local rw = sos_shadow.render_w or 0
	local rh = sos_shadow.render_h or 0
	local live_frac = waiting and 0 or visible_fraction(pos, sw, sh, rw, rh)
	return {
		active = true,
		waiting = waiting == true,
		skip = sos_shadow_skip == true,
		frame = sos_shadow.frame,
		delay = sos_shadow.delay,
		duration = sos_shadow.duration,
		progress = t,
		t = t,
		dir = sos_shadow.dir,
		path_type = sos_shadow.path_type,
		corner_id = sos_shadow.corner_id,
		scale = sos_shadow.scale,
		alpha_max = sos_shadow.alpha_max,
		space = sos_shadow.space,
		screen_width = sw,
		screen_height = sh,
		shadow_render_width = rw,
		shadow_render_height = rh,
		traveled_pixels = sos_shadow.traveled_pixels,
		max_visible_fraction = sos_shadow.max_visible_fraction or live_frac,
		visible_fraction = live_frac,
		final_outside_screen = shadow_outside_screen(to, sw, sh, rw, rh),
		from_screen = { x = from.X, y = from.Y },
		to_screen = { x = to.X, y = to.Y },
		pos_screen = { x = pos.X, y = pos.Y },
		from = { x = from.X, y = from.Y },
		to = { x = to.X, y = to.Y },
		pos = { x = pos.X, y = pos.Y },
	}
end

function V.render_sos_shadow()
	if not sos_shadow then
		return
	end
	local t, _dur, waiting = shadow_progress(sos_shadow)
	if waiting then
		return
	end
	local spr = ensure_shadow_sprite()
	if not spr or not shadow_load_ok then
		return
	end
	local from = sos_shadow.from or Vector.Zero
	local to = sos_shadow.to or Vector.Zero
	local pos = from + (to - from) * t
	local fade = shadow_fade(t)
	local a = (sos_shadow.alpha_max or 0.18) * fade
	local sc = sos_shadow.scale or 1.5
	spr.Scale = Vector(sc, sc)
	spr.Color = Color(1, 1, 1, a, 0, 0, 0)
	spr.Rotation = 0
	if spr.Play then
		spr:Play("Idle", true)
	end
	if spr.SetFrame then
		spr:SetFrame(0)
	end
	-- Screen-space path: render directly. Do NOT pass through world_to_render.
	spr:Render(pos, Vector.Zero, Vector.Zero)
end

--- @deprecated Head antenna removed; kept as no-op so old callers do not error.
function V.render_sos(_player)
end

return V
