-- 三因子 Skiel / Wisel / Granel：表驱动共享实现
-- 底座：RGON CollectibleCycle；非 RGON 回退 Morph+Consistance

local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local attack_holder = require("Qing_Remaster_scripts.callbacks.attack_trigger_holder")

local item = {
	ToCall = {},
	myToCall = {},
	-- Consistance / 旧存档键保持 "Iliaster"（无尾下划线）
	own_key = "Iliaster",
	entity1 = enums.Items.Skiel,
	entity2 = enums.Items.Wisel,
	entity3 = enums.Items.Granel,
}

-- 与旧 BitSet128(1<<n) 对齐（见 TearFlags.md）
local TF_SPECTRAL = TearFlags.TEAR_SPECTRAL -- TEARFLAG(0)
local TF_PIERCING = TearFlags.TEAR_PIERCING -- TEARFLAG(1)
local TF_HOMING = TearFlags.TEAR_HOMING -- TEARFLAG(2)
local TF_GROW = TearFlags.TEAR_GROW -- TEARFLAG(7)；旧 Wisel 冲击波用 1<<7
local TF_BOUNCE = TearFlags.TEAR_BOUNCE -- TEARFLAG(19)
local TF_SHIELDED = TearFlags.TEAR_SHIELDED -- TEARFLAG(34)；旧 Skiel 随机位
local TF_POP = TearFlags.TEAR_POP -- TEARFLAG(58)；旧 Skiel 随机位

local FACTOR_ORDER = {
	enums.Items.Skiel,
	enums.Items.Wisel,
	enums.Items.Granel,
}

local FACTORS = {
	[enums.Items.Skiel] = {
		key = "skiel",
		index = 1,
		charge_max = 90,
		bar = "gfx/effects/chargebar/chargebar_Skiel.anm2",
		-- hold_only: 按住蓄力，松手清零
		mode = "hold",
	},
	[enums.Items.Wisel] = {
		key = "wisel",
		index = 2,
		charge_max = 180,
		bar = "gfx/effects/chargebar/chargebar_Wisel.anm2",
		-- tap_decay: 点按蓄力，空闲衰减
		mode = "tap",
	},
	[enums.Items.Granel] = {
		key = "granel",
		index = 3,
		charge_max = 270,
		bar = "gfx/effects/chargebar/chargebar_Granel.anm2",
		-- hybrid: 长按 + 点按加速，松手衰减
		mode = "hybrid",
	},
}

local function is_factor(id)
	return FACTORS[id] ~= nil
end

