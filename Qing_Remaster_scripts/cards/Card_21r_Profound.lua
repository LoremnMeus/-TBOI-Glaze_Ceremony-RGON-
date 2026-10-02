local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")
local grid_door = require("Qing_Remaster_scripts.grids.grid_doors")
local card_01_wizard = require("Qing_Remaster_scripts.cards.Card_01_Wizard")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Profound_r,
	own_key = "Thoth_cd21r_Pro_",
	-- 阶段只决定门数；导航标尺（音量/cadence）四阶段统一
	door_info = {
		[0] = {num = 3, mul = 1.00, cadence_mul = 1.00,},
		[1] = {num = 5, mul = 1.00, cadence_mul = 1.00,},
		[2] = {num = 10, mul = 1.00, cadence_mul = 1.00,},
		[3] = {num = 15, mul = 1.00, cadence_mul = 1.00,},
	},
	-- V2.5：Homing 音量动态 0.35→1.00（约 2.86× / ~9dB）；SFX=0 短路不播
	target_final_far = 0.35,
	target_final_near = 1.00,
	target_final_volume = 1.00, -- compat preview fallback（近端）
	passed_volume_cap = 10.0,
	sfx_compensation_floor = 0.10, -- 仅反算用；raw SFX≈0 时不播放
	sfx_global_floor = 0.10, -- alias
	-- 距离 tier（HB3 = 贴门）
	dist_near = 70,
	dist_mid = 280,
	-- Guide-line cadence（远距几何定位）
	guide_inner_deg = 12,
	guide_outer_deg = 36,
	cadence_fast = 24,
	cadence_slow = 60,
	-- 近距 Homing / Lock-on（几何距离，禁止 closestDoor==correct）
	homing_start = 140,
	homing_far_interval = 60,
	homing_near_interval = 22,
	lock_spacing_frac = 0.30,
	lock_radius_min = 20,
	lock_radius_max = 55,
	-- 样本安全：整体平移。HB3 单 cycle ~412ms≈12.4f → 15
	hb3_sample_ms = 412,
	hb3_sample_frames = 12.4,
	safe_interval = {
		HB1 = 48,
		HB2 = 40,
		HB3 = 15,
	},
	allow_grid = {
		[GridEntityType.GRID_DECORATION] = true,
		[GridEntityType.GRID_SPIKES] = true,
		[GridEntityType.GRID_SPIKES_ONOFF] = true,
		[GridEntityType.GRID_SPIDERWEB] = true,
		[GridEntityType.GRID_TNT] = true,
		[GridEntityType.GRID_POOP] = true,
		[GridEntityType.GRID_TRAPDOOR] = true,
		[GridEntityType.GRID_STAIRS] = true,
		[GridEntityType.GRID_PRESSURE_PLATE] = true,
		[GridEntityType.GRID_TELEPORTER] = true,
		
		[GridEntityType.GRID_PIT] = true,
		[GridEntityType.GRID_ROCK] = true,
		[GridEntityType.GRID_ROCKB] = true,
		[GridEntityType.GRID_ROCKT] = true,
		[GridEntityType.GRID_ROCK_BOMB] = true,
		[GridEntityType.GRID_ROCK_ALT] = true,
		[GridEntityType.GRID_ROCK_SS] = true,
		[GridEntityType.GRID_ROCK_SPIKED] = true,
		[GridEntityType.GRID_ROCK_ALT2] = true,
		[GridEntityType.GRID_ROCK_GOLD] = true,
	},
}

function item.is_profound_room(desc)
	desc = desc or Game():GetLevel():GetCurrentRoomDesc()
	if desc and desc.Data then 
		local vr = desc.Data.Variant
		if vr == 24840 and desc.Data.Type == 8 then return true end
	end
	return false
end

function item.find_profound_room()
	local level = Game():GetLevel()
	local rooms = level:GetRooms()
	for i = 0, rooms.Size - 1 do
		local tg = rooms:Get(i)
		if item.is_profound_room(tg) and auxi.GetDimension(tg) == auxi.GetDimension() then return tg.SafeGridIndex end
	end
