-- §16 方案 B：蓝图绑定宝宝公共控制器
-- full：PRE 跳过原版 AI；POST_UPDATE 驱动移动/冷却/瞄准/动画；adapter 开火
-- move_only：放行原版 AI；实体保持脱离玩家 follower 链，FAMILIAR_UPDATE 用 FollowPosition + 强 Velocity 移动
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Familiar_Control_Selector = require("Qing_Remaster_scripts.mimics.Familiar_Control_Selector")
local Familiar_Follower_Arbiter = require("Qing_Remaster_scripts.mimics.Familiar_Follower_Arbiter")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "Craft_Familiar_holder_",
	ADAPTERS = {},
	-- ImGui 调试（默认关；正式逻辑不依赖）
	debug_freeze_cooldown = false,
	debug_force_fire = false,
	follow_speed = 0.35,
	follow_max_speed = 14,
	snap_dist = 120,
	-- 与角色模拟 Incubus 一致：外圈开始追、内圈停止；非硬间距钉死。
	follow_start_distance = 40,
	follow_stop_distance = 20,
	follow_distance_bias = 20,
	follow_speed_gain = 0.14,
	follow_response = 0.16,
	follow_soft_max_speed = 10,
	follow_spacing = 30, -- 兼容旧字段；链式跟随已改用 start/stop 滞回
	friendship_radius = 44,
	friendship_angular_speed = 2,
}

local BIND_KEY = "bind"
local CD_KEY = "craft_fire_cooldown"
local HEAD_KEY = "craft_head_delay"
local SNAP_KEY = "craft_need_snap"
local TICK_KEY = "craft_last_update_frame"
local RETIRED_KEY = "craft_retired"
local ORIGINAL_STATE_KEY = "craft_original_state"
local RELEASED_FRAME_KEY = "craft_released_frame"
local REVIVE_FX_MAP_KEY = "revive_fx_map"
local ONE_UP_FX_KEY = "one_up_fx" -- 旧单键兼容
local TEAR_VISUAL_LIFT_KEY = "tear_visual_lift"
local TEAR_VISUAL_LIFT_START_KEY = "tear_visual_lift_start"
local TEAR_VISUAL_OWNED_KEY = "tear_visual_owned"
local TEAR_FIRST_UPDATE_KEY = "tear_visual_first_update"
local TEAR_SHADOW_SIZE_KEY = "tear_visual_shadow_size"
local TEAR_VISUAL_LIFT_FRAMES = 16 -- 渲染帧；从宝宝口部高度平滑并入正常 Tear.Height 弹道
local TEAR_TRAJECTORY_LAG_STEPS = 0.75 -- 沿弹道反向补偿，掩平首个 Update 前后的前进跳步
-- 实测约 61 PositionOffset = 40 screen px；原版宝宝素材中心比 Flight 原点高约 16px。
-- 把修正放进 PO 而非 SpriteOffset，使发射口视觉高度也能继承同一中心基准。
local FAMILIAR_CENTER_POSITION_Y = 16 * 61 / 40
local REVIVE_SPENT_COLOR = Color(0.22, 0.22, 0.22, 0.8, 0, 0, 0)
local REVIVE_LIVE_COLOR = Color(1, 1, 1, 1, 0, 0, 0)
-- 430/431 轨迹跟随：与波比编队分离；每槽落后若干逻辑帧相位
local TRAIL_KEY = "craft_path_trail"
local TRAIL_FRAME_KEY = "craft_path_trail_frame"
local TRAIL_PHASE_LAG = 8 -- 相邻轨迹宝宝相位差（约 30Hz 帧）
local TRAIL_MAX_LEN = 200
local TRAIL_SNAP_DIST = 140 -- 仅失联时硬钉；平时只写 Velocity 留给引擎插值
local TRAIL_VEL_BLEND = 0.9 -- 紧跟历史点，略混合当前速避免抖
local ACTIVE_BOUND = setmetatable({}, {__mode = "k"})

local function active_familiar_alive(fam)
	if not fam then return false end
	local ok, alive = pcall(function()
		return fam:Exists() and not fam:IsDead()
	end)
	return ok and alive == true
end

local function get_craft_profile()
	return require("Qing_Remaster_scripts.others.craft_combat_profile")
end

local function get_air_flight()
	return require("Qing_Remaster_scripts.items.Item_Air_Flight")
end

local function air_is_standby(air)
	local Air = get_air_flight()
	return Air and Air.is_standby and Air.is_standby(air) == true
end

local function get_blueprint()
	return require("Qing_Remaster_scripts.items.Item_Blue_Print")
end

local function get_nil_holder()
	return require("Qing_Remaster_scripts.others.Nil_holder")
end

local function get_enums()
	return require("Qing_Remaster_scripts.core.enums")
end

local FIRE_DELAY_SENTINEL = 999999
local function suppress_bound_weapons(fam)
	if not fam then return end
	if fam.GetWeapon then
		local ok_w, weapon = pcall(function() return fam:GetWeapon() end)
		if ok_w and weapon then
			pcall(function()
				if weapon.SetCharge then weapon:SetCharge(0) end
				if weapon.SetFireDelay then weapon:SetFireDelay(FIRE_DELAY_SENTINEL) end
			end)
		end
	end
	local fam_hash = GetPtrHash(fam)
	for _, kn in ipairs(Isaac.FindByType(EntityType.ENTITY_KNIFE, -1, -1, false, false)) do
		local knife = kn:ToKnife() or kn
		if knife and knife:Exists() then
			local parent = knife.Parent
			local spawner = knife.SpawnerEntity
			local match = (parent and GetPtrHash(parent) == fam_hash)
				or (spawner and GetPtrHash(spawner) == fam_hash)
			if match then
				local kd = knife:GetData()
				if knife.GetData and knife:GetData().knife_flight then
				else
					if not kd[item.own_key.."weapon_suppressed"] then
						kd[item.own_key.."weapon_suppressed"] = true
						kd[item.own_key.."vis_was"] = knife.Visible ~= false
						kd[item.own_key.."coll_was"] = knife.EntityCollisionClass
					end
					knife.Visible = false
					knife.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
					knife.Velocity = Vector.Zero
					knife.Position = fam.Position
				end
			end
		end
	end
end

local function restore_bound_weapons(fam)
	if not fam then return end
	if fam.GetWeapon then
		local ok_w, weapon = pcall(function() return fam:GetWeapon() end)
		if ok_w and weapon and weapon.SetFireDelay then
			pcall(function() weapon:SetFireDelay(0) end)
		end
	end
	for _, kn in ipairs(Isaac.FindByType(EntityType.ENTITY_KNIFE, -1, -1, false, false)) do
		local knife = kn:ToKnife() or kn
		if knife and knife:Exists() then
			local kd = knife:GetData()
			if kd[item.own_key.."weapon_suppressed"] then
				knife.Visible = kd[item.own_key.."vis_was"] ~= false
				if kd[item.own_key.."coll_was"] ~= nil then
					knife.EntityCollisionClass = kd[item.own_key.."coll_was"]
				end
				kd[item.own_key.."weapon_suppressed"] = nil
				kd[item.own_key.."vis_was"] = nil
				kd[item.own_key.."coll_was"] = nil
			end
		end
	end
end

local function prototype_alive_for(player, collectible_id)
	local bp = get_blueprint()
	return function(uid)
		if not player or uid == nil or not bp.get_prototype then return false end
		local prec = bp.get_prototype(player, uid)
		return prec ~= nil and tonumber(prec.id) == tonumber(collectible_id)
	end
end

function item.register_adapter(variant, adapter)
	if not variant or not adapter then return end
	adapter.variant = variant
	-- full（默认）| move_only（自动索敌宝宝：只接管移动）
	adapter.control_mode = adapter.control_mode or "full"
	item.ADAPTERS[variant] = adapter
end

function item.get_adapter(variant)
	return item.ADAPTERS[variant]
end

local function bind_data(fam)
	return fam and fam:GetData()[item.own_key..BIND_KEY]
end

local function is_bound(fam)
	return bind_data(fam) ~= nil
end

-- 供前方 sync_craft_revive_* 使用（定义见后）
local find_all_bound_for_air

local function is_move_only(adapter)
	return adapter and adapter.control_mode == "move_only"
end

--- 棱镜式：放行原版 AI（攻击/分裂/复制），在 FAMILIAR_UPDATE 覆写 Velocity 跟 Flight。
--- 与 move_only 的区别是驱动时机（UPDATE 而非 POST），避免 FollowParent 钉死后软跟随无效。
local function keeps_vanilla_ai(adapter)
	return adapter and adapter.keep_vanilla_ai == true
end

local function allows_vanilla_ai(adapter)
	return is_move_only(adapter) or keeps_vanilla_ai(adapter)
end

function item.adapter_allows_vanilla_ai(adapter_or_variant)
	local adapter = type(adapter_or_variant) == "table"
		and adapter_or_variant or item.ADAPTERS[adapter_or_variant]
	return allows_vanilla_ai(adapter)
end

local function arm_owned_tear_visual(tear, fam)
	if not tear or not fam then return end
	local bind = bind_data(fam)
	local adapter = item.ADAPTERS[fam.Variant]
	-- 只接管蓝图 full-control 宝宝的模拟泪弹；放行原版 AI 的开火不受影响。
	if not bind or not adapter or allows_vanilla_ai(adapter) then return end
	item.arm_tear_visual_lift(tear, fam, bind.air)
end

--- 公共入口：制造环绕物等非 Craft_Familiar bind 的泪弹也必须走同一套视觉高度桥接。
--- 禁止把发射者 PositionOffset 写进 Tear；禁止把巡航 PO 经 offset2height 写进 Height。
--- 详见 codex_work/notes/craft_familiar_tear_height_pitfalls.md
function item.arm_tear_visual_lift(tear, fam, air)
	if not tear or not fam then return end
	if not REPENTOGON or not ModCallbacks.MC_PRE_TEAR_RENDER then return end
	local off = fam.PositionOffset or Vector.Zero
	if math.abs(off.Y) < 0.5 and air and air.PositionOffset then
		off = Vector(air.PositionOffset.X, air.PositionOffset.Y)
	end
	if math.abs(off.Y) < 0.5 then off = Vector(0, -34) end
	local d = tear:GetData()
	d[item.own_key..TEAR_VISUAL_OWNED_KEY] = true
	d[item.own_key..TEAR_FIRST_UPDATE_KEY] = nil
	d[item.own_key..TEAR_VISUAL_LIFT_KEY] = Vector(off.X, off.Y)
	d[item.own_key..TEAR_VISUAL_LIFT_START_KEY] = nil
	if tear.PositionOffset ~= nil then
		tear.PositionOffset = Vector.Zero
	end
	if tear.GetShadowSize and tear.SetShadowSize then
		if d[item.own_key..TEAR_SHADOW_SIZE_KEY] == nil then
			local ok, size = pcall(tear.GetShadowSize, tear)
			if ok then d[item.own_key..TEAR_SHADOW_SIZE_KEY] = size end
		end
		tear:SetShadowSize(0)
	end
end

