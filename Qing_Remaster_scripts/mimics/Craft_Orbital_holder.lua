-- Flight 环绕物控制层（不进普通宝宝队列）。
-- 架构：flight_orbitals_and_on_hurt_design.md
-- 范围：flight_orbitals_on_hurt_scope_v2.md
-- 审阅：orbital_on_hurt_implementation_review.md
-- 运动：blueprint_eid_length_and_orbit_review.md §1（AddToOrbit + GetOrbitPosition）
local enums = require("Qing_Remaster_scripts.core.enums")
local save = require("Qing_Remaster_scripts.core.savedata")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Familiar_Control_Selector = require("Qing_Remaster_scripts.mimics.Familiar_Control_Selector")
local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")
local dev_env = require("Qing_Remaster_scripts.core.dev_environment")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	own_key = "Craft_Orbital_holder_",
	CONTROLLER = "craft_orbital",
	debug = {
		contact_mul = 0.45,
		high_contact_mul = 0.30,
		chase_discount = 0.65,
		hit_interval = 10,
		-- 距离倍率（正式半径来自 GetOrbitDistance / 实体 OrbitDistance，禁止写死 px）
		orbit_dist_mul = 1.0,
		orbit_mul_meat = 1.0,
		orbit_mul_bandage = 1.0,
		orbit_mul_best_bud = 1.0,
		orbit_mul_leprosy = 1.0,
		-- 合成体兜底层；接管期 active layer 用 adapter.orbit_layer，vanilla_* 仅释放恢复
		orbit_layer_meat = 0,
		orbit_layer_bandage = 0,
		orbit_layer_best_bud = 1,
		orbit_layer_leprosy = 0,
		-- 视觉高度：正值屏幕向下；先全局校准，勿用世界半径补高度
		orbital_render_y_bias = 0,
		rebind_smooth = 8,
		spring = 0.28,
		damping = 0.72,
		orbit_max_speed = 16,
		ball_blocks = true,
		psy_search = 180,
		psy_chase_max = 28,
		psy_chase_blend = 0.4,
		psy_lead = 2,
		psy_return_max = 18,
		psy_return_max_after_chase = 22,
		psy_return_blend = 0.28,
		psy_streak_max = 8,
		psy_cd = 20,
		psy_trail_radius = 0.12,
		psy_trail_scale = 0.6,
		-- 批次1：守护天使 / 大粉丝速度聚合（禁止每帧累乘 OrbitSpeed）
		guardian_orbit_factor = 1.5,
		big_fan_orbit_factor = 0.5,
		razor_bleed_frames = 150,
		-- 蓝图解除真实环绕物：飞回玩家轨道（对照 My Emblem re_link），避免立刻交原版造成速度大跳
		return_join_ratio = 0.2,
		return_join_min_distance = 28,
		return_drive_min_speed = 10,
		return_drive_speed_margin = 12,
		return_drive_blend = 0.55,
		soft_attach_frames = 36,
		soft_attach_spring = 0.22,
		soft_attach_damping = 0.78,
		soft_attach_max_speed = 22,
	},
}

local BIND_KEY = "orbital_bind"
-- GetPtrHash -> 最新 wrapper；避免同一 orbital 的 userdata wrapper 重复进入运行集合。
local ACTIVE_BOUND = {}

local function active_key(fam)
	local ok, ptr = pcall(GetPtrHash, fam)
	return ok and ptr or nil
end

local function track_active(fam)
	local key = fam and active_key(fam)
	if key then ACTIVE_BOUND[key] = fam end
end

local function untrack_active(fam)
	local key = fam and active_key(fam)
	if key then ACTIVE_BOUND[key] = nil end
end

local function active_familiar_alive(fam)
	if not fam then return false end
	local ok, alive = pcall(function()
		return fam:Exists() and not fam:IsDead()
	end)
	return ok and alive == true
end

-- forward declare：布局函数在 bind_data 定义前引用
local bind_data
local find_all_bound
local orbit_phase_freeze_comp

-- variant -> adapter；由 register_orbital 填充
local ORBITAL_BY_VARIANT = {}
-- collectible -> adapter（普通 sync；肉块/绷带/on-hurt 另走专用路径）
local ORBITAL_BY_COLLECTIBLE = {}
-- kind -> adapter（同 kind 多 variant 时取主 adapter）
local ORBITAL_BY_KIND = {}
local SORTED_PROFILE_ORBITALS = nil

local function orbital_variants_iter()
	return pairs(ORBITAL_BY_VARIANT)
end

local function is_orbital_variant(variant)
	return ORBITAL_BY_VARIANT[variant] ~= nil
end

--- adapter: collectible, kind, base_dps|base_dps_fn, group, block, count?,
--- layout_ring?, orbit_layer?, orbit_distance?, distance_source?,
--- layout_priority?, render_y_bias?, position_offset_mode?,
--- sync_from_profile?, exclusive?, update?, on_block?, on_contact?, release?, custom_target?, skip_layout?,
--- keep_vanilla_ai?, soft_rebind?（装配/卸下禁 Position 瞬移，只 Velocity 软驱）,
--- detached_follow?（定向附件：禁止加入原版 Orbit；每帧由 custom_drive 脱队并强驱）,
--- custom_drive?(fam,bind,air,target,buckets,state)->true 则跳过弹簧/瞬移
function item.register_orbital(variant, adapter)
	if not variant or not adapter or not adapter.kind then return end
	adapter.variant = variant
	ORBITAL_BY_VARIANT[variant] = adapter
	if adapter.collectible and adapter.sync_from_profile ~= false and not adapter.exclusive then
		ORBITAL_BY_COLLECTIBLE[adapter.collectible] = adapter
		SORTED_PROFILE_ORBITALS = nil
	end
	if not ORBITAL_BY_KIND[adapter.kind] then
		ORBITAL_BY_KIND[adapter.kind] = adapter
	end
end

local MEAT_ID = CollectibleType.COLLECTIBLE_CUBE_OF_MEAT or 73
local BANDAGE_ID = CollectibleType.COLLECTIBLE_BALL_OF_BANDAGES or 207
local BEST_BUD_ID = CollectibleType.COLLECTIBLE_BEST_BUD or 274
local LEPROSY_ID = CollectibleType.COLLECTIBLE_LEPROSY or 525

-- wiki：肉块/绷带约 56 DPS；好朋友 150 DPS；麻风 35 DPS（麻风耐久阶段仍为占位）
local BASE_DPS = {
	meat = 56,
	bandage = 56,
	best_bud = 150,
	leprosy = 35,
}

local frame_buckets = nil
local frame_buckets_frame = -1

local function get_blueprint()
	return require("Qing_Remaster_scripts.items.Item_Blue_Print")
end

local function get_air_mod()
	return require("Qing_Remaster_scripts.items.Item_Air_Flight")
end

local function venge_probe_trace(event, fam, extra)
	local Probe = dev_env.require_probe("Qing_Remaster_scripts.others.vengeful_craft_lifecycle_probe")
	if Probe and Probe.trace then
		Probe.trace(event, fam, extra)
	end
end

local function dbg(key)
	return item.debug[key]
end

local function dbg_num(key, fallback)
	local v = tonumber(item.debug[key])
	if v == nil then return fallback end
	return v
end

local function copy_vec(v)
	if not v then return nil end
	return Vector(v.X, v.Y)
end

--- 与 Craft_Familiar_holder.find_unbound 同源：原版 Sprite/动画未就绪时不接管。
local ORBITAL_INIT_MIN_FRAMES = 2

local function familiar_vanilla_ready(fam)
	if not fam or not auxi.check_all_exists(fam) then return false end
	if fam.Visible == false then return false end
	if fam.IsDead and fam:IsDead() then return false end
	local sprite = fam:GetSprite()
	if not sprite then return false end
	local filename = sprite:GetFilename() or ""
	local animation = sprite:GetAnimation() or ""
	return (fam.FrameCount or 0) >= 2 and filename ~= "" and animation ~= ""
end

-- InitSeed -> {fam, air, player, meta}
local PENDING_ORBITALS = {}

local function orbital_matches_adapter(fam, ad)
	if not fam or not ad then return false end
	if ad.familiar_subtype and fam.SubType ~= ad.familiar_subtype then return false end
	return true
end

local function contact_interval_for(bind)
	local ad = bind and (bind.adapter or ORBITAL_BY_KIND[bind.kind])
	if ad and tonumber(ad.hit_interval) then
		return math.max(1, math.floor(tonumber(ad.hit_interval)))
	end
	return math.max(1, math.floor(dbg_num("hit_interval", 10)))
end

local function dist_mul_for(kind)
	local g = dbg_num("orbit_dist_mul", 1)
	local key = "orbit_mul_" .. (kind or "meat")
	local k = dbg_num(key, 1)
	return g * k
end

local function default_layer_for(kind)
	local ad = ORBITAL_BY_KIND[kind]
	if ad and ad.orbit_layer ~= nil then return math.floor(tonumber(ad.orbit_layer) or 0) end
	if kind == "best_bud" then return math.floor(dbg_num("orbit_layer_best_bud", 1)) end
	if kind == "leprosy" then return math.floor(dbg_num("orbit_layer_leprosy", 0)) end
	if kind == "bandage" then return math.floor(dbg_num("orbit_layer_bandage", 0)) end
	if kind == "meat" then return math.floor(dbg_num("orbit_layer_meat", 0)) end
	return 0
end

local function adapter_of(bind, fam)
	if bind and bind.adapter then return bind.adapter end
	if fam and ORBITAL_BY_VARIANT[fam.Variant] then return ORBITAL_BY_VARIANT[fam.Variant] end
	if bind and bind.kind and ORBITAL_BY_KIND[bind.kind] then return ORBITAL_BY_KIND[bind.kind] end
	return nil
end

--- 布局 ring 与引擎 OrbitLayer 拆开：同 ring 内统一分相位
local function resolved_layout_ring(bind, fam)
	if bind and bind.layout_ring then return bind.layout_ring end
	local ad = adapter_of(bind, fam)
	if ad and ad.layout_ring then return ad.layout_ring end
	local layer = tonumber(bind and (bind.active_orbit_layer or bind.orbit_layer)) or 0
	if layer <= 0 then return "inner" end
	if layer == 1 then return "middle" end
	return "outer"
end

local function active_orbit_layer_for(bind, fam)
	local ad = adapter_of(bind, fam)
	if ad and ad.orbit_layer ~= nil then
		return math.floor(tonumber(ad.orbit_layer) or 0)
	end
	if bind and bind.orbit_layer ~= nil and tonumber(bind.orbit_layer) >= 0 then
		return math.floor(tonumber(bind.orbit_layer) or 0)
	end
	return default_layer_for(bind and bind.kind)
end

local function capture_vanilla_render(fam, bind)
	if not fam or not bind then return end
	if bind.synthetic ~= false then
		bind.vanilla_position_offset = Vector(0, 0)
		bind.vanilla_sprite_offset = copy_vec(fam.SpriteOffset) or Vector(0, 0)
		bind.vanilla_sprite_rotation = tonumber(fam.SpriteRotation) or 0
		bind.vanilla_visible = true
		bind.vanilla_color = nil
		bind.vanilla_render_captured = true
		return
	end
	if bind.vanilla_render_captured then return end
	bind.vanilla_position_offset = copy_vec(fam.PositionOffset) or Vector(0, 0)
	bind.vanilla_sprite_offset = copy_vec(fam.SpriteOffset) or Vector(0, 0)
	bind.vanilla_sprite_rotation = tonumber(fam.SpriteRotation) or 0
	bind.vanilla_visible = fam.Visible ~= false
	bind.vanilla_color = fam.Color
	bind.vanilla_render_captured = true
end

local function restore_vanilla_render(fam, bind)
	if not fam or not bind or bind.synthetic ~= false then return end
	if bind.vanilla_position_offset then
		fam.PositionOffset = copy_vec(bind.vanilla_position_offset) or bind.vanilla_position_offset
	end
	if bind.vanilla_sprite_offset then
		fam.SpriteOffset = copy_vec(bind.vanilla_sprite_offset) or bind.vanilla_sprite_offset
	end
	if bind.vanilla_sprite_rotation ~= nil then
		fam.SpriteRotation = bind.vanilla_sprite_rotation
	end
	if bind.vanilla_visible ~= nil then
		fam.Visible = bind.vanilla_visible ~= false
	end
	if bind.vanilla_color then
		fam.Color = bind.vanilla_color
	end
end

--- 接管期视觉高度：只跟 Flight 动态 lift + bias；不改世界轨道半径。
--- vanilla_position_offset 只用于释放恢复。若在此继续相加，会把原版相对玩家腰部的高度
--- 再叠到 Flight 巡航高度上，造成所有真实环绕物统一高一层。
local function air_lift_vector(air)
	if not air then return Vector(0, 0) end
	local po = air.PositionOffset or Vector(0, 0)
	local y = po.Y
	-- 新飞行器偶发尚未写入巡航 PO：用 OffsetZ / 默认巡航高，避免环绕物先贴地再抬升闪一帧
	if math.abs(y) < 0.5 then
		local Air = get_air_mod()
		local z = tonumber(air:GetData()[Air.own_key.."OffsetZ"])
		if z ~= nil then
			y = z
		else
			y = -38 -- 对齐 Item_Air_Flight.AIR_AIM_VIS.base_offset
		end
	end
	return Vector(po.X, y)
end

local function apply_render_offset(fam, bind, air)
	if not fam or not bind or not air then return end
	local ad = adapter_of(bind, fam)
	local mode = (ad and ad.position_offset_mode) or "air_relative"
	if mode ~= "air_relative" and mode ~= "air_centered" then return end
	local bias = dbg_num("orbital_render_y_bias", 0)
	if ad and ad.render_y_bias_aux then
		local ok, Aux = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Aux_Entities_holder")
		if ok and Aux.get_cfg then
			bias = bias + (tonumber(Aux.get_cfg(ad.render_y_bias_aux)) or 0)
		end
	elseif ad and tonumber(ad.render_y_bias) then
		bias = bias + tonumber(ad.render_y_bias)
	end
	local air_po = air_lift_vector(air)
	-- 原版宝宝/环绕物素材中心比中心式 Flight 原点高约 16 screen px。
	-- 依实测 61 PO≈40px 换算进 PO，使攻击/泪弹也继承正确高度；SpriteOffset 不再重复下移。
	-- air_centered（Finger）：ANM2 原点就是可见中心，只继承 Flight lift，SpriteOffset 也必须清零。
	-- air_relative：普通原版宝宝素材的可见中心高于实体原点，继续补偿 16px。
	local centered = mode == "air_centered" or (ad and ad.centered_sprite == true)
	local center_po_y = centered and 0 or (16 * 61 / 40)
	fam.PositionOffset = Vector(air_po.X, air_po.Y + bias + center_po_y)
	local base_so = centered and Vector.Zero or (bind.vanilla_sprite_offset or Vector.Zero)
	fam.SpriteOffset = Vector(base_so.X, base_so.Y)
	-- 供显式开启的 Finger 探针判定本函数写入后是否又被其他回调覆盖；正常逻辑不读取。
	if bind.kind == "finger" then
		fam:GetData()[item.own_key.."last_offset_write"] = {
			frame = Game():GetFrameCount(), mode = mode,
			position_offset = copy_vec(fam.PositionOffset),
			sprite_offset = copy_vec(fam.SpriteOffset),
			air_position_offset = copy_vec(air.PositionOffset),
			center_po_y = center_po_y, bias = bias,
		}
	end
