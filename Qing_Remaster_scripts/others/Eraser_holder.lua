local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	targets = {},
}
--在这里擦除所有无关内容
function item.add_eraser_spawner_effect(ent)
	table.insert(item.targets,ent)
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	item.targets = {}
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_INIT, params = 15,
Function = function(_,ent)
	for i = #item.targets,1,-1 do
		local v = item.targets[i]
		if auxi.check_all_exists(v) ~= true or v.FrameCount > 1 then table.remove(item.targets,i)
		else 
			if (v.Position - ent.Position):Length() < 10 then 
				ent:Remove()
				return
			end
		end
	end
end,
})


return item