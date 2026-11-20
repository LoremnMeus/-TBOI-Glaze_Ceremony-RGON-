-- Storm V7.1 tornado: offline volumetric funnel (storm/v7) layered Sprite playback.
-- Public API preserved for storm_encounter / wind_visual / debug.
-- Does NOT stitch TRibbon segments. Physics/Story untouched.

local M = {
	active = false,
	center = nil,
	growth = 0,
	intensity = 0.5,
	spread = 0,
	mode = "hidden", -- forming | looping | opening | collapsing | hidden
	frame = 0,
	phase_t = 0,
	visual_scale = 0.85,
	alpha = 1.0,
	external_compose = false, -- when true, wind_visual skips tornado.render()
	_back = nil,
	_core = nil,
	_front = nil,
	_manifest = nil,
	-- Canvas anchors from generator (pixels); pivot is base.
	_canvas_h = 224,
	_base_local = Vector(0, 0), -- render at world base (pivot)
	_top_local = Vector(0, -178), -- BASE_Y - TOP_Y in atlas space
	R_bot = 19,
	R_top = 70,
}

local PATH_BACK = "gfx/boss/Zennith/storm/v7/tornado_back.anm2"
local PATH_CORE = "gfx/boss/Zennith/storm/v7/tornado_core.anm2"
local PATH_FRONT = "gfx/boss/Zennith/storm/v7/tornado_front.anm2"
local ANIM = "TornadoLoop"
local FRAME_N = 24
-- Atlas: 1 canvas unit ≈ 1 world unit at visual_scale=1 (tuned for room column).
local WORLD_PER_PX = 1.0

local function clamp01(x)
	return math.max(0, math.min(1, x or 0))
end

local function load_layer(path)
	local s = Sprite()
	s:Load(path, true)
	s:Play(ANIM, true)
	s:SetFrame(ANIM, 0)
	return s
end

local function ensure_sprites()
	if not M._back then M._back = load_layer(PATH_BACK) end
	if not M._core then M._core = load_layer(PATH_CORE) end
	if not M._front then M._front = load_layer(PATH_FRONT) end
end

function M.clear()
	M.active = false
	M.center = nil
	M.growth = 0
	M.spread = 0
	M.mode = "hidden"
	M.frame = 0
	M.phase_t = 0
	M.alpha = 1
	M.surge_scale_y = 1
	M.external_compose = false
end

function M.is_active()
	return M.active == true
end

function M.set_external_compose(on)
	M.external_compose = on == true
end

function M.begin(center, opts)
	opts = opts or {}
	center = center or Game():GetRoom():GetCenterPos()
	ensure_sprites()
	M.active = true
	M.center = Vector(center.X, center.Y)
	M.intensity = clamp01(opts.intensity or M.intensity or 0.55)
	M.growth = clamp01(opts.growth or M.growth or 0.12)
	M.spread = clamp01(opts.spread or 0)
	M.visual_scale = tonumber(opts.visual_scale) or M.visual_scale or 0.85
	M.alpha = 1
	M.surge_scale_y = 1
	M.frame = 0
	M._frame_accum = 0
	M.phase_t = 0
	M.mode = (M.growth < 0.95) and "forming" or "looping"
	-- Keep external_compose if encounter already claimed composition.
	if opts.external_compose ~= nil then
		M.external_compose = opts.external_compose == true
	end
	-- Top offset in world: atlas (BASE_Y-TOP_Y)=178 px * scale
	M._top_local = Vector(0, -178 * WORLD_PER_PX)
	return true
end

function M.set_growth(g)
	M.growth = clamp01(g)
	if M.mode == "forming" and M.growth >= 0.98 then
		M.mode = "looping"
	end
end

function M.set_intensity(i) M.intensity = clamp01(i) end
function M.set_spread(s) M.spread = clamp01(s) end
function M.set_center(center)
	if center then M.center = Vector(center.X, center.Y) end
end

function M.set_mode(mode)
	M.mode = mode or M.mode
end

--- Story-only vertical stretch. Growth stays normalized; the base pivot does not move.
function M.set_surge_scale_y(scale)
	local n = tonumber(scale) or 1
	if n < 1 then n = 1 end
	if n > 4 then n = 4 end
	M.surge_scale_y = n
end

local function column_draw_scale()
	local g = math.max(0.05, M.growth or 0)
	local sx = (M.visual_scale or 1) * (0.35 + 0.65 * g)
	sx = sx * (1 + (M.spread or 0) * 0.25)
	local sy = sx * (M.surge_scale_y or 1)
	return sx, sy
