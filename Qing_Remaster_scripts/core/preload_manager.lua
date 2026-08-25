-- 启动期模块预加载：在其他模组改写全局 require 搜索路径前写入 package.loaded。
-- 新增运行时 helper/data 或可能延迟首次使用的模块时，统一登记在这里。
local manager = {}
manager.loaded = {}
manager.callback_audit = {auto_registered = {}}

manager.modules = {
	"Qing_Remaster_scripts.core.dev_environment",
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
	"Qing_Remaster_scripts.others.craft_aura_effects",
	"Qing_Remaster_scripts.others.craft_charge_weapons",
	"Qing_Remaster_scripts.others.craft_orbiting_tears",
	"Qing_Remaster_scripts.others.craft_zodiac",
	"Qing_Remaster_scripts.others.craft_taurus",
	"Qing_Remaster_scripts.others.pareidolia_moon_render",
	"Qing_Remaster_scripts.others.craft_orbiting_tear_offset_probe",
	"Qing_Remaster_scripts.others.craft_laser_flag_probe",
	"Qing_Remaster_scripts.others.craft_knife_path_probe",
	"Qing_Remaster_scripts.others.craft_evil_eye_vanilla_probe",
	"Qing_Remaster_scripts.others.vengeful_spirit_vanilla_probe",
	"Qing_Remaster_scripts.others.vengeful_craft_lifecycle_probe",
	"Qing_Remaster_scripts.others.craft_path_tear_vanilla_probe",
	"Qing_Remaster_scripts.others.craft_floor_stat_counter_probe",
	"Qing_Remaster_scripts.others.time_stop_probe",
	"Qing_Remaster_scripts.others.destiny_anchor_probe",
	"Qing_Remaster_scripts.others.craft_tear_color_data",
	"Qing_Remaster_scripts.others.craft_tear_params_data",
	"Qing_Remaster_scripts.others.sprite_trail_presets",
	"Qing_Remaster_scripts.others.temporary_revive_manager",
	"Qing_Remaster_scripts.core.completion_marks_manager",
	"Qing_Remaster_scripts.core.thread_runtime",
	"Qing_Remaster_scripts.player.character_attack_compat",
	"Qing_Remaster_scripts.player.character_attack_compat_manifest",
	"Qing_Remaster_scripts.mimics.Familiar_Control_Selector",
	"Qing_Remaster_scripts.mimics.Craft_Bandwidth_Manager",
	"Qing_Remaster_scripts.mimics.Familiar_Follower_Arbiter",
	"Qing_Remaster_scripts.mimics.Familiar_Move_Driver",
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
	"Qing_Remaster_scripts.pickups.pickup_blueprint_prototype",
	"Qing_Remaster_scripts.slots.slot_offer_lift",
}

local function is_probe_module(module_path)
	return type(module_path) == "string" and module_path:find("_probe", 1, true) ~= nil
end

function manager.Init()
	local env = require("Qing_Remaster_scripts.core.dev_environment")
	for _, module_path in ipairs(manager.modules) do
		if is_probe_module(module_path) then
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
