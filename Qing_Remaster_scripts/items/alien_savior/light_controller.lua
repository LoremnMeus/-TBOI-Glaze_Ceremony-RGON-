-- Per-layer Color/Alpha for Alien Savior UFO lights. Temporary visual state only.
local C = require("Qing_Remaster_scripts.items.alien_savior.constants")
local CFG = require("Qing_Remaster_scripts.items.alien_savior.light_config")

local LC = {}

local dbg = {
	enabled = false,
	mode = "rainbow", -- rainbow | white | off
	master_brightness = CFG.DEFAULTS.master_brightness,
	color_cycle = CFG.DEFAULTS.color_cycle,
	chase_cycle = CFG.DEFAULTS.chase_cycle,
	paused = false,
	step_pending = 0,
	virtual_age = 0,
	selected_layer = "ring_base",
	layer_override = {}, -- name -> {r,g,b,a,hide}
	force_ufo_alpha = nil,
	-- V4 core probe
	core_freeze = false,
	core_force_phase = nil,
	core_override = nil, -- optional full glow override table
	indicator_override = nil,
}

local cached = {
	age = -1,
	phase = nil,
	ufo_alpha = 1,
	colors = {}, -- name -> {r,g,b,a}
}

local function clamp01(x)
	if x < 0 then
		return 0
	end
	if x > 1 then
		return 1
	end
	return x
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function lerp3(c0, c1, t)
	return {
		lerp(c0[1], c1[1], t),
		lerp(c0[2], c1[2], t),
		lerp(c0[3], c1[3], t),
	}
end

local function sample_palette(palette, u)
	local n = #palette
	if n <= 0 then
		return { 1, 1, 1 }
	end
	local x = u % 1
	if x < 0 then
		x = x + 1
	end
	local f = x * n
	local i0 = math.floor(f) % n
	local i1 = (i0 + 1) % n
	local t = f - math.floor(f)
	return lerp3(palette[i0 + 1], palette[i1 + 1], t)
end

local function chase_boost(phase01)
	-- ((1+cos(2pi*p))/2)^3 → soft peak
	local c = 0.5 + 0.5 * math.cos(phase01 * math.pi * 2)
	local c3 = c * c * c
	return 0.65 + 0.35 * c3
end

local function ring_scan_phase(name, age, chase_cycle)
	local idx = CFG.RING_INDEX[name]
	if not idx then
		return 0
	end
	local n = #CFG.RING_SPATIAL
	local t = age / math.max(1, chase_cycle)
	return (t - (idx - 1) / n) % 1
end

local function x_to_ring_phase(x, age, chase_cycle)
	local xs = CFG.RING_SPATIAL
	local n = #xs
	local x0 = CFG.LAYER_X[xs[1]]
	local x1 = CFG.LAYER_X[xs[n]]
	local u = 0
	if x1 > x0 then
		u = clamp01((x - x0) / (x1 - x0)) * (n - 1)
	end
	local t = age / math.max(1, chase_cycle)
	return (t - u / n) % 1
end

local function phase_progress(txn)
	local dur = math.max(1, txn.phase_dur or 1)
	return clamp01((txn.phase_frame or 0) / dur)
end

local function ufo_alpha_of(txn)
	if dbg.force_ufo_alpha ~= nil then
		return clamp01(dbg.force_ufo_alpha)
	end
	-- Motion V1: size/alpha stay full; arrive/depart are positional, not fade/scale tricks.
	return 1
end

local function resolve_age(txn)
	if dbg.enabled and dbg.paused then
		return dbg.virtual_age
	end
	return (txn and txn.light_age) or dbg.virtual_age or 0
end

function LC.get_debug()
	return dbg
end

function LC.set_debug(patch)
	if not patch then
		return
	end
	for k, v in pairs(patch) do
		dbg[k] = v
	end
	cached.age = -1
end

