-- Shared pocket / tarot-card visual resolver.
-- Input: concrete Card ID (pickup SubType for PICKUP_TAROTCARD).
-- Output: held/world preview visual spec. Does not spawn entities.
--
-- Priority:
-- 1) ModdedCardFront:Copy() when present
-- 2) ItemConfigCard.PickupSubtype → EntityConfig ANM2
-- 3) CardType / IsRune / known Card ID family fallbacks

local M = {}

local TAROT_VARIANT = PickupVariant.PICKUP_TAROTCARD

local FAMILY_ANM2 = {
	[ItemConfig.CARDTYPE_TAROT] = "gfx/005.301_tarot card.anm2",
	[ItemConfig.CARDTYPE_SUIT] = "gfx/005.302_suit card.anm2",
	[ItemConfig.CARDTYPE_RUNE] = "gfx/005.303_rune1.anm2",
	[ItemConfig.CARDTYPE_TAROT_REVERSE] = "gfx/005.300.14_reverse tarot card.anm2",
}

-- Known special / object / soul fronts when PickupSubtype is unavailable.
local CARD_ID_ANM2 = {
	[Card.CARD_CHAOS] = "gfx/005.308_magic card.anm2",
	[Card.CARD_CREDIT] = "gfx/005.310_credit card.anm2",
	[Card.CARD_HUMANITY] = "gfx/005.309_card against humanity.anm2",
	[Card.CARD_QUESTIONMARK] = "gfx/005.312_chance card.anm2",
	[Card.CARD_DICE_SHARD] = "gfx/005.306_diceshard.anm2",
	[Card.CARD_EMERGENCY_CONTACT] = "gfx/005.305_emergencycontact.anm2",
	[Card.CARD_HOLY] = "gfx/005.311_holy card.anm2",
	[Card.RUNE_BLACK] = "gfx/005.307_blackrune.anm2",
	[Card.RUNE_SHARD] = "gfx/005.313_rune shard.anm2",
	[Card.CARD_CRACKED_KEY] = "gfx/005.300.15_cracked key.anm2",
	[Card.CARD_QUEEN_OF_HEARTS] = "gfx/005.300.16_treasure card.anm2",
	[Card.CARD_WILD] = "gfx/005.300.17_unus card.anm2",
	[Card.CARD_SOUL_ISAAC] = "gfx/005.300.18_soul of isaac.anm2",
	[Card.CARD_SOUL_MAGDALENE] = "gfx/005.300.19_soul of magdalene.anm2",
	[Card.CARD_SOUL_CAIN] = "gfx/005.300.20_soul of cain.anm2",
	[Card.CARD_SOUL_JUDAS] = "gfx/005.300.21_soul of judas.anm2",
	[Card.CARD_SOUL_BLUEBABY] = "gfx/005.300.22_soul of blue baby.anm2",
	[Card.CARD_SOUL_EVE] = "gfx/005.300.23_soul of eve.anm2",
	[Card.CARD_SOUL_SAMSON] = "gfx/005.300.24_soul of samson.anm2",
	[Card.CARD_SOUL_AZAZEL] = "gfx/005.300.25_soul of azazel.anm2",
	[Card.CARD_SOUL_LAZARUS] = "gfx/005.300.26_soul of lazarus.anm2",
	[Card.CARD_SOUL_EDEN] = "gfx/005.300.27_soul of eden.anm2",
	[Card.CARD_SOUL_LOST] = "gfx/005.300.28_soul of the lost.anm2",
	[Card.CARD_SOUL_LILITH] = "gfx/005.300.29_soul of lilith.anm2",
	[Card.CARD_SOUL_KEEPER] = "gfx/005.300.30_soul of the keeper.anm2",
	[Card.CARD_SOUL_APOLLYON] = "gfx/005.300.31_soul of apollyon.anm2",
	[Card.CARD_SOUL_FORGOTTEN] = "gfx/005.300.32_soul of the forgotten.anm2",
	[Card.CARD_SOUL_BETHANY] = "gfx/005.300.33_soul of bethany.anm2",
	[Card.CARD_SOUL_JACOB] = "gfx/005.300.34_soul of jacob.anm2",
}

local function entity_anm2(variant, subtype)
	local path = nil
	pcall(function()
		local cfg = EntityConfig.GetEntity(EntityType.ENTITY_PICKUP, variant, subtype)
		if cfg and cfg.GetAnm2Path then
			path = cfg:GetAnm2Path()
		end
	end)
	if type(path) == "string" and path ~= "" then
		return path
	end
	return nil
