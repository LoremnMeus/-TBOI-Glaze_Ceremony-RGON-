-- Golden Compass: Boss@89 secret-exit door (Basement->Mausoleum flesh / mines / heart rules).
-- Native Room:TrySpawnSecretExit + door restore only. No TargetRoomIndex forge. No own callbacks.
-- Extracted from runtime.lua; install() also assigns moved helpers onto inject.compass_floor.

local M = {}

local deps = nil
-- deps: runtime, cfg, compass_floor, compass_state, corridor_plan, read_level_identity,
--       push_event, secret_exit_idx, snapshot_neg_desc, snapshot_special_door

local runtime = nil
local cfg = nil
local compass_floor = nil -- non-moved helpers only (is_backwards_path_init, is_mausoleum_ii_alt, snapshot_witness_route)
local compass_state = nil
local corridor_plan_mod = nil
local read_level_identity = nil
local push_event = nil
local SECRET_EXIT_IDX = -10
local snapshot_neg_desc = nil
local snapshot_special_door = nil

function M.find_secret_exit_door(room)
	if not room then
		return nil, nil
	end
	local found_door, found_slot = nil, nil
	pcall(function()
		local n = (DoorSlot and DoorSlot.NUM_DOOR_SLOTS) or 8
		for slot = 0, n - 1 do
			local door = room:GetDoor(slot)
			if door and door.TargetRoomIndex == SECRET_EXIT_IDX then
				found_door = door
				found_slot = slot
				break
			end
		end
	end)
	return found_door, found_slot
end

--- Presence helper shared by witness / boss secret-exit spawn (must live above callers).
function M.room_has_secret_exit_door(room)
	local door, slot = M.find_secret_exit_door(room)
	return door ~= nil, slot
end

function M.notify_secret_exit_door_observer(phase, payload)
	local cb = runtime.secret_exit_door_observer
	if type(cb) ~= "function" then
		return
	end
	pcall(cb, phase, payload)
end

function M.secret_exit_spawn_meta()
	return {
		attempted_this_visit = runtime.secret_exit_attempted_this_visit == true,
		attempts = runtime.secret_exit_spawn_attempts or 0,
		confirmed_slot = runtime.secret_exit_confirmed_slot,
		last_spawn = runtime.secret_exit_spawn,
	}
end

--- Full read-only secret-exit door snapshot for the door probe (no mutations).
function M.snapshot_secret_exit_door_probe(tag)
	local level = Game():GetLevel()
	local room = Game():GetRoom()
	local cur = level:GetCurrentRoomDesc()
	local door, slot = M.find_secret_exit_door(room)
	local snap = snapshot_special_door(door)
	local floor = compass_state.get_floor_persist() or {}
	local out = {
		tag = tag,
		sgid = cur and cur.SafeGridIndex or nil,
		slot = slot,
		door_present = door ~= nil,
		persisted = floor.secret_exit_door,
		spawn_meta = M.secret_exit_spawn_meta(),
		rule = M.resolve_secret_exit_rule(),
	}
	if snap then
		for k, v in pairs(snap) do
			out[k] = v
		end
	end
	out.restore_consistency = runtime.secret_exit_restore_consistency
	out.persist_hold = runtime.secret_exit_persist_hold == true
	out.persist_hold_reason = runtime.secret_exit_persist_hold_reason
	out.identity_restored_seen = runtime.identity_restored_seen == true
	out.boss_89_visit_active = runtime.boss_89_visit_active == true
	out.boss_89_visit_init_tag = runtime.boss_89_visit_init_tag
	out.secret_exit_attempted_this_visit = runtime.secret_exit_attempted_this_visit == true
	out.deal_type = runtime.corridor_deal_type
	out.deal_type_source = runtime.deal_type_source
	out.continue_current_room_pending = runtime.continue_current_room_pending == true
	return out
end

function M.remove_secret_exit_doors(room, tag)
	if not room then
		return 0
	end
	local removed = 0
	pcall(function()
		local n = (DoorSlot and DoorSlot.NUM_DOOR_SLOTS) or 8
		for slot = 0, n - 1 do
			local door = room:GetDoor(slot)
			if door then
				local target = nil
				pcall(function()
					target = door.TargetRoomIndex
				end)
				if target == SECRET_EXIT_IDX then
					if room.RemoveDoor then
						room:RemoveDoor(slot)
						removed = removed + 1
					end
				end
			end
		end
	end)
	if removed > 0 then
		push_event("boss_89_secret_exit_removed", {tag = tag, removed = removed})
	end
	return removed
end

