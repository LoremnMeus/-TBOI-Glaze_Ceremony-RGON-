-- 标题页 Logo：隐藏 live TitleMenu 的 Logo 层，叠绘 titlemenu_replace.anm2 的 Logo/LogoShadow。
local manifest = require("Qing_Remaster_scripts.translations.menu_language_manifest")
local menu_lang = require("Qing_Remaster_scripts.callbacks.rgon_menu_language_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
}

local TITLE_MENU_TYPE = MainMenuType and MainMenuType.TITLE or 1
local LAYER_LOGO = 2
local LAYER_LOGO_SHADOW = 3

local overlay = nil
local overlay_lang = nil
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

local function custom_logo_enabled()
	local cfg = title_logo_cfg()
	if cfg and cfg.enabled == false then return false end
	local options = get_options_holder()
	if options and options.get_value then
		if options.get_value({"QingRemasterOptions", "Menu", "TitleLogoCustom"}) == false then
			return false
		end
	end
	return true
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

local function resolve_logo_lang()
	local cfg = title_logo_cfg()
	if not cfg or cfg.enabled == false or not custom_logo_enabled() then return nil end
	local lang
	if cfg.follow_menu_lang == false then
		lang = "en"
	else
		lang = menu_lang.get_language("TitleLogoLanguage")
	end
	if lang == "zh" and type(cfg.zh) == "string" and cfg.zh ~= "" then return "zh" end
	return "en"
end

local function logo_sheet_for_lang(lang)
	local cfg = title_logo_cfg()
	if not cfg then return nil end
	if lang == "zh" and type(cfg.zh) == "string" and cfg.zh ~= "" then
		return cfg.zh
	end
	if type(cfg.en) == "string" and cfg.en ~= "" then return cfg.en end
	return nil
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
	set_layer_visible(spr, LAYER_LOGO_SHADOW, false)
	vanilla_logo_hidden = true
end

local function restore_vanilla_logo_layers()
	if not vanilla_logo_hidden or not TitleMenu or not TitleMenu.GetSprite then return end
	local ok, spr = pcall(TitleMenu.GetSprite)
	if not ok or not spr then return end
	set_layer_visible(spr, LAYER_LOGO, true)
	set_layer_visible(spr, LAYER_LOGO_SHADOW, true)
	vanilla_logo_hidden = false
end

function item.reset_overlay_cache()
	overlay = nil
	overlay_lang = nil
end

function item.refresh_vanilla_logo()
	restore_vanilla_logo_layers()
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
		overlay_lang = lang
	end
	if lang == "zh" and overlay_lang ~= "zh" then
		local zh_sheet = logo_sheet_for_lang("zh")
		if zh_sheet then
			local ok = pcall(function()
				overlay:ReplaceSpritesheet(1, zh_sheet, true)
				overlay:LoadGraphics()
			end)
			if ok then overlay_lang = "zh" end
		end
	elseif lang ~= "zh" and overlay_lang == "zh" then
		pcall(function()
			overlay:Load(anm2, true)
			overlay:Play("Idle", true)
		end)
		set_layer_visible(overlay, 0, false)
		set_layer_visible(overlay, 1, false)
		overlay_lang = lang
	end
	return overlay
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
	local logo_spr = ensure_overlay(lang)
	if not logo_spr then return end
	sync_overlay_frame(title_spr, logo_spr)
	local screen = logo_screen_anchor()
	pcall(function()
		logo_spr.Color = Color(1, 1, 1, 1)
		logo_spr:RenderLayer(LAYER_LOGO_SHADOW, screen, Vector.Zero, Vector.Zero)
		logo_spr:RenderLayer(LAYER_LOGO, screen, Vector.Zero, Vector.Zero)
	end)
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
