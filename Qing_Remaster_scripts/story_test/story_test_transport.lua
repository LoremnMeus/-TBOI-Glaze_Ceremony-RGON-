-- Floor / room transport for Story Test Lab.

local registry = require("Qing_Remaster_scripts.story_test.story_test_registry")
local session = require("Qing_Remaster_scripts.story_test.story_test_session")
local glaze_route = require("Qing_Remaster_scripts.story.glaze_route_rules")

local transport = {}

local READINESS = {
	READY = "READY",
	NEARBY = "NEARBY",
	NOT_GENERATED = "NOT_GENERATED",
}

transport.READINESS = READINESS

local function safe_command(cmd)
	if type(cmd) ~= "string" or cmd == "" then return false, "empty command" end
	local ok, err = pcall(function()
		Isaac.ExecuteCommand(cmd)
	end)
	if not ok then return false, tostring(err) end
	return true
end

local function current_stage_info()
	local game = Game and Game()
	if not game then return {} end
	local level = game:GetLevel()
	if not level then return {} end
	local room = game:GetRoom()
	local desc = level.GetCurrentRoomDesc and level:GetCurrentRoomDesc()
	local seeds = game.GetSeeds and game:GetSeeds()
	return {
		stage = level:GetStage(),
		stage_type = level:GetStageType(),
		room_type = room and room:GetType() or nil,
		safe_grid_index = desc and desc.SafeGridIndex or nil,
		mirror_world = room and room:IsMirrorWorld() == true or false,
		seed = seeds and seeds.GetStartSeedString and seeds:GetStartSeedString() or nil,
	}
end

local function change_room(index, dimension)
	local ok, err = pcall(function()
		if Game().ChangeRoom then
			if dimension == nil or dimension < 0 then
				Game():ChangeRoom(index)
			else
				Game():ChangeRoom(index, dimension)
			end
		else
			Game():GetLevel():ChangeRoom(index)
		end
	end)
	if not ok then return false, tostring(err) end
	return true
end

local function place_player_at(pos)
	if not pos then return false end
	local player = Game():GetPlayer(0)
	if not player then return false end
	player.Position = pos
	player.Velocity = Vector.Zero
	return true
end

function transport.resolve_preset(preset_id)
	if not preset_id or preset_id == "current" then return nil end
	return registry.get_level_preset(preset_id)
end

function transport.goto_level_preset(preset_id, opts)
	opts = opts or {}
	local log = {
		requested_preset = preset_id,
		before = current_stage_info(),
	}
	local preset = transport.resolve_preset(preset_id)
	if not preset then
		log.result = "kept current floor"
		return true, log.result, log
	end
	if not preset.command then
		log.result = "preset has no command"
		return true, log.result, log
	end
	log.stage_command = "stage " .. tostring(preset.command)
	local ok, err = safe_command(log.stage_command)
	if not ok then
		log.error = err
		return false, err, log
	end
	local mode = opts.mode or "natural"
	if mode == "natural" or opts.reseed ~= false then
		ok, err = safe_command("reseed")
		log.reseed = true
		if not ok then
			log.error = err
			return false, err, log
		end
	end
	log.after = current_stage_info()
	log.result = log.stage_command
	return true, log.result, log
end

function transport.reseed_floor()
	local ok, err = safe_command("reseed")
	return ok, ok and "reseed" or err
end

function transport.goto_starting_room()
	return safe_command("goto 0")
end

function transport.find_boss_room_index()
	local level = Game() and Game():GetLevel()
	if not level then return nil end
	local rooms = level:GetRooms()
	if not rooms then return nil end
	for i = 0, rooms.Size - 1 do
		local desc = rooms:Get(i)
		if desc and desc.Data and desc.Data.Type == RoomType.ROOM_BOSS then
			return desc.SafeGridIndex or desc.GridIndex
		end
	end
	return nil
end

function transport.goto_boss_exit()
	local index = transport.find_boss_room_index()
	if index == nil then
		return false, "no boss room", {readiness = READINESS.NOT_GENERATED}
	end
	local ok, err = change_room(index, -1)
	if not ok then return false, err, {readiness = READINESS.NOT_GENERATED} end
	return true, "boss room " .. tostring(index), {readiness = READINESS.READY, room_index = index}
end

