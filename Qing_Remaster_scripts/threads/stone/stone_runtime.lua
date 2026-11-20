-- StoneRun persistent state / phase machine.
-- Progress phases are irreversible forward; room location is queried separately.

local save = require("Qing_Remaster_scripts.core.savedata")
local defs = require("Qing_Remaster_scripts.threads.stone.stone_defs")

local runtime = {}

local PHASE_RANK = {
	[defs.PHASE.DORMANT] = 0,
	[defs.PHASE.LAYOUT_READY] = 1,
	[defs.PHASE.ORIGIN_FOUND] = 2,
	[defs.PHASE.BOARD_ACTIVE] = 3,
	[defs.PHASE.APPROACHING] = 4,
	[defs.PHASE.BOSS_READY] = 5,
	[defs.PHASE.BOSS_ENTERED] = 6,
	[defs.PHASE.COMPLETED] = 7,
	[defs.PHASE.ABORTED] = -1,
	[defs.PHASE.UNAVAILABLE] = -2,
}

local function empty_run()
	return {
		schema_version = defs.SCHEMA_VERSION,
		phase = defs.PHASE.DORMANT,
		floor = nil,
		trigger = nil,
		terminal = nil,
		route = nil,
		hidden = nil,
		board = { activated = false, activation_frame = nil },
		gate = {
			unlocked = false,
			reveal_pending = false,
			ante_boss_opened = false,
		},
		layout_fail = nil,
		attempts = {
			mines1 = false,
			mines1_success = false,
			mines2 = false,
			missed = false,
		},
		suppress_floraine = false,
		encounters = {},
		boss_defeated = false,
		unlock_pending = false,
	}
end

local function normalize_hidden_floraine(r)
	if type(r) ~= "table" or type(r.hidden) ~= "table" then
		return defs.FLORAINE_VARIANT
	end
	local prev = tonumber(r.hidden.floraine_variant)
	local resolved = defs.resolve_floraine_variant(prev)
	r.hidden.floraine_variant = resolved
	return resolved
end

--- Map legacy floraine_variant → canonical 23752 without touching route/phase.
function runtime.normalize_floraine_variant()
	return normalize_hidden_floraine(runtime.get())
end

function runtime.get()
	local root = save.elses
	if type(root[defs.RUN_KEY]) ~= "table" then
		root[defs.RUN_KEY] = empty_run()
	end
	local r = root[defs.RUN_KEY]
	r.schema_version = r.schema_version or defs.SCHEMA_VERSION
	r.phase = r.phase or defs.PHASE.DORMANT
	r.board = r.board or { activated = false }
	r.gate = r.gate or { unlocked = false, reveal_pending = false, ante_boss_opened = false }
	if r.gate.ante_boss_opened == nil then
		r.gate.ante_boss_opened = false
	end
	r.attempts = r.attempts or {
		mines1 = false,
		mines1_success = false,
		mines2 = false,
		missed = false,
	}
	if r.attempts.mines1_success == nil then
		r.attempts.mines1_success = false
	end
	if r.attempts.missed == nil then
		r.attempts.missed = false
	end
	r.encounters = r.encounters or {}
	r.board = r.board or { activated = false }
	if r.boss_defeated == nil then
		r.boss_defeated = false
	end
	if r.unlock_pending == nil then
		r.unlock_pending = false
	end
	normalize_hidden_floraine(r)
	return r
end

function runtime.reset()
	save.elses[defs.RUN_KEY] = empty_run()
	-- LEGACY-SAVE: clear old Thread_Stone_* keys when resetting.
	save.elses[defs.OWN_KEY .. "spawn"] = nil
	save.elses[defs.OWN_KEY .. "effect"] = nil
	save.elses[defs.OWN_KEY .. "map"] = nil
	return save.elses[defs.RUN_KEY]
end

function runtime.get_phase()
	return runtime.get().phase
end

function runtime.phase_rank(phase)
	return PHASE_RANK[phase]
end

--- True when `to` is a forward progress step from `from`.
function runtime.can_advance_phase(to, from)
	from = from or runtime.get_phase()
	if to == nil then return false, "nil" end
	if from == to then return false, "same" end
	if from == defs.PHASE.COMPLETED then
		return false, "completed"
	end
	if from == defs.PHASE.UNAVAILABLE then
		return false, "unavailable"
	end
	local from_rank = PHASE_RANK[from]
	local to_rank = PHASE_RANK[to]
	if from_rank == nil or to_rank == nil then
		return false, "unknown"
	end
	if to_rank < 0 then
		-- Terminal non-progress outcomes are explicit.
		return true
	end
	if from_rank < 0 then
		return false, "terminal_phase"
	end
	if to_rank <= from_rank then
		return false, "not_forward"
	end
	return true
end

