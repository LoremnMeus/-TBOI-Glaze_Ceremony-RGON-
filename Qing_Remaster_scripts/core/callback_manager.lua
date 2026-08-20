local g = require("Qing_Remaster_scripts.core.globals")
local enums = require("Qing_Remaster_scripts.core.enums")
local Assemble_holder = require("Qing_Remaster_scripts.others.Assemble_holder")

local callback_manager = {
	items = {},
	callbacks = {},
	pre_callbacks = {},
	post_callbacks = {},
	callback_order = {"pre_","","post_",},
	own_key = "Callback_manager_",
}
Assemble_holder.register_on(callback_manager.own_key,callback_manager,{force = true,})

function callback_manager.Init(mod)
	table.insert(callback_manager.items,#callback_manager.items + 1,require("Qing_Remaster_scripts.callbacks.collectible_holder"))
	table.insert(callback_manager.items,#callback_manager.items + 1,require("Qing_Remaster_scripts.callbacks.teleport_holder"))
	table.insert(callback_manager.items,#callback_manager.items + 1,require("Qing_Remaster_scripts.callbacks.basic_holder"))
	table.insert(callback_manager.items,#callback_manager.items + 1,require("Qing_Remaster_scripts.callbacks.item_displaying_holder"))
	table.insert(callback_manager.items,#callback_manager.items + 1,require("Qing_Remaster_scripts.callbacks.qing_s_knife_holder"))
	table.insert(callback_manager.items,#callback_manager.items + 1,require("Qing_Remaster_scripts.callbacks.next_level_holder"))
	table.insert(callback_manager.items,#callback_manager.items + 1,require("Qing_Remaster_scripts.callbacks.every_entity_holder"))
	table.insert(callback_manager.items,#callback_manager.items + 1,require("Qing_Remaster_scripts.callbacks.imitate_item_holder"))
	table.insert(callback_manager.items,#callback_manager.items + 1,require("Qing_Remaster_scripts.others.temporary_revive_manager"))
	table.insert(callback_manager.items,#callback_manager.items + 1,require("Qing_Remaster_scripts.callbacks.temp_item_hud_holder"))
	table.insert(callback_manager.items,#callback_manager.items + 1,require("Qing_Remaster_scripts.callbacks.price_holder"))
	table.insert(callback_manager.items,#callback_manager.items + 1,require("Qing_Remaster_scripts.callbacks.custom_price_holder"))
	table.insert(callback_manager.items,#callback_manager.items + 1,require("Qing_Remaster_scripts.callbacks.revive_holder"))
	table.insert(callback_manager.items,#callback_manager.items + 1,require("Qing_Remaster_scripts.callbacks.item_pool_holder"))
	table.insert(callback_manager.items,#callback_manager.items + 1,require("Qing_Remaster_scripts.callbacks.anna_portal_holder"))
	table.insert(callback_manager.items,#callback_manager.items + 1,require("Qing_Remaster_scripts.callbacks.player_offset_holder"))
	table.insert(callback_manager.items,#callback_manager.items + 1,require("Qing_Remaster_scripts.callbacks.slot_render_holder"))
	table.insert(callback_manager.items,#callback_manager.items + 1,require("Qing_Remaster_scripts.callbacks.laser_holder"))
	table.insert(callback_manager.items,#callback_manager.items + 1,require("Qing_Remaster_scripts.callbacks.tear_trigger_holder"))
	if REPENTOGON then
		table.insert(callback_manager.items,#callback_manager.items + 1,require("Qing_Remaster_scripts.callbacks.repentogon_holder"))
		table.insert(callback_manager.items,#callback_manager.items + 1,require("Qing_Remaster_scripts.callbacks.rgon_imgui_options_holder"))
		table.insert(callback_manager.items,#callback_manager.items + 1,require("Qing_Remaster_scripts.callbacks.rgon_menu_language_holder"))
		table.insert(callback_manager.items,#callback_manager.items + 1,require("Qing_Remaster_scripts.callbacks.title_menu_marquee_holder"))
	end
end

function callback_manager.work(callback_name,runner,stop_value,force_local)
	if REPENTOGON then
		if enums.REPENTOGON_CALLBACK_MAP[callback_name] and not force_local then return end
	end
	local stopped
	local ok,err = pcall(function()
		for order_index = 1,3 do
			local callbacks = callback_manager[callback_manager.callback_order[order_index].."callbacks"][callback_name]
			if callbacks then
				for _,callback_info in pairs(callbacks) do
					if callback_info.Function then
						local result = runner(callback_info.Function,callback_info.params)
						if stop_value ~= nil and result ~= nil and result == stop_value then
							stopped = stop_value
							return
						end
					end
				end
			end
		end
	end)
	if err then print(err) end
	return stopped
end

function callback_manager.work_with_result(callback_name,runner,initial_value,stop_condition)
	local value = initial_value
	for order_index = 1,3 do
		local callbacks = callback_manager[callback_manager.callback_order[order_index].."callbacks"][callback_name]
		if callbacks then
			for _,callback_info in pairs(callbacks) do
				if callback_info.Function then
					local result = runner(callback_info.Function,callback_info.params,value)
					if stop_condition ~= nil then
						if type(stop_condition) == "function" then
							if stop_condition(result) then return result end
						elseif result ~= nil and result == stop_condition then
							return result
						end
					end
					if result ~= nil then
						value = result
					end
				end
			end
		end
	end
	return value
end

return callback_manager
