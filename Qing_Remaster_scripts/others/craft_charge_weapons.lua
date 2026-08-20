-- Flight 蓄力武器（批次 2）：399 虚空之口 / 643 启示 / 597 海王星蓄力条
-- 共用：按 craft_uid+effect 独立状态；三条独立 Charging_Bar。
-- 399/643 语义对齐 Craft_Charged_Familiars_holder：
--   Flight 攻击窗口持续蓄力；满蓄 + 自绘条 Charged → 自动开火；
--   窗口结束 = 取消未满蓄力（绝不当作松手释放）。见 craft_charged_familiar_pitfalls.md。
-- 643 激光入口对齐 Item_TianYi：Isaac.Spawn(7, LIGHT_BEAM, 0)，勿用 FireTechLaser 换皮。
-- spawn_maw_ring 供 399 虚空之口满蓄释放。（408 Athame 受伤环已废止，不再共用。）
-- 不吃多发/泪特效；不读写玩家 Get/SetRevelationCharge。
-- 激光 PO：只跟 Flight.PositionOffset（枪口相对高度 0），见 flight_muzzle_position_offset.md。
-- 597：不攻击时蓄积、攻击时消耗并临时提高射速；需独立蓄力条。
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	own_key = "craft_charge_weapons_",
	cfg = {},
}

local IDS = {
	MAW = 399,
	REVELATION = 643,
	NEPTUNE = 597,
}

-- 满蓄 2.35s ≈ 71 帧；Maw：寿命~60；启示：天依同款 LIGHT_BEAM，Timeout≈20
local DEFAULTS = {
	charge_full_frames = 71,
	charge_cooldown = 20,
	bar_ready_fallback = 10,
	maw_life = 60,
	maw_radius = 80,
	maw_size = 16,
	maw_scale = 1.0,
	rev_timeout = 20,
	-- 启示输出：软刹；虚空环：追向环内理想半径（非贴边）
	hold_weight = 0.55,
	hold_settle_radius = 10,
	maw_chase_ideal_frac = 0.4, -- 理想距 = radius * frac（更靠中心）
	maw_chase_slack = 4,
	maw_chase_boost_base = 3.2,
	maw_chase_boost_per = 0.32,
	maw_chase_boost_cap = 12,
	-- 目标短暂不可打（跳跃等）但实体仍存活：保持蓄力约 30 帧
	charge_grace_frames = 30,
	nep_fill_frames = 180,
	nep_drain_frames = 60,
	nep_fire_rate_min = 1,
	nep_fire_rate_max = 6,
}

local CHARGE_BAR_ANM2 = "gfx/effects/chargebar/chargebar.anm2"

local function cfg(key)
	local v = item.cfg[key]
	if v ~= nil then return v end
	return DEFAULTS[key]
end

local function get_air_mod()
	return require("Qing_Remaster_scripts.items.Item_Air_Flight")
end

local function get_blueprint()
	return require("Qing_Remaster_scripts.items.Item_Blue_Print")
end

local function count_of(profile, id)
	return CraftProfile.count_of(profile and profile.counts, id)
end

local function craft_uid_of(air)
	if not air then return nil end
	local bp = get_blueprint()
	return air:GetData()[bp.own_key.."craft_uid"]
end

local function flight_damage(profile, player)
	return (profile and profile.stats and tonumber(profile.stats.damage))
		or (player and tonumber(player.Damage))
		or 3.5
end

local function copy_po(v)
	if not v then return Vector(0, 0) end
	return Vector(v.X, v.Y)
end

local function copy_vec(v)
	if not v then return nil end
	return Vector(v.X, v.Y)
end

