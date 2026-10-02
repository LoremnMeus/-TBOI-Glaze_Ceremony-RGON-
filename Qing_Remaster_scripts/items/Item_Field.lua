-- 逆反力场
-- 不看玩家静止或移动。立场固定在房间里，不跟随玩家，也不把眼泪吸向中心。
-- 持有份数 = 房间 Field 数量；多个 Field 组成同一个捕获网络，眼泪升空后可从任意场重新出现。
-- 只有进入真实圆形区域、且属于持有者的眼泪会被捕获。捕获一旦开始就不再因擦出边界而取消。
-- 入口波纹只表示真正的边界穿越；在场内生成的眼泪会捕获，但不画 ripple。
-- 眼泪保留自己的落点，横向速度逐渐消失。纵向交给 FallingSpeed / FallingAcceleration，由引擎积分 Height。
-- 升到顶后由紫色小洞把同一颗眼泪送回地面，不复制伤害实体，不改 TearFlags / 碰撞。
-- 捕获资格：ignore_field 与 TEAR_LUDOVICO 不捕获。TEAR_WAIT、TEAR_ORBIT、TEAR_ORBIT_ADVANCED 和普通泪都正常捕获。
-- 边界和场内粒子、入口波纹都只在渲染里画，不生成波纹实体。粒子 rise 是世界空间高度，经 W2S 前再偏移。
-- 物理只写在 UPDATE。CAPTURE_LIMIT 是整个 Field 网络的返回泪上限，不是每场一份。
--
-- Field vertical ownership:
--
-- Height              = authoritative vertical position
-- FallingSpeed        = actual vertical velocity; keep it meaningful while the tear is visible
-- FallingAcceleration = Field upward acceleration
-- Item_Field_vertical_accel = the rise acceleration restored after capture braking
--
-- During capture, Field rapidly brakes a positive FallingSpeed and then reverses it.
-- During rise, the engine integrates Height from FallingSpeed / FallingAcceleration.
-- FallingSpeed is capped at -RISE_SPEED_MAX. At the cap, FallingAcceleration is 0.
-- Rise ends when the tear's visual screen Y leaves the top, not at a fixed Height.
-- Accel and speed caps are scaled for POST_TEAR_UPDATE at 30 Hz. The old rise
-- integrated the same curve on POST_TEAR_RENDER at about 60 Hz.
--
-- Do not manually integrate Height while also leaving a nonzero FallingSpeed.
-- That double-integrates the vertical trajectory.
-- FallingSpeed may be 0 only while the tear is hidden or at a respawn reset.
--
-- Crossing the tear FA = 0.001 conversion breakpoint must go through
-- auxi.transition_tear_falling_accel, which preserves visual height and visual speed.
-- Field does that once, when a normal tear enters. Later negative <-> 0 changes stay
-- on the same branch and must not rebuild Height.
--
-- PositionOffset is derived from Height / FallingAcceleration.
-- Field syncs it only on that entry transition. It is not a second Z trajectory.
-- Canonical rule: codex_work/notes/tear_vertical_control_rules.md

local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local TEAR_STATE_CAPTURE = 1
local TEAR_STATE_RISE = 2
local TEAR_STATE_WAIT = 3

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},

	entity = enums.Items.Field,
	effect = enums.Entities.trans_field_door,
	own_key = "Item_Field_",

	FIELD_RADIUS = 80,
	FIELD_MARGIN = 18,

	CAPTURE_DAMPING = 0.86,
	CAPTURE_STOP_SPEED = 0.25,
	CAPTURE_VERTICAL_BRAKE_FRAMES = 3,
	CAPTURE_LIMIT = 64,
	FIELD_TEARS_BONUS = 1.0,

	RESPAWN_RADIUS_MUL = 0.78,
	RESPAWN_POINT_TRIES = 10,
	RESPAWN_COLOR_FRAMES = 18,
	RESPAWN_COLOR_PRIORITY = 10,
	RESPAWN_COLOR_RO = 0.42,
	RESPAWN_COLOR_GO = 0.04,
	RESPAWN_COLOR_BO = 0.68,

	ENTRY_WAVE_FRAMES = 18,
	ENTRY_WAVE_SCALE_START = 0.52,
	ENTRY_WAVE_SCALE_END = 1.35,
	ENTRY_WAVE_EDGE_SCALE = 0.18,
	ENTRY_WAVE_ALPHA = 0.92,
	ENTRY_WAVE_RO = 0.18,
	ENTRY_WAVE_GO = 0.02,
	ENTRY_WAVE_BO = 0.30,

	RISE_ACCEL_SCALE = 1.20,
	RISE_SHOTSPEED_BIAS = 0.30,
	RISE_ACCEL_MIN = 0.20,
	RISE_SPEED_MAX = 14.0,
	RISE_SCREEN_TOP_Y = 0,
	RISE_HEIGHT_SAFETY = -900,
	RISE_RESPAWN_HEIGHT = -10,

	LIFE_GRACE_CYCLES = 4,
	LIFE_SOFT_END = 7,
	LIFE_HARD_END = 11,

	BOUNDARY_PARTICLES = 20,
	BOUNDARY_RISE = 28,
	BOUNDARY_DRIFT = 0.018,
	BOUNDARY_ALPHA = 0.40,

	INNER_PARTICLES = 18,
	INNER_RISE_MIN = 105,
	INNER_RISE_MAX = 155,
	INNER_SPEED_MIN = 2.0,
	INNER_SPEED_MAX = 3.2,
	INNER_DRIFT = 3,
	INNER_ALPHA = 0.38,
	INNER_SCALE_MIN = 0.45,
	INNER_SCALE_MAX = 0.75,

	debug_circle = false,
	debug_labels = false,
}

