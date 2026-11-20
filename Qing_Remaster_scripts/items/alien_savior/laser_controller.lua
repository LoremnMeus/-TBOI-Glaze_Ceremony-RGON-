-- Alien Savior LASER_SWEEP V10.4: cone mains + lamp secs; screen-exit visual lifecycle.
-- EntityLaser = collision/damage only when OWN_VISUAL; laser_visual draws beams.
local C = require("Qing_Remaster_scripts.items.alien_savior.constants")
local CFG = require("Qing_Remaster_scripts.items.alien_savior.light_config")
local motion = require("Qing_Remaster_scripts.items.alien_savior.motion")
local lights = require("Qing_Remaster_scripts.items.alien_savior.light_controller")
local laser_visual = require("Qing_Remaster_scripts.items.alien_savior.laser_visual")
local audio = require("Qing_Remaster_scripts.items.alien_savior.audio")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local L = {}

local dbg = {
	show_main_origins = false,
	show_lamp_origins = false,
	show_cone_geometry = false,
	color_preset = "default",
	color_target = "both",
	layer_test = "ufo_foreground",
	cone_radius_x = nil,
	cone_radius_y = nil,
	cone_height = nil,
	cone_speed = nil,
}

local drawn_groups = {
	frame = -1,
	main_back = false,
	main_front = false,
	secondary = false,
}

local function cfg()
	return C.LASER or {}
end

local function cone_cfg()
	local c = cfg().CONE or {}
	return {
		COUNT = c.COUNT or cfg().MAIN_COUNT or 6,
		SPEED_DEG = dbg.cone_speed or c.SPEED_DEG or cfg().MAIN_ROTATE_DEG or 3,
		PHASE0 = c.PHASE0 or 0,
		BASE_OFFSET_Y = dbg.cone_height or c.BASE_OFFSET_Y or 70,
		RADIUS_X = dbg.cone_radius_x or c.RADIUS_X or 95,
		RADIUS_Y = dbg.cone_radius_y or c.RADIUS_Y or 28,
		BACK_WIDTH = c.BACK_WIDTH or 0.82,
		FRONT_WIDTH = c.FRONT_WIDTH or 1.10,
		BACK_ALPHA = c.BACK_ALPHA or 0.65,
		FRONT_ALPHA = c.FRONT_ALPHA or 1.00,
		BACK_BRIGHTNESS = c.BACK_BRIGHTNESS or 0.75,
		FRONT_BRIGHTNESS = c.FRONT_BRIGHTNESS or 1.00,
	}
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function tech_variant()
	if LaserVariant and LaserVariant.THIN_RED then
		return LaserVariant.THIN_RED
	end
	return cfg().TECH_VARIANT_FALLBACK or 2
end

local function alive_laser(ent)
	return ent and ent.Exists and ent:Exists() and not ent:IsDead()
end

local function own_visual_active()
	local lc = cfg()
	if dbg.layer_test == "native" then
		return false
	end
	if dbg.layer_test == "ufo_foreground" then
		return true
	end
	return lc.OWN_VISUAL ~= false
end

local function make_colorize_color(spec)
	spec = spec or {}
	local col = Color(
		spec.r ~= nil and spec.r or 1,
		spec.g ~= nil and spec.g or 1,
		spec.b ~= nil and spec.b or 1,
		spec.a ~= nil and spec.a or 1,
		spec.ro ~= nil and spec.ro or 0,
		spec.go ~= nil and spec.go or 0,
		spec.bo ~= nil and spec.bo or 0
	)
	if col.SetColorize then
		col:SetColorize(
			spec.cr ~= nil and spec.cr or 0,
			spec.cg ~= nil and spec.cg or 0,
			spec.cb ~= nil and spec.cb or 0,
			spec.amount ~= nil and spec.amount or 0
		)
	end
	return col
end

local function copy_color_spec(src)
	src = src or {}
	return {
		r = src.r, g = src.g, b = src.b, a = src.a,
		ro = src.ro, go = src.go, bo = src.bo,
		cr = src.cr, cg = src.cg, cb = src.cb, amount = src.amount,
		lamp_r = src.lamp_r, lamp_g = src.lamp_g, lamp_b = src.lamp_b,
	}
end

local function main_color_spec()
	local preset = dbg.color_preset or "default"
	if preset == "pure_white" then
		return {
			r = 1, g = 1, b = 1, a = 1,
			ro = 0.35, go = 0.35, bo = 0.35,
			cr = 1, cg = 1, cb = 1, amount = 1,
		}
	end
	if preset == "bright_cyan" then
		return {
			r = 0.75, g = 1.00, b = 0.98, a = 1,
			ro = 0.18, go = 0.42, bo = 0.38,
			cr = 0.55, cg = 1.00, cb = 0.95, amount = 1,
		}
	end
	local m = cfg().MAIN_COLORIZE or {}
	return {
		r = m.r ~= nil and m.r or 0.90,
		g = m.g ~= nil and m.g or 1.00,
		b = m.b ~= nil and m.b or 1.00,
		a = m.a ~= nil and m.a or 1.00,
		ro = m.ro ~= nil and m.ro or 0.18,
		go = m.go ~= nil and m.go or 0.35,
		bo = m.bo ~= nil and m.bo or 0.30,
		cr = m.cr ~= nil and m.cr or 0.65,
		cg = m.cg ~= nil and m.cg or 1.00,
		cb = m.cb ~= nil and m.cb or 0.92,
		amount = m.amount ~= nil and m.amount or 1.00,
	}
