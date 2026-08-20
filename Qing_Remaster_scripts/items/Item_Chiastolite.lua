local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Color_holder = require("Qing_Remaster_scripts.others.Color_cross_holder")
local Nil_holder = require("Qing_Remaster_scripts.others.Nil_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Chiastolite,
	familiar = enums.Familiars.ChiastoliteNil,
	own_key = "Item_Chiastolite_",
	ignorers = {
		[33] = true,
		[79] = function(ent) if ent.Variant == 20 then return true end end,
		[912] = function(ent) 
			if ent.Variant == 0 and (ent.SubType == 1 or ent.SubType == 2 or ent.SubType == 3) then return true end 
		end,
	},
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local cnt = player:GetCollectibleNum(item.entity)
	if cacheFlag == CacheFlag.CACHE_FAMILIARS then
		player:CheckFamiliar(item.familiar, cnt, player:GetCollectibleRNG(item.entity), Isaac.GetItemConfig():GetCollectible(item.entity))
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_FAMILIAR_UPDATE, params = item.familiar,
Function = function(_,ent)
	local d = ent:GetData()
	if auxi.check_all_exists(d[item.own_key.."linker"]) ~= true then
		local find_nil = false
		if d[item.own_key.."linker"] == nil then find_nil = true end
		d[item.own_key.."linker"] = auxi.random_in_table(auxi.getenemies(nil,function(ent) if ent:GetData()[item.own_key.."effect2"] == nil then return true end end))
		if auxi.check_all_exists(d[item.own_key.."linker"]) then
			local player = auxi.check_spawner_player(ent)
			local tg = d[item.own_key.."linker"]
			local d2 = tg:GetData()
			d2[item.own_key.."effect2"] = true
			local pos = ent.Position
			if find_nil then pos = player.Position end
			local q = auxi.fire_nil(pos,auxi.MakeVector(math.random(360)) * (math.random(1000)/1000 * 15 + 10),{cooldown = 60,}) 
			local d3 = q:GetData()
			d3.nil_mode = "chiastolite"
			d3[item.own_key.."effect"] = true
			d3[item.own_key.."target"] = tg
			d[item.own_key.."checker"] = q
		else d[item.own_key.."linker"] = nil end
	end
	if auxi.check_all_exists(d[item.own_key.."linker"]) then
		if d[item.own_key.."checker"] and auxi.check_all_exists(d[item.own_key.."checker"]) ~= true then
			local tg = d[item.own_key.."linker"]
			local d2 = tg:GetData()
			d2[item.own_key.."effect"] = true
			d[item.own_key.."checker"] = nil
		end
		ent.Position = d[item.own_key.."linker"].Position
		ent.Velocity = Vector(0,0)
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = nil,
Function = function(_,ent,amt,flag,source,cooldown)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		local mul = 0.2
		if ent:IsBoss() then mul = 0.05 end
		local val = ent.HitPoints * mul
		local player = auxi.have_player_has_collectible(item.entity) or Game():GetPlayer(0)
		local limit = math.max(player.Damage * 10,100)
		if val > limit then val = limit end
		local q = auxi.fire_nil(ent.Position,auxi.MakeVector(math.random(360)) * (math.random(1000)/1000 * 15 + 10),{cooldown = 9999,}) 
		local s2 = q:GetSprite()
		s2:Load("gfx/cards/cd03_emp_tear.anm2",true)
		s2:Play("RegularTear6",true)
		local d3 = q:GetData()
		d3.nil_mode = "chiastolite_heal"
		d3[item.own_key.."effect2"] = true
		d3[item.own_key.."target"] = ent
		d3[item.own_key.."time"] = 30
		d3[item.own_key.."val"] = val
		if ent:IsBoss() then d3[item.own_key.."time"] = 10 end
		ent.HitPoints = ent.HitPoints - val
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		if auxi.check_if_any(item.ignorers[ent.Type],ent) ~= true and ent.HitPoints > 0 then
			local s = ent:GetSprite()
			if auxi.check_all_exists(d[Color_holder.own_key.."linker"]) ~= true then
				Color_holder.try_add_edge_color(ent,Color(0,0,0,1,1,0,0))
			end
		end
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
			d[item.own_key.."counter"] = 30
			local mul = 0.2
			if col:IsBoss() then mul = 0.05 end
			mul = mul * 0.1
			local val = col.HitPoints * mul
			local limit = math.max(player.Damage * 10,100)
			if val > limit then val = limit end
			local q = auxi.fire_nil(col.Position,auxi.MakeVector(math.random(360)) * (math.random(1000)/1000 * 15 + 10),{cooldown = 9999,}) 
			local s2 = q:GetSprite()
			s2:Load("gfx/cards/cd03_emp_tear.anm2",true)
			s2:Play("RegularTear6",true)
			local d3 = q:GetData()
			d3.nil_mode = "chiastolite_heal"
			d3[item.own_key.."effect2"] = true
			d3[item.own_key.."target"] = col
			d3[item.own_key.."time"] = 30
			d3[item.own_key.."val"] = val
			if col:IsBoss() then d3[item.own_key.."time"] = 10 end
			col.HitPoints = col.HitPoints - val
		end
	end
end,
})

