-- Player LightTravel drive + laser for Alien Savior.
-- Ordinary target suction lives in suction.lua (not this module).
local C = require("Qing_Remaster_scripts.items.alien_savior.constants")
local visual = require("Qing_Remaster_scripts.items.alien_savior.visual")
local motion = require("Qing_Remaster_scripts.items.alien_savior.motion")
local suction = require("Qing_Remaster_scripts.items.alien_savior.suction")
local laser_ctrl = require("Qing_Remaster_scripts.items.alien_savior.laser_controller")
local state = require("Qing_Remaster_scripts.items.alien_savior.state")
local enums = require("Qing_Remaster_scripts.core.enums")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")

local O = {}

local function alive(ent)
	return ent and ent.Exists and ent:Exists() and not ent:IsDead()
end

local function clamp01(t)
	if t < 0 then
		return 0
	end
	if t > 1 then
		return 1
	end
	return t
end

local function phase_progress(txn)
	local dur = math.max(1, txn.phase_dur or 1)
	return clamp01((txn.phase_frame or 0) / dur)
end

local function rewind_token(player, name, token, params)
	if token == nil then
		return true
	end
	return Attribute_holder.try_rewind_attribute(player, name, token, params) == true
end

local function player_matches_txn(player, txn)
	if not player or not txn then
		return false
	end
	if txn.player_hash and GetPtrHash(player) ~= txn.player_hash then
		return false
	end
	local d = player:GetData()
	if d and d.AlienSavior_txn ~= nil and d.AlienSavior_txn ~= txn.id then
		return false
	end
	return true
end

--- Last-resort ControlsEnabled restore. Never overrides another Attribute_holder claim.
local function restore_controls_with_fallback(player, txn, had_ctrl_token)
	local audit = {
		had_ctrl_token = had_ctrl_token == true,
		rewind_ok = txn and txn.ctrl_audit and txn.ctrl_audit.rewind_ok,
		token_valid = false,
		managed = false,
		effective = nil,
		before = player and player.ControlsEnabled,
		after = nil,
		fallback_applied = false,
		reason = "none",
	}
	if not player or not txn or not had_ctrl_token then
		audit.reason = "no_prior_hold"
		txn.ctrl_audit = audit
		return audit
	end
	if not player_matches_txn(player, txn) then
		audit.reason = "player_mismatch"
		txn.ctrl_audit = audit
		return audit
	end
	if player:IsDead() then
		audit.reason = "player_dead"
		txn.ctrl_audit = audit
		return audit
	end
	local token = txn.attr and txn.attr.ctrl
	audit.token_valid = token ~= nil and Attribute_holder.has_claim(player, "ControlsEnabled", token)
	if audit.token_valid then
		audit.reason = "token_still_held"
		txn.ctrl_audit = audit
		return audit
	end
	local effective, managed = Attribute_holder.get_effective_value(player, "ControlsEnabled")
	audit.managed = managed == true
	audit.effective = effective
	if managed then
		audit.reason = "other_manager"
		txn.ctrl_audit = audit
		return audit
	end
	if player.ControlsEnabled ~= false then
		audit.reason = "already_enabled"
		audit.after = player.ControlsEnabled
		txn.ctrl_audit = audit
		return audit
	end
	player.ControlsEnabled = true
	audit.fallback_applied = true
	audit.after = player.ControlsEnabled
	audit.reason = "unmanaged_false"
	txn.ctrl_audit = audit
	return audit
end

--- Rewind one attr field; keep token on failure if claim still live.
local function rewind_attr_field(player, txn, field, name, params)
	if not txn or not txn.attr then
		return true
	end
	local token = txn.attr[field]
	if token == nil then
		return true
	end
	local ok = rewind_token(player, name, token, params)
	if ok then
		txn.attr[field] = nil
		return true
	end
	if not Attribute_holder.has_claim(player, name, token) then
		-- Claim already gone; drop stale token.
		txn.attr[field] = nil
		return true
	end
	txn.attr_rewind_pending = true
	return false
end

local function stop_extra_anim(player)
	if player and player.StopExtraAnimation then
		pcall(function()
			player:StopExtraAnimation()
		end)
	end
