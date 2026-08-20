local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local player_Spwq = require("Qing_Remaster_scripts.player.player_Spwq")
local Isaacs_Tear_holder = require("Qing_Remaster_scripts.mimics.Isaacs_Tear_holder")
local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")
local CraftDyn = require("Qing_Remaster_scripts.others.craft_dynamic_stats")
local CraftTearColors = require("Qing_Remaster_scripts.others.craft_tear_color_data")
local CraftTearParams = require("Qing_Remaster_scripts.others.craft_tear_params_data")
local Bomb_holder = require("Qing_Remaster_scripts.mimics.Bomb_holder")
local Laser_holder = require("Qing_Remaster_scripts.mimics.Laser_holder")
local Craft_Familiar_holder = require("Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
local Craft_Orbital_holder = require("Qing_Remaster_scripts.mimics.Craft_Orbital_holder")
local Craft_Ludovico_holder = require("Qing_Remaster_scripts.mimics.Craft_Ludovico_holder")
local CraftOnHurt = require("Qing_Remaster_scripts.others.craft_on_hurt_router")
local dev_env = require("Qing_Remaster_scripts.core.dev_environment")
-- 确保制造宝宝 adapter 完成注册
require("Qing_Remaster_scripts.mimics.Craft_Tear_Babies_holder")
require("Qing_Remaster_scripts.mimics.Craft_Laser_Babies_holder")
require("Qing_Remaster_scripts.mimics.Craft_Advanced_Familiars_holder")

local item = {
	ToCall = {},
	pre_ToCall = {},
	post_ToCall = {},
	entity = enums.Items.Air_Flight,
	familiar = enums.Familiars.QingsAirs,
	own_key = "Item_Air_Flight_",
	Focus2range = {
		cruise = 240,
		guard = 150,
		force = 320,
	},
	FORMATION_CRUISE = 0,
	FORMATION_GUARD = 1,
	FIRE_AUTO = 0,
	FIRE_FORCE = 1,
	-- 兼容旧引用
	MODE_HUNT = 0,
	MODE_FORM = 1,
	MODE_PIN = 2,
	MODE_DIVE = 2,
	-- 调试：>0 覆盖制造档案幸运（妈眼/洛基角等）；nil/≤0 = 用档案
	debug_force_luck = nil,
	-- ImGui：>0 时覆盖 craft 档案移速，便于测高低速；0/nil=用档案
	debug_move_spd = 0,
	-- Passway 精简诊断：仅活跃掠飞内预处理后写 jsonl（默认关）
	enable_passway_log = false,
	-- Flourish 触发/近失/阻断诊断（默认关）
	enable_flourish_log = false,
}
auxi.add_to_seija(item.entity)

local function get_blueprint()
	return require("Qing_Remaster_scripts.items.Item_Blue_Print")
end

local function get_bandwidth()
	return require("Qing_Remaster_scripts.mimics.Craft_Bandwidth_Manager")
end

--- §16：制造附属宝宝只消费飞行器发布的攻击意图。
--- 是否攻击与方向均以飞行器本帧实际攻击状态为准，不要求场上存在敌人；
--- 因此小青的强制攻击模式也能驱动绑定宝宝。
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
function item.queue_craft_aux_attack(ent, pos, dir, damage_mul, source)
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
		local bp = get_blueprint()
		local uid = d[bp.own_key.."craft_uid"]
		local rec = uid and bp.find_craft(player, uid)
		local phase = (rec and tonumber(rec.eye_phase)) or tonumber(d[item.own_key.."eye_phase"]) or 0
		d[item.own_key.."eye_phase"] = phase
		if (counts[600] or 0) > 0 then
			runtime.eye_drops_fire_rate_mul = (phase % 2 == 0) and 1.4 or 1
		end
	end
	-- 191
	if (counts[191] or 0) > 0 then
		local bp = get_blueprint()
		local uid = d[bp.own_key.."craft_uid"]
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
	local d = ent:GetData()
	local bp = get_blueprint()
	local uid = d[bp.own_key.."craft_uid"]
	if uid then
		local rec = bp.find_craft(player, uid)
		local counts = rec and CraftProfile.counts_from_ingredients(rec.ingredients) or {}
		local runtime = build_runtime_for_profile(ent, player, counts, attacking, aim_dir)
		local profile = bp.get_profile_for_uid(player, uid, {air = ent, runtime = runtime})
		d[item.own_key.."craft_profile"] = profile
		return profile
	end
	local new_uid, profile = bp.claim_air_flight_uid(player)
	if new_uid then
		d[bp.own_key.."craft_uid"] = new_uid
		d[item.own_key.."craft_profile"] = profile
		return profile
	end
	return d[item.own_key.."craft_profile"]
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

-- Transfer 俯仰条：外→下→后→上。
-- 姿态：2D 单位向量定向 slerp + 连续俯仰；大转向走「经正面/第一帧」华丽弧，而非贴背短路径。
-- 航向/俯仰都有每帧速率上限，与 Offset 一样保持连续。
local AIR_AIM_VIS = {
	anim = "Transfer",
	frame_count = 60,
	down_frame = 15,
	out_frame = 2,
	lean_max_frame = 30,
	lean_idle = 0.12,
	lean_move = 0.42,
	-- 普通攻击勿锁死俯视（屁股朝屏）；巡航高度时略偏「外」转正
	lean_attack = 0.40,
	attack_pitch_bias = -0.18,
	-- 俯仰：够跟得上准星，但仍有限速防闪帧
	pitch_smooth = 0.38,
	pitch_rate = 0.1,
	pitch_rate_flourish = 0.12,
	pitch_rate_pass = 0.16,
	-- 航向：直接限速追 face_t，不再先 face_smooth 再 yaw_cap（双重阻尼会抖又慢）
	yaw_rate_deg = 11,
	yaw_rate_deg_attack = 14,
	yaw_rate_deg_flourish = 14,
	yaw_rate_deg_pass = 42, -- 掠飞跟切线；过峰后仍要够快，避免贴图拖在旧朝向
	yaw_art_offset = -90,
	-- 轻混速度即可；过大时盘旋切向与准星径向互拧，准星一动就抖
	yaw_face_vel = 0.18,
	yaw_face_vel_attack = 0.08,
	aim_smooth = 0.55, -- 平滑原始瞄准，吃掉准星微抖；大跳仍由 Flourish 处理
	base_offset = -38, -- 巡航高度（更负=屏幕上更高）
	lean_offset = -6, -- |pitch| 轻度抬升，勿再叠大系数
	speed_offset = -5,
	out_pop_offset = -8, -- 仅负俯仰平滑抬升（连续、小幅）
	pass_peak_offset = -24, -- Passway 顶点额外高度
	offset_smooth = 0.18,
	pass_dive_smooth = 0.42, -- 掠飞下落时 OffsetZ 跟手更快
	pass_cushion_smooth = 0.14, -- 落地缓冲期更软
	-- 弹道跟画面高度（经 auxi.offset2height）；钳制避免顶点过高飞越障碍
	combat_offset_y = -34, -- 无 PositionOffset 时的回退（贴近巡航）
	combat_offset_min = -50, -- 更高（更负）上限
	combat_offset_max = -28, -- 更低下限，横射也不贴地
	tilt_lock_eps = 0.04,
	tilt_unlock_turn_deg = 4, -- 正在转向时不解冻 RotDir 会卡抖
	flourish_trigger_deg = 72, -- 原 95 偏严；大回头才触发，观感难出
	flourish_near_deg = 55, -- 近失带：≥此且 <trigger 记 miss
	flourish_out_pitch = -0.92, -- 第一帧/面向镜头
	-- 华丽转向偏好经过的世界朝向（约屏幕「正右」）；配合 out 俯仰=正面特写
	flourish_mid_pref = Vector(1, 0),
}

-- dir_sign: 1=CCW, -1=CW, 0=最短弧
local function vec2_slerp_dir(a, b, t, dir_sign)
	if not b then return a end
	if not a then return b end
	local al = a:Length()
	local bl = b:Length()
	if al < 1e-5 then return bl > 1e-5 and b:Normalized() or Vector(0, 1) end
	if bl < 1e-5 then return a:Normalized() end
	a = a / al
	b = b / bl
	if t <= 0 then return a end
	if t >= 1 then return b end
	local dot = a:Dot(b)
	if dot > 1 then dot = 1 elseif dot < -1 then dot = -1 end
	local th = math.acos(dot)
	if th < 1e-4 then return b end
	local cross = a.X * b.Y - a.Y * b.X
	local short_ccw = cross >= 0
	local want_ccw = short_ccw
	if dir_sign == 1 then want_ccw = true
	elseif dir_sign == -1 then want_ccw = false
	end
	local use_th = th
	if want_ccw ~= short_ccw then
		use_th = math.pi * 2 - th
	end
	local ang = (want_ccw and 1 or -1) * use_th * t
	local c, s = math.cos(ang), math.sin(ang)
	return Vector(a.X * c - a.Y * s, a.X * s + a.Y * c)
end

local function vec2_slerp(a, b, t)
	return vec2_slerp_dir(a, b, t, 0)
end

local function face_turn_deg(a, b)
	if not a or not b then return 0 end
	local al, bl = a:Length(), b:Length()
	if al < 1e-5 or bl < 1e-5 then return 0 end
	local dot = (a:Dot(b)) / (al * bl)
	if dot > 1 then dot = 1 elseif dot < -1 then dot = -1 end
	return math.deg(math.acos(dot))
end

-- 每帧最大转角，保证航向与俯仰一样连续
local function face_limit_turn(from, to, max_deg, dir_sign)
	if not from then return to end
	if not to then return from end
	local need = face_turn_deg(from, to)
	if need <= 1e-3 then return to:Length() > 1e-5 and to:Normalized() or from end
	if need <= max_deg then
		return to:Length() > 1e-5 and to:Normalized() or from
	end
	return vec2_slerp_dir(from, to, max_deg / need, dir_sign or 0)
end

local function pitch_limit_step(cur, target, max_step)
	local dp = target - cur
	if dp > max_step then return cur + max_step end
	if dp < -max_step then return cur - max_step end
	return target
end

-- 选转向方向：中点更靠近「正面偏好」的一侧（大掉头时经 +0/镜头面，而不是贴背）
local function choose_flourish_dir(from, to, mid_pref)
	local mid_short = vec2_slerp_dir(from, to, 0.5, 0)
	local cross = from.X * to.Y - from.Y * to.X
	local long_sign = cross >= 0 and -1 or 1
	local mid_long = vec2_slerp_dir(from, to, 0.5, long_sign)
	local pref = mid_pref or Vector(1, 0)
	if pref:Dot(mid_long) > pref:Dot(mid_short) + 0.05 then
		return long_sign, true
	end
	return 0, false
end

-- ---------- Flourish 精简 jsonl ----------
-- 输出：codex_work/logs/air_flourish.jsonl
-- e= start | miss | block | done | timeout | peek（周期峰值近失）
local FLOURISH_LOG_KEYS = {
	"e", "fr", "seed", "need", "thr", "near", "turn", "jump", "why",
	"pass", "atk", "long", "dir", "dur", "t", "remain", "peak",
	"ok_n", "miss_n", "block_n", "rate",
}

local function flourish_log_encode(row)
	local parts = {}
	for _, k in ipairs(FLOURISH_LOG_KEYS) do
		local v = row[k]
		if v ~= nil then
			local ks = "\""..k.."\":"
			local vt = type(v)
			if vt == "number" then
				if v ~= v or v == math.huge or v == -math.huge then
					parts[#parts + 1] = ks.."null"
				else
					parts[#parts + 1] = ks..string.format("%.4g", v)
				end
			elseif vt == "boolean" then
				parts[#parts + 1] = ks..(v and "true" or "false")
			else
				parts[#parts + 1] = ks.."\""..tostring(v):gsub("\\", "\\\\"):gsub("\"", "\\\"").."\""
			end
		end
	end
	return "{"..table.concat(parts, ",").."}"
end

local function flourish_log_write(row)
	if not dev_env.probes_allowed() then return end
	if not item.enable_flourish_log then return end
	row.fr = Game():GetFrameCount()
	local line = flourish_log_encode(row)
	pcall(function()
		if not io or not io.open then return end
		-- 唯一规范文件；仅两种相对写法（禁止根目录/机器绝对路径兜底）
		local paths = {
			"mods/Qing_remaster/codex_work/logs/air_flourish.jsonl",
			"../mods/Qing_remaster/codex_work/logs/air_flourish.jsonl",
		}
		local mode = "a"
		if not item._flourish_log_ready then
			mode = "w"
		end
		for _, path in ipairs(paths) do
			local f = io.open(path, mode)
			if f then
				f:write(line.."\n")
				f:close()
				item._flourish_log_ready = true
				return
			end
		end
	end)
end

local function flourish_stats(d)
	local st = d[item.own_key.."FlStat"]
	if not st then
		st = {ok_n = 0, miss_n = 0, block_n = 0, peak = 0, peak_fr = 0, last_miss_fr = -999, last_block_fr = -999}
		d[item.own_key.."FlStat"] = st
	end
	return st
end

local function flourish_log_rate(st)
	local den = (st.ok_n or 0) + (st.miss_n or 0) + (st.block_n or 0)
	if den <= 0 then return 0 end
	return (st.ok_n or 0) / den
end

local function air_list_for_player(player)
	local list = {}
	if not player then return list end
	for _, e in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, item.familiar, -1, false, false)) do
		local fam = e:ToFamiliar()
		if fam and auxi.check_all_exists(fam) then
			local owner = auxi.check_spawner_player(fam)
			if owner and auxi.check_for_the_same(owner, player) then
				list[#list + 1] = fam
			end
		end
	end
	table.sort(list, function(a, b)
		return (a.InitSeed or 0) < (b.InitSeed or 0)
	end)
	return list
end

local function air_formation(player, ent)
	local list = air_list_for_player(player)
	local n = #list
	local idx = 1
	local self_hash = GetPtrHash(ent)
	for i = 1, n do
		if GetPtrHash(list[i]) == self_hash then
			idx = i
			break
		end
	end
	local seed = ent.InitSeed or (idx * 97)
	local phase = (idx - 1) * (360 / math.max(n, 1))
	phase = phase + ((seed % 1000) / 1000 - 0.5) * math.min(36, 120 / math.max(n, 1))
	local radius_mul = 0.82 + ((seed % 9) / 9) * 0.4
	local pose_bias = ((seed % 200) / 200) * 2 - 1
	local spin_bias = ((seed % 17) / 17) * 0.6 + 0.7
	return {
		index = idx,
		count = math.max(n, 1),
		phase = phase,
		radius_mul = radius_mul,
		pose_bias = pose_bias,
		spin_bias = spin_bias,
	}
end

local function apply_air_aim_visual(ent, s, d, aim_vec, attacking, form)
	if not ent or not s then return end
	d = d or ent:GetData()
	local vis = AIR_AIM_VIS
	form = form or {}
	local vel = ent.Velocity or Vector(0, 0)
	local spd = vel:Length()
	local pass = d[item.own_key.."Passway"]
	local pass_w = tonumber(d[item.own_key.."PassWeight"]) or 0
	local pass_drive = pass_w > 0.12
		or (pass and pass.active == true and pass.phase ~= "done")
	-- 掠飞：默认跟航迹；有锁敌时混入敌人方向（开火/贴图与航迹可分离）
	if pass_drive then
		local path_aim = nil
		if pass and pass.face_dir and pass.face_dir:Length() > 0.01 then
			path_aim = pass.face_dir
		elseif spd > 0.35 then
			path_aim = vel
		elseif pass and pass.entry_vel and pass.entry_vel:Length() > 0.2 then
			path_aim = pass.entry_vel
		end
		local tgt = d[item.own_key.."Target"]
		local en = nil
		if tgt and auxi.check_all_exists(tgt) and auxi.isenemies(tgt) then
			local to_e = tgt.Position - ent.Position
			if to_e:Length() > 8 then en = to_e end
		end
		if en and path_aim and path_aim:Length() > 0.01 then
			local pu = tonumber(d[item.own_key.."PassU"]) or 0
			local w = (pu >= 0.45) and 0.7 or 0.45
			local mix = path_aim:Normalized() * (1 - w) + en:Normalized() * w
			aim_vec = mix:Length() > 0.01 and mix or en
			attacking = true
		elseif en then
			aim_vec = en
			attacking = true
		else
			attacking = false
			aim_vec = path_aim or aim_vec
		end
		local fl = d[item.own_key.."Flourish"]
		if fl and not fl.done then
			fl.done = true
			d[item.own_key.."Flourish"] = fl
		end
	end
	local aim_raw = aim_vec
	if not aim_raw or aim_raw:Length() < 0.01 then
		aim_raw = spd > 0.2 and vel or Vector(0, 1)
	end
	aim_raw = aim_raw:Normalized()

	-- Flourish 用原始跳变；显示用平滑瞄准，减轻准星微抖
	local aim_prev = d[item.own_key.."AimU"]
	local aim_jump = aim_prev and face_turn_deg(aim_prev, aim_raw) or 0
	d[item.own_key.."AimU"] = Vector(aim_raw.X, aim_raw.Y)

	local aim = aim_raw
	if not pass_drive then
		local aim_sm = d[item.own_key.."AimSm"]
		local a_sm = vis.aim_smooth or 0.55
		-- 大跳时加快跟上，避免「转得慢」
		if aim_jump > 40 then a_sm = math.max(a_sm, 0.78)
		elseif aim_jump > 18 then a_sm = math.max(a_sm, 0.65) end
		if aim_sm and aim_sm:Length() > 0.01 then
			aim = vec2_slerp(aim_sm, aim_raw, a_sm)
		end
		d[item.own_key.."AimSm"] = Vector(aim.X, aim.Y)
	else
		d[item.own_key.."AimSm"] = Vector(aim.X, aim.Y)
	end

	local face_t = aim
	if pass_drive then
		face_t = aim
	elseif spd > 0.8 then
		local vn = vel:Normalized()
		local w_max = attacking and vis.yaw_face_vel_attack or vis.yaw_face_vel
		local w = math.min(1, spd / 8) * w_max
		face_t = vn * w + aim * (1 - w)
		if face_t:Length() < 0.01 then face_t = aim else face_t = face_t:Normalized() end
	end

	local face_cur = d[item.own_key.."FaceU"] or face_t
	local turn_need = face_turn_deg(face_cur, face_t)
	local yaw_cap = attacking and vis.yaw_rate_deg_attack or vis.yaw_rate_deg
	if pass_drive then yaw_cap = vis.yaw_rate_deg_pass or yaw_cap end
	-- 准星大跳时临时放宽航向限速
	if not pass_drive and aim_jump > 25 then
		yaw_cap = math.max(yaw_cap, vis.yaw_rate_deg_attack or yaw_cap)
	end
	local face_dir = 0

	local flourish = d[item.own_key.."Flourish"]
	-- Flourish 超时强行结束，避免护航等场景俯仰卡在出屏段
	if flourish and not flourish.done then
		local over = (flourish.t or 0) - math.max(flourish.dur or 1, 1)
		if over > 36 or (flourish.t or 0) > 90 then
			flourish.done = true
			d[item.own_key.."Flourish"] = flourish
			if item.enable_flourish_log then
				local st = flourish_stats(d)
				flourish_log_write({
					e = "timeout",
					seed = ent.InitSeed or 0,
					t = flourish.t,
					dur = flourish.dur,
					ok_n = st.ok_n,
					miss_n = st.miss_n,
					block_n = st.block_n,
					rate = flourish_log_rate(st),
				})
			end
		end
	end
	local flourish_need = math.max(turn_need, aim_jump)
	local thr = vis.flourish_trigger_deg or 72
	local near_thr = vis.flourish_near_deg or math.max(40, thr - 17)
	local fr_now = Game():GetFrameCount()
	local st = item.enable_flourish_log and flourish_stats(d) or nil
	if st and flourish_need > (st.peak or 0) then
		st.peak = flourish_need
		st.peak_fr = fr_now
	end
	-- 掠飞中禁止 Flourish：否则会强行转向准星再掰回路径
	if pass_drive then
		if flourish and not flourish.done then
			-- 被掠飞打断：记 block（若本可继续）
			if st and flourish_need >= thr and fr_now - (st.last_block_fr or -999) > 12 then
				st.block_n = (st.block_n or 0) + 1
				st.last_block_fr = fr_now
				flourish_log_write({
					e = "block",
					seed = ent.InitSeed or 0,
					need = flourish_need,
					thr = thr,
					near = near_thr,
					turn = turn_need,
					jump = aim_jump,
					why = "pass_interrupt",
					pass = true,
					atk = attacking and true or false,
					ok_n = st.ok_n,
					miss_n = st.miss_n,
					block_n = st.block_n,
					rate = flourish_log_rate(st),
				})
			end
		elseif st and flourish_need >= thr and fr_now - (st.last_block_fr or -999) > 12 then
			st.block_n = (st.block_n or 0) + 1
			st.last_block_fr = fr_now
			flourish_log_write({
				e = "block",
				seed = ent.InitSeed or 0,
				need = flourish_need,
				thr = thr,
				near = near_thr,
				turn = turn_need,
				jump = aim_jump,
				why = "pass_drive",
				pass = true,
				atk = attacking and true or false,
				ok_n = st.ok_n,
				miss_n = st.miss_n,
				block_n = st.block_n,
				rate = flourish_log_rate(st),
			})
		end
		flourish = nil
	elseif (not flourish or flourish.done) and flourish_need >= thr
		and fr_now >= (tonumber(d[item.own_key.."NoFlourishUntil"]) or -1)
	then
		local dir_sign, use_long = choose_flourish_dir(face_cur, aim_raw, vis.flourish_mid_pref)
		local rate = math.max(vis.yaw_rate_deg_flourish, 1)
		flourish = {
			t = 0,
			dur = math.max(20, math.min(48, flourish_need / rate + 6)),
			from = Vector(face_cur.X, face_cur.Y),
			to = Vector(aim_raw.X, aim_raw.Y),
			dir = dir_sign,
			long = use_long,
			pitch0 = d[item.own_key.."Pitch"] or 0,
			done = false,
		}
		d[item.own_key.."Flourish"] = flourish
		if st then
			st.ok_n = (st.ok_n or 0) + 1
			flourish_log_write({
				e = "start",
				seed = ent.InitSeed or 0,
				need = flourish_need,
				thr = thr,
				near = near_thr,
				turn = turn_need,
				jump = aim_jump,
				why = (aim_jump >= turn_need) and "aim_jump" or "turn_need",
				pass = false,
				atk = attacking and true or false,
				long = use_long and true or false,
				dir = dir_sign,
				dur = flourish.dur,
				ok_n = st.ok_n,
				miss_n = st.miss_n,
				block_n = st.block_n,
				rate = flourish_log_rate(st),
			})
		end
	elseif (not flourish or flourish.done) and flourish_need >= thr
		and fr_now < (tonumber(d[item.own_key.."NoFlourishUntil"]) or -1)
	then
		-- 模式切换窗口：只限速转向，不开 Flourish
		if st and fr_now - (st.last_block_fr or -999) > 12 then
			st.block_n = (st.block_n or 0) + 1
			st.last_block_fr = fr_now
			flourish_log_write({
				e = "block",
				seed = ent.InitSeed or 0,
				need = flourish_need,
				thr = thr,
				near = near_thr,
				turn = turn_need,
				jump = aim_jump,
				why = "mode_switch",
				pass = false,
				atk = attacking and true or false,
				ok_n = st.ok_n,
				miss_n = st.miss_n,
				block_n = st.block_n,
				rate = flourish_log_rate(st),
			})
		end
	elseif (not flourish or flourish.done) then
		-- 近失：接近阈值却未达成；节流避免刷屏
		if st and flourish_need >= near_thr and flourish_need < thr then
			if fr_now - (st.last_miss_fr or -999) > 20 then
				st.miss_n = (st.miss_n or 0) + 1
				st.last_miss_fr = fr_now
				flourish_log_write({
					e = "miss",
					seed = ent.InitSeed or 0,
					need = flourish_need,
					thr = thr,
					near = near_thr,
					turn = turn_need,
					jump = aim_jump,
					why = (thr - flourish_need) <= 8 and "edge" or "near",
					pass = false,
					atk = attacking and true or false,
					peak = st.peak,
					ok_n = st.ok_n,
					miss_n = st.miss_n,
					block_n = st.block_n,
					rate = flourish_log_rate(st),
				})
			end
		elseif st and st.peak and st.peak >= near_thr and (fr_now - (st.peak_fr or 0)) >= 90 then
			-- 约 1.5s 窗口峰值快照（未触发时看天花板）
			flourish_log_write({
				e = "peek",
				seed = ent.InitSeed or 0,
				need = flourish_need,
				thr = thr,
				near = near_thr,
				turn = turn_need,
				jump = aim_jump,
				why = "window_peak",
				peak = st.peak,
				pass = pass_drive and true or false,
				atk = attacking and true or false,
				ok_n = st.ok_n,
				miss_n = st.miss_n,
				block_n = st.block_n,
				rate = flourish_log_rate(st),
			})
			st.peak = 0
			st.peak_fr = fr_now
		end
	elseif flourish and not flourish.done then
		flourish.to = Vector(aim_raw.X, aim_raw.Y)
	end

	local face
	local pitch_t

	if flourish and not flourish.done then
		yaw_cap = vis.yaw_rate_deg_flourish
		face_dir = flourish.dir or 0
		flourish.t = (flourish.t or 0) + 1
		local u = flourish.t / math.max(flourish.dur, 1)
		if u > 1 then u = 1 end
		-- smoothstep：只作期望姿态；实际航向仍受 yaw_cap 限制
		local su = u * u * (3 - 2 * u)
		local face_des = vec2_slerp_dir(flourish.from, flourish.to, su, flourish.dir or 0)
		face = face_limit_turn(face_cur, face_des, yaw_cap, face_dir)
		-- 俯仰：起势 → 正面/第一帧 → 目标倾侧（按弧进度，而非强行瞬切）
		local pitch_end
		local lean_t = attacking and vis.lean_attack or vis.lean_move
		if attacking then
			pitch_end = lean_t * 0.75
		else
			local approach_t = face_des:Dot(aim_raw)
			pitch_end = lean_t * math.max(-1, math.min(1, approach_t))
		end
		pitch_end = pitch_end + (form.pose_bias or 0) * 0.12
		local mid = vis.flourish_out_pitch
		if su < 0.5 then
			local k = su * 2
			k = k * k * (3 - 2 * k)
			pitch_t = flourish.pitch0 + (mid - flourish.pitch0) * k
		else
			local k = (su - 0.5) * 2
			k = k * k * (3 - 2 * k)
			pitch_t = mid + (pitch_end - mid) * k
		end
		d[item.own_key.."FaceU"] = face
		-- 时间到且航向真正贴近终点，才结束（限速时可能比 dur 更久）
		local remain = face_turn_deg(face, flourish.to)
		local finished = false
		if (u >= 1 and remain < 8) or remain < 3.5 then
			flourish.done = true
			d[item.own_key.."Flourish"] = flourish
			finished = true
		elseif u >= 1 then
			-- 曲线跑完但角度未到位：继续朝终点限速转，俯仰已接近 pitch_end
			face = face_limit_turn(face, flourish.to, yaw_cap, face_dir)
			d[item.own_key.."FaceU"] = face
			pitch_t = pitch_end
			if face_turn_deg(face, flourish.to) < 3.5 then
				flourish.done = true
				d[item.own_key.."Flourish"] = flourish
				finished = true
			end
		end
		if finished and item.enable_flourish_log then
			local st2 = flourish_stats(d)
			flourish_log_write({
				e = "done",
				seed = ent.InitSeed or 0,
				t = flourish.t,
				dur = flourish.dur,
				remain = remain,
				long = flourish.long and true or false,
				dir = flourish.dir,
				ok_n = st2.ok_n,
				miss_n = st2.miss_n,
				block_n = st2.block_n,
				rate = flourish_log_rate(st2),
			})
		end
	else
		-- 直接限速追 face_t（去掉 face_smooth→yaw_cap 双重阻尼）
		face = face_limit_turn(face_cur, face_t, yaw_cap, 0)
		d[item.own_key.."FaceU"] = face

		if pass_drive then
			-- 掠飞俯仰：轻抬头→回正→下落低头。顶点勿长时间停在朝镜头（第1帧）
			local pu = tonumber(d[item.own_key.."PassU"]) or 0
			if pu < 0.34 then
				local k = pu / 0.34
				pitch_t = -0.08 - 0.16 * (k * k * (3 - 2 * k))
			elseif pu < 0.52 then
				-- 顶点附近尽快离开朝镜头段，回到接近平视
				local k = (pu - 0.34) / 0.18
				k = math.min(1, math.max(0, k))
				pitch_t = -0.24 + 0.22 * (k * k * (3 - 2 * k))
			else
				local k = (pu - 0.52) / 0.48
				k = math.min(1, math.max(0, k))
				k = k * k * (3 - 2 * k)
				pitch_t = -0.02 + 0.72 * k
			end
			pitch_t = pitch_t + (form.pose_bias or 0) * 0.08
		else
			local lean_t = vis.lean_idle
			if attacking then
				lean_t = vis.lean_attack
			elseif spd > 1.5 then
				lean_t = vis.lean_move
			end
			local prev_face = d[item.own_key.."FaceUPrev"] or face
			local turn = math.min(1, (face - prev_face):Length() * 2.2)
			lean_t = math.min(1, lean_t + turn * 0.2)
			local vel_app = 0
			if spd > 0.25 then
				vel_app = math.max(-1, math.min(1, vel:Normalized():Dot(aim)))
			end
			local face_app = math.max(-1, math.min(1, face_t:Dot(aim)))
			local approach_t
			local formation = d[item.own_key.."FormationMode"]
			-- 护卫非开火：少用 face·aim（常≈1 会把俯仰锁在倾侧）
			if formation == item.FORMATION_GUARD and not attacking then
				lean_t = math.min(lean_t, vis.lean_idle + 0.16)
				approach_t = 0.7 * vel_app + 0.15 * face_app
			elseif attacking then
				approach_t = 0.25 * vel_app + 0.75 * face_app
			else
				approach_t = 0.45 * vel_app + 0.55 * face_app
			end
			if attacking then
				pitch_t = lean_t * (0.5 + 0.5 * math.max(0, approach_t))
					+ (vis.attack_pitch_bias or 0)
			else
				pitch_t = lean_t * approach_t
			end
			pitch_t = pitch_t + (form.pose_bias or 0) * (attacking and 0.1 or 0.22)
		end
		if pitch_t > 1 then pitch_t = 1 elseif pitch_t < -1 then pitch_t = -1 end
	end

	d[item.own_key.."FaceUPrev"] = face

	local pitch = d[item.own_key.."Pitch"] or pitch_t
	local p_sm = (flourish and not flourish.done) and 0.35 or vis.pitch_smooth
	if pass_drive then p_sm = math.max(p_sm, 0.28) end
	if not pass_drive and aim_jump > 25 then
		p_sm = math.max(p_sm, 0.5)
	end
	local pitch_des = pitch + (pitch_t - pitch) * p_sm
	local p_rate = (flourish and not flourish.done) and vis.pitch_rate_flourish or vis.pitch_rate
	if pass_drive then p_rate = vis.pitch_rate_pass or p_rate end
	if not pass_drive and aim_jump > 25 then
		p_rate = math.max(p_rate, 0.14)
	end
	pitch = pitch_limit_step(pitch, pitch_des, p_rate)
	if pitch > 1 then pitch = 1 elseif pitch < -1 then pitch = -1 end
	d[item.own_key.."Pitch"] = pitch

	local rot_dir = face
	local locked = d[item.own_key.."RotDir"] or face
	local turn_from_lock = face_turn_deg(locked, face)
	local unlock_deg = vis.tilt_unlock_turn_deg or 4
	-- Passway：贴图必须跟切线，禁止 tilt 冻结卡住旧朝向
	if pass_drive or math.abs(pitch) >= vis.tilt_lock_eps or turn_from_lock >= unlock_deg then
		d[item.own_key.."RotDir"] = face
		rot_dir = face
	else
		rot_dir = locked
		d[item.own_key.."RotDir"] = rot_dir
	end
	local ang = (rot_dir:GetAngleDegrees() + vis.yaw_art_offset) % 360

	local frame
	if pitch >= 0 then
		frame = vis.down_frame + pitch * (vis.lean_max_frame - vis.down_frame)
	else
		-- pitch=-1 → out_frame（第一帧附近）
		frame = vis.down_frame + pitch * (vis.down_frame - vis.out_frame)
	end
	local frame_t = frame
	local frame_s = d[item.own_key.."FrameF"]
	if frame_s == nil then
		frame_s = frame_t
	else
		local n = vis.frame_count + 1
		local delta = (frame_t - frame_s) % n
		if delta > n * 0.5 then delta = delta - n end
		if delta < -n * 0.5 then delta = delta + n end
		local f_sm = (flourish and not flourish.done) and 0.35 or 0.4
		if pass_drive then f_sm = 0.38 end
		if not pass_drive and aim_jump > 25 then f_sm = math.max(f_sm, 0.55) end
		frame_s = frame_s + delta * f_sm
		frame_s = frame_s % n
		if frame_s < 0 then frame_s = frame_s + n end
	end
	d[item.own_key.."FrameF"] = frame_s
	frame = math.floor(frame_s + 0.5)
	if frame < 0 then frame = 0 end
	if frame > vis.frame_count then frame = vis.frame_count end

	-- 高度：巡航 + 轻姿态 + 正面连续微抬 + Passway 掠飞拱；再单独平滑，禁 Flourish 跳高
	local out_w = math.max(0, -pitch)
	out_w = out_w * out_w * (3 - 2 * out_w)
	local pass_alt = tonumber(d[item.own_key.."PassAlt"]) or 0
	if pass_alt < 0 then pass_alt = 0 elseif pass_alt > 1 then pass_alt = 1 end
	local z_t = vis.base_offset
		+ math.abs(pitch) * vis.lean_offset
		+ out_w * vis.out_pop_offset
		+ math.min(1, spd / 10) * vis.speed_offset
		+ pass_alt * vis.pass_peak_offset
	local z = d[item.own_key.."OffsetZ"]
	local cush = tonumber(d[item.own_key.."PassZCushion"]) or 0
	if z == nil then
		z = z_t
		d[item.own_key.."OffsetZVel"] = nil
	elseif cush > 0 then
		-- 落地 Z 缓冲：弹簧阻尼，约 PASS_Z_CUSHION_FRAMES 帧
		local z_vel = tonumber(d[item.own_key.."OffsetZVel"]) or 0
		local err = z_t - z
		local sm = vis.pass_cushion_smooth or 0.14
		z_vel = z_vel * 0.7 + err * (0.16 + sm)
		if z_vel > 2.8 then z_vel = 2.8 elseif z_vel < -2.8 then z_vel = -2.8 end
		z = z + z_vel
		d[item.own_key.."OffsetZVel"] = z_vel
		d[item.own_key.."PassZCushion"] = cush - 1
		if d[item.own_key.."PassZCushion"] <= 0 then
			d[item.own_key.."PassZCushion"] = nil
			d[item.own_key.."OffsetZVel"] = nil
		end
	else
		local osm = (flourish and not flourish.done) and math.min(0.28, vis.offset_smooth + 0.08) or vis.offset_smooth
		if pass_drive then
			-- 下落（目标更靠近地面= OffsetY 更大/更不负）跟手更快；爬升略稳
			if z_t > z + 0.15 then
				osm = math.max(osm, vis.pass_dive_smooth or 0.42)
			else
				osm = math.max(osm, 0.26)
			end
		end
		z = z + (z_t - z) * osm
		d[item.own_key.."OffsetZVel"] = nil
	end
	d[item.own_key.."OffsetZ"] = z
	ent.PositionOffset = Vector(0, z)

	s.PlaybackSpeed = 0
	s:SetFrame(vis.anim, frame)
	s.Rotation = ang
	s.FlipX = false
	s.FlipY = false
end

-- 弹道高度：跟画面 PositionOffset，经 auxi.offset2height 转换。
-- FallingAcceleration>0 时 API 直接吃 Offset.Y 当 Height；≈0 时走 (Y+25)/0.4-25。
-- 泪弹只写 Height、激光等写 PositionOffset，二者不要叠加以免双重抬高。
local function air_combat_offset(ent)
	local vis = AIR_AIM_VIS
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

-- 拖尾跟画面高度（Position + PositionOffset），不跟战斗高度
local function air_sync_trail(ent, d)
	if not ent then return end
	d = d or ent:GetData()
	-- 坠毁期间禁止普通淡青拖尾
	if d[item.own_key.."TrailSuppress"] or d[item.own_key.."Crash"] then
		return
	end
	local sample = ent.Position + (ent.PositionOffset or Vector.Zero)
	local trail = d[item.own_key.."Trail"]
	if auxi.check_all_exists(trail) then
		trail.Position = sample
		trail.Velocity = Vector.Zero
	else
		trail = Isaac.Spawn(
			EntityType.ENTITY_EFFECT,
			EffectVariant.SPRITE_TRAIL,
			0,
			sample,
			Vector.Zero,
			ent
		):ToEffect()
		if not trail then return end
		trail.MinRadius = 0.12
		trail.MaxRadius = 0.12
		trail.SpriteScale = Vector(1.7, 1.7)
		trail.Parent = ent
		trail.Velocity = Vector.Zero
		-- 淡青拖尾；与里小青护航色接近
		trail:SetColor(Color(0.55, 0.9, 1, 0.5, 0.08, 0.18, 0.28), -1, 0)
		d[item.own_key.."Trail"] = trail
	end
end

local function air_soft_velocity(ent, desired, response)
	response = response or 0.2
	local cur = ent.Velocity or Vector(0, 0)
	local next_v = cur * (1 - response) + desired * response
	if next_v:Length() < 0.05 then next_v = Vector(0, 0) end
	ent.Velocity = next_v
end

local function air_orbit_velocity(pos, center, radius, tangent_spd, pull)
	local off = pos - center
	local dist = off:Length()
	if dist < 0.001 then
		return Vector(tangent_spd, 0)
	end
	local radial = off / dist
	local tang = Vector(-radial.Y, radial.X)
	return tang * tangent_spd + radial * ((radius - dist) * (pull or 0.12))
end

-- 均衡相位盘旋：多机均分角度 + 轻微随机半径，避免叠在同一点
local function air_orbit_slot_velocity(pos, center, radius, orb_sign, move_spd, form, spin_rate)
	form = form or {}
	local phase = (form.phase or 0) + Game():GetFrameCount() * (spin_rate or 2.4) * (orb_sign or 1) * (form.spin_bias or 1)
	local r = radius * (form.radius_mul or 1)
	local slot = center + auxi.MakeVector(phase) * r
	local to_slot = slot - pos
	local pull = to_slot:Resized(math.min(9 * move_spd, 2.5 + to_slot:Length() * 0.2))
	local tang = air_orbit_velocity(pos, center, r, 3.6 * move_spd * (orb_sign or 1) * (form.spin_bias or 1), 0.08)
	return pull * 0.72 + tang * 0.55
end

-- Passway：快速升起 → 掠过目标 → 落到对侧（战斗用；Idle 很少触发）
-- 审计见 codex_work/notes/air_flight_3d_aim_visual.md：
-- 标准二次贝塞尔（无 smoothstep 轨迹）+ 解析切线 + 末端制动
-- 顶点后冻结控制点；PASS_ACTIVE→SETTLE→EXIT 权重交接；settle cooldown 防重入
local PASS_PEAK_U = 0.48
local PASS_DIVE_U = 0.68 -- 加速下落起点（代偿水平减速）
local PASS_ARRIVE_DIST = 14
local PASS_SETTLE_MAX = 18
local PASS_SETTLE_MAX_LEAP = 10 -- 短程 leap：更快落地
local PASS_EXIT_FRAMES = 5 -- 缩短落地交接，减少“落地停一下再转”
local PASS_SETTLE_CD = 10
local PASS_LEAP_DIST = 128 -- 短于此距离走 leap（小飞跃），减少空中停顿
local PASS_TIMEOUT_EXTRA = 24
local PASS_BRAKE_ACCEL = 0.55
local PASS_Z_CUSHION_FRAMES = 8
local PASS_CORR_MAX = 0.28 -- 前瞻修正上限；过大易绕 look 点画圈

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
			local luck = 0
			local dbg = tonumber(item.debug_force_luck)
			local use_luck = (dbg and dbg > 0) and dbg or luck
			local p55 = CraftProfile.moms_eye_chance(use_luck)
			local p87 = CraftProfile.lokis_horns_chance(use_luck)
			return string.format(
				"无飞行器\n档案幸运=-- 生效幸运=%.1f%s\n妈眼→%.0f%%  洛基角→%.0f%%\n(0幸运：妈眼50%% / 洛基25%%)",
				use_luck, (dbg and dbg > 0) and " [强制]" or "",
				p55 * 100, p87 * 100
			)
		end
		local d = ent:GetData()
		local hr = air_hit_rate(d)
		local shots = tonumber(d[item.own_key.."ShotCount"]) or 0
		local hits = tonumber(d[item.own_key.."HitCount"]) or 0
		local miss = tonumber(d[item.own_key.."MissCount"]) or 0
		local prof = d[item.own_key.."craft_profile"]
		local luck = (prof and prof.stats and tonumber(prof.stats.luck)) or 0
		local dbg = tonumber(item.debug_force_luck)
		local use_luck = (dbg and dbg > 0) and dbg or luck
		local n55 = CraftProfile.count_of(prof and prof.counts, 55)
		local n87 = CraftProfile.count_of(prof and prof.counts, 87)
		local p55 = CraftProfile.moms_eye_chance(use_luck)
		local p87 = CraftProfile.lokis_horns_chance(use_luck)
		return string.format(
			"命中EWMA=%.0f%% shots=%d hit=%d miss=%d\n档案幸运=%.1f 生效幸运=%.1f%s\n妈眼x%d→%.0f%%  洛基角x%d→%.0f%%\n(0幸运：妈眼50%% / 洛基25%%，不是接近0)",
			hr * 100, shots, hits, miss,
			luck, use_luck, (dbg and dbg > 0) and " [强制]" or "",
			n55, p55 * 100, n87, p87 * 100
		)
	end)
	if ok then return result end
	return "状态读取失败: " .. tostring(result)
end
--- 仅幸运行（无 FindByType）；ImGui 勾选时可安全刷新
function item.get_luck_debug_line()
	local dbg = tonumber(item.debug_force_luck)
	local use_luck = (dbg and dbg > 0) and dbg or 0
	local p55 = CraftProfile.moms_eye_chance(use_luck)
	local p87 = CraftProfile.lokis_horns_chance(use_luck)
	if dbg and dbg > 0 then
		return string.format(
			"强制幸运=%.0f → 妈眼%.0f%% / 洛基%.0f%%（点「刷新命中/弹道」看配方份数）",
			use_luck, p55 * 100, p87 * 100
		)
	end
	return string.format(
		"强制幸运关；档案幸运时 0→妈眼%.0f%%/洛基%.0f%%（点刷新看场上飞行器）",
		CraftProfile.moms_eye_chance(0) * 100,
		CraftProfile.lokis_horns_chance(0) * 100
	)
end

-- ---------- Passway 精简 jsonl（仅活跃掠飞；游戏内预处理后按需落盘）----------
-- 输出：codex_work/logs/air_passway.jsonl
-- 事件 e= start | hit | samp | sum | exit_req
-- hit：扭动/急转/掉速等异常；samp：每 PASS_LOG_SAMP 帧心跳；sum：整段汇总
local PASS_LOG_SAMP = 8
local PASS_LOG_HIT_DTURN = 28
local PASS_LOG_HIT_VTURN = 35
local PASS_LOG_HIT_DROP = 2.0

local function pass_log_json_escape(s)
	s = tostring(s or "")
	s = string.gsub(s, "\\", "\\\\")
	s = string.gsub(s, "\"", "\\\"")
	s = string.gsub(s, "\n", "\\n")
	s = string.gsub(s, "\r", "\\r")
	return s
end

local function pass_log_ang_deg(a, b)
	if not a or not b then return nil end
	local al, bl = a:Length(), b:Length()
	if al < 1e-4 or bl < 1e-4 then return nil end
	local dot = (a:Dot(b)) / (al * bl)
	if dot > 1 then dot = 1 elseif dot < -1 then dot = -1 end
	return math.deg(math.acos(dot))
end

local PASS_LOG_KEYS = {
	"e", "fr", "seed", "kind", "mode", "t", "u", "ph", "dec", "tag",
	"dturn", "vturn", "spd", "v0", "v1", "look", "perr", "drop", "alt", "w", "resp",
	"force", "dist", "r", "dur", "ms",
	"hits", "frames", "max_dturn", "max_vturn", "max_perr", "max_drop",
	"clamp_n", "twist_n", "stutter_n", "worst_u", "worst_tag",
}

local function pass_log_encode(row)
	local parts = {}
	for _, k in ipairs(PASS_LOG_KEYS) do
		local v = row[k]
		if v ~= nil then
			local ks = "\""..k.."\":"
			local vt = type(v)
			if vt == "number" then
				if v ~= v or v == math.huge or v == -math.huge then
					parts[#parts + 1] = ks.."null"
				else
					parts[#parts + 1] = ks..string.format("%.4g", v)
				end
			elseif vt == "boolean" then
				parts[#parts + 1] = ks..(v and "true" or "false")
			else
				parts[#parts + 1] = ks.."\""..pass_log_json_escape(v).."\""
			end
		end
	end
	return "{"..table.concat(parts, ",").."}"
end

local function pass_log_write(row)
	if not dev_env.probes_allowed() then return end
	if not item.enable_passway_log then return end
	row.fr = Game():GetFrameCount()
	local line = pass_log_encode(row)
	pcall(function()
		if not io or not io.open then return end
		-- 唯一规范文件；仅两种相对写法（禁止根目录/机器绝对路径兜底）
		local paths = {
			"mods/Qing_remaster/codex_work/logs/air_passway.jsonl",
			"../mods/Qing_remaster/codex_work/logs/air_passway.jsonl",
		}
		local mode = "a"
		if not item._passway_log_ready then
			mode = "w"
		end
		for _, path in ipairs(paths) do
			local f = io.open(path, mode)
			if f then
				f:write(line.."\n")
				f:close()
				item._passway_log_path = path
				item._passway_log_ready = true
				return
			end
		end
	end)
end

local function pass_log_new_stats()
	return {
		frames = 0,
		hits = 0,
		max_dturn = 0,
		max_vturn = 0,
		max_perr = 0,
		max_drop = 0,
		clamp_n = 0,
		twist_n = 0,
		stutter_n = 0,
		worst_u = 0,
		worst_tag = "",
		worst_score = 0,
	}
end

local function pass_log_on_start(ent, pass, kind, force, dist, r, dur, move_spd)
	if not item.enable_passway_log then return end
	pass._plog = pass_log_new_stats()
	pass._plog_pending = nil
	pass_log_write({
		e = "start",
		seed = ent.InitSeed or 0,
		kind = kind or "",
		mode = (pass and pass.mode) or "arc",
		force = force and true or false,
		dist = dist,
		r = r,
		dur = dur,
		ms = move_spd,
	})
end

--- tick 内预处理：写 pending，等 apply 补 vel 后决定是否落盘
local function pass_log_on_tick(ent, pass, info)
	if not item.enable_passway_log or not pass then return end
	local st = pass._plog or pass_log_new_stats()
	pass._plog = st
	local dturn = info.dturn or 0
	local perr = info.perr or 0
	st.frames = st.frames + 1
	if dturn > st.max_dturn then st.max_dturn = dturn end
	if perr > st.max_perr then st.max_perr = perr end
	if info.clamped then st.clamp_n = st.clamp_n + 1 end
	pass._plog_pending = {
		seed = ent.InitSeed or 0,
		kind = pass.kind or "",
		t = info.t,
		u = info.u,
		ph = info.ph,
		dec = info.dec,
		dturn = dturn,
		spd = info.spd,
		look = info.look,
		perr = perr,
		alt = info.alt,
		phase_ch = info.phase_ch and true or false,
		clamped = info.clamped and true or false,
		w = info.w,
	}
end

local function pass_log_on_apply(ent, d, desired, response, vel0, vel1)
	if not item.enable_passway_log then return end
	local pass = d and d[item.own_key.."Passway"]
	local pend = pass and pass._plog_pending
	if not pend then return end
	pass._plog_pending = nil
	local st = pass._plog or pass_log_new_stats()
	pass._plog = st
	local vturn = pass_log_ang_deg(vel0, vel1) or 0
	local v0 = vel0 and vel0:Length() or 0
	local v1 = vel1 and vel1:Length() or 0
	local des_len = desired and desired:Length() or 0
	local drop = v0 - v1
	if drop < 0 then drop = 0 end
	if vturn > st.max_vturn then st.max_vturn = vturn end
	if drop > st.max_drop then st.max_drop = drop end

	local tags = {}
	if pend.dturn >= PASS_LOG_HIT_DTURN then
		tags[#tags + 1] = "twist"
		st.twist_n = st.twist_n + 1
	end
	if vturn >= PASS_LOG_HIT_VTURN then
		tags[#tags + 1] = "jerk"
		st.stutter_n = st.stutter_n + 1
	end
	if drop >= PASS_LOG_HIT_DROP and des_len >= 4 then
		tags[#tags + 1] = "stall"
		st.stutter_n = st.stutter_n + 1
	end
	if pend.clamped then tags[#tags + 1] = "clamp" end
	if pend.phase_ch then tags[#tags + 1] = "phase" end
	local tag = table.concat(tags, "+")
	local score = pend.dturn + vturn + drop * 12
	if score > st.worst_score then
		st.worst_score = score
		st.worst_u = pend.u or 0
		st.worst_tag = tag
	end

	local is_hit = #tags > 0
	local is_samp = (st.frames % PASS_LOG_SAMP) == 0
	if not is_hit and not is_samp then return end
	if is_hit then st.hits = st.hits + 1 end
	pass_log_write({
		e = is_hit and "hit" or "samp",
		seed = pend.seed,
		kind = pend.kind,
		t = pend.t,
		u = pend.u,
		ph = pend.ph,
		dec = pend.dec,
		tag = tag ~= "" and tag or nil,
		dturn = pend.dturn,
		vturn = vturn,
		spd = pend.spd,
		v0 = v0,
		v1 = v1,
		look = pend.look,
		perr = pend.perr,
		alt = pend.alt,
		drop = drop,
		w = pend.w,
		resp = response,
	})
end

local function pass_log_on_end(ent, pass, reason)
	if not item.enable_passway_log or not pass then return end
	local st = pass._plog or pass_log_new_stats()
	pass_log_write({
		e = "sum",
		seed = ent and (ent.InitSeed or 0) or 0,
		kind = pass.kind or "",
		dec = reason or "done",
		u = pass.t and pass.dur and (pass.t / math.max(pass.dur, 1)) or nil,
		hits = st.hits,
		frames = st.frames,
		max_dturn = st.max_dturn,
		max_vturn = st.max_vturn,
		max_perr = st.max_perr,
		max_drop = st.max_drop,
		clamp_n = st.clamp_n,
		twist_n = st.twist_n,
		stutter_n = st.stutter_n,
		worst_u = st.worst_u,
		worst_tag = st.worst_tag ~= "" and st.worst_tag or nil,
	})
	pass._plog = nil
	pass._plog_pending = nil
end

local function air_clamp_room_pos(pos, margin)
	if not pos then return pos end
	local room = Game():GetRoom()
	if not room then return pos end
	margin = margin or 48
	local tl = room:GetTopLeftPos()
	local br = room:GetBottomRightPos()
	local x = math.max(tl.X + margin, math.min(br.X - margin, pos.X))
	local y = math.max(tl.Y + margin, math.min(br.Y - margin, pos.Y))
	return Vector(x, y)
end

local function air_near_room_edge(pos, margin)
	if not pos then return false end
	local room = Game():GetRoom()
	if not room then return false end
	margin = margin or 56
	local tl = room:GetTopLeftPos()
	local br = room:GetBottomRightPos()
	return pos.X < tl.X + margin or pos.X > br.X - margin
		or pos.Y < tl.Y + margin or pos.Y > br.Y - margin
end

local function air_clear_passway(d)
	if not d then return end
	d[item.own_key.."Passway"] = nil
	d[item.own_key.."PassDrive"] = nil
	d[item.own_key.."PassU"] = nil
	d[item.own_key.."PassAlt"] = 0
	d[item.own_key.."PassWeight"] = 0
	d[item.own_key.."PassZCushion"] = nil
	d[item.own_key.."OffsetZVel"] = nil
end

local function air_request_pass_exit(d)
	if not d then return end
	local pass = d[item.own_key.."Passway"]
	if not pass then
		d[item.own_key.."PassDrive"] = nil
		d[item.own_key.."PassWeight"] = 0
		return
	end
	-- 已结束的掠飞禁止再拉起 EXIT：护航每帧都会 request_exit，
	-- 若把 phase=done 重新 active，会无限 5 帧 EXIT 循环，pass_drive 常开，俯仰/旋转卡死。
	if (not pass.active) or pass.phase == "done" then
		d[item.own_key.."PassDrive"] = nil
		d[item.own_key.."PassWeight"] = 0
		d[item.own_key.."PassU"] = nil
		d[item.own_key.."Passway"] = nil
		return
	end
	if pass.phase == "exit" then return end
	pass.phase = "exit"
	pass.exit_t = 0
	pass.active = true
	local v = pass.prev_desired
	if (not v) or v:Length() < 0.2 then
		v = pass.face_dir
	end
	pass.exit_vel = v and Vector(v.X, v.Y) or Vector(0, 0)
	pass.exit_alt = tonumber(d[item.own_key.."PassAlt"]) or 0.08
	d[item.own_key.."Passway"] = pass
	d[item.own_key.."PassZCushion"] = PASS_Z_CUSHION_FRAMES
	d[item.own_key.."OffsetZVel"] = 0
	if item.enable_passway_log then
		pass_log_write({
			e = "exit_req",
			kind = pass.kind or "",
			t = pass.t or 0,
			u = tonumber(d[item.own_key.."PassU"]) or 0,
			ph = "exit",
			dec = "request_exit",
			alt = pass.exit_alt,
		})
	end
end

-- 世界轨迹：标准二次贝塞尔（不对 u 做 smoothstep，避免端点导数为 0）
local function air_pass_point(pass, u)
	if u < 0 then u = 0 elseif u > 1 then u = 1 end
	local omu = 1 - u
	return pass.p0 * (omu * omu) + pass.p1 * (2 * omu * u) + pass.p2 * (u * u)
end

-- 解析切线 B'(u) = 2(1-u)(p1-p0) + 2u(p2-p1)
local function air_pass_tangent(pass, u)
	if u < 0 then u = 0 elseif u > 1 then u = 1 end
	local dlt = (pass.p1 - pass.p0) * (2 * (1 - u)) + (pass.p2 - pass.p1) * (2 * u)
	if dlt:Length() < 0.05 then
		local fallback = pass.p2 - pass.p0
		if fallback:Length() < 0.05 then return nil end
		return fallback:Normalized()
	end
	return dlt:Normalized()
end

local function air_pass_ideal_geometry(center, approach, tang, r, pose_bias)
	pose_bias = pose_bias or 0
	local p1 = center + tang * (10 + pose_bias * 12)
	local p2 = center - approach * r + tang * (16 + pose_bias * 18)
	return p1, p2
end

--- 爬升跟锚；空闲/靶心大跳/新接敌可解冻继续改终点；过峰后仍可轻挪 p2
local function air_retarget_passway(pass, ent, center, u, opts)
	if not pass or not center or not ent then return end
	opts = opts or {}
	local kind = pass.kind or ""
	local dc0 = center - (pass.center or center)
	local dlen0 = dc0:Length()

	-- 解冻：空闲靶心漂移、新攻击目标、锚点大幅跳动（避免傻飘完全程）
	if pass.frozen then
		local unlock = false
		if opts.target_appeared and u < 0.9 then
			unlock = true
		elseif kind == "idle" and dlen0 > 32 and u < 0.88 then
			unlock = true
		elseif dlen0 > 72 and u < 0.85 then
			unlock = true
		end
		if unlock then
			pass.frozen = false
		else
			-- 冻结期仍轻跟终点，减少落地后再追
			if dlen0 > 10 and u < 0.96 and pass.p2 then
				local soft = (kind == "idle") and 0.2 or 0.1
				pass.center = air_clamp_room_pos((pass.center or center) + dc0 * soft, 56)
				local approach = pass.approach_radial
				if not approach or approach:Length() < 0.01 then
					approach = Vector(0, 1)
				end
				local tang = pass.tang
				if not tang or tang:Length() < 0.01 then
					local os = pass.orb_sign or 1
					tang = Vector(-approach.Y, approach.X) * os
				end
				local r = pass.r or 90
				local ideal_p2
				if kind == "idle" then
					ideal_p2 = pass.center - approach * (r * 0.78) + tang * (r * 0.42 + 8)
				else
					local _p1, p2 = air_pass_ideal_geometry(pass.center, approach, tang, r, pass.pose_bias)
					ideal_p2 = p2
				end
				pass.p2 = air_clamp_room_pos(pass.p2 + (ideal_p2 - pass.p2) * soft, 40)
			end
			return
		end
	end

	if (not opts.force_follow) and u >= PASS_PEAK_U and not opts.target_appeared then
		-- 有目标的猎杀/压制：过峰后冻结主控点（下落可预测）；空闲继续跟
		if kind ~= "idle" then
			pass.frozen = true
			return
		end
	end

	pass.center = pass.center or Vector(center.X, center.Y)
	local dc = center - pass.center
	local dlen = dc:Length()
	local c_follow = 0.12
	if kind == "idle" then c_follow = 0.2 end
	if opts.target_appeared then c_follow = math.max(c_follow, 0.35) end
	if u > 0.3 then c_follow = c_follow + 0.04 end
	if dlen > 80 then c_follow = math.min(0.42, c_follow + 0.14)
	elseif dlen > 40 then c_follow = math.min(0.3, c_follow + 0.08) end
	pass.center = air_clamp_room_pos(pass.center + dc * c_follow, 56)

	local approach = pass.approach_radial
	if not approach or approach:Length() < 0.01 then
		local off0 = ent.Position - pass.center
		approach = off0:Length() > 1 and off0:Normalized() or Vector(0, 1)
	end
	local from = (pass.p0 or ent.Position) - pass.center
	if from:Length() > 10 then
		local ideal_app = from:Normalized()
		local a_follow = (u < 0.3) and 0.06 or 0.1
		if kind == "idle" then a_follow = a_follow + 0.04 end
		if opts.target_appeared then a_follow = math.max(a_follow, 0.16) end
		approach = approach * (1 - a_follow) + ideal_app * a_follow
		local al = approach:Length()
		if al > 1e-5 then approach = approach / al end
	end
	-- 新接敌：切向偏向敌人
	if opts.target_appeared and opts.enemy_pos then
		local to_e = opts.enemy_pos - ent.Position
		if to_e:Length() > 1 then
			local en = to_e:Normalized()
			local tang_a = Vector(-approach.Y, approach.X)
			local tang_b = Vector(approach.Y, -approach.X)
			pass.orb_sign = (tang_a:Dot(en) >= tang_b:Dot(en)) and 1 or -1
		end
	end
	pass.approach_radial = approach

	local orb_sign = pass.orb_sign or 1
	local tang = Vector(-approach.Y, approach.X) * orb_sign
	if pass.tang and pass.tang:Dot(tang) < 0 and not opts.target_appeared then
		tang = -tang
	end
	pass.tang = tang

	local r = pass.r or 90
	-- 靶心靠近时缩小掠飞半径，缩短空中段
	local dist_now = (ent.Position - pass.center):Length()
	if dist_now < (pass.r or 90) * 1.35 then
		r = math.min(r, math.max(24, dist_now * 0.4))
		pass.r = r
	end
	local ideal_p1, ideal_p2 = air_pass_ideal_geometry(pass.center, approach, tang, r, pass.pose_bias)
	if kind == "idle" then
		ideal_p2 = pass.center - approach * (r * 0.78) + tang * (r * 0.42 + 8)
	end
	local p_follow = (kind == "idle") and 0.16 or 0.12
	if u > 0.28 then p_follow = p_follow + 0.04 end
	if opts.target_appeared then p_follow = math.max(p_follow, 0.28) end
	if dlen > 50 then p_follow = math.min(0.4, p_follow + 0.1) end
	pass.p1 = air_clamp_room_pos(pass.p1 + (ideal_p1 - pass.p1) * p_follow, 40)
	pass.p2 = air_clamp_room_pos(pass.p2 + (ideal_p2 - pass.p2) * p_follow, 40)
end

--- 按剩余路径/到终点距离压缩时间轴，避免靶心已近仍慢飘满原 dur
local function air_adapt_passway_duration(pass, ent, move_spd, u)
	if not pass or not ent then return end
	if pass.phase == "exit" or pass.phase == "settle" or pass.phase == "done" then return end
	if u >= 0.9 then return end
	local samples = 6
	local u0 = math.min(math.max(u, 0), 0.98)
	local prev = air_pass_point(pass, u0)
	local remain = 0
	for i = 1, samples do
		local ui = u0 + (1 - u0) * (i / samples)
		local pt = air_pass_point(pass, ui)
		remain = remain + (pt - prev):Length()
		prev = pt
	end
	local to_p2 = (pass.p2 - ent.Position):Length()
	remain = math.max(remain, to_p2 * 0.8)
	local cruise = ((pass.mode == "leap") and 13.5 or 11.5) * math.max(move_spd or 1, 0.75)
	local need = math.max(5, math.ceil(remain / math.max(cruise * 0.72, 2.8)))
	-- 空闲长弧额外催促
	if (pass.kind or "") == "idle" then
		need = math.max(5, math.floor(need * 0.88))
	end
	local new_dur = (pass.t or 0) + need
	local old = math.max(pass.dur or new_dur, 1)
	if new_dur < old then
		-- 每帧最多削约 12%，避免 u 暴涨
		local floor_dur = math.max(new_dur, math.floor(old * 0.88))
		pass.dur = math.max(pass.t + 4, floor_dur)
	end
end

local function air_pass_brake_speed(dist, cruise, move_spd)
	cruise = math.max(cruise or 0, 0)
	if dist <= PASS_ARRIVE_DIST then
		return math.min(cruise, math.max(0.15, dist * 0.32))
	end
	local a = PASS_BRAKE_ACCEL * math.max(move_spd, 0.75)
	local braked = math.sqrt(math.max(0, 2 * a * dist))
	return math.min(cruise, math.max(0.35, braked))
end

-- 过冲后回 p2 的收束速度（远距不用 sqrt(2ad)，否则越远越快飞飞）
local function air_pass_home_speed(dist_end, cruise, move_spd)
	cruise = math.max(cruise or 1, 1)
	move_spd = math.max(move_spd or 1, 0.35)
	dist_end = math.max(dist_end or 0, 0)
	return math.min(cruise, math.max(1.4 * move_spd, math.min(7.5 * move_spd, 2.0 + dist_end * 0.1)))
end

local function air_pass_past_end(pass, pos, u)
	if not pass or not pass.p2 or not pos then return false end
	-- 参数进度太早时的“越过终点平面”多半是抄近路，禁止据此 settle/掉头
	u = tonumber(u) or 0
	if u < 0.52 then return false end
	local t1 = air_pass_tangent(pass, 1)
	if not t1 then return false end
	local ahead = (pos - pass.p2):Dot(t1)
	if ahead <= 6 then return false end
	-- 越早越严：刚过 0.52 需要冲得更远才算真过冲
	local need = 6 + (0.72 - math.min(u, 0.72)) * 80
	return ahead > need
end

--- Passway 高度 0..1：爬升近 sin；u≥PASS_DIVE_U 加速下落；settle 从 land_alt 缓冲落地
local function air_pass_altitude(u, phase, pass)
	phase = phase or "active"
	local leap = pass and pass.mode == "leap"
	local peak_scale = leap and 0.62 or 1
	if phase == "settle" then
		local st = (pass and pass.settle_t) or 0
		local from = (pass and tonumber(pass.land_alt)) or 0.18
		-- 高空落地：更快落到近巡航，缩短悬停
		local cush_frames = (from > 0.4) and math.max(4, PASS_Z_CUSHION_FRAMES - 3) or PASS_Z_CUSHION_FRAMES
		local t = st / math.max(cush_frames, 1)
		if t > 1 then t = 1 elseif t < 0 then t = 0 end
		local cush = 0.08 * math.sin(math.pi * t) * (1 - 0.4 * t)
		local target = 0.04 + cush
		local ease = t * t * (3 - 2 * t)
		if from > 0.4 then
			ease = 1 - (1 - ease) ^ 1.35
		end
		return math.max(0, from * (1 - ease) + target * ease)
	end
	if phase == "exit" or phase == "done" then
		local from = (pass and tonumber(pass.exit_alt)) or (pass and tonumber(pass.land_alt)) or 0.08
		local et = (pass and pass.exit_t) or 0
		local w = 1 - et / math.max(PASS_EXIT_FRAMES, 1)
		if w < 0 then w = 0 end
		return math.max(0, from * w)
	end
	u = tonumber(u) or 0
	if u < 0 then u = 0 elseif u > 1 then u = 1 end
	-- leap：更早开始下落，缩短顶点悬停感
	local peak_u = leap and 0.4 or PASS_PEAK_U
	local dive_u = leap and 0.55 or PASS_DIVE_U
	if u <= peak_u then
		return math.sin((u / peak_u) * (math.pi * 0.5)) * peak_scale
	end
	if u < dive_u then
		local t = (u - peak_u) / math.max(1e-4, dive_u - peak_u)
		return peak_scale * (1 - 0.18 * t)
	end
	-- 加速下落：二次以上衰减到近地
	local t = (u - dive_u) / math.max(1e-4, 0.95 - dive_u)
	if t > 1 then t = 1 elseif t < 0 then t = 0 end
	local start_h = peak_scale * (leap and 0.82 or 0.88)
	local h = start_h * ((1 - t) ^ 2.35)
	if u >= 0.95 then
		h = h * math.max(0, 1 - (u - 0.95) / 0.05)
	end
	return math.max(0, h)
end

local function air_pass_begin_cushion(d, pass, cur_alt)
	if not d then return end
	d[item.own_key.."PassZCushion"] = PASS_Z_CUSHION_FRAMES
	d[item.own_key.."OffsetZVel"] = 0
	if pass then
		pass.land_alt = math.max(0.04, math.min(1, tonumber(cur_alt) or tonumber(d[item.own_key.."PassAlt"]) or 0.2))
	end
end

-- 限制单帧期望速度跳变，避免 15→4 的“突然停下”
local function air_pass_limit_spd_delta(prev_des, spd, max_drop, max_up)
	spd = tonumber(spd) or 0
	local prev = (prev_des and prev_des:Length()) or spd
	max_drop = max_drop or 2.2
	max_up = max_up or 1.6
	if spd < prev - max_drop then spd = prev - max_drop end
	if spd > prev + max_up then spd = prev + max_up end
	return spd
end

--- 返回 intent：{velocity, weight, altitude, facing, u, phase}；无掠飞时 nil
local function air_tick_passway(d, ent, move_spd, center)
	local pass = d[item.own_key.."Passway"]
	if not pass or not pass.active then
		return nil
	end
	pass.phase = pass.phase or "active"
	local phase0 = pass.phase
	local dur = math.max(pass.dur or 1, 1)
	pass.t = (pass.t or 0) + 1
	local u = pass.t / dur
	if u < 0 then u = 0 end
	local decision = "cruise"
	local spd_used = nil

	-- 掠飞中新接敌：解冻并短时强跟（勿只改一帧就过峰冻死）
	local now_atk = d[item.own_key.."PassAttacking"] == true
	local tgt = d[item.own_key.."Target"]
	local tgt_ok = tgt and auxi.check_all_exists(tgt) and auxi.isenemies(tgt)
	local target_appeared = now_atk and (not pass.attacking) and tgt_ok
	if now_atk then pass.attacking = true end
	if target_appeared then
		pass.retarget_boost = 12
	elseif (pass.retarget_boost or 0) > 0 then
		pass.retarget_boost = pass.retarget_boost - 1
	end
	local boost = (pass.retarget_boost or 0) > 0

	if pass.phase == "active" or pass.phase == "enter" then
		if center then
			center = air_clamp_room_pos(center, 56)
			air_retarget_passway(pass, ent, center, math.min(u, 1), {
				target_appeared = target_appeared or boost,
				enemy_pos = tgt_ok and tgt.Position or nil,
				force_follow = boost,
			})
			air_adapt_passway_duration(pass, ent, move_spd, math.min(u, 1))
			dur = math.max(pass.dur or 1, 1)
			u = pass.t / dur
			decision = boost and "retarget_new_tgt" or "retarget"
		elseif u >= PASS_PEAK_U and not pass.frozen then
			pass.frozen = true
			decision = "freeze_peak"
		end
	end

	local dist_end = (pass.p2 - ent.Position):Length()
	local past_end = air_pass_past_end(pass, ent.Position, math.min(u, 1))
	-- 前瞻：中等胡萝卜；已过终点则直接看 p2，禁止沿出射切线外飞
	local vel_est = (ent.Velocity and ent.Velocity:Length()) or 6
	local want_look = math.max(26, math.min(52, vel_est * 2.8))
	local look_u = math.min(1, math.min(u, 1) + math.max(4 / dur, 0.06))
	local pt = air_pass_point(pass, look_u)
	if past_end or u >= 0.9 then
		look_u = 1
		pt = pass.p2
	else
		local guard = 0
		while look_u < 1 and (pt - ent.Position):Length() < want_look and guard < 14 do
			look_u = math.min(1, look_u + 0.04)
			pt = air_pass_point(pass, look_u)
			guard = guard + 1
		end
	end
	local to_look = pt - ent.Position
	local face
	if past_end then
		face = to_look:Length() > 0.01 and to_look:Normalized() or air_pass_tangent(pass, 1)
	else
		face = air_pass_tangent(pass, look_u)
		if (not face) and to_look:Length() > 0.01 then
			face = to_look:Normalized()
		end
	end
	local path_now = air_pass_point(pass, math.min(1, math.max(0, u)))
	local path_err = (ent.Position - path_now):Length()
	-- 过冲时 path_err 用距 p2，便于日志与回线
	if past_end then path_err = dist_end end

	-- 锁敌掠飞：朝向混入敌人方向，避免爬升段头完全跟切线、落地才拧准星
	do
		local tgt = d[item.own_key.."Target"]
		local attacking = pass.attacking or d[item.own_key.."PassAttacking"]
		if face and attacking and tgt and auxi.check_all_exists(tgt) and auxi.isenemies(tgt) then
			local to_e = tgt.Position - ent.Position
			if to_e:Length() > 8 then
				local en = to_e:Normalized()
				local aim_w = 0.32
				if past_end or u >= PASS_PEAK_U then
					aim_w = 0.78
				elseif u >= 0.28 then
					aim_w = 0.52
				end
				local mix = face * (1 - aim_w) + en * aim_w
				local ml = mix:Length()
				if ml > 1e-4 then face = mix / ml end
			end
		end
	end

	local desired
	local weight = 1

	if pass.phase == "exit" then
		pass.exit_t = (pass.exit_t or 0) + 1
		weight = 1 - pass.exit_t / PASS_EXIT_FRAMES
		decision = "exit_fade"
		if weight <= 0 then
			pass.active = false
			pass.phase = "done"
			d[item.own_key.."PasswayCD"] = pass.cd_next or 42
			d[item.own_key.."PassSettleCD"] = PASS_SETTLE_CD
			d[item.own_key.."Passway"] = pass
			d[item.own_key.."PassDrive"] = nil
			d[item.own_key.."PassWeight"] = 0
			d[item.own_key.."PassU"] = nil
			-- 落地朝向交接：避免清掉后贴图从旧航向慢慢拧回来
			if pass.face_dir and pass.face_dir:Length() > 0.01 then
				d[item.own_key.."FaceU"] = Vector(pass.face_dir.X, pass.face_dir.Y)
				d[item.own_key.."RotDir"] = Vector(pass.face_dir.X, pass.face_dir.Y)
				d[item.own_key.."AimSm"] = Vector(pass.face_dir.X, pass.face_dir.Y)
			end
			pass.face_dir = nil
			pass_log_on_end(ent, pass, "exit_complete")
			return nil
		end
		desired = pass.exit_vel or Vector(0, 0)
		if desired:Length() > 0.01 then
			-- 交接期保持最低前进感，避免 weight 降到一半时速度≈0
			desired = desired:Resized(math.max(2.0 * weight, desired:Length() * (0.55 + 0.45 * weight)))
		end
		spd_used = desired:Length()
		if face == nil and desired:Length() > 0.2 then
			face = desired:Normalized()
		end
	elseif pass.phase == "settle" then
		pass.settle_t = (pass.settle_t or 0) + 1
		local to_end = pass.p2 - ent.Position
		dist_end = to_end:Length()
		local settle_max = (pass.mode == "leap") and PASS_SETTLE_MAX_LEAP or PASS_SETTLE_MAX
		local cur_pa = tonumber(d[item.own_key.."PassAlt"]) or tonumber(pass.land_alt) or 0
		-- 高空落到近地再 exit，避免 settle 瞬间结束造成悬停观感
		local alt_ok = cur_pa <= 0.28
		local can_exit = (pass.settle_t >= settle_max + 8)
			or ((dist_end < 8 or pass.settle_t >= settle_max) and alt_ok)
			or (pass.settle_t >= settle_max and cur_pa <= 0.4)
		if can_exit then
			pass.phase = "exit"
			pass.exit_t = 0
			-- 保留残余速度交接 idle/盘旋，禁止几乎刹停后再慢慢转过来
			local v = ent.Velocity or Vector(0, 0)
			local pull = to_end:Length() > 0.01 and to_end:Normalized() * math.min(2.8, to_end:Length() * 0.2) or Vector(0, 0)
			if v:Length() > 1.2 then
				pass.exit_vel = v:Resized(math.min(4.8, math.max(2.4, v:Length() * 0.7)))
			elseif pull:Length() > 0.2 then
				pass.exit_vel = pull:Resized(math.max(2.2, pull:Length()))
			else
				local tang = air_pass_tangent(pass, 1) or pass.face_dir
				pass.exit_vel = tang and tang:Resized(2.6) or Vector(0, 0)
			end
			pass.exit_alt = math.min(0.35, tonumber(pass.land_alt) or air_pass_altitude(1, "settle", pass) or 0.2)
			desired = pass.exit_vel
			decision = (dist_end < 8) and "settle_to_exit_arrive" or "settle_to_exit_timeout"
		else
			local spd = (dist_end > 40) and air_pass_home_speed(dist_end, 6 * move_spd, move_spd)
				or air_pass_brake_speed(dist_end, 3.2 * move_spd, move_spd)
			spd_used = spd
			local aim = to_end:Length() > 0.01 and to_end:Normalized() or nil
			if aim and pass.prev_desired and pass.prev_desired:Length() > 0.25 then
				aim = face_limit_turn(pass.prev_desired:Normalized(), aim, (pass.mode == "leap") and 55 or 48)
			end
			desired = aim and aim:Resized(spd) or Vector(0, 0)
			decision = "settle_home"
			if face == nil and aim then
				face = aim
			end
		end
		u = math.max(u, 1)
	else
		-- active / enter
		pass.phase = "active"
		local cruise_scale = (pass.mode == "leap") and 1.22 or 1
		local cruise = (12.5 * move_spd * cruise_scale) * (0.92 + 0.45 * math.sin(math.pi * math.min(u, 1)))
		local look_len = to_look:Length()
		local to_p2 = pass.p2 - ent.Position
		local cur_alt = air_pass_altitude(math.min(u, 1), "active", pass)
		local spd
		local steer = nil
		-- leap / 过峰后提高限转：掠过目标后要尽快拧向出射/回家，避免慢悠悠掉头
		local turn_cap = (pass.mode == "leap") and 40 or 26
		if past_end or u >= PASS_PEAK_U then
			turn_cap = (pass.mode == "leap") and 56 or 42
		end
		-- 早到：须进度够晚，避免抄近路贴 p2 后 u 仍低 → 错误掉头再修正
		local early_mul = (pass.mode == "leap") and 1.45 or 1.15
		local u_gate = (pass.mode == "leap") and 0.5 or 0.58
		local early_arrive = false
		if dist_end <= 10 and u >= 0.4 then
			early_arrive = true
		elseif u >= u_gate then
			early_arrive = (dist_end <= PASS_ARRIVE_DIST * early_mul)
				or (past_end and dist_end <= ((pass.mode == "leap") and 56 or 48))
				or (dist_end <= ((pass.mode == "leap") and 28 or 22))
		end
		-- 高空早到：先落高度再 settle，避免顶点附近悬停
		if early_arrive and cur_alt > 0.45 and u < 0.85 then
			early_arrive = false
		end
		-- 空间上已近终点但参数还早 / 或高空待落：只减速贴线，不 settle
		local early_near = (not early_arrive) and (
			((u < u_gate) and (dist_end < 48 or (dist_end < 70 and path_err > 40)))
			or (cur_alt > 0.45 and dist_end < 40 and u >= u_gate)
		)

		if past_end and dist_end > 88 and u >= 0.62 then
			pass.phase = "exit"
			pass.exit_t = 0
			local v = ent.Velocity or Vector(0, 0)
			pass.exit_vel = v:Length() > 0.2 and v:Resized(math.min(2.4, v:Length() * 0.45)) or Vector(0, 0)
			pass.exit_alt = cur_alt
			pass.land_alt = cur_alt
			desired = pass.exit_vel
			spd_used = desired:Length()
			decision = "to_exit_overshoot"
			air_pass_begin_cushion(d, pass, cur_alt)
		elseif early_arrive then
			pass.phase = "settle"
			pass.settle_t = 0
			air_pass_begin_cushion(d, pass, cur_alt)
			local aim = to_p2:Length() > 0.01 and to_p2:Normalized() or (face or Vector(0, 1))
			local vlen = (ent.Velocity and ent.Velocity:Length()) or 0
			spd = math.min(air_pass_brake_speed(math.max(dist_end, 4), 4.5 * move_spd, move_spd), math.max(1.2, vlen * 0.55))
			spd = air_pass_limit_spd_delta(pass.prev_desired, spd, 2.6, 1.2)
			desired = aim:Resized(spd)
			spd_used = spd
			face = aim
			decision = past_end and "to_settle_early_past" or "to_settle_early"
		else
			-- 末段回家：仅在真正后段或明确过冲，避免中段 past_end 误触发急停
			local endgame = (u >= 0.86) or (u >= 0.72 and dist_end < 36) or (past_end and u >= 0.62)
			if endgame then
				if dist_end > 40 or past_end then
					spd = air_pass_home_speed(dist_end, cruise * 0.85, move_spd)
					decision = "home"
				else
					spd = air_pass_brake_speed(dist_end, cruise * 0.85, move_spd)
					decision = "brake"
				end
				steer = to_p2:Length() > 0.01 and to_p2:Normalized() or (face or Vector(0, 1))
				turn_cap = past_end and ((pass.mode == "leap") and 62 or 52) or math.max(turn_cap, 36)
				decision = decision.."_p2"
			else
				-- 用剩余距离/剩余帧封顶巡航，避免空间进度远超参数 u
				local frames_left = math.max(4, dur * (1 - math.min(u, 0.98)))
				local sync_cap = (dist_end / frames_left) * 1.2 + 2.2 * move_spd
				local remain = math.max(dist_end, look_len)
				local path_cap = math.max(4.2 * move_spd, 2.0 + remain * 0.13)
				path_cap = math.min(path_cap, sync_cap)
				if early_near then
					path_cap = math.min(path_cap, 5.5 * move_spd)
				end
				if u >= PASS_DIVE_U then
					spd = math.min(cruise * 0.9, path_cap)
					decision = "cruise_dive"
				else
					spd = math.min(cruise, 5.2 + math.max(look_len, 18) * 0.3, path_cap)
					decision = "cruise"
				end
				-- 渐近制动（非一刀切 brake_p2）
				if dist_end < 55 or early_near then
					local soft = air_pass_brake_speed(dist_end, spd, move_spd)
					local w = 1 - math.max(0, (dist_end - 22) / 33)
					if early_near then w = math.max(w, 0.55) end
					if w > 1 then w = 1 elseif w < 0 then w = 0 end
					spd = spd * (1 - 0.55 * w) + soft * (0.55 * w)
					decision = decision..(early_near and "_hold" or "_soft")
				end
				local tang = face or air_pass_tangent(pass, math.min(u, 1))
				if early_near and tang then
					-- 早到点附近：切线为主，轻混向 p2，禁止大幅掉头
					local to_n = to_p2:Length() > 0.01 and to_p2:Normalized() or tang
					local align = tang:Dot(to_n)
					local mix_w = (align > 0.2) and 0.22 or 0.08
					local mix = tang * (1 - mix_w) + to_n * mix_w
					local ml = mix:Length()
					steer = ml > 1e-4 and (mix / ml) or tang
					turn_cap = math.min(turn_cap, 18)
					decision = decision.."_gate"
				elseif tang then
					-- 高 path_err / 前瞻侧向时改“回线”(切线+横向)，禁止追 look 点绕圈
					local look_n = look_len > 1 and to_look:Normalized() or nil
					local look_align = look_n and look_n:Dot(tang) or 1
					local to_path = path_now - ent.Position
					local along = to_path:Dot(tang)
					local lateral = to_path - tang * along
					local lat_l = lateral:Length()
					local use_rejoin = (path_err > 28) or (look_align < 0.2) or (look_len < 10 and path_err > 16)
					local corr_w
					if use_rejoin then
						corr_w = math.min(0.32, path_err / 90)
						if lat_l > 0.8 then
							local mix = tang * (1 - corr_w) + (lateral / lat_l) * corr_w
							local ml = mix:Length()
							steer = ml > 1e-4 and (mix / ml) or tang
						else
							steer = tang
						end
						decision = decision.."_rejoin"
						if path_err > 36 then turn_cap = math.max(turn_cap, 36) end
					else
						corr_w = math.min(PASS_CORR_MAX, path_err / 55)
						if look_n and corr_w > 0.04 then
							local mix = tang * (1 - corr_w) + look_n * corr_w
							local ml = mix:Length()
							steer = ml > 1e-4 and (mix / ml) or tang
						else
							steer = tang
						end
						decision = decision..(corr_w > 0.16 and "_corr" or "_tang")
					end
				elseif look_len > 1 then
					steer = to_look:Normalized()
					decision = decision.."_look"
				elseif to_p2:Length() > 0.01 then
					steer = to_p2:Normalized()
					decision = decision.."_to_p2"
				else
					desired = Vector(0, 0)
					decision = "zero"
				end
			end

			if steer and pass.phase == "active" then
				spd = air_pass_limit_spd_delta(pass.prev_desired, spd, 2.4, 1.6)
				spd_used = spd
				desired = steer:Resized(spd)
				local prev_des = pass.prev_desired
				if desired and prev_des and prev_des:Length() > 0.35 and desired:Length() > 0.35 then
					local flip = pass_log_ang_deg(prev_des, desired)
					if flip and flip > turn_cap then
						if flip > 70 then pass._plog_raw_dturn = flip end
						-- 大翻折：贴切线前进，勿 22° 限转硬夹成圆轨道
						if flip > 85 then
							local tang2 = face or air_pass_tangent(pass, math.min(u, 1))
							if tang2 then
								desired = face_limit_turn(prev_des:Normalized(), tang2, math.max(turn_cap, 40)):Resized(spd)
								decision = decision.."_snap_tang"
							else
								desired = face_limit_turn(prev_des:Normalized(), desired:Normalized(), turn_cap):Resized(spd)
								decision = decision.."_clamp"
							end
						else
							desired = face_limit_turn(prev_des:Normalized(), desired:Normalized(), turn_cap):Resized(desired:Length())
							if flip > 40 then decision = decision.."_clamp" end
						end
					end
				end
				local warm = math.max(0, 1 - u * 8)
				if warm > 0 and pass.entry_vel and pass.entry_vel:Length() > 0.2 then
					desired = desired * (1 - 0.35 * warm) + pass.entry_vel * (0.35 * warm)
					decision = decision.."_warm"
				end
			elseif pass.phase == "active" and desired then
				spd_used = desired:Length()
			end

			-- 常规收束
			if pass.phase == "active" then
				if u >= 1 then
					pass.phase = "settle"
					pass.settle_t = 0
					air_pass_begin_cushion(d, pass, cur_alt)
					decision = "to_settle_u1"
				elseif u >= 0.92 and dist_end <= PASS_ARRIVE_DIST then
					pass.phase = "settle"
					pass.settle_t = 0
					air_pass_begin_cushion(d, pass, cur_alt)
					decision = "to_settle_u92"
				elseif past_end and dist_end > 56 and u >= 0.62 then
					pass.phase = "settle"
					pass.settle_t = 0
					air_pass_begin_cushion(d, pass, cur_alt)
					decision = "to_settle_past"
				elseif pass.t >= dur + PASS_TIMEOUT_EXTRA then
					pass.phase = "exit"
					pass.exit_t = 0
					local v = ent.Velocity or desired or Vector(0, 0)
					pass.exit_vel = v:Length() > 0.2 and v:Resized(math.min(2.8, v:Length())) or Vector(0, 0)
					pass.exit_alt = cur_alt
					pass.land_alt = cur_alt
					desired = pass.exit_vel
					decision = "to_exit_timeout"
					air_pass_begin_cushion(d, pass, cur_alt)
				end
			end
		end
	end

	local prev_des = pass.prev_desired
	local flip_ang = pass_log_ang_deg(prev_des, desired) or 0
	local clamped = false
	-- 复用 active 内已可能做过的 clamp 标记：从 decision 后缀识别
	if string.find(decision, "_clamp", 1, true) then
		clamped = true
	end
	pass.prev_desired = desired and Vector(desired.X, desired.Y) or pass.prev_desired
	if face then
		local prev = pass.face_dir
		if prev and prev:Length() > 0.01 then
			-- leap / 掠飞：更快跟上切线；过峰或 past_end 时再加快，减少掠过后贴图慢转
			local sm
			if pass.mode == "leap" then
				sm = (past_end or u >= PASS_PEAK_U) and 0.9 or 0.82
			elseif past_end or u >= PASS_PEAK_U then
				sm = 0.8
			else
				sm = 0.7
			end
			face = vec2_slerp(prev, face, sm)
		end
		pass.face_dir = face
	end

	local altitude = air_pass_altitude(math.min(1, math.max(0, u)), pass.phase, pass)

	d[item.own_key.."Passway"] = pass
	d[item.own_key.."PassU"] = math.min(1, math.max(0, u))

	do
		local perr = path_err
		local raw = tonumber(pass._plog_raw_dturn)
		pass._plog_raw_dturn = nil
		local dturn = flip_ang
		if raw and raw > dturn then dturn = raw end
		pass_log_on_tick(ent, pass, {
			t = pass.t,
			u = d[item.own_key.."PassU"],
			ph = pass.phase,
			dec = decision,
			dturn = dturn,
			spd = spd_used or (desired and desired:Length()) or 0,
			look = to_look:Length(),
			perr = perr,
			alt = altitude,
			phase_ch = phase0 ~= pass.phase,
			clamped = clamped,
			w = weight,
		})
	end

	return {
		velocity = desired or Vector(0, 0),
		weight = weight,
		altitude = altitude,
		facing = pass.face_dir,
		u = d[item.own_key.."PassU"],
		phase = pass.phase,
		decision = decision,
	}
end

local function air_try_passway(d, ent, center, form, move_spd, kind, force)
	local pass = d[item.own_key.."Passway"]
	if pass and pass.active then return end
	if kind == "form" then return end

	-- settle cooldown：普通 force 也不得绕过（由 blend 每帧递减）
	local settle_cd = tonumber(d[item.own_key.."PassSettleCD"]) or 0
	if settle_cd > 0 then
		return
	end

	local cd = tonumber(d[item.own_key.."PasswayCD"]) or 0
	if cd > 0 then
		d[item.own_key.."PasswayCD"] = cd - 1
		if not force then return end
		-- 攻击中：force 也尊重冷却；非攻击时 force 可绕过（远距追入）
		if d[item.own_key.."PassAttacking"] then return end
	end
	if not center then
		return
	end
	center = air_clamp_room_pos(center, 56)
	form = form or {}
	local off = ent.Position - center
	local dist = off:Length()
	local attacking = d[item.own_key.."PassAttacking"] == true
	local hr = air_hit_rate(d)

	-- 压制：保留掠飞，但默认更难进；主要靠 force（偏远）触发，盘旋中极少扫掠
	if kind == "pin" and not force then
		if dist < 100 then return end
		if ((ent.InitSeed or 1) + Game():GetFrameCount()) % 113 ~= 0 then return end
	end

	-- 滞回：进入阈值略严；force 需要更大距离且仍在远离
	local enter_dist = (kind == "idle") and 90 or ((kind == "pin") and 88 or 42)
	local force_dist = (kind == "idle") and 120 or ((kind == "pin") and 155 or 118)
	if attacking then
		-- 攻击中略降频率；命中越好越少掠（已略调回，勿接近 ban）
		if kind == "pin" then
			enter_dist = enter_dist * (1.12 + 0.28 * hr)
			force_dist = force_dist * (1.15 + 0.32 * hr)
		else
			enter_dist = enter_dist * (1.08 + 0.22 * hr)
			force_dist = force_dist * (1.1 + 0.28 * hr)
		end
	end
	if force then
		if dist < force_dist then
			return
		end
		local away = true
		local v = ent.Velocity or Vector(0, 0)
		if off:Length() > 1 and v:Length() > 0.4 then
			away = v:Dot(off:Normalized()) > -0.15
		end
		if not away then
			return
		end
	elseif dist < enter_dist then
		return
	end
	if air_near_room_edge(center, 88) and dist < 140 and force then
		return
	end
	if kind == "idle" and not force then
		if ((ent.InitSeed or 1) + Game():GetFrameCount()) % 17 ~= 0 then return end
	end
	-- 猎杀攻击中的定时 sweep：命中好少掠，命中差仍可改位
	if attacking and force and kind == "hunt" then
		if math.random() < (0.08 + 0.28 * hr) then
			return
		end
	end
	-- 压制 force：命中好时略否决，避免压点反复跳
	if attacking and force and kind == "pin" then
		if math.random() < (0.15 + 0.35 * hr) then
			return
		end
	end
	local radial = dist > 1 and (off / dist) or auxi.MakeVector(form.phase or 0)
	local orb_sign = d[item.own_key.."OrbSign"] or 1
	-- 有锁定敌人时：选更朝向敌人的切向，减少「头歪着爬升」
	local tgt = d[item.own_key.."Target"]
	if tgt and auxi.check_all_exists(tgt) and auxi.isenemies(tgt) then
		local to_e = tgt.Position - ent.Position
		if to_e:Length() > 1 then
			local en = to_e:Normalized()
			local tang_a = Vector(-radial.Y, radial.X)
			local tang_b = Vector(radial.Y, -radial.X)
			orb_sign = (tang_a:Dot(en) >= tang_b:Dot(en)) and 1 or -1
			d[item.own_key.."OrbSign"] = orb_sign
		end
	end
	local tang = Vector(-radial.Y, radial.X) * orb_sign
	local r
	if kind == "pin" then
		r = 62
	elseif kind == "idle" then
		r = 48
	else
		r = 90
	end
	r = r * (form.radius_mul or 1)
	if air_near_room_edge(center, 96) then
		r = r * 0.62
	end
	-- 半径相对距离封顶，避免 dist≈r 时走出半圆/整圈
	r = math.min(r, math.max(28, dist * 0.42))
	local pose_bias = form.pose_bias or 0
	if kind == "idle" then
		pose_bias = pose_bias * 0.35
	end
	-- idle 更倾向 leap，减少无目标长弧傻飘
	local leap = dist < ((kind == "idle") and (PASS_LEAP_DIST + 40) or PASS_LEAP_DIST)
	local mode = leap and "leap" or "arc"
	if leap then
		r = r * ((kind == "idle") and 0.72 or 0.58)
		if air_near_room_edge(center, 96) then
			r = r * 0.9
		end
	end
	local p1, p2 = air_pass_ideal_geometry(center, radial, tang, r, pose_bias)
	-- idle：终点略偏切向掠过，但保留足够对侧分量，避免远距冲线过早 past_end
	if kind == "idle" then
		p2 = center - radial * (r * 0.78) + tang * (r * 0.42 + 8)
	end
	p1 = air_clamp_room_pos(p1, 40)
	p2 = air_clamp_room_pos(p2, 40)
	local ahead = p1 - ent.Position
	local p0 = Vector(ent.Position.X, ent.Position.Y)
	if ahead:Length() > 1 then
		local push = leap and math.min(10, ahead:Length() * 0.35) or math.min(14, ahead:Length() * 0.25)
		p0 = p0 + ahead:Resized(push)
	end
	p0 = air_clamp_room_pos(p0, 36)
	local dur
	if leap then
		-- 短程小飞跃：更短时间轴，减少顶点空停
		dur = math.floor(16 + math.min(16, dist * 0.07) + ((form.index or 1) - 1) * 2)
		if kind == "idle" then
			dur = math.floor(dur * 0.85)
		end
	else
		-- 长弧：略收初始 dur（中途还会按剩余路径再压）
		dur = math.floor(24 + math.min(24, dist * 0.09) + ((form.index or 1) - 1) * 3)
		if kind == "idle" then
			dur = math.floor(dur * 0.9)
		end
	end
	local cd_next
	if kind == "idle" then
		cd_next = leap
			and (120 + ((ent.InitSeed or 1) % 60) + ((form.index or 1) - 1) * 10)
			or (160 + ((ent.InitSeed or 1) % 80) + ((form.index or 1) - 1) * 12)
	elseif kind == "pin" then
		-- 压制掠飞冷却加长，避免刚落地又跳
		cd_next = 80 + ((ent.InitSeed or 1) % 40) + ((form.index or 1) - 1) * 10
	elseif leap then
		cd_next = 22 + ((ent.InitSeed or 1) % 16) + ((form.index or 1) - 1) * 3
	else
		cd_next = 34 + ((ent.InitSeed or 1) % 28) + ((form.index or 1) - 1) * 5
	end
	if attacking then
		-- 攻击中掠飞后冷却略加长；命中越好冷却越长
		local mul = (kind == "pin") and (1.35 + 0.7 * hr) or (1.2 + 0.55 * hr)
		cd_next = math.floor(cd_next * mul)
	end
	local entry = ent.Velocity or Vector(0, 0)
	if entry:Length() < 2 * move_spd then
		entry = tang:Resized((leap and 8 or 6) * move_spd) + radial:Resized((leap and -1.2 or -2) * move_spd)
	elseif leap and entry:Length() < 5 * move_spd then
		entry = entry:Resized(math.max(entry:Length(), 6.5 * move_spd))
	end
	d[item.own_key.."Passway"] = {
		active = true,
		phase = "enter",
		t = 0,
		dur = dur,
		mode = mode,
		p0 = p0,
		p1 = p1,
		p2 = p2,
		cd_next = cd_next,
		entry_vel = entry,
		center = Vector(center.X, center.Y),
		approach_radial = Vector(radial.X, radial.Y),
		tang = Vector(tang.X, tang.Y),
		r = r,
		orb_sign = orb_sign,
		pose_bias = pose_bias,
		kind = kind,
		face_dir = nil,
		frozen = false,
		prev_desired = nil,
		attacking = attacking,
	}
	d[item.own_key.."PasswayCD"] = 0
	pass_log_on_start(ent, d[item.own_key.."Passway"], kind, force, dist, r, dur, move_spd)
end

local function air_blend_passway(d, ent, desired, center, form, move_spd, kind, force_start)
	local settle_cd = tonumber(d[item.own_key.."PassSettleCD"]) or 0
	if settle_cd > 0 then
		d[item.own_key.."PassSettleCD"] = settle_cd - 1
	end
	-- 仅护航禁止新掠飞；压制/猎杀走权重门控
	if kind == "form" then
		air_request_pass_exit(d)
	else
		air_try_passway(d, ent, center, form, move_spd, kind, force_start)
	end
	local intent = air_tick_passway(d, ent, move_spd, center)
	if intent and (intent.weight or 0) > 0 and intent.velocity then
		local w = intent.weight
		if w > 1 then w = 1 elseif w < 0 then w = 0 end
		-- 压制：掠飞权重略收，仍以盘旋为主
		if kind == "pin" then
			w = w * 0.92
		end
		desired = intent.velocity * w + desired * (1 - w)
		d[item.own_key.."PassDrive"] = w > 0.12
		d[item.own_key.."PassWeight"] = w
		d[item.own_key.."PassU"] = intent.u
		d[item.own_key.."PassAlt"] = (intent.altitude or 0) * w
		local pass = d[item.own_key.."Passway"]
		if pass and intent.facing then
			pass.face_dir = intent.facing
		end
		-- pending.w 用最终混合权重
		if pass and pass._plog_pending then
			pass._plog_pending.w = w
		end
	else
		d[item.own_key.."PassDrive"] = nil
		d[item.own_key.."PassWeight"] = 0
		local pa = tonumber(d[item.own_key.."PassAlt"]) or 0
		if pa > 0 then
			d[item.own_key.."PassAlt"] = pa * 0.82
			if d[item.own_key.."PassAlt"] < 0.02 then d[item.own_key.."PassAlt"] = 0 end
		end
	end
	return desired
end

local function air_blend_charge_output_hold(ent, d, desired)
	local ok, Charge = pcall(require, "Qing_Remaster_scripts.others.craft_charge_weapons")
	if not ok or not Charge then return desired end
	local hold = (Charge.get_move_hint and Charge.get_move_hint(ent))
		or (Charge.get_output_hold and Charge.get_output_hold(ent))
	if not hold then return desired end
	local pass_w = tonumber(d[item.own_key.."PassWeight"]) or 0

	-- 虚空环：朝环内理想距加性补速（理想约 0.4R，非贴边）
	if hold.mode == "maw_chase" and hold.toward then
		local over = math.max(0, tonumber(hold.overshoot) or 0)
		local boost_base = tonumber(hold.boost_base) or 3.2
		local boost_per = tonumber(hold.boost_per) or 0.32
		local boost_cap = tonumber(hold.boost_cap) or 12
		local boost = math.min(boost_cap, boost_base + over * boost_per)
		local along = desired:Dot(hold.toward)
		local need = math.max(0, boost - math.max(0, along))
		local out = desired + hold.toward * need
		d[item.own_key.."maw_pose"] = {
			frame = Game():GetFrameCount(),
			mode = "maw_chase",
			overshoot = over,
			ideal = hold.ideal,
			boost = boost,
			need = need,
			along = along,
			des_in_len = desired:Length(),
			des_out_len = out:Length(),
			vel_len = (ent.Velocity and ent.Velocity:Length()) or 0,
		}
		return out
	end

	-- 启示等：软刹向释放点
	local hw = tonumber(hold.weight) or 0.55
	if pass_w > 0.35 then
		hw = hw * (1 - math.min(1, (pass_w - 0.35) / 0.65) * 0.85)
	end
	if hw < 0.05 then return desired end
	local settle = tonumber(hold.settle) or 10
	local pos = hold.pos
	if not pos then return desired end
	local to = pos - ent.Position
	local hold_vel
	if to:Length() <= settle then
		hold_vel = Vector(0, 0)
	else
		hold_vel = to:Resized(math.min(4.5, 0.18 * to:Length()))
	end
	local out = desired * (1 - hw) + hold_vel * hw
	d[item.own_key.."maw_pose"] = {
		frame = Game():GetFrameCount(),
		mode = hold.mode or "anchor",
		hw = hw,
		des_in_len = desired:Length(),
		des_out_len = out:Length(),
		vel_len = (ent.Velocity and ent.Velocity:Length()) or 0,
	}
	if hold.face and hold.face:Length() >= 0.01 then
		local face = hold.face:Normalized()
		local cur = d[item.own_key.."FaceU"] or face
		if cur:Length() < 0.01 then cur = face end
		local blended = cur:Normalized() * (1 - 0.35 * hw) + face * (0.35 * hw)
		if blended:Length() >= 0.01 then
			blended = blended:Normalized()
			d[item.own_key.."FaceU"] = blended
			d[item.own_key.."RotDir"] = blended
		end
	end
	return out
end

--- 土星/无暇自管环绕泪：轻微补速，把敌人放到轨道附近以便扫中
local function air_blend_orbit_move_hint(ent, d, desired)
	local ok, Orbit = pcall(require, "Qing_Remaster_scripts.others.craft_orbiting_tears")
	if not ok or not Orbit or not Orbit.get_move_hint then return desired end
	local hold = Orbit.get_move_hint(ent)
	if not hold or hold.mode ~= "saturn_cover" or not hold.toward then return desired end
	local over = math.max(0, tonumber(hold.overshoot) or 0)
	local boost_base = tonumber(hold.boost_base) or 1.6
	local boost_per = tonumber(hold.boost_per) or 0.18
	local boost_cap = tonumber(hold.boost_cap) or 5.5
	local boost = math.min(boost_cap, boost_base + over * boost_per)
	local along = desired:Dot(hold.toward)
	local need = math.max(0, boost - math.max(0, along))
	return desired + hold.toward * need
end

local function air_apply_move(ent, d, desired, response)
	local w = d and tonumber(d[item.own_key.."PassWeight"]) or 0
	local vel0 = ent.Velocity or Vector(0, 0)
	if w > 0.12 then
		-- 掠飞响应略收，减轻追点过冲画圈
		response = math.max(response or 0.2, 0.34 + 0.08 * w)
	end
	desired = air_blend_charge_output_hold(ent, d, desired)
	desired = air_blend_orbit_move_hint(ent, d, desired)
	air_soft_velocity(ent, desired, response)
	if w > 0.05 then
		pass_log_on_apply(ent, d, desired, response, vel0, ent.Velocity or Vector(0, 0))
	end
end

-- Idle/护航定式：Lissajous 轻荡，比频繁掠飞更稳更美观
local function air_idle_sway_velocity(pos, center, form, move_spd, amp_mul)
	form = form or {}
	amp_mul = amp_mul or 1
	local t = Game():GetFrameCount() * 0.028 * (form.spin_bias or 1)
	local seed = (form.phase or 0) * 0.017 + (form.index or 1) * 1.3
	local ax = 20 * (form.radius_mul or 1) * amp_mul
	local ay = 12 * (form.radius_mul or 1) * amp_mul
	local slot = center + Vector(
		math.sin(t + seed) * ax,
		math.sin(t * 2 + seed * 0.7) * ay
	)
	local to = slot - pos
	return to:Resized(math.min(2.8 * move_spd, 1.2 + to:Length() * 0.16))
end

-- 按弹速预瞄，减少被高速怪遛
local function air_predict_aim(from_pos, tgt_pos, tgt_vel, shot_speed)
	shot_speed = math.max(tonumber(shot_speed) or 10, 1)
	tgt_vel = tgt_vel or Vector(0, 0)
	local dist = (tgt_pos - from_pos):Length()
	local tta = dist / shot_speed
	local pred = tgt_pos + tgt_vel * math.min(tta, 48)
	dist = (pred - from_pos):Length()
	tta = dist / shot_speed
	return tgt_pos + tgt_vel * math.min(tta * 1.08, 56)
end

local function air_pick_enemy(from_pos, max_range)
	local sel = auxi.get_nearest_enemy(nil, from_pos)
	if sel and (sel.Position - from_pos):Length() <= max_range then
		return sel
	end
	return nil
end

local function air_craft_uid(ent)
	local bp = get_blueprint()
	return ent and ent:GetData()[bp.own_key.."craft_uid"]
end

local function air_formation_at(ent, idx, n)
	n = math.max(n or 1, 1)
	idx = idx or 1
	local seed = (ent and ent.InitSeed) or (idx * 97)
	local phase = (idx - 1) * (360 / n)
	phase = phase + ((seed % 1000) / 1000 - 0.5) * math.min(36, 120 / math.max(n, 1))
	local radius_mul = 0.82 + ((seed % 9) / 9) * 0.4
	local pose_bias = ((seed % 200) / 200) * 2 - 1
	local spin_bias = ((seed % 17) / 17) * 0.6 + 0.7
	return {
		index = idx,
		count = n,
		phase = phase,
		radius_mul = radius_mul,
		pose_bias = pose_bias,
		spin_bias = spin_bias,
	}
end

local function air_formation_from_list(list, ent)
	list = list or {}
	local n = #list
	local idx = 1
	local self_hash = GetPtrHash(ent)
	for i = 1, n do
		if GetPtrHash(list[i]) == self_hash then
			idx = i
			break
		end
	end
	return air_formation_at(ent, idx, n)
end

local AIR_FORM_FRAME = -1
local AIR_FORM_BY_OWNER = {}

local function sort_airs_by_craft_order(list, order_index)
	table.sort(list, function(a, b)
		local ua, ub = air_craft_uid(a), air_craft_uid(b)
		local ia = ua and order_index[tostring(ua)]
		local ib = ub and order_index[tostring(ub)]
		if ia and ib then
			if ia ~= ib then return ia < ib end
		elseif ia then
			return true
		elseif ib then
			return false
		end
		return (a.InitSeed or 0) < (b.InitSeed or 0)
	end)
end

local function rebuild_air_formation_frame()
	local frame = Game():GetFrameCount()
	if AIR_FORM_FRAME == frame then return end
	AIR_FORM_FRAME = frame
	AIR_FORM_BY_OWNER = {}
	local buckets = {}
	for _, e in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, item.familiar, -1, false, false)) do
		local fam = e:ToFamiliar()
		if fam and auxi.check_all_exists(fam) then
			local owner = auxi.check_spawner_player(fam)
			if owner then
				local op = GetPtrHash(owner)
				local b = buckets[op]
				if not b then
					b = {player = owner, list = {}}
					buckets[op] = b
				end
				b.list[#b.list + 1] = fam
			end
		end
	end
	local BW = get_bandwidth()
	for op, b in pairs(buckets) do
		local player = b.player
		local is_spwq = player:GetPlayerType() == player_Spwq.entity
		local snap = is_spwq and BW.get_snapshot(player) or nil
		local order_index = {}
		if snap then
			for i, uid in ipairs(snap.order or {}) do
				order_index[tostring(uid)] = i
			end
		end
		local active, standby = {}, {}
		for i = 1, #b.list do
			local fam = b.list[i]
			local uid = air_craft_uid(fam)
			local is_sb = is_spwq and uid ~= nil and snap and snap.effective_active[tostring(uid)] ~= true
			if is_sb then
				standby[#standby + 1] = fam
			else
				active[#active + 1] = fam
			end
		end
		if snap then
			sort_airs_by_craft_order(active, order_index)
			sort_airs_by_craft_order(standby, order_index)
		else
			table.sort(active, function(a, c) return (a.InitSeed or 0) < (c.InitSeed or 0) end)
			table.sort(standby, function(a, c) return (a.InitSeed or 0) < (c.InitSeed or 0) end)
		end
		local active_form, standby_form = {}, {}
		for i = 1, #active do
			active_form[GetPtrHash(active[i])] = air_formation_at(active[i], i, #active)
		end
		for i = 1, #standby do
			standby_form[GetPtrHash(standby[i])] = air_formation_at(standby[i], i, #standby)
		end
		AIR_FORM_BY_OWNER[op] = {
			active_form = active_form,
			standby_form = standby_form,
		}
	end
end

local function get_air_form(player, ent, want_standby)
	rebuild_air_formation_frame()
	local pack = player and AIR_FORM_BY_OWNER[GetPtrHash(player)]
	local ptr = GetPtrHash(ent)
	local form = pack and ((want_standby == true) and pack.standby_form[ptr] or pack.active_form[ptr])
	if form then return form end
	return air_formation_at(ent, 1, 1)
end

local function air_guard_aim_dir(player, mark_pos, last_aim)
	local v = mark_pos - player.Position
	if v:Length() < 28 then
		if last_aim and last_aim:Length() > 0.01 then
			return last_aim:Normalized()
		end
		return Vector(0, 1)
	end
	return v:Normalized()
end

local function air_pick_enemy_guard(player, mark_pos, last_aim, max_range)
	local origin = player.Position
	local axis = air_guard_aim_dir(player, mark_pos, last_aim)
	local best, best_d = nil, max_range
	for _, npc in ipairs(auxi.getenemies()) do
		if auxi.check_all_exists(npc) then
			local off = npc.Position - origin
			local dist = off:Length()
			if dist > 0.01 and dist <= max_range then
				if off:Normalized():Dot(axis) >= 0.5 then
					if dist < best_d then
						best = npc
						best_d = dist
					end
				end
			end
		end
	end
	return best
end

local function air_apply_rear_wing_move(ent, d, player, face, form, move_spd, pass_tag)
	local orb_sign = d[item.own_key.."OrbSign"] or 1
	local rear_center = player.Position - face * (48 + form.radius_mul * 8)
	local orbit_r = 30 + 6 * (form.count - 1)
	local desired = air_orbit_slot_velocity(ent.Position, rear_center, orbit_r, orb_sign, move_spd, form, 1.7)
	local to_rear = rear_center - ent.Position
	if to_rear:Length() > orbit_r + 40 then
		desired = desired * 0.35 + to_rear:Resized(math.min(9 * move_spd, to_rear:Length() * 0.2))
	end
	desired = air_blend_passway(d, ent, desired, rear_center, form, move_spd, pass_tag or "form", false)
	air_apply_move(ent, d, desired, 0.22)
end

local function air_apply_cruise_move(ent, d, player, mark_pos, mark_alive, form, move_spd, engage_enemy)
	local orb_sign = d[item.own_key.."OrbSign"] or 1
	local move_anchor = mark_alive and mark_pos or player.Position
	if engage_enemy and auxi.check_all_exists(engage_enemy) then
		d[item.own_key.."PassAttacking"] = true
		local ev = engage_enemy.Velocity or Vector(0, 0)
		local orbit_center = engage_enemy.Position + ev * 6
		local orbit_r = 104
		local dist = (ent.Position - engage_enemy.Position):Length()
		local desired = air_orbit_slot_velocity(ent.Position, orbit_center, orbit_r, orb_sign, move_spd, form, 2.4)
		local force_pass = dist > 118
		if force_pass then
			desired = (orbit_center - ent.Position):Resized(math.min(10 * move_spd, dist * 0.16))
				+ auxi.MakeVector(form.phase) * (2 * move_spd)
		end
		local orbit_sweep = (not force_pass) and ((Game():GetFrameCount() + (ent.InitSeed or 0)) % 90 == (form.index or 0) % 90)
		desired = air_blend_passway(d, ent, desired, orbit_center, form, move_spd, "hunt", force_pass or orbit_sweep)
		air_apply_move(ent, d, desired, 0.28)
	else
		d[item.own_key.."PassAttacking"] = false
		local orbit_r = 80 + 10 * (form.count - 1)
		local desired = air_orbit_slot_velocity(ent.Position, move_anchor, orbit_r, orb_sign, move_spd, form, 2.6)
		local off = ent.Position - move_anchor
		if off:Length() < orbit_r * 0.4 then
			local kick = (off:Length() > 0.01) and Vector(-off.Y, off.X):Resized(5 * move_spd) or auxi.MakeVector(form.phase) * (5 * move_spd)
			desired = desired + kick
		end
		desired = air_blend_passway(d, ent, desired, move_anchor, form, move_spd, "idle", false)
		air_apply_move(ent, d, desired, 0.3)
	end
end

local function air_pick_cruise_enemy(ent, d, move_anchor, engage_range)
	local enemy = d[item.own_key.."Target"]
	if not (auxi.check_all_exists(enemy) and auxi.isenemies(enemy)) then
		enemy = air_pick_enemy(move_anchor, engage_range)
		d[item.own_key.."Target"] = enemy
	else
		local nearer = air_pick_enemy(ent.Position, engage_range)
		if nearer and (nearer.Position - ent.Position):Length() + 40 < (enemy.Position - ent.Position):Length() then
			enemy = nearer
			d[item.own_key.."Target"] = enemy
		elseif (enemy.Position - move_anchor):Length() > engage_range * 1.25 then
			enemy = air_pick_enemy(move_anchor, engage_range)
			d[item.own_key.."Target"] = enemy
		end
	end
	return enemy
end

local STANDBY_COLOR_KEY = "StandbyColorSaved"

local function air_combat_stop_for_standby(ent, d)
	air_clear_passway(d)
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
	d[item.own_key.."AuxAttackQueue"] = nil
	d[item.own_key.."anemic_active"] = nil
	d[item.own_key.."anemic_room"] = nil
	if Craft_Ludovico_holder and Craft_Ludovico_holder.release then
		Craft_Ludovico_holder.release(ent)
	end
	if auxi.check_all_exists(d[item.own_key.."Tech2"]) then
		d[item.own_key.."Tech2"]:SetTimeout(1)
	end
	d[item.own_key.."Tech2"] = nil
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
	if sig ~= last_sig or frame >= next_check then
		d[item.own_key.."companion_sync_sig"] = sig
		d[item.own_key.."companion_sync_next"] = frame + 15
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
			local Aux = require("Qing_Remaster_scripts.mimics.Craft_Aux_Entities_holder")
			if Aux and Aux.clear_for_air and not craft_prof then
				Aux.clear_for_air(ent)
			end
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	-- 里小青默认 getQingshots / Air Flight x2 / Spwq.cnt 加成已拆除，待重做。
	if cacheFlag == CacheFlag.CACHE_FAMILIARS then
		local bp = get_blueprint()
		local cnt = (bp and bp.familiar_check_count and bp.familiar_check_count(player, item.entity))
			or player:GetCollectibleNum(item.entity)
		player:CheckFamiliar(item.familiar, cnt, player:GetCollectibleRNG(item.entity), Isaac.GetItemConfig():GetCollectible(item.entity))
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_INIT, params = item.familiar,
Function = function(_,ent)
	local player = auxi.check_spawner_player(ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	d[item.own_key.."VLean"] = 0
	d[item.own_key.."VApproach"] = 0
	d[item.own_key.."Pitch"] = ((ent.InitSeed or 1) % 100) / 100 * 0.3 - 0.15
	d[item.own_key.."FaceU"] = nil
	d[item.own_key.."FaceUPrev"] = nil
	d[item.own_key.."RotDir"] = nil
	d[item.own_key.."FrameF"] = nil
	d[item.own_key.."Flourish"] = nil
	d[item.own_key.."AimU"] = nil
	d[item.own_key.."OffsetZ"] = nil
	d[item.own_key.."Passway"] = nil
	d[item.own_key.."PasswayCD"] = ((ent.InitSeed or 1) % 20)
	d[item.own_key.."PassAlt"] = 0
	d[item.own_key.."PassWeight"] = 0
	d[item.own_key.."PassSettleCD"] = 0
	d[item.own_key.."PassDrive"] = nil
	d[item.own_key.."PassU"] = nil
	d[item.own_key.."Rang"] = 0
	d[item.own_key.."OrbSign"] = ((ent.InitSeed or 1) % 2 == 0) and 1 or -1
	d[item.own_key.."PatrolAng"] = (ent.InitSeed or 0) % 360
	apply_air_aim_visual(ent, s, d, Vector(0, 1), false, {pose_bias = ((ent.InitSeed or 1) % 200) / 100 - 1})
	ent.State = 0
	if player then bind_craft_profile(ent, player) end
end,
})

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

local function stamp_craft_source(ent2, air, opts)
	opts = opts or {}
	if not ent2 then return end
	local td = ent2:GetData()
	td[item.own_key.."craft_air"] = air
	td[item.own_key.."craft_uid"] = air and air:GetData()[get_blueprint().own_key.."craft_uid"]
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
		local bp = get_blueprint()
		local uid = d[bp.own_key.."craft_uid"]
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

-- 制造飞行器坠毁：fail→fall→impact→tumble→revive/dead
-- 自管高度与朝向；坠毁中禁止走 apply_air_aim_visual。
-- 复活账本见 CraftProfile.CRAFT_REVIVE_*；视觉参数见 item.crash_fx。
-- 方案：codex_work/notes/air_flight_crash_visual_design.md

local CRASH_FX_DEFAULTS = {
	fail_frames = 7,
	gravity = 0.38,
	max_fall_speed = 7.5,
	drift_retain = 0.985,
	side_slip_max = 1.8,
	fall_smoke_interval = 5,
	tumble_friction = 0.90,
	tumble_max_frames = 24,
	impact_dust_count = 8,
	dead_smoke_min = 18,
	dead_smoke_max = 30,
	screen_shake = 4,
	particle_cap = 10,
	fail_z_vel_target = 1.2,
	impact_frames = 6,
	revive_frames = 14,
	margin = 20,
}

item.crash_fx = item.crash_fx or {}

local function crash_fx_get(key)
	local override = item.crash_fx[key]
	if override ~= nil then return override end
	local root = save.ModConfigSettings
	local debug_settings = root and root.QingRemasterOptions and root.QingRemasterOptions.Debug
	local cfg_key = "FlightCrash_" .. tostring(key)
	local from_cfg = debug_settings and debug_settings[cfg_key]
	if from_cfg ~= nil then return from_cfg end
	return CRASH_FX_DEFAULTS[key]
end

function item.crash_fx_restore_defaults()
	for k, v in pairs(CRASH_FX_DEFAULTS) do
		item.crash_fx[k] = v
		local root = save.ModConfigSettings
		if root and root.QingRemasterOptions and root.QingRemasterOptions.Debug then
			root.QingRemasterOptions.Debug["FlightCrash_" .. k] = v
		end
	end
end

local function air_crash_fx_list(d)
	d[item.own_key.."CrashFx"] = d[item.own_key.."CrashFx"] or {}
	return d[item.own_key.."CrashFx"]
end

local function air_crash_prune_fx(d)
	local list = air_crash_fx_list(d)
	local kept = {}
	for i = 1, #list do
		local fx = list[i]
		if auxi.check_all_exists(fx) then
			kept[#kept + 1] = fx
		end
	end
	d[item.own_key.."CrashFx"] = kept
	return kept
end

local function air_crash_cleanup_fx(d)
	if not d then return end
	local list = air_crash_fx_list(d)
	for i = 1, #list do
		local fx = list[i]
		if auxi.check_all_exists(fx) then
			fx:Remove()
		end
	end
	d[item.own_key.."CrashFx"] = {}
end

local function air_crash_stop_normal_trail(ent, d)
	local trail = d[item.own_key.."Trail"]
	if auxi.check_all_exists(trail) then
		trail.Parent = nil
		trail:Remove()
	end
	d[item.own_key.."Trail"] = nil
	d[item.own_key.."TrailSuppress"] = true
end

local function air_crash_rng(ent, crash, salt)
	crash.fx_serial = (tonumber(crash.fx_serial) or 0) + 1
	local rng = RNG()
	local seed = (ent.InitSeed or 1) + crash.fx_serial * 1103515245 + (salt or 0)
	seed = math.floor(seed % 2147483647)
	if seed <= 0 then seed = seed + 2147483646 end
	rng:SetSeed(seed, 35)
	return rng
end

local function air_crash_can_spawn(d)
	local list = air_crash_prune_fx(d)
	local cap = tonumber(crash_fx_get("particle_cap")) or 10
	return #list < cap, list
end

local function air_crash_track(d, fx)
	if not fx then return end
	local list = air_crash_fx_list(d)
	list[#list + 1] = fx
end

local function air_crash_spawn_smoke(ent, d, crash, kind)
	local ok = air_crash_can_spawn(d)
	if not ok then return nil end
	local rng = air_crash_rng(ent, crash, kind == "dead" and 77 or (kind == "fall" and 33 or 11))
	-- 视觉烟：DUST_CLOUD（59）。勿用 SMOKE_CLOUD（毒气伤）/ DARK_BALL_SMOKE（黑球粒子）。
	-- 参考 Reverie/Epiphany：必须同时设 LifeSpan + Timeout。
	local variant = EffectVariant.DUST_CLOUD or EffectVariant.POOF02 or EffectVariant.POOF01
	local face = crash.face or Vector(0, 1)
	local back = Vector(-face.X, -face.Y)
	if back:Length() < 0.01 then back = Vector(0, 1) end
	back = back:Normalized():Resized(3 + rng:RandomFloat() * 5)
	local pos = ent.Position + back
	local drift = Vector(
		(rng:RandomFloat() - 0.5) * 0.6,
		-0.2 - rng:RandomFloat() * 0.35
	)
	-- Spawner 用 nil，避免跟随飞行器 PositionOffset 把烟抬飞
	local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, variant, 0, pos, drift, nil)
	if not fx then return nil end
	fx = fx:ToEffect() or fx
	local scale = 0.65
	local life = 14
	if kind == "fail" then
		scale = 0.55 + rng:RandomFloat() * 0.2
		life = 10 + rng:RandomInt(6)
		fx:SetColor(Color(0.45, 0.45, 0.48, 0.7, 0, 0, 0), -1, 0)
	elseif kind == "fall" then
		scale = 0.7 + rng:RandomFloat() * 0.25
		life = 12 + rng:RandomInt(8)
		fx:SetColor(Color(0.5, 0.38, 0.35, 0.75, 0.05, 0, 0), -1, 0)
	elseif kind == "revive" then
		scale = 0.4 + rng:RandomFloat() * 0.2
		life = 8 + rng:RandomInt(6)
		fx:SetColor(Color(0.7, 0.95, 0.8, 0.5, 0, 0.08, 0.04), -1, 0)
		fx.Velocity = Vector((rng:RandomFloat() - 0.5) * 0.4, 0.5 + rng:RandomFloat() * 0.5)
	else -- dead：低频残骸烟
		scale = 0.65 + rng:RandomFloat() * 0.3
		life = 20 + rng:RandomInt(12)
		fx:SetColor(Color(0.4, 0.4, 0.42, 0.55, 0, 0, 0), -1, 0)
	end
	fx.SpriteScale = Vector(scale, scale)
	if fx.LifeSpan ~= nil then fx.LifeSpan = life end
	if fx.Timeout ~= nil then fx.Timeout = life end
	fx.DepthOffset = -30
	air_crash_track(d, fx)
	return fx
end

local function air_crash_spawn_sparks(ent, d, crash, count)
	count = math.max(1, math.floor(tonumber(count) or 4))
	local rng = air_crash_rng(ent, crash, 91)
	local face = crash.face or Vector(0, 1)
	local back = Vector(-face.X, -face.Y)
	if back:Length() < 0.01 then back = Vector(0, 1) end
	back = back:Normalized()
	-- 碎屑/火花：小 poof，勿用泪弹消失特效
	local variant = EffectVariant.BULLET_POOF or EffectVariant.POOF01
	for i = 1, count do
		local ok = air_crash_can_spawn(d)
		if not ok then break end
		local ang = (rng:RandomFloat() * 70 - 35)
		local dir = back:Rotated(ang):Resized(2.2 + rng:RandomFloat() * 2.5)
		local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, variant, 0, ent.Position, dir, nil)
		if fx then
			fx = fx:ToEffect() or fx
			fx:SetColor(Color(1, 0.7, 0.3, 0.85, 0.15, 0.04, 0), -1, 0)
			fx.SpriteScale = Vector(0.4 + rng:RandomFloat() * 0.2, 0.4)
			local life = 8 + rng:RandomInt(8)
			if fx.LifeSpan ~= nil then fx.LifeSpan = life end
			if fx.Timeout ~= nil then fx.Timeout = life end
			air_crash_track(d, fx)
		end
	end
end

local function air_crash_spawn_impact_dust(ent, d, crash)
	local n = math.floor(tonumber(crash_fx_get("impact_dust_count")) or 8)
	local rng = air_crash_rng(ent, crash, 55)
	-- 接地大团：POOF02（常见尘爆）；径向：DUST_CLOUD
	local core_var = EffectVariant.POOF02 or EffectVariant.ROCK_POOF or EffectVariant.POOF01
	local ok = air_crash_can_spawn(d)
	if ok then
		-- subtype 1：多数模组用作落地/受击尘团
		local core = Isaac.Spawn(EntityType.ENTITY_EFFECT, core_var, 1, ent.Position, Vector.Zero, nil)
		if core then
			core = core:ToEffect() or core
			core.SpriteScale = Vector(1.05, 1.05)
			local life = 16
			if core.LifeSpan ~= nil then core.LifeSpan = life end
			if core.Timeout ~= nil then core.Timeout = life end
			air_crash_track(d, core)
		end
	end
	local dust = EffectVariant.DUST_CLOUD or EffectVariant.POOF01
	for i = 1, n do
		ok = air_crash_can_spawn(d)
		if not ok then break end
		local ang = (360 / n) * (i - 1) + rng:RandomFloat() * 12
		local dir = auxi.MakeVector(ang):Resized(1.4 + rng:RandomFloat() * 2.0)
		local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, dust, 0, ent.Position, dir, nil)
		if fx then
			fx = fx:ToEffect() or fx
			fx:SetColor(Color(0.55, 0.5, 0.42, 0.8, 0, 0, 0), -1, 0)
			local sc = 0.5 + rng:RandomFloat() * 0.3
			fx.SpriteScale = Vector(sc, sc)
			local life = 12 + rng:RandomInt(8)
			if fx.LifeSpan ~= nil then fx.LifeSpan = life end
			if fx.Timeout ~= nil then fx.Timeout = life end
			fx.DepthOffset = -20
			air_crash_track(d, fx)
		end
	end
end

local function air_crash_safe_steer(ent, crash, room)
	if not room then return Vector(0, 0) end
	local margin = tonumber(crash_fx_get("margin")) or 20
	local z = math.abs(tonumber(crash.z) or 0)
	local zv = math.max(0.4, tonumber(crash.z_vel) or 1)
	local remaining = math.max(1, math.ceil(z / zv))
	local predicted = ent.Position + (ent.Velocity or Vector.Zero) * remaining
	local clamped = room:GetClampedPosition(predicted, margin)
	local free = room:FindFreePickupSpawnPosition(clamped, 10, true)
	if not free then return Vector(0, 0) end
	if (free - predicted):Length() <= 10 then return Vector(0, 0) end
	local to_safe = free - ent.Position
	if to_safe:Length() < 1 then return Vector(0, 0) end
	return to_safe:Normalized() * 0.4
end

local function air_crash_clamp_tumble(ent, room)
	if not room then return end
	local margin = tonumber(crash_fx_get("margin")) or 20
	local before = ent.Position
	local clamped = room:GetClampedPosition(before, margin)
	if (clamped - before):Length() > 0.5 then
		local push = clamped - before
		local vel = ent.Velocity or Vector.Zero
		-- 削去朝墙外的法向分量，保留切向
		if push:Length() > 0.01 and vel:Length() > 0.01 then
			local n = push:Normalized()
			local into = (vel.X * (-n.X) + vel.Y * (-n.Y))
			if into > 0 then
				vel = vel + n * into
			end
			ent.Velocity = vel * 0.85
		end
		ent.Position = clamped
	end
end

local function air_begin_crash(ent, d)
	if d[item.own_key.."Crash"] then return end
	local face = d[item.own_key.."RotDir"] or d[item.own_key.."FaceU"] or ent.Velocity
	if not face or face:Length() < 0.01 then face = Vector(0, 1) end
	face = face:Normalized()
	local z = tonumber(d[item.own_key.."OffsetZ"])
	if z == nil then
		z = (ent.PositionOffset and ent.PositionOffset.Y) or AIR_AIM_VIS.base_offset
	end
	local spin = (((ent.InitSeed or 1) % 2 == 0) and 1) or -1
	local drift = Vector((ent.Velocity and ent.Velocity.X) or 0, (ent.Velocity and ent.Velocity.Y) or 0)
	d[item.own_key.."Crash"] = {
		phase = "fail",
		t = 0,
		phase_t = 0,
		face = Vector(face.X, face.Y),
		spin = spin,
		start_z = z,
		z = z,
		z_vel = 0,
		gravity = tonumber(crash_fx_get("gravity")) or 0.38,
		max_fall_speed = tonumber(crash_fx_get("max_fall_speed")) or 7.5,
		drift_vel = drift,
		roll_vel = Vector(0, 0),
		roll_angle = 0,
		roll_speed = 4 * spin,
		smoke_cd = 0,
		fx_serial = 0,
		final_rotation = nil,
		impact_done = false,
	}
	air_crash_stop_normal_trail(ent, d)
	air_clear_passway(d)
	d[item.own_key.."Flourish"] = nil
	d[item.own_key.."AuxAimDirection"] = nil
	d[item.own_key.."AuxAimPos"] = nil
	d[item.own_key.."AuxShouldShoot"] = false
	d[item.own_key.."cursed_queue"] = nil
	d[item.own_key.."kidney_cooldown"] = nil
	d[item.own_key.."kidney_block_frames"] = nil
	d[item.own_key.."kidney_burst_remaining"] = nil
	d[item.own_key.."kidney_burst_tick"] = nil
	d[item.own_key.."kidney_release"] = nil
	d[item.own_key.."kidney_active"] = nil
	if Craft_Ludovico_holder and Craft_Ludovico_holder.release then
		Craft_Ludovico_holder.release(ent)
	end
	if auxi.check_all_exists(d[item.own_key.."Tech2"]) then
		d[item.own_key.."Tech2"]:SetTimeout(1)
	end
	d[item.own_key.."Tech2"] = nil
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
	d[item.own_key.."FaceU"] = face
	d[item.own_key.."RotDir"] = face
	d[item.own_key.."AimU"] = face
	d[item.own_key.."AimSm"] = face
	if SoundEffect.SOUND_THUMBS_DOWN then
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBS_DOWN, 0.85, 0.85, false, 0, 2)
	end
end

local function air_tick_crash(ent, s, d, opts)
	local crash = d[item.own_key.."Crash"]
	if type(crash) ~= "table" then return "none" end
	local room = Game():GetRoom()
	crash.t = (tonumber(crash.t) or 0) + 1
	crash.phase_t = (tonumber(crash.phase_t) or 0) + 1
	local face = crash.face or Vector(0, 1)
	local spin = crash.spin or 1
	local yaw0 = AIR_AIM_VIS.yaw_art_offset or -90
	local function paint_sprite(extra_deg)
		if not s then return end
		s.PlaybackSpeed = 0
		if s.SetFrame then
			s:SetFrame(AIR_AIM_VIS.anim, AIR_AIM_VIS.out_frame or 2)
		end
		s.Rotation = face:GetAngleDegrees() + yaw0 + (extra_deg or 0)
		s.FlipX = false
		s.FlipY = false
	end

	local function set_phase(name)
		crash.phase = name
		crash.phase_t = 0
	end

	-- ---- fail：失控预备 ----
	if crash.phase == "fail" then
		local fail_n = math.max(4, math.floor(tonumber(crash_fx_get("fail_frames")) or 7))
		local u = math.min(1, crash.phase_t / fail_n)
		local z_target = tonumber(crash_fx_get("fail_z_vel_target")) or 1.2
		crash.z_vel = z_target * u
		crash.z = (tonumber(crash.z) or crash.start_z or AIR_AIM_VIS.base_offset) + crash.z_vel * 0.35
		local retain = 0.8 + 0.2 * (1 - u)
		local drift = crash.drift_vel or Vector(0, 0)
		local yaw = face:Rotated(spin * u * 8)
		local desired = drift * retain + yaw:Resized(drift:Length() * 0.05 * u)
		ent.Velocity = (ent.Velocity or Vector.Zero) * 0.85 + desired * 0.15
		local shake = math.sin(crash.t * (1.2 + u * 2.2)) * (0.8 + u * 1.5)
		d[item.own_key.."OffsetZ"] = math.min(0, crash.z)
		d[item.own_key.."PassAlt"] = 0
		ent.PositionOffset = Vector(shake, d[item.own_key.."OffsetZ"])
		local pulse = (crash.t % math.max(2, math.floor(5 - u * 3)) < 2) and (0.2 + u * 0.25) or 0.08
		ent:SetColor(Color(1, 0.25, 0.25, 1, pulse, 0, 0), 2, 60, false, false)
		crash.roll_angle = (tonumber(crash.roll_angle) or 0) + crash.roll_speed * 0.35
		paint_sprite(crash.roll_angle)
		d[item.own_key.."FaceU"] = face
		d[item.own_key.."RotDir"] = face
		if crash.phase_t == 1 then
			air_crash_spawn_smoke(ent, d, crash, "fail")
			air_crash_spawn_sparks(ent, d, crash, 3)
		end
		if crash.phase_t >= fail_n then
			set_phase("fall")
		end
		return "busy"

	-- ---- fall：惯性螺旋下坠 ----
	elseif crash.phase == "fall" then
		local grav = tonumber(crash.gravity) or tonumber(crash_fx_get("gravity")) or 0.38
		local vmax = tonumber(crash.max_fall_speed) or tonumber(crash_fx_get("max_fall_speed")) or 7.5
		crash.z_vel = math.min(vmax, (tonumber(crash.z_vel) or 0) + grav)
		crash.z = math.min(0, (tonumber(crash.z) or AIR_AIM_VIS.base_offset) + crash.z_vel)
		local retain = tonumber(crash_fx_get("drift_retain")) or 0.985
		local slip_max = tonumber(crash_fx_get("side_slip_max")) or 1.8
		local tangent = Vector(-face.Y, face.X) * spin
		local drift = crash.drift_vel or Vector(0, 0)
		drift = drift * retain
		crash.drift_vel = drift
		local desired = drift + tangent * math.min(slip_max, crash.phase_t * 0.07)
		desired = desired + air_crash_safe_steer(ent, crash, room)
		ent.Velocity = (ent.Velocity or Vector.Zero) * 0.78 + desired * 0.22
		local near_g = math.min(1, math.abs(crash.z) < 12 and (1 - math.abs(crash.z) / 12) or 0)
		local shake = math.sin(crash.t * 1.7) * math.min(3, 0.8 + near_g * 2.2)
		d[item.own_key.."OffsetZ"] = math.min(0, crash.z)
		d[item.own_key.."PassAlt"] = 0
		ent.PositionOffset = Vector(shake, d[item.own_key.."OffsetZ"])
		crash.roll_speed = math.min(18, math.abs(tonumber(crash.roll_speed) or 4) + 0.35)
		if spin < 0 then crash.roll_speed = -math.abs(crash.roll_speed)
		else crash.roll_speed = math.abs(crash.roll_speed) end
		crash.roll_angle = (tonumber(crash.roll_angle) or 0) + crash.roll_speed
		-- 落地前压机头朝速度
		local look = face
		if near_g > 0.2 and ent.Velocity and ent.Velocity:Length() > 0.4 then
			look = face * (1 - near_g * 0.65) + ent.Velocity:Normalized() * (near_g * 0.65)
			if look:Length() > 0.01 then
				look = look:Normalized()
				crash.face = look
				face = look
			end
		end
		local pulse = (crash.t % 3 < 2) and 0.35 or 0.12
		ent:SetColor(Color(1, 0.22, 0.22, 1, pulse, 0, 0), 2, 60, false, false)
		paint_sprite(crash.roll_angle)
		d[item.own_key.."FaceU"] = face
		d[item.own_key.."RotDir"] = face
		crash.smoke_cd = (tonumber(crash.smoke_cd) or 0) - 1
		if crash.smoke_cd <= 0 then
			air_crash_spawn_smoke(ent, d, crash, "fall")
			crash.smoke_cd = math.max(3, math.floor(tonumber(crash_fx_get("fall_smoke_interval")) or 5))
		end
		if crash.z >= -0.5 then
			crash.z = 0
			crash.impact_pos = Vector(ent.Position.X, ent.Position.Y)
			crash.impact_speed = (ent.Velocity and ent.Velocity:Length()) or 0
			-- 翻滚初速：接地平面速度，勿强行 face*3.4
			local rv = Vector((ent.Velocity and ent.Velocity.X) or 0, (ent.Velocity and ent.Velocity.Y) or 0)
			if rv:Length() < 0.35 then
				rv = Vector(face.X, face.Y):Resized(1.2)
			elseif rv:Length() > 5.5 then
				rv = rv:Resized(5.5)
			end
			crash.roll_vel = rv
			d[item.own_key.."OffsetZ"] = 0
			ent.PositionOffset = Vector(0, 0)
			set_phase("impact")
		end
		return "busy"

	-- ---- impact：接地冲击 ----
	elseif crash.phase == "impact" then
		local impact_n = math.max(4, math.floor(tonumber(crash_fx_get("impact_frames")) or 6))
		ent.Velocity = (crash.roll_vel or Vector.Zero) * 0.55
		d[item.own_key.."OffsetZ"] = 0
		-- 2px 回弹（避免改 Sprite.Scale）
		local bounce = 0
		if crash.phase_t == 1 then
			bounce = 2
		elseif crash.phase_t <= 4 then
			bounce = 2 * (1 - (crash.phase_t - 1) / 3)
		end
		ent.PositionOffset = Vector(0, -bounce)
		if crash.phase_t == 1 and not crash.impact_done then
			crash.impact_done = true
			air_crash_spawn_impact_dust(ent, d, crash)
			air_crash_spawn_sparks(ent, d, crash, 4)
			local shake = math.floor(tonumber(crash_fx_get("screen_shake")) or 4)
			if shake > 0 and Game().ShakeScreen then
				Game():ShakeScreen(shake)
			end
			if SoundEffect.SOUND_ROCK_CRUMBLE then
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_ROCK_CRUMBLE, 0.8, 0.95, false, 0, 2)
			end
			if SoundEffect.SOUND_DEATH_BURST_SMALL then
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_DEATH_BURST_SMALL, 0.45, 0.85, false, 0, 1)
			end
		end
		ent:SetColor(Color(1, 0.28, 0.28, 1, 0.25, 0, 0), 2, 60, false, false)
		paint_sprite(crash.roll_angle)
		air_crash_clamp_tumble(ent, room)
		if crash.phase_t >= impact_n then
			set_phase("tumble")
		end
		return "busy"

	-- ---- tumble：擦地翻滚 ----
	elseif crash.phase == "tumble" then
		local fric = tonumber(crash_fx_get("tumble_friction")) or 0.90
		local max_t = math.floor(tonumber(crash_fx_get("tumble_max_frames")) or 24)
		local roll = crash.roll_vel or Vector(face.X, face.Y)
		roll = roll * fric
		crash.roll_vel = roll
		ent.Velocity = roll
		crash.roll_speed = (tonumber(crash.roll_speed) or 12) * 0.9
		crash.roll_angle = (tonumber(crash.roll_angle) or 0) + crash.roll_speed
		local fade = math.max(0, 1 - crash.phase_t / max_t)
		ent.PositionOffset = Vector(math.sin(crash.phase_t * 2.2) * (2.2 * fade), 0)
		d[item.own_key.."OffsetZ"] = 0
		ent:SetColor(Color(1, 0.3, 0.3, 1, 0.16 * fade, 0, 0), 2, 60, false, false)
		paint_sprite(crash.roll_angle)
		air_crash_clamp_tumble(ent, room)
		crash.smoke_cd = (tonumber(crash.smoke_cd) or 0) - 1
		if crash.smoke_cd <= 0 and roll:Length() > 0.4 then
			local back = roll:Length() > 0.01 and roll:Normalized() * -6 or Vector(0, 6)
			local old = ent.Position
			ent.Position = old + back
			air_crash_spawn_smoke(ent, d, crash, "fall")
			ent.Position = old
			crash.smoke_cd = 3 + (crash.phase_t % 2)
		end
		local stop = roll:Length() < 0.25 or crash.phase_t >= max_t
		if stop then
			ent.Velocity = Vector(0, 0)
			ent.PositionOffset = Vector(0, 0)
			-- 吸附最终残骸角，避免跳到固定 70*spin
			local final = crash.roll_angle or (70 * spin)
			-- 归一到相近的侧倒角
			local target = 55 * spin
			if math.abs(final - target) > 90 then
				target = final
			else
				final = final * 0.35 + target * 0.65
			end
			crash.final_rotation = final
			crash.roll_angle = final
			if opts and opts.can_revive then
				set_phase("revive")
			else
				set_phase("dead")
				local rng = air_crash_rng(ent, crash, 101)
				local mn = math.floor(tonumber(crash_fx_get("dead_smoke_min")) or 18)
				local mx = math.floor(tonumber(crash_fx_get("dead_smoke_max")) or 30)
				if mx < mn then mx = mn end
				crash.smoke_cd = mn + rng:RandomInt(math.max(1, mx - mn + 1))
			end
		end
		return "busy"

	-- ---- revive：ease-out 抬升 ----
	elseif crash.phase == "revive" then
		local rev_n = math.max(8, math.floor(tonumber(crash_fx_get("revive_frames")) or 14))
		crash.revive_t = (tonumber(crash.revive_t) or 0) + 1
		if crash.revive_t == 1 and opts and type(opts.on_revive_start) == "function" then
			opts.on_revive_start()
			air_crash_cleanup_fx(d)
		end
		local t = math.min(1, crash.revive_t / rev_n)
		local u = 1 - (1 - t) ^ 3
		d[item.own_key.."OffsetZ"] = AIR_AIM_VIS.base_offset * u
		d[item.own_key.."OffsetZVel"] = nil
		ent.PositionOffset = Vector(0, d[item.own_key.."OffsetZ"])
		ent.Velocity = Vector(0, 0)
		-- 灰红 → 淡绿
		local r = 0.55 + 0.45 * (1 - u)
		local gcol = 0.35 + 0.65 * u
		ent:SetColor(Color(r, gcol, 0.4 + 0.2 * u, 1, 0, 0.25 * (1 - u), 0), 3, 60, false, false)
		paint_sprite((crash.final_rotation or 0) * (1 - u))
		d[item.own_key.."FaceU"] = face
		d[item.own_key.."RotDir"] = face
		d[item.own_key.."AimU"] = face
		d[item.own_key.."AimSm"] = face
		if crash.revive_t >= 4 and crash.revive_t <= 8 and (crash.revive_t % 2 == 0) then
			air_crash_spawn_smoke(ent, d, crash, "revive")
		end
		if crash.revive_t >= rev_n then
			d[item.own_key.."Crash"] = nil
			d[item.own_key.."ForceCrash"] = nil
			d[item.own_key.."TrailSuppress"] = nil
			ent:SetColor(Color(1, 1, 1, 1, 0, 0, 0), 1, 50, false, false)
			air_crash_cleanup_fx(d)
			if opts and type(opts.on_revive_done) == "function" then
				opts.on_revive_done()
			end
			return "revived"
		end
		return "busy"

	-- ---- dead：残骸间歇冒烟 ----
	else
		ent.Velocity = Vector(0, 0)
		d[item.own_key.."OffsetZ"] = 0
		ent.PositionOffset = Vector(0, 0)
		ent:SetColor(Color(1, 0.32, 0.32, 1, 0.12, 0, 0), 2, 50, false, false)
		local ang = crash.final_rotation or crash.roll_angle or (70 * spin)
		paint_sprite(ang)
		crash.smoke_cd = (tonumber(crash.smoke_cd) or 0) - 1
		if crash.smoke_cd <= 0 then
			air_crash_spawn_smoke(ent, d, crash, "dead")
			local rng = air_crash_rng(ent, crash, 121)
			local mn = math.floor(tonumber(crash_fx_get("dead_smoke_min")) or 18)
			local mx = math.floor(tonumber(crash_fx_get("dead_smoke_max")) or 30)
			if mx < mn then mx = mn end
			crash.smoke_cd = mn + rng:RandomInt(math.max(1, mx - mn + 1))
		end
		return "dead"
	end
end

function item.debug_force_crash(opts)
	opts = opts or {}
	for _, fam in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, item.familiar, -1, false, false)) do
		local d = fam:GetData()
		air_crash_cleanup_fx(d)
		d[item.own_key.."Crash"] = nil
		d[item.own_key.."ForceCrash"] = true
		air_begin_crash(fam, d)
		local crash = d[item.own_key.."Crash"]
		if crash and opts.revive then
			crash.will_revive = true
		end
	end
end

function item.debug_clear_crash_fx()
	for _, fam in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, item.familiar, -1, false, false)) do
		local d = fam:GetData()
		air_crash_cleanup_fx(d)
		d[item.own_key.."Crash"] = nil
		d[item.own_key.."ForceCrash"] = nil
		d[item.own_key.."TrailSuppress"] = nil
		d[item.own_key.."WasBroken"] = nil
		fam:SetColor(Color(1, 1, 1, 1, 0, 0, 0), 1, 50, false, false)
	end
end

-- 换房：清掉旧房粒子引用（不序列化 userdata）；坠毁状态机保留，新房继续
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function(_)
		for _, fam in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, item.familiar, -1, false, false)) do
			local d = fam:GetData()
			air_crash_cleanup_fx(d)
		end
	end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar,
Function = function(_,ent)
	-- Gemini/Flight 几何探针的隔离对照体：保留引擎实体与 ANM2 渲染，禁止进入正式巡航控制链。
	if ent.SubType == 9876 or ent:GetData().gemini_motion_probe_control_air then return end
	if auxi.is_time_stopped() then
		ent.Velocity = Vector(0, 0)
		return
	end
	local s = ent:GetSprite()
	local d = ent:GetData()
	local room = Game():GetRoom()
	local player = auxi.check_spawner_player(ent)
	local d2 = player:GetData()
	local level = Game():GetLevel()
	-- 先取静态动态档案驱动移速；开火前再按本帧瞄准重绑
	local craft_prof = bind_craft_profile(ent, player, false, nil)
	apply_body_scale(ent, craft_prof)

	-- 配方缺真实材料/原型：坠毁状态机；制造复活源落地翻滚后再飞（locked 后须蓝图确认才修好）。
	do
		local bp = get_blueprint()
		local uid = d[bp.own_key.."craft_uid"]
		local broken = (uid and player and bp.is_craft_broken(player, uid))
			or d[item.own_key.."ForceCrash"] == true
		d[item.own_key.."Broken"] = broken and true or nil
		local rec = (uid and player and bp.find_craft) and bp.find_craft(player, uid) or nil
		local revive_locked = CraftProfile.craft_revive_is_locked(rec)
		if not broken then
			if d[item.own_key.."Crash"] or d[item.own_key.."WasBroken"] then
				air_crash_cleanup_fx(d)
				d[item.own_key.."TrailSuppress"] = nil
			end
			d[item.own_key.."Crash"] = nil
			d[item.own_key.."ForceCrash"] = nil
			-- spent 只在蓝图确认且完整性由 broken -> valid 时按 repair epoch 重置。
			if Craft_Familiar_holder.set_craft_revive_spent_visual then
				Craft_Familiar_holder.set_craft_revive_spent_visual(ent, rec)
			end
			if d[item.own_key.."WasBroken"] then
				ent:SetColor(Color(1, 1, 1, 1, 0, 0, 0), 1, 50, false, false)
			end
			d[item.own_key.."WasBroken"] = nil
		elseif d[item.own_key.."Crash"] then
			d[item.own_key.."WasBroken"] = true
			ent.State = 0
			d[item.own_key.."AuxShouldShoot"] = false
			local crash = d[item.own_key.."Crash"]
			local can_revive = type(crash) == "table" and crash.will_revive == true
			local status = air_tick_crash(ent, s, d, {
				can_revive = can_revive,
				on_revive_start = function()
					if SoundEffect.SOUND_1UP then
						sound_tracker.PlayStackedSound(SoundEffect.SOUND_1UP, 1, 1, false, 0, 2)
					end
				end,
			})
			-- 坠毁中禁止普通淡青拖尾；粒子由 crash tick 自管
			if status ~= "revived" then
				return
			end
		elseif revive_locked and not d[item.own_key.."ForceCrash"] then
			-- 本轮已用制造复活：继续飞，淡绿提示仍待手动修理；跟随源按额度暗下
			local col = ent:GetColor()
			ent:SetColor(Color(0.55, 1, 0.55, col.A, 0, 0.1, 0), 2, 50, false, false)
			d[item.own_key.."WasBroken"] = true
			if Craft_Familiar_holder.set_craft_revive_spent_visual then
				Craft_Familiar_holder.set_craft_revive_spent_visual(ent, rec)
			end
		elseif broken then
			d[item.own_key.."WasBroken"] = true
			ent.State = 0
			d[item.own_key.."AuxShouldShoot"] = false
			air_begin_crash(ent, d)
			local crash = d[item.own_key.."Crash"]
			local can_revive_new = false
			-- ForceCrash 调试可自带 will_revive；正式缺料才走账本扣次
			if crash and crash.will_revive then
				can_revive_new = true
			elseif not d[item.own_key.."ForceCrash"] then
				local src = CraftProfile.craft_revive_try_pick(craft_prof, rec, player)
				if src and rec then
					CraftProfile.craft_revive_spend(rec, src)
					can_revive_new = true
					if type(crash) == "table" then
						crash.will_revive = true
						crash.revive_key = src.key
					end
					if Craft_Familiar_holder.set_craft_revive_spent_visual then
						Craft_Familiar_holder.set_craft_revive_spent_visual(ent, rec)
					end
				end
			end
			local status = air_tick_crash(ent, s, d, {
				can_revive = can_revive_new or (crash and crash.will_revive == true),
				on_revive_start = function()
					if SoundEffect.SOUND_1UP then
						sound_tracker.PlayStackedSound(SoundEffect.SOUND_1UP, 1, 1, false, 0, 2)
					end
				end,
			})
			if status ~= "revived" then
				return
			end
		end
	end

	-- 档案移速驱动飞行器本体（与弹速 atk_shotspeed 分离）；下限避免过低时盘旋塌缩。
	local move_spd = (craft_prof and craft_prof.stats and craft_prof.stats.speed) or 1
	local dbg_spd = tonumber(item.debug_move_spd) or 0
	if dbg_spd > 0 then move_spd = dbg_spd end
	local is_spwq = player:GetPlayerType() == player_Spwq.entity
	local BW = get_bandwidth()
	if is_spwq then BW.ensure_reconcile(player) end
	local uid = air_craft_uid(ent)
	local standby = is_spwq and uid ~= nil and BW.is_active(player, uid) ~= true
	local was_standby = d[item.own_key.."Standby"] == true
	d[item.own_key.."Standby"] = standby or nil
	local taurus_charging = false
	if not standby then
		local Taurus = require("Qing_Remaster_scripts.others.craft_taurus")
		if Taurus and Taurus.pre_move then
			move_spd, taurus_charging = Taurus.pre_move(ent, player, craft_prof, move_spd)
		end
	end
	if move_spd < 0.75 and not taurus_charging then move_spd = 0.75 end
	d[item.own_key.."MoveSpd"] = move_spd
	local control = is_spwq and BW.get_control(player) or nil
	local formation = (control and control.formation_mode) or item.FORMATION_CRUISE
	local fire_mode = (control and control.fire_control_mode) or item.FIRE_AUTO
	local last_aim = (control and control.last_aim) or Vector(0, 1)
	local mark = is_spwq and d2[player_Spwq.own_key.."Focus_target"] or nil
	local mark_alive = auxi.check_all_exists(mark)
	local mark_pos = mark_alive and mark.Position or player.Position
	d[item.own_key.."FormationMode"] = formation
	d[item.own_key.."FireControlMode"] = fire_mode
	local orb_sign = d[item.own_key.."OrbSign"] or 1
	d[item.own_key.."OrbSign"] = orb_sign
	local prev_form = d[item.own_key.."FocusMode"]
	if prev_form ~= nil and prev_form ~= formation then
		air_request_pass_exit(d)
		d[item.own_key.."Flourish"] = nil
		d[item.own_key.."NoFlourishUntil"] = Game():GetFrameCount() + 28
		local face = d[item.own_key.."FaceU"] or d[item.own_key.."RotDir"]
		if face and face:Length() > 0.01 then
			local n = face:Normalized()
			d[item.own_key.."AimU"] = Vector(n.X, n.Y)
			d[item.own_key.."AimSm"] = Vector(n.X, n.Y)
		end
	end
	d[item.own_key.."FocusMode"] = formation

	if was_standby and not standby then
		air_restore_standby_color(ent, d)
		air_combat_stop_for_standby(ent, d)
	end

	if standby then
		if not was_standby then
			air_combat_stop_for_standby(ent, d)
		end
		d[item.own_key.."AuxShouldShoot"] = false
		d[item.own_key.."Target"] = nil
		d[item.own_key.."PassAttacking"] = false
		ent.State = 0
		local form = get_air_form(player, ent, true)
		d[item.own_key.."Form"] = form
		local face = air_guard_aim_dir(player, mark_pos, last_aim)
		air_apply_rear_wing_move(ent, d, player, face, form, move_spd, "form")
		air_apply_standby_dim(ent, d)
		apply_air_aim_visual(ent, s, d, face, false, form)
		air_sync_trail(ent, d)
		air_sync_companions(ent, d, craft_prof, player)
		return
	end

	local form = get_air_form(player, ent, false)
	local state_succ = false
	local fire_anchor = mark_pos
	local move_anchor = mark_pos
	local engage_range = item.Focus2range.cruise or 240

	-- 阵型阶段：只求期望位置。CRUISE+AUTO 可用敌人作盘旋中心；FORCE 不得为找敌偏离。
	local engage_enemy = nil
	if formation == item.FORMATION_GUARD then
		local face = air_guard_aim_dir(player, mark_pos, last_aim)
		move_anchor = player.Position - face * (48 + form.radius_mul * 8)
		air_apply_rear_wing_move(ent, d, player, face, form, move_spd, "form")
	else
		move_anchor = mark_alive and mark_pos or player.Position
		if fire_mode == item.FIRE_AUTO then
			engage_enemy = air_pick_cruise_enemy(ent, d, move_anchor, engage_range)
		else
			d[item.own_key.."Target"] = nil
		end
		air_apply_cruise_move(ent, d, player, mark_pos, mark_alive, form, move_spd, engage_enemy)
	end

	-- 火控阶段：只求 should_shoot / 瞄准点。FORCE 持续打准星。
	if fire_mode == item.FIRE_FORCE then
		state_succ = true
		fire_anchor = mark_pos
		d[item.own_key.."Target"] = nil
		d[item.own_key.."PassAttacking"] = true
	elseif formation == item.FORMATION_GUARD then
		local player_range = math.max(tonumber(player.TearRange) or 260, 120)
		local enemy = air_pick_enemy_guard(player, mark_pos, last_aim, player_range)
		if enemy then
			d[item.own_key.."Target"] = enemy
			fire_anchor = enemy.Position
			state_succ = true
		else
			d[item.own_key.."Target"] = nil
		end
		d[item.own_key.."PassAttacking"] = state_succ == true
	else
		if engage_enemy then
			d[item.own_key.."Target"] = engage_enemy
			fire_anchor = engage_enemy.Position
			state_succ = true
		else
			d[item.own_key.."Target"] = nil
			fire_anchor = move_anchor
		end
		d[item.own_key.."PassAttacking"] = state_succ == true
	end

	-- 金牛冲锋：覆盖本帧速度、炫彩、接触伤；压制开火
	do
		local Taurus = require("Qing_Remaster_scripts.others.craft_taurus")
		if Taurus and Taurus.post_move and Taurus.post_move(ent, player, craft_prof) then
			state_succ = false
			d[item.own_key.."PassAttacking"] = false
		end
	end

	-- 无掠飞权重时衰减高度加成
	if (tonumber(d[item.own_key.."PassWeight"]) or 0) <= 0 then
		local pa = tonumber(d[item.own_key.."PassAlt"]) or 0
		if pa > 0 then
			d[item.own_key.."PassAlt"] = pa * 0.82
			if d[item.own_key.."PassAlt"] < 0.02 then d[item.own_key.."PassAlt"] = 0 end
		end
	end

	d[item.own_key.."TgPos"] = fire_anchor
	local tgt_ent = d[item.own_key.."Target"]
	local approx_ss = ((craft_prof and craft_prof.stats and craft_prof.stats.shotspeed) or 1) * 10
	if fire_mode ~= item.FIRE_FORCE and auxi.check_all_exists(tgt_ent) then
		local pred = air_predict_aim(ent.Position, tgt_ent.Position, tgt_ent.Velocity or Vector(0, 0), approx_ss)
		d[item.own_key.."TgPos"] = pred
		d[item.own_key.."TgPosAdder"] = Vector(0, 0)
		fire_anchor = pred
	else
		d[item.own_key.."TgPosAdder"] = Vector(0, 0)
	end
	-- State 仅作兼容旧分支（如硫磺火超时）；新轨迹不再依赖 0/1/2 状态机
	ent.State = state_succ and 2 or 0
	-- 供视觉层使用的编队缓存
	d[item.own_key.."Form"] = form
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
	end
	tick_epiphora(ent, dyn_counts, state_succ, aim_for_dyn)
	tick_camo_undies(ent, dyn_counts, state_succ)
	tick_jupiter(ent, dyn_counts)
	craft_prof = bind_craft_profile(ent, player, state_succ, aim_for_dyn) or craft_prof
	tick_number_two(ent, player, craft_prof, state_succ)
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
	apply_body_scale(ent, craft_prof)
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
		local dbg_luck = tonumber(item.debug_force_luck)
		if dbg_luck and dbg_luck > 0 then
			atk_luck = dbg_luck
		end
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
	local craft_uid = craft_prof and d[get_blueprint().own_key.."craft_uid"]
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
	local function brim_list_add(laser, aim_dir, shot_dir)
		if not laser then return end
		local list = brim_list_get()
		local base_ang = aim_dir:GetAngleDegrees()
		local off = shot_dir:GetAngleDegrees() - base_ang
		list[#list + 1] = {laser = laser, angle_offset = off}
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
			stamp_craft_attack(ent2, ent, craft_prof, {
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
					return air_tear_height(ent, accel)
				end,
			})
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
				local q = player:FireTear(fire_pos, vel, true, true, true)
				if q then
					q = q:ToTear() or q
					q.Height = air_tear_height(ent, q.FallingAcceleration)
					q.FallingSpeed = -7.5 + auxi.random_2() * 5
					q.FallingAcceleration = 0.5
					q.Scale = q.Scale * (1.2 + auxi.random_2() * 0.3)
					if q.ResetSpriteScale then q:ResetSpriteScale() end
					air_copy_attack_offset(q, ent, true)
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
			local q = player:FireTear(fire_pos, base, true, true, true)
			if q then
				q = q:ToTear() or q
				q.Height = air_tear_height(ent, q.FallingAcceleration)
				air_copy_attack_offset(q, ent, true)
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
			params = { skip_player_sec_sample = true }
		end
		return auxi.fire_fetus(q, player, pos, vel, true, true, params)
	end
	local function apply_craft_flags_roll(ent2)
		if not craft_prof or not ent2 then return end
		local flags = roll_craft_flags(ent2)
		fire_flags = flags
		atk_flags = flags
		apply_craft_flags(ent2, craft_prof, flags, ent)
		CraftTearColors.apply(ent2, craft_prof.counts, flags, CraftProfile.TEAR_EFFECTS)
	end
	-- Knife/Sword：手写 fire_damage 后只登记来源，不二次乘 Dead Eye/巧克力。
	local function stamp_melee_source(ent2)
		if not craft_prof or not ent2 then return end
		stamp_craft_attack(ent2, ent, craft_prof, {
			skip_damage_reapply = true,
			attack_serial = craft_shot_serial,
		})
	end
	dir = - dis:Normalized() * 10 * atk_shotspeed
	dir2 = - dis2:Normalized() * 10 * atk_shotspeed
	-- 开火前先刷姿态/高度，保证本帧所有攻击与跟随激光吃到同一 Offset
	local aim_face = tgpos2 - ent.Position
	if aim_face:Length() < 0.01 then aim_face = ent.Velocity end
	apply_air_aim_visual(
		ent, s, d, aim_face,
		state_succ or d[item.own_key.."kidney_active"] == true,
		d[item.own_key.."Form"]
	)
	-- Passway：无锁敌时射击跟贴图朝向；有锁敌时优先朝目标开火
	do
		local pass = d[item.own_key.."Passway"]
		local pass_w = tonumber(d[item.own_key.."PassWeight"]) or 0
		local pass_drive = pass_w > 0.12
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
	fire_pos = ent.Position + dir2:Normalized() * 5
	-- 发布给宝宝的瞄准必须在 fire_jobs 之前冻结：job 循环会把 dir 改成附属攻击
	-- （该隐随机朝向 / Incubus 分发等），否则压制模式下每开火一次全体宝宝跟着转头。
	local aux_publish_dir = dir:Length() > 0.01 and dir:Normalized() or nil
	local aux_publish_pos = tgpos2
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
			on_volley_fired(ent, player, craft_prof, aim_for_dyn)
			d[item.own_key.."FireDelay"] = ludo_delay
		elseif (d[item.own_key.."FireDelay"] or 0) < 0 then
			d[item.own_key.."FireDelay"] = ludo_delay
		end
		-- 离散 AuxAttackQueue 不适用于持久卢多；Incubus 等改走 holder 宝宝卫星
		d[item.own_key.."AuxAttackQueue"] = nil
	else
		Craft_Ludovico_holder.release_if_not_ludo(ent, craft_prof)
	end
	-- §15.2 诅咒之眼：重放队列（制造档案）；禁止重放再入队
	local cursed_replay = nil
	local cq = d[item.own_key.."cursed_queue"]
	if (not craft_is_ludo) and cq and (cq.remain or 0) > 0 and state_succ then
		cq.cooldown = (cq.cooldown or 0) - 1
		if cq.cooldown <= 0 then
			cursed_replay = cq
			cq.remain = cq.remain - 1
			cq.cooldown = 2
			if cq.remain <= 0 then d[item.own_key.."cursed_queue"] = nil end
		end
	elseif cq and (cq.remain or 0) <= 0 then
		d[item.own_key.."cursed_queue"] = nil
	end

	-- 主开火 / 诅咒重放 / 附属完整攻击（Incubus 等）统一进 job 列表。
	local fire_jobs = {}
	if (((d[item.own_key.."FireDelay"] or 0) < 0 and state_succ) or cursed_replay)
		and not (craft_is_ludo and not cursed_replay) then
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
			j.dir = cursed_replay.dir or dir
			j.dir2 = cursed_replay.dir2 or dir2
			j.fire_pos = cursed_replay.fire_pos or fire_pos
			if cursed_replay.shot_serial then j.shot_serial = cursed_replay.shot_serial end
			if cursed_replay.atk_mods then j.atk_mods = cursed_replay.atk_mods end
		end
		fire_jobs[#fire_jobs + 1] = j
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
				}
			end
		end
		d[item.own_key.."AuxAttackQueue"] = {}
	end

	-- 440 Kidney Stone：独立于玩家状态的“卡住 → 结石 → 快速泪弹喷射”。
	if craft_prof and (craft_prof.counts[440] or 0) > 0 and kidney_requested_attack then
		local shot_dir = dir2:Length() > 0.01 and dir2:Normalized() or Vector(1, 0)
		if d[item.own_key.."kidney_release"] then
			d[item.own_key.."kidney_release"] = nil
			craft_shot_serial = (tonumber(d[item.own_key.."shot_serial"]) or 0) + 1
			d[item.own_key.."shot_serial"] = craft_shot_serial
			craft_proj_index = 0
			local stone = player:FireTear(fire_pos, shot_dir * 10 * atk_shotspeed, true, true, true)
			if stone then
				stone = stone:ToTear() or stone
				air_copy_attack_offset(stone, ent, true)
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
				local q = player:FireTear(fire_pos, spray_dir * 10 * atk_shotspeed, true, true, true)
				if q then
					q = q:ToTear() or q
					air_copy_attack_offset(q, ent, true)
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
				end
			end
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
		local delay = atk_delay
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
				local q = player:FireTear(fire_pos,shot_dir,true,true,true)
				table.insert(tbl,#tbl + 1,q)
				-- 剖腹产：转胎儿前不要 stamp。否则 CraftTearParams 先写平射下落，
				-- 且随后 stamp_fetus 会再 stamp 一次（计数已跳过，但下落/高度仍被污染）。
				if weap ~= 14 then
					q.Height = air_tear_height(ent,q.FallingAcceleration)
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
							local q = player:FireTear(fire_pos,shot_dir,true,true,true)
							if weap == 14 then
								air_fire_fetus(q,fire_pos,shot_dir)
								stamp_fetus(q)
							else
								q.Height = air_tear_height(ent,q.FallingAcceleration)
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
					local qe = player:FireTear(fire_pos, shot_dir, true, true, true)
					if qe then
						qe.Height = air_tear_height(ent, qe.FallingAcceleration)
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
			if not brim_list_any_alive() then
				local dirs = craft_volley_dirs(dir)
				local main_q = nil
				for bi, shot_dir in ipairs(dirs) do
					-- 按配方 Variant 生成；禁止 FireBrimstone 继承玩家 Brim+Tech 外观
					local q = CraftProfile.spawn_craft_brimstone({
						profile = craft_prof,
						air = ent,
						player = player,
						dir = shot_dir,
						position = fire_pos or ent.Position,
						position_offset = air_combat_offset(ent),
						timeout = 30,
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
						brim_list_add(q, dir, shot_dir)
						if bi == 1 then main_q = q end
					end
				end
				delay = delay * 0.5
				-- Brim + Tech X -> also fire a brimstone ring (secondary morph, beam stays)
				if syn and syn.brim_techx then
					local rad = (syn.thick_brim and 50 or 40) * proj_scale
					local qx = player:FireTechXLaser(fire_pos, dir * 0.15, rad, player, syn.thick_brim and 1 or 0.75)
					qx.PositionOffset = air_combat_offset(ent)
					qx.Parent = ent
					to_brim_ring(qx)
				end
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
						local q = air_fire_fetus(nil,fire_pos,dir2) q.Height = air_tear_height(ent,q.FallingAcceleration)
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
					position_offset = air_combat_offset(ent),
					timeout = 30,
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
						Posoffset = air_combat_offset(ent),
						dmg = fire_damage,
					}) or {}
					for _, q in ipairs(lasers) do
						stamp(q)
					end
				end
				delay = delay * 5
				if (not craft_prof) and has_coll(316) then
					delay_buffer.addeffe(function(params)
						auxi.fire_lung_Laser(player,ent.Position,dir,{Posoffset = air_combat_offset(ent),})
					end,{},2)
					delay = delay + atk_delay * 2
				end
			elseif (not craft_prof) and has_coll(316) then
				for i = 1,5 do
					delay_buffer.addeffe(function(params)
						local q = player:FireTechLaser(ent.Position,0,dir,false,true)
						q.PositionOffset = air_combat_offset(ent)
						stamp(q)
					end,{},i)
				end
				delay = delay * 3.5
			else
				local dirs = craft_volley_dirs(dir)
				for _, shot_dir in ipairs(dirs) do
					local q = player:FireTechLaser(fire_pos,0,shot_dir,false,true)
					q.PositionOffset = air_combat_offset(ent)
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
					local q = player:FireTechLaser(fire_pos,0,auxi.get_by_rotate(dir, (i - multitar * 0.5) * 6),false,true)
					q.PositionOffset = air_combat_offset(ent)
					q.Parent = ent
					stamp(q)
				end
			end
		elseif weap == 4 then
			-- hold_knife_path：Shoot 到顶后锁 PathOffset，避免回程与 Accerate 叠加跳变
			local params = {
				cooldown = 60,Accerate = 0.5,player = player,tearflags = atk_flags,Color = player.TearColor,
				Explosive = coll_n(149) + coll_n(52),
				PosOffset = air_combat_offset(ent),
				hold_knife_path = true,
			}
			if craft_prof and CraftProfile.profile_has_haemolacria(craft_prof) then
				params.craft_haemo = true
				params.craft_profile = craft_prof
				params.craft_atk_mods = atk_mods
			end
			local dirs = craft_volley_dirs(dir)
			local q = nil
			for ki, shot_dir in ipairs(dirs) do
				local qk = auxi.fire_knife(fire_pos,shot_dir,fire_damage,nil,auxi.deepCopy(params))
				qk:Shoot(1,atk_range/4)
				apply_craft_flags_roll(qk)
				stamp_melee_source(qk)
				CraftProfile.apply_size_mul(qk, proj_scale)
				if ki == 1 then q = qk end
			end
			-- Knife stack -> extra knives
			if syn and (syn.extra_shots or 0) > 0 then
				for i = 1, syn.extra_shots do
					local qk = auxi.fire_knife(fire_pos,auxi.get_by_rotate(dir, (i - syn.extra_shots * 0.5) * 10),fire_damage,nil,auxi.copy(params))
					qk:Shoot(1,atk_range/4)
					apply_craft_flags_roll(qk)
					stamp_melee_source(qk)
					CraftProfile.apply_size_mul(qk, proj_scale)
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
					pos_offset = air_combat_offset(ent),
				})
				stamp(q2, 0.3, {skip_scale = true})
			end
			-- §14.7.1 Knife + Technology：桥接激光；offset 差在 Laser_holder 里并入瞄准。
			if q and ((syn and syn.knife_tech) or (not craft_prof and has_coll(68) and not has_coll(395))) then
				local q2 = player:FireTechLaser(fire_pos, 1, dir, false, false, nil, 0.45)
				q2.DisableFollowParent = true
				q2.PositionOffset = air_combat_offset(ent)
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
				local qb = player:FireBomb(pos, vel)
				qb.PositionOffset = air_combat_offset(ent)
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
			if has_coll(678) then local q = air_fire_fetus(nil,fire_pos,dir2) q.Height = air_tear_height(ent,q.FallingAcceleration) stamp_fetus(q) end
			-- 制造档案已含 WEAPON_FIRE_DELAY_MUL[史诗]；非制造仍用旧 ×5 射速。
			if not craft_prof then
				delay = delay * 5
			end
		elseif weap == 7 then
			local function fire_one_lung(shot_dir)
				local lung_params = {
					Posoffset = air_combat_offset(ent),
					PosOffset = air_combat_offset(ent),
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
							})
						end
					end
				else
					local tears = auxi.fire_lung(ent.Position, shot_dir, player, lung_params) or {}
					for _, q in ipairs(tears) do
						q.Height = air_tear_height(ent, q.FallingAcceleration)
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
			local tx_rad = (atk_mods.techx_radius_mul or 1) * proj_scale
			local tx_dmg = atk_mods.techx_damage_mul or 1
			local dirs = craft_volley_dirs(dir)
			if has_coll(229) then
				for _, shot_dir in ipairs(dirs) do
					local rnd = math.random(3) + 3
					for i = 1,rnd do
						local radus = (math.random(30) + 30) * tx_rad
						if brim_ring then radus = radus + 15 * tx_rad end
						local q = player:FireTechXLaser(fire_pos,auxi.get_by_rotate(shot_dir,auxi.random_2() * 60),radus,player,(auxi.random_2() * 0.3 + 1) * tx_dmg)
						q.PositionOffset = air_combat_offset(ent)
						q.Parent = ent
						if brim_ring then to_brim_ring(q) else stamp(q, tx_dmg, {skip_scale = true}) end
					end
				end
			else
				local rad = (brim_ring and 45 or 30) * tx_rad
				for di, shot_dir in ipairs(dirs) do
					local q = player:FireTechXLaser(fire_pos,shot_dir,rad,player,tx_dmg)
					q.PositionOffset = air_combat_offset(ent)
					q.Parent = ent
					if brim_ring then to_brim_ring(q) else stamp(q, tx_dmg, {skip_scale = true}) end
					if di == 1 and craft_prof and CraftProfile.profile_has_haemolacria(craft_prof) then
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
				local qtech = player:FireTechLaser(fire_pos, 0, dir, false, true)
				qtech.Parent = ent
				qtech.PositionOffset = air_combat_offset(ent)
				stamp(qtech, 0.6 * tx_dmg)
			end
			-- Tech X stack -> extra rings
			if syn and (syn.extra_shots or 0) > 0 then
				for i = 1, syn.extra_shots do
					local qe = player:FireTechXLaser(fire_pos,auxi.get_by_rotate(dir, i * 20),(brim_ring and 40 or 28) * tx_rad,player,0.6 * tx_dmg)
					qe.PositionOffset = air_combat_offset(ent)
					qe.Parent = ent
					if brim_ring then to_brim_ring(qe) else stamp(qe, 0.6 * tx_dmg, {skip_scale = true}) end
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
					sq.Height = air_tear_height(ent, sq.FallingAcceleration)
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
					q.PositionOffset = air_combat_offset(ent)
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
						pos_offset = air_combat_offset(ent),
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
					q.PositionOffset = air_combat_offset(ent)
					apply_craft_flags_roll(q)
					stamp_melee_source(q)
					if q.Parent then stamp_melee_source(q.Parent) end
					CraftProfile.apply_size_mul(q, proj_scale)
				end
				delay_buffer.addeffe(function(params)
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_SHELLGAME,1,1,false,0,2)
				end,{},4)
			end
			if has_coll(678) then local q = air_fire_fetus(nil,fire_pos,dir2) q.Height = air_tear_height(ent,q.FallingAcceleration) stamp_fetus(q) end
		end
		-- 蜡烛：按本次最终攻击伤害（含单眼/巧克力/aux/Dead Eye）
		if has_coll(616) then
			if auxi.check_rand(atk_luck,50,3,10) then
				local q = Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.RED_CANDLE_FLAME,0,fire_pos,dir2,player):ToEffect()
				q.PositionOffset = air_combat_offset(ent)
				q.CollisionDamage = fire_damage * 4
				q:SetTimeout(600)
			end
		end
		if has_coll(495) then
			if auxi.check_rand(atk_luck,50,3,10) then
				local q = Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.BLUE_FLAME,0,fire_pos,dir2,player):ToEffect()
				q.PositionOffset = air_combat_offset(ent)
				q.CollisionDamage = fire_damage * 3
				q:SetTimeout(120)
			end
		end
		Isaacs_Tear_holder.add_tear(player)
		drain_shot_counter_effects()
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
		local cursed_n = craft_prof and (tonumber(atk_mods.cursed_replays) or 0) or 0
		if craft_prof and craft_prof.extras and craft_prof.extras.cursed_eye
			and cursed_n > 0 and not is_replay and not is_aux and weap ~= 8 then
			d[item.own_key.."cursed_queue"] = {
				remain = cursed_n,
				cooldown = 2,
				weap = weap,
				dir = dir,
				dir2 = dir2,
				fire_pos = fire_pos,
				shot_serial = craft_shot_serial,
				atk_mods = atk_mods,
			}
			local base_fd = craft_prof.stats and (craft_prof.stats.firedelay_base or craft_prof.stats.firedelay) or atk_delay
			delay = delay + 3 * base_fd
		end
		-- 重放/附属攻击不改写主冷却，也不推进眼睛相位等 volley 副作用。
		if not is_replay and not is_aux then
			d[item.own_key.."FireDelay"] = delay
			if craft_prof then
				on_volley_fired(ent, player, craft_prof, aim_for_dyn)
			end
		end
	end
	do
		local list = brim_list_get()
		local aim_ang = dir:GetAngleDegrees()
		local off = air_combat_offset(ent)
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
					las.Angle = aim_ang + (rec.angle_offset or 0)
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
		if auxi.check_all_exists(d[item.own_key.."Tech2"]) then
			d[item.own_key.."Tech2"].Angle = dir:GetAngleDegrees()
			d[item.own_key.."Tech2"].PositionOffset = air_combat_offset(ent)
			d[item.own_key.."Tech2"].Position = ent.Position
		else
			d[item.own_key.."Tech2"] = player:FireTechLaser(fire_pos,0,dir,false,false,player)
			d[item.own_key.."Tech2"].DepthOffset = -5
			air_copy_attack_offset(d[item.own_key.."Tech2"], ent, false)
			-- Tech2：最终攻击伤害 ×0.13；不推进铅笔/贪婪计数
			d[item.own_key.."Tech2"].CollisionDamage = atk_damage * (atk_mods.damage_mul or 1) * dead_eye_mul * 0.13
			local tech2_flags = craft_prof and roll_craft_flags(d[item.own_key.."Tech2"]) or fire_flags
			apply_craft_flags(d[item.own_key.."Tech2"], craft_prof, tech2_flags, ent)
			if craft_prof then
				stamp_craft_attack(d[item.own_key.."Tech2"], ent, craft_prof, {
					dead_eye_mul = dead_eye_mul,
					dead_eye_charge = has_coll(373) and dead_eye_charge or nil,
				})
			end
			d[item.own_key.."Tech2"]:SetTimeout(-1)
		end
	elseif auxi.check_all_exists(d[item.own_key.."Tech2"]) then 
		d[item.own_key.."Tech2"]:SetTimeout(1)
		d[item.own_key.."Tech2"] = nil
	end
	if state_succ and has_coll(244) then
		if (d[item.own_key.."Tech.5_counter"] or 0) <= 0 and auxi.check_rand(atk_luck,10,2,10) then
			local q = auxi.fire_Tech_5_laser(player,fire_pos,dir)
			air_copy_attack_offset(q, ent, false)
			stamp(q, 1)
			d[item.own_key.."Tech.5_counter"] = 10
		end
	end
	if (d[item.own_key.."Tech.5_counter"] or 0) > 0 then d[item.own_key.."Tech.5_counter"] = d[item.own_key.."Tech.5_counter"] - 1 end
	d[item.own_key.."FireDelay"] = (d[item.own_key.."FireDelay"] or 0) - 1
	-- 将飞行器本帧真正采用的攻击状态/方向发布给附属宝宝。
	-- 必须读统一火控结果；FORCE 下没有敌人时也应 should_shoot=true。
	d[item.own_key.."AuxShouldShoot"] = state_succ or d[item.own_key.."kidney_active"] == true
	d[item.own_key.."AuxAimDirection"] = aux_publish_dir
	d[item.own_key.."AuxAimPos"] = aux_publish_pos

	air_sync_trail(ent, d)
	air_sync_companions(ent, d, craft_prof, player)
