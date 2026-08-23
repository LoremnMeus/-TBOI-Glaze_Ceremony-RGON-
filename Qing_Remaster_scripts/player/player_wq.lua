local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local qing_s_knife_holder = require("Qing_Remaster_scripts.callbacks.qing_s_knife_holder")
local ModConfig = require("Qing_Remaster_scripts.others.Mod_Config_Menu_holder")
local grid_entity = require("Qing_Remaster_scripts.grids.grid_entity")
local Wavering_Eyes = require("Qing_Remaster_scripts.items.Item_Wavering_Eyes")
local Ice_holder = require("Qing_Remaster_scripts.mimics.Ice_holder")
local Damo_holder = require("Qing_Remaster_scripts.mimics.Damo_holder")
local Flat_Stone_holder = require("Qing_Remaster_scripts.mimics.Flat_Stone_holder")
local Isaacs_Tear_holder = require("Qing_Remaster_scripts.mimics.Isaacs_Tear_holder")
local Damage_holder = require("Qing_Remaster_scripts.mimics.Damage_holder")
local CharacterAttackCompat = require("Qing_Remaster_scripts.player.character_attack_compat")

local item = {
	pre_ToCall = {},
	ToCall = {},
	pre_myToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Players.wq,
	own_key = "Player_wq_",
	Special_Des = {
		["zh"] = {
			["Item"] = {
				[CollectibleType.COLLECTIBLE_CEREMONIAL_ROBES] = {Name = "帅气斗篷",Description = "不如换一身？",},
				[CollectibleType.COLLECTIBLE_BACKSTABBER] = {Name = "暗杀",Description = "小心你的肾！",},
				[enums.Items.Touchstone] = {Name = "名刃 · 金弑" , Description = "寸短寸强",},
				[enums.Items.Cheater_s_Blessing] = {Name = "我的帽子",Description = "大小刚刚好！",},
				[enums.Items.Assassin_s_Eye] = {Name = "我的左眼",Description = "窥见死亡！",},
				[enums.Items.My_Best_Friend] = {Name = "最好的朋友",Description = "就是我啦！",},
				[enums.Items.My_Emblem] = {Name = "我的纹章",Description = "我们有家了！",},
				[enums.Items.Chiastolite] = {Name = "名刃 · 灾心",Description = "刀莫见血",},
				[enums.Items.Seeker_s_Eye] = {Name = "我的右眼",Description = "窥见生命！",},
			},
		},
		["en"] = {
			["Item"] = {
			},
		},
	},
	open_list = {
		[51] = function(player,ent,col) 
			local d = ent:GetData()
			local s = col:GetSprite() 
			if (d.params.list.rock or 0) > 0 and (s:IsPlaying("Idle") or s:IsFinished("Idle") or s:IsFinished("Close")) then
				col:TryOpenChest()
				return true
			end
		end,
		[53] = function(player,ent,col) 
			local s = col:GetSprite() 
			if (s:IsPlaying("Idle") or s:IsFinished("Idle") or s:IsFinished("Close")) and (player:HasTrinket(19) or player:TryUseKey() == true) then
				col:TryOpenChest()
				return true
			end
		end,
		[55] = function(player,ent,col) 
			local s = col:GetSprite() 
			if (s:IsPlaying("Idle") or s:IsFinished("Idle")) and (player:HasTrinket(19) or player:TryUseKey() == true) then
				col:TryOpenChest()
				return true
			end
		end,
		[57] = function(player,ent,col) 
			local s = col:GetSprite() 
			if (s:IsPlaying("Idle") or s:IsFinished("Idle") or s:IsFinished("UseKey") or s:IsFinished("UseGoldenKey")) and (player:HasTrinket(19) or player:TryUseKey() == true) then
				if math.random(1000) > 50 then
					s:Play("Idle",true)
					if player:HasGoldenKey() == true then s:Play("UseGoldenKey",true)
					else s:Play("UseKey",true) end
				else
					col:TryOpenChest()
					return true
				end
			end
		end,
		[60] = function(player,ent,col) 
			local s = col:GetSprite() 
			if (s:IsPlaying("Idle") or s:IsFinished("Idle")) and (player:HasTrinket(19) or player:TryUseKey() == true) then
				col:TryOpenChest()
				return true
			end
		end,
		[69] = function(player,ent,col) 
			local s = col:GetSprite() 
			if s:IsPlaying("Idle") or s:IsFinished("Idle") then
				col:TryOpenChest()
				col:Remove() 
				return true
			end
		end,
	},
	attack_list = {
		[1] = {
			[0] = function(player,dir,tearHitParams,info,item,params) 
				auxi.fire_dosome_knife(params.pos or (player.Position + player.Velocity),player.Velocity + dir * 10,tearHitParams,"StabDown",{player = player,repel = dir * 10,},params)
			end,
			[1] = function(player,dir,tearHitParams,info,item,params) 
				auxi.fire_dosome_knife(params.pos or (player.Position + player.Velocity),(player.Velocity + dir * 10):Normalized()/1000,tearHitParams,"AttackUp",{player = player,Flip = auxi.random_bool(),},params)
			end,
			[2] = function(player,dir,tearHitParams,info,item,params) 
				local vel = player.Velocity + dir * 10
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)) + auxi.get_by_rotate(vel,90,60) + auxi.get_by_rotate(vel,0,-20),auxi.get_by_rotate(vel,-30),tearHitParams,"StabDown",{player = player,repel = dir * 10,},params)
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)) + auxi.get_by_rotate(vel,-90,60) + auxi.get_by_rotate(vel,0,-20),auxi.get_by_rotate(vel,30),tearHitParams,"StabDown",{player = player,repel = dir * 10,},params)
				return 2
			end,
			[3] = function(player,dir,tearHitParams,info,item,params) 
				auxi.fire_dosome_knife(params.pos or (player.Position + player.Velocity),(player.Velocity + dir * 10):Normalized()/1000,tearHitParams,"SpinUp",{player = player,dmgmul = 1/2,Flip = auxi.random_bool(),},params)
				return 3
			end,
			[4] = function(player,dir,tearHitParams,info,item,params) 
				local vel = player.Velocity + dir * 10
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)),auxi.get_by_rotate(vel,0,20 * player.ShotSpeed),tearHitParams,"IdleUp",{player = player,dmgmul = 1,thor = true,},params)
			end,
			state_trans = function(val) if val > 4 then return 0 end end,
		},
		[2] = {
			[0] = function(player,dir,tearHitParams,info,item,params) return item.attack_list[1][0] end,
			[1] = function(player,dir,tearHitParams,info,item,params) return item.attack_list[1][1] end,
			[2] = function(player,dir,tearHitParams,info,item,params) return item.attack_list[1][2] end,
			state_trans = function(val) if val > 2 then return 0 end end,
			special = function(player,dir,tearHitParams,info,item,params)
				if (params.charge or 1) > 0.5 then
					local vel = player.Velocity + dir * 10
					delay_buffer.addeffe(function(p_)
						if auxi.check_all_exists(player) then
							auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)),auxi.get_by_rotate(vel,0,20 * player.ShotSpeed),tearHitParams,"IdleUp",{player = player,dmgmul = 1,brim = true,},params)
						end
					end,{},player.MaxFireDelay * 0.2)
				end
			end,
			delaymul = 1.3,
		},
		[3] = {
			[0] = function(player,dir,tearHitParams,info,item,params) 
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)),player.Velocity + dir * 10,tearHitParams,"StabDown",{player = player,repel = dir * 10,},params)
				return 0.75
			end,
			[1] = function(player,dir,tearHitParams,info,item,params) 
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)) + auxi.get_by_rotate(dir,90,-20),player.Velocity + dir * 10,tearHitParams,"StabDown",{player = player,repel = dir * 10,dmgmul = 0.75,},params)
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)) + auxi.get_by_rotate(dir,90,20),player.Velocity + dir * 10,tearHitParams,"StabDown",{player = player,repel = dir * 10,dmgmul = 0.75,},params)
				return 1.25
			end,
			[2] = function(player,dir,tearHitParams,info,item,params) 
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)) + auxi.get_by_rotate(dir,90,-40),player.Velocity + dir * 10,tearHitParams,"StabDown",{player = player,repel = dir * 10,dmgmul = 0.5,},params)
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)) + auxi.get_by_rotate(dir,90,0),player.Velocity + dir * 10,tearHitParams,"StabDown",{player = player,repel = dir * 10,dmgmul = 0.5,},params)
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)) + auxi.get_by_rotate(dir,90,40),player.Velocity + dir * 10,tearHitParams,"StabDown",{player = player,repel = dir * 10,dmgmul = 0.5,},params)
				return 2.25
			end,
			[3] = function(player,dir,tearHitParams,info,item,params) 
				local vel = player.Velocity + dir * 10
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)),auxi.get_by_rotate(vel,120,1/1000),tearHitParams,"AttackUp",{player = player,Flip = true,},params)
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)),auxi.get_by_rotate(vel,-120,1/1000),tearHitParams,"AttackUp",{player = player,},params)
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)) + auxi.get_by_rotate(vel,45,20 * player.ShotSpeed),auxi.get_by_rotate(vel,45,1/1000),tearHitParams,"AttackUp",{player = player,Flip = true,},params)
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)) + auxi.get_by_rotate(vel,-45,20 * player.ShotSpeed),auxi.get_by_rotate(vel,-45,1/1000),tearHitParams,"AttackUp",{player = player,},params)
				--auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)) + auxi.get_by_rotate(dir,90,-60),player.Velocity + dir * 10,tearHitParams,"StabDown",{player = player,repel = dir * 10,dmgmul = 0.4,})
				--auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)) + auxi.get_by_rotate(dir,90,-20),player.Velocity + dir * 10,tearHitParams,"StabDown",{player = player,repel = dir * 10,dmgmul = 0.4,})
				--auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)) + auxi.get_by_rotate(dir,90,20),player.Velocity + dir * 10,tearHitParams,"StabDown",{player = player,repel = dir * 10,dmgmul = 0.4,})
				--auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)) + auxi.get_by_rotate(dir,90,60),player.Velocity + dir * 10,tearHitParams,"StabDown",{player = player,repel = dir * 10,dmgmul = 0.4,})
				return 1.5
			end,
			[4] = function(player,dir,tearHitParams,info,item,params) 
				local vel = player.Velocity + dir * 10
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)) + auxi.get_by_rotate(dir,90,-40) + auxi.get_by_rotate(dir,0,-30),player.Velocity + dir * 10,tearHitParams,"StabDown",{player = player,repel = dir * 10,dmgmul = 0.4,},params)
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)) + auxi.get_by_rotate(dir,90,-20) + auxi.get_by_rotate(dir,0,10),player.Velocity + dir * 10,tearHitParams,"StabDown",{player = player,repel = dir * 10,dmgmul = 0.4,},params)
				local q1 = auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)),auxi.get_by_rotate(vel,0,20 * player.ShotSpeed),tearHitParams,"IdleUp",{player = player,dmgmul = 2,thor = true,},params)
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)) + auxi.get_by_rotate(dir,90,20) + auxi.get_by_rotate(dir,0,10),player.Velocity + dir * 10,tearHitParams,"StabDown",{player = player,repel = dir * 10,dmgmul = 0.4,},params)
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)) + auxi.get_by_rotate(dir,90,40) + auxi.get_by_rotate(dir,0,-30),player.Velocity + dir * 10,tearHitParams,"StabDown",{player = player,repel = dir * 10,dmgmul = 0.4,},params)
				return 2.75
			end,
			state_trans = function(val) if val > 4 then return 0 end end,
		},
		[4] = {
			[0] = function(player,dir,tearHitParams,info,item,params) return item.attack_list[1][0] end,
			[1] = function(player,dir,tearHitParams,info,item,params) return item.attack_list[1][1] end,
			[2] = function(player,dir,tearHitParams,info,item,params) return item.attack_list[1][2] end,
			[3] = function(player,dir,tearHitParams,info,item,params) return item.attack_list[1][3] end,
			[4] = function(player,dir,tearHitParams,info,item,params) return item.attack_list[1][4] end,
			state_trans = function(val) if val > 3 then return 0 end end,
			special = function(player,dir,tearHitParams,info,item,params)
				if (params.charge or 1) > 0.5 then
					local vel = player.Velocity + dir * 10
					local cnt = ((params.list or {}).knife or 0) * 2 + 1
					delay_buffer.addeffe(function(p_)
						if auxi.check_all_exists(player) then
							for i = 1,cnt do 
								auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)) + auxi.get_by_rotate(vel,90,(i-cnt/2) * 15),auxi.get_by_rotate(vel,0,20 * player.ShotSpeed),tearHitParams,"IdleUp",{cooldown = 30,player = player,dmgmul = 1,knife = 1,},params)
							end
						end
					end,{},player.MaxFireDelay * 0.2)
				end
			end,
			delaymul = 1.4,
			delay = function(player,val) return (val + 20 * math.sqrt(player.MaxFireDelay/10))/2 end,
		},
		[5] = {
			[0] = function(player,dir,tearHitParams,info,item,params) 
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)),player.Velocity + dir * 10,tearHitParams,"StabDown",{player = player,repel = dir * 10,},params)
				return 0.5
			end,
			[1] = function(player,dir,tearHitParams,info,item,params) 
				local vel = player.Velocity + dir * 10
				local q1 = auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)),auxi.get_by_rotate(vel,0,20 * player.ShotSpeed),tearHitParams,"IdleUp",{player = player,dmgmul = 0.5,cooldown = 30,},params)
				if ((params.list or {}).brimstone or 0) > 0 and (params.charge or 1) > 0.3 then		--!!
					local cnt = params.list.brimstone
					for u,v in pairs({90,-90}) do 
						local q = player:FireBrimstone(auxi.get_by_rotate(vel,v,1))
						q.PositionOffset = Vector(0,0)
						if cnt > 1 then	q:SetTimeout(25)
						else q:SetTimeout(13) end
						q.Parent = q1
						q.Position = q1.Position
					end
				end
			end,
			[2] = function(player,dir,tearHitParams,info,item,params) 
				local vel = player.Velocity + dir * 10
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)) + auxi.get_by_rotate(vel,90,60) + auxi.get_by_rotate(vel,0,-20),auxi.get_by_rotate(vel,-30),tearHitParams,"StabDown",{player = player,repel = dir * 10,},params)
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)) + auxi.get_by_rotate(vel,-90,60) + auxi.get_by_rotate(vel,0,-20),auxi.get_by_rotate(vel,30),tearHitParams,"StabDown",{player = player,repel = dir * 10,},params)
				local q3 = player:FireBomb((params.pos or (player.Position + player.Velocity)),vel * player.ShotSpeed)
				return 0.8
			end,
			[3] = function(player,dir,tearHitParams,info,item,params) 
				for i = 1,4 do 
					local vel = auxi.get_by_rotate(player.Velocity + dir * 10,- 30 + 60/3 * (i-1),1)
					auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)),auxi.get_by_rotate(vel,0,20 * player.ShotSpeed),tearHitParams,"IdleUp",{player = player,dmgmul = 0.5,cooldown = 30,},params)
				end
				return 1.5
			end,
			state_trans = function(val) if val > 3 then return 0 end end,
		},
		[6] = {
			[0] = function(player,dir,tearHitParams,info,item,params) 
				local vel = player.Velocity + dir * 10
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)),auxi.get_by_rotate(vel,0,20),tearHitParams,"IdleUp",{player = player,repel = dir * 10,},params)
			end,
			delaymul = 4,
			state_trans = function(val) if val > 0 then return 0 end end,
		},
		[7] = {
			[0] = function(player,dir,tearHitParams,info,item,params) 
				local vel = player.Velocity + dir * 10
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)),auxi.get_by_rotate(vel,0,1/1000),tearHitParams,"AttackUp",{player = player,Flip = true,},params)
				local rnd = math.random(3) + 3
				for i = 1,rnd do
					delay_buffer.addeffe(function(p_)
						if auxi.check_all_exists(player) then
							local mul = math.random(2)
							local pos = (params.pos or (player.Position + player.Velocity))
							for i = 1,mul do 
								local gdir = auxi.RoundVector(nil,player.ShotSpeed * 80 * (i / rnd)) + vel * player.ShotSpeed * 20 * (i / rnd)
								auxi.fire_dosome_knife(pos + gdir,gdir:Normalized() * 10 * player.ShotSpeed,tearHitParams,"StabDown",{player = player,repel = gdir:Normalized() * 10,},params) 
							end
						end
					end,{},i)
				end
				return {punimul = 1,mul = 0.75,}
			end,
			[1] = function(player,dir,tearHitParams,info,item,params) 
				local vel = player.Velocity + dir * 10
				for i = -1,1 do auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)) + auxi.get_by_rotate(vel,90,i * 30),auxi.get_by_rotate(vel,i * 30),tearHitParams,"StabDown",{player = player,repel = dir * 10,},params) end
				return {punimul = 1.5,mul = 0.3,}
			end,
			[2] = function(player,dir,tearHitParams,info,item,params) 
				local vel = player.Velocity + dir * 10
				for i = -2,2 do auxi.fire_dosome_knife(params.pos or (player.Position + player.Velocity) + auxi.get_by_rotate(vel,90,i * 30),auxi.get_by_rotate(vel,i * 30):Normalized()/1000,tearHitParams,"SpinUp",{player = player,repel = dir * 10,Flip = i,},params) end
				return {punimul = 2,mul = 1,}
			end,
			[3] = function(player,dir,tearHitParams,info,item,params) 
				local vel = player.Velocity + dir * 10
				auxi.fire_dosome_knife(params.pos or (player.Position + player.Velocity),(player.Velocity + dir * 10):Normalized()/1000,tearHitParams,"SpinUp",{player = player,dmgmul = 1/2,Flip = auxi.random_bool(),},params)
				local rnd = math.random(3) + 5
				for i = 1,rnd do
					delay_buffer.addeffe(function(p_)
						if auxi.check_all_exists(player) then
							local mul = math.random(2)
							local pos = (params.pos or (player.Position + player.Velocity))
							for i = 1,mul do 
								local gdir = auxi.RoundVector(nil,player.ShotSpeed * 80 * (i / rnd)) + vel * player.ShotSpeed * 20 * (i / rnd)
								local q2 = auxi.fire_dosome_knife(pos,gdir:Normalized() * 10 * player.ShotSpeed,tearHitParams,"IdleUp",{player = player,dmgmul = 1,thor = true,Way_Accerate = dir,},params) 
							end
						end
					end,{},i)
				end
			return {mul = 3,} end,
			state_trans = function(val) if val > 3 then return 0 end end,
			delaymul = 2,
		},
		[8] = function(item) return item.attack_list[1] end,
		[9] = {
			[0] = function(player,dir,tearHitParams,info,item,params) 
				--auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)),player.Velocity + dir * 10,tearHitParams,"StabDown",{player = player,repel = dir * 10,},params)
				local cnt = math.random(3) + 3
				local vel = player.Velocity + dir * 10
				for i = 1,cnt do auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)) + auxi.get_by_rotate(dir,(i - 0.5)/cnt * 360,30),auxi.get_by_rotate(dir,(i - 0.5)/cnt * 360,10),tearHitParams,"StabDown",{player = player,repel = dir * 3,},params) end
				local q = player:FireTechXLaser((params.pos or (player.Position + player.Velocity)),vel,60)
				q.Velocity = Vector(0,0)
				q.PositionOffset = Vector(0,0)
				q:SetTimeout(10)
				return {punimul = 3,mul = 2,}
			end,
			[1] = function(player,dir,tearHitParams,info,item,params) 
				--auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)),player.Velocity + dir * 10,tearHitParams,"StabDown",{player = player,repel = dir * 10,},params)
				local vel = player.Velocity + dir * 10
				local cnt = (math.random(2) + 2) * 2
				for i = 1,cnt do auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)) + auxi.get_by_rotate(dir,(i - 0.5)/cnt * 360,30),auxi.get_by_rotate(dir,(i - 0.5)/cnt * 360,1/1000),tearHitParams,"AttackUp",{player = player,Flip = (i < cnt/2),},params) end
				local q = player:FireTechXLaser((params.pos or (player.Position + player.Velocity)),vel,60)
				q.Velocity = Vector(0,0)
				q.PositionOffset = Vector(0,0)
				q:SetTimeout(10)
				return {punimul = 4,mul = 2.5,}
			end,
			[2] = function(player,dir,tearHitParams,info,item,params) 
				local q = player:FireTechXLaser((params.pos or (player.Position + player.Velocity)) + (player.Velocity + dir * 10) * 4,player.Velocity + dir * 10,30)
				q.PositionOffset = Vector(0,0)
				q:SetTimeout(math.floor(player.ShotSpeed) * 10)
				local cnt = math.random(6) + 6
				for i = 1, cnt do
					local vel = player.Velocity + dir * 10 + auxi.get_by_rotate(dir,(i - 0.5)/cnt * 360,10)
					local q1 = auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)) + auxi.get_by_rotate(dir,(i - 0.5)/cnt * 360,30),vel,tearHitParams,"IdleUp",{player = player,},params)
					local d2 = q1.Parent:GetData()
					d2.follower = q
					d2.continue_after_follower = true
					d2.continue_and_resetvel = vel
				end
				return 6.5
			end,
			state_trans = function(val) if val > 2 then return 0 end end,
		},
		[10] = {
			[0] = function(player,dir,tearHitParams,info,item,params) 
				local n_enemy = auxi.getenemies()
				local posi = Game():GetRoom():GetClampedPosition(player.Position + dir:Normalized() * 300,0)
				if #n_enemy > 0 then
					local tg = nil
					for i = 1,#n_enemy do
						local lg = (n_enemy[i].Position - player.Position):Length()
						local the = (n_enemy[i].Position - player.Position):GetAngleDegrees() - dir:GetAngleDegrees()
						local cal = math.cos(math.rad(the)) * lg
						if cal > 0 and (tg or 99999) > cal then
							tg = cal
							posi = n_enemy[i].Position
						end
					end
				end
				auxi.kill_them_all(player,posi,player.Damage * 0.5)
				auxi.kill_them_all(player,posi,player.Damage * 1.5,7,150)
				return {punimul = 4.5,mul = 0.5,}
			end,
			[1] = function(player,dir,tearHitParams,info,item,params) return {punimul = 5,mul = 0.5,special = item.attack_list[1][1],} end,
			[2] = function(player,dir,tearHitParams,info,item,params) return {punimul = 0,mul = 6,special = item.attack_list[1][3],} end,
			state_trans = function(val) if val > 2 then return 0 end end,
		},
		[13] = {
			[0] = function(player,dir,tearHitParams,info,item,params) 
				local vel = player.Velocity + dir * 10
				auxi.fire_dosome_knife(params.pos or (player.Position + player.Velocity),(player.Velocity + dir * 10):Normalized()/1000,tearHitParams,"SpinUp",{player = player,dmgmul = 1/3,Flip = auxi.random_bool(),},params)
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)),auxi.get_by_rotate(vel,0,20 * player.ShotSpeed),tearHitParams,"IdleUp",{player = player,dmgmul = 1,thor = true,},params)
				return 2
			end,
			[1] = function(player,dir,tearHitParams,info,item,params) 
				local cnt = math.random(2) + 2
				for i = 1,cnt do 
					auxi.fire_dosome_knife(params.pos or (player.Position + player.Velocity),auxi.get_by_rotate(player.Velocity + dir * 10,(i - cnt/2) * 20),tearHitParams,"SpinUp",{player = player,dmgmul = 1/3,Flip = auxi.random_bool(),},params)
				end
				return {punimul = 4,mul = 1,}
			end,
			[2] = function(player,dir,tearHitParams,info,item,params)
				local vel = player.Velocity + dir * 10
				local cnt = math.random(2) + 2
				for i = 1,cnt do 
					auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)),auxi.get_by_rotate(vel,(i - cnt/2) * 20,20 * player.ShotSpeed),tearHitParams,"IdleUp",{player = player,dmgmul = 1,thor = true,},params)
				end
				return 4
			end,
			[3] = function(player,dir,tearHitParams,info,item,params) end,
			state_trans = function(val,list) 
				if (list.knife or 0) > 0 then 
					if val > 2 then return 0 end
				else
					if val > 0 then return 0 end
				end
			end,
		},
		[14] = {
			[0] = function(player,dir,tearHitParams,info,item,params) return item.attack_list[1][0] end,
			[1] = function(player,dir,tearHitParams,info,item,params) return item.attack_list[1][1] end,
			[2] = function(player,dir,tearHitParams,info,item,params) return item.attack_list[1][2] end,
			[3] = function(player,dir,tearHitParams,info,item,params) return item.attack_list[1][3] end,
			[4] = function(player,dir,tearHitParams,info,item,params) return item.attack_list[1][4] end,
			state_trans = function(val) if val > 4 then return 0 end end,
			delaymul = 1.8,
		},
		[15] = {
			[0] = function(player,dir,tearHitParams,info,item,params) 
				local vel = player.Velocity + dir * 10
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)),auxi.get_by_rotate(vel,0,20 * player.ShotSpeed),tearHitParams,"IdleUp",{player = player,dmgmul = 1,thor = true,},params)
				return {punimul = 0.5,mul = 0.7,}
			end,
			[1] = function(player,dir,tearHitParams,info,item,params) 
				local vel = player.Velocity + dir * 10
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)),auxi.get_by_rotate(vel,30,20 * player.ShotSpeed),tearHitParams,"IdleUp",{player = player,dmgmul = 1,thor = true,Way_Accerate = auxi.get_by_rotate(vel,-60,1),},params)
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)),auxi.get_by_rotate(vel,-30,20 * player.ShotSpeed),tearHitParams,"IdleUp",{player = player,dmgmul = 1,thor = true,Way_Accerate = auxi.get_by_rotate(vel,60,1),},params)
				return {punimul = 1,mul = 1,}
			end,
			[2] = function(player,dir,tearHitParams,info,item,params) 
				local vel = player.Velocity + dir * 10
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)),auxi.get_by_rotate(vel,0,20 * player.ShotSpeed),tearHitParams,"IdleUp",{player = player,dmgmul = 1,thor = true,},params)
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)),auxi.get_by_rotate(vel,60,1/1000),tearHitParams,"AttackUp",{player = player,},params)
				auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)),auxi.get_by_rotate(vel,-60,1/1000),tearHitParams,"AttackUp",{player = player,Flip = true,},params)
				return {punimul = 2,mul = 0.5,}
			end,
			[3] = function(player,dir,tearHitParams,info,item,params) 
				local vel = player.Velocity + dir * 10
				auxi.fire_dosome_knife(params.pos or (player.Position + player.Velocity),auxi.get_by_rotate(vel,30),tearHitParams,"SpinUp",{player = player,dmgmul = 1/3,Flip = auxi.random_bool(),Way_Accerate = auxi.get_by_rotate(vel,-60,1),},params)
				auxi.fire_dosome_knife(params.pos or (player.Position + player.Velocity),auxi.get_by_rotate(vel,-30),tearHitParams,"SpinUp",{player = player,dmgmul = 1/3,Flip = auxi.random_bool(),Way_Accerate = auxi.get_by_rotate(vel,60,1),},params)
				return 3
			end,
			state_trans = function(val) if val > 3 then return 0 end end,
			delaymul = 0.5,
		},
		["GreedHead"] = function(player,dir,tearHitParams,info,item,params) 
			local vel = player.Velocity + dir * 10
			player:AddCoins(-1)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_CASH_REGISTER,1,1,false,0,2)
			auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)) + auxi.get_by_rotate(vel,90,20 * auxi.random_0()),auxi.get_by_rotate(vel,0,20 * player.ShotSpeed),tearHitParams,"IdleUp",{player = player,dmgmul = 1,},params)
		end,
		["IdleUp"] = function(player,dir,tearHitParams,info,item,params) 
			local vel = player.Velocity + dir * 10
			auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)) + auxi.get_by_rotate(vel,90,20 * auxi.random_0()),auxi.get_by_rotate(vel,0,20 * player.ShotSpeed),tearHitParams,"IdleUp",{player = player,dmgmul = 1,},params)
		end,
		["Tech.5"] = function(player,dir,tearHitParams,info,item,params) 
			local vel = player.Velocity + dir * 10
			local q = auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)),auxi.get_by_rotate(vel,0,20 * player.ShotSpeed),tearHitParams,"IdleUp",{player = player,dmgmul = 1,},params)
			local d = q:GetData()
			local q2 = player:FireTechLaser(player.Position,1,-(player.Velocity + dir * 10),false,false,nil,0.5)
			q2.PositionOffset = Vector(0,0)
			q2:GetData().followParent = q
			q2:SetTimeout(13)
			local buff_list = {BitSet128(1<<2,0),BitSet128(1<<16,0),BitSet128(1<<30,0),BitSet128(1<<19,0),BitSet128(1<<33,0),BitSet128(0,1<<5)}
			for i = 1,6 do if math.random(1000) > 800 then q2:AddTearFlags(buff_list[i]) end end
			table.insert(d[item.own_key.."holder"],{ent = q2,adder = 180,})
		end,
		["Tech2"] = function(player,dir,tearHitParams,info,item,params) 
			local vel = player.Velocity + dir * 10
			local q = auxi.fire_dosome_knife((params.pos or (player.Position + player.Velocity)),auxi.get_by_rotate(vel,0,20 * player.ShotSpeed),tearHitParams,"IdleUp",{cooldown = 10,player = player,dmgmul = 1,},params)
			local d = q:GetData()
			local q2 = player:FireTechLaser(player.Position,1,-(player.Velocity + dir * 10),false,false,nil,0.2)
			q2:SetTimeout(10)
			q2.PositionOffset = Vector(0,0)
			q2:GetData().followParent = q
			table.insert(d[item.own_key.."holder"],{ent = q2,adder = 180,})
			return {ent = q,}
		end,
	},
	sec_trans = {
		["StabDown"] = true,
		["IdleUp"] = true,
		["AttackUp"] = true,
		["AttackUp2"] = true,
		["SpinUp"] = true,
		["SpinUp2"] = true,
	},
	replay_anim = {
		["StabDown"] = "StabDown",
		["ChargedDown"] = "ChargedDown",
		["NoChargedDown"] = "NoChargedDown",
		["ChargedFall"] = "ChargedDown",
		["NoChargedFall"] = "NoChargedDown",
	},
}

