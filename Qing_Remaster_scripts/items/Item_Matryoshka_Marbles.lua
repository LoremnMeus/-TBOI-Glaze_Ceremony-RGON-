-- 套娃弹珠：合格眼泪有概率变成弹珠。命中敌人后按接触法线弹开并分成两颗，重力方向始终是最初的发射方向。
local enums = require("Qing_Remaster_scripts.core.enums")
local attack_holder = require("Qing_Remaster_scripts.callbacks.attack_trigger_holder")
local registry = require("Qing_Remaster_scripts.callbacks.attack_registry")
local classifier = require("Qing_Remaster_scripts.callbacks.attack_source_classifier")
local fire_context = require("Qing_Remaster_scripts.callbacks.attack_fire_context")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	myToCall = {},
	entity = enums.Items.Matryoshka_Marbles,
	own_key = "Item_Matryoshka_Marbles_",
	TEAR_CHANCE = 0.20,
	OTHER_ATTACK_CHANCE = 0.20,
	MAX_GENERATION = 3,
	GRAVITY_ACCEL = 0.60,
	TERMINAL_SPEED = 13,
	BOUNCE_SPEED = 6.0,
	MIN_BACKWARD_SPEED = 3.0,
	ECCENTRIC_CLAMP = 1.5,
	LATERAL_SPREAD = 3.0,
	COLLISION_EPSILON = 1.5,
	SAME_TARGET_PROTECTION = 5,
	MAX_CHILD_AGE = 90,
	VISUAL_MAX_AGE = 45,
	VISUAL_FADE_TICKS = 8,
	VISUAL_SPRITE_HALF = 16,
	MIN_DIRECTION_SPEED = 0.05,
	ANGLE_APPROACH = 0.35,
	AIM_WAIT_FRAMES = 4,
	BRIM_BURST_COUNT = 4,
	BRIM_BURST_INTERVAL = 2,
	BRIM_SCATTER_DEG = 8,
	BRIM_SPEED_MIN = 0.90,
	BRIM_SPEED_SPAN = 0.20,
	debug_force = false,
}

local SCALES = {[0] = 1, [1] = 0.85, [2] = 0.72, [3] = 0.60}
local TEAR_ANM2 = "gfx/tears/Matryoshka_Marbles_Tear.anm2"
local LASER_FAMILIES = {brimstone = true, technology = true, techx = true}
local BLOCK_FLAGS = {}
local pending = {}
local compat_waits = {}
local brim_bursts = {}
local split_probe

local function vec_xy(v)
	if not v then return nil end
	return {x = v.X, y = v.Y}
end

local function probe_on()
	local env = require("Qing_Remaster_scripts.core.dev_environment")
	if not env.probes_allowed() then return false end
	if split_probe == nil then
		split_probe = env.require_probe("Qing_Remaster_scripts.debug.matryoshka_marbles_split_probe") or false
	end
	return split_probe and split_probe.is_enabled and split_probe.is_enabled() or false
end

local reported_probe_errors = {}

local function report_probe_error(err)
	local text = tostring(err)
	if reported_probe_errors[text] then return end
	reported_probe_errors[text] = true
	print("[Matryoshka Marbles probe]\n" .. text)
end

local function probe_call(fn, ...)
	if type(fn) ~= "function" then return end
	local argc = select("#", ...)
	local args = {...}
	local ok, a, b, c, d = xpcall(function()
		return fn(table.unpack(args, 1, argc))
	end, debug.traceback)
	if ok then return a, b, c, d end
	report_probe_error(a)
	return nil
end

local function probe_note(kind, fields)
	if not probe_on() then return false end
	probe_call(split_probe.note, kind, fields)
	return true
end

local function reject_split(tear, state, collider, reason, blocking)
	probe_note("SPLIT_REJECTED", {
		reason = reason,
		blocking = blocking ~= false,
		marble_id = probe_on() and probe_call(split_probe.marble_id_of, GetPtrHash(tear)) or nil,
		generation = state and state.generation or nil,
		position = vec_xy(tear.Position),
		velocity = vec_xy(tear.Velocity),
		gravity_dir = state and vec_xy(state.gravity_dir) or nil,
		height = tear.Height,
		collider_type = collider and collider.Type or nil,
		collider_variant = collider and collider.Variant or nil,
	})
end

