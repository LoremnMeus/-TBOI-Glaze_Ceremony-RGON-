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
				BlueprintSettingsVersion = 7,
				SuperBombsBombGrowthSeconds = 20,
				SuperBombsMamaGrowthSeconds = 120,
				SuperBombsTimerX = -7,
				SuperBombsTimerY = -8.25,
				TitleMarqueeStartX = 320,
				TitleMarqueeEndX = 80,
				TitleMarqueeY = 80,
				TitleMarqueeSpeed = 28,
				TitleMarqueeFadeWidth = 48,
				TitleMarqueeLetterSpacing = 4,
				TitleMarqueeRainbowSpeed = 0.7,
				TitleMarqueeWaveSpeed = 0.26,
				TitleMarqueeEdgeIntensity = 0.45,
				TitleMarqueeEdgeWaveWidth = 0.75,
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
				GlazeCrownForceSeija = false,
				BookOfThothForceSeija = false,
				BookOfThothDivineSplit = 0.4,
				BookOfThothConfirmY = 0,
				BookOfThothDotOffsetX = 0,
				BookOfThothDotOffsetY = -11,
				GospelForceSeija = false,
				DramaForceMask = false,
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
				GoldenSlotCost = 1,
				GoldenSlotWeightMidasFly = 20,
				GoldenSlotWeightGoldTroll = 10,
				GoldenSlotWeightGoldCoin = 32,
				GoldenSlotWeightGoldBomb = 36,
				GoldenSlotWeightGoldHeart = 26,
				GoldenSlotWeightGoldKey = 28,
				GoldenSlotWeightGoldBattery = 18,
				GoldenSlotWeightGoldPill = 18,
				GoldenSlotWeightGoldMegaPill = 10,
				GoldenSlotWeightGoldTrinket = 14,
				GoldenSlotWeightEnding = 1,
				GoldenSlotCoinOffsetX = 4.5,
				GoldenSlotCoinOffsetY = -6.25,
				GoldenSlotCoinScale = 0.5,
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
				PareidoliaTechLaserProbe = false,
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
		achievements_item = "\u{f091} Achievements",
		achievements_title = "Qing Remaster - Achievements",
		live_item = "\u{f03d} Live Broadcast",
		live_title = "Qing Remaster - Live Broadcast",
		tab_debug_tools = "Debug tools",
		debug_page_recent = "Recent",
		debug_page_flight = "Blueprint & Flight",
		debug_page_items = "Items",
		debug_page_audit = "Audit",
		debug_page_visual = "Visual",
		debug_recent_help = "Recently opened or edited modules. Shortcuts open the same controls (no duplicates).",
		debug_recent_empty = "No recent modules yet. Open or edit a group on another page.",
		debug_recent_clear = "Clear recent",
		debug_back_recent = "Back to recent",
		debug_goto_page = "View category",
		debug_nav_help = "Category filter: only one page of groups is shown. Controls are registered once.",
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
		character_menu_lang_help = "Swaps Qing character-select text sheets at runtime. Default follows the game language.",
		character_menu_lang_auto = "Follow game language",
		character_menu_lang_zh = "Force Chinese",
		character_menu_lang_en = "Force English",
		character_menu_lang_status = "Current sheets: %s (game language: %s)",
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
		anna_torsion_help = "Normal slash: takeoff→landing segment; band limits effect beside the path.",
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
		air_debug_force_luck_help = "Debug only. Overrides craft profile luck for Mom's Eye / Loki's Horns / other luck rolls. Off = use profile (0 luck ≈ Mom's Eye 50%, Loki 25%).",
		air_debug_hit_status = "Hit / volley status (click refresh)",
		air_debug_hit_refresh = "Refresh hit / volley status",
		group_prism_probe = "Angelic Prism color probe",
		prism_probe_help = "Samples vanilla Angelic Prism (528) split-tear colors (R/G/B/A + RO/GO/BO), angles, newborn clusters. giveitem c528 and shoot through prism. Writes codex_work/logs/angelic_prism_vanilla_probe.jsonl",
		prism_probe_enable = "Enable Angelic Prism probe",
		prism_probe_export = "Export Angelic Prism probe now",
		prism_probe_clear = "Clear Angelic Prism probe samples",
		prism_probe_status = "Probe off",
		group_special_fam_probe = "Special familiar probes",
		special_fam_probe_help = "Vanilla probes for Bob's Brain / Lil Spewer / Guppy's Hairball / Holy Water. Each switch writes its own codex_work/logs/*_vanilla_probe.jsonl",
		special_fam_probe_bobs = "Enable Bob's Brain probe (273)",
		special_fam_probe_spewer = "Enable Lil Spewer probe (537)",
		special_fam_probe_hair = "Enable Hairball probe (187)",
		special_fam_probe_holy = "Enable Holy Water probe (178)",
		special_fam_probe_export = "Export this probe",
		special_fam_probe_clear = "Clear this probe",
		special_fam_probe_refresh = "Refresh status",
		group_aura_vanilla_probe = "Aura / Zit vanilla probe",
		aura_vanilla_probe_help = "Vanilla c502/c447/c446/c574 Monstrance/c559 120 Volt/c423 Circle. Samples Tear/Effect/Laser(+anim blink, PositionOffset). Writes codex_work/logs/craft_aura_vanilla_probe.jsonl. No craft.",
		aura_vanilla_probe_enable = "Enable aura vanilla probe",
		aura_vanilla_probe_export = "Export aura probe now",
		aura_vanilla_probe_clear = "Clear aura probe samples",
		aura_vanilla_probe_status = "Aura probe off",
		group_charge_weapon_probe = "Charge weapon vanilla probe",
		charge_weapon_probe_help = "Vanilla c399 Maw / c643 Revelation. Charge fully then release. Samples lasers to codex_work/logs/craft_charge_weapon_vanilla_probe.jsonl. No craft.",
		charge_weapon_probe_enable = "Enable charge-weapon probe",
		charge_weapon_probe_export = "Export charge-weapon probe now",
		charge_weapon_probe_clear = "Clear charge-weapon samples",
		charge_weapon_probe_status = "Charge-weapon probe off",
		group_orbiting_tear_probe = "Orbiting tear / Evil Eye probe",
		orbiting_tear_probe_help = "Vanilla c595 Saturnus / c573 Immaculate / c410 Evil Eye. Samples tears to codex_work/logs/craft_orbiting_tear_vanilla_probe.jsonl. No craft.",
		orbiting_tear_probe_enable = "Enable orbiting-tear probe",
		orbiting_tear_probe_export = "Export orbiting-tear probe now",
		orbiting_tear_probe_clear = "Clear orbiting-tear samples",
		orbiting_tear_probe_status = "Orbiting-tear probe off",
		group_evil_eye_probe = "Evil Eye vanilla probe (1000.84)",
		evil_eye_probe_help = "giveitem c410. Samples EffectVariant.EVIL_EYE (1000.84) State/Timeout/Velocity + child tears. → codex_work/logs/craft_evil_eye_vanilla_probe.jsonl. No craft.",
		evil_eye_probe_enable = "Enable Evil Eye probe",
		evil_eye_probe_export = "Flush Evil Eye probe now",
		evil_eye_probe_clear = "Clear Evil Eye samples",
		evil_eye_probe_status = "Evil Eye probe off",
		group_vengeful_probe = "Vengeful Spirit vanilla probe (3.206.702)",
		vengeful_probe_help = "giveitem c702. Samples FamiliarVariant.WISP SubType 702 orbit + tears tied to player fire. → codex_work/logs/vengeful_spirit_vanilla_probe.jsonl. No craft.",
		vengeful_probe_enable = "Enable Vengeful Spirit probe",
		vengeful_probe_export = "Flush Vengeful Spirit probe now",
		vengeful_probe_clear = "Clear Vengeful Spirit samples",
		vengeful_probe_status = "Vengeful Spirit probe off",
		group_vengeful_life_probe = "Vengeful craft lifecycle probe",
		vengeful_life_probe_help = "Craft 702 wisps (3.206.702). Logs spawn/pending/bind/PRE/Remove vs engine POST_ENTITY_REMOVE. → codex_work/logs/vengeful_craft_lifecycle_probe.jsonl. Default off.",
		vengeful_life_probe_enable = "Enable vengeful lifecycle probe",
		vengeful_life_probe_export = "Flush vengeful lifecycle probe now",
		vengeful_life_probe_clear = "Clear vengeful lifecycle samples",
		vengeful_life_probe_status = "Vengeful lifecycle probe off",
		group_orbiting_offset_probe = "Craft orbit tear Offset probe (v3 fall)",
		orbiting_offset_probe_help = "Craft Saturnus/Immaculate. Enable truncates log. Dense around release; transition=fall_age0. Expect fix: FA>eps keeps PO=visual_y (no PO=0 flash). → codex_work/logs/craft_orbiting_tear_offset_probe.jsonl",
		orbiting_offset_probe_enable = "Enable Offset probe",
		orbiting_offset_probe_export = "Flush Offset probe now",
		orbiting_offset_probe_clear = "Clear Offset probe samples",
		orbiting_offset_probe_status = "Offset probe off",
		group_laser_flag_probe = "Craft laser flag probe",
		laser_flag_probe_help = "Craft Brim/Tech while player holds My Reflection / player Tech vs craft-only Brim. Logs Variant vs expected_variant, CollisionDamage vs bound_damage, CurveStrength → codex_work/logs/craft_laser_flag_probe.jsonl",
		laser_flag_probe_enable = "Enable laser-flag probe",
		laser_flag_probe_export = "Flush laser-flag probe now",
		laser_flag_probe_clear = "Clear laser-flag samples",
		laser_flag_probe_status = "Laser-flag probe off",
		group_knife_path_probe = "Mom's Knife path probe",
		knife_path_probe_help = "Vanilla/craft Mom's Knife (+homing / Tiny Planet). Knife Update ~60fps. Logs Charge/PathOffset/PathFollowSpeed/Rotation/TearFlags → codex_work/logs/craft_knife_path_probe.jsonl",
		knife_path_probe_enable = "Enable knife-path probe",
		knife_path_probe_export = "Flush knife-path probe now",
		knife_path_probe_clear = "Clear knife-path samples",
		knife_path_probe_status = "Knife-path probe off",
		group_maw_pose_probe = "Maw ring flight pose probe",
		maw_pose_probe_help = "Craft Maw (399). While the ring is active, samples Flight vel/desired/dist/hint to codex_work/logs/craft_maw_flight_pose_probe.jsonl.",
		maw_pose_probe_enable = "Enable Maw pose probe",
		maw_pose_probe_export = "Export Maw pose probe now",
		maw_pose_probe_clear = "Clear Maw pose samples",
		maw_pose_probe_status = "Maw pose probe off",
		group_aura_balance = "Aura balance (Monstrance)",
		aura_balance_help = "Monstrance radius / halo scale defaults are half of the first craft pass. Drag to retune; Restore resets to craft defaults.",
		aura_bal_mon_radius = "Monstrance radius",
		aura_bal_mon_scale = "Monstrance FX scale",
		aura_bal_mon_interval = "Monstrance damage interval",
		aura_bal_restore = "Restore Monstrance defaults",
		group_path_tear_probe = "Path tear vanilla probe",
		path_tear_probe_help = "Vanilla c233 Tiny Planet / c573 Immaculate / c5 My Reflection. Dense orbit/boomerang samples → codex_work/logs/craft_path_tear_vanilla_probe.jsonl. No craft.",
		path_tear_probe_enable = "Enable path-tear probe",
		path_tear_probe_export = "Export path-tear probe now",
		path_tear_probe_clear = "Clear path-tear samples",
		path_tear_probe_status = "Path-tear probe off",
		group_spewer_geo_probe = "Lil Spewer geometry probe",
		spewer_geo_probe_help = "Fine geometry for white dual-arc / red end creep / lemon Scale+Timeout. Vanilla giveitem c537 only (no craft). Writes codex_work/logs/lil_spewer_geometry_probe.jsonl",
		spewer_geo_probe_enable = "Enable Lil Spewer geometry probe",
		spewer_geo_probe_export = "Export geometry probe now",
		spewer_geo_probe_clear = "Clear geometry probe samples",
		spewer_geo_probe_refresh = "Refresh status",
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
		temp_revive_help = "Tracks spent innate revive copies (1UP / Dead Cat / …). Held-sprite capture after revive confirms source. Default logging off.",
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
		blueprint_tutorial_status = "Tutorial: idle",
		blueprint_tutorial_start = "Start Blueprint tutorial",
		blueprint_tutorial_start_skip = "Start tutorial (skip prompt)",
		blueprint_tutorial_abort = "Abort tutorial and cleanup",
		blueprint_tutorial_reset = "Reset first-open tutorial flag",
		blueprint_tutorial_help = "Tainted Qing first-open Blueprint lesson. Debug can re-enter anytime. End always deletes practice crafts.",
		blueprint_cost_scale = "Cost icon scale",
		blueprint_cost_scale_help = "Scale of cost question-mark / tokens inside the mini-slot (default 0.5).",
		blueprint_cost_slot_size = "Cost slot size (px)",
		blueprint_cost_slot_size_help = "Outline box size. Dot step is 8px: 16 → 3 dots, 32 → 5 dots (large slots use ~34).",
		blueprint_cost_qmark_x = "Cost ? offset X",
		blueprint_cost_qmark_y = "Cost ? offset Y",
		blueprint_cost_qmark_help = "Pixel offset for the cost-slot question-mark sprite.",
		group_charon_tide = "Charon's Sign black tide",
		group_ritual_sting = "Ritual Sting color bars",
		ritual_sting_help = "Edits the six bars of the first current holder. This is runtime test data, not a persistent option.",
		ritual_sting_red = "Red", ritual_sting_orange = "Orange", ritual_sting_yellow = "Yellow",
		ritual_sting_green = "Green", ritual_sting_blue = "Blue", ritual_sting_purple = "Purple",
		ritual_sting_reset = "Reset Ritual Sting bars",
		group_death_sentence = "Death Sentence letters",
		death_sentence_help = "Edits the death word and letters of the first current holder. This is runtime test data, not a persistent option.",
		death_sentence_death_word = "Death letters",
		death_sentence_letters = "Current letters",
		group_remaster = "Remaster!",
		remaster_help = "Floor-code flip animation. Spacing scales overall step duration; mid-path letters are always faster.",
		remaster_flip_spacing = "Code flip letter spacing",
		remaster_flip_spacing_help = "Larger spacing slows alphabet cascading (B→D plays C through). Mid letters stay relatively faster.",
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
		permanent_data_help = "Archive-level PermanentData. “Next run …” effects also live here. Non-permanent debug knobs stay on Debug tools.",
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
		spectral_clear_all = "Clear all Spectral Sword rewrites",
		spectral_cleared_notice = "All Spectral Sword rewrites cleared.",
		group_item_colors = "Mod item color analysis",
		item_colors_help = "REPENTOGON scans mod collectible icons in small batches. Hand-authored labels remain overrides; automatic labels extend Glazed Dice Shard compatibility.",
		item_colors_restart = "Restart color scan",
		item_colors_print = "Print detailed report",
		item_colors_restarted = "Mod item color scan restarted.",
		item_colors_printed = "Item color report printed to log.",
		spectral_editor_help = "Edit permanent name and pickup-subtitle rewrites created by Spectral Sword. EID keeps its original mechanical description; the subtitle is only used by pickup text.",
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
		group_glaze_crown = "Crown of the Glaze",
		glaze_crown_help = "Seija override for Crown of the Glaze. Restore defaults only resets this item's debug toggles.",
		glaze_crown_seija = "Force Seija enhancement",
		glaze_crown_seija_help = "When enabled, treats holders as Seija for testing. When disabled, only real Seija conditions apply.",
		group_book_of_thoth = "Book of Thoth",
		book_of_thoth_help = "Seija override and Divine page split. Restore defaults only resets this item.",
		book_of_thoth_seija = "Force Seija enhancement",
		book_of_thoth_seija_help = "When enabled, treats holders as Seija for testing (mystery Thoth card backs). When disabled, only real Seija conditions apply.",
		book_of_thoth_divine_split = "Divine split",
		book_of_thoth_divine_split_help = "How much of the Divine page is the upper band (formation slots). 0.40 is the default; the rest is the card pool.",
		book_of_thoth_confirm_y = "Confirm button Y",
		book_of_thoth_confirm_y_help = "Extra vertical offset for the Confirm spread button. Positive moves down. The button is centered in the gap under the slots first.",
		book_of_thoth_dot_x = "Outline dot X",
		book_of_thoth_dot_y = "Outline dot Y",
		book_of_thoth_dot_help = "Offset for the '.' used to draw Thoth outlines. Positive X/Y move right/down.",
		group_gospel = "Gospel",
		gospel_help = "Seija override for Gospel. Restore defaults only resets this item's debug toggles.",
		gospel_seija = "Force Seija enhancement",
		gospel_seija_help = "When enabled, treats holders as Seija for testing (Gospel cannot spread; Preaching and Revelation become weaker dark lights). When disabled, only real Seija conditions apply.",
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
		regenesis_help = "Run scores, pending next-run legacy (PermanentData), and the current run's active Age. Hidden numbers stay hidden in-game; this panel is for audit and testing.",
		regenesis_status = "Audit",
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
		diamond_hud_help = "Trade HUD above the player: diamond icon → digits + coin. Tune offsets/scales here.",
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
		golden_slot_help = "Per-run coin cost and reward weights for Golden Slot.",
		golden_slot_cost = "Current coin cost",
		golden_slot_cost_help = "Resets each run. Each successful use increases this by 1.",
		golden_slot_w_fly = "Weight: midas fly",
		golden_slot_w_troll = "Weight: golden troll bomb",
		golden_slot_w_coin = "Weight: golden coin",
		golden_slot_w_bomb = "Weight: golden bomb",
		golden_slot_w_heart = "Weight: golden heart",
		golden_slot_w_key = "Weight: golden key",
		golden_slot_w_battery = "Weight: golden battery",
		golden_slot_w_pill = "Weight: golden pill",
		golden_slot_w_mega_pill = "Weight: giant golden pill",
		golden_slot_w_trinket = "Weight: golden trinket",
		golden_slot_w_ending = "Weight: trophy / mega chest",
		golden_slot_coin_x = "Coin icon offset X",
		golden_slot_coin_x_help = "Offset from the right edge of the cost text.",
		golden_slot_coin_y = "Coin icon offset Y",
		golden_slot_coin_y_help = "Offset from the active slot UI position.",
		golden_slot_coin_scale = "Coin icon scale",
		group_reserved_judgment = "Reserved Judgment",
		reserved_judgment_help = "Reserve-marker icon layout and test helpers.",
		reserved_judgment_mark_range = "Mark range",
		reserved_judgment_mark_range_help = "Max distance to reserve an option-group collectible with Drop.",
		reserved_judgment_icon_x = "Marker offset X",
		reserved_judgment_icon_y = "Marker offset Y (world, down +)",
		reserved_judgment_icon_scale = "Marker scale",
		reserved_judgment_spawn_choices = "Spawn option choices (3)",
		reserved_judgment_give_item = "Give Reserved Judgment",
		reserved_judgment_clear_trial = "Clear trial / marks",
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
		achievements_item = "\u{f091} 成就",
		achievements_title = "小青 重制版 - 成就",
		live_item = "\u{f03d} 直播姬",
		live_title = "小青 重制版 - 直播姬",
		tab_debug_tools = "调试工具",
		debug_page_recent = "常用",
		debug_page_flight = "蓝图与飞行器",
		debug_page_items = "道具",
		debug_page_audit = "审计",
		debug_page_visual = "视觉",
		debug_recent_help = "最近打开或修改过的模块。快捷入口打开同一套控件，不会复制注册。",
		debug_recent_empty = "暂无最近记录。请到其他分类展开或修改某一组。",
		debug_recent_clear = "清空最近记录",
		debug_back_recent = "返回最近",
		debug_goto_page = "查看所在分类",
		debug_nav_help = "分类筛选：同一时刻只显示一页分组；控件只注册一次。",
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
		anna_torsion_help = "普通斩：起飞→落地线段；band 限制切开线两侧作用范围。",
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
		air_debug_force_luck_help = "仅调试。覆盖档案幸运，用于妈眼/洛基角等。关闭=用档案（0幸运：妈眼约50%，洛基约25%，不是接近0）。",
		air_debug_hit_status = "命中/弹道状态（点刷新）",
		air_debug_hit_refresh = "刷新命中/弹道状态",
		group_prism_probe = "天使棱镜配色探针",
		prism_probe_help = "采样原版天使棱镜(528)分裂泪 Color（R/G/B/A 与 RO/GO/BO）、速度角、新生簇。请 giveitem c528 朝棱镜连射。写出 codex_work/logs/angelic_prism_vanilla_probe.jsonl",
		prism_probe_enable = "启用天使棱镜探针",
		prism_probe_export = "立即导出天使棱镜探针",
		prism_probe_clear = "清空天使棱镜探针样本",
		prism_probe_status = "探针关闭",
		group_special_fam_probe = "专属宝宝原版探针",
		special_fam_probe_help = "273鲍勃脑浆 / 537小吐根 / 187毛球 / 178圣水。各开关独立写出 codex_work/logs/*_vanilla_probe.jsonl",
		special_fam_probe_bobs = "启用鲍勃脑浆探针 (273)",
		special_fam_probe_spewer = "启用小吐根探针 (537)",
		special_fam_probe_hair = "启用毛球探针 (187)",
		special_fam_probe_holy = "启用圣水探针 (178)",
		special_fam_probe_export = "导出该探针",
		special_fam_probe_clear = "清空该探针",
		special_fam_probe_refresh = "刷新状态",
		group_aura_vanilla_probe = "光环/痘弹原版探针",
		aura_vanilla_probe_help = "原版 c502/c447/c446/c574圣体光/c559 220伏/c423保护之环。采样 Tear/Effect/Laser（含动画闪烁、PositionOffset）。写出 codex_work/logs/craft_aura_vanilla_probe.jsonl。勿开制造。",
		aura_vanilla_probe_enable = "启用光环原版探针",
		aura_vanilla_probe_export = "立即导出光环探针",
		aura_vanilla_probe_clear = "清空光环探针样本",
		aura_vanilla_probe_status = "光环探针关闭",
		group_charge_weapon_probe = "蓄力武器原版探针",
		charge_weapon_probe_help = "原版 c399虚空之口 / c643启示。蓄满后松开。采样激光写出 codex_work/logs/craft_charge_weapon_vanilla_probe.jsonl。勿开制造。",
		charge_weapon_probe_enable = "启用蓄力武器原版探针",
		charge_weapon_probe_export = "立即导出蓄力武器探针",
		charge_weapon_probe_clear = "清空蓄力武器探针样本",
		charge_weapon_probe_status = "蓄力武器探针关闭",
		group_orbiting_tear_probe = "环绕泪/邪眼原版探针",
		orbiting_tear_probe_help = "原版 c595土星 / c573无暇之心 / c410邪眼。采样泪弹写出 codex_work/logs/craft_orbiting_tear_vanilla_probe.jsonl。勿开制造。",
		orbiting_tear_probe_enable = "启用环绕泪原版探针",
		orbiting_tear_probe_export = "立即导出环绕泪探针",
		orbiting_tear_probe_clear = "清空环绕泪探针样本",
		orbiting_tear_probe_status = "环绕泪探针关闭",
		group_evil_eye_probe = "邪眼原版探针（1000.84）",
		evil_eye_probe_help = "giveitem c410。采样 EffectVariant.EVIL_EYE（1000.84）的 State/Timeout/速度，以及眼球子泪间隔。→ codex_work/logs/craft_evil_eye_vanilla_probe.jsonl。勿开制造。",
		evil_eye_probe_enable = "启用邪眼原版探针",
		evil_eye_probe_export = "立即刷写邪眼探针",
		evil_eye_probe_clear = "清空邪眼探针样本",
		evil_eye_probe_status = "邪眼探针关闭",
		group_vengeful_probe = "魂火原版探针（3.206.702）",
		vengeful_probe_help = "giveitem c702。采样 FamiliarVariant.WISP SubType 702 的轨道/跟随，以及随玩家开火产生的泪弹（类型/间隔/配色）。→ codex_work/logs/vengeful_spirit_vanilla_probe.jsonl。勿开制造。",
		vengeful_probe_enable = "启用魂火原版探针",
		vengeful_probe_export = "立即刷写魂火探针",
		vengeful_probe_clear = "清空魂火探针样本",
		vengeful_probe_status = "魂火探针关闭",
		group_vengeful_life_probe = "魂火制造生命周期探针",
		vengeful_life_probe_help = "制造 702 魂火（3.206.702）。记录 spawn/pending/bind/PRE 是否跳过 AI，以及 Lua Remove vs 引擎 POST_ENTITY_REMOVE。→ codex_work/logs/vengeful_craft_lifecycle_probe.jsonl。默认关。",
		vengeful_life_probe_enable = "启用魂火生命周期探针",
		vengeful_life_probe_export = "立即刷写魂火生命周期探针",
		vengeful_life_probe_clear = "清空魂火生命周期样本",
		vengeful_life_probe_status = "魂火生命周期探针关闭",
		group_orbiting_offset_probe = "制造环绕泪 Offset 探针（v3 松环）",
		orbiting_offset_probe_help = "制造土星/无暇。启用时截断旧日志。松环±密采；transition=fall_age0。已修：FA>eps 时 PO 与画面 Y 同写（勿再 PO=0 闪一帧）。→ codex_work/logs/craft_orbiting_tear_offset_probe.jsonl",
		orbiting_offset_probe_enable = "启用 Offset 探针",
		orbiting_offset_probe_export = "立即刷写 Offset 探针",
		orbiting_offset_probe_clear = "清空 Offset 探针样本",
		orbiting_offset_probe_status = "Offset 探针关闭",
		group_laser_flag_probe = "制造激光 flag 探针",
		laser_flag_probe_help = "制造硫磺/科技；对照外观与 sample 路径。跟踪时看 sample0≈air_pos、HomingType。日志 → codex_work/logs/craft_laser_flag_probe.jsonl",
		laser_flag_probe_enable = "启用激光 flag 探针",
		laser_flag_probe_export = "立即导出激光 flag 探针",
		laser_flag_probe_clear = "清空激光 flag 样本",
		laser_flag_probe_status = "激光 flag 探针关闭",
		group_knife_path_probe = "妈刀路径探针",
		knife_path_probe_help = "原版/制造妈刀（+弯勺/小小星球）。刀 Update≈60fps。采样 Charge/PathOffset/PathFollowSpeed/Rotation/TearFlags → codex_work/logs/craft_knife_path_probe.jsonl",
		knife_path_probe_enable = "启用妈刀路径探针",
		knife_path_probe_export = "立即导出妈刀路径探针",
		knife_path_probe_clear = "清空妈刀路径样本",
		knife_path_probe_status = "妈刀路径探针关闭",
		group_maw_pose_probe = "虚空环姿态探针",
		maw_pose_probe_help = "制造虚空之口(399)。环存活期间采样 Flight 速度/期望/距敌/hint，写出 codex_work/logs/craft_maw_flight_pose_probe.jsonl。",
		maw_pose_probe_enable = "启用虚空环姿态探针",
		maw_pose_probe_export = "立即导出虚空环姿态探针",
		maw_pose_probe_clear = "清空虚空环姿态样本",
		maw_pose_probe_status = "虚空环姿态探针关闭",
		group_aura_balance = "光环平衡（圣体光）",
		aura_balance_help = "圣体光默认半径/贴图约为首版一半。拖条随时改；恢复=写回制造默认。",
		aura_bal_mon_radius = "圣体光伤害半径",
		aura_bal_mon_scale = "圣体光贴图 Scale",
		aura_bal_mon_interval = "圣体光伤害间隔(帧)",
		aura_bal_restore = "恢复圣体光默认",
		group_path_tear_probe = "路径泪原版探针",
		path_tear_probe_help = "原版 c233小小星球 / c573无暇 / c5我的镜像。密采样半径角速度与回旋减速 → codex_work/logs/craft_path_tear_vanilla_probe.jsonl。勿开制造。",
		path_tear_probe_enable = "启用路径泪探针",
		path_tear_probe_export = "立即导出路径泪探针",
		path_tear_probe_clear = "清空路径泪样本",
		path_tear_probe_status = "路径泪探针关闭",
		group_spewer_geo_probe = "小吐根几何精细探针",
		spewer_geo_probe_help = "白环定圆 / 红终点大水迹 / 柠檬 Scale+Timeout 寿命。仅原版 giveitem c537（勿开制造）。写出 codex_work/logs/lil_spewer_geometry_probe.jsonl",
		spewer_geo_probe_enable = "启用小吐根几何探针",
		spewer_geo_probe_export = "立即导出几何探针",
		spewer_geo_probe_clear = "清空几何探针样本",
		spewer_geo_probe_refresh = "刷新状态",
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
		ritual_sting_help = "直接调节当前局内首个持有者的六色进度；不会保存为模组设置。",
		ritual_sting_red = "红色", ritual_sting_orange = "橙色", ritual_sting_yellow = "黄色",
		ritual_sting_green = "绿色", ritual_sting_blue = "蓝色", ritual_sting_purple = "紫色",
		ritual_sting_reset = "重置血仪刺刃进度",
		group_death_sentence = "通灵盘·字母",
		death_sentence_help = "直接调节当前局内首个持有者的死亡字母与现有字母；不会保存为模组设置。",
		death_sentence_death_word = "死亡字母",
		death_sentence_letters = "现有字母",
		group_remaster = "Remaster!",
		remaster_help = "楼层代码翻页动画。间距放大整体变慢；路径正中的字母始终相对更快。",
		remaster_flip_spacing = "代码翻页字母间距",
		remaster_flip_spacing_help = "间距越大，字母表级联（如 B→D 经 C）越慢；中间字母仍会相对加速。",
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
		group_spectral_rewrites = "妖刀·逢魔改写",
		group_colorblind_bans = "色盲·下局点踩移除",
		colorblind_bans_help = "色盲点踩后将在下局道具池移除的道具列表；开局生效后清空。",
		colorblind_bans_empty = "（暂无下局移除）",
		colorblind_bans_clear = "清空下局点踩移除",
		colorblind_bans_cleared = "已清空色盲下局点踩列表。",
		group_diamond_permanent = "钻石·永久售价",
		diamond_permanent_help = "跨局保留的钻石商店售价与上次成交价。",
		diamond_last_sale = "上次成交价",
		diamond_permanent_restore = "恢复钻石永久售价默认",
		spectral_clear_all = "清空全部妖刀改写",
		spectral_cleared_notice = "已清空全部妖刀·逢魔改写。",
		group_item_colors = "模组道具颜色分析",
		item_colors_help = "忏悔龙会分批扫描模组道具图标。手工标签始终作为覆盖项，自动标签用于扩展琉璃的骰子碎片兼容。",
		item_colors_restart = "重新扫描道具颜色",
		item_colors_print = "输出详细报告",
		item_colors_restarted = "已重新开始模组道具颜色扫描。",
		item_colors_printed = "道具颜色报告已输出到日志。",
		spectral_editor_help = "编辑由妖刀·逢魔创建的永久名称与拾取副标题。EID 保留原有机制说明；副标题只用于拾取提示。",
		spectral_entry = "已修改道具",
		spectral_name = "名称",
		spectral_description = "描述",
		spectral_no_entries = "暂无已保存的修改",
		spectral_save = "保存当前修改",
		spectral_reload = "放弃草稿并重新载入",
		spectral_delete = "删除当前修改",
		spectral_undo_delete = "撤销上次删除",
		spectral_saved_notice = "已保存妖刀·逢魔的道具修改。",
		spectral_deleted_notice = "已删除妖刀·逢魔的道具修改。",
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
		super_bombs_bomb_seconds = "炸弹→超大炸弹计数上限",
		super_bombs_bomb_seconds_help = "未使用消耗型炸弹达到该秒数后，将一枚现有炸弹成长为超大炸弹。",
		super_bombs_mama_seconds = "超大炸弹→Mama Mega计数上限",
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
		group_glaze_crown = "琉璃的冠冕",
		glaze_crown_help = "琉璃的冠冕的 Seija 强制开关。恢复默认只重置该道具的调试项。",
		glaze_crown_seija = "强制 Seija 增幅",
		glaze_crown_seija_help = "开启时无论玩家状态都视为满足 Seija；关闭时仅实际 Seija 条件生效。",
		group_book_of_thoth = "透特之书",
		book_of_thoth_help = "透特之书调试：Seija 强制开关，以及占卜页上下分区。恢复默认只重置该道具。",
		book_of_thoth_seija = "强制 Seija 增幅",
		book_of_thoth_seija_help = "开启时无论玩家状态都视为满足 Seija（透特牌背面）；关闭时仅实际 Seija 条件生效。",
		book_of_thoth_divine_split = "占卜分区",
		book_of_thoth_divine_split_help = "上半区（阵位槽）占内容区高度的比例。默认 0.40，剩下给牌池。确认钮在槽位下方空隙居中。",
		book_of_thoth_confirm_y = "确认钮 Y",
		book_of_thoth_confirm_y_help = "「确认占卜」按钮的额外垂直偏移。正值向下。先在槽位与分割线之间居中，再叠加此值。",
		book_of_thoth_dot_x = "框线点 X",
		book_of_thoth_dot_y = "框线点 Y",
		book_of_thoth_dot_help = "绘制框线所用 '.' 的偏移；正 X/Y 向右/向下。",
		group_gospel = "福音",
		gospel_help = "福音的 Seija 强制开关。恢复默认只重置该道具的调试项。",
		gospel_seija = "强制 Seija 增幅",
		gospel_seija_help = "开启时无论玩家状态都视为满足 Seija（福音无法传播，宣讲与启示改为较弱的黑暗之光）；关闭时仅实际 Seija 条件生效。",
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
		regenesis_help = "本局隐藏分数、跨局 Pending 遗产（PermanentData），以及当前局已生效的世纪。游戏内不显示数字；此面板仅供审计和测试。",
		regenesis_status = "审计",
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
		diamond_hud_help = "玩家头顶议价条：钻石贴图 → 价格数字 + 硬币图标。用下列参数对齐。",
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
		golden_slot_help = "每局金币消耗与奖励权重。",
		golden_slot_cost = "当前金币消耗",
		golden_slot_cost_help = "每局重置；每次成功使用后+1。",
		golden_slot_w_fly = "权重：点金苍蝇",
		golden_slot_w_troll = "权重：金Troll炸弹",
		golden_slot_w_coin = "权重：金金币",
		golden_slot_w_bomb = "权重：金炸弹",
		golden_slot_w_heart = "权重：金心",
		golden_slot_w_key = "权重：金钥匙",
		golden_slot_w_battery = "权重：金电池",
		golden_slot_w_pill = "权重：金药丸",
		golden_slot_w_mega_pill = "权重：大金药丸",
		golden_slot_w_trinket = "权重：金饰品",
		golden_slot_w_ending = "权重：奖杯/超大金箱",
		golden_slot_coin_x = "硬币 icon 偏移 X",
		golden_slot_coin_x_help = "相对消耗数字右缘的水平偏移。",
		golden_slot_coin_y = "硬币 icon 偏移 Y",
		golden_slot_coin_y_help = "相对 Active 槽位 UI 位置的垂直偏移。",
		golden_slot_coin_scale = "硬币 icon Scale",
		group_reserved_judgment = "保留意见",
		reserved_judgment_help = "保留标识位置与测试工具。",
		reserved_judgment_mark_range = "保留判定距离",
		reserved_judgment_mark_range_help = "按 Drop 保留多选道具时的最大距离。",
		reserved_judgment_icon_x = "标识偏移 X",
		reserved_judgment_icon_y = "标识偏移 Y（世界坐标，下为正）",
		reserved_judgment_icon_scale = "标识 Scale",
		reserved_judgment_spawn_choices = "生成多选道具（3）",
		reserved_judgment_give_item = "给予保留意见",
		reserved_judgment_clear_trial = "清除试用/保留标记",
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
end

