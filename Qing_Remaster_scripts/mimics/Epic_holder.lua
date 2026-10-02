local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local attack_holder = require("Qing_Remaster_scripts.callbacks.attack_trigger_holder")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Epic_holder_",
}

--- M4: one Epic Attack for MeusFetus carrier (+ rockets / impact / children).
--- Same-frame multi-launch joins via create_or_join (max_frame_delta).
function item.begin_carrier_attack(carrier, player, opts)
	opts = opts or {}
	if not carrier or not player then return nil end
	local d = carrier:GetData()
	local existing = d[item.own_key .. "attack"]
		or select(1, attack_holder.GetAttackForMember(carrier))
	if existing and existing.active and not existing.ending then
		d[item.own_key .. "attack"] = existing
		return existing
	end
	local source = attack_holder.classifier.make_player_source(player)
	local attack = attack_holder.grouping.create_or_join(player, "epic", {
		max_frame_delta = opts.max_frame_delta or 2,
		position = carrier.Position,
		source_id = source and source.source_id,
		source = source,
	})
	attack_holder.BindMember(attack, carrier, {
		role = "proxy",
		reason = opts.reason or "epic_meus_carrier",
		position = carrier.Position,
	})
	attack_holder.MarkProxy(carrier)
	d[item.own_key .. "attack"] = attack
	return attack
end

local function resolve_epic_attack(carrier, rocket, params)
	params = params or {}
	if params.attack and params.attack.active and not params.attack.ending then
		return params.attack
	end
	if carrier then
		local d = carrier:GetData()
		local cached = d[item.own_key .. "attack"]
		if cached and cached.active and not cached.ending then
			return cached
		end
		local a = select(1, attack_holder.GetAttackForMember(carrier))
		if a then return a end
	end
	if rocket then
		return select(1, attack_holder.GetAttackForMember(rocket))
	end
	return nil
end

--- Seal + remember blast attribution at impact (MeusRocket has no Timeout==1).
local function finalize_epic_impact(rocket, carrier, attack)
	attack = attack or resolve_epic_attack(carrier, rocket)
	if not attack then return nil end
	if attack.open_for_members then
		attack_holder.grouping.seal_attack_and_clear(attack)
	end
	local member = rocket or carrier
	if member then
		local _, binding = attack_holder.GetAttackForMember(member)
		local gen = binding and binding.generation
		attack_holder.remember_for_damage(member, attack, gen)
		local player = attack.player
		if player then
			attack_holder.remember_player_blast(player, attack, gen, member.Position)
		end
	end
	return attack
end