local function add_flag(name)
	local flag = TearFlags[name]
	if flag then BLOCK_FLAGS[#BLOCK_FLAGS + 1] = flag end
end
add_flag("TEAR_PIERCING")
add_flag("TEAR_SPLIT")
add_flag("TEAR_QUADSPLIT")
add_flag("TEAR_EXPLOSIVE")
add_flag("TEAR_LUDOVICO")

local function state_of(tear)
	return tear and tear:GetData()[item.own_key .. "state"]
end

local function unit(v)
	if not v or v:Length() <= 0.0001 then return nil end
	return v:Normalized()
end

local function approach_angle(current, target, factor)
	local diff = (target - current + 180) % 360 - 180
	return current + diff * factor
end

local function target_token(ent)
	if not ent then return nil end
	return {ptr = GetPtrHash(ent), seed = ent.InitSeed, kind = ent.Type, variant = ent.Variant}
end

local function same_target(ent, token)
	if not ent or not token then return false end
	if GetPtrHash(ent) == token.ptr then return true end
	return ent.InitSeed == token.seed and ent.Type == token.kind and ent.Variant == token.variant
end

local function is_visual_marble(ent)
	return ent and ent.Type == EntityType.ENTITY_EFFECT and ent.Variant == enums.Entities.Matryoshka_Marble_Visual
end

local function is_valid_marble_collider(ent)
	if not ent or not ent:Exists() then return false end
	if ent.Type == EntityType.ENTITY_PLAYER or ent.Type == EntityType.ENTITY_FAMILIAR then return false end
	if ent.Type == EntityType.ENTITY_TEAR and state_of(ent) then return false end
	if is_visual_marble(ent) then return false end
	return true
end

local function player_owner(tear)
	local spawner = tear.SpawnerEntity
	local player = spawner and spawner.ToPlayer and spawner:ToPlayer()
	if not player then
		local parent = tear.Parent
		player = parent and parent.ToPlayer and parent:ToPlayer()
	end
	if not player or not player:HasCollectible(item.entity) then return nil end
	local attack = registry.GetAttackForMember(tear)
	if attack and attack.source and not classifier.IsPlayerAttackSource(attack.source) then
		return nil
	end
	return player
end

local function is_ludo_tear(ent)
	if not ent or not ent.TearFlags or not TearFlags or not TearFlags.TEAR_LUDOVICO then
		return false
	end
	return (ent.TearFlags & TearFlags.TEAR_LUDOVICO) == TearFlags.TEAR_LUDOVICO
end

local function is_eligible_tear(tear)
	if not tear or tear.Type ~= EntityType.ENTITY_TEAR then return false end
	if state_of(tear) then return false end
	local ctx = fire_context.Peek()
	if ctx and (ctx.reason == "taowa_split" or ctx.reason == "taowa_compat" or ctx.synthetic == true) then
		return false
	end
	if is_ludo_tear(tear) then
		return false
	end
	return player_owner(tear) ~= nil
end

local function apply_visual(tear, state, snap)
	local sprite = tear:GetSprite()
	sprite:Load(TEAR_ANM2, true)
	sprite:Play("Idle", true)
	local scale = SCALES[state.generation] or SCALES[3]
	sprite.Scale = Vector(scale, scale)
	local velocity = tear.Velocity
	if velocity and velocity:Length() > item.MIN_DIRECTION_SPEED then
		local angle = velocity:GetAngleDegrees() + 90
		sprite.Rotation = angle
		state.current_visual_angle = angle
	elseif snap then
		sprite.Rotation = state.current_visual_angle or 0
	end
end

local function clear_conflict_flags(tear)
	for i = 1, #BLOCK_FLAGS do
		if tear:HasTearFlags(BLOCK_FLAGS[i]) then
			tear:ClearTearFlags(BLOCK_FLAGS[i])
		end
	end
end

local function apply_locked_height(tear, visual_y)
	local height = auxi.offset2height(Vector(0, visual_y), 0)
	tear.Height = height
	if tear.PositionOffset ~= nil then
		tear.PositionOffset = Vector(tear.PositionOffset.X or 0, visual_y)
	end
	tear.FallingSpeed = 0
	tear.FallingAcceleration = 0
end

local function initialize_child_height(tear, state)
	if not tear or not state or (state.generation or 0) <= 0 then return end
	if state.locked_visual_y ~= nil then return end
	local height = tonumber(tear.Height)
	if not height then return end
	state.locked_visual_y = auxi.height2offset(height, tonumber(tear.FallingAcceleration) or 0)
	apply_locked_height(tear, state.locked_visual_y)
end

local function maintain_child_height(tear, state)
	if not state or (state.generation or 0) <= 0 then return end
	if state.locked_visual_y == nil then
		initialize_child_height(tear, state)
		return
	end
	apply_locked_height(tear, state.locked_visual_y)
end

local function write_state(tear, fields)
	local state = {
		generation = fields.generation or 0,
		gravity_dir = fields.gravity_dir,
		previous_position = tear.Position,
		previous_velocity = tear.Velocity,
		damage_snapshot = fields.damage or tear.CollisionDamage or 0,
		base_collision_radius = fields.base_radius or tear.Size or 8,
		age = 0,
		collision_claimed = false,
		spawn_target_token = fields.spawn_target,
		spawn_protection_age = 0,
		current_visual_angle = 0,
		physics_frame = nil,
	}
	tear.CollisionDamage = state.damage_snapshot
	local scale = SCALES[state.generation] or SCALES[3]
	tear.Size = state.base_collision_radius * scale
	tear:GetData()[item.own_key .. "state"] = state
	clear_conflict_flags(tear)
	apply_visual(tear, state, true)
	initialize_child_height(tear, state)
	if state.generation > 0 then
		probe_note("CHILD_INITIALIZED", {
			split_id = fields.probe_split_id,
			marble_id = fields.probe_marble_id,
			generation = state.generation,
			height = tear.Height,
			falling_speed = tear.FallingSpeed,
			falling_acceleration = tear.FallingAcceleration,
			position_offset = vec_xy(tear.PositionOffset),
			locked_visual_y = state.locked_visual_y,
			velocity = vec_xy(tear.Velocity),
			position = vec_xy(tear.Position),
			size = tear.Size,
			exists = tear:Exists(),
		})
		if fields.probe_track and probe_on() then
			probe_call(split_probe.bind_child, tear, {
				split_id = fields.probe_split_id,
				marble_id = fields.probe_marble_id,
				generation = state.generation,
				gravity_dir = state.gravity_dir,
			})
		end
	end
	return state
end

local function convert_to_marble(tear)
	local velocity = tear.Velocity
	local direction = unit(velocity)
	if not direction then return nil end
	return write_state(tear, {
		generation = 0,
		gravity_dir = direction,
		damage = tear.CollisionDamage,
		base_radius = tear.Size,
	})
end

local function solve_t(a, b, c)
	if math.abs(a) < 1e-8 then
		if math.abs(b) < 1e-8 then return nil end
		local t = -c / b
		if t >= 0 and t <= 1 then return t end
		return nil
	end
	local disc = b * b - 4 * a * c
	if disc < 0 then return nil end
	local root = math.sqrt(disc)
	local best = nil
	local t1 = (-b - root) / (2 * a)
	local t2 = (-b + root) / (2 * a)
	if t1 >= 0 and t1 <= 1 then best = t1 end
	if t2 >= 0 and t2 <= 1 and (not best or t2 < best) then best = t2 end
	return best
end

local function calculate_contact(state, tear, collider)
	local p0 = state.previous_position or tear.Position
	local p1 = tear.Position
	local center = collider.Position
	local radius = (collider.Size or 12) + (tear.Size or state.base_collision_radius or 8)
	local delta = p1 - p0
	local offset = p0 - center
	local a = delta:Dot(delta)
	local b = 2 * offset:Dot(delta)
	local c = offset:Dot(offset) - radius * radius
	local sweep_reason = nil
	if a < 0.0025 then
		sweep_reason = "no_motion"
	elseif offset:Length() < radius then
		sweep_reason = "started_inside"
	end
	local t = sweep_reason and nil or solve_t(a, b, c)
	if not t and not sweep_reason then
		local disc = b * b - 4 * a * c
		sweep_reason = disc < 0 and "missed_circle" or "root_outside"
	end
	local sweep = t ~= nil
	local hit = sweep and (p0 + delta * t) or p1
	local normal = unit(hit - center)
	local fallback = not sweep
	if not normal then
		fallback = true
		normal = unit(p1 - center) or (state.gravity_dir and unit(-state.gravity_dir))
	end
	return hit, normal, sweep, fallback, sweep_reason, p0, p1
end

local function clamp_number(value, low, high)
	if value < low then return low end
	if value > high then return high end
	return value
end

local function limit_speed(velocity)
	if velocity:Length() > item.TERMINAL_SPEED then
		return velocity:Resized(item.TERMINAL_SPEED)
	end
	return velocity
end

local function calculate_split_velocities(normal, incoming, gravity)
	local incident = unit(incoming)
	if not incident or not normal or not gravity then return nil, nil, nil end
	local bounce = incident
	if incident:Dot(normal) < 0 then
		bounce = incident - normal * (2 * incident:Dot(normal))
	else
		bounce = -incident
	end
	bounce = unit(bounce)
	if not bounce then return nil, nil, nil end
	local perpendicular = Vector(-gravity.Y, gravity.X)
	local eccentric = clamp_number(bounce:Dot(perpendicular) * item.BOUNCE_SPEED, -item.ECCENTRIC_CLAMP, item.ECCENTRIC_CLAMP)
	local backward = -gravity * item.MIN_BACKWARD_SPEED
	local left = limit_speed(backward + perpendicular * (eccentric - item.LATERAL_SPREAD))
	local right = limit_speed(backward + perpendicular * (eccentric + item.LATERAL_SPREAD))
	return left, right, bounce
end

local function outside_collider(point, collider, radius)
	local away = point - collider.Position
	local need = (collider.Size or 12) + radius + item.COLLISION_EPSILON
	if away:Length() >= need then return point end
	local normal = unit(away) or Vector(0, -1)
	return collider.Position + normal * need
end

local function spawn_child(player, attack, position, velocity, fields)
	local mode = (attack and attack.active and not attack.ending) and "inherit" or "untracked"
	if mode == "untracked" and not item.logged_untracked then
		item.logged_untracked = true
		Isaac.DebugString("[Matryoshka Marbles] parent attack ended; child uses untracked fire")
	end
	local tear = attack_holder.FireTear(player, position, velocity, {
		mode = mode,
		attack = mode == "inherit" and attack or nil,
		role = "derived",
		reason = "taowa_split",
		family = "tear",
		can_be_eye = false,
	})
	probe_note("CHILD_FIRE", {
		returned = tear ~= nil,
		ptr = tear and GetPtrHash(tear) or nil,
		mode = mode,
		generation = fields.generation,
		fire_reason = "taowa_split",
	})
	if not tear then return nil end
	write_state(tear, fields)
	return tear
end

local function commit_split(row)
	if row.done then return end
	row.done = true
	local collider = row.collider
	local radius = (row.base_radius or 8) * (SCALES[row.next_generation] or 0.6)
	local function child_pos(velocity)
		local step = velocity:Length() > 0.05 and velocity:Normalized() or row.gravity_dir
		local point = row.hit + step * item.COLLISION_EPSILON
		if collider and collider:Exists() then
			return outside_collider(point, collider, radius)
		end
		return point
	end
	local left_pos = child_pos(row.left_velocity)
	local right_pos = child_pos(row.right_velocity)
	local fields = {
		generation = row.next_generation,
		gravity_dir = row.gravity_dir,
		damage = row.damage,
		base_radius = row.base_radius,
		spawn_target = row.target,
	}
	local plan = probe_on() and probe_call(split_probe.plan_split, row.parent and GetPtrHash(row.parent) or nil, (row.next_generation or 1) - 1) or nil
	local function spawn_side(position, velocity, side_id, tracked)
		local child_fields = {
			generation = fields.generation,
			gravity_dir = fields.gravity_dir,
			damage = fields.damage,
			base_radius = fields.base_radius,
			spawn_target = fields.spawn_target,
			probe_split_id = plan and plan.split_id or nil,
			probe_marble_id = side_id,
			probe_track = tracked == true,
		}
		return spawn_child(row.player, row.attack, position, velocity, child_fields)
	end
	local left = spawn_side(left_pos, row.left_velocity, plan and plan.left_id or nil, plan and plan.track_left)
	local right = spawn_side(right_pos, row.right_velocity, plan and plan.right_id or nil, plan and plan.track_right)
	if left or right then
		SFXManager():Play(SoundEffect.SOUND_PLOP, 0.55, 0, false, 1.2)
	end
	local parent = row.parent
	if (left or right) and parent and parent:Exists() then
		if probe_on() and plan and (plan.track_left or plan.track_right) then
			probe_call(split_probe.watch_parent, parent, plan.split_id)
			probe_call(split_probe.mark_remove, parent, "split_parent_remove")
		end
		parent:Remove()
	end
end

local function flush_pending()
	if #pending == 0 then return end
	probe_note("SPLIT_FLUSH", {
		pending = #pending,
		frame = Game():GetFrameCount(),
	})
	local rows = pending
	pending = {}
	for i = 1, #rows do
		commit_split(rows[i])
	end
end

local function claim_collision(tear, collider)
	local state = state_of(tear)
	if not state then return end
	local hit, normal, sweep, fallback, sweep_reason, p0, p1 = calculate_contact(state, tear, collider)
	if not normal then
		reject_split(tear, state, collider, "invalid_normal")
		return
	end
	local incoming = state.previous_velocity or tear.Velocity
	if not unit(incoming) then
		reject_split(tear, state, collider, "invalid_incoming")
		return
	end
	local left, right, bounce = calculate_split_velocities(normal, incoming, state.gravity_dir)
	if not left or not right then
		reject_split(tear, state, collider, "invalid_incoming")
		return
	end
	local player = player_owner(tear)
	local attack = registry.GetAttackForMember(tear)
	if not player then
		reject_split(tear, state, collider, "missing_player")
		return
	end
	if not attack then
		reject_split(tear, state, collider, "missing_attack", false)
	end
	local incident = unit(incoming)
	probe_note("CONTACT_GEOMETRY", {
		generation = state.generation,
		marble_id = probe_on() and probe_call(split_probe.marble_id_of, GetPtrHash(tear)) or nil,
		incoming = vec_xy(incident),
		normal = vec_xy(normal),
		incoming_dot_normal = incident:Dot(normal),
		bounce = vec_xy(bounce),
		child_velocity_l = vec_xy(left),
		child_velocity_r = vec_xy(right),
		sweep_hit = sweep == true,
		normal_fallback = fallback == true,
		sweep_reason = sweep_reason,
		p0 = vec_xy(p0),
		p1 = vec_xy(p1),
	})
	state.collision_claimed = true
	pending[#pending + 1] = {
		parent = tear,
		player = player,
		attack = attack,
		collider = collider,
		hit = hit or tear.Position,
		gravity_dir = state.gravity_dir,
		left_velocity = left,
		right_velocity = right,
		next_generation = state.generation + 1,
		damage = state.damage_snapshot,
		base_radius = state.base_collision_radius,
		target = target_token(collider),
	}
	probe_note("SPLIT_CLAIMED", {
		ok = true,
		generation = state.generation,
		player = true,
		attack = attack ~= nil,
		hit = vec_xy(hit),
		incoming = vec_xy(incoming),
		normal = vec_xy(normal),
	})
end

local function visual_of(effect)
	return effect and effect:GetData()[item.own_key .. "visual"]
end

local function color_snapshot(color)
	if not color then return {r = 1, g = 1, b = 1, a = 1, ro = 0, go = 0, bo = 0} end
	return {
		r = color.R or 1,
		g = color.G or 1,
		b = color.B or 1,
		a = color.A or 1,
		ro = color.RO or 0,
		go = color.GO or 0,
		bo = color.BO or 0,
	}
end

local function apply_visual_color(effect, snap, alpha)
	local color = Color(snap.r, snap.g, snap.b, (snap.a or 1) * alpha, snap.ro, snap.go, snap.bo)
	effect.Color = color
	local sprite = effect:GetSprite()
	if sprite then sprite.Color = color end
end

local function handoff_visual_position(tear)
	local visual = tear.Position + (tear.PositionOffset or Vector.Zero)
	local screen = Isaac.WorldToScreen(visual)
	if not screen or not Isaac.RenderToWorld then return nil end
	return Isaac.RenderToWorld(screen), visual
end

local function fully_outside_room(pos, radius)
	local room = Game():GetRoom()
	if not pos or not room or not room.IsPositionInRoom then return false end
	if room:IsPositionInRoom(pos, 0) then return false end
	local reach = radius or 0
	local corners = {
		pos + Vector(reach, reach),
		pos + Vector(reach, -reach),
		pos + Vector(-reach, reach),
		pos + Vector(-reach, -reach),
	}
	for i = 1, #corners do
		if room:IsPositionInRoom(corners[i], 0) then return false end
	end
	return true
end

local function end_visual(effect, state, reason)
	if not effect or (state and state.ended) then return end
	if state then state.ended = true end
	probe_note("VISUAL_END", {
		reason = reason,
		generation = state and state.generation or nil,
		age = state and state.age or nil,
		position = vec_xy(effect.Position),
		velocity = state and vec_xy(state.velocity) or nil,
	})
	effect:Remove()
end

local function clear_visual_marbles(reason)
	local variant = enums.Entities.Matryoshka_Marble_Visual
	if not variant then return end
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, variant) or {}) do
		if ent:Exists() then
			end_visual(ent, visual_of(ent), reason)
		end
	end
