-- Flight 攻击附加 / 光环（批次 1：502/447/446/574/559/423）
-- 效果归属 craft_uid；不临时 AddCollectible；伤害取 Flight stats.damage。
-- 446/559/423/574 近身光环伤乘 Craft_Orbital_holder.aura_damage_mul（contact_mul/√n + 追敌折扣）。
-- 半径/资源常量可被 craft_aura_effect_probe 校准覆盖（item.cfg）。
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")

local item = {
	pre_ToCall = {},
	ToCall = {},
	own_key = "craft_aura_effects_",
	cfg = {},
}

local IDS = {
	LARGE_ZIT = 502,
	LINGER_BEAN = 447,
	DEAD_TOOTH = 446,
	MONSTRANCE = 574,
	VOLT = 559,
	CIRCLE = 423,
}

local DEFAULTS = {
	zit_chance = 0.20,
	zit_speed_mul = 10,
	zit_scale = 1.0, -- 探针：额外弹 Scale=1，与主弹同
	zit_creep_timeout = 125, -- PLAYER_CREEP_WHITE Timeout
	-- 探针 Tint≈0.3 + Offset≈0.7（粉肉）；非 BOOGER 泪
	zit_tint = 0.3,
	zit_offset = 0.7,
	linger_charge_frames = 120,
	linger_life = 300,
	linger_tick = 6, -- ~5/s
	linger_radius0 = 40,
	linger_radius1 = 90,
	linger_push = 0.35,
	-- 探针：贴身 Effect 105 BROWN_CLOUD（不是 SMOKE_CLOUD 141）
	linger_fx_variant = EffectVariant.BROWN_CLOUD or 105,
	linger_fx_subtype = 0,
	tooth_radius = 80, -- ~两格
	-- 探针：106 FART_RING，Scale≈0.8，Timeout 由引擎管（Appear）
	tooth_fx_variant = EffectVariant.FART_RING or 106,
	tooth_fx_subtype = 0,
	tooth_fx_scale = 0.8,
	tooth_poison_ticks = 2,
	tooth_poison_max = 6,
	tooth_poison_tick_frames = 30,
	-- 圣体光：默认半径/贴图约为首版一半；ImGui 可调
	monstrance_radius = 45,
	monstrance_fx_scale = 0.5,
	monstrance_interval = 4,
	monstrance_halo_subtype = 2,
	-- 探针：ELECTRIC 激光每 6 帧；伤 0.75×；链跳偶发 2–4
	volt_radius = 80,
	volt_interval = 6,
	volt_chain_max = 4,
	volt_damage_mul = 0.75,
	volt_laser_timeout = 2,
	-- Flight 枪口已在实体 PO 上；不再叠加原版玩家眼高 -18
	volt_laser_po_y = 0,
	volt_fx_variant = EffectVariant.CHAIN_LIGHTNING or 167,
	-- 探针：LIGHT_RING + RING_FOLLOW_PARENT，Radius=80，Size=16
	-- 原版相对玩家原点 PO.y=-20；Flight 已带升空 PO，不再叠常量
	cop_radius = 80,
	cop_midline = 80,
	cop_damage_interval = 30,
	cop_reflect_chance = 0.30,
	cop_tear_speed = 10,
	cop_size = 16,
	cop_laser_po_y = 0,
}

local volt_hit_window = {} -- [ptr] = frame；同帧多 Flight 去重
local linger_clouds = {} -- [GetPtrHash] = 最新 wrapper；行为状态不能使用可能被 GC 丢弃的弱键

local function runtime_key(ent)
	local ok, ptr = pcall(GetPtrHash, ent)
	return ok and ptr or nil
end

local function cfg(key)
	local v = item.cfg[key]
	if v ~= nil then return v end
	return DEFAULTS[key]
end

local function get_air_mod()
	return require("Qing_Remaster_scripts.items.Item_Air_Flight")
end

local function get_blueprint()
	return require("Qing_Remaster_scripts.items.Item_Blue_Print")
end

local function get_hurt_router()
	return require("Qing_Remaster_scripts.others.craft_on_hurt_router")
end