function LC.reset_debug()
	dbg.mode = "rainbow"
	dbg.master_brightness = CFG.DEFAULTS.master_brightness
	dbg.color_cycle = CFG.DEFAULTS.color_cycle
	dbg.chase_cycle = CFG.DEFAULTS.chase_cycle
	dbg.paused = false
	dbg.step_pending = 0
	dbg.virtual_age = 0
	dbg.selected_layer = "ring_base"
	dbg.layer_override = {}
	dbg.force_ufo_alpha = nil
	dbg.core_freeze = false
	dbg.core_force_phase = nil
	dbg.core_override = nil
	dbg.indicator_override = nil
	cached.age = -1
end

local function copy3(v, fallback)
	v = v or fallback
	return { v[1] or 0, v[2] or 0, v[3] or 0 }
end

local function copy4(v, fallback)
	v = v or fallback
	return { v[1] or 0, v[2] or 0, v[3] or 0, v[4] or 0 }
end

local function ensure_glow_state(slot, target)
	if not slot.tint then
		slot.tint = copy3(target.tint, { 0.5, 0.85, 0.72 })
		slot.offset = copy3(target.offset, { 0.02, 0.05, 0.04 })
		slot.colorize = copy4(target.colorize, { 0.35, 0.95, 0.80, 0.15 })
		slot.pulse_weight = target.pulse_weight or 0.1
	end
end

local function approach3(cur, target, k)
	cur[1] = cur[1] + (target[1] - cur[1]) * k
	cur[2] = cur[2] + (target[2] - cur[2]) * k
	cur[3] = cur[3] + (target[3] - cur[3]) * k
end

local function approach4(cur, target, k)
	approach3(cur, target, k)
	cur[4] = cur[4] + ((target[4] or 0) - (cur[4] or 0)) * k
end

local function glow_target_for(table_map, phase)
	phase = dbg.core_force_phase or phase or "ARRIVING"
	return table_map[phase] or table_map.ARRIVING
end

local function tick_glow_slot(slot, target, smooth)
	if dbg.core_freeze then
		return
	end
	ensure_glow_state(slot, target)
	approach3(slot.tint, target.tint, smooth.tint or 0.16)
	approach3(slot.offset, target.offset, smooth.offset or 0.20)
	approach4(slot.colorize, target.colorize, smooth.colorize or 0.14)
	slot.pulse_weight = slot.pulse_weight
		+ ((target.pulse_weight or 0) - slot.pulse_weight) * (smooth.pulse or 0.16)
end

local function glow_to_color(slot, age, master)
	master = clamp01(master or 1)
	local pulse = math.sin((age or 0) * 0.28) * (slot.pulse_weight or 0)
	local tint = slot.tint
	local off = slot.offset
	local cz = slot.colorize
	-- Tint absorbs master brightness; Offset gets a small pulse lift (not alpha).
	local tr = clamp01((tint[1] or 1) * master)
	local tg = clamp01((tint[2] or 1) * master)
	local tb = clamp01((tint[3] or 1) * master)
	local or_ = clamp01((off[1] or 0) + pulse * 0.08)
	local og = clamp01((off[2] or 0) + pulse * 0.12)
	local ob = clamp01((off[3] or 0) + pulse * 0.10)
	return {
		r = tr,
		g = tg,
		b = tb,
		a = 1,
		offset = { or_, og, ob },
		colorize = { cz[1] or 0, cz[2] or 0, cz[3] or 0, clamp01((cz[4] or 0) * master) },
		use_glow = true,
	}
end

function LC.tick_debug(dt)
	dt = dt or 1
	if not dbg.enabled then
		return
	end
	if dbg.paused then
		if (dbg.step_pending or 0) > 0 then
			dbg.virtual_age = (dbg.virtual_age or 0) + dbg.step_pending
			dbg.step_pending = 0
			cached.age = -1
		end
		return
	end
	dbg.virtual_age = (dbg.virtual_age or 0) + dt
end

local function work_speed(txn)
	if not txn then
		return 1
	end
	if txn.phase == C.PHASE.ABDUCT_TARGETS or txn.phase == C.PHASE.LASER_SWEEP then
		return C.LIGHT_WORK_SPEED or 1.5
	end
	return 1