local function detach_from_vanilla_formation(fam)
	if not fam then return end
	if not Familiar_Follower_Arbiter.maintain(fam) and fam.RemoveFromFollowers then
		-- 原版 AI / EvaluateItems 可能把已装载宝宝重新 AddToFollowers。
		-- 若不每帧重申，后续新获得的跟随宝宝会 FollowParent 跟上装载体（430→431 坑）。
		fam:RemoveFromFollowers()
	end
	local d = fam:GetData()
	if d then
		d.IsFollowing = nil
	end
end

--- 轨迹宝宝：必须 RemoveFromDelayed 退出原版延迟队列（Obsessed Fan / Papa / Multi 那条）。
--- SetMoveDelayNum(0) 只改延迟帧数，人仍在 Delayed 队列里 → 无效。
--- 保留 Player；不要 RemoveFromPlayer（拆归属会坏射击/复制）。
local function detach_trail_vanilla_delay(fam)
	if not fam then return end
	detach_from_vanilla_formation(fam)
	if not Familiar_Follower_Arbiter.maintain(fam) and fam.RemoveFromDelayed then
		fam:RemoveFromDelayed()
	end
	-- 顺带清 Delay 数，避免某帧又被 AddToDelayed 后立刻拖很远
	if fam.SetMoveDelayNum then
		pcall(function() fam:SetMoveDelayNum(0) end)
	end
end

local function as_familiar(ent)
	if not ent then return nil end
	if ent.ToFamiliar then
		local f = ent:ToFamiliar()
		if f then return f end
	end
	if ent.Type == EntityType.ENTITY_FAMILIAR then return ent end
	return nil
end

--- FindByType 返回 Entity：直接读 .Player 会报 no member named Player；必须 ToFamiliar
local function get_familiar_player(ent)
	local fam = as_familiar(ent)
	if fam then
		local ok, p = pcall(function() return fam.Player end)
		if ok and p then return p end
	end
	return auxi.check_spawner_player(ent)
end

local function set_familiar_player(ent, player)
	local fam = as_familiar(ent)
	if not fam or not player then return end
	pcall(function() fam.Player = player end)
end

Familiar_Control_Selector.register(Familiar_Control_Selector.BLUEPRINT, 200, function(fam)
	return is_bound(fam)
end)

local function has_forgotten_lullaby(player)
	return player and player:HasTrinket(TrinketType.TRINKET_FORGOTTEN_LULLABY)
end

local function has_bffs(player)
	return player and player:HasCollectible(CollectibleType.COLLECTIBLE_BFFS)
end

local function has_baby_bender(player)
	return player and player:HasTrinket(TrinketType.TRINKET_BABY_BENDER)
		and not player:HasCollectible(CollectibleType.COLLECTIBLE_SPOON_BENDER)
end

local function dir_to_direction(vec)
	if not vec or vec:Length() < 0.01 then
		return Direction.NO_DIRECTION
	end
	return auxi.GetDirectionByAngle(vec:GetAngleDegrees())
end

local function follow_slot(air, fam)
	local bind = bind_data(fam)
	local idx = bind and bind.slot_index or 0
	local count = math.max(1, bind and bind.slot_count or 1)
	local player = bind and bind.player

	-- 环绕队形属于朋友项链兼容，不是制造宝宝的默认行为。
	if player and player:HasTrinket(TrinketType.TRINKET_FRIENDSHIP_NECKLACE) then
		local angle = Game():GetFrameCount() * (item.friendship_angular_speed or 2)
			+ idx * 360 / count
		return air.Position + Vector.FromAngle(angle) * (item.friendship_radius or 44)
	end

	-- 普通队形：链式软约束；前一只已移除时回退到 Flight，避免断链钉死。
	local leader = bind and bind.follow_leader or air
	if not auxi.check_all_exists(leader) then
		leader = air
		if bind then bind.follow_leader = air end
	end
	local leashed = player and player:HasTrinket(TrinketType.TRINKET_CHILD_LEASH)
	local start_distance = leashed and 20 or (item.follow_start_distance or 40)
	local stop_distance = leashed and 10 or (item.follow_stop_distance or 20)
	local d = fam:GetData()
	d[item.own_key.."follow_state"] = d[item.own_key.."follow_state"] or {}
	return item.external_chain_target(leader, fam, start_distance, stop_distance, d[item.own_key.."follow_state"])
end

local function apply_soft_follow_velocity(fam, target, state)
	if not fam or not target then return end
	state = state or {}
	local delta = target - fam.Position
	local dist = delta:Length()
	local allow_snap = state.allow_snap ~= false
	if allow_snap and (state.need_snap or dist > (item.snap_dist or 120)) then
		fam.Position = target
		fam.Velocity = Vector.Zero
		state.need_snap = nil
		return
	end
	-- 弹簧式跟随：只写 Velocity，由引擎插值移动（与角色模拟 Incubus 一致）。
	local vmax = tonumber(state.max_speed) or item.follow_soft_max_speed or 10
	local response = math.max(0.01, math.min(1, tonumber(state.response) or item.follow_response or 0.16))
	local speed_gain = tonumber(state.speed_gain) or item.follow_speed_gain or 0.14
	local distance_bias = tonumber(state.distance_bias) or item.follow_distance_bias or 20
	local desired = Vector.Zero
	if dist > 0.01 then
		local desired_speed = math.min(vmax, math.max(0, dist - distance_bias) * speed_gain)
		desired = delta:Resized(desired_speed)
	end
	local current = fam.Velocity or Vector.Zero
	local vel = current * (1 - response) + desired * response
	if desired:Length() < 0.01 and vel:Length() < 0.05 then vel = Vector.Zero end
	if vel:Length() > vmax then vel = vel:Resized(vmax) end
	fam.Velocity = vel
end

--- keep_vanilla_ai 跟随：对齐 My Emblem——FollowPosition + 强 Velocity，不能只靠软弹簧。
--- 原版 FollowParent/自走会在 AI 里写位移；软弹簧在 FAMILIAR_UPDATE 盖不过，表现为「完全没挪」。
--- 近距禁止保底高速（旧 max(6,…) 会在 Flight 重合处来回抖）。
local function drive_keep_vanilla_follow(fam, target, air, bind)
	if not fam or not target then return end
	if fam.FollowPosition then
		fam:FollowPosition(target)
	end
	local delta = target - fam.Position
	local dist = delta:Length()
	local vmax = 18
	local settle = 8
	local blend = 0.55
	if dist > settle then
		local speed = math.min(vmax, (dist - settle) * 0.4)
		local desired = delta:Resized(speed)
		local cur = fam.Velocity or Vector.Zero
		fam.Velocity = cur * (1 - blend) + desired * blend
		if fam.Velocity:Length() > vmax then
			fam.Velocity = fam.Velocity:Resized(vmax)
		end
	else
		-- 末端：快速衰减到停，避免与 Flight 叠影抖动
		local cur = fam.Velocity or Vector.Zero
		fam.Velocity = cur * 0.2
		if fam.Velocity:Length() < 0.35 then
			fam.Velocity = Vector.Zero
		end
	end
	local center_po_y = FAMILIAR_CENTER_POSITION_Y
	if air and air.PositionOffset then
		fam.PositionOffset = Vector(air.PositionOffset.X, air.PositionOffset.Y + center_po_y)
	end
	-- Flight 画在前：宝宝 DepthOffset 略低 1~2
	if air and fam.DepthOffset ~= nil then
		fam.DepthOffset = (tonumber(air.DepthOffset) or 0) - 2
	end
	if bind then
		bind.vel = fam.Velocity
	end
end

