-- Gello（UMBILICAL_BABY）：保留原版移动/脐带/动画，禁用原版 Weapon，经角色 Provider 分发攻击。
-- 覆盖范围来自 character_attack_compat；无 Provider 的角色完全放行原版。不接蓝图。
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local CharacterFamiliars = require("Qing_Remaster_scripts.mimics.Character_Advanced_Familiars_holder")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Character_Gello_holder_",
}

local GELLO_VARIANT = FamiliarVariant.UMBILICAL_BABY or 240
local FIRE_DELAY_SENTINEL = 999
local SEEK_RANGE_CAP = 800

local function get_owner(fam)
	local player = fam and (fam.Player or auxi.check_spawner_player(fam))
	if not player and Game():GetNumPlayers() == 1 then
		player = Isaac.GetPlayer(0)
	end
	return player
end

local function should_takeover(fam)
	if not fam or fam.Variant ~= GELLO_VARIANT then return false end
	local player = get_owner(fam)
	if not player then return false end
	return CharacterFamiliars.has_attack_provider(player)
end

local function is_valid_enemy(ent)
	return ent
		and auxi.check_all_exists(ent)
		and ent:IsVulnerableEnemy()
		and not ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
end

local function find_closest_enemy(pos, range)
	local best, best_d
	range = tonumber(range) or SEEK_RANGE_CAP
	local r2 = range * range
	for _, npc in ipairs(Isaac.FindInRadius(pos, range, EntityPartition.ENEMY)) do
		if is_valid_enemy(npc) then
			local d2 = npc.Position:DistanceSquared(pos)
			if d2 <= r2 and (not best_d or d2 < best_d) then
				best, best_d = npc, d2
			end
		end
	end
	return best
end

local function resolve_target(fam, player)
	if is_valid_enemy(fam.Target) then
		return fam.Target
	end
	if fam.TryAimAtMarkedTarget then
		-- RGON：boolean, {AimDirection, Direction, TargetPos}；legacy：Vector 或 nil
		local a, b = fam:TryAimAtMarkedTarget(nil, Direction.NO_DIRECTION, nil)
		local target_pos = nil
		if type(a) == "boolean" and a and type(b) == "table" then
			target_pos = b.TargetPos
		elseif a and a.X and a.Y then
			target_pos = a
		end
		if target_pos then
			local near = find_closest_enemy(target_pos, 80)
			if near then return near end
		end
	end
	local range = math.min(tonumber(player.TearRange) or SEEK_RANGE_CAP, SEEK_RANGE_CAP)
	return find_closest_enemy(fam.Position, range)
end

local function snapshot_and_suppress_weapon(fam, d)
	local snap_key = item.own_key.."weapon_snapshot"
	local natural_key = item.own_key.."natural_delay"
	local type_key = item.own_key.."weapon_type_cached"
	if not fam.GetWeapon then return d[snap_key] end
	local weapon = fam:GetWeapon()
	if not weapon then return d[snap_key] end
	local snap = {
		weapon_type = weapon.GetWeaponType and weapon:GetWeaponType() or nil,
		modifiers = weapon.GetModifiers and weapon:GetModifiers() or nil,
		charge = weapon.GetCharge and weapon:GetCharge() or nil,
		max_charge = weapon.GetMaxCharge and weapon:GetMaxCharge() or nil,
		direction = weapon.GetDirection and weapon:GetDirection() or nil,
	}
	local natural = weapon.GetMaxFireDelay and weapon:GetMaxFireDelay() or nil
	natural = tonumber(natural)
	-- 禁止把哨兵 999 当成自然延迟
	if natural and natural > 0 and natural < FIRE_DELAY_SENTINEL - 1 then
		if d[natural_key] == nil or d[type_key] ~= snap.weapon_type then
			d[natural_key] = natural
			d[type_key] = snap.weapon_type
		end
	end
	snap.max_fire_delay = d[natural_key]
	d[snap_key] = snap
	if weapon.SetCharge then weapon:SetCharge(0) end
	if weapon.SetFireDelay then weapon:SetFireDelay(FIRE_DELAY_SENTINEL) end
	return snap
