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
local attack_holder = require("Qing_Remaster_scripts.callbacks.attack_trigger_holder")
local CraftIdentity = require("Qing_Remaster_scripts.mimics.craft_identity")
local CharRound = require("Qing_Remaster_scripts.player.character_attack_round")
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

local Air = {}
Air.get_blueprint = get_blueprint
Air.get_bandwidth = get_bandwidth

local AirMovement = require("Qing_Remaster_scripts.mimics.air_flight.movement")
AirMovement.attach(item, Air)

local AirCrash = require("Qing_Remaster_scripts.mimics.air_flight.crash")
AirCrash.attach(item, Air)

local AirCombat = require("Qing_Remaster_scripts.mimics.air_flight.combat")
AirCombat.attach(item, Air)

--- §16：制造附属宝宝只消费飞行器发布的攻击意图。
--- 是否攻击与方向均以飞行器本帧实际攻击状态为准，不要求场上存在敌人；
--- 因此小青的强制攻击模式也能驱动绑定宝宝。
-- Transfer 俯仰条：外→下→后→上。
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
	d[item.own_key.."AimSm"] = nil
	d[item.own_key.."FireAimSm"] = nil
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
	Air.apply_air_aim_visual(ent, s, d, Vector(0, 1), false, {pose_bias = ((ent.InitSeed or 1) % 200) / 100 - 1})
	ent.State = 0
	if player then Air.bind_craft_profile(ent, player) end
end,
})


