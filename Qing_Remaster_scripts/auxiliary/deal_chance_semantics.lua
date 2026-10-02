-- Deal Chance / Found HUD 公共语义。
-- Calculation（holder）≠ Found-HUD eligibility ≠ Devil/Angel display split。
-- Illegal floors zero only display.*; never mutate internal.*.
-- 不注册 callback；不知道 Spectralsword。

local deal_holder = require("Qing_Remaster_scripts.callbacks.deal_chance_holder")

local M = {}

local function any_player_has_collectible(collectible)
	if REPENTOGON and PlayerManager and PlayerManager.AnyoneHasCollectible then
		return PlayerManager.AnyoneHasCollectible(collectible) == true
	end
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player and player:HasCollectible(collectible, false) then
			return true
		end
	end
	return false
end

local function any_player_has_trinket(trinket)
	if REPENTOGON and PlayerManager and PlayerManager.AnyoneHasTrinket then
		return PlayerManager.AnyoneHasTrinket(trinket) == true
	end
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player and player:HasTrinket(trinket, false) then
			return true
		end
	end
	return false
end

--- Found HUD Deal 楼层资格（非 CanSpawnDevilRoom 一刀切）。
--- 复现 Co-Op HUD Plus 已验证的 floor gate。
function M.get_found_hud_eligibility()
	local level = Game():GetLevel()
	local stage = level and level:GetStage() or nil
	local stage_type = level and level:GetStageType() or nil

	local labyrinth = false
	if level and level.GetCurses and LevelCurse and LevelCurse.CURSE_OF_LABYRINTH then
		labyrinth = (level:GetCurses() & LevelCurse.CURSE_OF_LABYRINTH) ~= 0
	end

	local pre_ascent = false
	if level and level.IsPreAscent then
		local ok, v = pcall(function() return level:IsPreAscent() end)
		if ok then pre_ascent = v == true end
	end

	local can_spawn = nil
	if level and level.CanSpawnDevilRoom then
		local ok, v = pcall(function() return level:CanSpawnDevilRoom() end)
		if ok then can_spawn = v == true end
	end

	local disabled = nil
	if level and level.IsDevilRoomDisabled then
		local ok, v = pcall(function() return level:IsDevilRoomDisabled() end)
		if ok then disabled = v == true end
	end

	local function pack(eligible, reason)
		return {
			found_hud_eligible = eligible == true,
			reason = reason,
			can_spawn_api = can_spawn,
			devil_room_disabled = disabled,
			stage = stage,
			stage_type = stage_type,
			labyrinth = labyrinth,
			pre_ascent = pre_ascent,
		}
	end

	if pre_ascent then
		return pack(false, "pre_ascent")
	end

	if stage == LevelStage.STAGE4_3
		or stage == LevelStage.STAGE5
		or stage == LevelStage.STAGE6
		or stage == LevelStage.STAGE7
		or stage == LevelStage.STAGE8
	then
		return pack(false, "late_stage")
	end

	local is_rep_alt = stage_type == StageType.STAGETYPE_REPENTANCE
		or stage_type == StageType.STAGETYPE_REPENTANCE_B

	if stage == LevelStage.STAGE1_1 and not labyrinth and not is_rep_alt then
		return pack(false, "normal_stage1_1")
	end

	return pack(true, "eligible")
end

function M.is_found_hud_deal_eligible()
	local e = M.get_found_hud_eligibility()
	return e.found_hud_eligible == true, e.reason
end

--- 原版 Duality（含 Disequilibrium 等通过赋予该道具实现的模拟）。
function M.has_duality()
	if REPENTOGON and PlayerManager and PlayerManager.AnyoneHasCollectible then
		return PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_DUALITY) == true
	end
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player and player:HasCollectible(CollectibleType.COLLECTIBLE_DUALITY, false) then
			return true
		end
	end
	return false
end

local function read_level_angel_mod(level)
	if level and level.GetAngelRoomChance then
		return tonumber(level:GetAngelRoomChance()) or 0
	end
	return 0
end

