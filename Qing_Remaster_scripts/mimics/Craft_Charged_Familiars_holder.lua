-- 蓄力类制造宝宝：Lil Abaddon / Lil Brimstone / Lil Monstro / Lil Spewer
-- 共用 idle→charging→ready→firing→cooldown；移动走普通编队（无 custom_move）。
-- 蓄力条：自绘 Charging_Bar_holder（右侧对称位），不驱动原版 FireCooldown 条。
local H = require("Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")
local Familiar_Control_Selector = require("Qing_Remaster_scripts.mimics.Familiar_Control_Selector")
local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "Craft_Charged_Familiars_holder_",
}

-- 数值暂定，局内探针后再固化
local DEFAULT_FULL_CHARGE = 30
local DEFAULT_MIN_CHARGE = 8
local DEFAULT_COOLDOWN = 20
local DEFAULT_FIRE_ANIM = 8
-- RGON EntityLaser:SetScale；相对玩家满蓄硫磺的小硫磺粗细
local LIL_BRIM_SCALE = 0.5
-- 模组默认条在左上 (-8,-35)；制造蓄力宝宝偏右上，避免叠在一起
local CHARGE_BAR_OFFSET = Vector(16, -42)
local CHARGE_BAR_ANM2 = "gfx/effects/chargebar/chargebar.anm2"
local CHARGE_BAR_SPRITE_KEY = item.own_key.."_Charge_Bar"

local CHARGED_VARIANTS = {
	[FamiliarVariant.LIL_ABADDON or 230] = true,
	[FamiliarVariant.LIL_BRIMSTONE or 61] = true,
	[FamiliarVariant.LIL_MONSTRO or 108] = true,
	[FamiliarVariant.LIL_SPEWER or 125] = true,
}

local function data(fam)
	return fam:GetData()
end

local function key(name)
	return item.own_key..name
end

local function lullaby_step(player, adapter)
	if player and player:HasTrinket(TrinketType.TRINKET_FORGOTTEN_LULLABY)
		and (not adapter or adapter.supports_lullaby ~= false) then
		return 2
	end
	return 1
end

local function bffs_mul(player, adapter)
	if adapter and adapter.supports_bffs == false then return 1 end
	if player and player:HasCollectible(CollectibleType.COLLECTIBLE_BFFS) then
		return tonumber(adapter and adapter.bffs_damage_mul) or 2
	end
	return 1
end

local function apply_bender_flags(player, adapter, flags)
	flags = flags or BitSet128(0, 0)
	if adapter and adapter.supports_bender == false then return flags end
	if player and player:HasTrinket(TrinketType.TRINKET_BABY_BENDER)
		and not player:HasCollectible(CollectibleType.COLLECTIBLE_SPOON_BENDER) then
		flags = flags | TearFlags.TEAR_HOMING
	end
	return flags
end

local function dir_suffix(dir)
	if dir == Direction.LEFT or dir == Direction.RIGHT then return "Side" end
	if dir == Direction.UP then return "Up" end
	return "Down"
end

local function aim_to_dir(aim)
	if not aim or aim:Length() < 0.01 then return Direction.DOWN end
	return auxi.GetDirectionByAngle(aim:GetAngleDegrees())
end

-- 口部在 PositionOffset（非 ParentOffset）。探针：左右 (±10,-23)，上下 (0,-19)
local function brim_mouth_position_offset(aim, flip_x)
	local dir = aim_to_dir(aim)
	if dir == Direction.LEFT or (dir == Direction.RIGHT and flip_x) then
		return Vector(-10, -23)
	end
	if dir == Direction.RIGHT then
		return Vector(10, -23)
	end
	return Vector(0, -19) -- Up / Down
end

local function play_charge_anim(fam, state, aim)
	local sprite = fam:GetSprite()
	local dir = aim_to_dir(aim)
	local suffix = dir_suffix(dir)
	local anim
	if state == "charging" or state == "ready" then
		anim = "FloatCharge"..suffix
	elseif state == "firing" then
		anim = "FloatShoot"..suffix
	else
		anim = "Float"..suffix
	end
	if not sprite:IsPlaying(anim) then
		sprite:Play(anim, true)
	end
	fam.FlipX = (dir == Direction.LEFT)
	if fam.ShootDirection ~= nil then fam.ShootDirection = dir end
end

local function read_input(ctx, d)
	local intent = ctx.intent or {}
	-- 使用 holder 已解析过方向有效性的结果。原始 intent 只表示 Flight 想攻击；
	-- 若本帧没有有效方向，不能继续推进蓄力或误用旧方向开火。
	local want = ctx.should_shoot == true
	local aim = ctx.aim_vector
	if (not aim or aim:Length() < 0.01) and intent.aim_direction and intent.aim_direction:Length() >= 0.01 then
		aim = intent.aim_direction:Normalized()
	end
	if aim and aim:Length() >= 0.01 then
		d[key("last_aim")] = aim:Normalized()
	else
		aim = d[key("last_aim")] or Vector(0, 1)
	end
	local was = d[key("was_want")] == true
	if want and not was then
		d[key("aim_epoch")] = (tonumber(d[key("aim_epoch")]) or 0) + 1
	end
	d[key("was_want")] = want
	return want, aim, tonumber(d[key("aim_epoch")]) or 0
end

local function stamp_laser_source(laser, fam)
	if not laser or not fam then return end
	laser = laser:ToLaser() or laser
	if laser.Parent ~= nil then laser.Parent = fam end
	if laser.SpawnerEntity ~= nil then laser.SpawnerEntity = fam end
	return laser
end

local function hide_vanilla_charge_bar(fam)
	-- Sewing：蓄力中 FC 为负并继续减小；0≈蓄满可放（原版条接近满）。
	-- Character_Advanced 接管用大正数压条。勿写 0/-1。
	if fam and fam.FireCooldown ~= nil then
		fam.FireCooldown = 999999
	end
end

