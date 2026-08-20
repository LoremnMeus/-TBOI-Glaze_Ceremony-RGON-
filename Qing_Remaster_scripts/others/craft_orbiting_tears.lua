-- Flight 环绕泪（批次 3）：595 土星 / 573 无暇之心
-- 邪眼 410 已迁至 mimics/Craft_Evil_Eye_holder.lua
-- 自管轨（去 ORBIT）。FA=0/FS=0；Height=offset2height(正确PO)，并写入同一 PositionOffset（禁止 PO=0）。
-- 轨 Velocity=切向+air.Vel。595 HALO SubType5。
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local enums = require("Qing_Remaster_scripts.core.enums")
local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")
local CraftTearColors = require("Qing_Remaster_scripts.others.craft_tear_color_data")
local CraftTearParams = require("Qing_Remaster_scripts.others.craft_tear_params_data")

local item = {
	ToCall = {},
	pre_ToCall = {},
	own_key = "craft_orbiting_tears_",
	cfg = {},
}

local IDS = {
	SATURNUS = 595,
	IMMACULATE = 573,
}

-- 探针：半径中位 ~88.9，角速度 ~6.4°/帧；寿命 wiki 13s≈390
local DEFAULTS = {
	saturn_count = 7,
	saturn_life = 390,
	saturn_vanilla_radius = 89,
	saturn_radius = 45,
	saturn_damage_mul = 1.5,
	saturn_damage_add = 5,
	saturn_speed = 6.4,
	saturn_halo_anm2_y = -20,
	saturn_halo_subtype = 5,
	saturn_halo_scale = 0.5,
	saturn_hint_ideal_frac = 0.45,
	saturn_hint_boost_base = 1.6,
	saturn_hint_boost_per = 0.18,
	saturn_hint_boost_cap = 5.5,
	saturn_hint_slack = 6,
	immaculate_chance = 0.20,
	immaculate_radius = 45,
	immaculate_speed = 6.4,
	immaculate_life = 200,
	immaculate_launch_frames = 10,
	-- Tiny Planet path ORBIT：定圆 + 攻击时圆心沿瞄准平滑前移（勿再改椭圆长轴，会跳）
	tiny_radius = 100,
	tiny_center_shift = 42, -- 攻击时圆心相对 Flight 沿瞄准前移量
	tiny_center_follow = 0.2, -- 圆心偏移每帧逼近系数
	tiny_omega = 3.75,
	tiny_launch_frames = 14,
	tiny_fall_per_frame = 0.08,
	tiny_redirect = 0.32, -- 无暇悬浮环 redirect_aim（定圆相位），与 path 无关
	-- 我的镜像（探针 session 59065082）：apex 距中位≈286、约 27 帧达顶；勿用 0.22×range（会短得离谱）
	boomerang_pull = 0.85,
	boomerang_pull_return = 1.35,
	boomerang_apex_range_frac = 0.5,
	boomerang_apex_min = 140,
}

-- InitSeed 强表（禁止弱键 userdata）
local TRACKED = {} -- [InitSeed] = {tear=, meta=}  -- 土星/无暇悬浮环
local PATH = {} -- [InitSeed] = {tear=, meta=}    -- 小小星球 ORBIT / 镜像 BOOMERANG
local air_still_valid -- forward decl（path 步进会调用）

local function cfg(key)
	local v = item.cfg[key]
	if v ~= nil then return v end
	return DEFAULTS[key]
end

function item.get_defaults()
	local t = {}
	for k, v in pairs(DEFAULTS) do t[k] = v end
	return t
end

function item.get_cfg(key)
	return cfg(key)
end

function item.set_cfg(key, value)
	if key == nil then return end
	if value == nil then
		item.cfg[key] = nil
	else
		item.cfg[key] = value
	end
end

function item.reset_cfg(keys)
	if keys == nil then
		item.cfg = {}
		return
	end
	for _, k in ipairs(keys) do
		item.cfg[k] = nil
	end
end

local function get_air_mod()
	return require("Qing_Remaster_scripts.items.Item_Air_Flight")
end

local function get_blueprint()
	return require("Qing_Remaster_scripts.items.Item_Blue_Print")
end

local function count_of(profile, id)
	return CraftProfile.count_of(profile and profile.counts, id)
end

local function craft_uid_of(air)
	if not air then return nil end
	return air:GetData()[get_blueprint().own_key.."craft_uid"]
end

local function flight_damage(profile, player)
	return (profile and profile.stats and tonumber(profile.stats.damage))
		or (player and tonumber(player.Damage))
		or 3.5
end

local function sim_orbit_flags(no_grid)
	local orb = TearFlags.TEAR_SPECTRAL or 0
	if no_grid and TearFlags.TEAR_NO_GRID_DAMAGE then
		orb = orb | TearFlags.TEAR_NO_GRID_DAMAGE
	end
	return orb
end

local function strip_engine_orbit_flags(tear)
	if not tear then return end
	local clear = BitSet128(0, 0)
	if TearFlags.TEAR_ORBIT_ADVANCED then
		clear = clear | TearFlags.TEAR_ORBIT_ADVANCED
	end
	if TearFlags.TEAR_ORBIT then
		clear = clear | TearFlags.TEAR_ORBIT
	end
	if tear.ClearTearFlags then
		pcall(function() tear:ClearTearFlags(clear) end)
	end
end

local function flag_has(flags, bit)
	if not flags or not bit then return false end
	local ok, found = pcall(function() return (flags & bit) == bit end)
	return ok and found == true
