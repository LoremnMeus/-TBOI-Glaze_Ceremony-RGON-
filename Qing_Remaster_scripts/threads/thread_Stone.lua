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

-- ---- Floor planning ----

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_LEVEL,
	params = nil,
	Function = function(_)
		local r = runtime.get()
		if r.phase == defs.PHASE.COMPLETED or r.phase == defs.PHASE.UNAVAILABLE then
			return
		end
		-- Drop live layout when leaving the floor; keep attempt flags.
		r.trigger = nil
		r.terminal = nil
		r.route = nil
		r.hidden = nil
		r.board = { activated = false }
		r.gate = { unlocked = false, reveal_pending = false }
		r.floor = nil
		r.suppress_floraine = false
		runtime.set_phase(defs.PHASE.DORMANT)
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
		rooms.tick_antechamber()
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

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_RENDER,
	params = nil,
	Function = function(_)
		board.render_floor_overlay()
		rooms.render_origin_label()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NPC_DEATH,
	params = nil,
	Function = function(_, npc)
		rooms.try_activate_from_origin_kill(npc)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_ENTITY_KILL,
	params = nil,
	Function = function(_, ent)
		rooms.try_activate_from_origin_kill(ent)
	end,
})

-- ---- Mirror completion reward (unchanged) ----

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function(_)
		local room = Game():GetRoom()
		local level = Game():GetLevel()
		local desc = level:GetCurrentRoomDesc()
		local stageType = level:GetStageType()
		if gate.is_chapter1_available() then
			if stageType >= StageType.STAGETYPE_REPENTANCE
				and desc.SafeGridIndex == -11
				and desc.Data
				and desc.Data.Variant == 1000
				and room:IsFirstVisit()
			then
				local n_ent = Isaac.GetRoomEntities()
				local keys = auxi.getothers(n_ent, 5, 30, 1)
				if #keys > 0 then
					local targ = keys[1]:ToPickup()
					-- Legacy Rock Shard Morph retired: clear reward pedestal, grant Story token.
					if targ then
						targ:Remove()
					end
					local ok, material_adapter = pcall(require, "Qing_Remaster_scripts.story.material_story_adapter")
					if ok and material_adapter and material_adapter.on_thread_complete then
						material_adapter.on_thread_complete("stone", {story_owned = true})
					end
					runtime.complete_boss()
				end
			end
		end
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
		if type(snap) ~= "table" or type(snap.run) ~= "table" then return end
		save.elses[defs.RUN_KEY] = snap.run
	end,
	reset = function(_ctx)
		runtime.reset()
		return true
	end,
	prepare = function(ctx)
		ctx = ctx or {}
		local phase = ctx.phase or "pre_trigger"
		runtime.reset()
		if phase == "pre_trigger" then
			return true
		end
		layout.try_plan_current_floor({ force = true, ignore_gate = true })
		if phase == "layout_ready" or phase == "discovered" then
			return true
		end
		if phase == "board_active" or phase == "origin_found" then
			runtime.activate_board("story_test")
			return true
		end
		if phase == "boss" or phase == "boss_ready" then
			runtime.activate_board("story_test")
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
		}
	end,
	cleanup = function(_ctx)
		runtime.reset()
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
