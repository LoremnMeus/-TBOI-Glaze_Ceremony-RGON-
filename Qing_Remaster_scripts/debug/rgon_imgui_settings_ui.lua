-- Settings + Achievements ImGui builders (extracted from rgon_imgui_options_holder).
-- Registration only; option storage remains on the holder.

local M = {}

function M.build(api)
	local item = api.item
	local text = api.text
	local add_text = api.add_text
	local add_checkbox = api.add_checkbox
	local add_drag_float = api.add_drag_float
	local add_drag_pair_path = api.add_drag_pair_path
	local add_group = api.add_group
	local add_separator = api.add_separator
	local add_reset_button = api.add_reset_button
	local imgui_layout = api.imgui_layout
	local ImGui = api.ImGui
	local enums = api.enums
	local auxi = api.auxi
	local save = api.save
	local ModConfig = api.ModConfig
	local translations = api.translations
	local item_color_holder = api.item_color_holder
	local achievement_tracker = api.achievement_tracker
	local CompletionMarks = api.CompletionMarks
	local unlock_board = api.unlock_board
	local dev_env = api.dev_env
	local probe_registry = api.probe_registry
	local push_notice = api.push_notice
	local error_notice_type = api.error_notice_type
	local language_key = api.language_key
	local setup_window = api.setup_window
	local save_mod_data = api.save_mod_data
	local DEBUG_PAGE = api.DEBUG_PAGE
	local register_debug_module = api.register_debug_module
	local set_module_footer = api.set_module_footer
	local start_mod = api.start_mod
	local start_probe_module = api.start_probe_module
	local page_parent = api.page_parent
	local recent_tab = api.recent_tab
	local items_tab = api.items_tab
	local characters_tab = api.characters_tab
	local systems_tab = api.systems_tab
	local visual_tab = api.visual_tab
	local data_tab = api.data_tab
	local tests_tab = api.tests_tab
	local story_test_tab = api.story_test_tab


local function card_display_name(card_id)
	local lang = language_key()
	for _, entry in pairs(translations.Collectibles or {}) do
		if entry and entry.type == "card" and entry.id == card_id then
			local block = entry[lang] or entry.zh or entry.en
			if block and block.Name then return tostring(block.Name) end
			if entry.Name then return tostring(entry.Name) end
		end
	end
	local cfg = Isaac.GetItemConfig and Isaac.GetItemConfig():GetCard(card_id)
	if cfg and cfg.Name then return tostring(cfg.Name) end
	return "Card "..tostring(card_id)
end

local function add_card_rates_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupCardAppearRates",text("tab_cards"))
	add_text(group,text("card_rates_help"))
	local card_all = require("Qing_Remaster_scripts.cards.Card_All")
	for _, entry in ipairs(card_all.list_configurable_cards()) do
		local element_id = "QingRemasterOptions_CardAppear_"..tostring(entry.id)
		local label = card_display_name(entry.id)..text("card_rate_suffix")
		ImGui.AddDragFloat(group,element_id,label,function(value)
			card_all.set_card_appear_rate(entry.id,value)
		end,card_all.get_card_appear_rate(entry.id),0.01,0,1,"%.2f")
		ImGui.AddCallback(element_id,ImGuiCallback.Render,function()
			ImGui.UpdateData(element_id,ImGuiData.Value,card_all.get_card_appear_rate(entry.id))
		end)
	end
	ImGui.AddButton(group,"QingRemasterOptions_CardAppearRestore",text("card_rates_restore"),function()
		card_all.reset_card_appear_rates()
		push_notice(text("card_rates_restore"))
	end)
