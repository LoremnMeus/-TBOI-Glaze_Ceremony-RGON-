-- 放逐证明：永久名单跨局保留。放逐立即 RemoveCollectible。
-- 取回只改永久名单，不调用 AddCollectible；当前局保持已移除，下一局才恢复。
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local pixel_ui = require("Qing_Remaster_scripts.auxiliary.pixel_ui")
local g = require("Qing_Remaster_scripts.core.globals")
local Select = require("Qing_Remaster_scripts.others.fullscreen_select_holder")
local exo_ui = require("Qing_Remaster_scripts.others.exoneration_ui")
local Room_holder = require("Qing_Remaster_scripts.others.Room_holder")
local hidden_rooms = require("Qing_Remaster_scripts.callbacks.hidden_room_holder")
local pedestal_restore = require("Qing_Remaster_scripts.auxiliary.pedestal_restore")
local unique = require("Qing_Remaster_scripts.others.Unique_holder")
local layout = require("Qing_Remaster_scripts.items.exoneration_border_layout")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local grid_door = require("Qing_Remaster_scripts.grids.grid_doors")
local Book_of_Belial_holder = require("Qing_Remaster_scripts.mimics.Book_of_Belial_holder")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Exoneration_Certificate,
	own_key = "Item_Exoneration_Certificate_",
}

local BAN_LIMIT = 32
local PANEL_ID = "exoneration_certificate"
local DOOR_ANM2 = "gfx/grid/door_01_normaldoor.anm2"
local DOOR_SHEET = "gfx/grid/door_01_gehennadoor.png"
local backdrop_token = nil

item.debug_config = { count = 12, shape = "auto", algorithm = "auto", seed = 1 }
item.debug_status = ""
item.debug_scan_text = ""
local SESSION_KEY = "ExonerationCertificate_session"
local FLOOR_KEY = "ExonerationCertificate_floor"
local APPLIED_KEY = "ExonerationCertificate_applied"
local PERMANENT_KEY = "ExonerationCertificate"

local icon_cache = {}
local cursor_sprite = nil
local drop_claim, new_claim_id

local function zh_lang()
	local language = Options and Options.Language or "en"
	return language ~= "en"
end

local function text(zh, en)
	if zh_lang() then
		return zh
	end
	return en
end

local function permanent()
	save.PermanentData = save.PermanentData or {}
	local rec = save.PermanentData[PERMANENT_KEY]
	if type(rec) ~= "table" then
		rec = { version = 1, banished = {} }
		save.PermanentData[PERMANENT_KEY] = rec
	end
	if type(rec.banished) ~= "table" then
		rec.banished = {}
	end
	rec.version = 1
	return rec
end