local function get_orbital()
	return require("Qing_Remaster_scripts.mimics.Craft_Orbital_holder")
end

--- 与环绕物接触伤同一衰减：contact_mul / √(同 Flight normal 组数量) × chase_discount
local function orbital_mul(air)
	local Orb = get_orbital()
	if Orb and Orb.aura_damage_mul then
		local ok, mul = pcall(Orb.aura_damage_mul, air, "normal")
		if ok and tonumber(mul) then return tonumber(mul) end
	end
	local fallback = Orb and Orb.debug and tonumber(Orb.debug.contact_mul)
	return fallback or 0.45
end

local function count_of(profile, id)
	return CraftProfile.count_of(profile and profile.counts, id)
end

local function flight_damage(profile, player)
	return (profile and profile.stats and tonumber(profile.stats.damage))
		or (player and tonumber(player.Damage))
		or 3.5
end

local function craft_uid_of(air)
	if not air then return nil end
	local bp = get_blueprint()
	return air:GetData()[bp.own_key.."craft_uid"]
end

local function clamp01(x)
	if x < 0 then return 0 end
	if x > 1 then return 1 end
	return x
end

local function spawn_effect(variant, subtype, pos, vel, spawner)
	local ent = Isaac.Spawn(
		EntityType.ENTITY_EFFECT,
		variant,
		subtype or 0,
		pos,
		vel or Vector.Zero,
		spawner
	)
	if not ent then return nil end
	-- Isaac.Spawn 返回 Entity；Timeout/SetTimeout 只在 EntityEffect 上
	local fx = ent:ToEffect()
	if not fx then return nil end
	if spawner then
		fx.Parent = spawner
		fx.SpawnerEntity = spawner
	end
	return fx
end

local function set_effect_life(fx, frames)
	if not fx or frames == nil then return end
	frames = math.floor(tonumber(frames) or 0)
	if frames < 0 then frames = 0 end
	if fx.SetTimeout then
		pcall(function() fx:SetTimeout(frames) end)
	else
		pcall(function() fx.Timeout = frames end)
	end
end

local function copy_po(v)
	if not v then return Vector(0, 0) end
	return Vector(v.X, v.Y)
end

--- 跟随特效必须同步 Position + PositionOffset（Flight 升空时 PO.Y 非零）
local function sync_follow_fx(fx, air, scale)
	if not fx or not air then return end
	fx.Position = air.Position
	fx.Velocity = Vector.Zero
	if fx.PositionOffset ~= nil then
		fx.PositionOffset = copy_po(air.PositionOffset)
	end
	if scale and fx.SpriteScale then
		fx.SpriteScale = Vector(scale, scale)
	end
end

local function ensure_follow_fx(air, key, variant, subtype, scale)
	local d = air:GetData()
	local fx = d[item.own_key..key]
	if fx and auxi.check_all_exists(fx) then
		sync_follow_fx(fx, air, scale)
		return fx
	end
	fx = spawn_effect(variant, subtype or 0, air.Position, Vector.Zero, air)
	if fx then
		sync_follow_fx(fx, air, scale)
		d[item.own_key..key] = fx
	end
	return fx
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

local function clear_follow_fx(air, key)
	local d = air:GetData()
	local fx = d[item.own_key..key]
	if fx and auxi.check_all_exists(fx) then
		fx:Remove()
	end
	d[item.own_key..key] = nil
end

local function clear_cop_ring(air)
	clear_follow_fx(air, "cop_ring")
	-- 旧 HALO 跟随残留
	clear_follow_fx(air, "cop_fx")
end

