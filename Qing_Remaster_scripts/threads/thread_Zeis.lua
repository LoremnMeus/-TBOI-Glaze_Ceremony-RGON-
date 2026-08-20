local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local console_holder = require("Qing_Remaster_scripts.others.Console_holder")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local player_offset_holder = require("Qing_Remaster_scripts.callbacks.player_offset_holder")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")
local collectible_holder = require("Qing_Remaster_scripts.callbacks.collectible_holder")
local boss_zeis = require("Qing_Remaster_scripts.bosses.Boss_Zeistos")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	own_key = "Thread_Zeis_",
	entity = enums.Entities.ZeistosHelper,
	limit1 = 4,
	limit2 = 6,
	colorinfo = {
		{frame = 0,A = 0,RO = -1,GO = -1,BO = -1,},
		{frame = 100,A = 0.25,RO = -0.8,GO = -0.8,BO = 0,},
		{frame = 300,A = 0.5,RO = -0.4,GO = -0.4,BO = 0,},
		{frame = 800,A = 1,RO = 0,GO = 0,BO = 0,},
	},
	colorinfo2 = {
		{frame = 0,A = 0.5,RO = 0.5,GO = 0.5,BO = 0.75,},
		{frame = 100,A = 0.625,RO = 0.25,GO = 0.25,BO = 0.5,},
		{frame = 300,A = 0.75,RO = 0.1,GO = 0.1,BO = 0.25,},
		{frame = 800,A = 1,RO = 0,GO = 0,BO = 0.1,},
	},
	frame2speed = {
		{frame = 0,rate = 0.5,},
		{frame = 30,rate = 0.75,},
		{frame = 60,rate = 0.95,},
	},
	sevants = {
		[1] = {pos = Vector(60,-30),id = 1,},
		[2] = {pos = Vector(-60,-30),id = 2,},
		[3] = {pos = Vector(-100,20),id = 3,},
		[4] = {pos = Vector(0,40),id = 4,},
		[5] = {pos = Vector(100,20),id = 5,},
	},
	Words = {
		zh = {
			[1] = "难以言喻的喜悦笼罩着你",
			[2] = "你为至今所得沾沾自喜",
			[3] = "傲慢蒙蔽了你的双眼，直到...",
			[4] = "泽·伊斯托斯 苏醒了",
		},
		en = {
			[1] = "Inexplicable joy envelops you",
			[2] = "You are proud of what you have gained so far",
			[3] = "Pride blinds your eyes, until..",
			[4] = "Ze·istos has awaked",
		},
	},
	Banisheditem = {
		[477] = true,
		[523] = true,
		[706] = true,
	},
	playerscaler = {
		{frame = 0,scale = Vector(1,1),c = 0,},
		{frame = 6,scale = Vector(0.8,1.2),c = 0,},
		{frame = 9,scale = Vector(1.3,0.7),c = 1,},
		{frame = 12,scale = Vector(1,1),c = 0,},
	},
	banish_button = {
		[0] = true,
		[1] = true,
		[2] = true,
		[3] = true,
		[4] = true,
		[5] = true,
		[6] = true,
		[7] = true,
		[8] = true,
		[9] = true,
		[10] = true,
		[11] = true,
	},
	spiltinfo = {
		4,
		6,
		8,
		8,
		10,
		10,
	},
	spiltrate = {
		{frame = 0,rate = 0.01,cnt = 1,},
		{frame = 20,rate = 0.02,cnt = 2,},
		{frame = 60,rate = 0.04,cnt = 3,},
		{frame = 2 * 60,rate = 0.06,cnt = 4,},
	},
	Sleepoffset = {
		{frame = 0,offset = Vector(0,0),counter = 1,},
		{frame = 30,offset = Vector(0,0),counter = 2,},
		{frame = 5 * 60,offset = Vector(0,-50),counter = 5,},
	},
	Teleportoffset = {
		{frame = 0,offset = Vector(0,-50),},
		{frame = 10,offset = Vector(0,-40),},
		{frame = 60,offset = Vector(0,-400),},
	},
	Teleport2offset = {
		{frame = 0,offset = Vector(0,-400),},
		{frame = 30,offset = Vector(0,0),},
	},
	Zeisrender = {
		{frame = 0,R = 1,G = 1,B = 1,A = 0.5,},
		{frame = 35,R = 0,G = 0,B = 0,A = 1,},
		{frame = 40,R = 0,G = 0,B = 0,A = 0,},
	},
	Zeisscaler = {
		{frame = 0,scale = Vector(1,1),},
		{frame = 30,scale = Vector(1,1),},
		{frame = 35,scale = Vector(1.2,1.2),},
		{frame = 37,scale = Vector(0.7,1.3),},
		{frame = 40,scale = Vector(1,1),},
	},
	Description = {
		Name = "Boss战：泽·伊斯托斯",
		Description = "在战斗的间隙取回失去的道具#注意敌人也会随之变强",
	},
}
--l local player = Game():GetPlayer(0) player:QueueItem(Isaac.GetItemConfig():GetCollectible(15),0,true) player:FlushQueueItem()
--l local n_entity = Isaac.GetRoomEntities() for u,v in pairs(n_entity) do if v.Type == 5 then v:ToPickup().OptionsPickupIndex = 0 end end
--l local thread_Zeis = require("Qing_Remaster_scripts.threads.thread_Zeis") thread_Zeis.re_start() thread_Zeis.get_start()
function item.pre_start()
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
end

