-- 共享邪眼（410）：自管 EffectVariant.EVIL_EYE=84；禁止 FireTear(CanBeEye)。
-- Flight craft / 自定义攻击角色共用 try_spawn + fire_fn。
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local enums = require("Qing_Remaster_scripts.core.enums")

local item = {
	ToCall = {},
	pre_ToCall = {},
	own_key = "Craft_Evil_Eye_holder_",
	cfg = {},
}

local EVIL_COLLECTIBLE = CollectibleType.COLLECTIBLE_EVIL_EYE or 410
local EVIL_EYE_VARIANT = (EffectVariant and EffectVariant.EVIL_EYE) or 84
local EVIL_EYE_ANM2 = "gfx/1000.084_evil eye.anm2"
local EVIL_SHOOT_ANIM_FRAMES = 6

local DEFAULTS = {
	evil_chance_cap = 0.10,
	evil_chance_base_den = 30,
	evil_move_speed = 3,
	evil_first_shot_delay = 20,
	evil_shot_interval = 12,
	evil_tear_speed_mul = 10,
	evil_life = 180,
}

-- [InitSeed] = {eye=, meta=}
local EYES = {}

local function cfg(key)
	local v = item.cfg[key]
	if v ~= nil then return v end
	return DEFAULTS[key]
end

function item.get_defaults()
	local t = {}
	for k, v in pairs(DEFAULTS) do t[k] = v end
	return t
end

function item.set_cfg(key, value)
	if key == nil then return end
	item.cfg[key] = value
end

function item.evil_chance(luck)
	local den = math.max(1, (tonumber(cfg("evil_chance_base_den")) or 30) - math.floor(tonumber(luck) or 0))
	local cap = tonumber(cfg("evil_chance_cap")) or 0.10
	return math.min(1 / den, cap)
end

local function evil_dir_suffix(dir)
	if not dir or dir:Length() < 0.01 then return "Down" end
	local ax, ay = math.abs(dir.X), math.abs(dir.Y)
	if ay >= ax then
		return (dir.Y < 0) and "Up" or "Down"
	end
	return "Side"
end

local function play_evil_eye_anim(eye, dir, shooting)
	if not eye or not eye:Exists() then return end
	local spr = eye:GetSprite()
	if not spr then return end
	local need_load = true
	pcall(function()
		need_load = spr:GetFilename() ~= EVIL_EYE_ANM2
	end)
	if need_load then
		pcall(function()
			spr:Load(EVIL_EYE_ANM2, true)
		end)
	end
	local suffix = evil_dir_suffix(dir)
	local name = (shooting and "Shoot" or "Idle") .. suffix
	if suffix == "Side" then
		spr.FlipX = dir and dir.X < 0
	else
		spr.FlipX = false
	end
	if spr:GetAnimation() ~= name then
		spr:Play(name, true)
	end
end

local function claim_evil_eye(eye, owner)
	if not eye then return end
	eye:GetData()[item.own_key.."evil"] = true
	eye.Parent = nil
	eye.SpawnerEntity = owner
	if eye.SetDisableFollowParent then
		pcall(function() eye:SetDisableFollowParent(true) end)
	elseif eye.DisableFollowParent ~= nil then
		eye.DisableFollowParent = true
	end
	eye.CollisionDamage = 0
	if eye.Timeout ~= nil then eye.Timeout = -1 end
end

local function resolve_aim(meta, eye)
	if meta.aim_fn then
		local ok, aim = pcall(meta.aim_fn, eye, meta.ctx)
		if ok and aim and aim:Length() > 0.01 then
			return aim:Normalized()
		end
	end
	if meta.move and meta.move:Length() > 0.01 then
		return meta.move:Normalized()
	end
	return Vector(0, 1)
end

