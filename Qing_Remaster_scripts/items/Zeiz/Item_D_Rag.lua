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
	entity = enums.Items.D_Rag,
	own_key = "Item_D_Rag_",
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PLAYER_COLLISION, params = nil,
Function = function(_,player,other,low)
	if other:ToPickup() and other.Variant == 10 and other.SubType == 3 then -- 魂心
		if auxi.has_have_coll(player,item.entity) then
			local d = player:GetData()
			local idx = d.__Index
			save.elses[item.own_key.."revive_flag"] = save.elses[item.own_key.."revive_flag"] or {}
			
			-- 设置复活标志
			if not save.elses[item.own_key.."revive_flag"][idx] then
				save.elses[item.own_key.."revive_flag"][idx] = true
			end
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		if auxi.has_have_coll(player,item.entity) then
			local d = player:GetData()
			local idx = d.__Index
			save.elses[item.own_key.."revive_flag"] = save.elses[item.own_key.."revive_flag"] or {}
			
			-- 检查是否死亡
			if player:IsDead() and save.elses[item.own_key.."revive_flag"][idx] then
				save.elses[item.own_key.."revive_flag"][idx] = false
				
				-- 计算复活失败概率
				local failChance = math.max(0, player.Luck * 5)
				if auxi.random_1() * 100 < failChance then
					-- 复活失败
					return
				end
				
				-- 复活成功：-10幸运并以半颗魂心复活
				player.Luck = player.Luck - 10
				player:AddCacheFlags(CacheFlag.CACHE_LUCK)
				d.should_evaluate_on_update_once = true
				
				-- 复活玩家
				player:Revive()
				player:AddSoulHearts(1) -- 半颗魂心
				
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_REVIVAL,1,1,false,0,2)
			end
		end
	end
end,
})

return item