--- IsaacDocs Found-HUD Devil/Angel splitter（总 Deal → share）。
--- Angel ≠ Level:GetAngelRoomChance()（那是转化 modifier）。
--- opts.angel_mod：假设的转化 modifier；省略则读 Level:GetAngelRoomChance()。
--- 纯计算，不调用 AddAngelRoomChance。
function M.split_devil_angel(_total_unused, opts)
	opts = opts or {}
	local game = Game()
	local level = game:GetLevel()
	local angel_mod = opts.angel_mod
	if angel_mod == nil then
		angel_mod = read_level_angel_mod(level)
	else
		angel_mod = tonumber(angel_mod) or 0
	end

	local angel_spawned = game:GetStateFlag(GameStateFlag.STATE_FAMINE_SPAWNED) -- repurposed
	local devil_spawned = game:GetStateFlag(GameStateFlag.STATE_DEVILROOM_SPAWNED)
	local devil_visited = game:GetStateFlag(GameStateFlag.STATE_DEVILROOM_VISITED)

	local devil_share = 1.0
	if any_player_has_collectible(CollectibleType.COLLECTIBLE_EUCHARIST) then
		devil_share = 0.0
	elseif devil_spawned and devil_visited and game:GetDevilRoomDeals() > 0 then
		if any_player_has_collectible(CollectibleType.COLLECTIBLE_BOOK_OF_VIRTUES)
			or any_player_has_collectible(CollectibleType.COLLECTIBLE_ACT_OF_CONTRITION)
			or angel_mod > 0.0
		then
			devil_share = 0.5
		end
	elseif devil_spawned
		or any_player_has_collectible(CollectibleType.COLLECTIBLE_BOOK_OF_VIRTUES)
		or angel_mod > 0.0
	then
		if not (devil_visited or angel_spawned) then
			devil_share = 0.0
		else
			devil_share = 0.5
		end
	end

	if devil_share == 0.5 and level then
		if any_player_has_trinket(TrinketType.TRINKET_ROSARY_BEAD) then
			devil_share = devil_share * (1.0 - 0.5)
		end
		if game.GetDonationModAngel and game:GetDonationModAngel() >= 10 then
			devil_share = devil_share * (1.0 - 0.5)
		end
		if any_player_has_collectible(CollectibleType.COLLECTIBLE_KEY_PIECE_1) then
			devil_share = devil_share * (1.0 - 0.25)
		end
		if any_player_has_collectible(CollectibleType.COLLECTIBLE_KEY_PIECE_2) then
			devil_share = devil_share * (1.0 - 0.25)
		end
		if level:GetStateFlag(LevelStateFlag.STATE_EVIL_BUM_KILLED) then
			devil_share = devil_share * (1.0 - 0.25)
		end
		if level:GetStateFlag(LevelStateFlag.STATE_BUM_LEFT)
			and not level:GetStateFlag(LevelStateFlag.STATE_EVIL_BUM_LEFT)
		then
			devil_share = devil_share * (1.0 - 0.1)
		end
		if level:GetStateFlag(LevelStateFlag.STATE_EVIL_BUM_LEFT)
			and not level:GetStateFlag(LevelStateFlag.STATE_BUM_LEFT)
		then
			devil_share = devil_share * (1.0 + 0.1)
		end
		if angel_mod > 0.0
			or (angel_mod < 0.0 and (
				any_player_has_collectible(CollectibleType.COLLECTIBLE_BOOK_OF_VIRTUES)
				or any_player_has_collectible(CollectibleType.COLLECTIBLE_ACT_OF_CONTRITION)
			))
		then
			devil_share = devil_share * (1.0 - angel_mod)
		end
		if any_player_has_collectible(CollectibleType.COLLECTIBLE_BOOK_OF_VIRTUES) then
			devil_share = devil_share * (1.0 - 0.25)
		end
		devil_share = math.max(0.0, math.min(devil_share, 1.0))
	end

	return {
		devil_share = devil_share,
		angel_share = 1.0 - devil_share,
		angel_mod = angel_mod,
	}
end

--- 假设转化 modifier = x 时的 Found-HUD Angel/Devil 显示（不改游戏状态）。
function M.evaluate_angel_display_at(x, opts)
	opts = opts or {}
	local snap = M.snapshot({
		allow_getter_fallback = opts.allow_getter_fallback ~= false,
		angel_mod = x,
	})
	local display = snap.display or {}
	local split = snap.split or {}
	return {
		x = tonumber(x) or 0,
		total = tonumber(display.total) or 0,
		angel = tonumber(display.angel) or 0,
		devil = tonumber(display.devil) or 0,
		angel_share = tonumber(split.angel_share) or 0,
		devil_share = tonumber(split.devil_share) or 0,
		eligible = snap.eligibility and snap.eligibility.found_hud_eligible == true,
	}
end

--- opts.allow_getter_fallback：普通帧允许在无 cache 时读 getter；calculation callback 内必须 false。
--- opts.angel_mod：假设转化 modifier（试探用）；省略则读 Level。
function M.snapshot(opts)
	opts = opts or {}
	local allow_getter = opts.allow_getter_fallback == true

	local raw_total = deal_holder.get_raw_total_deal()
	local modified_total = deal_holder.get_modified_total_deal()
	local source = "runtime"
	local planetarium = 0

	if allow_getter then
		local room = Game():GetRoom()
		local level = Game():GetLevel()
		if modified_total == nil and room and room.GetDevilRoomChance then
			modified_total = tonumber(room:GetDevilRoomChance()) or 0
			raw_total = modified_total
			source = "getter_fallback"
		end
		-- Planetarium：独立链，优先公开 API Level:GetPlanetariumChance()
		if level and level.GetPlanetariumChance then
			planetarium = tonumber(level:GetPlanetariumChance()) or 0
		end
	end

	raw_total = tonumber(raw_total) or 0
	modified_total = tonumber(modified_total) or 0
	planetarium = math.max(0.0, math.min(tonumber(planetarium) or 0, 1.0))

	local eligibility = M.get_found_hud_eligibility()
	local split_opts = nil
	if opts.angel_mod ~= nil then
		split_opts = {angel_mod = opts.angel_mod}
	end
	local split = M.split_devil_angel(modified_total, split_opts)

	local display_total = 0
	local display_devil = 0
	local display_angel = 0
	if eligibility.found_hud_eligible then
		display_total = math.min(modified_total, 1.0)
		if M.has_duality() then
			-- Duality：Found HUD 合并为一行总 Deal；不再按 share 拆 Devil/Angel。
			display_devil = display_total
			display_angel = 0
		else
			display_devil = display_total * split.devil_share
			display_angel = display_total * split.angel_share
		end
	end

	return {
		internal = {
			raw_total = raw_total,
			modified_total = modified_total,
			source = source,
		},
		eligibility = eligibility,
		split = {
			devil_share = split.devil_share,
			angel_share = split.angel_share,
			angel_mod = split.angel_mod,
		},
		display = {
			total = display_total,
			devil = display_devil,
			angel = display_angel,
			planetarium = planetarium,
		},
	}
end

return M