function M.resolve_secret_exit_rule()
	local stage, stage_type
	if runtime.pending then
		stage = runtime.pending.restore_stage
		stage_type = runtime.pending.restore_stage_type
	end
	if stage == nil then
		local id = read_level_identity()
		stage = id.stage
		stage_type = id.stage_type
	end
	local rule
	if corridor_plan_mod.get_secret_exit_rule then
		rule = corridor_plan_mod.get_secret_exit_rule(stage, stage_type)
	else
		rule = {eligible = false, reason = "rule_api_missing"}
	end
	-- Dad's Note / photo-door route: do not prepare Mom's Heart -10 or flesh door.
	if rule and rule.kind == "mausoleum_heart" and compass_floor.is_backwards_path_init() then
		return {
			eligible = false,
			reason = "backwards_path_init_blocks_heart",
			target_subtype = nil,
			kind = nil,
			stage = stage,
			stage_type = stage_type,
			blocked_kind = "mausoleum_heart",
		}
	end
	-- Manual witness probe may still force the heart rule after clearing BACKWARDS_PATH_INIT.
	if cfg.witness_mausoleum_test
		and compass_floor.is_mausoleum_ii_alt(stage, stage_type)
		and not compass_floor.is_backwards_path_init()
		and (not rule or rule.kind ~= "mausoleum_heart" or rule.eligible ~= true)
	then
		return {
			eligible = true,
			reason = "witness_mausoleum_test",
			target_subtype = nil,
			kind = "mausoleum_heart",
			test = true,
			stage = stage,
			stage_type = stage_type,
		}
	end
	return rule
end

--- Shared TrySpawnSecretExit call. Animate always false (no smoke). Presence > return value.
function M.call_try_spawn_secret_exit(room, force)
	local animate = false
	local spawned = false
	local err = nil
	if not room or not room.TrySpawnSecretExit then
		return false, "TrySpawnSecretExit_missing", animate
	end
	local ok, ret = pcall(function()
		return room:TrySpawnSecretExit(animate, force == true)
	end)
	if ok then
		spawned = ret == true
	else
		err = tostring(ret)
	end
	return spawned, err, animate
end

function M.mines_half_cracked_state()
	return (DoorState and DoorState.STATE_HALF_CRACKED) or 4
end

--- Mausoleum flesh door one-key / one-heart stage (DoorState.STATE_ONE_CHAIN).
function M.mausoleum_one_chain_state()
	return (DoorState and DoorState.STATE_ONE_CHAIN) or 3
end

function M.begin_secret_exit_persist_hold(reason)
	runtime.secret_exit_persist_hold = true
	runtime.secret_exit_persist_hold_reason = reason
end

function M.clear_secret_exit_persist_hold(_reason)
	runtime.secret_exit_persist_hold = false
	runtime.secret_exit_persist_hold_reason = nil
end

--- unpaid | partial | fully_open — from persisted payment fields (not live sprite alone).
--- Mines: STATE_HALF_CRACKED (4). Mausoleum key door: STATE_ONE_CHAIN (3).
--- Mausoleum Heart flesh door: no Feed/ONE_CHAIN partial; opened via native Open / STATE_MOTHER_HEART_DOOR_OPENED.
function M.classify_secret_exit_payment(saved, rule)
	if type(saved) ~= "table" then
		return "none"
	end
	local progress = tonumber(saved.progress) or 0
	local kind = saved.kind or (rule and rule.kind)
	if kind == "mausoleum_heart" then
		local flesh_opened = false
		pcall(function()
			if GameStateFlag and GameStateFlag.STATE_MOTHER_HEART_DOOR_OPENED then
				flesh_opened = Game():GetStateFlag(GameStateFlag.STATE_MOTHER_HEART_DOOR_OPENED) == true
			end
		end)
		if saved.open == true or flesh_opened or progress >= 2 then
			return "fully_open"
		end
		return "unpaid"
	end
	if saved.open == true or progress >= 2 then
		return "fully_open"
	end
	local state = tonumber(saved.state) or tonumber(saved.save_state)
	if kind == "mausoleum" then
		if state == M.mausoleum_one_chain_state() then
			return "partial"
		end
		return "unpaid"
	end
	if kind == "mines" and state == M.mines_half_cracked_state() then
		return "partial"
	end
	local var_data = tonumber(saved.var_data)
	if progress == 1 or var_data == 1 then
		return "partial"
	end
	return "unpaid"
end

function M.secret_exit_payment_rank(saved, rule)
	local class = M.classify_secret_exit_payment(saved, rule)
	if class == "fully_open" then
		return 2
	end
	if class == "partial" then
		return 1
	end
	return 0
end

