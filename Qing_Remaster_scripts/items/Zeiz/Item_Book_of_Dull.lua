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
	entity = enums.Items.Book_of_Dull,
	own_key = "Item_Book_of_Dull_",
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,colid,rng,player,useFlags,activeSlot,customVarData)
	-- 钝化之书 - 根据描述为空，暂时实现为获得愚钝值
	local currentDull = Dull.get_point(player)
	Dull.add_point(player, 5) -- 获得5点愚钝值
	
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOOK_PAGE_TURN_12,1,1,false,0,2)
end,
})

return item

