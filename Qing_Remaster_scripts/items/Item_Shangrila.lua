local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Bomb_holder = require("Qing_Remaster_scripts.mimics.Bomb_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Shangrila,
	launcher_info = {
		{id = 1,weigh = 30,},
		{id = 2,weigh = 20,},
		{id = 3,weigh = 15,},
		{id = 4,weigh = 10,},
	},
	player_info = {
		{frame = 0,},
		{frame = 60,},
		launch = 10,
		total = 60,
	},
	own_key = "Item_Shangrila_",
}
auxi.add_to_seija(item.entity)

function item.generate_launcher(pos,params)
	params = params or {}
	local player = params.player or Game():GetPlayer(0)
	local rndinfo = params.info or auxi.random_in_weighed_table(item.launcher_info,params.rng)
	local id = rndinfo.id
	if id <= 3 then
		local q = Isaac.Spawn(1000,enums.Entities.ShangrilaHelper,0,pos,Vector(0,0),player)
		local s = q:GetSprite() s:Load("gfx/mimics/Shangrila/Missle.anm2",true) s:ReplaceSpritesheet(0,"gfx/mimics/Shangrila/Missle"..tostring(rndinfo.id)..".png") s:LoadGraphics() s:Play("Appear",true)
		local d = q:GetData()
		d[item.own_key.."effect"] = {id = rndinfo.id,floatrate = pos.Y * 0.2,mul = auxi.choose(1,1,2,3) + player:GetCollectibleNum(item.entity) - 1,}		--auxi.choose(10,20,30,40,50,60,70,80)
		if id == 1 then q.Position = player.Position q:GetSprite().FlipY = true d[item.own_key.."effect"].pos = pos
		else q.PositionOffset = auxi.screentop2pos(q.Position) - q.Position + Vector(0,-50) end
	end
end

