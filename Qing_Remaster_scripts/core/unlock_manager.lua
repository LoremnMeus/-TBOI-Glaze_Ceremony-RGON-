local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local ModConfig = require("Qing_Remaster_scripts.others.Mod_Config_Menu_holder")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Achievement_Display_holder = require("Qing_Remaster_scripts.others.Achievement_Display_holder")
local unlock_board = require("Qing_Remaster_scripts.data.unlock_board")
local CompletionMarks = require("Qing_Remaster_scripts.core.completion_marks_manager")
local players = enums.Players
local items = enums.Items
local trinkets = enums.Trinkets
local cards = enums.Cards

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	Unlocker = {
		["Item"] = {
			[items.Darkness] = {Unlock = "MegaSatan",name = "wq",},
			[items.Touchstone] = {Unlock = "Lamb",name = "wq",},
			[items.Glaze_Mushroom] = {Unlock = "BlueBaby",name = "wq"},
			[items.Tech_9] = {Unlock = "Hush",name = "wq",},
			[items.Assassin_s_Eye] = {Unlock = "BossRush",name = "wq",},
			[items.Mental_Hypnosis] = {Unlock = "Delirium",name = "wq",},
			[items.Pageant_Cross_dresser] = {Unlock = "Isaac",name = "wq"},
			[items.More_Options___] = {Unlock = "Satan",name = "wq"},
			[items.Ingestion_to_Night] = {Unlock = "Beast",name = "wq"},
			[items.Black_Map] = {Unlock = "Mother",name = "wq",},
			[items.Gold_Rush] = {Unlock = "GreedMode",name = "wq",},
			
			--[items.Air_Terror] = {Unlock = "MegaSatan",name = "Spwq",},
			[items.Air_Flight] = {Unlock = "Lamb",name = "Spwq"},
			[items.The_Watcher] = {Unlock = "BlueBaby",name = "Spwq"},
			[items.Giant_Punch] = {Unlock = "BossRush",name = "Spwq"},
			[items.Memory] = {Unlock = "Delirium",name = "Spwq"},
			[items.Field] = {Unlock = "Isaac",name = "Spwq"},
			[items.Little_Duck] = {Unlock = "Satan",name = "wq"},
			[items.My_Best_Friend] = {Unlock = "Beast",name = "Spwq"},
			[items.Super_Bombs] = {Unlock = "Mother",name = "Spwq"},
			[items.Fate_s_Draw] = {Unlock = "GreedMode",name = "Spwq"},
			[items.Brimstream] = {Unlock = "GreedMode",name = "Spwq",Hard = true,},
			[items.Blaststone] = {Unlock = "GreedMode",name = "Spwq",Hard = true,},
			
			--[items.It_s_a_trick] = {Special = function() return save.UnlockData.Glaze["Lost"].Unlock == true end,},
				
			--[items.Crown_of_the_glaze] = {Special = function() return save.UnlockData.Others["Crown_of_the_Glaze"].Unlock == true end,},
			--[[
			[items.Tianyi] = {Unlock = "Satan",name = "Spwq"},
			[items.Colorblindness] = {Unlock = "Satan",name = "Spwq"},
			[items.Devil_s_Heart] = {Unlock = "Satan",name = "Spwq"},
			[items.Suture_Needle] = {Unlock = "Satan",name = "Spwq"},
			[items.D773] = {Unlock = "Satan",name = "Spwq"},
			[items.Hyper_Velocity] = {Unlock = "Satan",name = "Spwq"},
			[items.Wavering_Eyes] = {Unlock = "Satan",name = "Spwq"},
			[items.Pendulum_Star] = {Unlock = "Satan",name = "Spwq"},
			[items.Aphasia] = {Unlock = "Satan",name = "Spwq"},
			[items.Nazca] = {Unlock = "Satan",name = "Spwq"},
			[items.Cloundy] = {Unlock = "Satan",name = "Spwq"},
			--]]
			
			--[items.Book_of_Thoth] = {Special = function() return save.UnlockData.Others["Thoth"].Unlock == true end},
			--[items.Book_of_The_Law] = {Special = function() return save.UnlockData.Others["Law"].Unlock == true end},
			--[items.Book_of_Vision] = {Special = function() return save.UnlockData.Others["Vision"].Unlock == true end},
			--[items.Book_of_Voice] = {Special = function() return save.UnlockData.Others["Voice"].Unlock == true end},
			--[items.Book_of_Future] = {Special = function() return save.UnlockData.Others["Future"].Unlock == true end},
			
			[items.My_Hat] = {Special = function() return save.UnlockData.Others["Ending1"].Unlock == true end,},
			[items.My_Emblem] = {Special = function() return save.UnlockData.Others["Ending1"].Unlock == true end,},
		},
		["Trinket"] = {
			
		},
		["Card"] = {
			--[cards.Glaze_dice_shard] = {rune = false,tarot = false,special_transform = 49,Special = function() return save.UnlockData.Glaze["Isaac"].Unlock == true end,},
			--[cards.Qing_s_Soul] = {Unlock = "Hush",name = "Spwq",rune = true,tarot = false,},
			--[cards.Round_trip_Rail_Ticket] = {Special = function() return save.UnlockData.Others["Crushed"].Unlock == true end,rune = false,tarot = false,},
			[cards.One_way_Rail_Ticket] = {Special = function() return false end,rune = false,tarot = false,},		--不会直接出现。
		},
		["Pickup"] = {
		--[[
			["Glaze_Battery"] = function() return save.UnlockData.Glaze.Bethany.Unlock end,
			["Glaze_Bomb"] = function()	return save.UnlockData.Glaze.Eve.Unlock	end,
			["Glaze_Chest"] = function() return save.UnlockData.Glaze.Samson.Unlock end,
			["Glaze_Coin"] = function() return save.UnlockData.Glaze.Keeper.Unlock end,
			["Glaze_Enemy"] = function() return save.UnlockData.Glaze.Judas.Unlock end,
			["Glaze_Grabbag"] = function() return save.UnlockData.Glaze.Eden.Unlock end,
			["Glaze_Heart"] = function() return save.UnlockData.Glaze.Maggy.Unlock end,
			["Glaze_Key"] = function() return save.UnlockData.Glaze.Cain.Unlock end,
			["Glaze_Poop"] = function() return save.UnlockData.Glaze.BlueBaby.Unlock end,
			["Glaze_Spider"] = function() return save.UnlockData.Glaze.Apollyon.Unlock end,
		--]]
		},
		["Thread"] = {
			["Glaze"] = {Special = function() return save.UnlockData.Others["Ending1"].Unlock == true end,},
			["Coin"] = {Special = function() return save.UnlockData.Others["Ending1"].Unlock == true end,},
			["Lava"] = {Special = function() return save.UnlockData.Others["Ending1"].Unlock == true end,},
			["Stone"] = {Special = function() return save.UnlockData.Others["Ending1"].Unlock == true end,},
			["Meat"] = {Special = function() return save.UnlockData.Others["Ending1"].Unlock == true end,},
			["Wind"] = {Special = function() return save.UnlockData.Others["Ending1"].Unlock == true end,},
			["Blood"] = {Special = function() return save.UnlockData.Others["Ending1"].Unlock == true end,},
			["Shadoll"] = {Special = function() return save.UnlockData.Others["Ending1"].Unlock == true end,},
		},
	},
}

