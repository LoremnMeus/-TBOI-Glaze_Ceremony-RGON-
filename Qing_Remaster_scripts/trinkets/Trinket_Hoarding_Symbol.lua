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
	entity = enums.Trinkets.Hoarding_Symbol,
	own_key = "Trinkets_Hoarding_Symbol_",
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GAIN_TRINKET, params = item.entity,
Function = function(_,player,tid,cnt,touched,curNum,known,golden)
	if touched ~= true and not (not known and curNum ~= 0) and player:HasTrinket(item.entity) then
		player:AddCoins(-player:GetNumCoins())
		player:AddKeys(-player:GetNumKeys())
		player:AddBombs(-player:GetNumBombs())
		save.elses[item.own_key.."buff"] = save.elses[item.own_key.."buff"] or {}
		local idx = player:GetData().__Index
		save.elses[item.own_key.."buff"][idx] = (save.elses[item.own_key.."buff"][idx] or 0) + 1
		player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
		player:GetData().should_evaluate_on_update_once = true
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local d = player:GetData()
	local idx = d.__Index
	if idx ~= nil and save.elses[item.own_key.."buff"] then
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			local num = save.elses[item.own_key.."buff"][idx] or 0
			player.Damage = player.Damage + num * auxi.get_damage_multiplier(player)
		end
	end
end,
})

return item