--- 释放后移动提示：anchor 刹停 / orbit 环距（黑圈、英灵剑）
local function begin_output_hold(air, life_frames, opts)
	if not air then return end
	opts = opts or {}
	local life = math.max(1, math.floor(tonumber(life_frames) or 1))
	local d = air:GetData()
	local until_f = Game():GetFrameCount() + life
	local prev = d[item.own_key.."hold_until"]
	if prev and until_f < prev then
		until_f = prev
	end
	d[item.own_key.."hold_until"] = until_f
	d[item.own_key.."hold_mode"] = opts.mode or "anchor"
	d[item.own_key.."hold_pos"] = copy_vec(opts.pos or air.Position)
	d[item.own_key.."hold_radius"] = tonumber(opts.radius)
	local face_dir = opts.face
	if face_dir and face_dir:Length() >= 0.01 then
		d[item.own_key.."hold_face"] = face_dir:Normalized()
	else
		d[item.own_key.."hold_face"] = nil
	end
end

--- Flight 运动侧：仅输出期提示
--- 虚空环：每帧检测目标是否在环内；在环外则朝目标补速追进
local function pick_maw_chase_target(air, air_key)
	local d = air:GetData()
	local function alive(ent)
		return ent ~= nil and ent.Exists and ent:Exists() and ent.IsDead and not ent:IsDead()
	end
	local target = d[air_key.."Target"]
	if alive(target) then return target end
	local sticky = d[item.own_key.."sticky_target"]
	if alive(sticky) then return sticky end
	local best, best_d = nil, nil
	local list = auxi.getenemies and auxi.getenemies() or nil
	if not list then return nil end
	for _, e in pairs(list) do
		if alive(e) and e.Position then
			local dist = (air.Position - e.Position):Length()
			if not best_d or dist < best_d then
				best = e
				best_d = dist
			end
		end
	end
	return best
end

function item.get_move_hint(air)
	if not air then return nil end
	local d = air:GetData()
	local Air = get_air_mod()
	local air_key = Air and Air.own_key or ""
	local until_f = tonumber(d[item.own_key.."hold_until"])
	local now = Game():GetFrameCount()
	if not until_f then return nil end
	if now > until_f then
		d[item.own_key.."hold_until"] = nil
		d[item.own_key.."hold_pos"] = nil
		d[item.own_key.."hold_face"] = nil
		d[item.own_key.."hold_mode"] = nil
		d[item.own_key.."hold_radius"] = nil
		return nil
	end
	local mode = d[item.own_key.."hold_mode"] or "anchor"
	if mode == "maw_chase" then
		local target = pick_maw_chase_target(air, air_key)
		if not target then return nil end
		local radius = tonumber(d[item.own_key.."hold_radius"]) or tonumber(cfg("maw_radius")) or 80
		local ideal_frac = tonumber(cfg("maw_chase_ideal_frac")) or 0.4
		local ideal = math.max(18, radius * ideal_frac)
		local slack = tonumber(cfg("maw_chase_slack")) or 4
		local dist = (air.Position - target.Position):Length()
		-- 已深入环内理想距：不干预
		if dist <= ideal + slack then
			return nil
		end
		local to = target.Position - air.Position
		if to:Length() < 0.01 then return nil end
		return {
			mode = "maw_chase",
			toward = to:Normalized(),
			overshoot = dist - ideal,
			ideal = ideal,
			radius = radius,
			boost_base = tonumber(cfg("maw_chase_boost_base")) or 3.2,
			boost_per = tonumber(cfg("maw_chase_boost_per")) or 0.32,
			boost_cap = tonumber(cfg("maw_chase_boost_cap")) or 12,
		}
	end
	local pos = d[item.own_key.."hold_pos"]
	if not pos then return nil end
	return {
		mode = "anchor",
		pos = pos,
		face = d[item.own_key.."hold_face"],
		weight = tonumber(cfg("hold_weight")) or 0.55,
		settle = tonumber(cfg("hold_settle_radius")) or 10,
	}
end

-- 兼容旧名
function item.get_output_hold(air)
	return item.get_move_hint(air)
end

local function bar_id(kind, air)
	local uid = tonumber(craft_uid_of(air)) or (air and air.InitSeed) or 0
	return "craft_" .. kind .. "_" .. tostring(uid)
end

