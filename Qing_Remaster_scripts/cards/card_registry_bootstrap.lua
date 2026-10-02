local registry = require("Qing_Remaster_scripts.cards.card_registry")
local enums = require("Qing_Remaster_scripts.core.enums")

local VANILLA_UPRIGHT = {
	{ id = Card.CARD_FOOL, key = "FOOL", arcana = 0 },
	{ id = Card.CARD_MAGICIAN, key = "MAGICIAN", arcana = 1 },
	{ id = Card.CARD_HIGH_PRIESTESS, key = "HIGH_PRIESTESS", arcana = 2 },
	{ id = Card.CARD_EMPRESS, key = "EMPRESS", arcana = 3 },
	{ id = Card.CARD_EMPEROR, key = "EMPEROR", arcana = 4 },
	{ id = Card.CARD_HIEROPHANT, key = "HIEROPHANT", arcana = 5 },
	{ id = Card.CARD_LOVERS, key = "LOVERS", arcana = 6 },
	{ id = Card.CARD_CHARIOT, key = "CHARIOT", arcana = 7 },
	{ id = Card.CARD_JUSTICE, key = "JUSTICE", arcana = 8 },
	{ id = Card.CARD_HERMIT, key = "HERMIT", arcana = 9 },
	{ id = Card.CARD_WHEEL_OF_FORTUNE, key = "WHEEL_OF_FORTUNE", arcana = 10 },
	{ id = Card.CARD_STRENGTH, key = "STRENGTH", arcana = 11 },
	{ id = Card.CARD_HANGED_MAN, key = "HANGED_MAN", arcana = 12 },
	{ id = Card.CARD_DEATH, key = "DEATH", arcana = 13 },
	{ id = Card.CARD_TEMPERANCE, key = "TEMPERANCE", arcana = 14 },
	{ id = Card.CARD_DEVIL, key = "DEVIL", arcana = 15 },
	{ id = Card.CARD_TOWER, key = "TOWER", arcana = 16 },
	{ id = Card.CARD_STARS, key = "STARS", arcana = 17 },
	{ id = Card.CARD_MOON, key = "MOON", arcana = 18 },
	{ id = Card.CARD_SUN, key = "SUN", arcana = 19 },
	{ id = Card.CARD_JUDGEMENT, key = "JUDGEMENT", arcana = 20 },
	{ id = Card.CARD_WORLD, key = "WORLD", arcana = 21 },
}

local VANILLA_REVERSED = {
	{ id = Card.CARD_REVERSE_FOOL, key = "REVERSE_FOOL", arcana = 0 },
	{ id = Card.CARD_REVERSE_MAGICIAN, key = "REVERSE_MAGICIAN", arcana = 1 },
	{ id = Card.CARD_REVERSE_HIGH_PRIESTESS, key = "REVERSE_HIGH_PRIESTESS", arcana = 2 },
	{ id = Card.CARD_REVERSE_EMPRESS, key = "REVERSE_EMPRESS", arcana = 3 },
	{ id = Card.CARD_REVERSE_EMPEROR, key = "REVERSE_EMPEROR", arcana = 4 },
	{ id = Card.CARD_REVERSE_HIEROPHANT, key = "REVERSE_HIEROPHANT", arcana = 5 },
	{ id = Card.CARD_REVERSE_LOVERS, key = "REVERSE_LOVERS", arcana = 6 },
	{ id = Card.CARD_REVERSE_CHARIOT, key = "REVERSE_CHARIOT", arcana = 7 },
	{ id = Card.CARD_REVERSE_JUSTICE, key = "REVERSE_JUSTICE", arcana = 8 },
	{ id = Card.CARD_REVERSE_HERMIT, key = "REVERSE_HERMIT", arcana = 9 },
	{ id = Card.CARD_REVERSE_WHEEL_OF_FORTUNE, key = "REVERSE_WHEEL_OF_FORTUNE", arcana = 10 },
	{ id = Card.CARD_REVERSE_STRENGTH, key = "REVERSE_STRENGTH", arcana = 11 },
	{ id = Card.CARD_REVERSE_HANGED_MAN, key = "REVERSE_HANGED_MAN", arcana = 12 },
	{ id = Card.CARD_REVERSE_DEATH, key = "REVERSE_DEATH", arcana = 13 },
	{ id = Card.CARD_REVERSE_TEMPERANCE, key = "REVERSE_TEMPERANCE", arcana = 14 },
	{ id = Card.CARD_REVERSE_DEVIL, key = "REVERSE_DEVIL", arcana = 15 },
	{ id = Card.CARD_REVERSE_TOWER, key = "REVERSE_TOWER", arcana = 16 },
	{ id = Card.CARD_REVERSE_STARS, key = "REVERSE_STARS", arcana = 17 },
	{ id = Card.CARD_REVERSE_MOON, key = "REVERSE_MOON", arcana = 18 },
	{ id = Card.CARD_REVERSE_SUN, key = "REVERSE_SUN", arcana = 19 },
	{ id = Card.CARD_REVERSE_JUDGEMENT, key = "REVERSE_JUDGEMENT", arcana = 20 },
	{ id = Card.CARD_REVERSE_WORLD, key = "REVERSE_WORLD", arcana = 21 },
}