local function next_factor(id)
	for i = 1, #FACTOR_ORDER do
		if FACTOR_ORDER[i] == id then
			return FACTOR_ORDER[(i % #FACTOR_ORDER) + 1]
		end
	end
	return nil
end

local function player_has_factor(player, id)
	return player:HasCollectible(id) or player:GetEffects():GetCollectibleEffectNum(id) > 0
end

local function tear_owner(ent)
	if ent.SpawnerEntity then
		local p = ent.SpawnerEntity:ToPlayer()
		if p then return p end
	end
	if ent.Spawner and ent.Spawner.Type == 1 then
		local p = ent.Spawner:ToPlayer()
		if p then return p end
	end
	return nil
end

local function factor_state(player, id)
	local d = player:GetData()
	d[item.own_key.."state"] = d[item.own_key.."state"] or {}
	local st = d[item.own_key.."state"]
	local key = tostring(id)
	st[key] = st[key] or {
		charge = 0,
		ready = false,
		tap_flag = false,
		tap_boost = 0,
	}
	return st[key]
end

--- 每多持有一种其他因子，蓄力速度 ×(1 + 0.15 × 数量)
local function other_factor_count(player, self_id)
	local n = 0
	for _, id in ipairs(FACTOR_ORDER) do
		if id ~= self_id and player_has_factor(player, id) then
			n = n + 1
		end
	end
	return n
end

local function charge_mul(player, self_id)
	return 1 + 0.15 * other_factor_count(player, self_id)
end

--- 痛苦因子自身随机 TearFlags（不含跨因子联动）
local function apply_skiel_own_flags(tear, rnd)
	rnd = rnd or math.random(5)
	tear.TearFlags = tear.TearFlags | TF_SPECTRAL
	if rnd == 1 then tear.TearFlags = tear.TearFlags | TF_HOMING end
	if rnd == 3 then tear.TearFlags = tear.TearFlags | TF_SHIELDED end
	if rnd == 5 then tear.TearFlags = tear.TearFlags | TF_POP end
end

function item.start_skiel(player)
	for i = 1, 5 do
		delay_buffer.addeffe(function()
			if not player or not player:Exists() then return end
			local d = player:GetData()
			local dir = auxi.ggdir(player, true, true)
			if dir:Length() < 0.05 then
				dir = d.last_skiel_dir or Vector(1, 0)
			else
				d.last_skiel_dir = dir
			end
			local ang = dir:GetAngleDegrees()
			local rnd = math.random(5)
			local lst_link = nil
			for j = 3, -3, -1 do
				if j ~= 0 then
					local k = j / math.abs(j)
					local q = Isaac.Spawn(2, 1, 0, player.Position,
						auxi.MakeVector(ang + ((4 - math.abs(j)) * 20 + i * 6 + 100) * k) * player.ShotSpeed * (5 + (5 - i) * 2),
						player):ToTear()
					q.CollisionDamage = player.Damage * 0.5
					apply_skiel_own_flags(q, rnd)
					local s2 = q:GetSprite()
					s2:Load("gfx/mimics/Iliaster/Iliaster_tear.anm2", true)
					s2:ReplaceSpritesheet(0, "gfx/tears/Iliaster_tear_" .. tostring(rnd) .. ".png")
					s2:LoadGraphics()
					s2:Play("Idle", true)
					local d2 = q:GetData()
					d2.is_skiel = true
					attack_holder.MarkIgnore(q)
					d2.link_target = lst_link
					lst_link = q
				end
			end
			player:AddVelocity(dir:Normalized() * 2.5)
		end, {}, i * 2)
	end
end

function item.start_wisel(player)
	local d = player:GetData()
	local gdir = auxi.ggdir(player, true, true)
	if gdir:Length() > 0.05 then d.last_wisel_dir = gdir end
	for i = 1, 6 do
		delay_buffer.addeffe(function()
			if not player or not player:Exists() then return end
			local dir = auxi.ggdir(player, true, true)
			if dir:Length() < 0.05 then
				dir = d.last_wisel_dir or Vector(1, 0)
			else
				d.last_wisel_dir = dir
			end
			local ang = dir:GetAngleDegrees()
			local q = Isaac.Spawn(2, 0, 0, player.Position,
				auxi.MakeVector(ang) * player.ShotSpeed * (5 + (7 - i) / 7 * 2),
				player):ToTear()
			-- piercing + spectral + homing + wiggle（冲击波纹身份）
			q.TearFlags = q.TearFlags | TF_BOUNCE | TF_PIERCING | TF_HOMING | TF_GROW
			q.CollisionDamage = player.Damage * 1.3
			local s2 = q:GetSprite()
			s2.Scale = Vector(1, 1) * (10 - i) / 10
			q:SetSize(16 * (10 - i) / 10, Vector(1, 1), 1)
			s2:Load("gfx/mimics/Iliaster/Wisel_tear.anm2", true)
			s2:Play("Idle", true)
			local d2 = q:GetData()
			d2.is_wisel = true
			d2.wisel_counter = 4
			attack_holder.MarkIgnore(q)
			player:AddVelocity(-dir:Normalized() * 2.5)
		end, {}, (i - 1) * 2)
	end
end

local function spawn_granel_flames(player, origin, ang, damage_scale)
	damage_scale = damage_scale or 1
	local rnd = math.random(7)
	local rnd2 = math.random(40) - 20
	if rnd == 1 then rnd2 = math.random(70) - 35 end
	local rnd3 = math.random(10) / 10 * 10 - 5
	if rnd == 5 then rnd2 = math.random(10) / 10 * 15 - 5 end
	local rnd4 = math.random(40) - 20
	if rnd == 3 then rnd4 = rnd4 + 60 end
	local dmg = player.Damage * 0.2 * damage_scale
	if rnd == 7 then dmg = player.Damage * 0.4 * damage_scale end
	for j = 1, 4 do
		local q = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BLUE_FLAME, 0, origin,
			auxi.MakeVector(ang + j * 90 + 45 + rnd2) * player.ShotSpeed * (10 + rnd3), player):ToEffect()
		local s2 = q:GetSprite()
		local d2 = q:GetData()
		s2:Load("gfx/mimics/Iliaster/granel_flame.anm2", true)
		s2:ReplaceSpritesheet(0, "gfx/effects/flames/flame" .. tostring(rnd) .. ".png")
		s2:LoadGraphics()
		s2:Play("Appear", true)
		d2.is_granel = true
		if rnd == 4 then d2.should_follow = true end
		q.CollisionDamage = dmg
		q.GridCollisionClass = GridCollisionClass.COLLISION_NONE
		q.Timeout = 90 + rnd4
	end
end

function item.start_granel(player)
	for i = 1, 20 do
		delay_buffer.addeffe(function()
			if not player or not player:Exists() then return end
			local dir = auxi.ggdir(player, true, true)
			if dir:Length() < 0.05 then dir = Vector(1, 0) end
			spawn_granel_flames(player, player.Position, dir:GetAngleDegrees(), 1)
		end, {}, i * 2)
	end
end

local FIRE_FN = {
	[enums.Items.Skiel] = item.start_skiel,
	[enums.Items.Wisel] = item.start_wisel,
	[enums.Items.Granel] = item.start_granel,
}

-- 兼容旧名
item.start_Iliaster_1 = item.start_skiel
item.start_Iliaster_2 = item.start_wisel
item.start_Iliaster_3 = item.start_granel

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION, params = nil,
Function = function(_, ent, col, low)
	local d = ent:GetData()
	if not d.is_wisel then return end
	local player = tear_owner(ent)
	if not player then return end
	local s = ent:GetSprite()
	if s:IsPlaying("Idle") then
		if d.wisel_counter == nil or d.wisel_counter <= 0 then
			s:Play("Remove", true)
			ent.Velocity = Vector(0, 0)
			d.wisel_target_ent = col
			ent.CollisionDamage = 0
			ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
			ent.TearFlags = TF_PIERCING
		else
			d.wisel_counter = d.wisel_counter - 1
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_, ent)
	local d = ent:GetData()
	if d.is_skiel then
		if d.link_target and d.link_target:Exists() and not d.link_target:IsDead() then
			if d.link_laser == nil then
				local player = tear_owner(ent)
				if player then
					local q = Isaac.Spawn(7, 10, 0, ent.Position, Vector(0, 0), player):ToLaser()
					q.CollisionDamage = ent.CollisionDamage
					d.link_laser = q
					q.Parent = ent
					q:GetSprite().Color = Color(1, 0, 1, 1)
				end
			end
			if d.link_laser and d.link_laser:Exists() then
				d.link_laser.PositionOffset = ent.PositionOffset
				d.link_laser.Angle = (d.link_target.Position - ent.Position):GetAngleDegrees()
				d.link_laser:SetMaxDistance(math.min(200, (d.link_target.Position - ent.Position):Length()))
			end
		else
			if d.link_laser ~= nil then
				if d.link_laser:Exists() then d.link_laser:Remove() end
				d.link_laser = nil
			end
		end
	end
	if d.is_wisel then
		local s = ent:GetSprite()
		if s:IsPlaying("Idle") then
			s.Rotation = ent.Velocity:GetAngleDegrees() - 90
			ent.FallingSpeed = 0
			ent.Height = -30
		end
		if s:IsPlaying("Remove") then
			ent.Velocity = ent.Velocity * 0.5
			if d.wisel_target_ent and d.wisel_target_ent:Exists() then
				ent.Position = d.wisel_target_ent.Position + Vector(0, 0.1)
			end
			s.Offset = s.Offset * 0.8 + Vector(0, -40) * 0.2
		end
		if s:IsFinished("Remove") then
			ent:Remove()
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_, player)
	if player_has_factor(player, enums.Items.Wisel) then
		local ggdir = auxi.ggdir(player, true, true)
		if ggdir:Length() > 0.05 then
			player:GetData().last_wisel_dir = ggdir
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = EffectVariant.BLUE_FLAME,
Function = function(_, ent)
	local d = ent:GetData()
	if not d.is_granel then return end
	local s = ent:GetSprite()
	if s:IsFinished("Appear") then s:Play("Idle", true) end
	if s:IsPlaying("Idle") then
		if d.should_follow and d.target == nil then
			d.target = auxi.get_by_nearest_enemy(ent.Position)
			d.should_follow = nil
		end
		if d.target and d.target:Exists() and not d.target:IsDead() then
			ent.Velocity = ent.Velocity + (d.target.Position - ent.Position) * 0.01
			if ent.Velocity:Length() > 10 then ent.Velocity = ent.Velocity:Normalized() * 10 end
		end
		if d.minded_scale == nil then d.minded_scale = math.max(1, ent.Timeout + 15) end
		s.Scale = Vector(1, 1) * (ent.Timeout + 15) / d.minded_scale
		ent.CollisionDamage = math.max(0.5, ent.CollisionDamage * 0.98)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_, player, offset)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	local d = player:GetData()
	for id, cfg in pairs(FACTORS) do
		if player_has_factor(player, id) then
			local st = factor_state(player, id)
			local cnt = st.charge or 0
			local bar_key = "Iliaster_" .. cfg.key
			Charging_Bar_holder.render_me(player, {
				name1 = item.own_key .. "charge_" .. cfg.key,
				name2 = item.own_key .. "sprite_" .. cfg.key,
				name3 = bar_key,
				loadname = cfg.bar,
				check1 = function() return cnt > 5 end,
				check2 = function() return cnt > cfg.charge_max end,
				check3 = function() return math.ceil(cnt / cfg.charge_max * 100) end,
				signal1 = function()
					st.ready = true
				end,
			})
		end
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = nil,
Function = function(_, player, collid, count)
	local cfg = FACTORS[collid]
	if cfg and count < 0 then
		Charging_Bar_holder.remove_charge_bar(player, "Iliaster_" .. cfg.key)
	end
