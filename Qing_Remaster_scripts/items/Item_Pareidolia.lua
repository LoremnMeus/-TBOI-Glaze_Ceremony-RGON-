-- 妖心·盈月（Pareidolia）
-- 注视积累月相 → 满月演出（升飞远小 → 渐白光柱 → 落点圣光 → 缓缓升隐）
-- 眼类联动表 YOKAI_EYE_SYNERGIES 预留，本轮只做基础共鸣。
local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Nil_holder = require("Qing_Remaster_scripts.others.Nil_holder")
local moon = require("Qing_Remaster_scripts.others.pareidolia_moon_render")

local item = {
	ToCall = {},
	pre_ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Items.Pareidolia,
	own_key = "Pareidolia_",
	costumes = {
		[1] = enums.Costumes.Pareidolia_1,
	},
	moon = moon,
	-- 预留：满月共鸣时按表追加效果（本轮为空）
	YOKAI_EYE_SYNERGIES = {},
	-- A↔B 双向 EID：持有盈月看对方 / 持有对方看盈月（图标由 add_EID_item_synic 注入）
	description = {
		zh_cn = {
			[CollectibleType.COLLECTIBLE_20_20] = {desc = "注视时额外生成一只瞳孔，圣光还会再造成一半伤害",},
			[CollectibleType.COLLECTIBLE_PUPULA_DUPLEX] = {desc = "注视时额外生成一只瞳孔，圣光范围变大",},
			[CollectibleType.COLLECTIBLE_INNER_EYE] = {desc = "满月时两侧的小月会优先攻击其他敌人",},
			[CollectibleType.COLLECTIBLE_MOMS_EYE] = {desc = "后方的瞳孔也会向对称位置发射圣光",},
			[CollectibleType.COLLECTIBLE_EYE_SORE] = {desc = "满月时会额外生成随机方向的小月进行攻击",},
			[CollectibleType.COLLECTIBLE_POLYPHEMUS] = {desc = "主瞳孔变大，周围还会射出额外的细圣光",},
			[CollectibleType.COLLECTIBLE_EYE_OF_THE_OCCULT] = {desc = "圣光变为紫色，准星处也会受到一次圣光打击",},
			[CollectibleType.COLLECTIBLE_PROPTOSIS] = {desc = "离月亮越近，圣光造成的伤害越高",},
			[CollectibleType.COLLECTIBLE_EVIL_EYE] = {desc = "满月时周围环绕的邪眼会向敌人射击",},
			[CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE] = {desc = "注视中的路德维希之泪也会受到圣光打击",},
			[CollectibleType.COLLECTIBLE_TECHNOLOGY] = {desc = "满月时还会短暂射出一道科技激光",},
			[CollectibleType.COLLECTIBLE_TECHNOLOGY_2] = {desc = "满月时还会持续射出一道科技激光",},
			[CollectibleType.COLLECTIBLE_TECH_X] = {desc = "月亮开始注视时，目标处出现悬浮的科技激光圈并逐渐收缩消失",},
		},
		en_us = {
			[CollectibleType.COLLECTIBLE_20_20] = {desc = "An extra pupil appears while gazing; holy light also strikes again for half damage",},
			[CollectibleType.COLLECTIBLE_PUPULA_DUPLEX] = {desc = "An extra pupil appears while gazing; holy light covers a wider area",},
			[CollectibleType.COLLECTIBLE_INNER_EYE] = {desc = "Side moons at full moon prefer attacking other enemies",},
			[CollectibleType.COLLECTIBLE_MOMS_EYE] = {desc = "The rear pupil also fires holy light at the mirrored spot",},
			[CollectibleType.COLLECTIBLE_EYE_SORE] = {desc = "Full moon spawns extra mini moons that attack in random directions",},
			[CollectibleType.COLLECTIBLE_POLYPHEMUS] = {desc = "The main pupil grows larger, and extra thin holy lights fire around it",},
			[CollectibleType.COLLECTIBLE_EYE_OF_THE_OCCULT] = {desc = "Holy light turns purple and also strikes the crosshair",},
			[CollectibleType.COLLECTIBLE_PROPTOSIS] = {desc = "The closer you are to the moon, the more damage holy light deals",},
			[CollectibleType.COLLECTIBLE_EVIL_EYE] = {desc = "Orbiting Evil Eyes fire at enemies during full moon",},
			[CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE] = {desc = "Holy light also strikes your controlled Ludovico tear",},
			[CollectibleType.COLLECTIBLE_TECHNOLOGY] = {desc = "Full moon also fires a brief Technology laser",},
			[CollectibleType.COLLECTIBLE_TECHNOLOGY_2] = {desc = "Full moon also sustains a Technology laser",},
			[CollectibleType.COLLECTIBLE_TECH_X] = {desc = "When the moon begins gazing, a hovering Technology ring appears on the target and shrinks away",},
		},
	},
}

auxi.add_EID_item_synic(item.entity, item.description, true)

local GAZE_TIMEOUT = 75          -- ~2.5s 有攻击注视
local OBSERVE_TIMEOUT = 50       -- 目标消失后随机观察、无攻击则隐去
local PHASE_NEED_MUL = 16        -- 累计约 16×Damage（约一串攻击，避免三下就满）
local RES_DAMAGE_MUL = 1.5
local RES_DAMAGE_FLAT = 2
local FAMILIAR_PHASE_MUL = 0.5

-- 进度月：透明度=显隐；高度/大小=月相；默认完全张开（-15/+15）
local VIS_FADE_IN = 5
local VIS_FADE_OUT = 12
local VIS_FADE_OUT_FAST = 4      -- 目标消失/换房/演出结束
local COVER_FULL_T, COVER_FULL_B = -15, 15
local COVER_DEFAULT_T, COVER_DEFAULT_B = COVER_FULL_T, COVER_FULL_B
local COVER_CLOSED_T, COVER_CLOSED_B = -165, 180
local PHASE_SCALE_MIN = 0.25
local PHASE_SCALE_MAX = 1.0 -- 超过 1 会像“贴脸变大”而非升起
local PHASE_LIFT_DEFAULT = 90
local PHASE_LIFT_TOP_DEFAULT = 210 -- 进度月必须明显升高，避免只放大像贴脸
local FLOAT_RATE_DEFAULT = 0.11  -- 影响追随/切目标速度
local VIS_SCALE_RATE = 0.14
local VIS_LIFT_RATE = 0.22
local VIS_COVER_RATE = 0.22
local BLINK_PERIOD = 150
local BLINK_LEN = 12
local VIS_ALPHA_START = 0.22     -- 出现/开始隐藏从较低 alpha 起
local VIS_ALPHA_PEAK = 1.0
local VIS_SCALE_AT_ZERO = 0.42   -- 全透明时相对原比例的额外缩小
local TELEPORT_SNAP_DIST = 90    -- 敌人单帧真跳变才算瞬移
local WARP_OUT_FRAMES = 4
local WARP_IN_FRAMES = 5
local WARP_COOLDOWN = 24         -- 显现后禁止再触发瞬移，只加速跟随
local PURSUE_LEAD = 2.0          -- 轻微预测，过大易抖

-- 满月：升飞向中央（远小）→ 光柱渐粗 + 目标渐白 → 全白后落点圣光 → 缓缓升隐
local FX = {
	charge = 48,
	strike = 10,
	fade = 36,
}
local FX_LIFT_START_DEFAULT = 36
local FX_LIFT_HOVER_DEFAULT = 160
local FX_LIFT_MAX_DEFAULT = 260
-- 目标屏幕 Y ≈ 屏高×比例：落在屏顶边界稍下方（可 ImGui 微调）
local FX_SCREEN_TOP_PCT_DEFAULT = 0.22
local FX_FAR_SCALE = 0.30 -- 升到最高时的透视缩小
local FX_RAY_WIDTH_START = 0.06
local FX_RAY_WIDTH_END = 1.15
local MARK_COLOR_PRIO = 48

-- 圣光 / 眼类兼容（须在 render_queued_moon 等闭包之前声明，避免当成 nil 全局）
local HOLY_RADIUS = 48
local FOLLOWUP_DELAY = 8
local INNER_MOON_SCALE = 0.30
local INNER_STRIKE_MUL = 0.60
local INNER_SIDE_BASE = 72 -- 相对主月亮屏幕左右偏移（再乘主月亮 scale）
local MOMS_EYE_SCALE = 0.28
local MOMS_STRIKE_MUL = 1.0
local EYESORE_MOON_SCALE = 0.26
local EYESORE_STRIKE_MUL = 0.45
local POLY_PUPIL_SCALE = 1.2
local POLY_RING_DELAY = 5
local POLY_RING_SPAN = 16 -- 细圣光在该窗口内陆续落下
local POLY_RING_RADIUS = 72
local POLY_BEAM_SCALE_X = 0.32
local POLY_RING_DMG_MUL = 0.22
local POLY_RING_RADIUS_MUL = 0.55
local POLY_RING_COUNT_MIN = 10
local POLY_RING_COUNT_MAX = 16
local OCCULT_CZ = {r = 2.6, g = 0.4, b = 3.4, a = 1} -- Colorize 需够强才看得见紫
local OCCULT_OFFSET = {r = 0.22, g = 0.04, b = 0.32} -- 加性偏色
local TECH_CZ = {r = 3.2, g = 0.4, b = 0.35, a = 1} -- 科技瞳孔红
local TECH_OFFSET = {r = 0.38, g = 0.06, b = 0.04}
local TECH_LIFT_PO_MUL = 0.72 -- 已弃用：激光改用世界坐标 Y-lift，不再叠 PositionOffset
local TECH_DEPTH = 280 -- 画在前方
local TECH_LASER_VAR = (LaserVariant and LaserVariant.THIN_RED) or 2
-- SubType 1 = RING_LUDOVICO（科技X+Ludo 悬浮圈）
-- SubType 2 = 射出去的科技X 投射环；SubType 3 = 虚空之口跟随环
local TECHX_RING_SUB = (LaserSubType and LaserSubType.LASER_SUBTYPE_RING_LUDOVICO) or 1
local LASER_TAG = "qing_pareidolia_laser" -- 探针/所有权标记；ShootAngle 内部 INIT 时尚无此标记
local TECHX_START_R = 120
local TECHX_ANCHOR_H = -23 -- RING_LUDOVICO 无泪 Height，用 ParentOffset 抬到 Ludo 悬浮高度
local FLASH_INTERVAL = 28 -- 多数时间原色；每隔这么多帧开始一次闪烁
local FLASH_HOLD = 3      -- 每种闪烁色持续帧数
local FLASH_FADE = 2      -- 闪烁起止各插值帧数（色相与瞳孔形变共用）
local PROPTOSIS_NEAR_MUL = 2.5   -- +150%
local PROPTOSIS_FAR_MUL = 0.5    -- -50%
local PROPTOSIS_NEAR_PX = 48
local PROPTOSIS_FAR_PX = 300
local EVIL_EYE_ANM2 = "gfx/1000.084_evil eye.anm2"
local EVIL_EYE_VARIANT = (EffectVariant and EffectVariant.EVIL_EYE) or 84
local EVIL_ORBIT_COUNT = 3
local EVIL_ORBIT_WORLD = 48 -- 逻辑/射击用世界半径
local EVIL_ORBIT_SCREEN = 58 -- 自绘环绕月亮的屏幕半径
-- 原版邪眼 anm2：贴图可视中心相对原点偏上；屏幕自绘需下移补偿（勿与 PositionOffset 混淆）
local EVIL_PIVOT_COMP = Vector(0, 14)
local EVIL_SHOT_INTERVAL = 14
local EVIL_FIRST_SHOT = 10
local EVIL_DATA_KEY = "Pareidolia_evil_eye"
local EVIL_GLOW_SCALE = 0.26 -- 白光略小于邪眼
local EVIL_GLOW_ALPHA = 0.5 -- 背景白光 50% 透明

--- 瞳孔/射线染色：Tint 白 + Offset + 强 Colorize（须在 render_holy_ray 等闭包之前声明）
local function make_occult_color(alpha, cz, off)
	cz = cz or OCCULT_CZ
	off = off or OCCULT_OFFSET
	local a = tonumber(alpha) or 1
	local col = Color(
		1, 1, 1, a,
		tonumber(off.r) or 0,
		tonumber(off.g) or 0,
		tonumber(off.b) or 0
	)
	if col.SetColorize then
		col:SetColorize(
			tonumber(cz.r) or 2.6,
			tonumber(cz.g) or 0.4,
			tonumber(cz.b) or 3.4,
			tonumber(cz.a) or 1
		)
	end
	return col
end

