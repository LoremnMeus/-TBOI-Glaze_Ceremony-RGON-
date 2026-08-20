local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	ToCall = {},
	entity = enums.Items.Pendulum_Star,
	familiar = enums.Familiars.Star_Pendulum,
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local cnt = player:GetCollectibleNum(item.entity)
	if cacheFlag == CacheFlag.CACHE_FAMILIARS then
		player:CheckFamiliar(item.familiar, cnt * 2, player:GetCollectibleRNG(item.entity), Isaac.GetItemConfig():GetCollectible(item.entity))
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_INIT, params = item.familiar,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local room = Game():GetRoom()
	local player = ent.Player
	if (player == nil or player:Exists() == false) and ent.SpawnerEntity and ent.SpawnerEntity:ToPlayer() then
		player = ent.SpawnerEntity:ToPlayer()
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_FAMILIAR_COLLISION, params = item.familiar,
Function = function(_,ent,col,low)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local room = Game():GetRoom()
	local player = ent.Player
	if (player == nil or player:Exists() == false) and ent.SpawnerEntity and ent.SpawnerEntity:ToPlayer() then
		player = ent.SpawnerEntity:ToPlayer()
	end
	if math.abs(s.Rotation) < 7 then
		if col:IsVulnerableEnemy() and col:IsActiveEnemy() and not col:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
			if player:HasCollectible(247) then
				col:TakeDamage(5,0,EntityRef(player),0)
			else
				col:TakeDamage(3.5,0,EntityRef(player),0)
			end
			d.mis_dir = 0
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local room = Game():GetRoom()
	local player = ent.Player
	if (player == nil or player:Exists() == false) and ent.SpawnerEntity and ent.SpawnerEntity:ToPlayer() then
		player = ent.SpawnerEntity:ToPlayer()
	end
	if d.Pendulum_counter == nil then d.Pendulum_counter = 0 end
	if d.mis_dir == nil then d.mis_dir = 0 end
	d.mis_dir = d.mis_dir + 1
	if d.Pendulum_range_counter == nil then d.Pendulum_range_counter = 0 end
	if d.Pendulum_range == nil then d.Pendulum_range = 45 end
	local delta = math.random(1000)/1000 + 0.5 + (90-d.Pendulum_range)/90 + (90 - math.abs(s.Rotation))/90 * 2
	if player:HasCollectible(247) then
		s.Offset = Vector(0,-384)
	else
		s.Offset = Vector(0,-334)
	end
	d.Pendulum_counter = d.Pendulum_counter + delta
	--s:SetOverlayFrame("Idle4",math.floor(d.Pendulum_counter) % 360)
	local lst_r = s.Rotation
	s.Rotation = s.Rotation + d.Pendulum_range * (math.sin(math.rad(d.Pendulum_counter)) - math.sin(math.rad(d.Pendulum_counter - delta)))
	if lst_r * s.Rotation < 0 then
		d.Pendulum_range_counter = d.Pendulum_range_counter + 7 + math.random(5)
		d.Pendulum_range = d.Pendulum_range + 25 * (math.sin(math.rad(d.Pendulum_range_counter)) - math.sin(math.rad(d.Pendulum_range_counter - 10)))
	end
	if s:IsFinished("Idle") or s:IsFinished("Idle2") or s:IsFinished("Idle3") then
		local rnd = math.random(3)
		if rnd == 1 then
			s:Play("Idle",true)
		elseif rnd == 2 then
			s:Play("Idle2",true)
		else
			s:Play("Idle3",true)
		end
	end
	if d.target == nil or d.target:Exists() == false or d.target:IsDead() or (d.mis_dir > 480 and d.mis_dir % 15 == 1) then		--如果一直不能命中敌人，则会考虑更换
		local n_entity = Isaac.GetRoomEntities()
		local n_enemy = auxi.getenemies(n_entity)
		local target = nil
		if #n_enemy > 0 then target = n_enemy[1] end
		for u,v in pairs(n_enemy) do
			if (v.Position - ent.Position):Length() < (target.Position - ent.Position):Length() then
				target = v
			end
		end
		d.target = target
	end
	if d.target and math.random(1000) <= 3 then		--小概率随机切换目标
		local n_entity = Isaac.GetRoomEntities()
		local n_enemy = auxi.getenemies(n_entity)
		local target = nil
		if #n_enemy > 0 then target = n_enemy[math.random(#n_enemy)] end
		d.target = target
	end
	local n_target = d.target
	if n_target == nil or n_target:Exists() == false or n_target:IsDead() then n_target = player end
	local dis = n_target.Position - ent.Position 
	if dis:Length() < 10 then
		ent.Velocity = ent.Velocity * 0.5
	else
		local dir = dis:Normalized()
		local ddir = Vector(0,0)
		if math.ceil(d.Pendulum_counter + 90) % 360 < 180 then
			ddir = Vector(math.min(0.2,dir.X),dir.Y)
		else
			ddir = Vector(math.max(-0.2,dir.X),dir.Y)
		end
		ent.Velocity = ddir * (math.abs(s.Rotation)/90 * 5 + 2)
	end
end,
})

return item