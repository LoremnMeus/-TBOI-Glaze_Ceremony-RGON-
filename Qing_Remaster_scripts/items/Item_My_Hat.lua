local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local head_anchor = require("Qing_Remaster_scripts.auxiliary.entity_head_anchor")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")

local item = {
	ToCall = {},
	pre_ToCall = {},
	myToCall = {},
	entity = enums.Items.My_Hat,
	own_key = "Item_My_Hat_",
	hat_anm2 = "gfx/mimics/My_Hat/Hat.anm2",
	hat_costume = Isaac.GetCostumeIdByPath("gfx/characters/Qingrobes.anm2"),
	player_head_offset = Vector(0,-22),
	cover_offset = Vector(0,8),
	cover_padding_y = 0,
	windup_frames = 6,
	launch_speed = 11,
	flight_max_speed = 23,
	flight_acceleration = 2.6,
	rise_gravity = 0.82,
	fall_gravity = 1.18,
	launch_air_velocity = 9.2,
	descend_drag = 0.975,
	max_flight_distance = 410,
	max_flight_frames = 45,
	attack_range = 410,
	attack_corridor_half_width = 55,
	head_align_radius = 40,
	head_align_snap_radius = 24,
	head_align_frames = 4,
	landing_hold_height = 14,
	descend_speed_far = 17,
	descend_speed_mid = 13,
	descend_speed_near = 8,
	align_speed = 5,
	steer_far = 0.10,
	steer_mid = 0.22,
	steer_near = 0.42,
	steer_align = 0.70,
	target_apex_ratio = 0.55,
	target_apex_min = 12,
	target_apex_margin = 16,
	-- TARGET_DESCEND only. HEAD_ALIGN is committed and does not use this timeout.
	target_phase_timeout = 120,
	impact_frames = 4,
	impact_scales = {
		Vector(1.12,0.84),Vector(0.95,1.10),Vector(1.04,0.97),Vector(1,1),
	},
	return_launch_frames = 3,
	return_launch_speed = 9,
	return_air_velocity = 7.5,
	return_max_speed = 20,
	return_turn_rate = 0.18,
	return_near_turn_rate = 0.34,
	return_near_radius = 55,
	return_gravity = 0.9,
	-- Visual-only Size scale for attached hat (does not change defence_radius).
	hat_size_base = 20,
	hat_size_max_scale = 1.75,
	return_shrink_frames = 8,
	reattach_radius = 18,
	reattach_frames = 5,
	-- MC_POST_PLAYER_UPDATE is 60 Hz: 8 ≈ 0.13s so reattach is visible before rethrow.
	refire_cooldown_frames = 8,
	spin_min = 0.018,
	spin_max = 0.065,
	windup_spin = 0.010,
	spin_response = 0.20,
	launch_stretch = Vector(0.92,1.10),
	rise_scale_x = 0.03,
	rise_scale_y = 0.06,
	fall_scale_x = 0.055,
	fall_scale_y = 0.045,
	scale_response = 0.30,
	afterimage_interval = 3,
	afterimage_life = 5,
	defence_radius = 24,
	cover_frames = 90,
	-- Boss uses Attribute_holder for slowdown/color, but shares the same cover duration.
	cover_frame = 4,
	slow_amount = 0.6,
	-- Boss: composable time-scale + light whitish Color claim via Attribute_holder.
	boss_slow_multiplier = 0.6,
	boss_slow_color = Color(1, 1, 1, 1, 0.12, 0.12, 0.12),
	-- Visual release after cover ends while host is hidden (gameplay already finished).
	return_visible_settle_frames = 3,
	return_wait_max_frames = 45,
	return_invalid_settle_frames = 3,
	-- Front spin frames only (ANM2 Idle 0..6). Back layer is fixed crop and never indexed.
	spin_weights = {
		1.90,
		1.00,
		0.85,
		1.00,
		1.45,
		0.85,
		1.00,
	},
	hat_back_layer = 0,
	hat_front_layer = 1,
	debug_hat_anchor = false,
	runtime_key = "Item_My_Hat_Runtime",
	effect_key = "Item_My_Hat_Effect",
	next_hat_token = 0,
	attached_hats = {},
}

-- Detached visual for IMPACT/COVER sandwich. Never use effect:GetSprite() in NPC render.
local attached_hat_sprite = Sprite()
attached_hat_sprite:Load(item.hat_anm2, true)
attached_hat_sprite:Play("Idle", true)
item.attached_hat_sprite = attached_hat_sprite

local COVERED_TOKEN_KEY = item.own_key .. "covered_hat_token"
local BOSS_SLOW_TOKEN_KEY = item.own_key .. "boss_slow_token"
local BOSS_COLOR_TOKEN_KEY = item.own_key .. "boss_slow_color_token"

local function exists(entity)
	return auxi.check_all_exists(entity)
end

local function has_hat(player)
	return auxi.has_have_coll(player,item.entity)
end

local function get_runtime(player,create)
	local data = player:GetData()
	local runtime = data[item.runtime_key]
	if not runtime and create then
		runtime = {
			state = "WORN",
			refire_cooldown = 0,
			costume_visible = false,
		}
		data[item.runtime_key] = runtime
	end
	return runtime
end

local function set_hat_costume(player,runtime,visible)
	if visible and not runtime.costume_visible then
		player:AddNullCostume(item.hat_costume)
		runtime.costume_visible = true
	elseif not visible and runtime.costume_visible then
		player:TryRemoveNullCostume(item.hat_costume)
		runtime.costume_visible = false
	end
end

local function player_hat_offset(player)
	return (player.PositionOffset or Vector.Zero) + item.player_head_offset
end

-- Coordinate types (see codex_work/notes/render_coordinate_contract.md):
--   Entity.Position          = entity world
--   Entity.PositionOffset    = ENTITY_PROJECTED_OFFSET (INSIDE Position+PO before W2R/W2S)
--   pose.position            = Sprite-local render delta (AFTER projection)
--   NPC callback offset      = callback-local only (draw path; never handoff)
-- Custom Sprite → native Entity handoff only:
--   RenderToWorld(WorldToScreen(Position + PositionOffset) + sprite_local_anchor)
local function entity_visual_to_world(position, position_offset, local_render_offset)
	if not Isaac.RenderToWorld or not Isaac.WorldToScreen then
		return position
	end
	local screen = Isaac.WorldToScreen(
		position + (position_offset or Vector.Zero)
	) + (local_render_offset or Vector.Zero)
	local world = Isaac.RenderToWorld(screen)
	return world or position
end

local function get_shooting_input(player)
	if player.GetShootingInput then
		local direction = player:GetShootingInput()
		if direction and direction:Length() > 0.1 then
			return direction:Normalized()
		end
	end
	local fire_direction = player:GetFireDirection()
	if fire_direction == Direction.LEFT then return Vector(-1,0) end
	if fire_direction == Direction.RIGHT then return Vector(1,0) end
	if fire_direction == Direction.UP then return Vector(0,-1) end
	if fire_direction == Direction.DOWN then return Vector(0,1) end
	return Vector.Zero
end