local function export_sparse_modconfig(merged)
	local sparse = auxi.deepCopy(merged or {})
	prune_matching_defaults(sparse, build_defaults_tree())
	return sparse
end

function item.get_settings()
	local root = save.ModConfigSettings or ModConfig.ModConfigSettings or {}
	apply_debug_migrations(root)
	local defaults = build_defaults_tree()
	prune_matching_defaults(root, defaults)
	shallow_merge_defaults(root, defaults)
	save.ModConfigSettings = root
	ModConfig.ModConfigSettings = root
	return root
end

function item.get_value(path)
	return get_by_path(item.get_settings(), path)
end

function item.set_value(path, value)
	local root = item.get_settings()
	local default_value = get_by_path(build_defaults_tree(), path)
	if values_equal(value, default_value) then
		set_by_path(root, path, default_value)
	else
		set_by_path(root, path, value)
	end
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
			shallow_merge_defaults(sparse, build_defaults_tree())
			save.ModConfigSettings = sparse
			ModConfig.ModConfigSettings = sparse
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
	ImGui.AddElement(parent_id, "", ImGuiElement.TextWrapped, text)
end

local function add_separator(parent_id, text)
	local separator = ImGuiElement.SeparatorText or ImGuiElement.Separator
	ImGui.AddElement(parent_id, "", separator, text or "")
end

local debug_touch_module = nil
local touch_debug_module

local function add_checkbox(parent_id, element_id, label, path, help)
	ImGui.AddCheckbox(parent_id, element_id, label, nil, item.get_value(path) == true)
	ImGui.AddCallback(element_id, ImGuiCallback.Render, function()
		ImGui.UpdateData(element_id, ImGuiData.Value, item.get_value(path) == true)
	end)
	ImGui.AddCallback(element_id, ImGuiCallback.Edited, function(value)
		item.set_value(path, value == true)
		if debug_touch_module then touch_debug_module(debug_touch_module, "edit") end
	end)
	if help then ImGui.SetHelpmarker(element_id, help) end
end

local function add_drag_float(parent_id, element_id, label, path, help, speed, min_value, max_value, formatting)
	local function set_value(value)
		item.set_value(path, tonumber(value) or 0)
		if debug_touch_module then touch_debug_module(debug_touch_module, "edit") end
	end
	ImGui.AddDragFloat(parent_id, element_id, label, set_value, tonumber(item.get_value(path)) or 0, speed or 0.25, min_value or -16, max_value or 16, formatting or "%.2f")
	ImGui.AddCallback(element_id, ImGuiCallback.Render, function()
		ImGui.UpdateData(element_id, ImGuiData.Value, tonumber(item.get_value(path)) or 0)
	end)
	ImGui.AddCallback(element_id, ImGuiCallback.Edited, set_value)
	if help then ImGui.SetHelpmarker(element_id, help) end
end

local function add_group(parent_id, element_id, label)
	ImGui.AddElement(parent_id, element_id, ImGuiElement.CollapsingHeader, label)
	return element_id
end

local function item_color_state_text(state)
	local zh = language_key() == "zh"
	local states = zh and {
		waiting = "等待扫描",
		scanning = "扫描中",
		complete = "已完成",
		unavailable = "忏悔龙图像接口不可用",
	} or {
		waiting = "Waiting",
		scanning = "Scanning",
		complete = "Complete",
		unavailable = "REPENTOGON image API unavailable",
	}
	return states[state] or tostring(state)
end

local function item_color_status_text()
	local stats = item_color_holder.get_stats()
	if language_key() == "zh" then
		return string.format(
			"状态：%s\n已处理：%d / %d    成功：%d    失败：%d    缓存命中：%d\n手工对照：%d    有交集：%d    完全一致：%d    冲突：%d\n最近：%d  %s",
			item_color_state_text(stats.state),
			stats.processed or 0,stats.total or 0,stats.succeeded or 0,stats.failed or 0,stats.cached or 0,
			stats.compared or 0,stats.overlap or 0,stats.exact or 0,stats.conflict or 0,
			stats.last_id or 0,stats.last_name or ""
		)
	end
	return string.format(
		"State: %s\nProcessed: %d / %d    Success: %d    Failed: %d    Cache hits: %d\nManual comparisons: %d    Overlap: %d    Exact: %d    Conflicts: %d\nLatest: %d  %s",
		item_color_state_text(stats.state),
		stats.processed or 0,stats.total or 0,stats.succeeded or 0,stats.failed or 0,stats.cached or 0,
		stats.compared or 0,stats.overlap or 0,stats.exact or 0,stats.conflict or 0,
		stats.last_id or 0,stats.last_name or ""
	)
end

