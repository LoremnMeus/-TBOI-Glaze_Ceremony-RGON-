-- Canonical player-facing config description.
-- Defaults / save still live on rgon_imgui_options_holder + save.ModConfigSettings.
-- ImGui is the full UI; MCM is a compatibility frontend over the same paths.

local save = require("Qing_Remaster_scripts.core.savedata")

local schema = {}

local OWNER_NAME = "Qing_Remaster_scripts.callbacks.rgon_imgui_options_holder"
local MCM_NAME = "Qing_Remaster_scripts.others.Mod_Config_Menu_holder"

function schema.language_key()
	local language = string.lower(tostring((Options and Options.Language) or "en"))
	if language == "zh"
		or language == "zh_cn"
		or language == "chinese"
		or string.sub(language, 1, 2) == "zh"
	then
		return "zh"
	end
	return "en"
end

local PAGES = {
	gameplay = {en = "Gameplay", zh = "游戏玩法"},
	hud = {en = "HUD & Visual", zh = "HUD 与显示"},
	controls = {en = "Controls", zh = "控制"},
	cards = {en = "Cards", zh = "卡牌"},
	compatibility = {en = "Compatibility", zh = "兼容性"},
	achievements = {en = "Achievements", zh = "成就"},
}

schema.category = {
	en = "Qing Remaster",
	zh = "琉璃盛典：应许之地",
}

local LANG_CHOICES = {
	{value = 0, label = {en = "Follow game language", zh = "跟随游戏语言"}},
	{value = 1, label = {en = "Chinese", zh = "中文"}},
	{value = 2, label = {en = "English", zh = "英文"}},
}

local MOUSE_CHOICES = {
	{value = 1, label = {en = "Disabled", zh = "关闭"}},
	{value = 2, label = {en = "Follow on click", zh = "按下时跟随"}},
	{value = 3, label = {en = "Always follow", zh = "始终跟随"}},
}

local function pick(bag)
	if type(bag) ~= "table" then return tostring(bag or "") end
	local lang = schema.language_key()
	return bag[lang] or bag.en or bag.zh or ""
end

function schema.page_name(group)
	return pick(PAGES[group] or {en = group, zh = group})
end

function schema.category_name()
	return pick(schema.category)
end

function schema.entry_text(entry, field)
	if not entry then return "" end
	return pick(entry[field])
end

function schema.choice_label(choice)
	return pick(choice and choice.label)
end

local function owner()
	return package.loaded[OWNER_NAME]
end

local function mcm_holder()
	return package.loaded[MCM_NAME]
end

local function walk(tbl, path)
	local cur = tbl
	for i = 1, #path do
		if type(cur) ~= "table" then return nil end
		cur = cur[path[i]]
	end
	return cur
end

