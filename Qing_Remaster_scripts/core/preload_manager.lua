-- 启动期模块预加载：在其他模组改写全局 require 搜索路径前写入 package.loaded。
-- 新增运行时 helper/data 或可能延迟首次使用的模块时，统一登记在这里。
local manager = {}
manager.loaded = {}
manager.callback_audit = {auto_registered = {}}

manager.modules = {
	"Qing_Remaster_scripts.core.dev_environment",
	"Qing_Remaster_scripts.core.release_scope",
	"Qing_Remaster_scripts.cards.card_registry",
	"Qing_Remaster_scripts.cards.card_registry_bootstrap",
	"Qing_Remaster_scripts.cards.thoth_use_semantics",
	"Qing_Remaster_scripts.cards.adjustment_vfx",
	"Qing_Remaster_scripts.items.regenesis_capture_vfx",
	"Qing_Remaster_scripts.cards.death_field.constants",
	"Qing_Remaster_scripts.others.room_space_mapper",
	"Qing_Remaster_scripts.others.room_wall_geometry",
	"Qing_Remaster_scripts.others.grid_rock_topology",
	"Qing_Remaster_scripts.cards.death_field.state",
	"Qing_Remaster_scripts.cards.death_field.layout",
	"Qing_Remaster_scripts.cards.death_field.trinket_effects",
	"Qing_Remaster_scripts.cards.death_field.proxy",
	"Qing_Remaster_scripts.cards.death_field.charge",
	"Qing_Remaster_scripts.cards.death_field.visual",
	"Qing_Remaster_scripts.cards.death_field.executor",
	"Qing_Remaster_scripts.cards.death_field.interaction",
	"Qing_Remaster_scripts.cards.sting_reversed.constants",
	"Qing_Remaster_scripts.cards.sting_reversed.visual",
	"Qing_Remaster_scripts.cards.sting_reversed.link",
	"Qing_Remaster_scripts.cards.sting_reversed.blood",
	"Qing_Remaster_scripts.systems.item_inscription",
	"Qing_Remaster_scripts.items.spectralsword.hud_nodes",
	"Qing_Remaster_scripts.items.spectralsword.hud_fonts",
	"Qing_Remaster_scripts.items.spectralsword.angel_reshape",
	"Qing_Remaster_scripts.callbacks.deal_chance_holder",
	"Qing_Remaster_scripts.auxiliary.deal_chance_semantics",
	"Qing_Remaster_scripts.items.spectralsword.input_repeater",
	"Qing_Remaster_scripts.items.spectralsword.ghost_controller",
	"Qing_Remaster_scripts.items.spectralsword.spirit_vfx",
	"Qing_Remaster_scripts.items.spectralsword.hud_render",
	"Qing_Remaster_scripts.debug.probe_registry",
	"Qing_Remaster_scripts.debug.probe_output",
	"Qing_Remaster_scripts.debug.probe_live_cache",
	"Qing_Remaster_scripts.debug.rgon_imgui_settings_ui",
	"Qing_Remaster_scripts.debug.rgon_imgui_debug_ui",
	"Qing_Remaster_scripts.debug.rgon_imgui_probes_ui",
	"Qing_Remaster_scripts.others.a2z_font_renderer",
	"Qing_Remaster_scripts.others.dynamic_lighting_holder",
	"Qing_Remaster_scripts.others.craft_combat_profile",
	"Qing_Remaster_scripts.others.craft_eid_copy",
	"Qing_Remaster_scripts.others.blueprint_craft_eid",
	"Qing_Remaster_scripts.others.blueprint_tutorial",
	"Qing_Remaster_scripts.others.Mouse_UI_holder",
	"Qing_Remaster_scripts.others.fullscreen_select_holder",
	"Qing_Remaster_scripts.others.craft_dynamic_stats",
	"Qing_Remaster_scripts.others.craft_on_hurt_router",
	"Qing_Remaster_scripts.auxiliary.electric_chain",
	"Qing_Remaster_scripts.auxiliary.enemy_death_guard",
	"Qing_Remaster_scripts.others.craft_aura_effects",
	"Qing_Remaster_scripts.others.craft_charge_weapons",
	"Qing_Remaster_scripts.others.craft_orbiting_tears",
	"Qing_Remaster_scripts.others.craft_zodiac",
	"Qing_Remaster_scripts.others.craft_taurus",
	"Qing_Remaster_scripts.others.pareidolia_moon_render",
	"Qing_Remaster_scripts.callbacks.attack_fire_context", -- same preload policy as attack_source_classifier
	"Qing_Remaster_scripts.callbacks.attack_source_classifier",
	"Qing_Remaster_scripts.callbacks.attack_aim_resolver",
	"Qing_Remaster_scripts.debug.consistance_test_lab",
	"Qing_Remaster_scripts.debug.consistance_test_lab_essm",
	"Qing_Remaster_scripts.debug.consistance_test_lab_unique",
	"Qing_Remaster_scripts.debug.unique_consumer_regression_lab",
	"Qing_Remaster_scripts.debug.unique_resolve_regression_lab",
	"Qing_Remaster_scripts.debug.unique_fresh_generation_lab",
	"Qing_Remaster_scripts.debug.pedestal_encounter_regression_lab",
	"Qing_Remaster_scripts.others.Entity_lifetime_holder",
	"Qing_Remaster_scripts.others.render_phase_holder",
	"Qing_Remaster_scripts.others.Generation_audit_holder",
	"Qing_Remaster_scripts.others.Special_Destination_holder",
	"Qing_Remaster_scripts.others.Pedestal_Encounter_holder",
	"Qing_Remaster_scripts.auxiliary.runtime_stitch_charm_filter",
	"Qing_Remaster_scripts.auxiliary.sprite_splice_geometry",
	"Qing_Remaster_scripts.auxiliary.sprite_visual_registration",
	"Qing_Remaster_scripts.auxiliary.sprite_splice_render",
	"Qing_Remaster_scripts.auxiliary.sprite_splice",
	"Qing_Remaster_scripts.auxiliary.runtime_stitch_renderer",
	"Qing_Remaster_scripts.auxiliary.runtime_stitch_geometry",
	"Qing_Remaster_scripts.auxiliary.runtime_stitch_host_edge",
	"Qing_Remaster_scripts.auxiliary.runtime_stitch_bestiary_visual",
	"Qing_Remaster_scripts.auxiliary.screen_desync",
	"Qing_Remaster_scripts.config.runtime_stitch_donors",
	"Qing_Remaster_scripts.config.runtime_stitch_enemy_profiles",
	"Qing_Remaster_scripts.others.Parent_Collect_holder",
	"Qing_Remaster_scripts.auxiliary.native_mixture.native_reinit",
	"Qing_Remaster_scripts.auxiliary.native_mixture.compat.delirium_anim_registry",
	"Qing_Remaster_scripts.auxiliary.native_mixture.data.Extra_Mixture_data",
	"Qing_Remaster_scripts.auxiliary.native_mixture.data.Mixture_data",
	"Qing_Remaster_scripts.auxiliary.native_mixture.catalog",
	"Qing_Remaster_scripts.auxiliary.native_mixture.controller",
	"Qing_Remaster_scripts.auxiliary.runtime_stitch_visual_adapter",
	"Qing_Remaster_scripts.others.runtime_stitch_pair",
	"Qing_Remaster_scripts.others.runtime_stitch_gameplay",
	"Qing_Remaster_scripts.items.ingestion_night_visual",
	"Qing_Remaster_scripts.others.craft_tear_color_data",
	"Qing_Remaster_scripts.others.craft_tear_params_data",
	"Qing_Remaster_scripts.others.sprite_trail_presets",
	"Qing_Remaster_scripts.others.temporary_revive_manager",
	"Qing_Remaster_scripts.core.completion_marks_manager",
	"Qing_Remaster_scripts.core.thread_runtime",
	"Qing_Remaster_scripts.story.story_defs",
	"Qing_Remaster_scripts.story.story_registry",
	"Qing_Remaster_scripts.story.story_checkpoint_defs",
	"Qing_Remaster_scripts.story.story_state",
	"Qing_Remaster_scripts.story.story_progress_control",
	"Qing_Remaster_scripts.debug.story_progress_ui",
	"Qing_Remaster_scripts.debug.story_dev_lab",
	"Qing_Remaster_scripts.debug.quest_ui_debug",
	"Qing_Remaster_scripts.quest.quest_run_scope",
	"Qing_Remaster_scripts.story.story_runtime_gate",
	"Qing_Remaster_scripts.story.glaze_route_rules",
	"Qing_Remaster_scripts.story.story_scenes",
	"Qing_Remaster_scripts.story.chapter_transition",
	"Qing_Remaster_scripts.story.prologue.controller",
	"Qing_Remaster_scripts.story.prologue.home_encounter",
	"Qing_Remaster_scripts.story.prologue.ending_defs",
	"Qing_Remaster_scripts.story.prologue.ending_scene",
	"Qing_Remaster_scripts.story.chapter1.controller",
	"Qing_Remaster_scripts.story.chapter1_commission_words",
	"Qing_Remaster_scripts.story.character_defs",
	"Qing_Remaster_scripts.story.character_registry",
	"Qing_Remaster_scripts.bosses.boss_defs",
	"Qing_Remaster_scripts.bosses.boss_registry",
	"Qing_Remaster_scripts.bosses.boss_test_registry",
	"Qing_Remaster_scripts.bosses.glaze.glaze_geometry",
	"Qing_Remaster_scripts.bosses.glaze.glaze_placeholder",
	"Qing_Remaster_scripts.bosses.glaze.glaze_visual_assets",
	"Qing_Remaster_scripts.bosses.glaze.glaze_palace",
	"Qing_Remaster_scripts.bosses.glaze.glaze_mirror",
	"Qing_Remaster_scripts.bosses.glaze.glaze_shard",
	"Qing_Remaster_scripts.bosses.glaze.glaze_attacks",
	"Qing_Remaster_scripts.bosses.glaze.glaze_story_adapter",
	"Qing_Remaster_scripts.bosses.qing.qing_story_adapter",
	"Qing_Remaster_scripts.story.material_story_adapter",
	"Qing_Remaster_scripts.bosses.glaze.glaze_controller",
	"Qing_Remaster_scripts.bosses.glaze.glaze_debug",
	"Qing_Remaster_scripts.bosses.Boss_Glaze",
	"Qing_Remaster_scripts.debug.boss_test_lab",
	"Qing_Remaster_scripts.core.boss_manager",
	"Qing_Remaster_scripts.threads.bank.bank_state",
	"Qing_Remaster_scripts.threads.bank.bank_branch",
	"Qing_Remaster_scripts.threads.bank.bank_rooms",
	"Qing_Remaster_scripts.threads.bank.bank_debug",
	"Qing_Remaster_scripts.threads.stone.stone_defs",
	"Qing_Remaster_scripts.threads.stone.stone_runtime",
	"Qing_Remaster_scripts.threads.stone.stone_route",
	"Qing_Remaster_scripts.threads.stone.stone_layout",
	"Qing_Remaster_scripts.threads.stone.stone_board",
	"Qing_Remaster_scripts.threads.stone.stone_rooms",
	"Qing_Remaster_scripts.threads.stone.stone_debug",
	"Qing_Remaster_scripts.story.phase_lab.defs",
	"Qing_Remaster_scripts.story.phase_lab.state",
	"Qing_Remaster_scripts.story.phase_lab.puzzle",
	"Qing_Remaster_scripts.story.phase_lab.materials",
	"Qing_Remaster_scripts.story.phase_lab.anchor",
	"Qing_Remaster_scripts.story.phase_lab.render",
	"Qing_Remaster_scripts.story.phase_lab.controller",
	"Qing_Remaster_scripts.story.phase_lab.test",
	"Qing_Remaster_scripts.slots.Slot_Bank_Branch",
	"Qing_Remaster_scripts.auxiliary.pixel_ui",
	"Qing_Remaster_scripts.auxiliary.pause_ui",
	"Qing_Remaster_scripts.quest.quest_defs",
	"Qing_Remaster_scripts.quest.quest_registry",
	"Qing_Remaster_scripts.quest.quest_tracker",
	"Qing_Remaster_scripts.quest.quest_hud",
	"Qing_Remaster_scripts.quest.quest_draw",
	"Qing_Remaster_scripts.quest.quest_panel",
	"Qing_Remaster_scripts.story_test.story_test_defs",
	"Qing_Remaster_scripts.story_test.story_test_registry",
	"Qing_Remaster_scripts.story_test.story_test_session",
	"Qing_Remaster_scripts.story_test.story_test_transport",
	"Qing_Remaster_scripts.story_test.story_test_runner",
	"Qing_Remaster_scripts.story_test.story_test_imgui",
	"Qing_Remaster_scripts.player.character_attack_compat",
	"Qing_Remaster_scripts.player.character_attack_compat_manifest",
	"Qing_Remaster_scripts.player.character_attack_round",
	"Qing_Remaster_scripts.mimics.Familiar_Control_Selector",
	"Qing_Remaster_scripts.mimics.Craft_Bandwidth_Manager",
	"Qing_Remaster_scripts.mimics.Familiar_Follower_Arbiter",
	"Qing_Remaster_scripts.mimics.Familiar_Move_Driver",
	"Qing_Remaster_scripts.mimics.familiar_attack_classification",
	"Qing_Remaster_scripts.mimics.craft_identity",
	"Qing_Remaster_scripts.mimics.Craft_Familiar_holder",
	"Qing_Remaster_scripts.mimics.Craft_Tear_Babies_holder",
	"Qing_Remaster_scripts.mimics.Craft_Laser_Babies_holder",
	"Qing_Remaster_scripts.mimics.Craft_Advanced_Familiars_holder",
	"Qing_Remaster_scripts.mimics.Character_Advanced_Familiars_holder",
	"Qing_Remaster_scripts.mimics.Character_Gello_holder",
	"Qing_Remaster_scripts.mimics.Craft_Charged_Familiars_holder",
	"Qing_Remaster_scripts.mimics.Craft_Dash_Familiars_holder",
	"Qing_Remaster_scripts.mimics.Craft_Projectile_Familiars_holder",
	"Qing_Remaster_scripts.mimics.Craft_Orbital_holder",
	"Qing_Remaster_scripts.mimics.Craft_Orbital_Batch2_holder",
	"Qing_Remaster_scripts.mimics.Craft_Follow_Extras_holder",
	"Qing_Remaster_scripts.mimics.Craft_Resource_Familiars_holder",
	"Qing_Remaster_scripts.mimics.Craft_Bobby_holder",
	"Qing_Remaster_scripts.mimics.Craft_Paschal_holder",
	"Qing_Remaster_scripts.mimics.Craft_Crown_holder",
	"Qing_Remaster_scripts.mimics.Craft_Ludovico_holder",
	"Qing_Remaster_scripts.mimics.Craft_Evil_Eye_holder",
	"Qing_Remaster_scripts.mimics.Craft_Aux_Entities_holder",
	"Qing_Remaster_scripts.mimics.spirit_sword_geometry",
	"Qing_Remaster_scripts.mimics.Spirit_Sword_holder",
	"Qing_Remaster_scripts.pickups.pickup_blueprint_prototype",
	"Qing_Remaster_scripts.slots.slot_offer_lift",
	"Qing_Remaster_scripts.auxiliary.entity_head_anchor",
	"Qing_Remaster_scripts.auxiliary.tear_snapshot",
	"Qing_Remaster_scripts.auxiliary.laser_helper",
	"Qing_Remaster_scripts.auxiliary.pedestal_restore",
	"Qing_Remaster_scripts.auxiliary.pocket_use_semantics",
	"Qing_Remaster_scripts.auxiliary.save_elses_access",
	"Qing_Remaster_scripts.auxiliary.weapon_path_geometry",
	"Qing_Remaster_scripts.others.pocket_visual",
	"Qing_Remaster_scripts.others.player_appearance_ghost",
	"Qing_Remaster_scripts.cards.aeon_replay",
	"Qing_Remaster_scripts.cards.aeon_save_codec",
	"Qing_Remaster_scripts.callbacks.combat_output_classifier",
}

