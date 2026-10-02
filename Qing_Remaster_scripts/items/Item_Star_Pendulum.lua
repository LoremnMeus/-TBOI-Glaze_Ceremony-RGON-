local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local attack_holder = require("Qing_Remaster_scripts.callbacks.attack_trigger_holder")
local tear_snapshot = require("Qing_Remaster_scripts.auxiliary.tear_snapshot")

-- 灵摆之星：单一 Pivot 父节点 + 必然交叉主摆 + 张开期扰动。
-- Pivot 帧时钟低频游走；主摆 ±side*sin（摆幅缓慢呼吸）；扰动仅在 openness 高时。
-- 无追敌 / waypoint / cos 椭圆 depth / 旋转摆平面 / 顶部横梁。

local item = {
	ToCall = {},
	pre_ToCall = {},
	myToCall = {},
	entity = enums.Items.Pendulum_Star,
	familiar = enums.Familiars.Star_Pendulum,
	own_key = "Item_Pendulum_Star_",

	FORWARD_DISTANCE = 105,
	-- Single pendulum length: pivot is this far above bob origin (stars stay near player height).
	PENDULUM_LENGTH = 420,

	PIVOT_SIDE_FREQ_1 = 0.017,
	PIVOT_SIDE_FREQ_2 = 0.041,
	PIVOT_SIDE_AMP_1 = 32,
	PIVOT_SIDE_AMP_2 = 14,
	PIVOT_FORWARD_FREQ_1 = 0.013,
	PIVOT_FORWARD_FREQ_2 = 0.033,
	PIVOT_FORWARD_AMP_1 = 24,
	PIVOT_FORWARD_AMP_2 = 11,
	PLAYER_VELOCITY_LEAD = 6,

	PIVOT_SPRING = 0.022,
	PIVOT_DAMPING = 0.915,
	PIVOT_MAX_SPEED = 5.0,

	CONTROL_TURN_SPEED_DEG = 3.0,
	SIDE_SPAN = 94,
	SWING_ENERGY_FREQ_1 = 0.009,
	SWING_ENERGY_FREQ_2 = 0.021,
	SWING_ENERGY_AMP_1 = 0.18,
	SWING_ENERGY_AMP_2 = 0.08,
	PERTURB_FULL_OPENNESS = 0.35,
	STAR_FORWARD_WOBBLE = 24,
	STAR_SIDE_WOBBLE = 14,
	PHASE_SPEED = 0.055,

	STAR_FOLLOW_GAIN = 0.20,
	STAR_INERTIA = 0.22,
	MAX_STAR_SPEED = 10,
	SNAP_DISTANCE = 200,

	SPRITE_ROPE_BASE_ANGLE = 90,
	CAPTURE_MIN_SPREAD = 0.22,
	RECENT_SHOT_KEEP = 8,
	RELEASE_OFFSET = 8,
	RELEASE_SIDE_DEG = 3,
	HISTORY_LEN = 20,

	BASE_MEMORY = 12,
	BASE_DAMAGE_MUL = 0.75,
	BFFS_DAMAGE_MUL = 1.0,
	ROPE_BASE_LENGTH = 32,
	SCALE_BASE_LENGTH = 32,
	CAPTURE_FLASH_FRAMES = 4,
	RELEASE_FLASH_FRAMES = 6,
	COPY_SPREAD_DEG = 5,

	-- Stored Star_tear memory visuals (sprite only; not Tear entities).
	MEMORY_SETTLE_FRAMES = 12,
	MEMORY_RISE_SPEED = 0.35,
	MEMORY_RISE_MAX = 32,
	MEMORY_FOLLOW_GAIN = 0.18,
	MEMORY_INERTIA = 0.75,
	MEMORY_MAX_SPEED = 4,
	MEMORY_FLOAT_X = 3,
	MEMORY_FLOAT_Y = 2,

	-- Closing arm + sweep release (Height arc, not PositionOffset).
	RELEASE_ARM_OPENNESS = 0.50,
	RELEASE_SWEEP_RADIUS = 22,
	RELEASE_RANGE = 600,
	RELEASE_SPEED_MUL = 1.0,
	RELEASE_SPEED_MIN = 9,
	RELEASE_SPEED_MAX = 14,
	RELEASE_START_HEIGHT = -23.75,
	RELEASE_RISE_DELTA = 52,
	RELEASE_RISE_FRAMES = 11,
	RELEASE_IGNITE_FRAMES = 3,
	RELEASE_IGNITE_SPEED_MUL = 0.05,
	RELEASE_ASCEND_ACCEL_FRAMES = 8,
	RELEASE_GLIDE_DISTANCE = 220,
	RELEASE_GLIDE_FA = 0.0025,
	RELEASE_DESCEND_FA_MIN = 0.002,
	RELEASE_DESCEND_FA_MAX = 0.20,
	RELEASE_ACTIVATE_COLOR_FRAMES = 9,
	RELEASE_APEX_COLOR_FRAMES = 4,
	RELEASE_FALLBACK_INTERVAL = 2,
	RELEASE_ANIM_COOLDOWN = 5,

	debug_geometry = false,
}

local SIDE_KEY = item.own_key .. "side"
local ROPE_PATH = "gfx/mimics/Star_Pendulum/Pendulum_Rope.anm2"
local SCALE_PATH = "gfx/mimics/Star_Pendulum/Pendulum_Scale.anm2"
local MEMORY_TEAR_PATH = "gfx/mimics/Star_Pendulum/Star_tear.anm2"

local rope_sprite = nil
local scale_sprite = nil
local memory_tear_sprite = nil
local memory_tear_anim_frame = -1
local last_release_probe = nil

local function ensure_rope_sprite()
	if rope_sprite then return rope_sprite end
	rope_sprite = Sprite()
	rope_sprite:Load(ROPE_PATH, true)
	rope_sprite:Play("Idle", true)
	return rope_sprite
end

local function ensure_scale_sprite()
	if scale_sprite then return scale_sprite end
	scale_sprite = Sprite()
	scale_sprite:Load(SCALE_PATH, true)
	scale_sprite:Play("Idle", true)
	return scale_sprite
end

local function ensure_memory_tear_sprite()
	if memory_tear_sprite then return memory_tear_sprite end
	memory_tear_sprite = Sprite()
	memory_tear_sprite:Load(MEMORY_TEAR_PATH, true)
	memory_tear_sprite:Play("Idle", true)
	return memory_tear_sprite
end

local function copies(player)
	return math.max(1, player:GetCollectibleNum(item.entity))
end

local function memory_cap(_player)
	return item.BASE_MEMORY
end

local function damage_mul(player)
	local mul = item.BASE_DAMAGE_MUL
	if player:HasCollectible(CollectibleType.COLLECTIBLE_BFFS) then
		mul = math.max(mul, item.BFFS_DAMAGE_MUL)
	end
	return mul
end

local function normalize_angle_deg(a)
	return tear_snapshot.normalize_angle_deg(a)
end

