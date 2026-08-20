local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Jacob_ladder_holder_",
}
--l local Jacob_ladder_holder = require("Qing_Remaster_scripts.mimics.Jacob_ladder_holder") Jacob_ladder_holder.fire_laser(Vector(200,200))

function item.fire_laser(pos,params)
	params = params or {}
	local player = params.player or Game():GetPlayer(0)
	local blacklist = params.blacklist or {}
	local tg = auxi.get_nearest_enemy(nil,pos,function(leg,v) if blacklist[GetPtrHash(v)] then return 9999 else return leg end end)
	if tg and blacklist[GetPtrHash(tg)] then tg = nil end
	local dir = auxi.random_r()
	local range = params.range or 80
	local leg = auxi.random_1() * range * 0.5 + range * 0.5
	if Game():GetRoom():HasWater() then range = 999 end
	if tg == nil or (tg.Position - pos):Length() > range then if params.attack then return end else 
		dir = tg.Position - pos leg = dir:Length() + tg.Size
		blacklist[GetPtrHash(tg)] = true
	end
	local q = Isaac.Spawn(7,10,0,pos,Vector(0,0),player):ToLaser()
	q.Angle = dir:GetAngleDegrees()
	q.MaxDistance = leg + q.Size
	q:SetTimeout(2)
	q.OneHit = true
	q.CollisionDamage = params.dmg or (3.5 * 0.5)
	q:GetData()[item.own_key.."effect"] = {mul = params.mul or 4,blacklist = blacklist,range = params.range,player = player,}
	return q
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_LASER_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then
		if (d[item.own_key.."effect"].mul or 0) > 0 then item.fire_laser(ent.EndPoint,{dmg = ent.CollisionDamage,mul = d[item.own_key.."effect"].mul - 1,blacklist = d[item.own_key.."effect"].blacklist,range = d[item.own_key.."effect"].range,attack = true,player = d[item.own_key.."effect"].player,}) end
		d[item.own_key.."effect"].mul = nil
	end
end,
})

return item