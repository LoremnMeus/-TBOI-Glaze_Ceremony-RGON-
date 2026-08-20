local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local ModConfig = require("Qing_Remaster_scripts.others.Mod_Config_Menu_holder")
local Achievement_Display_holder = require("Qing_Remaster_scripts.others.Achievement_Display_holder")
local unlock_board = require("Qing_Remaster_scripts.data.unlock_board")
local item_progress = require("Qing_Remaster_scripts.data.item_progress")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")
local CompletionMarks = require("Qing_Remaster_scripts.core.completion_marks_manager")

local function registered_achievement_name(entry)
	return entry and entry.enum_key and ("QingRemaster_"..(entry.content_type or "Item").."_"..entry.enum_key) or nil
end

local function unlock_registered_achievement(entry,block_popup)
	if not REPENTOGON or not Isaac.GetAchievementIdByName or not Isaac.GetPersistentGameData then return false end
	local name = registered_achievement_name(entry)
	if not name then return false end
	local achievement_id = Isaac.GetAchievementIdByName(name)
	if not achievement_id or achievement_id < 0 then return false end
	local persistent = Isaac.GetPersistentGameData()
	local ok,unlocked = pcall(function() return persistent:TryUnlock(achievement_id,block_popup == true) end)
	return ok and unlocked == true
end

local function translated_reward_name(entry,content_type,id,config)
	local fallback = config and auxi.check_name_data(config.Name,entry.name) or entry.name or entry.enum_key or tostring(entry.id or "")
	if not config or not id then return fallback end
	-- 成就与 ImGui 展示使用 UnItem，取得静态译名但不应用局内道具造成的动态改名。
	local description_type = content_type == "Item" and "UnItem" or content_type == "Trinket" and "Trinket" or content_type == "Card" and "Card" or nil
	if not description_type then return fallback end
	local translated = item_displaying_holder.check_description(description_type,id,fallback,"",nil)
	return translated and translated.Name and translated.Name ~= "" and translated.Name or fallback
end

local function reward_info(entry)
	local content_type = entry.content_type or "Item"
	local id = content_type == "Card" and enums.Cards[entry.enum_key] or content_type == "Trinket" and enums.Trinkets[entry.enum_key] or content_type == "Item" and (enums.Items[entry.enum_key] or tonumber(entry.id)) or entry.enum_key
	local progress_group = item_progress[content_type]
	local progress = progress_group and progress_group[id] or content_type == "Item" and id and item_progress[id]
	if progress and progress.achievement and progress.achievement_path ~= "" then
		return {display = {GfxRoot = progress.achievement_path},has_art = true,id = id}
	end
	local config = content_type == "Card" and id and Isaac.GetItemConfig():GetCard(id) or content_type == "Trinket" and id and Isaac.GetItemConfig():GetTrinket(id) or content_type == "Item" and id and Isaac.GetItemConfig():GetCollectible(id)
	local name = translated_reward_name(entry,content_type,id,config)
	return {name = name,has_art = false,id = id}
end

local function show_reward_text(names)
	if #names == 0 then return end
	local zh = string.find(string.lower(tostring((Options and Options.Language) or "en")),"zh",1,true) ~= nil
	Game():GetHUD():ShowItemText(table.concat(names," / ")..(zh and " 已解锁" or " Unlocked"),"")
end

local function show_reward_entries(entries)
	if not entries or #entries == 0 then return false end
	local displays = {}
	local text_rewards = {}
	for _,entry in ipairs(entries) do
		local info = reward_info(entry)
		if info.has_art then
			if not unlock_registered_achievement(entry,false) then table.insert(displays,info.display) end
		else
			table.insert(text_rewards,info.name)
		end
	end
	if #displays > 0 then Achievement_Display_holder.PlayAchievement(displays) end
	show_reward_text(text_rewards)
	return true
end

local function show_rewards(group,row,column)
	return show_reward_entries(group[row] and group[row][column])
end

local boss_board_names = {
	Maggy = "Magdalene",
	Jacob_and_Esau = "JacobEsau",
}

local function boss_board_row(info)
	local row = boss_board_names[info.Key] or info.Key
	if info.Field == "Tainted" then
		if row == "JacobEsau" then return "Jacob_B" end
		return row .. "_B"
	end
	return row
