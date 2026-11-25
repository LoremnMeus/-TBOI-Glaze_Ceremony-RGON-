-- One-shot floor map visibility settlement for the fixed-corridor Home rewrite.
-- Called once after ChangeRoom(78). Does not monitor later room enters.
-- Reuses Black Map / Bloody Map / hidden_room_holder — does not own hide books.

local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local M = {}

local VISIBLE = 1 << 0
local SHOW_LOCK = 1 << 1 -- Room Shadow / lock shade (Baby Lu / Glaze Key reveal use |7)
local SHOW_ICON = 1 << 2
local FLAGS_VISITED = VISIBLE | SHOW_ICON -- 5: visited/current look
local FLAGS_REVEALED = VISIBLE | SHOW_LOCK | SHOW_ICON -- 7: visible but not visited
local FLAGS_MAP_OUTLINE = VISIBLE -- 1
local FLAG_CLEAR = 1 << 0 -- RoomDescriptor.Flags clear bit

local COMPASS_TYPES = {
	[RoomType.ROOM_SHOP] = true,
	[RoomType.ROOM_TREASURE] = true,
	[RoomType.ROOM_BOSS] = true,
	[RoomType.ROOM_MINIBOSS] = true,
	[RoomType.ROOM_ARCADE] = true,
	[RoomType.ROOM_CURSE] = true,
	[RoomType.ROOM_CHALLENGE] = true,
	[RoomType.ROOM_LIBRARY] = true,
	[RoomType.ROOM_SACRIFICE] = true,
	[RoomType.ROOM_DEVIL] = true,
	[RoomType.ROOM_ANGEL] = true,
	[RoomType.ROOM_ISAACS] = true,
	[RoomType.ROOM_BARREN] = true,
	[RoomType.ROOM_CHEST] = true,
	[RoomType.ROOM_DICE] = true,
	[RoomType.ROOM_GREED_EXIT] = true,
	[RoomType.ROOM_PLANETARIUM] = true,
}

local BLUE_MAP_TYPES = {
	[RoomType.ROOM_SECRET] = true,
	[RoomType.ROOM_SUPERSECRET] = true,
	-- ULTRASECRET: Bloody Map / Full Map only — never Blue Map.
}

local function try_minimap_refresh()
	if Minimap and Minimap.Refresh then
		pcall(function()
			Minimap.Refresh()
		end)
	end
end

local function try_update_visibility()
	local level = Game():GetLevel()
	if level and level.UpdateVisibility then
		pcall(function()
			level:UpdateVisibility()
		end)
		return true
	end
	return false
end

function M.read_map_abilities()
	local level = Game():GetLevel()
	local flags = {
		map = false,
		compass = false,
		blue_map = false,
		full_map = false,
		black_map = false,
		bloody_map = false,
	}
	pcall(function()
		flags.map = level:GetStateFlag(LevelStateFlag.STATE_MAP_EFFECT) == true
		flags.compass = level:GetStateFlag(LevelStateFlag.STATE_COMPASS_EFFECT) == true
		flags.blue_map = level:GetStateFlag(LevelStateFlag.STATE_BLUE_MAP_EFFECT) == true
		flags.full_map = level:GetStateFlag(LevelStateFlag.STATE_FULL_MAP_EFFECT) == true
	end)
	pcall(function()
		flags.black_map = auxi.have_player_has_collectible(enums.Items.Black_Map) == true
	end)
	pcall(function()
		flags.bloody_map = auxi.have_player_has_collectible(enums.Items.Bloody_Map) == true
	end)
	return flags
end

