local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local input_holder = require("Qing_Remaster_scripts.others.Input_holder")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Item_Assassin_s_Eye = require("Qing_Remaster_scripts.items.Item_Assassin_s_Eye")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Ingestion_to_Night,
	ls = {},
	BarRenderOffset = Vector(-20,-18),
}

for i = 1,4 do
	item["s_I2N_"..i] = Sprite()
	item["s_I2N_"..i.."_pos"] = Vector(0,0)
	item["s_I2N_"..i.."_vel"] = Vector(0,0)
	item["s_I2N_"..i]:Load("gfx/mimics/Ingestion_to_Night/Dark_side.anm2",true)
	item["s_I2N_"..i]:Play("Idle_X",true)
	item["s_I2N_"..i].Color = Color(1,1,1,0)
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local cnt = player:GetCollectibleNum(item.entity)
	if cnt > 0 then
		if cacheFlag == CacheFlag.CACHE_FLYING then
			player.CanFly = true
		end
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1 * auxi.get_damage_multiplier(player) * cnt
        end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = item.entity,
Function = function(_,player,collid,cnt,touched)
	if save.elses.sol_use ~= true then
		local level = Game():GetLevel()
		local desc = level:GetRoomByIdx(level:GetCurrentRoomDesc().SafeGridIndex)
		if desc then
			desc.Flags = desc.Flags | RoomDescriptor.FLAG_PITCH_BLACK
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	local render_count = 0
	local t_player = nil
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.has_have_coll(player,item.entity) then
			player:GetData()["Ingestion2n_counter"] = player:GetData()["Ingestion2n_counter"] or 0
			if player:GetData()["Ingestion2n_counter"] > render_count then
				t_player = player
				render_count = player:GetData()["Ingestion2n_counter"]
			end
		end
	end
	if render_count > 0 and save.elses.sol_use ~= true then
		local idi = 4
		for i = 1,idi do
			item["s_I2N_"..i].Color = Color(1,1,1,render_count/180 * 0.7)
			item["s_I2N_"..i]:Render(item["s_I2N_"..i.."_pos"],Vector(0,0),Vector(0,0))
			local id = math.ceil(render_count/20 + 1)
			local del_vel = Vector(math.random(2 * id + 1) - id,math.random(2 * id + 1) - id)
			item["s_I2N_"..i.."_pos"] = item["s_I2N_"..i.."_pos"] + del_vel + item["s_I2N_"..i.."_vel"]
			item["s_I2N_"..i.."_pos"].X = math.max(math.min(600,item["s_I2N_"..i.."_pos"].X),-600)
			item["s_I2N_"..i.."_pos"].Y = math.max(math.min(600,item["s_I2N_"..i.."_pos"].Y),-600)
			item["s_I2N_"..i.."_vel"] = item["s_I2N_"..i.."_vel"] * 0.7 + del_vel
		end
		if Game():IsPaused() == false then
			local rnd = math.random(10000)
			if rnd > 7000 then
				local rnd = math.random(3) - 2
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_DEATH_CARD,math.max(0.5,render_count/240 * 0.5),math.random(2000)/10000 + 0.9,false,rnd,2)
			end
		end
	else
		local idi = 4
		for i = 1,idi do
			if item["s_I2N_"..i].Color.A > 0.01 then
				item["s_I2N_"..i]:Render(item["s_I2N_"..i.."_pos"],Vector(0,0),Vector(0,0))
				item["s_I2N_"..i].Color = Color(1,1,1,item["s_I2N_"..i].Color.A * 0.97)
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local player = auxi.have_player_has_collectible(item.entity)
	local room = Game():GetRoom()
	local level = Game():GetLevel()
	if player then
		if save.elses.sol_use ~= true then
			if room:IsFirstVisit() or save.elses.r_sol_use then
				local rng = player:GetCollectibleRNG(item.entity)
				local desc = level:GetRoomByIdx(level:GetCurrentRoomDesc().SafeGridIndex)
				if desc and rng:RandomFloat() < 0.33 then
					desc.Flags = desc.Flags | RoomDescriptor.FLAG_PITCH_BLACK
				end
				rng:Next()
			end
		else
			local desc = level:GetRoomByIdx(level:GetCurrentRoomDesc().SafeGridIndex)
			if desc then
				desc.Flags = desc.Flags & (~RoomDescriptor.FLAG_PITCH_BLACK)
			end
		end
	end
