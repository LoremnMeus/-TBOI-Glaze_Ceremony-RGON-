-- Chess Formation Director: room-scoped round cadence for Stone route pieces.
-- Issues controller.command / command_group only — never writes Position/Sprite/occupancy.
-- Floraine Boss must use its own director instance (do not share Stone members/round).

local defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")
local controller = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_controller")
local occupancy = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_occupancy")
local combat = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_combat")

local director = {}

director.PHASE = {
	ASSEMBLE = "ASSEMBLE",
	COMMAND = "COMMAND",
	EXECUTE = "EXECUTE",
	SETTLE = "SETTLE",
}

director.ID_STONE = "stone_route"
director.ID_FLORAINE = "floraine_boss"

local ASSEMBLE_FRAMES = 12
local COMMAND_FRAMES = 10
local SETTLE_MIN_FRAMES = 16
local FOLLOW_GAP = 6

local active = {
	id = nil,
	enabled = false,
	paused = false,
	phase = director.PHASE.ASSEMBLE,
	phase_frame = 0,
	round_id = 0,
	-- GetPtrHash -> latest wrapper
	members = {},
	assignments = {},
	wave_queue = {},
	wave_index = 0,
	wave_wait = 0,
	pending_reinforcements = {},
	last_tactic = nil,
	force_tactic = nil,
	diag = {},
	-- GetPtrHash -> {prepare_streak, last_moved_round, last_reason, last_landings}
	stagnation = {},
}

local function ptr(ent)
	return GetPtrHash(ent)
end

local function alive_member(ent)
	return ent and ent.Exists and ent:Exists() and not ent:IsDead()
end

local function refresh_members()
	local keep = {}
	for id, ent in pairs(active.members) do
		if alive_member(ent) then
			local data = controller.get_data(ent)
			if data and data.director_id == active.id then
				active.members[id] = ent -- refresh wrapper
				keep[id] = true
			end
		end
	end
	for id in pairs(active.members) do
		if not keep[id] then
			active.members[id] = nil
			active.assignments[id] = nil
		end
	end
end

