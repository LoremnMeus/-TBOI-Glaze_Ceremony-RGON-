local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Sting_r,
	own_key = "Thoth_cd5r_Sti_",
}

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	local rng = player:GetCardRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local damage = 10
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then damage = 20 end
		item.kill_it(damage)
		player:TakeDamage(1,DamageFlag.DAMAGE_NO_PENALTIES | DamageFlag.DAMAGE_RED_HEARTS | DamageFlag.DAMAGE_NOKILL,EntityRef(player),30)
	end
end,
})

function item.kill_it(damage)
	local tgs = auxi.getenemies()
	for u,v in pairs(tgs) do 
		v:TakeDamage(damage,0,EntityRef(player),0) 
	end
	delay_buffer.addeffe(function(params)
		for u,v in pairs(tgs) do 
			if v:IsDead() then item.kill_it(damage * 2) break end
		end
	end,{},1)
end

return item