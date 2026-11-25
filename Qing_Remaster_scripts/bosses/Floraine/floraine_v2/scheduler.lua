-- Floraine combat scheduler: alternates formation / temp assault / boss action.
-- Does not move pieces itself; only times director pause and temp/boss requests.

local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")
local director = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.director")
local attacks = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.attacks")
local visual = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.visual")
local temp_piece = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.temp_piece")
local patterns = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.temp_piece_patterns")
local royal_drop = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.royal_drop")
local p2_columns = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_columns")
local p2_promotion = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_promotion")
local p2_chess_drop = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_chess_drop")

local scheduler = {}

local S = {
	mode = defs.SCHED.FORMATION,
	elapsed = 0,
	phase = 1,
	next_temp_frame = 60,
	next_boss_frame = 90,
	next_royal_frame = 90,
	next_chess_drop_frame = 150,
	force_pattern = nil,
	last_temp = nil,
	last_fail = nil,
	p3_cycle = 0,
	command_dir = nil,
}

local function chess_drop_interval()
	local c = defs.P2_CHESS_DROP or {}
	local min_v = c.INTERVAL_MIN or 240
	local span = c.INTERVAL_SPAN or 60
	local r = RNG()
	r:SetSeed(Game():GetRoom():GetSpawnSeed() + (S.elapsed or 0) * 17 + 3, 35)
	return min_v + r:RandomInt(math.max(1, span))
end

local function royal_interval()
	local min_v = defs.P1_ROYAL_INTERVAL_MIN or 150
	local span = defs.P1_ROYAL_INTERVAL_SPAN or 60
	local r = Game():GetPlayer(0):GetCollectibleRNG(CollectibleType.COLLECTIBLE_DADS_KEY)
	return min_v + r:RandomInt(math.max(1, span))
end

function scheduler.reset(phase)
	S.mode = defs.SCHED.FORMATION
	S.elapsed = 0
	S.phase = tonumber(phase) or 1
	-- P2 uses column/promotion systems; old temp assault starts at P3 only.
	S.next_temp_frame = (S.phase >= 3) and 45 or 999999
	S.next_boss_frame = defs.P3_ATTACK_COOLDOWN
	S.next_royal_frame = defs.P1_ROYAL_FIRST_DELAY or 90
	local cd = defs.P2_CHESS_DROP or {}
	local first_min = cd.FIRST_DELAY_MIN or cd.FIRST_DELAY or 75
	local first_span = cd.FIRST_DELAY_SPAN or 31
	S.next_chess_drop_frame = first_min + Game():GetPlayer(0):GetCollectibleRNG(CollectibleType.COLLECTIBLE_DADS_KEY):RandomInt(math.max(1, first_span))
	S.force_pattern = nil
	S.last_temp = nil
	S.last_fail = nil
	S.p3_cycle = 0
	royal_drop.clear("sched_reset")
	p2_chess_drop.clear("sched_reset")
	if S.phase == 2 then
		S.mode = defs.SCHED.P2_COLUMNS
	end
	director.resume_orders()
end

function scheduler.get_state()
	return S
end

function scheduler.force_pattern(name)
	S.force_pattern = name
end

local function begin_recover()
	S.mode = defs.SCHED.RECOVER
	S.elapsed = 0
	director.resume_orders()
end

local function begin_temp(phase, ent)
	director.stop_orders()
	if ent then
		visual.command(ent)
		visual.flash(ent, 0.2, 0.35, 0.55, 14)
	end
	local n, name, why = patterns.execute(phase, S.force_pattern)
	S.force_pattern = nil
	S.last_temp = name
	if n < 1 then
		S.last_fail = why or "temp_failed"
		director.resume_orders()
		S.mode = defs.SCHED.FORMATION
		S.elapsed = 0
		return false
	end
	S.mode = defs.SCHED.TEMP_ASSAULT
	S.elapsed = 0
	return true
end

