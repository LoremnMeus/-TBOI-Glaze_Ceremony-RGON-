local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	ToCall = {},
	entity = enums.Items.Little_Duck,
	duck = enums.Entities.little_duck,
}

local function add_flip(npc)
	local v = npc.Velocity
	local d = npc:GetData()
	if d.flipped == nil then d.flipped = math.random(2) end
	if d.flipped then
		if v.X < -0.0005 then
			npc:GetSprite().FlipX = true
		elseif v.X > 0.0005 then
			npc:GetSprite().FlipX = false
		end
	else
		if v.X < -0.0005 then
			npc:GetSprite().FlipX = false
		elseif v.X > 0.0005 then
			npc:GetSprite().FlipX = true
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local room = Game():GetRoom()
	if room:IsClear() == false then
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			if auxi.has_have_coll(player,item.entity)  then
				local num = player:GetCollectibleNum(item.entity)
				for i = 1,3 * num do
					local pos = room:GetRandomPosition(5)
					Isaac.Spawn(996,item.duck,0,pos,Vector(0,0),player)
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = 996,		--速度、位移调整
Function = function(_,ent)
	if ent.Variant == item.duck then
		local s = ent:GetSprite()
		local d = ent:GetData()
		if d.is_meus_helper ~= true then
			if d.Should_Move and d.Should_Move == true then
			else
				if ent.Velocity:Length() > 0.05 then
					ent.Velocity = Vector(0,0)
				end
			end
			add_flip(ent)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_INIT, params = 996,	--初始化
Function = function(_,ent)
	if ent.Variant == item.duck then
		local s = ent:GetSprite()
		local d = ent:GetData()
		local room = Game():GetRoom()
		if d.State == nil then
			d.State = 0
		end
		d.Should_Move = true
		s:Play("Idle",true)
		d.flipped = math.random(2)
		ent:AddEntityFlags(EntityFlag.FLAG_NO_STATUS_EFFECTS)
		ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL
	end
end,
})


table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = 996,
Function = function(_,ent)
	if ent.Variant == item.duck then
		local s = ent:GetSprite()
		local d = ent:GetData()
		local room = Game():GetRoom()
		local player = Game():GetPlayer(0)
		if d.is_meus_helper ~= true then
			if ent.SpawnerEntity and ent.SpawnerEntity.Type == 1 then player = ent.SpawnerEntity:ToPlayer() end
			if ent:HasEntityFlags(EntityFlag.FLAG_MIDAS_FREEZE) then
				ent:ClearEntityFlags(EntityFlag.FLAG_MIDAS_FREEZE)
			end
			if s:IsEventTriggered("Quark") and (math.random(1000) < 300 or ent:HasEntityFlags(EntityFlag.FLAG_POISON) or ent:HasEntityFlags(EntityFlag.FLAG_CHARM) or ent:HasEntityFlags(EntityFlag.FLAG_FEAR) or ent:HasEntityFlags(EntityFlag.FLAG_BURN)) then
				sound_tracker.PlayStackedSound(510,1,1,false,0,2)
				if d.duck_counter == nil then d.duck_counter = 0 end
				d.duck_counter = d.duck_counter + 1
				sound_tracker.PlayStackedSound(510,1,0.8 + d.duck_counter/10,false,0,2)
				if d.duck_counter >= 7 then
					local rnd = math.random(4) + 8
					for i = 1,rnd do
						local q = Isaac.Spawn(2,0,0,ent.Position,ent.Velocity * 1.5 + auxi.MakeVector(360/rnd * i) * 8,player)
						q.CollisionDamage = player.Damage * 1.5 + 5
						q:SetColor(player.TearColor,-1,99,true,false)
					end
					ent:Kill()
				else
					s:ReplaceSpritesheet(0,"gfx/tears/little_duck_tear_"..tostring(d.duck_counter)..".png")
					s:LoadGraphics()
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 996,
Function = function(_,ent,amt,flag,source,cooldown)
	if ent.Variant == item.duck and ent.Type == 996 then
		local s = ent:GetSprite()
		local d = ent:GetData()
		local room = Game():GetRoom()
		local player = Game():GetPlayer(0)
		if d.is_meus_helper ~= true then
			if ent.SpawnerEntity and ent.SpawnerEntity.Type == 1 then player = ent.SpawnerEntity:ToPlayer() end
			if true then
			--if col.Type == 2 or col.Type == 7 or col.Type == 8 or col.Type == 4 or col.Type == 9 then
				if d.duck_counter == nil then d.duck_counter = 0 end
				d.duck_counter = d.duck_counter + 1
				sound_tracker.PlayStackedSound(510,1,0.8 + d.duck_counter/10,false,0,2)
				if d.duck_counter >= 7 then
					local rnd = math.random(4) + 8
					for i = 1,rnd do
						local q = Isaac.Spawn(2,0,0,ent.Position,ent.Velocity * 1.5 + auxi.MakeVector(360/rnd * i) * 8,player)
						q.CollisionDamage = player.Damage * 1.5 + 5
						q:SetColor(player.TearColor,-1,99,true,false)
					end
					ent:Kill()
				else
					s:ReplaceSpritesheet(0,"gfx/tears/little_duck_tear_"..tostring(d.duck_counter)..".png")
					s:LoadGraphics()
				end
			end
			return false
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION, params = 45,	--防止某些奇怪情况
Function = function(_,ent,col,low)
	if col.Variant == item.duck and col.Type == 996 then
		return false
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_NPC_COLLISION, params = 996,
Function = function(_,ent,col,low)
	if ent.Variant == item.duck then
		local s = ent:GetSprite()
		local d = ent:GetData()
		local room = Game():GetRoom()
		local player = Game():GetPlayer(0)
		if d.is_meus_helper ~= true then
			if ent.SpawnerEntity and ent.SpawnerEntity.Type == 1 then player = ent.SpawnerEntity:ToPlayer() end
			if col.Type == 9 then
				if d.duck_counter == nil then d.duck_counter = 0 end
				d.duck_counter = d.duck_counter + 1
				sound_tracker.PlayStackedSound(510,1,0.8 + d.duck_counter/10,false,0,2)
				if d.duck_counter >= 7 then
					local rnd = math.random(4) + 8
					for i = 1,rnd do
						local q = Isaac.Spawn(2,0,0,ent.Position,ent.Velocity * 1.5 + auxi.MakeVector(360/rnd * i) * 8,player)
						q.CollisionDamage = player.Damage * 1.5 + 5
						q:SetColor(player.TearColor,-1,99,true,false)
					end
					ent:Kill()
				else
					s:ReplaceSpritesheet(0,"gfx/tears/little_duck_tear_"..tostring(d.duck_counter)..".png")
					s:LoadGraphics()
				end
			end
		end
	end
end,
})

--sound_tracker.PlayStackedSound(510,1,1,false,0,2)

return item