local function evil_eye_should_die(eye)
	if not eye or not eye:Exists() then return true end
	local room = Game():GetRoom()
	if not room then return false end
	local clamped = room:GetClampedPosition(eye.Position, 8)
	if (clamped - eye.Position):LengthSquared() > 16 then
		return true
	end
	local grid = room:GetGridEntityFromPos(eye.Position)
	if grid then
		local gt = grid:GetType()
		if gt == GridEntityType.GRID_WALL
			or gt == GridEntityType.GRID_ROCK
			or gt == GridEntityType.GRID_ROCKT
			or gt == GridEntityType.GRID_ROCK_BOMB
			or gt == GridEntityType.GRID_ROCK_ALT
			or gt == GridEntityType.GRID_ROCK_SS
			or gt == GridEntityType.GRID_ROCK_SPIKED
			or gt == GridEntityType.GRID_ROCK_ALT2
			or gt == GridEntityType.GRID_ROCK_GOLD
		then
			return true
		end
	end
	for _, npc in ipairs(Isaac.FindInRadius(eye.Position, 14, EntityPartition.ENEMY)) do
		if npc and npc:Exists() and npc:IsVulnerableEnemy() then
			return true
		end
	end
	return false
end

local function owner_still_valid(meta)
	if meta.owner_alive_fn then
		local ok, ent = pcall(meta.owner_alive_fn, meta)
		if ok and ent then return ent end
		return nil
	end
	local owner = meta.owner
	if owner and auxi.check_all_exists(owner) then
		return owner
	end
	return nil
end

local function drive_evil_eye(eye, meta, frame)
	if not eye or not meta then return end
	local owner = owner_still_valid(meta)
	claim_evil_eye(eye, owner)
	if meta.move then
		eye.Velocity = meta.move
	end
	local aim = resolve_aim(meta, eye)
	local shooting = frame < (tonumber(meta.shoot_anim_until) or 0)
	play_evil_eye_anim(eye, aim, shooting)
end

--- ctx: owner, player, aim_dir, luck?, fire_fn, aim_fn?, owner_alive_fn?,
---      pos?, move_speed?, life?, first_shot_delay?, shot_interval?,
---      craft_uid?, skip_chance?, chance_fn?
function item.try_spawn(ctx)
	if type(ctx) ~= "table" then return nil end
	local player = ctx.player
	local owner = ctx.owner
	local aim_dir = ctx.aim_dir
	local fire_fn = ctx.fire_fn
	if not player or not owner or not fire_fn then return nil end
	if not aim_dir or aim_dir:Length() < 0.01 then return nil end
	if not ctx.skip_chance then
		local luck = tonumber(ctx.luck) or (player.Luck) or 0
		local chance = ctx.chance_fn and ctx.chance_fn(luck) or item.evil_chance(luck)
		local rng = player:GetCollectibleRNG(EVIL_COLLECTIBLE)
		if rng:RandomFloat() >= chance then return nil end
	end
	local move = aim_dir:Normalized() * (tonumber(ctx.move_speed) or tonumber(cfg("evil_move_speed")) or 3)
	local pos = ctx.pos or owner.Position
	local spawned = Isaac.Spawn(EntityType.ENTITY_EFFECT, EVIL_EYE_VARIANT, 0, pos, move, owner)
	if not spawned then return nil end
	local eye = spawned:ToEffect() or spawned
	claim_evil_eye(eye, owner)
	play_evil_eye_anim(eye, aim_dir, false)
	local life = math.max(1, math.floor(tonumber(ctx.life) or tonumber(cfg("evil_life")) or 180))
	local frame = Game():GetFrameCount()
	local owner_ptr = nil
	pcall(function() owner_ptr = GetPtrHash(owner) end)
	EYES[eye.InitSeed] = {
		eye = eye,
		meta = {
			owner = owner,
			owner_seed = owner.InitSeed,
			owner_ptr = owner_ptr,
			craft_uid = ctx.craft_uid,
			player = player,
			ctx = ctx,
			fire_fn = fire_fn,
			aim_fn = ctx.aim_fn,
			owner_alive_fn = ctx.owner_alive_fn,
			born = frame,
			life = life,
			next_shot = frame + (tonumber(ctx.first_shot_delay) or tonumber(cfg("evil_first_shot_delay")) or 20),
			shot_interval = math.max(1, math.floor(tonumber(ctx.shot_interval) or tonumber(cfg("evil_shot_interval")) or 12)),
			move = move,
			shoot_anim_until = 0,
		},
	}
	return eye
end

function item.clear_for_owner(owner_seed, craft_uid)
	for seed, row in pairs(EYES) do
		local meta = row.meta
		if meta and meta.owner_seed == owner_seed then
			if not craft_uid or meta.craft_uid == craft_uid then
				if row.eye and row.eye:Exists() then row.eye:Remove() end
				EYES[seed] = nil
			end
		end
	end