--- 每逻辑帧向 Flight 追加一个轨迹采样（同帧多次调用只写一次）
local function ensure_air_path_trail(air)
	if not air then return nil end
	local ad = air:GetData()
	local frame = Game():GetFrameCount()
	if ad[item.own_key..TRAIL_FRAME_KEY] == frame then
		return ad[item.own_key..TRAIL_KEY]
	end
	ad[item.own_key..TRAIL_FRAME_KEY] = frame
	local trail = ad[item.own_key..TRAIL_KEY]
	if type(trail) ~= "table" then
		trail = {}
		ad[item.own_key..TRAIL_KEY] = trail
	end
	trail[#trail + 1] = Vector(air.Position.X, air.Position.Y)
	while #trail > TRAIL_MAX_LEN do
		table.remove(trail, 1)
	end
	return trail
end

--- 430/431/426：顺滑复刻 Flight 轨迹；trail_index 越大相位越落后。
--- 禁止每帧 Position 硬钉 + Velocity=0（30Hz 阶跃、渲染无插值）。只写 Velocity 追上采样点。
local function drive_trail_follow(fam, air, bind)
	if not fam or not air then return end
	if fam.RemoveFromDelayed then
		fam:RemoveFromDelayed()
	end
	if fam.SetMoveDelayNum then
		pcall(function() fam:SetMoveDelayNum(0) end)
	end
	local trail = ensure_air_path_trail(air)
	if not trail or #trail == 0 then return end
	local slot = math.max(1, math.floor(tonumber(bind and bind.trail_index) or 1))
	local lag = slot * TRAIL_PHASE_LAG
	local hi = #trail - lag
	if hi < 1 then hi = 1 end
	local target = trail[hi]
	if not target then return end
	if fam.FollowPosition then
		fam:FollowPosition(target)
	end
	local delta = target - fam.Position
	local dist = delta:Length()
	local settle = 6
	if dist > TRAIL_SNAP_DIST then
		-- 装配/换房失联：允许一次硬钉，下帧恢复速度跟随
		fam.Position = Vector(target.X, target.Y)
		fam.Velocity = Vector.Zero
	elseif dist > settle then
		-- Velocity≈超出 settle 的残差：近距不保底高速，避免叠 Flight 抖动
		local desired = delta:Resized(dist - settle)
		local cur = fam.Velocity or Vector.Zero
		local blend = TRAIL_VEL_BLEND
		fam.Velocity = cur * (1 - blend) + desired * blend
	else
		local cur = fam.Velocity or Vector.Zero
		fam.Velocity = cur * 0.15
		if fam.Velocity:Length() < 0.3 then
			fam.Velocity = Vector.Zero
		end
	end
	local center_po_y = FAMILIAR_CENTER_POSITION_Y
	if air.PositionOffset then
		fam.PositionOffset = Vector(air.PositionOffset.X, air.PositionOffset.Y + center_po_y)
	end
	if air and fam.DepthOffset ~= nil then
		fam.DepthOffset = (tonumber(air.DepthOffset) or 0) - 2
	end
	if bind then
		bind.vel = fam.Velocity
		bind.trail_target = target
	end
end

local function get_intent(air)
	local Air = get_air_flight()
	if Air.get_craft_aux_fire_intent then
		return Air.get_craft_aux_fire_intent(air)
	end
	return {should_shoot = false, aim_direction = nil, aim_pos = nil}
end

-- synthetic 宝宝直接 Remove；禁止改 Player / 禁止改玩家一命库存。
local function is_craft_revive_real_variant(variant)
	return variant == FamiliarVariant.ONE_UP
		or variant == FamiliarVariant.DEAD_CAT
end

local function remove_synthetic_familiar(fam)
	if not fam then return end
	-- 原版复活宝宝绝不能 Remove / 清 Player；解绑即可
	if is_craft_revive_real_variant(fam.Variant) then
		local d = fam:GetData()
		d[item.own_key..BIND_KEY] = nil
		return
	end
	fam:GetData()[item.own_key..RETIRED_KEY] = true
	fam.Visible = false
	fam.Velocity = Vector(0, 0)
	fam:Remove()
end

function item.release_familiar(fam, reason)
	if not fam then return end
	local d = fam:GetData()
	local bind = d[item.own_key..BIND_KEY]
	if not bind then return end
	restore_bound_weapons(fam)
	ACTIVE_BOUND[fam] = nil
	Familiar_Control_Selector.invalidate(fam)
	local adapter = item.ADAPTERS[fam.Variant]
	if adapter and adapter.release then
		pcall(adapter.release, adapter, fam, bind, reason)
	end
	d[item.own_key..BIND_KEY] = nil
	d[item.own_key..CD_KEY] = nil
	d[item.own_key..HEAD_KEY] = nil
	d[item.own_key..SNAP_KEY] = nil
	d[item.own_key..TICK_KEY] = nil
	d[item.own_key.."follow_state"] = nil
	d[item.own_key.."duct_position"] = nil
	local queue_released = Familiar_Follower_Arbiter.release(fam, Familiar_Control_Selector.BLUEPRINT)
	local original = d[item.own_key..ORIGINAL_STATE_KEY]
	if original and not bind.synthetic then
		fam.Visible = original.visible ~= false
		if original.color then fam.Color = original.color end
		if original.position_offset then fam.PositionOffset = original.position_offset end
		if original.sprite_offset then fam.SpriteOffset = original.sprite_offset end
		local sprite = fam:GetSprite()
		if sprite and original.flip_x ~= nil then sprite.FlipX = original.flip_x end
	end
	if bind.synthetic then
		d[item.own_key..ORIGINAL_STATE_KEY] = nil
		remove_synthetic_familiar(fam)
		return
	end
	-- EvaluateItems 可能在本帧稍后才真正销毁失去道具的原版宝宝；短暂隔离，禁止旧实例立刻回绑。
	d[item.own_key..RELEASED_FRAME_KEY] = Game():GetFrameCount()
	d.IsFollowing = nil
	local player = bind.player
	if player and auxi.check_all_exists(player) then
		set_familiar_player(fam, player)
	end
	-- 兼容热重载前已经绑定、尚无 Arbiter state 的实体；正常新绑定一律由裁断器恢复。
	if not queue_released and original then
		if original.is_follower == true then
			if fam.AddToFollowers then fam:AddToFollowers() end
		elseif fam.RemoveFromFollowers then
			fam:RemoveFromFollowers()
		end
		if original.is_delayed == true then
			if fam.AddToDelayed then fam:AddToDelayed() end
			if original.move_delay_num ~= nil and fam.SetMoveDelayNum then
				pcall(function() fam:SetMoveDelayNum(original.move_delay_num) end)
			end
		elseif fam.RemoveFromDelayed then
			fam:RemoveFromDelayed()
		end
	end
	d.IsFollowing = original and original.is_follower == true or nil
	d[item.own_key..ORIGINAL_STATE_KEY] = nil
end

--- 制造复活跟随展示：MeusNil + 原版 ANM2；禁止 Spawn 无主 FamiliarVariant.ONE_UP / DEAD_CAT。
--- 跟随必须走与制造宝宝相同的链式软跟随（只写 Velocity）；禁止每帧钉死 Position。
local function spawn_craft_revive_fx(air, src)
	local enums = get_enums()
	local Nil_holder = get_nil_holder()
	local spawn_pos = air.Position
	local fx = Isaac.Spawn(
		EntityType.ENTITY_EFFECT,
		enums.Entities.ID_EFFECT_MeusNIL,
		0,
		spawn_pos,
		Vector.Zero,
		air
	)
	fx = fx and (fx:ToEffect() or fx) or nil
	if not fx then return nil end
	fx:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
	fx.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	fx.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	local anim = (src and src.anim) or "Float"
	local s = fx:GetSprite()
	if s and src and src.anm2 then
		s:Load(src.anm2, true)
		s:Play(anim, true)
	end
	local d = fx:GetData()
	d[item.own_key.."craft_revive_fx"] = src and src.key or true
	d.nil_mode = "visual_only"
	d.skip_nil_distance_cull = true
	d.removecd = 999999
	d.Params = d.Params or {}
	d.Params.remove_with_ent = air
	-- 跳过 Nil_holder 自带硬跟随/运动；由本模块 soft follow 驱动
	d[Nil_holder.own_key.."work"] = function() return true end
	d[item.own_key.."need_snap"] = true
	d[item.own_key.."follow_state"] = {}
	return fx
end

local function revive_fx_map(air)
	local ad = air:GetData()
	local map = ad[item.own_key..REVIVE_FX_MAP_KEY]
	if type(map) ~= "table" then
		map = {}
		ad[item.own_key..REVIVE_FX_MAP_KEY] = map
		-- 旧单键 one_up_fx 迁入
		local legacy = ad[item.own_key..ONE_UP_FX_KEY]
		if auxi.check_all_exists(legacy) then
			map.one_up = legacy
			ad[item.own_key..ONE_UP_FX_KEY] = nil
		end
	end
	return map
end

local function drive_craft_revive_soft_follow(fx, leader, air, player)
	if not auxi.check_all_exists(fx) then return end
	if not auxi.check_all_exists(leader) then leader = air end
	local d = fx:GetData()
	d[item.own_key.."follow_state"] = d[item.own_key.."follow_state"] or {}
	local leashed = player and player:HasTrinket(TrinketType.TRINKET_CHILD_LEASH)
	local start_distance = leashed and 20 or (item.follow_start_distance or 40)
	local stop_distance = leashed and 10 or (item.follow_stop_distance or 20)
	local target
	local drive = {
		allow_snap = false,
		speed_gain = item.follow_speed_gain or 0.14,
		response = item.follow_response or 0.16,
		max_speed = item.follow_soft_max_speed or 10,
		distance_bias = leashed and 10 or (item.follow_distance_bias or 20),
	}
	if player and player:HasTrinket(TrinketType.TRINKET_FRIENDSHIP_NECKLACE) then
		-- 与制造宝宝一致：项链时环绕 Flight，不用链式滞回
		local angle = Game():GetFrameCount() * (item.friendship_angular_speed or 2)
		target = air.Position + Vector.FromAngle(angle) * (item.friendship_radius or 44)
		drive.distance_bias = 0
		drive.speed_gain = 0.35
		drive.response = 0.45
		drive.max_speed = 14
	elseif player and player:HasTrinket(TrinketType.TRINKET_DUCT_TAPE) then
		d[item.own_key.."duct_position"] = d[item.own_key.."duct_position"]
			or Vector(fx.Position.X, fx.Position.Y)
		target = d[item.own_key.."duct_position"]
		drive.distance_bias = 0
		drive.speed_gain = 0.35
		drive.response = 0.45
		drive.max_speed = 14
	else
		d[item.own_key.."duct_position"] = nil
		target = item.external_chain_target(
			leader, fx, start_distance, stop_distance, d[item.own_key.."follow_state"]
		)
	end
	if d[item.own_key.."need_snap"] then
		drive.allow_snap = true
		drive.need_snap = true
		d[item.own_key.."need_snap"] = nil
	end
	apply_soft_follow_velocity(fx, target, drive)
	if air and air.PositionOffset then
		fx.PositionOffset = Vector(air.PositionOffset.X, air.PositionOffset.Y)
	end
	fx.DepthOffset = (air.DepthOffset or 0) - 2
end

local function air_has_bound_revive_familiar(air, variant)
	if not air or not variant then return false end
	for _, fam in ipairs(find_all_bound_for_air(air, variant)) do
		if auxi.check_all_exists(fam) then return true end
	end
	return false
end

--- MeusNil 仅作无真实宝宝时的审计/兜底；玩家实持复活道具时优先真实 Familiar。
--- opts = {chain_leader=, player=}
function item.sync_craft_revive_followers(air, extras, rec, opts)
	if not air then return end
	local CraftProfile = get_craft_profile()
	extras = extras or {}
	opts = opts or {}
	local map = revive_fx_map(air)
	local player = opts.player
	local leader = opts.chain_leader or air
	if not auxi.check_all_exists(leader) then leader = air end
	for _, src in ipairs(CraftProfile.CRAFT_REVIVE_SOURCES or {}) do
		if src.follower then
			local recipe_want = extras[src.key] == true
			local has_real = src.familiar_variant
				and air_has_bound_revive_familiar(air, src.familiar_variant)
			local player_has = CraftProfile.craft_revive_player_has(player, src)
			local virtual = CraftProfile.craft_has_virtual_source_for(rec, src.id, {
				prototype_alive = player and prototype_alive_for(player, src.id) or nil,
			})
			-- 有真实宝宝 → 绝不叠 MeusNil；道具已消失且非 audit/prototype 虚拟源 → 不伪装
			local want_nil = recipe_want and not has_real and (player_has or virtual)
			local fx = map[src.key]
			if want_nil then
				if not auxi.check_all_exists(fx) then
					fx = spawn_craft_revive_fx(air, src)
					map[src.key] = fx
					if src.key == "one_up" then
						air:GetData()[item.own_key..ONE_UP_FX_KEY] = fx
					end
				end
				if auxi.check_all_exists(fx) then
					local d = fx:GetData()
					d.removecd = 999999
					d.skip_nil_distance_cull = true
					drive_craft_revive_soft_follow(fx, leader, air, player)
					leader = fx
					local dimmed = CraftProfile.craft_revive_follower_dimmed(rec, src)
					if dimmed then
						fx:SetColor(REVIVE_SPENT_COLOR, 2, 45, false, false)
					else
						fx:SetColor(REVIVE_LIVE_COLOR, 1, 45, false, false)
					end
					local s = fx:GetSprite()
					local anim = src.anim or "Float"
					if s then
						if not s:IsPlaying(anim) then s:Play(anim, true) end
						s:Update()
					end
				end
			else
				if auxi.check_all_exists(fx) then fx:Remove() end
				map[src.key] = nil
				if src.key == "one_up" then
					air:GetData()[item.own_key..ONE_UP_FX_KEY] = nil
				end
			end
		end
	end
end

function item.sync_craft_one_up_visual(air, want, spent)
	-- 兼容旧调用：转通用 sync
	local extras = {one_up = want and true or false}
	local rec = nil
	if spent then
		rec = {craft_revive_spent = {one_up = 1}, one_up_spent = true}
	end
	item.sync_craft_revive_followers(air, extras, rec)
end

function item.set_craft_revive_spent_visual(air, rec)
	if not air then return end
	local CraftProfile = get_craft_profile()
	local map = revive_fx_map(air)
	for _, src in ipairs(CraftProfile.CRAFT_REVIVE_SOURCES or {}) do
		if src.follower then
			local dimmed = CraftProfile.craft_revive_follower_dimmed(rec, src)
			local col = dimmed and REVIVE_SPENT_COLOR or REVIVE_LIVE_COLOR
			local fx = map[src.key]
			if auxi.check_all_exists(fx) then
				fx:SetColor(col, -1, 45, false, false)
			end
			if src.familiar_variant then
				for _, fam in ipairs(find_all_bound_for_air(air, src.familiar_variant)) do
					if auxi.check_all_exists(fam) then
						fam:SetColor(col, -1, 45, false, false)
					end
				end
			end
		end
	end
end

function item.set_craft_one_up_spent_visual(air, spent)
	local rec = spent and {craft_revive_spent = {one_up = 1}, one_up_spent = true} or {craft_revive_spent = {}}
	item.set_craft_revive_spent_visual(air, rec)
end

function item.release_for_air(air)
	if not air then return end
	local air_ptr = GetPtrHash(air)
	local release, seen = {}, {}
	for fam in pairs(ACTIVE_BOUND) do
		local alive = active_familiar_alive(fam)
		local bind = alive and bind_data(fam) or nil
		if not alive or not bind then
			ACTIVE_BOUND[fam] = nil
		elseif bind.air_ptr == air_ptr then
			local ptr = GetPtrHash(fam)
			if not seen[ptr] then
				seen[ptr] = true
				release[#release + 1] = fam
			end
		end
	end
	for _, fam in ipairs(release) do
		item.release_familiar(fam, "air_release")
	end
	item.sync_craft_revive_followers(air, {}, nil)
end

local function find_unbound(player, variant)
	-- 禁止「无 Player 的最近同变体」兜底：会在 imitate/重获道具当帧过早接管，实体未就绪时表现为隐形，
	-- 且可能把不该认领的宝宝拉进飞行器队列。仅认领已归属本玩家、且至少过了出生帧的未绑定实例。
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, variant, -1, false, false)) do
		local fam = as_familiar(ent)
		if not fam then goto continue end
		local d = fam:GetData()
		local sprite = fam:GetSprite()
		local filename = sprite and sprite:GetFilename() or ""
		local animation = sprite and sprite:GetAnimation() or ""
		local dead = fam.IsDead and fam:IsDead()
		local released_frame = tonumber(d[item.own_key..RELEASED_FRAME_KEY])
		local release_settled = not released_frame or Game():GetFrameCount() - released_frame >= 2
		local initialized = (fam.FrameCount or 0) >= 2
			and filename ~= "" and animation ~= ""
		if not is_bound(fam)
			and not d[item.own_key..RETIRED_KEY]
			and fam.Visible ~= false
			and not dead
			and release_settled
			and auxi.check_all_exists(fam)
			and initialized
		then
			local p = get_familiar_player(fam)
			if p and auxi.check_for_the_same(p, player) then
				return fam
			end
		end
		::continue::
	end
	return nil
