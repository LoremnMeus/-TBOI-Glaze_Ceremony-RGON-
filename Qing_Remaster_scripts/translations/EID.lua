local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local item = {
	ToCall = {},
}

if EID then
local translations = include("Qing_Remaster_scripts.translations.translate")
local languages = {"en_us", "zh_cn"}

local s = Sprite()
s:Load("gfx/ui/EID/qing_player_icons.anm2", true)
EID:addIcon("Player"..enums.Players.wq, "Players", 0, 12, 12, -1, 1, s)
EID:addIcon("Player"..enums.Players.Spwq, "Players", 1, 12, 12, -1, 1, s)
EID:addIcon("Player"..enums.Players.Tecro, "Players", 2, 12, 12, -1, 1, s)
EID:addIcon("Player"..enums.Players.Anna, "Players", 3, 12, 12, 3, 1, s)
EID:addIcon("Player"..enums.Players.Zeistos, "Players", 4, 12, 12, -1, 1, s)
EID:addIcon("Player"..enums.Players.Tecrorun, "Players", 5, 12, 12, 3, 1, s)
EID:addIcon("Player"..enums.Players.annA, "Players", 6, 12, 12, 3, 1, s)

EID:addEntity(1000,enums.Entities.EID_Descriptier,0,"","",language)
EID:addEntity(1000,enums.Entities.S_Pentagram,0,"","",language)

local s = Sprite()
s:Load("gfx/ui/EID/other_icons.anm2",true)
EID:addIcon("Dullize", "icons", 1, 16, 16, 0, 1, s)

local item_buff_map = {
	["bookOfVirtuesWisps"] = "BookOfVirtues",
	["bookOfBelialBuffs"] = "BookOfBelial",
	["abyssSynergies"] = "AbyssSynic",
}
local pickup_buff_map = {
	["reverieSeijaBuffs"] = "SeijaBuff",
	["reverieSeijaNerfs"] = "SeijaNerf",
}

for _, u in ipairs(languages) do
	local EIDInfo = translations[u] or {}
	local languageCode = u
	for id, col in pairs(EIDInfo.Collectibles or {}) do
		if col.Description and col.Name then
			EID:addCollectible(id, col.Description, col.Name,languageCode)
		end
		for u,v in pairs(item_buff_map) do
			if (col[v] and EID.descriptions[languageCode][u]) then
				EID.descriptions[languageCode][u][id] = col[v]
			end
		end
		for u,v in pairs(pickup_buff_map) do
			if (col[v] and EID.descriptions[languageCode][u]) then
				EID.descriptions[languageCode][u]["100."..id] = col[v]
			end
		end
	end

	for id, trinket in pairs(EIDInfo.Trinkets or {}) do
		if trinket.Description and trinket.Name then
			EID:addTrinket(id, trinket.Description, trinket.Name,languageCode)
		end
		if trinket.goldenTrinket then EID.GoldenTrinketData[id] = trinket.goldenTrinket end
		if trinket.goldenTrinketEffects then EID.descriptions[languageCode].goldenTrinketEffects[id] = trinket.goldenTrinketEffects end
	end

	for id, trans in pairs(EIDInfo.CollectibleTransformations or {}) do
		EID:assignTransformation("collectible", id, trans,languageCode)
	end

	for id, br in pairs(EIDInfo.Birthrights or {}) do
		EID:addBirthright(id, br.Description, br.PlayerName,languageCode)
	end

	local s = Sprite()
	s:Load("gfx/ui/EID/qing_cardpill_icons2.anm2",true)
	EID:addIcon("ThothCard", "pickups", 0, 16, 16, 0, 1, s)
	EID:addIcon("ThothCard2", "pickups", 1, 16, 16, 0, 1, s)
	local cdsprite = Sprite()
	cdsprite:Load("gfx/ui/EID/qing_cardpill_icons.anm2",true)
	for id, cd in pairs(EIDInfo.Cards or {}) do
		if cd.Description and cd.Name then
			EID:addCard(id, cd.Description, cd.Name,languageCode)
		end
		if cd.tarotClothBuffs then
			EID.descriptions[languageCode].tarotClothBuffs[id] = cd.tarotClothBuffs
		end
		if cd.Frame then EID:addIcon("Card"..id, "Card", cd.Frame, 16, 16, 0, 1, cdsprite) end
	end

	for id, pk in pairs(EIDInfo.Pickups or {}) do
		EID:addEntity(5, pk.Variant, pk.SubType, pk.Name, pk.Description, languageCode)
		--EID.ObjectIcon["5".."."..tostring(pk.Variant).."."..tostring(pk.SubType)] = EID.ObjectIcon["5".."."..tostring(pk.Variant).."."..tostring(pk.SubType)] or EID.InlineIcons["Blank"]
	end
	--EID.ObjectIcon["5".."."..tostring(20).."."..tostring(4)] = EID.ObjectIcon["5".."."..tostring(20).."."..tostring(4)] or EID.InlineIcons["Blank"]
	if EIDInfo.Slots then
		for u, v in pairs(EIDInfo.Slots) do
			EID:addEntity(6, u, 0, v.Name, v.Description, languageCode)
		end
	end
	
	if EIDInfo.PlayerSync then
		local descriptions = EID.descriptions[languageCode]
		for id, info in pairs(EIDInfo.PlayerSync) do
			descriptions["PlayerSync_qing_"..tostring(id)] = {}
			for u,v in pairs(info) do
				descriptions["PlayerSync_qing_"..tostring(id)]["100."..u] = v.Description
			end
		end
		for id, info in pairs(EIDInfo.PlayerSyncTrinket or {}) do
			for u,v in pairs(info) do
				descriptions["PlayerSync_qing_"..tostring(id)]["350."..u] = v.Description
			end
		end
	end
	
	local challenges = EIDInfo.Challenges or EIDInfo.Challanges
	if challenges then
		table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
		Function = function(_)
			if u == auxi.get_EID_language() then
				local info = challenges[Game().Challenge]
				if info then 
					delay_buffer.addeffe(function(params)
						local q = Isaac.Spawn(1000,enums.Entities.EID_Descriptier,0,Game():GetRoom():GetCenterPos(),Vector(0,0),nil)
						local d = q:GetData()
						d.EID_Description = {Name = info.Name,Description = info.Description,}
					end,{},5)
				end
			end
		end,
		})
	end
end

for u,v in pairs(enums.Players) do
	EID:addDescriptionModifier("qing_player_sync"..tostring(v), function(desc) local ret = auxi.have_player(v) return ret end, function(desc)
        local id = desc.ObjType
        local vr = desc.ObjVariant
        local st = desc.ObjSubType
        if (id == 5) then
            local info = EID:getDescriptionEntry("PlayerSync_qing_"..tostring(v), tostring(vr).."."..tostring(st))
            if (info) then
                info = "#"..info
                local repl = "#{{Player"..v.."}} "
                info = string.gsub(info, "#", repl)
                EID:appendToDescription(desc, info)
            end
        end
        return desc
	end)
end

end

return item
