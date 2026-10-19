-- Card conversion owner. Registry says what a card is; this module says what it can become.
-- Face groups are the only upright/reversed relation. Vanilla tarot conversion is separate.
-- One candidate returns directly and does not advance RNG. Several candidates require the caller's RNG.

local enums = require("Qing_Remaster_scripts.core.enums")
local card_registry = require("Qing_Remaster_scripts.cards.card_registry")

local C = enums.Cards
local mapping = {}

local face_groups = {
	{
		upright = { C.Witch, C.Invoker, C.Wizard },
		reversed = { C.Sage_r },
	},
	{
		upright = { C.Faint },
		reversed = { C.Faint_r, C.Death_r, C.Corpse_r },
	},
	{ upright = { C.Fool }, reversed = { C.Fool_r } },
	{ upright = { C.Priestess }, reversed = { C.Priestess_r } },
	{ upright = { C.Empress }, reversed = { C.Empress_r } },
	{ upright = { C.Emperor }, reversed = { C.Emperor_r } },
	{ upright = { C.Hierophant }, reversed = { C.Hierophant_r } },
	{ upright = { C.Lover }, reversed = { C.Lover_r } },
	{ upright = { C.Chariot }, reversed = { C.Chariot_r } },
	{ upright = { C.Adjustment }, reversed = { C.Adjustment_r } },
	{ upright = { C.Hermit }, reversed = { C.Hermit_r } },
	{ upright = { C.Wheel_of_Destiny }, reversed = { C.Wheel_of_Destiny_r } },
	{ upright = { C.Lure }, reversed = { C.Lure_r } },
	{ upright = { C.Hanged_Man }, reversed = { C.Hanged_Man_r } },
	{ upright = { C.Art }, reversed = { C.Art_r } },
	{ upright = { C.Devil }, reversed = { C.Devil_r } },
	{ upright = { C.Tower }, reversed = { C.Tower_r } },
	{ upright = { C.Star }, reversed = { C.Star_r } },
	{ upright = { C.Moon }, reversed = { C.Moon_r } },
	{ upright = { C.Sun }, reversed = { C.Sun_r } },
	{ upright = { C.Aeon }, reversed = { C.Aeon_r } },
	{ upright = { C.Universe }, reversed = { C.Universe_r } },
	{ upright = { C.Eclipse }, reversed = { C.Eclipse_r } },
	{ upright = { C.Profound }, reversed = { C.Profound_r } },
	{ upright = { C.Sting }, reversed = { C.Sting_r } },
	{ upright = { C.Oblivion }, reversed = { C.Oblivion_r } },
}

local vanilla_to_thoth = {
	[Card.CARD_FOOL] = { C.Fool, C.Oblivion },
	[Card.CARD_MAGICIAN] = { C.Witch, C.Invoker, C.Wizard },
	[Card.CARD_HIGH_PRIESTESS] = { C.Priestess },
	[Card.CARD_EMPRESS] = { C.Empress },
	[Card.CARD_EMPEROR] = { C.Emperor },
	[Card.CARD_HIEROPHANT] = { C.Hierophant, C.Sting },
	[Card.CARD_LOVERS] = { C.Lover },
	[Card.CARD_CHARIOT] = { C.Chariot },
	[Card.CARD_JUSTICE] = { C.Adjustment },
	[Card.CARD_HERMIT] = { C.Hermit },
	[Card.CARD_WHEEL_OF_FORTUNE] = { C.Wheel_of_Destiny },
	[Card.CARD_STRENGTH] = { C.Lure },
	[Card.CARD_HANGED_MAN] = { C.Hanged_Man },
	[Card.CARD_DEATH] = { C.Faint },
	[Card.CARD_TEMPERANCE] = { C.Art },
	[Card.CARD_DEVIL] = { C.Devil },
	[Card.CARD_TOWER] = { C.Tower },
	[Card.CARD_STARS] = { C.Star },
	[Card.CARD_MOON] = { C.Moon },
	[Card.CARD_SUN] = { C.Sun, C.Eclipse },
	[Card.CARD_JUDGEMENT] = { C.Aeon },
	[Card.CARD_WORLD] = { C.Universe, C.Profound },
	[Card.CARD_REVERSE_FOOL] = { C.Fool_r, C.Oblivion_r },
	[Card.CARD_REVERSE_MAGICIAN] = { C.Sage_r },
	[Card.CARD_REVERSE_HIGH_PRIESTESS] = { C.Priestess_r },
	[Card.CARD_REVERSE_EMPRESS] = { C.Empress_r },
	[Card.CARD_REVERSE_EMPEROR] = { C.Emperor_r },
	[Card.CARD_REVERSE_HIEROPHANT] = { C.Hierophant_r, C.Sting_r },
	[Card.CARD_REVERSE_LOVERS] = { C.Lover_r },
	[Card.CARD_REVERSE_CHARIOT] = { C.Chariot_r },
	[Card.CARD_REVERSE_JUSTICE] = { C.Adjustment_r },
	[Card.CARD_REVERSE_HERMIT] = { C.Hermit_r },
	[Card.CARD_REVERSE_WHEEL_OF_FORTUNE] = { C.Wheel_of_Destiny_r },
	[Card.CARD_REVERSE_STRENGTH] = { C.Lure_r },
	[Card.CARD_REVERSE_HANGED_MAN] = { C.Hanged_Man_r },
	[Card.CARD_REVERSE_DEATH] = { C.Faint_r, C.Death_r, C.Corpse_r },
	[Card.CARD_REVERSE_TEMPERANCE] = { C.Art_r },
	[Card.CARD_REVERSE_DEVIL] = { C.Devil_r },
	[Card.CARD_REVERSE_TOWER] = { C.Tower_r },
	[Card.CARD_REVERSE_STARS] = { C.Star_r },
	[Card.CARD_REVERSE_MOON] = { C.Moon_r },
	[Card.CARD_REVERSE_SUN] = { C.Sun_r, C.Eclipse_r },
	[Card.CARD_REVERSE_JUDGEMENT] = { C.Aeon_r },
	[Card.CARD_REVERSE_WORLD] = { C.Universe_r, C.Profound_r },
}