end

local function find_bound_for_air(air, variant)
	local all = find_all_bound_for_air(air, variant)
	return all[1]
end

find_all_bound_for_air = function(air, variant)
	local out = {}
	if not air then return out end
	local air_ptr = GetPtrHash(air)
	local seen = {}
	for fam in pairs(ACTIVE_BOUND) do
		local alive = active_familiar_alive(fam)
		local bind = alive and bind_data(fam) or nil
		if not alive or not bind then
			ACTIVE_BOUND[fam] = nil
		elseif fam.Variant == variant and bind.air_ptr == air_ptr then
			local ptr = GetPtrHash(fam)
			if not seen[ptr] then
				seen[ptr] = true
				out[#out + 1] = fam:ToFamiliar() or fam
			end
		end
	end
	table.sort(out, function(a, b) return (a.InitSeed or 0) < (b.InitSeed or 0) end)
	return out
end

local function adapter_desired_count(adapter, extras, player, rec, profile)
	if not adapter or extras[adapter.extra_key] ~= true then return 0 end
	local CraftProfile = get_craft_profile()
	-- 真实复活宝宝：道具已从玩家消失则不再认领（避免再叠 MeusNil）
	if adapter.craft_revive_real then
		local src = CraftProfile.CRAFT_REVIVE_BY_KEY and CraftProfile.CRAFT_REVIVE_BY_KEY[adapter.extra_key]
		if not CraftProfile.craft_revive_player_has(player, src) then
			return 0
		end
		return math.max(1, tonumber(adapter.instances) or 1)
	end
	-- 捕捉原版宝宝类：材料失效则 desired=0，停止 find_unbound。
	-- always_spawn_synthetic 不依赖原版实体，缺料时暂维持 extras（后续再定是否一并失效）。
	if not adapter.always_spawn_synthetic then
		local col = tonumber(adapter.collectible)
		if col and col > 0 then
			if not rec then return 0 end
			if not CraftProfile.craft_familiar_material_available(player, rec, col, {
				prototype_alive = prototype_alive_for(player, col),
			}) then
				return 0
			end
		end
	end
	-- 份数：优先 counts[collectible]（与环绕物一致）；list 键常与 extra_key 不同（bobby≠brother_bobby）
	local copies = 0
	local col = tonumber(adapter.collectible)
	if profile and profile.counts and col and col > 0 then
		copies = tonumber(profile.counts[col]) or tonumber(profile.counts[tostring(col)]) or 0
	end
	if copies <= 0 and profile and profile.list then
		local list = profile.list
		local map = CraftProfile.CRAFT_FAMILIAR_EXTRA_LIST_KEY
		local list_key = map and map[adapter.extra_key]
		if list_key then
			copies = tonumber(list[list_key]) or 0
		end
		if copies <= 0 and adapter.extra_key then
			copies = tonumber(list[adapter.extra_key]) or 0
		end
	end
	if copies <= 0 then copies = 1 end
	local per = math.max(1, tonumber(adapter.instances) or 1)
	return copies * per
end

--- 按配方 extras 认领/释放各 adapter 对应宝宝；不驱动 tick
function item.sync_air_flight(air, player, profile)
	if not air or not player then return end
	local bp = get_blueprint()
	local uid = air:GetData()[bp.own_key.."craft_uid"]
	local air_ptr = GetPtrHash(air)
	local extras = profile and profile.extras or {}

	local craft_rec = uid and bp.find_craft(player, uid) or nil
	local CraftProfile = get_craft_profile()

	-- 本帧认领结果就地收集；编队/轨迹重建禁止再 FindByType 扫全场
	local collected = {}

	for variant, adapter in pairs(item.ADAPTERS) do
		local desired = adapter_desired_count(adapter, extras, player, craft_rec, profile)
		local bounds = find_all_bound_for_air(air, variant)
		-- 剔除已销毁实体上的残留 bind 引用
		for i = #bounds, 1, -1 do
			if not auxi.check_all_exists(bounds[i]) then
				table.remove(bounds, i)
			end
		end
		while #bounds > desired do
			item.release_familiar(table.remove(bounds), "recipe_drop")
		end
		for _, bound in ipairs(bounds) do
			ACTIVE_BOUND[bound] = true
			local bind = bind_data(bound)
			if bind then
				bind.air = air
				bind.player = player
				bind.craft_uid = uid
				bind.profile = profile
				bind.adapter_name = adapter.name
			end
		end
		while #bounds < desired do
			-- craft_revive_real：只认领玩家真实宝宝，禁止 Spawn/synthetic
			local fam = adapter.always_spawn_synthetic and nil or find_unbound(player, variant)
			local synthetic = false
			if not fam and adapter.spawn and not adapter.craft_revive_real then
				local ok, spawned = pcall(adapter.spawn, adapter, air, player, profile)
				if ok and spawned then
					fam = spawned:ToFamiliar() or spawned
					synthetic = true
				end
			end
			if fam and auxi.check_all_exists(fam) then
				local d = fam:GetData()
				local sprite = fam:GetSprite()
				Familiar_Follower_Arbiter.claim(fam, Familiar_Control_Selector.BLUEPRINT, {
					followers = true,
					delayed = adapter.trail_follow == true,
				})
				local queue_original = Familiar_Follower_Arbiter.original_state(fam)
				d[item.own_key..RETIRED_KEY] = nil
				d[item.own_key..RELEASED_FRAME_KEY] = nil
				if not synthetic and not d[item.own_key..ORIGINAL_STATE_KEY] then
					local move_delay_num = nil
					if fam.GetMoveDelayNum then
						local ok, value = pcall(function() return fam:GetMoveDelayNum() end)
						if ok then move_delay_num = value end
					end
						d[item.own_key..ORIGINAL_STATE_KEY] = {
						visible = fam.Visible,
						color = fam.Color,
						position_offset = fam.PositionOffset,
						sprite_offset = fam.SpriteOffset,
						flip_x = sprite and sprite.FlipX or nil,
						is_follower = queue_original.is_follower,
						is_delayed = queue_original.is_delayed,
						move_delay_num = queue_original.move_delay_num or move_delay_num,
					}
				end
				-- 必须在采集 IsFollower / IsDelayed 后才离队，否则释放时无法恢复原身份。
				Familiar_Follower_Arbiter.maintain(fam)
				fam.Visible = true
				d[item.own_key..BIND_KEY] = {
					craft_uid = uid,
					air = air,
					air_ptr = air_ptr,
					player = player,
					player_ptr = GetPtrHash(player),
					profile = profile,
					adapter_name = adapter.name,
					variant = variant,
					synthetic = synthetic,
				}
				ACTIVE_BOUND[fam] = true
				Familiar_Control_Selector.invalidate(fam)
				d[item.own_key..CD_KEY] = 0
				d[item.own_key..HEAD_KEY] = 0
				-- soft_rebind / keep_vanilla_ai / trail_follow：装配禁 Position 瞬移
				if not (adapter.soft_rebind or adapter.keep_vanilla_ai or adapter.trail_follow) then
					d[item.own_key..SNAP_KEY] = true
				end
				if adapter.trail_follow then
					detach_trail_vanilla_delay(fam)
				end
				if adapter.acquire then
					pcall(adapter.acquire, adapter, fam, d[item.own_key..BIND_KEY])
				end
				bounds[#bounds + 1] = fam
			else
				break
			end
		end
		for i, fam in ipairs(bounds) do
			local bind = bind_data(fam)
			if bind then
				bind.instance_index = i
				bind.instance_count = #bounds
			end
			if bind and auxi.check_all_exists(fam) then
				collected[#collected + 1] = {
					fam = fam,
					variant = variant,
					bind = bind,
					adapter = adapter,
				}
			end
		end
		-- 真实复活宝宝：按 spent 暗下
		if adapter.craft_revive_real and CraftProfile.CRAFT_REVIVE_BY_KEY then
			local src = CraftProfile.CRAFT_REVIVE_BY_KEY[adapter.extra_key]
			if src then
				local dimmed = CraftProfile.craft_revive_follower_dimmed(craft_rec, src)
				local col = dimmed and REVIVE_SPENT_COLOR or REVIVE_LIVE_COLOR
				for _, fam in ipairs(bounds) do
					if auxi.check_all_exists(fam) then
						fam:SetColor(col, 2, 45, false, false)
					end
				end
			end
		end
	end
	-- 编队 / 轨迹：只用上面认领结果，禁止再 FindByType
	local bound_list = {}
	local trail_list = {}
	for _, entry in ipairs(collected) do
		local fam, bind, adapter, variant = entry.fam, entry.bind, entry.adapter, entry.variant
		if not (bind and bind.air_ptr == air_ptr and auxi.check_all_exists(fam)) then
			goto continue_collect
		end
		if adapter.trail_follow then
			trail_list[#trail_list + 1] = entry
		else
			local leaving = false
			if adapter.is_leaving_formation then
				local ok, ret = pcall(adapter.is_leaving_formation, adapter, fam, bind)
				leaving = ok and ret == true
			end
			if not adapter.exclude_from_formation and not leaving then
				bound_list[#bound_list + 1] = entry
			end
		end
		::continue_collect::
	end
	table.sort(bound_list, function(a, b)
		local ap = tonumber(a.adapter and a.adapter.formation_priority) or 0
		local bp = tonumber(b.adapter and b.adapter.formation_priority) or 0
		if ap ~= bp then return ap < bp end
		if (a.variant or 0) == (b.variant or 0) then
			return (a.fam.InitSeed or 0) < (b.fam.InitSeed or 0)
		end
		return (a.variant or 0) < (b.variant or 0)
	end)
	local prev_alive = air
	for i = 1, #bound_list do
		bound_list[i].bind.slot_index = i - 1
		bound_list[i].bind.slot_count = #bound_list
		bound_list[i].bind.follow_leader = prev_alive
		prev_alive = bound_list[i].fam
	end
	table.sort(trail_list, function(a, b)
		local ap = tonumber(a.adapter and a.adapter.trail_priority) or 0
		local bp = tonumber(b.adapter and b.adapter.trail_priority) or 0
		if ap ~= bp then return ap < bp end
		if (a.variant or 0) == (b.variant or 0) then
			return (a.fam.InitSeed or 0) < (b.fam.InitSeed or 0)
		end
		return (a.variant or 0) < (b.variant or 0)
	end)
	for i = 1, #trail_list do
		local bind = trail_list[i].bind
		bind.trail_index = i
		bind.trail_count = #trail_list
		bind.follow_leader = air
		bind.slot_index = nil
		bind.slot_count = nil
	end
	if #trail_list > 0 then
		ensure_air_path_trail(air)
	end
	-- MeusNil 兜底：仅无真实复活宝宝时（审计或真实宝宝暂缺）
	local chain_leader = prev_alive
	if not auxi.check_all_exists(chain_leader) then chain_leader = air end
	item.sync_craft_revive_followers(air, extras, craft_rec, {
		chain_leader = chain_leader,
		player = player,
	})
end

-- 兼容旧名
item.sync_air_flight_compat = item.sync_air_flight

local function do_follow(fam, air, d, adapter, bind, intent)
	-- 原版素材的可见中心比中心式 Flight 原点高约 16 screen px。将换算后的修正写进 PO，
	-- 这样泪弹发射口会继承同一高度；不可再向 SpriteOffset 重复追加 16px。
	local center_po_y = FAMILIAR_CENTER_POSITION_Y
	-- 完全自定义移动的 adapter（如 Gemini）自行维护 Velocity；
	-- 仅消费 NEW_ROOM / teleport 的 SNAP_KEY 硬拉。远距必须靠 adapter 内软拉扯，禁止 dist 瞬移。
	if adapter and adapter.custom_move then
		if adapter.sync_air_position_offset ~= false and air and air.PositionOffset then
			fam.PositionOffset = Vector(air.PositionOffset.X, air.PositionOffset.Y + center_po_y)
		elseif adapter.sync_air_position_offset == false then
			-- Gemini 等自绘实体不能复制 Flight PO；它们不使用公共模拟射击，保留等效屏幕修正。
			if not bind.center_sprite_offset_base then
				local original = d[item.own_key..ORIGINAL_STATE_KEY]
				local base = original and original.sprite_offset or fam.SpriteOffset or Vector.Zero
				bind.center_sprite_offset_base = Vector(base.X, base.Y)
			end
			local base = bind.center_sprite_offset_base
			fam.SpriteOffset = Vector(base.X, base.Y + 16)
		end
		local need_snap = d[item.own_key..SNAP_KEY]
		if need_snap then
			d[item.own_key..SNAP_KEY] = nil
			if air then
				fam.Position = Vector(air.Position.X, air.Position.Y)
				fam.Velocity = Vector.Zero
				if adapter.on_snap then
					pcall(adapter.on_snap, adapter, fam, bind)
				end
			end
		end
		return
	end
	-- Chubby / Gurdy 冲刺：暂时脱队，只同步高度，不写 Velocity。
	-- 换房/传送 SNAP 优先于脱队；远距不在此瞬移（冲刺自己有 return）。
	if adapter and adapter.is_leaving_formation then
		local ok, leaving = pcall(adapter.is_leaving_formation, adapter, fam, bind)
		if ok and leaving then
			if air and air.PositionOffset then
				fam.PositionOffset = Vector(air.PositionOffset.X, air.PositionOffset.Y + center_po_y)
			end
			local need_snap = d[item.own_key..SNAP_KEY]
			if need_snap and air then
				d[item.own_key..SNAP_KEY] = nil
				fam.Position = Vector(air.Position.X, air.Position.Y)
				fam.Velocity = Vector.Zero
				if adapter.on_snap then
					pcall(adapter.on_snap, adapter, fam, bind)
				end
				-- on_snap（如 dash recycle）后应已回编队；继续走普通 follow
			else
				if need_snap then d[item.own_key..SNAP_KEY] = nil end
				return
			end
		end
	end

	local player = bind and bind.player
	local target = nil
	local drive = {
		allow_snap = false,
		speed_gain = item.follow_speed_gain or 0.14,
		response = item.follow_response or 0.16,
		max_speed = item.follow_soft_max_speed or 10,
		distance_bias = item.follow_distance_bias or 20,
	}

	if player and player:HasTrinket(TrinketType.TRINKET_DUCT_TAPE) then
		d[item.own_key.."duct_position"] = d[item.own_key.."duct_position"]
			or Vector(fam.Position.X, fam.Position.Y)
		target = d[item.own_key.."duct_position"]
		drive.distance_bias = 0
		drive.speed_gain = 0.35
		drive.response = 0.45
		drive.max_speed = 14
	else
		d[item.own_key.."duct_position"] = nil
		if adapter and adapter.follow_position then
			local ok, pos = pcall(adapter.follow_position, adapter, {
				familiar = fam, air = air, bind = bind, intent = intent,
			})
			if ok and pos then
				target = pos
				-- Twisted Pair 等固定槽：紧贴目标，接近旧版硬跟随。
				drive.distance_bias = 0
				drive.speed_gain = 0.35
				drive.response = 0.45
				drive.max_speed = 14
			end
		end
		if not target then
			if player and player:HasTrinket(TrinketType.TRINKET_FRIENDSHIP_NECKLACE) then
				target = follow_slot(air, fam)
				drive.distance_bias = 0
				drive.speed_gain = 0.35
				drive.response = 0.45
				drive.max_speed = 14
			else
				local leashed = player and player:HasTrinket(TrinketType.TRINKET_CHILD_LEASH)
				drive.distance_bias = leashed and 10 or (item.follow_distance_bias or 20)
				target = follow_slot(air, fam)
			end
		end
	end

	if d[item.own_key..SNAP_KEY] then
		drive.allow_snap = true
		drive.need_snap = true
		d[item.own_key..SNAP_KEY] = nil
	end

	apply_soft_follow_velocity(fam, target, drive)

	-- 跟随飞行器高度，攻击/渲染与主机一致
	if air and air.PositionOffset then
		fam.PositionOffset = Vector(air.PositionOffset.X, air.PositionOffset.Y + center_po_y)
	end
	-- 普通跟随也压一层 Depth，避免与 Flight 重合时盖住机身
	if air and fam.DepthOffset ~= nil then
		fam.DepthOffset = (tonumber(air.DepthOffset) or 0) - 2
	end
end

local function tick_cooldown(fam, player, d, adapter, bind)
	if item.debug_freeze_cooldown then
		return
	end
	-- Rotten 等：存活苍蝇期间暂停冷却递减
	if adapter and adapter.pause_cooldown then
		local ok, pause = pcall(adapter.pause_cooldown, adapter, fam, player, bind)
		if ok and pause then
			local head = tonumber(d[item.own_key..HEAD_KEY]) or 0
			if head > 0 then d[item.own_key..HEAD_KEY] = head - 1 end
			fam.FireCooldown = tonumber(d[item.own_key..CD_KEY]) or 0
			if fam.HeadFrameDelay ~= nil then
				fam.HeadFrameDelay = d[item.own_key..HEAD_KEY]
			end
			return
		end
	end
	local cd = tonumber(d[item.own_key..CD_KEY]) or 0
	local step = 1
	if has_forgotten_lullaby(player) and (not adapter or adapter.supports_lullaby ~= false) then
		step = 2
	end
	d[item.own_key..CD_KEY] = math.max(0, cd - step)
	local head = tonumber(d[item.own_key..HEAD_KEY]) or 0
	if head > 0 then
		d[item.own_key..HEAD_KEY] = head - 1
	end
	-- 镜像给第三方/动画读取；不以引擎字段为事实来源
	fam.FireCooldown = d[item.own_key..CD_KEY]
	if fam.HeadFrameDelay ~= nil then
		fam.HeadFrameDelay = d[item.own_key..HEAD_KEY]
	end
end

local function update_anim(fam, shoot_dir, d, head_override, adapter)
	if not fam or (fam.Exists and not fam:Exists()) then return end
	local s = fam:GetSprite()
	if not s then return end
	-- 无方向切片的 anm2（如 1up 仅 Idle/Float）：禁止拼 FloatUp/FloatSide
	local fixed = adapter and adapter.anim_fixed
	if type(fixed) == "string" and fixed ~= "" then
		if not s:IsPlaying(fixed) then
			s:Play(fixed, true)
		end
		fam.FlipX = false
		return
	end
	local head = tonumber(head_override)
	if head == nil then head = tonumber(d[item.own_key..HEAD_KEY]) or 0 end
	local dir = shoot_dir or Direction.DOWN
	if dir == Direction.NO_DIRECTION then
		dir = Direction.DOWN
	end
	local suffix = auxi.GetDirName(dir) or "Down"
	local prefix = head > 0 and "FloatShoot" or "Float"
	local anim = prefix .. suffix
	if not s:IsPlaying(anim) then
		s:Play(anim, true)
	end
	fam.FlipX = (dir == Direction.LEFT)
end

--- 非蓝图控制器复用的移动/动画入口。
--- 保持与 full adapter 相同的软跟随、限速和 Float/FloatShoot 动画选择，避免再造近似实现。
function item.drive_external(fam, target, aim_vector, state)
	if not fam or not target then return end
	if auxi.is_time_stopped() then
		fam.Velocity = Vector(0, 0)
		return
	end
	state = state or {}
	apply_soft_follow_velocity(fam, target, state)
	local head = tonumber(state.head_delay) or 0
	if head > 0 then state.head_delay = head - 1 end
	local shoot_dir = dir_to_direction(aim_vector or Vector(0, 1))
	if fam.ShootDirection ~= nil then fam.ShootDirection = shoot_dir end
	local adapter = item.ADAPTERS[fam.Variant]
	update_anim(fam, shoot_dir, fam:GetData(), head, adapter)
end

--- 外部控制器使用的普通宝宝链式跟随目标；与蓝图 follow_slot 的滞回行为一致。
function item.external_chain_target(leader, fam, start_distance, stop_distance, state)
	if not leader or not fam then return fam and fam.Position or nil end
	start_distance = tonumber(start_distance) or (item.follow_start_distance or 40)
	stop_distance = tonumber(stop_distance) or (item.follow_stop_distance or 20)
	state = state or {}
	local dist = fam.Position:Distance(leader.Position)
	if state.following then
		if dist <= stop_distance then state.following = false end
	elseif dist >= start_distance then
		state.following = true
	end
	return state.following and leader.Position or fam.Position
end

--- 普通泪弹工厂：Parent/Spawner 保持宝宝
--- opts 可覆盖 damage / damage_mul / bffs_damage_mul / skip_bffs /
--- projectile_speed / tear_flags / tear_variant / tear_color / tear_scale /
--- falling_speed / falling_acceleration / height / short_range
--- 对小丑等一次 FireProjectile 多发的宝宝：会修正同帧所有新泪弹（伤害/高度/弹速钳制），避免只改返回值、漏改另一发超高速弹。
function item.fire_basic_tear(fam, player, aim_vector, adapter, opts)
	if not fam or not fam.FireProjectile or not aim_vector then return nil end
	adapter = adapter or {}
	opts = opts or {}
	local speed = opts.projectile_speed or adapter.projectile_speed or 10
	local dir_vec = aim_vector
	if dir_vec:Length() > 0.01 then
		dir_vec = dir_vec:Normalized()
	else
		return nil
	end
	local dir = dir_vec * speed
	local capture_multi = opts.capture_multi == true or adapter.capture_multi == true
	local before = capture_multi and {} or nil
	if capture_multi then
		for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_TEAR, -1, -1, false, false)) do
			before[GetPtrHash(ent)] = true
		end
	end
	local tear = fam:FireProjectile(dir)
	if not tear then return nil end
	tear = tear:ToTear() or tear

	local dmg = opts.damage or adapter.damage or 3.5
	dmg = dmg * (tonumber(opts.damage_mul) or 1)
	local allow_bffs = adapter.supports_bffs ~= false and not opts.skip_bffs
	if allow_bffs and has_bffs(player) then
		local bffs_mul = tonumber(opts.bffs_damage_mul) or tonumber(adapter.bffs_damage_mul) or 2
		dmg = dmg * bffs_mul
	end
	local flags = opts.tear_flags or adapter.tear_flags
	local variant = opts.tear_variant or adapter.tear_variant
	local scale = opts.tear_scale or adapter.tear_scale
	local color = opts.tear_color or adapter.tear_color
	local bender = adapter.supports_bender ~= false and has_baby_bender(player)

	local function finish_tear(t, force_dir)
		if not t then return end
		t = t:ToTear() or t
		if opts.falling_speed ~= nil and t.FallingSpeed ~= nil then
			t.FallingSpeed = opts.falling_speed
		end
		if opts.falling_acceleration ~= nil and t.FallingAcceleration ~= nil then
			t.FallingAcceleration = opts.falling_acceleration
		end
		-- 短射程：用 Height/Falling* 落实，禁止只靠降弹速冒充
		if opts.short_range and t.FallingAcceleration ~= nil then
			t.FallingSpeed = opts.falling_speed or 2
			t.FallingAcceleration = opts.falling_acceleration or 1.4
		end
		if t.Parent ~= nil then t.Parent = fam end
		if t.SpawnerEntity ~= nil then t.SpawnerEntity = fam end
		if t.CollisionDamage ~= nil then t.CollisionDamage = dmg end
		if t.Velocity then
			if force_dir and force_dir:Length() > 0.01 then
				-- 单发宝宝：用瞄准方向*弹速
				t.Velocity = force_dir
			elseif t.Velocity:Length() > 0.01 then
				-- 多发宝宝：保留各自角度（V 字），只把速率钳到目标弹速
				t.Velocity = t.Velocity:Resized(speed)
			else
				t.Velocity = dir
			end
		end
		if flags and t.AddTearFlags then t:AddTearFlags(flags) end
		if variant ~= nil and t.ChangeVariant and t.Variant ~= variant then
			t:ChangeVariant(variant)
		end
		if scale and t.Scale then t.Scale = t.Scale * scale end
		if color then t.Color = color end
		if bender and t.AddTearFlags then
			t:AddTearFlags(TearFlags.TEAR_HOMING)
			if not color and not opts.skip_bender_color then
				t.Color = Color(0.4, 0.15, 0.38, 1, 0.27843, 0, 0.4549)
			end
		end
		local apply = opts.apply_tear or adapter.apply_tear
		if apply then
			pcall(apply, adapter, fam, player, t, opts)
		end
		-- 视觉高度与碰撞高度必须拆开：render-only lift 跟随 Flight/宝宝升空，Height 保持
		-- 泪弹正常可命中的弹道值。禁止把约 -40~-65 的巡航 PO 经 offset2height 写进 Height，
		-- 否则泪弹会因高度判定越过地面敌人。实体 PositionOffset 也必须清零，否则会与
		-- 原生 Height 在生成帧叠加，随后被引擎更新成另一高度，形成明显跳变。
		-- 扁石 HYDROBOUNCE：生成帧仍清一次 PO；后续帧勿再清（见 PRE_TEAR_UPDATE）。
		if t.Height ~= nil then
			local off = fam.PositionOffset or Vector(0, 0)
			local bind = bind_data(fam)
			local air = bind and bind.air
			if math.abs(off.Y) < 0.5 and air and air.PositionOffset then
				off = Vector(air.PositionOffset.X, air.PositionOffset.Y)
			end
			-- 仍接近 0：用飞行器巡航高度回退，避免 Height/Offset 都写成贴地
			if math.abs(off.Y) < 0.5 then
				off = Vector(0, -34)
			end
			if opts.short_range then
				t.Height = opts.height or -10
			elseif opts.height ~= nil then
				t.Height = opts.height
			end
			if t.PositionOffset ~= nil then
				t.PositionOffset = Vector.Zero
			end
			if REPENTOGON and ModCallbacks.MC_PRE_TEAR_RENDER then
				arm_owned_tear_visual(t, fam)
			end
		end
	end

	local spawned = {tear}
	if capture_multi then
		spawned = {}
		local fam_ptr = GetPtrHash(fam)
		for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_TEAR, -1, -1, false, false)) do
			if not before[GetPtrHash(ent)] then
				local t = ent:ToTear() or ent
				local spawner = t.SpawnerEntity
				local parent = t.Parent
				local from_fam = (spawner and GetPtrHash(spawner) == fam_ptr)
					or (parent and GetPtrHash(parent) == fam_ptr)
					or (GetPtrHash(t) == GetPtrHash(tear))
				if from_fam then spawned[#spawned + 1] = t end
			end
		end
	end
	if #spawned == 0 then spawned[1] = tear end

	-- 单发：强制瞄准方向；多发（小丑 V 字等）：只钳弹速，保留夹角
	local multi = #spawned > 1
	for i = 1, #spawned do
		finish_tear(spawned[i], (not multi) and dir or nil)
	end
	return tear
end

--- 科技激光工厂（Robo-Baby 等）；Source/Parent/Spawner 尽量保持宝宝
function item.fire_tech_laser(fam, player, aim_vector, adapter, opts)
	if not fam or not player or not player.FireTechLaser or not aim_vector then return nil end
	if aim_vector:Length() < 0.01 then return nil end
	adapter = adapter or {}
	opts = opts or {}
	local dir = aim_vector:Normalized()
	local offset = opts.laser_offset or adapter.laser_offset or LaserOffset.LASER_TECH1_OFFSET
	local one_hit = opts.one_hit
	if one_hit == nil then one_hit = adapter.one_hit end
	if one_hit == nil then one_hit = false end
	local dmg_mul = 1
	local laser = player:FireTechLaser(fam.Position, offset, dir, false, one_hit, fam, dmg_mul)
	if not laser then return nil end
	laser = laser:ToLaser() or laser
	-- CollisionDamage 承担 BFFS / Mongo damage_mul；引擎倍率保持 1 避免双乘
	if laser.Parent ~= nil then
		laser.Parent = fam
	end
	if laser.SpawnerEntity ~= nil then
		laser.SpawnerEntity = fam
	end
	-- 激光跟宝宝画面高度（跟 Flight PositionOffset），不用 Height
	if laser.PositionOffset ~= nil and fam.PositionOffset then
		laser.PositionOffset = Vector(fam.PositionOffset.X, fam.PositionOffset.Y)
	end
	local dmg = opts.damage or adapter.damage or 3.5
	dmg = dmg * (tonumber(opts.damage_mul) or 1)
	-- FireTechLaser 的 dmg_mul 参数与 CollisionDamage 分开：Mongo 复制伤倍只进 CollisionDamage，避免叠乘
	local allow_bffs = adapter.supports_bffs ~= false and not opts.skip_bffs
	if allow_bffs and has_bffs(player) then
		local bffs_mul = tonumber(opts.bffs_damage_mul) or tonumber(adapter.bffs_damage_mul) or 2
		dmg = dmg * bffs_mul
	end
	if laser.CollisionDamage ~= nil then
		laser.CollisionDamage = dmg
	end
	if adapter.apply_laser then
		pcall(adapter.apply_laser, adapter, fam, player, laser, opts)
	end
	return laser
end

--- 相对瞄准方向按夹角发射多发；angles 为度数表（0 = 瞄准方向）
function item.fire_tears_angled(fam, player, aim_vector, adapter, angles, opts)
	if not aim_vector or aim_vector:Length() < 0.01 then return false end
	local any = false
	for i = 1, #(angles or {}) do
		local t = item.fire_basic_tear(fam, player, aim_vector:Rotated(angles[i]), adapter, opts)
		if t then any = true end
	end
	return any
end

--- 是否有任一制造宝宝 extras 需要 sync（Air Flight 用）
function item.profile_needs_sync(profile)
	local extras = profile and profile.extras
	if not extras then return false end
	-- 一命菇/九命猫已改 MeusNil，不在 ADAPTERS 内
	if extras.one_up or extras.dead_cat then return true end
	for _, adapter in pairs(item.ADAPTERS) do
		if adapter.extra_key and extras[adapter.extra_key] then
			return true
		end
	end
	return false
end

--- 近距索敌（Demon Baby 等）；返回最近可伤敌人
function item.find_closest_enemy(position, range)
	if not position then return nil end
	range = range or 120
	local best, best_d2 = nil, range * range
	for _, npc in ipairs(Isaac.FindInRadius(position, range, EntityPartition.ENEMY)) do
		if npc and npc:IsVulnerableEnemy() and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
			local d2 = (npc.Position - position):LengthSquared()
			if d2 <= best_d2 then
				best_d2 = d2
				best = npc
			end
		end
	end
	return best
end

--- 解析本帧是否应开火与瞄准向量
--- auto_seek：忽略 Air Flight intent，按 seek_range 自行找敌
local function resolve_aim(fam, adapter, intent)
	if adapter.auto_seek then
		local range = adapter.seek_range or 120
		local npc = item.find_closest_enemy(fam.Position, range)
		if not npc then
			return false, Vector(0, 0), nil
		end
		local predict = npc.Position + npc.Velocity * 5
		local delta = predict - fam.Position
		if delta:Length() < 1 then
			delta = npc.Position - fam.Position
		end
		if delta:Length() < 1 then
			return false, Vector(0, 0), nil
		end
		return true, delta:Normalized(), npc
	end
	local aim_vector = Vector(0, 0)
	if intent.aim_direction and intent.aim_direction:Length() >= 0.01 then
		aim_vector = intent.aim_direction:Normalized()
	elseif intent.aim_pos then
		local delta = intent.aim_pos - fam.Position
		if delta:Length() >= 1 then
			aim_vector = delta:Normalized()
		end
	end
	local should = intent.should_shoot == true and aim_vector:Length() >= 0.01
	return should, aim_vector, nil
end

local function try_fire(fam, player, air, bind, adapter, intent, aim_vector, d, should_shoot)
	if adapter and adapter.no_fire then return end
	local cd = tonumber(d[item.own_key..CD_KEY]) or 0
	local want = item.debug_force_fire or (should_shoot and aim_vector:Length() >= 0.01)
	if not want then return end
	if cd > 0 and not item.debug_force_fire then return end
	if aim_vector:Length() < 0.01 then
		aim_vector = Vector(0, 1)
	end

	local ctx = {
		familiar = fam,
		player = player,
		air = air,
		bind = bind,
		intent = intent,
		aim_vector = aim_vector,
		holder = item,
	}
	local fired = false
	if adapter.fire then
		local ok, ret = pcall(adapter.fire, adapter, ctx)
		fired = ok and ret ~= false
	else
		fired = item.fire_basic_tear(fam, player, aim_vector, adapter) ~= nil
	end
	if fired then
		local reset = adapter.base_cooldown or 16
		if adapter.get_cooldown then
			local ok, v = pcall(adapter.get_cooldown, adapter, ctx)
			if ok and tonumber(v) then reset = tonumber(v) end
		end
		d[item.own_key..CD_KEY] = reset
		d[item.own_key..HEAD_KEY] = adapter.head_delay or 8
		fam.FireCooldown = reset
		item.debug_force_fire = false
	end
end

local function update_bound_move_only(fam, air, player, bind, adapter, d)
	-- 原版 AI 已在本帧跑完索敌/开火。不动 FireCooldown/动画。
	-- 所有蓝图绑定体都须退出玩家 follower 链，否则后来生成的普通宝宝会接到它后面。
	-- move_only 仍放行原版 AI；这里只在 AI 后重申脱队并覆盖移动。
	if adapter.trail_follow then
		detach_trail_vanilla_delay(fam)
	else
		detach_from_vanilla_formation(fam)
	end
	local intent = get_intent(air)
	bind.last_intent = intent
	if keeps_vanilla_ai(adapter) then
		-- 棱镜/My Emblem 路线：FollowPosition + 强 Velocity（软弹簧盖不过原版跟随 AI）
		-- 若仍带 trail_follow（兼容旧标记）：必须清 MoveDelay，否则吃玩家延迟队列互拖
		if adapter.trail_follow then
			d[item.own_key.."duct_position"] = nil
			drive_trail_follow(fam, air, bind)
		else
			local target
			if player and player:HasTrinket(TrinketType.TRINKET_DUCT_TAPE) then
				d[item.own_key.."duct_position"] = d[item.own_key.."duct_position"]
					or Vector(fam.Position.X, fam.Position.Y)
				target = d[item.own_key.."duct_position"]
			elseif adapter.strict_follow then
				-- 阴影等：严格钉 Flight，不进波比链
				d[item.own_key.."duct_position"] = nil
				target = air.Position
			elseif player and player:HasTrinket(TrinketType.TRINKET_FRIENDSHIP_NECKLACE) then
				d[item.own_key.."duct_position"] = nil
				target = follow_slot(air, fam)
			else
				d[item.own_key.."duct_position"] = nil
				local leader = bind.follow_leader or air
				if not auxi.check_all_exists(leader) then leader = air end
				target = leader.Position
			end
			drive_keep_vanilla_follow(fam, target, air, bind)
		end
	else
		-- 借用 My Emblem 已验证的移动原语，而非它的 follower 所有权模型：
		-- 脱队后仍用 FollowPosition + 强 Velocity；只写软弹簧曾表现为原地不动。
		local target
		if player and player:HasTrinket(TrinketType.TRINKET_DUCT_TAPE) then
			d[item.own_key.."duct_position"] = d[item.own_key.."duct_position"]
				or Vector(fam.Position.X, fam.Position.Y)
			target = d[item.own_key.."duct_position"]
		elseif player and player:HasTrinket(TrinketType.TRINKET_FRIENDSHIP_NECKLACE) then
			d[item.own_key.."duct_position"] = nil
			target = follow_slot(air, fam)
		else
			d[item.own_key.."duct_position"] = nil
			local leader = bind.follow_leader or air
			if not auxi.check_all_exists(leader) then leader = air end
			target = leader.Position
		end
		if d[item.own_key..SNAP_KEY] and air then
			d[item.own_key..SNAP_KEY] = nil
			fam.Position = Vector(target.X, target.Y)
			fam.Velocity = Vector.Zero
		else
			drive_keep_vanilla_follow(fam, target, air, bind)
		end
	end
	if adapter.update then
		pcall(adapter.update, adapter, {
			familiar = fam,
			player = player,
			air = air,
			bind = bind,
			intent = intent,
			aim_vector = Vector(0, 0),
			holder = item,
			control_mode = keeps_vanilla_ai(adapter) and "keep_vanilla_ai" or "move_only",
		})
	end
end

local function update_bound_full(fam, air, player, bind, adapter, d)
	-- full 也须每帧脱离跟随链：EvaluateItems 可能把装载体重新挂回队列，
	-- 导致玩家新获得的跟随宝宝 FollowParent 跟上装载体（如 430→431）。
	if not bind.external_keep_follower then
		if adapter.trail_follow then
			detach_trail_vanilla_delay(fam)
		else
			detach_from_vanilla_formation(fam)
		end
	end
	local intent = get_intent(air)
	bind.last_intent = intent

	-- 轨迹宝宝：跳过波比 do_follow；由 Flight 历史相位驱动
	if adapter.trail_follow then
		d[item.own_key.."duct_position"] = nil
		drive_trail_follow(fam, air, bind)
	elseif not adapter.custom_move then
		do_follow(fam, air, d, adapter, bind, intent)
	end
	if not adapter.skip_tick_cooldown then
		tick_cooldown(fam, player, d, adapter, bind)
	end

	local should_shoot, aim_vector, target
	if air_is_standby(air) then
		should_shoot, aim_vector, target = false, Vector(0, 0), nil
	else
		should_shoot, aim_vector, target = resolve_aim(fam, adapter, intent)
	end
	bind.last_seek_target = target
	if should_shoot and adapter.aim_while_shooting then
		local ok, override = pcall(adapter.aim_while_shooting, adapter, {
			familiar = fam,
			player = player,
			air = air,
			bind = bind,
			intent = intent,
			aim_vector = aim_vector,
			holder = item,
		})
		if ok and override and override:Length() >= 0.01 then
			aim_vector = override
		end
	end
	local shoot_dir = dir_to_direction(aim_vector)
	if fam.ShootDirection ~= nil then
		fam.ShootDirection = shoot_dir
	end

	if adapter.update then
		pcall(adapter.update, adapter, {
			familiar = fam,
			player = player,
			air = air,
			bind = bind,
			intent = intent,
			aim_vector = aim_vector,
			should_shoot = should_shoot,
			target = target,
			holder = item,
			control_mode = "full",
		})
	end

	try_fire(fam, player, air, bind, adapter, intent, aim_vector, d, should_shoot)
	-- FireProjectile 可能按玩家射击输入改写 ShootDirection；强制改回本帧解析方向。
	if fam.ShootDirection ~= nil then
		fam.ShootDirection = shoot_dir
	end
	if not adapter.custom_animation then
		update_anim(fam, shoot_dir, d, nil, adapter)
	end
	suppress_bound_weapons(fam)
end

--- 国王宝宝等低优先级控制器复用蓝图 full adapter 的火控/冷却/攻击。
--- external_bind 不写入实体 Craft bind；调用方仍须通过 Selector 裁决所有权。
function item.update_external_full(fam, air, player, external_bind)
	if not fam or not air or not player then return false end
	local adapter = item.ADAPTERS[fam.Variant]
	if not adapter or allows_vanilla_ai(adapter) then return false end
	external_bind = external_bind or {}
	external_bind.air = air
	external_bind.player = player
	external_bind.external_keep_follower = false
	update_bound_full(fam, air, player, external_bind, adapter, fam:GetData())
	return true
end

function item.release_external_full(fam)
	if not fam then return end
	restore_bound_weapons(fam)
	local d = fam:GetData()
	d[item.own_key..CD_KEY] = nil
	d[item.own_key..HEAD_KEY] = nil
	d[item.own_key.."follow_state"] = nil
	d[item.own_key.."duct_position"] = nil
	fam.FireCooldown = 0
end

--- 诅咒之眼等只移动制造组，不移动玩家；绑定宝宝与 Air Flight 保持同一落点。
function item.teleport_bound_to_air(air, position)
	if not air or not position then return end
	local air_ptr = GetPtrHash(air)
	local seen = {}
	for fam in pairs(ACTIVE_BOUND) do
		local alive = active_familiar_alive(fam)
		local bind = alive and bind_data(fam) or nil
		if not alive or not bind then
			ACTIVE_BOUND[fam] = nil
		elseif bind.air_ptr == air_ptr then
			local ptr = GetPtrHash(fam)
			if not seen[ptr] then
				seen[ptr] = true
				fam.Position = position
				fam.Velocity = Vector(0, 0)
				fam:GetData()[item.own_key..SNAP_KEY] = true
			end
		end
	end
end

local function update_bound(fam)
	if auxi.is_time_stopped() then return end
	if not fam or (fam.Exists and not fam:Exists()) then return end
	local bind = bind_data(fam)
	if not bind then return end
	local adapter = item.ADAPTERS[fam.Variant]
	if not adapter then
		item.release_familiar(fam, "no_adapter")
		return
	end
	local air = bind.air
	local player = bind.player
	if not auxi.check_all_exists(air) or not auxi.check_all_exists(player) then
		item.release_familiar(fam, "missing_air_or_player")
		return
	end
	bind.air = air
	bind.player = player

	local d = fam:GetData()
	local frame = Game():GetFrameCount()
	if d[item.own_key..TICK_KEY] == frame then return end
	d[item.own_key..TICK_KEY] = frame

	if is_move_only(adapter) or keeps_vanilla_ai(adapter) then
		update_bound_move_only(fam, air, player, bind, adapter, d)
	else
		update_bound_full(fam, air, player, bind, adapter, d)
	end
end

table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_FAMILIAR_UPDATE,
	params = nil,
	Function = function(_, fam)
		if not fam or (fam.Exists and not fam:Exists()) then return end
		if not fam or not item.ADAPTERS[fam.Variant] then return end
		if is_bound(fam) then ACTIVE_BOUND[fam] = true end
		if not Familiar_Control_Selector.is_owner(fam, Familiar_Control_Selector.BLUEPRINT) then return end
		local adapter = item.ADAPTERS[fam.Variant]
		-- AI 前先重申脱离玩家编队，防止原版 FollowParent 把它钉回玩家，也防止
		-- 新生成的普通宝宝把装载体当作 follower 前序节点。放行 AI 与 follower 身份
		-- 是两件事；目前没有证据表明资源宝宝的产出计时依赖 follower 队列。
		if is_bound(fam) and allows_vanilla_ai(adapter) then
			if adapter.trail_follow then
				detach_trail_vanilla_delay(fam)
			else
				detach_from_vanilla_formation(fam)
			end
		end
		if is_bound(fam) then
			local bind = bind_data(fam)
			local air = bind and bind.air
			if air_is_standby(air) then
				if adapter.trail_follow then
					detach_trail_vanilla_delay(fam)
				else
					detach_from_vanilla_formation(fam)
				end
				if fam.CollisionDamage ~= nil then fam.CollisionDamage = 0 end
				return true
			end
		end
		-- move_only / keep_vanilla_ai：放行原版 AI；full 才跳过
		if allows_vanilla_ai(adapter) then return end
		return true
	end,
})

