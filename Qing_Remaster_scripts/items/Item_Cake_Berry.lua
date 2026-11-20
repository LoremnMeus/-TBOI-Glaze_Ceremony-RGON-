-- 草莓蛋糕派：每次真实玩家攻击独立判定，派生一枚弹跳蛋糕。
-- 碰撞：额外飞行 + 视觉碎屑 + 范围 0.3× 伤害与减速；死亡碎裂仅视觉。
local enums = require("Qing_Remaster_scripts.core.enums")
local attack_holder = require("Qing_Remaster_scripts.callbacks.attack_trigger_holder")
local classifier = attack_holder.classifier
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local CraftTearParams = require("Qing_Remaster_scripts.others.craft_tear_params_data")
local Nil_holder = require("Qing_Remaster_scripts.others.Nil_holder")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Cake_Berry,
	own_key = "Item_Cake_Berry_",
	base_chance = 0.08,
	luck_chance = 0.02,
	max_chance = 0.34,
	damage_multiplier = 1.0,
	splash_damage_multiplier = 0.3,
	-- Idle → Idle2 → Flip(Idle) → Idle3，每段 flip_interval 个泪弹更新帧
	flip_interval = 3,
	large_crumb_chance = 0.18,
	large_crumb_speed_mul = 0.58,
	slow_frames = 45,
	slow_factor = 0.7,
	burst_radius = 80,
	bounce_bonus_frames = 12,
	bounce_bonus_cap = 36,
	crumb_min = 4,
	crumb_max = 6,
	-- 短窗口内连续碰撞：后续粒子衰减，避免贴墙/连环反弹刷屏
	crumb_vfx_cd = 8,
	crumb_cd_min = 1,
	crumb_cd_max = 2,
	death_crumb_min = 8,
	death_crumb_max = 12,
	crumb_anm2 = "gfx/mimics/Cake_Berry/cake_crumb.anm2",
	crumb_small_anm2 = "gfx/mimics/Cake_Berry/cake_crumb_16.anm2",
	crumb_tiny_anm2 = "gfx/mimics/Cake_Berry/cake_crumb_8.anm2",
	tear_anm2 = "gfx/mimics/Cake_Berry/cake_berry_tear.anm2",
}

local function player_has_item(player)
	return player and player:GetCollectibleNum(item.entity) > 0
end

local function trigger_chance(player)
	local luck = math.max(0, player.Luck or 0)
	return math.min(item.max_chance, item.base_chance + luck * item.luck_chance)
end

local function mark_cake_tear(tear)
	if not tear then
		return
	end
	local data = tear:GetData()
	data[item.own_key .. "tear"] = true
	data[item.own_key .. "visual_ready"] = false
	data[item.own_key .. "bonus_granted"] = 0
	tear.TearFlags = tear.TearFlags | TearFlags.TEAR_BOUNCE
end

local function pink_tint(rng)
	return Color(1, 0.55 + rng:RandomFloat() * 0.35, 0.7, 1, 0.15, 0, 0.05)
end

local function tear_visual_height(tear)
	if not tear then
		return 0
	end
	local po = tear.PositionOffset
	if po then
		return math.max(0, -po.Y)
	end
	return 0
end

-- 返回 anm2, speed_mul。大碎屑（100% 原生 32）略稀有且更慢。
local function pick_crumb_anm2(rng)
	local roll = rng:RandomFloat()
	if roll < item.large_crumb_chance then
		return item.crumb_anm2, item.large_crumb_speed_mul
	end
	-- 其余在 16 / 8 间大致均分
	if roll < item.large_crumb_chance + (1 - item.large_crumb_chance) * 0.5 then
		return item.crumb_small_anm2, 1
	end
	return item.crumb_tiny_anm2, 1
end

--- Idle → Idle2 → Flip(Idle) → Idle3
local function update_cake_tear_visual(sprite, frame_count)
	local phase = math.floor(frame_count / item.flip_interval) % 4
	local anim = "Idle"
	local flip = false
	if phase == 1 then
		anim = "Idle2"
	elseif phase == 2 then
		anim = "Idle"
		flip = true
	elseif phase == 3 then
		anim = "Idle3"
	end
	if sprite:GetAnimation() ~= anim then
		sprite:Play(anim, true)
	end
	sprite.FlipX = flip
	-- 翻面只靠 FlipX / Idle 序列；禁止引擎按速度带旋转
	sprite.Rotation = 0
end

