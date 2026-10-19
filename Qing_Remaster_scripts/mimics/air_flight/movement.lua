-- Air Flight movement: pose, formation, passway, normal move.
-- Structural extract from Item_Air_Flight.lua. No gameplay/UI semantic changes.
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local CraftIdentity = require("Qing_Remaster_scripts.mimics.craft_identity")
local player_Spwq = require("Qing_Remaster_scripts.player.player_Spwq")
local dev_env = require("Qing_Remaster_scripts.core.dev_environment")

local M = {}

function M.attach(item, Air)

-- 姿态：2D 单位向量定向 slerp + 连续俯仰；大转向走「经正面/第一帧」华丽弧，而非贴背短路径。
-- 航向/俯仰都有每帧速率上限，与 Offset 一样保持连续。
Air.AIR_AIM_VIS = {
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
	-- 持续武器火控（硫磺火/Tech2）每帧最大转向；略快于机体 FaceU(~14°) 但仍禁止瞬跳
	fire_aim_rate_deg = 18,
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
	local vis = Air.AIR_AIM_VIS
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
				d[item.own_key.."FireAimSm"] = Vector(pass.face_dir.X, pass.face_dir.Y)
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
	local hr = Air.hit_rate(d)

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
	local kh = d and tonumber(d[item.own_key.."KnifeHold"]) or 0
	if kh > 0.02 then
		if kh > 1 then kh = 1 end
		desired = desired * (1 - kh)
		response = math.max(response or 0.2, 0.22 + 0.42 * kh)
	end
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
	return CraftIdentity.get_uid(ent)
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
	local BW = Air.get_bandwidth()
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



-- Cross-module bridge (minimal)
Air.apply_air_aim_visual = apply_air_aim_visual
Air.face_limit_turn = face_limit_turn
Air.face_turn_deg = face_turn_deg
Air.sync_trail = air_sync_trail
Air.apply_move = air_apply_move
Air.get_form = get_air_form
Air.apply_rear_wing_move = air_apply_rear_wing_move
Air.apply_cruise_move = air_apply_cruise_move
Air.pick_cruise_enemy = air_pick_cruise_enemy
Air.pick_enemy_guard = air_pick_enemy_guard
Air.pick_enemy = air_pick_enemy
Air.rebuild_formation_frame = rebuild_air_formation_frame
Air.clear_passway = air_clear_passway
Air.guard_aim_dir = air_guard_aim_dir
Air.predict_aim = air_predict_aim
Air.craft_uid = air_craft_uid
Air.request_pass_exit = air_request_pass_exit

end

return M
