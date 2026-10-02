local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Ghost = require("Qing_Remaster_scripts.others.player_appearance_ghost")
local aeon_replay = require("Qing_Remaster_scripts.cards.aeon_replay")
local aeon_save_codec = require("Qing_Remaster_scripts.cards.aeon_save_codec")
local classifier = require("Qing_Remaster_scripts.callbacks.attack_source_classifier")
local room_space = require("Qing_Remaster_scripts.others.room_space_mapper")
local CharacterAttackCompat = require("Qing_Remaster_scripts.player.character_attack_compat")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Aeon_r,
	own_key = "Thoth_cd20r_Aeon_",
	record_frames_normal = 90,
	record_frames_cloth = 150,
	max_recorded_attacks = 512,
	fade_frames = 8,
	fade_in_frames = 8,
	pending_start_grace_frames = 3,
	echo_delay_frames = 4,
	echo_tint = Color(0.7, 0.85, 1.0, 0.32),
	record_schema_version = 3,
	recording = nil,
	record = nil,
	record_owner = nil,
	replay = nil,
	recording_echo = nil,
	pending_replay = nil,
	pending_record_start = nil,
	played_rooms = {},
}

local probe_observer = nil

function item.set_probe_observer(fn)
	probe_observer = type(fn) == "function" and fn or nil
end

local function probe_emit(event, data)
	if not probe_observer then return end
	pcall(probe_observer, event, data or {})
end

local function player_index(player)
	if not player then return nil end
	local d = player:GetData()
	return d and d.__Index
end

local function current_room_key()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if not desc then return nil end
	return tostring(auxi.get_acceptible_index(desc.SafeGridIndex))
end

--- Canonical timeline: frames[0]..frames[length-1]; attacks shifted with poses.
local function normalize_record_timeline(rec)
	if not rec or type(rec.frames) ~= "table" then
		if rec then rec.length = 0 end
		return 0
	end
	local min_f, max_f = nil, nil
	for k, _ in pairs(rec.frames) do
		local n = tonumber(k)
		if n ~= nil then
			if min_f == nil or n < min_f then min_f = n end
			if max_f == nil or n > max_f then max_f = n end
		end
	end
	if min_f == nil then
		rec.length = 0
		return 0
	end
	if min_f ~= 0 then
		local shifted = {}
		for k, v in pairs(rec.frames) do
			local n = tonumber(k)
			if n ~= nil and type(v) == "table" then
				shifted[n - min_f] = v
			end
		end
		rec.frames = shifted
		if type(rec.attacks) == "table" then
			for i = 1, #rec.attacks do
				local atk = rec.attacks[i]
				if atk and atk.frame ~= nil then
					atk.frame = (tonumber(atk.frame) or 0) - min_f
				end
			end
		end
		local function shift_span(list)
			if type(list) ~= "table" then return end
			for i = 1, #list do
				local tr = list[i]
				if tr then
					if tr.start_frame ~= nil then
						tr.start_frame = (tonumber(tr.start_frame) or 0) - min_f
					end
					if tr.end_frame ~= nil then
						tr.end_frame = (tonumber(tr.end_frame) or 0) - min_f
					end
					if tr.impact_frame ~= nil then
						tr.impact_frame = (tonumber(tr.impact_frame) or 0) - min_f
					end
					if tr.frame ~= nil then
						tr.frame = (tonumber(tr.frame) or 0) - min_f
					end
				end
			end
		end
		shift_span(rec.persistent_tracks)
		shift_span(rec.special_events)
		max_f = max_f - min_f
		min_f = 0
	end
	local length = max_f - min_f + 1
	rec.length = length
	return length
end

local function load_record_from_save()
	local raw = save.elses[item.own_key .. "record"]
	if not aeon_save_codec.is_packed(raw) then
		return nil
	end
	local rec = aeon_save_codec.unpack_save_record(raw)
	if type(rec) ~= "table" then return nil end
	if tonumber(rec.version) ~= item.record_schema_version then
		return nil
	end
	if type(rec.frames) ~= "table" or not rec.frames[0] then return nil end
	if rec.frames[0].x == nil or rec.frames[0].y == nil then
		return nil
	end
	if type(rec.attacks) == "table" then
		table.sort(rec.attacks, function(a, b)
			local fa, fb = tonumber(a.frame) or 0, tonumber(b.frame) or 0
			if fa ~= fb then return fa < fb end
			return (tonumber(a.sequence) or 0) < (tonumber(b.sequence) or 0)
		end)
	end
	return rec
end

local function set_save_record(rec)
	if rec == nil then
		save.elses[item.own_key .. "record"] = nil
		return
	end
	save.elses[item.own_key .. "record"] = aeon_save_codec.pack_save_record(rec)
end

--- Debug / probe: runtime + Continue blob presence for floor-boundary checks.
function item.debug_eternal_snapshot()
	local saved = save.elses[item.own_key .. "record"]
	local played = item.played_rooms
	local played_n = 0
	if type(played) == "table" then
		for _ in pairs(played) do
			played_n = played_n + 1
		end
	end
	return {
		has_record = item.record ~= nil,
		record_length = item.record and item.record.length or nil,
		recording = item.recording ~= nil,
		replay = item.replay ~= nil,
		pending_replay = item.pending_replay ~= nil,
		pending_record_start = item.pending_record_start ~= nil,
		played_rooms_empty = played_n == 0,
		played_rooms_count = played_n,
		saved_record = saved ~= nil,
		record_owner = item.record_owner ~= nil,
	}
end

--- Debug-only: JSON byte estimate for current runtime record vs packed Continue blob.
function item.debug_save_audit()
	local rec = item.record
	if type(rec) ~= "table" then
		local text = "Aeon Save Audit\n\n(no runtime record)"
		item._last_save_audit_text = text
		return {
			ok = false,
			text = text,
		}
	end
	local report = aeon_save_codec.audit_sizes(rec)
	local text = aeon_save_codec.format_audit(report)
	local ok_clip, probe_output = pcall(require, "Qing_Remaster_scripts.debug.probe_output")
	if ok_clip and probe_output and probe_output.copy_text then
		pcall(probe_output.copy_text, text, "aeon_save_audit")
	end
	item._last_save_audit_text = text
	return {
		ok = true,
		report = report,
		text = text,
	}
end

function item.get_last_save_audit_text()
	return item._last_save_audit_text or "尚未运行 Aeon Save Audit"
end

local function destroy_replay(reason)
	local rp = item.replay
	if not rp then return end
	if type(rp.live_tracks) == "table" then
		for i = 1, #rp.live_tracks do
			local live = rp.live_tracks[i]
			if live then
				aeon_replay.end_persistent_entity(live.ent, live.handle)
			end
		end
		rp.live_tracks = nil
	end
	if type(rp.live_specials) == "table" then
		for i = 1, #rp.live_specials do
			local live = rp.live_specials[i]
			if live then
				if live.melee then
					aeon_replay.end_melee_swing(live.ent, live.handle)
				else
					local ent = live.ent or live
					if ent and ent.Exists and ent:Exists() then
						ent:Remove()
					end
				end
			end
		end
		rp.live_specials = nil
	end
	if type(rp.live_presentations) == "table" then
		for i = 1, #rp.live_presentations do
			local handle = rp.live_presentations[i]
			if handle then
				CharacterAttackCompat.end_replay_presentation(handle, reason or "destroy")
				probe_emit("presentation_end", {
					reason = reason or "destroy",
					t = rp.t,
					character_key = handle.character_key,
				})
			end
		end
		rp.live_presentations = nil
	end
	if rp.ghost then
		Ghost.destroy(rp.ghost)
	end
	if not rp.finished_emitted then
		rp.finished_emitted = true
		probe_emit("replay_finished", {
			reason = reason or "destroy",
			t = rp.t,
			fading = rp.fading == true,
			length = rp.record and rp.record.length or nil,
		})
	end
	item.replay = nil
end

local function destroy_recording_echo()
	local echo = item.recording_echo
	if not echo then return end
	if echo.ghost then
		Ghost.destroy(echo.ghost)
	end
	item.recording_echo = nil
end

local function clear_runtime_eternal()
	item.recording = nil
	item.record = nil
	item.record_owner = nil
	item.pending_replay = nil
	item.pending_record_start = nil
	item.played_rooms = {}
	destroy_recording_echo()
	destroy_replay("clear_runtime")
end