--- Consistency after spawn/restore. Forbidden: IsOpen∧IsLocked∧KeyClosed.
--- Mines partial: require State=HALF_CRACKED, not open, Extra Damaged (not generic closed-locked success).
function M.evaluate_secret_exit_restore_consistency(snap, want_class, saved)
	want_class = want_class or M.classify_secret_exit_payment(saved)
	local result = {
		ok = false,
		want_class = want_class,
		reason = "unknown",
		open = snap and snap.open,
		locked = snap and snap.locked,
		state = snap and snap.state,
		previous_state = snap and snap.previous_state,
		var_data = snap and snap.var_data,
		main_animation = snap and snap.main_animation,
		extra_animation = snap and snap.extra_animation,
		extra_visible = snap and snap.extra_visible,
		save_variant = snap and snap.save_variant,
	}
	if not snap then
		result.reason = "door_missing"
		return result
	end
	local anim = tostring(snap.main_animation or "")
	local closed_look = anim == "KeyClosed" or anim == "Closed" or anim == "Close"
	if snap.open == true and snap.locked == true then
		result.reason = "open_but_locked"
		if closed_look then
			result.reason = "open_locked_closed_sprite"
		end
		return result
	end
	if want_class == "fully_open" then
		if snap.open ~= true then
			result.reason = "expected_open"
			return result
		end
		if snap.locked == true then
			result.reason = "expected_unlocked"
			return result
		end
		if closed_look then
			result.reason = "open_but_closed_sprite"
			return result
		end
		result.ok = true
		result.reason = "fully_open_ok"
		return result
	end
	if want_class == "partial" then
		local kind = saved and saved.kind
		if kind == "mines" then
			local half = M.mines_half_cracked_state()
			if snap.open == true and snap.locked ~= true and not closed_look then
				result.ok = true
				result.reason = "partial_advanced_to_open"
				return result
			end
			if snap.open == true then
				result.reason = "mines_partial_unexpected_open"
				return result
			end
			if tonumber(snap.state) ~= half then
				result.reason = "mines_expected_half_cracked_state"
				return result
			end
			local extra_anim = tostring(snap.extra_animation or "")
			if extra_anim ~= "Damaged" then
				result.reason = "mines_expected_damaged_extra"
				return result
			end
			result.ok = true
			result.reason = "mines_partial_ok"
			return result
		end
		if kind == "mausoleum" then
			local one = M.mausoleum_one_chain_state()
			if snap.open == true and snap.locked ~= true and not closed_look then
				result.ok = true
				result.reason = "partial_advanced_to_open"
				return result
			end
			if snap.open == true then
				result.reason = "mausoleum_partial_unexpected_open"
				return result
			end
			if tonumber(snap.state) ~= one then
				result.reason = "mausoleum_expected_one_chain_state"
				return result
			end
			local save_st = tonumber(snap.save_state)
			if save_st ~= nil and save_st ~= one then
				result.reason = "mausoleum_expected_save_state_one_chain"
				return result
			end
			if tonumber(snap.var_data) ~= 0 then
				result.reason = "mausoleum_expected_vardata_0"
				return result
			end
			if anim ~= "Feed" then
				result.reason = "mausoleum_expected_feed"
				return result
			end
			if closed_look then
				result.reason = "mausoleum_still_keyclosed"
				return result
			end
			result.ok = true
			result.reason = "mausoleum_partial_ok"
			return result
		end
		if snap.open == true and snap.locked ~= true and not closed_look then
			result.ok = true
			result.reason = "partial_advanced_to_open"
			return result
		end
		if snap.open == true and (snap.locked == true or closed_look) then
			result.reason = "partial_inconsistent_open"
			return result
		end
		result.ok = true
		result.reason = "partial_best_effort"
		return result
	end
	-- unpaid / none: closed locked KeyClosed is fine.
	if snap.open == true then
		result.reason = "expected_closed"
		return result
	end
	result.ok = true
	result.reason = "unpaid_ok"
	return result
end

function M.schedule_secret_exit_restore_verify(tag, want_class, saved)
	runtime.secret_exit_restore_verify = {
		tag = tag,
		want_class = want_class,
		saved = saved,
		frames = 1,
	}
end

function M.run_secret_exit_restore_verify_if_due(tag)
	local pending = runtime.secret_exit_restore_verify
	if not pending then
		return
	end
	pending.frames = (pending.frames or 1) - 1
	if pending.frames > 0 then
		return
	end
	runtime.secret_exit_restore_verify = nil
	local door_snap = M.snapshot_secret_exit_door_probe(pending.tag or tag or "restore_verify")
	local snap_for_eval = (door_snap and door_snap.door_present) and door_snap or nil
	local consistency = M.evaluate_secret_exit_restore_consistency(
		snap_for_eval,
		pending.want_class,
		pending.saved
	)
	-- Mines Extra / Mausoleum Feed may lag one native tick after State write + Play.
	if consistency.ok ~= true
		and (
			consistency.reason == "mines_expected_damaged_extra"
			or consistency.reason == "mausoleum_expected_feed"
		)
		and not pending.retried
	then
		runtime.secret_exit_restore_verify = {
			tag = pending.tag,
			want_class = pending.want_class,
			saved = pending.saved,
			frames = 1,
			retried = true,
		}
		M.notify_secret_exit_door_observer("restore_consistency_retry", {
			tag = pending.tag or tag,
			door = door_snap,
			saved = pending.saved,
			want_class = pending.want_class,
			consistency = consistency,
			note = "visual lag; retry next frame",
			spawn_meta = M.secret_exit_spawn_meta(),
		})
		return
	end
	runtime.secret_exit_restore_consistency = consistency
	if consistency.ok == true then
		M.clear_secret_exit_persist_hold("restore_consistency_ok")
	end
	M.notify_secret_exit_door_observer("restore_consistency", {
		tag = pending.tag or tag,
		door = door_snap,
		saved = pending.saved,
		want_class = pending.want_class,
		consistency = consistency,
		persist_hold = runtime.secret_exit_persist_hold == true,
		note = consistency.ok and "restore_consistency_ok" or ("restore_failed:" .. tostring(consistency.reason)),
		spawn_meta = M.secret_exit_spawn_meta(),
	})
end

