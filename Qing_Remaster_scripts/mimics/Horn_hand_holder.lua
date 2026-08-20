local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Horn_hand_holder_",
	entity = enums.Entities.HornHandHelper,
	hand_info = {
		[6] = {pos = Vector(-20,25),},
		[12] = {pos = Vector(20,25),},
		[18] = {pos = Vector(-20,25),},
	},
}

function item.fire_horn_hand(ent,col,params)
	params = params or {}
	local player = params.player or Game():GetPlayer(0)
	ent = ent or player
	col = col or auxi.get_nearest_enemy(nil,ent.Position)
	local pos = params.pos or (col and col.Position) or ent.Position
	if auxi.check_all_exists(col) and not col:IsBoss() then
		local d = col:GetData()
		if not d[item.own_key.."Horn"] then
			local q = Isaac.Spawn(1000,item.entity,0,pos,Vector(0,0),player):ToEffect()
			local d2 = q:GetData()
			d2[item.own_key.."effect"] = {linker = col,player = player,dmg = params.dmg or player.Damage,}
			d[item.own_key.."Horn"] = {linker = q,}
			Attribute_holder.try_hold_and_rewind_attribute(col,"Velocity",Vector(0,0),45,{toget = function(ent) return ent.Velocity end,tochange = function(ent,value) if value ~= true then ent.Velocity = value end end,tocompare = function(v1,v2) return (v1 - v2):Length() < 0.001 end,})
			Attribute_holder.try_hold_and_rewind_attribute(col,"EntityCollisionClass",EntityCollisionClass.ENTCOLL_NONE,45)
			col:AddEntityFlags(EntityFlag.FLAG_NO_SPRITE_UPDATE)
		end
	else
		local q = Isaac.Spawn(1000,item.entity,0,pos,Vector(0,0),player):ToEffect()
		local d2 = q:GetData()
		d2[item.own_key.."effect"] = {player = player,dmg = params.dmg or player.Damage,}
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = item.entity,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		local player = d[item.own_key.."effect"].player or auxi.check_spawner_player(ent)
		local ctrlvel = true
		if auxi.check_all_exists(d[item.own_key.."effect"].linker) then local tg = d[item.own_key.."effect"].linker ent.Position = tg.Position ent.Velocity = tg.Velocity ent.DepthOffset = tg.DepthOffset - 2 end
		local s = ent:GetSprite()
		if d[item.own_key.."effect"].Loaded == nil then
			s:Load("gfx/mimics/Big_Horn/big_horn_hand.anm2")
			s:Play("SmallHoleOpen",true)
			d[item.own_key.."effect"].Loaded = true
		end
		if s:IsFinished("SmallHoleOpen") then
			if d[item.own_key.."effect"].linker then
				if auxi.check_all_exists(d[item.own_key.."effect"].linker) then s:Play("HandGrab",true)
				else ent:Remove() return end
			else s:Play("HandSlap",true) end
		end
		if s:IsPlaying("HandSlap") then
			if s:WasEventTriggered("Move") and not s:WasEventTriggered("Stop") then
				ctrlvel = false
				local tg = auxi.get_nearest_enemy(nil,ent.Position)
				if auxi.check_all_exists(tg) then ent.Velocity = (tg.Position - ent.Position) * 0.3
				else ent.Velocity = ent.Velocity * 0.5 end
			end
			if s:IsEventTriggered("Slam") then
				local dpos = ent.Position + auxi.mul_t(auxi.ProtectVector(s.Scale),((item.hand_info[s:GetFrame()] or {}).pos or Vector(-20,25)))
				local n_entity = Isaac.GetRoomEntities()
				for u,v in pairs(n_entity) do 
					if (v.Position - dpos):Length() < 40 * s.Scale.X then v:TakeDamage(d[item.own_key.."effect"].dmg or 3.5,0,EntityRef(player),0) end
				end
				local q = Isaac.Spawn(1000,16,1,dpos,Vector(0,0),ent):ToEffect() q:GetSprite().Color = Color(1,1,1,0.6) q:GetSprite().Scale = auxi.mul_t(Vector(0.5,0.5),auxi.ProtectVector(s.Scale))
				local q = Isaac.Spawn(1000,16,2,dpos,Vector(0,0),ent):ToEffect() q:GetSprite().Color = Color(1,1,1,0.6) q:GetSprite().Scale = auxi.mul_t(Vector(0.5,0.5),auxi.ProtectVector(s.Scale))
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_FORESTBOSS_STOMPS,1,1,false,0,2)
			end
		end
		if s:IsFinished("HandSlap") then s:Play("SmallHoleClose",true) end
		if s:IsFinished("HandGrab") then s:Play("SmallHoleClose",true) end
		if s:IsFinished("SmallHoleClose") then ent:Remove() return end
		if s:IsEventTriggered("Slam") then
			if auxi.check_all_exists(d[item.own_key.."effect"].linker) then
				local tg = d[item.own_key.."effect"].linker
				tg:GetData()[item.own_key.."Horn"] = nil
				tg:ClearEntityFlags(EntityFlag.FLAG_NO_SPRITE_UPDATE)
				tg:Kill()
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_DEATH_BURST_SMALL,1,1,false,0,2)
				Game():ShakeScreen(7)
			end
		end
		if ctrlvel then ent.Velocity = Vector(0,0) end
	end
end,
})

return item