local function find_player(owner_hash)
	for index = 0,Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(index)
		if GetPtrHash(player) == owner_hash then return player end
	end
end

local function lerp_vector(from,to,amount)
	return from + (to - from) * amount
end

local function lerp_scalar(from, to, amount)
	return (tonumber(from) or 0) + ((tonumber(to) or 0) - (tonumber(from) or 0)) * amount
end

local function ease_in_out(amount)
	return amount * amount * (3 - 2 * amount)
end

-- Shortest-path angle lerp (degrees).
local function lerp_angle(a, b, t)
	a = tonumber(a) or 0
	b = tonumber(b) or 0
	t = tonumber(t) or 0
	local delta = ((b - a + 180) % 360) - 180
	return a + delta * t
end

-- Visual-only attached hat scale from Entity.Size. Never shrinks below 1; capped.
-- Does not change defence_radius / slow / duration / hit detection.
local function attached_hat_size_scale(target)
	local size = tonumber(target and target.Size) or item.hat_size_base
	local base = item.hat_size_base or 20
	local max_scale = item.hat_size_max_scale or 1.75
	return math.max(1, math.min(max_scale, math.sqrt(math.max(base, size) / base)))
end

local function set_spin_frame(effect,info,phase)
	phase = phase % 1
	local total = 0
	for _,weight in ipairs(item.spin_weights) do total = total + weight end
	local position = phase * total
	local accumulator = 0
	local frame = 0
	for index,weight in ipairs(item.spin_weights) do
		accumulator = accumulator + weight
		if position < accumulator then
			frame = index - 1
			break
		end
	end
	info.spin_phase = phase
	info.spin_frame = frame
	effect:GetSprite():SetFrame("Idle",frame)
end

local function update_spin(effect,info,desired_spin)
	info.spin_velocity = (info.spin_velocity or 0)
		+ (desired_spin - (info.spin_velocity or 0)) * item.spin_response
	set_spin_frame(effect,info,(info.spin_phase or 0) + info.spin_velocity)
end

local function update_motion_scale(effect,info,mode)
	local desired = Vector.One
	if mode == "RISE" then
		local base = math.max(0.1,info.launch_air_velocity or item.launch_air_velocity)
		local ratio = math.min(1,math.max(0,(info.air_velocity or 0) / base))
		desired = Vector(1 - item.rise_scale_x * ratio,1 + item.rise_scale_y * ratio)
	elseif mode == "DESCEND" then
		local ratio = math.min(1,math.max(0,-(info.air_velocity or 0) / 10))
		desired = Vector(1 + item.fall_scale_x * ratio,1 - item.fall_scale_y * ratio)
	elseif mode == "RETURN_LAUNCH" then
		desired = Vector(0.95,1.07)
	elseif mode == "RETURN" then
		local ratio = math.min(1,effect.Velocity:Length() / item.return_max_speed)
		desired = Vector(1 + 0.03 * ratio,1 - 0.02 * ratio)
	end
	-- finalScale = motionScale * sizeMultiplier (Size never owns SpriteScale alone).
	local size_mul = tonumber(info.size_multiplier) or 1
	local target_scale = Vector(desired.X * size_mul, desired.Y * size_mul)
	effect.SpriteScale = lerp_vector(effect.SpriteScale,target_scale,item.scale_response)
end

local function set_visual_scale(effect, info, motion_scale)
	local size_mul = tonumber(info and info.size_multiplier) or 1
	local motion = motion_scale or Vector.One
	effect.SpriteScale = Vector(motion.X * size_mul, motion.Y * size_mul)
end

local function block_projectiles(center,flash_entity)
	for _,entity in ipairs(Isaac.FindByType(EntityType.ENTITY_PROJECTILE,-1,-1,false,false)) do
		local projectile = entity:ToProjectile()
		if projectile and (projectile.Position + projectile.PositionOffset - center):Length()
			<= item.defence_radius + projectile.Size then
			projectile:Remove()
			flash_entity:SetColor(Color(1.25,1.25,1.25,1,0.2,0.2,0.2),3,10,true,false)
		end
	end
end

-- Sprite-local Render Pose (position + rotation). Never write into Entity.PositionOffset.
-- My Hat is a rigid head attachment.
-- Use the current formal head pose directly; do not apply cross-frame
-- smoothing/EMA here. Motion smoothing causes visible lag during valid
-- animated head movement. Gospel halo EMA is a floating VFX policy, not a
-- shared head-anchor rule.
local function get_enemy_head_pose(target, info)
	info.head_anchor = info.head_anchor or {}
	local pose = head_anchor.GetEntityHeadPose(target, {
		top = true,
		centerX = true,
		paddingY = item.cover_padding_y,
		lockData = info.head_anchor,
	})
	if pose.visible == false then
		return {
			visible = false,
			hidden_reason = pose.hidden_reason,
			position = nil,
			rotation = nil,
			flip_x = pose.flip_x == true,
			flip_y = pose.flip_y == true,
			source = pose.source,
			layer_id = pose.layer_id,
			rotation_source = pose.rotation_source,
			scalp_scan_state = pose.scalp_scan_state,
			cover_offset_rotated = nil,
		}
	end
	local rotation = pose.rotation or 0
	-- cover_offset is head-local "push into scalp"; rotate with pose.
	local cover = Vector(item.cover_offset.X, item.cover_offset.Y):Rotated(rotation)
	return {
		visible = true,
		hidden_reason = nil,
		position = (pose.position or Vector.Zero) + cover,
		rotation = rotation,
		flip_x = pose.flip_x == true,
		flip_y = pose.flip_y == true,
		source = pose.source,
		layer_id = pose.layer_id,
		rotation_source = pose.rotation_source,
		scalp_scan_state = pose.scalp_scan_state,
		cover_offset_rotated = cover,
	}
end

local function cached_enemy_head_pose(target, info)
	local frame = Isaac.GetFrameCount()
	if info.head_pose_frame ~= frame or not info.head_pose then
		info.head_pose = get_enemy_head_pose(target, info)
		info.head_pose_frame = frame
		if item.debug_hat_anchor then
			info.debug_head_source = info.head_pose.source or "?"
			info.debug_head_layer = info.head_pose.layer_id or -1
			info.debug_head_overlay = false
		end
	end
	return info.head_pose
end

-- Attached hat render position WITHOUT NPC callback offset.
-- Canonical entity-callback overlay: W2R(Position+PO) + pose (see render_coordinate_contract).
-- Handoff does NOT reuse this path; it uses entity_visual_to_world (W2S→RenderToWorld).
local function attached_hat_visual_render_pos(target, info)
	local pose = cached_enemy_head_pose(target, info)
	if not pose or pose.visible == false or not pose.position then
		return nil
	end
	local final_pos = Isaac.WorldToRenderPosition(
		target.Position + (target.PositionOffset or Vector.Zero)
	) + pose.position
	if info.state == "IMPACT" and info.impact_start_world then
		local progress = math.min(1, (info.age or 0) / item.impact_frames)
		local start_pos = Isaac.WorldToRenderPosition(info.impact_start_world)
		return lerp_vector(start_pos, final_pos, ease_in_out(progress))
	end
	return final_pos
