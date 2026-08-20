-- Flight 金牛座（299）：进敌房加速 → 移速达 2 后冲锋 5 秒（炫彩、停射、顺滑撞击）。
-- 基础移速仍吃 STAT_DELTA[-0.3]；冲锋结束清除加速加成直至换房。
--
-- 加速节奏说明：
-- 原版 wiki 为 +0.065/tick（帧）。角色 0.7→2.0 约 20 帧≈0.67s。
-- 飞行器 move_spd 会放大盘旋/冲刺位移，同速率体感过快。
-- 因此改为「有敌人时约 ramp_seconds 秒蓄满到 2.0」（默认 4s），与基础移速成比例分摊每帧增量。
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")

local item = {
	ToCall = {},
	own_key = "craft_taurus_",
	cfg = {},
}

local TAURUS_ID = CollectibleType.COLLECTIBLE_TAURUS or 299

local DEFAULTS = {
	-- 有敌人时从当前基础移速涨到 2.0 的目标秒数（30fps）
	ramp_seconds = 4.0,
	-- 原版对照常量（仅注释/调试；正式逻辑用 ramp_seconds）
	vanilla_ramp_per_frame = 0.065,
	charge_speed = 2.0,
	charge_frames = 150, -- 5s
	chase_speed = 13,
	-- 撞击：进入此距离锁航向前冲，避免贴脸每帧掉头抽搐
	impact_dist = 34,
	overshoot_frames = 14,
	max_turn_deg = 7,
	steer_blend = 0.28,
	contact_radius = 30,
	contact_cd = 6,
	dmg_normal = 20,
	dmg_execute = 40,
	execute_hp = 40,
}

local function cfg(key)
	local v = item.cfg[key]
	if v ~= nil then return v end
	return DEFAULTS[key]
end

local function room_key()
	local level = Game():GetLevel()
	local desc = level and level:GetCurrentRoomDesc()
	local list = desc and (desc.ListIndex or desc.SafeGridIndex) or 0
	local stage = 0
	pcall(function() stage = level:GetAbsoluteStage() or 0 end)
	return stage * 100000 + (tonumber(list) or 0)
end

local function room_has_enemies()
	for _, ent in ipairs(Isaac.GetRoomEntities()) do
		local npc = ent and ent:ToNPC()
		if npc and npc:Exists() and npc:IsVulnerableEnemy()
			and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
		then
			return true
		end
	end
	return false
end

local function enemy_valid(npc)
	return npc and npc:Exists() and npc:IsVulnerableEnemy()
		and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
end

local function nearest_enemy(pos, range)
	range = range or 800
	local best, best_d2
	local r2 = range * range
	for _, npc in ipairs(Isaac.FindInRadius(pos, range, EntityPartition.ENEMY)) do
		if enemy_valid(npc) then
			local d2 = npc.Position:DistanceSquared(pos)
			if d2 <= r2 and (not best_d2 or d2 < best_d2) then
				best, best_d2 = npc, d2
			end
		end
	end
	return best
end

local function get_state(air)
	local d = air:GetData()
	local st = d[item.own_key.."st"]
	if type(st) ~= "table" then
		st = {
			phase = "idle", -- idle | ramp | charge | done
			bonus = 0,
			room = nil,
			charge_left = 0,
			saved_color = nil,
			no_target = false,
			hit_cd = {},
			heading = nil,
			overshoot = 0,
			lock_ptr = nil,
		}
		d[item.own_key.."st"] = st
	end
	return st
end

local function restore_color(air, st)
	local spr = air:GetSprite()
	if not spr then return end
	if st.saved_color then
		spr.Color = auxi.table2color(st.saved_color)
	else
		spr.Color = Color(1, 1, 1, 1)
	end
	st.saved_color = nil
end

local function apply_rainbow(air, st, frame)
	local spr = air:GetSprite()
	if not spr then return end
	if not st.saved_color then
		st.saved_color = auxi.color2table(spr.Color)
	end
	local t = frame * 0.22
	local rc = 1.2 + 1.1 * math.sin(t)
	local gc = 1.2 + 1.1 * math.sin(t + 2.094395)
	local bc = 1.2 + 1.1 * math.sin(t + 4.188790)
	local blink = ((frame % 4) < 2) and 0.45 or 1.0
	spr.Color = auxi.table2color({
		R = 1, G = 1, B = 1, A = blink,
		RO = 0.05 + 0.08 * math.sin(t * 1.7),
		GO = 0.05 + 0.08 * math.sin(t * 1.7 + 1.0),
		BO = 0.05 + 0.08 * math.sin(t * 1.7 + 2.0),
		RC = rc, GC = gc, BC = bc, AC = 1,
	})