local function custom_bar_is_charged(fam)
	local bar = data(fam)[CHARGE_BAR_SPRITE_KEY]
	return bar ~= nil and bar:IsPlaying("Charged")
end

local function sync_brim_laser_aim(laser, fam, aim)
	if not laser or not fam then return end
	laser = laser:ToLaser() or laser
	local d = data(fam)
	if not aim or aim:Length() < 0.01 then
		aim = d[key("brim_aim")] or d[key("last_aim")] or Vector(0, 1)
	end
	aim = aim:Normalized()
	local ang = aim:GetAngleDegrees()
	if laser.Angle ~= nil then laser.Angle = ang end
	if laser.AngleDegrees ~= nil then laser.AngleDegrees = ang end
	-- 原版：ParentOffset 恒 (0,0)；口部位移在 PositionOffset
	if laser.ParentOffset ~= nil then
		laser.ParentOffset = Vector(0, 0)
	end
	local mouth = brim_mouth_position_offset(aim, fam.FlipX)
	local po = fam.PositionOffset or Vector(0, 0)
	if laser.PositionOffset ~= nil then
		laser.PositionOffset = Vector(po.X + mouth.X, po.Y + mouth.Y)
	end
end

local function fire_lil_brimstone(adapter, ctx, aim)
	local fam, player = ctx.familiar, ctx.player
	if not fam or not player or not player.FireBrimstone then return false end
	if aim:Length() < 0.01 then aim = Vector(0, 1) end
	aim = aim:Normalized()
	-- Source=fam；第三参伤害倍率取 1 对齐满蓄外观（勿乱改 Variant）
	local laser = player:FireBrimstone(aim, fam, 1)
	if not laser then return false end
	laser = stamp_laser_source(laser, fam)
	laser.Position = fam.Position
	if laser.SetDisableFollowParent then
		laser:SetDisableFollowParent(false)
	elseif laser.DisableFollowParent ~= nil then
		laser.DisableFollowParent = false
	end
	local d = data(fam)
	d[key("brim_aim")] = aim
	sync_brim_laser_aim(laser, fam, aim)
	local scale = tonumber(adapter.laser_scale) or LIL_BRIM_SCALE
	if laser.SetScale then
		laser:SetScale(scale)
	end
	local dmg = (tonumber(adapter.damage) or 3) * bffs_mul(player, adapter)
	if laser.CollisionDamage ~= nil then laser.CollisionDamage = dmg end
	-- 原版寿命约 16 帧（Timeout 从 6 递减并越过 0）
	if laser.SetTimeout then
		laser:SetTimeout(tonumber(adapter.laser_timeout) or 16)
	elseif laser.Timeout ~= nil then
		laser.Timeout = tonumber(adapter.laser_timeout) or 16
	end
	-- 制造小硫磺：不继承玩家镜像 CurveStrength / 弯勺 HomingType；仅配方/弯勺宝宝 flags。
	local flags = apply_bender_flags(player, adapter, BitSet128(0, 0))
	CraftProfile.bind_craft_laser(laser, fam, flags)
	laser:GetData()[key("brim_laser")] = {
		fam_seed = fam.InitSeed,
	}
	d[key("active_brim")] = laser
	return true
end

-- 原版探针外观：V=THICK_RED(1) Sub=3 Size=8 Radius=80 Timeout=28 Scale=0.5；PosOff=(0,-20)
-- 正确入口是 SpawnMawOfVoid（自带暗环与 SOUND_MAW_OF_VOID），不要用 FireTechXLaser 换皮。
local function fire_lil_abaddon(adapter, ctx, _aim)
	local fam, player = ctx.familiar, ctx.player
	if not fam or not player or not player.SpawnMawOfVoid then return false end
	local life = tonumber(adapter.ring_lifetime) or 28
	local laser = player:SpawnMawOfVoid(life)
	if not laser then return false end
	laser = stamp_laser_source(laser, fam)
	laser.Position = fam.Position
	if laser.ParentOffset ~= nil then laser.ParentOffset = Vector(0, 0) end
	local po = fam.PositionOffset or Vector(0, 0)
	local ring_po = tonumber(adapter.ring_po_y) or -20
	if laser.PositionOffset ~= nil then
		laser.PositionOffset = Vector(po.X, po.Y + ring_po)
	end
	laser.Variant = LaserVariant.THICK_RED or 1
	if LaserSubType and LaserSubType.LASER_SUBTYPE_RING_FOLLOW_PARENT then
		laser.SubType = LaserSubType.LASER_SUBTYPE_RING_FOLLOW_PARENT
	else
		laser.SubType = 3
	end
	local ring_size = tonumber(adapter.ring_size) or 8
	if laser.Size ~= nil then laser.Size = ring_size end
	local radius = tonumber(adapter.ring_radius) or 80
	if laser.Radius ~= nil then laser.Radius = radius end
	local scale = tonumber(adapter.laser_scale) or 0.5
	if laser.SetScale then
		laser:SetScale(scale)
	end
	local dmg = (tonumber(adapter.damage) or 3.5) * bffs_mul(player, adapter)
	if laser.CollisionDamage ~= nil then laser.CollisionDamage = dmg end
	local flags = apply_bender_flags(player, adapter, BitSet128(0, 0))
	CraftProfile.bind_craft_laser(laser, fam, flags)
	local ld = laser:GetData()
	ld[key("abaddon_ring")] = {
		life = life,
		max_life = life,
		fam_seed = fam.InitSeed,
		po_y = ring_po,
	}
	if laser.SetTimeout then
		laser:SetTimeout(life)
	elseif laser.Timeout ~= nil then
		laser.Timeout = life
	end
	return true
end

local function make_rng(fam, epoch)
	local rng = RNG()
	local seed = math.abs((fam.InitSeed or 1) + ((epoch or 0) * 1103515245)) % 2147483647
	if seed == 0 then seed = 1 end
	rng:SetSeed(seed, 35)
	return rng
end

