local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local modReference
local manager = {
	items = {},
	t_order = {"pre_","","post_",},
	t_priority = {-100,0,100,},
}
local callback_manager = require("Qing_Remaster_scripts.core.callback_manager")

function manager.Init(mod)
	modReference = mod
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.core.others_manager"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.core.enemy_manager"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.core.player_manager"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.core.item_manager"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.core.pickup_manager"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.core.mimics_manager"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.core.callback_manager"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.core.thread_mamager"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.core.grid_manager"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.core.slot_manager"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.core.challanges_manager"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.core.level_manager"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.core.card_manager"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.core.room_manager"))
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.core.trinket_manager"))
	manager.Make(mod)
end

function manager.Make(mod)
	for k = 1,#manager.items do
		manager.items[k].Init(mod)
	end
	local preload_manager = require("Qing_Remaster_scripts.core.preload_manager")
	local missing = preload_manager.collect_missing_callback_modules(manager.items)
	if #missing > 0 then
		for _, module in ipairs(missing) do if module.Init then module.Init(mod) end end
		table.insert(manager.items, {items = missing, Init = function() end})
	end
	for uk = 1,3 do
		for k = 1,#manager.items do
			for i = 1,#(manager.items[k].items) do
				if manager.items[k].items[i][manager.t_order[uk].."ToCall"] then
					for j = 1,#(manager.items[k].items[i][manager.t_order[uk].."ToCall"]) do
						if manager.items[k].items[i][manager.t_order[uk].."ToCall"][j] ~= nil and manager.items[k].items[i][manager.t_order[uk].."ToCall"][j].Function ~= nil and manager.items[k].items[i][manager.t_order[uk].."ToCall"][j].CallBack ~= nil then
							local tg = manager.items[k].items[i][manager.t_order[uk].."ToCall"][j]
							--if tg.priority == nil then modReference:AddCallback(tg.CallBack,tg.Function,tg.params)
							--else modReference:AddPriorityCallback(tg.CallBack,tg.priority,tg.Function,tg.params) end
							modReference:AddPriorityCallback(tg.CallBack,(tg.priority or 0) + manager.t_priority[uk],tg.Function,tg.params)
						end
					end
				end
			end
		end
		for k = 1,#manager.items do
			for i = 1,#(manager.items[k].items) do
				if manager.items[k].items[i][manager.t_order[uk].."myToCall"] then
					for j = 1,#(manager.items[k].items[i][manager.t_order[uk].."myToCall"]) do
						if manager.items[k].items[i][manager.t_order[uk].."myToCall"][j] ~= nil and manager.items[k].items[i][manager.t_order[uk].."myToCall"][j].Function ~= nil and manager.items[k].items[i][manager.t_order[uk].."myToCall"][j].CallBack ~= nil then
							local tg = manager.items[k].items[i][manager.t_order[uk].."myToCall"][j]
							callback_manager[manager.t_order[uk].."callbacks"][tg.CallBack] = callback_manager[manager.t_order[uk].."callbacks"][tg.CallBack] or {}
							table.insert(callback_manager[manager.t_order[uk].."callbacks"][tg.CallBack],{Function = tg.Function,params = tg.params,priority = (tg.priority or 0) + manager.t_priority[uk],})
							if REPENTOGON and enums.REPENTOGON_CALLBACK_MAP[tg.CallBack] then
								local info = auxi.check_if_any(enums.REPENTOGON_CALLBACK_MAP[tg.CallBack],tg)
								if type(info) == "number" then info = {CallBack = info,params = tg.params,Function = tg.Function,} end
								if type(info) == "table" then modReference:AddPriorityCallback(info.CallBack,(tg.priority or 0) + manager.t_priority[uk],info.Function or tg.Function,info.params or tg.params) end
							end
						end
					end
				end
			end
		end
		for u,v in pairs(callback_manager[manager.t_order[uk].."callbacks"]) do
			table.sort(callback_manager[manager.t_order[uk].."callbacks"][u],function(a,b) return (a.priority or 0) < (b.priority or 0) end)
		end
	end
end

return manager
