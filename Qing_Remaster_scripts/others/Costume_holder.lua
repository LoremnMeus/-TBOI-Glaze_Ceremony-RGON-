local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	CanAddi = {},
	CanAdd = {},
}

if true then
	local itemConfig = Isaac.GetItemConfig()
	local size = itemConfig:GetCollectibles().Size
	for i = 1,size do
		local collectible = itemConfig:GetCollectible(i)
		if (collectible and collectible.Costume.ID ~= -1 and (collectible.Type ~= ItemType.ITEM_ACTIVE or collectible.ID == 130 or collectible.ID == 181) and collectible.ID ~= 598) then		--冥王星太丑了。
			table.insert(item.CanAdd,#item.CanAdd + 1,i)
			item.CanAddi[i] = true
		end
	end
end


return item