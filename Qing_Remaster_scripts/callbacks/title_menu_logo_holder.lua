-- 标题页 Logo：隐藏 live TitleMenu 的 Logo 层；
-- 叠绘 titlemenu_replace.anm2 的 Logo；彩虹用独立双层 Sprite（上 80 大标题 / 下 80 小字）。
--
-- 小字带灰度几乎全在 ~0.076，必须单独更亮的 lum remap，不能和大标题共用 0.07–0.29。
-- Drawing 不由本 holder 接管（中文补丁覆盖资源时属外部问题，勿在此「补回」）。
local manifest = require("Qing_Remaster_scripts.translations.menu_language_manifest")
local menu_lang = require("Qing_Remaster_scripts.callbacks.rgon_menu_language_holder")
local temp_hud = require("Qing_Remaster_scripts.callbacks.temp_item_hud_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
}

local TITLE_MENU_TYPE = MainMenuType and MainMenuType.TITLE or 1
local LAYER_LOGO = 2
local LAYER_VANILLA_LOGO_SHADOW = 3
local RAINBOW_LAYER_TITLE = 0
local RAINBOW_LAYER_TEXT = 1
local RAINBOW_ANM2_DEFAULT = "gfx/ui/main menu/titlemenu_logo_rainbow.anm2"
local RAINBOW_SEED = 0.41
-- 大标题（YCrop 160–239）：有效灰度约 0.07–0.29
local DEFAULT_LUM_LOW = 0.07
local DEFAULT_LUM_HIGH = 0.29
-- 小字（YCrop 240–319）：几乎全是 ~0.076，用更窄/更亮 remap
local DEFAULT_TEXT_LUM_LOW = 0.05
local DEFAULT_TEXT_LUM_HIGH = 0.10
local DEFAULT_SPATIAL_ANGLE = 0
local DEFAULT_SPATIAL_DENSITY = 2.6
local DEFAULT_ROLL_SPEED = 0.65
local DEFAULT_ROLL_DIRECTION = 1
local DEFAULT_GRAY_HUE = 0.47
local DEFAULT_BEND = 0.15
local DEFAULT_SHAPE_CONTRAST = 0.40

local overlay = nil
local overlay_lang = nil
local rainbow = nil
local rainbow_lang = nil
local rainbow_load_failed = false
local rainbow_shader_applied = false
local rainbow_has_shader = false
local rainbow_last_error = nil
local rainbow_last_render_ok = false
local vanilla_logo_hidden = false
local options_holder

local function title_logo_cfg()
	return manifest.title_logo
end

local function get_options_holder()
	if options_holder == nil then
		local ok, mod = pcall(require, "Qing_Remaster_scripts.callbacks.rgon_imgui_options_holder")
		options_holder = ok and mod or false
	end
	return options_holder ~= false and options_holder or nil
end

local function option_flag(path, default_value)
	local options = get_options_holder()
	if options and options.get_value then
		local v = options.get_value(path)
		if v == false then return false end
		if v == true then return true end
	end
	return default_value == true
end

local function custom_logo_enabled()
	local cfg = title_logo_cfg()
	if cfg and cfg.enabled == false then return false end
	return option_flag({"QingRemasterOptions", "Menu", "TitleLogoCustom"}, true)
end

-- 默认开；仅选项明确 false 时关。禁止在渲染路径里 set_value/SaveModData。
local function rainbow_overlay_enabled()
	return option_flag({"QingRemasterOptions", "Menu", "TitleLogoRainbow"}, true)
end

local function rainbow_solo_enabled()
	return option_flag({"QingRemasterOptions", "Menu", "TitleLogoRainbowSolo"}, false)
end

