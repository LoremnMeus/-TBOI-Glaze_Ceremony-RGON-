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
	entity = enums.Items.D_Flame,
	own_key = "Item_D_Flame_",
}

-- 钝化神火 - 根据描述为空，暂时实现为提供火焰免疫
table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = nil,
Function = function(_,ent,amt,flag,source,cooldown)
	if ent:ToPlayer() then
		local player = ent:ToPlayer()
		if auxi.has_have_coll(player,item.entity) then
			-- 免疫火焰伤害
			if flag & DamageFlag.DAMAGE_FIRE > 0 then
				return false
			end
		end
	end
end,
})

return item