local function banished_ids()
	local rec = save.PermanentData and save.PermanentData[PERMANENT_KEY]
	if type(rec) ~= "table" or type(rec.banished) ~= "table" then
		return {}
	end
	local list = {}
	for _, id in ipairs(rec.banished) do
		id = tonumber(id)
		if id and id > 0 then
			list[#list + 1] = id
		end
	end
	return list
end

function item.list_banished()
	return banished_ids()
end

function item.clear_banished()
	local rec = permanent()
	rec.banished = {}
	if save.SaveModData then
		save.SaveModData("exoneration_debug_clear")
	end
	return true
end

local function ban_set()
	local set = {}
	for _, id in ipairs(banished_ids()) do
		set[id] = true
	end
	return set
end

local function applied_list()
	if type(save.elses[APPLIED_KEY]) ~= "table" then
		save.elses[APPLIED_KEY] = {}
	end
	return save.elses[APPLIED_KEY]
end

local function peek_session()
	local session = save.elses[SESSION_KEY]
	if type(session) ~= "table" then
		return nil
	end
	return session
end

local function session()
	if type(save.elses[SESSION_KEY]) ~= "table" then
		save.elses[SESSION_KEY] = {}
	end
	return save.elses[SESSION_KEY]
end

local function remember_applied(id)
	local list = applied_list()
	for _, have in ipairs(list) do
		if tonumber(have) == id then
			return
		end
	end
	list[#list + 1] = id
end

local function remove_from_pool(id)
	local itempool = Game():GetItemPool()
	if itempool and itempool.RemoveCollectible then
		itempool:RemoveCollectible(id)
	end
end

local function apply_new_run()
	local applied = {}
	for _, id in ipairs(banished_ids()) do
		remove_from_pool(id)
		applied[#applied + 1] = id
	end
	save.elses[APPLIED_KEY] = applied
	save.elses[SESSION_KEY] = nil
end

function item.add_banish(id)
	id = tonumber(id)
	if not id or id <= 0 then
		return false
	end
	local rec = permanent()
	local count = 0
	for _, have in ipairs(rec.banished) do
		count = count + 1
		if tonumber(have) == id then
			return false
		end
	end
	if count >= BAN_LIMIT then
		return false
	end
	rec.banished[#rec.banished + 1] = id
	remove_from_pool(id)
	remember_applied(id)
	if save.SaveModData then
		save.SaveModData("exoneration_banish")
	end
	return true
end

function item.remove_banish(id)
	id = tonumber(id)
	if not id then
		return false
	end
	local rec = permanent()
	local next_list = {}
	local found = false
	for _, have in ipairs(rec.banished) do
		if not found and tonumber(have) == id then
			found = true
		else
			next_list[#next_list + 1] = tonumber(have) or have
		end
	end
	if not found then
		return false
	end
	rec.banished = next_list
	if save.SaveModData then
		save.SaveModData("exoneration_retrieve")
	end
	return true
end

-- Full archive order by collectible id. Banished items stay listed.
local function eligible_ids()
	local config = Isaac.GetItemConfig()
	local list = {}
	local size = config:GetCollectibles().Size
	for id = 1, size do
		local col = config:GetCollectible(id)
		local tags = col and col.Tags or 0
		if col and col.Hidden ~= true and (tags & ItemConfig.TAG_QUEST) ~= ItemConfig.TAG_QUEST then
			list[#list + 1] = id
		end
	end
	return list
end

local function menu_options()
	local options = {}
	-- Archive stays open even at the 32/32 cap; confirm is blocked in the UI.
	options[#options + 1] = "banish"
	if #banished_ids() > 0 then
		options[#options + 1] = "border"
	end
	return options
end

local function player_index(player)
	if not player or not player.GetData then
		return nil
	end
	local data = player:GetData()
	return data and data.__Index or nil
end

local function border_allowed(player)
	return #banished_ids() > 0 and not auxi.should_do_Seija(player)
end

local function ui_model(player, candidates)
	local banned = ban_set()
	local snap = {}
	for id, flag in pairs(banned) do
		if flag then
			snap[tonumber(id) or id] = true
		end
	end
	return {
		options = {
			{ id = "banish", enabled = true },
			{ id = "border", enabled = border_allowed(player) },
		},
		banished_count = #banished_ids(),
		banished_limit = BAN_LIMIT,
		candidate_ids = candidates or {},
		banished_set = snap,
	}
end

local function clear_panel_data(player)
	if not player or not player.GetData then
		return
	end
	local data = player:GetData()
	data[item.own_key .. "effect"] = nil
	data[item.own_key .. "lift"] = nil
	data[item.own_key .. "mode"] = nil
	data[item.own_key .. "candidates"] = nil
	data[item.own_key .. "catalog"] = nil
	data[item.own_key .. "last_open_dir"] = 9
	data[item.own_key .. "last_open_dir_counter"] = 0
	exo_ui.close(player)
end

local function close_panel(player)
	if Select.get(PANEL_ID) then
		Select.close(PANEL_ID)
		return
	end
	clear_panel_data(player)
end

local function open_panel(player)
	Select.open(PANEL_ID, player)
end

local function candidate_list(player)
	local data = player and player.GetData and player:GetData()
	local list = data and data[item.own_key .. "candidates"]
	if type(list) ~= "table" then
		return {}
	end
	return list
end

local function icon_sprite(id)
	local cached = icon_cache[id]
	if cached then
		return cached
	end
	local config = Isaac.GetItemConfig():GetCollectible(id)
	if not config or not config.GfxFileName or config.GfxFileName == "" then
		return nil
	end
	local sprite = Sprite()
	sprite:Load("gfx/mimics/The_True_Name/the_true_name_item.anm2", true)
	sprite:Play("Idle", true)
	sprite:ReplaceSpritesheet(0, config.GfxFileName)
	sprite:LoadGraphics()
	sprite.Scale = Vector(0.5, 0.5)
	sprite.Color = Color(1, 1, 1, 1)
	icon_cache[id] = sprite
	return sprite
end

local function mark_sprite()
	if cursor_sprite then
		return cursor_sprite
	end
	local sprite = Sprite()
	sprite:Load("gfx/mimics/The_True_Name/the_true_name_item.anm2", true)
	sprite:Play("Idle", true)
	sprite:ReplaceSpritesheet(0, "gfx/ui/math/catch_mark.png")
	sprite:LoadGraphics()
	sprite.Scale = Vector(0.5, 0.5)
	cursor_sprite = sprite
	return sprite
end

local function consume_certificate(owner_index)
	if owner_index == nil then
		return false
	end
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player_index(player) == owner_index then
			local before = player:GetCollectibleNum(item.entity)
			if before <= 0 then
				return false
			end
			player:RemoveCollectible(item.entity)
			return player:GetCollectibleNum(item.entity) < before
		end
	end
	return false
end

local function restore_certificate(owner_index)
	if owner_index == nil then
		return
	end
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player_index(player) == owner_index then
			player:AddCollectible(item.entity)
			return
		end
	end
end

local function current_desc()
	if not g.is_gameplay_world_active() then
		return nil
	end
	return Game():GetLevel():GetCurrentRoomDesc()
end

local function peek_floor()
	local floor = save.elses[FLOOR_KEY]
	if type(floor) ~= "table" then
		return nil
	end
	return floor
end

local function floor_state()
	if type(save.elses[FLOOR_KEY]) ~= "table" then
		save.elses[FLOOR_KEY] = { offers = {} }
	end
	local floor = save.elses[FLOOR_KEY]
	if type(floor.offers) ~= "table" then
		floor.offers = {}
	end
	return floor
end

local function descriptor_shape(desc)
	if not desc or not desc.Data then
		return nil
	end
	return layout.shape_by_variant(desc.Data.Variant)
end

local function remember_border_room(index, dimension, variant)
	if not index then
		return
	end
	local floor = floor_state()
	if type(floor.hidden_border_rooms) ~= "table" then
		floor.hidden_border_rooms = {}
	end
	local key = tostring(dimension or 0) .. ":" .. tostring(index)
	floor.hidden_border_rooms[key] = {
		index = index,
		dimension = dimension or 0,
		variant = variant,
	}
end

local function each_border_record()
	local floor = peek_floor()
	local list = {}
	if not floor then
		return list
	end
	local seen = {}
	local function add(index, dimension, variant)
		if not index then
			return
		end
		local key = tostring(dimension or 0) .. ":" .. tostring(index)
		if seen[key] then
			return
		end
		seen[key] = true
		list[#list + 1] = {
			index = index,
			dimension = dimension or 0,
			variant = variant,
		}
	end
	add(floor.border_room_index, floor.border_dimension, floor.border_variant)
	if type(floor.test_rooms) == "table" then
		for shape, index in pairs(floor.test_rooms) do
			local info = layout.shape_info(shape)
			add(index, floor.test_dimension, info and info.variant)
		end
	end
	if type(floor.hidden_border_rooms) == "table" then
		for _, row in pairs(floor.hidden_border_rooms) do
			if type(row) == "table" then
				add(row.index, row.dimension, row.variant)
			end
		end
	end
	return list
end

local function hide_border_rooms(_)
	if not g.is_gameplay_world_active() then
		return
	end
	hidden_rooms.release_owner("exoneration")
	for _, row in ipairs(each_border_record()) do
		hidden_rooms.keep(row.index, row.dimension, {
			hide = true,
			hide_map = true,
			owner = "exoneration",
		})
	end
	hidden_rooms.refresh()
end

local function in_border()
	local desc = current_desc()
	local shape = descriptor_shape(desc)
	local floor = peek_floor()
	if not shape or not floor then
		return false
	end
	local dim = auxi.GetDimension() or 0
	if desc.SafeGridIndex == floor.border_room_index and auxi.check_equal(dim, floor.border_dimension or 0) then
		return true
	end
	local tests = floor.test_rooms
	if type(tests) ~= "table" then
		return false
	end
	for _, index in pairs(tests) do
		if index == desc.SafeGridIndex and auxi.check_equal(dim, floor.test_dimension or 0) then
			return true
		end
	end
	return false
end

local function current_shape()
	return descriptor_shape(current_desc())
end

local function border_config(variant)
	if not REPENTOGON then
		return nil
	end
	local holder = rawget(_G, "RoomConfig") or rawget(_G, "RoomConfigHolder")
	if not holder or not holder.GetRoomByStageTypeAndVariant then
		return nil
	end
	local mode = Game():IsGreedMode() and 1 or 0
	local ok, config = pcall(
		holder.GetRoomByStageTypeAndVariant,
		StbType.SPECIAL_ROOMS,
		RoomType.ROOM_DEFAULT,
		variant,
		mode
	)
	if ok then
		return config
	end
	return nil
end

local function place_variant(dimension, variant)
	local level = Game():GetLevel()
	local config = border_config(variant)
	if not config or not level.TryPlaceRoom then
		return nil
	end
	local seed = level:GetDungeonPlacementSeed()
	for grid_index = 0, 168 do
		local desc = level:GetRoomByIdx(grid_index, dimension)
		if desc and desc.Data == nil then
			local ok, placed = pcall(function()
				return level:TryPlaceRoom(config, grid_index, dimension, seed + grid_index, true, true, true)
			end)
			if ok and placed and placed.SafeGridIndex then
				remember_border_room(placed.SafeGridIndex, dimension, variant)
				hide_border_rooms(true)
				return placed.SafeGridIndex
			end
		end
	end
	return nil
end

local function ensure_border_index(dimension)
	local floor = peek_floor()
	if floor and floor.border_room_index then
		local desc = Game():GetLevel():GetRoomByIdx(floor.border_room_index, dimension)
		if descriptor_shape(desc) then
			remember_border_room(floor.border_room_index, dimension, desc.Data.Variant)
			hide_border_rooms(true)
			return floor.border_room_index
		end
	end
	local shape = layout.auto_shape(#banished_ids())
	local info = layout.shape_info(shape)
	local index = info and place_variant(dimension, info.variant) or nil
	if not index then
		return nil
	end
	local kept = floor_state()
	kept.border_room_index = index
	kept.border_dimension = dimension
	kept.border_shape = shape
	kept.border_variant = info.variant
	if type(kept.offers) ~= "table" then
		kept.offers = {}
	end
	return index
end

local function ensure_test_room(dimension, shape)
	local info = layout.shape_info(shape)
	if not info then
		return nil
	end
	local floor = floor_state()
	if type(floor.test_rooms) ~= "table" then
		floor.test_rooms = {}
	end
	local existing = floor.test_rooms[shape]
	if existing then
		local desc = Game():GetLevel():GetRoomByIdx(existing, dimension)
		if descriptor_shape(desc) == shape then
			floor.test_dimension = dimension
			remember_border_room(existing, dimension, desc.Data.Variant)
			hide_border_rooms(true)
			return existing
		end
	end
	local index = place_variant(dimension, info.variant)
	if not index then
		return nil
	end
	floor.test_rooms[shape] = index
	floor.test_dimension = dimension
	return index
end

local function capture_origin(player)
	local desc = current_desc()
	if not desc then
		return false
	end
	local state = session()
	local level = Game():GetLevel()
	state.origin_room_index = desc.SafeGridIndex
	state.origin_dimension = auxi.GetDimension() or 0
	state.origin_stage = level:GetStage()
	state.origin_stage_type = level:GetStageType()
	state.owner_index = player_index(player)
	state.phase = "inbound"
	state.prepared = false
	drop_claim(state, "NEW_VISIT")
	state.test = nil
	state.entry_placed = nil
	return true
end

local clear_border_pedestals
local clear_layout_previews

local function room_usable(index, dimension)
	if not index or index <= 0 then
		return false
	end
	local desc = Game():GetLevel():GetRoomByIdx(index, dimension)
	if not desc or not desc.Data then
		return false
	end
	if descriptor_shape(desc) then
		return false
	end
	return true
end

local function finish_border_return()
	local state = peek_session()
	if not state or state.phase ~= "outbound" or not state.return_arrived then
		return
	end
	local desc = current_desc()
	if not desc or desc.SafeGridIndex ~= state.return_index then
		return
	end
	local dim = auxi.GetDimension() or 0
	if state.return_dimension ~= nil and not auxi.check_equal(dim, state.return_dimension) then
		return
	end
	save.elses[SESSION_KEY] = nil
	hide_border_rooms(true)
end

local function return_home()
	local state = peek_session()
	if state and state.phase == "outbound" then
		return false
	end
	local floor = peek_floor()
	local target = floor and floor.entry_return
	local index = target and target.index
	local dimension = target and (target.dimension or 0) or 0
	if not room_usable(index, dimension) then
		return false
	end
	if in_border() and state and state.test then
		clear_layout_previews()
	end
	drop_claim(state, "RETURN_HOME")
	state = session()
	state.phase = "outbound"
	state.prepared = false
	state.refresh_exile_display = false
	state.return_index = index
	state.return_dimension = dimension
	state.origin_room_index = nil
	state.return_arrived = false
	Room_holder.Trans_to(
		index,
		Direction.NO_DIRECTION,
		RoomTransitionAnim.FADE,
		Game():GetPlayer(0),
		dimension,
		{ On_Arrive = function()
			local current = peek_session()
			if current then
				current.return_arrived = true
			end
			finish_border_return()
		end }
	)
	return true
end

local certificate_entry_frame = nil
local transit = nil

local function player_holds_certificate(player)
	return player and player.GetCollectibleNum and player:GetCollectibleNum(item.entity) > 0
end

local function release_transit_lock()
	if not transit then
		return
	end
	if transit.time_held and auxi.is_time_stopped(item.own_key) then
		auxi.time_free(item.own_key)
	end
	if transit then
		transit.time_held = false
	end
end

local function clear_transit()
	local who = nil
	if transit and transit.player_index ~= nil then
		for i = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(i)
			if player_index(player) == transit.player_index then
				who = player
				break
			end
		end
	end
	release_transit_lock()
	if who and who.StopExtraAnimation then
		pcall(function()
			who:StopExtraAnimation()
		end)
	end
	transit = nil
end

local function hold_transit_time()
	if not transit or transit.time_held then
		return
	end
	auxi.time_stop(item.own_key)
	transit.time_held = true
end

local function enter_border(player)
	if auxi.should_do_Seija(player) then
		return false
	end
	if transit or #banished_ids() <= 0 or not player_holds_certificate(player) then
		return false
	end
	local frame = Game():GetFrameCount()
	if certificate_entry_frame == frame then
		return false
	end
	local desc = current_desc()
	if not desc then
		return false
	end
	local dimension = auxi.GetDimension() or 0
	local index = ensure_border_index(dimension)
	if not index then
		return false
	end
	local owner = player_index(player)
	local level = Game():GetLevel()
	local state = session()
	state.origin_room_index = desc.SafeGridIndex
	state.origin_dimension = dimension
	state.origin_stage = level:GetStage()
	state.origin_stage_type = level:GetStageType()
	state.owner_index = owner
	state.phase = "inbound"
	state.prepared = false
	state.test = nil
	state.entry_placed = nil
	drop_claim(state, "NEW_VISIT")
	certificate_entry_frame = frame
	if not consume_certificate(owner) then
		certificate_entry_frame = nil
		save.elses[SESSION_KEY] = nil
		return false
	end
	state.refresh_exile_display = true
	state.certificate_entry = true
	state.place_players = true
	transit = {
		kind = "enter",
		phase = "closing_ui",
		player_index = owner,
		owner_index = owner,
		index = index,
		dimension = dimension,
		origin_room_index = desc.SafeGridIndex,
		origin_dimension = dimension,
		origin_stage = level:GetStage(),
		origin_stage_type = level:GetStageType(),
		consumed = true,
		time_held = false,
	}
	exo_ui.begin_close(player)
	return true
end

local function note_border_entry(kind)
	if not in_border() then
		return
	end
	local floor = floor_state()
	local state = peek_session()
	if kind == "continue" then
		local saved = floor.entry_return
		if type(saved) == "table" and room_usable(saved.index, saved.dimension or 0) then
			floor.return_fallback = nil
		elseif state and state.certificate_entry and room_usable(state.origin_room_index, state.origin_dimension or 0) then
			floor.entry_return = {
				index = state.origin_room_index,
				dimension = state.origin_dimension or 0,
				source = "certificate_origin",
			}
			floor.return_fallback = nil
		else
			floor.entry_return = nil
			floor.return_fallback = "continue_without_source"
		end
		if state then
			state.certificate_entry = nil
		end
		return
	end
	local dimension = auxi.GetDimension() or 0
	if state and state.certificate_entry and room_usable(state.origin_room_index, state.origin_dimension or 0) then
		floor.entry_return = {
			index = state.origin_room_index,
			dimension = state.origin_dimension or 0,
			source = "certificate_origin",
		}
		floor.return_fallback = nil
		state.certificate_entry = nil
		return
	end
	if state then
		state.certificate_entry = nil
		state.origin_room_index = nil
	end
	local level = Game():GetLevel()
	local previous = level:GetPreviousRoomIndex()
	if room_usable(previous, dimension) then
		floor.entry_return = { index = previous, dimension = dimension, source = "previous_room" }
		floor.return_fallback = nil
		return
	end
	local mock = item.debug_config and tonumber(item.debug_config.mock_previous) or 0
	if mock > 0 and room_usable(mock, dimension) then
		floor.entry_return = { index = mock, dimension = dimension, source = "debug_mock" }
		floor.return_fallback = "debug_mock"
		return
	end
	local starting = level:GetStartingRoomIndex()
	if room_usable(starting, dimension) then
		floor.entry_return = { index = starting, dimension = dimension, source = "starting_room" }
		floor.return_fallback = "starting_room"
		return
	end
	floor.entry_return = nil
	floor.return_fallback = "no_verified_source"
end

local function apply_backdrop_on_entry()
	if not in_border() then
		return
	end
	local token = tostring(Isaac.GetFrameCount())
	if backdrop_token == token then
		return
	end
	backdrop_token = token
	local room = Game():GetRoom()
	if room.SetBackdropType then
		room:SetBackdropType(BackdropType.GEHENNA, 1)
	end
end

local function spawn_border_door()
	if not in_border() then
		return nil
	end
	local floor = peek_floor()
	if not floor or type(floor.entry_return) ~= "table" then
		local state = peek_session()
		if state then
			state.door_ok = false
		end
		return nil
	end
	local shape = current_shape()
	local profile = shape and layout.profile(shape) or nil
	if not profile then
		return nil
	end
	local room = Game():GetRoom()
	local params = {
		check_and_leave = function()
			return_home()
		end,
		loadname = DOOR_ANM2,
		spritename = DOOR_SHEET,
		playname = "Opened",
		should_update = true,
		dir = 3,
		refer_slot = DoorSlot and DoorSlot.DOWN0 or 3,
	}
	local door = nil
	local door_index = nil
	if profile.door_slot == "down0" and DoorSlot and room.GetDoorSlotPosition then
		local vanilla = room.GetDoor and room:GetDoor(DoorSlot.DOWN0)
		if vanilla and room.RemoveDoor then
			room:RemoveDoor(DoorSlot.DOWN0)
		end
		door_index = room:GetGridIndex(room:GetDoorSlotPosition(DoorSlot.DOWN0))
		door = grid_door.try_spawn_grid_door(room, DoorSlot.DOWN0, nil, params)
	end
	if not door then
		door_index = layout.grid_index(room:GetGridWidth(), profile.door.x, profile.door.y)
		door = grid_door.try_spawn_grid_door(room, nil, door_index, params)
	end
	local state = peek_session()
	if state then
		state.door_index = door and door_index or nil
		state.door_ok = door ~= nil
	end
	return door
end

local function place_entry_players()
	local state = peek_session()
	if not state or not state.place_players or state.phase == "outbound" or state.entry_placed or not in_border() then
		return
	end
	local shape = current_shape()
	local profile = shape and layout.profile(shape) or nil
	if not profile then
		return
	end
	local room = Game():GetRoom()
	local pos = layout.world_position(room, profile.spawn.x, profile.spawn.y)
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		player.Position = pos
		player.Velocity = Vector.Zero
	end
	state.entry_placed = true
	state.place_players = nil
end

local function preview_ids(count, seed)
	local rng = RNG()
	rng:SetSeed(math.max(1, tonumber(seed) or 1), 35)
	local config = Isaac.GetItemConfig()
	local pool = {}
	local size = config:GetCollectibles().Size
	for id = 1, size do
		local col = config:GetCollectible(id)
		local tags = col and col.Tags or 0
		if col and col.Hidden ~= true and (tags & ItemConfig.TAG_QUEST) ~= ItemConfig.TAG_QUEST then
			pool[#pool + 1] = id
		end
	end
	local out = {}
	for _ = 1, count do
		if #pool == 0 then
			break
		end
		local pick = rng:RandomInt(#pool) + 1
		out[#out + 1] = pool[pick]
		table.remove(pool, pick)
	end
	return out
end

local function each_collectible()
	if not g.is_gameplay_world_active() then
		return {}
	end
	return Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)
end

local function generation_id_of(ent)
	if not ent or not ent.GetData then
		return nil
	end
	local gen = unique.resolve_generation(ent)
	if gen and gen.id ~= nil then
		ent:GetData()[item.own_key .. "generation_id"] = gen.id
		return tostring(gen.id)
	end
	local marked = ent:GetData()[item.own_key .. "generation_id"]
	if marked ~= nil then
		return tostring(marked)
	end
	return nil
end

local function peeked_generation_id(ent)
	local data = ent:GetData()
	local marked = data[item.own_key .. "generation_id"]
	if marked ~= nil then
		return tostring(marked)
	end
	local gen = unique.peek_generation(ent)
	if gen and gen.id ~= nil then
		return tostring(gen.id)
	end
	return nil
end

local function owned_collectible_id(ent, floor)
	local data = ent:GetData()
	if data[item.own_key .. "layout_preview"] then
		return nil
	end
	local marked = tonumber(data[item.own_key .. "border_id"])
	if marked then
		return marked
	end
	local gid = peeked_generation_id(ent)
	if not gid or type(floor.offers) ~= "table" then
		return nil
	end
	return tonumber(floor.offers[gid])
end

local function remember_offer(floor, ent, collectible_id)
	local data = ent:GetData()
	data[item.own_key .. "border_id"] = collectible_id
	local gid = generation_id_of(ent)
	if gid then
		floor.offers[gid] = collectible_id
	end
	return gid
end

local function sync_border_pedestals()
	local state = peek_session()
	if not state or state.phase == "outbound" or not in_border() then
		return
	end
	if not state.test and state.refresh_exile_display ~= true then
		return
	end
	if state.prepared then
		if not state.test then
			state.refresh_exile_display = false
		end
		return
	end
	if state.phase ~= "inbound" and state.phase ~= "choosing" then
		return
	end
	local shape = current_shape()
	if not shape then
		return
	end
	local floor = floor_state()
	local wanted = state.test and preview_ids(state.test_count or 1, state.test_seed or 1) or banished_ids()
	local plan = layout.plan(shape, #wanted, state.test and (state.test_algorithm or "auto") or "auto")
	state.last_plan = plan
	local room = Game():GetRoom()
	local seen = {}
	local unresolved = false
	local group_index = nil
	if state.test then
		clear_layout_previews()
	else
		clear_layout_previews()
		clear_border_pedestals()
		floor.settled_gains = {}
		floor.settle_error = nil
		group_index = option_index_holder.find_a_new_index()
		if not group_index or group_index == 0 then
			floor.option_index = nil
			floor.option_fallback = "index_exhausted"
			group_index = nil
		else
			floor.option_index = group_index
			floor.option_fallback = nil
		end
	end
	for index, id in ipairs(wanted) do
		local cell = plan.positions[index]
		if cell and not seen[id] then
			local pickup = pedestal_restore.spawn_owned_collectible(item.own_key, {
				collectible_id = id,
				touched = false,
				charge = 0,
			}, layout.world_position(room, cell.x, cell.y), nil, function(spawned)
				local data = spawned:GetData()
				if state.test then
					data[item.own_key .. "layout_preview"] = true
				else
					data[item.own_key .. "border_id"] = id
				end
			end)
			if pickup and group_index and not state.test then
				pickup.OptionsPickupIndex = group_index
			end
			if state.test and pickup then
				seen[id] = true
			elseif pickup and remember_offer(floor, pickup, id) then
				seen[id] = true
			else
				unresolved = true
			end
		end
	end
	if not unresolved then
		state.prepared = true
		state.phase = "choosing"
		if not state.test then
			state.refresh_exile_display = false
		end
	end
end

local function seal_doors()
	if not in_border() then
		return
	end
	local floor = peek_floor()
	if not floor or type(floor.entry_return) ~= "table" then
		return
	end
	local room = Game():GetRoom()
	local shape = current_shape()
	local profile = shape and layout.profile(shape) or nil
	for slot = 0, 7 do
		if profile and profile.door_slot == "down0" and DoorSlot and slot == DoorSlot.DOWN0 then
		else
			local door = room:GetDoor(slot)
			if door and door.Close then
				door:Close(true)
			end
		end
	end
end

clear_layout_previews = function()
	if not in_border() then
		return
	end
	for _, ent in ipairs(each_collectible()) do
		if ent:GetData()[item.own_key .. "layout_preview"] then
			ent:Remove()
		end
	end
end

clear_border_pedestals = function()
	if not in_border() then
		return
	end
	for _, ent in ipairs(each_collectible()) do
		local data = ent:GetData()
		if data[item.own_key .. "border_id"] ~= nil then
			ent:Remove()
		end
	end
	local floor = peek_floor()
	if floor then
		floor.offers = {}
	end
end

local function abandon_open_border_visit()
	if in_border() then
		return
	end
	local level = Game():GetLevel()
	local previous = level:GetPreviousRoomIndex()
	local dimension = auxi.GetDimension() or 0
	local prev_desc = previous and level:GetRoomByIdx(previous, dimension) or nil
	if not descriptor_shape(prev_desc) then
		return
	end
	local state = peek_session()
	if not state or state.phase == "outbound" then
		return
	end
	drop_claim(state, "ABANDON_LEFT_BORDER")
	save.elses[SESSION_KEY] = nil
end

local function find_offer_pedestal(generation_id)
	if generation_id == nil then
		return nil
	end
	local wanted = tostring(generation_id)
	for _, ent in ipairs(each_collectible()) do
		if generation_id_of(ent) == wanted then
			return ent
		end
	end
	return nil
end

item._claim_serial = item._claim_serial or 0

function drop_claim(state, _reason)
	local floor = peek_floor()
	if floor and type(floor.claim) == "table" then
		floor.claim = nil
	end
	if state and type(state.claim) == "table" then
		state.claim = nil
	end
	return true
end

function new_claim_id()
	item._claim_serial = (item._claim_serial or 0) + 1
	return string.format("exo_%d_%d", Game():GetFrameCount(), item._claim_serial)
end

local function player_by_index(idx)
	if idx == nil then
		return nil
	end
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player_index(player) == idx then
			return player
		end
	end
	return nil
end

--- A different collectible now occupying the queue replaced this pickup.
--- An empty queue is not cancellation: Gain often arrives after the queue clears.
local function replacement_collectible_id(player)
	if not player or not player.IsItemQueueEmpty or player:IsItemQueueEmpty() then
		return nil
	end
	local queued = player.QueuedItem
	local info = queued and queued.Item
	if not info or info.Type == ItemType.ITEM_TRINKET then
		return nil
	end
	return tonumber(info.ID)
end

local function release_unpicked_claim()
	local floor = peek_floor()
	local claim = floor and floor.claim
	if type(claim) ~= "table" then
		return
	end
	if claim.queue_linked then
		local queued_id = replacement_collectible_id(player_by_index(claim.player_index))
		if queued_id and queued_id ~= tonumber(claim.collectible_id) then
			drop_claim(peek_session(), "QUEUE_REPLACED")
		end
		return
	end
	local now = Game():GetFrameCount()
	local since = now - (tonumber(claim.frame) or now)
	if since <= 0 then
		return
	end
	local live = find_offer_pedestal(claim.generation_id)
	if live and (tonumber(live.SubType) or 0) > 0 then
		drop_claim(peek_session(), "OFFER_STILL_PRESENT")
		return
	end
	if since >= 30 then
		drop_claim(peek_session(), "UNLINKED_TIMEOUT")
	end
end

local function sprite_anim(player)
	local sprite = player and player.GetSprite and player:GetSprite()
	if not sprite or not sprite.GetAnimation then
		return ""
	end
	return sprite:GetAnimation() or ""
end

local function presentation_busy(player)
	if not player then
		return false
	end
	if player.IsItemQueueEmpty and not player:IsItemQueueEmpty() then
		return true
	end
	if player:IsHoldingItem() then
		return true
	end
	if player.IsExtraAnimationFinished and player:IsExtraAnimationFinished() ~= true then
		return true
	end
	local anim = sprite_anim(player)
	return anim == "Pickup" or anim == "PickupWalk" or anim == "LiftItem" or anim == "PlayerPickup"
end

local function lift_busy(player)
	if not player then
		return false
	end
	if player:IsHoldingItem() then
		return true
	end
	local anim = sprite_anim(player)
	if anim == "Pickup" or anim == "PickupWalk" or anim == "LiftItem" or anim == "PlayerPickup" or anim == "HideItem" then
		return true
	end
	if player.IsExtraAnimationFinished and player:IsExtraAnimationFinished() ~= true then
		return true
	end
	return false
end

-- Day Dreamer style: keep ExtraAnimation alive and drive the shown frame ourselves.
local function pin_death_pose(player)
	if not transit or not player then
		return
	end
	local hold = tonumber(transit.death_hold_frame)
	if hold == nil then
		return
	end
	local sprite = player.GetSprite and player:GetSprite()
	if not sprite or not sprite.SetFrame then
		return
	end
	player:PlayExtraAnimation("DeathTeleport")
	sprite:SetFrame("DeathTeleport", hold)
end

local function drive_death_teleport(player)
	if not transit or not player then
		return false
	end
	local sprite = player.GetSprite and player:GetSprite()
	if not sprite or not sprite.SetLastFrame or not sprite.GetFrame or not sprite.SetFrame then
		return false
	end
	player:PlayExtraAnimation("DeathTeleport")
	sprite:SetLastFrame()
	local last = sprite:GetFrame()
	if type(last) == "number" and last > 2 then
		transit.death_last = last
	end
	local max_frame = tonumber(transit.death_last)
	if not max_frame or max_frame <= 2 then
		sprite:SetFrame("DeathTeleport", 0)
		return false
	end
	transit.death_ticks = (transit.death_ticks or 0) + 1
	local wanted = math.min(max_frame - 2, math.floor(transit.death_ticks / 2))
	sprite:SetFrame("DeathTeleport", wanted)
	transit.death_hold_frame = wanted
	return wanted >= max_frame - 2
end

local function start_death(_player)
	transit.phase = "death_teleport"
	transit.death_ticks = 0
	transit.death_last = nil
	transit.death_hold_frame = nil
	transit.death_transferred = false
	hold_transit_time()
end

local function begin_enter_transfer(player)
	if not transit or transit.kind ~= "enter" or transit.phase == "transferring" then
		return
	end
	transit.phase = "transferring"
	local arrived = pcall(function()
		Room_holder.Trans_to(
			transit.index,
			Direction.NO_DIRECTION,
			RoomTransitionAnim.FADE,
			player,
			transit.dimension,
			nil
		)
	end)
	if not arrived then
		if transit.consumed then
			restore_certificate(transit.owner_index)
		end
		save.elses[SESSION_KEY] = nil
		clear_transit()
	end
end

local function begin_retrieve_exit(owner_index)
	if transit and transit.kind == "retrieve" then
		return true
	end
	if transit or owner_index == nil then
		return false
	end
	if not player_by_index(owner_index) then
		return false
	end
	transit = {
		kind = "retrieve",
		phase = "pickup",
		player_index = owner_index,
		owner_index = owner_index,
		gain_frame = Game():GetFrameCount(),
		saw_pickup = false,
		consumed = true,
		time_held = false,
	}
	return true
end

local function tick_transit(player)
	if not transit or not player or player_index(player) ~= transit.player_index then
		return
	end
	if Select.pause_menu_open() or Game():IsPaused() then
		if transit.time_held and auxi.is_time_stopped(item.own_key) then
			auxi.time_free(item.own_key)
			transit.time_held = false
			transit.pause_freed = true
		end
		return
	end
	if transit.pause_freed then
		hold_transit_time()
		transit.pause_freed = nil
	end
	if transit.phase == "closing_ui" then
		return
	end
	if transit.phase == "transferring" then
		pin_death_pose(player)
		return
	end
	if transit.phase == "settle_lift" then
		if lift_busy(player) then
			transit.saw_lift = true
			return
		end
		if not transit.saw_lift and Game():GetFrameCount() <= (transit.lift_frame or 0) then
			return
		end
		start_death(player)
		return
	end
	if transit.phase == "pickup" then
		if presentation_busy(player) then
			transit.saw_pickup = true
			return
		end
		local now = Game():GetFrameCount()
		if now <= (transit.gain_frame or now) + 1 then
			return
		end
		start_death(player)
		return
	end
	if transit.phase == "death_teleport" then
		if transit.death_transferred then
			pin_death_pose(player)
			return
		end
		if not drive_death_teleport(player) then
			return
		end
		transit.death_transferred = true
		pin_death_pose(player)
		if transit.kind == "enter" then
			begin_enter_transfer(player)
		elseif transit.phase ~= "transferring" then
			transit.phase = "transferring"
			if not return_home() then
				clear_transit()
				return
			end
		end
		if transit and transit.phase == "transferring" then
			pin_death_pose(player)
		end
	end
end

local function commit_retrieve(id, gid)
	local state = peek_session()
	if state and state.test then
		return false
	end
	local floor = peek_floor()
	if not floor or type(floor.offers) ~= "table" then
		return false
	end
	id = tonumber(id)
	gid = gid ~= nil and tostring(gid) or nil
	if not id or not gid then
		return false
	end
	if type(floor.settled_gains) ~= "table" then
		floor.settled_gains = {}
	end
	if floor.settled_gains[gid] then
		return false
	end
	local offered = tonumber(floor.offers[gid] or floor.offers[tonumber(gid)])
	if offered ~= id then
		return false
	end
	local claim = floor.claim
	if type(claim) == "table" and (tostring(claim.generation_id) ~= gid or tonumber(claim.collectible_id) ~= id) then
		return false
	end
	if not ban_set()[id] then
		floor.settle_error = "NOT_BANISHED"
		if type(claim) == "table" then
			claim.settle_error = "NOT_BANISHED"
		end
		return false
	end
	local removed = item.remove_banish(id)
	if not removed then
		floor.settle_error = "BANISH_REMOVE_FAILED"
		if type(claim) == "table" then
			claim.settle_error = "BANISH_REMOVE_FAILED"
		end
		return false
	end
	floor.settled_gains[gid] = true
	floor.settle_error = nil
	local who = type(claim) == "table" and claim.player_index or nil
	drop_claim(state, "COMMIT_SETTLED")
	clear_border_pedestals()
	if not begin_retrieve_exit(who) then
		return_home()
	end
	return true
end

local function still_legal(id)
	id = tonumber(id)
	if not id or id <= 0 or ban_set()[id] or #banished_ids() >= BAN_LIMIT then
		return false
	end
	local col = Isaac.GetItemConfig():GetCollectible(id)
	local tags = col and col.Tags or 0
	if not col or col.Hidden == true or (tags & ItemConfig.TAG_QUEST) == ItemConfig.TAG_QUEST then
		return false
	end
	return true
end

local function try_banish(player, id)
	if not still_legal(id) or not item.add_banish(id) then
		return false
	end
	if not consume_certificate(player_index(player)) then
		item.remove_banish(id)
		return false
	end
	return true
end

local function collectible_config(id)
	return Isaac.GetItemConfig():GetCollectible(tonumber(id) or 0)
end

local function grant_banish_synergy(player, id)
	local config = collectible_config(id)
	if not player or not config then
		return
	end
	local summonable = ((config.Tags or 0) & ItemConfig.TAG_SUMMONABLE) ~= 0
	if summonable and auxi.should_spawn_wisp(player) then
		player:AddItemWisp(id, player.Position, true)
	end
	local quality = tonumber(config.Quality) or 0
	local bonus = math.max(0, math.min(4, quality))
	if bonus > 0 and auxi.should_do_belial(player) then
		Book_of_Belial_holder.Add_dmg(player, bonus, { counter = 30 })
	end
end

local function apply_ui_action(player, action)
	if type(action) ~= "table" then
		return
	end
	if action.action == "open_catalog" then
		exo_ui.set_model(player, ui_model(player, eligible_ids()))
		exo_ui.show_page(player, "catalog")
	elseif action.action == "enter_border" then
		if not enter_border(player) then
			exo_ui.set_model(player, ui_model(player))
		end
	elseif action.action == "banish_selected" then
		if still_legal(action.collectible_id) and player_holds_certificate(player) then
			exo_ui.begin_verdict(player, action.collectible_id)
		end
	elseif action.action == "cancel" then
		exo_ui.begin_close(player)
	end
end

Select.register({
	id = PANEL_ID,
	own_key = item.own_key,
	selection_key = item.own_key,
	item_id = item.entity,
	open_lock = 8,
	reopen_on_room = false,
	on_open = function(_, player)
		local data = player:GetData()
		data[item.own_key .. "effect"] = true
		data[item.own_key .. "mode"] = "menu"
		data[item.own_key .. "menu"] = 0
		data[item.own_key .. "counter"] = 0
		data[item.own_key .. "tp"] = 0
		data[item.own_key .. "candidates"] = nil
		data[item.own_key .. "catalog"] = nil
		data[item.own_key .. "last_open_dir"] = 9
		data[item.own_key .. "last_open_dir_counter"] = 0
		exo_ui.open(player, ui_model(player))
	end,
	on_close = function(_, player)
		clear_panel_data(player)
	end,
	on_exit = function(_, player)
		if exo_ui.is_locked(player) then
			return true
		end
		if exo_ui.back_to_menu(player) then
			return true
		end
		return false
	end,
	on_input = function(session, player, can_interact)
		if not can_interact or Select.input_locked(session) then
			return
		end
		local action = exo_ui.handle_input(player)
		if action then
			apply_ui_action(player, action)
		end
	end,
})

local function render_border_notice()
	if not in_border() then
		return
	end
	local room = Game():GetRoom()
	if room.GetRenderMode and room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then
		return
	end
	local state = peek_session()
	local floor = peek_floor()
	local plan = state and state.last_plan
	local missing = plan and plan.missing or 0
	local lines = {}
	if missing > 0 then
		lines[#lines + 1] = text("还有 " .. missing .. " 件放不进这间房间", missing .. " items do not fit this room")
	end
	local fallback = floor and floor.return_fallback
	if fallback == "no_verified_source" or fallback == "continue_without_source" then
		lines[#lines + 1] = text("没有可核对的返回房间，返回门未生成", "No verified return room, so the door was not spawned")
	elseif state and state.door_ok == false then
		lines[#lines + 1] = text("返回门没有生成", "The return door did not spawn")
	end
	if floor and floor.settle_error == "BANISH_REMOVE_FAILED" then
		lines[#lines + 1] = text("永久放逐没有解除", "The banishment was not lifted")
	elseif floor and floor.settle_error == "NOT_BANISHED" then
		lines[#lines + 1] = text("这件道具不在放逐名单里", "That item is not on the banish list")
	end
	if floor and floor.option_fallback == "index_exhausted" then
		lines[#lines + 1] = text("选项组已用尽，这次陈列没有互斥", "No free Options group, so this display is not exclusive")
	end
	local pos = Isaac.WorldToScreen(room:GetCenterPos())
	for i, line in ipairs(lines) do
		gui.draw_text_units(line, pos.X - 70, pos.Y + 40 + (i - 1) * 14, 1, 1, KColor(1, 1, 1, 1), nil)
	end
end

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	params = nil,
	Function = function(_, continue)
		icon_cache = {}
		if continue ~= true then
			apply_new_run()
			save.elses[FLOOR_KEY] = nil
		else
			local state = peek_session()
			if state then
				state.prepared = false
				drop_claim(state, "CONTINUE")
			end
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	params = nil,
	Function = function()
		clear_transit()
		note_border_entry("continue")
		apply_backdrop_on_entry()
		place_entry_players()
		spawn_border_door()
		sync_border_pedestals()
		hide_border_rooms(true)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_LEVEL,
	params = nil,
	Function = function()
		save.elses[SESSION_KEY] = nil
		save.elses[FLOOR_KEY] = nil
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		clear_transit()
		note_border_entry("enter")
		apply_backdrop_on_entry()
		place_entry_players()
		spawn_border_door()
		if in_border() then
			local visit = peek_session()
			if not visit or not visit.test then
				clear_layout_previews()
			end
		end
		sync_border_pedestals()
		seal_doors()
		finish_border_return()
		abandon_open_border_visit()
		hide_border_rooms(true)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_GAME_EXIT,
	params = nil,
	Function = function()
		clear_transit()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_INPUT_ACTION,
	params = nil,
	Function = function(_, ent, hook, button)
		if not transit or not ent or not ent.ToPlayer then
			return
		end
		local player = ent:ToPlayer()
		if not player or player_index(player) ~= transit.player_index then
			return
		end
		local blocked = button == ButtonAction.ACTION_LEFT
			or button == ButtonAction.ACTION_RIGHT
			or button == ButtonAction.ACTION_UP
			or button == ButtonAction.ACTION_DOWN
			or button == ButtonAction.ACTION_SHOOTLEFT
			or button == ButtonAction.ACTION_SHOOTRIGHT
			or button == ButtonAction.ACTION_SHOOTUP
			or button == ButtonAction.ACTION_SHOOTDOWN
			or button == ButtonAction.ACTION_DROP
			or button == ButtonAction.ACTION_PILLCARD
			or button == ButtonAction.ACTION_MAP
			or button == ButtonAction.ACTION_BOMB
			or button == ButtonAction.ACTION_ITEM
		if not blocked then
			return
		end
		if hook == InputHook.IS_ACTION_TRIGGERED or hook == InputHook.IS_ACTION_PRESSED then
			return false
		end
		if hook == InputHook.GET_ACTION_VALUE then
			return 0
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_USE_ITEM,
	params = item.entity,
	Function = function(_, _id, _rng, player, useFlags)
		if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
			return { Discharge = false, Remove = false, ShowAnim = false }
		end
		if transit then
			return { Discharge = false, Remove = false, ShowAnim = false }
		end
		if in_border() then
			return_home()
			return { Discharge = false, Remove = false, ShowAnim = false }
		end
		if Select.is_open(PANEL_ID, player) then
			return { Discharge = false, Remove = false, ShowAnim = false }
		end
		if #menu_options() == 0 then
			return { Discharge = false, Remove = false, ShowAnim = false }
		end
		open_panel(player)
		-- Discharge=false：这次打开不触发放逐证明自己的美德书魂火。目标魂火只在签发成功后生成。
		return { Discharge = false }
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE,
	params = nil,
	Function = function(_, player)
		tick_transit(player)
		if not Select.is_open(PANEL_ID, player) then
			return
		end
		if Select.pause_menu_open() or Game():IsPaused() then
			if auxi.is_time_stopped(item.own_key) then
				auxi.time_free(item.own_key)
			end
			if transit and transit.time_held then
				transit.time_held = false
				transit.pause_freed = true
			end
			return
		end
		if not auxi.is_time_stopped(item.own_key) then
			auxi.time_stop(item.own_key)
		end
		local request = exo_ui.tick(player)
		if request and request.action == "commit_banish" then
			local ok = try_banish(player, request.collectible_id)
			if ok then
				grant_banish_synergy(player, request.collectible_id)
			end
			exo_ui.finish_commit(player, ok == true)
		end
		if exo_ui.ready_to_dismiss(player) then
			local entering = transit and transit.phase == "closing_ui" and player_index(player) == transit.player_index
			close_panel(player)
			if entering and transit then
				hold_transit_time()
				transit.phase = "settle_lift"
				transit.lift_frame = Game():GetFrameCount()
			end
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_HUD_RENDER,
	params = nil,
	Function = function()
		local session = Select.get(PANEL_ID)
		local player = session and session.player
		if not player or not exo_ui.is_open(player) or Select.pause_menu_open() then
			return
		end
		local room = Game():GetRoom()
		if room.GetRenderMode and room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then
			return
		end
		exo_ui.render(player, icon_sprite)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_RENDER,
	params = nil,
	Function = function()
		render_border_notice()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		sync_border_pedestals()
		seal_doors()
		release_unpicked_claim()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION,
	params = PickupVariant.PICKUP_COLLECTIBLE,
	priority = -140,
	Function = function(_, pickup, collider)
		if not pickup or not in_border() then
			return
		end
		local visit = peek_session()
		local data = pickup:GetData()
		if data[item.own_key .. "layout_preview"] or (visit and visit.test) then
			return true
		end
		local id = tonumber(data[item.own_key .. "border_id"])
		local gid = generation_id_of(pickup)
		local floor = peek_floor()
		local offered = gid and floor and floor.offers and tonumber(floor.offers[gid]) or nil
		if not id and not offered then
			return
		end
		id = id or offered
		local player = collider and collider.ToPlayer and collider:ToPlayer()
		if not player then
			return true
		end
		if not gid or not floor then
			return nil
		end
		local claim = floor.claim
		if type(claim) ~= "table" or (not claim.queue_linked and tostring(claim.generation_id) ~= gid) then
			floor.claim = {
				claim_id = new_claim_id(),
				generation_id = gid,
				collectible_id = id,
				player_index = player_index(player),
				frame = Game():GetFrameCount(),
				queue_linked = false,
			}
		end
		return nil
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_PICKUP_COLLECTIBLE,
	params = nil,
	Function = function(_, player, id, _touched, ent, source_context)
		local floor = peek_floor()
		local claim = floor and floor.claim
		local source = type(source_context) == "table" and source_context.source or nil
		if type(claim) ~= "table" then
			return
		end
		if claim.settled then
			return
		end
		if claim.queue_linked then
			return
		end
		if player_index(player) ~= claim.player_index then
			return
		end
		if tonumber(id) ~= tonumber(claim.collectible_id) then
			return
		end
		local gid = source and source.generation_id or nil
		if gid == nil then
			gid = generation_id_of(ent)
		end
		if not gid or tostring(claim.generation_id) ~= tostring(gid) then
			return
		end
		claim.queue_linked = true
		claim.frame = Game():GetFrameCount()
		claim.acquisition_id = type(source_context) == "table" and source_context.acquisition_id or nil
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE,
	params = nil,
	Function = function(_, player, id, _cnt, _touched, _prev, from_direct, gain_context)
		if from_direct == true then
			return
		end
		if type(gain_context) ~= "table" then
			return
		end
		local floor = peek_floor()
		if not floor then
			return
		end
		local claim = floor.claim
		local collectible_holder = require("Qing_Remaster_scripts.callbacks.collectible_holder")
		local source = collectible_holder.get_acquisition_source
			and collectible_holder.get_acquisition_source(gain_context)
		if not source or source.generation_id == nil then
			return
		end
		if source.collectible_id and tonumber(source.collectible_id) ~= tonumber(id) then
			return
		end
		if type(claim) == "table" then
			if player_index(player) ~= claim.player_index then
				return
			end
			if tonumber(id) ~= tonumber(claim.collectible_id) then
				return
			end
			if tostring(source.generation_id) ~= tostring(claim.generation_id) then
				return
			end
			local gain_aid = gain_context.acquisition_id
			if claim.acquisition_id ~= nil and gain_aid ~= nil and tostring(claim.acquisition_id) ~= tostring(gain_aid) then
				return
			end
			claim.queue_linked = true
		end
		commit_retrieve(id, source.generation_id)
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_GET_TELEPORT,
	params = "door",
	Function = function()
		if transit then
			return false
		end
		if in_border() and return_home() then
			return false
		end
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_REWIND,
	params = nil,
	Function = function()
		icon_cache = {}
		local floor = peek_floor()
		if floor and type(floor.claim) == "table" then
			drop_claim(peek_session(), "REWIND")
		end
	end,
})

local function clamp_debug_count(count)
	count = math.floor(tonumber(count) or 1)
	if count < 1 then
		count = 1
	elseif count > 32 then
		count = 32
	end
	return count
end

local function debug_shape_for(count)
	local shape = item.debug_config.shape or "auto"
	if shape == "auto" then
		return layout.auto_shape(count)
	end
	return shape
end

local function format_plan(plan)
	if type(plan) ~= "table" then
		return ""
	end
	local coords = {}
	for _, cell in ipairs(plan.positions or {}) do
		coords[#coords + 1] = tostring(cell.x) .. "," .. tostring(cell.y)
	end
	return table.concat({
		"房型 " .. tostring(plan.shape) .. "  variant " .. tostring(plan.variant),
		"算法 " .. tostring(plan.mode),
		"生成 " .. tostring(plan.placed) .. "  放不下 " .. tostring(plan.missing),
		"最小曼哈顿 " .. tostring(plan.min_manhattan),
		"左右镜像 " .. tostring(plan.mirror_ok),
		"棋盘相位 " .. tostring(plan.parity_ok),
		"可达 " .. tostring(plan.reachable),
		"门前留空 " .. tostring(plan.door_clear),
		"坐标 " .. table.concat(coords, " "),
	}, "\n")
end

function item.debug_plan_text()
	local count = clamp_debug_count(item.debug_config.count)
	return format_plan(layout.plan(debug_shape_for(count), count, item.debug_config.algorithm or "auto"))
end

function item.debug_enter()
	if not g.is_gameplay_world_active() then
		item.debug_status = "不在可玩世界"
		return false
	end
	local count = clamp_debug_count(item.debug_config.count)
	item.debug_config.count = count
	local shape = debug_shape_for(count)
	local player = Game():GetPlayer(0)
	local visiting = in_border() and peek_session() or nil
	if visiting and visiting.test then
		visiting.test_count = count
		visiting.test_shape = shape
		visiting.test_algorithm = item.debug_config.algorithm or "auto"
		visiting.test_seed = item.debug_config.seed or 1
		visiting.prepared = false
		if current_shape() == shape then
			visiting.phase = "choosing"
			sync_border_pedestals()
			item.debug_status = format_plan(visiting.last_plan)
			return true
		end
		clear_layout_previews()
		visiting.entry_placed = nil
		visiting.phase = "inbound"
		local dimension = auxi.GetDimension() or 0
		local index = ensure_test_room(dimension, shape)
		if not index then
			item.debug_status = "本层没有空位。已有测试房间会继续复用；请换一层再生成新尺寸。"
			return false
		end
		close_panel(player)
		Room_holder.Trans_to(index, Direction.NO_DIRECTION, RoomTransitionAnim.FADE, player, dimension, nil)
		item.debug_status = "正在进入 " .. shape
		return true
	end
	if in_border() then
		item.debug_status = "当前在正式边境，请先从炼狱门返回"
		return false
	end
	if not capture_origin(player) then
		item.debug_status = "无法记录来源房间"
		return false
	end
	local state = session()
	state.test = true
	state.test_count = count
	state.test_shape = shape
	state.test_algorithm = item.debug_config.algorithm or "auto"
	state.test_seed = item.debug_config.seed or 1
	local dimension = auxi.GetDimension() or 0
	local index = ensure_test_room(dimension, shape)
	if not index then
		save.elses[SESSION_KEY] = nil
		item.debug_status = "本层没有空位。已有测试房间会继续复用；请换一层再生成新尺寸。"
		return false
	end
	close_panel(player)
	Room_holder.Trans_to(index, Direction.NO_DIRECTION, RoomTransitionAnim.FADE, player, dimension, nil)
	item.debug_status = "正在进入 " .. shape
	return true
end

function item.debug_reroll()
	local state = peek_session()
	if not state or not state.test or not in_border() then
		item.debug_status = "当前不是测试边境"
		return false
	end
	item.debug_config.seed = (tonumber(item.debug_config.seed) or 1) + 1
	state.test_seed = item.debug_config.seed
	state.prepared = false
	sync_border_pedestals()
	item.debug_status = format_plan(state.last_plan)
	return true
end

function item.debug_leave()
	if not in_border() then
		item.debug_status = "当前不在边境"
		return false
	end
	if not return_home() then
		item.debug_status = "没有可用的返回房间"
		return false
	end
	item.debug_status = "正在返回"
	return true
end

function item.debug_scan()
	local failed = layout.audit_auto()
	if #failed == 0 then
		item.debug_scan_text = "1-32 自动布局通过"
	else
		local lines = {}
		for _, row in ipairs(failed) do
			lines[#lines + 1] = tostring(row.count) .. " " .. row.shape .. " " .. table.concat(row.reasons, ",")
		end
		item.debug_scan_text = table.concat(lines, "\n")
	end
	item.debug_status = item.debug_scan_text
	return item.debug_scan_text
end

function item.debug_return_text()
	if not g.is_gameplay_world_active() then
		return "不在可玩世界"
	end
	local floor = peek_floor()
	local target = floor and floor.entry_return
	local state = peek_session()
	local door_index = state and state.door_index or nil
	local source = target and target.source or (floor and floor.return_fallback) or "none"
	return "返回目标 " .. tostring(target and target.index) .. " (" .. tostring(source) .. ")\n门格 " .. tostring(door_index) .. "\n" .. format_plan(state and state.last_plan)
end

return item