local function fire_lil_monstro(adapter, ctx, aim)
	local fam, player = ctx.familiar, ctx.player
	if not fam or not player then return false end
	if aim:Length() < 0.01 then aim = Vector(0, 1) end
	aim = aim:Normalized()
	local epoch = tonumber(data(fam)[key("aim_epoch")]) or 0
	local rng = make_rng(fam, epoch)
	local count_min = tonumber(adapter.volley_min) or 12
	local count_max = tonumber(adapter.volley_max) or 14
	local count = count_min
	if count_max > count_min then
		count = count_min + (rng:RandomInt(count_max - count_min + 1))
	end
	local spread = tonumber(adapter.spread_degrees) or 35
	local speed = tonumber(adapter.projectile_speed) or 9
	local dmg = (tonumber(adapter.damage) or 3.5) * bffs_mul(player, adapter)
	local flags = apply_bender_flags(player, adapter, BitSet128(0, 0))
	local fired = 0
	for i = 1, count do
		local t = (i - 0.5) / count - 0.5
		local ang = t * spread * 2
		local spd = speed * (0.75 + 0.5 * (rng:RandomFloat()))
		local shot_dir = auxi.get_by_rotate(aim, ang)
		local tear = H.fire_basic_tear(fam, player, shot_dir, adapter, {
			projectile_speed = spd,
			damage = dmg,
			skip_bffs = true,
			tear_flags = flags,
		})
		if tear then fired = fired + 1 end
	end
	return fired > 0
end

-- 小吐根：探针 State→水迹（0绿53 / 1白44 / 2红46 / 3黑45 / 4黄柠檬32）；开喷 SOUND_SPEWER
-- 水迹必须在开火动画期间逐帧铺开，禁止一次生成整条。
local SPEWER_MODES = {
	[0] = {
		variant = EffectVariant.PLAYER_CREEP_GREEN or 53,
		timeout = 24, size = 16, spacing = 20, count = 10,
		pattern = "line", dmg = 0.4,
	},
	[1] = {
		variant = EffectVariant.PLAYER_CREEP_WHITE or 44,
		timeout = 99, size = 16,
		-- 前方定圆：vanilla 完整白环 R≈104（perpMax/alongSpan/2），近端 along≈20；旧值 52 正好小一半
		pattern = "dual_arc", arc_steps = 15, ring_radius = 104, mouth_offset = 20,
		dmg = 0,
	},
	[2] = {
		variant = EffectVariant.PLAYER_CREEP_RED or 46,
		-- 完整红喷：13 短命线 + 1 末端大滩（geo：n=14 gap=1）
		-- 探针末端 Size35/T59/Scale1；但玩家水迹视觉主要由 Effect.Scale 驱动（Reverie/Epiphany 惯例）
		-- 末端用 Scale≈35/17 放大贴图，Size 仍写 35 对齐；并短时每帧回写防引擎冲掉
		timeout = 3, size = 17, spacing = 18, count = 14,
		pattern = "line", end_size = 35, end_timeout = 59, end_scale = 35 / 17, dmg = 1.2,
	},
	[3] = {
		variant = EffectVariant.PLAYER_CREEP_BLACK or 45,
		timeout = 99, size = 16, spacing = 20, count = 12,
		pattern = "line", dmg = 0,
	},
	[4] = {
		variant = EffectVariant.PLAYER_CREEP_LEMON_MISHAP or 32,
		-- 柠檬：自管长大→维持→缩小消失（原版缩小动画不可靠）
		-- 总寿命≈79；Scale 目标仍按距离 0.27→0.77
		timeout = 79, spacing = 21, count = 6,
		frame_step = 2,
		pattern = "scale_line", scale0 = 0.27, scale1 = 0.77, max_dist = 130,
		lemon = true, lemon_grow = 16, lemon_shrink = 24, dmg = 2,
	},
}

-- 颜色与 State 对应，且必须换皮（anm2 默认只有绿表）
local SPEWER_SHEETS = {
	[0] = "gfx/familiar/familiar_125_lilspewer.png",
	[1] = "gfx/familiar/familiar_125_lilspewer_white.png",
	[2] = "gfx/familiar/familiar_125_lilspewer_red.png",
	[3] = "gfx/familiar/familiar_125_lilspewer_black.png",
	[4] = "gfx/familiar/familiar_125_lilspewer_yellow.png",
}

-- 颜色与 fam.State 对齐，但以 data spewer_mode 为权威（原版吃胶囊可能改 State 却不改我们换皮）
local function get_spewer_mode(fam)
	local d = data(fam)
	local m = tonumber(d[key("spewer_mode")])
	if m == nil then m = tonumber(fam.State) or 0 end
	m = math.floor(m)
	if m < 0 or m > 4 then m = 0 end
	return m
end

local function apply_spewer_sheet(fam, mode)
	mode = math.floor(tonumber(mode) or 0) % 5
	if mode < 0 then mode = mode + 5 end
	local path = SPEWER_SHEETS[mode] or SPEWER_SHEETS[0]
	local d = data(fam)
	d[key("spewer_mode")] = mode
	fam.State = mode
	if d[key("spewer_sheet")] == path then
		return
	end
	local sprite = fam:GetSprite()
	sprite:ReplaceSpritesheet(0, path)
	sprite:LoadGraphics()
	d[key("spewer_sheet")] = path
end

--- 切换形态：只换权威 mode/皮；喷射中标记重建队列（立刻改喷新形态，不进冷却）
local function set_spewer_mode(fam, mode)
	apply_spewer_sheet(fam, mode)
	local d = data(fam)
	if d[key("state")] == "firing" then
		d[key("spew_rebind")] = true
	else
		d[key("spew_queue")] = nil
		d[key("spew_age")] = nil
		d[key("spew_rebind")] = nil
	end
end