end

--- 只清这架母机的邪眼；禁止仅凭 craft uid 误伤联机另一架。
function item.clear_for_air(air)
	if not air then return end
	local ptr
	pcall(function() ptr = GetPtrHash(air) end)
	local seed = air.InitSeed
	for eye_seed, row in pairs(EYES) do
		local meta = row.meta
		if meta then
			local same = (ptr and meta.owner_ptr == ptr)
				or (meta.owner_seed == seed and meta.owner and auxi.check_for_the_same(meta.owner, air))
			if same then
				if row.eye and row.eye:Exists() then row.eye:Remove() end
				EYES[eye_seed] = nil
			end
		end
	end
end

local function flight_owner_blocked(meta, owner)
	if not owner or owner.Type ~= EntityType.ENTITY_FAMILIAR then return false end
	local ok, Air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
	if ok and Air and Air.combat_allowed and not Air.combat_allowed(owner) then
		return true
	end
	local ctx = meta and meta.ctx
	if ctx and ctx.craft_prof then
		local okp, CraftProfile = pcall(require, "Qing_Remaster_scripts.others.craft_combat_profile")
		if okp and CraftProfile and CraftProfile.count_of then
			if CraftProfile.count_of(ctx.craft_prof.counts, EVIL_COLLECTIBLE) <= 0 then
				return true
			end
		end
	end
	return false
end

function item.tick_all()
	local frame = Game():GetFrameCount()
	for seed, row in pairs(EYES) do
		local eye = row.eye
		local meta = row.meta
		if not eye or not eye:Exists() then
			EYES[seed] = nil
		else
			local owner = owner_still_valid(meta)
			if not owner or evil_eye_should_die(eye) or flight_owner_blocked(meta, owner) then
				eye:Remove()
				EYES[seed] = nil
			else
				local age = frame - (tonumber(meta.born) or 0)
				if age >= (tonumber(meta.life) or 180) then
					eye:Remove()
					EYES[seed] = nil
				else
					drive_evil_eye(eye, meta, frame)
					local aim = resolve_aim(meta, eye)
					if frame >= (tonumber(meta.next_shot) or 0) and meta.fire_fn then
						play_evil_eye_anim(eye, aim, true)
						pcall(meta.fire_fn, eye, meta.ctx, aim)
						meta.next_shot = frame + (tonumber(meta.shot_interval) or 12)
						meta.shoot_anim_until = frame + EVIL_SHOOT_ANIM_FRAMES
					end
				end
			end
		end
	end
end

local function player_aim_dir(player, fallback)
	if not player then return fallback or Vector(0, 1) end
	-- Tecro / Tecrorun：players.xml canShoot=false，自定义输入写在 now_dir；原版 Joystick/Aim 常为空。
	local d = player:GetData()
	local now = d and d.now_dir
	if now and now:Length() > 0.05 then return now:Normalized() end
	local input = player:GetShootingInput()
	if input and input:Length() > 0.1 then return input:Normalized() end
	local joy = player:GetShootingJoystick()
	if joy and joy:Length() > 0.1 then return joy:Normalized() end
	local ad = player:GetAimDirection()
	if ad and ad:Length() > 0.1 then return ad:Normalized() end
	if fallback and fallback:Length() > 0.01 then return fallback:Normalized() end
	local mv = player:GetMovementJoystick()
	if mv and mv:Length() > 0.1 then return mv:Normalized() end
	return Vector(0, 1)
end

local function fire_via_attack_provider(eye, ctx, aim)
	local player = ctx.player
	if not player then return end
	local Adv = require("Qing_Remaster_scripts.mimics.Character_Advanced_Familiars_holder")
	-- 不要把邪眼 Effect 当作 source：Tecro 的 fire_spear 会用 source 顶替 TecroNil Parent，
	-- 导致虚影枪挂在 1000.84 上、无法正常伸出。只传出生点。
	local origin = eye.Position
	if (not aim or aim:Length() < 0.05) and player:GetData().now_dir then
		aim = player:GetData().now_dir
	end
	if aim and aim:Length() >= 0.01 then aim = aim:Normalized() else aim = Vector(0, 1) end
	Adv.dispatch_familiar_attack(player, {
		familiar_kind = "evil_eye",
		origin = Vector(origin.X, origin.Y),
		aim_dir = aim,
		damage_mul = 1,
		suppress_player_cost = true,
	})