function item.repel_self(player,ent,dir)
	local d = ent:GetData()
	local d2 = player:GetData()
	--print("Added "..(dir * (d[item.own_key.."Repel"] or 1) * (d2[item.own_key.."Repel"] or 1) * 0.3):Length().." with "..dir:Length())
	local tg = player
	if auxi.check_all_exists(d2[item.own_key.."Ludo_Mark"]) then tg = d2[item.own_key.."Ludo_Mark"] end
	tg:AddVelocity(dir * (d[item.own_key.."Repel"] or 1) * (d2[item.own_key.."Repel"] or 1) * 0.3)
	d[item.own_key.."Repel"] = (d[item.own_key.."Repel"] or 1) * 0.6
	d2[item.own_key.."Repel"] = (d2[item.own_key.."Repel"] or 1) * 0.6
end

function item.try_set_touched(ent)
	local d = ent:GetData()
	if d[item.own_key.."Touched"] ~= true and ent.Parent then
		d[item.own_key.."Touched"] = true
		local d2 = ent.Parent:GetData()
		d2.Params = d2.Params or {}
		d2.Params.FollowInput = nil
		d2.Params.Accerate = -1
		d2.Params.Homing = false
		d2.Accerate_flag = true
	end
end

function item.trigger_epic_effect(ent,col,params)
	ent.Parent.Velocity = ent.Parent.Velocity:Normalized() * 3
	local s = ent:GetSprite()
	if s:IsPlaying("IdleUp") or s:IsFinished("IdleUp") then s:Play("ChargedUp",true) end
	local d2 = ent.Parent:GetData()
	d2.Params = d2.Params or {}
	d2.Params.FollowInput = nil
	d2.Params.Accerate = -1
	d2.Params.Homing = false
	d2.Accerate_flag = true
	local q = auxi.launch_Missile(ent.Position,Vector(0,0),nil,ent,{color = ent.Color,Cooldown = 25,player = player,scale = ent:GetSprite().Scale,invisible = true,targ = col,})
	return q
