-- 蓝图第一组·攻击型 orbital（推荐施工批次 2）
-- 范围：blueprint_familiar_batch_scope_v2.md
-- 复杂项半径/时序以探针校准；本文件先落地可测制造版，勿声称精确还原。
local Orb = require("Qing_Remaster_scripts.mimics.Craft_Orbital_holder")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local SpriteTrails = require("Qing_Remaster_scripts.others.sprite_trail_presets")
local Familiar_Move_Driver = require("Qing_Remaster_scripts.mimics.Familiar_Move_Driver")
local dev_env = require("Qing_Remaster_scripts.core.dev_environment")
-- 手指探针已归档到 codex_work/probes；仅调试时拷回 others 才会加载。
local FingerProbe = dev_env.require_probe("Qing_Remaster_scripts.others.finger_vanilla_probe")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	own_key = "Craft_Orbital_Batch2_",
}

-- 只追踪确有待复生状态的 Flight，避免每帧全局扫描实体。
local TINYTOMA_PENDING = setmetatable({}, {__mode = "k"})

local function get_air_mod()
	return require("Qing_Remaster_scripts.items.Item_Air_Flight")
end

local function flight_damage(air)
	local Air = get_air_mod()
	local prof = air and air:GetData()[Air.own_key.."craft_profile"]
	return (prof and prof.stats and tonumber(prof.stats.damage)) or 3.5
end

local function air_aim(air)
	if not air then return Vector(1, 0) end
	local Air = get_air_mod()
	local d = air:GetData()
	local aim = d[Air.own_key.."AuxAimDirection"]
	if aim and aim:Length() > 0.01 then return aim:Normalized() end
	local face = d[Air.own_key.."FaceDir"] or d[Air.own_key.."AimDir"]
	if face and face:Length() > 0.01 then return face:Normalized() end
	local v = air.Velocity
	if v and v:Length() > 0.4 then return v:Normalized() end
	return Vector(1, 0)
end

-- Flight 当前已经落实到贴图上的航向；与 AuxAimDirection（火控目标方向）严格区分。
local function air_current_facing(air)
	if not air then return Vector(1, 0) end
	local Air = get_air_mod()
	local d = air:GetData()
	local face = d[Air.own_key.."RotDir"] or d[Air.own_key.."FaceU"]
	if face and face:Length() > 0.01 then return face:Normalized() end
	local v = air.Velocity
	if v and v:Length() > 0.4 then return v:Normalized() end
	return air_aim(air)
end

-- Finger 的隐藏射线没有 80px 长度上限；Radius=80 不是长度字段。
-- 以当前房间包围盒求正向交点，伤害与调试绘制共用该长度。
local function finger_ray_length(origin, aim)
	local room = Game():GetRoom()
	local top_left = room:GetTopLeftPos()
	local bottom_right = room:GetBottomRightPos()
	local distance = math.huge
	if aim.X > 0.0001 then
		distance = math.min(distance, (bottom_right.X - origin.X) / aim.X)
	elseif aim.X < -0.0001 then
		distance = math.min(distance, (top_left.X - origin.X) / aim.X)
	end
	if aim.Y > 0.0001 then
		distance = math.min(distance, (bottom_right.Y - origin.Y) / aim.Y)
	elseif aim.Y < -0.0001 then
		distance = math.min(distance, (top_left.Y - origin.Y) / aim.Y)
	end
	if distance == math.huge then return 0 end
	return math.max(0, distance)
end

local function enemy_projectile(proj)
	if not proj then return false end
	if proj:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then return false end
	local sp = proj.SpawnerEntity
	if sp and sp:ToPlayer() then return false end
	if sp and sp.Type == EntityType.ENTITY_FAMILIAR then return false end
	return true
end

local function default_orbit_target(fam, bind, air)
	if fam.GetOrbitPosition then
		local ok, pos = pcall(function() return fam:GetOrbitPosition(air.Position) end)
		if ok and pos then return pos end
	end
	local dist = fam.OrbitDistance or bind.orbit_distance or Vector(40, 40)
	local spd = tonumber(fam.OrbitSpeed) or tonumber(bind.orbit_speed) or 0.045
	local ang = Game():GetFrameCount() * spd + (tonumber(bind.layout_angle_offset or bind.orbit_angle_offset) or 0)
	return air.Position + Vector(math.cos(ang) * dist.X, math.sin(ang) * dist.Y)
end

-- ---------- 206 Guillotine ----------
-- 断头台是 orbital，不进入普通宝宝 follower 链。只替换轨道中心为 Flight：
-- 放行原版 AI，并在同一 FAMILIAR_UPDATE 中覆写 Flight 轨道速度；碰撞/开火等
-- 原版行为不由制造侧重写。
Orb.register_orbital(FamiliarVariant.GUILLOTINE or 68, {
	collectible = CollectibleType.COLLECTIBLE_GUILLOTINE or 206,
	kind = "guillotine",
	base_dps = 0,
	group = "normal",
	block = false,
	layout_ring = "middle",
	orbit_layer = 1,
	position_offset_mode = "air_relative",
	keep_vanilla_ai = true,
	preserve_vanilla_combat = true,
	soft_rebind = true,
})