end

	local schema = require("Qing_Remaster_scripts.others.mod_config_schema")
	local function schema_label(key)
		local entry = schema.entry(key)
		return entry and schema.entry_text(entry, "label") or text(key)
	end
	local function schema_help(key)
		local entry = schema.entry(key)
		return entry and schema.entry_text(entry, "help") or nil
	end

	local settings_item = item.menu_id.."_SettingsItem"
	local window_id = item.settings_id
	local tabbar = window_id.."_TabBar"
	local tabs = {
		Compatibility = tabbar.."_Compatibility",
		Gameplay = tabbar.."_Gameplay",
		HUD = tabbar.."_HUD",
		Controls = tabbar.."_Controls",
		Cards = tabbar.."_Cards",
	}

	ImGui.AddElement(item.menu_id, settings_item, ImGuiElement.MenuItem, text("settings_item"))
	ImGui.CreateWindow(window_id, text("settings_title"))
	setup_window(window_id, item.default_window.settings)
	ImGui.LinkWindowToElement(window_id, settings_item)
	ImGui.AddTabBar(window_id, tabbar)
	ImGui.AddTab(tabbar, tabs.Compatibility, text("tab_compatibility"))
	ImGui.AddTab(tabbar, tabs.Gameplay, text("tab_gameplay"))
	ImGui.AddTab(tabbar, tabs.HUD, text("tab_hud"))
	ImGui.AddTab(tabbar, tabs.Controls, text("tab_controls"))
	ImGui.AddTab(tabbar, tabs.Cards, text("tab_cards"))

	local compatibility_rgon = add_group(tabs.Compatibility, "QingRemasterOptions_GroupCompatibilityRgon", text("group_rgon"))
	add_checkbox(compatibility_rgon, "QingRemasterOptions_UseRgonImitateItems", schema_label("UseRgonImitateItems"), {"QingRemasterOptions", "Compatibility", "UseRgonImitateItems"}, schema_help("UseRgonImitateItems"))

	local gameplay_runtime = add_group(tabs.Gameplay, "QingRemasterOptions_GroupGameplayRuntime", text("group_runtime"))
	add_checkbox(gameplay_runtime, "QingRemasterOptions_ItemsAllow", schema_label("Items_allow"), {"Items_allow"}, schema_help("Items_allow"))
	add_checkbox(gameplay_runtime, "QingRemasterOptions_TrinketsAllow", schema_label("Trinkets_allow"), {"Trinkets_allow"}, schema_help("Trinkets_allow"))
	add_checkbox(gameplay_runtime, "QingRemasterOptions_PickupAllow", schema_label("Pickup_allow"), {"Pickup_allow"}, schema_help("Pickup_allow"))
	add_checkbox(gameplay_runtime, "QingRemasterOptions_BossAllow", schema_label("Boss_allow"), {"Boss_allow"}, schema_help("Boss_allow"))
	add_checkbox(gameplay_runtime, "QingRemasterOptions_AutoLive", schema_label("Auto_Live"), {"Auto_Live"}, schema_help("Auto_Live"))
	add_checkbox(gameplay_runtime, "QingRemasterOptions_AchievementAllow", schema_label("Achievement_allow"), {"Achievement_allow"}, schema_help("Achievement_allow"))
	add_checkbox(gameplay_runtime, "QingRemasterOptions_AchievementPoolGating", schema_label("Achievement_pool_gating"), {"Achievement_pool_gating"}, schema_help("Achievement_pool_gating"))
	add_checkbox(gameplay_runtime, "QingRemasterOptions_AchievementTrinketGating", schema_label("Achievement_trinket_gating"), {"Achievement_trinket_gating"}, schema_help("Achievement_trinket_gating"))
	add_checkbox(gameplay_runtime, "QingRemasterOptions_AchievementCardGating", schema_label("Achievement_card_gating"), {"Achievement_card_gating"}, schema_help("Achievement_card_gating"))
	add_checkbox(gameplay_runtime, "QingRemasterOptions_AchievementPickupGating", schema_label("Achievement_pickup_gating"), {"Achievement_pickup_gating"}, schema_help("Achievement_pickup_gating"))

	local controls_group = add_group(tabs.Controls, "QingRemasterOptions_GroupControls", text("group_controls"))
	local function add_keyboard_binding(entry_key, element_id)
		local entry = schema.entry(entry_key)
		if not entry then return end
		ImGui.AddInputKeyboard(controls_group, element_id, schema.entry_text(entry, "label"), function(code)
			schema.write(entry, tonumber(code))
		end, tonumber(schema.read(entry)) or 0)
		ImGui.AddCallback(element_id, ImGuiCallback.Render, function()
			ImGui.UpdateData(element_id, ImGuiData.Value, tonumber(schema.read(entry)) or 0)
		end)
		imgui_layout.set_helpmarker(element_id, schema.entry_text(entry, "help"))
	end
	add_keyboard_binding("thor_key", "QingRemasterOptions_ThorKey")
	local thor_controller_entry = schema.entry("thor_controller")
	ImGui.AddInputInteger(controls_group, "QingRemasterOptions_ThorController", schema.entry_text(thor_controller_entry, "label"), function(value)
		schema.write(thor_controller_entry, math.floor(tonumber(value) or 0))
	end, tonumber(schema.read(thor_controller_entry)) or 12, 1, 4)
	ImGui.AddCallback("QingRemasterOptions_ThorController", ImGuiCallback.Render, function()
		ImGui.UpdateData("QingRemasterOptions_ThorController", ImGuiData.Value, tonumber(schema.read(thor_controller_entry)) or 12)
	end)
	imgui_layout.set_helpmarker("QingRemasterOptions_ThorController", schema.entry_text(thor_controller_entry, "help"))
	add_keyboard_binding("Off_air_key", "QingRemasterOptions_OffAirKey")
	add_checkbox(controls_group, "QingRemasterOptions_AllowMouseControl", schema_label("allow_mouse_control"), {"allow_mouse_control"}, schema_help("allow_mouse_control"))
	local mouse_entry = schema.entry("mouseSupport")
	local mouse_labels = {}
	for index, choice in ipairs(mouse_entry.choices) do
		mouse_labels[index] = schema.choice_label(choice)
	end
	ImGui.AddCombobox(controls_group, "QingRemasterOptions_MouseSupport", schema.entry_text(mouse_entry, "label"), function(index)
		schema.write(mouse_entry, (tonumber(index) or 0) + 1)
	end, mouse_labels, math.max(0, schema.mouse_mode() - 1))
	ImGui.AddCallback("QingRemasterOptions_MouseSupport", ImGuiCallback.Render, function()
		ImGui.UpdateData("QingRemasterOptions_MouseSupport", ImGuiData.Value, math.max(0, schema.mouse_mode() - 1))
	end)
	imgui_layout.set_helpmarker("QingRemasterOptions_MouseSupport", schema.entry_text(mouse_entry, "help"))

	local hud_imitate = add_group(tabs.HUD, "QingRemasterOptions_GroupHudImitate", text("group_hud_imitate"))
	add_text(hud_imitate, text("temp_hud_layout_help"))
	add_checkbox(hud_imitate, "QingRemasterOptions_ShowTempItemHUD", text("show_temp_item_hud"), {"QingRemasterOptions", "Gameplay", "ShowTempItemHUD"}, text("show_temp_item_hud_help"))
	add_drag_float(hud_imitate, "QingRemasterOptions_TempHUD_LargePadX", text("temp_hud_large_pad_x"), {"QingRemasterOptions", "Gameplay", "TempHUD_LargePadX"}, nil, 0.25, -64, 64, "%.2f")
	add_drag_float(hud_imitate, "QingRemasterOptions_TempHUD_LargePadY", text("temp_hud_large_pad_y"), {"QingRemasterOptions", "Gameplay", "TempHUD_LargePadY"}, nil, 0.25, -64, 64, "%.2f")
	add_drag_float(hud_imitate, "QingRemasterOptions_TempHUD_MiniPadX", text("temp_hud_mini_pad_x"), {"QingRemasterOptions", "Gameplay", "TempHUD_MiniPadX"}, nil, 0.25, -64, 64, "%.2f")
	add_drag_float(hud_imitate, "QingRemasterOptions_TempHUD_MiniPadY", text("temp_hud_mini_pad_y"), {"QingRemasterOptions", "Gameplay", "TempHUD_MiniPadY"}, nil, 0.25, -64, 64, "%.2f")
	add_drag_float(hud_imitate, "QingRemasterOptions_TempHUD_LargeStep", text("temp_hud_large_step"), {"QingRemasterOptions", "Gameplay", "TempHUD_LargeStep"}, nil, 0.5, 4, 64, "%.1f")
	add_drag_float(hud_imitate, "QingRemasterOptions_TempHUD_MiniStep", text("temp_hud_mini_step"), {"QingRemasterOptions", "Gameplay", "TempHUD_MiniStep"}, nil, 0.5, 4, 64, "%.1f")
	ImGui.AddButton(hud_imitate, "QingRemasterOptions_TempHUD_Restore", text("temp_hud_restore"), function()
		local defaults = {
			ShowTempItemHUD = true,
			TempHUD_LargePadX = 16,
			TempHUD_LargePadY = 38,
			TempHUD_MiniPadX = 8,
			TempHUD_MiniPadY = 19,
			TempHUD_LargeStep = 32,
			TempHUD_MiniStep = 16,
		}
		for key,value in pairs(defaults) do item.set_value({"QingRemasterOptions","Gameplay",key},value) end
	end)

	local function apply_menu_language()
		local holder = require("Qing_Remaster_scripts.callbacks.rgon_menu_language_holder")
		if holder then
			holder.loaded_by_hash = {}
			holder.applied_language = nil
			if holder.apply_language then holder.apply_language(true) end
		end
	end
	local function refresh_title_logo_settings()
		local holder = require("Qing_Remaster_scripts.callbacks.title_menu_logo_holder")
		if holder then
			if holder.reset_overlay_cache then holder.reset_overlay_cache() end
			if holder.refresh_vanilla_logo then holder.refresh_vanilla_logo() end
		end
	end
	local function set_all_menu_languages(mode)
		local holder = require("Qing_Remaster_scripts.callbacks.rgon_menu_language_holder")
		if holder and holder.set_all_force_modes then
			holder.set_all_force_modes(mode)
			return
		end
		for _, key in ipairs({
			"CharacterSelectLanguage",
			"ControlsLanguage",
			"GameOverLanguage",
			"TitleLogoLanguage",
		}) do
			item.set_value({"QingRemasterOptions", "Menu", key}, mode)
		end
		apply_menu_language()
		refresh_title_logo_settings()
	end
	local force_all_group = add_group(tabs.HUD, "QingRemasterOptions_GroupMenuLangForceAll", text("group_menu_lang_force_all"))
	add_text(force_all_group, text("menu_lang_force_all_help"))
	local force_all_status_id = "QingRemasterOptions_MenuLangForceAllStatus"
	imgui_layout.add_wrapped_text(force_all_group, force_all_status_id, "")
	ImGui.AddCallback(force_all_status_id, ImGuiCallback.Render, function()
		local holder = require("Qing_Remaster_scripts.callbacks.rgon_menu_language_holder")
		local sheets, game_lang = "en/en/en/en", "en"
		if holder and holder.describe_all_force_status then
			sheets, game_lang = holder.describe_all_force_status()
		end
		imgui_layout.update_text(force_all_status_id, string.format(text("menu_lang_force_all_status"), sheets, game_lang))
	end)
	ImGui.AddButton(force_all_group, "QingRemasterOptions_MenuLangForceAllAuto", text("character_menu_lang_auto"), function()
		set_all_menu_languages(0)
	end)
	ImGui.AddButton(force_all_group, "QingRemasterOptions_MenuLangForceAllZh", text("character_menu_lang_zh"), function()
		set_all_menu_languages(1)
	end)
	ImGui.AddButton(force_all_group, "QingRemasterOptions_MenuLangForceAllEn", text("character_menu_lang_en"), function()
		set_all_menu_languages(2)
	end)

	local function add_menu_language_group(setting_key, group_text_key, help_key, status_key, id_stem, on_apply)
		local function set_mode(mode)
			item.set_value({"QingRemasterOptions", "Menu", setting_key}, mode)
			if on_apply then
				on_apply()
			else
				apply_menu_language()
			end
		end
		local group = add_group(tabs.HUD, "QingRemasterOptions_Group"..id_stem.."Lang", text(group_text_key))
		add_text(group, text(help_key))
		local status_id = "QingRemasterOptions_"..id_stem.."LangStatus"
		imgui_layout.add_wrapped_text(group, status_id, "")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local holder = require("Qing_Remaster_scripts.callbacks.rgon_menu_language_holder")
			local current = holder and holder.get_language and holder.get_language(setting_key) or "en"
			local game_lang = holder and holder.get_game_language and holder.get_game_language() or "en"
			imgui_layout.update_text(status_id, string.format(text(status_key), current, game_lang))
		end)
		ImGui.AddButton(group, "QingRemasterOptions_"..id_stem.."LangAuto", text("character_menu_lang_auto"), function()
			set_mode(0)
		end)
		ImGui.AddButton(group, "QingRemasterOptions_"..id_stem.."LangZh", text("character_menu_lang_zh"), function()
			set_mode(1)
		end)
		ImGui.AddButton(group, "QingRemasterOptions_"..id_stem.."LangEn", text("character_menu_lang_en"), function()
			set_mode(2)
		end)
	end
	add_menu_language_group("CharacterSelectLanguage", "group_character_menu_lang", "character_menu_lang_help", "character_menu_lang_status", "CharacterSelect")
	add_menu_language_group("ControlsLanguage", "group_controls_lang", "controls_lang_help", "controls_lang_status", "Controls")
	add_menu_language_group("GameOverLanguage", "group_game_over_lang", "game_over_lang_help", "game_over_lang_status", "GameOver")

	local title_logo_group = add_group(tabs.HUD, "QingRemasterOptions_GroupTitleLogo", text("group_title_logo"))
	add_text(title_logo_group, text("title_logo_help"))
	local title_logo_custom_path = {"QingRemasterOptions", "Menu", "TitleLogoCustom"}
	ImGui.AddCheckbox(title_logo_group, "QingRemasterOptions_TitleLogoCustom", text("title_logo_custom"), nil, item.get_value(title_logo_custom_path) == true)
	ImGui.AddCallback("QingRemasterOptions_TitleLogoCustom", ImGuiCallback.Render, function()
		ImGui.UpdateData("QingRemasterOptions_TitleLogoCustom", ImGuiData.Value, item.get_value(title_logo_custom_path) == true)
	end)
	ImGui.AddCallback("QingRemasterOptions_TitleLogoCustom", ImGuiCallback.Edited, function(value)
		item.set_value(title_logo_custom_path, value == true)
		refresh_title_logo_settings()
	end)
	imgui_layout.set_helpmarker("QingRemasterOptions_TitleLogoCustom", text("title_logo_custom_help"))
	local title_logo_rainbow_path = {"QingRemasterOptions", "Menu", "TitleLogoRainbow"}
	ImGui.AddCheckbox(title_logo_group, "QingRemasterOptions_TitleLogoRainbow", text("title_logo_rainbow"), nil, item.get_value(title_logo_rainbow_path) ~= false)
	ImGui.AddCallback("QingRemasterOptions_TitleLogoRainbow", ImGuiCallback.Render, function()
		ImGui.UpdateData("QingRemasterOptions_TitleLogoRainbow", ImGuiData.Value, item.get_value(title_logo_rainbow_path) ~= false)
	end)
	ImGui.AddCallback("QingRemasterOptions_TitleLogoRainbow", ImGuiCallback.Edited, function(value)
		item.set_value(title_logo_rainbow_path, value == true)
	end)
	imgui_layout.set_helpmarker("QingRemasterOptions_TitleLogoRainbow", text("title_logo_rainbow_help"))
	local title_logo_rainbow_solo_path = {"QingRemasterOptions", "Menu", "TitleLogoRainbowSolo"}
	ImGui.AddCheckbox(title_logo_group, "QingRemasterOptions_TitleLogoRainbowSolo", text("title_logo_rainbow_solo"), nil, item.get_value(title_logo_rainbow_solo_path) == true)
	ImGui.AddCallback("QingRemasterOptions_TitleLogoRainbowSolo", ImGuiCallback.Render, function()
		ImGui.UpdateData("QingRemasterOptions_TitleLogoRainbowSolo", ImGuiData.Value, item.get_value(title_logo_rainbow_solo_path) == true)
	end)
	ImGui.AddCallback("QingRemasterOptions_TitleLogoRainbowSolo", ImGuiCallback.Edited, function(value)
		item.set_value(title_logo_rainbow_solo_path, value == true)
	end)
	imgui_layout.set_helpmarker("QingRemasterOptions_TitleLogoRainbowSolo", text("title_logo_rainbow_solo_help"))
	add_drag_float(title_logo_group, "QingRemasterOptions_TitleLogoRainbowLumLow", text("title_logo_rainbow_lum_low"), {"QingRemasterOptions", "Menu", "TitleLogoRainbowLumLow"}, text("title_logo_rainbow_lum_help"), 0.01, 0, 1, "%.2f")
	add_drag_float(title_logo_group, "QingRemasterOptions_TitleLogoRainbowLumHigh", text("title_logo_rainbow_lum_high"), {"QingRemasterOptions", "Menu", "TitleLogoRainbowLumHigh"}, text("title_logo_rainbow_lum_help"), 0.01, 0, 1, "%.2f")
	add_drag_float(title_logo_group, "QingRemasterOptions_TitleLogoRainbowTextLumLow", text("title_logo_rainbow_text_lum_low"), {"QingRemasterOptions", "Menu", "TitleLogoRainbowTextLumLow"}, text("title_logo_rainbow_text_lum_help"), 0.01, 0, 1, "%.2f")
	add_drag_float(title_logo_group, "QingRemasterOptions_TitleLogoRainbowTextLumHigh", text("title_logo_rainbow_text_lum_high"), {"QingRemasterOptions", "Menu", "TitleLogoRainbowTextLumHigh"}, text("title_logo_rainbow_text_lum_help"), 0.01, 0, 1, "%.2f")
	add_drag_float(title_logo_group, "QingRemasterOptions_TitleLogoRainbowSpatialAngle", text("title_logo_rainbow_spatial_angle"), {"QingRemasterOptions", "Menu", "TitleLogoRainbowSpatialAngle"}, text("title_logo_rainbow_spatial_help"), 1, 0, 360, "%.0f")
	add_drag_float(title_logo_group, "QingRemasterOptions_TitleLogoRainbowSpatialDensity", text("title_logo_rainbow_spatial_density"), {"QingRemasterOptions", "Menu", "TitleLogoRainbowSpatialDensity"}, text("title_logo_rainbow_spatial_help"), 0.05, 0.25, 6, "%.2f")
	add_drag_float(title_logo_group, "QingRemasterOptions_TitleLogoRainbowSpeed", text("title_logo_rainbow_speed"), {"QingRemasterOptions", "Menu", "TitleLogoRainbowSpeed"}, text("title_logo_rainbow_motion_help"), 0.05, 0, 4, "%.2f")
	add_drag_float(title_logo_group, "QingRemasterOptions_TitleLogoRainbowDirection", text("title_logo_rainbow_direction"), {"QingRemasterOptions", "Menu", "TitleLogoRainbowDirection"}, text("title_logo_rainbow_motion_help"), 1, -1, 1, "%.0f")
	add_drag_float(title_logo_group, "QingRemasterOptions_TitleLogoRainbowGrayHue", text("title_logo_rainbow_gray_hue"), {"QingRemasterOptions", "Menu", "TitleLogoRainbowGrayHue"}, text("title_logo_rainbow_style_help"), 0.01, 0, 1, "%.2f")
	add_drag_float(title_logo_group, "QingRemasterOptions_TitleLogoRainbowBend", text("title_logo_rainbow_bend"), {"QingRemasterOptions", "Menu", "TitleLogoRainbowBend"}, text("title_logo_rainbow_style_help"), 0.01, 0, 1, "%.2f")
	add_drag_float(title_logo_group, "QingRemasterOptions_TitleLogoRainbowShapeContrast", text("title_logo_rainbow_shape_contrast"), {"QingRemasterOptions", "Menu", "TitleLogoRainbowShapeContrast"}, text("title_logo_rainbow_style_help"), 0.01, 0, 1, "%.2f")
	local title_logo_rainbow_status_id = "QingRemasterOptions_TitleLogoRainbowStatus"
	imgui_layout.add_wrapped_text(title_logo_group, title_logo_rainbow_status_id, "")
	ImGui.AddCallback(title_logo_rainbow_status_id, ImGuiCallback.Render, function()
		local holder = require("Qing_Remaster_scripts.callbacks.title_menu_logo_holder")
		local status = holder and holder.rainbow_debug_status and holder.rainbow_debug_status() or "n/a"
		imgui_layout.update_text(title_logo_rainbow_status_id, string.format(text("title_logo_rainbow_status"), status))
	end)
	add_text(title_logo_group, text("title_logo_lang_help"))
	local title_logo_lang_status_id = "QingRemasterOptions_TitleLogoLangStatus"
	imgui_layout.add_wrapped_text(title_logo_group, title_logo_lang_status_id, "")
	ImGui.AddCallback(title_logo_lang_status_id, ImGuiCallback.Render, function()
		local holder = require("Qing_Remaster_scripts.callbacks.rgon_menu_language_holder")
		local current = holder and holder.get_language and holder.get_language("TitleLogoLanguage") or "en"
		local game_lang = holder and holder.get_game_language and holder.get_game_language() or "en"
		imgui_layout.update_text(title_logo_lang_status_id, string.format(text("title_logo_lang_status"), current, game_lang))
	end)
	ImGui.AddButton(title_logo_group, "QingRemasterOptions_TitleLogoLangAuto", text("character_menu_lang_auto"), function()
		item.set_value({"QingRemasterOptions", "Menu", "TitleLogoLanguage"}, 0)
		refresh_title_logo_settings()
	end)
	ImGui.AddButton(title_logo_group, "QingRemasterOptions_TitleLogoLangZh", text("character_menu_lang_zh"), function()
		item.set_value({"QingRemasterOptions", "Menu", "TitleLogoLanguage"}, 1)
		refresh_title_logo_settings()
	end)
	ImGui.AddButton(title_logo_group, "QingRemasterOptions_TitleLogoLangEn", text("character_menu_lang_en"), function()
		item.set_value({"QingRemasterOptions", "Menu", "TitleLogoLanguage"}, 2)
		refresh_title_logo_settings()
	end)
	add_drag_float(title_logo_group, "QingRemasterOptions_TitleLogoOffsetX", text("title_logo_offset_x"), {"QingRemasterOptions", "Menu", "TitleLogoOffsetX"}, text("title_logo_offset_help"), 1, -200, 200, "%.0f")
	add_drag_float(title_logo_group, "QingRemasterOptions_TitleLogoOffsetY", text("title_logo_offset_y"), {"QingRemasterOptions", "Menu", "TitleLogoOffsetY"}, text("title_logo_offset_help"), 1, -200, 200, "%.0f")
	ImGui.AddButton(title_logo_group, "QingRemasterOptions_TitleLogoOffsetRestore", text("title_logo_offset_restore"), function()
		item.set_value({"QingRemasterOptions", "Menu", "TitleLogoOffsetX"}, -39)
		item.set_value({"QingRemasterOptions", "Menu", "TitleLogoOffsetY"}, -15)
	end)

	add_card_rates_group(tabs.Cards)

	local maintenance_group = add_group(window_id, "QingRemasterOptions_GroupMaintenance", text("group_maintenance"))
	add_reset_button(maintenance_group, text("reset_defaults"))