function item.get_info() 
	return save.elses[item.own_key.."effect"] or {}
end

function item.GetZeis()
	if auxi.check_all_exists(item.Zeis) ~= true then
		local q2 = Isaac.Spawn(1000,item.entity,0,Game():GetRoom():GetCenterPos(),Vector(0,0),nil):ToEffect()
		item.Zeis = q2
		local s2 = q2:GetSprite()
		s2:Load("gfx/boss/Zeistos/Zeistos.anm2",true)
		s2:Play("IdlePickup",true)
		s2.Color = Color(1,1,1,0)
		q2.DepthOffset = -10
		q2.PositionOffset = Vector(0,-100)
		local d2 = q2:GetData()
		d2[item.own_key.."Zeis"] = {}
	end
	return item.Zeis
end

function item.AddZeis()
	local q = item.GetZeis()
	q:GetData()[item.own_key.."Zeis"].Loadcounter = (q:GetData()[item.own_key.."Zeis"].Loadcounter or 0) + 1
end

function item.get_start() 
	if not item.is_start() then
		save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {} 
		save.elses[item.own_key.."effect"].Start = true
		save.elses[item.own_key.."effect"].PreStart = true
		local pos = Game():GetRoom():GetCenterPos()
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			local q = Isaac.Spawn(1000,193,0,pos,Vector(0,0),player):ToEffect()
			player:GetData()[item.own_key.."Tear"] = {Linker = q,}
			q.Target = player
			q:GetSprite().Color = Color(0,0,1,1)
		end
		local player = Game():GetPlayer(0)
		local q = auxi.fire_nil(pos,Vector(0,0),{cooldown = 9999999,})
		q.DepthOffset = -100
		local s = q:GetSprite()
		s:Load("gfx/boss/Zeistos/Pentagram.anm2",true)
		s:Play("Appear",true)
		for i = 1,#item.sevants do
			local v = item.sevants[i]
			local q = Isaac.Spawn(1000,item.entity,0,v.pos + pos,Vector(0,0),nil):ToEffect()
			q.DepthOffset = 100
			q.Target = player
			local d2 = q:GetData()
			d2[item.own_key.."Sevant"] = {id = i,tgpos = pos,}
			local s2 = q:GetSprite()
			s2:Load("gfx/boss/Zeistos/dark_fanatic.anm2",true)
			s2:Play("SummonLoop"..tostring(v.id),true)
			s2.Color = Color(1,1,1,0)
		end
	end
end

function item.to_start()
	if save.elses[item.own_key.."effect"] and (not save.elses[item.own_key.."effect"].Start) and (not save.elses[item.own_key.."effect"].End) then return true end
end

function item.re_start()
	save.elses[item.own_key.."effect"] = nil
end

function item.is_start()
	if save.elses[item.own_key.."effect"] and save.elses[item.own_key.."effect"].Start and (not save.elses[item.own_key.."effect"].End) then return true end
