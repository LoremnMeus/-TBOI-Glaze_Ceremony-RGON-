-- Boss-owned formation director. Limited reinforce; never infinite refill.
-- Reuses chess_piece_controller; own member set via chess_piece_director.bind.

local enums = require("Qing_Remaster_scripts.core.enums")
local piece_defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")
local piece_controller = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_controller")
local chess_director = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_director")
local arena = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.arena")
local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")
local phase_mod = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.phase")
local deployment = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.deployment")
local reserve_controller = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_controller")
local command_souls = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.command_souls")

local director = {}

chess_director.ID_FLORAINE = defs.DIRECTOR_ID

local reinforce = {
	frame = 0,
	used = { [1] = 0, [2] = 0, [3] = 0 },
	last_spawn_frame = -9999,
	next_p1_interval = nil,
	initial_done = { [1] = false, [2] = false, [3] = false },
	p2_reformed = false,
	p3_culled = false,
	paused_orders = false,
	vuln_until = 0,
	pending_command_visual = false,
	diag = { last_reason = "none", last_spawn = 0 },
}

local function rng()
	return Game():GetPlayer(0):GetCollectibleRNG(CollectibleType.COLLECTIBLE_DADS_KEY)
end

local function reset_reinforce()
	reinforce.frame = 0
	reinforce.used = { [1] = 0, [2] = 0, [3] = 0 }
	reinforce.last_spawn_frame = -9999
	reinforce.next_p1_interval = nil
	reinforce.initial_done = { [1] = false, [2] = false, [3] = false }
	reinforce.p2_reformed = false
	reinforce.p3_culled = false
	reinforce.vuln_until = 0
	reinforce.pending_command_visual = false
	reinforce.diag = { last_reason = "reset", last_spawn = 0 }
end

local function p1_interval()
	local min_v = defs.P1_REINFORCE_INTERVAL_MIN or 90
	local span = defs.P1_REINFORCE_INTERVAL_SPAN or 30
	local r = rng()
	return min_v + r:RandomInt(math.max(1, span))
end

--- Soften guard DR while Floraine is casting a 点将 / command.
function director.begin_command_vuln(frames)
	frames = tonumber(frames) or defs.COMMAND_VULN_FRAMES or 36
	reinforce.vuln_until = math.max(reinforce.vuln_until or 0, reinforce.frame + frames)
end

function director.clear_command_vuln()
	reinforce.vuln_until = 0
end

function director.is_command_vulnerable()
	return reinforce.frame < (reinforce.vuln_until or 0)
end

--- P1 damage taken multiplier from live combat pieces (+ command vuln floor).
function director.guard_damage_factor()
	local n = director.count_guards()
	if n > 3 then
		n = 3
	end
	local table_ = defs.GUARD_DAMAGE_FACTOR or {}
	local factor = table_[n]
	if factor == nil then
		factor = 1
	end
	if director.is_command_vulnerable() then
		local floor_v = defs.COMMAND_VULN_FLOOR or 0.70
		if factor < floor_v then
			factor = floor_v
		end
	end
	return factor
end

function director.bind()
	chess_director.bind(defs.DIRECTOR_ID)
	reset_reinforce()
end

function director.unbind()
	if chess_director.is_enabled and chess_director.is_enabled() then
		chess_director.unbind()
	end
	reset_reinforce()
end

function director.register(ent)
	return chess_director.register(ent)
end

local piece_scan = {
	frame = -1,
	list = nil,
	calls = 0,
}

local function find_floraine()
	for _, ent in ipairs(Isaac.FindByType(996, enums.Enemies.Floraine, -1, false, false)) do
		if ent:Exists() and not ent:IsDead() then
			return ent
		end
	end
	return nil
end

