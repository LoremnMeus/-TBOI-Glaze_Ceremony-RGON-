local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Akeldama_holder_",
}

function item.Add_2(ent,player,id)
	local d2 = ent:GetData()
	local d = player:GetData()
	d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}
	id = id or (#d[item.own_key.."effect"] + 1)
	table.insert(d[item.own_key.."effect"],id,ent)
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local d = player:GetData()
	if d[item.own_key.."effect"] then
		for i = #d[item.own_key.."effect"],1,-1 do
			local v = d[item.own_key.."effect"][i]
			if auxi.check_all_exists(v) then 
			else table.remove(d[item.own_key.."effect"],i) end
		end
		for i = 1,#d[item.own_key.."effect"] do
			local v = d[item.own_key.."effect"][i]
			local d2 = v:GetData()
			d2[item.own_key.."effect"] = d2[item.own_key.."effect"] or {player = player,}
			d2[item.own_key.."effect"].id = i
		end
		d[item.own_key.."Pos"] = d[item.own_key.."Pos"] or {auxi.copyVec(player.Position),}
		local upbnd = (#d[item.own_key.."effect"] + 3) * 2
		if upbnd < #d[item.own_key.."Pos"] then for i = #d[item.own_key.."Pos"],upbnd,-1 do table.remove(d[item.own_key.."Pos"],i) end end
		if (player.Position - (d[item.own_key.."Pos"][1] or Vector(0,0))):Length() > 10 then 
			table.insert(d[item.own_key.."Pos"],1,auxi.copyVec(player.Position)) 
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local d = player:GetData()
		d[item.own_key.."Pos"] = nil
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_,ent)
	local d = ent:GetData()
	if d[item.own_key.."effect"] then 
		local player = d[item.own_key.."effect"].player
		if player then
			local d2 = player:GetData()
			local id = d[item.own_key.."effect"].id or 1
			d2[item.own_key.."Pos"] = d2[item.own_key.."Pos"] or {auxi.copyVec(player.Position),}
			local pos = d2[item.own_key.."Pos"][id * 2] or d2[item.own_key.."Pos"][#d2[item.own_key.."Pos"]]
			local dir = pos - ent.Position
			ent.Velocity = dir
		end
	end
end,
})

return item