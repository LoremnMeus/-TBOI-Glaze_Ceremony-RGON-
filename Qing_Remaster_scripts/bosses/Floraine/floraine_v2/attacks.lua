-- Boss-owned Shift / Royal Move.
-- Royal: WINDUP → DASH (hit once/player) → FOLLOW_WAIT → RECOVERY.
-- Shift: reposition only (no damage), prefer flanking relative to guards.

local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local enums = require("Qing_Remaster_scripts.core.enums")
local piece_defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")
local piece_controller = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_controller")
local occupancy = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_occupancy")
local visual = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.visual")
local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")

local attacks = {}

local ROYAL = {
	WINDUP = 10,
	DASH = 8,
	FOLLOW_WAIT = 6,
	RECOVERY = 14,
}

local SHIFT = {
	WINDUP = 6,
	DASH = 9,
	RECOVERY = 10,
}

local royal_serial = 0
local royal_hits = {} -- key → true for current dash

local function snap(pos)
	return select(1, occupancy.snap_world(pos, Game():GetRoom()))
end

local function gather_guard_positions()
	local list = {}
	for _, ent in ipairs(Isaac.FindByType(996, enums.Enemies.chess_piece, -1, false, false)) do
		local d = piece_controller.get_data(ent)
		if d and d.director_id == defs.DIRECTOR_ID and ent:Exists() and not ent:IsDead() then
			list[#list + 1] = ent.Position
		end
	end
	return list
end

--- Prefer ~4 cells from player, flank angle vs guards, avoid last Shift cell.
function attacks.pick_shift_dest(ent, target, last_pos)
	local room = Game():GetRoom()
	local g = piece_defs.GRID
	local candidates = {}
	local origin = ent.Position
	for dx = -4, 4 do
		for dy = -3, 3 do
			if not (dx == 0 and dy == 0) then
				local raw = origin + Vector(dx * g, dy * g)
				local pos, gidx = occupancy.snap_world(raw, room)
				if gidx >= 0 then
					local ok = select(1, occupancy.terrain_ok(pos, {avoid_doors = true, min_player_distance = 48}))
					local free = select(1, occupancy.can_enter(nil, pos, {ignore_occupancy = false}))
					if ok and free then
						candidates[#candidates + 1] = pos
					end
				end
			end
		end
	end
	if #candidates < 1 then
		return nil
	end
	local tpos = target and target.Position or room:GetCenterPos()
	local guards = gather_guard_positions()
	local best, best_s = candidates[1], -1e9
	for _, pos in ipairs(candidates) do
		local cells = (pos - tpos):Length() / g
		local s = 1 - math.abs(cells - 4) / 5
		-- Flank: prefer positions where player sits between boss candidate and a guard.
		local flank = 0
		for i = 1, #guards do
			local gpos = guards[i]
			local v1 = (tpos - pos)
			local v2 = (gpos - tpos)
			if v1:Length() > 1 and v2:Length() > 1 then
				local dot = v1:Normalized():Dot(v2:Normalized())
				-- Higher when roughly continuing past the player toward a guard (pinch).
				if dot > 0.15 then
					flank = flank + dot * 0.35
				end
			end
		end
		s = s + flank
		if last_pos and (pos - last_pos):Length() < g * 0.75 then
			s = s - 1.5
		end
		-- Prefer not returning to origin.
		if (pos - origin):Length() < g * 0.75 then
			s = s - 0.8
		end
		if s > best_s then
			best_s = s
			best = pos
		end
	end
	return best
end

function attacks.begin_shift(data, ent, dest)
	if not dest then return false end
	data.attack = {
		kind = "shift",
		phase = "WINDUP",
		elapsed = 0,
		start = Vector(ent.Position.X, ent.Position.Y),
		dest = snap(dest),
		windup = SHIFT.WINDUP,
		dash = SHIFT.DASH,
		recovery = SHIFT.RECOVERY,
	}
	data.last_shift_pos = Vector(ent.Position.X, ent.Position.Y)
	visual.flash(ent, 0.5, 0.5, 0.8, SHIFT.WINDUP)
	return true
end

function attacks.begin_royal(data, ent, target)
	target = target or auxi.get_acceptible_target(ent)
	if not target then return false end
	local room = Game():GetRoom()
	local dir = (target.Position - ent.Position)
	if dir:Length() < 1 then
		dir = Vector(0, 40)
	end
	dir = dir:Normalized() * (piece_defs.GRID * 3)
	local raw = ent.Position + dir
	local dest = snap(raw)
	-- Keep dash inside room playable area.
	dest = room:GetClampedPosition(dest, 20)
	dest = snap(dest)
	royal_serial = royal_serial + 1
	royal_hits = {}
	data.attack = {
		kind = "royal",
		phase = "WINDUP",
		elapsed = 0,
		start = Vector(ent.Position.X, ent.Position.Y),
		dest = dest,
		windup = ROYAL.WINDUP,
		dash = ROYAL.DASH,
		follow_wait = ROYAL.FOLLOW_WAIT,
		recovery = ROYAL.RECOVERY,
		follow_sent = false,
		attack_id = royal_serial,
		damage_active = false,
		contact_damage = 1,
		hit_radius = 26,
		target_hash = GetPtrHash(target),
	}
	visual.command(ent)
	visual.flash(ent, 0.45, 0.15, 0.1, ROYAL.WINDUP)
	return true
end

local function lerp_dash(ent, atk)
	local t = math.min(1, atk.elapsed / math.max(1, atk.dash))
	ent.Position = atk.start + (atk.dest - atk.start) * t
	ent.Velocity = Vector.Zero
end

local function royal_try_hit(ent, atk, prev, cur)
	if not atk or not atk.damage_active then return end
	local radius = atk.hit_radius or 26
	local attack_id = atk.attack_id or 0
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player and player:Exists() and not player:IsDead() then
			local pindex = player:GetData().__Index
			if pindex == nil then
				pindex = "ci" .. tostring(player.ControllerIndex or i)
			end
			local key = tostring(attack_id) .. ":" .. tostring(pindex)
			if not royal_hits[key] then
				-- Sweep along dash segment.
				local abx = cur.X - prev.X
				local aby = cur.Y - prev.Y
				local len2 = abx * abx + aby * aby
				local dist
				if len2 < 1 then
					dist = player.Position:Distance(cur)
				else
					local t = ((player.Position.X - prev.X) * abx + (player.Position.Y - prev.Y) * aby) / len2
					if t < 0 then t = 0 elseif t > 1 then t = 1 end
					local cx = prev.X + abx * t
					local cy = prev.Y + aby * t
					dist = player.Position:Distance(Vector(cx, cy))
				end
				if dist <= radius then
					royal_hits[key] = true
					player:TakeDamage(atk.contact_damage or 1, 0, EntityRef(ent), 20)
				end
			end
		end
	end
end

--- @return boolean finished
function attacks.tick(ent, data, director_mod)
	local atk = data.attack
	if not atk then return false end
	atk.elapsed = (atk.elapsed or 0) + 1
	ent.Velocity = Vector.Zero

	if atk.phase == "WINDUP" then
		atk.damage_active = false
		if atk.elapsed >= (atk.windup or 1) then
			atk.phase = "DASH"
			atk.elapsed = 0
			atk.start = Vector(ent.Position.X, ent.Position.Y)
			atk.damage_active = (atk.kind == "royal")
		end
		return false
	end

	if atk.phase == "DASH" then
		local prev = Vector(ent.Position.X, ent.Position.Y)
		lerp_dash(ent, atk)
		if atk.kind == "royal" then
			royal_try_hit(ent, atk, prev, ent.Position)
		end
		if atk.elapsed >= (atk.dash or 1) then
			ent.Position = atk.dest
			data.home = Vector(atk.dest.X, atk.dest.Y)
			atk.damage_active = false
			if atk.kind == "royal" then
				atk.phase = "FOLLOW_WAIT"
				atk.elapsed = 0
			else
				atk.phase = "RECOVERY"
				atk.elapsed = 0
			end
		end
		return false
	end

	if atk.phase == "FOLLOW_WAIT" then
		atk.damage_active = false
		ent.Position = atk.dest
		if atk.elapsed >= (atk.follow_wait or 1) then
			if not atk.follow_sent then
				atk.follow_sent = true
				if director_mod and director_mod.order_follow_strike then
					-- No-op if no idle guard; Royal still completes.
					director_mod.order_follow_strike(ent)
				end
			end
			atk.phase = "RECOVERY"
			atk.elapsed = 0
		end
		return false
	end

	if atk.phase == "RECOVERY" then
		atk.damage_active = false
		ent.Position = atk.dest or ent.Position
		if atk.elapsed >= (atk.recovery or 1) then
			data.attack = nil
			visual.rest(ent)
			return true
		end
		return false
	end

	data.attack = nil
	return true
end

function attacks.is_busy(data)
	return data and data.attack ~= nil
end

function attacks.clear_royal_hits()
	royal_hits = {}
end

return attacks
