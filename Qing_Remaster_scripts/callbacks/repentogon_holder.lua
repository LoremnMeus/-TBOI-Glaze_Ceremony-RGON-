local enums = require("Qing_Remaster_scripts.core.enums")
local callback_manager = require("Qing_Remaster_scripts.core.callback_manager")
local slot_render_holder = require("Qing_Remaster_scripts.callbacks.slot_render_holder")
local Pause_Screen_holder = require("Qing_Remaster_scripts.others.Pause_Screen_holder")
local time_holder = require("Qing_Remaster_scripts.others.Time_holder")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")

local item = {
	ToCall = {},
	grid_data = {},
}

local function work(name, runner, checkout)
	return callback_manager.work(name, runner, checkout, true)
end

-- RGON 1.1.2f：room:GetGridEntity() 不再返回“看似存在却无法索引”的垃圾引用；
-- 越界 idx / 空格仍可能得到不可用 userdata。禁止用 grid.Method 做存在探测。
local function grid_is_usable(grid)
	if not grid then return false end
	local ok = pcall(function()
		return grid:GetType()
	end)
	return ok == true
end

local function grid_key(grid)
	if not grid_is_usable(grid) then
		return 0
	end
	return grid:GetType() * 10000 + grid:GetVariant()
end

local function grid_index(grid)
	if not grid_is_usable(grid) then
		return -1
	end
	local ok, idx = pcall(function()
		return grid:GetGridIndex()
	end)
	if ok and type(idx) == "number" then
		return idx
	end
	ok, idx = pcall(function()
		return Game():GetRoom():GetGridIndex(grid.Position)
	end)
	if ok and type(idx) == "number" then
		return idx
	end
	return -1
end

local function dispatch_grid_init(grid)
	if not grid_is_usable(grid) then return end
	local idx = grid_index(grid)
	if idx < 0 then return end
	local old = item.grid_data[idx] or 0
	local key = grid_key(grid)
	if old ~= key then
		work("POST_GRID_INIT", function(funct, params)
			if params == nil or params == grid:GetType() then funct(nil, idx, grid, old) end
		end)
		item.grid_data[idx] = key
	end
end

local function dispatch_grid_update(grid)
	if not grid_is_usable(grid) then return end
	local idx = grid_index(grid)
	if idx < 0 then return end
	dispatch_grid_init(grid)
	work("POST_GRID_UPDATE", function(funct, params)
		if params == nil or params == grid:GetType() then funct(nil, idx, grid) end
	end)
end

local function scan_room_grids()
	local room = Game():GetRoom()
	local width = room:GetGridWidth()
	local height = room:GetGridHeight()
	-- 合法下标：x∈[0,width)、y∈[0,height)；旧代码写成 0..width / 0..height 会扫到越界格
	for y = 0, height - 1 do
		for x = 0, width - 1 do
			local idx = x + y * width
			local grid = room:GetGridEntity(idx)
			if grid_is_usable(grid) then
				dispatch_grid_init(grid)
			end
		end
	end
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_NEW_ROOM, params = nil,
Function = function(_, room, desc)
	item.grid_data = {}
	work("PRE_NEW_ROOM", function(funct, params) funct(nil, nil, room, desc) end)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	scan_room_grids()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_SLOT_INIT, params = nil,
Function = function(_, slot)
	work("POST_SLOT_INIT", function(funct, params)
		if params == nil or params == slot.Variant then funct(nil, slot) end
	end)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_SLOT_UPDATE, params = nil,
Function = function(_, slot)
	work("POST_SLOT_UPDATE", function(funct, params)
		if params == nil or params == slot.Variant then funct(nil, slot) end
	end)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_SLOT_COLLISION, params = nil,
Function = function(_, slot, collider, low)
	work("POST_SLOT_COLLISION", function(funct, params)
		if params == nil or params == slot.Variant then funct(nil, slot, collider, low) end
	end)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_SLOT_CREATE_EXPLOSION_DROPS, params = nil,