local function invalidate_eternal_for_new_take()
	item.record = nil
	item.record_owner = nil
	item.pending_replay = nil
	item.played_rooms = {}
	set_save_record(nil)
	destroy_recording_echo()
	destroy_replay("redefine")
	item.recording = nil
end

local function vec_tbl(v)
	if not v then return {x = 0, y = 0} end
	return {x = tonumber(v.X) or 0, y = tonumber(v.Y) or 0}
end

local function tbl_vec(t)
	if not t then return Vector(0, 0) end
	if t.X ~= nil or t.Y ~= nil then
		return Vector(tonumber(t.X) or 0, tonumber(t.Y) or 0)
	end
	return Vector(tonumber(t.x) or 0, tonumber(t.y) or 0)
end

local function canvas_rel_world(center, fs)
	if not center or not fs then return nil end
	return center + Vector(tonumber(fs.x) or 0, tonumber(fs.y) or 0)
end

local function apply_recorded_anim(ghost, fs)
	if not ghost or not ghost:Exists() or not fs then return end
	Ghost.apply_recorded_pose(ghost, {
		anim = fs.anim,
		anim_frame = fs.anim_frame,
		overlay_anim = fs.overlay_anim,
		overlay_frame = fs.overlay_frame,
		flip_x = fs.flip_x and true or false,
		layer_overrides = fs.layer_overrides,
	})
end

--- 仅首帧 / 重新显示时 Position snap；持续播放用 Velocity = next - ghost.Position 收敛误差
local function drive_ghost_along_targets(ghost, current, next_pos, opts)
	if not ghost or not ghost:Exists() or not current then return end
	opts = opts or {}
	next_pos = next_pos or current
	if opts.snap then
		ghost.Position = current
	end
	ghost.Velocity = next_pos - ghost.Position
end

local function player_extra_anim_finished(player)
	if not player or not player.Exists or not player:Exists() then
		return true
	end
	if not player.IsExtraAnimationFinished then
		return true
	end
	local ok, finished = pcall(function()
		return player:IsExtraAnimationFinished()
	end)
	if not ok then
		return true
	end
	return finished and true or false
end

local function recording_has_any_frame(rec)
	if not rec or type(rec.frames) ~= "table" then return false end
	for k, v in pairs(rec.frames) do
		if tonumber(k) ~= nil and type(v) == "table" then
			return true
		end
	end
	return false
end

local function play_record_end_fx(player)
	if not player or not player.Exists or not player:Exists() then return end
	player:SetColor(Color(0.85, 0.95, 1.0, 1, 0.4, 0.5, 0.6), 10, 8, true, false)
	pcall(function()
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_DARK, 0.55, 1.15, false, 0, 2)
	end)
end

local function scale_tint(base, alpha_mul)
	base = base or Ghost.DEFAULT_TINT
	alpha_mul = math.max(0, math.min(1, tonumber(alpha_mul) or 1))
	local a = (base.A or 1) * alpha_mul
	return Color(base.R, base.G, base.B, a, base.RO or 0, base.GO or 0, base.BO or 0)
end

local function ghost_fade_mul(age, duration)
	duration = math.max(1, tonumber(duration) or item.fade_frames or 8)
	age = math.max(0, tonumber(age) or 0)
	local t = age / duration
	if t < 0 then t = 0 end
	if t > 1 then t = 1 end
	return t
end

local function apply_recording_echo_pose(ghost, rec, echo_t, need_snap)
	if not ghost or not ghost:Exists() or not rec then return end
	local fs = rec.frames[echo_t]
	if not fs then return end
	local center = tbl_vec(rec.source_canvas_center)
	local current = canvas_rel_world(center, fs)
	if not current then return end
	local next_fs = rec.frames[echo_t + 1]
	local next_pos = next_fs and canvas_rel_world(center, next_fs) or current
	drive_ghost_along_targets(ghost, current, next_pos, {snap = need_snap and true or false})
	apply_recorded_anim(ghost, fs)
end

local function apply_replay_pose(ghost, rp, t)
	if not ghost or not ghost:Exists() or not rp then return nil end
	local rec = rp.record
	local fs = rec and rec.frames[t]
	if not fs then return nil end
	local center = rp.canvas_center
	local current = canvas_rel_world(center, fs)
	if not current then return nil end
	local next_fs = rec.frames[t + 1]
	local next_pos = next_fs and canvas_rel_world(center, next_fs) or current
	drive_ghost_along_targets(ghost, current, next_pos, {snap = false})
	apply_recorded_anim(ghost, fs)
	return current, next_pos
end

local function ensure_recording_echo(player, appearance)
	destroy_recording_echo()
	if not player or not appearance then return end
	local ghost = Ghost.spawn(player.Position, appearance, {
		anim = "WalkDown",
		subtype = item.entity,
		owner_key = item.own_key,
		tint = scale_tint(item.echo_tint, 0),
	})
	if not ghost or not ghost.Exists or not ghost:Exists() then
		return
	end
	-- 画在玩家身后
	ghost.DepthOffset = -20
	item.recording_echo = {
		ghost = ghost,
		visible = false,
		appear_age = 0,
		alpha_mul = 0,
		fading_out = false,
		fade_age = 0,
		fade_from = 1,
	}
	ghost.Visible = false
end

local function begin_echo_fade_out()
	local echo = item.recording_echo
	if not echo then return end
	local ghost = echo.ghost
	if not ghost or not ghost:Exists() then
		item.recording_echo = nil
		return
	end
	if echo.fading_out then return end
	echo.fading_out = true
	echo.fade_age = 0
	echo.fade_from = math.max(0, math.min(1, tonumber(echo.alpha_mul) or 1))
	if echo.fade_from <= 0.001 then
		destroy_recording_echo()
		return
	end
	ghost.Visible = true
	echo.visible = true
end

local function tick_echo_fade_out()
	local echo = item.recording_echo
	if not echo or not echo.fading_out then return end
	local ghost = echo.ghost
	if not ghost or not ghost:Exists() then
		item.recording_echo = nil
		return
	end
	echo.fade_age = (echo.fade_age or 0) + 1
	local duration = item.fade_frames or 8
	local mul = (echo.fade_from or 1) * (1 - ghost_fade_mul(echo.fade_age, duration))
	echo.alpha_mul = mul
	ghost.Velocity = Vector(0, 0)
	Ghost.set_tint(ghost, scale_tint(item.echo_tint, mul))
	if echo.fade_age >= duration then
		destroy_recording_echo()
	end
end

local function tick_recording_echo(frame)
	local echo = item.recording_echo
	local rec = item.recording
	if not echo or not rec then return end
	if echo.fading_out then return end
	local ghost = echo.ghost
	if not ghost or not ghost:Exists() then
		item.recording_echo = nil
		return
	end
	local delay = item.echo_delay_frames or 4
	local echo_t = (tonumber(frame) or 0) - delay
	if echo_t < 0 then
		ghost.Visible = false
		echo.visible = false
		echo.appear_age = 0
		echo.alpha_mul = 0
		return
	end
	local fs = rec.frames[echo_t]
	if not fs then
		ghost.Visible = false
		echo.visible = false
		return
	end
	local need_snap = not echo.visible
	if need_snap then
		echo.appear_age = 0
	end
	ghost.Visible = true
	echo.visible = true
	echo.appear_age = (echo.appear_age or 0) + 1
	local mul = ghost_fade_mul(echo.appear_age, item.fade_in_frames or item.fade_frames)
	-- tint 仅在淡入过程变化；满不透明后不再每帧重写
	if mul < 1 or (echo.alpha_mul or 0) < 1 then
		echo.alpha_mul = mul
		Ghost.set_tint(ghost, scale_tint(item.echo_tint, mul))
	else
		echo.alpha_mul = 1
	end
	apply_recording_echo_pose(ghost, rec, echo_t, need_snap)
end

local function get_live_shoot_direction(player)
	if not player or not player.GetShootingInput then
		return nil
	end
	local ok, dir = pcall(function()
		return player:GetShootingInput()
	end)
	if ok and dir and dir:Length() >= 0.1 then
		return dir:Normalized()
	end
	return nil
end

local function fire_direction_vector(fd)
	if fd == nil or Direction == nil then
		return nil
	end
	if fd == Direction.LEFT then
		return Vector(-1, 0)
	elseif fd == Direction.RIGHT then
		return Vector(1, 0)
	elseif fd == Direction.UP then
		return Vector(0, -1)
	elseif fd == Direction.DOWN then
		return Vector(0, 1)
	end
	return nil
