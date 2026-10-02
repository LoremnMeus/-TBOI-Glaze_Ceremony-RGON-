-- 夜之摄取视觉 V5：Charging 稳定 Focus + 朝内锥；Fang depth cap；Blackout/Recover 不画牙
-- Night Body / Noise 可深入；牙属边界；Release 对焦+后缩预备；Recover 只退幕不退牙。

local ANM2_H = "gfx/mimics/Ingestion_to_Night/Ingestion_Noise_H.anm2"
local ANM2_V = "gfx/mimics/Ingestion_to_Night/Ingestion_Noise_V.anm2"
local ANM2_FANG = "gfx/mimics/Ingestion_to_Night/Ingestion_Fang.anm2"
local ANM2_FANG_ROOT = "gfx/mimics/Ingestion_to_Night/Ingestion_Fang_Root.anm2"
local ANM2_BODY = "gfx/mimics/Ingestion_to_Night/Ingestion_Night_Body.anm2"
local ANM2_FILL = "gfx/mimics/Ingestion_to_Night/Ingestion_Blackout.anm2"

local SHEET_EDGE = {
	top = {
		coarse = "gfx/mimics/Ingestion_to_Night/night_noise_top_coarse.png",
		medium = "gfx/mimics/Ingestion_to_Night/night_noise_top_medium.png",
		detail = "gfx/mimics/Ingestion_to_Night/night_noise_top_detail.png",
	},
	bottom = {
		coarse = "gfx/mimics/Ingestion_to_Night/night_noise_bottom_coarse.png",
		medium = "gfx/mimics/Ingestion_to_Night/night_noise_bottom_medium.png",
		detail = "gfx/mimics/Ingestion_to_Night/night_noise_bottom_detail.png",
	},
	left = {
		coarse = "gfx/mimics/Ingestion_to_Night/night_noise_left_coarse.png",
		medium = "gfx/mimics/Ingestion_to_Night/night_noise_left_medium.png",
		detail = "gfx/mimics/Ingestion_to_Night/night_noise_left_detail.png",
	},
	right = {
		coarse = "gfx/mimics/Ingestion_to_Night/night_noise_right_coarse.png",
		medium = "gfx/mimics/Ingestion_to_Night/night_noise_right_medium.png",
		detail = "gfx/mimics/Ingestion_to_Night/night_noise_right_detail.png",
	},
}
local SHEET_FANG = "gfx/mimics/Ingestion_to_Night/fang_soft.png"
local SHEET_FANG_ROOT = "gfx/mimics/Ingestion_to_Night/fang_root_fade.png"
local SHEET_BODY = "gfx/mimics/Ingestion_to_Night/night_body_mask.png"
local SHEET_FILL = "gfx/mimics/Ingestion_to_Night/black_noise_fill.png"

-- fang_soft 尖端朝右；96×32，Pivot 在透明根部过渡区 (10,16)
local FANG_ROTATION_OFFSET = 0
local FANG_TEX_W = 96
local FANG_TEX_H = 32

local EDGES = {"top", "bottom", "left", "right"}
local LAYER_KEYS = {"coarse", "medium", "detail"}

local LAYER_DEF = {
	coarse = {a = 0.62, depth_mul = 1.00, scale = 1.02, drift = 0.12},
	medium = {a = 0.38, depth_mul = 1.12, scale = 1.08, drift = -0.18},
	detail = {a = 0.22, depth_mul = 1.28, scale = 1.16, drift = 0.28},
}

local DEFAULTS = {
	base_depth = 1.0,
	noise_amp = 1.0,
	noise_alpha = 1.0,
	drift_speed = 1.0,
	fang_count = 5, -- per edge
	fang_length = 1.0,
	fang_width = 1.0,
	fang_alpha = 1.0,
	reveal_start = 60,
	reveal_full = 180,
	bite_duration = 36,
	blackout_duration = 18,
	rim_boost = 1.0,
	recover_duration = 20,
	recover_black_hold = 8,
	recover_black_fade = 8,
	-- Night Body Mask
	body_alpha_max = 0.85,
	body_alpha_start = 10,
	body_alpha_full = 175,
	-- Bite / Release snapshot
	closure_margin = 40,
	fang_closure_radius = 34,
	bite_move_start = 10,
	bite_move_end = 20,
	bite_anticipation = 8,
	-- Charging aim: stable focus + inward cone
	fang_aim_cone = 42,
	fang_angle_bias_span = 8, -- ±4°
	charge_focus_follow = 0.015,
	charge_focus_max_offset = 70,
	fang_depth_cap_vertical = 0.22,
	fang_depth_cap_horizontal = 0.18,
	-- Fang root embed / fade
	fang_embed_min = 18,
	fang_embed_ratio = 0.30,
	fang_root_alpha = 0.32,
	fang_root_scale = 1.0,
	-- post-fang noise cover multipliers
	medium_cover_mul = 0.38,
	detail_cover_mul = 0.28,
}

