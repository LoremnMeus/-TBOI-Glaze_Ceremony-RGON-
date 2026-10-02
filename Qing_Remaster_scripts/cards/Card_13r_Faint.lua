local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local render_phase_holder = require("Qing_Remaster_scripts.others.render_phase_holder")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")

-- XIII - 长眠?：停火加深沉睡，开火逐渐唤醒。
-- 逻辑层：RGON SetSpeedMultiplier（time scale）→ AI / 动画 / 计时
-- NPC SpeedMultiplier 必须经 Attribute_holder.descriptors.speed_multiplier()
-- （相对 origin 的倍率 claim，可与 My Hat 等叠加），并在 MC_PRE_NPC_UPDATE
-- ensure 后立即 apply_entity_attributes，使 native AI 本帧生效。
-- Projectile / Laser 仍直接 SetSpeedMultiplier（探针通道，暂不迁 holder）。
-- NPC PositionOffset：目前仍保留 PRE→POST Δ×scale，待独立验证。
-- 弹幕 XY：SetSpeedMultiplier 已覆盖原生插值（CONFIRMED）；禁止再加 V×α Offset
-- Position 不再做 POST Δ×scale，避免与 native SpeedMultiplier 重复减速。
-- 敌方激光：SM 不拖 Timeout（CONFIRMED）→ SM + Timeout 按 scale 分数补回
-- 详见 codex_work/notes/faint_projectile_xy_speed_multiplier.md

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Faint_r,
	own_key = "Thoth_cd13r_Fai_",
}

-- Dev probe：CANT_HIT_PLAYER 弹幕打此标后仍走真实 Faint（仅 Data，无第二套物理）
item.PROBE_INCLUDE_KEY = item.own_key .. "probe_include"

local ENEMY_MIN_SCALE = 0.10
local PROJECTILE_MIN_SCALE = 0.05

local SLEEP_RATE = 0.025
local WAKE_RATE = 0.035
local CLOTH_SLEEP_RATE = 0.04
local CLOTH_WAKE_RATE = 0.02

local MAX_COMPENSATED_DELTA = 80

local PRE_POS_OFFSET_KEY = item.own_key .. "pre_pos_offset"
local SCALED_KEY = item.own_key .. "time_scaled"
local NPC_TIME_SCALE_TOKEN_KEY = item.own_key .. "npc_time_scale_token"
local PROJECTILE_PRE_POS_KEY = item.own_key .. "projectile_pre_pos"
local PROJECTILE_PRE_HEIGHT_KEY = item.own_key .. "projectile_pre_height"
local PROJECTILE_PRE_FALLING_SPEED_KEY = item.own_key .. "projectile_pre_falling_speed"
local LASER_PRE_TIMEOUT_KEY = item.own_key .. "laser_pre_timeout"
local LASER_TIMEOUT_DEBT_KEY = item.own_key .. "laser_timeout_debt"
local LASER_LAST_TIMEOUT_KEY = item.own_key .. "laser_last_timeout"

local state

local function get_scale(min_scale)
	if not state then
		return 1
	end
	return 1 - state.depth * (1 - min_scale)
end

local function should_affect_projectile(projectile)
	if not projectile then
		return false
	end
	if not projectile:HasProjectileFlags(ProjectileFlags.CANT_HIT_PLAYER) then
		return true
	end
	local d = projectile:GetData()
	return d[item.PROBE_INCLUDE_KEY] == true
end

local function is_probe_projectile(projectile)
	local d = projectile and projectile:GetData()
	return d and d[item.PROBE_INCLUDE_KEY] == true
end

--- 真实敌弹：depth→scale；探针弹：d.faint_probe_scale（互不污染）
local function get_projectile_scale(projectile)
	local d = projectile:GetData()
	if d[item.PROBE_INCLUDE_KEY] and d.faint_probe_scale ~= nil then
		local s = tonumber(d.faint_probe_scale)
		if s then
			if s < 0.01 then
				s = 0.01
			elseif s > 1 then
				s = 1
			end
			return s
		end
	end
	return get_scale(PROJECTILE_MIN_SCALE)
end

