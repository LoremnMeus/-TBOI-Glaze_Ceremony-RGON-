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
	entity = enums.Items.D_Trinity,
	own_key = "Item_D_Trinity_",
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local cnt = player:GetCollectibleNum(item.entity)
	if cacheFlag == CacheFlag.CACHE_LUCK then
		player.Luck = player.Luck * (1 - 2 * cnt) -- -2倍幸运
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_FIRE_TEAR, params = nil,
Function = function(_,player,tear)
	if auxi.has_have_coll(player,item.entity) then
		-- 子弹发射小子弹并试图躲避敌人
		local room = Game():GetRoom()
		local enemies = Isaac.GetRoomEntities()
		local closestEnemy = nil
		local closestDist = 999999
		
		-- 找到最近的敌人
		for i = 1, #enemies do
			local enemy = enemies[i]
			if enemy:IsEnemy() and enemy:IsActiveEnemy() then
				local dist = tear.Position:Distance(enemy.Position)
				if dist < closestDist then
					closestDist = dist
					closestEnemy = enemy
				end
			end
		end
		
		-- 发射小子弹
		for i = 1, 3 do
			local angle = tear.Velocity:GetAngleDegrees() + (i - 2) * 30
			local velocity = Vector.FromAngle(angle) * 3
			local smallTear = Isaac.Spawn(2, 0, 0, tear.Position, velocity, player):ToTear()
			smallTear:ChangeVariant(TearVariant.BLUE)
			smallTear.Scale = 0.5
			smallTear.CollisionDamage = tear.CollisionDamage * 0.3
			
			-- 试图躲避敌人
			if closestEnemy and auxi.random_1() < 0.5 then
				local avoidAngle = (tear.Position - closestEnemy.Position):GetAngleDegrees()
				smallTear.Velocity = Vector.FromAngle(avoidAngle) * 3
			end
		end
	end
end,
})

return item

