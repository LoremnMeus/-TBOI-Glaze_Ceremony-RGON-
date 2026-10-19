-- 微型更新：清理战斗房后，按本局补丁表微调道具属性、未来红心奖励、固定充能或道具池。
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local runtime = require("Qing_Remaster_scripts.items.tiny_update_runtime")
local notice = require("Qing_Remaster_scripts.items.tiny_update_ui")

local item = {
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Items.Tiny_Update,
	own_key = "Item_Tiny_Update_",
	debug_count = 8,
	debug_category = "any",
	debug_seed = 0,
	probe_pool = ItemPoolType.POOL_TREASURE,
	probe_item = 1,
	pending_frame = nil,
}

local function combat_room()
	local room = Game():GetRoom()
	if not room:IsClear() then return false end
	local kind = room:GetType()
	if kind == RoomType.ROOM_DEFAULT or kind == RoomType.ROOM_BOSS then return true end
	if RoomType.ROOM_MINIBOSS and kind == RoomType.ROOM_MINIBOSS then return true end
	return false
end

local function open_notice(history)
	if history then notice.show(history, false) end
end

function item.try_commit(opts)
	opts = opts or {}
	local history = runtime.commit(opts)
	if history and opts.open ~= false then open_notice(history) end
	return history
end

function item.debug_force_update()
	local category = item.debug_category
	if category == "any" then category = nil end
	return item.try_commit({
		skip_floor = true,
		count = item.debug_count,
		category = category,
		seed = item.debug_seed > 0 and item.debug_seed or nil,
	})
end

function item.debug_preview()
	notice.preview_sample()
end

function item.debug_show_last()
	notice.show_last()
end

function item.debug_status_text()
	return runtime.debug_status()
end

function item.debug_visual_get(key)
	return notice.visual_get(key)
end

function item.debug_visual_set(key, value)
	notice.visual_set(key, value)
end

function item.debug_visual_restore()
	notice.visual_restore()
end

function item.debug_probe_text()
	return runtime.probe_text()
end

function item.debug_probe_read()
	return runtime.probe_pool(item.probe_pool, item.probe_item, false)
end

function item.debug_probe_experiment()
	return runtime.probe_pool(item.probe_pool, item.probe_item, true)
end

function item.debug_cycle_pool()
	local pools = {
		ItemPoolType.POOL_TREASURE,
		ItemPoolType.POOL_SHOP,
		ItemPoolType.POOL_BOSS,
		ItemPoolType.POOL_DEVIL,
		ItemPoolType.POOL_ANGEL,
		ItemPoolType.POOL_SECRET,
		ItemPoolType.POOL_LIBRARY,
		ItemPoolType.POOL_CURSE,
		ItemPoolType.POOL_PLANETARIUM,
		ItemPoolType.POOL_GOLDEN_CHEST,
	}
	local next_index = 1
	for i = 1, #pools do
		if pools[i] == item.probe_pool then next_index = i % #pools + 1 end
	end
	item.probe_pool = pools[next_index]
	return item.probe_pool
end