--- Advance progress only. Does not rewrite phase for ordinary room revisits.
function runtime.advance_phase(to, reason)
	local r = runtime.get()
	local ok, why = runtime.can_advance_phase(to, r.phase)
	if not ok then
		return false, why
	end
	r.phase = to
	r.phase_reason = reason
	return true
end

--- Force-write phase. Prefer advance_phase for gameplay; force is for reset / debug / floor clear.
function runtime.set_phase(phase, opts)
	opts = opts or {}
	if opts.force then
		runtime.get().phase = phase
		return true
	end
	return runtime.advance_phase(phase, opts.reason)
end

function runtime.is_board_active()
	local r = runtime.get()
	return r.board and r.board.activated == true
end

function runtime.has_layout()
	local r = runtime.get()
	return r.trigger ~= nil and r.terminal ~= nil and type(r.route) == "table"
end

function runtime.has_hidden_chain()
	local r = runtime.get()
	return r.hidden ~= nil
		and r.hidden.ante_variant ~= nil
		and r.hidden.floraine_variant ~= nil
end

function runtime.floor_matches()
	local r = runtime.get()
	if not r.floor then return false end
	local level = Game():GetLevel()
	return level:GetStage() == r.floor.stage
		and level:GetStageType() == r.floor.stage_type
end

function runtime.is_eligible_stage(stage, stage_type)
	stage = stage or Game():GetLevel():GetStage()
	stage_type = stage_type or Game():GetLevel():GetStageType()
	if stage_type < StageType.STAGETYPE_REPENTANCE then
		return false
	end
	return stage == LevelStage.STAGE2_1 or stage == LevelStage.STAGE2_2
end

function runtime.mark_attempt(stage)
	local r = runtime.get()
	if stage == LevelStage.STAGE2_1 then
		r.attempts.mines1 = true
	elseif stage == LevelStage.STAGE2_2 then
		r.attempts.mines2 = true
	end
end

function runtime.should_try_layout()
	if not runtime.is_eligible_stage() then
		return false, "wrong_stage"
	end
	local r = runtime.get()
	if r.phase == defs.PHASE.COMPLETED or r.phase == defs.PHASE.UNAVAILABLE then
		return false, r.phase
	end
	if runtime.has_layout() and runtime.floor_matches() then
		return false, "already"
	end
	-- Successful Mines I offer → never re-offer on Mines II.
	if r.attempts.mines1_success then
		return false, "already_offered_mines1"
	end
	-- Missed a valid layout this run → do not invent a new board elsewhere.
	if r.attempts.missed then
		return false, "missed"
	end
	local stage = Game():GetLevel():GetStage()
	if stage == LevelStage.STAGE2_1 then
		-- Same floor must not re-roll after a failed or attempted plan.
		if r.attempts.mines1 then
			return false, "mines1_already_tried"
		end
		return true
	end
	if stage == LevelStage.STAGE2_2 then
		if r.attempts.mines2 then
			return false, "mines2_already_tried"
		end
		-- Compensation only when Mines I was attempted and failed to plan.
		if r.attempts.mines1 and not r.attempts.mines1_success then
			return true
		end
		-- Mid-run entry starting on Mines II (never saw Mines I).
		if not r.attempts.mines1 then
			return true
		end
		return false, "mines1_already_offered"
	end
	return false, "skip"
end

function runtime.activate_board(reason)
	local r = runtime.get()
	if not runtime.has_layout() then
		return false, "no_layout"
	end
	if r.board.activated then
		return false, "already"
	end
	local phase = r.phase
	if phase == defs.PHASE.COMPLETED or phase == defs.PHASE.UNAVAILABLE then
		return false, phase
	end
	if PHASE_RANK[phase] and PHASE_RANK[phase] >= PHASE_RANK[defs.PHASE.BOARD_ACTIVE] then
		return false, "already_past"
	end
	r.board.activated = true
	r.board.activation_frame = Game():GetFrameCount()
	r.board.reason = reason or "origin_destroyed"
	r.gate.unlocked = true
	-- Reveal only if the gate appears while the player is already standing in Terminal.
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	r.gate.reveal_pending = r.terminal ~= nil
		and desc ~= nil
		and desc.SafeGridIndex == r.terminal.safe_grid_index
	if not r.hidden then
		r.hidden = {
			ante_variant = defs.ANTE_VARIANT,
			floraine_variant = defs.FLORAINE_VARIANT,
		}
	else
		runtime.normalize_floraine_variant()
	end
	if not runtime.advance_phase(defs.PHASE.BOARD_ACTIVE, reason or "activate") then
		-- Soft recover: layout exists but phase lagged behind activation.
		if (PHASE_RANK[r.phase] or 0) < PHASE_RANK[defs.PHASE.BOARD_ACTIVE] then
			r.phase = defs.PHASE.BOARD_ACTIVE
		end
	end
	return true
end

function runtime.consume_gate_reveal_request()
	local r = runtime.get()
	if r.gate and r.gate.reveal_pending then
		r.gate.reveal_pending = false
		return true
	end
	return false
