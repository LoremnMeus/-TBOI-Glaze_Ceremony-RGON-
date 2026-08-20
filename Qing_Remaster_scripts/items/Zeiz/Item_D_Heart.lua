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
	entity = enums.Items.D_Heart,
	own_key = "Item_D_Heart_",
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.MC_EVALUATE_DULL_POINT, params = nil,
Function = function(_,player,tp,value)
	if auxi.has_have_coll(player,item.entity) and tp ~= "Real" then 
		value = value + math.floor(player:GetHearts()/2)
		return value
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = nil,
Function = function(_,ent,col,low)
	if (ent.Variant == 10 and (ent.SubType == 0 or ent.SubType == 1)) and ent.Price == 0 then
		local player = col:ToPlayer()
		if player and Dull.get_point(player) >= 1 and not player:CanPickRedHearts() then
			Dull.add_point(player,-1)
			ent:Morph(5,10,3,true,true,true)
			return false
		end
	end
end,
})

return item