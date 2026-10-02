-- Shared helpers for 0 - Oblivion / 0 - Oblivion?
local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local common = {}

common.FORGET_FRAMES = 2700 -- 90s @ 30Hz PEFFECT
common.SPAWN_INTERVAL = 30 -- 1s
common.TEMP_DURATION = 150 -- 5s
common.PENDING_PER_USE = 50
common.MAX_REROLL = 48
common.MAX_VIRTUAL_VISIBLE = 4

common.DESC_STEPS_ZH = {
	"别忘了这是什么",
	"别忘了这是什",
	"别忘了这是",
	"别忘了这",
	"别忘了",
	"别忘",
	"别",
	"",
}

common.DESC_STEPS_EN = {
	"Don't forget what this is",
	"Don't forget what this i",
	"Don't forget what this",
	"Don't forget what thi",
	"Don't forget what",
	"Don't forget wha",
	"Don't forget wh",
	"Don't forget w",
	"Don't forget",
	"Don't forge",
	"Don't forg",
	"Don't for",
	"Don't fo",
	"Don't f",
	"Don't",
	"Don'",
	"Don",
	"Do",
	"D",
	"",
}

-- Known-unsafe / non-removable / one-shot acquire items for either card.
common.FORGET_BLACKLIST = {
	[CollectibleType.COLLECTIBLE_DADS_NOTE] = true,
	[CollectibleType.COLLECTIBLE_KNIFE_PIECE_1] = true,
	[CollectibleType.COLLECTIBLE_KNIFE_PIECE_2] = true,
	[CollectibleType.COLLECTIBLE_KEY_PIECE_1] = true,
	[CollectibleType.COLLECTIBLE_KEY_PIECE_2] = true,
	[CollectibleType.COLLECTIBLE_POLAROID] = true,
	[CollectibleType.COLLECTIBLE_NEGATIVE] = true,
	[CollectibleType.COLLECTIBLE_DAMOCLES] = true,
	[CollectibleType.COLLECTIBLE_DAMOCLES_PASSIVE] = true,
	[CollectibleType.COLLECTIBLE_BIRTHRIGHT] = true,
}

common.TEMP_BLACKLIST = {
	[CollectibleType.COLLECTIBLE_DADS_NOTE] = true,
	[CollectibleType.COLLECTIBLE_KNIFE_PIECE_1] = true,
	[CollectibleType.COLLECTIBLE_KNIFE_PIECE_2] = true,
	[CollectibleType.COLLECTIBLE_KEY_PIECE_1] = true,
	[CollectibleType.COLLECTIBLE_KEY_PIECE_2] = true,
	[CollectibleType.COLLECTIBLE_POLAROID] = true,
	[CollectibleType.COLLECTIBLE_NEGATIVE] = true,
	[CollectibleType.COLLECTIBLE_DAMOCLES] = true,
	[CollectibleType.COLLECTIBLE_DAMOCLES_PASSIVE] = true,
	[CollectibleType.COLLECTIBLE_BIRTHRIGHT] = true,
	[CollectibleType.COLLECTIBLE_TMTRAINER] = true,
	[CollectibleType.COLLECTIBLE_MISSING_NO] = true,
	[CollectibleType.COLLECTIBLE_VOID] = true,
	[CollectibleType.COLLECTIBLE_GENESIS] = true,
	[CollectibleType.COLLECTIBLE_ESAU_JR] = true,
	[CollectibleType.COLLECTIBLE_SPINDOWN_DICE] = true,
	[CollectibleType.COLLECTIBLE_D100] = true,
	[CollectibleType.COLLECTIBLE_D4] = true,
	[CollectibleType.COLLECTIBLE_D6] = true,
	[CollectibleType.COLLECTIBLE_D7] = true,
	[CollectibleType.COLLECTIBLE_D8] = true,
	[CollectibleType.COLLECTIBLE_D10] = true,
	[CollectibleType.COLLECTIBLE_D12] = true,
	[CollectibleType.COLLECTIBLE_D20] = true,
	[CollectibleType.COLLECTIBLE_ETERNAL_D6] = true,
	[CollectibleType.COLLECTIBLE_CROOKED_PENNY] = true,
	[CollectibleType.COLLECTIBLE_MOVING_BOX] = true,
	[CollectibleType.COLLECTIBLE_CLICKER] = true,
	[CollectibleType.COLLECTIBLE_RECALL] = true,
	[CollectibleType.COLLECTIBLE_R_KEY] = true,
	[CollectibleType.COLLECTIBLE_DEATH_CERTIFICATE] = true,
	[CollectibleType.COLLECTIBLE_FLIP] = true,
	[CollectibleType.COLLECTIBLE_LEMEGETON] = true,
	[CollectibleType.COLLECTIBLE_ANIMA_SOLA] = true,
}