end

function LC.on_rescue_tick(txn)
	if not txn then
		return
	end
	local step = 1
	if dbg.enabled and dbg.paused then
		if (dbg.step_pending or 0) > 0 then
			step = dbg.step_pending
			dbg.step_pending = 0
		else
			return
		end
	end
	txn.light_age = (txn.light_age or 0) + step
	local color_cycle = math.max(1, dbg.color_cycle or CFG.DEFAULTS.color_cycle)
	local chase_cycle = math.max(1, dbg.chase_cycle or CFG.DEFAULTS.chase_cycle)
	local spd = work_speed(txn)
	txn.light_phase_color = (txn.light_phase_color or 0) + step * spd / color_cycle
	txn.light_phase_chase = (txn.light_phase_chase or 0) + step * spd / chase_cycle

	-- V4: continuous core / indicator glow (phase only sets targets).
	local phase = txn.phase or "ARRIVING"
	local smooth = CFG.CORE_SMOOTH or {}
	txn.core_lamp = txn.core_lamp or {}
	txn.indicator_lamp = txn.indicator_lamp or {}
	local core_tgt = glow_target_for(CFG.CORE_GLOW or {}, phase)
	local ind_tgt = glow_target_for(CFG.INDICATOR_GLOW or {}, phase)
	if dbg.core_override then
		core_tgt = dbg.core_override
	end
	if dbg.indicator_override then
		ind_tgt = dbg.indicator_override
	end
	for _ = 1, step do
		tick_glow_slot(txn.core_lamp, core_tgt, smooth)
		tick_glow_slot(txn.indicator_lamp, ind_tgt, smooth)
	end

	-- Tick secondary laser muzzle flash timers (visual only).
	if txn.laser_lamp_flash then
		for name, left in pairs(txn.laser_lamp_flash) do
			local n = (tonumber(left) or 0) - step
			if n <= 0 then
				txn.laser_lamp_flash[name] = nil
			else
				txn.laser_lamp_flash[name] = n
			end
		end
	end

	if dbg.enabled then
		dbg.virtual_age = txn.light_age
	end
	cached.age = -1
end

-- Solid lamp layers keep Alpha=1; brightness is RGB only (avoids hull punch-through holes).
local function solid_rgb(r, g, b, bright)
	bright = clamp01(bright or 1)
	return { r = r * bright, g = g * bright, b = b * bright, a = 1 }
end

