local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	myToCall = {},
	entity1 = enums.Items.Skiel,
	entity2 = enums.Items.Wisel,
	entity3 = enums.Items.Granel,
	spritename_1 = "gfx/effects/chargebar/chargebar_Skiel.anm2",
	spritename_2 = "gfx/effects/chargebar/chargebar_Wisel.anm2",
	spritename_3 = "gfx/effects/chargebar/chargebar_Granel.anm2",
	time_counter_1 = 90,
	time_counter_2 = 180,
	time_counter_3 = 270,
	own_key = "Iliaster",
}

function item.start_Iliaster_1(player)
	for i = 1,5 do
		delay_buffer.addeffe(function(params)
			if player and player:Exists() then
				local d = player:GetData()
				local ggdir = auxi.ggdir(player,true,true)
				if ggdir:Length() < 0.05 then 
					if d.last_skiel_dir then
						ggdir = d.last_skiel_dir
					else
						ggdir = Vector(1,0)
					end
				else
					d.last_skiel_dir = ggdir
				end
				local ang = ggdir:GetAngleDegrees()
				local rnd = math.random(5)
				local rnd2 = 0
				if player:HasCollectible(item.entity3) or player:GetEffects():GetCollectibleEffectNum(item.entity3) > 0 then rnd2 = math.random(3) end
				local lst_link = nil
				for j = 3,-3,-1 do
					if j ~= 0 then
						local k = j/math.abs(j)
						local q = Isaac.Spawn(2,1,0,player.Position,auxi.MakeVector(ang + ((4 - math.abs(j)) * 20 + i * 6 + 100) * k) * player.ShotSpeed * (5 + (5-i) * 2), player):ToTear()
						q.CollisionDamage = player.Damage * 0.5
						q.TearFlags = q.TearFlags | BitSet128(1<<0,0)
						if rnd == 1 then q.TearFlags = q.TearFlags | BitSet128(1<<2,0) end
						if rnd == 3 or rnd2 == 1 then q.TearFlags = q.TearFlags | BitSet128(1<<34,0) end
						if rnd == 5 or rnd2 == 1 then q.TearFlags = q.TearFlags | BitSet128(1<<58,0) end
						if player:HasCollectible(item.entity2) or player:GetEffects():GetCollectibleEffectNum(item.entity2) > 0 and (rnd == 2 or rnd == 4) then q.TearFlags = q.TearFlags | BitSet128(1<<19,0) end
						local s2 = q:GetSprite()
						s2:Load("gfx/mimics/Iliaster/Iliaster_tear.anm2",true)
						s2:ReplaceSpritesheet(0,"gfx/tears/Iliaster_tear_"..tostring(rnd)..".png")
						s2:LoadGraphics()
						s2:Play("Idle",true)
						local d2 = q:GetData()
						d2.is_skiel = true
						d2.Ignore_me_flag = true
						d2.link_target = lst_link
						lst_link = q
					end
				end
				player:AddVelocity(ggdir:Normalized() * 2.5)
			end
		end,{},i * 2)
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION, params = nil,
Function = function(_,ent,col,low)
	local d = ent:GetData()
	if d.is_wisel then
		local player = Game():GetPlayer(0)
		if ent.Spawner and ent.Spawner.Type == 1 and ent.Spawner:ToPlayer() then player = ent.Spawner:ToPlayer() end
		local s = ent:GetSprite()
		if s:IsPlaying("Idle") then
			if d.wisel_counter == nil or d.wisel_counter <= 0 then
				s:Play("Remove",true)
				ent.Velocity = Vector(0,0)
				d.wisel_target_ent = col
				ent.CollisionDamage = 0
				ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
				ent.TearFlags = BitSet128(1<<1,0)
			else
				d.wisel_counter = d.wisel_counter - 1
			end
		end
		if player:HasCollectible(item.entity1) or player:GetEffects():GetCollectibleEffectNum(item.entity1) > 0 then 
			if d.Iliaster_hold_counter_1 <= 0 then 
				local ggdir = ent.Velocity
				if ggdir:Length() < 0.01 then ggdir = auxi.MakeVector(math.random(360)) end
				local ang = ggdir:GetAngleDegrees()
				local rnd = math.random(5)
				local lst_link = nil
				for j = 3,-3,-1 do
					if j ~= 0 then
						local k = j/math.abs(j)
						local q = Isaac.Spawn(2,1,0,ent.Position,auxi.MakeVector(ang + ((4 - math.abs(j)) * 20 + 100) * k) * player.ShotSpeed * 10, player):ToTear()
						q.CollisionDamage = player.Damage * 0.1
						q.TearFlags = q.TearFlags | BitSet128(1<<0,0)
						if rnd == 1 then q.TearFlags = q.TearFlags | BitSet128(1<<2,0) end
						if rnd == 3 or rnd2 == 1 then q.TearFlags = q.TearFlags | BitSet128(1<<34,0) end
						if rnd == 5 or rnd2 == 1 then q.TearFlags = q.TearFlags | BitSet128(1<<58,0) end
						if rnd == 2 or rnd == 4 then q.TearFlags = q.TearFlags | BitSet128(1<<19,0) end
						local s2 = q:GetSprite()
						s2:Load("gfx/mimics/Iliaster/Iliaster_tear.anm2",true)
						s2:ReplaceSpritesheet(0,"gfx/tears/Iliaster_tear_"..tostring(rnd)..".png")
						s2:LoadGraphics()
						s2:Play("Idle",true)
						local d2 = q:GetData()
						d2.is_skiel = true
						d2.Ignore_me_flag = true
						d2.link_target = lst_link
						lst_link = q
					end
				end
				ent:AddVelocity(ggdir:Normalized() * 5)
				d.Iliaster_hold_counter_1 = 15
			end
		end
		if player:HasCollectible(item.entity3) or player:GetEffects():GetCollectibleEffectNum(item.entity3) > 0 then 
			if d.Iliaster_hold_counter_3 <= 0 then 
				local ggdir = Vector(1,0)
				local ang = ggdir:GetAngleDegrees()
				local rnd = math.random(7)
				local rnd2 = math.random(40) - 20
				if rnd == 1 then rnd2 = math.random(70) - 35 end
				local rnd3 = math.random(10)/10 * 10 - 5
				if rnd == 5 then rnd2 = math.random(10)/10 * 15 - 5 end
				local rnd4 = math.random(40) - 20
				if rnd == 3 then rnd4 = rnd4 + 60 end
				local dmg = player.Damage * 0.1
				if rnd == 7 then dmg = player.Damage * 0.2 end
				for j = 1,4 do
					local q = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BLUE_FLAME, 0, ent.Position, auxi.MakeVector(ang + j * 90 + 45 + rnd2) * player.ShotSpeed * (10 + rnd3), player):ToEffect()
					local s2 = q:GetSprite()
					local d2 = q:GetData()
					s2:Load("gfx/mimics/Iliaster/granel_flame.anm2",true)
					s2:ReplaceSpritesheet(0,"gfx/effects/flames/flame"..tostring(rnd)..".png")
					s2:LoadGraphics()
					s2:Play("Appear",true)
					d2.is_granel = true
					if rnd == 4 then d2.should_follow = true end
					q.CollisionDamage = dmg
					q.GridCollisionClass = GridCollisionClass.COLLISION_NONE
					q.Timeout = 90 + rnd4
				end
				d.Iliaster_hold_counter_3 = 15
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d.is_skiel then
		if d.link_target and d.link_target:Exists() and d.link_target:IsDead() ~= true then
			if d.link_laser == nil then
				local player = Game():GetPlayer(0)
				if ent.Spawner and ent.Spawner.Type == 1 and ent.Spawner:ToPlayer() then player = ent.Spawner:ToPlayer() end
				local q = Isaac.Spawn(7,10,0,ent.Position,Vector(0,0),player):ToLaser()
				q.CollisionDamage = ent.CollisionDamage
				d.link_laser = q
				q.Parent = ent
				local s2 = q:GetSprite()
				s2.Color = Color(1,0,1,1)
			end
			d.link_laser.PositionOffset = ent.PositionOffset
			d.link_laser.Angle = (d.link_target.Position - ent.Position):GetAngleDegrees()
			d.link_laser:SetMaxDistance(math.min(200,(d.link_target.Position - ent.Position):Length()))
		else
			if d.link_laser ~= nil then
				d.link_laser:Remove()
				d.link_laser = nil
			end
		end
	end
	if d.is_wisel then
		if d.Iliaster_hold_counter_1 == nil then d.Iliaster_hold_counter_1 = 0 end
		if d.Iliaster_hold_counter_3 == nil then d.Iliaster_hold_counter_3 = 0 end
		d.Iliaster_hold_counter_1 = math.max(0,d.Iliaster_hold_counter_1 - 1)
		d.Iliaster_hold_counter_3 = math.max(0,d.Iliaster_hold_counter_3 - 1)
		local s = ent:GetSprite()
		if s:IsPlaying("Idle") then
			s.Rotation = ent.Velocity:GetAngleDegrees() - 90
			ent.FallingSpeed = 0
			ent.Height = - 30
		end
		if s:IsPlaying("Remove") then
			ent.Velocity = ent.Velocity * 0.5
			if d.wisel_target_ent and d.wisel_target_ent:Exists() then
				ent.Position = d.wisel_target_ent.Position + Vector(0,0.1)
			end
			s.Offset = s.Offset * 0.8 + Vector(0,-40) * 0.2
		end
		if s:IsFinished("Remove") then
			ent:Remove()
		end
	end