end

local function clear_sprite_offset(player)
	if player then
		player.SpriteOffset = Vector.Zero
	end
end

local HOLD_PROTECT = { protect = true }

local function capture_frame_of(txn)
	if txn and txn.light_travel and txn.light_travel.capture_frame then
		return txn.light_travel.capture_frame
	end
	return motion.capture_frame()
end

--- Resolve LightTravel last frame from the live sprite after PlayExtraAnimation.
--- Falls back only to the verified ANM2 FrameNum-1 (never an unverified 35 blind guess alone).
local function resolve_last_frame(player, txn)
	local verified = C.LIGHTTRAVEL_LAST_FRAME or 35
	local s = player:GetSprite()
	if not s then
		return verified, "no_sprite"
	end
	if s.SetLastFrame then
		s:SetLastFrame()
	end
	local last = s.GetFrame and s:GetFrame() or nil
	local anim = (s.GetAnimation and s:GetAnimation()) or ""
	local overlay = (s.GetOverlayAnimation and s:GetOverlayAnimation()) or ""
	local name_ok = (anim == C.ANIM_NAME) or (overlay == C.ANIM_NAME)
	if type(last) == "number" and last >= 1 and name_ok then
		return last, "sprite"
	end
	if txn then
		txn.light_travel = txn.light_travel or {}
		txn.light_travel.last_frame_source = name_ok and "sprite_bad_frame" or "anim_mismatch"
		txn.light_travel.sprite_anim = anim
		txn.light_travel.sprite_overlay = overlay
		txn.light_travel.sprite_frame_read = last
	end
	return verified, "verified_anm2"
end

function O.begin_light_travel(txn, mode)
	txn.light_travel = {
		mode = mode or "capture", -- capture | release
		initialized = false,
		started = false,
		start_frame = 0,
		capture_frame = capture_frame_of(txn),
		current_frame = 0,
		last_frame = C.LIGHTTRAVEL_LAST_FRAME or 35,
		last_frame_source = nil,
		expected_frame = 0,
		lift_target_y = 0,
	}
	if mode == "release" then
		txn.light_travel.current_frame = txn.light_travel.capture_frame
		txn.light_travel.expected_frame = txn.light_travel.capture_frame
	end
	txn.light_anim_started = nil -- legacy flag; ownership is light_travel now
end

local function maintain_light_travel_anim(player, txn)
	local lt = txn.light_travel
	if not lt then
		return
	end
	-- Day Dreamer pattern: re-assert ExtraAnimation every player update, then SetFrame.
	-- Do not call AnimateLightTravel here — it fights scrubbing.
	player:PlayExtraAnimation(C.ANIM_NAME)
	if not lt.started then
		local last, src = resolve_last_frame(player, txn)
		lt.last_frame = last
		lt.last_frame_source = src
		local cap = math.min(lt.capture_frame or motion.capture_frame(), last)
		lt.capture_frame = cap
		lt.started = true
		lt.initialized = true
	end
end

--- progress 0..1 within the current capture/release phase.
--- reverse=false: frame 0 → capture_frame; reverse=true: capture_frame → 0.
function O.drive_light_travel(player, txn, progress, reverse)
	if not player or not txn or txn.player_released then
		return 0, 0
	end
	progress = clamp01(progress or 0)
	local mode = reverse and "release" or "capture"
	if not txn.light_travel or txn.light_travel.mode ~= mode then
		O.begin_light_travel(txn, mode)
	end
	maintain_light_travel_anim(player, txn)
	local lt = txn.light_travel
	local cap = lt.capture_frame or motion.capture_frame()
	local frame = math.floor(progress * cap + 1e-6)
	if reverse then
		frame = cap - frame
	end
	if frame < 0 then
		frame = 0
	elseif frame > cap then
		frame = cap
	end
	local s = player:GetSprite()
	if s and s.SetFrame then
		s:SetFrame(C.ANIM_NAME, frame)
	end
	lt.current_frame = frame
	lt.expected_frame = frame
	txn.light_frame = frame
	txn.light_last = lt.last_frame
	return frame, lt.last_frame or cap