local function item_color_failure_text()
	local failures = item_color_holder.get_stats().failures or {}
	if #failures == 0 then
		return language_key() == "zh" and "最近失败：无" or "Recent failures: none"
	end
	local lines = {language_key() == "zh" and "最近失败：" or "Recent failures:"}
	for i = math.max(1,#failures - 4),#failures do
		local failure = failures[i]
		lines[#lines + 1] = string.format("%d %s: %s",failure.id or 0,failure.name or "",failure.reason or "")
	end
	return table.concat(lines,"\n")
end

local function add_item_color_panel(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupItemColors",text("group_item_colors"))
	add_text(group,text("item_colors_help"))

	local progress_id = "QingRemasterOptions_ItemColorProgress"
	local status_id = "QingRemasterOptions_ItemColorStatus"
	local categories_id = "QingRemasterOptions_ItemColorCategories"
	local failures_id = "QingRemasterOptions_ItemColorFailures"
	local stats = item_color_holder.get_stats()
	local progress = stats.total > 0 and stats.processed / stats.total or 0
	ImGui.AddProgressBar(group,progress_id,"",progress,tostring(stats.processed or 0).."/"..tostring(stats.total or 0))
	ImGui.AddCallback(progress_id,ImGuiCallback.Render,function()
		local current = item_color_holder.get_stats()
		local value = current.total > 0 and current.processed / current.total or 0
		ImGui.UpdateData(progress_id,ImGuiData.Value,value)
		ImGui.UpdateData(progress_id,ImGuiData.HintText,tostring(current.processed or 0).."/"..tostring(current.total or 0))
	end)

	ImGui.AddElement(group,status_id,ImGuiElement.TextWrapped,item_color_status_text())
	ImGui.AddCallback(status_id,ImGuiCallback.Render,function()
		ImGui.UpdateText(status_id,item_color_status_text())
	end)
	ImGui.AddElement(group,categories_id,ImGuiElement.TextWrapped,item_color_holder.get_category_summary())
	ImGui.AddCallback(categories_id,ImGuiCallback.Render,function()
		local summary = item_color_holder.get_category_summary()
		if summary == "" then summary = language_key() == "zh" and "颜色分布：等待数据" or "Color distribution: waiting for data" end
		ImGui.UpdateText(categories_id,summary)
	end)
	ImGui.AddElement(group,failures_id,ImGuiElement.TextWrapped,item_color_failure_text())
	ImGui.AddCallback(failures_id,ImGuiCallback.Render,function()
		ImGui.UpdateText(failures_id,item_color_failure_text())
	end)

	ImGui.AddButton(group,"QingRemasterOptions_ItemColorRestart",text("item_colors_restart"),function()
		item_color_holder.start_scan(true)
		push_notice(text("item_colors_restarted"))
	end)
	ImGui.AddElement(group,"",ImGuiElement.SameLine)
	ImGui.AddButton(group,"QingRemasterOptions_ItemColorPrint",text("item_colors_print"),function()
		item_color_holder.print_report()
		push_notice(text("item_colors_printed"))
	end)
end

local function setup_window(window_id, info)
	local screen_w = Options and tonumber(Options.WindowWidth) or nil
	local screen_h = Options and tonumber(Options.WindowHeight) or nil
	local width,height = info.w,info.h
	local x,y = 80,60
	if screen_w and screen_h and screen_w > 0 and screen_h > 0 then
		-- RGON ImGui 使用窗口像素；按当前游戏画面取大部分空间，并在低分辨率下保留边距。
		width = math.min(math.max(info.w,math.floor(screen_w * (info.screen_w or 0.8))),math.max(320,screen_w - 40))
		height = math.min(math.max(info.h,math.floor(screen_h * (info.screen_h or 0.82))),math.max(240,screen_h - 40))
		x = math.max(20,math.floor((screen_w - width) * 0.5))
		y = math.max(20,math.floor((screen_h - height) * 0.5))
	end
	if ImGui.SetSize then ImGui.SetSize(window_id, width, height) end
	if ImGui.SetWindowPosition then ImGui.SetWindowPosition(window_id, x, y) end
	if ImGui.SetVisible then ImGui.SetVisible(window_id, false) end
end

local save_mod_data

local function add_reset_button(parent_id, label)
	ImGui.AddButton(parent_id, parent_id.."_ResetDefaults", label, function()
		local root = item.get_settings()
		local defaults = build_defaults_tree()
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
	return entry and (entry[language_key()] or entry.en) or tostring(key)
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
		return CompletionMarks.legacy_boss_field_status(BOSS_MARK_IDS[category], mark, field)
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
		CompletionMarks.set_legacy_boss_field(BOSS_MARK_IDS[category], mark, field, value == true)
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
	ImGui.SetHelpmarker(id,reward_annotation(category,mark,field))
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

function item.create_achievements_window()
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
	ImGui.AddElement(marks_group,xy_id,ImGuiElement.TextWrapped,string.format(text("completion_marks_character_xy"),0,0))
	ImGui.AddCallback(xy_id,ImGuiCallback.Render,function()
		local x = tonumber(item.get_value({"QingRemasterOptions","CompletionMarks","CharacterOffsetX"})) or 0
		local y = tonumber(item.get_value({"QingRemasterOptions","CompletionMarks","CharacterOffsetY"})) or 0
		ImGui.UpdateText(xy_id,string.format(text("completion_marks_character_xy"),x,y))
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

save_mod_data = function()
	if save.SaveModData then
		local ok,err = pcall(save.SaveModData)
		if not ok then print("QING:: Failed to save Spectral Sword rewrites: "..tostring(err)) end
	end
end

local function spectral_data()
	local key = "Item_Spectralsword_data"
	save.PermanentData = save.PermanentData or {}
	if save.PermanentData[key] == nil and save.elses and save.elses[key] ~= nil then
		save.PermanentData[key] = save.elses[key]
	end
	save.PermanentData[key] = save.PermanentData[key] or {rewrites = {},affixes = {}}
	save.PermanentData[key].rewrites = save.PermanentData[key].rewrites or {}
	save.PermanentData[key].affixes = save.PermanentData[key].affixes or {}
	for _,rewrite in pairs(save.PermanentData[key].rewrites) do
		if type(rewrite) == "table" and rewrite.Desc == nil and rewrite.Description ~= nil then
			rewrite.Desc = rewrite.Description
			rewrite.Description = nil
		end
	end
	return save.PermanentData[key]
end

local function spectral_load_selected()
	local editor = item.spectral_editor
	local rewrite = editor.selected_id and spectral_data().rewrites[tostring(editor.selected_id)] or nil
	editor.draft_name = rewrite and tostring(rewrite.Name or "") or ""
	editor.draft_description = rewrite and tostring(rewrite.Desc or "") or ""
end

local function spectral_refresh(force)
	local editor = item.spectral_editor
	local rewrites = spectral_data().rewrites
	local ids = {}
	for raw_id,rewrite in pairs(rewrites) do
		local id = tonumber(raw_id)
		if id and type(rewrite) == "table" and (rewrite.Name ~= nil or rewrite.Desc ~= nil) then
			table.insert(ids,id)
		end
	end
	table.sort(ids)
	local signature_parts = {}
	for _,id in ipairs(ids) do
		local rewrite = rewrites[tostring(id)] or {}
		table.insert(signature_parts,tostring(id).."\31"..tostring(rewrite.Name or "").."\31"..tostring(rewrite.Desc or ""))
	end
	local signature = table.concat(signature_parts,"\30")
	if not force and signature == editor.signature then return false end

	local previous_id = editor.selected_id
	editor.ids = ids
	editor.options = {}
	editor.selected_index = 1
	editor.selected_id = nil
	for index,id in ipairs(ids) do
		local rewrite = rewrites[tostring(id)] or {}
		local display_name = tostring(rewrite.Name or "")
		if display_name == "" and Isaac.GetItemConfig then
			local config = Isaac.GetItemConfig():GetCollectible(id)
			display_name = config and tostring(config.Name or "") or ""
		end
		table.insert(editor.options,tostring(id).." - "..display_name)
		if id == previous_id then editor.selected_index = index end
	end
	if #ids > 0 then
		editor.selected_id = ids[editor.selected_index] or ids[1]
	else
		editor.options = {text("spectral_no_entries")}
	end
	editor.signature = signature
	spectral_load_selected()
	return true
end

local function spectral_select(index,value)
	local editor = item.spectral_editor
	if #editor.ids == 0 then return end
	local selected = nil
	for option_index,option in ipairs(editor.options) do
		if option == value then selected = option_index break end
	end
	if selected == nil then
		selected = math.max(1,math.min(#editor.ids,(tonumber(index) or 0) + 1))
	end
	editor.selected_index = selected
	editor.selected_id = editor.ids[selected]
	spectral_load_selected()
end

function item.create_spectral_editor_panel(parent_id)
	local prefix = item.debug_id.."_SpectralSwordEditor"
	local group_id = prefix.."_Rewrites"
	local combo_id = prefix.."_Entry"
	local name_id = prefix.."_Name"
	local description_id = prefix.."_Description"

	spectral_refresh(true)
	local group = add_group(parent_id, group_id, text("group_spectral_rewrites"))
	add_text(group,text("spectral_editor_help"))
	ImGui.AddCombobox(group,combo_id,text("spectral_entry"),spectral_select,item.spectral_editor.options,math.max(0,item.spectral_editor.selected_index - 1))
	ImGui.AddCallback(combo_id,ImGuiCallback.Render,function()
		spectral_refresh(false)
		ImGui.UpdateData(combo_id,ImGuiData.ListValues,item.spectral_editor.options)
		ImGui.UpdateData(combo_id,ImGuiData.Value,math.max(0,item.spectral_editor.selected_index - 1))
	end)

	ImGui.AddInputText(group,name_id,text("spectral_name"),function(value)
		item.spectral_editor.draft_name = tostring(value or "")
	end,item.spectral_editor.draft_name,"")
	ImGui.AddCallback(name_id,ImGuiCallback.Render,function()
		ImGui.UpdateData(name_id,ImGuiData.Value,item.spectral_editor.draft_name)
	end)

	ImGui.AddInputTextMultiline(group,description_id,text("spectral_description"),function(value)
		item.spectral_editor.draft_description = tostring(value or "")
	end,item.spectral_editor.draft_description,8)
	ImGui.AddCallback(description_id,ImGuiCallback.Render,function()
		ImGui.UpdateData(description_id,ImGuiData.Value,item.spectral_editor.draft_description)
	end)

	ImGui.AddButton(group,prefix.."_Save",text("spectral_save"),function()
		local editor = item.spectral_editor
		if editor.selected_id == nil then push_notice(text("spectral_no_selection"),error_notice_type()) return end
		local rewrite = spectral_data().rewrites[tostring(editor.selected_id)] or {}
		rewrite.Name = editor.draft_name
		rewrite.Desc = editor.draft_description
		spectral_data().rewrites[tostring(editor.selected_id)] = rewrite
		editor.signature = nil
		save_mod_data()
		spectral_refresh(true)
		push_notice(text("spectral_saved_notice"))
	end)
	ImGui.AddElement(group,"",ImGuiElement.SameLine)
	ImGui.AddButton(group,prefix.."_Reload",text("spectral_reload"),function()
		if item.spectral_editor.selected_id == nil then push_notice(text("spectral_no_selection"),error_notice_type()) return end
		spectral_load_selected()
	end)

	ImGui.AddButton(group,prefix.."_Delete",text("spectral_delete"),function()
		local editor = item.spectral_editor
		if editor.selected_id == nil then push_notice(text("spectral_no_selection"),error_notice_type()) return end
		local key = tostring(editor.selected_id)
		local rewrite = spectral_data().rewrites[key]
		editor.last_deleted = {id = editor.selected_id,rewrite = {Name = rewrite and rewrite.Name,Desc = rewrite and rewrite.Desc}}
		spectral_data().rewrites[key] = nil
		editor.selected_id = nil
		editor.signature = nil
		save_mod_data()
		spectral_refresh(true)
		push_notice(text("spectral_deleted_notice"))
	end)
	ImGui.AddElement(group,"",ImGuiElement.SameLine)
	ImGui.AddButton(group,prefix.."_UndoDelete",text("spectral_undo_delete"),function()
		local deleted = item.spectral_editor.last_deleted
		if deleted == nil then push_notice(text("spectral_nothing_to_undo"),error_notice_type()) return end
		spectral_data().rewrites[tostring(deleted.id)] = {
			Name = deleted.rewrite.Name,
			Desc = deleted.rewrite.Desc,
		}
		item.spectral_editor.selected_id = deleted.id
		item.spectral_editor.last_deleted = nil
		item.spectral_editor.signature = nil
		save_mod_data()
		spectral_refresh(true)
		push_notice(text("spectral_restored_notice"))
	end)
	ImGui.AddButton(group,prefix.."_ClearAll",text("spectral_clear_all"),function()
		spectral_data().rewrites = {}
		item.spectral_editor.selected_id = nil
		item.spectral_editor.last_deleted = nil
		item.spectral_editor.signature = nil
		save_mod_data()
		spectral_refresh(true)
		push_notice(text("spectral_cleared_notice"))
	end)
end

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

function item.create_settings_window()
	local settings_item = item.menu_id.."_SettingsItem"
	local window_id = item.settings_id
	local tabbar = window_id.."_TabBar"
	local tabs = {
		Compatibility = tabbar.."_Compatibility",
		Gameplay = tabbar.."_Gameplay",
		HUD = tabbar.."_HUD",
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
	ImGui.AddTab(tabbar, tabs.Cards, text("tab_cards"))

	local compatibility_rgon = add_group(tabs.Compatibility, "QingRemasterOptions_GroupCompatibilityRgon", text("group_rgon"))
	add_checkbox(compatibility_rgon, "QingRemasterOptions_UseRgonImitateItems", text("use_rgon_imitate"), {"QingRemasterOptions", "Compatibility", "UseRgonImitateItems"}, text("use_rgon_imitate_help"))

	local gameplay_runtime = add_group(tabs.Gameplay, "QingRemasterOptions_GroupGameplayRuntime", text("group_runtime"))
	add_checkbox(gameplay_runtime, "QingRemasterOptions_ItemsAllow", text("items_allow"), {"Items_allow"}, text("existing_setting"))
	add_checkbox(gameplay_runtime, "QingRemasterOptions_TrinketsAllow", text("trinkets_allow"), {"Trinkets_allow"}, text("existing_setting"))
	add_checkbox(gameplay_runtime, "QingRemasterOptions_PickupAllow", text("pickup_allow"), {"Pickup_allow"}, text("existing_setting"))
	add_checkbox(gameplay_runtime, "QingRemasterOptions_BossAllow", text("boss_allow"), {"Boss_allow"}, text("existing_setting"))
	add_checkbox(gameplay_runtime, "QingRemasterOptions_AchievementAllow", text("achievement_allow"), {"Achievement_allow"}, text("existing_setting"))
	add_checkbox(gameplay_runtime, "QingRemasterOptions_AchievementPoolGating", text("achievement_pool_gating"), {"Achievement_pool_gating"}, text("achievement_pool_gating_help"))
	add_checkbox(gameplay_runtime, "QingRemasterOptions_AchievementTrinketGating", text("achievement_trinket_gating"), {"Achievement_trinket_gating"}, text("achievement_trinket_gating_help"))
	add_checkbox(gameplay_runtime, "QingRemasterOptions_AchievementCardGating", text("achievement_card_gating"), {"Achievement_card_gating"}, text("achievement_card_gating_help"))
	add_checkbox(gameplay_runtime, "QingRemasterOptions_AchievementPickupGating", text("achievement_pickup_gating"), {"Achievement_pickup_gating"}, text("achievement_pickup_gating_help"))
	local gameplay_callbacks = add_group(tabs.Gameplay, "QingRemasterOptions_GroupAttackCallbacks", text("group_attack_callbacks"))
	add_checkbox(gameplay_callbacks, "QingRemasterOptions_TriggerLaserStart", text("trigger_laser_start"), {"Trigger_LaserStart"}, text("trigger_laser_start_help"))
	add_checkbox(gameplay_callbacks, "QingRemasterOptions_TriggerLaserEnd", text("trigger_laser_end"), {"Trigger_LaserEnd"}, text("trigger_laser_end_help"))
	add_checkbox(gameplay_callbacks, "QingRemasterOptions_TriggerBrimStart", text("trigger_brim_start"), {"Trigger_BrimStart"}, text("trigger_brim_start_help"))
	add_checkbox(gameplay_callbacks, "QingRemasterOptions_TriggerBrimEnd", text("trigger_brim_end"), {"Trigger_BrimEnd"}, text("trigger_brim_end_help"))

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

	local function apply_character_menu_language()
		local holder = require("Qing_Remaster_scripts.callbacks.rgon_menu_language_holder")
		if holder then
			holder.loaded_by_hash = {}
			holder.applied_language = nil
			if holder.apply_language then holder.apply_language(true) end
		end
	end
	local function set_character_menu_language(mode)
		item.set_value({"QingRemasterOptions", "Menu", "CharacterSelectLanguage"}, mode)
		apply_character_menu_language()
	end
	local character_menu_lang = add_group(tabs.HUD, "QingRemasterOptions_GroupCharacterMenuLang", text("group_character_menu_lang"))
	add_text(character_menu_lang, text("character_menu_lang_help"))
	local character_menu_status_id = "QingRemasterOptions_CharacterSelectLangStatus"
	ImGui.AddElement(character_menu_lang, character_menu_status_id, ImGuiElement.TextWrapped, "")
	ImGui.AddCallback(character_menu_status_id, ImGuiCallback.Render, function()
		local holder = require("Qing_Remaster_scripts.callbacks.rgon_menu_language_holder")
		local current = holder and holder.get_language and holder.get_language() or "en"
		local game_lang = holder and holder.get_game_language and holder.get_game_language() or "en"
		ImGui.UpdateText(character_menu_status_id, string.format(text("character_menu_lang_status"), current, game_lang))
	end)
	ImGui.AddButton(character_menu_lang, "QingRemasterOptions_CharacterSelectLangAuto", text("character_menu_lang_auto"), function()
		set_character_menu_language(0)
	end)
	ImGui.AddButton(character_menu_lang, "QingRemasterOptions_CharacterSelectLangZh", text("character_menu_lang_zh"), function()
		set_character_menu_language(1)
	end)
	ImGui.AddButton(character_menu_lang, "QingRemasterOptions_CharacterSelectLangEn", text("character_menu_lang_en"), function()
		set_character_menu_language(2)
	end)

	add_card_rates_group(tabs.Cards)

	local maintenance_group = add_group(window_id, "QingRemasterOptions_GroupMaintenance", text("group_maintenance"))
	add_reset_button(maintenance_group, text("reset_defaults"))
end

local function add_live_broadcast_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupLiveBroadcast",text("live_item"))
	add_checkbox(group,"QingRemasterOptions_LiveAutoLive",text("auto_live"),{"Auto_Live"},text("auto_live_help"))
	add_drag_float(group,"QingRemasterOptions_LiveInterval",text("live_interval"),{"QingRemasterOptions","Live","MessageIntervalScale"},text("live_interval_help"),0.05,0.25,4,"%.2fx")
	add_drag_float(group,"QingRemasterOptions_LiveSoftLimit",text("live_soft_limit"),{"QingRemasterOptions","Live","BulletSoftLimit"},text("live_soft_limit_help"),1,10,300,"%.0f")
	add_drag_float(group,"QingRemasterOptions_LiveHardLimit",text("live_hard_limit"),{"QingRemasterOptions","Live","BulletHardLimit"},text("live_hard_limit_help"),1,20,500,"%.0f")
	add_drag_float(group,"QingRemasterOptions_LiveSpeed",text("live_speed"),{"QingRemasterOptions","Live","BulletSpeed"},text("live_speed_help"),0.05,0.25,6,"%.2f")
	add_drag_float(group,"QingRemasterOptions_LiveScale",text("live_scale"),{"QingRemasterOptions","Live","BulletScale"},text("live_scale_help"),0.05,0.5,2,"%.2fx")
	add_drag_float(group,"QingRemasterOptions_LiveOpacity",text("live_opacity"),{"QingRemasterOptions","Live","BulletOpacity"},text("live_opacity_help"),0.05,0.1,1,"%.2f")
end

local function add_ritual_sting_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupRitualSting",text("group_ritual_sting"))
	add_text(group,text("ritual_sting_help"))
	local ritual_sting = require("Qing_Remaster_scripts.items.Item_Ritual_Sting")
	local labels = {"red","orange","yellow","green","blue","purple"}
	local function holder()
		if not Isaac.IsInGame or not Isaac.IsInGame() then return nil end
		for player_num = 0,Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(player_num)
			if player:HasCollectible(ritual_sting.entity) then return player end
		end
	end
	for color_id,label in ipairs(labels) do
		local element_id = "QingRemasterOptions_RitualSting_"..label
		local function set_value(value)
			local player = holder()
			if not player then push_notice(text("start_run_first"),error_notice_type()) return end
			ritual_sting.get_values(player)[color_id] = math.max(0,math.min(30,(tonumber(value) or 0) / 10))
			ritual_sting.refresh_effects(player,true)
		end
		ImGui.AddDragFloat(group,element_id,text("ritual_sting_"..label),set_value,100,1,0,300,"%.1f%%")
		ImGui.AddCallback(element_id,ImGuiCallback.Render,function()
			local player = holder()
			local value = player and ritual_sting.get_values(player)[color_id] * 10 or 100
			ImGui.UpdateData(element_id,ImGuiData.Value,value)
		end)
		ImGui.AddCallback(element_id,ImGuiCallback.Edited,set_value)
	end
	ImGui.AddButton(group,"QingRemasterOptions_RitualStingReset",text("ritual_sting_reset"),function()
		local player = holder()
		if not player then push_notice(text("start_run_first"),error_notice_type()) return end
		local values = ritual_sting.get_values(player)
		for color_id = 1,6 do values[color_id] = 10 end
		ritual_sting.refresh_effects(player,true)
	end)
end

local function add_death_sentence_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupDeathSentence",text("group_death_sentence"))
	add_text(group,text("death_sentence_help"))
	local death_sentence = require("Qing_Remaster_scripts.items.Item_Death_Sentence")
	local function holder()
		if not Isaac.IsInGame or not Isaac.IsInGame() then return nil end
		for player_num = 0,Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(player_num)
			if player:HasCollectible(death_sentence.entity) then return player end
		end
	end

	local death_id = "QingRemasterOptions_DeathSentence_DeathWord"
	ImGui.AddInputText(group,death_id,text("death_sentence_death_word"),function(value)
		death_sentence.set_death_word(value)
	end,death_sentence.get_death_word(),"")
	ImGui.AddCallback(death_id,ImGuiCallback.Render,function()
		ImGui.UpdateData(death_id,ImGuiData.Value,death_sentence.get_death_word())
	end)

	local letters_id = "QingRemasterOptions_DeathSentence_Letters"
	ImGui.AddInputText(group,letters_id,text("death_sentence_letters"),function(value)
		local player = holder()
		if not player then push_notice(text("start_run_first"),error_notice_type()) return end
		death_sentence.set_letters_string(player,value)
	end,"","")
	ImGui.AddCallback(letters_id,ImGuiCallback.Render,function()
		local player = holder()
		ImGui.UpdateData(letters_id,ImGuiData.Value,player and death_sentence.get_letters_string(player) or "")
	end)

	ImGui.AddButton(group,"QingRemasterOptions_DeathSentenceReset",text("restore_item_defaults"),function()
		local player = holder()
		if not player then push_notice(text("start_run_first"),error_notice_type()) return end
		death_sentence.reset_debug(player)
	end)
end

local function add_book_of_voice_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupBookOfVoice",text("group_book_of_voice"))
	add_text(group,text("book_of_voice_help"))
	local voice = require("Qing_Remaster_scripts.items.Item_Book_of_Voice")
	add_checkbox(group,"QingRemasterOptions_VoiceForceSeija",text("book_of_voice_seija"),{"QingRemasterOptions","Debug","VoiceForceSeijaDefy"},text("book_of_voice_seija_help"))
	local function holder()
		if not Isaac.IsInGame or not Isaac.IsInGame() then return nil end
		for player_num = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(player_num)
			if player:HasCollectible(voice.entity) or (voice.voice_entity and player:HasCollectible(voice.voice_entity)) then return player end
		end
		return Game():GetPlayer(0)
	end
	local poss_id = "QingRemasterOptions_VoicePossession"
	ImGui.AddDragFloat(group,poss_id,text("book_of_voice_possession"),function(value)
		local player = holder()
		if not player then return end
		voice.debug_set_possession(player, value)
	end,0,1,0,20,"%.0f")
	ImGui.AddCallback(poss_id,ImGuiCallback.Render,function()
		local player = holder()
		ImGui.UpdateData(poss_id,ImGuiData.Value,player and voice.debug_get_possession(player) or 0)
	end)
	ImGui.SetHelpmarker(poss_id,text("book_of_voice_possession_help"))
	ImGui.AddButton(group,"QingRemasterOptions_VoiceRestoreDefaults",text("restore_item_defaults"),function()
		item.set_value({"QingRemasterOptions","Debug","VoiceForceSeijaDefy"},false)
		local player = holder()
		if player then voice.debug_set_possession(player, 0) end
	end)
end

local function add_regenesis_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupRegenesis",text("group_regenesis"))
	add_text(group,text("regenesis_help"))
	local regenesis = require("Qing_Remaster_scripts.items.Item_Regenesis")
	local keys = regenesis.CENTURIES or {"Prosperity","War","Abundance","Technology","Faith","Ruin"}
	local function century_options()
		local opts = {text("regenesis_none")}
		for _, key in ipairs(keys) do
			opts[#opts + 1] = text("regenesis_score_"..string.lower(key))
		end
		return opts
	end
	local function century_index(name)
		if not name then return 0 end
		for i, key in ipairs(keys) do
			if key == name then return i end
		end
		return 0
	end
	local status_id = "QingRemasterOptions_RegenesisStatus"
	ImGui.AddElement(group,status_id,ImGuiElement.TextWrapped,text("regenesis_status"))
	ImGui.AddCallback(status_id,ImGuiCallback.Render,function()
		ImGui.UpdateText(status_id,(regenesis.get_debug_status and regenesis.get_debug_status()) or "")
	end)
	local score_labels = {
		Prosperity = "regenesis_score_prosperity",
		War = "regenesis_score_war",
		Abundance = "regenesis_score_abundance",
		Technology = "regenesis_score_technology",
		Faith = "regenesis_score_faith",
		Ruin = "regenesis_score_ruin",
	}
	for _, key in ipairs(keys) do
		local drag_id = "QingRemasterOptions_RegenesisScore_"..key
		ImGui.AddDragFloat(group,drag_id,text(score_labels[key] or key),function(value)
			regenesis.set_score(key,value)
		end,1,1,0,300,"%.0f")
		ImGui.AddCallback(drag_id,ImGuiCallback.Render,function()
			local run = regenesis.get_run_data and regenesis.get_run_data()
			ImGui.UpdateData(drag_id,ImGuiData.Value,(run and run.Scores and run.Scores[key]) or 0)
		end)
	end
	local active_id = "QingRemasterOptions_RegenesisActive"
	ImGui.AddCombobox(group,active_id,text("regenesis_active"),function(index)
		index = tonumber(index) or 0
		regenesis.set_active_century(keys[index])
	end,century_options(),0)
	ImGui.AddCallback(active_id,ImGuiCallback.Render,function()
		local run = regenesis.get_run_data and regenesis.get_run_data()
		ImGui.UpdateData(active_id,ImGuiData.ListValues,century_options())
		ImGui.UpdateData(active_id,ImGuiData.Value,century_index(run and run.ActiveCentury))
	end)
	local pending_id = "QingRemasterOptions_RegenesisPending"
	ImGui.AddCombobox(group,pending_id,text("regenesis_pending"),function(index)
		index = tonumber(index) or 0
		regenesis.set_pending_century(keys[index])
	end,century_options(),0)
	ImGui.AddCallback(pending_id,ImGuiCallback.Render,function()
		local legacy = regenesis.get_legacy and regenesis.get_legacy()
		ImGui.UpdateData(pending_id,ImGuiData.ListValues,century_options())
		ImGui.UpdateData(pending_id,ImGuiData.Value,century_index(legacy and legacy.Pending and legacy.Century))
	end)
	ImGui.AddButton(group,"QingRemasterOptions_RegenesisSettle",text("regenesis_force_settle"),function()
		local century = regenesis.force_settle()
		push_notice(text("regenesis_settled")..(century and text("regenesis_score_"..string.lower(century)) or text("regenesis_none")))
	end)
	ImGui.AddButton(group,"QingRemasterOptions_RegenesisApply",text("regenesis_apply_active"),function()
		local century = regenesis.debug_apply_active()
		push_notice(text("regenesis_applied")..(century and text("regenesis_score_"..string.lower(century)) or text("regenesis_none")))
	end)
	ImGui.AddButton(group,"QingRemasterOptions_RegenesisAnnounce",text("regenesis_announce"),function()
		if regenesis.debug_announce then regenesis.debug_announce() end
	end)
	ImGui.AddButton(group,"QingRemasterOptions_RegenesisClearLegacy",text("regenesis_clear_legacy"),function()
		regenesis.clear_legacy()
		push_notice(text("regenesis_cleared"))
	end)
	ImGui.AddButton(group,"QingRemasterOptions_RegenesisReset",text("restore_item_defaults"),function()
		regenesis.reset_debug()
	end)
end

local function add_bloody_map_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupBloodyMap",text("group_bloody_map"))
	add_text(group,text("bloody_map_help"))
	add_checkbox(group,"QingRemasterOptions_BloodyMapForceSeija",text("bloody_map_seija"),{"QingRemasterOptions","Debug","BloodyMapForceSeijaEnhancement"},text("bloody_map_seija_help"))
	add_drag_float(group,"QingRemasterOptions_BloodyMapSpawnChance",text("bloody_map_spawn_chance"),{"QingRemasterOptions","Debug","BloodyMapMessengerSpawnChance"},text("bloody_map_spawn_chance_help"),0.01,0,1,"%.2f")
	add_drag_float(group,"QingRemasterOptions_BloodyMessengerPayNothing",text("bloody_messenger_pay_nothing"),{"QingRemasterOptions","Debug","BloodyMessengerPayNothingChance"},text("bloody_messenger_pay_nothing_help"),0.01,0,1,"%.2f")
	add_drag_float(group,"QingRemasterOptions_BloodyMessengerDouble",text("bloody_messenger_double"),{"QingRemasterOptions","Debug","BloodyMessengerDoubleRewardChance"},text("bloody_messenger_double_help"),0.01,0,1,"%.2f")
	add_drag_float(group,"QingRemasterOptions_BloodyMessengerWeightNothing",text("bloody_messenger_weight_nothing"),{"QingRemasterOptions","Debug","BloodyMessengerWeightNothing"},nil,1,0,1000,"%.0f")
	add_drag_float(group,"QingRemasterOptions_BloodyMessengerWeightUltra",text("bloody_messenger_weight_ultra"),{"QingRemasterOptions","Debug","BloodyMessengerWeightUltraRoom"},nil,1,0,1000,"%.0f")
	add_drag_float(group,"QingRemasterOptions_BloodyMessengerWeightKey",text("bloody_messenger_weight_key"),{"QingRemasterOptions","Debug","BloodyMessengerWeightCrackedKey"},nil,1,0,1000,"%.0f")
	add_drag_float(group,"QingRemasterOptions_BloodyMessengerWeightItem",text("bloody_messenger_weight_item"),{"QingRemasterOptions","Debug","BloodyMessengerWeightItem"},nil,1,0,1000,"%.0f")
	add_drag_float(group,"QingRemasterOptions_BloodyMessengerBoostUltra",text("bloody_messenger_boost_ultra"),{"QingRemasterOptions","Debug","BloodyMessengerBoostedWeightUltraRoom"},nil,1,0,1000,"%.0f")
	add_drag_float(group,"QingRemasterOptions_BloodyMessengerBoostKey",text("bloody_messenger_boost_key"),{"QingRemasterOptions","Debug","BloodyMessengerBoostedWeightCrackedKey"},nil,1,0,1000,"%.0f")
	add_drag_float(group,"QingRemasterOptions_BloodyMessengerBoostItem",text("bloody_messenger_boost_item"),{"QingRemasterOptions","Debug","BloodyMessengerBoostedWeightItem"},nil,1,0,1000,"%.0f")
	add_drag_float(group,"QingRemasterOptions_BloodyMapUltraAmount",text("bloody_map_ultra_amount"),{"QingRemasterOptions","Debug","BloodyMapUltraGrantAmount"},text("bloody_map_ultra_amount_help"),1,1,10,"%.0f")
	add_drag_float(group,"QingRemasterOptions_BloodyMapUltraMax",text("bloody_map_ultra_max"),{"QingRemasterOptions","Debug","BloodyMapUltraGrantMax"},text("bloody_map_ultra_max_help"),1,0,20,"%.0f")
	ImGui.AddButton(group,"QingRemasterOptions_BloodyMapRestoreDefaults",text("restore_item_defaults"),function()
		local defaults = {
			BloodyMapForceSeijaEnhancement = false,
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
		}
		for key,value in pairs(defaults) do item.set_value({"QingRemasterOptions","Debug",key},value) end
	end)
end

local function add_gospel_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupGospel",text("group_gospel"))
	add_text(group,text("gospel_help"))
	add_checkbox(group,"QingRemasterOptions_GospelForceSeija",text("gospel_seija"),{"QingRemasterOptions","Debug","GospelForceSeija"},text("gospel_seija_help"))
	ImGui.AddButton(group,"QingRemasterOptions_GospelRestoreDefaults",text("restore_item_defaults"),function()
		item.set_value({"QingRemasterOptions","Debug","GospelForceSeija"},false)
	end)
end

local function add_suture_needle_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupSutureNeedle",text("group_suture_needle"))
	add_text(group,text("suture_needle_help"))
	add_checkbox(group,"QingRemasterOptions_SutureNeedleForceSeija",text("suture_needle_seija"),{"QingRemasterOptions","Debug","SutureNeedleForceSeija"},text("suture_needle_seija_help"))
	ImGui.AddButton(group,"QingRemasterOptions_SutureNeedleRestoreDefaults",text("restore_item_defaults"),function()
		item.set_value({"QingRemasterOptions","Debug","SutureNeedleForceSeija"},false)
	end)
end

local function zeiz_mod()
	local ok, mod = pcall(require, "Qing_Remaster_scripts.player.zeiz.zeiz")
	if ok then return mod end
end

local function zeiz_status_text()
	local zh = language_key() == "zh"
	local mod = zeiz_mod()
	if not mod or not mod.debug_snapshot then
		return zh and "Zeiz 模块未加载" or "Zeiz module not loaded"
	end
	local snap = mod.debug_snapshot()
	local lines = {}
	lines[#lines + 1] = (zh and "是否 Zeiz：" or "Is Zeiz: ")..tostring(snap.isZeiz)
	lines[#lines + 1] = (zh and "等待进入中枢：" or "Pending hub: ")..tostring(snap.pending)
	lines[#lines + 1] = (zh and "中枢已打开：" or "Hub open: ")..tostring(snap.open)
	lines[#lines + 1] = (zh and "位于中枢房：" or "In hub room: ")..tostring(snap.inHub)
	lines[#lines + 1] = (zh and "中枢房间号：" or "Hub index: ")..tostring(snap.hubIndex)
	local cands = snap.candidates or {}
	lines[#lines + 1] = (zh and "当前候选：" or "Candidates: ")..table.concat(cands, ", ")
	local appointed = snap.appointed or {}
	lines[#lines + 1] = (zh and "已任命：" or "Appointed: ")..table.concat(appointed, ", ")
	for id, st in pairs(snap.admins or {}) do
		local prop = st.proposal or {}
		lines[#lines + 1] = string.format("%s  app=%s  I=%.1f  %s  ready=%s offered=%s approved=%s folly=%s",
			id, tostring(st.appointed), tonumber(st.interest) or 0, tostring(st.interestState),
			tostring(prop.ready), tostring(prop.offered), tostring(prop.approved), tostring(st.follyEnabled))
	end
	local events = snap.events or {}
	lines[#lines + 1] = zh and "最近事件：" or "Recent events:"
	local start = math.max(1, #events - 7)
	for i = start, #events do
		local e = events[i]
		lines[#lines + 1] = string.format("  %s src=%s room=%s", tostring(e.kind), tostring(e.source), tostring(e.room))
	end
	lines[#lines + 1] = (zh and "当前链：" or "Chain: ")..tostring(snap.chain)
	return table.concat(lines, "\n")
end

local function add_zeiz_hub_group(parent_id)
	local group = add_group(parent_id, "QingRemasterOptions_GroupZeizHub", "Zeiz Control Hub")
	add_text(group, language_key() == "zh"
		and "起点房南侧蓝色漩涡进入中枢。走近虚影看 EID 愚见，使用/胶囊/炸弹任命。中枢内漩涡返回。"
		or "Blue portal in the start room enters the hub. Walk up to a phantom for EID Folly; Use/Pill/Bomb appoints. Hub portal returns.")
	local status_id = "QingRemasterOptions_ZeizStatus"
	ImGui.AddElement(group, status_id, ImGuiElement.TextWrapped, zeiz_status_text())
	ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
		ImGui.UpdateText(status_id, zeiz_status_text())
	end)
	local function core()
		local mod = zeiz_mod()
		return mod and mod.api
	end
	ImGui.AddButton(group, "QingRemasterOptions_ZeizForceHub", "Force Enter Hub", function()
		local c = core()
		if c then c.hub.open() end
	end)
	ImGui.AddButton(group, "QingRemasterOptions_ZeizAppointCain", "Appoint Cain", function()
		local c = core()
		if c then c.admins.appoint("CAIN") end
	end)
	ImGui.AddButton(group, "QingRemasterOptions_ZeizAppointKeeper", "Appoint Keeper", function()
		local c = core()
		if c then c.admins.appoint("KEEPER") end
	end)
	ImGui.AddButton(group, "QingRemasterOptions_ZeizEmitLock", "Emit LOCK", function()
		local c = core()
		if c then
			c.events.emit("LOCK", { source = "DEBUG", targetId = "dbg"..tostring(Game():GetFrameCount()) })
		end
	end)
	ImGui.AddButton(group, "QingRemasterOptions_ZeizAddInterest", "+1 Keeper Interest", function()
		local c = core()
		if c then c.interest.add("KEEPER", 1) end
	end)
	ImGui.AddButton(group, "QingRemasterOptions_ZeizReadyProposal", "Ready Keeper Proposal", function()
		local c = core()
		if c then c.proposal.force_ready("KEEPER") end
	end)
	ImGui.AddButton(group, "QingRemasterOptions_ZeizToggleCainFolly", "Toggle Cain Folly", function()
		local c = core()
		if not c then return end
		local st = c.admins.state("CAIN")
		c.folly.set_enabled("CAIN", not (st and st.follyEnabled))
	end)
	ImGui.AddButton(group, "QingRemasterOptions_ZeizClearAdmins", "Clear Administrators", function()
		local c = core()
		if c then c.admins.clear_all() end
	end)
	ImGui.AddButton(group, "QingRemasterOptions_ZeizReset", "Reset Zeiz Run State", function()
		local c = core()
		if c then
			c.save.reset()
			c.admins.ensure_all()
		end
	end)
end

local function add_drama_group(parent_id)
	local group = add_group(parent_id, "QingRemasterOptions_GroupDrama", "悲欢之凶剧")
	add_text(group, "15% 面具泪固定交替悲剧/喜剧。调试用：强制每次眼泪都转化，方便打出凶剧。")
	add_checkbox(group, "QingRemasterOptions_DramaForceMask", "强制转化面具眼泪", {"QingRemasterOptions", "Debug", "DramaForceMask"}, "开启后仍按交替顺序发悲剧/喜剧，只是不再掷 15%。")
	ImGui.AddButton(group, "QingRemasterOptions_DramaRestoreDefaults", text("restore_item_defaults"), function()
		item.set_value({"QingRemasterOptions", "Debug", "DramaForceMask"}, false)
	end)
end

local function add_mental_group(parent_id)
	local group = add_group(parent_id, "QingRemasterOptions_GroupMental", "精神失序")
	add_text(group, "进房 25% 错认掉落物/敌人/已有被动。调试用：强制每次进房都发生错认。")
	add_checkbox(group, "QingRemasterOptions_MentalForceError", "强制发生错认", {"QingRemasterOptions", "Debug", "MentalForceError"}, "开启后进入新房间必定错认（仍按权重在掉落物/敌人/道具间选择）。")
	ImGui.AddButton(group, "QingRemasterOptions_MentalRestoreDefaults", text("restore_item_defaults"), function()
		item.set_value({"QingRemasterOptions", "Debug", "MentalForceError"}, false)
	end)
end

local function add_book_of_thoth_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupBookOfThoth",text("group_book_of_thoth"))
	add_text(group,text("book_of_thoth_help"))
	add_checkbox(group,"QingRemasterOptions_BookOfThothForceSeija",text("book_of_thoth_seija"),{"QingRemasterOptions","Debug","BookOfThothForceSeija"},text("book_of_thoth_seija_help"))
	add_drag_float(group,"QingRemasterOptions_BookOfThothDivineSplit",text("book_of_thoth_divine_split"),{"QingRemasterOptions","Debug","BookOfThothDivineSplit"},text("book_of_thoth_divine_split_help"),0.01,0.2,0.8,"%.2f")
	add_drag_float(group,"QingRemasterOptions_BookOfThothConfirmY",text("book_of_thoth_confirm_y"),{"QingRemasterOptions","Debug","BookOfThothConfirmY"},text("book_of_thoth_confirm_y_help"),0.25,-80,80,"%.1f")
	add_drag_float(group,"QingRemasterOptions_BookOfThothDotOffsetX",text("book_of_thoth_dot_x"),{"QingRemasterOptions","Debug","BookOfThothDotOffsetX"},text("book_of_thoth_dot_help"),0.25,-40,40,"%.2f")
	add_drag_float(group,"QingRemasterOptions_BookOfThothDotOffsetY",text("book_of_thoth_dot_y"),{"QingRemasterOptions","Debug","BookOfThothDotOffsetY"},text("book_of_thoth_dot_help"),0.25,-40,40,"%.2f")
	ImGui.AddButton(group,"QingRemasterOptions_BookOfThothRestoreDefaults",text("restore_item_defaults"),function()
		item.set_value({"QingRemasterOptions","Debug","BookOfThothForceSeija"},false)
		item.set_value({"QingRemasterOptions","Debug","BookOfThothDivineSplit"},0.4)
		item.set_value({"QingRemasterOptions","Debug","BookOfThothConfirmY"},0)
		item.set_value({"QingRemasterOptions","Debug","BookOfThothDotOffsetX"},0)
		item.set_value({"QingRemasterOptions","Debug","BookOfThothDotOffsetY"},-11)
	end)
end

local function add_glaze_crown_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupGlazeCrown",text("group_glaze_crown"))
	add_text(group,text("glaze_crown_help"))
	add_checkbox(group,"QingRemasterOptions_GlazeCrownForceSeija",text("glaze_crown_seija"),{"QingRemasterOptions","Debug","GlazeCrownForceSeija"},text("glaze_crown_seija_help"))
	ImGui.AddButton(group,"QingRemasterOptions_GlazeCrownRestoreDefaults",text("restore_item_defaults"),function()
		item.set_value({"QingRemasterOptions","Debug","GlazeCrownForceSeija"},false)
	end)
end

local function add_golden_slot_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupGoldenSlot",text("group_golden_slot"))
	add_text(group,text("golden_slot_help"))
	local golden_slot = require("Qing_Remaster_scripts.items.Item_Golden_Slot")
	local cost_id = "QingRemasterOptions_GoldenSlotCost"
	ImGui.AddDragFloat(group,cost_id,text("golden_slot_cost"),function(value)
		golden_slot.set_cost(value)
	end,golden_slot.get_cost(),1,1,999,"%.0f")
	ImGui.AddCallback(cost_id,ImGuiCallback.Render,function()
		ImGui.UpdateData(cost_id,ImGuiData.Value,golden_slot.get_cost())
	end)
	ImGui.SetHelpmarker(cost_id,text("golden_slot_cost_help"))
	add_drag_float(group,"QingRemasterOptions_GoldenSlotWeightMidasFly",text("golden_slot_w_fly"),{"QingRemasterOptions","Debug","GoldenSlotWeightMidasFly"},nil,1,0,1000,"%.0f")
	add_drag_float(group,"QingRemasterOptions_GoldenSlotWeightGoldTroll",text("golden_slot_w_troll"),{"QingRemasterOptions","Debug","GoldenSlotWeightGoldTroll"},nil,1,0,1000,"%.0f")
	add_drag_float(group,"QingRemasterOptions_GoldenSlotWeightGoldCoin",text("golden_slot_w_coin"),{"QingRemasterOptions","Debug","GoldenSlotWeightGoldCoin"},nil,1,0,1000,"%.0f")
	add_drag_float(group,"QingRemasterOptions_GoldenSlotWeightGoldBomb",text("golden_slot_w_bomb"),{"QingRemasterOptions","Debug","GoldenSlotWeightGoldBomb"},nil,1,0,1000,"%.0f")
	add_drag_float(group,"QingRemasterOptions_GoldenSlotWeightGoldHeart",text("golden_slot_w_heart"),{"QingRemasterOptions","Debug","GoldenSlotWeightGoldHeart"},nil,1,0,1000,"%.0f")
	add_drag_float(group,"QingRemasterOptions_GoldenSlotWeightGoldKey",text("golden_slot_w_key"),{"QingRemasterOptions","Debug","GoldenSlotWeightGoldKey"},nil,1,0,1000,"%.0f")
	add_drag_float(group,"QingRemasterOptions_GoldenSlotWeightGoldBattery",text("golden_slot_w_battery"),{"QingRemasterOptions","Debug","GoldenSlotWeightGoldBattery"},nil,1,0,1000,"%.0f")
	add_drag_float(group,"QingRemasterOptions_GoldenSlotWeightGoldPill",text("golden_slot_w_pill"),{"QingRemasterOptions","Debug","GoldenSlotWeightGoldPill"},nil,1,0,1000,"%.0f")
	add_drag_float(group,"QingRemasterOptions_GoldenSlotWeightGoldMegaPill",text("golden_slot_w_mega_pill"),{"QingRemasterOptions","Debug","GoldenSlotWeightGoldMegaPill"},nil,1,0,1000,"%.0f")
	add_drag_float(group,"QingRemasterOptions_GoldenSlotWeightGoldTrinket",text("golden_slot_w_trinket"),{"QingRemasterOptions","Debug","GoldenSlotWeightGoldTrinket"},nil,1,0,1000,"%.0f")
	add_drag_float(group,"QingRemasterOptions_GoldenSlotWeightEnding",text("golden_slot_w_ending"),{"QingRemasterOptions","Debug","GoldenSlotWeightEnding"},nil,1,0,1000,"%.0f")
	add_drag_float(group,"QingRemasterOptions_GoldenSlotCoinOffsetX",text("golden_slot_coin_x"),{"QingRemasterOptions","Debug","GoldenSlotCoinOffsetX"},text("golden_slot_coin_x_help"),0.25,-64,64,"%.2f")
	add_drag_float(group,"QingRemasterOptions_GoldenSlotCoinOffsetY",text("golden_slot_coin_y"),{"QingRemasterOptions","Debug","GoldenSlotCoinOffsetY"},text("golden_slot_coin_y_help"),0.25,-64,64,"%.2f")
	add_drag_float(group,"QingRemasterOptions_GoldenSlotCoinScale",text("golden_slot_coin_scale"),{"QingRemasterOptions","Debug","GoldenSlotCoinScale"},nil,0.01,0.05,2,"%.2f")
	ImGui.AddButton(group,"QingRemasterOptions_GoldenSlotRestoreDefaults",text("restore_item_defaults"),function()
		local defaults = {
			GoldenSlotCost = 1,
			GoldenSlotWeightMidasFly = 20,
			GoldenSlotWeightGoldTroll = 10,
			GoldenSlotWeightGoldCoin = 32,
			GoldenSlotWeightGoldBomb = 36,
			GoldenSlotWeightGoldHeart = 26,
			GoldenSlotWeightGoldKey = 28,
			GoldenSlotWeightGoldBattery = 18,
			GoldenSlotWeightGoldPill = 18,
			GoldenSlotWeightGoldMegaPill = 10,
			GoldenSlotWeightGoldTrinket = 14,
			GoldenSlotWeightEnding = 1,
			GoldenSlotCoinOffsetX = 4.5,
			GoldenSlotCoinOffsetY = -6.25,
			GoldenSlotCoinScale = 0.5,
		}
		for key,value in pairs(defaults) do item.set_value({"QingRemasterOptions","Debug",key},value) end
		golden_slot.set_cost(1)
	end)
end

local function add_remaster_flip_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupRemasterFlip",text("group_remaster"))
	add_text(group,text("remaster_help"))
	add_drag_float(group,"QingRemasterOptions_RemasterCodeFlipSpacing",text("remaster_flip_spacing"),{"QingRemasterOptions","Debug","RemasterCodeFlipSpacing"},text("remaster_flip_spacing_help"),0.25,0.5,24,"%.2f")
	ImGui.AddButton(group,"QingRemasterOptions_RemasterRestoreDefaults",text("restore_item_defaults"),function()
		item.set_value({"QingRemasterOptions","Debug","RemasterCodeFlipSpacing"},4)
	end)
end

local function add_remaster_channels_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupRemasterChannels",text("group_remaster"))
	local remaster = require("Qing_Remaster_scripts.items.Item_Remaster")
	item.remaster_debug = item.remaster_debug or {
		from_command = "1",
		to_command = "5c",
		selected_index = 1,
		options = {text("remaster_channel_empty")},
	}
	local dbg = item.remaster_debug

	local function refresh_channel_options()
		local list = remaster.get_channels() or {}
		dbg.options = {}
		if #list == 0 then
			dbg.options[1] = text("remaster_channel_empty")
			dbg.selected_index = 1
		else
			for i, ch in ipairs(list) do
				dbg.options[i] = remaster.format_channel_label(ch, i)
			end
			if dbg.selected_index < 1 or dbg.selected_index > #list then
				dbg.selected_index = 1
			end
		end
	end

	add_text(group,text("remaster_channels_help"))
	local list_id = "QingRemasterOptions_RemasterChannelList"
	ImGui.AddText(group,text("remaster_channel_list")..":\n"..text("remaster_channel_empty"),true,list_id)
	ImGui.AddCallback(list_id,ImGuiCallback.Render,function()
		refresh_channel_options()
		local list = remaster.get_channels() or {}
		local body
		if #list == 0 then
			body = text("remaster_channel_empty")
		else
			local lines = {}
			for i, ch in ipairs(list) do
				lines[#lines + 1] = remaster.format_channel_label(ch, i)
			end
			body = table.concat(lines, "\n")
		end
		ImGui.UpdateData(list_id,ImGuiData.Label,text("remaster_channel_list")..":\n"..body)
	end)

	local combo_id = "QingRemasterOptions_RemasterChannelSelect"
	refresh_channel_options()
	ImGui.AddCombobox(group,combo_id,text("remaster_channel_select"),function(index)
		dbg.selected_index = (tonumber(index) or 0) + 1
	end,dbg.options,math.max(0,dbg.selected_index - 1))
	ImGui.AddCallback(combo_id,ImGuiCallback.Render,function()
		refresh_channel_options()
		ImGui.UpdateData(combo_id,ImGuiData.ListValues,dbg.options)
		ImGui.UpdateData(combo_id,ImGuiData.Value,math.max(0,dbg.selected_index - 1))
	end)

	local from_id = "QingRemasterOptions_RemasterChannelFrom"
	ImGui.AddInputText(group,from_id,text("remaster_channel_from"),function(value)
		dbg.from_command = tostring(value or "")
	end,dbg.from_command)
	ImGui.SetHelpmarker(from_id,text("remaster_channel_from_help"))
	ImGui.AddCallback(from_id,ImGuiCallback.Render,function()
		ImGui.UpdateData(from_id,ImGuiData.Value,dbg.from_command or "")
	end)

	local to_id = "QingRemasterOptions_RemasterChannelTo"
	ImGui.AddInputText(group,to_id,text("remaster_channel_to"),function(value)
		dbg.to_command = tostring(value or "")
	end,dbg.to_command)
	ImGui.SetHelpmarker(to_id,text("remaster_channel_to_help"))
	ImGui.AddCallback(to_id,ImGuiCallback.Render,function()
		ImGui.UpdateData(to_id,ImGuiData.Value,dbg.to_command or "")
	end)

	ImGui.AddButton(group,"QingRemasterOptions_RemasterChannelFillFrom",text("remaster_channel_fill_from"),function()
		local cmd = remaster.debug_fill_from_current_floor()
		if not cmd then
			push_notice(text("start_run_first"),error_notice_type())
			return
		end
		dbg.from_command = cmd
	end)
	ImGui.AddButton(group,"QingRemasterOptions_RemasterChannelAdd",text("remaster_channel_add"),function()
		local idx, err = remaster.debug_add_channel(dbg.from_command, dbg.to_command, {armed = true})
		if not idx then
			push_notice(err == "invalid stage command" and text("remaster_channel_bad_cmd") or tostring(err),error_notice_type())
			return
		end
		dbg.selected_index = idx
		push_notice(text("remaster_channel_added"))
	end)
	ImGui.AddButton(group,"QingRemasterOptions_RemasterChannelRemove",text("remaster_channel_remove"),function()
		local list = remaster.get_channels() or {}
		if #list == 0 or not remaster.remove_channel_at(dbg.selected_index) then
			push_notice(text("remaster_channel_empty"),error_notice_type())
			return
		end
		push_notice(text("remaster_channel_removed"))
	end)
	ImGui.AddButton(group,"QingRemasterOptions_RemasterChannelClearAll",text("remaster_channel_clear_all"),function()
		remaster.clear_all_channels()
		dbg.selected_index = 1
		push_notice(text("remaster_channel_cleared"))
	end)
end

local function add_colorblind_bans_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupColorblindBans",text("group_colorblind_bans"))
	add_text(group,text("colorblind_bans_help"))
	local colorblind = require("Qing_Remaster_scripts.items.Item_Colorblindness")
	local list_id = "QingRemasterOptions_ColorblindBanList"
	ImGui.AddText(group,text("group_colorblind_bans")..":\n"..text("colorblind_bans_empty"),true,list_id)
	ImGui.AddCallback(list_id,ImGuiCallback.Render,function()
		local bans = colorblind.list_next_run_bans() or {}
		local body
		if #bans == 0 then
			body = text("colorblind_bans_empty")
		else
			local lines = {}
			for _, id in ipairs(bans) do
				local cfg = Isaac.GetItemConfig and Isaac.GetItemConfig():GetCollectible(id)
				local name = cfg and tostring(cfg.Name or "") or ""
				lines[#lines + 1] = tostring(id)..(name ~= "" and (" - "..name) or "")
			end
			body = table.concat(lines, "\n")
		end
		ImGui.UpdateData(list_id,ImGuiData.Label,text("group_colorblind_bans")..":\n"..body)
	end)
	ImGui.AddButton(group,"QingRemasterOptions_ColorblindClearBans",text("colorblind_bans_clear"),function()
		colorblind.clear_next_run_bans()
		push_notice(text("colorblind_bans_cleared"))
	end)
end

local function add_diamond_permanent_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupDiamondPermanent",text("group_diamond_permanent"))
	add_text(group,text("diamond_permanent_help"))
	local diamond = require("Qing_Remaster_scripts.items.Item_Qing_Faceted_Market_Diamond")
	local price_id = "QingRemasterOptions_DiamondPermanentShopPrice"
	ImGui.AddDragFloat(group,price_id,text("diamond_shop_price"),function(value)
		diamond.set_shop_price(value)
	end,diamond.get_shop_price(),1,0,99,"%.0f")
	ImGui.AddCallback(price_id,ImGuiCallback.Render,function()
		ImGui.UpdateData(price_id,ImGuiData.Value,diamond.get_shop_price())
	end)
	ImGui.SetHelpmarker(price_id,text("diamond_shop_price_help"))
	local sale_id = "QingRemasterOptions_DiamondPermanentLastSale"
	ImGui.AddDragFloat(group,sale_id,text("diamond_last_sale"),function(value)
		diamond.set_last_sale_price(value)
	end,diamond.get_last_sale_price(),1,0,99,"%.0f")
	ImGui.AddCallback(sale_id,ImGuiCallback.Render,function()
		ImGui.UpdateData(sale_id,ImGuiData.Value,diamond.get_last_sale_price())
	end)
	ImGui.AddButton(group,"QingRemasterOptions_DiamondPermanentRestore",text("diamond_permanent_restore"),function()
		diamond.set_shop_price(diamond.base_price or 5)
		diamond.set_last_sale_price(diamond.base_price or 5)
		push_notice(text("diamond_permanent_restore"))
	end)
end

function item.create_permanent_data_panel(parent_id)
	add_text(parent_id,text("permanent_data_help"))
	item.create_spectral_editor_panel(parent_id)
	add_remaster_channels_group(parent_id)
	add_colorblind_bans_group(parent_id)
	add_diamond_permanent_group(parent_id)
end

local function add_reserved_judgment_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupReservedJudgment",text("group_reserved_judgment"))
	add_text(group,text("reserved_judgment_help"))
	local reserved = require("Qing_Remaster_scripts.items.Item_Reserved_Judgment")
	add_drag_float(group,"QingRemasterOptions_ReservedJudgmentMarkRange",text("reserved_judgment_mark_range"),{"QingRemasterOptions","Debug","ReservedJudgmentMarkRange"},text("reserved_judgment_mark_range_help"),1,20,240,"%.0f")
	add_drag_float(group,"QingRemasterOptions_ReservedJudgmentIconOffsetX",text("reserved_judgment_icon_x"),{"QingRemasterOptions","Debug","ReservedJudgmentIconOffsetX"},nil,0.25,-64,64,"%.2f")
	add_drag_float(group,"QingRemasterOptions_ReservedJudgmentIconOffsetY",text("reserved_judgment_icon_y"),{"QingRemasterOptions","Debug","ReservedJudgmentIconOffsetY"},nil,0.25,-96,64,"%.2f")
	add_drag_float(group,"QingRemasterOptions_ReservedJudgmentIconScale",text("reserved_judgment_icon_scale"),{"QingRemasterOptions","Debug","ReservedJudgmentIconScale"},nil,0.05,0.1,3,"%.2f")
	ImGui.AddButton(group,"QingRemasterOptions_ReservedJudgmentGive",text("reserved_judgment_give_item"),function()
		if not reserved.debug_give_item() then push_notice(text("start_run_first"),error_notice_type()) end
	end)
	ImGui.AddButton(group,"QingRemasterOptions_ReservedJudgmentSpawnChoices",text("reserved_judgment_spawn_choices"),function()
		if not reserved.debug_spawn_option_choices(3) then push_notice(text("start_run_first"),error_notice_type()) end
	end)
	ImGui.AddButton(group,"QingRemasterOptions_ReservedJudgmentClearTrial",text("reserved_judgment_clear_trial"),function()
		if not reserved.debug_clear_trial() then push_notice(text("start_run_first"),error_notice_type()) end
	end)
	ImGui.AddButton(group,"QingRemasterOptions_ReservedJudgmentRestoreDefaults",text("restore_item_defaults"),function()
		local defaults = {
			ReservedJudgmentMarkRange = 90,
			ReservedJudgmentIconOffsetX = 18,
			ReservedJudgmentIconOffsetY = 22,
			ReservedJudgmentIconScale = 1,
		}
		for key,value in pairs(defaults) do item.set_value({"QingRemasterOptions","Debug",key},value) end
	end)
end

local function add_diamond_group(parent_id)
	local group = add_group(parent_id,"QingRemasterOptions_GroupDiamond",text("group_diamond"))
	add_text(group,text("diamond_help"))
	local diamond = require("Qing_Remaster_scripts.items.Item_Qing_Faceted_Market_Diamond")
	add_drag_float(group,"QingRemasterOptions_DiamondMerchantChance",text("diamond_merchant_chance"),{"QingRemasterOptions","Debug","DiamondMerchantChance"},text("diamond_merchant_chance_help"),0.01,0,1,"%.2f")
	add_text(group,text("diamond_hud_help"))
	add_drag_float(group,"QingRemasterOptions_DiamondHudBaseX",text("diamond_hud_base_x"),{"QingRemasterOptions","Debug","DiamondHudBaseOffsetX"},nil,0.5,-120,120,"%.1f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudBaseY",text("diamond_hud_base_y"),{"QingRemasterOptions","Debug","DiamondHudBaseOffsetY"},nil,0.5,-160,80,"%.1f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudIconX",text("diamond_hud_icon_x"),{"QingRemasterOptions","Debug","DiamondHudIconOffsetX"},nil,0.5,-80,80,"%.1f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudIconY",text("diamond_hud_icon_y"),{"QingRemasterOptions","Debug","DiamondHudIconOffsetY"},nil,0.5,-80,80,"%.1f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudIconScale",text("diamond_hud_icon_scale"),{"QingRemasterOptions","Debug","DiamondHudIconScale"},nil,0.01,0.1,2,"%.2f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudArrowX",text("diamond_hud_arrow_x"),{"QingRemasterOptions","Debug","DiamondHudArrowOffsetX"},nil,0.5,-80,80,"%.1f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudArrowY",text("diamond_hud_arrow_y"),{"QingRemasterOptions","Debug","DiamondHudArrowOffsetY"},nil,0.5,-80,80,"%.1f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudArrowScale",text("diamond_hud_arrow_scale"),{"QingRemasterOptions","Debug","DiamondHudArrowScale"},nil,0.05,0.2,3,"%.2f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudTensX",text("diamond_hud_tens_x"),{"QingRemasterOptions","Debug","DiamondHudDigitTensOffsetX"},nil,0.5,-80,80,"%.1f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudOnesX",text("diamond_hud_ones_x"),{"QingRemasterOptions","Debug","DiamondHudDigitOnesOffsetX"},nil,0.5,-80,80,"%.1f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudDigitY",text("diamond_hud_digit_y"),{"QingRemasterOptions","Debug","DiamondHudDigitOffsetY"},nil,0.5,-80,80,"%.1f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudDigitScale",text("diamond_hud_digit_scale"),{"QingRemasterOptions","Debug","DiamondHudDigitScale"},nil,0.05,0.2,3,"%.2f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudCentX",text("diamond_hud_cent_x"),{"QingRemasterOptions","Debug","DiamondHudCentOffsetX"},nil,0.5,-80,80,"%.1f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudCentY",text("diamond_hud_cent_y"),{"QingRemasterOptions","Debug","DiamondHudCentOffsetY"},nil,0.5,-80,80,"%.1f")
	add_drag_float(group,"QingRemasterOptions_DiamondHudCentScale",text("diamond_hud_cent_scale"),{"QingRemasterOptions","Debug","DiamondHudCentScale"},nil,0.05,0.2,3,"%.2f")
	ImGui.AddButton(group,"QingRemasterOptions_DiamondRestoreDefaults",text("restore_item_defaults"),function()
		local hud = diamond.hud_defaults
		local defaults = {
			DiamondMerchantChance = 0.5,
			DiamondHudBaseOffsetX = hud.BaseOffsetX,
			DiamondHudBaseOffsetY = hud.BaseOffsetY,
			DiamondHudIconOffsetX = hud.IconOffsetX,
			DiamondHudIconOffsetY = hud.IconOffsetY,
			DiamondHudIconScale = hud.IconScale,
			DiamondHudArrowOffsetX = hud.ArrowOffsetX,
			DiamondHudArrowOffsetY = hud.ArrowOffsetY,
			DiamondHudArrowScale = hud.ArrowScale,
			DiamondHudDigitTensOffsetX = hud.DigitTensOffsetX,
			DiamondHudDigitOnesOffsetX = hud.DigitOnesOffsetX,
			DiamondHudDigitOffsetY = hud.DigitOffsetY,
			DiamondHudDigitScale = hud.DigitScale,
			DiamondHudCentOffsetX = hud.CentOffsetX,
			DiamondHudCentOffsetY = hud.CentOffsetY,
			DiamondHudCentScale = hud.CentScale,
		}
		for key,value in pairs(defaults) do item.set_value({"QingRemasterOptions","Debug",key},value) end
	end)
end

-- ---------------------------------------------------------------------------
-- Debug tools page bucketing (imgui_debug_page_bucketing.md)
-- ---------------------------------------------------------------------------
local DEBUG_PAGE = {
	recent = "recent",
	flight = "flight",
	items = "items",
	audit = "audit",
	visual = "visual",
}
local DEBUG_RECENT_LIMIT = 6
local DEBUG_TOUCH_DEBOUNCE = 30

local debug_module_list = {}
local debug_module_by_id = {}
local debug_nav = {
	page = DEBUG_PAGE.recent,
	focus_module = nil,
}
local debug_touch_last = {}
local debug_nav_ids = {}

local function debug_game_frame()
	if Game and Game() then
		local ok, n = pcall(function() return Game():GetFrameCount() end)
		if ok and n then return n end
	end
	return 0
end

local function debug_access_store()
	item.get_settings()
	local root = save.ModConfigSettings and save.ModConfigSettings.QingRemasterOptions
	local dbg = root and root.Debug
	if type(dbg) ~= "table" then return {} end
	if type(dbg.DebugModuleAccess) ~= "table" then
		dbg.DebugModuleAccess = {}
	end
	return dbg.DebugModuleAccess
end

touch_debug_module = function(module_id, kind)
	if not module_id or not debug_module_by_id[module_id] then return end
	local frame = debug_game_frame()
	local prev = debug_touch_last[module_id]
	if prev and (frame - (prev.frame or 0)) < DEBUG_TOUCH_DEBOUNCE then
		return
	end
	debug_touch_last[module_id] = {frame = frame, kind = kind}
	local store = debug_access_store()
	local row = store[module_id]
	if type(row) ~= "table" then row = {open = 0, edit = 0, count = 0} end
	if kind == "edit" then
		row.edit = frame
	else
		row.open = frame
	end
	row.count = (tonumber(row.count) or 0) + 1
	store[module_id] = row
end

local function clear_debug_access()
	local store = debug_access_store()
	for k in pairs(store) do store[k] = nil end
	debug_touch_last = {}
	if save.SaveModData then pcall(save.SaveModData) end
end

local function register_debug_module(module_id, page, label, group_id)
	if not module_id or not group_id then return end
	if debug_module_by_id[module_id] then return end
	local entry = {
		module_id = module_id,
		page = page,
		label = label or module_id,
		group_id = group_id,
		order = #debug_module_list + 1,
	}
	debug_module_list[#debug_module_list + 1] = entry
	debug_module_by_id[module_id] = entry
	ImGui.AddCallback(group_id, ImGuiCallback.ToggledOpen, function(open)
		if open == true or open == 1 then
			touch_debug_module(module_id, "open")
		end
	end)
end

local function recent_debug_modules()
	local store = debug_access_store()
	local rows = {}
	for _, m in ipairs(debug_module_list) do
		local a = store[m.module_id]
		if type(a) == "table" then
			rows[#rows + 1] = {
				module = m,
				edit = tonumber(a.edit) or 0,
				open = tonumber(a.open) or 0,
				count = tonumber(a.count) or 0,
			}
		end
	end
	table.sort(rows, function(a, b)
		if a.edit ~= b.edit then return a.edit > b.edit end
		if a.open ~= b.open then return a.open > b.open end
		if a.count ~= b.count then return a.count > b.count end
		return a.module.order < b.module.order
	end)
	local out = {}
	for i = 1, math.min(DEBUG_RECENT_LIMIT, #rows) do
		out[i] = rows[i].module
	end
	return out
end

local function apply_debug_module_visibility()
	local page = debug_nav.page or DEBUG_PAGE.recent
	local focus = debug_nav.focus_module
	for _, m in ipairs(debug_module_list) do
		local vis = false
		if focus then
			vis = m.module_id == focus
		elseif page ~= DEBUG_PAGE.recent then
			vis = m.page == page
		end
		pcall(function() ImGui.SetVisible(m.group_id, vis) end)
	end
	local ids = debug_nav_ids
	local show_recent = (page == DEBUG_PAGE.recent) and not focus
	local show_focus = focus ~= nil
	if ids.back_id then pcall(function() ImGui.SetVisible(ids.back_id, show_focus) end) end
	if ids.goto_id then pcall(function() ImGui.SetVisible(ids.goto_id, show_focus) end) end
	if ids.focus_label then pcall(function() ImGui.SetVisible(ids.focus_label, show_focus) end) end
	if ids.recent_help then pcall(function() ImGui.SetVisible(ids.recent_help, show_recent) end) end
	if ids.recent_clear then pcall(function() ImGui.SetVisible(ids.recent_clear, show_recent) end) end
	local list = show_recent and recent_debug_modules() or {}
	if ids.recent_empty then
		pcall(function() ImGui.SetVisible(ids.recent_empty, show_recent and #list == 0) end)
	end
	if ids.recent_btns then
		for i = 1, DEBUG_RECENT_LIMIT do
			local bid = ids.recent_btns[i]
			local m = list[i]
			if bid then
				pcall(function() ImGui.SetVisible(bid, show_recent and m ~= nil) end)
			end
		end
	end
end

local function set_debug_page(page)
	debug_nav.page = page
	debug_nav.focus_module = nil
	apply_debug_module_visibility()
end

local function focus_debug_module(module_id)
	if not debug_module_by_id[module_id] then return end
	debug_nav.focus_module = module_id
	apply_debug_module_visibility()
end

local function page_label(page)
	if page == DEBUG_PAGE.flight then return text("debug_page_flight") end
	if page == DEBUG_PAGE.items then return text("debug_page_items") end
	if page == DEBUG_PAGE.audit then return text("debug_page_audit") end
	if page == DEBUG_PAGE.visual then return text("debug_page_visual") end
	return text("debug_page_recent")
end

local function build_debug_nav(tools_tab)
	local nav = "QingRemasterOptions_DebugNav"
	add_text(tools_tab, text("debug_nav_help"))
	local pages = {
		{DEBUG_PAGE.recent, "debug_page_recent"},
		{DEBUG_PAGE.flight, "debug_page_flight"},
		{DEBUG_PAGE.items, "debug_page_items"},
		{DEBUG_PAGE.audit, "debug_page_audit"},
		{DEBUG_PAGE.visual, "debug_page_visual"},
	}
	for i, row in ipairs(pages) do
		local pid, key = row[1], row[2]
		local bid = nav.."_Page_"..pid
		ImGui.AddButton(tools_tab, bid, text(key), function()
			set_debug_page(pid)
		end)
		if i < #pages then
			ImGui.AddElement(tools_tab, "", ImGuiElement.SameLine)
		end
	end

	local back_id = nav.."_BackRecent"
	local goto_id = nav.."_GotoPage"
	local focus_label = nav.."_FocusLabel"
	debug_nav_ids.back_id = back_id
	debug_nav_ids.goto_id = goto_id
	debug_nav_ids.focus_label = focus_label
	ImGui.AddButton(tools_tab, back_id, text("debug_back_recent"), function()
		debug_nav.focus_module = nil
		debug_nav.page = DEBUG_PAGE.recent
		apply_debug_module_visibility()
	end)
	ImGui.AddElement(tools_tab, "", ImGuiElement.SameLine)
	ImGui.AddButton(tools_tab, goto_id, text("debug_goto_page"), function()
		local m = debug_nav.focus_module and debug_module_by_id[debug_nav.focus_module]
		if m then
			debug_nav.page = m.page
			debug_nav.focus_module = nil
			apply_debug_module_visibility()
		end
	end)
	ImGui.AddElement(tools_tab, focus_label, ImGuiElement.TextWrapped, "")
	ImGui.AddCallback(focus_label, ImGuiCallback.Render, function()
		local m = debug_nav.focus_module and debug_module_by_id[debug_nav.focus_module]
		local body = m and (tostring(m.label).."  ["..page_label(m.page).."]") or ""
		ImGui.UpdateText(focus_label, body)
	end)

	local recent_help = nav.."_RecentHelp"
	local empty_id = nav.."_RecentEmpty"
	local clear_id = nav.."_RecentClear"
	debug_nav_ids.recent_help = recent_help
	debug_nav_ids.recent_empty = empty_id
	debug_nav_ids.recent_clear = clear_id
	ImGui.AddElement(tools_tab, recent_help, ImGuiElement.TextWrapped, text("debug_recent_help"))
	ImGui.AddElement(tools_tab, empty_id, ImGuiElement.TextWrapped, text("debug_recent_empty"))
	local recent_btn_ids = {}
	debug_nav_ids.recent_btns = recent_btn_ids
	for i = 1, DEBUG_RECENT_LIMIT do
		local bid = nav.."_RecentBtn_"..tostring(i)
		recent_btn_ids[i] = bid
		ImGui.AddButton(tools_tab, bid, "-", function()
			local list = recent_debug_modules()
			local m = list[i]
			if m then focus_debug_module(m.module_id) end
		end)
	end
	ImGui.AddButton(tools_tab, clear_id, text("debug_recent_clear"), function()
		clear_debug_access()
	end)
	ImGui.AddCallback(empty_id, ImGuiCallback.Render, function()
		local list = recent_debug_modules()
		for i = 1, DEBUG_RECENT_LIMIT do
			local m = list[i]
			local bid = recent_btn_ids[i]
			if m then
				pcall(function() ImGui.UpdateText(bid, m.label) end)
			end
		end
	end)

	local sync_id = nav.."_Sync"
	ImGui.AddElement(tools_tab, sync_id, ImGuiElement.Text, "")
	ImGui.AddCallback(sync_id, ImGuiCallback.Render, function()
		apply_debug_module_visibility()
	end)
end

local function install_debug_touch_hooks()
	local raw_btn = ImGui.AddButton
	local raw_cb = ImGui.AddCallback
	ImGui.AddButton = function(parent, id, label, cb)
		if type(cb) == "function" then
			local orig = cb
			cb = function(...)
				if debug_touch_module then touch_debug_module(debug_touch_module, "edit") end
				return orig(...)
			end
		end
		return raw_btn(parent, id, label, cb)
	end
	ImGui.AddCallback = function(id, typ, fn)
		if typ == ImGuiCallback.Edited and type(fn) == "function" then
			local orig = fn
			fn = function(...)
				if debug_touch_module then touch_debug_module(debug_touch_module, "edit") end
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

function item.create_debug_window()
	local debug_item = item.menu_id.."_DebugItem"
	local window_id = item.debug_id
	local tabbar = window_id.."_TabBar"
	local flight_tab = tabbar.."_Flight"
	local items_tab = tabbar.."_Items"
	local audit_tab = tabbar.."_Audit"
	local visual_tab = tabbar.."_Visual"
	local permanent_tab = tabbar.."_PermanentData"
	local item_colors_tab = tabbar.."_ItemColors"

	ImGui.AddElement(item.menu_id, debug_item, ImGuiElement.MenuItem, text("debug_item"))
	ImGui.CreateWindow(window_id, text("debug_title"))
	setup_window(window_id, item.default_window.debug)
	ImGui.LinkWindowToElement(window_id, debug_item)
	ImGui.AddTabBar(window_id, tabbar)
	ImGui.AddTab(tabbar, flight_tab, text("debug_page_flight"))
	ImGui.AddTab(tabbar, items_tab, text("debug_page_items"))
	ImGui.AddTab(tabbar, audit_tab, text("debug_page_audit"))
	ImGui.AddTab(tabbar, visual_tab, text("debug_page_visual"))
	ImGui.AddTab(tabbar, permanent_tab, text("tab_permanent_data"))
	ImGui.AddTab(tabbar, item_colors_tab, text("tab_item_colors"))

	local page_parent = {
		[DEBUG_PAGE.flight] = flight_tab,
		[DEBUG_PAGE.items] = items_tab,
		[DEBUG_PAGE.audit] = audit_tab,
		[DEBUG_PAGE.visual] = visual_tab,
	}

	local title_group = add_group(visual_tab, "QingRemasterOptions_GroupTitleMarquee", text("group_title_marquee"))
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeStartX", text("title_marquee_start_x"), {"QingRemasterOptions", "Debug", "TitleMarqueeStartX"}, text("title_marquee_help"), 1, -200, 800, "%.0f")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeEndX", text("title_marquee_end_x"), {"QingRemasterOptions", "Debug", "TitleMarqueeEndX"}, text("title_marquee_help"), 1, -200, 800, "%.0f")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeY", text("title_marquee_y"), {"QingRemasterOptions", "Debug", "TitleMarqueeY"}, nil, 1, -100, 400, "%.0f")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeSpeed", text("title_marquee_speed"), {"QingRemasterOptions", "Debug", "TitleMarqueeSpeed"}, nil, 1, 0, 240, "%.0f px/s")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeFadeWidth", text("title_marquee_fade"), {"QingRemasterOptions", "Debug", "TitleMarqueeFadeWidth"}, nil, 1, 1, 240, "%.0f px")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeLetterSpacing", text("title_marquee_spacing"), {"QingRemasterOptions", "Debug", "TitleMarqueeLetterSpacing"}, nil, 0.25, 0, 12, "%.1f px")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeRainbowSpeed", text("title_marquee_rainbow_speed"), {"QingRemasterOptions", "Debug", "TitleMarqueeRainbowSpeed"}, nil, 0.01, -2, 2, "%.2f cycle/s")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeWaveSpeed", text("title_marquee_wave_speed"), {"QingRemasterOptions", "Debug", "TitleMarqueeWaveSpeed"}, nil, 0.01, -2, 2, "%.2f cycle/s")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeEdgeIntensity", text("title_marquee_edge_intensity"), {"QingRemasterOptions", "Debug", "TitleMarqueeEdgeIntensity"}, nil, 0.05, 0, 2, "%.2f")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeEdgeWaveWidth", text("title_marquee_edge_wave_width"), {"QingRemasterOptions", "Debug", "TitleMarqueeEdgeWaveWidth"}, nil, 0.05, 0.05, 1, "%.2f")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeBounceSpeed", text("title_marquee_bounce_speed"), {"QingRemasterOptions", "Debug", "TitleMarqueeBounceSpeed"}, nil, 0.1, 0, 20, "%.2f rad/s")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeBounceTravelSpeed", text("title_marquee_bounce_travel_speed"), {"QingRemasterOptions", "Debug", "TitleMarqueeBounceTravelSpeed"}, nil, 0.25, 0.1, 60, "%.2f glyph/s")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeBounceHeight", text("title_marquee_bounce_height"), {"QingRemasterOptions", "Debug", "TitleMarqueeBounceHeight"}, nil, 0.25, 0, 20, "%.2f px")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeSquashX", text("title_marquee_squash_x"), {"QingRemasterOptions", "Debug", "TitleMarqueeSquashX"}, nil, 0.01, 0, 1, "%.2f")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeSquashY", text("title_marquee_squash_y"), {"QingRemasterOptions", "Debug", "TitleMarqueeSquashY"}, nil, 0.01, 0, 0.95, "%.2f")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeImpactSharpness", text("title_marquee_impact_sharpness"), {"QingRemasterOptions", "Debug", "TitleMarqueeImpactSharpness"}, nil, 0.25, 0.25, 16, "%.2f")
	add_drag_float(title_group, "QingRemasterOptions_TitleMarqueeTangentRotation", text("title_marquee_tangent_rotation"), {"QingRemasterOptions", "Debug", "TitleMarqueeTangentRotation"}, nil, 0.05, -3, 3, "%.2f x")
	ImGui.AddButton(title_group, "QingRemasterOptions_TitleMarqueeRestore", text("restore_item_defaults"), function()
		item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeStartX"}, 320)
		item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeEndX"}, 80)
		item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeY"}, 80)
		item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeSpeed"}, 28)
		item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeFadeWidth"}, 48)
		item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeLetterSpacing"}, 4)
		item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeRainbowSpeed"}, 0.7)
		item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeWaveSpeed"}, 0.26)
		item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeEdgeIntensity"}, 0.45)
		item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeEdgeWaveWidth"}, 0.75)
		item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeBounceSpeed"}, 2.5)
		item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeBounceTravelSpeed"}, 24)
		item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeBounceHeight"}, 9)
		item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeSquashX"}, 0.10)
		item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeSquashY"}, 0.95)
		item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeImpactSharpness"}, 6)
		item.set_value({"QingRemasterOptions", "Debug", "TitleMarqueeTangentRotation"}, 1)
	end)

	local function start_mod(module_id, page, label, group_id)
		local group = add_group(page_parent[page] or audit_tab, group_id, label)
		register_debug_module(module_id, page, label, group_id)
		return group
	end

	local lighting_group = start_mod("visual_dynamic_lighting", DEBUG_PAGE.visual, text("group_dynamic_lighting"), "QingRemasterOptions_GroupDynamicLighting")
	add_text(lighting_group, text("dynamic_lighting_help"))
	add_checkbox(lighting_group, "QingRemasterOptions_DynamicLightingEnabled", text("dynamic_lighting_enabled"), {"QingRemasterOptions", "Debug", "DynamicLightingEnabled"})
	add_drag_float(lighting_group, "QingRemasterOptions_DynamicLightingAmbient", text("dynamic_lighting_ambient"), {"QingRemasterOptions", "Debug", "DynamicLightingAmbient"}, text("dynamic_lighting_ambient_help"), 0.01, 0, 1, "%.2f")
	add_drag_float(lighting_group, "QingRemasterOptions_DynamicLightingRadius", text("dynamic_lighting_radius"), {"QingRemasterOptions", "Debug", "DynamicLightingRadius"}, nil, 5, 40, 800, "%.0f")
	add_drag_float(lighting_group, "QingRemasterOptions_DynamicLightingIntensity", text("dynamic_lighting_intensity"), {"QingRemasterOptions", "Debug", "DynamicLightingIntensity"}, nil, 0.05, 0, 3, "%.2f")
	add_drag_float(lighting_group, "QingRemasterOptions_DynamicLightingSoft", text("dynamic_lighting_soft"), {"QingRemasterOptions", "Debug", "DynamicLightingSoft"}, nil, 0.01, 0, 1, "%.2f")
	add_drag_float(lighting_group, "QingRemasterOptions_DynamicLightingColorR", text("dynamic_lighting_color_r"), {"QingRemasterOptions", "Debug", "DynamicLightingColorR"}, nil, 0.05, 0, 2, "%.2f")
	add_drag_float(lighting_group, "QingRemasterOptions_DynamicLightingColorG", text("dynamic_lighting_color_g"), {"QingRemasterOptions", "Debug", "DynamicLightingColorG"}, nil, 0.05, 0, 2, "%.2f")
	add_drag_float(lighting_group, "QingRemasterOptions_DynamicLightingColorB", text("dynamic_lighting_color_b"), {"QingRemasterOptions", "Debug", "DynamicLightingColorB"}, nil, 0.05, 0, 2, "%.2f")
	ImGui.AddButton(lighting_group, "QingRemasterOptions_DynamicLightingRestore", text("restore_item_defaults"), function()
		item.set_value({"QingRemasterOptions", "Debug", "DynamicLightingEnabled"}, false)
		item.set_value({"QingRemasterOptions", "Debug", "DynamicLightingAmbient"}, 0.03)
		item.set_value({"QingRemasterOptions", "Debug", "DynamicLightingRadius"}, 220)
		item.set_value({"QingRemasterOptions", "Debug", "DynamicLightingIntensity"}, 1.45)
		item.set_value({"QingRemasterOptions", "Debug", "DynamicLightingSoft"}, 0.18)
		item.set_value({"QingRemasterOptions", "Debug", "DynamicLightingColorR"}, 1)
		item.set_value({"QingRemasterOptions", "Debug", "DynamicLightingColorG"}, 1)
		item.set_value({"QingRemasterOptions", "Debug", "DynamicLightingColorB"}, 1)
	end)

	local torsion_group = start_mod("visual_torsion", DEBUG_PAGE.visual, text("group_torsion"), "QingRemasterOptions_GroupTorsion")
	add_text(torsion_group, text("torsion_help"))
	add_drag_float(torsion_group, "QingRemasterOptions_TorsionDemoPeak", text("torsion_peak"), {"QingRemasterOptions", "Debug", "TorsionDemoPeak"}, nil, 0.002, 0.01, 0.14, "%.3f")
	add_drag_float(torsion_group, "QingRemasterOptions_TorsionDemoStretch", text("torsion_stretch"), {"QingRemasterOptions", "Debug", "TorsionDemoStretch"}, nil, 0.002, 0.0, 0.14, "%.3f")
	add_drag_float(torsion_group, "QingRemasterOptions_TorsionDemoSlideAng", text("torsion_slide_ang"), {"QingRemasterOptions", "Debug", "TorsionDemoSlideAng"}, nil, 1, -90, 90, "%.0f")
	add_drag_float(torsion_group, "QingRemasterOptions_TorsionDemoSegHalfPx", text("torsion_seg_half"), {"QingRemasterOptions", "Debug", "TorsionDemoSegHalfPx"}, nil, 5, 20, 400, "%.0f")
	add_drag_float(torsion_group, "QingRemasterOptions_TorsionDemoTotal", text("torsion_total"), {"QingRemasterOptions", "Debug", "TorsionDemoTotal"}, nil, 1, 10, 180, "%.0f")
	add_drag_float(torsion_group, "QingRemasterOptions_TorsionDemoHold", text("torsion_hold"), {"QingRemasterOptions", "Debug", "TorsionDemoHold"}, nil, 1, 0, 40, "%.0f")
	add_drag_float(torsion_group, "QingRemasterOptions_TorsionDemoAngle", text("torsion_angle"), {"QingRemasterOptions", "Debug", "TorsionDemoAngle"}, nil, 1, -1, 180, "%.0f")
	add_drag_float(torsion_group, "QingRemasterOptions_TorsionDemoGap", text("torsion_gap"), {"QingRemasterOptions", "Debug", "TorsionDemoGap"}, nil, 0.0001, 0.0001, 0.02, "%.4f")
	add_drag_float(torsion_group, "QingRemasterOptions_TorsionDemoSoft", text("torsion_soft"), {"QingRemasterOptions", "Debug", "TorsionDemoSoft"}, nil, 0.001, 0.002, 0.12, "%.3f")
	add_drag_float(torsion_group, "QingRemasterOptions_TorsionDemoBandPx", text("torsion_band"), {"QingRemasterOptions", "Debug", "TorsionDemoBandPx"}, nil, 2, 8, 200, "%.0f")
	ImGui.AddButton(torsion_group, "QingRemasterOptions_TorsionTrigger", text("torsion_trigger"), function()
		local Shader_holder = require("Qing_Remaster_scripts.others.Shader_holder")
		local dbg = save.ModConfigSettings and save.ModConfigSettings.QingRemasterOptions and save.ModConfigSettings.QingRemasterOptions.Debug
		local angle = dbg and tonumber(dbg.TorsionDemoAngle) or -1
		if angle ~= nil and angle < 0 then angle = nil end
		Shader_holder.Trigger_demo({
			peak = dbg and tonumber(dbg.TorsionDemoPeak) or 0.1,
			stretch = dbg and tonumber(dbg.TorsionDemoStretch) or 0.07,
			slide_ang_deg = dbg and tonumber(dbg.TorsionDemoSlideAng) or 28,
			seg_half_px = dbg and tonumber(dbg.TorsionDemoSegHalfPx) or 90,
			total = dbg and tonumber(dbg.TorsionDemoTotal) or 60,
			hold = dbg and tonumber(dbg.TorsionDemoHold) or 5,
			angle_deg = angle,
			gap = dbg and tonumber(dbg.TorsionDemoGap) or 0.00025,
			soft = dbg and tonumber(dbg.TorsionDemoSoft) or 0.042,
			band_px = dbg and tonumber(dbg.TorsionDemoBandPx) or 70,
		})
	end)
	ImGui.AddButton(torsion_group, "QingRemasterOptions_TorsionRestore", text("restore_item_defaults"), function()
		item.set_value({"QingRemasterOptions", "Debug", "TorsionDemoPeak"}, 0.1)
		item.set_value({"QingRemasterOptions", "Debug", "TorsionDemoStretch"}, 0.07)
		item.set_value({"QingRemasterOptions", "Debug", "TorsionDemoSlideAng"}, 28)
		item.set_value({"QingRemasterOptions", "Debug", "TorsionDemoSegHalfPx"}, 90)
		item.set_value({"QingRemasterOptions", "Debug", "TorsionDemoTotal"}, 60)
		item.set_value({"QingRemasterOptions", "Debug", "TorsionDemoHold"}, 5)
		item.set_value({"QingRemasterOptions", "Debug", "TorsionDemoAngle"}, -1)
		item.set_value({"QingRemasterOptions", "Debug", "TorsionDemoGap"}, 0.00025)
		item.set_value({"QingRemasterOptions", "Debug", "TorsionDemoSoft"}, 0.042)
		item.set_value({"QingRemasterOptions", "Debug", "TorsionDemoBandPx"}, 70)
	end)

	local anna_torsion_group = start_mod("visual_anna_torsion", DEBUG_PAGE.visual, text("group_anna_torsion"), "QingRemasterOptions_GroupAnnaTorsion")
	add_text(anna_torsion_group, text("anna_torsion_help"))
	add_drag_float(anna_torsion_group, "QingRemasterOptions_AnnaTorsionPeak", text("anna_torsion_peak"), {"QingRemasterOptions", "Debug", "AnnaTorsionPeak"}, nil, 0.002, 0.01, 0.14, "%.3f")
	add_drag_float(anna_torsion_group, "QingRemasterOptions_AnnaTorsionStretchRatio", text("anna_torsion_stretch_ratio"), {"QingRemasterOptions", "Debug", "AnnaTorsionStretchRatio"}, nil, 0.05, 0.0, 2.0, "%.2f")
	add_drag_float(anna_torsion_group, "QingRemasterOptions_AnnaTorsionSlideAng", text("anna_torsion_slide_ang"), {"QingRemasterOptions", "Debug", "AnnaTorsionSlideAng"}, nil, 1, -90, 90, "%.0f")
	add_drag_float(anna_torsion_group, "QingRemasterOptions_AnnaTorsionGap", text("anna_torsion_gap"), {"QingRemasterOptions", "Debug", "AnnaTorsionGap"}, nil, 0.0001, 0.0001, 0.02, "%.4f")
	add_drag_float(anna_torsion_group, "QingRemasterOptions_AnnaTorsionSoft", text("anna_torsion_soft"), {"QingRemasterOptions", "Debug", "AnnaTorsionSoft"}, nil, 0.001, 0.002, 0.12, "%.3f")
	add_drag_float(anna_torsion_group, "QingRemasterOptions_AnnaTorsionBandPx", text("anna_torsion_band"), {"QingRemasterOptions", "Debug", "AnnaTorsionBandPx"}, nil, 2, 8, 160, "%.0f")
	add_drag_float(anna_torsion_group, "QingRemasterOptions_AnnaTorsionTotal", text("anna_torsion_total"), {"QingRemasterOptions", "Debug", "AnnaTorsionTotal"}, nil, 1, 4, 60, "%.0f")
	add_drag_float(anna_torsion_group, "QingRemasterOptions_AnnaTorsionHold", text("anna_torsion_hold"), {"QingRemasterOptions", "Debug", "AnnaTorsionHold"}, nil, 1, 0, 20, "%.0f")
	add_drag_float(anna_torsion_group, "QingRemasterOptions_AnnaTorsionFrame", text("anna_torsion_frame"), {"QingRemasterOptions", "Debug", "AnnaTorsionFrame"}, nil, 1, 1, 20, "%.0f")
	ImGui.AddButton(anna_torsion_group, "QingRemasterOptions_AnnaTorsionRestore", text("restore_item_defaults"), function()
		item.set_value({"QingRemasterOptions", "Debug", "AnnaTorsionPeak"}, 0.1)
		item.set_value({"QingRemasterOptions", "Debug", "AnnaTorsionStretchRatio"}, 0.7)
		item.set_value({"QingRemasterOptions", "Debug", "AnnaTorsionSlideAng"}, 28)
		item.set_value({"QingRemasterOptions", "Debug", "AnnaTorsionGap"}, 0.0002)
		item.set_value({"QingRemasterOptions", "Debug", "AnnaTorsionSoft"}, 0.045)
		item.set_value({"QingRemasterOptions", "Debug", "AnnaTorsionBandPx"}, 52)
		item.set_value({"QingRemasterOptions", "Debug", "AnnaTorsionTotal"}, 14)
		item.set_value({"QingRemasterOptions", "Debug", "AnnaTorsionHold"}, 2)
		item.set_value({"QingRemasterOptions", "Debug", "AnnaTorsionFrame"}, 5)
	end)

	local theseus_group = start_mod("visual_theseus", DEBUG_PAGE.visual, text("group_theseus_notice"), "QingRemasterOptions_GroupTheseusNotice")
	add_checkbox(theseus_group, "QingRemasterOptions_TheseusNoticeAlwaysShow", text("theseus_always_show"), {"QingRemasterOptions", "Debug", "TheseusNoticeAlwaysShow"}, text("theseus_always_show_help"))
	add_drag_float(theseus_group, "QingRemasterOptions_TheseusNoticeSourceY", text("theseus_source_y"), {"QingRemasterOptions", "Debug", "TheseusNoticeSourceY"})
	add_drag_float(theseus_group, "QingRemasterOptions_TheseusNoticeColonY", text("theseus_colon_y"), {"QingRemasterOptions", "Debug", "TheseusNoticeColonY"})
	add_drag_float(theseus_group, "QingRemasterOptions_TheseusNoticeAmountY", text("theseus_amount_y"), {"QingRemasterOptions", "Debug", "TheseusNoticeAmountY"})
	add_drag_float(theseus_group, "QingRemasterOptions_TheseusNoticeTriggerY", text("theseus_trigger_y"), {"QingRemasterOptions", "Debug", "TheseusNoticeTriggerY"})
	add_drag_float(theseus_group, "QingRemasterOptions_TheseusNoticeArrowY", text("theseus_arrow_y"), {"QingRemasterOptions", "Debug", "TheseusNoticeArrowY"})
	add_drag_float(theseus_group, "QingRemasterOptions_TheseusNoticeActionY", text("theseus_action_y"), {"QingRemasterOptions", "Debug", "TheseusNoticeActionY"})
	add_drag_float(theseus_group, "QingRemasterOptions_TheseusNoticeSourceScale", text("theseus_source_scale"), {"QingRemasterOptions", "Debug", "TheseusNoticeSourceScale"}, nil, 0.01, 0.2, 1.2)
	add_drag_float(theseus_group, "QingRemasterOptions_TheseusNoticeColonScale", text("theseus_colon_scale"), {"QingRemasterOptions", "Debug", "TheseusNoticeColonScale"}, nil, 0.05, 0.5, 2)
	add_drag_float(theseus_group, "QingRemasterOptions_TheseusNoticeAmountScale", text("theseus_amount_scale"), {"QingRemasterOptions", "Debug", "TheseusNoticeAmountScale"}, nil, 0.05, 0.5, 2)
	add_drag_float(theseus_group, "QingRemasterOptions_TheseusNoticeTriggerScale", text("theseus_trigger_scale"), {"QingRemasterOptions", "Debug", "TheseusNoticeTriggerScale"}, nil, 0.01, 0.2, 1.2)
	add_drag_float(theseus_group, "QingRemasterOptions_TheseusNoticeArrowScale", text("theseus_arrow_scale"), {"QingRemasterOptions", "Debug", "TheseusNoticeArrowScale"}, nil, 0.05, 0.5, 2)
	add_drag_float(theseus_group, "QingRemasterOptions_TheseusNoticeActionScale", text("theseus_action_scale"), {"QingRemasterOptions", "Debug", "TheseusNoticeActionScale"}, nil, 0.01, 0.2, 1.2)
	local super_bombs_group = start_mod("item_super_bombs", DEBUG_PAGE.items, text("group_super_bombs"), "QingRemasterOptions_GroupSuperBombs")
	add_drag_float(super_bombs_group, "QingRemasterOptions_SuperBombsBombGrowthSeconds", text("super_bombs_bomb_seconds"), {"QingRemasterOptions", "Debug", "SuperBombsBombGrowthSeconds"}, text("super_bombs_bomb_seconds_help"), 1, 1, 120, "%.0f s")
	add_drag_float(super_bombs_group, "QingRemasterOptions_SuperBombsMamaGrowthSeconds", text("super_bombs_mama_seconds"), {"QingRemasterOptions", "Debug", "SuperBombsMamaGrowthSeconds"}, text("super_bombs_mama_seconds_help"), 1, 1, 600, "%.0f s")
	add_drag_float(super_bombs_group, "QingRemasterOptions_SuperBombsTimerX", text("super_bombs_timer_x"), {"QingRemasterOptions", "Debug", "SuperBombsTimerX"}, text("super_bombs_timer_x_help"), 0.25, -100, 100)
	add_drag_float(super_bombs_group, "QingRemasterOptions_SuperBombsTimerY", text("super_bombs_timer_y"), {"QingRemasterOptions", "Debug", "SuperBombsTimerY"}, text("super_bombs_timer_y_help"), 0.25, -100, 100)
	local seeker_wall_probe_group = start_mod("item_seeker_wall_probe", DEBUG_PAGE.items, text("group_seeker_wall_probe"), "QingRemasterOptions_GroupSeekerWallProbe")
	do
		local status_id = "QingRemasterOptions_SeekerWallProbeStatus"
		local function seeker_mod()
			local ok, mod = pcall(require, "Qing_Remaster_scripts.items.Item_Seeker_s_Eye")
			if ok then return mod end
			return nil
		end
		local function refresh_status()
			local mod = seeker_mod()
			local body = (mod and mod.get_wall_probe_summary and mod.get_wall_probe_summary()) or text("seeker_wall_probe_status")
			ImGui.UpdateText(status_id, body)
		end
		add_text(seeker_wall_probe_group, text("seeker_wall_probe_help"))
		ImGui.AddElement(seeker_wall_probe_group, status_id, ImGuiElement.TextWrapped, text("seeker_wall_probe_status"))
		local enable_id = "QingRemasterOptions_SeekerWallProbeEnable"
		ImGui.AddCheckbox(seeker_wall_probe_group, enable_id, text("seeker_wall_probe_enable"), nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local mod = seeker_mod()
			local on = mod and mod.wall_probe_enabled == true
			ImGui.UpdateData(enable_id, ImGuiData.Value, on == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local mod = seeker_mod()
			if mod and mod.set_wall_probe_enabled then mod.set_wall_probe_enabled(value == true) end
			refresh_status()
		end)
		ImGui.AddButton(seeker_wall_probe_group, "QingRemasterOptions_SeekerWallProbeRefresh", text("seeker_wall_probe_export"), refresh_status)
		ImGui.AddButton(seeker_wall_probe_group, "QingRemasterOptions_SeekerWallProbeClear", text("seeker_wall_probe_clear"), function()
			local mod = seeker_mod()
			if mod and mod.clear_wall_probe then mod.clear_wall_probe() end
			refresh_status()
		end)
		ImGui.AddButton(seeker_wall_probe_group, "QingRemasterOptions_SeekerWallProbeRestore", text("restore_item_defaults"), function()
			local mod = seeker_mod()
			if mod and mod.set_wall_probe_enabled then mod.set_wall_probe_enabled(false) end
			if mod and mod.clear_wall_probe then mod.clear_wall_probe() end
			refresh_status()
		end)
	end
	local blue_print_group = start_mod("flight_blueprint", DEBUG_PAGE.flight, text("group_blue_print"), "QingRemasterOptions_GroupBluePrint")
	add_drag_float(blue_print_group, "QingRemasterOptions_BlueprintDotOffsetX", text("blueprint_dot_x"), {"QingRemasterOptions", "Debug", "BlueprintDotOffsetX"}, text("blueprint_dot_help"), 0.25, -40, 40)
	add_drag_float(blue_print_group, "QingRemasterOptions_BlueprintDotOffsetY", text("blueprint_dot_y"), {"QingRemasterOptions", "Debug", "BlueprintDotOffsetY"}, text("blueprint_dot_help"), 0.25, -40, 40)
	add_drag_float(blue_print_group, "QingRemasterOptions_BlueprintBgOffsetX", text("blueprint_bg_x"), {"QingRemasterOptions", "Debug", "BlueprintBgOffsetX"}, text("blueprint_bg_help"), 0.25, -80, 80)
	add_drag_float(blue_print_group, "QingRemasterOptions_BlueprintBgOffsetY", text("blueprint_bg_y"), {"QingRemasterOptions", "Debug", "BlueprintBgOffsetY"}, text("blueprint_bg_help"), 0.25, -80, 80)
	add_drag_float(blue_print_group, "QingRemasterOptions_BlueprintAuditTextY", text("blueprint_audit_y"), {"QingRemasterOptions", "Debug", "BlueprintAuditTextY"}, text("blueprint_audit_y_help"), 0.5, -40, 80)
	add_drag_float(blue_print_group, "QingRemasterOptions_BlueprintSlotCount", text("blueprint_slot_count"), {"QingRemasterOptions", "Debug", "BlueprintSlotCount"}, text("blueprint_slot_count_help"), 1, 1, 7, "%.0f")
	add_drag_float(blue_print_group, "QingRemasterOptions_BlueprintCostOffsetY", text("blueprint_cost_y"), {"QingRemasterOptions", "Debug", "BlueprintCostOffsetY"}, text("blueprint_cost_y_help"), 0.5, -20, 80)
	add_drag_float(blue_print_group, "QingRemasterOptions_BlueprintCostExtraCount", text("blueprint_cost_extra"), {"QingRemasterOptions", "Debug", "BlueprintCostExtraCount"}, text("blueprint_cost_extra_help"), 1, 0, 12, "%.0f")
	add_drag_float(blue_print_group, "QingRemasterOptions_BlueprintCostSlotSize", text("blueprint_cost_slot_size"), {"QingRemasterOptions", "Debug", "BlueprintCostSlotSize"}, text("blueprint_cost_slot_size_help"), 1, 8, 48, "%.0f")
	add_drag_float(blue_print_group, "QingRemasterOptions_BlueprintCostTokenScale", text("blueprint_cost_scale"), {"QingRemasterOptions", "Debug", "BlueprintCostTokenScale"}, text("blueprint_cost_scale_help"), 0.05, 0.15, 1.2)
	add_drag_float(blue_print_group, "QingRemasterOptions_BlueprintCostQmarkOffsetX", text("blueprint_cost_qmark_x"), {"QingRemasterOptions", "Debug", "BlueprintCostQmarkOffsetX"}, text("blueprint_cost_qmark_help"), 0.25, -20, 20)
	add_drag_float(blue_print_group, "QingRemasterOptions_BlueprintCostQmarkOffsetY", text("blueprint_cost_qmark_y"), {"QingRemasterOptions", "Debug", "BlueprintCostQmarkOffsetY"}, text("blueprint_cost_qmark_help"), 0.25, -20, 20)
	add_drag_float(blue_print_group, "QingRemasterOptions_BlueprintCraftGroupY", text("blueprint_craft_group_y"), {"QingRemasterOptions", "Debug", "BlueprintCraftGroupY"}, text("blueprint_craft_group_y_help"), 0.5, -60, 80)
	add_drag_float(blue_print_group, "QingRemasterOptions_BlueprintTagColOffsetX", text("blueprint_tag_col_x"), {"QingRemasterOptions", "Debug", "BlueprintTagColOffsetX"}, text("blueprint_tag_col_help"), 0.5, -120, 80)
	add_drag_float(blue_print_group, "QingRemasterOptions_BlueprintTagColOffsetY", text("blueprint_tag_col_y"), {"QingRemasterOptions", "Debug", "BlueprintTagColOffsetY"}, text("blueprint_tag_col_help"), 0.5, -40, 80)
	add_drag_float(blue_print_group, "QingRemasterOptions_BlueprintTagColWidth", text("blueprint_tag_col_w"), {"QingRemasterOptions", "Debug", "BlueprintTagColWidth"}, text("blueprint_tag_col_w_help"), 1, 40, 96, "%.0f")
	add_checkbox(blue_print_group, "QingRemasterOptions_BlueprintShowSourceMarks", text("blueprint_show_source_marks"), {"QingRemasterOptions", "Debug", "BlueprintShowSourceMarks"}, text("blueprint_show_source_marks_help"))
	add_text(blue_print_group, text("blueprint_tutorial_help"))
	local tut_status_id = "QingRemasterOptions_BlueprintTutorialStatus"
	ImGui.AddElement(blue_print_group, tut_status_id, ImGuiElement.TextWrapped, text("blueprint_tutorial_status"))
	ImGui.AddCallback(tut_status_id, ImGuiCallback.Render, function()
		local ok, tut = pcall(require, "Qing_Remaster_scripts.others.blueprint_tutorial")
		local body = (ok and tut and tut.status_text and tut.status_text()) or text("blueprint_tutorial_status")
		ImGui.UpdateText(tut_status_id, body)
	end)
	local function tut_player()
		local n = Game():GetNumPlayers()
		if not n or n < 1 then return Isaac.GetPlayer(0) end
		for i = 0, n - 1 do
			local p = Game():GetPlayer(i)
			if p and p:GetPlayerType() == enums.Players.Spwq then return p end
		end
		return Isaac.GetPlayer(0)
	end
	ImGui.AddButton(blue_print_group, "QingRemasterOptions_BlueprintTutorialStart", text("blueprint_tutorial_start"), function()
		local ok, tut = pcall(require, "Qing_Remaster_scripts.others.blueprint_tutorial")
		if ok and tut and tut.start then tut.start(tut_player(), {debug = true}) end
	end)
	ImGui.AddButton(blue_print_group, "QingRemasterOptions_BlueprintTutorialStartSkip", text("blueprint_tutorial_start_skip"), function()
		local ok, tut = pcall(require, "Qing_Remaster_scripts.others.blueprint_tutorial")
		if ok and tut and tut.start then tut.start(tut_player(), {debug = true, skip_prompt = true}) end
	end)
	ImGui.AddButton(blue_print_group, "QingRemasterOptions_BlueprintTutorialAbort", text("blueprint_tutorial_abort"), function()
		local ok, tut = pcall(require, "Qing_Remaster_scripts.others.blueprint_tutorial")
		if ok and tut and tut.abort then tut.abort(tut_player()) end
	end)
	ImGui.AddButton(blue_print_group, "QingRemasterOptions_BlueprintTutorialReset", text("blueprint_tutorial_reset"), function()
		local ok, tut = pcall(require, "Qing_Remaster_scripts.others.blueprint_tutorial")
		if ok and tut and tut.reset_flags then tut.reset_flags(tut_player()) end
	end)
	ImGui.AddButton(blue_print_group, "QingRemasterOptions_BluePrintRestoreDefaults", text("restore_item_defaults"), function()
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintDotOffsetX"}, -2)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintDotOffsetY"}, -9)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintBgOffsetX"}, 0)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintBgOffsetY"}, 13)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintAuditTextY"}, 2)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintSlotCount"}, 3)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintCostOffsetY"}, 21)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintCostExtraCount"}, 0)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintCostSlotSize"}, 18)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintCostTokenScale"}, 0.5)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintCostQmarkOffsetX"}, -2)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintCostQmarkOffsetY"}, 1)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintCraftGroupY"}, 14)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintTagColOffsetX"}, -36)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintTagColOffsetY"}, 0)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintTagColWidth"}, 56)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintShowSourceMarks"}, false)
		item.set_value({"QingRemasterOptions", "Debug", "BlueprintSettingsVersion"}, 7)
	end)
	-- 原型掉落调试
	if item.get_value({"QingRemasterOptions", "Debug", "PrototypeSpawnId"}) == nil then
		item.set_value({"QingRemasterOptions", "Debug", "PrototypeSpawnId"}, 118)
	end
	add_drag_float(blue_print_group, "QingRemasterOptions_PrototypeSpawnId", "原型 ID", {"QingRemasterOptions", "Debug", "PrototypeSpawnId"}, "Collectible ID for debug spawn", 1, 1, 732, "%.0f")
	ImGui.AddButton(blue_print_group, "QingRemasterOptions_SpawnPrototype", "生成指定原型", function()
		local ok, proto = pcall(require, "Qing_Remaster_scripts.pickups.pickup_blueprint_prototype")
		local id = math.floor(tonumber(item.get_value({"QingRemasterOptions", "Debug", "PrototypeSpawnId"})) or 118)
		local p = Isaac.GetPlayer(0)
		if ok and proto and proto.spawn_prototype and p then
			proto.spawn_prototype(p.Position, id, {source = "debug", spawner = p})
		end
	end)
	ImGui.AddButton(blue_print_group, "QingRemasterOptions_ClearPrototypes", "清空原型库存", function()
		local ok, bp = pcall(require, "Qing_Remaster_scripts.items.Item_Blue_Print")
		local p = Isaac.GetPlayer(0)
		if ok and bp and bp.clear_prototypes and p then bp.clear_prototypes(p) end
	end)
	ImGui.AddButton(blue_print_group, "QingRemasterOptions_ForceCleanProto", "强制下次清房掉落原型", function()
		local ok, proto = pcall(require, "Qing_Remaster_scripts.pickups.pickup_blueprint_prototype")
		if ok and proto then
			proto.force_next_clean = true
			local bp = require("Qing_Remaster_scripts.items.Item_Blue_Print")
			local root = bp.ensure_prototype_root and bp.ensure_prototype_root()
			if root then root.force_next_clean = true end
		end
	end)

	local craft_fam_group = start_mod("flight_craft_familiar", DEBUG_PAGE.flight, text("group_craft_familiar"), "QingRemasterOptions_GroupCraftFamiliar")
	do
		local status_id = "QingRemasterOptions_CraftFamiliarStatus"
		local function craft_fam_status_text()
			local ok, holder = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
			if not ok or not holder or not holder.debug_snapshot then
				return text("craft_familiar_status")
			end
			local rows = holder.debug_snapshot() or {}
			if #rows == 0 then
				return text("craft_familiar_status")
			end
			local lines = {}
			for i = 1, #rows do
				local r = rows[i]
				local aim = r.aim
				local aim_s = "nil"
				if aim then
					aim_s = string.format("%.0f,%.0f", aim.X or 0, aim.Y or 0)
				end
				lines[#lines + 1] = string.format(
					"uid=%s var=%s ad=%s mode=%s cd=%s shoot=%s aim=(%s) focus=%s st=%s",
					tostring(r.uid), tostring(r.variant), tostring(r.adapter), tostring(r.mode),
					tostring(r.cd), tostring(r.should), aim_s, tostring(r.focus), tostring(r.state)
				)
			end
			return table.concat(lines, "\n")
		end
		-- debug_snapshot 会按所有 adapter Variant 扫描实体；禁止挂常驻 Render 刷新。
		-- 仅用户点击时采一份快照，避免隐藏 ImGui 分组也持续做房间扫描。
		ImGui.AddElement(craft_fam_group, status_id, ImGuiElement.TextWrapped, text("craft_familiar_status"))
		ImGui.AddButton(craft_fam_group, "QingRemasterOptions_CraftFamiliarRefreshStatus", "刷新宝宝状态", function()
			ImGui.UpdateText(status_id, craft_fam_status_text())
		end)
		local freeze_id = "QingRemasterOptions_CraftFamiliarFreezeCd"
		ImGui.AddCheckbox(craft_fam_group, freeze_id, text("craft_familiar_freeze_cd"), nil, false)
		ImGui.SetHelpmarker(freeze_id, text("craft_familiar_freeze_cd_help"))
		ImGui.AddCallback(freeze_id, ImGuiCallback.Render, function()
			local ok, holder = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
			ImGui.UpdateData(freeze_id, ImGuiData.Value, ok and holder and holder.debug_freeze_cooldown == true)
		end)
		ImGui.AddCallback(freeze_id, ImGuiCallback.Edited, function(value)
			local ok, holder = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
			if ok and holder then holder.debug_freeze_cooldown = value == true end
		end)
		local force_id = "QingRemasterOptions_CraftFamiliarForceFire"
		ImGui.AddCheckbox(craft_fam_group, force_id, text("craft_familiar_force_fire"), nil, false)
		ImGui.SetHelpmarker(force_id, text("craft_familiar_force_fire_help"))
		ImGui.AddCallback(force_id, ImGuiCallback.Render, function()
			local ok, holder = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
			ImGui.UpdateData(force_id, ImGuiData.Value, ok and holder and holder.debug_force_fire == true)
		end)
		ImGui.AddCallback(force_id, ImGuiCallback.Edited, function(value)
			local ok, holder = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
			if ok and holder then holder.debug_force_fire = value == true end
		end)
		ImGui.AddButton(craft_fam_group, "QingRemasterOptions_CraftFamiliarRestore", text("craft_familiar_restore"), function()
			local ok, holder = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
			if ok and holder then
				holder.debug_freeze_cooldown = false
				holder.debug_force_fire = false
			end
			local ok2, air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
			if ok2 and air then
				air.debug_move_spd = 0
				air.debug_force_luck = nil
			end
		end)
		local move_id = "QingRemasterOptions_AirFlightDebugMoveSpd"
		ImGui.AddDragFloat(craft_fam_group, move_id, text("air_debug_move_spd"), function(value)
			local ok, air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
			if ok and air then air.debug_move_spd = tonumber(value) or 0 end
		end, 0, 0.05, 0, 3, "%.2f")
		ImGui.SetHelpmarker(move_id, text("air_debug_move_spd_help"))
		ImGui.AddCallback(move_id, ImGuiCallback.Render, function()
			local ok, air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
			local v = (ok and air and tonumber(air.debug_move_spd)) or 0
			ImGui.UpdateData(move_id, ImGuiData.Value, v)
		end)
		local luck_id = "QingRemasterOptions_AirFlightForceLuck"
		local hit_id = "QingRemasterOptions_AirFlightHitStatus"
		local function refresh_air_hit_status()
			local ok, air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
			local body = text("air_debug_hit_status")
			if ok and air then
				-- 禁止在 ImGui Render 里 FindByType；仅按钮/勾选时扫一次，且全程 pcall
				local ok2, s = pcall(function()
					return air.get_hit_rate_summary and air.get_hit_rate_summary() or body
				end)
				if ok2 and type(s) == "string" then
					body = s
				elseif air.get_luck_debug_line then
					local ok3, line = pcall(air.get_luck_debug_line)
					if ok3 and type(line) == "string" then body = line end
				end
			end
			ImGui.UpdateText(hit_id, body)
		end
		ImGui.AddCheckbox(craft_fam_group, luck_id, text("air_debug_force_luck"), function(value)
			local ok, air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
			if ok and air then
				air.debug_force_luck = (value == true) and 99 or nil
			end
			-- 勾选后只刷新幸运行安全文本；完整统计点刷新按钮
			if ok and air and air.get_luck_debug_line then
				local ok2, line = pcall(air.get_luck_debug_line)
				if ok2 and type(line) == "string" then
					ImGui.UpdateText(hit_id, line)
				end
			end
		end, false)
		ImGui.SetHelpmarker(luck_id, text("air_debug_force_luck_help"))
		ImGui.AddCallback(luck_id, ImGuiCallback.Render, function()
			local ok, air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
			local on = ok and air and tonumber(air.debug_force_luck) and tonumber(air.debug_force_luck) > 0
			ImGui.UpdateData(luck_id, ImGuiData.Value, on == true)
		end)
		-- 与「宝宝状态」相同：禁止挂常驻 Render 做房间扫描（FindByType 易在 ImGui 重绘时崩）
		ImGui.AddElement(craft_fam_group, hit_id, ImGuiElement.TextWrapped, text("air_debug_hit_status"))
		ImGui.AddButton(craft_fam_group, "QingRemasterOptions_AirFlightHitRefresh", text("air_debug_hit_refresh"), function()
			refresh_air_hit_status()
		end)
	end
	local aura_balance_group = start_mod("flight_aura_balance", DEBUG_PAGE.flight, text("group_aura_balance"), "QingRemasterOptions_GroupAuraBalance")
	do
		local function aura_mod()
			local ok, mod = pcall(require, "Qing_Remaster_scripts.others.craft_aura_effects")
			if ok then return mod end
			return nil
		end
		add_text(aura_balance_group, text("aura_balance_help"))
		local function add_aura_float(suffix, label_key, cfg_key, default_v, speed, min_v, max_v, fmt)
			local eid = "QingRemasterOptions_AuraBal_" .. suffix
			ImGui.AddDragFloat(aura_balance_group, eid, text(label_key), function(value)
				local mod = aura_mod()
				if mod and mod.set_cfg then mod.set_cfg(cfg_key, tonumber(value) or default_v) end
			end, default_v, speed, min_v, max_v, fmt)
			ImGui.AddCallback(eid, ImGuiCallback.Render, function()
				local mod = aura_mod()
				local v = default_v
				if mod and mod.get_cfg then
					local cur = tonumber(mod.get_cfg(cfg_key))
					if cur then v = cur end
				end
				ImGui.UpdateData(eid, ImGuiData.Value, v)
			end)
		end
		add_aura_float("MonRadius", "aura_bal_mon_radius", "monstrance_radius", 45, 0.5, 10, 160, "%.1f")
		add_aura_float("MonScale", "aura_bal_mon_scale", "monstrance_fx_scale", 0.5, 0.01, 0.1, 2.0, "%.2f")
		add_aura_float("MonInterval", "aura_bal_mon_interval", "monstrance_interval", 4, 0.25, 1, 30, "%.0f")
		ImGui.AddButton(aura_balance_group, "QingRemasterOptions_AuraBalRestore", text("aura_bal_restore"), function()
			local mod = aura_mod()
			if mod and mod.reset_cfg then
				mod.reset_cfg({"monstrance_radius", "monstrance_fx_scale", "monstrance_interval"})
			end
		end)
	end
	local orbiting_offset_probe_group = start_mod("flight_orbiting_offset_probe", DEBUG_PAGE.flight, text("group_orbiting_offset_probe"), "QingRemasterOptions_GroupOrbitingOffsetProbe")
	do
		local status_id = "QingRemasterOptions_OrbitingOffsetProbeStatus"
		local function probe_mod()
			return dev_env.require_probe("Qing_Remaster_scripts.others.craft_orbiting_tear_offset_probe")
		end
		local function refresh_status()
			local mod = probe_mod()
			local body = (mod and mod.get_summary and mod.get_summary()) or text("orbiting_offset_probe_status")
			ImGui.UpdateText(status_id, body)
		end
		add_text(orbiting_offset_probe_group, text("orbiting_offset_probe_help"))
		ImGui.AddElement(orbiting_offset_probe_group, status_id, ImGuiElement.TextWrapped, text("orbiting_offset_probe_status"))
		local enable_id = "QingRemasterOptions_OrbitingOffsetProbeEnable"
		ImGui.AddCheckbox(orbiting_offset_probe_group, enable_id, text("orbiting_offset_probe_enable"), nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local mod = probe_mod()
			local on = mod and mod.get_config and mod.get_config().enabled == true
			ImGui.UpdateData(enable_id, ImGuiData.Value, on == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local mod = probe_mod()
			if mod and mod.set_enabled then mod.set_enabled(value == true) end
			refresh_status()
		end)
		ImGui.AddButton(orbiting_offset_probe_group, "QingRemasterOptions_OrbitingOffsetProbeRefresh", "刷新状态", refresh_status)
		ImGui.AddButton(orbiting_offset_probe_group, "QingRemasterOptions_OrbitingOffsetProbeExport", text("orbiting_offset_probe_export"), function()
			local mod = probe_mod()
			if mod and mod.export_jsonl then mod.export_jsonl(true) end
			refresh_status()
		end)
		ImGui.AddButton(orbiting_offset_probe_group, "QingRemasterOptions_OrbitingOffsetProbeClear", text("orbiting_offset_probe_clear"), function()
			local mod = probe_mod()
			if mod and mod.clear then mod.clear() end
			refresh_status()
		end)
	end
	local laser_flag_probe_group = start_mod("flight_laser_flag_probe", DEBUG_PAGE.flight, text("group_laser_flag_probe"), "QingRemasterOptions_GroupLaserFlagProbe")
	do
		local status_id = "QingRemasterOptions_LaserFlagProbeStatus"
		local function probe_mod()
			return dev_env.require_probe("Qing_Remaster_scripts.others.craft_laser_flag_probe")
		end
		local function refresh_status()
			local mod = probe_mod()
			local body = (mod and mod.get_summary and mod.get_summary()) or text("laser_flag_probe_status")
			ImGui.UpdateText(status_id, body)
		end
		add_text(laser_flag_probe_group, text("laser_flag_probe_help"))
		ImGui.AddElement(laser_flag_probe_group, status_id, ImGuiElement.TextWrapped, text("laser_flag_probe_status"))
		local enable_id = "QingRemasterOptions_LaserFlagProbeEnable"
		ImGui.AddCheckbox(laser_flag_probe_group, enable_id, text("laser_flag_probe_enable"), nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local mod = probe_mod()
			local on = mod and mod.get_config and mod.get_config().enabled == true
			ImGui.UpdateData(enable_id, ImGuiData.Value, on == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local mod = probe_mod()
			if mod and mod.set_enabled then mod.set_enabled(value == true) end
			refresh_status()
		end)
		ImGui.AddButton(laser_flag_probe_group, "QingRemasterOptions_LaserFlagProbeRefresh", "刷新状态", refresh_status)
		ImGui.AddButton(laser_flag_probe_group, "QingRemasterOptions_LaserFlagProbeExport", text("laser_flag_probe_export"), function()
			local mod = probe_mod()
			if mod and mod.export_jsonl then mod.export_jsonl(true) end
			refresh_status()
		end)
		ImGui.AddButton(laser_flag_probe_group, "QingRemasterOptions_LaserFlagProbeClear", text("laser_flag_probe_clear"), function()
			local mod = probe_mod()
			if mod and mod.clear then mod.clear() end
			refresh_status()
		end)
	end
	local knife_path_probe_group = start_mod("flight_knife_path_probe", DEBUG_PAGE.flight, text("group_knife_path_probe"), "QingRemasterOptions_GroupKnifePathProbe")
	do
		local status_id = "QingRemasterOptions_KnifePathProbeStatus"
		local function probe_mod()
			return dev_env.require_probe("Qing_Remaster_scripts.others.craft_knife_path_probe")
		end
		local function refresh_status()
			local mod = probe_mod()
			local body = (mod and mod.get_summary and mod.get_summary()) or text("knife_path_probe_status")
			ImGui.UpdateText(status_id, body)
		end
		add_text(knife_path_probe_group, text("knife_path_probe_help"))
		ImGui.AddElement(knife_path_probe_group, status_id, ImGuiElement.TextWrapped, text("knife_path_probe_status"))
		local enable_id = "QingRemasterOptions_KnifePathProbeEnable"
		ImGui.AddCheckbox(knife_path_probe_group, enable_id, text("knife_path_probe_enable"), nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local mod = probe_mod()
			local on = mod and mod.get_config and mod.get_config().enabled == true
			ImGui.UpdateData(enable_id, ImGuiData.Value, on == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local mod = probe_mod()
			if mod and mod.set_enabled then mod.set_enabled(value == true) end
			refresh_status()
		end)
		ImGui.AddButton(knife_path_probe_group, "QingRemasterOptions_KnifePathProbeRefresh", "刷新状态", refresh_status)
		ImGui.AddButton(knife_path_probe_group, "QingRemasterOptions_KnifePathProbeExport", text("knife_path_probe_export"), function()
			local mod = probe_mod()
			if mod and mod.export_jsonl then mod.export_jsonl(true) end
			refresh_status()
		end)
		ImGui.AddButton(knife_path_probe_group, "QingRemasterOptions_KnifePathProbeClear", text("knife_path_probe_clear"), function()
			local mod = probe_mod()
			if mod and mod.clear then mod.clear() end
			refresh_status()
		end)
	end
	local evil_eye_probe_group = start_mod("flight_evil_eye_probe", DEBUG_PAGE.flight, text("group_evil_eye_probe"), "QingRemasterOptions_GroupEvilEyeProbe")
	do
		local status_id = "QingRemasterOptions_EvilEyeProbeStatus"
		local function probe_mod()
			return dev_env.require_probe("Qing_Remaster_scripts.others.craft_evil_eye_vanilla_probe")
		end
		local function refresh_status()
			local mod = probe_mod()
			local body = (mod and mod.get_summary and mod.get_summary()) or text("evil_eye_probe_status")
			ImGui.UpdateText(status_id, body)
		end
		add_text(evil_eye_probe_group, text("evil_eye_probe_help"))
		ImGui.AddElement(evil_eye_probe_group, status_id, ImGuiElement.TextWrapped, text("evil_eye_probe_status"))
		local enable_id = "QingRemasterOptions_EvilEyeProbeEnable"
		ImGui.AddCheckbox(evil_eye_probe_group, enable_id, text("evil_eye_probe_enable"), nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local mod = probe_mod()
			local on = mod and mod.get_config and mod.get_config().enabled == true
			ImGui.UpdateData(enable_id, ImGuiData.Value, on == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local mod = probe_mod()
			if mod and mod.set_enabled then mod.set_enabled(value == true) end
			refresh_status()
		end)
		ImGui.AddButton(evil_eye_probe_group, "QingRemasterOptions_EvilEyeProbeRefresh", "刷新状态", refresh_status)
		ImGui.AddButton(evil_eye_probe_group, "QingRemasterOptions_EvilEyeProbeExport", text("evil_eye_probe_export"), function()
			local mod = probe_mod()
			if mod and mod.export_jsonl then mod.export_jsonl(true) end
			refresh_status()
		end)
		ImGui.AddButton(evil_eye_probe_group, "QingRemasterOptions_EvilEyeProbeClear", text("evil_eye_probe_clear"), function()
			local mod = probe_mod()
			if mod and mod.clear then mod.clear() end
			refresh_status()
		end)
	end
	local vengeful_probe_group = start_mod("flight_vengeful_probe", DEBUG_PAGE.flight, text("group_vengeful_probe"), "QingRemasterOptions_GroupVengefulProbe")
	do
		local status_id = "QingRemasterOptions_VengefulProbeStatus"
		local function probe_mod()
			return dev_env.require_probe("Qing_Remaster_scripts.others.vengeful_spirit_vanilla_probe")
		end
		local function refresh_status()
			local mod = probe_mod()
			local body = (mod and mod.get_summary and mod.get_summary()) or text("vengeful_probe_status")
			ImGui.UpdateText(status_id, body)
		end
		add_text(vengeful_probe_group, text("vengeful_probe_help"))
		ImGui.AddElement(vengeful_probe_group, status_id, ImGuiElement.TextWrapped, text("vengeful_probe_status"))
		local enable_id = "QingRemasterOptions_VengefulProbeEnable"
		ImGui.AddCheckbox(vengeful_probe_group, enable_id, text("vengeful_probe_enable"), nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local mod = probe_mod()
			local on = mod and mod.get_config and mod.get_config().enabled == true
			ImGui.UpdateData(enable_id, ImGuiData.Value, on == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local mod = probe_mod()
			if mod and mod.set_enabled then mod.set_enabled(value == true) end
			refresh_status()
		end)
		ImGui.AddButton(vengeful_probe_group, "QingRemasterOptions_VengefulProbeRefresh", "刷新状态", refresh_status)
		ImGui.AddButton(vengeful_probe_group, "QingRemasterOptions_VengefulProbeExport", text("vengeful_probe_export"), function()
			local mod = probe_mod()
			if mod and mod.export_jsonl then mod.export_jsonl(true) end
			refresh_status()
		end)
		ImGui.AddButton(vengeful_probe_group, "QingRemasterOptions_VengefulProbeClear", text("vengeful_probe_clear"), function()
			local mod = probe_mod()
			if mod and mod.clear then mod.clear() end
			refresh_status()
		end)
	end
	local vengeful_life_group = start_mod("flight_vengeful_life_probe", DEBUG_PAGE.flight, text("group_vengeful_life_probe"), "QingRemasterOptions_GroupVengefulLifeProbe")
	do
		local status_id = "QingRemasterOptions_VengefulLifeProbeStatus"
		local function probe_mod()
			return dev_env.require_probe("Qing_Remaster_scripts.others.vengeful_craft_lifecycle_probe")
		end
		local function refresh_status()
			local mod = probe_mod()
			local body = (mod and mod.get_summary and mod.get_summary()) or text("vengeful_life_probe_status")
			ImGui.UpdateText(status_id, body)
		end
		add_text(vengeful_life_group, text("vengeful_life_probe_help"))
		ImGui.AddElement(vengeful_life_group, status_id, ImGuiElement.TextWrapped, text("vengeful_life_probe_status"))
		local enable_id = "QingRemasterOptions_VengefulLifeProbeEnable"
		ImGui.AddCheckbox(vengeful_life_group, enable_id, text("vengeful_life_probe_enable"), nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local mod = probe_mod()
			local on = mod and mod.get_config and mod.get_config().enabled == true
			ImGui.UpdateData(enable_id, ImGuiData.Value, on == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local mod = probe_mod()
			if mod and mod.set_enabled then mod.set_enabled(value == true) end
			refresh_status()
		end)
		ImGui.AddButton(vengeful_life_group, "QingRemasterOptions_VengefulLifeProbeRefresh", "刷新状态", refresh_status)
		ImGui.AddButton(vengeful_life_group, "QingRemasterOptions_VengefulLifeProbeExport", text("vengeful_life_probe_export"), function()
			local mod = probe_mod()
			if mod and mod.export_jsonl then mod.export_jsonl(true) end
			refresh_status()
		end)
		ImGui.AddButton(vengeful_life_group, "QingRemasterOptions_VengefulLifeProbeClear", text("vengeful_life_probe_clear"), function()
			local mod = probe_mod()
			if mod and mod.clear then mod.clear() end
			refresh_status()
		end)
	end
	local path_tear_probe_group = start_mod("flight_path_tear_probe", DEBUG_PAGE.flight, text("group_path_tear_probe"), "QingRemasterOptions_GroupPathTearProbe")
	do
		local status_id = "QingRemasterOptions_PathTearProbeStatus"
		local function probe_mod()
			return dev_env.require_probe("Qing_Remaster_scripts.others.craft_path_tear_vanilla_probe")
		end
		local function refresh_status()
			local mod = probe_mod()
			local body = (mod and mod.get_summary and mod.get_summary()) or text("path_tear_probe_status")
			ImGui.UpdateText(status_id, body)
		end
		add_text(path_tear_probe_group, text("path_tear_probe_help"))
		ImGui.AddElement(path_tear_probe_group, status_id, ImGuiElement.TextWrapped, text("path_tear_probe_status"))
		local enable_id = "QingRemasterOptions_PathTearProbeEnable"
		ImGui.AddCheckbox(path_tear_probe_group, enable_id, text("path_tear_probe_enable"), nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local mod = probe_mod()
			local on = mod and mod.get_config and mod.get_config().enabled == true
			ImGui.UpdateData(enable_id, ImGuiData.Value, on == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local mod = probe_mod()
			if mod and mod.set_enabled then mod.set_enabled(value == true) end
			refresh_status()
		end)
		ImGui.AddButton(path_tear_probe_group, "QingRemasterOptions_PathTearProbeRefresh", "刷新状态", refresh_status)
		ImGui.AddButton(path_tear_probe_group, "QingRemasterOptions_PathTearProbeExport", text("path_tear_probe_export"), function()
			local mod = probe_mod()
			if mod and mod.export_jsonl then mod.export_jsonl(true) end
			refresh_status()
		end)
		ImGui.AddButton(path_tear_probe_group, "QingRemasterOptions_PathTearProbeClear", text("path_tear_probe_clear"), function()
			local mod = probe_mod()
			if mod and mod.clear then mod.clear() end
			refresh_status()
		end)
	end
	local flight_crash_group = start_mod("flight_crash", DEBUG_PAGE.flight, text("group_flight_crash"), "QingRemasterOptions_GroupFlightCrash")
	do
		local function crash_get(key, default)
			local ok, air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
			if ok and air and air.crash_fx and air.crash_fx[key] ~= nil then
				return air.crash_fx[key]
			end
			local cfg = item.get_value({"QingRemasterOptions", "Debug", "FlightCrash_" .. key})
			if cfg ~= nil then return cfg end
			return default
		end
		local function crash_set(key, value)
			value = tonumber(value) or 0
			item.set_value({"QingRemasterOptions", "Debug", "FlightCrash_" .. key}, value)
			local ok, air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
			if ok and air then
				air.crash_fx = air.crash_fx or {}
				air.crash_fx[key] = value
			end
		end
		local function add_crash_float(id, label_key, key, default, speed, min_v, max_v, fmt)
			local eid = "QingRemasterOptions_FlightCrash_" .. id
			ImGui.AddDragFloat(flight_crash_group, eid, text(label_key), function(value)
				crash_set(key, value)
			end, tonumber(crash_get(key, default)) or default, speed or 0.05, min_v or 0, max_v or 40, fmt or "%.2f")
			ImGui.AddCallback(eid, ImGuiCallback.Render, function()
				ImGui.UpdateData(eid, ImGuiData.Value, tonumber(crash_get(key, default)) or default)
			end)
		end
		add_crash_float("FailFrames", "flight_crash_fail_frames", "fail_frames", 7, 1, 4, 16, "%.0f")
		add_crash_float("Gravity", "flight_crash_gravity", "gravity", 0.38, 0.01, 0.1, 1.2, "%.2f")
		add_crash_float("MaxFall", "flight_crash_max_fall", "max_fall_speed", 7.5, 0.1, 2, 14, "%.1f")
		add_crash_float("Drift", "flight_crash_drift", "drift_retain", 0.985, 0.001, 0.9, 1, "%.3f")
		add_crash_float("Slip", "flight_crash_slip", "side_slip_max", 1.8, 0.05, 0, 4, "%.2f")
		add_crash_float("FallSmoke", "flight_crash_fall_smoke", "fall_smoke_interval", 5, 1, 2, 20, "%.0f")
		add_crash_float("TumbleFric", "flight_crash_tumble_fric", "tumble_friction", 0.90, 0.005, 0.7, 0.98, "%.2f")
		add_crash_float("TumbleMax", "flight_crash_tumble_max", "tumble_max_frames", 24, 1, 10, 60, "%.0f")
		add_crash_float("ImpactDust", "flight_crash_impact_dust", "impact_dust_count", 8, 1, 2, 20, "%.0f")
		add_crash_float("DeadMin", "flight_crash_dead_min", "dead_smoke_min", 18, 1, 6, 60, "%.0f")
		add_crash_float("DeadMax", "flight_crash_dead_max", "dead_smoke_max", 30, 1, 6, 90, "%.0f")
		add_crash_float("Shake", "flight_crash_shake", "screen_shake", 4, 1, 0, 12, "%.0f")
		add_crash_float("Cap", "flight_crash_cap", "particle_cap", 10, 1, 2, 30, "%.0f")
		ImGui.AddButton(flight_crash_group, "QingRemasterOptions_FlightCrashForce", text("flight_crash_force"), function()
			local ok, air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
			if ok and air and air.debug_force_crash then air.debug_force_crash({}) end
		end)
		ImGui.AddButton(flight_crash_group, "QingRemasterOptions_FlightCrashForceRevive", text("flight_crash_force_revive"), function()
			local ok, air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
			if ok and air and air.debug_force_crash then air.debug_force_crash({revive = true}) end
		end)
		ImGui.AddButton(flight_crash_group, "QingRemasterOptions_FlightCrashClear", text("flight_crash_clear"), function()
			local ok, air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
			if ok and air and air.debug_clear_crash_fx then air.debug_clear_crash_fx() end
		end)
		ImGui.AddButton(flight_crash_group, "QingRemasterOptions_FlightCrashRestore", text("flight_crash_restore"), function()
			local ok, air = pcall(require, "Qing_Remaster_scripts.items.Item_Air_Flight")
			if ok and air and air.crash_fx_restore_defaults then
				air.crash_fx_restore_defaults()
			end
		end)
	end
	local temp_revive_group = start_mod("audit_temp_revive", DEBUG_PAGE.audit, text("group_temp_revive"), "QingRemasterOptions_GroupTempRevive")
	do
		add_text(temp_revive_group, text("temp_revive_help"))
		local log_id = "QingRemasterOptions_TempReviveLog"
		ImGui.AddCheckbox(temp_revive_group, log_id, text("temp_revive_log"), nil, false)
		ImGui.AddCallback(log_id, ImGuiCallback.Render, function()
			local ok, trv = pcall(require, "Qing_Remaster_scripts.others.temporary_revive_manager")
			ImGui.UpdateData(log_id, ImGuiData.Value, ok and trv and trv.debug_log == true)
		end)
		ImGui.AddCallback(log_id, ImGuiCallback.Edited, function(value)
			local ok, trv = pcall(require, "Qing_Remaster_scripts.others.temporary_revive_manager")
			if ok and trv then trv.debug_log = value == true end
		end)
		local status_id = "QingRemasterOptions_TempReviveStatus"
		ImGui.AddElement(temp_revive_group, status_id, ImGuiElement.TextWrapped, text("temp_revive_status"))
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local ok, trv = pcall(require, "Qing_Remaster_scripts.others.temporary_revive_manager")
			local body = (ok and trv and trv.get_debug_text and trv.get_debug_text()) or text("temp_revive_status")
			ImGui.UpdateText(status_id, body)
		end)
		ImGui.AddButton(temp_revive_group, "QingRemasterOptions_TempReviveClear", text("temp_revive_clear"), function()
			local ok, trv = pcall(require, "Qing_Remaster_scripts.others.temporary_revive_manager")
			if ok and trv and trv.clear_spent_for_player then
				trv.clear_spent_for_player(Isaac.GetPlayer(0))
				local ok2, imi = pcall(require, "Qing_Remaster_scripts.callbacks.imitate_item_holder")
				if ok2 and imi and imi.Evaluate_Imitate_Items then
					imi.Evaluate_Imitate_Items(Isaac.GetPlayer(0))
				end
			end
		end)
	end
	local attribute_group = start_mod("audit_attribute_holder", DEBUG_PAGE.audit, "属性裁断器探针", "QingRemasterOptions_GroupAttributeHolder")
	do
		add_text(attribute_group, "默认关闭。启用后仅展示活动委托计数；自检按钮使用假实体核对嵌套释放、动态值、外部改值和 getter/setter，不写文件、不扫描房间实体。")
		local enable_id = "QingRemasterOptions_AttributeHolderProbeEnabled"
		ImGui.AddCheckbox(attribute_group, enable_id, "启用实时状态", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local holder = require("Qing_Remaster_scripts.others.Attribute_holder")
			ImGui.UpdateData(enable_id, ImGuiData.Value, holder.debug.probe_enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local holder = require("Qing_Remaster_scripts.others.Attribute_holder")
			holder.debug.probe_enabled = value == true
		end)
		ImGui.AddButton(attribute_group, "QingRemasterOptions_AttributeHolderRun", "运行一次复杂场景自检", function()
			require("Qing_Remaster_scripts.others.Attribute_holder").run_self_test()
		end)
		local status_id = "QingRemasterOptions_AttributeHolderStatus"
		ImGui.AddElement(attribute_group, status_id, ImGuiElement.TextWrapped, "探针关闭；尚未自检。")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local holder = require("Qing_Remaster_scripts.others.Attribute_holder")
			local report = holder.debug.last_report
			local body = holder.debug.probe_enabled and "实时状态已开启" or "实时状态已关闭"
			if holder.debug.probe_enabled then
				local s = holder.get_debug_stats()
				body = body .. string.format("\n实体=%d binder=%d 属性=%d 委托=%d 错误=%d", s.entities,s.binders,s.attrs,s.claims,s.errors)
			end
			if report then
				body = body .. string.format("\n最近自检：%d/%d 通过，frame=%d",report.passed,report.total,report.frame)
				if #report.failures > 0 then body = body .. "\n失败：" .. table.concat(report.failures, ", ") end
			else body = body .. "\n尚未运行自检。" end
			ImGui.UpdateText(status_id, body)
		end)
		ImGui.AddButton(attribute_group, "QingRemasterOptions_AttributeHolderReset", "关闭并清除探针结果", function()
			local holder = require("Qing_Remaster_scripts.others.Attribute_holder")
			holder.debug.probe_enabled = false; holder.debug.last_report = nil
		end)
	end
	local consistance_group = start_mod("audit_consistance_holder", DEBUG_PAGE.audit, "实体一致性 V2 探针", "QingRemasterOptions_GroupConsistanceHolder")
	do
		add_text(consistance_group, "默认关闭。开启后只读取 Consistance V2 的存档索引和运行态认领汇总；不扫描房间实体、不写文件。完整性审计仅在点击按钮时遍历记录表。双实体测试会用 Game:Spawn 指定同一 seed 生成两枚硬币，分别登记 LEFT/RIGHT，移除后以相反顺序重建并核对位置佐证。")
		local enable_id = "QingRemasterOptions_ConsistanceHolderProbeEnabled"
		ImGui.AddCheckbox(consistance_group, enable_id, "启用实时汇总", nil, false)
		ImGui.AddCallback(enable_id, ImGuiCallback.Render, function()
			local holder = require("Qing_Remaster_scripts.others.Consistance_holder")
			ImGui.UpdateData(enable_id, ImGuiData.Value, holder.debug.probe_enabled == true)
		end)
		ImGui.AddCallback(enable_id, ImGuiCallback.Edited, function(value)
			local holder = require("Qing_Remaster_scripts.others.Consistance_holder")
			holder.debug.probe_enabled = value == true
		end)
		ImGui.AddButton(consistance_group, "QingRemasterOptions_ConsistanceHolderAudit", "运行一次索引完整性审计", function()
			require("Qing_Remaster_scripts.others.Consistance_holder").run_integrity_audit()
		end)
		ImGui.AddButton(consistance_group, "QingRemasterOptions_ConsistanceHolderDuplicateTest", "生成同 InitSeed 双实体并重建测试", function()
			require("Qing_Remaster_scripts.others.Consistance_holder").run_duplicate_spawn_test()
		end)
		local status_id = "QingRemasterOptions_ConsistanceHolderStatus"
		ImGui.AddElement(consistance_group, status_id, ImGuiElement.TextWrapped, "探针关闭；尚未审计。")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local holder = require("Qing_Remaster_scripts.others.Consistance_holder")
			local body = holder.debug.probe_enabled and "实时汇总已开启" or "实时汇总已关闭"
			if holder.debug.probe_enabled then
				local s = holder.get_debug_snapshot()
				body = body .. string.format("\nV%d 记录=%d 索引桶=%d/链接=%d 认领=%d 待移除=%d",s.schema_version,s.records,s.index_buckets,s.index_links,s.claims,s.pending_remove)
				body = body .. string.format("\n生命周期：房间=%d 层=%d 本局=%d；移除保留=%d 孤儿=%d",s.room,s.level,s.run,s.retained,s.orphans)
				body = body .. string.format("\n佐证竞争桶=%d/记录=%d；同指纹歧义=%d；相似度解决=%d；稳定序号回退=%d",s.evidence_groups,s.evidence_records,s.ambiguous_matches,s.similarity_resolutions,s.ambiguous_fallbacks)
				body = body .. string.format("\n错误=%d 参数冲突=%d；最近事件=%s",s.errors,s.parameter_conflicts,tostring(s.last_event or "none"))
				if s.last_error then body = body .. "\n最近错误：" .. tostring(s.last_error) end
			end
			local report = holder.debug.last_report
			if report then
				body = body .. string.format("\n最近审计：%s，记录=%d/索引=%d，错误=%d，frame=%d",report.ok and "通过" or "失败",report.records,report.index_links,report.failure_count or #report.failures,report.frame)
				if #report.failures > 0 then body = body .. "\n前20项：" .. table.concat(report.failures,"；") end
			else body = body .. "\n尚未运行完整性审计。" end
			local duplicate = holder.debug.last_duplicate_test
			if duplicate then
				body = body .. string.format("\n双实体测试：%s；seed=%s/%s；阶段=%s",duplicate.ok==true and "通过" or (duplicate.ok==false and "失败" or "等待"),tostring(duplicate.actual_a or duplicate.seed),tostring(duplicate.actual_b or duplicate.seed),tostring(duplicate.phase))
				body = body .. string.format("；原体移除=%s/%s；记录释放=%s",tostring(duplicate.original_removed_a),tostring(duplicate.original_removed_b),tostring(duplicate.records_released))
				if duplicate.phase=="complete" then body = body .. string.format("；检查=%s/%s；左=%s 右=%s；重建seed=%s/%s",tostring(duplicate.check_left),tostring(duplicate.check_right),tostring(duplicate.restored_left),tostring(duplicate.restored_right),tostring(duplicate.rebuilt_seed_a),tostring(duplicate.rebuilt_seed_b)) end
			end
			ImGui.UpdateText(status_id, body)
		end)
		ImGui.AddButton(consistance_group, "QingRemasterOptions_ConsistanceHolderResetProbe", "关闭并清除探针结果", function()
			local holder = require("Qing_Remaster_scripts.others.Consistance_holder")
			holder.debug.probe_enabled = false holder.reset_debug_stats()
		end)
	end
	local glaze_chest_group = start_mod("audit_glaze_chest", DEBUG_PAGE.audit, "琉璃宝箱钥匙审计", "QingRemasterOptions_GroupGlazeChest")
	do
		add_text(glaze_chest_group, "对照 key_cnt / 待合并 fake / 未捡钥匙任务（chest_seed）与本房箱·钥匙实体。默认实时刷新，不写盘。")
		local status_id = "QingRemasterOptions_GlazeChestAuditStatus"
		ImGui.AddElement(glaze_chest_group, status_id, ImGuiElement.TextWrapped, "加载中…")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local ok, chest = pcall(require, "Qing_Remaster_scripts.pickups.pickup_glaze_chest")
			local body = (ok and chest and chest.get_key_audit_text and chest.get_key_audit_text()) or "无法加载 pickup_glaze_chest"
			ImGui.UpdateText(status_id, body)
		end)
	end
	local charon_group = start_mod("item_charon", DEBUG_PAGE.items, text("group_charon_tide"), "QingRemasterOptions_GroupCharonTide")
	add_drag_float(charon_group, "QingRemasterOptions_CharonSpawnInterval", text("charon_spawn_interval"), {"QingRemasterOptions", "Debug", "CharonSpawnInterval"}, text("charon_spawn_interval_help"), 1, 1, 120, "%.0f f")
	add_drag_float(charon_group, "QingRemasterOptions_CharonParticleLifetime", text("charon_particle_lifetime"), {"QingRemasterOptions", "Debug", "CharonParticleLifetime"}, text("charon_particle_lifetime_help"), 1, 10, 600, "%.0f f")
	add_drag_float(charon_group, "QingRemasterOptions_CharonFadeFrames", text("charon_fade_frames"), {"QingRemasterOptions", "Debug", "CharonFadeFrames"}, text("charon_fade_frames_help"), 1, 1, 120, "%.0f f")
	add_drag_float(charon_group, "QingRemasterOptions_CharonForegroundRate", text("charon_foreground_rate"), {"QingRemasterOptions", "Debug", "CharonForegroundRate"}, text("charon_foreground_rate_help"), 0.01, 0, 1, "%.2f")
	add_drag_float(charon_group, "QingRemasterOptions_CharonRowsPerAnchor", text("charon_rows_per_anchor"), {"QingRemasterOptions", "Debug", "CharonRowsPerAnchor"}, text("charon_rows_per_anchor_help"), 1, 1, 8, "%.0f")
	add_drag_float(charon_group, "QingRemasterOptions_CharonRoomPrefillRatio", text("charon_room_prefill"), {"QingRemasterOptions", "Debug", "CharonRoomPrefillRatio"}, text("charon_room_prefill_help"), 0.05, 0, 1, "%.2f")
	add_drag_float(charon_group, "QingRemasterOptions_CharonRoomFadeFrames", text("charon_room_fade"), {"QingRemasterOptions", "Debug", "CharonRoomFadeFrames"}, text("charon_room_fade_help"), 1, 0, 120, "%.0f f")
	add_checkbox(charon_group, "QingRemasterOptions_CharonForceSeijaEnhancement", text("charon_seija_enabled"), {"QingRemasterOptions", "Debug", "CharonForceSeijaEnhancement"}, text("charon_seija_enabled_help"))
	add_drag_float(charon_group, "QingRemasterOptions_CharonSeijaSpeedMultiplier", text("charon_seija_speed"), {"QingRemasterOptions", "Debug", "CharonSeijaSpeedMultiplier"}, text("charon_seija_speed_help"), 0.25, 1, 20, "%.2fx")
	add_drag_float(charon_group, "QingRemasterOptions_CharonPickupProtectRadius", text("charon_pickup_radius"), {"QingRemasterOptions", "Debug", "CharonPickupProtectRadius"}, text("charon_pickup_radius_help"), 1, 0, 240, "%.0f px")
	ImGui.AddButton(charon_group, "QingRemasterOptions_CharonRestoreDefaults", text("restore_item_defaults"), function()
		local defaults={
			CharonSpawnInterval=15,
			CharonParticleLifetime=120,
			CharonFadeFrames=20,
			CharonForegroundRate=0.2,
			CharonRowsPerAnchor=1,
			CharonRoomPrefillRatio=0.5,
			CharonRoomFadeFrames=15,
			CharonForceSeijaEnhancement=false,
			CharonSeijaSpeedMultiplier=4,
			CharonPickupProtectRadius=120,
			CharonSettingsVersion=4,
		}
		for key,value in pairs(defaults) do item.set_value({"QingRemasterOptions","Debug",key},value) end
	end)
	add_remaster_flip_group(items_tab)

	add_live_broadcast_group(items_tab)

	add_ritual_sting_group(items_tab)

	do
		local orb_group = start_mod("flight_orbital", DEBUG_PAGE.flight, "Flight Orbital", "QingRemasterOptions_GroupFlightOrbital")
		add_text(orb_group, "布局按 Flight+layout_ring 全局均分相位；距离=层表/原实体椭圆×倍率。视觉高度用 render bias，勿改世界半径。批次1：10/57/112/128/172/279/364/508/542。")
		local function orb_mod()
			local ok, mod = pcall(require, "Qing_Remaster_scripts.mimics.Craft_Orbital_holder")
			if ok then return mod end
			return nil
		end
		local function add_orb_float(id, label, key, default, speed, min_v, max_v, fmt)
			local eid = "QingRemasterOptions_FlightOrbital_" .. id
			ImGui.AddDragFloat(orb_group, eid, label, function(value)
				local mod = orb_mod()
				if mod then mod.debug[key] = tonumber(value) or default end
			end, default, speed or 0.01, min_v or 0, max_v or 1, fmt or "%.2f")
			ImGui.AddCallback(eid, ImGuiCallback.Render, function()
				local mod = orb_mod()
				local v = (mod and tonumber(mod.debug[key])) or default
				ImGui.UpdateData(eid, ImGuiData.Value, v)
			end)
		end
		add_orb_float("ContactMul", "普通 contact 基础倍率", "contact_mul", 0.45, 0.01, 0.05, 1.00, "%.2f")
		add_orb_float("HighMul", "高伤 contact 基础倍率", "high_contact_mul", 0.30, 0.01, 0.05, 1.00, "%.2f")
		add_orb_float("Chase", "主动追敌折扣", "chase_discount", 0.65, 0.01, 0.10, 1.00, "%.2f")
		add_orb_float("HitInterval", "命中间隔(逻辑帧)", "hit_interval", 10, 1, 1, 30, "%.0f")
		add_orb_float("DistMul", "全局距离倍率", "orbit_dist_mul", 1.0, 0.05, 0.25, 3.0, "%.2f")
		add_orb_float("MulMeat", "肉块距离倍率", "orbit_mul_meat", 1.0, 0.05, 0.25, 3.0, "%.2f")
		add_orb_float("MulBand", "绷带距离倍率", "orbit_mul_bandage", 1.0, 0.05, 0.25, 3.0, "%.2f")
		add_orb_float("MulBud", "好朋友距离倍率", "orbit_mul_best_bud", 1.0, 0.05, 0.25, 3.0, "%.2f")
		add_orb_float("MulLep", "麻风距离倍率", "orbit_mul_leprosy", 1.0, 0.05, 0.25, 3.0, "%.2f")
		add_orb_float("LayerMeat", "合成肉块 OrbitLayer", "orbit_layer_meat", 0, 1, 0, 8, "%.0f")
		add_orb_float("LayerBand", "合成绷带 OrbitLayer", "orbit_layer_bandage", 0, 1, 0, 8, "%.0f")
		add_orb_float("LayerBud", "合成好朋友 OrbitLayer", "orbit_layer_best_bud", 1, 1, 0, 8, "%.0f")
		add_orb_float("LayerLep", "合成麻风 OrbitLayer", "orbit_layer_leprosy", 0, 1, 0, 8, "%.0f")
		add_orb_float("RenderYBias", "视觉高度 bias(+下)", "orbital_render_y_bias", 0, 0.5, -40, 40, "%.1f")
		add_orb_float("Spring", "弹簧", "spring", 0.28, 0.01, 0.05, 1.00, "%.2f")
		add_orb_float("Damping", "阻尼", "damping", 0.72, 0.01, 0.10, 0.98, "%.2f")
		add_orb_float("MaxSpd", "轨道最大速度", "orbit_max_speed", 16, 0.5, 4, 40, "%.1f")
		add_orb_float("GuardSpd", "守护天使转速倍率", "guardian_orbit_factor", 1.5, 0.05, 0.5, 3.0, "%.2f")
		add_orb_float("FanSpd", "大粉丝转速倍率", "big_fan_orbit_factor", 0.5, 0.05, 0.1, 1.5, "%.2f")
		add_orb_float("RazorBleed", "剃刀流血持续(帧)", "razor_bleed_frames", 150, 5, 30, 600, "%.0f")
		local ball_id = "QingRemasterOptions_FlightOrbital_BallBlocks"
		ImGui.AddCheckbox(orb_group, ball_id, "Ball blocks projectiles", nil, true)
		ImGui.AddCallback(ball_id, ImGuiCallback.Render, function()
			local mod = orb_mod()
			ImGui.UpdateData(ball_id, ImGuiData.Value, not mod or mod.debug.ball_blocks ~= false)
		end)
		ImGui.AddCallback(ball_id, ImGuiCallback.Edited, function(value)
			local mod = orb_mod()
			if mod then mod.debug.ball_blocks = value == true end
		end)
		ImGui.AddButton(orb_group, "QingRemasterOptions_FlightOrbital_Probe", "探针 layer0-4 / 真实环绕", function()
			local mod = orb_mod()
			if mod and mod.probe_orbit_params then mod.probe_orbit_params() end
		end)
		local status_id = "QingRemasterOptions_FlightOrbital_Status"
		ImGui.AddElement(orb_group, status_id, ImGuiElement.TextWrapped, "无 Flight orbital")
		ImGui.AddCallback(status_id, ImGuiCallback.Render, function()
			local mod = orb_mod()
			local probe = mod and mod._last_orbit_probe
			local body = (mod and mod.get_debug_status and mod.get_debug_status()) or "无 Flight orbital"
			if probe and probe ~= "" then
				body = body .. "\n\n" .. probe
			end
			ImGui.UpdateText(status_id, body)
		end)
		ImGui.AddButton(orb_group, "QingRemasterOptions_FlightOrbital_Restore", "恢复 Orbital 默认设置", function()
			local mod = orb_mod()
			if mod and mod.restore_debug_defaults then mod.restore_debug_defaults() end
		end)
	end

	-- Items continued (Remaster / Live / Ritual already registered above)
	add_death_sentence_group(items_tab)

	do
		local group = start_mod("item_pareidolia", DEBUG_PAGE.items, "妖心·盈月", "QingRemasterOptions_GroupPareidolia")
		add_text(group, "月亮眼调试：背景贴图 / 高度 / 飘移。正式：注视攒相→缩小升顶→停滞瞄准→光柱预兆→圣光。开睑默认全开。")
		-- 注意：不要再对同一 checkbox 挂第二份 Edited——会覆盖 add_checkbox 的 set_value，导致勾不上。
		-- moon.debug 由 Item_Pareidolia 每帧从 ModConfig 同步。
		add_checkbox(group, "QingRemasterOptions_PareidoliaPreview", "持有时预览月亮眼", {"QingRemasterOptions", "Debug", "PareidoliaPreview"}, "开启后在角色附近循环开合预览（与满月演出独立）。")
		add_checkbox(group, "QingRemasterOptions_PareidoliaDetailedBack", "背景用 0/0 阴影月面", {"QingRemasterOptions", "Debug", "PareidoliaDetailedBack"}, "关闭=128/0 纯色底；开启=0/0 带阴影格。默认开。")
		add_checkbox(group, "QingRemasterOptions_PareidoliaForceSpin", "预览强制旋转", {"QingRemasterOptions", "Debug", "PareidoliaForceSpin"}, "预览时慢速旋转整眼。")
		add_drag_float(group, "QingRemasterOptions_PareidoliaFxLiftHover", "满月偏好高度", {"QingRemasterOptions", "Debug", "PareidoliaFxLiftHover"}, "无房间信息时的回退高度。", 5, 40, 400, "%.0f")
		add_drag_float(group, "QingRemasterOptions_PareidoliaFxLiftMax", "满月高度硬顶", {"QingRemasterOptions", "Debug", "PareidoliaFxLiftMax"}, "抬升搜索上限；真正高度由屏高比例决定。", 5, 120, 480, "%.0f")
		add_drag_float(group, "QingRemasterOptions_PareidoliaFxScreenTopPct", "满月目标屏高比例", {"QingRemasterOptions", "Debug", "PareidoliaFxScreenTopPct"}, "目标屏幕 Y=屏高×此值，近似落在屏顶边界下方。默认 0.22；越小越高。", 0.01, 0.08, 0.40, "%.2f")
		add_drag_float(group, "QingRemasterOptions_PareidoliaFxLiftStart", "满月起始高度", {"QingRemasterOptions", "Debug", "PareidoliaFxLiftStart"}, "无进度月接续、强制满月时的升起起点。", 2, 0, 400, "%.0f")
		add_drag_float(group, "QingRemasterOptions_PareidoliaFxAscendFrames", "蓄力升飞帧数", {"QingRemasterOptions", "Debug", "PareidoliaFxAscendFrames"}, "charge：升飞+远小+光柱渐粗+目标渐白的总帧数。", 1, 8, 120, "%.0f f")
		add_drag_float(group, "QingRemasterOptions_PareidoliaPhaseLift", "进度月基准高度", {"QingRemasterOptions", "Debug", "PareidoliaPhaseLift"}, "0% 月相高度；满相约到 210，需明显升高。", 2, 10, 260, "%.0f")
		add_drag_float(group, "QingRemasterOptions_PareidoliaFloatRate", "追随速率", {"QingRemasterOptions", "Debug", "PareidoliaFloatRate"}, "预测追随的最大速度/加速度；切目标时会短暂加强。", 0.01, 0.02, 0.5, "%.2f")
		do
			local probe_path = {"QingRemasterOptions", "Debug", "PareidoliaTechLaserProbe"}
			local probe_id = "QingRemasterOptions_PareidoliaTechLaserProbe"
			ImGui.AddCheckbox(group, probe_id, "科技激光起点探针", nil, item.get_value(probe_path) == true)
			ImGui.AddCallback(probe_id, ImGuiCallback.Render, function()
				ImGui.UpdateData(probe_id, ImGuiData.Value, item.get_value(probe_path) == true)
			end)
			ImGui.AddCallback(probe_id, ImGuiCallback.Edited, function(value)
				item.set_value(probe_path, value == true)
				local mod = dev_env.require_probe("Qing_Remaster_scripts.others.pareidolia_tech_laser_probe")
				if mod and mod.set_enabled then mod.set_enabled(value == true) end
			end)
			ImGui.SetHelpmarker(probe_id, "满月+科技2时采样瞳孔/激光屏坐标差，并画点标记。绿=渲染瞳孔，青=逻辑瞳孔，红=激光 W2S。→ codex_work/logs/pareidolia_tech_laser_probe.jsonl")
		end
		ImGui.AddButton(group, "QingRemasterOptions_PareidoliaTechLaserProbeExport", "导出激光探针样本", function()
			local mod = dev_env.require_probe("Qing_Remaster_scripts.others.pareidolia_tech_laser_probe")
			if mod and mod.flush then
				mod.flush(true)
				local st = mod.get_status and mod.get_status() or {}
				push_notice("已导出 " .. tostring(st.sample_count or 0) .. " 条 → " .. tostring(st.export_path or "?"))
			else
				push_notice("探针模块不可用", error_notice_type())
			end
		end)
		ImGui.AddButton(group, "QingRemasterOptions_PareidoliaForceResonance", "强制满月共鸣", function()
			if not Isaac.IsInGame or not Isaac.IsInGame() then
				push_notice(text("start_run_first"), error_notice_type())
				return
			end
			local ok, pare = pcall(require, "Qing_Remaster_scripts.items.Item_Pareidolia")
			if not ok or not pare or not pare.debug_force_resonance then
				push_notice("Pareidolia module unavailable", error_notice_type())
				return
			end
			local player = nil
			for i = 0, Game():GetNumPlayers() - 1 do
				local p = Game():GetPlayer(i)
				if p and p:HasCollectible(pare.entity) then
					player = p
					break
				end
			end
			player = player or Game():GetPlayer(0)
			pare.debug_force_resonance(player)
			push_notice("强制满月已触发")
		end)
		ImGui.AddButton(group, "QingRemasterOptions_PareidoliaRestore", text("restore_item_defaults"), function()
			item.set_value({"QingRemasterOptions", "Debug", "PareidoliaPreview"}, false)
			item.set_value({"QingRemasterOptions", "Debug", "PareidoliaDetailedBack"}, true)
			item.set_value({"QingRemasterOptions", "Debug", "PareidoliaForceSpin"}, false)
			item.set_value({"QingRemasterOptions", "Debug", "PareidoliaFxLiftStart"}, 36)
			item.set_value({"QingRemasterOptions", "Debug", "PareidoliaFxLiftHover"}, 160)
			item.set_value({"QingRemasterOptions", "Debug", "PareidoliaFxLiftMax"}, 260)
			item.set_value({"QingRemasterOptions", "Debug", "PareidoliaFxScreenTopPct"}, 0.22)
			item.set_value({"QingRemasterOptions", "Debug", "PareidoliaFxAscendFrames"}, 48)
			item.set_value({"QingRemasterOptions", "Debug", "PareidoliaPhaseLift"}, 90)
			item.set_value({"QingRemasterOptions", "Debug", "PareidoliaFloatRate"}, 0.11)
			item.set_value({"QingRemasterOptions", "Debug", "PareidoliaTechLaserProbe"}, false)
			local mod = dev_env.require_probe("Qing_Remaster_scripts.others.pareidolia_tech_laser_probe")
			if mod and mod.set_enabled then mod.set_enabled(false) end
		end)
	end

	add_book_of_voice_group(items_tab)

	add_book_of_thoth_group(items_tab)

	add_gospel_group(items_tab)
	add_drama_group(items_tab)
	add_mental_group(items_tab)

	add_suture_needle_group(items_tab)

	add_zeiz_hub_group(items_tab)

	add_regenesis_group(items_tab)

	add_bloody_map_group(items_tab)

	add_glaze_crown_group(items_tab)

	add_golden_slot_group(items_tab)

	add_reserved_judgment_group(items_tab)

	add_diamond_group(items_tab)

	local eid_group = start_mod("audit_blueprint_eid", DEBUG_PAGE.audit, text("group_blueprint_eid_audit"), "QingRemasterOptions_GroupBlueprintEidAudit")
	add_text(eid_group, text("blueprint_eid_audit_help"))
	ImGui.AddButton(eid_group, "QingRemasterOptions_ExportBlueprintEidAudit", text("blueprint_eid_audit_export"), function()
		local ok, copy = pcall(require, "Qing_Remaster_scripts.others.craft_eid_copy")
		if not ok or not copy or not copy.export_eid_audit then
			print("[Qing] blueprint EID audit: craft_eid_copy unavailable")
			return
		end
		local ok_zh, path_zh, payload_zh = copy.export_eid_audit(true)
		local ok_en, path_en, payload_en = copy.export_eid_audit(false)
		local n_zh = payload_zh and payload_zh.count or 0
		local n_en = payload_en and payload_en.count or 0
		local long_zh, long_en = 0, 0
		if payload_zh and payload_zh.rows then
			for _, row in ipairs(payload_zh.rows) do
				if row.too_long then long_zh = long_zh + 1 end
			end
		end
		if payload_en and payload_en.rows then
			for _, row in ipairs(payload_en.rows) do
				if row.too_long then long_en = long_en + 1 end
			end
		end
		print(string.format(
			"[Qing] blueprint EID audit zh=%s (%d rows, %d too_long) en=%s (%d rows, %d too_long)",
			ok_zh and tostring(path_zh) or ("FAIL:"..tostring(path_zh)),
			n_zh, long_zh,
			ok_en and tostring(path_en) or ("FAIL:"..tostring(path_en)),
			n_en, long_en
		))
	end)

	local imitate_group = start_mod("audit_imitate", DEBUG_PAGE.audit, text("group_imitate_items"), "QingRemasterOptions_GroupImitateItems")
	add_text(imitate_group, text("run_only"))
	ImGui.AddButton(imitate_group, "QingRemasterOptions_ReevaluateImitateItems", text("reevaluate_imitate"), function()
		if Isaac.IsInGame and Isaac.IsInGame() then
			local imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")
			imitate_item_holder.Evaluate_Imitate_Items()
			push_notice(text("reevaluated_notice"))
		else
			push_notice(text("start_run_first"), error_notice_type())
		end
	end)
	ImGui.AddButton(imitate_group, "QingRemasterOptions_PrintImitateItems", text("print_imitate"), function()
		local recorder = save.elses and save.elses["Imi_item_r_recorder"] or {}
		for player_idx,records in pairs(recorder) do
			for collid,count in pairs(records or {}) do
				print("QING:: FakeItem player="..tostring(player_idx).." id="..tostring(collid).." count="..tostring(count))
			end
		end
		push_notice(text("printed_notice"))
	end)

	item.create_permanent_data_panel(permanent_tab)
	add_item_color_panel(item_colors_tab)
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