end

function item.normalize_angle(ang)
	ang = tonumber(ang) or 0
	while ang > 180 do
		ang = ang - 360
	end
	while ang <= -180 do
		ang = ang + 360
	end
	return ang
end

-- Shortest absolute angular distance on the circle (handles ±180 wrap).
function item.angular_distance(a, b)
	return math.abs(item.normalize_angle((tonumber(a) or 0) - (tonumber(b) or 0)))
end

-- Direction = 45° hard sectors；guide_error = 离最近 ±45°/±135° 导航射线的角距。
-- Guide lines: -135 / -45 / 45 / 135
function item.get_angle_info(angle)
	local tuning = item.get_probe_tuning()
	local strength = 1
	if tuning and tuning.pan_strength ~= nil then
		strength = tuning.pan_strength
	end
	angle = item.normalize_angle(angle)
	local pan
	if angle < -135 or angle > 135 then
		pan = strength
	elseif angle > -45 and angle < 45 then
		pan = -strength
	else
		pan = 0
	end
	local guides = {-135, -45, 45, 135}
	local nearest = 180
	local nearest_guide = 45
	for _, gdeg in ipairs(guides) do
		local d = item.angular_distance(angle, gdeg)
		if d < nearest then
			nearest = d
			nearest_guide = gdeg
		end
	end
	return pan, nearest, angle, nearest_guide
end

-- Compat wrapper (pan only).
function item.angle2pan(ang)
	local pan = item.get_angle_info(ang)
	return pan
end

function item.get_probe_tuning()
	-- 禁止 require 探针；仅在已由 require_probe 加载时读取
	local probe = package.loaded["Qing_Remaster_scripts.debug.profound_heartbeat_probe"]
	if type(probe) == "table" and probe.is_enabled and probe.is_enabled() and probe.get_tuning then
		return probe.get_tuning()
	end
	return nil
end

-- 接近程度用三级心跳：HB1 增强心跳 / HB2 增强 Faster / HB3 由 Faster 派生的加密节奏。
-- 永不回退原版 SOUND_HEARTBEAT_FASTEST(323)：那是短促爆鸣，不适合距离导航。
function item.get_heartbeat_sound_ids()
	local q = enums.SoundEffect
	local base = q.Qing_Heartbeat
	local faster = q.Qing_Heartbeat_Faster
	local fastest = q.Qing_Heartbeat_Fastest
	if type(base) ~= "number" or base < 0 then
		base = SoundEffect.SOUND_HEARTBEAT
	end
	if type(faster) ~= "number" or faster < 0 then
		faster = SoundEffect.SOUND_HEARTBEAT_FASTER
	end
	if type(fastest) ~= "number" or fastest < 0 then
		-- 宁可退到 faster，也不用有问题的 323
		fastest = faster
	end
	return base, faster, fastest
end

function item.get_heartbeat_sound(distance)
	local tier = item.get_heartbeat_tier(distance)
	local base, faster, fastest = item.get_heartbeat_sound_ids()
	if tier == "HB3" then
		return fastest
	elseif tier == "HB2" then
		return faster
	end
	return base
end

function item.get_dist_thresholds()
	local near = item.dist_near or 70
	local mid = item.dist_mid or 280
	local tuning = item.get_probe_tuning()
	if tuning then
		near = tuning.dist_near or near
		mid = tuning.dist_mid or mid
	end
	near = math.max(10, tonumber(near) or 70)
	mid = math.max(near + 1, tonumber(mid) or 280)
	return near, mid
end

function item.get_heartbeat_tier(distance)
	local near, mid = item.get_dist_thresholds()
	distance = tonumber(distance) or mid
	if distance <= near then
		return "HB3"
	elseif distance <= mid then
		return "HB2"
	end
	return "HB1"
end

