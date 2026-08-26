local enums = require("Qing_Remaster_scripts.core.enums")
local save = require("Qing_Remaster_scripts.core.savedata")
local manifest = require("Qing_Remaster_scripts.translations.menu_language_manifest")

local item = {
	ToCall = {},
	own_key = "Rgon_Menu_Language_",
	applied_language = nil,
	loaded_by_hash = {},
	failed = {},
	console_registered = false,
}

local aliases = {
	zh_cn = "zh",
	zh_tw = "zh",
}

local sprite_getters = {
	menu = "GetModdedMenuBackgroundSprite",
	portrait = "GetModdedMenuPortraitSprite",
	controls = "GetModdedControlsSprite",
	coop = "GetModdedCoopMenuSprite",
	game_over = "GetModdedGameOverSprite",
}

local FORCE_AUTO = 0
local FORCE_ZH = 1
local FORCE_EN = 2

local PLAYER_MENUS = {
	{key = "wq", anim = "W.Qing", family = "normal"},
	{key = "Spwq", anim = "SP.W.Qing", family = "alt"},
	{key = "Tecro", anim = "Tecro", family = "normal"},
	{key = "Tecrorun", anim = "Tecrorun", family = "alt"},
	{key = "Anna", anim = "Anna", family = "normal"},
	{key = "annA", anim = "annA", family = "alt"},
	{key = "Zeistos", anim = "Zeistos", family = "normal"},
	{key = "Zeiz", anim = "Zeiz", family = "alt"},
	{key = "Marriano", anim = "Marriano", family = "normal"},
	{key = "Autio", anim = "Autio", family = "normal"},
	{key = "Lu", anim = "Lu", family = "normal"},
}

function item.basename_lower(path)
	local name = tostring(path or ""):gsub("\\", "/"):lower()
	return name:match("([^/]+)$") or name
end

function item.paths_equal(a, b)
	return tostring(a or ""):gsub("\\", "/"):lower() == tostring(b or ""):gsub("\\", "/"):lower()
end

function item.get_game_language()
	local lang = (Options and Options.Language) or manifest.default_language or "en"
	return aliases[lang] or lang
end

function item.get_force_mode(setting_key)
	local root = save.ModConfigSettings
	local menu = root and root.QingRemasterOptions and root.QingRemasterOptions.Menu
	local value = menu and menu[setting_key or "CharacterSelectLanguage"]
	if value == "zh" or value == FORCE_ZH then return FORCE_ZH end
	if value == "en" or value == FORCE_EN then return FORCE_EN end
	return FORCE_AUTO
end

function item.get_language(setting_key)
	local force = item.get_force_mode(setting_key)
	if force == FORCE_ZH then return "zh" end
	if force == FORCE_EN then return "en" end
	local lang = item.get_game_language()
	if lang == "zh" then return "zh" end
	return "en"
end

function item.full_path(info, path)
	if type(path) ~= "string" or path == "" then return nil end
	return (info.base or "")..path
end

function item.anm2_for(family, lang)
	local info = manifest.character_select and manifest.character_select.anm2
	local family_info = info and info[family]
	if not family_info then return nil end
	return family_info[lang] or family_info.en
end

function item.section_anm2(section, lang)
	local info = manifest[section]
	if type(info) ~= "table" or info.enabled == false then return nil end
	return info[lang] or info.en
end

function item.get_play_anim()
	local selected_anim = item.get_selected_menu_info()
	if selected_anim then return selected_anim end
	local ok, count = pcall(function()
		return Game():GetNumPlayers()
	end)
	if not ok or type(count) ~= "number" then return nil end
	for i = 0, count - 1 do
		local pok, player = pcall(function()
			return Game():GetPlayer(i)
		end)
		if pok and player and player.GetPlayerType then
			local ptype = player:GetPlayerType()
			for _, info in ipairs(PLAYER_MENUS) do
				if enums.Players[info.key] == ptype then
					return info.anim
				end
			end
		end
	end
	return nil
end

function item.get_sprite_filename(sprite)
	if not sprite or not sprite.GetFilename then return "" end
	local ok, name = pcall(function()
		return sprite:GetFilename() or ""
	end)
	if ok then return name or "" end
	return ""
