-- Golden Compass: Boss@89 trapdoor site prep/spawn + heaven light.
-- No own MC_* callbacks; runtime remains scheduler.

local M = {}
local deps = nil

local function d()
	return deps
end

-- Bound on install (runtime chunk locals / compass_floor methods).
local runtime
local push_event
local compass_floor
local compass_state
local read_level_identity
local corridor_plan_mod
local BOSS_ROOM_SGID

local function room_has_native_trapdoor(room)
	local size = room:GetGridSize()
	for i = 0, size - 1 do
		local ge = room:GetGridEntity(i)
		if ge and ge:GetType() == GridEntityType.GRID_TRAPDOOR then
			return true, i
		end
	end
	return false, nil
end

local function is_knife_puzzle_dimension()
	local dim = nil
	pcall(function()
		local level = Game():GetLevel()
		if level and level.GetDimension then
			dim = level:GetDimension()
		end
	end)
	if dim == nil and compass_floor and compass_floor.read_current_dimension then
		dim = compass_floor.read_current_dimension()
	end
	return tonumber(dim) == ((Dimension and Dimension.KNIFE_PUZZLE) or 1)
end

--- Strip next-floor trapdoors / heaven light from Boss@89 (mirror / Dad's Note prep).
local function strip_boss_89_trapdoor_exits(tag, reason, note)
	local room = Game():GetRoom()
	local removed = 0
	local size = room:GetGridSize()
	for i = 0, size - 1 do
		local ge = room:GetGridEntity(i)
		if ge and ge:GetType() == GridEntityType.GRID_TRAPDOOR then
			local ok = pcall(function()
				if room.RemoveGridEntityImmediate then
					room:RemoveGridEntityImmediate(i, 0, false)
				else
					room:RemoveGridEntity(i, 0, false)
				end
			end)
			if ok then
				removed = removed + 1
			end
		end
	end
	local heaven_removed = 0
	if compass_floor and compass_floor.find_heaven_light_effect then
		local light = compass_floor.find_heaven_light_effect(room)
		while light do
			pcall(function()
				light:Remove()
			end)
			heaven_removed = heaven_removed + 1
			light = compass_floor.find_heaven_light_effect(room)
			if heaven_removed > 8 then
				break
			end
		end
	end
	local row = {
		tag = tag,
		ok = true,
		skipped = true,
		spawned = false,
		removed_trapdoors = removed,
		removed_heaven_lights = heaven_removed,
		reason = reason or "strip_trapdoor",
		note = note or "Boss@89: forbid trapdoor / heaven light",
	}
	runtime.boss_89_trapdoor = row
	if push_event then
		push_event("boss_89_trapdoor", row)
	end
	return row
end

local function strip_mirror_boss_trapdoor_exits(tag)
	return strip_boss_89_trapdoor_exits(
		tag,
		"mirror_dimension",
		"knife dim Boss@89: forbid trapdoor / heaven light"
	)
end

local function is_dads_note_prep_floor()
	if compass_floor and compass_floor.is_backwards_path_init then
		return compass_floor.is_backwards_path_init() == true
	end
	local on = false
	pcall(function()
		if GameStateFlag and GameStateFlag.STATE_BACKWARDS_PATH_INIT then
			on = Game():GetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH_INIT) == true
		end
	end)
	return on
end