-- Compat：旧 by_distance / fixed；主路径用 resolve_nav_cadence。
function item.get_heartbeat_interval(distance)
	local tuning = item.get_probe_tuning()
	if not tuning then
		return item.cadence_slow or 60
	end
	if tuning.interval_mode == "by_distance" then
		local near, mid = item.get_dist_thresholds()
		if distance <= near then
			return math.max(8, math.floor(tuning.interval_near or 36))
		elseif distance <= mid then
			return math.max(8, math.floor(tuning.interval_mid or 42))
		end
		return math.max(8, math.floor(tuning.interval_far or 48))
	end
	if tuning.interval_mode == "fixed" then
		return math.max(8, math.floor(tuning.interval_fixed or 45))
	end
	return math.max(8, math.floor(tuning.interval_fixed or item.cadence_slow or 60))
end

function item.get_stage_mul(_stage)
	return 1.0
end

function item.get_stage_cadence_mul(_stage)
	return 1.0
end

function item.get_raw_sfx_volume()
	local raw = 1.0
	if Options and type(Options.SFXVolume) == "number" then
		raw = Options.SFXVolume
	end
	return tonumber(raw) or 1.0
end

-- Compat：返回反算用的 effective global（floor 后）；真实 raw 见 get_raw_sfx_volume。
function item.get_global_sfx_volume()
	local raw = item.get_raw_sfx_volume()
	if raw <= 0.001 then
		return 0
	end
	local floor = item.sfx_compensation_floor or item.sfx_global_floor or 0.10
	local tuning = item.get_probe_tuning()
	if tuning and (tuning.sfx_compensation_floor ~= nil or tuning.sfx_global_floor ~= nil) then
		floor = tuning.sfx_compensation_floor or tuning.sfx_global_floor or floor
	end
	return math.max(raw, tonumber(floor) or 0.10)
end

-- returns: passed, effective_global, target, expected_final, raw_global, should_play
function item.get_sfx_volume_compensation(target)
	local tuning = item.get_probe_tuning()
	target = tonumber(target)
	if target == nil then
		target = item.target_final_near or item.target_final_volume or 1.0
		if tuning and tuning.target_final_near ~= nil then
			target = tuning.target_final_near
		elseif tuning and tuning.target_final_volume ~= nil then
			target = tuning.target_final_volume
		end
	end
	target = math.max(0.0, math.min(1.0, tonumber(target) or 0.0))

	local raw = item.get_raw_sfx_volume()
	if raw <= 0.001 or target <= 0.0 then
		return 0, 0, target, 0, raw, false
	end

	local floor = item.sfx_compensation_floor or item.sfx_global_floor or 0.10
	if tuning and (tuning.sfx_compensation_floor ~= nil or tuning.sfx_global_floor ~= nil) then
		floor = tuning.sfx_compensation_floor or tuning.sfx_global_floor or floor
	end
	local effective = math.max(raw, tonumber(floor) or 0.10)
	local passed = target / effective
	local cap = item.passed_volume_cap or 10.0
	if tuning and tuning.passed_volume_cap ~= nil then
		cap = tuning.passed_volume_cap
	end
	passed = math.min(passed, tonumber(cap) or 10.0)
	-- expected_final 用 raw×passed（用户真实全局），不是 effective×passed
	local expected = raw * passed
	return passed, effective, target, expected, raw, true
end

local function smoothstep01(t)
	t = math.max(0, math.min(1, t))
	return t * t * (3 - 2 * t)
end

local function lerp_num(a, b, t)
	return a + (b - a) * t
end

function item.get_nearest_wrong_spacing(room, door_list, correct_index)
	correct_index = correct_index or 1
	door_list = door_list or {}
	local correct = door_list[correct_index]
	if not (room and correct and correct.id) then
		return nil
	end
	local cpos = room:GetGridPosition(correct.id)
	local best = nil
	for i, d in ipairs(door_list) do
		if i ~= correct_index and d and d.id then
			local p = room:GetGridPosition(d.id)
			local dist = (p - cpos):Length()
			if best == nil or dist < best then
				best = dist
			end
		end
	end
	return best
end