end

local function lamp_color_spec(txn, layer_name)
	local c = lights.get_layer_color and lights.get_layer_color(txn, layer_name)
	local amount = cfg().SEC_COLORIZE_AMOUNT or 1.0
	local floor = cfg().SEC_OFFSET_FLOOR or {}
	local fro = floor.ro or 0.14
	local fgo = floor.go or 0.22
	local fbo = floor.bo or 0.16
	if not c then
		local m = main_color_spec()
		m.amount = amount
		return m, nil
	end
	local lr = c.r or 0.5
	local lg = c.g or 0.5
	local lb = c.b or 0.5
	local off = c.offset or { 0, 0, 0 }
	local cz = c.colorize
	local cr, cg, cb = lr, lg, lb
	local cz_amt = amount
	if cz and (cz[4] or 0) > 0.05 then
		cr = cz[1] or lr
		cg = cz[2] or lg
		cb = cz[3] or lb
		cz_amt = math.max(amount, cz[4] or 0)
	end
	local peak = math.max(cr, cg, cb, 0.2)
	local lift = 1.25 / peak
	cr = math.min(2.2, cr * lift)
	cg = math.min(2.2, cg * lift)
	cb = math.min(2.2, cb * lift)
	local tint_lift = 0.35
	return {
		r = math.min(1, 0.65 + lr * tint_lift),
		g = math.min(1, 0.65 + lg * tint_lift),
		b = math.min(1, 0.65 + lb * tint_lift),
		a = 1,
		ro = math.max(off[1] or 0, fro + lr * 0.12),
		go = math.max(off[2] or 0, fgo + lg * 0.14),
		bo = math.max(off[3] or 0, fbo + lb * 0.12),
		cr = cr,
		cg = cg,
		cb = cb,
		amount = cz_amt,
		lamp_r = lr,
		lamp_g = lg,
		lamp_b = lb,
	}, c
end

local function apply_laser_color(laser, spec)
	if not laser or not spec then
		return
	end
	local col = make_colorize_color(spec)
	local target = dbg.color_target or "both"
	if target == "entity" or target == "both" then
		if laser.SetColor then
			laser:SetColor(col, -1, 80, false, false)
		else
			laser.Color = col
		end
	end
	if target == "sprite" or target == "both" then
		local sp = laser.GetSprite and laser:GetSprite()
		if sp then
			sp.Color = col
		end
	end
	laser.Visible = not own_visual_active()
end

local function apply_pierce(laser)
	local mode = "none"
	if not laser then
		return mode
	end
	if TearFlags and TearFlags.TEAR_SPECTRAL and laser.TearFlags ~= nil then
		laser.TearFlags = laser.TearFlags | TearFlags.TEAR_SPECTRAL
		mode = "tear_spectral"
	end
	if EntityGridCollisionClass and laser.GridCollisionClass ~= nil then
		laser.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
		if mode == "none" then
			mode = "gridcoll_none"
		else
			mode = mode .. "+gridcoll_none"
		end
	end
	return mode
end

local function detach(laser)
	if not laser then
		return
	end
	if laser.DisableFollowParent ~= nil then
		laser.DisableFollowParent = true
	end
	if laser.SetDisableFollowParent then
		pcall(function()
			laser:SetDisableFollowParent(true)
		end)
	end
	laser.Parent = nil
end

local function kill_laser(ent)
	if not alive_laser(ent) then
		return
	end
	if ent.SetTimeout then
		ent:SetTimeout(1)
	else
		ent:Remove()
	end
end

local function player_dmg(player, mult)
	local base = 3.5
	if player and player.Damage then
		base = player.Damage
	end
	return base * (mult or 1)
end

local function make_rng(txn, player)
	if txn.laser_rng then
		return txn.laser_rng
	end
	local rng = RNG()
	local seed = 1
	if player and player.GetCollectibleRNG and enums.Items and enums.Items.Alien_Savior then
		local base = player:GetCollectibleRNG(enums.Items.Alien_Savior)
		if base and base.GetSeed then
			seed = base:GetSeed()
		end
	end
	if seed == 0 then
		seed = 1
	end
	seed = (seed + (txn.id or 0) * 9973) % 2147483647
	if seed == 0 then
		seed = 1
	end
	rng:SetSeed(seed, 35)
	txn.laser_rng = rng
	return rng
end

local function rng_range(rng, lo, hi)
	if not rng then
		return lo
	end
	if hi <= lo then
		return lo
	end
	local span = hi - lo + 1
	local r = rng:RandomInt(span)
	return lo + r
end

local function rng_float(rng, lo, hi)
	if not rng then
		return lo
	end
	local t = rng:RandomFloat()
	return lo + (hi - lo) * t
end

--- Cone apex = validated mouth emitter (not beam foot).
function L.main_origin(txn)
	return motion.mouth_world_pos(txn)
end

function L.ufo_center(txn)
	return motion.ufo_world_pos(txn)
end