--- Photo-door prep (Dad's Note): no next-floor trapdoor; progression is via the note.
local function strip_dads_note_prep_trapdoor_exits(tag)
	return strip_boss_89_trapdoor_exits(
		tag,
		"backwards_path_init",
		"Dad's Note prep: forbid next-floor trapdoor / heaven light"
	)
end

local TRAPDOOR_STRUCTURAL = {
	[GridEntityType.GRID_DOOR] = true,
	[GridEntityType.GRID_WALL] = true,
	[GridEntityType.GRID_GRAVITY] = true,
	[GridEntityType.GRID_TRAPDOOR] = true,
	[GridEntityType.GRID_STAIRS] = true,
}

local TRAPDOOR_DESTROYABLE = {
	[GridEntityType.GRID_ROCK] = true,
	[GridEntityType.GRID_ROCKB] = true,
	[GridEntityType.GRID_ROCKT] = true,
	[GridEntityType.GRID_ROCK_BOMB] = true,
	[GridEntityType.GRID_ROCK_ALT] = true,
	[GridEntityType.GRID_ROCK_SS] = true,
	[GridEntityType.GRID_ROCK_SPIKED] = true,
	[GridEntityType.GRID_ROCK_ALT2] = true,
	[GridEntityType.GRID_ROCK_GOLD] = true,
	[GridEntityType.GRID_POOP] = true,
	[GridEntityType.GRID_TNT] = true,
	[GridEntityType.GRID_SPIKES] = true,
	[GridEntityType.GRID_SPIKES_ONOFF] = true,
	[GridEntityType.GRID_SPIDERWEB] = true,
}

local function trapdoor_neighborhood_indices(room, center_idx)
	local w = room:GetGridWidth()
	local size = room:GetGridSize()
	local out = {}
	local offsets = {
		0,
		-1, 1,
		-w, w,
		-w - 1, -w + 1,
		w - 1, w + 1,
	}
	for _, off in ipairs(offsets) do
		local idx = center_idx + off
		if idx >= 0 and idx < size then
			out[#out + 1] = idx
		end
	end
	return out
end

local function trapdoor_classify_grid(ge)
	if not ge then
		return "empty"
	end
	local gt = ge:GetType()
	if TRAPDOOR_STRUCTURAL[gt] then
		return "structural", gt
	end
	if gt == GridEntityType.GRID_PIT then
		return "pit", gt
	end
	if TRAPDOOR_DESTROYABLE[gt] then
		return "destroy", gt
	end
	-- Unknown solid-ish: try DestroyGrid; if not, treat as structural later.
	if gt == GridEntityType.GRID_DECORATION
		or gt == GridEntityType.GRID_PRESSURE_PLATE
	then
		return "remove", gt
	end
	return "destroy", gt
end

--- Entity present ≠ still blocking. Rocks: State=2 rubble (Docs). Poop/spikes/web: State or COLLISION_NONE.
local function trapdoor_grid_is_destroyed(ge)
	if not ge then
		return true
	end
	local gt = ge:GetType()
	local st = tonumber(ge.State) or 0
	local col = nil
	pcall(function()
		col = ge.CollisionClass
	end)
	local none = GridCollisionClass and GridCollisionClass.COLLISION_NONE
	if col ~= nil and none ~= nil and col == none then
		return true
	end
	if gt == GridEntityType.GRID_ROCK
		or gt == GridEntityType.GRID_ROCKB
		or gt == GridEntityType.GRID_ROCKT
		or gt == GridEntityType.GRID_ROCK_BOMB
		or gt == GridEntityType.GRID_ROCK_ALT
		or gt == GridEntityType.GRID_ROCK_SS
		or gt == GridEntityType.GRID_ROCK_SPIKED
		or gt == GridEntityType.GRID_ROCK_ALT2
		or gt == GridEntityType.GRID_ROCK_GOLD
		or gt == GridEntityType.GRID_TNT
	then
		return st >= 2
	end
	if gt == GridEntityType.GRID_POOP then
		-- Destroyed poop often keeps Type=14; State advances and/or collision drops.
		return st >= 2
	end
	if gt == GridEntityType.GRID_SPIKES
		or gt == GridEntityType.GRID_SPIKES_ONOFF
		or gt == GridEntityType.GRID_SPIDERWEB
	then
		return st >= 2
	end
	if TRAPDOOR_DESTROYABLE[gt] then
		return st >= 2
	end
	return false
end

local function trapdoor_read_grid_snap(ge)
	if not ge then
		return {present = false}
	end
	return {
		present = true,
		type = ge:GetType(),
		state = tonumber(ge.State),
		variant = ge.GetVariant and ge:GetVariant() or nil,
		collision = ge.CollisionClass,
		destroyed = trapdoor_grid_is_destroyed(ge) == true,
	}
end

local function trapdoor_remove_center_residue(room, idx)
	local before = trapdoor_read_grid_snap(room:GetGridEntity(idx))
	local ok_r = false
	pcall(function()
		if room.RemoveGridEntityImmediate then
			room:RemoveGridEntityImmediate(idx, 0, false)
		else
			room:RemoveGridEntity(idx, 0, false)
		end
		ok_r = true
	end)
	local after = trapdoor_read_grid_snap(room:GetGridEntity(idx))
	return {
		ok = ok_r and (after.present ~= true or after.type == GridEntityType.GRID_TRAPDOOR),
		before = before,
		after = after,
	}
end

local function trapdoor_important_entity_at(room, gidx)
	local pos = room:GetGridPosition(gidx)
	for _, ent in ipairs(Isaac.GetRoomEntities()) do
		if ent and ent:Exists() and ent.Type == EntityType.ENTITY_PICKUP then
			if ent.Position:DistanceSquared(pos) < (28 * 28) then
				return true, ent.Variant, ent.SubType
			end
		end
	end
	return false
end

--- Precheck + DestroyGrid 3x3. Do NOT reject because a destroyed poop/rock GridEntity still exists.
--- Spawn attempt (+ optional center residue remove) happens in ensure_boss_89_trapdoor.
local function try_prepare_trapdoor_site(room, center_idx, label)
	local indices = trapdoor_neighborhood_indices(room, center_idx)
	local blocked = {}
	local plan = {}
	for _, idx in ipairs(indices) do
		local ge = room:GetGridEntity(idx)
		local kind, gt = trapdoor_classify_grid(ge)
		if kind == "structural" then
			blocked[#blocked + 1] = {index = idx, type = gt, reason = "structural"}
		else
			plan[#plan + 1] = {index = idx, kind = kind, type = gt}
		end
	end
	local ent_block, ent_vr, ent_st = trapdoor_important_entity_at(room, center_idx)
	if ent_block then
		blocked[#blocked + 1] = {
			index = center_idx,
			reason = "pickup_overlap",
			variant = ent_vr,
			subtype = ent_st,
		}
	end
	if #blocked > 0 then
		return false, {
			label = label,
			preferred_grid_index = center_idx,
			ok = false,
			blocked_grids = blocked,
			cleared_grids = {},
			bridged_pits = {},
			destroy_steps = {},
			note = "precheck_failed",
		}
	end

	local cleared = {}
	local bridged = {}
	local bridge_pending = {}
	local pit_bridge_steps = {}
	local remove_fail = {}
	local destroy_steps = {}
	local none_col = GridCollisionClass and GridCollisionClass.COLLISION_NONE
	for _, step in ipairs(plan) do
		if step.kind == "empty" then
			-- keep
		elseif step.kind == "pit" then
			-- MakeBridge creates a walkable surface; Type often stays GRID_PIT.
			-- Success = call ok + CollisionClass walkable (not "Type changed").
			local ge = room:GetGridEntity(step.index)
			local pit = ge and ge.ToPit and ge:ToPit() or nil
			local col_before = nil
			pcall(function()
				col_before = ge and ge.CollisionClass
			end)
			local call_ok = false
			local call_err = nil
			if pit and pit.MakeBridge then
				call_ok, call_err = pcall(function()
					pit:MakeBridge(nil)
				end)
			else
				call_err = "no_MakeBridge"
			end
			if call_ok and pit and pit.UpdateCollision then
				pcall(function()
					pit:UpdateCollision()
				end)
			end
			local after = room:GetGridEntity(step.index)
			local col_after = nil
			pcall(function()
				col_after = after and after.CollisionClass
			end)
			local still_type_pit = after ~= nil and after:GetType() == GridEntityType.GRID_PIT
			local walkable = (none_col ~= nil and col_after == none_col)
				or (after ~= nil and trapdoor_grid_is_destroyed(after))
			local step_row = {
				index = step.index,
				bridge_call_ok = call_ok == true,
				bridge_call_error = call_ok and nil or tostring(call_err),
				collision_before = col_before,
				collision_after = col_after,
				still_type_pit = still_type_pit == true,
				walkable = walkable == true,
			}
			pit_bridge_steps[#pit_bridge_steps + 1] = step_row
			if call_ok and walkable then
				bridged[#bridged + 1] = step.index
				step_row.bridge_pending = false
			elseif call_ok and not walkable then
				-- Collision may settle next frame; do not treat remaining GRID_PIT as failure.
				step_row.bridge_pending = true
				bridge_pending[#bridge_pending + 1] = step_row
			else
				remove_fail[#remove_fail + 1] = {
					index = step.index,
					reason = "pit_bridge_call_failed",
					bridge_call_ok = false,
					bridge_call_error = tostring(call_err),
					collision_before = col_before,
					collision_after = col_after,
				}
			end
		elseif step.kind == "destroy" then
			local before_snap = trapdoor_read_grid_snap(room:GetGridEntity(step.index))
			local ok_d = false
			pcall(function()
				ok_d = room:DestroyGrid(step.index, true) == true
			end)
			local after = room:GetGridEntity(step.index)
			local after_snap = trapdoor_read_grid_snap(after)
			-- DestroyGrid accepted OR native destroyed/residue state → OK (entity may still exist).
			local destroyed = after == nil or trapdoor_grid_is_destroyed(after) or ok_d == true
			local step_row = {
				index = step.index,
				destroy_ok = ok_d,
				before = before_snap,
				after = after_snap,
				destroyed = after == nil or trapdoor_grid_is_destroyed(after),
				accepted = destroyed == true,
			}
			destroy_steps[#destroy_steps + 1] = step_row
			if destroyed then
				cleared[#cleared + 1] = step.index
			elseif after and TRAPDOOR_STRUCTURAL[after:GetType()] then
				remove_fail[#remove_fail + 1] = {
					index = step.index,
					reason = "destroy_left_structural",
					type = after:GetType(),
					state = after_snap.state,
				}
			elseif step.type == GridEntityType.GRID_SPIDERWEB
				or step.type == GridEntityType.GRID_DECORATION
			then
				-- Stubborn minor obstacles only (not whole-3x3 rubble wipe).
				local ok_r = pcall(function()
					if room.RemoveGridEntityImmediate then
						room:RemoveGridEntityImmediate(step.index, 0, false)
					else
						room:RemoveGridEntity(step.index, 0, false)
					end
				end)
				local after_r = room:GetGridEntity(step.index)
				step_row.remove_fallback = true
				step_row.remove_ok = ok_r and (after_r == nil or trapdoor_grid_is_destroyed(after_r))
				if step_row.remove_ok then
					cleared[#cleared + 1] = step.index
				else
					remove_fail[#remove_fail + 1] = {
						index = step.index,
						reason = "destroy_failed",
						type = step.type,
						state = after_snap.state,
					}
				end
			else
				remove_fail[#remove_fail + 1] = {
					index = step.index,
					reason = "destroy_not_destroyed",
					type = after and after:GetType() or step.type,
					state = after_snap.state,
					destroy_ok = ok_d,
				}
			end
		elseif step.kind == "remove" then
			local ok_r = pcall(function()
				if room.RemoveGridEntityImmediate then
					room:RemoveGridEntityImmediate(step.index, 0, false)
				else
					room:RemoveGridEntity(step.index, 0, false)
				end
			end)
			if ok_r and room:GetGridEntity(step.index) == nil then
				cleared[#cleared + 1] = step.index
			else
				remove_fail[#remove_fail + 1] = {index = step.index, reason = "remove_failed", type = step.type}
			end
		end
	end

	if #remove_fail > 0 then
		return false, {
			label = label,
			preferred_grid_index = center_idx,
			ok = false,
			blocked_grids = remove_fail,
			cleared_grids = cleared,
			bridged_pits = bridged,
			pit_bridge_steps = pit_bridge_steps,
			bridge_pending = false,
			destroy_steps = destroy_steps,
			note = "clear_failed",
		}
	end

	if #bridge_pending > 0 then
		return false, {
			label = label,
			preferred_grid_index = center_idx,
			ok = false,
			blocked_grids = {},
			cleared_grids = cleared,
			bridged_pits = bridged,
			pit_bridge_steps = pit_bridge_steps,
			bridge_pending = true,
			bridge_pending_grids = bridge_pending,
			destroy_steps = destroy_steps,
			note = "bridge_pending",
		}
	end

	-- Center may still hold destroyed poop/rock residue — that is NOT an automatic fail.
	-- Only intact solids that never accepted DestroyGrid block the site.
	local center_ge = room:GetGridEntity(center_idx)
	local center_snap = trapdoor_read_grid_snap(center_ge)
	local center_residue = false
	if center_ge and center_ge:GetType() ~= GridEntityType.GRID_TRAPDOOR then
		if TRAPDOOR_STRUCTURAL[center_ge:GetType()] then
			return false, {
				label = label,
				preferred_grid_index = center_idx,
				ok = false,
				blocked_grids = {{
					index = center_idx,
					reason = "center_structural",
					type = center_snap.type,
					state = center_snap.state,
				}},
				cleared_grids = cleared,
				bridged_pits = bridged,
				destroy_steps = destroy_steps,
				center_after = center_snap,
				note = "center_blocked_after_clear",
			}
		end
		local center_cleared = false
		for _, idx in ipairs(cleared) do
			if idx == center_idx then
				center_cleared = true
				break
			end
		end
		if center_snap.destroyed or center_cleared then
			center_residue = center_ge ~= nil
		else
			return false, {
				label = label,
				preferred_grid_index = center_idx,
				ok = false,
				blocked_grids = {{
					index = center_idx,
					reason = "center_still_solid",
					type = center_snap.type,
					state = center_snap.state,
					destroyed = false,
				}},
				cleared_grids = cleared,
				bridged_pits = bridged,
				destroy_steps = destroy_steps,
				center_after = center_snap,
				note = "center_blocked_after_clear",
			}
		end
	end

	return true, {
		label = label,
		preferred_grid_index = center_idx,
		ok = true,
		blocked_grids = {},
		cleared_grids = cleared,
		bridged_pits = bridged,
		pit_bridge_steps = pit_bridge_steps,
		bridge_pending = false,
		destroy_steps = destroy_steps,
		center_after = center_snap,
		center_has_destroyed_residue = center_residue == true,
		note = center_residue and "site_ready_try_spawn_over_residue" or "site_ready",
	}
end

--- Spawn native trapdoor at idx; verify type. If residue blocks, remove center only and retry once.
local function try_spawn_trapdoor_at(room, idx, site_detail)
	local attempts = {}
	local function spawn_once(phase)
		local before = trapdoor_read_grid_snap(room:GetGridEntity(idx))
		local ok_spawn, err_spawn = pcall(function()
			room:SpawnGridEntity(idx, GridEntityType.GRID_TRAPDOOR, 0, 1, 0)
		end)
		local after = trapdoor_read_grid_snap(room:GetGridEntity(idx))
		local at_idx = after.present == true and after.type == GridEntityType.GRID_TRAPDOOR
		local row = {
			phase = phase,
			spawn_pcall_ok = ok_spawn == true,
			spawn_error = ok_spawn and nil or tostring(err_spawn),
			before = before,
			after = after,
			at_chosen = at_idx == true,
		}
		attempts[#attempts + 1] = row
		return at_idx == true, row
	end

	local ok = select(1, spawn_once("direct"))
	local center_remove = nil
	if not ok then
		local ge = room:GetGridEntity(idx)
		if ge and ge:GetType() ~= GridEntityType.GRID_TRAPDOOR then
			local snap = trapdoor_read_grid_snap(ge)
			local may_residue = snap.destroyed
				or (site_detail and site_detail.center_has_destroyed_residue == true)
				or TRAPDOOR_DESTROYABLE[ge:GetType()] == true
			if may_residue then
				center_remove = trapdoor_remove_center_residue(room, idx)
				ok = select(1, spawn_once("after_center_residue_remove"))
			end
		end
	end
	return ok, {
		ok = ok == true,
		grid_index = idx,
		attempts = attempts,
		center_remove = center_remove,
	}
end

local function ensure_boss_89_trapdoor(tag)
	local level = Game():GetLevel()
	local cur = level:GetCurrentRoomDesc()
	if not cur or cur.SafeGridIndex ~= BOSS_ROOM_SGID then
		return nil
	end
	local room = Game():GetRoom()
	if not room:IsClear() then
		return nil
	end
	if is_knife_puzzle_dimension() then
		return strip_mirror_boss_trapdoor_exits(tag)
	end
	-- Photo-door / Dad's Note prep: corridor OK, but no GC next-floor passage.
	if is_dads_note_prep_floor() then
		return strip_dads_note_prep_trapdoor_exits(tag)
	end
	local stage = nil
	local stage_type = nil
	if runtime.pending then
		stage = runtime.pending.restore_stage
		stage_type = runtime.pending.restore_stage_type
	end
	if stage == nil then
		local id = read_level_identity()
		stage = id.stage
		stage_type = id.stage_type
	end
	local floor_rule = corridor_plan_mod.get_floor_generation_rule
		and corridor_plan_mod.get_floor_generation_rule(stage, stage_type)
	local exit_rule = floor_rule and floor_rule.normal_exit_rule or nil
	if exit_rule and exit_rule.spawn == false then
		local row = {
			tag = tag,
			ok = true,
			skipped = true,
			spawned = false,
			rule = exit_rule,
			note = "chapter forbids compass trapdoor; keep vanilla end",
		}
		runtime.boss_89_trapdoor = row
		push_event("boss_89_trapdoor", row)
		return row
	end
	local had, existing_idx = room_has_native_trapdoor(room)
	if had then
		local heaven_row = nil
		if exit_rule and exit_rule.keep_heaven_light then
			local center = room:GetCenterPos()
			heaven_row = compass_floor.ensure_boss_89_heaven_light(
				tag,
				center + Vector(40, 0),
				existing_idx,
				true
			)
		end
		local row = {
			tag = tag,
			ok = true,
			spawned = true,
			already_present = true,
			grid_index = existing_idx,
			spawned_grid_index = existing_idx,
			fallback_used = false,
			heaven_light = heaven_row,
			dual_womb_exits = exit_rule and exit_rule.keep_heaven_light == true,
			note = "native trapdoor already present; no duplicate",
		}
		local prev = runtime.boss_89_trapdoor
		runtime.boss_89_trapdoor = row
		if not (prev and prev.spawned and prev.grid_index == existing_idx) then
			push_event("boss_89_trapdoor", row)
		end
		return row
	end
	-- Cached spawn but grid gone after leave/re-enter — clear and respawn.
	if runtime.boss_89_trapdoor and runtime.boss_89_trapdoor.spawned then
		push_event("boss_89_trapdoor_missing", {
			tag = tag,
			prev = runtime.boss_89_trapdoor,
			note = "cached trapdoor missing in live room; will respawn",
		})
		runtime.boss_89_trapdoor = nil
	end

	local center = room:GetCenterPos()
	local dual = exit_rule and exit_rule.keep_heaven_light == true
	-- Womb II: trapdoor/heaven center-left/right (no Boss pedestal). Else single upper trapdoor.
	local preferred_pos = dual and (center + Vector(-40, 0)) or (center + Vector(0, -80))
	local heaven_pos = dual and (center + Vector(40, 0)) or (center + Vector(40, -80))
	local preferred_idx = room:GetGridIndex(preferred_pos)
	local center_idx = room:GetGridIndex(center)
	local site_attempts = {}
	local spawn_attempts = {}
	local chosen_idx = nil
	local fallback_used = false
	local site_detail = nil
	local spawn_detail = nil
	local fallback_reason = nil
	local side2 = dual and (center + Vector(-80, 0)) or center
	local side2_idx = room:GetGridIndex(side2)
	local free_pos = dual and preferred_pos or room:FindFreePickupSpawnPosition(preferred_pos, 0, true)
	local free_idx = room:GetGridIndex(free_pos)
	local preferred_label = dual and "womb_center_left" or "center_up_2"
	local fallback_candidates = {
		{idx = dual and side2_idx or center_idx, label = dual and "womb_left_alt" or "center", fallback = true},
		{idx = free_idx, label = dual and "womb_center_left_fixed" or "free_near_preferred", fallback = true},
	}

	local function try_one_site(cand)
		local ok_site, detail = try_prepare_trapdoor_site(room, cand.idx, cand.label)
		site_attempts[#site_attempts + 1] = detail
		if detail and detail.bridge_pending == true then
			return "pending", detail, nil
		end
		if not ok_site then
			return "failed", detail, nil
		end
		local ok_spawn, sdetail = try_spawn_trapdoor_at(room, cand.idx, detail)
		spawn_attempts[#spawn_attempts + 1] = sdetail
		if ok_spawn then
			return "spawned", detail, sdetail
		end
		detail.spawn_failed = true
		detail.spawn_detail = sdetail
		return "spawn_failed", detail, sdetail
	end

	-- Preferred site first. Never fall back in the same frame while bridges are pending.
	local pending = runtime.boss_89_trapdoor_pending_retry
	local game_frame = Game():GetFrameCount()
	local allow_fallback = true
	if pending and tonumber(pending.preferred_grid_index) == preferred_idx then
		local status, detail, sdetail = try_one_site({
			idx = preferred_idx,
			label = preferred_label,
			fallback = false,
		})
		if status == "pending" then
			-- One delayed retry already spent → abandon preferred this visit.
			if (tonumber(pending.retries) or 0) >= 1 then
				fallback_reason = "preferred_bridge_pending_exhausted"
				runtime.boss_89_trapdoor_pending_retry = nil
				allow_fallback = true
			else
				pending.retries = (tonumber(pending.retries) or 0) + 1
				pending.retry_frame = game_frame
				runtime.boss_89_trapdoor_pending_retry = pending
				local wait_row = {
					tag = tag,
					ok = false,
					spawned = false,
					pending = true,
					bridge_pending = true,
					preferred_grid_index = preferred_idx,
					chosen_grid_index = preferred_idx,
					retry_frame = game_frame,
					retries = pending.retries,
					site_attempts = site_attempts,
					pit_bridge_steps = detail and detail.pit_bridge_steps,
					fallback_used = false,
					spawn_at_preferred = false,
					note = "bridge_pending_wait_preferred",
				}
				runtime.boss_89_trapdoor = wait_row
				push_event("boss_89_trapdoor_pending", wait_row)
				return wait_row
			end
		elseif status == "spawned" then
			chosen_idx = preferred_idx
			fallback_used = false
			site_detail = detail
			spawn_detail = sdetail
			runtime.boss_89_trapdoor_pending_retry = nil
			allow_fallback = false
		else
			fallback_reason = "preferred_" .. tostring(status)
			runtime.boss_89_trapdoor_pending_retry = nil
		end
	else
		local status, detail, sdetail = try_one_site({
			idx = preferred_idx,
			label = preferred_label,
			fallback = false,
		})
		if status == "pending" then
			runtime.boss_89_trapdoor_pending_retry = {
				preferred_grid_index = preferred_idx,
				label = preferred_label,
				retries = 0,
				armed_frame = game_frame,
			}
			local wait_row = {
				tag = tag,
				ok = false,
				spawned = false,
				pending = true,
				bridge_pending = true,
				preferred_grid_index = preferred_idx,
				chosen_grid_index = preferred_idx,
				retry_frame = nil,
				retries = 0,
				site_attempts = site_attempts,
				pit_bridge_steps = detail and detail.pit_bridge_steps,
				fallback_used = false,
				spawn_at_preferred = false,
				note = "bridge_pending_wait_preferred",
			}
			runtime.boss_89_trapdoor = wait_row
			push_event("boss_89_trapdoor_pending", wait_row)
			return wait_row
		elseif status == "spawned" then
			chosen_idx = preferred_idx
			fallback_used = false
			site_detail = detail
			spawn_detail = sdetail
			runtime.boss_89_trapdoor_pending_retry = nil
			allow_fallback = false
		else
			fallback_reason = "preferred_" .. tostring(status)
			runtime.boss_89_trapdoor_pending_retry = nil
		end
	end

	if allow_fallback and chosen_idx == nil then
		for _, cand in ipairs(fallback_candidates) do
			local status, detail, sdetail = try_one_site(cand)
			if status == "spawned" then
				chosen_idx = cand.idx
				fallback_used = true
				site_detail = detail
				spawn_detail = sdetail
				fallback_reason = fallback_reason or "preferred_unavailable"
				break
			elseif status == "pending" then
				-- Fallback sites: treat unresolved bridge as hard miss and continue.
				fallback_reason = fallback_reason or "fallback_bridge_pending_skip"
			end
		end
	end

	if chosen_idx == nil then
		chosen_idx = preferred_idx
		fallback_used = true
		fallback_reason = fallback_reason or "all_sites_failed"
		site_detail = site_attempts[#site_attempts]
		spawn_detail = spawn_attempts[#spawn_attempts]
	end

	local still, still_idx = room_has_native_trapdoor(room)
	local at_chosen = false
	pcall(function()
		local ge = room:GetGridEntity(chosen_idx)
		at_chosen = ge ~= nil and ge:GetType() == GridEntityType.GRID_TRAPDOOR
	end)
	local at_preferred = false
	pcall(function()
		local ge = room:GetGridEntity(preferred_idx)
		at_preferred = ge ~= nil and ge:GetType() == GridEntityType.GRID_TRAPDOOR
	end)
	local heaven_row = nil
	if dual then
		heaven_row = compass_floor.ensure_boss_89_heaven_light(
			tag,
			heaven_pos,
			still_idx or chosen_idx,
			true
		)
	end
	local row = {
		tag = tag,
		ok = still == true and at_chosen == true,
		spawned = still == true,
		already_present = false,
		preferred_grid_index = preferred_idx,
		chosen_grid_index = chosen_idx,
		spawned_grid_index = still_idx or chosen_idx,
		grid_index = still_idx or chosen_idx,
		spawned_at_chosen = at_chosen == true,
		spawn_at_preferred = at_preferred == true,
		fallback_used = fallback_used,
		fallback_reason = fallback_reason,
		cleared_grids = site_detail and site_detail.cleared_grids or {},
		bridged_pits = site_detail and site_detail.bridged_pits or {},
		pit_bridge_steps = site_detail and site_detail.pit_bridge_steps or nil,
		blocked_grids = site_detail and site_detail.blocked_grids or {},
		destroy_steps = site_detail and site_detail.destroy_steps or nil,
		center_remove = spawn_detail and spawn_detail.center_remove or nil,
		site_attempts = site_attempts,
		spawn_attempts = spawn_attempts,
		spawn_detail = spawn_detail,
		heaven_light = heaven_row,
		dual_womb_exits = dual == true,
		note = dual
			and "womb II dual: trapdoor center-left + HEAVEN_LIGHT_DOOR center-right"
			or "prefer center+(0,-80); pit bridge via CollisionClass; pending preferred before fallback",
	}
	runtime.boss_89_trapdoor = row
	push_event("boss_89_trapdoor", row)
	return row
end
function M.ensure_boss_89_trapdoor(tag)
	return ensure_boss_89_trapdoor(tag)
end

-- Game-time frames: 30 Hz TimeCounter (Docs: BossRushParTime = frames of game time).
local FRAMES_PER_MINUTE = 30 * 60
local MAUSOLEUM_BOSS_RUSH_FRAMES = 25 * FRAMES_PER_MINUTE

local function resolve_restore_stage_pair()
	local stage, stage_type
	if runtime.pending then
		stage = runtime.pending.restore_stage
		stage_type = runtime.pending.restore_stage_type
	end
	if compass_state and compass_state.get then
		local root = compass_state.get() or {}
		stage = stage or root.restore_stage or root.target_stage
		stage_type = stage_type or root.restore_stage_type or root.target_stage_type
	end
	if stage == nil then
		local id = read_level_identity and read_level_identity() or {}
		stage = id.stage
		stage_type = id.stage_type
	end
	return tonumber(stage), tonumber(stage_type)
end

local function is_repentance_alt_stage_type(stage_type)
	stage_type = tonumber(stage_type)
	local st_rep = StageType and StageType.STAGETYPE_REPENTANCE
	local st_rep_b = StageType and StageType.STAGETYPE_REPENTANCE_B
	return (st_rep ~= nil and stage_type == st_rep)
		or (st_rep_b ~= nil and stage_type == st_rep_b)
end

--- Boss Rush: Depths II / Necropolis II / Dank II + Mausoleum II / Gehenna II.
--- Blue Womb: Womb II / Utero II / Scarred Womb II only (not Corpse II).
local function classify_timed_special_door(stage, stage_type)
	stage = tonumber(stage)
	local alt = is_repentance_alt_stage_type(stage_type)
	if stage == LevelStage.STAGE3_2 then
		return "boss_rush", alt == true
	end
	if stage == LevelStage.STAGE4_2 then
		if alt then
			return nil, false
		end
		return "blue_womb", false
	end
	return nil, false
end

local function has_strange_key()
	local trinket = TrinketType and TrinketType.TRINKET_STRANGE_KEY
	if trinket == nil then
		return false
	end
	local found = false
	pcall(function()
		for i = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(i)
			if player and player.GetTrinketMultiplier
				and player:GetTrinketMultiplier(trinket) > 0
			then
				found = true
				break
			end
		end
	end)
	return found
end

local function find_door_to_grid_room(room, target_idx)
	target_idx = tonumber(target_idx)
	if not room or target_idx == nil then
		return nil, nil
	end
	local num = (DoorSlot and DoorSlot.NUM_DOOR_SLOTS) or 8
	for slot = 0, num - 1 do
		local door = room:GetDoor(slot)
		if door and tonumber(door.TargetRoomIndex) == target_idx then
			return slot, door
		end
	end
	return nil, nil
end

local function timed_door_target_idx(kind)
	if kind == "boss_rush" then
		return (GridRooms and GridRooms.ROOM_BOSSRUSH_IDX) or -5
	end
	if kind == "blue_womb" then
		return (GridRooms and GridRooms.ROOM_BLUE_WOOM_IDX) or -8
	end
	return nil
end

local function timed_door_state_flag(kind)
	if kind == "boss_rush" then
		return GameStateFlag and GameStateFlag.STATE_BOSSRUSH_DOOR_SPAWNED
	end
	if kind == "blue_womb" then
		return GameStateFlag and GameStateFlag.STATE_BLUEWOMB_DOOR_SPAWNED
	end
	return nil
end

local function read_timed_door_presence(room, kind)
	local target_idx = timed_door_target_idx(kind)
	local slot = select(1, find_door_to_grid_room(room, target_idx))
	local flagged = false
	local flag = timed_door_state_flag(kind)
	if flag ~= nil then
		pcall(function()
			flagged = Game():GetStateFlag(flag) == true
		end)
	end
	return {
		-- Live Door only: STATE_*_DOOR_SPAWNED is global and must not skip spawn.
		exists = slot ~= nil,
		door_slot = slot,
		target_idx = target_idx,
		state_flagged = flagged == true,
	}
end

local function read_time_gate(kind, mausoleum_alt)
	local game = Game()
	local time_now = nil
	local par = nil
	pcall(function()
		time_now = tonumber(game.TimeCounter)
	end)
	if kind == "boss_rush" then
		pcall(function()
			par = tonumber(game.BossRushParTime)
		end)
		if mausoleum_alt then
			-- Mausoleum/Gehenna II: 25 minutes (own gate; ParTime may still be Depths 20m after Home restore).
			par = MAUSOLEUM_BOSS_RUSH_FRAMES
		elseif par == nil then
			par = 20 * FRAMES_PER_MINUTE
		end
	elseif kind == "blue_womb" then
		pcall(function()
			par = tonumber(game.BlueWombParTime)
		end)
		if par == nil then
			par = 30 * FRAMES_PER_MINUTE
		end
	end
	local within = time_now ~= nil and par ~= nil and time_now <= par
	return {
		time_now = time_now,
		deadline = par,
		within = within == true,
	}
end

--- Spawn Boss Rush / Blue Womb door via vanilla Room API (Force=true for GC Home-then-restore).
--- opts.ignore_time: Mama Mega explosion only (not persisted).
--- opts.require_clear: default true; Mama Mega may set false to try mid-fight.
function ensure_timed_special_door(tag, opts)
	opts = opts or {}
	if not runtime or runtime.corridor_active ~= true then
		return nil
	end
	local level = Game():GetLevel()
	local cur = level:GetCurrentRoomDesc()
	if not cur or cur.SafeGridIndex ~= BOSS_ROOM_SGID then
		return nil
	end
	if is_knife_puzzle_dimension() then
		local skip = {
			tag = tag,
			ok = true,
			skipped = true,
			spawned = false,
			reason = "mirror_dimension",
			note = "knife dim Boss@89: forbid Boss Rush / Blue Womb door",
		}
		runtime.boss_89_timed_door = skip
		if opts.force_log == true and push_event then
			push_event("boss_89_timed_door", skip)
		end
		return skip
	end
	local room = Game():GetRoom()
	local require_clear = opts.require_clear ~= false
	local ignore_time = opts.ignore_time == true
	local stage, stage_type = resolve_restore_stage_pair()
	local kind, mausoleum_alt = classify_timed_special_door(stage, stage_type)
	local backwards = false
	if compass_floor and compass_floor.is_backwards_path_init then
		backwards = compass_floor.is_backwards_path_init() == true
	else
		pcall(function()
			if GameStateFlag and GameStateFlag.STATE_BACKWARDS_PATH_INIT then
				backwards = Game():GetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH_INIT) == true
			end
		end)
	end
	local strange_key = has_strange_key()
	local presence = kind and read_timed_door_presence(room, kind) or {
		exists = false,
	}
	local time_gate = kind and read_time_gate(kind, mausoleum_alt) or {}
	-- Avoid per-frame log spam from emit_boss_90_clear_if_needed / POST_UPDATE.
	if ignore_time ~= true and opts.force_log ~= true then
		local prev = runtime.boss_89_timed_door
		if prev and prev.kind == kind then
			if presence.exists and (prev.spawned == true or prev.reason == "already_exists") then
				return prev
			end
			if prev.reason == "time_exceeded" and strange_key ~= true then
				return prev
			end
			if prev.reason == "floor_ineligible" or prev.reason == "backwards_path_init" then
				return prev
			end
			if prev.reason == "mirror_dimension" then
				return prev
			end
		elseif prev and kind == nil and prev.reason == "floor_ineligible" then
			return prev
		elseif prev and prev.reason == "mirror_dimension" then
			return prev
		end
	end
	local row = {
		tag = tag,
		kind = kind,
		stage = stage,
		stage_type = stage_type,
		mausoleum_alt = mausoleum_alt == true,
		backwards_path_init = backwards,
		ignore_time = ignore_time,
		require_clear = require_clear,
		room_clear = room:IsClear() == true,
		strange_key = strange_key,
		time_now = time_gate.time_now,
		deadline = time_gate.deadline,
		time_within = time_gate.within == true,
		door_exists = presence.exists == true,
		door_slot = presence.door_slot,
		target_idx = presence.target_idx,
		state_flagged = presence.state_flagged == true,
		api_ok = nil,
		spawned = false,
		skipped = false,
		reason = nil,
	}
	local function finish(reason, extra)
		row.reason = reason
		if extra then
			for k, v in pairs(extra) do
				row[k] = v
			end
		end
		push_event("boss_89_timed_door", row)
		runtime.boss_89_timed_door = row
		return row
	end
	if kind == nil then
		row.skipped = true
		return finish("floor_ineligible")
	end
	if backwards then
		row.skipped = true
		return finish("backwards_path_init")
	end
	if presence.exists then
		row.skipped = true
		row.spawned = true
		return finish("already_exists")
	end
	if require_clear and room:IsClear() ~= true then
		row.skipped = true
		return finish("not_clear")
	end
	local allow_ignore = ignore_time
	if kind == "blue_womb" and strange_key then
		allow_ignore = true
	end
	if not allow_ignore and time_gate.within ~= true then
		row.skipped = true
		return finish("time_exceeded")
	end
	-- Mausoleum owns 25m: if past vanilla ParTime but within 25m, must IgnoreTime.
	local api_ignore = allow_ignore
	if kind == "boss_rush" and mausoleum_alt and not allow_ignore then
		api_ignore = true
	end
	local api_ok = false
	local call_ok = false
	if kind == "boss_rush" and room.TrySpawnBossRushDoor then
		call_ok, api_ok = pcall(function()
			return room:TrySpawnBossRushDoor(api_ignore == true, true)
		end)
	elseif kind == "blue_womb" and room.TrySpawnBlueWombDoor then
		call_ok, api_ok = pcall(function()
			return room:TrySpawnBlueWombDoor(true, api_ignore == true, true)
		end)
	else
		row.skipped = true
		return finish("api_missing")
	end
	row.api_call_ok = call_ok == true
	row.api_ok = call_ok == true and api_ok == true
	row.api_ignore_time = api_ignore == true
	local after = read_timed_door_presence(room, kind)
	row.door_exists = after.exists == true
	row.door_slot = after.door_slot
	row.state_flagged = after.state_flagged == true
	row.spawned = after.exists == true
	if row.spawned then
		return finish("spawned")
	elseif row.api_ok then
		return finish("api_true_but_no_door")
	end
	return finish("api_false")
end

function M.ensure_timed_special_door(tag, opts)
	return ensure_timed_special_door(tag, opts)
end

--- Debug: bypass timed-door gates; call vanilla TrySpawnBlueWombDoor(true,true,true) once.
function M.force_try_blue_womb_door(tag)
	if is_knife_puzzle_dimension() then
		local row = {
			tag = tag or "force_try_blue_womb",
			ok = true,
			skipped = true,
			spawned = false,
			reason = "mirror_dimension",
			note = "knife dim: refuse force Blue Womb door",
		}
		runtime.boss_89_blue_womb_force_test = row
		if push_event then
			push_event("boss_89_blue_womb_force_test", row)
		end
		return row
	end
	local game = Game()
	local level = game:GetLevel()
	local room = game:GetRoom()
	local cur = level:GetCurrentRoomDesc()
	local target_idx = timed_door_target_idx("blue_womb")
	local before_slot = select(1, find_door_to_grid_room(room, target_idx))
	local state_flagged = false
	local flag = timed_door_state_flag("blue_womb")
	if flag ~= nil then
		pcall(function()
			state_flagged = game:GetStateFlag(flag) == true
		end)
	end
	local stage, stage_type = nil, nil
	pcall(function()
		stage = level:GetStage()
		stage_type = level:GetStageType()
	end)
	local restore_stage, restore_stage_type = resolve_restore_stage_pair()
	local neg_snap = nil
	pcall(function()
		local desc = level:GetRoomByIdx(target_idx, 0)
		local data = desc and desc.Data
		neg_snap = {
			present = desc ~= nil,
			safe_grid_index = desc and desc.SafeGridIndex or nil,
			type = data and data.Type,
			variant = data and data.Variant,
			subtype = data and data.Subtype,
			shape = data and data.Shape,
		}
	end)
	local call_ok, api_result = false, nil
	if room.TrySpawnBlueWombDoor then
		call_ok, api_result = pcall(function()
			return room:TrySpawnBlueWombDoor(true, true, true)
		end)
	else
		call_ok = false
		api_result = "api_missing"
	end
	local after_slot = select(1, find_door_to_grid_room(room, target_idx))
	local state_flagged_after = false
	if flag ~= nil then
		pcall(function()
			state_flagged_after = game:GetStateFlag(flag) == true
		end)
	end
	local row = {
		tag = tag or "force_try_blue_womb",
		sgid = cur and cur.SafeGridIndex or nil,
		room_type = cur and cur.Data and cur.Data.Type or nil,
		stage = stage,
		stage_type = stage_type,
		restore_stage = restore_stage,
		restore_stage_type = restore_stage_type,
		target_idx = target_idx,
		target_desc = neg_snap,
		door_before = before_slot ~= nil,
		door_slot_before = before_slot,
		call_ok = call_ok == true,
		api_result = api_result,
		door_after = after_slot ~= nil,
		door_slot_after = after_slot,
		state_flagged_before = state_flagged == true,
		state_flagged_after = state_flagged_after == true,
		note = "raw TrySpawnBlueWombDoor(true,true,true); bypasses ensure_timed_special_door",
	}
	if push_event then
		push_event("boss_89_blue_womb_force_test", row)
	end
	runtime.boss_89_blue_womb_force_test = row
	return row
end

function M.install(inject)
	deps = inject
	runtime = inject.runtime
	push_event = inject.push_event
	compass_floor = inject.compass_floor
	read_level_identity = inject.read_level_identity
	corridor_plan_mod = inject.corridor_plan
	compass_state = inject.compass_state
	BOSS_ROOM_SGID = inject.boss_room_sgid
	-- Expose to runtime as local replacement
	return M.ensure_boss_89_trapdoor
end

return M