end,
})

--- 当前 cycle 是否仅为三因子（允许表含/不含当前 SubType）
local function factor_cycle_is_clean(pickup)
	if not pickup.GetCollectibleCycle then return false end
	local cycle = pickup:GetCollectibleCycle() or {}
	if #cycle == 0 then return false end
	local seen = {}
	for _, id in ipairs(cycle) do
		if not is_factor(id) then return false end
		seen[id] = true
	end
	-- 必须覆盖另外两个因子；当前底座 SubType 可能不在返回表里
	for _, id in ipairs(FACTOR_ORDER) do
		if id ~= pickup.SubType and not seen[id] then
			return false
		end
	end
	-- 除三因子外不得有其它 id（已在上面 is_factor 拦截）
	return true
end

--- RGON：只把另外两个因子加入 cycle。禁止 TryInitOptionCycle(n)——
--- 它会按 Glitched Crown 从道具池自动填满剩余槽，导致混入无关道具。
local function ensure_rgon_cycle(pickup)
	if not REPENTOGON or not pickup or not pickup.AddCollectibleCycle then return false end
	if pickup.Touched then return true end
	if not is_factor(pickup.SubType) then return false end

	local d = pickup:GetData()
	if d[item.own_key .. "cycle"] and factor_cycle_is_clean(pickup) then
		return true
	end

	local family_identity = {
		init_seed = pickup.InitSeed,
		type = pickup.Type,
		variant = pickup.Variant,
	}
	-- 污染 cycle 中的非三因子：永久移出此 pedestal，清对应 subtype-sensitive Consistance state
	if pickup.GetCollectibleCycle then
		local cycle = pickup:GetCollectibleCycle() or {}
		for _, id in ipairs(cycle) do
			if not is_factor(id) then
				consistance_holder.drop_family_state(family_identity, id)
			end
		end
	end

	if pickup.RemoveCollectibleCycle then
		pickup:RemoveCollectibleCycle()
	end
	for _, id in ipairs(FACTOR_ORDER) do
		if id ~= pickup.SubType then
			pickup:AddCollectibleCycle(id)
		end
	end
	d[item.own_key .. "cycle"] = factor_cycle_is_clean(pickup)
	return d[item.own_key .. "cycle"] == true
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = 100,
Function = function(_, pickup)
	if not is_factor(pickup.SubType) then return end
	ensure_rgon_cycle(pickup)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = 100,