function item.generate_trapdoor(pos)
	local tp = GridEntityType.GRID_TRAPDOOR
	local level = Game():GetLevel()
	if auxi.get_acceptible_level() >= 9 or level:IsAscent() or level:IsPreAscent() then return end--tp = GridEntityType.GRID_STAIRS end
	local room = Game():GetRoom() room:SpawnGridEntity(room:GetGridIndex(pos),tp,0,1,0)
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.ShangrilaHelper,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		ent.Velocity = Vector(0,0)
		local s = ent:GetSprite()
		local player = auxi.check_spawner_player(ent) or Game():GetPlayer(0)
		local id = d[item.own_key.."effect"].id
		if auxi.check_all_exists(d[item.own_key.."effect"].linker) then 
			local q = d[item.own_key.."effect"].linker q.Position = ent.Position + ent.PositionOffset + Vector(0,10) q.MaxDistance = ent.PositionOffset.Y - 10
			if auxi.should_do_Seija(player) and ent.FrameCount % 5 == 3 and auxi.random_1() < 0.5 then local rnd = auxi.random_1() item.generate_trapdoor(ent.Position * rnd + q.Position * (1 - rnd)) end
		end
		if d[item.own_key.."effect"].wait then d[item.own_key.."effect"].wait = d[item.own_key.."effect"].wait - 1 if d[item.own_key.."effect"].wait <= 0 then d[item.own_key.."effect"].wait = nil else return end end
		if id == 1 then
			ent.PositionOffset = ent.PositionOffset - Vector(0,20) * (math.sqrt(ent.FrameCount + 16) - 3)
			local tgpos = auxi.screentop2pos(ent.Position) - ent.Position
			if tgpos.Y > ent.PositionOffset.Y + 60 then 
				local pos = d[item.own_key.."effect"].pos or ent.Position
				local q = auxi.launch_Missile(pos + auxi.random_v() * 40,Vector(0,0),d[item.own_key.."effect"].tearhitparams,nil,{invisible = true,params = {dmgself = false,},fallspeed = auxi.choose(18,24,30),
				ReloadRocket = function(et) local s = et:GetSprite() s:Load("gfx/mimics/Shangrila/Missle.anm2",true) s:ReplaceSpritesheet(0,"gfx/mimics/Shangrila/Missle1.png") s:LoadGraphics() s:Play("Idle",true) end,
				Trigger = function(et) if auxi.should_do_Seija(player) then item.generate_trapdoor(et.Position) end end,}) 
				ent:Remove() return
			end
		elseif id == 2 then 
			ent.PositionOffset = ent.PositionOffset * 0.7 + (auxi.screentop2pos(ent.Position) - ent.Position + Vector(0,d[item.own_key.."effect"].floatrate or 30)) * 0.3
			if s:IsFinished("Appear") then s:Play("Charge",true) end
			if s:IsEventTriggered("Fire") then
				local q = player:FireBrimstone(Vector(0,1),nil,auxi.choose(0.25,0.25,0.5,0.5,0.5,1,1,2))
				q.CollisionDamage = 0 q:SetTimeout(15) q.Mass = 0 q.PositionOffset = Vector(0,0) q.TearFlags = BitSet128(0,0)
				q.DisableFollowParent = true
				d[item.own_key.."effect"].linker = q
				q.Position = ent.Position + ent.PositionOffset + Vector(0,10) q.MaxDistance = ent.PositionOffset.Y - 10
			end
			if s:IsFinished("Charge") then d[item.own_key.."effect"].mul = (d[item.own_key.."effect"].mul or 0) - 1 if d[item.own_key.."effect"].mul <= 0 then s:Play("Disappear",true) else s:Play("Charge",true) d[item.own_key.."effect"].wait = auxi.choose(15,30) * auxi.random_1() end end
		elseif id == 3 then
			ent.PositionOffset = ent.PositionOffset * 0.7 + (auxi.screentop2pos(ent.Position) - ent.Position + Vector(0,d[item.own_key.."effect"].floatrate or 30)) * 0.3
			if s:IsFinished("Appear") then s:Play("Charge2",true) end
			if s:IsEventTriggered("Fire") then
				local q = Isaac.Spawn(1000,enums.Entities.ShangrilaHelper,0,ent.Position + ent.PositionOffset + Vector(0,10),Vector(0,20),player)
				local s = q:GetSprite() s:Load("gfx/mimics/Shangrila/Missle.anm2",true) s:ReplaceSpritesheet(0,"gfx/mimics/Shangrila/Missle4.png") s:LoadGraphics() s:Play("Rotate",true)
				local d = q:GetData()
				d[item.own_key.."effect"] = {id = 4,pos = auxi.ProtectVector(ent.Position),vel = auxi.choose(8,10,10,12) * player.ShotSpeed,cnt = auxi.choose(2,2,2,2,4,4,8),leg = auxi.random_1() + 1,}
			end
			if s:IsFinished("Charge2") then d[item.own_key.."effect"].mul = (d[item.own_key.."effect"].mul or 0) - 1 if d[item.own_key.."effect"].mul <= 0 then s:Play("Disappear",true) else s:Play("Charge2",true) d[item.own_key.."effect"].wait = auxi.choose(15,30) * auxi.random_1() end end
		elseif id == 4 then
			if d[item.own_key.."effect"].se then else
				--local dir = (d[item.own_key.."effect"].pos or ent.Position + Vector(0,1)) - ent.Position
				ent.Velocity = Vector(0,d[item.own_key.."effect"].vel or 10) --dir:Normalized() * 20
				if auxi.should_do_Seija(player) and ent.FrameCount % 5 == 3 and auxi.random_1() < 0.5 then item.generate_trapdoor(ent.Position) end
				local shouldend = ((d[item.own_key.."effect"].pos == nil) or (d[item.own_key.."effect"].pos - ent.Position).Y < 0) and math.abs(auxi.checkrounded(s.Rotation % 360,0,1,0,360)) <= 15
				s.Rotation = s.Rotation + 15
				local cnt = d[item.own_key.."effect"].cnt or 2
				for i = 1,cnt do 
					local dir = 90 + i * 360/cnt + s.Rotation
					if auxi.check_all_exists(d[item.own_key.."effect"]["linker"..tostring(i)]) ~= true then
						local q = player:FireTechLaser(ent.Position,1,auxi.MakeVector(dir),false,true) q.Parent = ent q.PositionOffset = Vector(0,0) q:SetTimeout(120) q.OneHit = false q.MaxDistance = 40 * (d[item.own_key.."effect"].leg or 1.5) q.TearFlags = BitSet128(0,0)
						d[item.own_key.."effect"]["linker"..tostring(i)] = q
					end
					local q = d[item.own_key.."effect"]["linker"..tostring(i)]
					q.Angle = dir
					q.Position = ent.Position
					if shouldend then q:SetTimeout(1) end
				end
				if shouldend then d[item.own_key.."effect"].se = {} s.Rotation = 0 s:Play("Disappear") end
			end
		end
		if s:IsFinished("Disappear") then if id == 4 and auxi.should_do_Seija(player) then item.generate_trapdoor(ent.Position) end ent:Remove() end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if player:GetData()[item.own_key.."effect"] then player:GetData()[item.own_key.."effect"] = nil end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	if d[item.own_key.."effect"] then
		local dir = auxi.ggdir(player,true,true)
		if dir:Length() > 0.05 then
			d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) + 1
			if d[item.own_key.."effect"].counter == item.player_info.launch then 
				local pos = player.Position
				local tg = auxi.get_nearest_enemy(nil,player.Position)
				if tg == nil then pos = pos + dir * math.sqrt(player.ShotSpeed) * 40 * (auxi.random_1() * 3 + 1) else pos = tg.Position end
				item.generate_launcher(pos,{player = player,info = {id = auxi.choose(1,2,3),},})
			end
		end
		if d[item.own_key.."effect"].counter >= item.player_info.total then d[item.own_key.."effect"] = nil end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if Game():GetFrameCount() % 30 == 15 and auxi.have_player_has_collectible(item.entity) then
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			local ctrlid = player.ControllerIndex
			local d = player:GetData()
			if auxi.g_dir_can_work(player) and auxi.has_have_coll(player,item.entity) and player:GetData()[item.own_key.."effect"] == nil then
				player:GetData()[item.own_key.."effect"] = {counter = 0,}
			end
		end
	end
end,
})

return item