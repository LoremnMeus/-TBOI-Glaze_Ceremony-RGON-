local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Epic_holder_",
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.ID_EFFECT_MeusFetus,
Function = function(_,ent)	--史诗
	local d = ent:GetData()
	local s = ent:GetSprite()
	d[item.own_key.."Params"] = d[item.own_key.."Params"] or {}
	local targ = d[item.own_key.."targ"] or d[item.own_key.."Params"].targ
	if auxi.check_all_exists(targ) then
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
		local q = Isaac.Spawn(EntityType.ENTITY_EFFECT,enums.Entities.ID_EFFECT_MeusRocket,0,ent.Position,Vector(0,0),nil)
		if d[item.own_key.."Params"].ReloadRocket then auxi.check_if_any(d[item.own_key.."Params"].ReloadRocket,q) end
		q.SpriteOffset = q.SpriteOffset + (d[item.own_key.."Params"].baseoffset or Vector(0, -300))
		d[item.own_key.."Rocket"] = q
		
		q:GetSprite().Scale = ent:GetSprite().Scale
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
			item.trigger_epic_effect(q.Position,damage,tearflags,color,player,ent,d[item.own_key.."Params"],d[item.own_key.."Params"].params)
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
		for i = 0,cnt do
			local q1 = player:FireBrimstone(auxi.MakeVector(360/cnt * i + rnd))
			q1.Parent = q2
			q1.Position = q2.Position
		end
	end
	if (params.tech or 0) ~= 0 then
		local q2 = auxi.fire_nil(pos,Vector(0,0),{cooldown = 10,})
		local cnt = math.random(4) + 4
		local rnd = math.random(36000)/100
		for i = 0,cnt do
			local q1 = player:FireTechLaser(pos,1,auxi.MakeVector(360/cnt * i + rnd),false,true)
			q1.Parent = q2
		end
	end
	if (params.techX or 0) ~= 0 then
		local cnt = math.random(4) + 4
		local rnd = math.random(36000)/100
		for i = 0, cnt do player:FireTechXLaser(pos,auxi.MakeVector(360/cnt * i + rnd) * 7 * player.ShotSpeed,damage * 0.3 + 30) end
	end
	-- §14.7.7 Epic + Dr：落地留博士炸弹
	if (params.dr or 0) ~= 0 and player then
		local q = player:FireBomb(pos, Vector(0, 0), player)
		q.ExplosionDamage = damage * 5
		if params.craft_profile then
			local Bomb_holder = require("Qing_Remaster_scripts.mimics.Bomb_holder")
			Bomb_holder.attach_craft_aux(q, params.craft_profile, player)
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