end,
})

function item.start_Iliaster_2(player)
	local d = player:GetData()
	local gdir = auxi.ggdir(player,true,true)
	if gdir:Length() > 0.05 then d.last_wisel_dir = ggdir end
	for i = 1,6 do
		delay_buffer.addeffe(function(params)
			local ggdir = auxi.ggdir(player,true,true)
			if ggdir:Length() < 0.05 then
				if d.last_wisel_dir then
					ggdir = d.last_wisel_dir
				else
					ggdir = Vector(1,0)
				end
			else
				d.last_wisel_dir = ggdir
			end
			local ang = ggdir:GetAngleDegrees()
			local q = Isaac.Spawn(2,0,0,player.Position,auxi.MakeVector(ang) * player.ShotSpeed * (5 + (7 - i) / 7 * 2), player):ToTear()
			q.TearFlags = q.TearFlags | BitSet128(1<<19,0) | BitSet128(1<<1,0) | BitSet128(1<<2,0) | BitSet128(1<<7,0)
			q.CollisionDamage = player.Damage * 1.3
			local s2 = q:GetSprite()
			s2.Scale = Vector(1,1) * (10 - i)/10
			q:SetSize(16 * (10 - i)/10,Vector(1,1),1)
			s2:Load("gfx/mimics/Iliaster/Wisel_tear.anm2",true)
			s2:Play("Idle",true)
			local d2 = q:GetData()
			d2.is_wisel = true
			d2.wisel_counter = 4
			d2.Ignore_me_flag = true
			player:AddVelocity( -ggdir:Normalized() * 2.5)
		end,{},(i-1) * 2)
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if player:HasCollectible(item.entity2) or player:GetEffects():GetCollectibleEffectNum(item.entity2) > 0 then
		local ggdir = auxi.ggdir(player,true,true)
		if ggdir:Length() > 0.05 then
			player:GetData().last_wisel_dir = ggdir
		end
	end
