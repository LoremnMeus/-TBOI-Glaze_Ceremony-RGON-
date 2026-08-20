local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local input_holder = require("Qing_Remaster_scripts.others.Input_holder")
local revive_holder = require("Qing_Remaster_scripts.callbacks.revive_holder")
local selection_holder = require("Qing_Remaster_scripts.others.selection_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Devil_s_Heart,
	revive_counter = 95,
	costumes = {
		enums.Costumes.Devil_s_Heart_Head,
		enums.Costumes.D_s_H_2,
		enums.Costumes.D_s_H_3,
		enums.Costumes.D_s_H_4,
	},
	own_key = "Item_Devil_s_Heart_",
}
auxi.add_to_seija(item.entity)

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."Costume"] = {}
	end
	save.elses[item.own_key.."Costume"] = save.elses[item.own_key.."Costume"] or {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,coltyp,rng,player,useFlags,activeSlot,customVarData)
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local d = player:GetData()
		if d.is_holding_D_S_H_item ~= true then
			player:AnimateCollectible(item.entity,"LiftItem","PlayerPickup")
			d.is_holding_D_S_H_item = true
			return {Discharge = false}
		else
			player:AnimateCollectible(item.entity,"HideItem","PlayerPickup")
			d.is_holding_D_S_H_item = false
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local room = Game():GetRoom()
	if d.is_holding_D_S_H_item == true then
		if player:IsHoldingItem() == false then
			d.is_holding_D_S_H_item = false
		else
			local dir = 0
			local ctrlid = player.ControllerIndex
			for i = 4,7 do
				if (Input.IsActionPressed(i,ctrlid) and input_holder.actionsData[tostring(ctrlid)] and input_holder.actionsData[tostring(ctrlid)][i] and input_holder.actionsData[tostring(ctrlid)][i].ActionHoldTime and input_holder.actionsData[tostring(ctrlid)][i].ActionHoldTime == 1) then
					dir = i
				end
			end
			if dir > 0 then
				local vel = Vector(0,0)
				if room:IsMirrorWorld() == true and (dir == 4 or dir == 5) then dir = 9 - dir end
				if dir == 4 then vel = vel + Vector(-1,0)
				elseif dir == 5 then vel = vel + Vector(1,0)
				elseif dir == 6 then vel = vel + Vector(0,-1)
				elseif dir == 7 then vel = vel + Vector(0,1) end
				player:AnimateCollectible(item.entity,"HideItem","PlayerPickup")
				d.is_holding_D_S_H_item = false
				local q = Isaac.Spawn(2,1,0,player.Position + player.Velocity * 0.2 + vel * player.ShotSpeed * 5,vel * player.ShotSpeed * 10 + player.Velocity * 0.3,player):ToTear()
				local s = q:GetSprite()
				s:Load("gfx/mimics/Devil_s_Heart/Devil_s_Heart_Tear.anm2",true)
				s:Play("Idle",true)
				q.CollisionDamage = 0
				local d2 = q:GetData()
				d2[item.own_key.."Seeded"] = true
				d2[item.own_key.."player"] = player
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."Seeded"] and d[item.own_key.."Seeded"] == true then
		local s = ent:GetSprite()
		s.Rotation = ent.Velocity:GetAngleDegrees()
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION, params = nil,
Function = function(_,ent,col,low)
	local d = ent:GetData()
	if d[item.own_key.."Seeded"] then
		if col:IsVulnerableEnemy() and col:IsActiveEnemy() then
			local d2 = col:GetData()
			d2[item.own_key.."Seeded"] = true
			d2[item.own_key.."player"] = d[item.own_key.."player"]
			d[item.own_key.."Seeded"] = nil
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_RENDER, params = nil,
Function = function(_,ent,offset)
	local d = ent:GetData()
	if d[item.own_key.."Seeded"] then
		if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
			if d.devil_seed_to_render == nil then d.devil_seed_to_render = {} end
			for u,v in pairs(d.devil_seed_to_render) do
				if v.id <= 4 then
					local s = v.sprite
					if s:IsFinished(v.now_play) then
						table.remove(d.devil_seed_to_render,u)
					else
						s:Render(Isaac.WorldToScreen(ent.Position + v.offset),Vector(0,0),Vector(0,0))
						if Game():GetFrameCount() % 2 == 1 then
							if v.color then
								s.Color = auxi.AddColor(s.Color,v.color,0.9,0.1)
							end
							s:Update()
						end
					end
				end
			end
			for u,v in pairs(d.devil_seed_to_render) do
				if v.id > 4 then
					local s = v.sprite
					if s:IsFinished(v.now_play) then
						table.remove(d.devil_seed_to_render,u)
					else
						s:Render(Isaac.WorldToScreen(ent.Position + v.offset),Vector(0,0),Vector(0,0))
						if Game():GetFrameCount() % 2 == 1 then
							if v.color then
								s.Color = auxi.AddColor(s.Color,v.color,0.9,0.1)
							end
							s:Update()
						end
					end
				end
			end
			if Game():GetFrameCount() % 2 == 1 then
				local n_s = Sprite()
				n_s:Load("gfx/mimics/Devil_s_Heart/Dark_tentacle.anm2",true)
				local name = "Overlay"
				local rnd = math.random(10)
				if rnd > 4 then
					name = name .. tostring(rnd)
					n_s:Play(name,true)
					n_s.PlaybackSpeed = math.random(30, 100)/100
					n_s.FlipX = (math.random(2) > 1 and true or false)
					local offset = Vector(0,0)
					if rnd > 4 then
						offset.X = math.random(8)*(math.random(2) > 1 and -1 or 1)
						n_s.PlaybackSpeed = math.random(30, 100)/100
						local scale = math.random(100, 160)/100
						n_s.Scale = Vector(scale, scale)
						n_s.Color = Color(1,1,1,1,0.2 + math.random(100)/100 * 0.3,0,0)
					else
						offset.X = math.random(10)*(math.random(2) > 1 and -1 or 1)
						local scale = math.random(70, 110)/100
						n_s.Scale = Vector(scale, scale)
					end
					local tab = {sprite = n_s,now_play = name,offset = offset,id = rnd,}
					if rnd > 4 then
						tab.color = Color(1,1,1,1,0,0,0)
					end
					table.insert(d.devil_seed_to_render,tab)
				end
			end
		end
	end