end

--- Grant a short post-release i-frames window without stomping longer legitimate cooldowns.
--- Mirrors Item_Chasm / Blood Wing: SetMinDamageCooldown(want - GetDamageCooldown()).
local function ensure_short_damage_cooldown(player, want_frames)
	if not player or not player.SetMinDamageCooldown or not player.GetDamageCooldown then
		return
	end
	want_frames = math.max(0, math.floor(tonumber(want_frames) or 0))
	local cur = player:GetDamageCooldown() or 0
	player:SetMinDamageCooldown(math.max(0, want_frames - cur))
end

--- One-shot snapshot. No-op after player_released (idempotent terminal).
--- Damage immunity during rescue is MC_ENTITY_TAKE_DMG via protects_player — not a 9999 cooldown.
function O.lock_player(player, txn)
	if not player or not txn or txn.player_released then
		return
	end
	player.Velocity = Vector.Zero
	local d = player:GetData()
	d.AlienSavior_locked = true
	d.AlienSavior_txn = txn.id

	if txn.attr_captured ~= true then
		txn.attr_captured = true
		txn.attr = {
			ctrl = Attribute_holder.try_hold_attribute(player, "ControlsEnabled", false, HOLD_PROTECT),
			coll = Attribute_holder.try_hold_attribute(player, "EntityCollisionClass", EntityCollisionClass.ENTCOLL_NONE, HOLD_PROTECT),
			grid = Attribute_holder.try_hold_attribute(player, "GridCollisionClass", EntityGridCollisionClass.GRIDCOLL_NONE, HOLD_PROTECT),
			visible = nil,
		}
		txn.had_ctrl_hold = txn.attr.ctrl ~= nil
		txn.park_pos = Vector(player.Position.X, player.Position.Y)
	elseif txn.attr then
		-- Re-hold only when our claim is missing; never stack a second ControlsEnabled claim.
		Attribute_holder.ensure_hold_token(player, txn.attr, "ctrl", "ControlsEnabled", false, HOLD_PROTECT)
		Attribute_holder.ensure_hold_token(player, txn.attr, "coll", "EntityCollisionClass", EntityCollisionClass.ENTCOLL_NONE, HOLD_PROTECT)
		Attribute_holder.ensure_hold_token(player, txn.attr, "grid", "GridCollisionClass", EntityGridCollisionClass.GRIDCOLL_NONE, HOLD_PROTECT)
		if txn.attr.ctrl ~= nil then
			txn.had_ctrl_hold = true
		end
	end
end

--- Cabin world position while player is stowed (follows UFO).
function O.cabin_world_pos(txn)
	return motion.player_cabin_world_pos(txn)
end

--- Keep hidden player at UFO cabin. Does not rewrite park_pos (capture LightTravel anchor).
function O.sync_cabin_position(player, txn)
	if not player or not txn or txn.player_released then
		return
	end
	if not txn.player_stowed then
		return
	end
	local cabin = O.cabin_world_pos(txn)
	player.Position = cabin
	player.Velocity = Vector.Zero
	clear_sprite_offset(player)
end

function O.stow_player(player, txn)
	if not player or not txn or txn.player_released then
		return
	end
	O.lock_player(player, txn)
	txn.attr = txn.attr or {}
	if txn.attr.visible == nil then
		txn.attr.visible = Attribute_holder.try_hold_attribute(player, "Visible", false, HOLD_PROTECT)
	end
	clear_sprite_offset(player)
	stop_extra_anim(player)
	txn.player_stowed = true
	local d = player:GetData()
	d.AlienSavior_hidden = true
	-- Follow UFO cabin from the moment of stow (not frozen park_pos).
	O.sync_cabin_position(player, txn)
end

function O.unstow_visible(player, txn)
	if not player or not txn or not txn.attr then
		return
	end
	if txn.attr.visible ~= nil then
		rewind_token(player, "Visible", txn.attr.visible)
		txn.attr.visible = nil
	end
	local d = player:GetData()
	d.AlienSavior_hidden = nil
	txn.player_stowed = false
end