local function play_spewer_anim(fam, state, aim)
	local sprite = fam:GetSprite()
	local dir = aim_to_dir(aim)
	local suffix = dir_suffix(dir)
	local d = data(fam)
	local anim
	if state == "charging" or state == "ready" then
		anim = "Charge" .. suffix
	elseif state == "firing" then
		anim = "FloatShoot" .. suffix
	else
		anim = "Float" .. suffix
	end
	local prev = d[key("spewer_anim")]
	local prev_state = d[key("spewer_anim_state")]
	-- 蓄力：只在进入 charging 时 Play 一次；播完停在末帧，禁止循环重开导致反复“鼓起来”
	if state == "charging" or state == "ready" then
		if prev ~= anim or prev_state == "idle" or prev_state == "cooldown" or prev_state == "firing" or not prev_state then
			sprite:Play(anim, true)
			local full = math.max(1, tonumber(d[key("bar_full")]) or DEFAULT_FULL_CHARGE)
			if sprite.PlaybackSpeed ~= nil then
				-- Charge 动画 15 帧、满蓄约 30：放慢使鼓起过程铺满蓄力
				sprite.PlaybackSpeed = math.max(0.35, 15 / full)
			end
		elseif sprite:IsFinished(anim) then
			if sprite.SetFrame then
				sprite:SetFrame(anim, 14)
			end
			if sprite.PlaybackSpeed ~= nil then
				sprite.PlaybackSpeed = 0
			end
		end
	else
		if sprite.PlaybackSpeed ~= nil then
			sprite.PlaybackSpeed = 1
		end
		if prev ~= anim or prev_state ~= state then
			sprite:Play(anim, true)
		elseif state == "firing" and sprite:IsFinished(anim) then
			-- 射击动画结束可停末帧，水迹队列可能仍在吐
			if sprite.SetFrame then sprite:SetFrame(anim, math.max(0, (sprite:GetFrame() or 1) - 1)) end
		elseif not sprite:IsPlaying(anim) then
			sprite:Play(anim, true)
		end
	end
	d[key("spewer_anim")] = anim
	d[key("spewer_anim_state")] = state
	fam.FlipX = (dir == Direction.LEFT)
	if fam.ShootDirection ~= nil then fam.ShootDirection = dir end
	-- 每帧用权威 mode 回写 State + 贴图（防止原版/其它逻辑改 State 导致皮与攻击脱节）
	apply_spewer_sheet(fam, get_spewer_mode(fam))
	-- 蓄满：轻微红色闪烁（探针：Charge 末帧 Tint G/B 在 ~0.84–1 间抖）
	if state == "ready" then
		local phase = (Game():GetFrameCount() % 16) / 16
		local pulse = 0.84 + 0.16 * math.abs(1 - 2 * phase)
		sprite.Color = Color(1, pulse, pulse, 1)
		d[key("spewer_flash")] = true
	elseif d[key("spewer_flash")] then
		sprite.Color = Color(1, 1, 1, 1)
		d[key("spewer_flash")] = nil
	end
end

local function spawn_spewer_creep(fam, player, pos, cfg, opts)
	opts = opts or {}
	local ent = Isaac.Spawn(
		EntityType.ENTITY_EFFECT, cfg.variant, 0,
		pos, Vector(0, 0), player or fam
	)
	local e = ent and ent:ToEffect()
	if not e then return nil end
	local timeout = opts.timeout or cfg.timeout or 24
	local size = opts.size or cfg.size
	local scale = opts.scale
	local lemon = cfg.lemon == true or opts.lemon == true
	local function apply_timeout(eff, t)
		if not eff then return end
		-- 玩家水迹：直接写 Timeout 更稳（Epiphany lemon_bag）；SetTimeout 作双保险
		if eff.Timeout ~= nil then eff.Timeout = t end
		if eff.SetTimeout then eff:SetTimeout(t) end
	end
	if lemon then
		-- 自管 Scale：小→目标最大→渐缩→Remove；Timeout 只防引擎过早删
		local max_sc = tonumber(scale) or 0.5
		local grow = math.max(1, math.floor(tonumber(cfg.lemon_grow) or 16))
		local shrink = math.max(1, math.floor(tonumber(cfg.lemon_shrink) or 24))
		local hold = math.max(4, math.floor(timeout) - grow - shrink)
		local total = grow + hold + shrink
		local start_sc = math.max(0.05, max_sc * 0.2)
		if e.Scale ~= nil then e.Scale = start_sc end
		apply_timeout(e, total + 8)
		if e.SetColor then
			e:SetColor(Color(1, 1, 1, 0), 2, 10, false, false)
		end
		local ed = e:GetData()
		ed[key("spewer_lemon")] = true
		ed[key("spewer_lemon_anim")] = {
			max = max_sc,
			start = start_sc,
			born = Game():GetFrameCount(),
			grow = grow,
			hold = hold,
			shrink = shrink,
		}
	else
		apply_timeout(e, timeout)
		if size ~= nil and e.Size ~= nil then e.Size = size end
		if scale ~= nil and e.Scale ~= nil then e.Scale = scale end
		-- 红末端：视觉靠 Scale（他模惯例）；短时每帧回写 Size/Scale/Timeout
		if opts.hold_scale == true or opts.force_update == true then
			local ed = e:GetData()
			ed[key("spewer_hold")] = {
				size = size,
				scale = scale,
				timeout = timeout,
				until_frame = Game():GetFrameCount() + 12,
			}
			if e.Update then
				e:Update()
				apply_timeout(e, timeout)
				if size ~= nil and e.Size ~= nil then e.Size = size end
				if scale ~= nil and e.Scale ~= nil then e.Scale = scale end
			end
		end
	end
	local dmg = tonumber(opts.dmg)
	if dmg == nil then dmg = tonumber(cfg.dmg) or 0 end
	dmg = dmg * (tonumber(opts.dmg_mul) or 1)
	if dmg > 0 and e.CollisionDamage ~= nil then
		e.CollisionDamage = dmg
	end
	return e
end

