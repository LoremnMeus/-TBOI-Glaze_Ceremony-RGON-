-- Craft weapon runtime: spawn / decorate / mutate attack entities.
-- Structural extract from craft_combat_profile.lua. No combat semantic changes.
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local attack_holder = require("Qing_Remaster_scripts.callbacks.attack_trigger_holder")
local CraftIdentity = require("Qing_Remaster_scripts.mimics.craft_identity")

local Mod = {}

function Mod.attach(M)

local function profile_fire_opts(context, reason, extra)
	context = context or {}
	extra = extra or {}
	local opts
	if type(context.attack_ctx) == "table" and context.attack_ctx.mode then
		opts = auxi.copy(context.attack_ctx)
	elseif context.attack then
		opts = {
			mode = "inherit",
			attack = context.attack,
			emitter = context.emitter or context.source,
			role = context.role or "derived",
			reason = reason,
		}
	else
		opts = attack_holder.CopyFireContext(reason)
	end
	if not opts then
		local mode = context.fire_mode
		if mode == "inherit" or mode == "untracked" or mode == "new_attack" then
			opts = {
				mode = mode,
				attack = context.attack,
				emitter = context.emitter or context.source,
				role = context.role or "derived",
				reason = reason,
			}
		else
			opts = {
				mode = "untracked",
				reason = reason .. "_orphan",
				emitter = context.emitter or context.source,
				role = context.role or "derived",
			}
		end
	end
	for k, v in pairs(extra) do
		opts[k] = v
	end
	if opts.reason == nil then
		opts.reason = reason
	end
	return opts
end

function M.apply_bomb_item_effects(bomb, profile)
	if not bomb or not profile then return end
	local flags, variant = M.bomb_effects_from_counts(profile.counts, bomb.InitSeed)
	if bomb.AddTearFlags then bomb:AddTearFlags(flags)
	elseif bomb.Flags ~= nil then bomb.Flags = bomb.Flags | flags end
	if variant ~= nil then bomb.Variant = variant end
	local d = bomb:GetData()
	d.QingCraftBombFlags = flags
	d.QingCraftBombVariant = variant
end

--- 条件亮起：效果依赖特定主武器/副 morph 时，未满足则蓝图 UI 变暗（仍可放入）
--- 炸弹类：需博士/史诗为主武器，或配方含 52/168，或含 No. 2（378）/鲍勃脑浆（273）
--- 剖腹产副武器 flag：仅非主 morph 的 FETUS_SEC 条目才门控（主攻击方式如博士/硫磺等始终可亮）
--- 虫群之心（248）：需配方含妈妈的假发（217）
--- 注意：378/273 本身不进 BOMB_EFFECTS / 门控，走 EXTRA_IMPL；但会点亮其它炸弹材料
function M.write_entity_tear_flags(ent, flags)
	if not ent or flags == nil or ent.TearFlags == nil then return end
	local laser = ent.ToLaser and ent:ToLaser()
	if laser and laser.ClearTearFlags then
		local cur = laser.TearFlags
		if cur then
			pcall(function() laser:ClearTearFlags(cur) end)
		end
		if laser.AddTearFlags then
			pcall(function() laser:AddTearFlags(flags) end)
		end
		laser.TearFlags = flags
		return
	end
	ent.TearFlags = flags
end

local function flag_bit(flags, bit)
	return bit and flags and ((flags & bit) == bit)
end

--- FireBrimstone / FireTech* 会把玩家「我的镜像」写进 CurveStrength、「弯勺」写进 HomingType，
--- 与 TearFlags 脱钩；只清 TearFlags 不够。按本次配方 flags 对齐激光运动场。
--- CurveStrength 缺省 1：玩家未持镜像而配方有时，Fire* 不会预填；精确常数可后续探针校准。
function M.apply_laser_craft_motion(ent, tear_flags)
	local laser = ent and ent.ToLaser and ent:ToLaser()
	if not laser then return end
	local flags = tear_flags
	if flags == nil and laser.TearFlags ~= nil then
		flags = laser.TearFlags
	end
	local want_boom = flag_bit(flags, TearFlags and TearFlags.TEAR_BOOMERANG)
	if laser.CurveStrength ~= nil then
		if want_boom then
			if (tonumber(laser.CurveStrength) or 0) == 0 then
				laser.CurveStrength = 1
			end
		else
			laser.CurveStrength = 0
		end
	end
	local want_home = flag_bit(flags, TearFlags and TearFlags.TEAR_HOMING)
	if laser.SetHomingType then
		pcall(function() laser:SetHomingType(want_home and 1 or 0) end)
	elseif laser.HomingType ~= nil then
		laser.HomingType = want_home and 1 or 0
	end
end

--- 制造激光身份：Spawner 改挂 Flight（抑制玩家镜像 CurveStrength 回写），并缓存 flags。
--- Homing sample 随父体移动：就地改 GetSamples 返回的内部 Vector（见 shift_homing_laser_samples）。
--- 权重：近端多拉、末端不动，避免整条路径刚体平移把弯勺尖端拖离目标。
M.CRAFT_LASER_FLAGS_KEY = "qing_craft_laser_flags"
M.CRAFT_LASER_AIR_KEY = "qing_craft_laser_air"
M.CRAFT_LASER_VARIANT_KEY = "qing_craft_laser_variant"
M.CRAFT_LASER_DAMAGE_KEY = "qing_craft_laser_damage"
M.CRAFT_LASER_LAST_POS_KEY = "qing_craft_laser_last_pos"
M.CRAFT_LASER_SAMPLE_PULL = {
	-- 近端「全量跟随」的点数（含 index 0）；之后按幂次衰减到末端
	near_full = 2,
	-- 末端保持不动的点数（至少 1）
	end_keep = 2,
	-- 中间段衰减指数：weight = (1 - u)^power，u 从近端区末端→末端保护区
	mid_power = 2,
}