end

--- 轨道目标（与 update_orbital 共用）；绑定时即可算，不必等下一帧 POST。
local function resolve_orbit_target(fam, bind, air, buckets)
	if not fam or not bind or not air then return nil end
	local adapter = bind.adapter or ORBITAL_BY_VARIANT[fam.Variant] or ORBITAL_BY_KIND[bind.kind]
	bind.adapter = adapter
	local target = nil
	if adapter and adapter.custom_target then
		local ok, pos = pcall(adapter.custom_target, fam, bind, air, buckets)
		if ok and pos then target = pos end
	end
	if not target and fam.GetOrbitPosition then
		local ok, pos = pcall(function() return fam:GetOrbitPosition(air.Position) end)
		if ok and pos then
			local layer = tonumber(fam.OrbitLayer)
			if layer and layer >= 0 then
				target = pos
			elseif pos.X ~= 0 or pos.Y ~= 0 then
				target = pos
			end
		end
	end
	if not target then
		local dist = fam.OrbitDistance or bind.orbit_distance or Vector(40, 40)
		local spd = tonumber(fam.OrbitSpeed) or tonumber(bind.orbit_speed) or 0.045
		local ang = (Game():GetFrameCount() * spd)
			+ (tonumber(bind.layout_angle_offset or bind.orbit_angle_offset) or 0)
			+ orbit_phase_freeze_comp(bind)
		target = air.Position + Vector(math.cos(ang) * dist.X, math.sin(ang) * dist.Y)
	end
	return target
end

--- 绑定/layout 后立即钉位置与 PO，避免制造飞行器当帧仍画在玩家槽或贴地闪烁。
--- soft_rebind：只校准 PO，不瞬移 Position（棱镜等装配要平滑）。
local function commit_orbital_pose(fam, bind, air, buckets)
	if not fam or not bind or not air or not auxi.check_all_exists(air) then return end
	local ad = adapter_of(bind, fam)
	local soft = ad and ad.soft_rebind == true
	local target = resolve_orbit_target(fam, bind, air, buckets)
	if target then
		bind.last_target = copy_vec(target)
		if soft then
			bind.last_dist_to_air = fam.Position:Distance(air.Position)
		else
			fam.Position = target
			bind.last_dist_to_air = fam.Position:Distance(air.Position)
		end
	end
	if soft then
		bind.vel = copy_vec(fam.Velocity) or Vector(0, 0)
		bind.needs_snap = false
		bind.settle_frames = 0
		bind.soft_attach_frames = math.max(tonumber(bind.soft_attach_frames) or 0, dbg_num("soft_attach_frames", 36))
	else
		bind.vel = Vector(0, 0)
		fam.Velocity = Vector(0, 0)
		bind.needs_snap = false
	end
	apply_render_offset(fam, bind, air)
	fam.CollisionDamage = 0
end

local function commit_pending_snaps_for_air(air)
	if not air then return end
	for _, fam in ipairs(find_all_bound(air)) do
		local bind = bind_data(fam)
		if bind and bind.needs_snap then
			local ad = adapter_of(bind, fam)
			if ad and ad.soft_rebind then
				bind.needs_snap = false
				bind.settle_frames = 0
				bind.soft_attach_frames = math.max(tonumber(bind.soft_attach_frames) or 0, dbg_num("soft_attach_frames", 36))
				apply_render_offset(fam, bind, air)
			else
				commit_orbital_pose(fam, bind, air, nil)
			end
		end
	end
end

-- air_ptr -> { [ring] = {sig=, epoch=} }
local layout_state = {}