--- Per Game-frame combat-piece scan (shared by count / busy / kill helpers).
local function cached_guard_list()
	local f = Game():GetFrameCount()
	if piece_scan.frame == f and piece_scan.list then
		return piece_scan.list
	end
	piece_scan.frame = f
	piece_scan.calls = (piece_scan.calls or 0) + 1
	local list = {}
	for _, ent in ipairs(Isaac.FindByType(996, enums.Enemies.chess_piece, -1, false, false)) do
		local d = piece_controller.get_data(ent)
		if d and d.director_id == defs.DIRECTOR_ID and ent:Exists() and not ent:IsDead() then
			list[#list + 1] = ent
		end
	end
	piece_scan.list = list
	return list
end

function director.invalidate_piece_cache()
	piece_scan.frame = -1
	piece_scan.list = nil
end

function director.tick(boss_ent)
	reinforce.frame = (reinforce.frame or 0) + 1
	director.invalidate_piece_cache()
	command_souls.tick(boss_ent or find_floraine())
	deployment.tick()
	if reinforce.paused_orders then
		return
	end
	if chess_director.is_enabled and chess_director.is_enabled() then
		chess_director.tick()
	end
end

function director.count_guards()
	return #cached_guard_list()
end

--- Active NPCs + in-flight reserve deployments (consume roster slots).
function director.count_guard_pressure()
	return director.count_guards() + deployment.queue_count()
end

function director.mark_initial_done(combat_phase)
	combat_phase = tonumber(combat_phase) or 1
	reinforce.initial_done[combat_phase] = true
	reinforce.last_spawn_frame = reinforce.frame
	if combat_phase == 1 then
		reinforce.next_p1_interval = p1_interval()
	end
	reinforce.diag.last_reason = "opening_deploy"
end

function director.any_guards_busy()
	for _, ent in ipairs(cached_guard_list()) do
		if piece_controller.is_busy(ent) then
			return true
		end
	end
	return false
end

function director.kill_guards()
	command_souls.set_suppress_death(true)
	director.invalidate_piece_cache()
	for _, ent in ipairs(cached_guard_list()) do
		ent:Kill()
	end
	director.invalidate_piece_cache()
	command_souls.set_suppress_death(false)
end

function director.stop_orders()
	reinforce.paused_orders = true
	chess_director.set_paused(true)
end

function director.resume_orders()
	reinforce.paused_orders = false
	chess_director.set_paused(false)
end

function director.is_orders_paused()
	return reinforce.paused_orders == true
end

local function spawn_kind(kind, pos)
	local ent, data = piece_controller.spawn({
		kind = kind,
		position = pos,
		role = piece_defs.ROLE.COMBAT,
		mode = piece_defs.MODE.DIRECTED,
		director_id = defs.DIRECTOR_ID,
		damageable = true,
	})
	if ent then
		director.register(ent)
		reinforce.diag.last_spawn = reinforce.frame
	end
	return ent, data
end

local function pool_for(combat_phase)
	if combat_phase == 2 then
		return defs.P2_KINDS
	elseif combat_phase == 3 then
		return defs.P3_KINDS
	end
	return defs.P1_KINDS
end

local function spawn_offsets()
	local g = piece_defs.GRID
	return {
		Vector(-2 * g, g), Vector(2 * g, g), Vector(0, 2 * g),
		Vector(-3 * g, 2 * g), Vector(3 * g, 2 * g), Vector(-g, 3 * g), Vector(g, 3 * g),
	}
end

local function spawn_n(combat_phase, need, reason)
	if need < 1 then return 0 end
	local pool = pool_for(combat_phase)
	local r = rng()
	local boss_pos = arena.boss_spawn_pos()
	local offsets = spawn_offsets()
	local have = director.count_guards()
	local spawned = 0
	for i = 1, need do
		local kind = pool[(r:RandomInt(#pool)) + 1]
		local off = offsets[((have + i - 1) % #offsets) + 1]
		local pos = select(1, piece_controller.find_spawn_position({
			preferred_position = boss_pos + off,
			min_player_distance = 70,
		})) or (boss_pos + off)
		if spawn_kind(kind, pos) then
			spawned = spawned + 1
		end
	end
	reinforce.diag.last_reason = reason or "spawn"
	reinforce.last_spawn_frame = reinforce.frame
	return spawned
end

--- P1 roster: pull from reserve formation (never mid-air spawn_n).
local function deploy_n(need, reason)
	if need < 1 then return 0 end
	if not reserve_controller.is_active() then
		reinforce.diag.last_reason = "no_reserve"
		return 0
	end
	if reserve_controller.count_remaining() < 1 then
		reinforce.diag.last_reason = "reserve_empty"
		return 0
	end
	local spawned = 0
	local pool = pool_for(1)
	local r = rng()
	for _ = 1, need do
		local kind = pool[(r:RandomInt(#pool)) + 1]
		local ok, why = deployment.deploy_one(kind)
		if ok then
			spawned = spawned + 1
		else
			reinforce.diag.last_reason = why or "deploy_fail"
			break
		end
	end
	if spawned > 0 then
		reinforce.diag.last_reason = reason or "deploy"
		reinforce.last_spawn_frame = reinforce.frame
		director.begin_command_vuln(defs.COMMAND_VULN_FRAMES)
		reinforce.pending_command_visual = true
	elseif reinforce.diag.last_reason == "deploy" or reinforce.diag.last_reason == reason then
		reinforce.diag.last_reason = "deploy_fail"
	end
	return spawned
end

--- Controller/scheduler: play Raise→Cast chain once when a deploy was queued.
function director.consume_command_visual()
	if reinforce.pending_command_visual then
		reinforce.pending_command_visual = false
		return true
	end
	return false
end

local function cull_to(cap)
	director.invalidate_piece_cache()
	local guards = {}
	local boss_pos = arena.boss_spawn_pos()
	for _, ent in ipairs(cached_guard_list()) do
		guards[#guards + 1] = ent
	end
	table.sort(guards, function(a, b)
		return (a.Position - boss_pos):LengthSquared() < (b.Position - boss_pos):LengthSquared()
	end)
	for i = cap + 1, #guards do
		guards[i]:Kill()
	end
	director.invalidate_piece_cache()
end

--- Phase roster + limited mid-combat reinforce. Never infinite refill.
-- @param combat_phase number
-- @param opts {reform=bool, allow_reinforce=bool, force_initial=bool}
function director.ensure_guards(combat_phase, opts)
	opts = opts or {}
	combat_phase = tonumber(combat_phase) or 1
	local cap = phase_mod.guard_cap(combat_phase)
	local have = director.count_guard_pressure()

	-- P2 enter: one-time reform up to 4 (does not spend mid-combat budget).
	-- Still uses spawn_n (temp assaults remain separate); not reserve queue.
	if combat_phase == 2 and not reinforce.p2_reformed and (opts.reform == true or not reinforce.initial_done[2]) then
		reinforce.p2_reformed = true
		reinforce.initial_done[2] = true
		local need = math.max(0, cap - director.count_guards())
		spawn_n(2, need, "p2_reform")
		return
	end

	-- P3 enter: keep at most 2 existing; never spawn new.
	if combat_phase == 3 then
		if not reinforce.p3_culled or opts.reform == true then
			reinforce.p3_culled = true
			reinforce.initial_done[3] = true
			cull_to(cap)
			reinforce.diag.last_reason = "p3_cull"
		end
		return
	end

	-- P1 initial: owned by OPENING_SELECTION (deployment.deploy_opening).
	-- Do not spawn_n mid-arena. force_initial only re-queues opening if empty.
	if combat_phase == 1 and (not reinforce.initial_done[1] or opts.force_initial == true) then
		if director.count_guards() < 1 and not deployment.is_busy() then
			if reserve_controller.is_active() then
				deployment.deploy_opening(defs.P1_OPENING_COUNT or 1)
				reinforce.diag.last_reason = "force_opening"
			else
				reinforce.diag.last_reason = "await_opening"
			end
		else
			reinforce.initial_done[1] = true
			reinforce.diag.last_reason = "opening_present"
		end
		return
	end

	if opts.allow_reinforce == false then
		return
	end

	-- Hold mid-combat reinforce until the opening点将 wave finishes (avoid slot fights).
	if combat_phase == 1 and deployment.is_opening_wave_busy and deployment.is_opening_wave_busy() then
		reinforce.diag.last_reason = "opening_wave"
		return
	end

	-- Mid-combat reinforce only when below cap, budget remains, interval elapsed.
	if have >= cap then
		reinforce.diag.last_reason = "at_cap"
		return
	end

	if combat_phase == 1 then
		-- P1 refill is owned solely by command_souls death inheritance.
		reinforce.diag.last_reason = "p1_souls_only"
		return
	end

	local budget = defs.REINFORCE_BUDGET[combat_phase]
	if budget == nil then
		budget = 0
	end
	local used = reinforce.used[combat_phase] or 0
	if used >= budget then
		reinforce.diag.last_reason = "budget_exhausted"
		return
	end
	if (reinforce.frame - reinforce.last_spawn_frame) < defs.REINFORCE_INTERVAL then
		reinforce.diag.last_reason = "interval"
		return
	end
	-- P2+: wait for quiet board before mid-air reinforce.
	if director.any_guards_busy() or deployment.is_busy() then
		reinforce.diag.last_reason = "wait_busy"
		return
	end
	local gained = spawn_n(combat_phase, 1, "reinforce")
	if gained > 0 then
		reinforce.used[combat_phase] = used + 1
	end
end

function director.on_phase_enter(combat_phase)
	combat_phase = tonumber(combat_phase) or 1
	-- P2 is owned by p2_columns / p2_promotion — never reform old 4-guard roster.
	if combat_phase == 2 then
		reinforce.initial_done[2] = true
		reinforce.p2_reformed = true
		reinforce.diag.last_reason = "p2_columns"
		return
	end
	director.ensure_guards(combat_phase, { reform = true })
end

function director.order_follow_strike(_boss_ent)
	local target = nil
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if p and p:Exists() and not p:IsDead() then
			target = p
			break
		end
	end
	if not target then return false end
	local best, best_d = nil, 1e12
	for _, ent in ipairs(cached_guard_list()) do
		if piece_controller.can_accept_order(ent) then
			local dist = (ent.Position - target.Position):LengthSquared()
			if dist < best_d then
				best_d = dist
				best = ent
			end
		end
	end
	if best then
		piece_controller.command(best, {
			type = "ATTACK",
			destination = target.Position,
			movement_policy = piece_defs.MOVEMENT_POLICY.NORMAL,
			task = piece_defs.TASK.FOLLOW_UP,
		})
		return true
	end
	return false
end

--- Real P1 directed order: flash chosen guard + short staff motion + attack command.
function director.begin_directed_order(boss_ent)
	local target = nil
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if p and p:Exists() and not p:IsDead() then
			target = p
			break
		end
	end
	if not target then
		return false, "no_player"
	end
	local best, best_d = nil, 1e12
	for _, ent in ipairs(cached_guard_list()) do
		local d = piece_controller.get_data(ent)
		if d and d.floraine_command and piece_controller.can_accept_order(ent) then
			local dist = (ent.Position - target.Position):LengthSquared()
			if dist < best_d then
				best_d = dist
				best = ent
			end
		end
	end
	if not best then
		return false, "no_guard"
	end
	best:SetColor(Color(1, 0.22, 0.26, 1, 0.45, 0.05, 0.05), 18, 2, true, false)
	local visual = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.visual")
	if boss_ent then
		visual.order(boss_ent)
		visual.flash(boss_ent, 0.25, 0.12, 0.05, 10)
	end
	piece_controller.command(best, {
		type = "ATTACK",
		destination = target.Position,
		movement_policy = piece_defs.MOVEMENT_POLICY.NORMAL,
		task = piece_defs.TASK.FOLLOW_UP,
	})
	reinforce.diag.last_reason = "directed_order"
	return true, GetPtrHash(best)
end

function director.force_tactic(name)
	chess_director.force_tactic(name)
end

function director.get_diag()
	local base = chess_director.get_diag and chess_director.get_diag() or {}
	base.reinforce = {
		frame = reinforce.frame,
		used = {
			p1 = reinforce.used[1] or 0,
			p2 = reinforce.used[2] or 0,
			p3 = reinforce.used[3] or 0,
		},
		budget = defs.REINFORCE_BUDGET,
		last_reason = reinforce.diag.last_reason,
		last_spawn = reinforce.diag.last_spawn,
		guards = director.count_guards(),
		guard_pressure = director.count_guard_pressure(),
		paused = reinforce.paused_orders == true,
		command_vuln = director.is_command_vulnerable(),
		damage_factor = director.guard_damage_factor(),
		next_p1_interval = reinforce.next_p1_interval,
	}
	base.reserve = reserve_controller.diag()
	base.reserve_perf = reserve_controller.get_perf and reserve_controller.get_perf() or nil
	base.piece_scan_calls = piece_scan.calls
	base.deployment = deployment.diag()
	base.command_souls = command_souls.diag()
	return base
end

function director.get_reinforce_state()
	return reinforce
end

return director
