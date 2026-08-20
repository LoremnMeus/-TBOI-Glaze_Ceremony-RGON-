-- 投射物式制造宝宝：273 鲍勃脑浆 / 178 圣水
-- 共享：follow → launch(速≈10) → 命中 impact → hidden(~305) → respawn(CD≈60)
--                 ↘ 空枪 miss_slow(速度折半) → follow(CD≈30)
-- 脑浆：进门保护；命中爆炸吃 BOMB_EFFECTS+毒
-- 圣水：无进门保护；仅命中敌人才碎（水迹 37 ± 大宝蓝火 10）；空枪不碎、回编队
-- 禁止沿用「受伤/落地必碎」的旧版叙述——探针空枪样本全程 Float、无 Break/水迹。
local H = require("Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")
local Bomb_holder = require("Qing_Remaster_scripts.mimics.Bomb_holder")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "Craft_Projectile_Familiars_holder_",
}

local function data(fam)
	return fam:GetData()
end

local function key(name)
	return item.own_key .. name
end

local function bffs_mul(player, adapter)
	if adapter and adapter.supports_bffs == false then return 1 end
	if player and player:HasCollectible(CollectibleType.COLLECTIBLE_BFFS or 247) then
		return tonumber(adapter and adapter.bffs_damage_mul) or 2
	end
	return 1
end

local function room_age()
	local room = Game():GetRoom()
	return room and (tonumber(room:GetFrameCount()) or 0) or 0
end

local function read_press_edge(ctx, d)
	local intent = ctx.intent or {}
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
	local pressed = want and not was
	local released = was and not want
	d[key("was_want")] = want
	return want, pressed, released, aim
end

local function set_collidable(fam, on)
	if not fam then return end
	if on then
		fam.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ENEMIES
		fam.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_WALLS
	else
		fam.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
		fam.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	end
end

local function hit_enemy(fam)
	for _, npc in ipairs(Isaac.FindInRadius(fam.Position, (fam.Size or 13) + 8, EntityPartition.ENEMY)) do
		if npc:IsVulnerableEnemy() and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
			return npc
		end
	end
	return nil
end

local function hit_wall_or_timeout(fam, d, max_time)
	local age = (tonumber(d[key("flight_age")]) or 0) + 1
	d[key("flight_age")] = age
	if age >= (max_time or 90) then return true, "timeout" end
	local room = Game():GetRoom()
	local next_pos = fam.Position + (fam.Velocity or Vector.Zero)
	if room and not room:IsPositionInRoom(next_pos, 8) then return true, "oob" end
	if (fam.Velocity or Vector.Zero):Length() < 0.35 and age > 6 then
		return true, "stall"
	end
	return false
end

local function brain_explode(fam, player, bind, adapter)
	local pos = Vector(fam.Position.X, fam.Position.Y)
	local profile = bind and bind.profile
	local mul = bffs_mul(player, adapter)
	local base = tonumber(adapter.explode_damage) or 100
	local dmg = base * mul
	local size_mul = mul > 1 and (tonumber(adapter.bffs_radius_mul) or 1.5) or 1
	local flags = BitSet128(0, 0)
	if profile then
		flags = select(1, CraftProfile.bomb_effects_from_counts(profile.counts, fam.InitSeed))
	end
	-- 原版脑浆必带毒
	if TearFlags and TearFlags.TEAR_POISON then
		flags = flags | TearFlags.TEAR_POISON
	end
	if player and profile then
		local bomb = player:FireBomb(pos, Vector.Zero, player)
		if bomb then
			bomb.ExplosionDamage = dmg
			if bomb.RadiusMultiplier ~= nil then
				bomb.RadiusMultiplier = size_mul
			end
			Bomb_holder.attach_craft_aux(bomb, profile, player, {
				damage_mul = mul,
				size_mul = size_mul,
			})
			-- 叠配方 flags 之外再保证毒
			if bomb.AddTearFlags then bomb:AddTearFlags(flags) end
			if bomb.SetExplosionCountdown then
				bomb:SetExplosionCountdown(0)
			end
			return
		end
	end
	Game():BombExplosionEffects(pos, dmg, flags, Color.Default, player, size_mul, true, false)
end