-- ---------- 363 Sworn Protector ----------
Orb.register_orbital(FamiliarVariant.SWORN_PROTECTOR or 83, {
	collectible = CollectibleType.COLLECTIBLE_SWORN_PROTECTOR or 363,
	kind = "sworn_protector",
	base_dps = 105,
	group = "high",
	block = true,
	layout_ring = "inner",
	orbit_layer = 0,
	position_offset_mode = "air_relative",
	update = function(fam, bind, air, _buckets, state)
		if state ~= "active" or not air then return end
		-- 轻量吸弹：逼近敌弹；强度待探针
		local radius = tonumber(Orb.debug.sworn_attract_radius) or 48
		for _, ent in ipairs(Isaac.FindInRadius(fam.Position, radius, EntityPartition.BULLET)) do
			local proj = ent:ToProjectile()
			if proj and enemy_projectile(proj) then
				local to = fam.Position - proj.Position
				if to:Length() > 1 then
					proj.Velocity = proj.Velocity * 0.92 + to:Resized(1.6)
				end
			end
		end
	end,
	on_block = function(fam, bind, proj, air)
		-- 只统计无 CANT_HIT_PLAYER 的敌弹；带该 flag 的仍挡掉但不计入掉心进度
		if not Orb.is_sworn_blockable_projectile(proj) then
			return false
		end
		local room = Game():GetLevel():GetCurrentRoomIndex()
		if bind.sworn_room ~= room then
			bind.sworn_room = room
			bind.sworn_blocks = 0
		end
		-- 原版阈值：每房挡 10 发可命中玩家的敌弹 → 1 永恒心（不做叠乘衰减）
		local threshold = 10
		if Orb.debug and tonumber(Orb.debug.sworn_heart_threshold) then
			threshold = math.max(1, math.floor(tonumber(Orb.debug.sworn_heart_threshold)))
		end
		bind.sworn_blocks = (tonumber(bind.sworn_blocks) or 0) + 1
		if bind.sworn_blocks >= threshold then
			bind.sworn_blocks = 0
			local player = auxi.check_spawner_player(air) or (fam and fam.Player)
			if player then
				Isaac.Spawn(
					EntityType.ENTITY_PICKUP,
					PickupVariant.PICKUP_HEART,
					HeartSubType.HEART_ETERNAL or 4,
					player.Position,
					Vector.Zero,
					player
				)
			end
		end
		return false -- 仍删除弹丸
	end,
})