--- 保护之环：常驻 LIGHT_RING + RING_FOLLOW_PARENT（视觉）；CollisionDamage=0，伤由 Lua 脉冲负责
local function ensure_cop_ring(air)
	if not air then return nil end
	local d = air:GetData()
	local ring = d[item.own_key.."cop_ring"]
	local radius = tonumber(cfg("cop_radius")) or 80
	local size = tonumber(cfg("cop_size")) or 16
	local po_y = tonumber(cfg("cop_laser_po_y")) or 0
	local po = copy_po(air.PositionOffset) + Vector(0, po_y)
	if ring and auxi.check_all_exists(ring) then
		ring.Position = air.Position
		ring.Velocity = Vector.Zero
		ring.Parent = air
		ring.SpawnerEntity = air
		ring.PositionOffset = po
		if ring.Radius ~= nil then ring.Radius = radius end
		if ring.Size ~= nil then ring.Size = size end
		if ring.CollisionDamage ~= nil then ring.CollisionDamage = 0 end
		return ring
	end
	local var = LaserVariant.LIGHT_RING or 8
	local sub = (LaserSubType and LaserSubType.LASER_SUBTYPE_RING_FOLLOW_PARENT) or 3
	local ent = Isaac.Spawn(EntityType.ENTITY_LASER, var, sub, air.Position, Vector.Zero, air)
	if not ent then return nil end
	ring = ent:ToLaser()
	if not ring then return nil end
	ring.Parent = air
	ring.SpawnerEntity = air
	ring.SubType = sub
	ring.PositionOffset = po
	if ring.ParentOffset ~= nil then ring.ParentOffset = Vector(0, 0) end
	if ring.Radius ~= nil then ring.Radius = radius end
	if ring.Size ~= nil then ring.Size = size end
	if ring.SpriteScale then ring.SpriteScale = Vector(1, 1) end
	ring.OneHit = false
	if ring.SetDisableFollowParent then
		pcall(function() ring:SetDisableFollowParent(false) end)
	elseif ring.DisableFollowParent ~= nil then
		ring.DisableFollowParent = false
	end
	if ring.SetTimeout then
		ring:SetTimeout(0)
	else
		ring.Timeout = 0
	end
	ring.CollisionDamage = 0
	if ring.MaxDistance ~= nil then ring.MaxDistance = 0 end
	d[item.own_key.."cop_ring"] = ring
	return ring
end

local function mark_zit_tear(tear, air)
	if not tear then return end
	local Hurt = get_hurt_router()
	local td = tear:GetData()
	td[Hurt.own_key.."large_zit"] = true
	local Air = get_air_mod()
	td[Air.own_key.."craft_air"] = air
	td[Air.own_key.."craft_uid"] = craft_uid_of(air)
	tear.Parent = air
	tear.SpawnerEntity = air
end

--- 502：每个基础 volley 一次固定概率额外泪（探针：常规 Variant0，2×伤，粉 Offset 色）
function item.on_volley_fired(air, player, craft_prof, aim_dir)
	if not air or not craft_prof or count_of(craft_prof, IDS.LARGE_ZIT) <= 0 then return end
	if not aim_dir or aim_dir:Length() < 0.01 then return end
	local uid = craft_uid_of(air) or 0
	local shot = tonumber(air:GetData()[get_air_mod().own_key.."shot_serial"]) or air.FrameCount or 0
	local rng = CraftProfile.derived_rng(
		(air.InitSeed or 1) + (tonumber(uid) or 0) * 131,
		502 * 1009 + shot * 17
	)
	if rng:RandomFloat() >= (tonumber(cfg("zit_chance")) or 0.2) then return end
	local ss = (craft_prof.stats and tonumber(craft_prof.stats.shotspeed)) or 1
	local dmg = flight_damage(craft_prof, player) * 2
	local vel = aim_dir:Normalized() * (ss * (tonumber(cfg("zit_speed_mul")) or 10))
	local tear = Isaac.Spawn(
		EntityType.ENTITY_TEAR,
		TearVariant.BLUE or 0,
		0,
		air.Position,
		vel,
		air
	):ToTear()
	if not tear then return end
	tear.CollisionDamage = dmg
	tear.Scale = tonumber(cfg("zit_scale")) or 1.0
	local tint = tonumber(cfg("zit_tint")) or 0.3
	local off = tonumber(cfg("zit_offset")) or 0.7
	tear:SetColor(Color(tint, tint, tint, 1, off, off, off), -1, 1, false, false)
	-- 白水迹由命中/消失回调生成；若引擎认 CREEP_WHITE 则顺带挂上
	if tear.AddTearFlags and TearFlags.TEAR_CREEP_WHITE then
		tear:AddTearFlags(TearFlags.TEAR_CREEP_WHITE)
	end
	mark_zit_tear(tear, air)
