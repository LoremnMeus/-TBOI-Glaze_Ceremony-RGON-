-- Pareidolia 月亮眼独立渲染：上下半弦开合 + 眼球注视（无衔接条）
-- anm2: gfx/mimics/Pareidolia/Pareidolia_Moon.anm2（6 层：Back/Eyeball/CoverB/CoverT/Halo/Rim）
-- 第1行：0 detail Back / 128 纯色 Back / 256 瞳孔 / 384 黑边 Rim（瞳孔后再画一次）
-- 第2行 Y=128 下半弦：15→30→…→180（开→闭）
-- 第3行 Y=256 上半弦：-165→…→-15（闭→开；无 0°）
-- Halo：864,480 起 192×192 居中，画在 Back 之后
-- 绘制顺序：Halo → Back → Eyeball(+副瞳) → Rim → CoverB/CoverT
local g = require("Qing_Remaster_scripts.core.globals")

local M = {}

M.ANM2 = "gfx/mimics/Pareidolia/Pareidolia_Moon.anm2"
M.ANIM = "Eye"
M.SPRITE_REV = 6
M.LAYER_COUNT = 6
M.NULL_MOON = "Moon"
M.NULL_EYE = "Eye"
M.RAY_ANM2 = "gfx/mimics/Pareidolia/Pareidolia_Ray.anm2"
M.RAY_SHEET_Y = 192

M.LAYER = {
	BACK = 0,
	EYEBALL = 1,
	COVER_B = 2, -- 下半弦
	COVER_T = 3, -- 上半弦
	HALO = 4,    -- 背景光晕（先画）
	RIM = 5,     -- 黑边：压在瞳孔之上、眼皮之下
}
-- 兼容旧名
M.LAYER.COVER_H = M.LAYER.COVER_B
M.LAYER.COVER_H_FLIP = M.LAYER.COVER_T
M.LAYER.SEAM_H = -1
M.LAYER.SEAM_H_FLIP = -1
M.LAYER.COVER_V = -1
M.LAYER.COVER_V_FLIP = -1
M.LAYER.SEAM_V = -1
M.LAYER.SEAM_V_FLIP = -1

M.BACK_RADIUS = 51
M.EYEBALL_RADIUS = 18
M.LOOK_RADIUS = 31

--- 瞳孔/视线染色：Tint + Offset + Colorize（缺 Colorize 会看起来仍是白）
function M.make_tint_color(alpha, cz, offset)
	local a = tonumber(alpha) or 1
	if a < 0 then a = 0 elseif a > 1 then a = 1 end
	local off = offset or {}
	local col = Color(
		1, 1, 1, a,
		tonumber(off.r) or 0,
		tonumber(off.g) or 0,
		tonumber(off.b) or 0
	)
	if col.SetColorize and cz then
		col:SetColorize(
			tonumber(cz.r) or 0,
			tonumber(cz.g) or 0,
			tonumber(cz.b) or 0,
			tonumber(cz.a) or 1
		)
	end
	return col
end

-- 下半弦：15(开) … 180(闭)
M.COVER_STEPS_B = {15, 30, 45, 60, 75, 90, 105, 120, 135, 150, 165, 180}
-- 上半弦：-165(闭) … -15(开)，无 0
M.COVER_STEPS_T = {-165, -150, -135, -120, -105, -90, -75, -60, -45, -30, -15}

local function clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

--- 瞳孔边缘内缩：必须按完整瞳孔半径，旧 0.5 倍只护中心会导致贴图穿出睑弦
local function pupil_edge_inset(pupil_scale)
	pupil_scale = math.max(0.15, tonumber(pupil_scale) or 1)
	return (M.EYEBALL_RADIUS or 18) * pupil_scale + 2
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function smooth_t(rate, dt)
	dt = dt or 1
	rate = rate or 0.22
	return 1 - ((1 - rate) ^ dt)
end

local function vec_len(x, y)
	return math.sqrt(x * x + y * y)
end

local function nearest_step_frame(angle, steps)
	angle = tonumber(angle)
	if angle == nil or not steps or #steps == 0 then return nil end
	local best_i, best_d = 0, 1e9
	for i, step in ipairs(steps) do
		local d = math.abs(angle - step)
		if d < best_d then
			best_i, best_d = i - 1, d
		end
	end
	return best_i
end

--- 下睑开度 0..1（15=1，180=0）
function M.cover_open_frac_b(angle)
	angle = clamp(tonumber(angle) or 180, 15, 180)
	return (180 - angle) / 165
end

--- 上睑开度 0..1（-15=1，-165=0）
function M.cover_open_frac_t(angle)
	angle = clamp(tonumber(angle) or -165, -165, -15)
	return (angle + 165) / 150
end

-- 旧 API 兼容：按“正角度=下睑、负角度=上睑”猜测
local function cover_open_frac(angle)
	angle = tonumber(angle) or 180
	if angle < 0 then
		return M.cover_open_frac_t(angle)
	end
	return M.cover_open_frac_b(angle)
end

--- side: "b" | "t"；角度按 15° 档就近取帧（贴图半弦插值）
function M.cover_angle_to_frame(angle, side)
	if side == "t" or side == "top" then
		return nearest_step_frame(angle, M.COVER_STEPS_T)
	end
	return nearest_step_frame(angle, M.COVER_STEPS_B)
end

function M.seam_angle_to_frame(_angle)
	return nil -- 已无衔接
end

function M.pair_covers_overlap(angle_a, angle_b)
	-- 半弦贴图始终两层同画，不再做合并裁决
	return (M.cover_open_frac_t(angle_a) + M.cover_open_frac_b(angle_b)) <= 0.12
		or (M.cover_open_frac_b(angle_a) + M.cover_open_frac_t(angle_b)) <= 0.12
end

