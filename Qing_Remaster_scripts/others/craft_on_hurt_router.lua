-- Flight 受伤触发轻量路由（v2 七项 + 702 复仇之火；408 Athame 受伤环已废止 2026-08-16）。
-- 审阅：orbital_on_hurt_implementation_review.md
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local enums = require("Qing_Remaster_scripts.core.enums")

local item = {
	ToCall = {},
	pre_ToCall = {},
	own_key = "craft_on_hurt_router_",
}

-- 仅跟踪真正处于贫血轨迹状态的 Flight；按 InitSeed 避免 userdata wrapper 身份不稳定。
local active_anemic_airs = {}

local IDS = {
	BLACK_BEAN = 180,
	ANEMIC = 214,
	VARICOSE = 452,
	IT_HURTS = 560,
	LARGE_ZIT = 502,
	BEST_BUD = 274,
	LEPROSY = 525,
	SMART_FLY = 264,
	-- ATHAME = 408, -- 原版已无受伤触发；制造兼容已注释
	VENGEFUL = 702,
}

local TOKEN_TTL = 2
local recent_tokens = {}

local function get_blueprint()
	return require("Qing_Remaster_scripts.items.Item_Blue_Print")
end

local function get_air_mod()
	return require("Qing_Remaster_scripts.items.Item_Air_Flight")
end

local function get_orbital()
	return require("Qing_Remaster_scripts.mimics.Craft_Orbital_holder")
end

local function get_prototype()
	local ok, mod = pcall(require, "Qing_Remaster_scripts.pickups.pickup_blueprint_prototype")
	if ok then return mod end
	return nil
end

local function truly_owns(player, id)
	return player and player.HasCollectible and player:HasCollectible(id, true) == true
end

local function craft_count(profile, id)
	return tonumber(profile and profile.counts and profile.counts[id]) or 0
end

local function prune_tokens(frame)
	for k, until_f in pairs(recent_tokens) do
		if (tonumber(until_f) or 0) < frame then
			recent_tokens[k] = nil
		end
	end
end

local function source_seed(source)
	if not source then return 0 end
	local ent = source.Entity
	if ent then
		return tonumber(ent.InitSeed) or GetPtrHash(ent) or 0
	end
	return tonumber(source.InitSeed) or 0
end

local function make_token(player, amount, flags, source, countdown)
	local frame = Game():GetFrameCount()
	local parts = {
		tostring(player and (player.InitSeed or GetPtrHash(player)) or 0),
		tostring(frame),
		tostring(source_seed(source)),
		tostring(flags or 0),
		tostring(math.floor((tonumber(amount) or 0) * 100 + 0.5)),
		tostring(countdown or 0),
	}
	return table.concat(parts, "|"), frame
end

local function is_prototype_devil_spike(source)
	local proto = get_prototype()
	if not proto or not source or not source.Entity then return false end
	local pk = source.Entity:ToPickup()
	if not pk then return false end
	local d = pk:GetData()
	return d[proto.own_key.."devil_spike"] == true
end

--- 只排假伤 / 未成立 / 明确标记不触发；不用逾越节蜡烛过滤
local function is_eligible(event)
	if not event then return false end
	if event.is_fake then return false end
	if (tonumber(event.amount) or 0) <= 0 then return false end
	if event.skip_marked then return false end
	return true
end

local function event_rng(player, air, event, salt)
	local seed = (air and air.InitSeed or 1)
		+ (event.token_num or 0)
		+ (tonumber(salt) or 0) * 65537
	seed = math.abs(seed) % 2147483647
	if seed == 0 then seed = 1 end
	local rng = RNG()
	rng:SetSeed(seed, 35)
	return rng
end