end

local function reward_entries(category,mark,field)
	local dynamic_boss_column = string.match(category or "","^BossBoard_(.+)$")
	if dynamic_boss_column and field == "Unlock" then
		return unlock_board.boss_unlocks[mark] and unlock_board.boss_unlocks[mark][dynamic_boss_column] or nil
	end
	local character_group = unlock_board.character_unlocks[category]
	if character_group then
		local column = field == "Unlock" and mark or (field == "Hard" and mark == "GreedMode" and "Greedier" or nil)
		local entries = column and character_group[column] or nil
		if entries then return entries end
	end
	local special_group = unlock_board.special_unlocks and unlock_board.special_unlocks[category]
	if field == "Unlock" and special_group and special_group[mark] then return special_group[mark] end
	if category == "Glaze" or category == "BossZeis" then
		local tainted = field == "Tainted" or field == "TaintedHard"
		local hard = field == "Hard" or field == "TaintedHard"
		local row = boss_board_row({Key = mark,Field = tainted and "Tainted" or "Unlock"})
		local prefix = category == "BossZeis" and "Zeis" or category
		local column = prefix..(hard and "Hard" or "Normal")
		return unlock_board.boss_unlocks[row] and unlock_board.boss_unlocks[row][column] or nil
	end
	return nil
end
--这里只检查成就纸片
local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	Unlockers = {
		[RoomType.ROOM_BOSS] = {
			[LevelStage.STAGE4_2] = function(room,st,diff,desc,item)
				if room:IsClear() then
					if st >= StageType.STAGETYPE_REPENTANCE and desc.SafeGridIndex == -10 then item.UpdateCompletion("Mother", diff)
					elseif st <= StageType.STAGETYPE_AFTERBIRTH and room:IsCurrentRoomLastBoss() then item.UpdateCompletion("MomsHeart", diff) end
				end
			end,
			[LevelStage.STAGE4_3] = function(room,st,diff,desc,item)
				if room:IsClear() and desc.SafeGridIndex > 0 then item.UpdateCompletion("Hush", diff) end
			end,
			[LevelStage.STAGE5] = function(room,st,diff,desc,item)
				if room:IsClear() and desc.SafeGridIndex > 0 then
					if st == StageType.STAGETYPE_WOTL then item.UpdateCompletion("Isaac", diff)
					else item.UpdateCompletion("Satan", diff) end
				end
			end,
			[LevelStage.STAGE6] = function(room,st,diff,desc,item)
				if desc.SafeGridIndex == -7 then
					local MegaSatan = auxi.getothers(nil,EntityType.ENTITY_MEGA_SATAN_2,0)[1]
					if not MegaSatan then return end
					local s = MegaSatan:GetSprite()
					if s:IsPlaying("Death") and s:GetFrame() == 110 then item.UpdateCompletion("MegaSatan", diff) end
				else
					if room:IsClear() and desc.SafeGridIndex > 0 then
						if st == StageType.STAGETYPE_WOTL then item.UpdateCompletion("BlueBaby", diff)
						else item.UpdateCompletion("Lamb", diff) end
					end
				end
			end,
			[LevelStage.STAGE7] = function(room,st,diff,desc,item)
				if desc.Data.Subtype == 70 and room:IsClear() and desc.SafeGridIndex > 0 then item.UpdateCompletion("Delirium", diff) end
			end,
			Unlock = function(diff,self,item)
				local level = Game():GetLevel()
				local room = Game():GetRoom()
				local desc = Game():GetLevel():GetCurrentRoomDesc()
				local stageType = level:GetStageType()
				local stage = level:GetStage()
				if stage == LevelStage.STAGE4_1 and level:GetCurses() & LevelCurse.CURSE_OF_LABYRINTH > 0 then stage = stage + 1 end
				if self[stage] then self[stage](room,stageType,diff,desc,item) end
			end,
		},
		[RoomType.ROOM_BOSSRUSH] = {
			Unlock = function(diff,self,item)
				local room = Game():GetRoom()
				if room:IsAmbushDone() then item.UpdateCompletion("BossRush", diff) end
			end,
		},
		[RoomType.ROOM_DUNGEON] = {
			Unlock = function(diff,self,item)
				local level = Game():GetLevel()
				local room = Game():GetRoom()
				local desc = level:GetCurrentRoomDesc()
				local stageType = level:GetStageType()
				local stage = level:GetStage()
				if stage == LevelStage.STAGE4_1 and level:GetCurses() & LevelCurse.CURSE_OF_LABYRINTH > 0 then stage = stage + 1 end
				if self[stage] then self[stage](room,stageType,diff,desc,item) end
			end,
			[LevelStage.STAGE8] = function(room,st,diff,desc,item)
				local Beast = auxi.getothers(nil,EntityType.ENTITY_BEAST,0)[1]
				if not Beast then return end
				local s = Beast:GetSprite()
				if s:IsPlaying("Death") and s:GetFrame() == 30 then item.UpdateCompletion("Beast", diff) end
			end,
		},
		["Greed"] = function(difficulty,item)
			local level = Game():GetLevel()
			local room = Game():GetRoom()
			local desc = level:GetCurrentRoomDesc()
			local stageType = level:GetStageType()
			local stage = level:GetStage()
			if stage == LevelStage.STAGE7_GREED and desc.SafeGridIndex == 45 then
				if room:IsClear() then item.UpdateCompletion("GreedMode", difficulty) end
			end
		end,
	},
}

