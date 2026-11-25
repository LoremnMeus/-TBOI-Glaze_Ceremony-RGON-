-- Floraine V2 debug helpers (no permanent unlock by default).

local runtime = require("Qing_Remaster_scripts.threads.stone.stone_runtime")
local controller = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.controller")
local director = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.director")
local rewards = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.rewards")
local scheduler = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.scheduler")
local temp_piece = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.temp_piece")
local patterns = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.temp_piece_patterns")
local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")
local ante_formation = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.ante_formation")
local reserve_controller = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_controller")
local deployment = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.deployment")
local arena = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.arena")
local reserve_defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_defs")
local visual = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.visual")
local royal_drop = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.royal_drop")

local test = {}

local BOSS_ANIMS = {
	"Idle", "Idle2", "Raise", "Cast", "Settle", "Lower", "RaiseFromIdle2", "Release", "Leave",
}

--- Force-play a formal boss clip (debug). Chain clips still need tick_chain each frame.
function test.play_boss_anim(name, force)
	local ent = controller.find_boss and controller.find_boss() or nil
	if not ent then
		return false, "no_boss"
	end
	local anim = tostring(name or "")
	local ok = false
	for i = 1, #BOSS_ANIMS do
		if BOSS_ANIMS[i] == anim then
			ok = true
			break
		end
	end
	if not ok then
		return false, "bad_anim"
	end
	visual.play(ent, anim, force ~= false)
	return true, anim
end

function test.boss_command()
	local ent = controller.find_boss and controller.find_boss() or nil
	if not ent then return false end
	visual.command(ent)
	return true
end

function test.boss_lower()
	local ent = controller.find_boss and controller.find_boss() or nil
	if not ent then return false end
	visual.lower(ent)
	return true
end

function test.boss_chain_anims()
	return BOSS_ANIMS
end

--- Ensure Stone layout + board activation so stone_board (and royal-drop overlay) can draw.
--- Uses existing stone_debug facilities; does not invent a Floraine-only board.
function test.ensure_stone_board()
	local stone_debug = require("Qing_Remaster_scripts.threads.stone.stone_debug")
	if not (runtime.has_layout() and runtime.floor_matches()) then
		local ok_l, err_l = stone_debug.ensure_layout({ force = true, ignore_gate = true })
		if not ok_l then
			return false, err_l or "layout_failed"
		end
	end
	if not runtime.is_board_active() then
		local ok_a, why_a = runtime.activate_board("floraine_boss_test")
		if ok_a == false and why_a ~= "already" then
			return false, why_a or "activate_failed"
		end
	end
	return true
end

--- Goto Floraine via stone_debug (layout + board on). Bare goto skips the board gate.
function test.enter_arena()
	local stone_debug = require("Qing_Remaster_scripts.threads.stone.stone_debug")
	return stone_debug.goto_floraine({ suppress_boss = false })
end

function test.start_combat()
	test.ensure_stone_board()
	controller.debug_start_combat()
	return true
end

function test.set_phase(p)
	-- Legacy forward-only hint; prefer transition_to_phase / load_phase.
	controller.debug_set_phase(p)
	return true
end

function test.transition_to_phase(p)
	return controller.debug_transition_to_phase(p)
end

function test.load_phase(p)
	return controller.debug_load_phase(p)
end

function test.set_hp(ratio)
	return controller.debug_set_hp_ratio(ratio)
end

function test.force_command_return()
	local souls = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.command_souls")
	local ent = controller.find_boss and controller.find_boss()
	return souls.debug_force_return_one(ent)
end

function test.exhaust_reserves()
	local souls = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.command_souls")
	return souls.debug_exhaust_reserves()
end

function test.force_three_returns()
	local souls = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.command_souls")
	local ent = controller.find_boss and controller.find_boss()
	souls.debug_exhaust_reserves()
	local n = 0
	for _ = 1, 3 do
		local ok = souls.debug_force_return_one(ent)
		if ok then n = n + 1 end
	end
	return n >= 1, n