end

local function get_enemy_hat_render_pos(target, info, callback_offset)
	local pos = attached_hat_visual_render_pos(target, info)
	if not pos then
		pos = Isaac.WorldToRenderPosition(
			target.Position + (target.PositionOffset or Vector.Zero)
		)
	end
	-- callback offset is callback-only; never stored into world handoff.
	return pos + (callback_offset or Vector.Zero)
end

local function get_attached_hat_rotation(target, info)
	local pose = cached_enemy_head_pose(target, info)
	local target_rotation = pose.rotation or 0
	if info.state ~= "IMPACT" then
		return target_rotation
	end
	local progress = math.min(1, (info.age or 0) / item.impact_frames)
	return lerp_angle(
		info.impact_start_rotation or 0,
		target_rotation,
		ease_in_out(progress)
	)
end

-- IMPACT blends free-hat visual → head anchor; callback offset applied only here.
local function get_attached_hat_render_pos(target, info, callback_offset)
	return get_enemy_hat_render_pos(target, info, callback_offset)
end

-- IMPACT / COVER: gameplay cover + sandwich render.
local function is_gameplay_cover_state(state)
	return state == "IMPACT" or state == "COVER"
end

-- Sandwich render only (RETURN_WAIT keeps token but must not draw).
local function is_attached_hat_state(state)
	return state == "IMPACT" or state == "COVER"
end

local function ensure_attach_token(info)
	if not info.attach_token then
		item.next_hat_token = item.next_hat_token + 1
		info.attach_token = item.next_hat_token
	end
	return info.attach_token
end

-- NPC data stores only a number token. Registry holds pure Lua render snapshot (no Effect userdata).
local function bind_hat_target(effect, info, target)
	if not exists(target) or not info then return end
	local token = ensure_attach_token(info)
	target:GetData()[COVERED_TOKEN_KEY] = token
	item.attached_hats[token] = {
		info = info,
		scale = auxi.ProtectVector(effect.SpriteScale or Vector.One),
		target_ptr = GetPtrHash(target),
	}
end

local function refresh_attached_render(effect, info)
	local token = info and info.attach_token
	local rec = token and item.attached_hats[token]
	if not rec then return end
	rec.info = info
	rec.scale = auxi.ProtectVector(effect.SpriteScale or Vector.One)
	-- Cheap effect pose for DebugGetAttachedHatInfo (no head scan).
	rec.debug_effect = {
		position = auxi.ProtectVector(effect.Position),
		position_offset = auxi.ProtectVector(effect.PositionOffset or Vector.Zero),
		visible = effect.Visible == true,
	}
end

local function store_attached_debug_snapshot(npc, info, rec, pose, rotation, render_pos, callback_offset)
	if not rec or not info then
		return
	end
	local gf = -1
	pcall(function()
		gf = Game():GetFrameCount()
	end)
	rec.debug_snapshot = {
		game_frame = gf,
		state = info.state,
		token = info.attach_token,
		head_local = pose and pose.position and auxi.ProtectVector(pose.position) or nil,
		pose_rotation = pose and pose.rotation or nil,
		field_rotation = pose and pose.field_rotation or nil,
		hat_rotation = rotation,
		rotated_cover_offset = pose and pose.cover_offset_rotated
			and auxi.ProtectVector(pose.cover_offset_rotated) or nil,
		render_pos = render_pos and auxi.ProtectVector(render_pos) or nil,
		callback_offset = callback_offset and auxi.ProtectVector(callback_offset) or nil,
		cover_offset = Vector(item.cover_offset.X, item.cover_offset.Y),
		cover_padding_y = item.cover_padding_y,
	}
end

local function maintain_boss_cover_attributes(target)
	if not target or not target.IsBoss or not target:IsBoss() then
		return
	end
	local d = target:GetData()
	-- COVER owns claims here (lifecycle). Same-frame gameplay application for
	-- native boss AI is repeated in MC_PRE_NPC_UPDATE via apply_entity_attributes.
	if target.SetSpeedMultiplier then
		Attribute_holder.ensure_hold_token(
			target,
			d,
			BOSS_SLOW_TOKEN_KEY,
			"SpeedMultiplier",
			item.boss_slow_multiplier,
			Attribute_holder.descriptors.speed_multiplier()
		)
	end
	Attribute_holder.ensure_hold_token(
		target,
		d,
		BOSS_COLOR_TOKEN_KEY,
		"Color",
		item.boss_slow_color,
		Attribute_holder.descriptors.color()
	)
end

local function release_boss_cover_attributes(target)
	if not target then
		return
	end
	local d = target:GetData()
	Attribute_holder.rewind_hold_token(
		target,
		d,
		BOSS_SLOW_TOKEN_KEY,
		"SpeedMultiplier",
		Attribute_holder.descriptors.speed_multiplier()
	)
	Attribute_holder.rewind_hold_token(
		target,
		d,
		BOSS_COLOR_TOKEN_KEY,
		"Color",
		Attribute_holder.descriptors.color()
	)
end

-- Unbind host only. Caller owns when/where Effect becomes Visible and its world pose.
local function detach_target(effect, info)
	local token = info and info.attach_token
	local target = info and info.target
	if exists(target) then
		release_boss_cover_attributes(target)
		if token then
			local data = target:GetData()
			if data[COVERED_TOKEN_KEY] == token then
				data[COVERED_TOKEN_KEY] = nil
			end
		end
	end
	if token then
		item.attached_hats[token] = nil
	end
	if info then
		info.target = nil
		info.attach_token = nil
		info.head_anchor = nil
		info.head_pose = nil
		info.head_pose_frame = nil
		info.impact_start_world = nil
		info.impact_start_rotation = nil
		info.reattach_start_world = nil
		info.debug_head_source = nil
		info.debug_head_layer = nil
		info.debug_head_overlay = nil
	end
end

-- Render path: token → Lua record only. Never returns Effect userdata.
local function get_attached_hat_record(npc)
	if not exists(npc) then return nil end
	local token = npc:GetData()[COVERED_TOKEN_KEY]
	if type(token) ~= "number" then return nil end
	local rec = item.attached_hats[token]
	if not rec or not rec.info then return nil end
	if not is_attached_hat_state(rec.info.state) then return nil end
	if rec.target_ptr and GetPtrHash(npc) ~= rec.target_ptr then return nil end
	return rec
end

local function prepare_attached_hat_sprite(rec, rotation)
	local sprite = item.attached_hat_sprite
	sprite:SetFrame("Idle", item.cover_frame)
	sprite.Scale = auxi.ProtectVector(rec.scale or Vector.One)
	sprite.Rotation = rotation or 0
	sprite.FlipX = false
	sprite.FlipY = false
	sprite.Offset = Vector.Zero
	sprite.Color = Color(1, 1, 1, 1)
	return sprite
end

local function sync_attached_entity(effect, target)
	effect.Position = target.Position
	effect.PositionOffset = auxi.ProtectVector(target.PositionOffset or Vector.Zero)
	effect.Velocity = Vector.Zero
	effect.Visible = false
end

local function is_valid_target(target)
	return exists(target) and not target:IsDead()