local function clamp_num(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

local function remap(v, a, b, c, d)
	if b <= a then return d end
	local t = clamp_num((v - a) / (b - a), 0, 1)
	return c + (d - c) * t
end

local function normalize_dir(dir, fallback)
	fallback = fallback or Vector(1, 0)
	if not dir or dir:LengthSquared() < 0.001 then
		return fallback:Normalized()
	end
	return dir:Normalized()
end

local function clamp_vector_length(vec, max_len)
	if not vec then
		return Vector(0, 0)
	end
	local len = vec:Length()
	if len > max_len and len > 0.001 then
		return vec:Resized(max_len)
	end
	return vec
end

local function rotate_toward_vector(current, target, max_deg)
	local cur = normalize_dir(current, Vector(1, 0))
	local want = normalize_dir(target, cur)
	local cur_a = cur:GetAngleDegrees()
	local want_a = want:GetAngleDegrees()
	local diff = normalize_angle_deg(want_a - cur_a)
	local step = clamp_num(diff, -max_deg, max_deg)
	return auxi.MakeVector(cur_a + step)
end

local function player_state(player)
	local d = player:GetData()
	local st = d[item.own_key .. "state"]
	if type(st) ~= "table" then
		st = {
			phase = 0,
			phase_bootstrapped = false,
			memory = {},
			left_ent = nil,
			right_ent = nil,
			left_ptr = nil,
			right_ptr = nil,
			control_dir = Vector(1, 0),
			target_control_dir = Vector(1, 0),
			recent_shot_dir = nil,
			recent_shot_frame = -999,
			pivot = nil,
			pivot_prev = nil,
			pivot_velocity = Vector(0, 0),
			desired_left = nil,
			desired_right = nil,
			prev_left_pos = nil,
			prev_right_pos = nil,
			curr_left_pos = nil,
			curr_right_pos = nil,
			last_phase_frame = -1,
			motion_frame = -1,
			openness = 0,
			capture_enabled = false,
			phase_name = "CAPTURE",
			left_history = {},
			right_history = {},
			capture_flash = 0,
			capture_side = 0,
			release_flash = 0,
			last_cross = nil,
			last_left_error = nil,
			last_right_error = nil,
			move_debug = nil,
		}
		d[item.own_key .. "state"] = st
	end
	st.memory = st.memory or {}
	st.left_history = st.left_history or {}
	st.right_history = st.right_history or {}
	if not st.control_dir or st.control_dir:LengthSquared() < 0.001 then
		st.control_dir = Vector(1, 0)
	end
	if not st.target_control_dir or st.target_control_dir:LengthSquared() < 0.001 then
		st.target_control_dir = Vector(st.control_dir.X, st.control_dir.Y)
	end
	if not st.pivot_velocity then
		st.pivot_velocity = Vector(0, 0)
	end
	return st
end

local function phase_label(openness, crossed_bottom)
	if crossed_bottom then
		return "RELEASE"
	end
	if openness >= item.CAPTURE_MIN_SPREAD then
		return "CAPTURE"
	end
	return "CLOSING"
end

local function read_fire_input_dir(player)
	local dir = auxi.ggdir(player, false, true)
	if dir and dir:Length() > 0.05 then
		return dir:Normalized()
	end
	return nil
end

local function update_control_dir(player, st, gf)
	if st.recent_shot_dir
		and st.recent_shot_dir:LengthSquared() > 0.001
		and (gf - (st.recent_shot_frame or -999)) <= item.RECENT_SHOT_KEEP
	then
		st.target_control_dir = st.recent_shot_dir:Normalized()
	else
		local input_dir = read_fire_input_dir(player)
		if input_dir then
			st.target_control_dir = input_dir
		end
	end

	if not st.target_control_dir or st.target_control_dir:LengthSquared() < 0.001 then
		st.target_control_dir = Vector(st.control_dir.X, st.control_dir.Y)
	end

	st.control_dir = rotate_toward_vector(
		st.control_dir,
		st.target_control_dir,
		item.CONTROL_TURN_SPEED_DEG
	)
end

local function push_history(hist, pos)
	table.insert(hist, Vector(pos.X, pos.Y))
	while #hist > item.HISTORY_LEN do
		table.remove(hist, 1)
	end
end

local function get_release_direction(player, st)
	if st.recent_shot_dir and st.recent_shot_dir:LengthSquared() > 0.001 then
		return st.recent_shot_dir:Normalized()
	end
	if st.control_dir and st.control_dir:LengthSquared() > 0.001 then
		return st.control_dir:Normalized()
	end
	local input_dir = read_fire_input_dir(player)
	if input_dir then
		return input_dir
	end
	return Vector(1, 0)
end

local function render_lerp_t()
	return (Isaac.GetFrameCount() % 2) * 0.5
end

-- Entity callback offset belongs only to the entity being rendered.
-- Pendulum endpoints:
--   familiar endpoint → own render callback cache
--   pivot/world point → WorldToScreen(world)
--   never borrow another familiar's callback offset
local RENDER_CACHE_KEY = item.own_key .. "render_cache"

local function world_point_screen(world)
	if not world then return nil end
	return Isaac.WorldToScreen(world)
end

local function cache_familiar_render_position(ent, callback_offset)
	if not ent or not ent.Exists or not ent:Exists() then
		return nil
	end
	local room = Game():GetRoom()
	local world = ent.Position + (ent.PositionOffset or Vector.Zero)
	local screen = Isaac.WorldToScreen(world)
		+ (callback_offset or Vector.Zero)
		- room:GetRenderScrollOffset()
	ent:GetData()[RENDER_CACHE_KEY] = {
		frame = Isaac.GetFrameCount(),
		pos = Vector(screen.X, screen.Y),
	}
	return screen
end

local function get_familiar_render_position(ent)
	if not ent or not ent.Exists or not ent:Exists() then
		return nil
	end
	local cache = ent:GetData()[RENDER_CACHE_KEY]
	local rf = Isaac.GetFrameCount()
	if cache and cache.frame == rf and cache.pos then
		return cache.pos
	end
	-- Foreign-entity fallback: no callback offset; independent world state only.
	local t = render_lerp_t()
	local world = ent.Position + ent.Velocity * t + (ent.PositionOffset or Vector.Zero)
	return Isaac.WorldToScreen(world)
end

local function get_pivot_screen(st)
	if not st or not st.pivot then
		return nil
	end
	local t = render_lerp_t()
	local world = st.pivot
	if st.pivot_prev then
		world = st.pivot_prev + (st.pivot - st.pivot_prev) * t
	end
	return Isaac.WorldToScreen(world)
end

local function get_player_screen(player)
	if not player or not player.Exists or not player:Exists() then
		return nil
	end
	local t = render_lerp_t()
	local world = player.Position + player.Velocity * t + (player.PositionOffset or Vector.Zero)
	return Isaac.WorldToScreen(world)
end

local function collect_player_pendulums(player)
	local list = {}
	local found = Isaac.FindByType(EntityType.ENTITY_FAMILIAR, item.familiar, -1, false, false)
	for _, ent in ipairs(found) do
		local fam = ent:ToFamiliar()
		if fam and fam.Player and auxi.check_for_the_same(fam.Player, player) then
			table.insert(list, fam)
		end
	end
	return list
end

local function familiar_valid_for_side(ent, player, side)
	if not ent or not ent.Exists or not ent:Exists() then return false end
	if ent:IsDead() then return false end
	if ent.Type ~= EntityType.ENTITY_FAMILIAR or ent.Variant ~= item.familiar then return false end
	local owner = ent.Player
	if (not owner or not owner:Exists()) and ent.SpawnerEntity and ent.SpawnerEntity:ToPlayer() then
		owner = ent.SpawnerEntity:ToPlayer()
	end
	if not owner or not auxi.check_for_the_same(owner, player) then return false end
	return ent:GetData()[SIDE_KEY] == side
end

local function ensure_pair_binding(player)
	local st = player_state(player)
	if familiar_valid_for_side(st.left_ent, player, -1)
		and familiar_valid_for_side(st.right_ent, player, 1)
	then
		st.left_ptr = GetPtrHash(st.left_ent)
		st.right_ptr = GetPtrHash(st.right_ent)
		return true
	end

	local list = collect_player_pendulums(player)
	if #list < 2 then
		st.left_ent = nil
		st.right_ent = nil
		st.left_ptr = nil
		st.right_ptr = nil
		return false
	end

	local left, right = nil, nil
	for _, fam in ipairs(list) do
		local side = fam:GetData()[SIDE_KEY]
		if side == -1 and not left then
			left = fam
		elseif side == 1 and not right then
			right = fam
		end
	end

	if not left or not right or GetPtrHash(left) == GetPtrHash(right) then
		table.sort(list, function(a, b)
			local dx = a.Position.X - b.Position.X
			if math.abs(dx) > 0.5 then
				return dx < 0
			end
			return GetPtrHash(a) < GetPtrHash(b)
		end)
		left = list[1]
		right = list[2]
	end

	left:GetData()[SIDE_KEY] = -1
	right:GetData()[SIDE_KEY] = 1
	st.left_ent = left
	st.right_ent = right
	st.left_ptr = GetPtrHash(left)
	st.right_ptr = GetPtrHash(right)

	local lh = st.left_ptr
	local rh = st.right_ptr
	for _, fam in ipairs(list) do
		local h = GetPtrHash(fam)
		if h ~= lh and h ~= rh then
			fam:GetData()[SIDE_KEY] = nil
		end
	end
	return true
end

local function segment_intersection(a1, a2, b1, b2)
	local ax = a2.X - a1.X
	local ay = a2.Y - a1.Y
	local bx = b2.X - b1.X
	local by = b2.Y - b1.Y
	local den = ax * by - ay * bx

	if math.abs(den) >= 1e-8 then
		local dx = b1.X - a1.X
		local dy = b1.Y - a1.Y
		local t = (dx * by - dy * bx) / den
		local u = (dx * ay - dy * ax) / den
		if t >= 0 and t <= 1 and u >= 0 and u <= 1 then
			return true, Vector(a1.X + t * ax, a1.Y + t * ay), u
		end
	end

	local function near_proj(p)
		local se = b2 - b1
		local len2 = se:LengthSquared()
		if len2 < 1e-4 then
			if (p - b1):Length() < 6 then
				return true, b1, 0
			end
			return false
		end
		local u = math.max(0, math.min(1, (p - b1):Dot(se) / len2))
		local q = b1 + se * u
		if (p - q):Length() < 6 then
			return true, q, u
		end
		return false
	end

	local ok, pt, u = near_proj(a1)
	if ok then return true, pt, u end
	ok, pt, u = near_proj(a2)
	if ok then return true, pt, u end
	return false
end

local function push_memory_entry(st, player, entry)
	local cap = memory_cap(player)
	table.insert(st.memory, entry)
	while #st.memory > cap do
		table.remove(st.memory, 1)
	end
end

local function play_star_anim(ent, anim)
	local s = ent:GetSprite()
	if s:GetAnimation() ~= anim or not s:IsPlaying(anim) then
		s:Play(anim, true)
	end
end

local function get_anchor_ent(st, player, anchor_side)
	if anchor_side == -1 then
		if familiar_valid_for_side(st.left_ent, player, -1) then
			return st.left_ent
		end
	elseif anchor_side == 1 then
		if familiar_valid_for_side(st.right_ent, player, 1) then
			return st.right_ent
		end
	end
	return nil
end

local function distance_point_to_segment(p, a, b)
	if not p or not a or not b then
		return math.huge
	end
	local ab = b - a
	local len2 = ab:LengthSquared()
	if len2 < 1e-6 then
		return (p - a):Length()
	end
	local t = clamp_num((p - a):Dot(ab) / len2, 0, 1)
	local q = a + ab * t
	return (p - q):Length()
end

local function memory_desired_target(entry, anchor_pos)
	local settle_t = clamp_num(entry.age / item.MEMORY_SETTLE_FRAMES, 0, 1)
	local off = entry.capture_offset or Vector(0, 0)
	local settled = Vector(off.X * (1 - 0.55 * settle_t), off.Y)
	local seed = entry.seed or 0
	local float_x = math.sin(entry.age * 0.05 + seed) * item.MEMORY_FLOAT_X
	local float_y = math.sin(entry.age * 0.035 + seed * 1.7) * item.MEMORY_FLOAT_Y
	return anchor_pos
		+ settled
		+ Vector(float_x, -entry.rise + float_y)
end

local function arm_memory_release(st)
	for _, entry in ipairs(st.memory) do
		if (entry.release_state or "stored") == "stored" and entry.visual_pos then
			entry.release_state = "armed"
			entry.frozen_pos = Vector(entry.visual_pos.X, entry.visual_pos.Y)
			entry.visual_pos = Vector(entry.frozen_pos.X, entry.frozen_pos.Y)
			entry.visual_velocity = Vector(0, 0)
			entry.arm_age = 0
		end
	end
end

local function update_memory_visuals(player, st)
	for _, entry in ipairs(st.memory) do
		local state = entry.release_state or "stored"
		if state == "armed" then
			entry.arm_age = (entry.arm_age or 0) + 1
			if entry.frozen_pos then
				entry.visual_pos = Vector(entry.frozen_pos.X, entry.frozen_pos.Y)
			end
			entry.visual_velocity = Vector(0, 0)
		else
			entry.age = (entry.age or 0) + 1
			entry.rise = math.min(item.MEMORY_RISE_MAX, (entry.rise or 0) + item.MEMORY_RISE_SPEED)

			local anchor = get_anchor_ent(st, player, entry.anchor_side)
			local anchor_pos
			if anchor then
				anchor_pos = anchor.Position
			elseif st.pivot then
				local side_axis = Vector(1, 0)
				if st.control_dir and st.control_dir:LengthSquared() > 0.001 then
					local forward = st.control_dir:Normalized()
					side_axis = Vector(-forward.Y, forward.X)
				end
				anchor_pos = st.pivot
					+ Vector(0, item.PENDULUM_LENGTH)
					+ side_axis * ((entry.anchor_side or 1) * item.SIDE_SPAN * 0.35)
			else
				anchor_pos = player.Position
			end

			local target = memory_desired_target(entry, anchor_pos)
			if not entry.visual_pos then
				entry.visual_pos = Vector(target.X, target.Y)
				entry.visual_velocity = Vector(0, 0)
			else
				local wanted = (target - entry.visual_pos) * item.MEMORY_FOLLOW_GAIN
				entry.visual_velocity = (entry.visual_velocity or Vector(0, 0)) * item.MEMORY_INERTIA
					+ wanted * (1 - item.MEMORY_INERTIA)
				entry.visual_velocity = clamp_vector_length(entry.visual_velocity, item.MEMORY_MAX_SPEED)
				entry.visual_pos = entry.visual_pos + entry.visual_velocity
			end
		end
	end
end

local function tick_release_anim_cds(st)
	if (st.left_release_anim_cd or 0) > 0 then
		st.left_release_anim_cd = st.left_release_anim_cd - 1
	end
	if (st.right_release_anim_cd or 0) > 0 then
		st.right_release_anim_cd = st.right_release_anim_cd - 1
	end
end

local function try_play_side_release_anim(st, player, side)
	local ent = get_anchor_ent(st, player, side)
	if not ent then return end
	if side == -1 then
		if (st.left_release_anim_cd or 0) > 0 then return end
		st.left_release_anim_cd = item.RELEASE_ANIM_COOLDOWN
	else
		if (st.right_release_anim_cd or 0) > 0 then return end
		st.right_release_anim_cd = item.RELEASE_ANIM_COOLDOWN
	end
	play_star_anim(ent, "Idle3")
end

local function ascend_speed_mul(age)
	local t = clamp_num(age / item.RELEASE_ASCEND_ACCEL_FRAMES, 0, 1)
	local e = t * t * (3 - 2 * t)
	return item.RELEASE_IGNITE_SPEED_MUL + (1 - item.RELEASE_IGNITE_SPEED_MUL) * e
end

local function solve_fall_to_ground(height, falling_speed, frames)
	local n = math.max(1, tonumber(frames) or 1)
	local h0 = tonumber(height) or 0
	local fs0 = tonumber(falling_speed) or 0
	return 2 * (-h0 - n * fs0) / (n * (n + 1))
end

local function compute_release_velocity(player, st, entry)
	local snap = entry.snap
	local release_dir = get_release_direction(player, st)
	local speed = clamp_num(
		player.ShotSpeed * 10 * item.RELEASE_SPEED_MUL,
		item.RELEASE_SPEED_MIN,
		item.RELEASE_SPEED_MAX
	)
	local relative_angle = (snap and snap.relative_angle) or 0
	local side_bias = (entry.anchor_side or 1) * item.RELEASE_SIDE_DEG
	local dir = release_dir:Rotated(relative_angle + side_bias)
	if dir:LengthSquared() < 0.001 then
		dir = release_dir
	else
		dir = dir:Normalized()
	end
	return dir * speed
end

local function begin_release_state(motion, state)
	motion.state = state
	motion.state_age = 0
end

local function release_copy_angle(index, count)
	if count <= 1 then
		return 0
	end
	return (index - (count + 1) * 0.5) * item.COPY_SPREAD_DEG
end

local function spawn_release_tear(player, st, entry, angle_offset, copy_index, copy_count)
	local snap = entry.snap
	if not snap then return false end

	local visual_pos = entry.visual_pos or entry.frozen_pos
	if not visual_pos then
		local spawn_side = -(entry.anchor_side or 1)
		local spawn_ent = get_anchor_ent(st, player, spawn_side)
		if spawn_ent then
			visual_pos = spawn_ent.Position
		elseif st.pivot then
			visual_pos = st.pivot + Vector(0, item.PENDULUM_LENGTH)
		else
			visual_pos = player.Position
		end
	end

	local final_velocity = compute_release_velocity(player, st, entry)
	final_velocity = final_velocity:Rotated(angle_offset or 0)
	local final_speed = final_velocity:Length()

	local h0 = item.RELEASE_START_HEIGHT
	local target_h = h0 - item.RELEASE_RISE_DELTA
	local fs0, launch_fa = auxi.solve_tear_vertical_target(h0, target_h, item.RELEASE_RISE_FRAMES, 0)
	local ground_pos = auxi.tear_ground_position_for_visual(visual_pos, h0, launch_fa)
	local initial_xy = final_velocity * item.RELEASE_IGNITE_SPEED_MUL

	local tear = attack_holder.FireTear(player, ground_pos, initial_xy, {
		mode = "untracked",
		reason = "star_pendulum_echo",
		can_be_eye = false,
		no_tracer = true,
		can_trigger_streak_end = false,
		Source = player,
		damage_multiplier = 1,
	})
	if not tear then
		return false
	end

	tear_snapshot.apply(tear, snap, { skip_damage = true })
	tear.TearFlags = tear.TearFlags | TearFlags.TEAR_SPECTRAL
	tear.CollisionDamage = (snap.damage or player.Damage) * damage_mul(player)

	-- Pendulum owns speed / range / Height arc after snapshot apply.
	tear.Height = h0
	tear.FallingSpeed = fs0
	tear.FallingAcceleration = launch_fa
	tear.Velocity = initial_xy

	local spr = tear:GetSprite()
	spr:Load(MEMORY_TEAR_PATH, true)
	spr:Play("Idle", true)

	tear:SetColor(
		Color(1.55, 1.55, 1.75, 1, 0.35, 0.35, 0.65),
		item.RELEASE_ACTIVATE_COLOR_FRAMES,
		10,
		true,
		false
	)

	local td = tear:GetData()
	td[item.own_key .. "echo"] = true
	td[item.own_key .. "marked"] = true
	td[item.own_key .. "release_motion"] = {
		state = "ignite",
		age = 0,
		state_age = 0,
		target_velocity = Vector(final_velocity.X, final_velocity.Y),
		travel_distance = 0,
		prev_position = Vector(tear.Position.X, tear.Position.Y),
		apex_travel_distance = nil,
		apex_height = target_h,
		h0 = h0,
		target_h = target_h,
		fs0 = fs0,
		launch_fa = launch_fa,
		final_speed = final_speed,
		descend_fa = nil,
		homing_enabled = false,
		copy_index = copy_index,
		copy_count = copy_count,
		copy_angle = angle_offset or 0,
	}

	if item.debug_geometry then
		st.last_release_debug = {
			frame = Game():GetFrameCount(),
			state = "ignite",
			visual_pos = Vector(visual_pos.X, visual_pos.Y),
			ground_pos = Vector(ground_pos.X, ground_pos.Y),
			h0 = h0,
			target_h = target_h,
			fs0 = fs0,
			launch_fa = launch_fa,
			final_speed = final_speed,
			range = item.RELEASE_RANGE,
			glide_distance = item.RELEASE_GLIDE_DISTANCE,
			rise_frames = item.RELEASE_RISE_FRAMES,
			copy_count = copy_count,
			copy_index = copy_index,
			copy_angle = angle_offset or 0,
		}
	end
	return true
end

local function activate_memory_entry(player, st, entry)
	if not entry or not entry.snap then
		return false
	end

	local count = copies(player)
	local spawned = 0
	for i = 1, count do
		local angle_offset = release_copy_angle(i, count)
		if spawn_release_tear(player, st, entry, angle_offset, i, count) then
			spawned = spawned + 1
		end
	end
	if spawned <= 0 then
		return false
	end

	try_play_side_release_anim(st, player, entry.anchor_side or 1)
	st.release_flash = math.max(st.release_flash or 0, item.RELEASE_FLASH_FRAMES)
	return true
end

local function update_release_sweep(player, st)
	local left = st.left_ent
	local right = st.right_ent
	if not familiar_valid_for_side(left, player, -1) then return end
	if not familiar_valid_for_side(right, player, 1) then return end

	local prev_l = st.prev_left_pos or left.Position
	local prev_r = st.prev_right_pos or right.Position
	local cur_l = left.Position
	local cur_r = right.Position

	for i = #st.memory, 1, -1 do
		local entry = st.memory[i]
		if (entry.release_state or "stored") == "armed" then
			local frozen = entry.frozen_pos or entry.visual_pos
			if frozen then
				local dist
				if entry.anchor_side == -1 then
					dist = distance_point_to_segment(frozen, prev_l, cur_l)
				else
					dist = distance_point_to_segment(frozen, prev_r, cur_r)
				end
				if dist <= item.RELEASE_SWEEP_RADIUS then
					if activate_memory_entry(player, st, entry) then
						table.remove(st.memory, i)
					end
				end
			end
		end
	end
end

local function schedule_release_fallback(st)
	local delay = 0
	for _, entry in ipairs(st.memory) do
		if (entry.release_state or "stored") == "armed" and entry.fallback_delay == nil then
			entry.fallback_delay = delay
			delay = delay + item.RELEASE_FALLBACK_INTERVAL
		elseif (entry.release_state or "stored") == "stored" then
			-- Still stored at crossed bottom: arm then schedule.
			if entry.visual_pos then
				entry.release_state = "armed"
				entry.frozen_pos = Vector(entry.visual_pos.X, entry.visual_pos.Y)
				entry.visual_velocity = Vector(0, 0)
				entry.arm_age = entry.arm_age or 0
			end
			if entry.fallback_delay == nil then
				entry.fallback_delay = delay
				delay = delay + item.RELEASE_FALLBACK_INTERVAL
			end
		end
	end
end

local function process_release_fallback(player, st)
	for i = #st.memory, 1, -1 do
		local entry = st.memory[i]
		if entry.fallback_delay ~= nil then
			if entry.fallback_delay <= 0 then
				if activate_memory_entry(player, st, entry) then
					table.remove(st.memory, i)
				else
					entry.fallback_delay = nil
				end
			else
				entry.fallback_delay = entry.fallback_delay - 1
			end
		end
	end
end

local function update_released_tear_motion(tear, d, motion)
	motion.age = (motion.age or 0) + 1
	motion.state_age = (motion.state_age or 0) + 1

	local now = tear.Position
	local prev = motion.prev_position or now
	motion.travel_distance = (motion.travel_distance or 0) + (now - prev):Length()
	motion.prev_position = Vector(now.X, now.Y)

	local state = motion.state or "ignite"
	local target = motion.target_velocity
	if not target then
		d[item.own_key .. "release_motion"] = nil
		return
	end

	if state == "ignite" then
		tear.Velocity = target * item.RELEASE_IGNITE_SPEED_MUL
		if motion.state_age >= item.RELEASE_IGNITE_FRAMES then
			begin_release_state(motion, "ascend")
		end
	elseif state == "ascend" then
		tear.Velocity = target * ascend_speed_mul(motion.state_age)
		if motion.age >= item.RELEASE_RISE_FRAMES then
			begin_release_state(motion, "glide")
			motion.apex_travel_distance = motion.travel_distance
			tear.FallingSpeed = 0
			tear.FallingAcceleration = item.RELEASE_GLIDE_FA
			if not motion.homing_enabled then
				tear.TearFlags = tear.TearFlags | TearFlags.TEAR_HOMING
				motion.homing_enabled = true
			end
			tear:SetColor(
				Color(1.15, 1.25, 1.45, 1, 0.08, 0.14, 0.32),
				item.RELEASE_APEX_COLOR_FRAMES,
				8,
				true,
				false
			)
		end
	elseif state == "glide" then
		tear.Velocity = target
		local apex_travel = motion.apex_travel_distance or motion.travel_distance
		local glide_travel = motion.travel_distance - apex_travel
		if glide_travel >= item.RELEASE_GLIDE_DISTANCE then
			begin_release_state(motion, "descend")
			local remain_distance = math.max(1, item.RELEASE_RANGE - motion.travel_distance)
			local speed = math.max(0.01, target:Length())
			local fall_frames = math.max(1, math.floor(remain_distance / speed + 0.5))
			local descend_fa = solve_fall_to_ground(tear.Height, tear.FallingSpeed, fall_frames)
			descend_fa = clamp_num(descend_fa, item.RELEASE_DESCEND_FA_MIN, item.RELEASE_DESCEND_FA_MAX)
			motion.descend_fa = descend_fa
			motion.remain_distance = remain_distance
			motion.fall_frames = fall_frames
			tear.FallingAcceleration = descend_fa
			tear.Velocity = target
			-- DESCEND FA applied; hand off XY to engine.
			d[item.own_key .. "release_motion"] = nil
		end
	elseif state == "descend" then
		tear.Velocity = target
		d[item.own_key .. "release_motion"] = nil
	else
		d[item.own_key .. "release_motion"] = nil
	end

	if item.debug_geometry then
		local remain = math.max(0, item.RELEASE_RANGE - (motion.travel_distance or 0))
		last_release_probe = {
			state = motion.state,
			state_age = motion.state_age,
			total_age = motion.age,
			Height = tear.Height,
			FallingSpeed = tear.FallingSpeed,
			FallingAcceleration = tear.FallingAcceleration,
			travel_distance = motion.travel_distance,
			target_height = motion.target_h,
			apex_travel_distance = motion.apex_travel_distance,
			remaining_distance = remain,
			descend_fa = motion.descend_fa,
			launch_fa = motion.launch_fa,
			final_speed = motion.final_speed,
			copy_index = motion.copy_index,
			copy_count = motion.copy_count,
			copy_angle = motion.copy_angle,
		}
	end
end

local function update_pivot(st, pivot_target)
	if not st.pivot then
		st.pivot = Vector(pivot_target.X, pivot_target.Y)
		st.pivot_prev = Vector(pivot_target.X, pivot_target.Y)
		st.pivot_velocity = Vector(0, 0)
		return
	end

	local accel = (pivot_target - st.pivot) * item.PIVOT_SPRING
	st.pivot_velocity = (st.pivot_velocity + accel) * item.PIVOT_DAMPING
	st.pivot_velocity = clamp_vector_length(st.pivot_velocity, item.PIVOT_MAX_SPEED)
	st.pivot_prev = Vector(st.pivot.X, st.pivot.Y)
	st.pivot = st.pivot + st.pivot_velocity
end

local function drive_star(ent, target)
	local wanted = (target - ent.Position) * item.STAR_FOLLOW_GAIN
	wanted = clamp_vector_length(wanted, item.MAX_STAR_SPEED)

	if ent.FrameCount <= 1 or (target - ent.Position):Length() > item.SNAP_DISTANCE then
		ent.Position = target
		ent.Velocity = Vector(0, 0)
		return Vector(0, 0)
	end

	ent.Velocity = ent.Velocity * item.STAR_INERTIA + wanted * (1 - item.STAR_INERTIA)
	ent.Velocity = clamp_vector_length(ent.Velocity, item.MAX_STAR_SPEED)
	return ent.Velocity
end

local function perturb_gate_from_openness(openness)
	local g = clamp_num(openness / item.PERTURB_FULL_OPENNESS, 0, 1)
	return g * g
end

--- 仅逻辑 Left 调用：Pivot 帧时钟游走 → sin 主摆交叉 → 张开期扰动 → drive
local function update_pair_motion(player, st)
	local gf = Game():GetFrameCount()
	if st.motion_frame == gf then
		return
	end
	st.motion_frame = gf

	if not ensure_pair_binding(player) then
		return
	end
	local left = st.left_ent
	local right = st.right_ent
	if not familiar_valid_for_side(left, player, -1) then return end
	if not familiar_valid_for_side(right, player, 1) then return end

	st.prev_left_pos = st.curr_left_pos or Vector(left.Position.X, left.Position.Y)
	st.prev_right_pos = st.curr_right_pos or Vector(right.Position.X, right.Position.Y)

	update_control_dir(player, st, gf)

	local old_sin = math.sin(st.phase)
	st.phase = st.phase + item.PHASE_SPEED
	local new_sin = math.sin(st.phase)
	local old_open = math.abs(old_sin)
	local new_open = math.abs(new_sin)
	local closing = new_open < old_open
	st.closing = closing
	local crossed = (old_sin * new_sin <= 0) and (math.abs(old_sin) > 1e-4)
	if not st.phase_bootstrapped then
		st.phase_bootstrapped = true
		crossed = false
	end

	local forward = normalize_dir(st.control_dir, Vector(1, 0))
	local side = Vector(-forward.Y, forward.X)
	local p = st.phase
	local t = gf

	-- Layer A：Pivot 低频游走（与主 phase 解耦）
	local side_drift = math.sin(t * item.PIVOT_SIDE_FREQ_1) * item.PIVOT_SIDE_AMP_1
		+ math.sin(t * item.PIVOT_SIDE_FREQ_2 + 1.37) * item.PIVOT_SIDE_AMP_2
	local forward_drift = math.sin(t * item.PIVOT_FORWARD_FREQ_1 + 2.03) * item.PIVOT_FORWARD_AMP_1
		+ math.sin(t * item.PIVOT_FORWARD_FREQ_2 + 0.41) * item.PIVOT_FORWARD_AMP_2
	local pivot_target = player.Position
		+ forward * item.FORWARD_DISTANCE
		+ Vector(0, -item.PENDULUM_LENGTH)
		+ side * side_drift
		+ forward * forward_drift
		+ player.Velocity * item.PLAYER_VELOCITY_LEAD

	update_pivot(st, pivot_target)

	-- Layer B：主摆镜像交叉（sin=0 时 target 必重合）+ 摆幅缓慢呼吸
	local bob_origin = st.pivot + Vector(0, item.PENDULUM_LENGTH)
	local s = math.sin(p)
	local openness = math.abs(s)
	local swing_energy = 1
		+ math.sin(t * item.SWING_ENERGY_FREQ_1 + 0.43) * item.SWING_ENERGY_AMP_1
		+ math.sin(t * item.SWING_ENERGY_FREQ_2 + 1.71) * item.SWING_ENERGY_AMP_2
	swing_energy = clamp_num(swing_energy, 0.72, 1.30)
	local current_span = item.SIDE_SPAN * swing_energy
	local span = s * current_span
	local base_left = bob_origin + side * span
	local base_right = bob_origin - side * span

	-- Layer C：张开期独立扰动（交叉区 gate→0）
	local gate = perturb_gate_from_openness(openness)
	local lf = math.sin(p * 1.73 + 0.65) * item.STAR_FORWARD_WOBBLE * gate
	local ls = math.sin(p * 2.31 + 1.35) * item.STAR_SIDE_WOBBLE * gate
	local rf = math.sin(p * 1.73 + 2.15) * item.STAR_FORWARD_WOBBLE * gate
	local rs = math.sin(p * 2.31 + 3.05) * item.STAR_SIDE_WOBBLE * gate

	local left_target = base_left + forward * lf + side * ls
	local right_target = base_right + forward * rf + side * rs
	st.desired_left = left_target
	st.desired_right = right_target

	st.openness = openness
	st.capture_enabled = openness >= item.CAPTURE_MIN_SPREAD
	st.phase_name = phase_label(openness, crossed)

	tick_release_anim_cds(st)
	if closing and openness <= item.RELEASE_ARM_OPENNESS and #st.memory > 0 then
		arm_memory_release(st)
	end

	local left_vel = drive_star(left, left_target)
	local right_vel = drive_star(right, right_target)
	st.last_left_error = (left.Position - left_target):Length()
	st.last_right_error = (right.Position - right_target):Length()

	update_memory_visuals(player, st)
	update_release_sweep(player, st)

	if crossed and #st.memory > 0 then
		schedule_release_fallback(st)
	end
	process_release_fallback(player, st)

	push_history(st.left_history, left.Position)
	push_history(st.right_history, right.Position)

	st.move_debug = {
		L = {
			pos = Vector(left.Position.X, left.Position.Y),
			vel = Vector(left_vel.X, left_vel.Y),
			desired = Vector(left_target.X, left_target.Y),
		},
		R = {
			pos = Vector(right.Position.X, right.Position.Y),
			vel = Vector(right_vel.X, right_vel.Y),
			desired = Vector(right_target.X, right_target.Y),
		},
		span = span,
		current_span = current_span,
		swing_energy = swing_energy,
		gate = gate,
		side_drift = side_drift,
		forward_drift = forward_drift,
		cross_distance = (left.Position - right.Position):Length(),
		bob_origin = Vector(bob_origin.X, bob_origin.Y),
		pivot_target = Vector(pivot_target.X, pivot_target.Y),
	}

	st.curr_left_pos = Vector(left.Position.X, left.Position.Y)
	st.curr_right_pos = Vector(right.Position.X, right.Position.Y)
end

local function prepare_familiar_sprite(ent)
	ent.SpriteRotation = 0
	ent.SpriteOffset = Vector(0, 0)
	local s = ent:GetSprite()
	s.Offset = Vector(0, 0)
	return s
end

local function apply_rope_rotation(ent, pivot_render, star_render)
	if not ent or not pivot_render or not star_render then
		return
	end
	local s = ent:GetSprite()
	local rope_vec = star_render - pivot_render
	if rope_vec:LengthSquared() < 0.001 then
		s.Rotation = 0
		return
	end
	s.Rotation = rope_vec:GetAngleDegrees() - item.SPRITE_ROPE_BASE_ANGLE
end

local function render_segment_screen(sprite, from, to, base_length, vertical_source, color)
	local delta = to - from
	local len = delta:Length()
	if len < 1 then return end
	local mid = (from + to) * 0.5
	if vertical_source then
		sprite.Rotation = delta:GetAngleDegrees() - 90
		sprite.Scale = Vector(1, len / base_length)
	else
		sprite.Rotation = delta:GetAngleDegrees()
		sprite.Scale = Vector(len / base_length, 1)
	end
	sprite.Color = color or Color(1, 1, 1, 1)
	sprite:Render(mid, Vector.Zero, Vector.Zero)
	sprite.Color = Color(1, 1, 1, 1)
	sprite.Scale = Vector(1, 1)
	sprite.Rotation = 0
end

local function flash_boost(st)
	return (st.release_flash or 0) > 0 or (st.capture_flash or 0) > 0
end

local function resolve_player_from_familiar(ent)
	local player = ent.Player
	if (not player or not player:Exists()) and ent.SpawnerEntity and ent.SpawnerEntity:ToPlayer() then
		player = ent.SpawnerEntity:ToPlayer()
	end
	return player
end

local function rope_angle_deg(pivot_render, star_render)
	if not pivot_render or not star_render then
		return 0
	end
	local rope_vec = star_render - pivot_render
	if rope_vec:LengthSquared() < 0.001 then
		return 0
	end
	return rope_vec:GetAngleDegrees() - item.SPRITE_ROPE_BASE_ANGLE
end

local function render_memory_tears(st)
	if not st.memory or #st.memory <= 0 then return end
	local spr = ensure_memory_tear_sprite()
	if not spr:IsPlaying("Idle") then
		spr:Play("Idle", true)
	end
	-- Advance once per game frame (POST_FAMILIAR_RENDER is ~60Hz).
	local gf = Game():GetFrameCount()
	if gf ~= memory_tear_anim_frame then
		memory_tear_anim_frame = gf
		spr:Update()
	end
	for i, entry in ipairs(st.memory) do
		local pos = entry.visual_pos
		if pos then
			local screen = world_point_screen(pos)
			if (entry.release_state or "stored") == "armed" then
				local pulse = 0.5 + 0.5 * math.sin((entry.arm_age or 0) * 0.5)
				spr.Color = Color(
					1.12,
					1.12,
					1.30,
					1,
					0.10 + 0.08 * pulse,
					0.10 + 0.08 * pulse,
					0.24 + 0.12 * pulse
				)
			else
				spr.Color = Color(1, 1, 1, 1)
			end
			spr:Render(screen, Vector.Zero, Vector.Zero)
			spr.Color = Color(1, 1, 1, 1)
			if item.debug_geometry and Isaac.RenderText then
				local label = ((entry.release_state or "stored") == "armed") and ("A" .. tostring(i)) or ("M" .. tostring(i))
				Isaac.RenderText(label, screen.X + 6, screen.Y - 8, 0.85, 0.95, 1, 1)
			end
		end
	end
	spr.Color = Color(1, 1, 1, 1)
end

local function render_pendulum_visuals(player, st)
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	if not familiar_valid_for_side(st.left_ent, player, -1) then return end
	if not familiar_valid_for_side(st.right_ent, player, 1) then return end

	local left_render = get_familiar_render_position(st.left_ent)
	local right_render = get_familiar_render_position(st.right_ent)
	local player_render = get_player_screen(player)
	local pivot_render = get_pivot_screen(st)
	if not left_render or not right_render or not player_render or not pivot_render then return end

	-- Rotation already applied in each familiar's PRE using that familiar's own cache + pivot.
	local rope = ensure_rope_sprite()
	local rope_a = flash_boost(st) and 0.85 or 0.55
	local rope_col = Color(0.85, 0.9, 1, rope_a, 0.05, 0.08, 0.12)
	-- Pivot → Left / Pivot → Right only (always exactly two drivers).
	render_segment_screen(rope, pivot_render, left_render, item.ROPE_BASE_LENGTH, true, rope_col)
	render_segment_screen(rope, pivot_render, right_render, item.ROPE_BASE_LENGTH, true, rope_col)

	local openness = st.openness or 0
	if openness >= item.CAPTURE_MIN_SPREAD then
		local base_a = remap(openness, item.CAPTURE_MIN_SPREAD, 1, 0.15, 0.7)
		if flash_boost(st) then
			base_a = math.min(0.9, base_a + 0.2)
		end
		local scale = ensure_scale_sprite()
		render_segment_screen(
			scale, left_render, right_render,
			item.SCALE_BASE_LENGTH, false,
			Color(1, 0.45, 0.45, base_a, 0.2, 0.05, 0.05)
		)
	end

	render_memory_tears(st)

	if not item.debug_geometry or not Isaac.RenderText then return end

	local function mark(pos, label, r, g, b)
		Isaac.RenderText(label, pos.X - 4, pos.Y - 6, r, g, b, 1)
	end

	mark(pivot_render, "P", 1, 0.85, 0.2)
	mark(left_render, "L", 0.4, 1, 1)
	mark(right_render, "R", 1, 0.6, 1)
	local md = st.move_debug
	if md and md.pivot_target then
		mark(world_point_screen(md.pivot_target), "PT", 1, 0.55, 0.2)
	end
	if md and md.bob_origin then
		mark(world_point_screen(md.bob_origin), "B", 0.9, 1, 0.4)
	end
	if st.desired_left then
		mark(world_point_screen(st.desired_left), "DL", 0.5, 1, 0.7)
	end
	if st.desired_right then
		mark(world_point_screen(st.desired_right), "DR", 1, 0.7, 0.9)
	end

	if st.pivot and st.control_dir then
		for i = 1, 8 do
			local w = st.pivot + st.control_dir * (10 * i)
			local p = world_point_screen(w)
			Isaac.RenderText(".", p.X, p.Y, 1, 0.9, 0.2, 0.85)
		end
	end

	for _, hist in ipairs({ st.left_history, st.right_history }) do
		for i = 1, #hist do
			local p = world_point_screen(hist[i])
			Isaac.RenderText(".", p.X, p.Y, 0.55, 0.9, 0.7, 0.55)
		end
	end

	if md and md.L then
		local tip = world_point_screen(md.L.pos + md.L.vel * 10)
		Isaac.RenderText(">", tip.X, tip.Y, 0.5, 1, 1, 1)
	end
	if md and md.R then
		local tip = world_point_screen(md.R.pos + md.R.vel * 10)
		Isaac.RenderText(">", tip.X, tip.Y, 1, 0.6, 1, 1)
	end

	local hud = player_render + Vector(-58, -140)
	local mem_n = #st.memory
	local cap = memory_cap(player)
	local ctrl_a = st.control_dir and st.control_dir:GetAngleDegrees() or 0
	local left_rope_a = rope_angle_deg(pivot_render, left_render)
	local right_rope_a = rope_angle_deg(pivot_render, right_render)
	Isaac.RenderText(string.format("Phase: %.2f  Open: %.2f", st.phase, openness), hud.X, hud.Y, 1, 1, 1, 1)
	Isaac.RenderText(
		string.format("%s Cap:%s Mem:%d/%d", st.phase_name or "?", st.capture_enabled and "ON" or "OFF", mem_n, cap),
		hud.X, hud.Y + 10, 1, 0.9, 0.5, 1
	)
	Isaac.RenderText(
		string.format(
			"Ctrl:%.0f Gate:%.2f Energy:%.2f Span:%.0f",
			ctrl_a,
			md and md.gate or 0,
			md and md.swing_energy or 1,
			md and md.current_span or 0
		),
		hud.X, hud.Y + 20, 0.85, 1, 0.7, 1
	)
	Isaac.RenderText(
		string.format(
			"Drift S/F:%.0f/%.0f RopeL:%.1f RopeR:%.1f",
			md and md.side_drift or 0,
			md and md.forward_drift or 0,
			left_rope_a,
			right_rope_a
		),
		hud.X, hud.Y + 30, 0.8, 0.85, 1, 1
	)
	Isaac.RenderText(
		string.format(
			"Err L/R:%.1f/%.1f Cross:%.1f",
			st.last_left_error or -1,
			st.last_right_error or -1,
			md and md.cross_distance or -1
		),
		hud.X, hud.Y + 40, 0.7, 0.9, 1, 1
	)
	if st.last_cross and st.last_cross.point then
		mark(world_point_screen(st.last_cross.point), "X", 1, 0.3, 0.3)
	end
	if st.prev_left_pos and st.left_ent then
		local a = world_point_screen(st.prev_left_pos)
		local b = get_familiar_render_position(st.left_ent)
		if a and b then
			Isaac.RenderText("-", a.X, a.Y, 0.4, 1, 0.6, 0.7)
			Isaac.RenderText("-", b.X, b.Y, 0.4, 1, 0.6, 0.7)
		end
	end
	if st.prev_right_pos and st.right_ent then
		local a = world_point_screen(st.prev_right_pos)
		local b = get_familiar_render_position(st.right_ent)
		if a and b then
			Isaac.RenderText("-", a.X, a.Y, 1, 0.5, 0.9, 0.7)
			Isaac.RenderText("-", b.X, b.Y, 1, 0.5, 0.9, 0.7)
		end
	end
	if st.last_release_debug or last_release_probe then
		local rd = last_release_probe or st.last_release_debug
		Isaac.RenderText(
			string.format(
				"Rel %s a:%d/%d v:%.1f",
				tostring(rd.state or "?"),
				rd.state_age or 0,
				rd.total_age or 0,
				rd.final_speed or (st.last_release_debug and st.last_release_debug.final_speed) or 0
			),
			hud.X, hud.Y + 50, 0.7, 1, 0.85, 1
		)
		Isaac.RenderText(
			string.format(
				"H:%.1f FS:%.2f FA:%.4f",
				rd.Height or rd.target_h or 0,
				rd.FallingSpeed or 0,
				rd.FallingAcceleration or rd.launch_fa or 0
			),
			hud.X, hud.Y + 60, 0.7, 1, 0.85, 1
		)
		Isaac.RenderText(
			string.format(
				"Dist:%.0f Rem:%.0f Apex:%.0f DFA:%.4f",
				rd.travel_distance or 0,
				rd.remaining_distance or 0,
				rd.apex_travel_distance or -1,
				rd.descend_fa or 0
			),
			hud.X, hud.Y + 70, 0.7, 1, 0.85, 1
		)
		if rd.copy_count or (st.last_release_debug and st.last_release_debug.copy_count) then
			local cc = rd.copy_count or st.last_release_debug.copy_count or 1
			local ci = rd.copy_index or st.last_release_debug.copy_index or 1
			local ca = rd.copy_angle or st.last_release_debug.copy_angle or 0
			Isaac.RenderText(
				string.format("Copy %d/%d angle=%.1f", ci, cc, ca),
				hud.X, hud.Y + 80, 0.85, 1, 0.7, 1
			)
		end
	end
	Isaac.RenderText(
		string.format("Close:%s", st.closing and "Y" or "N"),
		hud.X, hud.Y + 80, 0.8, 0.9, 1, 1
	)
end

local function reset_room_runtime(player)
	local st = player_state(player)
	st.phase = 0
	st.phase_bootstrapped = false
	st.memory = {}
	st.pivot = nil
	st.pivot_prev = nil
	st.pivot_velocity = Vector(0, 0)
	st.desired_left = nil
	st.desired_right = nil
	st.prev_left_pos = nil
	st.prev_right_pos = nil
	st.curr_left_pos = nil
	st.curr_right_pos = nil
	st.motion_frame = -1
	st.last_phase_frame = -1
	st.capture_flash = 0
	st.release_flash = 0
	st.phase_name = "CAPTURE"
	st.move_debug = nil
	st.last_cross = nil
	st.last_release_debug = nil
	st.closing = false
	st.left_release_anim_cd = 0
	st.right_release_anim_cd = 0
	st.last_left_error = nil
	st.last_right_error = nil
	st.left_history = {}
	st.right_history = {}
	local aim = normalize_dir(st.control_dir, Vector(1, 0))
	st.control_dir = Vector(aim.X, aim.Y)
	st.target_control_dir = Vector(aim.X, aim.Y)
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_EVALUATE_CACHE,
	params = nil,
	Function = function(_, player, cacheFlag)
		if cacheFlag ~= CacheFlag.CACHE_FAMILIARS then return end
		if not auxi.has_have_coll(player, item.entity) then
			player:CheckFamiliar(
				item.familiar,
				0,
				player:GetCollectibleRNG(item.entity),
				Isaac.GetItemConfig():GetCollectible(item.entity)
			)
			return
		end
		player:CheckFamiliar(
			item.familiar,
			2,
			player:GetCollectibleRNG(item.entity),
			Isaac.GetItemConfig():GetCollectible(item.entity)
		)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_FAMILIAR_INIT,
	params = item.familiar,
	Function = function(_, ent)
		ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
		ent.GridCollisionClass = GridCollisionClass.COLLISION_NONE
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_ROOM,
	params = nil,
	Function = function(_)
		for i = 0, Game():GetNumPlayers() - 1 do
			local p = Game():GetPlayer(i)
			if p and auxi.has_have_coll(p, item.entity) then
				reset_room_runtime(p)
			end
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE,
	params = nil,
	Function = function(_, player)
		if not auxi.has_have_coll(player, item.entity) then return end
		local st = player_state(player)
		local gf = Game():GetFrameCount()
		if st.last_phase_frame == gf then return end
		st.last_phase_frame = gf

		if st.recent_shot_dir
			and st.recent_shot_dir:LengthSquared() > 0.001
			and (gf - (st.recent_shot_frame or -999)) <= item.RECENT_SHOT_KEEP
		then
			st.target_control_dir = st.recent_shot_dir:Normalized()
		else
			local input_dir = read_fire_input_dir(player)
			if input_dir then
				st.target_control_dir = input_dir
			end
		end

		if st.capture_flash and st.capture_flash > 0 then
			st.capture_flash = st.capture_flash - 1
		end
		if st.release_flash and st.release_flash > 0 then
			st.release_flash = st.release_flash - 1
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_FAMILIAR_UPDATE,
	params = item.familiar,
	Function = function(_, ent)
		local player = resolve_player_from_familiar(ent)
		if not player then return end
		if not auxi.has_have_coll(player, item.entity) then return end

		local st = player_state(player)
		ensure_pair_binding(player)

		local side = ent:GetData()[SIDE_KEY]
		if side ~= -1 and side ~= 1 then
			return
		end

		if side == -1 then
			st.left_ent = ent
			st.left_ptr = GetPtrHash(ent)
			update_pair_motion(player, st)
		else
			st.right_ent = ent
			st.right_ptr = GetPtrHash(ent)
		end

		local s = prepare_familiar_sprite(ent)

		local flashing = false
		if (st.release_flash or 0) > 0 then
			flashing = true
			s.Color = Color(1.35, 1.35, 1.55, 1, 0.18, 0.18, 0.32)
		elseif (st.capture_flash or 0) > 0 and st.capture_side == side then
			flashing = true
			s.Color = Color(1.45, 1.45, 1.65, 1, 0.22, 0.22, 0.38)
		else
			s.Color = Color(1, 1, 1, 1)
		end

		if not flashing then
			local anim = s:GetAnimation()
			if anim ~= "Idle" and anim ~= "Idle2" and anim ~= "Idle3" then
				s:Play("Idle", true)
			elseif (anim == "Idle2" or anim == "Idle3") and s:IsFinished(anim) then
				s:Play("Idle", true)
			elseif anim == "Idle" and not s:IsPlaying("Idle") and s:IsFinished("Idle") then
				s:Play("Idle", true)
			end
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_TEAR_UPDATE,
	params = nil,
	Function = function(_, tear)
		local d = tear:GetData()
		local motion = d[item.own_key .. "release_motion"]
		if motion then
			update_released_tear_motion(tear, d, motion)
		end
		if d[item.own_key .. "echo"] or d[item.own_key .. "marked"] then
			d[item.own_key .. "prev"] = tear.Position
			return
		end

		local player = auxi.check_spawner_player(tear)
		if not player or not auxi.has_have_coll(player, item.entity) then
			d[item.own_key .. "prev"] = tear.Position
			return
		end
		if tear.SpawnerType == EntityType.ENTITY_FAMILIAR then
			d[item.own_key .. "prev"] = tear.Position
			return
		end

		local st = player_state(player)

		if not d[item.own_key .. "seen_for_aim"] then
			d[item.own_key .. "seen_for_aim"] = true
			if tear.Velocity:LengthSquared() > 0.01 then
				st.recent_shot_dir = tear.Velocity:Normalized()
				st.recent_shot_frame = Game():GetFrameCount()
			end
		end

		if not familiar_valid_for_side(st.left_ent, player, -1)
			or not familiar_valid_for_side(st.right_ent, player, 1)
		then
			d[item.own_key .. "prev"] = tear.Position
			return
		end

		local prev = d[item.own_key .. "prev"] or tear.Position
		local cur = tear.Position
		d[item.own_key .. "prev"] = cur

		local thr = item.CAPTURE_MIN_SPREAD
		local openness = st.openness or math.abs(math.sin(st.phase))
		if openness < thr then
			return
		end

		local left = st.left_ent.Position
		local right = st.right_ent.Position
		local prev_left = st.prev_left_pos or left
		local prev_right = st.prev_right_pos or right

		local crossed, point, line_t = segment_intersection(prev, cur, left, right)
		if not crossed then
			crossed, point, line_t = segment_intersection(prev, cur, prev_left, prev_right)
		end

		if crossed then
			d[item.own_key .. "marked"] = true
			local snap = tear_snapshot.capture(tear, { aim_dir = st.control_dir })
			local anchor_side = (line_t < 0.5) and -1 or 1
			local anchor = (anchor_side == -1) and st.left_ent or st.right_ent
			local capture_offset = Vector(0, 0)
			if anchor then
				capture_offset = point - anchor.Position
			end
			push_memory_entry(st, player, {
				snap = snap,
				anchor_side = anchor_side,
				capture_offset = capture_offset,
				visual_pos = Vector(point.X, point.Y),
				visual_velocity = Vector(0, 0),
				age = 0,
				rise = 0,
				seed = (Game():GetFrameCount() + #st.memory * 17) * 0.137,
				release_state = "stored",
				frozen_pos = nil,
			})

			st.capture_flash = item.CAPTURE_FLASH_FRAMES
			st.capture_side = anchor_side
			st.last_cross = {
				point = point,
				line_t = line_t,
				frame = Game():GetFrameCount(),
			}

			local star = (st.capture_side == -1) and st.left_ent or st.right_ent
			if familiar_valid_for_side(star, player, st.capture_side) then
				play_star_anim(star, "Idle2")
			end
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_FAMILIAR_RENDER,
	params = item.familiar,
	Function = function(_, ent, offset)
		local side = ent:GetData()[SIDE_KEY]
		if side ~= -1 and side ~= 1 then return end
		ent.SpriteRotation = 0
		local player = resolve_player_from_familiar(ent)
		local st = player and player_state(player) or nil
		local star_render = cache_familiar_render_position(ent, offset)
		local pivot_render = get_pivot_screen(st)
		apply_rope_rotation(ent, pivot_render, star_render)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_FAMILIAR_RENDER,
	params = item.familiar,
	Function = function(_, ent, offset)
		local side = ent:GetData()[SIDE_KEY]
		-- Refresh this familiar's own cache if PRE was skipped; never write the opposite star.
		cache_familiar_render_position(ent, offset)
		if side ~= 1 then return end

		local player = resolve_player_from_familiar(ent)
		if not player or not auxi.has_have_coll(player, item.entity) then return end

		local st = player_state(player)
		ensure_pair_binding(player)
		render_pendulum_visuals(player, st)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_FAMILIAR_COLLISION,
	params = item.familiar,
	Function = function(_, ent, col, low)
		return true
	end,
})

function item.restore_debug_defaults()
	item.debug_geometry = false
end

return item
