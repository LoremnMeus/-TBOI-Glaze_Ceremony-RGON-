local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local card_04_Emperor = require("Qing_Remaster_scripts.cards.Card_04_Emperor")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Trinkets.Torn_Emperor,
	own_key = "Trinkets_Torn_Emperor_",
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	local player = auxi.have_player_has_trinket(item.entity)
	if player and Game():GetRoom():IsFirstVisit() then
		local rng = player:GetTrinketRNG(item.entity)
		local succ = 0
		local cnt = auxi.get_player_have_trinket_num(item.entity)
		for i = 1,cnt do if rng:RandomInt(100) > 75 then succ = succ + 1 end end
		if succ > 0 then
			card_04_Emperor.open_doors(player,{thre = 900,special = succ,DontClose = true,})
		end
	end
end,
})

return item