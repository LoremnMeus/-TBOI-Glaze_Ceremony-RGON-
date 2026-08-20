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
	tosay = {word = {},},
	Talking_Pos_Offset =  Vector(30,-50),
	Words = {
		zh = {
			"风暴起于天南",
			"破坏的欲望",
			"毁灭一切",
			"把它们全部都捏到爆浆",
			"破坏让我破坏",
			"可恶的家伙",
			"要是我抓住了你",
			"不要以为我好欺负",
			"这是重要的东西",
			"为什么阻拦我",
			"罪恶在疯涨",
			"小青已经失去音讯三天",
			"究竟是谁害的",
			"给我绝对的力量",
			"风中传来难闻的气味",
			"预感敌人就在身边",
			"反击必须反击",
			"如果还能继续深入的话",
			"力尽于此了吗",
			"对不起我失败了",
			"请原谅我",
			"琉璃原来是你",
			"此刻必须退去了",
		},
	},
	now_hold = nil,
}

function item.start_(pos)
	if item.now_hold == nil or item.now_hold:Exists() == false then
		local room = Game():GetRoom()
		if pos == nil then pos = room:GetCenterPos() end
		local q = Isaac.Spawn(996,item.enemy,0,pos,Vector(0,0),nil)
	end
	return item.now_hold
end

local function add_flip(ent)
	local d = ent:GetData()
	if d.dir then
		local direction = auxi.GetDirectionByAngle(d.dir:GetAngleDegrees())
		ent.FlipX = (direction == Direction.LEFT)
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_INIT, params = 996,	--初始化
Function = function(_,ent)
	if ent.Variant == item.enemy then
		local s = ent:GetSprite()
		local d = ent:GetData()
		if d.State == nil then
			d.State = 0
		end
		if(item.now_hold ~= nil and item.now_hold:Exists()) then
			ent:Remove()
		else
			item.now_hold = ent
		end
		d.should_flip = true
		d.Should_Move = true
		d.move_mode = 1
		d.dir_leng = 100
		d.dir = Vector(0,1)
		ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_PLAYEROBJECTS
		s:Play("Idle",true)
		ent:AddEntityFlags(EntityFlag.FLAG_NO_STATUS_EFFECTS)
		if (MusicManager():GetCurrentMusicID() ~= 24) then
			local music = MusicManager()
			music:Play(24, 1)
			music:UpdateVolume()
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = 996,		--速度、位移调整
Function = function(_,ent)
	if ent.Variant == item.enemy then
		local room = Game():GetRoom()
		local s = ent:GetSprite()
		local d = ent:GetData()
		if d.Should_Move and d.Should_Move == true then
			if d.move_mode == 1 then		--跟随角色
				if d.target_player == nil or d.target_player:Exists() == false then
					for playerNum = 1, Game():GetNumPlayers() do
						local player = Game():GetPlayer(playerNum - 1)
						if math.random(playerNum) == 1 then
							d.target_player = player
						end
					end
				end
				if d.target_player and d.target_player:Exists() then
					if d.dir == nil then d.dir = Vector(0,1) end
					if d.dir_leng == nil then d.dir_leng = 100 end
					local pos = d.target_player.Position - d.dir * d.dir_leng
					local dir = ent.Position - pos
					if ent.Velocity:Length() > 5 then
						ent.Velocity = ent.Velocity:Length() * (ent.Velocity - dir/30):Normalized()
					else
						ent.Velocity = ent.Velocity - dir/30
					end
					ent.Velocity = ent.Velocity * 0.98
					--[[
					if dir:Length() < 20 and Game():GetFrameCount()//5 == 1 then
						d.dir_leng = math.max(10,d.dir_leng - 5)
					else
						d.dir_leng = math.min(100,d.dir_leng + 5)
					end
					--]]
				end
			elseif d.move_mode == 2 then	--移动至固定位置
				if d.move_pos == nil then d.move_pos = room:GetCenterPos() end
				local dir = ent.Position - d.move_pos
				if ent.Velocity:Length() > 5 then
					ent.Velocity = ent.Velocity:Length() * (ent.Velocity - dir/30):Normalized()
				else
					ent.Velocity = ent.Velocity - dir/30
				end
				ent.Velocity = ent.Velocity * 0.95
			else
			end
		else
			if ent.Velocity:Length() > 0.05 then
				ent.Velocity = Vector(0,0)
			end
		end
		if d.should_flip and d.should_flip == true then
			add_flip(ent)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = 996,		--行为、战斗控制