local DEFAULTS = {
	FIELD_RADIUS = item.FIELD_RADIUS,
	FIELD_MARGIN = item.FIELD_MARGIN,
	CAPTURE_DAMPING = item.CAPTURE_DAMPING,
	CAPTURE_STOP_SPEED = item.CAPTURE_STOP_SPEED,
	CAPTURE_VERTICAL_BRAKE_FRAMES = item.CAPTURE_VERTICAL_BRAKE_FRAMES,
	CAPTURE_LIMIT = item.CAPTURE_LIMIT,
	FIELD_TEARS_BONUS = item.FIELD_TEARS_BONUS,
	RESPAWN_RADIUS_MUL = item.RESPAWN_RADIUS_MUL,
	RESPAWN_POINT_TRIES = item.RESPAWN_POINT_TRIES,
	RESPAWN_COLOR_FRAMES = item.RESPAWN_COLOR_FRAMES,
	RESPAWN_COLOR_PRIORITY = item.RESPAWN_COLOR_PRIORITY,
	RESPAWN_COLOR_RO = item.RESPAWN_COLOR_RO,
	RESPAWN_COLOR_GO = item.RESPAWN_COLOR_GO,
	RESPAWN_COLOR_BO = item.RESPAWN_COLOR_BO,
	ENTRY_WAVE_FRAMES = item.ENTRY_WAVE_FRAMES,
	ENTRY_WAVE_SCALE_START = item.ENTRY_WAVE_SCALE_START,
	ENTRY_WAVE_SCALE_END = item.ENTRY_WAVE_SCALE_END,
	ENTRY_WAVE_EDGE_SCALE = item.ENTRY_WAVE_EDGE_SCALE,
	ENTRY_WAVE_ALPHA = item.ENTRY_WAVE_ALPHA,
	ENTRY_WAVE_RO = item.ENTRY_WAVE_RO,
	ENTRY_WAVE_GO = item.ENTRY_WAVE_GO,
	ENTRY_WAVE_BO = item.ENTRY_WAVE_BO,
	RISE_ACCEL_SCALE = item.RISE_ACCEL_SCALE,
	RISE_SHOTSPEED_BIAS = item.RISE_SHOTSPEED_BIAS,
	RISE_ACCEL_MIN = item.RISE_ACCEL_MIN,
	RISE_SPEED_MAX = item.RISE_SPEED_MAX,
	RISE_SCREEN_TOP_Y = item.RISE_SCREEN_TOP_Y,
	RISE_HEIGHT_SAFETY = item.RISE_HEIGHT_SAFETY,
	RISE_RESPAWN_HEIGHT = item.RISE_RESPAWN_HEIGHT,
	LIFE_GRACE_CYCLES = item.LIFE_GRACE_CYCLES,
	LIFE_SOFT_END = item.LIFE_SOFT_END,
	LIFE_HARD_END = item.LIFE_HARD_END,
	BOUNDARY_PARTICLES = item.BOUNDARY_PARTICLES,
	BOUNDARY_RISE = item.BOUNDARY_RISE,
	BOUNDARY_DRIFT = item.BOUNDARY_DRIFT,
	BOUNDARY_ALPHA = item.BOUNDARY_ALPHA,
	INNER_PARTICLES = item.INNER_PARTICLES,
	INNER_RISE_MIN = item.INNER_RISE_MIN,
	INNER_RISE_MAX = item.INNER_RISE_MAX,
	INNER_SPEED_MIN = item.INNER_SPEED_MIN,
	INNER_SPEED_MAX = item.INNER_SPEED_MAX,
	INNER_DRIFT = item.INNER_DRIFT,
	INNER_ALPHA = item.INNER_ALPHA,
	INNER_SCALE_MIN = item.INNER_SCALE_MIN,
	INNER_SCALE_MAX = item.INNER_SCALE_MAX,
}

local room_fields = nil
local boundary_sprite = nil
local entry_wave_sprite = nil
local entry_waves = {}
local capture_serial = 0

local function key(name)
	return item.own_key .. name
end

local function get_field_count()
	local count = 0
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Isaac.GetPlayer(i)
		if player then
			count = count + player:GetCollectibleNum(item.entity)
		end
	end
	return count
end

local function has_field_holder()
	return get_field_count() > 0
end

local function room_fields_active()
	return room_fields and room_fields.active and room_fields.fields and #room_fields.fields > 0
end

local function get_active_fields()
	if not room_fields_active() then
		return {}
	end
	return room_fields.fields
end

local function room_identity()
	local level = Game():GetLevel()
	local desc = level:GetCurrentRoomDesc()
	local room = Game():GetRoom()
	local seed = room:GetSpawnSeed()
	if desc and desc.SpawnSeed and desc.SpawnSeed ~= 0 then
		seed = desc.SpawnSeed
	end
	local grid = desc and desc.SafeGridIndex or -1
	local dimension = 0
	if level.GetDimension then
		dimension = level:GetDimension() or 0
	end
	return tostring(level:GetStage()) .. ":" .. tostring(level:GetStageType()) .. ":"
		.. tostring(dimension) .. ":" .. tostring(grid) .. ":" .. tostring(seed), seed
end

local function field_rng(seed)
	if not seed or seed == 0 then seed = 1 end
	local rng = RNG()
	rng:SetSeed(seed, 35)
	local mix = (item.entity % 5) + 3
	for _ = 1, mix do
		rng:Next()
	end
	return rng
end

local function door_penalty(room, pos, radius)
	local penalty = 0
	local near = (radius + item.FIELD_MARGIN) * (radius + item.FIELD_MARGIN)
	local slots = DoorSlot.NUM_DOOR_SLOTS or 8
	for slot = 0, slots - 1 do
		if room:GetDoor(slot) then
			local door_pos = room:GetDoorSlotPosition(slot)
			if door_pos and pos:DistanceSquared(door_pos) <= near then
				penalty = penalty + 40
			end
		end
	end
	return penalty
end