local function epic_child_opts(params, carrier, reason, damage_multiplier)
	params = params or {}
	if params.attack_ctx then
		return {
			mode = params.attack_ctx.mode or "inherit",
			attack = params.attack_ctx.attack,
			attack_id = params.attack_ctx.attack_id,
			emitter = params.attack_ctx.emitter or carrier,
			role = params.attack_ctx.role or "derived",
			reason = params.attack_ctx.reason or reason,
			damage_multiplier = params.attack_ctx.damage_multiplier or damage_multiplier,
			Source = params.attack_ctx.Source,
		}
	end
	local attack = params.attack
	if not attack and carrier then
		attack = select(1, attack_holder.GetAttackForMember(carrier))
	end
	if attack then
		return {
			mode = "inherit",
			attack = attack,
			emitter = carrier,
			role = "derived",
			reason = reason,
			damage_multiplier = damage_multiplier,
		}
	end
	if params.expected_attack then
		attack_holder.warn_missing_parent_once(
			reason or "epic_child",
			"[AttackHolder] Epic child emitted without parent Attack; fallback to untracked."
		)
	end
	return {
		mode = "untracked",
		reason = reason,
		damage_multiplier = damage_multiplier,
	}
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.ID_EFFECT_MeusFetus,
Function = function(_,ent)	--史诗
	local d = ent:GetData()
	local s = ent:GetSprite()
	d[item.own_key.."Params"] = d[item.own_key.."Params"] or {}
	-- Aeon / fixed-target: skip carrier XY follow; keep cooldown / rocket / impact.
	local manual_xy = d[item.own_key.."ManualCarrierPosition"] == true
		or d[item.own_key.."LockCarrierXY"] == true
		or d[item.own_key.."Params"].ManualCarrierPosition == true
		or d[item.own_key.."Params"].LockCarrierXY == true
		or d[item.own_key.."Params"].FixedTargetPosition == true
	local targ = d[item.own_key.."targ"] or d[item.own_key.."Params"].targ
	if not manual_xy and auxi.check_all_exists(targ) then
		if d[item.own_key.."Params"].Homing then
			local shouldHome = true
			if (d[item.own_key.."Params"].HomingWait or 0) > 0 then d[item.own_key.."Params"].HomingWait = d[item.own_key.."Params"].HomingWait - 1 shouldHome = false end
			if d[item.own_key.."Params"].HomingDistance and targ.Position:DistanceSquared(ent.Position) < d[item.own_key.."Params"].HomingDistance then shouldHome = false end
			if shouldHome then
				local dir = (targ.Position - ent.Position):Normalized()
				ent:AddVelocity(dir * (d[item.own_key.."Params"].HomingSpeed or 0.6))
			end
			if type(d[item.own_key.."Params"].Homing) == "number" then d[item.own_key.."Params"].Homing = d[item.own_key.."Params"].Homing - 1 if d[item.own_key.."Params"].Homing < 0 then d[item.own_key.."Params"].Homing = nil end end
		else
			if d[item.own_key.."Params"].NoFollow then ent.Velocity = ent.Velocity * 0.5 
			else
				d[item.own_key.."Follow"] = d[item.own_key.."Follow"] or (ent.Position - targ.Position)
				ent.Position = targ.Position + d[item.own_key.."Follow"]
				ent.Velocity = targ.Velocity
			end
		end
	end
	if (d[item.own_key.."Cooldown"] or 0) > 0 then d[item.own_key.."Cooldown"] = d[item.own_key.."Cooldown"] - 1
	elseif auxi.check_all_exists(d[item.own_key.."Rocket"]) ~= true then
		local player = d[item.own_key.."Params"].player or Game():GetPlayer(0)
		local attack = nil
		if not manual_xy then
			attack = item.begin_carrier_attack(ent, player, {
				reason = "epic_meus_carrier_lazy",
			})
		end
		local q
		if attack then
			q = attack_holder.WithFireContext({
				mode = "inherit",
				attack = attack,
				emitter = ent,
				role = "proxy",
				reason = "epic_meus_rocket",
			}, function()
				return Isaac.Spawn(
					EntityType.ENTITY_EFFECT,
					enums.Entities.ID_EFFECT_MeusRocket,
					0,
					ent.Position,
					Vector(0, 0),
					player
				)
			end)
		else
			q = Isaac.Spawn(
				EntityType.ENTITY_EFFECT,
				enums.Entities.ID_EFFECT_MeusRocket,
				0,
				ent.Position,
				Vector(0, 0),
				player
			)
		end
		if q then
			q.Parent = ent
			if manual_xy then
				attack_holder.MarkIgnore(q)
			end
			if d[item.own_key.."Params"].ReloadRocket then auxi.check_if_any(d[item.own_key.."Params"].ReloadRocket,q) end
			q.SpriteOffset = q.SpriteOffset + (d[item.own_key.."Params"].baseoffset or Vector(0, -300))
			d[item.own_key.."Rocket"] = q
			q:GetSprite().Scale = ent:GetSprite().Scale
			if attack and not select(1, attack_holder.GetAttackForMember(q)) then
				attack_holder.BindMember(attack, q, {
					allow_sealed = true,
					role = "proxy",
					reason = "epic_meus_rocket_late",
					position = q.Position,
				})
			end
		end
	end

	if auxi.check_all_exists(d[item.own_key.."Rocket"]) then
		local q = d[item.own_key.."Rocket"]
		q.Position = ent.Position
		q.SpriteOffset = q.SpriteOffset + Vector(0,d[item.own_key.."Params"].fallspeed or 30)
		if q.SpriteOffset.Y >= 0 then
			local tearflags = d[item.own_key.."Tearflags"] or BitSet128(0,0)
			local color = d[item.own_key.."Color"] or Color(1,1,1,1)
			local player = d[item.own_key.."Params"].player or Game():GetPlayer(0)
			local damage = d[item.own_key.."Damage"] or 1
			local params = d[item.own_key.."Params"]
			local attack = finalize_epic_impact(q, ent, resolve_epic_attack(ent, q, params))
			if attack then
				params.attack = attack
				params.expected_attack = true
			end
			item.trigger_epic_effect(q.Position,damage,tearflags,color,player,ent,params,params.params)
			auxi.check_if_any(d[item.own_key.."Params"].Trigger,q)
			q:Remove()
			d[item.own_key.."Rocket"] = nil
			d[item.own_key.."Counter"] = (d[item.own_key.."Counter"] or 0) + 1
			
			if d[item.own_key.."Counter"] < (d[item.own_key.."Params"].NumRockets or 1) then d[item.own_key.."Cooldown"] = d[item.own_key.."Cooldown"] + (d[item.own_key.."Params"].TimeBetweenRockets or 1)
			else ent:Remove() end
		end
	end
end,
})