end

function item.reset_linger(air)
	if not air then return end
	air:GetData()[item.own_key.."linger_charge"] = 0
end

function item.on_player_hurt(player)
	if not player then return end
	local Air = get_air_mod()
	local bp = get_blueprint()
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, Air.familiar or -1, -1, false, false)) do
		local d = ent:GetData()
		local owner = auxi.check_spawner_player(ent)
		if owner and GetPtrHash(owner) == GetPtrHash(player) and d[bp.own_key.."craft_uid"] then
			item.reset_linger(ent)
		end
	end
end

local function tick_linger(air, player, craft_prof, attacking)
	local d = air:GetData()
	if count_of(craft_prof, IDS.LINGER_BEAN) <= 0 then
		d[item.own_key.."linger_charge"] = nil
		return
	end
	local charge = tonumber(d[item.own_key.."linger_charge"]) or 0
	if attacking then
		charge = charge + 1
	else
		charge = 0
	end
	local need = tonumber(cfg("linger_charge_frames")) or 120
	if charge >= need then
		charge = 0
		local life = tonumber(cfg("linger_life")) or 300
		local cloud = spawn_effect(
			tonumber(cfg("linger_fx_variant")) or (EffectVariant.BROWN_CLOUD or 105),
			tonumber(cfg("linger_fx_subtype")) or 0,
			air.Position,
			Vector.Zero,
			air
		)
		if cloud then
			set_effect_life(cloud, life)
			local cd = cloud:GetData()
			cd[item.own_key.."linger"] = true
			cd[item.own_key.."linger_uid"] = craft_uid_of(air)
			cd[item.own_key.."linger_born"] = Game():GetFrameCount()
			cd[item.own_key.."linger_dmg"] = flight_damage(craft_prof, player)
			cd[item.own_key.."linger_life"] = life
			local key = runtime_key(cloud)
			if key then linger_clouds[key] = cloud end
		end
	end
	d[item.own_key.."linger_charge"] = charge
end

local function tick_linger_clouds()
	local frame = Game():GetFrameCount()
	local tick = math.max(1, math.floor(tonumber(cfg("linger_tick")) or 6))
	local r0 = tonumber(cfg("linger_radius0")) or 40
	local r1 = tonumber(cfg("linger_radius1")) or 90
	local push = tonumber(cfg("linger_push")) or 0.35
	for key, cloud in pairs(linger_clouds) do
		if not (cloud and auxi.check_all_exists(cloud)) then
			linger_clouds[key] = nil
			goto cont
		end
		local cd = cloud:GetData()
		if not cd[item.own_key.."linger"] then
			linger_clouds[key] = nil
			goto cont
		end
		local life = math.max(1, tonumber(cd[item.own_key.."linger_life"]) or 300)
		local age = frame - (tonumber(cd[item.own_key.."linger_born"]) or frame)
		local t = clamp01(age / life)
		local radius = r0 + (r1 - r0) * t
		local dmg_mul = 1 - 0.57 * t
		local base = tonumber(cd[item.own_key.."linger_dmg"]) or 3.5
		cloud.SpriteScale = Vector(radius / 40, radius / 40)
		-- 友方泪推动
		for _, tear_ent in ipairs(Isaac.FindInRadius(cloud.Position, radius + 20, EntityPartition.TEAR)) do
			local tear = tear_ent:ToTear()
			if tear and tear:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) ~= false then
				local friendly = tear:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
					or (tear.SpawnerType == EntityType.ENTITY_PLAYER)
					or (tear.SpawnerType == EntityType.ENTITY_FAMILIAR)
				if friendly and tear.Velocity then
					cloud.Velocity = (cloud.Velocity or Vector.Zero) + tear.Velocity:Resized(math.min(push, tear.Velocity:Length() * 0.05))
				end
			end
		end
		if age % tick == 0 then
			local spawner = cloud.SpawnerEntity
			local allow_hit = true
			if spawner then
				local ok, Air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
				if ok and Air and Air.combat_allowed and not Air.combat_allowed(spawner) then
					allow_hit = false
				end
			end
			if allow_hit then
				local hit = base * dmg_mul
				for _, npc in ipairs(Isaac.FindInRadius(cloud.Position, radius, EntityPartition.ENEMY)) do
					if npc:IsVulnerableEnemy() and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
						npc:TakeDamage(hit, 0, EntityRef(cloud.SpawnerEntity or cloud), 0)
					end
				end
			end
		end
		if age >= life or (cloud.Timeout or 1) <= 0 then
			linger_clouds[key] = nil
			cloud:Remove()
		end
		::cont::
	end
