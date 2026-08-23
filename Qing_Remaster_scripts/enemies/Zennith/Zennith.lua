local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local wind = require("Qing_Remaster_scripts.enemies.Zennith.Enemy_wind")

local item = {
	ToCall = {},
	enemy = enums.Enemies.Zennith,
	own_key = "Enemies_Zennith_",
	Words = {
		zh = {
		},
	},
	now_hold = nil,
	strategies = {				--攻击策略列表
		["Idle"] = {anim = "Idle",},
		["attack_plan_A1"] = {anim = "AttackDown1",task = {["move_mode"] = 2,["state"] = 0,},},
		["attack_plan_A2"] = {anim = "AttackDown1",task = {["move_mode"] = 2,["state"] = 1,["pos_offset"] = Vector(0,-50),},},
		["attack_plan_A3"] = {anim = "AttackSide1",task = {["move_mode"] = 2,["state"] = 0,},},
		["attack_plan_A4"] = {anim = "AttackDown1",task = {["move_mode"] = 2,["state"] = 2,},},
		["attack_plan_A5"] = {anim = "AttackDown1",task = {["move_mode"] = 2,["state"] = 3,},},
		["attack_plan_B1"] = {anim = "AttackDown2",task = {["move_mode"] = 2,["state"] = 0,["pos_rate"] = 0.5,},},
		["attack_plan_B2"] = {anim = "AttackDown2",task = {["move_mode"] = 2,["state"] = 1,["pos_rate"] = 0.5,},},
		["attack_plan_B3"] = {anim = "AttackDown2",task = {["move_mode"] = 1,["state"] = 2,["pos_rate"] = 0.5,},},
		["attack_plan_C1"] = {anim = "AttackDown3",task = {["move_mode"] = 1,["state"] = 0,},},
		["attack_plan_C2"] = {anim = "AttackDown3",task = {["move_mode"] = 1,["state"] = 1,},},
		["attack_plan_C3"] = {anim = "AttackDown3",task = {["move_mode"] = 1,["state"] = 2,},},
	},
	Swapper = {
		["Appearing"] = "Idle",
		["Appear"] = "Idle",
		["AttackDown1"] = "Idle",
		["AttackDown2"] = "Idle",
		["AttackDown3"] = "Idle",
		["AttackDown4"] = "Idle",
		["AttackSide1"] = "Idle",
		["AttackSide2"] = "Idle",
	},
}
--这里也需要重写
function item.select_dir(anim)
	if string.sub(anim,1,10) == "AttackSide" then return Vector(auxi.choose(1,-1),0)
	else return Vector(0,1) end
end

function item.start_(pos)
	if auxi.check_all_exists(item.now_hold) ~= true then
		pos = pos or Game():GetRoom():GetCenterPos()
		local q = Isaac.Spawn(996,item.enemy,0,pos,Vector(0,0),nil):ToNPC()
		item.now_hold = q
	end
	return item.now_hold
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_INIT, params = 996,		--初始化
Function = function(_,ent)
	if ent.Variant == item.enemy then
		local s = ent:GetSprite() local d = ent:GetData()
		s:Play("Idle",true)
		ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_PLAYEROBJECTS
		ent:AddEntityFlags(EntityFlag.FLAG_NO_STATUS_EFFECTS)
		if (MusicManager():GetCurrentMusicID() ~= 24) then
			local music = MusicManager()
			music:Play(24, 1)
			music:UpdateVolume()
		end
		local room = Game():GetRoom()
		for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
			local door = room:GetDoor(slot)
			if door then door:Close() end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PROJECTILE_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then ent:GetSprite().Rotation = ent.Velocity:GetAngleDegrees() end
	if ent.FrameCount == 15 then
		if d[item.own_key.."tear2"] then local q = item.fire_z_brimstone(ent.Position,ent,d[item.own_key.."tear2"].ang) end
		if d[item.own_key.."wait_rate"] then d[wind.own_key.."rate"] = d[item.own_key.."wait_rate"] end
	end
	if ent.FrameCount == 5 then
		if d[item.own_key.."tear"] then local q = item.fire_z_brimstone(ent.Position,ent,d[item.own_key.."tear"].ang) end
	end
	if d[wind.own_key.."try_remove"] then ent:Remove() end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_LASER_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if ent.FrameCount == 5 and d[item.own_key.."laser"] then
		if d[item.own_key.."laser"].split then
			local info = d[item.own_key.."laser"].split
			local pos = ent:GetEndPoint()
			for i = 1,5 do
				local q = item.fire_z_projectile(pos,ent,auxi.MakeVector(info.ang + 180 - 30 + i * 10) * 10)
			end
		end
	end