local function list_player_flights(player)
	local Air = get_air_mod()
	local Orb = get_orbital()
	local out = {}
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, Air.familiar or enums.Familiars.QingsAirs, -1, false, false)) do
		local air = ent:ToFamiliar()
		local owner = air and auxi.check_spawner_player(air)
		if air and owner and auxi.check_for_the_same(owner, player) then
			local state = Orb.get_air_combat_state(air, player)
			-- 七项受伤效果仅 active；degraded/inactive 不触发
			if state == "active" then
				local profile = air:GetData()[Air.own_key.."craft_profile"]
				out[#out + 1] = {air = air, profile = profile}
			end
		end
	end
	return out
end

local function stamp_hurt_attack(ent2, air, extra)
	if not ent2 or not air then return end
	local Air = get_air_mod()
	local td = ent2:GetData()
	td[Air.own_key.."craft_air"] = air
	td[Air.own_key.."craft_uid"] = air:GetData()[get_blueprint().own_key.."craft_uid"]
	td[item.own_key.."from_hurt"] = true
	if extra then
		for k, v in pairs(extra) do td[k] = v end
	end
end

local function effect_black_bean(air, _player, _profile, _event, budget)
	-- 仅走 Game():Fart，避免手工循环双结算
	budget = budget or 1
	local radius = 85 * math.sqrt(budget)
	Game():Fart(air.Position, radius, air, 1, 0)
end

local function effect_anemic(air, _player, _profile, _event, _budget)
	local Air = get_air_mod()
	local d = air:GetData()
	d[Air.own_key.."anemic_room"] = Game():GetLevel():GetCurrentRoomIndex()
	-- 本房间持续，直到换房清除；不再限时 8 秒
	d[Air.own_key.."anemic_active"] = true
	active_anemic_airs[air.InitSeed] = air
end

local function effect_varicose(air, player, profile, event, budget)
	-- wiki：10 颗，+25 伤；本批按 Flight 伤害链 +25，再乘事件预算
	budget = budget or 1
	local dmg = ((profile.stats and profile.stats.damage) or (player and player.Damage) or 3.5) + 25
	dmg = dmg * budget
	local n = 10
	for i = 1, n do
		local ang = (i - 1) * (360 / n)
		local tear = Isaac.Spawn(EntityType.ENTITY_TEAR, TearVariant.BLOOD, 0, air.Position, auxi.MakeVector(ang) * 8, air):ToTear()
		if tear then
			tear.CollisionDamage = dmg
			tear.Parent = air
			tear.SpawnerEntity = air
			stamp_hurt_attack(tear, air)
		end
	end
end

local function effect_it_hurts(air, player, profile, event, budget)
	budget = budget or 1
	local dmg = ((profile.stats and profile.stats.damage) or (player and player.Damage) or 3.5) * budget
	local count = 10
	local rng = event_rng(player, air, event, 560)
	for i = 1, count do
		local ang = (i - 1) * (360 / count) + rng:RandomFloat() * 4
		local dir = auxi.MakeVector(ang)
		local tear = Isaac.Spawn(EntityType.ENTITY_TEAR, TearVariant.BLOOD, 0, air.Position, dir * 9, air):ToTear()
		if tear then
			tear.CollisionDamage = dmg
			tear.Scale = 1.35
			tear.Parent = air
			tear.SpawnerEntity = air
			stamp_hurt_attack(tear, air)
		end
	end
	local creep = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.PLAYER_CREEP_RED or 46, 0, air.Position, Vector.Zero, air)
	if creep then
		creep.Parent = air
		creep.SpawnerEntity = air
		stamp_hurt_attack(creep, air)
	end
	local Air = get_air_mod()
	local d = air:GetData()
	local room = Game():GetLevel():GetCurrentRoomIndex()
	if d[Air.own_key.."it_hurts_room"] ~= room then
		d[Air.own_key.."it_hurts_room"] = room
		d[Air.own_key.."it_hurts_hits"] = 0
	end
	-- 原版可无限叠：首击 +1.2 FR，之后每次 +0.4
	d[Air.own_key.."it_hurts_hits"] = (tonumber(d[Air.own_key.."it_hurts_hits"]) or 0) + 1
end