end

local function tick_dead_tooth(air, player, craft_prof, attacking)
	if count_of(craft_prof, IDS.DEAD_TOOTH) <= 0 then
		clear_follow_fx(air, "tooth_fx")
		return
	end
	if not attacking then
		clear_follow_fx(air, "tooth_fx")
		return
	end
	ensure_follow_fx(
		air,
		"tooth_fx",
		tonumber(cfg("tooth_fx_variant")) or (EffectVariant.FART_RING or 106),
		tonumber(cfg("tooth_fx_subtype")) or 0,
		tonumber(cfg("tooth_fx_scale")) or 0.8
	)
	local fx = air:GetData()[item.own_key.."tooth_fx"]
	if fx then
		-- 原版 FART_RING 自带绿环贴图，勿再强行染色；Timeout=-1 由引擎/动画管，每帧续命即可
		set_effect_life(fx, 2)
	end
	local radius = tonumber(cfg("tooth_radius")) or 80
	local dmg = flight_damage(craft_prof, player) * orbital_mul(air)
	local add_ticks = tonumber(cfg("tooth_poison_ticks")) or 2
	local max_ticks = tonumber(cfg("tooth_poison_max")) or 6
	local tick_f = tonumber(cfg("tooth_poison_tick_frames")) or 30
	local apply_dur = add_ticks * tick_f
	local max_dur = max_ticks * tick_f
	for _, npc in ipairs(Isaac.FindInRadius(air.Position, radius, EntityPartition.ENEMY)) do
		if npc:IsVulnerableEnemy() and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
			local nd = npc:GetData()
			local until_f = tonumber(nd[item.own_key.."tooth_poison_until"]) or 0
			local frame = Game():GetFrameCount()
			local remain = math.max(0, until_f - frame)
			if remain < max_dur then
				local next_remain = math.min(max_dur, remain + apply_dur)
				nd[item.own_key.."tooth_poison_until"] = frame + next_remain
				if npc.AddPoison then
					npc:AddPoison(EntityRef(air), apply_dur, dmg)
				end
			end
		end
	end
end

local function absolute_stage()
	local level = Game():GetLevel()
	if level and level.GetAbsoluteStage then
		return tonumber(level:GetAbsoluteStage()) or 1
	end
	return 1
end

local function tick_monstrance(air, player, craft_prof)
	if count_of(craft_prof, IDS.MONSTRANCE) <= 0 then
		clear_follow_fx(air, "monstrance_fx")
		return
	end
	local sub = tonumber(cfg("monstrance_halo_subtype")) or 2
	local fx_scale = tonumber(cfg("monstrance_fx_scale")) or 0.5
	ensure_follow_fx(air, "monstrance_fx", EffectVariant.HALO or 123, sub, fx_scale)
	local radius = tonumber(cfg("monstrance_radius")) or 45
	local interval = math.max(1, math.floor(tonumber(cfg("monstrance_interval")) or 4))
	local d = air:GetData()
	local last = tonumber(d[item.own_key.."monstrance_tick"]) or -999
	local frame = Game():GetFrameCount()
	if frame - last < interval then return end
	d[item.own_key.."monstrance_tick"] = frame
	local stage = absolute_stage()
	local center_base = 3.9 + 0.3 * stage
	local edge_base = 0.4
	local omul = orbital_mul(air)
	for _, npc in ipairs(Isaac.FindInRadius(air.Position, radius, EntityPartition.ENEMY)) do
		if npc:IsVulnerableEnemy() and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
			local dist = (npc.Position - air.Position):Length()
			local t = clamp01(dist / radius)
			local base = center_base + (edge_base - center_base) * t
			npc:TakeDamage(base * omul, 0, EntityRef(air), 0)
		end
	end