local function begin_boss_action(ent, data)
	S.mode = defs.SCHED.BOSS_ACTION
	S.elapsed = 0
	director.stop_orders() -- hold new formation combo during Royal/Shift
	S.p3_cycle = (S.p3_cycle or 0) + 1
	local target = auxi.get_acceptible_target(ent)
	local started = false
	if S.p3_cycle % 2 == 0 then
		local dest = attacks.pick_shift_dest(ent, target, data and data.last_shift_pos)
		started = attacks.begin_shift(data, ent, dest) == true
	else
		started = attacks.begin_royal(data, ent, target) == true
	end
	if not started then
		director.resume_orders()
		S.mode = defs.SCHED.FORMATION
		S.next_boss_frame = S.elapsed + 30 -- relative; fixed below via absolute
		return false
	end
	return true
end

local function begin_command(ent)
	S.mode = defs.SCHED.COMMAND
	S.elapsed = 0
	visual.command(ent)
	visual.flash(ent, 0.25, 0.2, 0.05, defs.COMMAND_WINDUP)
end

--- Per combat logic frame. Returns whether boss attack tick should run.
function scheduler.tick(ent, data, session_frame, phase)
	S.phase = tonumber(phase) or S.phase
	S.elapsed = (S.elapsed or 0) + 1

	if S.mode == defs.SCHED.TEMP_ASSAULT then
		if not temp_piece.any_active() then
			begin_recover()
			local cd = (S.phase >= 3) and defs.P3_TEMP_COOLDOWN or defs.P2_ASSAULT_COOLDOWN
			S.next_temp_frame = session_frame + cd
		end
		-- Formation director stays paused; do not schedule boss personal attack.
		return false
	end

	if S.mode == defs.SCHED.RECOVER then
		if S.elapsed >= defs.TEMP_RECOVER_FRAMES then
			S.mode = defs.SCHED.FORMATION
			S.elapsed = 0
			director.resume_orders()
		end
		return false
	end

	if S.mode == defs.SCHED.COMMAND then
		-- Keep formation clock alive during command telegraph.
		director.ensure_guards(S.phase, { allow_reinforce = true })
		director.tick(ent)
		visual.tick_chain(ent)
		local wind = (defs.COMMAND_WINDUP or 12) + (defs.COMMAND_RECOVER or 24)
		if S.elapsed >= wind then
			S.mode = defs.SCHED.FORMATION
			S.elapsed = 0
			-- Chain settles to Idle2; do not force Idle.
		end
		return false
	end

	if S.mode == defs.SCHED.BOSS_ACTION then
		if attacks.is_busy(data) then
			attacks.tick(ent, data, director)
			return false
		end
		-- Action finished.
		director.resume_orders()
		S.mode = defs.SCHED.FORMATION
		S.elapsed = 0
		S.next_boss_frame = session_frame + defs.P3_ATTACK_COOLDOWN
		-- Occasionally follow Shift with a single rook pierce in P3.
		if S.phase >= 3 and S.p3_cycle % 2 == 0 and not temp_piece.any_active() then
			if session_frame >= (S.next_temp_frame or 0) then
				begin_temp(3, ent)
			end
		end
		return false
	end

	-- P2: dual columns + promotion chase + periodic「棋落」.
	if S.phase == 2 then
		S.mode = defs.SCHED.P2_COLUMNS
		if not p2_columns.is_active() then
			p2_columns.begin()
			p2_promotion.reset()
		end
		p2_columns.tick()
		p2_promotion.tick(ent)

		-- Chess-drop runs in parallel with columns (warn may wait for march clear).
		if p2_chess_drop.is_busy() then
			S.mode = defs.SCHED.P2_CHESS_DROP
			local finished = p2_chess_drop.tick(ent)
			if finished then
				S.mode = defs.SCHED.P2_COLUMNS
				S.next_chess_drop_frame = session_frame + chess_drop_interval()
			end
		elseif session_frame >= (S.next_chess_drop_frame or 0)
			and not royal_drop.is_busy() then
			local ok = p2_chess_drop.try_begin(ent)
			if ok then
				S.mode = defs.SCHED.P2_CHESS_DROP
				p2_chess_drop.tick(ent)
			else
				S.next_chess_drop_frame = session_frame + 45
				S.last_fail = p2_chess_drop.diag().last_fail
			end
		end

		if ent then
			visual.tick_chain(ent)
		end
		return false
	end

	-- FORMATION mode (also hosts in-flight「重落子」while other guards keep forming).
	director.resume_orders()
	director.ensure_guards(S.phase, { allow_reinforce = true })
	director.tick(ent)

	-- Prune lingering royal-drop projectiles (may outlive the job).
	royal_drop.tick_projectiles()

	-- P1 signature「重落子」owns staff while busy — skip 点将 telegraphs.
	if S.phase == 1 and (S.mode == defs.SCHED.ROYAL_DROP or royal_drop.is_busy()) then
		S.mode = defs.SCHED.ROYAL_DROP
		royal_drop.tick(ent)
		visual.tick_chain(ent)
		if not royal_drop.is_busy() then
			S.mode = defs.SCHED.FORMATION
			S.next_royal_frame = session_frame + royal_interval()
		end
		return false
	end

	-- Deploy queued a 点将: Raise(/FromIdle2)→Cast→Settle chain + COMMAND telegraph.
	if director.consume_command_visual and director.consume_command_visual() then
		begin_command(ent)
		return false
	end

	-- Advance cosmetic chain while formation runs (orders / leftover Settle).
	if ent then
		visual.tick_chain(ent)
	end

	if S.phase == 1 and session_frame >= (S.next_royal_frame or 0) then
		local anim = ent and ent:GetSprite() and ent:GetSprite():GetAnimation()
		local busy_anim = anim == "Raise" or anim == "RaiseFromIdle2" or anim == "Cast"
			or anim == "Release" or anim == "Settle"
		if not busy_anim then
			local ok = royal_drop.try_begin(ent)
			if ok then
				S.mode = defs.SCHED.ROYAL_DROP
				royal_drop.tick(ent)
				visual.tick_chain(ent)
				return false
			else
				-- No Idle piece / no legal step: retry soon, do not spam staff.
				S.next_royal_frame = session_frame + 30
				S.last_fail = royal_drop.diag().last_fail
			end
		end
	end

	-- P3: temp assault patterns (former P2 rook/bishop/queen kits) + personal attacks.
	if S.phase >= 3 and not attacks.is_busy(data) then
		if session_frame >= (S.next_temp_frame or 0) and not temp_piece.any_active() then
			if not director.any_guards_busy() or S.force_pattern then
				begin_temp(S.phase, ent)
				return false
			end
		end
	end

	-- P3: personal Shift / Royal on cooldown.
	if S.phase >= 3 and not attacks.is_busy(data) then
		if session_frame >= (S.next_boss_frame or 0) then
			if begin_boss_action(ent, data) then
				return false
			else
				S.next_boss_frame = session_frame + 30
			end
		end
	end

	return false
