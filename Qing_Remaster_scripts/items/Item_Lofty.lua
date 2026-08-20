local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local input_holder = require("Qing_Remaster_scripts.others.Input_holder")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Lofty,
	time_counter = 90,
	mode_vel = {
		[1] = 4,
		[3] = 10,
		[2] = 20,
	},
	mode_addvel = {
		[1] = -0.08,
		[3] = 0.2,
		[2] = -0.4,
	},
	own_key = "Item_Lofty_",
}
auxi.add_to_seija(item.entity)

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	local room = Game():GetRoom()
	local s = player:GetSprite()
	local d = player:GetData()
	if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
		if auxi.has_have_coll(player,item.entity) then
			d["Lofty_counter"] = d["Lofty_counter"] or 0
			local cnt = d["Lofty_counter"]
			Charging_Bar_holder.render_me(player,{name1 = "Lofty_counter",name2 = "Lofty_sprite",name3 = "Lofty",loadname = "gfx/effects/chargebar/chargebar_Lofty.anm2",		--使用另外一个charge减少修改量
				check1 = function(val,ent)
					return cnt > 5
				end,
				check2 = function(val,ent) 
					return cnt > item["time_counter"]
				end,
				check3 = function(val,ent)
					return math.ceil(cnt/item["time_counter"] * 100)
				end,
				signal1 = function(ent)
					d["Lofty_active"] = true
				end,
			})
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = item.entity,
Function = function(_,player,collid,count)
	if count < 0 then
		Charging_Bar_holder.remove_charge_bar(player,"Lofty")
	end
end,
})

