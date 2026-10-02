local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local dropping_holder = require("Qing_Remaster_scripts.others.Dropping_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local Achievement_Display_holder = require("Qing_Remaster_scripts.others.Achievement_Display_holder")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder") 

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Hermit,
	own_key = "Thoth_cd9_Her_",
}

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	if continue then
	else
		save.elses[item.own_key.."effect"] = {}
	end
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_LOSE_COLLECTIBLE, params = nil,
Function = function(_,player,col,num,curNum)
	local d = player:GetData()
	local idx = d.__Index
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	save.elses[item.own_key.."effect"][idx] = save.elses[item.own_key.."effect"][idx] or {}
	save.elses[item.own_key.."effect"][idx][col] = true		--(save.elses[item.own_key.."effect"][idx][col] or 0) + 1
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_,cardtype,player,useFlags)
	local room = Game():GetRoom()
	local d = player:GetData()
	local idx = d.__Index
	local rng = player:GetCardRNG(item.entity)
	rng = auxi.rng_for_sake(rng)
	
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
	else
		local tbl = {}
		local act_tbl = {}
		local config = Isaac:GetItemConfig()
		save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
		save.elses[item.own_key.."effect"][idx] = save.elses[item.own_key.."effect"][idx] or {}
		for u,v in pairs(save.elses[item.own_key.."effect"][idx]) do
			if tonumber(u) then
				local collectibleinfo = config:GetCollectible(tonumber(u))
				if collectibleinfo and collectibleinfo.Tags & ItemConfig.TAG_QUEST ~= ItemConfig.TAG_QUEST then
					if collectibleinfo.Type == ItemType.ITEM_ACTIVE then
						table.insert(act_tbl,#act_tbl + 1,{id = u,})
					else
						table.insert(tbl,#tbl + 1,{id = u,})
					end
				end
			end
		end
		tbl = auxi.randomTable(tbl,rng)
		act_tbl = auxi.randomTable(act_tbl,rng)
		for i = 1,3 do table.insert(act_tbl,#act_tbl + 1,{id = 36,touch = true,}) end
		for i = 1,#act_tbl do table.insert(tbl,#tbl + 1,act_tbl[i]) end
		local q = unique_holder.with_missing(33, function()
			local q = Isaac.Spawn(5,100,tonumber(tbl[1].id) or 36,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
			auxi.self_morph(q,{5,100,tonumber(tbl[1].id) or 36,})
			return q
		end)
		if (tonumber(tbl[1].id) or 36) == 36 then Game():Fart(q.Position,64,player,1,0)
		else sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBSUP,1,1,false,0,2) end
		if tbl[1].touch then q.Touched = true end
		table.remove(tbl,1)
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
			local ndx = option_index_holder.find_a_new_index()
			q.OptionsPickupIndex = ndx
			for i = 1,2 do
				local q2 = unique_holder.with_missing(33, function()
					local q2 = Isaac.Spawn(5,100,tonumber(tbl[1].id) or 36,room:FindFreePickupSpawnPosition(player.Position,10,true),Vector(0,0),player):ToPickup()
					auxi.self_morph(q2,{5,100,tonumber(tbl[1].id) or 36,})
					return q2
				end)
				q2.OptionsPickupIndex = ndx
				if tbl[1].touch then q2.Touched = true end
				if (tonumber(tbl[1].id) or 36) == 36 then Game():Fart(q.Position,64,player,1,0)
				else sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBSUP,1,1,false,0,2) end
				table.remove(tbl,1)
			end
		end
	end
end,
})

function item.has_recoverable_lost_record(player)
	if not player then return false end
	local idx = player:GetData().__Index
	save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] or {}
	local record = save.elses[item.own_key.."effect"][idx] or {}
	local config = Isaac:GetItemConfig()
	for u,v in pairs(record) do
		if tonumber(u) then
			local collectibleinfo = config:GetCollectible(tonumber(u))
			if collectibleinfo and collectibleinfo.Tags & ItemConfig.TAG_QUEST ~= ItemConfig.TAG_QUEST then
				return true
			end
		end
	end
	return false
end

if EID then
	EID:addDescriptionModifier("qing_card_hermit_lost_fallback"..tostring(item.entity), function(desc)
		return desc.ObjType == 5 and desc.ObjVariant == 300 and desc.ObjSubType == item.entity
	end, function(desc)
		local player = (EID and EID.player) or Game():GetPlayer(0)
		if item.has_recoverable_lost_record(player) then
			return desc
		end
		local language = auxi.get_EID_language()
		if language == "zh_cn" then
			EID:appendToDescription(desc, "#若本局没有可恢复记录，生成 {{Collectible36}}")
		else
			EID:appendToDescription(desc, "#If none remain, spawns {{Collectible36}}")
		end
		return desc
	end)
end

return item