local vis = {
	params = {},
	debug_force_counter = nil,
	debug_preview_bite = false,
	debug_freeze_release_t = nil,
	FANG_ROTATION_OFFSET = FANG_ROTATION_OFFSET,
}

for k, v in pairs(DEFAULTS) do
	vis.params[k] = v
end

local function copy_defaults()
	local t = {}
	for k, v in pairs(DEFAULTS) do t[k] = v end
	return t
end

function vis.reset_params()
	vis.params = copy_defaults()
	vis.debug_force_counter = nil
	vis.debug_preview_bite = false
	vis.debug_freeze_release_t = nil
end

function vis.set_param(key, value)
	if DEFAULTS[key] ~= nil and type(value) == "number" then
		vis.params[key] = value
	end
end

function vis.get_params()
	return vis.params
end

function vis.get_defaults()
	return copy_defaults()
end

function vis.get_viewport_rect()
	local w = Isaac.GetScreenWidth()
	local h = Isaac.GetScreenHeight()
	return 0, 0, w, h
end

function vis.world_to_screen(pos)
	return Isaac.WorldToScreen(pos)
end

local function hash01(i, seed)
	local n = (i * 374761393 + seed * 1274126177) % 2147483647
	n = (n ~ math.floor(n / 8192)) * 1274126177 % 2147483647
	return (n % 65536) / 65535
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function clamp(x, a, b)
	if x < a then return a end
	if x > b then return b end
	return x
end

local function ease_in_cubic(t)
	return t * t * t
end

local function smoothstep(a, b, x)
	if x <= a then return 0 end
	if x >= b then return 1 end
	local t = (x - a) / (b - a)
	return t * t * (3 - 2 * t)
end

local function shortest_angle_delta(a, b)
	return ((b - a + 180) % 360) - 180
end

local function lerp_angle(a, b, t)
	return a + shortest_angle_delta(a, b) * t
end

local function clamp_angle_around(angle, center, max_delta)
	local d = shortest_angle_delta(center, angle)
	d = clamp(d, -max_delta, max_delta)
	return center + d
end

local function inward_angle(edge)
	if edge == "top" then
		return 90
	elseif edge == "bottom" then
		return -90
	elseif edge == "left" then
		return 0
	else
		return 180
	end
end

local function depth_from_counter(c)
	c = c or 0
	local p = vis.params
	local d
	if c <= 0 then
		d = 0
	elseif c < 60 then
		d = lerp(0, 25, c / 60)
	elseif c < 120 then
		d = lerp(25, 60, (c - 60) / 60)
	elseif c < 170 then
		d = lerp(60, 95, (c - 120) / 50)
	elseif c < 180 then
		d = lerp(95, 115, (c - 170) / 10)
	else
		d = lerp(115, 130, math.min(1, (c - 180) / 60))
	end
	return d * (p.base_depth or 1)
end

local function fang_morph(c)
	local length_m, width_m, alpha_m, jitter_m
	if c < 60 then
		local u = c / 60
		length_m = lerp(0.05, 0.15, u)
		width_m = lerp(2.0, 1.7, u)
		alpha_m = lerp(0.03, 0.08, u)
		jitter_m = 1.0
	elseif c < 120 then
		local u = (c - 60) / 60
		length_m = lerp(0.15, 0.40, u)
		width_m = lerp(1.8, 1.4, u)
		alpha_m = lerp(0.08, 0.18, u)
		jitter_m = 0.85
	elseif c < 170 then
		local u = (c - 120) / 50
		length_m = lerp(0.40, 0.80, u)
		width_m = lerp(1.4, 1.0, u)
		alpha_m = lerp(0.18, 0.50, u)
		jitter_m = lerp(0.7, 0.25, u)
	elseif c < 180 then
		local u = (c - 170) / 10
		length_m = lerp(0.80, 1.0, u)
		width_m = lerp(1.0, 0.85, u)
		alpha_m = lerp(0.50, 0.80, u)
		jitter_m = lerp(0.25, 0.05, u)
	else
		length_m = 1.0
		width_m = 0.85
		alpha_m = 0.85
		jitter_m = 0
	end
	return length_m, width_m, alpha_m, jitter_m
end

local overlay = {
	active = false,
	counter = 0,
	release_t = 0,
	phase = "idle",
	player_screen = Vector(0, 0),
	pitch_black = false,
	reverse_sun = false,
	seed = 1,
	fangs = nil,
	edge_noise = nil,
	noise_phase = 0,
	damage_resolved = false,
	release_initialized = false,
	release_player_screen = nil,
	release_edge_depths = nil,
	release_edge_targets = nil,
	charge_focus_screen = nil,
}

-- edge sprites: [edge][layer]; body/fill are single sprites
local sprites = {
	edge = {},
	fangs = {},
	fang_roots = {},
	body = nil,
	fill = nil,
}

