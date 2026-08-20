local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local tear_trigger_holder = require("Qing_Remaster_scripts.callbacks.tear_trigger_holder")

local item = {
	myToCall = {},
	ToCall = {},
	entity = enums.Items.Assassin_s_Eye,
	own_key = "Item_Assassin_s_Eye_",
}

function item.fire_Assassin_tear(player,pos,vel,params)
	params = params or {}
	player = player or Game():GetPlayer(0)
	pos = pos or player.Position
	vel = vel or Vector(0,0)
	local q = params.ent or Isaac.Spawn(2,1,0,pos,vel,player):ToTear()
	local d = q:GetData()
	d[item.own_key.."effect"] = true
	d[item.own_key.."counter"] = params.counter or 5
	return q
end

function item.Assassin_link(player,ent,col,dmg,params)
	params = params or {}
	player = player or Game():GetPlayer(0)
	local q1 = Isaac.Spawn(1000,enums.Entities.MeusLink,0,ent.Position/2 + col.Position/2,Vector(0,0),player)
	local s1 = q1:GetSprite()
	local dir = params.dir or (col.Position - ent.Position)
	local ang = dir:GetAngleDegrees() + math.random(20000)/1000 - 10
	local leg = dir:Length() + col.Size * 1.3 + 5
	s1.Rotation = ang - 90
	s1.Scale = auxi.mul_t(Vector(leg/120,1/10),params.Scaler or Vector(1,1))
	q1.PositionOffset = Vector(0,ent.PositionOffset.Y)
	col:TakeDamage(dmg,0,EntityRef(player),0)
	if params.Ignore_ent then
	else
		ent.Position = ent.Position + auxi.MakeVector(ang) * (leg)
		ent.Velocity = auxi.MakeVector(ang) * (params.endleg or ent.Velocity:Length())
		ent:SetColor(Color(1,1,1,1,-2,-2,-2),15,99,true,false)
	end
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_TOOTH_AND_NAIL,math.random(1000)/10000 + 0.95,math.random(1000)/10000 + 0.95,false,0,2)
	return q1
end
--[[
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_FIRE_TEAR, params = nil,
Function = function(_,ent)
	local player = auxi.check_spawner_player(ent)
	if player and auxi.has_have_coll(player,item.entity) then
		local d = ent:GetData()
		d[item.own_key.."effect"] = true
	end
end,
})
--]]
--table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_FIRE_TRIGGER_IN_FRAME, params = nil,
table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_FIRE_TRIGGER, params = nil,
Function = function(_,tp,ent,pos,player,dir,rate)
	local succ = tear_trigger_holder.check_rate(tp,player:GetData(),rate)
	if succ and player and (auxi.has_have_coll(player,item.entity)) and tear_trigger_holder.framecheck(tp,ent,player,{Update = true,
		["Dr."] = {frame = 1,banished = true,},["Dr. Explode"] = {frame = 1,},
		["Brim"] = {frame = 5,},["BrimFire"] = {frame = 1,banished = true,},
		}) then
		if tp == "Tear" then 
			local d = ent:GetData()
			d[item.own_key.."effect"] = true
		else--if auxi.check_rand(player.Luck,10,5,10) then
			local mulinfo = tear_trigger_holder.multi_check(tp,ent,player)
			local rounded = mulinfo.rounded
			if dir == nil or dir:Length() < 0.01 then rounded = true end
			local ddir = tear_trigger_holder.dir_info_check(tp,ent,dir)
			for i = 1,mulinfo.cnt do
				local tdir = tear_trigger_holder.dir_info_check(tp,ent,dir)
				if rounded then tdir = auxi.get_by_rotate(ddir,i * 360/mulinfo.cnt) end
				if auxi.check_rand(player.Luck,10,5,5) then
					local q = item.fire_Assassin_tear(player,pos or ent.Position,tdir * player.ShotSpeed * 10) q.Mass = 0 q.EntityCollisionClass = 0 q.GridCollisionClass = 0 q:SetColor(Color(1,1,1,1,-2,-2,-2),15,99,true,false)
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_,ent)
	local player = auxi.check_spawner_player(ent)
	local d = ent:GetData()
	if player and (d[item.own_key.."effect"] and d.Ignore_me_flag == nil) or d.is_assassin ~= nil then
		d[item.own_key.."counter"] = (d[item.own_key.."counter"] or 5) - 1
		if d[item.own_key.."counter"] <= 0 then
			local range = math.min(180,player.TearRange * 0.3)
			local n_enemy = auxi.getenemies(Isaac.FindInRadius(ent.Position,range,1<<3))
			if #n_enemy > 0 then
				local targ = auxi.getdisenemies(n_enemy,ent.Position,100) or auxi.random_in_table(n_enemy)
				if auxi.check_all_exists(targ) then
					local q = item.Assassin_link(player,ent,targ,ent.CollisionDamage * 0.75,{Scaler = Vector(1,ent.Scale),endleg = 1,})
					if d.is_assassin then d[item.own_key.."counter"] = 5
					else d[item.own_key.."counter"] = math.max(8,player.MaxFireDelay * 1.3) end
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = FamiliarVariant.ABYSS_LOCUST,
Function = function(_,ent)
	if ent.Type == 3 and ent.Variant == FamiliarVariant.ABYSS_LOCUST and ent.SubType == item.entity then
		local d = ent:GetData()
		if (d[item.own_key.."counter"] or 0) > 0 then d[item.own_key.."counter"] = d[item.own_key.."counter"] - 1
		elseif ent.State == -1 then
			local n_enemy = auxi.getenemies(Isaac.FindInRadius(ent.Position,100,1<<3))
			if #n_enemy > 0 then
				local player = auxi.check_spawner_player(ent)
				local targ = auxi.getdisenemies(n_enemy,ent.Position,100) or auxi.random_in_table(n_enemy)
				if auxi.check_all_exists(targ) then
					item.Assassin_link(player,ent,targ,3.5)
					d[item.own_key.."counter"] = 3
					d[item.own_key.."counter2"] = (d[item.own_key.."counter2"] or 0) + 1
					if d[item.own_key.."counter2"] > 3 then d[item.own_key.."counter2"] = 0 d[item.own_key.."counter"] = 30 end
				end
			end
		end
	end
end,
})

return item