-- 换房：清掉旧房粒子引用（不序列化 userdata）；坠毁状态机保留，新房继续
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function(_)
		for _, fam in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, item.familiar, -1, false, false)) do
			local d = fam:GetData()
			Air.crash_cleanup_fx(d)
			Air.clear_engine_knives(fam)
			d[item.own_key.."AuxAttackQueue"] = nil
			d[item.own_key.."companion_sync_next"] = 0
			d[item.own_key.."companion_sync_sig"] = nil
			d[item.own_key.."companion_resync_until"] = Game():GetFrameCount() + 90
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	params = nil,
	Function = function(_, continued)
		for _, fam in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, item.familiar, -1, false, false)) do
			Air.clear_engine_knives(fam)
			fam:GetData()[item.own_key.."AuxAttackQueue"] = nil
			Air.force_companion_sync(fam)
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
	local craft_prof = Air.bind_craft_profile(ent, player, false, nil)
	Air.apply_body_scale(ent, craft_prof)

	-- 配方缺真实材料/原型：坠毁状态机；制造复活源落地翻滚后再飞（locked 后须蓝图确认才修好）。
	do
		local bp = get_blueprint()
		local uid = CraftIdentity.get_uid(ent)
		local broken = (uid and player and bp.is_craft_broken(player, uid))
			or d[item.own_key.."ForceCrash"] == true
		d[item.own_key.."Broken"] = broken and true or nil
		local rec = (uid and player and bp.find_craft) and bp.find_craft(player, uid) or nil
		local revive_locked = CraftProfile.craft_revive_is_locked(rec)
		if not broken then
			if d[item.own_key.."Crash"] or d[item.own_key.."WasBroken"] then
				Air.crash_cleanup_fx(d)
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
			local status = Air.tick_crash(ent, s, d, {
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
			Air.begin_crash(ent, d)
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
			local status = Air.tick_crash(ent, s, d, {
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
	BW.ensure_reconcile(player)
	local uid = Air.craft_uid(ent)
	-- All Blueprint holders use bandwidth; standby crafts must not keep fighting.
	local standby = uid ~= nil and BW.is_active(player, uid) ~= true
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
	local control = BW.get_control(player)
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
		Air.request_pass_exit(d)
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
		Air.restore_standby_color(ent, d)
		Air.combat_stop_for_standby(ent, d)
	end

	if standby then
		if not was_standby then
			Air.combat_stop_for_standby(ent, d)
		end
		-- Hide Cursed Mask aim linker immediately (UPDATE also culls; tick skips on standby).
		do
			local ok_m, Mask = pcall(require, "Qing_Remaster_scripts.items.Item_Cursed_Mask")
			if ok_m and Mask and Mask.clear_craft_linker then
				Mask.clear_craft_linker(ent, "standby")
			end
		end
		d[item.own_key.."AuxShouldShoot"] = false
		d[item.own_key.."Target"] = nil
		d[item.own_key.."PassAttacking"] = false
		ent.State = 0
		local form = Air.get_form(player, ent, true)
		d[item.own_key.."Form"] = form
		local face = Air.guard_aim_dir(player, mark_pos, last_aim)
		Air.apply_rear_wing_move(ent, d, player, face, form, move_spd, "form")
		Air.apply_standby_dim(ent, d)
		Air.apply_air_aim_visual(ent, s, d, face, false, form)
		Air.sync_trail(ent, d)
		Air.sync_companions(ent, d, craft_prof, player)
		return
	end

	local form = Air.get_form(player, ent, false)
	local state_succ = false
	local fire_anchor = mark_pos
	local move_anchor = mark_pos
	local engage_range = item.Focus2range.cruise or 240

	-- 阵型阶段：只求期望位置。CRUISE+AUTO 可用敌人作盘旋中心；FORCE 不得为找敌偏离。
	-- 持刀：出程减速、顶点停顿、回程加速，不硬钉原地。
	d[item.own_key.."KnifeHold"] = Air.knife_move_hold(ent)
	local engage_enemy = nil
	if formation == item.FORMATION_GUARD then
		local face = Air.guard_aim_dir(player, mark_pos, last_aim)
		move_anchor = player.Position - face * (48 + form.radius_mul * 8)
		Air.apply_rear_wing_move(ent, d, player, face, form, move_spd, "form")
	else
		move_anchor = mark_alive and mark_pos or player.Position
		if fire_mode == item.FIRE_AUTO then
			engage_enemy = Air.pick_cruise_enemy(ent, d, move_anchor, engage_range)
		else
			d[item.own_key.."Target"] = nil
		end
		Air.apply_cruise_move(ent, d, player, mark_pos, mark_alive, form, move_spd, engage_enemy)
	end

	-- 火控阶段：只求 should_shoot / 瞄准点。FORCE 持续打准星。
	if fire_mode == item.FIRE_FORCE then
		state_succ = true
		fire_anchor = mark_pos
		d[item.own_key.."Target"] = nil
		d[item.own_key.."PassAttacking"] = true
	elseif formation == item.FORMATION_GUARD then
		local player_range = math.max(tonumber(player.TearRange) or 260, 120)
		local enemy = Air.pick_enemy_guard(player, mark_pos, last_aim, player_range)
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
		local pred = Air.predict_aim(ent.Position, tgt_ent.Position, tgt_ent.Velocity or Vector(0, 0), approx_ss)
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
	Air.update_combat(ent, {
		s = s,
		d = d,
		player = player,
		craft_prof = craft_prof,
		form = form,
		state_succ = state_succ,
		fire_anchor = fire_anchor,
		mark_pos = mark_pos,
		room = room,
	})
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
			Air.note_hit(ad, true)
		end
		local prof = CraftIdentity.get_profile(air)
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
		if not g.is_gameplay_world_active() then return end
		if not tear then return end
		local td = tear:GetData()
		local air = td[item.own_key.."craft_air"]
		if not air or not auxi.check_all_exists(air) then return end
		if td[item.own_key.."craft_hit"] then return end
		local ad = air:GetData()
		if not td[item.own_key.."hit_noted"] then
			td[item.own_key.."hit_noted"] = true
			Air.note_hit(ad, false)
		end
		local prof = CraftIdentity.get_profile(air)
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
		local prof = CraftIdentity.get_profile(air)
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
		if not g.is_gameplay_world_active() then return end
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

-- Consumer capability: Craft Flight Attack may consume named modules when the craft recipe
-- contains the corresponding collectible. Source identity stays attack_mimic / craft:<uid>.
-- Keys are Attack-level consumer ids (Tech IX / Assassin / Pearl / Evil Intervention / Seeker).
do
	local classifier = attack_holder.classifier
	local CONSUMER_COLLECTIBLE = {
		tech9 = enums.Items.Tech_9,
		assassin = enums.Items.Assassin_s_Eye,
		pearl = enums.Items.Tears_of_Pearl,
		evil_intervention = enums.Items.Evil_Intervention,
		seeker = enums.Items.Seeker_s_Eye,
		gospel = enums.Items.Gospel,
	}
	classifier.RegisterSourceCapabilityResolver(function(source, key, player, attack)
		local col_id = CONSUMER_COLLECTIBLE[key]
		if not col_id then
			return nil
		end
		if not classifier.IsIndependentMimicSource(source) then
			return nil
		end
		local fam = source.entity
		if not fam or fam.Type ~= EntityType.ENTITY_FAMILIAR or fam.Variant ~= item.familiar then
			return nil
		end
		local uid = CraftIdentity.get_uid(fam)
		if not uid then
			return nil
		end
		-- Auth: Craft_Bandwidth_Manager (not Air Flight Standby GetData cache).
		local BW = get_bandwidth()
		if not player or BW.is_active(player, uid) ~= true then
			return false
		end
		-- Any Blueprint holder with a live craft Flight; no Spwq-only gate.
		return classifier.GetCraftCollectibleCount(source, col_id) > 0
	end)
end

return item