local function fire_directed_tear(fam, air, dir, opts)
	opts = opts or {}
	if not fam or not dir or dir:Length() < 0.01 then return nil end
	local speed = tonumber(opts.speed) or 10
	local n = dir:Normalized()
	local tear = nil
	if fam.FireProjectile then
		tear = fam:FireProjectile(n * speed)
	end
	if not tear then
		tear = Isaac.Spawn(
			EntityType.ENTITY_TEAR,
			opts.variant or TearVariant.BLOOD or 1,
			0,
			fam.Position,
			n * speed,
			fam
		)
	end
	if not tear then return nil end
	tear = tear:ToTear() or tear
	-- FireProjectile 常被玩家射击输入改向；强制写回瞄准速度
	tear.Velocity = n * speed
	tear.CollisionDamage = tonumber(opts.damage) or 3.5
	if opts.variant and tear.ChangeVariant and tear.Variant ~= opts.variant then
		tear:ChangeVariant(opts.variant)
	end
	tear.Parent = fam
	tear.SpawnerEntity = fam
	local Air = get_air_mod()
	local td = tear:GetData()
	td[Air.own_key.."craft_air"] = air
	td[Orb.own_key.."orbital_tear"] = true
	if opts.mark then
		td[item.own_key..opts.mark] = true
	end
	-- 与波比弟弟同一套：Height 不抬，PO 清零，PRE_TEAR_RENDER 做视觉 lift
	local H = require("Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
	if H.arm_tear_visual_lift then
		H.arm_tear_visual_lift(tear, fam, air)
	elseif tear.PositionOffset ~= nil then
		tear.PositionOffset = Vector(0, 0)
	end
	return tear
end

-- ---------- 509 Bloodshot Eye：环绕 Flight；仅当径向射线上有敌才开火并进 CD ----------
Orb.register_orbital(FamiliarVariant.BLOODSHOT_EYE or 116, {
	collectible = CollectibleType.COLLECTIBLE_BLOODSHOT_EYE or 509,
	kind = "bloodshot_eye",
	base_dps = 20,
	group = "normal",
	block = false,
	layout_ring = "middle",
	orbit_layer = 1,
	position_offset_mode = "air_relative",
	update = function(fam, bind, air, _buckets, state)
		if state ~= "active" or not air then return end
		local cd = tonumber(bind.tear_cd) or 0
		if cd > 0 then
			bind.tear_cd = cd - 1
			return
		end
		-- 幅角方向 = Flight → 自身；弹道方向固定径向，不转向敌人
		local radial = fam.Position - air.Position
		if radial:Length() < 1 then
			radial = bind.last_radial
			if not radial or radial:Length() < 1 then
				return
			end
		else
			bind.last_radial = radial:Normalized()
			radial = bind.last_radial
		end
		-- 仅当该射线上（前方锥内）有敌人时才发射；无敌不占冷却（异于普通泪宝宝持续开火）
		local range = tonumber(Orb.debug.bloodshot_range) or 220
		local cone = tonumber(Orb.debug.bloodshot_cone) or 0.72 -- cos 阈值，约 ±44°
		local has_enemy = false
		for _, npc in ipairs(Isaac.FindInRadius(fam.Position, range, EntityPartition.ENEMY)) do
			if npc:IsVulnerableEnemy() and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
				local to = npc.Position - fam.Position
				local len = to:Length()
				if len > 1 and (to / len):Dot(radial) >= cone then
					has_enemy = true
					break
				end
			end
		end
		if not has_enemy then return end

		local dmg = tonumber(Orb.debug.bloodshot_tear_dmg) or 3.5
		local player = auxi.check_spawner_player(air) or fam.Player
		if player and player:HasCollectible(CollectibleType.COLLECTIBLE_BFFS) then
			dmg = dmg * 2
		end
		local tear = fire_directed_tear(fam, air, radial, {
			speed = tonumber(Orb.debug.bloodshot_speed) or 6.5,
			damage = dmg,
			variant = TearVariant.BLOOD or 1,
		})
		if tear then
			bind.tear_cd = math.floor(tonumber(Orb.debug.bloodshot_cd) or 10)
		end
	end,
})

-- ---------- 467 Finger! ----------
-- 定向附件：以 Flight 为唯一根节点。原版 AI 的隐藏激光固定读取 player->Finger，
-- 与 Flight 接管移动天然冲突，因此绑定体完整跳过原版 AI，并按原版采样定频结算隐藏射线。
Orb.register_orbital(FamiliarVariant.FINGER or 110, {
	collectible = CollectibleType.COLLECTIBLE_FINGER or 467,
	kind = "finger",
	group = "normal",
	block = false,
	skip_layout = true,
	position_offset_mode = "air_centered",
	base_dps = 0,
	soft_rebind = true,
	detached_follow = true,
	custom_target = function(fam, bind, air)
		local reach = tonumber(Orb.debug.finger_reach) or 52
		local aim = air_current_facing(air)
		bind.last_aim = aim
		return air.Position + aim * reach
	end,
	-- full-control 在公共 POST_UPDATE 执行；只写速度，返回 true 防止通用 orbital 弹簧二次覆写。
	custom_drive = function(fam, bind, air, target)
		if not fam or not air or not target then return false end
		-- full-control Finger 禁止调用 FollowPosition：该原版 familiar 原语仍可能混入玩家根语义。
		-- 这里只以 Flight 槽位误差 + Flight 自身速度计算 Velocity，逻辑 Position 仍交给引擎积分。
		if fam.RemoveFromOrbit then fam:RemoveFromOrbit() end
		if fam.RemoveFromFollowers then fam:RemoveFromFollowers() end
		local delta = target - fam.Position
		local dist = delta:Length()
		-- 挂点速度同时包含 Flight 平移和转向产生的切向速度；只追位置误差会显得逐帧停顿。
		local target_velocity = air.Velocity or Vector.Zero
		if bind.finger_prev_target then
			target_velocity = target - bind.finger_prev_target
			if target_velocity:Length() > 18 then target_velocity = target_velocity:Resized(18) end
		end
		bind.finger_prev_target = Vector(target.X, target.Y)
		local desired
		if dist <= 2 then
			desired = target_velocity
		else
			desired = target_velocity + delta * 0.30
			local max_speed = (dist > 80) and 18 or 12
			if desired:Length() > max_speed then desired = desired:Resized(max_speed) end
		end
		fam.Velocity = fam.Velocity * 0.42 + desired * 0.58
		local fd = fam:GetData()
		fd[item.own_key.."finger_drive_frame"] = Game():GetFrameCount()
		fd[item.own_key.."finger_drive_target"] = Vector(target.X, target.Y)
		fd[item.own_key.."finger_drive_air_seed"] = air.InitSeed
		-- Finger 原版能力不是实体接触伤；禁止 orbital/原版 AI 遗留 CollisionDamage。
		fam.CollisionDamage = 0
		bind.vel = fam.Velocity
		bind.needs_snap = false
		bind.settle_frames = 0
		return true
	end,
	update = function(fam, bind, air, _buckets, state)
		local aim = bind.last_aim
		if not aim or aim:Length() < 0.01 then return end
		local frame = Game():GetFrameCount()
		-- ACTIVE_BOUND 可能持有同一实体的多个 userdata wrapper；Finger 的伤害/冷却每逻辑帧只推进一次。
		if bind.finger_update_frame == frame then return end
		bind.finger_update_frame = frame
		-- Rotation 第 0 帧朝正下；四向素材实际相同，固定首帧并只做连续旋转，避免方向表映射错误。
		local target_ang = aim:GetAngleDegrees()
		local cur_ang = tonumber(bind.finger_render_angle)
		if cur_ang == nil then cur_ang = target_ang end
		bind.finger_render_angle = auxi.checkrounded(cur_ang, target_ang, 0.65, 0.35, 360)
		local render_ang = bind.finger_render_angle
		local shoot_dir = Direction.RIGHT
		local ang = target_ang
		if ang >= -45 and ang < 45 then
			shoot_dir = Direction.RIGHT
		elseif ang >= 45 and ang < 135 then
			shoot_dir = Direction.DOWN
		elseif ang >= -135 and ang < -45 then
			shoot_dir = Direction.UP
		else
			shoot_dir = Direction.LEFT
		end
		if fam.ShootDirection ~= nil then
			fam.ShootDirection = shoot_dir
		end
		local spr = fam:GetSprite()
		if spr then
			-- Entity.SpriteRotation 是独立于 Sprite.Rotation 的第二层旋转；原版 AI 遗留值必须清零。
			fam.SpriteRotation = 0
			spr.Rotation = render_ang - 90
			fam.FlipX = false
			spr:SetFrame("Rotation", 0)
		end

		-- 原版每 3 逻辑帧结算一次无限隐藏射线（延伸至房间边界）。直接做胶囊命中，不生成 Laser 实体。
		-- 后者即使 Visible=false 仍执行多帧激光更新/碰撞，是多 Finger 时的主要卡顿源。
		if state == "inactive" then
			bind.finger_laser_cd = 0
			return
		end
		bind.finger_laser_cd = tonumber(bind.finger_laser_cd) or 0
		if bind.finger_laser_cd > 0 then
			bind.finger_laser_cd = bind.finger_laser_cd - 1
			return
		end
		local player = fam.Player or auxi.check_spawner_player(air)
		if not player then return end
		local origin = fam.Position + aim * 9.23077
		local length, width = finger_ray_length(origin, aim), 5.076453
		local damage = flight_damage(air) * 0.1
		for _, ent in ipairs(Isaac.FindInRadius(origin, length + 40, EntityPartition.ENEMY)) do
			local npc = ent:ToNPC()
			if npc and npc:IsVulnerableEnemy() and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
				local rel = npc.Position - origin
				local along = rel:Dot(aim)
				if along >= 0 and along <= length then
					local perpendicular = math.abs(rel.X * aim.Y - rel.Y * aim.X)
					if perpendicular <= width + (tonumber(npc.Size) or 0) then
						npc:TakeDamage(damage, DamageFlag.DAMAGE_LASER, EntityRef(fam), 0)
					end
				end
			end
		end
		bind.finger_laser_cd = 2
	end,
})

-- 手指探针开启时绘制延伸至房间边界的实际命中胶囊射线；正式模式零扫描、零绘制。
table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_RENDER,
	params = nil,
	Function = function(_)
		local cfg = FingerProbe and FingerProbe.get_config and FingerProbe.get_config()
		if not (cfg and cfg.enabled and Isaac.DrawLine) then return end
		for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FamiliarVariant.FINGER or 110, -1, false, false)) do
			local fam = ent:ToFamiliar()
			local bind = fam and Orb.get_bind and Orb.get_bind(fam)
			local aim = bind and bind.kind == "finger" and bind.last_aim or nil
			if aim and aim:Length() >= 0.01 then
				aim = aim:Normalized()
				local origin = fam.Position + aim * 9.23077
				local finish = origin + aim * finger_ray_length(origin, aim)
				local normal = Vector(-aim.Y, aim.X) * 5.076453
				-- PO 必须进入 WorldToScreen；这样画的是碰撞射线在当前升空高度下的视觉投影。
				local po = fam.PositionOffset or Vector.Zero
				local a, b = Isaac.WorldToScreen(origin + po), Isaac.WorldToScreen(finish + po)
				local a1, b1 = Isaac.WorldToScreen(origin + normal + po), Isaac.WorldToScreen(finish + normal + po)
				local a2, b2 = Isaac.WorldToScreen(origin - normal + po), Isaac.WorldToScreen(finish - normal + po)
				local center = KColor(1, 0.15, 0.1, 0.9)
				local edge = KColor(0.2, 0.9, 1, 0.65)
				Isaac.DrawLine(a, b, center, center, 2)
				Isaac.DrawLine(a1, b1, edge, edge, 1)
				Isaac.DrawLine(a2, b2, edge, edge, 1)
				Isaac.DrawLine(a1, a2, edge, edge, 1)
				Isaac.DrawLine(b1, b2, edge, edge, 1)
			end
		end
	end,
})

