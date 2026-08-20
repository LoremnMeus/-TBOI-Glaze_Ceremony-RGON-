local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local grid_wall = require("Qing_Remaster_scripts.grids.grid_wall")
local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder")
local Nil_holder = require("Qing_Remaster_scripts.others.Nil_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	pre_myToCall = {},
	myToCall = {},
	entity = enums.Cards.Devil_r,
	own_key = "Thoth_cd15r_Dev_",
	own_key2 = "Thoth_cd15r_Dev2_",
	buff_info = {
		[1] = {
			work = function(pos,ent,info,item)
				local q = Isaac.Spawn(5,0,1,pos,Vector(0,0),nil):ToPickup()
				q.Price = -5
				local d = q:GetData()
				price_holder.catch_price_over(q)
				consistance_holder.try_hold_over_entity(q,item.own_key2)
				d._Data[item.own_key2][item.own_key.."record"] = q.SubType
				consistance_holder.try_hold_entity(q,item.own_key)
				consistance_holder.try_hold_entity(q,item.own_key2,{ignore_subtype = true,})
				return q
			end,
			weigh = 10,
		},
		[2] = {
			work = function(pos,ent,info,item)
				local q = Isaac.Spawn(5,100,0,pos,Vector(0,0),nil):ToPickup()
				q.Price = -1
				local d = q:GetData()
				price_holder.catch_price_over(q)
				consistance_holder.try_hold_over_entity(q,item.own_key2)
				d._Data[item.own_key2][item.own_key.."record"] = q.SubType
				consistance_holder.try_hold_entity(q,item.own_key)
				consistance_holder.try_hold_entity(q,item.own_key2,{ignore_subtype = true,})
				return q
			end,
			weigh = 10,
		},
		[3] = {
			work = function(pos,ent,info,item)
				local rng = ent:GetDropRNG()
				local colid = Game():GetItemPool():GetCollectible(3,true,rng:GetSeed())
				local q = Isaac.Spawn(5,100,colid,pos,Vector(0,0),nil):ToPickup()
				q.Price = -1
				local d = q:GetData()
				price_holder.catch_price_over(q)
				consistance_holder.try_hold_over_entity(q,item.own_key2)
				d._Data[item.own_key2][item.own_key.."record"] = q.SubType
				consistance_holder.try_hold_entity(q,item.own_key)
				consistance_holder.try_hold_entity(q,item.own_key2,{ignore_subtype = true,})
				return q
			end,
			weigh = 10,
		},
	},
}

