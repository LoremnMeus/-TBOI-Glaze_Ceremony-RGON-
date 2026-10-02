-- StoneRun persistent state / phase machine.

local save = require("Qing_Remaster_scripts.core.savedata")
local defs = require("Qing_Remaster_scripts.threads.stone.stone_defs")

local runtime = {}

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
		gate = { unlocked = false, reveal_pending = false },
		layout_fail = nil,
		attempts = {
			mines1 = false,
			mines1_success = false,
			mines2 = false,
		},
		suppress_floraine = false,
	}
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
	r.gate = r.gate or { unlocked = false, reveal_pending = false }
	r.attempts = r.attempts or { mines1 = false, mines1_success = false, mines2 = false }
	if r.attempts.mines1_success == nil then
		r.attempts.mines1_success = false
	end
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

function runtime.set_phase(phase)
	runtime.get().phase = phase
end

function runtime.is_board_active()
	local r = runtime.get()
	return r.board and r.board.activated == true
end

function runtime.has_layout()
	local r = runtime.get()
	return r.trigger ~= nil and r.terminal ~= nil and type(r.route) == "table"
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
	-- Mines I already offered a valid layout this run → never re-offer on Mines II.
	if r.attempts.mines1_success then
		return false, "already_offered_mines1"
	end
	local stage = Game():GetLevel():GetStage()
	if stage == LevelStage.STAGE2_1 then
		return true
	end
	-- Mines II only compensates when Mines I was attempted and failed to plan.
	if stage == LevelStage.STAGE2_2 then
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
	r.board.activated = true
	r.board.activation_frame = Game():GetFrameCount()
	r.board.reason = reason or "origin_destroyed"
	r.gate.unlocked = true
	-- Reveal only if the gate appears while the player is already standing in Terminal.
	-- Normal shatter happens in Trigger; later Terminal visits should start as Opened.
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	r.gate.reveal_pending = r.terminal ~= nil
		and desc ~= nil
		and desc.SafeGridIndex == r.terminal.safe_grid_index
	if not r.hidden then
		local rng = Game():GetPlayer(0):GetCollectibleRNG(CollectibleType.COLLECTIBLE_DADS_KEY)
		local pool = defs.FLORAINE_VARIANTS
		local pick = pool[(rng:RandomInt(#pool)) + 1]
		r.hidden = {
			ante_variant = defs.ANTE_VARIANT,
			floraine_variant = pick,
		}
	end
	runtime.set_phase(defs.PHASE.BOARD_ACTIVE)
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

function runtime.complete_boss()
	runtime.set_phase(defs.PHASE.COMPLETED)
	return true
end

function runtime.debug_snapshot()
	local r = runtime.get()
	local path = r.route and r.route.path or {}
	return {
		phase = r.phase,
		activated = r.board and r.board.activated,
		gate_unlocked = r.gate and r.gate.unlocked,
		trigger = r.trigger and r.trigger.safe_grid_index,
		terminal = r.terminal and r.terminal.safe_grid_index,
		route_len = #path,
		route = path,
		ante = r.hidden and r.hidden.ante_variant,
		floraine = r.hidden and r.hidden.floraine_variant,
		fail = r.layout_fail,
		attempts = r.attempts,
		mines1_success = r.attempts and r.attempts.mines1_success == true,
		suppress_floraine = r.suppress_floraine == true,
	}
end

return runtime