--- 闪烁相位：strength 0..1（含起止 FLASH_FADE 插值）；红+紫连续闪
--- 返回 nil 或 {cz, off, strength, breath, seq_i, local_t, flash_span}
local function flash_envelope(syn)
	syn = syn or {}
	local seq = {}
	local want_red = syn.tech1 or syn.tech2 or syn.evil
	local want_purple = syn.occult or syn.evil
	if want_red then
		seq[#seq + 1] = {TECH_CZ, TECH_OFFSET, "red"}
	end
	if want_purple then
		seq[#seq + 1] = {OCCULT_CZ, OCCULT_OFFSET, "purple"}
	end
	if #seq == 0 then
		return nil
	end
	local f = Game():GetFrameCount()
	local flash_span = #seq * FLASH_HOLD
	local cycle = FLASH_INTERVAL + flash_span
	local phase = f % cycle
	if phase < FLASH_INTERVAL then
		return nil
	end
	local local_t = phase - FLASH_INTERVAL
	local idx = math.floor(local_t / FLASH_HOLD) + 1
	if idx < 1 then idx = 1 end
	if idx > #seq then idx = #seq end
	local fade = math.max(1, FLASH_FADE)
	local strength = 1
	if local_t < fade then
		strength = (local_t + 1) / (fade + 1)
	elseif local_t >= flash_span - fade then
		strength = math.max(0, (flash_span - local_t) / fade)
	end
	-- 单色段内再拱一次，方便瞳孔挤压/微颤
	local within = local_t - (idx - 1) * FLASH_HOLD
	local mid = FLASH_HOLD * 0.5
	local arch = 1 - math.abs(within - mid) / math.max(0.5, mid)
	if arch < 0 then arch = 0 end
	local breath = strength * arch
	local pair = seq[idx]
	return {
		cz = pair[1],
		off = pair[2],
		kind = pair[3],
		strength = strength,
		breath = breath,
		seq_i = idx,
		local_t = local_t,
		flash_span = flash_span,
		frame = f,
	}
end

--- 返回按 strength 插值后的 cz, off；nil 表示保留原色
local function flash_tint_for(syn)
	local env = flash_envelope(syn)
	if not env or (env.strength or 0) <= 0.001 then
		return nil, nil
	end
	local s = env.strength
	local cz, off = env.cz, env.off
	return {
		r = (cz.r or 0) * s,
		g = (cz.g or 0) * s,
		b = (cz.b or 0) * s,
		a = cz.a or 1,
	}, {
		r = (off.r or 0) * s,
		g = (off.g or 0) * s,
		b = (off.b or 0) * s,
	}
end

--- 闪烁时瞳孔形变：微颤 + XY 挤压拉伸（breath 越大越明显）
local function flash_pulse_for(syn)
	local env = flash_envelope(syn)
	if not env or (env.breath or 0) <= 0.001 then
		return nil
	end
	local b = env.breath
	local f = env.frame or Game():GetFrameCount()
	-- 红偏横拉、紫偏竖拉
	local sx, sy
	if env.kind == "red" then
		sx = 1 + 0.22 * b
		sy = 1 - 0.14 * b
	else
		sx = 1 - 0.12 * b
		sy = 1 + 0.20 * b
	end
	return {
		look_dx = math.sin(f * 0.95) * 3.2 * b,
		look_dy = math.cos(f * 1.25) * 2.4 * b,
		scale_x = sx,
		scale_y = sy,
	}
end

local function apply_entity_colorize(ent, cz, off, duration)
	if not ent then return end
	duration = tonumber(duration)
	if duration == nil then duration = -1 end
	if not cz then
		local col = Color(1, 1, 1, 1, 0, 0, 0)
		if ent.SetColor then
			ent:SetColor(col, math.max(1, duration > 0 and duration or 2), 80, false, false)
		else
			ent.Color = col
		end
		return
	end
	local col = make_occult_color(1, cz, off)
	if ent.SetColor then
		ent:SetColor(col, duration, 80, false, false)
	else
		ent.Color = col
	end
end

local function release_owned_laser(las)
	if not las then return end
	if las.Exists and not las:Exists() then return end
	if las.SetTimeout then
		las:SetTimeout(1)
	elseif las.Remove then
		las:Remove()
	end
end

local function release_techx_hover(fx)
	if not fx then return end
	-- RING_LUDOVICO 会忽略 SetTimeout(1)，必须 Remove（同 Craft_Ludovico_holder.clear_slot_ring）
	local las = fx.techx_ring
	fx.techx_ring = nil
	if auxi.check_all_exists(las) then
		if las.Radius ~= nil then las.Radius = 0 end
		las.Visible = false
		if las.CollisionDamage ~= nil then las.CollisionDamage = 0 end
		if las.Remove then las:Remove() end
	end
	local a = fx.techx_anchor
	fx.techx_anchor = nil
	if auxi.check_all_exists(a) then
		local ad = a:GetData()
		if ad then ad.removecd = 0 end
		if a.Remove then a:Remove() end
	end
end

local function clear_fx_tech_lasers(fx)
	if not fx then return end
	release_owned_laser(fx.tech2_laser)
	release_owned_laser(fx.tech1_laser)
	release_techx_hover(fx)
	fx.tech2_laser = nil
	fx.tech1_laser = nil
	fx.tech1_fired = nil
end

local function sanitize_gaze_laser(las)
	if not las then return end
	if las.CurveStrength ~= nil then las.CurveStrength = 0 end
	if las.HomingType ~= nil then las.HomingType = 0 end
	if las.DisableFollowParent ~= nil then las.DisableFollowParent = true end
	if las.SetDisableFollowParent then las:SetDisableFollowParent(true) end
	-- 高度/升空：只用世界坐标，清掉 Height / PositionOffset，避免双重抬高与玩家遗留
	if las.PositionOffset ~= nil then las.PositionOffset = Vector(0, 0) end
	if las.Height ~= nil then las.Height = 0 end
	if las.ParentOffset ~= nil then las.ParentOffset = Vector(0, 0) end
	las.Parent = nil
	las.DepthOffset = TECH_DEPTH
end

local function tech_lift_po(lift)
	-- 兼容旧引用；新路径不再用 PO 补偿升空
	return Vector(0, -(tonumber(lift) or 0) * TECH_LIFT_PO_MUL)
end

--- 月亮瞳孔视觉 → 世界坐标（与圣光 Beam / eye_screen_pos 同源）
local function moon_pupil_world_pos(fx, aim, apply_opts)
	if not fx or not fx.anchor then return nil end
	local room = Game():GetRoom()
	if not room or not fx.state then return nil end
	return moon.pupil_world_pos(room, fx.anchor, fx.lift, fx.state, fx.holder, aim, apply_opts)
end

--- 旧公式（探针对照）：不含 sway / Null / apply 布局
local function moon_pupil_world_pos_legacy(fx)
	if not fx or not fx.anchor then return nil end
	local lift = tonumber(fx.lift) or 0
	local origin = Vector(fx.anchor.X, fx.anchor.Y - lift)
	local room = Game():GetRoom()
	local st = fx.state
	if room and st then
		local scale = tonumber(st.scale) or 1
		local lx = tonumber(st._primary_look_x or st.look_x) or 0
		local ly = tonumber(st._primary_look_y or st.look_y) or 0
		if math.abs(lx) > 0.05 or math.abs(ly) > 0.05 then
			local base_s = room:WorldToScreenPosition(origin)
			local eye_s = base_s + Vector(lx * scale, ly * scale)
			origin = moon.screen_to_world(eye_s) or origin
		end
	end
	return origin
end

--- 独立生成科技激光（不用 player:FireTech*，避免继承镜像/弯勺等）
--- 不要用 ShootAngle(..., timeout=-1)：INIT 阶段可能直接判死，探针/画面都抓不到。
local function spawn_standalone_tech_laser(origin, aim, opts)
	opts = opts or {}
	if not origin or not aim then return nil end
	local dir = aim - origin
	local dist = dir:Length()
	if dist < 0.05 then
		dir = Vector(0, 1)
		dist = 1
	else
		dir = dir:Normalized()
	end
	local ang = dir:GetAngleDegrees()
	local source = opts.source
	local las = Isaac.Spawn(EntityType.ENTITY_LASER, TECH_LASER_VAR, 0, origin, Vector.Zero, source)
	if not las then return nil end
	las = las:ToLaser() or las
	las:GetData()[LASER_TAG] = opts.kind or "beam"
	sanitize_gaze_laser(las)
	las.Position = Vector(origin.X, origin.Y)
	las.Velocity = Vector.Zero
	las.Angle = ang
	if las.SetMaxDistance then
		las:SetMaxDistance(dist + 24)
	elseif las.MaxDistance ~= nil then
		las.MaxDistance = dist + 24
	end
	if opts.one_hit then
		if las.SetOneHit then las:SetOneHit(true) end
		las.OneHit = true
		if las.SetTimeout then las:SetTimeout(2) end
	elseif las.SetTimeout then
		las:SetTimeout(-1)
	end
	las.CollisionDamage = tonumber(opts.damage) or 3.5
	las.SpawnerEntity = source
	if las.ClearTearFlags and TearFlags and TearFlags.TEAR_NORMAL then
		pcall(function()
			las:ClearTearFlags(TearFlags.TEAR_NORMAL)
		end)
	end
	-- 尽量清掉玩家继承位
	if las.TearFlags ~= nil and BitSet128 then
		pcall(function() las.TearFlags = BitSet128(0, 0) end)
	end
	return las
end

local function update_standalone_tech_laser(las, origin, aim)
	if not auxi.check_all_exists(las) or not origin or not aim then return end
	local dir = aim - origin
	local dist = dir:Length()
	if dist < 0.05 then
		dir = Vector(0, 1)
		dist = 1
	else
		dir = dir:Normalized()
	end
	sanitize_gaze_laser(las)
	las.Position = Vector(origin.X, origin.Y)
	las.Velocity = Vector.Zero
	las.Angle = dir:GetAngleDegrees()
	if las.SetMaxDistance then
		las:SetMaxDistance(dist + 24)
	elseif las.MaxDistance ~= nil then
		las.MaxDistance = dist + 24
	end
	if las.SetTimeout then las:SetTimeout(-1) end
end

-- 前向声明：render_queued_moon 在邪眼自绘函数之前定义
local render_evil_eyes_at_moon
-- tick_fx 内调用；定义在 eye_synergies 之后
local tick_fx_tech_lasers

local function pdata(player)
	local d = player:GetData()
	local key = item.own_key .. "run"
	if not d[key] then
		d[key] = {
			phase = 0,
			gaze_seed = nil,
			gaze_timeout = 0,
			vis_alpha = 0,          -- 进度月显隐（与 phase 脱钩）
			indicator_seed = nil,  -- 淡出时仍可定位
			indicator_pos = nil,
			indicator_vel = nil,   -- 追随速度（路径模拟）
			look_target = nil,
			pursue = nil,          -- {switch=bool} 切目标时短暂加强加速
			observe = nil,         -- 目标消失后的就近观察
			fast_hide = false,
			hiding = false,        -- 正在隐藏：从低 alpha 起淡出
			counting = true,       -- 满月动画结束前禁止攒相
			fx = nil,
		}
	end
	return d[key]
end

local function ease_smooth(u)
	u = math.min(1, math.max(0, u))
	return u * u * (3 - 2 * u)
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function lerp_vec(a, b, t)
	if not a then return Vector(b.X, b.Y) end
	return Vector(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t)
end

local function phase_covers(_phase, blink_t)
	-- 默认完全张开；眨眼才闭合
	local t, b = COVER_FULL_T, COVER_FULL_B
	if blink_t and blink_t > 0 and BLINK_LEN > 0 then
		local u = 1 - (blink_t / BLINK_LEN)
		local close_u
		if u < 0.45 then
			close_u = u / 0.45
		else
			close_u = 1 - (u - 0.45) / 0.55
		end
		t = lerp(t, COVER_CLOSED_T, close_u)
		b = lerp(b, COVER_CLOSED_B, close_u)
	end
	return t, b
end

local function phase_scale(phase)
	phase = math.min(1, math.max(0, phase or 0))
	return PHASE_SCALE_MIN + (PHASE_SCALE_MAX - PHASE_SCALE_MIN) * phase
end

--- 0% → 进度月基准高度；100% → 进度满相高度（未顶到画面顶，留给满月 charge 升飞）
local function phase_lift_for(phase, cfg)
	phase = math.min(1, math.max(0, phase or 0))
	local base = cfg.phase_lift
	local top = math.max(base, cfg.phase_lift_top or PHASE_LIFT_TOP_DEFAULT)
	return base + (top - base) * phase
end

local function debug_options()
	local root = save.ModConfigSettings
	local dbg = root and root.QingRemasterOptions and root.QingRemasterOptions.Debug
	return dbg or {}
end

local function clamp_num(v, lo, hi, default)
	v = tonumber(v)
	if v == nil then return default end
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

local function fx_tuning()
	local dbg = debug_options()
	local lift_max = clamp_num(dbg.PareidoliaFxLiftMax, 120, 480, FX_LIFT_MAX_DEFAULT)
	return {
		lift_start = clamp_num(dbg.PareidoliaFxLiftStart, 0, 400, FX_LIFT_START_DEFAULT),
		lift_hover = clamp_num(dbg.PareidoliaFxLiftHover, 40, lift_max, FX_LIFT_HOVER_DEFAULT),
		lift_max = lift_max,
		screen_top_pct = clamp_num(dbg.PareidoliaFxScreenTopPct, 0.04, 0.40, FX_SCREEN_TOP_PCT_DEFAULT),
		ascend = math.floor(clamp_num(dbg.PareidoliaFxAscendFrames, 8, 120, FX.charge) + 0.5),
		phase_lift = clamp_num(dbg.PareidoliaPhaseLift, 10, 260, PHASE_LIFT_DEFAULT),
		phase_lift_top = PHASE_LIFT_TOP_DEFAULT,
		float_rate = clamp_num(dbg.PareidoliaFloatRate, 0.02, 0.5, FLOAT_RATE_DEFAULT),
	}
end

--- Potato for Scale：只缓存成功解析的 Type；失败不锁死，允许稍后重试
local potato_for_scale_type = nil
local function get_potato_for_scale_type()
	if type(potato_for_scale_type) == "number" then
		return potato_for_scale_type
	end
	local t = Isaac.GetEntityTypeByName("Potato Dummy")
	if t and t > 0 then
		potato_for_scale_type = t
		return t
	end
	return nil
end

local function is_training_dummy(ent)
	if not ent then return false end
	if ent.Type == EntityType.ENTITY_DUMMY then return true end
	local potato_t = get_potato_for_scale_type()
	if potato_t and ent.Type == potato_t and ent.Variant == 2 then
		return true
	end
	-- Potato for Scale entities2：id=231（Nerve Ending）variant=2
	if ent.Type == EntityType.ENTITY_NERVE_ENDING and ent.Variant == 2 then
		return true
	end
	if EntityConfig and EntityConfig.GetEntity then
		local ok, cfg = pcall(EntityConfig.GetEntity, ent.Type, ent.Variant, ent.SubType)
		if ok and cfg and cfg.GetName then
			local name = cfg:GetName()
			if name == "Potato Dummy" then return true end
		end
	end
	return false
end

--- 可锁定：训练假人优先（含 NO_TARGET 石化态）；不要求 IsVulnerableEnemy
local function is_gaze_lockable(ent)
	if not ent or not ent:Exists() or ent:IsDead() then return false end
	if is_training_dummy(ent) then return true end
	if ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then return false end
	if ent:IsEnemy() then return true end
	local npc = ent:ToNPC()
	if npc and npc:Exists() then return true end
	return false
end

local function find_enemy_by_seed(seed)
	if not seed then return nil end
	for _, ent in ipairs(Isaac.GetRoomEntities()) do
		if ent and ent.InitSeed == seed and is_gaze_lockable(ent) then
			return ent
		end
	end
	return nil
end

local function nearest_enemy(from_pos, max_r)
	max_r = max_r or 280
	local best, best_d = nil, max_r * max_r
	for _, ent in ipairs(Isaac.FindInRadius(from_pos, max_r, EntityPartition.ENEMY)) do
		if is_gaze_lockable(ent) then
			local d = from_pos:DistanceSquared(ent.Position)
			if d < best_d then
				best, best_d = ent, d
			end
		end
	end
	-- Dummy 有时不在 ENEMY 分区：全房再扫一遍
	if not best then
		for _, ent in ipairs(Isaac.GetRoomEntities()) do
			if is_gaze_lockable(ent) then
				local d = from_pos:DistanceSquared(ent.Position)
				if d < best_d then
					best, best_d = ent, d
				end
			end
		end
	end
	return best
end

local function list_lockable_enemies(exclude_seed)
	local list = {}
	for _, ent in ipairs(Isaac.GetRoomEntities()) do
		if is_gaze_lockable(ent) and ent.InitSeed ~= exclude_seed then
			list[#list + 1] = ent
		end
	end
	return list
end

local function is_prefer_hurt_target(ent)
	if not ent then return false end
	if is_training_dummy(ent) then return true end
	if ent.IsVulnerableEnemy and ent:IsVulnerableEnemy() then return true end
	return false
end

--- 目标消失后选下一个：靠近死亡点为主、玩家为辅；优先可受伤
local function pick_observe_enemy(player, exclude_seed, near_pos)
	local list = list_lockable_enemies(exclude_seed)
	if #list <= 0 then return nil end
	local dead_pos = near_pos
		or (player and player.Position)
		or Vector(0, 0)
	local player_pos = (player and player.Position) or dead_pos
	local best, best_score = nil, nil
	for _, ent in ipairs(list) do
		local d_dead = ent.Position:DistanceSquared(dead_pos)
		local d_player = ent.Position:DistanceSquared(player_pos)
		-- 死亡点权重更高，同时兼顾玩家附近
		local score = d_dead * 0.65 + d_player * 0.35
		if not is_prefer_hurt_target(ent) then
			score = score + 90000
		end
		if not best_score or score < best_score then
			best, best_score = ent, score
		end
	end
	return best
end

--- 透明度联动的额外缩放（相对原比例再缩小；显隐/瞬移共用）
local function alpha_scale_mul(alpha)
	local u = 0
	if VIS_ALPHA_PEAK > 0.001 then
		u = math.min(1, math.max(0, (alpha or 0) / VIS_ALPHA_PEAK))
	end
	return VIS_SCALE_AT_ZERO + (1 - VIS_SCALE_AT_ZERO) * ease_smooth(u)
end

--- 切目标：短暂提高追随响应（不加冲量，避免抖）
local function begin_travel(rec, to_pos, cfg, opts)
	opts = opts or {}
	if not to_pos then return end
	if not rec.indicator_pos then
		rec.indicator_pos = Vector(to_pos.X, to_pos.Y)
		rec.indicator_vel = Vector(0, 0)
	elseif not rec.indicator_vel then
		rec.indicator_vel = Vector(0, 0)
	end
	rec.pursue = {
		boost = opts.switch and 12 or 0,
	}
	rec._smooth_goal = Vector(to_pos.X, to_pos.Y)
end

--- 瞬移：旧位快隐（丢失跟随但终点仍同步）→ 瞬间落到新位 → 快现
local function begin_warp(rec, to_pos, to_vel)
	if not to_pos then return end
	to_vel = to_vel or Vector(0, 0)
	if rec.warp then
		-- 只更新解算终点，不把可见月亮吸过去
		rec.warp.to = Vector(to_pos.X, to_pos.Y)
		rec.warp.to_vel = Vector(to_vel.X, to_vel.Y)
		return
	end
	local from = rec.indicator_pos or to_pos
	rec.warp = {
		stage = "out",
		t = 0,
		from_a = math.max(VIS_ALPHA_START, rec.vis_alpha or VIS_ALPHA_PEAK),
		from = Vector(from.X, from.Y),
		to = Vector(to_pos.X, to_pos.Y),
		to_vel = Vector(to_vel.X, to_vel.Y),
	}
	rec.pursue = nil
	rec.indicator_vel = Vector(0, 0)
end

local function tick_warp(rec)
	local w = rec.warp
	if not w then return false end
	w.t = (w.t or 0) + 1
	if w.stage == "out" then
		-- 淡出停在丢失跟随的旧位；终点只做后台同步
		rec.indicator_pos = Vector(w.from.X, w.from.Y)
		rec.indicator_vel = Vector(0, 0)
		rec.look_target = Vector(w.from.X, w.from.Y)
		local u = math.min(1, w.t / WARP_OUT_FRAMES)
		rec.vis_alpha = (w.from_a or VIS_ALPHA_PEAK) * (1 - u)
		rec.hiding = false
		rec.fast_hide = false
		if u >= 1 then
			-- 瞬移瞬间重新解算：落到最新终点再显现
			rec.indicator_pos = Vector(w.to.X, w.to.Y)
			rec.indicator_vel = Vector(w.to_vel.X, w.to_vel.Y)
			rec._smooth_goal = Vector(w.to.X, w.to.Y)
			rec._last_target_pos = Vector(w.to.X, w.to.Y)
			rec.look_target = Vector(w.to.X, w.to.Y)
			w.stage = "in"
			w.t = 0
		end
		return true
	end
	-- in：已在新位，淡入放大
	rec.indicator_pos = Vector(w.to.X, w.to.Y)
	rec.indicator_vel = Vector(w.to_vel.X, w.to_vel.Y)
	rec._smooth_goal = Vector(w.to.X, w.to.Y)
	rec.look_target = Vector(w.to.X, w.to.Y)
	local u = math.min(1, w.t / WARP_IN_FRAMES)
	rec.vis_alpha = VIS_ALPHA_START + (VIS_ALPHA_PEAK - VIS_ALPHA_START) * u
	if u >= 1 then
		rec.vis_alpha = VIS_ALPHA_PEAK
		rec.warp = nil
		rec.warp_cd = WARP_COOLDOWN
	end
	return true
end

--- 稳定追随：平滑目标点 + 限速靠近。
--- 仅当敌人坐标真的跳变（瞬移）才快隐再显现；掉队则加速追赶。
local function tick_pursue(rec, desired_pos, desired_vel, cfg)
	if not desired_pos then return end
	desired_vel = desired_vel or Vector(0, 0)
	if not rec.indicator_pos then
		rec.indicator_pos = Vector(desired_pos.X, desired_pos.Y)
		rec.indicator_vel = Vector(desired_vel.X, desired_vel.Y)
		rec._last_target_pos = Vector(desired_pos.X, desired_pos.Y)
		rec._smooth_goal = Vector(desired_pos.X, desired_pos.Y)
		return
	end

	-- 每帧记录敌人当前位置，避免 warp/掉帧后把「多帧路程」误判成瞬移
	local last = rec._last_target_pos
	local jump = last and last:Distance(desired_pos) or 0
	rec._last_target_pos = Vector(desired_pos.X, desired_pos.Y)

	if rec.warp then
		begin_warp(rec, desired_pos, desired_vel)
		return
	end

	local cd = rec.warp_cd or 0
	if cd > 0 then
		rec.warp_cd = cd - 1
	end

	-- 只认敌人单帧真跳变；冷却期内一律加速跟随
	if cd <= 0 and last then
		local spd = desired_vel:Length()
		local teleported = jump >= TELEPORT_SNAP_DIST and jump > (spd * 4 + 50)
		if teleported then
			begin_warp(rec, desired_pos, desired_vel)
			return
		end
	end

	local rate = (cfg and cfg.float_rate) or FLOAT_RATE_DEFAULT
	local max_spd = 4.0 + rate * 42
	local goal_follow = 0.38
	local steer = 0.28
	local vel_match = 0.25
	local pursue = rec.pursue
	if pursue and (pursue.boost or 0) > 0 then
		max_spd = max_spd * 1.35
		goal_follow = 0.55
		steer = 0.42
		pursue.boost = pursue.boost - 1
	end

	-- 月亮掉队 / 刚闪现后：模仿并加速追赶（不是再闪现）
	local lag = rec.indicator_pos:Distance(desired_pos)
	if lag > 28 or cd > 0 then
		local catch = 1 + math.min(2.6, (lag - 28) / 40)
		if cd > 0 then catch = math.max(catch, 1.8) end
		max_spd = max_spd * catch
		steer = math.min(0.78, steer * (0.85 + catch * 0.35))
		goal_follow = math.min(0.78, goal_follow * (0.9 + catch * 0.25))
		vel_match = math.min(0.85, 0.25 + math.max(0, lag - 28) / 70)
	end

	-- 先低通目标位置，避免敌人 Velocity/贴图抖动传到月亮
	local sg = rec._smooth_goal or desired_pos
	sg = Vector(
		sg.X + (desired_pos.X - sg.X) * goal_follow,
		sg.Y + (desired_pos.Y - sg.Y) * goal_follow
	)
	rec._smooth_goal = sg
	local goal = Vector(
		sg.X + desired_vel.X * PURSUE_LEAD,
		sg.Y + desired_vel.Y * PURSUE_LEAD
	)

	local pos = rec.indicator_pos
	local vel = rec.indicator_vel or Vector(0, 0)
	local to_x = goal.X - pos.X
	local to_y = goal.Y - pos.Y
	local dist = math.sqrt(to_x * to_x + to_y * to_y)

	if dist < 1.5 then
		rec.indicator_pos = Vector(sg.X, sg.Y)
		rec.indicator_vel = Vector(
			vel.X * 0.5 + desired_vel.X * 0.5,
			vel.Y * 0.5 + desired_vel.Y * 0.5
		)
		return
	end

	local arrive = 40
	local want_spd = max_spd
	if dist < arrive then
		want_spd = max_spd * (dist / arrive)
	end
	local want_x = to_x * (want_spd / dist)
	local want_y = to_y * (want_spd / dist)
	want_x = want_x + desired_vel.X * vel_match
	want_y = want_y + desired_vel.Y * vel_match

	vel = Vector(
		vel.X + (want_x - vel.X) * steer,
		vel.Y + (want_y - vel.Y) * steer
	)
	local spd = vel:Length()
	if spd > max_spd then
		vel = vel * (max_spd / spd)
	end
	rec.indicator_pos = Vector(pos.X + vel.X, pos.Y + vel.Y)
	rec.indicator_vel = vel
end

local function hide_indicator(rec, opts)
	opts = opts or {}
	rec.gaze_seed = nil
	rec.gaze_timeout = 0
	rec.indicator_seed = nil
	rec.look_target = nil
	rec.pursue = nil
	rec.observe = nil
	rec.warp = nil
	rec.warp_cd = nil
	rec._last_target_pos = nil
	rec._smooth_goal = nil
	rec.fast_hide = opts.fast ~= false
	if opts.clear_pos then
		rec.indicator_pos = nil
		rec.indicator_vel = nil
	end
	if opts.instant then
		rec.vis_alpha = 0
		rec.hiding = false
		rec._draw = nil
		rec.fast_hide = false
	end
end

local function interp_t()
	return (Isaac.GetFrameCount() % 2) * 0.5
end

local function is_water_reflect()
	local room = Game():GetRoom()
	return room and room.GetRenderMode and room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT
end

--- 满月目标屏幕 Y：基于屏高，落在屏顶边界稍下方（无精确 HUD 边界 API，用比例近似）
local function desired_fx_screen_y(cfg)
	local h = (Isaac.GetScreenHeight and Isaac.GetScreenHeight()) or 270
	local pct = (cfg and cfg.screen_top_pct) or FX_SCREEN_TOP_PCT_DEFAULT
	-- 略加一点像素边距，避免贴死黑边/屏顶
	return math.max(48, math.floor(h * pct + 0.5))
end

local function compute_top_lift(anchor, cfg)
	local room = Game():GetRoom()
	local min_lift = math.max(70, cfg and cfg.lift_start or FX_LIFT_START_DEFAULT)
	local max_lift = (cfg and cfg.lift_max) or FX_LIFT_MAX_DEFAULT
	if not room or not anchor then
		return math.min(max_lift, math.max(min_lift, cfg and cfg.lift_hover or FX_LIFT_HOVER_DEFAULT))
	end
	local target_y = desired_fx_screen_y(cfg)
	local best = min_lift
	for lift = min_lift, max_lift, 4 do
		local s = room:WorldToScreenPosition(Vector(anchor.X, anchor.Y - lift))
		best = lift
		if s.Y <= target_y then
			break
		end
	end
	return best
end

--- 透视：升得越高看起来越小（与 lift 进度绑定；终点约为 near * FX_FAR_SCALE）
local function perspective_scale(scale_from, lift_u)
	lift_u = math.min(1, math.max(0, lift_u or 0))
	local near = scale_from or PHASE_SCALE_MAX
	local far = math.max(0.05, FX_FAR_SCALE)
	local k = (1 / far) - 1
	return near / (1 + k * ease_smooth(lift_u))
end

--- 圣光标记：Colorize 渐白；每帧 duration=1 覆盖。
--- 受伤红不能靠 GetColor 回读（会被本帧标记盖住并反馈），用 TAKE_DMG 盖章窗口揉进 Offset。
local MARK_DATA = item.own_key .. "mark"

local function note_mark_hurt(ent, amount)
	if not ent then return end
	local d = ent:GetData()
	local m = d[MARK_DATA] or {}
	d[MARK_DATA] = m
	m.hurt_until = Game():GetFrameCount() + 5
	m.hurt_amt = math.min(1, 0.4 + math.min(1.2, tonumber(amount) or 0) * 0.06)
end

local function read_mark_hurt(ent)
	if not ent then return 0 end
	local m = ent:GetData()[MARK_DATA]
	if not m or not m.hurt_until then return 0 end
	if Game():GetFrameCount() > m.hurt_until then return 0 end
	return math.min(1, tonumber(m.hurt_amt) or 0.7)
end

local function apply_mark_white(ent, white_u)
	if not ent or not ent:Exists() or ent:IsDead() then return end
	white_u = math.min(1, math.max(0, white_u or 0))
	local flash = read_mark_hurt(ent)
	-- 越白越盖住受伤红，但仍留一点可调制（参考 Seeker duration=1 + Colorize）
	local keep_flash = flash * (1 - white_u * 0.55)
	local c = Color(1, 1, 1, 1, keep_flash, keep_flash * 0.08, keep_flash * 0.04)
	if c.SetColorize then
		c:SetColorize(1, 1, 1, white_u)
	end
	ent:SetColor(c, 1, MARK_COLOR_PRIO, false, false)
end

local function clear_mark_white(ent)
	if not ent then return end
	local d = ent:GetData()
	d[MARK_DATA] = nil
	if not ent:Exists() then return end
	ent:SetColor(Color(1, 1, 1, 1, 0, 0, 0), 2, MARK_COLOR_PRIO, true, false)
end

local function end_fx(rec)
	if not rec or not rec.fx then return end
	local fx = rec.fx
	if fx.target_seed then
		local t = find_enemy_by_seed(fx.target_seed)
		if t then clear_mark_white(t) end
	end
	if fx.evil_eyes then
		for _, row in ipairs(fx.evil_eyes) do
			local e = row and row.ent
			if e and e:Exists() then e:Remove() end
		end
		fx.evil_eyes = nil
	end
	clear_fx_tech_lasers(fx)
	rec.fx = nil
	rec._draw = nil
	rec.phase = 0
	rec.counting = true
	-- 演出结束后月亮已升隐；新一轮须等玩家再攻击，不要立刻盯新目标
	hide_indicator(rec, {fast = true})
end

--- 逻辑帧只排队世界坐标；身体跟 anchor，眼睛跟 look_world
local function queue_moon_draw(rec, holder, st, target_seed, anchor, lift, look_world, extra)
	extra = extra or {}
	local vel = extra.vel or rec.indicator_vel
	rec._draw = {
		holder = holder,
		state = st,
		target_seed = target_seed,
		anchor = anchor and Vector(anchor.X, anchor.Y) or nil,
		vel = vel and Vector(vel.X, vel.Y) or nil,
		lift = lift or 0,
		look_world = look_world and Vector(look_world.X, look_world.Y) or nil,
		ray_width = tonumber(extra.ray_width),
		ray_alpha = tonumber(extra.ray_alpha),
		hit_world = extra.hit_world and Vector(extra.hit_world.X, extra.hit_world.Y) or nil,
		extra_pupils = extra.extra_pupils,
		primary_pupil_scale = extra.primary_pupil_scale,
		pupil_cz = extra.pupil_cz,
		pupil_offset = extra.pupil_offset,
		pupil_flash = extra.pupil_flash,
		ray_colorize = extra.ray_colorize,
		ray_color_offset = extra.ray_color_offset,
		side_moons = extra.side_moons,
		moms_moon = extra.moms_moon,
		sore_moons = extra.sore_moons,
		evil_eyes = extra.evil_eyes,
	}
	if st then
		moon.tick(st, 1)
	end
end

local function sway_offset(lift)
	local u = math.min(1, math.max(0, ((lift or 0) - 70) / 160))
	if u <= 0.04 then return Vector(0, 0) end
	local t = Game():GetFrameCount() + interp_t()
	local amp = 3.2 + 6.5 * u
	return Vector(math.sin(t * 0.09) * amp, math.cos(t * 0.13) * amp * 0.42)
end

local function ensure_ray(rec)
	if rec._ray_beam then return rec._ray_beam, rec._ray_spr end
	if not Beam then return nil, nil end
	local spr = Sprite()
	spr:Load(moon.RAY_ANM2, true)
	spr:Play("Idle", true)
	rec._ray_spr = spr
	-- Beam 会复制 Sprite；之后必须改 beam:GetSprite()，改外层 spr 无效
	rec._ray_beam = Beam(spr, "Ray", false, false)
	return rec._ray_beam, spr
end

local function paint_sprite_color(spr, col)
	if not spr or not col then return end
	spr.Color = col
	if spr.GetLayer then
		local ok, layer = pcall(function()
			return spr:GetLayer("Ray") or spr:GetLayer(0)
		end)
		if ok and layer and layer.SetColor then
			pcall(function() layer:SetColor(col) end)
		end
	end
end

local function render_holy_ray(rec, from_screen, to_screen, opts)
	if not from_screen or not to_screen then return end
	opts = opts or {}
	local width = tonumber(opts.width) or 0.55
	local a = tonumber(opts.alpha) or 0.7
	local beam, spr = ensure_ray(rec)
	local cz = opts.colorize
	local off = opts.color_offset
	local col
	if cz then
		col = make_occult_color(a, cz, off)
	else
		col = Color(1, 1, 1, a, 0.15 * a, 0.12 * a, 0.05 * a)
	end
	-- 关键：Beam 内部是拷贝，必须 GetSprite
	local beam_spr = (beam and beam.GetSprite) and beam:GetSprite() or nil
	paint_sprite_color(beam_spr, col)
	paint_sprite_color(spr, col)
	if beam_spr and beam_spr.SetFrame then
		pcall(function() beam_spr:SetFrame("Idle", 0) end)
	elseif spr and spr.SetFrame then
		pcall(function() spr:SetFrame("Idle", 0) end)
	end
	if beam and beam.Add and beam.Render then
		beam:Add(from_screen, 0, width)
		beam:Add(to_screen, moon.RAY_SHEET_Y or 192, width)
		beam:Render()
		return
	end
	if not spr then return end
	local d = to_screen - from_screen
	local len = d:Length()
	if len < 4 then return end
	local ang
	if math.atan2 then
		ang = math.deg(math.atan2(d.Y, d.X))
	else
		ang = math.deg(math.atan(d.Y, d.X))
	end
	spr.Rotation = ang - 90
	spr.Scale = Vector(width, len / (moon.RAY_SHEET_Y or 192))
	spr:Render(from_screen, Vector.Zero, Vector.Zero)
	spr.Rotation = 0
	spr.Scale = Vector(1, 1)
end

local function render_queued_moon(rec)
	local d = rec._draw
	if not d or not d.holder or not d.state then return false end
	local room = Game():GetRoom()
	if not room then return false end
	-- 身体只跟排队的漂移动画，禁止每帧吸附到敌人（否则无法「先看再挪」）
	local anchor = d.anchor
	local look_world = d.look_world or anchor
	local target = find_enemy_by_seed(d.target_seed)
	if target then
		-- 瞳孔只跟当前位置，不加 Velocity*t（否则显示帧会抖）
		look_world = target.Position
		d.hit_world = Vector(target.Position.X, target.Position.Y)
	end
	if not anchor then return false end
	-- 不用 vel*t 外推身体：逻辑帧已积分，渲染再加会抖
	local base = room:WorldToScreenPosition(Vector(anchor.X, anchor.Y - (d.lift or 0)))
	local screen = base + sway_offset(d.lift)
	local look_screen = look_world and room:WorldToScreenPosition(look_world) or nil
	if look_screen then
		moon.set_look_at(d.state, screen, look_screen)
		d.state.target_rot = 0
		d.state.rot = 0
		-- 渲染帧只轻跟瞳孔，避免每显示帧 0.55 追敌速度造成眼珠抖
		moon.tick_look(d.state, 0.22)
	end
	local spr = moon.draw(d.holder, screen, d.state, {
		dt = 0,
		tick = false,
		extra_pupils = d.extra_pupils,
		primary_pupil_scale = d.primary_pupil_scale,
		pupil_cz = d.pupil_cz,
		pupil_offset = d.pupil_offset,
		pupil_flash = d.pupil_flash,
	})
	d.eye_screen = moon.eye_screen_pos(screen, d.state, spr)
	d.look_screen = look_screen
	local ray_cz = d.ray_colorize
	local ray_off = d.ray_color_offset or d.pupil_offset
	if d.ray_width and d.ray_width > 0.01 and d.eye_screen and look_screen then
		render_holy_ray(rec, d.eye_screen, look_screen, {
			width = d.ray_width,
			alpha = d.ray_alpha or 0.7,
			colorize = ray_cz,
			color_offset = ray_off,
		})
	end

	-- 邪眼：月亮画完后再自绘（在白光外圈 + 自带小白光）
	if d.evil_eyes then
		render_evil_eyes_at_moon(rec, screen, d.evil_eyes, d.state and d.state.scale)
	end

	if rec.fx and d.eye_screen and rec.fx._tech_laser_dbg then
		rec.fx._tech_laser_dbg.eye_screen_render = Vector(d.eye_screen.X, d.eye_screen.Y)
	end

	-- 内眼：主月亮左右两侧 30% 小月亮
	local sides = d.side_moons
	if sides then
		local main_sc = d.state.scale or 1
		local a = d.state.alpha or 1
		for i = 1, #sides do
			local sm = sides[i]
			if sm and sm.holder and sm.state then
				local side_screen = screen + Vector((sm.side or 1) * INNER_SIDE_BASE * main_sc, 4)
				local side_look = sm.look_world
				local side_look_screen = side_look and room:WorldToScreenPosition(side_look) or look_screen
				moon.set_alpha(sm.state, a)
				sm.state.scale = main_sc * INNER_MOON_SCALE
				sm.state.detailed_back = moon.debug.detailed_back ~= false
				sm.state.rotate_with_look = false
				sm.state.target_rot = 0
				sm.state.rot = 0
				if side_look_screen then
					moon.set_look_at(sm.state, side_screen, side_look_screen)
					moon.tick_look(sm.state, 0.28)
				end
				local sspr = moon.draw(sm.holder, side_screen, sm.state, {dt = 0, tick = false})
				local side_eye = moon.eye_screen_pos(side_screen, sm.state, sspr)
				local rw = (d.ray_width or 0) * 0.55
				if rw > 0.02 and side_eye and side_look_screen then
					render_holy_ray(rec, side_eye, side_look_screen, {
						width = rw,
						alpha = (d.ray_alpha or 0.7) * 0.75,
						colorize = d.ray_colorize,
						color_offset = d.ray_color_offset or d.pupil_offset,
					})
				end
			end
		end
	end

	-- 妈妈的眼睛：瞳孔后方小眼睛，盯对称落点
	local mm = d.moms_moon
	if mm and mm.holder and mm.state and d.eye_screen then
		local main_sc = d.state.scale or 1
		local a = d.state.alpha or 1
		local eye = d.eye_screen
		local behind
		if look_screen then
			local dir = look_screen - eye
			local len = dir:Length()
			if len > 0.5 then
				behind = eye - dir * (22 * main_sc / len)
			else
				behind = eye + Vector(0, 18 * main_sc)
			end
		else
			behind = eye + Vector(0, 18 * main_sc)
		end
		moon.set_alpha(mm.state, a)
		mm.state.scale = main_sc * MOMS_EYE_SCALE
		mm.state.detailed_back = moon.debug.detailed_back ~= false
		mm.state.rotate_with_look = false
		mm.state.target_rot = 0
		mm.state.rot = 0
		local moms_look = mm.look_world
		local moms_look_screen = moms_look and room:WorldToScreenPosition(moms_look) or nil
		if moms_look_screen then
			moon.set_look_at(mm.state, behind, moms_look_screen)
			moon.tick_look(mm.state, 0.28)
		end
		local mspr = moon.draw(mm.holder, behind, mm.state, {dt = 0, tick = false})
		local moms_eye = moon.eye_screen_pos(behind, mm.state, mspr)
		local rw = (d.ray_width or 0) * 0.5
		if rw > 0.02 and moms_eye and moms_look_screen then
			render_holy_ray(rec, moms_eye, moms_look_screen, {
				width = rw,
				alpha = (d.ray_alpha or 0.7) * 0.7,
				colorize = d.ray_colorize,
				color_offset = d.ray_color_offset or d.pupil_offset,
			})
		end
	end

	-- 眼瘤（多眼症）：随机屏幕偏移的小月亮
	local sores = d.sore_moons
	if sores then
		local main_sc = d.state.scale or 1
		local a = d.state.alpha or 1
		for i = 1, #sores do
			local sm = sores[i]
			if sm and sm.holder and sm.state then
				local ox = tonumber(sm.ox) or 0
				local oy = tonumber(sm.oy) or 0
				local side_screen = screen + Vector(ox * main_sc, oy * main_sc)
				local side_look = sm.look_world
				local side_look_screen = side_look and room:WorldToScreenPosition(side_look) or look_screen
				moon.set_alpha(sm.state, a)
				sm.state.scale = main_sc * EYESORE_MOON_SCALE
				sm.state.detailed_back = moon.debug.detailed_back ~= false
				sm.state.rotate_with_look = false
				sm.state.target_rot = 0
				sm.state.rot = 0
				if side_look_screen then
					moon.set_look_at(sm.state, side_screen, side_look_screen)
					moon.tick_look(sm.state, 0.28)
				end
				local sspr = moon.draw(sm.holder, side_screen, sm.state, {dt = 0, tick = false})
				local side_eye = moon.eye_screen_pos(side_screen, sm.state, sspr)
				local rw = (d.ray_width or 0) * 0.45
				if rw > 0.02 and side_eye and side_look_screen then
					render_holy_ray(rec, side_eye, side_look_screen, {
						width = rw,
						alpha = (d.ray_alpha or 0.7) * 0.7,
						colorize = d.ray_colorize,
						color_offset = d.ray_color_offset or d.pupil_offset,
					})
				end
			end
		end
	end

	return true
end

--- 从 ImGui/ModConfig 拉预览开关到 moon.debug（每帧一次即可）
local function sync_moon_debug_from_options()
	local dbg = debug_options()
	moon.debug.enabled = dbg.PareidoliaPreview == true
	if dbg.PareidoliaDetailedBack == nil then
		moon.debug.detailed_back = true
	else
		moon.debug.detailed_back = dbg.PareidoliaDetailedBack == true
	end
	moon.debug.force_spin = dbg.PareidoliaForceSpin == true
end

local function source_player(source)
	if not source or not source.Entity then return nil end
	local e = source.Entity
	local p = e:ToPlayer()
	if p then return p, 1 end
	local fam = e:ToFamiliar()
	if fam and fam.Player then return fam.Player, FAMILIAR_PHASE_MUL end
	local sp = e.SpawnerEntity
	if sp then
		p = sp:ToPlayer()
		if p then return p, 1 end
		fam = sp:ToFamiliar()
		if fam and fam.Player then return fam.Player, FAMILIAR_PHASE_MUL end
	end
	return nil
end

local function resonance_damage(player)
	return player.Damage * RES_DAMAGE_MUL + RES_DAMAGE_FLAT
end

--- 眼类视觉/攻击兼容
local function eye_synergies(player)
	local s = {
		twenty = false,
		pupula = false,
		inner = false,
		moms = false,
		eyesore = false,
		poly = false,
		occult = false,
		proptosis = false,
		evil = false,
		ludo = false,
		tech1 = false,
		tech2 = false,
		techx = false,
	}
	if not player then return s end
	s.twenty = player:HasCollectible(CollectibleType.COLLECTIBLE_20_20)
	s.pupula = player:HasCollectible(CollectibleType.COLLECTIBLE_PUPULA_DUPLEX)
	s.inner = player:HasCollectible(CollectibleType.COLLECTIBLE_INNER_EYE)
	s.moms = player:HasCollectible(CollectibleType.COLLECTIBLE_MOMS_EYE)
	s.eyesore = player:HasCollectible(CollectibleType.COLLECTIBLE_EYE_SORE)
	s.poly = player:HasCollectible(CollectibleType.COLLECTIBLE_POLYPHEMUS)
	s.occult = player:HasCollectible(CollectibleType.COLLECTIBLE_EYE_OF_THE_OCCULT)
	s.proptosis = player:HasCollectible(CollectibleType.COLLECTIBLE_PROPTOSIS)
	s.evil = player:HasCollectible(CollectibleType.COLLECTIBLE_EVIL_EYE)
	s.ludo = player:HasCollectible(CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE)
	s.tech1 = player:HasCollectible(CollectibleType.COLLECTIBLE_TECHNOLOGY)
	s.tech2 = player:HasCollectible(CollectibleType.COLLECTIBLE_TECHNOLOGY_2)
	s.techx = player:HasCollectible(CollectibleType.COLLECTIBLE_TECH_X)
	return s
end

local function build_extra_pupils(player)
	local syn = eye_synergies(player)
	local list = {}
	local tint_cz = flash_tint_for(syn)
	-- 偏移由 moon.layout_pupils 环绕；附加瞳约 30%
	if syn.twenty then
		list[#list + 1] = {
			scale = 0.30,
			cz = tint_cz or {r = 0.2, g = 0.85, b = 1.0, a = 1},
		}
	end
	if syn.pupula then
		list[#list + 1] = {
			scale = 0.30,
			cz = tint_cz or {r = 0.95, g = 0.3, b = 0.85, a = 1},
		}
	end
	if #list == 0 then return nil end
	return list
end

--- 科技/玄秘/邪眼：平时原色，闪烁帧才上色（与视线/激光同步）
local function pupil_style_for(player)
	local syn = eye_synergies(player)
	if syn.tech1 or syn.tech2 or syn.occult or syn.evil then
		return flash_tint_for(syn)
	end
	return nil, nil
end

local function pupil_cz_for(player)
	local cz = pupil_style_for(player)
	return cz
end

local function pupil_offset_for(player)
	local _, off = pupil_style_for(player)
	return off
end

local function primary_pupil_scale_for(player)
	if eye_synergies(player).poly then
		return POLY_PUPIL_SCALE
	end
	return 1
end

--- 满月科技激光：独立生成；视线仍用圣光 Beam（不替代）
tick_fx_tech_lasers = function(player, fx, syn, hit_pos)
	if not player or not fx or not syn then return end
	local aim = hit_pos or fx.lock_pos or fx.anchor_target or fx.anchor

	-- 科技X 悬浮圈不依赖瞳孔射线；视线失败时仍继续缩圈。
	-- RING_LUDOVICO 必须挂在 MeusNil 锚点上，禁止每帧 Parent=nil。
	do
		local pos = fx.lock_pos or aim
		local anchor = fx.techx_anchor
		if pos and auxi.check_all_exists(anchor) then
			anchor.Position = Vector(pos.X, pos.Y)
			anchor.Velocity = Vector.Zero
			anchor.Visible = false
			local ad = anchor:GetData()
			if (ad.removecd or 0) < 120 then ad.removecd = 999999 end
		elseif not auxi.check_all_exists(anchor) then
			fx.techx_anchor = nil
			anchor = nil
		end
		local ring = fx.techx_ring
		if auxi.check_all_exists(ring) and auxi.check_all_exists(anchor) then
			local life = math.max(24, tonumber(fx.techx_life) or 48)
			local age = (tonumber(fx.techx_age) or 0) + 1
			fx.techx_age = age
			local u = math.min(1, age / life)
			local r0 = tonumber(fx.techx_r0) or TECHX_START_R
			local r = r0 * (1 - u)
			if age >= life or r <= 2 then
				release_techx_hover(fx)
			else
				ring.Position = Vector(anchor.Position.X, anchor.Position.Y)
				ring.Velocity = Vector.Zero
				ring.Parent = anchor
				if ring.ParentOffset ~= nil then ring.ParentOffset = Vector(0, TECHX_ANCHOR_H) end
				if ring.DisableFollowParent ~= nil then ring.DisableFollowParent = false end
				if ring.SetDisableFollowParent then ring:SetDisableFollowParent(false) end
				ring.SubType = TECHX_RING_SUB
				if ring.SetTimeout then ring:SetTimeout(999999) end
				if ring.Shrink ~= nil then ring.Shrink = false end
				if ring.Radius ~= nil then ring.Radius = r end
			end
		else
			release_techx_hover(fx)
		end
	end

	if not aim or not fx.anchor then
		release_owned_laser(fx.tech2_laser)
		release_owned_laser(fx.tech1_laser)
		fx.tech2_laser = nil
		fx.tech1_laser = nil
		return
	end
	local room = Game():GetRoom()
	local pupils = build_extra_pupils(player)
	local p_scale = primary_pupil_scale_for(player)
	local apply_opts = {
		sway = sway_offset(fx.lift),
		look_tick = 0.22,
		extra_pupils = pupils,
		primary_pupil_scale = p_scale,
		pupil_flash = flash_pulse_for(syn),
	}
	local eye_screen = nil
	if room and fx.state then
		eye_screen = moon.pupil_screen_pos(room, fx.anchor, fx.lift, fx.state, fx.holder, aim, apply_opts)
	end
	local origin = eye_screen and moon.screen_to_world(eye_screen) or moon_pupil_world_pos(fx, aim, apply_opts)
	if not origin then
		release_owned_laser(fx.tech2_laser)
		release_owned_laser(fx.tech1_laser)
		fx.tech2_laser = nil
		fx.tech1_laser = nil
		return
	end
	fx._tech_laser_dbg = {
		frame = Game():GetFrameCount(),
		origin = Vector(origin.X, origin.Y),
		origin_legacy = moon_pupil_world_pos_legacy(fx),
		eye_screen_tick = eye_screen and Vector(eye_screen.X, eye_screen.Y) or nil,
		aim = Vector(aim.X, aim.Y),
		lift = fx.lift,
		scale = fx.state and fx.state.scale,
	}
	local dmg = resonance_damage(player)
	local want_beam = (fx.stage == "charge" or fx.stage == "strike" or fx.stage == "fade")
		and (tonumber(fx.ray_alpha) or 0) > 0.05

	-- 科技2：持续激光（跟瞳孔视觉点 → 目标落点）
	if syn.tech2 and want_beam then
		local las = fx.tech2_laser
		if auxi.check_all_exists(las) then
			update_standalone_tech_laser(las, origin, aim)
			las.CollisionDamage = dmg * 0.13
		else
			fx.tech2_laser = spawn_standalone_tech_laser(origin, aim, {
				source = player,
				damage = dmg * 0.13,
				one_hit = false,
				kind = "tech2",
			})
		end
	else
		release_owned_laser(fx.tech2_laser)
		fx.tech2_laser = nil
	end

	-- 科技1：打击瞬间 OneHit
	if syn.tech1 and fx.stage == "strike" and not fx.tech1_fired then
		fx.tech1_fired = true
		fx.tech1_laser = spawn_standalone_tech_laser(origin, aim, {
			source = player,
			damage = dmg * 0.85,
			one_hit = true,
			kind = "tech1",
		})
	elseif not auxi.check_all_exists(fx.tech1_laser) then
		fx.tech1_laser = nil
	end

	-- 激光闪烁染色（短 duration，不影响圣光柱 -1 染色）
	do
		local cz, off = flash_tint_for(syn)
		apply_entity_colorize(fx.tech2_laser, cz, off, 2)
		apply_entity_colorize(fx.tech1_laser, cz, off, 2)
		apply_entity_colorize(fx.techx_ring, cz, off, 2)
	end
	local dbg = fx._tech_laser_dbg
	if dbg then
		dbg.owned_tech1 = auxi.check_all_exists(fx.tech1_laser)
		dbg.owned_tech2 = auxi.check_all_exists(fx.tech2_laser)
		dbg.owned_techx = auxi.check_all_exists(fx.techx_ring)
		local las, kind = nil, nil
		if auxi.check_all_exists(fx.tech2_laser) then
			las = fx.tech2_laser
			kind = "tech2"
		elseif auxi.check_all_exists(fx.tech1_laser) then
			las = fx.tech1_laser
			kind = "tech1"
		elseif auxi.check_all_exists(fx.techx_ring) then
			las = fx.techx_ring
			kind = "techx"
		end
		if las then
			dbg.laser_kind = kind
			dbg.laser_pos = Vector(las.Position.X, las.Position.Y)
			dbg.laser_po = las.PositionOffset and Vector(las.PositionOffset.X, las.PositionOffset.Y) or nil
			dbg.laser_height = las.Height
			dbg.laser_angle = las.Angle
			dbg.laser_variant = las.Variant
			dbg.laser_subtype = las.SubType
			dbg.laser_timeout = las.Timeout
			if room then
				dbg.laser_screen = room:WorldToScreenPosition(las.Position)
				if las.PositionOffset then
					local po = las.PositionOffset
					local w_po = Vector(las.Position.X + po.X, las.Position.Y + po.Y)
					dbg.laser_screen_po = room:WorldToScreenPosition(w_po)
				end
			end
		end
	end
end

local function spawn_fx_techx_anchor(player, pos)
	if not pos then return nil end
	-- MeusNil 当圆心：不会被泪弹捕捉/20/20 分叉。跳过 Nil_holder 默认运动与距离清杀。
	local q = auxi.fire_nil(pos, Vector(0, 0), {cooldown = 999999, player = player})
	if not q then return nil end
	q:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
	q.Visible = false
	q.Velocity = Vector.Zero
	q.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	q.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	local d = q:GetData()
	d[item.own_key.."techx_anchor"] = true
	d.skip_nil_distance_cull = true
	d.nil_mode = "visual_only"
	d[Nil_holder.own_key.."work"] = function() return true end
	return q
end

local function spawn_fx_techx_ring(player, fx, pos)
	if not player or not fx or not pos then return end
	if not eye_synergies(player).techx then return end
	if auxi.check_all_exists(fx.techx_ring) then return end
	local origin = Vector(pos.X, pos.Y)
	local anchor = fx.techx_anchor
	if not auxi.check_all_exists(anchor) then
		anchor = spawn_fx_techx_anchor(player, origin)
		fx.techx_anchor = anchor
	end
	if not auxi.check_all_exists(anchor) then return end
	-- 与 Craft_Ludovico_holder.spawn_ring 同序：FireTechXLaser → Parent=锚点 → RING_LUDOVICO
	local ring = player:FireTechXLaser(anchor.Position, Vector.Zero, TECHX_START_R, player, 0.4)
	if not ring then
		release_techx_hover(fx)
		return
	end
	ring = ring:ToLaser() or ring
	ring:GetData()[LASER_TAG] = "techx"
	ring.Parent = anchor
	ring.SubType = TECHX_RING_SUB
	ring.Velocity = Vector.Zero
	if ring.DisableFollowParent ~= nil then ring.DisableFollowParent = false end
	if ring.SetDisableFollowParent then ring:SetDisableFollowParent(false) end
	if ring.SetTimeout then ring:SetTimeout(999999) end
	ring.Variant = TECH_LASER_VAR
	ring.SubType = TECHX_RING_SUB
	ring.Position = Vector(anchor.Position.X, anchor.Position.Y)
	if ring.ParentOffset ~= nil then ring.ParentOffset = Vector(0, TECHX_ANCHOR_H) end
	if ring.Shrink ~= nil then ring.Shrink = false end
	if ring.Radius ~= nil then ring.Radius = TECHX_START_R end
	if ring.CurveStrength ~= nil then ring.CurveStrength = 0 end
	if ring.HomingType ~= nil then ring.HomingType = 0 end
	fx.techx_ring = ring
	fx.techx_r0 = TECHX_START_R
	fx.techx_age = 0
	fx.techx_life = math.max(24, tonumber(fx.ascend_frames) or 48)
end

local function holy_radius_for(player)
	local r = HOLY_RADIUS
	if eye_synergies(player).pupula then
		r = r * 1.5
	end
	return r
end

--- 玩家准星（玄秘 / Marked 等）
local function find_aim_mark_pos(player)
	if not player then return nil end
	local ph = GetPtrHash(player)
	local vars = {}
	if EffectVariant.OCCULT_TARGET then vars[#vars + 1] = EffectVariant.OCCULT_TARGET end
	if EffectVariant.TARGET then vars[#vars + 1] = EffectVariant.TARGET end
	for vi = 1, #vars do
		for _, e in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, vars[vi], -1, false, false)) do
			if e and e:Exists() then
				local sp = e.SpawnerEntity or e.Parent
				if sp and GetPtrHash(sp) == ph then
					return Vector(e.Position.X, e.Position.Y)
				end
			end
		end
	end
	return nil
end

local function tear_has_flag(tear, flag)
	if not tear or not flag then return false end
	if tear.HasTearFlags then
		return tear:HasTearFlags(flag) == true
	end
	if tear.TearFlags then
		return tear.TearFlags & flag == flag
	end
	return false
end

--- 锁定一枚属于玩家的 Ludo 泪（TEAR_LUDOVICO）
local function find_ludo_tear_pos(player)
	if not player or not TearFlags or not TearFlags.TEAR_LUDOVICO then return nil end
	local ph = GetPtrHash(player)
	local locked = nil
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_TEAR, -1, -1, false, false)) do
		local tear = ent:ToTear()
		if tear and tear:Exists() and tear_has_flag(tear, TearFlags.TEAR_LUDOVICO) then
			local sp = tear.SpawnerEntity or tear.Parent
			if sp and GetPtrHash(sp) == ph then
				-- 只锁一枚：取 InitSeed 最小的，保证同帧稳定
				if not locked or (tear.InitSeed or 0) < (locked.InitSeed or 0) then
					locked = tear
				end
			end
		end
	end
	if locked then
		return Vector(locked.Position.X, locked.Position.Y)
	end
	return nil
end

--- 屏幕距离：近 +150%～远 -50%
local function proptosis_mul(player, moon_screen, world_pos)
	if not eye_synergies(player).proptosis then return 1 end
	local room = Game():GetRoom()
	if not room or not moon_screen or not world_pos then return 1 end
	local ts = room:WorldToScreenPosition(world_pos)
	local d = (ts - moon_screen):Length()
	local span = math.max(1, PROPTOSIS_FAR_PX - PROPTOSIS_NEAR_PX)
	local u = (d - PROPTOSIS_NEAR_PX) / span
	if u < 0 then u = 0 elseif u > 1 then u = 1 end
	return PROPTOSIS_NEAR_MUL * (1 - u) + PROPTOSIS_FAR_MUL * u
end

local function fx_screen_pos(room, anchor, lift)
	local world = Vector(anchor.X, anchor.Y - (lift or 0))
	if room then
		return room:WorldToScreenPosition(world)
	end
	return Vector(320, 200)
end

--- 优先可受伤、靠近 near_pos；排除 exclude_seed
local function pick_alt_targets(exclude_seed, near_pos, count)
	count = count or 2
	near_pos = near_pos or Vector(0, 0)
	local cands = list_lockable_enemies(exclude_seed)
	table.sort(cands, function(a, b)
		local da = a.Position:DistanceSquared(near_pos) + (is_prefer_hurt_target(a) and 0 or 80000)
		local db = b.Position:DistanceSquared(near_pos) + (is_prefer_hurt_target(b) and 0 or 80000)
		return da < db
	end)
	local out = {}
	for i = 1, math.min(count, #cands) do
		out[i] = cands[i]
	end
	return out
end

local function make_mini_moon_state(scale)
	local st = moon.create_state({
		cover_t = COVER_FULL_T,
		cover_b = COVER_FULL_B,
		alpha = 1,
		scale = scale or INNER_MOON_SCALE,
		two_lid = true,
		detailed_back = moon.debug.detailed_back ~= false,
		look_rate = 0.5,
		cover_rate = 0.4,
		rotate_with_look = false,
		clamp_to_lids = false,
		rot = 0,
	})
	moon.snap(st)
	st.alpha = 1
	st.target_alpha = 1
	st.target_rot = 0
	st.rot = 0
	return st
end

local function ensure_fx_eye_extras(fx, player)
	local syn = eye_synergies(player)
	if syn.inner and not fx.side_moons then
		fx.side_moons = {
			{side = -1, holder = {}, state = make_mini_moon_state(INNER_MOON_SCALE), look_seed = nil, lock_pos = nil},
			{side = 1, holder = {}, state = make_mini_moon_state(INNER_MOON_SCALE), look_seed = nil, lock_pos = nil},
		}
	end
	if syn.moms and not fx.moms_moon then
		fx.moms_moon = {
			holder = {},
			state = make_mini_moon_state(MOMS_EYE_SCALE),
		}
	end
	if syn.eyesore and fx.sore_moons == nil then
		local rng = player:GetCollectibleRNG(CollectibleType.COLLECTIBLE_EYE_SORE)
		local n = rng:RandomInt(3) -- 0..2
		fx.sore_moons = {}
		for i = 1, n do
			local ang = rng:RandomFloat() * math.pi * 2
			local dist = 48 + rng:RandomFloat() * 70
			fx.sore_moons[i] = {
				holder = {},
				state = make_mini_moon_state(EYESORE_MOON_SCALE),
				ox = math.cos(ang) * dist,
				oy = math.sin(ang) * dist * 0.72,
				look_seed = nil,
				lock_pos = nil,
			}
		end
	end
end

local function refresh_side_moon_targets(fx)
	if not fx or not fx.side_moons then return end
	local near = fx.lock_pos or fx.anchor_target or fx.anchor
	local alts = pick_alt_targets(fx.target_seed, near, #fx.side_moons)
	for i, sm in ipairs(fx.side_moons) do
		local ent = alts[i]
		if ent then
			sm.look_seed = ent.InitSeed
			sm.lock_pos = Vector(ent.Position.X, ent.Position.Y)
		else
			-- 没有其他目标则聚焦主目标落点
			sm.look_seed = fx.target_seed
			sm.lock_pos = fx.lock_pos and Vector(fx.lock_pos.X, fx.lock_pos.Y) or near
		end
	end
end

--- 眼瘤小月亮：随机锁定可打目标（可与主目标相同）
local function refresh_sore_moon_targets(fx, player)
	if not fx or not fx.sore_moons or #fx.sore_moons == 0 then return end
	local rng = player and player:GetCollectibleRNG(CollectibleType.COLLECTIBLE_EYE_SORE)
	local cands = list_lockable_enemies(nil)
	local near = fx.lock_pos or fx.anchor_target or fx.anchor
	for _, sm in ipairs(fx.sore_moons) do
		local ent = nil
		if #cands > 0 and rng then
			ent = cands[rng:RandomInt(#cands) + 1]
		elseif #cands > 0 then
			ent = cands[1]
		end
		if ent then
			sm.look_seed = ent.InitSeed
			sm.lock_pos = Vector(ent.Position.X, ent.Position.Y)
		else
			sm.look_seed = fx.target_seed
			sm.lock_pos = near and Vector(near.X, near.Y) or nil
		end
	end
end

local function mirror_through_player(player, pos)
	if not player or not pos then return pos end
	local p = player.Position
	return Vector(p.X * 2 - pos.X, p.Y * 2 - pos.Y)
end

local function apply_synergies(_player, _target, _ctx)
	-- 预留：遍历 YOKAI_EYE_SYNERGIES
end

local function spawn_light_pillar(player, pos, dmg, opts)
	opts = opts or {}
	local radius = tonumber(opts.radius) or HOLY_RADIUS
	local dmg_mul = tonumber(opts.dmg_mul) or 1
	local width_mul = tonumber(opts.width_mul) or 1
	dmg = (dmg or 0) * dmg_mul
	local beam = Isaac.Spawn(
		EntityType.ENTITY_EFFECT,
		EffectVariant.CRACK_THE_SKY,
		1,
		pos,
		Vector.Zero,
		player
	)
	if beam then
		beam.CollisionDamage = dmg or 0
		beam.Parent = player
		beam.SpawnerEntity = player
		local sx = tonumber(opts.scale_x) or 1
		sx = sx * width_mul
		if beam.SpriteScale then
			beam.SpriteScale = Vector(sx, beam.SpriteScale.Y)
		end
		if opts.colorize then
			-- 圣光柱需持久染色（勿用闪烁用的短 duration）
			apply_entity_colorize(beam, opts.colorize, opts.color_offset or OCCULT_OFFSET, -1)
		end
	end
	if opts.shockwave ~= false and Game().MakeShockwave then
		Game():MakeShockwave(pos, 0.035, 0.025, 10)
	end
	if (dmg or 0) > 0 then
		local r2 = radius * radius
		for _, ent in ipairs(Isaac.FindInRadius(pos, radius, EntityPartition.ENEMY)) do
			if is_gaze_lockable(ent) then
				ent:TakeDamage(dmg, 0, EntityRef(player), 0)
			end
		end
		for _, ent in ipairs(Isaac.GetRoomEntities()) do
			if is_training_dummy(ent) and is_gaze_lockable(ent)
				and ent.Position:DistanceSquared(pos) <= r2 then
				ent:TakeDamage(dmg, 0, EntityRef(player), 0)
			end
		end
		if opts.play_sound ~= false and g.sound then
			g.sound:Play(SoundEffect.SOUND_HOLY, 0.85, 0, false, 1.05)
		end
	end
	return beam
end

local function clear_fx_evil_eyes(fx)
	if not fx or not fx.evil_eyes then return end
	for _, row in ipairs(fx.evil_eyes) do
		local e = row and row.ent
		if e and e:Exists() then
			e:Remove()
		end
	end
	fx.evil_eyes = nil
end

local function evil_dir_suffix(dir)
	if not dir or dir:Length() < 0.01 then return "Down" end
	local ax, ay = math.abs(dir.X), math.abs(dir.Y)
	if ay >= ax then
		return (dir.Y < 0) and "Up" or "Down"
	end
	return "Side"
end

local function play_pareidolia_evil_anim(eye_or_spr, dir, shooting)
	local spr = eye_or_spr
	if eye_or_spr and eye_or_spr.GetSprite then
		spr = eye_or_spr:GetSprite()
	end
	if not spr then return end
	local need_load = true
	pcall(function()
		need_load = spr:GetFilename() ~= EVIL_EYE_ANM2
	end)
	if need_load then
		pcall(function()
			spr:Load(EVIL_EYE_ANM2, true)
		end)
	end
	local suffix = evil_dir_suffix(dir)
	local name = (shooting and "Shoot" or "Idle") .. suffix
	if suffix == "Side" then
		spr.FlipX = dir and dir.X < 0
	else
		spr.FlipX = false
	end
	if spr:GetAnimation() ~= name then
		spr:Play(name, true)
	end
end

local function ensure_fx_evil_eyes(fx, player)
	if not fx or not player or not eye_synergies(player).evil then return end
	if fx.evil_eyes then return end
	fx.evil_eyes = {}
	local frame = Game():GetFrameCount()
	for i = 1, EVIL_ORBIT_COUNT do
		local spawned = Isaac.Spawn(
			EntityType.ENTITY_EFFECT,
			EVIL_EYE_VARIANT,
			0,
			player.Position,
			Vector.Zero,
			player
		)
		if spawned then
			local eye = spawned:ToEffect() or spawned
			eye:GetData()[EVIL_DATA_KEY] = true
			eye.Parent = nil
			eye.SpawnerEntity = player
			eye.CollisionDamage = 0
			eye.Visible = false -- 自绘；实体只负责射击落点
			if eye.Timeout ~= nil then eye.Timeout = -1 end
			if eye.SetDisableFollowParent then
				pcall(function() eye:SetDisableFollowParent(true) end)
			end
			fx.evil_eyes[#fx.evil_eyes + 1] = {
				ent = eye,
				phase = (i - 1) * (math.pi * 2 / EVIL_ORBIT_COUNT),
				next_shot = frame + EVIL_FIRST_SHOT + i * 2,
				shoot_until = 0,
				ang = 0,
				aim = Vector(0, 1),
				shooting = false,
			}
		end
	end
end

local function tick_fx_evil_eyes(player, fx)
	if not fx or not fx.evil_eyes then return end
	local frame = Game():GetFrameCount()
	-- 与月亮同一套「升空」世界锚点（W2S(anchor.Y - lift)）
	local center = Vector(fx.anchor.X, fx.anchor.Y - (fx.lift or 0))
	local target = find_enemy_by_seed(fx.target_seed)
	local aim_pos = (target and target.Position)
		or fx.lock_pos
		or fx.anchor_target
		or center
	local spin = frame * 0.045
	for _, row in ipairs(fx.evil_eyes) do
		local eye = row.ent
		if not eye or not eye:Exists() then
			row.dead = true
		else
			local ang = spin + (row.phase or 0)
			row.ang = ang
			local pos = center + Vector(math.cos(ang) * EVIL_ORBIT_WORLD, math.sin(ang) * EVIL_ORBIT_WORLD * 0.72)
			eye.Position = pos
			eye.Velocity = Vector.Zero
			eye.PositionOffset = Vector.Zero
			eye.Visible = false
			local aim = (aim_pos - pos)
			if aim:Length() < 0.05 then aim = Vector(0, 1) else aim = aim:Normalized() end
			row.aim = aim
			row.shooting = frame < (row.shoot_until or 0)
			if frame >= (row.next_shot or 0) then
				local speed = (player.ShotSpeed or 1) * 10
				local tear = player:FireTear(pos, aim * speed, false, true, false)
				if tear then
					tear = tear:ToTear() or tear
					tear.SpawnerEntity = player
					local lift = fx.lift or 0
					if tear.Height ~= nil then
						tear.Height = math.min(tear.Height or -20, -12 - lift * 0.12)
					end
				end
				row.next_shot = frame + EVIL_SHOT_INTERVAL
				row.shoot_until = frame + 6
				row.shooting = true
			end
		end
	end
	local alive = {}
	for _, row in ipairs(fx.evil_eyes) do
		if not row.dead and row.ent and row.ent:Exists() then
			alive[#alive + 1] = row
		end
	end
	fx.evil_eyes = (#alive > 0) and alive or nil
end

local function ensure_evil_draw_sprites(rec)
	if not rec._evil_spr then
		local spr = Sprite()
		spr:Load(EVIL_EYE_ANM2, true)
		spr:Play("IdleDown", true)
		rec._evil_spr = spr
	end
	if not rec._evil_glow then
		local glow = Sprite()
		glow:Load(moon.ANM2, true)
		glow:Play(moon.ANIM, true)
		if glow.SetFrame then pcall(function() glow:SetFrame(moon.ANIM, 0) end) end
		rec._evil_glow = glow
	end
	return rec._evil_spr, rec._evil_glow
end

--- 在月亮屏幕坐标外环绕自绘（带白光 + anm2 枢轴补偿），画在月亮之后
render_evil_eyes_at_moon = function(rec, moon_screen, evil_rows, moon_scale)
	if not moon_screen or not evil_rows or #evil_rows == 0 then return end
	local spr, glow = ensure_evil_draw_sprites(rec)
	if not spr then return end
	local sc = tonumber(moon_scale) or 1
	local orbit = EVIL_ORBIT_SCREEN * math.max(0.55, sc)
	for i = 1, #evil_rows do
		local row = evil_rows[i]
		if row then
			local ang = tonumber(row.ang) or 0
			-- 环绕锚点（Halo 中心枢轴，不加邪眼 anm2 补偿）
			local orbit_pos = moon_screen
				+ Vector(math.cos(ang) * orbit, math.sin(ang) * orbit * 0.72)
			-- 邪眼贴图可视中心偏上，单独下移补偿
			local eye_pos = orbit_pos + EVIL_PIVOT_COMP
			-- 平时原色；闪烁帧才红/紫（邪眼：红→紫连续）
			local flash_cz, flash_off = flash_tint_for({evil = true})
			local flash_col = flash_cz and make_occult_color(1, flash_cz, flash_off)
				or Color(1, 1, 1, 1, 0, 0, 0)
			-- 白光（月亮 Halo 层）衬在邪眼背后：对齐环绕锚点，勿套 EVIL_PIVOT_COMP
			if glow and glow.RenderLayer and moon.LAYER and moon.LAYER.HALO then
				local bak_g = glow.Scale
				local bak_c = glow.Color
				glow.Scale = Vector(EVIL_GLOW_SCALE, EVIL_GLOW_SCALE)
				glow.Color = Color(1, 1, 1, EVIL_GLOW_ALPHA, 0.2, 0.2, 0.2)
				pcall(function()
					glow:RenderLayer(moon.LAYER.HALO, orbit_pos, Vector.Zero, Vector.Zero)
				end)
				glow.Scale = bak_g
				glow.Color = bak_c
			end
			local aim = row.aim or Vector(0, 1)
			play_pareidolia_evil_anim(spr, aim, row.shooting)
			local bak_s = spr.Scale
			spr.Scale = Vector(1, 1)
			spr.Color = flash_col
			spr:Render(eye_pos, Vector.Zero, Vector.Zero)
			spr.Scale = bak_s
		end
	end
end

local function enqueue_followup(fx, entry)
	if not fx or not entry then return end
	fx.followups = fx.followups or {}
	fx.followups[#fx.followups + 1] = entry
end

local function tick_followup_strike(player, rec)
	local list = rec.fx and rec.fx.followups
	if not list then return end
	-- 兼容旧字段
	if rec.fx.followup then
		list[#list + 1] = rec.fx.followup
		rec.fx.followup = nil
	end
	local fx = rec.fx
	local room = Game():GetRoom()
	local moon_screen = nil
	if fx and fx.anchor then
		moon_screen = fx_screen_pos(room, fx.anchor, fx.lift or 0)
	end
	local i = 1
	while i <= #list do
		local fu = list[i]
		fu.t = (fu.t or 0) - 1
		if fu.t <= 0 then
			local mul = 1
			if moon_screen and fu.pos then
				mul = proptosis_mul(player, moon_screen, fu.pos)
			end
			spawn_light_pillar(player, fu.pos, fu.dmg, {
				radius = fu.radius,
				shockwave = false,
				play_sound = fu.play_sound ~= false,
				scale_x = fu.scale_x,
				dmg_mul = mul,
				width_mul = mul,
				colorize = fu.colorize,
			})
			table.remove(list, i)
		else
			i = i + 1
		end
	end
	if #list == 0 then rec.fx.followups = nil end
end

local function begin_fx(player, target, lock_pos)
	local rec = pdata(player)
	local cfg = fx_tuning()
	-- 击杀瞬间实体可能已死：仍用落点/锁定坐标，禁止改选最近敌人
	local pos = lock_pos
		or (target and target.Position)
		or rec.look_target
		or rec.indicator_pos
		or player.Position
	pos = Vector(pos.X, pos.Y)
	local seed = (target and target.InitSeed) or rec.gaze_seed or nil
	local start_xy = rec.indicator_pos and Vector(rec.indicator_pos.X, rec.indicator_pos.Y) or Vector(pos.X, pos.Y)
	local start_lift = rec.vis_lift or phase_lift_for(1, cfg)
	local start_scale = rec.vis_scale or PHASE_SCALE_MAX
	local start_t = rec.vis_cover_t or COVER_FULL_T
	local start_b = rec.vis_cover_b or COVER_FULL_B

	rec.counting = false
	rec.observe = nil
	rec.pursue = nil
	rec.fast_hide = false
	rec.hiding = false

	-- 复用进度月 sprite/state，避免换 holder 闪一下；alpha 保持 1（ascend 不再淡入）
	local holder = rec._phase_holder or {}
	rec._phase_holder = holder
	local st = rec._phase_state
	if not st then
		st = moon.create_state({
			cover_t = start_t,
			cover_b = start_b,
			alpha = 1,
			scale = start_scale,
			two_lid = true,
			detailed_back = moon.debug.detailed_back ~= false,
			look_rate = 0.42,
			cover_rate = 0.32,
			rotate_with_look = false,
			clamp_to_lids = false,
			rot = 0,
		})
		rec._phase_state = st
	else
		moon.set_covers(st, {t = start_t, b = start_b})
		moon.set_alpha(st, 1)
		st.scale = start_scale
		st.detailed_back = moon.debug.detailed_back ~= false
		st.rotate_with_look = false
		st.clamp_to_lids = false
		st.look_rate = 0.42
		st.target_rot = 0
		st.rot = 0
	end
	moon.snap(st)
	st.alpha = 1
	st.target_alpha = 1
	st.target_rot = 0
	st.rot = 0

	local room = Game():GetRoom()
	local top_lift = compute_top_lift(start_xy, cfg)
	local center = room and room:GetCenterPos() or Vector(start_xy.X, start_xy.Y)
	-- 往屏幕中央偏一点上方，不要死贴敌人头顶
	local fly_to = Vector(center.X, center.Y - 20)
	local ascend_need = math.max(1, cfg.ascend)
	rec.fx = {
		stage = "charge",
		t = 0,
		state = st,
		holder = holder,
		target_seed = seed,
		lock_pos = Vector(pos.X, pos.Y),
		anchor_target = Vector(pos.X, pos.Y),
		anchor = start_xy,
		anchor_start = Vector(start_xy.X, start_xy.Y),
		fly_to = fly_to,
		lift = start_lift,
		lift_from = start_lift,
		top_lift = top_lift,
		scale_from = start_scale,
		ascend_frames = ascend_need,
		ray_width = FX_RAY_WIDTH_START,
		ray_alpha = 0.2,
		white_u = 0,
		dealt = false,
		charged = false,
	}
	-- 进度月藏起；月相清零留到 end_fx，期间 counting=false 禁止攒相
	rec.vis_alpha = 0
	spawn_fx_techx_ring(player, rec.fx, rec.fx.lock_pos)
end

local function fx_total(stage, cfg, fx)
	if stage == "charge" then
		if fx and fx.ascend_frames then
			return math.max(1, fx.ascend_frames)
		end
		return math.max(1, cfg and cfg.ascend or FX.charge)
	end
	return (FX[stage] or 1)
end

local function tick_fx(player, rec)
	local fx = rec.fx
	if not fx then return end
	fx.t = fx.t + 1
	tick_followup_strike(player, rec)
	local st = fx.state
	local cfg = fx_tuning()
	local pupils = build_extra_pupils(player)
	local syn = eye_synergies(player)
	ensure_fx_eye_extras(fx, player)
	ensure_fx_evil_eyes(fx, player)
	tick_fx_evil_eyes(player, fx)

	-- 全程盯锁定落点；目标死亡/消失也不改选最近敌人
	local target = find_enemy_by_seed(fx.target_seed)
	if target then
		fx.anchor_target = Vector(target.Position.X, target.Position.Y)
	elseif fx.lock_pos then
		fx.anchor_target = Vector(fx.lock_pos.X, fx.lock_pos.Y)
	end

	if fx.side_moons then
		if not fx.side_targets_locked then
			refresh_side_moon_targets(fx)
			fx.side_targets_locked = true
		end
		for _, sm in ipairs(fx.side_moons) do
			local ent = find_enemy_by_seed(sm.look_seed)
			if ent then
				sm.lock_pos = Vector(ent.Position.X, ent.Position.Y)
			elseif not sm.lock_pos and fx.lock_pos then
				sm.lock_pos = Vector(fx.lock_pos.X, fx.lock_pos.Y)
			end
		end
	end

	if fx.sore_moons and #fx.sore_moons > 0 then
		if not fx.sore_targets_locked then
			refresh_sore_moon_targets(fx, player)
			fx.sore_targets_locked = true
		end
		for _, sm in ipairs(fx.sore_moons) do
			local ent = find_enemy_by_seed(sm.look_seed)
			if ent then
				sm.lock_pos = Vector(ent.Position.X, ent.Position.Y)
			elseif not sm.lock_pos and fx.lock_pos then
				sm.lock_pos = Vector(fx.lock_pos.X, fx.lock_pos.Y)
			end
		end
	end

	local room = Game():GetRoom()
	if room and not fx.fly_to then
		local c = room:GetCenterPos()
		fx.fly_to = Vector(c.X, c.Y - 20)
	end

	local function set_stage(name)
		fx.stage = name
		fx.t = 0
		if name == "charge" then
			fx.lift_from = fx.lift or cfg.lift_start
		end
	end

	local hit_pos = fx.lock_pos or fx.anchor_target or fx.anchor
	if target then
		-- 仍存活则落点跟实体；已死则用 lock_pos
		hit_pos = target.Position
		fx.lock_pos = Vector(hit_pos.X, hit_pos.Y)
	end

	moon.set_covers(st, {t = COVER_FULL_T, b = COVER_FULL_B})
	moon.set_alpha(st, 1)
	st.look_rate = 0.45
	st.rotate_with_look = false
	st.target_rot = 0
	st.detailed_back = moon.debug.detailed_back ~= false

	if fx.stage == "charge" then
		local total = fx_total("charge", cfg, fx)
		local u = math.min(1, fx.t / total)
		local ease = ease_smooth(u)
		local fly = fx.fly_to or fx.anchor
		local from_xy = fx.anchor_start or fx.anchor
		fx.anchor = lerp_vec(from_xy, fly, ease)
		local from = fx.lift_from or cfg.lift_start
		local top = fx.top_lift or cfg.lift_hover
		fx.lift = from + (top - from) * ease
		st.scale = perspective_scale(fx.scale_from or PHASE_SCALE_MAX, ease) * alpha_scale_mul(1)
		fx.ray_width = FX_RAY_WIDTH_START + (FX_RAY_WIDTH_END - FX_RAY_WIDTH_START) * u
		fx.ray_alpha = 0.22 + 0.78 * u
		fx.white_u = ease
		if target then
			apply_mark_white(target, fx.white_u)
		end
		if not fx.charged and u >= 0.15 and g.sound then
			fx.charged = true
			g.sound:Play(SoundEffect.SOUND_LIGHTBOLT_CHARGE, 0.65, 0, false, 0.95)
		end
		if u >= 1 then set_stage("strike") end
	elseif fx.stage == "strike" then
		local u = math.min(1, fx.t / fx_total("strike", cfg, fx))
		if fx.fly_to then fx.anchor = Vector(fx.fly_to.X, fx.fly_to.Y) end
		fx.lift = fx.top_lift or cfg.lift_hover
		st.scale = perspective_scale(fx.scale_from or PHASE_SCALE_MAX, 1) * alpha_scale_mul(1)
		fx.ray_width = FX_RAY_WIDTH_END
		fx.ray_alpha = 1
		fx.white_u = 1
		if target then apply_mark_white(target, 1) end
		if not fx.dealt then
			fx.dealt = true
			local dmg = resonance_damage(player)
			local strike_pos = fx.lock_pos or hit_pos
			local radius = holy_radius_for(player)
			local moon_screen = fx_screen_pos(room, fx.anchor or strike_pos, fx.lift or 0)
			local occult_cz = syn.occult and OCCULT_CZ or nil
			local function pillar_opts(pos, extra)
				extra = extra or {}
				local mul = proptosis_mul(player, moon_screen, pos)
				return {
					radius = extra.radius or radius,
					shockwave = extra.shockwave,
					play_sound = extra.play_sound,
					scale_x = extra.scale_x,
					dmg_mul = mul,
					width_mul = mul,
					colorize = occult_cz,
				}
			end
			spawn_light_pillar(player, strike_pos, dmg, pillar_opts(strike_pos, {radius = radius}))
			apply_synergies(player, target, {damage = dmg, pos = strike_pos, radius = radius})
			if target then note_mark_hurt(target, dmg) end
			-- 玄秘魔眼：准星位置额外光柱
			if syn.occult then
				local mark = find_aim_mark_pos(player)
				if mark then
					enqueue_followup(fx, {
						t = 3,
						pos = Vector(mark.X, mark.Y),
						dmg = dmg,
						radius = radius,
						play_sound = true,
						colorize = occult_cz,
					})
				end
			end
			-- 路德维希科技：锁定一枚 Ludo 泪，对其位置降圣光
			if syn.ludo then
				local ludo_pos = find_ludo_tear_pos(player)
				if ludo_pos then
					enqueue_followup(fx, {
						t = 3,
						pos = Vector(ludo_pos.X, ludo_pos.Y),
						dmg = dmg,
						radius = radius,
						play_sound = true,
						colorize = occult_cz,
					})
				end
			end
			-- 20/20：短延迟后再打一段 50% 伤害
			if syn.twenty then
				enqueue_followup(fx, {
					t = FOLLOWUP_DELAY,
					pos = Vector(strike_pos.X, strike_pos.Y),
					dmg = dmg * 0.5,
					radius = radius,
					play_sound = true,
					colorize = occult_cz,
				})
			end
			-- 内眼：左右小月亮各打 60%（优先别的目标）
			if fx.side_moons then
				for i, sm in ipairs(fx.side_moons) do
					local pos = sm.lock_pos or strike_pos
					local ent = find_enemy_by_seed(sm.look_seed)
					if ent then pos = ent.Position end
					enqueue_followup(fx, {
						t = 2 + i * 2,
						pos = Vector(pos.X, pos.Y),
						dmg = dmg * INNER_STRIKE_MUL,
						radius = radius,
						play_sound = false,
						colorize = occult_cz,
					})
				end
			end
			-- 妈妈的眼睛：主落点相对玩家的对称位置
			if syn.moms then
				local mir = mirror_through_player(player, strike_pos)
				fx.moms_mirror = Vector(mir.X, mir.Y)
				enqueue_followup(fx, {
					t = 4,
					pos = Vector(mir.X, mir.Y),
					dmg = dmg * MOMS_STRIKE_MUL,
					radius = radius,
					play_sound = false,
					colorize = occult_cz,
				})
			end
			-- 眼瘤：各小月亮随机落点圣光
			if fx.sore_moons then
				for i, sm in ipairs(fx.sore_moons) do
					local pos = sm.lock_pos or strike_pos
					local ent = find_enemy_by_seed(sm.look_seed)
					if ent then pos = ent.Position end
					enqueue_followup(fx, {
						t = 3 + i * 2,
						pos = Vector(pos.X, pos.Y),
						dmg = dmg * EYESORE_STRIKE_MUL,
						radius = radius * 0.85,
						play_sound = false,
						colorize = occult_cz,
					})
				end
			end
			-- 巨人独眼：主圣光后，圆周散布更多细圣光，错开数帧落下
			if syn.poly then
				local rng = player:GetCollectibleRNG(CollectibleType.COLLECTIBLE_POLYPHEMUS)
				local n = POLY_RING_COUNT_MIN + rng:RandomInt(POLY_RING_COUNT_MAX - POLY_RING_COUNT_MIN + 1)
				local ring_r = POLY_RING_RADIUS
				local thin_r = radius * POLY_RING_RADIUS_MUL
				local thin_dmg = dmg * POLY_RING_DMG_MUL
				local span = math.max(1, POLY_RING_SPAN)
				for i = 1, n do
					local ang = rng:RandomFloat() * math.pi * 2
					local dist = ring_r * (0.55 + rng:RandomFloat() * 0.45)
					local off = Vector(math.cos(ang) * dist, math.sin(ang) * dist)
					local slot = (n <= 1) and 0 or math.floor((i - 1) * span / (n - 1) + 0.5)
					local jitter = rng:RandomInt(2)
					local pos = Vector(strike_pos.X + off.X, strike_pos.Y + off.Y)
					enqueue_followup(fx, {
						t = POLY_RING_DELAY + slot + jitter,
						pos = pos,
						dmg = thin_dmg,
						radius = thin_r,
						scale_x = POLY_BEAM_SCALE_X,
						play_sound = (i == 1),
						colorize = occult_cz,
					})
				end
			end
		end
		if u >= 1 then set_stage("fade") end
	elseif fx.stage == "fade" then
		local u = math.min(1, fx.t / fx_total("fade", cfg, fx))
		local ease = ease_smooth(u)
		local fade_a = 1 - ease
		-- 缓缓再升起并变淡消失；透明度额外缩小
		moon.set_alpha(st, fade_a)
		fx.lift = (fx.top_lift or cfg.lift_hover) + 55 * ease
		st.scale = perspective_scale(fx.scale_from or PHASE_SCALE_MAX, 1) * alpha_scale_mul(fade_a)
		fx.ray_width = FX_RAY_WIDTH_END * (1 - ease)
		fx.ray_alpha = 1 - ease
		fx.white_u = 1 - ease
		if target then
			if fx.white_u > 0.02 then
				apply_mark_white(target, fx.white_u)
			else
				clear_mark_white(target)
			end
		end
		if u >= 1 then
			end_fx(rec)
			return
		end
	end

	local look_world = fx.anchor_target or fx.lock_pos or fx.anchor
	if look_world and room then
		local approx = fx_screen_pos(room, fx.anchor, fx.lift)
		moon.set_look_at(st, approx, room:WorldToScreenPosition(look_world))
	end

	-- 科技视线激光：命中世界坐标即可；渲染高度用 PositionOffset 补偿
	tick_fx_tech_lasers(player, fx, syn, hit_pos)

	local side_draw = nil
	if fx.side_moons then
		side_draw = {}
		for i, sm in ipairs(fx.side_moons) do
			side_draw[i] = {
				side = sm.side,
				holder = sm.holder,
				state = sm.state,
				look_world = sm.lock_pos or look_world,
			}
			moon.set_covers(sm.state, {t = COVER_FULL_T, b = COVER_FULL_B})
			moon.set_alpha(sm.state, st.alpha or 1)
		end
	end
	local moms_draw = nil
	if fx.moms_moon then
		local mir = fx.moms_mirror or (fx.lock_pos and mirror_through_player(player, fx.lock_pos)) or look_world
		moms_draw = {
			holder = fx.moms_moon.holder,
			state = fx.moms_moon.state,
			look_world = mir,
		}
		moon.set_covers(fx.moms_moon.state, {t = COVER_FULL_T, b = COVER_FULL_B})
		moon.set_alpha(fx.moms_moon.state, st.alpha or 1)
	end

	local sore_draw = nil
	if fx.sore_moons and #fx.sore_moons > 0 then
		sore_draw = {}
		for i, sm in ipairs(fx.sore_moons) do
			sore_draw[i] = {
				ox = sm.ox,
				oy = sm.oy,
				holder = sm.holder,
				state = sm.state,
				look_world = sm.lock_pos or look_world,
			}
			moon.set_covers(sm.state, {t = COVER_FULL_T, b = COVER_FULL_B})
			moon.set_alpha(sm.state, st.alpha or 1)
		end
	end

	local pcz, poff = pupil_style_for(player)
	local flash_pulse = flash_pulse_for(eye_synergies(player))
	queue_moon_draw(rec, fx.holder, st, fx.target_seed, fx.anchor, fx.lift, look_world, {
		-- 视线始终用圣光 Beam；科技激光另算，不替代视线
		ray_width = fx.ray_width,
		ray_alpha = fx.ray_alpha,
		hit_world = fx.lock_pos or hit_pos,
		extra_pupils = pupils,
		primary_pupil_scale = primary_pupil_scale_for(player),
		pupil_cz = pcz,
		pupil_offset = poff,
		pupil_flash = flash_pulse,
		ray_colorize = pcz,
		ray_color_offset = poff,
		side_moons = side_draw,
		moms_moon = moms_draw,
		sore_moons = sore_draw,
		evil_eyes = fx.evil_eyes,
	})
end

--- 进度月：更新显隐；高度/大小随进度；预测追随平滑移动
local function tick_phase_indicator(player, rec)
	if rec.fx then
		rec.vis_alpha = 0
		return
	end
	local cfg = fx_tuning()
	local phase = rec.phase or 0

	local function follow_ent(ent, switch)
		if not ent then return end
		rec.indicator_seed = ent.InitSeed
		rec.look_target = Vector(ent.Position.X, ent.Position.Y)
		if not rec.indicator_pos then
			rec.indicator_pos = Vector(ent.Position.X, ent.Position.Y)
			rec.indicator_vel = Vector(ent.Velocity.X, ent.Velocity.Y)
		end
		if switch and not rec.warp then
			begin_travel(rec, ent.Position, cfg, {switch = true})
		end
		tick_pursue(rec, ent.Position, ent.Velocity, cfg)
	end

	-- 观察态：目标消失后就近（优先可受伤）看别的敌人，等玩家出手
	if rec.observe then
		local obs = rec.observe
		obs.timeout = (obs.timeout or 0) - 1
		local obs_ent = find_enemy_by_seed(obs.seed)
		if not obs_ent then
			local near = rec.look_target or rec.indicator_pos or (player and player.Position)
			local nxt = pick_observe_enemy(player, obs.seed, near)
			if nxt then
				obs.seed = nxt.InitSeed
				obs_ent = nxt
				follow_ent(nxt, true)
			end
		elseif obs_ent then
			follow_ent(obs_ent, false)
		end
		if (obs.timeout or 0) <= 0 or (not obs_ent and #list_lockable_enemies(nil) <= 0) then
			rec.observe = nil
			rec.warp = nil
			rec.fast_hide = true
			rec.gaze_timeout = 0
			rec.gaze_seed = nil
		end
	elseif rec.gaze_seed then
		local gaze_ent = find_enemy_by_seed(rec.gaze_seed)
		if not gaze_ent then
			local last_pos = rec.look_target or rec.indicator_pos
			local other = pick_observe_enemy(player, rec.gaze_seed, last_pos)
			rec.gaze_seed = nil
			rec.gaze_timeout = 0
			if other then
				rec.observe = {
					seed = other.InitSeed,
					timeout = OBSERVE_TIMEOUT,
				}
				rec.fast_hide = false
				if last_pos and not rec.indicator_pos then
					rec.indicator_pos = Vector(last_pos.X, last_pos.Y)
					rec.indicator_vel = Vector(0, 0)
				end
				follow_ent(other, true)
			else
				rec.warp = nil
				rec.fast_hide = true
				rec.indicator_seed = nil
			end
		else
			rec.observe = nil
			follow_ent(gaze_ent, false)
		end
	elseif rec.indicator_vel and rec.indicator_pos and not rec.warp then
		local v = rec.indicator_vel
		rec.indicator_vel = Vector(v.X * 0.86, v.Y * 0.86)
		rec.indicator_pos = Vector(
			rec.indicator_pos.X + rec.indicator_vel.X,
			rec.indicator_pos.Y + rec.indicator_vel.Y
		)
	end

	if rec.warp then
		tick_warp(rec)
	end

	local observing = rec.observe ~= nil
	local active = observing or ((rec.gaze_timeout or 0) > 0 and (phase > 0.001 or (rec.vis_alpha or 0) > 0.05))
	local fade_out = (rec.fast_hide and VIS_FADE_OUT_FAST) or VIS_FADE_OUT
	-- 瞬移 warp 自管 alpha；普通显隐才走这里
	if not rec.warp then
		if active then
			rec.hiding = false
			local a = rec.vis_alpha or 0
			if a < VIS_ALPHA_START * 0.5 then
				a = VIS_ALPHA_START
			end
			rec.vis_alpha = math.min(VIS_ALPHA_PEAK, a + (VIS_ALPHA_PEAK - VIS_ALPHA_START) / VIS_FADE_IN)
			rec.fast_hide = false
		else
			if not rec.hiding then
				rec.hiding = true
				local a = rec.vis_alpha or 0
				if a > VIS_ALPHA_START then
					rec.vis_alpha = VIS_ALPHA_START
				end
			end
			rec.vis_alpha = math.max(0, (rec.vis_alpha or 0) - VIS_ALPHA_START / fade_out)
			if (rec.vis_alpha or 0) <= 0.01 then
				rec.indicator_seed = nil
				rec.indicator_pos = nil
				rec.indicator_vel = nil
				rec.look_target = nil
				rec.pursue = nil
				rec.warp = nil
				rec.fast_hide = false
				rec.hiding = false
			end
		end
	end

	-- 眨眼：仅在稳定现身且未满月演出时
	if active and (rec.vis_alpha or 0) > 0.75 then
		if (rec.blink_t or 0) > 0 then
			rec.blink_t = rec.blink_t - 1
		else
			rec.blink_cd = (rec.blink_cd or BLINK_PERIOD) - 1
			if rec.blink_cd <= 0 then
				rec.blink_cd = BLINK_PERIOD
				rec.blink_t = BLINK_LEN
			end
		end
	else
		rec.blink_t = 0
	end

	local want_t, want_b = phase_covers(phase, rec.blink_t)
	local want_scale = phase_scale(phase)
	local want_lift = phase_lift_for(phase, cfg)
	if rec.vis_cover_t == nil then rec.vis_cover_t = COVER_DEFAULT_T end
	if rec.vis_cover_b == nil then rec.vis_cover_b = COVER_DEFAULT_B end
	if rec.vis_scale == nil then rec.vis_scale = want_scale end
	if rec.vis_lift == nil then rec.vis_lift = want_lift end
	rec.vis_cover_t = lerp(rec.vis_cover_t, want_t, VIS_COVER_RATE)
	rec.vis_cover_b = lerp(rec.vis_cover_b, want_b, VIS_COVER_RATE)
	rec.vis_scale = lerp(rec.vis_scale, want_scale, VIS_SCALE_RATE)
	rec.vis_lift = lerp(rec.vis_lift, want_lift, VIS_LIFT_RATE)
end

local function draw_phase_indicator(player, rec)
	if rec.fx then return end
	local a = rec.vis_alpha or 0
	if a <= 0.01 then
		rec._draw = nil
		return
	end
	local pos = rec.indicator_pos
	if not pos then
		rec._draw = nil
		return
	end
	local room = Game():GetRoom()
	if not room then return end

	local holder = rec._phase_holder or {}
	rec._phase_holder = holder
	local st = rec._phase_state
	if not st then
		st = moon.create_state({
			cover_t = COVER_DEFAULT_T,
			cover_b = COVER_DEFAULT_B,
			alpha = 0,
			scale = rec.vis_scale or PHASE_SCALE_MIN,
			two_lid = true,
			look_rate = 0.42,
			cover_rate = 0.35,
			alpha_rate = 0.45,
			rotate_with_look = false,
			clamp_to_lids = false,
			rot = 0,
		})
		moon.snap(st)
		rec._phase_state = st
	end

	moon.set_covers(st, {
		t = rec.vis_cover_t or COVER_DEFAULT_T,
		b = rec.vis_cover_b or COVER_DEFAULT_B,
	})
	moon.set_alpha(st, a)
	st.scale = (rec.vis_scale or PHASE_SCALE_MIN) * alpha_scale_mul(a)
	st.alpha_rate = 0.45
	st.look_rate = 0.42
	st.detailed_back = moon.debug.detailed_back ~= false
	st.rotate_with_look = false
	st.clamp_to_lids = false
	st.target_rot = 0

	local lift = rec.vis_lift or PHASE_LIFT_DEFAULT
	local look_world = rec.look_target or pos
	local pcz, poff = pupil_style_for(player)
	queue_moon_draw(rec, holder, st, rec.gaze_seed or (rec.observe and rec.observe.seed) or rec.indicator_seed, pos, lift, look_world, {
		vel = rec.indicator_vel,
		extra_pupils = build_extra_pupils(player),
		primary_pupil_scale = primary_pupil_scale_for(player),
		pupil_cz = pcz,
		pupil_offset = poff,
		pupil_flash = flash_pulse_for(eye_synergies(player)),
		ray_colorize = pcz,
		ray_color_offset = poff,
	})
end

--- 外部/ImGui：强制对最近敌人打一发满月
function item.debug_force_resonance(player)
	player = player or g.game:GetPlayer(0)
	if not player then return false end
	local tg = nearest_enemy(player.Position, 400)
	begin_fx(player, tg)
	return true
end

function item.get_phase(player)
	return pdata(player).phase or 0
end

-- —— 伤害 → 注视 / 月相 ——
-- 必须 pre_ToCall：Potato for Scale 会在 TAKE_DMG 里 return false，拦住后续回调。
local function on_gaze_damage(_, ent, amount, _flags, source, _countdown)
	if not ent or not is_gaze_lockable(ent) then return end
	if amount <= 0 then return end
	local player, mul = source_player(source)
	if not player or not auxi.has_have_coll(player, item.entity) then return end
	local rec = pdata(player)
	if rec.fx or rec.counting == false then
		-- 演出中 / 动画未结束：不攒相；仅给当前锁定目标盖受伤红
		if rec.fx and rec.fx.target_seed and ent.InitSeed == rec.fx.target_seed then
			note_mark_hurt(ent, amount)
		end
		return
	end

	local seed = ent.InitSeed
	local cfg = fx_tuning()
	local switched = rec.gaze_seed ~= nil and rec.gaze_seed ~= seed
	rec.gaze_seed = seed
	rec.observe = nil
	rec.fast_hide = false
	rec.hiding = false
	rec.indicator_seed = seed
	rec.look_target = Vector(ent.Position.X, ent.Position.Y)
	if not rec.indicator_pos then
		rec.indicator_pos = Vector(ent.Position.X, ent.Position.Y)
		rec.indicator_vel = Vector(ent.Velocity.X, ent.Velocity.Y)
	elseif switched then
		begin_travel(rec, ent.Position, cfg, {switch = true})
	end
	rec.gaze_timeout = GAZE_TIMEOUT
	local need = math.max(1, player.Damage * PHASE_NEED_MUL)
	rec.phase = math.min(1, (rec.phase or 0) + (amount * (mul or 1)) / need)
	if rec.phase >= 1 then
		-- 即使用致死伤填满，也锁定该落点，禁止改选最近敌人
		local lock = Vector(ent.Position.X, ent.Position.Y)
		begin_fx(player, ent, lock)
	end
end

table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_EFFECT_UPDATE,
	params = EVIL_EYE_VARIANT,
	Function = function(_, effect)
		if effect and effect:GetData()[EVIL_DATA_KEY] then
			return true
		end
	end,
})

table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
	CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG,
	params = nil,
	priority = -20,
	Function = on_gaze_damage,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PEFFECT_UPDATE,
	params = nil,
	Function = function(_, player)
		if not auxi.has_have_coll(player, item.entity) then return end
		local rec = pdata(player)
		if rec.gaze_timeout and rec.gaze_timeout > 0 then
			rec.gaze_timeout = rec.gaze_timeout - 1
			if rec.gaze_timeout <= 0 and not rec.observe then
				rec.gaze_seed = nil
				rec.fast_hide = true
			end
		end
		if rec.fx then
			tick_fx(player, rec)
		else
			tick_phase_indicator(player, rec)
			draw_phase_indicator(player, rec)
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		for i = 0, g.game:GetNumPlayers() - 1 do
			local p = g.game:GetPlayer(i)
			if p then
				local rec = pdata(p)
				end_fx(rec)
				-- 换房默认隐藏；月相保留，下次攻击再现身
				hide_indicator(rec, {instant = true, clear_pos = true, fast = true})
				rec.counting = true
			end
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_RENDER,
	params = nil,
	Function = function(_, _)
		sync_moon_debug_from_options()
		if is_water_reflect() then return end
		for i = 0, g.game:GetNumPlayers() - 1 do
			local p = g.game:GetPlayer(i)
			if p and auxi.has_have_coll(p, item.entity) then
				render_queued_moon(pdata(p))
			end
		end
		if moon.debug.enabled then
			local any = false
			for i = 0, g.game:GetNumPlayers() - 1 do
				local p = g.game:GetPlayer(i)
				if p and auxi.has_have_coll(p, item.entity) then any = true break end
			end
			if any then moon.debug_tick_and_render() end
		end
	end,
})

return item