--- 双睑：直接画上下半弦，无衔接
function M.pick_lid_draw(state, _opts)
	local t = state.cover_t
	local b = state.cover_b
	local ot = M.cover_open_frac_t(t)
	local ob = M.cover_open_frac_b(b)
	return {
		cover = {l = false, r = false, t = t, b = b},
		seam = {l = false, r = false, t = false, b = false},
		seam_ang = {},
		seam_mul = {},
		closed = (ot < 0.06 and ob < 0.06),
		v_over = false,
		h_over = false,
		two_lid = true,
	}
end

function M.pick_seam_flags(state, opts)
	return M.pick_lid_draw(state, opts).seam
end

--- openness 1=睁开 → 上-15 / 下15；0=闭合 → 上-165 / 下180
function M.openness_to_covers(openness)
	openness = clamp(tonumber(openness) or 1, 0, 1)
	return {
		t = lerp(-165, -15, openness),
		b = lerp(180, 15, openness),
	}
end

--- 兼容旧单值 API（返回下睑角，仅作调试）
function M.openness_to_cover(openness)
	return M.openness_to_covers(openness).b
end

function M.create_state(opts)
	opts = opts or {}
	local covers
	if opts.cover_t ~= nil or opts.cover_b ~= nil then
		covers = {
			t = opts.cover_t or -15,
			b = opts.cover_b or 15,
		}
	elseif opts.openness ~= nil then
		covers = M.openness_to_covers(opts.openness)
	else
		covers = {
			t = opts.cover or -15,
			b = opts.cover or 15,
		}
	end
	return {
		two_lid = opts.two_lid ~= false,
		rotate_with_look = opts.rotate_with_look == true, -- 默认关，避免头顶乱转
		rot = opts.rot or 0,
		target_rot = opts.rot or 0,
		rot_rate = opts.rot_rate or 0.14,
		secondary_seam = 0,
		target_secondary_seam = 0,
		secondary_seam_rate = opts.secondary_seam_rate or 0.06,
		cover_l = -90,
		cover_r = -90,
		cover_t = covers.t,
		cover_b = covers.b,
		look_x = 0,
		look_y = 0,
		alpha = opts.alpha or 1,
		scale = opts.scale or 1,
		target_cover_l = -90,
		target_cover_r = -90,
		target_cover_t = covers.t,
		target_cover_b = covers.b,
		target_look_x = 0,
		target_look_y = 0,
		target_alpha = opts.alpha or 1,
		cover_rate = opts.cover_rate or 0.28,
		look_rate = opts.look_rate or 0.20,
		alpha_rate = opts.alpha_rate or 0.18,
		look_radius = opts.look_radius or M.LOOK_RADIUS,
		detailed_back = opts.detailed_back == true,
		clamp_to_lids = opts.clamp_to_lids == true, -- 默认关：眨眼不挤瞳孔
	}
end

function M.set_covers(state, covers)
	if not state or type(covers) ~= "table" then return end
	if state.two_lid ~= false then
		if covers.t ~= nil then state.target_cover_t = covers.t end
		if covers.b ~= nil then state.target_cover_b = covers.b end
		if covers.h ~= nil or covers.all ~= nil then
			local src = covers.h ~= nil and covers.h or covers.all
			local a = tonumber(src)
			if a ~= nil then
				-- 旧 cover 角 -90..90 → openness；否则当作已是半弦角时分别写入无意义，这里按旧角解释
				if a >= -90 and a <= 90 then
					local open = clamp((90 - a) / 180, 0, 1)
					local pair = M.openness_to_covers(open)
					state.target_cover_t = pair.t
					state.target_cover_b = pair.b
				end
			end
		end
		state.target_cover_l = -90
		state.target_cover_r = -90
		return
	end
	if covers.l ~= nil then state.target_cover_l = covers.l end
	if covers.r ~= nil then state.target_cover_r = covers.r end
	if covers.t ~= nil then state.target_cover_t = covers.t end
	if covers.b ~= nil then state.target_cover_b = covers.b end
end

function M.set_openness(state, openness)
	if not state then return end
	if type(openness) == "number" then
		local c = M.openness_to_covers(openness)
		M.set_covers(state, {t = c.t, b = c.b})
		return
	end
	if type(openness) ~= "table" then return end
	local covers = {}
	if openness.all ~= nil then
		local c = M.openness_to_covers(openness.all)
		covers.t, covers.b = c.t, c.b
	end
	if openness.h ~= nil then
		local c = M.openness_to_covers(openness.h)
		covers.t, covers.b = c.t, c.b
	end
	if openness.t ~= nil then covers.t = M.openness_to_covers(openness.t).t end
	if openness.b ~= nil then covers.b = M.openness_to_covers(openness.b).b end
	M.set_covers(state, covers)
end

function M.set_look_offset(state, x, y)
	if not state then return end
	state.target_look_x = tonumber(x) or 0
	state.target_look_y = tonumber(y) or 0
	if state.rotate_with_look == true then
		local len = vec_len(state.target_look_x, state.target_look_y)
		if len > 0.5 then
			local ang
			if math.atan2 then
				ang = math.deg(math.atan2(state.target_look_y, state.target_look_x))
			else
				ang = math.deg(math.atan(state.target_look_y, state.target_look_x))
			end
			state.target_rot = ang + 90
		end
	end
end

function M.set_look_at(state, eye_pos, target_pos, max_radius)
	if not state or not eye_pos or not target_pos then return end
	local dx = target_pos.X - eye_pos.X
	local dy = target_pos.Y - eye_pos.Y
	local r = max_radius or state.look_radius or M.LOOK_RADIUS
	local len = vec_len(dx, dy)
	if len > 0.001 and r > 0 then
		local scale = math.min(1, len / math.max(r * 2.5, 1))
		dx, dy = dx / len * r * scale, dy / len * r * scale
	end
	M.set_look_offset(state, dx, dy)
end