end

local function card_type_of(cfg)
	if not cfg then return nil end
	local ct = cfg.CardType
	if type(ct) == "number" then return ct end
	return nil
end

local function is_rune_cfg(cfg)
	if not cfg then return false end
	local ok, rune = pcall(function()
		return cfg.IsRune and cfg:IsRune()
	end)
	if ok and rune then return true end
	return card_type_of(cfg) == ItemConfig.CARDTYPE_RUNE
end

local function family_anm2(cfg, card_id)
	if CARD_ID_ANM2[card_id] then
		return CARD_ID_ANM2[card_id]
	end
	local ct = card_type_of(cfg)
	if ct == ItemConfig.CARDTYPE_RUNE or is_rune_cfg(cfg) then
		if card_id == Card.RUNE_BLACK then
			return "gfx/005.307_blackrune.anm2"
		end
		if card_id == Card.RUNE_SHARD then
			return "gfx/005.313_rune shard.anm2"
		end
		if card_id >= Card.CARD_SOUL_ISAAC and card_id <= Card.CARD_SOUL_JACOB then
			return CARD_ID_ANM2[card_id] or "gfx/005.303_rune1.anm2"
		end
		return "gfx/005.303_rune1.anm2"
	end
	if ct and FAMILY_ANM2[ct] then
		return FAMILY_ANM2[ct]
	end
	if ct == ItemConfig.CARDTYPE_SPECIAL or ct == ItemConfig.CARDTYPE_SPECIAL_OBJECT then
		return CARD_ID_ANM2[card_id] or "gfx/005.301_tarot card.anm2"
	end
	return "gfx/005.301_tarot card.anm2"
end

local function try_modded_front(cfg)
	if not cfg or not cfg.ModdedCardFront then
		return nil
	end
	local ok, copied = pcall(function()
		return cfg.ModdedCardFront:Copy()
	end)
	if ok and copied then
		return copied
	end
	return nil
end

--- Resolve held/world visual for a concrete Card ID.
--- @return table|nil {
---   card_id, exact, sprite?, anm2?, animation, pickup_subtype?,
---   card_type?, is_rune, family
--- }
function M.resolve_card_visual(card_id)
	card_id = tonumber(card_id)
	if not card_id or card_id <= 0 then
		return nil
	end
	local cfg = Isaac.GetItemConfig():GetCard(card_id)
	if not cfg then
		return nil
	end

	local pickup_st = nil
	pcall(function()
		pickup_st = cfg.PickupSubtype
	end)
	pickup_st = tonumber(pickup_st)
	local ct = card_type_of(cfg)
	local rune = is_rune_cfg(cfg)

	local modded = try_modded_front(cfg)
	if modded then
		return {
			card_id = card_id,
			exact = true,
			sprite = modded,
			animation = "Idle",
			pickup_subtype = pickup_st,
			card_type = ct,
			is_rune = rune,
			family = "modded",
			anm2 = nil,
		}
	end

	local anm2 = nil
	if pickup_st ~= nil then
		anm2 = entity_anm2(TAROT_VARIANT, pickup_st)
	end
	if type(anm2) ~= "string" or anm2 == "" then
		anm2 = family_anm2(cfg, card_id)
	end

	local family = "tarot"
	if rune or ct == ItemConfig.CARDTYPE_RUNE then
		family = "rune"
	elseif ct == ItemConfig.CARDTYPE_SUIT then
		family = "suit"
	elseif ct == ItemConfig.CARDTYPE_TAROT_REVERSE then
		family = "reverse_tarot"
	elseif ct == ItemConfig.CARDTYPE_SPECIAL then
		family = "special"
	elseif ct == ItemConfig.CARDTYPE_SPECIAL_OBJECT then
		family = "special_object"
	end

	return {
		card_id = card_id,
		exact = false,
		sprite = nil,
		anm2 = anm2,
		animation = "Idle",
		pickup_subtype = pickup_st,
		card_type = ct,
		is_rune = rune,
		family = family,
	}
end

--- Convenience: ANM2 path only (never spawns).
function M.resolve_card_anm2(card_id)
	local visual = M.resolve_card_visual(card_id)
	return visual and visual.anm2 or nil
end

return M