--- Idempotent release of UFO-owned player holds + LightTravel.
--- Failed Attribute_holder rewinds keep their tokens for bounded retry; never blank the table blindly.
function O.unlock_player(player, txn)
	if not player then
		return
	end
	if txn and txn.player_released and txn.attr == nil then
		return
	end
	-- Top-up only; never treat SetMinDamageCooldown(N) as overwriting a leftover 9999.
	ensure_short_damage_cooldown(player, C.POST_RELEASE_SAFE or 30)
	clear_sprite_offset(player)
	stop_extra_anim(player)

	local had_ctrl = false
	if txn then
		had_ctrl = txn.had_ctrl_hold == true or (txn.attr ~= nil and txn.attr.ctrl ~= nil)
	end

	local ctrl_ok = true
	if txn and txn.attr then
		ctrl_ok = rewind_attr_field(player, txn, "ctrl", "ControlsEnabled")
		rewind_attr_field(player, txn, "coll", "EntityCollisionClass")
		rewind_attr_field(player, txn, "grid", "GridCollisionClass")
		rewind_attr_field(player, txn, "visible", "Visible")
		txn.player_stowed = false
		if txn.ctrl_audit == nil then
			txn.ctrl_audit = {}
		end
		txn.ctrl_audit.rewind_ok = ctrl_ok
		-- Drop empty attr table only when every field cleared.
		local any = false
		for _, v in pairs(txn.attr) do
			if v ~= nil then
				any = true
				break
			end
		end
		if not any then
			txn.attr = nil
			txn.attr_captured = nil
			txn.attr_rewind_pending = nil
		end
	end

	if txn and had_ctrl then
		restore_controls_with_fallback(player, txn, true)
	end

	local d = player:GetData()
	d.AlienSavior_locked = nil
	-- Keep txn id on player only while attr rewind still pending.
	if not (txn and txn.attr) then
		d.AlienSavior_txn = nil
	end
	d.AlienSavior_hidden = nil
	if txn then
		txn.player_released = true
		txn.light_anim_started = nil
		txn.light_travel = nil
		-- After leaving the UFO: temporary Alien_Head until rescue is READY again.
		if txn.pkey then
			state.set_alien_head(txn.pkey, true)
		end
		O.sync_alien_head_costume(player)
	end
end

--- Temporary null costume (not item-bound). On while COOLDOWN+flag; off when READY.
function O.sync_alien_head_costume(player)
	if not player or not player.ToPlayer then
		return
	end
	player = player:ToPlayer()
	if not player then
		return
	end
	local costume = enums.Costumes and enums.Costumes.Alien_Head
	if costume == nil or costume < 0 then
		return
	end
	local pkey = state.player_key(player)
	local want = state.wants_alien_head(pkey)
	local d = player:GetData()
	local applied = d.AlienSavior_head_costume == true
	if want and not applied then
		player:AddNullCostume(costume)
		d.AlienSavior_head_costume = true
	elseif not want and applied then
		player:TryRemoveNullCostume(costume)
		d.AlienSavior_head_costume = nil
	end
end

--- Bounded retry for tokens that failed to rewind at unlock time. Safe after player_released.
function O.retry_pending_attr_rewind(player, txn)
	if not player or not txn or not txn.attr then
		return false
	end
	if not player_matches_txn(player, txn) then
		return false
	end
	txn.attr_rewind_attempts = (txn.attr_rewind_attempts or 0) + 1
	if txn.attr_rewind_attempts > 30 then
		-- Give up keeping tokens; still try ctrl fallback once more.
		if txn.attr.ctrl ~= nil and not Attribute_holder.has_claim(player, "ControlsEnabled", txn.attr.ctrl) then
			txn.attr.ctrl = nil
		end
		restore_controls_with_fallback(player, txn, txn.had_ctrl_hold == true)
		return false
	end
	rewind_attr_field(player, txn, "ctrl", "ControlsEnabled")
	rewind_attr_field(player, txn, "coll", "EntityCollisionClass")
	rewind_attr_field(player, txn, "grid", "GridCollisionClass")
	rewind_attr_field(player, txn, "visible", "Visible")
	if txn.had_ctrl_hold then
		restore_controls_with_fallback(player, txn, true)
	end
	local any = false
	for _, v in pairs(txn.attr) do
		if v ~= nil then
			any = true
			break
		end
	end
	if not any then
		txn.attr = nil
		txn.attr_captured = nil
		txn.attr_rewind_pending = nil
		local d = player:GetData()
		if d then
			d.AlienSavior_txn = nil
		end
		return true
	end
	return false
