local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local modReference
local item = {
	ToCall = {},
	challange = enums.Challenges.Heterothermal_Concentric,
	p1 = nil,
	p2 = nil,
	own_key = "Challenge_Hete_Con_",
	dirs = {
		[4] = Vector(-1,0),
		[5] = Vector(1,0),
		[6] = Vector(0,-1),
		[7] = Vector(0,1),
	},
}

--[[
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if Game().Challenge == item.challange then
		if cacheFlag == CacheFlag.CACHE_FLYING then
			if player.CanFly == false then
				player.CanFly = true
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_INIT, params = nil,
Function = function(_,player)
	if Game().Challenge == item.challange then
		if player:GetPlayerType() == 19 then
			if item.p1 == nil or item.p1:Exists() == false or item.p1:IsDead() then
				item.p1 = player
			end
		end
		if player:GetPlayerType() == 20 then
			if item.p2 == nil or item.p2:Exists() == false or item.p2:IsDead() then
				item.p2 = player
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if Game().Challenge == item.challange then
		if item.p2 ~= nil and item.p2:Exists() == true and not item.p2:IsDead() and item.p1 ~= nil and item.p1:Exists() == true and not item.p1:IsDead() then
			if Game():GetFrameCount() % 5 == 1 then
				local p1 = item.p1
				local p2 = item.p2
				if Game():GetFrameCount() % 10 == 1 then
					p2 = item.p1
					p1 = item.p2
				end
				local dir = p1.Position - p2.Position
				local flg = p1.TearFlags | p2.TearFlags | BitSet128(1,0)
				if dir:Length() > 50 then
					local q = p1:FireTechLaser(p1.Position,LaserOffset.LASER_TECH1_OFFSET,-dir,false,true):ToLaser()
					q.Parent = p1
					q:SetMaxDistance(dir:Length() - 15)
					q.DepthOffset = -100
					q.TearFlags = flg
				end
			end
		end
	end
end,
})
--]]

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_INIT, params = nil,
Function = function(_,player)
	if Game().Challenge == item.challange then
		save.elses[item.own_key.."Index"] = save.elses[item.own_key.."Index"] or {}
		local idx = player:GetData().__Index
		if save.elses[item.own_key.."Index"][idx] ~= true then
			player:AddCollectible(465)
			save.elses[item.own_key.."Index"][idx] = true
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if Game().Challenge == item.challange then
		local d = player:GetData()
		local gdir = auxi.ggdir(player,true,false,false,nil,{real = true})
		d.check_dir = gdir
	end
end,
})


table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_INPUT_ACTION, params = nil,
Function = function(_,ent,hook,button)
	if Game().Challenge == item.challange then
	if ent and ent:ToPlayer() then
		local player = ent:ToPlayer()
		local tg = nil
		if auxi.check_for_the_same(player,Game():GetPlayer(0)) then tg = Game():GetPlayer(1)
		elseif auxi.check_for_the_same(player,Game():GetPlayer(1)) then	tg = Game():GetPlayer(0) end
		if tg and not auxi.check_for_the_same(player,tg) then
			local d = player:GetData()
			local dir = (tg.Position - player.Position):Normalized()
			if Game():GetRoom():IsMirrorWorld() == true then dir = Vector(-dir.X,dir.Y) end
			local gdir = d.check_dir or Vector(0,0)
			if gdir:Length() > 0.05 then
				if item.dirs[button] then
					local info = item.dirs[button] or Vector(0,0)
					local val = info.X * dir.X + info.Y * dir.Y
					if (hook == InputHook.IS_ACTION_TRIGGERED or hook == InputHook.IS_ACTION_PRESSED) then
					elseif hook == InputHook.GET_ACTION_VALUE then
						if math.abs(gdir.Y) > 0.7 then
							return val
						else 
							return val * 0.01
						end
					end
				end
			end
		end
	end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_, tear)
	if Game().Challenge ~= item.challange then return end
	local d = tear:GetData()
	if d[item.own_key.."boosted"] then return end
	local spawner = tear.SpawnerEntity and tear.SpawnerEntity:ToPlayer()
	if not spawner then return end
	local other
	if auxi.check_for_the_same(spawner, Game():GetPlayer(0)) then
		other = Game():GetPlayer(1)
	elseif auxi.check_for_the_same(spawner, Game():GetPlayer(1)) then
		other = Game():GetPlayer(0)
	end
	if not other or not auxi.check_all_exists(other) then return end
	if (spawner.Position - other.Position):Length() < 28 then return end
	if (tear.Position - other.Position):Length() > other.Size + tear.Size + 10 then return end
	d[item.own_key.."boosted"] = true
	tear.CollisionDamage = tear.CollisionDamage * 1.5
	tear.Velocity = tear.Velocity * 1.15
	tear.Color = Color(1, 0.75, 1.2, 1, 0.18, 0.04, 0.28)
end,
})

return item