end

function test.simulate_hp_to_p2()
	local ent = controller.find_boss and controller.find_boss()
	if not ent then return false, "no_boss" end
	local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")
	ent.HitPoints = ent.MaxHitPoints * defs.PHASE_HP[1].lo
	return controller.begin_transition_public(2, "debug_hp")
end

function test.play_clear_pieces()
	local pt = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.phase_transition")
	local s = controller.get_session()
	local ent = controller.find_boss and controller.find_boss()
	return pt.debug_play_clear_only(s, ent)
end

function test.play_staff_detach()
	local pt = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.phase_transition")
	local ent = controller.find_boss and controller.find_boss()
	if not ent then return false, "no_boss" end
	return pt.debug_play_staff_only(ent)
end

function test.p2_begin_columns(opts)
	local cols = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_columns")
	return cols.begin(opts)
end

--- Replay side entrance (clears + rebuilds with fly-in).
function test.p2_play_entrance()
	local cols = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_columns")
	local promo = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_promotion")
	promo.clear("entrance_replay")
	return cols.begin({ entrance = true })
end

--- Instant layout without entrance (debug march only).
function test.p2_begin_skip_entrance()
	local cols = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_columns")
	return cols.begin({ entrance = false })
end

function test.p2_step()
	local cols = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_columns")
	return cols.step_once()
end

function test.p2_force_demote()
	local promo = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_promotion")
	return promo.force_demote_at()
end

--- Staff end-of-transition restore check (Idle2 + layers visible).
function test.staff_force_restore()
	local staff = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.staff_transition")
	local visual = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.visual")
	local ent = controller.find_boss and controller.find_boss()
	staff.clear(ent)
	if ent and visual.idle2 then
		visual.idle2(ent)
	end
	return true, staff.diag()
end

function test.p2_set_paused(p)
	local cols = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_columns")
	cols.set_paused(p)
	return true, cols.is_paused()
end

function test.p2_motion_phase(name)
	local cols = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_columns")
	if cols.debug_set_phase then
		return cols.debug_set_phase(name)
	end
	return false, "no_debug_phase"
end

function test.p2_force_cast()
	local promo = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_promotion")
	local ent = controller.find_boss and controller.find_boss()
	return promo.force_cast(ent)
end

function test.p2_force_promote(side, kind)
	local promo = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_promotion")
	local ent = controller.find_boss and controller.find_boss()
	return promo.force_promote_side(side or "left", kind, ent)
end

function test.p2_set_kind(kind)
	local promo = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_promotion")
	promo.set_force_kind(kind)
	return true, kind
end

function test.p2_clear()
	local promo = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_promotion")
	local cols = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_columns")
	promo.clear("debug")
	return cols.clear("debug")
end

function test.phase_diag()
	local s = controller.get_session()
	local pt = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.phase_transition")
	local staff = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.staff_transition")
	local cols = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_columns")
	local promo = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_promotion")
	local souls = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.command_souls")
	local ent = controller.find_boss and controller.find_boss()
	return {
		state = s.state,
		phase = s.phase,
		pending_phase = s.pending_phase,
		transition_stage = s.transition_stage,
		transition_reason = s.transition_reason,
		frame = s.frame,
		hp = ent and ent.HitPoints,
		max_hp = ent and ent.MaxHitPoints,
		commands_returned = s.commands_returned,
		souls_returned = souls.count_returned and souls.count_returned(),
		transition = pt.diag(),
		staff = staff.diag(),
		p2_columns = cols.diag(),
		p2_promotion = promo.diag(),
	}
end

function test.force_tactic(name)
	director.force_tactic(name)
	return true
end

function test.force_pattern(name)
	controller.debug_force_pattern(name)
	return true
end

