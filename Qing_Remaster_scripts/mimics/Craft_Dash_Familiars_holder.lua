-- 冲刺类制造宝宝：Little Chubby / Big Chubby / Lil Gurdy
-- Chubby：formation→windup→outbound→return→recover→formation
-- Gurdy：蓄力→弹墙冲刺（探针：初速≈5..25、boost 期微加速、其后 *0.98、墙弹近似弹性）
local H = require("Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")
local Familiar_Control_Selector = require("Qing_Remaster_scripts.mimics.Familiar_Control_Selector")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "Craft_Dash_Familiars_holder_",
}

-- 原版拷贝：resources/gfx/effects/chargebar/chargebar.anm2
local GURDY_CHARGE_BAR_ANM2 = "gfx/effects/chargebar/chargebar.anm2"
local GURDY_CHARGE_BAR_OFFSET = Vector(16, -42)
local GURDY_BAR_ID = item.own_key.."gurdy"
local GURDY_CHARGE_BAR_SPRITE_KEY = GURDY_BAR_ID.."_Charge_Bar"
local GURDY_VARIANT = FamiliarVariant.LIL_GURDY or 87

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

local function dir_suffix(dir)
	if dir == Direction.LEFT or dir == Direction.RIGHT then return "Side" end
	if dir == Direction.UP then return "Up" end
	return "Down"
end

local function aim_to_dir(aim)
	if not aim or aim:Length() < 0.01 then return Direction.DOWN end
	return auxi.GetDirectionByAngle(aim:GetAngleDegrees())
end

local function leaving_states(adapter, state)
	if adapter and adapter.name == "lil_gurdy" then
		return state == "dashing" or state == "dash_stop"
	end
	return state == "windup" or state == "outbound" or state == "wall_stick" or state == "return"
end

local function is_leaving(adapter, fam)
	local d = data(fam)
	local state = d[key("state")] or "formation"
	return leaving_states(adapter, state)
end

local function hit_wall_or_timeout(fam, air, d, max_time)
	local age = (tonumber(d[key("flight_age")]) or 0) + 1
	d[key("flight_age")] = age
	if age >= (max_time or 90) then return true, "timeout" end
	local room = Game():GetRoom()
	local next_pos = fam.Position + fam.Velocity
	if not room:IsPositionInRoom(next_pos, 8) then return true, "oob" end
	-- 贴墙：速度被挡且前方不可通行
	if fam.Velocity:Length() < 0.4 and age > 4 then
		local dir = d[key("dash_dir")] or Vector(0, 1)
		local probe = fam.Position + dir:Normalized() * 12
		if not room:IsPositionInRoom(probe, 4) then return true, "wall" end
	end
	return false
end

local function apply_collision_damage(fam, adapter, player)
	local base = tonumber(adapter.collision_damage) or 3.5
	fam.CollisionDamage = base * bffs_mul(player, adapter)
end

local function play_chubby_anim(fam, state, aim)
	local sprite = fam:GetSprite()
	local dir = aim_to_dir(aim)
	local suffix = dir_suffix(dir)
	-- 原版探针：抵达末端后仍保持 FloatShoot* 片刻，再切 Float 飞回
	local anim = "Float"
	if state == "windup" or state == "outbound" or state == "wall_stick" then
		anim = "FloatShoot"..suffix
	end
	if not sprite:IsPlaying(anim) then
		sprite:Play(anim, true)
	end
	fam.FlipX = (dir == Direction.LEFT)
end

local function play_gurdy_anim(fam, state)
	local sprite = fam:GetSprite()
	local anim = "Idle"
	if state == "charge_start" then anim = "ChargeStart"
	elseif state == "charging" then anim = "Charging"
	elseif state == "dashing" then anim = "Dashing"
	elseif state == "dash_stop" then anim = "DashStop"
	end
	if not sprite:IsPlaying(anim) then
		sprite:Play(anim, true)
	end
end

local function read_press_edge(ctx, d)
	-- 与蓄力宝宝一致：用 holder 解析后的 ctx.should_shoot（含有效瞄准），
	-- 不要读原始 intent.should_shoot。
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
	if pressed then
		d[key("aim_epoch")] = (tonumber(d[key("aim_epoch")]) or 0) + 1
	end
	d[key("was_want")] = want
	return want, pressed, released, aim