end

function M.build_achievements(api)
	local item = api.item
	local text = api.text
	local add_text = api.add_text
	local add_checkbox = api.add_checkbox
	local add_drag_float = api.add_drag_float
	local add_drag_pair_path = api.add_drag_pair_path
	local add_group = api.add_group
	local add_separator = api.add_separator
	local add_reset_button = api.add_reset_button
	local imgui_layout = api.imgui_layout
	local ImGui = api.ImGui
	local enums = api.enums
	local auxi = api.auxi
	local save = api.save
	local ModConfig = api.ModConfig
	local translations = api.translations
	local item_color_holder = api.item_color_holder
	local achievement_tracker = api.achievement_tracker
	local CompletionMarks = api.CompletionMarks
	local unlock_board = api.unlock_board
	local dev_env = api.dev_env
	local probe_registry = api.probe_registry
	local push_notice = api.push_notice
	local error_notice_type = api.error_notice_type
	local language_key = api.language_key
	local setup_window = api.setup_window
	local save_mod_data = api.save_mod_data
	local DEBUG_PAGE = api.DEBUG_PAGE
	local register_debug_module = api.register_debug_module
	local set_module_footer = api.set_module_footer
	local start_mod = api.start_mod
	local start_probe_module = api.start_probe_module
	local page_parent = api.page_parent
	local recent_tab = api.recent_tab
	local items_tab = api.items_tab
	local characters_tab = api.characters_tab
	local systems_tab = api.systems_tab
	local visual_tab = api.visual_tab
	local data_tab = api.data_tab
	local tests_tab = api.tests_tab
	local story_test_tab = api.story_test_tab


