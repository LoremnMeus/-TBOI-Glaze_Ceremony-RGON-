local save = require("Qing_Remaster_scripts.core.savedata")
local ModConfig = require("Qing_Remaster_scripts.others.Mod_Config_Menu_holder")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local enums = require("Qing_Remaster_scripts.core.enums")
local translations = require("Qing_Remaster_scripts.translations.translate")
local item_color_holder = require("Qing_Remaster_scripts.others.Item_color_holder")
local achievement_tracker = require("Qing_Remaster_scripts.core.achievement_tracker")
local CompletionMarks = require("Qing_Remaster_scripts.core.completion_marks_manager")
local unlock_board = require("Qing_Remaster_scripts.data.unlock_board")
local dev_env = require("Qing_Remaster_scripts.core.dev_environment")
local imgui_layout = require("Qing_Remaster_scripts.debug.imgui_debug_layout")
local probe_registry = require("Qing_Remaster_scripts.debug.probe_registry")
local settings_ui = require("Qing_Remaster_scripts.debug.rgon_imgui_settings_ui")
local debug_ui = require("Qing_Remaster_scripts.debug.rgon_imgui_debug_ui")
local probes_ui = require("Qing_Remaster_scripts.debug.rgon_imgui_probes_ui")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "Rgon_Imgui_Options_",
	menu_id = "QingRemasterOptions_Menu",
	settings_id = "QingRemasterOptions_Settings",
	debug_id = "QingRemasterOptions_Debug",
	achievements_id = "QingRemasterOptions_Achievements",
	default_window = {
		settings = {w = 720,h = 560,screen_w = 0.72,screen_h = 0.78,},
		debug = {w = 800,h = 620,screen_w = 0.80,screen_h = 0.84,},
		achievements = {w = 860,h = 680,screen_w = 0.82,screen_h = 0.88,},
	},
	spectral_editor = {
		ids = {},
		options = {},
		selected_index = 1,
		selected_id = nil,
		draft_name = "",
		draft_description = "",
		signature = nil,
		last_deleted = nil,
	},
	defaults = {
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
		Auto_Live = false,
		Trigger_LaserStart = true,
		Trigger_LaserEnd = true,
		Trigger_BrimStart = true,
		Trigger_BrimEnd = true,
		QingRemasterOptions = {
			Achievements = {
				PlayManualAnimations = true,
				LegacyCompletionTracker = false,
			},
			CompletionMarks = {
				CharacterDrawPostit = false,
				CharacterOffsetX = -70,
				CharacterOffsetY = 26,
			},
			CardAppearRates = {},
			Live = {
				BulletSoftLimit = 72,
				BulletHardLimit = 120,
				BulletSpeed = 1.5,
				BulletScale = 1,
				BulletOpacity = 1,
				MessageIntervalScale = 1,
			},
			Compatibility = {
				UseRgonImitateItems = true,
			},
			Gameplay = {
				ShowTempItemHUD = true,
				TempHUD_LargePadX = 16,
				TempHUD_LargePadY = 38,
				TempHUD_MiniPadX = 8,
				TempHUD_MiniPadY = 19,
				TempHUD_LargeStep = 32,
				TempHUD_MiniStep = 16,
			},
			Menu = {
				CharacterSelectLanguage = 0,
				ControlsLanguage = 0,
				GameOverLanguage = 0,
				TitleLogoCustom = true,
				TitleLogoRainbow = true,
				TitleLogoRainbowSolo = false,
				TitleLogoRainbowLumLow = 0.07,
				TitleLogoRainbowLumHigh = 0.29,
				TitleLogoRainbowTextLumLow = 0.05,
				TitleLogoRainbowTextLumHigh = 0.10,
				TitleLogoRainbowSpatialAngle = 0,
				TitleLogoRainbowSpatialDensity = 2.6,
				TitleLogoRainbowSpeed = 0.65,
				TitleLogoRainbowDirection = 1,
				TitleLogoRainbowGrayHue = 0.47,
				TitleLogoRainbowBend = 0.15,
				TitleLogoRainbowShapeContrast = 0.40,
				TitleLogoLanguage = 0,
				TitleLogoOffsetX = -39,
				TitleLogoOffsetY = -15,
			},
			Debug = {
				TheseusNoticeAlwaysShow = false,
				TheseusNoticeSourceY = 0,
				TheseusNoticeColonY = -7.25,
				TheseusNoticeAmountY = -7.25,
				TheseusNoticeTriggerY = -3,
				TheseusNoticeArrowY = -6,
				TheseusNoticeActionY = -0.75,
				TheseusNoticeSourceScale = 0.5,
				TheseusNoticeColonScale = 1,
				TheseusNoticeAmountScale = 1,
				TheseusNoticeTriggerScale = 0.5,
				TheseusNoticeArrowScale = 1,
				TheseusNoticeActionScale = 0.5,
				BlueprintDotOffsetX = -2,
				BlueprintDotOffsetY = -9,
				BlueprintBgOffsetX = 0,
				BlueprintBgOffsetY = 13,
				BlueprintAuditTextY = 2,
				BlueprintSlotCount = 3,
				BlueprintCostOffsetY = 21,
				BlueprintCostExtraCount = 0,
				BlueprintCostSlotSize = 18,
				BlueprintCostTokenScale = 0.5,
				BlueprintCostQmarkOffsetX = -2,
				BlueprintCostQmarkOffsetY = 1,
				BlueprintCraftGroupY = 14,
				BlueprintTagColOffsetX = -36,
				BlueprintTagColOffsetY = 0,
				BlueprintTagColWidth = 56,
				BlueprintShowSourceMarks = false,
				BlueprintAllItemsModeEnabled = not dev_env.is_public_release(),
				BlueprintSettingsVersion = 8,
				SuperBombsBombGrowthSeconds = 20,
				SuperBombsMamaGrowthSeconds = 120,
				SuperBombsTimerX = -7,
				SuperBombsTimerY = -8.25,
				TitleMarqueeStartX = 320,
				TitleMarqueeEndX = 80,
				TitleMarqueeY = 95,
				TitleMarqueeSpeed = 28,
				TitleMarqueeFadeWidth = 48,
				TitleMarqueeLetterSpacing = 4,
				TitleMarqueeRainbowSpeed = 0.7,
				TitleMarqueeWaveSpeed = 0.26,
				TitleMarqueeEdgeIntensity = 0.45,
				TitleMarqueeEdgeWaveWidth = 0.75,
				TitleMarqueeEdgePeakSharpness = 6,
				TitleMarqueeBounceSpeed = 2.5,
				TitleMarqueeBounceTravelSpeed = 24,
				TitleMarqueeBounceHeight = 9,
				TitleMarqueeSquashX = 0.10,
				TitleMarqueeSquashY = 0.95,
				TitleMarqueeImpactSharpness = 6,
				TitleMarqueeTangentRotation = 1,
				DynamicLightingEnabled = false,
				DynamicLightingAmbient = 0.03,
				DynamicLightingRadius = 220,
				DynamicLightingIntensity = 1.45,
				DynamicLightingSoft = 0.18,
				DynamicLightingColorR = 1,
				DynamicLightingColorG = 1,
				DynamicLightingColorB = 1,
				TorsionDemoPeak = 0.1,
				TorsionDemoStretch = 0.07,
				TorsionDemoSlideAng = 28,
				TorsionDemoSegHalfPx = 90,
				TorsionDemoTotal = 60,
				TorsionDemoHold = 5,
				TorsionDemoAngle = -1,
				TorsionDemoGap = 0.00025,
				TorsionDemoSoft = 0.042,
				TorsionDemoBandPx = 70,
				AnnaTorsionPeak = 0.1,
				AnnaTorsionStretchRatio = 0.7,
				AnnaTorsionSlideAng = 28,
				AnnaTorsionGap = 0.0002,
				AnnaTorsionSoft = 0.045,
				AnnaTorsionBandPx = 52,
				AnnaTorsionTotal = 14,
				AnnaTorsionHold = 2,
				AnnaTorsionFrame = 5,
				SuperBombsTimerPositionVersion = 1,
				CharonSpawnInterval = 15,
				CharonParticleLifetime = 120,
				CharonFadeFrames = 20,
				CharonForegroundRate = 0.2,
				CharonRowsPerAnchor = 1,
				CharonRoomPrefillRatio = 0.5,
				CharonRoomFadeFrames = 15,
				CharonForceSeijaEnhancement = false,
				CharonSeijaSpeedMultiplier = 4,
				CharonPickupProtectRadius = 120,
				CharonSettingsVersion = 4,
				BloodyMapForceSeijaEnhancement = false,
				PerhapsChosenForceSeija = false,
				GlazeCrownForceSeija = false,
				BookOfThothForceSeija = false,
				BookOfThothDivineSplit = 0.4,
				BookOfThothDotOffsetX = 0,
				BookOfThothDotOffsetY = -11,
				BookOfThothBgOffsetX = 0,
				BookOfThothBgOffsetY = 0,
				BookOfThothTabCatalogTextX = -31.2,
				BookOfThothTabCatalogTextY = -6.4,
				BookOfThothTabDivineTextX = -32.2,
				BookOfThothTabDivineTextY = -7.0,
				BookOfThothSlotCardScale = 1.0,
				BookOfThothSlotCardOffsetX = 1,
				BookOfThothSlotCardOffsetY = -8,
				BookOfThothHudCardScale = 0.5,
				BookOfThothHudCardOffsetX = 0,
				BookOfThothHudCardOffsetY = 0,
				BookOfThothPoolOffsetY = -15,
				BookOfThothPageLabelOffsetX = 0,
				BookOfThothPageLabelOffsetY = 0,
				BookOfThothCupHitOffsetX = 0,
				BookOfThothCupHitOffsetY = 1,
				BookOfThothCupHitW = 44,
				BookOfThothCupHitH = 66,
				GospelForceSeija = false,
				DarkMysticismForceSeija = false,
				MultiknifeHud7 = 5.5,
				MultiknifeHud8 = 9.5,
				MultiknifeHud9 = 16.5,
				MultiknifeHud10 = 28.0,
				MultiknifeHud11 = 40.0,
				MultiknifeHud12 = 56.0,
				MultiknifeLiftX = 0,
				MultiknifeLiftY = -20,
				DramaForceMask = false,
				DramaMaskKind = 0,
				MentalForceError = false,
				SutureNeedleForceSeija = false,
				VoiceForceSeijaDefy = false,
				BloodyMapMessengerSpawnChance = 0.4,
				BloodyMessengerPayNothingChance = 0.3,
				BloodyMessengerDoubleRewardChance = 0.3,
				BloodyMessengerWeightNothing = 40,
				BloodyMessengerWeightUltraRoom = 15,
				BloodyMessengerWeightCrackedKey = 25,
				BloodyMessengerWeightItem = 20,
				BloodyMessengerBoostedWeightUltraRoom = 30,
				BloodyMessengerBoostedWeightCrackedKey = 40,
				BloodyMessengerBoostedWeightItem = 30,
				BloodyMapUltraGrantAmount = 1,
				BloodyMapUltraGrantMax = 2,
				GoldenSlotBaseWinChance = 10,
				GoldenSlotWinChancePerLoss = 4,
				GoldenSlotMaxWinChance = 40,
				GoldenSlotRewardWeightMidasFly = 24,
				GoldenSlotRewardWeightGoldTroll = 15,
				GoldenSlotRewardWeightGoldCoin = 18,
				GoldenSlotRewardWeightGoldHeart = 11,
				GoldenSlotRewardWeightGoldPill = 8,
				GoldenSlotRewardWeightGoldBattery = 6,
				GoldenSlotRewardWeightGoldBomb = 5,
				GoldenSlotRewardWeightGoldKey = 5,
				GoldenSlotRewardWeightGoldMegaPill = 3,
				GoldenSlotRewardWeightGoldTrinket = 4,
				GoldenSlotRewardWeightEnding = 1,
				GoldenSlotEndingMegaWeight = 95,
				GoldenSlotEndingTrophyWeight = 5,
				ReservedJudgmentMarkRange = 90,
				ReservedJudgmentIconOffsetX = 18,
				ReservedJudgmentIconOffsetY = 22,
				ReservedJudgmentIconScale = 1,
				DiamondShopPrice = 5,
				DiamondMerchantChance = 0.5,
				DiamondHudBaseOffsetX = 4,
				DiamondHudBaseOffsetY = -50,
				DiamondHudIconOffsetX = -20,
				DiamondHudIconOffsetY = 17.5,
				DiamondHudIconScale = 0.5,
				DiamondHudArrowOffsetX = -10,
				DiamondHudArrowOffsetY = -2,
				DiamondHudArrowScale = 1.0,
				DiamondHudDigitTensOffsetX = 3,
				DiamondHudDigitOnesOffsetX = 9.0,
				DiamondHudDigitOffsetY = -2,
				DiamondHudDigitScale = 1.0,
				DiamondHudCentOffsetX = 20,
				DiamondHudCentOffsetY = 8,
				DiamondHudCentScale = 0.5,
				RemasterCodeFlipSpacing = 4,
				RemasterPanelOffsetX = 0,
				RemasterPanelOffsetY = 40,
				PareidoliaPreview = false,
				PareidoliaDetailedBack = true,
				PareidoliaForceSpin = false,
				PareidoliaFxLiftStart = 36,
				PareidoliaFxLiftHover = 160,
				PareidoliaFxLiftMax = 260,
				PareidoliaFxScreenTopPct = 0.22,
				PareidoliaFxAscendFrames = 48,
				PareidoliaPhaseLift = 90,
				PareidoliaFloatRate = 0.11,
				RestrictedUnlocked = false,
				PinnedModules = {},
				DebugPageAccess = {},
			},
		},
	},
}