end

local function hide_vanilla_charge_bar(fam)
	-- Gurdy 原版条跟正 FireCooldown 走（0 空～90 满）。写 999999 会显示「永远满条」。
	-- 制造接管只压掉原版条：写 0；进度走模组 Charging_Bar_holder。
	if fam and fam.FireCooldown ~= nil then
		fam.FireCooldown = 0
	end
end

local function clear_gurdy_mod_bar(fam)
	if not fam then return end
	Charging_Bar_holder.remove_charge_bar(fam, GURDY_BAR_ID)
	local d = data(fam)
	-- render_me 在 Disappear 结束后只卸占位，不卸 Sprite；取消/冲出后必须显式清掉，
	-- 否则偶发残留到小退重载才消失。
	d[GURDY_CHARGE_BAR_SPRITE_KEY] = nil
	d[GURDY_BAR_ID.."_Charge_Bar_buff"] = nil
	d[GURDY_CHARGE_BAR_SPRITE_KEY.."_Clock"] = nil
	d[key("bar_charge")] = 0
end

local function gurdy_bar_is_charged(fam)
	local bar = data(fam)[GURDY_CHARGE_BAR_SPRITE_KEY]
	return bar ~= nil and bar:IsPlaying("Charged")
end

local function safe_recycle(fam, d, reason)
	d[key("state")] = "formation"
	d[key("flight_age")] = nil
	d[key("dash_dir")] = nil
	d[key("charge")] = nil
	d[key("boost_fc")] = nil
	d[key("blood_cd")] = nil
	d[key("bounce_cd")] = nil
	d[key("stop_age")] = nil
	d[key("windup_left")] = nil
	d[key("recover_left")] = nil
	d[key("stick_left")] = nil
	d[key("attack_spent")] = nil
	d[key("await_release")] = nil
	d[key("full_wait")] = nil
	d[key("bar_charge")] = nil
	d[key("crawl_frames")] = nil
	fam.Velocity = fam.Velocity * 0.2
	d[key("recycle_reason")] = reason
	clear_gurdy_mod_bar(fam)
end

-- 探针：满蓄 FC≈90 → 初速 25；低蓄近似线性 5..25。冲刺中 FC 每帧 -3。
local function gurdy_init_speed(charge, full, adapter)
	full = math.max(1, tonumber(full) or 90)
	charge = math.max(0, math.min(full, tonumber(charge) or 0))
	local min_spd = tonumber(adapter and adapter.min_dash_speed) or 5
	local max_spd = tonumber(adapter and adapter.max_dash_speed) or 25
	return min_spd + (max_spd - min_spd) * (charge / full)
end

local function gurdy_spawn_blood(fam)
	if not fam then return end
	-- RGON：短效血迹并染色地面（非常驻实体）
	if fam.SpawnBloodEffect then
		fam:SpawnBloodEffect(0, fam.Position, Vector.Zero, nil, Vector.Zero)
		return
	end
	Isaac.Spawn(
		EntityType.ENTITY_EFFECT,
		EffectVariant.BLOOD_SPLAT or 7,
		0,
		fam.Position,
		Vector.Zero,
		fam
	)
end

local function gurdy_bounce_fx(fam, adapter)
	local sfx = (adapter and adapter.bounce_sfx) or SoundEffect.SOUND_MEAT_IMPACTS or 69
	SFXManager():Play(sfx, 1, 0, false, 1)
	gurdy_spawn_blood(fam)
end

local function gurdy_begin_dash(adapter, fam, d, player, aim, charge, full)
	local ratio = math.max(0, math.min(1, charge / full))
	local spd = gurdy_init_speed(charge, full, adapter)
	d[key("boost_fc")] = math.floor(charge + 0.5)
	d[key("flight_age")] = 0
	d[key("blood_cd")] = 0
	d[key("bounce_cd")] = 0
	d[key("dash_dir")] = (d[key("dash_dir")] or aim):Normalized()
	local min_dmg = tonumber(adapter.min_collision_damage) or 5
	local max_dmg = tonumber(adapter.max_collision_damage) or 20
	fam.CollisionDamage = (min_dmg + (max_dmg - min_dmg) * ratio) * bffs_mul(player, adapter)
	fam.Velocity = d[key("dash_dir")] * spd
	if fam.GridCollisionClass ~= nil then
		fam.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_WALLS
	end