end

function item.trigger_explosive_effect(ent,player,pos,damage)
	local d = ent:GetData()
	local s = ent:GetSprite()
	local tearflags = d[item.own_key.."Explosive_Flag"] or BitSet128(0,0)
	local dmgself = d[item.own_key.."Explosive_DMG_self"]
	Game():BombExplosionEffects(pos,damage * 5,tearflags,ent.Color,player,s.Scale:Length()/math.sqrt(2),false,dmgself)	
	d[item.own_key.."Explosive_cnt"] = d[item.own_key.."Explosive_cnt"] - 1
end

function item.switch_thor(ent,player)
	local d = ent:GetData()
	local s = ent:GetSprite()
	local d3 = player:GetData()
	if auxi.check_all_exists(d3.thor_target) then 
		local e3 = d3.thor_target.Child
		if e3 then
			e3:GetData().should_renew_charge = nil
			e3:GetData().should_clear_charge = true
			local s3 = e3:GetSprite()
			local name = s3:GetAnimation()
			if name == "ChargedUp" or name == "ChargedDown" then s3:Play("No"..name,true) end
		end
		if (d.params.list.link_knife or 0) > 0 then d.link_thor = d3.thor_target end
	end
	d3.thor_target = ent.Parent
	if d.tearflags & BitSet128(1<<57,0) == BitSet128(1<<57,0) and not d.linked_zero then
		d.linked_zero = true
		if auxi.check_all_exists(d3.last_zero_knife) then d3.last_zero_knife:GetData().last_zero_target = ent end
		d3.last_zero_knife = ent
	end
	s:Play("ChargedUp",true)
	item.try_set_touched(ent)
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
		save.elses.Qing_ludo_buff = save.elses.Qing_ludo_buff or {}
		save.elses.Qing_knife_buff = save.elses.Qing_knife_buff or {}
	else
		save.elses.Qing_ludo_buff = {}
		save.elses.Qing_knife_buff = {}
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_EVERY_ENTITY_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if (d[item.own_key.."counter"] or 0) > 0 then d[item.own_key.."counter"] = d[item.own_key.."counter"] - 1 end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	item._room_epoch = (item._room_epoch or 0) + 1
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.MeusLink,
Function = function(_,ent)
	local room = Game():GetRoom()
	local level = Game():GetLevel()
	local d = ent:GetData()
	local s = ent:GetSprite()
	if ent.Variant == enums.Entities.MeusLink then
		if s:IsFinished("Link") or s:IsFinished("Link2") then
			ent:Remove()
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	if d[item.own_key.."room_epoch"] ~= (item._room_epoch or 0) then
		d[item.own_key.."room_epoch"] = item._room_epoch or 0
		d[item.own_key.."Ludo_pos"] = nil
	end
	if player:GetPlayerType() == item.entity then
		if Game():GetFrameCount() % (30 * 5) == 1 and player.CanFly ~= true and player.GridCollisionClass ~= EntityGridCollisionClass.GRIDCOLL_NONE then
			d[item.own_key.."Kept"] = (auxi.check_path_to_door(player.Position) and auxi.has_door())
		end
	end
	d[item.own_key.."Repel"] = (d[item.own_key.."Repel"] or 1) * 0.98 + 1 * 0.02
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_REASSIGN_IMITATE_ITEM, params = nil,
Function = function(_,player)
	if player:GetPlayerType() == item.entity then
		local d = player:GetData()
		d.Qing_list = auxi.get_qing_list(player)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	local d = player:GetData()
	if player:GetPlayerType() == item.entity then
		if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
			d[item.own_key.."cursed_counter"] = d[item.own_key.."cursed_counter"] or 0
			Charging_Bar_holder.render_me(player,{name1 = "Qing_cursed",name2 = "Qing_cursed",name3 = "Qing_cursed",loadname = "gfx/effects/chargebar/chargebar_Qing_cursed.anm2",
				check1 = function(val,ent)
					return d[item.own_key.."cursed_counter"] >= 0.01
				end,
				check2 = function(val,ent)
					return d[item.own_key.."cursed_counter"] >= 5
				end,
				check3 = function(val,ent)
					return math.ceil(d[item.own_key.."cursed_counter"]/5 * 100)
				end,
				signal1 = function(ent) end,
			})
			d[item.own_key.."Cho_counter"] = d[item.own_key.."Cho_counter"] or 0
			Charging_Bar_holder.render_me(player,{name1 = "Qing_Cho",name2 = "Qing_Cho",name3 = "Qing_Cho",loadname = "gfx/effects/chargebar/chargebar_Qing_Cho.anm2",
				check1 = function(val,ent)
					return d[item.own_key.."Cho_counter"] >= 0.01
				end,
				check2 = function(val,ent)
					return d[item.own_key.."Cho_counter"] >= 1
				end,
				check3 = function(val,ent)
					return math.ceil(d[item.own_key.."Cho_counter"] * 100)
				end,
				signal1 = function(ent) end,
			})
			d[item.own_key.."Nep_counter"] = d[item.own_key.."Nep_counter"] or 0
			Charging_Bar_holder.render_me(player,{name1 = "Qing_Nep",name2 = "Qing_Nep",name3 = "Qing_Nep",loadname = "gfx/effects/chargebar/chargebar_Qing_Nep.anm2",
				check1 = function(val,ent)
					return d[item.own_key.."Nep_counter"] >= 0.01
				end,
				check2 = function(val,ent)
					return d[item.own_key.."Nep_counter"] >= 1
				end,
				check3 = function(val,ent)
					return math.ceil(d[item.own_key.."Nep_counter"] * 100)
				end,
				signal1 = function(ent) end,
			})
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if player:GetPlayerType() == item.entity then
		local room = Game():GetRoom()
		local level = Game():GetLevel()
		local d = player:GetData()
		local ctrlidx = player.ControllerIndex
		local gdir = auxi.ggdir(player,false,ModConfig.ModConfigSettings.allow_mouse_control)
		local list = d.Qing_list or auxi.get_qing_list(player)
		if player:AreControlsEnabled() and player:IsExtraAnimationFinished() and (auxi.check_bottom_down(ModConfig.ModConfigSettings.thor_key,ctrlidx) or auxi.check_bottom_down(ModConfig.ModConfigSettings.thor_controller,ctrlidx) or (ModConfig.ModConfigSettings.allow_mouse_control and Input.IsMouseBtnPressed(1))) then		--按下alt时，使用瞬移。
			if auxi.check_all_exists(d.thor_target) ~= true and auxi.check_all_exists(d[item.own_key.."Ludo_Mark"]) and (d[item.own_key.."Ludo_Mark"].Position - player.Position):Length() > 75 then
				d.thor_target = d[item.own_key.."Ludo_Mark"]
				d[item.own_key.."Ludo_Mark"] = nil
				d[item.own_key.."Ludo_pos"] = nil
			end
			if auxi.check_all_exists(d.thor_target) then
				d.birth_delay = d.birth_delay or 0
				if player:HasCollectible(619) and d.birth_delay <= 0 then
					auxi.kill_them_all(player,d.thor_target.Position,player.Damage * 0.25)
					auxi.kill_them_all2(player,d.thor_target.Position,player.Damage * 0.75,15,200)
					d.birth_delay = 150
					d.thor_target:Remove()
					d.thor_target = nil
				else
					auxi.thor_attack(player,list)
					local new_thor = nil
					if list.link_knife and list.link_knife > 0 then
						if d.thor_target.Child then
							new_thor = d.thor_target.Child:GetData().link_thor
							if new_thor then
								if new_thor:Exists() == false or new_thor:IsDead() or not new_thor.Child or not new_thor.Child:Exists() or new_thor.Child:IsDead() then 
									new_thor = nil 
								else
									new_thor.Child:GetData().should_renew_charge = true
									new_thor.Child:GetData().should_clear_charge = nil
								end
							end
						end
					end
					d.thor_target:Remove()
					d.thor_target = new_thor
				end
			elseif player:HasCollectible(619) and player:GetData().birth_delay < 0 then -- and player:GetData().Birth_Flag and player:GetData().Birth_Flag == true then
				local n_entity = Isaac.GetRoomEntities()
				local n_enemy = auxi.getenemies(n_entity)
				local posi = room:GetRandomPosition(10)
				local wait = false
				if #n_enemy > 0 then
					if gdir:Length() < 0.05 then
						posi = n_enemy[math.random(#n_enemy)].Position
					else
						posi = player.Position + gdir * 100
						for i = 1,#n_enemy do
							local lg = (n_enemy[i].Position - player.Position):Length()
							local the = (n_enemy[i].Position - player.Position):GetAngleDegrees()
							local cal = math.sin(math.rad(the)) * lg
							if cal > -10 and (player:GetData().birthright_counter == nil or player:GetData().birthright_counter > cal) then
								player:GetData().birthright_counter = cal
								posi = n_enemy[i].Position
								wait = true
							end
							player:GetData().birthright_counter = nil
						end
					end
				else
					if gdir:Length() > 0.05 then
						posi = player.Position + gdir * 100
					end
				end
				auxi.kill_them_all(player,posi,0)
				if wait == true then
					auxi.kill_them_all2(player,posi,player.Damage/2,10,150)
					player:GetData().birth_delay = 150
				else
					player:GetData().birth_delay = 30
				end
			end
		end
		if d[item.own_key.."Thor"] then gdir = Vector(0,0) end
		
		if player:HasCollectible(619) then d.birth_delay = math.max(0,(d.birth_delay or 0) - 1) end
		d[item.own_key.."Delay"] = math.min(1800,math.max(0,d[item.own_key.."Delay"] or 0) - 1)
		d[item.own_key.."State"] = d[item.own_key.."State"] or 0
		if (d[item.own_key.."cursed"] or 0) == -1 then
			d[item.own_key.."cursed_counter"] = d[item.own_key.."Delay"]/(d[item.own_key.."Mx_cursed_counter"] or 1) * 5
			if d[item.own_key.."Delay"] <= 0 then
				d[item.own_key.."cursed_counter"] = 0
				d[item.own_key.."cursed"] = 0
			end
		end
		if gdir:Length() < 0.05 then
			d[item.own_key.."State"] = 0
			if (d[item.own_key.."Delay_Puni"] or 0) > 0 then
				d[item.own_key.."Delay"] = d[item.own_key.."Delay"] + d[item.own_key.."Delay_Puni"]
				d[item.own_key.."Delay_Puni"] = nil
			end
			if (d[item.own_key.."cursed"] or 0) > 0 then
				d[item.own_key.."Delay"] = d[item.own_key.."Delay"] + 1.2 * d[item.own_key.."cursed"]
				d[item.own_key.."cursed"] = -1
				d[item.own_key.."Mx_cursed_counter"] = d[item.own_key.."Delay"]
			end
			if player:HasCollectible(69) then 
				if d[item.own_key.."State"] == 0 and d[item.own_key.."Delay"] <= 0 then
					d[item.own_key.."Cho_counter"] = math.min(1,(d[item.own_key.."Cho_counter"] or 0) + 0.005)
				end
			else d[item.own_key.."Cho_counter"] = nil end
			if player:HasCollectible(597) then
				if d[item.own_key.."Delay"] <= 0 then
					d[item.own_key.."Nep_counter"] = math.min(1,(d[item.own_key.."Nep_counter"] or 0) + 0.008)
				end
			else d[item.own_key.."Nep_counter"] = nil end
		else
			if player:HasCollectible(597) and d[item.own_key.."Delay"] > 2 then
				d[item.own_key.."Delay"] = d[item.own_key.."Delay"] * (1 - d[item.own_key.."Nep_counter"])
				d[item.own_key.."Nep_counter"] = d[item.own_key.."Nep_counter"] * 0.8
			end
			if player:HasCollectible(316) then
				if (d[item.own_key.."cursed_counter"] or 0) < 5 and (d[item.own_key.."cursed"] or 0) >= 0 then
					if d[item.own_key.."Delay"] >= 2 then
						d[item.own_key.."cursed_counter"] = (d[item.own_key.."cursed_counter"] or 0) + 1
						d[item.own_key.."cursed"] = (d[item.own_key.."cursed"] or 0) + d[item.own_key.."Delay"]
						d[item.own_key.."Delay"] = 2
					end
				elseif (d[item.own_key.."cursed"] or 0) > 0 then
					d[item.own_key.."Delay"] = d[item.own_key.."Delay"] + 1.2 * d[item.own_key.."cursed"]
					d[item.own_key.."cursed"] = -1
					d[item.own_key.."Mx_cursed_counter"] = d[item.own_key.."Delay"]
				end
			end
			if player:HasCollectible(69) and d[item.own_key.."State"] == 0 then
				if d[item.own_key.."Delay"] <= 0 then
					d[item.own_key.."Charge"] = (d[item.own_key.."Charge"] or 1) * ((d[item.own_key.."Cho_counter"] or 0) + 1)
					d[item.own_key.."Cho_counter"] = 0
				end
				if d[item.own_key.."Delay"] > 0 and d[item.own_key.."MaxDelay"] then
					d[item.own_key.."Charge"] = (d[item.own_key.."MaxDelay"] - d[item.own_key.."Delay"])/d[item.own_key.."MaxDelay"]
					d[item.own_key.."Delay"] = 0	
				end
			end
			if (list.ludo or 0) > 0 then d[item.own_key.."Ludo_pos"] = room:GetClampedPosition((d[item.own_key.."Ludo_pos"] or player.Position) + gdir * 5 * player.ShotSpeed,0)
			else d[item.own_key.."Ludo_pos"] = nil end
		end
		if d[item.own_key.."Ludo_pos"] then 
			if auxi.check_all_exists(d[item.own_key.."Ludo_Mark"]) ~= true then 
				local q = auxi.fire_nil(d[item.own_key.."Ludo_pos"],Vector(0,0),{cooldown = 60000,})
				local d2 = q:GetData()
				d2.Is_Qing_Fetus = true
				local tearHitParams = player:GetTearHitParams(WeaponType.WEAPON_TEARS,1,auxi.choose(0,1))
				d2.fetus_scale = Vector(1,1) * tearHitParams.TearScale
				d[item.own_key.."Ludo_Mark"] = q
			end
			local d2 = d[item.own_key.."Ludo_Mark"]:GetData()
			d2.Params = d2.Params or {}
			d2.Params.target_pos = d[item.own_key.."Ludo_pos"]
		elseif d[item.own_key.."Ludo_Mark"] then d[item.own_key.."Ludo_Mark"]:GetData().removecd = 1 d[item.own_key.."Ludo_Mark"] = nil end
		if Input.IsActionTriggered(ButtonAction.ACTION_DROP,ctrlidx) or Input.IsActionPressed(ButtonAction.ACTION_DROP,ctrlidx) then d[item.own_key.."Ludo_pos"] = nil end 
		if (d[item.own_key.."Delay"] or 0) <= 0 and gdir:Length() > 0.05 then		--发动攻击
			local weap = auxi.get_weapon(player)
			if player:HasCollectible(258) then weap = auxi.choose(1,2,3,4,5,6,7,9,13,14,15) end -- auxi.choose(1,2,3,4,5,6,7,9,13,14,15) end		--编号错误
			if player:HasCollectible(191) then		--三美刀		--!!
				if d[item.own_key.."ThreeDoll"] == nil or (d[item.own_key.."State"] == 1) then
					d[item.own_key.."ThreeDoll"] = auxi.choose(1,2,3,4,5,6,7,9,13,14,15)
				end
				weap = d[item.own_key.."ThreeDoll"]
			end
			local attack_params = auxi.get_Qing_multishots(player,list)
			for i = #attack_params,1,-1 do
				local info = attack_params[i]
				local dir = auxi.MakeVector(info.dir + gdir:GetAngleDegrees()) * math.max(0.6,math.min(3,0.7 * player.ShotSpeed + 0.3 + math.log(player.TearRange/260)))
				if player:HasCollectible(418) and math.random(1000) > 800 then weap = auxi.choose(1,2,3,4,5,6,7,9,13,14,15) end		--水果蛋糕
				if list.tech9 > 0 then 
					if math.random(1000) > 850 then weap = 3 end
					if math.random(1000) > 850 then weap = 9 end
				end
				if (weap == 1) and list.hae > 0 then weap = 15 end			--血泪
				
				local weap_listinfo = (auxi.check_if_any(item.attack_list[weap],item) or item.attack_list[1])
				d[item.own_key.."State"] = auxi.check_if_any(weap_listinfo.state_trans,d[item.own_key.."State"],list) or d[item.own_key.."State"]
				local weapinfo = item.attack_list[info.Anim] or weap_listinfo[d[item.own_key.."State"]] or item.attack_list[1][0]
				local tearHitParams = player:GetTearHitParams(WeaponType.WEAPON_TEARS,1,auxi.choose(0,1))
				local attack_call_params = {tearflag = info.tearflag,color = info.color,state = d[item.own_key.."State"],weap = weap,list = list,charge = (d[item.own_key.."Charge"] or 1),pos = (d[item.own_key.."Ludo_Mark"] or {}).Position,}
				local ret = auxi.check_if_any(weapinfo,player,dir,tearHitParams,weapinfo,item,attack_call_params) or {delay = player.MaxFireDelay,}
				-- 高级宝宝统一通过角色 Provider 复制本次已确认的真实攻击。
				local CharacterFamiliars = require("Qing_Remaster_scripts.mimics.Character_Advanced_Familiars_holder")
				CharacterFamiliars.dispatch_registered_copies(player, {
					aim_dir = dir,
					damage_mul = tonumber(attack_call_params.dmgmul) or 1,
				})
				if type(ret) == "number" then ret = {mul = ret,} end
				if ret.special then auxi.check_if_any(ret.special,player,dir,tearHitParams,ret.special,item,{tearflag = info.tearflag,color = info.color,state = d[item.own_key.."State"],weap = weap,list = list,charge = (d[item.own_key.."Charge"] or 1),pos = (d[item.own_key.."Ludo_Mark"] or {}).Position,}) end
				if weap_listinfo.special then auxi.check_if_any(weap_listinfo.special,player,dir,tearHitParams,ret.special,item,{tearflag = info.tearflag,color = info.color,state = d[item.own_key.."State"],weap = weap,list = list,charge = (d[item.own_key.."Charge"] or 1),pos = (d[item.own_key.."Ludo_Mark"] or {}).Position,}) end
				if i == 1 then
					d[item.own_key.."State"] = ret.state or (d[item.own_key.."State"] + 1)
					d[item.own_key.."Delay"] = ret.delay or (player.MaxFireDelay * (ret.mul or 1)) * (auxi.check_if_any(weap_listinfo.delaymul,player) or 1) 
					d[item.own_key.."Delay"] = auxi.check_if_any(weap_listinfo.delay,player,d[item.own_key.."Delay"]) or d[item.own_key.."Delay"]
					d[item.own_key.."MaxDelay"] = d[item.own_key.."Delay"]
					d[item.own_key.."Delay_Puni"] = auxi.check_if_any((ret.punimul or 0) * player.MaxFireDelay)
				end
			end
			d[item.own_key.."Charge"] = nil
			Isaacs_Tear_holder.add_tear(player)
			do
				local ok, EvilEye = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Evil_Eye_holder")
				if ok and EvilEye and EvilEye.notify_player_attack then
					EvilEye.notify_player_attack(player, gdir)
				end
			end
		end
		if player:HasCollectible(152) then		--科技2
			if gdir:Length() > 0.05 and auxi.check_all_exists(d[item.own_key.."Tech2"]) ~= true then
				local weapinfo = item.attack_list["Tech2"]
				local tearHitParams = player:GetTearHitParams(WeaponType.WEAPON_TEARS,1,auxi.choose(0,1))
				local ret = auxi.check_if_any(weapinfo,player,gdir,tearHitParams,weapinfo,item,{state = d[item.own_key.."State"],weap = weap,list = list,charge = 1,}) or {delay = player.MaxFireDelay,}
				d[item.own_key.."Tech2"] = ret.ent
			end
		end
		if gdir:Length() > 0.05 and player:HasCollectible(244) then		--科技.5
			if math.random(1000) > 950 and d[item.own_key.."Delay"]/2 > math.random(math.floor(player.MaxFireDelay) + 1) then
				local weapinfo = item.attack_list["Tech.5"]
				local tearHitParams = player:GetTearHitParams(WeaponType.WEAPON_TEARS,1,auxi.choose(0,1))
				local ret = auxi.check_if_any(weapinfo,player,gdir,tearHitParams,weapinfo,item,{state = d[item.own_key.."State"],weap = weap,list = list,charge = 1,}) or {delay = player.MaxFireDelay,}
			end
		end
	end
end,
})