--- opts: count_min/max, speed_min/max, vz_min/max, height, force_anm2
local function spawn_landing_crumbs(position, owner, rng, opts)
	opts = opts or {}
	local count_min = opts.count_min or item.crumb_min
	local count_max = opts.count_max or item.crumb_max
	local speed_min = opts.speed_min or 2
	local speed_max = opts.speed_max or 5
	local vz_min = opts.vz_min or 0.8
	local vz_max = opts.vz_max or 2.8
	local height0 = math.max(0, tonumber(opts.height) or 0)
	local count = count_min + rng:RandomInt(math.max(1, count_max - count_min + 1))
	local speed_span = math.max(0, speed_max - speed_min)
	local vz_span = math.max(0, vz_max - vz_min)

	for _ = 1, count do
		local anm2 = opts.force_anm2
		local speed_mul = 1
		if not anm2 then
			anm2, speed_mul = pick_crumb_anm2(rng)
		end
		local speed = (speed_min + rng:RandomFloat() * speed_span) * speed_mul
		local direction = Vector.FromAngle(rng:RandomFloat() * 360)
		-- cooldown 宽裕；真实移除由落地/淡出阶段控制
		local crumb = auxi.fire_nil(position, direction * speed, {
			cooldown = 180,
			player = owner,
		})
		if crumb then
			local sprite = crumb:GetSprite()
			sprite:Load(anm2, true)
			sprite:Play("Idle", true)
			sprite.Rotation = rng:RandomFloat() * 360
			local tint = pink_tint(rng)
			sprite.Color = tint

			local d = crumb:GetData()
			d.nil_mode = "cake_berry_crumb"
			d.skip_nil_distance_cull = true
			local land_stay = 6 + rng:RandomInt(5)
			local fade_frames = 10 + rng:RandomInt(3)
			local rise = (vz_min + rng:RandomFloat() * vz_span) * speed_mul
			d[item.own_key .. "crumb"] = {
				-- alt>=0 离地高度；PositionOffset.Y = -alt。alt_v>0 上升，gravity 每帧扣减。
				alt = height0 + rng:RandomFloat() * 2,
				alt_v = rise,
				gravity = 0.28 + rng:RandomFloat() * 0.10,
				air_drag = 0.96,
				land_drag = 0.78,
				rot_speed = (rng:RandomFloat() * 28 - 14) * speed_mul,
				phase = "air",
				land_left = land_stay,
				fade_left = fade_frames,
				fade_max = fade_frames,
				base_a = tint.A,
				tint = tint,
			}
			crumb.PositionOffset = Vector(0, -d[item.own_key .. "crumb"].alt)
		end
	end
end

Nil_holder.register("cake_berry_crumb", {
	detect = function(d)
		return d[item.own_key .. "crumb"]
	end,
	update = function(ent, d, s)
		local st = d[item.own_key .. "crumb"]
		if not st then
			ent:Remove()
			return
		end

		if st.phase == "air" then
			ent.Velocity = ent.Velocity * (st.air_drag or 0.96)
			st.alt_v = (st.alt_v or 0) - (st.gravity or 0.32)
			st.alt = (st.alt or 0) + st.alt_v
			if st.rot_speed and st.rot_speed ~= 0 then
				s.Rotation = s.Rotation + st.rot_speed
			end
			if st.alt <= 0 then
				st.alt = 0
				st.alt_v = 0
				st.rot_speed = 0
				st.phase = "land"
			end
		elseif st.phase == "land" then
			ent.Velocity = ent.Velocity * (st.land_drag or 0.78)
			st.land_left = (st.land_left or 0) - 1
			if st.land_left <= 0 then
				st.phase = "fade"
			end
		else
			ent.Velocity = ent.Velocity * (st.land_drag or 0.78)
			st.fade_left = (st.fade_left or 0) - 1
			local fade_max = math.max(1, st.fade_max or 1)
			local alpha = math.max(0, (st.fade_left / fade_max) * (st.base_a or 1))
			local tint = st.tint or Color(1, 0.7, 0.8, 1, 0.15, 0, 0.05)
			s.Color = Color(tint.R, tint.G, tint.B, alpha, tint.RO, tint.GO, tint.BO)
			if st.fade_left <= 0 then
				ent:Remove()
				return
			end
		end

		ent.PositionOffset = Vector(0, -(st.alt or 0))
		-- 防止 Nil_holder 寿命抢先移除
		if d.removecd ~= nil and d.removecd < 8 then
			d.removecd = 8
		end
	end,
})