local LANG = {
	en = {
		menu = "\u{f12e} Qing Remaster",
		settings_item = "\u{f013} Settings",
		settings_title = "Qing Remaster - Settings",
		debug_item = "\u{f492} Debug",
		debug_title = "Qing Remaster - Debug",
		probes_item = "\u{f0c3} Probes",
		probes_title = "Qing Remaster - Probes",
		achievements_item = "\u{f091} Achievements",
		achievements_title = "Qing Remaster - Achievements",
		live_item = "\u{f03d} Live Broadcast",
		live_title = "Qing Remaster - Live Broadcast",
		tab_debug_tools = "Debug tools",
		debug_page_recent = "Recent",
		debug_page_items = "Items",
		debug_page_cards = "Cards",
		debug_page_characters = "Characters",
		debug_page_systems = "Systems",
		debug_page_visual = "Visual",
		debug_page_data = "Data",
		debug_page_tests = "Tests",
		probe_page_items = "Items",
		probe_page_characters = "Characters",
		probe_page_systems = "Systems",
		probe_page_visual = "Visual",
		probe_page_runtime = "Runtime",
		debug_page_flight = "Blueprint & Flight",
		debug_recent_help = "Home mirrors pinned controls and recently edited parameters (same settings paths, no navigation).",
		debug_recent_empty = "No recently edited controls yet.",
		debug_recent_clear = "Clear recent",
		debug_pinned_help = "Pinned on Home",
		debug_pinned_empty = "No pins yet. Use Pin to Home at the bottom of a home-enabled module.",
		debug_back_recent = "Back to recent",
		debug_goto_page = "View category",
		debug_nav_help = "Target located. Click the named Debug Tab to open it (RGON cannot script-select Tabs).",
		debug_nav_click_tab = "Please click the '%s' Tab.",
		debug_pin_module = "Pin to Home",
		debug_unpin_module = "Remove from Home",
		debug_recent_pages = "Recently used pages",
		debug_recent_modules = "Recently Edited",
		debug_restricted_locked = "Restricted edits: locked",
		debug_restricted_unlock = "Unlock restricted Data edits (developer)",
		debug_restricted_status = "Restricted edit status: %s",
		debug_restricted_unlocked = "unlocked",
		debug_restricted_locked_word = "locked",
		group_blueprint_eid_audit = "Blueprint EID audit export",
		blueprint_eid_audit_help = "Exports assembled craft EID lines for length review (zh/en JSON under codex_work/logs).",
		blueprint_eid_audit_export = "Export Blueprint EID audit",
		tab_permanent_data = "Permanent data",
		tab_item_colors = "Item colors",
		tab_cards = "Cards",
		card_rates_help = "Per-card appear rate for Qing Thoth cards (0 = always map back to vanilla, 1 = always keep). Stored in ModConfigSettings.",
		card_rates_restore = "Restore all card rates to default",
		card_rate_suffix = " appear rate",
		achievement_characters = "Characters",
		achievement_bosses = "Bosses",
		achievement_other = "Other",
		achievement_settings = "Settings",
		achievement_manual_animation = "Play animation when checking achievements",
		achievement_manual_animation_help = "Only controls manual unlocks from this achievement window. Normal gameplay unlocks still use achievement papers.",
		achievement_legacy_tracker = "Legacy room-scan completion tracker",
		achievement_legacy_tracker_help = "Default off. Re-enables the old per-frame boss-room scan so it can be compared with RGON completion callbacks.",
		completion_marks_character = "Character menu paper probe",
		completion_marks_character_help = "Character select does not draw the pause paper by default. Enable this only to tune XY against RGON RenderPos, then report the values.",
		completion_marks_character_draw = "Draw paper on character select",
		completion_marks_character_x = "Character paper offset X",
		completion_marks_character_y = "Character paper offset Y",
		completion_marks_character_xy = "Current XY: %.2f, %.2f (relative to RGON RenderPos)",
		completion_marks_character_restore = "Restore character-paper probe defaults",
		completion_marks_audit = "Audit and sync completion marks",
		completion_marks_audit_result = "Audit complete: %d characters, %d mismatched marks reconciled.",
		achievement_reward = "Unlocks: %s",
		achievement_no_reward = "No unlock content configured",
		achievement_unlock = "Unlock",
		achievement_normal = "Normal",
		achievement_hard = "Hard",
		achievement_normal_victory = "Defeated by normal",
		achievement_tainted_victory = "Defeated by tainted",
		achievement_unlock_all = "Unlock all",
		achievement_lock_all = "Lock all",
		achievement_saved = "Achievement data saved.",
		tab_compatibility = "Compatibility",
		tab_gameplay = "Gameplay",
		tab_hud = "HUD",
		group_hud_imitate = "Imitate items",
		group_character_menu_lang = "Character select language",
		character_menu_lang_help = "Swaps Qing character-select text sheets. Default follows the game language.",
		character_menu_lang_auto = "Follow game language",
		character_menu_lang_zh = "Force Chinese",
		character_menu_lang_en = "Force English",
		character_menu_lang_status = "Current sheets: %s (game language: %s)",
		group_controls_lang = "Starting-room controls language",
		controls_lang_help = "Swaps the starting-room controls prompt. Default follows the game language.",
		controls_lang_status = "Current controls sheets: %s (game language: %s)",
		group_game_over_lang = "Game-over name language",
		game_over_lang_help = "Swaps the game-over character name. Default follows the game language.",
		game_over_lang_status = "Current game-over sheets: %s (game language: %s)",
		group_title_logo = "Title screen logo",
		title_logo_help = "Overlay the mod title logo on the title screen. Uncheck to restore the vanilla Binding of Isaac logo.",
		title_logo_custom = "Use mod title logo",
		title_logo_custom_help = "When off, the vanilla title logo is shown again and the overlay is not drawn.",
		title_logo_rainbow = "Rainbow logo overlay (test)",
		title_logo_rainbow_help = "Draw the logo fragment as two 80px rainbow bands (big title + subtitle) on top of the normal logo. Temporary test toggle.",
		title_logo_rainbow_solo = "Solo overlay only (diagnose)",
		title_logo_rainbow_solo_help = "Skip the base logo and draw only the rainbow bands. Raw dark-red = rendered but shader off/broken; rolling rainbow = shader OK; nothing = overlay not rendering.",
		title_logo_rainbow_status = "Overlay status: %s",
		title_logo_rainbow_lum_low = "Rainbow roll luminance low (title)",
		title_logo_rainbow_lum_high = "Rainbow roll luminance high (title)",
		title_logo_rainbow_lum_help = "Big-title band (top 80px). Art ~0.07–0.29. Raise Low to deepen borders; lower High to brighten fill sooner.",
		title_logo_rainbow_text_lum_low = "Rainbow roll luminance low (subtitle)",
		title_logo_rainbow_text_lum_high = "Rainbow roll luminance high (subtitle)",
		title_logo_rainbow_text_lum_help = "Small-text band (bottom 80px). Pixels are almost all ~0.076 — keep a tight bright window (default 0.05–0.10) or it goes near-black.",
		title_logo_rainbow_spatial_angle = "Rainbow roll spatial angle (deg)",
		title_logo_rainbow_spatial_density = "Rainbow roll spatial density",
		title_logo_rainbow_spatial_help = "Band direction (0/45/90…) and how many rainbow cycles across the sprite. Quantized to 16×16 packed Colorize.r.",
		title_logo_rainbow_speed = "Rainbow roll speed",
		title_logo_rainbow_direction = "Rainbow roll time direction",
		title_logo_rainbow_motion_help = "Time spin rate (0=static) and sign (+1 / -1). Seed is mixed into phase in Lua, not sent to the shader.",
		title_logo_rainbow_gray_hue = "Rainbow roll gray→hue weight",
		title_logo_rainbow_bend = "Rainbow roll spatial bend",
		title_logo_rainbow_shape_contrast = "Rainbow roll shape contrast",
		title_logo_rainbow_style_help = "ColorOffset params: how much luminance shifts hue, how curved bands are, and how strongly remapped gray keeps border/fill contrast. Defaults match prior fixed constants.",
		title_logo_lang_help = "Choose which logo sheet to use when the mod logo is enabled. Auto follows game language. Chinese sheet is not bundled yet and falls back to English.",
		title_logo_lang_status = "Current logo: %s (game language: %s)",
		title_logo_offset_x = "Logo overlay offset X",
		title_logo_offset_y = "Logo overlay offset Y",
		title_logo_offset_help = "Menu-space offset added at WorldToMenuPosition(0,0). Tune on the title screen, then report the values.",
		title_logo_offset_restore = "Restore logo offset defaults",
		group_rgon = "REPENTOGON",
		group_runtime = "Runtime",
		group_hud = "HUD",
		show_temp_item_hud = "Show temporary items on Extra HUD",
		show_temp_item_hud_help = "Draw Qing temporary items as semi-transparent icons after the vanilla Extra HUD list. Follows Options.ExtraHUDStyle.",
		temp_hud_large_pad_x = "Large panel pad X",
		temp_hud_large_pad_y = "Large panel pad Y",
		temp_hud_mini_pad_x = "Mini panel pad X",
		temp_hud_mini_pad_y = "Mini panel pad Y",
		temp_hud_large_step = "Large panel step",
		temp_hud_mini_step = "Mini panel step",
		temp_hud_restore = "Restore Extra HUD layout defaults",
		temp_hud_layout_help = "Origin from HistoryHUD offsets when present, else (0,0). Pad defaults: large 16/38, mini 8/19.",
		group_attack_callbacks = "Attack callback trigger points",
		group_live_general = "Broadcast mode",
		group_live_comments = "Scrolling comments",
		group_maintenance = "Maintenance",
		group_debug = "Debug",
		group_title_marquee = "Title marquee",
		group_dynamic_lighting = "Dynamic Lighting (Phase 1)",
		dynamic_lighting_help = "Fullscreen dark overlay + circular player light. High-contrast defaults. HUD may darken (no room clip). Toggle on after reloadshaders.",
		dynamic_lighting_enabled = "Enable dynamic lighting",
		dynamic_lighting_ambient = "Ambient darkness floor",
		dynamic_lighting_ambient_help = "Brightness outside the light (0=pitch black). Lower = stronger contrast.",
		dynamic_lighting_radius = "Player light radius (world)",
		dynamic_lighting_intensity = "Light intensity",
		dynamic_lighting_soft = "Soft falloff",
		dynamic_lighting_color_r = "Light color R",
		dynamic_lighting_color_g = "Light color G",
		dynamic_lighting_color_b = "Light color B",
		group_torsion = "Torsion slash test",
		torsion_help = "Finite segment cut + angled slide (first rewrite). Angle <0 = random.",
		torsion_trigger = "Trigger torsion",
		torsion_peak = "Slide amount (UV)",
		torsion_stretch = "Seam stretch (UV)",
		torsion_slide_ang = "Slide fork angle (deg)",
		torsion_seg_half = "Segment half-length (px)",
		torsion_total = "Duration (frames)",
		torsion_hold = "Hold peak (frames)",
		torsion_angle = "Cut angle (deg, -1=random)",
		torsion_gap = "Gap half-width",
		torsion_soft = "Falloff width",
		torsion_band = "Perp. half-width (px)",
		group_anna_torsion = "Anna sword torsion",
		anna_torsion_help = "Normal slash: takeoff->landing segment; band limits effect beside the path.",
		anna_torsion_peak = "Slide amount (UV)",
		anna_torsion_stretch_ratio = "Stretch / slide ratio",
		anna_torsion_slide_ang = "Fork angle (deg)",
		anna_torsion_gap = "Gap half-width",
		anna_torsion_soft = "Falloff width",
		anna_torsion_band = "Perp. half-width (px)",
		anna_torsion_total = "Duration (frames)",
		anna_torsion_hold = "Hold peak (frames)",
		anna_torsion_frame = "Trigger frame (after land)",
		title_marquee_start_x = "Right spawn X",
		title_marquee_end_x = "Left disappear X",
		title_marquee_y = "Baseline Y",
		title_marquee_speed = "Scroll speed",
		title_marquee_fade = "Left fade width",
		title_marquee_spacing = "Letter spacing",
		title_marquee_rainbow_speed = "Rainbow cycle speed",
		title_marquee_wave_speed = "Edge wave speed",
		title_marquee_edge_intensity = "Edge wave intensity",
		title_marquee_edge_wave_width = "Edge color range",
		title_marquee_edge_peak_sharpness = "Edge peak sharpness",
		title_marquee_bounce_speed = "Bounce speed",
		title_marquee_bounce_travel_speed = "Bounce wave travel speed",
		title_marquee_bounce_height = "Bounce height",
		title_marquee_squash_x = "Impact horizontal stretch",
		title_marquee_squash_y = "Impact vertical squash",
		title_marquee_impact_sharpness = "Impact peak sharpness",
		title_marquee_tangent_rotation = "Tangent rotation strength",
		title_marquee_help = "Coordinates use the title menu's 480x270 design space. Letters emerge at Start X and fade while approaching End X.",
		group_theseus_notice = "Theseus's Sign notice",
		group_super_bombs = "Super Bombs",
		group_seeker_wall_probe = "Seeker's Eye wall probe",
		seeker_wall_probe_help = "Logs seeker wall A*/tangent checks (blocked octants, inward, tangent-from-away vs raw). Writes codex_work/logs/seeker_wall_probe.jsonl. Off by default.",
		seeker_wall_probe_enable = "Enable Seeker's Eye wall probe",
		seeker_wall_probe_export = "Refresh wall-probe status",
		seeker_wall_probe_clear = "Clear wall-probe log",
		seeker_wall_probe_status = "Probe off",
		group_blue_print = "Blue Print UI",
		group_craft_familiar = "Craft familiar (Air Flight)",
		craft_familiar_status = "(no bound craft familiar)",
		craft_familiar_freeze_cd = "Freeze craft fire cooldown",
		craft_familiar_freeze_cd_help = "Debug only. Stops craft_fire_cooldown countdown while checked.",
		craft_familiar_force_fire = "Force fire once",
		craft_familiar_force_fire_help = "Debug only. Next Familiar update may fire ignoring cooldown; auto-clears.",
		craft_familiar_restore = "Restore craft familiar debug defaults",
		air_debug_move_spd = "Air Flight move speed override",
		air_debug_move_spd_help = "Debug only. >0 overrides craft profile speed for Air Flight body movement. 0 = use profile.",
		air_debug_force_luck = "Force Air Flight luck = 99",
		air_debug_force_luck_help = "Debug only; works alone. On = force 99 (overrides console debug 9). Off = use debug 9 HIGH_LUCK if active, else craft profile (0 luck ≈ Mom's Eye 50%, Loki 25%). Affects Mom's Eye / Loki / Tech IX craft rolls.",
		air_debug_hit_status = "Hit / volley status (click refresh)",
		air_debug_hit_refresh = "Refresh hit / volley status",
		group_aura_balance = "Aura balance (Monstrance)",
		aura_balance_help = "Monstrance radius / halo scale defaults are half of the first craft pass. Drag to retune; Restore resets to craft defaults.",
		aura_bal_mon_radius = "Monstrance radius",
		aura_bal_mon_scale = "Monstrance FX scale",
		aura_bal_mon_interval = "Monstrance damage interval",
		aura_bal_restore = "Restore Monstrance defaults",
		group_flight_crash = "Flight Crash FX",
		flight_crash_fail_frames = "Fail frames",
		flight_crash_gravity = "Gravity",
		flight_crash_max_fall = "Max fall speed",
		flight_crash_drift = "Drift retain",
		flight_crash_slip = "Side slip max",
		flight_crash_fall_smoke = "Fall smoke interval",
		flight_crash_tumble_fric = "Tumble friction",
		flight_crash_tumble_max = "Tumble max frames",
		flight_crash_impact_dust = "Impact dust count",
		flight_crash_dead_min = "Dead smoke min",
		flight_crash_dead_max = "Dead smoke max",
		flight_crash_shake = "Screen shake",
		flight_crash_cap = "Particle cap / Flight",
		flight_crash_force = "Force Crash",
		flight_crash_force_revive = "Force Crash + Revive",
		flight_crash_clear = "Repair / Clear FX",
		flight_crash_restore = "Restore crash FX defaults",
		group_temp_revive = "Temporary revive ledger",
		temp_revive_help = "Tracks spent innate revive copies (1UP / Dead Cat / ...). Held-sprite capture after revive confirms source. Default logging off.",
		temp_revive_log = "Log held-sprite / spend decisions",
		temp_revive_clear = "Clear spent for P0",
		temp_revive_status = "Spent / grants / events",
		blueprint_dot_x = "Outline dot X offset",
		blueprint_dot_y = "Outline dot Y offset",
		blueprint_dot_help = "Offset for the '.' used to draw Blue Print hitbox outlines. Positive X/Y move right/down.",
		blueprint_bg_x = "Background X offset",
		blueprint_bg_y = "Background Y offset",
		blueprint_bg_help = "Offset only for the Blue Print panel background sprite.",
		blueprint_audit_y = "Effect text Y offset",
		blueprint_audit_y_help = "Extra padding below the lowest ingredient/cost slot for live effect lines.",
		blueprint_slot_count = "Ingredient slot count (unused)",
		blueprint_slot_count_help = "Slots are now driven by base-item quality. This slider is unused.",
		blueprint_cost_y = "Cost slot Y offset",
		blueprint_cost_y_help = "Cost mini-slots sit under the target icon; positive Y moves them down.",
		blueprint_cost_extra = "Cost slot extra count",
		blueprint_cost_extra_help = "Extra empty cost mini-slots drawn beyond the required cost (layout testing).",
		blueprint_craft_group_y = "Craft group Y offset",
		blueprint_craft_group_y_help = "Moves the target icon + ingredient slots (+ cost slots) as one group. Positive Y is down.",
		blueprint_tag_col_x = "Audit tag column X",
		blueprint_tag_col_y = "Audit tag column Y",
		blueprint_tag_col_help = "Tag column anchor is the bag panel's right edge. Negative X pulls inward toward the bag.",
		blueprint_tag_col_w = "Audit tag column width",
		blueprint_tag_col_w_help = "Width of the audit tag filter column (px).",
		blueprint_show_source_marks = "Show source marks (P/A)",
		blueprint_show_source_marks_help = "Show prototype/audit corner badges and source outlines on craft tokens. Off by default.",
		blueprint_all_items_mode = "Enable Blueprint all-items audit mode",
		blueprint_all_items_mode_help = "Enables the Blueprint all-collectibles catalog for compatibility auditing and testing. Disabled by default in public builds.",
		blueprint_tutorial_status = "Tutorial: idle",
		blueprint_tutorial_start = "Start Blueprint tutorial",
		blueprint_tutorial_start_skip = "Start tutorial (skip prompt)",
		blueprint_tutorial_abort = "Abort tutorial and cleanup",
		blueprint_tutorial_reset = "Reset first-open tutorial flag",
		blueprint_tutorial_help = "Tainted Qing first-open Blueprint lesson. Debug can re-enter anytime. End always deletes practice crafts.",
		blueprint_cost_scale = "Cost icon scale",
		blueprint_cost_scale_help = "Scale of cost question-mark / tokens inside the mini-slot (default 0.5).",
		blueprint_cost_slot_size = "Cost slot size (px)",
		blueprint_cost_slot_size_help = "Outline box size. Dot step is 8px: 16 -> 3 dots, 32 -> 5 dots (large slots use ~34).",
		blueprint_cost_qmark_x = "Cost ? offset X",
		blueprint_cost_qmark_y = "Cost ? offset Y",
		blueprint_cost_qmark_help = "Pixel offset for the cost-slot question-mark sprite.",
		group_charon_tide = "Charon's Sign black tide",
		group_ritual_sting = "Ritual Sting color bars",
		ritual_sting_help = "Runtime bars for the first holder (0–cap). Threshold unlocks each color effect; Blue unlocks tears + holy-water trails on POST_ATTACK_DPS_SAMPLE. Not saved.",
		ritual_sting_red = "Red", ritual_sting_orange = "Orange", ritual_sting_yellow = "Yellow",
		ritual_sting_green = "Green", ritual_sting_blue = "Blue", ritual_sting_purple = "Purple",
		ritual_sting_give = "Give Ritual Sting",
		ritual_sting_give_help = "Adds Ritual Sting to player 0 if missing.",
		ritual_sting_give_ok = "Ritual Sting ready.",
		ritual_sting_enable_blue = "Unlock Blue (water trail)",
		ritual_sting_enable_blue_help = "Sets Blue to the unlock threshold so DPS-sample water trails fire while shooting.",
		ritual_sting_enable_blue_ok = "Blue unlocked (water trail).",
		ritual_sting_fill_all = "Unlock all colors",
		ritual_sting_reset = "Reset Ritual Sting bars",
		group_death_sentence = "Death Sentence letters",
		death_sentence_help = "Edits the death word and letters of the first current holder. This is runtime test data, not a persistent option.",
		death_sentence_death_word = "Death letters",
		death_sentence_letters = "Current letters",
		group_remaster = "Remaster!",
		remaster_help = "Floor-code flip animation and Tptron panel layout. Spacing scales overall step duration; mid-path letters are always faster.",
		remaster_flip_spacing = "Code flip letter spacing",
		remaster_flip_spacing_help = "Larger spacing slows alphabet cascading (B->D plays C through). Mid letters stay relatively faster.",
		remaster_panel_offset_x = "Panel offset X",
		remaster_panel_offset_y = "Panel offset Y",
		remaster_panel_offset_help = "Screen-pixel offset for the Tptron panel (positive Y moves down). Applied after the default center/rise position.",
		remaster_channels_help = "Permanent teleport links (PROFILE.PermanentData). Survive new runs until a return consumes them.",
		remaster_channel_list = "Channel list",
		remaster_channel_empty = "(no permanent channels)",
		remaster_channel_select = "Selected channel",
		remaster_channel_from = "From stage command",
		remaster_channel_to = "To stage command",
		remaster_channel_from_help = "e.g. 1, 5c, 10a. Use Fill From Current while in a run.",
		remaster_channel_to_help = "Target floor stage command. Same format as the stage console command.",
		remaster_channel_fill_from = "Fill From = current floor",
		remaster_channel_add = "Add / upsert permanent channel",
		remaster_channel_remove = "Remove selected channel",
		remaster_channel_clear_all = "Clear all permanent channels",
		remaster_channel_added = "Permanent Remaster channel saved.",
		remaster_channel_removed = "Selected Remaster channel removed.",
		remaster_channel_cleared = "All Remaster channels cleared.",
		remaster_channel_bad_cmd = "Invalid stage command(s).",
		group_imitate_items = "Imitate items",
		permanent_data_help = "Archive-level PermanentData. “Next run ...” effects also live here. Non-permanent debug knobs stay on Debug tools.",
		group_spectral_rewrites = "Spectral Sword rewrites",
		group_colorblind_bans = "Colorblindness next-run bans",
		colorblind_bans_help = "Collectibles removed from the next run's item pools by Colorblindness dislikes. Cleared after they apply at run start.",
		colorblind_bans_empty = "(no next-run bans)",
		colorblind_bans_clear = "Clear next-run bans",
		colorblind_bans_cleared = "Colorblindness next-run bans cleared.",
		group_diamond_permanent = "Diamond permanent price",
		diamond_permanent_help = "Cross-run shop price / last sale for Qing's Faceted Market Diamond.",
		diamond_last_sale = "Last sale price",
		diamond_permanent_restore = "Restore Diamond permanent prices",
		group_book_of_future_permanent = "Book of Future escape",
		book_of_future_progress_help = "Archive-level accumulated quality retained after the book escapes. The next Book of Future resumes from this value toward 50.",
		book_of_future_progress = "Accumulated quality",
		book_of_future_progress_restore = "Clear Book of Future progress",
		spectral_clear_all = "Clear all Spectral Sword rewrites",
		spectral_cleared_notice = "All Spectral Sword rewrites cleared.",
		group_item_colors = "Mod item color analysis",
		item_colors_help = "REPENTOGON scans mod collectible icons in small batches. Hand-authored labels remain overrides; automatic labels extend Glazed Dice Shard compatibility.",
		item_colors_restart = "Restart color scan",
		item_colors_print = "Print detailed report",
		item_colors_restarted = "Mod item color scan restarted.",
		item_colors_printed = "Item color report printed to log.",
		spectral_editor_help = "Legacy item-inscription editor (name / pickup Desc rewrites). Spectral Sword no longer creates these; data lives in systems/item_inscription.",
		spectral_entry = "Modified item",
		spectral_name = "Name",
		spectral_description = "Description",
		spectral_no_entries = "No saved rewrites",
		spectral_save = "Save selected rewrite",
		spectral_reload = "Discard draft changes",
		spectral_delete = "Delete selected rewrite",
		spectral_undo_delete = "Undo last deletion",
		spectral_saved_notice = "Spectral Sword rewrite saved.",
		spectral_deleted_notice = "Spectral Sword rewrite deleted.",
		spectral_restored_notice = "Deleted Spectral Sword rewrite restored.",
		spectral_no_selection = "Select a saved rewrite first.",
		spectral_nothing_to_undo = "There is no deleted rewrite to restore.",
		use_rgon_imitate = "Use RGON innate collectible backend for fake items",
		use_rgon_imitate_help = "When enabled, imitate_item_holder uses AddInnateCollectible/RemoveInnateCollectible instead of hidden wisps. Disable this if a compatibility issue appears.",
		items_allow = "Allow mod items to naturally appear",
		trinkets_allow = "Allow mod trinkets to naturally appear",
		pickup_allow = "Allow mod pickups to naturally appear",
		boss_allow = "Allow mod bosses to appear",
		achievement_allow = "Allow achievements to be unlocked",
		achievement_pool_gating = "Apply achievement unlocks to item pools",
		achievement_pool_gating_help = "When enabled, collectibles assigned on the achievement board cannot be naturally selected until their condition is completed. Takes effect on the next new run.",
		achievement_trinket_gating = "Apply achievement unlocks to trinkets",
		achievement_trinket_gating_help = "When enabled, locked trinkets assigned on the achievement board are removed from the trinket pool on the next new run.",
		achievement_card_gating = "Apply achievement unlocks to cards",
		achievement_card_gating_help = "When enabled, locked cards are made unavailable through REPENTOGON without rerolling or changing card weights.",
		achievement_pickup_gating = "Apply achievement unlocks to pickups",
		achievement_pickup_gating_help = "When enabled, locked glazed pickups assigned on the achievement board will not be generated.",
		existing_setting = "Existing ModConfigMenu setting.",
		trigger_laser_start = "Enable LaserStart trigger",
		trigger_laser_start_help = "First endpoint of normal laser-style attacks. When LaserEnd is also enabled, each newly generated laser chooses one endpoint and keeps it.",
		trigger_laser_end = "Enable LaserEnd trigger",
		trigger_laser_end_help = "Terminal endpoint of normal laser-style attacks. Direction follows the final laser segment.",
		trigger_brim_start = "Enable BrimStart trigger",
		trigger_brim_start_help = "First endpoint of brimstone-style attacks. The chosen endpoint is reused by that brimstone entity.",
		trigger_brim_end = "Enable BrimEnd trigger",
		trigger_brim_end_help = "Terminal endpoint of brimstone-style attacks. Direction follows the final laser segment, or reverses when MaxDistance is 0.",
		auto_live = "Automatically open broadcast",
		auto_live_help = "Runs Live Broadcast mode without requiring the collectible.",
		live_soft_limit = "Comment soft limit",
		live_soft_limit_help = "Above this count, new comments are increasingly filtered.",
		live_hard_limit = "Comment hard limit",
		live_hard_limit_help = "Maximum simultaneous scrolling comments.",
		live_speed = "Comment speed",
		live_speed_help = "Horizontal movement speed in pixels per frame.",
		live_scale = "Comment scale",
		live_scale_help = "Display scale for scrolling comments.",
		live_opacity = "Comment opacity",
		live_opacity_help = "Global opacity multiplier for scrolling comments.",
		live_interval = "Message interval multiplier",
		live_interval_help = "Higher values make regular comments appear less frequently.",
		reset_defaults = "Reset options to defaults",
		reset_notice = "Qing Remaster options reset.",
		theseus_always_show = "Always show current clauses",
		theseus_always_show_help = "Debug display for Theseus's Sign. Shows the current clauses above the player even when no rewrite is happening.",
		theseus_source_y = "Source item icon Y",
		theseus_colon_y = "Colon Y",
		theseus_amount_y = "Amount number Y",
		theseus_trigger_y = "Condition icon Y",
		theseus_arrow_y = "Arrow Y",
		theseus_action_y = "Result icon Y",
		theseus_source_scale = "Source item icon scale",
		theseus_colon_scale = "Colon scale",
		theseus_amount_scale = "Amount number scale",
		theseus_trigger_scale = "Condition icon scale",
		theseus_arrow_scale = "Arrow scale",
		theseus_action_scale = "Result icon scale",
		super_bombs_bomb_seconds = "Bomb to Giga Bomb limit",
		super_bombs_bomb_seconds_help = "Seconds without using a consumable bomb before one existing bomb grows into a Giga Bomb.",
		super_bombs_mama_seconds = "Giga Bomb to Mama Mega limit",
		super_bombs_mama_seconds_help = "Seconds with an empty primary active slot before one Giga Bomb grows into Mama Mega.",
		super_bombs_timer_x = "Timer right edge X",
		super_bombs_timer_x_help = "Horizontal offset of the timer's right edge from the Glaze Bomb HUD anchor.",
		super_bombs_timer_y = "Timer Y",
		super_bombs_timer_y_help = "Vertical offset of the timer from the Glaze Bomb HUD anchor.",
		charon_spawn_interval = "Generation interval",
		charon_spawn_interval_help = "Frames between generation attempts on each flooded grid. The original frequency is 15.",
		charon_particle_lifetime = "Particle lifetime",
		charon_particle_lifetime_help = "Lifetime of each rendered black-tide particle in frames.",
		charon_fade_frames = "Fade-out duration",
		charon_fade_frames_help = "Frames reserved for the end-of-life fade-out.",
		charon_foreground_rate = "Foreground proportion",
		charon_foreground_rate_help = "Proportion rendered among room entities; the rest stays behind them.",
		charon_rows_per_anchor = "Rows per render anchor",
		charon_rows_per_anchor_help = "Higher values use fewer effect anchors, but foreground Y sorting becomes less precise.",
		charon_room_prefill = "Room-entry prefill",
		charon_room_prefill_help = "Procedurally reconstructs this share of a full particle lifetime when entering a room. It does not store particles in save data.",
		charon_room_fade = "Room-entry fade-in",
		charon_room_fade_help = "Frames used to fade the reconstructed tide in after the room preview transitions into gameplay. Set to 0 for immediate display.",
		charon_seija_enabled = "Enable Seija enhancement",
		charon_seija_enabled_help = "When enabled, treats the holder as Seija for testing. When disabled, the enhancement still applies normally to actual Seija conditions.",
		charon_seija_speed = "Seija tide speed",
		charon_seija_speed_help = "Progress multiplier while Seija compatibility is active.",
		charon_pickup_radius = "Pickup safe radius",
		charon_pickup_radius_help = "Radius in pixels kept clear around pickups during Seija compatibility.",
		group_bloody_map = "Bloody Map",
		group_perhaps_chosen = "Perhaps Chosen",
		perhaps_chosen_help = "Pending queue size, Force Seija, and force-attach for testing. Restore defaults resets Seija force and clears pending.",
		perhaps_chosen_status = "Status",
		perhaps_chosen_pending = "Pending count",
		perhaps_chosen_pending_help = "Stacked waiting slots. Change the number, then Force attach (or enter a choice room) to spawn that many carriers.",
		perhaps_chosen_force_attach = "Force attach now",
		perhaps_chosen_force_attach_help = "Remove active carriers in this room and spawn carriers from the current pending queue into the eligible choice group. Enable Force Seija first to test bonus cycles.",
		perhaps_chosen_clear_pending = "Clear pending",
		perhaps_chosen_attach_no_host = "No eligible collectible choice in this room.",
		perhaps_chosen_attach_empty = "Pending queue is empty.",
		perhaps_chosen_seija = "Force Seija enhancement",
		perhaps_chosen_seija_help = "When enabled, treats the run as Seija for testing: pending carriers spawn with a bonus pool cycle. When disabled, only real Seija buff conditions apply.",
		group_glaze_crown = "Crown of the Glaze",
		glaze_crown_help = "Seija override for Crown of the Glaze. Restore defaults only resets this item's debug toggles.",
		glaze_crown_seija = "Force Seija enhancement",
		glaze_crown_seija_help = "When enabled, treats holders as Seija for testing. When disabled, only real Seija conditions apply.",
		group_abiogenesis = "Abiogenesis",
		abiogenesis_help = "Force awakening, override combat resources, and tweak overall attack pacing.",
		abiogenesis_force_awaken = "Force start awakening",
		abiogenesis_force_awaken_help = "Gives Abiogenesis if missing, then starts the awakening VFX immediately (skips all-zero resource gate).",
		abiogenesis_advance = "Advance +1 phase",
		abiogenesis_advance_help = "Jump current awakening to the next phase boundary.",
		abiogenesis_force_finish = "Force finish → familiar",
		abiogenesis_force_finish_help = "Instantly convert, hand off, and leave a proved baby familiar.",
		abiogenesis_resource_debug = "Resource test",
		abiogenesis_resource_override = "Override combat resources",
		abiogenesis_coin = "Coin",
		abiogenesis_key = "Key",
		abiogenesis_bomb = "Bomb",
		abiogenesis_charge = "Charge",
		abiogenesis_preset_1 = "1 Resource",
		abiogenesis_preset_2 = "2 Resources",
		abiogenesis_preset_3 = "3 Resources",
		abiogenesis_preset_4 = "4 Resources",
		abiogenesis_combat_tuning = "Combat test",
		abiogenesis_interval_scale = "Attack interval scale",
		abiogenesis_bomb_speed = "Bomb speed",
		abiogenesis_bomb_fuse = "Bomb fuse",
		group_tianyi = "World's End Tianyi",
		tianyi_help = "Test the clear-room traveler. Force Clear Proc skips only the chance roll, then uses the same delay, doors, path, reward, and performance.",
		tianyi_force = "Force performance",
		tianyi_force_clear = "Force clear proc",
		tianyi_clear = "Clear traveler",
		tianyi_reroll = "Reroll route",
		tianyi_print_doors = "Print room doors",
		tianyi_debug_reward = "Spawn reward during debug",
		tianyi_walk_speed = "Walk speed",
		tianyi_anim_speed = "Walk animation speed",
		tianyi_show_path = "Show Tianyi path",
		tianyi_player_hair = "Apply Tianyi hair to players",
		tianyi_reason_path_failed = "No walkable path in this room",
		tianyi_spawned = "Traveler performance started",
		tianyi_pending = "Clear proc is waiting to appear",
		tianyi_cleared = "Traveler cleared",
		tianyi_reason_forbidden_room = "This room type cannot play the performance",
		tianyi_reason_no_open_door = "No valid open door",
		tianyi_reason_no_player = "No living player",
		tianyi_reason_busy = "A traveler is already here",
		tianyi_reason_pending = "A clear proc is already waiting",
		tianyi_reason_no_copies = "No World's End Tianyi is held",
		tianyi_reason_failed = "Clear proc did not start",
		group_ingestion_night = "Ingestion to Night",
		ingestion_night_help = "Screen noise + fang overlay debug (no shaders). Preview counters force visual depth.",
		ingestion_mouth_radius = "Mouth radius",
		ingestion_noise_strength = "Noise strength",
		ingestion_fang_reveal = "Fang reveal mul",
		ingestion_fang_sharp = "Fang sharpness mul",
		ingestion_fang_length = "Fang length mul",
		ingestion_bite_shrink = "Bite radius shrink",
		ingestion_force_counter = "Force counter",
		ingestion_clear_force = "Clear force counter",
		ingestion_trigger_bite = "Trigger bite",
		group_book_of_thoth = "Book of Thoth",
		book_of_thoth_help = "Seija nerf override, HUD card placement, Divine-page cup hitbox, and thoth-card use semantics (attempt/commit). Restore defaults only resets this item.",
		book_of_thoth_use_semantics_empty = "Thoth use semantics: no event yet",
		book_of_thoth_seija = "Force Seija nerf",
		book_of_thoth_seija_help = "When enabled, treats holders as Seija for testing: world Thoth cards stay face-down, and the codex shows only upright/reversed backs until the first reading. When disabled, only real Seija conditions apply.",
		book_of_thoth_divine_split = "Divine split",
		book_of_thoth_divine_split_help = "How much of the Divine page is the upper band (formation slots). 0.40 is the default; the rest is the card pool.",
		book_of_thoth_dot_x = "Outline dot X",
		book_of_thoth_dot_y = "Outline dot Y",
		book_of_thoth_dot_help = "Offset for the '.' used to draw Thoth outlines. Positive X/Y move right/down.",
		book_of_thoth_bg_x = "Book background X",
		book_of_thoth_bg_y = "Book background Y",
		book_of_thoth_bg_help = "Offset for ThothBook.anm2 from screen center. Positive X/Y move right/down.",
		book_of_thoth_tab_catalog_x = "Codex tab text X",
		book_of_thoth_tab_catalog_y = "Codex tab text Y",
		book_of_thoth_tab_divine_x = "Reading tab text X",
		book_of_thoth_tab_divine_y = "Reading tab text Y",
		book_of_thoth_tab_text_help = "Offset for that tab's label from the p1/p2 layer box. Each tab is independent. Positive X/Y move right/down.",
		book_of_thoth_slot_card_scale = "Slot card scale",
		book_of_thoth_slot_card_help = "Scale of cards on the three flame slots. 1.0 is native 16x20.",
		book_of_thoth_slot_card_x = "Slot card X",
		book_of_thoth_slot_card_y = "Slot card Y",
		book_of_thoth_slot_card_pos_help = "Moves the three reading-slot cards together. Positive X/Y move right/down. Flames stay put.",
		book_of_thoth_hud_card_scale = "HUD card size",
		book_of_thoth_hud_card_help = "Size of formation cards on the active item. 0.5 = half the 32px slot (card Scale 1).",
		book_of_thoth_hud_card_x = "HUD card X",
		book_of_thoth_hud_card_y = "HUD card Y",
		book_of_thoth_hud_card_pos_help = "Moves the active-slot card row. Positive X/Y move right/down.",
		book_of_thoth_cup_hit_x = "Cup hit X",
		book_of_thoth_cup_hit_y = "Cup hit Y",
		book_of_thoth_cup_hit_w = "Cup hit width",
		book_of_thoth_cup_hit_h = "Cup hit height",
		book_of_thoth_cup_hit_pos_help = "Moves the Divine-page cup click box from the Cup layer center. Positive X/Y move right/down. Dots on the page show the current box.",
		book_of_thoth_cup_hit_size_help = "Size of the cup click box in pixels. The Cup layer itself is a 448x96 banner; shrink this to the bowl.",
		book_of_thoth_pool_y = "Pool list Y",
		book_of_thoth_pool_y_help = "Moves only the lower card list. Positive down, negative up. Does not move the reading slots.",
		book_of_thoth_page_label_x = "Page number X",
		book_of_thoth_page_label_y = "Page number Y",
		book_of_thoth_page_label_help = "Moves the page number (1 / N) at the bottom. Positive X/Y move right/down.",
		book_of_thoth_unlock_all = "Unlock all faces",
		book_of_thoth_unlock_all_help = "Registers every Thoth face for all players this run. Does not spend Revelation or start a reading.",
		group_gospel = "Gospel",
		gospel_help = "Seija override for Gospel. Restore defaults only resets this item's debug toggles.",
		gospel_seija = "Force Seija enhancement",
		gospel_seija_help = "When enabled, treats holders as Seija for testing (Gospel cannot spread; Preaching and Revelation become weaker dark lights). When disabled, only real Seija conditions apply.",
		group_dark_mysticism = "Dark Mysticism",
		dark_mysticism_help = "Seija override for Dark Mysticism. Restore defaults only resets this item's debug toggles.",
		dark_mysticism_seija = "Force Seija enhancement",
		dark_mysticism_seija_help = "When enabled, treats holders as Seija for testing (successful negate also applies player pseudo-fear ~3s, cannot attack). When disabled, only real Seija conditions apply.",
		dark_mysticism_apply_fear = "Apply pseudo-fear now",
		dark_mysticism_apply_fear_help = "Immediately applies player pseudo-fear (~3s) on player 0 for visual/attack-block testing. Does not require taking damage.",
		group_multiknife = "Multiknife",
		multiknife_help = "HUD body scale for charges 7–12 (charge 6 stays 3.2). Later ranks no longer double; default 10-charge cap is 28, Belial 12-charge cap is 56. Lift offsets only move the self-drawn held sword.",
		multiknife_hud7 = "HUD scale 7",
		multiknife_hud8 = "HUD scale 8",
		multiknife_hud9 = "HUD scale 9",
		multiknife_hud10 = "HUD scale 10",
		multiknife_hud11 = "HUD scale 11",
		multiknife_hud12 = "HUD scale 12",
		multiknife_lift_x = "Lift offset X",
		multiknife_lift_y = "Lift offset Y",
		multiknife_lift_help = "Screen offset from the empty held-item point. Positive X/Y move right/down.",
		group_suture_needle = "Suture Needle",
		suture_needle_help = "Seija override for Suture Needle. Restore defaults only resets this item's debug toggles.",
		suture_needle_seija = "Force Seija enhancement",
		suture_needle_seija_help = "When enabled, treats holders as Seija for testing (sutured corpses last longer but break much faster when hit). When disabled, only real Seija conditions apply.",
		group_book_of_voice = "Book of Voice",
		book_of_voice_help = "Possession testing and Seija defiance override.",
		book_of_voice_seija = "Force Seija defiance",
		book_of_voice_seija_help = "When enabled, treating the holder as Seija makes refusing whispers still raise possession and grant a small reverse reward.",
		book_of_voice_possession = "Possession",
		book_of_voice_possession_help = "Run value. 9+ unlocks destroying the book.",
		group_regenesis = "Regenesis",
		group_zero_presence = "Zero Presence",
		zero_presence_help = "Force the next eligible collectible gain to trigger Zero Presence escape (skips the chance roll).",
		zero_presence_force_escape = "Force next escape",
		zero_presence_force_escape_notice = "Zero Presence: next gain will force escape if a valid empty pedestal context exists.",
		regenesis_help = "Records losses while held. Each eligible combat-room clear advances one distinct record per familiar. Cards, pills, and items take longer than ordinary losses. Without the familiar, up to 12 recent losses persist for the current floor.",
		regenesis_status = "Audit",
		regenesis_runtime_status = "Runtime Status",
		regenesis_queue_inspector = "Queue Inspector",
		regenesis_simulation = "Simulation / Recovery",
		regenesis_familiar_vfx = "Familiar & Capture VFX",
		regenesis_simulate_room_clear = "Simulate combat-room clear",
		regenesis_add_progress = "Advance active jobs (+1)",
		regenesis_try_restore = "Try restore with current progress",
		regenesis_force_next_restore = "Force next restore",
		regenesis_inject_header = "Inject loss",
		regenesis_inject_coin = "Inject 1 Coin",
		regenesis_inject_bomb = "Inject 1 Bomb",
		regenesis_inject_key = "Inject 1 Key",
		regenesis_inject_charge = "Inject Charge",
		regenesis_inject_soul = "Inject 1 Soul Heart",
		regenesis_inject_card = "Inject Card (Fool)",
		regenesis_inject_q0 = "Inject Q0 Item",
		regenesis_inject_q4 = "Inject Q4 Item",
		regenesis_clear_stored = "Clear stored",
		regenesis_clear_dormant = "Clear dormant",
		regenesis_reset_state = "Reset Regenesis state",
		regenesis_refresh_familiar = "Re-evaluate Familiar Cache",
		regenesis_dump_familiar = "Dump Familiar Info",
		regenesis_test_coin_vfx = "Test Coin Capture VFX",
		regenesis_test_item_vfx = "Test Collectible Capture VFX",
		regenesis_clear_vfx = "Clear Capture VFX",
		regenesis_resource_amount = "Resource amount",
		regenesis_charge_visual = "Charge / Effort Visual",
		regenesis_effort_enabled = "Effort enabled",
		regenesis_effort_resource = "Effort interval — resource",
		regenesis_effort_far = "Effort interval — early progress",
		regenesis_effort_near = "Effort interval — near ready",
		regenesis_squash_x = "Squash X",
		regenesis_squash_y = "Squash Y",
		regenesis_stretch_x = "Stretch X",
		regenesis_stretch_y = "Stretch Y",
		regenesis_red_offset = "Red offset strength",
		regenesis_effort_duration = "Effort duration",
		regenesis_capture_timing = "Capture VFX timing",
		regenesis_rise_frames = "Rise frames",
		regenesis_travel_frames = "Travel frames",
		regenesis_hover_frames = "Hover frames",
		regenesis_drop_frames = "Drop frames",
		regenesis_hover_height = "Hover height",
		regenesis_score_prosperity = "Prosperity",
		regenesis_score_war = "War",
		regenesis_score_abundance = "Abundance",
		regenesis_score_technology = "Technology",
		regenesis_score_faith = "Faith",
		regenesis_score_ruin = "Ruin",
		regenesis_active = "Active Age (this run)",
		regenesis_pending = "Pending legacy (next run)",
		regenesis_force_settle = "Force settle from current scores",
		regenesis_apply_active = "Re-apply this run's Age effects",
		regenesis_announce = "Play tendency hint",
		regenesis_clear_legacy = "Clear pending legacy",
		regenesis_settled = "Forced settle: ",
		regenesis_applied = "Applied Age: ",
		regenesis_cleared = "Pending legacy cleared.",
		regenesis_none = "(none)",
		bloody_map_help = "Messenger spawn chance, reward weights, extra Ultra Secret grants, and Seija portal testing.",
		bloody_map_seija = "Force Seija enhancement",
		bloody_map_seija_help = "When enabled, treats holders as Seija for testing. When disabled, only real Seija buff conditions apply.",
		bloody_map_spawn_chance = "Messenger base spawn chance",
		bloody_map_spawn_chance_help = "Per copy of Bloody Map. Total chance = min(1, base × copies).",
		bloody_messenger_pay_nothing = "Immediate nothing chance (soul)",
		bloody_messenger_pay_nothing_help = "Soul-heart characters only: chance to play PayNothing after paying.",
		bloody_messenger_double = "Double reward chance",
		bloody_messenger_double_help = "Normal (boosted) pays only: chance to roll a second different reward.",
		bloody_messenger_weight_nothing = "Soul weight: nothing",
		bloody_messenger_weight_ultra = "Soul weight: Ultra Secret",
		bloody_messenger_weight_key = "Soul weight: Cracked Key",
		bloody_messenger_weight_item = "Soul weight: Ultra Secret item",
		bloody_messenger_boost_ultra = "Boosted weight: Ultra Secret",
		bloody_messenger_boost_key = "Boosted weight: Cracked Key",
		bloody_messenger_boost_item = "Boosted weight: Ultra Secret item",
		bloody_map_ultra_amount = "Ultra Secrets per grant",
		bloody_map_ultra_amount_help = "How many next-floor Ultra Secrets one Messenger grant queues.",
		bloody_map_ultra_max = "Ultra Secret grant cap",
		bloody_map_ultra_max_help = "Maximum successful Messenger Ultra Secret grants per run.",
		group_golden_slot = "Golden Slot",
		group_diamond = "Diamond",
		diamond_help = "Merchant chance and trade HUD layout for Qing's Faceted Market Diamond. Permanent shop price is on the Permanent data page.",
		diamond_shop_price = "Current shop price",
		diamond_shop_price_help = "Permanent Diamond shop price (0-99). Cross-run; applied to shop pedestals immediately.",
		diamond_merchant_chance = "Merchant spawn chance",
		diamond_merchant_chance_help = "Chance to roll a Diamond Merchant when entering a shop while holding Diamond. Already-rolled rooms keep their result; chance 1 always forces spawn.",
		diamond_hud_help = "Trade HUD above the player: diamond icon -> digits + coin. Tune offsets/scales here.",
		diamond_hud_base_x = "HUD base offset X",
		diamond_hud_base_y = "HUD base offset Y",
		diamond_hud_icon_x = "Icon offset X",
		diamond_hud_icon_y = "Icon offset Y",
		diamond_hud_icon_scale = "Icon scale",
		diamond_hud_arrow_x = "Arrow offset X",
		diamond_hud_arrow_y = "Arrow offset Y",
		diamond_hud_arrow_scale = "Arrow scale",
		diamond_hud_tens_x = "Tens digit offset X",
		diamond_hud_ones_x = "Ones digit offset X",
		diamond_hud_digit_y = "Digit offset Y",
		diamond_hud_digit_scale = "Digit scale",
		diamond_hud_cent_x = "Coin offset X",
		diamond_hud_cent_y = "Coin offset Y",
		diamond_hud_cent_scale = "Coin scale",
		golden_slot_help = "Two-stage Golden Slot odds: win chance, failure table, and reward table.",
		golden_slot_loss_streak = "Current loss streak",
		golden_slot_loss_streak_help = "Consecutive non-wins this run. Resets on a golden reward.",
		golden_slot_next_chance = "Next win chance (%)",
		golden_slot_base_chance = "Base win chance (%)",
		golden_slot_chance_per_loss = "Win chance bonus per loss (%)",
		golden_slot_max_chance = "Max win chance (%)",
		golden_slot_w_fly = "Reward weight: midas fly",
		golden_slot_w_troll = "Reward weight: golden troll bomb",
		golden_slot_w_coin = "Reward weight: golden coin",
		golden_slot_w_bomb = "Reward weight: golden bomb",
		golden_slot_w_heart = "Reward weight: golden heart",
		golden_slot_w_key = "Reward weight: golden key",
		golden_slot_w_battery = "Reward weight: golden battery",
		golden_slot_w_pill = "Reward weight: golden pill",
		golden_slot_w_mega_pill = "Reward weight: giant golden pill",
		golden_slot_w_trinket = "Reward weight: golden trinket",
		golden_slot_w_ending = "Reward weight: super prize",
		golden_slot_w_mega_chest = "Super prize weight: mega chest",
		golden_slot_w_trophy = "Super prize weight: trophy",
		golden_slot_coin_x = "Coin icon offset X",
		golden_slot_coin_x_help = "Offset from the right edge of the cost text.",
		golden_slot_coin_y = "Coin icon offset Y",
		golden_slot_coin_y_help = "Offset from the active slot UI position.",
		golden_slot_coin_scale = "Coin icon scale",
		group_reserved_judgment = "Reserved Judgment",
		reserved_judgment_help = "Reserve-marker layout and priced-offer test helpers.",
		reserved_judgment_mark_range = "Mark range",
		reserved_judgment_mark_range_help = "Max distance to reserve a priced collectible with Drop.",
		reserved_judgment_icon_x = "Marker offset X",
		reserved_judgment_icon_y = "Marker offset Y (world, down +)",
		reserved_judgment_icon_scale = "Marker scale",
		reserved_judgment_spawn_choices = "Spawn 15¢ test item",
		reserved_judgment_give_item = "Give Reserved Judgment",
		reserved_judgment_clear_trial = "Clear reserved offer / marks",
		restore_item_defaults = "Restore this item's defaults",
		run_only = "These buttons only work during a run.",
		reevaluate_imitate = "Re-evaluate fake items",
		print_imitate = "Print fake item records",
		reevaluated_notice = "Fake items re-evaluated.",
		start_run_first = "Start a run first.",
		printed_notice = "Fake item records printed to log.",
		console_desc = "Open Qing Remaster RGON options.",
	},
	zh = {
		menu = "\u{f12e} 小青 重制版",
		settings_item = "\u{f013} 设置",
		settings_title = "小青 重制版 - 设置",
		debug_item = "\u{f492} 调试",
		debug_title = "小青 重制版 - 调试",
		probes_item = "\u{f0c3} 探针",
		probes_title = "小青 重制版 - 探针",
		achievements_item = "\u{f091} 成就",
		achievements_title = "小青 重制版 - 成就",
		live_item = "\u{f03d} 直播姬",
		live_title = "小青 重制版 - 直播姬",
		tab_debug_tools = "调试工具",
		debug_page_recent = "常用",
		debug_page_items = "道具",
		debug_page_cards = "卡牌",
		debug_page_characters = "角色",
		debug_page_systems = "系统",
		debug_page_visual = "视觉",
		debug_page_data = "数据",
		debug_page_tests = "测试",
		probe_page_items = "道具",
		probe_page_characters = "角色",
		probe_page_systems = "系统",
		probe_page_visual = "视觉",
		probe_page_runtime = "运行时",
		debug_page_flight = "蓝图与飞行器",
		debug_recent_help = "首页镜像已固定模块的核心参数，以及最近编辑过的控件（同一配置路径，不做跳转）。",
		debug_recent_empty = "暂无最近编辑的控件。",
		debug_recent_clear = "清空最近记录",
		debug_pinned_help = "首页固定",
		debug_pinned_empty = "暂无置顶。可在支持首页镜像的模块底部点「固定到首页」。",
		debug_back_recent = "返回最近",
		debug_goto_page = "查看所在分类",
		debug_nav_help = "已定位目标。请点击对应调试 Tab 打开（当前 RGON 无法脚本选中 Tab）。",
		debug_nav_click_tab = "请点击「%s」Tab。",
		debug_pin_module = "固定到首页",
		debug_unpin_module = "从首页移除",
		debug_recent_pages = "最近使用的分类",
		debug_recent_modules = "最近编辑",
		debug_restricted_locked = "受限编辑：未解锁",
		debug_restricted_unlock = "解锁受限数据编辑（开发者）",
		debug_restricted_status = "受限编辑状态：%s",
		debug_restricted_unlocked = "已解锁",
		debug_restricted_locked_word = "未解锁",
		group_blueprint_eid_audit = "蓝图 EID 审计导出",
		blueprint_eid_audit_help = "导出全部可组装蓝图 EID 行，供长度审计（中/英 JSON 位于 codex_work/logs）。",
		blueprint_eid_audit_export = "导出蓝图EID审计",
		tab_permanent_data = "永久数据",
		tab_item_colors = "道具颜色",
		tab_cards = "卡牌",
		card_rates_help = "托特卡逐卡出现率（0=总是映回原版，1=总是保留）。写入 ModConfigSettings，非 PermanentData。",
		card_rates_restore = "恢复全部卡牌出现率为默认",
		card_rate_suffix = " 出现率",
		achievement_characters = "角色解锁",
		achievement_bosses = "Boss",
		achievement_other = "其他",
		achievement_settings = "设置",
		achievement_manual_animation = "勾选成就时播放解锁动画",
		achievement_manual_animation_help = "仅控制成就窗口中的手动解锁；正常游玩获得成就仍会播放纸片。",
		achievement_legacy_tracker = "旧版房间扫描完成检测",
		achievement_legacy_tracker_help = "默认关闭。重新启用逐帧扫描终局房间的旧逻辑，仅用于和 RGON 完成回调对照。",
		completion_marks_character = "选人页纸片探针",
		completion_marks_character_help = "选人页默认不画暂停纸片。只有要对齐位置时才打开，XY 是相对 RGON RenderPos 的偏移，调好后把数值发回来。",
		completion_marks_character_draw = "在选人页绘制纸片",
		completion_marks_character_x = "选人页纸片偏移 X",
		completion_marks_character_y = "选人页纸片偏移 Y",
		completion_marks_character_xy = "当前 XY：%.2f, %.2f（相对 RGON RenderPos）",
		completion_marks_character_restore = "恢复选人页纸片探针默认值",
		completion_marks_audit = "审计并同步完成标记",
		completion_marks_audit_result = "审计完成：%d 个角色，共校正 %d 个不一致标记。",
		achievement_reward = "解锁：%s",
		achievement_no_reward = "暂未设置解锁内容",
		achievement_unlock = "解锁",
		achievement_normal = "普通",
		achievement_hard = "困难",
		achievement_normal_victory = "原角色击败",
		achievement_tainted_victory = "堕化角色击败",
		achievement_unlock_all = "全部解锁",
		achievement_lock_all = "全部锁定",
		achievement_saved = "成就数据已保存。",
		tab_compatibility = "兼容",
		tab_gameplay = "玩法",
		tab_hud = "HUD",
		group_hud_imitate = "模拟道具",
		group_character_menu_lang = "选人页语言",
		character_menu_lang_help = "运行时替换青的选人页文字贴图。默认跟随游戏语言，可强制中文或英文。",
		character_menu_lang_auto = "跟随游戏语言",
		character_menu_lang_zh = "强制中文",
		character_menu_lang_en = "强制英文",
		character_menu_lang_status = "当前贴图：%s（游戏语言：%s）",
		group_controls_lang = "开局操作说明语言",
		controls_lang_help = "运行时替换开局房间的操作说明。默认跟随游戏语言，可强制中文或英文。",
		controls_lang_status = "当前操作说明：%s（游戏语言：%s）",
		group_game_over_lang = "死亡界面名字语言",
		game_over_lang_help = "运行时替换死亡界面的角色名。默认跟随游戏语言，可强制中文或英文。",
		game_over_lang_status = "当前死亡名字：%s（游戏语言：%s）",
		group_title_logo = "标题页 Logo",
		title_logo_help = "在标题页叠绘模组 Logo。取消勾选则恢复原版以撒标题 Logo。",
		title_logo_custom = "使用模组标题 Logo",
		title_logo_custom_help = "关闭后不再叠绘模组 Logo，并重新显示原版标题 Logo。",
		title_logo_rainbow = "彩虹 Logo 叠层（测试）",
		title_logo_rainbow_help = "在正常 Logo 上用 qing_rainbow_roll 分两段绘制（上 80 大标题 + 下 80 小字）。临时测试开关。",
		title_logo_rainbow_solo = "只渲染叠层（诊断）",
		title_logo_rainbow_solo_help = "不画主 Logo，只画彩虹双段。看到暗红原色=有渲染但 shader 未生效；看到连续流动彩虹=shader 正常；完全没有=叠层没画上。",
		title_logo_rainbow_status = "叠层状态：%s",
		title_logo_rainbow_lum_low = "彩虹 Roll 灰度下限（大标题）",
		title_logo_rainbow_lum_high = "彩虹 Roll 灰度上限（大标题）",
		title_logo_rainbow_lum_help = "上半 80px 大标题。实测约 0.07–0.29。提高 Low 加深边框；降低 High 让内部更早进高光。",
		title_logo_rainbow_text_lum_low = "彩虹 Roll 灰度下限（小字）",
		title_logo_rainbow_text_lum_high = "彩虹 Roll 灰度上限（小字）",
		title_logo_rainbow_text_lum_help = "下半 80px 小字。像素几乎全是 ~0.076，须用更窄更亮的窗口（默认 0.05–0.10），否则会接近全黑。",
		title_logo_rainbow_spatial_angle = "彩虹 Roll 空间角度（度）",
		title_logo_rainbow_spatial_density = "彩虹 Roll 空间密度",
		title_logo_rainbow_spatial_help = "色带铺开方向（0/45/90…）与图上铺多少圈彩虹。量化为 16×16 打包进 Colorize.r。",
		title_logo_rainbow_speed = "彩虹 Roll 转速",
		title_logo_rainbow_direction = "彩虹 Roll 时间方向",
		title_logo_rainbow_motion_help = "时间旋转速度（0=静止）与正负（+1 / -1）。seed 在 Lua 混入 phase，不再传 shader。",
		title_logo_rainbow_gray_hue = "彩虹 Roll 灰度→色相权重",
		title_logo_rainbow_bend = "彩虹 Roll 空间弯曲",
		title_logo_rainbow_shape_contrast = "彩虹 Roll 结构对比",
		title_logo_rainbow_style_help = "ColorOffset：灰度影响色相的程度、色带弯曲、remap 后边框/内部对比。默认对应旧固定常量。",
		title_logo_lang_help = "启用模组 Logo 时选择贴图语言。默认跟随游戏语言；中文贴图尚未实装，会回退英文。",
		title_logo_lang_status = "当前 Logo：%s（游戏语言：%s）",
		title_logo_offset_x = "Logo 叠绘偏移 X",
		title_logo_offset_y = "Logo 叠绘偏移 Y",
		title_logo_offset_help = "相对 WorldToMenuPosition(0,0) 的菜单空间偏移。在标题页拖动调好后把数值报给我。",
		title_logo_offset_restore = "恢复 Logo 偏移默认值",
		group_rgon = "忏悔龙",
		group_runtime = "运行时",
		group_hud = "HUD",
		show_temp_item_hud = "在 Extra HUD 显示临时道具",
		show_temp_item_hud_help = "在原版 Extra HUD 列表后半透明绘制青的临时道具。跟随 Options.ExtraHUDStyle。",
		temp_hud_large_pad_x = "大面板微调 X",
		temp_hud_large_pad_y = "大面板微调 Y",
		temp_hud_mini_pad_x = "小面板微调 X",
		temp_hud_mini_pad_y = "小面板微调 Y",
		temp_hud_large_step = "大面板格距",
		temp_hud_mini_step = "小面板格距",
		temp_hud_restore = "恢复 Extra HUD 布局默认值",
		temp_hud_layout_help = "有原版格时原点取 HistoryHUD offsets，否则 (0,0)。Pad 默认：大 16/38，小 8/19。",
		group_attack_callbacks = "攻击回调触发点",
		group_live_general = "直播模式",
		group_live_comments = "滚动弹幕",
		group_maintenance = "维护",
		group_debug = "调试",
		group_title_marquee = "标题滚动字标",
		group_dynamic_lighting = "动态光照（Phase 1）",
		dynamic_lighting_help = "全屏黑暗 overlay + 玩家圆形光。默认偏高对比。不做房间裁剪（HUD 可能被压暗）。改 shader 后请 reloadshaders。",
		dynamic_lighting_enabled = "启用动态光照",
		dynamic_lighting_ambient = "环境底光",
		dynamic_lighting_ambient_help = "光圈外亮度（0=全黑）。越低对比越强。",
		dynamic_lighting_radius = "玩家光半径（世界单位）",
		dynamic_lighting_intensity = "光照强度",
		dynamic_lighting_soft = "边缘柔和度",
		dynamic_lighting_color_r = "光色 R",
		dynamic_lighting_color_g = "光色 G",
		dynamic_lighting_color_b = "光色 B",
		group_torsion = "Torsion 切开测试",
		torsion_help = "第一次改版：有限线段 + 岔开错位。角度 <0 随机。",
		torsion_trigger = "触发一道 Torsion",
		torsion_peak = "错位幅度（UV）",
		torsion_stretch = "切缝拉伸（UV）",
		torsion_slide_ang = "错位岔开角（度）",
		torsion_seg_half = "切开半长（像素）",
		torsion_total = "总时长（帧）",
		torsion_hold = "峰值保持（帧）",
		torsion_angle = "切开角度（度，-1=随机）",
		torsion_gap = "缝半宽",
		torsion_soft = "衰减宽度",
		torsion_band = "垂直半宽（像素）",
		group_anna_torsion = "Anna 剑斩 Torsion",
		anna_torsion_help = "普通斩：起飞->落地线段；band 限制切开线两侧作用范围。",
		anna_torsion_peak = "错位幅度（UV）",
		anna_torsion_stretch_ratio = "拉伸/错位比",
		anna_torsion_slide_ang = "岔开角（度）",
		anna_torsion_gap = "缝半宽",
		anna_torsion_soft = "衰减宽度",
		anna_torsion_band = "垂直半宽（像素）",
		anna_torsion_total = "总时长（帧）",
		anna_torsion_hold = "峰值保持（帧）",
		anna_torsion_frame = "触发帧（落地后）",
		title_marquee_start_x = "右侧出现点 X",
		title_marquee_end_x = "左侧消失点 X",
		title_marquee_y = "基线 Y",
		title_marquee_speed = "滚动速度",
		title_marquee_fade = "左侧淡出宽度",
		title_marquee_spacing = "字母间距",
		title_marquee_rainbow_speed = "彩虹滚动速度",
		title_marquee_wave_speed = "背景波峰速度",
		title_marquee_edge_intensity = "背景波峰强度",
		title_marquee_edge_wave_width = "背景染色范围",
		title_marquee_edge_peak_sharpness = "背景波峰锐度",
		title_marquee_bounce_speed = "抖动速度",
		title_marquee_bounce_travel_speed = "抖动波传播速度",
		title_marquee_bounce_height = "弹起高度",
		title_marquee_squash_x = "落地横向挤压",
		title_marquee_squash_y = "落地纵向挤压",
		title_marquee_impact_sharpness = "落地波峰锐度",
		title_marquee_tangent_rotation = "切线旋转强度",
		title_marquee_help = "坐标使用标题菜单的 480×270 设计空间；字母从起点进入，并在接近终点时逐渐透明。",
		group_theseus_notice = "忒修斯之印提示",
		group_super_bombs = "超级炸弹",
		group_seeker_wall_probe = "求索者之眼墙壁探针",
		seeker_wall_probe_help = "记录求索贴墙检测（八向 blocked、法线 inward、法线外挪后的切线 vs 原位切线）。写出 codex_work/logs/seeker_wall_probe.jsonl。默认关闭。",
		seeker_wall_probe_enable = "启用求索者之眼墙壁探针",
		seeker_wall_probe_export = "刷新墙壁探针状态",
		seeker_wall_probe_clear = "清空墙壁探针日志",
		seeker_wall_probe_status = "探针关闭",
		group_blue_print = "蓝图面板",
		group_craft_familiar = "制造宝宝（Air Flight）",
		craft_familiar_status = "（无绑定制造宝宝）",
		craft_familiar_freeze_cd = "冻结制造开火冷却",
		craft_familiar_freeze_cd_help = "仅调试。勾选后停止 craft_fire_cooldown 递减。",
		craft_familiar_force_fire = "立即开火一次",
		craft_familiar_force_fire_help = "仅调试。下一帧 Familiar update 可无视冷却开火，触发后自动关闭。",
		craft_familiar_restore = "恢复制造宝宝调试默认",
		air_debug_move_spd = "Air Flight 移速覆盖",
		air_debug_move_spd_help = "仅调试。>0 时覆盖制造档案移速驱动飞行器本体；0=用档案。",
		air_debug_force_luck = "强制飞行器幸运=99",
		air_debug_force_luck_help = "仅调试；可单独开关。开=强制99（覆盖控制台 debug 9）。关=若已开 debug 9 则用高幸运，否则用档案（0幸运：妈眼约50%，洛基约25%）。影响妈眼/洛基/科技9制造侧判定。",
		air_debug_hit_status = "命中/弹道状态（点刷新）",
		air_debug_hit_refresh = "刷新命中/弹道状态",
		group_aura_balance = "光环平衡（圣体光）",
		aura_balance_help = "圣体光默认半径/贴图约为首版一半。拖条随时改；恢复=写回制造默认。",
		aura_bal_mon_radius = "圣体光伤害半径",
		aura_bal_mon_scale = "圣体光贴图 Scale",
		aura_bal_mon_interval = "圣体光伤害间隔(帧)",
		aura_bal_restore = "恢复圣体光默认",
		group_flight_crash = "Flight 坠毁特效",
		flight_crash_fail_frames = "失控预备帧数",
		flight_crash_gravity = "下落重力",
		flight_crash_max_fall = "最大下落速度",
		flight_crash_drift = "前冲保留系数",
		flight_crash_slip = "侧滑上限",
		flight_crash_fall_smoke = "下坠冒烟间隔",
		flight_crash_tumble_fric = "翻滚摩擦",
		flight_crash_tumble_max = "翻滚最长帧",
		flight_crash_impact_dust = "接地尘粒数",
		flight_crash_dead_min = "残骸冒烟最短间隔",
		flight_crash_dead_max = "残骸冒烟最长间隔",
		flight_crash_shake = "震屏强度",
		flight_crash_cap = "每架粒子上限",
		flight_crash_force = "强制坠毁",
		flight_crash_force_revive = "强制坠毁+复活",
		flight_crash_clear = "修复/清理特效",
		flight_crash_restore = "恢复坠毁默认参数",
		group_temp_revive = "临时复活账本",
		temp_revive_help = "记录 innate 复活已消耗次数（一命菇/死猫等）。复活后用举起贴图确认来源。默认关闭日志。",
		temp_revive_log = "记录举起贴图 / 扣账判定",
		temp_revive_clear = "清除 P0 已消耗",
		temp_revive_status = "已消耗 / 授予 / 事件",
		blueprint_dot_x = "框线点 X 偏移",
		blueprint_dot_y = "框线点 Y 偏移",
		blueprint_dot_help = "绘制命中框所用 '.' 的偏移；正 X/Y 向右/向下。",
		blueprint_bg_x = "背景 X 偏移",
		blueprint_bg_y = "背景 Y 偏移",
		blueprint_bg_help = "仅调整蓝图背景精灵渲染位置。",
		blueprint_audit_y = "效果描述 Y 偏移",
		blueprint_audit_y_help = "相对上方最低材料/成本槽底边的额外下移间距。",
		blueprint_slot_count = "材料槽数量（已停用）",
		blueprint_slot_count_help = "材料槽数现由底座道具品质决定，此滑条不再生效。",
		blueprint_cost_y = "成本小槽 Y 偏移",
		blueprint_cost_y_help = "成本小槽相对目标道具图标中心的下移；正值向下。",
		blueprint_cost_extra = "成本小槽追加数量",
		blueprint_cost_extra_help = "在所需成本之外额外画出的空小槽数，便于测排版。",
		blueprint_craft_group_y = "制造组 Y 偏移",
		blueprint_craft_group_y_help = "目标道具图标 + 材料槽（及成本小槽）整组下移；正值向下。",
		blueprint_tag_col_x = "审计标签列 X",
		blueprint_tag_col_y = "审计标签列 Y",
		blueprint_tag_col_help = "锚点为背包面板右缘；负 X 往背包内侧靠。",
		blueprint_tag_col_w = "审计标签列宽度",
		blueprint_tag_col_w_help = "标签筛选列宽度（像素）。",
		blueprint_show_source_marks = "显示来源角标（原/审）",
		blueprint_show_source_marks_help = "显示材料来源角标与描边（原型/审计）。默认关闭。",
		blueprint_all_items_mode = "启用蓝图全道具审计模式",
		blueprint_all_items_mode_help = "开启后，蓝图制造页可切换到全道具目录，用于兼容性审计与测试。公开版本默认关闭。",
		blueprint_tutorial_status = "教学：未开始",
		blueprint_tutorial_start = "开始蓝图教学",
		blueprint_tutorial_start_skip = "开始教学（跳过询问）",
		blueprint_tutorial_abort = "结束教学并清理练习机",
		blueprint_tutorial_reset = "重置「首次打开」教学标记",
		blueprint_tutorial_help = "里小青本存档首次打开蓝图会询问是否教学。此处可随时重进；结束必清练习机。",
		blueprint_cost_scale = "成本图标缩放",
		blueprint_cost_scale_help = "成本小槽内问号/道具贴图缩放（默认 0.5）。",
		blueprint_cost_slot_size = "成本小槽尺寸(px)",
		blueprint_cost_slot_size_help = "小槽边长；中心距=尺寸+2。过多自动换行。默认 18。",
		blueprint_cost_qmark_x = "成本问号 X 偏移",
		blueprint_cost_qmark_y = "成本问号 Y 偏移",
		blueprint_cost_qmark_help = "成本小槽问号贴图的像素偏移。",
		group_charon_tide = "卡戎之印·黑潮",
		group_ritual_sting = "血仪刺刃·六色进度",
		ritual_sting_help = "调节局内首个持有者的六色进度（0–上限）。达到阈值解锁对应效果；蓝色解锁射速与圣水痕迹（跟 POST_ATTACK_DPS_SAMPLE）。不写入存档。",
		ritual_sting_red = "红色", ritual_sting_orange = "橙色", ritual_sting_yellow = "黄色",
		ritual_sting_green = "绿色", ritual_sting_blue = "蓝色", ritual_sting_purple = "紫色",
		ritual_sting_give = "给予血仪刺刃",
		ritual_sting_give_help = "若玩家 0 没有该道具则给予。",
		ritual_sting_give_ok = "血仪刺刃已就绪。",
		ritual_sting_enable_blue = "解锁蓝色（水迹）",
		ritual_sting_enable_blue_help = "把蓝色拉到解锁阈值，方便测试射击时的 DPS_SAMPLE 水迹。",
		ritual_sting_enable_blue_ok = "蓝色已解锁（水迹）。",
		ritual_sting_fill_all = "解锁全部颜色",
		ritual_sting_reset = "重置血仪刺刃进度",
		group_death_sentence = "通灵盘·字母",
		death_sentence_help = "直接调节当前局内首个持有者的死亡字母与现有字母；不会保存为模组设置。",
		death_sentence_death_word = "死亡字母",
		death_sentence_letters = "现有字母",
		group_remaster = "Remaster!",
		remaster_help = "楼层代码翻页动画与 Tptron 面板布局。间距放大整体变慢；路径正中的字母始终相对更快。",
		remaster_flip_spacing = "代码翻页字母间距",
		remaster_flip_spacing_help = "间距越大，字母表级联（如 B->D 经 C）越慢；中间字母仍会相对加速。",
		remaster_panel_offset_x = "面板偏移 X",
		remaster_panel_offset_y = "面板偏移 Y",
		remaster_panel_offset_help = "Tptron 面板屏幕像素偏移（Y 正方向向下）。加在默认居中/升起位置之上。",
		remaster_channels_help = "永久传送渠道（PROFILE.PermanentData）。跨局保留，回传成功后才会消费移除。",
		remaster_channel_list = "通道列表",
		remaster_channel_empty = "（暂无永久通道）",
		remaster_channel_select = "选中通道",
		remaster_channel_from = "出发 stage 命令",
		remaster_channel_to = "目标 stage 命令",
		remaster_channel_from_help = "例如 1、5c、10a。局内可点「填入当前楼层」。",
		remaster_channel_to_help = "目标楼层 stage 命令，格式同控制台 stage。",
		remaster_channel_fill_from = "From = 当前楼层",
		remaster_channel_add = "添加/覆盖永久通道",
		remaster_channel_remove = "删除选中通道",
		remaster_channel_clear_all = "清空全部永久通道",
		remaster_channel_added = "已写入永久 Remaster 通道。",
		remaster_channel_removed = "已删除选中 Remaster 通道。",
		remaster_channel_cleared = "已清空全部 Remaster 通道。",
		remaster_channel_bad_cmd = "stage 命令无效。",
		group_imitate_items = "模拟道具",
		permanent_data_help = "档案级 PermanentData。「下局生效」类数据也放这里。非永久调试项仍在调试工具页。",
		group_spectral_rewrites = "道具铭刻改写（旧）",
		group_colorblind_bans = "色盲·下局点踩移除",
		colorblind_bans_help = "色盲点踩后将在下局道具池移除的道具列表；开局生效后清空。",
		colorblind_bans_empty = "（暂无下局移除）",
		colorblind_bans_clear = "清空下局点踩移除",
		colorblind_bans_cleared = "已清空色盲下局点踩列表。",
		group_diamond_permanent = "钻石·永久售价",
		diamond_permanent_help = "跨局保留的钻石商店售价与上次成交价。",
		diamond_last_sale = "上次成交价",
		diamond_permanent_restore = "恢复钻石永久售价默认",
		group_book_of_future_permanent = "未来之书·逃逸进度",
		book_of_future_progress_help = "未来之书逃逸后跨局保留的累计品质；下次获得并使用时，会从此数值继续补到 50。",
		book_of_future_progress = "已累计品质",
		book_of_future_progress_restore = "清空未来之书进度",
		spectral_clear_all = "清空全部铭刻改写",
		spectral_cleared_notice = "已清空全部道具铭刻改写。",
		group_item_colors = "模组道具颜色分析",
		item_colors_help = "忏悔龙会分批扫描模组道具图标。手工标签始终作为覆盖项，自动标签用于扩展琉璃的骰子碎片兼容。",
		item_colors_restart = "重新扫描道具颜色",
		item_colors_print = "输出详细报告",
		item_colors_restarted = "已重新开始模组道具颜色扫描。",
		item_colors_printed = "道具颜色报告已输出到日志。",
		spectral_editor_help = "旧铭刻系统编辑器（名称 / 拾取副标题）。新版妖刀·逢魔已不再写入；数据由 systems/item_inscription 持有。",
		spectral_entry = "已修改道具",
		spectral_name = "名称",
		spectral_description = "描述",
		spectral_no_entries = "暂无已保存的修改",
		spectral_save = "保存当前修改",
		spectral_reload = "放弃草稿并重新载入",
		spectral_delete = "删除当前修改",
		spectral_undo_delete = "撤销上次删除",
		spectral_saved_notice = "已保存道具铭刻修改。",
		spectral_deleted_notice = "已删除道具铭刻修改。",
		spectral_restored_notice = "已恢复刚刚删除的道具修改。",
		spectral_no_selection = "请先选择一项已保存的修改。",
		spectral_nothing_to_undo = "当前没有可恢复的删除记录。",
		use_rgon_imitate = "使用 RGON 内置道具后端处理模拟道具",
		use_rgon_imitate_help = "开启后 imitate_item_holder 会使用 AddInnateCollectible/RemoveInnateCollectible，而不是隐藏魂火。遇到兼容问题时可以关闭。",
		items_allow = "允许模组道具自然出现",
		trinkets_allow = "允许模组饰品自然出现",
		pickup_allow = "允许模组掉落物自然出现",
		boss_allow = "允许模组 Boss 出现",
		achievement_allow = "允许解锁成就",
		achievement_pool_gating = "让成就解锁状态实际影响道具池",
		achievement_pool_gating_help = "开启后，解锁板上的道具在完成对应条件前不会被自然抽取。下一局新游戏生效。",
		achievement_trinket_gating = "按成就解锁状态调控饰品",
		achievement_trinket_gating_help = "开启后，解锁板中尚未解锁的饰品会在下一局从饰品池移除。",
		achievement_card_gating = "按成就解锁状态调控卡牌",
		achievement_card_gating_help = "开启后，尚未解锁的卡牌会通过忏悔龙可用性条件禁用，不重抽，也不会改变卡牌权重。",
		achievement_pickup_gating = "按成就解锁状态调控琉璃化掉落物",
		achievement_pickup_gating_help = "开启后，解锁板中尚未解锁的琉璃化掉落物不会生成。",
		existing_setting = "既有 ModConfigMenu 设置。",
		trigger_laser_start = "启用 LaserStart 触发",
		trigger_laser_start_help = "普通激光类攻击的首端触发。若 LaserEnd 也启用，每个新生成的激光会二选一并持续复用。",
		trigger_laser_end = "启用 LaserEnd 触发",
		trigger_laser_end_help = "普通激光类攻击的末端触发。方向取激光最后一节切向。",
		trigger_brim_start = "启用 BrimStart 触发",
		trigger_brim_start_help = "硫磺火类攻击的首端触发。生成时选定后，该实体后续持续复用。",
		trigger_brim_end = "启用 BrimEnd 触发",
		trigger_brim_end_help = "硫磺火类攻击的末端触发。方向取最后一节切向；MaxDistance 为 0 时改为反向。",
		auto_live = "自动开启直播",
		auto_live_help = "无需持有直播姬，也会持续运行直播模式。",
		live_soft_limit = "弹幕软上限",
		live_soft_limit_help = "超过此数量后，新弹幕会逐渐被过滤。",
		live_hard_limit = "弹幕硬上限",
		live_hard_limit_help = "屏幕上同时存在的滚动弹幕最大数量。",
		live_speed = "弹幕速度",
		live_speed_help = "滚动弹幕每帧水平移动的像素数。",
		live_scale = "弹幕缩放",
		live_scale_help = "滚动弹幕的显示缩放。",
		live_opacity = "弹幕透明度",
		live_opacity_help = "滚动弹幕的全局透明度倍率。",
		live_interval = "消息间隔倍率",
		live_interval_help = "数值越高，常规弹幕出现得越慢。",
		reset_defaults = "重置为默认设置",
		reset_notice = "小青 重制版设置已重置。",
		theseus_always_show = "始终显示当前条款",
		theseus_always_show_help = "忒修斯之印的调试显示。即使没有发生改写，也会在玩家头顶显示当前条款。",
		theseus_source_y = "源道具图标 Y",
		theseus_colon_y = "冒号 Y",
		theseus_amount_y = "数字 Y",
		theseus_trigger_y = "条件图标 Y",
		theseus_arrow_y = "箭头 Y",
		theseus_action_y = "结果图标 Y",
		theseus_source_scale = "源道具图标缩放",
		theseus_colon_scale = "冒号缩放",
		theseus_amount_scale = "数字缩放",
		theseus_trigger_scale = "条件图标缩放",
		theseus_arrow_scale = "箭头缩放",
		theseus_action_scale = "结果图标缩放",
		super_bombs_bomb_seconds = "炸弹->超大炸弹计数上限",
		super_bombs_bomb_seconds_help = "未使用消耗型炸弹达到该秒数后，将一枚现有炸弹成长为超大炸弹。",
		super_bombs_mama_seconds = "超大炸弹->Mama Mega计数上限",
		super_bombs_mama_seconds_help = "主主动槽为空时达到该秒数后，将一枚超大炸弹成长为 Mama Mega。",
		super_bombs_timer_x = "计时文本右边缘 X",
		super_bombs_timer_x_help = "计时文本右边缘相对琉璃炸弹 HUD 锚点的水平偏移。",
		super_bombs_timer_y = "计时文本 Y",
		super_bombs_timer_y_help = "计时文本相对琉璃炸弹 HUD 锚点的垂直偏移。",
		charon_spawn_interval = "生成间隔",
		charon_spawn_interval_help = "每个已淹没网格尝试生成黑潮的帧间隔；原始频率为 15。",
		charon_particle_lifetime = "粒子寿命",
		charon_particle_lifetime_help = "每个黑潮渲染粒子的存在帧数。",
		charon_fade_frames = "淡出时长",
		charon_fade_frames_help = "粒子寿命末尾用于淡出的帧数。",
		charon_foreground_rate = "前景比例",
		charon_foreground_rate_help = "在房间实体之间渲染的比例，其余黑潮位于实体后方。",
		charon_rows_per_anchor = "每锚点网格行数",
		charon_rows_per_anchor_help = "数值越高，效果锚点越少，但前景黑潮的 Y 轴排序会略粗糙。",
		charon_room_prefill = "进房预热比例",
		charon_room_prefill_help = "进入房间时程序化重建该比例的完整粒子寿命，不会把粒子或贴图数据写入存档。",
		charon_room_fade = "进房淡入帧数",
		charon_room_fade_help = "房间预览切换到正式游玩后，重建黑潮用于淡入的帧数；设为 0 时立即显示。",
		charon_seija_enabled = "启用 Seija 增幅",
		charon_seija_enabled_help = "开启时强制将持有者视为 Seija，方便测试；关闭时仍会按正常条件，仅对实际 Seija 生效。",
		charon_seija_speed = "Seija 黑潮速度",
		charon_seija_speed_help = "Seija 兼容生效时的黑潮推进倍率。",
		charon_pickup_radius = "掉落物安全半径",
		charon_pickup_radius_help = "Seija 兼容生效时，掉落物周围不生成黑潮的像素半径。",
		group_bloody_map = "红地图",
		group_perhaps_chosen = "似有所选",
		perhaps_chosen_help = "可调 Pending 队列数量、强制 Seija，以及本房立刻挂接。恢复默认会关掉强制 Seija 并清空 Pending。",
		perhaps_chosen_status = "状态",
		perhaps_chosen_pending = "Pending 数量",
		perhaps_chosen_pending_help = "叠加等待次数。改完数量后点「立刻挂接」，或进入有道具选择的房间，才会按数量生成 Carrier。",
		perhaps_chosen_force_attach = "立刻挂接",
		perhaps_chosen_force_attach_help = "移除本房已有 Carrier，再按当前 Pending 队列挂到可选项上。测 Seija 时先开强制增幅再挂接。",
		perhaps_chosen_clear_pending = "清空 Pending",
		perhaps_chosen_attach_no_host = "本房没有可挂接的道具选择。",
		perhaps_chosen_attach_empty = "Pending 队列为空。",
		perhaps_chosen_seija = "强制 Seija 增幅",
		perhaps_chosen_seija_help = "开启时无论玩家状态都视为满足 Seija：Pending Carrier 生成时自带一次当前道具池轮换候选。关闭时仅实际 Seija 增幅条件生效。",
		group_glaze_crown = "琉璃的冠冕",
		glaze_crown_help = "琉璃的冠冕的 Seija 强制开关。恢复默认只重置该道具的调试项。",
		glaze_crown_seija = "强制 Seija 增幅",
		glaze_crown_seija_help = "开启时无论玩家状态都视为满足 Seija；关闭时仅实际 Seija 条件生效。",
		group_abiogenesis = "无生源论",
		abiogenesis_help = "立刻开启觉醒、覆盖战斗资源，并整体调整攻击节奏。",
		abiogenesis_force_awaken = "立刻开始觉醒",
		abiogenesis_force_awaken_help = "若没有道具会先给予；跳过资源判定，直接开 HUD 觉醒演出。",
		abiogenesis_advance = "推进到下一阶段",
		abiogenesis_advance_help = "把当前觉醒跳到下一个阶段边界。",
		abiogenesis_force_finish = "立刻完成 → 宝宝",
		abiogenesis_force_finish_help = "立刻 convert + handoff，留下已证明的宝宝 Familiar。",
		abiogenesis_resource_debug = "资源测试",
		abiogenesis_resource_override = "覆盖战斗资源",
		abiogenesis_coin = "硬币",
		abiogenesis_key = "钥匙",
		abiogenesis_bomb = "炸弹",
		abiogenesis_charge = "充能",
		abiogenesis_preset_1 = "1 种资源",
		abiogenesis_preset_2 = "2 种资源",
		abiogenesis_preset_3 = "3 种资源",
		abiogenesis_preset_4 = "4 种资源",
		abiogenesis_combat_tuning = "战斗测试",
		abiogenesis_interval_scale = "攻击间隔倍率",
		abiogenesis_bomb_speed = "炸弹速度",
		abiogenesis_bomb_fuse = "炸弹引信",
		group_tianyi = "世末天依",
		tianyi_help = "测试清房后的旅人演出。强制清房触发只跳过概率，仍会等待、检查门，并走正常路线、奖励和演出。",
		tianyi_force = "强制播放演出",
		tianyi_force_clear = "强制清房触发",
		tianyi_clear = "清除当前旅人",
		tianyi_reroll = "重新随机路线",
		tianyi_print_doors = "打印房间门状态",
		tianyi_debug_reward = "调试演出生成奖励",
		tianyi_walk_speed = "移动速度",
		tianyi_anim_speed = "步行动画速度",
		tianyi_show_path = "显示世末天依路径",
		tianyi_player_hair = "将天依头发应用到玩家",
		tianyi_reason_path_failed = "房间内找不到可走路径",
		tianyi_spawned = "世末天依演出已触发",
		tianyi_pending = "清房触发已进入等待",
		tianyi_cleared = "已清除当前旅人",
		tianyi_reason_forbidden_room = "当前房型不适合这场演出",
		tianyi_reason_no_open_door = "当前没有可用的开放门",
		tianyi_reason_no_player = "未找到有效玩家",
		tianyi_reason_busy = "场上已经有天依",
		tianyi_reason_pending = "已经有一次清房触发在等待",
		tianyi_reason_no_copies = "当前没有持有世末天依",
		tianyi_reason_failed = "清房触发没有开始",
		group_ingestion_night = "夜之摄取",
		ingestion_night_help = "屏幕噪声幕 + 牙覆盖调试（无 Shader）。Preview 强制视觉深度。",
		ingestion_mouth_radius = "Mouth 半径",
		ingestion_noise_strength = "噪声强度",
		ingestion_fang_reveal = "牙显现倍率",
		ingestion_fang_sharp = "牙尖锐倍率",
		ingestion_fang_length = "牙长度倍率",
		ingestion_bite_shrink = "咬合半径收缩",
		ingestion_force_counter = "强制 counter",
		ingestion_clear_force = "清除强制 counter",
		ingestion_trigger_bite = "触发咬合",
		group_book_of_thoth = "透特之书",
		book_of_thoth_help = "透特之书调试：Seija 减幅强制开关、主动槽卡面、占卜页圣杯热区，以及透特牌使用语义（Attempt/Commit）。恢复默认只重置该道具。",
		book_of_thoth_use_semantics_empty = "透特牌使用语义：尚无记录",
		book_of_thoth_seija = "强制 Seija 减幅",
		book_of_thoth_seija_help = "开启时无论玩家状态都视为满足 Seija：世界透特牌背面、卡册先只显示正逆位背面，首次占卜后才翻开。关闭时仅实际 Seija 条件生效。",
		book_of_thoth_divine_split = "占卜分区",
		book_of_thoth_divine_split_help = "上半区（阵位槽）占内容区高度的比例。默认 0.40，剩下给牌池。",
		book_of_thoth_dot_x = "框线点 X",
		book_of_thoth_dot_y = "框线点 Y",
		book_of_thoth_dot_help = "绘制框线所用 '.' 的偏移；正 X/Y 向右/向下。",
		book_of_thoth_bg_x = "书页背景 X",
		book_of_thoth_bg_y = "书页背景 Y",
		book_of_thoth_bg_help = "ThothBook.anm2 相对屏幕中心的偏移。正 X/Y 向右/向下。",
		book_of_thoth_tab_catalog_x = "卡册标签文字 X",
		book_of_thoth_tab_catalog_y = "卡册标签文字 Y",
		book_of_thoth_tab_divine_x = "占卜标签文字 X",
		book_of_thoth_tab_divine_y = "占卜标签文字 Y",
		book_of_thoth_tab_text_help = "该标签文字相对 p1/p2 图层框的偏移，两个标签各自独立。正 X/Y 向右/向下。",
		book_of_thoth_slot_card_scale = "槽位卡面缩放",
		book_of_thoth_slot_card_help = "放在三处火焰槽上的卡面缩放。1.0 为 16×20 原尺寸。",
		book_of_thoth_slot_card_x = "槽位卡面 X",
		book_of_thoth_slot_card_y = "槽位卡面 Y",
		book_of_thoth_slot_card_pos_help = "三张占卜槽卡面整体偏移。正 X/Y 向右/向下。火焰位置不动。",
		book_of_thoth_hud_card_scale = "主动槽卡面大小",
		book_of_thoth_hud_card_help = "占卜开始后主动道具上的队列卡面。0.5 = 32px 槽宽的一半（卡面 Scale 1）。",
		book_of_thoth_hud_card_x = "主动槽卡面 X",
		book_of_thoth_hud_card_y = "主动槽卡面 Y",
		book_of_thoth_hud_card_pos_help = "主动槽上卡牌队列的整体偏移。正 X/Y 向右/向下。",
		book_of_thoth_cup_hit_x = "圣杯热区 X",
		book_of_thoth_cup_hit_y = "圣杯热区 Y",
		book_of_thoth_cup_hit_w = "圣杯热区宽",
		book_of_thoth_cup_hit_h = "圣杯热区高",
		book_of_thoth_cup_hit_pos_help = "相对 Cup 图层中心移动可点区域。正 X/Y 向右/向下。占卜页上的点框就是当前热区。",
		book_of_thoth_cup_hit_size_help = "圣杯可点区域像素大小。Cup 图层本身是 448×96 整条横幅，把热区收到杯身上。",
		book_of_thoth_pool_y = "卡池列表 Y",
		book_of_thoth_pool_y_help = "只移动下方卡牌列表。正值向下，负值上移。上方占卜槽不动。",
		book_of_thoth_page_label_x = "页码 X",
		book_of_thoth_page_label_y = "页码 Y",
		book_of_thoth_page_label_help = "底部页码（1 / N）的偏移。正 X/Y 向右/向下。",
		book_of_thoth_unlock_all = "开放所有卡面",
		book_of_thoth_unlock_all_help = "为本局所有玩家登记全部透特牌面。不消耗启示，也不开始占卜。",
		group_gospel = "福音",
		gospel_help = "福音的 Seija 强制开关。恢复默认只重置该道具的调试项。",
		gospel_seija = "强制 Seija 增幅",
		gospel_seija_help = "开启时无论玩家状态都视为满足 Seija（福音无法传播，宣讲与启示改为较弱的黑暗之光）；关闭时仅实际 Seija 条件生效。",
		group_multiknife = "倍增重刃",
		multiknife_help = "HUD 第 7–12 格刀身倍率（第 6 格仍是 3.2）。后面不再翻倍，默认 10 格满为 28，彼列 12 格满为 56。举剑偏移只影响自绘的持刀。",
		multiknife_hud7 = "HUD 倍率 7",
		multiknife_hud8 = "HUD 倍率 8",
		multiknife_hud9 = "HUD 倍率 9",
		multiknife_hud10 = "HUD 倍率 10",
		multiknife_hud11 = "HUD 倍率 11",
		multiknife_hud12 = "HUD 倍率 12",
		multiknife_lift_x = "举剑偏移 X",
		multiknife_lift_y = "举剑偏移 Y",
		multiknife_lift_help = "相对空举物锚点的屏幕偏移。正 X/Y 向右/向下。",
		group_suture_needle = "缝合针",
		suture_needle_help = "缝合针的 Seija 强制开关。恢复默认只重置该道具的调试项。",
		suture_needle_seija = "强制 Seija 增幅",
		suture_needle_seija_help = "开启时无论玩家状态都视为满足 Seija（缝尸更久，但受击拆线更快）；关闭时仅实际 Seija 条件生效。",
		group_book_of_voice = "假象之书",
		book_of_voice_help = "附体值测试，以及 Seija 违抗强制开关。",
		book_of_voice_seija = "强制 Seija 违抗",
		book_of_voice_seija_help = "开启时无论玩家状态都视为 Seija：拒绝低语仍会增加少量附体并给予反向奖励。",
		book_of_voice_possession = "附体值",
		book_of_voice_possession_help = "当前局数值。达到 9 后可毁灭此书。",
		group_regenesis = "再世纪",
		group_zero_presence = "零存在感",
		zero_presence_help = "强制下一次合法的道具获得触发零存在感逃逸（跳过概率判定）。",
		zero_presence_force_escape = "强制下次逃逸",
		zero_presence_force_escape_notice = "零存在感：下次获得道具时，若有合法空底座上下文则强制逃逸。",
		regenesis_help = "持有时记录失物。每个合法战斗房清理后，每个宝宝各推进一条不同的失物。卡牌、药丸和道具比普通失物更久。未持有时本层仍临时记住最近 12 条。",
		regenesis_status = "审计",
		regenesis_runtime_status = "运行状态",
		regenesis_queue_inspector = "队列检视",
		regenesis_simulation = "模拟 / 恢复",
		regenesis_familiar_vfx = "宝宝与记录特效",
		regenesis_simulate_room_clear = "模拟战斗房清理",
		regenesis_add_progress = "推进当前任务（+1）",
		regenesis_try_restore = "用当前进度尝试恢复",
		regenesis_force_next_restore = "强制恢复下一条",
		regenesis_inject_header = "注入损失",
		regenesis_inject_coin = "注入 1 硬币",
		regenesis_inject_bomb = "注入 1 炸弹",
		regenesis_inject_key = "注入 1 钥匙",
		regenesis_inject_charge = "注入充能",
		regenesis_inject_soul = "注入 1 魂心",
		regenesis_inject_card = "注入卡牌（愚者）",
		regenesis_inject_q0 = "注入 Q0 道具",
		regenesis_inject_q4 = "注入 Q4 道具",
		regenesis_clear_stored = "清空正式记录",
		regenesis_clear_dormant = "清空休眠记录",
		regenesis_reset_state = "重置再世纪状态",
		regenesis_refresh_familiar = "重新评估宝宝缓存",
		regenesis_dump_familiar = "输出宝宝信息",
		regenesis_test_coin_vfx = "测试硬币飞入特效",
		regenesis_test_item_vfx = "测试道具飞入特效",
		regenesis_clear_vfx = "清空飞入特效",
		regenesis_resource_amount = "资源数量",
		regenesis_charge_visual = "蓄力 / 使劲",
		regenesis_effort_enabled = "使劲动画",
		regenesis_effort_resource = "使劲间隔 — 一房资源",
		regenesis_effort_far = "使劲间隔 — 刚开始",
		regenesis_effort_near = "使劲间隔 — 快吐出",
		regenesis_squash_x = "压扁 X",
		regenesis_squash_y = "压扁 Y",
		regenesis_stretch_x = "拉长 X",
		regenesis_stretch_y = "拉长 Y",
		regenesis_red_offset = "红色 Offset 强度",
		regenesis_effort_duration = "使劲持续帧",
		regenesis_capture_timing = "记录飞行时长",
		regenesis_rise_frames = "升起帧数",
		regenesis_travel_frames = "飞行帧数",
		regenesis_hover_frames = "停留帧数",
		regenesis_drop_frames = "落下帧数",
		regenesis_hover_height = "头顶高度",
		regenesis_score_prosperity = "繁荣",
		regenesis_score_war = "战争",
		regenesis_score_abundance = "丰饶",
		regenesis_score_technology = "技术",
		regenesis_score_faith = "信仰",
		regenesis_score_ruin = "废墟",
		regenesis_active = "本局生效世纪",
		regenesis_pending = "待生效遗产（下一局）",
		regenesis_force_settle = "用当前分数强制结算",
		regenesis_apply_active = "重新应用本局世纪效果",
		regenesis_announce = "播放倾向提示",
		regenesis_clear_legacy = "清空待生效遗产",
		regenesis_settled = "已强制结算：",
		regenesis_applied = "已应用世纪：",
		regenesis_cleared = "已清空待生效遗产。",
		regenesis_none = "（无）",
		bloody_map_help = "血红使者出现概率、奖励权重、额外红隐藏次数，以及 Seija 漩涡测试。",
		bloody_map_seija = "强制 Seija 增幅",
		bloody_map_seija_help = "开启时无论玩家状态都视为满足 Seija；关闭时仅实际 Seija 增幅条件生效。",
		bloody_map_spawn_chance = "使者基础出现概率",
		bloody_map_spawn_chance_help = "每持有1份红地图的基础概率；总概率 = min(1, 基础 × 份数)。",
		bloody_messenger_pay_nothing = "直接一无所获概率（魂心）",
		bloody_messenger_pay_nothing_help = "仅魂心角色：付血后直接播放一无所获动画的概率。",
		bloody_messenger_double = "双收益概率",
		bloody_messenger_double_help = "仅普通红心支付（强档）：额外再roll一次不同奖励的概率。",
		bloody_messenger_weight_nothing = "魂心权重：一无所获",
		bloody_messenger_weight_ultra = "魂心权重：下层红隐藏",
		bloody_messenger_weight_key = "魂心权重：红钥匙碎片",
		bloody_messenger_weight_item = "魂心权重：红隐藏道具",
		bloody_messenger_boost_ultra = "强档权重：下层红隐藏",
		bloody_messenger_boost_key = "强档权重：红钥匙碎片",
		bloody_messenger_boost_item = "强档权重：红隐藏道具",
		bloody_map_ultra_amount = "每次给予的红隐藏数",
		bloody_map_ultra_amount_help = "血红使者一次“下层红隐藏”奖励排队生成的数量。",
		bloody_map_ultra_max = "红隐藏给予上限",
		bloody_map_ultra_max_help = "整局由使者成功给予的额外红隐藏次数上限。",
		group_golden_slot = "黄金抽奖机",
		group_diamond = "钻石",
		diamond_help = "钻石客商概率与议价 HUD（永久售价在「永久数据」页）。",
		diamond_shop_price = "当前售价",
		diamond_shop_price_help = "钻石永久商店售价（0-99），跨局保留，立即作用于商店底座。",
		diamond_merchant_chance = "收购商出现概率",
		diamond_merchant_chance_help = "持有钻石进入商店时掷骰出现收购商的概率。已掷过的房间结果不会重掷；概率=1时强制出现。",
		diamond_hud_help = "玩家头顶议价条：钻石贴图 -> 价格数字 + 硬币图标。用下列参数对齐。",
		diamond_hud_base_x = "HUD 基准偏移 X",
		diamond_hud_base_y = "HUD 基准偏移 Y",
		diamond_hud_icon_x = "钻石图标偏移 X",
		diamond_hud_icon_y = "钻石图标偏移 Y",
		diamond_hud_icon_scale = "钻石图标缩放",
		diamond_hud_arrow_x = "箭头偏移 X",
		diamond_hud_arrow_y = "箭头偏移 Y",
		diamond_hud_arrow_scale = "箭头缩放",
		diamond_hud_tens_x = "十位偏移 X",
		diamond_hud_ones_x = "个位偏移 X",
		diamond_hud_digit_y = "数字偏移 Y",
		diamond_hud_digit_scale = "数字缩放",
		diamond_hud_cent_x = "硬币偏移 X",
		diamond_hud_cent_y = "硬币偏移 Y",
		diamond_hud_cent_scale = "硬币缩放",
		golden_slot_help = "两段式抽奖：中奖率、失败表与成功奖励表。",
		golden_slot_loss_streak = "当前连败次数",
		golden_slot_loss_streak_help = "本局连续未中奖次数；中奖后清零。",
		golden_slot_next_chance = "下次中奖率 (%)",
		golden_slot_base_chance = "基础中奖率 (%)",
		golden_slot_chance_per_loss = "每次失败加成 (%)",
		golden_slot_max_chance = "中奖率上限 (%)",
		golden_slot_w_fly = "奖励权重：点金苍蝇",
		golden_slot_w_troll = "奖励权重：金Troll炸弹",
		golden_slot_w_coin = "奖励权重：金金币",
		golden_slot_w_bomb = "奖励权重：金炸弹",
		golden_slot_w_heart = "奖励权重：金心",
		golden_slot_w_key = "奖励权重：金钥匙",
		golden_slot_w_battery = "奖励权重：金电池",
		golden_slot_w_pill = "奖励权重：金药丸",
		golden_slot_w_mega_pill = "奖励权重：大金药丸",
		golden_slot_w_trinket = "奖励权重：金饰品",
		golden_slot_w_ending = "奖励权重：超大奖",
		golden_slot_w_mega_chest = "超大奖权重：超大金箱",
		golden_slot_w_trophy = "超大奖权重：金奖杯",
		golden_slot_coin_x = "硬币 icon 偏移 X",
		golden_slot_coin_x_help = "相对消耗数字右缘的水平偏移。",
		golden_slot_coin_y = "硬币 icon 偏移 Y",
		golden_slot_coin_y_help = "相对 Active 槽位 UI 位置的垂直偏移。",
		golden_slot_coin_scale = "硬币 icon Scale",
		group_reserved_judgment = "保留意见",
		reserved_judgment_help = "保留标识位置与有价测试工具。",
		reserved_judgment_mark_range = "保留判定距离",
		reserved_judgment_mark_range_help = "按 Drop 保留有价商品时的最大距离。",
		reserved_judgment_icon_x = "标识偏移 X",
		reserved_judgment_icon_y = "标识偏移 Y（世界坐标，下为正）",
		reserved_judgment_icon_scale = "标识 Scale",
		reserved_judgment_spawn_choices = "生成 15¢ 测试商品",
		reserved_judgment_give_item = "给予保留意见",
		reserved_judgment_clear_trial = "清除保留报价/标记",
		restore_item_defaults = "恢复该道具默认设置",
		run_only = "这些按钮只能在局内使用。",
		reevaluate_imitate = "重新评估模拟道具",
		print_imitate = "打印模拟道具记录",
		reevaluated_notice = "模拟道具已重新评估。",
		start_run_first = "请先开始一局游戏。",
		printed_notice = "模拟道具记录已输出到日志。",
		console_desc = "打开小青 重制版的 RGON 选项。",
	},
}