local function base_color_for(layer, age, txn, master, color_phase, chase_phase)
	local name = layer.name
	local group = layer.group
	master = clamp01(master or 1)

	if group == "body" then
		return { r = 1, g = 1, b = 1, a = 1 }
	end

	-- Lights Off: keep opaque dark lamp bodies, do not punch holes.
	if dbg.mode == "off" then
		return solid_rgb(0.07, 0.07, 0.08, 1)
	end
	if dbg.mode == "white" then
		return solid_rgb(1, 1, 1, master)
	end

	if group == "ring_main" then
		local idx = CFG.RING_INDEX[name] or 1
		local n = #CFG.RING_SPATIAL
		local color_u = color_phase + (idx - 1) / n
		local rgb = sample_palette(CFG.RING_PALETTE, color_u)
		local b = chase_boost((chase_phase - (idx - 1) / n) % 1)
		return solid_rgb(rgb[1], rgb[2], rgb[3], b * master)
	end

	if group == "ring_red_markers" then
		local x = CFG.LAYER_X[name] or 128
		local xs = CFG.RING_SPATIAL
		local n = #xs
		local x0 = CFG.LAYER_X[xs[1]]
		local x1 = CFG.LAYER_X[xs[n]]
		local u = 0
		if x1 > x0 then
			u = clamp01((x - x0) / (x1 - x0)) * (n - 1)
		end
		local scan = (chase_phase - u / n) % 1
		local near = 0.5 + 0.5 * math.cos(scan * math.pi * 2)
		local pulse = near * near * near
		local dim = 0.28 + 0.12 * math.sin(age * 0.11 + x * 0.02)
		local bright = clamp01((dim + 0.72 * pulse) * master)
		return solid_rgb(
			lerp(0.55, 1.0, pulse),
			lerp(0.08, 0.55, pulse),
			lerp(0.05, 0.25, pulse),
			bright
		)
	end

	if group == "navigation_red" then
		local left = (CFG.LAYER_X[name] or 128) < 128
		local side = left and 0 or 0.5
		local flash = 0.5 + 0.5 * math.sin((age / math.max(1, CFG.DEFAULTS.nav_flash_cycle) + side) * math.pi * 2)
		local bright = (0.25 + 0.75 * (flash ^ 3)) * master
		return solid_rgb(0.95, 0.18 + 0.15 * bright, 0.08, bright)
	end

	if group == "bottom_blink_green" then
		local x = CFG.LAYER_X[name] or (40 + (layer.id % 30) * 6)
		local u = clamp01((x - 35) / 185)
		local chase = (age / math.max(1, CFG.DEFAULTS.bottom_chase_cycle) - u) % 1
		local peak = 0.5 + 0.5 * math.cos(chase * math.pi * 2)
		local bright = (0.45 + 0.55 * (peak ^ 2)) * master
		return solid_rgb(0.25, 0.95, 0.55 + 0.25 * peak, bright)
	end

	if group == "central_auxiliary" then
		local core = CFG.CORE_BY_PHASE[txn and txn.phase] or CFG.CORE_BY_PHASE.ABDUCT_TARGETS
		local breath = 0.75 + 0.25 * math.sin(age * 0.08)
		local bright = clamp01((core.a or 1) * breath * master * 0.85)
		return solid_rgb(core.r * 0.85, core.g, core.b * 0.9, bright)
	end

	if group == "cabin" then
		local u = age / math.max(1, CFG.DEFAULTS.cabin_cycle)
		local rgb = sample_palette(CFG.CABIN_COLORS, u)
		local breath = 0.7 + 0.3 * (0.5 + 0.5 * math.sin(u * math.pi * 2))
		return solid_rgb(rgb[1], rgb[2], rgb[3], breath * master)
	end

	if group == "bottom_core" or group == "bottom_core_indicators" then
		-- Handled in evaluate() via continuous glow state (Tint/Offset/Colorize).
		return solid_rgb(0.7, 0.95, 0.85, master)
	end

	return solid_rgb(0.6, 0.6, 0.6, 0.5 * master)
end