--- 构建逐帧生成队列（每项一帧或同帧多项）；开火时只入队，update 里吐出
local function build_spewer_queue(fam, player, aim, cfg, range_mul, size_mul, life_mul, dmg_mul)
	local queue = {}
	local mouth = tonumber(cfg.mouth_offset) or 5
	local origin = fam.Position + aim * mouth
	local function push(pos, opts, delay)
		queue[#queue + 1] = {
			pos = pos,
			opts = opts,
			delay = delay or 0,
			cfg = cfg,
			player = player,
		}
	end
	local function life(t)
		return math.floor((t or 24) * life_mul + 0.5)
	end
	if cfg.pattern == "dual_arc" then
		-- 前方定圆：圆心 = origin + aim*R；双弧从近端（口）同步铺到远端对径
		local steps = math.max(4, math.floor((cfg.arc_steps or 12) * range_mul + 0.5))
		local R = (cfg.ring_radius or 52) * range_mul
		local center = origin + aim * R
		local back = aim:GetAngleDegrees() + 180
		for step = 0, steps - 1 do
			local t = (steps <= 1) and 1 or (step / (steps - 1))
			local opts = {
				timeout = life(cfg.timeout),
				size = (cfg.size or 16) * size_mul,
				dmg_mul = dmg_mul,
			}
			push(center + Vector.FromAngle(back + t * 180) * R, opts, step)
			push(center + Vector.FromAngle(back - t * 180) * R, opts, step)
		end
	else
		local count = math.max(1, math.floor((cfg.count or 8) * range_mul + 0.5))
		local spacing = cfg.spacing or 20
		local frame_step = math.max(1, math.floor(tonumber(cfg.frame_step) or 1))
		local max_dist = cfg.max_dist and (cfg.max_dist * range_mul) or nil
		for i = 1, count do
			local dist = spacing * i
			if max_dist and dist > max_dist then break end
			local opts = {
				timeout = life(cfg.timeout),
				dmg_mul = dmg_mul,
			}
			if cfg.size ~= nil then
				opts.size = cfg.size * size_mul
			end
			if cfg.pattern == "scale_line" then
				local u = (count <= 1) and 1 or ((i - 1) / (count - 1))
				opts.scale = (cfg.scale0 or 0.3) + ((cfg.scale1 or 0.8) - (cfg.scale0 or 0.3)) * u
				opts.lemon = cfg.lemon == true
			end
			if i == count and cfg.end_size then
				opts.size = cfg.end_size * size_mul
				opts.timeout = life(cfg.end_timeout or 30)
				local base = tonumber(cfg.size) or 17
				local esc = tonumber(cfg.end_scale)
				if esc == nil then esc = (cfg.end_size or base) / base end
				opts.scale = esc * size_mul
				opts.hold_scale = true
				opts.force_update = true
			end
			push(origin + aim * dist, opts, (i - 1) * frame_step)
		end
	end
	return queue
end

local function tick_spewer_queue(fam)
	local d = data(fam)
	local queue = d[key("spew_queue")]
	if type(queue) ~= "table" or #queue == 0 then
		d[key("spew_queue")] = nil
		d[key("spew_age")] = nil
		return false
	end
	local age = (tonumber(d[key("spew_age")]) or 0)
	d[key("spew_age")] = age + 1
	-- 吐出所有 delay <= age 的项（同 delay 的双弧左右同一帧）
	local remain = {}
	for i = 1, #queue do
		local job = queue[i]
		if (tonumber(job.delay) or 0) <= age then
			spawn_spewer_creep(fam, job.player, job.pos, job.cfg, job.opts)
		else
			remain[#remain + 1] = job
		end
	end
	if #remain == 0 then
		d[key("spew_queue")] = nil
		d[key("spew_age")] = nil
		return false
	end
	d[key("spew_queue")] = remain
	return true
end

--- 喷射中换色：用新形态整队重建队列并马上开吐，保持 firing（不进冷却）
local function rebind_spewer_queue(fam, adapter)
	local d = data(fam)
	if not d[key("spew_rebind")] then return end
	d[key("spew_rebind")] = nil
	local player = fam.Player or auxi.check_spawner_player(fam)
	local aim = d[key("last_aim")]
	if (not aim or aim:Length() < 0.01) and fam.Velocity and fam.Velocity:Length() > 0.2 then
		aim = fam.Velocity:Normalized()
	end
	if not aim or aim:Length() < 0.01 then
		aim = Vector(0, 1)
	else
		aim = aim:Normalized()
	end
	d[key("last_aim")] = aim
	local mode = get_spewer_mode(fam)
	apply_spewer_sheet(fam, mode)
	local cfg = SPEWER_MODES[mode] or SPEWER_MODES[0]
	local dmg_mul = bffs_mul(player, adapter)
	local range_mul = (dmg_mul > 1) and 1.35 or 1
	local size_mul = 1
	if player and player:HasTrinket(TrinketType.TRINKET_LOST_CORK or 106) then
		size_mul = 1.5
	end
	local life_mul = (dmg_mul > 1) and 1.35 or 1
	local queue = build_spewer_queue(fam, player, aim, cfg, range_mul, size_mul, life_mul, dmg_mul)
	local max_delay = 0
	for i = 1, #queue do
		max_delay = math.max(max_delay, tonumber(queue[i].delay) or 0)
	end
	d[key("spew_queue")] = queue
	d[key("spew_age")] = 0
	d[key("state")] = "firing"
	d[key("fire_left")] = math.max(tonumber(d[key("fire_left")]) or 0, max_delay + 2)
	d[key("spew_fire_len")] = math.max(14, max_delay + 2)
	tick_spewer_queue(fam)
end

local function fire_lil_spewer(adapter, ctx, aim)
	local fam, player = ctx.familiar, ctx.player
	if not fam then return false end
	if aim:Length() < 0.01 then aim = Vector(0, 1) end
	aim = aim:Normalized()
	local mode = get_spewer_mode(fam)
	-- 开火前再钉一次，保证本发 cfg 与当前皮一致
	apply_spewer_sheet(fam, mode)
	local cfg = SPEWER_MODES[mode] or SPEWER_MODES[0]
	local dmg_mul = bffs_mul(player, adapter)
	local range_mul = (dmg_mul > 1) and 1.35 or 1
	local size_mul = 1
	if player and player:HasTrinket(TrinketType.TRINKET_LOST_CORK or 106) then
		size_mul = 1.5
	end
	local life_mul = (dmg_mul > 1) and 1.35 or 1
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_SPEWER or 459, 1, 1, false, 0, 0)
	local queue = build_spewer_queue(fam, player, aim, cfg, range_mul, size_mul, life_mul, dmg_mul)
	local max_delay = 0
	for i = 1, #queue do
		max_delay = math.max(max_delay, tonumber(queue[i].delay) or 0)
	end
	local d = data(fam)
	d[key("spew_rebind")] = nil
	d[key("last_aim")] = aim
	d[key("spew_queue")] = queue
	d[key("spew_age")] = 0
	d[key("spew_fire_len")] = math.max(14, max_delay + 2)
	-- 立即吐出 delay=0（第一滩 / 双弧第一对）
	tick_spewer_queue(fam)
	return #queue > 0