end,
})

local function start_ingestion(player,counter)
	if player == nil then return end
	local id = math.floor((counter-180)/90) + 1
	local n_entity = Isaac.FindInRadius(player.Position,500,1<<3)
	local n_enemy = auxi.getenemies(n_entity)
	if #n_enemy == 0 then table.insert(n_enemy,#n_enemy + 1,player) end
	for i = 1,id do
		local rnd = 7 + math.random(math.ceil(#n_enemy * 2.5))
		for j = 1,rnd do
			local q = Item_Assassin_s_Eye.fire_Assassin_tear(player,n_enemy[math.random(#n_enemy)].Position + auxi.RoundVector(nil,30,{leg2 = 20,}),Vector(0,0),{counter = 0,})
			local s = q:GetSprite()
			local d = q:GetData()
			q.CollisionDamage = player.Damage * 0.65
			q.Visible = false
			q.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
			q.GridCollisionClass = GridCollisionClass.COLLISION_NONE
			d.is_I2N = true
		end
	end
	for i = 1,3 do
		delay_buffer.addeffe(function(params)
			for j = 1,2 do
				local rnd = math.random(3) - 2
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_DEATH_CARD,math.random(2000)/10000 + 0.9,math.random(2000)/10000 + 0.9,false,rnd,2)
			end
		end,{},i * 3)
	end
	local n_projectiles = Isaac.FindInRadius(player.Position,500,1<<1)
	for u,v in pairs(n_projectiles) do
		local q = Item_Assassin_s_Eye.fire_Assassin_tear(player,v.Position,-v.Velocity,{counter = 0,})
		q.CollisionDamage = player.Damage * 1.75
		local s = q:GetSprite()
		auxi.copy_sprite(v:GetSprite(),s)
		local d = q:GetData()
		q.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
		q.GridCollisionClass = GridCollisionClass.COLLISION_NONE
		d.is_I2N = true
		v:Remove()
	end
	if save.elses.r_sol_use then
		local rnd = math.random(3) + 1
		for j = 1,rnd do
			local mx_cnt = math.random(10) + 10
			for i = 1,mx_cnt do
				local pos = player.Position + auxi.MakeVector(360/mx_cnt*i) * (120 * (j * 0.3 + 1))
				local q2 = Isaac.Spawn(1000,EffectVariant.CRACK_THE_SKY,0,pos,Vector(0,0),player)
				q2.CollisionDamage = 5
				q2:GetSprite().Color = Color(1,1,1,1,-1,-1,-1)
			end
		end
	end
end

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = nil,
Function = function(_,ent)
	if ent.Type == 2 then
		local d = ent:GetData()
		if d.is_I2N then
			item.should_remove_poof = 5
		end
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_,ent,amt,flag,source,cooldown)
	if save.elses.sol_use ~= true then
		local player = ent:ToPlayer()
		if player then
			if auxi.is_damage_from_enemy(ent, amt, flag, source, cooldown) then
				if auxi.has_have_coll(player,item.entity) then
					local cnt = player:GetData()["Ingestion2n_counter"] or 0
					if cnt > 130 then
						local rnd = math.random(1000)
						if rnd > 700 then
							player:SetMinDamageCooldown(cooldown)
							return false
						end
					end
				end
			end
		end
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_INIT, params = nil,
Function = function(_,ent)
	if ent.Type == 1000 and (ent.Variant == 11 or ent.Variant == 12 or ent.Variant == 13) then
		if item.should_remove_poof and item.should_remove_poof > 0 then
			ent:Remove()
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = Card.CARD_SUN,
Function = function(_,cardtype,player,useflags)
	if cardtype == Card.CARD_SUN then
		if auxi.has_have_coll(player,item.entity) then
			save.elses.sol_use = true
			local level = Game():GetLevel()
			local desc = level:GetRoomByIdx(level:GetCurrentRoomDesc().SafeGridIndex)
			if desc then
				desc.Flags = desc.Flags & (~RoomDescriptor.FLAG_PITCH_BLACK)
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = Card.CARD_REVERSE_SUN,
Function = function(_,cardtype,player,useflags)
	if cardtype == Card.CARD_REVERSE_SUN then
		if auxi.has_have_coll(player,item.entity) then
			save.elses.sol_use = false
			save.elses.r_sol_use = true
			local level = Game():GetLevel()
			local desc = level:GetRoomByIdx(level:GetCurrentRoomDesc().SafeGridIndex)
			if desc then
				desc.Flags = desc.Flags | RoomDescriptor.FLAG_PITCH_BLACK
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_GET_CARD, params = nil,
Function = function(_,rng,card,playing,rune,onlyrune)
	local should_count = false
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.has_have_coll(player,item.entity) then
			should_count = true
		end
	end
	if should_count then
		if card ~= Card.CARD_REVERSE_SUN and card ~= Card.CARD_SUN and ((card > 0 and card < 23) or (card > 55 and card < 78)) then
			rng = auxi.rng_for_sake(rng)
			local rnd = rng:RandomInt(10)
			if rnd == 1 then
				if save.elses.sol_use ~= true then
					if card ~= Card.CARD_SUN then
						return Card.CARD_SUN
					end
				end
				if save.elses.r_sol_use ~= true then
					if card ~= Card.CARD_REVERSE_SUN then
						return Card.CARD_REVERSE_SUN
					end
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses.sol_use = false
		save.elses.r_sol_use = false
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses.sol_use = false
	save.elses.r_sol_use = false
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.has_have_coll(player,item.entity) then
			local level = Game():GetLevel()
			local desc = level:GetRoomByIdx(level:GetCurrentRoomDesc().SafeGridIndex)
			if desc then
				desc.Flags = desc.Flags | RoomDescriptor.FLAG_PITCH_BLACK
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if item.should_remove_poof and item.should_remove_poof > 0 then
		item.should_remove_poof = item.should_remove_poof - 1
	end
	if save.elses.sol_use ~= true then
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
					if save.elses.r_sol_use then
						if act == true then
							if d["Ingestion2n_active"] == true then
								d["Ingestion2n_active"] = false
								start_ingestion(player,d["Ingestion2n_counter"])
								d["Ingestion2n_counter"] = 0
							end
						end
						if d["Ingestion2n_counter"] == nil then d["Ingestion2n_counter"] = 0 end
						d["Ingestion2n_counter"] = d["Ingestion2n_counter"] + 2
					else
						if act == true then
							if d["Ingestion2n_counter"] == nil then d["Ingestion2n_counter"] = 0 end
							d["Ingestion2n_counter"] = d["Ingestion2n_counter"] + 1
						else
							if d["Ingestion2n_active"] == true then
								d["Ingestion2n_active"] = false
								start_ingestion(player,d["Ingestion2n_counter"])
							end
							d["Ingestion2n_counter"] = 0
						end
					end
				end
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_RENDER, params = nil,
Function = function(_,player,offset)
	if save.elses.sol_use ~= true then
		local room = Game():GetRoom()
		local s = player:GetSprite()
		local d = player:GetData()
		if (Game():GetRoom():GetRenderMode() ~= RenderMode.RENDER_WATER_REFLECT) then
			if auxi.has_have_coll(player,item.entity) then
				d["Ingestion2n_counter"] = d["Ingestion2n_counter"] or 0
				local cnt = d["Ingestion2n_counter"]
				Charging_Bar_holder.render_me(player,{name1 = "Ingestion2n_counter",name2 = "Ingestion2n_sprite",name3 = "I_2_N",loadname = "gfx/effects/chargebar/chargebar_I_t_N.anm2",		--使用另外一个charge减少修改量
					check1 = function(val,ent)
						return cnt > 5
					end,
					check2 = function(val,ent) 
						return cnt > 180
					end,
					check3 = function(val,ent)
						return math.ceil(cnt/1.8)
					end,
					signal1 = function(ent)
						d["Ingestion2n_active"] = true
					end,
				})
			end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE, params = nil,
Function = function(_,player,collid,count)
	if collid == item.entity and count < 0 then
		Charging_Bar_holder.remove_charge_bar(player,"Blaststone")
	end
end,
})

return item