local ACHIEVEMENT_LABELS = {
	Glaze = {en = "Glaze", zh = "琉璃"},
	BossZeis = {en = "Zeis", zh = "泽伊斯"},
	Others = {en = "Other achievements", zh = "其他成就"},
	MomsHeart = {en = "Mom's Heart", zh = "妈妈的心脏"},
	Isaac = {en = "Isaac", zh = "以撒"},
	Satan = {en = "Satan", zh = "撒旦"},
	BlueBaby = {en = "???", zh = "???"},
	Lamb = {en = "The Lamb", zh = "羔羊"},
	BossRush = {en = "Boss Rush", zh = "头目挑战"},
	Hush = {en = "Hush", zh = "死寂"},
	MegaSatan = {en = "Mega Satan", zh = "超级撒旦"},
	Delirium = {en = "Delirium", zh = "精神错乱"},
	Mother = {en = "Mother", zh = "母亲"},
	Beast = {en = "The Beast", zh = "祸兽"},
	GreedMode = {en = "Greed Mode", zh = "贪婪模式"},
	FullCompletion = {en = "Full Completion", zh = "全完成标记"},
	Ending1 = {en = "Ending I", zh = "结局一"},
	Ending2 = {en = "Ending II", zh = "结局二"},
	Ending3 = {en = "Ending III", zh = "结局三"},
	Crown_of_the_Glaze = {en = "Crown of the Glaze", zh = "琉璃之冠"},
	Crushed = {en = "Crushed", zh = "被碾碎"},
	Thoth = {en = "Book of Thoth", zh = "透特之书"},
	Law = {en = "Book of the Law", zh = "法之书"},
	Voice = {en = "Book of Voice", zh = "假象之书"},
	Vision = {en = "Book of Vision", zh = "觅之书"},
	Coin = {en = "Coin storyline", zh = "钱币剧情"},
	Future = {en = "Book of Future", zh = "未来之书"},
	Cookie_Clicker = {en = "Cookie Clicker", zh = "挑战：曲奇点击者"},
	Dragon_Flight = {en = "Dragon Flight", zh = "挑战：飞龙在天"},
	Fans_Service = {en = "Fans Service", zh = "挑战：粉丝服务"},
	Feels_Like_Dead_Ashes = {en = "Feels Like Dead Ashes", zh = "挑战：心如死灰"},
	Fusion_Destiny = {en = "Fusion Destiny", zh = "挑战：命运融合"},
	Heterothermal_Concentric = {en = "Heterothermal Concentric", zh = "挑战：异热同心"},
	Invisible = {en = "Invisible", zh = "挑战：不为人知"},
	Louvre_puzzle = {en = "Louvre Puzzle", zh = "挑战：卢浮宫难题"},
	Pointing = {en = "Pointing and Disappointing", zh = "挑战：指指点点"},
	Safe_Driving = {en = "Safe Driving", zh = "挑战：安全驾驶"},
	Swallow_The_Sun = {en = "Swallow the Sun", zh = "挑战：食日"},
	Unstable_State = {en = "Unstable State", zh = "挑战：不稳定体"},
}