end

--- 视觉点：Position + PositionOffset（伪 3D；PO.Y 抬高会参与瞄准角）
local function visual_pos(pos, po)
	pos = pos or Vector(0, 0)
	po = po or Vector(0, 0)
	return Vector(pos.X + po.X, pos.Y + po.Y)
end

--- 探针：EntityLaser ELECTRIC(10)，OneHit，Timeout=2；伤害走激光 CollisionDamage。
--- from_po：本段起点高度（首段=Flight PO+枪口；链跳=上一目标 PO，禁止继续套 Flight 高位）。
local function fire_volt_laser(from_pos, from_po, target, air, dmg, range, blacklist, hops_left)
	if not from_pos or not target or not air then return nil end
	from_po = copy_po(from_po)
	local to_po = copy_po(target.PositionOffset)
	local dir = visual_pos(target.Position, to_po) - visual_pos(from_pos, from_po)
	local leg = dir:Length() + (tonumber(target.Size) or 0)
	if leg < 1 then leg = 1 end
	local laser_var = LaserVariant.ELECTRIC or 10
	local ent = Isaac.Spawn(EntityType.ENTITY_LASER, laser_var, 0, from_pos, Vector.Zero, air)
	if not ent then return nil end
	local q = ent:ToLaser()
	if not q then return nil end
	q.Parent = air
	q.SpawnerEntity = air
	q.Angle = dir:GetAngleDegrees()
	if q.SetMaxDistance then
		q:SetMaxDistance(leg)
	else
		q.MaxDistance = leg
	end
	local life = math.max(1, math.floor(tonumber(cfg("volt_laser_timeout")) or 2))
	if q.SetTimeout then
		q:SetTimeout(life)
	else
		q.Timeout = life
	end
	q.OneHit = true
	q.CollisionDamage = dmg
	-- 整段激光贴起点高度；链跳不得再写 Flight 的高 PO
	q.PositionOffset = from_po
	if q.SetDisableFollowParent then
		pcall(function() q:SetDisableFollowParent(true) end)
	elseif q.DisableFollowParent ~= nil then
		q.DisableFollowParent = true
	end
	q:GetData()[item.own_key.."volt"] = {
		hops = math.max(0, math.floor(tonumber(hops_left) or 0)),
		blacklist = blacklist,
		range = range,
		air = air,
		dmg = dmg,
		-- 下一段从本目标视觉高度出发
		next_from_po = to_po,
		hit_ptr = GetPtrHash(target),
	}
	return q
end

local function pick_volt_target(origin, radius, blacklist)
	local best, best_dist = nil, radius + 1
	for _, npc in ipairs(Isaac.FindInRadius(origin, radius, EntityPartition.ENEMY)) do
		if npc:IsVulnerableEnemy() and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
			local ptr = GetPtrHash(npc)
			if not blacklist[ptr] then
				local dist = (npc.Position - origin):Length()
				if dist < best_dist then
					best, best_dist = npc, dist
				end
			end
		end
	end
	return best
end