local function title_lum_range(for_text)
	local options = get_options_holder()
	local low_key = for_text and "TitleLogoRainbowTextLumLow" or "TitleLogoRainbowLumLow"
	local high_key = for_text and "TitleLogoRainbowTextLumHigh" or "TitleLogoRainbowLumHigh"
	local low = for_text and DEFAULT_TEXT_LUM_LOW or DEFAULT_LUM_LOW
	local high = for_text and DEFAULT_TEXT_LUM_HIGH or DEFAULT_LUM_HIGH
	if options and options.get_value then
		low = tonumber(options.get_value({"QingRemasterOptions", "Menu", low_key})) or low
		high = tonumber(options.get_value({"QingRemasterOptions", "Menu", high_key})) or high
	end
	local fallback_low = for_text and DEFAULT_TEXT_LUM_LOW or DEFAULT_LUM_LOW
	local fallback_high = for_text and DEFAULT_TEXT_LUM_HIGH or DEFAULT_LUM_HIGH
	if high <= low + 0.001 then
		return fallback_low, fallback_high
	end
	return math.max(0, math.min(1, low)), math.max(0, math.min(1, high))
end

local function title_option_number(key, default)
	local options = get_options_holder()
	if options and options.get_value then
		local v = tonumber(options.get_value({"QingRemasterOptions", "Menu", key}))
		if v ~= nil then return v end
	end
	return default
end

local function make_title_rainbow_color(alpha, for_text)
	local lum_low, lum_high = title_lum_range(for_text == true)
	local dir = title_option_number("TitleLogoRainbowDirection", DEFAULT_ROLL_DIRECTION)
	if dir < 0 then
		dir = -1
	else
		dir = 1
	end
	-- 标题页 Game frame 可能不推进：use_wall_time=true
	return temp_hud.make_rainbow_roll_color(
		tonumber(alpha) or 1,
		RAINBOW_SEED,
		lum_low,
		lum_high,
		title_option_number("TitleLogoRainbowSpatialAngle", DEFAULT_SPATIAL_ANGLE),
		title_option_number("TitleLogoRainbowSpatialDensity", DEFAULT_SPATIAL_DENSITY),
		title_option_number("TitleLogoRainbowSpeed", DEFAULT_ROLL_SPEED),
		dir,
		title_option_number("TitleLogoRainbowGrayHue", DEFAULT_GRAY_HUE),
		title_option_number("TitleLogoRainbowBend", DEFAULT_BEND),
		title_option_number("TitleLogoRainbowShapeContrast", DEFAULT_SHAPE_CONTRAST),
		true
	)
end

local function title_rainbow_shader()
	return temp_hud.RAINBOW_ROLL_SHADER
end

local function apply_title_rainbow_shader(spr)
	if not spr then return end
	local path = title_rainbow_shader()
	-- 若仍挂着旧 cellular，先清再挂 roll
	if spr.HasCustomShader and spr:HasCustomShader() and not spr:HasCustomShader(path) then
		temp_hud.clear_sprite_shader(spr)
	end
	temp_hud.apply_sprite_shader(spr, path)
end

local function is_title_screen()
	if not REPENTOGON or not MenuManager or not MenuManager.GetActiveMenu then return false end
	local ok, active = pcall(MenuManager.GetActiveMenu)
	return ok and active == TITLE_MENU_TYPE
end

local function menu_position(pos)
	return Isaac.WorldToMenuPosition(TITLE_MENU_TYPE, pos)
end

local function menu_scale()
	return math.max(0.01, (menu_position(Vector(1, 0)) - menu_position(Vector(0, 0))):Length())
end

local function logo_render_menu_offset()
	local options = get_options_holder()
	local x, y = -39, -15
	if options and options.get_value then
		x = tonumber(options.get_value({"QingRemasterOptions", "Menu", "TitleLogoOffsetX"})) or -39
		y = tonumber(options.get_value({"QingRemasterOptions", "Menu", "TitleLogoOffsetY"})) or -15
	end
	return Vector(x, y)
end

local function logo_screen_anchor()
	local base = menu_position(Vector(0, 0))
	local off = logo_render_menu_offset()
	local scale = menu_scale()
	return base + Vector(off.X * scale, off.Y * scale)
end

