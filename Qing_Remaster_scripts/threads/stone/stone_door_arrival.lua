-- Stone hidden-chain door arrival: one-shot pending transfer → door-inward player place.
-- Module-local only (not save.elses). Continue / debug without a matching transfer never relocates.

local runtime = require("Qing_Remaster_scripts.threads.stone.stone_runtime")
local board = require("Qing_Remaster_scripts.threads.stone.stone_board")

local arrival = {}

local INWARD_DIST = 45
local COOP_SPREAD = 18

--- Named routes. arrival_slot nil for ANTE_TO_TERMINAL → resolve terminal.gate_slot at apply time.
arrival.ROUTE = {
	TERMINAL_TO_ANTE = {destination = "ante", arrival_slot = DoorSlot.DOWN0},
	ANTE_TO_FLORAINE = {destination = "floraine", arrival_slot = DoorSlot.DOWN0},
	FLORAINE_TO_ANTE = {destination = "ante", arrival_slot = DoorSlot.UP0},
	ANTE_TO_TERMINAL = {destination = "terminal", arrival_slot = nil},
	DEBUG_ANTE = {destination = "ante", arrival_slot = DoorSlot.DOWN0, debug = true},
	DEBUG_FLORAINE = {destination = "floraine", arrival_slot = DoorSlot.DOWN0, debug = true},
}

-- One-shot pending transfer (cleared on apply / reject / explicit clear).
local pending = nil
local last_diag = {
	source_room = nil,
	destination_room = nil,
	source_door_slot = nil,
	arrival_door_slot = nil,
	arrival_position = nil,
	arrival_applied = false,
	arrival_reject_reason = nil,
}

local function rooms_mod()
	return require("Qing_Remaster_scripts.threads.stone.stone_rooms")
end

local function note(fields)
	for k, v in pairs(fields) do
		last_diag[k] = v
	end
end

function arrival.get_diag()
	return last_diag
end

function arrival.has_pending()
	return pending ~= nil
end

function arrival.clear(why)
	note({
		arrival_applied = false,
		arrival_reject_reason = why or "cleared",
	})
	pending = nil
end

--- World position just inside a door slot (avoids immediate re-trigger).
function arrival.resolve_arrival_pos(slot)
	if slot == nil then
		return nil, "no_slot"
	end
	local room = Game():GetRoom()
	local door_pos = room:GetDoorSlotPosition(slot)
	if not door_pos then
		return nil, "no_door_pos"
	end
	local inward = board.door_inward_normal(slot)
	local pos = room:GetClampedPosition(door_pos + inward * INWARD_DIST, 20)
	return pos, "ok"
end

function arrival.begin(route_key, opts)
	opts = opts or {}
	local spec = arrival.ROUTE[route_key]
	if not spec then
		note({arrival_applied = false, arrival_reject_reason = "unknown_route"})
		return false, "unknown_route"
	end
	local source = opts.source
	if source == nil then
		source = rooms_mod().current_location()
	end
	pending = {
		key = route_key,
		source = source,
		destination = spec.destination,
		arrival_slot = opts.arrival_slot or spec.arrival_slot,
		source_door_slot = opts.source_door_slot,
		expect_variant = opts.expect_variant,
		expect_sgi = opts.expect_sgi,
		debug = spec.debug == true or opts.debug == true,
	}
	note({
		source_room = source,
		destination_room = spec.destination,
		source_door_slot = pending.source_door_slot,
		arrival_door_slot = pending.arrival_slot,
		arrival_position = nil,
		arrival_applied = false,
		arrival_reject_reason = nil,
	})
	return true
end

local function destination_matches(p)
	local rooms = rooms_mod()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local loc = rooms.current_location(desc)
	if loc ~= p.destination then
		return false, "dest_mismatch:" .. tostring(loc)
	end
	if p.destination == "terminal" then
		local want = p.expect_sgi
		if want == nil then
			local r = runtime.get()
			want = r.terminal and r.terminal.safe_grid_index
		end
		if want ~= nil and desc and desc.SafeGridIndex ~= want then
			return false, "terminal_sgi_mismatch"
		end
	elseif p.destination == "ante" or p.destination == "floraine" then
		if p.expect_variant ~= nil and desc and desc.Data and desc.Data.Variant ~= p.expect_variant then
			return false, "variant_mismatch"
		end
	end
	return true
end

local function place_players_at(center, slot)
	local room = Game():GetRoom()
	local inward = board.door_inward_normal(slot)
	local tangent = Vector(-inward.Y, inward.X)
	local n = Game():GetNumPlayers()
	for i = 0, n - 1 do
		local player = Game():GetPlayer(i)
		if player then
			local spread = 0
			if n > 1 then
				spread = (i - (n - 1) * 0.5) * COOP_SPREAD
			end
			local pos = room:GetClampedPosition(center + tangent * spread, 20)
			player.Position = pos
			player.Velocity = Vector.Zero
		end
	end
end

--- Consume pending transfer if current room matches. Safe no-op when none / mismatch.
function arrival.apply_if_pending()
	if not pending then
		note({
			arrival_applied = false,
			arrival_reject_reason = "no_pending",
		})
		return false, "no_pending"
	end
	local p = pending
	local ok, why = destination_matches(p)
	if not ok then
		-- Drop stale pending so Continue / wrong-room never keep relocating.
		pending = nil
		note({
			arrival_applied = false,
			arrival_reject_reason = why,
			source_room = p.source,
			destination_room = p.destination,
			source_door_slot = p.source_door_slot,
			arrival_door_slot = p.arrival_slot,
		})
		return false, why
	end

	local slot = p.arrival_slot
	if p.destination == "terminal" then
		local r = runtime.get()
		slot = r.terminal and r.terminal.gate_slot or slot
	end
	local pos, pos_why = arrival.resolve_arrival_pos(slot)
	if not pos then
		pending = nil
		note({
			arrival_applied = false,
			arrival_reject_reason = pos_why or "no_pos",
			arrival_door_slot = slot,
		})
		return false, pos_why
	end

	place_players_at(pos, slot)
	pending = nil
	note({
		source_room = p.source,
		destination_room = p.destination,
		source_door_slot = p.source_door_slot,
		arrival_door_slot = slot,
		arrival_position = {x = pos.X, y = pos.Y},
		arrival_applied = true,
		arrival_reject_reason = nil,
	})
	return true, "ok"
end

--- Wrap grid_doors check_and_leave: register then run original string/function leave.
function arrival.wrap_leave(route_key, targ, opts)
	opts = opts or {}
	return function(doorinfo, player)
		local begin_opts = {
			source_door_slot = doorinfo and doorinfo.slot or opts.source_door_slot,
			expect_variant = opts.expect_variant,
			expect_sgi = opts.expect_sgi,
			arrival_slot = opts.arrival_slot,
			source = opts.source,
			debug = opts.debug,
		}
		arrival.begin(route_key, begin_opts)
		local slot = pending and pending.arrival_slot
		if slot == nil and route_key == "ANTE_TO_TERMINAL" then
			local r = runtime.get()
			slot = r.terminal and r.terminal.gate_slot
		end
		if slot ~= nil and Game():GetLevel() then
			-- Align engine LeaveDoor with destination arrival when possible.
			Game():GetLevel().LeaveDoor = slot
		end
		if type(targ) == "string" then
			Isaac.ExecuteCommand("goto " .. targ)
		elseif type(targ) == "function" then
			targ(doorinfo, player)
		end
	end
end

return arrival