local function tick_volt(air, player, craft_prof)
	if count_of(craft_prof, IDS.VOLT) <= 0 then return end
	local d = air:GetData()
	local frame = Game():GetFrameCount()
	local interval = math.max(1, math.floor(tonumber(cfg("volt_interval")) or 6))
	local last = tonumber(d[item.own_key.."volt_tick"]) or -999
	if frame - last < interval then return end
	d[item.own_key.."volt_tick"] = frame
	local radius = tonumber(cfg("volt_radius")) or 80
	local chain_max = math.max(1, math.floor(tonumber(cfg("volt_chain_max")) or 4))
	local dmg = flight_damage(craft_prof, player) * (tonumber(cfg("volt_damage_mul")) or 0.75) * orbital_mul(air)
	-- 玩家脚下瞬时放电（探针：167 比激光早约 1 帧，Timeout=0）
	local spark = spawn_effect(
		tonumber(cfg("volt_fx_variant")) or (EffectVariant.CHAIN_LIGHTNING or 167),
		0,
		air.Position,
		Vector.Zero,
		air
	)
	if spark then
		sync_follow_fx(spark, air, nil)
		set_effect_life(spark, 0)
	end
	local blacklist = {}
	local target = pick_volt_target(air.Position, radius, blacklist)
	if not target then return end
	local ptr = GetPtrHash(target)
	blacklist[ptr] = true
	local hit_dmg = dmg
	if (tonumber(volt_hit_window[ptr]) or -1) == frame then
		hit_dmg = 0 -- 同帧多 Flight：只保留视觉，不叠伤
	else
		volt_hit_window[ptr] = frame
	end
	-- 首段：只用 Flight 视觉高度（volt_laser_po_y 默认 0，不再叠眼高）
	local muzzle = tonumber(cfg("volt_laser_po_y")) or 0
	local from_po = copy_po(air.PositionOffset) + Vector(0, muzzle)
	fire_volt_laser(air.Position, from_po, target, air, hit_dmg, radius, blacklist, chain_max - 1)
	if frame % 30 == 0 then
		for k, f in pairs(volt_hit_window) do
			if (tonumber(f) or 0) < frame - 2 then
				volt_hit_window[k] = nil
			end
		end
	end
end

local function convert_projectile_to_tear(proj, air, craft_prof, player)
	if not proj or not air then return end
	local pos = Vector(proj.Position.X, proj.Position.Y)
	local speed = tonumber(cfg("cop_tear_speed")) or 10
	local vel = proj.Velocity
	if not vel or vel:Length() < 0.01 then
		vel = (air.Position - pos)
		if vel:Length() < 0.01 then vel = Vector(1, 0) end
	end
	vel = vel:Normalized() * speed
	local dmg = flight_damage(craft_prof, player) * orbital_mul(air)
	proj:Remove()
	local tear = Isaac.Spawn(EntityType.ENTITY_TEAR, TearVariant.BLUE or 0, 0, pos, vel, air):ToTear()
	if not tear then return end
	tear.CollisionDamage = dmg
	tear.Parent = air
	tear.SpawnerEntity = air
	tear:SetColor(Color(0.75, 0.35, 1.0, 1, 0.15, 0, 0.25), -1, 1, false, false)
	if tear.AddTearFlags and TearFlags.TEAR_HOMING then
		tear:AddTearFlags(TearFlags.TEAR_HOMING)
	elseif tear.TearFlags ~= nil and TearFlags.TEAR_HOMING then
		tear.TearFlags = tear.TearFlags | TearFlags.TEAR_HOMING
	end
	if tear.AddEntityFlags and EntityFlag.FLAG_FRIENDLY then
		tear:AddEntityFlags(EntityFlag.FLAG_FRIENDLY)
	end
end

local function tick_circle(air, player, craft_prof)
	if count_of(craft_prof, IDS.CIRCLE) <= 0 then
		clear_cop_ring(air)
		return
	end
	ensure_cop_ring(air)
	local radius = tonumber(cfg("cop_radius")) or 80
	local midline = tonumber(cfg("cop_midline")) or 80
	local interval = math.max(1, math.floor(tonumber(cfg("cop_damage_interval")) or 30))
	local d = air:GetData()
	local frame = Game():GetFrameCount()
	local last = tonumber(d[item.own_key.."cop_dmg_tick"]) or -999
	if frame - last >= interval then
		d[item.own_key.."cop_dmg_tick"] = frame
		local dmg = flight_damage(craft_prof, player) * orbital_mul(air)
		for _, npc in ipairs(Isaac.FindInRadius(air.Position, radius, EntityPartition.ENEMY)) do
			if npc:IsVulnerableEnemy() and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
				npc:TakeDamage(dmg, 0, EntityRef(air), 0)
			end
		end
	end
	local chance = tonumber(cfg("cop_reflect_chance")) or 0.30
	local player_key = tostring(player and (player.InitSeed or GetPtrHash(player)) or 0)
	for _, ent in ipairs(Isaac.FindInRadius(air.Position, radius + 16, EntityPartition.BULLET)) do
		local proj = ent:ToProjectile()
		if not proj then goto next_proj end
		if proj:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then goto next_proj end
		-- 第一版只处理标准敌弹
		if proj.Type ~= EntityType.ENTITY_PROJECTILE then goto next_proj end
		local pd = proj:GetData()
		local judged_key = item.own_key.."cop_judged_"..player_key
		local ok_key = item.own_key.."cop_ok_"..player_key
		local owner_key = item.own_key.."cop_owner_"..player_key
		local dist = (proj.Position - air.Position):Length()
		if dist > radius then goto next_proj end
		if not pd[judged_key] then
			pd[judged_key] = true
			pd[owner_key] = craft_uid_of(air) or GetPtrHash(air)
			local uid = tonumber(craft_uid_of(air)) or 0
			local rng = CraftProfile.derived_rng(
				(proj.InitSeed or 1) + uid * 17,
				423 * 1009 + (player and player.InitSeed or 0)
			)
			pd[ok_key] = rng:RandomFloat() < chance
		end
		-- 仅判定所有者的环负责转换（避免多环串联）
		local my_uid = craft_uid_of(air) or GetPtrHash(air)
		if pd[owner_key] ~= my_uid then goto next_proj end
		if pd[ok_key] and dist <= midline and not pd[item.own_key.."cop_converted"] then
			pd[item.own_key.."cop_converted"] = true
			convert_projectile_to_tear(proj, air, craft_prof, player)
		end
		::next_proj::
	end