local CATEGORY_PLAYER_IDS = {
	wq = enums.Players.wq,
	Spwq = enums.Players.Spwq,
	Tecro = enums.Players.Tecro,
	Tecrorun = enums.Players.Tecrorun,
	Anna = enums.Players.Anna,
	annA = enums.Players.annA,
	Zeis = enums.Players.Zeistos,
	Zeiz = enums.Players.Zeiz,
}

local BOSS_PLAYER_NAME_TOKENS = {
	Isaac = {"#ISAAC_NAME","Isaac"},
	Maggy = {"#MAGDALENE_NAME","Magdalene"},
	Cain = {"#CAIN_NAME","Cain"},
	Judas = {"#JUDAS_NAME","Judas"},
	BlueBaby = {"#BLUEBABY_NAME","???"},
	Eve = {"#EVE_NAME","Eve"},
	Samson = {"#SAMSON_NAME","Samson"},
	Azazel = {"#AZAZEL_NAME","Azazel"},
	Lazarus = {"#LAZARUS_NAME","Lazarus"},
	Eden = {"#EDEN_NAME","Eden"},
	Lost = {"#THE_LOST_NAME","The Lost"},
	Lilith = {"#LILITH_NAME","Lilith"},
	Keeper = {"#KEEPER_NAME","Keeper"},
	Apollyon = {"#APOLLYON_NAME","Apollyon"},
	Forgotten = {"#THE_FORGOTTEN_NAME","The Forgotten"},
	Bethany = {"#BETHANY_NAME","Bethany"},
}

