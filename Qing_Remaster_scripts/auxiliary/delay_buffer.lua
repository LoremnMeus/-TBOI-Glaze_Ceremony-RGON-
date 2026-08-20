local enums = require("Qing_Remaster_scripts.core.enums")
local item = {
	pre_ToCall = {},
	ToCall = {},
	pre_myToCall = {},
	myToCall = {},
	own_key = "Delay_buffer_",
	buffer = {},
}

local function check_mode(v1,v2)
	if type(v1) == "table" then 
		v2 = v2 or v1.isshader 
		v1 = v1.isrender
	end
	if v1 == true then return 2 end
	if v2 == true then return 3 end
	return 1
end

local function check_params(v1,v2)
	if type(v1) == "table" then return v1 end
	if type(v2) == "table" then return v2 end
	return {isrender = v1,isshader = v2,}
end

function item.addeffe(f,params,tm,isrender,isshader)
	local tbl = {func = f,params = params,TimeD = tm or 0,render_mode = check_mode(isrender,isshader),params2 = check_params(isrender,isshader),}
	table.insert(item.buffer,tbl)
end

function item.check_over_buffer(id)
	id = id or 1
	for i = #item.buffer,1,-1 do
		if item.buffer[i] == nil then
		elseif item.buffer[i].render_mode == id and (item.buffer[i].TimeD or 0) >= 0 then
			item.buffer[i].TimeD = item.buffer[i].TimeD - 1
		end
		if item.buffer[i].render_mode == id and item.buffer[i] ~= nil and (item.buffer[i].TimeD or 0) <= 0 then
			if item.buffer[i].func ~= nil then
				local func = item.buffer[i].func
				func(item.buffer[i].params)		--要记住同一帧内的这些是倒叙执行的
			end
			table.remove(item.buffer,i)
		end
	end
end

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_GET_SHADER_PARAMS, params = nil,
Function = function(__,name)
	if name == "Qing_HelpfulShader" then
		item.check_over_buffer(3)
	end
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function(__)
	item.check_over_buffer(2)
end,
})

table.insert(item.pre_ToCall,#item.pre_ToCall + 1,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	item.check_over_buffer(1)
end,
})

table.insert(item.pre_myToCall,#item.pre_myToCall + 1,{CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_,continue)
	item.buffer = {}
end,
})

function item.check_if_any(val,...)
	if type(val) == "function" then return item.check_if_any(val(...),...) end
	if type(val) == "table" and val["Function"] then return item.check_if_any(val["Function"],val,...) end
	return val
end

table.insert(item.pre_myToCall,#item.pre_myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_ROOM, params = nil,
Function = function(_)
	for i = #item.buffer,1,-1 do
		if item.buffer[i] and (item.buffer[i].params2 or {}).remove_now then 
			local tbl = item.buffer[i].params2 or {}
			item.check_if_any(tbl.remove_now,tbl.remove_now_parameter or {}) 		--现在支持传入remove_now作为函数，指导移除时触发的内容了	然而好像是在进入新房间的第一帧触发，没什么办法
			table.remove(item.buffer,i) 
		end
	end
end,
})

return item