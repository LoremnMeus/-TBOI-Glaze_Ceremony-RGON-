local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local grid_entity = require("Qing_Remaster_scripts.grids.grid_entity")
local danger_data = require("Qing_Remaster_scripts.others.Danger_Data")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local player_offset_holder = require("Qing_Remaster_scripts.callbacks.player_offset_holder")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")
local Screen_Filter = require("Qing_Remaster_scripts.others.Screen_Filter")
local Card_16r_Tower = require("Qing_Remaster_scripts.cards.Card_16r_Tower")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Calamity,
	own_key = "Item_Calamity_",
	scaler = Vector(0,-60),
	slots = {},
	moveoffset = {
		{frame = 0,val = Vector(0,0),},
		{frame = 12,val = Vector(0,-20),},
		{frame = 20,val = Vector(0,-100),},
		{frame = 60,val = Vector(0,-400),},
		mx = 60,
	},
	bustoffset = {
		{frame = 0,val = Vector(0,-400),},
		{frame = 30 * 2,val = Vector(0,-100),},
		{frame = 30 * 13,val = Vector(0,-20),},
		{frame = 30 * 15,val = Vector(0,0),},
		mx = 30 * 15,
	},
	ignorers = {
		[1] = true,
		[3] = true,
		[7] = true,
		[8] = true,
	},
	delayer = {
		[6] = 0,
	},
	level_info = {
		[8] = "Both",
		[9] = "Both",
		[10] = "Chest",
		[11] = "Chest",
		[12] = "Chest",
		[13] = "Void",
	},
	no_remove = {
		[GridEntityType.GRID_WALL] = true,
		[GridEntityType.GRID_DOOR] = true,
		[GridEntityType.GRID_STAIRS] = true,
	},
}

