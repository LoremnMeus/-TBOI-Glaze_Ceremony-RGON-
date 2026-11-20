-- Reserve → battlefield deployment: infuse / lift / transfer / hover / drop / NPC handoff.
-- Opening batch waits for Floraine Release; death inheritance auto-drops.

local enums = require("Qing_Remaster_scripts.core.enums")
local piece_defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")
local piece_controller = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_controller")
local occupancy = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_occupancy")
local reserve_defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_defs")
local reserve_controller = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_controller")
local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")
local arena = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.arena")

local deployment = {}

local queue = {}
local serial = 0
local last_fail = "none"
local opening_pending = {} -- legacy stagger queue (kept for debug deploy_opening)
local opening_delay = 0
local opening_expected = 0
local opening_landed = 0
local opening_start_fails = 0
local opening_active = false

local TILT_BY_KIND = {
	[piece_defs.KIND.PAWN] = 6,
	[piece_defs.KIND.KNIGHT] = -8,
	[piece_defs.KIND.VEHICLE] = 5,
	[piece_defs.KIND.BISHOP] = -7,
	[piece_defs.KIND.QUEEN] = 8,
	[piece_defs.KIND.KING] = 5,
}

local function occ_token(piece_id)
	return "floraine_reserve_" .. tostring(piece_id)
end

local function release_occ(job)
	if not job or not job.occ_id then return end
	occupancy.release_target(job.occ_id)
	occupancy.release_current(job.occ_id)
	job.occ_id = nil
end

local function find_job(id)
	for _, job in ipairs(queue) do
		if job.id == id then return job end
	end
	return nil
end

local function pick_target(_kind)
	local boss_pos = arena.boss_spawn_pos()
	local g = piece_defs.GRID
	local offsets = {
		Vector(-2 * g, g), Vector(2 * g, g), Vector(0, 2 * g),
		Vector(-3 * g, 2 * g), Vector(3 * g, 2 * g),
		Vector(-g, 3 * g), Vector(g, 3 * g), Vector(0, g),
	}
	for _, off in ipairs(offsets) do
		local pos = select(1, piece_controller.find_spawn_position({
			preferred_position = boss_pos + off,
			min_player_distance = 70,
		}))
		if pos then
			return pos
		end
	end
	return select(1, piece_controller.find_spawn_position({
		preferred_position = boss_pos + Vector(0, 3 * g),
		min_player_distance = 50,
	}))
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function ease_out(t)
	t = math.max(0, math.min(1, t))
	return 1 - (1 - t) * (1 - t)
end

local function tilt_for(row)
	local base = TILT_BY_KIND[row and row.kind] or (reserve_defs.DEPLOY.TILT_DEG or 8)
	return base
end

--- Pre-claim a destination grid for a piece (before red light). Does not start motion.
function deployment.claim_target_for_piece(piece_id, preferred)
	if find_job(piece_id) then
		last_fail = "already_deploying"
		return nil, nil, last_fail
	end
	local row = reserve_controller.get_row(piece_id)
	if not row then
		last_fail = "no_row"
		return nil, nil, last_fail
	end
	local target = preferred or pick_target(row.kind)
	if not target then
		last_fail = "no_target"
		return nil, nil, last_fail
	end
	local occ_id = occ_token(piece_id)
	local ok, a, b = occupancy.commit_move(occ_id, target, {})
	if not ok then
		last_fail = a or "occ_fail"
		return nil, nil, last_fail
	end
	local gidx, snap = a, b
	target = snap or target
	row.deploy_target = Vector(target.X, target.Y)
	row.deploy_target_gidx = gidx
	-- Stash occ on row until start() claims the job.
	row._deploy_occ_id = occ_id
	last_fail = "ok"
	return target, gidx, "ok"
end

