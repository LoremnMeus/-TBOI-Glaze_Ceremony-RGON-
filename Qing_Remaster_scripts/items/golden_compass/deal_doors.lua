-- Golden Compass: Boss@89 ↔ Deal@90 door styling / Mom virtual door.
-- No own MC_* callbacks.

local M = {}

local runtime
local push_event
local compass_state
local BOSS_ROOM_SGID
local DEAL_ROOM_SGID
local grid_door
local snapshot_live_door
local Room_holder
local game_frame
local BOSS_TYPE_MOM

--- Prefer persisted floor deal_type for an active corridor; log live conflicts.
--- Never treat ROOM_DEVIL fallback as a fresh decision when persist already chose.
local function resolve_deal_type()
	local function is_deal(t)
		return t == RoomType.ROOM_DEVIL or t == RoomType.ROOM_ANGEL
	end
	local floor = compass_state.get_floor_persist() or {}
	local persisted = runtime.corridor_deal_type or floor.deal_type
	if not is_deal(persisted) then
		persisted = nil
	end
	local level = Game():GetLevel()
	local desc = nil
	pcall(function()
		desc = level:GetRoomByIdx(DEAL_ROOM_SGID, 0)
	end)
	local live = desc and desc.Data and desc.Data.Type
	if not is_deal(live) then
		live = nil
	end
	if persisted and live and persisted ~= live then
		push_event("deal_type_conflict", {
			persisted = persisted,
			live_desc = live,
			source = "prefer_persist",
			note = "floor.deal_type wins over RoomDesc for active corridor",
		})
		runtime.corridor_deal_type = persisted
		runtime.deal_type_source = "persist_over_live"
		return persisted
	end
	if live then
		runtime.corridor_deal_type = live
		runtime.deal_type_source = "live_desc"
		return live
	end
	if persisted then
		runtime.deal_type_source = "persist"
		return persisted
	end
	local pending = runtime.pending
	local choice = pending and pending.deal_room_choice
	if choice and is_deal(choice.room_type) then
		runtime.corridor_deal_type = choice.room_type
		runtime.deal_type_source = "pending_choice"
		return choice.room_type
	end
	runtime.deal_type_source = "fallback_devil"
	return RoomType.ROOM_DEVIL
end

local function deal_door_anm2(deal_type)
	if deal_type == RoomType.ROOM_ANGEL then
		return "gfx/grid/door_07_holyroomdoor.anm2"
	end
	return "gfx/grid/door_07_devilroomdoor.anm2"
end

local function read_door_sprite_snap(door)
	local snap = {
		is_open = nil,
		filename = nil,
		animation = nil,
		frame = nil,
		open_animation = nil,
		close_animation = nil,
	}
	if not door then
		return snap
	end
	pcall(function()
		snap.is_open = door:IsOpen()
	end)
	pcall(function()
		local spr = door:GetSprite()
		if not spr then
			return
		end
		if spr.GetFilename then
			snap.filename = spr:GetFilename()
		end
		if spr.GetAnimation then
			snap.animation = spr:GetAnimation()
		end
		if spr.GetFrame then
			snap.frame = spr:GetFrame()
		end
	end)
	pcall(function()
		snap.open_animation = door.OpenAnimation
	end)
	pcall(function()
		snap.close_animation = door.CloseAnimation
	end)
	return snap
end

local function ensure_open_sprite_pose(door)
	local fixed = false
	local before = nil
	local after = nil
	pcall(function()
		local spr = door:GetSprite()
		if not spr or not spr.GetAnimation then
			return
		end
		before = spr:GetAnimation()
		local anim = before
		if anim == "Closed" or anim == "Close" or anim == "KeyClosed" then
			if spr.Play then
				spr:Play("Opened", true)
				fixed = true
			end
		end
		after = spr:GetAnimation()
	end)
	return {fixed = fixed, before = before, after = after}
end

local function arm_deal_door_sprite_watch(tag, slot)
	runtime.deal_door_sprite_watch = {
		tag = tag,
		slot = slot,
		sgid = BOSS_ROOM_SGID,
		start_frame = game_frame(),
		offsets = {1, 5, 15},
		emitted = {},
	}