function M.bind_craft_laser(laser, air, tear_flags, opts)
	if not laser then return end
	laser = laser.ToLaser and laser:ToLaser() or laser
	if not laser then return end
	opts = opts or {}
	local td = laser:GetData()
	if air and auxi.check_all_exists(air) then
		if laser.SpawnerEntity ~= nil then
			laser.SpawnerEntity = air
		end
		td[M.CRAFT_LASER_AIR_KEY] = air
	end
	if tear_flags ~= nil then
		td[M.CRAFT_LASER_FLAGS_KEY] = tear_flags
		M.write_entity_tear_flags(laser, tear_flags)
	elseif td[M.CRAFT_LASER_FLAGS_KEY] == nil and laser.TearFlags ~= nil then
		td[M.CRAFT_LASER_FLAGS_KEY] = laser.TearFlags
	end
	if opts.variant ~= nil then
		td[M.CRAFT_LASER_VARIANT_KEY] = opts.variant
		M.apply_laser_variant_skin(laser, opts.variant)
	end
	if opts.damage ~= nil and laser.CollisionDamage ~= nil then
		td[M.CRAFT_LASER_DAMAGE_KEY] = opts.damage
		laser.CollisionDamage = opts.damage
	end
	M.apply_laser_craft_motion(laser, td[M.CRAFT_LASER_FLAGS_KEY] or tear_flags or laser.TearFlags)
end

--- sample index → 父体位移权重：近端 1、末端 0、中间平滑衰减。
local function sample_pull_weight(index, count, cfg)
	if count <= 1 then return 0 end -- 单点视为末端，不拉（避免尖端跟着飞）
	cfg = cfg or M.CRAFT_LASER_SAMPLE_PULL
	local end_keep = math.max(1, math.floor(tonumber(cfg.end_keep) or 2))
	local near_full = math.max(1, math.floor(tonumber(cfg.near_full) or 2))
	local power = tonumber(cfg.mid_power) or 2
	if power < 1 then power = 1 end
	-- 点数少时压缩保护区，仍保证最后一个点 weight=0
	if count <= end_keep + 1 then
		if index >= count - 1 then return 0 end
		local u = index / math.max(1, count - 2)
		return (1 - u) ^ power
	end
	if index >= count - end_keep then
		return 0
	end
	if index < near_full then
		return 1
	end
	local mid_start = near_full
	local mid_end = count - end_keep - 1
	if mid_end <= mid_start then
		return 0
	end
	local u = (index - mid_start) / (mid_end - mid_start)
	if u < 0 then u = 0 elseif u > 1 then u = 1 end
	return (1 - u) ^ power
end

