-- 宝宝泰克罗：蓄力预瞄细光柱，松手后沿已锁定光路 Impale（复用 Tecrorun.load_impale / control_impale）
local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")
local Baby_Anim = require("Qing_Remaster_scripts.others.Baby_Anim_holder")
local Tecrorun = require("Qing_Remaster_scripts.player.player_Tecrorun")

local TK = Tecrorun.own_key

local item = {
	ToCall = {},
	pre_ToCall = {},
	post_ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	post_myToCall = {},
	entity = enums.Items.Baby_Tecro,
	familiar = enums.Familiars.Baby_Tecro,
	own_key = "Item_Baby_Tecro_",
	max_charge = 60,
	aim_lerp = 0.22,
	axis_grace_frames = 3,
	preview_bounces = 3,
	wall_margin = -20,
	height_offset = Vector(0, -15),
	laser_fade_in_frames = 10,
	effect_scale = 0.72,
	dmgmul = 0.4,
	rangerate = 0.45,
	impale_steps_per_frame = 2,
}

local function ensure_charge(d)
	if type(d[item.own_key.."charging"]) ~= "table" then
		d[item.own_key.."charging"] = {
			progress = 0,
			maxCharge = item.max_charge,
			lastInput = false,
			storedDir = Vector(0, 1),
			displayDir = Vector(0, 1),
			prev_axes = 0,
			axis_grace = 0,
		}
	end
	return d[item.own_key.."charging"]
end

local function axis_count(dir)
	if not dir then return 0 end
	local n = 0
	if math.abs(dir.X) > 0.35 then n = n + 1 end
	if math.abs(dir.Y) > 0.35 then n = n + 1 end
	return n
end

local function charge_rate(chargeData)
	local mx = math.max(1, chargeData.maxCharge or item.max_charge)
	return math.max(0, math.min(1, (chargeData.progress or 0) / mx))
end

--- Tecrorun：now_layer = floor(rate * layercnt)；rate*layercnt>=0.5 才显示/可射
local function layer_from_rate(rate)
	local layercnt = item.preview_bounces
	local f = rate * layercnt
	if f < 0.5 then return nil end
	return math.floor(f)
end

local function normalize_dir(dir)
	if not dir or dir:Length() < 1e-4 then return Vector(0, 1) end
	return dir:Normalized()
end

local function safe_input_dir(player)
	local dir = auxi.ggdir(player, true, false, false, nil, {
		real = true,
		ignore_firedirection = true,
	})
	if not dir or dir:Length() <= 0.1 then return nil end
	return dir:Normalized()
end

local function blend_aim(current, target, rate)
	if not target then return current end
	if not current or current:Length() < 0.1 then return target end
	local cur_ang = current:GetAngleDegrees()
	local tgt_ang = target:GetAngleDegrees()
	local delta = auxi.get_correct_angle(tgt_ang - cur_ang)
	return auxi.MakeVector(cur_ang + delta * rate)
end

--- 蓄力瞄准：斜向 lerp；纯单轴 snap；2→1 时 axis_grace 帧内保持原方向（防双键齐松不同步）
local function update_aim(chargeData, input)
	chargeData.storedDir = input
	local axes = axis_count(input)
	if axes >= 2 then
		chargeData.axis_grace = 0
		chargeData.displayDir = blend_aim(chargeData.displayDir, input, item.aim_lerp)
	elseif axes == 1 then
		if chargeData.prev_axes >= 2 then
			chargeData.axis_grace = item.axis_grace_frames
		end
		if (chargeData.axis_grace or 0) > 0 then
			chargeData.axis_grace = chargeData.axis_grace - 1
		else
			chargeData.displayDir = input:Normalized()
		end
	else
		chargeData.axis_grace = 0
		chargeData.displayDir = blend_aim(chargeData.displayDir, input, item.aim_lerp)
	end
	chargeData.prev_axes = axes
	return chargeData.displayDir
end

--- 完全松手：用最后一帧平滑后的 displayDir
local function aim_on_release(chargeData)
	return normalize_dir(chargeData.displayDir or chargeData.storedDir)
end

--- 旋转枢轴世界坐标（SpriteOffset 补偿后 pivot 固定，不随朝向再旋转 height_offset）
local function pivot_world_pos(ent)
	return ent.Position + item.height_offset + (ent.SpriteOffset or Vector.Zero)
end

local function foot_pos_from_pivot(pivot_pos, ent)
	return pivot_pos - item.height_offset - (ent.SpriteOffset or Vector.Zero)
end

local function set_face_dir(ent, dir)
	if not dir or dir:Length() < 0.1 then return end
	ent.SpriteRotation = 0
	local ang = dir:GetAngleDegrees() + 90
	local s = ent:GetSprite()
	s.Rotation = ang
	local pivot = item.height_offset
	ent.SpriteOffset = pivot - pivot:Rotated(ang)