end,
})

-- 死眼命中/未命中；拟寄生物生成；杀戮嗜血击杀
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION,
	params = nil,
	Function = function(_, tear, collider, low)
		if not tear or not collider then return end
		local td = tear:GetData()
		local air = td[item.own_key.."craft_air"]
		if not air or not auxi.check_all_exists(air) then return end
		if not collider:IsVulnerableEnemy() or collider:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then return end
		td[item.own_key.."craft_hit"] = true
		local ad = air:GetData()
		if not td[item.own_key.."hit_noted"] then
			td[item.own_key.."hit_noted"] = true
			air_note_hit(ad, true)
		end
		local prof = ad[item.own_key.."craft_profile"]
		local player = auxi.check_spawner_player(air)
		if prof and prof.counts and (prof.counts[373] or 0) > 0 then
			ad[item.own_key.."dead_eye_charge"] = math.min(4, (tonumber(ad[item.own_key.."dead_eye_charge"]) or 0) + 1)
		end
		if prof and prof.counts and (prof.counts[411] or 0) > 0 and player then
			collider:GetData()[item.own_key.."lusty_player"] = GetPtrHash(player)
		end
		if prof and prof.counts and (prof.counts[257] or 0) > 0 and player then
			td[item.own_key.."fire_mind_hits"] = td[item.own_key.."fire_mind_hits"] or {}
			local hit_key = GetPtrHash(collider)
			if not td[item.own_key.."fire_mind_hits"][hit_key] then
				td[item.own_key.."fire_mind_hits"][hit_key] = true
				local chance = CraftProfile.fire_mind_explode_chance((prof.stats and prof.stats.luck) or player.Luck)
				local rng = CraftProfile.derived_rng(tear.InitSeed or 1, 257 * 65537 + hit_key)
				if rng:RandomFloat() < chance then
					local damage = tear.CollisionDamage or (prof.stats and prof.stats.damage) or player.Damage
					Isaac.Explode(tear.Position, player, damage)
					local fire = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.HOT_BOMB_FIRE, 0,
						tear.Position, Vector(0, 0), player):ToEffect()
					if fire and fire.CollisionDamage ~= nil then fire.CollisionDamage = 22 end
				end
			end
		end
		if td[item.own_key.."parasitoid"] and player then
			Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.PLAYER_CREEP_WHITE, 0, tear.Position, Vector(0, 0), player)
			if player:GetCollectibleRNG(461):RandomInt(2) == 0 then
				player:AddBlueSpider(tear.Position)
			else
				player:AddBlueFlies(1, tear.Position, player)
			end
			td[item.own_key.."parasitoid"] = nil
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE,
	params = EntityType.ENTITY_TEAR,
	Function = function(_, tear)
		if not tear then return end
		local td = tear:GetData()
		local air = td[item.own_key.."craft_air"]
		if not air or not auxi.check_all_exists(air) then return end
		if td[item.own_key.."craft_hit"] then return end
		local ad = air:GetData()
		if not td[item.own_key.."hit_noted"] then
			td[item.own_key.."hit_noted"] = true
			air_note_hit(ad, false)
		end
		local prof = ad[item.own_key.."craft_profile"]
		if prof and prof.counts and (prof.counts[373] or 0) > 0 then
			ad[item.own_key.."dead_eye_charge"] = 0
		end
	end,
})