local function ensure_sprite(cache, key, anm2, sheet)
	if cache[key] == nil then
		local s = Sprite()
		s:Load(anm2, true)
		if sheet then
			s:ReplaceSpritesheet(0, sheet)
			s:LoadGraphics()
		end
		s:Play("Idle", true)
		cache[key] = s
	end
	return cache[key]
end

local function ensure_all_sprites()
	for _, edge in ipairs(EDGES) do
		sprites.edge[edge] = sprites.edge[edge] or {}
		local sheets = SHEET_EDGE[edge]
		local anm2 = (edge == "top" or edge == "bottom") and ANM2_H or ANM2_V
		for _, layer in ipairs(LAYER_KEYS) do
			ensure_sprite(sprites.edge[edge], layer, anm2, sheets[layer])
		end
	end
	local nfang = math.max(1, math.floor((vis.params.fang_count or 5) * 4))
	for i = 1, nfang do
		ensure_sprite(sprites.fangs, i, ANM2_FANG, SHEET_FANG)
		ensure_sprite(sprites.fang_roots, i, ANM2_FANG_ROOT, SHEET_FANG_ROOT)
	end
	if sprites.body == nil then
		sprites.body = Sprite()
		sprites.body:Load(ANM2_BODY, true)
		sprites.body:ReplaceSpritesheet(0, SHEET_BODY)
		sprites.body:LoadGraphics()
		sprites.body:Play("Idle", true)
	end
	if sprites.fill == nil then
		sprites.fill = Sprite()
		sprites.fill:Load(ANM2_FILL, true)
		sprites.fill:ReplaceSpritesheet(0, SHEET_FILL)
		sprites.fill:LoadGraphics()
		sprites.fill:Play("Idle", true)
	end
end

local function rebuild_candidates(seed)
	local fangs = {}
	local edge_noise = {}
	local per = math.max(3, math.floor(vis.params.fang_count or 5))
	local idx = 0
	for ei, edge in ipairs(EDGES) do
		edge_noise[edge] = {}
		for i = 1, 12 do
			edge_noise[edge][i] = {
				n0 = hash01(ei * 100 + i, seed),
				n1 = hash01(ei * 100 + i, seed + 19),
				vel = 0.002 + hash01(ei * 50 + i, seed + 3) * 0.004,
				phase = hash01(ei * 70 + i, seed + 5),
			}
		end
		for i = 1, per do
			idx = idx + 1
			local bias_span = vis.params.fang_angle_bias_span or 8
			local angle_bias = (hash01(idx, seed + 12) - 0.5) * bias_span -- ±4°
			fangs[#fangs + 1] = {
				edge = edge,
				along = (i - 0.5) / per + (hash01(idx, seed) - 0.5) * 0.08,
				target_len = 28 + hash01(idx, seed + 2) * 34,
				base_width = 0.85 + hash01(idx, seed + 4) * 0.4,
				alpha_bias = 0.85 + hash01(idx, seed + 6) * 0.3,
				phase = hash01(idx, seed + 8),
				jitter = hash01(idx, seed + 10),
				sprite_i = idx,
				angle_bias = angle_bias,
				charge_angle = inward_angle(edge) + angle_bias + FANG_ROTATION_OFFSET,
			}
		end
	end
	overlay.fangs = fangs
	overlay.edge_noise = edge_noise
	overlay.seed = seed
	overlay.charge_focus_screen = nil
end

local function clear_release_snapshot()
	overlay.release_initialized = false
	overlay.release_player_screen = nil
	overlay.release_edge_depths = nil
	overlay.release_edge_targets = nil
	if overlay.fangs then
		for _, f in ipairs(overlay.fangs) do
			f.release_root = nil
			f.bite_dir = nil
			f.bite_angle = nil
			f.bite_max_travel = nil
		end
	end
end

function vis.clear_all()
	overlay.active = false
	overlay.counter = 0
	overlay.release_t = 0
	overlay.phase = "idle"
	overlay.damage_resolved = false
	overlay.fangs = nil
	overlay.edge_noise = nil
	overlay.charge_focus_screen = nil
	clear_release_snapshot()
	sprites = {edge = {}, fangs = {}, fang_roots = {}, body = nil, fill = nil}
end

local function segment_depth(edge, base, i)
	local p = vis.params
	local en = overlay.edge_noise and overlay.edge_noise[edge]
	if not en or not en[i] then return base end
	local e = en[i]
	local ph = overlay.noise_phase * e.vel * 60 + e.phase
	local wave = math.sin(ph * math.pi * 2) * 0.5 + 0.5
	local n = lerp(e.n0, e.n1, wave)
	return base + (n - 0.5) * 18 * (p.noise_amp or 1)
end

