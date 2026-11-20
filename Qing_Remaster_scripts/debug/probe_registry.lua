-- Probe lifecycle and Probes ImGui classification: single source of truth.
-- `runtime` means an active temporary probe; `permanent` marks a long-term
-- inspector backed by normal runtime code. A source file alone registers nothing.
local registry = {}

-- Canonical probe-window tabs (8). Legacy keys visual/runtime alias to new pages
-- so any missed category string still resolves to a real Tab element id.
registry.PROBE_PAGE = {
	items = "probe_items",
	characters = "probe_characters",
	combat = "probe_combat",
	render = "probe_render",
	rooms = "probe_rooms",
	story = "probe_story",
	systems = "probe_systems",
	experiments = "probe_experiments",
	-- LEGACY aliases (same page ids; do not create separate tabs)
	visual = "probe_render",
	runtime = "probe_systems",
}

-- Ordered tab keys for ImGui creation (excludes legacy aliases).
registry.PROBE_TAB_ORDER = {
	"items",
	"characters",
	"combat",
	"render",
	"rooms",
	"story",
	"systems",
	"experiments",
}

local entries = {
	-- items
	rooted_demon_performance = {
		runtime = "Qing_Remaster_scripts.debug.rooted_demon_performance_probe",
		ui = {id = "audit_rooted_demon_performance", category = "items"},
	},
	tiny_update_charge = {
		runtime = "Qing_Remaster_scripts.debug.tiny_update_charge_probe",
		ui = {id = "audit_tiny_update_charge", category = "items"},
	},
	tiny_update_commit = {
		runtime = "Qing_Remaster_scripts.debug.tiny_update_commit_probe",
		ui = {id = "audit_tiny_update_commit", category = "items"},
	},
	matryoshka_marbles_split = {
		runtime = "Qing_Remaster_scripts.debug.matryoshka_marbles_split_probe",
		ui = {id = "audit_matryoshka_marbles_split", category = "items"},
	},
	aeon_replay = {
		runtime = "Qing_Remaster_scripts.others.aeon_replay_probe",
		ui = {id = "audit_aeon_replay", category = "items"},
	},
	devils_heart_debt = {
		runtime = "Qing_Remaster_scripts.debug.devils_heart_debt_probe",
		ui = {id = "audit_devils_heart_debt", category = "items"},
	},
	gold_rush_grid = {
		runtime = "Qing_Remaster_scripts.debug.gold_rush_grid_probe",
		ui = {id = "audit_gold_rush_grid", category = "items"},
	},
	spectralsword_hud = {
		runtime = "Qing_Remaster_scripts.debug.spectralsword_hud_probe",
		ui = {id = "audit_spectralsword_hud", category = "items"},
	},
	spectralsword_input = {
		runtime = "Qing_Remaster_scripts.debug.spectralsword_input_probe",
		ui = {id = "audit_spectralsword_input", category = "items"},
	},
	spectralsword_lazarus_identity = {
		runtime = "Qing_Remaster_scripts.debug.spectralsword_lazarus_identity_probe",
		ui = {id = "audit_spectralsword_lazarus_identity", category = "items"},
	},
	cursed_mask_craft_link = {
		runtime = "Qing_Remaster_scripts.debug.cursed_mask_craft_link_probe",
		ui = {id = "audit_cursed_mask_craft_link", category = "items"},
	},
	tarot_reverse_pool = {
		runtime = "Qing_Remaster_scripts.debug.tarot_reverse_pool_probe",
		ui = {id = "audit_tarot_reverse_pool", category = "items"},
	},
	suture_needle = {
		runtime = "Qing_Remaster_scripts.others.suture_needle_probe",
		ui = {id = "audit_suture_needle", category = "items"},
	},
	isolation_spawn = {
		runtime = "Qing_Remaster_scripts.others.isolation_spawn_probe",
		ui = {id = "audit_isolation_spawn", category = "items"},
	},
	alien_savior = {
		runtime = "Qing_Remaster_scripts.debug.alien_savior_probe",
		ui = {id = "audit_alien_savior", category = "items"},
	},
	incandescence_flame = {
		runtime = "Qing_Remaster_scripts.debug.incandescence_flame_probe",
		ui = {id = "audit_incandescence_flame", category = "items"},
	},
	celestial_stars = {
		runtime = "Qing_Remaster_scripts.others.celestial_stars_probe",
		ui = {id = "audit_celestial_stars", category = "items"},
	},
	celestial_tear_lifecycle = {
		runtime = "Qing_Remaster_scripts.others.celestial_tear_lifecycle_probe",
		ui = {id = "audit_celestial_tear_lifecycle", category = "items"},
	},
	nihilistic_eye_record = {
		runtime = "Qing_Remaster_scripts.others.nihilistic_eye_record_probe",
		ui = {id = "audit_nihilistic_eye_record", category = "items"},
	},
	seeker_wall = {
		permanent = true,
		ui = {id = "item_seeker_wall_probe", category = "items"},
	},
	glaze_chest = {
		permanent = true,
		ui = {id = "audit_glaze_chest", category = "items"},
	},
	blueprint_eid = {
		permanent = true,
		ui = {id = "audit_blueprint_eid", category = "items"},
	},
	flight_orbital = {
		permanent = true,
		ui = {id = "item_flight_orbital_probe", category = "items"},
	},

	-- characters
	anna_attack_range = {
		runtime = "Qing_Remaster_scripts.debug.anna_attack_range_probe",
		ui = {id = "audit_anna_attack_range", category = "characters"},
	},

	-- combat
	attack_audit = {
		runtime = "Qing_Remaster_scripts.others.attack_audit_probe",
		ui = {id = "audit_attack_audit", category = "combat"},
	},
	sting_reversed_damage = {
		runtime = "Qing_Remaster_scripts.debug.sting_reversed_damage_probe",
		ui = {id = "audit_sting_reversed_damage", category = "combat"},
	},
	faint_projectile_z_corr = {
		runtime = "Qing_Remaster_scripts.debug.faint_projectile_z_corr_probe",
		ui = {id = "audit_faint_projectile_z_corr", category = "combat"},
	},
	faint_npc_motion = {
		runtime = "Qing_Remaster_scripts.debug.faint_npc_motion_probe",
		ui = {id = "audit_faint_npc_motion", category = "combat"},
	},
	pin_62_visibility = {
		runtime = "Qing_Remaster_scripts.debug.pin_62_visibility_probe",
		ui = {id = "audit_pin_62_visibility", category = "combat"},
	},
	monstro_20_visibility = {
		runtime = "Qing_Remaster_scripts.debug.monstro_20_visibility_probe",
		ui = {id = "audit_monstro_20_visibility", category = "combat"},
	},
	swarm_spider_884_visibility = {
		runtime = "Qing_Remaster_scripts.debug.swarm_spider_884_visibility_probe",
		ui = {id = "audit_swarm_spider_884_visibility", category = "combat"},
	},
	profound_heartbeat = {
		runtime = "Qing_Remaster_scripts.debug.profound_heartbeat_probe",
		ui = {id = "audit_profound_heartbeat", category = "combat"},
	},
	heartbeat_sfx_capture = {
		runtime = "Qing_Remaster_scripts.debug.heartbeat_sfx_capture_probe",
		ui = {id = "audit_heartbeat_sfx_capture", category = "combat"},
	},

	-- render
	native_sprite_render_compare = {
		runtime = "Qing_Remaster_scripts.debug.native_sprite_render_compare_probe",
		ui = {id = "audit_native_sprite_render_compare", category = "render"},
	},
	pause_sprite_shift = {
		runtime = "Qing_Remaster_scripts.debug.pause_sprite_shift_probe",
		ui = {id = "audit_pause_sprite_shift", category = "render"},
	},
	sprite_splice = {
		runtime = "Qing_Remaster_scripts.debug.sprite_splice_probe",
		ui = {id = "audit_sprite_splice", category = "render"},
	},
	runtime_stitch = {
		runtime = "Qing_Remaster_scripts.others.runtime_stitch_test_probe",
		ui = {id = "audit_runtime_stitch", category = "render"},
	},
	tianyi_walk_clock = {
		runtime = "Qing_Remaster_scripts.debug.tianyi_walk_clock_probe",
		ui = {id = "audit_tianyi_walk_clock", category = "render"},
	},
	player_appearance_ghost = {
		runtime = "Qing_Remaster_scripts.debug.player_appearance_ghost_probe",
		ui = {id = "audit_player_appearance_ghost", category = "render"},
	},
	remaster_ghost_render = {
		runtime = "Qing_Remaster_scripts.debug.remaster_ghost_render_probe",
		ui = {id = "audit_remaster_ghost_render", category = "render"},
	},
	player_vfx_layer = {
		runtime = "Qing_Remaster_scripts.debug.player_vfx_layer_probe",
		ui = {id = "audit_player_vfx_layer", category = "render"},
	},
	held_reward_consistency = {
		runtime = "Qing_Remaster_scripts.debug.held_reward_consistency_probe",
		ui = {id = "audit_held_reward_consistency", category = "render"},
	},
	pocket_pill_visual = {
		runtime = "Qing_Remaster_scripts.debug.pocket_pill_visual_probe",
		ui = {id = "audit_pocket_pill_visual", category = "render"},
	},

	-- rooms
	grid_rock_topology = {
		runtime = "Qing_Remaster_scripts.debug.grid_rock_topology_probe",
		ui = {id = "audit_grid_rock_topology", category = "rooms"},
	},
	essm_hourglass = {
		runtime = "Qing_Remaster_scripts.debug.essm_hourglass_probe",
		ui = {id = "audit_essm_hourglass", category = "rooms"},
	},
	portal_restore_rewind = {
		runtime = "Qing_Remaster_scripts.debug.portal_restore_rewind_probe",
		ui = {id = "audit_portal_restore_rewind", category = "rooms"},
	},
	empress_d6_timeline = {
		runtime = "Qing_Remaster_scripts.debug.empress_d6_timeline_probe",
		ui = {id = "audit_empress_d6_timeline", category = "rooms"},
	},

	-- story
	stone_render = {
		runtime = "Qing_Remaster_scripts.debug.stone_render_probe",
		ui = {id = "audit_stone_render", category = "story"},
	},
	wind_pipeline = {
		runtime = "Qing_Remaster_scripts.threads.wind.wind_pipeline_probe",
		ui = {id = "audit_wind_pipeline", category = "story"},
	},

	-- systems (former systems + runtime)
	attribute_holder = {
		permanent = true,
		ui = {id = "audit_attribute_holder", category = "systems"},
	},
	consistance_holder = {
		permanent = true,
		ui = {id = "audit_consistance_holder", category = "systems"},
	},
	imitate = {
		permanent = true,
		ui = {id = "audit_imitate", category = "systems"},
	},
	player_identity = {
		runtime = "Qing_Remaster_scripts.debug.player_identity_probe",
		ui = {id = "audit_player_identity", category = "systems"},
	},
}