end

local function tick_deal_door_sprite_watch()
	local watch = runtime.deal_door_sprite_watch
	if not watch or not runtime.corridor_active then
		return
	end
	local now = game_frame()
	if now == nil or watch.start_frame == nil then
		return
	end
	local level = Game():GetLevel()
	local cur = level:GetCurrentRoomDesc()
	if not cur or cur.SafeGridIndex ~= watch.sgid then
		return
	end
	local room = Game():GetRoom()
	local door = nil
	pcall(function()
		door = room:GetDoor(watch.slot)
	end)
	local elapsed = now - watch.start_frame
	for _, off in ipairs(watch.offsets) do
		if elapsed >= off and not watch.emitted[off] then
			watch.emitted[off] = true
			local snap = read_door_sprite_snap(door)
			local pose_fix = nil
			if door and snap.is_open == true then
				local anim = snap.animation
				if anim == "Closed" or anim == "Close" or anim == "KeyClosed" then
					pose_fix = ensure_open_sprite_pose(door)
					snap = read_door_sprite_snap(door)
				end
			end
			push_event("boss_89_deal_door_sprite", {
				tag = watch.tag,
				offset_frames = off,
				elapsed = elapsed,
				present = door ~= nil,
				sprite = snap,
				pose_fix = pose_fix,
				note = "sample after restyle; fix sprite pose only if IsOpen but Closed anim",
			})
		end
	end
	local all = true
	for _, off in ipairs(watch.offsets) do
		if not watch.emitted[off] then
			all = false
			break
		end
	end
	if all then
		runtime.deal_door_sprite_watch = nil
	end
end

local function deal_door_state_key(row)
	if not row then
		return ""
	end
	return string.format(
		"%s|%s|%s|%s|%s|%s|%s|%s",
		tostring(row.sgid),
		tostring(row.slot),
		tostring(row.phase),
		tostring(row.present),
		tostring(row.current_room_type),
		tostring(row.target_room_type),
		tostring(row.open_after),
		tostring(row.ok)
	)
end

--- Boss@89 deal-entry appear SFX: tied to post-combat door visibility, not Open() call.
--- Requires this visit saw combat; re-enter already-cleared room stays silent.
local function try_play_boss_89_deal_appear_sfx(deal_type, reason, door, room, opts)
	opts = opts or {}
	local was_in_combat = runtime.boss_89_visit_had_combat == true
	local room_clear = false
	pcall(function()
		room_clear = room and room:IsClear() == true
	end)
	local door_open = opts.treat_as_open == true
	if not door_open and door then
		pcall(function()
			door_open = door:IsOpen() == true
		end)
	end
	local sound = (deal_type == RoomType.ROOM_ANGEL)
		and SoundEffect.SOUND_CHOIR_UNLOCK
		or SoundEffect.SOUND_SATAN_ROOM_APPEAR
	local already = runtime.deal_appear_sfx_played == true
	if not already then
		local floor = compass_state.get_floor_persist and (compass_state.get_floor_persist() or {}) or {}
		if floor.deal_appear_sfx_played == true then
			runtime.deal_appear_sfx_played = true
			already = true
		end
	end
	local eligible = was_in_combat == true and room_clear == true and door_open == true and already ~= true
	local played = false
	if eligible then
		local ok = pcall(function()
			SFXManager():Play(sound, 1, 0, false, 1)
		end)
		played = ok == true
		if played then
			-- Persist only after a real play at the appear moment.
			runtime.deal_appear_sfx_played = true
			if compass_state.set_floor_persist then
				compass_state.set_floor_persist({deal_appear_sfx_played = true})
			end
		end
	end
	-- Log attempts that could have been the appear moment (avoid Deal@90 / sealed spam).
	if push_event and (eligible or (was_in_combat and room_clear and door_open) or opts.force_log) then
		if played or opts.force_log or runtime.deal_appear_sfx_logged ~= true then
			if played or eligible or opts.force_log then
				runtime.deal_appear_sfx_logged = true
			end
			push_event("boss_89_deal_appear_sfx", {
				deal_type = deal_type,
				sound = sound,
				reason = reason,
				room_clear = room_clear,
				door_open = door_open,
				was_in_combat = was_in_combat,
				already_played = already == true,
				eligible = eligible == true,
				played = played == true,
			})
		end
	end
	return played