local board_requirements = {Item = {},Trinket = {},Card = {},Pickup = {},Player = {}}

local function add_board_requirement(entry,category,mark,field)
	local content_type = entry.content_type or "Item"
	local key
	if content_type == "Item" then
		-- enum_key 存在时只用运行时 CollectibleType。XML id 不是 CollectibleType；
		-- Zeis D 系停用后 GetItemIdByName 为 -1，禁止回退到 144 等原版 id。
		if entry.enum_key then key = items[entry.enum_key]
		else key = tonumber(entry.id) end
		if type(key) ~= "number" or key <= 0 then key = nil end
	elseif content_type == "Trinket" then
		key = trinkets[entry.enum_key]
		if type(key) ~= "number" or key <= 0 then key = nil end
	elseif content_type == "Card" then
		key = cards[entry.enum_key]
		if type(key) ~= "number" or key <= 0 then key = nil end
	elseif content_type == "Pickup" or content_type == "Player" then key = entry.enum_key end
	if key then board_requirements[content_type][key] = {category = category,mark = mark,field = field} end
end

for category,columns in pairs(unlock_board.character_unlocks or {}) do
	for column,entries in pairs(columns) do
		local mark = column == "Greedier" and "GreedMode" or column
		local field = column == "Greedier" and "Hard" or "Unlock"
		for _,entry in ipairs(entries) do add_board_requirement(entry,category,mark,field) end
	end
end
for category,columns in pairs(unlock_board.special_unlocks or {}) do
	for mark,entries in pairs(columns) do
		local record = save.UnlockData and save.UnlockData[category] and save.UnlockData[category][mark]
		if record then
			for _,entry in ipairs(entries) do add_board_requirement(entry,category,mark,"Unlock") end
		end
	end
