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
	entity = enums.Items.D_Cross,
	own_key = "Item_D_Cross_",
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = nil,
Function = function(_,ent,amt,flag,source,cooldown)
	if ent:ToPlayer() then
		local player = ent:ToPlayer()
		if auxi.has_have_coll(player,item.entity) then
			local d = player:GetData()
			local idx = d.__Index
			save.elses[item.own_key.."hurt_count"] = save.elses[item.own_key.."hurt_count"] or {}
			save.elses[item.own_key.."hurt_count"][idx] = (save.elses[item.own_key.."hurt_count"][idx] or 0) + 1
			
			-- 减少幸运
			player.Luck = player.Luck - 0.2
			player:AddCacheFlags(CacheFlag.CACHE_LUCK)
			d.should_evaluate_on_update_once = true
			
			-- 每受伤5次生成魂心
			if save.elses[item.own_key.."hurt_count"][idx] >= 5 then
				save.elses[item.own_key.."hurt_count"][idx] = 0
				local room = Game():GetRoom()
				local pos = room:FindFreePickupSpawnPosition(player.Position, 10, true)
				Isaac.Spawn(5, 10, 3, pos, Vector(0,0), player)
			end
		end
	end
end,
})

return item