local function holy_impact(fam, player, adapter)
	local pos = Vector(fam.Position.X, fam.Position.Y)
	local creep_v = EffectVariant.PLAYER_CREEP_HOLYWATER or 37
	local creep = Isaac.Spawn(EntityType.ENTITY_EFFECT, creep_v, 0, pos, Vector.Zero, player):ToEffect()
	if creep then
		creep.Timeout = tonumber(adapter.creep_timeout) or 289
		creep.Scale = 1
		if creep.Size ~= nil then creep.Size = tonumber(adapter.creep_size) or 60 end
	end
	if player and player:HasCollectible(CollectibleType.COLLECTIBLE_BFFS or 247) then
		local flame_v = EffectVariant.BLUE_FLAME or 10
		local flame = Isaac.Spawn(EntityType.ENTITY_EFFECT, flame_v, 0, pos, Vector.Zero, player):ToEffect()
		if flame then
			flame.Timeout = tonumber(adapter.flame_timeout) or 289
			flame.Scale = 1
			if flame.Size ~= nil then flame.Size = tonumber(adapter.flame_size) or 16 end
			flame.CollisionDamage = tonumber(adapter.flame_damage) or 6
			-- 探针：Tint 白，Offset.G≈0.2
			flame.Color = Color(1, 1, 1, 1, 0, 0.2, 0)
		end
	end
end

local function enter_hidden(fam, d, adapter, reason)
	d[key("state")] = "hidden"
	d[key("hidden_left")] = tonumber(adapter.hidden_frames) or 305
	d[key("hidden_reason")] = reason
	fam.Visible = false
	fam.Velocity = Vector.Zero
	fam.CollisionDamage = 0
	set_collidable(fam, false)
	local spr = fam:GetSprite()
	if spr and adapter.break_anim then
		spr:Play(adapter.break_anim, true)
	end
end

local function enter_follow(fam, d, adapter, air, cd)
	d[key("state")] = "follow"
	d[key("flight_age")] = 0
	d[key("await_release")] = true
	fam.Visible = true
	set_collidable(fam, true)
	fam.CollisionDamage = tonumber(adapter.collision_damage) or 0
	if fam.FireCooldown ~= nil then
		fam.FireCooldown = math.max(0, math.floor(tonumber(cd) or 0))
	end
	if air then
		fam.Position = Vector(air.Position.X, air.Position.Y)
		fam.Velocity = Vector.Zero
	end
	local spr = fam:GetSprite()
	if spr then
		local anim = adapter.idle_anim or "Float"
		if not spr:IsPlaying(anim) then spr:Play(anim, true) end
	end
end

local function update_projectile(adapter, ctx)
	local fam, air, player, bind = ctx.familiar, ctx.air, ctx.player, ctx.bind
	if not fam then return end
	local d = data(fam)
	if not air or not auxi.check_all_exists(air) then
		enter_follow(fam, d, adapter, nil, 0)
		return
	end

	local want, pressed, released, aim = read_press_edge(ctx, d)
	local state = d[key("state")] or "follow"
	local launch_speed = tonumber(adapter.launch_speed) or 10
	local max_flight = tonumber(adapter.max_flight_frames) or 90

	-- full-control：自行倒数 FireCooldown（原版 AI 被跳过）
	if fam.FireCooldown ~= nil and fam.FireCooldown > 0 then
		fam.FireCooldown = fam.FireCooldown - 1
	end

	if d[key("await_release")] then
		if released or not want then
			d[key("await_release")] = nil
		else
			pressed = false
		end
	end

	-- 重生冷却：FireCooldown 倒数期间不可再射
	if state == "follow" and fam.FireCooldown ~= nil and fam.FireCooldown > 0 then
		pressed = false
	end

	if state == "follow" then
		fam.Visible = true
		set_collidable(fam, true)
		fam.CollisionDamage = tonumber(adapter.collision_damage) or 0
		-- custom_move 跳过 do_follow：跟随时自行钉 Flight
		if fam.FollowPosition then
			fam:FollowPosition(air.Position)
		end
		local delta = air.Position - fam.Position
		local dist = delta:Length()
		if dist > 8 then
			local speed = math.min(14, (dist - 8) * 0.35)
			fam.Velocity = delta:Resized(speed)
		else
			fam.Velocity = (fam.Velocity or Vector.Zero) * 0.25
		end
		if air.PositionOffset then
			fam.PositionOffset = Vector(air.PositionOffset.X, air.PositionOffset.Y + 16)
		end
		local protect = tonumber(adapter.door_protect_frames) or 0
		local blocked = protect > 0 and room_age() < protect
		if pressed and want and not blocked then
			state = "launch"
			d[key("state")] = state
			d[key("dash_dir")] = aim:Normalized()
			d[key("flight_age")] = 0
			fam.Velocity = aim:Normalized() * launch_speed
			if fam.FireCooldown ~= nil then fam.FireCooldown = -1 end
			local spr = fam:GetSprite()
			if spr and adapter.launch_anim then
				spr:Play(adapter.launch_anim, true)
			end
		end
	elseif state == "launch" then
		local dir = d[key("dash_dir")] or aim
		fam.Velocity = dir:Normalized() * launch_speed
		local enemy = hit_enemy(fam)
		if enemy then
			if adapter.impact == "bomb" then
				brain_explode(fam, player, bind, adapter)
			else
				holy_impact(fam, player, adapter)
			end
			enter_hidden(fam, d, adapter, "hit")
		else
			local wall = hit_wall_or_timeout(fam, d, max_flight)
			if wall then
				-- 空枪：与脑浆相同，减速回编队，不破碎、不生成水迹/爆炸
				d[key("state")] = "miss_slow"
				d[key("miss_frames")] = 0
			end
		end
	elseif state == "miss_slow" then
		-- 探针：打空后速度约每帧折半；FC 经 -2..-10 后置 miss_cooldown(≈30)
		fam.Velocity = (fam.Velocity or Vector.Zero) * 0.5
		local frames = (tonumber(d[key("miss_frames")]) or 0) + 1
		d[key("miss_frames")] = frames
		if fam.Velocity:Length() < 0.4 or frames >= 12 then
			enter_follow(fam, d, adapter, air, tonumber(adapter.miss_cooldown) or 30)
		end
	elseif state == "hidden" then
		fam.Visible = false
		fam.Velocity = Vector.Zero
		fam.CollisionDamage = 0
		set_collidable(fam, false)
		-- 藏在 Flight 旁，换房 SNAP 仍可消费
		if air then
			fam.Position = Vector(air.Position.X, air.Position.Y)
		end
		local left = (tonumber(d[key("hidden_left")]) or 1) - 1
		d[key("hidden_left")] = left
		if left <= 0 then
			-- 命中破碎后重生冷却（探针脑浆≈60；圣水同结构）
			local cd = tonumber(adapter.respawn_cooldown) or 60
			enter_follow(fam, d, adapter, air, cd)
			local spr = fam:GetSprite()
			if spr and adapter.appear_anim then
				spr:Play(adapter.appear_anim, true)
			end
		end
	end