local function get_visual_edge_depth(edge, base_depth, sample_index)
	local coarse = segment_depth(edge, base_depth * 1.00, sample_index)
	local medium = segment_depth(edge, base_depth * 1.12, sample_index + 3)
	return math.max(coarse * 0.88, medium * 0.90)
end

local function edge_root_line(edge, depth, sw, sh)
	if edge == "top" then
		return Vector(0, depth), Vector(sw, depth), Vector(0, 1)
	elseif edge == "bottom" then
		return Vector(0, sh - depth), Vector(sw, sh - depth), Vector(0, -1)
	elseif edge == "left" then
		return Vector(depth, 0), Vector(depth, sh), Vector(1, 0)
	else
		return Vector(sw - depth, 0), Vector(sw - depth, sh), Vector(-1, 0)
	end
end

local function edge_inward(edge)
	if edge == "top" then return Vector(0, 1)
	elseif edge == "bottom" then return Vector(0, -1)
	elseif edge == "left" then return Vector(1, 0)
	else return Vector(-1, 0)
	end
end

local function fang_depth_cap(edge, sw, sh)
	local p = vis.params
	if edge == "top" or edge == "bottom" then
		return sh * (p.fang_depth_cap_vertical or 0.22)
	end
	return sw * (p.fang_depth_cap_horizontal or 0.18)
end

local function charging_fang_root(f, edge_depths, sw, sh, length_m, jitter_m)
	local p = vis.params
	local base = edge_depths[f.edge] or 0
	local depth = get_visual_edge_depth(f.edge, base, 1 + (f.sprite_i % 8))
	depth = math.min(depth, fang_depth_cap(f.edge, sw, sh))
	local a, b, inward = edge_root_line(f.edge, depth, sw, sh)
	local along = clamp(f.along, 0.05, 0.95)
	local root = a + (b - a) * along
	local len_px = f.target_len * length_m
	local embed = math.max(p.fang_embed_min or 18, len_px * (p.fang_embed_ratio or 0.30))
	root = root - inward * embed
	local j = (hash01(f.sprite_i, overlay.seed + math.floor(overlay.noise_phase * 3)) - 0.5) * 10 * jitter_m
	if f.edge == "top" or f.edge == "bottom" then
		root = root + Vector(j, 0)
	else
		root = root + Vector(0, j)
	end
	return root, inward, depth
end

local function update_charge_focus(sw, sh)
	local player = overlay.player_screen
	if not player then return end
	local p = vis.params
	local center = Vector(sw * 0.5, sh * 0.5)
	local max_off = p.charge_focus_max_offset or 70
	local offset = player - center
	if offset:Length() > max_off then
		offset = offset:Resized(max_off)
	end
	local target = center + offset
	if overlay.charge_focus_screen == nil then
		overlay.charge_focus_screen = Vector(target.X, target.Y)
		return
	end
	local follow = p.charge_focus_follow or 0.015
	local cur = overlay.charge_focus_screen
	overlay.charge_focus_screen = cur + (target - cur) * follow
end

local function charging_aim_angle(f, root)
	local p = vis.params
	local base = inward_angle(f.edge)
	local focus = overlay.charge_focus_screen or overlay.player_screen
	local desired = base
	if focus and root then
		local delta = focus - root
		if delta:Length() > 0.01 then
			desired = delta:GetAngleDegrees()
		end
	end
	local cone = p.fang_aim_cone or 42
	return clamp_angle_around(desired, base, cone) + (f.angle_bias or 0) + FANG_ROTATION_OFFSET
end

local function anticipation_offset(release_t)
	local p = vis.params
	local amt = p.bite_anticipation or 8
	local move_start = p.bite_move_start or 10
	if release_t < 4 or release_t >= move_start then
		return 0
	end
	local u = smoothstep(4, math.max(5, move_start - 1), release_t)
	return math.sin(u * math.pi) * amt
end

local function blackout_strength(phase, release_t)
	local p = vis.params
	local move_end = p.bite_move_end or 20
	if phase == "blackout" then
		return math.min(1, release_t / 4)
	elseif phase == "releasing" and release_t >= move_end then
		return math.min(1, (release_t - move_end) / 4)
	elseif phase == "recover" then
		local hold = p.recover_black_hold or 8
		local fade = p.recover_black_fade or 8
		if release_t <= hold then
			return 1
		end
		return 1 - smoothstep(hold, hold + fade, release_t)
	end
	return 0
end

local function release_progress(release_t)
	local p = vis.params
	local start_t = p.bite_move_start or 10
	local end_t = p.bite_move_end or 20
	if release_t < start_t then return 0 end
	return ease_in_cubic(clamp((release_t - start_t) / math.max(1, end_t - start_t), 0, 1))
end

local function compute_edge_targets(player_s, sw, sh)
	local m = vis.params.closure_margin or 40
	return {
		top = math.max(0, player_s.Y - m),
		bottom = math.max(0, sh - player_s.Y - m),
		left = math.max(0, player_s.X - m),
		right = math.max(0, sw - player_s.X - m),
	}
