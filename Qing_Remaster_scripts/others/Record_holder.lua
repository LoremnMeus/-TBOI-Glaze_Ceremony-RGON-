local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	holder_buffer = {},
	by_token = {},
	next_token = 0,
	debug = {check_errors = 0, function_errors = 0},
}

local function entity_exists(ent)
	if ent == nil then return false end
	local ok, exists = pcall(function() return ent:Exists() end)
	return ok and exists == true
end

local function remove_index(index)
	local record = item.holder_buffer[index]
	if not record then return false end
	item.by_token[record.token] = nil
	table.remove(item.holder_buffer, index)
	return true
end

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	for i = #item.holder_buffer, 1, -1 do
		local record = item.holder_buffer[i]
		local ent, params = record.ent, record.params
		local should_trigger, trigger_type, dropped = false, nil, false
		if not entity_exists(ent) then
			should_trigger, trigger_type = true, "Remove"
		elseif type(params.check) == "function" then
			local ok, trigger, kind = pcall(params.check, ent)
			if ok then
				should_trigger, trigger_type = trigger == true, kind
			else
				item.debug.check_errors = item.debug.check_errors + 1
				remove_index(i)
				dropped = true
			end
		end
		if not dropped and should_trigger then
			local keep = false
			if type(params.Function) == "function" then
				local ok, ret = pcall(params.Function, trigger_type, ent)
				if ok then keep = ret == true else item.debug.function_errors = item.debug.function_errors + 1 end
			end
			if not keep then remove_index(i) end
		end
	end
end})

function item.try_hold(ent, params)
	if ent == nil then return nil end
	params = params or {}
	if params.key ~= nil then
		for _, record in ipairs(item.holder_buffer) do
			if auxi.check_for_the_same(record.ent, ent) and record.key == params.key then return record.token end
		end
	end
	item.next_token = item.next_token + 1
	local record = {token = item.next_token, ent = ent, params = params, key = params.key}
	item.holder_buffer[#item.holder_buffer + 1] = record
	item.by_token[record.token] = record
	return record.token
end

function item.release(token)
	if token == nil or item.by_token[token] == nil then return false end
	for i = #item.holder_buffer, 1, -1 do
		if item.holder_buffer[i].token == token then return remove_index(i) end
	end
	item.by_token[token] = nil
	return false
end

function item.clear()
	item.holder_buffer = {}
	item.by_token = {}
end

table.insert(item.ToCall,{CallBack = ModCallbacks.MC_PRE_GAME_EXIT, params = nil, Function = item.clear})
table.insert(item.ToCall,{CallBack = ModCallbacks.MC_POST_GAME_END, params = nil, Function = item.clear})

return item
