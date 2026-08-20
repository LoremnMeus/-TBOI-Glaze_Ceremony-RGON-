local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")

local modReference
local item = {
	items = {},
}

function item.Init(mod)
	modReference = mod
	table.insert(item.items,#item.items + 1,require("Qing_Remaster_scripts.threads.thread_Glaze"))
	table.insert(item.items,#item.items + 1,require("Qing_Remaster_scripts.threads.thread_Coin"))
	table.insert(item.items,#item.items + 1,require("Qing_Remaster_scripts.threads.thread_Meat"))
	table.insert(item.items,#item.items + 1,require("Qing_Remaster_scripts.threads.thread_Stone"))
	table.insert(item.items,#item.items + 1,require("Qing_Remaster_scripts.threads.thread_Wind"))
	table.insert(item.items,#item.items + 1,require("Qing_Remaster_scripts.threads.thread_End1"))
	table.insert(item.items,#item.items + 1,require("Qing_Remaster_scripts.threads.thread_End2"))
	table.insert(item.items,#item.items + 1,require("Qing_Remaster_scripts.threads.thread_End2_2"))
	--table.insert(item.items,#item.items + 1,require("Qing_Remaster_scripts.threads.thread_Start"))
	--table.insert(item.items,#item.items + 1,require("Qing_Remaster_scripts.threads.thread_Shaddoll"))
	--table.insert(item.items,#item.items + 1,require("Qing_Remaster_scripts.threads.thread_Zeis"))
end

return item
