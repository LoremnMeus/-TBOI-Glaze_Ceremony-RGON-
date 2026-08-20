local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local AI = require("Qing_Remaster_scripts.bosses.Boss_All")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")

local item = {
	ToCall = {},
	entity = enums.Enemies.Autio,
	own_key = "Boss_Autio_",
	Swapper = {
		["Appear"] = "Idle",
		["BossAppear"] = "Idle",
	},
	Animinfo = {
		[1] = {
			{frame = 0,scale = Vector(1,-1),RO = -1,GO = -1,BO = -1,},
			--{frame = 2,scale = Vector(1,0),RO = -1,GO = -1,BO = -1,},
			--{frame = 7,scale = Vector(1,0),RO = 0,GO = 0,BO = 0,},
			{frame = 15,scale = Vector(1,-1),RO = -1,GO = -1,BO = -1,},
			{frame = 20,scale = Vector(1,1),RO = 0,GO = 0,BO = 0,},
		},
	},
	Posinfo = {
		[1] = 37,
		[2] = 63,
		[3] = 71,
	},
}
--l local n_entity = Isaac.GetRoomEntities() for u,v in pairs(n_entity) do if v.Type == 996 then print(v:GetSprite():GetAnimation()) end end
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = 996,
Function = function(_,ent)
	if ent.Variant == item.entity then
		local s = ent:GetSprite()
		local d = ent:GetData()
		local anim = s:GetAnimation()
		local frame = s:GetFrame()
		
		if d[item.own_key.."Eater"] then
			ent.Position = d[item.own_key.."Eater"].Position
			ent.Velocity = d[item.own_key.."Eater"].Velocity
			ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
			s.Color = auxi.AddColor(s.Color,Color(0,0,0,1),1,1/60)
			if s.Color.A >= 1 then
				s.Color = Color(1,1,1,1,-1,-1,-1)
				d[item.own_key.."Eater"]:GetData()[item.own_key.."Eaten"] = d[item.own_key.."Eater"]:GetData()[item.own_key.."Eaten"] or {}
				if (d[item.own_key.."Eater"]:GetData()[item.own_key.."Eaten"] or {}).Ready then
					d[item.own_key.."Eater"]:GetData()[item.own_key.."Eaten"] = nil
					d[item.own_key.."Scale"] = Vector(1,-1)
					s:Play("BossAppear",true)
					d[item.own_key.."Eater"] = nil
				end
			else
				d[item.own_key.."Scale"] = d[item.own_key.."Scale"] + Vector(0,1/60)
			end
		end
		if anim == "BossAppear" then
			local info = auxi.check_lerp(frame,item.Animinfo[1])
			d[item.own_key.."Scale"] = info.scale
			s.Color = auxi.table2color(info)
			if frame == 3 then AI.move2pos(ent,auxi.gidx2pos(item.Posinfo[1]),17-3) end
		end
		
		AI.Control_Move(ent)
		ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_WALLS
		if anim == "Idle" then ent:Kill() end
		if s:IsFinished(anim) then
			local tg = auxi.check_if_any(item.Swapper[anim],ent) or "Idle"
			s:Play(tg,true)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_INIT, params = 996,
Function = function(_,ent)
	if ent.Variant == item.entity then
		local s = ent:GetSprite()
		local d = ent:GetData()
		AI.basic(ent,{Friction = 0.5,})
		d[item.own_key.."Scale"] = d[item.own_key.."Scale"] or Attribute_holder.try_hold_attribute(ent,"SpriteScale",function(ent) return ent:GetData()[item.own_key.."Scale"] or ent.SpriteScale end,{protect = true,})
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			if true	then --player:GetData()[item.own_key.."Shadow"] then 
				ent:GetData()[item.own_key.."Eater"] = player
				ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
				ent:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
				s:Play("BossIdle",true)
				s.Color = Color(1,1,1,0)
				d[item.own_key.."Scale"] = Vector(1,0)
				break
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	if d[item.own_key.."Eaten"] then
		local s = player:GetSprite()
		local anim = s:GetAnimation()
		local fr = s:GetFrame()
		player:AddControlsCooldown(math.max(0,3 - player.ControlsCooldown))
		local cnt = d[item.own_key.."Eaten"].cnt or 0
		if cnt >= 60 * 3 then 
			d[item.own_key.."Eaten"].Ready = true 
		else
			if (anim == "Sad" and fr >= 19) or d[item.own_key.."Eaten"].eat then 
				player:PlayExtraAnimation("Sad") 
				d[item.own_key.."Eaten"].eat = true
				s:SetLastFrame()
				s:SetFrame("Sad",fr % 2 + 19) 
			else
				if player:IsExtraAnimationFinished() then 
					player:PlayExtraAnimation("Sad") 
				end
			end
		end
		--l local player = Game():GetPlayer(0) player:PlayExtraAnimation("Sad") local s = player:GetSprite() s:SetFrame("Sad",fr % 2 + 13)
		d[item.own_key.."Eaten"].cnt = cnt + 1
	end
end,
})

return item