--- 正常：render_phase_holder；探针：faint_probe_alpha0/1（按 Holder phase）或旧 faint_probe_alpha
local function get_projectile_render_alpha(projectile)
	local d = projectile:GetData()
	if d[item.PROBE_INCLUDE_KEY] then
		if d.faint_probe_alpha0 ~= nil and d.faint_probe_alpha1 ~= nil then
			local phase = render_phase_holder.get_phase()
			if phase == 0 then
				return tonumber(d.faint_probe_alpha0) or 0
			end
			return tonumber(d.faint_probe_alpha1) or 0
		end
		if d.faint_probe_alpha ~= nil then
			return tonumber(d.faint_probe_alpha) or 0
		end
	end
	return render_phase_holder.get_alpha()
end

--- 正式 Z：neg_h2o（弹幕专用 height2offset_projectile）
--- 探针可覆写 mode：baseline/raw/neg/h2o/neg_h2o；alpha 可为负；仅 |alpha|≈0 时跳过
local function get_z_render_correction(projectile, scale, alpha)
	alpha = tonumber(alpha)
	if not alpha or math.abs(alpha) < 0.000001 then
		return nil
	end
	if scale >= 0.999 then
		return nil
	end

	local d = projectile:GetData()
	local mode = d.faint_probe_z_mode
	if mode == "none" or mode == "baseline" then
		return nil
	end
	-- 真实敌弹 / 未指定探针 mode → 正式 neg_h2o
	if not mode then
		mode = "neg_h2o"
	end

	local fs = projectile.FallingSpeed
	local dh = fs * alpha * (scale - 1)
	local fa = projectile.FallingAccel or 0

	if mode == "raw" then
		return Vector(0, dh)
	elseif mode == "neg" then
		return Vector(0, -dh)
	elseif mode == "h2o" then
		local h0 = projectile.Height
		local y0 = auxi.height2offset_projectile(h0, fa)
		local y1 = auxi.height2offset_projectile(h0 + dh, fa)
		return Vector(0, y1 - y0)
	elseif mode == "neg_h2o" then
		local h0 = projectile.Height
		local y0 = auxi.height2offset_projectile(h0, fa)
		local y1 = auxi.height2offset_projectile(h0 + dh, fa)
		return Vector(0, -(y1 - y0))
	end
	return nil
end

--- XY：正式路径无 PRE Offset（SetSpeedMultiplier 已覆盖原生插值）
--- 探针 faint_probe_xy_mode 仅影响 SM / Pos / V 交叉实验，不进 Offset

--- 伤害来源为敌方的激光（硫磺火等）；玩家 / 宝宝激光不碰；Timeout<0（常驻）不补
local function is_hostile_laser(laser)
	if not laser then
		return false
	end
	local spawner = laser.SpawnerEntity
	if spawner then
		if spawner:ToPlayer() then
			return false
		end
		if spawner:ToFamiliar() then
			return false
		end
		local npc = spawner:ToNPC()
		if npc and npc:IsActiveEnemy(false) then
			return true
		end
	end
	local parent = laser.Parent
	if parent then
		if parent:ToPlayer() then
			return false
		end
		if parent:ToFamiliar() then
			return false
		end
		local npc = parent:ToNPC()
		if npc and npc:IsActiveEnemy(false) then
			return true
		end
	end
	local st = laser.SpawnerType
	if st == EntityType.ENTITY_PLAYER or st == EntityType.ENTITY_FAMILIAR then
		return false
	end
	return false
end

local function should_apply_laser_faint(laser)
	if not state then
		return false
	end
	return is_hostile_laser(laser)
end

local function should_apply_projectile_faint(projectile)
	if not should_affect_projectile(projectile) then
		return false
	end
	if state then
		return true
	end
	-- 无卡时仍允许探针弹按 faint_probe_scale 走同一套物理/渲染（dev-only）
	return is_probe_projectile(projectile) and projectile:GetData().faint_probe_scale ~= nil
end

local function clear_state()
	state = nil
	local speed_desc = Attribute_holder.descriptors.speed_multiplier()
	for _, ent in ipairs(Isaac.GetRoomEntities()) do
		local d = ent:GetData()

		if ent:ToNPC() then
			Attribute_holder.rewind_hold_token(
				ent,
				d,
				NPC_TIME_SCALE_TOKEN_KEY,
				"SpeedMultiplier",
				speed_desc
			)
		elseif d[SCALED_KEY] and ent.SetSpeedMultiplier then
			ent:SetSpeedMultiplier(1)
			d[SCALED_KEY] = nil
		end

		d[PRE_POS_OFFSET_KEY] = nil
		d[PROJECTILE_PRE_POS_KEY] = nil
		d[PROJECTILE_PRE_HEIGHT_KEY] = nil
		d[PROJECTILE_PRE_FALLING_SPEED_KEY] = nil
		d[LASER_PRE_TIMEOUT_KEY] = nil
		d[LASER_TIMEOUT_DEBT_KEY] = nil
		d[LASER_LAST_TIMEOUT_KEY] = nil
	end