--- Start deploying one reserve piece. Supports command-soul infusion path.
function deployment.start(piece_id, opts)
	opts = opts or {}
	if find_job(piece_id) then
		last_fail = "already_deploying"
		return false, last_fail
	end
	local row = reserve_controller.get_row(piece_id)
	if not row then
		last_fail = "not_available"
		return false, last_fail
	end
	local S = reserve_defs.STATE
	local allowed = {
		[S.RESERVE] = true,
		[S.SELECTED] = true,
		[S.TARGETED] = true,
		[S.INFUSING] = true,
	}
	if not allowed[row.state] then
		last_fail = "not_available"
		return false, last_fail
	end

	local occ_id = row._deploy_occ_id
	local target = opts.target or row.deploy_target
	local gidx = row.deploy_target_gidx
	if not occ_id or not target then
		target = opts.target or pick_target(row.kind)
		if not target then
			last_fail = "no_target"
			return false, last_fail
		end
		occ_id = occ_token(piece_id)
		local ok, a, b = occupancy.commit_move(occ_id, target, {})
		if not ok then
			last_fail = a or "occ_fail"
			return false, last_fail
		end
		gidx, target = a, (b or target)
		row.deploy_target = Vector(target.X, target.Y)
		row.deploy_target_gidx = gidx
	end
	row._deploy_occ_id = nil

	if row.state == S.RESERVE then
		reserve_controller.begin_select(piece_id)
		row = reserve_controller.get_row(piece_id)
	end

	local phase = S.SELECTED
	if opts.from_infuse then
		phase = S.LIFTING
		row.state = S.LIFTING
	end

	serial = serial + 1
	queue[#queue + 1] = {
		id = piece_id,
		phase = phase,
		elapsed = 0,
		start = Vector(row.home_pos.X, row.home_pos.Y),
		target = Vector(target.X, target.Y),
		target_gidx = gidx,
		occ_id = occ_id,
		serial = serial,
		is_opening = opts.is_opening == true,
		batch_id = opts.batch_id,
		wait_for_drop = opts.wait_for_drop == true,
		auto_drop = opts.auto_drop == true,
		drop_signal = false,
		command_id = opts.command_id,
		generation = opts.generation,
		session_id = opts.session_id,
		tilt_peak = tilt_for(row),
	}
	last_fail = "ok"
	return true, "started"
end

function deployment.signal_drop(piece_id)
	local job = find_job(piece_id)
	if job then
		job.drop_signal = true
		return true
	end
	return false
end

function deployment.signal_batch_drop(batch_id)
	local n = 0
	for _, job in ipairs(queue) do
		if job.batch_id == batch_id and job.phase == reserve_defs.STATE.HOVERING then
			job.drop_signal = true
			n = n + 1
		end
	end
	return n
end

function deployment.batch_hover_count(batch_id)
	local n = 0
	local total = 0
	for _, job in ipairs(queue) do
		if job.batch_id == batch_id then
			total = total + 1
			if job.phase == reserve_defs.STATE.HOVERING then
				n = n + 1
			end
		end
	end
	return n, total
end

function deployment.batch_all_hovering(batch_id)
	local n, total = deployment.batch_hover_count(batch_id)
	return total > 0 and n >= total
end

local function handoff_npc(job, row)
	local pos = job.target
	local ent, data = piece_controller.spawn({
		kind = row.kind,
		position = pos,
		role = piece_defs.ROLE.COMBAT,
		mode = piece_defs.MODE.DIRECTED,
		director_id = defs.DIRECTOR_ID,
		damageable = true,
		skip_occupancy = true,
		no_appear = true,
	})
	if not ent then
		last_fail = "spawn_failed"
		reserve_controller.revert_to_reserve(row.id)
		release_occ(job)
		return nil, "spawn_failed"
	end
	-- Appear can reassert during init; clear again and force Idle.
	ent:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
	local spr = ent:GetSprite()
	if spr then
		spr:Play("Idle", true)
	end
	local claim_ok, a, b = occupancy.claim_reserved(job.occ_id, GetPtrHash(ent), {})
	if not claim_ok then
		last_fail = "claim_" .. tostring(a)
		ent:Remove()
		reserve_controller.revert_to_reserve(row.id)
		release_occ(job)
		return nil, last_fail
	end
	job.occ_id = nil
	local gidx, snap = a, b
	if snap then
		ent.Position = snap
	end
	if data then
		data.current_grid = gidx
		data.occupancy_deferred = nil
		data.action_state = "IDLE"
		data._deploy_settle = reserve_defs.DEPLOY.SETTLE
		data._deploy_color_progress = row.visual_color_progress or 1
		data._deploy_outline_fade = 0.55
		if job.command_id then
			data.floraine_command = {
				session_id = job.session_id,
				command_id = job.command_id,
				reserve_piece_id = row.id,
				generation = job.generation or 1,
			}
		end
	end
	local director = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.director")
	if director.register then
		director.register(ent)
	end
	reserve_controller.mark_active(row.id, GetPtrHash(ent))
	local souls_ok, souls = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.command_souls")
	if souls_ok and souls and souls.on_handoff then
		souls.on_handoff(row.id, ent, data)
	end
	if job.is_opening then
		opening_landed = opening_landed + 1
	end
	last_fail = "landed"
	return ent, data
end