function item.debug_cycle_category()
	local order = {"any", "buff", "nerf", "pool"}
	local next_index = 1
	for i = 1, #order do
		if order[i] == item.debug_category then next_index = i % #order + 1 end
	end
	item.debug_category = order[next_index]
	return item.debug_category
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD,
	params = nil,
	Function = function()
		if notice.is_open() then return end
		if item.room_pending_frame then return end
		if runtime.copies() <= 0 then return end
		if not combat_room() then return end
		local state = runtime.state()
		if state.room_update_floor_key == runtime.floor_key() then return end
		local player = auxi.have_player_has_collectible(item.entity)
		if not player then return end
		local rng = player:GetCollectibleRNG(item.entity)
		if rng:RandomFloat() >= runtime.room_chance() then return end
		item.room_pending_frame = Game():GetFrameCount() + 10
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_LEVEL,
	params = nil,
	Function = function()
		item.floor_roll_target = runtime.floor_key()
		item.floor_roll_frame = Game():GetFrameCount() + 10
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		local frame = Game():GetFrameCount()
		if item.floor_roll_frame and frame >= item.floor_roll_frame then
			local target = item.floor_roll_target
			item.floor_roll_frame = nil
			item.floor_roll_target = nil
			if target and target == runtime.floor_key() then
				local state = runtime.state()
				if state.floor_entry_roll_key ~= target then
					state.floor_entry_roll_key = target
					if runtime.copies() > 0 then
						local player = auxi.have_player_has_collectible(item.entity)
						local rng = player and player:GetCollectibleRNG(item.entity)
						if rng and rng:RandomFloat() < runtime.floor_chance() then
							item.floor_pending_frame = frame + 1
						end
					end
				end
			end
		end
		if item.floor_pending_frame and frame >= item.floor_pending_frame then
			if notice.is_open() then
				item.floor_pending_frame = frame + 10
			else
				item.floor_pending_frame = nil
				if runtime.copies() > 0 then
					item.try_commit({open = true, kind = "floor"})
				end
			end
		end
		if item.room_pending_frame and frame >= item.room_pending_frame then
			if notice.is_open() then
				item.room_pending_frame = frame + 10
			else
				item.room_pending_frame = nil
				if runtime.copies() > 0 then
					local state = runtime.state()
					local key = runtime.floor_key()
					if state.room_update_floor_key ~= key then
						item.try_commit({open = true, kind = "room"})
						runtime.state().room_update_floor_key = key
					end
				end
			end
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		item.room_pending_frame = nil
		if notice.is_open() then notice.force_close() end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_EVALUATE_CACHE,
	params = nil,
	Function = function(_, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + runtime.stat_total(player, "damage")
		elseif flag == CacheFlag.CACHE_FIREDELAY then
			local tears = runtime.stat_total(player, "tears")
			if tears ~= 0 then player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay, tears) end
		elseif flag == CacheFlag.CACHE_RANGE then
			player.TearRange = player.TearRange + runtime.stat_total(player, "range") * 40
		elseif flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + runtime.stat_total(player, "shot_speed")
		elseif flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + runtime.stat_total(player, "speed")
		elseif flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + runtime.stat_total(player, "luck")
		end
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE,
	params = nil,
	Function = function(_, player, id, count)
		runtime.on_gain(player, id, count)
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_REWIND,
	params = nil,
	Function = function()
		item.pending_frame = nil
		item.room_pending_frame = nil
		item.floor_pending_frame = nil
		item.floor_roll_frame = nil
		item.floor_roll_target = nil
		runtime.clear_charge_jobs()
		if notice.is_open() then notice.force_close() end
		runtime.invalidate_eid()
		runtime.sync_custom_pools()
		runtime.sync_charges()
		runtime.sync_stats()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	params = nil,
	Function = function(_, continue)
		item.pending_frame = nil
		item.room_pending_frame = nil
		item.floor_pending_frame = nil
		item.floor_roll_frame = nil
		item.floor_roll_target = nil
		runtime.clear_charge_jobs()
		if not continue then runtime.clear_commit_trace() end
		if notice.is_open() then notice.force_close() end
		item.register_eid()
		runtime.sync_custom_pools()
		if continue then
			runtime.sync_charges()
			runtime.sync_stats()
		else
			runtime.sync_charges()
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_GAME_EXIT,
	params = nil,
	Function = function()
		if notice.is_open() then notice.force_close() end
	end,
})

if ModCallbacks.MC_PLAYER_GET_ACTIVE_MAX_CHARGE then
	table.insert(item.post_ToCall, #item.post_ToCall + 1, {
		CallBack = ModCallbacks.MC_PLAYER_GET_ACTIVE_MAX_CHARGE,
		params = nil,
		Function = function(_, collectible, _, _, current_max)
			local delta, floor_value, ceil_value = runtime.charge_delta(collectible)
			if not delta then return nil end
			local result = (tonumber(current_max) or 0) + delta
			if floor_value and result < floor_value then result = floor_value end
			if ceil_value and result > ceil_value then result = ceil_value end
			return math.floor(result)
		end,
	})
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PEFFECT_UPDATE,
	params = nil,
	Function = function()
		runtime.settle_charge_adjust()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE,
	params = nil,
	Function = function()
		notice.tick()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = (REPENTOGON and ModCallbacks.MC_POST_HUD_RENDER) or ModCallbacks.MC_POST_RENDER,
	params = nil,
	Function = function()
		notice.render()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_INPUT_ACTION,
	params = nil,
	Function = function(_, _, hook, button)
		if not notice.is_blocking() then return nil end
		if button == ButtonAction.ACTION_PAUSE or button == ButtonAction.ACTION_MENUCONFIRM or button == ButtonAction.ACTION_MENUBACK then
			if button ~= ButtonAction.ACTION_MENUCONFIRM and button ~= ButtonAction.ACTION_MENUBACK then
				return nil
			end
		end
		if hook == InputHook.GET_ACTION_VALUE then return 0 end
		if hook == InputHook.IS_ACTION_TRIGGERED or hook == InputHook.IS_ACTION_PRESSED then
			return false
		end
		return nil
	end,
})

function item.register_eid()
	if item._eid or not EID or not EID.addDescriptionModifier then return end
	item._eid = true
	EID:addDescriptionModifier("qing_tiny_update_patch", function(desc)
		if not desc or desc.ObjType ~= 5 or desc.ObjVariant ~= 100 then return false end
		local lines = runtime.eid_lines(desc.ObjSubType)
		return lines and #lines > 0
	end, function(desc)
		local lines = runtime.eid_lines(desc.ObjSubType)
		if not lines or not lines[1] then return desc end
		EID:appendToDescription(desc, "#" .. lines[1])
		return desc
	end)
end

item.register_eid()

return item