local TAG_QUEST = ItemConfig.TAG_QUEST or (1 << 15)

function common.player_index(player)
	if not player then return nil end
	local d = player:GetData()
	return d and d.__Index or nil
end

function common.find_owned_card_slot(player, card_id)
	if not player or not card_id then
		return nil
	end
	return auxi.has_card(player, card_id)
end

function common.has_in_any_card_slot(player, card_id)
	return common.find_owned_card_slot(player, card_id) ~= nil
end

-- Foreground pocket slot only. A card sitting behind a pocket active is not held.
function common.get_primary_card(player)
	if not player then
		return nil
	end

	local slot = PillCardSlot and PillCardSlot.PRIMARY or 0

	if player.GetPocketItem then
		local pocket = player:GetPocketItem(slot)
		if not pocket then
			return nil
		end

		local pocket_slot = pocket:GetSlot()
		-- PocketItem docs: empty -> GetSlot() == 0.
		if pocket_slot == 0 then
			return nil
		end

		-- CARD GetSlot is the card id. ACTIVE_ITEM GetSlot is ActiveSlot + 1.
		if not PocketItemType or pocket:GetType() ~= PocketItemType.CARD then
			return nil
		end

		-- GetCard should match. PocketItem stays authoritative if it does not.
		if player.GetCard and player:GetCard(slot) ~= pocket_slot then
			-- PocketItem is authoritative when GetCard disagrees.
		end

		return pocket_slot
	end

	local card = player:GetCard(0)
	if card and card > 0 then
		return card
	end
	return nil
end

function common.has_primary_card(player, card_id)
	return common.get_primary_card(player) == card_id
end

-- Direct pocket press vs simulated UseCard/UsePill. Shared with player_loss_holder.
local pocket_use = require("Qing_Remaster_scripts.auxiliary.pocket_use_semantics")

function common.is_simulated_use(useFlags)
	return pocket_use.is_simulated_use(useFlags)
end

function common.is_real_owned_use(useFlags)
	return pocket_use.is_real_owned_use(useFlags)
end

function common.is_paused()
	local ok, paused = pcall(function()
		return Game():IsPaused() == true
	end)
	return ok and paused
end

function common.prefer_chinese_desc()
	local lang = Options and Options.Language
	if lang == "zh" or lang == "cn" or lang == "schinese" or lang == "tchinese" then
		return true
	end
	if EID and EID.Config and EID.Config["Language"] then
		local eid_lang = tostring(EID.Config["Language"])
		if eid_lang:find("zh") or eid_lang:find("chinese") then
			return true
		end
	end
	return false
end

function common.desc_steps()
	if common.prefer_chinese_desc() then
		return common.DESC_STEPS_ZH
	end
	return common.DESC_STEPS_EN
end

function common.desc_language_key()
	if common.prefer_chinese_desc() then
		return "zh"
	end
	return "en"
end