end

local function update_sleep_depth()
	if not state then
		return
	end
	local p = state.owner
	if not p or not p:Exists() or p:IsDead() then
		clear_state()
		return
	end
	local firing =
		p:GetShootingInput():Length() > 0.1
		or p:GetFireDirection() ~= Direction.NO_DIRECTION
	if firing then
		state.depth = math.max(
			0,
			state.depth - (state.cloth and CLOTH_WAKE_RATE or WAKE_RATE)
		)
	else
		state.depth = math.min(
			1,
			state.depth + (state.cloth and CLOTH_SLEEP_RATE or SLEEP_RATE)
		)
	end
end

local function apply_npc_time_scale(npc)
	if not REPENTOGON or not npc.SetSpeedMultiplier then
		return
	end
	local d = npc:GetData()
	local descriptor = Attribute_holder.descriptors.speed_multiplier()
	if state then
		Attribute_holder.ensure_hold_token(
			npc,
			d,
			NPC_TIME_SCALE_TOKEN_KEY,
			"SpeedMultiplier",
			function()
				return get_scale(ENEMY_MIN_SCALE)
			end,
			descriptor
		)
		-- PRE_NPC_UPDATE 当帧就要生效，native AI 才能吃到 time scale。
		Attribute_holder.apply_entity_attributes(npc)
	else
		Attribute_holder.rewind_hold_token(
			npc,
			d,
			NPC_TIME_SCALE_TOKEN_KEY,
			"SpeedMultiplier",
			descriptor
		)
	end
end

local function apply_npc_position_scale(npc)
	local d = npc:GetData()
	local before_offset = d[PRE_POS_OFFSET_KEY]
	d[PRE_POS_OFFSET_KEY] = nil

	if not state then
		return
	end
	if not npc:Exists() or npc:IsDead() then
		return
	end

	local scale = get_scale(ENEMY_MIN_SCALE)
	local probe = d.faint_npc_probe

	-- Position 交给 PRE 设置的 SetSpeedMultiplier；此处只记录探针字段，不写回。
	if probe then
		local before_pos = d.faint_probe_pos_before
		d.faint_probe_pos_raw_after = Vector(npc.Position.X, npc.Position.Y)
		if before_pos then
			d.faint_probe_pos_delta = npc.Position - before_pos
		end
		d.faint_probe_pos_corrected = Vector(npc.Position.X, npc.Position.Y)
	end

	if before_offset then
		local delta = npc.PositionOffset - before_offset
		if probe then
			d.faint_probe_po_before = Vector(before_offset.X, before_offset.Y)
			d.faint_probe_po_raw_after = Vector(npc.PositionOffset.X, npc.PositionOffset.Y)
			d.faint_probe_po_delta = Vector(delta.X, delta.Y)
		end
		if delta:Length() <= MAX_COMPENSATED_DELTA then
			npc.PositionOffset = before_offset + delta * scale
		end
		if probe then
			d.faint_probe_po_corrected = Vector(npc.PositionOffset.X, npc.PositionOffset.Y)
		end
	end
end

local function apply_projectile_time_scale(projectile)
	if not REPENTOGON or not projectile.SetSpeedMultiplier then
		return
	end
	local d = projectile:GetData()
	if should_apply_projectile_faint(projectile) then
		local scale = get_projectile_scale(projectile)
		local xy_mode = d.faint_probe_xy_mode
		local sm = scale
		-- XY SpeedMultiplier 交叉实验：B/C/D 强制 SM=1；A 用 scale；非 XY 探针保持正式 SM=scale
		if xy_mode == "sm_one" or xy_mode == "vel_scale" or xy_mode == "vanilla" then
			sm = 1
		elseif xy_mode == "sm_scale" then
			sm = scale
		end
		projectile:SetSpeedMultiplier(sm)
		d[SCALED_KEY] = true
	elseif d[SCALED_KEY] then
		projectile:SetSpeedMultiplier(1)
		d[SCALED_KEY] = nil
	end
end