end

-- 弹墙：夹紧探测反射；保速反射；低速加摩擦以便尽快 DashStop。返回当前速率。
local function gurdy_apply_dash_motion(fam, d, adapter)
	local vel = fam.Velocity
	local spd = vel:Length()
	if spd < 0.01 then
		return 0
	end
	local boost = tonumber(d[key("boost_fc")]) or 0
	local base_fric = tonumber(adapter.friction) or 0.98
	local slow_spd = tonumber(adapter.slow_friction_speed) or 4.5
	local slow_fric = tonumber(adapter.slow_friction) or 0.88
	if boost > 0 then
		vel = vel + vel:Normalized() * (tonumber(adapter.boost_accel) or 0.07)
		boost = boost - (tonumber(adapter.boost_fc_step) or 3)
		d[key("boost_fc")] = boost
	else
		-- 慢速额外减速，缩短「爬行不回收」尾段
		if spd < slow_spd then
			vel = vel * slow_fric
		else
			vel = vel * base_fric
		end
	end

	local room = Game():GetRoom()
	local margin = tonumber(adapter.wall_margin) or 12
	local next_pos = fam.Position + vel
	local clamped = room:GetClampedPosition(next_pos, margin)
	local bounce_cd = tonumber(d[key("bounce_cd")]) or 0
	if bounce_cd > 0 then
		d[key("bounce_cd")] = bounce_cd - 1
	end
	local bounced = false
	local pre_spd = vel:Length()
	if bounce_cd <= 0 then
		if math.abs(clamped.X - next_pos.X) > 0.5 then
			vel = Vector(-vel.X, vel.Y)
			bounced = true
		end
		if math.abs(clamped.Y - next_pos.Y) > 0.5 then
			vel = Vector(vel.X, -vel.Y)
			bounced = true
		end
	end
	if bounced then
		d[key("bounce_cd")] = 4
		-- 保速反射，避免引擎/夹墙把速度打没后看起来「撞一下就泄能」
		if pre_spd > 0.01 and vel:Length() > 0.01 then
			vel = vel:Normalized() * pre_spd
		end
		fam.Position = clamped
		gurdy_bounce_fx(fam, adapter)
	end

	fam.Velocity = vel
	spd = vel:Length()

	local blood_cd = tonumber(d[key("blood_cd")]) or 0
	if blood_cd > 0 then
		d[key("blood_cd")] = blood_cd - 1
	elseif spd > (tonumber(adapter.blood_min_speed) or 3) then
		d[key("blood_cd")] = tonumber(adapter.blood_interval) or 5
		gurdy_spawn_blood(fam)
	end

	if vel.X < -0.5 then
		fam.FlipX = true
	elseif vel.X > 0.5 then
		fam.FlipX = false
	end
	return spd
end