-- ---------- 544 Pointy Rib ----------
-- 以 Flight 为根，严格朝 Flight 最终攻击方向伸出；Sprite 旋转 = 方向角 - 90°，并角度插值。
-- 接触伤走 group=normal 的环绕物削弱（contact_mul / √n）。
Orb.register_orbital(FamiliarVariant.POINTY_RIB or 127, {
	collectible = CollectibleType.COLLECTIBLE_POINTY_RIB or 544,
	kind = "pointy_rib",
	group = "normal",
	block = false,
	skip_layout = true,
	position_offset_mode = "air_relative",
	detached_follow = true,
	contact_radius = 28,
	base_dps_fn = function(air, _bind)
		-- 基础 DPS；update_orbital 再乘 contact_mul/√n（及追敌折扣）
		return 6 * flight_damage(air)
	end,
	custom_target = function(fam, bind, air)
		local reach = tonumber(Orb.debug.pointy_rib_reach) or 48
		local aim = air_aim(air)
		bind.last_aim = aim
		return air.Position + aim * reach
	end,
	custom_drive = function(fam, bind, air, target)
		if not fam or not air or not target then return false end
		if fam.RemoveFromOrbit then fam:RemoveFromOrbit() end
		if fam.RemoveFromFollowers then fam:RemoveFromFollowers() end
		Familiar_Move_Driver.drive_to_position(fam, target, air.Velocity)
		bind.vel = fam.Velocity
		bind.needs_snap = false
		bind.settle_frames = 0
		return true
	end,
	update = function(fam, bind, _air, _buckets, _state)
		local aim = bind.last_aim
		if not aim or aim:Length() < 0.01 then return end
		local spr = fam:GetSprite()
		if not spr then return end
		-- 素材默认尖端朝上（+Y）。+90 仍反 180° → 使用 -90。
		local off = tonumber(Orb.debug.pointy_rib_rot_offset)
		if off == nil then off = -90 end
		local target_ang = aim:GetAngleDegrees() + off
		local cur = tonumber(bind.rib_rot)
		if cur == nil then
			cur = spr.Rotation or target_ang
		end
		local lerp = tonumber(Orb.debug.pointy_rib_rot_lerp)
		if lerp == nil then lerp = 0.35 end
		lerp = math.max(0.05, math.min(1, lerp))
		bind.rib_rot = auxi.checkrounded(cur, target_ang, 1 - lerp, lerp, 360)
		spr.Rotation = bind.rib_rot
	end,
})