end

function item.get_sprite_animation(sprite)
	if not sprite or not sprite.GetAnimation then return "" end
	local ok, name = pcall(function()
		return sprite:GetAnimation() or ""
	end)
	if ok then return name or "" end
	return ""
end

function item.get_selected_menu_info()
	if not (CharacterMenu and CharacterMenu.GetSelectedCharacterPlayerType) then return nil, nil end
	local ok, ptype = pcall(CharacterMenu.GetSelectedCharacterPlayerType)
	if not ok or type(ptype) ~= "number" then return nil, nil end
	for _, info in ipairs(PLAYER_MENUS) do
		if enums.Players[info.key] == ptype then return info.anim, info.family end
	end
	return nil, nil
end

function item.load_menu_sprite(sprite, anm2_path, anim, force_load)
	if not sprite or not anm2_path then return false end
	local hash
	local hash_ok, got = pcall(GetPtrHash, sprite)
	if hash_ok then hash = got end
	if not force_load and hash and item.loaded_by_hash[hash] == anm2_path then
		return true
	end
	local current_anim = item.get_sprite_animation(sprite)
	if current_anim == "" then current_anim = anim end
	local ok, err = pcall(function()
		sprite:Load(anm2_path, true)
		if current_anim and current_anim ~= "" then
			sprite:Play(current_anim, true)
		end
	end)
	if not ok then
		print("QING:: Character menu load failed: "..tostring(anm2_path).." :: "..tostring(err))
		return false
	end
	if hash then item.loaded_by_hash[hash] = anm2_path end
	return true
end

function item.apply_character_select(lang, force_load)
	local sheets = manifest.character_select
	if sheets and sheets.enabled == false then return end
	if not (EntityConfig and EntityConfig.GetPlayer) then return end
	local seen = {}
	local selected_anim, selected_family = item.get_selected_menu_info()
	for _, player_info in ipairs(PLAYER_MENUS) do
		local player_type = enums.Players[player_info.key]
		if type(player_type) == "number" and player_type >= 0 then
			local ok, config = pcall(function()
				return EntityConfig.GetPlayer(player_type)
			end)
			if ok and config and config.GetModdedMenuBackgroundSprite then
				local sprite_ok, sprite = pcall(function()
					return config:GetModdedMenuBackgroundSprite()
				end)
				if sprite_ok and sprite then
					local hash
					local hash_ok, got = pcall(GetPtrHash, sprite)
					if hash_ok then hash = got end
					if not (hash and seen[hash]) then
						if hash then seen[hash] = true end
						local anim = player_info.anim
						if selected_anim and player_info.family == selected_family then
							anim = selected_anim
						end
						item.load_menu_sprite(sprite, item.anm2_for(player_info.family, lang), anim, force_load)
					end
				end
			end
		end
	end
	if force_load and CharacterMenu and CharacterMenu.GetSelectedCharacterID and CharacterMenu.SetSelectedCharacterID then
		local id_ok, char_id = pcall(CharacterMenu.GetSelectedCharacterID)
		if id_ok and type(char_id) == "number" then
			pcall(CharacterMenu.SetSelectedCharacterID, char_id)
		end
	end
end

function item.apply_shared_player_sprite(lang, section, getter_name, force_load)
	local anm2_path = item.section_anm2(section, lang)
	if not anm2_path then return end
	if not (EntityConfig and EntityConfig.GetPlayer) then return end
	local play_anim = item.get_play_anim()
	local seen = {}
	for _, player_info in ipairs(PLAYER_MENUS) do
		local player_type = enums.Players[player_info.key]
		if type(player_type) == "number" and player_type >= 0 then
			local ok, config = pcall(function()
				return EntityConfig.GetPlayer(player_type)
			end)
			if ok and config and config[getter_name] then
				local sprite_ok, sprite = pcall(function()
					return config[getter_name](config)
				end)
				if sprite_ok and sprite then
					local hash
					local hash_ok, got = pcall(GetPtrHash, sprite)
					if hash_ok then hash = got end
					if not (hash and seen[hash]) then
						if hash then seen[hash] = true end
						item.load_menu_sprite(sprite, anm2_path, play_anim or player_info.anim, force_load)
					end
				end
			end
		end
	end