-- 额外粉色散射：原生 8×8 碎屑（不 SpriteScale），比主碎屑初速更高；物理参数与主碎屑相同。
local function scatter_pink_particles(position, owner, rng, height)
	spawn_landing_crumbs(position, owner, rng, {
		count_min = 3,
		count_max = 4,
		speed_min = 4.5,
		speed_max = 8,
		vz_min = 0.8,
		vz_max = 2.6,
		height = height or 0,
		force_anm2 = item.crumb_tiny_anm2,
	})
end

-- 每次有效碰撞：范围内每个敌人至多一次 splash（与碎屑数量无关）+ 减速。
local function apply_area_impact(position, owner, tear, data)
	local source = owner and owner:Exists() and EntityRef(owner) or EntityRef(tear)
	local base = (data and data[item.own_key .. "base_damage"]) or (tear and tear.CollisionDamage) or 3.5
	local splash = base * item.splash_damage_multiplier
	for _, entity in ipairs(Isaac.FindInRadius(position, item.burst_radius, EntityPartition.ENEMY)) do
		local npc = entity:ToNPC()
		if npc and npc:IsActiveEnemy(false) then
			if splash > 0 then
				npc:TakeDamage(splash, 0, source, 0)
			end
			npc:AddSlowing(source, item.slow_frames, item.slow_factor, Color(1, 0.85, 0.9, 1, 0.1, 0, 0))
		end
	end
end

local function try_flush_area_impact(tear, data)
	local pending = data[item.own_key .. "pending_area"]
	if not pending then
		return
	end
	if Game():GetFrameCount() < (pending.ready_frame or 0) then
		return
	end
	data[item.own_key .. "pending_area"] = nil
	apply_area_impact(pending.pos, data[item.own_key .. "owner"], tear, data)
end

local function velocity_bounced(prev, cur)
	if not prev or not cur then
		return false
	end
	if math.abs(prev.X) > 0.5 and prev.X * cur.X < 0 then
		return true
	end
	if math.abs(prev.Y) > 0.5 and prev.Y * cur.Y < 0 then
		return true
	end
	local delta = math.abs(((cur:GetAngleDegrees() - prev:GetAngleDegrees() + 180) % 360) - 180)
	return delta >= 40
end

local function handle_cake_death_scatter(tear, data)
	if data[item.own_key .. "death_scattered"] then
		return
	end
	data[item.own_key .. "death_scattered"] = true
	-- 与同帧碰撞结算互斥
	data[item.own_key .. "impact_frame"] = Game():GetFrameCount()

	local owner = data[item.own_key .. "owner"]
	local rng = tear:GetDropRNG()
	spawn_landing_crumbs(tear.Position, owner, rng, {
		count_min = item.death_crumb_min,
		count_max = item.death_crumb_max,
		speed_min = 3,
		speed_max = 7,
		vz_min = 1.2,
		vz_max = 3.5,
		height = tear_visual_height(tear),
	})
end

--- opts.defer_area：敌人 PRE 碰撞时延后一帧结算范围伤害，避免抢在原生 1.0× 命中之前。
local function handle_cake_impact(tear, data, position, opts)
	opts = opts or {}
	if data[item.own_key .. "death_scattered"] or tear:IsDead() then
		return
	end
	local frame = Game():GetFrameCount()
	if data[item.own_key .. "impact_frame"] == frame then
		return
	end
	data[item.own_key .. "impact_frame"] = frame

	local impact_pos = position or tear.Position
	local owner = data[item.own_key .. "owner"]
	local rng = tear:GetDropRNG()

	local granted = data[item.own_key .. "bonus_granted"] or 0
	local room = math.max(0, item.bounce_bonus_cap - granted)
	local bonus = math.min(item.bounce_bonus_frames, room)
	if bonus > 0 then
		CraftTearParams.extend_flight(tear, bonus)
		data[item.own_key .. "bonus_granted"] = granted + bonus
	end

	local visual_h = tear_visual_height(tear)
	local last_vfx = data[item.own_key .. "vfx_frame"]
	local in_vfx_cd = last_vfx ~= nil and (frame - last_vfx) < item.crumb_vfx_cd
	if in_vfx_cd then
		spawn_landing_crumbs(impact_pos, owner, rng, {
			count_min = item.crumb_cd_min,
			count_max = item.crumb_cd_max,
			speed_min = 2,
			speed_max = 4,
			vz_min = 0.6,
			vz_max = 2.0,
			height = visual_h,
		})
	else
		spawn_landing_crumbs(impact_pos, owner, rng, {
			count_min = item.crumb_min,
			count_max = item.crumb_max,
			speed_min = 2,
			speed_max = 5,
			vz_min = 0.8,
			vz_max = 2.6,
			height = visual_h,
		})
		scatter_pink_particles(impact_pos, owner, rng, visual_h)
		data[item.own_key .. "vfx_frame"] = frame
	end

	data[item.own_key .. "pending_area"] = {
		pos = Vector(impact_pos.X, impact_pos.Y),
		ready_frame = opts.defer_area and (frame + 1) or frame,
	}

	-- 音量/音高随机放在粒子 RNG 之后，避免搅乱碎屑分布；样本文件由 sounds.xml 权重随机。
	local volume = 0.4 + rng:RandomFloat() * 0.2
	local pitch = 0.90 + rng:RandomFloat() * 0.20
	SFXManager():Play(enums.SoundEffect.Cake_Berry_Plate_Impact, volume, 0, false, pitch)
