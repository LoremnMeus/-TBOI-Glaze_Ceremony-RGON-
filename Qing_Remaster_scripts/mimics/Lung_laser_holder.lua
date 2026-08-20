local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Lung_laser_holder_",
}

function item.fire_one_lung_laser(player,pos,id,dir,leg,params)
	params = params or {}
	player = player or params.player or Game():GetPlayer(0)
	local dmgmul = auxi.choose(0.5,1,2,2,4)
	local q = player:FireTechLaser(pos or player.Position,id or 0,dir or Vector(1,0),false,true,player,dmgmul)
	q.PositionOffset = params.Posoffset or q.PositionOffset
	q.CollisionDamage = (params.dmg or q.CollisionDamage)/dmgmul * (params.Dmgmul or 1)
	q:SetMaxDistance(leg)
	q.SubType = 4
	return q
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_LASER_UPDATE, params = nil,
Function = function(_,ent)
	if ent.FrameCount >= 2 then
		local d = ent:GetData()
		if d[item.own_key.."effect"] and (d[item.own_key.."effect"].mul or 0) > 0 then
			local samples = ent:GetSamples()
			local dpos = auxi.MakeVector(ent.Angle)
			if #samples > 1 then dpos = samples:Get(#samples - 1) - samples:Get(#samples - 2) end
			--if ent.BounceLaser then local samples = ent.BounceLaser:ToLaser():GetSamples() if #samples > 1 then dpos = samples:Get(#samples - 1) - samples:Get(#samples - 2) end end
			local q = item.fire_one_lung_laser(d[item.own_key.."effect"].player,ent.EndPoint,0,auxi.get_by_rotate(dpos,auxi.random_2() * (d[item.own_key.."effect"].angle or 40)),(d[item.own_key.."effect"].legth or 80) + auxi.random_2() * (d[item.own_key.."effect"].leg2 or 50),d[item.own_key.."effect"])
			q.TearFlags = q.TearFlags & ~(BitSet128(1<<8,0) | BitSet128(1<<16,0) | BitSet128(1<<17,0))
			local d2 = q:GetData()
			d2[item.own_key.."effect"] = auxi.copy(d[item.own_key.."effect"])
			d2[item.own_key.."effect"].mul = d2[item.own_key.."effect"].mul - 1
			d2[item.own_key.."effect"].angle = (d2[item.own_key.."effect"].angle or 40) + 30
			if d2[item.own_key.."effect"].mul <= 0 then q.SubType = 0 end
			
			d[item.own_key.."effect"] = nil
		end
	end
end,
})

return item