end

function O.get_control_audit(player, txn)
	txn = txn or {}
	player = player or txn.player
	local attr = txn.attr
	local token = attr and attr.ctrl
	local effective, managed = nil, false
	if player then
		effective, managed = Attribute_holder.get_effective_value(player, "ControlsEnabled")
	end
	local ca = txn.ctrl_audit or {}
	return {
		ControlsEnabled = player and player.ControlsEnabled,
		ControlsCooldown = player and player.ControlsCooldown,
		ctrl_token = token,
		ctrl_claim_active = player and token ~= nil and Attribute_holder.has_claim(player, "ControlsEnabled", token) or false,
		rewind_result = ca.rewind_ok,
		fallback_applied = ca.fallback_applied == true,
		fallback_reason = ca.reason,
		managed = managed == true,
		effective = effective,
		attr_captured = txn.attr_captured == true,
		attr_pending = txn.attr ~= nil,
		had_ctrl_hold = txn.had_ctrl_hold == true,
		player_released = txn.player_released == true,
		active_rescue = true,
	}
end

function O.is_protected(player)
	local d = player and player:GetData()
	return d and d.AlienSavior_locked == true
end

function O.update_abduct_player(txn, player)
	if not txn or not player or txn.player_released then
		return
	end
	O.lock_player(player, txn)
	local beam = require("Qing_Remaster_scripts.items.alien_savior.beam")
	local origin = txn.player_origin or txn.park_pos or player.Position
	player.Position = origin
	player.Velocity = Vector.Zero
	clear_sprite_offset(player)
	txn.beam_foot = origin
	-- Hold LightTravel until pickup beam is fully open (ARRIVING should finish open).
	if not beam.is_open_enough(txn, 0.92) then
		if txn.light_travel then
			txn.light_travel.waiting_beam = true
		end
		return
	end
	local progress = phase_progress(txn)
	O.drive_light_travel(player, txn, progress, false)
	if progress >= 1 then
		O.stow_player(player, txn)
		txn.beam_foot = txn.park_pos or origin
	end
end

function O.update_release_player(txn, player)
	if not txn or not player then
		return
	end
	if txn.player_released then
		return
	end
	O.lock_player(player, txn)
	local beam = require("Qing_Remaster_scripts.items.alien_savior.beam")
	local dest = txn.release_pos or txn.player_origin or player.Position
	local seg = beam.release_segment(txn)

	-- Keep captive during travel/settle; still ride UFO cabin. Drop only when drop starts.
	if seg == "travel" or seg == "settle" then
		if not txn.player_stowed then
			O.stow_player(player, txn)
		else
			O.sync_cabin_position(player, txn)
		end
		-- Beam foot tracks release pad; player body stays at cabin until drop.
		txn.beam_foot = dest
		return
	end

	-- drop / close: place at release_pos and restore visibility for LightTravel reverse.
	O.unstow_visible(player, txn)
	player.Position = dest
	player.Velocity = Vector.Zero
	clear_sprite_offset(player)
	txn.beam_foot = dest

	if seg == "drop" then
		local progress = beam.release_drop_progress(txn)
		O.drive_light_travel(player, txn, progress, true)
		if progress >= 1 and not txn.release_unlocked then
			player.Position = dest
			O.unlock_player(player, txn)
			txn.release_unlocked = true
		end
		return
	end

	-- close: player already unlocked after drop; keep feet parked.
	if not txn.player_released then
		player.Position = dest
		O.unlock_player(player, txn)
		txn.release_unlocked = true
	end
end