end

-- 原生落地和射程没有带原因的移除回调。MC_POST_TEAR_DEATH 只有眼泪参数，
-- 不能区分命中移除、换房和自然结束，所以这一版只从 max_child_age 转入视觉弹珠。
local function convert_marble_to_visual(tear, state, reason)
	if not tear or not state or state.visual_converted or (state.generation or 0) <= 0 then return nil end
	local variant = enums.Entities.Matryoshka_Marble_Visual
	if not variant then return nil end
	local world, tear_visual = handoff_visual_position(tear)
	if not world then return nil end
	local velocity = tear.Velocity or Vector.Zero
	state.visual_converted = true
	local effect = Isaac.Spawn(EntityType.ENTITY_EFFECT, variant, 0, world, velocity, nil)
	effect = effect and effect.ToEffect and effect:ToEffect()
	if not effect then
		state.visual_converted = false
		return nil
	end
	effect.Position = world
	effect.PositionOffset = Vector.Zero
	effect.Velocity = velocity
	effect.CollisionDamage = 0
	effect.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	effect.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	local tear_sprite = tear:GetSprite()
	local scale = tear_sprite and tear_sprite.Scale or Vector(SCALES[state.generation] or 1, SCALES[state.generation] or 1)
	local rotation = tear_sprite and tear_sprite.Rotation or state.current_visual_angle or 0
	local sprite = effect:GetSprite()
	sprite:Load(TEAR_ANM2, true)
	sprite:Play("Idle", true)
	sprite.Scale = Vector(scale.X, scale.Y)
	sprite.Rotation = rotation
	local colors = color_snapshot(tear.Color)
	local visual = {
		velocity = Vector(velocity.X, velocity.Y),
		gravity_dir = state.gravity_dir,
		generation = state.generation,
		current_visual_angle = rotation,
		visual_snapped = true,
		scale = sprite.Scale,
		color = colors,
		age = 0,
		physics_frame = nil,
		await_first_render = true,
		render_wait = 0,
		handoff_position = Vector(world.X, world.Y),
		tear_visual = tear_visual,
		reason = reason,
		ended = false,
	}
	effect:GetData()[item.own_key .. "visual"] = visual
	apply_visual_color(effect, colors, 1)
	probe_note("VISUAL_CONVERT", {
		reason = reason,
		generation = state.generation,
		tear_position = vec_xy(tear.Position),
		tear_offset = vec_xy(tear.PositionOffset),
		tear_visual = vec_xy(tear_visual),
		effect_position = vec_xy(effect.Position),
		handoff_delta = (effect.Position - tear_visual):Length(),
		velocity = vec_xy(velocity),
	})
	return effect