--- Force P1「重落子」immediately (requires Idle combat piece with a legal step).
function test.force_royal_drop()
	local ent = controller.find_boss and controller.find_boss() or nil
	if not ent then
		return false, "no_boss"
	end
	if royal_drop.is_busy() then
		return false, "busy"
	end
	local ok, why = royal_drop.try_begin(ent)
	if ok then
		local st = scheduler.get_state()
		st.mode = defs.SCHED.ROYAL_DROP
		st.next_royal_frame = 999999
		royal_drop.tick(ent)
	end
	return ok, why or (royal_drop.diag() and royal_drop.diag().last_fail)
end

--- Jump into late LIFT so target outline + ALIGN can be checked without full cast windup.
function test.royal_align_preview()
	local ent = controller.find_boss and controller.find_boss() or nil
	if not ent then
		return false, "no_boss"
	end
	local ok, why = royal_drop.debug_align_preview(ent)
	if ok then
		local st = scheduler.get_state()
		st.mode = defs.SCHED.ROYAL_DROP
		st.next_royal_frame = 999999
	end
	return ok, why or (royal_drop.diag() and royal_drop.diag().last_fail)
end

function test.royal_drop_diag()
	return royal_drop.diag()
end

function test.fire_pattern_now(name)
	-- Immediate spawn for isolated testing (bypasses scheduler cooldown).
	director.stop_orders()
	local n, pname, why = patterns.execute(2, name)
	return n, pname, why
end

function test.spawn_guard(kind)
	director.bind()
	director.ensure_guards(3, { force_initial = true })
	return true, kind
end

function test.kill_guards()
	director.kill_guards()
	return true
end

function test.defeat()
	controller.debug_defeat()
	return true
end

function test.spawn_unlock()
	local r = runtime.get()
	r.unlock_pending = true
	r.boss_defeated = true
	return rewards.spawn_seal()
end

function test.claim_unlock_debug()
	local ok, why = rewards.claim(Game():GetPlayer(0), {debug_skip_story = true, force = true})
	if ok then
		rewards.remove_all_seals()
	end
	return ok, why
end

function test.reset_combat()
	return controller.debug_reset_combat()
end

function test.reset_test_state()
	return controller.debug_reset_test_state()
end

function test.reset_encounter()
	return test.reset_combat()
end

function test.preview_ante_formation()
	return ante_formation.spawn()
end

function test.preview_reserve()
	director.bind()
	director.stop_orders()
	return reserve_controller.spawn_formation()
end

function test.select_one()
	if not reserve_controller.is_active() then
		reserve_controller.spawn_formation()
	end
	local row = reserve_controller.pick_for_kind(nil)
	if not row then
		return false, "empty"
	end
	return reserve_controller.begin_select(row.id)
end

function test.deploy_one()
	if not reserve_controller.is_active() then
		reserve_controller.spawn_formation()
	end
	director.bind()
	director.stop_orders()
	return deployment.deploy_one()
end

function test.deploy_opening(count)
	if not reserve_controller.is_active() then
		reserve_controller.spawn_formation()
	end
	director.bind()
	director.stop_orders()
	return deployment.deploy_opening(count)
end

function test.deploy_opening_three()
	return test.deploy_opening(3)
end

function test.preview_march()
	director.bind()
	director.stop_orders()
	deployment.cancel_all("preview_march")
	reserve_controller.prepare_formation()
	return reserve_controller.begin_march()
end

function test.force_p1_reinforce()
	-- Legacy button: P1 no longer timed-reinforces; show souls diag instead.
	return false, "p1_souls_only", director.get_diag().command_souls
end

function test.reset_p1_formation()
	local souls = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.command_souls")
	souls.set_suppress_death(true)
	director.kill_guards()
	souls.clear("reset_p1")
	souls.set_suppress_death(false)
	deployment.cancel_all("reset_p1")
	return reserve_controller.spawn_formation()
end

function test.begin_opening_souls()
	if not reserve_controller.is_active() then
		reserve_controller.spawn_formation()
	end
	director.bind()
	director.stop_orders()
	local souls = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.command_souls")
	local ent = controller.find_boss and controller.find_boss()
	if ent then
		visual.command(ent)
	end
	return souls.begin_opening(ent)