end

local function set_invuln(air, st, on)
	if on and not st.no_target then
		air:AddEntityFlags(EntityFlag.FLAG_NO_TARGET)
		st.no_target = true
	elseif (not on) and st.no_target then
		air:ClearEntityFlags(EntityFlag.FLAG_NO_TARGET)
		st.no_target = false
	end
end

local function contact_tick(air, player, st, frame)
	local rad = tonumber(cfg("contact_radius")) or 30
	local cd = math.max(1, math.floor(tonumber(cfg("contact_cd")) or 6))
	local dmg_n = tonumber(cfg("dmg_normal")) or 20
	local dmg_x = tonumber(cfg("dmg_execute")) or 40
	local hp_x = tonumber(cfg("execute_hp")) or 40
	st.hit_cd = st.hit_cd or {}
	for _, npc in ipairs(Isaac.FindInRadius(air.Position, rad, EntityPartition.ENEMY)) do
		if enemy_valid(npc) then
			local ptr = GetPtrHash(npc)
			local last = tonumber(st.hit_cd[ptr]) or -999
			if frame - last >= cd then
				st.hit_cd[ptr] = frame
				local hp = tonumber(npc.HitPoints) or 0
				local dmg = (hp > 0 and hp < hp_x) and dmg_x or dmg_n
				npc:TakeDamage(dmg, 0, EntityRef(player or air), 0)
			end
		end
	end
end

local function resolve_charge_target(air, st)
	local overshoot = tonumber(st.overshoot) or 0
	if overshoot > 0 and st.lock_ptr then
		for _, npc in ipairs(Isaac.FindInRadius(air.Position, 900, EntityPartition.ENEMY)) do
			if enemy_valid(npc) and GetPtrHash(npc) == st.lock_ptr then
				return npc
			end
		end
	end
	-- 粘滞：优先当前锁敌（未死且仍在范围内）
	if st.lock_ptr then
		for _, npc in ipairs(Isaac.FindInRadius(air.Position, 900, EntityPartition.ENEMY)) do
			if enemy_valid(npc) and GetPtrHash(npc) == st.lock_ptr then
				return npc
			end
		end
	end
	local tgt = nearest_enemy(air.Position, 900)
	st.lock_ptr = tgt and GetPtrHash(tgt) or nil
	return tgt
end

local function steer_heading(st, desired_dir, max_turn)
	if not desired_dir or desired_dir:Length() < 0.01 then return end
	desired_dir = desired_dir:Normalized()
	if not st.heading or st.heading:Length() < 0.01 then
		st.heading = desired_dir
		return
	end
	local cur_ang = st.heading:GetAngleDegrees()
	local want = desired_dir:GetAngleDegrees()
	local delta = auxi.get_correct_angle(want - cur_ang)
	local lim = tonumber(max_turn) or 7
	if delta > lim then delta = lim end
	if delta < -lim then delta = -lim end
	st.heading = auxi.MakeVector(cur_ang + delta)
end

local function update_charge_velocity(air, st, tgt)
	local chase = tonumber(cfg("chase_speed")) or 13
	local impact = tonumber(cfg("impact_dist")) or 34
	local overshoot_n = math.max(1, math.floor(tonumber(cfg("overshoot_frames")) or 14))
	local max_turn = tonumber(cfg("max_turn_deg")) or 7
	local blend = tonumber(cfg("steer_blend")) or 0.28
	blend = math.max(0.08, math.min(1, blend))

	local cur = air.Velocity or Vector(0, 0)
	if not st.heading or st.heading:Length() < 0.01 then
		if cur:Length() > 0.2 then
			st.heading = cur:Normalized()
		elseif tgt then
			local to = tgt.Position - air.Position
			st.heading = (to:Length() > 0.01) and to:Normalized() or Vector(0, 1)
		else
			st.heading = Vector(0, 1)
		end
	end

	local overshoot = tonumber(st.overshoot) or 0
	if overshoot > 0 then
		st.overshoot = overshoot - 1
		-- 前冲：保持撞击瞬间航向，略加速
		local punch = st.heading:Resized(chase * 1.08)
		air.Velocity = cur * (1 - blend * 0.5) + punch * (blend * 0.5 + 0.5)
		return
	end

	if tgt then
		local to = tgt.Position - air.Position
		local dist = to:Length()
		if dist <= impact then
			-- 撞击：锁当前冲向（或朝敌），进入前冲段
			if cur:Length() > 0.4 then
				st.heading = cur:Normalized()
			elseif dist > 0.01 then
				st.heading = to:Normalized()
			end
			st.overshoot = overshoot_n
			st.lock_ptr = GetPtrHash(tgt)
			air.Velocity = st.heading:Resized(chase * 1.12)
			return
		end
		steer_heading(st, to, max_turn)
	else
		-- 无目标：沿当前航向巡航，缓缓扫向房间中心偏置
		local room = Game():GetRoom()
		local center = room and room:GetCenterPos() or air.Position
		local to_c = center - air.Position
		if to_c:Length() > 40 then
			steer_heading(st, to_c, max_turn * 0.5)
		end
		st.lock_ptr = nil
	end

	local desired = st.heading:Resized(chase)
	air.Velocity = cur * (1 - blend) + desired * blend