function LC.evaluate(txn)
	local age = resolve_age(txn)
	local phase = txn and txn.phase or "NONE"
	local master = clamp01(dbg.master_brightness or CFG.DEFAULTS.master_brightness)
	local color_phase = (txn and txn.light_phase_color) or (age / math.max(1, dbg.color_cycle or CFG.DEFAULTS.color_cycle))
	local chase_phase = (txn and txn.light_phase_chase) or (age / math.max(1, dbg.chase_cycle or CFG.DEFAULTS.chase_cycle))
	local ufo_a = ufo_alpha_of(txn)

	if cached.age == age and cached.phase == phase and cached.ufo_alpha == ufo_a
		and cached.master == master and cached.mode == dbg.mode
		and cached.color_phase == color_phase and cached.chase_phase == chase_phase
	then
		return cached.colors, ufo_a
	end

	-- Ensure glow states exist even before first tick (force-phase / first render).
	if txn then
		txn.core_lamp = txn.core_lamp or {}
		txn.indicator_lamp = txn.indicator_lamp or {}
		local phase = txn.phase or "ARRIVING"
		ensure_glow_state(txn.core_lamp, glow_target_for(CFG.CORE_GLOW or {}, phase))
		ensure_glow_state(txn.indicator_lamp, glow_target_for(CFG.INDICATOR_GLOW or {}, phase))
	end

	local colors = {}
	for _, layer in ipairs(CFG.LAYERS) do
		local c
		if layer.group == "bottom_core" and txn and txn.core_lamp then
			if dbg.mode == "off" then
				c = {
					r = 0.08, g = 0.1, b = 0.1, a = 1,
					offset = { 0, 0, 0 },
					colorize = { 0.2, 0.3, 0.3, 0.05 },
					use_glow = true,
				}
			elseif dbg.mode == "white" then
				c = {
					r = master, g = master, b = master, a = 1,
					offset = { 0.05 * master, 0.05 * master, 0.05 * master },
					colorize = { 1, 1, 1, 0 },
					use_glow = true,
				}
			else
				c = glow_to_color(txn.core_lamp, age, master)
			end
		elseif layer.group == "bottom_core_indicators" and txn and txn.indicator_lamp then
			if dbg.mode == "off" then
				c = {
					r = 0.08, g = 0.1, b = 0.1, a = 1,
					offset = { 0, 0, 0 },
					colorize = { 0.2, 0.35, 0.3, 0.05 },
					use_glow = true,
				}
			elseif dbg.mode == "white" then
				c = {
					r = master, g = master, b = master, a = 1,
					offset = { 0.04 * master, 0.04 * master, 0.04 * master },
					colorize = { 1, 1, 1, 0 },
					use_glow = true,
				}
			else
				c = glow_to_color(txn.indicator_lamp, age, master)
			end
		else
			c = base_color_for(layer, age, txn, master, color_phase, chase_phase)
		end
		local ov = dbg.layer_override[layer.name]
		if ov then
			if ov.hide then
				-- Explicit Hide Layer debug only — not Lights Off.
				c.a = 0
			else
				if ov.r ~= nil then c.r = ov.r end
				if ov.g ~= nil then c.g = ov.g end
				if ov.b ~= nil then c.b = ov.b end
				if ov.a ~= nil then c.a = ov.a end
			end
		end
		-- Solid layers stay opaque; only explicit hide / rare overrides may lower alpha.
		if layer.group ~= "body" and (not ov or not ov.hide) and (ov == nil or ov.a == nil) then
			c.a = 1
		end
		-- Brief muzzle flash boost from laser_controller secondary fire.
		local flash = txn and txn.laser_lamp_flash and txn.laser_lamp_flash[layer.name]
		if type(flash) == "number" and flash > 0 then
			local boost = 1.35
			c.r = clamp01((c.r or 0) * boost)
			c.g = clamp01((c.g or 0) * boost)
			c.b = clamp01((c.b or 0) * boost)
		end
		c.a = clamp01((c.a or 1) * ufo_a)
		colors[layer.name] = c
	end

	cached.age = age
	cached.phase = phase
	cached.ufo_alpha = ufo_a
	cached.master = master
	cached.mode = dbg.mode
	cached.color_phase = color_phase
	cached.chase_phase = chase_phase
	cached.colors = colors
	return colors, ufo_a
end

--- Live lamp RGB used by UFO render (same evaluate path). For laser Colorize inheritance.
function LC.get_layer_color(txn, layer_name)
	if not layer_name then
		return nil
	end
	local colors = LC.evaluate(txn)
	return colors and colors[layer_name] or nil
end

function LC.flash_layer(txn, layer_name, frames)
	if not txn or not layer_name then
		return
	end
	txn.laser_lamp_flash = txn.laser_lamp_flash or {}
	txn.laser_lamp_flash[layer_name] = frames or 6
	cached.age = -1
end

function LC.summary_line(txn)
	local age = resolve_age(txn)
	return string.format(
		"light mode=%s age=%d pause=%s bright=%.2f color=%df chase=%df sel=%s",
		tostring(dbg.mode),
		age,
		tostring(dbg.paused),
		dbg.master_brightness or 0,
		dbg.color_cycle or 0,
		dbg.chase_cycle or 0,
		tostring(dbg.selected_layer)
	)
end

function LC.layer_names()
	local names = {}
	for _, layer in ipairs(CFG.LAYERS) do
		names[#names + 1] = layer.name
	end
	return names
end

return LC