local function advance_job(job)
	local row = reserve_controller.get_row(job.id)
	if not row then
		release_occ(job)
		return false
	end
	local D = reserve_defs.DEPLOY
	local S = reserve_defs.STATE
	job.elapsed = job.elapsed + 1
	row.phase_elapsed = job.elapsed

	local function set_phase(st)
		job.phase = st
		job.elapsed = 0
		row.state = st
		row.phase_elapsed = 0
	end

	if job.phase == S.SELECTED then
		row.state = S.SELECTED
		row.outline_pulse = nil
		row.visual_height = 0
		row.visual_color_progress = 0
		row.visual_tilt = 0
		row.pos = Vector(job.start.X, job.start.Y)
		if job.elapsed >= D.SELECTED then
			set_phase(S.PULSING)
		end
		return true
	end

	if job.phase == S.PULSING then
		row.state = S.PULSING
		row.outline_pulse = nil
		row.visual_height = 0
		row.visual_color_progress = 0
		row.visual_tilt = 0
		if job.elapsed >= D.PULSE then
			set_phase(S.LIFTING)
		end
		return true
	end

	if job.phase == S.LIFTING then
		row.state = S.LIFTING
		-- Home hard-block releases as soon as lift begins.
		if reserve_controller.release_home_blocker then
			reserve_controller.release_home_blocker(job.id)
		end
		local t = ease_out(job.elapsed / math.max(1, D.LIFT))
		row.visual_height = D.LIFT_HEIGHT * t
		row.visual_color_progress = 0.30 * t
		row.visual_tilt = (job.tilt_peak or 8) * t
		row.outline_pulse = nil
		row.pos = Vector(job.start.X, job.start.Y)
		if job.elapsed >= D.LIFT then
			set_phase("POST_LIFT")
		end
		return true
	end

	-- Brief pause at height before horizontal transfer (opening readable beat).
	if job.phase == "POST_LIFT" then
		row.state = S.LIFTING
		row.visual_height = D.LIFT_HEIGHT
		row.visual_color_progress = 0.30
		row.visual_tilt = job.tilt_peak or 8
		row.pos = Vector(job.start.X, job.start.Y)
		local hold = D.POST_LIFT or defs.P1_POST_LIFT_HOLD or 10
		if job.elapsed >= hold then
			set_phase(S.TRANSFERRING)
		end
		return true
	end

	if job.phase == S.TRANSFERRING then
		row.state = S.TRANSFERRING
		local t = ease_out(job.elapsed / math.max(1, D.TRANSFER))
		-- Stable cruise height (no mid-arc bob).
		row.visual_height = D.LIFT_HEIGHT
		row.visual_color_progress = 0.30 + 0.65 * t
		row.visual_tilt = (job.tilt_peak or 8) * (1 - t)
		row.outline_pulse = nil
		row.pos = lerp(job.start, job.target, t)
		if job.elapsed >= D.TRANSFER then
			row.pos = Vector(job.target.X, job.target.Y)
			row.visual_tilt = 0
			set_phase(S.HOVERING)
		end
		return true
	end

	if job.phase == S.HOVERING then
		row.state = S.HOVERING
		row.visual_height = D.LIFT_HEIGHT
		row.visual_color_progress = 0.95
		row.visual_tilt = 0
		row.outline_pulse = nil
		row.pos = Vector(job.target.X, job.target.Y)
		local hold = defs.P1_HOVER_HOLD or D.HOVER or 8
		local ready = false
		if job.wait_for_drop then
			ready = job.drop_signal == true
		elseif job.auto_drop then
			ready = job.elapsed >= hold
		else
			-- Default: short hover then drop (legacy single deploy).
			ready = job.elapsed >= hold
		end
		if ready then
			set_phase(S.DROPPING)
		end
		return true
	end

	if job.phase == S.DROPPING or job.phase == S.LANDING then
		row.state = S.LANDING
		job.phase = S.LANDING
		local t = job.elapsed / math.max(1, D.LAND)
		row.visual_height = D.LIFT_HEIGHT * (1 - ease_out(t))
		row.visual_color_progress = 0.95 + 0.05 * ease_out(t)
		row.visual_tilt = 0
		row.outline_pulse = nil
		row.pos = Vector(job.target.X, job.target.Y)
		if job.elapsed >= D.LAND then
			local landed = handoff_npc(job, row)
			if not landed and job.is_opening then
				opening_start_fails = opening_start_fails + 1
			end
			return false
		end
		return true
	end

	return false
end