-- ---------- 264 Smart Fly ----------
-- 常态环绕 Flight；受伤后 chase_until 内解除劫持，交还原版 AI 追敌，结束后再接管。
Orb.register_orbital(FamiliarVariant.SMART_FLY or 50, {
	collectible = CollectibleType.COLLECTIBLE_SMART_FLY or 264,
	kind = "smart_fly",
	base_dps = 6.5,
	group = "normal",
	block = true,
	skip_layout = true,
	layout_ring = "inner",
	orbit_layer = 0,
	position_offset_mode = "air_relative",
	should_vanilla_free = function(_fam, bind, _air)
		return Game():GetFrameCount() < (tonumber(bind.chase_until) or 0)
	end,
	custom_target = function(fam, bind, air)
		return default_orbit_target(fam, bind, air)
	end,
})

-- 511 Angry Fly / 548 Jaw Bone：故意不实装（不做制造兼容）

-- ---------- 528 Angelic Prism ----------
-- 对齐 My Emblem：不跳过原版 AI（分裂在 AI/碰撞里），在 MC_FAMILIAR_UPDATE 覆写 Velocity 钉 Flight。
-- soft_rebind：装配/卸下禁止 Position 瞬移，只软驱速度。
Orb.register_orbital(FamiliarVariant.ANGELIC_PRISM or 123, {
	collectible = CollectibleType.COLLECTIBLE_ANGELIC_PRISM or 528,
	kind = "angelic_prism",
	base_dps = 0,
	group = "normal",
	block = false,
	layout_ring = "middle",
	orbit_layer = 1,
	position_offset_mode = "air_relative",
	keep_vanilla_ai = true,
	soft_rebind = true,
})

-- ---------- 581 Psy Fly ----------
-- 探针：追弹加速（threat med~8 / p90~26），碰撞后下一帧销毁敌弹（非反弹）。
-- 禁止把弹幕 Position 当弹簧目标：err>90 会瞬移过去再闪回轨道。
local function psy_pick_threat(fam, air, search)
	local best, best_score = nil, -1e9
	for _, ent in ipairs(Isaac.FindInRadius(air.Position, search, EntityPartition.BULLET)) do
		local proj = ent:ToProjectile()
		if proj and enemy_projectile(proj) then
			local to_air = air.Position - proj.Position
			local d_air = to_air:Length()
			local closing = 0
			if d_air > 0.01 and proj.Velocity then
				closing = proj.Velocity:Dot(to_air:Normalized())
			end
			local d_fam = fam.Position:Distance(proj.Position)
			-- 优先朝 Flight 闭合；兼顾已接近苍蝇的弹
			local score = closing * 3 - d_air * 0.03 - d_fam * 0.02
			if score > best_score then
				best, best_score = proj, score
			end
		end
	end
	return best
end

local function psy_soft_drive(fam, bind, target, max_spd, blend)
	local err = target - fam.Position
	local dist = err:Length()
	local vel = bind.vel or fam.Velocity or Vector(0, 0)
	blend = math.max(0.05, math.min(1, tonumber(blend) or 0.3))
	max_spd = math.max(4, tonumber(max_spd) or 16)
	if dist > 0.5 then
		local desired_spd = math.min(max_spd, 6 + dist * 0.4)
		local desired = err:Resized(desired_spd)
		vel = vel * (1 - blend) + desired * blend
	else
		vel = vel * 0.85
	end
	if vel:Length() > max_spd then
		vel = vel:Resized(max_spd)
	end
	bind.vel = vel
	fam.Velocity = vel
end

local function psy_clear_trail(bind)
	SpriteTrails.clear(bind, "psy_trail")
end

local function psy_sync_trail(fam, bind)
	SpriteTrails.sync(fam, bind, "psy_trail", SpriteTrails.SMALL)
end

Orb.register_orbital(FamiliarVariant.PSY_FLY or 204, {
	collectible = CollectibleType.COLLECTIBLE_PSY_FLY or 581,
	kind = "psy_fly",
	base_dps = 15,
	group = "normal",
	block = true,
	skip_layout = true,
	layout_ring = "middle",
	orbit_layer = 1,
	position_offset_mode = "air_relative",
	orbit_distance = Vector(50, 42), -- 探针常态距玩家 med≈48.6 / OrbitDistance 50×42
	contact_radius = 20,
	custom_target = function(fam, bind, air)
		local search = tonumber(Orb.debug.psy_search) or 180
		local best = psy_pick_threat(fam, air, search)
		bind.intercept = best
		-- 只返回环绕点给 last_target/调试；追弹位移交给 custom_drive
		return default_orbit_target(fam, bind, air)
	end,
	custom_drive = function(fam, bind, air, target, _buckets, state)
		if not fam or not air or not target then return false end
		-- 追弹期禁止 snap/settle 瞬移
		bind.needs_snap = false
		bind.settle_frames = 0

		local proj = bind.intercept
		if proj and auxi.check_all_exists(proj) and enemy_projectile(proj) and state == "active" then
			local lead = tonumber(Orb.debug.psy_lead) or 2
			local aim = proj.Position + (proj.Velocity or Vector(0, 0)) * lead
			local max_spd = tonumber(Orb.debug.psy_chase_max) or 28
			local blend = tonumber(Orb.debug.psy_chase_blend) or 0.4
			psy_soft_drive(fam, bind, aim, max_spd, blend)
			bind.psy_chasing = true
			return true
		end

		-- 无威胁：软回 Flight 轨道（远距也只加速，不 Position 钉死）
		local max_spd = tonumber(Orb.debug.psy_return_max) or 18
		if bind.psy_chasing then
			max_spd = tonumber(Orb.debug.psy_return_max_after_chase) or 22
		end
		local dist = fam.Position:Distance(target)
		if dist < 10 then
			bind.psy_chasing = nil
		end
		psy_soft_drive(fam, bind, target, max_spd, tonumber(Orb.debug.psy_return_blend) or 0.28)
		return true
	end,
	-- 必须在 apply_render_offset 之后同步拖尾（用 Position+PO）
	update = function(fam, bind, _air, _buckets, _state)
		psy_sync_trail(fam, bind)
	end,
	on_block = function(_fam, bind, _proj, _air)
		-- 探针：碰撞后销毁，不是反弹/FRIENDLY
		local frame = Game():GetFrameCount()
		local cd_until = tonumber(bind.psy_cd_until) or 0
		if frame < cd_until then
			return false -- 仍销毁
		end
		bind.psy_streak = (tonumber(bind.psy_streak) or 0) + 1
		if bind.psy_streak >= (tonumber(Orb.debug.psy_streak_max) or 8) then
			bind.psy_streak = 0
			bind.psy_cd_until = frame + (tonumber(Orb.debug.psy_cd) or 20)
		end
		return false -- 走默认 proj:Die()
	end,
	release = function(_fam, bind, _reason)
		psy_clear_trail(bind)
	end,
})