local function logo_sheet_for_lang(lang)
	local cfg = title_logo_cfg()
	if not cfg then return nil end
	-- 中文贴图未实装前不得 Replace 到 cfg.zh（缺文件 → 空白叠层）。实装后设 title_logo.zh_ready = true。
	if lang == "zh" then
		if cfg.zh_ready == true and type(cfg.zh) == "string" and cfg.zh ~= "" then
			return cfg.zh
		end
		return nil
	end
	if type(cfg.en) == "string" and cfg.en ~= "" then return cfg.en end
	return nil
end

local function resolve_logo_lang()
	local cfg = title_logo_cfg()
	if not cfg or cfg.enabled == false or not custom_logo_enabled() then return nil end
	local lang
	if cfg.follow_menu_lang == false then
		lang = "en"
	else
		lang = menu_lang.get_language("TitleLogoLanguage")
	end
	if lang == "zh" and logo_sheet_for_lang("zh") then
		return "zh"
	end
	return "en"
end

local function set_layer_visible(spr, layer_id, visible)
	if not spr or not spr.GetLayer then return end
	pcall(function()
		local lay = spr:GetLayer(layer_id)
		if lay and lay.SetVisible then lay:SetVisible(visible) end
	end)
end

local function hide_vanilla_logo_layers()
	if not TitleMenu or not TitleMenu.GetSprite then return end
	local ok, spr = pcall(TitleMenu.GetSprite)
	if not ok or not spr then return end
	set_layer_visible(spr, LAYER_LOGO, false)
	set_layer_visible(spr, LAYER_VANILLA_LOGO_SHADOW, false)
	vanilla_logo_hidden = true
end

local function restore_vanilla_logo_layers()
	if not vanilla_logo_hidden or not TitleMenu or not TitleMenu.GetSprite then return end
	local ok, spr = pcall(TitleMenu.GetSprite)
	if not ok or not spr then return end
	set_layer_visible(spr, LAYER_LOGO, true)
	set_layer_visible(spr, LAYER_VANILLA_LOGO_SHADOW, true)
	vanilla_logo_hidden = false
end

function item.reset_overlay_cache()
	overlay = nil
	overlay_lang = nil
	rainbow = nil
	rainbow_lang = nil
	rainbow_load_failed = false
	rainbow_shader_applied = false
	rainbow_has_shader = false
	rainbow_last_error = nil
	rainbow_last_render_ok = false
end

function item.refresh_vanilla_logo()
	restore_vanilla_logo_layers()
end

function item.rainbow_debug_status()
	if not rainbow_overlay_enabled() then
		return "disabled (TitleLogoRainbow off)"
	end
	if rainbow_load_failed then
		return "LOAD FAIL: " .. tostring(rainbow_last_error or "unknown")
	end
	if not rainbow then
		return "not loaded yet (open title screen)"
	end
	local t_lo, t_hi = title_lum_range(false)
	local x_lo, x_hi = title_lum_range(true)
	local parts = {
		"loaded",
		"lang=" .. tostring(rainbow_lang or "?"),
		"sheet=" .. tostring(logo_sheet_for_lang(rainbow_lang or "en") or "none"),
		"shader_applied=" .. tostring(rainbow_shader_applied),
		"has_shader=" .. tostring(rainbow_has_shader),
		"last_render=" .. tostring(rainbow_last_render_ok),
		"solo=" .. tostring(rainbow_solo_enabled()),
		string.format("title_lum=%.2f-%.2f", t_lo, t_hi),
		string.format("text_lum=%.2f-%.2f", x_lo, x_hi),
		string.format(
			"ang=%.0f dens=%.2f spd=%.2f dir=%d gray=%.2f bend=%.2f contrast=%.2f",
			title_option_number("TitleLogoRainbowSpatialAngle", DEFAULT_SPATIAL_ANGLE),
			title_option_number("TitleLogoRainbowSpatialDensity", DEFAULT_SPATIAL_DENSITY),
			title_option_number("TitleLogoRainbowSpeed", DEFAULT_ROLL_SPEED),
			title_option_number("TitleLogoRainbowDirection", DEFAULT_ROLL_DIRECTION) < 0 and -1 or 1,
			title_option_number("TitleLogoRainbowGrayHue", DEFAULT_GRAY_HUE),
			title_option_number("TitleLogoRainbowBend", DEFAULT_BEND),
			title_option_number("TitleLogoRainbowShapeContrast", DEFAULT_SHAPE_CONTRAST)
		),
	}
	return table.concat(parts, ", ")
