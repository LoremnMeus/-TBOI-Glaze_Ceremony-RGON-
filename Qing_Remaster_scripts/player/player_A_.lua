local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local ModConfig = require("Qing_Remaster_scripts.others.Mod_Config_Menu_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local Wavering_Eyes = require("Qing_Remaster_scripts.items.Item_Wavering_Eyes")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Players.Autio,
	Special_Des = {
		["zh"] = {
			["Item"] = {
			},
		},
		["en"] = {
			["Item"] = {
			},
		},
	},
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	if player:GetPlayerType() == item.entity then
		local d = player:GetData()
		local s = player:GetSprite()
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if player:GetPlayerType() == item.entity then
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_DESCRIPT_ITEM, params = nil,
Function = function(_,player,tp,id,value)
	if player:GetPlayerType() == item.entity then
		local ret = nil
		local language = Options.Language
		local infos = (item.Special_Des[language] or {})[tp]
		if infos == nil then return end
		local info = infos[id]
		if info == nil then return end
		ret = {Name = info.Name or value.Name,Description = info.Description or value.Description,}
		return ret
	end
end,
})


return item