end

function test.signal_opening_drop()
	local deployment = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.deployment")
	local souls = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.command_souls")
	local ost = souls.opening_status()
	if ost.batch_id then
		return deployment.signal_batch_drop(ost.batch_id)
	end
	-- Fall back: drop every hovering job.
	local n = 0
	-- opening_status may not expose batch_id on legacy path
	local d = souls.diag()
	local bid = d.opening and d.opening.session_id and ("opening_" .. tostring(d.opening.session_id))
	if bid then
		n = deployment.signal_batch_drop(bid)
	end
	return n
end

function test.souls_diag()
	local souls = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.command_souls")
	return souls.diag()
end

function test.kill_one_command_guard()
	local piece_controller = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_controller")
	local enums = require("Qing_Remaster_scripts.core.enums")
	for _, ent in ipairs(Isaac.FindByType(996, enums.Enemies.chess_piece, -1, false, false)) do
		local d = piece_controller.get_data(ent)
		if d and d.floraine_command and ent:Exists() and not ent:IsDead() then
			ent:Kill()
			return true, d.floraine_command.command_id
		end
	end
	return false, "none"
end

function test.blockers_diag()
	local occupancy = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_occupancy")
	return occupancy.list_blockers()
end

function test.play_release_drop()
	local ent = controller.find_boss and controller.find_boss()
	if not ent then
		return false, "no_boss"
	end
	visual.release(ent)
	return true, "Release"
end

local function souls_mod()
	return require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.command_souls")
end

function test.gold_trigger_next()
	local souls = souls_mod()
	local boss = controller.find_boss and controller.find_boss()
	local ok, th = souls.debug_trigger_next_gold()
	if not ok then
		return false, th
	end
	souls.tick(boss)
	return true, "threshold=" .. tostring(th)
end

function test.gold_spawn_test()
	local souls = souls_mod()
	local boss = controller.find_boss and controller.find_boss()
	if not boss then
		return false, "no_boss"
	end
	return souls.debug_spawn_gold_now(boss)
end

function test.gold_kill_reward()
	local piece_controller = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_controller")
	for _, ent in ipairs(Isaac.FindByType(996, -1, -1, false, false)) do
		local d = piece_controller.get_data(ent)
		if d and d.is_gold and ent:Exists() and not ent:IsDead() then
			ent:Kill()
			return true, d.floraine_command and d.floraine_command.command_id
		end
	end
	return false, "no_gold"
end

function test.gold_report()
	local souls = souls_mod()
	local d = souls.diag()
	local boss = controller.find_boss and controller.find_boss()
	local sess = controller.get_session and controller.get_session()
	local summary = string.format(
		"kills=%s unlocked=%s pending=%s cap=%s live=%s hp=%s/%s phase=%s",
		tostring(d.kill_count),
		tostring(d.unlocked_gold),
		tostring(d.pending_gold),
		tostring(d.p1_guard_cap),
		tostring(d.live_commands),
		boss and string.format("%.1f", boss.HitPoints) or "?",
		boss and string.format("%.1f", boss.MaxHitPoints) or "?",
		sess and tostring(sess.phase) or "?"
	)
	d.summary = summary
	d.boss_hp = boss and boss.HitPoints or nil
	d.session_state = sess and sess.state or nil
	return d
end

function test.directed_order()
	return director.begin_directed_order(controller.find_boss and controller.find_boss())
end

function test.seal_arena()
	arena.seal_combat_doors()
	return arena.get_door_state()
end

function test.open_arena()
	arena.open_return_door()
	return arena.get_door_state()
end

local FREEZE_STATES = {
	"RESERVE", "SELECTED", "PULSING", "LIFTING", "TRANSFERRING", "LANDING",
}