end

--- open_wanted restyles/opens. Appear SFX is owned by Boss@89 clear path only (not Deal@90).
local function style_deal_door(door, deal_type, target_sgid, open_wanted)
	local set_ok, set_err = pcall(function()
		door:SetRoomTypes(RoomType.ROOM_DEFAULT, deal_type)
	end)
	if target_sgid ~= nil then
		pcall(function()
			door.TargetRoomIndex = target_sgid
		end)
	end
	pcall(function()
		if door:IsLocked() then
			door:SetLocked(false)
		end
	end)
	local open_ok, open_err = true, nil
	local already_open = false
	pcall(function()
		already_open = door:IsOpen() == true
	end)
	if open_wanted and not already_open then
		open_ok, open_err = pcall(function()
			door:Open()
		end)
	elseif (not open_wanted) and already_open then
		open_ok, open_err = pcall(function()
			door:Close(true)
		end)
	end
	-- Do not call door:PlayAnimation() after Open — it can leave sprite on Closed.
	local pose_fix = nil
	if open_wanted then
		pose_fix = ensure_open_sprite_pose(door)
	end
	local spr = read_door_sprite_snap(door)
	return {
		set_room_types_ok = set_ok == true,
		set_room_types_err = set_ok and nil or tostring(set_err),
		open_ok = open_ok == true,
		open_err = open_ok and nil or tostring(open_err),
		open_after = door:IsOpen(),
		locked_after = door:IsLocked(),
		current_room_type = door.CurrentRoomType,
		target_room_type = door.TargetRoomType,
		target_room_index = door.TargetRoomIndex,
		animation = spr.animation,
		sprite = spr,
		pose_fix = pose_fix,
		skipped_open = already_open == true,
	}
end

local function is_mom_boss_case(room)
	if runtime.corridor_force_boss == BOSS_TYPE_MOM then
		return true
	end
	local pending = runtime.pending
	if pending and tonumber(pending.force_boss_subtype) == BOSS_TYPE_MOM then
		return true
	end
	local plan = runtime.boss_90_plan
	if plan and tonumber(plan.subtype) == BOSS_TYPE_MOM then
		return true
	end
	local bid = nil
	pcall(function()
		if room and room.GetBossID then
			bid = room:GetBossID()
		end
	end)
	return tonumber(bid) == BOSS_TYPE_MOM
end

--- Mom only: simulated deal door via grid_doors virtual carrier (no GRID_DOOR spawn).
local function ensure_mom_sim_deal_door(tag, deal_type)
	if runtime.boss_89_mom_sim_door and runtime.boss_89_mom_sim_door.ok then
		-- Re-bind if still in same room and entry still listed.
		local still = false
		for _, v in ipairs(grid_door.doors or {}) do
			if v and v.virtual and v.slot == DoorSlot.RIGHT0 then
				still = true
				break
			end
		end
		if still then
			return runtime.boss_89_mom_sim_door
		end
	end
	local room = Game():GetRoom()
	local anm2 = deal_door_anm2(deal_type)
	local spawned = nil
	local err = nil
	local ok, ret = pcall(function()
		return grid_door.try_spawn_virtual_door(room, DoorSlot.RIGHT0, nil, {
			loadname = anm2,
			playname = "Opened",
			should_update = true,
			tp = RoomType.ROOM_DEFAULT,
			check_and_leave = function(_doorinfo, player)
				Room_holder.Trans_to(
					DEAL_ROOM_SGID,
					Direction.RIGHT,
					RoomTransitionAnim.WALK,
					player,
					0
				)
			end,
		})
	end)
	if ok then
		spawned = ret
	else
		err = tostring(ret)
	end
	local row = {
		tag = tag,
		ok = spawned ~= nil,
		deal_type = deal_type,
		anm2 = anm2,
		spawn_error = err,
		note = "Mom branch: virtual grid_doors sim door → Trans_to(90); no GRID_DOOR",
	}
	local prev = runtime.boss_89_mom_sim_door
	local first_ok = row.ok == true
		and not (prev and prev.ok == true)
	if first_ok then
		row.appear_sfx = try_play_boss_89_deal_appear_sfx(
			deal_type,
			"mom_sim_spawn",
			nil,
			room,
			{treat_as_open = true, force_log = true}
		)
	end
	runtime.boss_89_mom_sim_door = row
	-- Avoid event spam when re-entering the same successful sim door.
	if not (prev and prev.ok and row.ok and prev.anm2 == row.anm2 and prev.deal_type == row.deal_type) then
		push_event("boss_89_mom_sim_door", row)
	end
	return row