function item.get_lock_radius(nearest_spacing)
	local tuning = item.get_probe_tuning()
	local frac = item.lock_spacing_frac or 0.30
	local lo = item.lock_radius_min or 20
	local hi = item.lock_radius_max or 55
	if tuning then
		frac = tuning.lock_spacing_frac or frac
		lo = tuning.lock_radius_min or lo
		hi = tuning.lock_radius_max or hi
	end
	nearest_spacing = tonumber(nearest_spacing)
	if nearest_spacing == nil then
		return math.max(lo, math.min(hi, 40))
	end
	local r = nearest_spacing * (tonumber(frac) or 0.30)
	return math.max(tonumber(lo) or 20, math.min(tonumber(hi) or 55, r))
end

-- Guide-line 原始 interval（不含 sample-safe）。
function item.get_guide_interval(guide_error)
	local tuning = item.get_probe_tuning()
	local inner = item.guide_inner_deg or 12
	local outer = item.guide_outer_deg or 36
	local fast = item.cadence_fast or 24
	local slow = item.cadence_slow or 60
	if tuning then
		inner = tuning.guide_inner_deg or inner
		outer = tuning.guide_outer_deg or outer
		fast = tuning.cadence_fast or fast
		slow = tuning.cadence_slow or slow
	end
	inner = math.max(0, tonumber(inner) or 12)
	outer = math.max(inner + 0.001, tonumber(outer) or 36)
	fast = math.max(1, math.floor(tonumber(fast) or 24))
	slow = math.max(fast, math.floor(tonumber(slow) or 60))

	guide_error = math.max(0, tonumber(guide_error) or 45)
	local shape_t
	local interval
	if guide_error <= inner then
		interval = fast
		shape_t = 0
	elseif guide_error >= outer then
		interval = slow
		shape_t = 1
	else
		local linear = (guide_error - inner) / (outer - inner)
		shape_t = smoothstep01(linear)
		interval = math.floor(lerp_num(fast, slow, shape_t) + 0.5)
	end
	return {
		interval = interval,
		shape_t = shape_t,
		guide_error = guide_error,
		inner = inner,
		outer = outer,
		fast = fast,
		slow = slow,
	}
end

-- 近距 Homing：距离越近 t→1；仅几何，不用 closestDoor 身份。
function item.get_homing_state(distance, lock_radius)
	local tuning = item.get_probe_tuning()
	local start_d = item.homing_start or 140
	local far_iv = item.homing_far_interval or 60
	local near_iv = item.homing_near_interval or 22
	local far_vol = item.target_final_far or 0.35
	local near_vol = item.target_final_near or 1.00
	if tuning then
		start_d = tuning.homing_start or start_d
		far_iv = tuning.homing_far_interval or far_iv
		near_iv = tuning.homing_near_interval or near_iv
		far_vol = tuning.target_final_far or far_vol
		near_vol = tuning.target_final_near or near_vol
	end
	start_d = math.max(1, tonumber(start_d) or 140)
	lock_radius = math.max(1, tonumber(lock_radius) or 20)
	if lock_radius >= start_d then
		lock_radius = start_d * 0.5
	end
	far_iv = math.max(1, math.floor(tonumber(far_iv) or 60))
	near_iv = math.max(1, math.floor(tonumber(near_iv) or 22))
	if near_iv > far_iv then
		near_iv = far_iv
	end
	far_vol = math.max(0.0, math.min(1.0, tonumber(far_vol) or 0.35))
	near_vol = math.max(far_vol, math.min(1.0, tonumber(near_vol) or 1.0))

	distance = math.max(0, tonumber(distance) or start_d)
	local locked = distance <= lock_radius
	local homing_t
	if distance >= start_d then
		homing_t = 0
	elseif locked then
		homing_t = 1
	else
		local linear = 1 - (distance - lock_radius) / (start_d - lock_radius)
		homing_t = smoothstep01(linear)
	end
	local interval = math.floor(lerp_num(far_iv, near_iv, homing_t) + 0.5)
	local target_final = lerp_num(far_vol, near_vol, homing_t)
	if locked then
		target_final = near_vol
		interval = near_iv
	end
	return {
		homing_t = homing_t,
		locked = locked,
		interval = interval,
		target_final = target_final,
		homing_start = start_d,
		lock_radius = lock_radius,
		far_interval = far_iv,
		near_interval = near_iv,
	}