local function update_chubby(adapter, ctx)
	local fam, air, player = ctx.familiar, ctx.air, ctx.player
	if not fam then return end
	local d = data(fam)
	if not air or not auxi.check_all_exists(air) then
		safe_recycle(fam, d, "no_air")
		return
	end
	local want, pressed, released, aim = read_press_edge(ctx, d)
	local state = d[key("state")] or "formation"
	local speed = tonumber(adapter.dash_speed) or 14
	local max_out = tonumber(adapter.max_outbound) or 75
	local windup = tonumber(adapter.windup_frames) or 4
	local recover = tonumber(adapter.recover_frames) or 6
	local stick_frames = tonumber(adapter.wall_stick_frames) or 15
	local catch_dist = tonumber(adapter.catch_distance) or 22

	apply_collision_damage(fam, adapter, player)

	-- 一次冲锋结束后需松手再按，才接受下一次飞行器攻击指令
	if d[key("await_release")] then
		if released or not want then
			d[key("await_release")] = nil
		else
			pressed = false
		end
	end

	if state == "formation" then
		if pressed and want and not d[key("attack_spent")] then
			state = "windup"
			d[key("dash_dir")] = aim:Normalized()
			d[key("windup_left")] = windup
			d[key("flight_age")] = 0
			d[key("epoch")] = d[key("aim_epoch")]
			d[key("air_seed")] = air.InitSeed
			d[key("attack_spent")] = true
			local sfx = adapter.dash_sfx
			if sfx then
				SFXManager():Play(sfx, 1, 0, false, 1)
			end
		end
	elseif state == "windup" then
		local left = (tonumber(d[key("windup_left")]) or 0) - 1
		d[key("windup_left")] = left
		fam.Velocity = fam.Velocity * 0.7
		if left <= 0 then
			state = "outbound"
			local dir = d[key("dash_dir")] or aim
			fam.Velocity = dir:Normalized() * speed
			if fam.FireCooldown ~= nil then fam.FireCooldown = -1 end -- Sewing 观察点
		end
	elseif state == "outbound" then
		local dir = d[key("dash_dir")] or Vector(0, 1)
		fam.Velocity = dir:Normalized() * speed
		local hit = hit_wall_or_timeout(fam, air, d, max_out)
		if hit then
			state = "wall_stick"
			d[key("stick_left")] = stick_frames
			d[key("flight_age")] = 0
			-- 微速保持朝向，贴墙停住
			fam.Velocity = dir:Normalized() * 0.05
		end
	elseif state == "wall_stick" then
		local left = (tonumber(d[key("stick_left")]) or 0) - 1
		d[key("stick_left")] = left
		local dir = d[key("dash_dir")] or Vector(0, 1)
		fam.Velocity = dir:Normalized() * 0.05
		if left <= 0 then
			state = "return"
			d[key("flight_age")] = 0
		end
	elseif state == "return" then
		local delta = air.Position - fam.Position
		local dist = delta:Length()
		if dist < catch_dist then
			state = "recover"
			d[key("recover_left")] = recover
			fam.Velocity = Vector(0, 0)
		else
			local ret_speed = tonumber(adapter.return_speed) or (speed * 0.85)
			fam.Velocity = delta:Resized(math.min(ret_speed, dist * 0.35))
			local hit = hit_wall_or_timeout(fam, air, d, max_out + 60)
			if hit and dist < catch_dist * 2 then
				state = "recover"
				d[key("recover_left")] = recover
			end
		end
	elseif state == "recover" then
		local left = (tonumber(d[key("recover_left")]) or 0) - 1
		d[key("recover_left")] = left
		fam.Velocity = fam.Velocity * 0.5
		if left <= 0 then
			state = "formation"
			d[key("attack_spent")] = nil
			d[key("await_release")] = want == true
			if fam.FireCooldown ~= nil then fam.FireCooldown = tonumber(adapter.base_cooldown) or 20 end
		end
	end

	d[key("state")] = state
	play_chubby_anim(fam, state, d[key("dash_dir")] or aim)
end