end

function runtime.mark_ante_boss_opened()
	local r = runtime.get()
	r.gate = r.gate or {}
	r.gate.ante_boss_opened = true
end

function runtime.is_ante_boss_opened()
	local r = runtime.get()
	return r.gate and r.gate.ante_boss_opened == true
end

--- Clear live floor layout when leaving Mines/Ashpit. Keeps attempt flags.
function runtime.clear_floor_layout(opts)
	opts = opts or {}
	local r = runtime.get()
	local had_layout = runtime.has_layout()
	local completed = r.phase == defs.PHASE.COMPLETED
	local unavailable = r.phase == defs.PHASE.UNAVAILABLE
	if had_layout and not completed and not unavailable then
		r.attempts.missed = true
	end
	r.trigger = nil
	r.terminal = nil
	r.route = nil
	r.hidden = nil
	r.board = { activated = false }
	r.gate = { unlocked = false, reveal_pending = false, ante_boss_opened = false }
	r.floor = nil
	r.suppress_floraine = false
	r.layout_fail = nil
	r.encounters = {}
	if completed then
		r.phase = defs.PHASE.COMPLETED
	elseif unavailable then
		r.phase = defs.PHASE.UNAVAILABLE
	elseif r.attempts.missed or r.attempts.mines1_success then
		r.phase = defs.PHASE.ABORTED
	else
		r.phase = defs.PHASE.DORMANT
	end
	return r
end

function runtime.mark_completed(reason)
	local r = runtime.get()
	if r.phase == defs.PHASE.COMPLETED then
		return true, "already"
	end
	r.phase = defs.PHASE.COMPLETED
	r.complete_reason = reason
	return true
end

--- Backward-compatible alias used by older callers.
-- V2: do not call on Boss HP=0; call after seal claim via claim_boss_unlock.
function runtime.complete_boss()
	return runtime.mark_completed("complete_boss")
end

--- Permanent Floraine / Stone first clear = chapter1.stone node completed.
-- Do not use has_token alone (material token ≠ permanent first clear).
function runtime.has_stone_first_clear()
	local ok, story = pcall(require, "Qing_Remaster_scripts.story.story_state")
	if not ok or not story or not story.is_node_completed then
		return false
	end
	return story.is_node_completed("chapter1", "chapter1.stone") == true
end

--- Boss HP reached zero. Does NOT complete the story thread.
function runtime.mark_boss_defeated()
	local r = runtime.get()
	r.boss_defeated = true
	if not runtime.has_stone_first_clear() then
		r.unlock_pending = true
	end
	return true
end

function runtime.is_boss_defeated()
	return runtime.get().boss_defeated == true
end

function runtime.is_unlock_pending()
	return runtime.get().unlock_pending == true
end

--- After seal pickup succeeds: permanent story must register before clearing pending.
-- @param opts table|nil {skip_story=bool, story_test=bool, force=bool, require_story=bool}
function runtime.claim_boss_unlock(player, opts)
	opts = opts or {}
	local r = runtime.get()
	if not r.unlock_pending and not opts.force then
		return false, "no_pending"
	end
	if opts.skip_story then
		r.unlock_pending = false
		r.boss_defeated = true
		return true, "skipped_story"
	end
	local ok, thread = pcall(require, "Qing_Remaster_scripts.threads.thread_Stone")
	if not ok or not thread or not thread.complete_thread then
		return false, "no_thread"
	end
	local cok, why, registered = thread.complete_thread("floraine_seal_claim", {
		force = true,
		story_test = opts.story_test == true,
		require_story = opts.require_story ~= false,
	})
	if not cok then
		return false, why or "complete_failed"
	end
	if opts.require_story ~= false and not registered and not runtime.has_stone_first_clear() then
		return false, "story_not_registered"
	end
	r.unlock_pending = false
	r.boss_defeated = true
	return true, why or "ok"
end

function runtime.debug_snapshot()
	local r = runtime.get()
	local path = r.route and r.route.path or {}
	return {
		phase = r.phase,
		activated = r.board and r.board.activated,
		gate_unlocked = r.gate and r.gate.unlocked,
		ante_boss_opened = r.gate and r.gate.ante_boss_opened == true,
		trigger = r.trigger and r.trigger.safe_grid_index,
		terminal = r.terminal and r.terminal.safe_grid_index,
		route_len = #path,
		route = path,
		ante = r.hidden and r.hidden.ante_variant,
		floraine = r.hidden and r.hidden.floraine_variant,
		fail = r.layout_fail,
		attempts = r.attempts,
		mines1_success = r.attempts and r.attempts.mines1_success == true,
		missed = r.attempts and r.attempts.missed == true,
		suppress_floraine = r.suppress_floraine == true,
		boss_defeated = r.boss_defeated == true,
		unlock_pending = r.unlock_pending == true,
	}
end

return runtime
