local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	pre_myToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "Reverie_holder_",
}

if Reverie then

local Items = enums.Items

local Hunger = Reverie.Collectibles.Hunger		--Reverie.Require("scripts/items/th17-5/hunger")
Hunger:SetCollectibleHunger(enums.Items.Glaze_Mushroom,2)
Hunger:SetCollectibleHunger(enums.Items.Tiramisu,2)
Hunger:SetCollectibleHunger(enums.Items.Hunger_Burger,6)

local DFlip = Reverie.Collectibles.DFlip		--Reverie.Require("scripts/items/th14/d_flip")
DFlip:AddFixedPair(5,100,enums.Items.Touchstone,5,100,enums.Items.Chiastolite)
DFlip:AddFixedPair(5,100,enums.Items.Assassin_s_Eye,5,100,enums.Items.Seeker_s_Eye)
DFlip:AddFixedPair(5,100,enums.Items.Memory,5,100,enums.Items.Hypermnesia)
DFlip:AddFixedPair(5,100,enums.Items.Brimstream,5,100,enums.Items.Blaststone)
DFlip:AddFixedPair(5,100,enums.Items.Cloundy,5,100,enums.Items.Day_Dreamer)
DFlip:AddFixedPair(5,100,enums.Items.Book_of_How_to_Fly,5,100,CollectibleType.COLLECTIBLE_HOW_TO_JUMP)
DFlip:AddFixedPair(5,100,enums.Items.Pageant_Cross_dresser,5,100,CollectibleType.COLLECTIBLE_PAGEANT_BOY)
DFlip:AddFixedPair(5,100,enums.Items.Book_of_Voice,5,100,enums.Items.Book_of_Vision)
DFlip:AddFixedPair(5,100,enums.Items.Book_of_Thoth,5,100,enums.Items.Book_of_Rune)
DFlip:AddFixedPair(5,100,enums.Items.Heart_Change,5,100,enums.Items.Disequilibrium)
DFlip:AddFixedPair(5,100,enums.Items.Tzolkin,5,100,enums.Items.Nazca)
DFlip:AddFixedPair(5,100,enums.Items.Philosopher_s_stone,5,100,enums.Items.Alchemy_Pot)
DFlip:AddFixedPair(5,100,enums.Items.Suture_Needle,5,100,enums.Items.The_Suture_Needle)
DFlip:AddFixedPair(5,100,enums.Items.Devil_s_Heart,5,100,enums.Items.Pathetique)
DFlip:AddFixedPair(5,100,enums.Items.Evil_Intervention,5,100,CollectibleType.COLLECTIBLE_DIVINE_INTERVENTION)

DFlip:AddFixedPair(5,350,enums.Trinkets.Torn_Moon_,5,350,TrinketType.TRINKET_FRAGMENTED_CARD)

table.insert(item.pre_myToCall,#item.pre_myToCall + 1,{CallBack = enums.Callbacks.PRE_DESCRIPT_ITEM, params = nil,priority = 10,
Function = function(_,player,tp,id,value)
	local language = Options.Language
	local translationinfo = Reverie.Translations[language] or {}
	if tp == "Trinket" then
		target = translationinfo.Trinkets
	elseif tp == "Item" then
		target = translationinfo.Collectibles
	elseif tp == "Card" then
		target = translationinfo.Cards
	elseif tp == "Pill" then
		target = translationinfo.Pills
	elseif tp == "UnItem" then
		target = translationinfo.Collectibles
		ignore_changes = true
	elseif tp == "Player" then
		target = translationinfo.Players
		ignore_changes = true
	end
	if target == nil then return nil end
	local info = target[id]
	if info then
		local name = info.Name
		local des = info.Description
		if type(name) == "function" then name = name(player) end
		if type(des) == "function" then des = des(player) end
		return {Name = name,Description = des,}
	end
	if (tp == "Item" or tp == "UnItem") and id == 619 then
		local playerinfo = translationinfo.Players[player:GetPlayerType()]
		if playerinfo then return {Name = value.Name,Description = playerinfo.Birthright,} end
	end
	return nil
end,
})