-- 放行 AI 的宝宝：必须在 MC_FAMILIAR_UPDATE 立刻覆写位移（POST 太晚）。
-- move_only → 波比 do_follow；keep_vanilla_ai → FollowPosition/轨迹（棱镜/粉丝等）。
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_FAMILIAR_UPDATE,
	params = nil,
	Function = function(_, fam)
		if not fam or (fam.Exists and not fam:Exists()) then return end
		local adapter = item.ADAPTERS[fam.Variant]
		if not allows_vanilla_ai(adapter) then return end
		if not Familiar_Control_Selector.is_owner(fam, Familiar_Control_Selector.BLUEPRINT) then return end
		if not is_bound(fam) then return end
		update_bound(fam)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function(_)
		-- full：PRE 已跳过实体更新，帧末完整驱动。
		-- move_only / keep_vanilla_ai：已在 FAMILIAR_UPDATE 驱动，避免双 tick。
		for fam in pairs(ACTIVE_BOUND) do
			if not active_familiar_alive(fam) or not is_bound(fam) then
				ACTIVE_BOUND[fam] = nil
			elseif Familiar_Control_Selector.is_owner(fam, Familiar_Control_Selector.BLUEPRINT) then
				local adapter = item.ADAPTERS[fam.Variant]
				if not allows_vanilla_ai(adapter) then update_bound(fam) end
			end
		end
	end,
})