end

local PROFILES = {
	lil_abaddon = {
		full_charge = DEFAULT_FULL_CHARGE,
		min_charge = DEFAULT_MIN_CHARGE,
		cooldown = DEFAULT_COOLDOWN,
		fire_anim = DEFAULT_FIRE_ANIM,
		fire = fire_lil_abaddon,
		auto_fire_when_full = true,
	},
	lil_brimstone = {
		full_charge = DEFAULT_FULL_CHARGE,
		min_charge = DEFAULT_MIN_CHARGE,
		cooldown = 10,
		fire_anim = DEFAULT_FIRE_ANIM,
		fire = fire_lil_brimstone,
		auto_fire_when_full = true,
	},
	lil_monstro = {
		full_charge = 30,
		min_charge = DEFAULT_MIN_CHARGE,
		cooldown = DEFAULT_COOLDOWN,
		fire_anim = 10,
		fire = fire_lil_monstro,
		auto_fire_when_full = true,
	},
	lil_spewer = {
		full_charge = 30,
		min_charge = DEFAULT_MIN_CHARGE,
		cooldown = 30,
		fire_anim = 14,
		fire = fire_lil_spewer,
		play_anim = play_spewer_anim,
		auto_fire_when_full = true,
	},
}

local function try_release_shot(adapter, ctx, profile, aim, fire_anim, cool)
	local fam = ctx.familiar
	local d = data(fam)
	local ok = false
	if profile.fire then
		local fired_ok, ret = pcall(profile.fire, adapter, ctx, aim)
		ok = fired_ok and ret ~= false
	end
	if ok then
		d[key("state")] = "firing"
		local spew_len = tonumber(d[key("spew_fire_len")])
		d[key("fire_left")] = spew_len or fire_anim
		d[key("spew_fire_len")] = nil
		d[key("charge")] = 0
		d[key("cooldown")] = cool
		hide_vanilla_charge_bar(fam)
		return true
	end
	d[key("state")] = "idle"
	d[key("charge")] = 0
	hide_vanilla_charge_bar(fam)
	return false
end

local function update_charged(adapter, ctx)
	local fam = ctx.familiar
	if not fam then return end
	local d = data(fam)
	local profile = PROFILES[adapter.name] or PROFILES.lil_abaddon
	local want, aim = read_input(ctx, d)
	local state = d[key("state")] or "idle"
	local charge = tonumber(d[key("charge")]) or 0
	local cd = tonumber(d[key("cooldown")]) or 0
	local fire_left = tonumber(d[key("fire_left")]) or 0
	local step = lullaby_step(ctx.player, adapter)
	local full = tonumber(adapter.full_charge) or profile.full_charge
	local cool = tonumber(adapter.base_cooldown) or profile.cooldown
	local fire_anim = tonumber(adapter.fire_anim) or profile.fire_anim
	local auto_full = adapter.auto_fire_when_full
	if auto_full == nil then auto_full = profile.auto_fire_when_full end

	if state == "cooldown" then
		cd = math.max(0, cd - step)
		d[key("cooldown")] = cd
		if cd <= 0 then
			state = "idle"
			charge = 0
			d[key("charge")] = 0
		end
	elseif state == "firing" then
		if adapter.name == "lil_spewer" then
			rebind_spewer_queue(fam, adapter)
			tick_spewer_queue(fam)
		end
		fire_left = math.max(0, fire_left - 1)
		-- 队列未吐完则续命，避免 fire_anim 先结束切断双弧
		if fire_left <= 0 and adapter.name == "lil_spewer" and d[key("spew_queue")] then
			fire_left = 1
		end
		d[key("fire_left")] = fire_left
		if fire_left <= 0 then
			state = "cooldown"
			d[key("cooldown")] = cool
			d[key("spew_queue")] = nil
			d[key("spew_age")] = nil
		end
	elseif want then
		if state == "idle" or state == "charging" or state == "ready" then
			charge = math.min(full, charge + step)
			d[key("charge")] = charge
			if charge >= full then
				state = "ready"
				-- 先让自绘条完整播放 StartCharged；进入 Charged 循环后的下一次
				-- UPDATE 才开火，避免“数值满了但条还没转好”或永远等松手。
				if auto_full and custom_bar_is_charged(fam) then
					if try_release_shot(adapter, ctx, profile, aim, fire_anim, cool) then
						state = d[key("state")] or "firing"
						charge = tonumber(d[key("charge")]) or 0
					end
				end
			else
				state = "charging"
			end
		end
	elseif not want and (state == "charging" or state == "ready") then
		-- Flight 发布的是攻击窗口而非玩家“松开射击键”。窗口结束（失去目标、
		-- 切模式）只能取消未完成蓄力，绝不能被解释为释放攻击。
		state = "idle"
		d[key("charge")] = 0
		charge = 0
	end

	d[key("state")] = state
	d[key("bar_charge")] = charge
	d[key("bar_full")] = full
	if profile.play_anim then
		profile.play_anim(fam, state, aim)
	else
		play_charge_anim(fam, state, aim)
	end
	-- 小硫磺：激光存活期间持续锁开火方向（不仅第一帧）
	local brim = d[key("active_brim")]
	if brim then
		if auxi.check_all_exists(brim) then
			sync_brim_laser_aim(brim, fam, d[key("brim_aim")])
		else
			d[key("active_brim")] = nil
			d[key("brim_aim")] = nil
		end
	end
	-- 始终压掉原版条；进度改由自绘条读 bar_charge
	hide_vanilla_charge_bar(fam)
