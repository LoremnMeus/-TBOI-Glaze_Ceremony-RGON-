local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local modReference
local item = {
	ToCall = {},
	should_charm = false,
	entity = enums.Challenges.Fans_Service,
	own_key = "Challange_Fans_Service_",
	ignore_type = {
		[EntityType.ENTITY_MEGA_SATAN] = true,
		[EntityType.ENTITY_MEGA_SATAN_2] = true,
		[EntityType.ENTITY_RAG_MEGA] = function(ent) if ent.Variant == 1 then return true end end,
	},
}

function item.addcharm(ent)
	ent = ent or auxi.getenemies()
	if type(ent) == "table" then else ent = {ent} end
	for u,v in pairs(ent) do if v:IsVulnerableEnemy() and auxi.check_if_any(item.ignore_type[v.Type],v) ~= true then v:AddEntityFlags(EntityFlag.FLAG_FRIENDLY | EntityFlag.FLAG_PERSISTENT | EntityFlag.FLAG_CHARM) end end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = nil,
Function = function(_,ent)
	if Game().Challenge == item.entity and auxi.check_if_any(item.ignore_type[ent.Type],ent) ~= true then 
		local room = Game():GetRoom()
		local roomType = room:GetType()
		if roomType == RoomType.ROOM_BOSS and (Game():GetLevel():GetStage() == LevelStage.STAGE6 or (room:IsFirstVisit() and item.should_charm ~= true)) then
			ent:ClearEntityFlags(EntityFlag.FLAG_FRIENDLY | EntityFlag.FLAG_PERSISTENT | EntityFlag.FLAG_CHARM)
		else
			for playerNum = 1, Game():GetNumPlayers() do
				local player = Game():GetPlayer(playerNum - 1)
				if (player.Position - ent.Position):Length() < 100 then
					item.addcharm(ent)
					break
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if Game().Challenge == item.entity then 
		local s = player:GetSprite()
		if s:IsPlaying("TeleportUp") then
			item.should_charm = true
			item.addcharm()
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = nil,
Function = function(_,ent, amt, flag, source, cooldown)
	if Game().Challenge == item.entity and ent:IsVulnerableEnemy() and ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY | EntityFlag.FLAG_PERSISTENT | EntityFlag.FLAG_CHARM) then
		return false
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	if Game().Challenge == enums.Challenges.Fans_Service then
		local room = Game():GetRoom()
		local level = Game():GetLevel()
		local levelStage = level:GetStage()
		local roomType = room:GetType()
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			local d = player:GetData()
			if roomType == RoomType.ROOM_BOSS and (levelStage == LevelStage.STAGE6 or (room:IsFirstVisit() and item.should_charm ~= true)) then
				if auxi.check_all_exists(d[item.own_key.."effect"]) then d[item.own_key.."effect"]:Remove() d[item.own_key.."effect"] = nil end
			else
				if auxi.check_all_exists(d[item.own_key.."effect"]) ~= true then 
					local q = Isaac.Spawn(1000,enums.Entities.ID_EFFECT_MeusNIL,0,player.Position,player.Velocity,player)
					d[item.own_key.."effect"] = q
					local s = q:GetSprite()
					local d = q:GetData()
					d.removecd = 999999
					d.ignore_follower_distance = true
					d.follower = player
					s:Load("gfx/challenges/Fans_Service/fans_services_ring.anm2", true)
					s:Play("Idle")
					q.SpriteOffset = Vector(0,-20)
					q.DepthOffset = -50
				end
			end
		end
		item.should_charm = false
		local room = Game():GetRoom()
		local player = Game():GetPlayer(0)
		local n_entity = Isaac.GetRoomEntities()
		for u,ent in pairs(n_entity) do
			if ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY | EntityFlag.FLAG_PERSISTENT | EntityFlag.FLAG_CHARM) then
				ent.MaxHitPoints = ent.MaxHitPoints + 5
				ent.HitPoints = math.min(ent.HitPoints + 5,ent.MaxHitPoints)
				local pos = room:GetRandomPosition(10)
				local cnt = 5
				while cnt > 0 and (pos - player.Position):Length() < 50 do
					pos = room:GetRandomPosition(10)
					cnt = cnt - 1
				end
				ent.Position = pos
			end
		end
	end
end,
})

return item
