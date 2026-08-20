local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	entity = enums.Items.Giant_Punch,
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if auxi.has_have_coll(player,item.entity) then
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			local heart = player:GetHearts() + player:GetSoulHearts() + player:GetEternalHearts()
			local mxheart = player:GetMaxHearts() + player:GetBoneHearts() * 2
			if heart < mxheart then
				player.Damage = player.Damage * 2
			elseif heart > mxheart then
				player.Damage = player.Damage * 0.5
			end
		end
		if cacheFlag == CacheFlag.CACHE_SIZE then
			local heart = player:GetHearts() + player:GetSoulHearts() + player:GetEternalHearts()
			local mxheart = player:GetMaxHearts() + player:GetBoneHearts() * 2
			if heart < mxheart then
				player.SpriteScale = player.SpriteScale * 1.25;
			elseif heart > mxheart then
				player.SpriteScale = player.SpriteScale * 0.75;
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if auxi.has_have_coll(player,item.entity) then
		player:GetData().should_evaluate_on_update_once = true
		player:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_SIZE)
	end
end,
})

return item