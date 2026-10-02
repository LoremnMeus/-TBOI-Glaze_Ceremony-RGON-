local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	entity = enums.Enemies.Staff_Strike,
	own_key = "Enemies_staff_strike_",
}

function item.generate_staff(pos,vel,params)
	if params.spawner and params.spawner.HitPoints == 1 then return end
	params = params or {}
	local q = Isaac.Spawn(1000,item.entity,0,pos,vel,params.spawner)
	local d = q:GetData() local s = q:GetSprite()
	d[item.own_key.."effect"] = {target = params.target,}
	if (params.subtype or 0) == 1 then s:Play("Idle2",true) end
	return q
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_INIT, params = item.entity,	--初始化
Function = function(_,ent)
	if ent.Variant == item.entity then
		local s = ent:GetSprite()
		local d = ent:GetData()
		ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
		s:Play("Idle",true)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = item.entity,		--速度、位移调整
Function = function(_,ent)
	if ent.Variant == item.entity then
		local s = ent:GetSprite()
		local d = ent:GetData()
		if s:WasEventTriggered("Fall") == false then
			if auxi.check_all_exists(d[item.own_key.."effect"].target) == true then 
				local target = d[item.own_key.."effect"].target
				ent.Velocity = target.Velocity ent.Position = target.Position
			else ent.Velocity = Vector(0,0) end
		else ent.Velocity = Vector(0,0) end
		
		if s:IsEventTriggered("Down") then
			Game():ShakeScreen(10)
			auxi.draw_scan(function(v,val) if (v.Position - ent.Position):Length() < 10 + 15 then v:TakeDamage(1,0,EntityRef(ent),30) end end,auxi.GetPlayers(),{})
			local rnd = math.random(1000)
			if rnd > 400 then
				local rd = math.random(3)
				for i = 1,rd do
					local q = Isaac.Spawn(1000,72,0,ent.Position,Vector(0,0),ent):ToEffect() q.Rotation = math.random(360)
				end
			elseif rnd > 300 then Isaac.Spawn(1000, 61, 1, ent.Position, Vector(0,0), ent):ToEffect() end
		end
		if s:IsEventTriggered("Leave") then
			ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
		end
		if s:IsFinished("Idle") or s:IsFinished("Idle2") then
			ent:Remove()
		end
	end
end,
})
	
return item