local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")

local modReference
local manager = {
	items = {},
}

function manager.Init(mod)
	modReference = mod
	table.insert(manager.items,#manager.items + 1,require("Qing_Remaster_scripts.level.Level_Shaddoll"))
	--manager.Make()
end

function manager.Make()				--没有传入参数。
	for i = 1,#manager.items do
		if manager.items[i].ToCall then
			for j = 1,#(manager.items[i].ToCall) do
				if manager.items[i].ToCall[j] ~= nil and manager.items[i].ToCall[j].Function ~= nil and manager.items[i].ToCall[j].CallBack ~= nil then
					if manager.items[i].ToCall[j].params == nil then
						modReference:AddCallback(manager.items[i].ToCall[j].CallBack,manager.items[i].ToCall[j].Function)
					else
						modReference:AddCallback(manager.items[i].ToCall[j].CallBack,manager.items[i].ToCall[j].Function,manager.items[i].ToCall[j].params)
					end
				end
			end
		end
	end
end

return manager
