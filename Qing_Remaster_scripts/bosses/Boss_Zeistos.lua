local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local AI = require("Qing_Remaster_scripts.bosses.Boss_All")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Zeis_helper = require("Qing_Remaster_scripts.bosses.Boss_ZeistosHelper")
local CompletionMarks = require("Qing_Remaster_scripts.core.completion_marks_manager")

local item = {
	ToCall = {},
	own_key = "Boss_Zeistos_",
	entity = enums.Enemies.Zeistos,
	Swapper = {
		["Appear"] = "Idle",
		["MiscAppear"] = "Pickup2Float",
		["Pickup2Float"] = "Idle",
		["BossAppear"] = "Idle",
		["MiscFloat"] = "Idle",
		["MiscPickup"] = "PickupIdle",
		["MiscTeleportUp"] = function(ent,item) auxi.check_if_any(ent:GetData()[item.own_key.."Teleport"],ent,item) return "MiscTeleportDown" end,
		["MiscTeleportDown"] = "Idle",
	},
	Inhitible = {
		["MiscTeleportUp"] = true,
		["MiscTeleportDown"] = true,
	},
	Item_info = {
		[1] = {tear = 1,},
		[2] = {tearrate = 0.5,tearmul = 2,proi = 1,},
		[3] = {tearflag = 2,proi = 2,},
		[4] = {damage = 1,},
		[5] = {tearflag = 8,damage = 1,},
		[6] = {tear = 1,},
		[7] = {damage = 1,},
		--[8] = {damage = 1,},	--?
		--[9] = {fly = 5,proi = -2,},	--?
		--[10] = {efly = 2,proi = -1,},	--?
		--[11] = {life = 1,},
		[12] = {scale = 1.5,damage = 1,health = 1,proi = 1,},
		[13] = {speed = 1,},		--
		[14] = {speed = 1,},
		--[15] = {health = 1,},
		--[16] = {health = 1,},
		--[17] = {speed = 1,},
		--[18] = {speed = 1,},
		--[19] = {speed = 1,},
		--[20] = {speed = 1,},
		--[21] = {speed = 1,},
		--[22] = {health = 1,},
		--[23] = {health = 1,},
		--[24] = {health = 1,},
		--[25] = {health = 1,},
		--[26] = {health = 1,},
		[27] = {speed = 1,},
		[28] = {speed = 1,},
		--[29] = {speed = 1,},
		--[30] = {speed = 1,},
		--[31] = {speed = 1,},
		[32] = {tear = 1,},
		--[33] = {speed = 1,},
		[34] = {damage = 1,},
		--[35] = {speed = 1,},
		--[36] = {speed = 1,},
		--[37] = {speed = 1,},	--
		--[38] = {speed = 1,},	--
		--[39] = {speed = 1,},
		--[40] = {speed = 1,},	--
		--[41] = {speed = 1,},
		--[42] = {speed = 1,},
		--
		--[44] = {speed = 1,},	--
		[45] = {health = 1,},
		--[46] = {speed = 1,},
		--[47] = {speed = 1,},	--
		[48] = {tearflag = 0,proi = -2,},
		--[49] = {speed = 1,},	--
		[50] = {damage = 1,},
		[51] = {damage = 1,},
		[52] = {Dr = 1,},
		--[53] = {speed = 1,},
		--[54] = {speed = 1,},
		--[55] = {speed = 1,},	--
		--[56] = {speed = 1,},	--
		--[57] = {speed = 1,},	--?
		--[58] = {speed = 1,},	--
		--[59] = {speed = 1,},	--
		--[60] = {speed = 1,},
		[62] = {damage = 1,},
		--[63] = {speed = 1,},
		--[64] = {speed = 1,},
		--[65] = {speed = 1,},	--
		--[66] = {speed = 1,},
		--[67] = {speed = 1,},	--?
		[68] = {Tech = 1,},
		--[69] = {},
		[70] = {damage = 1,speed = 1,},
		[71] = {speed = 1,},
		[72] = {tear = 1,},
		--[73] = {},	--
		--[74] = {},
		--[75] = {},
		--[76] = {},
		--[77] = {},
		--[78] = {},
		[79] = {damage = 1,speed = 1,},
		[80] = {damage = 1,speed = 1,},
		--[81] = {},	--
		[82] = {speed = 1,},
		[83] = {damage = 1,},
		--[84] = {},
		--[85] = {},
		--[86] = {},	--
		--[87] = {},	--
		--[88] = {},
		--[89] = {tearflag = 3,},
		[90] = {damage = 1,},
		--[93] = {},
		[101] = {damage = 1,speed = 1,tear = 1,},
		--103
		--104
		--110
		[114] = {Knife = 1,},
		[115] = {tear = 1,},
		[117] = {Bird = 1,},
		[118] = {Brim = 1,},
		[119] = {speed = 1,},
		[120] = {tear = 1,speed = 1,},
		[121] = {damage = 1,},
		[122] = {damage = 1,speed = 1,},
		--126
		--127
		--130
		[132] = {tearflag = 7,},
		[138] = {damage = 1,},
		[143] = {speed = 1,},
		[149] = {Ipec = 1,},
		--151
		[152] = {Tech2 = 1,},
		[153] = {tearrate = 0.3,tearmul = 3,proi = 1,},
		[160] = {Holy = 1,},
		[165] = {damage = 1,},
		[168] = {Epic = 1,},
		--[169] = {damage = 1,},
		--181
		[182] = {Holy = 1,damage = 1,},
		[183] = {tear = 1,},
		[189] = {damage = 1,speed = 1,tear = 1,},
		--190
		--191
		[192] = {damage = 1,},
		[196] = {tear = 1,},
		[197] = {damage = 1,},
		--200
		[201] = {damage = 1,},	--
		--202
		[208] = {damage = 1,},
		--213
		[216] = {damage = 1,},
		--217
		--221
		--222
		--223
		--224
		--228
		[229] = {Lung = 1,},
		[230] = {damage = 1,speed = 1,},
		[232] = {Slow = 1,speed = 1,},
		--233
		[237] = {damage = 1,},
		--240
		[244] = {Tech5 = 1,},
		[245] = {tearmul = 1,},
		[255] = {tear = 1,},
		--257
		[259] = {damage = 1,},	--
		--261
		--282
		--283
		--284
		--289
		--293
		[300] = {speed = 1,},
		--304
		--305
		[306] = {speed = 1,},
		[307] = {damage = 1,speed = 1,tear = 1,},
		--308
		[309] = {tear = 1,},
		[310] = {damage = 1,},
		--313
		--315
		[316] = {Cursed = 1,},
		--317
		--323
		--326
		[329] = {Ludo = 1,},
		--330
		--331
		--338
		[340] = {speed = 1,},
		[341] = {tear = 1,},
		[342] = {tear = 1,},
		[345] = {damage = 1,},
		--347
		--350
		--358
		[359] = {damage = 1,},
		--360
		--369
		[370] = {tear = 1,},
		--371
		--373
		[374] = {Holy = 1,},
		--375
		[381] = {tear = 1,},
		[395] = {TechX = 1,},
		[399] = {Maw = 1,},
		--401
		[408] = {Maw = 1,},
		--410
		[415] = {damage = 1,},		--
		
	},
	Info = {
		[1] = {
			{frame = 0,pos = Vector(0,-20),},
		},
		[2] = {
			{frame = 0,pos = Vector(0,-400),},
			{frame = 30,pos = Vector(0,-100),},
			{frame = 90,pos = Vector(0,-20),},
		},
	},
	binfo = {
		[1] = {
			{frame = 0,leg = 10,},
			{frame = 30,leg = 60,},
			{frame = 3 * 30,leg = 80,},
			total = 10 * 30,
		},
	},
	pickup_info = {
		{frame = 0,pos = Vector(0,-10),scale = Vector(1,1),},
		{frame = 2,pos = Vector(0,-26),scale = Vector(1,1),},
		{frame = 4,pos = Vector(0,-14),scale = Vector(1,1),},
		{frame = 6,pos = Vector(0,-28),scale = Vector(1,1),},
		{frame = 8,pos = Vector(0,-25),scale = Vector(1,1),},
	},
	Assign_limit = 0,
}

