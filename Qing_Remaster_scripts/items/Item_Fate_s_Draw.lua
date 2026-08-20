local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	ToCall = {},
	entity = enums.Items.Fate_s_Draw,
	cards = {
	},
	counter = 10,
	own_key = "Item_FtsD_",
}

if #item.cards == 0 then
	local config = Isaac.GetItemConfig()
	local sz = config:GetCards().Size - 1
	for i = 1,sz do
		local cardinfo = config:GetCard(i)
		local id = tostring(cardinfo.CardType)
		item.cards[id] = item.cards[id] or {}
		table.insert(item.cards[id],#item.cards[id] + 1,cardinfo.ID)
		if cardinfo.GreedModeAllowed == true then 
			local id = "g_" .. id
			item.cards[id] = item.cards[id] or {}
			table.insert(item.cards[id],#item.cards[id] + 1,cardinfo.ID)
		end
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	if Game():IsPaused() then
		item.should_change_now = true
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if auxi.has_have_coll(player,item.entity) then
		local d = player:GetData()
		d[item.own_key.."counter"] = (d[item.own_key.."counter"] or 0) + 1
		local cnt = item.counter + (player:GetCollectibleNum(item.entity) - 1) * 5
		if d[item.own_key.."counter"] % cnt == 1 or item.should_change_now then
			local config = Isaac.GetItemConfig()
			for i = 0,3 do
				local card = player:GetCard(i)
				local cardinfo = config:GetCard(card)
				if card and card > 0 then
					local id = tostring(cardinfo.CardType)
					local rng = player:GetCardRNG(card)
					if Game():IsGreedMode() then id = "g_"..id end
					local tg = item.cards[id] or item.cards["1"]
					local rnd = rng:RandomInt(#tg) + 1
					player:SetCard(i,tg[rnd])
				end
			end
			d[item.own_key.."counter"] = 2
			item.should_change_now = nil
		end
	end
end,
})

return item