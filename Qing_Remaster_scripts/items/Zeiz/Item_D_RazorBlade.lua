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
	entity = enums.Items.D_RazorBlade,
	own_key = "Item_D_RazorBlade_",
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,colid,rng,player,useFlags,activeSlot,customVarData)
	if player:CanTakeRedHearts() then
		player:TakeDamage(1, DamageFlag.DAMAGE_RED_HEARTS | DamageFlag.DAMAGE_NO_PENALTIES, EntityRef(player), 0)
		
		-- 添加临时攻击提升
		local d = player:GetData()
		local idx = d.__Index
		save.elses[item.own_key.."damage"] = save.elses[item.own_key.."damage"] or {}
		save.elses[item.own_key.."damage"][idx] = (save.elses[item.own_key.."damage"][idx] or 0) + 2.0
		
		-- 添加临时幸运下降
		save.elses[item.own_key.."luck"] = save.elses[item.own_key.."luck"] or {}
		save.elses[item.own_key.."luck"][idx] = (save.elses[item.own_key.."luck"][idx] or 0) - 1.0
		
		player:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_LUCK)
		d.should_evaluate_on_update_once = true
		
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_RAZOR,1,1,false,0,2)
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if Game():GetFrameCount() % 300 == 0 then -- 每5秒减少效果
		save.elses[item.own_key.."damage"] = save.elses[item.own_key.."damage"] or {}
		save.elses[item.own_key.."luck"] = save.elses[item.own_key.."luck"] or {}
		
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			local d = player:GetData()
			local idx = d.__Index
			
			-- 减少攻击提升
			if save.elses[item.own_key.."damage"][idx] and save.elses[item.own_key.."damage"][idx] > 0 then
				save.elses[item.own_key.."damage"][idx] = math.max(0, save.elses[item.own_key.."damage"][idx] - 0.2)
			end
			
			-- 恢复幸运
			if save.elses[item.own_key.."luck"][idx] and save.elses[item.own_key.."luck"][idx] < 0 then
				save.elses[item.own_key.."luck"][idx] = math.min(0, save.elses[item.own_key.."luck"][idx] + 0.1)
			end
			
			if (save.elses[item.own_key.."damage"][idx] and save.elses[item.own_key.."damage"][idx] > 0) or 
			   (save.elses[item.own_key.."luck"][idx] and save.elses[item.own_key.."luck"][idx] < 0) then
				player:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_LUCK)
				d.should_evaluate_on_update_once = true
			end
		end
	end
end,
})

table.insert(item.post_ToCall,#item.post_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	local d = player:GetData()
	local idx = d.__Index
	if idx ~= nil then
		save.elses[item.own_key.."damage"] = save.elses[item.own_key.."damage"] or {}
		save.elses[item.own_key.."luck"] = save.elses[item.own_key.."luck"] or {}
		
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			local damageMul = save.elses[item.own_key.."damage"][idx] or 0
			if damageMul > 0 then
				player.Damage = player.Damage + auxi.get_damage_multiplier(player) * damageMul
			end
		elseif cacheFlag == CacheFlag.CACHE_LUCK then
			local luckMul = save.elses[item.own_key.."luck"][idx] or 0
			if luckMul ~= 0 then
				player.Luck = player.Luck + luckMul
			end
		end
	end
end,
})

return item
