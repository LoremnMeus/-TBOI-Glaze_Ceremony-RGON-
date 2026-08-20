local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local ModConfig = require("Qing_Remaster_scripts.others.Mod_Config_Menu_holder")

local item = {
	entity = enums.Cards.Anna_s_Soul,
	own_key = "sins_Anna_s_Soul_",
	ToCall = {},
	frame_info = {
		{frame = -90,offset = Vector(0,-600),},
		{frame = -45,offset = Vector(0,-600),},
		{frame = -30,offset = Vector(0,0),},
		{frame = 0,offset = Vector(0,0),},
	},
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,card,player,useflags)	
	Game():BombExplosionEffects(player.Position,50,BitSet128(0,0),Color(1,0,0,1,0.75,0,0),player,2,false,false)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = 300,
Function = function(_,ent)
	if ent.SubType == item.entity then
		local d = ent:GetData()
		local s = ent:GetSprite()
		local anim = s:GetAnimation()
		d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}
		d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) + 1
		if d[item.own_key.."effect"].counter <= 0 then
			local tg = d[item.own_key.."effect"].target
			if d[item.own_key.."effect"].counter <= -60 then 
				if auxi.check_all_exists(tg) then ent.Velocity = (tg.Position - ent.Position) * 0.5
				else d[item.own_key.."effect"].target = auxi.get_nearest_enemy(nil,ent.Position) end
				d[item.own_key.."effect"].Position = auxi.ProtectVector(ent.Position)
			else 
				if d[item.own_key.."effect"].counter <= -30 then
					ent.Position = d[item.own_key.."effect"].Position 
					ent.Velocity = Vector(0,0) 
				end
			end
			if d[item.own_key.."effect"].counter == -60 then
				local q = Isaac.Spawn(1000,19,2,ent.Position,Vector(0,0),nil)
				q.Parent = Game():GetPlayer(0)
				q.CollisionDamage = 15
				local s = q:GetSprite()
				s.Color = Color(1,0,0,1,0,0,0)
				Game():MakeShockwave(ent.Position,0.035,0.025,10) 
			end
			if d[item.own_key.."effect"].counter == -30 then
				Game():BombExplosionEffects(ent.Position,50,BitSet128(0,0),Color(1,0,0,1,0.75,0,0),ent,2,false,false)
				s:Play("Appear",true)
				ent.Velocity = auxi.RoundVector(ent:GetDropRNG(),5)
				ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_GROUND
			end
			local posinfo = auxi.check_lerp(d[item.own_key.."effect"].counter,item.frame_info)
			ent.PositionOffset = posinfo.offset
			if d[item.own_key.."effect"].counter <= -30 then s.FlipY = true else s.FlipY = false end
			if d[item.own_key.."effect"].counter == 0 then 
				ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_PLAYERONLY 
			end
		end
		if d[item.own_key.."effect"].counter == 60 and anim == "Idle" then
			local q = Isaac.Spawn(1000,enums.Entities.Rift_Beggar_Helper,0,ent.Position,Vector(0,0),nil):ToEffect()
			q.Parent = ent
			s:Play("Fall",true)
			d[item.own_key.."effect"].linker = q
			q:GetSprite().Offset = Vector(0,5)
		end
		if s:IsFinished("Fall") then
			if auxi.check_all_exists(d[item.own_key.."effect"].linker) then d[item.own_key.."effect"].linker.Parent = nil end
			d[item.own_key.."effect"].counter = -90
			s:Play("Idle",true)
			ent.PositionOffset = Vector(0,-600)
			d[item.own_key.."effect"].target = auxi.get_nearest_enemy(nil,ent.Position)
			ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
			ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
		end
	end
end,
})


return item