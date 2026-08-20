local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local dropping_holder = require("Qing_Remaster_scripts.others.Dropping_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")
local Item_Lofty = require("Qing_Remaster_scripts.items.Item_Lofty")
local Nil_holder = require("Qing_Remaster_scripts.others.Nil_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Chariot_r,
	own_key = "Thoth_cd7r_Cha_",
	infos = {
		[1] = {
			loadname = "gfx/effects/traps/Magic_Cylinder.png",
			cnt = 10,
			work = function(ent,info)
				local pos = ent.Position
				local n_proj = auxi.getothers(Isaac.GetRoomEntities(),9)
				local cnt = 0
				for u,v in pairs(n_proj) do
					if v.FrameCount > 10 then
						cnt = cnt + 1
						v = v:ToProjectile()
						local q = Isaac.Spawn(2,0,0,v.Position,-v.Velocity,nil):ToTear()
						q.Height = v.Height
						q.FallingSpeed = v.FallingSpeed
						q.FallingAcceleration = v.FallingAccel
						auxi.copy_sprite(v:GetSprite(),q:GetSprite())
						v:Remove()
					end
				end
				if cnt > 0 then return 1 end
			end,
			sound = {id = SoundEffect.SOUND_DOGMA_FEATHER_SPRAY, pit = 1.3,val = 1,},
		},
		[2] = {
			loadname = "gfx/effects/traps/Mirror_Force.png",
			cnt = 1,
			work = function(ent,info)
				local pos = ent.Position
				local n_enemy = auxi.getenemies(Isaac.GetRoomEntities())
				for u,v in pairs(n_enemy) do
					if (v.Position - pos):Length() < 40 then
						local q = Item_Lofty.start_lofty(Game():GetPlayer(0),1,100)
						q.Parent = auxi.fire_nil(ent.Position,Vector(0,0),{cooldown = 60,})
						return 1
					end
				end
			end,
			sound = {id = SoundEffect.SOUND_SUPERHOLY, val = 0,},
		},
		[3] = {
			loadname = "gfx/effects/traps/Skill_Drain.png",
			cnt = 3,
			work = function(ent,info)
				local pos = ent.Position
				local n_enemy = auxi.getenemies(Isaac.GetRoomEntities())
				local cnt = 0
				for u,v in pairs(n_enemy) do
					if (v.Position - pos):Length() < 40 and not v:HasEntityFlags(EntityFlag.FLAG_FREEZE) then
						local ti = 10 * 30
						if v:IsBoss() then ti = 3 * 30 end
						Attribute_holder.try_hold_and_rewind_attribute(v,"Color",Color(0.1,0.1,0.1,1),ti,Attribute_holder.descriptors.color())
						Attribute_holder.try_hold_and_rewind_attribute(v,"EntityFlag_FLAG_FREEZE",true,ti,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_FREEZE))
						cnt = cnt + 1
					end
				end
				if cnt > 0 then return 1 end
			end,
			sound = {id = SoundEffect.SOUND_BOSS2INTRO_PIPES_TURNON, val = 1,pit = 3.5,},
		},
		[4] = {
			loadname = "gfx/effects/traps/Universe.png",
			cnt = 5,
			work = function(ent,info,item)
				local pos = ent.Position
				local n_enemy = auxi.getenemies(Isaac.GetRoomEntities())
				local cnt = 0
				for u,v in pairs(n_enemy) do
					local d = v:GetData()
					if (v.Position - pos):Length() < 40 and d[item.own_key.."teleport"] == nil then
						d[item.own_key.."teleport"] = true
						v.HitPoints = math.max(0,v.HitPoints - v.MaxHitPoints * 0.5)
						cnt = cnt + 1
						item.teleport_cnt = item.teleport_cnt + 1
					end
				end
				if cnt > 0 then return 1 end
			end,
			sound = {id = SoundEffect.SOUND_DOGMA_BLACKHOLE_OPEN, val = 1.5,pit = 1.5,},
		},
		[5] = {
			loadname = "gfx/effects/traps/Void_Space.png",
			cnt = 2,
			work = function(ent,info)
				local pos = ent.Position
				local n_enemy = auxi.getenemies(Isaac.GetRoomEntities())
				local cnt = 0
				for u,v in pairs(n_enemy) do
					if v.FrameCount == 0 then
						if v:IsBoss() then v.HitPoints = v.HitPoints * 0.8
						else v.HitPoints = 1 end
						local e = Isaac.Spawn(1000,16,3,v.Position,Vector(0,0),nil)
						cnt = cnt + 1
					end
				end
				if cnt > 0 then return 1 end
			end,
			sound = {id = SoundEffect.SOUND_DOGMA_RING_START, val = 1.5,pit = 1.5},
		},
	},
	teleport_buff = {
		[1] = {scale = Vector(0.9,1,1),color = Color(0,0,0,1),offset = Vector(0,0)},
		[2] = {scale = Vector(0.9,1,1),color = Color(1,1,1,1,1,1,1),offset = Vector(0,0)},
		[3] = {scale = Vector(1.4,0.6),color = Color(0,0,0,1),offset = Vector(0,-32)},
		[4] = {scale = Vector(1.4,0.6),color = Color(1,1,1,1,1,1,1),offset = Vector(0,-32)},
		[5] = {scale = Vector(1.8,0.5),color = Color(0,0,0,1),offset = Vector(0,-32)},
		[6] = {scale = Vector(0.5,2.2),color = Color(1,1,1,1,1,1,1),offset = Vector(0,18)},
		[7] = {scale = Vector(0.3,3),color = Color(0,0,0,1),offset = Vector(0,18)},
		[8] = {scale = Vector(0.1,8),color = Color(1,1,1,1,1,1,1),offset = Vector(0,22)},
		[9] = {scale = Vector(0,0),color = Color(1,1,1,1,1,1,1),offset = Vector(0,-70),teleport = true,},
		[10] = {scale = Vector(0,0),color = Color(1,1,1,1,1,1,1),offset = Vector(0,-70),},
		[11] = {scale = Vector(0,0),color = Color(1,1,1,1,1,1,1),offset = Vector(0,-70),},
		[12] = {scale = Vector(0,0),color = Color(1,1,1,1,1,1,1),offset = Vector(0,-70),},
		[13] = {scale = Vector(0,0),color = Color(1,1,1,1,1,1,1),offset = Vector(0,-70),},
		[14] = {scale = Vector(0,0),color = Color(1,1,1,1,1,1,1),offset = Vector(0,-70),},
		[15] = {scale = Vector(0,0),color = Color(1,1,1,1,1,1,1),offset = Vector(0,-70),},
		[16] = {scale = Vector(0,0),color = Color(1,1,1,1,1,1,1),offset = Vector(0,-70),},
		[17] = {scale = Vector(0,0),color = Color(1,1,1,1,1,1,1),offset = Vector(0,-70),},
		
		[17] = {scale = Vector(0.9,1,1),color = Color(0,0,0,1),offset = Vector(0,0)},
		[19] = {scale = Vector(0.9,1,1),color = Color(1,1,1,1,1,1,1),offset = Vector(0,0)},
		[20] = {scale = Vector(1.4,0.6),color = Color(0,0,0,1),offset = Vector(0,-32)},
		[21] = {scale = Vector(1.4,0.6),color = Color(1,1,1,1,1,1,1),offset = Vector(0,-32)},
		[22] = {scale = Vector(1.8,0.5),color = Color(0,0,0,1),offset = Vector(0,-32)},
		[23] = {scale = Vector(0.5,2.2),color = Color(1,1,1,1,1,1,1),offset = Vector(0,18)},
		[24] = {scale = Vector(0.3,3),color = Color(0,0,0,1),offset = Vector(0,18)},
		[25] = {scale = Vector(0.1,8),color = Color(1,1,1,1,1,1,1),offset = Vector(0,22)},
	},
	teleport_cnt = 0,
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if item.teleport_cnt > 0 then
		item.teleport_cnt = 0
		local room = Game():GetRoom()
		local n_enemy = auxi.getenemies(Isaac.GetRoomEntities())
		for u,ent in pairs(n_enemy) do
			local d = ent:GetData()
			for i = 1,1 do if d[item.own_key.."teleport"] then
				--d[item.own_key.."EntityCollisionClass"] = d[item.own_key.."EntityCollisionClass"] or Attribute_holder.try_hold_attribute(ent,"EntityCollisionClass",EntityCollisionClass.ENTCOLL_NONE)
				d[item.own_key.."counter"] = (d[item.own_key.."counter"] or 0) + 1
				local info = item.teleport_buff[d[item.own_key.."counter"]]
				if info == nil then 
					d[item.own_key.."teleport"] = nil 
					d[item.own_key.."counter"] = nil 
					ent:GetSprite().Color = Color(1,1,1,1) 
					--if d[item.own_key.."EntityCollisionClass"] then Attribute_holder.try_rewind_attribute(ent,"EntityCollisionClass",d[item.own_key.."EntityCollisionClass"]) d[item.own_key.."EntityCollisionClass"] = nil end
					break 
				end
				ent.SpriteOffset = info.offset
				ent.SpriteScale = auxi.mul_t(ent.SpriteScale,info.scale)
				ent:GetSprite().Color = auxi.AddColor(ent:GetSprite().Color,info.color,info.c1 or 0,info.c2 or 1)
				if info.teleport then
					local pos = room:GetRandomPosition(0)
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_HELL_PORTAL2,1,1,false,0,2)
					if ent.GridCollisionClass ~= EntityGridCollisionClass.GRIDCOLL_NONE then pos = room:FindFreeTilePosition(pos,10) end
					ent.Position = pos
				end
				item.teleport_cnt = item.teleport_cnt + 1
			end end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local tbl = {}
		for i = 1,5 do
			local info = item.infos[i]
			local pos = room:FindFreePickupSpawnPosition(player.Position,10,true)
			local q = auxi.fire_nil(pos,Vector(0,0),{cooldown = 9999999,})
			q.DepthOffset = -100
			local d2 = q:GetData()
			local s = q:GetSprite()
			s:Load("gfx/cards/cd07r_cha_trapcard.anm2",true)
			s:ReplaceSpritesheet(0,info.loadname)
			s:LoadGraphics()
			s.Scale = Vector(0.5,0.5)
			s:Play("Appear",true)
			d2.nil_mode = "card_07r_chariot"
			d2[item.own_key.."effect"] = info
			d2[item.own_key.."cnt"] = info.cnt
			if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then d2[item.own_key.."cnt"] = d2[item.own_key.."cnt"] * 2 end
			local bombinfo = enums.Pickups.Glaze_bomb
			local q3 = Isaac.Spawn(5,bombinfo.Variant,bombinfo.SubType,pos,Vector(0,0),nil)
			table.insert(tbl,#tbl + 1,q3)
		end
		for u,v in pairs(tbl) do v:Remove() end
	end
end,
})

Nil_holder.register("card_07r_chariot", {
	detect = function(d) return d[item.own_key.."effect"] end,
	update = function(ent, d, s)
		local info = d[item.own_key.."effect"]
		if (s:IsFinished("Appear") or s:IsFinished("Idle") or s:IsPlaying("Idle")) and (d[item.own_key.."cnt"] or 0) > 0 then
			local succ = info.work(ent,info,item)
			if succ then
				if s:IsFinished("Appear") then s:Play("ToIdle",true)
				else s:Play("IdletoIdle",true) end
				d[item.own_key.."cnt"] = d[item.own_key.."cnt"] - succ
			end
		end
		if s:IsFinished("ToIdle") or s:IsFinished("IdletoIdle") then
			if (d[item.own_key.."cnt"] or 0) > 0 then s:Play("Idle",true)
			else s:Play("Disappear",true) end
		end
		if s:IsFinished("Disappear") then ent:Remove() return end
		if s:IsEventTriggered("Sound") then
			local soundinfo = info.sound or {}
			sound_tracker.PlayStackedSound(soundinfo.id or SoundEffect.SOUND_SUPERHOLY, soundinfo.val or 1,soundinfo.pit or 1, false, 0,2)
		end
	end,
})

return item