function test.freeze_visual_state(state_name)
	if not reserve_controller.is_active() then
		reserve_controller.spawn_formation()
	end
	local S = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_defs").STATE
	local st = S[state_name] or state_name or S.SELECTED
	local opts = { phase_elapsed = 6 }
	if st == S.LIFTING or st == S.TRANSFERRING then
		opts.visual_height = 14
	elseif st == S.LANDING then
		opts.visual_height = 4
		opts.phase_elapsed = 5
	end
	return reserve_controller.debug_set_state(nil, st, opts)
end

function test.freeze_visual_cycle()
	test._freeze_i = ((test._freeze_i or 0) % #FREEZE_STATES) + 1
	local name = FREEZE_STATES[test._freeze_i]
	local ok, id = test.freeze_visual_state(name)
	return ok, name, id
end

--- Outline visibility A/B: white / red / normal pulse (requires reserve formation).
function test.outline_force(mode)
	if not reserve_controller.is_active() then
		reserve_controller.spawn_formation()
	end
	local rv = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_visual")
	local applied = rv.set_outline_force(mode)
	if mode == "white" or mode == "red" then
		reserve_controller.debug_set_state(nil, reserve_defs.STATE.SELECTED, {
			phase_elapsed = 0,
			outline_pulse = 1,
		})
	end
	rv.sync_all()
	return applied
end

--- Replay opening camera hold→soft release (no full room restart).
function test.replay_opening_camera()
	return controller.debug_replay_opening_camera()
end

local function outline_layer_visible(ent)
	if not ent or not ent.GetSprite then
		return nil
	end
	local s = ent:GetSprite()
	if not s or not s.GetLayer then
		return nil
	end
	local ok, layer = pcall(function()
		return s:GetLayer("outline") or s:GetLayer(1)
	end)
	if not (ok and layer) then
		return nil
	end
	if layer.IsVisible then
		local ok_v, vis = pcall(function()
			return layer:IsVisible()
		end)
		if ok_v then
			return vis == true
		end
	end
	return nil
end

--- Full single-piece command glow path: INFUSING → lift → land → NPC handoff.
-- Use command_glow_diag() while it runs to inspect alpha / fade_start / NPC fade.
function test.preview_command_glow()
	if not reserve_controller.is_active() then
		reserve_controller.spawn_formation()
	end
	director.bind()
	director.stop_orders()
	local rv = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_visual")
	rv.set_outline_force(nil)
	local row = reserve_controller.pick_for_kind(nil)
	if not row then
		return false, "empty"
	end
	local id = row.id
	-- Drop other deploy jobs so this single-piece preview owns the queue.
	deployment.cancel_all("preview_command_glow")
	reserve_controller.set_state(id, reserve_defs.STATE.INFUSING)
	row = reserve_controller.get_row(id)
	if not row then
		return false, "lost_row"
	end
	row.phase_elapsed = 0
	row.freeze_debug = false
	row.visual_height = 0
	row.visual_color_progress = 0
	row.visual_tilt = 0
	rv.begin_command_glow(row)
	local ok, why = deployment.start(id, {
		from_infuse = true,
		auto_drop = true,
		is_opening = false,
	})
	if not ok then
		return false, why or "deploy_start_failed", id
	end
	test._glow_preview_id = id
	rv.sync_all()
	Isaac.DebugString(string.format(
		"[FloraineV2] preview_command_glow piece=%s glow_alpha=%.3f",
		tostring(id),
		tonumber(row.glow_alpha) or 0
	))
	return true, id
end

--- Live diag for the preview / command-glow timeline (matte + NPC handoff).
function test.command_glow_diag(piece_id)
	piece_id = piece_id or test._glow_preview_id
	local row = piece_id and reserve_controller.get_row(piece_id) or nil
	local effect = row and row.effect or nil
	local effect_alive = effect and effect.Exists and effect:Exists() or false
	local npc = nil
	local npc_fade = nil
	local npc_outline_vis = nil
	if row and row.npc_ptr then
		for _, ent in ipairs(Isaac.FindByType(996, -1, -1, false, false)) do
			if GetPtrHash(ent) == row.npc_ptr then
				npc = ent
				break
			end
		end
	end
	if not npc and piece_id then
		local enums = require("Qing_Remaster_scripts.core.enums")
		for _, ent in ipairs(Isaac.FindByType(996, enums.Enemies.chess_piece, -1, false, false)) do
			local d = ent:GetData().QingChessPiece
			if d and d.floraine_command and d.floraine_command.reserve_piece_id == piece_id then
				npc = ent
				break
			end
		end
	end
	if npc then
		local d = npc:GetData().QingChessPiece
		if d then
			npc_fade = d._deploy_outline_fade
		end
		npc_outline_vis = outline_layer_visible(npc)
	end
	local out = {
		piece_id = piece_id,
		state = row and row.state or nil,
		command_kind = row and row.command_kind or nil,
		command_glow = row and row.command_glow == true or false,
		glow_alpha = row and row.glow_alpha or nil,
		last_outline_alpha = row and row._last_outline_alpha or nil,
		glow_fade_start = row and row.glow_fade_start or nil,
		glow_elapsed = row and row.glow_elapsed or nil,
		effect_exists = effect_alive,
		npc_exists = npc ~= nil,
		npc_outline_fade = npc_fade,
		npc_outline_visible = npc_outline_vis,
		effect_outline_visible = effect_alive and outline_layer_visible(effect) or nil,
	}
	Isaac.DebugString(string.format(
		"[FloraineV2] command_glow_diag id=%s st=%s kind=%s glow=%s elapsed=%s a=%.3f last=%.3f fade_start=%s effect=%s npc_fade=%s npc_vis=%s",
		tostring(out.piece_id),
		tostring(out.state),
		tostring(out.command_kind),
		tostring(out.command_glow),
		tostring(out.glow_elapsed),
		tonumber(out.glow_alpha) or -1,
		tonumber(out.last_outline_alpha) or -1,
		tostring(out.glow_fade_start),
		tostring(out.effect_exists),
		tostring(out.npc_outline_fade),
		tostring(out.npc_outline_visible)
	))
	return out
end

function test.snapshot()
	local s = controller.get_session()
	local matte = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.piece_matte_fx")
	local ddiag = director.get_diag()
	local phase_d = test.phase_diag()
	return {
		state = s.state,
		phase = s.phase,
		frame = s.frame,
		transition_stage = s.transition_stage,
		transition_reason = s.transition_reason,
		commands_returned = s.commands_returned,
		guards = director.count_guards(),
		guards_busy = director.any_guards_busy(),
		damage_factor = director.guard_damage_factor and director.guard_damage_factor() or 1,
		command_vuln = director.is_command_vulnerable and director.is_command_vulnerable() or false,
		boss_defeated = runtime.is_boss_defeated(),
		unlock_pending = runtime.is_unlock_pending(),
		first_clear = runtime.has_stone_first_clear(),
		arena_door_state = arena.get_door_state(),
		ante = ante_formation.diag(),
		reserve = reserve_controller.diag(),
		reserve_perf = reserve_controller.get_perf and reserve_controller.get_perf() or nil,
		matte_stats = matte.get_spawn_stats and matte.get_spawn_stats() or nil,
		piece_scan_calls = ddiag and ddiag.piece_scan_calls,
		deployment = deployment.diag(),
		director = ddiag,
		scheduler = scheduler.get_diag(),
		temp = temp_piece.get_diag(),
		royal_drop = royal_drop.diag(),
		opening_camera = controller.get_opening_camera and controller.get_opening_camera().get_diag() or nil,
		opening_timeline = controller.get_opening_timeline and controller.get_opening_timeline() or nil,
		phase_diag = phase_d,
		patterns = {
			rook = defs.PATTERN.ROOK_PIERCE,
			bishop = defs.PATTERN.BISHOP_CROSS,
			pawn = defs.PATTERN.PAWN_TIDE,
			queen = defs.PATTERN.QUEEN_JUDGMENT,
		},
	}
end

return test