end

function item.apply_sample_safe(raw_interval, tier, guide_fast)
	local tuning = item.get_probe_tuning()
	tier = tier or "HB1"
	guide_fast = math.max(1, math.floor(tonumber(guide_fast) or item.cadence_fast or 24))
	raw_interval = math.max(1, math.floor(tonumber(raw_interval) or guide_fast))
	local safe = (item.safe_interval and item.safe_interval[tier]) or 40
	if tuning and tuning.safe_interval and tuning.safe_interval[tier] ~= nil then
		safe = tuning.safe_interval[tier]
	end
	safe = math.max(1, math.floor(tonumber(safe) or 40))
	local safe_offset = math.max(0, safe - guide_fast)
	return {
		raw = raw_interval,
		safe = safe,
		safe_offset = safe_offset,
		final = raw_interval + safe_offset,
		tier = tier,
		guide_fast = guide_fast,
	}
end

-- V2.5 合并：guide ∩ homing → min，再 sample-safe 平移；Lock 强制 HB3。
function item.resolve_nav(distance, guide_error, door_list, room)
	local guide = item.get_guide_interval(guide_error)
	local nearest_spacing = item.get_nearest_wrong_spacing(room, door_list, 1)
	local lock_radius = item.get_lock_radius(nearest_spacing)
	local homing = item.get_homing_state(distance, lock_radius)
	local raw_final = math.min(guide.interval, homing.interval)
	local tier = item.get_heartbeat_tier(distance)
	if homing.locked then
		tier = "HB3"
	end
	local safe = item.apply_sample_safe(raw_final, tier, guide.fast)
	return {
		guide = guide,
		homing = homing,
		nearest_spacing = nearest_spacing,
		lock_radius = lock_radius,
		guide_interval = guide.interval,
		homing_interval = homing.interval,
		raw_final_interval = raw_final,
		requested = safe.raw,
		raw_requested = safe.raw,
		safe = safe.safe,
		safe_offset = safe.safe_offset,
		final = safe.final,
		tier = tier,
		target_final = homing.target_final,
		homing_t = homing.homing_t,
		locked = homing.locked,
		inner = guide.inner,
		outer = guide.outer,
		fast = guide.fast,
		slow = guide.slow,
		shape_t = guide.shape_t,
		homing_start = homing.homing_start,
	}
end

-- Compat：旧 API 名称 → 仅 guide 分量 + safe（无 Homing）。
function item.get_cadence_interval(guide_error, tier, _stage)
	local guide = item.get_guide_interval(guide_error)
	local safe = item.apply_sample_safe(guide.interval, tier or "HB1", guide.fast)
	return {
		requested = safe.raw,
		raw_requested = safe.raw,
		safe = safe.safe,
		safe_offset = safe.safe_offset,
		final = safe.final,
		shape_t = guide.shape_t,
		guide_error = guide.guide_error,
		tier = tier or "HB1",
		stage_mul = 1.0,
		inner = guide.inner,
		outer = guide.outer,
		fast = guide.fast,
		slow = guide.slow,
	}
end

function item.get_dis2vol_curve()
	local far = item.target_final_far or 0.35
	return {
		{frame = 0, vol = far},
		{frame = 600, vol = far},
	}
end

function item.get_vol_cap()
	local _, _, _, expected = item.get_sfx_volume_compensation(item.target_final_near or 1.0)
	return expected
end

local function heartbeat_sound_name(id)
	local q = enums.SoundEffect
	if id == q.Qing_Heartbeat_Fastest or id == SoundEffect.SOUND_HEARTBEAT_FASTEST then
		return "FASTEST"
	end
	if id == q.Qing_Heartbeat_Faster or id == SoundEffect.SOUND_HEARTBEAT_FASTER then
		return "FASTER"
	end
	if id == q.Qing_Heartbeat or id == SoundEffect.SOUND_HEARTBEAT then
		return "HEARTBEAT"
	end
	return tostring(id)
