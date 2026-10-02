-- Probe lifecycle and Probes ImGui classification: single source of truth.
-- `runtime` means an active temporary probe; `permanent` marks a long-term
-- inspector backed by normal runtime code. A source file alone registers nothing.
local registry = {}

registry.PROBE_PAGE = {
	items = "probe_items",
	characters = "probe_characters",
	systems = "probe_systems",
	visual = "probe_visual",
	runtime = "probe_runtime",
}

local entries = {
	attack_audit = {
		runtime = "Qing_Remaster_scripts.others.attack_audit_probe",
		ui = {id = "audit_attack_audit", category = "systems"},
	},
	runtime_stitch = {
		runtime = "Qing_Remaster_scripts.others.runtime_stitch_test_probe",
		ui = {id = "audit_runtime_stitch", category = "runtime"},
	},
	suture_needle = {
		runtime = "Qing_Remaster_scripts.others.suture_needle_probe",
		ui = {id = "audit_suture_needle", category = "runtime"},
	},
	native_sprite_render_compare = {
		runtime = "Qing_Remaster_scripts.debug.native_sprite_render_compare_probe",
		ui = {id = "audit_native_sprite_render_compare", category = "visual"},
	},
	pause_sprite_shift = {
		runtime = "Qing_Remaster_scripts.debug.pause_sprite_shift_probe",
		ui = {id = "audit_pause_sprite_shift", category = "visual"},
	},
	sprite_splice = {
		runtime = "Qing_Remaster_scripts.debug.sprite_splice_probe",
		ui = {id = "audit_sprite_splice", category = "visual"},
	},
	empress_d6_timeline = {
		runtime = "Qing_Remaster_scripts.debug.empress_d6_timeline_probe",
		ui = {id = "audit_empress_d6_timeline", category = "runtime"},
	},
	faint_projectile_z_corr = {
		runtime = "Qing_Remaster_scripts.debug.faint_projectile_z_corr_probe",
		ui = {id = "audit_faint_projectile_z_corr", category = "visual"},
	},
	faint_npc_motion = {
		runtime = "Qing_Remaster_scripts.debug.faint_npc_motion_probe",
		ui = {id = "audit_faint_npc_motion", category = "visual"},
	},
	profound_heartbeat = {
		runtime = "Qing_Remaster_scripts.debug.profound_heartbeat_probe",
		ui = {id = "audit_profound_heartbeat", category = "runtime"},
	},
	heartbeat_sfx_capture = {
		runtime = "Qing_Remaster_scripts.debug.heartbeat_sfx_capture_probe",
		ui = {id = "audit_heartbeat_sfx_capture", category = "runtime"},
	},
	aeon_replay = {
		runtime = "Qing_Remaster_scripts.others.aeon_replay_probe",
		ui = {id = "audit_aeon_replay", category = "items"},
	},
	tianyi_walk_clock = {
		runtime = "Qing_Remaster_scripts.debug.tianyi_walk_clock_probe",
		ui = {id = "audit_tianyi_walk_clock", category = "visual"},
	},
	player_appearance_ghost = {
		runtime = "Qing_Remaster_scripts.debug.player_appearance_ghost_probe",
		ui = {id = "audit_player_appearance_ghost", category = "visual"},
	},
	held_reward_consistency = {
		runtime = "Qing_Remaster_scripts.debug.held_reward_consistency_probe",
		ui = {id = "audit_held_reward_consistency", category = "visual"},
	},
	devils_heart_debt = {
		runtime = "Qing_Remaster_scripts.debug.devils_heart_debt_probe",
		ui = {id = "audit_devils_heart_debt", category = "items"},
	},
	sting_reversed_damage = {
		runtime = "Qing_Remaster_scripts.debug.sting_reversed_damage_probe",
		ui = {id = "audit_sting_reversed_damage", category = "items"},
	},
	gold_rush_grid = {
		runtime = "Qing_Remaster_scripts.debug.gold_rush_grid_probe",
		ui = {id = "audit_gold_rush_grid", category = "items"},
	},
	pin_62_visibility = {
		runtime = "Qing_Remaster_scripts.debug.pin_62_visibility_probe",
		ui = {id = "audit_pin_62_visibility", category = "visual"},
	},
	monstro_20_visibility = {
		runtime = "Qing_Remaster_scripts.debug.monstro_20_visibility_probe",
		ui = {id = "audit_monstro_20_visibility", category = "visual"},
	},
	swarm_spider_884_visibility = {
		runtime = "Qing_Remaster_scripts.debug.swarm_spider_884_visibility_probe",
		ui = {id = "audit_swarm_spider_884_visibility", category = "visual"},
	},
	grid_rock_topology = {
		runtime = "Qing_Remaster_scripts.debug.grid_rock_topology_probe",
		ui = {id = "audit_grid_rock_topology", category = "systems"},
	},
	essm_hourglass = {
		runtime = "Qing_Remaster_scripts.debug.essm_hourglass_probe",
		ui = {id = "audit_essm_hourglass", category = "systems"},
	},
	spirit_sword_lifecycle = {
		runtime = "Qing_Remaster_scripts.debug.spirit_sword_lifecycle_probe",
		ui = {id = "audit_spirit_sword_lifecycle", category = "systems"},
	},
	spirit_sword_spin_replay = {
		runtime = "Qing_Remaster_scripts.debug.spirit_sword_spin_replay_probe",
		ui = {id = "audit_spirit_sword_spin_replay", category = "systems"},
	},
	spirit_sword_replay_sandbox = {
		runtime = "Qing_Remaster_scripts.debug.spirit_sword_replay_sandbox",
		ui = {id = "audit_spirit_sword_replay_sandbox", category = "systems"},
	},
	spirit_sword_feel = {
		runtime = "Qing_Remaster_scripts.debug.spirit_sword_feel_probe",
		ui = {id = "audit_spirit_sword_feel", category = "systems"},
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
	seeker_wall = {
		permanent = true,
		ui = {id = "item_seeker_wall_probe", category = "items"},
	},
	attribute_holder = {
		permanent = true,
		ui = {id = "audit_attribute_holder", category = "systems"},
	},
	consistance_holder = {
		permanent = true,
		ui = {id = "audit_consistance_holder", category = "systems"},
	},
	glaze_chest = {
		permanent = true,
		ui = {id = "audit_glaze_chest", category = "items"},
	},
	blueprint_eid = {
		permanent = true,
		ui = {id = "audit_blueprint_eid", category = "items"},
	},
	imitate = {
		permanent = true,
		ui = {id = "audit_imitate", category = "systems"},
	},
	flight_orbital = {
		permanent = true,
		ui = {id = "item_flight_orbital_probe", category = "items"},
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
		assert(entry.ui.category, "probe UI missing category: " .. tostring(key))
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