end

local function register(variant, adapter)
	if adapter.supports_bffs == nil then adapter.supports_bffs = true end
	if adapter.supports_lullaby == nil then adapter.supports_lullaby = true end
	if adapter.supports_bender == nil then adapter.supports_bender = true end
	adapter.control_mode = adapter.control_mode or "full"
	adapter.custom_animation = true
	adapter.no_fire = true
	adapter.skip_tick_cooldown = true
	adapter.fire = function() return false end
	adapter.update = update_charged
	adapter.acquire = function(_, fam)
		local d = data(fam)
		if d[key("saved_fire_cooldown")] == nil then
			d[key("saved_fire_cooldown")] = fam.FireCooldown
		end
		d[key("state")] = "idle"
		d[key("charge")] = 0
		d[key("bar_charge")] = 0
		d[key("cooldown")] = 0
		d[key("was_want")] = nil
		d[key("fire_left")] = nil
		if adapter.name == "lil_spewer" then
			local m = tonumber(d[key("spewer_mode")]) or tonumber(fam.State) or 0
			if m < 0 or m > 4 then m = 0 end
			apply_spewer_sheet(fam, m)
			d[key("spewer_anim")] = nil
			d[key("spewer_anim_state")] = nil
			d[key("spew_queue")] = nil
			d[key("spew_age")] = nil
		end
		hide_vanilla_charge_bar(fam)
	end
	adapter.release = function(_, fam)
		local d = data(fam)
		local saved_fire_cooldown = d[key("saved_fire_cooldown")]
		d[key("state")] = nil
		d[key("charge")] = nil
		d[key("bar_charge")] = nil
		d[key("cooldown")] = nil
		d[key("was_want")] = nil
		d[key("last_aim")] = nil
		d[key("fire_left")] = nil
		d[key("active_brim")] = nil
		d[key("brim_aim")] = nil
		d[key("spew_queue")] = nil
		d[key("spew_age")] = nil
		d[key("spew_fire_len")] = nil
		d[key("spewer_anim")] = nil
		d[key("spewer_anim_state")] = nil
		d[key("spewer_sheet")] = nil
		d[key("spewer_mode")] = nil
		d[key("spewer_flash")] = nil
		d[key("saved_fire_cooldown")] = nil
		if fam and fam.FireCooldown ~= nil then
			fam.FireCooldown = tonumber(saved_fire_cooldown) or 0
		end
		if fam then
			Charging_Bar_holder.remove_charge_bar(fam, item.own_key)
		end
	end
	H.register_adapter(variant, adapter)
end

register(FamiliarVariant.LIL_ABADDON, {
	name = "lil_abaddon",
	extra_key = "lil_abaddon",
	collectible = CollectibleType.COLLECTIBLE_LIL_ABADDON or 679,
	class = "charged",
	damage = 3.5,
	ring_radius = 80,
	ring_lifetime = 28,
	ring_size = 8,
	ring_po_y = -20,
	laser_scale = 0.5,
	full_charge = DEFAULT_FULL_CHARGE,
	min_charge = DEFAULT_MIN_CHARGE,
	base_cooldown = DEFAULT_COOLDOWN,
	auto_fire_when_full = true,
})

register(FamiliarVariant.LIL_BRIMSTONE, {
	name = "lil_brimstone",
	extra_key = "lil_brimstone",
	collectible = CollectibleType.COLLECTIBLE_LIL_BRIMSTONE or 275,
	class = "charged",
	damage = 3,
	laser_timeout = 16,
	laser_scale = LIL_BRIM_SCALE,
	full_charge = DEFAULT_FULL_CHARGE,
	min_charge = DEFAULT_MIN_CHARGE,
	base_cooldown = 10,
	auto_fire_when_full = true,
})

register(FamiliarVariant.LIL_MONSTRO, {
	name = "lil_monstro",
	extra_key = "lil_monstro",
	collectible = CollectibleType.COLLECTIBLE_LIL_MONSTRO or 471,
	class = "charged",
	damage = 3.5,
	projectile_speed = 9,
	volley_min = 12,
	volley_max = 14,
	spread_degrees = 35,
	full_charge = 30,
	min_charge = DEFAULT_MIN_CHARGE,
	base_cooldown = DEFAULT_COOLDOWN,
	auto_fire_when_full = true,
})

register(FamiliarVariant.LIL_SPEWER or 125, {
	name = "lil_spewer",
	extra_key = "lil_spewer",
	collectible = CollectibleType.COLLECTIBLE_LIL_SPEWER or 537,
	class = "charged",
	full_charge = 30,
	min_charge = DEFAULT_MIN_CHARGE,
	base_cooldown = 30,
	fire_anim = 14,
	auto_fire_when_full = true,
	supports_bender = false,
})

-- 吃胶囊：制造小吐根随机换色（与原版一致，按所属玩家）
-- 换色时清空 spew_queue，避免继续吐上一种水迹
table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_USE_PILL,
	params = nil,
	Function = function(_, _pill_effect, player, _)
		if not player then return end
		local list = Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FamiliarVariant.LIL_SPEWER or 125, -1, false, false)
		for _, ent in ipairs(list) do
			local fam = ent:ToFamiliar()
			if fam and Familiar_Control_Selector.is_owner(fam, Familiar_Control_Selector.BLUEPRINT) then
				local owner = fam.Player or auxi.check_spawner_player(fam)
				if owner and GetPtrHash(owner) == GetPtrHash(player) then
					local cur = get_spewer_mode(fam)
					local nxt = cur
					for _ = 1, 8 do
						nxt = math.floor(Random() % 5)
						if nxt ~= cur then break end
					end
					if nxt == cur then nxt = (cur + 1) % 5 end
					set_spewer_mode(fam, nxt)
				end
			end
		end
	end,
})