--- door_mines.anm2 Break ends with Door2 Visible=false; Close/6 keeps Door2 visible.
--- Half-cracked display needs Door2 hidden once — do not PlayAnimation / write PreviousState.
function M.sync_mines_half_cracked_door2_layer(door)
	local meta = {
		ok = false,
		skipped = false,
		reason = "no_main",
		before_visible = nil,
		after_visible = nil,
		layer_id = 2,
		layer_name = "Door2",
	}
	if not door then
		return meta
	end
	local is_open = false
	pcall(function()
		is_open = door:IsOpen() == true
	end)
	if is_open then
		meta.ok = true
		meta.skipped = true
		meta.reason = "door_open_skip_door2"
		return meta
	end
	local main = nil
	pcall(function()
		main = door:GetSprite()
	end)
	if not main or not main.GetLayer then
		meta.reason = "no_get_layer"
		return meta
	end
	local layer = nil
	pcall(function()
		layer = main:GetLayer("Door2")
	end)
	if not layer then
		pcall(function()
			layer = main:GetLayer(2)
		end)
	end
	if not layer or not layer.SetVisible then
		meta.reason = "no_door2_layer"
		return meta
	end
	pcall(function()
		if layer.IsVisible then
			meta.before_visible = layer:IsVisible()
		end
	end)
	if meta.before_visible == false then
		meta.ok = true
		meta.skipped = true
		meta.reason = "already_hidden"
		meta.after_visible = false
		return meta
	end
	pcall(function()
		layer:SetVisible(false)
	end)
	pcall(function()
		if layer.IsVisible then
			meta.after_visible = layer:IsVisible()
		else
			meta.after_visible = false
		end
	end)
	meta.ok = meta.after_visible == false
	meta.reason = meta.ok and "door2_hidden" or "door2_hide_failed"
	return meta
end

--- door_mines_planks.anm2: Idle/Damaged are both FrameNum=1 static crops (Damaged=XCrop 64).
--- Appear is the 12-frame fade; never Play Appear on restore. Stable damage = SetFrame("Damaged", 0).
function M.sync_mines_half_cracked_extra_sprite(door)
	local meta = {
		ok = false,
		skipped = false,
		reason = "no_extra",
		before_anim = nil,
		after_anim = nil,
		filename = nil,
		applied = nil,
	}
	if not door then
		return meta
	end
	-- Never touch Extra once the door is fully open.
	local is_open = false
	pcall(function()
		is_open = door:IsOpen() == true
	end)
	if is_open then
		meta.reason = "door_open_skip_visual"
		meta.skipped = true
		meta.ok = true
		return meta
	end
	local extra = nil
	pcall(function()
		extra = door.GetExtraSprite and door:GetExtraSprite() or door.ExtraSprite
	end)
	if not extra then
		return meta
	end
	pcall(function()
		if extra.GetFilename then
			meta.filename = extra:GetFilename()
		end
	end)
	pcall(function()
		if extra.GetAnimation then
			meta.before_anim = extra:GetAnimation()
		end
	end)
	if meta.before_anim == "Damaged" then
		meta.ok = true
		meta.skipped = true
		meta.reason = "already_damaged"
		meta.after_anim = "Damaged"
		return meta
	end
	-- One-shot stable pose only (Damaged is a single frame). Not in tick.
	local set_ok = false
	pcall(function()
		if extra.SetFrame then
			extra:SetFrame("Damaged", 0)
			set_ok = true
			meta.applied = "setframe_damaged_0"
		elseif extra.Play then
			extra:Play("Damaged", true)
			set_ok = true
			meta.applied = "play_damaged"
		end
	end)
	pcall(function()
		door.ExtraVisible = true
	end)
	pcall(function()
		if extra.GetAnimation then
			meta.after_anim = extra:GetAnimation()
		end
	end)
	meta.ok = set_ok and meta.after_anim == "Damaged"
	meta.reason = meta.ok and "visual_synced" or "visual_sync_failed"
	return meta
end

--- Mines half-cracked: State/Desc for payment + one-shot ExtraSprite Damaged pose for display.
function M.apply_mines_half_cracked_restore(door, saved)
	local half = M.mines_half_cracked_state()
	local wrote_desc = false
	local wrote_state = false
	pcall(function()
		local desc = door.GetSaveState and door:GetSaveState() or nil
		if desc then
			desc.State = half
			wrote_desc = true
		end
	end)
	pcall(function()
		door.State = half
		wrote_state = true
	end)
	pcall(function()
		if saved and saved.extra_visible ~= nil then
			door.ExtraVisible = saved.extra_visible == true
		else
			door.ExtraVisible = true
		end
	end)
	pcall(function()
		if saved and saved.var_data ~= nil then
			door.VarData = saved.var_data
		end
	end)
	-- Logic State alone does not switch Extra Idle→Damaged; sync stable pose once.
	local visual = M.sync_mines_half_cracked_extra_sprite(door)
	-- Main Close/6 matches logs; half-cracked look needs Door2 layer hidden (Break end pose).
	local door2 = M.sync_mines_half_cracked_door2_layer(door)
	return {
		applied = "mines_half_cracked_state",
		half_state = half,
		wrote_desc = wrote_desc,
		wrote_state = wrote_state,
		visual = visual,
		door2 = door2,
	}
end