table.insert(item.pre_myToCall,#item.pre_myToCall + 1,{CallBack = enums.Callbacks.PRE_CHECK_PRICE, params = nil,
Function = function(_,ent,val)
	local d = ent:GetData()
	local succ = consistance_holder.try_check_entity(ent,item.own_key2)
	if succ then	--and d._Data[item.own_key2][item.own_key.."record"]
		return auxi.get_acceptible_devil_price(ent)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	local succ = consistance_holder.try_check_entity(ent,item.own_key2)
	if succ and d._Data[item.own_key2][item.own_key.."record"] and ent.Touched == true then		--d._Data[item.own_key2][item.own_key.."record"] ~= ent.SubType
		consistance_holder.try_remove_entity(ent,item.own_key,{record_subtype = d._Data[item.own_key2][item.own_key.."record"],})
		consistance_holder.try_remove_entity(ent,item.own_key2)
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	local succ = consistance_holder.try_check_entity(ent,item.own_key)
	-- FrameCount==0 在小退也会发生；仅非首次进房时清交易残留
	if succ and Game():GetRoom():GetFrameCount() == 0 and not Game():GetRoom():IsFirstVisit() then
		consistance_holder.try_remove_entity(ent,item.own_key2)
		consistance_holder.try_remove_entity(ent,item.own_key)
		ent:Remove()
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local d = player:GetData()
	local idx = d.__Index
	if idx ~= nil then
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	local room = Game():GetRoom()
	if d[item.own_key.."effect"] then
		if s:IsPlaying("SmallIdle") and s:IsEventTriggered("Drop") then
			local q = auxi.fire_nil(ent.Position + Vector(0,-100),Vector(0,0),{cooldown = 9999999,})
			q.PositionOffset = Vector(0,100)
			--q:AddEntityFlags(EntityFlag.FLAG_RENDER_FLOOR | EntityFlag.FLAG_NO_REMOVE_ON_TEX_RENDER)
			local s = q:GetSprite()
			s:Load("gfx/cards/cd15r_devil_pentagram.anm2",true)
			s:Play("Appear",true)
			local d2 = q:GetData()
			d2.nil_mode = "card_15r_devil"
			d2[item.own_key.."effect"] = true
			
			local cnt = 2 + math.random(2)
			if d[item.own_key.."effect2"] then cnt = cnt + math.random(2) end
			local spawn_pos = ent.Position + Vector(0,40) + Vector(- cnt * 0.5 * 40,0)
			unique_holder.try_spawn_shop_item()
			local rng = ent:GetDropRNG()
			d[item.own_key.."table"] = {}
			for i = 1,cnt do
				local pos = spawn_pos + Vector(40,0) * (i - 0.5)
				local tbl = auxi.deepCopy(item.buff_info)
				local ret = auxi.random_in_weighed_table(tbl,rng)
				local q = ret.work(pos,ent,ret,item)
				table.insert(d[item.own_key.."table"],#d[item.own_key.."table"] + 1,{ent = q,})
			end
			d[item.own_key.."pentagram"] = q
		end
		if d[item.own_key.."table"] then
			for i = #d[item.own_key.."table"],1,-1 do
				local v = d[item.own_key.."table"][i]
				if v.ent:Exists() == false or consistance_holder.try_check_entity(v.ent,item.own_key2) ~= true then 
					s:Play("SmallHappy")
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_SATAN_GROW,1,1,false,0,2)
					table.remove(d[item.own_key.."table"],i)
				end
			end
			if #d[item.own_key.."table"] == 0 then
				d[item.own_key.."table"] = nil
				s:Play("SmallLeave",true) 
			end
		end
		if s:IsFinished("SmallLeave") then ent:Remove() return end
		if s:IsFinished("SmallIdle") then s:Play("Idle",true) end
		if s:IsFinished("SmallHappy") then s:Play("Idle",true) end
		if s:IsFinished("Idle") or s:IsPlaying("Idle") or s:IsPlaying("SmallHappy") then 
			local succ = auxi.check_explosion(ent)
			if succ then
				MusicManager():Play(Music.MUSIC_SATAN_BOSS,Options.MusicVolume)
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_SATAN_GROW,1,1,false,0,2)
				if d[item.own_key.."pentagram"] and d[item.own_key.."pentagram"]:Exists() then
					d[item.own_key.."pentagram"]:GetSprite():Play("DisAppear",true)
				end
				local q = Isaac.Spawn(84,0,0,ent.Position + Vector(0,-80),Vector(0,0),nil):ToNPC() 
				local d2 = q:GetData()
				for i = 1,300 do q:Update() end 
				for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
					local door = room:GetDoor(slot)
					if (door) then
						door:Close()
					end
				end
				d2[item.own_key.."table"] = {}
				for u,v in pairs(d[item.own_key.."table"] or {}) do
					local q2 = v.ent:ToPickup()
					if q2 and q2:Exists() then
						consistance_holder.try_remove_entity(q2,item.own_key2)
						consistance_holder.try_remove_entity(q2,item.own_key)
						table.insert(d2[item.own_key.."table"],#d2[item.own_key.."table"] + 1,{vr = q2.Variant,st = q2.SubType,})
						q2:Remove()
					end
				end
				ent:Remove() 
				return
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = 84,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	local room = Game():GetRoom()
	if s:GetAnimation() == "Death" and s:GetFrame() == 29 then
		if d[item.own_key.."table"] then 
			for u,v in pairs(d[item.own_key.."table"]) do
				local q = Isaac.Spawn(5,v.vr,v.st,room:FindFreePickupSpawnPosition(ent.Position,10,true),Vector(0,0),nil):ToPickup()
				q:Morph(5,v.vr,v.st,true,true,true)
				q:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
			end
			d[item.own_key.."table"] = nil
		end
	end
end,
})
--l local n_entity = Isaac.GetRoomEntities() for u,v in pairs(n_entity) do if v.Type == 84 then print(v:ToNPC().State) end end
--local q = Isaac.Spawn(84,0,0,Vector(200,200),Vector(0,0),nil):ToNPC() for i = 1,300 do q:Update() end 

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	local rng = player:GetCardRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_SATAN_APPEAR,1,1,false,0,2)
		--l SFXManager():Play(320, 1, 1, false, 1, 0)
		grid_wall.ChangeRoomGfx({Backdrops = BackdropType.SHEOL,})
		local q = Isaac.Spawn(1000,6,0,room:FindFreeTilePosition(player.Position + Vector(0,-80),10),Vector(0,0),nil):ToEffect()
		local s = q:GetSprite()
		s:Load("gfx/cards/cd15r_devil_satan.anm2",true)
		s:Play("SmallIdle",true)
		local d = q:GetData()
		d[item.own_key.."effect"] = true
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then d[item.own_key.."effect2"] = true end
	end
end,
})

Nil_holder.register("card_15r_devil", {
	detect = function(d) return d[item.own_key.."effect"] end,
	update = function(ent, d, s)
		if s:IsFinished("Appear") then
			s:Play("Idle",true)
		end
		if s:IsFinished("DisAppear") then ent:Remove() return end
	end,
})

return item