local function write_path(tbl, path, value)
	local cur = tbl
	for i = 1, #path - 1 do
		local key = path[i]
		if type(cur[key]) ~= "table" then cur[key] = {} end
		cur = cur[key]
	end
	cur[path[#path]] = value
end

function schema.get(path)
	local o = owner()
	if o and o.get_value then
		return o.get_value(path)
	end
	local root = save.ModConfigSettings
	local holder = mcm_holder()
	if type(root) ~= "table" and holder then
		root = holder.ModConfigSettings
	end
	local value = walk(root, path)
	if value ~= nil then return value end
	if holder and holder.get_initlist and #path == 1 then
		return holder.get_initlist()[path[1]]
	end
	return nil
end

function schema.set(path, value)
	local o = owner()
	if o and o.set_value then
		o.set_value(path, value)
		return
	end
	local holder = mcm_holder()
	local root = save.ModConfigSettings or (holder and holder.ModConfigSettings) or {}
	write_path(root, path, value)
	save.ModConfigSettings = root
	if holder then holder.ModConfigSettings = root end
	if save.SaveModData then
		pcall(save.SaveModData)
	end
end

function schema.mouse_mode()
	local mode = tonumber(schema.get({"mouseSupport"}))
	if mode == 1 or mode == 2 or mode == 3 then return mode end
	local bit2 = schema.get({"mouseSupport1"}) and 2 or 0
	local bit1 = schema.get({"mouseSupport2"}) and 1 or 0
	mode = bit2 + bit1
	if mode < 1 then mode = 1 end
	if mode > 3 then mode = 3 end
	return mode
end

function schema.set_mouse_mode(mode)
	mode = math.floor(tonumber(mode) or 2)
	if mode < 1 then mode = 1 end
	if mode > 3 then mode = 3 end
	schema.set({"mouseSupport"}, mode)
	schema.set({"mouseSupport1"}, (mode & 2) == 2)
	schema.set({"mouseSupport2"}, (mode & 1) == 1)
end

local function refresh_menu_language()
	local ok, holder = pcall(require, "Qing_Remaster_scripts.callbacks.rgon_menu_language_holder")
	if not ok or not holder then return end
	holder.loaded_by_hash = {}
	holder.applied_language = nil
	if holder.apply_language then holder.apply_language(true) end
end

local function refresh_title_logo()
	local ok, holder = pcall(require, "Qing_Remaster_scripts.callbacks.title_menu_logo_holder")
	if not ok or not holder then return end
	if holder.reset_overlay_cache then holder.reset_overlay_cache() end
	if holder.refresh_vanilla_logo then holder.refresh_vanilla_logo() end
end

schema.entries = {
	{
		key = "Items_allow",
		path = {"Items_allow"},
		type = "boolean",
		group = "gameplay",
		surfaces = {imgui = true, mcm = true},
		label = {
			en = "Allow mod items to appear naturally",
			zh = "允许模组道具自然出现",
		},
		help = {
			en = "Unlocked items can appear in the basement. Takes effect on the next new run.",
			zh = "已解锁道具可以在地下室自然出现。下一局新游戏生效。",
		},
	},
	{
		key = "Trinkets_allow",
		path = {"Trinkets_allow"},
		type = "boolean",
		group = "gameplay",
		surfaces = {imgui = true, mcm = true},
		label = {
			en = "Allow mod trinkets to appear naturally",
			zh = "允许模组饰品自然出现",
		},
		help = {
			en = "When disabled, all Qing Remaster trinkets are removed from the trinket pool on the next new run.",
			zh = "关闭后，下一局会从饰品池移除全部琉璃盛典饰品。",
		},
	},
	{
		key = "Pickup_allow",
		path = {"Pickup_allow"},
		type = "boolean",
		group = "gameplay",
		surfaces = {imgui = true, mcm = true},
		label = {
			en = "Allow mod pickups to appear naturally",
			zh = "允许模组掉落物自然出现",
		},
		help = {
			en = "Unlocked pickups can appear in the basement.",
			zh = "已解锁掉落物可以在地下室自然出现。",
		},
	},
	{
		key = "Boss_allow",
		path = {"Boss_allow"},
		type = "boolean",
		group = "gameplay",
		surfaces = {imgui = true, mcm = true},
		label = {
			en = "Allow mod bosses to appear",
			zh = "允许模组 Boss 出现",
		},
		help = {
			en = "Special bosses can appear in the basement.",
			zh = "允许模组 Boss 在地下室出现。",
		},
	},
	{
		key = "Auto_Live",
		path = {"Auto_Live"},
		type = "boolean",
		group = "gameplay",
		surfaces = {imgui = true, mcm = true},
		label = {
			en = "Automatically open broadcast",
			zh = "自动开启直播",
		},
		help = {
			en = "Runs Live Broadcast mode without requiring the collectible.",
			zh = "无需持有直播姬，也会持续运行直播模式。",
		},
	},
	{
		key = "UseRgonImitateItems",
		path = {"QingRemasterOptions", "Compatibility", "UseRgonImitateItems"},
		type = "boolean",
		group = "compatibility",
		surfaces = {imgui = true, mcm = true},
		label = {
			en = "Use RGON innate collectible backend for fake items",
			zh = "使用 RGON 内置道具后端处理模拟道具",
		},
		help = {
			en = "When enabled, imitate_item_holder uses AddInnateCollectible/RemoveInnateCollectible instead of hidden wisps. Disable this if a compatibility issue appears.",
			zh = "开启后 imitate_item_holder 会使用 AddInnateCollectible/RemoveInnateCollectible，而不是隐藏魂火。遇到兼容问题时可以关闭。",
		},
	},
	{
		key = "Achievement_allow",
		path = {"Achievement_allow"},
		type = "boolean",
		group = "achievements",
		surfaces = {imgui = true, mcm = true},
		label = {
			en = "Allow achievements to be unlocked",
			zh = "允许解锁成就",
		},
		help = {
			en = "Achievements unlock after their conditions are met.",
			zh = "满足条件后可以解锁成就。",
		},
	},
	{
		key = "Achievement_pool_gating",
		path = {"Achievement_pool_gating"},
		type = "boolean",
		group = "achievements",
		surfaces = {imgui = true, mcm = true},
		label = {
			en = "Apply achievement unlocks to item pools",
			zh = "让成就解锁状态实际影响道具池",
		},
		help = {
			en = "Collectibles on the achievement board cannot be naturally selected until completed. Takes effect on the next new run.",
			zh = "解锁板上的道具在完成对应条件前不会被自然抽取。下一局新游戏生效。",
		},
	},
	{
		key = "Achievement_trinket_gating",
		path = {"Achievement_trinket_gating"},
		type = "boolean",
		group = "achievements",
		surfaces = {imgui = true, mcm = true},
		label = {
			en = "Apply achievement unlocks to trinkets",
			zh = "按成就解锁状态调控饰品",
		},
		help = {
			en = "Locked achievement-board trinkets are removed from the trinket pool on the next new run.",
			zh = "开启后，解锁板中尚未解锁的饰品会在下一局从饰品池移除。",
		},
	},
	{
		key = "Achievement_card_gating",
		path = {"Achievement_card_gating"},
		type = "boolean",
		group = "achievements",
		surfaces = {imgui = true, mcm = true},
		label = {
			en = "Apply achievement unlocks to cards",
			zh = "按成就解锁状态调控卡牌",
		},
		help = {
			en = "Locked cards are made unavailable through REPENTOGON without rerolling or changing card weights.",
			zh = "尚未解锁的卡牌会通过忏悔龙可用性条件禁用，不重抽，也不会改变卡牌权重。",
		},
	},
	{
		key = "Achievement_pickup_gating",
		path = {"Achievement_pickup_gating"},
		type = "boolean",
		group = "achievements",
		surfaces = {imgui = true, mcm = true},
		label = {
			en = "Apply achievement unlocks to pickups",
			zh = "按成就解锁状态调控琉璃化掉落物",
		},
		help = {
			en = "Locked glazed pickups on the achievement board will not be generated.",
			zh = "解锁板中尚未解锁的琉璃化掉落物不会生成。",
		},
	},
	{
		key = "achievements_note",
		type = "note",
		group = "achievements",
		surfaces = {mcm = true},
		label = {
			en = "Unlock / lock individual achievements in the Qing Remaster ImGui Achievements window.",
			zh = "单个成就的解锁/锁定请使用琉璃盛典 ImGui「成就」窗口。",
		},
	},
	{
		key = "ShowTempItemHUD",
		path = {"QingRemasterOptions", "Gameplay", "ShowTempItemHUD"},
		type = "boolean",
		group = "hud",
		surfaces = {imgui = true, mcm = true},
		label = {
			en = "Show temporary items on Extra HUD",
			zh = "在 Extra HUD 上显示临时道具",
		},
		help = {
			en = "Draw Qing temporary items as semi-transparent icons after the vanilla Extra HUD list.",
			zh = "在原版 Extra HUD 列表后绘制半透明的临时道具图标。",
		},
	},
	{
		key = "TitleLogoCustom",
		path = {"QingRemasterOptions", "Menu", "TitleLogoCustom"},
		type = "boolean",
		group = "hud",
		surfaces = {imgui = true, mcm = true},
		after_set = refresh_title_logo,
		label = {
			en = "Use custom title logo",
			zh = "使用自定义标题 Logo",
		},
		help = {
			en = "Replace the title-screen logo with the Qing Remaster overlay.",
			zh = "用琉璃盛典封面 Logo 替换标题画面。",
		},
	},
	{
		key = "TitleLogoRainbow",
		path = {"QingRemasterOptions", "Menu", "TitleLogoRainbow"},
		type = "boolean",
		group = "hud",
		surfaces = {imgui = true, mcm = true},
		label = {
			en = "Enable title logo rainbow",
			zh = "启用标题 Logo 彩虹效果",
		},
		help = {
			en = "Rainbow shading on the custom title logo. Fine shader knobs stay in ImGui.",
			zh = "自定义 Logo 的彩虹着色。精细参数仍在 ImGui 中调整。",
		},
	},
	{
		key = "CharacterSelectLanguage",
		path = {"QingRemasterOptions", "Menu", "CharacterSelectLanguage"},
		type = "enum",
		choices = LANG_CHOICES,
		group = "hud",
		surfaces = {mcm = true},
		after_set = refresh_menu_language,
		label = {
			en = "Character select language",
			zh = "选人菜单语言",
		},
		help = {
			en = "Language for the character-select menu sheets.",
			zh = "角色选择菜单贴图的语言。",
		},
	},
	{
		key = "ControlsLanguage",
		path = {"QingRemasterOptions", "Menu", "ControlsLanguage"},
		type = "enum",
		choices = LANG_CHOICES,
		group = "hud",
		surfaces = {mcm = true},
		after_set = refresh_menu_language,
		label = {
			en = "Controls menu language",
			zh = "操作说明语言",
		},
		help = {
			en = "Language for the pause/controls menu sheets.",
			zh = "暂停/操作说明菜单贴图的语言。",
		},
	},
	{
		key = "GameOverLanguage",
		path = {"QingRemasterOptions", "Menu", "GameOverLanguage"},
		type = "enum",
		choices = LANG_CHOICES,
		group = "hud",
		surfaces = {mcm = true},
		after_set = refresh_menu_language,
		label = {
			en = "Game over language",
			zh = "结束画面语言",
		},
		help = {
			en = "Language for game-over menu sheets.",
			zh = "游戏结束画面贴图的语言。",
		},
	},
	{
		key = "TitleLogoLanguage",
		path = {"QingRemasterOptions", "Menu", "TitleLogoLanguage"},
		type = "enum",
		choices = LANG_CHOICES,
		group = "hud",
		surfaces = {mcm = true},
		after_set = refresh_title_logo,
		label = {
			en = "Title logo language",
			zh = "标题 Logo 语言",
		},
		help = {
			en = "Which logo sheet to use. Auto follows game language.",
			zh = "使用哪套 Logo 贴图。自动跟随游戏语言。",
		},
	},
	{
		key = "thor_key",
		path = {"thor_key"},
		type = "keyboard",
		group = "controls",
		surfaces = {imgui = true, mcm = true},
		label = {
			en = "Qing special action (keyboard)",
			zh = "小青特殊动作（键盘）",
		},
		help = {
			en = "Keyboard button for Qing's special teleport / final attack.",
			zh = "小青特殊瞬移/终结攻击的键盘按键。",
		},
	},
	{
		key = "thor_controller",
		path = {"thor_controller"},
		type = "controller",
		group = "controls",
		surfaces = {imgui = true, mcm = true},
		min = 0,
		max = 31,
		label = {
			en = "Qing special action (controller button)",
			zh = "小青特殊动作（手柄按键）",
		},
		help = {
			en = "Raw controller button id used with Input.IsButtonPressed. Default 12.",
			zh = "供 Input.IsButtonPressed 使用的手柄按键编号。默认 12。",
		},
	},
	{
		key = "Off_air_key",
		path = {"Off_air_key"},
		type = "keyboard",
		group = "controls",
		surfaces = {imgui = true, mcm = true},
		label = {
			en = "Tainted Qing Cruise / Guard toggle",
			zh = "里小青 巡航/护卫 切换",
		},
		help = {
			en = "Keyboard button that toggles Cruise / Guard formation. Drop is always also accepted.",
			zh = "切换巡航/护卫阵型的键盘按键。丢弃键始终可用。",
		},
	},
	{
		key = "allow_mouse_control",
		path = {"allow_mouse_control"},
		type = "boolean",
		group = "controls",
		surfaces = {imgui = true, mcm = true},
		label = {
			en = "Mouse aim for Qing",
			zh = "小青鼠标瞄准",
		},
		help = {
			en = "Let Qing aim / trigger special action with the mouse.",
			zh = "允许用鼠标控制小青瞄准/触发特殊动作。",
		},
	},
	{
		key = "mouseSupport",
		path = {"mouseSupport"},
		type = "enum",
		choices = MOUSE_CHOICES,
		group = "controls",
		surfaces = {imgui = true, mcm = true},
		get = schema.mouse_mode,
		set = schema.set_mouse_mode,
		label = {
			en = "Tainted Qing mouse follow",
			zh = "里小青鼠标跟随",
		},
		help = {
			en = "How Tainted Qing's mark follows the mouse.",
			zh = "里小青标记如何跟随鼠标。",
		},
	},
	{
		key = "card_rates",
		type = "card_rates",
		group = "cards",
		surfaces = {mcm = true},
		label = {
			en = "Card appear rates",
			zh = "卡牌出现率",
		},
		help = {
			en = "1 keeps the Thoth card; 0 maps it back to the vanilla card. Also adjustable in ImGui Settings → Cards.",
			zh = "1 保留透特牌；0 映射回原版卡。也可在 ImGui 设置 → 卡牌中调整。",
		},
	},
}

function schema.entry(key)
	for _, entry in ipairs(schema.entries) do
		if entry.key == key then return entry end
	end
	return nil
end

function schema.for_surface(surface, group)
	local out = {}
	for _, entry in ipairs(schema.entries) do
		if entry.surfaces and entry.surfaces[surface] then
			if not group or entry.group == group then
				out[#out + 1] = entry
			end
		end
	end
	return out
end

function schema.read(entry)
	if entry.get then return entry.get() end
	if entry.path then return schema.get(entry.path) end
	return nil
end

function schema.write(entry, value)
	if entry.set then
		entry.set(value)
	elseif entry.path then
		schema.set(entry.path, value)
	end
	if entry.after_set then entry.after_set() end
end

return schema