function item.pickup_allow()
	if save.elses[item.own_key.."Pickup"] == nil then return true end
end

function item.player_pickup(player,st)
	save.elses[item.own_key.."Pickup"] = save.elses[item.own_key.."Pickup"] or {}
	table.insert(save.elses[item.own_key.."Pickup"],#save.elses[item.own_key.."Pickup"] + 1,{id = st,})
end
--l local boss_zeis = require("Qing_Remaster_scripts.bosses.Boss_Zeistos") boss_zeis.search_for()
function item.search_for()
	local tgs = auxi.getothers(5,100,nil,function(ent) if ent:ToPickup().OptionsPickupIndex == 1 and ent.SubType ~= 0 then return true end end)
	local tbl = {}
	save.elses[item.own_key.."record"] = save.elses[item.own_key.."record"] or {}
	for u,v in pairs(tgs) do 
		local st = v.SubType
		if item.Item_info[st] then 
			table.insert(tbl,#tbl + 1,v) 
		end
	end
	return auxi.random_in_table(tbl) or auxi.random_in_table(tgs)
end

function item.search()
	return auxi.random_in_table(Zeis_helper.get_table())
end

function item.start(ent)
	local music = MusicManager()
	if (music:GetCurrentMusicID() ~= enums.Music.Origin_1) then
		music:Play(enums.Music.Origin_1,0)
		music:UpdateVolume()
	end
	local tgs = auxi.getothers(996,item.entity)
	if #tgs == 0 and auxi.check_all_exists(ent) ~= true then Isaac.Spawn(996,item.entity,0,Game():GetRoom():GetCenterPos(),Vector(0,0),nil)
	else for i = 1,#tgs do tgs[i]:Remove() end end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_RENDER, params = 996,
Function = function(_,ent)
	if Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT then
		local d = ent:GetData()
		local ainfo = d[item.own_key.."Ainfo"]
		if ainfo then
			local s = ent:GetSprite()
			local anim = s:GetAnimation()
			local frame = s:GetFrame()
			if ainfo.name == "Assign" and anim == "MiscPickup" then
				local s2 = auxi.load_item(ainfo.st)
				local info = auxi.check_lerp(frame,item.pickup_info)
				s2:Render(Isaac.WorldToScreen(ent.Position + info.pos + ent.PositionOffset),Vector(0,0),Vector(0,0))
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = 996,
Function = function(_,ent)
	if ent.Variant == item.entity then
		local s = ent:GetSprite()
		local d = ent:GetData()
		local anim = s:GetAnimation()
		local frame = s:GetFrame()
		local finished = s:IsFinished(anim)
		if finished then
			local tg = auxi.check_if_any(item.Swapper[anim],ent,item)
			if d[item.own_key.."Nx_sw"] then 
				tg = auxi.check_if_any(d[item.own_key.."Nx_sw"][1],ent,item) or tg
				table.remove(d[item.own_key.."Nx_sw"],1)
				if #d[item.own_key.."Nx_sw"] == 0 then d[item.own_key.."Nx_sw"] = nil end
			end
			if tg then s:Play(tg,true) end
		end
		if ent.PositionOffset.Y < -40 or auxi.check_if_any(item.Inhitible[anim],ent,frame) then ent.EntityCollisionClass = 0 
		else ent.EntityCollisionClass = 2 end
		
		AI.Control_Move(ent)
		local succ = AI.Control_Attack(ent)
		if succ == nil and ((d[item.own_key.."Ainfo"] or {}).Help or anim == "Idle") then
			local hpc = ent.HitPoints/ent.MaxHitPoints
			local tbl = {
				{name = "Normal",weigh = 100,dcwei = 1,},
				{name = "Teleport",weigh = 40,},
			}
			local ainfo = nil
			if hpc > 0.6 then
				d[item.own_key.."AssignCounter"] = (d[item.own_key.."AssignCounter"] or 0) + 1
				if d[item.own_key.."AssignCounter"] > item.Assign_limit then
					table.insert(tbl,#tbl + 1,{name = "Assign",weigh = 200,})
					d[item.own_key.."AssignCounter"] = nil
				end
			end
			if hpc < 0.8 and hpc > 0.4 then
				table.insert(tbl,{name = "Assign2",weigh = 100 * auxi.guass_dis(hpc,0.8,0.3),})
				if Zeis_helper.count_helper() >= 2 then table.insert(tbl,{name = "Aggregate",weigh = 200 * auxi.guass_dis(hpc,0.6,0.3),}) end
			end
			if hpc < 0.6 then
				table.insert(tbl,{name = "Laser",weigh = 150 * auxi.guass_dis(hpc,0.6,0.3),})
				table.insert(tbl,{name = "Wrapper",weigh = 200 * auxi.guass_dis(hpc,0.5,0.2),})
				table.insert(tbl,{name = "Assign3",weigh = 200 * auxi.guass_dis(hpc,0.6,0.4),})
			end
			if hpc < 0.4 then
				table.insert(tbl,{name = "Assign4",weigh = 200,})
				table.insert(tbl,{name = "Darklaser",weigh = 200,})
				if Zeis_helper.count_helper() >= 2 then table.insert(tbl,{name = "Aggregate2",weigh = 250,}) end
			end
			if hpc < 0.2 then
				
			end
			if hpc <= 0.4 and save.elses["Thread_Zeis_effect"] and save.elses["Thread_Zeis_effect"].Transfer == nil then 		--transfer
				tbl = {{name = "Transfer",weigh = 100,},} 
				--save.elses["Thread_Zeis_effect"].Transfer = {}		--之后在这里copy其他item的状态
			end
			if d[item.own_key.."Ainfo"] then
				if (d[item.own_key.."Ainfo"].countinue or 0) > 0 then 
					ainfo = d[item.own_key.."Ainfo"] 
					ainfo.countinue = ainfo.countinue - 1 
				else
					for u,v in pairs(tbl) do
						if v.name == d[item.own_key.."Ainfo"].name then v.weigh = v.weigh * (d[item.own_key.."Ainfo"].dcwei or 0.3) end
					end
				end
			end
			if ainfo == nil then ainfo = auxi.random_in_weighed_table(tbl) end
			if ainfo.name == "Normal" then
				s:Play("MiscFloat",true)
				AI.AddAttackDelay(ent,30)
				local target = auxi.get_acceptible_target(ent)
				local tbl = auxi.make_lerp({cnt = 2,mul = 10,})
				local tgpos = target.Position
				local pos = auxi.ProtectVector(ent.Position)
				local pos2 = Game():GetRoom():GetClampedPosition(ent.Position + auxi.get_by_rotate(tgpos - ent.Position,auxi.random_2() * 60,50 + auxi.random_1() * 100),-40)
				tbl = auxi.set_to(tbl,auxi.cut_by(function(val) return auxi.Bezier({pos,(pos + pos2) * 0.5,(pos + pos2) * 0.5,pos2,},val) end,10),"pos")
				AI.move_in_inval(ent,tbl,30,function(ent,frame,info) 
					if frame == 15 then 
						local projparams = ProjectileParams()
						local dir = target.Position - ent.Position
						local cnt = 6
						for i = 1,cnt do
							local q = Isaac.Spawn(9,0,0,ent.Position,auxi.get_by_rotate(dir,i * 360/cnt,10),ent):ToProjectile()
							local d = q:GetData()
							d[item.own_key.."effect"] = {tg = ent,AddAngle = i,state = 1,}
							q:SetColor(Color(0,0,0,1),15,99,true,true)
						end
					end
				end)
			elseif ainfo.name == "Assign" then		--切换房间会导致出错
				AI.AddAttackDelay(ent,999)
				s:Play("MiscFloat",true)
				local tg = item.search_for()
				if auxi.check_all_exists(tg) then
					local d3 = tg:GetData()
					local pos = auxi.ProtectVector(ent.Position)
					local pos2 = tg.Position
					local tbl = auxi.make_lerp({cnt = 2,mul = 10,})
					tbl = auxi.set_to(tbl,auxi.cut_by(function(val) return auxi.Bezier({pos,(pos + pos2) * 0.5,(pos + pos2) * 0.5,pos2,},val) end,10),"pos")
					AI.move_in_inval(ent,tbl,30)
					ainfo.st = tg.SubType
					d[item.own_key.."Nx_sw"] = {"MiscPickup",function() Zeis_helper.spawn_helper(ainfo.st,ent.Position,Vector(0,0),ent) return "Pickup2Float" end,function() AI.AddAttackDelay(ent,0) end,}
				else
					ainfo.st = item.search()
					s:Play("MiscPickup",true)
					d[item.own_key.."Nx_sw"] = {function() Zeis_helper.spawn_helper(ainfo.st,ent.Position,Vector(0,0),ent) return "Pickup2Float" end,function() AI.AddAttackDelay(ent,0) end,}
				end
				ainfo.special = function(ent,ainfo) if ent:GetSprite():GetAnimation() == "MiscPickup" and ent:GetSprite():GetFrame() == 8 then sound_tracker.PlayStackedSound(SoundEffect.SOUND_POWERUP1,1,1,false,0,2) end	end
				--save.elses[item.own_key.."record"] = save.elses[item.own_key.."record"] or {}
				--save.elses[item.own_key.."record"][ainfo.st] = (save.elses[item.own_key.."record"][ainfo.st] or 0) + 1
			elseif ainfo.name == "Assign2" then
				AI.AddAttackDelay(ent,999)
				s:Play("MiscPickup",true)
				ainfo.st = item.search()
				d[item.own_key.."Nx_sw"] = {function() Zeis_helper.spawn_helper(ainfo.st,ent.Position,Vector(0,0),ent) return "Pickup2Float" end,function() AI.AddAttackDelay(ent,0) end,}
				ainfo.special = function(ent,ainfo) if ent:GetSprite():GetAnimation() == "MiscPickup" and ent:GetSprite():GetFrame() == 8 then sound_tracker.PlayStackedSound(SoundEffect.SOUND_POWERUP1,1,1,false,0,2) end	end
			elseif ainfo.name == "Teleport" then
				s:Play("MiscTeleportUp",true)
				AI.AddAttackDelay(ent,999)
				d[item.own_key.."Teleport"] = function(ent,item)
					local d = ent:GetData()
					ent.Position = Game():GetRoom():GetRandomPosition(0)
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_HELL_PORTAL2,1,1,false,0,2)
					d[item.own_key.."Teleport"] = nil
				end
				d[item.own_key.."Nx_sw"] = {function() end,function() AI.AddAttackDelay(ent,0) end,}
			end
			d[item.own_key.."Ainfo"] = ainfo
		end
		local ainfo = d[item.own_key.."Ainfo"]
		if ainfo then auxi.check_if_any(ainfo.special,ent,ainfo) end
		if anim == "MiscAppear" then
			local info = auxi.check_lerp(frame,item.Info[2])
			ent.PositionOffset = info.pos
		else
			ent.PositionOffset = ent.PositionOffset * 0.5 + Vector(0,-20) * 0.5
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local tgs = auxi.getothers(nil,996,item.entity)
	for u,v in pairs(tgs) do 
		v.Position = v.Position + unique_holder.Room_Shift_offset
		AI.ClearMovement(v)
		AI.AddAttackDelay(v,1)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PROJECTILE_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		local info = d[item.own_key.."effect"]
		local parent = d[item.own_key.."effect"].tg or ent.SpawnerEntity
		if auxi.check_all_exists(parent) ~= true then d[item.own_key.."effect"] = nil return end
		if info.state == 1 then
			ent.FallingSpeed = 0
			local binfo = auxi.check_lerp(ent.FrameCount,item.binfo[1])
			local tg_pos = parent.Position + auxi.MakeVector((info.AddAngle or 0) * 60 + parent.FrameCount * 5) * binfo.leg
			ent.Velocity = tg_pos - ent.Position
			if ent.FrameCount >= item.binfo[1].total then info.state = 2 end
		elseif info.state == 2 then
			local tg_pos = ent.Position - parent.Position
			ent.Velocity = tg_pos
			info.state = nil
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_INIT, params = 996,
Function = function(_,ent)
	if ent.Variant == item.entity then
		AI.basic(ent,{Friction = 0.5,})
		ent:AddEntityFlags(EntityFlag.FLAG_PERSISTENT)
		ent:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
		local s = ent:GetSprite()
		local d = ent:GetData()
		item.start(ent)
		s:Play("BossAppear",true)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_KILL, params = 996,
Function = function(_,ent)
	if ent.Variant == item.entity then
		CompletionMarks.complete_extra_all_players("boss.zeis")
	end
end,
})

return item