function item.dealt_extra_effect_to_col(ent,col,tp)
	local d = ent:GetData()
	local s = ent:GetSprite()
	local player = CharacterAttackCompat.resolve_entity_player(ent, d.player)
	if not player then return end
	if d.tearflags and auxi.isenemies(col) then Damage_holder.damage_with(player,col,{Luck = player.luck,dmg = dmg,tearflags = d.tearflags,tearcolor = player.TearColor,player = player,Qing = true,}) end
end

table.insert(item.pre_myToCall,#item.pre_myToCall + 1,{CallBack = enums.Callbacks.PRE_QINGS_KNIFE_COLLISION, params = nil,
Function = function(_,ent,col,tp)
	col = auxi.illustrate_ent(col)
	local d = ent:GetData()
	local d2 = col:GetData()
	local s = ent:GetSprite()
	local s2 = col:GetSprite()
	if not ent.Parent then return end
	local damage = d.damage or ent.CollisionDamage
	local damageflag = d.damageflag or 0
	d.params = d.params or {}
	d.params.list = d.params.list or {}
	local player = CharacterAttackCompat.resolve_entity_player(ent, d.params.player or d.player)
	if not player then return end
	local d3 = player:GetData()
	if Game():GetRoom():GetFrameCount() <= 0 then return end
	if col.IsGrid then
		local grid = col:get_grid()
		if tp == "Idle" or d.inner_frame % 8 == 4 then
			if d.params.no_grid ~= true then grid:Hurt(1) end
			if (d.params.list.sulfur or 0) > 0 then
				if auxi.check_rand(player.Luck,50,20,6) then auxi.try_destroy_grid(grid,1) end
			end
			if (d.params.list.rock or 0) > 0 and auxi.check_rand(player.Luck,80,40,4) then
				local succ = auxi.try_destroy_grid(grid,2)
				if succ then
					delay_buffer.addeffe(function(params)
						sound_tracker.PlayStackedSound(SoundEffect.SOUND_STONE_IMPACT,math.random(1000)/1000 * 0.2 + 0.9,math.random(1000)/1000 * 0.1 + 0.95,false,0,2)
					end,{},1)
				end
			end
			if (d[item.own_key.."Explosive_cnt"] or 0) > 0 and auxi.issolid(grid) then item.trigger_explosive_effect(ent,player,col:Position(),damage) end
		end
		if tp == "Idle" then
			local room = Game():GetRoom()
			if grid:GetType() == GridEntityType.GRID_WALL then
				if d.params.thor and (d3[item.own_key.."Thor"] ~= true) and (d.params.follow_hae or d3[item.own_key.."Kept"]) and auxi.check_all_exists(d3.thor_target) ~= true and d.has_thor ~= true and d[item.own_key.."Touched"] ~= true then 
					d3[item.own_key.."Kept"] = nil
					d.has_thor = true 
					item.switch_thor(ent,player)
					ent.Parent.Velocity = ent.Parent.Velocity:Normalized() * 5
					ent.Parent.Position = ent.Parent.Position * 0.8 + room:GetGridPosition(grid:GetGridIndex()) * 0.2
					if room:GetGridIndex(ent.Parent.Position) ~= grid:GetGridIndex() then delay_buffer.addeffe(function(params) if auxi.check_all_exists(ent) and auxi.check_all_exists(ent.Parent) then ent.Parent.Position = ent.Parent.Position * 0.7 + room:GetGridPosition(grid:GetGridIndex()) * 0.3 end end,{},1) end
					d[item.own_key.."should_fall"] = true
					d[item.own_key.."FallRot"] = auxi.find_rot_dir(grid:GetGridIndex())
				elseif d.tearflags & BitSet128(1<<19,0) == BitSet128(1<<19,0) and d[item.own_key.."Bounce"] ~= true then
					d[item.own_key.."Bounce"] = true
					local dir = auxi.find_rot_dir(grid:GetGridIndex()) - 180 - ent.Parent.Velocity:GetAngleDegrees()
					ent.Parent.Velocity = auxi.get_by_rotate(ent.Parent.Velocity,2 * dir,ent.Parent.Velocity:Length() * 0.3)
				end
			end
		end
		return
	end
	if auxi.isenemies(col) then
		if d.params.no_repel ~= true then 					--击退
			if tp ~= "Collision" then col:AddVelocity((ent.Position - col.Position):Normalized() * (-5) * auxi.get_repel_params(col))
			elseif d.params.repel then
				if col.Velocity:Length() < 20 then col:AddVelocity(d.params.repel * auxi.get_repel_params(col))
				else col.Velocity = (col.Velocity + d.params.repel * auxi.get_repel_params(col)):Normalized() * 20 end
				if d.params.no_co_repel ~= true then item.repel_self(player,ent,-d.params.repel) end
			end
		end
		if (d.deadeye or 0) > 0 then						--死眼
			player:AddDeadEyeCharge()
			d.deadeye = 0
		end
		if (d.wavereye or 0) > 0 then
			Wavering_Eyes.add_waver_eye_charge(player)
			d.wavereye = 0
		end
		if (d.params.list.damo or 0) > 0 then Damo_holder.try_add_damo(col)	end
		if d[item.own_key.."Dual"] then						--阴阳
			if d2[item.own_key.."Dual_effect"] then
				if d2[item.own_key.."Dual"] ~= d[item.own_key.."Dual"] and d2[item.own_key.."Dual"] ~= 2 then
					d2[item.own_key.."Dual"] = 2
					d2[item.own_key.."Dual_effect"]:Play("Rotate_"..tostring(d2[item.own_key.."Dual"]),true)
					d2[item.own_key.."Dual_effect"].Rotation = math.ceil(d2[item.own_key.."Dual_effect"].Rotation) % 360
				end
			else
				d2[item.own_key.."Dual_effect"] = Sprite()
				d2[item.own_key.."Dual_effect"]:Load("gfx/player/qing/Yin_Yang_orb.anm2",true)
				d2[item.own_key.."Dual_effect"]:Play("Rotate_"..tostring(d[item.own_key.."Dual"]),true)
				d2[item.own_key.."Dual_player"] = player
				d2[item.own_key.."Dual"] = d[item.own_key.."Dual"]
			end
		end
		if (d[item.own_key.."Explosive_cnt"] or 0) > 0 then item.trigger_explosive_effect(ent,player,col.Position,damage) end
		if d.fire_sound_effect == true then	sound_tracker.PlayStackedSound(SoundEffect.SOUND_FIREDEATH_HISS,1.0,auxi.random_1() * 0.3 + 0.8,false,0,2) end
		if d.tearflags & BitSet128(1<<18,0) == BitSet128(1<<18,0) and d.divi_list then		--分裂
			for u,v in pairs(d.divi_list) do auxi.fire_dosome_knife(ent.Position,auxi.get_by_rotate(ent.Velocity,v.dir or 0,20 * player.ShotSpeed),nil,"IdleUp",{cooldown = 10,player = player,dmg = (v.dmg or 0.5) * ent.CollisionDamage,ignore_divi = true,Accerate = 3,scale = Vector(0.5,0.5),}) end
			d.divi_list = nil
		end
		if tp ~= "Collision" then 
			col:TakeDamage(damage,damageflag,EntityRef(ent),0)
			d2[item.own_key.."counter"] = 3
			item.dealt_extra_effect_to_col(ent,col,s:GetAnimation()) 
		end
		return
	end
	if auxi.is_movable(col) then
		if d.inner_frame == 6 then 
			if damage > 0 then col:TakeDamage(1,damageflag,EntityRef(ent),0) end
		end
		return
	end
	if col:ToBomb() then
		if tp ~= "Collision" then 
			d2[item.own_key.."counter"] = 3
		end
		if d.params.no_repel ~= true then 
			if tp ~= "Collision" then 
				col:AddVelocity((ent.Position - col.Position):Normalized() * (-1.5))
			elseif d.params.repel then
				if (col.Velocity + d.params.repel):Length() < 20 then col:AddVelocity(d.params.repel)
				else col.Velocity = (col.Velocity + d.params.repel):Normalized() * 20 end
				item.repel_self(player,ent,-d.params.repel * 0.5)
			end
		end
		if (d[item.own_key.."Explosive_cnt"] or 0) > 0 then item.trigger_explosive_effect(ent,player,col.Position,damage) end
		return
	end
	if col:ToPickup() and col.Variant ~= 100 and col:IsShopItem() == false then
		d2[item.own_key.."counter"] = 3
		if d.params.no_repel ~= true then col:AddVelocity((ent.Position - col.Position):Normalized() * (-3) * auxi.get_repel_params(col)) end
		if d.params.no_open ~= true then
			local succ = false
			for i = 1,1 do 
				if ((auxi.needs_key(col) and player:HasTrinket(136)) or col.Variant == 51) and auxi.needs_open(col) then
					if (d[item.own_key.."Explosive_cnt"] or 0) > 0 then item.trigger_explosive_effect(ent,player,col.Position,damage) succ = true break end
				end
				if auxi.can_open(col) then
					if item.open_list[col.Variant] then succ = auxi.check_if_any(item.open_list[col.Variant],player,ent,col)
					elseif s2:IsPlaying("Idle") or s2:IsFinished("Idle") then col:TryOpenChest() succ = true end
				end
			end
			if succ then auxi.try_start_ambush() end
		end
		return
	end
	if col:ToProjectile() then
		if d.tearflags & BitSet128(1<<34,0) == BitSet128(1<<34,0) then col:AddVelocity((ent.Position - col.Position):Normalized() * (-2)) end
		return
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_KNIFE_UPDATE, params = nil,
Function = function(_,ent)
	if ent.Variant == enums.Entities.StabberKnife then
		local room = Game():GetRoom()
		local level = Game():GetLevel()
		local d = ent:GetData()
		d.tearflags = d.tearflags or BitSet128(0,0)
		local s = ent:GetSprite()
		if not ent.Parent then return end
		local d2 = ent.Parent:GetData()
		d2.Params = d2.Params or {}
		local n_entity = Isaac.GetRoomEntities()
		d.params = d.params or {}
		d.params.list = d.params.list or {}
		d.params.color = d.params.color or Color(1,1,1,1)
		local range = ent:GetSprite().Scale:Length()
		local player = CharacterAttackCompat.resolve_entity_player(ent, d.params.player or d.player)
		if not player then return end
		local d3 = player:GetData()
		local damage = d.damage or ent.CollisionDamage
		local damageflag = d.damageflag or 0
		d.inner_frame = (d.inner_frame or 0) + 1
		if s:IsPlaying("SpinUp") or s:IsPlaying("SpinUp2") then
			if s:GetFrame() == 1 and math.random(1000) > 700 then sound_tracker.PlayStackedSound(SoundEffect.SOUND_SWORD_SPIN,math.random(1000)/2000 + 1,math.random(1000)/5000 + 0.8,false,0,2) end
			local grids = auxi.get_near_grid_info(ent.Position,75 * range)
			for u,v in pairs(grids) do
				local gent = grid_entity.get_grid_entity(v.grid,v.idx)
				if gent then qing_s_knife_holder.collide_knife_on_it(ent,gent,"Spin") end
			end
			for u,v in pairs(n_entity) do
				if (v:GetData()[item.own_key.."counter"] or 0) <= 0 and v.Type ~= 8 then
					if (ent.Position - v.Position):Length() < 75 * range then qing_s_knife_holder.collide_knife_on_it(ent,v,"Spin") end
				end
			end
		end
		if s:IsPlaying("AttackUp") or s:IsPlaying("AttackUp2") then
			if s:GetFrame() == 1 and math.random(1000) > 700 then sound_tracker.PlayStackedSound(SoundEffect.SOUND_SWORD_SPIN,math.random(1000)/2000 + 0.5,math.random(1000)/5000 + 0.4,false,0,2) end
			local grids = auxi.get_near_grid_info(ent.Position,55 * range)
			for u,v in pairs(grids) do
				if auxi.MakeVector((ent.Position - room:GetGridPosition(v.idx)):GetAngleDegrees() - ent.RotationOffset).X < 0.05 then
					local gent = grid_entity.get_grid_entity(v.grid,v.idx)
					if gent then qing_s_knife_holder.collide_knife_on_it(ent,gent,"Attack") end
				end
			end
			for u,v in pairs(n_entity) do
				if (v:GetData()[item.own_key.."counter"] or 0) <= 0 and v.Type ~= 8 then
					if (ent.Position - v.Position):Length() < 55 * range and auxi.MakeVector((ent.Position - v.Position):GetAngleDegrees() - ent.RotationOffset).X < 0.05 then qing_s_knife_holder.collide_knife_on_it(ent,v,"Attack") end
				end
			end
		end
		if s:IsPlaying("IdleUp") or s:IsFinished("IdleUp") then
			local gent = grid_entity.get_grid_entity(room:GetGridEntityFromPos(ent.Position))
			if gent then qing_s_knife_holder.collide_knife_on_it(ent,gent,"Idle") end
			ent.RotationOffset = ent.Parent.Velocity:GetAngleDegrees() + (d[item.own_key.."Vel_Float"] or 0)
			if d2.removecd == 10 then 
				if ent.Parent.Velocity:Length() > 7 then d[item.own_key.."ClearOut"] = true d2.Params.removeanimate = nil
				else d[item.own_key.."ClearOut"] = nil d2.Params.removeanimate = true end
			end
			if (d2.removecd or 0) <= 10 and d[item.own_key.."ClearOut"] then ent.Color = auxi.MulColor(d.params.color,Color(1,1,1,(d2.removecd or 0)/10)) end
			
			if (d.params.knife or 0) > 0 then
				if d[item.own_key.."Sec"] then
					d[item.own_key.."Knife_delay"] = (d[item.own_key.."Knife_delay"] or math.random(20)) - 1
					if d[item.own_key.."Knife_delay"] < 0 and auxi.check_all_exists(d2.Params.Homing_target) then
						local q1 = auxi.fire_knife(ent.Position,(d2.Params.Homing_target.Position - ent.Position):Normalized(),ent.CollisionDamage * 0.1,nil,{cooldown = 8,player = player,Color = Color(1,1,1,0.5,0,0,0)})
						q1:Shoot(1,player.TearRange/4)
						d[item.own_key.."Knife_delay"] = math.random(20)
					end
				elseif (d.params.list.brimstone or 0) > 0 then
					d[item.own_key.."Knife_delay"] = (d[item.own_key.."Knife_delay"] or math.random(8)) - 1
					if d[item.own_key.."Knife_delay"] < 0 then
						local vel = auxi.MakeVector(ent.RotationOffset) * 0.01
						local q1 = auxi.fire_knife(ent.Position, -vel,ent.CollisionDamage / 3,nil,{cooldown = math.random(10),player = player,Color = Color(-1,-1,-1,0.3,0,0,0)})
						q1:SetColor(Color(-1,-1,-1,0.3,0,0,0),15,99,false,false)
						local s2 = q1:GetSprite()
						s2.Scale = s.Scale * 1.5
						q1.RotationOffset = 180 + q1.RotationOffset
						d[item.own_key.."Knife_delay"] = math.random(8)
					end
				end
			end
			if d.params and d.params.Dr_fet and (d.params.Dr_fet == true or d.params.Dr_fet > 0) then
				if d2.Params and d2.Params.Homing_target and d2.Params.Homing_target:Exists() == true then
					if d.Dr_fetus_firedelay == nil then
						d.Dr_fetus_firedelay = -1
					end
					if d.Dr_fetus_firedelay < 0 then
						if math.random(1000) > 800 then
							local d2 = ent.Parent:GetData()
							local vel = (d2.Params.Homing_target.Position - ent.Parent.Position):Normalized() * ent.Parent.Velocity:Length()
							if vel:Length() < 0.005 then
								vel = auxi.MakeVector(ent.RotationOffset) * 0.005
							end
							local q1 = player:FireBomb(ent.Position,vel * (math.random(50)/10 + 2),nil,0.3)
						end
						d.Dr_fetus_firedelay = math.random(65) + 10 + player.MaxFireDelay
					end
					d.Dr_fetus_firedelay = d.Dr_fetus_firedelay - 1
				end
			end
			if (d.params.epic or 0) > 0 then 		--史诗
				if d[item.own_key.."Touched"] then
					if auxi.check_all_exists(d[item.own_key.."Epic"]) ~= true then d2.removecd = math.min(1,d2.removecd or 0) end
				else
					local grid = room:GetGridEntityFromPos(ent.Position)
					if grid and auxi.issolid(grid) then
						d[item.own_key.."Epic"] = item.trigger_epic_effect(ent,nil)
						item.try_set_touched(ent)
					end
				end
			end
			
			if d.start_sec ~= nil and d.start_sec == false and ent.Parent.Velocity:Length() < 0.005 then
				local d2 = ent.Parent:GetData()
				if d2.Params and (d2.Params.Homing_target and d2.Params.Homing_target:Exists() == false) then
					d2.Params.Homing_target = nil
					ent.Parent.Velocity = ent.Parent.Velocity:Normalized() * 3
					ent.Parent:GetData().Params.Accerate = 0
				end
			end
			if d.tearflags & BitSet128(1<<61,0) == BitSet128(1<<61,0) and d.inner_frame % 7 == 3 then Flat_Stone_holder.attack_wave(ent.Position,{scale = s.Scale * 1.5,dmg = ent.CollisionDamage * 0.5,}) end
			if d.params and d.params.sword and (d.params.sword == true or d.params.sword > 0) then
				local d2 = ent.Parent:GetData()
				if d2.Params and d2.Params.Homing_target and d2.Params.Homing_target:Exists() == true then
					if d.Dr_fetus_firedelay == nil then
						d.Dr_fetus_firedelay = -1
					end
					if d.Dr_fetus_firedelay < 0 then
						if math.random(1000) > 400 then
							
							local d2 = ent.Parent:GetData()
							local vel = (d2.Params.Homing_target.Position - ent.Parent.Position):Normalized() * ent.Parent.Velocity:Length()
							if vel:Length() < 0.005 then
								vel = auxi.MakeVector(ent.RotationOffset) * 0.005
							end
							local q1 = auxi.fire_Sword(ent.Position,vel,ent.CollisionDamage/3,nil,{cooldown = 14,Accerate = 0.5,player = player,tearflags = player.TearFlags,Color = player.TearColor,Qing = (player:GetPlayerType() == item.entity)})
							sound_tracker.PlayStackedSound(SoundEffect.SOUND_SWORD_SPIN,math.random(1000)/2000 + 1,math.random(1000)/5000 + 0.8,false,0,2)
						end
						d.Dr_fetus_firedelay = math.random(65) + 10 + player.MaxFireDelay
					end
					d.Dr_fetus_firedelay = d.Dr_fetus_firedelay - 1
				end
			end
			if d.params and d.params.Hae and (d.params.Hae == true or d.params.Hae > 0) then
				local d2 = ent.Parent:GetData()
				if d2.removecd and d2.removecd == 1 then
					local maxcnt = math.random(d.params.list.hae * 1 + 1) - 1
					for i = 1, maxcnt do 
						local q1 = player:FireTear(ent.Position, auxi.MakeVector(math.random(36000)/100) * 3 * player.ShotSpeed * (math.random(1000)/400+0.3),true,true,true)
						q1.FallingSpeed = 10
						q1.FallingAcceleration = 2.6
						q1.PositionOffset = Vector(0,0)
						q1.Scale = q1.Scale * (math.random(1500)/1000 + 0.8)
					end
				end
			end
			
			local n_multi_baby = auxi.getothers(n_entity,3,101)
			if d.params.ignore_divi == nil then
				for u,v in pairs(n_multi_baby) do
					if (v.Position - ent.Position):Length() < 20 then
						d.params.ignore_divi = true
						auxi.fire_dosome_knife(ent.Position + auxi.get_by_rotate(ent.Velocity,90,auxi.random_0() * 10),auxi.get_by_rotate(ent.Velocity,0,25),nil,"IdleUp",{player = player,color = auxi.AddColor(d.params.color,Color(0,0,0,1,0.5,0.5,0.5),0.25,0.75),ignore_divi = true,})
						break
					end
				end
			end
			local n_prism = auxi.getothers(n_entity,3,123)
			if d.params.ignore_divi == nil then
				for u,v in pairs(n_prism) do
					if (v.Position - ent.Position):Length() < 20 then
						d.params.ignore_divi = true
						local color_idx = {
							Color(0,0,0,1,1,0,0),
							Color(0,0,0,1,0,1,0),
							Color(0,0,0,1,0,0,1),
							Color(0,0,0,1,0,1,1),
						}
						for i = 1,4 do auxi.fire_dosome_knife(ent.Position,auxi.get_by_rotate(ent.Velocity,- 18 + 12 * (i - 1),15),nil,"IdleUp",{player = player,color = auxi.AddColor(d.params.color,color_idx[i],0.25,0.75),dmg = ent.CollisionDamage/2,ignore_divi = true,}) end
						break
					end
				end
			end
		end
		if s:IsPlaying("StabDown") or s:IsFinished("StabDown") then
			local grids = auxi.get_near_grid_info(ent.Position + ent.Velocity * 10,20 * range)
			for u,v in pairs(grids) do
				local gent = grid_entity.get_grid_entity(v.grid,v.idx)
				if gent then qing_s_knife_holder.collide_knife_on_it(ent,gent,"Stab") end
			end
			if d.params.thor_effe ~= true then
				for u,v in pairs(n_entity) do
					if (v:GetData()[item.own_key.."counter"] or 0) <= 0 then
						if (ent.Position + ent.Velocity * 5 - v.Position):Length() < 20 * range then qing_s_knife_holder.collide_knife_on_it(ent,v,"Stab") end
					end
				end
			end
			
			if d.params and d.params.lung_and_tech and d.params.lung_and_tech > 0 and d.params.lung_and_tech_cnt and d.params.lung_and_tech_cnt> 0 then
				if s:GetFrame() == 2 then
					local dirang = (ent.Velocity):GetAngleDegrees()
					local rang = math.random(60) + 30
					local leap = rang/(d.params.lung_and_tech_cnt - 1)
					local length = (ent.Velocity):Length()
					for i = 1,d.params.lung_and_tech_cnt do 
						auxi.fire_dosome_knife(ent.Position + ent.Velocity,auxi.MakeVector(dirang - rang/2 + (i-1) * leap) * math.max(0.001,(length + math.random(10000)/1000 - 5)),nil,"StabDown",{player = player,repel = 0,lung_and_tech = d.params.lung_and_tech - math.random(d.params.lung_and_tech + 1),lung_and_tech_cnt = math.max(1,d.params.lung_and_tech_cnt + math.random(3) - 2)})
					end
				end
			end
			
			local n_multi_baby = auxi.getothers(n_entity,3,101)
			if d.params.ignore_divi == nil then
				for u,v in pairs(n_multi_baby) do
					if (v.Position - ent.Position):Length() < 20 then
						d.params.ignore_divi = true
						auxi.fire_dosome_knife(ent.Position + auxi.get_by_rotate(ent.Velocity,90,auxi.random_0() * 10),auxi.get_by_rotate(ent.Velocity,0,25),nil,"IdleUp",{player = player,color = auxi.AddColor(d.params.color,Color(0,0,0,1,0.5,0.5,0.5),0.25,0.75),ignore_divi = true,})
						break
					end
				end
			end
			local n_prism = auxi.getothers(n_entity,3,123)
			if d.params.ignore_divi == nil then
				for u,v in pairs(n_prism) do
					if (v.Position - ent.Position):Length() < 20 then
						d.params.ignore_divi = true
						local color_idx = {
							Color(0,0,0,1,1,0,0),
							Color(0,0,0,1,0,1,0),
							Color(0,0,0,1,0,0,1),
							Color(0,0,0,1,0,1,1),
						}
						for i = 1,4 do auxi.fire_dosome_knife(ent.Position,auxi.get_by_rotate(ent.Velocity,- 18 + 12 * (i - 1),15),nil,"IdleUp",{player = player,color = auxi.AddColor(d.params.color,color_idx[i],0.25,0.75),dmg = ent.CollisionDamage/2,ignore_divi = true,}) end
						break
					end
				end
			end
		end
		
		if d.tearflags & BitSet128(1<<21,0) == BitSet128(1<<21,0) then		--突眼
			if d.damage_float == nil then
				d.damage_float = 3
				d.damage_count = ent.CollisionDamage
				d.damage_scale = Vector(s.Scale.X,s.Scale.Y)
			end
			d.damage_float = math.max(0,d.damage_float - 0.15 / player.ShotSpeed)		--15帧后减少至0。
			ent.CollisionDamage = d.damage_float * d.damage_count
			s.Scale = d.damage_scale * (d.damage_float/3 * 0.5 + 0.5)
		end
		if d.tearflags & BitSet128(1<<7,0) == BitSet128(1<<7,0) then		--煤块
			if d.damage_float == nil then
				d.damage_float = 0.6
				d.damage_count = ent.CollisionDamage
				d.damage_scale = Vector(s.Scale.X,s.Scale.Y)
			end
			d.damage_float = d.damage_float + 0.03 / player.ShotSpeed
			ent.CollisionDamage = d.damage_float * d.damage_count
			s.Scale = d.damage_scale * ((d.damage_float + 0.4) * 0.1 + 0.9)
		end
		if (d.deadeye or 0) > 0 and (d2.removecd or 0) == 1 then		--死眼
			player:ClearDeadEyeCharge()
			d.deadeye = 0
		end
		if (d.wavereye or 0) > 0 and (d2.removecd or 0) == 1 then
			if math.random(1000) > 750 then Wavering_Eyes.clear_waver_eye_charge(player) end
			d.wavereye = 0
		end
		
		if (d.params.sec or 0) > 0 then			--剖腹产
			if s:IsFinished(s:GetAnimation()) and item.sec_trans[s:GetAnimation()] and ent.FrameCount > 6 and not d[item.own_key.."sec"] then
				d[item.own_key.."sec"] = true
				s:Play("IdleUp",true)
				d2.Is_Qing_Fetus = true
				d2.Params.Homing = true
				d2.Params.HomingSpeed = 8
				d2.Params.HomingDistance = 170 + math.sqrt(math.max(0,(player.TearRange - 260))) * 0.3
				d2.Params.Accerate = 0.55
				ent.Parent.Velocity = ent.Parent.Velocity:Normalized() * 3
				d2.removecd = (d2.removecd or 0) + math.sqrt(player.TearRange * 0.8) * 2
				
				d.params.shouldrotate = true
				d.params.repel = Vector(0,0)
				d.params.no_repel = true
				d[item.own_key.."Sec"] = true
				if d.params.thor_effe ~= true then	
					d.params.epic = d.params.list.epic
					d.params.sword = d.params.list.sword
					d.params.knife = d.params.list.knife
					d.params.brimstone = d.params.list.brimstone
					d.params.TechX = d.params.list.techX
					d.params.Tech = d.params.list.tech
					d.params.Hae = d.params.list.hae
					d.params.Dr_fet = d.params.list.dr + d.params.list.epic
				end
				d[item.own_key.."holder"] = d[item.own_key.."holder"] or {}
				if (d.params.brimstone or 0) > 0 then
					local q2 = player:FireBrimstone(-ent.Parent.Velocity,nil,0.3)
					q2.PositionOffset = Vector(0,0)
					q2:SetTimeout(math.ceil(ent.Parent:GetData().removecd) - 1)
					q2:SetMaxDistance(player.TearRange/4)
					q2.Parent = ent
					q2.Position = ent.Position
					table.insert(d[item.own_key.."holder"],{ent = q2,adder = 180,})
				end
				if d.params.TechX and d.params.TechX > 0 and d.params.Tech and d.params.Tech == 0 then
					local q2 = player:FireTechXLaser(ent.Position,ent.Velocity,player.TearRange/10,nil,0.3)
					q2.SubType = 3
					q2.PositionOffset = Vector(0,0)
					q2.Parent = ent
					q2:SetTimeout(math.ceil(ent.Parent:GetData().removecd) - 1)
				end
			end
		end
		
		if d.params.thor and d.has_thor then
			if d.has_fall ~= true and room:GetType() ~= RoomType.ROOM_DUNGEON then
				if (d2.follower and d2.follower:IsDead() == true) or d[item.own_key.."should_fall"] then
					d2.follower = nil
					if (d2.removecd or 0) > 0 then d2.removecd = d2.removecd + 30 * 2 end
					if s:IsPlaying("ChargedUp") then s:Play("ChargedFall",true)	end
					if s:IsPlaying("NoChargedUp") then s:Play("NoChargedFall",true)	end
					d.has_fall = true
				end
			end
		end
		
		if d[item.own_key.."holder"] then
			for u,v in pairs(d[item.own_key.."holder"]) do 
				auxi.check_if_any(v,ent,item)
				if auxi.check_all_exists(v.ent) and v.No_rotate ~= true then
					v.ent.Angle = ent.RotationOffset + (v.adder or 0)
				end
			end
		end
		
		if s:IsPlaying("ChargedFall") or s:IsPlaying("NoChargedFall") or s:IsFinished("ChargedFall") or s:IsFinished("NoChargedFall") then
			d.save_rotation = d.save_rotation or s.Rotation
			d.save_rotation = auxi.AddAngle(d.save_rotation,(d[item.own_key.."FallRot"] or 0),0.7,0.3)
			s.Rotation = d.save_rotation
			ent.Parent.Velocity = ent.Parent.Velocity * 0.1
			if s:IsEventTriggered("TryCrack") then
				if (d.params.list.lemon or 0) > 0 then		--柠檬
					if auxi.check_rand(player.Luck,35,15,6) == true then
						local q = Isaac.Spawn(1000,EffectVariant.PLAYER_CREEP_LEMON_MISHAP,0,ent.Position,Vector(0,0),player):ToEffect()
						if ent.Parent then
							q:SetTimeout(ent.Parent:GetData().removecd)
						end
						auxi.replace_dagger_graph(ent,"Empty_Stabknife")
						s:ReplaceSpritesheet(3,"gfx/effects/ground_yellow.png")
						s:LoadGraphics()
						sound_tracker.PlayStackedSound(SoundEffect.SOUND_GLASS_BREAK,1,1,false,0,2)
					end
				end
				if d.tearflags & BitSet128(1<<57,0) == BitSet128(1<<57,0) and not d.linked_zero then		--科技0
					if auxi.check_all_exists(d3.last_zero_knife) then
						d3.last_zero_knife:GetData().last_zero_target = ent
					end
					d3.last_zero_knife = ent
					d.linked_zero = true
				end
				if (d.params.list.godhead or 0) > 0 then	--神性
					if d.god_head_gospel_ring == nil then
						d.god_head_gospel_ring = true
						local q = Isaac.Spawn(7,5,3,ent.Position,Vector(0,0),player):ToLaser()
						q.PositionOffset = ent.PositionOffset
						q.Parent = ent
						q.Radius = 70
						local d2 = q:GetData()
						q.CollisionDamage = ent.CollisionDamage/3 * d.params.list.godhead
						d2.is_gospel_laser = true
						d2.radius_vel = -14
						d2.radius_acc = 2.8
						local s = q:GetSprite()
						s:Load("gfx/laser_concerter.anm2",true)
						s:ReplaceSpritesheet(0,"gfx/effects/lasers/lofty_brim3.png")
						s:LoadGraphics()
						s:Play("LargeRedLaser",true)
						s.Color = Color(1,1,0,0.2)
						s.Scale = Vector(1,1)
					end
				end
			end
		end
		
		if s:IsPlaying("ChargedDown") or s:IsPlaying("NoChargedDown") then
			if d.should_renew_charge then d.should_renew_charge = nil s:Play("ChargedDown",true) end
			if d.should_clear_charge then d.should_clear_charge = nil s:Play("NoChargedDown",true) end
			s.Rotation = (d[item.own_key.."FallRot"] or 0)
			ent.Parent.Velocity = ent.Parent.Velocity * 0.1
			if d.tearflags and d.tearflags & BitSet128(1<<57,0) == BitSet128(1<<57,0) then
				if ent.Parent and ent.Parent:GetData().removecd and (d.zero_stack or 0) > 0 then ent.Parent:GetData().removecd = math.max(5,ent.Parent:GetData().removecd) end
				if (d.zero_stack or 0) > 0 and ent.FrameCount % 8 == 1 then
					if d.last_zero_target then
						if d.last_zero_target:Exists() then
							d.zero_stack = d.zero_stack - 1
							local q = Isaac.Spawn(7,10,4,ent.Position,Vector(0,0),player):ToLaser()
							q.AngleDegrees = (d.last_zero_target.Position - ent.Position):GetAngleDegrees()
							q.TearFlags = BitSet128(0,0)
							q.PositionOffset = Vector(0,0)
							q:SetTimeout(2)
							q.Parent = ent
							q.CollisionDamage = damage * 0.7
							q:SetOneHit(true)
							q:SetMaxDistance((d.last_zero_target.Position - ent.Position):Length())
						else
							d.zero_stack = 0
						end
					end
				end
			end
		end
		
		if s:IsPlaying("StabDown") or s:IsPlaying("IdleUp") or s:IsPlaying("ChargedDown") or s:IsPlaying("NoChargedDown") or s:IsPlaying("ChargedUp") or s:IsPlaying("NoChargedUp") or s:IsPlaying("ChargedFall") or s:IsPlaying("NoChargedFall") then
			if d.tearflags then
				if d.tearflags & BitSet128(1<<55,0) == BitSet128(1<<55,0) then
					if d.Qing_Laser_counter == nil then d.Qing_Laser_counter = 0 end
					if d.Qing_Laser_random_counter == nil then d.Qing_Laser_random_counter = math.random(7) + 7 end
					d.Qing_Laser_counter = d.Qing_Laser_counter + 1
					if d.Qing_Laser_counter >= d.Qing_Laser_random_counter then
						d.Qing_Laser_random_counter = math.random(7) + 7
						d.Qing_Laser_counter = 0
						local range = 50
						if d.params and d.params.list and d.params.list.onlaser then range = range + d.params.list.onlaser * 30 end
						local n_entity = Isaac.FindInRadius(ent.Position,range,1<<3)
						local n_enemy = auxi.getenemies(n_entity)
						local ignore_it = nil
						if ent.Parent and ent.Parent:GetData().follower then ignore_it = ent.Parent:GetData().follower end
						for u,v in pairs(n_enemy) do
							if ignore_it and auxi.check_for_the_same(v,ignore_it) then
							else
								local q = Isaac.Spawn(7,10,4,ent.Position,Vector(0,0),player):ToLaser()
								q.AngleDegrees = (v.Position - ent.Position):GetAngleDegrees()
								q.TearFlags = BitSet128(0,0)
								q.PositionOffset = Vector(0,0)
								q:SetTimeout(2)
								q.Parent = ent
								q.CollisionDamage = damage * 0.2
								q:SetOneHit(true)
								q:SetMaxDistance((v.Position - ent.Position):Length())
							end
						end
					end
				end
			end
		end
		
		if s:IsPlaying("ChargedUp") or s:IsPlaying("NoChargedUp") then
			if d.should_renew_charge then d.should_renew_charge = nil s:Play("ChargedUp",true) end
			if d.should_clear_charge then d.should_clear_charge = nil s:Play("NoChargedUp",true) end
		end
		if s:IsFinished(s:GetAnimation()) and item.replay_anim[s:GetAnimation()] then s:Play(item.replay_anim[s:GetAnimation()],true) end
		--if d.params.continueafter and s:IsFinished(s:GetAnimation()) then s:Play(s:GetAnimation(),true) end
		if s:IsPlaying("IdleUp") or s:IsFinished("IdleUp") then		--特效
			if d.tearflags & BitSet128(1<<16,0) == BitSet128(1<<16,0) then		--原版星球
				local leg = ent.Parent.Velocity:Length()
				d[item.own_key.."Planet"] = d[item.own_key.."Planet"] or (auxi.random_0() * 90)
				ent.Parent.Velocity = (auxi.get_by_rotate(ent.Parent.Velocity,d[item.own_key.."Planet"],0.2) + ent.Parent.Velocity:Normalized()):Normalized() * leg
				d[item.own_key.."Vel_Float"] = d[item.own_key.."Planet"] * 0.2
			end
			if d.tearflags & BitSet128(0,1<<(69-64)) == BitSet128(0,1<<(69-64)) then		--星球2
				local mul = math.min(1,(ent.Parent.Position - player.Position):Length()/100)
				local leg = ent.Parent.Velocity:Length()
				d[item.own_key.."Immu"] = d[item.own_key.."Immu"] or (auxi.random_0() * 90)
				ent.Parent.Velocity = ent.Parent.Velocity * 0.5 * (2 - mul) + auxi.get_by_rotate(ent.Parent.Position - player.Position,d[item.own_key.."Immu"],leg * 0.9 + (15 + ent.FrameCount * 0.2) * 0.1) * 0.5 * mul
				d[item.own_key.."Vel_Float"] = d[item.own_key.."Immu"] * 0.2
			end
			if d.tearflags & BitSet128(1<<30,0) == BitSet128(1<<30,0) then		--方蛇
				if d.Addition_Pulse_flag == nil then
					d.Addition_Pulse_flag = math.random(2) * 2 - 1
					d.Addition_Pulse_cnt = 5
					d.OriginalVelocity = ent.Parent.Velocity
				end
				if d.Addition_Pulse_flag == 0 or d.Addition_Pulse_flag == 1 and d.Addition_Pulse_cnt < 0 then
					ent.Parent.Velocity = auxi.Get_rotate(ent.Parent.Velocity)
					d.Addition_Pulse_flag = d.Addition_Pulse_flag + 1
					d.Addition_Pulse_cnt = 5
				elseif d.Addition_Pulse_flag == 2 or d.Addition_Pulse_flag == 3 and d.Addition_Pulse_cnt < 0 then
					ent.Parent.Velocity = - auxi.Get_rotate(ent.Parent.Velocity)
					d.Addition_Pulse_flag = d.Addition_Pulse_flag + 1
					d.Addition_Pulse_cnt = 5
				end
				if d.Addition_Pulse_flag > 3 then
					d.Addition_Pulse_flag = 0
				end
				d.Addition_Pulse_cnt = d.Addition_Pulse_cnt - 1
			end
			if d.tearflags & BitSet128(1<<26,0) == BitSet128(1<<26,0) then		--环蛇
				if d.AdditionVelocity == nil then
					d.AdditionVelocity = 0
					d.OriginalVelocity = ent.Parent.Velocity
				end
				local leg = ent.Parent.Velocity:Length()
				ent.Parent.Velocity = (d.OriginalVelocity:Normalized() + auxi.MakeVector(d.AdditionVelocity) * 2):Normalized() * leg
				d.AdditionVelocity = d.AdditionVelocity + 20
			end
			if d.tearflags & BitSet128(1<<46,0) == BitSet128(1<<46,0) then		--黑蛇
				if d.AdditionVelocity == nil then
					d.AdditionVelocity = 0
					d.OriginalVelocity = ent.Parent.Velocity
				end
				local leg = ent.Parent.Velocity:Length()
				ent.Parent.Velocity = (d.OriginalVelocity:Normalized() + auxi.MakeVector(d.AdditionVelocity) * 2):Normalized() * leg
				d.AdditionVelocity = d.AdditionVelocity + 10
			end
			if d.tearflags & BitSet128(1<<10,0) == BitSet128(1<<10,0) then		--弯虫
				if d.AdditionVelocity == nil then
					d.AdditionVelocity = 0
					d.OriginalVelocity = ent.Parent.Velocity
				end
				local leg = ent.Parent.Velocity:Length()
				ent.Parent.Velocity = (d.OriginalVelocity:Normalized() + auxi.MakeVector(d.AdditionVelocity) * 0.6):Normalized() * leg
				d.AdditionVelocity = d.AdditionVelocity + 20
			end
			if d.tearflags & BitSet128(1<<17,0) == BitSet128(1<<17,0) then		--反重力
				d2.Params.Accerate = d2.Params.Accerate or 0
				if d.Antig_velo == nil and ent.FrameCount > 1 then
					d.Antig_velo = ent.Parent.Velocity
					d.Antig_acce = d2.Params.Accerate
					d.Antig_flag = false
				end
				if auxi.ggdir(player,false):Length() > 0.05 and d.Antig_flag ~= nil and d.Antig_flag == false and ent.FrameCount > 1 then
					ent.Parent.Velocity = ent.Parent.Velocity/100000
					d2.Params.Accerate = 0	
				elseif d.Antig_flag ~= nil and d.Antig_flag == false then
					ent.Parent.Velocity = d.Antig_velo
					d2.Params.Accerate = d.Antig_acce
					d.Antig_flag = true
				end
			end
			if d.tearflags & BitSet128(1<<8,0) == BitSet128(1<<8,0) then		--镜子
				if d.Mirror_counter == nil then
					d.Mirror_counter = 3
					d.Mirror_Velocity = ent.Parent.Velocity
				end
				d2.Params.Accerate = d2.Params.Accerate or 0
				if d.Mirror_counter == 0 then
					ent.Parent:GetData().Params.Accerate =  - ent.Parent:GetData().Params.Accerate * 3
				end
				if ent.Parent.Velocity:Length() < 0.01 then
					ent.Parent:AddVelocity(-d.Mirror_Velocity:Normalized() * 2)
					d2.Params.Accerate = - d2.Params.Accerate / 3
					d2.Accerate_flag = true
				end
				d.Mirror_counter = d.Mirror_counter - 1
			end
			if d.tearflags & BitSet128(1<<38,0) == BitSet128(1<<38,0) and d[item.own_key.."Continum"] ~= true then		--连续集
				if room:IsPositionInRoom(ent.Position,-50) ~= true then	
					d2.next_pos = room:GetCenterPos() * 2 - ent.Parent.Position
					ent.Parent.Velocity = ent.Parent.Velocity * 0.3
					d2.removecd = (d2.removecd or 0) + 30
					ent.Color = auxi.AddColor(ent.Color,Color(1,0,1,1,0.3,0,0.3),0.5,0.5)
					d[item.own_key.."Continum"] = true
				end
			end
			if d.tearflags & BitSet128(0,(1<<(71-64))) == BitSet128(0,(1<<(71-64))) and ent.FrameCount > 7 then		--脑虫
				if d2.Params.Homing == nil then
					d.brain_worm_effect = true
					d2.Params.Homing = true
					d2.Params.HomingDistance = 200
				end
				if d.brain_worm_effect == true and auxi.check_all_exists(d2.Params.Homing_target) then
					d2.Params.Homing = false
					d.brain_worm_effect = false
					local dir = d2.Params.Homing_target.Position - ent.Position
					ent.Parent.Velocity = dir:Normalized() * ent.Parent.Velocity:Length()/2
					ent.RotationOffset = ent.Parent.Velocity:GetAngleDegrees()
					d2.Params.Accerate = 1
				end
			end
			if d.tearflags & BitSet128(0,1<<(68-64)) == BitSet128(0,(1<<68-64)) then		--魔眼
				d2.Params.FollowInput = true
			end
		end
		
		if d[item.own_key.."Touched"] ~= nil then
			ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
			ent.CollisionDamage = 0
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_KNIFE_COLLISION, params = nil,
Function = function(_,ent,col,low)
	if ent.Variant == enums.Entities.StabberKnife then
		local room = Game():GetRoom()
		local level = Game():GetLevel()
		local d = ent:GetData()
		local s = ent:GetSprite()
		if not ent.Parent then return end
		local d2 = ent.Parent:GetData()
		d.params = d.params or {}
		local player = CharacterAttackCompat.resolve_entity_player(ent, d.params.player or d.player)
		if not player then return end
		local d3 = player:GetData()
		qing_s_knife_holder.collide_knife_on_it(ent,col,"Collision")
		
		if s:IsPlaying("IdleUp") or s:IsFinished("IdleUp") then
			if (d.params.epic or 0) > 0 then 
				if d[item.own_key.."Touched"] ~= true then
					d[item.own_key.."Epic"] = item.trigger_epic_effect(ent,col)
					d2.follower = col
					item.try_set_touched(ent)
				end
			end
			if auxi.isenemies(col) then
				local limit_vel = nil
				if (d.params.brimstone or 0) > 0 then limit_vel = (limit_vel or 0) + 5 end
				if (d.params.knife or 0) > 0 then limit_vel = (limit_vel or 0) + 3 end
				if limit_vel then ent.Parent.Velocity = ent.Parent.Velocity:Normalized() * limit_vel end
				if d.params.thor then
					if d.has_thor ~= true and d[item.own_key.."Touched"] ~= true then 
						d.has_thor = true 
						item.switch_thor(ent,player)
						item.try_set_touched(ent)
						ent.Parent.Velocity = ent.Parent.Velocity:Normalized() * 3
						d2.Params.removeanimate = true
						d2.follower = col
						s:Play("ChargedUp",true)
					end
				end
				if ent.TearFlags & BitSet128(1<<52,0) == BitSet128(1<<52,0) and d.not_allow_multi_belial == nil then		--彼列之眼
					d.not_allow_multi_belial = true
					local q = auxi.fire_dosome_knife(ent.Position,ent.Velocity:Normalized() * 15,nil,"IdleUp",{player = player,anti_tearflag = BitSet128(1<<52,0),tearflag = BitSet128(1<<2,0),Accerate = 1,color = auxi.AddColor(d.params.color,Color(1,0,0,1,1,0,0),0.5,0.5),})
				end
			end
			if (d.params.follow_hae or 0) > 0 then
				d.params.follow_hae = d.params.follow_hae - 1
				if (d.params.list.brimstone or 0) > 0 then
					local cnt = d.params.list.brimstone
					if d.has_thor then
						local rnd = math.random(3) + math.ceil((1 + cnt)/2)
						for i = 1,rnd do
							local q = player:FireBrimstone(auxi.MakeVector(math.random(3600)/10))
							q.PositionOffset = Vector(0,0)
							q:SetTimeout(7)
							q.Parent = ent
							q.Position = ent.Position
						end
					else
						local tot = cnt + 1
						d[item.own_key.."holder"] = d[item.own_key.."holder"] or {}
						for k = 1,-1,-2 do
							for i = 1,tot do
								local adder = (90 + (i - 0.5) * 60 / tot) * k
								local q = player:FireBrimstone(auxi.MakeVector(ent.Velocity:GetAngleDegrees() + adder))
								q.PositionOffset = Vector(0,0)
								q:SetTimeout(15)
								q.Parent = ent
								q.Position = ent.Position
								table.insert(d[item.own_key.."holder"],{ent = q,adder = adder,})
							end
						end
					end
				end
				if (d.params.list.techX or 0) > 0 then
					local cnt = d.params.list.techX
					if d.has_thor then
						local rnd = math.random(2) + math.ceil((3 + cnt)/4)
						for i = 1,rnd do
							local q = player:FireTechXLaser(ent.Position + ent.Velocity,auxi.MakeVector(math.random(3600)/10) * 10 * player.ShotSpeed,20 + math.random(30))
							q.PositionOffset = Vector(0,0)
							if (d.params.list.brimstone or 0) == 0 then q:SetTimeout(10) end
							q.Parent = ent
						end
					else
						local tot = cnt + 1
						for k = 1,-1,-2 do
							for i = 1,tot do
								local adder = (90 + (i - 0.5) * 60 / tot) * k
								local q = player:FireTechXLaser(ent.Position + ent.Velocity,auxi.MakeVector(ent.Velocity:GetAngleDegrees() + k * (180 - (i - 0.5) * 60/tot)) * 10 * player.ShotSpeed,20 + math.random(30))
								q.PositionOffset = Vector(0,0)
								if (d.params.list.brimstone or 0) == 0 then q:SetTimeout(20) end
								q.Parent = ent
							end
						end
					end
				end
			end
		end
		if s:IsPlaying("IdleUp") or s:IsPlaying("ChargedUp") or s:IsPlaying("NoChargedUp") then
			if (d.params.list.godhead or 0) > 0 then
				if d.god_head_gospel_ring == nil then
					d.god_head_gospel_ring = true
					local q = Isaac.Spawn(7,5,3,ent.Position,Vector(0,0),player):ToLaser()
					q.PositionOffset = ent.PositionOffset
					q.Parent = ent
					q.Radius = 70
					local d2 = q:GetData()
					q.CollisionDamage = ent.CollisionDamage/3 * d.params.list.godhead
					d2.is_gospel_laser = true
					d2.radius_vel = -14
					d2.radius_acc = 2.8
					local s = q:GetSprite()
					s:Load("gfx/laser_concerter.anm2",true)
					s:ReplaceSpritesheet(0,"gfx/effects/lasers/lofty_brim3.png")
					s:LoadGraphics()
					s:Play("LargeRedLaser",true)
					s.Color = Color(1,1,0,0.2)
					s.Scale = Vector(1,1)
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_RENDER, params = nil,
Function = function(_,ent,offset)
	local d = ent:GetData()
	if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
		if d[item.own_key.."Dual_effect"] then
			d[item.own_key.."Dual_effect"]:Render(Isaac.WorldToScreen(ent.Position + Vector(0,-5)) - Game().ScreenShakeOffset,Vector(0,0),Vector(0,0))
			if Game():IsPaused() == false then
				if d[item.own_key.."Dual"] == 2 then
					d[item.own_key.."Dual_effect"].Rotation = d[item.own_key.."Dual_effect"].Rotation * 0.6
				else
					d[item.own_key.."Dual_effect"].Rotation = d[item.own_key.."Dual_effect"].Rotation + 360/60
				end
				d[item.own_key.."Dual_effect"]:Update()
				local player = CharacterAttackCompat.resolve_entity_player(ent, d[item.own_key.."Dual_player"])
				if not player then return end
				if d[item.own_key.."Dual_effect"]:IsEventTriggered("Attack") then
					local col = Color(1,1,1,1)
					d[item.own_key.."Dual_Color"] = math.random(2)
					if d[item.own_key.."Dual_Color"] == 2 then col = Color(1,1,1,1,1,1,1) else col = Color(-1,-1,-1,1,-1,-1,-1) end
					Game():BombExplosionEffects(ent.Position,player.Damage * 0.4,0,col,player,0.6,false,false)
				end
				if d[item.own_key.."Dual_effect"]:IsEventTriggered("Attack2") then
					local col = Color(1,1,1,1)
					if d[item.own_key.."Dual_Color"] == 1 then col = Color(1,1,1,1,1,1,1) else col = Color(-1,-1,-1,1,-1,-1,-1) end
					local rnd = math.random(6) + 9
					for i = 1,rnd do Game():BombExplosionEffects(ent.Position + auxi.MakeVector(360/rnd * i) * 30,player.Damage * 0.1,0,col,player,0.2,false,false) end
				end
				if d[item.own_key.."Dual_effect"]:IsEventTriggered("Attack3") then
					local rnd = math.random(5) * 2 + 15
					for i = 1,rnd do
						local col = Color(1,1,1,1,1,1,1)
						if i % 2 == 1 then col = Color(1,1,1,1,1,1,1) else col = Color(-1,-1,-1,1,-1,-1,-1) end
						Game():BombExplosionEffects(ent.Position + auxi.MakeVector(360/rnd * i) * 60,player.Damage * 0.05,0,col,player,0.1,false,false)
					end
				end
				if d[item.own_key.."Dual_effect"]:IsEventTriggered("Remove") then
					d[item.own_key.."Dual_effect"] = nil
					d[item.own_key.."Dual"] = nil
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = EntityType.ENTITY_PLAYER,
Function = function(_,ent, amt, flag, source, cooldown)
	local d = ent:GetData()	
	if ent.Type == 1 and ent:ToPlayer():GetPlayerType() == item.entity then
		local player = ent:ToPlayer()
		if player:HasCollectible(316) and player:HasCollectible(260) == false and (d[item.own_key.."cursed_counter"] or 0) > 0 then	--受伤传送
			player:AnimateTeleport(true)
			player:UseActiveItem(CollectibleType.COLLECTIBLE_TELEPORT,false,true,false,false)
			d[item.own_key.."cursed"] = 0
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_LASER_UPDATE, params = nil,
Function = function(_,ent)
	local room = Game():GetRoom()
	local level = Game():GetLevel()
	local d = ent:GetData()
	if d.followParent and d.followParent:Exists() and not d.followParent:IsDead() then
		local pos = d.followParent.Position
		if d.followParent_offset_position then
			pos = pos + d.followParent_offset_position
		end
		ent.Position = pos
	end
	if d.followRotation and d.followRotation:Exists() then
		local ang = 180
		if d.followRotation_aidang then
			ang = d.followRotation_aidang + ang
		end
		ent.Angle = ang + d.followRotation.Velocity:GetAngleDegrees()
	end
	if d.reset_startp and d.reset_startp == true then
		if d.reset_startp_source and d.reset_startp_source:Exists() == true then
			d.reset_startp_position = d.reset_startp_source.Position
		end
		if d.reset_startp_position == nil then
			d.reset_startp_position = room:GetCenterPos()
		end
		ent.EndPoint = d.reset_startp_position
		ent:SetMaxDistance((ent.Position - d.reset_startp_position):Length())
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.MC_EVALUATE_IMITATE_ITEM, params = nil,
Function = function(_,player,colid,value)
	if player:GetPlayerType() == item.entity then
		local d = player:GetData()
		local idx = d.__Index
		local weap = auxi.get_weapon(player)
		save.elses.Qing_ludo_buff = save.elses.Qing_ludo_buff or {}
		save.elses.Qing_knife_buff = save.elses.Qing_knife_buff or {}
		if (auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_DR_FETUS) and weap == 7) or (save.elses.Qing_knife_buff[idx] and weap == 4) or (save.elses.Qing_ludo_buff[idx] and weap == 1) then
			save.elses.Qing_knife_buff[idx] = true
			value[114] = (value[114] or 0) + 1
			save.elses.Qing_ludo_buff[idx] = nil
		else
			if (auxi.has_have_coll(player,CollectibleType.COLLECTIBLE_IPECAC) and weap == 1) or weap == 7 or (save.elses.Qing_ludo_buff[idx] and weap == 8) then
				save.elses.Qing_ludo_buff[idx] = true
				value[329] = (value[329] or 0) + 1
			else
				save.elses.Qing_ludo_buff[idx] = nil
			end
			save.elses.Qing_knife_buff[idx] = nil
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_DESCRIPT_ITEM, params = nil,
Function = function(_,player,tp,id,value)
	if player:GetPlayerType() == item.entity then
		local ret = nil
		local language = Options.Language
		local infos = (item.Special_Des[language] or {})[tp]
		if infos == nil then return end
		local info = infos[id]
		if info == nil then return end
		ret = {Name = info.Name or value.Name,Description = info.Description or value.Description,}
		return ret
	end
