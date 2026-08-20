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
	entity = enums.Trinkets.Allocation_Symbol,
	own_key = "Trinkets_Allocation_Symbol_",
	limit = 0.1,
}

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,priority = 10,
Function = function(_,player,cacheFlag)
	local d = player:GetData()
	if player:GetTrinketMultiplier(item.entity) > 0 then
		local mul = player:GetTrinketMultiplier(item.entity) * item.limit
		if cacheFlag == CacheFlag.CACHE_DAMAGE then player.Damage = math.ceil(player.Damage/mul) * mul end
		if cacheFlag == CacheFlag.CACHE_SHOTSPEED then player.ShotSpeed = math.ceil(player.ShotSpeed/mul) * mul end
		if cacheFlag == CacheFlag.CACHE_SPEED then player.MoveSpeed = math.ceil(player.MoveSpeed/mul) * mul end
		if cacheFlag == CacheFlag.CACHE_LUCK then player.Luck = math.ceil(player.Luck/mul) * mul end
		if cacheFlag == CacheFlag.CACHE_RANGE then player.TearRange = math.ceil(player.TearRange/40/mul) * mul * 40 end
		if cacheFlag == CacheFlag.CACHE_FIREDELAY then 
			local tear = 30 / (player.MaxFireDelay + 1) 
			player.MaxFireDelay = (30 / (math.ceil(tear/mul) * mul)) - 1
		end
	end
end,
})

return item