do
	local probe_registry = require("Qing_Remaster_scripts.debug.probe_registry")
	for _, path in ipairs(probe_registry.runtime_modules()) do
		manager.modules[#manager.modules + 1] = path
	end
end

local function is_probe_module(module_path)
	return type(module_path) == "string" and module_path:find("%.[%w_]+_probe$") ~= nil
end

function manager.Init()
	local env = require("Qing_Remaster_scripts.core.dev_environment")
	for _, module_path in ipairs(manager.modules) do
		if is_probe_module(module_path) then
			-- require_probe pcall-swallows load errors but prints + stores last_probe_error.
			manager.loaded[module_path] = env.require_probe(module_path)
		else
			manager.loaded[module_path] = require(module_path)
		end
	end
end

local callback_fields = {"pre_ToCall", "ToCall", "post_ToCall", "pre_myToCall", "myToCall", "post_myToCall"}
local function has_callbacks(module)
	if type(module) ~= "table" then return false end
	for _, field in ipairs(callback_fields) do if type(module[field]) == "table" and #module[field] > 0 then return true end end
	return false
end

-- Return callback-bearing preloads omitted from all business managers. The core
-- manager registers these through its normal pipeline, so callback priority and
-- REPENTOGON mapping remain centralized and object identity prevents duplicates.
function manager.collect_missing_callback_modules(groups)
	local registered = {}
	for _, group in ipairs(groups) do for _, module in ipairs(group.items or {}) do registered[module] = true end end
	local missing = {}
	manager.callback_audit.auto_registered = {}
	for _, path in ipairs(manager.modules) do
		local module = manager.loaded[path]
		if has_callbacks(module) and not registered[module] then
			missing[#missing + 1] = module
			manager.callback_audit.auto_registered[#manager.callback_audit.auto_registered + 1] = path
			registered[module] = true
		end
	end
	return missing
end

return manager