function common.desc_index_for_progress(progress)
	local steps = common.desc_steps()
	local ratio = 0
	if common.FORGET_FRAMES > 0 then
		ratio = math.max(0, math.min(1, (progress or 0) / common.FORGET_FRAMES))
	end
	local index = math.floor(ratio * (#steps - 1)) + 1
	if index < 1 then index = 1 end
	if index > #steps then index = #steps end
	return index
end

function common.desc_for_progress(progress)
	local steps = common.desc_steps()
	return steps[common.desc_index_for_progress(progress)]
end

function common.alpha_for_progress(progress)
	local ratio = 0
	if common.FORGET_FRAMES > 0 then
		ratio = math.max(0, math.min(1, (progress or 0) / common.FORGET_FRAMES))
	end
	return 1 - ratio
end

-- Overlay PNG already eases (gamma baked). Do not square progress again.
common.FORGET_OVERLAY_FRAMES = 16

function common.overlay_frame_for_progress(progress)
	local total = tonumber(common.FORGET_FRAMES) or 0
	if total <= 0 then
		return 0
	end
	local t = math.max(0, math.min(1, (tonumber(progress) or 0) / total))
	local frame = math.floor(t * (common.FORGET_OVERLAY_FRAMES - 1) + 1e-6)
	if frame < 0 then frame = 0 end
	if frame >= common.FORGET_OVERLAY_FRAMES then
		frame = common.FORGET_OVERLAY_FRAMES - 1
	end
	return frame
end

function common.overlay_blend_for_progress(progress)
	local total = tonumber(common.FORGET_FRAMES) or 0
	if total <= 0 then
		return 0, 0, 0
	end
	local t = math.max(0, math.min(1, (tonumber(progress) or 0) / total))
	local last = common.FORGET_OVERLAY_FRAMES - 1
	local exact = t * last
	local current = math.floor(exact)
	local next_frame = math.min(last, current + 1)
	local blend = exact - current
	return current, next_frame, blend
end

function common.get_config(card_id)
	return Isaac.GetItemConfig():GetCard(card_id)
end

function common.cfg_has_tags(cfg, tag)
	if not cfg then return false end
	if cfg.HasTags then return cfg:HasTags(tag) end
	return (cfg.Tags or 0) & tag == tag
end

function common.is_passive_or_familiar(cfg)
	if not cfg then return false end
	local tp = cfg.Type
	return tp == ItemType.ITEM_PASSIVE or tp == ItemType.ITEM_FAMILIAR
end

function common.can_reroll(id)
	local config = Isaac.GetItemConfig()
	if config.CanRerollCollectible then
		return config.CanRerollCollectible(id) == true
	end
	return true
end

function common.is_valid_pool(pool)
	pool = tonumber(pool)
	if pool == nil then return false end
	if ItemPoolType and ItemPoolType.POOL_NULL ~= nil and pool == ItemPoolType.POOL_NULL then
		return false
	end
	return pool >= 0
end

function common.is_forgettable_id(player, id, pool)
	id = tonumber(id)
	if not id or id <= 0 then return false end
	if common.FORGET_BLACKLIST[id] then return false end
	if not common.is_valid_pool(pool) then return false end
	if not common.can_reroll(id) then return false end
	local cfg = Isaac.GetItemConfig():GetCollectible(id)
	if not cfg or cfg.Hidden then return false end
	if common.cfg_has_tags(cfg, TAG_QUEST) then return false end
	if not common.is_passive_or_familiar(cfg) then return false end
	if player:GetCollectibleNum(id, true) < 1 then return false end
	return true
end

function common.find_forget_target(player)
	if not player or not player.GetHistory then return nil end
	local history = player:GetHistory():GetCollectiblesHistory()
	if type(history) ~= "table" then return nil end
	for i = #history, 1, -1 do
		local hi = history[i]
		if hi and not (hi.IsTrinket and hi:IsTrinket()) then
			local id = hi.GetItemID and hi:GetItemID() or nil
			local pool = hi.GetItemPoolType and hi:GetItemPoolType() or nil
			if common.is_forgettable_id(player, id, pool) then
				return {
					lua_index = i,
					history_index = i - 1,
					id = id,
					pool = pool,
				}
			end
		end
	end
	return nil
end

function common.is_valid_replacement(id, old_id)
	id = tonumber(id)
	old_id = tonumber(old_id)
	if not id or id <= 0 then return false end
	if id == old_id then return false end
	if id == CollectibleType.COLLECTIBLE_BREAKFAST then return false end
	if common.FORGET_BLACKLIST[id] then return false end
	local cfg = Isaac.GetItemConfig():GetCollectible(id)
	if not cfg or cfg.Hidden then return false end
	if common.cfg_has_tags(cfg, TAG_QUEST) then return false end
	if not common.is_passive_or_familiar(cfg) then return false end
	if not common.can_reroll(id) then return false end
	return true
end

function common.draw_replacement(player, pool, old_id, rng, exclude_ids)
	local item_pool = Game():GetItemPool()
	rng = auxi.rng_for_sake(rng) or player:GetCardRNG(enums.Cards.Oblivion)
	for _ = 1, common.MAX_REROLL do
		local seed = rng:Next()
		local id = item_pool:GetCollectible(pool, true, seed, CollectibleType.COLLECTIBLE_BREAKFAST)
		if common.is_valid_replacement(id, old_id) and not (exclude_ids and exclude_ids[id]) then
			return id
		end
	end
	return nil
end

function common.resync_collectible_counter(player, ids)
	local idx = common.player_index(player)
	if idx == nil then return end
	save.elses.collectible_counter = save.elses.collectible_counter or {}
	local counter = save.elses.collectible_counter[idx]
	if type(counter) ~= "table" then return end
	counter.list = counter.list or {}
	for _, id in ipairs(ids or {}) do
		id = tonumber(id)
		if id then
			local n = player:GetCollectibleNum(id, true)
			if n <= 0 then
				counter.list[id] = nil
			else
				counter.list[id] = n
			end
		end
	end
	counter.num = player:GetCollectibleCount()
end

-- Rewrite one history-backed passive into replacements from the same pool.
-- Target, pool, and removal each happen once. replacement_count defaults to 1.
function common.execute_forget(player, rng, opts)
	opts = opts or {}
	local replacement_count = tonumber(opts.replacement_count) or 1
	if replacement_count < 1 then
		replacement_count = 1
	end
	if not player then return false end
	local target = common.find_forget_target(player)
	if not target then return false end

	local old_id = target.id
	local pool = target.pool
	local exclusions = {[old_id] = true}
	local replacements = {}
	for _ = 1, replacement_count do
		local new_id = common.draw_replacement(player, pool, old_id, rng, exclusions)
		if new_id then
			replacements[#replacements + 1] = new_id
			exclusions[new_id] = true
		end
	end

	player:RemoveCollectibleByHistoryIndex(target.history_index)
	local ids = {old_id}
	for _, new_id in ipairs(replacements) do
		if player.AddCollectible then
			local ok = pcall(function()
				player:AddCollectible(new_id, 0, false, ActiveSlot.SLOT_PRIMARY, 0, pool)
			end)
			if not ok then
				player:AddCollectible(new_id, 0, false)
			end
		end
		ids[#ids + 1] = new_id
	end
	common.resync_collectible_counter(player, ids)
	return true
end

function common.can_temporarily_remember(id)
	id = tonumber(id)
	if not id or id <= 0 then return false end
	if common.TEMP_BLACKLIST[id] then return false end
	local cfg = Isaac.GetItemConfig():GetCollectible(id)
	if not cfg or cfg.Hidden then return false end
	if common.cfg_has_tags(cfg, TAG_QUEST) then return false end
	if not common.is_passive_or_familiar(cfg) then return false end
	return true
end

function common.build_temp_pool()
	if common._temp_pool then return common._temp_pool end
	local pool = {}
	local config = Isaac.GetItemConfig()
	local size = config:GetCollectibles().Size
	for i = 1, size - 1 do
		if common.can_temporarily_remember(i) then
			pool[#pool + 1] = i
		end
	end
	common._temp_pool = pool
	return pool
end

function common.pick_temp_collectible(rng, active_ids)
	local pool = common.build_temp_pool()
	if #pool == 0 then return nil end
	rng = auxi.rng_for_sake(rng)
	active_ids = active_ids or {}
	for _ = 1, common.MAX_REROLL do
		local id = pool[(rng:RandomInt(#pool)) + 1]
		if id and not active_ids[id] and common.can_temporarily_remember(id) then
			return id
		end
	end
	-- Fallback: allow any valid even if active (should be rare).
	for _ = 1, 8 do
		local id = pool[(rng:RandomInt(#pool)) + 1]
		if id and common.can_temporarily_remember(id) then
			return id
		end
	end
	return nil
end

function common.make_card_sprite()
	local spr = Sprite()
	spr:Load("gfx/ui/content/ui_cardfronts.anm2", true)
	return spr
end

return common
