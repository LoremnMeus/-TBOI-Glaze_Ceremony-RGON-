-- 宝宝安娜：蓄力喷射硫磺尾；旋转/瞄准对齐宝宝泰克罗；撞墙贴住参考大胖蛆探针
local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")
local Baby_Anim = require("Qing_Remaster_scripts.others.Baby_Anim_holder")

local item = {
	ToCall = {},
	pre_ToCall = {},
	post_ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	post_myToCall = {},
	entity = enums.Items.Baby_Anna,
	familiar = enums.Familiars.Baby_Anna,
	own_key = "Item_Baby_Anna_",
	max_charge = 60,
	min_charge = 30,
	speed = 20,
	max_speed = 40,
	acceleration = 0.5,
	aim_lerp = 0.22,
	axis_grace_frames = 3,
	height_offset = Vector(0, -15),
	windup_frames = 4,
	wall_stick_frames = 8,
	wall_stop_base = 12,
}

local function ensure_charge(d)
	if type(d[item.own_key.."charging"]) ~= "table" then
		d[item.own_key.."charging"] = {
			progress = 0,
			maxCharge = item.max_charge,
			minCharge = item.min_charge,
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

local function pivot_world_pos(ent)
	return ent.Position + item.height_offset + (ent.SpriteOffset or Vector.Zero)
end

local function set_laser_follow_parent(laser, follow)
	if not laser then return end
	if laser.SetDisableFollowParent then
		pcall(function() laser:SetDisableFollowParent(not follow) end)
	elseif laser.DisableFollowParent ~= nil then
		laser.DisableFollowParent = not follow
	end
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
	ent.Color = Color(1, 1, 1, 1, 0, 0, 0)
end

local function apply_full_charge_vfx(ent, chargeData)
	local s = ent:GetSprite()
	if chargeData.progress >= chargeData.maxCharge then
		local fc = Game():GetFrameCount()
		local pulse = (math.sin(fc * 0.38) + 1) * 0.5
		s.Color = Color(1, 0.12 + 0.08 * (1 - pulse), 0.12 + 0.08 * (1 - pulse), 1, 0.35 + 0.45 * pulse, 0, 0)
		local base_so = ent.SpriteOffset or Vector.Zero
		local shake = Vector(math.sin(fc * 0.85) * 1.4, math.sin(fc * 1.05) * 0.9)
		ent.SpriteOffset = base_so + shake
	else
		s.Color = Color(1, 1, 1, 1, 0, 0, 0)
	end
end

local function ensure_tail(ent, player, launchData)
	if auxi.check_all_exists(launchData.tail) then return end
	local info = auxi.judge_by_brimstone(player)
	local origin = pivot_world_pos(ent)
	local q = Isaac.Spawn(7, info.tp, 0, origin, Vector(0, 0), ent):ToLaser()
	delay_buffer.addeffe(function() SFXManager():Stop(7) end, {}, 1)
	q.CollisionDamage = info.dmg * 0.5
	q.Parent = ent
	set_laser_follow_parent(q, false)
	q.PositionOffset = Vector.Zero
	launchData.tail = q
end

local function sync_tail(ent, launchData)
	local tail = launchData.tail
	if not auxi.check_all_exists(tail) then return end
	tail.Angle = 180 + launchData.direction:GetAngleDegrees()
	tail.Position = pivot_world_pos(ent)
	tail.PositionOffset = Vector.Zero
end

local function end_launch(ent, d)
	local launchData = d[item.own_key.."launchData"]
	if launchData and auxi.check_if_any(launchData.tail) then
		launchData.tail:SetTimeout(1)
	end
	d[item.own_key.."launchData"] = nil
	ent.Velocity = Vector.Zero
	clear_face(ent)
	ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_WALLS
	Baby_Anim.reset(ent, item.own_key.."float")
	ent:GetSprite():Play("Idle", true)
end

local function tick_launch(ent, launchData)
	local room = Game():GetRoom()
	local dir = launchData.direction
	if not dir or dir:Length() < 1e-4 then return true end
	dir = dir:Normalized()
	launchData.direction = dir
	local phase = launchData.phase or "windup"

	if phase == "windup" then
		launchData.windup_left = (launchData.windup_left or item.windup_frames) - 1
		local t = 1 - math.max(0, launchData.windup_left) / item.windup_frames
		local spd = (launchData.speed or item.speed) * (0.15 + 0.85 * t * t)
		ent.Velocity = dir * spd
		if (launchData.windup_left or 0) <= 0 then
			launchData.phase = "dash"
		end
	elseif phase == "dash" then
		if (launchData.speed or 0) < item.max_speed then
			launchData.speed = (launchData.speed or 0) + (launchData.acceleration or item.acceleration)
		end
		ent.Velocity = dir * launchData.speed
		local margin = launchData.margin or 0
		local next_pos = ent.Position + ent.Velocity
		local clamped = room:GetClampedPosition(next_pos, margin)
		if (clamped - next_pos):Length() > 0.5 then
			launchData.phase = "wall_stick"
			launchData.stick_left = item.wall_stick_frames
			launchData.speed = launchData.speed * 0.5
			ent.Velocity = dir * 0.05
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MEAT_IMPACTS, 0.85, 1, false, 0, 2)
		end
	elseif phase == "wall_stick" then
		launchData.stick_left = (launchData.stick_left or 0) - 1
		ent.Velocity = dir * 0.05
		if (launchData.stick_left or 0) <= 0 then
			launchData.phase = "stop"
			ent.Velocity = Vector.Zero
			launchData.counter = 0
		end
	elseif phase == "stop" then
		ent.Velocity = Vector.Zero
		launchData.counter = (launchData.counter or 0) + 1
		if (launchData.counter or 0) > (launchData.mxcnt or item.wall_stop_base) then
			return true
		end
	end
	return false
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
		loadname = "gfx/effects/chargebar/chargebar_Anna.anm2",
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
		local launchData = d[item.own_key.."launchData"]
		set_face_dir(ent, launchData.direction)
		if not s:IsPlaying("Idle") then s:Play("Idle", true) end
		ensure_tail(ent, player, launchData)
		sync_tail(ent, launchData)
		if tick_launch(ent, launchData) then
			end_launch(ent, d)
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

	if isInput then
		if not chargeData.lastInput then
			chargeData.progress = 0
			chargeData.prev_axes = 0
			chargeData.axis_grace = 0
		end
		local aim = update_aim(chargeData, input)
		chargeData.progress = math.min(chargeData.progress + 1, chargeData.maxCharge)
		Baby_Anim.reset(ent, item.own_key.."float")
		if not s:IsPlaying("Idle") then s:Play("Idle", true) end
		set_face_dir(ent, aim)
		apply_full_charge_vfx(ent, chargeData)
		ent:FollowParent()
	elseif releasing then
		set_face_dir(ent, chargeData.displayDir or chargeData.storedDir)
	else
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
		if chargeData.progress >= chargeData.minCharge then
			local aim = normalize_dir(chargeData.displayDir or chargeData.storedDir)
			if aim:Length() > 0.1 then
				local rate = chargeData.progress / chargeData.maxCharge
				Baby_Anim.reset(ent, item.own_key.."float")
				ent:RemoveFromFollowers()
				d[item.own_key.."IsFollow"] = nil
				ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
				s:Play("Idle", true)
				set_face_dir(ent, aim)
				s.Color = Color(1, 1, 1, 1, 0, 0, 0)
				d[item.own_key.."launchData"] = {
					direction = aim,
					speed = item.speed * math.sqrt(rate),
					acceleration = item.acceleration,
					phase = "windup",
					windup_left = item.windup_frames,
					mxcnt = math.floor(item.wall_stop_base * (0.5 + 0.5 * rate)),
					margin = 0,
				}
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_SHELLGAME, 0.65, 1.05, false, 0, 2)
			end
		end
		chargeData.progress = 0
		chargeData.prev_axes = 0
		chargeData.axis_grace = 0
	end

	chargeData.lastInput = isInput
end,
})

return item