end

local function update_visual(effect)
	local state = visual_of(effect)
	if not state or state.ended or not state.gravity_dir then return end
	local scale = state.scale and math.max(math.abs(state.scale.X), math.abs(state.scale.Y)) or 1
	local radius = item.VISUAL_SPRITE_HALF * scale
	if state.await_first_render then
		effect.Position = state.handoff_position
		effect.PositionOffset = Vector.Zero
		effect.Velocity = state.velocity
		if fully_outside_room(effect.Position, radius) then
			end_visual(effect, state, "out_of_room")
			return
		end
		state.render_wait = (state.render_wait or 0) + 1
		if state.render_wait < 2 then return end
		state.await_first_render = false
		probe_note("VISUAL_FIRST_RENDER", {
			generation = state.generation,
			missed = true,
			position = vec_xy(effect.Position),
		})
		return
	elseif fully_outside_room(effect.Position, radius) then
		end_visual(effect, state, "out_of_room")
		return
	end
	local frame = Game():GetFrameCount()
	if state.physics_frame == frame then return end
	state.physics_frame = frame
	state.age = state.age + 1
	if state.age >= item.VISUAL_MAX_AGE then
		end_visual(effect, state, "max_age")
		return
	end
	local velocity = state.velocity + state.gravity_dir * item.GRAVITY_ACCEL
	if velocity:Length() > item.TERMINAL_SPEED then
		velocity = velocity:Resized(item.TERMINAL_SPEED)
	end
	state.velocity = velocity
	effect.Velocity = velocity
	if velocity:Length() > item.MIN_DIRECTION_SPEED then
		local target = velocity:GetAngleDegrees() + 90
		state.current_visual_angle = approach_angle(state.current_visual_angle or target, target, item.ANGLE_APPROACH)
		effect:GetSprite().Rotation = state.current_visual_angle
	end
	local fade_start = item.VISUAL_MAX_AGE - item.VISUAL_FADE_TICKS
	local alpha = 1
	if state.age >= fade_start then
		alpha = 1 - (state.age - fade_start) / item.VISUAL_FADE_TICKS
	end
	apply_visual_color(effect, state.color, alpha)
end

local function note_visual_first_render(effect)
	local state = visual_of(effect)
	if not state or not state.await_first_render then return end
	state.await_first_render = false
	local rendered = effect.Position + (effect.PositionOffset or Vector.Zero)
	local delta = state.handoff_position and (rendered - state.handoff_position):Length() or nil
	probe_note("VISUAL_FIRST_RENDER", {
		generation = state.generation,
		reason = state.reason,
		handoff_position = vec_xy(state.handoff_position),
		render_position = vec_xy(rendered),
		tear_visual = vec_xy(state.tear_visual),
		delta = delta,
		match = delta ~= nil and delta < 1,
	})
end

local function update_marble(tear)
	local state = state_of(tear)
	if not state or not state.gravity_dir then return end
	maintain_child_height(tear, state)
	if state.generation > 0 and not state.probe_child_update and probe_on() then
		state.probe_child_update = true
		probe_note("CHILD_UPDATE", {
			generation = state.generation,
			exists = tear:Exists(),
			height = tear.Height,
			age = state.age,
			velocity = vec_xy(tear.Velocity),
			ptr = GetPtrHash(tear),
		})
	end
	local frame = Game():GetFrameCount()
	if state.physics_frame ~= frame then
		state.physics_frame = frame
		state.age = state.age + 1
		state.spawn_protection_age = (state.spawn_protection_age or 0) + 1
		local velocity = tear.Velocity + state.gravity_dir * item.GRAVITY_ACCEL
		if velocity:Length() > item.TERMINAL_SPEED then
			velocity = velocity:Resized(item.TERMINAL_SPEED)
		end
		tear.Velocity = velocity
		state.previous_velocity = tear.Velocity
		if probe_on() then probe_call(split_probe.observe, tear, state) end
		if state.generation > 0 and state.age >= item.MAX_CHILD_AGE and not state.visual_converted then
			local effect = convert_marble_to_visual(tear, state, "max_child_age")
			if effect then
				if probe_on() then probe_call(split_probe.mark_remove, tear, "max_child_age") end
				tear:Remove()
			end
			return
		end
	end
	local velocity = tear.Velocity
	if velocity:Length() > item.MIN_DIRECTION_SPEED then
		local target = velocity:GetAngleDegrees() + 90
		if state.visual_snapped then
			state.current_visual_angle = approach_angle(state.current_visual_angle or target, target, item.ANGLE_APPROACH)
		else
			state.current_visual_angle = target
			state.visual_snapped = true
		end
		tear:GetSprite().Rotation = state.current_visual_angle
	end
end

local function copy_vec(v)
	if not v or not v.Length or v:Length() <= 0.01 then return nil end
	return Vector(v.X, v.Y)