end

--- 89 RIGHT↔90 LEFT deal doors: re-apply every enter.
--- Combat hide via PRE_DOOR_RENDER gated by corridor_active (not pending).
local function apply_boss_deal_doors(tag)
	if not runtime.corridor_active and not (runtime.pending and runtime.pending.layout_ready) then
		return nil
	end
	-- Void Delirium 2x2: no separate deal@90 / boss↔deal door lifecycle.
	do
		local pending = runtime.pending
		local boss = pending and pending.corridor_plan and pending.corridor_plan[BOSS_ROOM_SGID]
		if boss and (boss.suppress_deal_90 or boss.boss_role == "delirium" or boss.shape_2x2) then
			return {
				tag = tag,
				skipped = true,
				reason = "delirium_2x2_no_deal_door",
				sgid = BOSS_ROOM_SGID,
			}
		end
	end
	local level = Game():GetLevel()
	local cur = level:GetCurrentRoomDesc()
	local sgid = cur and cur.SafeGridIndex
	if sgid ~= BOSS_ROOM_SGID and sgid ~= DEAL_ROOM_SGID then
		return nil
	end
	local room = Game():GetRoom()
	local deal_type = resolve_deal_type()
	local slot = (sgid == BOSS_ROOM_SGID) and DoorSlot.RIGHT0 or DoorSlot.LEFT0
	local neighbor = (sgid == BOSS_ROOM_SGID) and DEAL_ROOM_SGID or BOSS_ROOM_SGID
	local door = nil
	pcall(function()
		door = room:GetDoor(slot)
	end)
	local is_clear = room:IsClear() == true
	local mom = is_mom_boss_case(room)
	local row = {
		tag = tag,
		sgid = sgid,
		slot = slot,
		neighbor = neighbor,
		deal_type = deal_type,
		present = door ~= nil,
		is_clear = is_clear,
		mom_branch = mom,
		force_boss_subtype = runtime.corridor_force_boss
			or (runtime.pending and runtime.pending.force_boss_subtype)
			or nil,
	}

	if sgid == BOSS_ROOM_SGID and not is_clear then
		runtime.boss_89_visit_had_combat = true
		if door then
			pcall(function()
				door:Close(true)
			end)
			row.phase = "sealed"
			row.ok = true
			row.open_after = door:IsOpen()
			row.locked_after = door:IsLocked()
			row.current_room_type = door.CurrentRoomType
			row.target_room_type = door.TargetRoomType
			row.target_room_index = door.TargetRoomIndex
			row.note = "combat: Close only; PRE_DOOR_RENDER hides; corridor_active gate"
		else
			row.phase = "sealed_missing"
			row.ok = mom == true
			row.note = mom
				and "Mom combat: no native RIGHT0; sim door after clear"
				or "combat: RIGHT0 missing unexpectedly"
		end
		local prev = runtime.boss_89_deal_door
		runtime.boss_89_deal_door = row
		if deal_door_state_key(prev) ~= deal_door_state_key(row) then
			push_event("boss_89_deal_door", row)
		end
		return row
	end

	if sgid == BOSS_ROOM_SGID and not door then
		if mom then
			local sim = ensure_mom_sim_deal_door(tag, deal_type)
			row.phase = "mom_sim_door"
			row.mom_sim = sim
			row.ok = sim and sim.ok == true
			row.opened = row.ok
			row.note = "Mom clear: virtual sim deal door (no SpawnGridEntity)"
			local prev = runtime.boss_89_deal_door
			runtime.boss_89_deal_door = row
			if deal_door_state_key(prev) ~= deal_door_state_key(row) then
				push_event("boss_89_deal_door", row)
			end
			return row
		end
		row.phase = "clear_missing"
		row.ok = false
		row.opened = false
		row.note = "clear but RIGHT0 missing; non-Mom — no GRID_DOOR retry"
		runtime.boss_89_door_restore = {
			tag = tag,
			skipped = true,
			reason = "native_grid_door_restore_disabled",
		}
		local prev = runtime.boss_89_deal_door
		runtime.boss_89_deal_door = row
		if deal_door_state_key(prev) ~= deal_door_state_key(row) then
			push_event("boss_89_deal_door", row)
		end
		return row
	end

	if not door then
		row.phase = "missing"
		row.ok = false
		row.note = "deal-side door missing"
		local prev = runtime.boss_89_deal_door
		runtime.boss_89_deal_door = row
		if deal_door_state_key(prev) ~= deal_door_state_key(row) then
			push_event("boss_89_deal_door", row)
		end
		return row
	end

	-- Deal/Angel@90 uncleared: SetRoomTypes once, then native Close(true). No per-frame restyle.
	if sgid == DEAL_ROOM_SGID and not is_clear then
		if runtime.deal_90_seal_init_done then
			local spr = read_door_sprite_snap(door)
			row.phase = "deal_side_sealed_stable"
			row.ok = true
			row.opened = false
			row.open_after = door:IsOpen()
			row.locked_after = door:IsLocked()
			row.current_room_type = door.CurrentRoomType
			row.target_room_type = door.TargetRoomType
			row.target_room_index = door.TargetRoomIndex
			row.animation = spr.animation
			row.sprite = spr
			row.skipped_restyle = true
			row.note = "90 uncleared: seal already applied this visit; leave native Close anim"
			local prev = runtime.boss_89_deal_door
			runtime.boss_89_deal_door = row
			if deal_door_state_key(prev) ~= deal_door_state_key(row) then
				push_event("boss_89_deal_door", row)
			end
			return row
		end
		local set_ok, set_err = pcall(function()
			door:SetRoomTypes(RoomType.ROOM_DEFAULT, deal_type)
		end)
		local close_ok, close_err = pcall(function()
			door:Close(true)
		end)
		runtime.deal_90_seal_init_done = true
		local spr = read_door_sprite_snap(door)
		row.phase = "deal_side_sealed"
		row.ok = set_ok == true
		row.opened = false
		row.set_room_types_ok = set_ok == true
		row.set_room_types_err = set_ok and nil or tostring(set_err)
		row.open_ok = close_ok == true
		row.open_err = close_ok and nil or tostring(close_err)
		row.open_after = door:IsOpen()
		row.locked_after = door:IsLocked()
		row.current_room_type = door.CurrentRoomType
		row.target_room_type = door.TargetRoomType
		row.target_room_index = door.TargetRoomIndex
		row.animation = spr.animation
		row.sprite = spr
		row.note = "90 uncleared: SetRoomTypes then native Close(true) once"
		local prev = runtime.boss_89_deal_door
		runtime.boss_89_deal_door = row
		if deal_door_state_key(prev) ~= deal_door_state_key(row) then
			push_event("boss_89_deal_door", row)
		end
		return row
	end

	-- Already correct + open: do NOT SetRoomTypes/Open again (replays open anim every frame).
	local stable = false
	pcall(function()
		if door:IsOpen() ~= true then
			return
		end
		if door.CurrentRoomType ~= RoomType.ROOM_DEFAULT then
			return
		end
		if door.TargetRoomType ~= deal_type then
			return
		end
		if sgid == BOSS_ROOM_SGID and door.TargetRoomIndex ~= DEAL_ROOM_SGID then
			return
		end
		stable = true
	end)
	if stable then
		local spr = read_door_sprite_snap(door)
		row.phase = (sgid == BOSS_ROOM_SGID) and "opened_stable" or "deal_side_stable"
		row.ok = true
		row.opened = true
		row.open_after = true
		row.locked_after = door:IsLocked()
		row.current_room_type = door.CurrentRoomType
		row.target_room_type = door.TargetRoomType
		row.target_room_index = door.TargetRoomIndex
		row.animation = spr.animation
		row.sprite = spr
		row.skipped_restyle = true
		row.note = "deal door stable: skip SetRoomTypes/Open"
		-- Appear SFX: door already open after combat still counts as appear (not Open() call).
		if sgid == BOSS_ROOM_SGID and is_clear then
			row.appear_sfx = try_play_boss_89_deal_appear_sfx(
				deal_type,
				"boss_89_stable_open",
				door,
				room
			)
		end
		local prev = runtime.boss_89_deal_door
		runtime.boss_89_deal_door = row
		if deal_door_state_key(prev) ~= deal_door_state_key(row) then
			push_event("boss_89_deal_door", row)
		end
		return row
	end

	local target_write = (sgid == BOSS_ROOM_SGID) and DEAL_ROOM_SGID or nil
	local open_wanted = is_clear == true
	local styled = style_deal_door(door, deal_type, target_write, open_wanted)
	for k, v in pairs(styled) do
		row[k] = v
	end
	row.phase = (sgid == BOSS_ROOM_SGID) and "opened" or "deal_side_styled"
	row.opened = row.open_after == true
	row.ok = row.set_room_types_ok == true
		and row.current_room_type == RoomType.ROOM_DEFAULT
		and row.target_room_type == deal_type
	if sgid == DEAL_ROOM_SGID then
		row.ok = row.ok and (row.target_room_index == BOSS_ROOM_SGID or row.target_room_index == nil)
		row.note = "90 LEFT0: SetRoomTypes from live Room@90 type; keep target 89"
	else
		row.note = "89 RIGHT0: restyle+Open once if closed; sprite pose fix; no PlayAnimation"
		-- Appear after clear when door is passable (Open() this frame OR already open).
		if is_clear and row.open_after == true then
			row.appear_sfx = try_play_boss_89_deal_appear_sfx(
				deal_type,
				styled.skipped_open and "boss_89_already_open" or "boss_89_clear_open",
				door,
				room
			)
		end
		if not runtime.deal_door_sprite_watch then
			arm_deal_door_sprite_watch(tag, slot)
		end
	end
	local prev = runtime.boss_89_deal_door
	runtime.boss_89_deal_door = row
	if deal_door_state_key(prev) ~= deal_door_state_key(row) then
		push_event("boss_89_deal_door", row)
	end
	return row
end

local function apply_boss_89_deal_door(tag)
	return apply_boss_deal_doors(tag)
end

function M.install(inject)
	runtime = inject.runtime
	push_event = inject.push_event
	compass_state = inject.compass_state
	BOSS_ROOM_SGID = inject.boss_room_sgid
	DEAL_ROOM_SGID = inject.deal_room_sgid
	grid_door = inject.grid_door
	snapshot_live_door = inject.snapshot_live_door
	Room_holder = inject.Room_holder
	game_frame = inject.game_frame
	BOSS_TYPE_MOM = inject.boss_type_mom
	return {
		resolve_deal_type = resolve_deal_type,
		apply_boss_deal_doors = apply_boss_deal_doors,
		apply_boss_89_deal_door = apply_boss_89_deal_door,
		is_mom_boss_case = is_mom_boss_case,
		read_door_sprite_snap = read_door_sprite_snap,
		ensure_open_sprite_pose = ensure_open_sprite_pose,
		tick_deal_door_sprite_watch = tick_deal_door_sprite_watch,
		arm_deal_door_sprite_watch = arm_deal_door_sprite_watch,
	}
end

return M