function O.get_light_travel_audit(player, txn)
	txn = txn or {}
	local lt = txn.light_travel or {}
	local s = player and player:GetSprite()
	local finished = nil
	if player and player.IsExtraAnimationFinished then
		finished = player:IsExtraAnimationFinished()
	end
	return {
		mode = lt.mode,
		started = lt.started == true,
		initialized = lt.initialized == true,
		anim = s and s.GetAnimation and s:GetAnimation() or nil,
		overlay = s and s.GetOverlayAnimation and s:GetOverlayAnimation() or nil,
		sprite_frame = s and s.GetFrame and s:GetFrame() or nil,
		expected_frame = lt.expected_frame or txn.light_frame,
		capture_frame = lt.capture_frame or motion.capture_frame(),
		last_frame = lt.last_frame or txn.light_last,
		last_frame_source = lt.last_frame_source,
		extra_finished = finished,
		visible = player and player.Visible,
		stowed = txn.player_stowed == true,
		released = txn.player_released == true,
		sprite_offset_y = player and player.SpriteOffset and player.SpriteOffset.Y or 0,
		lift_target_y = lt.lift_target_y,
		pos = player and { x = player.Position.X, y = player.Position.Y } or nil,
		origin = txn.player_origin and { x = txn.player_origin.X, y = txn.player_origin.Y } or nil,
		park_pos = txn.park_pos and { x = txn.park_pos.X, y = txn.park_pos.Y } or nil,
		release_pos = txn.release_pos and { x = txn.release_pos.X, y = txn.release_pos.Y } or nil,
		ufo_pos = (function()
			local p = motion.ufo_world_pos(txn)
			return p and { x = p.X, y = p.Y } or nil
		end)(),
		player_cabin_pos = (function()
			local p = O.cabin_world_pos(txn)
			return p and { x = p.X, y = p.Y } or nil
		end)(),
	}
end

--- Restore player holds. Relocate only if still captive (not yet released).
function O.force_restore_player(txn)
	if not txn then
		return
	end
	local player = txn.player
	if not (player and player.Exists and player:Exists()) then
		if txn then
			txn.player_released = true
		end
		return
	end
	if txn.player_released and txn.attr == nil then
		return
	end
	if not txn.player_released then
		local dest = txn.release_pos or txn.park_pos or txn.player_origin
		if dest then
			player.Position = dest
		end
	end
	O.unlock_player(player, txn)
end

function O.classify_npc(npc)
	local policy = require("Qing_Remaster_scripts.items.alien_savior.suction_policy")
	return policy.classify_npc(npc)
end

function O.cleanup_rescue_entities(txn)
	suction.abort(txn)
	laser_ctrl.cleanup(txn, "rescue_cleanup")
end

--- V10: real laser array (no TakeDamage queue). Kept name for controller call sites.
function O.begin_laser_sweep(txn, player)
	return laser_ctrl.begin(txn, player or txn.player)
end

function O.update_laser(txn, player)
	laser_ctrl.update(txn, player or txn.player)
	local origin = laser_ctrl.main_origin(txn)
	txn.laser_from = origin
	txn.laser_to = origin
end

--- @deprecated Target queue removed in V10; retained as no-op for old probe calls.
function O.refresh_laser_queue(_txn)
end

function O.pick_release_pos(txn)
	local room = Game():GetRoom()
	-- Prefer a safe tile near room center (work site), not the original edge pickup.
	local center = (txn.work_feet) or room:GetCenterPos()
	if room:IsPositionInRoom(center, 0) and room:GetGridCollisionAtPos(center) == GridCollisionClass.COLLISION_NONE then
		return Vector(center.X, center.Y)
	end
	for r = 0, 100, 20 do
		for a = 0, 315, 45 do
			local rad = math.rad(a)
			local p = center + Vector(math.cos(rad) * r, math.sin(rad) * r)
			if room:IsPositionInRoom(p, 0) and room:GetGridCollisionAtPos(p) == GridCollisionClass.COLLISION_NONE then
				return p
			end
		end
	end
	local origin = txn.player_origin or txn.park_pos
	if origin and room:IsPositionInRoom(origin, 0) and room:GetGridCollisionAtPos(origin) == GridCollisionClass.COLLISION_NONE then
		return origin
	end
	return room:GetCenterPos()
end

return O