end

function item.has_started()
	if save.elses[item.own_key.."effect"] and save.elses[item.own_key.."effect"].Start and (not save.elses[item.own_key.."effect"].PreStart) and (not save.elses[item.own_key.."effect"].End) then return true end
end

function item.is_pre_start()
	if save.elses[item.own_key.."effect"] and save.elses[item.own_key.."effect"].PreStart and (not save.elses[item.own_key.."effect"].End) then return true end
end

function item.remove_and_record(player,colid)
	local idx = player:GetData().__Index
	player:RemoveCollectible(colid)
	save.elses[item.own_key.."Record"] = save.elses[item.own_key.."Record"] or {}
	save.elses[item.own_key.."Record"][idx] = save.elses[item.own_key.."Record"][idx] or {}
	save.elses[item.own_key.."RecordOn"] = save.elses[item.own_key.."RecordOn"] or {}
	save.elses[item.own_key.."RecordOn"][colid] = (save.elses[item.own_key.."RecordOn"][colid] or 0) + 1
	table.insert(save.elses[item.own_key.."Record"][idx],#save.elses[item.own_key.."Record"][idx] + 1,colid)
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
		if item.is_pre_start() then item.re_start() item.get_start() end
	else
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local s = player:GetSprite()
	if d[item.own_key.."Tear"] then
		d[item.own_key.."Tear"].counter = (d[item.own_key.."Tear"].counter or 0) + 1
		if d[item.own_key.."Tear"].counter >= 3 * 60 then
			d[item.own_key.."Tear"].updater = (d[item.own_key.."Tear"].counter % 30)/2
			if d[item.own_key.."Tear"].updater == 9 then
				local rng = player:GetCollectibleRNG(33)
				local rnd = rng:RandomInt(3) + 1 + (d[item.own_key.."Tear"].rnd or 0)
				d[item.own_key.."Tear"].rnd = (d[item.own_key.."Tear"].rnd or 0) + 2
				for i = 1,rnd do
					local colid = auxi.get_random_item_that_player_has(player,rng,{ignore_pocket_item = true,})
					if colid then
						item.remove_and_record(player,colid)
						local q = Isaac.Spawn(1000,item.entity,0,player.Position,auxi.RoundVector(nil,30),nil):ToEffect()
						local s = q:GetSprite()
						local d2 = q:GetData()
						d2[item.own_key.."Energy"] = {id = colid,tgpos = player.Position + Vector(0,-100),}
						auxi.load_item(colid,{sprite = s,})
						q.PositionOffset = Vector(0,8)
						s.Color = Color(1,1,1,1,1,1,1)
					else
						if i == 1 then
							d[item.own_key.."Tear"].Limit = (d[item.own_key.."Tear"].Limit or 0) + 1
							local cnt = item.spiltinfo[d[item.own_key.."Tear"].Limit]
							for j = 1,cnt do 
								local q = Isaac.Spawn(1000,item.entity,0,player.Position,auxi.RoundVector(nil,30),nil):ToEffect()
								local s2 = q:GetSprite()
								local d2 = q:GetData()
								d2[item.own_key.."Energy"] = {tgpos = player.Position + Vector(0,-100),soul = true,}
								s2:Load("gfx/boss/Zeistos/Item_soul.anm2",true)
								s2:Play("Idle",true)
								s2.Color = Color(1,1,1,1,1,1,1)
								q.PositionOffset = Vector(0,13)
							end
						end
						break
					end
				end
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_PLOP,1,1,false,0,2)
			end
			if d[item.own_key.."Tear"].updater == 0 then
				if (d[item.own_key.."Tear"].Limit or 0) >= item.limit2 then
					if auxi.check_all_exists(d[item.own_key.."Tear"].Linker) then
						d[item.own_key.."Tear"].Linker:SetTimeout(1)
						d[item.own_key.."Tear"].Linker = nil
					end
					d[item.own_key.."Tear"] = nil
					d[item.own_key.."Sleep"] = {}
					player_offset_holder.LoadPlayer(player,true)
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_ISAACDIES,1,1,false,0,2)
				end
			end
			player:AddCacheFlags(CacheFlag.CACHE_SIZE | CacheFlag.CACHE_COLOR)
			d.should_evaluate_on_update_once = true
		end
	end
	if d[item.own_key.."Sleep"] then
		d[item.own_key.."Sleep"].counter = (d[item.own_key.."Sleep"].counter or 0) + 1
		player:AddControlsCooldown(math.max(0,3 - player.ControlsCooldown))
		player:PlayExtraAnimation("DeathTeleport")
		s:SetLastFrame()
		local fr = s:GetFrame()
		d[item.own_key.."Sleep"]["c1"] = (d[item.own_key.."Sleep"]["c1"] or 0) + 1
		fr = math.min(fr,math.floor(d[item.own_key.."Sleep"]["c1"]/2))
		s:SetFrame("DeathTeleport",fr)
		local sinfo = auxi.check_lerp(d[item.own_key.."Sleep"].counter,item.spiltrate)
		for i = 1,sinfo.cnt do 
			if auxi.random_1() < sinfo.rate then
				local q = Isaac.Spawn(1000,item.entity,0,player.Position + player_offset_holder.GetPlayerOffset(player),auxi.RoundVector(nil,60),nil):ToEffect()
				local s2 = q:GetSprite()
				local d2 = q:GetData()
				d2[item.own_key.."Energy"] = {tgpos = player.Position + Vector(0,-100),soul = true,}
				s2:Load("gfx/boss/Zeistos/Item_soul.anm2",true)
				s2:Play("Idle",true)
				s2.Color = Color(1,1,1,1,1,1,1)
				q.PositionOffset = Vector(0,13)
			end
		end
		local prate = d[item.own_key.."Sleep"].updater or 0
		d[item.own_key.."Sleep"].updater = ((d[item.own_key.."Sleep"].updater or 0) * 2 + auxi.check_lerp(d[item.own_key.."Sleep"].counter,item.Sleepoffset).counter) % 30 /2
		if prate < 9 and d[item.own_key.."Sleep"].updater >= 9 then sound_tracker.PlayStackedSound(SoundEffect.SOUND_PLOP,1,1,false,0,2) end
		player:AddCacheFlags(CacheFlag.CACHE_SIZE | CacheFlag.CACHE_COLOR)
		d.should_evaluate_on_update_once = true
	end
	if d[item.own_key.."Teleport"] then
		d[item.own_key.."Teleport"].counter = (d[item.own_key.."Teleport"].counter or 0) + 1
		player:AddControlsCooldown(math.max(0,3 - player.ControlsCooldown))
		player:PlayExtraAnimation("DeathTeleport")
		s:SetLastFrame()
		if d[item.own_key.."Teleport"].counter == 10 then sound_tracker.PlayStackedSound(SoundEffect.SOUND_HELL_PORTAL2,1,1,false,0,2) end
		if d[item.own_key.."Teleport"].counter > 10 * 30 and auxi.check_all_exists(d[item.own_key.."Teleport"].Tg) ~= true then d[item.own_key.."Teleport"] = nil	d[item.own_key.."Teleported"] = {} end
	end
	if d[item.own_key.."Teleported"] then
		
		d[item.own_key.."Teleported"].counter = (d[item.own_key.."Teleported"].counter or 0) + 1
		player:AddControlsCooldown(math.max(0,3 - player.ControlsCooldown))
		player:PlayExtraAnimation("DeathTeleport")
		s:SetLastFrame()
		if d[item.own_key.."Teleported"].counter >= 30 then
			d[item.own_key.."Teleported"].fr_ = d[item.own_key.."Teleported"].fr_ or s:GetFrame()
			s:SetFrame("DeathTeleport",math.floor(d[item.own_key.."Teleported"].fr_))
			d[item.own_key.."Teleported"].fr_ = math.max(0,d[item.own_key.."Teleported"].fr_ - 0.5)
		end
		if (d[item.own_key.."Teleported"].fr_ or 30) == 0 then d[item.own_key.."Teleported"] = nil end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHECK_PLAYER_POSITIONOFFSET, params = nil,