Nil_holder.register("chiastolite", {
	detect = function(d) return d[item.own_key.."effect"] end,
	update = function(ent, d, s, player)
		local targ = d[item.own_key.."target"]
		if auxi.check_all_exists(targ) then
			if (targ.Position - ent.Position):Length() < 15 then ent:Remove() return
			elseif (targ.Position - ent.Position):Length() < 50 then
				ent.Velocity = (targ.Position - ent.Position):Normalized() * math.max(math.max(4,targ.Velocity:Length() * 1.2),ent.Velocity:Length() * 0.98)
			else
				ent.Velocity = (ent.Velocity:Normalized() * math.max(0,1 - ent.FrameCount/50) + (targ.Position - ent.Position):Normalized() * math.min(1,ent.FrameCount/50)):Normalized() * (ent.Velocity:Length() + 3) * 0.9
			end
		else
			s.Color = auxi.AddColor(s.Color,Color(0,0,0,0),0.95,0.05)
			if s.Color.A < 0.1 then ent:Remove() return end
		end
		if auxi.check_all_exists(d[item.own_key.."tail"]) then
			d[item.own_key.."tail"].Position = ent.Position + Vector(0,-24)
			d[item.own_key.."tail"]:GetSprite().Color = Color(1,0,0,s.Color.A,1,0,0)
		else
			local q = Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.SPRITE_TRAIL, 0, ent.Position, Vector(0,0), ent):ToEffect()
			d[item.own_key.."tail"] = q
			q.MinRadius = 0.3
			q.MaxRadius = 0.15
			q.SpriteScale = Vector(1,1)
			q.Parent = ent
			q:GetSprite().Color = Color(1,0,0,s.Color.A,1,0,0)
		end
	end,
})

Nil_holder.register("chiastolite_heal", {
	detect = function(d) return d[item.own_key.."effect2"] end,
	update = function(ent, d, s, player)
		local targ = d[item.own_key.."target"]
		if auxi.check_all_exists(targ) then
			if ent.FrameCount > (d[item.own_key.."time"] or 30) then
				if (targ.Position - ent.Position):Length() < 15 then
					targ.HitPoints = targ.HitPoints + (d[item.own_key.."val"] or 30)
					targ:SetColor(Color(1,0.6,0.6,1,0.5,0.3,0.3),15,50,true,false)
					sound_tracker.PlayStackedSound(SoundEffect.SOUND_SOUL_PICKUP,0.3,1,false,0,2)
					ent:Remove()
					return
				elseif (targ.Position - ent.Position):Length() < 50 then ent.Velocity = (targ.Position - ent.Position):Normalized() * math.max(math.max(4,targ.Velocity:Length() * 1.2),ent.Velocity:Length() * 0.98)
				else ent.Velocity = (ent.Velocity:Normalized() * math.max(0,1 - ent.FrameCount/50) + (targ.Position - ent.Position):Normalized() * math.min(1,ent.FrameCount/50)):Normalized() * (ent.Velocity:Length() + 3) * 0.9 end
			else ent.Velocity = ent.Velocity:Normalized() * (ent.Velocity:Length() + 1.5) * 0.9 end
		else
			s.Color = auxi.AddColor(s.Color,Color(0,0,0,0),0.95,0.05)
			if s.Color.A < 0.1 then ent:Remove() return end
		end
		if auxi.check_all_exists(d[item.own_key.."tail"]) then
			d[item.own_key.."tail"].Position = ent.Position
			d[item.own_key.."tail"]:GetSprite().Color = Color(1,0,0,s.Color.A,1,0,0)
		else
			local q = Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.SPRITE_TRAIL, 0, ent.Position, Vector(0,0), ent):ToEffect()
			d[item.own_key.."tail"] = q
			q.MinRadius = 0.3
			q.MaxRadius = 0.15
			q.SpriteScale = Vector(1,1)
			q.Parent = ent
			q:GetSprite().Color = Color(1,0,0,s.Color.A,1,0,0)
		end
	end,
})

return item