--- Mausoleum one-pay: State=ONE_CHAIN / VarData=0 + one-shot main Feed (FrameNum 18, frames 0–17).
--- Visual only — do not Open/SetLocked/TryUnlock (must not re-charge payment).
function M.apply_mausoleum_one_chain_restore(door, saved)
	local one = M.mausoleum_one_chain_state()
	local wrote_desc = false
	local wrote_state = false
	local feed = {
		ok = false,
		before_anim = nil,
		after_anim = nil,
		applied = nil,
	}
	pcall(function()
		local desc = door.GetSaveState and door:GetSaveState() or nil
		if desc then
			desc.State = one
			wrote_desc = true
		end
	end)
	pcall(function()
		door.State = one
		wrote_state = true
	end)
	pcall(function()
		door.VarData = (saved and saved.var_data ~= nil) and saved.var_data or 0
	end)
	pcall(function()
		local main = door:GetSprite()
		if not main then
			return
		end
		if main.GetAnimation then
			feed.before_anim = main:GetAnimation()
		end
		-- door_mausoleum.anm2 Feed = 18 frames; Play from 0 each revisit (no payment side effects).
		if main.Play then
			main:Play("Feed", true)
			feed.applied = "play_feed"
		elseif main.SetFrame then
			main:SetFrame("Feed", 0)
			feed.applied = "setframe_feed_0"
		end
		if main.GetAnimation then
			feed.after_anim = main:GetAnimation()
		end
		feed.ok = feed.after_anim == "Feed"
	end)
	return {
		applied = "mausoleum_one_chain_state",
		one_chain_state = one,
		wrote_desc = wrote_desc,
		wrote_state = wrote_state,
		feed = feed,
	}
end

function M.tick_secret_exit_door(tag)
	if not runtime.corridor_active then
		return
	end
	M.run_secret_exit_restore_verify_if_due(tag)
	local rule = M.resolve_secret_exit_rule()
	if not rule or rule.eligible ~= true then
		return
	end
	local room = Game():GetRoom()
	local door, slot = M.find_secret_exit_door(room)
	if not door then
		return
	end
	local snap = snapshot_special_door(door)
	if not snap then
		return
	end
	local progress = snap.progress
	-- Mines board damage: State=HALF_CRACKED. Mausoleum one-pay: State=ONE_CHAIN.
	-- Mausoleum Heart flesh door: open → 2, else 0 (no Feed/VarData partial).
	if rule.kind == "mines" and tonumber(snap.state) == M.mines_half_cracked_state() then
		if (tonumber(progress) or 0) < 1 then
			progress = 1
		end
	elseif rule.kind == "mausoleum_heart" then
		progress = (snap.open == true) and 2 or 0
	elseif rule.kind == "mausoleum" and tonumber(snap.state) == M.mausoleum_one_chain_state() then
		if (tonumber(progress) or 0) < 1 then
			progress = 1
		end
	elseif rule.kind == "mausoleum" then
		-- Unpaid mausoleum often has VarData=1; keep progress 0 unless ONE_CHAIN/open.
		if snap.open ~= true and tonumber(snap.state) ~= M.mausoleum_one_chain_state() then
			progress = 0
		end
	end
	-- Persist payment-stable fields only (not transitional Extra frames).
	local payload = {
		kind = rule.kind,
		slot = slot,
		progress = progress,
		progress_inferred = true,
		open = snap.open,
		locked = snap.locked,
		busted = snap.busted,
		state = snap.state,
		var_data = snap.var_data,
		extra_visible = snap.extra_visible,
		extra_animation = snap.extra_animation,
		save_state = snap.save_state,
		save_var_data = snap.save_var_data,
		variant = snap.variant,
	}
	-- Hold: spawn→restore→verify must finish before live State=1 can overwrite saved damage.
	if runtime.secret_exit_persist_hold then
		local floor_hold = compass_state.get_floor_persist() or {}
		local saved_hold = floor_hold.secret_exit_door
		local saved_rank = M.secret_exit_payment_rank(saved_hold, rule)
		local live_rank = M.secret_exit_payment_rank(payload, rule)
		-- Allow catch-up only when live is at least as paid and no verify pending.
		if live_rank >= saved_rank
			and live_rank > 0
			and not runtime.secret_exit_restore_verify
		then
			M.clear_secret_exit_persist_hold("live_caught_up")
		else
			M.notify_secret_exit_door_observer("persist_hold", {
				tag = tag,
				door = M.snapshot_secret_exit_door_probe(tag),
				live = payload,
				saved_rank = saved_rank,
				live_rank = live_rank,
				reason = runtime.secret_exit_persist_hold_reason,
				spawn_meta = M.secret_exit_spawn_meta(),
				note = "persist_hold: not writing live door over saved payment",
			})
			return
		end
	end
	local prev = runtime.secret_exit_door_snap
	local payment_changed = not prev
		or prev.progress ~= payload.progress
		or prev.open ~= payload.open
		or prev.var_data ~= payload.var_data
		or prev.state ~= payload.state
		or prev.extra_visible ~= payload.extra_visible
	if payment_changed then
		runtime.secret_exit_door_snap = payload
		compass_state.set_floor_persist({secret_exit_door = payload})
		-- Door frame/sprite churn belongs to golden_compass_door_probe, not corridor events.
		M.notify_secret_exit_door_observer("payment_changed", {
			tag = tag,
			door = M.snapshot_secret_exit_door_probe(tag),
			spawn_meta = M.secret_exit_spawn_meta(),
		})
	end
end