Function = function(_,player,value)
	local d = player:GetData()
	if d[item.own_key.."Sleep"] then
		local info = auxi.check_lerp(d[item.own_key.."Sleep"].counter or 0,item.Sleepoffset)
		value.Offset = value.Offset + info.offset
		value.Remove = false
	end
	if d[item.own_key.."Teleport"] then
		local info = auxi.check_lerp(d[item.own_key.."Teleport"].counter or 0,item.Teleportoffset)
		value.Offset = value.Offset + info.offset
		value.Remove = false
	end
	if d[item.own_key.."Teleported"] then
		local info = auxi.check_lerp(d[item.own_key.."Teleported"].counter or 0,item.Teleport2offset)
		value.Offset = value.Offset + info.offset
		value.Remove = false
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local d = player:GetData()
	if d[item.own_key.."Tear"] and d[item.own_key.."Tear"].updater then
		if cacheFlag == CacheFlag.CACHE_SIZE then
			local info = auxi.check_lerp(d[item.own_key.."Tear"].updater,item.playerscaler)
			player.SpriteScale = auxi.mul_t(player.SpriteScale,info.scale)
		end
		if cacheFlag == CacheFlag.CACHE_COLOR then
			local info = auxi.check_lerp(d[item.own_key.."Tear"].updater,item.playerscaler)
			player.Color = auxi.AddColor(player.Color,Color(1,1,1,1,1,1,1),1 - info.c,info.c)
		end
	end
	if d[item.own_key.."Sleep"] and d[item.own_key.."Sleep"].updater then
		if cacheFlag == CacheFlag.CACHE_SIZE then
			local info = auxi.check_lerp(d[item.own_key.."Sleep"].updater,item.playerscaler)
			player.SpriteScale = auxi.mul_t(player.SpriteScale,info.scale)
		end
		if cacheFlag == CacheFlag.CACHE_COLOR then
			local info = auxi.check_lerp(d[item.own_key.."Sleep"].updater,item.playerscaler)
			player.Color = auxi.AddColor(player.Color,Color(1,1,1,1,1,1,1),1 - info.c,info.c)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = item.entity,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if d[item.own_key.."Zeis"] then
		local anim = s:GetAnimation()
		if anim == "IdlePickup" then
			if (d[item.own_key.."Zeis"].Loadcounter or 0) > 0 then
				d[item.own_key.."Zeis"].Totalcounter = (d[item.own_key.."Zeis"].Totalcounter or 0) + d[item.own_key.."Zeis"].Loadcounter
				d[item.own_key.."Zeis"].Loadcounter = 0
				if d[item.own_key.."Zeis"].Rendercounter then d[item.own_key.."Zeis"].Rendercounter = math.max(35,d[item.own_key.."Zeis"].Rendercounter)
				else d[item.own_key.."Zeis"].Rendercounter = 40 end	
			end
			if (d[item.own_key.."Zeis"].Rendercounter or 0) > 0 then
				local info = auxi.check_lerp(d[item.own_key.."Zeis"].Rendercounter,item.Zeisrender)
				local info2 = auxi.check_lerp(d[item.own_key.."Zeis"].Rendercounter,item.Zeisscaler)
				ent.Color = auxi.table2color(info)
				s.Scale = info2.scale
				d[item.own_key.."Zeis"].Rendercounter = d[item.own_key.."Zeis"].Rendercounter - 1
			end
			local succ = true
			for playerNum = 1, Game():GetNumPlayers() do
				local player = Game():GetPlayer(playerNum - 1)
				if ((player:GetData()[item.own_key.."Sleep"] or {}).counter or 0) > 6 * 60 then
				else succ = false break end
			end
			if succ then
				s:Play("Pickup2Float",true)
				s.Color = Color(1,1,1,1)
				s.Scale = Vector(1,1)
				Game():ShakeScreen(30 * 2)
			end
		end
		if anim == "Pickup2Float" then
			if s:IsEventTriggered("Attack") then 
				local q = Isaac.Spawn(1000,item.entity,0,Game():GetRoom():GetCenterPos(),Vector(0,0),nil):ToEffect()
				q.DepthOffset = -10
				local d2 = q:GetData()
				local s2 = q:GetSprite()
				s2:Load("gfx/Blackout.anm2",true)
				s2:Play("Flash",true)
				s2.Color = Color(-1,-1,-1,1)
				d2[item.own_key.."Blackout"] = {}
				for playerNum = 1, Game():GetNumPlayers() do
					local player = Game():GetPlayer(playerNum - 1)
					local dp = player:GetData()
					dp[item.own_key.."Sleep"] = nil
					dp[item.own_key.."Teleport"] = {tg = q,}
				end
			end
			if s:IsFinished(anim) then s:Play("Idle",true) end
		end
	end
	if d[item.own_key.."Sevant"] then
		local id = d[item.own_key.."Sevant"].id or 1
		if auxi.check_all_exists(ent.Target) then 
			ent.Position = (d[item.own_key.."Sevant"].tgpos or ent.Target.Position) + item.sevants[id].pos
		else ent.Velocity = ent.Velocity * 0.5 end
		s.Color = auxi.AddColor(s.Color,Color(1,1,1,1),0.98,0.02)
	end
	if d[item.own_key.."Energy"] then
		d[item.own_key.."Energy"].counter = (d[item.own_key.."Energy"].counter or 0) + 1
		if d[item.own_key.."Energy"].counter >= 30 then s.Color = auxi.AddColor(s.Color,Color(0,0,0,1),0.9,0.1)
		else s.Color = auxi.AddColor(s.Color,Color(1,1,1,1),0.96,0.04) end
		s.Scale = s.Scale * 0.98 --+ Vector(0.5,0.5) * 0.02
		local dir = d[item.own_key.."Energy"].tgpos - ent.Position
		ent.Velocity = ent.Velocity * 0.9 + dir * 0.2 * 0.1
		if auxi.check_all_exists(d[item.own_key.."Energy"].tail) then
			d[item.own_key.."Energy"].tail.Position = ent.Position
			d[item.own_key.."Energy"].tail:GetSprite().Color = s.Color
		else
			local q = Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.SPRITE_TRAIL, 0, ent.Position, Vector(0,0), ent):ToEffect()
			d[item.own_key.."Energy"].tail = q
			q.MinRadius = 0.2
			q.MaxRadius = 0.15
			q.SpriteScale = Vector(1,1)
			q.Parent = ent
			q:GetSprite().Color = s.Color
		end
		if dir:Length() < 0.5 then item.AddZeis() ent:Remove() return end
	end
	if d[item.own_key.."Blackout"] then	
		if s:IsEventTriggered("Trigger") then 
			local player = Game():GetPlayer(0)
			player:UseActiveItem(CollectibleType.COLLECTIBLE_DEATH_CERTIFICATE,UseFlag.USE_NOANIM)
			player:StopExtraAnimation()
			save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
			save.elses[item.own_key.."effect"].PreStart = nil		--结束开始阶段
			local dir = -1
			if auxi.GetDimension() ~= 2 then dir = Direction.UP end
			Room_holder.Trans_to(80, dir, RoomTransitionAnim.WALK, player,2,{On_Arrive = function() 
				for playerNum = 1, Game():GetNumPlayers() do
					local player = Game():GetPlayer(playerNum - 1)
					player.Position = Game():GetRoom():GetGridPosition(85)
					player:GetData()[item.own_key.."Teleport"] = nil
					player:GetData()[item.own_key.."Teleported"] = {}
				end
				local q = Isaac.Spawn(1000,enums.Entities.EID_Descriptier,0,Game():GetRoom():GetGridPosition(auxi.choose(51,66,81)),Vector(0,0),nil)
				q.SortingLayer = 1
				local s = q:GetSprite()
				s:Load("gfx/thread/Notice_board.anm2",true) s:ReplaceSpritesheet(1,"gfx/effects/signs/notice_sign_Zeistos2.png") s:LoadGraphics()
				s:SetFrame("Idle2",1)
				s.Rotation = -90
				local d = q:GetData()
				d.EID_Description = item.Description
			end,})
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = 100,
Function = function(_,ent,col,low)
	local player = col:ToPlayer()
	if player and auxi.GetDimension() == 2 then 
		if item.to_start() and auxi.will_pick_up(player,ent) then 
			if not ent:GetData()[option_index_holder.own_key.."Remove"] and ent.OptionsPickupIndex == 1 then
				save.elses[item.own_key.."effect"].cnt = (save.elses[item.own_key.."effect"].cnt or 0) + 1
				save.elses[item.own_key.."effect"].frame = Game():GetFrameCount()
				local wdinfo = item.Words[Options.Language] or item.Words["en"]
				wdinfo = wdinfo[save.elses[item.own_key.."effect"].cnt] or ""
				gui.general_speak(Vector(0,0),wdinfo,0,#wdinfo * 3 + 20,{R = 0,G = 0,B = 1,})
				if save.elses[item.own_key.."effect"].cnt == item.limit1 then
					item.get_start()
					return true
				end
			end
		end
		if item.is_start() then 
			if ((save.elses[item.own_key.."RecordOn"] or {})[ent.SubType] or 0) > 0 and auxi.will_pick_up(player,ent) and boss_zeis.pickup_allow() then
				save.elses[item.own_key.."RecordOn"][ent.SubType] = save.elses[item.own_key.."RecordOn"][ent.SubType] - 1
				local collectibleinfo = Isaac.GetItemConfig():GetCollectible(ent.SubType)
				boss_zeis.player_pickup(player,ent.SubType)
				if auxi.REPENTENCE_PLUS() then
					player:AddCollectible(collectibleinfo.ID, collectibleinfo.InitCharge,false)
					if collectibleinfo.AddCostumeOnPickup ~= false then
						player:AddCostume(collectibleinfo,false)
					end
				else
					player:QueueItem(collectibleinfo, collectibleinfo.InitCharge, true)
				end
				player:AnimateCollectible(ent.SubType,"Pickup","PlayerPickupSparkle")
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_POWERUP1,1,1,false,0,2)
			end
			return true
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if item.is_pre_start() then 
		for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
			local door = Game():GetRoom():GetDoor(slot)
			if door then
				door:GetSprite():Play("Closed",true)
			end
		end
		if auxi.check_all_exists(item.Blocker) ~= true then 
			local level = Game():GetLevel()
			item.Blocker = Isaac.Spawn(303,enums.Enemies.ZToken,0,Vector(0,0),Vector(0,0),nil)
			item.Blocker:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
			level:GetRoomByIdx(level:GetCurrentRoomDesc().SafeGridIndex).Clear = false
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = 100,
Function = function(_,ent)
	if auxi.GetDimension() == 2 and item.is_start() then 
		local s = ent:GetSprite()
		local d = ent:GetData()
		if ent.OptionsPickupIndex == 1 then
			local tbl = {}
			for playerNum = 1, Game():GetNumPlayers() do
				local player = Game():GetPlayer(playerNum - 1)
				table.insert(tbl,player)
			end
			local info = auxi.get_nearest(tbl,ent.Position)
			local player = info.tg
			local dis = info.dis
			local colinfo = auxi.check_lerp(dis,item.colorinfo)
			if ((save.elses[item.own_key.."RecordOn"] or {})[ent.SubType] or 0) > 0 and boss_zeis.pickup_allow() then colinfo = auxi.check_lerp(dis,item.colorinfo2) end
			--local speed = auxi.check_lerp(ent.FrameCount,item.frame2speed).rate
			if Game():GetRoom():GetFrameCount() <= 1 then s.Color = auxi.table2color(colinfo)
			else s.Color = auxi.AddColor(s.Color,auxi.table2color(colinfo),0.95,0.05) end
			if d[item.own_key.."No_Query_Succ"] == nil then d[item.own_key.."No_Query_Succ"] = Attribute_holder.try_hold_attribute(ent,"EntityFlag_FLAG_FLAG_NO_QUERY",true,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_QUERY)) end
		else
			
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_USE_ITEM, params = nil,
Function = function(_, colid, rng, player, flags, slot, data)
	if auxi.GetDimension() == 2 and item.is_start() and item.Banisheditem[colid] then 
		player:AnimateCollectible(colid,"UseItem","PlayerPickupSparkle")
		return true
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = nil,
Function = function(_,card,player,flag)
	if card == Card.RUNE_BLACK then
		
	end
end,
})

return item