end

local function fire_via_anna(eye, ctx, aim)
	local player = ctx.player
	if not player then return end
	local ok, Anna = pcall(require, "Qing_Remaster_scripts.player.player_Anna")
	if ok and Anna and Anna.fire_anna_tear then
		pcall(Anna.fire_anna_tear, player, eye.Position, aim, {})
		return
	end
	-- 兜底：普通泪
	local speed = (player.ShotSpeed or 1) * (tonumber(cfg("evil_tear_speed_mul")) or 10)
	local q = Isaac.Spawn(EntityType.ENTITY_TEAR, TearVariant.BLUE or 0, 0, eye.Position, aim * speed, player)
	q = q and q:ToTear()
	if q then
		q.CollisionDamage = player.Damage or 3.5
		q.SpawnerEntity = player
	end
end

local function fire_vanilla_tear(eye, ctx, aim)
	local player = ctx.player
	if not player then return end
	local speed = (player.ShotSpeed or 1) * (tonumber(cfg("evil_tear_speed_mul")) or 10)
	-- CanBeEye=false：禁止再滚眼球
	local q = player:FireTear(eye.Position, aim * speed, false, true, false)
	if q then
		q = q:ToTear() or q
		q.SpawnerEntity = player
	end
end

--- 真持 410 的角色在基础攻击落点调用；按角色选 fire_fn。
function item.notify_player_attack(player, aim_dir)
	if not player or not player:HasCollectible(EVIL_COLLECTIBLE, true) then return end
	aim_dir = aim_dir or player_aim_dir(player)
	if not aim_dir or aim_dir:Length() < 0.01 then return end
	local Adv = require("Qing_Remaster_scripts.mimics.Character_Advanced_Familiars_holder")
	local ptype = player:GetPlayerType()
	local fire_fn
	if Adv.has_attack_provider(player) then
		fire_fn = fire_via_attack_provider
	elseif enums.Players and enums.Players.Anna and ptype == enums.Players.Anna then
		fire_fn = fire_via_anna
	else
		fire_fn = fire_vanilla_tear
	end
	item.try_spawn({
		owner = player,
		player = player,
		aim_dir = aim_dir,
		luck = player.Luck,
		pos = player.Position,
		fire_fn = fire_fn,
		aim_fn = function(_eye, _ctx)
			return player_aim_dir(player, aim_dir)
		end,
		owner_alive_fn = function(meta)
			local p = meta.player
			if p and auxi.check_all_exists(p) then return p end
			return nil
		end,
	})
end