-- ---------- 629 Bot Fly ----------
-- anm2：Fly（循环）/ Attack（11f，第 3 帧 Shoot）。劫持后必须自驱 Sprite:Update，否则 Attack 卡死。
-- 优先威胁：朝 Flight 闭合的敌弹；按泪速预判拦截点；LOST_CONTACT + TEAR_SHIELDED。
local function bot_predict_aim(from, tgt_pos, tgt_vel, shot_spd)
	if not from or not tgt_pos then return Vector(1, 0) end
	local vel = tgt_vel or Vector(0, 0)
	local spd = math.max(1, tonumber(shot_spd) or 12)
	local to = tgt_pos - from
	local dist = to:Length()
	if dist < 0.1 then return Vector(1, 0) end
	local t = dist / spd
	for _ = 1, 3 do
		local future = tgt_pos + vel * t
		t = future:Distance(from) / spd
	end
	local aim = (tgt_pos + vel * t) - from
	if aim:Length() < 0.01 then
		return (dist > 0.01) and to:Normalized() or Vector(1, 0)
	end
	return aim:Normalized()
end

local function bot_pick_threat(fam, air, search)
	local best, best_score = nil, -1e9
	for _, ent in ipairs(Isaac.FindInRadius(air.Position, search, EntityPartition.BULLET)) do
		local proj = ent:ToProjectile()
		if proj and enemy_projectile(proj) then
			local to_air = air.Position - proj.Position
			local d_air = to_air:Length()
			local closing = 0
			if d_air > 0.01 and proj.Velocity then
				closing = proj.Velocity:Dot(to_air:Normalized())
			end
			-- 优先：正朝 Flight 飞来；次之近距离
			local score = closing * 4 - d_air * 0.04 - fam.Position:Distance(proj.Position) * 0.01
			if score > best_score then
				best, best_score = proj, score
			end
		end
	end
	return best, best_score
end

