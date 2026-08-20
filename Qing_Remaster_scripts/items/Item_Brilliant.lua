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
	pre_myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Brilliant,
	info = {
		["zh_cn"] = "#{{Coin}} 基础价格不高于所持有的硬币数量",
		["en_us"] = "#{{Coin}} Basic price not higher than the number of coins held",
	},
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = item.entity,
Function = function(_,player,collid,cnt,touched)
	if not touched then
		player:AddGoldenHearts(3)
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_CHECK_PRICE, params = nil,
Function = function(_,ent,val)
	local v = val
	if val == -1000 then v = 0 end
	if auxi.have_player_has_collectible(item.entity) and v >= 0 then
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			v = math.max(0,v - player:GetGoldenHearts())
		end
		ret = v
		if ret == 0 then ret = -1000 end
		return ret
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = nil,
Function = function(_,ent)
	if ent:IsShopItem() and auxi.have_player_has_collectible(item.entity) then
		price_holder.try_catch_price(ent)
	end
end,
})

table.insert(item.pre_myToCall,#item.pre_myToCall + 1,{CallBack = enums.Callbacks.PRE_CHECK_PRICE, params = nil,
Function = function(_,ent,val)
	local d = ent:GetData()
	if ent.Variant == 100 and ent.SubType == item.entity then
		if val > 0 then return math.min(math.max(1,Game():GetPlayer(0):GetNumCoins()),val) end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = nil,
Function = function(_,ent)
	if ent:IsShopItem() and ent.Variant == 100 and ent.SubType == item.entity then
		price_holder.try_catch_price(ent)
	end
end,
})

if EID then

EID:addDescriptionModifier("qing_item_sync"..tostring(item.entity), function(desc) return true end, function(desc)
	if desc.Entity and desc.Entity.Type == 5 and desc.Entity.Variant == 100 and desc.Entity.SubType == item.entity and desc.Entity:ToPickup():IsShopItem() and desc.Entity:ToPickup().Price > 0 then
		local language = auxi.get_EID_language()
		local info = item.info[language] or item.info["en_us"]
		EID:appendToDescription(desc, info)
	end
	return desc
end)

end

return item