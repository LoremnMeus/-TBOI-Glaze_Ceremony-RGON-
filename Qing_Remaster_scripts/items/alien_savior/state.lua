-- Persistable SOS / comms state for Alien Savior.
local save = require("Qing_Remaster_scripts.core.savedata")
local C = require("Qing_Remaster_scripts.items.alien_savior.constants")
local rock_topology = require("Qing_Remaster_scripts.others.grid_rock_topology")

local M = {}

local ROOT = "AlienSavior"
local NULL_SHEET = "gfx/effects/nill.png"

-- Room-local SOS only (runtime). Continue / new room clears; not a cooldown business key.
local room_sos = {} -- [player_key] = true when ARMED this room visit

local function root()
	-- Always re-fetch save.elses; never cache the table across rewind.
	save.elses[ROOT] = save.elses[ROOT] or { players = {}, absorbed_grids = {} }
	local r = save.elses[ROOT]
	r.players = r.players or {}
	r.absorbed_grids = r.absorbed_grids or {}
	return r
end

function M.player_key(player)
	if not player or not player.ToPlayer then
		return nil
	end
	player = player:ToPlayer()
	if not player then
		return nil
	end
	local data = player:GetData()
	local idx = data and data.__Index
	if idx == nil then
		return nil
	end
	return tostring(idx)
end

function M.room_id()
	local level = Game():GetLevel()
	local desc = level and level:GetCurrentRoomDesc()
	local list = desc and desc.ListIndex or -1
	local stage = level and level:GetStage() or -1
	local stype = level and level:GetStageType() or -1
	local dim = 0
	if level and level.GetDimension then
		dim = level:GetDimension() or 0
	end
	return string.format("%d:%d:%d:%d", stage, stype, dim, list)
end

function M.get_player_rec(pkey)
	if not pkey then
		return nil
	end
	local r = root()
	local rec = r.players[pkey]
	if type(rec) ~= "table" then
		rec = {
			comm = "READY",
			cooldown_left = 0,
			rescue_skip_room = nil,
			last_clear_room = nil,
			counted_rooms = {},
			alien_head = false,
		}
		r.players[pkey] = rec
	end
	if rec.comm ~= "READY" and rec.comm ~= "COOLDOWN" then
		rec.comm = "READY"
		rec.cooldown_left = 0
	end
	if type(rec.counted_rooms) ~= "table" then
		rec.counted_rooms = {}
	end
	return rec
end

function M.is_ready(pkey)
	local rec = M.get_player_rec(pkey)
	return rec and rec.comm == "READY"
end

function M.is_armed(pkey)
	return pkey ~= nil and room_sos[pkey] == true
end

function M.set_armed(pkey, armed)
	if not pkey then
		return
	end
	if armed then
		room_sos[pkey] = true
	else
		room_sos[pkey] = nil
	end
end

function M.clear_room_sos()
	room_sos = {}
end

function M.consume_comms(pkey)
	local rec = M.get_player_rec(pkey)
	if not rec then
		return
	end
	rec.comm = "COOLDOWN"
	rec.cooldown_left = C.COOLDOWN_ROOMS
	rec.rescue_skip_room = M.room_id()
end

function M.mark_rescue_room(pkey)
	local rec = M.get_player_rec(pkey)
	if rec then
		rec.rescue_skip_room = M.room_id()
	end
end

function M.on_combat_clear(pkey)
	if not pkey then
		return
	end
	local rec = M.get_player_rec(pkey)
	if not rec or rec.comm ~= "COOLDOWN" then
		return
	end
	local rid = M.room_id()
	if rec.rescue_skip_room == rid then
		return
	end
	if rec.counted_rooms[rid] then
		return
	end
	if rec.last_clear_room == rid then
		return
	end
	rec.counted_rooms[rid] = true
	rec.last_clear_room = rid
	local left = tonumber(rec.cooldown_left) or 0
	left = left - 1
	if left <= 0 then
		rec.comm = "READY"
		rec.cooldown_left = 0
		rec.alien_head = false
	else
		rec.cooldown_left = left
	end
end

--- Temporary Alien_Head until rescue becomes READY again (not a permanent item skin).
function M.wants_alien_head(pkey)
	local rec = M.get_player_rec(pkey)
	return rec and rec.alien_head == true and rec.comm == "COOLDOWN"
end