local BOSS_MOD_PLAYER_IDS = {
	wq = enums.Players.wq,
	Tecro = enums.Players.Tecro,
	Anna = enums.Players.Anna,
	Zeis = enums.Players.Zeistos,
}

local HIDDEN_OTHER_ACHIEVEMENTS = {
	Thoth = true,
	Law = true,
	Voice = true,
	Vision = true,
	Future = true,
}

local CHARACTER_CATEGORY_ORDER = {"wq","Spwq","Tecro","Tecrorun","Anna","annA","Zeis","Zeiz","Marriano","Autio","Lu"}
local BOSS_PLAYER_ORDER = {
	"Isaac","Maggy","Cain","Judas","BlueBaby","Eve","Samson","Azazel","Lazarus","Eden","Lost","Lilith",
	"Keeper","Apollyon","Forgotten","Bethany","Jacob_and_Esau","wq","Tecro","Anna","Zeis",
}
local BOSS_BOARD_ROW_LABELS = {}
local BOSS_BOARD_ORDER = {}
for _,row in ipairs(unlock_board.boss_rows or {}) do
	BOSS_BOARD_ROW_LABELS[row.code] = row.name
	table.insert(BOSS_BOARD_ORDER,row.code)
end

local function translated_mod_player_name(player_id)
	local language = language_key()
	local player = translations[language] and translations[language].Players and
		translations[language].Players[player_id]
	return player and player.Name
end

local function achievement_label(key)
	local player_name = CATEGORY_PLAYER_IDS[key] and translated_mod_player_name(CATEGORY_PLAYER_IDS[key])
	if player_name and player_name ~= "" then return player_name end
	local entry = ACHIEVEMENT_LABELS[key]
	if entry then return entry[language_key()] or entry.en end
	for _,event in ipairs(unlock_board.special_events or {}) do
		if event.key == key and event.label and event.label ~= "" then return event.label end
	end
	return tostring(key)
end