local function bot_fire_shield_tear(fam, air, dir, tgt, shot_spd)
	if not fam or not dir or dir:Length() < 0.01 then return nil end
	local n = dir:Normalized()
	local spd = math.max(4, tonumber(shot_spd) or 12)
	local variant = TearVariant.LOST_CONTACT or 10
	local tear = Isaac.Spawn(
		EntityType.ENTITY_TEAR,
		variant,
		0,
		fam.Position,
		n * spd,
		fam
	)
	if not tear then return nil end
	tear = tear:ToTear() or tear
	tear.Velocity = n * spd
	tear.CollisionDamage = tonumber(Orb.debug.bot_tear_dmg) or 3
	if tear.AddTearFlags and TearFlags.TEAR_SHIELDED then
		tear:AddTearFlags(TearFlags.TEAR_SHIELDED)
	end
	tear.Parent = fam
	tear.SpawnerEntity = fam
	local Air = get_air_mod()
	local td = tear:GetData()
	td[Air.own_key.."craft_air"] = air
	td[Orb.own_key.."orbital_tear"] = true
	td[item.own_key.."bot_tear"] = true
	if tgt then
		td[item.own_key.."bot_target"] = tgt
	end
	local H = require("Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
	if H.arm_tear_visual_lift then
		H.arm_tear_visual_lift(tear, fam, air)
	elseif tear.PositionOffset ~= nil then
		tear.PositionOffset = Vector(0, 0)
	end
	return tear
end

Orb.register_orbital(FamiliarVariant.BOT_FLY or 218, {
	collectible = CollectibleType.COLLECTIBLE_BOT_FLY or 629,
	kind = "bot_fly",
	base_dps = 3,
	group = "normal",
	block = false,
	layout_ring = "middle",
	orbit_layer = 1,
	position_offset_mode = "air_relative",
	update = function(fam, bind, air, _buckets, state)
		if not fam or not air then return end
		local spr = fam:GetSprite()
		local shot_spd = tonumber(Orb.debug.bot_tear_speed) or 12
		local search = tonumber(Orb.debug.bot_search) or 160
		local cd = tonumber(bind.tear_cd) or 0
		if cd > 0 then
			bind.tear_cd = cd - 1
		end

		-- 显式阶段机 + 先 IsFinished 后补播（见 sprite_isfinished_before_isplaying.md）
		-- Attack 为 Loop=false；禁止用「anim ~= Fly → Play Fly」在 Attack 结束帧抢播。
		local phase = bind.bot_phase or "fly"

		if phase == "attack" then
			if not spr then
				-- 无 Sprite：直接开火并回 fly
				if not bind.bot_shot_this_attack and state == "active" then
					local tgt = bind.bot_pending_tgt
					local aim = bind.bot_pending_aim or Vector(1, 0)
					if tgt and auxi.check_all_exists(tgt) and enemy_projectile(tgt) then
						aim = bot_predict_aim(fam.Position, tgt.Position, tgt.Velocity, shot_spd)
					end
					bot_fire_shield_tear(fam, air, aim, tgt, shot_spd)
					bind.tear_cd = math.floor(tonumber(Orb.debug.bot_cd) or 20)
				end
				bind.bot_phase = "fly"
				bind.bot_shot_this_attack = nil
				bind.bot_pending_tgt = nil
				bind.bot_pending_aim = nil
				return
			end

			if spr:IsFinished("Attack") then
				bind.bot_phase = "fly"
				bind.bot_shot_this_attack = nil
				bind.bot_pending_tgt = nil
				bind.bot_pending_aim = nil
				spr:Play("Fly", true)
				return
			end
			-- 中断/未开始才补播；勿用 not IsPlaying 每帧 Play(true)
			if (spr:GetAnimation() or "") ~= "Attack" then
				spr:Play("Attack", true)
			end
			if not bind.bot_shot_this_attack then
				local fire_now = false
				if spr.IsEventTriggered and spr:IsEventTriggered("Shoot") then
					fire_now = true
				elseif spr:GetFrame() >= 3 then
					fire_now = true
				end
				if fire_now then
					bind.bot_shot_this_attack = true
					local tgt = bind.bot_pending_tgt
					if not (tgt and auxi.check_all_exists(tgt) and enemy_projectile(tgt)) then
						tgt = select(1, bot_pick_threat(fam, air, search))
					end
					local aim = bind.bot_pending_aim
					if tgt then
						aim = bot_predict_aim(fam.Position, tgt.Position, tgt.Velocity, shot_spd)
					elseif not aim then
						aim = Vector(1, 0)
					end
					if state == "active" then
						bot_fire_shield_tear(fam, air, aim, tgt, shot_spd)
					end
					bind.tear_cd = math.floor(tonumber(Orb.debug.bot_cd) or 20)
				end
			end
			return
		end

		-- fly 阶段：用 GetAnimation 判断；禁止 not IsPlaying("Fly")→Play(true)（会卡第0帧，见 orbital pitfalls）
		if spr then
			if (spr:GetAnimation() or "") ~= "Fly" then
				spr:Play("Fly", true)
			end
		end

		if state ~= "active" then return end
		if (tonumber(bind.tear_cd) or 0) > 0 then return end

		local best = select(1, bot_pick_threat(fam, air, search))
		if not best then return end

		local aim = bot_predict_aim(fam.Position, best.Position, best.Velocity, shot_spd)
		bind.bot_pending_tgt = best
		bind.bot_pending_aim = aim
		bind.bot_shot_this_attack = nil
		bind.bot_phase = "attack"
		if spr then
			spr:Play("Attack", true)
		else
			bot_fire_shield_tear(fam, air, aim, best, shot_spd)
			bind.tear_cd = math.floor(tonumber(Orb.debug.bot_cd) or 20)
			bind.bot_phase = "fly"
		end
	end,
})

-- Bot tear：持续追踪敌弹并销毁
table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_TEAR_UPDATE,
	params = nil,
	Function = function(_, tear)
		if not tear then return end
		local td = tear:GetData()
		if not td[item.own_key.."bot_tear"] then return end
		local tgt = td[item.own_key.."bot_target"]
		if not (tgt and auxi.check_all_exists(tgt) and enemy_projectile(tgt)) then
			-- 丢目标：再锁最近敌弹
			local best, best_d = nil, 80
			for _, ent in ipairs(Isaac.FindInRadius(tear.Position, best_d, EntityPartition.BULLET)) do
				local proj = ent:ToProjectile()
				if proj and enemy_projectile(proj) then
					local d = tear.Position:Distance(proj.Position)
					if d < best_d then best, best_d = proj, d end
				end
			end
			tgt = best
			td[item.own_key.."bot_target"] = tgt
		end
		if tgt and auxi.check_all_exists(tgt) then
			local spd = math.max(8, (tear.Velocity and tear.Velocity:Length()) or 12)
			local aim = bot_predict_aim(tear.Position, tgt.Position, tgt.Velocity, spd)
			local desired = aim * spd
			tear.Velocity = (tear.Velocity or desired) * 0.55 + desired * 0.45
		end
		for _, ent in ipairs(Isaac.FindInRadius(tear.Position, 12, EntityPartition.BULLET)) do
			local proj = ent:ToProjectile()
			if proj and enemy_projectile(proj) then
				proj:Die()
				tear:Remove()
				return
			end
		end
	end,
})