function deployment.tick()
	if #opening_pending > 0 then
		if opening_delay > 0 then
			opening_delay = opening_delay - 1
		else
			local next_id = table.remove(opening_pending, 1)
			local ok, why = deployment.start(next_id, { is_opening = true, auto_drop = true })
			if not ok then
				opening_start_fails = opening_start_fails + 1
				last_fail = why or "opening_start_fail"
				reserve_controller.revert_to_reserve(next_id)
			end
			opening_delay = reserve_defs.DEPLOY.STAGGER
		end
	end

	local keep = {}
	for _, job in ipairs(queue) do
		if advance_job(job) then
			keep[#keep + 1] = job
		end
	end
	queue = keep
end

function deployment.cancel_all(reason)
	for _, job in ipairs(queue) do
		release_occ(job)
		local row = reserve_controller.get_row(job.id)
		if row and row._deploy_occ_id then
			occupancy.release_target(row._deploy_occ_id)
			occupancy.release_current(row._deploy_occ_id)
			row._deploy_occ_id = nil
		end
		reserve_controller.revert_to_reserve(job.id)
	end
	queue = {}
	opening_pending = {}
	opening_delay = 0
	opening_active = false
	last_fail = reason or "cancelled"
end

function deployment.is_busy()
	return #queue > 0 or #opening_pending > 0
end

function deployment.queue_count()
	return #queue + #opening_pending
end

local function count_opening_inflight()
	local n = #opening_pending
	for _, job in ipairs(queue) do
		if job.is_opening then
			n = n + 1
		end
	end
	return n
end

local function claim_opening_row(row)
	if not row then
		return false
	end
	local ok = reserve_controller.begin_select(row.id)
	if not ok then
		return false
	end
	opening_pending[#opening_pending + 1] = row.id
	return true
end

--- Legacy/debug: queue opening deploys with auto-drop (no command souls).
function deployment.deploy_opening(count)
	count = tonumber(count) or defs.P1_OPENING_COUNT or 1
	count = math.max(1, math.floor(count))
	local candidates = {}
	if count >= 3 and reserve_controller.pick_opening_three then
		candidates = reserve_controller.pick_opening_three()
	end
	opening_pending = {}
	for _, row in ipairs(candidates) do
		if #opening_pending >= count then
			break
		end
		claim_opening_row(row)
	end
	while #opening_pending < count do
		local row = reserve_controller.pick_for_kind(nil)
		if not row or not claim_opening_row(row) then
			break
		end
	end
	if #opening_pending < 1 then
		last_fail = "no_pieces"
		opening_expected = 0
		opening_landed = 0
		opening_start_fails = 0
		opening_active = false
		return 0, last_fail
	end
	opening_expected = #opening_pending
	opening_landed = 0
	opening_start_fails = 0
	opening_active = true
	opening_delay = 0
	last_fail = "opening_queued"
	return #opening_pending, last_fail
end

function deployment.deploy_opening_three()
	return deployment.deploy_opening(3)
end

function deployment.retry_opening_deficit()
	local need = (opening_expected or 0) - (opening_landed or 0) - count_opening_inflight()
	if need < 1 then
		last_fail = "no_deficit"
		return 0, last_fail
	end
	local added = 0
	for _ = 1, need do
		local row = reserve_controller.pick_for_kind(nil)
		if not row then
			break
		end
		if claim_opening_row(row) then
			added = added + 1
		else
			break
		end
	end
	opening_active = true
	last_fail = added > 0 and "opening_retry_queued" or "opening_retry_empty"
	return added, last_fail
end

function deployment.has_opening_guard_landed()
	local souls_ok, souls = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.command_souls")
	if souls_ok and souls and souls.has_opening_guard_landed and souls.has_opening_guard_landed() then
		return true
	end
	return (opening_landed or 0) > 0
end

function deployment.is_opening_wave_busy()
	if #opening_pending > 0 then
		return true
	end
	for _, job in ipairs(queue) do
		if job.is_opening or job.batch_id then
			return true
		end
	end
	return false
end

function deployment.opening_status()
	local busy = deployment.is_opening_wave_busy()
	local expected = opening_expected
	local landed = opening_landed
	local souls_ok, souls = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.command_souls")
	if souls_ok and souls and souls.opening_status then
		local os = souls.opening_status()
		if os and os.active then
			return os
		end
	end
	return {
		active = opening_active,
		expected = expected,
		landed = landed,
		start_fails = opening_start_fails,
		busy = busy,
		wave_busy = busy,
		inflight = count_opening_inflight(),
		has_landed = landed > 0,
		complete = (not busy) and expected > 0 and landed >= expected,
		failed = (not busy) and expected > 0 and landed < expected,
	}
end

function deployment.clear_opening_flag()
	opening_active = false
	local souls_ok, souls = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.command_souls")
	if souls_ok and souls and souls.clear_opening_flag then
		souls.clear_opening_flag()
	end
end

function deployment.deploy_one(kind)
	local row = reserve_controller.pick_for_kind(kind)
	if not row then
		last_fail = "reserve_empty"
		return false, last_fail
	end
	return deployment.start(row.id, { auto_drop = true })
end

function deployment.diag()
	local cur = queue[1]
	local opening = deployment.opening_status()
	return {
		queue = #queue,
		opening_pending = #opening_pending,
		busy = deployment.is_busy(),
		last_fail = last_fail,
		selected_piece_id = cur and cur.id,
		deployment_state = cur and cur.phase,
		deployment_target = cur and cur.target and { x = cur.target.X, y = cur.target.Y },
		deployment_failure_reason = last_fail,
		opening = opening,
	}
end

local _ = enums.Enemies

return deployment