end

local function current_edge_depths_charging(base)
	return {top = base, bottom = base, left = base, right = base}
end

local function get_edge_depths_for_frame(sw, sh, counter, phase, release_t)
	local base = depth_from_counter(counter)
	if phase == "releasing" or phase == "blackout" then
		if not overlay.release_initialized then
			return current_edge_depths_charging(base)
		end
		local t = 1
		if phase == "releasing" then
			t = release_progress(release_t)
		end
		local starts = overlay.release_edge_depths
		local targets = overlay.release_edge_targets
		local out = {}
		for _, edge in ipairs(EDGES) do
			out[edge] = lerp(starts[edge] or base, targets[edge] or base, t)
		end
		return out
	elseif phase == "recover" then
		local u = clamp(release_t / math.max(1, vis.params.recover_duration or 20), 0, 1)
		if overlay.release_edge_targets then
			local out = {}
			for _, edge in ipairs(EDGES) do
				out[edge] = lerp(overlay.release_edge_targets[edge] or base, base * 0.35, u)
			end
			return out
		end
	end
	return current_edge_depths_charging(base)
end

local function initialize_release_snapshot(sw, sh, counter)
	if overlay.release_initialized then return end
	local player_s = overlay.player_screen
	overlay.release_player_screen = Vector(player_s.X, player_s.Y)
	local base = depth_from_counter(counter)
	local starts = current_edge_depths_charging(base)
	local visual_starts = {}
	for _, edge in ipairs(EDGES) do
		visual_starts[edge] = get_visual_edge_depth(edge, starts[edge], 2)
	end
	overlay.release_edge_depths = visual_starts
	overlay.release_edge_targets = compute_edge_targets(overlay.release_player_screen, sw, sh)

	local length_m = select(1, fang_morph(counter)) * (vis.params.fang_length or 1)
	local radius = vis.params.fang_closure_radius or 34
	local fangs = overlay.fangs
	if fangs then
		for _, f in ipairs(fangs) do
			local root, inward = charging_fang_root(f, visual_starts, sw, sh, length_m, 0)
			local delta = overlay.release_player_screen - root
			local dir
			if delta:Length() > 0.01 then
				dir = delta:Normalized()
			else
				dir = inward
			end
			f.release_root = Vector(root.X, root.Y)
			f.bite_dir = dir
			f.bite_angle = dir:GetAngleDegrees() + FANG_ROTATION_OFFSET
			-- 冻结松手前的蓄力朝向，供 4–move_start 对焦插值
			f.charge_angle = charging_aim_angle(f, root)
			local dist = (overlay.release_player_screen - f.release_root):Length()
			f.bite_max_travel = math.max(0, dist - radius)
		end
	end
	overlay.release_initialized = true
end

function vis.set_frame_state(st)
	st = st or {}
	local prev_phase = overlay.phase
	overlay.active = st.active == true
	overlay.counter = st.counter or 0
	if vis.debug_force_counter ~= nil then
		overlay.counter = vis.debug_force_counter
		overlay.active = overlay.counter > 0 or (st.phase and st.phase ~= "idle")
	end
	overlay.release_t = st.release_t or 0
	if vis.debug_freeze_release_t ~= nil then
		overlay.release_t = vis.debug_freeze_release_t
	end
	overlay.phase = st.phase or "idle"
	overlay.player_screen = st.player_screen or overlay.player_screen
	overlay.pitch_black = st.pitch_black == true
	overlay.reverse_sun = st.reverse_sun == true
	if st.damage_resolved ~= nil then
		overlay.damage_resolved = st.damage_resolved
	end
	if overlay.active and overlay.fangs == nil then
		rebuild_candidates(st.seed or (Game():GetRoom():GetSpawnSeed() % 100000))
	end
	if not overlay.active then
		overlay.fangs = nil
		overlay.edge_noise = nil
		overlay.charge_focus_screen = nil
		clear_release_snapshot()
	elseif overlay.phase ~= "releasing" and overlay.phase ~= "blackout" and overlay.phase ~= "recover" then
		clear_release_snapshot()
	elseif prev_phase == "recover" and overlay.phase == "idle" then
		clear_release_snapshot()
		overlay.charge_focus_screen = nil
	end
end

function vis.get_overlay()
	return overlay
end

local function bite_focus_screen()
	if overlay.release_player_screen then
		return overlay.release_player_screen
	end
	return overlay.player_screen
end

local function night_body_alpha(counter, phase, release_t)
	local p = vis.params
	local a = smoothstep(p.body_alpha_start or 10, p.body_alpha_full or 175, counter)
	a = a * (p.body_alpha_max or 0.85)
	if phase == "releasing" or phase == "blackout" then
		a = math.min(0.95, a * (1.0 + 0.15 * release_progress(release_t)))
	elseif phase == "recover" then
		local u = clamp(release_t / math.max(1, p.recover_duration or 20), 0, 1)
		a = a * (1 - u)
	end
	return a