--- 瞳孔相对月心的贴图像素偏移（未乘 scale）
function M.eye_offset(state)
	if state and state._primary_look_x ~= nil then
		return Vector(state._primary_look_x, state._primary_look_y or 0)
	end
	return Vector(state and state.look_x or 0, state and state.look_y or 0)
end

function M.screen_to_world(screen_pos)
	if not screen_pos then return nil end
	if Isaac.ScreenToWorldFloat then
		return Isaac.ScreenToWorldFloat(screen_pos)
	end
	if Isaac.ScreenToWorld then
		return Isaac.ScreenToWorld(screen_pos)
	end
	return nil
end

--- 与 render_queued_moon / 圣光 Beam 同源：月亮屏坐标 → 瞳孔屏坐标
function M.pupil_screen_pos(room, anchor, lift, state, holder, look_world, opts)
	if not room or not anchor or not state then return nil, nil end
	opts = opts or {}
	lift = tonumber(lift) or 0
	local base = room:WorldToScreenPosition(Vector(anchor.X, anchor.Y - lift))
	local sway = opts.sway
	if sway and sway.X ~= nil then
		base = base + sway
	end
	if look_world then
		local look_screen = room:WorldToScreenPosition(look_world)
		M.set_look_at(state, base, look_screen)
		M.tick_look(state, opts.look_tick or 0.22)
	end
	local spr = M.ensure_sprite(holder or {})
	M.apply(spr, state, opts)
	return M.eye_screen_pos(base, state, spr), base, spr
end

--- 瞳孔屏坐标反算世界坐标（科技激光起点应与圣光 Beam 一致）
function M.pupil_world_pos(room, anchor, lift, state, holder, look_world, opts)
	local eye_screen = M.pupil_screen_pos(room, anchor, lift, state, holder, look_world, opts)
	if not eye_screen then return nil end
	return M.screen_to_world(eye_screen)
end

--- 瞳孔屏幕坐标：Moon Null + 瞳孔层偏移
function M.eye_screen_pos(moon_screen, state, sprite)
	if not moon_screen then return Vector(0, 0) end
	local scale = (state and state.scale) or 1
	local off = M.eye_offset(state)
	local nx, ny = 0, 0
	if sprite and sprite.GetNullFrame then
		local nf = sprite:GetNullFrame(M.NULL_EYE) or sprite:GetNullFrame(M.NULL_MOON)
		if nf and nf.GetPos then
			local p = nf:GetPos()
			if p then
				nx, ny = p.X, p.Y
			end
		end
	end
	return Vector(moon_screen.X + (nx + off.X) * scale, moon_screen.Y + (ny + off.Y) * scale)
end

--- 只推进注视插值（60Hz 渲染可用，不加快眨眼）
function M.tick_look(state, dt)
	if not state then return end
	dt = dt or 1
	local lt = smooth_t(state.look_rate, dt)
	state.look_x = lerp(state.look_x, state.target_look_x, lt)
	state.look_y = lerp(state.look_y, state.target_look_y, lt)
end

function M.set_alpha(state, alpha)
	if not state then return end
	state.target_alpha = clamp(tonumber(alpha) or 1, 0, 1)
end

function M.set_rotation(state, deg)
	if not state then return end
	state.target_rot = tonumber(deg) or 0
end

function M.snap(state)
	if not state then return end
	state.cover_l = state.target_cover_l
	state.cover_r = state.target_cover_r
	state.cover_t = state.target_cover_t
	state.cover_b = state.target_cover_b
	state.look_x = state.target_look_x
	state.look_y = state.target_look_y
	state.alpha = state.target_alpha
	state.rot = state.target_rot or 0
	state.secondary_seam = state.target_secondary_seam or 0
end

--- 半弦角度 → 水平弦在贴图坐标中的 Y（中心为 0，+Y 向下）
-- 下睑 b∈[15,180]：开时近底部(+R)，闭时扫过中心到上方
-- 上睑 t∈[-165,-15]：开时近顶部(-R)，闭时扫到下方
function M.chord_y_b(angle_b, radius)
	local R = radius or M.BACK_RADIUS
	local b = clamp(tonumber(angle_b) or 180, 15, 180)
	return R * math.cos(math.rad(b))
end

function M.chord_y_t(angle_t, radius)
	local R = radius or M.BACK_RADIUS
	local t = clamp(tonumber(angle_t) or -165, -165, -15)
	return -R * math.cos(math.rad(t))
end

--- 按上下半弦夹出的固定边界钳制瞳孔；pupil_scale 越大 inset 越大（防放大出界）
-- 返回 look_x, look_y, visible, gap
function M.clamp_look_to_chords(state, x, y, pupil_scale)
	x = tonumber(x) or 0
	y = tonumber(y) or 0
	pupil_scale = math.max(0.2, tonumber(pupil_scale) or 1)
	local R = M.BACK_RADIUS
	local inset = pupil_edge_inset(pupil_scale)
	local y_t = M.chord_y_t(state and state.cover_t, R)
	local y_b = M.chord_y_b(state and state.cover_b, R)
	-- 可视带：上弦之下、下弦之上
	local y_lo = math.min(y_t, y_b) + inset
	local y_hi = math.max(y_t, y_b) - inset
	local gap = y_hi - y_lo
	if gap < inset * 0.35 then
		local mid = (y_t + y_b) * 0.5
		return 0, mid, true, gap
	end
	y = clamp(y, y_lo, y_hi)
	local rad2 = R * R - y * y
	local max_x = 0
	if rad2 > 0 then
		max_x = math.sqrt(rad2) - inset
	end
	if max_x < 0 then max_x = 0 end
	x = clamp(x, -max_x, max_x)
	-- 活动半径也按瞳孔放大略收紧
	local max_r = ((state and state.look_radius) or M.LOOK_RADIUS) / math.sqrt(pupil_scale)
	local len = vec_len(x, y)
	if len > max_r and len > 1e-6 then
		local s = max_r / len
		x, y = x * s, y * s
		y = clamp(y, y_lo, y_hi)
		rad2 = R * R - y * y
		max_x = rad2 > 0 and (math.sqrt(rad2) - inset) or 0
		if max_x < 0 then max_x = 0 end
		x = clamp(x, -max_x, max_x)
	end
	return x, y, true, gap