end

--- Sword window > ShootingInput > FireDirection > nil (keep Sprite overlay).
local function resolve_recording_visual_aim(player, rec, frame)
	local aim = rec and rec.visual_aim
	if aim and aim.direction and frame <= (tonumber(aim.until_frame) or frame) then
		return aim.direction, aim.authority or "sword"
	end
	if rec and rec.visual_aim and frame > (tonumber(rec.visual_aim.until_frame) or -1) then
		rec.visual_aim = nil
	end
	local shoot = get_live_shoot_direction(player)
	if shoot then
		return shoot, "shooting"
	end
	if player and player.GetFireDirection then
		local ok, fd = pcall(function()
			return player:GetFireDirection()
		end)
		if ok then
			local dir = fire_direction_vector(fd)
			if dir then
				return dir, "fire"
			end
		end
	end
	return nil, nil
end

local function record_pose(player, frame)
	local rec = item.recording
	if not rec then return end
	local pose = Ghost.capture_live_pose(player, rec.pose_runtime)
	local anim, anim_frame, overlay_anim, overlay_frame, flip_x =
		"WalkDown", 0, nil, 0, false
	local layer_overrides = nil
	if type(pose) == "table" then
		if pose.body then
			anim = pose.body.anim or anim
			anim_frame = tonumber(pose.body.frame) or 0
		end
		if pose.head then
			overlay_anim = pose.head.anim
			overlay_frame = tonumber(pose.head.frame) or 0
		end
		flip_x = pose.flip_x and true or false
		layer_overrides = pose.overrides
	else
		local spr = player:GetSprite()
		if spr then
			pcall(function()
				anim = spr:GetAnimation() or anim
				anim_frame = spr:GetFrame() or 0
				overlay_anim = spr:GetOverlayAnimation()
				overlay_frame = spr:GetOverlayFrame() or 0
				flip_x = spr.FlipX and true or false
			end)
		end
	end

	local visual_aim = resolve_recording_visual_aim(player, rec, frame)
	if visual_aim then
		local head_anim = aeon_replay.head_anim_from_direction(visual_aim)
		if head_anim and head_anim ~= overlay_anim then
			overlay_anim = head_anim
			if overlay_frame == nil then
				overlay_frame = 0
			end
		elseif head_anim then
			overlay_anim = head_anim
		end
	end

	local center = tbl_vec(rec.source_canvas_center)
	local relative = player.Position - center
	local character_pose = CharacterAttackCompat.capture_replay_pose(player, {
		canvas_center = center,
		frame = frame,
	})
	rec.frames[frame] = {
		x = relative.X,
		y = relative.Y,
		velocity = vec_tbl(player.Velocity),
		anim = anim,
		anim_frame = anim_frame,
		overlay_anim = overlay_anim,
		overlay_frame = overlay_frame,
		flip_x = flip_x,
		layer_overrides = layer_overrides,
		character_pose = character_pose,
	}
end

local function begin_recording(player, target_length)
	item.pending_record_start = nil
	item.recording = nil

	local appearance = Ghost.capture(player)
	if not appearance then
		probe_emit("record_start", {
			ok = false,
			reason = "appearance_capture_failed",
			target_length = target_length,
		})
		return false
	end

	local source_canvas = room_space.select_standard_canvas(player.Position)
	item.recording = {
		owner = player,
		owner_index = player_index(player),
		owner_controller_index = player.ControllerIndex,
		start_frame = Game():GetFrameCount(),
		target_length = target_length,
		appearance = appearance,
		source_room_key = current_room_key(),
		source_canvas_center = {
			x = source_canvas.center.X,
			y = source_canvas.center.Y,
		},
		source_canvas_grid_origin_x = source_canvas.grid_origin_x,
		source_canvas_grid_origin_y = source_canvas.grid_origin_y,
		frames = {},
		attacks = {},
		persistent_tracks = {},
		special_events = {},
		live_members = {},
		seen_members = {},
		character_owned_attacks = {},
		sword_watch = {},
		visual_aim = nil,
		max_events = item.max_recorded_attacks,
		next_sequence = 0,
		pose_runtime = Ghost.begin_live_pose_capture(player, appearance),
	}
	-- Extra Animation 结束后的真实第一帧
	record_pose(player, 0)
	ensure_recording_echo(player, appearance)
	tick_recording_echo(0)
	player:SetColor(Color(0.75, 0.9, 1.0, 1, 0.25, 0.35, 0.45), 8, 8, true, false)
	pcall(function()
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.7, 1.4, false, 0, 2)
	end)
	local f0 = item.recording.frames[0]
	probe_emit("record_start", {
		ok = true,
		target_length = target_length,
		owner_index = item.recording.owner_index,
		owner_controller_index = item.recording.owner_controller_index,
		start_frame = item.recording.start_frame,
		room_key = current_room_key(),
		has_frame0 = f0 ~= nil,
		x = f0 and f0.x or nil,
		y = f0 and f0.y or nil,
		canvas_center_x = source_canvas.center.X,
		canvas_center_y = source_canvas.center.Y,
		canvas_grid_origin_x = source_canvas.grid_origin_x,
		canvas_grid_origin_y = source_canvas.grid_origin_y,
	})
	return true
end

local function resolve_pending_owner(pending)
	if not pending then return nil end
	local owner = pending.owner
	if owner and owner.Exists and owner:Exists() and not owner:IsDead() then
		return owner
	end
	if pending.owner_index ~= nil then
		for i = 0, Game():GetNumPlayers() - 1 do
			local p = Game():GetPlayer(i)
			if p and p:Exists() and not p:IsDead() and player_index(p) == pending.owner_index then
				pending.owner = p
				return p
			end
		end
	end
	if pending.owner_controller_index ~= nil then
		for i = 0, Game():GetNumPlayers() - 1 do
			local p = Game():GetPlayer(i)
			if p and p:Exists() and not p:IsDead()
				and p.ControllerIndex == pending.owner_controller_index then
				pending.owner = p
				return p
			end
		end
	end
	return nil
end

local function tick_pending_record_start()
	local pending = item.pending_record_start
	if not pending then return end
	if item.recording then
		item.pending_record_start = nil
		return
	end

	local owner = resolve_pending_owner(pending)
	if not owner then
		item.pending_record_start = nil
		probe_emit("record_start", {ok = false, reason = "pending_owner_lost"})
		return
	end

	local finished = player_extra_anim_finished(owner)
	if not finished then
		pending.saw_extra_animation = true
		return
	end

	if pending.saw_extra_animation then
		item.pending_record_start = nil
		begin_recording(owner, pending.target_length)
		return
	end

	local age = Game():GetFrameCount() - (pending.request_frame or 0)
	if age >= (item.pending_start_grace_frames or 3) then
		item.pending_record_start = nil
		begin_recording(owner, pending.target_length)
	end
end

local function request_recording(player, target_length)
	invalidate_eternal_for_new_take()
	item.pending_record_start = {
		owner = player,
		owner_index = player_index(player),
		owner_controller_index = player.ControllerIndex,
		target_length = target_length,
		saw_extra_animation = false,
		request_frame = Game():GetFrameCount(),
	}
	probe_emit("use", {
		target_length = target_length,
		room_key = current_room_key(),
		player_index = player_index(player),
		pending_record_start = true,
	})
end