end

local function is_moms_knife(ent)
	if not ent or ent.Type ~= EntityType.ENTITY_KNIFE then return false end
	local variant = ent.Variant
	if KnifeVariant then
		if KnifeVariant.MOMS_KNIFE and variant == KnifeVariant.MOMS_KNIFE then return true end
		if KnifeVariant.SUMPTORIUM and variant == KnifeVariant.SUMPTORIUM then return true end
	end
	return variant == 0 or variant == 5
end

local function bound_entities(attack)
	local out, seen = {}, {}
	local function add(ent)
		if not ent or not ent.Exists or not ent:Exists() then return end
		local hash = GetPtrHash(ent)
		if seen[hash] then return end
		seen[hash] = true
		out[#out + 1] = ent
	end
	if attack and attack.bound_members then
		for _, rec in pairs(attack.bound_members) do
			if rec and rec.bound ~= false then add(rec.entity) end
		end
	end
	if attack and attack.members then
		for i = 1, #attack.members do
			local rec = attack.members[i]
			if rec and rec.bound ~= false then add(rec.entity) end
		end
	end
	return out
end

local function find_member(attack, pred)
	local list = bound_entities(attack)
	for i = 1, #list do
		if pred(list[i]) then return list[i] end
	end
	return nil
end

local function laser_angle_direction(laser)
	if not laser or laser.Type ~= EntityType.ENTITY_LASER then return nil, nil end
	local angle = laser.AngleDegrees
	if type(angle) ~= "number" then angle = laser.Angle end
	if type(angle) ~= "number" then return nil, nil end
	return auxi.MakeVector(angle), angle
end

local function knife_throw_direction(knife)
	if not knife or type(knife.Rotation) ~= "number" then return nil, nil end
	local direction = auxi.get_by_rotate(Vector(1, 0), knife.Rotation)
	if not direction or direction:Length() <= 0.01 then return nil, knife.Rotation end
	return direction:Normalized(), knife.Rotation
end

local function live_player_aim(player)
	if not player or not player.GetShootingInput then return nil end
	local input = player:GetShootingInput()
	if input and input:Length() > 0.05 then return input:Normalized() end
	return nil
end

local function resolve_compat_aim(attack, snap)
	local family = attack and attack.family or nil
	local laser = find_member(attack, function(ent) return ent.Type == EntityType.ENTITY_LASER end)
	local knife = find_member(attack, is_moms_knife)
	local laser_dir, laser_angle = laser_angle_direction(laser)
	local knife_dir, knife_rotation = knife_throw_direction(knife)
	local event_direction = snap and snap.event_direction or nil
	local attack_direction = unit(attack and attack.direction)
	local player = classifier.GetAttackOwnerPlayer(attack)
	local player_aim = nil
	if attack and attack.source and classifier.IsPlayerAttackSource(attack.source) then
		player_aim = live_player_aim(player)
	end
	local direction, reason = nil, "none"
	if family == "techx" then
		if event_direction then
			direction, reason = event_direction:Normalized(), "event_direction"
		elseif attack_direction then
			direction, reason = attack_direction, "attack_direction"
		elseif player_aim then
			direction, reason = player_aim, "player_input"
		end
	elseif family == "brimstone" or family == "technology" then
		if laser_dir then
			direction, reason = laser_dir:Normalized(), "laser_angle"
		elseif event_direction then
			direction, reason = event_direction:Normalized(), "event_direction"
		elseif attack_direction then
			direction, reason = attack_direction, "attack_direction"
		elseif player_aim then
			direction, reason = player_aim, "player_input"
		end
	elseif family == "knife" then
		if knife_dir then
			direction, reason = knife_dir, "knife_rotation"
		elseif event_direction then
			direction, reason = event_direction:Normalized(), "event_direction"
		elseif attack_direction then
			direction, reason = attack_direction, "attack_direction"
		elseif player_aim then
			direction, reason = player_aim, "player_input"
		end
	end
	local position = nil
	if (family == "brimstone" or family == "technology" or family == "techx") and laser and laser.Position then
		position = laser.Position
	elseif family == "knife" and snap and snap.event_position then
		position = snap.event_position
	elseif family == "knife" and knife and knife.Position then
		position = knife.Position
	elseif snap and snap.event_position then
		position = snap.event_position
	elseif reason == "player_input" and player and player.Position then
		position = player.Position
	end
	return {
		family = family,
		attack_id = attack and attack.id or nil,
		event_direction = event_direction,
		attack_direction = attack and attack.direction or nil,
		member = laser or knife,
		laser_angle = laser_angle,
		knife_rotation = knife_rotation,
		position = position,
		direction = direction,
		aim_reason = reason,
		fallback_used = direction == nil,
	}
end

local function spawn_compatible_marble(player, attack, position, direction, generation)
	if not player or not position or not direction then return nil end
	local mode = (attack and attack.active and not attack.ending) and "inherit" or "untracked"
	local tear = attack_holder.FireTear(player, position, direction * ((player.ShotSpeed or 1) * 10), {
		mode = mode,
		attack = mode == "inherit" and attack or nil,
		role = "derived",
		reason = "taowa_compat",
		family = "tear",
		can_be_eye = false,
	})
	if not tear then return nil end
	write_state(tear, {
		generation = generation or 0,
		gravity_dir = direction,
		damage = tear.CollisionDamage,
		base_radius = tear.Size,
	})
	return tear
end

local function queue_brimstone_burst(player, attack, aim)
	local frame = Game():GetFrameCount()
	local job = {
		attack_id = attack.id,
		direction = Vector(aim.direction.X, aim.direction.Y),
		origin = Vector(aim.position.X, aim.position.Y),
		base_speed = (player.ShotSpeed or 1) * 10,
		shots_remaining = item.BRIM_BURST_COUNT,
		next_fire_frame = frame,
		interval = item.BRIM_BURST_INTERVAL,
		spawned = 0,
	}
	brim_bursts[#brim_bursts + 1] = job
	probe_note("BRIM_BURST_START", {
		attack_id = attack.id,
		shots = item.BRIM_BURST_COUNT,
		interval = item.BRIM_BURST_INTERVAL,
		direction = vec_xy(job.direction),
		origin = vec_xy(job.origin),
	})
end

local function end_brim_burst(job, reason)
	probe_note("BRIM_BURST_END", {
		attack_id = job.attack_id,
		reason = reason,
		spawned = job.spawned,
		remaining = job.shots_remaining,
	})
end

local function tick_brimstone_bursts()
	if #brim_bursts == 0 then return end
	local frame = Game():GetFrameCount()
	local keep = {}
	for i = 1, #brim_bursts do
		local job = brim_bursts[i]
		local attack = registry.GetAttack(job.attack_id)
		local player = attack and classifier.GetAttackOwnerPlayer(attack) or nil
		if not player or not player:Exists() then
			end_brim_burst(job, "no_player")
		elseif frame >= job.next_fire_frame then
			local rng = player:GetCollectibleRNG(item.entity)
			local angle = (rng:RandomFloat() * 2 - 1) * item.BRIM_SCATTER_DEG
			local speed_scale = item.BRIM_SPEED_MIN + rng:RandomFloat() * item.BRIM_SPEED_SPAN
			local direction = job.direction:Rotated(angle):Normalized()
			local velocity = direction * job.base_speed * speed_scale
			local mode = (attack and attack.active and not attack.ending) and "inherit" or "untracked"
			local tear = attack_holder.FireTear(player, job.origin, velocity, {
				mode = mode,
				attack = mode == "inherit" and attack or nil,
				role = "derived",
				reason = "taowa_compat",
				family = "tear",
				can_be_eye = false,
			})
			if tear then
				write_state(tear, {
					generation = 0,
					gravity_dir = direction,
					damage = tear.CollisionDamage,
					base_radius = tear.Size,
				})
				job.spawned = job.spawned + 1
			end
			probe_note("BRIM_BURST_SHOT", {
				attack_id = job.attack_id,
				index = job.spawned,
				spawned = tear ~= nil,
				mode = mode,
				direction = vec_xy(direction),
				speed_scale = speed_scale,
			})
			job.shots_remaining = job.shots_remaining - 1
			job.next_fire_frame = frame + job.interval
			if job.shots_remaining > 0 then
				keep[#keep + 1] = job
			else
				end_brim_burst(job, "done")
			end
		else
			keep[#keep + 1] = job
		end
	end
	brim_bursts = keep
end

local function compat_roll(player)
	if item.debug_force then return true end
	local rng = player:GetCollectibleRNG(item.entity)
	return rng:RandomFloat() < item.OTHER_ATTACK_CHANCE
end

local function finish_compat_wait(wait, frame)
	local attack = registry.GetAttack(wait.attack_id)
	if not attack then
		return true
	end
	local aim = resolve_compat_aim(attack, wait)
	local expired = frame - wait.born >= item.AIM_WAIT_FRAMES
	if not aim.direction or not aim.position then
		if not expired then return false end
		return true
	end
	local player = classifier.GetAttackOwnerPlayer(attack)
	if not player or not player:Exists() or not player:HasCollectible(item.entity) then return true end
	local rolled = compat_roll(player)
	if wait.family == "knife" then
		probe_note("KNIFE_THROW_PROC", {
			attack_id = attack.id,
			reason = wait.event_reason,
			variant = aim.member and aim.member.Variant or nil,
			success = rolled,
			direction = vec_xy(aim.direction),
		})
	end
	if not rolled then return true end
	if wait.family == "brimstone" then
		queue_brimstone_burst(player, attack, aim)
	else
		spawn_compatible_marble(player, attack, aim.position, aim.direction, 0)
	end
	return true
end

local function settle_compat_waits()
	if #compat_waits == 0 then return end
	local frame = Game():GetFrameCount()
	local keep = {}
	for i = 1, #compat_waits do
		if not finish_compat_wait(compat_waits[i], frame) then
			keep[#keep + 1] = compat_waits[i]
		end
	end
	compat_waits = keep
end

local function clear_compat_jobs(reason)
	for i = 1, #brim_bursts do
		end_brim_burst(brim_bursts[i], reason)
	end
	brim_bursts = {}
	compat_waits = {}
end

local function attack_has_tear(attack)
	for i = 1, #(attack.members or {}) do
		local record = attack.members[i]
		local member = record and record.bound and record.entity
		if member and member:Exists() and member.Type == EntityType.ENTITY_TEAR then
			return true
		end
	end
	return false
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_FIRE_TEAR,
	params = nil,
	Function = function(_, tear)
		if not is_eligible_tear(tear) then return end
		local player = player_owner(tear)
		if not player then return end
		if not item.debug_force then
			local rng = player:GetCollectibleRNG(item.entity)
			if rng:RandomFloat() >= item.TEAR_CHANCE then return end
		end
		convert_to_marble(tear)
	end,
})

local function ludo_data(tear)
	return tear and tear:GetData()[item.own_key .. "ludo"]
end

local function ludo_tag(attack)
	return attack and attack.tags and attack.tags.matryoshka_ludo
end

local function ludo_skin_player(tear)
	local player = classifier.resolve_owner_player(tear)
	local attack = select(1, registry.GetAttackForMember(tear))
	local has_item = player and player:Exists() and player:HasCollectible(item.entity) or false
	local independent = attack and attack.source and not classifier.IsPlayerAttackSource(attack.source) or false
	return (has_item and not independent) and player or nil, player, attack, has_item, independent
end

local function capture_ludo_visual(tear)
	local data = tear:GetData()
	local key = item.own_key .. "ludo_visual"
	if type(data[key]) == "table" then return data[key] end
	local sprite = tear:GetSprite()
	local scale = sprite and sprite.Scale
	data[key] = {
		variant = tear.Variant,
		flags = tear.TearFlags,
		tear_scale = tear.Scale,
		sprite_scale = scale and {X = scale.X, Y = scale.Y} or nil,
		color = tear.Color,
		rotation = sprite and sprite.Rotation or 0,
	}
	return data[key]
end

--- Custom anm2 sticks on the same variant. Pearl uses a variant round-trip to rebuild the tear sprite.
--- Do not write TearFlags, Height, FallingSpeed, or CollisionDamage; those change Ludo control.
local function restore_ludo_visual(tear, state)
	if not state or not state.visual_applied then return false end
	local t = tear.ToTear and tear:ToTear() or tear
	local snap = tear:GetData()[item.own_key .. "ludo_visual"]
	local want = snap and snap.variant or t.Variant
	if t.ChangeVariant and want ~= nil then
		local cur = t.Variant
		if cur == want then
			local tmp = TearVariant.BLOOD or 1
			if want == tmp then tmp = TearVariant.BLUE or 0 end
			pcall(function() t:ChangeVariant(tmp) end)
		end
		pcall(function() t:ChangeVariant(want) end)
	end
	if snap and snap.flags ~= nil then t.TearFlags = snap.flags end
	if snap and snap.tear_scale ~= nil then t.Scale = snap.tear_scale end
	if snap and snap.color ~= nil then t.Color = snap.color end
	if t.ResetSpriteScale then
		pcall(function() t:ResetSpriteScale(true) end)
	end
	local sprite = t.GetSprite and t:GetSprite()
	if sprite and snap and snap.sprite_scale then
		sprite.Scale = Vector(snap.sprite_scale.X or 1, snap.sprite_scale.Y or 1)
	end
	if sprite and snap and snap.rotation ~= nil then sprite.Rotation = snap.rotation end
	if sprite and sprite.LoadGraphics then
		pcall(function() sprite:LoadGraphics() end)
	end
	state.visual_applied = false
	probe_note("LUDO_SKIN_RESTORE", {
		ptr = GetPtrHash(tear),
		attack_id = state.attack_id,
		variant = t.Variant,
	})
	return true
end

local function apply_ludo_visual(tear, state)
	local sprite = tear:GetSprite()
	if not sprite or not sprite.GetFilename then return false end
	local animation = sprite.GetAnimation and sprite:GetAnimation() or nil
	if state.visual_applied and sprite:GetFilename() == TEAR_ANM2 and animation == "Ludo" then
		return false
	end
	local reload = state.visual_applied == true
	local previous = sprite:GetFilename()
	local previous_animation = animation
	if not reload then capture_ludo_visual(tear) end
	if sprite:GetFilename() ~= TEAR_ANM2 then
		local scale = sprite.Scale
		sprite:Load(TEAR_ANM2, true)
		if scale then sprite.Scale = Vector(scale.X, scale.Y) end
	end
	sprite:Play("Ludo", true)
	state.visual_applied = true
	local shown = sprite.GetAnimation and sprite:GetAnimation() or nil
	if reload then
		probe_note("LUDO_VISUAL_RELOAD", {
			ptr = GetPtrHash(tear),
			attack_id = state.attack_id,
			previous_filename = previous,
			previous_animation = previous_animation,
			filename = sprite.GetFilename and sprite:GetFilename() or nil,
			animation = shown,
		})
	else
		probe_note("LUDO_SKIN_APPLY", {
			ptr = GetPtrHash(tear),
			attack_id = state.attack_id,
			filename = sprite.GetFilename and sprite:GetFilename() or nil,
			animation = shown,
		})
	end
	return true
end

local function sync_ludo_visual(tear, state)
	if not state then return end
	if state.proc then
		apply_ludo_visual(tear, state)
	else
		restore_ludo_visual(tear, state)
	end
end

local function sync_ludo_round(tear, attack)
	local tag = ludo_tag(attack)
	if not tag or tag.checked ~= true then return nil end
	if not tear or not tear:Exists() or not is_ludo_tear(tear) then return nil end
	local bound = select(1, registry.GetAttackForMember(tear))
	if not bound or bound.id ~= attack.id or bound.family ~= "ludo" then return nil end
	if attack.source and not classifier.IsPlayerAttackSource(attack.source) then return nil end
	local player = classifier.GetAttackOwnerPlayer(attack)
	local state = ludo_data(tear)
	if not player or not player:Exists() or not player:HasCollectible(item.entity) then
		if state and state.visual_applied then restore_ludo_visual(tear, state) end
		return nil
	end
	if type(state) ~= "table" then
		state = {attack_id = nil, proc = false, spawned = false, visual_applied = false}
		tear:GetData()[item.own_key .. "ludo"] = state
	end
	if state.attack_id ~= attack.id then
		state.attack_id = attack.id
		state.proc = tag.proc == true
		state.spawned = false
		sync_ludo_visual(tear, state)
	elseif state.proc then
		apply_ludo_visual(tear, state)
	end
	return state
end

local function each_bound_ludo_tear(attack, fn)
	for i = 1, #(attack.members or {}) do
		local record = attack.members[i]
		local member = record and record.bound and record.entity
		if member then fn(member) end
	end
end

local function roll_ludo_attack(player, attack)
	if not player or not player:Exists() or not player:HasCollectible(item.entity) then return end
	if classifier.IsSyntheticSampleAttack(attack) then return end
	if attack.source and not classifier.IsPlayerAttackSource(attack.source) then return end
	attack.tags = attack.tags or {}
	local tag = attack.tags.matryoshka_ludo
	if type(tag) == "table" and tag.checked then
		probe_note("LUDO_ROUND_ROLL", {
			attack_id = attack.id,
			duplicate = true,
			success = tag.proc == true,
		})
		return
	end
	local success = item.debug_force or player:GetCollectibleRNG(item.entity):RandomFloat() < item.TEAR_CHANCE
	attack.tags.matryoshka_ludo = {checked = true, proc = success}
	probe_note("LUDO_ROUND_ROLL", {
		attack_id = attack.id,
		duplicate = false,
		success = success,
		forced = item.debug_force == true,
	})
	each_bound_ludo_tear(attack, function(member)
		sync_ludo_round(member, attack)
	end)
end

local function release_unowned_ludo(tear)
	local state = ludo_data(tear)
	if not state or not state.visual_applied then return end
	local player = classifier.resolve_owner_player(tear)
	if player and player:Exists() and player:HasCollectible(item.entity) then return end
	restore_ludo_visual(tear, state)
	tear:GetData()[item.own_key .. "ludo"] = nil
end

local function track_ludo_tear(tear)
	if not tear or tear.Type ~= EntityType.ENTITY_TEAR or not is_ludo_tear(tear) then return end
	local data = tear:GetData()
	local seen_key = item.own_key .. "ludo_seen"
	if not data[seen_key] then
		data[seen_key] = true
		probe_note("LUDO_DETECTED", {
			ptr = GetPtrHash(tear),
			init_seed = tear.InitSeed,
			flag = "TEAR_LUDOVICO",
		})
		local _, owner, attack, has_item, independent = ludo_skin_player(tear)
		probe_note("LUDO_OWNER", {
			ptr = GetPtrHash(tear),
			owner_present = owner ~= nil,
			has_item = has_item == true,
			independent_source = independent == true,
			attack_id = attack and attack.id or nil,
			source_kind = attack and attack.source and attack.source.kind or nil,
		})
	end
	local attack = select(1, registry.GetAttackForMember(tear))
	if not attack or attack.family ~= "ludo" then
		release_unowned_ludo(tear)
		return
	end
	sync_ludo_round(tear, attack)
end

local function clear_ludo_visuals()
	local tears = Isaac.FindByType(EntityType.ENTITY_TEAR, -1, -1, false, false)
	for i = 1, #tears do
		local tear = tears[i]
		local state = ludo_data(tear)
		if state and state.visual_applied then restore_ludo_visual(tear, state) end
		if state then tear:GetData()[item.own_key .. "ludo"] = nil end
	end
end

local function spawn_ludo_split_children(tear, collider, attack, player)
	local fake = {
		previous_position = tear.Position,
		previous_velocity = tear.Velocity,
		base_collision_radius = tear.Size,
	}
	local _, normal = calculate_contact(fake, tear, collider)
	normal = normal or unit(tear.Position - collider.Position)
	if not normal then
		probe_note("LUDO_G2_SPAWN", {
			attack_id = attack.id,
			parent_ptr = GetPtrHash(tear),
			parent_exists = tear:Exists(),
			left = false,
			right = false,
			repeat_spawn = false,
			reason = "invalid_normal",
		})
		return false
	end
	local moving = unit(tear.Velocity)
	local incident = moving or (-normal)
	local axis = moving or incident
	local left, right = calculate_split_velocities(normal, incident, axis)
	local ludo_position = Vector(tear.Position.X, tear.Position.Y)
	local collider_position = collider.Position and Vector(collider.Position.X, collider.Position.Y) or nil
	local player_position = player.Position and Vector(player.Position.X, player.Position.Y) or nil
	local gravity_dir, gravity_reason
	local toward_collider = collider_position and unit(collider_position - ludo_position)
	if toward_collider then
		gravity_dir, gravity_reason = toward_collider, "collider_center"
	else
		local toward_player = player_position and unit(player_position - ludo_position)
		if toward_player then
			gravity_dir, gravity_reason = toward_player, "player_fallback"
		elseif normal then
			gravity_dir, gravity_reason = -normal, "normal_fallback"
		else
			gravity_dir, gravity_reason = incident, "incident_fallback"
		end
	end
	if not left or not right or not gravity_dir then
		probe_note("LUDO_G2_SPAWN", {
			attack_id = attack.id,
			parent_ptr = GetPtrHash(tear),
			parent_exists = tear:Exists(),
			left = false,
			right = false,
			repeat_spawn = false,
			reason = "invalid_split",
			gravity_dir = vec_xy(gravity_dir),
			gravity_reason = gravity_reason,
			player_position = vec_xy(player_position),
			ludo_position = vec_xy(ludo_position),
		})
		return false
	end
	local radius = (tear.Size or 8) * (SCALES[2] or 0.72)
	local function place(velocity)
		local step = velocity:Length() > 0.05 and velocity:Normalized() or axis
		local point = tear.Position + step * item.COLLISION_EPSILON
		if collider:Exists() then return outside_collider(point, collider, radius) end
		return point
	end
	local function fire(velocity)
		local mode = (attack.active and not attack.ending) and "inherit" or "untracked"
		local child = attack_holder.FireTear(player, place(velocity), velocity, {
			mode = mode,
			attack = mode == "inherit" and attack or nil,
			role = "derived",
			reason = "taowa_compat",
			family = "tear",
			can_be_eye = false,
		})
		if not child then return nil end
		write_state(child, {
			generation = 2,
			gravity_dir = gravity_dir,
			damage = tear.CollisionDamage,
			base_radius = tear.Size,
			spawn_target = target_token(collider),
		})
		return child
	end
	local child_l = fire(left)
	local child_r = fire(right)
	probe_note("LUDO_G2_SPAWN", {
		attack_id = attack.id,
		parent_ptr = GetPtrHash(tear),
		parent_exists = tear:Exists(),
		left = child_l ~= nil,
		right = child_r ~= nil,
		repeat_spawn = false,
		left_direction = child_l and vec_xy(unit(left)) or nil,
		right_direction = child_r and vec_xy(unit(right)) or nil,
		normal = vec_xy(normal),
		gravity_dir = vec_xy(gravity_dir),
		gravity_reason = gravity_reason,
		player_position = vec_xy(player_position),
		ludo_position = vec_xy(ludo_position),
	})
	return child_l ~= nil and child_r ~= nil
end

local function try_ludo_split(tear, collider)
	if not is_ludo_tear(tear) then return end
	if not is_valid_marble_collider(collider) then return end
	local attack = select(1, registry.GetAttackForMember(tear))
	if not attack or attack.family ~= "ludo" then return end
	local state = ludo_data(tear)
	if not state or state.attack_id ~= attack.id then
		state = sync_ludo_round(tear, attack)
	end
	probe_note("LUDO_CONTACT", {
		attack_id = attack.id,
		ptr = GetPtrHash(tear),
		proc = state and state.proc == true,
		spawned = state and state.spawned == true,
		blocked_repeat = state and state.proc == true and state.spawned == true,
	})
	if not state or state.attack_id ~= attack.id then return end
	if not state.proc or state.spawned then return end
	state.spawned = true
	local player = classifier.GetAttackOwnerPlayer(attack)
	if not player or not player:Exists() or not player:HasCollectible(item.entity) then
		probe_note("LUDO_G2_SPAWN", {
			attack_id = attack.id,
			parent_ptr = GetPtrHash(tear),
			parent_exists = tear:Exists(),
			left = false,
			right = false,
			repeat_spawn = false,
			reason = "missing_player",
		})
		return
	end
	spawn_ludo_split_children(tear, collider, attack, player)
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_TEAR_UPDATE,
	params = nil,
	Function = function(_, tear)
		local state = state_of(tear)
		if not state then return end
		state.previous_position = tear.Position
		state.previous_velocity = tear.Velocity
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_TEAR_UPDATE,
	params = nil,
	Function = function(_, tear)
		track_ludo_tear(tear)
		update_marble(tear)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE,
	params = enums.Entities.Matryoshka_Marble_Visual,
	Function = function(_, effect)
		update_visual(effect)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_EFFECT_RENDER,
	params = enums.Entities.Matryoshka_Marble_Visual,
	Function = function(_, effect)
		note_visual_first_render(effect)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION,
	params = nil,
	Function = function(_, tear, collider)
		try_ludo_split(tear, collider)
		local state = state_of(tear)
		if not state then return end
		if probe_on() then probe_call(split_probe.mark_collision, GetPtrHash(tear)) end
		probe_note("COLLISION_SEEN", {
			generation = state.generation,
			marble_id = probe_on() and probe_call(split_probe.marble_id_of, GetPtrHash(tear)) or nil,
			collider_type = collider and collider.Type or nil,
			collider_variant = collider and collider.Variant or nil,
			state = true,
		})
		if state.spawn_target_token and same_target(collider, state.spawn_target_token) and state.spawn_protection_age < item.SAME_TARGET_PROTECTION then
			local gap = (tear.Position - collider.Position):Length()
			local need = (tear.Size or 0) + (collider.Size or 0) + item.COLLISION_EPSILON
			if gap <= need then
				reject_split(tear, state, collider, "same_target_protection")
				return {Collide = false, SkipCollisionEffects = true}
			end
		end
		if not is_valid_marble_collider(collider) then
			reject_split(tear, state, collider, "ignored_collider")
			return {Collide = false, SkipCollisionEffects = true}
		end
		if state.collision_claimed then
			reject_split(tear, state, collider, "already_claimed")
			return
		end
		if state.generation >= item.MAX_GENERATION then
			reject_split(tear, state, collider, "max_generation")
			return
		end
		claim_collision(tear, collider)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		flush_pending()
		settle_compat_waits()
		tick_brimstone_bursts()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	params = nil,
	Function = function()
		pending = {}
		clear_visual_marbles("game_started")
		clear_compat_jobs("game_started")
		clear_ludo_visuals()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		pending = {}
		clear_visual_marbles("room_transition")
		clear_compat_jobs("room_transition")
		clear_ludo_visuals()
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_ATTACK_ONCE,
	params = nil,
	Function = function(_, event)
		local player = event and event.player
		local attack = event and event.attack
		if not player or not attack or not player:HasCollectible(item.entity) then return end
		if attack.family == "ludo" or attack.synthetic_kind == "ludo" then
			roll_ludo_attack(player, attack)
			return
		end
		if classifier.IsSyntheticSampleAttack(attack) then return end
		if not classifier.IsPlayerAttackSource(attack.source) then return end
		local family = attack.family
		if not LASER_FAMILIES[family] and family ~= "knife" then return end
		if family == "knife" then
			local knife = (event.member and is_moms_knife(event.member)) and event.member or find_member(attack, is_moms_knife)
			if not knife then return end
		end
		if attack_has_tear(attack) then return end
		attack.tags = attack.tags or {}
		if attack.tags.matryoshka_checked then return end
		attack.tags.matryoshka_checked = true
		if LASER_FAMILIES[family] then
			local source = event.attack_source or attack.source
			local aim = classifier.GetAttackAimContext(source, attack, event)
			if not compat_roll(player) then return end
			local function launch(dir, pos)
				if not dir or not pos then return end
				local owner = classifier.GetAttackOwnerPlayer(attack) or player
				if not owner or not owner:Exists() or not owner:HasCollectible(item.entity) then return end
				if family == "brimstone" then
					queue_brimstone_burst(owner, attack, {direction = dir, position = pos})
				else
					spawn_compatible_marble(owner, attack, pos, dir, 0)
				end
			end
			if aim and aim.state == "pending" then
				registry.WhenAttackDirectionReady(attack, function(atk, dir, state)
					if state ~= "resolved" or not dir then return end
					local pos = (aim and aim.position) or (atk and atk.position) or player.Position
					launch(dir, pos)
				end)
				return
			end
			if aim and aim.direction and aim.position then
				launch(aim.direction, aim.position)
			end
			return
		end
		compat_waits[#compat_waits + 1] = {
			attack_id = attack.id,
			family = family,
			born = Game():GetFrameCount(),
			event_direction = copy_vec(event.direction),
			event_position = copy_vec(event.position),
			event_reason = event.reason,
		}
		settle_compat_waits()
	end,
})

return item