local function boss_player_label(key)
	local mod_name = BOSS_MOD_PLAYER_IDS[key] and translated_mod_player_name(BOSS_MOD_PLAYER_IDS[key])
	if mod_name and mod_name ~= "" then return mod_name end
	if key == "Jacob_and_Esau" then
		return auxi.check_name_data("#JACOB_NAME","Jacob").." & "..auxi.check_name_data("#ESAU_NAME","Esau")
	end
	local token = BOSS_PLAYER_NAME_TOKENS[key]
	if token then return auxi.check_name_data(token[1],token[2]) end
	return achievement_label(key)
end

local function sorted_keys(tbl)
	local keys = {}
	for key,_ in pairs(tbl or {}) do table.insert(keys,key) end
	table.sort(keys,function(a,b) return tostring(a) < tostring(b) end)
	return keys
end

local function ordered_keys(tbl,preferred)
	local keys,seen = {},{}
	for _,key in ipairs(preferred or {}) do
		if tbl and tbl[key] ~= nil then table.insert(keys,key) seen[key] = true end
	end
	for _,key in ipairs(sorted_keys(tbl)) do
		if not seen[key] then table.insert(keys,key) end
	end
	return keys
end

local function reward_annotation(category,mark,field)
	local names = achievement_tracker.GetRewardNames(category,mark,field)
	if #names == 0 then return text("achievement_no_reward") end
	return string.format(text("achievement_reward"),table.concat(names," + "))
end

local BOSS_MARK_IDS = {
	Glaze = "boss.glaze",
	BossZeis = "boss.zeis",
}

local function character_mark_status(category, mark)
	local player_id = CATEGORY_PLAYER_IDS[category]
	if not player_id then return 0 end
	return CompletionMarks.get_status(player_id, mark)
end

local function set_character_mark_status(category, mark, field, value)
	local player_id = CATEGORY_PLAYER_IDS[category]
	if not player_id then return end
	local current = CompletionMarks.get_status(player_id, mark)
	local status = current
	if field == "Hard" then
		if value == true then status = 2
		elseif current >= 2 then status = 1 end
	else
		if value == true then
			if current < 1 then status = 1 end
		else
			status = 0
		end
	end
	CompletionMarks.set_status(player_id, mark, status)
end

local function achievement_current_value(category, mark, field)
	if BOSS_MARK_IDS[category] then
		return CompletionMarks.reward_boss_field_status(BOSS_MARK_IDS[category], mark, field)
	end
	if CATEGORY_PLAYER_IDS[category] then
		local status = character_mark_status(category, mark)
		if field == "Hard" then return status >= 2 end
		return status >= 1
	end
	local record = save.UnlockData and save.UnlockData[category] and save.UnlockData[category][mark]
	return record and record[field] == true or false
end

local function achievement_set_value(category, mark, field, value)
	if BOSS_MARK_IDS[category] then
		CompletionMarks.set_reward_boss_field(BOSS_MARK_IDS[category], mark, field, value == true)
		return
	end
	if CATEGORY_PLAYER_IDS[category] then
		set_character_mark_status(category, mark, field, value == true)
		return
	end
	save.UnlockData[category] = save.UnlockData[category] or {}
	save.UnlockData[category][mark] = save.UnlockData[category][mark] or {}
	save.UnlockData[category][mark][field] = value == true
end

local function add_achievement_checkbox(parent_id, id, label, category, mark, field)
	local function current_value()
		return achievement_current_value(category, mark, field)
	end
	ImGui.AddCheckbox(parent_id,id,label,nil,current_value())
	imgui_layout.set_helpmarker(id,reward_annotation(category,mark,field))
	ImGui.AddCallback(id,ImGuiCallback.Render,function()
		ImGui.UpdateData(id,ImGuiData.Value,current_value())
	end)
	ImGui.AddCallback(id,ImGuiCallback.Edited,function(value)
		achievement_set_value(category, mark, field, value)
		save_mod_data()
		if value == true then
			achievement_tracker.PlayManualAchievement(category,mark,field,item.get_value({"QingRemasterOptions","Achievements","PlayManualAnimations"}) == true)
		end
	end)
end

local function add_achievement_category(parent_id, category, category_type,header_label)
	local header = item.achievements_id.."_Category_"..category
	save.UnlockData[category] = save.UnlockData[category] or
		save.get_achievement_init(save.over_unlock_info[category],false)
	ImGui.AddElement(parent_id,header,ImGuiElement.CollapsingHeader,header_label or achievement_label(category))
	local marks = category_type == "boss" and ordered_keys(save.UnlockData[category],BOSS_PLAYER_ORDER) or category_type == "dynamic_boss" and ordered_keys(save.UnlockData[category],BOSS_BOARD_ORDER) or sorted_keys(save.UnlockData[category])
	for _,mark in ipairs(marks) do
		if not (category_type == "other" and HIDDEN_OTHER_ACHIEVEMENTS[mark]) then
		local prefix = header.."_"..tostring(mark)
		local label = category_type == "boss" and boss_player_label(mark) or category_type == "dynamic_boss" and (BOSS_BOARD_ROW_LABELS[mark] or boss_player_label(mark)) or achievement_label(mark)
		if category_type == "boss" then
			add_achievement_checkbox(header,prefix.."_Unlock",label.." - "..text("achievement_normal_victory").." / "..text("achievement_normal"),category,mark,"Unlock")
			ImGui.AddElement(header,"",ImGuiElement.SameLine)
			add_achievement_checkbox(header,prefix.."_Hard",text("achievement_hard"),category,mark,"Hard")
			add_achievement_checkbox(header,prefix.."_Tainted",label.." - "..text("achievement_tainted_victory").." / "..text("achievement_normal"),category,mark,"Tainted")
			ImGui.AddElement(header,"",ImGuiElement.SameLine)
			add_achievement_checkbox(header,prefix.."_TaintedHard",text("achievement_hard"),category,mark,"TaintedHard")
		elseif category_type == "dynamic_boss" then
			add_achievement_checkbox(header,prefix.."_Unlock",label.." - "..text("achievement_unlock"),category,mark,"Unlock")
		else
			add_achievement_checkbox(header,prefix.."_Unlock",label.." - "..text("achievement_unlock"),category,mark,"Unlock")
		end
		if category_type == "character" then
			ImGui.AddElement(header,"",ImGuiElement.SameLine)
			add_achievement_checkbox(header,prefix.."_Hard",text("achievement_hard"),category,mark,"Hard")
		end
		end
	end