end

--- Stop issuing new combat work for an in-fight phase transition.
--- Does NOT clear P2 columns / promotion / chess-drop entities (evac handoff needs them).
function scheduler.suspend_for_transition()
	S.mode = defs.SCHED.FORMATION
	S.force_pattern = nil
	-- Push chess-drop far away so a stale timer cannot fire if tick races.
	S.next_chess_drop_frame = (S.elapsed or 0) + 999999
	director.stop_orders()
end

--- Boss defeat / leave arena: hard-clear combat entities and resume formation bookkeeping.
function scheduler.on_defeat_or_leave()
	temp_piece.clear_all("defeat_or_leave")
	royal_drop.clear("defeat_or_leave")
	p2_chess_drop.clear("defeat_or_leave")
	p2_promotion.clear("defeat_or_leave")
	p2_columns.clear("defeat_or_leave")
	S.mode = defs.SCHED.FORMATION
	S.force_pattern = nil
	director.resume_orders()
end

function scheduler.get_diag()
	local t = temp_piece.get_diag()
	return {
		mode = S.mode,
		phase = S.phase,
		elapsed = S.elapsed,
		next_temp_frame = S.next_temp_frame,
		next_boss_frame = S.next_boss_frame,
		next_royal_frame = S.next_royal_frame,
		next_chess_drop_frame = S.next_chess_drop_frame,
		last_temp = S.last_temp,
		last_fail = S.last_fail,
		temp = t,
		royal_drop = royal_drop.diag(),
		p2_columns = p2_columns.diag(),
		p2_promotion = p2_promotion.diag(),
		p2_chess_drop = p2_chess_drop.diag(),
	}
end

return scheduler