end,
})

function item.start_Iliaster_3(player)
	for i = 1,20 do
		delay_buffer.addeffe(function(params)
			if player and player:Exists() then
				local d = player:GetData()
				local ggdir = auxi.ggdir(player,true,true)
				if ggdir:Length() < 0.05 then ggdir = Vector(1,0) end
				local ang = ggdir:GetAngleDegrees()
				local rnd = math.random(7)
				local rnd2 = math.random(40) - 20
				if rnd == 1 then rnd2 = math.random(70) - 35 end
				local rnd3 = math.random(10)/10 * 10 - 5
				if rnd == 5 then rnd2 = math.random(10)/10 * 15 - 5 end
				local rnd4 = math.random(40) - 20
				if rnd == 3 then rnd4 = rnd4 + 60 end
				local dmg = player.Damage * 0.2
				if rnd == 7 then dmg = player.Damage * 0.4 end
				for j = 1,4 do
					local q = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BLUE_FLAME, 0, player.Position, auxi.MakeVector(ang + j * 90 + 45 + rnd2) * player.ShotSpeed * (10 + rnd3), player):ToEffect()
					local s2 = q:GetSprite()
					local d2 = q:GetData()
					s2:Load("gfx/mimics/Iliaster/granel_flame.anm2",true)
					s2:ReplaceSpritesheet(0,"gfx/effects/flames/flame"..tostring(rnd)..".png")
					s2:LoadGraphics()
					s2:Play("Appear",true)
					d2.is_granel = true
					if rnd == 4 then d2.should_follow = true end
					q.CollisionDamage = dmg
					q.GridCollisionClass = GridCollisionClass.COLLISION_NONE
					q.Timeout = 90 + rnd4
				end
			end
		end,{},i * 2)
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = EffectVariant.BLUE_FLAME,
Function = function(_,ent)
	local d = ent:GetData()
	if d.is_granel then
		local s = ent:GetSprite()
		if s:IsFinished("Appear") then
			s:Play("Idle",true)
		end
		if s:IsPlaying("Idle") then
			if d.should_follow and d.target == nil then 
				d.target = auxi.get_by_nearest_enemy(ent.Position)
				d.should_follow = nil
			end
			if d.target and d.target:Exists() and d.target:IsDead() == false then 
				ent.Velocity = ent.Velocity + (d.target.Position - ent.Position) * 0.01
				if ent.Velocity:Length() > 10 then ent.Velocity = ent.Velocity:Normalized() * 10 end
			end
			if d.minded_scale == nil then d.minded_scale = math.max(1,ent.Timeout + 15) end
			s.Scale = Vector(1,1) * (ent.Timeout + 15 )/ d.minded_scale
			ent.CollisionDamage = math.max(0.5,ent.CollisionDamage * 0.98)
		end
	end