local function set_bar_counter(air, kind, ratio01)
	local id = bar_id(kind, air)
	local d = air:GetData()
	local name1 = id .. "_Charge_Bar_buff"
	d[name1] = math.max(0, math.min(100, math.floor((tonumber(ratio01) or 0) * 100 + 0.5)))
end

local function remove_bar(air, kind)
	if not air then return end
	Charging_Bar_holder.remove_charge_bar(air, bar_id(kind, air))
end

local function render_bar(air, kind, ratio01, show)
	if not air then return end
	local id = bar_id(kind, air)
	local pct = math.max(0, math.min(100, math.floor((tonumber(ratio01) or 0) * 100 + 0.5)))
	set_bar_counter(air, kind, ratio01)
	if not show or pct <= 5 then
		-- 仍调用一次以驱动消失动画；check1 失败时 holder 会 Disappear
		Charging_Bar_holder.render_me(air, {
			name1 = id,
			name2 = id,
			name3 = id,
			loadname = CHARGE_BAR_ANM2,
			NoOffset = true,
			check1 = function() return false end,
			check2 = function() return false end,
			check3 = function() return 0 end,
		})
		return
	end
	Charging_Bar_holder.render_me(air, {
		name1 = id,
		name2 = id,
		name3 = id,
		loadname = CHARGE_BAR_ANM2,
		NoOffset = true,
		check1 = function() return pct > 5 end,
		check2 = function() return pct >= 100 end,
		check3 = function() return pct end,
	})
end

--- 开火蓄力：窗口内蓄；满+条 Charged 自动放。
--- intent: true=正常蓄；"hold"=暂停蓄但保留并可满蓄释放；false=清零。
local function bar_is_charged(air, kind)
	if not air then return false end
	local id = bar_id(kind, air)
	local spr = air:GetData()[id .. "_Charge_Bar"]
	if spr and spr:IsPlaying("Charged") then
		return true
	end
	local ready = tonumber(air:GetData()[item.own_key..kind.."_ready_frames"]) or 0
	local fallback = math.max(1, math.floor(tonumber(cfg("bar_ready_fallback")) or 10))
	return ready >= fallback
end

local function tick_fire_charge(air, key, intent, full_frames)
	local d = air:GetData()
	local charge = tonumber(d[item.own_key..key.."_charge"]) or 0
	local cd = tonumber(d[item.own_key..key.."_cd"]) or 0
	local ready_frames = tonumber(d[item.own_key..key.."_ready_frames"]) or 0
	local release = false
	local holding = intent == "hold"
	local attacking = intent == true
	if cd > 0 then
		cd = cd - 1
		charge = 0
		ready_frames = 0
	elseif attacking then
		charge = math.min(1, charge + 1 / math.max(1, full_frames))
		if charge >= 1 then
			ready_frames = ready_frames + 1
			d[item.own_key..key.."_ready_frames"] = ready_frames
			if bar_is_charged(air, key) then
				release = true
				charge = 0
				ready_frames = 0
				cd = math.max(1, math.floor(tonumber(cfg("charge_cooldown")) or 20))
			end
		else
			ready_frames = 0
		end
	elseif holding then
		-- 暂停蓄力增长，保留当前蓄力；已满仍可释放
		if charge >= 1 then
			ready_frames = ready_frames + 1
			d[item.own_key..key.."_ready_frames"] = ready_frames
			if bar_is_charged(air, key) then
				release = true
				charge = 0
				ready_frames = 0
				cd = math.max(1, math.floor(tonumber(cfg("charge_cooldown")) or 20))
			end
		end
	else
		charge = 0
		ready_frames = 0
	end
	d[item.own_key..key.."_charge"] = charge
	d[item.own_key..key.."_cd"] = cd
	d[item.own_key..key.."_ready_frames"] = ready_frames
	d[item.own_key..key.."_was"] = attacking or holding
	return charge, release
end