local function obstacle_penalty(room, pos, radius)
	local penalty = 0
	local samples = {
		pos,
		pos + Vector(radius * 0.55, 0),
		pos - Vector(radius * 0.55, 0),
		pos + Vector(0, radius * 0.55),
		pos - Vector(0, radius * 0.55),
	}
	for _, sample in ipairs(samples) do
		local collision = room:GetGridCollisionAtPos(sample)
		if collision == GridCollisionClass.COLLISION_WALL
			or collision == GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER then
			penalty = penalty + 28
		elseif collision == GridCollisionClass.COLLISION_SOLID then
			penalty = penalty + 8
		end
	end
	return penalty
end

local function player_penalty(pos)
	local penalty = 0
	local limit = 70 * 70
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Isaac.GetPlayer(i)
		if player and pos:DistanceSquared(player.Position) <= limit then
			penalty = penalty + 25
		end
	end
	return penalty
end

local function score_candidate(room, pos, center, radius)
	if not room:IsPositionInRoom(pos, radius * 0.82) then
		return nil
	end
	local score = 100
	score = score - door_penalty(room, pos, radius)
	score = score - obstacle_penalty(room, pos, radius)
	score = score - player_penalty(pos)
	local away = pos:Distance(center)
	if away > radius * 1.7 then
		score = score - 20
	end
	score = score + math.max(0, 12 - away / 28)
	return score
end

local function field_spacing_penalty(pos, chosen, radius)
	local penalty = 0
	local soft = radius * 1.45
	for _, field in ipairs(chosen) do
		local dist = pos:Distance(field.center)
		if dist < soft then
			penalty = penalty + (soft - dist) * 2
		end
	end
	return penalty
end