end

local function clamp_look_to_aperture(state, x, y, pupil_scale)
	pupil_scale = math.max(0.2, tonumber(pupil_scale) or 1)
	if state and state.clamp_to_lids == false then
		local max_r = ((state.look_radius) or M.LOOK_RADIUS) / math.sqrt(pupil_scale)
		local len = vec_len(x, y)
		if len > max_r and len > 1e-6 then
			local s = max_r / len
			return x * s, y * s, true, max_r
		end
		return x, y, true, max_r
	end
	return M.clamp_look_to_chords(state, x, y, pupil_scale)
end

--- 多瞳布局主瞳用：可含 look_radius
local function clamp_pupil_in_lids(state, x, y, pupil_scale)
	return M.clamp_look_to_chords(state, x, y, pupil_scale)
end

--- 点是否在睑弦开孔内（含副瞳 inset）；不贴边投影，只做内外判定
local function point_inside_aperture(state, x, y, pupil_scale)
	x = tonumber(x) or 0
	y = tonumber(y) or 0
	pupil_scale = math.max(0.15, tonumber(pupil_scale) or 1)
	local R = M.BACK_RADIUS
	local inset = pupil_edge_inset(pupil_scale)
	local y_t = M.chord_y_t(state and state.cover_t, R)
	local y_b = M.chord_y_b(state and state.cover_b, R)
	local y_lo = math.min(y_t, y_b) + inset
	local y_hi = math.max(y_t, y_b) - inset
	if y_hi < y_lo then return false end
	if y < y_lo or y > y_hi then return false end
	local rad2 = R * R - y * y
	local max_x = rad2 > 0 and (math.sqrt(rad2) - inset) or 0
	if max_x < 0 then max_x = 0 end
	return x >= -max_x and x <= max_x
end