local runtime_index = {}
local ui_index = {}

for key, entry in pairs(entries) do
	if entry.runtime then
		assert(runtime_index[entry.runtime] == nil, "duplicate probe runtime path: " .. tostring(entry.runtime))
		runtime_index[entry.runtime] = entry
	end
	if entry.ui then
		assert(entry.ui.id, "probe UI missing id: " .. tostring(key))
		assert(entry.ui.category, "probe UI missing category: " .. tostring(entry.ui.category))
		assert(registry.PROBE_PAGE[entry.ui.category], "invalid probe category: " .. tostring(entry.ui.category))
		assert(ui_index[entry.ui.id] == nil, "duplicate probe UI id: " .. tostring(entry.ui.id))
		ui_index[entry.ui.id] = entry
	end
end

function registry.runtime_modules()
	local result = {}
	for path in pairs(runtime_index) do result[#result + 1] = path end
	table.sort(result)
	return result
end

function registry.is_runtime_active(path)
	return runtime_index[path] ~= nil
end

function registry.get_ui(module_id)
	local entry = ui_index[module_id]
	if not entry then return nil end
	return {
		page = registry.PROBE_PAGE[entry.ui.category],
		category = entry.ui.category,
		runtime = entry.runtime,
		permanent = entry.permanent == true,
	}
end

function registry.get_by_runtime(path)
	return runtime_index[path]
end

function registry.entries()
	return entries
end

return registry