end,
})

function item.fire_z_brimstone(pos,ent,ang)
	local q = Isaac.Spawn(7,1,0,pos,Vector(0,0),ent):ToLaser() q.Parent = ent q:SetTimeout(5) 
	q.Angle = ang q.DepthOffset = 100 q.PositionOffset = Vector(0,-20)
	q:SetColor(Color(1,1,1,1,0,0.7,1),60,99,false,false)
	return q
end

function item.fire_z_projectile(pos,ent,dir)
	local q = Isaac.Spawn(9,4,0,pos,dir,ent):ToProjectile()
	q.ProjectileFlags = q.ProjectileFlags | ProjectileFlags.NO_WALL_COLLIDE
	q.FallingAccel = -0.05
	local s = q:GetSprite() s:Load("gfx/boss/Zennith/Zennith_projectile.anm2",true) s:Play("RegularTear8",true)
	local d = q:GetData() d[item.own_key.."effect"] = {}
	return q
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = 996,			--战斗控制
Function = function(_,ent)
	if ent.Variant == item.enemy then
		local room = Game():GetRoom() local level = Game():GetLevel()
		local s = ent:GetSprite() local d = ent:GetData() local anim = s:GetAnimation()
		d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}			--有效参数：pos_offset	攻击位置
		if s:IsPlaying("Idle") then
			if s:IsEventTriggered("Target") then
				local find_s = {{name = "attack_plan_A1",weigh = 10,},}
				table.insert(find_s,#find_s + 1,{name = "Idle",weigh = 2,})
				table.insert(find_s,#find_s + 1,{name = "attack_plan_A2",weigh = 7,})
				table.insert(find_s,#find_s + 1,{name = "attack_plan_A3",weigh = 9,})
				if ent.HitPoints / ent.MaxHitPoints < 0.9 then
					table.insert(find_s,#find_s + 1,{name = "attack_plan_A4",weigh = 10,})
					table.insert(find_s,#find_s + 1,{name = "attack_plan_B1",weigh = 10,})
					table.insert(find_s,#find_s + 1,{name = "attack_plan_B2",weigh = 10,})
				end
				---[[
				if ent.HitPoints / ent.MaxHitPoints < 0.7 then
					table.insert(find_s,#find_s + 1,{name = "attack_plan_C1",weigh = 10,})
					table.insert(find_s,#find_s + 1,{name = "attack_plan_C2",weigh = 10,})
				end
				if ent.HitPoints / ent.MaxHitPoints < 0.5 then
					table.insert(find_s,#find_s + 1,{name = "attack_plan_A5",weigh = 15,})
					table.insert(find_s,#find_s + 1,{name = "attack_plan_C3",weigh = 10,})
					table.insert(find_s,#find_s + 1,{name = "attack_plan_B3",weigh = 15,})
				end
				---]]
				--find_s = {{name = "attack_plan_C3",weigh = 10,},}
				
				local stag = auxi.random_in_weighed_table(find_s)
				local sinfo = item.strategies[stag.name]
				s:Play(sinfo.anim,true) auxi.check_if_any(sinfo.extra,ent,item)
				d[item.own_key.."task"] = {}
				for u,v in pairs(sinfo.task or {}) do d[item.own_key.."task"][u] = v end
				d[item.own_key.."task"].dir = item.select_dir(sinfo.anim)
				local target = auxi.get_acceptible_target(ent)
				local target_pos = room:GetCenterPos() if target then target_pos = target.Position end
				local pos_rate = d[item.own_key.."task"]["pos_rate"] or 1
				target_pos = pos_rate * target_pos + (1 - pos_rate) * room:GetCenterPos()
				target_pos = target_pos + (d[item.own_key.."task"].pos_offset or Vector(0,0)) - d[item.own_key.."task"].dir * 60
				d[item.own_key.."task"].pos = target_pos
			end
		end
		
		d[item.own_key.."task"] = d[item.own_key.."task"] or {} 
		local state = d[item.own_key.."task"].state or 0
		local move_mode = d[item.own_key.."task"].move_mode or 0
		local dir = d[item.own_key.."task"].dir or item.select_dir(anim)
		local target_pos = d[item.own_key.."task"].pos
		local hp_rate = ent.HitPoints / ent.MaxHitPoints
		if move_mode == 1 then
			local target = auxi.get_acceptible_target(ent)
			target_pos = room:GetCenterPos() if target then target_pos = target.Position end
			local pos_rate = d[item.own_key.."task"]["pos_rate"] or 1
			target_pos = pos_rate * target_pos + (1 - pos_rate) * room:GetCenterPos()
			target_pos = target_pos + (d[item.own_key.."task"].pos_offset or Vector(0,0)) - dir * 60
		end
		target_pos = target_pos or room:GetCenterPos()
		if move_mode > 0 then ent.Velocity = ent.Velocity * 0.5 + 0.5 * (target_pos - ent.Position):Normalized() * (target_pos - ent.Position):Length() * 0.15
		else ent.Velocity = ent.Velocity * 0.5 end
		ent.Velocity = auxi.apply_friction(ent.Velocity,1)
		
		local direction = auxi.GetDirectionByAngle(dir:GetAngleDegrees())
		ent.FlipX = (direction == Direction.LEFT)
		
		if s:IsPlaying("AttackDown1") or s:IsPlaying("AttackSide1") then
			if state == 0 or state == 2 then
				if s:IsEventTriggered("Shoot") then
					local q = item.fire_z_brimstone(ent.Position,ent,dir:GetAngleDegrees())
					local qd = q:GetData() qd[item.own_key.."laser"] = {}
					local dir = d[item.own_key.."task"].dir or item.select_dir(anim)
					wind.change_control(1,{ang = dir:GetAngleDegrees() - 90,power = math.random(4),})
					if state == 0 then
						if hp_rate < 0.8 then 
							qd[item.own_key.."laser"].split = {ang = q.Angle,}
						end
					elseif state == 2 then
						for i = 1,4 do
							local ddir = dir:GetAngleDegrees() - 50 + i * 20
							local q = item.fire_z_projectile(ent.Position,ent,auxi.MakeVector(ddir) * 10)
							local dq = q:GetData()
							if hp_rate < 0.5 then 
								dq[item.own_key.."tear"] = {ang = ddir,ent = ent,}
							end
						end
					end
				end
			elseif state == 1 or state == 3 then		--10度的分叉射击
				if s:IsEventTriggered("Shoot") then
					for i = 1,2 do
						local q = item.fire_z_brimstone(ent.Position,ent,dir:GetAngleDegrees() - 30 + 20 * i)
						local qd = q:GetData() qd[item.own_key.."laser"] = {}
						if hp_rate < 0.6 then 
							qd[item.own_key.."laser"].split = {ang = q.Angle,}
						end
					end
					local rnd = math.random(2)
					wind.change_control(1,{ang = dir:GetAngleDegrees() - 90,power = math.random(4),})
				end
			end
		end
		
		if s:IsPlaying("AttackDown2") then
			if s:IsEventTriggered("Shoot") then
				if state == 0 then
					local wind_ang = 180 + auxi.choose(0,0,30,-30)
					if hp_rate < 0.5 then wind_ang = 180 + auxi.choose(0,0,20,-20) end
					wind.change_control(3,{ent = ent,power = auxi.choose(3,4,5),delta_rotation = wind_ang})
					for j = 1,3 do 
						delay_buffer.addeffe(function()
							for i = 1,15 do
								local q = item.fire_z_projectile(ent.Position + auxi.random_r() * 600,ent,auxi.random_v2() * 3) 
								local qd = q:GetData() qd[wind.own_key.."rate"] = 2 qd[wind.own_key.."test_remove"] = true
							end
						end,{},j * 10 - 5,{remove_now = true,})
					end
				elseif state == 1 then
					local wind_ang = auxi.choose(90,-90)
					local mxcnt = 8 local mxk = 2
					if hp_rate < 0.3 then mxcnt = 16 mxk = auxi.choose(2,3,4) end
					for j = 1,mxcnt do 
						delay_buffer.addeffe(function()
							for k = 1,mxk do 
								local q = item.fire_z_projectile(ent.Position,ent,auxi.MakeVector(j * 5 - 5 + 360/mxk * k) * auxi.choose(3,5,7,9)) 
								local qd = q:GetData() qd[wind.own_key.."rate"] = 2
							end
						end,{},j * 80/mxcnt - 5,{remove_now = true,})
					end
					wind.change_control(3,{ent = ent,power = auxi.choose(2,3,4,5,6),delta_rotation = wind_ang})
				elseif state == 2 then
					local wind_ang = 0
					local mxj = auxi.choose(2,3,4)
					for j = 1,mxj do
						local mxi = auxi.choose(4,5,6,7)
						for i = 1,mxi do
							local q = item.fire_z_projectile(ent.Position + auxi.MakeVector(j * 360/mxj) * 60,ent,auxi.MakeVector(360/mxi * i) * 3) 
							local qd = q:GetData() qd[item.own_key.."wait_rate"] = 1.5
						end
					end
					wind.change_control(3,{ent = ent,power = auxi.choose(1,2,3),delta_rotation = wind_ang})
				end
			end
		end
		
		if s:IsPlaying("AttackDown3") then
			if s:IsEventTriggered("Shoot") then
				if state == 0 then
					wind.change_control(3,{ent = ent,power = 2,delta_rotation = 0})
					local mxi = 8
					if hp_rate < 0.4 then mxi = auxi.choose(8,10,12) end
					for i = 1,mxi do 
						local q = item.fire_z_projectile(ent.Position,ent,auxi.MakeVector(360/mxi * i) * auxi.choose(3,5,7)) 
						local qd = q:GetData() qd[item.own_key.."wait_rate"] = 3
						q.ProjectileFlags = 1<<42
					end
				elseif state == 1 then
					local mxi = 8
					if hp_rate < 0.4 then mxi = auxi.choose(8,10,12) end
					for i = 1,mxi do 
						local q = item.fire_z_projectile(ent.Position,ent,auxi.MakeVector(360/mxi * i) * 3) 
						local dq = q:GetData() dq[item.own_key.."tear2"] = {ang = 360/mxi * i,ent = ent,}
					end
					wind.change_control(3,{ent = ent,power = 3,delta_rotation = math.random(2) * 180})
				elseif state == 2 then
					for j = 1,10 do
						delay_buffer.addeffe(function()
							if auxi.check_all_exists(ent) then
								local target = auxi.get_acceptible_target(ent)
								local dir = (target.Position - ent.Position):Normalized()
								for i = 1,3 do
									local q = item.fire_z_projectile(ent.Position,ent,auxi.get_by_rotate(dir,(i-2) * 15,auxi.choose(3,5,7,9))) 
									local qd = q:GetData() qd[wind.own_key.."rate"] = 5
								end
							end
						end,{},j * 5 - 5,{remove_now = true,})
					end
					wind.change_control(3,{ent = auxi.get_acceptible_target(ent),power = 2,delta_rotation = 180,})
				end
			end
		end
		if s:IsFinished(anim) then
			local tg = auxi.check_if_any(item.Swapper[anim],ent) or "Idle"
			s:Play(tg,true)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = 996,
Function = function(_,ent)
	if ent.Variant == item.enemy then
		local q = Isaac.Spawn(5,100,enums.Items.A_Shard_Of_Lava,ent.Position,Vector(0,0),nil)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = 996,
Function = function(_,ent)
	if ent.Variant == item.enemy then
		wind.grow_slow()
	end
end,
})

return item