local function member_list()
	local list = {}
	for _, ent in pairs(active.members) do
		if alive_member(ent) then
			list[#list + 1] = ent
		end
	end
	return list
end

local function pick_target()
	local players = {}
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if p and p:Exists() and not p:IsDead() and p.Variant == 0 then
			players[#players + 1] = p
		end
	end
	if #players < 1 then
		return nil
	end
	-- Stable within a round: lowest ControllerIndex.
	table.sort(players, function(a, b)
		return (a.ControllerIndex or 0) < (b.ControllerIndex or 0)
	end)
	return players[1]
end

local function attack_budget(n)
	if n <= 1 then return 1, 0 end
	if n == 2 then return 2, 0 end
	if n == 3 then return 2, 1 end
	if n == 4 then return 3, 1 end
	if n <= 6 then return 4, n - 4 end
	return 5, n - 5
end

local function direction_bucket(from, to)
	local d = to - from
	if math.abs(d.X) >= math.abs(d.Y) then
		return d.X >= 0 and "E" or "W"
	end
	return d.Y >= 0 and "S" or "N"
end

local function is_long_range(kind)
	return kind == defs.KIND.VEHICLE or kind == defs.KIND.BISHOP or kind == defs.KIND.QUEEN
end

--- Strong penalty for A→B then B→A; mild for revisiting a recent cell.
local function ping_pong_penalty(ent, dest)
	local data = controller.get_data(ent)
	if not data then
		return 0
	end
	local room = Game():GetRoom()
	local dest_g = room:GetGridIndex(dest)
	local from_g = room:GetGridIndex(ent.Position)
	if data._last_from_gidx and data._last_to_gidx
		and dest_g == data._last_from_gidx and from_g == data._last_to_gidx then
		return 0.9
	end
	if data._recent_cells and data._recent_cells[dest_g] then
		return 0.35
	end
	return 0
end

--- Preferred standoff distance in grid cells (long-range keep space; king/pawn close).
local function standoff_score(kind, dest, target_pos)
	local cells = (dest - target_pos):Length() / defs.GRID
	if kind == defs.KIND.KING or kind == defs.KIND.PAWN then
		return math.max(0, 1 - cells / 4)
	elseif kind == defs.KIND.KNIGHT then
		return math.max(0, 1 - math.abs(cells - 2.5) / 3)
	end
	-- Rook / Bishop / Queen: prefer ~3–6 cells of line, not hugging.
	return math.max(0, 1 - math.abs(cells - 4.5) / 5)
end

--- Next-round attack coverage from a hypothetical landing (real legal moves from dest).
local function attack_coverage_from(ent, dest, target_pos)
	local data = controller.get_data(ent)
	local kind = data and data.kind or defs.KIND.PAWN
	local probes = controller.legal_landings_at(dest, kind, GetPtrHash(ent))
	if #probes < 1 then
		return 0
	end
	local best = 0
	local g = defs.GRID
	for _, atk in ipairs(probes) do
		local d = (atk - target_pos):Length()
		if d <= g * 0.75 then
			best = 1
			break
		end
		best = math.max(best, math.max(0, 1 - d / (g * 5)))
	end
	return best
end

--- How close the charge path comes to the player (strike wants to skim / hit).
local function path_near_score(from, dest, target_pos)
	local cells = combat.line_cells(from, dest, defs.GRID)
	local best = 1e9
	for _, c in ipairs(cells) do
		local d = (c - target_pos):Length()
		if d < best then
			best = d
		end
	end
	return math.max(0, 1 - best / (defs.GRID * 1.25))
end

local function score_strike_dest(ent, dest, target)
	local data = controller.get_data(ent)
	local kind = data and data.kind or defs.KIND.PAWN
	local path_s = path_near_score(ent.Position, dest, target.Position)
	local cover = attack_coverage_from(ent, dest, target.Position)
	local stand = standoff_score(kind, dest, target.Position)
	local reach = 0
	if is_long_range(kind) then
		local cells = (dest - ent.Position):Length() / defs.GRID
		reach = math.min(1, cells / 5)
	end
	local pen = ping_pong_penalty(ent, dest)
	return 0.40 * path_s + 0.30 * cover + 0.15 * stand + 0.15 * reach - pen
end

local function landing_toward(ent, target)
	local target_pos = target.Position or target
	local landings = controller.legal_landings(ent)
	if #landings < 1 then
		return nil, -1, 0
	end
	local best, best_s = nil, -1
	for _, dest in ipairs(landings) do
		local s = score_strike_dest(ent, dest, {Position = target_pos})
		if s > best_s then
			best_s = s
			best = dest
		end
	end
	return best, best_s, #landings
end

local function score_maneuver(ent, dest, target, primary_dest, used)
	local room = Game():GetRoom()
	local gidx = room:GetGridIndex(dest)
	if used[gidx] then
		return -1
	end
	local data = controller.get_data(ent)
	local kind = data and data.kind or defs.KIND.PAWN
	-- A: threat coverage AFTER arriving at dest (not "closer to player").
	local A = attack_coverage_from(ent, dest, target.Position)
	local stand = standoff_score(kind, dest, target.Position)
	A = 0.65 * A + 0.35 * stand
	local F = 0.5
	if primary_dest then
		local b1 = direction_bucket(target.Position, dest)
		local b2 = direction_bucket(target.Position, primary_dest)
		F = (b1 ~= b2) and 1 or 0.25
	end
	local P = 1
	local cells = (ent.Position - dest):Length() / defs.GRID
	local D = is_long_range(kind) and math.min(1, cells / 5) or (1 - math.min(1, cells / 5))
	local C = 0.5
	if kind == defs.KIND.VEHICLE or kind == defs.KIND.BISHOP or kind == defs.KIND.QUEEN then
		C = 0.75
	elseif kind == defs.KIND.KING then
		C = 0.35
	end
	local pen = ping_pong_penalty(ent, dest)
	return 0.40 * A + 0.20 * F + 0.15 * P + 0.15 * D + 0.10 * C - pen
end

local function best_maneuver(ent, target, primary_dest, used)
	local landings = controller.legal_landings(ent)
	local best, best_s = nil, -1
	for _, dest in ipairs(landings) do
		local s = score_maneuver(ent, dest, target, primary_dest, used)
		if s > best_s then
			best_s = s
			best = dest
		end
	end
	return best, best_s, #landings
end

local function note_move_choice(ent, dest, score, landing_count, role)
	active.diag.move_choices = active.diag.move_choices or {}
	local data = controller.get_data(ent)
	local cells = dest and ((dest - ent.Position):Length() / defs.GRID) or 0
	active.diag.move_choices[#active.diag.move_choices + 1] = {
		kind = data and data.kind,
		role = role,
		landings = landing_count or 0,
		cells = math.floor(cells * 10 + 0.5) / 10,
		score = math.floor((score or 0) * 100 + 0.5) / 100,
		from = Game():GetRoom():GetGridIndex(ent.Position),
		to = dest and Game():GetRoom():GetGridIndex(dest) or -1,
	}
end

local function mark_recent(ent, dest)
	local data = controller.get_data(ent)
	if not data then return end
	local room = Game():GetRoom()
	local gidx = room:GetGridIndex(dest)
	local from_g = room:GetGridIndex(ent.Position)
	data._last_from_gidx = from_g
	data._last_to_gidx = gidx
	data._recent_cells = data._recent_cells or {}
	data._recent_cells[gidx] = active.round_id
	for k, rid in pairs(data._recent_cells) do
		if rid < active.round_id - 1 then
			data._recent_cells[k] = nil
		end
	end
end

local function evaluate_flank(members, target)
	local candidates = {}
	for _, ent in ipairs(members) do
		if controller.can_accept_order(ent) then
			local dest, s = landing_toward(ent, target)
			if dest then
				candidates[#candidates + 1] = {
					ent = ent,
					dest = dest,
					bucket = direction_bucket(target.Position, dest),
					kind = controller.get_data(ent).kind,
					score = s,
				}
			end
		end
	end
	if #candidates < 1 then
		return nil
	end
	table.sort(candidates, function(a, b)
		return (a.score or 0) > (b.score or 0)
	end)
	local primary = candidates[1]
	local secondary = nil
	for i = 2, #candidates do
		if candidates[i].bucket ~= primary.bucket then
			secondary = candidates[i]
			break
		end
	end
	local score = 0.55 + (#candidates >= 2 and 0.2 or 0) + (secondary and 0.25 or 0)
	return {
		name = "flank",
		score = score,
		primary = {primary},
		follow = secondary and {secondary} or {},
		maneuver = {},
	}
end

local function evaluate_pin_and_leap(members, target)
	local pawn, knight = nil, nil
	for _, ent in ipairs(members) do
		if controller.can_accept_order(ent) then
			local k = controller.get_data(ent).kind
			if k == defs.KIND.PAWN and not pawn then
				pawn = ent
			elseif k == defs.KIND.KNIGHT and not knight then
				knight = ent
			end
		end
	end
	if not pawn then
		return nil
	end
	local pdest = landing_toward(pawn, target)
	if not pdest then
		return nil
	end
	local follow = {}
	if knight then
		local kdest = landing_toward(knight, target)
		if kdest then
			follow[#follow + 1] = {ent = knight, dest = kdest, kind = defs.KIND.KNIGHT}
		end
	end
	return {
		name = "pin_and_leap",
		score = 0.7 + (#follow > 0 and 0.25 or 0),
		primary = {{ent = pawn, dest = pdest, kind = defs.KIND.PAWN}},
		follow = follow,
		maneuver = {},
	}
end

local function evaluate_heavy_command(members, target)
	local heavy = nil
	for _, ent in ipairs(members) do
		if controller.can_accept_order(ent) then
			local k = controller.get_data(ent).kind
			if k == defs.KIND.KING or k == defs.KIND.QUEEN then
				heavy = ent
				break
			end
		end
	end
	if not heavy then
		return nil
	end
	local hdest = landing_toward(heavy, target)
	if not hdest then
		return nil
	end
	local follow = {}
	for _, ent in ipairs(members) do
		if ent ~= heavy and controller.can_accept_order(ent) and #follow < 2 then
			local dest = landing_toward(ent, target)
			if dest then
				follow[#follow + 1] = {ent = ent, dest = dest, kind = controller.get_data(ent).kind}
			end
		end
	end
	return {
		name = "heavy_command",
		score = 0.85,
		primary = {{ent = heavy, dest = hdest, kind = controller.get_data(heavy).kind}},
		follow = follow,
		maneuver = {},
	}
end

local function evaluate_single(members, target)
	for _, ent in ipairs(members) do
		if controller.can_accept_order(ent) then
			local dest = landing_toward(ent, target)
			if dest then
				return {
					name = "single",
					score = 0.3,
					primary = {{ent = ent, dest = dest, kind = controller.get_data(ent).kind}},
					follow = {},
					maneuver = {},
				}
			end
		end
	end
	return nil
end

local function note_plan_strikes(plan)
	local function note_row(row, role)
		if not row or not row.ent or not row.dest then
			return
		end
		local landings = controller.legal_landings(row.ent)
		local cells = (row.dest - row.ent.Position):Length() / defs.GRID
		note_move_choice(row.ent, row.dest, row.score, #landings, role)
		-- Overwrite cells with computed value (note_move_choice already sets cells).
		local last = active.diag.move_choices and active.diag.move_choices[#active.diag.move_choices]
		if last then
			last.cells = math.floor(cells * 10 + 0.5) / 10
		end
	end
	for _, row in ipairs(plan.primary or {}) do
		note_row(row, "strike")
	end
	for _, row in ipairs(plan.follow or {}) do
		note_row(row, "follow")
	end
end

local function choose_tactic(members, target)
	if active.force_tactic == "flank" then
		return evaluate_flank(members, target) or evaluate_single(members, target)
	elseif active.force_tactic == "pin_and_leap" then
		return evaluate_pin_and_leap(members, target) or evaluate_single(members, target)
	elseif active.force_tactic == "heavy_command" then
		return evaluate_heavy_command(members, target) or evaluate_single(members, target)
	end
	local cands = {
		evaluate_flank(members, target),
		evaluate_pin_and_leap(members, target),
		evaluate_heavy_command(members, target),
		evaluate_single(members, target),
	}
	local best = nil
	for _, c in ipairs(cands) do
		if c then
			local penalty = (active.last_tactic == c.name) and 0.08 or 0
			local s = c.score - penalty
			if not best or s > best._s then
				c._s = s
				best = c
			end
		end
	end
	return best
end

local function note_stagnation(ent, reason, landings)
	local id = ptr(ent)
	local row = active.stagnation[id]
	if not row then
		row = {prepare_streak = 0, last_moved_round = active.round_id, last_reason = nil, last_landings = 0}
		active.stagnation[id] = row
	end
	row.last_reason = reason
	row.last_landings = landings or row.last_landings or 0
	if reason == "moved" or reason == "busy" then
		row.prepare_streak = 0
		if reason == "moved" then
			row.last_moved_round = active.round_id
		end
	elseif reason == "prepare" or reason == "no_legal_landings" or reason == "command_rejected" or reason == "no_target" then
		row.prepare_streak = (row.prepare_streak or 0) + 1
	end
end

local function fill_maneuvers(plan, members, target)
	local used = {}
	local assigned = {}
	local function take(row)
		if not row then return end
		assigned[ptr(row.ent)] = true
		local room = Game():GetRoom()
		used[room:GetGridIndex(row.dest)] = true
	end
	for _, row in ipairs(plan.primary or {}) do take(row) end
	for _, row in ipairs(plan.follow or {}) do take(row) end
	local primary_dest = plan.primary and plan.primary[1] and plan.primary[1].dest
	plan.maneuver = plan.maneuver or {}
	for _, ent in ipairs(members) do
		local id = ptr(ent)
		if not assigned[id] and controller.can_accept_order(ent) then
			local landings = controller.legal_landings(ent, controller.get_data(ent).kind)
			local n_land = landings and #landings or 0
			local dest, s, n = best_maneuver(ent, target, primary_dest, used)
			if dest and s > 0.15 then
				note_move_choice(ent, dest, s, n, "maneuver")
				plan.maneuver[#plan.maneuver + 1] = {
					ent = ent,
					dest = dest,
					kind = controller.get_data(ent).kind,
				}
				assigned[id] = true
				used[Game():GetRoom():GetGridIndex(dest)] = true
				note_stagnation(ent, "moved", n_land)
			else
				local data = controller.get_data(ent)
				if data then
					data.task = defs.TASK.PREPARE
					active.assignments[id] = {task = defs.TASK.PREPARE}
				end
				if n then
					note_move_choice(ent, dest, s or -1, n, "prepare")
				end
				local why = "prepare"
				if n_land < 1 then
					why = "no_legal_landings"
				elseif not target then
					why = "no_target"
				end
				note_stagnation(ent, why, n_land)
			end
		end
	end
end

local function trim_attack_budget(plan, n)
	local atk, _man = attack_budget(n)
	local strikes = {}
	for _, row in ipairs(plan.primary or {}) do
		strikes[#strikes + 1] = row
	end
	for _, row in ipairs(plan.follow or {}) do
		strikes[#strikes + 1] = row
	end
	while #strikes > atk do
		local dropped = table.remove(strikes)
		plan.maneuver = plan.maneuver or {}
		plan.maneuver[#plan.maneuver + 1] = dropped
	end
	plan.primary = {}
	plan.follow = {}
	for i, row in ipairs(strikes) do
		if i == 1 or (#plan.primary < math.max(1, math.floor(atk / 2))) then
			plan.primary[#plan.primary + 1] = row
		else
			plan.follow[#plan.follow + 1] = row
		end
	end
end

local function commit_assignment(ent, task, dest)
	local data = controller.get_data(ent)
	if data then
		data.task = task
		data.director_bound = true
	end
	active.assignments[ptr(ent)] = {task = task, dest = dest}
	if dest then
		mark_recent(ent, dest)
	end
end

local function note_reject(why)
	active.diag.command_rejection_reasons = active.diag.command_rejection_reasons or {}
	local key = tostring(why or "rejected")
	active.diag.command_rejection_reasons[key] = (active.diag.command_rejection_reasons[key] or 0) + 1
end

--- Plan then submit; only successful accepts update task / assignment / recent cells.
local function issue_rows(rows, task, attack)
	if not rows or #rows < 1 then
		return 0, 0
	end
	local entries = {}
	for _, row in ipairs(rows) do
		if alive_member(row.ent) and controller.can_accept_order(row.ent) then
			entries[#entries + 1] = {
				piece = row.ent,
				destination = row.dest,
				type = attack and "ATTACK" or "MOVE",
				attack_enabled = attack == true,
				task = task,
			}
		elseif alive_member(row.ent) and not controller.can_accept_order(row.ent) then
			note_reject("busy")
		end
	end
	if #entries < 1 then
		return 0, 0
	end
	local ok = controller.command_group(entries, {
		movement_policy = defs.MOVEMENT_POLICY.NORMAL,
	})
	if ok then
		for _, e in ipairs(entries) do
			commit_assignment(e.piece, task, e.destination)
		end
		return #entries, 0
	end
	-- Fallback: issue individually so one failure does not cancel all.
	local accepted, rejected = 0, 0
	for _, e in ipairs(entries) do
		local aok, why = controller.command(e.piece, {
			type = e.type,
			destination = e.destination,
			attack_enabled = e.attack_enabled,
			movement_policy = defs.MOVEMENT_POLICY.NORMAL,
			task = task,
		})
		if aok then
			commit_assignment(e.piece, task, e.destination)
			accepted = accepted + 1
		else
			rejected = rejected + 1
			note_reject(why)
		end
	end
	return accepted, rejected
end

local function begin_execute(plan)
	active.wave_queue = {
		{delay = 0, rows = plan.primary, task = defs.TASK.STRIKE, attack = true},
		{delay = FOLLOW_GAP, rows = plan.follow, task = defs.TASK.FOLLOW_UP, attack = true},
		{delay = FOLLOW_GAP, rows = plan.maneuver, task = defs.TASK.MANEUVER, attack = false},
	}
	active.wave_index = 0
	active.wave_wait = 0
	active.diag.round_id = active.round_id
	active.diag.phase = active.phase
	active.diag.tactic = plan.name
	active.diag.primary_count = #(plan.primary or {})
	active.diag.secondary_count = #(plan.follow or {})
	active.diag.maneuver_count = #(plan.maneuver or {})
	active.diag.commands_accepted = 0
	active.diag.commands_rejected = 0
	active.diag.command_rejection_reasons = {}
	active.diag.moving_maneuvers = 0
	-- Keep move_choices accumulated during plan_round / fill_maneuvers.
	active.diag.move_choices = active.diag.move_choices or {}
	active.last_tactic = plan.name
end

local function count_busy_tasks(task_a, task_b)
	local n = 0
	for id, ent in pairs(active.members) do
		local asg = active.assignments[id]
		local task = asg and asg.task
		if task and (task == task_a or (task_b and task == task_b)) then
			if alive_member(ent) and controller.is_busy(ent) then
				n = n + 1
			end
		end
	end
	return n
end

local function tick_execute()
	active.wave_wait = active.wave_wait + 1
	while active.wave_index < #active.wave_queue do
		local wave = active.wave_queue[active.wave_index + 1]
		if active.wave_wait < (wave.delay or 0) and active.wave_index > 0 then
			break
		end
		if active.wave_index == 0 or active.wave_wait >= (wave.delay or 0) then
			active.wave_index = active.wave_index + 1
			active.wave_wait = 0
			local acc, rej = issue_rows(wave.rows, wave.task, wave.attack)
			active.diag.commands_accepted = (active.diag.commands_accepted or 0) + acc
			active.diag.commands_rejected = (active.diag.commands_rejected or 0) + rej
		else
			break
		end
	end
	active.diag.moving_maneuvers = count_busy_tasks(defs.TASK.MANEUVER, nil)
	if active.wave_index >= #active.wave_queue then
		-- Strike/follow decide when the attack wave is done. Maneuver may continue into
		-- the next ASSEMBLE; planning already skips busy pieces via can_accept_order.
		local strike_busy = count_busy_tasks(defs.TASK.STRIKE, defs.TASK.FOLLOW_UP) > 0
		if not strike_busy or active.phase_frame > 55 then
			active.phase = director.PHASE.SETTLE
			active.phase_frame = 0
		end
	end
end

local function plan_round()
	refresh_members()
	local members = member_list()
	-- Only idle pieces receive new orders; mid-maneuver keep their current task.
	local ready_members = {}
	for _, ent in ipairs(members) do
		if controller.can_accept_order(ent) then
			ready_members[#ready_members + 1] = ent
		end
	end
	active.diag.member_count = #members
	active.diag.ready_count = #ready_members
	active.diag.moving_maneuvers = count_busy_tasks(defs.TASK.MANEUVER, nil)
	active.diag.move_choices = {}
	local target = pick_target()
	if not target or #ready_members < 1 then
		active.phase = director.PHASE.SETTLE
		active.phase_frame = 0
		return
	end
	local plan = choose_tactic(ready_members, target)
	if not plan then
		active.phase = director.PHASE.SETTLE
		active.phase_frame = 0
		return
	end
	trim_attack_budget(plan, #ready_members)
	note_plan_strikes(plan)
	fill_maneuvers(plan, ready_members, target)
	begin_execute(plan)
	active.phase = director.PHASE.EXECUTE
	active.phase_frame = 0
end

function director.bind(id)
	active.id = id or director.ID_STONE
	active.enabled = true
	active.paused = false
	active.phase = director.PHASE.ASSEMBLE
	active.phase_frame = 0
	active.round_id = 0
	active.members = {}
	active.assignments = {}
	active.stagnation = {}
	active.wave_queue = {}
	active.pending_reinforcements = {}
	active.last_tactic = nil
	active.force_tactic = nil
	active.diag = {}
end

function director.unbind()
	for _, ent in pairs(active.members) do
		local data = controller.get_data(ent)
		if data then
			data.director_bound = false
		end
	end
	active.enabled = false
	active.members = {}
	active.assignments = {}
	active.stagnation = {}
	active.wave_queue = {}
	-- Detach shared reinforce queue without wiping encounter-owned table.
	active.pending_reinforcements = {}
	active.reinforce_queue_shared = false
	active.id = nil
end

function director.register(ent)
	if not active.enabled or not alive_member(ent) then
		return false
	end
	local data = controller.get_data(ent)
	if not data then
		return false
	end
	data.director_id = active.id
	data.director_bound = true
	-- Under director: directed mode, no autonomous_decide.
	controller.set_control_mode(ent, defs.MODE.DIRECTED)
	active.members[ptr(ent)] = ent
	return true
end

function director.unregister(ent)
	if not ent then return end
	local id = ptr(ent)
	active.members[id] = nil
	active.assignments[id] = nil
	local data = controller.get_data(ent)
	if data then
		data.director_bound = false
	end
end

--- Attach encounter-owned queue table (survives director.unbind / room leave).
function director.attach_reinforce_queue(queue)
	if type(queue) ~= "table" then
		return false
	end
	active.pending_reinforcements = queue
	active.reinforce_queue_shared = true
	return true
end

function director.queue_reinforcement(spec)
	active.pending_reinforcements = active.pending_reinforcements or {}
	active.pending_reinforcements[#active.pending_reinforcements + 1] = spec
end

function director.peek_reinforcement()
	local q = active.pending_reinforcements
	if type(q) ~= "table" or #q < 1 then
		return nil
	end
	return q[1]
end

function director.confirm_reinforcement_spawned()
	local q = active.pending_reinforcements
	if type(q) ~= "table" or #q < 1 then
		return nil
	end
	return table.remove(q, 1)
end

--- Keep front item for a later settle (at max_alive).
function director.defer_reinforcement()
	return director.peek_reinforcement() ~= nil
end

--- Spawn failed: bump fail count; drop after retries without consuming budget.
function director.fail_reinforcement(max_fails)
	local q = active.pending_reinforcements
	if type(q) ~= "table" or #q < 1 then
		return "empty"
	end
	local spec = q[1]
	spec.fail = (spec.fail or 0) + 1
	max_fails = max_fails or 5
	if spec.fail >= max_fails then
		table.remove(q, 1)
		return "dropped"
	end
	return "retry"
end

function director.has_pending_reinforcements()
	return #(active.pending_reinforcements or {}) > 0
end

function director.queued_reinforcement_count()
	return #(active.pending_reinforcements or {})
end

function director.in_settle_or_assemble()
	return active.phase == director.PHASE.SETTLE or active.phase == director.PHASE.ASSEMBLE
end

function director.set_paused(v)
	active.paused = v == true
end

function director.force_tactic(name)
	active.force_tactic = name
end

function director.request_round()
	if not active.enabled then return end
	active.phase = director.PHASE.COMMAND
	active.phase_frame = COMMAND_FRAMES
	active.round_id = active.round_id + 1
	plan_round()
end

function director.tick()
	if not active.enabled or active.paused then
		return
	end
	refresh_members()
	active.phase_frame = active.phase_frame + 1
	active.diag.phase = active.phase
	active.diag.round_id = active.round_id
	local occ = occupancy.get_state and occupancy.get_state() or nil
	if occ then
		local oc, rc = 0, 0
		for _ in pairs(occ.current or {}) do oc = oc + 1 end
		for _ in pairs(occ.target or {}) do rc = rc + 1 end
		active.diag.occupied_cells = oc
		active.diag.reserved_cells = rc
	end

	if active.phase == director.PHASE.ASSEMBLE then
		if active.phase_frame >= ASSEMBLE_FRAMES then
			active.phase = director.PHASE.COMMAND
			active.phase_frame = 0
			active.round_id = active.round_id + 1
		end
	elseif active.phase == director.PHASE.COMMAND then
		if active.phase_frame >= COMMAND_FRAMES then
			plan_round()
		end
	elseif active.phase == director.PHASE.EXECUTE then
		tick_execute()
	elseif active.phase == director.PHASE.SETTLE then
		if active.phase_frame >= SETTLE_MIN_FRAMES then
			active.phase = director.PHASE.ASSEMBLE
			active.phase_frame = 0
		end
	end
end

function director.get_diag()
	return {
		enabled = active.enabled,
		paused = active.paused,
		id = active.id,
		phase = active.phase,
		phase_frame = active.phase_frame,
		round_id = active.round_id,
		member_count = active.diag.member_count or 0,
		ready_count = active.diag.ready_count or 0,
		tactic = active.diag.tactic,
		primary_count = active.diag.primary_count or 0,
		secondary_count = active.diag.secondary_count or 0,
		maneuver_count = active.diag.maneuver_count or 0,
		commands_accepted = active.diag.commands_accepted or 0,
		commands_rejected = active.diag.commands_rejected or 0,
		command_rejection_reasons = active.diag.command_rejection_reasons or {},
		moving_maneuvers = active.diag.moving_maneuvers or count_busy_tasks(defs.TASK.MANEUVER, nil),
		occupied_cells = active.diag.occupied_cells or 0,
		reserved_cells = active.diag.reserved_cells or 0,
		queued_reinforcements = #(active.pending_reinforcements or {}),
		pending_reinforcements = #(active.pending_reinforcements or {}),
		last_tactic = active.last_tactic,
		move_choices = active.diag.move_choices or {},
	}
end

--- Per-piece idle / PREPARE diagnosis for Stone debug (does not change orders).
function director.get_stagnation_diag()
	refresh_members()
	local rows = {}
	local max_prepare = 0
	for id, ent in pairs(active.members) do
		if alive_member(ent) then
			local data = controller.get_data(ent)
			local st = active.stagnation[id] or {}
			local bound = data and data.director_bound == true
			local mode = data and data.control_mode
			local landings = 0
			if data and data.kind then
				local list = controller.legal_landings(ent, data.kind)
				landings = list and #list or 0
			end
			local reason = st.last_reason
			if not active.enabled then
				reason = "director_disabled"
			elseif not bound and mode == defs.MODE.DIRECTED then
				reason = "not_registered"
			elseif controller.is_busy and controller.is_busy(ent) then
				reason = "busy"
				note_stagnation(ent, "busy", landings)
			elseif not reason then
				if landings < 1 then
					reason = "no_legal_landings"
				elseif (data and data.task) == defs.TASK.PREPARE then
					reason = "prepare"
				else
					reason = "ok"
				end
			end
			local streak = st.prepare_streak or 0
			if streak > max_prepare then max_prepare = streak end
			rows[#rows + 1] = {
				ptr = id,
				kind = data and data.kind,
				mode = mode,
				director_bound = bound,
				action_state = data and data.action_state,
				task = data and data.task,
				legal_landings = landings,
				prepare_streak = streak,
				last_moved_round = st.last_moved_round,
				reason = reason,
			}
		end
	end
	return {
		enabled = active.enabled,
		id = active.id,
		round_id = active.round_id,
		phase = active.phase,
		max_prepare_streak = max_prepare,
		pieces = rows,
	}
end

function director.is_enabled()
	return active.enabled == true
end

return director
