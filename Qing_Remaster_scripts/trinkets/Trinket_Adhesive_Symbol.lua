local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Trinkets.Adhesive_Symbol,
	own_key = "Trinkets_Adhesive_Symbol_",
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_CHANGE_BASIC, params = nil,
Function = function(_,player,changetype,count)
	if changetype == "bk_heart" and count < 0 then
		if player:GetTrinketMultiplier(item.entity) > 0 then
			local mul = player:GetTrinketMultiplier(item.entity) * 2
			player:AddMaxHearts(mul)
		end
	end
end,
})

return item