local function iter_unique_descs()
	local level = Game():GetLevel()
	local rooms = level:GetRooms()
	local seen = {}
	local list = {}
	local size = rooms and rooms.Size or 0
	for i = 0, size - 1 do
		local desc = rooms:Get(i)
		if desc and desc.Data and desc.SafeGridIndex and desc.SafeGridIndex >= 0 and desc.ListIndex and desc.ListIndex >= 0 then
			local li = desc.ListIndex
			if not seen[li] then
				seen[li] = true
				local live = level:GetRoomByIdx(desc.SafeGridIndex, 0)
				if live and live.ListIndex == li then
					list[#list + 1] = live
				else
					list[#list + 1] = desc
				end
			end
		end
	end
	return list
end

function M.snapshot_rooms(label)
	local out = {}
	for _, desc in ipairs(iter_unique_descs()) do
		out[#out + 1] = {
			list_index = desc.ListIndex,
			sgid = desc.SafeGridIndex,
			type = desc.Data and desc.Data.Type,
			variant = desc.Data and desc.Data.Variant,
			shape = desc.Data and desc.Data.Shape,
			visited = desc.VisitedCount or 0,
			display_flags = desc.DisplayFlags or 0,
		}
	end
	table.sort(out, function(a, b)
		return (a.sgid or 0) < (b.sgid or 0)
	end)
	return {
		label = label or "snapshot",
		room_count = #out,
		rooms = out,
	}
end

local function snapshot_focus(sgids, label)
	local level = Game():GetLevel()
	local rows = {}
	for _, sgid in ipairs(sgids or {}) do
		local desc = level:GetRoomByIdx(sgid, 0)
		rows[#rows + 1] = {
			sgid = sgid,
			visited = desc and desc.VisitedCount,
			display_flags = desc and desc.DisplayFlags,
			type = desc and desc.Data and desc.Data.Type,
			owner_sgid = desc and desc.SafeGridIndex,
		}
	end
	return {label = label, rooms = rows}
end

local function clear_fake_visits(fake_sgids)
	local level = Game():GetLevel()
	local cleared = {}
	for _, sgid in ipairs(fake_sgids or {}) do
		local desc = level:GetRoomByIdx(sgid, 0)
		if desc then
			local before_v = desc.VisitedCount
			local before_clear = desc.Clear
			local before_flags = desc.Flags
			pcall(function()
				-- Strip Home-start inheritance: not visited, not cleared.
				desc.VisitedCount = 0
				desc.Clear = false
				if desc.Flags ~= nil then
					desc.Flags = (tonumber(desc.Flags) or 0) & ~FLAG_CLEAR
				end
			end)
			cleared[#cleared + 1] = {
				sgid = sgid,
				visited_before = before_v,
				visited_after = desc.VisitedCount,
				clear_before = before_clear,
				clear_after = desc.Clear,
				flags_before = before_flags,
				flags_after = desc.Flags,
			}
		end
	end
	return cleared
end

local function zero_all_display_flags()
	local n = 0
	for _, desc in ipairs(iter_unique_descs()) do
		pcall(function()
			desc.DisplayFlags = 0
		end)
		n = n + 1
	end
	return n
end

--- Apply visited/current + map-item overlays. Does NOT call UpdateVisibility.
local function apply_visit_and_item_flags(abilities)
	local level = Game():GetLevel()
	local current = level:GetCurrentRoomDesc()
	local current_li = current and current.ListIndex
	for _, desc in ipairs(iter_unique_descs()) do
		local data = desc.Data
		local tp = data and data.Type
		local visited = (desc.VisitedCount or 0) > 0
		local is_current = current_li ~= nil and desc.ListIndex == current_li
		local flags = 0
		if visited or is_current then
			flags = FLAGS_VISITED
		elseif abilities.full_map then
			-- Reveal without pretending VisitedCount>0 (Zeis uses 5+Visited=1; we need unvisited shade).
			flags = FLAGS_REVEALED
		else
			if abilities.map and tp == RoomType.ROOM_DEFAULT then
				flags = flags | FLAGS_MAP_OUTLINE
			end
			if abilities.compass and tp and COMPASS_TYPES[tp] then
				flags = flags | FLAGS_VISITED
			end
			if abilities.blue_map and tp and BLUE_MAP_TYPES[tp] then
				flags = flags | FLAGS_VISITED
			end
			if abilities.bloody_map and tp == RoomType.ROOM_ULTRASECRET then
				flags = flags | FLAGS_VISITED
			end
		end
		pcall(function()
			desc.DisplayFlags = flags
		end)
	end
end

--- After UpdateVisibility: keep fake-cleared rooms unvisited while preserving reveal flags.
local function reassert_unvisited_home_start(fake_sgids, abilities)
	local level = Game():GetLevel()
	local rows = {}
	for _, sgid in ipairs(fake_sgids or {}) do
		local desc = level:GetRoomByIdx(sgid, 0)
		if desc and (tonumber(desc.VisitedCount) or 0) <= 0 then
			local before = {
				visited = desc.VisitedCount,
				clear = desc.Clear,
				display_flags = desc.DisplayFlags,
			}
			pcall(function()
				desc.VisitedCount = 0
				desc.Clear = false
				if desc.Flags ~= nil then
					desc.Flags = (tonumber(desc.Flags) or 0) & ~FLAG_CLEAR
				end
				if abilities and abilities.full_map then
					desc.DisplayFlags = FLAGS_REVEALED
				elseif (tonumber(desc.DisplayFlags) or 0) == FLAGS_VISITED then
					-- Visibility pass may have stamped visited look; demote to revealed outline if any bits set.
					if (desc.DisplayFlags or 0) ~= 0 then
						desc.DisplayFlags = FLAGS_REVEALED
					end
				end
			end)
			rows[#rows + 1] = {
				sgid = sgid,
				before = before,
				after = {
					visited = desc.VisitedCount,
					clear = desc.Clear,
					display_flags = desc.DisplayFlags,
					flags = desc.Flags,
				},
			}
		end
	end
	return rows
end

--- One-shot settlement after layout + ChangeRoom(78).
--- Order: clear fake visits → zero flags → apply visit/item → UpdateVisibility once
--- → Black/Bloody/hidden overlays → Minimap.Refresh.
--- Does not re-run on later room enters (caller must gate with map_settlement_done).
function M.settle_once(opts)
	opts = opts or {}
	local abilities = M.read_map_abilities()
	local focus = opts.focus_sgids or {83, 84, 85, 95, 97, 108, 109, 110, 122, 78}

	local before = M.snapshot_rooms("before_clear")
	local focus_before = snapshot_focus(focus, "focus_before")

	local cleared = clear_fake_visits(opts.fake_clear_sgids)
	local zeroed = zero_all_display_flags()
	local after_clear = M.snapshot_rooms("after_clear")
	local focus_after_clear = snapshot_focus(focus, "focus_after_clear")

	apply_visit_and_item_flags(abilities)
	local after_apply = M.snapshot_rooms("after_apply")

	-- Single UpdateVisibility: neighbors of real visits + helmet / vanilla extras.
	local visibility_ok = try_update_visibility()
	local after_visibility = M.snapshot_rooms("after_visibility")
	local home_reassert = reassert_unvisited_home_start(opts.fake_clear_sgids, abilities)
	if home_reassert and #home_reassert > 0 then
		try_update_visibility()
	end
	local after_home_reassert = snapshot_focus(opts.fake_clear_sgids or {}, "focus_after_home_reassert")

	local black_ran = false
	if abilities.black_map then
		local ok, black = pcall(function()
			return require("Qing_Remaster_scripts.items.Item_Black_Map")
		end)
		if ok and black and black.update_black_map then
			pcall(black.update_black_map)
			black_ran = true
		end
	end

	local bloody_ran = false
	if abilities.bloody_map then
		local ok, bloody = pcall(function()
			return require("Qing_Remaster_scripts.items.Item_Bloody_Map")
		end)
		if ok and bloody and bloody.reveal_ultra_secrets then
			pcall(bloody.reveal_ultra_secrets)
			bloody_ran = true
		end
	end

	local hidden_ran = false
	local ok_h, hidden = pcall(function()
		return require("Qing_Remaster_scripts.callbacks.hidden_room_holder")
	end)
	if ok_h and hidden and hidden.refresh then
		pcall(function()
			hidden.refresh(true)
		end)
		hidden_ran = true
	end

	try_minimap_refresh()
	local after = M.snapshot_rooms("final")
	local focus_final = snapshot_focus(focus, "focus_final")

	return {
		ok = true,
		kind = "map_settlement_once",
		reason = opts.reason or "settle_once",
		abilities = abilities,
		fake_cleared = cleared,
		zeroed_count = zeroed,
		visibility_ok = visibility_ok == true,
		black_ran = black_ran,
		bloody_ran = bloody_ran,
		hidden_ran = hidden_ran,
		before = before,
		after_clear = after_clear,
		after_apply = after_apply,
		after_visibility = after_visibility,
		after = after,
		focus_before = focus_before,
		focus_after_clear = focus_after_clear,
		home_reassert = home_reassert,
		focus_after_home_reassert = after_home_reassert,
		focus_final = focus_final,
	}
end

-- Back-compat alias for older probe call sites.
function M.settle(opts)
	return M.settle_once(opts)
end

function M.snapshot_rooms_public(label)
	return M.snapshot_rooms(label)
end

return M