Function = function(_, ent)
	if ent.Touched then return end
	if not is_factor(ent.SubType) then return end
	-- RGON 已接管则不再 Morph
	if ensure_rgon_cycle(ent) then return end
	-- 非 RGON 回退：约 2 秒 Morph（旧 lifetime 整 family 结束）
	local d = ent:GetData()
	consistance_holder.try_check_entity(ent, item.own_key)
	d._Data = d._Data or {}
	d._Data[item.own_key] = d._Data[item.own_key] or {}
	d._Data[item.own_key].Ilaster_counter = (d._Data[item.own_key].Ilaster_counter or 0) + 1
	if d._Data[item.own_key].Ilaster_counter >= 60 then
		local nx = next_factor(ent.SubType)
		if nx then
			local family_identity = {
				init_seed = ent.InitSeed,
				type = ent.Type,
				variant = ent.Variant,
			}
			consistance_holder.supersede_family(family_identity)
			consistance_holder.invalidate_entity_binding(ent)
			ent:Morph(5, 100, nx, true, true, true)
			ent:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
			ent:SetColor(Color(1, 1, 1, 1, 1, 1, 1), 10, 10, true)
		end
	end
	consistance_holder.try_hold_entity(ent, item.own_key, {ignore_subtype = true})
end,
})