end,
})

--- Gello 等宝宝：从 origin 沿 aim_dir 复用当前武器分支；不推进玩家 Delay/State，不复制 Incubus。
function item.fire_familiar_attack(player, request)
	request = request or {}
	if not player then return {fired = false} end
	local CharacterFamiliars = require("Qing_Remaster_scripts.mimics.Character_Advanced_Familiars_holder")
	local d = player:GetData()
	local list = d.Qing_list or auxi.get_qing_list(player)
	local origin = request.origin or (request.source and request.source.Position) or player.Position
	local aim = request.aim_dir or Vector(0, 1)
	if aim:Length() < 0.01 then aim = Vector(0, 1) end
	local mul = tonumber(request.damage_mul) or 0.75
	local weap = auxi.get_weapon(player)
	if player:HasCollectible(258) then
		weap = auxi.choose(1, 2, 3, 4, 5, 6, 7, 9, 13, 14, 15)
	end
	if player:HasCollectible(191) then
		weap = d[item.own_key.."ThreeDoll"] or weap
	end
	local attack_params = auxi.get_Qing_multishots(player, list)
	local delay_out = player.MaxFireDelay
	local state = d[item.own_key.."State"] or 0
	for i = #attack_params, 1, -1 do
		local info = attack_params[i]
		local dir = auxi.MakeVector(info.dir + aim:GetAngleDegrees())
			* math.max(0.6, math.min(3, 0.7 * player.ShotSpeed + 0.3 + math.log(player.TearRange / 260)))
		local local_weap = weap
		if player:HasCollectible(418) and math.random(1000) > 800 then
			local_weap = auxi.choose(1, 2, 3, 4, 5, 6, 7, 9, 13, 14, 15)
		end
		if (list.tech9 or 0) > 0 then
			if math.random(1000) > 850 then local_weap = 3 end
			if math.random(1000) > 850 then local_weap = 9 end
		end
		if local_weap == 1 and (list.hae or 0) > 0 then local_weap = 15 end
		local weap_listinfo = auxi.check_if_any(item.attack_list[local_weap], item) or item.attack_list[1]
		local weapinfo = item.attack_list[info.Anim] or weap_listinfo[state] or item.attack_list[1][0]
		local tearHitParams = player:GetTearHitParams(WeaponType.WEAPON_TEARS, 1, auxi.choose(0, 1))
		local call_params = {
			tearflag = CharacterFamiliars.apply_familiar_tear_flags(player, info.tearflag),
			color = info.color,
			state = state,
			weap = local_weap,
			list = list,
			charge = mul,
			pos = origin,
			advanced_familiar_copy = true,
			source = request.source,
		}
		local ret = auxi.check_if_any(weapinfo, player, dir, tearHitParams, weapinfo, item, call_params) or {}
		if type(ret) == "number" then ret = {mul = ret} end
		if i == 1 then
			delay_out = ret.delay or (player.MaxFireDelay * (ret.mul or 1)) * (auxi.check_if_any(weap_listinfo.delaymul, player) or 1)
			delay_out = auxi.check_if_any(weap_listinfo.delay, player, delay_out) or delay_out
		end
	end
	return {fired = true, delay = delay_out}
end

CharacterAttackCompat.register(item.entity, {
	key = "qing",
	module = "Qing_Remaster_scripts.player.player_wq",
	advanced_familiars = true,
	familiar_attack = item.fire_familiar_attack,
	capabilities = {projectile = true, volley = true, charge = true, weapon_morph = true},
})

return item
