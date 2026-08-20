local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local ModConfig = require("Qing_Remaster_scripts.others.Mod_Config_Menu_holder")
local player_Tecro = require("Qing_Remaster_scripts.player.player_Tecro")

local item = {
	entity = enums.Cards.Tecro_s_Soul,
	own_key = "sins_Tecro_s_Soul_",
	ToCall = {},
}

function item.fire_spears(player)
	for i = 1,8 do
		local q = player_Tecro.fire_birth_right_spear(player,player.Position,auxi.get_by_rotate(nil,i * 360/8),{list = auxi.get_Tecro_list(player),})
		q:GetData().should_not_reload = true
		q:GetData().Tecro_Ignore_fire = true
		q:GetData().Tecro_damage_rate = 1.5
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_,ent, amt, flag, source, cooldown)
	local player = ent:ToPlayer()
	if player then
		if auxi.has_card(player,item.entity) then item.fire_spears(player) end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,card,player,useflags)	
	item.fire_spears(player)
end,
})

return item