local thoth_to_vanilla = {
	[C.Fool] = Card.CARD_FOOL,
	[C.Witch] = Card.CARD_MAGICIAN,
	[C.Invoker] = Card.CARD_MAGICIAN,
	[C.Wizard] = Card.CARD_MAGICIAN,
	[C.Priestess] = Card.CARD_HIGH_PRIESTESS,
	[C.Empress] = Card.CARD_EMPRESS,
	[C.Emperor] = Card.CARD_EMPEROR,
	[C.Hierophant] = Card.CARD_HIEROPHANT,
	[C.Lover] = Card.CARD_LOVERS,
	[C.Chariot] = Card.CARD_CHARIOT,
	[C.Adjustment] = Card.CARD_JUSTICE,
	[C.Hermit] = Card.CARD_HERMIT,
	[C.Wheel_of_Destiny] = Card.CARD_WHEEL_OF_FORTUNE,
	[C.Lure] = Card.CARD_STRENGTH,
	[C.Hanged_Man] = Card.CARD_HANGED_MAN,
	[C.Faint] = Card.CARD_DEATH,
	[C.Art] = Card.CARD_TEMPERANCE,
	[C.Devil] = Card.CARD_DEVIL,
	[C.Tower] = Card.CARD_TOWER,
	[C.Star] = Card.CARD_STARS,
	[C.Moon] = Card.CARD_MOON,
	[C.Sun] = Card.CARD_SUN,
	[C.Aeon] = Card.CARD_JUDGEMENT,
	[C.Universe] = Card.CARD_WORLD,
	[C.Fool_r] = Card.CARD_REVERSE_FOOL,
	[C.Sage_r] = Card.CARD_REVERSE_MAGICIAN,
	[C.Priestess_r] = Card.CARD_REVERSE_HIGH_PRIESTESS,
	[C.Empress_r] = Card.CARD_REVERSE_EMPRESS,
	[C.Emperor_r] = Card.CARD_REVERSE_EMPEROR,
	[C.Hierophant_r] = Card.CARD_REVERSE_HIEROPHANT,
	[C.Lover_r] = Card.CARD_REVERSE_LOVERS,
	[C.Chariot_r] = Card.CARD_REVERSE_CHARIOT,
	[C.Adjustment_r] = Card.CARD_REVERSE_JUSTICE,
	[C.Hermit_r] = Card.CARD_REVERSE_HERMIT,
	[C.Wheel_of_Destiny_r] = Card.CARD_REVERSE_WHEEL_OF_FORTUNE,
	[C.Lure_r] = Card.CARD_REVERSE_STRENGTH,
	[C.Hanged_Man_r] = Card.CARD_REVERSE_HANGED_MAN,
	[C.Faint_r] = Card.CARD_REVERSE_DEATH,
	[C.Death_r] = Card.CARD_REVERSE_DEATH,
	[C.Corpse_r] = Card.CARD_REVERSE_DEATH,
	[C.Art_r] = Card.CARD_REVERSE_TEMPERANCE,
	[C.Devil_r] = Card.CARD_REVERSE_DEVIL,
	[C.Tower_r] = Card.CARD_REVERSE_TOWER,
	[C.Star_r] = Card.CARD_REVERSE_STARS,
	[C.Moon_r] = Card.CARD_REVERSE_MOON,
	[C.Sun_r] = Card.CARD_REVERSE_SUN,
	[C.Aeon_r] = Card.CARD_REVERSE_JUDGEMENT,
	[C.Universe_r] = Card.CARD_REVERSE_WORLD,
	[C.Eclipse] = Card.CARD_SUN,
	[C.Eclipse_r] = Card.CARD_REVERSE_SUN,
	[C.Profound] = Card.CARD_WORLD,
	[C.Profound_r] = Card.CARD_REVERSE_WORLD,
	[C.Sting] = Card.CARD_HIEROPHANT,
	[C.Sting_r] = Card.CARD_REVERSE_HIEROPHANT,
	[C.Oblivion] = Card.CARD_FOOL,
	[C.Oblivion_r] = Card.CARD_REVERSE_FOOL,
}