-- ---------- 645 Tinytoma ----------
local function tinytoma_on_block(fam, bind, _proj, air)
	local hp0 = (bind.kind == "tinytoma_small") and 2 or 3
	bind.tinytoma_hp = (tonumber(bind.tinytoma_hp) or hp0) - 1
	if bind.tinytoma_hp > 0 then
		return false
	end
	local player = auxi.check_spawner_player(air) or (fam and fam.Player)
	local col = CollectibleType.COLLECTIBLE_TINYTOMA or 645
	if bind.kind == "tinytoma" then
		if air then Orb.set_collectible_suppress(air, col, true) end
		for i = 0, 1 do
			local child = Isaac.Spawn(
				EntityType.ENTITY_FAMILIAR,
				FamiliarVariant.TINYTOMA_2 or 217,
				0,
				fam.Position + Vector((i == 0) and -8 or 8, 0),
				Vector.Zero,
				player
			):ToFamiliar()
			if child then
				child.Player = player
				Orb.bind_external_orbital(child, air, player, {
					source_id = col,
					kind = "tinytoma_small",
					slot = i,
					local_slot = i,
					layout_ring = "middle",
					group = "normal",
					base_dps = 3.5,
					block = true,
					orbit_layer = 1,
					synthetic = true,
					tinytoma_hp = 2,
				})
			end
		end
		fam:Remove()
		return false
	end
	for _ = 1, 3 do
		Isaac.Spawn(EntityType.ENTITY_FAMILIAR, FamiliarVariant.BLUE_SPIDER or 73, 0, fam.Position, RandomVector() * 3, player)
	end
	local ad = air and air:GetData()
	if ad then
		ad[item.own_key.."tinytoma_dead"] = (tonumber(ad[item.own_key.."tinytoma_dead"]) or 0) + 1
		if (tonumber(ad[item.own_key.."tinytoma_dead"]) or 0) >= 2 then
			ad[item.own_key.."tinytoma_respawn_at"] = Game():GetFrameCount() + 150
			ad[item.own_key.."tinytoma_dead"] = 0
			TINYTOMA_PENDING[air] = true
		end
	end
	fam:Remove()
	return false
end

Orb.register_orbital(FamiliarVariant.TINYTOMA or 216, {
	collectible = CollectibleType.COLLECTIBLE_TINYTOMA or 645,
	kind = "tinytoma",
	base_dps = 3.5,
	group = "normal",
	block = true,
	count = 1,
	layout_ring = "middle",
	orbit_layer = 1,
	position_offset_mode = "air_relative",
	on_block = tinytoma_on_block,
})

Orb.register_orbital(FamiliarVariant.TINYTOMA_2 or 217, {
	collectible = CollectibleType.COLLECTIBLE_TINYTOMA or 645,
	kind = "tinytoma_small",
	base_dps = 3.5,
	group = "normal",
	block = true,
	sync_from_profile = false, -- 分裂体不按材料再刷
	layout_ring = "middle",
	orbit_layer = 1,
	position_offset_mode = "air_relative",
	on_block = tinytoma_on_block,
})

-- Tinytoma 重生：只轮询待复生弱表。
table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function(_)
		local Air = get_air_mod()
		for air in pairs(TINYTOMA_PENDING) do
			local ok, alive = pcall(function() return air:Exists() and not air:IsDead() end)
			if not ok or not alive then
				TINYTOMA_PENDING[air] = nil
			else
				local ad = air:GetData()
				local at = tonumber(ad[item.own_key.."tinytoma_respawn_at"])
				if not at then
					TINYTOMA_PENDING[air] = nil
				elseif Game():GetFrameCount() >= at then
					TINYTOMA_PENDING[air] = nil
					ad[item.own_key.."tinytoma_respawn_at"] = nil
					Orb.set_collectible_suppress(air, CollectibleType.COLLECTIBLE_TINYTOMA or 645, false)
					local prof = ad[Air.own_key.."craft_profile"]
					if prof and Orb.sync_air_flight then
						local player = auxi.check_spawner_player(air)
						if player then Orb.sync_air_flight(air, player, prof) end
					end
				end
			end
		end
	end,
})

-- 默认 debug 旋钮（挂到 Orb.debug，ImGui 可后续扩展）
Orb.debug.sworn_attract_radius = Orb.debug.sworn_attract_radius or 48
Orb.debug.sworn_heart_threshold = Orb.debug.sworn_heart_threshold or 10
Orb.debug.bloodshot_cd = Orb.debug.bloodshot_cd or 10
Orb.debug.bloodshot_tear_dmg = Orb.debug.bloodshot_tear_dmg or 3.5
Orb.debug.bloodshot_speed = Orb.debug.bloodshot_speed or 6.5
Orb.debug.bloodshot_range = Orb.debug.bloodshot_range or 220
Orb.debug.bloodshot_cone = Orb.debug.bloodshot_cone or 0.72
Orb.debug.pointy_rib_reach = Orb.debug.pointy_rib_reach or 48
-- 尖肋素材尖端朝上；旧默认 +90 实测反 180°，统一 -90
do
	local off = tonumber(Orb.debug.pointy_rib_rot_offset)
	if off == nil or off == 0 or off == 90 then
		Orb.debug.pointy_rib_rot_offset = -90
	end
end
Orb.debug.pointy_rib_rot_lerp = Orb.debug.pointy_rib_rot_lerp or 0.35
Orb.debug.smart_fly_chase_frames = Orb.debug.smart_fly_chase_frames or 180
Orb.debug.psy_search = Orb.debug.psy_search or 160
Orb.debug.psy_streak_max = Orb.debug.psy_streak_max or 3
Orb.debug.psy_cd = Orb.debug.psy_cd or 45
Orb.debug.bot_search = Orb.debug.bot_search or 160
Orb.debug.bot_cd = Orb.debug.bot_cd or 20
Orb.debug.bot_tear_speed = Orb.debug.bot_tear_speed or 12
Orb.debug.bot_tear_dmg = Orb.debug.bot_tear_dmg or 3

return item
