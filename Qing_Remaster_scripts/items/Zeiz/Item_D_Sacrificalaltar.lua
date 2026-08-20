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
	entity = enums.Items.D_Sacrificalaltar,
	own_key = "Item_D_Sacrificalaltar_",
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local cnt = player:GetCollectibleNum(item.entity)
	if cacheFlag == CacheFlag.CACHE_LUCK then
		player.Luck = player.Luck - 5 * cnt -- -5幸运
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_INIT, params = nil,
Function = function(_,player)
	if auxi.has_have_coll(player,item.entity) then
		-- 生成一个随机宝宝
		local room = Game():GetRoom()
		local pos = room:FindFreePickupSpawnPosition(player.Position, 20, true)
		
		-- 随机选择一个宝宝类型
		local familiarTypes = {
			FamiliarVariant.BROTHER_BOBBY,
			FamiliarVariant.SISTER_MAGGY,
			FamiliarVariant.LITTLE_CHAD,
			FamiliarVariant.ROBO_BABY,
			FamiliarVariant.LITTLE_STEVEN,
			FamiliarVariant.DRY_BABY,
			FamiliarVariant.JUICY_SACK,
			FamiliarVariant.ROBO_BABY_2,
			FamiliarVariant.ROTTEN_BABY,
			FamiliarVariant.HEADLESS_BABY,
		}
		
		local randomFamiliar = familiarTypes[math.random(1, #familiarTypes)]
		Isaac.Spawn(3, randomFamiliar, 0, pos, Vector(0,0), player)
	end
end,
})

return item