function item.GetRewardEntries(category,mark,field)
	return reward_entries(category,mark,field) or {}
end

function item.GrantRewards(category,mark,field)
	return show_reward_entries(item.GetRewardEntries(category,mark,field))
end

function item.GetRewardNames(category,mark,field)
	local names = {}
	for _,entry in ipairs(item.GetRewardEntries(category,mark,field)) do
		local content_type = entry.content_type or "Item"
		local id = content_type == "Card" and enums.Cards[entry.enum_key] or content_type == "Trinket" and enums.Trinkets[entry.enum_key] or content_type == "Item" and (enums.Items[entry.enum_key] or tonumber(entry.id)) or nil
		local config = content_type == "Card" and id and Isaac.GetItemConfig():GetCard(id) or content_type == "Trinket" and id and Isaac.GetItemConfig():GetTrinket(id) or content_type == "Item" and id and Isaac.GetItemConfig():GetCollectible(id)
		table.insert(names,translated_reward_name(entry,content_type,id,config))
	end
	return names
end

function item.PlayManualAchievement(category,mark,field,play_animation)
	local entries = item.GetRewardEntries(category,mark,field)
	local displays = {}
	local text_rewards = {}
	for _,entry in ipairs(entries) do
		local info = reward_info(entry)
		if info.has_art then
			unlock_registered_achievement(entry,true)
			if play_animation ~= false then table.insert(displays,info.display) end
		elseif play_animation ~= false then
			table.insert(text_rewards,info.name)
		end
	end
	if play_animation ~= false then
		if #displays > 0 then Achievement_Display_holder.PlayAchievement(displays) end
		show_reward_text(text_rewards)
	end
	return true
end

function item.UpdateBossCompletion(boss_key)
	local mark_id = boss_key == "BossZeis" and "boss.zeis" or boss_key == "Glaze" and "boss.glaze" or nil
	if mark_id then return CompletionMarks.complete_extra_all_players(mark_id) end
	return false
end

function item.UpdateCompletion(name,difficulty)
	local status = (difficulty == Difficulty.DIFFICULTY_HARD or difficulty == Difficulty.DIFFICULTY_GREEDIER) and 2 or 1
	for playerNum = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(playerNum - 1)
		local pt = player:GetPlayerType()
		CompletionMarks.complete_vanilla(pt, name, status)
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function()
	if CompletionMarks.use_legacy_tracker() ~= true then return end
	if ModConfig.ModConfigSettings.Achievement_allow ~= true then return end
	if not auxi.is_normal_game() then return end
	local room = Game():GetRoom()
	local roomType = room:GetType()
	local difficulty = Game().Difficulty
	if difficulty <= Difficulty.DIFFICULTY_HARD then
		if item.Unlockers[roomType] then item.Unlockers[roomType].Unlock(difficulty,item.Unlockers[roomType],item) end
	else
		if roomType == RoomType.ROOM_BOSS then item.Unlockers.Greed(difficulty,item) end
	end
end,
})

return item