end

-- Save the last place the hat was actually drawn (not the host entity center).
-- Same W2S(Position+PO)+pose → RenderToWorld contract as handoff (no callback offset).
local function record_last_safe_hat_visual(target, info)
	if not is_valid_target(target) or not info then
		return
	end
	local pose = cached_enemy_head_pose(target, info)
	if not pose or pose.visible == false or not pose.position then
		return
	end
	local world_pos = entity_visual_to_world(
		target.Position,
		target.PositionOffset,
		pose.position
	)
	if not world_pos then
		return
	end
	info.last_safe_visual_world = auxi.ProtectVector(world_pos)
	info.last_safe_rotation = get_attached_hat_rotation(target, info)
	local token = info.attach_token
	local rec = token and item.attached_hats[token]
	info.last_safe_scale = auxi.ProtectVector(
		(rec and rec.scale) or Vector.One
	)
end

-- Move hidden Effect to the attached sandwich visual before making it Visible.
-- Must run while target/head-pose state still exist (before detach_target).
local function handoff_attached_hat_to_effect(effect, info, target)
	if not exists(effect) or not is_valid_target(target) or not info then
		return false
	end
	local pose = cached_enemy_head_pose(target, info)
	if not pose or pose.visible == false or not pose.position then
		return false
	end
	local world_pos = entity_visual_to_world(
		target.Position,
		target.PositionOffset,
		pose.position
	)
	if not world_pos then
		return false
	end

	effect.Position = world_pos
	effect.PositionOffset = Vector.Zero
	effect.Velocity = Vector.Zero

	local rotation = get_attached_hat_rotation(target, info)
	local sprite = effect:GetSprite()
	if sprite then
		sprite.Rotation = rotation or 0
	end

	local token = info.attach_token
	local rec = token and item.attached_hats[token]
	if rec and rec.scale then
		effect.SpriteScale = auxi.ProtectVector(rec.scale)
	else
		set_visual_scale(effect, info, Vector.One)
	end

	return true
end

local function apply_last_safe_visual_to_effect(effect, info)
	if not exists(effect) or not info or not info.last_safe_visual_world then
		return false
	end
	effect.Position = auxi.ProtectVector(info.last_safe_visual_world)
	effect.PositionOffset = Vector.Zero
	effect.Velocity = Vector.Zero
	local sprite = effect:GetSprite()
	if sprite and info.last_safe_rotation then
		sprite.Rotation = info.last_safe_rotation
	end
	if info.last_safe_scale then
		effect.SpriteScale = auxi.ProtectVector(info.last_safe_scale)
	end
	return true
end

-- Gameplay / collision center. Never reuse Render Anchor geometry here.
local function hat_gameplay_center(effect, info)
	if is_gameplay_cover_state(info.state) and is_valid_target(info.target) then
		return info.target.Position + (info.target.PositionOffset or Vector.Zero)
	end
	return effect.Position + (effect.PositionOffset or Vector.Zero)
end

local function find_attack_target(player,direction)
	local axis = direction:Normalized()
	local perpendicular = Vector(-axis.Y,axis.X)
	local best,best_forward,best_side
	for _,entity in ipairs(Isaac.FindInRadius(player.Position,
		item.attack_range + item.attack_corridor_half_width,EntityPartition.ENEMY)) do
		local npc = entity:ToNPC()
		if npc and npc:IsActiveEnemy(false) and npc:IsVulnerableEnemy()
			and not npc:IsDead() and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
			local delta = npc.Position - player.Position
			local forward = delta:Dot(axis)
			local side = math.abs(delta:Dot(perpendicular))
			if forward > 0 and forward <= item.attack_range
				and side <= item.attack_corridor_half_width
				and (not best_forward or forward < best_forward - 1
					or (math.abs(forward - best_forward) <= 1 and side < best_side)) then
				best,best_forward,best_side = npc,forward,side
			end
		end
	end
	return best,best_forward
end

local function launch_profile(forward)
	if not forward then return item.launch_speed,item.flight_max_speed,item.launch_air_velocity end
	local ratio = math.min(1,math.max(0,(forward - 70) / 220))
	return 8 + 3 * ratio,15 + 8 * ratio,6.5 + 2.7 * ratio
end

local function descend_profile(distance)
	if distance > 120 then return item.descend_speed_far,item.steer_far end
	if distance > 80 then return item.descend_speed_mid,item.steer_mid end
	if distance > 50 then
		return (item.descend_speed_mid + item.descend_speed_near) * 0.5,
			(item.steer_mid + item.steer_near) * 0.5
	end
	if distance > 30 then return item.descend_speed_near,item.steer_near end
	return item.align_speed,0.65
end

local function flight_hits_wall(effect)
	local room = Game():GetRoom()
	local next_position = effect.Position + effect.Velocity
	return not room:IsPositionInRoom(next_position,4)
		or room:GetGridCollisionAtPos(next_position) ~= GridCollisionClass.COLLISION_NONE
end

local function free_flight_should_return(effect,info)
	local hit_wall = flight_hits_wall(effect)
	return hit_wall or (info.flight_distance or 0) >= item.max_flight_distance
		or (info.age or 0) >= item.max_flight_frames,hit_wall
end

local function target_attack_should_abort(effect,info)
	local hit_wall = flight_hits_wall(effect)
	return hit_wall or (info.target_phase_age or 0) >= item.target_phase_timeout,hit_wall
end

local function start_target_descend(info)
	info.state = "TARGET_DESCEND"
	info.age = 0
	info.target_phase_age = 0
	info.air_velocity = math.min(info.air_velocity or 0,-0.5)
	info.head_anchor = {}
end

local function start_head_align(info)
	info.state = "HEAD_ALIGN"
	info.age = 0
	info.target_phase_age = 0
end

local function spawn_puff(effect,scale)
	local puff = Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.POOF01,0,effect.Position,Vector.Zero,effect):ToEffect()
	if puff then
		puff.PositionOffset = auxi.ProtectVector(effect.PositionOffset)
		puff.SpriteScale = Vector.One * (scale or 0.4)
		puff:SetColor(Color(0.8,0.8,0.8,0.65),6,1,false,false)
	end
end

local function spawn_afterimage(effect,info)
	local ghost = Isaac.Spawn(EntityType.ENTITY_EFFECT,enums.Entities.AnnaHelper,0,effect.Position,Vector.Zero,effect):ToEffect()
	if not ghost then return end
	ghost.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	ghost.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	ghost.PositionOffset = auxi.ProtectVector(effect.PositionOffset)
	ghost.SpriteScale = auxi.ProtectVector(effect.SpriteScale)
	ghost.DepthOffset = effect.DepthOffset - 1
	local sprite = ghost:GetSprite()
	sprite:Load(item.hat_anm2,true)
	sprite:SetFrame("Idle",info.spin_frame or 0)
	sprite.Color = Color(1,1,1,0.28)
	ghost:GetData()[item.own_key.."afterimage"] = {age = 0,life = item.afterimage_life}
end

local function set_air_offset(effect,info)
	effect.PositionOffset = info.base_air_offset + Vector(0,-(info.air_height or 0))
