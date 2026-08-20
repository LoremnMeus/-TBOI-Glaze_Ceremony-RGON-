local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Habit_holder_",
	entity = CollectibleType.COLLECTIBLE_HABIT,
	Addlist = {
	},
}

function item.Additem(id,val)
	item.Addlist[id] = val
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = 1,
Function = function(_,ent,amt,flag,source,cooldown)
	local player = ent:ToPlayer()
	if player and auxi.has_have_coll(player,item.entity) then
		for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET do 
			if player:GetActiveItem(slot) then
				local info = item.Addlist[player:GetActiveItem(slot)]
				if type(info) == "number" then 
					while (auxi.should_real_charge(player,slot) and info > 0) do
						player:SetActiveCharge(player:GetActiveCharge(i) + player:GetBatteryCharge(i) + 1,i)
						info = info - 1
					end
				else auxi.check_if_any(info,player) end
			end
		end
	end
end,
})

return item