end

local function apply_lang_sheet(spr, spritesheet_id, lang)
	if not spr then return false end
	local sheet = logo_sheet_for_lang(lang)
	if not sheet then return false end
	local ok, err = pcall(function()
		spr:ReplaceSpritesheet(spritesheet_id, sheet, true)
		spr:LoadGraphics()
	end)
	if not ok then
		rainbow_last_error = "ReplaceSpritesheet: " .. tostring(err)
		return false
	end
	return true
end

local function ensure_overlay(lang)
	local cfg = title_logo_cfg()
	if not cfg or cfg.enabled == false or not custom_logo_enabled() then return nil end
	local anm2 = type(cfg.anm2) == "string" and cfg.anm2 or "gfx/ui/main menu/titlemenu_replace.anm2"
	if not overlay then
		overlay = Sprite()
		local ok = pcall(function()
			overlay:Load(anm2, true)
			overlay:Play("Idle", true)
		end)
		if not ok or not overlay or overlay.GetLayerCount == nil then
			overlay = nil
			overlay_lang = nil
			return nil
		end
		set_layer_visible(overlay, 0, false)
		set_layer_visible(overlay, 1, false)
		set_layer_visible(overlay, 3, false)
		overlay_lang = "en"
	end
	if lang == "zh" and overlay_lang ~= "zh" then
		if apply_lang_sheet(overlay, 1, "zh") then
			overlay_lang = "zh"
		end
	elseif lang ~= "zh" and overlay_lang == "zh" then
		pcall(function()
			overlay:Load(anm2, true)
			overlay:Play("Idle", true)
		end)
		set_layer_visible(overlay, 0, false)
		set_layer_visible(overlay, 1, false)
		set_layer_visible(overlay, 3, false)
		overlay_lang = lang
	end
	return overlay
end

local function rainbow_anm2_path()
	local cfg = title_logo_cfg()
	if cfg and type(cfg.rainbow_anm2) == "string" and cfg.rainbow_anm2 ~= "" then
		return cfg.rainbow_anm2
	end
	return RAINBOW_ANM2_DEFAULT
end

local function refresh_rainbow_shader_flag(spr)
	rainbow_has_shader = false
	if not spr or not spr.HasCustomShader then return end
	local ok, has = pcall(function()
		return spr:HasCustomShader(title_rainbow_shader())
	end)
	rainbow_has_shader = ok and has == true
end

local function ensure_rainbow(lang)
	if not rainbow_overlay_enabled() then return nil end
	if rainbow_load_failed then return nil end
	local anm2 = rainbow_anm2_path()
	local sheet_lang = lang or "en"
	if not logo_sheet_for_lang(sheet_lang) then
		sheet_lang = "en"
	end
	if not rainbow then
		rainbow = Sprite()
		local ok, err = pcall(function()
			rainbow:Load(anm2, true)
			rainbow:Play("Idle", true)
		end)
		if not ok or not rainbow or rainbow.GetLayerCount == nil then
			rainbow_last_error = tostring(err or "Load/GetLayerCount failed") .. " path=" .. tostring(anm2)
			rainbow = nil
			rainbow_lang = nil
			rainbow_load_failed = true
			rainbow_shader_applied = false
			rainbow_has_shader = false
			return nil
		end
		-- 必须显式绑到存在的 en sheet；缺 zh 文件时 Replace 会留下空白贴图
		if not apply_lang_sheet(rainbow, 0, sheet_lang) then
			rainbow_last_error = "sheet bind failed lang=" .. tostring(sheet_lang)
			rainbow = nil
			rainbow_lang = nil
			rainbow_load_failed = true
			return nil
		end
		apply_title_rainbow_shader(rainbow)
		rainbow_shader_applied = true
		refresh_rainbow_shader_flag(rainbow)
		rainbow_lang = sheet_lang
		rainbow_last_error = nil
	elseif not rainbow_shader_applied then
		apply_title_rainbow_shader(rainbow)
		rainbow_shader_applied = true
		refresh_rainbow_shader_flag(rainbow)
	end
	-- 从错误的 zh 空白 sheet 拉回 en
	if rainbow_lang ~= sheet_lang then
		pcall(function()
			rainbow:Load(anm2, true)
			rainbow:Play("Idle", true)
		end)
		if apply_lang_sheet(rainbow, 0, sheet_lang) then
			apply_title_rainbow_shader(rainbow)
			rainbow_shader_applied = true
			refresh_rainbow_shader_flag(rainbow)
			rainbow_lang = sheet_lang
			rainbow_last_error = nil
		else
			rainbow_last_error = "rebind sheet failed lang=" .. tostring(sheet_lang)
		end
	end
	return rainbow
