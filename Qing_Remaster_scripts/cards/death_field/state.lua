-- Death Field record CRUD / save (authoritative state)
local save = require("Qing_Remaster_scripts.core.savedata")
local C = require("Qing_Remaster_scripts.cards.death_field.constants")

local M = {}

local function ensure_root()
	save.elses[C.SAVE_KEY] = save.elses[C.SAVE_KEY] or {}
	return save.elses[C.SAVE_KEY]
end

function M.player_index(player)
	if not player then
		return nil
	end
	return player:GetData().__Index
end

function M.get_field(player)
	local idx = M.player_index(player)
	if idx == nil then
		return nil
	end
	return ensure_root()[idx]
end

function M.is_active(player)
	local f = M.get_field(player)
	return f ~= nil and f.active == true
end

function M.max_slots(player)
	local f = M.get_field(player)
	if f and f.max_slots then
		return f.max_slots
	end
	return C.MAX_FIELD_SLOTS
end

function M.entry_count(player)
	local f = M.get_field(player)
	if not f or not f.entries then
		return 0
	end
	return #f.entries
end

function M.has_room(player)
	return M.entry_count(player) < M.max_slots(player)
end

function M.find_entry(player, uid)
	local f = M.get_field(player)
	if not f then
		return nil, nil
	end
	for i, e in ipairs(f.entries) do
		if e.uid == uid then
			return e, i
		end
	end
	return nil, nil
end

function M.create_field(player, opts)
	opts = opts or {}
	local idx = M.player_index(player)
	if idx == nil then
		return nil
	end
	local field = {
		active = true,
		entries = {},
		next_uid = 1,
		max_slots = opts.max_slots or C.MAX_FIELD_SLOTS,
		cloth = opts.cloth == true,
	}
	ensure_root()[idx] = field
	return field
end

function M.clear_field(player)
	local idx = M.player_index(player)
	if idx == nil then
		return
	end
	ensure_root()[idx] = nil
end

function M.reset_all()
	save.elses[C.SAVE_KEY] = {}
	-- 废弃旧属性汤存档键
	save.elses[C.OWN_KEY .. "effect"] = nil
end

local function alloc_uid(field)
	local uid = field.next_uid or 1
	field.next_uid = uid + 1
	return uid
end

function M.add_entry(player, entry)
	local f = M.get_field(player)
	if not f or not f.active then
		return nil
	end
	if #f.entries >= M.max_slots(player) then
		return nil
	end
	entry.uid = entry.uid or alloc_uid(f)
	if entry.norm_x == nil then
		entry.norm_x = 0.5
	end
	if entry.norm_y == nil then
		entry.norm_y = 0.5
	end
	if entry.angle == nil then
		entry.angle = 0
	end
	table.insert(f.entries, entry)
	return entry
end

function M.remove_entry(player, uid)
	local f = M.get_field(player)
	if not f then
		return nil
	end
	for i, e in ipairs(f.entries) do
		if e.uid == uid then
			table.remove(f.entries, i)
			return e
		end
	end
	return nil
end

function M.iter_entries(player)
	local f = M.get_field(player)
	if not f then
		return function() end
	end
	local i = 0
	return function()
		i = i + 1
		return f.entries[i]
	end
end

function M.update_norm_from_world(entry, pos)
	local layout = require("Qing_Remaster_scripts.cards.death_field.layout")
	local nx, ny = layout.world_to_norm(pos)
	entry.norm_x, entry.norm_y = nx, ny
end

--- 玩家真实槽是否已有「手牌」资源（不含 Death_r innate 饰品）
function M.player_holds_real_inventory(player)
	for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET do
		if player:GetActiveItem(slot) ~= 0 then
			return true
		end
	end
	-- pocket2 在部分角色存在
	if ActiveSlot.SLOT_POCKET2 and player:GetActiveItem(ActiveSlot.SLOT_POCKET2) ~= 0 then
		return true
	end
	for slot = 0, 1 do
		if player:GetCard(slot) ~= 0 then
			return true
		end
		if player:GetPill(slot) ~= 0 then
			return true
		end
		if player:GetTrinket(slot) ~= 0 then
			return true
		end
	end
	return false
end

return M