local THOTH_ENTRIES = {
	{ key = "Fool", id_key = "Fool", arcana = 0, reversed = false },
	{ key = "Witch", id_key = "Witch", arcana = 1, reversed = false },
	{ key = "Invoker", id_key = "Invoker", arcana = 1, reversed = false },
	{ key = "Wizard", id_key = "Wizard", arcana = 1, reversed = false },
	{ key = "Priestess", id_key = "Priestess", arcana = 2, reversed = false },
	{ key = "Empress", id_key = "Empress", arcana = 3, reversed = false },
	{ key = "Emperor", id_key = "Emperor", arcana = 4, reversed = false },
	{ key = "Hierophant", id_key = "Hierophant", arcana = 5, reversed = false },
	{ key = "Lover", id_key = "Lover", arcana = 6, reversed = false },
	{ key = "Chariot", id_key = "Chariot", arcana = 7, reversed = false },
	{ key = "Adjustment", id_key = "Adjustment", arcana = 8, reversed = false },
	{ key = "Hermit", id_key = "Hermit", arcana = 9, reversed = false },
	{ key = "Wheel_of_Destiny", id_key = "Wheel_of_Destiny", arcana = 10, reversed = false, use_resolution = "deferred" },
	{ key = "Lure", id_key = "Lure", arcana = 11, reversed = false },
	{ key = "Hanged_Man", id_key = "Hanged_Man", arcana = 12, reversed = false },
	{ key = "Faint", id_key = "Faint", arcana = 13, reversed = false },
	{ key = "Art", id_key = "Art", arcana = 14, reversed = false },
	{ key = "Devil", id_key = "Devil", arcana = 15, reversed = false },
	{ key = "Tower", id_key = "Tower", arcana = 16, reversed = false },
	{ key = "Star", id_key = "Star", arcana = 17, reversed = false },
	{ key = "Moon", id_key = "Moon", arcana = 18, reversed = false },
	{ key = "Sun", id_key = "Sun", arcana = 19, reversed = false },
	{ key = "Aeon", id_key = "Aeon", arcana = 20, reversed = false },
	{ key = "Universe", id_key = "Universe", arcana = 21, reversed = false },
	{ key = "Eclipse", id_key = "Eclipse", arcana = 19, reversed = false },
	{ key = "Profound", id_key = "Profound", arcana = 21, reversed = false },
	{ key = "Sting", id_key = "Sting", arcana = 5, reversed = false },
	{ key = "Oblivion", id_key = "Oblivion", arcana = 0, reversed = false, use_resolution = "no_effect" },

	{ key = "Fool_r", id_key = "Fool_r", arcana = 0, reversed = true },
	{ key = "Sage_r", id_key = "Sage_r", arcana = 1, reversed = true },
	{ key = "Priestess_r", id_key = "Priestess_r", arcana = 2, reversed = true },
	{ key = "Empress_r", id_key = "Empress_r", arcana = 3, reversed = true },
	{ key = "Emperor_r", id_key = "Emperor_r", arcana = 4, reversed = true },
	{ key = "Hierophant_r", id_key = "Hierophant_r", arcana = 5, reversed = true },
	{ key = "Lover_r", id_key = "Lover_r", arcana = 6, reversed = true },
	{ key = "Chariot_r", id_key = "Chariot_r", arcana = 7, reversed = true },
	{ key = "Adjustment_r", id_key = "Adjustment_r", arcana = 8, reversed = true },
	{ key = "Hermit_r", id_key = "Hermit_r", arcana = 9, reversed = true },
	{ key = "Wheel_of_Destiny_r", id_key = "Wheel_of_Destiny_r", arcana = 10, reversed = true },
	{ key = "Lure_r", id_key = "Lure_r", arcana = 11, reversed = true },
	{ key = "Hanged_Man_r", id_key = "Hanged_Man_r", arcana = 12, reversed = true },
	{ key = "Faint_r", id_key = "Faint_r", arcana = 13, reversed = true },
	{ key = "Death_r", id_key = "Death_r", arcana = 13, reversed = true },
	{ key = "Corpse_r", id_key = "Corpse_r", arcana = 13, reversed = true },
	{ key = "Art_r", id_key = "Art_r", arcana = 14, reversed = true },
	{ key = "Devil_r", id_key = "Devil_r", arcana = 15, reversed = true },
	{ key = "Tower_r", id_key = "Tower_r", arcana = 16, reversed = true },
	{ key = "Star_r", id_key = "Star_r", arcana = 17, reversed = true },
	{ key = "Moon_r", id_key = "Moon_r", arcana = 18, reversed = true },
	{ key = "Sun_r", id_key = "Sun_r", arcana = 19, reversed = true },
	{ key = "Aeon_r", id_key = "Aeon_r", arcana = 20, reversed = true },
	{ key = "Universe_r", id_key = "Universe_r", arcana = 21, reversed = true },
	{ key = "Eclipse_r", id_key = "Eclipse_r", arcana = 19, reversed = true },
	{ key = "Profound_r", id_key = "Profound_r", arcana = 21, reversed = true },
	{ key = "Sting_r", id_key = "Sting_r", arcana = 5, reversed = true },
	{ key = "Oblivion_r", id_key = "Oblivion_r", arcana = 0, reversed = true },
}

for _, entry in ipairs(VANILLA_UPRIGHT) do
	registry.register(entry.id, {
		key = entry.key,
		arcana = entry.arcana,
		reversed = false,
		families = { tarot = true },
		source = "vanilla",
	})
end

for _, entry in ipairs(VANILLA_REVERSED) do
	registry.register(entry.id, {
		key = entry.key,
		arcana = entry.arcana,
		reversed = true,
		families = { tarot = true },
		source = "vanilla",
	})
end

for _, entry in ipairs(THOTH_ENTRIES) do
	local card_id = enums.Cards[entry.id_key]
	registry.register(card_id, {
		key = entry.key,
		arcana = entry.arcana,
		reversed = entry.reversed,
		families = { thoth = true },
		source = "mod",
		use_resolution = entry.use_resolution,
	})
end

registry.finalize()
registry.validate()

return registry
