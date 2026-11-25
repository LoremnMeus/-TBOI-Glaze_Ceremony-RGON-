-- Golden Compass: protect fixed corridor rooms from StageAPI RoomsList replacement.
-- Scope: SGID 78 entry, 84 options/fire, and the planned X-skull combat room only.
-- Boss@89 StageAPI extension: bind via GenerateBossRoom + SetLevelRoom after GC writes descriptor.
-- Does NOT protect special story endpoints (Mother / Dad's Note).

local M = {}

local MOD_ID = "QingRemaster"
local CALLBACK_ID = "PRE_ROOM_LAYOUT_CHOOSE"
-- Run early so breakOnFirstReturn wins before other layout choosers.
local CALLBACK_PRIORITY = -200

local installed = false
local generation_cb_installed = false
-- Optional resolve hook for Boss@89 encounter (set by runtime; avoids circular require).
local boss_89_resolve_hook = nil
-- sgid -> protected record for the active GC generation
local by_sgid = {}
-- secondary indices refreshed from live descriptors
local by_list_index = {}
local by_spawn_seed = {}

--- StageAPI.LevelRoom is a Class table with __call, not a Lua function.
local function is_callable(v)
	local t = type(v)
	if t == "function" then
		return true
	end
	if t ~= "table" then
		return false
	end
	local mt = getmetatable(v)
	return type(mt) == "table" and type(mt.__call) == "function"
end

--- Layout protection needs layout convert + LevelRoom rewrite APIs.
local function stageapi_layout_ready()
	return StageAPI ~= nil
		and type(StageAPI.AddCallback) == "function"
		and type(StageAPI.GenerateRoomLayoutFromData) == "function"
		and is_callable(StageAPI.LevelRoom)
		and type(StageAPI.GetLevelRoom) == "function"
		and type(StageAPI.SetLevelRoom) == "function"
end

--- Boss ownership probe only needs GetLevelRoom.
local function stageapi_boss_probe_ready()
	return StageAPI ~= nil and type(StageAPI.GetLevelRoom) == "function"
end

function M.clear()
	by_sgid = {}
	by_list_index = {}
	by_spawn_seed = {}
end

function M.get_protected()
	local out = {}
	for sgid, row in pairs(by_sgid) do
		out[#out + 1] = row
		out[#out].sgid = sgid
	end
	table.sort(out, function(a, b)
		return (a.sgid or 0) < (b.sgid or 0)
	end)
	return out
end

local function rebuild_indices()
	by_list_index = {}
	by_spawn_seed = {}
	for sgid, row in pairs(by_sgid) do
		row.sgid = sgid
		if row.list_index ~= nil then
			by_list_index[row.list_index] = row
		end
		if row.spawn_seed ~= nil then
			by_spawn_seed[row.spawn_seed] = row
		end
	end
end

--- Build protection set from final corridor_plan (X-skull from has_x_skull, not raw 82/85/88).
function M.apply_from_pending(pending)
	M.clear()
	if type(pending) ~= "table" or type(pending.corridor_plan) ~= "table" then
		return M.get_protected()
	end
	local plan = pending.corridor_plan
	local function claim(sgid, reason)
		sgid = tonumber(sgid)
		if not sgid then
			return
		end
		local row = plan[sgid]
		if not row or not row.cfg then
			return
		end
		local cfg = row.cfg
		by_sgid[sgid] = {
			sgid = sgid,
			reason = reason,
			variant = tonumber(row.variant or cfg.Variant),
			subtype = tonumber(row.subtype or cfg.Subtype),
			room_type = tonumber(row.room_type_actual or row.room_type or cfg.Type),
			shape = tonumber(row.shape or cfg.Shape),
			name = cfg.Name or row.name,
			dimension = 0,
			list_index = nil,
			spawn_seed = nil,
			has_x_skull = row.has_x_skull == true,
		}
	end

	claim(78, "fixed_entry")
	claim(84, "fixed_options")

	-- Protect only the room that actually received require_x_skull content.
	local x_sgid = nil
	local rule = pending.corridor_content and pending.corridor_content.combat_content_rule
	if type(rule) == "table" and rule.x_skull_quota_abandoned ~= true then
		if type(rule.x_skull_sgids) == "table" and #rule.x_skull_sgids >= 1 then
			x_sgid = rule.x_skull_sgids[1]
		elseif rule.x_skull_quota_sgid ~= nil then
			x_sgid = rule.x_skull_quota_sgid
		end
	end
	if x_sgid == nil then
		for _, sgid in ipairs({82, 85, 88}) do
			local prow = plan[sgid]
			if prow and prow.has_x_skull == true and not prow.content_fallback then
				x_sgid = sgid
				break
			end
		end
	end
	if x_sgid ~= nil then
		local xrow = plan[tonumber(x_sgid)]
		if xrow and xrow.has_x_skull == true and not xrow.content_fallback then
			claim(x_sgid, "required_x_skull")
		end
	end

	rebuild_indices()
	return M.get_protected()
end

--- Refresh ListIndex / SpawnSeed from live RoomDescriptors after GC wrote Data.
function M.refresh_live_identities()
	if not Game or not Game() then
		return M.get_protected()
	end
	local level = Game():GetLevel()
	if not level then
		return M.get_protected()
	end
	for sgid, row in pairs(by_sgid) do
		local desc = nil
		pcall(function()
			desc = level:GetRoomByIdx(sgid, 0)
		end)
		if desc and desc.Data and desc.SafeGridIndex == sgid then
			row.list_index = desc.ListIndex
			row.spawn_seed = desc.SpawnSeed
			row.variant = tonumber(desc.Data.Variant) or row.variant
			row.subtype = tonumber(desc.Data.Subtype) or row.subtype
			row.room_type = tonumber(desc.Data.Type) or row.room_type
			row.shape = tonumber(desc.Data.Shape) or row.shape
			row.name = desc.Data.Name or row.name
		end
	end
	rebuild_indices()
	return M.get_protected()
end

local function layout_fingerprint(layout)
	if type(layout) ~= "table" then
		return nil
	end
	local ent_n = 0
	if type(layout.Entities) == "table" then
		if layout.Entities[1] ~= nil then
			ent_n = #layout.Entities
		else
			for _ in pairs(layout.Entities) do
				ent_n = ent_n + 1
			end
		end
	end
	local grid_n = 0
	if type(layout.GridEntities) == "table" then
		if layout.GridEntities[1] ~= nil then
			grid_n = #layout.GridEntities
		else
			for _ in pairs(layout.GridEntities) do
				grid_n = grid_n + 1
			end
		end
	end
	return string.format(
		"%s|%s|%s|%s|%s|%s|e%s|g%s",
		tostring(layout.Type),
		tostring(layout.Variant),
		tostring(layout.SubType),
		tostring(layout.Shape),
		tostring(layout.Name),
		tostring(layout.Difficulty),
		tostring(ent_n),
		tostring(grid_n)
	)
end

local function expected_fingerprint_from_data(data)
	if not data or not stageapi_layout_ready() then
		return nil
	end
	local ok, layout = pcall(StageAPI.GenerateRoomLayoutFromData, data)
	if ok and type(layout) == "table" then
		return layout_fingerprint(layout), layout
	end
	return nil, nil
end

--- Strict identity: RoomsList layouts can share Variant/Subtype with different content.
local function layout_matches(row, layout)
	if not row or not layout then
		return false
	end
	if row.room_type ~= nil and tonumber(layout.Type) ~= tonumber(row.room_type) then
		return false
	end
	if row.shape ~= nil and tonumber(layout.Shape) ~= tonumber(row.shape) then
		return false
	end
	if row.variant ~= nil and tonumber(layout.Variant) ~= tonumber(row.variant) then
		return false
	end
	if row.subtype ~= nil and tonumber(layout.SubType) ~= tonumber(row.subtype) then
		return false
	end
	if row.name ~= nil and layout.Name ~= nil and tostring(layout.Name) ~= tostring(row.name) then
		return false
	end
	if row.layout_fp ~= nil then
		local fp = layout_fingerprint(layout)
		if fp ~= row.layout_fp then
			return false
		end
	end
	return true
end

local function match_protected(level_room)
	if type(level_room) ~= "table" or not next(by_sgid) then
		return nil
	end
	if level_room.LevelIndex ~= nil and by_list_index[level_room.LevelIndex] then
		return by_list_index[level_room.LevelIndex]
	end
	if level_room.FromData ~= nil and by_list_index[level_room.FromData] then
		return by_list_index[level_room.FromData]
	end
	local seed = level_room.SpawnSeed
	if seed ~= nil and by_spawn_seed[seed] then
		local row = by_spawn_seed[seed]
		if row.room_type == nil or tonumber(level_room.RoomType) == tonumber(row.room_type) then
			if row.shape == nil or tonumber(level_room.Shape) == tonumber(row.shape) then
				return row
			end
		end
	end
	-- Weak fallback: type+shape+variant already on layout name path is insufficient alone.
	return nil
end

function M.choose_layout(level_room, _rooms_list)
	local row = match_protected(level_room)
	if not row then
		return nil
	end
	if not stageapi_layout_ready() then
		return nil
	end
	local data = nil
	if Game and Game() then
		local level = Game():GetLevel()
		local desc = nil
		if row.list_index ~= nil then
			pcall(function()
				desc = level:GetRooms():Get(row.list_index)
			end)
		end
		if (not desc or not desc.Data) and row.sgid ~= nil then
			pcall(function()
				desc = level:GetRoomByIdx(row.sgid, 0)
			end)
		end
		if desc and desc.Data then
			data = desc.Data
		end
	end
	if not data then
		return nil
	end
	local ok, layout = pcall(StageAPI.GenerateRoomLayoutFromData, data)
	if ok and type(layout) == "table" then
		return layout
	end
	return nil
end

--- Replace stale StageAPI LevelRooms that do not match GC's final RoomDescriptor.
function M.sync_level_rooms()
	local report = {synced = {}, skipped = {}, errors = {}}
	if not stageapi_layout_ready() or not next(by_sgid) then
		report.reason = "stageapi_unavailable_or_empty"
		return report
	end
	local level = Game():GetLevel()
	for sgid, row in pairs(by_sgid) do
		local desc = nil
		pcall(function()
			desc = level:GetRoomByIdx(sgid, 0)
		end)
		if not desc or not desc.Data or desc.SafeGridIndex ~= sgid then
			report.skipped[#report.skipped + 1] = {sgid = sgid, reason = "desc_missing"}
		else
			row.list_index = desc.ListIndex
			row.spawn_seed = desc.SpawnSeed
			row.variant = tonumber(desc.Data.Variant) or row.variant
			row.subtype = tonumber(desc.Data.Subtype) or row.subtype
			row.room_type = tonumber(desc.Data.Type) or row.room_type
			row.shape = tonumber(desc.Data.Shape) or row.shape
			row.name = desc.Data.Name or row.name
			local fp = expected_fingerprint_from_data(desc.Data)
			if fp then
				row.layout_fp = fp
			end
			local list_index = desc.ListIndex
			local dim = 0
			local existing = nil
			pcall(function()
				existing = StageAPI.GetLevelRoom(list_index, dim)
			end)
			-- Only touch rooms StageAPI already bound; leave unbound rooms to PRE_ROOM_LAYOUT_CHOOSE.
			local need_replace = false
			local skip_reason = "no_level_room"
			if existing then
				local from_data_ok = existing.FromData == list_index or existing.FromData == true
				if not from_data_ok then
					-- RoomsList / custom layout ownership → always rewrite protected rooms.
					need_replace = true
					skip_reason = nil
				elseif existing.Layout and layout_matches(row, existing.Layout) then
					skip_reason = "layout_matches"
				elseif not existing.Layout then
					skip_reason = "from_data_pending"
				else
					need_replace = true
					skip_reason = nil
				end
			end
			if need_replace then
				local ok_new, new_room = pcall(function()
					return StageAPI.LevelRoom({
						FromData = list_index,
						RoomDescriptor = desc,
					})
				end)
				if ok_new and new_room then
					local ok_set, err_set = pcall(StageAPI.SetLevelRoom, new_room, list_index, dim)
					if ok_set then
						report.synced[#report.synced + 1] = {
							sgid = sgid,
							list_index = list_index,
							reason = row.reason,
							had_prior = true,
						}
					else
						report.errors[#report.errors + 1] = {
							sgid = sgid,
							error = tostring(err_set),
						}
					end
				else
					report.errors[#report.errors + 1] = {
						sgid = sgid,
						error = "LevelRoom_FromData_failed:" .. tostring(new_room),
					}
				end
			else
				report.skipped[#report.skipped + 1] = {
					sgid = sgid,
					reason = skip_reason,
					list_index = list_index,
				}
			end
		end
	end
	rebuild_indices()
	return report
end

function M.serialize_protected()
	local out = {}
	for _, row in ipairs(M.get_protected()) do
		out[#out + 1] = {
			sgid = row.sgid,
			reason = row.reason,
			variant = row.variant,
			subtype = row.subtype,
			room_type = row.room_type,
			shape = row.shape,
			name = row.name,
			dimension = row.dimension or 0,
			list_index = row.list_index,
			spawn_seed = row.spawn_seed,
			has_x_skull = row.has_x_skull == true,
			layout_fp = row.layout_fp,
		}
	end
	return out
end

function M.restore_protected(rows)
	M.clear()
	if type(rows) ~= "table" then
		return M.get_protected()
	end
	for i = 1, #rows do
		local row = rows[i]
		local sgid = row and tonumber(row.sgid)
		if sgid then
			by_sgid[sgid] = {
				sgid = sgid,
				reason = row.reason,
				variant = tonumber(row.variant),
				subtype = tonumber(row.subtype),
				room_type = tonumber(row.room_type),
				shape = tonumber(row.shape),
				name = row.name,
				dimension = tonumber(row.dimension) or 0,
				list_index = row.list_index,
				spawn_seed = row.spawn_seed,
				has_x_skull = row.has_x_skull == true,
				layout_fp = row.layout_fp,
			}
		end
	end
	rebuild_indices()
	return M.get_protected()
end

function M.set_boss_89_resolve_hook(fn)
	boss_89_resolve_hook = type(fn) == "function" and fn or nil
end

function M.ensure_installed()
	if installed and generation_cb_installed then
		return true, "already"
	end
	if not stageapi_layout_ready() and not stageapi_boss_probe_ready() then
		return false, "stageapi_unavailable"
	end
	if not installed and stageapi_layout_ready() then
		local ok, err = pcall(function()
			StageAPI.AddCallback(MOD_ID, CALLBACK_ID, CALLBACK_PRIORITY, function(level_room, rooms_list)
				return M.choose_layout(level_room, rooms_list)
			end)
		end)
		if not ok then
			return false, tostring(err)
		end
		installed = true
	end
	if not generation_cb_installed and StageAPI and type(StageAPI.AddCallback) == "function" then
		local ok_gen = pcall(function()
			StageAPI.AddCallback(
				MOD_ID,
				"POST_STAGEAPI_NEW_ROOM_GENERATION",
				0,
				function(current_room, _just_generated, current_list_index, boss, _dimension)
					if type(boss_89_resolve_hook) == "function" then
						pcall(boss_89_resolve_hook, {
							tag = "post_stageapi_new_room_generation",
							current_room = current_room,
							list_index = current_list_index,
							boss = boss,
						})
					end
				end
			)
		end)
		if ok_gen then
			generation_cb_installed = true
		end
	end
	if installed or generation_cb_installed then
		return true, installed and "installed" or "boss_hook_only"
	end
	return false, "stageapi_layout_unavailable"
end

--- Activate protection for current pending after GC descriptors are final.
function M.activate_for_pending(pending)
	M.ensure_installed()
	local protected = M.apply_from_pending(pending)
	M.refresh_live_identities()
	-- Capture expected fingerprints from final RoomDescriptor.Data.
	if Game and Game() then
		local level = Game():GetLevel()
		for sgid, row in pairs(by_sgid) do
			local desc = nil
			pcall(function()
				desc = level:GetRoomByIdx(sgid, 0)
			end)
			if desc and desc.Data then
				local fp = expected_fingerprint_from_data(desc.Data)
				if fp then
					row.layout_fp = fp
				end
			end
		end
	end
	local sync = M.sync_level_rooms()
	return {
		protected = M.serialize_protected(),
		sync = sync,
		installed = installed,
	}
end

--- Continue / rebuild: restore serialized protection and re-sync LevelRooms.
function M.activate_from_persist(rows)
	M.ensure_installed()
	M.restore_protected(rows)
	M.refresh_live_identities()
	local sync = M.sync_level_rooms()
	return {
		protected = M.serialize_protected(),
		sync = sync,
		installed = installed,
	}
end

local function lr_door_mask_for_89()
	local doors = {}
	local slot_n = DoorSlot.NUM_DOOR_SLOTS or 8
	for s = 0, slot_n - 1 do
		doors[s] = false
	end
	doors[DoorSlot.LEFT0] = true
	doors[DoorSlot.RIGHT0] = true
	return doors
end

--- Clear StageAPI LevelRoom at Boss@89 (vanilla RoomConfig path must not keep stale extension room).
function M.clear_boss_89_level_room()
	if not stageapi_boss_probe_ready() or not Game then
		return false, "stageapi_unavailable"
	end
	local level = Game():GetLevel()
	local desc = nil
	pcall(function()
		desc = level:GetRoomByIdx(89, 0)
	end)
	if not desc or desc.ListIndex == nil then
		return false, "desc_missing"
	end
	local ok = pcall(StageAPI.SetLevelRoom, nil, desc.ListIndex, 0)
	return ok == true, ok and "cleared" or "set_failed"
end

--- StageAPI boss takeover check for Boss@89 (PersistentData.BossID).
--- Returns: boss_id|nil, info
function M.get_stageapi_boss_id_at_89()
	if not stageapi_boss_probe_ready() or not Game then
		return nil, {reason = "stageapi_unavailable"}
	end
	local level = Game():GetLevel()
	local desc = nil
	pcall(function()
		desc = level:GetRoomByIdx(89, 0)
	end)
	if not desc or desc.ListIndex == nil then
		return nil, {reason = "desc_missing"}
	end
	local lr = nil
	local get_ok = pcall(function()
		lr = StageAPI.GetLevelRoom(desc.ListIndex, 0)
	end)
	if not get_ok then
		return nil, {reason = "get_level_room_failed", list_index = desc.ListIndex}
	end
	if lr == nil then
		return nil, {reason = "no_level_room", list_index = desc.ListIndex, level_room_present = false}
	end
	local id = lr.PersistentData and lr.PersistentData.BossID
	if type(id) == "string" and id ~= "" then
		return id, {
			reason = "stageapi_boss",
			list_index = desc.ListIndex,
			level_room_present = true,
			rooms_list_name = lr.RoomsListName,
			rooms_list_id = lr.RoomsListID,
			layout_name = lr.Layout and (lr.Layout.Name or lr.Layout.name),
		}
	end
	return nil, {
		reason = "level_room_without_boss_id",
		list_index = desc.ListIndex,
		level_room_present = true,
		rooms_list_name = lr.RoomsListName,
		from_data = lr.FromData,
	}
end

--- Bind StageAPI extension Boss to Boss@89 after GC RoomDescriptor is final.
--- Uses StageAPI.GenerateBossRoom + SetLevelRoom (scheme A: GC picks Boss, StageAPI picks layout).
--- Returns: ok, info
function M.bind_extension_boss_at_89(boss_id, opts)
	opts = opts or {}
	if type(boss_id) ~= "string" or boss_id == "" then
		return false, {reason = "bad_boss_id"}
	end
	if not (StageAPI and type(StageAPI.GenerateBossRoom) == "function" and type(StageAPI.SetLevelRoom) == "function") then
		return false, {reason = "stageapi_generate_unavailable"}
	end
	if not Game then
		return false, {reason = "no_game"}
	end
	local level = Game():GetLevel()
	local desc = nil
	pcall(function()
		desc = level:GetRoomByIdx(89, 0)
	end)
	if not desc or not desc.Data or desc.ListIndex == nil then
		return false, {reason = "desc_missing"}
	end
	if tonumber(desc.Data.Type) ~= tonumber(RoomType.ROOM_BOSS) then
		return false, {
			reason = "desc_not_boss",
			room_type = desc.Data.Type,
		}
	end
	if tonumber(desc.Data.Shape) ~= tonumber(RoomShape.ROOMSHAPE_1x1) then
		return false, {
			reason = "desc_not_1x1",
			shape = desc.Data.Shape,
		}
	end

	local doors = lr_door_mask_for_89()
	local seed = opts.seed or desc.SpawnSeed
	local room = nil
	local boss = nil
	local gen_ok, gen_err = pcall(function()
		room, boss = StageAPI.GenerateBossRoom({
			BossID = boss_id,
			NoPlayBossAnim = true,
			CheckEncountered = false,
		}, {
			RoomDescriptor = desc,
			RequireRoomType = false,
			Shape = RoomShape.ROOMSHAPE_1x1,
			Doors = doors,
			IgnoreDoors = false,
			-- LevelRoom copies SpawnSeed (not Seed) into ChooseRoomLayout.
			SpawnSeed = seed,
		})
	end)
	if not gen_ok then
		return false, {reason = "generate_error", error = tostring(gen_err)}
	end
	if not room then
		return false, {reason = "generate_nil", boss_id = boss_id}
	end

	-- Match StageAPI.GenerateBaseRoom: replace problematic vanilla subtypes with goto shell.
	local replaced_subtype = false
	pcall(function()
		local subtype = desc.Data and desc.Data.Subtype
		if StageAPI.ReplaceBossSubtypes and subtype and StageAPI.ReplaceBossSubtypes[subtype] then
			local replace_data = StageAPI.GetGotoDataForTypeShape(RoomType.ROOM_BOSS, desc.Data.Shape)
			if replace_data then
				local overwritable = level:GetRoomByIdx(desc.SafeGridIndex, 0)
				if overwritable then
					overwritable.Data = replace_data
					replaced_subtype = true
					desc = overwritable
				end
			end
		end
	end)

	local set_ok, set_err = pcall(StageAPI.SetLevelRoom, room, desc.ListIndex, 0)
	if not set_ok then
		return false, {reason = "set_level_room_failed", error = tostring(set_err)}
	end

	local verify_id, verify_info = M.get_stageapi_boss_id_at_89()
	local ok = verify_id == boss_id
	return ok, {
		reason = ok and "bound" or "verify_mismatch",
		boss_id = boss_id,
		verify_id = verify_id,
		verify = verify_info,
		list_index = desc.ListIndex,
		rooms_list_name = room.RoomsListName,
		rooms_list_id = room.RoomsListID,
		layout_name = room.Layout and (room.Layout.Name or room.Layout.name),
		replaced_subtype = replaced_subtype,
		boss_name = boss and boss.Name,
	}
end

--- After GC layout is ready: bind StageAPI extension OR clear stale LevelRoom for vanilla.
--- pending.corridor_plan[89] drives the choice.
function M.apply_boss_89_stageapi_ownership(pending)
	local row = pending and pending.corridor_plan and pending.corridor_plan[89]
	local report = {
		action = "none",
		ok = false,
	}
	if type(row) ~= "table" then
		report.reason = "no_boss_row"
		return report
	end
	-- Hard endpoints never handed to StageAPI extension bind.
	if row.boss_role == "mother_gate" or row.boss_role == "dads_note_prep" or row.pool == "mother_gate" or row.pool == "dads_note_prep" then
		M.clear_boss_89_level_room()
		report.action = "clear_endpoint"
		report.ok = true
		report.reason = tostring(row.boss_role or row.pool)
		return report
	end
	if row.stageapi_extension == true and type(row.stageapi_boss_id or row.boss_id) == "string" then
		local boss_id = row.stageapi_boss_id or row.boss_id
		local ok, info = M.bind_extension_boss_at_89(boss_id, {
			seed = row.rng_seed,
		})
		report.action = "bind_extension"
		report.ok = ok == true
		report.boss_id = boss_id
		report.info = info
		if not ok then
			-- Do not leave a partial/wrong LevelRoom; vanilla shell stays on descriptor.
			M.clear_boss_89_level_room()
			report.cleared_after_fail = true
		end
		return report
	end
	-- Vanilla RoomConfig path: drop any StageAPI LevelRoom so descriptor content wins.
	local cleared, clear_reason = M.clear_boss_89_level_room()
	report.action = "clear_vanilla"
	report.ok = true
	report.cleared = cleared
	report.clear_reason = clear_reason
	report.boss_id = row.boss_id
	return report
end

return M