end

--- Air Flight 每帧：attacking 须含蓄力意图（调用方传 kidney_requested_attack / 统一攻击态）
function item.tick_flight(air, player, craft_prof, attacking)
	if not air or not player or not craft_prof then return end
	tick_linger(air, player, craft_prof, attacking == true)
	tick_dead_tooth(air, player, craft_prof, attacking == true)
	tick_monstrance(air, player, craft_prof)
	tick_volt(air, player, craft_prof)
	tick_circle(air, player, craft_prof)
end

function item.clear_flight(air)
	if not air then return end
	item.reset_linger(air)
	clear_follow_fx(air, "tooth_fx")
	clear_follow_fx(air, "monstrance_fx")
	clear_cop_ring(air)
	local d = air:GetData()
	d[item.own_key.."monstrance_tick"] = nil
	d[item.own_key.."volt_tick"] = nil
	d[item.own_key.."cop_dmg_tick"] = nil
end

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		tick_linger_clouds()
	end,
})

-- 220V 链跳：从 EndPoint 续射；起点 PO 用上一目标高度，禁止再套 Flight 高位
table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_LASER_UPDATE,
	params = nil,
	Function = function(_, laser)
		if not laser then return end
		local vd = laser:GetData()[item.own_key.."volt"]
		if not vd then return end
		local hops = math.floor(tonumber(vd.hops) or 0)
		if hops <= 0 then
			vd.hops = nil
			return
		end
		local air = vd.air
		if not air or not auxi.check_all_exists(air) then
			vd.hops = nil
			return
		end
		do
			local ok, Air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
			if ok and Air and Air.combat_allowed and not Air.combat_allowed(air) then
				vd.hops = nil
				return
			end
		end
		local blacklist = vd.blacklist or {}
		local range = tonumber(vd.range) or (tonumber(cfg("volt_radius")) or 80)
		local origin = laser.EndPoint or laser.Position
		if not origin then
			vd.hops = nil
			return
		end
		local target = pick_volt_target(origin, range, blacklist)
		if not target then
			vd.hops = nil
			return
		end
		local ptr = GetPtrHash(target)
		blacklist[ptr] = true
		local frame = Game():GetFrameCount()
		local hit_dmg = tonumber(vd.dmg) or 0
		if (tonumber(volt_hit_window[ptr]) or -1) == frame then
			hit_dmg = 0
		else
			volt_hit_window[ptr] = frame
		end
		vd.hops = nil -- 本段已消费；下一段自带 hops-1
		local from_po = copy_po(vd.next_from_po) -- 上一命中目标的 PO（地面/敌人高度）
		fire_volt_laser(origin, from_po, target, air, hit_dmg, range, blacklist, hops - 1)
	end,
})

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		volt_hit_window = {}
		linger_clouds = {}
	end,
})

return item