function transport.apply_spawn_anchor(anchor)
	if not anchor or anchor == "none" or anchor == "room" then
		return true, "no anchor"
	end
	local room = Game():GetRoom()
	if not room then return false, "no room" end
	if anchor == "white_fire" then
		local fires = glaze_route.find_white_fireplaces(room)
		if #fires == 0 then return false, "no white fire" end
		local pos = fires[1].Position
		local center = room:GetCenterPos()
		local toward = (center - pos):Normalized() * 28
		place_player_at(pos + toward)
		return true, "white_fire"
	end
	if anchor == "mirror_door" then
		local door, grid_index = glaze_route.find_mirror_door(room)
		if not door then return false, "no mirror door" end
		local door_pos = door.Position
		if grid_index and room.GetGridPosition then
			door_pos = room:GetGridPosition(grid_index)
		end
		local center = room:GetCenterPos()
		local toward = (center - door_pos):Normalized() * 40
		place_player_at(door_pos + toward)
		return true, "mirror_door"
	end
	return false, "unknown spawn_anchor: " .. tostring(anchor)
end

function transport.apply_player_loadout(player_spec)
	if type(player_spec) ~= "table" then return true, "no player loadout" end
	local player = Game():GetPlayer(0)
	if not player then return false, "no player" end
	local messages = {}
	if player_spec.bombs ~= nil then
		local want = math.max(0, math.floor(tonumber(player_spec.bombs) or 0))
		local have = player:GetNumBombs()
		if want > have then
			player:AddBombs(want - have)
		end
		messages[#messages + 1] = "bombs=" .. tostring(want)
	end
	return true, table.concat(messages, ",")
end

function transport.goto_glaze_mirror_room(opts)
	opts = opts or {}
	local log = {
		selector = "glaze_mirror_room",
		dimension = opts.dimension or "normal",
		spawn_anchor = opts.spawn_anchor,
	}
	local level = Game() and Game():GetLevel()
	if not level then
		log.readiness = READINESS.NOT_GENERATED
		return false, "no level", log
	end
	local desc, index = glaze_route.find_mirror_room_desc(level)
	if index == nil then
		log.readiness = READINESS.NOT_GENERATED
		log.result = "no glaze mirror room on this seed"
		return false, log.result, log
	end
	log.room_index = index
	log.room_variant = desc and desc.Data and desc.Data.Variant or nil
	local dim = glaze_route.dimension_id(opts.dimension or "normal")
	if dim == 1 and not glaze_route.has_mirror_dimension(level) then
		log.readiness = READINESS.NOT_GENERATED
		log.result = "mirror dimension unavailable"
		return false, log.result, log
	end
	log.dimension_id = dim
	local ok, err = change_room(index, dim)
	if not ok then
		log.readiness = READINESS.NOT_GENERATED
		log.error = err
		return false, err, log
	end
	local room = Game():GetRoom()
	log.mirror_world = room and room:IsMirrorWorld() == true or false
	if opts.spawn_anchor then
		local aok, amsg = transport.apply_spawn_anchor(opts.spawn_anchor)
		log.anchor = amsg
		if not aok then
			log.readiness = READINESS.NEARBY
			log.result = "mirror room entered; anchor missing (" .. tostring(amsg) .. ")"
			return true, log.result, log
		end
	end
	log.readiness = READINESS.READY
	log.result = string.format(
		"glaze mirror room %s dim=%s",
		tostring(index),
		tostring(opts.dimension or "normal")
	)
	return true, log.result, log
end

function transport.apply_room_selector(selector, opts)
	opts = opts or {}
	if not selector or selector == "current_room" then
		return true, "current room", {readiness = READINESS.READY, selector = selector}
	end
	if selector == "starting_room" then
		local ok, msg = transport.goto_starting_room()
		return ok, msg, {readiness = ok and READINESS.READY or READINESS.NOT_GENERATED, selector = selector}
	end
	if selector == "boss_exit" or selector == "boss" then
		return transport.goto_boss_exit()
	end
	if selector == "glaze_mirror_room" then
		return transport.goto_glaze_mirror_room(opts)
	end
	if type(selector) == "string" and selector:sub(1, 6) == "stone_" then
		local ok_dbg, stone_debug = pcall(require, "Qing_Remaster_scripts.threads.stone.stone_debug")
		if not ok_dbg or not stone_debug then
			return false, "stone_debug missing", {readiness = READINESS.NOT_GENERATED, selector = selector}
		end
		local ok, msg = stone_debug.transport_selector(selector, opts)
		return ok, msg, {
			readiness = ok and READINESS.READY or READINESS.NOT_GENERATED,
			selector = selector,
			result = msg,
		}
	end
	return false, "unsupported room selector: " .. tostring(selector), {
		readiness = READINESS.NOT_GENERATED,
		selector = selector,
	}
end

function transport.prepare_run(step, opts)
	opts = opts or {}
	local messages = {}
	local log = {steps = {}, readiness = READINESS.READY}
	local preset = step.level_preset
	if preset and preset ~= "current" then
		local ok, msg, plog = transport.goto_level_preset(preset, {
			mode = (step.entry and step.entry.mode) or "natural",
			reseed = opts.reseed,
		})
		messages[#messages + 1] = tostring(msg)
		log.steps[#log.steps + 1] = plog
		log.level = plog
		if not ok then
			log.readiness = READINESS.NOT_GENERATED
			session.last_transport_log = log
			return false, table.concat(messages, "; "), log
		end
	else
		messages[#messages + 1] = "no level change"
		log.level = {result = "no level change", after = current_stage_info()}
	end
	local room = step.room or (step.run and step.run.room)
	if room and room.selector then
		local ok, msg, rlog = transport.apply_room_selector(room.selector, {
			dimension = room.dimension,
			spawn_anchor = room.spawn_anchor,
		})
		messages[#messages + 1] = tostring(msg)
		log.room = rlog or {selector = room.selector, result = msg}
		if rlog and rlog.readiness then
			log.readiness = rlog.readiness
		end
		if not ok then
			-- Floor may still be correct; keep NOT_GENERATED so UI can reseed.
			log.readiness = (rlog and rlog.readiness) or READINESS.NOT_GENERATED
			log.after = current_stage_info()
			session.last_transport_log = log
			return false, table.concat(messages, "; "), log
		end
	end
	if step.player then
		local pok, pmsg = transport.apply_player_loadout(step.player)
		messages[#messages + 1] = tostring(pmsg)
		log.player = {result = pmsg, ok = pok}
		if not pok then
			log.readiness = READINESS.NEARBY
		end
	end
	log.after = current_stage_info()
	session.last_transport_log = log
	return true, table.concat(messages, "; "), log
end

local STAGE_NAME = {
	[LevelStage and LevelStage.STAGE1_2 or -1] = "STAGE1_2",
	[LevelStage and LevelStage.STAGE2_1 or -2] = "STAGE2_1",
	[LevelStage and LevelStage.STAGE3_1 or -3] = "STAGE3_1",
	[LevelStage and LevelStage.STAGE3_2 or -4] = "STAGE3_2",
	[LevelStage and LevelStage.STAGE8 or -5] = "STAGE8",
}

local TYPE_NAME = {
	[StageType and StageType.STAGETYPE_REPENTANCE or -1] = "REPENTANCE",
	[StageType and StageType.STAGETYPE_REPENTANCE_B or -2] = "REPENTANCE_B",
	[StageType and StageType.STAGETYPE_ORIGINAL or -3] = "ORIGINAL",
}

function transport.validate_step(step)
	if not step or not step.level_preset or step.level_preset == "current" then
		return nil
	end
	local preset = registry.get_level_preset(step.level_preset)
	if not preset then return nil end
	local info = current_stage_info()
	local results = {}
	local stage_name = STAGE_NAME[info.stage] or tostring(info.stage)
	local type_name = TYPE_NAME[info.stage_type] or tostring(info.stage_type)
	local stage_ok = true
	if preset.stage_family then
		stage_ok = false
		for _, name in ipairs(preset.stage_family) do
			if name == stage_name then stage_ok = true break end
		end
	elseif preset.stage then
		stage_ok = stage_name == preset.stage
	end
	results[#results + 1] = {
		name = "transport_stage",
		pass = stage_ok,
		detail = stage_name,
	}
	local type_ok = true
	if preset.stage_type_family then
		type_ok = false
		for _, name in ipairs(preset.stage_type_family) do
			if name == type_name then type_ok = true break end
		end
	elseif preset.stage_type then
		-- REPENTANCE preset accepts REPENTANCE_B (Downpour II / Dross II).
		if preset.stage_type == "REPENTANCE" then
			type_ok = type_name == "REPENTANCE" or type_name == "REPENTANCE_B"
		else
			type_ok = type_name == preset.stage_type
		end
	end
	results[#results + 1] = {
		name = "transport_stage_type",
		pass = type_ok,
		detail = type_name,
	}
	local tlog = session.last_transport_log
	if tlog and tlog.readiness then
		results[#results + 1] = {
			name = "transport_readiness",
			pass = tlog.readiness == READINESS.READY,
			detail = tlog.readiness,
		}
	end
	return results
end

return transport
