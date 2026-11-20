-- Antechamber dormant black formation: matte Effects + GridPath blocking.
-- Effects use native Y-sort (not POST_RENDER). Not NPCs; no Director / damage / Room Clear.

local reserve_defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_defs")
local matte_fx = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.piece_matte_fx")
local soft_collision = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.chess_piece_soft_collision")

local ante = {}

local active = false
local pieces = {} -- { id, kind, pos, grid_index, effect }
local path_saved = {} -- gridIndex -> previous GridPath
local list_index = nil
local last_fail = "none"
local last_diag = nil

local function room_list_index()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	return desc and desc.ListIndex
end

local function clear_grid_path()
	local room = Game():GetRoom()
	if room and room.SetGridPath then
		for idx, prev in pairs(path_saved) do
			if type(idx) == "number" and type(prev) == "number" then
				room:SetGridPath(idx, prev)
			end
		end
	end
	path_saved = {}
end

local function apply_grid_path()
	local room = Game():GetRoom()
	if not room or not room.SetGridPath or not room.GetGridPath then
		return
	end
	local cost = reserve_defs.gridpath_cost()
	for _, row in ipairs(pieces) do
		local idx = row.grid_index
		if type(idx) == "number" and idx >= 0 and path_saved[idx] == nil then
			local prev = room:GetGridPath(idx)
			if type(prev) ~= "number" then
				prev = 0
			end
			if prev < cost then
				path_saved[idx] = prev
				room:SetGridPath(idx, cost)
			end
		end
	end
end

local function remove_effects()
	for _, row in ipairs(pieces) do
		if row.effect then
			matte_fx.remove(row.effect)
			row.effect = nil
		end
	end
end

function ante.is_active()
	return active
end

function ante.get_pieces()
	return pieces
end

function ante.clear(reason)
	clear_grid_path()
	remove_effects()
	pieces = {}
	active = false
	list_index = nil
	last_fail = reason or "cleared"
	return last_fail
end

--- Spawn staggered ante matte guards (20 real + 4 decorative; decorative never enter Boss).
function ante.spawn()
	ante.clear("respawn")
	local room = Game():GetRoom()
	local cells, why, diag = reserve_defs.resolve_ante_layout(room)
	last_diag = diag
	if not cells then
		last_fail = why or "layout_failed"
		Isaac.DebugString(string.format("[FloraineV2] ante layout failed: %s", tostring(last_fail)))
		if type(diag) == "table" then
			Isaac.DebugString(string.format(
				"[FloraineV2] ante diag cols=%s rows=%s fail_id=%s gidx=%s",
				tostring(diag.cols), tostring(diag.rows), tostring(diag.fail_id), tostring(diag.fail_gidx)
			))
		end
		return false, last_fail, diag
	end
	local expect = reserve_defs.ANTE_VISUAL_COUNT or 24
	for _, cell in ipairs(cells) do
		local ent = matte_fx.spawn(cell.kind, cell.pos, {
			owner = cell.decorative and "ante_deco" or "ante",
			piece_id = cell.id,
			color_progress = 0,
			outline_alpha = 0,
		})
		pieces[#pieces + 1] = {
			id = cell.id,
			kind = cell.kind,
			side = cell.side,
			ante_col = cell.ante_col,
			ante_row = cell.ante_row,
			reserve_slot = cell.reserve_slot,
			decorative = cell.decorative == true,
			pos = Vector(cell.pos.X, cell.pos.Y),
			grid_index = cell.grid_index,
			effect = ent,
		}
	end
	list_index = room_list_index()
	apply_grid_path()
	active = #pieces == expect
	last_fail = active and "ok" or "count_mismatch"
	if not active then
		Isaac.DebugString(string.format("[FloraineV2] ante spawn count=%d expected=%d", #pieces, expect))
	end
	return active, #pieces, last_diag
end

local function soft_block_players()
	local room = Game():GetRoom()
	local center_x = room:GetCenterPos().X
	local radius = soft_collision.default_radius()
	local strength = soft_collision.default_strength()
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player and player:Exists() and not player:IsDead() then
			for _, row in ipairs(pieces) do
				if soft_collision.push_player(player, row.pos, center_x, strength, radius) then
					break -- one push per player per logic frame
				end
			end
		end
	end
end

function ante.tick()
	if not active then
		return
	end
	local li = room_list_index()
	if list_index ~= nil and li ~= list_index then
		ante.clear("room_changed")
		return
	end
	apply_grid_path()
	soft_block_players()
	for _, row in ipairs(pieces) do
		if row.effect and matte_fx.is_matte(row.effect) then
			matte_fx.sync(row.effect, {
				ground_pos = row.pos,
				visual_height = 0,
				color_progress = 0,
				outline_alpha = 0,
			})
		elseif row.effect == nil or not (row.effect.Exists and row.effect:Exists()) then
			-- Recreate if Effect was culled unexpectedly.
			row.effect = matte_fx.spawn(row.kind, row.pos, {
				owner = "ante",
				piece_id = row.id,
				color_progress = 0,
				outline_alpha = 0,
			})
		end
	end
end

--- Native Effect render owns draw; keep no-op for rooms.render_room_fx compatibility.
function ante.render()
end

function ante.diag()
	local deco = 0
	for _, row in ipairs(pieces) do
		if row.decorative then
			deco = deco + 1
		end
	end
	return {
		active = active,
		count = #pieces,
		deco = deco,
		real = #pieces - deco,
		list_index = list_index,
		last_fail = last_fail,
		layout = last_diag,
		uses_effect = true,
		path_marks = (function()
			local n = 0
			for _ in pairs(path_saved) do n = n + 1 end
			return n
		end)(),
	}
end

return ante