local function sample_live_attack_members(rec, owner, frame)
	local live = rec.live_members
	if type(live) ~= "table" then return end
	local dead = {}
	for ptr, track in pairs(live) do
		local ent = track and track._entity
		if track and (track.mode == "melee_swing" or track.kind == "melee_swing"
			or track.mode == "sword_action" or track.kind == "sword_action"
			or track.kind == "normal" or track.kind == "spin")
		then
			if aeon_replay.entity_alive(ent) then
				aeon_replay.sample_melee_swing_event(track, ent, owner)
			else
				dead[#dead + 1] = ptr
			end
		elseif not aeon_replay.entity_alive(ent) then
			dead[#dead + 1] = ptr
		else
			track._entity = ent
			track._ptr = ptr
			if track.mode == "special" or track.kind == "epic" then
				aeon_replay.sample_special_event(track, ent, owner)
			elseif frame > (tonumber(track.start_frame) or 0) then
				aeon_replay.sample_persistent_track(track, ent, owner)
			end
		end
	end
	for i = 1, #dead do
		local ptr = dead[i]
		local track = live[ptr]
		live[ptr] = nil
		if track then
			if track.mode == "melee_swing" or track.kind == "melee_swing"
				or track.mode == "sword_action" or track.kind == "sword_action"
				or track.kind == "normal" or track.kind == "spin"
			then
				aeon_replay.finalize_melee_swing_event(track, frame)
			elseif track.mode == "special" or track.kind == "epic" then
				aeon_replay.finalize_special_event(track, frame)
			else
				aeon_replay.finalize_persistent_track(track, frame)
			end
		end
	end
end

local function finalize_all_live_members(rec, end_frame)
	local live = rec.live_members
	if type(live) ~= "table" then return end
	for ptr, track in pairs(live) do
		if track then
			if track.mode == "melee_swing" or track.kind == "melee_swing"
				or track.mode == "sword_action" or track.kind == "sword_action"
				or track.kind == "normal" or track.kind == "spin"
			then
				aeon_replay.finalize_melee_swing_event(track, end_frame)
			elseif track.mode == "special" or track.kind == "epic" then
				aeon_replay.finalize_special_event(track, end_frame)
			else
				aeon_replay.finalize_persistent_track(track, end_frame)
			end
		end
		live[ptr] = nil
	end
end

--- 完成录像：normalize 后 length = max-min+1；写入 runtime item.record
local function finish_recording(reason)
	local rec = item.recording
	if not rec then return false end

	local target = rec.target_length or item.record_frames_normal
	item.recording = nil
	begin_echo_fade_out()

	local actual = normalize_record_timeline(rec)
	local attack_n = type(rec.attacks) == "table" and #rec.attacks or 0
	if actual < 1 or not rec.frames[0] or rec.frames[0].x == nil or rec.frames[0].y == nil then
		probe_emit("record_finish", {
			ok = false,
			reason = reason or "empty",
			length = 0,
			target_length = target,
			attack_count = attack_n,
			room_key = current_room_key(),
		})
		return false
	end

	-- 丢掉越界攻击（normalize 后 frame 应落在 [0, length)）
	if type(rec.attacks) == "table" then
		local kept = {}
		for i = 1, #rec.attacks do
			local atk = rec.attacks[i]
			local f = atk and tonumber(atk.frame)
			if f ~= nil and f >= 0 and f < actual then
				kept[#kept + 1] = atk
			end
		end
		rec.attacks = kept
		attack_n = #kept
	end

	finalize_all_live_members(rec, math.max(0, actual - 1))

	local function keep_span(list)
		local kept = {}
		if type(list) ~= "table" then return kept end
		for i = 1, #list do
			local tr = list[i]
			local sf = tr and tonumber(tr.start_frame)
			if sf ~= nil and sf >= 0 and sf < actual then
				if tr.end_frame == nil then
					tr.end_frame = math.max(sf, actual - 1)
				end
				local ef = tonumber(tr.end_frame) or sf
				if ef >= actual then
					tr.end_frame = actual - 1
				end
				if tr.impact_frame ~= nil then
					local imp = tonumber(tr.impact_frame) or ef
					if imp >= actual then tr.impact_frame = actual - 1 end
				end
				kept[#kept + 1] = tr
			end
		end
		return kept
	end

	local out = {
		version = item.record_schema_version,
		owner_index = rec.owner_index,
		owner_controller_index = rec.owner_controller_index,
		length = actual,
		appearance = Ghost.sanitize(rec.appearance) or rec.appearance,
		canvas = {
			grid_w = room_space.STANDARD_GRID_W,
			grid_h = room_space.STANDARD_GRID_H,
			tile = room_space.GRID_TILE,
		},
		frames = rec.frames,
		attacks = rec.attacks,
		persistent_tracks = keep_span(rec.persistent_tracks),
		special_events = keep_span(rec.special_events),
		source_room_key = rec.source_room_key,
		played_rooms = {},
	}
	table.sort(out.persistent_tracks, function(a, b)
		local fa = tonumber(a.start_frame) or 0
		local fb = tonumber(b.start_frame) or 0
		if fa ~= fb then return fa < fb end
		return (tonumber(a.sequence) or 0) < (tonumber(b.sequence) or 0)
	end)
	table.sort(out.special_events, function(a, b)
		local fa = tonumber(a.start_frame) or 0
		local fb = tonumber(b.start_frame) or 0
		if fa ~= fb then return fa < fb end
		return (tonumber(a.sequence) or 0) < (tonumber(b.sequence) or 0)
	end)
	if rec.source_room_key then
		out.played_rooms[tostring(rec.source_room_key)] = true
	else
		local key = current_room_key()
		if key then
			out.played_rooms[key] = true
		end
	end

	item.record = out
	item.record_owner = rec.owner
	-- 与 record 共用同一张表，Continue 时一并恢复
	item.played_rooms = out.played_rooms
	item.pending_replay = nil
	set_save_record(out)

	local player = rec.owner
	if not (player and player.Exists and player:Exists()) then
		player = nil
		if rec.owner_index ~= nil then
			for i = 0, Game():GetNumPlayers() - 1 do
				local p = Game():GetPlayer(i)
				if p and player_index(p) == rec.owner_index then
					player = p
					break
				end
			end
		end
	end
	play_record_end_fx(player)
	probe_emit("record_finish", {
		ok = true,
		reason = reason or "complete",
		length = actual,
		target_length = target,
		attack_count = attack_n,
		persistent_count = type(out.persistent_tracks) == "table" and #out.persistent_tracks or 0,
		special_count = type(out.special_events) == "table" and #out.special_events or 0,
		character_action_count = (function()
			local n = 0
			local specials = out.special_events
			if type(specials) ~= "table" then return 0 end
			for i = 1, #specials do
				local sp = specials[i]
				if sp and (sp.mode == "character_action" or sp.kind == "character_action") then
					n = n + 1
				end
			end
			return n
		end)(),
		character_action_kinds = (function()
			local kinds = {}
			local specials = out.special_events
			if type(specials) ~= "table" then return kinds end
			for i = 1, #specials do
				local sp = specials[i]
				if sp and (sp.mode == "character_action" or sp.kind == "character_action") then
					local kind = sp.base and sp.base.attack_kind or sp.base and sp.base.snapshot and sp.base.snapshot.kind
					kinds[#kinds + 1] = kind
				end
			end
			return kinds
		end)(),
		owner_index = out.owner_index,
		room_key = current_room_key(),
		has_runtime_record = item.record ~= nil,
		has_frame0 = out.frames[0] ~= nil,
	})
	return true
end

local function resolve_record_owner(rec)
	local owner = item.record_owner
	if owner and owner.Exists and owner:Exists() and not owner:IsDead() then
		return owner
	end

	if rec and rec.owner_index ~= nil then
		for i = 0, Game():GetNumPlayers() - 1 do
			local p = Game():GetPlayer(i)
			if p and p:Exists() and not p:IsDead() and player_index(p) == rec.owner_index then
				item.record_owner = p
				return p
			end
		end
	end

	if rec and rec.owner_controller_index ~= nil then
		for i = 0, Game():GetNumPlayers() - 1 do
			local p = Game():GetPlayer(i)
			if p and p:Exists() and not p:IsDead()
				and p.ControllerIndex == rec.owner_controller_index then
				item.record_owner = p
				return p
			end
		end
	end

	if Game():GetNumPlayers() == 1 then
		local p = Game():GetPlayer(0)
		if p and p:Exists() and not p:IsDead() then
			item.record_owner = p
			return p
		end
	end

	return nil
end

local function start_replay(rec)
	if not rec then
		return false, "invalid_record"
	end
	if type(rec.frames) ~= "table" then
		return false, "invalid_record"
	end
	if tonumber(rec.version) ~= item.record_schema_version then
		return false, "invalid_record"
	end

	local had_runtime_owner = item.record_owner
		and item.record_owner.Exists
		and item.record_owner:Exists()
		and not item.record_owner:IsDead()
	local owner = resolve_record_owner(rec)
	if owner then
		probe_emit("owner_resolved", {
			owner_index = player_index(owner),
			controller_index = owner.ControllerIndex,
			via_runtime_ref = had_runtime_owner and true or false,
		})
	else
		probe_emit("owner_failed", {
			record_owner_index = rec.owner_index,
			record_controller_index = rec.owner_controller_index,
		})
		return false, "owner_failed"
	end

	destroy_replay("restart")

	local first = rec.frames[0]
	if not first or first.x == nil or first.y == nil then
		probe_emit("ghost_spawn_result", {ok = false, reason = "no_frame0"})
		return false, "no_frame0"
	end

	local target_canvas = room_space.select_standard_canvas(owner.Position)
	local canvas_center = Vector(target_canvas.center.X, target_canvas.center.Y)
	local spawn_pos = canvas_rel_world(canvas_center, first)
	if not spawn_pos then
		probe_emit("ghost_spawn_result", {ok = false, reason = "invalid_record"})
		return false, "invalid_record"
	end

	probe_emit("ghost_spawn_request", {
		origin = {x = spawn_pos.X, y = spawn_pos.Y},
		recorded_x = first.x,
		recorded_y = first.y,
		anim = first.anim or "WalkDown",
		length = rec.length,
		attack_count = type(rec.attacks) == "table" and #rec.attacks or 0,
		canvas_center_x = canvas_center.X,
		canvas_center_y = canvas_center.Y,
	})
	local ghost = Ghost.spawn(spawn_pos, rec.appearance, {
		anim = first.anim or "WalkDown",
		subtype = item.entity,
		owner_key = item.own_key,
		tint = scale_tint(Ghost.DEFAULT_TINT, 0),
	})
	local ghost_ok = ghost and ghost.Exists and ghost:Exists()
	probe_emit("ghost_spawn_result", {
		ok = ghost_ok == true,
		ptr = ghost_ok and GetPtrHash(ghost) or nil,
		type = ghost_ok and ghost.Type or nil,
		variant = ghost_ok and ghost.Variant or nil,
		subtype = ghost_ok and ghost.SubType or nil,
	})
	if not ghost_ok then
		return false, "ghost_spawn_failed"
	end

	ghost.Position = spawn_pos
	ghost.Velocity = Vector(0, 0)
	apply_recorded_anim(ghost, first)

	item.replay = {
		record = rec,
		ghost = ghost,
		owner = owner,
		canvas_center = canvas_center,
		canvas_grid_origin_x = target_canvas.grid_origin_x,
		canvas_grid_origin_y = target_canvas.grid_origin_y,
		t = 0,
		attack_index = 1,
		track_index = 1,
		special_index = 1,
		live_tracks = {},
		live_specials = {},
		live_presentations = {},
		appearing = true,
		appear_age = 0,
		fading = false,
		fade_age = 0,
		first_tick_emitted = false,
		first_attack_emitted = false,
		finished_emitted = false,
	}
	probe_emit("replay_started", {
		length = rec.length,
		room_key = current_room_key(),
		ghost_ptr = GetPtrHash(ghost),
		canvas_center_x = canvas_center.X,
		canvas_center_y = canvas_center.Y,
		canvas_grid_origin_x = target_canvas.grid_origin_x,
		canvas_grid_origin_y = target_canvas.grid_origin_y,
	})
	return true
end

local function recording_owner(rec)
	local owner = rec.owner
	if owner and owner.Exists and owner:Exists() and not owner:IsDead() then
		return owner
	end
	if rec.owner_index ~= nil then
		for i = 0, Game():GetNumPlayers() - 1 do
			local p = Game():GetPlayer(i)
			if p and player_index(p) == rec.owner_index then
				rec.owner = p
				return p
			end
		end
	end
	return nil
end

local function tick_recording()
	local rec = item.recording
	if not rec then return end
	local owner = recording_owner(rec)
	if not owner or not owner:Exists() or owner:IsDead() then
		if recording_has_any_frame(rec) then
			finish_recording("owner_lost")
		else
			item.recording = nil
			destroy_recording_echo()
			probe_emit("record_finish", {
				ok = false,
				reason = "owner_lost_empty",
				length = 0,
			})
		end
		return
	end
	local frame = Game():GetFrameCount() - rec.start_frame
	if frame < 0 then return end
	local target = rec.target_length or item.record_frames_normal
	if frame >= target then
		finish_recording("target_reached")
		return
	end
	sample_live_attack_members(rec, owner, frame)
	aeon_replay.sample_sword_watch(rec, owner, frame)
	-- Pose after sword watch so spin visual_aim applies on the same frame.
	record_pose(owner, frame)
	tick_recording_echo(frame)
end

local function try_start_pending_replay()
	local pending = item.pending_replay
	if not pending then return end
	if item.recording then return end
	if item.pending_record_start then return end
	if item.replay then return end

	local rec = item.record
	local current_key = current_room_key()
	local fail_reason = nil
	if not rec then
		fail_reason = "no_record"
	elseif current_key ~= pending.room_key then
		fail_reason = "room_mismatch"
	elseif item.played_rooms[current_key] then
		fail_reason = "already_played"
	end

	if fail_reason then
		probe_emit("replay_try_start", {
			ok = false,
			reason = fail_reason,
			room_key = pending.room_key,
			current_key = current_key,
			record_length = rec and rec.length or nil,
		})
		item.pending_replay = nil
		return
	end

	probe_emit("replay_try_start", {
		ok = true,
		room_key = pending.room_key,
		record_length = rec.length,
	})
	local ok, reason = start_replay(rec)
	if ok then
		-- 与 item.record.played_rooms 同一引用；成功后才消费，并 re-pack Continue blob
		item.played_rooms[current_key] = true
		if item.record then
			set_save_record(item.record)
		end
		item.pending_replay = nil
		return
	end
	-- 不可恢复的 record 校验失败：清 pending，禁止每帧重试
	if reason == "no_frame0" or reason == "invalid_record" then
		item.pending_replay = nil
		probe_emit("replay_try_start", {
			ok = false,
			reason = reason,
			room_key = pending.room_key,
			dropped_pending = true,
		})
	end
	-- owner_failed / ghost_spawn_failed：保留 pending，允许后续帧再试
end

local function tick_replay()
	local rp = item.replay
	if not rp then return end
	local rec = rp.record
	local ghost = rp.ghost
	if not ghost or not ghost:Exists() then
		probe_emit("replay_ghost_lost", {
			t = rp.t,
			fading = rp.fading == true,
		})
		destroy_replay("ghost_lost")
		return
	end

	if rp.fading then
		rp.fade_age = (rp.fade_age or 0) + 1
		local duration = item.fade_frames or 8
		local mul = 1 - ghost_fade_mul(rp.fade_age, duration)
		Ghost.set_tint(ghost, scale_tint(Ghost.DEFAULT_TINT, mul))
		ghost.Velocity = Vector(0, 0)
		if rp.fade_age >= duration then
			destroy_replay("fade_complete")
		end
		return
	end

	local t = rp.t
	local fs = rec.frames[t]
	if not fs then
		rp.fading = true
		rp.fade_age = 0
		rp.appearing = false
		return
	end

	local target, next_target = apply_replay_pose(ghost, rp, t)
	if not target then
		rp.fading = true
		rp.fade_age = 0
		rp.appearing = false
		return
	end
	next_target = next_target or target

	-- 出现 / 消失过渡才改 tint；稳态不每帧重写
	if rp.appearing then
		rp.appear_age = (rp.appear_age or 0) + 1
		local mul = ghost_fade_mul(rp.appear_age, item.fade_in_frames or item.fade_frames)
		Ghost.set_tint(ghost, scale_tint(Ghost.DEFAULT_TINT, mul))
		if mul >= 1 then
			rp.appearing = false
		end
	end

	if not rp.first_tick_emitted then
		rp.first_tick_emitted = true
		probe_emit("replay_first_tick", {
			t = t,
			recorded_x = fs.x,
			recorded_y = fs.y,
			target_x = target.X,
			target_y = target.Y,
			pos = {x = target.X, y = target.Y},
			anim = fs.anim,
			ghost_ptr = GetPtrHash(ghost),
		})
	end

	local attacks = rec.attacks or {}
	while rp.attack_index <= #attacks do
		local atk = attacks[rp.attack_index]
		if not atk or (atk.frame or 0) > t then
			break
		end
		if (atk.frame or 0) == t then
			local is_first = not rp.first_attack_emitted
			if is_first then
				probe_emit("replay_first_attack", {
					frame = atk.frame,
					sequence = atk.sequence,
					kind = atk.kind or atk.type,
				})
			end
			local spawned = aeon_replay.spawn_from_snapshot(atk, ghost, rp.owner, item.own_key)
			if is_first then
				rp.first_attack_emitted = true
				probe_emit("replay_first_attack_result", {
					ok = spawned ~= nil,
					ptr = spawned and GetPtrHash(spawned) or nil,
					type = spawned and spawned.Type or nil,
					variant = spawned and spawned.Variant or nil,
				})
			end
		end
		rp.attack_index = rp.attack_index + 1
	end

	-- Persistent tracks: spawn at start, drive each frame, remove at end.
	local tracks = rec.persistent_tracks or {}
	while rp.track_index <= #tracks do
		local tr = tracks[rp.track_index]
		if not tr or (tonumber(tr.start_frame) or 0) > t then
			break
		end
		if (tonumber(tr.start_frame) or 0) == t then
			local ent, handle = aeon_replay.spawn_persistent(tr, ghost, rp.owner, item.own_key, t)
			if ent then
				local owned = {ent}
				if handle then owned[#owned + 1] = handle end
				local kd = ent.GetData and ent:GetData() or nil
				local spatial = kd and (kd._QingAeonKnifeSpatialDriver or kd._QingAeonEngineKnife)
				rp.live_tracks[#rp.live_tracks + 1] = {
					track = tr,
					ent = ent,
					handle = handle,
					owned = owned,
				}
				if spatial and tr.kind == "knife" then
					local hd = handle and handle.GetData and handle:GetData() or nil
					probe_emit("knife_spawn", {
						ptr = GetPtrHash(ent),
						handle_ptr = handle and GetPtrHash(handle) or nil,
						start_frame = tonumber(tr.start_frame),
						end_frame = tonumber(tr.end_frame),
						t = t,
						anchor_removecd = hd and hd.removecd or nil,
					})
				elseif tr.kind == "laser" then
					local laser = ent.ToLaser and ent:ToLaser() or ent
					local get_scale = nil
					if laser and laser.GetScale then
						local ok, sc = pcall(function() return laser:GetScale() end)
						if ok then get_scale = tonumber(sc) end
					end
					local get_dm = nil
					if laser and laser.GetDamageMultiplier then
						local ok, dm = pcall(function() return laser:GetDamageMultiplier() end)
						if ok then get_dm = tonumber(dm) end
					end
					local ss = laser and laser.SpriteScale or nil
					local base = tr.base or {}
					probe_emit("laser_spawn", {
						family = tr.family,
						t = t,
						recorded_laser_scale = tonumber(base.laser_scale),
						recorded_damage_multiplier = tonumber(base.damage_multiplier),
						get_scale = get_scale,
						get_damage_multiplier = get_dm,
						sprite_scale = ss and {x = ss.X, y = ss.Y} or nil,
						radius = laser and tonumber(laser.Radius) or nil,
						size = laser and tonumber(laser.Size) or nil,
						collision_damage = laser and tonumber(laser.CollisionDamage) or nil,
						techx_spawn_radius = tonumber(base.techx_spawn_radius),
						ptr = GetPtrHash(ent),
						handle_ptr = handle and GetPtrHash(handle) or nil,
					})
				end
			end
		end
		rp.track_index = rp.track_index + 1
	end

	local still_live = {}
	for i = 1, #(rp.live_tracks or {}) do
		local live = rp.live_tracks[i]
		local tr = live and live.track
		local ent = live and live.ent
		local handle = live and live.handle
		local owned = live and live.owned
		local end_f = tr and tonumber(tr.end_frame) or t
		if not aeon_replay.entity_alive(ent) then
			if handle and aeon_replay.entity_alive(handle) then
				handle:Remove()
			end
			if tr and tr.kind == "knife" then
				probe_emit("knife_cleanup", {
					reason = "entity_gone",
					t = t,
					end_frame = end_f,
					called = false,
				})
			end
		elseif tr then
			local kd = ent:GetData()
			local spatial_knife = tr.kind == "knife"
				and (kd._QingAeonKnifeSpatialDriver == true or kd._QingAeonEngineKnife == true)

			if spatial_knife then
				local grace = aeon_replay.KNIFE_WATCHDOG_GRACE or 8
				local deadline = end_f + grace
				local hd = handle and handle.GetData and handle:GetData() or nil
				probe_emit("knife_tick", {
					t = t,
					end_frame = end_f,
					deadline = deadline,
					ent_exists = true,
					handle_exists = aeon_replay.entity_alive(handle),
					anchor_removecd = hd and hd.removecd or nil,
					ptr = GetPtrHash(ent),
				})
				if t <= end_f then
					-- Recorded phase: drive space only; factory owns lifetime.
					aeon_replay.refresh_knife_handle_driver(handle, target, next_target)
					aeon_replay.apply_persistent_state(tr, ent, ghost, t, handle)
					still_live[#still_live + 1] = live
				elseif t <= deadline then
					-- Past recorded end: let Nil_holder / engine finish; keep watching.
					aeon_replay.refresh_knife_handle_driver(handle, target, next_target)
					still_live[#still_live + 1] = live
				else
					-- Watchdog only if factory failed to clean up.
					probe_emit("knife_cleanup", {
						reason = "watchdog",
						t = t,
						end_frame = end_f,
						deadline = deadline,
						called = true,
						ent_before = true,
						handle_before = aeon_replay.entity_alive(handle),
						anchor_removecd = hd and hd.removecd or nil,
					})
					aeon_replay.end_replay_knife(ent, handle, owned)
					probe_emit("knife_cleanup_result", {
						ent_after = aeon_replay.entity_alive(ent),
						handle_after = aeon_replay.entity_alive(handle),
					})
				end
			else
				if t <= end_f then
					aeon_replay.apply_persistent_state(tr, ent, ghost, t, handle)
				end
				if t < end_f then
					still_live[#still_live + 1] = live
				else
					aeon_replay.end_persistent_entity(ent, handle)
				end
			end
		end
	end
	rp.live_tracks = still_live

	-- Epic / sword_action / legacy melee_swing: spawn once; Spirit Sword Mimic or fire_Sword + duration watchdog.
	-- character_action: gameplay via spawn_special; optional pure-visual presentation via CharacterAttackCompat.
	local specials = rec.special_events or {}
	while rp.special_index <= #specials do
		local sp = specials[rp.special_index]
		if not sp or (tonumber(sp.start_frame) or 0) > t then
			break
		end
		if (tonumber(sp.start_frame) or 0) == t then
			local is_character_action = sp.mode == "character_action"
				or sp.kind == "character_action"
				or sp.family == "character_action"
			if is_character_action then
				local ok_tecro, Tecro = pcall(require, "Qing_Remaster_scripts.player.player_Tecro")
				if ok_tecro and Tecro and Tecro.debug_take_virtual_spawn_delta then
					Tecro.debug_take_virtual_spawn_delta()
				end
			end
			local ent, handle = aeon_replay.spawn_special(sp, ghost, rp.owner, item.own_key, t)
			if is_character_action then
				local base = sp.base or {}
				local snapshot = base.snapshot
				local dir = tbl_vec(base.direction or (snapshot and snapshot.direction))
				if dir:Length() < 0.01 then
					dir = Vector(0, 1)
				else
					dir = dir:Normalized()
				end
				local pose_owner = base.player_type or rp.owner
				if CharacterAttackCompat.has_replay_presentation(pose_owner) then
					local presentation = CharacterAttackCompat.begin_replay_presentation(
						pose_owner,
						{
							snapshot = snapshot,
							source = ghost,
							origin = ghost.Position,
							aim_dir = dir,
							owner_player = rp.owner,
							player_type = base.player_type,
							character_key = base.character_key,
							reason = "aeon_character_presentation",
						}
					)
					if presentation then
						rp.live_presentations = rp.live_presentations or {}
						rp.live_presentations[#rp.live_presentations + 1] = presentation
						probe_emit("presentation_begin", {
							ok = true,
							character_key = base.character_key,
							attack_kind = base.attack_kind or (snapshot and snapshot.kind),
							player_type = base.player_type,
							t = t,
						})
					else
						probe_emit("presentation_begin", {
							ok = false,
							character_key = base.character_key,
							attack_kind = base.attack_kind or (snapshot and snapshot.kind),
							player_type = base.player_type,
							t = t,
						})
					end
				else
					probe_emit("presentation_begin", {
						ok = true,
						skipped = true,
						reason = "replay_owns_presentation",
						character_key = base.character_key,
						attack_kind = base.attack_kind or (snapshot and snapshot.kind),
						player_type = base.player_type,
						t = t,
					})
				end
				do
					local ok_tecro, Tecro = pcall(require, "Qing_Remaster_scripts.player.player_Tecro")
					if ok_tecro and Tecro and Tecro.debug_take_virtual_spawn_delta then
						local delta = Tecro.debug_take_virtual_spawn_delta()
						probe_emit("tecro_virtual_spawn", {
							character_key = base.character_key,
							attack_kind = base.attack_kind or (snapshot and snapshot.kind),
							t = t,
							delta = delta,
							ok = (tonumber(delta.total) or 0) == 1
								and (tonumber(delta.gameplay) or 0) == 1
								and (tonumber(delta.presentation) or 0) == 0,
							expect = {total = 1, gameplay = 1, presentation = 0},
						})
					end
				end
			elseif ent then
				local is_melee = sp.mode == "sword_action"
					or sp.kind == "sword_action"
					or sp.kind == "normal"
					or sp.kind == "spin"
					or sp.kind == "melee_swing"
					or sp.mode == "melee_swing"
				local end_f = tonumber(sp.end_frame) or t
				local grace = is_melee and (aeon_replay.MELEE_SWING_GRACE or 4) or 0
				local owned = {ent}
				if handle then owned[#owned + 1] = handle end
				rp.live_specials[#rp.live_specials + 1] = {
					event = sp,
					ent = ent,
					handle = handle,
					owned = owned,
					melee = is_melee,
					cleanup_frame = end_f + grace,
				}
				if is_melee then
					local base = sp.base or {}
					local dir = base.direction or {}
					local ad = handle and handle.GetData and handle:GetData() or nil
					local anim = nil
					if ent.GetSprite then
						local spr = ent:GetSprite()
						anim = spr and spr.GetAnimation and spr:GetAnimation() or nil
					end
					local action_kind = base.action_kind or sp.kind or "normal"
					probe_emit("sword_spawn", {
						sf = tonumber(sp.start_frame),
						ef = end_f,
						family = sp.family or base.family,
						action_kind = action_kind,
						direction = {x = tonumber(dir.x), y = tonumber(dir.y)},
						rotation = tonumber(base.rotation),
						variant = tonumber(base.variant),
						subtype = tonumber(base.subtype),
						cooldown = tonumber(base.cooldown),
						fire_sword_returned = true,
						sword_ptr = GetPtrHash(ent),
						anchor_ptr = handle and GetPtrHash(handle) or nil,
						sword_pos = {x = ent.Position.X, y = ent.Position.Y},
						anchor_pos = handle and {x = handle.Position.X, y = handle.Position.Y} or nil,
						ghost_pos = {x = ghost.Position.X, y = ghost.Position.Y},
						anchor_removecd = ad and ad.removecd or nil,
						sword_visible = ent.Visible,
						sword_anim = anim,
						sword_parent_alive = aeon_replay.entity_alive(ent.Parent),
					})
				end
			elseif sp.mode == "sword_action"
				or sp.kind == "sword_action"
				or sp.kind == "normal"
				or sp.kind == "spin"
				or sp.kind == "melee_swing"
				or sp.mode == "melee_swing"
			then
				local base = sp.base or {}
				local dir = base.direction or {}
				probe_emit("sword_spawn", {
					sf = tonumber(sp.start_frame),
					ef = tonumber(sp.end_frame),
					fire_sword_returned = false,
					action_kind = base.action_kind or sp.kind,
					direction = {x = tonumber(dir.x), y = tonumber(dir.y)},
					variant = tonumber(base.variant),
					subtype = tonumber(base.subtype),
					cooldown = tonumber(base.cooldown),
				})
			end
		end
		rp.special_index = rp.special_index + 1
	end

	-- Pure-visual character presentations (not live_specials / not combat entities).
	local still_presentations = {}
	for i = 1, #(rp.live_presentations or {}) do
		local handle = rp.live_presentations[i]
		if handle then
			local pose_fs = rec.frames[t]
			local next_pose_fs = rec.frames[t + 1]
			local finished = CharacterAttackCompat.update_replay_presentation(handle, {
				source = ghost,
				frame = t,
				pose = pose_fs and pose_fs.character_pose or nil,
				next_pose = next_pose_fs and next_pose_fs.character_pose or nil,
				pose_alpha = 0,
				canvas_center = rp.canvas_center,
			})
			if not handle._aeon_pres_update_emitted then
				handle._aeon_pres_update_emitted = true
				probe_emit("presentation_update", {
					finished = finished == true,
					t = t,
					age = handle.age,
					character_key = handle.character_key,
					has_pose = pose_fs and pose_fs.character_pose ~= nil,
				})
			elseif finished then
				probe_emit("presentation_update", {
					finished = true,
					t = t,
					age = handle.age,
					character_key = handle.character_key,
					has_pose = pose_fs and pose_fs.character_pose ~= nil,
				})
			end
			if finished then
				CharacterAttackCompat.end_replay_presentation(handle, "finished")
				probe_emit("presentation_end", {
					reason = "finished",
					t = t,
					character_key = handle.character_key,
				})
			else
				still_presentations[#still_presentations + 1] = handle
			end
		end
	end
	rp.live_presentations = still_presentations

	-- Drop finished/missing carriers; melee watchdog forces Remove after duration+grace.
	local still_specials = {}
	for i = 1, #(rp.live_specials or {}) do
		local live = rp.live_specials[i]
		if live then
			if live.melee then
				local deadline = tonumber(live.cleanup_frame) or t
				local still_here = aeon_replay.entity_alive(live.ent) or aeon_replay.entity_alive(live.handle)
				if still_here then
					aeon_replay.refresh_knife_handle_driver(live.handle, target, next_target)
				end
				if not still_here then
					probe_emit("melee_cleanup", {
						reason = "natural_dead",
						t = t,
						deadline = deadline,
					})
				elseif t >= deadline then
					-- Watchdog backup only.
					probe_emit("melee_cleanup", {
						reason = "watchdog",
						t = t,
						deadline = deadline,
						called = true,
					})
					aeon_replay.end_melee_swing(live.ent, live.handle, live.owned)
				else
					still_specials[#still_specials + 1] = live
				end
			elseif aeon_replay.entity_alive(live.ent) then
				still_specials[#still_specials + 1] = live
			end
		end
	end
	rp.live_specials = still_specials

	rp.t = t + 1
	if rp.t >= (rec.length or 0) then
		rp.fading = true
		rp.fade_age = 0
		rp.appearing = false
	end
end

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	params = nil,
	Function = function(_, continue)
		item.recording = nil
		item.replay = nil
		item.pending_replay = nil
		item.pending_record_start = nil
		item.played_rooms = {}
		item.record_owner = nil
		destroy_replay("game_start")
		if continue then
			item.record = load_record_from_save()
			if item.record then
				item.record.played_rooms = item.record.played_rooms or {}
				item.played_rooms = item.record.played_rooms
			else
				item.played_rooms = {}
			end
		else
			item.record = nil
			item.played_rooms = {}
			set_save_record(nil)
		end
	end,
})

-- Floor-boundary eternal cleanup: project canonical only.
-- Do NOT invent ModCallbacks.MC_PRE_NEW_LEVEL (does not exist).
table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_LEVEL,
	params = nil,
	Function = function(_)
		set_save_record(nil)
		clear_runtime_eternal()
		probe_emit("pre_new_level", item.debug_eternal_snapshot())
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function(_)
		local key = current_room_key()
		local snap = item.debug_eternal_snapshot()
		snap.room_key = key
		snap.pending = item.pending_replay ~= nil
		probe_emit("new_room", snap)
		-- 尚未真正开录：换房取消 pending（不产生半截 eternal）
		if item.pending_record_start then
			item.pending_record_start = nil
		end
		-- 录制期间换房：立刻固化已录内容，本房不播放
		if item.recording then
			finish_recording("room_change")
			return
		end
		if not item.record then return end
		if not key then return end
		if item.played_rooms[key] then return end
		item.pending_replay = {
			room_key = key,
		}
		probe_emit("replay_queued", {
			room_key = key,
			record_length = item.record.length,
			attack_count = type(item.record.attacks) == "table" and #item.record.attacks or 0,
		})
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function(_)
		if Game():IsPaused() then return end
		tick_pending_record_start()
		tick_recording()
		tick_echo_fade_out()
		try_start_pending_replay()
		tick_replay()
	end,
})

--- Mom's Knife is 60Hz; Aeon timeline is 30Hz. Drive MeusNil handle here only.
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_KNIFE_UPDATE,
	params = nil,
	Function = function(_, knife)
		if not knife then return end
		if Game():IsPaused() then return end
		if not item.replay then return end
		aeon_replay.tick_knife_handle_driver(knife)
	end,
})

local function recording_capacity_full(rec)
	return #(rec.attacks)
		+ #(rec.persistent_tracks or {})
		+ #(rec.special_events or {})
		>= item.max_recorded_attacks
end

--- Attack-level ownership: one character_action max per Attack (not per member generation).
local function is_character_owned_attack(rec, attack_id)
	if attack_id == nil or type(rec) ~= "table" then return false end
	rec.character_owned_attacks = rec.character_owned_attacks or {}
	return rec.character_owned_attacks[tostring(attack_id)] == true
end

local function mark_character_owned_attack(rec, event, attack)
	rec.character_owned_attacks = rec.character_owned_attacks or {}
	local attack_id = (event and event.attack_id) or (attack and attack.id)
	if attack_id ~= nil then
		rec.character_owned_attacks[tostring(attack_id)] = true
	end
	-- Keep id:generation key for existing notes / probes.
	if event then
		rec.character_owned_attacks[aeon_replay.attack_record_key(event)] = true
	elseif attack_id ~= nil then
		rec.character_owned_attacks[tostring(attack_id) .. ":0"] = true
	end
end

--- Shared Once + MEMBER_BOUND recorder. Returns true when Attack is character-owned.
local function try_record_character_action(rec, player, attack, event, frame)
	if not rec or not player or not attack then return false end
	local attack_id = (event and event.attack_id) or attack.id
	if is_character_owned_attack(rec, attack_id) then
		return true
	end
	local source = (event and event.attack_source) or attack.source
	if not classifier.IsPlayerAttackSource(source) then
		return false
	end
	local owner_idx = player_index(player)
	if owner_idx == nil or owner_idx ~= rec.owner_index then
		return false
	end
	local target = rec.target_length or item.record_frames_normal
	frame = tonumber(frame)
	if frame == nil then
		frame = Game():GetFrameCount() - rec.start_frame
	end
	if frame < 0 or frame >= target then return false end
	if recording_capacity_full(rec) then return false end

	local entry = CharacterAttackCompat.get(player)
	if not entry
		or not entry.capabilities
		or entry.capabilities.aeon_replay ~= true
		or not CharacterAttackCompat.has_snapshot_attack(player)
	then
		return false
	end

	local dir = (event and event.direction) or attack.direction
	local dir_tbl = nil
	if dir then
		if type(dir) == "table" then
			dir_tbl = {x = tonumber(dir.x or dir.X) or 0, y = tonumber(dir.y or dir.Y) or 0}
		elseif dir.X ~= nil then
			dir_tbl = {x = tonumber(dir.X) or 0, y = tonumber(dir.Y) or 0}
		end
	end
	local snap = CharacterAttackCompat.dispatch_snapshot_attack(player, {
		attack = attack,
		event = event,
		member = event and event.member,
		frame = frame,
		direction = dir_tbl,
		origin = player.Position,
	})
	if not snap then return false end

	local ev = aeon_replay.begin_character_action_event(
		player,
		entry.key,
		snap,
		frame,
		attack
	)
	if not ev then return false end

	mark_character_owned_attack(rec, event, attack)
	rec.next_sequence = (rec.next_sequence or 0) + 1
	ev.sequence = rec.next_sequence
	rec.special_events = rec.special_events or {}
	rec.special_events[#rec.special_events + 1] = ev
	probe_emit("character_action_recorded", {
		attack_id = attack_id,
		kind = snap.kind,
		character_key = entry.key,
		frame = frame,
		path = (event and event.member) and "member_bound" or "attack_once",
	})
	return true
end

--- Attack-level capture for member-less character actions (Tecro thrust).
table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_ATTACK_ONCE,
	params = nil,
	Function = function(_, event)
		local rec = item.recording
		if not rec then return end
		if not event or not event.player or not event.attack then return end
		local member = event.member
		if member then
			local d = member:GetData()
			if d and d[item.own_key .. "replay"] then return end
		end
		try_record_character_action(rec, event.player, event.attack, event, nil)
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_ATTACK_MEMBER_BOUND,
	params = nil,
	Function = function(_, event)
		local rec = item.recording
		if not rec then return end
		if not event or not event.member or not event.player then return end
		local member = event.member
		local d = member:GetData()
		if d[item.own_key .. "replay"] then return end
		if not classifier.IsPlayerAttackSource(event.attack_source) then return end
		local owner_idx = player_index(event.player)
		if owner_idx == nil or owner_idx ~= rec.owner_index then return end

		local frame = Game():GetFrameCount() - rec.start_frame
		local target = rec.target_length or item.record_frames_normal
		if frame < 0 or frame >= target then return end

		-- Character ownership before ordinary member classify (skip derived re-record).
		if is_character_owned_attack(rec, event.attack_id) then
			return
		end
		if try_record_character_action(rec, event.player, event.attack, event, frame) then
			return
		end

		if not aeon_replay.should_record_member(event.attack, member) then return end

		local key = tostring(event.attack_id) .. ":" .. tostring(event.generation) .. ":" .. tostring(GetPtrHash(member))
		if rec.seen_members[key] then return end
		rec.seen_members[key] = true

		if recording_capacity_full(rec) then
			return
		end

		local mode = aeon_replay.get_record_mode(member, event)

		-- Spirit Sword / Bone Club: POST_FIRE → normal sword_action only.
		-- Spin is owned by first non-spin→spin anim watch (not a second POST_FIRE).
		if mode == "sword_action" or mode == "melee_swing" then
			aeon_replay.note_sword_watch(rec, member)
			local anim_class = select(1, aeon_replay.classify_sword_anim(member))
			if anim_class == "spin" or anim_class == "charged" or anim_class == "idle" then
				return
			end
			if recording_capacity_full(rec) then
				return
			end
			rec.next_sequence = (rec.next_sequence or 0) + 1
			local ev = aeon_replay.begin_sword_action_event(member, event.player, event, frame, "normal")
			if not ev then return end
			ev.sequence = rec.next_sequence
			aeon_replay.finalize_melee_swing_event(ev, frame)
			aeon_replay.set_sword_visual_aim(rec, ev)
			rec.special_events = rec.special_events or {}
			rec.special_events[#rec.special_events + 1] = ev
			return
		end

		if recording_capacity_full(rec) then
			return
		end

		rec.next_sequence = (rec.next_sequence or 0) + 1
		local seq = rec.next_sequence

		if mode == "persistent" then
			local track = aeon_replay.begin_persistent_track(member, event.player, event, frame)
			if not track then return end
			track.sequence = seq
			rec.persistent_tracks = rec.persistent_tracks or {}
			rec.persistent_tracks[#rec.persistent_tracks + 1] = track
			rec.live_members = rec.live_members or {}
			rec.live_members[GetPtrHash(member)] = track
			return
		end

		if mode == "special" then
			local ev = aeon_replay.begin_special_event(member, event.player, event, frame)
			if not ev then return end
			ev.sequence = seq
			rec.special_events = rec.special_events or {}
			rec.special_events[#rec.special_events + 1] = ev
			rec.live_members = rec.live_members or {}
			rec.live_members[GetPtrHash(member)] = ev
			return
		end

		local snap = aeon_replay.snapshot_member(member, event.player, event)
		if not snap then return end
		snap.frame = frame
		snap.sequence = seq
		rec.attacks[#rec.attacks + 1] = snap
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_USE_CARD,
	params = item.entity,
	Function = function(_, cardtype, player, useFlags)
		if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
			return
		end
		local length = item.record_frames_normal
		local d = player:GetData()
		if d.tarot_cloth_used and d.tarot_cloth_used == cardtype then
			length = item.record_frames_cloth
		end
		request_recording(player, length)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_GAME_EXIT,
	params = nil,
	Function = function(_)
		-- 半段录像 / pending 不进存档；已完成的 item.record / save 备份保留
		item.recording = nil
		item.pending_record_start = nil
		item.pending_replay = nil
		-- Exit: drop Lua refs only. Engine tears down ghosts/entities.
		item.recording_echo = nil
		item.replay = nil
	end,
})

return item
