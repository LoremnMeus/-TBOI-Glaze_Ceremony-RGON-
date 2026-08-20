local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	should_filter = 0,
	should_filter_update = 0,
	alpha_map = {
		{frame = 0,alpha = 0,},
		{frame = 2,alpha = 1,},
	},
}

local s = Sprite()
s:Load("gfx/Black.anm2",true)
s:Play("Idle",true)

function item.add_filter(t1,t2)
	item.should_filter = math.max(item.should_filter,t1)
	if t2 then item.should_filter_update = math.max(item.should_filter_update,t2) end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	local succ = false
	if (item.should_filter or 0) > 0 then item.should_filter = item.should_filter - 1 succ = true end
	if (item.should_filter_update or 0) > 0 then succ = true end
	if succ then local alpha = auxi.check_lerp(math.max(item.should_filter,item.should_filter_update * 3),item.alpha_map).alpha s.Color = Color(1,1,1,alpha) s:Render(Vector(0,0),Vector(0,0),Vector(0,0)) end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if (item.should_filter_update or 0) > 0 then item.should_filter_update = item.should_filter_update - 1 end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_,shouldsave)
	item.should_filter = 0
	item.should_filter_update = 0
end,
})

return item