Function = function(_,ent)
	local room = Game():GetRoom()
	if ent.Variant == item.enemy then
		local s = ent:GetSprite()
		local d = ent:GetData()
		local level = Game():GetLevel()
		local desc = level:GetCurrentRoomDesc()
		local player = Game():GetPlayer(0)
		local hud = Game():GetHUD()
		if d.State == nil then
			d.State = 0
		end
		if s:IsFinished("Appearing") then
			s:Play("Idle",true)
		end
		if s:IsPlaying("Idle") then
			if s:IsEventTriggered("Target") then
				local find_s = {{name = "attack_plan_A1",weight = 10,},}
				table.insert(find_s,#find_s + 1,{name = "Idle",weight = 2,})
				table.insert(find_s,#find_s + 1,{name = "attack_plan_A2",weight = 7,})
				table.insert(find_s,#find_s + 1,{name = "attack_plan_A3",weight = 9,})
				if ent.HitPoints / ent.MaxHitPoints < 0.95 then
					table.insert(find_s,#find_s + 1,{name = "attack_plan_B1",weight = 10,})
					table.insert(find_s,#find_s + 1,{name = "attack_plan_B2",weight = 10,})
				end
				if ent.HitPoints / ent.MaxHitPoints < 0.8 then
					table.insert(find_s,#find_s + 1,{name = "attack_plan_C1",weight = 10,})
					table.insert(find_s,#find_s + 1,{name = "attack_plan_C2",weight = 10,})
				end
				if ent.HitPoints / ent.MaxHitPoints < 0.6 then
					table.insert(find_s,#find_s + 1,{name = "attack_plan_A4",weight = 10,})
					table.insert(find_s,#find_s + 1,{name = "attack_plan_A5",weight = 10,})
					table.insert(find_s,#find_s + 1,{name = "attack_plan_C3",weight = 10,})
					table.insert(find_s,#find_s + 1,{name = "attack_plan_B3",weight = 10,})
				end
				
				local stag = find_s[1]
				local tot_wei = 0
				for u,v in pairs(find_s) do
					tot_wei = tot_wei + v.weight
				end
				tot_wei = math.random(tot_wei)
				for i = 1,#find_s do
					tot_wei = tot_wei - find_s[i].weight
					if tot_wei <= 0 then
						stag = find_s[i]
						break
					end
				end
				
				if stag.name == "attack_plan_A1" then
					s:Play("AttackDown1",true)
					d.Should_Move = true
					d.move_pos = room:GetCenterPos()
					if d.target_player and d.target_player:Exists() then
						d.move_pos = d.target_player.Position
					end
					d.move_mode = 2
					d.State = 0
					d.dir = Vector(0,1)
				elseif stag.name == "attack_plan_A2" then
					s:Play("AttackDown1",true)
					d.Should_Move = true
					d.move_pos = room:GetCenterPos()
					if d.target_player and d.target_player:Exists() then
						d.move_pos = room:FindFreeTilePosition(d.target_player.Position + Vector(0,-50),10)
					end
					d.move_mode = 2
					d.State = 1
					d.dir = Vector(0,1)
				elseif stag.name == "attack_plan_A3" then		--转向攻击
					s:Play("AttackSide1",true)
					d.Should_Move = true
					d.move_pos = room:GetCenterPos()
					if d.target_player and d.target_player:Exists() then
						d.move_pos = d.target_player.Position
					end
					d.move_mode = 2
					d.State = 0
					local rnd = math.random(2) * 2 - 3
					d.dir = Vector(rnd,0)
				elseif stag.name == "attack_plan_A4" then
					s:Play("AttackDown1",true)
					d.Should_Move = true
					d.move_pos = room:GetCenterPos()
					if d.target_player and d.target_player:Exists() then
						d.move_pos = d.target_player.Position
					end
					d.move_mode = 2
					d.State = 2
					d.dir = Vector(0,1)
				elseif stag.name == "attack_plan_A5" then
					s:Play("AttackDown1",true)
					d.Should_Move = true
					d.move_pos = room:GetCenterPos()
					if d.target_player and d.target_player:Exists() then
						d.move_pos = room:FindFreeTilePosition(d.target_player.Position + Vector(0,-50),10)
					end
					d.move_mode = 2
					d.State = 3
					d.dir = Vector(0,1)
				elseif stag.name == "attack_plan_B1" then		--简单弹幕
					s:Play("AttackDown2",true)
					d.Should_Move = true
					d.move_pos = (room:GetCenterPos() + player.Position)/2
					if d.target_player and d.target_player:Exists() then
						d.move_pos = (room:GetCenterPos() + d.target_player.Position)/2
					end
					d.move_mode = 2
					d.State = 0
				elseif stag.name == "attack_plan_B2" then		--随风弹幕
					s:Play("AttackDown2",true)
					d.Should_Move = true
					d.move_pos = (room:GetCenterPos() + player.Position)/2
					if d.target_player and d.target_player:Exists() then
						d.move_pos = d.target_player.Position
					end
					d.move_mode = 2
					d.State = 1
				elseif stag.name == "attack_plan_B3" then		--随风弹幕
					s:Play("AttackDown2",true)
					d.Should_Move = true
					d.move_pos = (room:GetCenterPos() + player.Position)/2
					if d.target_player and d.target_player:Exists() then
						d.move_pos = d.target_player.Position
					end
					d.move_mode = 1
					d.State = 2
				elseif stag.name == "attack_plan_C1" then		--散射
					s:Play("AttackDown3",true)
					d.Should_Move = true
					d.move_pos = (player.Position)
					if d.target_player and d.target_player:Exists() then
						d.move_pos = (d.target_player.Position)
					end
					d.move_mode = 1
					d.State = 0
				elseif stag.name == "attack_plan_C2" then
					s:Play("AttackDown3",true)
					d.Should_Move = true
					d.move_pos = (player.Position)
					if d.target_player and d.target_player:Exists() then
						d.move_pos = (d.target_player.Position)
					end
					d.move_mode = 1
					d.State = 1
				elseif stag.name == "attack_plan_C3" then
					s:Play("AttackDown3",true)
					d.Should_Move = true
					d.move_pos = (player.Position)
					if d.target_player and d.target_player:Exists() then
						d.move_pos = (d.target_player.Position)
					end
					d.move_mode = 1
					d.State = 2
				else
					d.move_mode = math.random(3) - 1
					d.State = 0
				end
				if d.is_first_update == nil then
					d.is_first_update = true
					for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
						local door = room:GetDoor(slot)
						if (door) then
							door:Close()
						end
					end
				end
			end
		end
		
		if s:IsPlaying("AttackDown1") or s:IsPlaying("AttackSide1") then
			if d.State == 0 or d.State == 2 then
				if s:IsEventTriggered("Shoot") then
					local q = Isaac.Spawn(7,1,0,ent.Position,Vector(0,0),ent):ToLaser()
					q.Parent = ent
					q:SetTimeout(5)
					if d.dir == nil then d.dir = Vector(0,1) end
					q.Angle = d.dir:GetAngleDegrees()
					q.DepthOffset = 100
					q.PositionOffset = Vector(0,-20)
					q:SetColor(Color(1,1,1,1,0,0.7,1),60,99,false,false)
					wind.change_control(1,{ang = d.dir:GetAngleDegrees() - 90,power = math.random(4) - 1,})
					if ent.HitPoints / ent.MaxHitPoints < 0.6 and d.State == 0 then
						delay_buffer.addeffe(function(params)
							local level = Game():GetLevel()
							local desc = level:GetCurrentRoomDesc()
							if desc.SafeGridIndex == params.sgid then
								if params.eent ~= nil then
									local pos = params.eent:GetEndPoint()
									for i = 1,2 do
										local q = Isaac.Spawn(7,1,0,pos,Vector(0,0),params.ent):ToLaser()
										q:SetTimeout(15)
										q.Angle = params.ang - 110 + i * 20
										q:SetColor(Color(1,1,1,1,0,0.7,1),60,99,false,false)
										if ent and ent:Exists() and ent.HitPoints / ent.MaxHitPoints < 0.3 then
											delay_buffer.addeffe(function(params)
												local level = Game():GetLevel()
												local desc = level:GetCurrentRoomDesc()
												if desc.SafeGridIndex == params.sgid then
													if params.eent ~= nil then
														local pos = params.eent:GetEndPoint()
														local rnd = math.random(6) + 6
														for i = 1,rnd do
															local q = Isaac.Spawn(7,1,0,pos,Vector(0,0),params.ent):ToLaser()
															q:SetTimeout(5)
															q.Angle = params.ang + 90 + i * 360/rnd
															q:SetColor(Color(1,1,1,1,0,0.7,1),60,99,false,false)
															q:SetMaxDistance(150)
														end
													end
												end
											end,{sgid = desc.SafeGridIndex,eent = q,ang = q.Angle + 180,ent = ent,},15)
										end
									end
									for i = 1,2 do
										local q = Isaac.Spawn(7,1,0,pos,Vector(0,0),params.ent):ToLaser()
										q:SetTimeout(15)
										q.Angle = params.ang + 110 - i * 20
										q:SetColor(Color(1,1,1,1,0,0.7,1),60,99,false,false)
										if ent and ent:Exists() and ent.HitPoints / ent.MaxHitPoints < 0.3 then
											delay_buffer.addeffe(function(params)
												local level = Game():GetLevel()
												local desc = level:GetCurrentRoomDesc()
												if desc.SafeGridIndex == params.sgid then
													if params.eent ~= nil then
														local pos = params.eent:GetEndPoint()
														local rnd = math.random(6) + 6
														for i = 1,rnd do
															local q = Isaac.Spawn(7,1,0,pos,Vector(0,0),params.ent):ToLaser()
															q:SetTimeout(5)
															q.Angle = params.ang + 90 + i * 360/rnd
															q:SetColor(Color(1,1,1,1,0,0.7,1),60,99,false,false)
															q:SetMaxDistance(150)
														end
													end
												end
											end,{sgid = desc.SafeGridIndex,eent = q,ang = q.Angle + 180,ent = ent,},15)
										end
									end
								end
							end
						end,{sgid = desc.SafeGridIndex,eent = q,ang = d.dir:GetAngleDegrees() + 180,ent = ent,},10)
					end
				
					if d.State == 2 then
						local rnd = math.random(2) * 2 - 3
						for i = 1,10 do
							delay_buffer.addeffe(function(params)
								local level = Game():GetLevel()
								local desc = level:GetCurrentRoomDesc()
								local pos = (params.eent:GetEndPoint() * 0.95 + ent.Position * 0.05)
								local rnd = math.random(5) + 4
								for i = 1,5 do
									if params.sgid == desc.SafeGridIndex then
										local q = Isaac.Spawn(9,4,0,pos,auxi.MakeVector(params.ang - 30 + i * 10) * rnd,ent):ToProjectile()
										q.ProjectileFlags = q.ProjectileFlags | ProjectileFlags.NO_WALL_COLLIDE
										q.FallingAccel = -0.05
									end
								end
							end,{sgid = desc.SafeGridIndex,eent = q,ang = q.Angle + 180 + rnd * (- 110 + i * 20),ent = ent,},(i-1) * 2)
						end
					end
				end
			elseif d.State == 1 or d.State == 3 then		--10度的分叉射击
				if s:IsEventTriggered("Shoot") then
					for i = 1,2 do
						local q = Isaac.Spawn(7,1,0,ent.Position,Vector(0,0),ent):ToLaser()
						q.Parent = ent
						q:SetTimeout(5)
						if d.dir == nil then d.dir = Vector(0,1) end
						q.Angle = d.dir:GetAngleDegrees() - 30 + 20 * i
						local Ang = q.Angle
						q.DepthOffset = 100
						q.PositionOffset = Vector(0,-20)
						q:SetColor(Color(1,1,1,1,0,0.7,1),60,99,false,false)
						if ent.HitPoints / ent.MaxHitPoints < 0.5 and d.State == 1 then
							delay_buffer.addeffe(function(params)
								local level = Game():GetLevel()
								local desc = level:GetCurrentRoomDesc()
								if desc.SafeGridIndex == params.sgid then
									if params.eent ~= nil then
										local pos = params.eent:GetEndPoint()
										local ent = params.ent
										for i = 1,2 do
											local q = Isaac.Spawn(7,1,0,pos,Vector(0,0),params.ent):ToLaser()
											q:SetTimeout(15)
											q.Angle = params.ang - 110 + i * 20
											q:SetColor(Color(1,1,1,1,0,0.7,1),60,99,false,false)
											if ent and ent:Exists() and ent.HitPoints / ent.MaxHitPoints < 0.3 then
												delay_buffer.addeffe(function(params)
													local level = Game():GetLevel()
													local desc = level:GetCurrentRoomDesc()
													if desc.SafeGridIndex == params.sgid then
														if params.eent ~= nil then
															local pos = params.eent:GetEndPoint()
															local rnd = math.random(6) + 6
															for i = 1,rnd do
																local q = Isaac.Spawn(7,1,0,pos,Vector(0,0),params.ent):ToLaser()
																q:SetTimeout(5)
																q.Angle = params.ang + 90 + i * 360/rnd
																q:SetColor(Color(1,1,1,1,0,0.7,1),60,99,false,false)
																q:SetMaxDistance(150)
															end
														end
													end
												end,{sgid = desc.SafeGridIndex,eent = q,ang = params.ang - 90 + 180,ent = ent,},15)
											end
										end
										for i = 1,2 do
											local q = Isaac.Spawn(7,1,0,pos,Vector(0,0),params.ent):ToLaser()
											q:SetTimeout(15)
											q.Angle = params.ang + 110 - i * 20
											q:SetColor(Color(1,1,1,1,0,0.7,1),60,99,false,false)
											if ent and ent:Exists() and ent.HitPoints / ent.MaxHitPoints < 0.3 then
												delay_buffer.addeffe(function(params)
													local level = Game():GetLevel()
													local desc = level:GetCurrentRoomDesc()
													if desc.SafeGridIndex == params.sgid then
														if params.eent ~= nil then
															local pos = params.eent:GetEndPoint()
															local rnd = math.random(6) + 6
															for i = 1,rnd do
																local q = Isaac.Spawn(7,1,0,pos,Vector(0,0),params.ent):ToLaser()
																q:SetTimeout(5)
																q.Angle = params.ang + 90 + i * 360/rnd
																q:SetColor(Color(1,1,1,1,0,0.7,1),60,99,false,false)
																q:SetMaxDistance(150)
															end
														end
													end
												end,{sgid = desc.SafeGridIndex,eent = q,ang = params.ang + 90 + 180,ent = ent,},15)
											end
										end
									end
								end
							end,{sgid = desc.SafeGridIndex,eent = q,ang = d.dir:GetAngleDegrees() + 180 - 30 + 20 * i,ent = ent,},10)
						end
						if d.State == 3 then
							local rnd = math.random(2) * 2 - 3
							for i = 1,10 do
								delay_buffer.addeffe(function(params)
									local level = Game():GetLevel()
									local desc = level:GetCurrentRoomDesc()
									local pos = (params.eent:GetEndPoint() * 0.95 + ent.Position * 0.05)
									local rnd = math.random(5) + 4
									for i = 1,5 do
										if params.sgid == desc.SafeGridIndex then
											local q = Isaac.Spawn(9,4,0,pos,auxi.MakeVector(params.ang - 30 + i * 10) * rnd,ent):ToProjectile()
											q.ProjectileFlags = q.ProjectileFlags | ProjectileFlags.NO_WALL_COLLIDE
											q.FallingAccel = -0.05
										end
									end
								end,{sgid = desc.SafeGridIndex,eent = q,ang = q.Angle + 180 + rnd * (- 110 + i * 20),ent = ent,},(i-1) * 2)
							end
						end
					end
					local rnd = math.random(2)
					wind.change_control(1,{ang = d.dir:GetAngleDegrees() - 90 - 30 + 20 * rnd,power = math.random(4) - 1,})
				end
			end
		end
		
		if s:IsPlaying("AttackDown2") then
			if s:IsEventTriggered("Shoot") then
				if d.State == 0 then
					local wind_ang = math.random(8) * 45
					wind.change_control(3,{ent = ent,power = math.random(5) - 1,pos_rev_del = wind_ang})
					local rnd = math.random(3) * 2 + 6
					for i = 1,rnd do
						local q = Isaac.Spawn(9,4,0,ent.Position,auxi.MakeVector(360/rnd * i) * 10,ent):ToProjectile()
						q.FallingAccel = -0.05
						q.ProjectileFlags = q.ProjectileFlags | ProjectileFlags.BOUNCE
					end
					if ent.HitPoints / ent.MaxHitPoints < 0.4 then
						delay_buffer.addeffe(function(params)
							for i = 1,rnd - 1 do
								local q = Isaac.Spawn(9,4,0,ent.Position,auxi.MakeVector(360/rnd * i) * 10,ent):ToProjectile()
								q.FallingAccel = -0.05
								q.ProjectileFlags = q.ProjectileFlags | ProjectileFlags.SINE_VELOCITY
							end
						end,{},15)
					end
				elseif d.State == 2 then
					local wind_ang = math.random(16) * 22.5
					wind.change_control(3,{ent = ent,power = math.random(5) - 1,pos_rev_del = wind_ang})
					local rnd = math.random(10) + 5
					local rnd2 = math.random(2) + 1
					for i = 1,rnd2 do
						delay_buffer.addeffe(function(params)
						for i = 1,rnd do
							local q = Isaac.Spawn(9,4,0,ent.Position,auxi.MakeVector(360/rnd * i) * 3,nil):ToProjectile()
							q.ProjectileFlags = q.ProjectileFlags | ProjectileFlags.SMART
							q.FallingAccel = -0.1
						end
						end,{},(i-1) * 15)
					end
					--print(1)
				elseif d.State == 1 then
					local wind_ang = math.random(6) * 60
					wind.change_control(3,{ent = ent,power = math.random(5) - 1,pos_rev_del = wind_ang})
					local rnd = math.random(2) * 2 + 4
					for i = 1,rnd do
						local q = Isaac.Spawn(9,4,0,ent.Position,auxi.MakeVector(360/rnd * i) * 15,nil):ToProjectile()
						q.FallingAccel = -0.1
					end
					if ent.HitPoints / ent.MaxHitPoints < 0.6 then
						for i = 1,rnd do
							local q = Isaac.Spawn(9,4,0,ent.Position,auxi.MakeVector(360/rnd * i) * 15,ent):ToProjectile()
							q.FallingAccel = -0.2
						end
					end
					if ent.HitPoints / ent.MaxHitPoints < 0.3 then
						for i = 1,4 do
							local q = Isaac.Spawn(7,1,0,ent.Position,Vector(0,0),ent):ToLaser()
							q:SetTimeout(10)
							q.Angle = i * 90
							q:SetMaxDistance(100)
							q:SetColor(Color(1,1,1,1,0,0.7,1),60,99,false,false)
							q.Parent = ent
						end
					end
				end
			end
		end
		
		if s:IsPlaying("AttackDown3") then
			if s:IsEventTriggered("Shoot") then
				if d.State == 0 then
					wind.change_control(3,{ent = ent,power = math.random(3),pos_rev_del = math.random(2) * 180})
					local dir = math.random(10000)/10000 * 180
					for i = 1,10 do
						delay_buffer.addeffe(function(params)
							if params.ent and params.ent:Exists() then
								local ent = params.ent
								local q = Isaac.Spawn(9,4,0,ent.Position,auxi.MakeVector(i * 10 + dir) * 8,ent):ToProjectile()
								local q2 = Isaac.Spawn(9,4,0,ent.Position,- auxi.MakeVector(i * 10 + dir) * 8,ent):ToProjectile()
								if ent.HitPoints / ent.MaxHitPoints < 0.5 then
									q.FallingAccel = -0.06
									q2.FallingAccel = -0.06
									q.ProjectileFlags = q.ProjectileFlags | ProjectileFlags.BOUNCE
									q2.ProjectileFlags = q.ProjectileFlags | ProjectileFlags.BOUNCE
								end
							end
						end,{ent = ent,},i * 6)
					end
				elseif d.State == 1 then
					wind.change_control(3,{ent = ent,power = math.random(3),pos_rev_del = math.random(2) * 180})
					local dir = math.random(10000)/10000 * 180
					for i = 1,15 do
						delay_buffer.addeffe(function(params)
							if params.ent and params.ent:Exists() then
								local ent = params.ent
								local q = Isaac.Spawn(9,4,0,ent.Position,auxi.MakeVector(i * 10 + dir) * 15,nil):ToProjectile()
								local q2 = Isaac.Spawn(9,4,0,ent.Position,- auxi.MakeVector(i * 10 + dir) * 15,nil):ToProjectile()
								if ent.HitPoints / ent.MaxHitPoints < 0.5 then
									q.ProjectileFlags = q.ProjectileFlags | ProjectileFlags.BOUNCE
									q2.ProjectileFlags = q.ProjectileFlags | ProjectileFlags.BOUNCE
								end
							end
						end,{ent = ent,},i * 4)
					end
				elseif d.State == 2 then
					wind.change_control(3,{ent = ent,power = math.random(4),pos_rev_del = math.random(4) * 90})
					local dir = math.random(10000)/10000 * 180
					local rnd = math.random(10000)/10000 * 90
					for i = 1,5 do
						delay_buffer.addeffe(function(params)
							for i = 1,3 do
								local q = Isaac.Spawn(9,4,0,ent.Position,auxi.MakeVector(math.random(360)) * 10,ent):ToProjectile()
								q.ProjectileFlags = q.ProjectileFlags | ProjectileFlags.SMART
							end
						end,{},(i-1) * 7)
					end
				end
			end
		end
		
		if s:IsFinished("AttackDown1") then
			s:Play("Idle")
			d.move_mode = 1
			d.Should_Move = true
		end
		
		if s:IsFinished("AttackDown2") then
			s:Play("Idle")
			d.move_mode = 1
			d.Should_Move = true
		end
		
		if s:IsFinished("AttackDown3") then
			s:Play("Idle")
			d.move_mode = 1
			d.Should_Move = true
		end
		
		if s:IsFinished("AttackDown4") then
			s:Play("Idle")
			d.move_mode = 1
			d.Should_Move = true
		end
		
		if s:IsFinished("AttackSide1") then
			s:Play("Idle")
			d.move_mode = 1
			d.Should_Move = true
		end
		
		if s:IsFinished("AttackSide2") then
			s:Play("Idle")
			d.move_mode = 1
			d.Should_Move = true
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 996,	--自己写个减伤
Function = function(_,ent,amt,flag,source,cooldown)
	if ent.Variant == item.enemy then
		local s = ent:GetSprite()
		local d = ent:GetData()
		if source and (source.Type <= 8 and source.Type > 0 or (source.Type == 1000 and source.Variant == 30 or source.Variant == enums.Entities.ID_EFFECT_MeusNIL)) then		--似乎会免疫里莉莉丝的拳击
			
		else
			return false
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = 996,
Function = function(_,ent)
	local level = Game():GetLevel()
	local desc = level:GetCurrentRoomDesc()
	if ent.Variant == item.enemy then
		if save.elses.should_Zennith_spawn and save.elses.should_Zennith_spawn == true and save.elses["Zennith_room"] and save.elses["Zennith_room"] == desc.SafeGridIndex then
			--print("remove")
			local q = Isaac.Spawn(5,100,enums.Items.A_Shard_Of_Lava,ent.Position,Vector(0,0),nil):ToPickup()
			q:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
			save.elses.should_Zennith_spawn = false
			save.elses.Zennith_end = true
		end
		local pos = ent.Position
		if wind.now_hold ~= nil and wind.now_hold:Exists() then
			local language = Options.Language
			if item.Words[language] == nil then language = "zh" end
			local words = item.Words[language]
			for i = 1,30 do
				delay_buffer.addeffe(function(params)
					local level = Game():GetLevel()
					local desc = level:GetCurrentRoomDesc()
					if wind.now_hold ~= nil and wind.now_hold:Exists() then
						wind.change_control(2,{pos = pos,pos_rev_del = i * 6,power = i})
					end
					local rnd = math.random(3) + 2
					local rrnd = math.random(#words)
					for i = 1,rnd do
						local ret = auxi.random_shuffle_string(words[rrnd],Game():GetPlayer(0):GetCollectibleRNG(33))
						local wd = auxi.collect_table_to_string(ret,1,math.random(#ret))
						gui.draw_ch_with_time_to_dispair(pos,Vector((math.random(2) * 2 - 3) * (math.random(50)+30),(math.random(2) * 2 - 3) * (math.random(50)+30)),wd,math.random(40)+10)
					end
				end,{},i * 2)
			end
		end
	end
end,
})

--l local q = Isaac.Spawn(996,23751,0,Vector(400,300),Vector(0,0),nil);local s = q:GetSprite();s:ReplaceSpritesheet(0, "gfx/boss/Floraine/pawn_pieces.png");s:LoadGraphics();print(q.Mass);
--l local rnd = math.random(10) + 5;for i = 1,rnd do local q = Isaac.Spawn(9,4,0,Vector(200,200),Vector(1,1),nil):ToProjectile();q.FallingAccel = -1;	end;
return item