end,
})

local function check_has(tp)
	return (tp == item.entity1 or tp == item.entity2 or tp == item.entity3)
end

local function check_next(tp)
	if check_has(tp) == false then return 0 end
	for i = 1,3 do
		if tp == item["entity"..tostring(i)] then return item["entity"..tostring(i%3+1)] end
	end
	return 0
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	local room = Game():GetRoom()
	local s = player:GetSprite()
	local d = player:GetData()
	if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
		for i = 1,3 do
			if player:HasCollectible(item["entity"..tostring(i)]) or player:GetEffects():GetCollectibleEffectNum(item["entity"..tostring(i)]) > 0 then
				local cnt = d["Iliaster_counter_"..tostring(i)] or 0
				Charging_Bar_holder.render_me(player,{name1 = "Iliaster_counter_"..tostring(i),name2 = "Iliaster_sprite"..tostring(i),name3 = "Iliaster_"..tostring(i),loadname = item["spritename_"..tostring(i)],		--使用另外一个charge减少修改量
					check1 = function(val,ent)
						return cnt > 5
					end,
					check2 = function(val,ent) 
						return cnt > item["time_counter_"..tostring(i)]
					end,
					check3 = function(val,ent)
						return math.ceil(cnt/item["time_counter_"..tostring(i)] * 100)
					end,
					signal1 = function(ent)
						d["Iliaster_active_"..tostring(i)] = true
					end,
				})
			end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = nil,