end

--- 单张连续夜幕 mask（非四边矩形）
local function render_night_body(sw, sh, counter, phase, release_t, alpha_mul)
	local spr = sprites.body
	if not spr then return end
	local p = vis.params
	local alpha = night_body_alpha(counter, phase, release_t) * alpha_mul
	if alpha < 0.01 then return end
	if overlay.pitch_black then
		alpha = alpha * 0.30
	end

	local progress = clamp(counter / 180, 0, 1)
	-- Scale 越小，中央透明窗口越小（mask 外围黑）
	local scale_mul = lerp(1.65, 0.92, smoothstep(0, 1, progress))

	if phase == "releasing" or phase == "blackout" then
		local bite = release_progress(release_t)
		scale_mul = lerp(scale_mul, 0.55, bite)
		alpha = math.min(0.95, alpha * (1 + bite * 0.18))
	elseif phase == "recover" then
		local u = clamp(release_t / math.max(1, p.recover_duration or 20), 0, 1)
		scale_mul = lerp(0.55, 1.70, u)
		alpha = alpha * (1 - u)
	end

	local screen_center = Vector(sw * 0.5, sh * 0.5)
	local player = bite_focus_screen()
	local offset = player - screen_center
	if offset:Length() > 50 then
		offset = offset:Resized(50)
	end
	local body_center = screen_center + offset * 0.30

	-- Body tex is 1024 with solid dark pad around the old 512 hole.
	-- Keep hole on-screen size (= old 512 * 1.35 * scale_mul), but outer coverage ~2× so bite at 0.55 still fills the screen.
	local body_tex = 1024
	local cover = 2.70
	local sx = (sw / body_tex) * cover * scale_mul
	local sy = (sh / body_tex) * cover * scale_mul
	spr.Scale = Vector(sx, sy)
	spr.Rotation = 0
	spr.Color = Color(1, 1, 1, alpha, 0, 0, 0)
	spr:Render(body_center, Vector(0, 0), Vector(0, 0))
end

local function render_curtain_layer(edge, layer_key, base_depth, sw, sh, alpha_mul, detail_mul)
	local L = LAYER_DEF[layer_key]
	if not L then return end
	local p = vis.params
	local depth = math.max(0, base_depth)
	if depth < 1 then return end
	local sample = ({coarse = 3, medium = 6, detail = 9})[layer_key] or 3
	local dseg = segment_depth(edge, depth * L.depth_mul, sample)
	local base_a = L.a
	if layer_key == "detail" then
		base_a = base_a * detail_mul
	end
	local a = base_a * (p.noise_alpha or 1) * alpha_mul
	if a < 0.01 then return end
	local drift = overlay.noise_phase * L.drift * (p.drift_speed or 1)
	local col = Color(1, 1, 1, a, 0, 0, 0)
	local spr = sprites.edge[edge] and sprites.edge[edge][layer_key]
	if not spr then return end
	spr.Color = col
	spr.Rotation = 0
	-- 四向独立贴图：全部正 Scale，不再翻转
	if edge == "top" or edge == "bottom" then
		local sx = (sw / 512) * L.scale
		local sy = (dseg / 128) * L.scale
		spr.Scale = Vector(sx, sy)
		local y = (edge == "top") and (dseg * 0.5) or (sh - dseg * 0.5)
		spr:Render(Vector(sw * 0.5 + drift * 8, y), Vector(0, 0), Vector(0, 0))
	else
		local sx = (dseg / 128) * L.scale
		local sy = (sh / 512) * L.scale
		spr.Scale = Vector(sx, sy)
		local x = (edge == "left") and (dseg * 0.5) or (sw - dseg * 0.5)
		spr:Render(Vector(x, sh * 0.5 + drift * 8), Vector(0, 0), Vector(0, 0))
	end
end

local function fang_draw_state(counter, release_boost, phase, release_t)
	local p = vis.params
	local length_m, width_m, alpha_m, jitter_m = fang_morph(counter)
	length_m = length_m * (p.fang_length or 1)
	width_m = width_m * (p.fang_width or 1)
	alpha_m = alpha_m * (p.fang_alpha or 1)
	if release_boost > 0 then
		length_m = math.min(1.15, length_m + release_boost * 0.25)
		alpha_m = math.min(1, alpha_m + release_boost * 0.35)
		width_m = math.max(0.75, width_m - release_boost * 0.1)
		jitter_m = jitter_m * (1 - release_boost)
	end
	if phase == "releasing" or phase == "blackout" then
		jitter_m = 0
	end
	local rim = 1.0
	if overlay.pitch_black then
		rim = rim * (1.25 * (p.rim_boost or 1))
		alpha_m = math.min(1, alpha_m * 1.1)
	end
	if overlay.reverse_sun then
		rim = rim * 1.05
	end
	return length_m, width_m, alpha_m, jitter_m, rim