function item.start_lofty(player,mode,dmg)
	local d = player:GetData()
	if d.Lofty_holder == nil then d.Lofty_holder = {} end
	local q = Isaac.Spawn(7,5,3,player.Position,Vector(0,0),player):ToLaser()
	q.Parent = player
	q.Radius = 0
	local d2 = q:GetData()
	d2.basic_damage = (dmg or player.Damage)
	q.CollisionDamage = d2.basic_damage
	local s = q:GetSprite()
	s:Load("gfx/laser_concerter.anm2",true)
	s:ReplaceSpritesheet(0,"gfx/effects/lasers/lofty_brim.png")
	s:LoadGraphics()
	s:Play("LargeRedLaser",true)
	table.insert(d.Lofty_holder,{ent = q,mode = mode,Radius_adder = item.mode_vel[mode],Radius_vel_adder = item.mode_addvel[mode]})
	return q
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	if d.Lofty_holder ~= nil then
		local n_entity = Isaac.GetRoomEntities()
		local n_enemy = auxi.getenemies(n_entity)
		local n_proj = auxi.getothers(n_entity,9)
		local tbl = {}
		for u,v in pairs(d.Lofty_holder) do
			local ent = v.ent
			if ent == nil or ent:Exists() == false then 
				table.remove(d.Lofty_holder,u)
			else
				ent.Radius = ent.Radius + (v.Radius_adder or 3)
				v.Radius_adder = math.max(0,(v.Radius_adder or 3) + (v.Radius_vel_adder or 0))
				local s = ent:GetSprite()
				if v.mode == 1 then
					s.Color = Color(1,1,1,math.max(0,math.min(s.Color.A - 0.015,s.Color.A * 0.96)))
				else
					s.Color = Color(1,1,1,math.max(0,math.min(s.Color.A - 0.01,s.Color.A * 0.97)))
				end
				ent.CollisionDamage = (ent:GetData().basic_damage or 7) * s.Color.A
				if s.Color.A < 0.05 then
					ent:Remove()
				end
				if s.Color.A > 0.15 then
					for u2,v2 in pairs(n_proj) do
						if math.abs((v2.Position - ent.Position):Length() - ent.Radius) < 30 then
							v2:Remove()
							table.remove(n_proj,u2)
						end
					end
				end
				if s.Color.A > 0.15 then
					for u2,v2 in pairs(n_enemy) do
						if math.abs((v2.Position - ent.Position):Length() - ent.Radius) < 30 then
							table.insert(tbl,{ent = v2,colorA = s.Color.A,dmg = ent.CollisionDamage})
						end
					end
				end
			end
		end
		for u,v in pairs(tbl) do
			local d2 = v.ent:GetData()
			if d2.Lofty_holdit == nil or d2.Lofty_holdit:Exists() == false then
				local q = item.start_lofty(player,2,v.dmg)
				local n_t = auxi.fire_nil(v.ent.Position,v.ent.Velocity)
				n_t:GetData().follower = v.ent
				d2.Lofty_holdit = q
				q.Parent = n_t
				q.Position = v.ent.Position
				q.Color = Color(1,1,1,math.max(0.7,v.colorA - 0.1))
			end
		end
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_,ent,amt,flag,source,cooldown)
	local player = ent:ToPlayer()
	if amt > 0 and auxi.is_damage_from_enemy(ent, amt, flag, source, cooldown) then
		if player and auxi.has_have_coll(player,item.entity) then
			local idx = player:GetData().__Index
			if idx then
				save.elses[item.own_key.."limit"] = save.elses[item.own_key.."limit"] or {}
				if (save.elses[item.own_key.."limit"][idx] or 1) > 0 then
					item.start_lofty(player,2,player.Damage * 1.5)
					save.elses[item.own_key.."limit"][idx] = (save.elses[item.own_key.."limit"][idx] or 1) - 1
					local e1 = Isaac.Spawn(1000,16,2,player.Position + Vector(0,1),Vector(0,0),player)
					local e2 = Isaac.Spawn(1000,16,1,player.Position + Vector(0,1),Vector(0,0),player)
					e1:GetSprite().Scale = Vector(2,2)
					e2:GetSprite().Scale = Vector(2,2)
					player:SetMinDamageCooldown(cooldown)
					return false
				end
			end
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
		if auxi.g_dir_can_work(player) then
			if auxi.has_have_coll(player,item.entity) then
				local act = false
				for i = 4,7 do
					if (Input.IsActionTriggered(i,ctrlid)) or (Input.IsActionPressed(i,ctrlid)) then
						act = true
					end
				end
				local idx = d.__Index
				if idx then
					save.elses[item.own_key.."limit"] = save.elses[item.own_key.."limit"] or {}
					if act and (save.elses[item.own_key.."limit"][idx] or 1) > 0 then
						if d["Lofty_counter"] == nil then d["Lofty_counter"] = 0 end
						d["Lofty_counter"] = d["Lofty_counter"] + 1
					else
						if d["Lofty_active"] == true then
							d["Lofty_active"] = false
							item.start_lofty(player,1,player.Damage * 2.5)
						end
						d["Lofty_counter"] = 0
					end
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.has_have_coll(player,item.entity) then
			local idx = player:GetData().__Index
			if idx then
				save.elses[item.own_key.."limit"] = save.elses[item.own_key.."limit"] or {}
				if not auxi.should_do_Seija(player) then save.elses[item.own_key.."limit"][idx] = player:GetCollectibleNum(item.entity) end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
Function = function(_)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.has_have_coll(player,item.entity) then
			local idx = player:GetData().__Index
			if idx then
				save.elses[item.own_key.."limit"] = save.elses[item.own_key.."limit"] or {}
				if auxi.should_do_Seija(player) then save.elses[item.own_key.."limit"][idx] = player:GetCollectibleNum(item.entity) end
			end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."limit"] = {}
	end
	save.elses[item.own_key.."limit"] = save.elses[item.own_key.."limit"] or {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = FamiliarVariant.ABYSS_LOCUST,
Function = function(_,ent)
	if ent.Type == 3 and ent.Variant == FamiliarVariant.ABYSS_LOCUST and ent.SubType == item.entity then
		local d = ent:GetData()
		if (d[item.own_key.."counter"] or 0) > 0 then d[item.own_key.."counter"] = d[item.own_key.."counter"] - 1 end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_FAMILIAR_COLLISION, params = FamiliarVariant.ABYSS_LOCUST,
Function = function(_,ent,col,low)
	if ent.Type == 3 and ent.Variant == FamiliarVariant.ABYSS_LOCUST and ent.SubType == item.entity then
		local player = auxi.check_spawner_player(ent)
		local d = ent:GetData()
		if (d[item.own_key.."counter"] or 0) <= 0 and auxi.isenemies(col) and ent.State == -1 then 
			d[item.own_key.."counter"] = 10 * 30
			local q = item.start_lofty(player,1,player.Damage * 0.5)
			q.Parent = ent
		end
	end
end,
})

return item
