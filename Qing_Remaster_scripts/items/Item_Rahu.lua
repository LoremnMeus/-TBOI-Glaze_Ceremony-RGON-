-- 罗喉星 Rahu：外侧逆行 · 吸收
local enums = require("Qing_Remaster_scripts.core.enums")
local runtime = require("Qing_Remaster_scripts.items.celestial.runtime")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Rahu,
	own_key = "Item_Rahu_",
}

function item.get_runtime()
	return runtime
end

return item