local function values_equal(a,b)
	if a == b then return true end
	if type(a) == "number" and type(b) == "number" then
		return math.abs(a - b) < 1e-4
	end
	return false
end

local function shallow_merge_defaults(target, defaults)
	if type(target) ~= "table" then target = {} end
	for key,value in pairs(defaults) do
		if type(value) == "table" then
			target[key] = shallow_merge_defaults(target[key], value)
		elseif target[key] == nil then
			target[key] = value
		end
	end
	return target
end

local function prune_matching_defaults(stored, defaults)
	if type(stored) ~= "table" or type(defaults) ~= "table" then return stored end
	for key,def in pairs(defaults) do
		local cur = stored[key]
		if cur == nil then
			-- skip
		elseif type(def) == "table" then
			if type(cur) == "table" then
				prune_matching_defaults(cur,def)
				if next(cur) == nil then stored[key] = nil end
			end
		elseif values_equal(cur,def) then
			stored[key] = nil
		end
	end
	return stored
end

local function build_defaults_tree()
	local defaults = {}
	if ModConfig.get_initlist then shallow_merge_defaults(defaults, ModConfig.get_initlist()) end
	shallow_merge_defaults(defaults, item.defaults)
	return defaults
end

-- get_value 热路径禁止每帧 rebuild；defaults / hydrate 只做一次（或 Save 后仍可读 sparse）
local defaults_tree_cache = nil
local settings_hydrated = false

