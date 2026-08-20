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
	entity = enums.Items.D_Lusty,
	own_key = "Item_D_Lusty_",
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local cnt = player:GetCollectibleNum(item.entity)
	if cacheFlag == CacheFlag.CACHE_LUCK then
		player.Luck = player.Luck - 2 * cnt
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_INIT, params = nil,
Function = function(_,player)
	if auxi.has_have_coll(player,item.entity) then
		-- +2心之容器
		for i = 1, 2 do
			player:AddMaxHearts(2, true)
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.has_have_coll(player,item.entity) then
			-- 下层后+1白心并-1幸运
			local room = Game():GetRoom()
			local pos = room:FindFreePickupSpawnPosition(player.Position, 10, true)
			Isaac.Spawn(5, 10, 4, pos, Vector(0,0), player) -- 白心
			
			player.Luck = player.Luck - 1
			player:AddCacheFlags(CacheFlag.CACHE_LUCK)
			local d = player:GetData()
			d.should_evaluate_on_update_once = true
		end
	end
end,
})

return item

