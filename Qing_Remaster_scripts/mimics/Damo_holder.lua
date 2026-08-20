local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "Damo_holder_",
	entity = enums.Entities.Mimic_Damocles,
	Anims = {
		["Idle"] = {name = "Idle",weigh = 10,},
		["Idle2"] = {name = "Idle2",weigh = 5,},
		["Idle3"] = {name = "Idle3",weigh = 3,},
	},
}

function item.try_add_damo(ent)
	local d = ent:GetData()
	if auxi.check_all_exists(d[item.own_key.."effect"]) ~= true then
		local q = Isaac.Spawn(1000,item.entity,0,ent.Position,ent.Velocity,nil)
		local d2 = q:GetData()
		d2[item.own_key.."follower"] = ent
		d[item.own_key.."effect"] = q
	end
end

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = nil,
Function = function(_,ent,amt,flag,source,cooldown)
	local d = ent:GetData()
	if auxi.check_all_exists(d[item.own_key.."effect"]) and amt > ent.HitPoints then
		ent:TakeDamage(ent.HitPoints - 1,0,EntityRef(player),0)
		d[item.own_key.."Kill"] = true
		return false
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = item.entity,
Function = function(_,ent)
	local s = ent:GetSprite()
	local d = ent:GetData()
	local anim = s:GetAnimation()
	if s:IsFinished(anim) and item.Anims[anim] then s:Play(auxi.random_in_weighed_table(item.Anims).name,true) end
	local follower = d[item.own_key.."follower"]
	if auxi.check_all_exists(follower) and s:WasEventTriggered("Hit") ~= true then ent.Position = follower.Position ent.Velocity = follower.Velocity
	else ent.Velocity = ent.Velocity * 0.5 end
	if d[item.own_key.."kill"] then
		if s:IsEventTriggered("Hit") or s:WasEventTriggered("Hit") or s:IsFinished("Fall") then
			if auxi.check_all_exists(follower) then	follower:Kill()	end
		end
		if anim ~= "Fall" then s:Play("Fall",true) end
		if s:IsFinished("Fall") then ent:Remove() return end
	else
		if auxi.check_all_exists(follower) ~= true or follower.HitPoints < follower.MaxHitPoints * 0.1 or follower.HitPoints < 3 or follower:GetData()[item.own_key.."Kill"] then d[item.own_key.."kill"] = true end
	end
end,
})

return item