local function get_defaults_tree()
	if defaults_tree_cache == nil then
		defaults_tree_cache = build_defaults_tree()
	end
	return defaults_tree_cache
end

local function get_by_path(tbl, path)
	local cur = tbl
	for i = 1,#path do
		if type(cur) ~= "table" then return nil end
		cur = cur[path[i]]
	end
	return cur
end

local function set_by_path(tbl, path, value)
	local cur = tbl
	for i = 1,#path - 1 do
		local key = path[i]
		if type(cur[key]) ~= "table" then cur[key] = {} end
		cur = cur[key]
	end
	cur[path[#path]] = value
end

local function clear_defaults_keys(root, defaults)
	if type(root) ~= "table" or type(defaults) ~= "table" then return end
	for key,def in pairs(defaults) do
		local cur = root[key]
		if type(def) == "table" and type(cur) == "table" then
			clear_defaults_keys(cur,def)
			if next(cur) == nil then root[key] = nil end
		else
			root[key] = nil
		end
	end
end

local function apply_debug_migrations(root)
	local debug_settings = root.QingRemasterOptions and root.QingRemasterOptions.Debug
	if not debug_settings then return end
	if debug_settings.SuperBombsTimerPositionVersion == nil then
		if debug_settings.SuperBombsTimerX == nil or debug_settings.SuperBombsTimerX == -11 then
			debug_settings.SuperBombsTimerX = -7
		end
		if debug_settings.SuperBombsTimerY == nil or debug_settings.SuperBombsTimerY == -5 then
			debug_settings.SuperBombsTimerY = -8.25
		end
		debug_settings.SuperBombsTimerPositionVersion = 1
	end
	if (tonumber(debug_settings.CharonSettingsVersion) or 0) < 3 then
		debug_settings.CharonAnimationSpeed = nil
		debug_settings.CharonSettingsVersion = 3
	end
	if (tonumber(debug_settings.CharonSettingsVersion) or 0) < 4 then
		if debug_settings.CharonPickupProtectRadius == nil or debug_settings.CharonPickupProtectRadius == 48 then
			debug_settings.CharonPickupProtectRadius = 120
		end
		debug_settings.CharonSettingsVersion = 4
	end
	if (tonumber(debug_settings.BlueprintSettingsVersion) or 0) < 1 then
		debug_settings.BlueprintBgOffsetY = 13
		debug_settings.BlueprintAuditTextY = 27
		if debug_settings.BlueprintCostOffsetY == nil then
			debug_settings.BlueprintCostOffsetY = 21
		end
		if debug_settings.BlueprintCostExtraCount == nil then
			debug_settings.BlueprintCostExtraCount = 0
		end
		debug_settings.BlueprintSettingsVersion = 1
	end
	if (tonumber(debug_settings.BlueprintSettingsVersion) or 0) < 2 then
		debug_settings.BlueprintCostOffsetY = 21
		debug_settings.BlueprintSettingsVersion = 2
	end
	if (tonumber(debug_settings.BlueprintSettingsVersion) or 0) < 3 then
		debug_settings.BlueprintAuditTextY = 2
		debug_settings.BlueprintCraftGroupY = 14
		debug_settings.BlueprintCostTokenScale = 0.5
		debug_settings.BlueprintSettingsVersion = 3
	end
	if (tonumber(debug_settings.BlueprintSettingsVersion) or 0) < 4 then
		debug_settings.BlueprintCostSlotSize = 18
		if debug_settings.BlueprintCostQmarkOffsetX == nil then
			debug_settings.BlueprintCostQmarkOffsetX = -2
		end
		if debug_settings.BlueprintCostQmarkOffsetY == nil then
			debug_settings.BlueprintCostQmarkOffsetY = 1
		end
		debug_settings.BlueprintSettingsVersion = 4
	end
	if (tonumber(debug_settings.BlueprintSettingsVersion) or 0) < 5 then
		debug_settings.BlueprintCostSlotSize = 18
		debug_settings.BlueprintCostQmarkOffsetX = -2
		debug_settings.BlueprintCostQmarkOffsetY = 1
		debug_settings.BlueprintSettingsVersion = 5
	end
	if (tonumber(debug_settings.BlueprintSettingsVersion) or 0) < 6 then
		if debug_settings.BlueprintTagColOffsetX == nil then
			debug_settings.BlueprintTagColOffsetX = -36
		end
		if debug_settings.BlueprintTagColOffsetY == nil then
			debug_settings.BlueprintTagColOffsetY = 0
		end
		if debug_settings.BlueprintTagColWidth == nil then
			debug_settings.BlueprintTagColWidth = 56
		end
		debug_settings.BlueprintSettingsVersion = 6
	end
	if (tonumber(debug_settings.BlueprintSettingsVersion) or 0) < 7 then
		-- 审计标签列默认 X：-48 → -36（仅仍为旧默认时迁移）
		if tonumber(debug_settings.BlueprintTagColOffsetX) == -48 then
			debug_settings.BlueprintTagColOffsetX = -36
		end
		debug_settings.BlueprintSettingsVersion = 7
	end
	if (tonumber(debug_settings.BlueprintSettingsVersion) or 0) < 8 then
		if debug_settings.BlueprintAllItemsModeEnabled == nil then
			debug_settings.BlueprintAllItemsModeEnabled = not dev_env.is_public_release()
		end
		debug_settings.BlueprintSettingsVersion = 8
	end
	-- 探针开关不得进存档；清掉误写入的 Debug.PareidoliaTechLaserProbe
	debug_settings.PareidoliaTechLaserProbe = nil
end

local function export_sparse_modconfig(merged)
	local sparse = auxi.deepCopy(merged or {})
	prune_matching_defaults(sparse, get_defaults_tree())
	return sparse
end

function item.get_settings()
	local root = save.ModConfigSettings or ModConfig.ModConfigSettings or {}
	apply_debug_migrations(root)
	local defaults = get_defaults_tree()
	prune_matching_defaults(root, defaults)
	shallow_merge_defaults(root, defaults)
	save.ModConfigSettings = root
	ModConfig.ModConfigSettings = root
	settings_hydrated = true
	return root
end

function item.get_value(path)
	-- 热路径：只读已有表；缺键回落 defaults。禁止每次 prune/merge（标题 Logo 每帧会读十余次）。
	if not settings_hydrated then
		item.get_settings()
	end
	local root = save.ModConfigSettings or ModConfig.ModConfigSettings
	local v = get_by_path(root, path)
	if v ~= nil then return v end
	return get_by_path(get_defaults_tree(), path)
end

function item.set_value(path, value)
	local root = item.get_settings()
	local default_value = get_by_path(get_defaults_tree(), path)
	local store = value
	if values_equal(value, default_value) then
		store = default_value
	end
	local current = get_by_path(root, path)
	-- 同值不写盘：ImGui Render/UpdateData 或重复 Edited 时避免每帧 SaveModData 卡顿
	if values_equal(current, store) then
		return
	end
	set_by_path(root, path, store)
	save.ModConfigSettings = root
	ModConfig.ModConfigSettings = root
	if save.SaveModData then
		local ok,err = pcall(save.SaveModData)
		if not ok then print("QING:: Failed to save RGON options: "..tostring(err)) end
	end
end

do
	local orig_save = save.SaveModData
	if type(orig_save) == "function" and not save._QingSparseModConfigWrapped then
		save._QingSparseModConfigWrapped = true
		function save.SaveModData(...)
			local merged = save.ModConfigSettings or ModConfig.ModConfigSettings or {}
			local sparse = export_sparse_modconfig(merged)
			save.ModConfigSettings = sparse
			ModConfig.ModConfigSettings = sparse
			local ok,err = pcall(orig_save,...)
			shallow_merge_defaults(sparse, get_defaults_tree())
			save.ModConfigSettings = sparse
			ModConfig.ModConfigSettings = sparse
			settings_hydrated = true
			if not ok then error(err) end
		end
	end
end

local function element_exists(id)
	if not ImGui or not ImGui.ElementExists then return false end
	local ok,exists = pcall(ImGui.ElementExists, id)
	return ok and exists
end

local function push_notice(text, tp)
	if ImGui and ImGui.PushNotification then
		ImGui.PushNotification(text, tp or 0, 2500)
	end
end

local function error_notice_type()
	if ImGuiNotificationType and ImGuiNotificationType.ERROR then return ImGuiNotificationType.ERROR end
	return 0
end

local function language_key()
	local language = string.lower(tostring((Options and Options.Language) or "en"))
	if language == "zh" or language == "zh_cn" or language == "chinese" or string.sub(language,1,2) == "zh" then return "zh" end
	return "en"
end

local function text(key)
	local lang = LANG[language_key()] or LANG.en
	return lang[key] or LANG.en[key] or key
end

local function add_text(parent_id, text)
	imgui_layout.add_wrapped_text(parent_id, "", text)
end

local function add_separator(parent_id, text)
	local separator = ImGuiElement.SeparatorText or ImGuiElement.Separator
	ImGui.AddElement(parent_id, "", separator, text or "")
end

local debug_touch_module = nil
local touch_debug_module
local debug_footer_opts = {}
local home_control_registry = {}

local function set_module_footer(module_id, footer)
	if not module_id or type(footer) ~= "table" then return end
	debug_footer_opts[module_id] = footer
end

local function register_home_controls(module_id, spec)
	if not module_id or type(spec) ~= "table" then return end
	home_control_registry[module_id] = spec
end

local function add_checkbox(parent_id, element_id, label, path, help)
	local owner = debug_touch_module
	ImGui.AddCheckbox(parent_id, element_id, label, nil, item.get_value(path) == true)
	ImGui.AddCallback(element_id, ImGuiCallback.Render, function()
		ImGui.UpdateData(element_id, ImGuiData.Value, item.get_value(path) == true)
	end)
	ImGui.AddCallback(element_id, ImGuiCallback.Edited, function(value)
		item.set_value(path, value == true)
		if owner then touch_debug_module(owner, "edit") end
	end)
	if help then imgui_layout.set_helpmarker(element_id, help) end
end

local function add_drag_float(parent_id, element_id, label, path, help, speed, min_value, max_value, formatting)
	local owner = debug_touch_module
	local function set_value(value)
		item.set_value(path, tonumber(value) or 0)
		if owner then touch_debug_module(owner, "edit") end
	end
	ImGui.AddDragFloat(parent_id, element_id, label, set_value, tonumber(item.get_value(path)) or 0, speed or 0.25, min_value or -16, max_value or 16, formatting or "%.2f")
	ImGui.AddCallback(element_id, ImGuiCallback.Render, function()
		ImGui.UpdateData(element_id, ImGuiData.Value, tonumber(item.get_value(path)) or 0)
	end)
	ImGui.AddCallback(element_id, ImGuiCallback.Edited, set_value)
	if help then imgui_layout.set_helpmarker(element_id, help) end
end

local function add_drag_pair_path(parent_id, left_id, left_label, left_path, right_id, right_label, right_path, opts)
	opts = opts or {}
	local owner = debug_touch_module
	imgui_layout.add_drag_pair(parent_id, {
		id = left_id,
		label = left_label,
		on_edit = function(value)
			item.set_value(left_path, tonumber(value) or 0)
			if owner then touch_debug_module(owner, "edit") end
		end,
		get = function() return tonumber(item.get_value(left_path)) or 0 end,
		default = tonumber(item.get_value(left_path)) or 0,
		speed = opts.speed or 0.25,
		min = opts.min or -16,
		max = opts.max or 16,
		fmt = opts.fmt or "%.2f",
		help = opts.left_help,
	}, {
		id = right_id,
		label = right_label,
		on_edit = function(value)
			item.set_value(right_path, tonumber(value) or 0)
			if owner then touch_debug_module(owner, "edit") end
		end,
		get = function() return tonumber(item.get_value(right_path)) or 0 end,
		default = tonumber(item.get_value(right_path)) or 0,
		speed = opts.speed or 0.25,
		min = opts.min or -16,
		max = opts.max or 16,
		fmt = opts.fmt or "%.2f",
		help = opts.right_help,
	}, opts)
end

local function add_group(parent_id, element_id, label)
	ImGui.AddElement(parent_id, element_id, ImGuiElement.CollapsingHeader, label)
	return element_id
end

local function setup_window(window_id, info)
	local screen_w = Options and tonumber(Options.WindowWidth) or nil
	local screen_h = Options and tonumber(Options.WindowHeight) or nil
	local width, height = info.w, info.h
	if screen_w and screen_h and screen_w > 0 and screen_h > 0 then
		-- RGON ImGui 使用窗口像素；只定初始尺寸，不强制位置。
		-- REPENTOGON 1.1.3：CreateWindow/setup 阶段调用 SetWindowPosition 会经 viewport
		-- 转换访问主窗口位置，易在模组初始化时 native crash；由 1.1.3 自行管理 docking/position。
		width = math.min(math.max(info.w, math.floor(screen_w * (info.screen_w or 0.8))), math.max(320, screen_w - 40))
		height = math.min(math.max(info.h, math.floor(screen_h * (info.screen_h or 0.82))), math.max(240, screen_h - 40))
	end
	if ImGui.SetSize then
		ImGui.SetSize(window_id, width, height)
	end
	if ImGui.SetVisible then
		ImGui.SetVisible(window_id, false)
	end
end


local function save_mod_data()
	if save.SaveModData then
		local ok,err = pcall(save.SaveModData)
		if not ok then print("QING:: Failed to save RGON options: "..tostring(err)) end
	end
end

local function add_reset_button(parent_id, label)
	ImGui.AddButton(parent_id, parent_id.."_ResetDefaults", label, function()
		local root = item.get_settings()
		local defaults = get_defaults_tree()
		clear_defaults_keys(root, defaults)
		shallow_merge_defaults(root, defaults)
		save.ModConfigSettings = root
		ModConfig.ModConfigSettings = root
		if save.SaveModData then
			local ok,err = pcall(save.SaveModData)
			if not ok then print("QING:: Failed to save RGON options: "..tostring(err)) end
		end
		push_notice(text("reset_notice"))
	end)
end

-- ---------------------------------------------------------------------------
-- Debug object pages:
-- Items / Cards / Characters / Systems / Visual / Data / Tests.
--
-- Runtime card-state controls belong to Cards.
-- Persistent gameplay/card-rate settings belong to Settings -> Cards.
-- Investigation probes belong to the separate Probes window.
-- See .cursor/rules/imgui-architecture.mdc
-- ---------------------------------------------------------------------------
local DEBUG_PAGE = {
	recent = "recent",
	items = "items",
	cards = "cards",
	characters = "characters",
	systems = "systems",
	visual = "visual",
	data = "data",
	tests = "tests",
}
local PROBE_PAGE = probe_registry.PROBE_PAGE
local DEBUG_RECENT_LIMIT = 6
local DEBUG_PINNED_HOME = 4
local DEBUG_PIN_LIMIT = 4

local debug_module_list = {}
local debug_module_by_id = {}
local debug_nav = {
	focus_module = nil,
	location_notice = "",
	tab_ids = {},
}
local debug_page_parent = {}

local function debug_settings_root()
	item.get_settings()
	local root = save.ModConfigSettings and save.ModConfigSettings.QingRemasterOptions
	if type(root) ~= "table" then return nil end
	if type(root.Debug) ~= "table" then root.Debug = {} end
	return root.Debug
end

local recent_runtime = {
	serial = 0,
	modules = {},
	pages = {},
	controls = {},
	last_touch = {},
	last_page_touch = {},
}

local function recent_next_serial()
	recent_runtime.serial = (tonumber(recent_runtime.serial) or 0) + 1
	return recent_runtime.serial
end

local function debug_pinned_store()
	local dbg = debug_settings_root()
	if type(dbg) ~= "table" then return {} end
	if type(dbg.PinnedModules) ~= "table" then
		dbg.PinnedModules = {}
	end
	return dbg.PinnedModules
end

local function is_module_pinned(module_id)
	local store = debug_pinned_store()
	return store[module_id] == true
end

local function toggle_module_pin(module_id)
	if not module_id or not debug_module_by_id[module_id] then return end
	local store = debug_pinned_store()
	if store[module_id] then
		store[module_id] = nil
	else
		local count = 0
		for _ in pairs(store) do count = count + 1 end
		if count >= DEBUG_PIN_LIMIT then
			push_notice("Pin limit reached (" .. tostring(DEBUG_PIN_LIMIT) .. ")")
			return
		end
		store[module_id] = true
	end
	if save.SaveModData then pcall(save.SaveModData) end
end

local function pinned_debug_modules()
	local store = debug_pinned_store()
	local out = {}
	for _, m in ipairs(debug_module_list) do
		if store[m.module_id] == true and m.pinnable ~= false then
			out[#out + 1] = m
		end
	end
	return out
end

touch_debug_module = function(module_id, kind)
	if not module_id or not debug_module_by_id[module_id] then return end
	local meta = debug_module_by_id[module_id]
	if meta.recent == false then return end
	local serial = recent_next_serial()
	local prev = recent_runtime.last_touch[module_id]
	-- Debounce identical kind spam within one serial step of the same module
	if prev and prev.kind == kind and prev.serial == serial - 1 and kind == "edit" then
		-- allow edits; only skip if somehow same serial
	end
	recent_runtime.last_touch[module_id] = {serial = serial, kind = kind}
	local row = recent_runtime.modules[module_id]
	if type(row) ~= "table" then row = {count = 0} end
	row.last_used = serial
	row.kind = kind or "open"
	if kind == "edit" then
		row.last_edit = serial
	elseif kind == "action" then
		row.last_action = serial
	else
		row.last_open = serial
	end
	row.count = (tonumber(row.count) or 0) + 1
	recent_runtime.modules[module_id] = row
end

local function clear_debug_access()
	recent_runtime.modules = {}
	recent_runtime.pages = {}
	recent_runtime.controls = {}
	recent_runtime.last_touch = {}
	recent_runtime.last_page_touch = {}
end

local function touch_debug_control(module_id, control_key, label)
	if not module_id or not control_key then return end
	local serial = recent_next_serial()
	local id = tostring(module_id) .. ":" .. tostring(control_key)
	recent_runtime.controls[id] = {
		last_used = serial,
		module_id = module_id,
		control_key = control_key,
		label = label or control_key,
	}
end

local function recent_debug_controls()
	local rows = {}
	for _, row in pairs(recent_runtime.controls) do
		if type(row) == "table" and (tonumber(row.last_used) or 0) > 0 then
			rows[#rows + 1] = row
		end
	end
	table.sort(rows, function(a, b)
		return (tonumber(a.last_used) or 0) > (tonumber(b.last_used) or 0)
	end)
	local out = {}
	for i = 1, math.min(DEBUG_RECENT_LIMIT, #rows) do
		out[i] = rows[i]
	end
	return out
end

local function touch_debug_page(page)
	if not page or page == DEBUG_PAGE.recent then return end
	local serial = recent_next_serial()
	recent_runtime.last_page_touch[page] = serial
	local row = recent_runtime.pages[page]
	if type(row) ~= "table" then row = {count = 0} end
	row.last_used = serial
	row.count = (tonumber(row.count) or 0) + 1
	recent_runtime.pages[page] = row
end

local function page_label(page)
	if page == DEBUG_PAGE.items then return text("debug_page_items") end
	if page == DEBUG_PAGE.cards then return text("debug_page_cards") end
	if page == DEBUG_PAGE.characters then return text("debug_page_characters") end
	if page == DEBUG_PAGE.systems then return text("debug_page_systems") end
	if page == DEBUG_PAGE.visual then return text("debug_page_visual") end
	if page == DEBUG_PAGE.data then return text("debug_page_data") end
	if page == DEBUG_PAGE.tests then return text("debug_page_tests") end
	return text("debug_page_recent")
end

local function module_path_label(m)
	if not m then return "" end
	local parts = {page_label(m.page)}
	if type(m.path) == "table" then
		for _, p in ipairs(m.path) do parts[#parts + 1] = tostring(p) end
	else
		parts[#parts + 1] = tostring(m.label or m.module_id)
	end
	return table.concat(parts, " / ")
end

local function register_debug_module(module_id, page, label, group_id, meta)
	if not module_id or not group_id then return nil end
	if debug_module_by_id[module_id] then return debug_module_by_id[module_id] end
	meta = meta or {}
	assert(meta.kind ~= "probe" and meta.kind ~= "diagnostic" and meta.kind ~= "audit" and meta.kind ~= "inspection",
		"probe/diagnostic modules must use start_probe_module: " .. tostring(module_id))
	local home = meta.home
	local home_enabled = type(home) == "table" and home.enabled == true
	assert(not home_enabled or meta.kind == "config" or meta.kind == "tool",
		"Home only accepts Debug config/tool modules: " .. tostring(module_id))
	-- Pin means mirror core controls on Home; only home-enabled modules are pinnable.
	local pinnable = false
	if home_enabled then
		pinnable = meta.pinnable ~= false
	end
	local entry = {
		module_id = module_id,
		page = page,
		label = label or module_id,
		group_id = group_id,
		path = meta.path,
		kind = meta.kind or "tool",
		home = home,
		pinnable = pinnable,
		recent = meta.recent ~= false,
		order = #debug_module_list + 1,
	}
	if home_enabled and type(meta.controls) == "table" then
		register_home_controls(module_id, {
			label = label or module_id,
			path = meta.path,
			controls = meta.controls,
			home_keys = home.controls,
			restore = meta.footer and meta.footer.restore,
			restore_label = meta.footer and meta.footer.restore_label,
			actions = home.actions,
			page = page,
		})
	end
	debug_module_list[#debug_module_list + 1] = entry
	debug_module_by_id[module_id] = entry
	if meta.footer then
		set_module_footer(module_id, meta.footer)
	end
	ImGui.AddCallback(group_id, ImGuiCallback.ToggledOpen, function(open)
		if open == true or open == 1 then
			touch_debug_module(module_id, "open")
		end
	end)
	return entry
end

local function recent_debug_modules()
	local rows = {}
	for module_id, a in pairs(recent_runtime.modules) do
		local m = debug_module_by_id[module_id]
		if m and m.recent ~= false and type(a) == "table" then
			rows[#rows + 1] = {
				module = m,
				last_used = tonumber(a.last_used) or 0,
				count = tonumber(a.count) or 0,
			}
		end
	end
	table.sort(rows, function(a, b)
		if a.last_used ~= b.last_used then return a.last_used > b.last_used end
		if a.count ~= b.count then return a.count > b.count end
		return a.module.order < b.module.order
	end)
	local out = {}
	for i = 1, math.min(DEBUG_RECENT_LIMIT, #rows) do
		out[i] = rows[i].module
	end
	return out
end

local function focus_debug_module(module_id)
	local m = debug_module_by_id[module_id]
	if not m then return end
	debug_nav.focus_module = module_id
	local path = module_path_label(m)
	local tab_name = page_label(m.page)
	debug_nav.location_notice = string.format(
		"%s\n%s\n%s",
		text("debug_nav_help"),
		path,
		string.format(text("debug_nav_click_tab"), tab_name)
	)
	-- Locate only. SetVisible(tab,true) is NOT Tab selection.
	touch_debug_module(module_id, "open")
end

local function build_home_dashboard(parent_id)
	imgui_layout.add_location_notice(parent_id, "QingRemasterOptions_DebugLocationNotice", function()
		return debug_nav.location_notice or ""
	end)
	local driver_id = "QingRemasterOptions_HomeRefreshDriver"
	imgui_layout.add_plain_text(parent_id, driver_id, " ")

	imgui_layout.add_separator_text(parent_id, "QingRemasterOptions_HomePinnedHeader", text("debug_pinned_help"))
	local pinned_empty = "QingRemasterOptions_HomePinnedEmpty"
	imgui_layout.add_plain_text(parent_id, pinned_empty, text("debug_pinned_empty"))

	local home_panels = {}
	local ordered = {}
	for module_id in pairs(home_control_registry) do
		ordered[#ordered + 1] = module_id
	end
	table.sort(ordered)
	for _, module_id in ipairs(ordered) do
		local spec = home_control_registry[module_id]
		local panel_id = "QingRemasterOptions_HomePanel_" .. module_id
		ImGui.AddElement(parent_id, panel_id, ImGuiElement.CollapsingHeader, spec.label or module_id)
		pcall(function() ImGui.SetVisible(panel_id, false) end)
		imgui_layout.render_control_spec(panel_id, module_id, spec.controls, "home", {
			home_keys = spec.home_keys,
		})
		if type(spec.actions) == "table" then
			for _, act in ipairs(spec.actions) do
				local aid = "QingRemasterOptions_HomeAct_" .. module_id .. "_" .. tostring(act.key or "act")
				ImGui.AddButton(panel_id, aid, act.label or "Action", function()
					if act.on_click then act.on_click() end
					touch_debug_control(module_id, act.key or "action", act.label or "Action")
				end, false)
			end
		end
		local path_hint = module_path_label({page = spec.page, path = spec.path, label = spec.label, module_id = module_id})
		if path_hint ~= "" then
			imgui_layout.add_wrapped_text(panel_id, panel_id .. "_Path", (language_key() == "zh" and "完整参数：" or "Full page: ") .. path_hint)
		end
		local footer_btns = {}
		if spec.restore then
			footer_btns[#footer_btns + 1] = {
				id = panel_id .. "_Restore",
				label = spec.restore_label or text("restore_item_defaults"),
				on_click = spec.restore,
				small = false,
			}
		end
		footer_btns[#footer_btns + 1] = {
			id = panel_id .. "_Unpin",
			label = text("debug_unpin_module"),
			on_click = function()
				toggle_module_pin(module_id)
			end,
			small = false,
		}
		imgui_layout.add_action_row(panel_id, footer_btns)
		home_panels[module_id] = panel_id
	end

	imgui_layout.add_separator_text(parent_id, "QingRemasterOptions_HomeRecentHeader", text("debug_recent_modules"))
	local recent_empty = "QingRemasterOptions_HomeRecentEmpty"
	imgui_layout.add_plain_text(parent_id, recent_empty, text("debug_recent_empty"))

	local recent_host = "QingRemasterOptions_HomeRecentHosts"
	ImGui.AddElement(parent_id, recent_host, ImGuiElement.CollapsingHeader, text("debug_recent_modules"))
	local recent_control_hosts = {}
	for module_id, spec in pairs(home_control_registry) do
		for _, control in ipairs(spec.controls or {}) do
			if control.home ~= false then
				local cid = module_id .. ":" .. control.key
				local wrap = "QingRemasterOptions_HomeRecentWrap_" .. module_id .. "_" .. control.key
				ImGui.AddElement(recent_host, wrap, ImGuiElement.TreeNode, (spec.label or module_id) .. " · " .. (control.label or control.key))
				pcall(function() ImGui.SetVisible(wrap, false) end)
				imgui_layout.render_control(wrap, module_id, control, {surface = "home_recent"})
				recent_control_hosts[cid] = wrap
			end
		end
	end

	ImGui.AddCallback(driver_id, ImGuiCallback.Render, function()
		local pinned = pinned_debug_modules()
		local pinned_set = {}
		for _, m in ipairs(pinned) do
			pinned_set[m.module_id] = true
		end
		local any_pin = false
		for module_id, panel_id in pairs(home_panels) do
			local show = pinned_set[module_id] == true
			if show then any_pin = true end
			pcall(function() ImGui.SetVisible(panel_id, show) end)
		end
		pcall(function() ImGui.SetVisible(pinned_empty, not any_pin) end)

		local recent = recent_debug_controls()
		local recent_set = {}
		for _, row in ipairs(recent) do
			recent_set[row.module_id .. ":" .. row.control_key] = row
		end
		local any_recent = false
		for cid, wrap in pairs(recent_control_hosts) do
			local row = recent_set[cid]
			local show = row ~= nil and pinned_set[row.module_id] ~= true
			if show then any_recent = true end
			pcall(function() ImGui.SetVisible(wrap, show) end)
		end
		pcall(function() ImGui.SetVisible(recent_empty, not any_recent) end)
		pcall(function() ImGui.SetVisible(recent_host, any_recent) end)
	end)

	ImGui.AddButton(parent_id, "QingRemasterOptions_RecentClear", text("debug_recent_clear"), function()
		clear_debug_access()
	end, false)
end

local function install_debug_touch_hooks()
	local raw_btn = ImGui.AddButton
	local raw_cb = ImGui.AddCallback
	ImGui.AddButton = function(parent, id, label, cb, is_small)
		local owner = debug_touch_module
		if type(cb) == "function" then
			local orig = cb
			cb = function(...)
				if owner then touch_debug_module(owner, "edit") end
				return orig(...)
			end
		end
		return raw_btn(parent, id, label, cb, is_small)
	end
	ImGui.AddCallback = function(id, typ, fn)
		local owner = debug_touch_module
		if typ == ImGuiCallback.Edited and type(fn) == "function" then
			local orig = fn
			fn = function(...)
				if owner then touch_debug_module(owner, "edit") end
				return orig(...)
			end
		end
		return raw_cb(id, typ, fn)
	end
	return function()
		ImGui.AddButton = raw_btn
		ImGui.AddCallback = raw_cb
	end
end

-- Tab page recent: use Activated (one-shot select). Visible is NOT selected.
local function install_tab_page_touch(tab_map)
	for page, tab_id in pairs(tab_map or {}) do
		if ImGuiCallback.Activated then
			pcall(function()
				ImGui.AddCallback(tab_id, ImGuiCallback.Activated, function()
					touch_debug_page(page)
				end)
			end)
		end
	end
end


local function make_imgui_page_api(extra)
	local api = {
		item = item,
		text = text,
		add_text = add_text,
		add_checkbox = add_checkbox,
		add_drag_float = add_drag_float,
		add_drag_pair_path = add_drag_pair_path,
		add_group = add_group,
		add_separator = add_separator,
		add_reset_button = add_reset_button,
		imgui_layout = imgui_layout,
		ImGui = ImGui,
		enums = enums,
		auxi = auxi,
		save = save,
		ModConfig = ModConfig,
		translations = translations,
		item_color_holder = item_color_holder,
		achievement_tracker = achievement_tracker,
		CompletionMarks = CompletionMarks,
		unlock_board = unlock_board,
		dev_env = dev_env,
		probe_registry = probe_registry,
		push_notice = push_notice,
		error_notice_type = error_notice_type,
		language_key = language_key,
		setup_window = setup_window,
		save_mod_data = save_mod_data,
		DEBUG_PAGE = DEBUG_PAGE,
		register_debug_module = register_debug_module,
		set_module_footer = set_module_footer,
		register_home_controls = register_home_controls,
		build_home_dashboard = build_home_dashboard,
	}
	if extra then
		for k, v in pairs(extra) do
			api[k] = v
		end
	end
	return api
end

function item.create_settings_window()
	settings_ui.build(make_imgui_page_api())
end

function item.create_achievements_window()
	settings_ui.build_achievements(make_imgui_page_api())
end

function item.create_debug_window()
	debug_module_list = {}
	debug_module_by_id = {}
	local debug_item = item.menu_id.."_DebugItem"
	local window_id = item.debug_id
	local tabbar = window_id.."_TabBar"
	local recent_tab = tabbar.."_Recent"
	local items_tab = tabbar.."_Items"
	local cards_tab = tabbar.."_Cards"
	local characters_tab = tabbar.."_Characters"
	local systems_tab = tabbar.."_Systems"
	local visual_tab = tabbar.."_Visual"
	local data_tab = tabbar.."_Data"
	local tests_tab = tabbar.."_Tests"
	local story_progress_tab = tabbar.."_StoryProgress"
	local story_dev_tab = tabbar.."_StoryDev"
	local boss_test_tab = tabbar.."_BossTest"
	local probes_item = item.menu_id.."_ProbesItem"
	local probes_window = item.debug_id.."_Probes"
	local probes_tabbar = probes_window.."_TabBar"
	local probe_tabs = {
		[PROBE_PAGE.items] = probes_tabbar.."_Items",
		[PROBE_PAGE.characters] = probes_tabbar.."_Characters",
		[PROBE_PAGE.systems] = probes_tabbar.."_Systems",
		[PROBE_PAGE.visual] = probes_tabbar.."_Visual",
		[PROBE_PAGE.runtime] = probes_tabbar.."_Runtime",
	}

	ImGui.AddElement(item.menu_id, debug_item, ImGuiElement.MenuItem, text("debug_item"))
	ImGui.CreateWindow(window_id, text("debug_title"))
	setup_window(window_id, item.default_window.debug)
	ImGui.LinkWindowToElement(window_id, debug_item)
	ImGui.CreateWindow(probes_window, text("probes_title"))
	setup_window(probes_window, item.default_window.debug)
	-- Public builds exclude *_probe.lua implementations and do not expose the
	-- development-only Probes window in the menu.
	if dev_env.probes_allowed() then
		ImGui.AddElement(item.menu_id, probes_item, ImGuiElement.MenuItem, text("probes_item"))
		ImGui.LinkWindowToElement(probes_window, probes_item)
	end
	ImGui.AddTabBar(probes_window, probes_tabbar)
	ImGui.AddTab(probes_tabbar, probe_tabs[PROBE_PAGE.items], text("probe_page_items"))
	ImGui.AddTab(probes_tabbar, probe_tabs[PROBE_PAGE.characters], text("probe_page_characters"))
	ImGui.AddTab(probes_tabbar, probe_tabs[PROBE_PAGE.systems], text("probe_page_systems"))
	ImGui.AddTab(probes_tabbar, probe_tabs[PROBE_PAGE.visual], text("probe_page_visual"))
	ImGui.AddTab(probes_tabbar, probe_tabs[PROBE_PAGE.runtime], text("probe_page_runtime"))
	imgui_layout.set_context({debug_window_width = item.default_window.debug.w or 800})
	local uninstall_touch_hooks = install_debug_touch_hooks()
	debug_footer_opts = {}
	ImGui.AddTabBar(window_id, tabbar)
	ImGui.AddTab(tabbar, recent_tab, text("debug_page_recent"))
	ImGui.AddTab(tabbar, items_tab, text("debug_page_items"))
	ImGui.AddTab(tabbar, cards_tab, text("debug_page_cards"))
	ImGui.AddTab(tabbar, characters_tab, text("debug_page_characters"))
	ImGui.AddTab(tabbar, systems_tab, text("debug_page_systems"))
	ImGui.AddTab(tabbar, visual_tab, text("debug_page_visual"))
	ImGui.AddTab(tabbar, data_tab, text("debug_page_data"))
	ImGui.AddTab(tabbar, tests_tab, text("debug_page_tests"))
	ImGui.AddTab(tabbar, story_progress_tab, (Options and Options.Language == "en") and "Story Progress" or "剧情进度")
	if dev_env.probes_allowed() then
		ImGui.AddTab(tabbar, story_dev_tab, (Options and Options.Language == "en") and "Story Dev" or "支线调试")
	end
	ImGui.AddTab(tabbar, boss_test_tab, "Boss Test")

	local page_parent = {
		[DEBUG_PAGE.items] = items_tab,
		[DEBUG_PAGE.cards] = cards_tab,
		[DEBUG_PAGE.characters] = characters_tab,
		[DEBUG_PAGE.systems] = systems_tab,
		[DEBUG_PAGE.visual] = visual_tab,
		[DEBUG_PAGE.data] = data_tab,
		[DEBUG_PAGE.tests] = tests_tab,
	}
	debug_page_parent = page_parent
	debug_nav.tab_ids = {
		[DEBUG_PAGE.recent] = recent_tab,
		[DEBUG_PAGE.items] = items_tab,
		[DEBUG_PAGE.cards] = cards_tab,
		[DEBUG_PAGE.characters] = characters_tab,
		[DEBUG_PAGE.systems] = systems_tab,
		[DEBUG_PAGE.visual] = visual_tab,
		[DEBUG_PAGE.data] = data_tab,
		[DEBUG_PAGE.tests] = tests_tab,
	}

	imgui_layout.bind_access({
		push_notice = push_notice,
		error_notice_type = error_notice_type,
		focus_debug_module = focus_debug_module,
		is_pinned = is_module_pinned,
		toggle_pin = toggle_module_pin,
		pin_label = function() return text("debug_pin_module") end,
		unpin_label = function() return text("debug_unpin_module") end,
		get_value = function(path) return item.get_value(path) end,
		set_value = function(path, value) item.set_value(path, value) end,
		restricted_unlocked = function()
			local dbg = debug_settings_root()
			if type(dbg) == "table" and dbg.RestrictedUnlocked == true then return true end
			return dev_env.probes_allowed() == true
		end,
	})
	imgui_layout.bind_control_touch(touch_debug_control)

	install_tab_page_touch({
		[DEBUG_PAGE.items] = items_tab,
		[DEBUG_PAGE.cards] = cards_tab,
		[DEBUG_PAGE.characters] = characters_tab,
		[DEBUG_PAGE.systems] = systems_tab,
		[DEBUG_PAGE.visual] = visual_tab,
		[DEBUG_PAGE.data] = data_tab,
		[DEBUG_PAGE.tests] = tests_tab,
	})

	-- Home dashboard built after home_control_registry is filled

	local function start_debug_module(module_id, page, label, group_id, meta)
		meta = meta or {}
		local parent = meta.parent or page_parent[page] or systems_tab
		local group = add_group(parent, group_id, label)
		local entry = register_debug_module(module_id, page, label, group_id, meta)
		if not entry then return nil end
		debug_touch_module = module_id
		if meta.footer then
			debug_footer_opts[module_id] = meta.footer
		end
		return group
	end
	local start_mod = start_debug_module

	local function start_probe_module(module_id, label, group_id, meta)
		meta = meta or {}
		local registered = probe_registry.get_ui(module_id)
		if not registered then return nil end
		assert(meta.home == nil and meta.parent == nil, "probe UI cannot register on Home or a Debug parent")
		local parent = probe_tabs[registered.page]
		assert(parent, "invalid PROBE_PAGE for " .. tostring(module_id))
		return add_group(parent, group_id, label)
	end
	local api = make_imgui_page_api({
		start_mod = start_mod,
		start_probe_module = start_probe_module,
		page_parent = page_parent,
		recent_tab = recent_tab,
		items_tab = items_tab,
		cards_tab = cards_tab,
		characters_tab = characters_tab,
		systems_tab = systems_tab,
		visual_tab = visual_tab,
		data_tab = data_tab,
		tests_tab = tests_tab,
		story_progress_tab = story_progress_tab,
		story_dev_tab = story_dev_tab,
		boss_test_tab = boss_test_tab,
	})
	debug_ui.build(api)
	probes_ui.build(api)

	build_home_dashboard(recent_tab)

	for _, m in ipairs(debug_module_list) do
		if m.pinnable ~= false and m.group_id then
			local fopts = debug_footer_opts[m.module_id] or {}
			imgui_layout.add_module_footer(m.group_id, m.module_id, {
				id_stem = m.group_id .. "_Footer",
				restore = fopts.restore,
				restore_label = fopts.restore_label,
			})
		end
	end

	do
		local ok, progress_ui = pcall(require, "Qing_Remaster_scripts.debug.story_progress_ui")
		if ok and progress_ui and progress_ui.build then
			progress_ui.build(story_progress_tab)
		end
	end
	if dev_env.probes_allowed() then
		do
			local ok, story_dev = pcall(require, "Qing_Remaster_scripts.debug.story_dev_lab")
			if ok and story_dev and story_dev.build then
				story_dev.build(story_dev_tab)
			end
		end
	end
	do
		local ok, boss_test_lab = pcall(require, "Qing_Remaster_scripts.debug.boss_test_lab")
		if ok and boss_test_lab and boss_test_lab.build then
			boss_test_lab.build(boss_test_tab)
		end
	end

	debug_touch_module = nil
	if uninstall_touch_hooks then uninstall_touch_hooks() end
end

function item.create_menu()
	if not REPENTOGON or not ImGui then return end
	item.get_settings()
	if not element_exists(item.menu_id) then
		ImGui.CreateMenu(item.menu_id, text("menu"))
		item.create_settings_window()
		item.create_achievements_window()
		item.create_debug_window()
		if Console and Console.RegisterCommand then
			local autocomplete = AutocompleteType and AutocompleteType.NONE or 0
			Console.RegisterCommand("qing_options", text("console_desc"), "qing_options", true, autocomplete)
		end
	end
	if not element_exists(item.achievements_id) then item.create_achievements_window() end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EXECUTE_CMD, params = nil,
Function = function(_,cmd,params)
	if not REPENTOGON or not ImGui then return end
	if string.lower(cmd or "") == "qing_options" then
		ImGui.Show()
		ImGui.SetVisible(item.settings_id, true)
	end
end,
})

if REPENTOGON and ModCallbacks.MC_POST_SAVESLOT_LOAD then
	table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_SAVESLOT_LOAD, params = nil,
	Function = function(_)
		if save.RuntimeLoaded == true then
			item.get_settings()
		end
	end,
	})
end

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_)
	item.get_settings()
end,
})

function item.Init(mod)
	item.create_menu()
end

if REPENTOGON and ImGui then
	item.create_menu()
end

return item