end

local function get_effect_player()
	local player_idx = (save.elses[item.own_key.."effect"] or {}).player_idx
	for i = 0,Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player:GetData().__Index == player_idx then return player end
	end
	return Game():GetPlayer(0)
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	local rng = player:GetCardRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local succ = item.find_profound_room() 
		if succ then 
		else 
			succ = Room_holder.Allocate_with()
			Room_holder.Try_replace_with(succ,auxi.GetDimension(),{data = function() Isaac.ExecuteCommand("goto s.supersecret.24840") return Game():GetLevel():GetRoomByIdx(-3).Data end,})
		end
		player:AnimateTeleport(true)
		Room_holder.Trans_to(succ,Direction.NO_DIRECTION,RoomTransitionAnim.TELEPORT,player,-1)
		save.elses[item.own_key.."effect"] = {tarot = d.tarot_cloth_used == cardtype,player_idx = idx,}
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	local effect = save.elses[item.own_key.."effect"]
	if not (item.is_profound_room() and effect) then
		return
	end

	local stage = effect.counter or 0
	local info = item.door_info[stage]
	if not info then
		return
	end

	local door = (effect.list or {})[1]
	if not door then
		return
	end

	local room = Game():GetRoom()
	local player = get_effect_player()
	local door_list = effect.list or {}
	local door_pos = room:GetGridPosition(door.id)
	local delta = player.Position - door_pos
	local distance = delta:Length()
	local angle = delta:GetAngleDegrees()
	local pan, guide_error, angle_n, nearest_guide = item.get_angle_info(angle)
	local nav = item.resolve_nav(distance, guide_error, door_list, room)
	local tuning = item.get_probe_tuning()
	if tuning and (tuning.interval_mode == "fixed" or tuning.interval_mode == "by_distance") then
		local forced = item.get_heartbeat_interval(distance)
		local safe = item.apply_sample_safe(forced, nav.tier, nav.fast)
		nav.guide_interval = forced
		nav.homing_interval = forced
		nav.raw_final_interval = forced
		nav.requested = safe.raw
		nav.raw_requested = safe.raw
		nav.safe = safe.safe
		nav.safe_offset = safe.safe_offset
		nav.final = safe.final
	end

	local now = room:GetFrameCount()
	local last = effect.hb_last_frame
	if type(last) ~= "number" then
		last = -9999
	end

	local passed_vol, effective_sfx, target_final, expected_final, raw_sfx, should_play =
		item.get_sfx_volume_compensation(nav.target_final)

	local probe = package.loaded["Qing_Remaster_scripts.debug.profound_heartbeat_probe"]
	if type(probe) == "table" and probe.is_enabled and probe.is_enabled() then
		if probe.update_nav then
			probe.update_nav({
				distance = distance,
				angle = angle_n,
				pan = pan,
				guide_error = guide_error,
				nearest_guide = nearest_guide,
				tier = nav.tier,
				stage = stage,
				nearest_spacing = nav.nearest_spacing,
				lock_radius = nav.lock_radius,
				homing_start = nav.homing_start,
				homing_t = nav.homing_t,
				locked = nav.locked,
				guide_interval = nav.guide_interval,
				homing_interval = nav.homing_interval,
				raw_final_interval = nav.raw_final_interval,
				requested_interval = nav.requested,
				raw_requested_interval = nav.raw_requested,
				safe_interval = nav.safe,
				safe_offset = nav.safe_offset,
				final_interval = nav.final,
				door_pos = door_pos,
				player_pos = player.Position,
				inner = nav.inner,
				outer = nav.outer,
				sample_playing = (now - last) < nav.final,
				global_sfx = raw_sfx,
				raw_global_sfx = raw_sfx,
				effective_global_sfx = effective_sfx,
				target_final_vol = target_final,
				passed_vol = passed_vol,
				expected_final_vol = expected_final,
				should_play = should_play,
			})
		end
	end

	-- Guide = 远距；Homing = 近距音量+节奏；Lock = 贴门最响最快。
	if (now - last) >= nav.final then
		effect.hb_last_frame = now
		local snd = item.get_heartbeat_sound(
			nav.locked and 0 or distance
		)
		if nav.locked then
			local _, _, fastest = item.get_heartbeat_sound_ids()
			snd = fastest
		end
		-- SFX=0 或 target=0：不播放（仍推进调度，避免每帧重试）
		if should_play and passed_vol > 0 then
			sound_tracker.PlayStackedSound(snd, passed_vol, 1, false, pan, 2)
		end

		if type(probe) == "table" and probe.note_play and probe.is_enabled and probe.is_enabled() then
			probe.note_play({
				distance = distance,
				angle = angle_n,
				interval = nav.final,
				guide_interval = nav.guide_interval,
				homing_interval = nav.homing_interval,
				raw_final_interval = nav.raw_final_interval,
				requested_interval = nav.requested,
				raw_requested_interval = nav.raw_requested,
				safe_interval = nav.safe,
				safe_offset = nav.safe_offset,
				final_interval = nav.final,
				nearest_spacing = nav.nearest_spacing,
				lock_radius = nav.lock_radius,
				homing_t = nav.homing_t,
				locked = nav.locked,
				vol = passed_vol,
				passed_vol = passed_vol,
				global_sfx = raw_sfx,
				raw_global_sfx = raw_sfx,
				effective_global_sfx = effective_sfx,
				target_final_vol = target_final,
				expected_final_vol = expected_final,
				should_play = should_play,
				pan = pan,
				guide_error = guide_error,
				nearest_guide = nearest_guide,
				boundary_dist = guide_error,
				boundary_gain = 0,
				boundary_mul = 1,
				tier = nav.tier,
				stage = stage,
				sound = snd,
				sound_name = heartbeat_sound_name(snd),
				sample_playing = should_play == true,
			})
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local room = Game():GetRoom()
	local level = Game():GetLevel()
	local curse = level:GetCurses()
	if item.is_profound_room() then
		local player = get_effect_player()
		item_displaying_holder.check_and_description("Level","Profound","Profound","",player,false)
		if curse & (1<<2) ~= (1<<2) and save.elses[item.own_key.."curse"] == nil then
			save.elses[item.own_key.."curse"] = true
			level:AddCurse(1<<2,false)
		end
		for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
			local door = room:GetDoor(slot)
			if door then room:RemoveDoor(slot) end 
		end
		if save.elses[item.own_key.."effect"] then
			local id = (save.elses[item.own_key.."effect"].counter or 0)
			local infos = item.door_info[id] or {}
			local cnt = infos.num
			if cnt then
				if #(save.elses[item.own_key.."effect"].list or {}) ~= cnt then
					local rng = auxi.rng_for_sake(player:GetCardRNG(item.entity))
					save.elses[item.own_key.."effect"].list = {}
					local size = room:GetGridSize()
					local dir_j = room:GetGridWidth()
					local dirs = {[0] = {delta = 1,dir = 0,},[1] = {delta = dir_j,dir = 1,},[2] = {delta = -1,dir = 2,},[3] = {delta = -dir_j,dir = 3,},}
					local succ_tbl = {}
					for i = 0,size - 1 do
						local gent = room:GetGridEntity(i)
						if gent and gent:GetType() == GridEntityType.GRID_WALL and room:IsPositionInRoom(room:GetGridPosition(i),0) == false then
							local dirinfo = nil
							for u,dir in pairs(dirs) do
								local iidx = i + dir.delta
								if room:IsPositionInRoom(room:GetGridPosition(iidx),0) then
									local gent = room:GetGridEntity(iidx)
									if gent == nil or auxi.check_if_any(item.allow_grid[gent:GetType()],player) then
										dirinfo = dir
										break
									end
								end
							end
							if dirinfo then table.insert(succ_tbl,#succ_tbl + 1,{dir = dirinfo.dir,id = i,}) end
						end
					end
					succ_tbl = auxi.randomOverTable(succ_tbl,rng)
					for i = 1,cnt do save.elses[item.own_key.."effect"].list[i] = succ_tbl[i] end
					save.elses[item.own_key.."effect"].hb_last_frame = nil
				end
				for i = 1,cnt do
					local v = save.elses[item.own_key.."effect"].list[i]
					if not v then break end
					if i ~= 1 then 
						grid_door.try_spawn_grid_door(room,nil,v.id,{check_and_leave = function(doorinfo,player)
							Room_holder.Trans_to(auxi.safe_gridindex(),Direction.NO_DIRECTION,RoomTransitionAnim.WALK,player)
						end,should_update = true,loadname = "gfx/grid/door_house.anm2",spritename = "gfx/grid/door_closet_red.png",playname = "Opened",dir = v.dir,})
					else
						grid_door.try_spawn_grid_door(room,nil,v.id,{check_and_leave = function(doorinfo,player)
							Room_holder.Trans_to(level:GetCurrentRoomDesc().SafeGridIndex,Direction.NO_DIRECTION,RoomTransitionAnim.WALK,player)
							save.elses[item.own_key.."effect"].counter = (save.elses[item.own_key.."effect"].counter or 0) + 1
							save.elses[item.own_key.."effect"].list = nil
						end,should_update = true,loadname = "gfx/grid/door_house.anm2",spritename = "gfx/grid/door_closet_red.png",playname = "Opened",dir = v.dir,})
					end
				end
			else
				--card_01_wizard.spawn_a_fool_port(room:FindFreePickupSpawnPosition(room:GetCenterPos(),10,true))
				local ndx = option_index_holder.find_a_new_index()
				local cnt = 3
				if save.elses[item.own_key.."effect"].tarot then cnt = 4 end
				local rng = auxi.rng_for_sake(player:GetCardRNG(item.entity))
				for i = 1,cnt do
					local offset = auxi.get_by_rotate(nil,rng:RandomFloat() * 360,40 * (rng:RandomInt(5) + 1))
					local q = Isaac.Spawn(5,100,0,room:FindFreePickupSpawnPosition(room:GetCenterPos() + offset,10,true),Vector(0,0),player):ToPickup()
					q.OptionsPickupIndex = ndx
				end
				save.elses[item.own_key.."effect"] = nil
				grid_door.try_spawn_grid_door(room,nil,127,{check_and_leave = function(doorinfo,player)
					Room_holder.Trans_to(auxi.safe_gridindex(),Direction.NO_DIRECTION,RoomTransitionAnim.WALK,player)
				end,should_update = true,loadname = "gfx/grid/door_house.anm2",spritename = "gfx/grid/door_closet_red.png",playname = "Opened",dir = 3,})
			end
		else card_01_wizard.spawn_a_fool_port(room:FindFreePickupSpawnPosition(room:GetCenterPos(),10,true)) end
	else
		if save.elses[item.own_key.."curse"] then
			save.elses[item.own_key.."curse"] = nil
			level:RemoveCurses(1<<2)
		end
		for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
			local door = room:GetDoor(slot)
			if door and door.TargetRoomIndex then 
				local desc = level:GetRoomByIdx(door.TargetRoomIndex)
				if desc and item.is_profound_room(desc) then room:RemoveDoor(slot) end
			end 
		end
		local lastdesc = level:GetLastRoomDesc()
		if item.is_profound_room(lastdesc) then 
			local desc = level:GetRoomByIdx(lastdesc.SafeGridIndex,auxi.GetDimension(lastdesc))
			desc.DisplayFlags = 0
			desc.VisitedCount = 0
			level:UpdateVisibility()
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_INIT, params = EffectVariant.DOOR_OUTLINE,
Function = function(_,ent)
	if item.is_profound_room() then ent:Remove() end
end,
})

return item