end

local function strip_path_engine_flags(tear, do_orbit, do_boom)
	if not tear or not tear.ClearTearFlags then return end
	local clear = BitSet128(0, 0)
	if do_orbit then
		if TearFlags.TEAR_ORBIT then clear = clear | TearFlags.TEAR_ORBIT end
		if TearFlags.TEAR_ORBIT_ADVANCED then clear = clear | TearFlags.TEAR_ORBIT_ADVANCED end
	end
	if do_boom and TearFlags.TEAR_BOOMERANG then
		clear = clear | TearFlags.TEAR_BOOMERANG
	end
	if clear ~= BitSet128(0, 0) then
		pcall(function() tear:ClearTearFlags(clear) end)
	end
end

local function shortest_angle_lerp(cur, want, t)
	cur = tonumber(cur) or 0
	want = tonumber(want) or 0
	t = tonumber(t) or 0
	local diff = (want - cur + 180) % 360 - 180
	return cur + diff * t
end

--- Flight 当前射击方向；优先用 Flight 发布的 AuxAim（攻击态），避免玩家摇杆抖动拖椭圆。
local function flight_aim_state(air)
	local Air = get_air_mod()
	local d = air:GetData()
	local key = Air.own_key.."last_aim"
	local aux = d[Air.own_key.."AuxAimDirection"]
	local shooting = d[Air.own_key.."AuxShouldShoot"] == true
	if shooting and aux and aux:Length() > 0.01 then
		local aim = aux:Normalized()
		d[key] = Vector(aim.X, aim.Y)
		return aim, true
	end
	local player = air.Player
	local aim = nil
	local active = false
	if player then
		local joy = player:GetShootingJoystick()
		if joy and joy:Length() > 0.1 then
			aim = joy:Normalized()
			active = true
		else
			local ad = player:GetAimDirection()
			if ad and ad:Length() > 0.1 then
				aim = ad:Normalized()
				active = true
			end
		end
	end
	if active and aim then
		d[key] = Vector(aim.X, aim.Y)
		return aim, true
	end
	local last = d[key]
	if last and last:Length() > 0.01 then
		return last:Normalized(), false
	end
	return Vector(0, 1), false
end

--- 发射后按 TearFlags 接管：TEAR_ORBIT / TEAR_BOOMERANG。
--- ORBIT：绕 Flight 的定圆；攻击时圆心沿瞄准方向平滑前移（不改椭圆轴）。
function item.adopt_path_tear(tear, air, flags, opts)
	if not tear or not air or not flags then return false end
	opts = opts or {}
	local do_orbit = flag_has(flags, TearFlags.TEAR_ORBIT)
	local do_boom = flag_has(flags, TearFlags.TEAR_BOOMERANG)
	if not do_orbit and not do_boom then return false end
	if TRACKED[tear.InitSeed] then return false end
	strip_path_engine_flags(tear, do_orbit, do_boom)
	tear.Parent = nil
	tear.SpawnerEntity = air
	local aim = opts.aim
	if not aim or aim:Length() < 0.01 then
		aim = select(1, flight_aim_state(air))
	end
	if not aim or aim:Length() < 0.01 then
		aim = tear.Velocity
	end
	if not aim or aim:Length() < 0.01 then
		aim = Vector(0, 1)
	else
		aim = aim:Normalized()
	end
	local Air = get_air_mod()
	air:GetData()[Air.own_key.."last_aim"] = Vector(aim.X, aim.Y)

	-- 相位从瞄准角起步，发射再外扩半径
	local phase = aim:GetAngleDegrees()
	local omega_sign = ((tear.InitSeed or 0) % 2 == 0) and 1 or -1
	local launch_frames = 0
	if do_orbit then
		launch_frames = math.max(0, math.floor(tonumber(cfg("tiny_launch_frames")) or 14))
	end

	local range = tonumber(opts.range) or 260
	local apex = math.max(
		tonumber(cfg("boomerang_apex_min")) or 42,
		range * (tonumber(cfg("boomerang_apex_range_frac")) or 0.22)
	)
	local td = tear:GetData()
	td[item.own_key.."path_hold"] = true
	td[Air.own_key.."craft_air"] = air
	td[item.own_key.."await_first_update"] = true
	if do_orbit then
		tear.FallingAcceleration = 0
		tear.FallingSpeed = 0
	end
	PATH[tear.InitSeed] = {
		tear = tear,
		meta = {
			air_seed = air.InitSeed,
			craft_uid = craft_uid_of(air),
			born = Game():GetFrameCount(),
			orbit = do_orbit,
			boom = do_boom,
			phase = phase,
			omega = tonumber(cfg("tiny_omega")) or 3.75,
			omega_sign = omega_sign,
			aim0 = Vector(aim.X, aim.Y),
			spawn = Vector(tear.Position.X, tear.Position.Y),
			apex = apex,
			max_along = 0,
			returning = false,
			center_off = Vector(0, 0),
			launch_left = launch_frames > 0 and launch_frames or nil,
			launch_total = launch_frames > 0 and launch_frames or nil,
			last_step_frame = nil,
			last_pos = Vector(tear.Position.X, tear.Position.Y),
		},
	}
	return true
end