end

local function integrate_air(effect,info,gravity)
	info.air_velocity = (info.air_velocity or 0) - gravity
	info.air_height = (info.air_height or 0) + info.air_velocity
	set_air_offset(effect,info)
end

local function start_return_launch(effect,info,player,bounce)
	local target = info.target
	local incoming_velocity = auxi.ProtectVector(effect.Velocity)
	-- Capture attached Size scale before detach clears the host link.
	local return_from = tonumber(info.size_multiplier)
	if (not return_from or return_from <= 0) and exists(target) then
		return_from = attached_hat_size_scale(target)
	end
	info.return_size_scale = return_from or 1
	info.return_shrink_elapsed = 0

	-- Critical visual handoff BEFORE detach clears target/head pose.
	local handed_off = false
	if is_valid_target(target) then
		handed_off = handoff_attached_hat_to_effect(effect, info, target)
	end
	if not handed_off then
		apply_last_safe_visual_to_effect(effect, info)
	end

	detach_target(effect, info)

	info.state = "RETURN_LAUNCH"
	info.age = 0
	info.size_multiplier = info.return_size_scale
	effect.Visible = true
	info.base_air_offset = auxi.ProtectVector(effect.PositionOffset or Vector.Zero)
	info.air_height = 0
	info.air_velocity = item.return_air_velocity
	local direction = player.Position - effect.Position
	if direction:Length() <= 0.1 then direction = Vector(0,1) end
	effect.Velocity = bounce and incoming_velocity * -0.25 or direction:Resized(item.return_launch_speed)
	update_motion_scale(effect,info,"RETURN_LAUNCH")
end

-- Cover gameplay finished while host is still render-hidden: wait for a safe visual release.
local function start_return_wait(effect, info, target)
	info.state = "RETURN_WAIT"
	info.age = 0
	info.return_visible_frames = 0
	info.return_invalid_frames = 0
	-- Gameplay COVER already ended.
	if exists(target) then
		release_boss_cover_attributes(target)
	end
	effect.Velocity = Vector.Zero
	effect.Visible = false
end

-- Smooth Size scale back to 1× across RETURN_LAUNCH + early RETURN (visual only).
local function update_return_size_shrink(info)
	info.return_shrink_elapsed = (info.return_shrink_elapsed or 0) + 1
	local u = math.min(1, info.return_shrink_elapsed / item.return_shrink_frames)
	info.size_multiplier = lerp_scalar(
		info.return_size_scale or 1,
		1,
		ease_in_out(u)
	)
end

local function get_cover_record(npc)
	local rec = get_attached_hat_record(npc)
	if not rec or not rec.info or rec.info.state ~= "COVER" then
		return nil
	end
	return rec
end

local function start_impact(effect,info,target)
	info.state = "IMPACT"
	info.age = 0
	info.target = target
	info.head_anchor = info.head_anchor or {}
	info.head_pose = nil
	info.head_pose_frame = nil
	-- Entity visual point (Position+PO) for later WorldToRenderPosition; not a handoff world.
	info.impact_start_world = auxi.ProtectVector(
		effect.Position + (effect.PositionOffset or Vector.Zero)
	)
	local start_rot = 0
	if effect.GetSprite then
		local ok, spr = pcall(function() return effect:GetSprite() end)
		if ok and spr then
			start_rot = tonumber(spr.Rotation) or 0
		end
	end
	info.impact_start_rotation = start_rot
	sync_attached_entity(effect, target)
	bind_hat_target(effect, info, target)
	effect:GetSprite():SetFrame("Idle",item.cover_frame)
	info.spin_frame = item.cover_frame
	refresh_attached_render(effect, info)
	spawn_puff(effect,0.32)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_PLOP,0.65,1.15,false,0,2)
end

local function start_cover(info,target)
	info.state = "COVER"
	info.age = 0
	info.timer = item.cover_frames
	info.size_multiplier = attached_hat_size_scale(target)
	info.air_height = nil
	info.air_velocity = nil
	info.flight_distance = nil
	info.base_air_offset = nil
	info.impact_start_world = nil
	info.impact_start_rotation = nil
end

local function spawn_hat(player,runtime,direction)
	local effect = Isaac.Spawn(EntityType.ENTITY_EFFECT,enums.Entities.AnnaHelper,0,player.Position,Vector.Zero,player):ToEffect()
	if not effect then return end
	effect.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	effect.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	effect.DepthOffset = 120
	effect.Visible = true
	effect.PositionOffset = player_hat_offset(player)
	local sprite = effect:GetSprite()
	sprite:Load(item.hat_anm2,true)
	sprite:SetFrame("Idle",0)
	local info = {
		owner_hash = GetPtrHash(player),
		state = "WINDUP",
		age = 0,
		direction = direction,
		spin_phase = 0,
		spin_frame = 0,
		spin_velocity = 0,
	}
	effect:GetData()[item.effect_key] = info
	runtime.state = "WINDUP"
	runtime.effect = effect
	runtime.spin_frame = 0
	set_hat_costume(player,runtime,false)
end

local function finish_reattach(player,runtime,effect)
	if exists(effect) then
		detach_target(effect, effect:GetData()[item.effect_key])
		effect:Remove()
	end
	runtime.effect = nil
	runtime.state = "WORN"
	runtime.spin_frame = 0
	runtime.refire_cooldown = item.refire_cooldown_frames
	set_hat_costume(player,runtime,true)
end

local function reset_to_worn(player,runtime)
	if exists(runtime.effect) then
		detach_target(runtime.effect, runtime.effect:GetData()[item.effect_key])
		runtime.effect:Remove()
	end
	runtime.effect = nil
	runtime.state = "WORN"
	runtime.spin_frame = 0
	runtime.refire_cooldown = 0
	set_hat_costume(player,runtime,true)
end

