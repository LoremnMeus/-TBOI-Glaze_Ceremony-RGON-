local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Isaacs_Tear_holder_",
	entity = CollectibleType.COLLECTIBLE_ISAACS_TEARS,
}

function item.add_tear(player,val)
	for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET do
		if (player:GetActiveItem(slot) == item.entity) then
			local mx = 6
			if player:HasCollectible(63) then mx = 12 end
			if player:GetActiveCharge(slot) + player:GetBatteryCharge(slot) < mx then
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_ITEMRECHARGE,1,1,false,0,2)
				player:SetActiveCharge(player:GetActiveCharge(slot) + player:GetBatteryCharge(slot) + (val or 1), slot)
			end
		end
	end
end

return item