-- 计都星 Ketu：内侧顺行 · 赋予
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local runtime = require("Qing_Remaster_scripts.items.celestial.runtime")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Ketu,
	own_key = "Item_Ketu_",
	-- Shared runtime owns Update/Render/effects; this module is the collectible identity.
}

-- Seija nerf: top-track time acceleration (see celestial/runtime ketu_time).
auxi.add_to_seija(item.entity)

function item.get_runtime()
	return runtime
end

return item
