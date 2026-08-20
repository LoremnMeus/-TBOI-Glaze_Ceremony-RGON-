local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_myToCall = {},
	post_ToCall = {},
	entity = enums.Trinkets.Pacification_Mark,
	buffers = {},
	marker = nil,
}

function item.check_buffers(ent,val)
	local tg = nil
	local aver = 0
	for i = #item.buffers,1,-1 do
		local v = item.buffers[i]
		if auxi.check_all_exists(v.ent) ~= true or v.ent.Price == 0 then table.remove(item.buffers,i) 
		else
			if auxi.check_for_the_same(ent,v.ent) then 
				tg = i 
				v.val = val
			end
			aver = aver + v.val
		end
	end
	if tg == nil then table.insert(item.buffers,#item.buffers + 1,{ent = ent,val = val,}) aver = aver + val end
	return math.ceil(aver/(#item.buffers))
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_CHECK_PRICE, params = nil,
Function = function(_,ent,val)
	local v = val
	if val == -1000 then v = 0 end
	if auxi.have_player_has_trinket(item.entity) and v >= 0 then
		local ret = item.check_buffers(ent,v)
		if ret == 0 then ret = -1000 end
		return ret
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	item.marker = nil
	item.marker2 = nil
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if item.marker2 and auxi.have_player_has_trinket(item.entity) == nil then
		item.marker2 = nil
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = nil,
Function = function(_,ent)
	if ent:IsShopItem() and auxi.have_player_has_trinket(item.entity) then
		price_holder.try_catch_price(ent)
		if item.marker2 == nil or (ent.FrameCount <= 2 and not item.marker) then 
			item.marker2 = true
			item.marker = true
			delay_buffer.addeffe(function(params)
				price_holder.reset_price()
				item.marker = nil
			end,{},1)
		end
	end
end,
})

return item