end

local function sync_overlay_frame(title_spr, logo_spr)
	if not title_spr or not logo_spr then return end
	local frame = 0
	pcall(function() frame = title_spr:GetFrame() end)
	pcall(function() logo_spr:SetFrame("Idle", frame or 0) end)
end

local function render_logo_overlay()
	local cfg = title_logo_cfg()
	if not cfg or cfg.enabled == false or not custom_logo_enabled() then return end
	local ok_title, title_spr = pcall(TitleMenu.GetSprite)
	if not ok_title or not title_spr then return end
	local lang = resolve_logo_lang()
	local solo = rainbow_solo_enabled()
	local screen = logo_screen_anchor()

	if not solo then
		local logo_spr = ensure_overlay(lang)
		if logo_spr then
			sync_overlay_frame(title_spr, logo_spr)
			pcall(function()
				temp_hud.clear_sprite_shader(logo_spr)
				logo_spr.Color = Color(1, 1, 1, 1)
				logo_spr:RenderLayer(LAYER_LOGO, screen, Vector.Zero, Vector.Zero)
			end)
		end
	end

	local rainbow_spr = ensure_rainbow(lang)
	rainbow_last_render_ok = false
	if rainbow_spr then
		sync_overlay_frame(title_spr, rainbow_spr)
		local ok_render, err_render = pcall(function()
			if not rainbow_shader_applied then
				apply_title_rainbow_shader(rainbow_spr)
				rainbow_shader_applied = true
				refresh_rainbow_shader_flag(rainbow_spr)
			end
			-- 上半大标题 / 下半小字：各自 Colorize lum 映射
			rainbow_spr.Color = make_title_rainbow_color(1, false)
			rainbow_spr:RenderLayer(RAINBOW_LAYER_TITLE, screen, Vector.Zero, Vector.Zero)
			rainbow_spr.Color = make_title_rainbow_color(1, true)
			rainbow_spr:RenderLayer(RAINBOW_LAYER_TEXT, screen, Vector.Zero, Vector.Zero)
		end)
		rainbow_last_render_ok = ok_render == true
		if not ok_render then
			rainbow_last_error = "Render: " .. tostring(err_render)
		end
	end
end

local function on_main_menu_pre()
	if not custom_logo_enabled() then
		restore_vanilla_logo_layers()
		return
	end
	if is_title_screen() then
		hide_vanilla_logo_layers()
	else
		restore_vanilla_logo_layers()
	end
end

local function on_main_menu_render()
	if not is_title_screen() then return end
	if not custom_logo_enabled() then
		restore_vanilla_logo_layers()
		return
	end
	hide_vanilla_logo_layers()
	render_logo_overlay()
end

table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
	CallBack = ModCallbacks.MC_MAIN_MENU_RENDER,
	priority = 0,
	Function = function(_) on_main_menu_pre() end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_MAIN_MENU_RENDER,
	Function = function(_) on_main_menu_render() end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	Function = function(_)
		restore_vanilla_logo_layers()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_GAME_EXIT,
	Function = function(_)
		restore_vanilla_logo_layers()
	end,
})

return item