end

local function restore_weapon_fire_delay(fam)
	if not fam or not fam.GetWeapon then return end
	local weapon = fam:GetWeapon()
	if weapon and weapon.SetFireDelay then
		weapon:SetFireDelay(0)
	end
end

local function lullaby_mul(player)
	if player and player:HasTrinket(TrinketType.TRINKET_FORGOTTEN_LULLABY) then
		return 0.5
	end
	return 1
end

local function damage_mul_for(player)
	local mul = 0.75
	if player and player:HasCollectible(CollectibleType.COLLECTIBLE_BFFS) then
		mul = mul * 2
	end
	return mul
end

local function play_shoot_anim(fam, aim_dir)
	if not fam or not fam.PlayShootAnim then return end
	local dir = Direction.DOWN
	if aim_dir and aim_dir:Length() > 0.01 then
		dir = auxi.GetDirectionByAngle(aim_dir:GetAngleDegrees())
	end
	pcall(function() fam:PlayShootAnim(dir) end)
end

local function tick_gello(fam)
	local player = get_owner(fam)
	local d = fam:GetData()
	if not should_takeover(fam) then
		if d[item.own_key.."takeover"] then
			restore_weapon_fire_delay(fam)
			d[item.own_key.."takeover"] = nil
			d[item.own_key.."cooldown"] = nil
			d[item.own_key.."natural_delay"] = nil
		end
		return
	end
	d[item.own_key.."takeover"] = true
	local snap = snapshot_and_suppress_weapon(fam, d)
	local target = resolve_target(fam, player)
	local cd = tonumber(d[item.own_key.."cooldown"]) or 0
	if not target then
		-- 无目标：保持 ready，不累计、不补发
		if cd > 0 then
			d[item.own_key.."cooldown"] = math.max(0, cd - 1)
		end
		return
	end
	if cd > 0 then
		d[item.own_key.."cooldown"] = cd - 1
		return
	end
	local aim = (target.Position - fam.Position)
	if aim:Length() < 0.01 then aim = Vector(0, 1) else aim = aim:Normalized() end
	local frame = Game():GetFrameCount()
	if d[item.own_key.."last_fire_frame"] == frame then return end
	local result = CharacterFamiliars.dispatch_familiar_attack(player, {
		familiar_kind = "gello",
		source = fam,
		origin = fam.Position,
		aim_dir = aim,
		target = target,
		damage_mul = damage_mul_for(player),
		weapon_snapshot = snap,
		suppress_player_cost = true,
	})
	if result and result.fired then
		d[item.own_key.."last_fire_frame"] = frame
		local delay = tonumber(result.delay)
			or tonumber(d[item.own_key.."natural_delay"])
			or tonumber(player.MaxFireDelay)
			or 10
		delay = math.max(1, delay * lullaby_mul(player))
		d[item.own_key.."cooldown"] = delay
		play_shoot_anim(fam, aim)
	end
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_FAMILIAR_UPDATE,
	params = GELLO_VARIANT,
	Function = function(_, fam)
		if not fam then return end
		tick_gello(fam)
	end,
})

-- 漏网普通泪清理（主路径是禁 Weapon；此为安全网）
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_TEAR_UPDATE,
	params = nil,
	Function = function(_, tear)
		if not tear or (tear.FrameCount or 0) > 1 then return end
		local sp = tear.SpawnerEntity and tear.SpawnerEntity:ToFamiliar()
		if not sp or sp.Variant ~= GELLO_VARIANT then return end
		if should_takeover(sp) then
			tear:Remove()
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, GELLO_VARIANT, -1, false, false)) do
			local d = ent:GetData()
			d[item.own_key.."cooldown"] = nil
			d[item.own_key.."last_fire_frame"] = nil
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE,
	params = EntityType.ENTITY_FAMILIAR,
	Function = function(_, ent)
		if not ent or ent.Variant ~= GELLO_VARIANT then return end
		local d = ent:GetData()
		d[item.own_key.."takeover"] = nil
		d[item.own_key.."cooldown"] = nil
	end,
})

return item