local function update_gurdy(adapter, ctx)
	local fam, air, player = ctx.familiar, ctx.air, ctx.player
	if not fam then return end
	local d = data(fam)
	if not air or not auxi.check_all_exists(air) then
		safe_recycle(fam, d, "no_air")
		play_gurdy_anim(fam, "formation")
		hide_vanilla_charge_bar(fam)
		return
	end
	-- Flight 攻击窗口语义（对齐亚巴顿等）：
	-- want=持续蓄力；满蓄自动冲出；窗口结束只取消未满蓄力，绝不当作“松手开火”。
	local want, _, _, aim = read_press_edge(ctx, d)
	local state = d[key("state")] or "formation"
	local full = tonumber(adapter.full_charge) or 90
	local charge = tonumber(d[key("charge")]) or 0
	local step = lullaby_step(player, adapter)
	local auto_full = adapter.auto_fire_when_full
	if auto_full == nil then auto_full = true end

	hide_vanilla_charge_bar(fam)

	local function begin_dash_now()
		state = "dashing"
		gurdy_begin_dash(adapter, fam, d, player, aim, charge, full)
		d[key("charge")] = 0
		charge = 0
		clear_gurdy_mod_bar(fam)
	end

	local function cancel_charge()
		state = "formation"
		charge = 0
		d[key("charge")] = 0
		d[key("full_wait")] = nil
		clear_gurdy_mod_bar(fam)
	end

	if state == "formation" or state == "idle" then
		state = "formation"
		apply_collision_damage(fam, adapter, player)
		if want then
			state = "charge_start"
			charge = step
			d[key("charge")] = charge
			d[key("dash_dir")] = aim:Normalized()
		else
			charge = 0
			d[key("charge")] = 0
		end
	elseif state == "charge_start" then
		local sprite = fam:GetSprite()
		if want then
			charge = math.min(full, charge + step)
			d[key("charge")] = charge
			d[key("dash_dir")] = aim:Normalized()
			fam.Velocity = fam.Velocity * 0.75
			if sprite:IsFinished("ChargeStart") or not sprite:IsPlaying("ChargeStart") then
				state = "charging"
				play_gurdy_anim(fam, "charging")
			end
			if auto_full and charge >= full then
				if gurdy_bar_is_charged(fam) then
					begin_dash_now()
				else
					local wait = (tonumber(d[key("full_wait")]) or 0) + 1
					d[key("full_wait")] = wait
					-- 自绘条未就绪时兜底，避免永远卡在满蓄
					if wait >= 10 then begin_dash_now() end
				end
			else
				d[key("full_wait")] = nil
			end
		else
			-- 攻击窗口结束：取消蓄力，不发射
			cancel_charge()
		end
	elseif state == "charging" then
		if want then
			charge = math.min(full, charge + step)
			d[key("charge")] = charge
			d[key("dash_dir")] = aim:Normalized()
			fam.Velocity = fam.Velocity * 0.75
			if auto_full and charge >= full then
				if gurdy_bar_is_charged(fam) then
					begin_dash_now()
				else
					local wait = (tonumber(d[key("full_wait")]) or 0) + 1
					d[key("full_wait")] = wait
					if wait >= 10 then begin_dash_now() end
				end
			else
				d[key("full_wait")] = nil
			end
		else
			cancel_charge()
		end
	elseif state == "dashing" then
		local age = (tonumber(d[key("flight_age")]) or 0) + 1
		d[key("flight_age")] = age
		local spd = gurdy_apply_dash_motion(fam, d, adapter)
		local max_age = tonumber(adapter.max_dash_frames) or 240
		local stop_spd = tonumber(adapter.stop_speed) or 2.0
		local crawl = tonumber(adapter.crawl_speed) or 3.0
		if spd < crawl then
			d[key("crawl_frames")] = (tonumber(d[key("crawl_frames")]) or 0) + 1
		else
			d[key("crawl_frames")] = 0
		end
		local crawl_frames = tonumber(d[key("crawl_frames")]) or 0
		local crawl_limit = tonumber(adapter.crawl_stop_frames) or 8
		if (spd < stop_spd and age > 12) or crawl_frames >= crawl_limit or age >= max_age then
			state = "dash_stop"
			d[key("stop_age")] = 0
			d[key("crawl_frames")] = nil
			fam.Velocity = fam.Velocity * 0.5
		end
	elseif state == "dash_stop" then
		local age = (tonumber(d[key("stop_age")]) or 0) + 1
		d[key("stop_age")] = age
		fam.Velocity = fam.Velocity * 0.7
		local sprite = fam:GetSprite()
		if sprite:IsFinished("DashStop") or age > 18 then
			state = "formation"
			d[key("charge")] = 0
			d[key("boost_fc")] = nil
			fam.Velocity = Vector(0, 0)
			apply_collision_damage(fam, adapter, player)
			-- 持续攻击窗口仍在：下一帧可再蓄
		end
	end

	d[key("state")] = state
	d[key("bar_charge")] = tonumber(d[key("charge")]) or 0
	d[key("bar_full")] = full
	hide_vanilla_charge_bar(fam)
	if state == "formation" then
		play_gurdy_anim(fam, "formation")
	else
		play_gurdy_anim(fam, state)
	end
end

