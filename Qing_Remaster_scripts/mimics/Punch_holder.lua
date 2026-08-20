local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Punch_holder_",
}

function item.Add_Punch(ent,col,params)
	params = params or {}
	local vel = params.vel or Vector(0,0)
	if not col:HasEntityFlags(EntityFlag.FLAG_KNOCKED_BACK) then
		local d = col:GetData() 
		d[item.own_key.."effect"] = {counter = 2,}
		col:AddConfusion(EntityRef(ent),30,false)
		--col:AddFreeze(EntityRef(ent),30 * 2)
		d[item.own_key.."effect"].vel = vel
		d[item.own_key.."effect"].velocity = Attribute_holder.try_hold_and_rewind_attribute(col,"Velocity",vel,30,{toget = function(ent) return ent.Velocity end,tochange = function(ent,value) if value ~= true then ent.Velocity = value end end,tocompare = function(v1,v2) return (v1 - v2):Length() < 0.001 end,})
		Attribute_holder.try_hold_and_rewind_attribute(col,"ENTITY_FLAG_FLAG_KNOCKED_BACK",true,30,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_KNOCKED_BACK))
		Attribute_holder.try_hold_and_rewind_attribute(col,"ENTITY_FLAG_FLAG_FLAG_APPLY_IMPACT_DAMAGE",true,30,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_APPLY_IMPACT_DAMAGE))
		--Attribute_holder.try_hold_and_rewind_attribute(col,"ENTITY_FLAG_FLAG_FLAG_SLIPPERY_PHYSICS",true,20,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_SLIPPERY_PHYSICS))
		--Attribute_holder.try_hold_and_rewind_attribute(col,"EntityFlag_FLAG_NO_SPRITE_UPDATE",true,Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_SPRITE_UPDATE))
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_PUNCH,math.random(1000)/1000 * 0.3 + 0.85,math.random(1000)/1000 * 0.1 + 0.95,false,0,2)
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_NPC_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] and not ent:HasEntityFlags(EntityFlag.FLAG_KNOCKED_BACK) then d[item.own_key.."effect"].counter = (d[item.own_key.."effect"].counter or 0) - 1 if d[item.own_key.."effect"].counter < 0 then d[item.own_key.."effect"] = nil end 
	elseif d[item.own_key.."effect"] then
		if d[item.own_key.."effect"].velocity then ent.Velocity = d[item.own_key.."effect"].vel or Vector(0,0) end
		if ent:CollidesWithGrid() and d[item.own_key.."effect"].velocity then
			Attribute_holder.try_rewind_attribute(ent,"Velocity",d[item.own_key.."effect"].velocity,{toget = function(ent) return ent.Velocity end,tochange = function(ent,value) if value ~= true then ent.Velocity = value end end,tocompare = function(v1,v2) return (v1 - v2):Length() < 0.001 end,})
			ent:TakeDamage(10,0,EntityRef(ent),0)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_PUNCH,1,1,false,0,2)
			d[item.own_key.."effect"] = nil
		end
	end
end,
})

return item