-- PostInit 的 SpawnerEntity 属于文档保证可用字段；这里只打蓝图 full-control 标记，
-- 不读取尚未完成初始化的 Height/Falling*。可覆盖 FireProjectile 的延迟/额外多发泪弹。
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_TEAR_INIT,
	params = nil,
	Function = function(_, tear)
		if not REPENTOGON or not tear then return end
		local spawner = tear.SpawnerEntity
		local fam = spawner and spawner:ToFamiliar()
		if fam then arm_owned_tear_visual(tear, fam) end
	end,
})

-- 新实体在生成循环会先 Render、下一逻辑帧才首次 Update。首个 Update 前禁止本体渲染；
-- 到这里再清 PO、恢复影子并从稳定帧启动视觉过渡。
-- 扁石 HYDROBOUNCE：仅第一帧清 PO；之后每帧清零会掐死引擎弹跳对 PositionOffset 的写入。
if REPENTOGON and ModCallbacks.MC_PRE_TEAR_UPDATE then
	table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
		CallBack = ModCallbacks.MC_PRE_TEAR_UPDATE,
		params = nil,
		Function = function(_, tear)
			if not tear then return end
			local d = tear:GetData()
			if d[item.own_key..TEAR_VISUAL_OWNED_KEY] ~= true then return end
			local is_first = d[item.own_key..TEAR_FIRST_UPDATE_KEY] ~= true
			local hydro = false
			local flag = TearFlags and TearFlags.TEAR_HYDROBOUNCE
			if flag then
				if tear.HasTearFlags then
					hydro = tear:HasTearFlags(flag) == true
				elseif tear.TearFlags ~= nil then
					hydro = (tear.TearFlags & flag) == flag
				end
			end
			-- 无扁石：持续清 PO 防与 Height 耦合；有扁石：只首帧修正一次
			if is_first or not hydro then
				if tear.PositionOffset ~= nil then tear.PositionOffset = Vector.Zero end
			end
			if is_first then
				d[item.own_key..TEAR_FIRST_UPDATE_KEY] = true
				d[item.own_key..TEAR_VISUAL_LIFT_START_KEY] = Isaac.GetFrameCount and Isaac.GetFrameCount() or Game():GetFrameCount()
				local shadow = d[item.own_key..TEAR_SHADOW_SIZE_KEY]
				if shadow ~= nil and tear.SetShadowSize then tear:SetShadowSize(shadow) end
			end
		end,
	})
