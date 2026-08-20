local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local grid_morpher = require("Qing_Remaster_scripts.grids.grid_morpher")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Tower,
	own_key = "Thoth_cd16_Tow_",
	height_limit = -900,
	rock_grid = {
		[GridEntityType.GRID_ROCK] = {info = true,},
		[GridEntityType.GRID_ROCKB] = {info = true,Damage = true,replace_type = true,},
		[GridEntityType.GRID_ROCKT] = {info = true,},
		[GridEntityType.GRID_ROCK_BOMB] = {info = true,},
		[GridEntityType.GRID_ROCK_ALT] = {info = true,},
		[GridEntityType.GRID_ROCK_SS] = {info = true,Damage = true,},
		[GridEntityType.GRID_ROCK_SPIKED] = {info = true,replace_type = true,},
		[GridEntityType.GRID_ROCK_ALT2] = {info = true,},
		[GridEntityType.GRID_ROCK_GOLD] = {info = true,},
		[GridEntityType.GRID_PILLAR] = {info = true,Damage = true,replace_type = true,},
		
		[GridEntityType.GRID_POOP] = {},
		[GridEntityType.GRID_LOCK] = {Damage = true,replace_type = true,},
		[GridEntityType.GRID_TNT] = {},
	},
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		local height = d[item.own_key.."height"] or -24
		ent.FallingSpeed = 0
		if ent.Height > height + 0.3 then
			ent.Height = ent.Height * 0.5 + height * 0.5
			ent.FallingAcceleration = 0
		else
			ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
			ent.FallingAcceleration = ent.FallingAcceleration * 0.95 + (d[item.own_key.."float"] or 1) * 0.05
			d[item.own_key.."FallingSpeed"] = (d[item.own_key.."FallingSpeed"] or 0) + ent.FallingAcceleration
			ent.Height = ent.Height + d[item.own_key.."FallingSpeed"]
			d[item.own_key.."height"] = 100
			--ent.Height = ent.Height - (d[item.own_key.."float"] or 1)
		end
		if d[item.own_key.."orderposition"] then
			local dir = (d[item.own_key.."orderposition"] - ent.Position)
			ent.Velocity = dir:Normalized() * math.min(5 + math.min(5,ent.FrameCount) * 2,dir:Length() * 0.4)
		end
		local s = ent:GetSprite()
		s.Rotation = s.Rotation + d[item.own_key.."rot"]
	end
	if d[item.own_key.."effect2"] then
		if ent.Height > -50 then 
			ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL 
		end
		ent.FallingAcceleration = ent.FallingAcceleration * 0.8 + (d[item.own_key.."float"] or 1) * 0.2
		--d[item.own_key.."float"] = math.min(0,(d[item.own_key.."float"] or 1)) * 0.8 + (-30) * 0.2
		--ent.Height = math.min(-1,ent.Height - (d[item.own_key.."float"] or 1))
		if auxi.check_all_exists(d[item.own_key.."target"]) then
			local dir = (d[item.own_key.."target"].Position - ent.Position)
			ent.Velocity = dir:Normalized() * math.min(25,dir:Length() * 0.4)
		else
			ent.Velocity = ent.Velocity * 0.9
		end
		local s = ent:GetSprite()
		s.Rotation = s.Rotation + d[item.own_key.."rot"]
		--s.Rotation = auxi.get_correct_angle(s.Rotation) * 0.7
		if ent.Height >= 0 then Game():ShakeScreen(5) s:Load("gfx/effects/nil_effect.anm2",true) s:Play("Idle",true) d[item.own_key.."effect2"] = nil end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local idx = d.__Index
	local rng = player:GetCardRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	if d[item.own_key.."effect"] then
		local n_entity = Isaac.GetRoomEntities()
		local n_enemy = auxi.getenemies(n_entity)
		for i = #(d[item.own_key.."effect"]),1,-1 do
			local v = d[item.own_key.."effect"][i]
			if auxi.check_all_exists(v) == false then table.remove(d[item.own_key.."effect"],i) end
			if v.Height <= item.height_limit then
				local d2 = v:GetData()
				d2[item.own_key.."distance"] = nil
				d2[item.own_key.."rotate"] = nil
				table.remove(d[item.own_key.."effect"],i)
				d2[item.own_key.."effect"] = nil
				d2[item.own_key.."effect2"] = true
				d2[item.own_key.."float"] = 4 + math.random(1000)/1000 * 3
				if #n_enemy > 0 then
					local rnd = auxi.random_in_table(n_enemy,rng)
					d2[item.own_key.."target"] = rnd
				end
			end
		end
		for u,v in pairs(d[item.own_key.."effect"]) do
			local d2 = v:GetData()
			local dir = v.Position - player.Position
			local n_dir = auxi.MakeVector(dir:GetAngleDegrees() + (d2[item.own_key.."rotate"] or 10)) * (d2[item.own_key.."distance"] or 100)
			d2[item.own_key.."rotate"] = (d2[item.own_key.."rotate"] or 10) * 1.03
			d2[item.own_key.."distance"] = math.max(30,(d2[item.own_key.."distance"] or 100) - 0.5)
			--d2[item.own_key.."float"] = (d2[item.own_key.."float"] or 1) * 1.05
			d2[item.own_key.."orderposition"] = n_dir + player.Position
		end
		if #d[item.own_key.."effect"] == 0 then d[item.own_key.."effect"] = nil end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	local rng = player:GetCardRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local should_destroy = true
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then should_destroy = false end
		local size = room:GetGridSize()
		Game():ShakeScreen(10)
		local rk_info = grid_morpher.get_morph_dir()
		for i = 0,size - 1 do
			local gent = room:GetGridEntity(i)
			if gent then
				local grid_info = item.rock_grid[gent:GetType()]
				if grid_info and room:IsPositionInRoom(room:GetGridPosition(i),0) and (gent.CollisionClass == GridCollisionClass.COLLISION_SOLID or gent.CollisionClass == GridCollisionClass.COLLISION_OBJECT or gent.CollisionClass == GridCollisionClass.COLLISION_WALL) then
					local q = grid_morpher.morph_grid(gent,{rk_info = rk_info,spawner = player,})
					
					q.Height = -5
					q.CollisionDamage = player.Damage
					if grid_info.Damage then q.CollisionDamage = q.CollisionDamage * 3 end
					q.TearFlags = TearFlags.TEAR_SPECTRAL
					
					local d2 = q:GetData()
					d2.Ignore_me_flag = true
					d2[item.own_key.."effect"] = true
					d2[item.own_key.."distance"] = math.random(1000)/1000 * 150 + 100
					d2[item.own_key.."float"] = - (math.random(1000)/1000 * 5 + 1)
					d2[item.own_key.."rotate"] = (math.random(1000)/1000 * 10 + 10) * (math.random(2) * 2 - 3)
					d2[item.own_key.."rot"] = (math.random(1000)/1000 * 60 + 10) * (math.random(2) * 2 - 3)
					d2[item.own_key.."height"] = - (math.random(1000)/1000 * 10 + 19)
					
					d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}
					table.insert(d[item.own_key.."effect"],#d[item.own_key.."effect"] + 1,q)
					
					room:RemoveGridEntity(i, 0, false)
					if should_destroy then
						delay_buffer.addeffe(function(params)
							room:SpawnGridEntity(i, 1, 0, 0, 0)
							local ggent = room:GetGridEntity(i)
							if ggent then
								local s2 = ggent:GetSprite()
								s2:ReplaceSpritesheet(0,"gfx/effects/nill.png")
								s2:LoadGraphics()
							end
						end,{},2)
					end
				end
			end
		end
	end
end,
})


return item