local to_reversed = {}
local to_upright = {}

local function normalize(card)
	if type(card) == "userdata" and card.SubType then
		return card.SubType
	end
	return card
end

local function choose(candidates, rng)
	if type(candidates) ~= "table" or #candidates == 0 then
		return nil
	end
	if #candidates == 1 then
		return candidates[1]
	end
	if not rng or not rng.RandomInt then
		error("card_mapping: RNG required")
	end
	return candidates[rng:RandomInt(#candidates) + 1]
end

for _, group in ipairs(face_groups) do
	for _, id in ipairs(group.upright) do
		to_reversed[id] = group.reversed
	end
	for _, id in ipairs(group.reversed) do
		to_upright[id] = group.upright
	end
end

function mapping.flip(card, rng)
	local id = normalize(card)
	if type(id) ~= "number" then return nil end
	if id > 0 and id < 23 then return id + 55 end
	if id > 55 and id < 78 then return id - 55 end
	if to_reversed[id] then return choose(to_reversed[id], rng) end
	if to_upright[id] then return choose(to_upright[id], rng) end
	return nil
end

function mapping.from_vanilla(card, rng)
	local id = normalize(card)
	local candidates = vanilla_to_thoth[id]
	if not candidates then return nil end
	return choose(candidates, rng)
end

function mapping.to_vanilla(card)
	local id = normalize(card)
	return thoth_to_vanilla[id]
end

function mapping.map_legacy(card, rng)
	local from_vanilla = mapping.from_vanilla(card, rng)
	if from_vanilla then return from_vanilla end
	return mapping.to_vanilla(card)
end

function mapping.is_reversed(card)
	local id = normalize(card)
	if type(id) == "number" and id > 55 and id < 78 then
		return true
	end
	local meta = card_registry.get(id)
	return meta ~= nil and meta.reversed == true
end

function mapping.is_vanilla_tarot(card)
	local id = normalize(card)
	return vanilla_to_thoth[id] ~= nil
end

function mapping.is_mapped(card)
	local id = normalize(card)
	return vanilla_to_thoth[id] ~= nil or thoth_to_vanilla[id] ~= nil
end

function mapping.face_groups()
	return face_groups
end

function mapping.validate()
	local warnings = {}
	local seen = {}
	local function note(id, where)
		if id == nil then
			warnings[#warnings + 1] = where .. " nil id"
			return
		end
		if seen[id] then
			warnings[#warnings + 1] = where .. " duplicate " .. tostring(id)
		end
		seen[id] = true
		local meta = card_registry.get(id)
		if not meta or not meta.families or not meta.families.thoth then
			warnings[#warnings + 1] = where .. " not thoth " .. tostring(id)
		end
	end
	for index, group in ipairs(face_groups) do
		if #group.upright == 0 or #group.reversed == 0 then
			warnings[#warnings + 1] = "empty face group " .. tostring(index)
		end
		for _, id in ipairs(group.upright) do note(id, "upright") end
		for _, id in ipairs(group.reversed) do note(id, "reversed") end
	end
	for _, meta in ipairs(card_registry.query({ family = "thoth" })) do
		if not seen[meta.id] then
			warnings[#warnings + 1] = "thoth missing face " .. tostring(meta.id)
		end
	end
	for vanilla_id, candidates in pairs(vanilla_to_thoth) do
		if #candidates == 0 then
			warnings[#warnings + 1] = "empty vanilla map " .. tostring(vanilla_id)
		end
		local inner = {}
		for _, id in ipairs(candidates) do
			if inner[id] then
				warnings[#warnings + 1] = "duplicate vanilla candidate " .. tostring(id)
			end
			inner[id] = true
			if not thoth_to_vanilla[id] then
				warnings[#warnings + 1] = "vanilla target has no reverse map " .. tostring(id)
			end
		end
	end
	if #warnings > 0 and Isaac and Isaac.DebugString then
		for _, warning in ipairs(warnings) do
			Isaac.DebugString("[Qing card_mapping] " .. warning)
		end
	end
	mapping._warnings = warnings
	return warnings
end

return mapping
