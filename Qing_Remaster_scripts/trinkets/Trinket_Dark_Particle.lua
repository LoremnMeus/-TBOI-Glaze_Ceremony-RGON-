local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Trinkets.Dark_Particle,
	own_key = "Trinkets_Dark_Particle_",
}

--table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_PICKUP_TRINKET, params = item.entity,
--Function = function(_,player,tid,golden,touched)
table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GAIN_TRINKET, params = item.entity,
Function = function(_,player,tid,cnt,touched,curNum,known,golden,total)
	if touched ~= true then
		local cnt = total or cnt
		if (not known and curNum ~= 0) or player:HasTrinket(item.entity) ~= true then cnt = 0 end
		for i = 1,cnt do 
			auxi.add_soul_heart(player,1)
			player:AddBlackHearts(1)
		end
		save.elses[item.own_key.."cnt"] = (save.elses[item.own_key.."cnt"] or 0) + cnt
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_LOSE_TRINKET, params = item.entity,
Function = function(_,player,tid,cnt,curNum)
	if (save.elses[item.own_key.."cnt"] or 0) > 0 then 
		local cnt = math.min(save.elses[item.own_key.."cnt"],cnt)
		player:AddBrokenHearts(cnt) 
		save.elses[item.own_key.."cnt"] = save.elses[item.own_key.."cnt"] - cnt 
	end
end,
})

return item