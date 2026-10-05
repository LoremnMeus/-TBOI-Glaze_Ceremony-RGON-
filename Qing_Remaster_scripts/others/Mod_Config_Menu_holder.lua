local enums = require("Qing_Remaster_scripts.core.enums")
local save = require("Qing_Remaster_scripts.core.savedata")
local schema = require("Qing_Remaster_scripts.others.mod_config_schema")

local item = {
	post_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "Mod_config_holder_",
	ModConfigSettings = {},
}

function item.get_initlist()
	return {
		Items_allow = true,
		Trinkets_allow = true,
		Pickup_allow = true,
		Boss_allow = true,
		Achievement_allow = true,
		Achievement_pool_gating = false,
		Achievement_trinket_gating = false,
		Achievement_card_gating = false,
		Achievement_pickup_gating = false,
		allow_mouse_control = true,
		thor_key = Keyboard.KEY_LEFT_ALT,
		thor_controller = 12,
		On_air_key = Keyboard.KEY_LEFT_ALT,
		Off_air_key = Keyboard.KEY_LEFT_CONTROL,
		mouseSupport = 2,
		mouseSupport1 = true,
		mouseSupport2 = false,
		Auto_Live = false,
		Trigger_LaserStart = true,
		Trigger_LaserEnd = true,
		Trigger_BrimStart = true,
		Trigger_BrimEnd = true,
	}
end
item.ModConfigSettings = item.get_initlist()

function item.get_setting(key)
	local value = schema.get({key})
	if value ~= nil then return value end
	if item.ModConfigSettings[key] == nil then
		item.ModConfigSettings[key] = item.get_initlist()[key]
	end
	return item.ModConfigSettings[key]
end

local function yes_no(value)
	if schema.language_key() == "zh" then
		return value and "是" or "否"
	end
	return value and "Yes" or "No"
end

local function keyboard_name(code)
	code = tonumber(code)
	if code == nil then return "?" end
	if Keyboard then
		for name, id in pairs(Keyboard) do
			if id == code and type(name) == "string" then
				return name
			end
		end
	end
	return tostring(code)
end

local function option_types()
	local types = (ModConfigMenu and ModConfigMenu.OptionType) or {}
	return {
		boolean = types.BOOLEAN or 1,
		number = types.NUMBER or 2,
		keyboard = types.KEYBIND_KEYBOARD or types.KEYBOARD or 3,
		controller = types.KEYBIND_CONTROLLER or types.CONTROLLER or 4,
	}
end

local function add_boolean(category, page, entry)
	local types = option_types()
	ModConfigMenu.AddSetting(category, page, {
		Type = types.boolean,
		CurrentSetting = function()
			return schema.read(entry) == true
		end,
		Display = function()
			return schema.entry_text(entry, "label") .. ": " .. yes_no(schema.read(entry) == true)
		end,
		OnChange = function(currentBool)
			schema.write(entry, currentBool == true)
		end,
		Info = {schema.entry_text(entry, "help")},
	})
end

local function add_enum(category, page, entry)
	local types = option_types()
	local choices = entry.choices or {}
	local min_value = choices[1] and choices[1].value or 0
	local max_value = min_value
	local by_value = {}
	for _, choice in ipairs(choices) do
		by_value[choice.value] = choice
		if choice.value < min_value then min_value = choice.value end
		if choice.value > max_value then max_value = choice.value end
	end
	ModConfigMenu.AddSetting(category, page, {
		Type = types.number,
		CurrentSetting = function()
			return tonumber(schema.read(entry)) or min_value
		end,
		Minimum = min_value,
		Maximum = max_value,
		ModifyBy = 1,
		Display = function()
			local value = tonumber(schema.read(entry)) or min_value
			local choice = by_value[value]
			local shown = choice and schema.choice_label(choice) or tostring(value)
			return schema.entry_text(entry, "label") .. ": " .. shown
		end,
		OnChange = function(currentNum)
			schema.write(entry, tonumber(currentNum) or min_value)
		end,
		Info = {schema.entry_text(entry, "help")},
	})
end

