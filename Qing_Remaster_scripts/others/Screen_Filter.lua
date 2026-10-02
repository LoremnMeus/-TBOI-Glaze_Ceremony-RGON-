local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	should_filter = 0,
	should_filter_update = 0,
	soft_alpha = 0,
	alpha_map = {
		{frame = 0,alpha = 0,},
		{frame = 2,alpha = 1,},
	},
}

local s = Sprite()
s:Load("gfx/Black.anm2",true)
s:Play("Idle",true)

function item.add_filter(t1,t2)
	item.should_filter = math.max(item.should_filter, t1 or 0)
	if t2 then item.should_filter_update = math.max(item.should_filter_update, t2) end
end

function item.add_soft_filter(alpha)
	alpha = tonumber(alpha) or 0
	if alpha <= 0 then return end
	alpha = math.max(0, math.min(alpha, 1))
	item.soft_alpha = math.max(item.soft_alpha or 0, alpha)
end

local function clear_filter()
	item.should_filter = 0
	item.should_filter_update = 0
	item.soft_alpha = 0
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(_)
	local succ = false
	if (item.should_filter or 0) > 0 then
		item.should_filter = item.should_filter - 1
		succ = true
	end
	if (item.should_filter_update or 0) > 0 then
		succ = true
		-- POST_UPDATE 在暂停/控制台期间不跑；若不在此扣减，update 计时会把全屏 Black 钉死到永久黑屏。
		if Game():IsPaused() then
			item.should_filter_update = item.should_filter_update - 1
		end
	end
	local hard_alpha = 0
	if succ then
		hard_alpha = auxi.check_lerp(
			math.max(item.should_filter, item.should_filter_update * 3),
			item.alpha_map
		).alpha
	end
	-- 30Hz consumers request once per logic frame; do not zero here or 60Hz POST_RENDER would flicker.
	local final_alpha = math.max(hard_alpha, item.soft_alpha or 0)
	if final_alpha > 0.001 then
		s.Color = Color(1, 1, 1, final_alpha)
		s:Render(Vector(0, 0), Vector(0, 0), Vector(0, 0))
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_UPDATE, params = nil,
Function = function(_)
	item.soft_alpha = 0
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	if (item.should_filter_update or 0) > 0 then
		item.should_filter_update = item.should_filter_update - 1
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil,
Function = function(_)
	clear_filter()
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_END, params = nil,
Function = function(_)
	clear_filter()
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_GAME_STARTED, params = nil,
Function = function(_)
	clear_filter()
end,
})

return item