end


	local menu_item = item.menu_id.."_AchievementsItem"
	local window_id = item.achievements_id
	local tabbar = window_id.."_TabBar"
	local characters_tab = tabbar.."_Characters"
	local bosses_tab = tabbar.."_Bosses"
	local other_tab = tabbar.."_Other"
	local settings_tab = tabbar.."_Settings"

	ImGui.AddElement(item.menu_id,menu_item,ImGuiElement.MenuItem,text("achievements_item"))
	ImGui.CreateWindow(window_id,text("achievements_title"))
	setup_window(window_id,item.default_window.achievements)
	ImGui.LinkWindowToElement(window_id,menu_item)
	ImGui.AddTabBar(window_id,tabbar)
	ImGui.AddTab(tabbar,characters_tab,text("achievement_characters"))
	ImGui.AddTab(tabbar,bosses_tab,text("achievement_bosses"))
	ImGui.AddTab(tabbar,other_tab,text("achievement_other"))
	ImGui.AddTab(tabbar,settings_tab,text("achievement_settings"))

	for _,category in ipairs(CHARACTER_CATEGORY_ORDER) do
		if save.over_unlock_info[category] then add_achievement_category(characters_tab,category,"character") end
	end
	add_achievement_category(bosses_tab,"Glaze","boss")
	add_achievement_category(bosses_tab,"BossZeis","boss")
	for _,definition in ipairs(save.dynamic_boss_categories or {}) do
		add_achievement_category(bosses_tab,definition.category,"dynamic_boss",definition.label)
	end
	add_achievement_category(other_tab,"Others","other")
	local settings_group = add_group(settings_tab,window_id.."_SettingsGroup",text("achievement_settings"))
	add_checkbox(settings_group,window_id.."_PlayManualAnimations",text("achievement_manual_animation"),{"QingRemasterOptions","Achievements","PlayManualAnimations"},text("achievement_manual_animation_help"))
	add_checkbox(settings_group,window_id.."_LegacyCompletionTracker",text("achievement_legacy_tracker"),{"QingRemasterOptions","Achievements","LegacyCompletionTracker"},text("achievement_legacy_tracker_help"))
	local marks_group = add_group(settings_tab,window_id.."_CompletionMarksGroup",text("completion_marks_character"))
	add_text(marks_group,text("completion_marks_character_help"))
	add_checkbox(marks_group,window_id.."_CharacterDrawPostit",text("completion_marks_character_draw"),{"QingRemasterOptions","CompletionMarks","CharacterDrawPostit"})
	add_drag_float(marks_group,window_id.."_CharacterOffsetX",text("completion_marks_character_x"),{"QingRemasterOptions","CompletionMarks","CharacterOffsetX"},nil,0.5,-400,400,"%.2f")
	add_drag_float(marks_group,window_id.."_CharacterOffsetY",text("completion_marks_character_y"),{"QingRemasterOptions","CompletionMarks","CharacterOffsetY"},nil,0.5,-400,400,"%.2f")
	local xy_id = window_id.."_CharacterOffsetXY"
	imgui_layout.add_wrapped_text(marks_group, xy_id, string.format(text("completion_marks_character_xy"),0,0))
	ImGui.AddCallback(xy_id,ImGuiCallback.Render,function()
		local x = tonumber(item.get_value({"QingRemasterOptions","CompletionMarks","CharacterOffsetX"})) or 0
		local y = tonumber(item.get_value({"QingRemasterOptions","CompletionMarks","CharacterOffsetY"})) or 0
		imgui_layout.update_text(xy_id,string.format(text("completion_marks_character_xy"),x,y))
	end)
	ImGui.AddButton(marks_group,window_id.."_CharacterPaperRestore",text("completion_marks_character_restore"),function()
		item.set_value({"QingRemasterOptions","CompletionMarks","CharacterDrawPostit"},false)
		item.set_value({"QingRemasterOptions","CompletionMarks","CharacterOffsetX"},-70)
		item.set_value({"QingRemasterOptions","CompletionMarks","CharacterOffsetY"},26)
		push_notice(text("completion_marks_character_restore"))
	end)
	ImGui.AddButton(marks_group,window_id.."_CompletionMarksAudit",text("completion_marks_audit"),function()
		local audit = CompletionMarks.audit_and_sync()
		local characters,mismatches = 0,0
		for _,report in pairs(audit or {}) do
			characters = characters + 1
			mismatches = mismatches + (tonumber(report.mismatches) or 0)
		end
		push_notice(string.format(text("completion_marks_audit_result"),characters,mismatches))
	end)
	add_checkbox(settings_group,window_id.."_ItemPoolGating",text("achievement_pool_gating"),{"Achievement_pool_gating"},text("achievement_pool_gating_help"))
	add_checkbox(settings_group,window_id.."_TrinketGating",text("achievement_trinket_gating"),{"Achievement_trinket_gating"},text("achievement_trinket_gating_help"))
	add_checkbox(settings_group,window_id.."_CardGating",text("achievement_card_gating"),{"Achievement_card_gating"},text("achievement_card_gating_help"))
	add_checkbox(settings_group,window_id.."_PickupGating",text("achievement_pickup_gating"),{"Achievement_pickup_gating"},text("achievement_pickup_gating_help"))

	ImGui.AddButton(window_id,window_id.."_UnlockAll",text("achievement_unlock_all"),function()
		save.UnLockAll()
		save_mod_data()
		push_notice(text("achievement_saved"))
	end)
	ImGui.AddElement(window_id,"",ImGuiElement.SameLine)
	ImGui.AddButton(window_id,window_id.."_LockAll",text("achievement_lock_all"),function()
		save.LockAll()
		save_mod_data()
		push_notice(text("achievement_saved"))
	end)
end

return M