-- 柠檬水迹：手动长大→维持→缩小后 Remove
table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE,
	params = EffectVariant.PLAYER_CREEP_LEMON_MISHAP or 32,
	Function = function(_, effect)
		if not effect then return end
		local ed = effect:GetData()
		local anim = ed and ed[key("spewer_lemon_anim")]
		if type(anim) ~= "table" then return end
		local age = Game():GetFrameCount() - (tonumber(anim.born) or 0)
		local grow = math.max(1, tonumber(anim.grow) or 16)
		local hold = math.max(0, tonumber(anim.hold) or 0)
		local shrink = math.max(1, tonumber(anim.shrink) or 24)
		local max_sc = tonumber(anim.max) or 0.5
		local start_sc = tonumber(anim.start) or (max_sc * 0.2)
		local sc
		if age <= grow then
			local t = age / grow
			-- smoothstep：起步慢、接近最大时放缓
			t = t * t * (3 - 2 * t)
			sc = start_sc + (max_sc - start_sc) * t
		elseif age <= grow + hold then
			sc = max_sc
		else
			local u = (age - grow - hold) / shrink
			if u >= 1 then
				effect:Remove()
				return
			end
			-- 后段略加快收束，消失更干净
			u = u * u
			sc = max_sc * (1 - u)
		end
		if effect.Scale ~= nil then
			effect.Scale = math.max(0.02, sc)
		end
	end,
})

-- 红末端：短时回写 Size/Scale（勿每帧重写 Timeout，否则寿命被钉死）
table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE,
	params = EffectVariant.PLAYER_CREEP_RED or 46,
	Function = function(_, effect)
		if not effect then return end
		local ed = effect:GetData()
		local hold = ed and ed[key("spewer_hold")]
		if type(hold) ~= "table" then return end
		if Game():GetFrameCount() > (tonumber(hold.until_frame) or 0) then
			ed[key("spewer_hold")] = nil
			return
		end
		if hold.size ~= nil and effect.Size ~= nil then effect.Size = hold.size end
		if hold.scale ~= nil and effect.Scale ~= nil then effect.Scale = hold.scale end
	end,
})

-- 自绘蓄力条：相对默认左上 (-8,-35) 偏右上
table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_FAMILIAR_RENDER,
	params = nil,
	Function = function(_, fam, _offset)
		if not fam or not CHARGED_VARIANTS[fam.Variant] then return end
		if not Familiar_Control_Selector.is_owner(fam, Familiar_Control_Selector.BLUEPRINT) then return end
		local d = data(fam)
		local state = d[key("state")]
		local charge = tonumber(d[key("bar_charge")]) or tonumber(d[key("charge")]) or 0
		local full = math.max(1, tonumber(d[key("bar_full")]) or DEFAULT_FULL_CHARGE)
		local show = (state == "charging" or state == "ready") and charge > 0
		local cnt = show and math.ceil(charge / full * 100) or 0
		Charging_Bar_holder.render_me(fam, {
			name1 = item.own_key,
			name2 = item.own_key,
			name3 = item.own_key,
			loadname = CHARGE_BAR_ANM2,
			offset = CHARGE_BAR_OFFSET,
			NoOffset = true,
			check1 = function()
				return cnt > 5
			end,
			check2 = function()
				return cnt >= 100
			end,
			check3 = function()
				return cnt
			end,
		})
	end,
})

-- 小硫磺激光 + Abaddon 环：每帧同步
table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_LASER_UPDATE,
	params = nil,
	Function = function(_, laser)
		if not laser then return end
		local ldata = laser:GetData()
		local brim = ldata[key("brim_laser")]
		if brim then
			local fam = laser.Parent and laser.Parent:ToFamiliar()
			if not fam and laser.SpawnerEntity then
				fam = laser.SpawnerEntity:ToFamiliar()
			end
			if fam and auxi.check_all_exists(fam) then
				sync_brim_laser_aim(laser, fam, data(fam)[key("brim_aim")])
			end
			return
		end
		local ld = ldata[key("abaddon_ring")]
		if not ld then return end
		-- 跟住宝宝高度 + 环口部 PosOff.y=-20（Parent/Spawner 均为 fam）
		local fam = laser.Parent and laser.Parent:ToFamiliar()
		if not fam and laser.SpawnerEntity then
			fam = laser.SpawnerEntity:ToFamiliar()
		end
		if fam and laser.PositionOffset then
			local po = fam.PositionOffset or Vector(0, 0)
			local ring_po = tonumber(ld.po_y) or -20
			laser.PositionOffset = Vector(po.X, po.Y + ring_po)
			if laser.Position then
				laser.Position = fam.Position
			end
		end
		if laser.ParentOffset ~= nil then
			laser.ParentOffset = Vector(0, 0)
		end
		ld.life = (tonumber(ld.life) or 0) - 1
		local fade = 5
		if ld.life == fade and laser.SetTimeout then
			laser:SetTimeout(fade)
		elseif ld.life == fade and laser.Timeout ~= nil then
			laser.Timeout = fade
		end
		if ld.life <= 0 then
			laser:Remove()
			return
		end
		local alpha = math.max(0.15, ld.life / math.max(1, ld.max_life or 28))
		if laser.Color then
			local c = laser.Color
			laser.Color = Color(c.R, c.G, c.B, alpha, c.RO, c.GO, c.BO)
		end
	end,
})

function item.sync_air_flight(air, player, profile)
	return H.sync_air_flight(air, player, profile)
end

function item.release_for_air(air)
	return H.release_for_air(air)
end

return item