local function apply_path_step(tear, meta)
	if not tear or not meta then return false end
	if not tear:Exists() or tear:IsDead() then return false end
	local air = air_still_valid(meta.air_seed, meta.craft_uid)
	if not air then
		tear:Remove()
		return false
	end
	tear.Parent = nil
	if tear.SpawnerEntity ~= nil then
		tear.SpawnerEntity = air
	end
	if meta.orbit then
		local aim, aim_active = flight_aim_state(air)
		local shift = tonumber(cfg("tiny_center_shift")) or 42
		local follow = tonumber(cfg("tiny_center_follow")) or 0.2
		follow = math.max(0.01, math.min(1, follow))
		local want_off = Vector(0, 0)
		if aim_active and aim and aim:Length() > 0.01 then
			want_off = aim:Normalized() * shift
		end
		local cur_off = meta.center_off or Vector(0, 0)
		local next_off = Vector(
			cur_off.X + (want_off.X - cur_off.X) * follow,
			cur_off.Y + (want_off.Y - cur_off.Y) * follow
		)
		local d_off = Vector(next_off.X - cur_off.X, next_off.Y - cur_off.Y)
		meta.center_off = next_off

		local radius = tonumber(cfg("tiny_radius")) or 100
		local rad_mul = 1
		local launch_left = tonumber(meta.launch_left)
		local launch_total = tonumber(meta.launch_total) or 1
		local launching = launch_left and launch_left > 0 and launch_total > 0
		if launching then
			local done = 1 - (launch_left / launch_total)
			rad_mul = 0.12 + 0.88 * math.max(0, math.min(1, done))
			meta.launch_left = launch_left - 1
		end
		radius = radius * rad_mul

		local omega = (tonumber(meta.omega) or 3.75) * (tonumber(meta.omega_sign) or 1)
		meta.phase = (tonumber(meta.phase) or 0) + omega
		local th = math.rad(tonumber(meta.phase) or 0)
		local center = air.Position + next_off
		local desired = center + Vector(math.cos(th), math.sin(th)) * radius
		-- 切向 + 圆心（机体 + 偏移）速度，供渲染插值
		local w = omega * math.pi / 180
		local tang = Vector(-math.sin(th), math.cos(th)) * (radius * w)
		if launching then
			local radial = desired - center
			if radial:Length() > 0.01 then
				tang = tang + radial:Resized(radius * 0.88 / launch_total)
			end
		end
		tear.Position = desired
		tear.Velocity = tang + (air.Velocity or Vector.Zero) + d_off
		tear.FallingAcceleration = 0
		tear.FallingSpeed = 0
		if tear.Height ~= nil then
			local fall = tonumber(cfg("tiny_fall_per_frame")) or 0.08
			tear.Height = math.min(0, (tonumber(tear.Height) or -23) + fall)
		end
		strip_path_engine_flags(tear, true, false)
	end
	if meta.boom then
		-- 探针：外冲期 FA≈-0.06（微抬），勿用普通泪下落提前落地
		tear.FallingAcceleration = -0.06
		tear.FallingSpeed = 0
		local spawn = meta.spawn or air.Position
		local aim0 = meta.aim0 or Vector(0, 1)
		if aim0:Length() < 0.01 then aim0 = Vector(0, 1) else aim0 = aim0:Normalized() end
		local along = (tear.Position - spawn):Dot(aim0)
		if along > (tonumber(meta.max_along) or 0) then
			meta.max_along = along
		end
		local apex = tonumber(meta.apex) or 160
		if along >= apex or meta.returning then
			meta.returning = true
		end
		local to = air.Position - tear.Position
		local dist = to:Length()
		if dist > 0.01 then
			local pull = tonumber(cfg("boomerang_pull")) or 0.85
			if meta.returning then
				pull = tonumber(cfg("boomerang_pull_return")) or 1.35
			end
			tear.Velocity = (tear.Velocity or Vector.Zero) + to:Resized(pull)
		end
		strip_path_engine_flags(tear, false, true)
	end
	meta.last_pos = Vector(tear.Position.X, tear.Position.Y)
	return true
end

function item.tick_path_tears()
	-- 仅补漏：主步进在 POST_TEAR_UPDATE；禁止同帧双步进（会毁掉 Velocity 插值与 ω）
	local frame = Game():GetFrameCount()
	for seed, row in pairs(PATH) do
		local tear = row and row.tear
		local meta = row and row.meta
		if not tear or not tear:Exists() or tear:IsDead() then
			PATH[seed] = nil
		elseif meta and meta.last_step_frame ~= frame then
			if not apply_path_step(tear, meta) then
				PATH[seed] = nil
			else
				meta.last_step_frame = frame
			end
		end
	end
end

local function apply_sim_flags(tear, no_grid)
	local orb = sim_orbit_flags(no_grid)
	if tear.AddTearFlags then
		tear:AddTearFlags(orb)
	elseif tear.TearFlags ~= nil then
		tear.TearFlags = (tear.TearFlags or 0) | orb
	end
	strip_engine_orbit_flags(tear)
end

local function stamp(tear, air)
	if not tear or not air then return end
	local Air = get_air_mod()
	local td = tear:GetData()
	td[Air.own_key.."craft_air"] = air
	td[Air.own_key.."craft_uid"] = craft_uid_of(air)
	td[item.own_key.."tracked"] = true
end

local function copy_po(v)
	if not v then return Vector(0, 0) end
	return Vector(v.X, v.Y)
end

local function spawn_effect(variant, subtype, pos, vel, spawner)
	local ent = Isaac.Spawn(EntityType.ENTITY_EFFECT, variant, subtype or 0, pos, vel or Vector.Zero, spawner)
	return ent and (ent:ToEffect() or ent) or nil
end