local function clear_runtime(player,runtime)
	if not runtime then return end
	if exists(runtime.effect) then
		detach_target(runtime.effect, runtime.effect:GetData()[item.effect_key])
		runtime.effect:Remove()
	end
	runtime.effect = nil
	set_hat_costume(player,runtime,false)
	player:GetData()[item.runtime_key] = nil
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_,player)
	local runtime = get_runtime(player,false)
	if not has_hat(player) then
		clear_runtime(player,runtime)
		return
	end

	runtime = runtime or get_runtime(player,true)
	if runtime.state ~= "WORN" and not exists(runtime.effect) then
		reset_to_worn(player,runtime)
	end
	if runtime.state == "WORN" then
		set_hat_costume(player,runtime,true)
		block_projectiles(player.Position + player_hat_offset(player),player)
		runtime.refire_cooldown = math.max(0, (runtime.refire_cooldown or 0) - 1)
		local input = get_shooting_input(player)
		if input:Length() > 0.1 and runtime.refire_cooldown <= 0 then
			spawn_hat(player, runtime, input)
		end
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = enums.Entities.AnnaHelper,
Function = function(_,effect)
	local afterimage = effect:GetData()[item.own_key.."afterimage"]
	if afterimage then
		afterimage.age = (afterimage.age or 0) + 1
		local alpha = 0.28 * math.max(0,1 - afterimage.age / afterimage.life)
		effect:GetSprite().Color = Color(1,1,1,alpha)
		if afterimage.age >= afterimage.life then effect:Remove() end
		return
	end
	local info = effect:GetData()[item.effect_key]
	if not info then return end
	local player = find_player(info.owner_hash)
	if not player or not has_hat(player) then
		detach_target(effect, info)
		effect:Remove()
		return
	end
	local runtime = get_runtime(player,true)
	runtime.effect = effect
	runtime.state = info.state
	block_projectiles(hat_gameplay_center(effect, info),effect)

	if info.state == "WINDUP" then
		info.age = info.age + 1
		local progress = math.min(1,info.age / item.windup_frames)
		local eased = ease_in_out(progress)
		local offset
		if progress < 0.5 then
			local pull = ease_in_out(progress * 2)
			offset = -info.direction * (6 * pull) + Vector(0,3 * pull)
			effect.SpriteScale = lerp_vector(Vector.One,Vector(1.06,0.94),pull)
		else
			local release = ease_in_out((progress - 0.5) * 2)
			offset = lerp_vector(-info.direction * 6 + Vector(0,3),info.direction * 5 + Vector(0,-8),release)
			effect.SpriteScale = release < 0.65
				and lerp_vector(Vector(1.06,0.94),Vector(0.96,1.08),release / 0.65)
				or lerp_vector(Vector(0.96,1.08),Vector.One,(release - 0.65) / 0.35)
		end
		effect.Position = player.Position
		effect.PositionOffset = player_hat_offset(player) + offset
		effect.Velocity = Vector.Zero
		update_spin(effect,info,item.windup_spin * (0.4 + eased))
		if progress >= 1 then
			local target,forward = find_attack_target(player,info.direction)
			local launch_speed,flight_max_speed,air_velocity = launch_profile(forward)
			info.state = "FLIGHT"
			info.age = 0
			info.flight_distance = 0
			info.target = target
			info.had_target = target ~= nil
			info.target_forward_distance = forward
			info.flight_max_speed = flight_max_speed
			info.launch_origin = auxi.ProtectVector(effect.Position)
			if forward then
				local before_target = math.max(4,forward - item.target_apex_margin)
				info.apex_forward_distance = math.min(
					math.max(item.target_apex_min,forward * item.target_apex_ratio),before_target)
			end
			info.base_air_offset = auxi.ProtectVector(effect.PositionOffset)
			info.air_height = 0
			info.air_velocity = air_velocity
			info.launch_air_velocity = air_velocity
			effect.Velocity = info.direction * launch_speed
			effect.SpriteScale = item.launch_stretch
			spawn_puff(effect,0.38)
		end

	elseif info.state == "FLIGHT" then
		info.age = info.age + 1
		local rising = (info.air_velocity or 0) > 0
		local speed = effect.Velocity:Length()
		if rising then
			speed = math.min(info.flight_max_speed or item.flight_max_speed,speed + item.flight_acceleration)
			effect.Velocity = info.direction * speed
		else
			effect.Velocity = effect.Velocity * item.descend_drag
			speed = effect.Velocity:Length()
		end
		integrate_air(effect,info,rising and item.rise_gravity or item.fall_gravity)
		info.flight_distance = (info.flight_distance or 0) + speed
		local speed_ratio = math.min(1,speed / (info.flight_max_speed or item.flight_max_speed))
		info.spin_speed = item.spin_min + (item.spin_max - item.spin_min) * speed_ratio
		if not rising then info.spin_speed = math.max(item.spin_min,info.spin_speed * 0.62) end
		update_spin(effect,info,info.spin_speed)
		update_motion_scale(effect,info,rising and "RISE" or "DESCEND")
		if speed_ratio > 0.55 and info.age % item.afterimage_interval == 0 then spawn_afterimage(effect,info) end

		if info.had_target and not is_valid_target(info.target) then
			start_return_launch(effect,info,player,false)
		elseif is_valid_target(info.target) then
			local travelled_forward = (effect.Position - info.launch_origin):Dot(info.direction)
			local planned_apex = travelled_forward >= (info.apex_forward_distance or math.huge)
			local safety_apex = travelled_forward >= math.max(4,
				(info.target_forward_distance or math.huge) - item.target_apex_margin)
			if not rising or planned_apex or safety_apex then start_target_descend(info) end
		end

		local should_return,hit_wall
		if info.state == "FLIGHT" and info.target then
			hit_wall = flight_hits_wall(effect)
			should_return = hit_wall
		elseif info.state == "FLIGHT" then
			should_return,hit_wall = free_flight_should_return(effect,info)
		end
		if info.state == "FLIGHT" and (should_return or (not info.target and (info.air_height or 0) < -24)) then
			start_return_launch(effect,info,player,hit_wall)
			if hit_wall then spawn_puff(effect,0.28) end
		end

	elseif info.state == "TARGET_DESCEND" then
		if not is_valid_target(info.target) then
			start_return_launch(effect,info,player,false)
		else
			info.age = info.age + 1
			info.target_phase_age = (info.target_phase_age or 0) + 1
			local delta = info.target.Position - effect.Position
			local distance = delta:Length()
			local desired_speed,steer = descend_profile(distance)
			if distance > 0.1 then
				effect.Velocity = lerp_vector(effect.Velocity,delta:Resized(desired_speed),steer)
			end
			integrate_air(effect,info,item.fall_gravity)
			if distance > item.head_align_radius and (info.air_height or 0) < item.landing_hold_height then
				info.air_height = item.landing_hold_height
				info.air_velocity = math.max(0,info.air_velocity or 0)
				set_air_offset(effect,info)
			end
			local speed_ratio = math.min(1,effect.Velocity:Length() / item.flight_max_speed)
			update_spin(effect,info,math.max(0.035,0.045 * speed_ratio))
			update_motion_scale(effect,info,"DESCEND")
			if speed_ratio > 0.55 and info.age % item.afterimage_interval == 0 then spawn_afterimage(effect,info) end
			if distance <= item.head_align_radius then start_head_align(info) end
			local should_return,hit_wall = target_attack_should_abort(effect,info)
			if info.state == "TARGET_DESCEND" and should_return then
				start_return_launch(effect,info,player,hit_wall)
				if hit_wall then spawn_puff(effect,0.28) end
			end
		end

	elseif info.state == "HEAD_ALIGN" then
		if not is_valid_target(info.target) then
			start_return_launch(effect,info,player,false)
		else
			info.age = info.age + 1
			local target = info.target
			local target_po = auxi.ProtectVector(target.PositionOffset or Vector.Zero)
			local delta = target.Position - effect.Position
			local plane_distance = delta:Length()
			if plane_distance > 0.1 then
				local desired = delta:Resized(math.min(item.align_speed,plane_distance))
				effect.Velocity = lerp_vector(effect.Velocity,desired,item.steer_align)
			else
				effect.Velocity = Vector.Zero
			end
			-- Entity follow only; Render Anchor stays out of PositionOffset.
			effect.PositionOffset = lerp_vector(effect.PositionOffset,target_po,0.35)
			-- Grow toward host Size scale over the last align frames (visual only).
			local target_scale = attached_hat_size_scale(target)
			local u = math.min(1, info.age / item.head_align_frames)
			info.size_multiplier = 1 + (target_scale - 1) * ease_in_out(u)
			update_motion_scale(effect,info,"ALIGN")
			effect:GetSprite():SetFrame("Idle",3)
			info.spin_frame = 3
			-- Committed: no timeout abort. Snap when close enough, else after short settle.
			if plane_distance <= item.head_align_snap_radius
				or info.age >= item.head_align_frames
			then
				start_impact(effect,info,target)
			end
		end

	elseif info.state == "IMPACT" then
		if not is_valid_target(info.target) then
			start_return_launch(effect,info,player,false)
		else
			local target = info.target
			info.age = info.age + 1
			sync_attached_entity(effect, target)
			bind_hat_target(effect, info, target)
			local target_scale = attached_hat_size_scale(target)
			info.size_multiplier = target_scale
			local impact = item.impact_scales[math.min(#item.impact_scales,info.age)] or Vector.One
			set_visual_scale(effect, info, impact)
			effect:GetSprite():SetFrame("Idle",item.cover_frame)
			info.spin_frame = item.cover_frame
			refresh_attached_render(effect, info)
			if info.age >= item.impact_frames then
				start_cover(info,target)
				set_visual_scale(effect, info, Vector.One)
				refresh_attached_render(effect, info)
			end
		end

	elseif info.state == "COVER" then
		local target = info.target
		if not is_valid_target(target) then
			start_return_launch(effect,info,player,false)
		else
			sync_attached_entity(effect, target)
			bind_hat_target(effect, info, target)
			info.size_multiplier = attached_hat_size_scale(target)
			set_visual_scale(effect, info, Vector.One)
			effect:GetSprite():SetFrame("Idle",item.cover_frame)
			info.spin_frame = item.cover_frame
			refresh_attached_render(effect, info)
			-- Pose gate: Visible/IsVisible + empty scalp (not entity Visible alone).
			local pose = cached_enemy_head_pose(target, info)
			local pose_visible = pose and pose.visible ~= false
			if pose_visible then
				record_last_safe_hat_visual(target, info)
			end
			if target:IsBoss() then
				-- Claim lifecycle only; same-frame SM/Color apply is MC_PRE_NPC_UPDATE.
				maintain_boss_cover_attributes(target)
			else
				target:AddSlowing(
					EntityRef(effect),
					2,
					item.slow_amount,
					Color(0.25,0.25,0.25,1,0,0,0),
					false
				)
			end
			info.timer = math.max(0,(info.timer or 0) - 1)
			if info.timer <= 0 then
				if pose_visible then
					start_return_launch(effect,info,player,false)
				else
					-- COVER ended while host has no mountable head surface / is hidden.
					start_return_wait(effect, info, target)
				end
			end
		end

	elseif info.state == "RETURN_WAIT" then
		info.age = info.age + 1
		local target = info.target
		effect.Visible = false
		effect.Velocity = Vector.Zero
		if is_valid_target(target) then
			-- Keep Effect hidden at host center until handoff; do not draw.
			sync_attached_entity(effect, target)
			-- Wait for pose.visible (includes empty→hit recovery), not Visible alone.
			info.head_pose = nil
			info.head_pose_frame = nil
			local pose = cached_enemy_head_pose(target, info)
			if pose and pose.visible ~= false then
				info.return_visible_frames = (info.return_visible_frames or 0) + 1
				record_last_safe_hat_visual(target, info)
			else
				info.return_visible_frames = 0
			end
			if info.return_visible_frames >= item.return_visible_settle_frames then
				-- start_return_launch performs handoff then detach then Visible=true.
				start_return_launch(effect, info, player, false)
			elseif info.age >= item.return_wait_max_frames then
				apply_last_safe_visual_to_effect(effect, info)
				start_return_launch(effect, info, player, false)
			end
		else
			info.return_invalid_frames = (info.return_invalid_frames or 0) + 1
			if info.return_invalid_frames >= item.return_invalid_settle_frames then
				apply_last_safe_visual_to_effect(effect, info)
				start_return_launch(effect, info, player, false)
			end
		end

	elseif info.state == "RETURN_LAUNCH" then
		info.age = info.age + 1
		update_return_size_shrink(info)
		integrate_air(effect,info,item.return_gravity)
		update_spin(effect,info,0.055)
		update_motion_scale(effect,info,"RETURN_LAUNCH")
		if info.age >= item.return_launch_frames then
			info.state = "RETURN"
			info.age = 0
		end

	elseif info.state == "RETURN" then
		info.age = info.age + 1
		update_return_size_shrink(info)
		local to_player = player.Position - effect.Position
		local distance = to_player:Length()
		if distance > 0.1 then
			local near = distance < item.return_near_radius
			local turn_rate = near and item.return_near_turn_rate or item.return_turn_rate
			local max_speed = near and item.return_max_speed * 0.72 or item.return_max_speed
			local desired = to_player:Resized(max_speed)
			effect.Velocity = lerp_vector(effect.Velocity,desired,turn_rate)
			if effect.Velocity:Length() > max_speed then effect.Velocity = effect.Velocity:Resized(max_speed) end
			if near then
				info.base_air_offset = lerp_vector(info.base_air_offset,player_hat_offset(player),0.24)
				info.air_velocity = ((info.air_velocity or 0) + (0 - (info.air_height or 0)) * 0.16) * 0.78
				info.air_height = (info.air_height or 0) + info.air_velocity
				set_air_offset(effect,info)
			else
				integrate_air(effect,info,item.return_gravity)
			end
			local speed_ratio = math.min(1,effect.Velocity:Length() / item.return_max_speed)
			update_spin(effect,info,0.045 + 0.015 * speed_ratio)
			update_motion_scale(effect,info,"RETURN")
			if speed_ratio > 0.55 and info.age % item.afterimage_interval == 0 then spawn_afterimage(effect,info) end
		end
		if distance <= item.reattach_radius and math.abs(info.air_height or 0) <= 12 then
			info.state = "REATTACH"
			info.age = 0
			info.size_multiplier = 1
			info.return_size_scale = nil
			info.return_shrink_elapsed = nil
			-- Entity-coordinate visual interpolation (no W2S / RenderToWorld).
			info.reattach_start_world = auxi.ProtectVector(
				effect.Position + (effect.PositionOffset or Vector.Zero)
			)
			effect.Velocity = Vector.Zero
		end

	elseif info.state == "REATTACH" then
		info.age = info.age + 1
		info.size_multiplier = 1
		local progress = math.min(1,info.age / item.reattach_frames)
		local target_world = player.Position + player_hat_offset(player)
		local visual_world = lerp_vector(
			info.reattach_start_world
				or (effect.Position + (effect.PositionOffset or Vector.Zero)),
			target_world,
			ease_in_out(progress)
		)
		effect.Position = player.Position
		effect.PositionOffset = visual_world - player.Position
		effect.Velocity = Vector.Zero
		effect.SpriteScale = lerp_vector(effect.SpriteScale,Vector.One,0.45)
		effect:GetSprite():SetFrame("Idle",0)
		info.spin_frame = 0
		if progress >= 1 then finish_reattach(player,runtime,effect) end
	end

	if exists(effect) then
		runtime.state = info.state
		runtime.spin_frame = info.spin_frame
	end
end,
})