-- 激光、刀与其他非泪弹攻击同样可触发 Fire Mind；每个攻击实例对每个敌人判定一次。
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG,
	params = nil,
	Function = function(_, target, amount, flags, source, countdown, extra_source)
		local npc = target and target:ToNPC()
		-- RGON 将激光/刀等真实命中实体放在 ExtraSource；Source 多数只指向 parent。
		local attack = extra_source and extra_source.Entity
		local adata = attack and attack.GetData and attack:GetData() or nil
		if not (adata and adata[item.own_key.."craft_air"]) then
			attack = source and source.Entity
			adata = attack and attack.GetData and attack:GetData() or nil
		end
		if not npc or not attack or not adata or attack.Type == EntityType.ENTITY_TEAR then return end
		local air = adata[item.own_key.."craft_air"]
		if not air or not auxi.check_all_exists(air) then return end
		local prof = air:GetData()[item.own_key.."craft_profile"]
		local player = auxi.check_spawner_player(air)
		if not prof or not prof.counts or (prof.counts[257] or 0) <= 0 or not player then return end
		adata[item.own_key.."fire_mind_hits"] = adata[item.own_key.."fire_mind_hits"] or {}
		local hit_key = GetPtrHash(npc)
		if adata[item.own_key.."fire_mind_hits"][hit_key] then return end
		adata[item.own_key.."fire_mind_hits"][hit_key] = true
		local chance = CraftProfile.fire_mind_explode_chance((prof.stats and prof.stats.luck) or player.Luck)
		local rng = CraftProfile.derived_rng(attack.InitSeed or 1, 257 * 65537 + hit_key)
		if rng:RandomFloat() < chance then
			Isaac.Explode(npc.Position, player, amount or (prof.stats and prof.stats.damage) or player.Damage)
			local fire = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.HOT_BOMB_FIRE, 0,
				npc.Position, Vector(0, 0), player):ToEffect()
			if fire and fire.CollisionDamage ~= nil then fire.CollisionDamage = 22 end
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NPC_DEATH,
	params = nil,
	Function = function(_, npc)
		if not npc or npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then return end
		local credit = npc:GetData()[item.own_key.."lusty_player"]
		if not credit then return end
		for i = 0, Game():GetNumPlayers() - 1 do
			local p = Game():GetPlayer(i)
			if p and GetPtrHash(p) == credit then
				CraftDyn.on_craft_kill(p)
				break
			end
		end
	end,
})