local function sync_follow_fx(fx, air, scale, po_extra_y)
	if not fx or not air then return end
	-- 光环：Effect 只用 PO 抬升（对齐 Flight）；禁止 Parent（SpriteRotation 公转）
	if fx.Parent ~= nil then fx.Parent = nil end
	if fx.SetDisableFollowParent then
		pcall(function() fx:SetDisableFollowParent(true) end)
	elseif fx.DisableFollowParent ~= nil then
		fx.DisableFollowParent = true
	end
	if fx.SpriteRotation ~= nil then fx.SpriteRotation = 0 end
	local spr = fx.GetSprite and fx:GetSprite()
	if spr and spr.Rotation ~= nil then spr.Rotation = 0 end
	fx.Position = air.Position
	fx.Velocity = air.Velocity or Vector.Zero
	if fx.PositionOffset ~= nil then
		local po = air.PositionOffset or Vector(0, 0)
		fx.PositionOffset = Vector(po.X, po.Y + (tonumber(po_extra_y) or 0))
	end
	if scale and fx.SpriteScale then
		fx.SpriteScale = Vector(scale, scale)
	end
end

local function clear_follow_fx(air, key)
	local d = air:GetData()
	local fx = d[item.own_key..key]
	if fx and auxi.check_all_exists(fx) then
		fx:Remove()
	end
	d[item.own_key..key] = nil
end

local function halo_scale_for_radius()
	local scale = tonumber(cfg("saturn_halo_scale"))
	if scale ~= nil then return scale end
	local r = tonumber(cfg("saturn_radius")) or 45
	local vr = tonumber(cfg("saturn_vanilla_radius")) or 89
	return math.max(0.25, r / vr)
end

local function halo_po_cancel_y()
	local anm2_y = tonumber(cfg("saturn_halo_anm2_y")) or -20
	return -anm2_y
end

local function ensure_saturn_halo(air)
	if not air then return end
	local d = air:GetData()
	local craft_prof = d[get_air_mod().own_key.."craft_profile"]
	if count_of(craft_prof, IDS.SATURNUS) <= 0 then
		clear_follow_fx(air, "saturn_halo")
		return
	end
	local sub = tonumber(cfg("saturn_halo_subtype")) or 5
	local scale = halo_scale_for_radius()
	local cancel = halo_po_cancel_y()
	local fx = d[item.own_key.."saturn_halo"]
	if fx and auxi.check_all_exists(fx) then
		sync_follow_fx(fx, air, scale, cancel)
		return fx
	end
	-- Spawner 也别绑 Flight：部分特效仍会跟 Spawner 继承旋转/位移
	fx = spawn_effect(EffectVariant.HALO or 123, sub, air.Position, Vector.Zero, nil)
	if fx then
		fx.SpawnerEntity = nil
		if fx.Parent ~= nil then fx.Parent = nil end
		if fx.SpriteRotation ~= nil then fx.SpriteRotation = 0 end
		local spr = fx.GetSprite and fx:GetSprite()
		if spr and spr.Rotation ~= nil then spr.Rotation = 0 end
		sync_follow_fx(fx, air, scale, cancel)
		d[item.own_key.."saturn_halo"] = fx
	end
	return fx
end

-- 探针：引擎在 FA≈0 时会把 Height 换成 PositionOffset（height2offset）；Update 若 PO=0 而 Render PO≠0 就打架。
-- 正确：Height = offset2height(正确PO)，并主动写入同一 PO（=height2offset(Height)），禁止强行 PO=0。
--
-- 临界（本模组 auxi.height2offset / offset2height）：
--   (acce or 0) > 0.001  → Height 与画面 Y 一一对应
--   否则                 → Height = (Y+25)/0.4 - 25
-- 跨过 0.001 时若只改 FA、不按新公式重写 Height，画面升空会瞬间跳一截（例如 -87.5 当 Y 用）。
-- 松环：当帧固定画面 Y，一次 write_visual_offset_y(Y, FALL_FA)，保留 Velocity，之后交给引擎。
local FALL_FA = 0.9
local FALL_FS = 0.2
local FA_FORMULA_EPS = 0.001 -- 与 auxi.height2offset / offset2height 一致

-- 无暇额外泪外观与圣心（182）一致（audit Tint 1.5/2/2/A1）；仅额外环绕泪，不污染主射。
local function sacred_heart_color()
	local v = CraftTearColors.DATA and CraftTearColors.DATA[182]
	if type(v) == "table" then
		return Color(v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8] or 0, v[9] or 0, v[10] or 0, v[11] or 0)
	end
	return Color(1.5, 2, 2, 1, 0, 0, 0)
end

local function apply_immaculate_appearance(tear)
	if not tear then return end
	local c = sacred_heart_color()
	tear.Color = c
	local ok, spr = pcall(function() return tear:GetSprite() end)
	if ok and spr then spr.Color = c end
end

local function air_combat_offset_y(air)
	local y = -34
	if air and air.PositionOffset then
		y = air.PositionOffset.Y
	end
	if y < -50 then y = -50 elseif y > -28 then y = -28 end
	return y
end

--- 当前画面升空 Y（PO 语义）。环上 FA=0：优先 PO，并用 height2offset(Height,0) 交叉校验。
local function read_visual_offset_y(tear)
	if not tear then return -34 end
	local fa = tonumber(tear.FallingAcceleration) or 0
	local h = tonumber(tear.Height) or -23.75
	-- 仍在悬浮公式侧：Height 必须按 FA≈0 反推，不能拿 FA>eps 的恒等去读旧 Height
	if fa <= FA_FORMULA_EPS then
		local y_h = auxi.height2offset(h, 0)
		local po = tear.PositionOffset
		if po and math.abs(po.Y) > 0.01 then
			-- PO 与 Height 成对时应接近；若被清过则信 Height
			if math.abs(po.Y - y_h) < 1.5 then
				return po.Y
			end
		end
		return y_h
	end
	return auxi.height2offset(h, fa)
