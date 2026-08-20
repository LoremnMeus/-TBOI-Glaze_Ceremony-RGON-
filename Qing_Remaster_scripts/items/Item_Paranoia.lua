local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder") 
local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")

local item = {
	ToCall = {},
	pre_myToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Paranoia,
	own_key = "Item_Paranoia_",
	info = {
		["zh_cn"] = "#{{Coin}} 价格不低于所持有的硬币数量",
		["en_us"] = "#{{Coin}} Price not lower than the number of coins held",
	},
}
auxi.add_to_seija(item.entity)

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = 100,priority = -90,
Function = function(_,ent,col,low)
	local player = col:ToPlayer()
	if player and auxi.has_have_coll(player,item.entity) and auxi.will_pick_up(player,ent) and ent.Touched ~= true then
		local rng = player:GetCollectibleRNG(item.entity)
		for i = 1,1 do if rng:RandomFloat() < 0.50 then
			rng:Next()
			local st = ent.SubType
			if auxi.should_do_Seija(player) and rng:RandomFloat() < 0.1 then st = 258 end
			local colinfo = Isaac.GetItemConfig():GetCollectible(st)
			if ent.Price ~= 0 then 
				if auxi.can_buy(ent,player) then auxi.buy_a_pickup(ent,player,{NoAnim = true,no_remove = true,})
				else break end
			end
			if colinfo.Type == ItemType.ITEM_ACTIVE and auxi.would_replace_active(player) then
				local actid = player:GetActiveItem(0)
				unique_holder.Hold_for_missing(true)
				local q = Isaac.Spawn(5,100,actid,Game():GetRoom():FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
				auxi.self_morph(q,{5,100,actid,})
				q.Touched = true
				q.Charge = player:GetActiveCharge(0) + player:GetBatteryCharge(0)
				unique_holder.Hold_for_missing()
			end
			auxi.try_start_ambush()
			print(ent.Touched)
			if auxi.REPENTENCE_PLUS() then
				player:AddCollectible(colinfo.ID, ent.Charge,not ent.Touched)  -- 新版本使用AddCollectible
			else
				player:QueueItem(colinfo, ent.Charge, ent.Touched)  -- 旧版本保持原样
			end
			player:AnimateCollectible(st,"Pickup","PlayerPickupSparkle")
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_POWERUP1,1,1,false,0,2)
			item_displaying_holder.display_item(player,st)
			return true
		end end
	end
end,
})

table.insert(item.pre_myToCall,#item.pre_myToCall + 1,{CallBack = enums.Callbacks.PRE_CHECK_PRICE, params = nil,
Function = function(_,ent,val)
	local d = ent:GetData()
	if ent.Variant == 100 and ent.SubType == item.entity then
		if val > 0 then return math.max(Game():GetPlayer(0):GetNumCoins(),val) end
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