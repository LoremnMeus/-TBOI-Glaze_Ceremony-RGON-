-- Air Flight combat helpers: profile runtime, knives, stamps, standby sync.
-- Structural extract from Item_Air_Flight.lua. No gameplay/UI semantic changes.
-- Main combat dispatcher remains in Item_Air_Flight until a later commit.
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")
local CraftDyn = require("Qing_Remaster_scripts.others.craft_dynamic_stats")
local CraftIdentity = require("Qing_Remaster_scripts.mimics.craft_identity")
local Craft_Familiar_holder = require("Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
local Craft_Orbital_holder = require("Qing_Remaster_scripts.mimics.Craft_Orbital_holder")
local Craft_Ludovico_holder = require("Qing_Remaster_scripts.mimics.Craft_Ludovico_holder")
local Bomb_holder = require("Qing_Remaster_scripts.mimics.Bomb_holder")

local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local enums = require("Qing_Remaster_scripts.core.enums")
local attack_holder = require("Qing_Remaster_scripts.callbacks.attack_trigger_holder")
local Laser_holder = require("Qing_Remaster_scripts.mimics.Laser_holder")
local Isaacs_Tear_holder = require("Qing_Remaster_scripts.mimics.Isaacs_Tear_holder")
local CraftTearColors = require("Qing_Remaster_scripts.others.craft_tear_color_data")
local CraftTearParams = require("Qing_Remaster_scripts.others.craft_tear_params_data")
local CraftOnHurt = require("Qing_Remaster_scripts.others.craft_on_hurt_router")
local player_Spwq = require("Qing_Remaster_scripts.player.player_Spwq")
local CharRound = require("Qing_Remaster_scripts.player.character_attack_round")

local M = {}

function M.attach(item, Air)

function item.get_craft_aux_fire_intent(ent)
	local out = {should_shoot = false, aim_direction = nil, aim_pos = nil, focus = nil, state = nil}
	if not ent then return out end
	local d = ent:GetData()
	out.state = ent.State
	out.focus = d[item.own_key.."FireControlMode"] or 0
	out.should_shoot = d[item.own_key.."AuxShouldShoot"] == true
	out.aim_direction = d[item.own_key.."AuxAimDirection"]
	out.aim_pos = d[item.own_key.."AuxAimPos"]
	return out
end

function item.is_standby(ent)
	if not ent then return false end
	return ent:GetData()[item.own_key.."Standby"] == true
end

function item.combat_allowed(ent)
	if not ent or not auxi.check_all_exists(ent) then return false end
	return ent:GetData()[item.own_key.."Standby"] ~= true
end

--- Incubus / Twisted Pair / Cain's Other Eye：请求复用飞行器完整武器分支。
--- 覆盖发射原点/方向/伤害倍率；不推进主冷却、眼睛相位、诅咒眼重放。
function item.queue_craft_aux_attack(ent, pos, dir, damage_mul, source, host, visual_scale)
	if not ent or not pos or not dir then return false end
	if dir:Length() < 0.01 then return false end
	local d = ent:GetData()
	local q = d[item.own_key.."AuxAttackQueue"]
	if type(q) ~= "table" then
		q = {}
		d[item.own_key.."AuxAttackQueue"] = q
	end
	q[#q + 1] = {
		pos = Vector(pos.X, pos.Y),
		dir = dir:Normalized(),
		damage_mul = tonumber(damage_mul) or 1,
		source = source,
		host = host,
		visual_scale = tonumber(visual_scale),
	}
	return true
end

-- 迷彩爆发衰减：约 90 帧线性落到 0（对照原版“迅速衰减”写死）
local CAMO_BURST_FRAMES = 90
local CAMO_DMG0 = 10.5
local CAMO_FR0 = 7.5
local JUPITER_STILL_SPEED = 0.35
local JUPITER_CHARGE_FRAMES = 90 -- 静止约 1.5s 攒满 +0.5
-- No. 2（378）：持续攻击 2.5s 掉落大便炸弹，随后较长冷却（离房重置）
local NO2_CHARGE_FRAMES = 75
local NO2_COOLDOWN_FRAMES = 180

local function camo_burst_bonuses(frames)
	frames = tonumber(frames) or 0
	if frames < 0 or frames >= CAMO_BURST_FRAMES then
		return 0, 0
	end
	local t = 1 - (frames / CAMO_BURST_FRAMES)
	return CAMO_DMG0 * t, CAMO_FR0 * t
end

local function tick_camo_undies(ent, counts, attacking)
	if (counts[497] or 0) <= 0 then return end
	local d = ent:GetData()
	local room_idx = Game():GetLevel():GetCurrentRoomIndex()
	if d[item.own_key.."camo_room"] ~= room_idx then
		d[item.own_key.."camo_room"] = room_idx
		d[item.own_key.."camo_stealthed"] = true
		d[item.own_key.."camo_burst"] = nil
		d[item.own_key.."camo_broke"] = nil
	end
	if d[item.own_key.."camo_stealthed"] then
		-- 非 Boss 混乱
		for _, npc in ipairs(Isaac.FindInRadius(ent.Position, 2000, EntityPartition.ENEMY)) do
			if npc and npc:IsVulnerableEnemy() and not npc:IsBoss()
				and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
			then
				npc:AddConfusion(EntityRef(ent), 2, false)
			end
		end
		if attacking and not d[item.own_key.."camo_broke"] then
			d[item.own_key.."camo_stealthed"] = nil
			d[item.own_key.."camo_broke"] = true
			d[item.own_key.."camo_burst"] = 0
			for _, npc in ipairs(Isaac.FindInRadius(ent.Position, 80, EntityPartition.ENEMY)) do
				if npc and npc:IsVulnerableEnemy() and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
					npc:TakeDamage(15, 0, EntityRef(ent), 0)
				end
			end
		end
	elseif d[item.own_key.."camo_burst"] ~= nil then
		local f = (tonumber(d[item.own_key.."camo_burst"]) or 0) + 1
		if f >= CAMO_BURST_FRAMES then
			d[item.own_key.."camo_burst"] = nil
		else
			d[item.own_key.."camo_burst"] = f
		end
	end
end

local function tick_jupiter(ent, counts)
	if (counts[594] or 0) <= 0 then
		ent:GetData()[item.own_key.."jupiter_charge"] = nil
		return
	end
	local d = ent:GetData()
	local spd = ent.Velocity and ent.Velocity:Length() or 0
	local charge = tonumber(d[item.own_key.."jupiter_charge"]) or 0
	if spd < JUPITER_STILL_SPEED then
		charge = math.min(1, charge + 1 / JUPITER_CHARGE_FRAMES)
		d[item.own_key.."jupiter_moving"] = nil
	else
		if charge > 0.15 and not d[item.own_key.."jupiter_moving"] then
			-- 开始明显移动：释放毒气（绿水迹）
			local player = auxi.check_spawner_player(ent)
			local cloud = Isaac.Spawn(
				EntityType.ENTITY_EFFECT, EffectVariant.PLAYER_CREEP_GREEN, 0,
				ent.Position, Vector(0, 0), player or ent
			)
			if cloud then
				cloud = cloud:ToEffect() or cloud
				if cloud.SetTimeout then cloud:SetTimeout(90) end
				if cloud.Scale ~= nil then cloud.Scale = 1.5 end
			end
			charge = 0
		end
		d[item.own_key.."jupiter_moving"] = true
	end
	d[item.own_key.."jupiter_charge"] = charge
end

local function build_runtime_for_profile(ent, player, counts, attacking, aim_dir)
	local d = ent:GetData()
	local runtime = {}
	counts = counts or {}
	-- 368 Epiphora
	if (counts[368] or 0) > 0 then
		local frames = tonumber(d[item.own_key.."epiphora_frames"]) or 0
		runtime.epiphora_fire_rate_mul = math.min(2, 1 + frames / 180)
	end
	-- 373 Dead Eye
	if (counts[373] or 0) > 0 then
		local ch = tonumber(d[item.own_key.."dead_eye_charge"]) or 0
		runtime.dead_eye_damage_mul = 1 + 0.25 * math.min(4, ch)
	end
	-- 眼药水 / 单眼：同步眼睛相位（优先 craft 记录）。
	if CraftProfile.needs_eye_phase(counts) then
		local bp = Air.get_blueprint()
		local uid = CraftIdentity.get_uid(ent)
		local rec = uid and bp.find_craft(player, uid)
		local phase = (rec and tonumber(rec.eye_phase)) or tonumber(d[item.own_key.."eye_phase"]) or 0
		d[item.own_key.."eye_phase"] = phase
		if (counts[600] or 0) > 0 then
			runtime.eye_drops_fire_rate_mul = (phase % 2 == 0) and 1.4 or 1
		end
	end
	-- 191
	if (counts[191] or 0) > 0 then
		local bp = Air.get_blueprint()
		local uid = CraftIdentity.get_uid(ent)
		local rec = uid and bp.find_craft(player, uid)
		runtime.dollar_flag = CraftDyn.tick_dollar_bill(ent, rec, counts, attacking)
	end
	-- 497 Camo
	if (counts[497] or 0) > 0 then
		runtime.camo_stealthed = d[item.own_key.."camo_stealthed"] == true
		if d[item.own_key.."camo_burst"] ~= nil then
			local dmg, fr = camo_burst_bonuses(d[item.own_key.."camo_burst"])
			runtime.camo_damage = dmg
			runtime.camo_fire_rate = fr
		end
	end
	-- 594 Jupiter
	if (counts[594] or 0) > 0 then
		local ch = tonumber(d[item.own_key.."jupiter_charge"]) or 0
		runtime.jupiter_speed = 0.5 * ch
	end
	-- 597 Neptunus：蓄积射速倍率由 craft_charge_weapons 维护
	if (counts[597] or 0) > 0 then
		local ok, Charge = pcall(require, "Qing_Remaster_scripts.others.craft_charge_weapons")
		if ok and Charge and Charge.get_neptune_fire_rate_mul then
			runtime.neptunus_fire_rate_mul = Charge.get_neptune_fire_rate_mul(ent)
		end
	end
	return runtime
end

local function tick_epiphora(ent, counts, attacking, aim_dir)
	if (counts[368] or 0) <= 0 then return end
	local d = ent:GetData()
	if not attacking or not aim_dir or aim_dir:Length() < 0.01 then
		d[item.own_key.."epiphora_frames"] = 0
		d[item.own_key.."epiphora_dir"] = nil
		return
	end
	local prev = d[item.own_key.."epiphora_dir"]
	local cur = aim_dir:Normalized()
	if prev and prev:Dot(cur) < 0.92 then
		d[item.own_key.."epiphora_frames"] = 0
	else
		d[item.own_key.."epiphora_frames"] = (tonumber(d[item.own_key.."epiphora_frames"]) or 0) + 1
	end
	d[item.own_key.."epiphora_dir"] = cur
end

--- No. 2：持续攻击满 2.5s 在飞行器脚下掉 Entity 4.9 大便炸弹，再进冷却；中断攻击清蓄力；离房清蓄力与冷却。
--- 掉落弹走 Bomb_holder.attach_craft_aux，吃配方里其它 BOMB_EFFECTS（毒/粘性/巨型等）；378 本身不进炸弹门控。
local function tick_number_two(ent, player, craft_prof, attacking)
	local counts = craft_prof and craft_prof.counts
	if not counts or (counts[378] or 0) <= 0 then return end
	local d = ent:GetData()
	local room_idx = Game():GetLevel():GetCurrentRoomIndex()
	if d[item.own_key.."no2_room"] ~= room_idx then
		d[item.own_key.."no2_room"] = room_idx
		d[item.own_key.."no2_charge"] = 0
		d[item.own_key.."no2_cd"] = 0
	end
	local cd = tonumber(d[item.own_key.."no2_cd"]) or 0
	if cd > 0 then
		d[item.own_key.."no2_cd"] = cd - 1
		d[item.own_key.."no2_charge"] = 0
		return
	end
	if not attacking then
		d[item.own_key.."no2_charge"] = 0
		return
	end
	local ch = (tonumber(d[item.own_key.."no2_charge"]) or 0) + 1
	if ch < NO2_CHARGE_FRAMES then
		d[item.own_key.."no2_charge"] = ch
		return
	end
	d[item.own_key.."no2_charge"] = 0
	d[item.own_key.."no2_cd"] = NO2_COOLDOWN_FRAMES
	if not player then return end
	local bomb = Isaac.Spawn(
		EntityType.ENTITY_BOMB, BombVariant.BOMB_BUTT, 0,
		ent.Position, Vector(0, 0), player
	)
	bomb = bomb and bomb:ToBomb()
	if not bomb then return end
	local dmg = (craft_prof.stats and craft_prof.stats.damage) or player.Damage
	if bomb.ExplosionDamage ~= nil then bomb.ExplosionDamage = dmg end
	Bomb_holder.attach_craft_aux(bomb, craft_prof, player, {})
end

local function bind_craft_profile(ent, player, attacking, aim_dir)
	local bp = Air.get_blueprint()
	local uid = CraftIdentity.get_uid(ent)
	if uid then
		local rec = bp.find_craft(player, uid)
		local counts = rec and CraftProfile.counts_from_ingredients(rec.ingredients) or {}
		local runtime = build_runtime_for_profile(ent, player, counts, attacking, aim_dir)
		local profile = bp.get_profile_for_uid(player, uid, {air = ent, runtime = runtime})
		CraftIdentity.set_profile(ent, profile)
		return profile
	end
	local new_uid, profile = bp.claim_air_flight_uid(player)
	if new_uid then
		CraftIdentity.set_uid(ent, new_uid)
		CraftIdentity.set_profile(ent, profile)
		return profile
	end
	return CraftIdentity.get_profile(ent)
end

-- 宝宝/环绕物只关心配方计数与 extras。profile 每帧会因 runtime 重建，不能用 table 身份判变。
local function craft_companion_signature(profile)
	if not profile then return "none" end
	local parts = {}
	for id, n in pairs(profile.counts or {}) do
		if tonumber(n) and tonumber(n) ~= 0 then
			parts[#parts + 1] = "c"..tostring(id).."="..tostring(n)
		end
	end
	for key, value in pairs(profile.extras or {}) do
		local tv = type(value)
		if (tv == "boolean" or tv == "number" or tv == "string")
			and value ~= false and value ~= 0 and value ~= "" then
			parts[#parts + 1] = "e"..tostring(key).."="..tostring(value)
		end
	end
	table.sort(parts)
	return table.concat(parts, ";")
end

-- 弹道高度：跟画面 PositionOffset，经 auxi.offset2height 转换。
-- FallingAcceleration>0 时 API 直接吃 Offset.Y 当 Height；≈0 时走 (Y+25)/0.4-25。
-- 泪弹只写 Height、激光等写 PositionOffset，二者不要叠加以免双重抬高。
local function air_combat_offset(ent)
	local vis = Air.AIR_AIM_VIS
	local y = vis.combat_offset_y
	if ent and ent.PositionOffset then
		y = ent.PositionOffset.Y
	end
	local lo = vis.combat_offset_min or -50
	local hi = vis.combat_offset_max or -28
	if y < lo then y = lo elseif y > hi then y = hi end
	return Vector(0, y)
end

local function air_tear_height(ent, falling_acc)
	return auxi.offset2height(air_combat_offset(ent), falling_acc)
end

local function air_copy_attack_offset(ent2, ent, prefer_height)
	if not ent2 or not ent then return end
	local off = air_combat_offset(ent)
	if prefer_height and ent2.Height ~= nil then
		ent2.Height = air_tear_height(ent, ent2.FallingAcceleration)
		-- 泪弹视觉由 Height 承担，清空 PositionOffset 防双重抬高
		if ent2.PositionOffset ~= nil then
			ent2.PositionOffset = Vector(0, 0)
		end
	elseif ent2.PositionOffset ~= nil then
		ent2.PositionOffset = Vector(off.X, off.Y)
	end
end

-- ---------- 命中率 EWMA（影响攻击中掠飞频率）----------
local HIT_RATE_ALPHA = 0.12
local HIT_RATE_DEFAULT = 0.55

local function air_hit_rate(d)
	local r = tonumber(d[item.own_key.."HitRate"])
	if r == nil then return HIT_RATE_DEFAULT end
	if r < 0 then return 0 end
	if r > 1 then return 1 end
	return r
end

local function air_note_shot(d)
	if not d then return end
	d[item.own_key.."ShotCount"] = (tonumber(d[item.own_key.."ShotCount"]) or 0) + 1
end

local function air_note_hit(d, hit)
	if not d then return end
	local cur = air_hit_rate(d)
	local sample = hit and 1 or 0
	d[item.own_key.."HitRate"] = cur * (1 - HIT_RATE_ALPHA) + sample * HIT_RATE_ALPHA
	if hit then
		d[item.own_key.."HitCount"] = (tonumber(d[item.own_key.."HitCount"]) or 0) + 1
	else
		d[item.own_key.."MissCount"] = (tonumber(d[item.own_key.."MissCount"]) or 0) + 1
	end
end

-- debug 9 / DebugFlag.HIGH_LUCK (1<<8): engine high luck; craft profile does not inherit it automatically.
local HIGH_LUCK_FLAG = (DebugFlag and DebugFlag.HIGH_LUCK) or (1 << 8)

function item.is_high_luck_debug()
	local game = Game()
	if not game or not game.GetDebugFlags then
		return false
	end
	return (game:GetDebugFlags() & HIGH_LUCK_FLAG) ~= 0
end

--- Effective Flight luck for rolls (Mom's Eye / Loki / Tech IX when capability-granted).
--- Priority: ImGui debug_force_luck (>0) → debug 9 HIGH_LUCK → craft profile luck → 0.
function item.get_effective_luck(ent, craft_prof)
	local force = tonumber(item.debug_force_luck)
	if force and force > 0 then
		return force, "force"
	end
	if item.is_high_luck_debug() then
		return 99, "debug9"
	end
	local prof = craft_prof
	if not prof and ent then
		prof = CraftIdentity.get_profile(ent)
	end
	local luck = (prof and prof.stats and tonumber(prof.stats.luck)) or 0
	return luck, "profile"
end

function item.get_hit_rate_summary(ent)
	local ok, result = pcall(function()
		if not ent then
			local fam = item.familiar
			if fam == nil then
				return "无飞行器（familiar 未注册）"
			end
			local list = Isaac.FindByType(EntityType.ENTITY_FAMILIAR, fam, -1, false, false)
			ent = list and list[1]
		end
		if not ent or not ent.GetData then
			-- 无实体时仍显示幸运调试信息（不依赖房间扫描结果）
			local use_luck, tag = item.get_effective_luck(nil, nil)
			local tag_s = (tag == "force" and " [强制]") or (tag == "debug9" and " [debug9]") or ""
			local p55 = CraftProfile.moms_eye_chance(use_luck)
			local p87 = CraftProfile.lokis_horns_chance(use_luck)
			return string.format(
				"无飞行器\n档案幸运=-- 生效幸运=%.1f%s\n妈眼→%.0f%%  洛基角→%.0f%%\n(0幸运：妈眼50%% / 洛基25%%)",
				use_luck, tag_s,
				p55 * 100, p87 * 100
			)
		end
		local d = ent:GetData()
		local hr = air_hit_rate(d)
		local shots = tonumber(d[item.own_key.."ShotCount"]) or 0
		local hits = tonumber(d[item.own_key.."HitCount"]) or 0
		local miss = tonumber(d[item.own_key.."MissCount"]) or 0
		local prof = CraftIdentity.get_profile(ent)
		local luck = (prof and prof.stats and tonumber(prof.stats.luck)) or 0
		local use_luck, tag = item.get_effective_luck(ent, prof)
		local tag_s = (tag == "force" and " [强制]") or (tag == "debug9" and " [debug9]") or ""
		local n55 = CraftProfile.count_of(prof and prof.counts, 55)
		local n87 = CraftProfile.count_of(prof and prof.counts, 87)
		local p55 = CraftProfile.moms_eye_chance(use_luck)
		local p87 = CraftProfile.lokis_horns_chance(use_luck)
		return string.format(
			"命中EWMA=%.0f%% shots=%d hit=%d miss=%d\n档案幸运=%.1f 生效幸运=%.1f%s\n妈眼x%d→%.0f%%  洛基角x%d→%.0f%%\n(0幸运：妈眼50%% / 洛基25%%，不是接近0)",
			hr * 100, shots, hits, miss,
			luck, use_luck, tag_s,
			n55, p55 * 100, n87, p87 * 100
		)
	end)
	if ok then return result end
	return "状态读取失败: " .. tostring(result)
end
--- 仅幸运行（无 FindByType）；ImGui 勾选时可安全刷新
function item.get_luck_debug_line()
	local use_luck, tag = item.get_effective_luck(nil, nil)
	local p55 = CraftProfile.moms_eye_chance(use_luck)
	local p87 = CraftProfile.lokis_horns_chance(use_luck)
	if tag == "force" then
		return string.format(
			"强制幸运=%.0f → 妈眼%.0f%% / 洛基%.0f%%（点「刷新命中/弹道」看配方份数）",
			use_luck, p55 * 100, p87 * 100
		)
	end
	if tag == "debug9" then
		return string.format(
			"debug 9 高幸运生效=%.0f → 妈眼%.0f%% / 洛基%.0f%%（ImGui 强制可再覆盖）",
			use_luck, p55 * 100, p87 * 100
		)
	end
	return string.format(
		"强制/debug9 关；档案幸运时 0→妈眼%.0f%%/洛基%.0f%%（点刷新看场上飞行器）",
		CraftProfile.moms_eye_chance(0) * 100,
		CraftProfile.lokis_horns_chance(0) * 100
	)
end


local function air_clear_owned_laser(d, key)
	local las = d[item.own_key..key]
	if auxi.check_all_exists(las) then
		local ld = las.GetData and las:GetData()
		if ld then
			ld.craft_clear_if_dead = nil
		end
		if las.Parent ~= nil then
			las.Parent = nil
		end
		if las.SetDisableFollowParent then
			las:SetDisableFollowParent(true)
		elseif las.DisableFollowParent ~= nil then
			las.DisableFollowParent = true
		end
		if las.SetTimeout then
			las:SetTimeout(1)
		end
		if las.Remove then
			las:Remove()
		end
	end
	d[item.own_key..key] = nil
end

local function air_remove_engine_knife(knife)
	if not knife then return end
	local parent = knife.Parent
	if knife.Exists and knife:Exists() then
		knife:Remove()
	end
	if parent and parent.Exists and parent:Exists() then
		parent:Remove()
	end
end

local function air_clear_engine_knives(ent)
	if not ent then return end
	local d = ent:GetData()
	local registered = d[item.own_key.."engine_knives"]
	if type(registered) == "table" then
		for _, knife in pairs(registered) do
			if knife and knife.Exists and knife:Exists() then
				air_remove_engine_knife(knife)
			end
		end
	end
	d[item.own_key.."engine_knives"] = {}
	d[item.own_key.."KnifePendingDelay"] = nil
	-- 100000 只是“主刀尚未收回”的运行时哨兵。刀被换房/待机/坠毁清理后，
	-- 必须同时解除哨兵，否则会从 100000 逐帧倒数，看起来就是主机永不出刀。
	if (tonumber(d[item.own_key.."FireDelay"]) or 0) >= 99999 then
		d[item.own_key.."FireDelay"] = -1
	end
	d[item.own_key.."KnifeHold"] = 0
	local air_hash = GetPtrHash(ent)
	-- 注册表是主路径；全局扫描只清理明确带 knife_flight 归属的漏网体。
	-- 禁止按“附近的 MeusNil 父体”删除，那会误杀其他模块/模组的刀。
	for _, kn in ipairs(Isaac.FindByType(EntityType.ENTITY_KNIFE, -1, -1, false, false)) do
		local k = kn.ToKnife and kn:ToKnife() or kn
		if k and k.Exists and k:Exists() then
			local kd = k.GetData and k:GetData()
			local flight = kd and kd.knife_flight
			local craft_air = flight and (flight.craft_air or flight.air)
			if craft_air and craft_air.Exists and craft_air:Exists()
				and GetPtrHash(craft_air) == air_hash then
				air_remove_engine_knife(k)
			end
		end
	end
end

local STANDBY_COLOR_KEY = "StandbyColorSaved"

local function air_seal_kidney_attack(d)
	if not d then return end
	CharRound.seal_persistent_attack(d[item.own_key.."kidney_attack"])
	d[item.own_key.."kidney_attack"] = nil
end

local function air_combat_stop_for_standby(ent, d)
	Air.clear_passway(d)
	d[item.own_key.."Flourish"] = nil
	d[item.own_key.."Target"] = nil
	d[item.own_key.."AuxAimDirection"] = nil
	d[item.own_key.."AuxAimPos"] = nil
	d[item.own_key.."AuxShouldShoot"] = false
	d[item.own_key.."PassAttacking"] = false
	d[item.own_key.."cursed_queue"] = nil
	d[item.own_key.."kidney_cooldown"] = nil
	d[item.own_key.."kidney_block_frames"] = nil
	d[item.own_key.."kidney_burst_remaining"] = nil
	d[item.own_key.."kidney_release"] = nil
	d[item.own_key.."kidney_active"] = nil
	air_seal_kidney_attack(d)
	d[item.own_key.."AuxAttackQueue"] = nil
	d[item.own_key.."anemic_active"] = nil
	d[item.own_key.."anemic_room"] = nil
	if Craft_Ludovico_holder and Craft_Ludovico_holder.release then
		Craft_Ludovico_holder.release(ent)
	end
	air_clear_owned_laser(d, "Tech2")
	air_clear_engine_knives(ent)
	local list = d[item.own_key.."Brimstones"]
	if type(list) == "table" then
		for _, entry in pairs(list) do
			local q = (type(entry) == "table" and entry.ent) or entry
			if auxi.check_all_exists(q) and q.SetTimeout then
				q:SetTimeout(1)
			end
		end
		d[item.own_key.."Brimstones"] = {}
	end
	pcall(function()
		local Charge = require("Qing_Remaster_scripts.others.craft_charge_weapons")
		if Charge and Charge.clear_flight then Charge.clear_flight(ent) end
	end)
	pcall(function()
		local Orbit = require("Qing_Remaster_scripts.others.craft_orbiting_tears")
		if Orbit and Orbit.clear_for_air then Orbit.clear_for_air(ent) end
	end)
	pcall(function()
		local Aux = require("Qing_Remaster_scripts.mimics.Craft_Aux_Entities_holder")
		if Aux and Aux.clear_for_air then Aux.clear_for_air(ent) end
	end)
	pcall(function()
		local Aura = require("Qing_Remaster_scripts.others.craft_aura_effects")
		if Aura and Aura.clear_flight then Aura.clear_flight(ent) end
	end)
	pcall(function()
		local EvilEye = require("Qing_Remaster_scripts.mimics.Craft_Evil_Eye_holder")
		if EvilEye and EvilEye.clear_for_air then EvilEye.clear_for_air(ent) end
	end)
end

local function air_apply_standby_dim(ent, d)
	if not d[item.own_key..STANDBY_COLOR_KEY] then
		d[item.own_key..STANDBY_COLOR_KEY] = auxi.color2table(ent:GetColor())
	end
	local saved = d[item.own_key..STANDBY_COLOR_KEY]
	local dim = auxi.table2color({
		R = 0.42, G = 0.44, B = 0.5, A = saved.A or 1,
		RO = saved.RO or 0, GO = saved.GO or 0, BO = saved.BO or 0,
		RC = 0.38, GC = 0.4, BC = 0.52, AC = 1,
	})
	ent:SetColor(dim, 2, 50, false, false)
end

local function air_restore_standby_color(ent, d)
	local saved = d[item.own_key..STANDBY_COLOR_KEY]
	if saved then
		ent:SetColor(auxi.table2color(saved), 1, 50, false, false)
		d[item.own_key..STANDBY_COLOR_KEY] = nil
	end
end

local function air_sync_companions(ent, d, craft_prof, player)
	local frame = Game():GetFrameCount()
	local sig = craft_companion_signature(craft_prof)
	local last_sig = d[item.own_key.."companion_sync_sig"]
	local next_check = tonumber(d[item.own_key.."companion_sync_next"]) or 0
	local urgent_until = tonumber(d[item.own_key.."companion_resync_until"]) or 0
	local interval = (frame < urgent_until) and 2 or 15
	if sig ~= last_sig or frame >= next_check then
		d[item.own_key.."companion_sync_sig"] = sig
		d[item.own_key.."companion_sync_next"] = frame + interval
		if craft_prof and Craft_Familiar_holder.profile_needs_sync(craft_prof) then
			Craft_Familiar_holder.sync_air_flight(ent, player, craft_prof)
		else
			Craft_Familiar_holder.release_for_air(ent)
		end
		if craft_prof then
			Craft_Orbital_holder.sync_air_flight(ent, player, craft_prof)
		else
			Craft_Orbital_holder.release_for_air(ent)
		end
		do
			local ok_w, WatchCraft = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Watcher_holder")
			if ok_w and WatchCraft then
				if craft_prof and WatchCraft.sync_air_flight then
					WatchCraft.sync_air_flight(ent, player, craft_prof)
				elseif WatchCraft.release_for_air then
					WatchCraft.release_for_air(ent)
				end
			end
		end
		do
			local Aux = require("Qing_Remaster_scripts.mimics.Craft_Aux_Entities_holder")
			if Aux and Aux.clear_for_air and not craft_prof then
				Aux.clear_for_air(ent)
			end
		end
	end
end

local function apply_craft_flags(ent, craft_prof, fire_flags, air)
	if not ent or not craft_prof then return end
	if fire_flags ~= nil and ent.TearFlags ~= nil then
		CraftProfile.write_entity_tear_flags(ent, fire_flags)
		CraftProfile.apply_laser_craft_motion(ent, fire_flags)
	else
		CraftProfile.apply_flag_mask(ent, craft_prof)
	end
	local laser = ent.ToLaser and ent:ToLaser()
	if laser and air then
		CraftProfile.bind_craft_laser(laser, air, fire_flags or laser.TearFlags)
	end
end

local function apply_body_scale(ent, craft_prof)
	if not ent or not craft_prof then return end
	local mul = tonumber(craft_prof.body_scale_mul) or 1
	local base = Vector(1, 1)
	ent.SpriteScale = base * mul
end

local function register_engine_knife(air, knife, blocks_main_cooldown)
	if not air or not knife then return end
	local kd = knife.GetData and knife:GetData()
	local flight = kd and kd.knife_flight
	if flight then
		flight.blocks_main_cooldown = blocks_main_cooldown == true
	end
	local ad = air:GetData()
	local list = ad[item.own_key.."engine_knives"]
	if type(list) ~= "table" then
		list = {}
		ad[item.own_key.."engine_knives"] = list
	end
	list[GetPtrHash(knife)] = knife
end

local function air_engine_knives_busy(air)
	if not air then return false end
	local ad = air:GetData()
	local list = ad[item.own_key.."engine_knives"]
	if type(list) == "table" then
		for hash, k in pairs(list) do
			if k and k.Exists and k:Exists() and not k:IsDead() then
				local kd = k.GetData and k:GetData()
				local flight = kd and kd.knife_flight
				if flight and flight.blocks_main_cooldown == true then
					return true
				end
			else
				list[hash] = nil
			end
		end
	end
	return false
end

function item.craft_knives_busy(air)
	return air_engine_knives_busy(air)
end

local function air_force_companion_sync(ent, player)
	if not ent then return end
	local d = ent:GetData()
	d[item.own_key.."companion_sync_next"] = 0
	d[item.own_key.."companion_sync_sig"] = nil
	d[item.own_key.."companion_resync_until"] = Game():GetFrameCount() + 90
	player = player or auxi.check_spawner_player(ent)
	local craft_prof = bind_craft_profile(ent, player, false, nil)
	air_sync_companions(ent, d, craft_prof, player)
end

local function air_knife_progress(knife)
	local dist, vel
	if knife and knife.GetKnifeDistance then
		local ok, v = pcall(function() return knife:GetKnifeDistance() end)
		if ok then dist = tonumber(v) end
	end
	if knife and knife.GetKnifeVelocity then
		local ok, v = pcall(function() return knife:GetKnifeVelocity() end)
		if ok then vel = tonumber(v) end
	end
	if dist == nil then
		local parent = knife and knife.Parent
		if parent and parent.Exists and parent:Exists() then
			dist = math.max(0, (knife.Position - parent.Position):Length() - 30)
		else
			dist = 0
		end
	end
	return dist, tonumber(vel) or 0
end

-- 0=正常巡航，1=完全刹停。出程减速、顶点停顿、回程再加速。
-- 进度用 GetKnifeDistance / GetKnifeVelocity（PathOffset 是常量，不能当伸出量）。
local function air_knife_move_hold(air)
	if not air then return 0 end
	local ad = air:GetData()
	local list = ad[item.own_key.."engine_knives"]
	if type(list) ~= "table" then return 0 end
	local best = 0
	for hash, k in pairs(list) do
		if not (k and k.Exists and k:Exists() and not k:IsDead()) then
			list[hash] = nil
		else
			local kd = k.GetData and k:GetData()
			local flight = kd and kd.knife_flight
			if not (flight and flight.blocks_main_cooldown == true) then
				goto continue_engine_knife_hold
			end
			local knife = k.ToKnife and k:ToKnife() or k
			if not knife then
				best = math.max(best, 0.45)
			else
				local dist, kvel = air_knife_progress(knife)
				local maxd = tonumber(knife.MaxDistance) or 0
				local peak = math.max(maxd * 1.08, 24)
				local falling = kvel < -2
				local rising = kvel > 2
				if flight then
					if dist > (flight.peak_dist or 0) then
						flight.peak_dist = dist
					end
					local prev = flight.last_dist
					flight.last_dist = dist
					if (not rising) and (not falling) and prev ~= nil then
						if dist + 1.5 < prev then
							falling = true
						elseif dist > prev + 1.5 then
							rising = true
						end
					end
					if dist >= peak * 0.82 or falling or (kvel <= 0 and dist > 12) then
						flight.reached_target = true
					end
					peak = math.max(peak, flight.peak_dist or 0, 24)
				end
				local u = dist / peak
				if u < 0 then u = 0 elseif u > 1 then u = 1 end
				local hold
				if rising then
					hold = 0.28 + 0.72 * (u * u * (3 - 2 * u))
					if flight and flight.reached_target then
						hold = 1
					end
				elseif falling then
					hold = 0.12 + 0.55 * u
				elseif dist > 10 then
					hold = 1
				else
					hold = 0.4
				end
				best = math.max(best, hold)
			end
		end
		::continue_engine_knife_hold::
	end
	return best
end

local function air_follow_tech2_laser(las, ent, dir)
	if not las or not ent then return end
	if auxi.check_for_the_same(las.Parent, ent) ~= true then
		las.Parent = ent
	end
	if las.SetDisableFollowParent then
		las:SetDisableFollowParent(false)
	elseif las.DisableFollowParent ~= nil then
		las.DisableFollowParent = false
	end
	if las.ParentOffset ~= nil then
		las.ParentOffset = Vector(0, 0)
	end
	if las.SpawnerEntity ~= nil then
		las.SpawnerEntity = ent
	end
	las.Angle = dir:GetAngleDegrees()
	las.Position = ent.Position
	las.PositionOffset = air_combat_offset(ent)
	if (tonumber(las.HomingType) or 0) ~= 0 then
		CraftProfile.shift_homing_laser_samples(las)
	end
end

local function shoot_engine_knife(air, qk, shot_dir, charge, range, blocks_main_cooldown)
	if not qk then return nil end
	register_engine_knife(air, qk, blocks_main_cooldown)
	local kd = qk.GetData and qk:GetData()
	local flight = kd and kd.knife_flight
	if flight then
		flight.aim_ang = shot_dir:GetAngleDegrees()
		flight.craft_air = air
	end
	qk:Shoot(charge, range)
	return qk
end

local function stamp_craft_source(ent2, air, opts)
	opts = opts or {}
	if not ent2 then return end
	local td = ent2:GetData()
	td[item.own_key.."craft_air"] = air
	td[item.own_key.."craft_uid"] = air and CraftIdentity.get_uid(air)
	if opts.attack_serial ~= nil then
		td[item.own_key.."attack_serial"] = opts.attack_serial
	end
end

--- 制造攻击来源 + 可选 Dead Eye/拟寄生物；Knife/Sword 等已手写最终伤害时传 skip_damage_reapply。
local function stamp_craft_attack(ent2, air, craft_prof, opts)
	opts = opts or {}
	if not ent2 then return end
	stamp_craft_source(ent2, air, opts)
	if air and ent2.Type == EntityType.ENTITY_TEAR then
		local td = ent2:GetData()
		if not td[item.own_key.."shot_noted"] then
			td[item.own_key.."shot_noted"] = true
			air_note_shot(air:GetData())
		end
	end
	if opts.skip_damage_reapply then return end
	if opts.dead_eye_mul and ent2.CollisionDamage then
		ent2.CollisionDamage = ent2.CollisionDamage * opts.dead_eye_mul
	end
	if opts.dead_eye_charge and ent2.SetDeadEyeIntensity then
		ent2:SetDeadEyeIntensity(opts.dead_eye_charge / 4)
	end
	if opts.parasitoid and ent2.AddTearFlags and TearFlags.TEAR_EGG then
		ent2:AddTearFlags(TearFlags.TEAR_EGG)
	elseif opts.parasitoid and ent2.ChangeVariant and TearVariant.EGG then
		ent2:ChangeVariant(TearVariant.EGG)
	end
end

local function on_volley_fired(ent, player, craft_prof, aim_dir)
	if not craft_prof or not craft_prof.counts then return end
	local d = ent:GetData()
	local counts = craft_prof.counts
	local luck = craft_prof.stats and craft_prof.stats.luck or 0
	-- 眼药水 / 单眼道具：每个基础 volley 推进左右眼相位。
	if CraftProfile.needs_eye_phase(counts) then
		local phase = (tonumber(d[item.own_key.."eye_phase"]) or 0) + 1
		d[item.own_key.."eye_phase"] = phase
		local bp = Air.get_blueprint()
		local uid = CraftIdentity.get_uid(ent)
		local rec = uid and bp.find_craft(player, uid)
		if rec then rec.eye_phase = phase end
	end
	-- 217 Mom's Wig：射击时若场上蓝蜘蛛 <上限，以 1/max(1, 20-⌊luck×2⌋) 生成 1 只（每 volley 一次）
	-- 248 Hive Mind：上限 5→10；特效文案见 CraftProfile「妈假发+」
	if (counts[217] or 0) > 0 then
		local spider_cap = ((counts[248] or 0) > 0) and 10 or 5
		local spiders = Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FamiliarVariant.BLUE_SPIDER, -1, false, false)
		if #spiders < spider_cap then
			local den = math.max(1, 20 - math.floor((tonumber(luck) or 0) * 2))
			local rng = player:GetCollectibleRNG(217)
			if rng:RandomFloat() < (1 / den) then
				player:AddBlueSpider(ent.Position)
			end
		end
	end
	-- 573 / 410：环绕泪与邪眼（批次 3）
	do
		local Orbit = require("Qing_Remaster_scripts.others.craft_orbiting_tears")
		if Orbit and Orbit.on_volley_fired then
			Orbit.on_volley_fired(ent, player, craft_prof, aim_dir)
		end
	end
	-- 502 Large Zit：每基础 volley 固定概率额外痘泪（受伤方向痘泪仍走 craft_on_hurt_router）
	do
		local Aura = require("Qing_Remaster_scripts.others.craft_aura_effects")
		if Aura and Aura.on_volley_fired then
			Aura.on_volley_fired(ent, player, craft_prof, aim_dir)
		end
	end
end




Air.hit_rate = air_hit_rate
Air.note_shot = air_note_shot
Air.note_hit = air_note_hit
Air.combat_offset = air_combat_offset
Air.tear_height = air_tear_height
Air.copy_attack_offset = air_copy_attack_offset
Air.clear_owned_laser = air_clear_owned_laser
Air.clear_engine_knives = air_clear_engine_knives
Air.remove_engine_knife = air_remove_engine_knife
Air.seal_kidney_attack = air_seal_kidney_attack
Air.combat_stop_for_standby = air_combat_stop_for_standby
Air.apply_standby_dim = air_apply_standby_dim
Air.restore_standby_color = air_restore_standby_color
Air.sync_companions = air_sync_companions
Air.force_companion_sync = air_force_companion_sync
Air.bind_craft_profile = bind_craft_profile
Air.apply_body_scale = apply_body_scale
Air.apply_craft_flags = apply_craft_flags
Air.register_engine_knife = register_engine_knife
Air.engine_knives_busy = air_engine_knives_busy
Air.knife_progress = air_knife_progress
Air.knife_move_hold = air_knife_move_hold
Air.follow_tech2_laser = air_follow_tech2_laser
Air.shoot_engine_knife = shoot_engine_knife
Air.stamp_craft_source = stamp_craft_source
Air.stamp_craft_attack = stamp_craft_attack
Air.on_volley_fired = on_volley_fired
Air.tick_jupiter = tick_jupiter
Air.tick_epiphora = tick_epiphora
Air.tick_number_two = tick_number_two
Air.tick_camo_undies = tick_camo_undies


local WEAPON_TYPE_FOR = {
	[1] = WeaponType.WEAPON_TEARS,
	[2] = WeaponType.WEAPON_BRIMSTONE,
	[3] = WeaponType.WEAPON_LASER,
	[4] = WeaponType.WEAPON_KNIFE,
	[5] = WeaponType.WEAPON_BOMBS,
	[6] = WeaponType.WEAPON_ROCKETS,
	[7] = WeaponType.WEAPON_MONSTROS_LUNGS,
	[8] = WeaponType.WEAPON_LUDOVICO_TECHNIQUE,
	[9] = WeaponType.WEAPON_TECH_X,
	[10] = WeaponType.WEAPON_BONE,
	[11] = WeaponType.WEAPON_NOTCHED_AXE,
	[12] = WeaponType.WEAPON_URN_OF_SOULS,
	[13] = WeaponType.WEAPON_SPIRIT_SWORD,
	[14] = WeaponType.WEAPON_TEARS, -- fetus / C Section
}

-- Attack Trigger family for craft fire rounds (M5).
local CRAFT_ATTACK_FAMILY = {
	[1] = "tear",
	[2] = "brimstone",
	[3] = "technology",
	[4] = "knife",
	[5] = "bomb",
	[6] = "epic",
	[7] = "tear",
	[8] = "tear", -- Ludo synthetic; job usually skips Fire*
	[9] = "techx",
	[10] = "sword",
	[13] = "sword",
	[14] = "tear",
}

--- Main combat dispatcher (former MC_FAMILIAR_UPDATE combat section).
--- Order and state keys frozen; structural move only.
function Air.update_combat(ent, opts)
	opts = opts or {}
	local s = opts.s
	local d = opts.d
	local player = opts.player
	local craft_prof = opts.craft_prof
	local form = opts.form
	local state_succ = opts.state_succ
	local fire_anchor = opts.fire_anchor
	local mark_pos = opts.mark_pos
	local room = opts.room
	local tgpos = d[item.own_key.."TgPos"] or mark_pos
	local tgpos2 = tgpos
	local dis = ent.Position - tgpos
	local dis2 = ent.Position - tgpos2
	-- 须先声明：drain_pencil/greed、stamp_fetus 等闭包在赋值前定义，否则会当全局 dir2
	local dir, dir2, fire_pos
	local aim_for_dyn = dis2:Length() > 0.01 and (-dis2):Normalized() or nil
	local dyn_counts = craft_prof and craft_prof.counts or {}
	local kidney_requested_attack = state_succ
	if (dyn_counts[440] or 0) > 0 and kidney_requested_attack then
		if d[item.own_key.."kidney_burst_remaining"] and d[item.own_key.."kidney_burst_remaining"] > 0 then
			d[item.own_key.."kidney_active"] = true
			state_succ = false
		elseif (tonumber(d[item.own_key.."kidney_block_frames"]) or 0) > 0 then
			d[item.own_key.."kidney_active"] = true
			d[item.own_key.."kidney_block_frames"] = d[item.own_key.."kidney_block_frames"] - 1
			-- 蓄积阶段用短周期颜色覆盖形成红色闪烁；持续时间很短，不会污染结束后的常态颜色。
			if math.floor(d[item.own_key.."kidney_block_frames"] / 4) % 2 == 0 then
				ent:SetColor(Color(1, 0.3, 0.3, 1, 0.45, 0, 0), 2, 10, false, false)
			end
			state_succ = false
			if d[item.own_key.."kidney_block_frames"] <= 0 then
				d[item.own_key.."kidney_release"] = true
			end
		else
			d[item.own_key.."kidney_cooldown"] = tonumber(d[item.own_key.."kidney_cooldown"])
				or (180 + ((ent.InitSeed or 1) % 181))
			d[item.own_key.."kidney_cooldown"] = d[item.own_key.."kidney_cooldown"] - 1
			if d[item.own_key.."kidney_cooldown"] <= 0 then
				d[item.own_key.."kidney_block_frames"] = 60
				d[item.own_key.."kidney_active"] = true
				state_succ = false
			end
		end
	elseif (dyn_counts[440] or 0) <= 0 then
		d[item.own_key.."kidney_cooldown"] = nil
		d[item.own_key.."kidney_block_frames"] = nil
		d[item.own_key.."kidney_burst_remaining"] = nil
		d[item.own_key.."kidney_release"] = nil
		d[item.own_key.."kidney_active"] = nil
		Air.seal_kidney_attack(d)
	end
	Air.tick_epiphora(ent, dyn_counts, state_succ, aim_for_dyn)
	Air.tick_camo_undies(ent, dyn_counts, state_succ)
	Air.tick_jupiter(ent, dyn_counts)
	craft_prof = Air.bind_craft_profile(ent, player, state_succ, aim_for_dyn) or craft_prof
	-- Cursed Mask: keep rotating even while not firing this frame.
	if craft_prof and enums.Items.Cursed_Mask
		and CraftProfile.count_of(craft_prof.counts, enums.Items.Cursed_Mask) > 0 then
		local ok_m, Mask = pcall(require, "Qing_Remaster_scripts.items.Item_Cursed_Mask")
		if ok_m and Mask and Mask.tick_craft_aim then
			Mask.tick_craft_aim(ent, player)
		end
	end
	-- Tech XIV: walk-place into owner player's shared pointer network (not while standby).
	if craft_prof and enums.Items.Tech_14
		and CraftProfile.count_of(craft_prof.counts, enums.Items.Tech_14) > 0 then
		local ok_t, Tech14 = pcall(require, "Qing_Remaster_scripts.items.Item_Tech_14")
		if ok_t and Tech14 and Tech14.try_place_pointer then
			Tech14.try_place_pointer(player, ent)
		end
	end
	Air.tick_number_two(ent, player, craft_prof, state_succ)
	-- 批次 1 光环：用肾结石改写前的统一攻击意图（含压制/猎杀开火态）
	do
		local Aura = require("Qing_Remaster_scripts.others.craft_aura_effects")
		if Aura and Aura.tick_flight then
			Aura.tick_flight(ent, player, craft_prof, kidney_requested_attack == true)
		end
	end
	do
		local Aux = require("Qing_Remaster_scripts.mimics.Craft_Aux_Entities_holder")
		if Aux and Aux.tick_flight then
			Aux.tick_flight(ent, player, craft_prof)
		end
	end
	do
		local Charge = require("Qing_Remaster_scripts.others.craft_charge_weapons")
		if Charge and Charge.tick_flight then
			Charge.tick_flight(ent, player, craft_prof, kidney_requested_attack == true, aim_for_dyn)
		end
	end
	Air.apply_body_scale(ent, craft_prof)
	local function coll_n(id)
		if craft_prof then return CraftProfile.count_of(craft_prof.counts, id) end
		return player:GetCollectibleNum(id)
	end
	local function has_coll(id)
		if craft_prof then return coll_n(id) > 0 end
		return auxi.has_have_coll(player, id)
	end
	local atk_damage = craft_prof and craft_prof.stats.damage or player.Damage
	local atk_delay = craft_prof and craft_prof.stats.firedelay or player.MaxFireDelay
	local atk_shotspeed = craft_prof and craft_prof.stats.shotspeed or player.ShotSpeed
	local atk_range = craft_prof and craft_prof.stats.range or player.TearRange
	local atk_luck = craft_prof and craft_prof.stats.luck or player.Luck
	do
		local eff = item.get_effective_luck(ent, craft_prof)
		atk_luck = eff
	end
	-- 单眼：本次发射使用当前眼睛相位（0 / 1）。Lead Pencil 仅右眼。
	local eye_side = (tonumber(d[item.own_key.."eye_phase"]) or 0) % 2
	if craft_prof and (craft_prof.counts[444] or 0) > 0 then
		eye_side = 1
	end
	local one_eye = craft_prof and CraftProfile.one_eye_bonus(craft_prof.counts, eye_side)
		or {damage = 0, range = 0, shotspeed = 0, damage_mul = 1, blood_variant = false}
	atk_damage = (atk_damage + (one_eye.damage or 0)) * (one_eye.damage_mul or 1)
	atk_shotspeed = atk_shotspeed + (one_eye.shotspeed or 0)
	atk_range = atk_range + (one_eye.range or 0)
	local tear_stat_opts = {
		damage_add = one_eye.damage or 0,
		damage_mul = one_eye.damage_mul or 1,
	}
	-- 制造档案完全脱钩玩家 TearFlags；非制造仍用玩家缓存。
	local atk_flags = craft_prof and BitSet128(0, 0) or player.TearFlags
	local fire_flags = atk_flags
	local craft_shot_serial = tonumber(d[item.own_key.."shot_serial"]) or 0
	local craft_uid = craft_prof and CraftIdentity.get_uid(ent)

	local function craft_fire_opts(reason, overrides)
		local opts = attack_holder.CopyFireContext(reason, overrides)
		if opts then
			return opts
		end
		attack_holder.warn_missing_parent_once(
			reason,
			"Craft main fire job missing Attack context: " .. tostring(reason)
		)
		local orphan = {
			mode = "untracked",
			reason = tostring(reason) .. "_orphan",
		}
		if type(overrides) == "table" then
			for k, v in pairs(overrides) do
				orphan[k] = v
			end
		end
		return orphan
	end
	local craft_proj_index = 0
	local dead_eye_charge = tonumber(d[item.own_key.."dead_eye_charge"]) or 0
	local dead_eye_mul = (has_coll(373) and (1 + 0.25 * math.min(4, dead_eye_charge))) or 1
	-- §15.3 巧克力：制造档案统一倍率；无档案时保持旧硬编码路径。
	local atk_mods = craft_prof and CraftProfile.attack_modifiers_from_profile(craft_prof)
		or {
			chocolate = false, techx = false, ratio = 1,
			damage_mul = 1, size_mul = 1, delay_add_frac = 0,
			techx_radius_mul = 1, techx_damage_mul = 1,
		}
	local aux_mul = 1
	local is_replay = false
	local is_aux = false
	local fire_damage = atk_damage * (atk_mods.damage_mul or 1) * dead_eye_mul
	local proj_scale = craft_prof and CraftProfile.projectile_scale(craft_prof, atk_mods) or 1
	local syn = craft_prof and craft_prof.synergy
	local multi_n = (craft_prof and craft_prof.multishot and craft_prof.multishot.count) or 1
	local weap = craft_prof and craft_prof.weapon or auxi.get_weapon(player)
	local function craft_volley_dirs(base)
		if not craft_prof then return {base} end
		local seed = (ent.InitSeed or 0) + craft_shot_serial * 17 + (tonumber(craft_uid) or 0)
			+ (is_aux and 55087 or 0)
		local dirs = CraftProfile.build_volley_directions(craft_prof, base, {
			count = multi_n,
			-- 诅咒眼重放不重掷；附属完整攻击各自独立掷。
			roll_bookworm = not is_replay,
			luck = atk_luck,
			seed = seed,
		})
		return dirs
	end
	local function brim_list_get()
		local list = d[item.own_key.."Brimstones"]
		if type(list) ~= "table" then
			list = {}
			d[item.own_key.."Brimstones"] = list
			-- 兼容旧单字段
			local old = d[item.own_key.."Brimstone"]
			if auxi.check_all_exists(old) then
				list[#list + 1] = {laser = old, angle_offset = 0}
				d[item.own_key.."Brimstone"] = nil
			end
		end
		return list
	end
	local function brim_list_any_alive()
		local list = brim_list_get()
		for i = #list, 1, -1 do
			if auxi.check_all_exists(list[i].laser) then return true end
			table.remove(list, i)
		end
		return false
	end
	local BRIM_AIM_HISTORY_MAX = 12
	local function brim_aim_history_push(vec)
		if not vec or vec:Length() < 0.01 then return end
		local h = d[item.own_key.."BrimAimHistory"]
		if type(h) ~= "table" then
			h = {}
			d[item.own_key.."BrimAimHistory"] = h
		end
		table.insert(h, 1, Vector(vec.X, vec.Y))
		while #h > BRIM_AIM_HISTORY_MAX do
			table.remove(h)
		end
	end
	local function brim_aim_history_get(lag, fallback)
		local fb = fallback
		if (not fb or fb:Length() < 0.01) and dir and dir:Length() > 0.01 then
			fb = dir
		end
		if not fb or fb:Length() < 0.01 then
			fb = Vector(1, 0)
		end
		local h = d[item.own_key.."BrimAimHistory"]
		if type(h) ~= "table" or #h == 0 then
			return fb
		end
		lag = math.max(0, math.floor(tonumber(lag) or 0))
		local idx = math.min(#h, lag + 1)
		return h[idx] or fb
	end
	local function brim_list_add(laser, aim_dir, shot_dir, replay_lag)
		if not laser then return end
		local list = brim_list_get()
		local base_ang = aim_dir:GetAngleDegrees()
		local off = shot_dir:GetAngleDegrees() - base_ang
		list[#list + 1] = {
			laser = laser,
			angle_offset = off,
			replay_lag = math.max(0, math.floor(tonumber(replay_lag) or 0)),
		}
	end
	local function brim_list_set_timeout(t)
		local list = brim_list_get()
		for _, rec in ipairs(list) do
			if auxi.check_all_exists(rec.laser) and rec.laser.SetTimeout then
				rec.laser:SetTimeout(t)
			end
		end
	end
	local function brim_list_clear_dead_or_all(force_all)
		local list = brim_list_get()
		for i = #list, 1, -1 do
			local las = list[i].laser
			if force_all or not auxi.check_all_exists(las) then
				if force_all and auxi.check_all_exists(las) and las.SetTimeout then
					las:SetTimeout(1)
				end
				table.remove(list, i)
			end
		end
	end
	local function roll_craft_flags(ent2)
		craft_proj_index = craft_proj_index + 1
		return CraftProfile.sample_tear_flags(
			player, atk_luck, craft_prof,
			WEAPON_TYPE_FOR[weap] or WeaponType.WEAPON_TEARS,
			{
				shot_serial = craft_shot_serial,
				craft_uid = craft_uid,
				projectile_index = craft_proj_index,
				init_seed = ent2 and ent2.InitSeed,
			}
		)
	end
	local stamped_for_counters = 0
	local note_craft_shots
	local function stamp(ent2, dmg_mul, opts)
		opts = opts or {}
		local mul = (dmg_mul or 1) * (atk_mods.damage_mul or 1) * (aux_mul or 1)
		if craft_prof then
			-- 每颗弹丸独立幸运判定（内眼多发不得整组共用）。
			local flags = opts.inherit_flags or roll_craft_flags(ent2)
			fire_flags = flags
			atk_flags = flags
			local tear_ent = ent2.ToTear and ent2:ToTear() or nil
			local can_variant = tear_ent
				and not (TearVariant.FETUS and tear_ent.Variant == TearVariant.FETUS)
			local apple = false
			local tooth = false
			local force_blood = (one_eye.blood_variant == true) or (opts.force_blood_variant == true)
			-- Apple! 优先于 Tough Love（互斥，避免伤倍相乘）。
			if can_variant and has_coll(443) and not opts.skip_apple then
				local chance = CraftProfile.apple_chance(atk_luck)
				local rng = CraftProfile.derived_rng(
					(ent2 and ent2.InitSeed or 0) + craft_shot_serial * 17 + (tonumber(craft_uid) or 0) * 131,
					443 * 65537 + craft_proj_index
				)
				apple = rng:RandomFloat() < chance
				if apple then mul = mul * 4 end
			end
			if can_variant and not apple and has_coll(150) and not opts.skip_tough_love then
				local chance = CraftProfile.tough_love_chance(atk_luck)
				local rng = CraftProfile.derived_rng(
					(ent2 and ent2.InitSeed or 0) + craft_shot_serial * 17 + (tonumber(craft_uid) or 0) * 131,
					150 * 65537 + craft_proj_index
				)
				tooth = rng:RandomFloat() < chance
				if tooth then mul = mul * 3.2 end
			end
			-- Lead Pencil：50% 血泪外观（仅泪弹）；攻击计数见 note_craft_shots。
			if can_variant and has_coll(444) and not opts.skip_lead_pencil then
				local rng = CraftProfile.derived_rng(
					(ent2 and ent2.InitSeed or 0) + craft_shot_serial * 17 + (tonumber(craft_uid) or 0) * 131,
					444 * 65537 + craft_proj_index
				)
				if rng:RandomFloat() < 0.5 then force_blood = true end
			end
			CraftProfile.apply_tear_stats(ent2, craft_prof, mul, flags, tear_stat_opts)
			do
				local laser = ent2.ToLaser and ent2:ToLaser()
				if laser then
					CraftProfile.bind_craft_laser(laser, ent, flags)
				end
			end
			CraftTearColors.apply(ent2, craft_prof.counts, flags, CraftProfile.TEAR_EFFECTS)
			if not opts.skip_scale then
				CraftProfile.apply_projectile_scale(ent2, proj_scale)
			end
			local para = false
			if has_coll(461) and not opts.skip_parasitoid then
				local chance = CraftProfile.parasitoid_chance(atk_luck)
				local rng = CraftProfile.derived_rng(
					(ent2 and ent2.InitSeed or 0) + craft_shot_serial * 17 + (tonumber(craft_uid) or 0) * 131,
					461 * 65537 + craft_proj_index
				)
				para = rng:RandomFloat() < chance
			end
			Air.stamp_craft_attack(ent2, ent, craft_prof, {
				dead_eye_mul = dead_eye_mul,
				dead_eye_charge = has_coll(373) and dead_eye_charge or nil,
				parasitoid = para,
			})
			CraftTearParams.apply(ent2, craft_prof.counts, flags, CraftProfile.TEAR_EFFECTS, {
				parasitoid = para,
				tough_love = tooth,
				apple = apple,
				force_blood_variant = force_blood,
				eye_of_greed = opts.eye_of_greed == true,
				haemo_burst_mode = opts.haemo_burst_mode or CraftProfile.haemo_burst_mode(craft_prof),
				force_variant = opts.force_variant,
				range = atk_range,
				shotspeed = atk_shotspeed,
				set_base_height = function(accel)
					return Air.tear_height(ent, accel)
				end,
			})
			if ent2.Type == EntityType.ENTITY_TEAR
				and enums.Items.Wavering_Eyes
				and has_coll(enums.Items.Wavering_Eyes) then
				local ok_w, Wav = pcall(require, "Qing_Remaster_scripts.items.Item_Wavering_Eyes")
				if ok_w and Wav and Wav.on_craft_tear_fire then
					Wav.on_craft_tear_fire(ent2, ent, player, craft_prof)
				end
			end
			if para then
				ent2:GetData()[item.own_key.."parasitoid"] = true
			end
			if opts.eye_of_greed then
				local tf = ent2.TearFlags or BitSet128(0, 0)
				if TearFlags.TEAR_MIDAS then tf = tf | TearFlags.TEAR_MIDAS end
				if opts.greed_paid and TearFlags.TEAR_COIN_DROP then
					tf = tf | TearFlags.TEAR_COIN_DROP
				end
				ent2.TearFlags = tf
				if ent2.SetColor then
					ent2:SetColor(Color(1, 0.69, 0, 1, 1, 0.69, 0), -1, 1, false, false)
				end
			end
			if not opts.skip_shot_counters then
				note_craft_shots(1)
			end
			-- 血泪主泪：stamp 后再清 BURSTSPLIT，防止 FireTear 继承玩家 flag 落地喷泪
			if CraftProfile.profile_has_haemolacria(craft_prof) and ent2.ToTear and ent2:ToTear() then
				CraftProfile.clear_craft_haemo_burst_flag(ent2)
			end
			-- 小小星球 ORBIT / 我的镜像 BOOMERANG：按 flag 自管绕 Flight（杏仁奶等随机 flag 同样生效）
			do
				local q = ent2.ToTear and ent2:ToTear()
				if q then
					local Orbit = require("Qing_Remaster_scripts.others.craft_orbiting_tears")
					if Orbit and Orbit.adopt_path_tear then
						Orbit.adopt_path_tear(q, ent, flags, {
							aim = dir2,
							range = atk_range,
							shotspeed = atk_shotspeed,
						})
					end
				end
			end
		end
	end
	--- 铅笔 / 贪婪眼等：任意武器 stamp（或无 stamp 的 volley 兜底）都推进计数。
	note_craft_shots = function(n)
		n = tonumber(n) or 1
		if n <= 0 or not craft_prof then return end
		if not (has_coll(444) or has_coll(450)) then return end
		stamped_for_counters = stamped_for_counters + n
		if has_coll(444) then
			local cnt = (tonumber(d[item.own_key.."pencil_count"]) or 0) + n
			while cnt >= 15 do
				cnt = cnt - 15
				d[item.own_key.."pencil_burst"] = (tonumber(d[item.own_key.."pencil_burst"]) or 0) + 1
			end
			d[item.own_key.."pencil_count"] = cnt
		end
		if has_coll(450) then
			local cnt = (tonumber(d[item.own_key.."greed_count"]) or 0) + n
			while cnt >= 20 do
				cnt = cnt - 20
				d[item.own_key.."greed_burst"] = (tonumber(d[item.own_key.."greed_burst"]) or 0) + 1
			end
			d[item.own_key.."greed_count"] = cnt
		end
	end
	--- Lead Pencil：排空待发的萌死戳式血泪爆发（每触发 1 次喷 12 发，100% 伤）。
	local function drain_pencil_bursts()
		if not craft_prof or not has_coll(444) then return end
		local bursts = tonumber(d[item.own_key.."pencil_burst"]) or 0
		if bursts <= 0 then return end
		d[item.own_key.."pencil_burst"] = 0
		local base = dir2:Length() > 0.01 and dir2 or (Vector(10, 0) * atk_shotspeed)
		for _ = 1, bursts do
			for _i = 1, 12 do
				local vel = auxi.get_by_rotate(
					base,
					auxi.random_2() * 12,
					base:Length() * (1 + auxi.random_2() * 0.3)
				)
				local q = attack_holder.FireTear(player, fire_pos, vel, {
					mode = "untracked",
					reason = "craft_lead_pencil_burst",
					no_tracer = true,
				})
				if q then
					q = q:ToTear() or q
					q.Height = Air.tear_height(ent, q.FallingAcceleration)
					q.FallingSpeed = -7.5 + auxi.random_2() * 5
					q.FallingAcceleration = 0.5
					q.Scale = q.Scale * (1.2 + auxi.random_2() * 0.3)
					if q.ResetSpriteScale then q:ResetSpriteScale() end
					Air.copy_attack_offset(q, ent, true)
					stamp(q, 1, {
						skip_shot_counters = true,
						skip_lead_pencil = true,
						skip_apple = true,
						skip_tough_love = true,
						force_blood_variant = true,
					})
				end
			end
		end
	end
	--- Eye of Greed：每满 20 次攻击计数额外发 1 枚金币泪（不替换本轮攻击）。
	local function drain_greed_coins()
		if not craft_prof or not has_coll(450) then return end
		local bursts = tonumber(d[item.own_key.."greed_burst"]) or 0
		if bursts <= 0 then return end
		d[item.own_key.."greed_burst"] = 0
		local base = dir2:Length() > 0.01 and dir2 or (Vector(10, 0) * atk_shotspeed)
		for _ = 1, bursts do
			local paid = (player:GetNumCoins() or 0) > 0
			player:AddCoins(-1)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_CASH_REGISTER, 1, 1, false, 0, 2)
			local q = attack_holder.FireTear(player, fire_pos, base, {
				mode = "untracked",
				reason = "craft_eye_of_greed",
				no_tracer = true,
			})
			if q then
				q = q:ToTear() or q
				q.Height = Air.tear_height(ent, q.FallingAcceleration)
				Air.copy_attack_offset(q, ent, true)
				stamp(q, 1, {
					skip_shot_counters = true,
					skip_lead_pencil = true,
					skip_apple = true,
					skip_tough_love = true,
					eye_of_greed = true,
					greed_paid = paid,
				})
				-- Rep：有钱时 1.5N+10；没钱仍可发射但不享受伤害加成。
				if paid and q.CollisionDamage ~= nil then
					q.CollisionDamage = 1.5 * atk_damage + 10
				end
			end
		end
	end
	local function drain_shot_counter_effects()
		-- 无 stamp 的武器（剑、部分肺激光等）按本次 volley 计 1 次。
		if stamped_for_counters <= 0 and craft_prof and (has_coll(444) or has_coll(450)) then
			note_craft_shots(1)
		end
		drain_pencil_bursts()
		drain_greed_coins()
		stamped_for_counters = 0
	end
	local function stamp_fetus(q)
		if not q then return end
		stamp(q)
		-- stamp → apply_tear_stats 会整表覆盖 TearFlags，清掉 fire_fetus 写入的 TEAR_FETUS。
		-- 缺基旗时胎儿只剩外形，副武器/配方 flag 也无法按剖腹产逻辑生效，轨迹也不对。
		local fetus_bit = (TearFlags and TearFlags.TEAR_FETUS)
			or BitSet128(0, 1 << (114 - 64))
		q.TearFlags = (q.TearFlags or BitSet128(0, 0)) | fetus_bit
		if craft_prof then CraftProfile.apply_fetus_sec_flags(q, craft_prof) end
		-- 血泪：禁止 BURSTSPLIT；落地/移除走自模拟爆发
		if craft_prof and CraftProfile.profile_has_haemolacria(craft_prof) then
			CraftProfile.clear_craft_haemo_burst_flag(q)
			CraftProfile.mark_craft_haemo_tear(q, craft_prof, player, {
				mods = atk_mods,
				dir = dir2,
				damage = q.CollisionDamage,
				mode = "tears",
			})
		end
	end
	-- 制造胎儿：禁止 fire_fetus 再读玩家 Sec_buffs；副武器 flag 由 stamp_fetus/apply_fetus_sec_flags 写入。
	local function air_fire_fetus(q, pos, vel)
		local params = nil
		if craft_prof then
			params = {
				skip_player_sec_sample = true,
				attack = d[item.own_key.."round_attack"],
			}
		end
		return auxi.fire_fetus(q, player, pos, vel, true, true, params)
	end
	local function apply_craft_flags_roll(ent2)
		if not craft_prof or not ent2 then return end
		local flags = roll_craft_flags(ent2)
		fire_flags = flags
		atk_flags = flags
		Air.apply_craft_flags(ent2, craft_prof, flags, ent)
		CraftTearColors.apply(ent2, craft_prof.counts, flags, CraftProfile.TEAR_EFFECTS)
	end
	-- Knife/Sword：手写 fire_damage 后只登记来源，不二次乘 Dead Eye/巧克力。
	local function stamp_melee_source(ent2)
		if not craft_prof or not ent2 then return end
		Air.stamp_craft_attack(ent2, ent, craft_prof, {
			skip_damage_reapply = true,
			attack_serial = craft_shot_serial,
		})
	end
	dir = - dis:Normalized() * 10 * atk_shotspeed
	dir2 = - dis2:Normalized() * 10 * atk_shotspeed
	-- Cursed Mask craft module: replace unified fire direction (all weapon branches).
	if craft_prof and enums.Items.Cursed_Mask
		and CraftProfile.count_of(craft_prof.counts, enums.Items.Cursed_Mask) > 0 then
		local ok_m, Mask = pcall(require, "Qing_Remaster_scripts.items.Item_Cursed_Mask")
		if ok_m and Mask and Mask.resolve_craft_direction then
			local n = Mask.resolve_craft_direction(ent, player, dir2)
			local spd = 10 * atk_shotspeed
			dir = n * spd
			dir2 = n * spd
		end
	end
	-- 开火前先刷姿态/高度，保证本帧所有攻击与跟随激光吃到同一 Offset
	local aim_face = tgpos2 - ent.Position
	if aim_face:Length() < 0.01 then aim_face = ent.Velocity end
	-- Prefer cursed-mask aim for facing when active.
	if craft_prof and enums.Items.Cursed_Mask
		and CraftProfile.count_of(craft_prof.counts, enums.Items.Cursed_Mask) > 0
		and dir2:Length() > 0.01 then
		aim_face = dir2
	end
	Air.apply_air_aim_visual(
		ent, s, d, aim_face,
		state_succ or d[item.own_key.."kidney_active"] == true,
		d[item.own_key.."Form"]
	)
	-- Passway：无锁敌时射击跟贴图朝向；有锁敌时优先朝目标开火
	local pass_drive = false
	do
		local pass = d[item.own_key.."Passway"]
		local pass_w = tonumber(d[item.own_key.."PassWeight"]) or 0
		pass_drive = pass_w > 0.12
			or (pass and pass.active == true and pass.phase ~= "done")
		if pass_drive then
			local tgt = d[item.own_key.."Target"]
			local shot_n = nil
			if tgt and auxi.check_all_exists(tgt) and auxi.isenemies(tgt) then
				local to = (tgpos2 or tgt.Position) - ent.Position
				if to:Length() > 0.01 then
					shot_n = to:Normalized()
				end
			end
			if not shot_n then
				local face_shot = d[item.own_key.."RotDir"]
					or d[item.own_key.."FaceU"]
					or (pass and pass.face_dir)
				if face_shot and face_shot:Length() > 0.01 then
					shot_n = face_shot:Normalized()
				end
			end
			if shot_n then
				dir = shot_n * 10 * atk_shotspeed
				dir2 = shot_n * 10 * atk_shotspeed
			end
		end
	end
	-- Persistent weapon aim (Brimstone / Tech2): rate-limit DesiredFire → FireAimSm.
	-- One-shot projectiles keep `dir` / `dir2` (instant target). Continuous lasers use persist_dir.
	local persist_dir = dir
	do
		local desired_n = nil
		if dir and dir:Length() > 0.01 then
			desired_n = dir:Normalized()
		elseif dir2 and dir2:Length() > 0.01 then
			desired_n = dir2:Normalized()
		end
		local prev = d[item.own_key.."FireAimSm"]
		local rate = (Air.AIR_AIM_VIS and Air.AIR_AIM_VIS.fire_aim_rate_deg) or 18
		local next_sm = nil
		local function unit_or_nil(v)
			if v and v:Length() > 0.01 then return v:Normalized() end
			return nil
		end
		if pass_drive then
			-- Passway：与机体/火控统一，允许跟切线；退出后由限速承接
			next_sm = desired_n
				or unit_or_nil(prev)
				or unit_or_nil(d[item.own_key.."RotDir"])
				or unit_or_nil(d[item.own_key.."FaceU"])
		elseif desired_n then
			local from = unit_or_nil(prev)
				or unit_or_nil(d[item.own_key.."RotDir"])
				or unit_or_nil(d[item.own_key.."FaceU"])
				or desired_n
			if Air.face_limit_turn then
				next_sm = Air.face_limit_turn(from, desired_n, rate)
			else
				next_sm = desired_n
			end
		else
			next_sm = unit_or_nil(prev)
		end
		if next_sm and next_sm:Length() > 0.01 then
			next_sm = next_sm:Normalized()
			d[item.own_key.."FireAimSm"] = Vector(next_sm.X, next_sm.Y)
			persist_dir = next_sm * 10 * atk_shotspeed
		end
	end
	fire_pos = ent.Position + dir2:Normalized() * 5
	-- 发布给宝宝的瞄准必须在 fire_jobs 之前冻结：job 循环会把 dir 改成附属攻击
	-- （该隐随机朝向 / Incubus 分发等），否则压制模式下每开火一次全体宝宝跟着转头。
	local aux_publish_dir = dir:Length() > 0.01 and dir:Normalized() or nil
	local aux_publish_pos = tgpos2
	local persist_publish_dir = persist_dir and persist_dir:Length() > 0.01 and persist_dir:Normalized() or aux_publish_dir
	local function to_brim_ring(q)
		if not q then return end
		-- TechX variants that can become brimstone rings (Tecro brim_list)
		local brim_vars = {[1]=true,[9]=true,[10]=true,[11]=true,[14]=true,[15]=true}
		if brim_vars[q.Variant] then q.Variant = 3 end
		q.SubType = 3
		-- 只 stamp 一次；调用方勿在 to_brim_ring 前再 stamp
		stamp(q, 1, {skip_scale = true})
	end
	-- Ludovico：制造主武器=8 时走持久受控泪/环/刀形；覆盖巧克力蓄力/诅咒重放语义。
	local craft_is_ludo = craft_prof and weap == 8
	if craft_is_ludo then
		d[item.own_key.."cursed_queue"] = nil
		-- 环形态：命中节奏约 1× tear delay；刀形 ×4 在 holder 内处理
		local syn_l = craft_prof.synergy or {}
		local ludo_base_delay = CraftProfile.craft_fire_delay(craft_prof, 8)
		if syn_l.ludo_brim or syn_l.ludo_tech then
			local st = craft_prof.stats or {}
			ludo_base_delay = tonumber(st.firedelay_base) or tonumber(st.firedelay) or ludo_base_delay
		end
		local ludo_delay = CraftProfile.attack_delay_from_modifiers(ludo_base_delay, atk_mods)
		ludo_delay = CraftOnHurt.apply_it_hurts_delay(ent, ludo_delay)
		local aim_ludo = aim_for_dyn
		if not aim_ludo and dir:Length() > 0.01 then
			aim_ludo = dir:Normalized()
		end
		local epochs = Craft_Ludovico_holder.tick(ent, player, craft_prof, {
			should_shoot = state_succ == true,
			aim_dir = aim_ludo,
			aim_pos = tgpos2,
			target = d[item.own_key.."Target"],
			damage_mul = (atk_mods.damage_mul or 1) * dead_eye_mul,
			damage_add = one_eye.damage or 0,
			eye_damage_mul = one_eye.damage_mul or 1,
			shotspeed = atk_shotspeed,
			scale = proj_scale,
			luck = atk_luck,
			multi = multi_n,
			volley_seed = (ent.InitSeed or 0) + craft_shot_serial * 17 + (tonumber(craft_uid) or 0),
			delay = ludo_delay,
			craft_uid = craft_uid,
		})
		if epochs > 0 then
			note_craft_shots(epochs)
			drain_shot_counter_effects()
			craft_shot_serial = (tonumber(d[item.own_key.."shot_serial"]) or 0) + epochs
			d[item.own_key.."shot_serial"] = craft_shot_serial
			Air.on_volley_fired(ent, player, craft_prof, aim_for_dyn)
			d[item.own_key.."FireDelay"] = ludo_delay
		elseif (d[item.own_key.."FireDelay"] or 0) < 0 then
			d[item.own_key.."FireDelay"] = ludo_delay
		end
		-- 离散 AuxAttackQueue 不适用于持久卢多；Incubus 等改走 holder 宝宝卫星
		d[item.own_key.."AuxAttackQueue"] = nil
	else
		Craft_Ludovico_holder.release_if_not_ludo(ent, craft_prof)
	end
	-- §15.2 诅咒之眼：重放队列（制造档案）；禁止重放再入队。
	-- burst 存活期间冻结下一轮主攻；最后一次 replay 真正完成后才写回 FireDelay。
	local cursed_replay = nil
	local cq = d[item.own_key.."cursed_queue"]
	if (not craft_is_ludo) and cq and (cq.remain or 0) > 0 and state_succ then
		cq.cooldown = (cq.cooldown or 0) - 1
		if cq.cooldown <= 0 then
			cursed_replay = cq
			cq.remain = cq.remain - 1
			cq.cooldown = 1
			-- remain 归零时仍保留 queue，等本帧 job 真正开火后再清。
		end
	end
	local cursed_active = type(cq) == "table"
		and (((tonumber(cq.remain) or 0) > 0) or cursed_replay ~= nil)
	local main_ready = ((d[item.own_key.."FireDelay"] or 0) < 0)
		and state_succ
		and not cursed_active

	-- 主开火 / 诅咒重放 / 附属完整攻击（Incubus 等）统一进 job 列表。
	local fire_jobs = {}
	if (main_ready or cursed_replay)
		and not (craft_is_ludo and not cursed_replay) then
		if (not cursed_replay) and weap == 4 and Air.engine_knives_busy(ent) then
			-- 收刀前不射下一刀；FireDelay 在收刀前冻结，不在这里清零。
		else
			local j = {
				is_replay = cursed_replay ~= nil,
				is_aux = false,
				weap = weap,
				dir = dir,
				dir2 = dir2,
				fire_pos = fire_pos,
				shot_serial = craft_shot_serial,
				atk_mods = atk_mods,
				aux_mul = 1,
			}
			if cursed_replay then
				j.weap = cursed_replay.weap or weap
				local aim = cursed_replay.aim_dir or cursed_replay.dir
				if aim and aim:Length() > 0.01 then
					local n = aim:Normalized()
					local spd = (cursed_replay.dir and cursed_replay.dir:Length() > 0.01) and cursed_replay.dir:Length() or (dir:Length() > 0.01 and dir:Length() or (10 * atk_shotspeed))
					j.dir = n * spd
					j.dir2 = n * 10 * atk_shotspeed
				end
				-- 重放从当前 emitter 再发射，不锁定第一次的世界坐标。
				j.fire_pos = fire_pos
				if cursed_replay.shot_serial then j.shot_serial = cursed_replay.shot_serial end
				if cursed_replay.atk_mods then j.atk_mods = cursed_replay.atk_mods end
				j.replay_index = cursed_replay.next_replay_index or 1
				cursed_replay.next_replay_index = (j.replay_index or 1) + 1
				-- 1 帧间隔：主 Beam lag=0，Replay n 使用滞后 n 帧的瞄准历史。
				j.replay_lag = j.replay_index or 1
				j.cursed_finishes_burst = (tonumber(cursed_replay.remain) or 0) <= 0
				j.cursed_post_delay = cursed_replay.post_fire_delay
			end
			fire_jobs[#fire_jobs + 1] = j
		end
	end
	local aq = d[item.own_key.."AuxAttackQueue"]
	local aux_should = state_succ or d[item.own_key.."kidney_active"] == true
	if not aux_should then
		d[item.own_key.."AuxAttackQueue"] = nil
	elseif type(aq) == "table" and #aq > 0 then
		for _, req in ipairs(aq) do
			local n = req.dir
			if n and n:Length() >= 0.01 then
				n = n:Normalized()
				local spd = 10 * atk_shotspeed
				fire_jobs[#fire_jobs + 1] = {
					is_replay = false,
					is_aux = true,
					weap = weap,
					dir = n * spd,
					dir2 = n * spd,
					fire_pos = req.pos or (ent.Position + n * 5),
					shot_serial = craft_shot_serial,
					atk_mods = atk_mods,
					aux_mul = tonumber(req.damage_mul) or 1,
					host = req.host,
					knife_visual_scale = req.visual_scale,
				}
			end
		end
		d[item.own_key.."AuxAttackQueue"] = {}
	end

	-- 440 Kidney Stone：独立 persistent Attack（不进 open_cohorts / 不与 craft tear cohort 合并）。
	if craft_prof and (craft_prof.counts[440] or 0) > 0 and kidney_requested_attack then
		local shot_dir = dir2:Length() > 0.01 and dir2:Normalized() or Vector(1, 0)
		local kidney_tok = nil
		local kidney_firing = d[item.own_key.."kidney_release"]
			or (tonumber(d[item.own_key.."kidney_burst_remaining"]) or 0) > 0
		if kidney_firing and craft_uid ~= nil and attack_holder.classifier.IsCraftAttackFamiliar(ent) then
			local attack = d[item.own_key.."kidney_attack"]
			if not (attack and attack.active and not attack.ending) then
				attack = CharRound.open_persistent_mimic_attack(ent, player, "tear", {
					reason = "craft_kidney_stone",
					position = fire_pos,
					direction = shot_dir,
				})
				d[item.own_key.."kidney_attack"] = attack
			end
			if attack then
				d[item.own_key.."round_attack"] = attack
				kidney_tok = attack_holder.PushFireContext({
					mode = "inherit",
					attack = attack,
					emitter = ent,
					role = "primary",
					reason = "craft_kidney_stone",
				}).token
			else
				attack_holder.warn_missing_parent_once(
					"craft_kidney_open",
					"Failed to open kidney persistent Attack"
				)
			end
		end
		if d[item.own_key.."kidney_release"] then
			d[item.own_key.."kidney_release"] = nil
			craft_shot_serial = (tonumber(d[item.own_key.."shot_serial"]) or 0) + 1
			d[item.own_key.."shot_serial"] = craft_shot_serial
			craft_proj_index = 0
			local stone = attack_holder.FireTear(
				player,
				fire_pos,
				shot_dir * 10 * atk_shotspeed,
				craft_fire_opts("craft_kidney_stone", { no_tracer = true })
			)
			if stone then
				stone = stone:ToTear() or stone
				Air.copy_attack_offset(stone, ent, true)
				stamp(stone, 5, {
					skip_shot_counters = true,
					skip_lead_pencil = true,
					skip_apple = true,
					skip_tough_love = true,
				})
				if TearVariant.ROCK and stone.ChangeVariant then stone:ChangeVariant(TearVariant.ROCK) end
				local no_inherit = BitSet128(0, 0)
				for _, flag in ipairs({
					TearFlags.TEAR_SPLIT, TearFlags.TEAR_QUADSPLIT,
					TearFlags.TEAR_BURSTSPLIT, TearFlags.TEAR_BOUNCE,
				}) do
					if flag then no_inherit = no_inherit | flag end
				end
				if stone.TearFlags ~= nil then stone.TearFlags = stone.TearFlags & ~no_inherit end
				if stone.Scale ~= nil then stone.Scale = math.max(stone.Scale, 2) end
			end
			d[item.own_key.."kidney_burst_remaining"] = 15
			d[item.own_key.."kidney_burst_tick"] = 0
		elseif (tonumber(d[item.own_key.."kidney_burst_remaining"]) or 0) > 0 then
			d[item.own_key.."kidney_burst_tick"] = (tonumber(d[item.own_key.."kidney_burst_tick"]) or 0) - 1
			if d[item.own_key.."kidney_burst_tick"] <= 0 then
				d[item.own_key.."kidney_burst_tick"] = 2
				local spread = ((ent.InitSeed or 1) + d[item.own_key.."kidney_burst_remaining"] * 37) % 25 - 12
				local spray_dir = auxi.get_by_rotate(shot_dir, spread)
				local q = attack_holder.FireTear(
					player,
					fire_pos,
					spray_dir * 10 * atk_shotspeed,
					craft_fire_opts("craft_kidney_burst", { no_tracer = true })
				)
				if q then
					q = q:ToTear() or q
					Air.copy_attack_offset(q, ent, true)
					stamp(q, 1, {
						skip_shot_counters = true,
						skip_lead_pencil = true,
						skip_apple = true,
						skip_tough_love = true,
					})
				end
				d[item.own_key.."kidney_burst_remaining"] = d[item.own_key.."kidney_burst_remaining"] - 1
				if d[item.own_key.."kidney_burst_remaining"] <= 0 then
					d[item.own_key.."kidney_burst_remaining"] = nil
					d[item.own_key.."kidney_active"] = nil
					d[item.own_key.."kidney_cooldown"] = 240 + ((Game():GetFrameCount() + (ent.InitSeed or 1)) % 181)
					Air.seal_kidney_attack(d)
				end
			end
		end
		if kidney_tok then
			attack_holder.PopFireContext(kidney_tok)
			d[item.own_key.."round_attack"] = nil
		end
	end
	for _, job in ipairs(fire_jobs) do
		is_replay = job.is_replay == true
		is_aux = job.is_aux == true
		weap = job.weap or weap
		dir = job.dir or dir
		dir2 = job.dir2 or dir2
		fire_pos = job.fire_pos or fire_pos
		if job.shot_serial then craft_shot_serial = job.shot_serial end
		if job.atk_mods then atk_mods = job.atk_mods end
		aux_mul = tonumber(job.aux_mul) or 1
		fire_damage = atk_damage * (atk_mods.damage_mul or 1) * aux_mul * dead_eye_mul
		local knife_host = ent
		if is_aux and job.host and job.host.Exists and job.host:Exists() then
			knife_host = job.host
		end
		local delay = atk_delay
		local job_fired = false
		local tgs = {}
		if (not is_replay) and (not is_aux) and has_coll(418) then
			weap = CraftProfile.pick_fruit_cake_weapon()
		end
		-- 推进 volley 序号；具体 TearFlags 在 stamp 内按弹丸独立投掷。
		-- 附属攻击不改写主飞行器 shot_serial，仅用当前值做 flags 种子。
		if craft_prof and not is_replay and not is_aux then
			craft_shot_serial = (tonumber(d[item.own_key.."shot_serial"]) or 0) + 1
			d[item.own_key.."shot_serial"] = craft_shot_serial
			craft_proj_index = 0
		elseif is_aux then
			craft_proj_index = 0
		end
		-- M5: one Attack per craft fire job (source=craft_uid). All Fire* / knife INIT inherit.
		-- Ludo job does not Fire* here (persistent entity); skip empty Attack.
		local round_ctx_token = nil
		local round_attack = nil
		if craft_uid ~= nil and not attack_holder.classifier.IsCraftAttackFamiliar(ent) then
			attack_holder.warn_missing_parent_once(
				"craft_identity_mismatch",
				"Flight has craft_uid but classifier rejected it"
			)
		end
		if craft_prof and craft_uid ~= nil
			and not (weap == 8)
			and attack_holder.classifier.IsCraftAttackFamiliar(ent) then
			local family = CRAFT_ATTACK_FAMILY[weap] or "tear"
			local src = attack_holder.classifier.make_mimic_source(ent, player)
			round_attack = attack_holder.grouping.create_or_join(player, family, {
				max_frame_delta = 0,
				source_id = src.source_id,
				source = src,
				position = fire_pos,
				direction = dir2,
			})
			if round_attack then
				d[item.own_key.."round_attack"] = round_attack
				round_ctx_token = attack_holder.PushFireContext({
					mode = "inherit",
					attack = round_attack,
					emitter = ent,
					role = "primary",
					reason = "craft_fire_job",
				}).token
			else
				attack_holder.warn_missing_parent_once(
					"craft_round_open",
					"Failed to open craft fire round"
				)
			end
		end
		if weap == 8 and craft_prof then
			-- 制造 Ludovico：持久泪由 Craft_Ludovico_holder 维护；job 内不发射。
			delay = CraftProfile.attack_delay_from_modifiers(
				CraftProfile.craft_fire_delay(craft_prof, 8),
				atk_mods
			)
		elseif weap == 1 or weap == 8 or weap == 14 then
			local tbl = {}
			local dirs = craft_volley_dirs(dir2)
			-- 血泪多 guest：仍只发 1 发主气球（叠份另计）；落地 shared 再按各 mode 面额均分，
			-- 禁止按 guest 数打出多颗主气球。
			local haemo_mark_mode = nil
			if craft_prof and weap == 1 and CraftProfile.profile_has_haemolacria(craft_prof) then
				haemo_mark_mode = CraftProfile.haemo_burst_mode(craft_prof)
			end
			for _, shot_dir in ipairs(dirs) do
				local q = attack_holder.FireTear(
					player,
					fire_pos,
					shot_dir,
					craft_fire_opts("craft_fire_job_tear", { no_tracer = true })
				)
				table.insert(tbl,#tbl + 1,q)
				-- 剖腹产：转胎儿前不要 stamp。否则 CraftTearParams 先写平射下落，
				-- 且随后 stamp_fetus 会再 stamp 一次（计数已跳过，但下落/高度仍被污染）。
				if weap ~= 14 then
					q.Height = Air.tear_height(ent,q.FallingAcceleration)
					stamp(q, 1, haemo_mark_mode and { haemo_burst_mode = haemo_mark_mode } or nil)
					if craft_prof and weap == 1 then
						CraftProfile.mark_craft_haemo_tear(q, craft_prof, player, {
							mods = atk_mods,
							dir = shot_dir,
							damage = q.CollisionDamage,
							mode = haemo_mark_mode,
						})
					end
				end
				-- 非制造：保留旧巧克力硬编码。
				if (not craft_prof) and has_coll(69) then
					q.Scale = q.Scale * 2
					q.CollisionDamage = atk_damage * 3
				end
			end
			if (not craft_prof) and has_coll(69) then
				delay = delay + 0.5 * atk_delay
			end
			-- 非制造诅咒眼：旧 delay_buffer；制造走统一队列
			if (not craft_prof) and has_coll(316) then
				for i = 1,4 do
					delay_buffer.addeffe(function(params)
						for _, shot_dir in ipairs(dirs) do
							local q = attack_holder.FireTear(
								player,
								fire_pos,
								shot_dir,
								craft_fire_opts("craft_cursed_eye_tear", { no_tracer = true })
							)
							if weap == 14 then
								air_fire_fetus(q,fire_pos,shot_dir)
								stamp_fetus(q)
							else
								q.Height = Air.tear_height(ent,q.FallingAcceleration)
								stamp(q, 0.3)
							end
							q.Scale = q.Scale * 0.4
						end
					end,{},i*2)
				end
				delay = delay + 3 * atk_delay
			end
			if weap == 14 then
				for u,v in pairs(tbl) do
					air_fire_fetus(v,fire_pos,dir2)
					stamp_fetus(v)
				end
				delay = delay + atk_delay
			end
			-- C Section stack / non-brim morph stack -> extra shots
			if syn and (syn.extra_shots or 0) > 0 and weap == 14 then
				for i = 1, syn.extra_shots do
					local qe = air_fire_fetus(nil,fire_pos,auxi.get_by_rotate(dir2, (i - syn.extra_shots * 0.5) * 8))
					stamp_fetus(qe)
				end
			end
			-- morph 叠份：额外主泪（多 guest 仍各带同一 shared/单 mode，不按 guest 再乘）
			if craft_prof and weap == 1 and syn and (syn.extra_shots or 0) > 0 then
				for i = 1, syn.extra_shots do
					local shot_dir = auxi.get_by_rotate(dir2, (i - syn.extra_shots * 0.5) * 8)
					local qe = attack_holder.FireTear(
						player,
						fire_pos,
						shot_dir,
						craft_fire_opts("craft_fire_job_extra_tear", { no_tracer = true })
					)
					if qe then
						qe.Height = Air.tear_height(ent, qe.FallingAcceleration)
						stamp(qe, 1, haemo_mark_mode and { haemo_burst_mode = haemo_mark_mode } or nil)
						CraftProfile.mark_craft_haemo_tear(qe, craft_prof, player, {
							mods = atk_mods,
							dir = shot_dir,
							damage = qe.CollisionDamage,
							mode = haemo_mark_mode,
						})
					end
				end
			end
		elseif weap == 2 then
			if is_replay or not brim_list_any_alive() then
				-- 持续硫磺火用 FireAimSm（persist_dir），避免 Desired 瞬跳第一帧拧激光
				local dirs = craft_volley_dirs(persist_dir)
				local main_q = nil
				local brim_lag = tonumber(job.replay_lag) or 0
				for bi, shot_dir in ipairs(dirs) do
					-- 按配方 Variant 生成；禁止 FireBrimstone 继承玩家 Brim+Tech 外观
					local q = CraftProfile.spawn_craft_brimstone({
						profile = craft_prof,
						air = ent,
						player = player,
						dir = shot_dir,
						position = fire_pos or ent.Position,
						position_offset = Air.combat_offset(ent),
						timeout = 30,
						attack = round_attack or d[item.own_key.."round_attack"],
						emitter = ent,
					})
					if q then
						stamp(q)
						CraftProfile.decorate_brimstone(q, craft_prof, ent, player, shot_dir, fire_pos)
						if craft_prof and CraftProfile.profile_has_haemolacria(craft_prof) then
							q:GetData().craft_haemo = {
								profile = craft_prof,
								player = player,
								mods = atk_mods,
								dir = shot_dir,
							}
						end
						brim_list_add(q, persist_dir, shot_dir, brim_lag)
						if bi == 1 then main_q = q end
					end
				end
				delay = delay * 0.5
				-- §14.7.3 Brim + Spirit Sword：沿硫磺路径近敌斩击（自定义兼容）。
				if syn and syn.brim_sword and main_q then
					main_q:GetData().craft_brim_sword = {
						player = player,
						dmg = fire_damage,
						flags = fire_flags,
						cd = 0,
						hit = {},
					}
				end
			end
			if has_coll(330) or has_coll(561) then
				brim_list_set_timeout(-1)
			end
			if has_coll(678) then 
				for i = 1,3 do
					delay_buffer.addeffe(function(params)
						local q = air_fire_fetus(nil,fire_pos,dir2) q.Height = Air.tear_height(ent,q.FallingAcceleration)
						stamp_fetus(q)
					end,{},i*2)
				end
			end
			delay = delay * 1.5
			local multitar = 0
			if coll_n(229) > 0 then multitar = multitar + math.random(coll_n(229) * 3) + 1 end
			if (not craft_prof) and coll_n(558) > 0 then multitar = multitar + math.random(coll_n(558) * 2) end
			for i = 1,multitar do
				local shot = auxi.RoundVector()
				local q1 = CraftProfile.spawn_craft_brimstone({
					profile = craft_prof,
					air = ent,
					player = player,
					dir = shot,
					position = ent.Position,
					position_offset = Air.combat_offset(ent),
					timeout = 30,
					attack = round_attack or d[item.own_key.."round_attack"],
					emitter = ent,
				})
				if q1 then
					stamp(q1)
					CraftProfile.decorate_brimstone(q1, craft_prof, ent, player, shot, fire_pos)
				end
			end
		elseif weap == 3 then
			if has_coll(229) then
				local lung_dirs = craft_volley_dirs(dir)
				for _, shot_dir in ipairs(lung_dirs) do
					local lasers = auxi.fire_lung_Laser(player, fire_pos, shot_dir, {
						Posoffset = Air.combat_offset(ent),
						dmg = fire_damage,
					}) or {}
					for _, q in ipairs(lasers) do
						stamp(q)
					end
				end
				delay = delay * 5
				if (not craft_prof) and has_coll(316) then
					delay_buffer.addeffe(function(params)
						auxi.fire_lung_Laser(player,ent.Position,dir,{Posoffset = Air.combat_offset(ent),})
					end,{},2)
					delay = delay + atk_delay * 2
				end
			elseif (not craft_prof) and has_coll(316) then
				for i = 1,5 do
					delay_buffer.addeffe(function(params)
						local q = attack_holder.FireTechLaser(
							player,
							ent.Position,
							dir,
							craft_fire_opts("craft_cursed_eye_tech", {
								offset_id = 0,
								left_eye = false,
								one_hit = true,
							})
						)
						q.PositionOffset = Air.combat_offset(ent)
						stamp(q)
					end,{},i)
				end
				delay = delay * 3.5
			else
				local dirs = craft_volley_dirs(dir)
				for _, shot_dir in ipairs(dirs) do
					local q = attack_holder.FireTechLaser(
						player,
						fire_pos,
						shot_dir,
						craft_fire_opts("craft_fire_job_tech", {
							offset_id = 0,
							left_eye = false,
							one_hit = true,
						})
					)
					q.PositionOffset = Air.combat_offset(ent)
					q.Parent = ent
					stamp(q)
					if craft_prof and CraftProfile.profile_has_haemolacria(craft_prof) then
						local ld = q:GetData()
						ld.craft_haemo = {
							profile = craft_prof,
							player = player,
							mods = atk_mods,
							dir = shot_dir,
						}
					end
				end
				local multitar = 0
				if (not craft_prof) and coll_n(558) > 0 then multitar = multitar + math.random(coll_n(558) * 2) end
				-- Technology stack -> extra lasers (not thicker beam)
				if syn and (syn.extra_shots or 0) > 0 then multitar = multitar + syn.extra_shots end
				for i = 1,multitar do
					local q = attack_holder.FireTechLaser(
						player,
						fire_pos,
						auxi.get_by_rotate(dir, (i - multitar * 0.5) * 6),
						craft_fire_opts("craft_fire_job_tech_extra", {
							offset_id = 0,
							left_eye = false,
							one_hit = true,
						})
					)
					q.PositionOffset = Air.combat_offset(ent)
					q.Parent = ent
					stamp(q)
				end
			end
		elseif weap == 4 then
			-- 引擎 Shoot；MeusNil 跟机主（飞行器或淫魔等附属体）。
			local knife_ratio = atk_mods.knife_ratio or 1
			local knife_range = atk_range * (atk_mods.knife_maxdist_mul or (0.6 * knife_ratio))
			local knife_dmg = fire_damage * (atk_mods.knife_damage_mul or 1)
			local params = {
				player = player,tearflags = atk_flags,Color = player.TearColor,
				Explosive = coll_n(149) + coll_n(52),
				PosOffset = Air.combat_offset(knife_host),
				position = fire_pos,
				craft_air = ent,
			}
			if craft_prof and CraftProfile.profile_has_haemolacria(craft_prof) then
				params.craft_haemo = true
				params.craft_profile = craft_prof
				params.craft_atk_mods = atk_mods
			end
			local dirs = craft_volley_dirs(dir)
			local q = nil
			for ki, shot_dir in ipairs(dirs) do
				local shot_params = auxi.deepCopy(params)
				local qk = auxi.fire_engine_knife(knife_host, shot_dir, knife_dmg, shot_params)
				if qk then
					apply_craft_flags_roll(qk)
					stamp_melee_source(qk)
					local knife_scale = is_aux and (tonumber(job.knife_visual_scale) or 0.65) or 1
					CraftProfile.apply_size_mul(qk, proj_scale * knife_scale)
					Air.shoot_engine_knife(ent, qk, shot_dir, knife_ratio, knife_range, not is_aux)
					job_fired = true
					if ki == 1 then q = qk end
				end
			end
			-- Knife stack -> extra knives
			if syn and (syn.extra_shots or 0) > 0 then
				for i = 1, syn.extra_shots do
					local extra_params = auxi.copy(params)
					extra_params.PathOffset = (i - syn.extra_shots * 0.5) * 12
					local extra_dir = auxi.get_by_rotate(dir, (i - syn.extra_shots * 0.5) * 10)
					local qk = auxi.fire_engine_knife(knife_host, extra_dir, knife_dmg, extra_params)
					if qk then
						apply_craft_flags_roll(qk)
						stamp_melee_source(qk)
						local knife_scale = is_aux and (tonumber(job.knife_visual_scale) or 0.65) or 1
						CraftProfile.apply_size_mul(qk, proj_scale * knife_scale)
						Air.shoot_engine_knife(ent, qk, extra_dir, knife_ratio, knife_range, not is_aux)
						job_fired = true
					end
				end
			end
			-- Knife + Tech X：独立生成跟随环（不走玩家 FireTechXLaser，避免硫磺火改写）。
			if q and ((syn and syn.knife_techx) or (not craft_prof and has_coll(395))) then
				local q2 = Laser_holder.fire_follow_techx_ring({
					pos = fire_pos,
					parent = q,
					source = player,
					radius = 70 * proj_scale,
					dmg = fire_damage * 0.3,
					pos_offset = Air.combat_offset(ent),
					attack = round_attack or d[item.own_key.."round_attack"],
					emitter = ent,
					expected_attack = round_attack ~= nil,
				})
				stamp(q2, 0.3, {skip_scale = true})
			end
			-- §14.7.1 Knife + Technology：桥接激光；offset 差在 Laser_holder 里并入瞄准。
			if q and ((syn and syn.knife_tech) or (not craft_prof and has_coll(68) and not has_coll(395))) then
				local q2 = attack_holder.FireTechLaser(
					player,
					fire_pos,
					dir,
					craft_fire_opts("craft_knife_tech_bridge", {
						offset_id = 1,
						left_eye = false,
						one_hit = false,
						damage_multiplier = 0.45,
					})
				)
				q2.DisableFollowParent = true
				q2.PositionOffset = Air.combat_offset(ent)
				local ld = q2:GetData()
				ld.craft_bridge_start = ent
				ld.craft_bridge_end = q
				q2:SetTimeout(9999)
				-- 生成当帧立刻同步射程，避免首帧默认射程闪一下
				Laser_holder.sync_craft_bridge(q2, true)
				stamp(q2, 0.45)
			end
			if has_coll(229) then
				params.Accerate = 1.5
				params.cooldown = 60
				local rnd = math.random(coll_n(229) * 3) + 2
				for i = 1,rnd do 
					local qk = auxi.fire_knife(fire_pos,auxi.RoundVector() * 13 * atk_shotspeed,fire_damage/2,nil,auxi.copy(params))
					apply_craft_flags_roll(qk)
					stamp_melee_source(qk)
				end
			end
			delay = delay * 1.8 + 1
			if has_coll(118) then
				params.Accerate = 1.5
				params.cooldown = params.cooldown or 60
				local cnt = math.random(3) + 1 + 2 * (coll_n(118) - 1)
				for i = 1,cnt do
					local cnt2 = math.random(2) + (coll_n(118) - 1)
					for j = 1,cnt2 do
						delay_buffer.addeffe(function(pm)
							local rand = math.random(31) - 16
							local q2 = auxi.fire_knife(fire_pos,auxi.get_by_rotate(dir,rand),fire_damage,nil,auxi.copy(params))
							apply_craft_flags_roll(q2)
							stamp_melee_source(q2)
							if rand < 0 then q2:GetSprite().FlipX = true q2.RotationOffset = 180 - q2.RotationOffset end
							delay_buffer.addeffe(function(params)
								local mnil = q2.Parent
								if auxi.check_all_exists(mnil) then	mnil.Velocity = mnil.Velocity:Length() * auxi.MakeVector(dir:GetAngleDegrees()) end
							end,{},5)
							for i = 1,2 do
								delay_buffer.addeffe(function(params)
									if q2:GetSprite().FlipX then q2.RotationOffset = 180 - dir:GetAngleDegrees()
									else q2.RotationOffset = dir:GetAngleDegrees() end
								end,{},5 + i)
							end
						end,{},i * 3)
					end
				end
				delay = delay * 1.5 + 3
			end
		elseif weap == 5 then
			local function fire_craft_bomb(pos, vel)
				local qb = attack_holder.FireBomb(
					player,
					pos,
					vel,
					craft_fire_opts("craft_fire_job_bomb")
				)
				qb.PositionOffset = Air.combat_offset(ent)
				stamp(qb)
				-- 最终爆炸伤：含单眼/巧克力/aux/Dead Eye（fire_damage）
				if qb.ExplosionDamage then
					qb.ExplosionDamage = fire_damage
				end
				if craft_prof then
					CraftProfile.apply_bomb_scale(qb, proj_scale)
					Bomb_holder.attach_craft_aux(qb, craft_prof, player, {
						damage_mul = (atk_mods.damage_mul or 1) * aux_mul * dead_eye_mul,
						size_mul = proj_scale,
						attack = round_attack or d[item.own_key.."round_attack"],
						expected_attack = round_attack ~= nil,
					})
				end
				return qb
			end
			local dirs = craft_volley_dirs(dir)
			for _, shot_dir in ipairs(dirs) do
				fire_craft_bomb(fire_pos, shot_dir)
			end
			local multitar = 0
			if (not craft_prof) and coll_n(558) > 0 then multitar = multitar + math.random(coll_n(558) * 2) end
			if syn and (syn.extra_shots or 0) > 0 then multitar = multitar + syn.extra_shots end
			for i = 1,multitar do
				fire_craft_bomb(fire_pos, auxi.RoundVector(nil,0,{leg2 = 7 * atk_shotspeed,}))
			end
		elseif weap == 6 then
			-- 准星/下落节奏固定；射速只进开火冷却（勿用 atk_delay 拖慢导弹）。
			local missile_cooldown = 35
			local epic_bomb_flags = craft_prof and select(1, CraftProfile.bomb_effects_from_counts(craft_prof.counts, craft_shot_serial + craft_proj_index)) or player:GetBombFlags()
			local params = {
				Cooldown = missile_cooldown,Spawner = ent,Player = player,player = player,
				tearflags = atk_flags | epic_bomb_flags,
				tearflag = atk_flags | epic_bomb_flags,
				dmg = fire_damage,
				attack = round_attack or d[item.own_key.."round_attack"],
			}
			if not craft_prof then
				params.tearflags = player.TearFlags | player:GetBombFlags()
				params.tearflag = params.tearflags
			else
				-- Recipe-only Epic landing burst (ignore owner inventory)
				params.Dontautocheck = true
				local eb = syn and syn.epic_burst or {}
				params.knife = eb.knife or 0
				params.brimstone = eb.brimstone or 0
				params.tech = eb.tech or 0
				params.techX = eb.techX or 0
				params.dr = eb.dr or 0
				params.sword = eb.sword or 0
				params.craft_profile = craft_prof
				params.craft_atk_mods = atk_mods
			end
			local epic_vel_base = -dis/(missile_cooldown + 0.1)
			local epic_dirs = craft_volley_dirs(epic_vel_base)
			for _, shot_vel in ipairs(epic_dirs) do
				auxi.launch_Missile(ent.Position, shot_vel, nil, nil, params)
			end
			local multitar = 0
			for i = 1,coll_n(229) do multitar = multitar + math.random(5) + 1 end
			if (not craft_prof) then
				for i = 1,coll_n(558) do multitar = multitar + math.random(1) end
			end
			if syn and (syn.extra_shots or 0) > 0 then multitar = multitar + syn.extra_shots end
			for i = 1,multitar do auxi.launch_Missile(ent.Position,auxi.RoundVector(nil,3,{leg2 = 0.5,}) - dis/(missile_cooldown + 0.1),nil,nil,params) end
			if has_coll(678) then local q = air_fire_fetus(nil,fire_pos,dir2) q.Height = Air.tear_height(ent,q.FallingAcceleration) stamp_fetus(q) end
			-- 制造档案已含 WEAPON_FIRE_DELAY_MUL[史诗]；非制造仍用旧 ×5 射速。
			if not craft_prof then
				delay = delay * 5
			end
		elseif weap == 7 then
			local function fire_one_lung(shot_dir)
				local lung_params = {
					Posoffset = Air.combat_offset(ent),
					PosOffset = Air.combat_offset(ent),
					dmg = fire_damage,
					shot_speed = atk_shotspeed,
				}
				-- 肺+血泪：减量喷射血泪主弹（Wiki≈8；默认肺 12–20）
				if craft_prof and CraftProfile.profile_has_haemolacria(craft_prof) then
					lung_params.cnt = 8
				end
				if has_coll(52) then
					local bombs = auxi.fire_lung_bomb(fire_pos, shot_dir, player, lung_params) or {}
					for _, qb in ipairs(bombs) do
						stamp(qb)
						if qb.ExplosionDamage then qb.ExplosionDamage = fire_damage end
						if craft_prof then
							CraftProfile.apply_bomb_scale(qb, proj_scale)
							Bomb_holder.attach_craft_aux(qb, craft_prof, player, {
								damage_mul = (atk_mods.damage_mul or 1) * aux_mul * dead_eye_mul,
								size_mul = proj_scale,
								attack = round_attack or d[item.own_key.."round_attack"],
								expected_attack = round_attack ~= nil,
							})
						end
					end
				else
					local tears = auxi.fire_lung(ent.Position, shot_dir, player, lung_params) or {}
					for _, q in ipairs(tears) do
						q.Height = Air.tear_height(ent, q.FallingAcceleration)
						stamp(q)
						if craft_prof then
							CraftProfile.mark_craft_haemo_tear(q, craft_prof, player, {
								mods = atk_mods,
								dir = shot_dir,
								damage = q.CollisionDamage,
							})
						end
					end
				end
			end
			local dirs = craft_volley_dirs(dir)
			for _, shot_dir in ipairs(dirs) do
				fire_one_lung(shot_dir)
			end
			if syn and (syn.extra_shots or 0) > 0 then
				for i = 1, syn.extra_shots do
					fire_one_lung(auxi.get_by_rotate(dir, i * 12))
				end
			end
		elseif weap == 9 then
			local brim_ring = syn and syn.brim_techx
			-- radius_mul = charge_ratio；普通 Tech X 基准 60（15–60）。Brim 组合暂仍用 45，待单独验证。
			local tx_rad = atk_mods.techx_radius_mul or 1
			local tx_dmg = atk_mods.techx_damage_mul or 1
			local dirs = craft_volley_dirs(dir)
			local function fire_tx(shot_dir, rad, dmg_mul, reason)
				local q = CraftProfile.spawn_craft_techx({
					profile = craft_prof,
					air = ent,
					player = player,
					dir = shot_dir,
					radius = rad,
					position = fire_pos,
					position_offset = Air.combat_offset(ent),
					damage_mul = dmg_mul,
					attack = round_attack or d[item.own_key.."round_attack"],
					emitter = ent,
					reason = reason,
					techx_radius_mul = atk_mods.techx_radius_mul,
					projectile_scale = proj_scale,
					main_charge_ratio = craft_prof and craft_prof.main_charge_ratio or atk_mods.charge_ratio,
					techx_charge_ratio = craft_prof and craft_prof.techx_charge_ratio,
					craft_uid = craft_uid,
				})
				if q then
					stamp(q, dmg_mul, {skip_scale = true})
				end
				return q
			end
			if has_coll(229) then
				for _, shot_dir in ipairs(dirs) do
					local rnd = math.random(3) + 3
					for i = 1,rnd do
						local radus = (math.random(30) + 30) * tx_rad * proj_scale
						if brim_ring then radus = radus + 15 * tx_rad * proj_scale end
						local tx_mul = (auxi.random_2() * 0.3 + 1) * tx_dmg
						fire_tx(
							auxi.get_by_rotate(shot_dir, auxi.random_2() * 60),
							radus,
							tx_mul,
							"craft_fire_job_techx_lung"
						)
					end
				end
			else
				local base_rad = brim_ring and 45 or 60
				local rad = base_rad * tx_rad * proj_scale
				for di, shot_dir in ipairs(dirs) do
					local q = fire_tx(shot_dir, rad, tx_dmg, "craft_fire_job_techx")
					if di == 1 and q and craft_prof and CraftProfile.profile_has_haemolacria(craft_prof) then
						q:GetData().craft_haemo = {
							profile = craft_prof,
							player = player,
							mods = atk_mods,
							dir = shot_dir,
						}
					end
				end
			end
			-- §14.7.4 Tech X + Technology：保留环同时附加直线科技
			if syn and syn.techx_tech then
				local qtech = attack_holder.FireTechLaser(
					player,
					fire_pos,
					dir,
					craft_fire_opts("craft_techx_tech", {
						offset_id = 0,
						left_eye = false,
						one_hit = true,
					})
				)
				qtech.Parent = ent
				qtech.PositionOffset = Air.combat_offset(ent)
				stamp(qtech, 0.6 * tx_dmg)
			end
			-- Tech X stack -> extra rings
			if syn and (syn.extra_shots or 0) > 0 then
				for i = 1, syn.extra_shots do
					fire_tx(
						auxi.get_by_rotate(dir, i * 20),
						(brim_ring and 40 or 28) * tx_rad * proj_scale,
						0.6 * tx_dmg,
						"craft_fire_job_techx_extra"
					)
				end
			end
			-- Tech X 冷却：制造走 attack_delay_from_modifiers；非制造保留旧 ×4
			if not craft_prof then
				delay = delay * 4
			end
		elseif weap == 10 or weap == 13 then
			d[item.own_key.."Sword_counter"] = ((d[item.own_key.."Sword_counter"] or 0) + 1)% 5
			local sword_dirs = craft_volley_dirs(dir)
			-- 英灵剑+血泪：有概率额外发射剑泪外观的血泪主弹（落地再爆）
			if craft_prof and CraftProfile.profile_has_haemolacria(craft_prof) then
				local sq = CraftProfile.try_fire_haemo_sword_beam(
					craft_prof, player, fire_pos, dir2, fire_damage, {mods = atk_mods}
				)
				if sq then
					sq.Height = Air.tear_height(ent, sq.FallingAcceleration)
					stamp(sq, 1, {
						skip_shot_counters = true,
						force_variant = TearVariant.SWORD_BEAM or 47,
					})
					CraftProfile.mark_craft_haemo_tear(sq, craft_prof, player, {
						mods = atk_mods,
						dir = dir2,
						damage = sq.CollisionDamage,
					})
				end
			end
			if d[item.own_key.."Sword_counter"] == 0 then
				local params = {
					cooldown = 15,Accerate = -1,player = player,tearflags = atk_flags,
					Color = player.TearColor,Tech = has_coll(68) or has_coll(395),
				}
				if has_coll(114) then params.cool_down = 20 params.del_RotationOffset = 35 end
				if craft_prof and CraftProfile.profile_has_haemolacria(craft_prof) then
					params.craft_haemo = true
					params.craft_profile = craft_prof
					params.craft_atk_mods = atk_mods
				end
				local first_q = nil
				for si, shot_dir in ipairs(sword_dirs) do
					local q = auxi.fire_Sword(fire_pos,shot_dir:Normalized(),fire_damage * 0.2,nil,auxi.copy(params))
					local mnil = q.Parent mnil:GetData().follower = ent
					q.PositionOffset = Air.combat_offset(ent)
					apply_craft_flags_roll(q)
					stamp_melee_source(q)
					if mnil then stamp_melee_source(mnil) end
					CraftProfile.apply_size_mul(q, proj_scale)
					if si == 1 then first_q = q end
					if has_coll(114) then q:Shoot(1,atk_range/4) end
				end
				delay_buffer.addeffe(function(params)
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_SWORD_SPIN,1,1,false,0,2)
				end,{},4)
				if first_q and has_coll(395) then
					local q2 = Laser_holder.fire_follow_techx_ring({
						pos = fire_pos,
						parent = first_q,
						source = player,
						radius = 70 * proj_scale,
						dmg = fire_damage * 0.3,
						pos_offset = Air.combat_offset(ent),
						attack = round_attack or d[item.own_key.."round_attack"],
						emitter = ent,
						expected_attack = round_attack ~= nil,
					})
					stamp(q2, 0.3, {skip_scale = true})
				end
				delay = delay * 5
			else
				local params = {
					cooldown = 8,Accerate = -2,player = player,tearflags = atk_flags,
					Color = player.TearColor,Tech = has_coll(68) or has_coll(395),
					Attack = true,RotationOffset = dir:GetAngleDegrees(),
				}
				if craft_prof and CraftProfile.profile_has_haemolacria(craft_prof) then
					params.craft_haemo = true
					params.craft_profile = craft_prof
					params.craft_atk_mods = atk_mods
				end
				for _, shot_dir in ipairs(sword_dirs) do
					local p = auxi.copy(params)
					p.RotationOffset = shot_dir:GetAngleDegrees()
					local q = auxi.fire_Sword(fire_pos,shot_dir:Normalized(),fire_damage * 0.2,nil,p)
					q.PositionOffset = Air.combat_offset(ent)
					apply_craft_flags_roll(q)
					stamp_melee_source(q)
					if q.Parent then stamp_melee_source(q.Parent) end
					CraftProfile.apply_size_mul(q, proj_scale)
				end
				delay_buffer.addeffe(function(params)
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_SHELLGAME,1,1,false,0,2)
				end,{},4)
			end
			if has_coll(678) then local q = air_fire_fetus(nil,fire_pos,dir2) q.Height = Air.tear_height(ent,q.FallingAcceleration) stamp_fetus(q) end
		end
		-- 蜡烛（495/616）：一次攻击最多一团；原生 Effect 自管衰减/耐久。
		do
			local has_blue_fire = has_coll(495)
			local has_red_fire = has_coll(616)
			if has_blue_fire or has_red_fire then
				local both = has_blue_fire and has_red_fire
				local chance = CraftProfile.candle_fire_chance(atk_luck, both)
				local rng = player:GetCollectibleRNG(has_blue_fire and 495 or 616)
				if rng:RandomFloat() < chance then
					local variant
					if both then
						variant = (rng:RandomFloat() < 0.5)
							and EffectVariant.BLUE_FLAME
							or EffectVariant.RED_CANDLE_FLAME
					elseif has_blue_fire then
						variant = EffectVariant.BLUE_FLAME
					else
						variant = EffectVariant.RED_CANDLE_FLAME
					end
					local q = Isaac.Spawn(
						EntityType.ENTITY_EFFECT,
						variant,
						0,
						fire_pos,
						dir2,
						player
					):ToEffect()
					q.PositionOffset = Air.combat_offset(ent)
					if variant == EffectVariant.BLUE_FLAME then
						-- 初始 600%；原生 Effect 再衰减到 300%
						q.CollisionDamage = fire_damage * 6
						q:SetTimeout(120)
					else
						-- 初始 400%；后续 3/2/2 与耐久由原生红火处理
						q.CollisionDamage = fire_damage * 4
						q:SetTimeout(600)
					end
				end
			end
		end
		if round_ctx_token then
			attack_holder.PopFireContext(round_ctx_token)
			round_ctx_token = nil
			d[item.own_key.."round_attack"] = nil
		end
		Isaacs_Tear_holder.add_tear(player)
		do
			-- Lead Pencil / Eye of Greed：独立 bonus → untracked（不计 Gospel Once）
			local bonus_tok = attack_holder.PushFireContext({
				mode = "untracked",
				reason = "craft_shot_counter_bonus",
			}).token
			drain_shot_counter_effects()
			attack_holder.PopFireContext(bonus_tok)
		end
		if auxi.should_do_Seija(player) and not player:GetPlayerType() == player_Spwq.entity then delay = delay * 2 end
		-- 蓝图制造：射速按表决后的主武器倍率，再经巧克力/TechX 蓄力统一入口。
		if craft_prof then
			delay = CraftProfile.attack_delay_from_modifiers(
				CraftProfile.craft_fire_delay(craft_prof, weap),
				atk_mods
			)
			delay = CraftOnHurt.apply_it_hurts_delay(ent, delay)
		end
		-- §15.2 诅咒之眼：读取滑条 cursed_replays（0–4）；为 0 不入队。
		-- Ludovico 覆盖诅咒蓄力/重放，不入队。
		-- burst = 主发 + 每 1 逻辑帧一次重放；期间禁止新主攻，全部完成后才启动本轮算好的 FireDelay。
		local cursed_n = craft_prof and (tonumber(atk_mods.cursed_replays) or 0) or 0
		local burst_holds_cooldown = false
		if craft_prof and craft_prof.extras and craft_prof.extras.cursed_eye
			and cursed_n > 0 and not is_replay and not is_aux and weap ~= 8 then
			d[item.own_key.."cursed_queue"] = {
				remain = cursed_n,
				cooldown = 1,
				weap = weap,
				aim_dir = (dir:Length() > 0.01) and dir:Normalized() or Vector(1, 0),
				shot_serial = craft_shot_serial,
				atk_mods = atk_mods,
				next_replay_index = 1,
				post_fire_delay = delay,
			}
			burst_holds_cooldown = true
		end
		-- 最后一次 curse replay 真正完成后，才启动该武器原本的攻击冷却。
		if is_replay and job.cursed_finishes_burst then
			local finish_ok = (weap ~= 4) or job_fired
			if finish_ok then
				local post = tonumber(job.cursed_post_delay)
				if post == nil then post = delay end
				if weap == 4 then
					-- 妈刀：仍由收刀后 KnifePendingDelay 启动冷却，不绕过 knife lifecycle。
					d[item.own_key.."KnifePendingDelay"] = post
					d[item.own_key.."FireDelay"] = 100000
				else
					d[item.own_key.."FireDelay"] = post
				end
				d[item.own_key.."cursed_queue"] = nil
			else
				local q = d[item.own_key.."cursed_queue"]
				if type(q) == "table" then
					q.remain = math.max(1, tonumber(q.remain) or 0)
					q.cooldown = 1
					if job.replay_index then
						q.next_replay_index = job.replay_index
					end
				end
			end
		elseif not is_replay and not is_aux then
			if burst_holds_cooldown then
				-- burst 未结束：不启动下一轮主攻冷却（由 cursed_active gate 显式阻塞）。
			elseif weap == 4 and job_fired then
				-- 4/t 从收刀后才开始扣，飞出期间不把冷却跑掉。
				d[item.own_key.."KnifePendingDelay"] = delay
				d[item.own_key.."FireDelay"] = 100000
			else
				d[item.own_key.."FireDelay"] = delay
			end
			if craft_prof then
				Air.on_volley_fired(ent, player, craft_prof, aim_for_dyn)
			end
		end
	end
	do
		local list = brim_list_get()
		local brim_aim = (persist_dir and persist_dir:Length() > 0.01) and persist_dir or dir
		if brim_aim and brim_aim:Length() > 0.01 then
			brim_aim_history_push(brim_aim)
		end
		local off = Air.combat_offset(ent)
		if ent.State == 2 then
			for i = #list, 1, -1 do
				local rec = list[i]
				local las = rec.laser
				if auxi.check_all_exists(las) then
					-- Parent 跟随 Flight；Spawner 保持玩家（见 craft_laser_homing_path_report）
					if auxi.check_for_the_same(las.Parent, ent) ~= true then
						las.Parent = ent
					end
					if las.SetDisableFollowParent then
						las:SetDisableFollowParent(false)
					elseif las.DisableFollowParent ~= nil then
						las.DisableFollowParent = false
					end
					if las.ParentOffset ~= nil then
						las.ParentOffset = Vector(0, 0)
					end
					local delayed = brim_aim_history_get(rec.replay_lag, brim_aim)
					las.Angle = delayed:GetAngleDegrees() + (rec.angle_offset or 0)
					las.PositionOffset = off
					-- Homing：近端 sample 加权跟随，末端固定（见 craft_laser_homing_sample_shift_pitfall）
					if (tonumber(las.HomingType) or 0) ~= 0 then
						CraftProfile.shift_homing_laser_samples(las)
					end
				else
					table.remove(list, i)
				end
			end
		else
			brim_list_clear_dead_or_all(true)
		end
	end
	for i = #(d[item.own_key.."Swords"] or {}),1,-1 do
		local v = d[item.own_key.."Swords"][i]
		if auxi.check_all_exists(v) then
		else table.remove(d[item.own_key.."Swords"],i) end
	end
	if state_succ and has_coll(152) then
		local tech2_dir = (persist_dir and persist_dir:Length() > 0.01) and persist_dir or dir
		local tech2 = d[item.own_key.."Tech2"]
		if auxi.check_all_exists(tech2) then
			Air.follow_tech2_laser(tech2, ent, tech2_dir)
		else
			tech2 = attack_holder.FireTechLaser(player, fire_pos, tech2_dir, {
				mode = "untracked",
				reason = "craft_tech2_continuous",
				offset_id = 0,
				left_eye = false,
				one_hit = false,
				source_entity = ent,
			})
			d[item.own_key.."Tech2"] = tech2
			if tech2 then
				tech2.DepthOffset = -5
				Air.follow_tech2_laser(tech2, ent, tech2_dir)
				-- Tech2：最终攻击伤害 ×0.13；不推进铅笔/贪婪计数
				tech2.CollisionDamage = atk_damage * (atk_mods.damage_mul or 1) * dead_eye_mul * 0.13
				local tech2_flags = craft_prof and roll_craft_flags(tech2) or fire_flags
				Air.apply_craft_flags(tech2, craft_prof, tech2_flags, ent)
				if craft_prof then
					Air.stamp_craft_attack(tech2, ent, craft_prof, {
						dead_eye_mul = dead_eye_mul,
						dead_eye_charge = has_coll(373) and dead_eye_charge or nil,
					})
				end
				local td = tech2.GetData and tech2:GetData()
				if td then
					td.craft_clear_if_dead = ent
				end
				if tech2.SetTimeout then
					tech2:SetTimeout(-1)
				end
			end
		end
	else
		Air.clear_owned_laser(d, "Tech2")
	end
	if state_succ and has_coll(244) then
		if (d[item.own_key.."Tech.5_counter"] or 0) <= 0 and auxi.check_rand(atk_luck,10,2,10) then
			local t5_tok = attack_holder.PushFireContext({
				mode = "untracked",
				reason = "craft_tech5_luck",
			}).token
			local q = auxi.fire_Tech_5_laser(player,fire_pos,dir)
			attack_holder.PopFireContext(t5_tok)
			Air.copy_attack_offset(q, ent, false)
			stamp(q, 1)
			d[item.own_key.."Tech.5_counter"] = 10
		end
	end
	if (d[item.own_key.."Tech.5_counter"] or 0) > 0 then d[item.own_key.."Tech.5_counter"] = d[item.own_key.."Tech.5_counter"] - 1 end
	-- 妈刀：收刀后再开始扣 4/t；飞出期间冻结。
	if weap == 4 then
		if Air.engine_knives_busy(ent) then
			d[item.own_key.."FireDelay"] = 100000
		elseif d[item.own_key.."KnifePendingDelay"] ~= nil then
			d[item.own_key.."FireDelay"] = d[item.own_key.."KnifePendingDelay"]
			d[item.own_key.."KnifePendingDelay"] = nil
		elseif (tonumber(d[item.own_key.."FireDelay"]) or 0) >= 99999 then
			-- 自愈异常/热重载遗留的孤立哨兵：无主刀、无待恢复冷却时立即允许重试。
			d[item.own_key.."FireDelay"] = -1
		else
			d[item.own_key.."FireDelay"] = (d[item.own_key.."FireDelay"] or 0) - 1
		end
	else
		d[item.own_key.."FireDelay"] = (d[item.own_key.."FireDelay"] or 0) - 1
	end
	-- 将飞行器本帧真正采用的攻击状态/方向发布给附属宝宝。
	-- 必须读统一火控结果；FORCE 下没有敌人时也应 should_shoot=true。
	d[item.own_key.."AuxShouldShoot"] = state_succ or d[item.own_key.."kidney_active"] == true
	d[item.own_key.."AuxAimDirection"] = aux_publish_dir
	d[item.own_key.."AuxAimPos"] = aux_publish_pos

	Air.sync_trail(ent, d)
	Air.sync_companions(ent, d, craft_prof, player)
end

end

return M