end

local function clear_face(ent)
	ent.SpriteRotation = 0
	ent:GetSprite().Rotation = 0
	ent.SpriteOffset = Vector.Zero
end

local function get_laser(d)
	local tq = d[TK.."Linked_Laser"]
	if auxi.check_exists(tq) then return tq end
	return nil
end

local function set_laser_alpha(tq, alpha)
	if not tq then return end
	local ld = tq:GetData()[TK.."laser"]
	if not ld then return end
	ld.basecolor = ld.basecolor or auxi.color2table(tq:GetSprite().Color)
	ld.basecolor.A = math.max(0, math.min(1, alpha))
end

local function fade_out_laser(d)
	local tq = get_laser(d)
	if tq then
		local ld = tq:GetData()[TK.."laser"]
		if ld then
			ld.Remove = true
			ld.Removecounter = ld.Removecounter or 1
		end
	end
	d[TK.."Linked_Laser"] = nil
	d[item.own_key.."laser_fade"] = nil
end

--- 蓄力预瞄：激光 Position 在宝宝 pivot；Angle 随 displayDir 平滑；PO=0
local function ensure_preview_laser(ent, player, face_dir, now_layer)
	local d = ent:GetData()
	local dir = normalize_dir(face_dir)
	now_layer = math.max(0, math.floor(now_layer or 0))
	local origin = pivot_world_pos(ent)
	local tq = get_laser(d)
	if not tq then
		tq = Tecrorun.fire_tecro_laser(origin, player, dir)
		if not tq then return nil end
		d[TK.."Linked_Laser"] = tq
		d[item.own_key.."laser_fade"] = 0
		set_laser_alpha(tq, 0)
	end
	local ld = tq:GetData()[TK.."laser"]
	if not ld then return tq end
	ld.linker = ent
	ld.layer = now_layer
	ld.mxlayer = now_layer
	ld.reflection_count = now_layer
	ld.segment_level = 0
	ld.Remove = nil
	ld.RemoveNow = nil
	tq.Position = origin
	tq.PositionOffset = Vector.Zero
	-- Angle 也 lerp，避免单轴按键时光柱瞬间跳向
	local cur_ang = tq.Angle or dir:GetAngleDegrees()
	local tgt_ang = dir:GetAngleDegrees()
	local delta = auxi.get_correct_angle(tgt_ang - cur_ang)
	tq.Angle = cur_ang + delta * item.aim_lerp
	tq.DepthOffset = 5
	tq.CollisionDamage = 0
	local fade = d[item.own_key.."laser_fade"] or 0
	fade = math.min(1, fade + 1 / item.laser_fade_in_frames)
	d[item.own_key.."laser_fade"] = fade
	set_laser_alpha(tq, fade)
	return tq
end

--- 松手：锁定当前光路（不改 Angle/Position），再 load_impale
local function begin_impale(ent, player, charge_rate_val)
	local d = ent:GetData()
	local tq = get_laser(d)
	if not tq then return false end
	local ld = tq:GetData()[TK.."laser"]
	if not ld then return false end

	d[TK.."Record"] = d[TK.."Record"] or {}
	-- effect_scale 在 attack_impale 压 Scale.X（沿前进）；Scale.Y 为垂直于前进的宽度
	d[TK.."Record"].BaseScale = Vector(1, 1)

	d[item.own_key.."laser_fade"] = 1
	set_laser_alpha(tq, 1)
	ld.Remove = nil
	ld.RemoveNow = nil

	local locked_dir = auxi.MakeVector(tq.Angle)
	set_face_dir(ent, locked_dir)
	ent.Position = foot_pos_from_pivot(tq.Position, ent)
	Tecrorun.load_impale(ent)
	if not d[TK.."Impale"] then return false end
	d[TK.."Impale"].rnd = auxi.random_1() * 60
	d[TK.."Impale"].charge = charge_rate_val
	d[item.own_key.."launchData"] = {
		charge = charge_rate_val,
		dir = locked_dir,
	}
	return true
end

local function end_impale(ent, d)
	d[item.own_key.."launchData"] = nil
	d[TK.."Impale"] = nil
	ent.Velocity = Vector.Zero
	ent.CollisionDamage = 0
	clear_face(ent)
	ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_WALLS
	Baby_Anim.reset(ent, item.own_key.."float")
	ent:GetSprite():Play("Idle", true)
	fade_out_laser(d)
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_, player, cacheFlag)
	local cnt = player:GetCollectibleNum(item.entity) + player:GetEffects():GetCollectibleEffectNum(item.entity)
	if cacheFlag == CacheFlag.CACHE_FAMILIARS then
		player:CheckFamiliar(item.familiar, cnt, player:GetCollectibleRNG(item.entity), Isaac.GetItemConfig():GetCollectible(item.entity))
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_FAMILIAR_INIT, params = item.familiar,
Function = function(_, ent)
	clear_face(ent)
	ent:GetSprite():Play("Idle", true)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_FAMILIAR_RENDER, params = item.familiar,