local function register(variant, adapter)
	if adapter.supports_bffs == nil then adapter.supports_bffs = true end
	if adapter.supports_lullaby == nil then adapter.supports_lullaby = true end
	if adapter.supports_bender == nil then adapter.supports_bender = false end
	adapter.control_mode = "full"
	adapter.custom_animation = true
	adapter.no_fire = true
	if adapter.skip_tick_cooldown == nil and adapter.name == "lil_gurdy" then
		adapter.skip_tick_cooldown = true
	end
	adapter.fire = function() return false end
	adapter.is_leaving_formation = is_leaving
	adapter.on_snap = function(_, fam)
		safe_recycle(fam, data(fam), "snap")
	end
	adapter.acquire = function(_, fam)
		local d = data(fam)
		if d[key("saved_fire_cooldown")] == nil and fam and fam.FireCooldown ~= nil then
			d[key("saved_fire_cooldown")] = fam.FireCooldown
		end
		d[key("state")] = "formation"
		d[key("charge")] = 0
		d[key("bar_charge")] = 0
		d[key("was_want")] = nil
		hide_vanilla_charge_bar(fam)
	end
	adapter.release = function(_, fam)
		local d = data(fam)
		local saved_fire_cooldown = d[key("saved_fire_cooldown")]
		safe_recycle(fam, d, "release")
		d[key("was_want")] = nil
		d[key("last_aim")] = nil
		d[key("bar_charge")] = nil
		d[key("bar_full")] = nil
		d[key("saved_fire_cooldown")] = nil
		if fam and fam.FireCooldown ~= nil then
			fam.FireCooldown = tonumber(saved_fire_cooldown) or 0
		end
		if fam and adapter.name == "lil_gurdy" then
			clear_gurdy_mod_bar(fam)
		end
	end
	H.register_adapter(variant, adapter)
end

-- 在 PRE 就压掉原版条，避免引擎在 POST 更新前按上一帧 FC/蓄力动画画出残留条。
table.insert(item.pre_ToCall, {
	CallBack = ModCallbacks.MC_PRE_FAMILIAR_UPDATE,
	params = GURDY_VARIANT,
	Function = function(_, fam)
		if not fam then return end
		if not Familiar_Control_Selector.is_owner(fam, Familiar_Control_Selector.BLUEPRINT) then return end
		hide_vanilla_charge_bar(fam)
	end,
})

register(FamiliarVariant.LITTLE_CHUBBY, {
	name = "little_chubby",
	extra_key = "little_chubby",
	collectible = CollectibleType.COLLECTIBLE_LITTLE_CHUBBY or 88,
	class = "dash",
	collision_damage = 3.5,
	dash_speed = 16,
	return_speed = 13,
	max_outbound = 70,
	windup_frames = 3,
	recover_frames = 5,
	-- 探针：贴墙段 FC -2..-10 且 FloatShoot*，小约 7–8 帧、大约 9 帧
	wall_stick_frames = 8,
	catch_distance = 20,
	base_cooldown = 18,
	dash_sfx = SoundEffect.SOUND_LITTLE_CHUBBY_ATTACK or 849,
	update = update_chubby,
})

register(FamiliarVariant.BIG_CHUBBY, {
	name = "big_chubby",
	extra_key = "big_chubby",
	collectible = CollectibleType.COLLECTIBLE_BIG_CHUBBY or 473,
	class = "dash",
	collision_damage = 5.25,
	dash_speed = 10,
	return_speed = 8,
	max_outbound = 100,
	windup_frames = 5,
	recover_frames = 8,
	wall_stick_frames = 9,
	catch_distance = 28,
	base_cooldown = 28,
	dash_sfx = SoundEffect.SOUND_BIG_CHUBBY_ATTACK or 835,
	update = update_chubby,
})