end

-- 只补视觉起点，不改 Tear.Height / PositionOffset / Position，因此不抬高碰撞轨道。
-- PositionOffset 是实体单位，必须经 W2S 作差后才能加到 PRE render 的屏幕 offset。
if REPENTOGON and ModCallbacks.MC_PRE_TEAR_RENDER then
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_PRE_TEAR_RENDER,
		params = nil,
		Function = function(_, tear, _offset)
			if not tear then return end
			local d = tear:GetData()
			if d[item.own_key..TEAR_VISUAL_OWNED_KEY] ~= true then return end
			-- 生成后尚未经历 Tear Update：引擎内部 Height/PO render cache 不可靠。
			if d[item.own_key..TEAR_FIRST_UPDATE_KEY] ~= true then
				if tear.SetShadowSize then tear:SetShadowSize(0) end
				return false
			end
			local lift = d[item.own_key..TEAR_VISUAL_LIFT_KEY]
			local start = tonumber(d[item.own_key..TEAR_VISUAL_LIFT_START_KEY])
			if not lift or not start then return end
			local now = Isaac.GetFrameCount and Isaac.GetFrameCount() or Game():GetFrameCount()
			local age = math.max(0, now - start)
			local u = math.min(1, age / TEAR_VISUAL_LIFT_FRAMES)
			if u >= 1 then
				d[item.own_key..TEAR_VISUAL_LIFT_KEY] = nil
				d[item.own_key..TEAR_VISUAL_LIFT_START_KEY] = nil
				d[item.own_key..TEAR_VISUAL_OWNED_KEY] = nil
				return
			end
			-- smootherstep：起点和终点的一、二阶速度均为零，避免旧二次曲线开头猛降，
			-- 也避免线性插值在结束点突然停住。
			local blend = u * u * u * (u * (u * 6 - 15) + 10)
			local weight = 1 - blend
			-- 同步补偿沿弹道的首帧前进量：起点略向后收，随同一平滑曲线归零。
			-- 只改 render offset，不修改世界 Position/Velocity/碰撞。PRE callback 的
			-- offset 已含大房间滚动，不能再原样加回；仅返回两次 W2S 的差值。
			local velocity = tear.Velocity or Vector.Zero
			local base = Isaac.WorldToScreen(tear.Position)
			local visual_world = tear.Position
				+ lift * weight
				- velocity * (TEAR_TRAJECTORY_LAG_STEPS * weight)
			return Isaac.WorldToScreen(visual_world) - base
		end,
	})
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function(_)
		item._milk_room_unload = false
		for variant,_ in pairs(item.ADAPTERS) do
			for _, fam in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, variant, -1, false, false)) do
				if is_bound(fam) then
					fam:GetData()[item.own_key..SNAP_KEY] = true
				end
			end
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_GAME_EXIT,
	params = nil,
	Function = function(_)
		for variant,_ in pairs(item.ADAPTERS) do
			for _, fam in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, variant, -1, false, false)) do
				if is_bound(fam) then
					item.release_familiar(fam, "exit")
				end
			end
		end
	end,
})