-- 制造血泪：主泪落地/命中后自模拟 burst（不写 TEAR_BURSTSPLIT）
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE,
	params = EntityType.ENTITY_TEAR,
	Function = function(_, ent)
		if not ent then return end
		CraftProfile.try_trigger_craft_haemo_tear(ent)
	end,
})

table.insert(item.post_ToCall, #item.post_ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION,
	params = nil,
	Function = function(_, tear, collider)
		if not tear or not collider then return end
		if not collider:IsVulnerableEnemy() then return end
		CraftProfile.try_trigger_craft_haemo_tear(tear)
	end,
})

-- 飞行中持续清 BURSTSPLIT，防止引擎/其它模组在 stamp 后又写回
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_TEAR_UPDATE,
	params = nil,
	Function = function(_, tear)
		if not tear then return end
		local d = tear:GetData()
		if d and d.craft_haemo and not d.craft_haemo_child then
			CraftProfile.clear_craft_haemo_burst_flag(tear)
		end
	end,
})

-- 制造激光：每帧重申 TearFlags / CurveStrength / HomingType（玩家 Spawner 会回写镜像弯曲）
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_LASER_UPDATE,
	params = nil,
	Function = function(_, laser)
		if not laser then return end
		CraftProfile.reassert_craft_laser(laser)
	end,
})

--[[ 旧四向 Float* 切片已废弃；现用 Transfer 俯仰帧 + Rotation 伪 3D（见 apply_air_aim_visual）。 ]]

return item