-- PRE 快照 → 引擎整帧 → POST：ΔPos/ΔH/ΔFS × scale（单一 FallingSpeed，无 world_fs 双状态）
-- XY 探针可覆写：vanilla 不缩 Position；vel_scale 把 Lua Velocity 写成 base×scale
local function apply_projectile_physics_scale(projectile)
	local d = projectile:GetData()
	local before_pos = d[PROJECTILE_PRE_POS_KEY]
	local before_height = d[PROJECTILE_PRE_HEIGHT_KEY]
	local before_falling_speed = d[PROJECTILE_PRE_FALLING_SPEED_KEY]
	d[PROJECTILE_PRE_POS_KEY] = nil
	d[PROJECTILE_PRE_HEIGHT_KEY] = nil
	d[PROJECTILE_PRE_FALLING_SPEED_KEY] = nil

	if not should_apply_projectile_faint(projectile) then
		return
	end

	local scale = get_projectile_scale(projectile)
	local xy_mode = d.faint_probe_xy_mode
	local skip_pos_scale = xy_mode == "vanilla"

	if before_pos and not skip_pos_scale then
		local delta = projectile.Position - before_pos
		projectile.Position = before_pos + delta * scale
	end

	if before_height ~= nil and not skip_pos_scale then
		local delta_height = projectile.Height - before_height
		projectile.Height = before_height + delta_height * scale
	end

	if before_falling_speed ~= nil and not skip_pos_scale then
		local delta_speed = projectile.FallingSpeed - before_falling_speed
		projectile.FallingSpeed = before_falling_speed + delta_speed * scale
	end

	-- C：SM=1 + Pos×scale，但把暴露给渲染的 Velocity 写成 base×scale
	if xy_mode == "vel_scale" then
		local base = tonumber(d.faint_probe_xy_base_speed) or projectile.Velocity:Length()
		local sign = 1
		if projectile.Velocity.X < 0 then
			sign = -1
		end
		projectile.Velocity = Vector(sign * base * scale, 0)
	end
end

local function apply_laser_time_scale(laser)
	if not REPENTOGON or not laser.SetSpeedMultiplier then
		return
	end
	local d = laser:GetData()
	if should_apply_laser_faint(laser) then
		laser:SetSpeedMultiplier(get_scale(PROJECTILE_MIN_SCALE))
		d[SCALED_KEY] = true
	elseif d[SCALED_KEY] then
		laser:SetSpeedMultiplier(1)
		d[SCALED_KEY] = nil
		d[LASER_TIMEOUT_DEBT_KEY] = nil
	end
end

-- SM 不拖 Timeout（实测）；引擎仍整帧倒计时，按 scale 分数补回
local function apply_laser_timeout_scale(laser)
	local d = laser:GetData()
	local before = d[LASER_PRE_TIMEOUT_KEY]
	d[LASER_PRE_TIMEOUT_KEY] = nil
	if before == nil then
		before = d[LASER_LAST_TIMEOUT_KEY]
	end

	if not should_apply_laser_faint(laser) then
		d[LASER_TIMEOUT_DEBT_KEY] = nil
		d[LASER_LAST_TIMEOUT_KEY] = nil
		return
	end

	local timeout = laser.Timeout
	if timeout == nil or timeout < 0 then
		d[LASER_TIMEOUT_DEBT_KEY] = nil
		d[LASER_LAST_TIMEOUT_KEY] = timeout
		return
	end
	if before == nil or before < 0 then
		d[LASER_LAST_TIMEOUT_KEY] = timeout
		return
	end

	local delta = timeout - before
	-- 只补倒计时；AI 刷新/拉长 Timeout（delta>=0）原样保留
	if delta < 0 then
		local scale = get_scale(PROJECTILE_MIN_SCALE)
		local debt = (tonumber(d[LASER_TIMEOUT_DEBT_KEY]) or 0) + (-delta) * (1 - scale)
		local give_back = math.floor(debt)
		if give_back > 0 then
			local next_timeout = timeout + give_back
			if laser.SetTimeout then
				laser:SetTimeout(next_timeout)
			else
				laser.Timeout = next_timeout
			end
			timeout = next_timeout
			debt = debt - give_back
		end
		d[LASER_TIMEOUT_DEBT_KEY] = debt
	end

	d[LASER_LAST_TIMEOUT_KEY] = timeout
end

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_ROOM,
	Function = function()
		clear_state()
	end,
})

