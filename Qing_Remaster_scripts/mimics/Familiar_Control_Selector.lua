-- 宝宝控制权统一选择器。
-- 这里只裁决“谁可以控制”，不实现任何移动/攻击，避免控制器互相 require。
local item = {
	controllers = {},
	VANILLA = "vanilla",
	KING_BABY = "king_baby",
	MY_EMBLEM = "my_emblem",
	BLUEPRINT = "blueprint",
}

local OWNER_KEY = "Familiar_Control_Selector_owner"
local OWNER_FRAME_KEY = "Familiar_Control_Selector_owner_frame"

function item.invalidate(familiar)
	if not familiar then return end
	local data = familiar:GetData()
	data[OWNER_FRAME_KEY] = nil
end

function item.register(id, priority, wants_control, hooks)
	if not id or type(wants_control) ~= "function" then return end
	hooks = hooks or {}
	item.controllers[id] = {
		id = id,
		priority = tonumber(priority) or 0,
		wants_control = wants_control,
		on_gain = hooks.on_gain,
		on_lost = hooks.on_lost,
	}
end

function item.get_owner(familiar)
	if not familiar then return item.VANILLA end
	local data = familiar:GetData()
	local frame = Game():GetFrameCount()
	if data[OWNER_FRAME_KEY] == frame and data[OWNER_KEY] ~= nil then
		return data[OWNER_KEY]
	end
	local best_id = item.VANILLA
	local best_priority = -math.huge
	for id, controller in pairs(item.controllers) do
		local ok, wanted = pcall(controller.wants_control, familiar)
		if ok and wanted == true then
			local priority = controller.priority or 0
			if priority > best_priority or (priority == best_priority and id < best_id) then
				best_id = id
				best_priority = priority
			end
		end
	end
	local old_id = data[OWNER_KEY] or item.VANILLA
	if old_id ~= best_id then
		-- 先写入新 owner，避免生命周期回调中再次查询导致递归切换。
		data[OWNER_KEY] = best_id
		local old_controller = item.controllers[old_id]
		if old_controller and old_controller.on_lost then
			pcall(old_controller.on_lost, familiar, best_id)
		end
		local new_controller = item.controllers[best_id]
		if new_controller and new_controller.on_gain then
			pcall(new_controller.on_gain, familiar, old_id)
		end
	end
	data[OWNER_KEY] = best_id
	data[OWNER_FRAME_KEY] = frame
	return best_id
end

function item.is_owner(familiar, id)
	return item.get_owner(familiar) == id
end

--- 供低优先级控制器构建候选表；只询问更高优先级控制器是否申请，
--- 不读取/写入 owner 缓存，因此可安全地在 wants_control 内调用。
function item.has_claim_above(familiar, priority, excluded_id)
	priority = tonumber(priority) or -math.huge
	for id, controller in pairs(item.controllers) do
		if id ~= excluded_id and (controller.priority or 0) > priority then
			local ok, wanted = pcall(controller.wants_control, familiar)
			if ok and wanted == true then return true, id end
		end
	end
	return false, nil
end

return item