end,
})

function item.find_a_seeded_ent(player)
	local n_entity = Isaac.GetRoomEntities()
	local n_enemy = auxi.getenemies(n_entity)
	for u,v in pairs(n_enemy) do
		local d = v:GetData()
		if d[item.own_key.."Seeded"] and d[item.own_key.."player"] then
			if auxi.check_for_the_same(player,d[item.own_key.."player"]) then return v end
		end
	end
end

function item.recheck_costume(player)
	local d = player:GetData()
	local idx = d.__Index
	save.elses[item.own_key.."Costume"] = save.elses[item.own_key.."Costume"] or {}
	for i = 1,math.min(save.elses[item.own_key.."Costume"][idx] or 0,#item.costumes) do
		player:AddNullCostume(item.costumes[i])
	end
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_PLAYER_KILL, params = nil,
Function = function(_,player)
	if not player:WillPlayerRevive() then
		local d = player:GetData()
		if not d[item.own_key.."has_revive"] then
			local reviver = item.find_a_seeded_ent(player)
			if reviver then
				local ret = {should_revive = true,on_revive = function(player,tp)
					local d = player:GetData()
					if auxi.check_all_exists(d[item.own_key.."revive_ent"]) == false then d[item.own_key.."revive_ent"] = item.find_a_seeded_ent(player) end
					if auxi.check_all_exists(d[item.own_key.."revive_ent"]) then 
						local ent = d[item.own_key.."revive_ent"]
						local d2 = ent:GetData()
						local idx = d.__Index
						local rng = player:GetCollectibleRNG(item.entity)
						rng = auxi.rng_for_sake(rng)
						
						d2[item.own_key.."Seeded"] = nil
						d2[item.own_key.."player"] = nil
						save.elses[item.own_key.."Costume"] = save.elses[item.own_key.."Costume"] or {}
						save.elses[item.own_key.."Costume"][idx] = (save.elses[item.own_key.."Costume"][idx] or 0) + 1
						if auxi.should_do_belial(player) then
							if save.elses[item.own_key.."Costume"][idx] <= 5 then player:AddCollectible(51)
							elseif save.elses[item.own_key.."Costume"][idx] <= 12 then player:AddCollectible(462)
							elseif save.elses[item.own_key.."Costume"][idx] >= 13 then player:AddCollectible(118) end
						end
						item.recheck_costume(player)
						player.Position = ent.Position
						local hp = ent.HitPoints
						local rnd = rng:RandomInt(math.ceil(math.log(hp/3))) + save.elses[item.own_key.."Costume"][idx]
						if hp > 150 then rnd = rnd + rng:RandomInt(math.ceil(math.log(hp)))	end
						if hp > 800 then rnd = rnd + rng:RandomInt(math.ceil(math.log(hp * 2))) end
						if hp > 3000 then rnd = math.max(rnd,wei + 3) end
						
						local n_entity = Isaac.GetRoomEntities()
						local wisps = auxi.getothers(n_entity,3,FamiliarVariant.WISP,item.entity)
						for i = 1,math.min(rnd,#wisps) do
							wisps[i]:Remove()
							rnd = math.max(0,rnd - 1)
						end
						if auxi.should_do_Seija(player,true) then rnd = 0 end
						if player:GetHeartLimit() == 1 then player:Kill() return end
						for i = 1,rnd do
							local ret = auxi.get_random_item_that_player_has(player,rng,{ignore_pocket_item = true,ignore_pool = {[item.entity] = 1,},})
							if ret then player:RemoveCollectible(ret)
							else player:AddBrokenHearts(math.min(player:GetHeartLimit() - 1,1)) end
						end
						ent:Kill()
					else player:Kill() return end
					d[item.own_key.."has_revive"] = nil
				end,}
				d[item.own_key.."revive_ent"] = reviver
				d[item.own_key.."has_revive"] = true
				return ret
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_INIT, params = nil,
Function = function(_,player)
	local d = player:GetData()
	local idx = d.__Index
	if idx then
		if Game():GetFrameCount() > 2 then
			item.recheck_costume(player)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = nil,
Function = function(_,collid, itemRng, player, useFlags, activeSlot, customVarData)
	if collid == 283 or collid == 284 or collid == 703 then
		item.recheck_costume(player)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_FAMILIAR_COLLISION, params = FamiliarVariant.ABYSS_LOCUST,
Function = function(_,ent,col,low)
	if ent.Type == 3 and ent.Variant == FamiliarVariant.ABYSS_LOCUST and ent.SubType == item.entity then
		local player = auxi.check_spawner_player(ent)
		local d = ent:GetData()
		if auxi.isenemies(col) and ent.State == -1 then 
			local d2 = col:GetData()
			d2[item.own_key.."Seeded"] = true
			d2[item.own_key.."player"] = player
		end
	end
end,
})

return item