end

local function resolve_fang_pose(f, edge_depths, sw, sh, length_m, jitter_m, phase, release_t)
	local inward = edge_inward(f.edge)
	local move_start = vis.params.bite_move_start or 10

	-- Release：快照轨迹；4–move_start 对焦+后缩；之后咬合。Blackout/Recover 不渲染牙。
	if phase == "releasing" and f.release_root and f.bite_dir and f.bite_angle then
		local move_t = release_progress(release_t)
		local anti = anticipation_offset(release_t)
		local root = f.release_root + f.bite_dir * ((f.bite_max_travel or 0) * move_t) - f.bite_dir * anti

		local ang
		if release_t < move_start then
			local turn_t = smoothstep(4, move_start, release_t)
			ang = lerp_angle(f.charge_angle or f.bite_angle, f.bite_angle, turn_t)
		else
			ang = f.bite_angle
		end
		local dir = Vector.FromAngle(ang - FANG_ROTATION_OFFSET)
		return root, dir, ang, inward
	end

	-- Charging：朝向稳定 Focus，限制在边内锥
	local root, inward2 = charging_fang_root(f, edge_depths, sw, sh, length_m, jitter_m)
	local ang = charging_aim_angle(f, root)
	f.charge_angle = ang
	local dir = Vector.FromAngle(ang - FANG_ROTATION_OFFSET)
	return root, dir, ang, inward2
end

local function render_fang_root_patches(edge_depths, sw, sh, counter, release_boost, phase, release_t)
	local fangs = overlay.fangs
	if not fangs then return end
	local p = vis.params
	local length_m, width_m, alpha_m, jitter_m = fang_draw_state(counter, release_boost, phase, release_t)
	local root_alpha = (p.fang_root_alpha or 0.32) * alpha_m
	if root_alpha < 0.015 then return end
	local scale_mul = p.fang_root_scale or 1.0
	for _, f in ipairs(fangs) do
		local depth = edge_depths[f.edge] or 0
		if depth < 4 then goto continue end
		local root, dir, ang = resolve_fang_pose(f, edge_depths, sw, sh, length_m, jitter_m, phase, release_t)
		local spr = sprites.fang_roots[f.sprite_i]
		if not spr then goto continue end
		local fang_len = f.target_len * length_m
		local root_len = (28 + fang_len * 0.65) * scale_mul
		local root_width = (22 + 10 * f.base_width * width_m) * scale_mul
		-- 限制可见斑块，避免单独辨认出一团一团
		root_len = math.min(65, root_len)
		root_width = math.min(45, root_width)
		spr.Scale = Vector(root_len / 128, root_width / 96)
		spr.Rotation = ang
		local patch_pos = root - dir * math.min(12, root_len * 0.18)
		local a = math.min(0.50, root_alpha * f.alpha_bias)
		spr.Color = Color(1, 1, 1, a, 0, 0, 0)
		spr:Render(patch_pos, Vector(0, 0), Vector(0, 0))
		::continue::
	end
end

local function render_fangs(edge_depths, sw, sh, counter, release_boost, phase, release_t)
	local fangs = overlay.fangs
	if not fangs then return end
	local length_m, width_m, alpha_m, jitter_m, rim = fang_draw_state(counter, release_boost, phase, release_t)
	for _, f in ipairs(fangs) do
		local depth = edge_depths[f.edge] or 0
		if depth < 4 then goto continue end
		local root, _, ang = resolve_fang_pose(f, edge_depths, sw, sh, length_m, jitter_m, phase, release_t)
		local spr = sprites.fangs[f.sprite_i]
		if not spr then goto continue end
		local len_px = f.target_len * length_m
		spr.Scale = Vector(len_px / FANG_TEX_W, f.base_width * width_m)
		spr.Rotation = ang
		local a_body = math.min(1, alpha_m * f.alpha_bias)
		local col = Color(1, 1, 1, a_body, 0.02 * rim, 0.025 * rim, 0.04 * rim)
		if overlay.reverse_sun and col.SetColorize then
			col:SetColorize(0.15, 0.02, 0.08, 0.2)
		elseif col.SetColorize then
			col:SetColorize(0.02, 0.03, 0.05, 0.15 * rim)
		end
		spr.Color = col
		spr:Render(root, Vector(0, 0), Vector(0, 0))
		::continue::
	end
end