--- 调试摘要（ImGui）
function item.debug_snapshot()
	local rows = {}
	for variant, adapter in pairs(item.ADAPTERS) do
		for _, fam in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, variant, -1, false, false)) do
			local bind = bind_data(fam)
			if bind then
				local d = fam:GetData()
				local intent = bind.last_intent or {}
				rows[#rows + 1] = {
					uid = bind.craft_uid,
					variant = variant,
					adapter = adapter.name,
					mode = adapter.control_mode or "full",
					cd = d[item.own_key..CD_KEY],
					should = intent.should_shoot,
					aim = intent.aim_direction or intent.aim_pos,
					focus = intent.focus,
					state = intent.state,
				}
			end
		end
	end
	return rows
end

-- Milk!：只跟 AF 移动，不改挡弹计数；破碎写 milk_broken_floor
-- 1up!/Dead Cat：必须 full（跳过原版 FollowParent）；move_only 会被钉回玩家队列
local enums = get_enums()
item._milk_room_unload = false

item.register_adapter(FamiliarVariant.MILK, {
	name = "milk",
	extra_key = "milk",
	collectible = CollectibleType.COLLECTIBLE_MILK or 436,
	control_mode = "move_only",
	mongo_copyable = false,
	supports_bffs = false,
	supports_lullaby = false,
	supports_bender = false,
	-- 无开火；原版 AI 负责挡弹/破碎
})

local function revive_familiar_float_update(adapter, ctx)
	local fam = ctx and ctx.familiar
	if not fam then return end
	local s = fam:GetSprite()
	if not s then return end
	local anim = (adapter and adapter.float_anim) or "Float"
	if not s:IsPlaying(anim) then
		s:Play(anim, true)
	end
end

item.register_adapter(FamiliarVariant.ONE_UP, {
	name = "one_up",
	extra_key = "one_up",
	collectible = CollectibleType.COLLECTIBLE_1UP or 11,
	control_mode = "full",
	craft_revive_real = true,
	no_fire = true,
	custom_animation = true,
	float_anim = "Float",
	mongo_copyable = false,
	supports_bffs = false,
	supports_lullaby = false,
	supports_bender = false,
	formation_priority = 8000, -- 靠后，接在普通宝宝链尾
	update = revive_familiar_float_update,
})

item.register_adapter(FamiliarVariant.DEAD_CAT, {
	name = "dead_cat",
	extra_key = "dead_cat",
	collectible = CollectibleType.COLLECTIBLE_DEAD_CAT or 81,
	control_mode = "full",
	craft_revive_real = true,
	no_fire = true,
	custom_animation = true,
	float_anim = "Float",
	mongo_copyable = false,
	supports_bffs = false,
	supports_lullaby = false,
	supports_bender = false,
	formation_priority = 8100,
	update = revive_familiar_float_update,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_ROOM,
	params = nil,
	Function = function(_)
		item._milk_room_unload = true
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE,
	params = EntityType.ENTITY_FAMILIAR,
	Function = function(_, ent)
		if not ent or ent.Variant ~= FamiliarVariant.MILK then return end
		if item._milk_room_unload then return end
		local bind = bind_data(ent)
		if not bind or not bind.craft_uid then return end
		local CraftDyn = require("Qing_Remaster_scripts.others.craft_dynamic_stats")
		local bp = get_blueprint()
		local player = bind.player
		local rec = player and bp.find_craft(player, bind.craft_uid)
		if rec and CraftDyn and CraftDyn.floor_key then
			rec.milk_broken_floor = CraftDyn.floor_key()
		end
	end,
})

return item
