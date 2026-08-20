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
	entity = enums.Items.D_Soul,
	own_key = "Item_D_Soul_",
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_,colid,rng,player,useFlags,activeSlot,customVarData)
	-- 生成3个随机钝化道具
	local room = Game():GetRoom()
	local dullItems = {
		enums.Items.D_Heart,
		enums.Items.D_Key,
		enums.Items.D_Bomb,
		enums.Items.D_RazorBlade,
		enums.Items.D_Cross,
		enums.Items.D_Lusty,
		enums.Items.D_Flame,
		enums.Items.D_Rag,
		enums.Items.D_Trinity,
		enums.Items.D_Sacrificalaltar,
		enums.Items.D_Coin,
		enums.Items.D_Pointyrib,
		enums.Items.D_Pack,
	}
	
	for i = 1, 3 do
		local pos = room:FindFreePickupSpawnPosition(player.Position, 20 + i * 10, true)
		local randomItem = dullItems[math.random(1, #dullItems)]
		Isaac.Spawn(5, 100, randomItem, pos, Vector(0,0), player)
	end
	
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_ITEMRECHARGE,1,1,false,0,2)
end,
})

return item

