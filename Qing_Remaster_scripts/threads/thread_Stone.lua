-- Chess story thread shell: Story Gate, reward, adapters.
-- Map runtime lives in Qing_Remaster_scripts/threads/stone/*.

local enums = require("Qing_Remaster_scripts.core.enums")
local save = require("Qing_Remaster_scripts.core.savedata")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local gate = require("Qing_Remaster_scripts.story.story_runtime_gate")
local defs = require("Qing_Remaster_scripts.threads.stone.stone_defs")
local runtime = require("Qing_Remaster_scripts.threads.stone.stone_runtime")
local layout = require("Qing_Remaster_scripts.threads.stone.stone_layout")
local rooms = require("Qing_Remaster_scripts.threads.stone.stone_rooms")
local board = require("Qing_Remaster_scripts.threads.stone.stone_board")
local route = require("Qing_Remaster_scripts.threads.stone.stone_route")

local item = {
	ToCall = {},
	pre_ToCall = {},
	myToCall = {},
	post_ToCall = {},
	own_key = defs.OWN_KEY,
}

function item.set_off()
	runtime.reset()
end

function item.set_on()
	layout.try_plan_current_floor({ force = true, ignore_gate = true })
	runtime.activate_board("legacy_set_on")
end

function item.can_spawn()
	return runtime.is_eligible_stage()
end

function item.should_spawn()
	return runtime.has_layout() and runtime.floor_matches()
end

local function resolve_story_owned(opts)
	opts = opts or {}
	if opts.story_owned ~= nil then
		return opts.story_owned == true
	end
	if opts.story_test == true then
		return true
	end
	return gate.is_commission_accepted() and gate.is_chapter1_available()
end

local function phase_allows_complete(phase, opts)
	if opts and (opts.force == true or opts.story_test == true) then
		return true
	end
	if phase == defs.PHASE.COMPLETED then
		return true
	end
	local rank = runtime.phase_rank(phase) or -1
	-- Formal completion expects the player to have reached the Floraine room chain.
	return rank >= (runtime.phase_rank(defs.PHASE.BOSS_ENTERED) or 6)
end

local function stone_node_completed()
	local ok, story = pcall(require, "Qing_Remaster_scripts.story.story_state")
	if not ok or not story or not story.is_node_completed then
		return false
	end
	return story.is_node_completed("chapter1", "chapter1.stone") == true
end

--- Canonical Stone thread completion. Boss seal claim and Story Test both call this.
-- Returns: ok, why, story_registered
-- When story_owned, Adapter must succeed (or node already completed) before run mark.
-- Does not invent a second persistence owner; Story advances only via material_story_adapter.
function item.complete_thread(reason, opts)
	opts = opts or {}
	local r = runtime.get()
	if r.phase == defs.PHASE.COMPLETED and stone_node_completed() then
		return true, "already", true
	end
	if not phase_allows_complete(r.phase, opts) then
		return false, "bad_phase", false
	end
	if not opts.force and not opts.story_test then
		if not runtime.has_hidden_chain() and not runtime.is_board_active() then
			return false, "no_board", false
		end
	end

	local story_owned = resolve_story_owned(opts)
	local story_registered = false
	local already_node = stone_node_completed()
	if already_node then
		story_registered = true
	elseif story_owned or opts.story_test == true then
		local ok, material_adapter = pcall(require, "Qing_Remaster_scripts.story.material_story_adapter")
		if ok and material_adapter and material_adapter.on_thread_complete then
			story_registered = material_adapter.on_thread_complete("stone", {
				story_owned = true,
				story_test = opts.story_test == true,
			}) == true
		end
		-- Re-check node after grant (complete_node may return false if already true).
		if not story_registered and stone_node_completed() then
			story_registered = true
		end
		if not story_registered and not opts.allow_run_only then
			return false, "story_not_registered", false
		end
	elseif opts.require_story == true then
		return false, "not_story_owned", false
	end

	runtime.mark_completed(reason or "complete_thread")
	return true, already_node and "already" or "ok", story_registered
end

-- ---- Floor planning ----

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_LEVEL,
	params = nil,
	Function = function(_)
		local r = runtime.get()
		if r.phase == defs.PHASE.COMPLETED or r.phase == defs.PHASE.UNAVAILABLE then
			-- Still drop live layout pointers; keep terminal phase.
			runtime.clear_floor_layout()
			return
		end
		runtime.clear_floor_layout()
		rooms.clear_ante_wait()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function(_)
		if Game():GetRoom():GetFrameCount() > 0 then return end
		if not gate.is_material_event_enabled("chapter1.stone") then return end
		if runtime.is_eligible_stage() then
			layout.ensure_for_current_floor()
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function(_)
		rooms.on_new_room()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function(_)
		local perf = board.get_board_perf and board.get_board_perf() or nil
		local done_upd = perf and perf.scope and perf.scope("stone_update_ns") or function() end
		rooms.tick_antechamber()
		rooms.tick_scene()
		local ok_dbg, stone_debug = pcall(require, "Qing_Remaster_scripts.threads.stone.stone_debug")
		if ok_dbg and stone_debug and stone_debug.tick_prepare then
			stone_debug.tick_prepare()
		end
		done_upd()
	end,
})

-- Prepare FSM must also advance while the game is paused (ImGui open).
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_RENDER,
	params = nil,
	Function = function(_)
		local ok_dbg, stone_debug = pcall(require, "Qing_Remaster_scripts.threads.stone.stone_debug")
		if not ok_dbg or not stone_debug or not stone_debug.has_prepare_job then
			return
		end
		if stone_debug.has_prepare_job() then
			stone_debug.tick_prepare({ from_render = true })
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE,
	params = nil,
	Function = function(_, player)
		if not player or player.Variant ~= 0 then return end
		rooms.tick_origin_prompt(player)
	end,
})

-- Board: per-cell ownership routing (EMPTY helper + Grid PRE/POST). Not backdrop→walls; not POST_RENDER.
-- See codex_work/notes/ff_floor_render_path.md.

local function register_grid_pre(callback_id, tag)
	if not (REPENTOGON and callback_id) then return end
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = callback_id,
		params = nil,
		Function = function(_, grid, _offset)
			board.render_grid_cell(grid, tag or "GRID_PRE")
		end,
	})
end

register_grid_pre(ModCallbacks.MC_PRE_GRID_ENTITY_ROCK_RENDER, "GRID_PRE")
register_grid_pre(ModCallbacks.MC_PRE_GRID_ENTITY_POOP_RENDER, "GRID_PRE")
register_grid_pre(ModCallbacks.MC_PRE_GRID_ENTITY_SPIKES_RENDER, "GRID_PRE")
register_grid_pre(ModCallbacks.MC_PRE_GRID_ENTITY_TNT_RENDER, "GRID_PRE")
register_grid_pre(ModCallbacks.MC_PRE_GRID_ENTITY_DOOR_RENDER, "GRID_PRE")
register_grid_pre(ModCallbacks.MC_PRE_GRID_ENTITY_LOCK_RENDER, "GRID_PRE")
register_grid_pre(ModCallbacks.MC_PRE_GRID_ENTITY_PRESSUREPLATE_RENDER, "GRID_PRE")
register_grid_pre(ModCallbacks.MC_PRE_GRID_ENTITY_DECORATION_RENDER, "GRID_PRE")
register_grid_pre(ModCallbacks.MC_PRE_GRID_ENTITY_WEB_RENDER, "GRID_PRE")
register_grid_pre(ModCallbacks.MC_PRE_GRID_ENTITY_TELEPORTER_RENDER, "GRID_PRE")

if REPENTOGON and ModCallbacks.MC_POST_GRID_ENTITY_PIT_RENDER then
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_GRID_ENTITY_PIT_RENDER,
		params = nil,
		Function = function(_, pit)
			board.render_grid_cell(pit, "PIT_POST")
		end,
	})
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function(_)
		board.remove_overlay_helper()
		board.ensure_overlay_helper()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function(_)
		if board.should_keep_overlay() then
			board.ensure_overlay_helper()
		else
			board.remove_overlay_helper()
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_EFFECT_RENDER,
	params = enums.Entities.Stone_Board_Overlay,
	Function = function(_, effect, _offset)
		if board.is_overlay_effect(effect) then
			local perf = board.get_board_perf and board.get_board_perf() or nil
			if perf and perf.mark_overlay then
				perf.mark_overlay(effect)
			end
			board.render_empty_cells("EMPTY_HELPER")
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_RENDER,
	params = nil,
	Function = function(_)
		local skip_vis = board.should_skip_stone_visuals and board.should_skip_stone_visuals()
		if not REPENTOGON and not skip_vis then
			-- Non-RGON only: last-resort full draw (may cover entities).
			board.render_floor_overlay("POST_RENDER")
		end
		if not skip_vis then
			rooms.render_room_fx()
			rooms.render_origin_label()
		end
		local perf = board.get_board_perf and board.get_board_perf() or nil
		if perf and perf.is_enabled and perf.is_enabled() and perf.flush_frame then
			perf.flush_frame()
		end
	end,
})

-- Giant Pawn NPC: stationary prop update / crack / custom render.
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_NPC_UPDATE,
	params = 996,
	Function = function(_, npc)
		local origin = require("Qing_Remaster_scripts.threads.stone.stone_origin")
		if origin.is_living_giant_pawn(npc) then
			origin.update_npc(npc)
		end
	end,
})

-- Re-apply LayerState colors immediately before draw (ANM2 frame tint can overwrite Update sets).
if REPENTOGON and ModCallbacks.MC_PRE_NPC_RENDER then
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_PRE_NPC_RENDER,
		params = 996,
		Function = function(_, npc, _offset)
			if board.should_skip_stone_visuals and board.should_skip_stone_visuals() then
				return
			end
			local origin = require("Qing_Remaster_scripts.threads.stone.stone_origin")
			if origin.is_living_giant_pawn(npc) and origin.apply_layer_colors_for_render then
				origin.apply_layer_colors_for_render(npc)
			end
		end,
	})
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NPC_RENDER,
	params = 996,
	Function = function(_, npc, offset)
		if board.should_skip_stone_visuals and board.should_skip_stone_visuals() then
			return
		end
		local origin = require("Qing_Remaster_scripts.threads.stone.stone_origin")
		if origin.is_living_giant_pawn(npc) then
			origin.render_npc(npc, offset)
		end
	end,
})

-- Official activation: stage-3 finish_breaking via Update / TAKE_DMG (not Kill).
table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
	CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG,
	params = 996,
	Function = function(_, ent, amount, flags, source, countdown)
		local origin = require("Qing_Remaster_scripts.threads.stone.stone_origin")
		return origin.on_take_damage(ent, amount, flags, source, countdown)
	end,
})

-- Safety net only if the engine still kills the pawn somehow.
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NPC_DEATH,
	params = 996,
	Function = function(_, npc)
		rooms.try_activate_from_origin_kill(npc)
	end,
})

-- ---- Legacy special-room reward (not the Mines chessboard route) ----
-- SafeGridIndex -11 / Variant 1000 is an older reward room. It must not drive
-- StoneRun board phases or Floraine completion. Material grant stays for that
-- room only; formal chess completion uses item.complete_thread.

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function(_)
		local room = Game():GetRoom()
		local level = Game():GetLevel()
		local desc = level:GetCurrentRoomDesc()
		local stageType = level:GetStageType()
		if not gate.is_chapter1_available() then return end
		if stageType < StageType.STAGETYPE_REPENTANCE then return end
		if not desc or desc.SafeGridIndex ~= -11 or not desc.Data or desc.Data.Variant ~= 1000 then
			return
		end
		if not room:IsFirstVisit() then return end
		-- Chessboard route owns completion when a live layout exists this floor.
		if runtime.has_layout() and runtime.floor_matches() then
			return
		end
		if runtime.get_phase() == defs.PHASE.COMPLETED then
			return
		end
		local n_ent = Isaac.GetRoomEntities()
		local keys = auxi.getothers(n_ent, 5, 30, 1)
		if #keys < 1 then return end
		local targ = keys[1]:ToPickup()
		if targ then
			targ:Remove()
		end
		local story_owned = gate.is_commission_accepted() and gate.is_chapter1_available()
		local ok, material_adapter = pcall(require, "Qing_Remaster_scripts.story.material_story_adapter")
		if ok and material_adapter and material_adapter.on_thread_complete then
			material_adapter.on_thread_complete("stone", {story_owned = story_owned == true})
		end
		-- Deliberately does not call runtime.mark_completed / complete_boss.
	end,
})

item.story_test = {
	snapshot = function(_ctx)
		return {
			run = runtime.get(),
		}
	end,
	restore = function(snap, _ctx)
		runtime.reset()
		rooms.clear_ante_wait()
		if type(snap) ~= "table" or type(snap.run) ~= "table" then return end
		save.elses[defs.RUN_KEY] = snap.run
	end,
	reset = function(ctx)
		ctx = ctx or {}
		rooms.clear_ante_wait()
		if ctx.soft or ctx.reset_encounter_only then
			local r = runtime.get()
			r.encounters = {}
			return true
		end
		runtime.reset()
		return true
	end,
	prepare = function(ctx)
		ctx = ctx or {}
		local phase = ctx.phase or "pre_trigger"
		rooms.clear_ante_wait()
		local reuse_layout = ctx.reuse_layout
		if reuse_layout == nil then
			reuse_layout = true
		end
		local have_layout = runtime.has_layout() and runtime.floor_matches()
		-- Never wipe a valid same-floor layout during Story Test prepare.
		if not have_layout then
			if phase == "pre_trigger" then
				return true
			end
			layout.try_plan_current_floor({ force = true, ignore_gate = true })
			have_layout = runtime.has_layout() and runtime.floor_matches()
		elseif ctx.reset_encounter then
			local r = runtime.get()
			r.encounters = {}
		end
		if phase == "pre_trigger" then
			return true
		end
		if phase == "layout_ready" or phase == "discovered" then
			-- Origin / pre-shatter: keep layout, ensure board is inactive.
			local r = runtime.get()
			if r.board and r.board.activated then
				r.board.activated = false
			end
			runtime.set_phase(defs.PHASE.LAYOUT_READY, {force = true, reason = "story_test_layout"})
			return true
		end
		if not have_layout and not reuse_layout then
			layout.try_plan_current_floor({ force = true, ignore_gate = true })
		end
		if phase == "board_active" or phase == "origin_found" then
			if not runtime.is_board_active() then
				runtime.activate_board("story_test")
			end
			return true
		end
		if phase == "boss" or phase == "boss_ready" then
			if not runtime.is_board_active() then
				runtime.activate_board("story_test")
			end
			runtime.get().suppress_floraine = true
			return true
		end
		if phase == "complete" or phase == "completed" then
			if not runtime.is_board_active() then
				runtime.activate_board("story_test")
			end
			item.complete_thread("story_test_prepare", {force = true, story_test = true})
			return true
		end
		return true
	end,
	trigger = function(ctx)
		ctx = ctx or {}
		layout.ensure_for_current_floor({ force = true, ignore_gate = true })
		runtime.activate_board("story_test_trigger")
		return true
	end,
	complete = function(ctx)
		ctx = ctx or {}
		return item.complete_thread(ctx.reason or "story_test_complete", {
			force = true,
			story_test = true,
			story_owned = true,
		})
	end,
	inspect = function(_ctx)
		local snap = runtime.debug_snapshot()
		return {
			phase = snap.phase,
			spawn = snap.activated,
			has_map = runtime.has_layout(),
			effect = snap.terminal ~= nil,
			can_spawn = item.can_spawn(),
			gate = gate.is_material_event_enabled("chapter1.stone"),
			route_len = snap.route_len,
			trigger = snap.trigger,
			terminal = snap.terminal,
			fail = snap.fail,
			ante_boss_opened = snap.ante_boss_opened,
			missed = snap.missed,
			location = rooms.current_location(),
		}
	end,
	cleanup = function(_ctx)
		runtime.reset()
		rooms.clear_ante_wait()
		return true
	end,
}

-- Public map APIs for future chess-piece modules.
item.runtime = runtime
item.route = route
item.rooms = rooms
item.layout = layout
item.board = board
item.defs = defs

return item
