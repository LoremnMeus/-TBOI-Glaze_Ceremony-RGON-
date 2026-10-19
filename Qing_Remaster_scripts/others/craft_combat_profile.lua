-- Craft combat profile: recipe → weapon / flag mask / base⊕stat deltas / synergy / multishot
local M = {
	own_key = "Craft_Combat_Profile_",
	enable_form_log = false,
}

local CraftRegistry = require("Qing_Remaster_scripts.others.craft.registry")
CraftRegistry.attach(M)

local CraftResolver = require("Qing_Remaster_scripts.others.craft.resolver")
CraftResolver.attach(M)

local CraftWeaponRuntime = require("Qing_Remaster_scripts.others.craft.weapon_runtime")
CraftWeaponRuntime.attach(M)

local CraftPresentation = require("Qing_Remaster_scripts.others.craft.presentation")
CraftPresentation.attach(M)

return M
