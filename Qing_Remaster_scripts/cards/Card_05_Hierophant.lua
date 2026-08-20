local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local dropping_holder = require("Qing_Remaster_scripts.others.Dropping_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local Achievement_Display_holder = require("Qing_Remaster_scripts.others.Achievement_Display_holder")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Hierophant,
	own_key = "Thoth_cd5_Hie_",
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_ROOM, params = nil,
Function = function(_)
	save.elses[item.own_key.."effect"] = {}
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.MC_EVALUATE_IMITATE_ITEM, params = nil,
Function = function(_,player,colid,value)
	local d = player:GetData()
	local idx = d.__Index
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	if save.elses[item.own_key.."effect"][idx] then
		value[533] = (value[533] or 0) + 1
		value[182] = (value[182] or 0) + 1
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
			local q1 = player:AddItemWisp(533,player.Position,true)
			local q2 = player:AddItemWisp(182,player.Position,true)
			local q3 = player:AddItemWisp(184,player.Position,true)
			q1.HitPoints = 1
			q2.HitPoints = 1
			q3.HitPoints = 1
		else
			save.elses[item.own_key.."effect"][idx] = true
			Imitate_item_holder.Evaluate_Imitate_Items(player)
		end
	end
end,
})

do
	local temp_hud = require("Qing_Remaster_scripts.callbacks.temp_item_hud_holder")
	-- 教皇卡临时效果：白色 Colorize
	item.temp_hud_color = Color(1,1,1,0.58,0,0,0,2.4,2.4,2.4,1)
	temp_hud.register_provider(function(player)
		local idx = player:GetData() and player:GetData().__Index
		if not idx then return end
		local bag = save.elses[item.own_key.."effect"]
		if not (bag and bag[idx]) then return end
		return {
			[533] = 1, -- Haemolacria
			[182] = 1, -- Sacred Heart
		}
	end,{
		color = item.temp_hud_color,
		exclusive = true,
		source_card = item.entity,
	})
end

return item