table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_NPC_UPDATE,
	params = nil,
	Function = function(_, npc)
		if not npc or not npc.IsBoss or not npc:IsBoss() then
			return
		end
		local rec = get_cover_record(npc)
		if not rec then
			return
		end
		-- Same as Reversed Slumber / Faint: claim + apply before native boss AI.
		maintain_boss_cover_attributes(npc)
		Attribute_holder.apply_entity_attributes(npc)
	end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_NPC_RENDER, params = nil,
Function = function(_,npc,offset)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	local rec = get_attached_hat_record(npc)
	if not rec then return end
	-- Cheap segment-local render gate before any head texel / pose work.
	local render_visible = head_anchor.GetEntityRenderVisibility(npc)
	if not render_visible then
		return
	end
	local info = rec.info
	local pose = cached_enemy_head_pose(npc, info)
	if not pose or pose.visible == false then
		return
	end
	local rotation = get_attached_hat_rotation(npc, info)
	local sprite = prepare_attached_hat_sprite(rec, rotation)
	local pos = get_attached_hat_render_pos(npc, info, offset)
	pcall(function()
		sprite:RenderLayer(item.hat_back_layer, pos, Vector.Zero, Vector.Zero)
	end)
	-- PRE may run without POST (hidden front); still publish snapshot for probes.
	store_attached_debug_snapshot(npc, info, rec, pose, rotation, pos, offset)
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_NPC_RENDER, params = nil,
Function = function(_,npc,offset)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	local rec = get_attached_hat_record(npc)
	if not rec then return end
	-- Same cheap gate as PRE before pose / texel.
	local render_visible = head_anchor.GetEntityRenderVisibility(npc)
	if not render_visible then
		return
	end
	local info = rec.info
	local pose = cached_enemy_head_pose(npc, info)
	if not pose or pose.visible == false then
		return
	end
	local rotation = get_attached_hat_rotation(npc, info)
	local sprite = prepare_attached_hat_sprite(rec, rotation)
	local pos = get_attached_hat_render_pos(npc, info, offset)
	pcall(function()
		sprite:RenderLayer(item.hat_front_layer, pos, Vector.Zero, Vector.Zero)
	end)
	store_attached_debug_snapshot(npc, info, rec, pose, rotation, pos, offset)

	if item.debug_hat_anchor and Isaac.RenderText then
		local po = npc.PositionOffset or Vector.Zero
		local red = Isaac.WorldToRenderPosition(npc.Position + po) + (offset or Vector.Zero)
		local pose = cached_enemy_head_pose(npc, info)
		local yellow = red + (pose.position or Vector.Zero)
		Isaac.RenderText("+", red.X - 3, red.Y - 4, 1, 0.2, 0.2, 1)
		Isaac.RenderText("+", yellow.X - 3, yellow.Y - 4, 1, 0.9, 0.2, 1)
		Isaac.RenderText("+", pos.X - 3, pos.Y - 4, 0.2, 1, 0.3, 1)
		Isaac.RenderText(
			string.format(
				"src=%s layer=%s rot=%.0f fr=%d %s",
				tostring(info.debug_head_source or "?"),
				tostring(info.debug_head_layer or "?"),
				rotation or 0,
				info.spin_frame or item.cover_frame,
				tostring(info.state)
			),
			pos.X + 6, pos.Y - 8, 0.85, 1, 0.85, 1
		)
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_NEW_ROOM, params = nil,
Function = function(_)
	for index = 0,Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(index)
		local runtime = get_runtime(player,false)
		if has_hat(player) then
			reset_to_worn(player,runtime or get_runtime(player,true))
		else
			clear_runtime(player,runtime)
		end
	end
	item.attached_hats = {}