local seija = Isaac.GetPlayerTypeByName("Seija",false)
local seija_b = Isaac.GetPlayerTypeByName("Tainted Seija",true)
item.Special_Des = {
	[seija] = {
		["zh"] = {
			["Item"] = {
				[Items.Air_Flight] = {Name = "空行零号-试做版",Description = "滴..注入失败..",},
				[Items.The_Watcher] = {Name = "监视",Description = "威慑纪元",},
				[Items.Alchemy_Pot] = {Name = "炼金术的掌中锅",Description = "结果竟是大失败！",},
				[Items.Crown_of_the_glaze] = {Name = "琉璃的冠冕",Description = "破碎之前，你即为王",},
				[Items.Colorblindness] = {Name = "傲慢或是偏见",Description = "即使，二者兼有",},
				[Items.Suture_Needle] = {Name = "缝合针",Description = "线不会自己断！",},
				[Items.More_Options___] = {Name = "更多更多选择！",Description = "奇货可居",},
				[Items.Devil_s_Heart] = {Name = "恶魔的愚钝",Description = "免费永生",},
				[Items.Book_of_Future] = {Name = "未来之书",Description = "未来已定",},
				[Items.Book_of_Thoth] = {Name = "透特之书",Description = "愿塔罗蒙蔽你！",},
				[Items.Book_of_Voice] = {Name = "假象之书",Description = "我已无欲无求",},
				[Items.Nazca] = {Name = "纳兹卡线条",Description = "一笔一画",},
				[Items.Cloundy] = {Name = "超级云玩大佬",Description = "高贵的云玩家可是四级道具！",},
				[Items.Squiresaga] = {Name = "妖刻 · 白隙",Description = "这刀岂是你配用的！",},
				[Items.Spectralsword] = {Name = "妖刀 · 逢魔",Description = "铂金吞噬者已苏醒！",},
				[Items.Moment] = {Name = "妖星 · 一瞬",Description = "物理学不存在了？",},
				[Items.Lofty] = {Name = "崇高之阵",Description = "好好珍惜它！",},
				[Items.Gospel] = {Name = "福音",Description = "黄昏的神国惩戒叛逆的罪人",},
				[Items.Day_Dreamer] = {Name = "白日做梦",Description = "各有所爱",},
				[Items.Philosopher_s_stone] = {Name = "闲者之屎",Description = "劫座",},
				[Items.Cheater_s_Blessing] = {Name = "作弊者的诅咒",Description = "再练上几年吧！",},
				[Items.Book_of_Rune] = {Name = "符文之书",Description = "好死！",},
				[Items.Pathetique] = {Name = "欢悦",Description = "我好开心！",},
				[Items.Dark_Mysticism] = {Name = "暗黑奥术学",Description = "SAN值归零",},
				[Items.The_Suture_Needle] = {Name = "新式缝合针",Description = "更痛了...",},
				[Items.Paranoia] = {Name = "妄想症",Description = "他疯了",},
				[Items.Cursed_Mask] = {Name = "诅咒面具",Description = "还是好晕",},
				[Items.Nihilistic_Artificial_Eye] = {Name = "虚无真眼",Description = "转转转！",},
				[Items.Subera_Light] = {Name = "微型炬火模块",Description = "瞄准！",},
				[Items.Phantom_Crown] = {Name = "幻像冠冕",Description = "灵力渐衰",},
				[Items.Shangrila] = {Name = "香格里拉",Description = "放逐...",},
				[Items.Hunger_Burger] = {Name = "邪魔典堡",Description = "好吃！",},
				[Items.Charon_s_Sign] = {Name = "卡戎之印",Description = "黑暗吞没了我",},
			},
		},
		["en"] = {
			["Item"] = {
			},
		},
	},
}
item.Special_Des[seija_b] = auxi.deepCopy(item.Special_Des[seija])

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_DESCRIPT_ITEM, params = nil,
Function = function(_,player,tp,id,value)
	if item.Special_Des[player:GetPlayerType()] then
		local ret = nil
		local language = Options.Language
		local infos = (item.Special_Des[player:GetPlayerType()][language] or {})[tp]
		if infos == nil then return end
		local info = infos[id]
		if info == nil then return end
		ret = {Name = info.Name or value.Name,Description = info.Description or value.Description,}
		return ret
	end
end,
})
	
end

return item