Function = function(_, ent, offset)
	local d = ent:GetData()
	local cnt = (d[item.own_key.."charging"] or {}).progress or 0
	Charging_Bar_holder.render_me(ent, {
		name1 = item.own_key.."counter",
		name2 = item.own_key.."sprite",
		name3 = item.own_key,
		loadname = "gfx/effects/chargebar/chargebar_Baby_Tecro.anm2",
		check1 = function() return cnt > 5 end,
		check2 = function() return cnt >= item.max_charge end,
		check3 = function() return math.ceil(cnt / item.max_charge * 100) end,
		signal1 = function() end,
	})
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar,
Function = function(_, ent)
	local player = auxi.check_spawner_player(ent)
	if not player then return end
	local d = ent:GetData()
	local s = ent:GetSprite()

	if d[item.own_key.."launchData"] then
		if d[item.own_key.."IsFollow"] then
			ent:RemoveFromFollowers()
			d[item.own_key.."IsFollow"] = nil
		end
		ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
		ent.Velocity = Vector.Zero
		ent.CollisionDamage = 0
		if not d[TK.."Impale"] then
			end_impale(ent, d)
			return
		end
		local launch = d[item.own_key.."launchData"]
		local finished = false
		local last_dir = launch.dir
		for _ = 1, item.impale_steps_per_frame do
			local ret = Tecrorun.control_impale(player, ent, {
				main = false,
				terminal_burst = true,
				charge = launch.charge or 1,
				dmgmul = item.dmgmul,
				rangerate = item.rangerate,
				effect_scale = item.effect_scale,
			}) or {}
			if ret.dir and ret.dir:Length() > 0.001 then
				last_dir = ret.dir
			end
			if ret.pos then
				set_face_dir(ent, last_dir)
				ent.Position = foot_pos_from_pivot(ret.pos, ent)
			end
			if ret.End then
				finished = true
				break
			end
		end
		launch.dir = last_dir
		if not s:IsPlaying("Idle") then
			s:Play("Idle", true)
		end
		if finished then
			end_impale(ent, d)
		end
		return
	end

	ent.CollisionDamage = 0
	ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_WALLS
	if not d[item.own_key.."IsFollow"] then
		ent:AddToFollowers()
		d[item.own_key.."IsFollow"] = true
	end

	local chargeData = ensure_charge(d)
	local input = safe_input_dir(player)
	local isInput = input ~= nil
	local releasing = chargeData.lastInput and not isInput
	local rate = charge_rate(chargeData)
	local now_layer = layer_from_rate(rate)

	if isInput then
		if not chargeData.lastInput then
			chargeData.progress = 0
			chargeData.prev_axes = 0
			chargeData.axis_grace = 0
		end
		local aim = update_aim(chargeData, input)
		chargeData.progress = math.min(chargeData.progress + 1, chargeData.maxCharge)
		rate = charge_rate(chargeData)
		now_layer = layer_from_rate(rate)
		Baby_Anim.reset(ent, item.own_key.."float")
		if not s:IsPlaying("Idle") then s:Play("Idle", true) end
		set_face_dir(ent, aim)
		ent:FollowParent()
		if now_layer ~= nil then
			ensure_preview_laser(ent, player, aim, now_layer)
		elseif get_laser(d) then
			fade_out_laser(d)
		end
	elseif releasing then
		-- 完全松手处理在下方
	else
		if get_laser(d) then fade_out_laser(d) end
		clear_face(ent)
		Baby_Anim.tick_float_idle(ent, item.own_key.."float", {
			float_min = 18,
			float_max = 36,
			idle_min = 90,
			idle_max = 180,
		})
		if Baby_Anim.is_float_idle_anim(s:GetAnimation()) then
			ent:FollowParent()
		end
	end

	if releasing then
		local lock_aim = aim_on_release(chargeData)
		if now_layer ~= nil and get_laser(d) then
			set_face_dir(ent, lock_aim)
			ensure_preview_laser(ent, player, lock_aim, now_layer)
			Baby_Anim.reset(ent, item.own_key.."float")
			ent:RemoveFromFollowers()
			d[item.own_key.."IsFollow"] = nil
			ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
			s:Play("Idle", true)
			if begin_impale(ent, player, rate) then
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_SHELLGAME, 0.7, 1.1, false, 0, 2)
			else
				fade_out_laser(d)
				ent:AddToFollowers()
				d[item.own_key.."IsFollow"] = true
				ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_WALLS
			end
		else
			fade_out_laser(d)
		end
		chargeData.progress = 0
		chargeData.prev_axes = 0
		chargeData.axis_grace = 0
	end

	chargeData.lastInput = isInput
end,
})

return item