end

local function is_leaving(_adapter, fam)
	local d = data(fam)
	local state = d[key("state")] or "follow"
	return state == "launch" or state == "miss_slow" or state == "hidden"
end

local function register_proj(variant, adapter)
	adapter.update = update_projectile
	adapter.is_leaving_formation = is_leaving
	adapter.custom_move = true
	adapter.custom_animation = true
	adapter.no_fire = true
	adapter.exclude_from_formation = true
	adapter.soft_rebind = true
	if adapter.supports_bffs == nil then adapter.supports_bffs = true end
	if adapter.supports_lullaby == nil then adapter.supports_lullaby = false end
	adapter.on_snap = function(_, fam)
		local d = data(fam)
		if (d[key("state")] or "follow") ~= "hidden" then
			enter_follow(fam, d, adapter, nil, 0)
		end
	end
	adapter.release = function(_, fam)
		local d = data(fam)
		d[key("state")] = nil
		d[key("await_release")] = nil
		fam.Visible = true
		set_collidable(fam, true)
	end
	H.register_adapter(variant, adapter)
end

register_proj(FamiliarVariant.BOBS_BRAIN or 59, {
	name = "bobs_brain",
	extra_key = "bobs_brain",
	collectible = CollectibleType.COLLECTIBLE_BOBS_BRAIN or 273,
	impact = "bomb",
	launch_speed = 10,
	max_flight_frames = 90,
	hidden_frames = 305,
	miss_cooldown = 30,
	respawn_cooldown = 60,
	door_protect_frames = 30,
	explode_damage = 100,
	bffs_radius_mul = 1.5,
	collision_damage = 3.5,
	idle_anim = "Float",
	launch_anim = "Float",
})

register_proj(FamiliarVariant.HOLY_WATER or 25, {
	name = "holy_water",
	extra_key = "holy_water",
	collectible = CollectibleType.COLLECTIBLE_HOLY_WATER or 178,
	impact = "holy",
	launch_speed = 10,
	max_flight_frames = 90,
	hidden_frames = 305,
	miss_cooldown = 30,
	respawn_cooldown = 60,
	door_protect_frames = 0,
	creep_timeout = 289,
	creep_size = 60,
	flame_timeout = 289,
	flame_size = 16,
	flame_damage = 6,
	collision_damage = 7,
	idle_anim = "Float",
	launch_anim = "Float",
	break_anim = "Break",
	appear_anim = "Appear",
})

return item