end

--- 按目标 FA 写入同一画面升空量。
--- FA≤eps：Height↔PO 成对（悬浮公式）。
--- FA>eps：Height = 画面Y，且 PO.Y 也写成同一画面Y（禁止 PO=0）。
--- 证据：松环当帧若 PO=0 而 Height=-41，Update↔Render ΔPO≈41，会闪一帧；引擎要到 Render 才把 PO 填回。
--- 赋值顺序：先 Height/PO，最后 FA。
local function write_visual_offset_y(tear, visual_y, fa)
	if not tear then return end
	fa = tonumber(fa) or 0
	visual_y = tonumber(visual_y) or -34
	local h = auxi.offset2height(Vector(0, visual_y), fa)
	if tear.Height ~= nil then
		tear.Height = h
	end
	if tear.PositionOffset ~= nil then
		-- 恒把 PO 写成当前公式下的画面 Y（FA>eps 时 h==visual_y）
		tear.PositionOffset = Vector(0, visual_y)
	end
	if tear.FallingAcceleration ~= nil then
		tear.FallingAcceleration = fa
	end
end

local function hold_orbit_physics(tear, air)
	if not tear then return end
	if tear.FallingSpeed ~= nil then tear.FallingSpeed = 0 end
	local y = air_combat_offset_y(air)
	write_visual_offset_y(tear, y, 0)
	if tear.SetParentOffset then
		pcall(function() tear:SetParentOffset(Vector.Zero) end)
	elseif tear.ParentOffset ~= nil then
		tear.ParentOffset = Vector.Zero
	end
end

local function strip_orbit_hazards(tear)
	if not tear then return end
	if TearFlags.TEAR_EXPLOSIVE and tear.ClearTearFlags then
		pcall(function() tear:ClearTearFlags(TearFlags.TEAR_EXPLOSIVE) end)
	end
	if TearFlags.TEAR_BURSTSPLIT and tear.ClearTearFlags then
		pcall(function() tear:ClearTearFlags(TearFlags.TEAR_BURSTSPLIT) end)
	end
	tear:GetData().craft_no_haemo = true
end

--- 生成：Isaac.Spawn（避免 FireTear 继承玩家 ORBIT/ParentOffset）；归属 Spawner=Flight，不设 Parent
function item.spawn_orbit_tear(air, player, craft_prof, opts)
	if not air or not player or not craft_prof then return nil end
	opts = opts or {}
	local ent = Isaac.Spawn(EntityType.ENTITY_TEAR, TearVariant.BLUE or 0, 0, air.Position, Vector.Zero, air)
	local q = ent and ent:ToTear()
	if not q then return nil end
	-- 自管世界坐标：禁止 Parent（否则渲染易走 Parent+ParentOffset）
	q.Parent = nil
	q.SpawnerEntity = air
	if q.SetParentOffset then
		pcall(function() q:SetParentOffset(Vector.Zero) end)
	elseif q.ParentOffset ~= nil then
		q.ParentOffset = Vector.Zero
	end
	local flags = CraftProfile.sample_tear_flags(
		player,
		craft_prof.stats and craft_prof.stats.luck or 0,
		craft_prof,
		WeaponType.WEAPON_TEARS,
		{
			shot_serial = tonumber(air:GetData()[get_air_mod().own_key.."shot_serial"]) or 0,
			craft_uid = craft_uid_of(air),
			projectile_index = tonumber(opts.projectile_index) or 0,
		}
	) or BitSet128(0, 0)
	local no_grid = opts.no_grid == true or opts.kind == "saturnus"
	flags = flags | sim_orbit_flags(no_grid)
	local dmg_mul = tonumber(opts.damage_mul) or 1
	CraftProfile.apply_tear_stats(q, craft_prof, dmg_mul, flags, {})
	if opts.damage then
		q.CollisionDamage = opts.damage
	end
	CraftTearColors.apply(q, craft_prof.counts, flags, CraftProfile.TEAR_EFFECTS)
	CraftTearParams.apply(q, craft_prof.counts, flags, CraftProfile.TEAR_EFFECTS, {
		range = craft_prof.stats and craft_prof.stats.range,
		shotspeed = craft_prof.stats and craft_prof.stats.shotspeed,
		set_base_height = function(accel)
			local fa = accel or 0
			return auxi.offset2height(Vector(0, air_combat_offset_y(air)), fa)
		end,
	})
	apply_sim_flags(q, no_grid)
	strip_orbit_hazards(q)
	hold_orbit_physics(q, air)
	if opts.kind == "immaculate" then
		apply_immaculate_appearance(q)
	end
	if CraftProfile.profile_has_haemolacria and CraftProfile.profile_has_haemolacria(craft_prof) then
		CraftProfile.mark_craft_haemo_tear(q, craft_prof, player, {
			damage = q.CollisionDamage,
			dir = Vector(0, 0),
		})
		q:GetData().craft_no_haemo = true
	end
	local Air = get_air_mod()
	local td = q:GetData()
	td[Air.own_key.."craft_air"] = air
	td[Air.own_key.."craft_uid"] = craft_uid_of(air)
	td[item.own_key.."tracked"] = true
	td[item.own_key.."orbit_hold"] = true
	-- 生成帧会先 Render、后 Update：首帧缓存不可信，PRE 隐藏到第一次 Update（同 craft_familiar_tear_height_pitfalls）
	td[item.own_key.."await_first_update"] = true
	local angle = tonumber(opts.angle) or 0
	local radius = tonumber(opts.radius) or tonumber(cfg("saturn_radius")) or 45
	local spd = tonumber(opts.speed) or tonumber(cfg("saturn_speed")) or 6.4
	local launch_frames = math.max(0, math.floor(tonumber(opts.launch_frames) or 0))
	local tang = Vector.FromAngle(angle + 90) * (radius * spd * math.pi / 180)
	if launch_frames > 0 then
		-- 无暇等：从枪口飞出再入轨，禁止瞬移到环上
		q.Position = air.Position
		local out = Vector.FromAngle(angle) * math.max(3.5, radius / launch_frames)
		q.Velocity = out + (air.Velocity or Vector.Zero)
	else
		q.Position = air.Position + Vector.FromAngle(angle) * radius
		q.Velocity = tang + (air.Velocity or Vector.Zero)
	end
	TRACKED[q.InitSeed] = {
		tear = q,
		meta = {
			kind = opts.kind or "orbit",
			air_seed = air.InitSeed,
			craft_uid = craft_uid_of(air),
			angle = angle,
			radius = radius,
			born = Game():GetFrameCount(),
			life = tonumber(opts.life),
			manual = true,
			speed = tonumber(opts.speed),
			launch_left = launch_frames > 0 and launch_frames or nil,
			launch_total = launch_frames > 0 and launch_frames or nil,
			redirect_aim = opts.redirect_aim == true,
			had_ipecac = CraftProfile.count_of(craft_prof.counts, 149) > 0,
			had_haemo = CraftProfile.profile_has_haemolacria and CraftProfile.profile_has_haemolacria(craft_prof),
		},
	}
	return q