function M.set_alien_head(pkey, on)
	local rec = M.get_player_rec(pkey)
	if not rec then
		return
	end
	rec.alien_head = on == true
end

function M.reset_floor()
	local r = root()
	for _, rec in pairs(r.players) do
		if type(rec) == "table" then
			rec.comm = "READY"
			rec.cooldown_left = 0
			rec.rescue_skip_room = nil
			rec.last_clear_room = nil
			rec.counted_rooms = {}
			rec.alien_head = false
		end
	end
	r.absorbed_grids = {}
	room_sos = {}
end

function M.reset_all()
	save.elses[ROOT] = { players = {}, absorbed_grids = {} }
	room_sos = {}
end

local function paint_null_decoration(grid)
	if not grid then
		return
	end
	local s = grid.GetSprite and grid:GetSprite()
	if s and s.ReplaceSpritesheet then
		s:ReplaceSpritesheet(0, NULL_SHEET)
		if s.LoadGraphics then
			s:LoadGraphics()
		end
	end
	if grid.CollisionClass ~= nil then
		grid.CollisionClass = GridCollisionClass.COLLISION_NONE
	end
end

--- Invisible GRID_DECORATION placeholder (same pattern as auxi.tryremovegrid force).
function M.spawn_null_decoration(room, index)
	room = room or Game():GetRoom()
	if not room or index == nil then
		return false
	end
	if room.SetGridPath then
		room:SetGridPath(index, 0)
	end
	local seed = (room.GetSpawnSeed and room:GetSpawnSeed()) or 1
	if seed == 0 then
		seed = 1
	end
	room:SpawnGridEntity(index, GridEntityType.GRID_DECORATION, 0, seed, 0)
	local g = room:GetGridEntity(index)
	paint_null_decoration(g)
	return g ~= nil and g:GetType() == GridEntityType.GRID_DECORATION
end

function M.register_absorbed_grid(index, info)
	if index == nil then
		return
	end
	local r = root()
	local rid = M.room_id()
	r.absorbed_grids[rid] = r.absorbed_grids[rid] or {}
	r.absorbed_grids[rid][tostring(index)] = {
		index = index,
		tp = info and info.tp or nil,
		variant = info and info.variant or nil,
		frame = Game():GetFrameCount(),
	}
end

function M.is_absorbed_grid(index)
	if index == nil then
		return false
	end
	local bag = root().absorbed_grids[M.room_id()]
	return bag ~= nil and bag[tostring(index)] ~= nil
end

--- Re-apply decoration if a previously absorbed rock respawned on room re-entry.
function M.apply_absorbed_grids()
	local rid = M.room_id()
	local bag = root().absorbed_grids[rid]
	if type(bag) ~= "table" then
		return 0
	end
	local room = Game():GetRoom()
	if not room then
		return 0
	end
	local fixed = 0
	for key, _ in pairs(bag) do
		local index = tonumber(key)
		if index ~= nil then
			local grid = room:GetGridEntity(index)
			if grid and rock_topology.is_rock(grid) then
				rock_topology.remove_rock(room, index, { path_penalty = 0, keep_decoration = false })
				if room.RemoveGridEntityImmediate and room:GetGridEntity(index) then
					room:RemoveGridEntityImmediate(index, 0, false)
				end
				if M.spawn_null_decoration(room, index) then
					fixed = fixed + 1
				end
			elseif not grid then
				if M.spawn_null_decoration(room, index) then
					fixed = fixed + 1
				end
			elseif grid:GetType() == GridEntityType.GRID_DECORATION then
				paint_null_decoration(grid)
			end
		end
	end
	return fixed
end

function M.absorbed_grid_count(room_id)
	local bag = root().absorbed_grids[room_id or M.room_id()]
	if type(bag) ~= "table" then
		return 0
	end
	local n = 0
	for _ in pairs(bag) do
		n = n + 1
	end
	return n
end

function M.snapshot(pkey)
	local rec = M.get_player_rec(pkey)
	return {
		comm = rec and rec.comm or "?",
		cooldown_left = rec and rec.cooldown_left or 0,
		armed = M.is_armed(pkey),
		room = M.room_id(),
		rescue_skip = rec and rec.rescue_skip_room or nil,
		last_clear = rec and rec.last_clear_room or nil,
		absorbed_grids = M.absorbed_grid_count(),
	}
end

return M