local function shooting_held(player)
	local ctrlid = player.ControllerIndex
	for i = 4, 7 do
		if Input.IsActionTriggered(i, ctrlid) or Input.IsActionPressed(i, ctrlid) then
			return true
		end
	end
	return false
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.g_dir_can_work(player) then
			local act = shooting_held(player)
			for id, cfg in pairs(FACTORS) do
				if player_has_factor(player, id) then
					local st = factor_state(player, id)
					local mul = charge_mul(player, id)
					if cfg.mode == "hold" then
						if act then
							st.charge = st.charge + 1 * mul
							if st.ready then
								st.ready = false
								FIRE_FN[id](player)
								st.charge = 0
							end
						else
							st.charge = 0
						end
					elseif cfg.mode == "tap" then
						if act then
							if not st.tap_flag then
								st.tap_flag = true
								st.tap_boost = math.min(35, st.tap_boost + 7)
							end
							if st.ready then
								st.ready = false
								FIRE_FN[id](player)
								st.charge = 0
							end
						elseif st.tap_flag then
							st.tap_flag = false
							st.tap_boost = math.min(35, st.tap_boost + 7)
						end
						if st.tap_boost > 0 then
							local cnt = math.max(1, st.tap_boost / 5)
							st.charge = st.charge + cnt * 0.5 * mul
							st.tap_boost = math.max(0, st.tap_boost - cnt)
						else
							st.charge = math.max(0, st.charge - 5)
						end
					elseif cfg.mode == "hybrid" then
						if act then
							st.charge = st.charge + 1 * mul
							if not st.tap_flag then
								st.tap_flag = true
								st.tap_boost = math.min(35, st.tap_boost + 7)
							end
							if st.ready then
								st.ready = false
								FIRE_FN[id](player)
								st.charge = 0
							end
						elseif st.tap_flag then
							st.tap_flag = false
							st.tap_boost = math.min(35, st.tap_boost + 7)
						end
						if st.tap_boost > 0 then
							local cnt = math.max(1, st.tap_boost / 5)
							st.charge = st.charge + cnt * 0.3 * mul
							st.tap_boost = math.max(0, st.tap_boost - cnt)
						elseif not act then
							st.charge = math.max(0, st.charge - 5)
						end
					end
				end
			end
		end
	end
end,
})

item.FACTORS = FACTORS
item.FACTOR_ORDER = FACTOR_ORDER

return item