local function effect_large_zit(air, player, profile, event, budget)
	budget = budget or 1
	local rng = event_rng(player, air, event, 502)
	local ang = rng:RandomFloat() * 360
	local dmg = ((profile.stats and profile.stats.damage) or (player and player.Damage) or 3.5) * 2 * budget
	-- 与 craft_aura_effects 对齐：常规泪 + 粉 Offset，非 BOOGER
	local tear = Isaac.Spawn(
		EntityType.ENTITY_TEAR, TearVariant.BLUE or 0, 0,
		air.Position, auxi.MakeVector(ang) * 7, air
	):ToTear()
	if tear then
		tear.CollisionDamage = dmg
		tear.Scale = 1.0
		tear:SetColor(Color(0.3, 0.3, 0.3, 1, 0.7, 0.7, 0.7), -1, 1, false, false)
		if tear.AddTearFlags and TearFlags.TEAR_CREEP_WHITE then
			tear:AddTearFlags(TearFlags.TEAR_CREEP_WHITE)
		end
		tear.Parent = air
		tear.SpawnerEntity = air
		-- 白水迹在命中/消失时生成，不在脚下立刻生成
		stamp_hurt_attack(tear, air, {[item.own_key.."large_zit"] = true})
	end
end

local function spawn_zit_creep(tear)
	if not tear then return end
	local td = tear:GetData()
	if not td[item.own_key.."large_zit"] or td[item.own_key.."zit_creep_done"] then return end
	td[item.own_key.."zit_creep_done"] = true
	local air = td[get_air_mod().own_key.."craft_air"]
	local creep = Isaac.Spawn(
		EntityType.ENTITY_EFFECT, EffectVariant.PLAYER_CREEP_WHITE or 44, 0,
		tear.Position, Vector.Zero, air or tear
	)
	if creep then
		local fx = creep:ToEffect() or creep
		if fx.SetTimeout then
			pcall(function() fx:SetTimeout(125) end)
		elseif fx.Timeout ~= nil then
			pcall(function() fx.Timeout = 125 end)
		end
		if air then
			fx.Parent = air
			fx.SpawnerEntity = air
			stamp_hurt_attack(fx, air)
		end
	end
end

local function effect_best_bud(air, player)
	get_orbital().spawn_best_bud(air, player)
end

local function effect_leprosy(air, player)
	get_orbital().spawn_or_repair_leprosy(air, player)
end

local function effect_smart_fly(air, _player)
	local Orb = get_orbital()
	local frames = (Orb.debug and tonumber(Orb.debug.smart_fly_chase_frames)) or 180
	Orb.notify_smart_fly_chase(air, frames)
end

--- 408 Athame：原版已无受伤触发效果（2026-08-16 确认）→ 制造侧兼容已停用。
-- local function effect_athame(air, player, profile, _event, budget)
-- 	local Charge = require("Qing_Remaster_scripts.others.craft_charge_weapons")
-- 	if not Charge or not Charge.spawn_maw_ring then return end
-- 	budget = tonumber(budget) or 1
-- 	local dmg = ((profile and profile.stats and profile.stats.damage) or (player and player.Damage) or 3.5) * budget
-- 	Charge.spawn_maw_ring(air, player, profile, {
-- 		source = "athame",
-- 		hold = false,
-- 		damage = dmg,
-- 	})
-- end

local function effect_vengeful(_air, player)
	local ok, Aux = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Aux_Entities_holder")
	if ok and Aux and Aux.effect_vengeful_hurt then
		Aux.effect_vengeful_hurt(_air, player)
	end
end

local HANDLERS = {
	[IDS.BLACK_BEAN] = {fn = effect_black_bean},
	[IDS.ANEMIC] = {fn = effect_anemic},
	[IDS.VARICOSE] = {fn = effect_varicose},
	[IDS.IT_HURTS] = {fn = effect_it_hurts},
	[IDS.LARGE_ZIT] = {fn = effect_large_zit},
	[IDS.BEST_BUD] = {fn = effect_best_bud},
	[IDS.LEPROSY] = {fn = effect_leprosy},
	[IDS.SMART_FLY] = {fn = effect_smart_fly},
	-- [IDS.ATHAME] = {fn = effect_athame},
	[IDS.VENGEFUL] = {fn = effect_vengeful},
}