end,
})

--- Dev-only: production My Hat pose for any target (no attach required).
--- Reuses get_enemy_head_pose + cover_offset + size scale. Does not mutate NPC.
function item.DebugGetHatPoseForTarget(npc, callback_offset)
	if not exists(npc) then
		return nil
	end
	local scratch = {
		head_anchor = {},
		state = "COVER",
	}
	local pose = get_enemy_head_pose(npc, scratch)
	local scale_mul = attached_hat_size_scale(npc)
	local scale = Vector(scale_mul, scale_mul)
	if not pose or pose.visible == false then
		return {
			visible = false,
			hidden_reason = pose and pose.hidden_reason or "unknown",
			render_pos = nil,
			head_local = nil,
			rotation = nil,
			scale = scale,
			source = pose and pose.source or nil,
			layer_id = pose and pose.layer_id or nil,
			scalp_scan_state = pose and pose.scalp_scan_state or nil,
		}
	end
	local base = Isaac.WorldToRenderPosition(
		npc.Position + (npc.PositionOffset or Vector.Zero)
	)
	local render_pos = base + (pose.position or Vector.Zero) + (callback_offset or Vector.Zero)
	return {
		visible = true,
		hidden_reason = nil,
		render_pos = render_pos,
		head_local = pose.position,
		rotation = pose.rotation or 0,
		scale = scale,
		source = pose.source,
		layer_id = pose.layer_id,
		scalp_scan_state = pose.scalp_scan_state,
		cover_offset_rotated = pose.cover_offset_rotated,
	}
end

--- Dev-only: read-only snapshot of an NPC currently covered by My Hat.
--- Observes the formal PRE/POST render cache — does NOT re-run head/pose scans.
function item.DebugGetAttachedHatInfo(npc, callback_offset)
	local rec = get_attached_hat_record(npc)
	if not rec or not rec.info then
		return nil
	end
	local snap = rec.debug_snapshot
	local effect_pose = rec.debug_effect
	if not snap then
		-- Attachment exists but has not rendered yet this cycle.
		return {
			state = rec.info.state,
			token = rec.info.attach_token,
			effect_position = effect_pose and effect_pose.position or nil,
			effect_position_offset = effect_pose and effect_pose.position_offset or nil,
			effect_visible = effect_pose and effect_pose.visible or nil,
			stale = true,
		}
	end
	-- callback_offset is ignored: formal render already baked offset into render_pos.
	return {
		state = snap.state,
		token = snap.token,
		head_pose = nil,
		head_local = snap.head_local,
		pose_rotation = snap.pose_rotation,
		field_rotation = snap.field_rotation,
		geometry_axis_rotation = nil,
		hat_rotation = snap.hat_rotation,
		rotated_cover_offset = snap.rotated_cover_offset,
		render_pos = snap.render_pos,
		cover_offset = snap.cover_offset,
		cover_padding_y = snap.cover_padding_y,
		effect_position = effect_pose and effect_pose.position or nil,
		effect_position_offset = effect_pose and effect_pose.position_offset or nil,
		effect_visible = effect_pose and effect_pose.visible or nil,
		game_frame = snap.game_frame,
		stale = false,
	}
end

return item