--- 攻击窗口短暂丢失但粘性目标仍存活、且暂无其他可打目标 → hold 蓄力
local function resolve_charge_intent(air, attacking)
	local d = air:GetData()
	local Air = get_air_mod()
	local air_key = Air and Air.own_key or ""
	local target = d[air_key.."Target"]
	if auxi.check_all_exists(target) then
		d[item.own_key.."sticky_target"] = target
	end
	local sticky = d[item.own_key.."sticky_target"]
	local sticky_alive = sticky ~= nil and sticky.Exists and sticky:Exists() and sticky.IsDead and not sticky:IsDead()
	if not sticky_alive then
		d[item.own_key.."sticky_target"] = nil
		d[item.own_key.."charge_grace"] = 0
	end

	if attacking then
		d[item.own_key.."charge_grace"] = 0
		return true
	end

	local grace = tonumber(d[item.own_key.."charge_grace"]) or 0
	local grace_max = math.max(1, math.floor(tonumber(cfg("charge_grace_frames")) or 30))
	-- 刚从攻击窗口掉下来：若粘性目标仍存活，且当前没有可打目标，开启 grace
	if sticky_alive then
		local other = nil
		if auxi.get_nearest_enemy then
			other = auxi.get_nearest_enemy(nil, air.Position)
		end
		-- other 若是粘性目标本身（跳起后可能仍不在 isenemies 里），或完全没有其他敌人
		local has_other = other and other ~= sticky and auxi.check_all_exists(other)
		if not has_other then
			if grace <= 0 and d[item.own_key.."was_attacking"] then
				grace = grace_max
			end
			if grace > 0 then
				grace = grace - 1
				d[item.own_key.."charge_grace"] = grace
				-- 用粘性目标位置刷新瞄准
				local to = sticky.Position - air.Position
				if to:Length() >= 0.01 then
					d[item.own_key.."last_aim"] = to:Normalized()
				end
				return "hold"
			end
		end
	end
	d[item.own_key.."charge_grace"] = 0
	return false
end

--- 以 Flight 为中心生成虚空环（399 满蓄）。
--- opts.life / radius / size / scale 可覆盖；opts.hold=false 时不进入追环移动提示。
--- opts.damage 可覆盖伤害（默认 Flight damage）。
function item.spawn_maw_ring(air, player, craft_prof, opts)
	if not air or not player or not player.SpawnMawOfVoid then return nil end
	opts = opts or {}
	local life = math.max(1, math.floor(tonumber(opts.life) or tonumber(cfg("maw_life")) or 60))
	local laser = player:SpawnMawOfVoid(life)
	if not laser then return nil end
	laser = laser:ToLaser() or laser
	laser.Parent = air
	laser.SpawnerEntity = air
	laser.Position = air.Position
	if laser.ParentOffset ~= nil then laser.ParentOffset = Vector(0, 0) end
	-- 枪口相对 Flight PO = 0
	laser.PositionOffset = copy_po(air.PositionOffset)
	if LaserSubType and LaserSubType.LASER_SUBTYPE_RING_FOLLOW_PARENT then
		laser.SubType = LaserSubType.LASER_SUBTYPE_RING_FOLLOW_PARENT
	else
		laser.SubType = 3
	end
	local radius = tonumber(opts.radius) or tonumber(cfg("maw_radius")) or 80
	if laser.Radius ~= nil then laser.Radius = radius end
	local size = tonumber(opts.size) or tonumber(cfg("maw_size")) or 16
	if laser.Size ~= nil then laser.Size = size end
	local scale = tonumber(opts.scale) or tonumber(cfg("maw_scale")) or 1.0
	if laser.SetScale then
		pcall(function() laser:SetScale(scale) end)
	elseif laser.SpriteScale then
		laser.SpriteScale = Vector(scale, scale)
	end
	local dmg = tonumber(opts.damage) or flight_damage(craft_prof, player)
	laser.CollisionDamage = dmg
	-- 不继承泪特效 / 我的镜像 CurveStrength / 弯勺 HomingType
	if CraftProfile and CraftProfile.write_entity_tear_flags then
		CraftProfile.write_entity_tear_flags(laser, BitSet128(0, 0))
		CraftProfile.apply_laser_craft_motion(laser, BitSet128(0, 0))
	elseif laser.TearFlags ~= nil then
		laser.TearFlags = BitSet128(0, 0)
		if laser.CurveStrength ~= nil then laser.CurveStrength = 0 end
	end
	-- 环激光不锁 Angle（无直线方向）；勿写 SpriteRotation
	laser:GetData()[item.own_key.."maw"] = {
		air_seed = air.InitSeed,
		life = life,
		source = opts.source or "maw",
	}
	if opts.hold ~= false then
		begin_output_hold(air, life, {
			mode = "maw_chase",
			radius = radius,
			pos = air.Position,
		})
	end
	return laser