--- 主瞳钉死注视点；副瞳绕主瞳公转，碰睑缘则停顿并反向（不贴边滑移、不挪主瞳）
function M.layout_pupils(state, look_x, look_y, extras, primary_scale)
	extras = extras or {}
	primary_scale = math.max(0.2, tonumber(primary_scale) or 1)
	local lx = tonumber(look_x) or 0
	local ly = tonumber(look_y) or 0
	lx, ly = clamp_pupil_in_lids(state, lx, ly, primary_scale)

	local positions = {
		{
			x = lx,
			y = ly,
			scale = primary_scale,
			primary = true,
		},
	}

	local scales = {}
	local czs = {}
	local alphas = {}
	for i = 1, #extras do
		local p = extras[i]
		if p then
			scales[#scales + 1] = math.max(0.15, tonumber(p.scale) or 0.3)
			czs[#czs + 1] = p.cz
			alphas[#alphas + 1] = p.a
		end
	end
	local n_ex = #scales
	if n_ex <= 0 then
		return positions
	end

	state._sec_orbit_ang = tonumber(state._sec_orbit_ang) or 0
	state._sec_orbit_dir = (state._sec_orbit_dir == -1) and -1 or 1
	state._sec_orbit_pause = math.max(0, math.floor(tonumber(state._sec_orbit_pause) or 0))

	local er = M.EYEBALL_RADIUS or 18
	local max_sc = scales[1]
	for i = 2, n_ex do
		if scales[i] > max_sc then max_sc = scales[i] end
	end
	-- 目标环半径：主瞳外缘之外；半径可轻微脉动，但不得贴边滑
	local min_r = er * primary_scale * 0.92 + er * max_sc * 0.75 + 3
	local t = Game():GetFrameCount() + (tonumber(state.orbit_phase) or 0)
	local pulse = 0.5 + 0.5 * math.sin(t * 0.11)
	local desired_r = min_r + er * 0.4 * pulse

	local function extras_fit(ang, r)
		if r < 1 then return false end
		for idx = 1, n_ex do
			local a = ang + (idx - 1) * (math.pi * 2 / n_ex)
			local x = lx + math.cos(a) * r
			local y = ly + math.sin(a) * r
			if not point_inside_aperture(state, x, y, scales[idx]) then
				return false
			end
		end
		return true
	end

	-- 空间不够时只缩小环半径，绝不挪主瞳
	local r = desired_r
	for _ = 1, 16 do
		if extras_fit(state._sec_orbit_ang, r) then break end
		r = r * 0.88
		if r < min_r * 0.35 then break end
	end

	local ANG_SPEED = 0.09
	local PAUSE_FRAMES = 6
	if state._sec_orbit_pause > 0 then
		state._sec_orbit_pause = state._sec_orbit_pause - 1
	else
		local next_ang = state._sec_orbit_ang + ANG_SPEED * state._sec_orbit_dir
		if extras_fit(next_ang, r) then
			state._sec_orbit_ang = next_ang
		else
			-- 撞到开孔边界：停顿并反向，禁止贴边继续推进
			state._sec_orbit_dir = -state._sec_orbit_dir
			state._sec_orbit_pause = PAUSE_FRAMES
			local rev = state._sec_orbit_ang + ANG_SPEED * state._sec_orbit_dir
			if extras_fit(rev, r) then
				-- 停顿结束后再走；本帧保持原角
			end
		end
	end

	local ang = state._sec_orbit_ang
	for idx = 1, n_ex do
		local a = ang + (idx - 1) * (math.pi * 2 / n_ex)
		local rr = r
		local x = lx + math.cos(a) * rr
		local y = ly + math.sin(a) * rr
		-- 安全：若仍出界，沿半径向主瞳收回（径向收缩，绝不沿睑缘投影）
		if not point_inside_aperture(state, x, y, scales[idx]) then
			for s = 0.95, 0.2, -0.05 do
				local tx = lx + math.cos(a) * (rr * s)
				local ty = ly + math.sin(a) * (rr * s)
				if point_inside_aperture(state, tx, ty, scales[idx]) then
					x, y = tx, ty
					break
				end
			end
			-- 仍不行：贴在主瞳旁再强制弦夹
			if not point_inside_aperture(state, x, y, scales[idx]) then
				x = lx + math.cos(a) * (min_r * 0.35)
				y = ly + math.sin(a) * (min_r * 0.35)
			end
		end
		x, y = clamp_pupil_in_lids(state, x, y, scales[idx])
		positions[#positions + 1] = {
			x = x,
			y = y,
			scale = scales[idx],
			primary = false,
			cz = czs[idx],
			a = alphas[idx],
		}
	end
	return positions
end

local function lerp_angle(a, b, t)
	local d = (b - a) % 360
	if d > 180 then d = d - 360 end
	if d < -180 then d = d + 360 end
	return a + d * t
end

function M.tick(state, dt)
	if not state then return end
	dt = dt or 1
	local ct = smooth_t(state.cover_rate, dt)
	local lt = smooth_t(state.look_rate, dt)
	local at = smooth_t(state.alpha_rate, dt)
	local rt = smooth_t(state.rot_rate or 0.14, dt)
	state.cover_l = lerp(state.cover_l, state.target_cover_l, ct)
	state.cover_r = lerp(state.cover_r, state.target_cover_r, ct)
	state.cover_t = lerp(state.cover_t, state.target_cover_t, ct)
	state.cover_b = lerp(state.cover_b, state.target_cover_b, ct)
	state.look_x = lerp(state.look_x, state.target_look_x, lt)
	state.look_y = lerp(state.look_y, state.target_look_y, lt)
	state.alpha = lerp(state.alpha, state.target_alpha, at)
	state.rot = lerp_angle(state.rot or 0, state.target_rot or 0, rt)
	state.secondary_seam = 0
	state.target_secondary_seam = 0
end

local function safe_layer(sprite, id)
	if not sprite or not sprite.GetLayer or id == nil or id < 0 then return nil end
	local ok, layer = pcall(function() return sprite:GetLayer(id) end)
	if ok then return layer end
	return nil
end

local function force_hide_layer(sprite, layer_id)
	if layer_id == nil or layer_id < 0 then return end
	local layer = safe_layer(sprite, layer_id)
	if not layer then return end
	if layer.SetVisible then layer:SetVisible(false) end
	if layer.SetColor then layer:SetColor(Color(1, 1, 1, 0, 0, 0, 0)) end
	if layer.SetSize then layer:SetSize(Vector(0, 0)) end
	if layer.SetPos then layer:SetPos(Vector(0, 0)) end
end

local function apply_cover_layer(sprite, layer_id, angle, side, alpha)
	if layer_id == nil or layer_id < 0 then return false end
	local layer = safe_layer(sprite, layer_id)
	if not layer then return false end
	if angle == false or angle == nil then
		force_hide_layer(sprite, layer_id)
		return false
	end
	local frame = M.cover_angle_to_frame(angle, side)
	if frame == nil then
		force_hide_layer(sprite, layer_id)
		return false
	end
	if layer.SetVisible then layer:SetVisible(true) end
	if layer.SetSize then layer:SetSize(Vector(1, 1)) end
	if sprite.SetLayerFrame then
		pcall(function() sprite:SetLayerFrame(layer_id, frame) end)
	end
	if layer.SetFlipX then layer:SetFlipX(false) end
	if layer.SetFlipY then layer:SetFlipY(false) end
	if layer.SetColor then layer:SetColor(Color(1, 1, 1, alpha or 1, 0, 0, 0)) end
	if layer.SetPos then layer:SetPos(Vector(0, 0)) end
	if layer.SetRotation then layer:SetRotation(0) end
	return true
end

local function rotate_vec(x, y, deg)
	local rad = math.rad(deg or 0)
	local c, s = math.cos(rad), math.sin(rad)
	return x * c - y * s, x * s + y * c
end

function M.apply(sprite, state, opts)
	if not sprite or not state then return end
	opts = opts or {}
	local alpha = clamp(state.alpha or 1, 0, 1)
	if alpha <= 0.001 then
		sprite.Color = Color(1, 1, 1, 0, 0, 0, 0)
		return
	end
	sprite.Color = Color(1, 1, 1, alpha, 0, 0, 0)

	if sprite.GetAnimation and sprite:GetAnimation() ~= M.ANIM then
		sprite:Play(M.ANIM, true)
	end
	if sprite.SetFrame then
		pcall(function() sprite:SetFrame(M.ANIM, 0) end)
	end

	local lid_draw = M.pick_lid_draw(state, {alpha = alpha})

	local halo = safe_layer(sprite, M.LAYER.HALO)
	if halo then
		if halo.SetVisible then halo:SetVisible(true) end
		if halo.SetSize then halo:SetSize(Vector(1, 1)) end
		if sprite.SetLayerFrame then
			pcall(function() sprite:SetLayerFrame(M.LAYER.HALO, 0) end)
		end
		if halo.SetColor then halo:SetColor(Color(1, 1, 1, alpha, 0, 0, 0)) end
		if halo.SetPos then halo:SetPos(Vector(0, 0)) end
		if halo.SetFlipX then halo:SetFlipX(false) end
		if halo.SetFlipY then halo:SetFlipY(false) end
		if halo.SetRotation then halo:SetRotation(0) end
	end

	local back = safe_layer(sprite, M.LAYER.BACK)
	if back then
		if back.SetVisible then back:SetVisible(true) end
		if back.SetSize then back:SetSize(Vector(1, 1)) end
		if sprite.SetLayerFrame then
			local bf = (state.detailed_back or opts.detailed_back or (M.debug and M.debug.detailed_back)) and 1 or 0
			pcall(function() sprite:SetLayerFrame(M.LAYER.BACK, bf) end)
		end
		if back.SetColor then back:SetColor(Color(1, 1, 1, alpha, 0, 0, 0)) end
		if back.SetPos then back:SetPos(Vector(0, 0)) end
		if back.SetFlipX then back:SetFlipX(false) end
		if back.SetFlipY then back:SetFlipY(false) end
		if back.SetRotation then back:SetRotation(0) end
	end

	-- 注视：布局主瞳 + 额外瞳（互不重叠、按大小钳睑）；额外瞳在睑下绘制
	local world_rot = state.rot or 0
	local lx, ly = rotate_vec(state.look_x or 0, state.look_y or 0, -world_rot)
	local extras = opts.extra_pupils or state.extra_pupils
	local primary_scale = math.max(0.2, tonumber(opts.primary_pupil_scale or state.primary_pupil_scale) or 1)
	local flash = opts.pupil_flash or state.pupil_flash
	local layout = nil
	local need_layout = (extras and #extras > 0) or primary_scale > 1.01
	if need_layout then
		layout = M.layout_pupils(state, lx, ly, extras or {}, primary_scale)
		for i = 1, #layout do
			if layout[i].primary then
				lx, ly = layout[i].x, layout[i].y
				break
			end
		end
	else
		lx, ly = clamp_look_to_aperture(state, lx, ly, 1)
	end
	if flash then
		lx = lx + (tonumber(flash.look_dx) or 0)
		ly = ly + (tonumber(flash.look_dy) or 0)
		lx, ly = clamp_look_to_aperture(state, lx, ly, primary_scale)
	end
	state._pupil_layout = layout
	state._primary_pupil_scale = primary_scale

	local eye_drawn = false
	local eye = safe_layer(sprite, M.LAYER.EYEBALL)
	if eye then
		local eye_a = alpha
		eye_drawn = eye_a > 0.01
		if eye.SetVisible then eye:SetVisible(eye_drawn) end
		if sprite.SetLayerFrame then
			pcall(function() sprite:SetLayerFrame(M.LAYER.EYEBALL, 0) end)
		end
		if eye.SetPos then eye:SetPos(Vector(lx, ly)) end
		local pcz = opts.pupil_cz or state.pupil_cz
		local poff = opts.pupil_offset or state.pupil_offset
		local eye_col = M.make_tint_color(eye_a, pcz, poff)
		if eye.SetColor then eye:SetColor(eye_col) end
		local sx = primary_scale * (flash and tonumber(flash.scale_x) or 1)
		local sy = primary_scale * (flash and tonumber(flash.scale_y) or 1)
		if eye.SetSize then eye:SetSize(Vector(sx, sy)) end
		if eye.SetFlipX then eye:SetFlipX(false) end
		if eye.SetFlipY then eye:SetFlipY(false) end
		if eye.SetRotation then eye:SetRotation(0) end
		if not eye_drawn then force_hide_layer(sprite, M.LAYER.EYEBALL) end
	end
	state._primary_look_x = lx
	state._primary_look_y = ly
	state._pupil_cz = opts.pupil_cz or state.pupil_cz
	state._pupil_offset = opts.pupil_offset or state.pupil_offset
	state._eye_color = M.make_tint_color(alpha, state._pupil_cz, state._pupil_offset)

	-- 黑边 Rim：钉在月心，不跟瞳孔偏移；瞳孔之后再画一次压住外溢
	local rim = safe_layer(sprite, M.LAYER.RIM)
	local rim_drawn = false
	if rim then
		rim_drawn = alpha > 0.01
		if rim.SetVisible then rim:SetVisible(rim_drawn) end
		if sprite.SetLayerFrame then
			pcall(function() sprite:SetLayerFrame(M.LAYER.RIM, 0) end)
		end
		if rim.SetPos then rim:SetPos(Vector(0, 0)) end
		if rim.SetSize then rim:SetSize(Vector(1, 1)) end
		if rim.SetColor then rim:SetColor(Color(1, 1, 1, alpha, 0, 0, 0)) end
		if rim.SetFlipX then rim:SetFlipX(false) end
		if rim.SetFlipY then rim:SetFlipY(false) end
		if rim.SetRotation then rim:SetRotation(0) end
		if not rim_drawn then force_hide_layer(sprite, M.LAYER.RIM) end
	else
		force_hide_layer(sprite, M.LAYER.RIM)
	end

	local c = lid_draw.cover
	-- Halo → Back → Eyeball（副瞳插在其后）→ Rim → Cover
	local draw_layers = {}
	if halo then
		draw_layers[#draw_layers + 1] = M.LAYER.HALO
	end
	draw_layers[#draw_layers + 1] = M.LAYER.BACK
	if eye_drawn then
		draw_layers[#draw_layers + 1] = M.LAYER.EYEBALL
	end
	state._base_layers = draw_layers

	local rim_layers = {}
	if rim_drawn then
		rim_layers[1] = M.LAYER.RIM
	end
	state._rim_layers = rim_layers

	force_hide_layer(sprite, M.LAYER.COVER_B)
	force_hide_layer(sprite, M.LAYER.COVER_T)

	local cover_layers = {}
	if apply_cover_layer(sprite, M.LAYER.COVER_B, c.b, "b", alpha) then
		cover_layers[#cover_layers + 1] = M.LAYER.COVER_B
	end
	if apply_cover_layer(sprite, M.LAYER.COVER_T, c.t, "t", alpha) then
		cover_layers[#cover_layers + 1] = M.LAYER.COVER_T
	end
	state._cover_layers = cover_layers
	-- 完整顺序副本（勿与 _base_layers 共用同一张表）
	local full = {}
	for i = 1, #draw_layers do
		full[#full + 1] = draw_layers[i]
	end
	for i = 1, #rim_layers do
		full[#full + 1] = rim_layers[i]
	end
	for i = 1, #cover_layers do
		full[#full + 1] = cover_layers[i]
	end
	state._render_layers = full
	state._render_layer_only = true
end

function M.ensure_sprite(holder)
	holder = holder or {}
	local spr = holder.sprite
	local stale = holder.sprite_rev ~= M.SPRITE_REV
	if spr and spr.GetLayerCount then
		local ok, n = pcall(function() return spr:GetLayerCount() end)
		if ok and type(n) == "number" and n ~= M.LAYER_COUNT then
			stale = true
		end
	end
	if spr == nil or stale or (spr.GetFilename and spr:GetFilename() ~= M.ANM2) then
		spr = Sprite()
		spr:Load(M.ANM2, true)
		spr:Play(M.ANIM, true)
		spr:SetFrame(M.ANIM, 0)
		holder.sprite = spr
		holder.sprite_rev = M.SPRITE_REV
	end
	return holder.sprite, holder
end

function M.render(sprite, screen_pos, state, opts)
	if not sprite or not screen_pos or not state then return end
	opts = opts or {}
	if (state.alpha or 0) <= 0.001 and (state.target_alpha or 0) <= 0.001 then
		return
	end
	M.apply(sprite, state, opts)
	local scale = opts.scale or state.scale or 1
	local backup_scale = sprite.Scale
	local backup_rot = sprite.Rotation
	local backup_col = sprite.Color
	sprite.Scale = Vector(scale, scale)
	sprite.Rotation = state.rot or 0

	local eye_col = state._eye_color
	local eye_layer = M.LAYER.EYEBALL
	local function draw_layer(id)
		-- 瞳孔层同时写 Sprite.Color，避免仅 Layer Colorize 不生效
		if id == eye_layer and eye_col then
			sprite.Color = eye_col
		else
			sprite.Color = Color(1, 1, 1, 1, 0, 0, 0)
		end
		pcall(function()
			sprite:RenderLayer(id, screen_pos, Vector.Zero, Vector.Zero)
		end)
	end

	local has_extra = (opts.extra_pupils or state.extra_pupils) and #(opts.extra_pupils or state.extra_pupils) > 0
	local base = state._base_layers
	local rims = state._rim_layers
	local covers = state._cover_layers
	if has_extra and state._render_layer_only and base and sprite.RenderLayer then
		for i = 1, #base do
			draw_layer(base[i])
		end
		M.render_extra_pupils(sprite, screen_pos, state, opts)
		if rims then
			for i = 1, #rims do
				draw_layer(rims[i])
			end
		end
		if covers then
			for i = 1, #covers do
				draw_layer(covers[i])
			end
		end
	else
		local layers = state._render_layers
		if state._render_layer_only and layers and sprite.RenderLayer then
			for i = 1, #layers do
				draw_layer(layers[i])
			end
		else
			if eye_col then sprite.Color = eye_col end
			sprite:Render(screen_pos, Vector.Zero, Vector.Zero)
		end
	end
	sprite.Scale = backup_scale
	sprite.Rotation = backup_rot
	sprite.Color = backup_col
end

--- 使用 apply 已算好的 _pupil_layout；画在眼皮之前
function M.render_extra_pupils(sprite, screen_pos, state, opts)
	opts = opts or {}
	local layout = state and state._pupil_layout
	if not sprite or not screen_pos or not state or not layout then return end
	if (state.alpha or 0) <= 0.01 then return end
	local eye = safe_layer(sprite, M.LAYER.EYEBALL)
	if not eye or not sprite.RenderLayer then return end

	local alpha = clamp(state.alpha or 1, 0, 1)
	local scale = opts.scale or state.scale or 1
	local world_rot = state.rot or 0

	local backup_scale = sprite.Scale
	local backup_rot = sprite.Rotation
	sprite.Scale = Vector(scale, scale)
	sprite.Rotation = world_rot

	if eye.SetVisible then eye:SetVisible(true) end
	if sprite.SetLayerFrame then
		pcall(function() sprite:SetLayerFrame(M.LAYER.EYEBALL, 0) end)
	end
	if eye.SetFlipX then eye:SetFlipX(false) end
	if eye.SetFlipY then eye:SetFlipY(false) end
	if eye.SetRotation then eye:SetRotation(0) end

	for i = 1, #layout do
		local p = layout[i]
		if p and not p.primary then
			local ps = tonumber(p.scale) or 1
			local a = alpha * (tonumber(p.a) or 0.95)
			if eye.SetPos then eye:SetPos(Vector(p.x, p.y)) end
			if eye.SetSize then eye:SetSize(Vector(ps, ps)) end
			local cz = p.cz or state._pupil_cz
			local col = M.make_tint_color(a, cz, state._pupil_offset)
			if eye.SetColor then eye:SetColor(col) end
			sprite.Color = col
			pcall(function()
				sprite:RenderLayer(M.LAYER.EYEBALL, screen_pos, Vector.Zero, Vector.Zero)
			end)
		end
	end

	-- 还原主瞳孔层
	local plx = state._primary_look_x or 0
	local ply = state._primary_look_y or 0
	local psc = state._primary_pupil_scale or 1
	if eye.SetPos then eye:SetPos(Vector(plx, ply)) end
	if eye.SetSize then eye:SetSize(Vector(psc, psc)) end
	local restore = state._eye_color or M.make_tint_color(alpha, state._pupil_cz, state._pupil_offset)
	if eye.SetColor then eye:SetColor(restore) end
	sprite.Color = restore
	sprite.Scale = backup_scale
	sprite.Rotation = backup_rot
end

function M.draw(holder, screen_pos, state, opts)
	local spr = M.ensure_sprite(holder)
	if opts and opts.tick ~= false then
		M.tick(state, opts.dt or 1)
	end
	M.render(spr, screen_pos, state, opts)
	return spr
end

M.debug = {
	enabled = false,
	follow_player = true,
	offset = Vector(0, -40),
	auto_progress = true,
	progress_period = 240,
	progress = 0,
	open_at_zero = 0.60,
	open_at_full = 1.0,
	blink = true,
	scale = 0.9,
	stare_enemies = true,
	wander = true,
	force_spin = false,
	spin_deg_per_frame = 2,
	detailed_back = true,
}

local debug_holder = {}
local debug_state = nil
local debug_t = 0

function M.progress_to_openness(progress, opts)
	opts = opts or {}
	local p = clamp(tonumber(progress) or 0, 0, 1)
	local a0 = opts.open_at_zero or 0.60
	local a1 = opts.open_at_full or 1.0
	if p < 0.5 then return a0 end
	local u = (p - 0.5) / 0.5
	return lerp(a0, a1, u * u * (3 - 2 * u))
end

function M.debug_reset()
	debug_holder.sprite = nil
	debug_holder.sprite_rev = nil
	debug_state = M.create_state({
		openness = M.progress_to_openness(0, M.debug),
		scale = M.debug.scale,
		alpha = 1,
		detailed_back = M.debug.detailed_back == true,
		two_lid = true,
		rotate_with_look = false,
	})
	debug_state.detailed_back = M.debug.detailed_back == true
	M.snap(debug_state)
	M.debug.progress = 0
	debug_t = 0
end

local function is_preview_lockable(ent)
	if not ent or not ent:Exists() or ent:IsDead() then return false end
	-- 原版 Dummy + Potato for Scale（Nerve Ending / Potato Dummy, variant 2）
	if ent.Type == EntityType.ENTITY_DUMMY then return true end
	if ent.Variant == 2 then
		local potato_t = Isaac.GetEntityTypeByName("Potato Dummy")
		if potato_t and potato_t > 0 and ent.Type == potato_t then return true end
		if ent.Type == EntityType.ENTITY_NERVE_ENDING then return true end
	end
	if ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then return false end
	if ent:IsEnemy() then return true end
	local npc = ent:ToNPC()
	return npc ~= nil and npc:Exists()
end

local function find_nearest_enemy(from_pos)
	local best, best_d = nil, 280 * 280
	for _, ent in ipairs(Isaac.FindInRadius(from_pos, 280, EntityPartition.ENEMY)) do
		if is_preview_lockable(ent) then
			local d = from_pos:DistanceSquared(ent.Position)
			if d < best_d then
				best, best_d = ent, d
			end
		end
	end
	if not best then
		for _, ent in ipairs(Isaac.GetRoomEntities()) do
			if is_preview_lockable(ent) then
				local d = from_pos:DistanceSquared(ent.Position)
				if d < best_d then
					best, best_d = ent, d
				end
			end
		end
	end
	return best
end

function M.debug_tick_and_render()
	if not M.debug.enabled then return end
	if debug_state == nil then M.debug_reset() end
	debug_t = debug_t + 1

	local period = math.max(60, tonumber(M.debug.progress_period) or 240)
	local progress = tonumber(M.debug.progress) or 0
	if M.debug.auto_progress then
		local hold = 45
		local cycle = period + hold
		local phase = debug_t % cycle
		if phase < period then
			progress = phase / period
		else
			progress = 1
		end
		M.debug.progress = progress
	end

	local openness = M.progress_to_openness(progress, M.debug)
	if M.debug.blink then
		local phase = debug_t % 180
		if phase >= 150 and phase < 162 then
			local u = (phase - 150) / 12
			if u < 0.45 then
				openness = lerp(openness, 0.02, u / 0.45)
			else
				openness = lerp(0.02, openness, (u - 0.45) / 0.55)
			end
		end
	end
	M.set_openness(debug_state, openness)
	M.set_alpha(debug_state, 0.45 + 0.55 * math.min(1, progress + 0.2))
	debug_state.detailed_back = M.debug.detailed_back == true

	local room = Game():GetRoom()
	local player = g.game and g.game:GetPlayer(0) or nil
	local world_anchor = player and player.Position or Vector(320, 280)
	local look_world = nil
	local enemy = nil
	if M.debug.stare_enemies and player then
		enemy = find_nearest_enemy(player.Position)
	end
	if enemy then
		world_anchor = enemy.Position
		look_world = enemy.Position
	elseif player then
		local aim = player:GetAimDirection()
		if aim and aim:Length() > 0.05 then
			look_world = player.Position + aim:Normalized() * 120
		end
	end

	local pos
	if room then
		pos = room:WorldToScreenPosition(world_anchor + (M.debug.offset or Vector(0, -40)))
	else
		pos = Vector(Isaac.GetScreenWidth() * 0.5, Isaac.GetScreenHeight() * 0.35)
	end

	debug_state.rotate_with_look = false
	debug_state.target_rot = 0
	if look_world and room then
		M.set_look_at(debug_state, pos, room:WorldToScreenPosition(look_world))
	elseif M.debug.wander then
		local ang = debug_t * 2.1
		M.set_look_at(debug_state, pos, pos + Vector(math.cos(math.rad(ang)) * 70, math.sin(math.rad(ang * 0.7)) * 50))
	else
		M.set_look_offset(debug_state, 0, 8)
	end
	debug_state.target_rot = 0

	if M.debug.force_spin then
		local spd = tonumber(M.debug.spin_deg_per_frame) or 2
		debug_state.target_rot = (debug_t * spd) % 360
		debug_state.rot_rate = 0.35
		debug_state.rotate_with_look = true
	end

	debug_state.scale = M.debug.scale or 0.9
	M.draw(debug_holder, pos, debug_state, {dt = 1})
end

return M