end

function item.spawn_saturnus_ring(air, player, craft_prof)
	if not air or count_of(craft_prof, IDS.SATURNUS) <= 0 then return end
	local n = math.max(1, math.floor(tonumber(cfg("saturn_count")) or 7))
	local radius = tonumber(cfg("saturn_radius")) or 45
	local life = math.max(1, math.floor(tonumber(cfg("saturn_life")) or 390))
	local dmg = flight_damage(craft_prof, player) * (tonumber(cfg("saturn_damage_mul")) or 1.5)
		+ (tonumber(cfg("saturn_damage_add")) or 5)
	local speed = tonumber(cfg("saturn_speed")) or 6.4
	for i = 1, n do
		local ang = (i - 1) * (360 / n)
		item.spawn_orbit_tear(air, player, craft_prof, {
			kind = "saturnus",
			angle = ang,
			radius = radius,
			life = life,
			damage = dmg,
			damage_mul = 1,
			speed = speed,
			no_grid = true,
			projectile_index = 500 + i,
		})
	end
	ensure_saturn_halo(air)
end

function item.try_immaculate_volley(air, player, craft_prof, aim_dir)
	if not air or not player or not craft_prof then return end
	if count_of(craft_prof, IDS.IMMACULATE) <= 0 then return end
	if not aim_dir or aim_dir:Length() < 0.01 then return end
	local rng = player:GetCollectibleRNG(IDS.IMMACULATE)
	if rng:RandomFloat() >= (tonumber(cfg("immaculate_chance")) or 0.2) then return end
	item.spawn_orbit_tear(air, player, craft_prof, {
		kind = "immaculate",
		angle = aim_dir:GetAngleDegrees(),
		radius = tonumber(cfg("immaculate_radius")) or tonumber(cfg("saturn_radius")) or 45,
		life = tonumber(cfg("immaculate_life")) or 200,
		speed = tonumber(cfg("immaculate_speed")) or tonumber(cfg("saturn_speed")) or 6.4,
		damage_mul = 1,
		no_grid = false,
		launch_frames = tonumber(cfg("immaculate_launch_frames")) or 10,
		redirect_aim = true, -- 更接近小小星球：开火方向重定向环相位
		projectile_index = 900 + (air.FrameCount % 97),
	})
end

function item.on_volley_fired(air, player, craft_prof, aim_dir)
	item.try_immaculate_volley(air, player, craft_prof, aim_dir)
	local ok, EvilEye = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Evil_Eye_holder")
	if ok and EvilEye and EvilEye.try_craft_volley then
		EvilEye.try_craft_volley(air, player, craft_prof, aim_dir)
	end
	local ok2, Aux = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Aux_Entities_holder")
	if ok2 and Aux and Aux.try_craft_volley then
		Aux.try_craft_volley(air, player, craft_prof, aim_dir)
	end
end

air_still_valid = function(air_seed, craft_uid)
	local Air = get_air_mod()
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, Air.familiar or enums.Familiars.QingsAirs, -1, false, false)) do
		local air = ent:ToFamiliar()
		if air and auxi.check_all_exists(air) and air.InitSeed == air_seed then
			if not craft_uid or craft_uid_of(air) == craft_uid then
				return air
			end
		end
	end
	return nil
end