register(FamiliarVariant.LIL_GURDY, {
	name = "lil_gurdy",
	extra_key = "lil_gurdy",
	collectible = CollectibleType.COLLECTIBLE_LIL_GURDY or 384,
	class = "dash_charge",
	collision_damage = 5,
	min_collision_damage = 5,
	max_collision_damage = 20,
	min_dash_speed = 5,
	max_dash_speed = 25,
	full_charge = 90,
	min_charge = 10,
	friction = 0.98,
	slow_friction = 0.88,
	slow_friction_speed = 4.5,
	boost_accel = 0.07,
	boost_fc_step = 3,
	stop_speed = 2.0,
	crawl_speed = 3.0,
	crawl_stop_frames = 8,
	blood_interval = 5,
	blood_min_speed = 5,
	bounce_sfx = SoundEffect.SOUND_MEAT_IMPACTS or 69,
	max_dash_frames = 240,
	catch_distance = 24,
	base_cooldown = 20,
	auto_fire_when_full = true,
	skip_tick_cooldown = true,
	update = update_gurdy,
})

-- 撞敌也弹（原版 wiki：walls + enemies）。return true 跳过引擎默认碰撞，避免速度被二次打没。
table.insert(item.pre_ToCall, {
	CallBack = ModCallbacks.MC_PRE_FAMILIAR_COLLISION,
	params = GURDY_VARIANT,
	Function = function(_, fam, collider, _low)
		if not fam or not collider then return end
		if not Familiar_Control_Selector.is_owner(fam, Familiar_Control_Selector.BLUEPRINT) then return end
		local d = data(fam)
		if d[key("state")] ~= "dashing" then return end
		local npc = collider:ToNPC()
		if not npc or not npc:IsVulnerableEnemy() then return end
		local bounce_cd = tonumber(d[key("bounce_cd")]) or 0
		if bounce_cd > 0 then return true end
		local away = fam.Position - collider.Position
		if away:Length() < 0.01 then
			away = fam.Velocity:Length() > 0.01 and fam.Velocity or Vector(0, 1)
		end
		local spd = math.max(fam.Velocity:Length(), 4)
		fam.Velocity = away:Normalized() * spd
		d[key("bounce_cd")] = 5
		d[key("dash_dir")] = fam.Velocity:Normalized()
		-- 跳过引擎碰撞以免泄速；伤害需自结
		local dmg = fam.CollisionDamage or 5
		if dmg > 0 and npc.TakeDamage then
			npc:TakeDamage(dmg, 0, EntityRef(fam), 0)
		end
		local adapter = H.get_adapter and H.get_adapter(fam.Variant) or nil
		if not adapter then
			adapter = { bounce_sfx = SoundEffect.SOUND_MEAT_IMPACTS or 69 }
		end
		gurdy_bounce_fx(fam, adapter)
		return true
	end,
})

-- Lil Gurdy 自绘蓄力条：只显示模组条；原版 FireCooldown 条由 hide_vanilla_charge_bar 压掉
table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_FAMILIAR_RENDER,
	params = GURDY_VARIANT,
	Function = function(_, fam, _offset)
		if not fam then return end
		if not Familiar_Control_Selector.is_owner(fam, Familiar_Control_Selector.BLUEPRINT) then
			clear_gurdy_mod_bar(fam)
			return
		end
		local d = data(fam)
		local state = d[key("state")]
		local charge = tonumber(d[key("bar_charge")]) or tonumber(d[key("charge")]) or 0
		local full = math.max(1, tonumber(d[key("bar_full")]) or 90)
		local show = (state == "charge_start" or state == "charging") and charge > 0
		if not show then
			clear_gurdy_mod_bar(fam)
			return
		end
		local cnt = math.ceil(charge / full * 100)
		Charging_Bar_holder.render_me(fam, {
			name1 = GURDY_BAR_ID,
			name2 = GURDY_BAR_ID,
			name3 = GURDY_BAR_ID,
			loadname = GURDY_CHARGE_BAR_ANM2,
			offset = GURDY_CHARGE_BAR_OFFSET,
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

-- 换房强制回收
table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		local variants = {
			FamiliarVariant.LITTLE_CHUBBY,
			FamiliarVariant.BIG_CHUBBY,
			FamiliarVariant.LIL_GURDY,
		}
		for _, variant in ipairs(variants) do
			for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, variant, -1, false, false)) do
				local fam = ent:ToFamiliar()
				if fam then
					local bind = fam:GetData()[H.own_key.."bind"]
					if bind then
						safe_recycle(fam, data(fam), "new_room")
					end
				end
			end
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