function item.dispatch(player, event)
	if not player or not event or not is_eligible(event) then return end
	local flights = list_player_flights(player)
	if #flights == 0 then return end
	-- 447 流连豆：受伤重置连攻计时（气云已生成则保留）
	do
		local ok, Aura = pcall(require, "Qing_Remaster_scripts.others.craft_aura_effects")
		if ok and Aura and Aura.on_player_hurt then
			pcall(Aura.on_player_hurt, player)
		end
	end

	for id, handler in pairs(HANDLERS) do
		-- 玩家真实持有：原版生实体 / 特殊通知；Flight 仍须接管（魂火、聪明苍蝇）
		if truly_owns(player, id) and id ~= IDS.SMART_FLY and id ~= IDS.VENGEFUL then goto continue end

		local responders = {}
		for _, row in ipairs(flights) do
			if craft_count(row.profile, id) > 0 and row.air then
				responders[#responders + 1] = row
			end
		end
		if #responders == 0 then goto continue end

		-- 多 Flight：按同事件触发台数分摊，而非单台材料数量
		local budget = 1 / math.sqrt(#responders)
		for _, row in ipairs(responders) do
			pcall(handler.fn, row.air, player, row.profile, event, budget)
		end
		::continue::
	end
end

function item.tick_anemic_trails()
	if next(active_anemic_airs) == nil then return end
	local Air = get_air_mod()
	local room = Game():GetLevel():GetCurrentRoomIndex()
	for seed, air in pairs(active_anemic_airs) do
		local ok, live = pcall(function() return air and air:Exists() and not air:IsDead() end)
		if not ok or not live then
			active_anemic_airs[seed] = nil
			goto continue
		end
		local d = air:GetData()
		if d[Air.own_key.."anemic_active"] and d[Air.own_key.."anemic_room"] == room then
			if Air.combat_allowed and not Air.combat_allowed(air) then
				d[Air.own_key.."anemic_active"] = nil
				d[Air.own_key.."anemic_room"] = nil
				active_anemic_airs[seed] = nil
			elseif Game():GetFrameCount() % 4 == 0 then
				local creep = Isaac.Spawn(
					EntityType.ENTITY_EFFECT, EffectVariant.PLAYER_CREEP_RED or 46, 0,
					air.Position, Vector.Zero, air
				)
				if creep then
					creep.Parent = air
					creep.SpawnerEntity = air
					stamp_hurt_attack(creep, air)
				end
			end
		elseif d[Air.own_key.."anemic_active"] then
			d[Air.own_key.."anemic_active"] = nil
			d[Air.own_key.."anemic_room"] = nil
			active_anemic_airs[seed] = nil
		else
			active_anemic_airs[seed] = nil
		end
		::continue::
	end
end

local function build_event(player, amount, flags, source, countdown)
	local token, frame = make_token(player, amount, flags, source, countdown)
	local token_num = 0
	for i = 1, #token do token_num = token_num + string.byte(token, i) end
	return {
		player = player,
		amount = tonumber(amount) or 0,
		flags = flags or 0,
		source = source,
		countdown = countdown,
		frame = frame,
		token = token,
		token_num = token_num,
		room_index = Game():GetLevel():GetCurrentRoomIndex(),
		is_fake = DamageFlag.DAMAGE_FAKE and ((flags or 0) & DamageFlag.DAMAGE_FAKE) ~= 0,
		skip_marked = is_prototype_devil_spike(source),
	}
end

local function try_dispatch(player, amount, flags, source, countdown)
	if not player or (amount or 0) <= 0 then return end
	local event = build_event(player, amount, flags, source, countdown)
	if not is_eligible(event) then return end
	prune_tokens(event.frame)
	if recent_tokens[event.token] then return end
	recent_tokens[event.token] = event.frame + TOKEN_TTL
	item.dispatch(player, event)
end

-- 优先 POST；无 RGON 时 PRE 快照 + 下一帧生命差确认
if ModCallbacks.MC_POST_ENTITY_TAKE_DMG then
	table.insert(item.ToCall, {
		CallBack = ModCallbacks.MC_POST_ENTITY_TAKE_DMG,
		params = EntityType.ENTITY_PLAYER,
		Function = function(_, ent, amount, flags, source, countdown, _extra)
			local player = ent and ent:ToPlayer()
			try_dispatch(player, amount, flags, source, countdown)
		end,
	})
else
	table.insert(item.pre_ToCall, {
		CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG,
		params = EntityType.ENTITY_PLAYER,
		Function = function(_, ent, amount, flags, source, countdown)
			local player = ent and ent:ToPlayer()
			if not player or (amount or 0) <= 0 then return end
			if DamageFlag.DAMAGE_FAKE and ((flags or 0) & DamageFlag.DAMAGE_FAKE) ~= 0 then return end
			local d = player:GetData()
			d[item.own_key.."pre_snap"] = d[item.own_key.."pre_snap"] or {}
			d[item.own_key.."pre_snap"][#d[item.own_key.."pre_snap"] + 1] = {
				frame = Game():GetFrameCount(),
				hearts = player:GetHearts() + player:GetSoulHearts() + (player.GetBoneHearts and player:GetBoneHearts() or 0),
				amount = amount,
				flags = flags,
				source = source,
				countdown = countdown,
			}
		end,
	})
	table.insert(item.ToCall, {
		CallBack = ModCallbacks.MC_POST_UPDATE,
		params = nil,
		Function = function()
			for i = 0, Game():GetNumPlayers() - 1 do
				local player = Game():GetPlayer(i)
				if not player then goto cont end
				local d = player:GetData()
				local snaps = d[item.own_key.."pre_snap"]
				if not snaps or #snaps == 0 then goto cont end
				local now = player:GetHearts() + player:GetSoulHearts() + (player.GetBoneHearts and player:GetBoneHearts() or 0)
				local kept = {}
				local frame = Game():GetFrameCount()
				for _, snap in ipairs(snaps) do
					if frame > (snap.frame or 0) then
						if now < (snap.hearts or 0) then
							try_dispatch(player, snap.amount, snap.flags, snap.source, snap.countdown)
						end
					else
						kept[#kept + 1] = snap
					end
				end
				d[item.own_key.."pre_snap"] = kept
				::cont::
			end
		end,
	})
end

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		item.tick_anemic_trails()
	end,
})

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		active_anemic_airs = {}
		local Air = get_air_mod()
		for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, Air.familiar or enums.Familiars.QingsAirs, -1, false, false)) do
			local d = ent:GetData()
			d[Air.own_key.."anemic_active"] = nil
			d[Air.own_key.."anemic_room"] = nil
			d[Air.own_key.."it_hurts_hits"] = nil
			d[Air.own_key.."it_hurts_room"] = nil
		end
		recent_tokens = {}
	end,
})

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION,
	params = nil,
	Function = function(_, tear, collider, _low)
		if not tear or not collider then return end
		local td = tear:GetData()
		if not td[item.own_key.."large_zit"] then return end
		if collider:IsVulnerableEnemy() and not collider:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
			spawn_zit_creep(tear)
		end
	end,
})

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE,
	params = EntityType.ENTITY_TEAR,
	Function = function(_, ent)
		local tear = ent and ent:ToTear()
		if tear then spawn_zit_creep(tear) end
	end,
})

--- Air 射速：把痛痛本房叠层折成 fire rate 加成
function item.apply_it_hurts_delay(air, delay)
	if not air then return delay end
	local Air = get_air_mod()
	local d = air:GetData()
	local room = Game():GetLevel():GetCurrentRoomIndex()
	if d[Air.own_key.."it_hurts_room"] ~= room then return delay end
	local hits = tonumber(d[Air.own_key.."it_hurts_hits"]) or 0
	if hits <= 0 then return delay end
	local bonus = 1.2 + (hits - 1) * 0.4
	local fr = 30 / (math.max(1, tonumber(delay) or 10) + 1)
	fr = fr + bonus
	return math.max(1, 30 / math.max(0.1, fr) - 1)
end

return item