function L.lamp_world_pos(txn, layer_name)
	local xy = CFG.LAYER_XY and CFG.LAYER_XY[layer_name]
	if not xy then
		return nil, "missing_xy"
	end
	local ufo = L.ufo_center(txn)
	local sc = motion.scale and motion.scale() or (C.UFO_SCALE or 1)
	local px = cfg().PIVOT_X or 128
	local py = cfg().PIVOT_Y or 64
	local lx = (xy.x - px) * sc
	local ly = (xy.y - py) * sc
	return Vector(ufo.X + lx, ufo.Y + ly), nil
end

local function list_lamp_names()
	local names = {}
	if CFG.LAYER_XY then
		for name, _ in pairs(CFG.LAYER_XY) do
			names[#names + 1] = name
		end
	end
	table.sort(names)
	return names
end

local function depth_for(kind, angle)
	local lc = cfg()
	if kind == "secondary" then
		return lc.SEC_DEPTH or 900
	end
	local a = auxi.get_correct_angle and auxi.get_correct_angle(angle) or angle
	if a > 0 and a < 180 then
		return lc.MAIN_DEPTH_FRONT or 500
	end
	return lc.MAIN_DEPTH_BACK or -200
end

local function spawn_beam(player, pos, angle, dmg, opts)
	opts = opts or {}
	local variant = opts.variant or tech_variant()
	local q = Isaac.Spawn(EntityType.ENTITY_LASER, variant, 0, pos, Vector.Zero, player):ToLaser()
	if not q then
		return nil, "spawn_failed"
	end
	detach(q)
	q.SpawnerEntity = player
	q.CollisionDamage = dmg
	q.Angle = angle
	apply_laser_color(q, opts.color_spec or main_color_spec())
	if q.SetTimeout then
		q:SetTimeout(9999)
	end
	local pierce = apply_pierce(q)
	q.DepthOffset = depth_for(opts.kind or "main", angle)
	return q, pierce, variant
end

local function muzzle_pos(lamp_center, angle)
	local out = cfg().MUZZLE_OUT or 5
	local dir = auxi.MakeVector(angle)
	return lamp_center + dir * out
end

local function ensure_visual(slot_or_lamp, extend_f, retract_f, duration)
	local vis = slot_or_lamp.visual
	if not vis then
		vis = {}
		slot_or_lamp.visual = vis
	end
	vis.age = vis.age or 0
	vis.duration = duration or vis.duration or 1
	vis.extend_frames = extend_f or vis.extend_frames or 5
	vis.retract_frames = retract_f or vis.retract_frames or 7
	vis.target_length = vis.target_length or 0
	vis.visible_length = vis.visible_length or 0
	vis.alpha = vis.alpha or 1
	vis.state = vis.state or "extending"
	vis.extend_progress = vis.extend_progress or 0
	vis.retract_progress = vis.retract_progress or 0
	vis.screen_exit_distance = vis.screen_exit_distance or 0
	vis.collision_length = vis.collision_length or 0
	return vis
end

--- Target length follows current aim each frame; reveal ratio is lifecycle-owned.
local function refresh_visual(vis, origin, angle, laser_ent)
	local len01, a01, state, ep, rp = laser_visual.laser_reveal(
		vis.age,
		vis.duration,
		vis.extend_frames,
		vis.retract_frames
	)
	local target, screen_exit = laser_visual.screen_exit_distance(origin, angle)
	vis.target_length = target
	vis.visible_length = target * len01
	vis.alpha = a01
	vis.state = state
	vis.extend_progress = ep
	vis.retract_progress = rp
	vis.screen_exit_distance = screen_exit or 0
	vis.collision_length = laser_visual.collision_length(laser_ent)
end

local function update_cone_slot(txn, slot, frame)
	local c = cone_cfg()
	local apex = L.main_origin(txn)
	local phase = math.rad((c.PHASE0 or 0) + frame * (c.SPEED_DEG or 3))
	local phi = phase + (slot.id - 1) * math.pi * 2 / math.max(1, c.COUNT)
	local base_center = apex + Vector(0, c.BASE_OFFSET_Y)
	local guide = base_center + Vector(
		c.RADIUS_X * math.cos(phi),
		c.RADIUS_Y * math.sin(phi)
	)
	local delta = guide - apex
	local length = delta:Length()
	local direction = length > 0.001 and (delta * (1 / length)) or Vector(0, 1)
	local front_t = (math.sin(phi) + 1) * 0.5
	local is_front = math.sin(phi) >= 0

	slot.phi = phi
	slot.front_t = front_t
	slot.origin = apex
	slot.guide_point = guide
	slot.direction = direction
	slot.angle = direction:GetAngleDegrees()
	slot.actual_angle = slot.angle
	slot.width_scale = lerp(c.BACK_WIDTH, c.FRONT_WIDTH, front_t)
	slot.alpha = lerp(c.BACK_ALPHA, c.FRONT_ALPHA, front_t)
	slot.brightness = lerp(c.BACK_BRIGHTNESS, c.FRONT_BRIGHTNESS, front_t)
	slot.render_group = is_front and "main_front" or "main_back"
	slot.color_spec = main_color_spec()

	local ent = slot.ent
	if alive_laser(ent) then
		ent.Position = apex
		ent.Angle = slot.angle
		ent.CollisionDamage = slot.damage or ent.CollisionDamage
		apply_laser_color(ent, slot.color_spec)
		-- DepthOffset only for native layer_test; cone order is visual groups.
		local depth = is_front and (cfg().MAIN_DEPTH_FRONT or 500) or (cfg().MAIN_DEPTH_BACK or -200)
		ent.DepthOffset = depth
		slot.depth_offset = depth
		slot.collision_angle = ent.Angle
		slot.render_length = laser_visual.collision_length(ent)
	end

	local lc = cfg()
	local dur = (C.DUR and C.DUR.LASER_SWEEP) or 65
	local vis = ensure_visual(
		slot,
		lc.MAIN_EXTEND_FRAMES or 5,
		lc.MAIN_RETRACT_FRAMES or 7,
		dur
	)
	vis.age = frame
	vis.duration = dur
	refresh_visual(vis, slot.origin, slot.angle, slot.ent)
end

function L.begin(txn, player)
	L.cleanup(txn, "restart")
	player = player or txn.player
	local lc = cfg()
	local c = cone_cfg()
	local n = c.COUNT
	local origin = L.main_origin(txn)
	local dmg = player_dmg(player, lc.MAIN_DMG_MULT or 1.5)
	local rng = make_rng(txn, player)
	local main = {}
	local pierce_mode = "none"
	local variant = tech_variant()
	local main_spec = main_color_spec()
	for i = 1, n do
		local ang = 90 + (i - 1) * (360 / n)
		local ent, pierce, var = spawn_beam(player, origin, ang, dmg, {
			kind = "main",
			variant = variant,
			color_spec = main_spec,
		})
		if ent then
			pierce_mode = pierce or pierce_mode
			variant = var or variant
			local slot = {
				ent = ent,
				id = i,
				kind = "main",
				damage = dmg,
				base_angle = ang,
				actual_angle = ang,
				color_spec = main_spec,
				depth_offset = depth_for("main", ang),
				created = true,
				phi = 0,
				front_t = 0,
				render_group = "main_back",
			}
			ensure_visual(
				slot,
				lc.MAIN_EXTEND_FRAMES or 5,
				lc.MAIN_RETRACT_FRAMES or 7,
				(C.DUR and C.DUR.LASER_SWEEP) or 65
			)
			main[#main + 1] = slot
		end
	end

	local lamps = {}
	local invalid = {}
	local names = list_lamp_names()
	local stagger = math.max(1, math.floor(#names / math.max(1, lc.SEC_ACTIVE_MAX or 10)))
	for i, name in ipairs(names) do
		local pos, err = L.lamp_world_pos(txn, name)
		if not pos then
			invalid[#invalid + 1] = { layer = name, reason = err or "nil" }
		else
			local delay = ((i - 1) * stagger) % math.max(1, (lc.SEC_STOP or 56) - (lc.SEC_START or 8))
			lamps[#lamps + 1] = {
				layer = name,
				kind = "secondary",
				cooldown = (lc.SEC_START or 8) + delay,
				fire_left = 0,
				ent = nil,
				base_angle = 0,
				actual_angle = 0,
				created = 0,
				destroyed = 0,
			}
		end
	end

	txn.laser_bank = {
		main = main,
		lamps = lamps,
		invalid_lamps = invalid,
		age = 0,
		main_dmg = dmg,
		sec_dmg = player_dmg(player, lc.SEC_DMG_MULT or 0.5),
		wall_pierce_mode = pierce_mode,
		laser_variant = variant,
		main_colorize = copy_color_spec(main_spec),
		created_main = #main,
		created_sec = 0,
		destroyed = 0,
		cleanup_reason = nil,
		last_main_origin = origin,
		cone_phase_deg = c.PHASE0 or 0,
		render_specs = nil,
		render_specs_frame = -1,
		render_order_note = "V10.4 cone + screen-exit visual extend/retract",
		main_sfx_played = false,
	}
	-- Seed cone geometry immediately (age 0 → extend start).
	for _, slot in ipairs(main) do
		update_cone_slot(txn, slot, 0)
	end
	if #main > 0 and audio.play_tech_laser_main then
		audio.play_tech_laser_main()
		txn.laser_bank.main_sfx_played = true
	end
	if audio.reset_tech_laser_sfx then
		audio.reset_tech_laser_sfx()
	end
	txn.stats = txn.stats or {}
	txn.stats.laser_hits = txn.stats.laser_hits or 0
	return true
end

local function count_active_sec(bank)
	local n = 0
	for _, lamp in ipairs(bank.lamps or {}) do
		if alive_laser(lamp.ent) then
			n = n + 1
		end
	end
	return n
end

local function update_main(txn, bank)
	local c = cone_cfg()
	local frame = bank.age or 0
	bank.cone_phase_deg = (c.PHASE0 or 0) + frame * (c.SPEED_DEG or 3)
	bank.last_main_origin = L.main_origin(txn)
	local base_center = bank.last_main_origin + Vector(0, c.BASE_OFFSET_Y)
	bank.cone_base_center = base_center
	bank.cone_radius_x = c.RADIUS_X
	bank.cone_radius_y = c.RADIUS_Y
	for _, slot in ipairs(bank.main or {}) do
		if alive_laser(slot.ent) then
			slot.damage = bank.main_dmg
			update_cone_slot(txn, slot, frame)
		end
	end
end

local function stop_secondaries(bank, reason)
	for _, lamp in ipairs(bank.lamps or {}) do
		if alive_laser(lamp.ent) then
			kill_laser(lamp.ent)
			lamp.ent = nil
			lamp.destroyed = (lamp.destroyed or 0) + 1
			bank.destroyed = (bank.destroyed or 0) + 1
		end
		lamp.visual = nil
		lamp.fire_left = 0
		lamp.fire_age = 0
		lamp.fire_duration = 0
		lamp.cooldown = 9999
	end
	bank.sec_stop_reason = reason
end

local function update_secondaries(txn, bank, player)
	local lc = cfg()
	local pf = txn.phase_frame or 0
	local start_f = lc.SEC_START or 8
	local stop_f = lc.SEC_STOP or 56
	if pf >= stop_f then
		if not bank.sec_stopped then
			stop_secondaries(bank, "sec_window_end")
			bank.sec_stopped = true
		end
		return
	end
	if pf < start_f then
		return
	end

	local rng = make_rng(txn, player)
	local ufo = L.ufo_center(txn)
	local active_max = lc.SEC_ACTIVE_MAX or 10
	local active_n = count_active_sec(bank)
	local variant = tech_variant()

	for _, lamp in ipairs(bank.lamps or {}) do
		if alive_laser(lamp.ent) then
			lamp.fire_age = (lamp.fire_age or 0) + 1
			lamp.fire_left = math.max(0, (lamp.fire_duration or 0) - lamp.fire_age)
			local center = L.lamp_world_pos(txn, lamp.layer)
			if center then
				local ang = lamp.actual_angle or lamp.ent.Angle or 0
				local muzzle = muzzle_pos(center, ang)
				lamp.lamp_center = center
				lamp.last_origin = muzzle
				lamp.ent.Position = muzzle
				lamp.ent.Angle = ang
				lamp.ent.CollisionDamage = bank.sec_dmg or lamp.ent.CollisionDamage
				lamp.ent.DepthOffset = lc.SEC_DEPTH or 900
				lamp.depth_offset = lamp.ent.DepthOffset
				if lamp.color_spec then
					apply_laser_color(lamp.ent, lamp.color_spec)
				end
				local vis = ensure_visual(
					lamp,
					lc.SEC_EXTEND_FRAMES or 3,
					lc.SEC_RETRACT_FRAMES or 4,
					lamp.fire_duration or 16
				)
				vis.age = lamp.fire_age
				vis.duration = lamp.fire_duration or 16
				refresh_visual(vis, muzzle, ang, lamp.ent)
			end
			-- Kill only after full duration (includes retract).
			if lamp.fire_age >= (lamp.fire_duration or 0) then
				kill_laser(lamp.ent)
				lamp.ent = nil
				lamp.visual = nil
				lamp.destroyed = (lamp.destroyed or 0) + 1
				bank.destroyed = (bank.destroyed or 0) + 1
				active_n = math.max(0, active_n - 1)
				lamp.cooldown = rng_range(rng, lc.SEC_CD_MIN or 18, lc.SEC_CD_MAX or 28)
			end
		else
			lamp.ent = nil
			lamp.cooldown = (lamp.cooldown or 0) - 1
			if lamp.cooldown <= 0 and active_n < active_max and pf < stop_f then
				local center, err = L.lamp_world_pos(txn, lamp.layer)
				if not center then
					lamp.cooldown = 30
					bank.invalid_lamps = bank.invalid_lamps or {}
					bank.invalid_lamps[#bank.invalid_lamps + 1] = { layer = lamp.layer, reason = err or "nil" }
				else
					local outward = center - ufo
					local base = outward:GetAngleDegrees()
					if outward:LengthSquared() < 0.25 then
						base = rng_float(rng, 0, 360)
					end
					local jitter = lc.SEC_ANGLE_JITTER or 25
					local ang = base + rng_float(rng, -jitter, jitter)
					local muzzle = muzzle_pos(center, ang)
					local color_spec, lamp_rgb = lamp_color_spec(txn, lamp.layer)
					local ent, pierce, var = spawn_beam(player, muzzle, ang, bank.sec_dmg, {
						kind = "secondary",
						variant = variant,
						color_spec = color_spec,
					})
					if ent then
						bank.wall_pierce_mode = pierce or bank.wall_pierce_mode
						bank.laser_variant = var or bank.laser_variant or variant
						lamp.ent = ent
						lamp.base_angle = base
						lamp.actual_angle = ang
						lamp.color_spec = color_spec
						lamp.lamp_source_rgb = lamp_rgb and {
							r = lamp_rgb.r, g = lamp_rgb.g, b = lamp_rgb.b,
						} or (color_spec and {
							r = color_spec.lamp_r, g = color_spec.lamp_g, b = color_spec.lamp_b,
						}) or nil
						local dur = rng_range(rng, lc.SEC_FIRE_MIN or 14, lc.SEC_FIRE_MAX or 20)
						lamp.fire_duration = dur
						lamp.fire_age = 0
						lamp.fire_left = dur
						local vis = ensure_visual(
							lamp,
							lc.SEC_EXTEND_FRAMES or 3,
							lc.SEC_RETRACT_FRAMES or 4,
							dur
						)
						vis.age = 0
						vis.duration = dur
						refresh_visual(vis, muzzle, ang, ent)
						lamp.lamp_center = center
						lamp.last_origin = muzzle
						lamp.depth_offset = ent.DepthOffset
						lamp.created = (lamp.created or 0) + 1
						bank.created_sec = (bank.created_sec or 0) + 1
						active_n = active_n + 1
						if audio.play_tech_laser_secondary then
							audio.play_tech_laser_secondary()
						end
						if lights.flash_layer then
							lights.flash_layer(txn, lamp.layer, lc.LAMP_FLASH_FRAMES or 6)
						end
					else
						lamp.cooldown = 10
					end
				end
			end
		end
	end
end

function L.collect_render_specs(txn)
	local bank = txn and txn.laser_bank
	local groups = {
		main_back = {},
		main_front = {},
		secondary = {},
	}
	if not bank then
		return groups
	end
	local frame = Isaac.GetFrameCount() or 0
	if bank.render_specs and bank.render_specs_frame == frame then
		return bank.render_specs
	end

	for _, slot in ipairs(bank.main or {}) do
		if alive_laser(slot.ent) then
			local group = slot.render_group or "main_back"
			local vis = slot.visual or {}
			local cone_a = slot.alpha or 1
			local vis_a = vis.alpha or 1
			local spec = {
				id = slot.id,
				kind = "main",
				group = group,
				entity = slot.ent,
				origin = slot.origin,
				direction = slot.direction,
				angle = slot.angle,
				guide_point = slot.guide_point,
				render_length = slot.render_length,
				visual_current_length = vis.visible_length or 0,
				visual_target_length = vis.target_length or 0,
				visual_state = vis.state,
				visual_age = vis.age,
				collision_length = vis.collision_length or slot.render_length,
				extend_progress = vis.extend_progress,
				retract_progress = vis.retract_progress,
				screen_exit_distance = vis.screen_exit_distance,
				front_t = slot.front_t,
				width_scale = slot.width_scale or 1,
				alpha_multiplier = cone_a * vis_a,
				brightness_multiplier = slot.brightness or 1,
				color_spec = slot.color_spec or main_color_spec(),
				texture_set = "alien_tech",
				muzzle_always = true,
				active = true,
			}
			groups[group][#groups[group] + 1] = spec
		end
	end

	for _, lamp in ipairs(bank.lamps or {}) do
		if alive_laser(lamp.ent) then
			local ang = lamp.actual_angle or lamp.ent.Angle or 0
			local vis = lamp.visual or {}
			groups.secondary[#groups.secondary + 1] = {
				id = lamp.layer,
				kind = "secondary",
				group = "secondary",
				entity = lamp.ent,
				origin = lamp.last_origin or lamp.ent.Position,
				angle = ang,
				direction = auxi.MakeVector(ang),
				visual_current_length = vis.visible_length or 0,
				visual_target_length = vis.target_length or 0,
				visual_state = vis.state,
				visual_age = vis.age,
				collision_length = vis.collision_length,
				extend_progress = vis.extend_progress,
				retract_progress = vis.retract_progress,
				screen_exit_distance = vis.screen_exit_distance,
				width_scale = 0.9,
				alpha_multiplier = vis.alpha or 1,
				brightness_multiplier = 1,
				color_spec = lamp.color_spec or main_color_spec(),
				texture_set = "alien_tech",
				muzzle_always = true,
				active = true,
			}
		end
	end

	bank.render_specs = groups
	bank.render_specs_frame = frame
	return groups
end

function L.update(txn, player)
	local bank = txn and txn.laser_bank
	if not bank then
		return
	end
	player = player or txn.player
	bank.age = (bank.age or 0) + 1
	if audio.tick_tech_laser_sfx then
		audio.tick_tech_laser_sfx()
	end
	update_main(txn, bank)
	update_secondaries(txn, bank, player)
	bank.render_specs = nil
	bank.render_specs_frame = -1
	L.collect_render_specs(txn)
end

function L.cleanup(txn, reason)
	if not txn then
		return
	end
	local bank = txn.laser_bank
	if not bank then
		return
	end
	bank.cleanup_reason = reason or "cleanup"
	for _, slot in ipairs(bank.main or {}) do
		if alive_laser(slot.ent) then
			kill_laser(slot.ent)
			bank.destroyed = (bank.destroyed or 0) + 1
		end
		slot.ent = nil
	end
	for _, lamp in ipairs(bank.lamps or {}) do
		if alive_laser(lamp.ent) then
			kill_laser(lamp.ent)
			lamp.destroyed = (lamp.destroyed or 0) + 1
			bank.destroyed = (bank.destroyed or 0) + 1
		end
		lamp.ent = nil
	end
	txn.laser_bank = nil
end

function L.set_debug(patch)
	patch = patch or {}
	if patch.show_main_origins ~= nil then
		dbg.show_main_origins = patch.show_main_origins == true
	end
	if patch.show_lamp_origins ~= nil then
		dbg.show_lamp_origins = patch.show_lamp_origins == true
	end
	if patch.show_cone_geometry ~= nil then
		dbg.show_cone_geometry = patch.show_cone_geometry == true
	end
	if patch.color_preset ~= nil then
		local p = tostring(patch.color_preset)
		if p == "default" or p == "bright_cyan" or p == "pure_white" then
			dbg.color_preset = p
		end
	end
	if patch.color_target ~= nil then
		local t = tostring(patch.color_target)
		if t == "entity" or t == "sprite" or t == "both" then
			dbg.color_target = t
		end
	end
	if patch.layer_test ~= nil then
		local lt = tostring(patch.layer_test)
		if lt == "native" or lt == "ufo_foreground" then
			dbg.layer_test = lt
		end
	end
	if patch.cone_radius_x ~= nil then
		dbg.cone_radius_x = tonumber(patch.cone_radius_x)
	end
	if patch.cone_radius_y ~= nil then
		dbg.cone_radius_y = tonumber(patch.cone_radius_y)
	end
	if patch.cone_height ~= nil then
		dbg.cone_height = tonumber(patch.cone_height)
	end
	if patch.cone_speed ~= nil then
		dbg.cone_speed = tonumber(patch.cone_speed)
	end
end

function L.get_debug()
	local c = cone_cfg()
	return {
		show_main_origins = dbg.show_main_origins == true,
		show_lamp_origins = dbg.show_lamp_origins == true,
		show_cone_geometry = dbg.show_cone_geometry == true,
		color_preset = dbg.color_preset or "default",
		color_target = dbg.color_target or "both",
		layer_test = dbg.layer_test or "ufo_foreground",
		own_visual = own_visual_active(),
		cone_radius_x = c.RADIUS_X,
		cone_radius_y = c.RADIUS_Y,
		cone_height = c.BASE_OFFSET_Y,
		cone_speed = c.SPEED_DEG,
	}
end

local function begin_draw_frame()
	local f = Isaac.GetFrameCount() or 0
	if drawn_groups.frame ~= f then
		drawn_groups.frame = f
		drawn_groups.main_back = false
		drawn_groups.main_front = false
		drawn_groups.secondary = false
	end
end

--- Draw one visual group once per Isaac render frame.
function L.render_group(txn, group)
	if not own_visual_active() then
		return
	end
	if not txn or not group then
		return
	end
	begin_draw_frame()
	if drawn_groups[group] then
		return
	end
	drawn_groups[group] = true
	local groups = L.collect_render_specs(txn)
	local list = groups and groups[group]
	if not list then
		return
	end
	for _, spec in ipairs(list) do
		laser_visual.render(spec)
	end
end

--- Compatibility: draw all laser groups in flat order (prefer split passes).
function L.render_foreground(txn)
	L.render_group(txn, "main_back")
	L.render_group(txn, "main_front")
	L.render_group(txn, "secondary")
end

function L.render_debug(txn)
	if not txn or not Isaac.DrawLine then
		return
	end
	local bank = txn.laser_bank
	if not bank then
		return
	end
	local room = Game():GetRoom()
	local function scr(p)
		if room and room.WorldToScreenPosition then
			return room:WorldToScreenPosition(p)
		end
		return Isaac.WorldToScreen(p)
	end
	if dbg.show_main_origins and bank.last_main_origin then
		local s = scr(bank.last_main_origin)
		local col = KColor(0.2, 1.0, 0.9, 0.9)
		Isaac.DrawLine(s + Vector(-6, 0), s + Vector(6, 0), col, col, 1)
		Isaac.DrawLine(s + Vector(0, -6), s + Vector(0, 6), col, col, 1)
	end
	if dbg.show_lamp_origins then
		local col = KColor(1.0, 0.85, 0.2, 0.75)
		for _, lamp in ipairs(bank.lamps or {}) do
			local pos = lamp.last_origin or L.lamp_world_pos(txn, lamp.layer)
			if pos then
				local s = scr(pos)
				Isaac.DrawLine(s + Vector(-3, 0), s + Vector(3, 0), col, col, 1)
				Isaac.DrawLine(s + Vector(0, -3), s + Vector(0, 3), col, col, 1)
			end
		end
	end
	if dbg.show_cone_geometry and bank.last_main_origin then
		local apex = bank.last_main_origin
		local base = bank.cone_base_center or (apex + Vector(0, cone_cfg().BASE_OFFSET_Y))
		local rx = bank.cone_radius_x or cone_cfg().RADIUS_X
		local ry = bank.cone_radius_y or cone_cfg().RADIUS_Y
		local col_a = KColor(0.3, 1, 0.9, 0.85)
		local col_g = KColor(1, 0.6, 0.2, 0.7)
		local sa = scr(apex)
		Isaac.DrawLine(sa + Vector(-5, 0), sa + Vector(5, 0), col_a, col_a, 1)
		Isaac.DrawLine(sa + Vector(0, -5), sa + Vector(0, 5), col_a, col_a, 1)
		for i = 0, 23 do
			local a0 = (i / 24) * math.pi * 2
			local a1 = ((i + 1) / 24) * math.pi * 2
			local p0 = base + Vector(rx * math.cos(a0), ry * math.sin(a0))
			local p1 = base + Vector(rx * math.cos(a1), ry * math.sin(a1))
			Isaac.DrawLine(scr(p0), scr(p1), col_g, col_g, 1)
		end
		for _, slot in ipairs(bank.main or {}) do
			if slot.guide_point then
				Isaac.DrawLine(sa, scr(slot.guide_point), KColor(0.5, 0.9, 1, 0.45), KColor(0.5, 0.9, 1, 0.45), 1)
			end
		end
	end
end

function L.audit(txn)
	local bank = txn and txn.laser_bank
	if not bank then
		return { active = false }
	end
	local main_n, sec_n = 0, 0
	local mains = {}
	for _, slot in ipairs(bank.main or {}) do
		if alive_laser(slot.ent) then
			main_n = main_n + 1
		end
		local vis = slot.visual or {}
		mains[#mains + 1] = {
			id = slot.id,
			phi = slot.phi,
			front_t = slot.front_t,
			angle = slot.angle,
			collision_angle = slot.collision_angle or (slot.ent and slot.ent.Angle),
			render_group = slot.render_group,
			render_length = slot.render_length,
			width_scale = slot.width_scale,
			guide = slot.guide_point and { x = slot.guide_point.X, y = slot.guide_point.Y } or nil,
			active = alive_laser(slot.ent),
			visual_state = vis.state,
			visual_age = vis.age,
			visual_target_length = vis.target_length,
			visual_current_length = vis.visible_length,
			collision_length = vis.collision_length,
			extend_progress = vis.extend_progress,
			retract_progress = vis.retract_progress,
			screen_exit_distance = vis.screen_exit_distance,
		}
	end
	local lamps = {}
	for _, lamp in ipairs(bank.lamps or {}) do
		if alive_laser(lamp.ent) then
			sec_n = sec_n + 1
		end
		local cz = lamp.color_spec
		local vis = lamp.visual or {}
		lamps[#lamps + 1] = {
			layer = lamp.layer,
			base_angle = lamp.base_angle,
			actual_angle = lamp.actual_angle,
			fire_left = lamp.fire_left,
			fire_age = lamp.fire_age,
			fire_duration = lamp.fire_duration,
			cooldown = lamp.cooldown,
			active = alive_laser(lamp.ent),
			created = lamp.created,
			destroyed = lamp.destroyed,
			depth_offset = lamp.depth_offset,
			colorize_rgb = cz and { r = cz.cr, g = cz.cg, b = cz.cb } or nil,
			colorize_amount = cz and cz.amount or nil,
			lamp_source_rgb = lamp.lamp_source_rgb,
			lamp_center = lamp.lamp_center and { x = lamp.lamp_center.X, y = lamp.lamp_center.Y } or nil,
			actual_muzzle_pos = lamp.last_origin and { x = lamp.last_origin.X, y = lamp.last_origin.Y } or nil,
			origin = lamp.last_origin and { x = lamp.last_origin.X, y = lamp.last_origin.Y } or nil,
			visual_state = vis.state,
			visual_age = vis.age,
			visual_target_length = vis.target_length,
			visual_current_length = vis.visible_length,
			collision_length = vis.collision_length,
			extend_progress = vis.extend_progress,
			retract_progress = vis.retract_progress,
			screen_exit_distance = vis.screen_exit_distance,
		}
	end
	local origin = bank.last_main_origin or L.main_origin(txn)
	local mcz = main_color_spec()
	bank.main_colorize = copy_color_spec(mcz)
	local c = cone_cfg()
	return {
		active = true,
		phase_frame = txn.phase_frame,
		main_mode = "cone",
		cone_count = c.COUNT,
		cone_phase = bank.cone_phase_deg,
		cone_apex = origin and { x = origin.X, y = origin.Y } or nil,
		cone_base_center = bank.cone_base_center and {
			x = bank.cone_base_center.X, y = bank.cone_base_center.Y,
		} or nil,
		cone_radius_x = bank.cone_radius_x or c.RADIUS_X,
		cone_radius_y = bank.cone_radius_y or c.RADIUS_Y,
		main_laser_count = main_n,
		secondary_laser_count = sec_n,
		active_laser_count = main_n + sec_n,
		main_origin = origin and { x = origin.X, y = origin.Y } or nil,
		main = mains,
		main_dmg = bank.main_dmg,
		sec_dmg = bank.sec_dmg,
		laser_variant = bank.laser_variant or tech_variant(),
		texture_anm2 = cfg().VISUAL_ANM2,
		color_preset = dbg.color_preset or "default",
		color_target = dbg.color_target or "both",
		layer_test = dbg.layer_test or "ufo_foreground",
		own_visual = own_visual_active(),
		tint_rgb = { r = mcz.r, g = mcz.g, b = mcz.b, a = mcz.a },
		offset_rgb = { r = mcz.ro, g = mcz.go, b = mcz.bo },
		colorize_rgb = { r = mcz.cr, g = mcz.cg, b = mcz.cb },
		colorize_amount = mcz.amount,
		actual_wall_pierce_mode = bank.wall_pierce_mode,
		created_main = bank.created_main,
		created_sec = bank.created_sec,
		destroyed = bank.destroyed,
		cleanup_reason = bank.cleanup_reason,
		invalid_lamp_positions = bank.invalid_lamps,
		render_order_note = bank.render_order_note,
		ufo_callbacks = "back→main_back→hull→main_front→secondary→lamps",
		lamps = lamps,
	}
end

return L
