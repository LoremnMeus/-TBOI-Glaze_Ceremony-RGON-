-- Suture Needle active entry (Runtime Stitch consumer).
-- Does not own stitch profiles, selection, friend AI, or rendering.

local enums = require("Qing_Remaster_scripts.core.enums")
local gameplay = require("Qing_Remaster_scripts.others.runtime_stitch_gameplay")

local item = {
	ToCall = {},
	entity = enums.Items.Suture_Needle,
	own_key = "Item_Suture_Needle_",
}

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_USE_ITEM,
	params = item.entity,
	Function = function(_, _colid, rng, player, useFlags, activeSlot)
		if useFlags & UseFlag.USE_CARBATTERY ~= 0 then
			return { Discharge = false, Remove = false, ShowAnim = false }
		end
		return gameplay.begin_selection(player, rng, activeSlot)
	end,
})

return item