--- Flight craft 泪（供 craft_orbiting_tears 注入）
function item.fire_craft_tear(eye, ctx, aim)
	local air = ctx.owner
	local player = ctx.player
	local craft_prof = ctx.craft_prof
	if not eye or not air or not player or not craft_prof then return end
	local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")
	local CraftTearColors = require("Qing_Remaster_scripts.others.craft_tear_color_data")
	local CraftTearParams = require("Qing_Remaster_scripts.others.craft_tear_params_data")
	local Air = require("Qing_Remaster_scripts.items.Item_Air_Flight")
	local Orbit = require("Qing_Remaster_scripts.others.craft_orbiting_tears")
	local ss = (craft_prof.stats and craft_prof.stats.shotspeed) or 1
	local speed = ss * (tonumber(cfg("evil_tear_speed_mul")) or 10)
	if not aim or aim:Length() < 0.01 then aim = Vector(0, 1) end
	aim = aim:Normalized()
	local ent = Isaac.Spawn(EntityType.ENTITY_TEAR, TearVariant.BLUE or 0, 0, eye.Position, aim * speed, air)
	local q = ent and ent:ToTear()
	if not q then return end
	q.Parent = nil
	q.SpawnerEntity = air
	if q.SetParentOffset then
		pcall(function() q:SetParentOffset(Vector.Zero) end)
	elseif q.ParentOffset ~= nil then
		q.ParentOffset = Vector.Zero
	end
	local Blueprint = require("Qing_Remaster_scripts.items.Item_Blue_Print")
	local craft_uid = air:GetData()[Blueprint.own_key.."craft_uid"]
	local flags = CraftProfile.sample_tear_flags(
		player,
		craft_prof.stats and craft_prof.stats.luck or 0,
		craft_prof,
		WeaponType.WEAPON_TEARS,
		{
			shot_serial = tonumber(air:GetData()[Air.own_key.."shot_serial"]) or 0,
			craft_uid = craft_uid,
			projectile_index = 410,
		}
	) or BitSet128(0, 0)
	CraftProfile.apply_tear_stats(q, craft_prof, 1, flags, {})
	CraftTearColors.apply(q, craft_prof.counts, flags, CraftProfile.TEAR_EFFECTS)
	local po_y = -34
	if air.PositionOffset then po_y = air.PositionOffset.Y end
	CraftTearParams.apply(q, craft_prof.counts, flags, CraftProfile.TEAR_EFFECTS, {
		range = craft_prof.stats and craft_prof.stats.range,
		shotspeed = craft_prof.stats and craft_prof.stats.shotspeed,
		set_base_height = function(accel)
			return auxi.offset2height(Vector(0, po_y), accel)
		end,
	})
	if q.PositionOffset ~= nil then q.PositionOffset = Vector(0, 0) end
	local td = q:GetData()
	td[Air.own_key.."craft_air"] = air
	td[Air.own_key.."craft_uid"] = craft_uid
	if CraftProfile.profile_has_haemolacria and CraftProfile.profile_has_haemolacria(craft_prof) then
		CraftProfile.mark_craft_haemo_tear(q, craft_prof, player, {
			damage = q.CollisionDamage,
			dir = aim,
		})
	end
	if Orbit and Orbit.adopt_path_tear then
		Orbit.adopt_path_tear(q, air, flags, { aim = aim })
	end
end

--- Flight volley：材料 counts[410] > 0
function item.try_craft_volley(air, player, craft_prof, aim_dir)
	if not air or not player or not craft_prof then return end
	local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")
	if CraftProfile.count_of(craft_prof.counts, EVIL_COLLECTIBLE) <= 0 then return end
	if not aim_dir or aim_dir:Length() < 0.01 then return end
	local Blueprint = require("Qing_Remaster_scripts.items.Item_Blue_Print")
	local Air = require("Qing_Remaster_scripts.items.Item_Air_Flight")
	local craft_uid = air:GetData()[Blueprint.own_key.."craft_uid"]
	item.try_spawn({
		owner = air,
		player = player,
		craft_prof = craft_prof,
		craft_uid = craft_uid,
		aim_dir = aim_dir,
		luck = craft_prof.stats and craft_prof.stats.luck or 0,
		pos = air.Position,
		fire_fn = item.fire_craft_tear,
		aim_fn = function(_eye, ctx)
			local a = ctx.owner
			if not a then return aim_dir end
			local last = a:GetData()[Air.own_key.."last_aim"]
			if last and last:Length() > 0.01 then return last:Normalized() end
			return aim_dir
		end,
		owner_alive_fn = function(meta)
			local a = meta.owner
			if a and auxi.check_all_exists(a) and a.InitSeed == meta.owner_seed then
				if Air.combat_allowed and not Air.combat_allowed(a) then return nil end
				if not meta.craft_uid then return a end
				local uid = a:GetData()[Blueprint.own_key.."craft_uid"]
				if uid == meta.craft_uid then return a end
			end
			return nil
		end,
	})
end

if ModCallbacks.MC_PRE_EFFECT_UPDATE then
	table.insert(item.ToCall, {
		CallBack = ModCallbacks.MC_PRE_EFFECT_UPDATE,
		params = EVIL_EYE_VARIANT,
		Function = function(_, effect)
			if not effect or not effect:GetData()[item.own_key.."evil"] then return end
			local row = EYES[effect.InitSeed]
			if not row or not row.meta then return true end
			if not owner_still_valid(row.meta) then return true end
			if flight_owner_blocked(row.meta, row.meta.owner) then return true end
			drive_evil_eye(effect, row.meta, Game():GetFrameCount())
			return true
		end,
	})
end

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		item.tick_all()
	end,
})

return item
