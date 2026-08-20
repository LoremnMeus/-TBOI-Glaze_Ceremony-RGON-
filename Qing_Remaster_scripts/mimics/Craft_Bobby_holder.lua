-- 兼容入口：第一批泪弹宝宝已迁至 Craft_Tear_Babies_holder
local Tear_Babies = require("Qing_Remaster_scripts.mimics.Craft_Tear_Babies_holder")
local Craft_Familiar_holder = require("Qing_Remaster_scripts.mimics.Craft_Familiar_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "Craft_Bobby_holder_",
}

function item.sync_air_flight(air, player, profile)
	return Craft_Familiar_holder.sync_air_flight(air, player, profile)
end

function item.release_for_air(air)
	return Craft_Familiar_holder.release_for_air(air)
end

-- 防止未引用被优化掉；确保 adapter 已注册
item._tear_babies = Tear_Babies

return item