local function build_field_candidates(room, center, radius)
	local tl = room:GetTopLeftPos()
	local br = room:GetBottomRightPos()
	local span = br - tl
	local ox = math.max(48, math.min(math.abs(span.X) * 0.22, 110))
	local oy = math.max(36, math.min(math.abs(span.Y) * 0.18, 80))
	local candidates = {
		center,
		center + Vector(-ox, 0),
		center + Vector(ox, 0),
		center + Vector(0, -oy),
		center + Vector(0, oy),
		center + Vector(-ox * 0.75, -oy * 0.7),
		center + Vector(ox * 0.75, -oy * 0.7),
		center + Vector(-ox * 0.75, oy * 0.7),
		center + Vector(ox * 0.75, oy * 0.7),
	}
	if math.abs(span.X) > radius * 4 or math.abs(span.Y) > radius * 4 then
		local ox2 = math.max(ox, math.min(math.abs(span.X) * 0.36, 180))
		local oy2 = math.max(oy, math.min(math.abs(span.Y) * 0.30, 140))
		candidates[#candidates + 1] = center + Vector(-ox2, 0)
		candidates[#candidates + 1] = center + Vector(ox2, 0)
		candidates[#candidates + 1] = center + Vector(0, -oy2)
		candidates[#candidates + 1] = center + Vector(0, oy2)
		candidates[#candidates + 1] = center + Vector(-ox2 * 0.7, -oy2 * 0.65)
		candidates[#candidates + 1] = center + Vector(ox2 * 0.7, -oy2 * 0.65)
		candidates[#candidates + 1] = center + Vector(-ox2 * 0.7, oy2 * 0.65)
		candidates[#candidates + 1] = center + Vector(ox2 * 0.7, oy2 * 0.65)
	end
	local _, seed = room_identity()
	local rng = field_rng(seed + 17)
	local margin = radius * 0.82
	for _ = 1, 24 do
		local x = tl.X + margin + rng:RandomFloat() * math.max(1, span.X - margin * 2)
		local y = tl.Y + margin + rng:RandomFloat() * math.max(1, span.Y - margin * 2)
		candidates[#candidates + 1] = Vector(x, y)
	end
	return candidates
end

local function choose_field_centers(room, count, seed)
	local radius = item.FIELD_RADIUS
	local center = room:GetCenterPos()
	local chosen = {}
	if count <= 0 then
		return chosen
	end
	local span = room:GetBottomRightPos() - room:GetTopLeftPos()
	if span.X < radius * 2.15 or span.Y < radius * 2.15 then
		for n = 1, count do
			chosen[#chosen + 1] = {
				id = n,
				center = center,
				radius = radius,
				seed = (seed or 1) + n * 9973,
			}
		end
		return chosen
	end
	local candidates = build_field_candidates(room, center, radius)
	local scored = {}
	for _, pos in ipairs(candidates) do
		local score = score_candidate(room, pos, center, radius)
		if score then
			scored[#scored + 1] = { pos = pos, base = score }
		end
	end
	local used = {}
	for n = 1, count do
		local best_i = nil
		local best_score = -1e9
		for i, entry in ipairs(scored) do
			if not used[i] then
				local score = entry.base - field_spacing_penalty(entry.pos, chosen, radius)
				if score > best_score + 1e-6
					or (math.abs(score - best_score) <= 1e-6 and best_i and (
						entry.pos.X < scored[best_i].pos.X - 1e-6
						or (math.abs(entry.pos.X - scored[best_i].pos.X) <= 1e-6 and entry.pos.Y < scored[best_i].pos.Y)
					))
				then
					best_score = score
					best_i = i
				elseif best_i == nil then
					best_score = score
					best_i = i
				end
			end
		end
		if not best_i then
			chosen[#chosen + 1] = {
				id = n,
				center = center + Vector((n - 1) * 8, 0),
				radius = radius,
				seed = (seed or 1) + n * 9973,
			}
		else
			used[best_i] = true
			chosen[#chosen + 1] = {
				id = n,
				center = scored[best_i].pos,
				radius = radius,
				seed = (seed or 1) + n * 9973,
			}
		end
	end
	return chosen
end

local function field_color(alpha, strength)
	strength = strength or 1
	return Color(0.78, 0.42, 0.96, alpha, 0.16 * strength, 0.02, 0.24 * strength)
end

-- Read-only. Places a non-tear effect at the tear's current Height. Never write this back onto the tear.
local function tear_render_height(tear)
	return auxi.height2offset(tear.Height, tear.FallingAcceleration)
end

local function has_tear_flag(tear, flag)
	if not tear or not flag then return false end
	if tear.HasTearFlags then
		return tear:HasTearFlags(flag) == true
	end
	return tear.TearFlags and (tear.TearFlags & flag) == flag or false
end

local function should_ignore_field_tear(tear)
	if not tear then
		return true
	end
	local data = tear:GetData()
	if data.ignore_field then
		return true
	end
	-- Ludo is the player's continuously controlled floating shot.
	-- Capturing it would replace that attack, so Field never takes it.
	if TearFlags and TearFlags.TEAR_LUDOVICO and has_tear_flag(tear, TearFlags.TEAR_LUDOVICO) then
		return true
	end
	return false
end

local function push_entry_wave(tear, field, entry_render_y)
	if not field or not field.center or not tear then
		return
	end
	local radius = field.radius or item.FIELD_RADIUS
	local delta = tear.Position - field.center
	if delta:LengthSquared() < 0.01 then
		return
	end
	local radial = delta:Normalized()
	local entry_pos = field.center + radial * radius
	local lift = entry_render_y
	if lift == nil then
		lift = tear_render_height(tear)
	end
	entry_waves[#entry_waves + 1] = {
		pos = entry_pos,
		lift = lift,
		radial_x = radial.X,
		radial_y = radial.Y,
		age = 0,
	}
end

local function sync_room_field()
	local count = get_field_count()
	local key_id, seed = room_identity()
	if room_fields and room_fields.key == key_id and room_fields.count == count then
		room_fields.active = count > 0
		room_fields.spawn_seed = seed
		for _, field in ipairs(room_fields.fields or {}) do
			field.radius = item.FIELD_RADIUS
		end
		return
	end
	if count <= 0 then
		room_fields = nil
		entry_waves = {}
		capture_serial = 0
		return
	end
	local room = Game():GetRoom()
	capture_serial = 0
	entry_waves = {}
	room_fields = {
		key = key_id,
		active = true,
		spawn_seed = seed,
		count = count,
		fields = choose_field_centers(room, count, seed),
	}
end

local function point_inside_one_field(pos, field)
	if not pos or not field or not field.center then
		return false
	end
	local radius = field.radius or item.FIELD_RADIUS
	return pos:DistanceSquared(field.center) <= radius * radius
end

local function vdot(a, b)
	return a.X * b.X + a.Y * b.Y
end

-- Earliest t in [0,1] where segment p0→p1 hits the circle boundary.
local function segment_circle_entry_t(p0, p1, center, radius)
	local d = p1 - p0
	local f = p0 - center
	local a = vdot(d, d)
	if a < 1e-8 then
		return nil
	end
	local b = 2 * vdot(f, d)
	local c = vdot(f, f) - radius * radius
	local disc = b * b - 4 * a * c
	if disc < 0 then
		return nil
	end
	local s = math.sqrt(disc)
	local t1 = (-b - s) / (2 * a)
	local t2 = (-b + s) / (2 * a)
	local best = nil
	if t1 >= 0 and t1 <= 1 then
		best = t1
	end
	if t2 >= 0 and t2 <= 1 and (best == nil or t2 < best) then
		best = t2
	end
	return best
end

local function find_capture_field(previous_pos, current_pos)
	local fields = get_active_fields()
	if #fields == 0 or not current_pos then
		return nil, false
	end
	local crossed = {}
	local inside_now = {}
	for _, field in ipairs(fields) do
		if point_inside_one_field(current_pos, field) then
			inside_now[#inside_now + 1] = field
			local was_inside = previous_pos and point_inside_one_field(previous_pos, field) or false
			if previous_pos and not was_inside then
				local radius = field.radius or item.FIELD_RADIUS
				local t = segment_circle_entry_t(previous_pos, current_pos, field.center, radius)
				crossed[#crossed + 1] = {
					field = field,
					t = t or 1,
				}
			end
		end
	end
	if #crossed > 0 then
		table.sort(crossed, function(a, b)
			if math.abs(a.t - b.t) > 1e-6 then
				return a.t < b.t
			end
			return a.field.id < b.field.id
		end)
		return crossed[1].field, true
	end
	if #inside_now > 0 then
		table.sort(inside_now, function(a, b)
			local da = current_pos:DistanceSquared(a.center)
			local db = current_pos:DistanceSquared(b.center)
			if math.abs(da - db) > 1e-6 then
				return da < db
			end
			return a.id < b.id
		end)
		return inside_now[1], false
	end
	return nil, false
end

local function tear_life_alpha(cycles)
	if cycles < item.LIFE_GRACE_CYCLES then
		return 1
	end
	if cycles < item.LIFE_SOFT_END then
		local span = math.max(1, item.LIFE_SOFT_END - item.LIFE_GRACE_CYCLES)
		local t = (cycles - item.LIFE_GRACE_CYCLES) / span
		return 1 - 0.16 * t
	end
	if cycles < item.LIFE_HARD_END then
		local span = math.max(1, item.LIFE_HARD_END - item.LIFE_SOFT_END)
		local t = (cycles - item.LIFE_SOFT_END) / span
		if t < 0 then t = 0 end
		if t > 1 then t = 1 end
		return 0.84 * ((1 - t) ^ 1.7)
	end
	return 0
end

local function apply_tear_alpha(tear, data)
	local base = data[key("base_color")]
	if not base then return end
	local alpha = data[key("alpha")] or 1
	tear.Color = auxi.table2color({
		R = base.R, G = base.G, B = base.B, A = (base.A or 1) * alpha,
		RO = base.RO, GO = base.GO, BO = base.BO,
		RC = base.RC, GC = base.GC, BC = base.BC, AC = base.AC,
	})
end

local function make_capture_room()
	local limit = math.max(1, math.floor(item.CAPTURE_LIMIT))
	local active = {}
	local returning = 0
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_TEAR)) do
		local tear = ent.ToTear and ent:ToTear() or nil
		if tear then
			local d = tear:GetData()
			if d[key("state")] and not d[key("retire_on_exit")] then
				returning = returning + 1
				active[#active + 1] = {
					tear = tear,
					serial = d[key("capture_serial")] or 0,
				}
			end
		end
	end
	if returning < limit then
		return
	end
	table.sort(active, function(a, b)
		return a.serial < b.serial
	end)
	local oldest = active[1]
	if not oldest or not auxi.check_all_exists(oldest.tear) then
		return
	end
	local tear = oldest.tear
	local d = tear:GetData()
	if d[key("state")] == TEAR_STATE_WAIT then
		local hole = d[key("hole")]
		if auxi.check_all_exists(hole) then
			hole:Remove()
		end
		tear:Remove()
	else
		d[key("retire_on_exit")] = true
	end
end

local function enter_field(tear, field, show_entry_wave)
	local data = tear:GetData()
	local entry_render_y = auxi.height2offset(tear.Height, tear.FallingAcceleration)
	capture_serial = capture_serial + 1
	data[key("capture_serial")] = capture_serial
	data[key("state")] = TEAR_STATE_CAPTURE
	data[key("cycles")] = 0
	data[key("alpha")] = 1
	data[key("anchor")] = nil
	data[key("field_id")] = field and field.id or nil
	data[key("previous_position")] = nil
	if not data[key("base_color")] then
		data[key("base_color")] = auxi.color2table(tear.Color)
	end
	local owner = auxi.check_spawner_player(tear)
	local shot_speed = owner and owner.ShotSpeed or 1
	local rise_accel = -math.max(item.RISE_ACCEL_MIN, (shot_speed - item.RISE_SHOTSPEED_BIAS) * item.RISE_ACCEL_SCALE)
	data[key("vertical_accel")] = rise_accel
	auxi.transition_tear_falling_accel(tear, rise_accel, { sync_position_offset = true })
	apply_tear_alpha(tear, data)
	if show_entry_wave then
		push_entry_wave(tear, field, entry_render_y)
	end
end

local function finish_respawn(tear)
	if not tear or not tear:Exists() then return end
	local data = tear:GetData()
	if data[key("state")] ~= TEAR_STATE_WAIT then return end
	local cycles = (data[key("cycles")] or 0) + 1
	if cycles >= item.LIFE_HARD_END then
		tear:Remove()
		return
	end
	data[key("cycles")] = cycles
	data[key("alpha")] = tear_life_alpha(cycles)
	data[key("state")] = TEAR_STATE_RISE
	tear.Visible = true
	tear.Position = data[key("anchor")] or tear.Position
	tear.Velocity = Vector.Zero
	tear.Height = item.RISE_RESPAWN_HEIGHT
	tear.FallingSpeed = 0
	tear.FallingAcceleration = data[key("vertical_accel")] or -item.RISE_ACCEL_MIN
	apply_tear_alpha(tear, data)
	tear:SetColor(Color(1, 1, 1, 1, item.RESPAWN_COLOR_RO, item.RESPAWN_COLOR_GO, item.RESPAWN_COLOR_BO), item.RESPAWN_COLOR_FRAMES, item.RESPAWN_COLOR_PRIORITY, true, false)
end

local function choose_respawn_field(tear, next_cycle)
	local fields = get_active_fields()
	if #fields == 0 then
		return nil
	end
	if #fields == 1 then
		return fields[1]
	end
	local data = tear:GetData()
	local previous_id = data[key("field_id")]
	local candidates = {}
	for _, field in ipairs(fields) do
		if field.id ~= previous_id then
			candidates[#candidates + 1] = field
		end
	end
	if #candidates == 0 then
		candidates = fields
	end
	local seed = ((room_fields and room_fields.spawn_seed) or 1)
		+ (tear.InitSeed or 1) * 37
		+ (next_cycle or 0) * 7919
		+ 131
	if seed < 0 then seed = -seed end
	local rng = field_rng(seed)
	return candidates[rng:RandomInt(#candidates) + 1]
end

local function choose_respawn_anchor(tear, field, next_cycle)
	if not field or not field.center then
		return tear.Position
	end
	local room = Game():GetRoom()
	local radius = (field.radius or item.FIELD_RADIUS) * item.RESPAWN_RADIUS_MUL
	local seed = (field.seed or 1) + (tear.InitSeed or 1) * 37 + (next_cycle or 0) * 7919
	if seed < 0 then seed = -seed end
	local rng = field_rng(seed)
	local tries = math.max(1, math.floor(item.RESPAWN_POINT_TRIES))
	for _ = 1, tries do
		local angle = rng:RandomFloat() * 360
		local dist = math.sqrt(rng:RandomFloat()) * radius
		local pos = field.center + Vector(1, 0):Rotated(angle) * dist
		if room:IsPositionInRoom(pos, 12) then
			local collision = room:GetGridCollisionAtPos(pos)
			if collision ~= GridCollisionClass.COLLISION_WALL
				and collision ~= GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER
				and collision ~= GridCollisionClass.COLLISION_SOLID
			then
				return pos
			end
		end
	end
	return tear.Position
end

local function begin_respawn(tear, data)
	if data[key("retire_on_exit")] then
		tear:Remove()
		return
	end
	local next_cycle = (data[key("cycles")] or 0) + 1
	if next_cycle >= item.LIFE_HARD_END then
		tear:Remove()
		return
	end
	local target_field = choose_respawn_field(tear, next_cycle)
	if target_field then
		data[key("field_id")] = target_field.id
	end
	local anchor = choose_respawn_anchor(tear, target_field, next_cycle)
	data[key("anchor")] = anchor
	tear.Visible = false
	tear.Position = anchor
	tear.Velocity = Vector.Zero
	tear.Height = item.RISE_RESPAWN_HEIGHT
	tear.FallingSpeed = 0
	tear.FallingAcceleration = 0
	data[key("state")] = TEAR_STATE_WAIT
	data[key("hole")] = nil
	local alpha = data[key("alpha")] or 1
	local hole = Isaac.Spawn(EntityType.ENTITY_EFFECT, item.effect, 0, anchor, Vector.Zero, nil):ToEffect()
	if not hole then
		finish_respawn(tear)
		return
	end
	local hole_data = hole:GetData()
	hole_data[key("respawn_fx")] = true
	hole_data[key("tear")] = tear
	hole_data[key("alpha")] = alpha
	hole.Color = Color(1, 1, 1, math.max(0.25, alpha))
	hole:GetSprite():Play("Appear", true)
	data[key("hole")] = hole
end

local function update_capture(tear, data)
	local base_accel = data[key("vertical_accel")] or -item.RISE_ACCEL_MIN
	local fs = tonumber(tear.FallingSpeed) or 0
	local brake_frames = item.CAPTURE_VERTICAL_BRAKE_FRAMES
	if brake_frames < 1 then
		brake_frames = 1
	end
	if fs > 0 then
		tear.FallingAcceleration = math.min(base_accel, -fs / brake_frames)
	else
		tear.FallingAcceleration = base_accel
	end
	tear.Velocity = tear.Velocity * item.CAPTURE_DAMPING
	local stop = item.CAPTURE_STOP_SPEED
	if tear.Velocity:LengthSquared() <= stop * stop then
		tear.Velocity = Vector.Zero
		data[key("anchor")] = tear.Position
		data[key("state")] = TEAR_STATE_RISE
		tear.FallingAcceleration = base_accel
	end
end

local function tear_visual_offset_y(tear)
	return auxi.height2offset(tear.Height, tear.FallingAcceleration)
end

local function tear_screen_y(tear)
	local visual_y = tear_visual_offset_y(tear)
	return Isaac.WorldToScreen(tear.Position + Vector(0, visual_y)).Y
end

local function update_rise(tear, data)
	if not data[key("anchor")] then
		data[key("anchor")] = tear.Position
	end
	tear.Position = data[key("anchor")]
	tear.Velocity = Vector.Zero
	local accel = data[key("vertical_accel")] or -item.RISE_ACCEL_MIN
	if tear.FallingSpeed <= -item.RISE_SPEED_MAX then
		tear.FallingSpeed = -item.RISE_SPEED_MAX
		tear.FallingAcceleration = 0
	else
		tear.FallingAcceleration = accel
	end
	local reached_top = tear_screen_y(tear) <= item.RISE_SCREEN_TOP_Y
	local safety = tear.Height <= item.RISE_HEIGHT_SAFETY
	if reached_top or safety then
		begin_respawn(tear, data)
	end
end

local function update_wait(tear, data)
	local anchor = data[key("anchor")] or tear.Position
	tear.Visible = false
	tear.Position = anchor
	tear.Velocity = Vector.Zero
	tear.Height = item.RISE_RESPAWN_HEIGHT
	tear.FallingSpeed = 0
	tear.FallingAcceleration = 0
	local hole = data[key("hole")]
	if not auxi.check_all_exists(hole) then
		finish_respawn(tear)
		return
	end
end

local function ensure_boundary_sprite()
	if boundary_sprite then
		return boundary_sprite
	end
	local sprite = Sprite()
	sprite:Load("gfx/mimics/Field/field_particle.anm2", true)
	if not sprite:IsLoaded() then
		return nil
	end
	sprite:Play("Idle", true)
	boundary_sprite = sprite
	return boundary_sprite
end

local function ensure_entry_wave_sprite()
	if entry_wave_sprite then
		return entry_wave_sprite
	end
	local sprite = Sprite()
	sprite:Load("gfx/mimics/Field/field_entry_ripple.anm2", true)
	if not sprite:IsLoaded() then
		return nil
	end
	sprite:Play("Idle", true)
	sprite:SetFrame("Idle", 0)
	entry_wave_sprite = sprite
	return entry_wave_sprite
end

local function entry_wave_projection(radial_x, radial_y)
	local radial = Vector(radial_x or 0, radial_y or 0)
	if radial:LengthSquared() < 0.0001 then
		return 0, 1
	end
	radial = radial:Normalized()
	-- Isaac angle: right 0, down 90, left +/-180, up -90.
	-- Shift so up is 0, right +90, down +/-180, left -90.
	local yaw = radial:GetAngleDegrees() + 90
	yaw = ((yaw + 180) % 360) - 180
	-- A circle at yaw and yaw+180 looks the same. Fold into [-90, 90].
	if yaw > 90 then
		yaw = yaw - 180
	elseif yaw < -90 then
		yaw = yaw + 180
	end
	local projected = math.abs(math.cos(math.rad(yaw)))
	local squash = math.max(item.ENTRY_WAVE_EDGE_SCALE, projected)
	return yaw, squash
end

local function smoothstep01(t)
	if t < 0 then t = 0 end
	if t > 1 then t = 1 end
	return t * t * (3 - 2 * t)
end

local function entry_wave_scale(t)
	local p = smoothstep01(t)
	return item.ENTRY_WAVE_SCALE_START + (item.ENTRY_WAVE_SCALE_END - item.ENTRY_WAVE_SCALE_START) * p
end

local function entry_wave_alpha(t)
	if t <= 0 or t >= 1 then
		return 0
	end
	local fade_in = math.min(1, t / 0.10)
	local fade_out = (1 - t) ^ 1.25
	return item.ENTRY_WAVE_ALPHA * fade_in * fade_out
end

local function render_entry_waves()
	if Game():IsPaused() then
		return
	end
	local sprite = ensure_entry_wave_sprite()
	if not sprite then
		return
	end
	local duration = math.max(1, item.ENTRY_WAVE_FRAMES)
	for i = #entry_waves, 1, -1 do
		local wave = entry_waves[i]
		wave.age = (wave.age or 0) + 1
		local t = wave.age / duration
		if t >= 1 then
			table.remove(entry_waves, i)
		else
			local rotation, squash = entry_wave_projection(wave.radial_x, wave.radial_y)
			local base_scale = entry_wave_scale(t)
			local alpha = entry_wave_alpha(t)
			sprite.Rotation = rotation
			sprite.Scale = Vector(base_scale, base_scale * squash)
			local color = Color(0.82, 0.48, 1.00, alpha, item.ENTRY_WAVE_RO, item.ENTRY_WAVE_GO, item.ENTRY_WAVE_BO)
			if color.SetColorize then
				color:SetColorize(0.82, 0.42, 1.00, 0.72)
			end
			sprite.Color = color
			-- lift is a world-space height offset, not screen pixels.
			local render_pos = Isaac.WorldToScreen(wave.pos + Vector(0, wave.lift or 0))
			sprite:Render(render_pos, Vector.Zero, Vector.Zero)
		end
	end
end

local DEBUG_WAVE_ANGLES = { -90, -45, 0, 45, 90, 135, 180, -135 }
local DEBUG_WAVE_LABELS = { "U", "UR", "R", "DR", "D", "DL", "L", "UL" }

local function render_debug_entry_waves(field)
	if not item.debug_circle then
		return
	end
	if Game():IsPaused() then
		return
	end
	if not field or not field.center then
		return
	end
	local sprite = ensure_entry_wave_sprite()
	if not sprite then
		return
	end
	local radius = field.radius or item.FIELD_RADIUS
	local base_scale = item.ENTRY_WAVE_SCALE_END
	for i, angle in ipairs(DEBUG_WAVE_ANGLES) do
		local radial = Vector(1, 0):Rotated(angle)
		local rotation, squash = entry_wave_projection(radial.X, radial.Y)
		sprite.Rotation = rotation
		sprite.Scale = Vector(base_scale, base_scale * squash)
		local color = Color(0.82, 0.48, 1.00, 0.9, item.ENTRY_WAVE_RO, item.ENTRY_WAVE_GO, item.ENTRY_WAVE_BO)
		if color.SetColorize then
			color:SetColorize(0.82, 0.42, 1.00, 0.72)
		end
		sprite.Color = color
		local screen = Isaac.WorldToScreen(field.center + radial * radius)
		sprite:Render(screen, Vector.Zero, Vector.Zero)
		Isaac.RenderText(DEBUG_WAVE_LABELS[i], screen.X + 8, screen.Y - 8, 1, 1, 1, 0.95)
	end
end

local function hash01(seed, index, salt)
	local x = math.sin((seed or 1) * 0.013 + index * 12.9898 + salt * 78.233) * 43758.5453
	return x - math.floor(x)
end

local function render_particle(sprite, world_pos, rise, alpha, scale_mul, absolute_scale, color)
	-- rise is world-space height, not screen pixels.
	local screen = Isaac.WorldToScreen(world_pos + Vector(0, -rise))
	scale_mul = scale_mul or 1
	local normalized_alpha = 0
	if item.BOUNDARY_ALPHA > 0 then
		normalized_alpha = math.min(1, alpha / item.BOUNDARY_ALPHA)
	end
	local scale = absolute_scale or ((0.42 + normalized_alpha * 0.16) * scale_mul)
	sprite.Scale = Vector(scale, scale)
	sprite.Color = color or field_color(alpha, 1)
	sprite:Render(screen, Vector.Zero, Vector.Zero)
end

local function render_one_field_visual(field)
	if not field or not field.center then
		return
	end
	local sprite = ensure_boundary_sprite()
	if not sprite then
		return
	end
	local radius = field.radius or item.FIELD_RADIUS
	-- Pure render animation clock.
	-- Isaac.GetFrameCount() follows rendered frames in this project.
	-- Game():GetFrameCount() is the logic-frame counter.
	local render_frame = Isaac.GetFrameCount()
	local seed = field.seed or 1
	local count = math.max(1, math.floor(item.BOUNDARY_PARTICLES + 0.5))
	local seed_wave = seed % 97
	for i = 1, count do
		local base = (i - 1) / count
		local angle = base * 360 + math.sin(render_frame * 0.02 + i * 1.7 + seed_wave) * 3
		local radial = radius + math.sin(render_frame * 0.015 + i * 2.31) * 3
		local dir = Vector(1, 0):Rotated(angle)
		local life = (render_frame * item.BOUNDARY_DRIFT + base) % 1
		local alpha = math.sin(life * math.pi) * item.BOUNDARY_ALPHA
		render_particle(sprite, field.center + dir * radial, life * item.BOUNDARY_RISE, alpha)
	end
	local inner_count = math.max(0, math.floor(item.INNER_PARTICLES + 0.5))
	local rise_min = item.INNER_RISE_MIN
	local rise_max = item.INNER_RISE_MAX
	if rise_max < rise_min then
		rise_max = rise_min
	end
	for i = 1, inner_count do
		local dist = math.sqrt(hash01(seed, i, 1)) * radius * 0.82
		local anchor = field.center + Vector(1, 0):Rotated(hash01(seed, i, 2) * 360) * dist
		local rise_dist = rise_min + (rise_max - rise_min) * hash01(seed, i, 4)
		local rise_speed = item.INNER_SPEED_MIN + (item.INNER_SPEED_MAX - item.INNER_SPEED_MIN) * hash01(seed, i, 8)
		local phase = (hash01(seed, i, 3) + render_frame * rise_speed / math.max(1, rise_dist)) % 1
		local hue = hash01(seed, i, 7)
		local sway = math.sin(render_frame * 0.035 + i * 2.17) * item.INNER_DRIFT
		local world_pos = anchor + Vector(1, 0):Rotated(hash01(seed, i, 6) * 360) * sway
		local fade_in = math.min(1, phase / 0.12)
		local fade_out = math.min(1, (1 - phase) / 0.20)
		local alpha = math.min(fade_in, fade_out) * item.INNER_ALPHA
		local scale = item.INNER_SCALE_MIN + (item.INNER_SCALE_MAX - item.INNER_SCALE_MIN) * hash01(seed, i, 5)
		local color = Color(0.68 + hue * 0.16, 0.26 + hue * 0.16, 0.88 + hue * 0.10, alpha, 0.16, 0.02, 0.24)
		render_particle(sprite, world_pos, phase * rise_dist, alpha, nil, scale, color)
	end
	if item.debug_circle then
		for i = 1, 48 do
			local dir = Vector(1, 0):Rotated((i - 1) / 48 * 360)
			render_particle(sprite, field.center + dir * radius, 0, 0.55, 0.75)
		end
		local center_screen = Isaac.WorldToScreen(field.center)
		Isaac.RenderText("+", center_screen.X - 3, center_screen.Y - 6, 0.8, 0.85, 1, 0.7)
		render_debug_entry_waves(field)
	end
end

local function render_field_visual()
	if Game():IsPaused() then return end
	if not room_fields_active() then return end
	for _, field in ipairs(room_fields.fields) do
		render_one_field_visual(field)
	end
	if not item.debug_labels then return end
	for _, tear in ipairs(Isaac.FindByType(EntityType.ENTITY_TEAR)) do
		local state = tear:GetData()[key("state")]
		if state then
			local screen = Isaac.WorldToScreen(tear.Position)
			Isaac.RenderText("C" .. tostring(tear:GetData()[key("cycles")] or 0), screen.X, screen.Y - 18, 1, 1, 1, 0.9)
		end
	end
end

function item.restore_debug_defaults()
	for name, value in pairs(DEFAULTS) do
		item[name] = value
	end
	item.debug_circle = false
	item.debug_labels = false
end

function item.field_status_text()
	if Isaac.IsInGame and not Isaac.IsInGame() then
		return "no field"
	end
	local captured = 0
	for _, tear in ipairs(Isaac.FindByType(EntityType.ENTITY_TEAR)) do
		if tear:GetData()[key("state")] then
			captured = captured + 1
		end
	end
	if not room_fields_active() then
		return "no field | tears " .. tostring(captured)
	end
	local n = #room_fields.fields
	local first = room_fields.fields[1]
	return string.format(
		"on x%d  %.0f, %.0f | tears %d",
		n,
		first.center.X,
		first.center.Y,
		captured
	)
end

local function player_inside_any_field(player)
	if not player then
		return false
	end
	if not auxi.has_have_coll(player, item.entity) then
		return false
	end
	return item.entity_inside_any_field(player)
end

--- Spatial-only: is this entity currently inside any active room Field?
--- Does not check inventory; callers gate by player hold / craft counts.
function item.entity_inside_any_field(ent)
	if not ent or not ent.Position then
		return false
	end
	if not room_fields_active() then
		return false
	end
	for _, field in ipairs(room_fields.fields) do
		if point_inside_one_field(ent.Position, field) then
			return true
		end
	end
	return false
end

local function refresh_player_field_buff(player)
	if not player then
		return
	end
	local data = player:GetData()
	local inside = player_inside_any_field(player)
	local old = data[key("inside_buff")] and true or false
	if inside == old then
		return
	end
	if inside then
		data[key("inside_buff")] = true
	else
		data[key("inside_buff")] = nil
	end
	player:AddCacheFlags(CacheFlag.CACHE_FIREDELAY)
	player:EvaluateItems()
end

local function refresh_all_player_field_buffs()
	for i = 0, Game():GetNumPlayers() - 1 do
		refresh_player_field_buff(Isaac.GetPlayer(i))
	end
end

table.insert(item.ToCall, #item.ToCall + 1, { CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_, player, cacheFlag)
	if cacheFlag ~= CacheFlag.CACHE_FIREDELAY then return end
	if not auxi.has_have_coll(player, item.entity) then return end
	if not player:GetData()[key("inside_buff")] then return end
	player.MaxFireDelay = auxi.TearsUp(player.MaxFireDelay, auxi.get_mxdelay_multiplier(player) * item.FIELD_TEARS_BONUS)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, { CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function()
	sync_room_field()
	refresh_all_player_field_buffs()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, { CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function()
	sync_room_field()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, { CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_, player)
	refresh_player_field_buff(player)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, { CallBack = ModCallbacks.MC_POST_TEAR_INIT, params = nil,
Function = function(_, tear)
	if not tear then return end
	local data = tear:GetData()
	if data[key("previous_position")] == nil then
		data[key("previous_position")] = Vector(tear.Position.X, tear.Position.Y)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, { CallBack = ModCallbacks.MC_POST_TEAR_UPDATE, params = nil,
Function = function(_, tear)
	if should_ignore_field_tear(tear) then return end
	local data = tear:GetData()
	local state = data[key("state")]
	if state == nil then
		local previous = data[key("previous_position")]
		local field, crossed = find_capture_field(previous, tear.Position)
		if field then
			local owner = auxi.check_spawner_player(tear)
			if owner and auxi.has_have_coll(owner, item.entity) then
				make_capture_room()
				enter_field(tear, field, crossed)
				return
			end
		end
		data[key("previous_position")] = Vector(tear.Position.X, tear.Position.Y)
		return
	end
	if state == TEAR_STATE_CAPTURE then
		update_capture(tear, data)
	elseif state == TEAR_STATE_RISE then
		update_rise(tear, data)
	elseif state == TEAR_STATE_WAIT then
		update_wait(tear, data)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, { CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE, params = item.effect,
Function = function(_, ent)
	local data = ent:GetData()
	if not data[key("respawn_fx")] then
		return
	end
	local tear = data[key("tear")]
	if not auxi.check_all_exists(tear) then
		ent:Remove()
		return
	end
	local sprite = ent:GetSprite()
	if sprite:IsFinished("Appear") then
		finish_respawn(tear)
		if auxi.check_all_exists(tear) and tear:GetData()[key("state")] == TEAR_STATE_RISE then
			sprite:Play("Spawn", true)
		else
			ent:Remove()
		end
		return
	end
	if sprite:IsFinished("Spawn") then
		ent:Remove()
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, { CallBack = ModCallbacks.MC_POST_RENDER, params = nil,
Function = function()
	render_field_visual()
	render_entry_waves()
end,
})

return item