--- 环结束：一次换算到下落公式下的同画面 Y，之后交给引擎。
--- 保留当前 Velocity（切向飞出 + 自然掉落可接受）；禁止再每帧锁 Height/PO，也不刹速。
local function begin_fall(tear, meta)
	if not tear then return end
	local td = tear:GetData()
	td[item.own_key.."orbit_hold"] = nil
	td.craft_no_haemo = nil
	local visual_y = read_visual_offset_y(tear)
	write_visual_offset_y(tear, visual_y, FALL_FA)
	if tear.FallingSpeed ~= nil then tear.FallingSpeed = FALL_FS end
	-- 探针用：松环当帧打标（Offset 探针密采窗）；正式逻辑不依赖
	td[item.own_key.."fall_mark_frame"] = Game():GetFrameCount()
	td[item.own_key.."fall_mark_from_y"] = visual_y
	if meta and meta.had_haemo and CraftProfile.clear_craft_haemo_burst_flag then
		CraftProfile.clear_craft_haemo_burst_flag(tear)
	end
end

local function apply_orbit_step(tear, meta)
	if not tear or not meta or not meta.manual then return false end
	if not tear:Exists() or tear:IsDead() then return false end
	local air = air_still_valid(meta.air_seed, meta.craft_uid)
	if not air then
		tear:Remove()
		return false
	end
	if meta.life then
		local age = Game():GetFrameCount() - (tonumber(meta.born) or 0)
		if age >= meta.life then
			begin_fall(tear, meta)
			return false
		end
	end
	local speed = tonumber(meta.speed) or tonumber(cfg("saturn_speed")) or 6.4
	local rad = tonumber(meta.radius) or tonumber(cfg("saturn_radius")) or 45
	local launch_left = tonumber(meta.launch_left)
	if launch_left and launch_left > 0 then
		-- 发射段：枪口 → 入轨点；角度暂不公转，结束后才按环速转
		local total = math.max(1, tonumber(meta.launch_total) or launch_left)
		meta.launch_left = launch_left - 1
		local u = 1 - (meta.launch_left / total)
		if u < 0 then u = 0 elseif u > 1 then u = 1 end
		u = u * u * (3 - 2 * u)
		local desired = air.Position + Vector.FromAngle(meta.angle or 0) * rad
		local muzzle = air.Position
		tear.Parent = nil
		tear.Position = muzzle + (desired - muzzle) * u
		local tang = Vector.FromAngle((meta.angle or 0) + 90) * (rad * speed * math.pi / 180)
		local out = desired - muzzle
		local out_spd = math.max(3.5, rad / total)
		if out:Length() > 0.01 then
			out = out:Resized(out_spd)
		else
			out = Vector.FromAngle(meta.angle or 0) * out_spd
		end
		tear.Velocity = out * (1 - u) + (tang + (air.Velocity or Vector.Zero)) * u
		hold_orbit_physics(tear, air)
		strip_orbit_hazards(tear)
		strip_engine_orbit_flags(tear)
		if meta.kind == "immaculate" then
			apply_immaculate_appearance(tear)
		end
		if meta.launch_left <= 0 then
			meta.launch_left = nil
			meta.launch_total = nil
		end
		return true
	end
	if meta.redirect_aim then
		local aim = air:GetData()[get_air_mod().own_key.."last_aim"]
		if aim and aim:Length() > 0.01 then
			meta.angle = shortest_angle_lerp(
				meta.angle,
				aim:GetAngleDegrees(),
				tonumber(cfg("tiny_redirect")) or 0.32
			)
		end
	end
	meta.angle = (tonumber(meta.angle) or 0) + speed
	local desired = air.Position + Vector.FromAngle(meta.angle) * rad
	local tang = Vector.FromAngle(meta.angle + 90) * (rad * speed * math.pi / 180)
	tear.Parent = nil
	tear.Position = desired
	tear.Velocity = tang + (air.Velocity or Vector.Zero)
	hold_orbit_physics(tear, air)
	strip_orbit_hazards(tear)
	strip_engine_orbit_flags(tear)
	if meta.kind == "immaculate" then
		apply_immaculate_appearance(tear)
	end
	return true
end

local function prune_dead_tracked()
	for seed, row in pairs(TRACKED) do
		local tear = row and row.tear
		local meta = row and row.meta
		if not tear or not tear:Exists() or tear:IsDead() then
			TRACKED[seed] = nil
		elseif meta and meta.life then
			local age = Game():GetFrameCount() - (tonumber(meta.born) or 0)
			if age >= meta.life then
				begin_fall(tear, meta)
				TRACKED[seed] = nil
			end
		end
	end
end

local function count_manual_tears_for_air(air)
	if not air then return 0, nil end
	local n = 0
	local radius = tonumber(cfg("saturn_radius")) or 45
	for _, row in pairs(TRACKED) do
		local tear = row.tear
		local meta = row.meta
		if meta and meta.manual and meta.air_seed == air.InitSeed
			and tear and tear:Exists() and not tear:IsDead() then
			n = n + 1
			if meta.radius then radius = meta.radius end
		end
	end
	return n, radius
end

local function nearest_enemy(pos, max_dist)
	max_dist = max_dist or 280
	local best, best_d = nil, max_dist
	for _, ent in ipairs(Isaac.FindInRadius(pos, max_dist, EntityPartition.ENEMY)) do
		if ent and ent:Exists() and not ent:IsDead() and ent:IsVulnerableEnemy() then
			local d = (ent.Position - pos):Length()
			if d < best_d then
				best, best_d = ent, d
			end
		end
	end
	return best, best_d
end