function item.trigger_epic_effect(pos,damage,tearflags,color,player,ent,params,params2)
	params = params or {}
	params2 = params2 or {}
	if params2.dmgself == nil then params2.dmgself = true end
	color = color or Color(1,1,1,1)
	local attack = resolve_epic_attack(ent, nil, params)
	if attack then
		params.attack = attack
		params.expected_attack = true
	end
	Game():BombExplosionEffects(pos,damage * 20,tearflags,color,player,ent:GetSprite().Scale:Length()/math.sqrt(2),false,params2.dmgself)
	-- §15.4 Epic 落地血泪（与其它 epic_burst 共用落点）
	if params.craft_profile then
		local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")
		if CraftProfile.profile_has_haemolacria(params.craft_profile) then
			local mods = params.craft_atk_mods or {}
			CraftProfile.spawn_craft_haemolacria_burst(
				params.craft_profile,
				pos,
				Vector(0, 1),
				player,
				{
					player = player,
					damage_mul = 0.45 * (mods.damage_mul or 1),
					size_mul = mods.size_mul or 1,
					tear_flags = tearflags,
				}
			)
		end
	end
	if (params.knife or 0) ~= 0 then
		local params = {
			cooldown = 30,
			Accerate = 1.3,
			player = player,
		}
		local cnt = math.random(4) + 4
		local rnd = math.random(36000)/100
		for i = 0,cnt do auxi.fire_knife(pos,auxi.MakeVector(360/cnt * i + rnd) * 10,damage * 0.65,nil,params) end
	end
	if (params.brimstone or 0) ~= 0 then
		local q2 = auxi.fire_nil(pos,Vector(0,0),{cooldown = 60,})
		local cnt = math.random(4) + 4
		local rnd = math.random(36000)/100
		local fire_opts = epic_child_opts(params, ent, "epic_brim_burst", 1)
		for i = 0,cnt do
			local q1 = attack_holder.FireBrimstone(player, auxi.MakeVector(360/cnt * i + rnd), fire_opts)
			if q1 then
				q1.Parent = q2
				q1.Position = q2.Position
			end
		end
	end
	if (params.tech or 0) ~= 0 then
		local q2 = auxi.fire_nil(pos,Vector(0,0),{cooldown = 10,})
		local cnt = math.random(4) + 4
		local rnd = math.random(36000)/100
		local fire_opts = epic_child_opts(params, ent, "epic_tech_burst", 1)
		fire_opts.offset_id = 1
		fire_opts.one_hit = true
		for i = 0,cnt do
			local q1 = attack_holder.FireTechLaser(player, pos, auxi.MakeVector(360/cnt * i + rnd), fire_opts)
			if q1 then
				q1.Parent = q2
			end
		end
	end
	if (params.techX or 0) ~= 0 then
		local cnt = math.random(4) + 4
		local rnd = math.random(36000)/100
		local fire_opts = epic_child_opts(params, ent, "epic_techx_burst", 1)
		for i = 0, cnt do
			attack_holder.FireTechXLaser(
				player,
				pos,
				auxi.MakeVector(360/cnt * i + rnd) * 7 * player.ShotSpeed,
				damage * 0.3 + 30,
				fire_opts
			)
		end
	end
	-- F6: FireBomb via holder (inherit Epic Attack when present).
	if (params.dr or 0) ~= 0 and player then
		local fire_opts = epic_child_opts(params, ent, "epic_dr_bomb", 1)
		fire_opts.Source = fire_opts.Source or player
		local q = attack_holder.FireBomb(player, pos, Vector(0, 0), fire_opts)
		if q then
			q.ExplosionDamage = damage * 5
			-- BindMember also happens via inherit Fire Context; keep explicit allow_sealed for sealed Epic.
			if attack then
				attack_holder.BindMember(attack, q, {
					allow_sealed = true,
					role = "derived",
					reason = "epic_dr_bomb",
					position = q.Position,
				})
			end
			if params.craft_profile then
				local Bomb_holder = require("Qing_Remaster_scripts.mimics.Bomb_holder")
				Bomb_holder.attach_craft_aux(q, params.craft_profile, player, {
					attack = attack or params.attack or select(1, attack_holder.GetAttackForMember(ent)),
					attack_ctx = params.attack_ctx,
					expected_attack = true,
				})
			end
		end
	end
	-- §14.7.8 Epic + Spirit Sword：落地 SpinUp 斩击环
	if (params.sword or 0) ~= 0 and player then
		local cnt = 4 + math.random(2)
		local rnd = math.random(36000) / 100
		for i = 0, cnt - 1 do
			local dir = auxi.MakeVector(360 / cnt * i + rnd)
			auxi.fire_dosome_knife(
				pos,
				dir:Normalized() / 1000,
				{TearFlags = tearflags or BitSet128(0, 0), TearColor = color or player.TearColor, TearDamage = damage, TearScale = 1},
				"SpinUp",
				{player = player, dmgmul = 0.45, Flip = auxi.random_bool(), list = {}, dmg = damage},
				nil
			)
		end
	end
end

return item