local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Book_of_Belial_holder_",
}

function item.Add_dmg(player,val,params)
	player = player or Game():GetPlayer(0)
	params = params or {}
	params.counter = params.counter or 30
	local d = player:GetData()
	local idx = d.__Index
	if params.counter <= 0 then
		save.elses[item.own_key.."buff"] = save.elses[item.own_key.."buff"] or {}
		save.elses[item.own_key.."buff"][idx] = save.elses[item.own_key.."buff"][idx] or 0
		save.elses[item.own_key.."buff"][idx] = save.elses[item.own_key.."buff"][idx] + val
	else
		d[item.own_key.."bufflist"] = d[item.own_key.."bufflist"] or {}
		table.insert(d[item.own_key.."bufflist"],#d[item.own_key.."bufflist"] + 1,{
			pdmg = val/params.counter,counter = params.counter,
		})
	end
	item.Evaluate(player)
end

function item.Evaluate(player)
	local d = player:GetData()
	local dmg = 0
	if d[item.own_key.."bufflist"] then
		for i = #(d[item.own_key.."bufflist"]),1,-1 do
			local v = d[item.own_key.."bufflist"][i]
			v.counter = (v.counter or 0)
			if v.counter <= 0 then table.remove(d[item.own_key.."bufflist"],i) 
			else dmg = dmg + v.pdmg * v.counter end
		end
	end
	d[item.own_key.."buff"] = dmg
	player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
	player:GetData().should_evaluate_on_update_once = true
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local d = player:GetData()
	local idx = d.__Index
	if idx then
		if cacheFlag & CacheFlag.CACHE_DAMAGE == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + auxi.get_damage_multiplier(player) * (((save.elses[item.own_key.."buff"] or {})[idx] or 0) + (d[item.own_key.."buff"] or 0))
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if Game():GetFrameCount() % 15 == 5 then
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			local d = player:GetData()
			local idx = d.__Index
			if d[item.own_key.."bufflist"] then
				for u,v in pairs(d[item.own_key.."bufflist"]) do v.counter = (v.counter or 1) - 1	end
				item.Evaluate(player)
			else d[item.own_key.."buff"] = nil end
		end
	end
end,
})

return item