end

local function launch_cake(player, attack, position, direction)
	if not player or not player:Exists() or not player_has_item(player) or not position or not direction then
		return
	end
	local mode = (attack and attack.active and not attack.ending) and "inherit" or "untracked"
	local tear = attack_holder.FireTear(player, position, direction * ((player.ShotSpeed or 1) * 9), {
		mode = mode,
		role = "derived",
		reason = "cake_berry",
		attack = mode == "inherit" and attack or nil,
		family = "tear",
		can_be_eye = false,
		damage_multiplier = item.damage_multiplier,
	})
	mark_cake_tear(tear)
	if tear then
		local data = tear:GetData()
		data[item.own_key .. "owner"] = player
		-- 快照生成时基础碰撞伤害（1.0×），供范围 splash 共用同一数值源。
		data[item.own_key .. "base_damage"] = tear.CollisionDamage or (player.Damage or 3.5)
	end
end

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_ATTACK_ONCE,
	params = nil,
	Function = function(_, event)
		local player = event and event.player
		local attack = event and event.attack
		local member = event and event.member
		if not player_has_item(player) or not attack or not member then
			return
		end
		if classifier.IsSyntheticSampleAttack(attack) then
			return
		end
		local source = event.attack_source or attack.source
		if not classifier.IsPlayerAttackSource(source) then
			return
		end
		attack.tags = attack.tags or {}
		if attack.tags.cake_berry_checked then
			return
		end
		attack.tags.cake_berry_checked = true
		local rng = player:GetCollectibleRNG(item.entity)
		if rng:RandomFloat() >= trigger_chance(player) then
			return
		end
		local aim = classifier.GetAttackAimContext(source, attack, event)
		if aim and aim.state == "pending" then
			attack_holder.WhenAttackDirectionReady(attack, function(atk, direction, state)
				if state ~= "resolved" or not direction then
					return
				end
				local position = (aim and aim.position) or (atk and atk.position) or player.Position
				launch_cake(player, atk, position, direction)
			end)
			return
		end
		if not aim or not aim.direction then
			return
		end
		launch_cake(player, attack, aim.position or player.Position, aim.direction)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_TEAR_UPDATE,
	params = nil,
	Function = function(_, tear)
		local data = tear:GetData()
		if data[item.own_key .. "tear"] ~= true then
			return
		end

		if tear:IsDead() then
			-- 死亡不追加范围伤害/减速；若仍有未到期 splash 也不再结算。
			data[item.own_key .. "pending_area"] = nil
			handle_cake_death_scatter(tear, data)
			return
		end

		try_flush_area_impact(tear, data)

		local sprite = tear:GetSprite()
		if data[item.own_key .. "visual_ready"] ~= true then
			sprite:Load(item.tear_anm2, true)
			data[item.own_key .. "visual_ready"] = true
		end
		update_cake_tear_visual(sprite, tear.FrameCount)

		local vel = tear.Velocity
		local last = data[item.own_key .. "last_velocity"]
		if tear:CollidesWithGrid() and velocity_bounced(last, vel) then
			handle_cake_impact(tear, data, tear.Position, {defer_area = false})
		end
		data[item.own_key .. "last_velocity"] = Vector(vel.X, vel.Y)
		try_flush_area_impact(tear, data)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION,
	params = nil,
	Function = function(_, tear, collider, _low)
		local data = tear:GetData()
		if data[item.own_key .. "tear"] ~= true then
			return
		end
		if data[item.own_key .. "death_scattered"] or tear:IsDead() then
			return
		end
		local npc = collider and collider.ToNPC and collider:ToNPC()
		if npc and npc:IsActiveEnemy(false) then
			handle_cake_impact(tear, data, npc.Position, {defer_area = true})
		end
	end,
})

return item