find_all_bound = function(air)
	local out = {}
	local seen = {}
	if not air then return out end
	local air_ptr = GetPtrHash(air)
	for active_id, fam in pairs(ACTIVE_BOUND) do
		local alive = active_familiar_alive(fam)
		local bind = alive and bind_data(fam) or nil
		if not alive or not bind then
			ACTIVE_BOUND[active_id] = nil
		elseif bind.air and GetPtrHash(bind.air) == air_ptr then
			local ptr = GetPtrHash(fam)
			if not seen[ptr] then
				seen[ptr] = true
				out[#out + 1] = fam
			end
		end
	end
	return out
end

local function sorted_profile_orbitals()
	if SORTED_PROFILE_ORBITALS then return SORTED_PROFILE_ORBITALS end
	local rows = {}
	for id, adapter in pairs(ORBITAL_BY_COLLECTIBLE) do
		rows[#rows + 1] = {id = tonumber(id) or 0, adapter = adapter}
	end
	table.sort(rows, function(a, b) return a.id < b.id end)
	SORTED_PROFILE_ORBITALS = rows
	return rows
end

local function layout_less(a, b)
	local ba, bb = bind_data(a), bind_data(b)
	local ada, adb = adapter_of(ba, a), adapter_of(bb, b)
	local pa = (ada and tonumber(ada.layout_priority)) or 100
	local pb = (adb and tonumber(adb.layout_priority)) or 100
	if pa ~= pb then return pa < pb end
	local sa = tonumber(ba and ba.source_id) or 0
	local sb = tonumber(bb and bb.source_id) or 0
	if sa ~= sb then return sa < sb end
	local ka = tostring(ba and ba.kind or "")
	local kb = tostring(bb and bb.kind or "")
	if ka ~= kb then return ka < kb end
	local la = tonumber(ba and (ba.local_slot or ba.slot)) or 0
	local lb = tonumber(bb and (bb.local_slot or bb.slot)) or 0
	if la ~= lb then return la < lb end
	return (tonumber(a.InitSeed) or 0) < (tonumber(b.InitSeed) or 0)
end

--- 按 Flight + layout_ring 全局均分相位；签名不变不重分配
local function rebuild_orbit_layout(air)
	if not air then return end
	local air_ptr = GetPtrHash(air)
	local by_ring = {}
	for _, fam in ipairs(find_all_bound(air)) do
		local bind = bind_data(fam)
		if bind then
			local ad = adapter_of(bind, fam)
			if not (ad and ad.skip_layout) then
				local ring = resolved_layout_ring(bind, fam)
				bind.layout_ring = ring
				by_ring[ring] = by_ring[ring] or {}
				by_ring[ring][#by_ring[ring] + 1] = fam
			end
		end
	end
	layout_state[air_ptr] = layout_state[air_ptr] or {}
	local st = layout_state[air_ptr]
	local rings = {}
	for ring in pairs(by_ring) do rings[#rings + 1] = ring end
	table.sort(rings)
	for _, ring in ipairs(rings) do
		local list = by_ring[ring]
		table.sort(list, layout_less)
		local parts = {}
		for i, fam in ipairs(list) do
			local bind = bind_data(fam)
			parts[#parts + 1] = tostring(fam.InitSeed or GetPtrHash(fam))
		end
		table.sort(parts)
		local sig = table.concat(parts, "|")
		local prev = st[ring]
		if not prev or prev.sig ~= sig then
			st[ring] = {sig = sig, epoch = (prev and (prev.epoch or 0) or 0) + 1}
			local n = #list
			for i, fam in ipairs(list) do
				local bind = bind_data(fam)
				local ang = (n > 0) and (((i - 1) * (2 * math.pi)) / n) or 0
				bind.layout_angle_offset = ang
				bind.orbit_angle_offset = ang
				bind.layout_epoch = st[ring].epoch
				-- 相位重分配：禁止弹簧跨半圈飞远，硬钉若干帧（soft_rebind 除外）
				local ad = adapter_of(bind, fam)
				if ad and ad.soft_rebind then
					bind.needs_snap = false
					bind.settle_frames = 0
					bind.soft_attach_frames = math.max(tonumber(bind.soft_attach_frames) or 0, dbg_num("soft_attach_frames", 36))
				else
					bind.needs_snap = true
					bind.settle_frames = math.max(tonumber(bind.settle_frames) or 0, 6)
				end
				if fam.OrbitAngleOffset ~= nil then
					fam.OrbitAngleOffset = ang + (tonumber(bind.orbit_phase_freeze_comp) or 0)
				end
			end
		else
			for _, fam in ipairs(list) do
				local bind = bind_data(fam)
				local ang = bind.layout_angle_offset
				if ang ~= nil then
					bind.orbit_angle_offset = ang
					if fam.OrbitAngleOffset ~= nil then
						fam.OrbitAngleOffset = ang + (tonumber(bind.orbit_phase_freeze_comp) or 0)
					end
				end
			end
		end
	end
end

--- 绑定后挂入原版 orbit 系统；距离 = 层表/原实体椭圆 × 倍率（绝不用 :Length()）
--- vanilla_orbit_* 仅释放恢复；接管期用 active_orbit_* + layout_angle_offset
local function apply_orbit_attachment(fam, bind)
	if not fam or not bind then return end
	local kind = bind.kind or "meat"
	local ad = adapter_of(bind, fam)
	bind.adapter = ad or bind.adapter
	-- Finger 等定向附件不是轨道物。skip_layout 只跳布局，不会阻止 AddToOrbit；
	-- 必须显式脱离，否则原版 Orbit 每帧拉向玩家，custom_drive 又拉向 Flight。
	if ad and ad.detached_follow == true then
		if fam.RemoveFromOrbit then fam:RemoveFromOrbit() end
		if fam.RemoveFromFollowers then fam:RemoveFromFollowers() end
		bind.active_orbit_layer = -1
		bind.orbit_layer = -1
		return
	end
	bind.layout_ring = resolved_layout_ring(bind, fam)
	local layer = active_orbit_layer_for(bind, fam)
	layer = math.floor(tonumber(layer) or 0)
	bind.active_orbit_layer = layer
	bind.orbit_layer = layer
	if fam.AddToOrbit then
		pcall(function() fam:AddToOrbit(layer) end)
	end
	local resolved = fam.OrbitLayer
	if resolved == nil or tonumber(resolved) < 0 then
		resolved = layer
	end
	bind.active_orbit_layer = resolved
	bind.orbit_layer = resolved

	local base = nil
	if ad and ad.orbit_params_aux == "vengeful" then
		local ok, Aux = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Aux_Entities_holder")
		if ok and Aux.get_cfg then
			local r = tonumber(Aux.get_cfg("vengeful_orbit_r")) or 40
			base = Vector(r, r)
		end
	elseif ad and ad.orbit_distance then
		base = copy_vec(ad.orbit_distance)
	elseif bind.vanilla_orbit_distance then
		base = copy_vec(bind.vanilla_orbit_distance)
	elseif EntityFamiliar.GetOrbitDistance then
		local ok, d = pcall(function() return EntityFamiliar.GetOrbitDistance(resolved) end)
		if ok and d then base = d end
	end
	if not base and fam.OrbitDistance then
		base = fam.OrbitDistance
	end
	if base then
		bind.base_orbit_distance = copy_vec(base)
		local mul = dist_mul_for(kind)
		fam.OrbitDistance = Vector(base.X * mul, base.Y * mul)
		bind.orbit_distance = copy_vec(fam.OrbitDistance)
		bind.active_orbit_distance = copy_vec(fam.OrbitDistance)
	end

	if bind.vanilla_orbit_speed ~= nil then
		fam.OrbitSpeed = bind.vanilla_orbit_speed
	elseif ad and ad.orbit_params_aux == "vengeful" then
		local ok, Aux = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Aux_Entities_holder")
		local omega = 5
		if ok and Aux.get_cfg then
			omega = tonumber(Aux.get_cfg("vengeful_omega")) or 5
		end
		fam.OrbitSpeed = omega * math.pi / 180
	elseif ad and ad.orbit_speed ~= nil then
		fam.OrbitSpeed = tonumber(ad.orbit_speed)
	end
	bind.orbit_speed = fam.OrbitSpeed

	local ang = bind.layout_angle_offset
	if ang == nil then ang = bind.orbit_angle_offset end
	if ang ~= nil then
		-- layout 相位 + 时停相位补偿（GetOrbitPosition 仍吃 FrameCount）
		fam.OrbitAngleOffset = ang + (tonumber(bind.orbit_phase_freeze_comp) or 0)
		bind.orbit_angle_offset = ang
	end
end

--- GetOrbitPosition ≈ f(FrameCount)*OrbitSpeed + OrbitAngleOffset。
--- 蓝图 time_stop 时 FrameCount 仍前进；累积负补偿冻结槽位，避免解冻/解除时相位大跳。
orbit_phase_freeze_comp = function(bind)
	return tonumber(bind and bind.orbit_phase_freeze_comp) or 0
end

local function apply_orbit_angle_with_freeze(fam, bind, base_ang)
	if not fam or not bind then return end
	local base = tonumber(base_ang)
	if base == nil then base = tonumber(bind.layout_angle_offset) end
	if base == nil then base = tonumber(bind.orbit_angle_offset) end
	if base == nil then base = tonumber(bind.vanilla_orbit_angle_offset) end
	if base == nil then return end
	fam.OrbitAngleOffset = base + orbit_phase_freeze_comp(bind)
end

local function accumulate_orbit_phase_freeze(fam, bind)
	if not fam or not bind then return end
	local spd = tonumber(fam.OrbitSpeed)
		or tonumber(bind.orbit_speed)
		or tonumber(bind.vanilla_orbit_speed)
		or 0
	if spd == 0 then return end
	bind.orbit_phase_freeze_comp = orbit_phase_freeze_comp(bind) - spd
	apply_orbit_angle_with_freeze(fam, bind)
end

--- 每帧刷新倍率/合成层，使 ImGui 滑条即时生效
local function refresh_orbit_runtime(fam, bind)
	if not fam or not bind then return end
	local ad = adapter_of(bind, fam)
	if ad and ad.detached_follow == true then
		-- 原版 AI 可能重新挂回玩家编队；AI 后每帧重申脱离。
		if fam.RemoveFromOrbit then fam:RemoveFromOrbit() end
		if fam.RemoveFromFollowers then fam:RemoveFromFollowers() end
		bind.active_orbit_layer = -1
		bind.orbit_layer = -1
		return
	end
	local kind = bind.kind or "meat"
	local layer = active_orbit_layer_for(bind, fam)
	bind.active_orbit_layer = layer
	if tonumber(fam.OrbitLayer) ~= layer and fam.AddToOrbit then
		pcall(function() fam:AddToOrbit(layer) end)
		bind.orbit_layer = fam.OrbitLayer or layer
		bind.active_orbit_layer = bind.orbit_layer
		if ad and ad.orbit_distance then
			bind.base_orbit_distance = copy_vec(ad.orbit_distance)
		elseif bind.vanilla_orbit_distance then
			bind.base_orbit_distance = copy_vec(bind.vanilla_orbit_distance)
		elseif EntityFamiliar.GetOrbitDistance then
			local ok, d = pcall(function() return EntityFamiliar.GetOrbitDistance(layer) end)
			if ok and d then bind.base_orbit_distance = copy_vec(d) end
		end
	end
	if not bind.base_orbit_distance then
		if ad and ad.orbit_params_aux == "vengeful" then
			local ok, Aux = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Aux_Entities_holder")
			if ok and Aux.get_cfg then
				local r = tonumber(Aux.get_cfg("vengeful_orbit_r")) or 40
				bind.base_orbit_distance = Vector(r, r)
			end
		elseif ad and ad.orbit_distance then
			bind.base_orbit_distance = copy_vec(ad.orbit_distance)
		elseif bind.vanilla_orbit_distance then
			bind.base_orbit_distance = copy_vec(bind.vanilla_orbit_distance)
		elseif fam.OrbitDistance then
			bind.base_orbit_distance = copy_vec(fam.OrbitDistance)
		end
	end
	if bind.base_orbit_distance then
		local mul = dist_mul_for(kind)
		fam.OrbitDistance = Vector(bind.base_orbit_distance.X * mul, bind.base_orbit_distance.Y * mul)
		bind.active_orbit_distance = copy_vec(fam.OrbitDistance)
	end
	local ang = bind.layout_angle_offset
	if ang == nil then ang = bind.orbit_angle_offset end
	if ang ~= nil then
		bind.orbit_angle_offset = ang
		apply_orbit_angle_with_freeze(fam, bind, ang)
	end
end

local function player_key(player)
	if not player then return "0" end
	return tostring(player.InitSeed or GetPtrHash(player))
end

local function exclusive_store()
	save.elses = save.elses or {}
	save.elses.FlightOrbitalExclusive = save.elses.FlightOrbitalExclusive or {}
	return save.elses.FlightOrbitalExclusive
end

local function craft_count(profile_or_rec, id)
	if not profile_or_rec then return 0 end
	if profile_or_rec.counts then
		return tonumber(profile_or_rec.counts[id]) or 0
	end
	if profile_or_rec.ingredients then
		return (CraftProfile.counts_from_ingredients(profile_or_rec.ingredients) or {})[id] or 0
	end
	return 0
end

local function air_uid(air)
	local bp = get_blueprint()
	return air and air:GetData()[bp.own_key.."craft_uid"]
end

local function uid_str(uid)
	if uid == nil then return "" end
	return tostring(uid)
end

--- active / degraded / inactive（禁止再当单一 boolean）
function item.get_air_combat_state(air, player)
	if not air or not auxi.check_all_exists(air) then return "inactive" end
	local Air = get_air_mod()
	local d = air:GetData()
	if d[Air.own_key.."Crash"] then return "inactive" end
	if Air.is_standby and Air.is_standby(air) then return "inactive" end
	player = player or auxi.check_spawner_player(air)
	local bp = get_blueprint()
	local uid = d[bp.own_key.."craft_uid"]
	if uid and player and bp.is_craft_broken and bp.is_craft_broken(player, uid) then
		return "degraded"
	end
	return "active"
end

local function air_is_chasing(air)
	local Air = get_air_mod()
	local d = air:GetData()
	if Air.is_standby and Air.is_standby(air) then return false end
	if d[Air.own_key.."FormationMode"] == (Air.FORMATION_GUARD or 1) then return false end
	if d[Air.own_key.."FireControlMode"] == (Air.FIRE_FORCE or 1) then return false end
	return true
end

bind_data = function(fam)
	return fam and fam:GetData()[item.own_key..BIND_KEY]
end

-- 供同批 adapter 的定向回调读取；只读，禁止外部直接改 bind。
function item.get_bind(fam)
	return bind_data(fam)
end

local function set_bind(fam, bind)
	fam:GetData()[item.own_key..BIND_KEY] = bind
	if bind then track_active(fam) else untrack_active(fam) end
	Familiar_Control_Selector.invalidate(fam)
end

local function pending_craft_orbital(fam)
	return fam and fam.InitSeed and PENDING_ORBITALS[fam.InitSeed] ~= nil
end

local function controlled_by_orbital(fam)
	if not fam or not is_orbital_variant(fam.Variant) then return false end
	if pending_craft_orbital(fam) then return false end
	local bind = bind_data(fam)
	if not bind then return false end
	local ad = adapter_of(bind, fam)
	if ad and not orbital_matches_adapter(fam, ad) then return false end
	if not familiar_vanilla_ready(fam) then return false end
	-- 飞回态：无 air，仍占控制权直到靠近玩家轨道槽
	if bind.returning then return true end
	-- 追敌等：解除劫持，交还原版 AI（选择器不申请）
	if bind.vanilla_free then return false end
	return bind.air ~= nil
end

--- 仍绑定 Flight 时需要 tick（含 vanilla_free 的进入/退出）
local function bound_orbital_needs_tick(fam)
	if not fam or not is_orbital_variant(fam.Variant) then return false end
	local bind = bind_data(fam)
	if not bind then return false end
	if bind.returning then return true end
	return bind.air ~= nil
end

Familiar_Control_Selector.register(item.CONTROLLER, 160, controlled_by_orbital)

local function resolve_base_dps(air, bind)
	if bind and bind.base_dps_fn then
		local ok, v = pcall(bind.base_dps_fn, air, bind)
		if ok and tonumber(v) then return tonumber(v) end
	end
	if bind and tonumber(bind.base_dps) then return tonumber(bind.base_dps) end
	local ad = bind and ORBITAL_BY_KIND[bind.kind]
	if ad and ad.base_dps_fn then
		local ok, v = pcall(ad.base_dps_fn, air, bind)
		if ok and tonumber(v) then return tonumber(v) end
	end
	if ad and tonumber(ad.base_dps) then return tonumber(ad.base_dps) end
	return BASE_DPS.meat
end

local function group_mul(air, group, n)
	-- solo：尖肋骨等单件接触，不吃 √n 组伤折扣
	local mul
	if group == "solo" then
		mul = 1
	else
		local base = (group == "high") and dbg_num("high_contact_mul", 0.30) or dbg_num("contact_mul", 0.45)
		n = math.max(1, tonumber(n) or 1)
		mul = base / math.sqrt(n)
	end
	if air_is_chasing(air) then
		mul = mul * dbg_num("chase_discount", 0.65)
	end
	return mul
end

local function state_mul(state)
	if state == "degraded" then return 0.5 end
	if state == "active" then return 1 end
	return 0
end

function item.contact_damage_per_hit(air, bind, group_n, state)
	local interval = contact_interval_for(bind)
	local base_dps = resolve_base_dps(air, bind)
	local gmul = group_mul(air, bind and bind.group or "normal", group_n)
	local smul = state_mul(state)
	local per_hit = base_dps * (interval / 30) * gmul * smul
	return per_hit, base_dps * gmul * smul, interval
end

--- 独占：字符串 UID 稳定排序；Crash 排除；degraded 保留
function item.resolve_exclusive_owner(player, kind, candidates)
	if not player or not kind then return nil end
	local store = exclusive_store()
	local pk = player_key(player).."|"..kind
	local prev = store[pk]
	table.sort(candidates, function(a, b)
		local au, bu = uid_str(a.uid), uid_str(b.uid)
		if au ~= bu then return au < bu end
		return (a.air and a.air.InitSeed or 0) < (b.air and b.air.InitSeed or 0)
	end)
	local valid = {}
	for _, c in ipairs(candidates) do
		local units = tonumber(c.units) or 0
		if units > 0 and c.air and auxi.check_all_exists(c.air) then
			local st = item.get_air_combat_state(c.air, player)
			if st ~= "inactive" then
				valid[#valid + 1] = c
			end
		end
	end
	if #valid == 0 then
		store[pk] = nil
		return nil
	end
	if prev ~= nil then
		local prev_s = uid_str(prev)
		for _, c in ipairs(valid) do
			if uid_str(c.uid) == prev_s then
				return c.uid
			end
		end
	end
	store[pk] = valid[1].uid
	return store[pk]
end

local MEAT_VARIANTS = {
	[FamiliarVariant.CUBE_OF_MEAT_1 or 44] = true,
	[FamiliarVariant.CUBE_OF_MEAT_2 or 45] = true,
	[FamiliarVariant.CUBE_OF_MEAT_3 or 46] = true,
	[FamiliarVariant.CUBE_OF_MEAT_4 or 47] = true,
}
local BANDAGE_VARIANTS = {
	[FamiliarVariant.BALL_OF_BANDAGES_1 or 69] = true,
	[FamiliarVariant.BALL_OF_BANDAGES_2 or 70] = true,
	[FamiliarVariant.BALL_OF_BANDAGES_3 or 71] = true,
	[FamiliarVariant.BALL_OF_BANDAGES_4 or 72] = true,
}

--- ledger：resolved_units 仍用配方合计（独占/形态）；spawn/claim 看 source
function item.meat_bandage_ledger(player, profile, id)
	local profile_units = craft_count(profile, id)
	local src = CraftProfile.source_bucket_for(profile, id)
	local true_items, temp_effects, peeler_uses = 0, 0, 0
	if player then
		if player.GetCollectibleNum then
			true_items = player:GetCollectibleNum(id, true, true) or 0
		end
		if player.GetEffects then
			temp_effects = player:GetEffects():GetCollectibleEffectNum(id) or 0
		end
		if id == MEAT_ID and player.GetPotatoPeelerUses then
			peeler_uses = player:GetPotatoPeelerUses() or 0
		end
	end
	local real_units = src.real
	local synthetic_units = src.audit + src.prototype
	local note = "profile"
	if real_units > 0 and synthetic_units > 0 then
		note = "mixed_source"
	elseif real_units > 0 then
		note = "real_claim"
	elseif synthetic_units > 0 then
		note = "synthetic_spawn"
	end
	return {
		profile_units = profile_units,
		real_units = real_units,
		synthetic_units = synthetic_units,
		true_items = true_items,
		temp_effects = temp_effects,
		peeler_uses = peeler_uses,
		resolved_units = profile_units,
		note = note,
	}
end

function item.meat_bandage_units(player, profile, id)
	return item.meat_bandage_ledger(player, profile, id).resolved_units
end

-- 前向声明：queue / promote 在定义点之前会调用 bind_existing_orbital；
-- bind / release 也会调 clear_pending_orbital（禁止 local function 写在调用点之后，会解析成 _G）。
local bind_existing_orbital
local clear_pending_orbital
local release_fam

clear_pending_orbital = function(fam)
	if fam and fam.InitSeed then
		PENDING_ORBITALS[fam.InitSeed] = nil
	end
end

local function queue_orbital_bind(fam, air, player, meta)
	if not fam then return nil end
	local seed = fam.InitSeed
	local frame = Game():GetFrameCount()
	local row = PENDING_ORBITALS[seed]
	if not row then
		PENDING_ORBITALS[seed] = {
			fam = fam, air = air, player = player, meta = meta,
			queued_frame = frame,
		}
		if fam.Variant == (FamiliarVariant.WISP or 206) then
			venge_probe_trace("queue_pending", fam, {
				kind_meta = meta and meta.kind,
				queued_frame = frame,
			})
		end
	else
		row.fam = fam
		row.air = air
		row.player = player
		row.meta = meta
	end
	return fam
end

local function orbital_promote_ready(fam, row)
	if not fam or not row then return false end
	if not familiar_vanilla_ready(fam) then return false end
	local qf = tonumber(row.queued_frame) or Game():GetFrameCount()
	return Game():GetFrameCount() - qf >= ORBITAL_INIT_MIN_FRAMES
end

local function promote_pending_orbitals()
	for seed, row in pairs(PENDING_ORBITALS) do
		local fam = row.fam
		if not fam or not fam:Exists() then
			PENDING_ORBITALS[seed] = nil
		elseif orbital_promote_ready(fam, row) then
			bind_existing_orbital(fam, row.air, row.player, row.meta)
		end
	end
end

local function spawn_orbital(variant, air, player, meta)
	meta = meta or {}
	local subtype = tonumber(meta.spawn_subtype) or 0
	local fam = Isaac.Spawn(
		EntityType.ENTITY_FAMILIAR, variant, subtype,
		air.Position, Vector.Zero, player
	)
	fam = fam and fam:ToFamiliar()
	if not fam then return nil end
	fam.Player = player
	if meta.synthetic == nil then meta.synthetic = true end
	meta.adapter = meta.adapter or ORBITAL_BY_VARIANT[variant]
	local ad = meta.adapter or ORBITAL_BY_VARIANT[variant]
	if not (ad and ad.preserve_vanilla_appear) then
		if fam.ClearEntityFlags and EntityFlag.FLAG_APPEAR then
			fam:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
		end
	end
	if variant == (FamiliarVariant.WISP or 206) then
		venge_probe_trace("spawn_orbital", fam, {
			synthetic = meta.synthetic,
			subtype = subtype,
			cleared_appear = not (ad and ad.preserve_vanilla_appear),
		})
	end
	return queue_orbital_bind(fam, air, player, meta)
end

bind_existing_orbital = function(fam, air, player, meta)
	if not fam then return nil end
	if not familiar_vanilla_ready(fam) then
		return queue_orbital_bind(fam, air, player, meta)
	end
	local seed = fam.InitSeed
	local row = PENDING_ORBITALS[seed]
	if not row then
		queue_orbital_bind(fam, air, player, meta)
		return fam
	end
	if not orbital_promote_ready(fam, row) then
		row.air = air
		row.player = player
		row.meta = meta
		return fam
	end
	clear_pending_orbital(fam)
	fam.Player = player or fam.Player
	local orbit_layer = fam.OrbitLayer
	local orbit_dist = copy_vec(fam.OrbitDistance)
	local orbit_speed = fam.OrbitSpeed
	local orbit_ang = fam.OrbitAngleOffset
	local kind = meta.kind or "meat"
	local layer = meta.orbit_layer
	if layer == nil or tonumber(layer) < 0 then
		layer = default_layer_for(kind)
	end
	local bind = {
		air = air,
		air_seed = air.InitSeed,
		craft_uid = air_uid(air),
		source_id = meta.source_id,
		kind = kind,
		slot = meta.slot or 0,
		local_slot = meta.local_slot or meta.slot or 0,
		layout_ring = meta.layout_ring,
		orbit_layer = layer,
		orbit_angle_offset = meta.orbit_angle_offset,
		group = meta.group or "normal",
		base_dps = meta.base_dps or BASE_DPS.meat,
		base_dps_fn = meta.base_dps_fn,
		block = meta.block ~= false,
		reflect = meta.reflect == true,
		-- 认领真体默认 false；仅分裂体等显式 synthetic=true
		synthetic = meta.synthetic == true,
		adapter = meta.adapter or ORBITAL_BY_VARIANT[fam.Variant],
		tinytoma_hp = meta.tinytoma_hp,
		vanilla_orbit_layer = orbit_layer,
		vanilla_orbit_distance = orbit_dist,
		vanilla_orbit_speed = orbit_speed,
		vanilla_orbit_angle_offset = orbit_ang,
		tear_cd = 0,
		hit_gate = {},
		vel = Vector(0, 0),
		needs_snap = true,
		settle_frames = 10,
	}
	local ad0 = bind.adapter
	if ad0 and ad0.soft_rebind then
		bind.needs_snap = false
		bind.settle_frames = 0
		bind.soft_attach_frames = dbg_num("soft_attach_frames", 36)
		bind.vel = copy_vec(fam.Velocity) or Vector(0, 0)
	end
	set_bind(fam, bind)
	fam:GetData()[item.own_key.."last_bind_trace"] = {
		frame = Game():GetFrameCount(),
		reason = meta.trace_reason or "bind_existing",
		kind = kind,
		air_seed = air and air.InitSeed,
		units = meta.trace_units,
		want_n = meta.trace_want_n,
	}
	capture_vanilla_render(fam, bind)
	if fam.RemoveFromFollowers then fam:RemoveFromFollowers() end
	apply_orbit_attachment(fam, bind)
	fam.CollisionDamage = 0
	commit_orbital_pose(fam, bind, air, nil)
	if ad0 and ad0.on_bind then
		pcall(ad0.on_bind, fam, bind, air, player)
	end
	if not (ad0 and ad0.soft_rebind) then
		bind.needs_snap = true
		bind.settle_frames = 10
	end
	rebuild_orbit_layout(air)
	commit_pending_snaps_for_air(air)
	if fam.Variant == (FamiliarVariant.WISP or 206) then
		venge_probe_trace("bind_existing", fam, {
			kind = kind,
			synthetic = bind.synthetic,
			reason = meta.trace_reason,
		})
	end
	return fam
end

local function find_claimable_vanilla(player, air, variant_set, kind)
	local out = {}
	if not player or not air then return out end
	local air_ptr = GetPtrHash(air)
	for variant in pairs(variant_set) do
		for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, variant, -1, false, false)) do
			local fam = ent:ToFamiliar()
			if fam and fam.Player and auxi.check_for_the_same(fam.Player, player) then
				local bind = bind_data(fam)
				if not bind then
					out[#out + 1] = fam
				elseif bind.kind == kind and bind.synthetic == false then
					if bind.air and GetPtrHash(bind.air) == air_ptr then
						out[#out + 1] = fam
					end
				end
			end
		end
	end
	return out
end

local function desired_meat_variant(units)
	if units >= 3 then return nil, "unsupported" end
	if units >= 2 then return FamiliarVariant.CUBE_OF_MEAT_2 or 45, nil end
	if units >= 1 then return FamiliarVariant.CUBE_OF_MEAT_1 or 44, nil end
	return nil, nil
end

local function desired_bandage_variant(units)
	if units >= 3 then return nil, "unsupported" end
	if units >= 2 then return FamiliarVariant.BALL_OF_BANDAGES_2 or 70, nil end
	if units >= 1 then return FamiliarVariant.BALL_OF_BANDAGES_1 or 69, nil end
	return nil, nil
end

local function find_bound(air, kind)
	local out = {}
	local seen = {}
	local air_ptr = GetPtrHash(air)
	for active_id, fam in pairs(ACTIVE_BOUND) do
		local alive = active_familiar_alive(fam)
		local bind = alive and bind_data(fam) or nil
		if not alive or not bind then
			ACTIVE_BOUND[active_id] = nil
		elseif bind.air and GetPtrHash(bind.air) == air_ptr and bind.kind == kind then
			-- 同一实体可能被引擎以不同 userdata wrapper 访问；弱键表会同时保留这些 wrapper。
			-- 配额必须按实体指针去重，否则单个环绕物会被误判为 excess，周期性释放/重绑。
			local ptr = GetPtrHash(fam)
			if not seen[ptr] then
				seen[ptr] = true
				out[#out + 1] = fam
			end
		end
	end
	return out
end

local function pending_row_kind(row, fam)
	if not row then return nil end
	local meta = row.meta or {}
	if meta.kind then return meta.kind end
	local ad = meta.adapter or (fam and ORBITAL_BY_VARIANT[fam.Variant])
	return ad and ad.kind
end

--- 已绑定 + init 待绑（pending）同属该 Flight 份额；ensure 配额必须计入 pending，否则会重复 spawn。
local function find_reserved_for_air(air, kind)
	local out = find_bound(air, kind)
	local seen = {}
	for _, fam in ipairs(out) do
		seen[GetPtrHash(fam)] = true
	end
	if not air then return out end
	local air_ptr = GetPtrHash(air)
	for _, row in pairs(PENDING_ORBITALS) do
		local fam = row.fam
		if fam and fam:Exists() and row.air and GetPtrHash(row.air) == air_ptr then
			if pending_row_kind(row, fam) == kind then
				local ptr = GetPtrHash(fam)
				if not seen[ptr] then
					seen[ptr] = true
					out[#out + 1] = fam
				end
			end
		end
	end
	return out
end

--- 释放已绑定或仅 pending 的库存环绕物（合成 spawn 直接 Remove；认领真体仅解绑/清 pending）。
local function release_reserved_orbital(fam, opts)
	if not fam then return end
	opts = opts or {}
	local row = fam.InitSeed and PENDING_ORBITALS[fam.InitSeed] or nil
	clear_pending_orbital(fam)
	if bind_data(fam) then
		release_fam(fam, opts)
		return
	end
	local synthetic = true
	if row and row.meta and row.meta.synthetic == false then
		synthetic = false
	end
	if synthetic and fam:Exists() then
		venge_probe_trace("release_remove", fam, {reason = opts.reason or "reserved", pending_only = true})
		fam:Remove()
	end
end

local function restore_vanilla_orbit(fam, bind)
	if not fam then return end
	local player = (bind and bind.player) or fam.Player
	local layer = bind and bind.vanilla_orbit_layer
	if layer == nil or tonumber(layer) < 0 then layer = 0 end
	if fam.AddToOrbit then
		pcall(function() fam:AddToOrbit(layer) end)
	end
	if bind and bind.vanilla_orbit_distance ~= nil then
		fam.OrbitDistance = copy_vec(bind.vanilla_orbit_distance) or bind.vanilla_orbit_distance
	end
	if bind and bind.vanilla_orbit_speed ~= nil then
		fam.OrbitSpeed = bind.vanilla_orbit_speed
	end
	if bind and bind.vanilla_orbit_angle_offset ~= nil then
		fam.OrbitAngleOffset = bind.vanilla_orbit_angle_offset + orbit_phase_freeze_comp(bind)
	end
	restore_vanilla_render(fam, bind)
	if player then fam.Player = player end
end

--- 飞回结束：交回原版 orbit AI（此时已靠近槽位，避免速度大跳）
local function finalize_orbital_return(fam, bind)
	if not fam then return end
	restore_vanilla_orbit(fam, bind)
	set_bind(fam, nil)
end

--- 预备玩家轨道参数，供 GetOrbitPosition(player) 取飞回目标；仍由本模块写 Velocity
local function prepare_return_orbit_target(fam, bind)
	if not fam or not bind or bind.return_orbit_ready then return end
	local layer = bind.vanilla_orbit_layer
	if layer == nil or tonumber(layer) < 0 then layer = 0 end
	if fam.AddToOrbit then
		pcall(function() fam:AddToOrbit(layer) end)
	end
	if bind.vanilla_orbit_distance ~= nil then
		fam.OrbitDistance = copy_vec(bind.vanilla_orbit_distance) or bind.vanilla_orbit_distance
	end
	if bind.vanilla_orbit_speed ~= nil then
		fam.OrbitSpeed = bind.vanilla_orbit_speed
	end
	if bind.vanilla_orbit_angle_offset ~= nil then
		fam.OrbitAngleOffset = bind.vanilla_orbit_angle_offset + orbit_phase_freeze_comp(bind)
	end
	bind.return_orbit_ready = true
end

local function player_orbit_target(fam, player)
	if not fam or not player then return nil end
	if fam.GetOrbitPosition then
		local ok, pos = pcall(function() return fam:GetOrbitPosition(player.Position) end)
		if ok and pos then
			local layer = tonumber(fam.OrbitLayer)
			if layer and layer >= 0 then return pos end
			if pos.X ~= 0 or pos.Y ~= 0 then return pos end
		end
	end
	return player.Position
end

--- 对照 My Emblem drive_to_position：限速软驱，继承当前速度，禁止一帧拉满
local function drive_orbital_return(fam, bind, target)
	if not fam or not target then return end
	local delta = target - fam.Position
	local dist = delta:Length()
	local vel = bind.vel or fam.Velocity or Vector(0, 0)
	local current_speed = vel:Length()
	local min_spd = dbg_num("return_drive_min_speed", 10)
	local margin = dbg_num("return_drive_speed_margin", 12)
	local blend = dbg_num("return_drive_blend", 0.55)
	if dist > 0.1 then
		local speed = math.max(min_spd, math.max(current_speed, dist * 0.35))
		speed = math.min(speed, current_speed + margin)
		local desired = delta:Normalized() * speed
		vel = vel * (1 - blend) + desired * blend
	else
		vel = vel * 0.3
	end
	bind.vel = vel
	fam.Velocity = vel
end

local function update_returning_orbital(fam, bind)
	if not fam or not bind or not bind.returning then return end
	if auxi.is_time_stopped() then
		accumulate_orbit_phase_freeze(fam, bind)
		bind.vel = Vector(0, 0)
		fam.Velocity = Vector(0, 0)
		return
	end
	local player = bind.player or fam.Player
	if not player or not player:Exists() then
		finalize_orbital_return(fam, bind)
		return
	end
	fam.Player = player
	prepare_return_orbit_target(fam, bind)
	local target = player_orbit_target(fam, player)
	if not target then
		finalize_orbital_return(fam, bind)
		return
	end
	local dist = fam.Position:Distance(target)
	if bind.return_start_dist == nil then
		bind.return_start_dist = math.max(dist, 1)
	end
	local join = math.max(
		dbg_num("return_join_min_distance", 28),
		bind.return_start_dist * dbg_num("return_join_ratio", 0.2)
	)
	if dist <= join then
		finalize_orbital_return(fam, bind)
		return
	end
	drive_orbital_return(fam, bind, target)
	fam.CollisionDamage = 0
	local ad = adapter_of(bind, fam)
	if ad and ad.update then
		pcall(ad.update, fam, bind, nil, nil, "returning")
	end
end

--- 真实环绕物：进入飞回态，继续占用 craft_orbital 控制权直到靠近玩家槽位
local function begin_orbital_flyback(fam, bind)
	if not fam or not bind then return end
	local ad = adapter_of(bind, fam)
	if ad and ad.release then
		pcall(ad.release, fam, bind, "flyback")
	end
	local player = fam.Player or bind.player
	local seed_vel = bind.vel or fam.Velocity or Vector(0, 0)
	restore_vanilla_render(fam, bind)
	local return_bind = {
		returning = true,
		player = player,
		kind = bind.kind,
		synthetic = false,
		vanilla_orbit_layer = bind.vanilla_orbit_layer,
		vanilla_orbit_distance = bind.vanilla_orbit_distance,
		vanilla_orbit_speed = bind.vanilla_orbit_speed,
		vanilla_orbit_angle_offset = bind.vanilla_orbit_angle_offset,
		vanilla_position_offset = bind.vanilla_position_offset,
		vanilla_sprite_offset = bind.vanilla_sprite_offset,
		vanilla_sprite_rotation = bind.vanilla_sprite_rotation,
		vanilla_visible = bind.vanilla_visible,
		vanilla_color = bind.vanilla_color,
		vanilla_render_captured = bind.vanilla_render_captured,
		orbit_phase_freeze_comp = bind.orbit_phase_freeze_comp,
		adapter = bind.adapter,
		vel = copy_vec(seed_vel) or Vector(0, 0),
		return_start_dist = nil,
		return_orbit_ready = false,
	}
	set_bind(fam, return_bind)
	fam.CollisionDamage = 0
end

release_fam = function(fam, opts)
	if not fam then return end
	opts = opts or {}
	clear_pending_orbital(fam)
	local bind = bind_data(fam)
	local fd = fam:GetData()
	fd[item.own_key.."last_release_trace"] = {
		frame = Game():GetFrameCount(),
		reason = opts.reason or "unspecified",
		kind = bind and bind.kind,
		air_seed = bind and bind.air_seed,
		units = opts.units,
		want_n = opts.want_n,
		synthetic = bind and bind.synthetic,
	}
	if bind and bind.returning then
		if opts.immediate then
			finalize_orbital_return(fam, bind)
		end
		return
	end
	local synthetic = not bind or bind.synthetic == true
	-- 有 vanilla_orbit_* 的视为真体认领，即使旧 bug 把 synthetic 标成 true
	if bind and bind.synthetic == true and bind.vanilla_orbit_distance ~= nil then
		synthetic = false
		bind.synthetic = false
	end
	if synthetic then
		local ad = bind and adapter_of(bind, fam)
		if ad and ad.release then
			pcall(ad.release, fam, bind, opts.reason or "release")
		end
		if fam.Variant == (FamiliarVariant.WISP or 206) then
			venge_probe_trace("release_remove", fam, {
				reason = opts.reason or "release",
				synthetic = true,
			})
		end
		set_bind(fam, nil)
		fam:Remove()
		return
	end
	if opts.immediate then
		local ad = adapter_of(bind, fam)
		if ad and ad.release then
			pcall(ad.release, fam, bind, opts.reason or "release")
		end
		if fam.Variant == (FamiliarVariant.WISP or 206) then
			venge_probe_trace("release_unbind", fam, {
				reason = opts.reason or "release",
				synthetic = false,
				immediate = true,
			})
		end
		restore_vanilla_orbit(fam, bind)
		set_bind(fam, nil)
		return
	end
	begin_orbital_flyback(fam, bind)
end

local function ensure_meat_or_bandage(air, player, kind, ledger, want_var, meta)
	local existing = find_bound(air, kind)
	if not want_var then
		for _, fam in ipairs(existing) do release_fam(fam) end
		return
	end
	local real_n = ledger and (ledger.real_units or 0) or 0
	local synth_n = ledger and (ledger.synthetic_units or 0) or 0
	-- 已有绑定：优先保留；形态不对则对合成体重建，真实体尝试改 Variant
	local fam = existing[1]
	for i = 2, #existing do release_fam(existing[i]) end
	if fam then
		local b = bind_data(fam)
		if fam.Variant ~= want_var then
			if b and b.synthetic == false then
				-- 真实体：尽量切换形态；失败则保持
				pcall(function() fam.Variant = want_var end)
			else
				release_fam(fam)
				fam = nil
			end
		end
	end
	if fam then
		local b = bind_data(fam)
		if b then
			b.base_dps = meta.base_dps
			b.block = meta.block
			b.local_slot = meta.local_slot or meta.slot or 0
			b.slot = b.local_slot
			if meta.layout_ring ~= nil then b.layout_ring = meta.layout_ring end
			if meta.orbit_layer ~= nil then b.orbit_layer = meta.orbit_layer end
			-- 相位由 rebuild_orbit_layout 全局分配，不在 kind 内写死
			apply_orbit_attachment(fam, b)
		end
		return fam
	end
	-- 认领真实原版实体（有 real 份数时）
	if real_n > 0 then
		local variant_set = (kind == "meat") and MEAT_VARIANTS or BANDAGE_VARIANTS
		local cands = find_claimable_vanilla(player, air, variant_set, kind)
		-- 优先尚未绑定的
		local pick = nil
		for _, c in ipairs(cands) do
			local b = bind_data(c)
			if not b then pick = c break end
		end
		if not pick then
			for _, c in ipairs(cands) do
				local b = bind_data(c)
				if b and b.synthetic == false and b.air and GetPtrHash(b.air) == GetPtrHash(air) then
					pick = c
					break
				end
			end
		end
		if pick then
			if pick.Variant ~= want_var then
				pcall(function() pick.Variant = want_var end)
			end
			meta.synthetic = false
			return bind_existing_orbital(pick, air, player, meta)
		end
	end
	-- 合成份，或 real 认领失败时的兜底：仅当需要显示且（有 synth 或 real 认领失败）时 Spawn
	if synth_n > 0 or real_n > 0 then
		meta.synthetic = true
		return spawn_orbital(want_var, air, player, meta)
	end
	return nil
end

--- 普通 registry orbital：按材料份数 × adapter.count 认领/合成；相位交给全局 layout
local function meta_from_adapter(adapter, local_slot)
	return {
		source_id = adapter.collectible,
		kind = adapter.kind,
		slot = local_slot or 0,
		local_slot = local_slot or 0,
		layout_ring = adapter.layout_ring,
		group = adapter.group or "normal",
		base_dps = adapter.base_dps,
		base_dps_fn = adapter.base_dps_fn,
		block = adapter.block ~= false,
		reflect = adapter.reflect == true,
		orbit_layer = adapter.orbit_layer,
		adapter = adapter,
		-- synthetic 由 claim/spawn 路径显式写入；禁止默认 true 导致真体被 Remove
	}
end

local function ensure_profile_orbital(air, player, adapter, profile)
	if not adapter or not adapter.kind or not adapter.variant then return end
	local units = craft_count(profile, adapter.collectible)
	local per = math.max(1, math.floor(tonumber(adapter.count) or 1))
	local want_n = (units > 0) and (units * per) or 0
	local ad = air and air:GetData()
	local suppress = ad and ad[item.own_key.."suppress"]
	if suppress and suppress[adapter.collectible] then
		want_n = 0
	end
	local existing = find_bound(air, adapter.kind)
	table.sort(existing, function(a, b)
		local ba, bb = bind_data(a), bind_data(b)
		return (ba and (ba.local_slot or ba.slot) or 0) < (bb and (bb.local_slot or bb.slot) or 0)
	end)
	while #existing > want_n do
		local fam = table.remove(existing)
		release_fam(fam, {reason = "profile_excess", units = units, want_n = want_n})
	end
	local variant_set = {[adapter.variant] = true}
	for i = 0, want_n - 1 do
		local fam = existing[i + 1]
		local meta = meta_from_adapter(adapter, i)
		if fam then
			local b = bind_data(fam)
			if b then
				b.base_dps = meta.base_dps
				b.base_dps_fn = meta.base_dps_fn
				b.block = meta.block
				b.reflect = meta.reflect
				b.group = meta.group
				b.slot = i
				b.local_slot = i
				b.layout_ring = meta.layout_ring
				b.adapter = adapter
				if meta.orbit_layer ~= nil then b.orbit_layer = meta.orbit_layer end
				apply_orbit_attachment(fam, b)
			end
		else
			local claimed = nil
			local src = CraftProfile.source_bucket_for and CraftProfile.source_bucket_for(profile, adapter.collectible)
			local real_n = src and (src.real or 0) or 0
			if real_n > 0 or units > 0 then
				local cands = find_claimable_vanilla(player, air, variant_set, adapter.kind)
				for _, c in ipairs(cands) do
					if not bind_data(c) then
						claimed = c
						break
					end
				end
			end
			if claimed then
				meta.synthetic = false
				meta.trace_reason = "profile_claim"
				meta.trace_units = units
				meta.trace_want_n = want_n
				bind_existing_orbital(claimed, air, player, meta)
			else
				meta.synthetic = true
				spawn_orbital(adapter.variant, air, player, meta)
			end
		end
	end
end

--- 受伤库存类（693/702）：按 Flight 份额绑定，相位走 rebuild_orbit_layout 全局均分。
function item.ensure_kind_orbitals(air, player, kind, want_n, opts)
	if not air or not player or not kind then return {} end
	opts = opts or {}
	want_n = math.max(0, math.floor(tonumber(want_n) or 0))
	local adapter = ORBITAL_BY_KIND[kind]
	local existing = find_reserved_for_air(air, kind)
	table.sort(existing, function(a, b)
		local ba, bb = bind_data(a), bind_data(b)
		local la = ba and (ba.local_slot or ba.slot)
		local lb = bb and (bb.local_slot or bb.slot)
		if la == nil and lb == nil then
			return (tonumber(a.InitSeed) or 0) < (tonumber(b.InitSeed) or 0)
		end
		return (tonumber(la) or 999) < (tonumber(lb) or 999)
	end)
	local release_opts = opts.release_opts or {reason = "stock_excess", immediate = opts.release_immediate ~= false}
	while #existing > want_n do
		release_reserved_orbital(table.remove(existing), release_opts)
	end
	for i, fam in ipairs(existing) do
		local b = bind_data(fam)
		if b then
			b.local_slot = i - 1
			b.slot = i - 1
			if adapter then b.adapter = adapter end
			apply_orbit_attachment(fam, b)
		else
			local row = fam.InitSeed and PENDING_ORBITALS[fam.InitSeed]
			if row and row.meta then
				row.meta.local_slot = i - 1
				row.meta.slot = i - 1
			end
		end
	end
	while #existing < want_n do
		local slot = #existing
		local meta = adapter and meta_from_adapter(adapter, slot) or {kind = kind, slot = slot, local_slot = slot}
		if opts.meta then
			for k, v in pairs(opts.meta) do meta[k] = v end
		end
		if adapter and adapter.familiar_subtype then
			meta.spawn_subtype = adapter.familiar_subtype
		end
		local fam = nil
		if opts.claim_next then
			fam = opts.claim_next(player, air, slot)
			if fam and (bind_data(fam) or PENDING_ORBITALS[fam.InitSeed]) then
				fam = nil
			end
		end
		if fam then
			if opts.synthetic_claim == false then
				meta.synthetic = false
			end
			meta.trace_reason = meta.trace_reason or "stock_claim"
			queue_orbital_bind(fam, air, player, meta)
		elseif opts.spawn ~= false and adapter and adapter.variant then
			meta.synthetic = meta.synthetic ~= false
			meta.trace_reason = meta.trace_reason or "stock_spawn"
			fam = spawn_orbital(adapter.variant, air, player, meta)
		end
		if not fam then break end
		existing[#existing + 1] = fam
	end
	rebuild_orbit_layout(air)
	commit_pending_snaps_for_air(air)
	return existing
end

function item.find_bound_for_air(air, kind)
	return find_bound(air, kind)
end

function item.is_pending_orbital(fam)
	return fam and PENDING_ORBITALS[fam.InitSeed] ~= nil
end

function item.clear_pending_orbital(fam)
	clear_pending_orbital(fam)
end

function item.release_orbital(fam, opts)
	release_fam(fam, opts)
end

function item.find_reserved_for_air(air, kind)
	return find_reserved_for_air(air, kind)
end

function item.release_reserved_orbital(fam, opts)
	release_reserved_orbital(fam, opts)
end

local function write_profile_status(profile, key, value)
	if not profile then return end
	profile.extras = profile.extras or {}
	profile.extras[key] = value
end

function item.profile_needs_sync(profile)
	if not profile or not profile.counts then return false end
	local c = profile.counts
	if (c[MEAT_ID] or 0) > 0 or (c[BANDAGE_ID] or 0) > 0 then return true end
	for id, _ in pairs(ORBITAL_BY_COLLECTIBLE) do
		if (c[id] or 0) > 0 then return true end
	end
	return false
end

function item.sync_air_flight(air, player, profile)
	if not air or not player or not profile then return end
	local uid = air_uid(air)
	local meat_ledger = item.meat_bandage_ledger(player, profile, MEAT_ID)
	local band_ledger = item.meat_bandage_ledger(player, profile, BANDAGE_ID)
	local meat_u = meat_ledger.resolved_units
	local band_u = band_ledger.resolved_units

	local meat_cands, band_cands = {}, {}
	local Air = get_air_mod()
	local bp = get_blueprint()
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, Air.familiar or enums.Familiars.QingsAirs, -1, false, false)) do
		local other = ent:ToFamiliar()
		local owner = other and auxi.check_spawner_player(other)
		if other and owner and auxi.check_for_the_same(owner, player) then
			local ouid = other:GetData()[bp.own_key.."craft_uid"]
			local oprof = other:GetData()[Air.own_key.."craft_profile"]
			if ouid and oprof then
				local mu = item.meat_bandage_units(player, oprof, MEAT_ID)
				local bu = item.meat_bandage_units(player, oprof, BANDAGE_ID)
				if mu > 0 then meat_cands[#meat_cands + 1] = {uid = ouid, air = other, units = mu} end
				if bu > 0 then band_cands[#band_cands + 1] = {uid = ouid, air = other, units = bu} end
			end
		end
	end
	local meat_owner = item.resolve_exclusive_owner(player, "meat", meat_cands)
	local band_owner = item.resolve_exclusive_owner(player, "bandage", band_cands)

	local ad = air:GetData()
	local meat_conflict = (meat_u > 0 and uid_str(meat_owner) ~= uid_str(uid)) or nil
	local band_conflict = (band_u > 0 and uid_str(band_owner) ~= uid_str(uid)) or nil
	local meat_unsup = (meat_u >= 3) or nil
	local band_unsup = (band_u >= 3) or nil
	ad[item.own_key.."meat_conflict"] = meat_conflict
	ad[item.own_key.."bandage_conflict"] = band_conflict
	ad[item.own_key.."meat_unsupported"] = meat_unsup
	ad[item.own_key.."bandage_unsupported"] = band_unsup
	ad[item.own_key.."meat_ledger"] = meat_ledger
	ad[item.own_key.."bandage_ledger"] = band_ledger
	write_profile_status(profile, "meat_exclusive_conflict", meat_conflict and true or nil)
	write_profile_status(profile, "bandage_exclusive_conflict", band_conflict and true or nil)
	write_profile_status(profile, "meat_unsupported", meat_unsup and true or nil)
	write_profile_status(profile, "bandage_unsupported", band_unsup and true or nil)

	-- Meat
	do
		local want_var, unsup = nil, nil
		if uid_str(meat_owner) == uid_str(uid) and meat_u > 0 then
			want_var, unsup = desired_meat_variant(meat_u)
		end
		if unsup then want_var = nil end
		ensure_meat_or_bandage(air, player, "meat", meat_ledger, want_var, {
			source_id = MEAT_ID, kind = "meat", slot = 0, local_slot = 0,
			layout_ring = "inner",
			base_dps = BASE_DPS.meat, group = "normal", block = true,
			orbit_layer = default_layer_for("meat"),
			synthetic = true,
		})
	end

	-- Bandage
	do
		local want_var, unsup = nil, nil
		if uid_str(band_owner) == uid_str(uid) and band_u > 0 then
			want_var, unsup = desired_bandage_variant(band_u)
		end
		if unsup then want_var = nil end
		local ball_block = dbg("ball_blocks") ~= false
		ensure_meat_or_bandage(air, player, "bandage", band_ledger, want_var, {
			source_id = BANDAGE_ID, kind = "bandage", slot = 0, local_slot = 0,
			layout_ring = "inner",
			base_dps = BASE_DPS.bandage, group = "normal", block = ball_block,
			orbit_layer = default_layer_for("bandage"),
			synthetic = true,
		})
	end

	-- 批次1+：registry 普通 orbital（不含 exclusive / on-hurt）；稳定按 collectible id 排序
	do
		for _, row in ipairs(sorted_profile_orbitals()) do
			ensure_profile_orbital(air, player, row.adapter, profile)
		end
	end
	-- 香炉已迁到 Craft_Familiar 链式跟随；清掉旧 orbital 焊死绑定
	for _, fam in ipairs(find_bound(air, "censer")) do
		release_fam(fam)
	end
	rebuild_orbit_layout(air)
	-- layout 相位分配后再钉一次，避免首帧用旧角、次帧跳相位造成渲染闪烁
	commit_pending_snaps_for_air(air)
end

function item.release_for_air(air)
	if not air then return end
	local air_ptr = GetPtrHash(air)
	local release, seen = {}, {}
	for active_id, fam in pairs(ACTIVE_BOUND) do
		local alive = active_familiar_alive(fam)
		local bind = alive and bind_data(fam) or nil
		if not alive or not bind then
			ACTIVE_BOUND[active_id] = nil
		elseif bind.air and GetPtrHash(bind.air) == air_ptr then
			local ptr = GetPtrHash(fam)
			if not seen[ptr] then
				seen[ptr] = true
				release[#release + 1] = fam
			end
		end
	end
	for _, fam in ipairs(release) do
		release_fam(fam, {reason = "air_profile_release"})
	end
end

function item.spawn_best_bud(air, player)
	if not air or not player then return nil end
	if item.get_air_combat_state(air, player) ~= "active" then return nil end
	local room_idx = Game():GetLevel():GetCurrentRoomIndex()
	local existing = find_bound(air, "best_bud")
	if #existing > 0 then return existing[1] end
	local fam = spawn_orbital(FamiliarVariant.BEST_BUD or 60, air, player, {
		source_id = BEST_BUD_ID, kind = "best_bud", slot = 0, local_slot = 0,
		layout_ring = "middle",
		base_dps = BASE_DPS.best_bud, group = "normal", block = false,
		room_only = true, room_index = room_idx,
		orbit_layer = default_layer_for("best_bud"),
	})
	rebuild_orbit_layout(air)
	commit_pending_snaps_for_air(air)
	return fam
end

function item.spawn_or_repair_leprosy(air, player)
	if not air or not player then return end
	if item.get_air_combat_state(air, player) ~= "active" then return end
	local list = find_bound(air, "leprosy")
	table.sort(list, function(a, b)
		local ba, bb = bind_data(a), bind_data(b)
		return (ba and (ba.local_slot or ba.slot) or 0) < (bb and (bb.local_slot or bb.slot) or 0)
	end)
	local alive = {}
	for _, fam in ipairs(list) do
		local b = bind_data(fam)
		if b and (tonumber(b.durability) or 1) > 0 then
			alive[#alive + 1] = fam
		else
			release_fam(fam)
		end
	end
	if #alive >= 3 then return end
	local slot = #alive
	-- 耐久/阶段为占位：待探针确认原版破损后再固化；相位由全局 layout
	spawn_orbital(FamiliarVariant.LEPROSY or 121, air, player, {
		source_id = LEPROSY_ID, kind = "leprosy", slot = slot, local_slot = slot,
		layout_ring = "inner",
		base_dps = BASE_DPS.leprosy, group = "normal", block = true,
		durability = 3, max_durability = 3, stage = 0,
		orbit_layer = default_layer_for("leprosy"),
	})
	rebuild_orbit_layout(air)
	commit_pending_snaps_for_air(air)
end

local function rebuild_buckets()
	local frame = Game():GetFrameCount()
	if frame_buckets_frame == frame and frame_buckets then return frame_buckets end
	frame_buckets_frame = frame
	frame_buckets = {by_air = {}, group_n = {}, kind_n = {}, layout_ring_n = {}}
	local airs_seen = {}
	local seen = {}
	for active_id, fam in pairs(ACTIVE_BOUND) do
		local alive = active_familiar_alive(fam)
		local bind = alive and bind_data(fam) or nil
		if not alive or not bind then ACTIVE_BOUND[active_id] = nil end
		local ptr = bind and GetPtrHash(fam) or nil
		if ptr and seen[ptr] then goto continue end
		if ptr then seen[ptr] = true end
		if bind and bind.air and auxi.check_all_exists(bind.air) then
				local ap = GetPtrHash(bind.air)
				airs_seen[ap] = bind.air
				frame_buckets.by_air[ap] = frame_buckets.by_air[ap] or {}
				frame_buckets.by_air[ap][#frame_buckets.by_air[ap] + 1] = fam
				local gk = ap.."|"..(bind.group or "normal")
				frame_buckets.group_n[gk] = (frame_buckets.group_n[gk] or 0) + 1
				local kinds = frame_buckets.kind_n[ap] or {}
				kinds[bind.kind] = (kinds[bind.kind] or 0) + 1
				frame_buckets.kind_n[ap] = kinds
				local ring = resolved_layout_ring(bind, fam)
				local rk = ap.."|"..ring
				frame_buckets.layout_ring_n[rk] = (frame_buckets.layout_ring_n[rk] or 0) + 1
			end
		::continue::
	end
	for _, air in pairs(airs_seen) do
		rebuild_orbit_layout(air)
	end
	return frame_buckets
end

--- Flight 光环/近身类（446/559/423/574 等）：与环绕接触伤同一套 contact_mul/√n（及追敌折扣）。
--- group 默认 normal；无环绕物时 n=1，仅吃基础 contact_mul。
function item.aura_damage_mul(air, group)
	group = group or "normal"
	if not air then
		return dbg_num("contact_mul", 0.45)
	end
	local buckets = rebuild_buckets()
	local ap = GetPtrHash(air)
	local gk = ap .. "|" .. group
	local n = math.max(1, (buckets and buckets.group_n and buckets.group_n[gk]) or 1)
	return group_mul(air, group, n)
end

--- 同 Flight、同 group 的环绕叠乘惩罚 √n（不含 contact_mul / 追敌折扣）。至少为 1。
function item.group_stack_penalty(air, group)
	group = group or "normal"
	if not air then return 1 end
	local buckets = rebuild_buckets()
	local ap = GetPtrHash(air)
	local gk = ap .. "|" .. group
	local n = math.max(1, (buckets and buckets.group_n and buckets.group_n[gk]) or 1)
	return math.sqrt(n)
end

local function is_enemy_projectile(proj)
	if not proj then return false end
	local sp = proj.SpawnerEntity
	if sp then
		if sp:ToPlayer() then return false end
		local fam = sp:ToFamiliar()
		if fam and fam.Player then return false end
		if sp:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then return false end
	end
	if proj.SpawnerType == EntityType.ENTITY_PLAYER then return false end
	return true
end

--- 可计入宣誓守护者挡弹奖励的敌弹：敌方弹且无 CANT_HIT_PLAYER。
function item.is_sworn_blockable_projectile(proj)
	if not is_enemy_projectile(proj) then return false end
	local flag = ProjectileFlags and ProjectileFlags.CANT_HIT_PLAYER
	if flag and proj.HasProjectileFlags and proj:HasProjectileFlags(flag) then
		return false
	end
	if flag and proj.ProjectileFlags ~= nil and (proj.ProjectileFlags & flag) == flag then
		return false
	end
	return true
end

local function update_orbital(fam, buckets)
	local bind = bind_data(fam)
	if not bind then return end
	if bind.returning then
		update_returning_orbital(fam, bind)
		return
	end
	local air = bind.air
	if not air or not auxi.check_all_exists(air) then
		release_fam(fam)
		return
	end
	if bind.room_only then
		local idx = Game():GetLevel():GetCurrentRoomIndex()
		if bind.room_index ~= idx then
			release_fam(fam, { immediate = true, reason = "room_only" })
			return
		end
	end

	-- 蓝图时停：对齐 Craft_Familiar_holder，停驱动并冻结 orbit 相位
	if auxi.is_time_stopped() then
		accumulate_orbit_phase_freeze(fam, bind)
		bind.vel = Vector(0, 0)
		fam.Velocity = Vector(0, 0)
		apply_render_offset(fam, bind, air)
		fam.CollisionDamage = 0
		return
	end

	local adapter = bind.adapter or ORBITAL_BY_VARIANT[fam.Variant] or ORBITAL_BY_KIND[bind.kind]
	bind.adapter = adapter

	-- adapter 可声明 should_vanilla_free（聪明苍蝇追敌等）：解除位置/伤害劫持
	do
		local want_free = false
		if adapter and adapter.should_vanilla_free then
			local ok, v = pcall(adapter.should_vanilla_free, fam, bind, air)
			want_free = ok and v == true
		end
		local was_free = bind.vanilla_free == true
		bind.vanilla_free = want_free
		if want_free then
			if not was_free then
				-- 交还玩家轨道参数，便于原版 Smart Fly 追敌 AI
				restore_vanilla_orbit(fam, bind)
				bind.vanilla_free_entered = true
			end
			-- 不写 Position/Velocity/CollisionDamage，交还原版 AI
			return
		end
		if was_free then
			bind.vanilla_free_entered = nil
			bind.needs_snap = true
			bind.settle_frames = math.max(tonumber(bind.settle_frames) or 0, 8)
			apply_orbit_attachment(fam, bind)
		end
	end

	local player = auxi.check_spawner_player(air) or fam.Player
	local state = item.get_air_combat_state(air, player)

	refresh_orbit_runtime(fam, bind)

	-- 速度聚合：用缓存 vanilla_orbit_speed，禁止累乘
	do
		local ap = GetPtrHash(air)
		local kinds = (buckets and buckets.kind_n and buckets.kind_n[ap]) or {}
		local g_n = tonumber(kinds.guardian_angel) or 0
		local f_n = tonumber(kinds.big_fan) or 0
		local base_spd = bind.vanilla_orbit_speed
		if base_spd == nil then
			base_spd = tonumber(bind.orbit_speed) or tonumber(fam.OrbitSpeed) or 0.045
			bind.vanilla_orbit_speed = base_spd
		end
		local mul = 1
		if g_n > 0 then mul = mul * dbg_num("guardian_orbit_factor", 1.5) end
		if f_n > 0 then mul = mul * dbg_num("big_fan_orbit_factor", 0.5) end
		fam.OrbitSpeed = base_spd * mul
		bind.orbit_speed = fam.OrbitSpeed
	end

	-- 目标点：adapter.custom_target 优先，否则原版椭圆轨道相对 Flight
	local target = resolve_orbit_target(fam, bind, air, buckets)
	if not target then return end
	bind.last_target = copy_vec(target)
	bind.last_dist_to_air = fam.Position:Distance(air.Position)

	-- custom_drive：追弹等自驱（禁止走下方 err>90 瞬移，否则会「闪到弹幕再闪回」）
	local driven = false
	if adapter and adapter.custom_drive then
		local ok, ret = pcall(adapter.custom_drive, fam, bind, air, target, buckets, state)
		driven = ok and ret == true
	end

	if not driven then
	local soft = adapter and adapter.soft_rebind == true
	local soft_boost = soft and (tonumber(bind.soft_attach_frames) or 0) > 0
	if soft_boost then
		bind.soft_attach_frames = (tonumber(bind.soft_attach_frames) or 1) - 1
		bind.needs_snap = false
		bind.settle_frames = 0
	end
	local settling = (not soft) and (tonumber(bind.settle_frames) or 0) > 0
	if (not soft) and (bind.needs_snap or settling) then
		fam.Position = target
		bind.vel = Vector(0, 0)
		fam.Velocity = Vector(0, 0)
		bind.needs_snap = false
		if settling then
			bind.settle_frames = (tonumber(bind.settle_frames) or 1) - 1
		end
	else
		local spring = dbg_num("spring", 0.28)
		local damping = dbg_num("damping", 0.72)
		local max_spd = dbg_num("orbit_max_speed", 16)
		if soft_boost then
			spring = dbg_num("soft_attach_spring", 0.22)
			damping = dbg_num("soft_attach_damping", 0.78)
			max_spd = dbg_num("soft_attach_max_speed", 22)
		end
		local err = target - fam.Position
		-- 单帧误差过大：直接钉住（soft_rebind 禁止，避免装配闪现）
		if (not soft) and err:Length() > 90 then
			fam.Position = target
			bind.vel = Vector(0, 0)
			fam.Velocity = Vector(0, 0)
			bind.settle_frames = math.max(tonumber(bind.settle_frames) or 0, 3)
		else
			local vel = bind.vel or Vector(0, 0)
			vel = vel * damping + err * spring
			if vel:Length() > max_spd then
				vel = vel:Resized(max_spd)
			end
			bind.vel = vel
			fam.Velocity = vel
		end
	end
	end -- not driven

	apply_render_offset(fam, bind, air)
	-- preserve_vanilla_combat：手指等只接管位姿，接触伤留给原版 AI
	local preserve_combat = adapter and adapter.preserve_vanilla_combat == true
	local Air = get_air_mod()
	if Air.is_standby and Air.is_standby(air) then
		preserve_combat = false
	end
	if not preserve_combat then
		fam.CollisionDamage = 0
	end

	-- inactive：仍跑 adapter.update（机器苍蝇 Fly 动画等），但不结算接触/挡弹
	local skip_combat = (state == "inactive") or preserve_combat
	if state == "inactive" then
		fam.Velocity = fam.Velocity * 0.5
	end

	if not skip_combat then
	local ap = GetPtrHash(air)
	local gk = ap.."|"..(bind.group or "normal")
	local group_n = (buckets and buckets.group_n[gk]) or 1
	local per_hit, effective_dps, interval = item.contact_damage_per_hit(air, bind, group_n, state)
	bind.last_per_hit = per_hit
	bind.last_effective_dps = effective_dps

	local frame = Game():GetFrameCount()
	bind.hit_gate = bind.hit_gate or {}
	if frame % 90 == 0 then
		for k, until_f in pairs(bind.hit_gate) do
			if (tonumber(until_f) or 0) < frame then bind.hit_gate[k] = nil end
		end
	end

	local function contact_radius()
		local r = math.max(12, fam.Size + 6)
		if adapter and tonumber(adapter.contact_radius) then
			r = math.max(r, tonumber(adapter.contact_radius))
		end
		if adapter and adapter.contact_radius_fn then
			local ok, v = pcall(adapter.contact_radius_fn, fam, bind, air)
			if ok and tonumber(v) then r = math.max(r, tonumber(v)) end
		end
		return r
	end

	local function contact_allowed(npc)
		if not npc or not npc:IsVulnerableEnemy() or npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
			return false
		end
		if adapter and adapter.contact_filter then
			local ok, allow = pcall(adapter.contact_filter, fam, bind, npc, air)
			if ok and allow == false then return false end
		end
		return true
	end

	local hit_r = contact_radius()
	if per_hit > 0 then
		for _, npc in ipairs(Isaac.FindInRadius(fam.Position, hit_r, EntityPartition.ENEMY)) do
			if contact_allowed(npc) then
				local key = tostring(npc.InitSeed or GetPtrHash(npc))
				local next_ok = tonumber(bind.hit_gate[key]) or 0
				if frame >= next_ok then
					npc:TakeDamage(per_hit, 0, EntityRef(fam), 0)
					bind.hit_gate[key] = frame + interval
					bind.last_hit_frame = frame
					bind.last_hit_seed = npc.InitSeed
					bind.base_dps = resolve_base_dps(air, bind)
					if adapter and adapter.on_contact then
						pcall(adapter.on_contact, fam, bind, npc, air)
					end
				end
			end
		end
	elseif adapter and adapter.on_contact then
		-- 无 DPS 仍可能有接触副作用（如流血）；用同一 gate 限频
		for _, npc in ipairs(Isaac.FindInRadius(fam.Position, hit_r, EntityPartition.ENEMY)) do
			if contact_allowed(npc) then
				local key = "fx_"..tostring(npc.InitSeed or GetPtrHash(npc))
				local next_ok = tonumber(bind.hit_gate[key]) or 0
				if frame >= next_ok then
					pcall(adapter.on_contact, fam, bind, npc, air)
					bind.hit_gate[key] = frame + interval
				end
			end
		end
	end

	-- 挡弹 / 反射：active 才挡；degraded 不挡；Ball 受 ImGui 开关
	local can_block = state == "active" and bind.block
	if bind.kind == "bandage" then
		can_block = can_block and (dbg("ball_blocks") ~= false)
	end
	if can_block then
		for _, ent in ipairs(Isaac.FindInRadius(fam.Position, math.max(10, fam.Size + 4), EntityPartition.BULLET)) do
			local proj = ent:ToProjectile()
			if proj and is_enemy_projectile(proj) then
				local pd = proj:GetData()
				if pd[item.own_key.."blocked_frame"] ~= frame then
					pd[item.own_key.."blocked_frame"] = frame
					bind.block_count = (tonumber(bind.block_count) or 0) + 1
					local handled = false
					if adapter and adapter.on_block then
						local ok, ret = pcall(adapter.on_block, fam, bind, proj, air)
						handled = ok and ret == true
					end
					if not handled then
						if bind.kind == "leprosy" then
							bind.durability = (tonumber(bind.durability) or 1) - 1
							bind.stage = (tonumber(bind.stage) or 0) + 1
							if bind.durability <= 0 then
								release_fam(fam)
								return
							end
						end
						proj:Die()
					end
				end
			end
		end
	end

	-- 二级泪：仅 active
	local is_l2 = fam.Variant == (FamiliarVariant.CUBE_OF_MEAT_2 or 45)
		or fam.Variant == (FamiliarVariant.BALL_OF_BANDAGES_2 or 70)
	if is_l2 and state == "active" then
		local Air = get_air_mod()
		local ad = air:GetData()
		local should = ad[Air.own_key.."AuxShouldShoot"] == true
		local aim = ad[Air.own_key.."AuxAimDirection"]
		local cd = tonumber(bind.tear_cd) or 0
		local step = 1
		if player and player:HasTrinket(TrinketType.TRINKET_FORGOTTEN_LULLABY) then step = 2 end
		bind.tear_cd = math.max(0, cd - step)
		if should and aim and aim:Length() >= 0.01 and bind.tear_cd <= 0 then
			bind.tear_cd = 20
			local n = aim:Normalized()
			local tear = fam:FireProjectile(n * 10)
			if tear then
				tear = tear:ToTear() or tear
				tear.Velocity = n * 10
				tear.CollisionDamage = 3.5
				if player and player:HasCollectible(CollectibleType.COLLECTIBLE_BFFS) then
					tear.CollisionDamage = tear.CollisionDamage * 2
				end
				if fam.Variant == (FamiliarVariant.BALL_OF_BANDAGES_2 or 70) and tear.AddTearFlags then
					tear:AddTearFlags(TearFlags.TEAR_CHARM)
					tear.Color = Color(1, 0.4, 0.85, 1, 0.2, 0, 0.1)
				end
				tear.Parent = fam
				tear.SpawnerEntity = fam
				local td = tear:GetData()
				td[Air.own_key.."craft_air"] = air
				td[Air.own_key.."craft_uid"] = air_uid(air)
				td[item.own_key.."orbital_tear"] = true
				local FamiliarH = require("Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
				if FamiliarH.arm_tear_visual_lift then
					FamiliarH.arm_tear_visual_lift(tear, fam, air)
				elseif tear.PositionOffset ~= nil then
					tear.PositionOffset = Vector(0, 0)
				end
			end
		end
	end
	end -- not skip_combat

	if adapter and adapter.update then
		pcall(adapter.update, fam, bind, air, buckets, state)
	end
end

local function keeps_vanilla_ai(fam)
	local bind = bind_data(fam)
	local ad = (bind and bind.adapter) or (fam and ORBITAL_BY_VARIANT[fam.Variant])
	return ad and ad.keep_vanilla_ai == true
end

-- keep_vanilla_ai：必须在 MC_FAMILIAR_UPDATE 覆写 Velocity（对齐 My Emblem）；POST 太晚会本帧被原版位移吸走
local _keep_ai_buckets, _keep_ai_buckets_frame
local function buckets_for_keep_ai()
	local frame = Game():GetFrameCount()
	if _keep_ai_buckets_frame ~= frame then
		_keep_ai_buckets = rebuild_buckets()
		_keep_ai_buckets_frame = frame
	end
	return _keep_ai_buckets
end

table.insert(item.pre_ToCall, {
	CallBack = ModCallbacks.MC_PRE_FAMILIAR_UPDATE,
	params = nil,
	Function = function(_, fam)
		if fam and bind_data(fam) then track_active(fam) end
		if fam and fam.Variant == (FamiliarVariant.WISP or 206)
			and fam.SubType == (CollectibleType.COLLECTIBLE_VENGEFUL_SPIRIT or 702) then
			local d = fam:GetData()
			local skip = nil
			if pending_craft_orbital(fam) then
				skip = "pending_allow_ai"
			elseif not controlled_by_orbital(fam) then
				skip = "not_controlled"
			elseif not Familiar_Control_Selector.is_owner(fam, item.CONTROLLER) then
				skip = "not_owner"
			elseif not familiar_vanilla_ready(fam) then
				skip = "not_ready_allow_ai"
			elseif keeps_vanilla_ai(fam) then
				skip = "keep_vanilla_ai"
			else
				skip = "skip_ai"
			end
			if d[item.own_key.."pre_skip_state"] ~= skip then
				d[item.own_key.."pre_skip_state"] = skip
				venge_probe_trace("pre_familiar", fam, {pre_state = skip})
			end
		end
		if not controlled_by_orbital(fam) then return end
		if not Familiar_Control_Selector.is_owner(fam, item.CONTROLLER) then return end
		if not familiar_vanilla_ready(fam) then return end
		-- 棱镜等：不跳过原版 AI（分裂/碰撞逻辑在 AI 里）；其余 orbital 仍 return true
		if keeps_vanilla_ai(fam) then return end
		return true
	end,
})

-- 与 My Emblem 同回调：原版 AI 跑完立刻改 Velocity，物理积分前生效
table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_FAMILIAR_UPDATE,
	params = nil,
	Function = function(_, fam)
		if not fam or not keeps_vanilla_ai(fam) then return end
		if not bound_orbital_needs_tick(fam) then return end
		local bind = bind_data(fam)
		if bind and bind.vanilla_free then
			update_orbital(fam, buckets_for_keep_ai())
			return
		end
		if controlled_by_orbital(fam)
			and Familiar_Control_Selector.is_owner(fam, item.CONTROLLER) then
			update_orbital(fam, buckets_for_keep_ai())
		end
	end,
})

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		promote_pending_orbitals()
		local buckets = rebuild_buckets()
		local seen = {}
		for active_id, fam in pairs(ACTIVE_BOUND) do
				if not active_familiar_alive(fam) then
					ACTIVE_BOUND[active_id] = nil
					goto continue
				end
				local ptr = GetPtrHash(fam)
				if seen[ptr] then goto continue end
				seen[ptr] = true
				if not bound_orbital_needs_tick(fam) then goto continue end
				-- keep_vanilla_ai 已在 FAMILIAR_UPDATE 驱动，避免双 tick
				if keeps_vanilla_ai(fam) then goto continue end
				local bind = bind_data(fam)
				-- vanilla_free：不占选择器，但仍需 tick 以检测追敌结束并重新接管
				if bind and bind.vanilla_free then
					update_orbital(fam, buckets)
				elseif controlled_by_orbital(fam)
					and Familiar_Control_Selector.is_owner(fam, item.CONTROLLER) then
					update_orbital(fam, buckets)
				end
				::continue::
		end
	end,
})

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		local room_idx = Game():GetLevel():GetCurrentRoomIndex()
		for variant in orbital_variants_iter() do
			for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, variant, -1, false, false)) do
				local fam = ent:ToFamiliar()
				local bind = bind_data(ent)
				if bind then
					if bind.returning then
						-- 换房中断飞回，直接交回原版，避免跨房软驱
						release_fam(fam, { immediate = true, reason = "new_room" })
					else
						bind.hit_gate = {}
						local ad = adapter_of(bind, fam)
						if ad and ad.soft_rebind then
							bind.needs_snap = false
							bind.settle_frames = 0
							bind.soft_attach_frames = math.max(tonumber(bind.soft_attach_frames) or 0, dbg_num("soft_attach_frames", 36))
						else
							bind.needs_snap = true
						end
						if bind.room_only and bind.room_index ~= room_idx then
							release_fam(fam, { immediate = true, reason = "room_only" })
						end
					end
				end
			end
		end
	end,
})

function item.get_debug_status()
	local lines = {}
	local Air = get_air_mod()
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, Air.familiar or enums.Familiars.QingsAirs, -1, false, false)) do
		local air = ent:ToFamiliar()
		local ad = air:GetData()
		local player = auxi.check_spawner_player(air)
		local st = item.get_air_combat_state(air, player)
		local ml = ad[item.own_key.."meat_ledger"]
		local bl = ad[item.own_key.."bandage_ledger"]
		lines[#lines + 1] = string.format(
			"Air#%s state=%s meat_c=%s band_c=%s meat_u=%s band_u=%s",
			tostring(air.InitSeed), st,
			tostring(ad[item.own_key.."meat_conflict"]),
			tostring(ad[item.own_key.."bandage_conflict"]),
			ml and tostring(ml.resolved_units) or "?",
			bl and tostring(bl.resolved_units) or "?"
		)
		if ml then
			lines[#lines + 1] = string.format(
				"  meat ledger profile=%s true=%s fx=%s peeler=%s note=%s",
				tostring(ml.profile_units), tostring(ml.true_items),
				tostring(ml.temp_effects), tostring(ml.peeler_uses), tostring(ml.note)
			)
		end
	end
	for variant in orbital_variants_iter() do
		for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, variant, -1, false, false)) do
			local bind = bind_data(ent)
			if bind then
				local fam = ent:ToFamiliar() or ent
				if bind.returning then
					lines[#lines + 1] = string.format(
						"orb seed=%s kind=%s RETURNING startDist=%.1f vel=%.1f",
						tostring(ent.InitSeed),
						tostring(bind.kind),
						tonumber(bind.return_start_dist) or -1,
						(fam.Velocity and fam.Velocity:Length()) or 0
					)
				else
					local od = fam.OrbitDistance or bind.orbit_distance
					lines[#lines + 1] = string.format(
						"orb seed=%s kind=%s ring=%s slot=%s layer=%s dist=(%.1f,%.1f) spd=%.4f layAng=%.3f airDist=%.1f poY=%.1f bias=%.1f dps0=%.0f hitDmg=%.2f blocks=%s",
						tostring(ent.InitSeed),
						tostring(bind.kind),
						tostring(bind.layout_ring or resolved_layout_ring(bind, fam)),
						tostring(bind.local_slot or bind.slot),
						tostring(fam.OrbitLayer or bind.active_orbit_layer or bind.orbit_layer),
						od and od.X or 0, od and od.Y or 0,
						tonumber(fam.OrbitSpeed or bind.orbit_speed) or 0,
						tonumber(bind.layout_angle_offset or fam.OrbitAngleOffset or bind.orbit_angle_offset) or 0,
						tonumber(bind.last_dist_to_air) or 0,
						fam.PositionOffset and fam.PositionOffset.Y or 0,
						dbg_num("orbital_render_y_bias", 0),
						tonumber(bind.base_dps) or 0,
						tonumber(bind.last_per_hit) or 0,
						tostring(bind.block_count)
					)
				end
			end
		end
	end
	if #lines == 0 then return "无 Flight orbital" end
	return table.concat(lines, "\n")
end

--- ImGui 探针：layer 0–4 + 批次1全部 Variant 的 Layer/Distance/Speed/Angle/PO/中心距
function item.probe_orbit_params()
	if not dev_env.probes_allowed() then return "public release: probes disabled" end
	local lines = {}
	lines[#lines + 1] = "=== EntityFamiliar.GetOrbitDistance(0..4) ==="
	if EntityFamiliar.GetOrbitDistance then
		for layer = 0, 4 do
			local ok, d = pcall(function() return EntityFamiliar.GetOrbitDistance(layer) end)
			if ok and d then
				lines[#lines + 1] = string.format("layer %d: (%.2f, %.2f) len=%.2f", layer, d.X, d.Y, d:Length())
			else
				lines[#lines + 1] = string.format("layer %d: FAIL %s", layer, tostring(d))
			end
		end
	else
		lines[#lines + 1] = "GetOrbitDistance unavailable"
	end

	local want = {
		[FamiliarVariant.CUBE_OF_MEAT_1 or 44] = "meat1",
		[FamiliarVariant.CUBE_OF_MEAT_2 or 45] = "meat2",
		[FamiliarVariant.CUBE_OF_MEAT_3 or 46] = "meat3",
		[FamiliarVariant.CUBE_OF_MEAT_4 or 47] = "meat4",
		[FamiliarVariant.BALL_OF_BANDAGES_1 or 69] = "band1",
		[FamiliarVariant.BALL_OF_BANDAGES_2 or 70] = "band2",
		[FamiliarVariant.BALL_OF_BANDAGES_3 or 71] = "band3",
		[FamiliarVariant.BALL_OF_BANDAGES_4 or 72] = "band4",
		[FamiliarVariant.BEST_BUD or 60] = "best_bud",
		[FamiliarVariant.LEPROSY or 121] = "leprosy",
		[FamiliarVariant.FLY_ORBITAL or 33] = "halo_flies",
		[FamiliarVariant.DISTANT_ADMIRATION or 31] = "distant_admiration",
		[FamiliarVariant.GUARDIAN_ANGEL or 32] = "guardian_angel",
		[FamiliarVariant.FOREVER_ALONE or 30] = "forever_alone",
		[FamiliarVariant.SACRIFICIAL_DAGGER or 35] = "sacrificial_dagger",
		[FamiliarVariant.BIG_FAN or 65] = "big_fan",
		[FamiliarVariant.FRIEND_ZONE or 84] = "friend_zone",
		[FamiliarVariant.MOMS_RAZOR or 117] = "moms_razor",
		[FamiliarVariant.SLIPPED_RIB or 126] = "slipped_rib",
		[FamiliarVariant.SWORN_PROTECTOR or 83] = "sworn_protector",
		[FamiliarVariant.CENSER or 89] = "censer",
		[FamiliarVariant.SMART_FLY or 50] = "smart_fly",
		[FamiliarVariant.BLOODSHOT_EYE or 116] = "bloodshot_eye",
		[FamiliarVariant.ANGELIC_PRISM or 123] = "angelic_prism",
		[FamiliarVariant.POINTY_RIB or 127] = "pointy_rib",
		[FamiliarVariant.FINGER or 110] = "finger",
		[FamiliarVariant.PSY_FLY or 204] = "psy_fly",
		[FamiliarVariant.BOT_FLY or 218] = "bot_fly",
		[FamiliarVariant.TINYTOMA or 216] = "tinytoma",
		[FamiliarVariant.TINYTOMA_2 or 217] = "tinytoma_2",
	}
	local labels = {}
	for variant, label in pairs(want) do
		labels[#labels + 1] = {variant = variant, label = label}
	end
	table.sort(labels, function(a, b) return a.variant < b.variant end)

	lines[#lines + 1] = "=== player-owned orbitals (batch1 + meat/band) ==="
	local p0 = Isaac.GetPlayer(0)
	local found = 0
	for _, row in ipairs(labels) do
		local variant, label = row.variant, row.label
		for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, variant, -1, false, false)) do
			local fam = ent:ToFamiliar()
			if fam and fam.Player and p0 and auxi.check_for_the_same(fam.Player, p0) then
				found = found + 1
				local od = fam.OrbitDistance
				local po = fam.PositionOffset
				local so = fam.SpriteOffset
				local center = fam.Player.Position
				local b = bind_data(fam)
				local air = b and b.air
				if air and auxi.check_all_exists(air) then center = air.Position end
				local spr = fam:GetSprite()
				lines[#lines + 1] = string.format(
					"%s var=%s layer=%s dist=(%.2f,%.2f) spd=%.5f angOff=%.4f toCenter=%.1f po=(%.1f,%.1f) so=(%.1f,%.1f) anim=%s frame=%s bound=%s ring=%s layAng=%s",
					label, tostring(variant),
					tostring(fam.OrbitLayer),
					od and od.X or 0, od and od.Y or 0,
					tonumber(fam.OrbitSpeed) or 0,
					tonumber(fam.OrbitAngleOffset) or 0,
					fam.Position:Distance(center),
					po and po.X or 0, po and po.Y or 0,
					so and so.X or 0, so and so.Y or 0,
					spr and spr:GetAnimation() or "?",
					spr and tostring(spr:GetFrame()) or "?",
					b and "yes" or "no",
					b and tostring(b.layout_ring or "?") or "-",
					b and tostring(b.layout_angle_offset or "-") or "-"
				)
			end
		end
	end
	if found == 0 then
		lines[#lines + 1] = "(无玩家相关 orbital；请先拿原版道具或制造环绕材料再探针)"
	end
	item._last_orbit_probe = table.concat(lines, "\n")
	print("[Qing] orbital probe:\n"..item._last_orbit_probe)

	-- 写入 codex_work/logs（与 AGENTS 探针路径约定一致）
	local paths = {
		"mods/Qing_remaster/codex_work/logs/orbital_batch1_probe.txt",
		"../mods/Qing_remaster/codex_work/logs/orbital_batch1_probe.txt",
	}
	local written = nil
	for _, path in ipairs(paths) do
		local ok, f = pcall(io.open, path, "w")
		if ok and f then
			f:write(item._last_orbit_probe)
			f:write("\n")
			f:close()
			written = path
			break
		end
	end
	if written then
		print("[Qing] orbital probe wrote "..written)
	else
		print("[Qing] orbital probe write failed (ensure codex_work/logs exists)")
	end
	return item._last_orbit_probe
end

function item.restore_debug_defaults()
	item.debug.contact_mul = 0.45
	item.debug.high_contact_mul = 0.30
	item.debug.chase_discount = 0.65
	item.debug.hit_interval = 10
	item.debug.orbit_dist_mul = 1.0
	item.debug.orbit_mul_meat = 1.0
	item.debug.orbit_mul_bandage = 1.0
	item.debug.orbit_mul_best_bud = 1.0
	item.debug.orbit_mul_leprosy = 1.0
	item.debug.orbit_layer_meat = 0
	item.debug.orbit_layer_bandage = 0
	item.debug.orbit_layer_best_bud = 1
	item.debug.orbit_layer_leprosy = 0
	item.debug.orbital_render_y_bias = 0
	item.debug.rebind_smooth = 8
	item.debug.spring = 0.28
	item.debug.damping = 0.72
	item.debug.orbit_max_speed = 16
	item.debug.ball_blocks = true
	item.debug.psy_search = 180
	item.debug.psy_chase_max = 28
	item.debug.psy_chase_blend = 0.4
	item.debug.psy_lead = 2
	item.debug.psy_return_max = 18
	item.debug.psy_return_max_after_chase = 22
	item.debug.psy_return_blend = 0.28
	item.debug.psy_streak_max = 8
	item.debug.psy_cd = 20
	item.debug.psy_trail_radius = 0.12
	item.debug.psy_trail_scale = 0.6
	item.debug.guardian_orbit_factor = 1.5
	item.debug.big_fan_orbit_factor = 0.5
	item.debug.razor_bleed_frames = 150
	item.debug.return_join_ratio = 0.2
	item.debug.return_join_min_distance = 28
	item.debug.return_drive_min_speed = 10
	item.debug.return_drive_speed_margin = 12
	item.debug.return_drive_blend = 0.55
	item.debug.soft_attach_frames = 36
	item.debug.soft_attach_spring = 0.22
	item.debug.soft_attach_damping = 0.78
	item.debug.soft_attach_max_speed = 22
end

-- ---------- registry：现有独占/on-hurt + 批次1 ----------
local function register_legacy_and_batch1()
	local meat1 = FamiliarVariant.CUBE_OF_MEAT_1 or 44
	local meat2 = FamiliarVariant.CUBE_OF_MEAT_2 or 45
	local band1 = FamiliarVariant.BALL_OF_BANDAGES_1 or 69
	local band2 = FamiliarVariant.BALL_OF_BANDAGES_2 or 70
	item.register_orbital(meat1, {
		collectible = MEAT_ID, kind = "meat", exclusive = true, sync_from_profile = false,
		base_dps = BASE_DPS.meat, group = "normal", block = true,
		layout_ring = "inner", orbit_layer = 0, position_offset_mode = "air_relative",
	})
	item.register_orbital(meat2, {
		collectible = MEAT_ID, kind = "meat", exclusive = true, sync_from_profile = false,
		base_dps = BASE_DPS.meat, group = "normal", block = true,
		layout_ring = "inner", orbit_layer = 0, position_offset_mode = "air_relative",
	})
	item.register_orbital(band1, {
		collectible = BANDAGE_ID, kind = "bandage", exclusive = true, sync_from_profile = false,
		base_dps = BASE_DPS.bandage, group = "normal", block = true,
		layout_ring = "inner", orbit_layer = 0, position_offset_mode = "air_relative",
	})
	item.register_orbital(band2, {
		collectible = BANDAGE_ID, kind = "bandage", exclusive = true, sync_from_profile = false,
		base_dps = BASE_DPS.bandage, group = "normal", block = true,
		layout_ring = "inner", orbit_layer = 0, position_offset_mode = "air_relative",
	})
	item.register_orbital(FamiliarVariant.BEST_BUD or 60, {
		collectible = BEST_BUD_ID, kind = "best_bud", sync_from_profile = false,
		base_dps = BASE_DPS.best_bud, group = "normal", block = false,
		layout_ring = "middle", orbit_layer = 1, position_offset_mode = "air_relative",
	})
	item.register_orbital(FamiliarVariant.LEPROSY or 121, {
		collectible = LEPROSY_ID, kind = "leprosy", sync_from_profile = false,
		base_dps = BASE_DPS.leprosy, group = "normal", block = true,
		layout_ring = "inner", orbit_layer = 0, position_offset_mode = "air_relative",
	})

	-- 10 Halo of Flies
	item.register_orbital(FamiliarVariant.FLY_ORBITAL or 33, {
		collectible = CollectibleType.COLLECTIBLE_HALO_OF_FLIES or 10,
		kind = "halo_flies", count = 2, base_dps = 0, group = "normal", block = true,
		layout_ring = "inner", orbit_layer = 0, position_offset_mode = "air_relative",
	})
	-- 57 Distant Admiration（距离待 vanilla_probe 校准，勿声称精确还原）
	item.register_orbital(FamiliarVariant.DISTANT_ADMIRATION or 31, {
		collectible = CollectibleType.COLLECTIBLE_DISTANT_ADMIRATION or 57,
		kind = "distant_admiration", base_dps = 75, group = "normal", block = false,
		layout_ring = "middle", orbit_layer = 1, distance_source = "vanilla_probe",
		position_offset_mode = "air_relative",
	})
	-- 112 Guardian Angel
	item.register_orbital(FamiliarVariant.GUARDIAN_ANGEL or 32, {
		collectible = CollectibleType.COLLECTIBLE_GUARDIAN_ANGEL or 112,
		kind = "guardian_angel", base_dps = 105, group = "high", block = true,
		layout_ring = "inner", orbit_layer = 0, position_offset_mode = "air_relative",
	})
	-- 128 Forever Alone
	item.register_orbital(FamiliarVariant.FOREVER_ALONE or 30, {
		collectible = CollectibleType.COLLECTIBLE_FOREVER_ALONE or 128,
		kind = "forever_alone", base_dps = 30, group = "normal", block = false,
		layout_ring = "outer", orbit_layer = 2, distance_source = "vanilla_probe",
		position_offset_mode = "air_relative",
	})
	-- 172 Sacrificial Dagger
	item.register_orbital(FamiliarVariant.SACRIFICIAL_DAGGER or 35, {
		collectible = CollectibleType.COLLECTIBLE_SACRIFICIAL_DAGGER or 172,
		kind = "sacrificial_dagger", base_dps = 112.5, group = "high", block = true,
		layout_ring = "inner", orbit_layer = 0, position_offset_mode = "air_relative",
	})
	-- 279 Big Fan
	item.register_orbital(FamiliarVariant.BIG_FAN or 65, {
		collectible = CollectibleType.COLLECTIBLE_BIG_FAN or 279,
		kind = "big_fan", base_dps = 30, group = "normal", block = false,
		layout_ring = "middle", orbit_layer = 1, position_offset_mode = "air_relative",
	})
	-- 364 Friend Zone
	item.register_orbital(FamiliarVariant.FRIEND_ZONE or 84, {
		collectible = CollectibleType.COLLECTIBLE_FRIEND_ZONE or 364,
		kind = "friend_zone", base_dps = 45, group = "normal", block = false,
		layout_ring = "middle", orbit_layer = 1, distance_source = "vanilla_probe",
		position_offset_mode = "air_relative",
	})
	-- 508 Mom's Razor
	item.register_orbital(FamiliarVariant.MOMS_RAZOR or 117, {
		collectible = CollectibleType.COLLECTIBLE_MOMS_RAZOR or 508,
		kind = "moms_razor", group = "normal", block = false,
		layout_ring = "middle", orbit_layer = 1, position_offset_mode = "air_relative",
		base_dps_fn = function(air, _bind)
			local Air = get_air_mod()
			local prof = air and air:GetData()[Air.own_key.."craft_profile"]
			local dmg = (prof and prof.stats and tonumber(prof.stats.damage)) or 3.5
			return 1.5 * dmg
		end,
		on_contact = function(fam, _bind, npc, _air)
			local dur = math.floor(dbg_num("razor_bleed_frames", 150))
			if npc and npc.AddBleeding then
				npc:AddBleeding(EntityRef(fam), dur)
			end
		end,
	})
	-- 542 Slipped Rib
	item.register_orbital(FamiliarVariant.SLIPPED_RIB or 126, {
		collectible = CollectibleType.COLLECTIBLE_SLIPPED_RIB or 542,
		kind = "slipped_rib", base_dps = 0, group = "normal", block = true, reflect = true,
		layout_ring = "inner", orbit_layer = 0, position_offset_mode = "air_relative",
		on_block = function(fam, _bind, proj, _air)
			if not proj then return false end
			local pd = proj:GetData()
			if pd[item.own_key.."rib_reflected"] then
				return false
			end
			pd[item.own_key.."rib_reflected"] = true
			local vel = proj.Velocity
			if vel then
				proj.Velocity = Vector(-vel.X, -vel.Y)
			end
			proj.SpawnerEntity = fam
			if proj.SpawnerType ~= nil then
				proj.SpawnerType = EntityType.ENTITY_FAMILIAR
			end
			if proj.SpawnerVariant ~= nil then
				proj.SpawnerVariant = fam.Variant
			end
			if proj.AddEntityFlags and EntityFlag.FLAG_FRIENDLY then
				proj:AddEntityFlags(EntityFlag.FLAG_FRIENDLY)
			end
			return true
		end,
	})
	-- 693 The Swarm / 702 Vengeful Spirit：受伤库存，轨道与相位走全局 layout（Craft_Aux 管库存与齐射）
	local SWARM_ID = CollectibleType.COLLECTIBLE_SWARM or 693
	local VENGEFUL_ID = CollectibleType.COLLECTIBLE_VENGEFUL_SPIRIT or 702
	local SWARM_FLY_VAR = FamiliarVariant.SWARM_FLY_ORBITAL or 229
	local WISP_VAR = FamiliarVariant.WISP or 206
	item.register_orbital(SWARM_FLY_VAR, {
		collectible = SWARM_ID, kind = "swarm", sync_from_profile = false,
		base_dps = 0, group = "normal", block = true,
		layout_ring = "inner", orbit_layer = 0, layout_priority = 100,
		position_offset_mode = "air_relative",
		render_y_bias_aux = "swarm_lift_extra",
		on_block = function(fam, _bind, proj, air)
			local ok, Aux = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Aux_Entities_holder")
			if not ok or not Aux or not Aux.on_swarm_block then return false end
			return Aux.on_swarm_block(fam, proj, auxi.check_spawner_player(air)) == true
		end,
	})
	item.register_orbital(WISP_VAR, {
		collectible = VENGEFUL_ID, kind = "vengeful_spirit", familiar_subtype = VENGEFUL_ID,
		sync_from_profile = false, base_dps = 0, group = "normal", block = false,
		layout_ring = "vengeful", orbit_layer = 1, layout_priority = 10,
		orbit_params_aux = "vengeful", render_y_bias_aux = "vengeful_lift_extra",
		hit_interval = 4, position_offset_mode = "air_relative",
		-- 对齐棱镜：装配从玩家槽软驱到 Flight，禁止 Position 瞬移。
		soft_rebind = true,
		-- 接管后 PRE 挡原版 AI；Sprite 须自驱（003.206_wisp.anm2 默认 Idle）
		on_bind = function(fam, bind)
			if not fam then return end
			fam.Visible = true
			if fam.ClearEntityFlags and EntityFlag.FLAG_APPEAR then
				fam:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
			end
			local spr = fam:GetSprite()
			if spr then
				spr:Play("Idle", true)
			end
			if bind then bind.venge_sprite_ok = true end
		end,
		update = function(fam, bind, _air, _buckets, _state)
			if not fam then return end
			fam.Visible = true
			local spr = fam:GetSprite()
			if not spr then return end
			if (spr:GetAnimation() or "") ~= "Idle" then
				spr:Play("Idle", true)
			end
			spr:Update()
		end,
		base_dps_fn = function(air, _bind)
			local Air = get_air_mod()
			local prof = air and air:GetData()[Air.own_key.."craft_profile"]
			local player = auxi.check_spawner_player(air)
			local fd = (prof and prof.stats and tonumber(prof.stats.damage))
				or (player and tonumber(player.Damage)) or 3.5
			local mul = 0.5
			local ok, Aux = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Aux_Entities_holder")
			if ok and Aux.get_cfg then
				mul = tonumber(Aux.get_cfg("vengeful_contact_mul")) or 0.5
			end
			local per_hit = fd * mul * item.aura_damage_mul(air, "normal")
			local cd = 4
			if ok and Aux.get_cfg then
				cd = math.max(1, math.floor(tonumber(Aux.get_cfg("vengeful_contact_hit_cd")) or 4))
			end
			return per_hit * (30 / cd)
		end,
	})
end

register_legacy_and_batch1()

--- 聪明苍蝇：所属玩家有效受伤后追敌一段时间（解除劫持，交还原版 AI）
function item.notify_smart_fly_chase(air, duration_frames)
	if not air then return end
	duration_frames = math.max(30, math.floor(tonumber(duration_frames) or 180))
	local until_f = Game():GetFrameCount() + duration_frames
	for _, fam in ipairs(find_all_bound(air)) do
		local bind = bind_data(fam)
		if bind and bind.kind == "smart_fly" then
			bind.chase_until = until_f
			bind.chase_target = nil
			-- 当帧起解除劫持；下一帧 PRE 放行原版 AI
			if not bind.vanilla_free then
				restore_vanilla_orbit(fam, bind)
			end
			bind.vanilla_free = true
			bind.vanilla_free_entered = true
		end
	end
end

--- 临时压制某 collectible 的 profile sync（Tinytoma 分裂期等）
function item.set_collectible_suppress(air, collectible_id, on)
	if not air or not collectible_id then return end
	local d = air:GetData()
	d[item.own_key.."suppress"] = d[item.own_key.."suppress"] or {}
	if on then
		d[item.own_key.."suppress"][collectible_id] = true
	else
		d[item.own_key.."suppress"][collectible_id] = nil
	end
end

--- 供分裂体等外部 spawn 后绑定
function item.bind_external_orbital(fam, air, player, meta)
	return queue_orbital_bind(fam, air, player, meta)
end

return item