function M.restore_secret_exit_door(tag)
	if not runtime.corridor_active then
		return
	end
	local floor = compass_state.get_floor_persist() or {}
	local saved = floor.secret_exit_door
	if type(saved) ~= "table" then
		return
	end
	local rule = M.resolve_secret_exit_rule()
	if not rule or rule.eligible ~= true then
		return
	end
	-- Keep kind on saved so classify/consistency stay mines-scoped across Continue.
	if saved.kind == nil and rule.kind ~= nil then
		saved.kind = rule.kind
	end
	local room = Game():GetRoom()
	local door = M.find_secret_exit_door(room)
	if not door then
		return
	end
	local want_class = M.classify_secret_exit_payment(saved, rule)
	local before = snapshot_special_door(door)
	M.notify_secret_exit_door_observer("before_restore", {
		tag = tag,
		door = M.snapshot_secret_exit_door_probe(tag),
		saved = saved,
		want_class = want_class,
		spawn_meta = M.secret_exit_spawn_meta(),
	})
	-- Native already matches desired payment class: leave alone.
	local already = M.evaluate_secret_exit_restore_consistency(before, want_class, saved)
	if already.ok == true and want_class == "fully_open" and before and before.open == true and before.locked ~= true then
		runtime.secret_exit_door_snap = saved
		runtime.secret_exit_restore_consistency = already
		M.clear_secret_exit_persist_hold("already_fully_open")
		M.notify_secret_exit_door_observer("restore_skipped", {
			tag = tag,
			door = M.snapshot_secret_exit_door_probe(tag),
			saved = saved,
			want_class = want_class,
			consistency = already,
			note = "native_already_matches",
			spawn_meta = M.secret_exit_spawn_meta(),
		})
		return
	end
	if already.ok == true and want_class == "partial"
		and (already.reason == "mines_partial_ok" or already.reason == "mausoleum_partial_ok")
	then
		runtime.secret_exit_door_snap = saved
		runtime.secret_exit_restore_consistency = already
		M.clear_secret_exit_persist_hold("already_partial")
		M.notify_secret_exit_door_observer("restore_skipped", {
			tag = tag,
			door = M.snapshot_secret_exit_door_probe(tag),
			saved = saved,
			want_class = want_class,
			consistency = already,
			note = "native_already_" .. tostring(already.reason),
			spawn_meta = M.secret_exit_spawn_meta(),
		})
		return
	end
	if already.ok == true and want_class == "unpaid" then
		runtime.secret_exit_door_snap = saved
		runtime.secret_exit_restore_consistency = already
		M.clear_secret_exit_persist_hold("already_unpaid")
		M.notify_secret_exit_door_observer("restore_skipped", {
			tag = tag,
			door = M.snapshot_secret_exit_door_probe(tag),
			saved = saved,
			want_class = want_class,
			consistency = already,
			note = "native_already_unpaid",
			spawn_meta = M.secret_exit_spawn_meta(),
		})
		return
	end

	local applied = "none"
	local mines_meta = nil
	local mausoleum_meta = nil
	if want_class == "fully_open" then
		-- Downpour/etc fully open: SetLocked + Open only (no State write).
		applied = "native_open"
		M.begin_secret_exit_persist_hold("restore_fully_open")
		pcall(function()
			if door.SetLocked and door:IsLocked() then
				door:SetLocked(false)
			end
		end)
		pcall(function()
			door:Open()
		end)
		pcall(function()
			if door:IsLocked() then
				door:SetLocked(false)
				door:Open()
			end
		end)
	elseif want_class == "partial" then
		local kind = saved.kind or rule.kind
		local half = M.mines_half_cracked_state()
		local one = M.mausoleum_one_chain_state()
		if kind == "mausoleum_heart" then
			-- Door_MomsHeart has no key-door Feed/ONE_CHAIN stage.
			applied = "mausoleum_heart_no_partial"
			M.clear_secret_exit_persist_hold("mausoleum_heart_no_partial")
		elseif kind == "mines" and tonumber(saved.state) == half then
			M.begin_secret_exit_persist_hold("restore_mines_partial")
			mines_meta = M.apply_mines_half_cracked_restore(door, saved)
			applied = mines_meta.applied
		elseif kind == "mausoleum" and tonumber(saved.state) == one then
			M.begin_secret_exit_persist_hold("restore_mausoleum_partial")
			mausoleum_meta = M.apply_mausoleum_one_chain_restore(door, saved)
			applied = mausoleum_meta.applied
		else
			applied = "partial_vardata_only"
			M.begin_secret_exit_persist_hold("restore_partial_vardata")
			pcall(function()
				if saved.var_data ~= nil then
					door.VarData = saved.var_data
				end
			end)
		end
	else
		applied = "unpaid_leave"
		M.clear_secret_exit_persist_hold("unpaid_leave")
	end

	local after = snapshot_special_door(door)
	local immediate = M.evaluate_secret_exit_restore_consistency(after, want_class, saved)
	-- Persist corrected progress for mausoleum ONE_CHAIN so Continue keeps partial rank.
	if want_class == "partial" and (saved.kind or rule.kind) == "mausoleum" then
		saved.progress = 1
		saved.var_data = 0
		saved.state = M.mausoleum_one_chain_state()
		saved.save_state = saved.state
		saved.open = false
		compass_state.set_floor_persist({secret_exit_door = saved})
	end
	runtime.secret_exit_door_snap = saved
	runtime.secret_exit_restore_skipped_tag = nil
	runtime.secret_exit_restore_consistency = immediate
	if want_class == "partial" or want_class == "fully_open" then
		M.schedule_secret_exit_restore_verify(tag, want_class, saved)
	end
	M.notify_secret_exit_door_observer("after_restore", {
		tag = tag,
		door = M.snapshot_secret_exit_door_probe(tag),
		saved = saved,
		before = before,
		after = after,
		want_class = want_class,
		applied = applied,
		mines_meta = mines_meta,
		mausoleum_meta = mausoleum_meta,
		consistency = immediate,
		persist_hold = runtime.secret_exit_persist_hold == true,
		note = "class=" .. want_class .. " via=" .. applied,
		spawn_meta = M.secret_exit_spawn_meta(),
	})
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