end

function M.get_base_anchor()
	if not M.center then return nil end
	return Vector(M.center.X, M.center.Y)
end

function M.get_top_anchor()
	if not M.center then return nil end
	local _, sy = column_draw_scale()
	return Vector(M.center.X, M.center.Y + M._top_local.Y * sy)
end

function M.get_core_radius()
	local g = math.max(0.05, M.growth or 0)
	local scale = (M.visual_scale or 1) * (0.55 + 0.45 * g)
	-- Approx world radius at mid height from atlas r_bot/r_top.
	local r = (M.R_bot + M.R_top) * 0.5 * WORLD_PER_PX * scale
	return math.max(18, r * (1 + (M.spread or 0) * 0.5))
end

function M.get_occlusion_profile()
	return {
		growth = M.growth or 0,
		intensity = M.intensity or 0,
		spread = M.spread or 0,
		mode = M.mode,
	}
end

local function sync_layer_frames()
	local f = M.frame % FRAME_N
	local function sync(spr)
		if not spr then return end
		pcall(function()
			spr:SetFrame(ANIM, f)
		end)
	end
	sync(M._back)
	sync(M._core)
	sync(M._front)
end

function M.update()
	if not M.active or not M.center then return end
	M.phase_t = (M.phase_t or 0) + 1
	-- Shared frame clock only (Back/Core/Front never advance independently).
	-- Step every 2 game frames → ~1.6s loop; seamless PNG must still hold at any rate.
	M._frame_accum = (M._frame_accum or 0) + 1
	if M._frame_accum >= 2 then
		M._frame_accum = 0
		M.frame = (M.frame + 1) % FRAME_N
	end
	ensure_sprites()
	sync_layer_frames()

	if M.mode == "forming" then
		-- Auto creep growth if caller only began once.
		if M.growth < 1 then
			M.growth = math.min(1, M.growth + 0.02)
		end
		if M.growth >= 0.98 then
			M.mode = "looping"
		end
	elseif M.mode == "opening" then
		-- Tip reveal hold: keep column open at the mouth until encounter advances.
		M.growth = 1
		M.spread = math.max(M.spread or 0, 0.14)
		-- Do not auto-flip to looping — storm_encounter owns the beat.
	elseif M.mode == "collapsing" then
		M.growth = math.max(0, M.growth - 0.04)
		M.alpha = math.max(0, (M.alpha or 1) - 0.05)
		if M.growth <= 0.02 then
			M.active = false
			M.mode = "hidden"
		end
	end
end

local function layer_scale()
	local sx, sy = column_draw_scale()
	return Vector(sx, sy)
end

local function layer_color(mul)
	local a = (M.alpha or 1) * clamp01(0.55 + (M.intensity or 0.5) * 0.45) * (mul or 1)
	if M.mode == "forming" then
		a = a * (0.35 + 0.65 * (M.growth or 0))
	end
	return Color(1, 1, 1, a)
end

local function draw_layer(spr, mul)
	if not spr or not M.center then return false end
	local ok = pcall(function()
		-- Play once at load; Update owns shared frame. Render only draws.
		spr.Rotation = 0
		spr.Scale = layer_scale()
		spr.Color = layer_color(mul)
		spr:Render(Isaac.WorldToScreen(M.center), Vector(0, 0), Vector(0, 0))
	end)
	return ok == true
end

function M.render_back()
	if not M.active then return {attempts = 0, draws = 0} end
	ensure_sprites()
	local attempts, draws = 1, 0
	if draw_layer(M._back, 0.9) then draws = 1 end
	return {attempts = attempts, draws = draws}
end

function M.render_core()
	if not M.active then return {attempts = 0, draws = 0} end
	ensure_sprites()
	local attempts, draws = 1, 0
	if draw_layer(M._core, 1.0) then draws = 1 end
	return {attempts = attempts, draws = draws}
end

function M.render_front()
	if not M.active then return {attempts = 0, draws = 0} end
	ensure_sprites()
	local attempts, draws = 1, 0
	if draw_layer(M._front, 0.95) then draws = 1 end
	return {attempts = attempts, draws = draws}
end

--- Full stack (debug / when encounter is not composing).
function M.render()
	if not M.active then return {attempts = 0, draws = 0} end
	local a = M.render_back()
	local b = M.render_core()
	local c = M.render_front()
	return {
		attempts = (a.attempts or 0) + (b.attempts or 0) + (c.attempts or 0),
		draws = (a.draws or 0) + (b.draws or 0) + (c.draws or 0),
	}
end

return M