table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_NPC_UPDATE,
	Function = function(_, npc)
		if not npc:IsActiveEnemy(false) then
			return
		end

		-- 必须在 native NPC update 之前设置。
		-- 用于让敌人的 AI / 动画 / 内部运动状态在本帧开始前就看到正确 time scale。
		apply_npc_time_scale(npc)

		if not state then
			return
		end

		local d = npc:GetData()
		-- Position 已交 native SM；仅在探针目标上保留 before 快照供 raw Δ 对比。
		if d.faint_npc_probe then
			d.faint_probe_pos_before = Vector(npc.Position.X, npc.Position.Y)
		end
		d[PRE_POS_OFFSET_KEY] = Vector(npc.PositionOffset.X, npc.PositionOffset.Y)
	end,
})

if ModCallbacks.MC_PRE_PROJECTILE_UPDATE then
	table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
		CallBack = ModCallbacks.MC_PRE_PROJECTILE_UPDATE,
		Function = function(_, projectile)
			if not should_affect_projectile(projectile) then
				return
			end
			if not should_apply_projectile_faint(projectile) then
				return
			end
			local d = projectile:GetData()
			-- C：逻辑帧用 base Velocity 走路，POST 再压 Position，并把暴露 Velocity 写成 base×scale
			if d.faint_probe_xy_mode == "vel_scale" then
				local base = tonumber(d.faint_probe_xy_base_speed)
				if base then
					local sign = 1
					if projectile.Velocity.X < 0 then
						sign = -1
					end
					projectile.Velocity = Vector(sign * base, 0)
				end
			end
			d[PROJECTILE_PRE_POS_KEY] = Vector(projectile.Position.X, projectile.Position.Y)
			d[PROJECTILE_PRE_HEIGHT_KEY] = projectile.Height
			d[PROJECTILE_PRE_FALLING_SPEED_KEY] = projectile.FallingSpeed
		end,
	})
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PROJECTILE_UPDATE,
	Function = function(_, projectile)
		if not should_affect_projectile(projectile) then
			return
		end
		apply_projectile_time_scale(projectile)
		apply_projectile_physics_scale(projectile)
	end,
})

if ModCallbacks.MC_PRE_LASER_UPDATE then
	table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
		CallBack = ModCallbacks.MC_PRE_LASER_UPDATE,
		Function = function(_, laser)
			if not should_apply_laser_faint(laser) then
				return
			end
			local timeout = laser.Timeout
			if timeout ~= nil then
				laser:GetData()[LASER_PRE_TIMEOUT_KEY] = timeout
			end
		end,
	})
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_LASER_UPDATE,
	Function = function(_, laser)
		apply_laser_time_scale(laser)
		apply_laser_timeout_scale(laser)
	end,
})

if ModCallbacks.MC_PRE_PROJECTILE_RENDER then
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_PRE_PROJECTILE_RENDER,
		Function = function(_, projectile, offset)
			if not should_affect_projectile(projectile) then
				return
			end
			if not should_apply_projectile_faint(projectile) then
				return
			end

			local scale = get_projectile_scale(projectile)
			local alpha = get_projectile_render_alpha(projectile)
			local total = offset or Vector.Zero

			-- 仅 Z：neg_h2o（正式）/ 探针 mapping；XY 无 Offset
			local z_corr = get_z_render_correction(projectile, scale, alpha)
			if z_corr then
				total = total + z_corr
			end

			if total.X == 0 and total.Y == 0 and (not offset or (offset.X == 0 and offset.Y == 0)) then
				return
			end
			return total
		end,
	})
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	Function = function()
		if not state then
			return
		end

		for _, ent in ipairs(Isaac.GetRoomEntities()) do
			local npc = ent:ToNPC()
			if npc and npc:IsActiveEnemy(false) then
				apply_npc_position_scale(npc)
			end
		end

		update_sleep_depth()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_USE_CARD,
	params = item.entity,
	Function = function(_, card, p, f)
		if f & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
			return
		end
		clear_state()
		state = {
			owner = p,
			depth = 0,
			cloth = p:GetData().tarot_cloth_used == card,
		}
	end,
})

function item.IsActive()
	return state ~= nil
end

--- Probe-only: expected enemy time scale and current sleep depth.
function item.GetEnemyTimeScale()
	if not state then
		return 1, nil
	end
	return get_scale(ENEMY_MIN_SCALE), state.depth
end

return item