function M.try_spawn_boss_secret_exit(tag)
	local room = Game():GetRoom()
	if is_knife_puzzle_dimension() then
		local removed = M.remove_secret_exit_doors(room, tag)
		local row = {
			tag = tag,
			ok = true,
			skipped = true,
			spawned = false,
			removed = removed,
			reason = "mirror_dimension",
			note = "knife dim Boss@89: forbid secret-exit branch door",
		}
		runtime.secret_exit_spawn = row
		push_event("boss_89_secret_exit", row)
		return row
	end
	local rule = M.resolve_secret_exit_rule()
	if not rule or rule.eligible ~= true then
		local removed = M.remove_secret_exit_doors(room, tag)
		local row = {
			tag = tag,
			ok = true,
			skipped = true,
			spawned = false,
			removed = removed,
			rule = rule,
			note = "chapter ineligible for secret exit; doors cleared",
		}
		runtime.secret_exit_spawn = row
		push_event("boss_89_secret_exit", row)
		return row
	end
	-- Corpse II Mother: 89 is SPECIAL_ROOMS 6000 gate; do not forge TrySpawnSecretExit over vanilla Mother door.
	if rule.kind == "mother_arena" then
		local secret_snap = snapshot_neg_desc(SECRET_EXIT_IDX)
		local mother_ok = corridor_plan_mod.is_mother_arena_target_cfg
			and corridor_plan_mod.is_mother_arena_target_cfg(secret_snap)
		local row = {
			tag = tag,
			ok = mother_ok == true,
			skipped = true,
			spawned = false,
			rule = rule,
			secret_desc = secret_snap,
			note = mother_ok
				and "mother_arena: keep vanilla Mother gate door; -10 Corpse/1 ready"
				or "mother_arena: -10 is not Mother arena; refuse TrySpawnSecretExit",
		}
		runtime.secret_exit_spawn = row
		push_event("boss_89_secret_exit", row)
		return row
	end
	local present, present_slot = M.room_has_secret_exit_door(room)
	if present then
		runtime.secret_exit_attempted_this_visit = true
		runtime.secret_exit_confirmed_slot = present_slot
		local row = {
			tag = tag,
			ok = true,
			spawned = true,
			already_present = true,
			slot = present_slot,
			rule = rule,
			note = "live door → -10 present; no TrySpawnSecretExit",
		}
		local prev = runtime.secret_exit_spawn
		runtime.secret_exit_spawn = row
		if not (prev and prev.ok and prev.slot == present_slot and prev.already_present) then
			push_event("boss_89_secret_exit", row)
		end
		return row
	end
	-- Stay in Boss room: never re-call TrySpawnSecretExit after the first attempt this visit.
	if runtime.secret_exit_attempted_this_visit then
		local row = {
			tag = tag,
			ok = true,
			skipped = true,
			spawned = false,
			live_present = false,
			rule = rule,
			attempts = runtime.secret_exit_spawn_attempts,
			note = "secret exit spawn already attempted this visit; not re-calling TrySpawnSecretExit",
		}
		local prev = runtime.secret_exit_spawn
		runtime.secret_exit_spawn = row
		if not (prev and prev.skipped and prev.note == row.note) then
			push_event("boss_89_secret_exit", row)
		end
		return row
	end
	runtime.secret_exit_attempted_this_visit = true
	runtime.secret_exit_spawn_attempts = (runtime.secret_exit_spawn_attempts or 0) + 1
	-- Mausoleum Heart: require verified Mom's Heart -10, then same Soft→Force as other chapters.
	if rule.kind == "mausoleum_heart" then
		local secret_snap = snapshot_neg_desc(SECRET_EXIT_IDX)
		local heart_ok = corridor_plan_mod.is_mausoleum_heart_target_cfg
			and corridor_plan_mod.is_mausoleum_heart_target_cfg(secret_snap)
		if not heart_ok then
			local row = {
				tag = tag,
				ok = false,
				skipped = true,
				spawned = false,
				rule = rule,
				secret_desc = secret_snap,
				note = "mausoleum_heart: -10 is not Mom's Heart (mausoleum); refuse TrySpawnSecretExit / Beast Room",
			}
			runtime.secret_exit_spawn = row
			push_event("boss_89_secret_exit", row)
			compass_floor.snapshot_witness_route(tag .. ":skip_invalid_neg10")
			return row
		end
	end
	local before = snapshot_neg_desc(SECRET_EXIT_IDX)
	M.notify_secret_exit_door_observer("before_try_spawn", {
		tag = tag,
		door = M.snapshot_secret_exit_door_probe(tag),
		spawn_meta = M.secret_exit_spawn_meta(),
		note = "before TrySpawnSecretExit soft→force, animate=false",
	})
	-- Soft first; Force only if the live door is still missing. Never animate (no smoke).
	-- Force=true only forces spawn attempt; does not unlock/open payment.
	local spawned, err, animate = M.call_try_spawn_secret_exit(room, false)
	local force_used = false
	local after_present, after_slot = M.room_has_secret_exit_door(room)
	if not after_present then
		force_used = true
		local spawned2, err2
		spawned2, err2, animate = M.call_try_spawn_secret_exit(room, true)
		spawned = spawned or spawned2
		err = err2 or err
		after_present, after_slot = M.room_has_secret_exit_door(room)
	end
	local after = snapshot_neg_desc(SECRET_EXIT_IDX)
	if after_present then
		runtime.secret_exit_confirmed_slot = after_slot
	end
	-- Fresh spawn replaces any live door: hold persist until restore/verify if saved payment exists.
	if after_present then
		local floor = compass_state.get_floor_persist() or {}
		local saved = floor.secret_exit_door
		if M.secret_exit_payment_rank(saved, rule) > 0 then
			M.begin_secret_exit_persist_hold("spawn_await_restore")
		end
	end
	local row = {
		tag = tag,
		ok = after_present == true,
		spawned = spawned,
		live_present = after_present == true,
		slot = after_slot,
		animate = animate == true,
		force = force_used,
		force_fallback = force_used,
		attempts = runtime.secret_exit_spawn_attempts,
		persist_hold = runtime.secret_exit_persist_hold == true,
		error = err,
		before = before,
		after = after,
		rule = rule,
		api = "TrySpawnSecretExit",
		note = (rule.kind == "mausoleum_heart")
			and (force_used
				and "mausoleum_heart: soft miss → TrySpawnSecretExit(Force); Door_MomsHeart presence checked"
				or "mausoleum_heart: TrySpawnSecretExit(soft) ok; presence checked")
			or (force_used
				and "Boss clear/reenter: soft miss → TrySpawnSecretExit(false,true); presence checked"
				or "Boss clear/reenter: TrySpawnSecretExit(false,false) ok; no animate"),
	}
	runtime.secret_exit_spawn = row
	push_event("boss_89_secret_exit", row)
	M.notify_secret_exit_door_observer("after_try_spawn", {
		tag = tag,
		door = M.snapshot_secret_exit_door_probe(tag),
		spawn_meta = M.secret_exit_spawn_meta(),
		note = row.note,
	})
	return row