end

local function fire_maw(air, player, craft_prof)
	item.spawn_maw_ring(air, player, craft_prof, {source = "maw", hold = true})
end

local function fire_revelation(air, player, craft_prof, aim)
	if not air or not player then return end
	if not aim or aim:Length() < 0.01 then aim = Vector(0, 1) end
	aim = aim:Normalized()
	local dmg = flight_damage(craft_prof, player)
	local timeout = math.max(1, math.floor(tonumber(cfg("rev_timeout")) or 20))
	-- 与 Item_TianYi.attack 同构；Angle 是世界角，只写一次，禁止用父体 Sprite.Rotation 做差补
	local q = Isaac.Spawn(7, 5, 0, air.Position, Vector(0, 0), player):ToLaser()
	if not q then return end
	q.Parent = air
	q.CollisionDamage = dmg
	q:SetTimeout(timeout)
	q.Angle = aim:GetAngleDegrees()
	q.DepthOffset = 100
	q.PositionOffset = copy_po(air.PositionOffset)
	q:GetData()[item.own_key.."rev"] = {
		air_seed = air.InitSeed,
		timeout = timeout,
	}
	begin_output_hold(air, timeout + 8, {
		mode = "anchor",
		pos = air.Position,
		face = aim,
	})
end

local function tick_neptune(air, craft_prof, attacking)
	if count_of(craft_prof, IDS.NEPTUNE) <= 0 then
		air:GetData()[item.own_key.."nep_charge"] = nil
		remove_bar(air, "nep")
		return 0
	end
	local d = air:GetData()
	local charge = tonumber(d[item.own_key.."nep_charge"]) or 0
	local fill = math.max(1, math.floor(tonumber(cfg("nep_fill_frames")) or 180))
	local drain = math.max(1, math.floor(tonumber(cfg("nep_drain_frames")) or 60))
	if attacking then
		charge = math.max(0, charge - 1 / drain)
	else
		charge = math.min(1, charge + 1 / fill)
	end
	d[item.own_key.."nep_charge"] = charge
	local lo = tonumber(cfg("nep_fire_rate_min")) or 1
	local hi = tonumber(cfg("nep_fire_rate_max")) or 6
	local mul = lo + (hi - lo) * charge
	d[item.own_key.."nep_fire_rate_mul"] = mul
	return charge
end

function item.get_neptune_fire_rate_mul(air)
	if not air then return 1 end
	return tonumber(air:GetData()[item.own_key.."nep_fire_rate_mul"]) or 1
end