function item.Kill_room(slot)
	local room = Game():GetRoom()
	local level = Game():GetLevel()
	local door = room:GetDoor(slot)
	if door and level:GetRoomByIdx(door.TargetRoomIndex) then
		local desc = level:GetRoomByIdx(door.TargetRoomIndex)
		save.elses[item.own_key.."Kill2"] = save.elses[item.own_key.."Kill2"] or {}
		local ridx = auxi.get_acceptible_index(desc.SafeGridIndex)
		if desc.Data then
			if desc.ClearCount > 0 then return end
			local spawns = desc.Data.Spawns
			local sz = spawns.Size
			local tbl = {}
			for i = 1,sz do
				local entinfo = spawns:Get(i - 1):PickEntry(math.random(1000)/1000)
				if entinfo.Type >= 10 and entinfo.Type < 999 then
					local tpinfo = {Type = entinfo.Type,Variant = entinfo.Variant,SubType = entinfo.Subtype,}
					local check_info = danger_data.check_data(tpinfo)
					if check_info then
						local q = Isaac.Spawn(tpinfo.Type,tpinfo.Variant,tpinfo.SubType,door.Position,Vector(0,0),nil):ToNPC()
						q:Morph(tpinfo.Type,tpinfo.Variant,tpinfo.SubType,-1)
						local s = q:GetSprite()
						s:SetLastFrame()
						local d = q:GetData()
						d[item.own_key.."effect"] = true
						d[item.own_key.."EntityFlag_FLAG_FEAR"] = Attribute_holder.try_hold_attribute(q,"EntityFlag_FLAG_FEAR",true,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_FEAR))
						d[item.own_key.."EntityFlag_FLAG_BURN"] = Attribute_holder.try_hold_attribute(q,"EntityFlag_FLAG_BURN",true,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_BURN))
						d[item.own_key.."Color"] = Attribute_holder.try_hold_attribute(q,"Color",Color(1,1,1,1,1,0,0))
						table.insert(tbl,#tbl + 1,q)
					end
				end
			end
			delay_buffer.addeffe(function(params)
				room:MamaMegaExplosion(door.Position)
				delay_buffer.addeffe(function(params)
					for u,v in pairs(tbl) do if auxi.check_all_exists(v) then auxi.safely_kill(v) end end
				end,{},5)
			end,{},30 * 2)
		end
	end
end

function item.KillRoom2(player,door)
	local level = Game():GetLevel()
	local d = player:GetData()
	local s = auxi.load_item(item.entity)
	player.Velocity = Vector(0,0)
	player:AnimatePickup(s,true,"LiftItem")
	d[item.own_key.."AnnaKiller"] = {sgid = door.TargetRoomIndex,dir = door.Direction,}
	player_offset_holder.LoadPlayer(nil,true)
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHECK_PLAYER_POSITIONOFFSET, params = nil,
Function = function(_,player,value)
	local d = player:GetData()
	if player:GetPlayerType() == enums.Players.Anna then
		if d[item.own_key.."AnnaKiller"] then
			value.Remove = false
			local info = auxi.check_lerp(d[item.own_key.."AnnaKiller"].counter or 0,item.moveoffset)
			value.Offset = value.Offset + info.val
		end
		if d[item.own_key.."AnnaKiller2"] then
			value.Remove = false
			local info = auxi.check_lerp(d[item.own_key.."AnnaKiller2"].counter or 0,item.bustoffset)
			value.Offset = value.Offset + info.val
		end
		return value
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."Kill"] = {}
		save.elses[item.own_key.."Kill2"] = {}
	end
	save.elses[item.own_key.."Kill"] = save.elses[item.own_key.."Kill"] or {}
	save.elses[item.own_key.."Kill2"] = save.elses[item.own_key.."Kill2"] or {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_ROOM_ENTITY_SPAWN, params = nil,
Function = function(_,tp,vr,st)
	local ridx = auxi.get_acceptible_index()
	save.elses[item.own_key.."Kill2"] = save.elses[item.own_key.."Kill2"] or {}
	if save.elses[item.own_key.."Kill2"][ridx] then return {999,enums.Entities.Remover,0} end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, params = nil,
Function = function(_,rng,pos)
	if Game():GetRoom():GetType() == 5 then
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET do 
				 if player:GetActiveItem(slot) == item.entity and auxi.should_real_charge(player,slot) then
					player:SetActiveCharge(player:GetActiveCharge(slot) + player:GetBatteryCharge(slot) + auxi.get_charge_from_room(),slot)
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_ITEMRECHARGE,1,1,false,0,2)
				 end
			end
		end
	else
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			if player:GetPlayerType() == enums.Players.Anna then
				for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET do 
					 if player:GetActiveItem(slot) == item.entity and auxi.should_real_charge(player,slot) then
						player:SetActiveCharge(player:GetActiveCharge(slot) + player:GetBatteryCharge(slot) + auxi.get_charge_from_room(),slot)
						sound_tracker.PlayStackedSound(SoundEffect.SOUND_ITEMRECHARGE,1,1,false,0,2)
					 end
				end
			end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_EVERY_ENTITY_INIT, params = nil,