end
local reverse_rows = {Magdalene = "Maggy",JacobEsau = "Jacob_and_Esau",Jacob = "Jacob_and_Esau"}
for row,columns in pairs(unlock_board.boss_unlocks or {}) do
	local tainted = string.sub(row,-2) == "_B"
	local base_row = tainted and string.sub(row,1,-3) or row
	local mark = reverse_rows[base_row] or base_row
	for column,entries in pairs(columns) do
		local known_boss = string.sub(column,1,5) == "Glaze" or string.sub(column,1,4) == "Zeis"
		local category = string.sub(column,1,4) == "Zeis" and "BossZeis" or known_boss and "Glaze" or "BossBoard_"..column
		local hard = known_boss and string.sub(column,-4) == "Hard"
		local field = known_boss and (tainted and (hard and "TaintedHard" or "Tainted") or (hard and "Hard" or "Unlock")) or "Unlock"
		local requirement_mark = known_boss and mark or row
		for _,entry in ipairs(entries) do add_board_requirement(entry,category,requirement_mark,field) end
	end
end

local function board_requirement_unlocked(content_type,key)
	local requirement = board_requirements[content_type] and board_requirements[content_type][key]
	if not requirement then return true end
	if CompletionMarks and CompletionMarks.is_requirement_unlocked then
		return CompletionMarks.is_requirement_unlocked(requirement.category,requirement.mark,requirement.field)
	end
	local record = save.UnlockData and save.UnlockData[requirement.category] and save.UnlockData[requirement.category][requirement.mark]
	return record and record[requirement.field] == true or false
end

function item.should_any_be_done(tp,id,desc,checkout)
	local gating_key = tp == "Trinket" and "Achievement_trinket_gating" or tp == "Card" and "Achievement_card_gating" or tp == "Pickup" and "Achievement_pickup_gating" or nil
	if gating_key and ModConfig.get_setting(gating_key) == true then
		local key = tp == "Card" and id or tostring(id)
		if not board_requirement_unlocked(tp,key) then return false end
	end
	desc = desc or (item.Unlocker[tp] or {})[id]
	local ret = false
	if desc == nil then ret = true 
	else for i = 1,1 do
		if type(desc) == "table" then 
			if desc.Special then ret = desc.Special() break end
			local name = desc.name or "wq"
			if CompletionMarks and CompletionMarks.is_requirement_unlocked then
				ret = CompletionMarks.is_requirement_unlocked(name,desc.Unlock,desc.Hard and "Hard" or "Unlock")
			elseif desc.Hard then ret = save.UnlockData[name][desc.Unlock].Hard
			else ret = save.UnlockData[name][desc.Unlock].Unlock end
		else
			ret = auxi.check_if_any(desc)
		end
	end end
	if checkout and ModConfig.ModConfigSettings[checkout] ~= true then ret = false end
	--print("Asked:"..tp.." "..id.." "..tostring(ret))
	return ret
end

function item.unlock_achievement(TargetTab,val,params)
	if ModConfig.ModConfigSettings.Achievement_allow then
		if TargetTab and val and TargetTab[val] ~= true then 
			params = params or {}
			if params.Achievement_page then Achievement_Display_holder.PlayAchievement(params.Achievement_page) end
			if params.Achievement_name then end
			TargetTab[val] = true
		end
	end
end

local function achievement_pool_states()
	local states = {}
	for id,_ in pairs(board_requirements.Item) do states[id] = board_requirement_unlocked("Item",id) end
	return states
end

local function configure_card_availability()
	if not REPENTOGON then return end
	for id,_ in pairs(board_requirements.Card) do
		local card_id = id
		local config = Isaac.GetItemConfig():GetCard(card_id)
		if config and config.SetAvailabilityCondition then
			config:SetAvailabilityCondition(function()
				if ModConfig.get_setting("Achievement_card_gating") ~= true then return true end
				return board_requirement_unlocked("Card",card_id)
			end)
		end
	end
end

local function apply_item_pool_options()
	local pool = Game():GetItemPool()
	if ModConfig.ModConfigSettings.Items_allow ~= true then
		for _,id in pairs(enums.Items) do
			if type(id) == "number" and id > 0 then pool:RemoveCollectible(id) end
		end
	elseif ModConfig.ModConfigSettings.Achievement_pool_gating == true then
		for id,unlocked in pairs(achievement_pool_states()) do
			if not unlocked then pool:RemoveCollectible(id) end
		end
	end
	if pool.RemoveTrinket then
		for _,id in pairs(enums.Trinkets) do
			if type(id) == "number" and id > 0 then
				if ModConfig.get_setting("Trinkets_allow") ~= true
				or (ModConfig.get_setting("Achievement_trinket_gating") == true and not board_requirement_unlocked("Trinket",id)) then
					pool:RemoveTrinket(id)
				end
			end
		end
	end
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	configure_card_availability()
	if not continue then apply_item_pool_options() end
end,
})

return item
