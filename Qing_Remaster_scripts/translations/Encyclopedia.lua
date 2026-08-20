local enums = require("Qing_Remaster_scripts.core.enums")
local g = require("Qing_Remaster_scripts.core.globals")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local item = {
	ToCall = {},
}

if Encyclopedia then

local ModName = ___QING___.MOD.Name
local ClassName = string.lower(ModName)
local translations = include("Qing_Remaster_scripts.translations.translate")
local eidInfo = translations.en_us or {}
--local ItemPools = require("Qing_Remaster_scripts.translation.itempools")
local itemPools = {}
for id, col in pairs(eidInfo.Collectibles or {}) do
	if col.Description then
		Encyclopedia.AddItem{
			Class = ClassName,
			ID = id,
			WikiDesc = Encyclopedia.EIDtoWiki(col.Description),
			Pools = itemPools[id],
		}
		local configItem = Isaac.GetItemConfig():GetCollectible(id)
		if col.Hidden or (configItem and configItem.Hidden) then
			Encyclopedia.HideItem(id, string.lower(ClassName))
		end
	end
end
for id, col in pairs(eidInfo.Trinkets or {}) do
	if col.Description then
		Encyclopedia.AddTrinket{
			Class = ClassName,
			ID = id,
			WikiDesc = Encyclopedia.EIDtoWiki(col.Description),
		}
	end
end
for id, card in pairs(eidInfo.Cards or {}) do
	if card.Description then
		local info = {
			Class = ClassName,
			ID = id,
			WikiDesc = Encyclopedia.EIDtoWiki(card.Description),
		};
		if (card.Type== "Soul") then
			Encyclopedia.AddSoul(info);
		elseif (card.Type == "Rune") then
			Encyclopedia.AddRune(info);
		else
			Encyclopedia.AddCard(info);
		end
	end
end 
for id, v in pairs(eidInfo.Players or {}) do
	local info = {
		ModName = ModName,
		Class = ClassName,
		Name = v.Name,
		Description = v.Description,
		ID = id,
		--Sprite = Encyclopedia.RegisterSprite(v.Sprite, v.Animation, v.Frame or 0),
		WikiDesc = v.Wiki or {},
	}
	if (v.Tainted) then
		Encyclopedia.AddCharacterTainted(info);
	else
		Encyclopedia.AddCharacter(info);
	end
end
	
end

return item