Function = function(_,ent)
	if Game():GetRoom():GetFrameCount() == item.delayer[ent.Type] or -1 and not item.ignorers[ent.Type] then
		local ridx = auxi.get_acceptible_index()
		save.elses[item.own_key.."Kill"] = save.elses[item.own_key.."Kill"] or {}
		if save.elses[item.own_key.."Kill"][ridx] then ent:Remove() return end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local ridx = auxi.get_acceptible_index()
	save.elses[item.own_key.."Kill"] = save.elses[item.own_key.."Kill"] or {}
	local succ = save.elses[item.own_key.."Kill"][ridx]
	if succ then
		local room = Game():GetRoom()
		for i = 1,room:GetGridSize() do
			local grid = room:GetGridEntity(i)
			if grid and item.no_remove[grid:GetType()] ~= true then	room:RemoveGridEntity(i,0,false) end
		end
		room:Update()
	end
	save.elses[item.own_key.."Kill"][ridx] = nil
	if succ then
		local room = Game():GetRoom()
		if room:IsCurrentRoomLastBoss() or (room:GetType() == 5 and auxi.get_acceptible_level() == 9) then
			local info = item.level_info[auxi.get_acceptible_level()] 
			if info == "Both" then
				room:SpawnGridEntity(room:GetGridIndex(room:GetCenterPos()) - 1,GridEntityType.GRID_TRAPDOOR,0,1,0)
				local q = Isaac.Spawn(1000,39,0,room:GetCenterPos() + Vector(40,0),Vector(0,0),nil)
			elseif info == "Chest" then
				if Game().Challenge > 0 then
					local q = Isaac.Spawn(5,370,0,room:GetCenterPos(),Vector(0,0),nil)
				else
					local q = Isaac.Spawn(5,340,0,room:GetCenterPos(),Vector(0,0),nil)
				end
			elseif info == "Void" then
				room:SpawnGridEntity(room:GetGridIndex(room:GetCenterPos()),GridEntityType.GRID_TRAPDOOR,0,1,1)
			else
				room:SpawnGridEntity(room:GetGridIndex(room:GetCenterPos()),GridEntityType.GRID_TRAPDOOR,0,1,0)
			end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[item.own_key.."Kill"] = {}
	save.elses[item.own_key.."Kill2"] = {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,colid,rng,player,useFlags,activeSlot,customVarData)
	local ret = {Discharge = false}
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local level = Game():GetLevel()
		local room = Game():GetRoom()
		for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
			local door = room:GetDoor(slot)
			if door and (player.Position - door.Position):Length() < 60 then
				if auxi.check_all_exists(item.slots[slot]) then
					if player:GetPlayerType() == enums.Players.Anna then
						sound_tracker.PlayStackedSound(SoundEffect.SOUND_DEVIL_CARD,1,1,false,0,2)
						item.KillRoom2(player,door)
						ret = nil
					else
						if door:CanBlowOpen() then door:TryBlowOpen(false,nil) end
						door:TryUnlock(Game():GetPlayer(0),true)
						local ent = grid_entity.get_grid_entity(door)
						local succc = ent:GetData()[item.own_key.."Door_Open"]
						local door_params = {
							toget = function(e)
								local g2 = e and e.get_grid and e:get_grid()
								if not g2 then return false end
								local ok, open = pcall(function() return g2:IsOpen() end)
								return ok and open == true
							end,
							tochange = function(e, val)
								local g2 = e and e.get_grid and e:get_grid()
								if not g2 then return end
								local ok_door, door = pcall(function()
									return g2.ToDoor and g2:ToDoor()
								end)
								if not ok_door or not door then return end
								if val == true then
									pcall(function()
										if g2.Open then g2:Open() end
									end)
								else
									pcall(function()
										local s = g2:GetSprite()
										if s then s:Play("Close", true); s:SetLastFrame() end
										if g2.Close then g2:Close() end
									end)
								end
							end,
						}
						ent:GetData()[item.own_key.."Door_Open"] = Attribute_holder.try_hold_attribute(ent,"Door_Open",true,door_params)
						if succc then Attribute_holder.try_rewind_attribute(ent,"Door_Open",succc,door_params) end
						SFXManager():Stop(SoundEffect.SOUND_UNLOCK00)
						sound_tracker.PlayStackedSound(SoundEffect.SOUND_DEVIL_CARD,1,1,false,0,2)
						local q = Isaac.Spawn(1000,enums.Entities.Calamity_ball,0,player.Position,Vector(0,0),nil):ToEffect()
						local d = q:GetData()
						local desc = level:GetRoomByIdx(door.TargetRoomIndex)
						if desc then 
							desc.Clear = true
							local ridx = auxi.get_acceptible_index(desc.SafeGridIndex)
							save.elses[item.own_key.."Kill"][ridx] = true
							if save.elses[item.own_key.."Kill2"][ridx] ~= true then d[item.own_key.."Funct"] = function() item.Kill_room(slot) end end
							save.elses[item.own_key.."Kill2"][ridx] = true
							ret = true
						end
					end
					break
				end
			end
		end
	end
	return ret
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	if auxi.has_have_coll(player,item.entity) and auxi.get_coll_full_charge(player,item.entity) then
		local room = Game():GetRoom()
		local level = Game():GetLevel()
		for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
			local door = room:GetDoor(slot)
			if door and (player.Position - door.Position):Length() < 60 then
				if auxi.check_all_exists(item.slots[slot]) ~= true then
					local q = Isaac.Spawn(1000,enums.Entities.Calamity_door,0,door.Position,Vector(0,0),nil):ToEffect()
					q.DepthOffset = -100
					local s = q:GetSprite()
					local d = q:GetData()
					auxi.copy_sprite(door:GetSprite(),s)
					s.Color = Color(1,0,0,0)
					item.slots[slot] = q
					d[item.own_key.."target"] = slot
				elseif item.slots[slot]:GetData()[item.own_key.."Kill"] then
					item.slots[slot]:GetData()[item.own_key.."counter"] = nil
					item.slots[slot]:GetData()[item.own_key.."Kill"] = nil
				end
			end
		end
	end
	if d[item.own_key.."AnnaKiller"] then
		d[item.own_key.."AnnaKiller"].counter = (d[item.own_key.."AnnaKiller"].counter or 0) + 1
		player:AddControlsCooldown(math.max(0,3 - player.ControlsCooldown))
		player:SetMinDamageCooldown(math.max(0,3 - player:GetDamageCooldown()))
		if d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] == nil then d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] = Attribute_holder.try_hold_attribute(player,"ENTITY_FLAG_NO_DAMAGE_BLINK",true,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_DAMAGE_BLINK)) end
		if d[item.own_key.."EntityCollision"] == nil then d[item.own_key.."EntityCollision"] = Attribute_holder.try_hold_attribute(player,"EntityCollisionClass",EntityCollisionClass.ENTCOLL_NONE)	end
		if d[item.own_key.."AnnaKiller"].counter == item.moveoffset.mx - 1 then Screen_Filter.add_filter(10) end
		if d[item.own_key.."AnnaKiller"].counter > item.moveoffset.mx then 
			local desc = Game():GetLevel():GetRoomByIdx(d[item.own_key.."AnnaKiller"].sgid or -1)
			if desc then 
				Room_holder.Trans_to(desc.SafeGridIndex, -1, RoomTransitionAnim.FADE, player,-1,{On_Arrive = function() 	--d[item.own_key.."AnnaKiller"].dir
					for playerNum = 1, Game():GetNumPlayers() do
						local player = Game():GetPlayer(playerNum - 1)
						player.Position = Game():GetRoom():GetCenterPos()
						if player:GetData()[item.own_key.."AnnaKiller2"] then 
							player:GetData()[item.own_key.."AnnaKiller2"].Activate = true 
							local s = auxi.load_item(item.entity)
							player:AnimatePickup(s,true,"LiftItem")
						end
					end
				end,})
				d[item.own_key.."AnnaKiller2"] = {sel = auxi.choose(1,2,3,4,5,6),} 
			end
			d[item.own_key.."AnnaKiller"] = nil 
		end
	end
	if d[item.own_key.."AnnaKiller2"] and d[item.own_key.."AnnaKiller2"].Activate then
		player:AddControlsCooldown(math.max(0,3 - player.ControlsCooldown))
		player:SetMinDamageCooldown(math.max(0,3 - player:GetDamageCooldown()))
		d[item.own_key.."AnnaKiller2"].counter = (d[item.own_key.."AnnaKiller2"].counter or 0) + 1
		local tgpos = player.Position + player_offset_holder.GetPlayerOffset(player) + auxi.mul_t(player.SpriteScale,item.scaler)
		local rng = player:GetCollectibleRNG(item.entity)
		if d[item.own_key.."AnnaKiller2"].counter == 45 then 
			if d[item.own_key.."AnnaKiller2"].sel == 1 then
				d[item.own_key.."Brimstones"] = d[item.own_key.."Brimstones"] or {}
				local cnt = auxi.choose(12,16,20,24)
				for i = 1,cnt do 
					local q = Isaac.Spawn(7,1,0,player.Position,Vector(0,0),player):ToLaser()
					q.PositionOffset = player_offset_holder.GetPlayerOffset(player) + auxi.mul_t(player.SpriteScale,item.scaler)
					q.CollisionDamage = player.Damage
					table.insert(d[item.own_key.."Brimstones"],#d[item.own_key.."Brimstones"] + 1,{ent = q,id = i,})
				end
			end
			if d[item.own_key.."AnnaKiller2"].sel == 4 then
				d[item.own_key.."Brimstones"] = d[item.own_key.."Brimstones"] or {}
				local cnt = auxi.choose(6,8,10,12)
				for i = 1,cnt do 
					local q = Isaac.Spawn(7,5,0,player.Position,Vector(0,0),player):ToLaser()
					q.PositionOffset = player_offset_holder.GetPlayerOffset(player) + auxi.mul_t(player.SpriteScale,item.scaler)
					q.CollisionDamage = player.Damage
					table.insert(d[item.own_key.."Brimstones"],#d[item.own_key.."Brimstones"] + 1,{ent = q,id = i,})
				end
			end
		end
		local room = Game():GetRoom()
		if d[item.own_key.."AnnaKiller2"].counter == 45 then
			local tgs = auxi.getenemies()
			for u,v in pairs(tgs) do Attribute_holder.try_hold_and_rewind_attribute(v,"EntityFlag_FLAG_FEAR",true,30 * 30,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_FEAR)) end
		end
		if d[item.own_key.."AnnaKiller2"].counter >= 45 and d[item.own_key.."AnnaKiller2"].counter <= 30 * 14 + 15 then 
			if d[item.own_key.."AnnaKiller2"].sel == 2 then auxi.launch_Missile(room:GetRandomPosition(0),Vector(0,0),nil,{player = player,}) end
			if d[item.own_key.."AnnaKiller2"].sel == 4 then Isaac.Spawn(1000,19,0,room:GetRandomPosition(0),Vector(0,0),player) end
			if d[item.own_key.."AnnaKiller2"].sel == 1 then 
				local q = Isaac.Spawn(1000,19,0,room:GetRandomPosition(0),Vector(0,0),player) 
				local d2 = q:GetData()
				d2[item.own_key.."Brim"] = {}
				local s2 = q:GetSprite()
				s2:Load("gfx/mimics/Calamity/hushlaser.anm2",true)
				s2:Play("Spotlight",true)
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLOOD_LASER_LARGE,1,1,false,0,2)
			end
			if d[item.own_key.."AnnaKiller2"].sel == 6 and d[item.own_key.."AnnaKiller2"].counter % 5 == 1 then 
				local cnt = auxi.choose(3,4,5,6)
				for i = 1,cnt do 
					local q = Card_16r_Tower.fire_fake_rocks(player,tgpos,rng)
					q.DepthOffset = -(player_offset_holder.GetPlayerOffset(player) + auxi.mul_t(player.SpriteScale,item.scaler)).Y + 5
					q.Velocity = auxi.MakeVector(i/cnt*360 + d[item.own_key.."AnnaKiller2"].counter * 2.7) * 5
					q.TearFlags = q.TearFlags | BitSet128(0,1<<(83-64))
					q.GridCollisionClass = 0
				end
			end
			if d[item.own_key.."AnnaKiller2"].sel == 5 and d[item.own_key.."AnnaKiller2"].counter % 5 == 1 then 
				local cnt = auxi.choose(3,4,5,6)
				for i = 1,cnt do 
					auxi.fire_knife(tgpos,auxi.MakeVector(i/cnt*360 + d[item.own_key.."AnnaKiller2"].counter * 2.7),player.Damage * 10,nil,{player = player,cooldown = 60,Accerate = 1.5,}) 
				end
			end
			if d[item.own_key.."AnnaKiller2"].sel == 2 and d[item.own_key.."AnnaKiller2"].counter % 5 == 1 then 
				local cnt = auxi.choose(3,4,5,6)
				local pos = player.Position + player_offset_holder.GetPlayerOffset(player) + auxi.mul_t(player.SpriteScale,item.scaler)
				if room:IsPositionInRoom(pos,0) then
					for i = 1,cnt do 
						local q = auxi.fire_rocket(pos,auxi.MakeVector(i/cnt*360 + d[item.own_key.."AnnaKiller2"].counter * 2.7),player,{}) 
					end
				end
			end
		end
		--l local n_entity = Isaac.GetRoomEntities() for u,v in pairs(n_entity) do if v.Type == 4 then print(v:ToBomb().Flags) end end
		--l local auxi = require("Qing_Remaster_scripts.auxiliary.functions") local q = auxi.fire_rocket(Vector(200,200),Vector(1,0),Game():GetPlayer(0)) print(q.Flags)
		--l local room = Game():GetRoom() local size = room:GetGridSize() for i = 0,size - 1 do local gent = room:GetGridEntity(i) if gent and gent:GetType() == GridEntityType.GRID_WALL and room:IsPositionInRoom(room:GetGridPosition(i),0) == false then gent.CollisionClass = 0 end end
		if d[item.own_key.."AnnaKiller2"].counter >= 45 and d[item.own_key.."AnnaKiller2"].counter <= 30 * 14 then 
			if d[item.own_key.."AnnaKiller2"].sel == 3 then Isaac.Spawn(1000,29,0,room:GetRandomPosition(0),Vector(0,0),player) end
		end
		for i = #(d[item.own_key.."Brimstones"] or {}),1,-1 do 
			local v = d[item.own_key.."Brimstones"][i]
			if auxi.check_all_exists(v.ent) then
				local ang = (v.id * 360/(#d[item.own_key.."Brimstones"]) + d[item.own_key.."AnnaKiller2"].counter * 2)
				if auxi.get_correct_angle(ang) > 0 and auxi.get_correct_angle(ang) < 180 then v.ent.DepthOffset = 500 else v.ent.DepthOffset = -500 end
				local dir = auxi.MakeVector(ang) * 100 + Vector(0,30) -- player_offset_holder.GetPlayerOffset(player)
				v.ent.PositionOffset = player_offset_holder.GetPlayerOffset(player) + auxi.mul_t(player.SpriteScale,item.scaler)
				v.ent.Position = player.Position
				v.ent.Angle = dir:GetAngleDegrees()
			else table.remove(d[item.own_key.."Brimstones"],i) end
		end
		if d[item.own_key.."AnnaKiller2"].counter > item.bustoffset.mx then
			if d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] then Attribute_holder.try_rewind_attribute(player,"ENTITY_FLAG_NO_DAMAGE_BLINK",d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"],Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_DAMAGE_BLINK)) d[item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"] = nil end
			if d[item.own_key.."EntityCollision"] then Attribute_holder.try_rewind_attribute(player,"EntityCollisionClass",d[item.own_key.."EntityCollision"]) d[item.own_key.."EntityCollision"] = nil end
			d[item.own_key.."AnnaKiller2"] = nil
			local s = auxi.load_item(item.entity)
			player:AnimatePickup(s,true,"HideItem")
			for u,v in pairs(d[item.own_key.."Brimstones"] or {}) do v.ent:SetTimeout(1) end
			d[item.own_key.."Brimstones"] = nil
			Game():GetRoom():MamaMegaExplosion(player.Position)
			delay_buffer.addeffe(function() 
				local tgs = auxi.getenemies()
				for u,v in pairs(tgs) do auxi.safely_kill(v) end
			end,{},3)
		player:SetMinDamageCooldown(math.max(0,30 - player:GetDamageCooldown()))
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.Calamity_door,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	d[item.own_key.."counter"] = (d[item.own_key.."counter"] or 0) + 1
	local cnt = math.min(1,d[item.own_key.."counter"]/30)
	local room = Game():GetRoom()
	local door = room:GetDoor(d[item.own_key.."target"] or -1)
	if door then auxi.copy_sprite(door:GetSprite(),s,{SetColor = true,}) end
	if d[item.own_key.."Kill"] then
		ent.Color = auxi.AddColor(ent.Color,ent.Color,0.97,0)
		if ent.Color.A < 0.05 then ent:Remove() return end
	else
		ent.Color = auxi.AddColor(ent.Color,Color(1,0,0,0.4 + math.sin(d[item.own_key.."counter"] * 5/180 * 3.14) * 0.2,1,0,0),(1 - cnt),cnt)
		local should_kill = true
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			if auxi.has_have_coll(player,item.entity) and auxi.get_coll_full_charge(player,item.entity) and (player.Position - ent.Position):Length() < 60 then should_kill = false break end
		end
		if should_kill then d[item.own_key.."Kill"] = true d[item.own_key.."counter"] = 0 end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.Calamity_ball,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if s:IsFinished("Idle") then s:Play("Rotate",true) end
	if s:IsFinished("Rotate") then s:Play("Fly",true) end
	if s:IsPlaying("Fly") or s:IsPlaying("Rotate") then 
		d[item.own_key.."Vel"] = math.min(20,(d[item.own_key.."Vel"] or 0) + 1)
		s.Offset = s.Offset + Vector(0,-d[item.own_key.."Vel"]) 
		if s.Offset.Y < -400 then 
			auxi.check_if_any(d[item.own_key.."Funct"])
			ent:Remove() 
			return 
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = 19,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	local player = auxi.check_spawner_player(ent)
	if player and d[item.own_key.."Brim"] and ent.FrameCount >= 4 and ent.FrameCount % 3 == 1 then
		d[item.own_key.."Brim"] = nil
		local n_entity = Isaac.GetRoomEntities()
		for u,v in pairs(n_entity) do
			if (v.Position - ent.Position):Length() <= 30 + v.Size then
				v:TakeDamage(ent.CollisionDamage,0,EntityRef(player),0)
			end
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = item.entity,
Function = function(_,player,colid,cnt,touched)
	if player:GetPlayerType() == enums.Players.Anna then
		player:FlushQueueItem()
		player:RemoveCollectible(colid)
		player:SetPocketActiveItem(colid,2,false)
		if not touched then player:AddCollectible(colid,2,true,2) end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_INIT, params = nil,
Function = function(_,ent)
	if ent.SpawnerEntity and ent.SpawnerEntity.Type == 3 and ent.SpawnerEntity.Variant == FamiliarVariant.WISP and ent.SpawnerEntity.SubType == item.entity then
		local d = ent:GetData()
		d[item.own_key.."Burst"] = {}
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."Burst"] and ent:IsDead() then
		d[item.own_key.."Burst"] = nil
		local player = auxi.check_spawner_player(ent) or Game():GetPlayer(0)
		local q = Isaac.Spawn(1000,19,0,ent.Position,Vector(0,0),player) 
		local d2 = q:GetData()
		d2[item.own_key.."Brim"] = {}
		local s2 = q:GetSprite()
		s2:Load("gfx/mimics/Calamity/hushlaser.anm2",true)
		s2:Play("Spotlight",true)
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLOOD_LASER_LARGE,1,1,false,0,2)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION, params = nil,
Function = function(_,ent,col,low)
	local d = ent:GetData()
	if d[item.own_key.."Burst"] then
		d[item.own_key.."Burst"] = nil
		local player = auxi.check_spawner_player(ent) or Game():GetPlayer(0)
		local q = Isaac.Spawn(1000,19,0,ent.Position,Vector(0,0),player) 
		local d2 = q:GetData()
		d2[item.own_key.."Brim"] = {}
		local s2 = q:GetSprite()
		s2:Load("gfx/mimics/Calamity/hushlaser.anm2",true)
		s2:Play("Spotlight",true)
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLOOD_LASER_LARGE,1,1,false,0,2)
	end
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
			d[item.own_key.."counter"] = 15 * 30
			local q = Isaac.Spawn(1000,19,0,ent.Position,Vector(0,0),player) 
			local d2 = q:GetData()
			d2[item.own_key.."Brim"] = {}
			local s2 = q:GetSprite()
			s2:Load("gfx/mimics/Calamity/hushlaser.anm2",true)
			s2:Play("Spotlight",true)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLOOD_LASER_LARGE,1,1,false,0,2)
		end
	end
end,
})

return item