function item.tick_flight(air, player, craft_prof, attacking, aim_dir)
	if not air or not player or not craft_prof then return end
	local full = math.max(1, math.floor(tonumber(cfg("charge_full_frames")) or 71))
	local d = air:GetData()
	if aim_dir and aim_dir:Length() >= 0.01 then
		d[item.own_key.."last_aim"] = aim_dir:Normalized()
	end
	local intent = resolve_charge_intent(air, attacking == true)
	d[item.own_key.."was_attacking"] = attacking == true
	local aim = d[item.own_key.."last_aim"] or aim_dir or Vector(0, 1)

	-- 399 Maw
	if count_of(craft_prof, IDS.MAW) > 0 then
		local charge, release = tick_fire_charge(air, "maw", intent, full)
		d[item.own_key.."maw_bar"] = charge
		if release then
			fire_maw(air, player, craft_prof)
		end
	else
		d[item.own_key.."maw_charge"] = nil
		d[item.own_key.."maw_was"] = nil
		d[item.own_key.."maw_bar"] = nil
		d[item.own_key.."maw_cd"] = nil
		d[item.own_key.."maw_ready_frames"] = nil
		remove_bar(air, "maw")
	end

	-- 643 Revelation
	if count_of(craft_prof, IDS.REVELATION) > 0 then
		local charge, release = tick_fire_charge(air, "rev", intent, full)
		d[item.own_key.."rev_bar"] = charge
		if release then
			fire_revelation(air, player, craft_prof, aim)
		end
	else
		d[item.own_key.."rev_charge"] = nil
		d[item.own_key.."rev_was"] = nil
		d[item.own_key.."rev_bar"] = nil
		d[item.own_key.."rev_cd"] = nil
		d[item.own_key.."rev_ready_frames"] = nil
		remove_bar(air, "rev")
	end

	-- 597 Neptune（蓄积条；射速倍率写入 data 供 build_runtime）
	-- 海王星用真实攻击窗口：grace 期间视为未攻击（继续蓄积）更合理
	local nep_attacking = attacking == true
	local nep_charge = tick_neptune(air, craft_prof, nep_attacking)
	d[item.own_key.."nep_bar"] = nep_charge
end

function item.render_flight_bars(air, craft_prof)
	if not air or not craft_prof then return end
	local d = air:GetData()
	if count_of(craft_prof, IDS.MAW) > 0 then
		local c = tonumber(d[item.own_key.."maw_bar"]) or 0
		render_bar(air, "maw", c, c > 0.05)
	end
	if count_of(craft_prof, IDS.REVELATION) > 0 then
		local c = tonumber(d[item.own_key.."rev_bar"]) or 0
		render_bar(air, "rev", c, c > 0.05)
	end
	if count_of(craft_prof, IDS.NEPTUNE) > 0 then
		local c = tonumber(d[item.own_key.."nep_bar"]) or 0
		render_bar(air, "nep", c, c > 0.05)
	end
end

function item.clear_flight(air)
	if not air then return end
	local d = air:GetData()
	for _, k in ipairs({"maw", "rev", "nep"}) do
		d[item.own_key..k.."_charge"] = nil
		d[item.own_key..k.."_was"] = nil
		d[item.own_key..k.."_bar"] = nil
		d[item.own_key..k.."_cd"] = nil
		d[item.own_key..k.."_ready_frames"] = nil
		remove_bar(air, k)
	end
	d[item.own_key.."nep_fire_rate_mul"] = nil
	d[item.own_key.."last_aim"] = nil
	d[item.own_key.."hold_until"] = nil
	d[item.own_key.."hold_pos"] = nil
	d[item.own_key.."hold_face"] = nil
	d[item.own_key.."hold_mode"] = nil
	d[item.own_key.."hold_radius"] = nil
	d[item.own_key.."sticky_target"] = nil
	d[item.own_key.."charge_grace"] = nil
	d[item.own_key.."was_attacking"] = nil
end

-- Maw：跟 Flight 位置。启示：与天依相同，生成后不再改 Angle。
table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_LASER_UPDATE,
	params = nil,
	Function = function(_, laser)
		if not laser then return end
		local is_maw = laser:GetData()[item.own_key.."maw"]
		if not is_maw then return end
		local air = laser.Parent
		if air and auxi.check_all_exists(air) then
			laser.Position = air.Position
			if laser.PositionOffset then
				laser.PositionOffset = copy_po(air.PositionOffset)
			end
		end
	end,
})

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_FAMILIAR_RENDER,
	params = nil,
	Function = function(_, fam)
		local Air = get_air_mod()
		if not fam or not Air or fam.Variant ~= Air.familiar then return end
		local craft_prof = fam:GetData()[Air.own_key.."craft_profile"]
		if craft_prof then
			item.render_flight_bars(fam, craft_prof)
		end
	end,
})

return item