end

function item.try_load_sprite(sprite, anm2_path, anim, key)
	if not sprite or not anm2_path then return false end
	if item.failed[key] then return false end
	local ok, err = pcall(function()
		sprite:Load(anm2_path, true)
		if anim then sprite:Play(anim, true) end
	end)
	if not ok then
		item.failed[key] = true
		print("QING:: Menu language asset failed: "..tostring(key).." -> "..tostring(anm2_path).." :: "..tostring(err))
		return false
	end
	return true
end

function item.apply_global(info, lang)
	if type(info.global) ~= "table" then return end
	local skip_title = manifest.title_logo and manifest.title_logo.enabled
	if not skip_title and TitleMenu and TitleMenu.GetSprite then
		local ok, sprite = pcall(TitleMenu.GetSprite)
		item.try_load_sprite(ok and sprite or nil, item.full_path(info, info.global.title), nil, lang..":global:title")
	end
	if MainMenu and MainMenu.GetGameMenuSprite then
		local ok, sprite = pcall(MainMenu.GetGameMenuSprite)
		item.try_load_sprite(ok and sprite or nil, item.full_path(info, info.global.main), nil, lang..":global:main")
	end
end

function item.apply_player(info, player_info, lang)
	local player_type = enums.Players[player_info.key]
	if not player_type or player_type < 0 then return end
	local config = EntityConfig and EntityConfig.GetPlayer and EntityConfig.GetPlayer(player_type)
	if not config then return end
	for field, getter in pairs(sprite_getters) do
		local ok, sprite = pcall(function()
			if config[getter] then return config[getter](config) end
		end)
		if not ok then sprite = nil end
		local path = item.full_path(info, player_info[field])
		item.try_load_sprite(sprite, path, player_info.anim, lang..":"..player_info.key..":"..field)
	end
end

function item.apply_language(force)
	if not REPENTOGON then return end
	local select_lang = item.get_language("CharacterSelectLanguage")
	item.apply_character_select(select_lang, force == true)
	item.apply_shared_player_sprite(item.get_language("ControlsLanguage"), "controls", "GetModdedControlsSprite", force == true)
	item.apply_shared_player_sprite(item.get_language("GameOverLanguage"), "game_over", "GetModdedGameOverSprite", force == true)
	if manifest.enabled == true and (force or item.applied_language ~= select_lang) then
		local info = manifest.languages and manifest.languages[select_lang]
		if info then
			item.failed = {}
			item.apply_global(info, select_lang)
			for _, player_info in ipairs(info.players or {}) do
				item.apply_player(info, player_info, select_lang)
			end
		end
	end
	item.applied_language = select_lang
end

function item.register_console()
	if item.console_registered then return end
	if Console and Console.RegisterCommand then
		local autocomplete = AutocompleteType and AutocompleteType.NONE or 0
		Console.RegisterCommand("qing_menu_lang_reload", "Reload Qing Remaster menu language assets.", "qing_menu_lang_reload", true, autocomplete)
		item.console_registered = true
	end
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_MAIN_MENU_RENDER, params = nil,
Function = function(_)
	item.apply_language(false)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_)
	item.loaded_by_hash = {}
	item.apply_language(true)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_EXECUTE_CMD, params = nil,
Function = function(_, cmd, params)
	if string.lower(cmd or "") == "qing_menu_lang_reload" then
		item.applied_language = nil
		item.loaded_by_hash = {}
		item.apply_language(true)
		print("QING:: Menu language reload requested. enabled="..tostring(manifest.enabled)
			.." select="..tostring(item.get_language("CharacterSelectLanguage"))
			.." controls="..tostring(item.get_language("ControlsLanguage"))
			.." game_over="..tostring(item.get_language("GameOverLanguage")))
	end
end,
})

function item.Init(mod)
	item.register_console()
	item.apply_language(true)
end

if REPENTOGON then
	item.register_console()
	item.apply_language(true)
end

return item