local function render_blackout(sw, sh, strength, player_s)
	if strength < 0.02 or not sprites.fill then return end
	local spr = sprites.fill
	local sx = (sw / 256) * 1.15
	local sy = (sh / 256) * 1.15
	spr.Scale = Vector(sx, sy)
	spr.Rotation = 0
	spr.Color = Color(1, 1, 1, math.min(0.98, strength * 0.96), 0, 0, 0)
	spr:Render(Vector(sw * 0.5, sh * 0.5), Vector(0, 0), Vector(0, 0))
	local pulse = 0.6 + strength * 1.4
	spr.Scale = Vector(pulse * (sw / 256), pulse * (sh / 256))
	spr.Color = Color(1, 1, 1, math.min(0.98, strength), 0, 0, 0)
	spr:Render(player_s, Vector(0, 0), Vector(0, 0))
end

function vis.render()
	-- 暂停时仍绘制当前帧（菜单/地图底下保持夜幕），但不推进噪声与焦点动画
	if not overlay.active and overlay.phase == "idle" then return end
	ensure_all_sprites()
	local _, _, sw, sh = vis.get_viewport_rect()
	local counter = overlay.counter
	local phase = overlay.phase
	local release_t = overlay.release_t or 0
	local paused = Game():IsPaused()

	if phase == "releasing" and not overlay.release_initialized then
		initialize_release_snapshot(sw, sh, counter)
	end

	if not paused then
		if phase == "charging" then
			update_charge_focus(sw, sh)
		end
		if phase ~= "releasing" and phase ~= "blackout" then
			overlay.noise_phase = overlay.noise_phase + 0.016 * (vis.params.drift_speed or 1)
		end
	end

	local edge_depths = get_edge_depths_for_frame(sw, sh, counter, phase, release_t)

	local alpha_mul = 1
	local detail_mul = 1
	local coarse_mul = 1
	local medium_mul = 1
	if counter >= 120 then
		detail_mul = lerp(1, 0.85, smoothstep(120, 170, counter))
	end
	if counter >= 170 then
		detail_mul = lerp(detail_mul, 0.7, smoothstep(170, 180, counter))
	end
	if overlay.pitch_black then
		detail_mul = detail_mul * 0.85
		coarse_mul = coarse_mul * 1.05
	end

	local release_boost = 0
	local p = vis.params
	local move_start = p.bite_move_start or 10
	local move_end = p.bite_move_end or 20
	if phase == "releasing" then
		if release_t >= 4 and release_t < move_start then
			release_boost = (release_t - 4) / math.max(1, move_start - 4)
			detail_mul = detail_mul * (1 - release_boost * 0.35)
		elseif release_t >= move_start then
			release_boost = 1
			coarse_mul = coarse_mul * 1.10
			medium_mul = medium_mul * 0.85
			detail_mul = detail_mul * 0.60
		end
	elseif phase == "blackout" then
		release_boost = 1
		coarse_mul = coarse_mul * 1.10
		medium_mul = medium_mul * 0.8
		detail_mul = 0.5
	elseif phase == "recover" then
		-- 幕布/夜幕可退；黑屏由 blackout_strength 独立 hold/fade，不乘 alpha_mul
		alpha_mul = 1 - math.min(1, release_t / math.max(1, p.recover_duration or 20))
		release_boost = 0
	end

	local any_depth = false
	for _, edge in ipairs(EDGES) do
		if (edge_depths[edge] or 0) > 0.5 then any_depth = true break end
	end

	-- Night Body 在 counter 很低时也要能先变暗（不只依赖 edge depth）
	local body_ready = counter > (p.body_alpha_start or 10) or phase == "releasing" or phase == "blackout" or phase == "recover"
	if body_ready and alpha_mul > 0.02 then
		render_night_body(sw, sh, counter, phase, release_t, alpha_mul)
	end

	local show_fangs = (phase == "charging" or phase == "releasing")
	if any_depth and alpha_mul > 0.02 then
		for _, edge in ipairs(EDGES) do
			render_curtain_layer(edge, "coarse", edge_depths[edge] or 0, sw, sh, alpha_mul * coarse_mul, detail_mul)
		end
		if show_fangs then
			render_fang_root_patches(edge_depths, sw, sh, counter, release_boost, phase, release_t)
			render_fangs(edge_depths, sw, sh, counter, release_boost, phase, release_t)
		end
		local cover_m = (p.medium_cover_mul or 0.38) * medium_mul
		local cover_d = (p.detail_cover_mul or 0.28)
		for _, edge in ipairs(EDGES) do
			render_curtain_layer(edge, "medium", edge_depths[edge] or 0, sw, sh, alpha_mul * cover_m, detail_mul)
			render_curtain_layer(edge, "detail", edge_depths[edge] or 0, sw, sh, alpha_mul * cover_d, detail_mul)
		end
	end

	local bo = blackout_strength(phase, release_t)
	if bo > 0 then
		render_blackout(sw, sh, bo, bite_focus_screen())
	end
end

function vis.trigger_bite(player)
	vis.debug_preview_bite = true
end

function vis.tick()
end

return vis