Function = function(_,player,collid,count)
	for i = 1,3 do
		if collid == item["entity"..tostring(i)] and count < 0 then
			Charging_Bar_holder.remove_charge_bar(player,"Iliaster_"..tostring(i))
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = 100,
Function = function(_,ent)
	local d = ent:GetData()
	if ent.Touched ~= true then
		if check_has(ent.SubType) then
			consistance_holder.try_check_entity(ent,item.own_key)
			d._Data = d._Data or {}
			d._Data[item.own_key] = d._Data[item.own_key] or {}
			d._Data[item.own_key].Ilaster_counter = (d._Data[item.own_key].Ilaster_counter or 0) + 1
			--print(d._Data.Ilaster_counter.." "..ent.InitSeed.." "..ent.DropSeed)
			if d._Data[item.own_key].Ilaster_counter >= 60 then
				local nx = check_next(ent.SubType)
				consistance_holder.try_remove_entity(ent,item.own_key,{ignore_subtype = true})
				ent:Morph(5,100,nx,true,true,true)
				ent:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
				ent:SetColor(Color(1,1,1,1,1,1,1),10,10,true)
			end
			consistance_holder.try_hold_entity(ent,item.own_key,{ignore_subtype = true})
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local ctrlid = player.ControllerIndex
		local d = player:GetData()
		local act = false
		for i = 4,7 do
			if (Input.IsActionTriggered(i,ctrlid)) or (Input.IsActionPressed(i,ctrlid)) then
				act = true
			end
		end
		if auxi.g_dir_can_work(player) then
			for i = 1,3 do
				if player:HasCollectible(item["entity"..tostring(i)]) or player:GetEffects():GetCollectibleEffectNum(item["entity"..tostring(i)]) > 0 then
					if d["Iliaster_counter_"..tostring(i)] == nil then d["Iliaster_counter_"..tostring(i)] = 0 end
					if act == true then
						if i == 1 or i == 3 then
							d["Iliaster_counter_"..tostring(i)] = d["Iliaster_counter_"..tostring(i)] + 1
							if d["Iliaster_active_"..tostring(i)] == true then
								d["Iliaster_active_"..tostring(i)] = false
								item["start_Iliaster_"..tostring(i)](player)
								d["Iliaster_counter_"..tostring(i)] = 0
							end
						end
						if i == 2 or i == 3 then
							if d["Iliaster_set_flag"..tostring(i)] == nil then d["Iliaster_set_flag"..tostring(i)] = false end
							if d["Iliaster_set_counter"..tostring(i)] == nil then d["Iliaster_set_counter"..tostring(i)] = 0 end
							if d["Iliaster_set_flag"..tostring(i)] ~= true then
								d["Iliaster_set_flag"..tostring(i)] = true
								d["Iliaster_set_counter"..tostring(i)] = math.min(35,d["Iliaster_set_counter"..tostring(i)] + 7)
							end
							if d["Iliaster_active_"..tostring(i)] == true then
								d["Iliaster_active_"..tostring(i)] = false
								item["start_Iliaster_"..tostring(i)](player)
								d["Iliaster_counter_"..tostring(i)] = 0
							end
						end
					else
						if i == 1 then
							d["Iliaster_counter_"..tostring(i)] = 0
						elseif i == 2 or i == 3 then
							if d["Iliaster_set_flag"..tostring(i)] == nil then d["Iliaster_set_flag"..tostring(i)] = false end
							if d["Iliaster_set_counter"..tostring(i)] == nil then d["Iliaster_set_counter"..tostring(i)] = 0 end
							if d["Iliaster_set_flag"..tostring(i)] ~= false then
								d["Iliaster_set_flag"..tostring(i)] = false
								d["Iliaster_set_counter"..tostring(i)] = math.min(35,d["Iliaster_set_counter"..tostring(i)] + 7)
							end
						end
					end
					if i == 2 then 
						if d["Iliaster_set_counter"..tostring(i)] > 0 then
							local cnt = math.max(1,d["Iliaster_set_counter"..tostring(i)] / 5)
							d["Iliaster_counter_"..tostring(i)] = d["Iliaster_counter_"..tostring(i)] + cnt * 0.5
							d["Iliaster_set_counter"..tostring(i)] = math.max(0,d["Iliaster_set_counter"..tostring(i)] - cnt)
						else
							d["Iliaster_counter_"..tostring(i)] = math.max(0,d["Iliaster_counter_"..tostring(i)] - 5)
						end
					elseif i == 3 then
						if d["Iliaster_set_counter"..tostring(i)] > 0 then
							local cnt = math.max(1,d["Iliaster_set_counter"..tostring(i)] / 5)
							d["Iliaster_counter_"..tostring(i)] = d["Iliaster_counter_"..tostring(i)] + cnt * 0.3
							d["Iliaster_set_counter"..tostring(i)] = math.max(0,d["Iliaster_set_counter"..tostring(i)] - cnt)
						elseif not act then
							d["Iliaster_counter_"..tostring(i)] = math.max(0,d["Iliaster_counter_"..tostring(i)] - 5)
						end
					end
				end
			end
		end
	end
end,
})

return item