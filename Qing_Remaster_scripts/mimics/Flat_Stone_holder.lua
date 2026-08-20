local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Flat_Stone_holder_",
	entity = EffectVariant.WATER_RIPPLE,
}

function item.attack_wave(pos,params)
	params = params or {}
	local q = Isaac.Spawn(1000,item.entity,0,pos,params.vel or Vector(0,0),nil):ToEffect()
	local d = q:GetData()
	local s = q:GetSprite()
	s.Scale = params.scale or s.Scale
	d[item.own_key.."effect"] = params.dmg or 5
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = item.entity,
Function = function(_,ent)
	local d = ent:GetData()
	local s = ent:GetSprite()
	if d[item.own_key.."effect"] then
		if s:GetFrame() == 10 then
			local n_enemy = Isaac.FindInRadius(ent.Position,s.Scale:Length() * 25,1<<3)
			for u,v in pairs(n_enemy) do if auxi.isenemies(v) then v:TakeDamage(d[item.own_key.."effect"] or 5,0,EntityRef(ent),0) end end
		end
	end
end,
})

return item