local function add_keyboard(category, page, entry)
	local types = option_types()
	ModConfigMenu.AddSetting(category, page, {
		Type = types.keyboard,
		CurrentSetting = function()
			return tonumber(schema.read(entry)) or 0
		end,
		Display = function()
			return schema.entry_text(entry, "label") .. ": " .. keyboard_name(schema.read(entry))
		end,
		OnChange = function(currentNum)
			schema.write(entry, tonumber(currentNum))
		end,
		Info = {schema.entry_text(entry, "help")},
	})
end

local function add_controller(category, page, entry)
	local types = option_types()
	ModConfigMenu.AddSetting(category, page, {
		Type = types.number,
		CurrentSetting = function()
			return tonumber(schema.read(entry)) or 0
		end,
		Minimum = entry.min or 0,
		Maximum = entry.max or 31,
		ModifyBy = 1,
		Display = function()
			return schema.entry_text(entry, "label") .. ": " .. tostring(tonumber(schema.read(entry)) or 0)
		end,
		OnChange = function(currentNum)
			schema.write(entry, tonumber(currentNum) or 0)
		end,
		Info = {schema.entry_text(entry, "help")},
	})
end

local function card_display_name(card_id)
	local translations = require("Qing_Remaster_scripts.translations.translate")
	local lang = schema.language_key()
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

local function add_card_rates(category, page, entry)
	local types = option_types()
	local card_all = require("Qing_Remaster_scripts.cards.Card_All")
	ModConfigMenu.AddText(category, page, function()
		return schema.entry_text(entry, "help")
	end)
	for _, card in ipairs(card_all.list_configurable_cards()) do
		local card_id = card.id
		ModConfigMenu.AddSetting(category, page, {
			Type = types.number,
			CurrentSetting = function()
				return tonumber(card_all.get_card_appear_rate(card_id)) or 1
			end,
			Minimum = 0,
			Maximum = 1,
			ModifyBy = 0.05,
			Display = function()
				local rate = tonumber(card_all.get_card_appear_rate(card_id)) or 1
				return card_display_name(card_id) .. ": " .. string.format("%.2f", rate)
			end,
			OnChange = function(currentNum)
				card_all.set_card_appear_rate(card_id, tonumber(currentNum) or 1)
			end,
			Info = {schema.entry_text(entry, "help")},
		})
	end
end

local function add_note(category, page, entry)
	ModConfigMenu.AddText(category, page, function()
		return schema.entry_text(entry, "label")
	end)
end

local function add_entry(category, page, entry)
	local kind = entry.type
	if kind == "boolean" then add_boolean(category, page, entry)
	elseif kind == "enum" then add_enum(category, page, entry)
	elseif kind == "keyboard" then add_keyboard(category, page, entry)
	elseif kind == "controller" then add_controller(category, page, entry)
	elseif kind == "card_rates" then add_card_rates(category, page, entry)
	elseif kind == "note" then add_note(category, page, entry)
	end
end

local PAGE_ORDER = {"gameplay", "hud", "controls", "cards", "compatibility", "achievements"}

if ModConfigMenu then
	local category = schema.category_name()
	if ModConfigMenu.UpdateCategory then
		ModConfigMenu.UpdateCategory(category, {
			Info = {
				schema.language_key() == "zh"
					and "琉璃盛典：应许之地 的玩家设置。与 ImGui 设置读写同一份配置。"
					or "Player settings for Qing Remaster. Shares the same config as the ImGui Settings window.",
			},
		})
	end
	for _, group in ipairs(PAGE_ORDER) do
		local page = schema.page_name(group)
		for _, entry in ipairs(schema.for_surface("mcm", group)) do
			add_entry(category, page, entry)
		end
	end
end

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_)
	item.ModConfigSettings = save.ModConfigSettings or item.ModConfigSettings or {}
	save.ModConfigSettings = item.ModConfigSettings
	local o = package.loaded["Qing_Remaster_scripts.callbacks.rgon_imgui_options_holder"]
	if o and o.get_settings then o.get_settings() end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_)
	save.ModConfigSettings = item.ModConfigSettings
end,
})

return item