Function = function(_, slot)
	local data = slot:GetData()
	if data.Every_Entity_holder_Killed == true then return end
	work("POST_SLOT_KILL", function(funct, params)
		if params == nil or params == slot.Variant then funct(nil, slot, nil) end
	end)
	data.Every_Entity_holder_Killed = true
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_GRID_ENTITY_SPAWN, params = nil,
Function = function(_, grid)
	dispatch_grid_init(grid)
end,
})

local grid_update_callbacks = {
	ModCallbacks.MC_POST_GRID_ENTITY_DECORATION_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_DOOR_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_FIRE_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_GRAVITY_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_LOCK_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_PIT_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_POOP_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_PRESSUREPLATE_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_ROCK_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_SPIKES_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_STAIRCASE_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_STATUE_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_TELEPORTER_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_TNT_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_TRAPDOOR_UPDATE,
	ModCallbacks.MC_POST_GRID_ENTITY_WEB_UPDATE,
}

for _, callback in ipairs(grid_update_callbacks) do
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = callback, params = nil,
	Function = function(_, grid)
		dispatch_grid_update(grid)
	end,
	})
end

local function dispatch_pocket(player, pickup, expected_variant)
	if not player or not pickup then return end
	work("POST_PICKUP_POCKET_ITEM", function(funct, params)
		if params == nil or params == pickup.SubType then funct(nil, player, pickup.Variant or expected_variant, pickup.SubType) end
	end)
	if player:GetPlayerType() == PlayerType.PLAYER_THESOUL_B then
		for playerNum = 1, Game():GetNumPlayers() do
			local other = Game():GetPlayer(playerNum - 1)
			if other:GetPlayerType() == PlayerType.PLAYER_THEFORGOTTEN_B then
				work("POST_PICKUP_POCKET_ITEM", function(funct, params)
					if params == nil or params == pickup.SubType then funct(nil, other, pickup.Variant or expected_variant, pickup.SubType) end
				end)
			end
		end
	end
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PLAYER_COLLECT_CARD, params = nil,
Function = function(_, player, pickup)
	dispatch_pocket(player, pickup, PickupVariant.PICKUP_TAROTCARD)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PLAYER_COLLECT_PILL, params = nil,
Function = function(_, player, pickup)
	dispatch_pocket(player, pickup, PickupVariant.PICKUP_PILL)
end,
})

local function dispatch_active_slot_render(name, player, slot)
	if not Game():GetHUD():IsVisible() then return end
	local cid = player:GetActiveItem(slot)
	if cid and cid ~= 0 and slot_render_holder.check_pocket(player, slot) then
		work(name, function(funct, params)
			if params == nil or params == "Active" then funct(nil, player, "Active", cid, slot) end
		end)
	end
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_PLAYERHUD_RENDER_ACTIVE_ITEM, params = nil,
Function = function(_, player, slot, offset, alpha, scale, chargeBarOffset)
	ui.SetActiveSlotRenderInfo(player, slot, offset, alpha, scale, chargeBarOffset)
	dispatch_active_slot_render("PRE_SLOT_RENDER", player, slot)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PLAYERHUD_RENDER_ACTIVE_ITEM, params = nil,
Function = function(_, player, slot, offset, alpha, scale, chargeBarOffset)
	ui.SetActiveSlotRenderInfo(player, slot, offset, alpha, scale, chargeBarOffset)
	if time_holder.IsUpper() ~= true then return end
	local no_update = Pause_Screen_holder.check_info("NoUpdate")
	if Pause_Screen_holder.check_info("Leave") then
		slot_render_holder.do_frame("Leave", no_update)
	elseif Pause_Screen_holder.check_info("Menu") then
		slot_render_holder.do_frame("Menu", no_update)
	end
	dispatch_active_slot_render("POST_SLOT_RENDER", player, slot)
end,
})

return item