--- 按父体位移拉动 Homing sample 近端；末端不动；不重 init / 不乒乓 HomingType。
--- RGON 无 SetSamples；GetSamples 返回内部引用，改 .X/.Y 有效（已探针确认）。
--- 返回 true 表示至少写入一点且回读一致。
function M.shift_homing_laser_samples(laser)
	if not laser then return false end
	laser = laser.ToLaser and laser:ToLaser() or laser
	if not laser then return false end
	local td = laser:GetData()
	local pos = laser.Position
	if not pos then return false end
	local last = td[M.CRAFT_LASER_LAST_POS_KEY]
	td[M.CRAFT_LASER_LAST_POS_KEY] = Vector(pos.X, pos.Y)
	if not last then return false end
	local delta = pos - last
	if delta:LengthSquared() < 0.25 then return false end

	local cfg = M.CRAFT_LASER_SAMPLE_PULL
	local function shift_list(getter)
		if not getter then return false end
		local ok, samples = pcall(getter)
		if not ok or not samples or #samples < 1 then return false end
		local n = #samples
		local wrote = false
		for i = 0, n - 1 do
			local w = sample_pull_weight(i, n, cfg)
			if w > 1e-4 then
				local v = samples:Get(i)
				if v and v.X ~= nil then
					local nx = v.X + delta.X * w
					local ny = v.Y + delta.Y * w
					v.X = nx
					v.Y = ny
					local v2 = samples:Get(i)
					if v2 and math.abs((v2.X or 0) - nx) < 0.01 and math.abs((v2.Y or 0) - ny) < 0.01 then
						wrote = true
					end
				end
			end
		end
		return wrote
	end

	local a = shift_list(function() return laser:GetSamples() end)
	local b = false
	if laser.GetNonOptimizedSamples then
		b = shift_list(function() return laser:GetNonOptimizedSamples() end)
	end
	-- 末端不动：EndPoint 与最后 sample 对齐（勿 += delta）
	if laser.GetSamples then
		local ok, samples = pcall(function() return laser:GetSamples() end)
		if ok and samples and #samples > 0 and laser.EndPoint then
			local tip = samples:Get(#samples - 1)
			if tip then
				pcall(function() laser.EndPoint = Vector(tip.X, tip.Y) end)
			end
		end
	end
	td.qing_craft_sample_shift_ok = (a or b) == true
	return td.qing_craft_sample_shift_ok
end

--- POST_LASER_UPDATE 重申：Spawner 挂 Flight + TearFlags / CurveStrength / Variant / 伤害
function M.reassert_craft_laser(laser)
	if not laser then return false end
	laser = laser.ToLaser and laser:ToLaser() or laser
	if not laser then return false end
	local td = laser:GetData()
	local flags = td and td[M.CRAFT_LASER_FLAGS_KEY]
	local var = td and td[M.CRAFT_LASER_VARIANT_KEY]
	local dmg = td and td[M.CRAFT_LASER_DAMAGE_KEY]
	if flags == nil and var == nil and dmg == nil then return false end
	local air = td[M.CRAFT_LASER_AIR_KEY]
	if air and auxi.check_all_exists(air) and laser.SpawnerEntity ~= nil then
		laser.SpawnerEntity = air
	end
	if flags ~= nil then
		M.write_entity_tear_flags(laser, flags)
		M.apply_laser_craft_motion(laser, flags)
	end
	if var ~= nil then
		M.apply_laser_variant_skin(laser, var)
	end
	if dmg ~= nil and laser.CollisionDamage ~= nil then
		laser.CollisionDamage = dmg
	end
	return true
end

function M.apply_flag_mask(ent, profile)
	if not ent or not profile or not profile.flag_mask then return end
	if ent.TearFlags ~= nil then
		M.write_entity_tear_flags(ent, ent.TearFlags & profile.flag_mask)
	end
	M.apply_laser_craft_motion(ent, ent.TearFlags)
end

--- 兼容旧调用：已脱钩 GetTearHitParams；应每颗弹丸带 projectile_index / init_seed。
function M.apply_tear_stats(ent, profile, dmg_mul, tear_flags, opts)
	if not ent or not profile or not profile.stats then return end
	dmg_mul = dmg_mul or 1
	opts = opts or {}
	if ent.CollisionDamage ~= nil then
		local dmg = (profile.stats.damage + (opts.damage_add or 0)) * (opts.damage_mul or 1)
		ent.CollisionDamage = dmg * dmg_mul
	end
	if tear_flags ~= nil and ent.TearFlags ~= nil then
		M.write_entity_tear_flags(ent, tear_flags)
		M.apply_laser_craft_motion(ent, tear_flags)
	else
		M.apply_flag_mask(ent, profile)
	end
end

-- ---------- 制造命名：空行 + 附加型号（TARGET_BASE 仍可扩展其他底盘前缀）----------
function M.apply_fetus_sec_flags(ent, profile)
	if not ent or not profile or not profile.counts then return end
	for id, flg in pairs(M.FETUS_SEC_FLAGS) do
		if (profile.counts[id] or 0) > 0 then
			ent.TearFlags = ent.TearFlags | flg
		end
	end
end

-- ---------- §15 小攻击方式：巧克力奶 / 诅咒之眼 / 血泪症 ----------
-- 一根共享 main_charge_ratio：各机制声明 accepted domain → UI 投影到并集 →
-- 各机制再投影到自己的 domain。cooldown = max(各机制 required delay)。

function M.craft_brimstone_variant(profile)
	local syn = (profile and profile.synergy) or {}
	if syn.brim_tech then
		if syn.thick_brim and LaserVariant and LaserVariant.THICKER_BRIM_TECH then
			return LaserVariant.THICKER_BRIM_TECH
		end
		return (LaserVariant and LaserVariant.BRIM_TECH) or 9
	end
	if syn.thick_brim then
		return (LaserVariant and LaserVariant.THICKER_RED) or 11
	end
	return (LaserVariant and LaserVariant.THICK_RED) or 1
end

--- 激光 Variant → 原版 anm2（事后改 Variant 不换皮，须 Load）。
local LASER_VARIANT_ANM2 = {
	[1] = "gfx/007.001_thick red laser.anm2",
	[2] = "gfx/007.002_thin red laser.anm2",
	[3] = "gfx/007.003_shoop laser.anm2",
	[6] = "gfx/007.006_giant red laser.anm2",
	[9] = "gfx/007.009_brimtech.anm2",
	[11] = "gfx/007.011_thicker red laser.anm2",
	[14] = "gfx/007.014_thicker red laser tech.anm2",
	[15] = "gfx/007.015_giant red laser tech.anm2",
}

--- FireBrimstone 后按配方换皮：写 Variant + Load 对应 anm2。保留 Fire* 的「玩家发射硫磺」兼容链。
function M.apply_laser_variant_skin(laser, variant, anim)
	if not laser or variant == nil then return false end
	laser = laser.ToLaser and laser:ToLaser() or laser
	if not laser then return false end
	local path = LASER_VARIANT_ANM2[variant]
	laser.Variant = variant
	if not path then return false end
	local s = laser.GetSprite and laser:GetSprite()
	if not s or not s.Load then return false end
	local cur = s.GetFilename and s:GetFilename()
	if cur and cur:lower() == path:lower() then
		return true
	end
	s:Load(path, true)
	if anim == false then
		return true
	end
	anim = (type(anim) == "string" and anim ~= "") and anim or "LargeRedLaser"
	if s.Play then
		if not pcall(function()
			s:Play(anim, true)
		end) then
			pcall(function()
				s:Play("Laser", true)
			end)
		end
	end
	return true
end

--- 用 FireBrimstone 生成（保留玩家硫磺兼容），再按配方换皮。勿用 ShootAngle 当主路径。
--- opts: {profile, air, player, dir, position, position_offset, timeout, damage_mul}
--- 返回 laser, variant
function M.spawn_craft_brimstone(opts)
	opts = opts or {}
	local profile = opts.profile
	local air = opts.air
	local player = opts.player
	if not player or not player.FireBrimstone then return nil, M.craft_brimstone_variant(profile) end
	local dir = opts.dir or Vector(1, 0)
	if dir:Length() < 0.01 then
		dir = Vector(1, 0)
	else
		dir = dir:Normalized()
	end
	local var = M.craft_brimstone_variant(profile)
	local pos = opts.position
	if not pos and air then pos = air.Position end
	if not pos then pos = player.Position end
	local po = opts.position_offset or Vector(0, 0)
	local timeout = opts.timeout
	if timeout == nil then timeout = 30 end
	local dmg_mul = opts.damage_mul
	if dmg_mul == nil then dmg_mul = 1 end
	local source = air or player
	local laser = attack_holder.FireBrimstone(player, dir, profile_fire_opts(opts, "craft_spawn_brimstone", {
		source_entity = source,
		damage_multiplier = dmg_mul,
		emitter = air or opts.emitter,
	}))
	if not laser then return nil, var end
	laser = laser:ToLaser() or laser
	laser.Parent = air or laser.Parent
	laser.Position = pos
	if laser.PositionOffset ~= nil then
		laser.PositionOffset = po
	end
	if laser.ParentOffset ~= nil then
		laser.ParentOffset = Vector(0, 0)
	end
	if air and laser.SpawnerEntity ~= nil then
		laser.SpawnerEntity = air
	end
	if air then
		if laser.SetDisableFollowParent then
			laser:SetDisableFollowParent(false)
		elseif laser.DisableFollowParent ~= nil then
			laser.DisableFollowParent = false
		end
	end
	M.apply_laser_variant_skin(laser, var)
	if laser.SetTimeout and timeout then
		laser:SetTimeout(timeout)
	end
	return laser, var
end

--- 按配方选 Tech X 环 Variant：plain=细红科技；brim_techx=硫磺科技环。禁止继承玩家装备外观。
function M.craft_techx_variant(profile)
	local syn = (profile and profile.synergy) or {}
	if syn.brim_techx then
		if syn.thick_brim and LaserVariant and LaserVariant.THICKER_BRIM_TECH then
			return LaserVariant.THICKER_BRIM_TECH
		end
		return (LaserVariant and LaserVariant.BRIM_TECH) or 9
	end
	return (LaserVariant and LaserVariant.THIN_RED) or 2
end

--- FireTechXLaser 后按配方换皮。opts: profile, air, player, dir, radius, position, position_offset, damage_mul, timeout
--- Radius 语义：60 * charge_ratio（再乘 projectile_scale）。厚度：factory raw 为 vanilla 一半，
--- 见 normalize_craft_techx_scale（SetScale×2）；勿手写 SpriteScale/Size。
local function normalize_craft_techx_scale(laser)
	-- Craft Tech X factory normalization only — restores vanilla thickness after FireTechXLaser.
	-- Not a gameplay size modifier; not for replay/copy paths. See craft_techx_radius_thickness.md.
	if not laser or not laser.GetScale or not laser.SetScale then
		return
	end
	local ok, scale = pcall(function()
		return laser:GetScale()
	end)
	scale = ok and tonumber(scale) or nil
	if scale and scale > 0 then
		pcall(function()
			laser:SetScale(scale * 2)
		end)
	end
end

function M.spawn_craft_techx(opts)
	opts = opts or {}
	local profile = opts.profile
	local air = opts.air
	local player = opts.player
	if not player or not player.FireTechXLaser then
		return nil, M.craft_techx_variant(profile)
	end
	local dir = opts.dir or Vector(1, 0)
	if dir:Length() < 0.01 then
		dir = Vector(1, 0)
	end
	local var = M.craft_techx_variant(profile)
	local pos = opts.position
	if not pos and air then pos = air.Position end
	if not pos then pos = player.Position end
	local po = opts.position_offset or Vector(0, 0)
	local rad = tonumber(opts.radius) or 60
	local dmg_mul = opts.damage_mul
	if dmg_mul == nil then dmg_mul = 1 end
	local source = air or player
	local reason = opts.reason or "craft_spawn_techx"
	local laser = attack_holder.FireTechXLaser(player, pos, dir, rad, profile_fire_opts(opts, reason, {
		source_entity = source,
		damage_multiplier = dmg_mul,
		emitter = air or opts.emitter,
	}))
	if not laser then return nil, var end
	laser = laser:ToLaser() or laser
	normalize_craft_techx_scale(laser)
	laser.Parent = air or laser.Parent
	laser.Position = pos
	if laser.PositionOffset ~= nil then
		laser.PositionOffset = po
	end
	if laser.ParentOffset ~= nil then
		laser.ParentOffset = Vector(0, 0)
	end
	if air and laser.SpawnerEntity ~= nil then
		laser.SpawnerEntity = air
	end
	if air then
		if laser.SetDisableFollowParent then
			laser:SetDisableFollowParent(false)
		elseif laser.DisableFollowParent ~= nil then
			laser.DisableFollowParent = false
		end
	end
	-- 环动画不要强行 LargeRedLaser
	M.apply_laser_variant_skin(laser, var, false)
	local td = laser:GetData()
	td[M.CRAFT_LASER_VARIANT_KEY] = var
	if laser.CollisionDamage ~= nil then
		td[M.CRAFT_LASER_DAMAGE_KEY] = laser.CollisionDamage
	end
	if air then
		M.bind_craft_laser(laser, air, laser.TearFlags, {
			variant = var,
			damage = laser.CollisionDamage,
		})
	end
	if opts.timeout and laser.SetTimeout then
		laser:SetTimeout(opts.timeout)
	end
	return laser, var
end

function M.decorate_brimstone(laser, profile, ent, player, dir, fire_pos)
	if not laser or not profile then return end
	local syn = profile.synergy or {}
	local var = M.craft_brimstone_variant(profile)
	M.apply_laser_variant_skin(laser, var)
	local mul = M.brimstone_synergy_mul(profile)
	if mul ~= 1 and laser.CollisionDamage ~= nil then
		laser.CollisionDamage = laser.CollisionDamage * mul
	end
	M.apply_flag_mask(laser, profile)
	local td = laser:GetData()
	td.qing_craft_brim_tech = syn.brim_tech == true
	td.qing_craft_thick_brim = syn.thick_brim == true
	td.qing_craft_syn_mul = mul
	local bind_opts = {
		variant = var,
		damage = laser.CollisionDamage,
	}
	if ent then
		M.bind_craft_laser(laser, ent, laser.TearFlags, bind_opts)
	else
		td[M.CRAFT_LASER_VARIANT_KEY] = var
		if laser.CollisionDamage ~= nil then
			td[M.CRAFT_LASER_DAMAGE_KEY] = laser.CollisionDamage
		end
	end
end

--- 配方弹体尺寸 × 巧克力尺寸倍率（博士炸弹 / 泪弹共用）
function M.projectile_scale(profile, atk_mods)
	local base = 1
	if profile and profile.stats and profile.stats.scale then
		base = tonumber(profile.stats.scale) or 1
	end
	local choco = 1
	if atk_mods and atk_mods.size_mul then
		choco = tonumber(atk_mods.size_mul) or 1
	end
	return math.max(0.12, base * choco)
end

function M.apply_bomb_scale(bomb, scale)
	if not bomb or not scale then return end
	scale = math.max(0.12, tonumber(scale) or 1)
	if bomb.SetScale then
		bomb:SetScale(scale)
		if bomb.SetLoadCostumes then bomb:SetLoadCostumes(true) end
	end
	if bomb.SpriteScale ~= nil then
		bomb.SpriteScale = Vector(scale, scale)
	end
	local spr = bomb.GetSprite and bomb:GetSprite()
	if spr and spr.Scale then
		spr.Scale = Vector(scale, scale)
	end
	if bomb.RadiusMultiplier ~= nil then
		bomb.RadiusMultiplier = scale
	end
end

--- 泪弹设绝对 Scale；炸弹走 SetScale；激光半径由发射点自行乘
function M.apply_projectile_scale(ent, scale)
	if not ent or not scale then return end
	scale = math.max(0.12, tonumber(scale) or 1)
	if ent.ToBomb and ent:ToBomb() then
		M.apply_bomb_scale(ent:ToBomb(), scale)
		return
	end
	if ent.ToLaser and ent:ToLaser() then
		return
	end
	if ent.Scale ~= nil then
		ent.Scale = scale
	elseif ent.SpriteScale ~= nil then
		ent.SpriteScale = Vector(scale, scale)
	end
end

function M.apply_size_mul(ent, size_mul)
	if not ent or not size_mul or size_mul == 1 then return end
	if ent.Scale ~= nil then ent.Scale = ent.Scale * size_mul end
	if ent.SpriteScale ~= nil then
		ent.SpriteScale = Vector(ent.SpriteScale.X * size_mul, ent.SpriteScale.Y * size_mul)
	end
	if ent.Radius ~= nil then ent.Radius = ent.Radius * size_mul end
end

function M.clear_craft_haemo_burst_flag(tear)
	if not tear or not TearFlags or not TearFlags.TEAR_BURSTSPLIT then return end
	if tear.ClearTearFlags then
		tear:ClearTearFlags(TearFlags.TEAR_BURSTSPLIT)
	end
	if tear.TearFlags ~= nil then
		tear.TearFlags = tear.TearFlags & ~TearFlags.TEAR_BURSTSPLIT
	end
end

function M.mark_craft_haemo_tear(tear, profile, player, context)
	if not tear or not M.profile_has_haemolacria(profile) then return end
	local d = tear:GetData()
	if d.craft_haemo_child or d.craft_no_haemo then return end
	context = context or {}
	local mode = context.mode or M.haemo_burst_mode(profile)
	d.craft_haemo = {
		profile = profile,
		player = player,
		mods = context.mods,
		dir = context.dir,
		damage = context.damage,
		mode = mode,
	}
	-- 必须清掉引擎/玩家继承的 BURSTSPLIT，否则落地会再喷一波原版小血泪
	M.clear_craft_haemo_burst_flag(tear)
end

--- 主血泪终结时触发（ENTITY_REMOVE / 碰撞兜底）；子泪与已触发跳过
--- opts.force：允许卢多概率路径显式触发（默认忽略带 ludo_proc 的标记，避免控泪移除时误爆）
function M.try_trigger_craft_haemo_tear(tear, opts)
	if not tear then return false end
	local d = tear:GetData()
	if not d or not d.craft_haemo or d.craft_haemo_done or d.craft_haemo_child or d.craft_no_haemo then
		return false
	end
	local ch = d.craft_haemo
	if ch.ludo_proc and not (opts and opts.force) then
		return false
	end
	-- 触发前再清一次，避免碰撞帧原版仍读到 BURSTSPLIT
	M.clear_craft_haemo_burst_flag(tear)
	d.craft_haemo_done = true
	local profile = ch.profile
	local player = ch.player
	local dir = ch.dir
	if (not dir or dir:Length() < 0.01) and tear.Velocity then
		dir = tear.Velocity
	end
	local mode = ch.mode or M.haemo_burst_mode(profile)
	M.spawn_craft_haemolacria_burst(profile, tear.Position, dir, tear, {
		player = player,
		damage_mul = nil,
		parent_damage = ch.damage or tear.CollisionDamage,
		size_mul = tear.Scale,
		mods = ch.mods,
		mode = mode,
	})
	return true
end

--- 卢多控泪有效伤害 tick：低概率血泪爆发（伤害继承攻击实体 CollisionDamage）
function M.try_ludo_haemo_burst(attack, target, profile, player, context)
	if not attack or not target or not M.profile_has_haemolacria(profile) then return false end
	local ex = profile.extras or {}
	if not ex.haemo_ludo_proc and not (ex.haemolacria and (profile.weapon or 1) == 8) then
		return false
	end
	context = context or {}
	local luck = tonumber(context.luck) or tonumber(profile.stats and profile.stats.luck) or 0
	local chance = tonumber(M.HAEMO_LUDO_BURST_CHANCE) or 0.12
	chance = math.min(0.35, math.max(0.02, chance + luck * 0.01))
	local seed = (attack.InitSeed or 0)
		+ (target.InitSeed or 0)
		+ (Game():GetFrameCount() or 0) * 17
		+ (tonumber(context.shot_serial) or 0) * 131
	local rng = M.derived_rng(seed, 531 * 65537 + (tonumber(context.projectile_index) or 1))
	if rng:RandomFloat() >= chance then return false end
	local dir = context.dir
	if (not dir or dir:Length() < 0.01) and attack.Velocity then
		dir = attack.Velocity
	end
	if not dir or dir:Length() < 0.01 then dir = Vector(1, 0) end
	local dmg = tonumber(context.parent_damage)
	if not dmg or dmg <= 0 then
		dmg = tonumber(attack.CollisionDamage)
	end
	if (not dmg or dmg <= 0) and profile.stats then
		dmg = tonumber(profile.stats.damage) or 3.5
	end
	M.spawn_craft_haemolacria_burst(profile, target.Position, dir, attack, {
		player = player,
		parent_damage = dmg,
		size_mul = context.size_mul or attack.Scale or 1,
		mods = context.mods,
		-- 侧车：各 guest 均分面额后套自身倍率（含妈刀 3–6 全向）
		mode = "shared",
	})
	return true
end

--- 卢多泪血泪染色（Colorize；Tint 保持白）
function M.apply_haemo_ludo_color(tear)
	if not tear or not tear.SetColor then return end
	local c = Color(1, 1, 1, 1, 0, 0, 0)
	if c.SetColorize then
		c:SetColorize(0.9, 0.12, 0.12, 1)
	end
	tear:SetColor(c, -1, 1, false, false)
end

local function haemo_child_flags(profile, context)
	local flags = context.tear_flags
	if flags == nil then flags = profile.flag_mask or BitSet128(0, 0) end
	if TearFlags and TearFlags.TEAR_BURSTSPLIT then
		flags = flags & ~TearFlags.TEAR_BURSTSPLIT
	end
	return flags
end

--- 爆裂子弹分摊：妈刀 / 剑泪 与眼泪并列成独立 mode，各掷自身区间再按 mode 数均分面额
--- 若妈刀已是主泪均分 guest，则 tears burst 不再带刀
local function haemo_child_mode_plan(profile)
	local list = profile and profile.list or {}
	local modes = {"tears"}
	local knife_share = M.haemo_knife_is_share_guest(profile)
	if (list.knife or 0) > 0 and not knife_share then
		modes[#modes + 1] = "knife"
	end
	if (list.sword or 0) > 0 then
		modes[#modes + 1] = "sword"
	end
	local n = #modes
	local plan = {}
	for _, mode in ipairs(modes) do
		local base = M.haemo_roll_mode_count(mode)
		plan[#plan + 1] = {
			mode = mode,
			count = M.haemo_scale_mode_count(base, n),
		}
	end
	return plan
end

local function spawn_haemo_knife_child(profile, position, direction, player, context, damage, opts)
	opts = opts or {}
	local shot
	if opts.full_spread then
		shot = auxi.MakeVector(math.random() * 360)
	else
		local dir = direction
		if not dir or dir:Length() < 0.01 then dir = Vector(1, 0) end
		dir = dir:Normalized()
		local ang = (math.random(1200) / 10) - 60
		shot = auxi.get_by_rotate(dir, ang)
	end
	local flags = haemo_child_flags(profile, context)
	local params = {
		cooldown = 40,
		Accerate = 0.85,
		player = player,
		tearflags = flags,
		hold_knife_path = true,
		PosOffset = Vector(0, -8),
	}
	local q = auxi.fire_knife(position, shot, damage, nil, params)
	if q then
		q:Shoot(1, 40 + math.random(30))
		local qd = q:GetData()
		qd.craft_haemo_child = true
		qd.craft_no_haemo = true
		if q.Parent and q.Parent.GetData then
			local pd = q.Parent:GetData()
			pd.craft_haemo_child = true
			pd.craft_no_haemo = true
		end
	end
	return q
end

local function spawn_haemo_sword_tear_child(profile, position, direction, player, context, damage, size_mul)
	local dir = direction
	if not dir or dir:Length() < 0.01 then dir = Vector(1, 0) end
	dir = dir:Normalized()
	local stats = profile.stats or M.BASE_STATS
	local shotspeed = tonumber(stats.shotspeed) or 1
	local ang = (math.random(1200) / 10) - 60
	local spd = 3 + (math.random(1000) / 1000) * (shotspeed * 10)
	local vel = auxi.get_by_rotate(dir, ang) * spd
	local q = attack_holder.FireTear(player, position, vel, profile_fire_opts(context, "craft_haemo_sword_child", {
		can_be_eye = false,
		no_tracer = true,
		can_trigger_streak_end = false,
	}))
	if not q then return nil end
	local want = TearVariant.SWORD_BEAM or 47
	if q.ChangeVariant and q.Variant ~= want then
		q:ChangeVariant(want)
		if q.ResetSpriteScale then q:ResetSpriteScale() end
	end
	q.CollisionDamage = damage
	q.TearFlags = haemo_child_flags(profile, context)
	if q.ClearTearFlags and TearFlags and TearFlags.TEAR_BURSTSPLIT then
		q:ClearTearFlags(TearFlags.TEAR_BURSTSPLIT)
	end
	q.Scale = (0.7 + (math.random(250) / 1000)) * math.max(0.35, (size_mul or 1) * 0.7)
	q.FallingAcceleration = 0.8
	q.FallingSpeed = -8.9 + auxi.random_2() * 2
	local qd = q:GetData()
	qd.craft_haemo_child = true
	qd.craft_no_haemo = true
	return q
end

local function spawn_haemo_tear_children(profile, position, direction, player, context, forced_count)
	local stats = profile.stats or M.BASE_STATS
	local parent_dmg = tonumber(context.parent_damage)
	local size_mul = context.size_mul or 1
	local tear_count = tonumber(forced_count)
	if not tear_count then
		-- 仅眼泪，或与刀/剑并列时由 plan 拆开；此处只发眼泪份
		local plan = haemo_child_mode_plan(profile)
		local knife_n, sword_n = 0, 0
		for _, p in ipairs(plan) do
			if p.mode == "tears" then tear_count = p.count end
			if p.mode == "knife" then knife_n = p.count end
			if p.mode == "sword" then sword_n = p.count end
		end
		tear_count = tear_count or M.haemo_roll_mode_count("tears")
		-- 刀/剑在本函数末尾按自身份发射（全向刀）
		context._haemo_plan_knife = knife_n
		context._haemo_plan_sword = sword_n
	end
	local dir = direction
	if not dir or dir:Length() < 0.01 then dir = Vector(1, 0) end
	dir = dir:Normalized()
	local flags = haemo_child_flags(profile, context)
	local shotspeed = tonumber(stats.shotspeed) or 1
	local mods = context.mods or {}
	local dmg_mul = tonumber(mods.damage_mul) or 1
	local stats_dmg = (tonumber(stats.damage) or 3.5) * (tonumber(context.damage_mul) or 0.66) * dmg_mul

	local function child_dmg()
		if parent_dmg and parent_dmg > 0 then
			return parent_dmg * (0.5 + math.random() * (1 / 3))
		end
		return stats_dmg
	end

	for _ = 1, tear_count or 0 do
		local ang = (math.random(1200) / 10) - 60
		local spd = 3 + (math.random(1000) / 1000) * (shotspeed * 10)
		local vel = auxi.get_by_rotate(dir, ang) * spd
		local q = attack_holder.FireTear(player, position, vel, profile_fire_opts(context, "craft_haemo_tear_child", {
			can_be_eye = false,
			no_tracer = true,
			can_trigger_streak_end = false,
		}))
		if q then
			if q.ChangeVariant then q:ChangeVariant(TearVariant.BLOOD) end
			q.CollisionDamage = child_dmg()
			q.TearFlags = flags
			if q.ClearTearFlags and TearFlags and TearFlags.TEAR_BURSTSPLIT then
				q:ClearTearFlags(TearFlags.TEAR_BURSTSPLIT)
			end
			q.Scale = (0.55 + (math.random(350) / 1000)) * math.max(0.35, size_mul * 0.55)
			local qd = q:GetData()
			qd.craft_haemo_child = true
			qd.craft_no_haemo = true
		end
	end
	local knife_n = tonumber(context._haemo_plan_knife) or 0
	local sword_n = tonumber(context._haemo_plan_sword) or 0
	context._haemo_plan_knife = nil
	context._haemo_plan_sword = nil
	for _ = 1, knife_n do
		spawn_haemo_knife_child(profile, position, dir, player, context, child_dmg(), {full_spread = true})
	end
	for _ = 1, sword_n do
		spawn_haemo_sword_tear_child(profile, position, dir, player, context, child_dmg(), size_mul)
	end
end

local function spawn_haemo_brim_burst(profile, position, direction, player, context, forced_count)
	local parent_dmg = tonumber(context.parent_damage) or ((profile.stats and profile.stats.damage) or 3.5)
	local count = tonumber(forced_count) or M.haemo_roll_mode_count("brim")
	local syn = profile.synergy or {}
	local air = context.source
	for _ = 1, count do
		-- 真随机方向（非均分圆）；按配方 Variant 生成，避免继承玩家科技硫磺外观
		local shot = auxi.MakeVector(math.random() * 360)
		local q = M.spawn_craft_brimstone({
			profile = profile,
			air = (air and air.ToFamiliar and air:ToFamiliar()) and air or nil,
			player = player,
			dir = shot,
			position = position,
			position_offset = Vector(0, 0),
			timeout = 9,
			attack = context.attack,
			attack_ctx = context.attack_ctx,
			fire_mode = context.fire_mode,
			emitter = context.emitter or air,
		})
		if q then
			q.Parent = air or player
			q.CollisionDamage = parent_dmg
			if syn.thick_brim and q.SpriteScale then
				q.SpriteScale = Vector(1.35, 1.35)
			end
			-- 始终 decorate：强制 Variant + brim_tech/双硫磺加伤；无 synergy 时 mul=1
			M.decorate_brimstone(q, profile, air, player, shot, position)
			if q.SetTimeout then q:SetTimeout(9) end -- 探针：Timeout=9
			local qd = q:GetData()
			qd.craft_haemo_child = true
			qd.craft_no_haemo = true
		end
	end
end

local function spawn_haemo_tech_burst(profile, position, direction, player, context, forced_count)
	local parent_dmg = tonumber(context.parent_damage) or ((profile.stats and profile.stats.damage) or 3.5)
	local count = tonumber(forced_count) or M.haemo_roll_mode_count("tech")
	for _ = 1, count do
		local shot = auxi.MakeVector(math.random() * 360)
		local q = attack_holder.FireTechLaser(player, position, shot, profile_fire_opts(context, "craft_haemo_tech_burst", {
			offset_id = 0,
			left_eye = false,
			one_hit = true,
		}))
		if q then
			q.CollisionDamage = parent_dmg
			M.apply_flag_mask(q, profile)
			if q.SetTimeout then q:SetTimeout(2) end -- 探针：Timeout=2
			local qd = q:GetData()
			qd.craft_haemo_child = true
			qd.craft_no_haemo = true
		end
	end
end

local function spawn_haemo_techx_burst(profile, position, direction, player, context, forced_count)
	local parent_dmg = tonumber(context.parent_damage) or ((profile.stats and profile.stats.damage) or 3.5)
	local count = tonumber(forced_count) or M.haemo_roll_mode_count("techx")
	local mods = context.mods or {}
	local base_r = 40 * (tonumber(mods.techx_radius_mul) or 1)
	local air = context.source
	for _ = 1, count do
		local rad = base_r * (0.55 + math.random() * 0.9) -- 探针约 22..80
		local vel = auxi.MakeVector(math.random() * 360) * (0.8 + math.random() * 1.4)
		local q = M.spawn_craft_techx({
			profile = profile,
			air = air,
			player = player,
			dir = vel,
			radius = rad,
			position = position,
			position_offset = Vector(0, 0),
			damage_mul = 1,
			attack = context.attack,
			attack_ctx = context.attack_ctx,
			fire_mode = context.fire_mode,
			emitter = context.emitter or air,
			reason = "craft_haemo_techx_burst",
			techx_radius_mul = mods.techx_radius_mul,
			projectile_scale = mods.projectile_scale or mods.proj_scale,
			main_charge_ratio = profile and profile.main_charge_ratio,
			techx_charge_ratio = profile and profile.techx_charge_ratio,
			craft_uid = air and CraftIdentity.get_uid(air),
		})
		if q then
			q.CollisionDamage = parent_dmg
			M.apply_flag_mask(q, profile)
			local qd = q:GetData()
			qd.craft_haemo_child = true
			qd.craft_no_haemo = true
		end
	end
end

--- 博士+血泪：小炸弹（吃档案伤害/flag/倍率）
--- 探针：Size=8、RadiusMul≈0.65、水平速≈3–6；上飞为 PO.Y 抛物线（Y0=-3，vy+=0.8）
local function spawn_haemo_bomb_burst(profile, position, direction, player, context, forced_count)
	local parent_dmg = tonumber(context.parent_damage) or ((profile.stats and profile.stats.damage) or 3.5)
	local mods = context.mods or {}
	local dmg_mul = tonumber(mods.damage_mul) or 1
	-- 低于博士主武满伤：半伤 × 蓄力等倍率（仍吃 tear/bomb flag）
	local bomb_dmg = parent_dmg * 0.5 * dmg_mul
	local count = tonumber(forced_count) or M.haemo_roll_mode_count("bombs")
	local size = 0.65 * (tonumber(mods.size_mul) or 1)
	for _ = 1, count do
		-- 连续角真随机，避免整数角/均分观感
		local ang = math.random() * 360
		local spd = 3 + math.random() * 3 -- ≈3..6
		local vel = auxi.MakeVector(ang) * spd
		local q = attack_holder.FireBomb(player, position, vel, profile_fire_opts(context, "craft_haemo_bomb_burst", {
			source_entity = player,
		}))
		if q then
			q.ExplosionDamage = bomb_dmg
			-- 探针：首帧 PO.Y=-3；之后由 Bomb_holder 按 vy+=0.8 积分上飞
			q.PositionOffset = Vector(0, -3)
			if q.RadiusMultiplier ~= nil then q.RadiusMultiplier = size end
			M.apply_bomb_scale(q, size)
			local Bomb_holder = require("Qing_Remaster_scripts.mimics.Bomb_holder")
			Bomb_holder.attach_craft_aux(q, profile, player, {
				damage_mul = 0.5 * dmg_mul,
				size_mul = size,
			})
			local craft = q:GetData()[Bomb_holder.own_key .. "craft"]
			if craft then
				-- 血泪子炸弹不再二次爆血泪
				craft.haemo = false
				-- vy0 ≈ -3.5..-8（探针首帧ΔY）；apex≈第7–8帧
				craft.hae_jump = {
					y = -3,
					vy = -(3.5 + math.random() * 4.5),
					accel = 0.8,
					done = false,
				}
			end
			local qd = q:GetData()
			qd.craft_haemo_child = true
			qd.craft_no_haemo = true
			qd.craft_bomb = true
		end
	end
end

local function spawn_haemo_knife_burst(profile, position, direction, player, context, forced_count)
	local total = tonumber(forced_count) or M.haemo_roll_mode_count("knife")
	local stats = profile.stats or M.BASE_STATS
	local parent_dmg = tonumber(context.parent_damage)
	local dmg_mul = tonumber((context.mods or {}).damage_mul) or 1
	local stats_dmg = (tonumber(stats.damage) or 3.5) * (tonumber(context.damage_mul) or 0.66) * dmg_mul
	local function child_dmg()
		if parent_dmg and parent_dmg > 0 then
			return parent_dmg * (0.5 + math.random() * (1 / 3))
		end
		return stats_dmg
	end
	for _ = 1, total do
		-- 全向散射；禁止 ±60° 锥里堆在同一侧
		spawn_haemo_knife_child(profile, position, direction, player, context, child_dmg(), {full_spread = true})
	end
end

local function spawn_haemo_mode(mode, profile, position, direction, player, context, forced_count)
	if mode == "brim" then
		spawn_haemo_brim_burst(profile, position, direction, player, context, forced_count)
	elseif mode == "tech" then
		spawn_haemo_tech_burst(profile, position, direction, player, context, forced_count)
	elseif mode == "techx" then
		spawn_haemo_techx_burst(profile, position, direction, player, context, forced_count)
	elseif mode == "bombs" then
		spawn_haemo_bomb_burst(profile, position, direction, player, context, forced_count)
	elseif mode == "knife" then
		spawn_haemo_knife_burst(profile, position, direction, player, context, forced_count)
	elseif mode == "sword" then
		local n = tonumber(forced_count) or M.haemo_roll_mode_count("sword")
		local stats = profile.stats or M.BASE_STATS
		local parent_dmg = tonumber(context.parent_damage) or (tonumber(stats.damage) or 3.5)
		local function cd()
			return parent_dmg * (0.5 + math.random() * (1 / 3))
		end
		for _ = 1, n do
			spawn_haemo_sword_tear_child(profile, position, direction, player, context, cd(), context.size_mul or 1)
		end
	else
		spawn_haemo_tear_children(profile, position, direction, player, context, forced_count)
	end
end

--- 统一血泪 burst：按档案 mode 自模拟产物，不依赖 TEAR_BURSTSPLIT / 玩家背包
--- mode="shared"：侧车（卢多等）一次触发，对各 guest 均分面额后套各自倍率
function M.spawn_craft_haemolacria_burst(profile, position, direction, source, context)
	if not M.profile_has_haemolacria(profile) then return end
	if not position then return end
	context = context or {}
	context.source = source
	local player = context.player
	if not player and source then
		if source.ToPlayer then player = source:ToPlayer() end
		if not player then player = auxi.check_spawner_player(source) end
	end
	if not player then return end
	local mode = context.mode or M.haemo_burst_mode(profile)
	if mode == "shared" or mode == "multi" then
		local modes = M.haemo_burst_guest_modes(profile)
		local n = #modes
		for _, m in ipairs(modes) do
			local base = M.haemo_roll_mode_count(m)
			local c = M.haemo_scale_mode_count(base, n)
			-- tears 在 shared 里不要再嵌套刀/剑 plan
			if m == "tears" then
				spawn_haemo_tear_children(profile, position, direction, player, context, c)
			else
				spawn_haemo_mode(m, profile, position, direction, player, context, c)
			end
		end
		return
	end
	-- 单一 mode（主泪 mark 的那份面额）：用该 mode 满额自身倍率
	spawn_haemo_mode(mode, profile, position, direction, player, context, nil)
end

--- 概率发射剑泪外观的主血泪（英灵剑兼容）；返回 tear 或 nil（调用方负责 stamp + mark）
function M.try_fire_haemo_sword_beam(profile, player, position, direction, damage, context)
	if not M.profile_has_haemolacria(profile) then return nil end
	local list = profile.list or {}
	if (list.sword or 0) <= 0 then return nil end
	context = context or {}
	local luck = tonumber(profile.stats and profile.stats.luck) or 0
	local chance = math.min(0.65, 0.35 + luck * 0.02)
	local rng = context.rng
	local roll = rng and rng.RandomFloat and rng:RandomFloat() or math.random()
	if roll >= chance then return nil end
	local dir = direction
	if not dir or dir:Length() < 0.01 then dir = Vector(10, 0) end
	local q = attack_holder.FireTear(player, position, dir, profile_fire_opts(context, "craft_haemo_sword_beam", {
		can_be_eye = true,
		no_tracer = true,
		can_trigger_streak_end = true,
	}))
	if not q then return nil end
	if damage then q.CollisionDamage = damage end
	q.FallingAcceleration = 0.8
	q.FallingSpeed = -8.9
	return q
end

--- 激光/剑等「攻击实例×敌人」去重：同一攻击对同一敌人只触发一次
function M.mark_haemo_hit(attack_data, enemy)
	if not attack_data or not enemy then return false end
	attack_data.haemo_hit = attack_data.haemo_hit or {}
	local ptr = GetPtrHash(enemy)
	if attack_data.haemo_hit[ptr] then return false end
	attack_data.haemo_hit[ptr] = true
	return true
end

end

return Mod