function item.get_move_hint(air)
	if not air or not auxi.check_all_exists(air) then return nil end
	local n, radius = count_manual_tears_for_air(air)
	if n <= 0 then return nil end
	local enemy = nearest_enemy(air.Position, math.max(220, radius * 4))
	if not enemy then return nil end
	local ideal = radius * (tonumber(cfg("saturn_hint_ideal_frac")) or 0.45)
	local slack = tonumber(cfg("saturn_hint_slack")) or 6
	local to = enemy.Position - air.Position
	local dist = to:Length()
	if dist < 0.01 then return nil end
	local toward = to:Normalized()
	local overshoot = 0
	if dist > ideal + slack then
		overshoot = dist - ideal
	elseif dist < math.max(8, ideal - slack) then
		overshoot = ideal - dist
		toward = toward * -1
	else
		return nil
	end
	return {
		mode = "saturn_cover",
		toward = toward,
		overshoot = overshoot,
		ideal = ideal,
		radius = radius,
		boost_base = tonumber(cfg("saturn_hint_boost_base")) or 1.6,
		boost_per = tonumber(cfg("saturn_hint_boost_per")) or 0.18,
		boost_cap = tonumber(cfg("saturn_hint_boost_cap")) or 5.5,
	}
end

--- 只按 InitSeed 索引。禁止 `row.tear == tear`：Isaac 对同一实体可有多份 userdata wrapper，== 不可靠。
local function tracked_row_for(tear)
	if not tear then return nil end
	local row = TRACKED[tear.InitSeed]
	if not row then return nil end
	row.tear = tear
	return row
end

--- 对齐 Ludovico：在 POST_TEAR_UPDATE 写轨 + 重申 FA/FS/Height
function item.on_tear_update(tear)
	if not tear then return end
	local td = tear:GetData()
	if td[item.own_key.."await_first_update"] then
		td[item.own_key.."await_first_update"] = nil
	end
	local path_row = PATH[tear.InitSeed]
	if path_row then
		path_row.tear = tear
		local frame = Game():GetFrameCount()
		if path_row.meta and path_row.meta.last_step_frame == frame then
			return
		end
		if not apply_path_step(tear, path_row.meta) then
			PATH[tear.InitSeed] = nil
		elseif path_row.meta then
			path_row.meta.last_step_frame = frame
		end
		return
	end
	local row = tracked_row_for(tear)
	if not row then return end
	local frame = Game():GetFrameCount()
	if row.meta and row.meta.last_step_frame == frame then
		local air = air_still_valid(row.meta.air_seed, row.meta.craft_uid)
		if air then hold_orbit_physics(tear, air) end
		return
	end
	if not apply_orbit_step(tear, row.meta) then
		TRACKED[tear.InitSeed] = nil
	else
		row.meta.last_step_frame = frame
	end
end

function item.tick_manual_orbits()
	prune_dead_tracked()
end

function item.tick_halos()
	local Air = get_air_mod()
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, Air.familiar or enums.Familiars.QingsAirs, -1, false, false)) do
		local air = ent:ToFamiliar()
		if air and auxi.check_all_exists(air) then
			ensure_saturn_halo(air)
		end
	end
end

function item.clear_for_air(air)
	if not air then return end
	local seed = air.InitSeed
	local uid = craft_uid_of(air)
	for tseed, row in pairs(TRACKED) do
		local meta = row.meta
		if meta and (meta.air_seed == seed or (uid and meta.craft_uid == uid)) then
			local tear = row.tear
			if tear and tear:Exists() then tear:Remove() end
			TRACKED[tseed] = nil
			PATH[tseed] = nil
		end
	end
	for pseed, row in pairs(PATH) do
		local meta = row and row.meta
		if meta and (meta.air_seed == seed or (uid and meta.craft_uid == uid)) then
			local tear = row.tear
			if tear and tear:Exists() then tear:Remove() end
			PATH[pseed] = nil
		end
	end
	do
		local ok, EvilEye = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Evil_Eye_holder")
		if ok and EvilEye and EvilEye.clear_for_owner then
			EvilEye.clear_for_owner(seed, uid)
		end
	end
	clear_follow_fx(air, "saturn_halo")
end

function item.on_new_room()
	local Air = get_air_mod()
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, Air.familiar or enums.Familiars.QingsAirs, -1, false, false)) do
		local air = ent:ToFamiliar()
		if air and auxi.check_all_exists(air) then
			local craft_prof = air:GetData()[Air.own_key.."craft_profile"]
			local player = auxi.check_spawner_player(air)
			if craft_prof and player and count_of(craft_prof, IDS.SATURNUS) > 0 then
				item.clear_for_air(air)
				item.spawn_saturnus_ring(air, player, craft_prof)
			else
				clear_follow_fx(air, "saturn_halo")
			end
		end
	end
end

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		item.on_new_room()
	end,
})

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_TEAR_UPDATE,
	params = nil,
	priority = -50,
	Function = function(_, tear)
		item.on_tear_update(tear)
	end,
})

-- 生成帧先 Render 后 Update：首帧隐藏，避免高度/位置缓存闪一下（同 craft_familiar_tear_height_pitfalls）
if REPENTOGON and ModCallbacks.MC_PRE_TEAR_RENDER then
	table.insert(item.ToCall, {
		CallBack = ModCallbacks.MC_PRE_TEAR_RENDER,
		params = nil,
		Function = function(_, tear, _offset)
			if not tear then return end
			local td = tear:GetData()
			if td[item.own_key.."await_first_update"] then
				if tear.SetShadowSize then tear:SetShadowSize(0) end
				return false
			end
		end,
	})
end

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		item.tick_manual_orbits()
		item.tick_path_tears()
		item.tick_halos()
	end,
})

return item
