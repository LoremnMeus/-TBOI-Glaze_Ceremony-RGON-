-- Attack Aim Context: member / weapon / proxy geometry for derived Fire*.
-- PreferredAimEntity answers "who controls"; this answers "where / which way to fire".
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local classifier = require("Qing_Remaster_scripts.callbacks.attack_source_classifier")

local M = {
	own_key = "attack_aim_resolver_",
}

local function same_ent(a, b)
	if not a or not b then
		return false
	end
	return GetPtrHash(a) == GetPtrHash(b)
end

--- Rotation-owned facing on knife / swing / effect-style weapon members.
local function weapon_rotation_direction(ent)
	if not ent then
		return nil
	end
	if ent.Type == EntityType.ENTITY_KNIFE and type(ent.Rotation) == "number" then
		return auxi.get_by_rotate(Vector(1, 0), ent.Rotation)
	end
	local spr = ent.GetSprite and ent:GetSprite() or nil
	if spr and type(spr.Rotation) == "number" then
		-- Effect mimics often store facing as Sprite.Rotation = angle - 90.
		return auxi.MakeVector(spr.Rotation + 90)
	end
	if type(ent.Rotation) == "number" then
		return auxi.get_by_rotate(Vector(1, 0), ent.Rotation)
	end
	return nil
end

local function laser_direction(ent)
	if not ent or ent.Type ~= EntityType.ENTITY_LASER then
		return nil
	end
	local ang = ent.AngleDegrees
	if ang == nil then
		ang = ent.Angle
	end
	if type(ang) ~= "number" then
		return nil
	end
	return auxi.MakeVector(ang)
end

local function velocity_or_random(ent, owner)
	if ent and ent.Velocity and ent.Velocity:Length() > 0.01 then
		return ent.Velocity:Normalized()
	end
	local seed = (ent and ent.InitSeed) or (owner and owner.InitSeed) or Random()
	local rng = RNG()
	rng:SetSeed((seed % 2147483646) + 1, 35)
	return auxi.MakeVector(rng:RandomInt(360))
end

local function make_ctx(ent, position, direction, reason)
	return {
		entity = ent,
		position = position or (ent and ent.Position) or Vector.Zero,
		direction = (direction and direction:Length() > 0.01 and direction:Normalized()) or Vector(1, 0),
		reason = reason or "fallback",
	}
end

local function stored_direction(event, attack)
	if event and event.direction and event.direction:Length() > 0.01 then
		return event.direction
	end
	if attack and attack.direction and attack.direction:Length() > 0.01 then
		return attack.direction
	end
	return nil
end

--- Resolve origin + direction for Attack Trigger derived fire.
--- Explicit family geometry (ludo / epic / sword) before entity-type fallbacks,
--- then player Preferred Aim Entity input.
function M.GetAttackAimContext(source, attack, event)
	source = source or (event and event.attack_source) or (attack and attack.source)
	local member = event and event.member
	local family = (event and event.family) or (attack and attack.family)
	local owner = classifier.GetAttackOwnerPlayer(attack) or (event and event.player)

	-- Explicit family geometry (adapter-owned), not entity-type guessing.
	if family == "ludo" and member then
		-- Prefer bind-time direction; else tear / floating-laser Velocity; else deterministic 360° random.
		local dir = stored_direction(event, attack) or velocity_or_random(member, owner)
		local pos = (event and event.position) or member.Position
		return make_ctx(member, pos, dir, "ludo")
	end
	if family == "epic" and member then
		return make_ctx(member, member.Position, velocity_or_random(member, owner), "epic")
	end
	if (family == "sword" or family == "bone_club") and member then
		local role = nil
		if attack and attack.bound_members then
			local rec = attack.bound_members[GetPtrHash(member)]
			role = rec and rec.role
		end
		local is_throw = family == "bone_club" and (role == "projectile"
			or (member.IsFlying and member:IsFlying()))
		local pos = (event and event.position) or member.Position
		-- Priority: bind-time attack.direction → live player aim → Velocity (throw) / Rotation.
		-- Never RNG-fallback for bone_club (Once-frame Velocity is often 0 / residual).
		local dir = stored_direction(event, attack)
		if (not dir or dir:Length() < 0.01) and owner then
			dir = classifier.GetPlayerAimDirection(owner)
		end
		if (not dir or dir:Length() < 0.01) and is_throw
			and member.Velocity and member.Velocity:Length() > 0.01 then
			dir = member.Velocity:Normalized()
		end
		if not dir or dir:Length() < 0.01 then
			dir = weapon_rotation_direction(member)
		end
		local reason = is_throw and "bone_club_throw"
			or ((family == "bone_club") and "bone_club" or "sword")
		return make_ctx(member, pos, dir or Vector(1, 0), reason)
	end

	-- Mom's Knife / other knife members: entity Rotation.
	if member and member.Type == EntityType.ENTITY_KNIFE then
		local dir = weapon_rotation_direction(member)
		if dir then
			return make_ctx(member, member.Position, dir, "knife")
		end
	end

	-- Laser member (Brimstone / Tech / Tech X rings): Angle owns facing.
	if member and member.Type == EntityType.ENTITY_LASER then
		local dir = laser_direction(member)
		if dir then
			return make_ctx(member, member.Position, dir, "laser")
		end
	end

	-- Preferred Aim Entity: live player input, then mimic / weapon body.
	local aim_ent = classifier.GetPreferredAimEntity(source, attack, event)
	local aim_player = aim_ent and aim_ent.ToPlayer and aim_ent:ToPlayer() or nil

	if aim_player then
		if aim_player.GetShootingInput then
			local input = aim_player:GetShootingInput()
			if input and input:Length() > 0.01 then
				return make_ctx(aim_player, aim_player.Position, input, "player")
			end
		end
		if aim_player.GetAimDirection then
			local aim = aim_player:GetAimDirection()
			if aim and aim:Length() > 0.01 then
				return make_ctx(aim_player, aim_player.Position, aim, "player")
			end
		end
	end

	if aim_ent and not aim_player and not same_ent(aim_ent, member) then
		local dir = weapon_rotation_direction(aim_ent) or laser_direction(aim_ent)
		if dir then
			return make_ctx(aim_ent, aim_ent.Position, dir, "aim_entity")
		end
		if aim_ent.Velocity and aim_ent.Velocity:Length() > 0.01 then
			return make_ctx(aim_ent, aim_ent.Position, aim_ent.Velocity, "aim_entity")
		end
	end

	-- Ordinary tear / bomb member velocity after weapon-native paths failed.
	if member and member.Velocity and member.Velocity:Length() > 0.01 then
		return make_ctx(member, member.Position, member.Velocity, "member")
	end

	local soft_player = aim_player or owner
	if soft_player then
		local soft = classifier.GetPlayerAimDirection(soft_player)
		if soft and soft:Length() > 0.01 then
			return make_ctx(soft_player, soft_player.Position, soft, "player")
		end
	end

	local fallback = stored_direction(event, attack)
	if fallback then
		local ent = member or aim_ent or soft_player
		return make_ctx(ent, (ent and ent.Position) or (owner and owner.Position), fallback, "event")
	end

	local ent = member or aim_ent or soft_player or owner
	return make_ctx(ent, (ent and ent.Position) or Vector.Zero, Vector(1, 0), "fallback")
end

return M
