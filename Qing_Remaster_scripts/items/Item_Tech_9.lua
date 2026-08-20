local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local tear_trigger_holder = require("Qing_Remaster_scripts.callbacks.tear_trigger_holder")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Tech_9,
	own_key = "Item_Tech_9_",
}

local function player_has_item(player)
	return player and auxi.has_have_coll(player,item.entity)
end

local function get_shooting_direction(player)
	if player == nil then return Vector(1,0) end
	local dir = Vector(0,0)
	if player.GetShootingInput then
		dir = player:GetShootingInput()
	end
	if dir:Length() < 0.01 and player.GetAimDirection then
		dir = player:GetAimDirection()
	end
	if dir:Length() < 0.01 then
		local fire_dir = player:GetFireDirection()
		if fire_dir == Direction.LEFT then dir = Vector(-1,0)
		elseif fire_dir == Direction.RIGHT then dir = Vector(1,0)
		elseif fire_dir == Direction.UP then dir = Vector(0,-1)
		elseif fire_dir == Direction.DOWN then dir = Vector(0,1)
		end
	end
	if dir:Length() < 0.01 then dir = Vector(1,0) end
	return dir:Normalized()
end

local function normalize_dir(player,vel)
	if vel and vel:Length() > 0.01 then return vel:Normalized() end
	return get_shooting_direction(player)
end

local function as_shot_velocity(player,vec,force_direction)
	local fallback_speed = math.max(6,(player and player.ShotSpeed or 1) * 10)
	if vec == nil or vec:Length() < 0.01 then
		return get_shooting_direction(player) * fallback_speed
	end
	if force_direction == true then
		return vec:Normalized() * fallback_speed
	end
	local length = vec:Length()
	if length < 1 then return vec:Normalized() * fallback_speed end
	if length < fallback_speed then
		local target = vec:Normalized() * fallback_speed
		local alpha = (fallback_speed - length) / math.max(0.01,fallback_speed - 1)
		return vec * (1 - alpha) + target * alpha
	end
	return vec
end

local function mark_laser(laser,tag)
	if laser then
		laser:GetData()[tag or item.own_key.."laser"] = true
	end
	return laser
end

local function fire_bonus(player,pos,vel,rng,damage_scale,force_direction)
	if player == nil then return end
	if pos == nil then pos = player.Position end
	local shot_vel = as_shot_velocity(player,vel,force_direction)
	local dir = normalize_dir(player,shot_vel)
	rng = rng or player:GetCollectibleRNG(item.entity)
	damage_scale = damage_scale or 1
	local count = player:GetCollectibleNum(item.entity)
	if rng:RandomInt(1000) > math.max(600,1000 - count * 60 - player.Luck * 10) then
		local radius = rng:RandomInt(50) + 20
		local q = player:FireTechXLaser(pos,shot_vel * ((auxi.random_1() + 1) / 2),radius,player,(radius / 70) * damage_scale)
		mark_laser(q,item.own_key.."techx_laser")
		return true
	end
	if rng:RandomInt(1000) > math.max(800,1000 - count * 100 - player.Luck * 5) then
		mark_laser(player:FireTechLaser(pos,LaserOffset.LASER_TECH1_OFFSET,dir,false,false,player,0.75 * damage_scale))
		return true
	end
	if rng:RandomInt(1000) > math.max(900,1000 - count * 30 - player.Luck * 3) then
		mark_laser(player:FireTechLaser(pos,LaserOffset.LASER_TECH1_OFFSET,dir,true,false,player,0.75 * damage_scale))
		return true
	end
	if rng:RandomInt(1000) > math.max(500,1000 - count * 50 - player.Luck * 35) then
		mark_laser(player:FireTechLaser(pos,LaserOffset.LASER_TECH1_OFFSET,dir,false,true,player,1.3 * damage_scale))
		return true
	end
	return false
end

local function try_fire_bonus(player,pos,vel,source,damage_scale,rng,force_direction)
	if player_has_item(player) ~= true then return end
	if source then
		local d = source:GetData()
		if d[item.own_key.."triggered"] == true or d.Ignore_me_flag == true or d[item.own_key.."laser"] == true or d[item.own_key.."techx_laser"] == true then return end
		d[item.own_key.."triggered"] = true
	end
	rng = rng or player:GetCollectibleRNG(item.entity)
	fire_bonus(player,pos,vel,rng,damage_scale,force_direction)
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_FIRE_TRIGGER_IN_FRAME, params = nil,
Function = function(_,tp,ent,pos,player,dir)
	if player_has_item(player) ~= true or ent == nil then return end
	local d = ent:GetData()
	if d.Ignore_me_flag == true or d[item.own_key.."laser"] == true or d[item.own_key.."techx_laser"] == true then return end
	local rng = player:GetCollectibleRNG(item.entity)
	if tp == "Tear" then
		try_fire_bonus(player,pos or ent.Position,dir or ent.Velocity,ent,1,rng)
	else
		if d[item.own_key.."triggered_"..tostring(tp)] == true then return end
		d[item.own_key.."triggered_"..tostring(tp)] = true
		local mulinfo = tear_trigger_holder.multi_check(tp,ent,player)
		local rounded = mulinfo.rounded
		if dir == nil or dir:Length() < 0.01 then rounded = true end
		local base_dir = tear_trigger_holder.dir_info_check(tp,ent,dir)
		for i = 1,(mulinfo.cnt or 1) do
			local tdir = tear_trigger_holder.dir_info_check(tp,ent,dir)
			if rounded then tdir = auxi.get_by_rotate(base_dir,i * 360/(mulinfo.cnt or 1)) end
			fire_bonus(player,pos or ent.Position,tdir,rng,0.75,true)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_LASER_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."techx_laser"] == true then
		if ent.FrameCount > 8 and ent.Velocity:Length() < 0.3 then
			ent:Remove()
		end
		return
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = FamiliarVariant.ABYSS_LOCUST,
Function = function(_,ent)
	if ent.Type == 3 and ent.Variant == FamiliarVariant.ABYSS_LOCUST and ent.SubType == item.entity then
		local d = ent:GetData()
		if ent.State == -1 then 
			if d[item.own_key.."counter"] == nil then 
				local player = auxi.check_spawner_player(ent)
				d[item.own_key.."counter"] = true
				local rng = ent:GetDropRNG()
				if player and rng:RandomFloat() > 0.7 then 
					local q = player:FireTechXLaser(ent.Position,ent.Velocity,30,player,0.3)
					q.PositionOffset = ent.PositionOffset
					q.SubType = 3
					q.Parent = ent
					d[item.own_key.."effect"] = q
				end
			end
		else
			if auxi.check_all_exists(d[item.own_key.."effect"]) then
				d[item.own_key.."effect"]:SetTimeout(1)
				d[item.own_key.."effect"] = nil
			end
			d[item.own_key.."counter"] = nil
		end
	end
end,
})

return item