end

--- 移速阶段：更新房间/加速；返回生效 move_spd。
function item.pre_move(air, player, craft_prof, base_spd)
	if not air or not craft_prof then return base_spd, false end
	if CraftProfile.count_of(craft_prof.counts, TAURUS_ID) <= 0 then
		local d = air:GetData()
		if d[item.own_key.."st"] then
			local st = d[item.own_key.."st"]
			set_invuln(air, st, false)
			restore_color(air, st)
			d[item.own_key.."st"] = nil
		end
		return base_spd, false
	end
	local st = get_state(air)
	local rk = room_key()
	if st.room ~= rk then
		set_invuln(air, st, false)
		restore_color(air, st)
		st.room = rk
		st.bonus = 0
		st.charge_left = 0
		st.hit_cd = {}
		st.heading = nil
		st.overshoot = 0
		st.lock_ptr = nil
		if room_has_enemies() then
			st.phase = "ramp"
		else
			st.phase = "idle"
		end
	end

	local base = tonumber(base_spd) or 1
	local cap = tonumber(cfg("charge_speed")) or 2.0
	local ramp_sec = math.max(0.5, tonumber(cfg("ramp_seconds")) or 4.0)
	local ramp_frames = math.max(1, math.floor(ramp_sec * 30 + 0.5))

	if st.phase == "idle" then
		if room_has_enemies() then
			st.phase = "ramp"
		end
	end

	if st.phase == "ramp" and room_has_enemies() then
		local need = math.max(0, cap - base)
		st.bonus = (tonumber(st.bonus) or 0) + (need / ramp_frames)
		local effective = base + st.bonus
		if effective >= cap then
			st.bonus = math.max(0, cap - base)
			st.phase = "charge"
			st.charge_left = math.floor(tonumber(cfg("charge_frames")) or 150)
			st.heading = nil
			st.overshoot = 0
			st.lock_ptr = nil
			set_invuln(air, st, true)
		end
	end

	if st.phase == "charge" then
		return math.max(cap, base + (tonumber(st.bonus) or 0)), true
	end
	if st.phase == "done" then
		return base, false
	end
	local out = base + (tonumber(st.bonus) or 0)
	if out < 0.75 then out = 0.75 end
	return out, false
end

--- 移速应用之后：冲锋追敌、染色、接触伤；返回是否压制开火。
function item.post_move(air, player, craft_prof)
	if not air or not craft_prof then return false end
	if CraftProfile.count_of(craft_prof.counts, TAURUS_ID) <= 0 then return false end
	local st = get_state(air)
	local frame = Game():GetFrameCount()

	if st.phase ~= "charge" then
		if st.saved_color then restore_color(air, st) end
		set_invuln(air, st, false)
		return false
	end

	st.charge_left = (tonumber(st.charge_left) or 0) - 1
	apply_rainbow(air, st, frame)
	set_invuln(air, st, true)

	local tgt = resolve_charge_target(air, st)
	update_charge_velocity(air, st, tgt)
	contact_tick(air, player, st, frame)

	if st.charge_left <= 0 then
		st.phase = "done"
		st.bonus = 0
		st.charge_left = 0
		st.heading = nil
		st.overshoot = 0
		st.lock_ptr = nil
		set_invuln(air, st, false)
		restore_color(air, st)
		return false
	end
	return true
end

function item.is_charging(air)
	if not air then return false end
	local st = air:GetData()[item.own_key.."st"]
	return st and st.phase == "charge"
end

return item