end

function M.install(inject)
	deps = inject
	runtime = inject.runtime
	cfg = inject.cfg
	compass_floor = inject.compass_floor
	compass_state = inject.compass_state
	corridor_plan_mod = inject.corridor_plan
	read_level_identity = inject.read_level_identity
	push_event = inject.push_event
	SECRET_EXIT_IDX = inject.secret_exit_idx or SECRET_EXIT_IDX
	snapshot_neg_desc = inject.snapshot_neg_desc
	snapshot_special_door = inject.snapshot_special_door
	local cf = inject.compass_floor
	cf.apply_mausoleum_one_chain_restore = M.apply_mausoleum_one_chain_restore
	cf.apply_mines_half_cracked_restore = M.apply_mines_half_cracked_restore
	cf.begin_secret_exit_persist_hold = M.begin_secret_exit_persist_hold
	cf.call_try_spawn_secret_exit = M.call_try_spawn_secret_exit
	cf.classify_secret_exit_payment = M.classify_secret_exit_payment
	cf.clear_secret_exit_persist_hold = M.clear_secret_exit_persist_hold
	cf.evaluate_secret_exit_restore_consistency = M.evaluate_secret_exit_restore_consistency
	cf.find_secret_exit_door = M.find_secret_exit_door
	cf.mausoleum_one_chain_state = M.mausoleum_one_chain_state
	cf.mines_half_cracked_state = M.mines_half_cracked_state
	cf.notify_secret_exit_door_observer = M.notify_secret_exit_door_observer
	cf.remove_secret_exit_doors = M.remove_secret_exit_doors
	cf.resolve_secret_exit_rule = M.resolve_secret_exit_rule
	cf.restore_secret_exit_door = M.restore_secret_exit_door
	cf.room_has_secret_exit_door = M.room_has_secret_exit_door
	cf.run_secret_exit_restore_verify_if_due = M.run_secret_exit_restore_verify_if_due
	cf.schedule_secret_exit_restore_verify = M.schedule_secret_exit_restore_verify
	cf.secret_exit_payment_rank = M.secret_exit_payment_rank
	cf.secret_exit_spawn_meta = M.secret_exit_spawn_meta
	cf.snapshot_secret_exit_door_probe = M.snapshot_secret_exit_door_probe
	cf.sync_mines_half_cracked_door2_layer = M.sync_mines_half_cracked_door2_layer
	cf.sync_mines_half_cracked_extra_sprite = M.sync_mines_half_cracked_extra_sprite
	cf.tick_secret_exit_door = M.tick_secret_exit_door
	cf.try_spawn_boss_secret_exit = M.try_spawn_boss_secret_exit
	return M
end

return M
