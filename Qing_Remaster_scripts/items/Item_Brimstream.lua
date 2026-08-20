local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	ToCall = {},
	entity = enums.Items.Brimstream,
	familiar = enums.Familiars.Brimstream,
	description = {
		zh_cn = {
			[118] = {desc = "追加一个火箭跟班，爆发的硫磺火无距离限制",},
		},
		en_us = {
			[118] = {desc = "Add one rocket baby.#Cancel the distance limitation of the short brimstone laser.",},
		},
	},
	own_key = "Item_Brimstream_",
}
auxi.add_EID_item_synic(item.entity,item.description,true)

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local cnt = player:GetCollectibleNum(item.entity)
	if cnt > 0 then	cnt = cnt + player:GetCollectibleNum(118) end
	if cacheFlag == CacheFlag.CACHE_FAMILIARS then
		player:CheckFamiliar(item.familiar, cnt, player:GetCollectibleRNG(item.entity), Isaac.GetItemConfig():GetCollectible(item.entity))
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local n_entity = Isaac.GetRoomEntities()
	local n_brim = auxi.getothers(n_entity,3,item.familiar)
	for u,v in pairs(n_brim) do
		v.Velocity = Vector(0,0)
		local d = v:GetData()
		if auxi.check_all_exists(d[item.own_key.."follower"]) then
			d[item.own_key.."angle"] = math.random(2) * 2 - 3
			d[item.own_key.."follower"]:Remove()
		end
		d[item.own_key.."follower"] = nil
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local room = Game():GetRoom()
	local player = auxi.check_spawner_player(ent) or Game():GetPlayer(0)
	if s:IsFinished("Appear") then s:Play("Idle") end
	if s:IsPlaying("Idle") then
		if auxi.check_all_exists(d[item.own_key.."follower"]) ~= true then
			local info = auxi.judge_by_brimstone(player)
			local q = Isaac.Spawn(7,info.tp,0,ent.Position,Vector(0,0),ent)
			delay_buffer.addeffe(function(params) SFXManager():Stop(7) end,{},1)
			q.CollisionDamage = info.dmg * 0.5
			d[item.own_key.."length"] = 5
			q.Parent = ent
			d[item.own_key.."follower"] = q:ToLaser()
		else
			d[item.own_key.."follower"].Angle = ent.Velocity:GetAngleDegrees() + 180
			s.Rotation = ent.Velocity:GetAngleDegrees() + 90
			d[item.own_key.."follower"].MaxDistance = d[item.own_key.."length"]
			d[item.own_key.."length"] = math.min(1000,d[item.own_key.."length"] * 1.2 + 5)
			if auxi.check_all_exists(d[item.own_key.."target"]) ~= true or auxi.isenemies(d[item.own_key.."target"]) ~= true then
				d[item.own_key.."target"] = auxi.get_by_nearest_enemy(ent.Position)
			end
			
			if auxi.check_all_exists(d[item.own_key.."target"]) ~= true then
				local vel = math.min(20,math.max(5,ent.Velocity:Length() * 1.3))
				local dis = player.Position - ent.Position
				local dg_angle = 90 - math.max(math.min(dis:Length() - 80,80),-80)
				d[item.own_key.."angle"] = d[item.own_key.."angle"] or math.random(2) * 2 - 3
				ent.Velocity = ent.Velocity * 0.3 + auxi.MakeVector(dg_angle * d[item.own_key.."angle"] + dis:GetAngleDegrees()) * vel * 0.7
			else
				if (d[item.own_key.."inni"] or 0) > 0 then
					local vel = math.min(20,math.max(5,ent.Velocity:Length() * 1.3))
					local dir = d[item.own_key.."initpos"] - ent.Position
					if dir:Length() > 120 then d[item.own_key.."inni"] = d[item.own_key.."inni"] - 1 end
					ent.Velocity = ent.Velocity * 0.5 - dir:Normalized() * vel * 0.5
				else
					local dir = d[item.own_key.."target"].Position - ent.Position
					ent.Velocity = ent.Velocity * 0.7 + dir:Normalized() * math.min(20,(dir:Length() + 10) * 0.3) * 0.3
					if dir:Length() < 15 and (d[item.own_key.."delay"] or 0) <= 0 then
						s:Play("Crush",true)
						if auxi.check_all_exists(d[item.own_key.."follower"]) then d[item.own_key.."follower"]:Remove() end
						d[item.own_key.."follower"] = nil
						d[item.own_key.."target"] = nil
						ent.Velocity = ent.Velocity:Normalized() * 0.1
						Game():BombExplosionEffects(ent.Position,3 + player.Damage * 0.2,player.TearFlags,Color(1,0,0,1),player,ent:GetSprite().Scale:Length()/math.sqrt(2),false,true)
						local pos = ent.Position
						delay_buffer.addeffe(function(params)
							local n_enemy = auxi.getenemies(nil,function(ent) if (ent.Position - pos):Length() <= 100 then return true end end)
							for u,v in pairs(n_enemy) do
								if auxi.check_all_exists(v) then v:AddEntityFlags(EntityFlag.FLAG_BRIMSTONE_MARKED)	end
							end
						end,{},20)
						local rnd = math.random(6) + 6
						local range = math.random(50) + 50
						local st_ang = math.random(36000)/100
						local dmg = 0.5
						local info = auxi.judge_by_brimstone(player)
						for i = 1,rnd do
							local q = Isaac.Spawn(7,info.tp,0,ent.Position,Vector(0,0),player):ToLaser()
							q.CollisionDamage = info.dmg * 0.5
							if player:HasCollectible(118) == false then q.MaxDistance = range end
							q:SetTimeout(9)
							q.Angle = st_ang + 360/rnd * (i-1)
							
							local d2 = q:GetData()
							d2.should_ignore_modifier = true
						end
						d[item.own_key.."delay"] = 15
						d[item.own_key.."inni"] = 1
						d[item.own_key.."initpos"] = ent.Position
					end
				end
			end
		end
	else 
		ent.Velocity = Vector(0,0)
	end
	if (d[item.own_key.."delay"] or 0) > 0 then d[item.own_key.."delay"] = (d[item.own_key.."delay"] or 0) - 1 end
	if s:IsFinished("Crush_to_Idle") then
		s:Play("Idle",true)
	end
	if s:IsFinished("Crush") then
		s:Play("Crush_to_Idle",true)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_INIT, params = item.familiar,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	s:Play("Appear",true)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_FAMILIAR_COLLISION, params = FamiliarVariant.ABYSS_LOCUST,
Function = function(_,ent,col,low)
	if ent.Type == 3 and ent.Variant == FamiliarVariant.ABYSS_LOCUST and ent.SubType == item.entity then
		local player = auxi.check_spawner_player(ent)
		local d = ent:GetData()
		if auxi.isenemies(col) and ent.State == -1 then 
			col:AddEntityFlags(EntityFlag.FLAG_BRIMSTONE_MARKED)
		end
	end
end,
})

return item