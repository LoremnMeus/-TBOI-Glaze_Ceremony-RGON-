local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Dull = require("Qing_Remaster_scripts.items.Zeiz.Item_Dull_items")

local item = {
	ToCall = {},
	pre_ToCall = {},
	post_ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	post_myToCall = {},
	entity = enums.Items.D_Coin,
	own_key = "Item_D_Coin_",
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local cnt = player:GetCollectibleNum(item.entity)
	if cacheFlag == CacheFlag.CACHE_LUCK then
		player.Luck = player.Luck - 25 * cnt -- -25幸运
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_INIT, params = nil,
Function = function(_,player)
	if auxi.has_have_coll(player,item.entity) then
		-- +33硬币
		local d = player:GetData()
		local idx = d.__Index
		save.elses[item.own_key.."coins"] = save.elses[item.own_key.."coins"] or {}
		save.elses[item.own_key.."coins"][idx] = (save.elses[item.own_key.."coins"][idx] or 0) + 33
		
		-- 直接给玩家硬币
		for i = 1, 33 do
			player:AddCoins(1)
		end
	end
end,
})

return item

