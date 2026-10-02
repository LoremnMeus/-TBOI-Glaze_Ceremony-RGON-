-- Blood Wing: wall-charge → launch burst → steerable V-sweep wings + rear Brimstone; bounce snap.
-- Timers on MC_POST_PLAYER_UPDATE (60 Hz) unless noted.
-- wall_normal = from wall into the room (never invert again for launch).
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local Charging_Bar_holder = require("Qing_Remaster_scripts.others.Charging_Bar_holder")
local player_offset_holder = require("Qing_Remaster_scripts.callbacks.player_offset_holder")
local Attribute_holder = require("Qing_Remaster_scripts.others.Attribute_holder")
local attack_holder = require("Qing_Remaster_scripts.callbacks.attack_trigger_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Blood_Wing,
	own_key = "Item_Blood_Wing_",
	charge_max = 120,
	charge_decay = 4,
	ready_grace_max = 18,
	launch_frames = 11,
	dash_total = 135,
	recovery_frames = 18,
	bounce_time_penalty = 6,
	bounce_speed_mul = 0.90,
	bounce_compress_frames = 3,
	bounce_reignite_frames = 5,
	bounce_steer_frames = 6,
	bounce_damage_boost = 1.25,
	bounce_damage_boost_frames = 8,
	wall_stick_frames = 4,
	max_speed = 15,
	launch_start_speed = 8,
	launch_peak_speed = 17,
	brim_mul = 0.30,
	turn_early = 2.4,
	turn_mid = 3.4,
	turn_late = 4.5,
	ready_pulse_period = 18,
	layer_appear_frames = 8,
	wing_damage_inner = 0.50,
	wing_damage_mid = 0.65,
	wing_damage_outer = 0.80,
	wing_hit_cooldown = 8,
	wing_capsule_radius = 12,
	wing_sound_cooldown = 4,
	-- Parallel lasers: small fan is visual-only via sprite angle; fire stays near -dash_dir.
	use_fire_fan = false,
	wing_layout = {
		{lateral = 12, backward = 5, scale = 1.15, angle = 5, follow = 1.00, fire_angle = 2},
		{lateral = 22, backward = 10, scale = 1.05, angle = 9, follow = 0.85, fire_angle = 4},
		{lateral = 34, backward = 17, scale = 0.95, angle = 13, follow = 0.70, fire_angle = 6},
		{lateral = 48, backward = 26, scale = 0.85, angle = 17, follow = 0.55, fire_angle = 8},
		{lateral = 64, backward = 38, scale = 0.75, angle = 21, follow = 0.40, fire_angle = 10},
	},
}

local STATE_KEY = item.own_key.."state"
local COUNTER_KEY = item.own_key.."counter"
local EFFECT_KEY = item.own_key.."effect"
local SPRITE_KEY = item.own_key.."sprite"
local SPRITE_FRAME_KEY = item.own_key.."sprite_update_frame"
local UPDATE_KEY = item.own_key.."Update"
local BLINK_KEY = item.own_key.."ENTITY_FLAG_NO_DAMAGE_BLINK"

local PHASE_IDLE = "idle"
local PHASE_CHARGING = "charging"
local PHASE_READY = "ready"
local PHASE_LAUNCH = "launch"
local PHASE_DASH = "dash"
local PHASE_BOUNCE = "bounce"
local PHASE_RECOVERY = "recovery"

-- Recovery close windows (progress 0–1): outer → inner.
local RECOVERY_LAYER = {
	{0.00, 0.20},
	{0.10, 0.35},
	{0.25, 0.55},
	{0.45, 0.75},
	{0.70, 1.00},
}

local function empty_state()
	return {
		phase = PHASE_IDLE,
		timer = 0,
		dash_dir = nil,
		wall_normal = nil,
		speed = 0,
		ready_grace = 0,
		wall_contact = 0,
		off_wall_frames = 0,
		bounce_immune = 0,
		flight_left = 0,
		bounce_t = 0,
		bank = 0,
		prev_dash_angle = nil,
		spread = 1,
		visual_angle = {},
		layer_blend = {0, 0, 0, 0, 0},
		prev_wing_pose = nil,
		wing_hit_cd = {},
		wing_sound_cd = 0,
		bounce_boost_left = 0,
		bounce_steer_left = 0,
	}
end

local function get_state(d)
	local st = d[STATE_KEY]
	if type(st) ~= "table" then
		st = empty_state()
		d[STATE_KEY] = st
	end
	st.visual_angle = st.visual_angle or {}
	st.layer_blend = st.layer_blend or {0, 0, 0, 0, 0}
	st.wing_hit_cd = st.wing_hit_cd or {}
	return st
end

local function clamp(x, a, b)
	if x < a then return a end
	if x > b then return b end
	return x
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function shortest_angle_delta(a, b)
	return ((b - a + 180) % 360) - 180
end

local function approach_angle(cur, want, follow)
	follow = clamp(follow or 1, 0.05, 1)
	local d = shortest_angle_delta(cur, want)
	return cur + d * follow
end

function item.real_collideswithgrid(player)
	if player:CollidesWithGrid() then return true end
	local mov = player:GetMovementInput()
	for _, v in pairs(auxi.splitvector(mov)) do
		local pos = player.Position + v * (player.Size + 1)
		local room = Game():GetRoom()
		if room:GetGridCollisionAtPos(pos) == GridCollisionClass.COLLISION_WALL then
			return true
		end
	end
	return false
end

-- Returns unit vector from wall into the room (away from contacted wall cells).
local function probe_wall_normal(player)
	local room = Game():GetRoom()
	local pos = player.Position
	local normal = Vector(0, 0)
	local dirs = {
		Vector(-1, 0), Vector(1, 0), Vector(0, -1), Vector(0, 1),
		Vector(-0.707, -0.707), Vector(0.707, -0.707),
		Vector(-0.707, 0.707), Vector(0.707, 0.707),
	}
	for i = 1, #dirs do
		local dir = dirs[i]
		local p = pos + dir * (player.Size + 2)
		if room:GetGridCollisionAtPos(p) == GridCollisionClass.COLLISION_WALL then
			normal = normal - dir
		end
	end
	if normal:Length() > 0.05 then
		return normal:Normalized()
	end
	return nil
end

local function reflect_dir(dir, normal)
	if not dir or not normal then return dir end
	local d = dir:Normalized()
	local n = normal:Normalized()
	local reflected = d - n * (2 * (d.X * n.X + d.Y * n.Y))
	if reflected:Length() < 0.05 then
		return -d
	end
	return reflected:Normalized()
end

local function refresh_wall_normal(player, st)
	local n = probe_wall_normal(player)
	if n then
		st.wall_normal = n
	end
	return st.wall_normal
end

-- Launch direction: stored wall_normal (into room). Never prefer wall-hug move input.
local function resolve_launch_dir(player, st)
	if st.wall_normal and st.wall_normal:Length() > 0.05 then
		return st.wall_normal:Normalized()
	end
	local n = probe_wall_normal(player)
	if n then
		return n
	end
	local mov = auxi.getmov(player)
	if mov and mov:Length() > 0.1 then
		-- Only as fallback: prefer component away from last known wall if any.
		return mov:Normalized()
	end
	if st.dash_dir and st.dash_dir:Length() > 0.05 then
		return st.dash_dir:Normalized()
	end
	local aim = auxi.getdir(player)
	if aim and aim:Length() > 0.05 then
		return aim:Normalized()
	end
	return Vector(1, 0)
end

local function turn_cap_for_progress(progress)
	if progress < 0.3 then
		return item.turn_early
	elseif progress < 0.7 then
		return item.turn_mid
	end
	return item.turn_late
end

local function steer_dash_dir(dash_dir, input_dir, progress)
	if not input_dir or input_dir:Length() < 0.05 then
		return dash_dir
	end
	local cur = dash_dir:GetAngleDegrees()
	local want = input_dir:GetAngleDegrees()
	local delta = auxi.checkrounded2(want, cur, 1, -1, 360)
	local abs_delta = math.abs(delta)
	local mul = 1
	if abs_delta > 135 then
		mul = 0.55
	elseif abs_delta > 90 then
		mul = 0.75
	end
	local cap = turn_cap_for_progress(progress) * mul
	local next_ang = auxi.move_in_round(cur, want, cap, 360)
	return auxi.MakeVector(next_ang)
end

local function update_bank(st, dash_dir)
	local ang = dash_dir:GetAngleDegrees()
	local prev = st.prev_dash_angle
	if prev == nil then
		st.prev_dash_angle = ang
		st.bank = 0
		return
	end
	local delta = shortest_angle_delta(prev, ang)
	local max_rate = item.turn_late
	st.bank = clamp(delta / math.max(0.01, max_rate), -1, 1)
	st.prev_dash_angle = ang
end

local function launch_speed_at(t)
	-- Frame 0→4: 8→17; 4→11: 17→15 (timer is 1-based after increment).
	local f = t
	if f <= 4 then
		return lerp(item.launch_start_speed, item.launch_peak_speed, f / 4)
	end
	local u = clamp((f - 4) / math.max(1, item.launch_frames - 4), 0, 1)
	return lerp(item.launch_peak_speed, item.max_speed, u)
end

local function launch_spread_at(t)
	-- READY compress 0.88 → overshoot 1.12 → cruise 1.0 over launch_frames.
	local u = clamp(t / math.max(1, item.launch_frames), 0, 1)
	if u < 0.45 then
		return lerp(0.88, 1.12, u / 0.45)
	end
	return lerp(1.12, 1.0, (u - 0.45) / 0.55)
end

local function bounce_spread_at(t)
	local c = item.bounce_compress_frames
	local r = item.bounce_reignite_frames
	if t <= c then
		return lerp(1.0, 0.55, t / math.max(1, c))
	end
	local u = clamp((t - c) / math.max(1, r), 0, 1)
	if u < 0.55 then
		return lerp(0.55, 1.12, u / 0.55)
	end
	return lerp(1.12, 1.0, (u - 0.55) / 0.45)
end

local function ignition_layers(st)
	local phase = st.phase
	if phase == PHASE_LAUNCH then
		local t = st.timer or 0
		if t <= 3 then return 1 end
		if t <= 6 then return 3 end
		return 5
	end
	if phase == PHASE_BOUNCE then
		local t = st.bounce_t or 0
		local c = item.bounce_compress_frames
		if t <= c then return 5 end
		local u = t - c
		if u <= 2 then return 1 end
		if u <= 4 then return 3 end
		return 5
	end
	if phase == PHASE_DASH then
		return 5
	end
	if phase == PHASE_RECOVERY then
		return 5
	end
	-- Charging / ready: by charge bar.
	return 5
end

local function layer_visibility(st, charge, layer)
	local phase = st.phase
	local ign = ignition_layers(st)
	if phase == PHASE_LAUNCH or phase == PHASE_DASH or phase == PHASE_BOUNCE then
		return layer <= ign and 1 or 0
	end
	if phase == PHASE_RECOVERY then
		local t = (st.timer or 0) / math.max(1, item.recovery_frames)
		local win = RECOVERY_LAYER[layer]
		local a, b = win[1], win[2]
		if t <= a then return 1 end
		if t >= b then return 0 end
		return 1 - (t - a) / math.max(0.001, b - a)
	end
	local ratio = clamp((charge or 0) / item.charge_max, 0, 1)
	local start = (layer - 1) / 5
	local finish = layer / 5
	if ratio <= start then return 0 end
	if ratio >= finish then return 1 end
	return (ratio - start) / math.max(0.001, finish - start)
end

local function clear_lasers(d)
	local effect = d[EFFECT_KEY]
	if type(effect) ~= "table" then return end
	for i = 1, 5 do
		local slot = effect[i]
		if type(slot) == "table" then
			for j = 1, 2 do
				local q = slot["laser"..tostring(j)]
				if auxi.check_all_exists(q) then
					q.Color = Color(1, 1, 1, 0)
					q:SetTimeout(2)
				end
				slot["laser"..tostring(j)] = nil
			end
		end
	end
end

local function end_invuln(player, d)
	if d[BLINK_KEY] then
		Attribute_holder.try_rewind_attribute(
			player,
			"ENTITY_FLAG_NO_DAMAGE_BLINK",
			d[BLINK_KEY],
			Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_DAMAGE_BLINK)
		)
		d[BLINK_KEY] = nil
	end
end

local function ensure_invuln(player, d)
	player:SetMinDamageCooldown(math.max(0, 3 - player:GetDamageCooldown()))
	if d[BLINK_KEY] == nil then
		d[BLINK_KEY] = Attribute_holder.try_hold_attribute(
			player,
			"ENTITY_FLAG_NO_DAMAGE_BLINK",
			true,
			Attribute_holder.descriptors.entity_flag(EntityFlag.FLAG_NO_DAMAGE_BLINK)
		)
	end
end

local function begin_launch(player, d, st)
	local dir = resolve_launch_dir(player, st)
	st.phase = PHASE_LAUNCH
	st.timer = 0
	st.dash_dir = dir
	st.speed = item.launch_start_speed
	st.flight_left = item.dash_total
	st.wall_contact = 0
	st.off_wall_frames = 0
	st.bounce_t = 0
	st.bounce_immune = item.launch_frames + 6
	st.ready_grace = 0
	st.bank = 0
	st.prev_dash_angle = dir:GetAngleDegrees()
	st.spread = 0.88
	st.visual_angle = {}
	st.prev_wing_pose = nil
	st.wing_hit_cd = {}
	st.bounce_boost_left = 0
	st.bounce_steer_left = 0
	d[COUNTER_KEY] = 0
	d[EFFECT_KEY] = d[EFFECT_KEY] or {}
	d[EFFECT_KEY].dir = dir:GetAngleDegrees()
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_FETUS_JUMP, 0.9, 1.05, false, 0, 2)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_STONE_IMPACT, 0.35, 0.85, false, 0, 2)
end

local function begin_bounce(player, d, st)
	local normal = probe_wall_normal(player)
	-- Prefer inward room normal for reflection; fall back to opposite of travel.
	local n = normal or st.wall_normal or -(st.dash_dir or Vector(1, 0))
	local reflected = reflect_dir(st.dash_dir or Vector(1, 0), n)
	local mov = auxi.getmov(player)
	if mov and mov:Length() > 0.1 then
		st.dash_dir = (reflected * 0.7 + mov:Normalized() * 0.3):Normalized()
	else
		st.dash_dir = reflected
	end
	st.wall_normal = n
	st.speed = item.max_speed * item.bounce_speed_mul
	st.flight_left = math.max(0, (st.flight_left or 0) - item.bounce_time_penalty)
	st.wall_contact = 0
	st.bounce_t = 0
	st.bounce_immune = item.bounce_compress_frames + 2
	st.bounce_boost_left = item.bounce_damage_boost_frames
	st.bounce_steer_left = item.bounce_steer_frames
	st.phase = PHASE_BOUNCE
	st.prev_dash_angle = st.dash_dir:GetAngleDegrees()
	d[EFFECT_KEY] = d[EFFECT_KEY] or {}
	d[EFFECT_KEY].dir = st.dash_dir:GetAngleDegrees()
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_STONE_IMPACT, 0.7, 1.1, false, 0, 2)
	if st.flight_left <= 0 then
		st.phase = PHASE_RECOVERY
		st.timer = 0
		clear_lasers(d)
		end_invuln(player, d)
	end
end

local function begin_recovery(player, d, st)
	st.phase = PHASE_RECOVERY
	st.timer = 0
	clear_lasers(d)
	end_invuln(player, d)
end

local function maintain_brimstone(player, d, st, pose, geom)
	local dir = st.dash_dir
	if not dir or dir:Length() < 0.05 then return end
	d[EFFECT_KEY] = d[EFFECT_KEY] or {}
	d[EFFECT_KEY].dir = dir:GetAngleDegrees()
	local effect = d[EFFECT_KEY]
	local succ = nil
	local base_ang = dir:GetAngleDegrees() + 180
	local ign = pose and pose.ignition or 5
	for i = 1, 5 do
		effect[i] = effect[i] or {}
		local vis = pose and pose.layer_vis and pose.layer_vis[i] or 1
		local lit = i <= ign and vis > 0.15
		if lit then
			local layout = item.wing_layout[i]
			for j = 1, 2 do
				local side = (j == 1) and 1 or -1
				if auxi.check_all_exists(effect[i]["laser"..tostring(j)]) ~= true then
					local q = attack_holder.FireBrimstone(player, -dir, {
						mode = "untracked",
						damage_multiplier = item.brim_mul,
					})
					q.Parent = nil
					q.PositionOffset = Vector(0, 0)
					effect[i]["laser"..tostring(j)] = q
					q:SetTimeout(120)
					if Game():GetRoom():GetFrameCount() == 0 then succ = true end
				end
				local q = effect[i]["laser"..tostring(j)]
				local anchor = geom and geom.layer and geom.layer[i] and geom.layer[i][j]
				if not anchor then
					anchor = effect[i]["pos"..tostring(j)]
				end
				if anchor then
					q.Position = anchor
					effect[i]["pos"..tostring(j)] = anchor
				end
				local fan = 0
				if item.use_fire_fan and layout then
					fan = (layout.fire_angle or 0) * side
				end
				q.Angle = base_ang + fan
				local alpha = clamp(vis, 0.15, 1)
				q.Color = Color(1, 1, 1, alpha, 0, 0, 0)
			end
		else
			for j = 1, 2 do
				local q = effect[i]["laser"..tostring(j)]
				if auxi.check_all_exists(q) then
					q.Color = Color(1, 1, 1, 0)
					q:SetTimeout(2)
					effect[i]["laser"..tostring(j)] = nil
				end
			end
		end
	end
	if succ then
		delay_buffer.addeffe(function()
			SFXManager():Stop(7)
		end, {}, 1)
	end
end

local function refresh_layer_blends(st, charge)
	for i = 1, 5 do
		local target = layer_visibility(st, charge, i)
		local cur = st.layer_blend[i] or 0
		local rate = 1 / math.max(1, item.layer_appear_frames)
		if target > cur then
			cur = math.min(target, cur + rate)
		elseif target < cur then
			cur = math.max(target, cur - rate)
		else
			cur = target
		end
		st.layer_blend[i] = cur
	end
end

local function compute_wing_pose(st, charge)
	local phase = st.phase
	local pose = {
		spread = 1,
		bank = st.bank or 0,
		ignition = ignition_layers(st),
		layer_vis = {},
		pulse = 1,
		facing = st.dash_dir,
	}
	for i = 1, 5 do
		pose.layer_vis[i] = st.layer_blend[i] or layer_visibility(st, charge, i)
	end

	if phase == PHASE_CHARGING or phase == PHASE_IDLE then
		local ratio = clamp((charge or 0) / item.charge_max, 0, 1)
		pose.spread = lerp(0.55, 1.0, ratio)
		if st.wall_normal then
			pose.facing = st.wall_normal
		end
	elseif phase == PHASE_READY then
		local pulse_t = (Game():GetFrameCount() % item.ready_pulse_period) / item.ready_pulse_period
		pose.pulse = lerp(0.96, 1.04, 0.5 - 0.5 * math.cos(pulse_t * math.pi * 2))
		pose.spread = 0.88 * pose.pulse
		if st.wall_normal then
			pose.facing = st.wall_normal
		end
	elseif phase == PHASE_LAUNCH then
		pose.spread = launch_spread_at(st.timer or 0)
	elseif phase == PHASE_BOUNCE then
		pose.spread = bounce_spread_at(st.bounce_t or 0)
	elseif phase == PHASE_DASH then
		pose.spread = 1.0
	elseif phase == PHASE_RECOVERY then
		pose.spread = 1.0
	end

	st.spread = pose.spread
	return pose
end

--- Gameplay + render share this: world anchors for wing layers (does not depend on Render).
local function resolve_facing(player, st, pose, d)
	local facing = pose and pose.facing
	if not facing or facing:Length() < 0.05 then
		facing = st.dash_dir
	end
	if not facing or facing:Length() < 0.05 then
		facing = auxi.getdir(player)
		if facing:Length() < 0.05 then facing = auxi.getmov(player) end
		if d and facing:Length() < 0.05 then
			facing = auxi.MakeVector((d[EFFECT_KEY] or {}).dir or 0)
		end
	end
	if facing:Length() < 0.05 then
		facing = Vector(1, 0)
	end
	return facing:Normalized()
end

local function layer_world_offset(player, facing, pose, layout, side_sign, bank)
	local forward = facing
	local side = Vector(-forward.Y, forward.X)
	local back = Vector(-forward.X, -forward.Y)
	local abs_bank = math.abs(bank or 0)
	local spread = (pose and pose.spread) or 1
	local is_left = side_sign > 0
	local is_inner = (bank < -0.05 and is_left) or (bank > 0.05 and not is_left)
	local lat_mul = 1
	local b_extra = 1
	if abs_bank > 0.01 then
		if is_inner then
			lat_mul = 1 - 0.15 * abs_bank
			b_extra = 1 - 0.12 * abs_bank
		else
			lat_mul = 1 + 0.10 * abs_bank
			b_extra = 1 + 0.12 * abs_bank
		end
	end
	local back_mul = 1
	if pose and (pose._phase_ready or false) then
		back_mul = 0.8
	end
	local lateral = layout.lateral * spread * lat_mul * player.SpriteScale.X
	local backward = layout.backward * spread * back_mul * b_extra * player.SpriteScale.Y
	return side * (lateral * side_sign) + back * backward
end

--- Capsule anchors: inner=layer1, middle=layer3, outer=layer5.
local function compute_wing_world_pose(player, st, pose)
	local d = player:GetData()
	local facing = resolve_facing(player, st, pose, d)
	local bank = (pose and pose.bank) or (st.bank or 0)
	local root = player.Position
	local out = {
		facing = facing,
		root = root,
		left = {},
		right = {},
		layer = {}, -- [i][1|2] = world Vector
	}
	if pose then
		pose._phase_ready = st.phase == PHASE_READY
	end
	for i = 1, 5 do
		local layout = item.wing_layout[i]
		out.layer[i] = {}
		for j = 1, 2 do
			local sign = (j == 1) and 1 or -1
			local off = layer_world_offset(player, facing, pose, layout, sign, bank)
			out.layer[i][j] = root + off
		end
	end
	-- j=1 left(+), j=2 right(-) matching render
	out.left.inner = out.layer[1][1]
	out.left.middle = out.layer[3][1]
	out.left.outer = out.layer[5][1]
	out.right.inner = out.layer[1][2]
	out.right.middle = out.layer[3][2]
	out.right.outer = out.layer[5][2]
	return out
end

local function dist_point_segment_sq(p, a, b)
	local ab = b - a
	local len2 = ab:LengthSquared()
	if len2 < 0.0001 then
		return (p - a):LengthSquared()
	end
	local t = clamp(((p.X - a.X) * ab.X + (p.Y - a.Y) * ab.Y) / len2, 0, 1)
	local proj = a + ab * t
	return (p - proj):LengthSquared()
end

local function capsule_hits(pos, a, b, radius)
	return dist_point_segment_sq(pos, a, b) <= radius * radius
end

local function apply_wing_sweep_damage(player, st, geom)
	if not geom then return end
	local frame = Game():GetFrameCount()
	local enemies = auxi.getenemies(Isaac.GetRoomEntities())
	local radius = item.wing_capsule_radius
	local boost = 1
	if (st.bounce_boost_left or 0) > 0 then
		boost = item.bounce_damage_boost
	end
	local sides = {
		{ key = "left", chain = {"inner", "middle", "outer"}, mul = {item.wing_damage_inner, item.wing_damage_mid, item.wing_damage_outer} },
		{ key = "right", chain = {"inner", "middle", "outer"}, mul = {item.wing_damage_inner, item.wing_damage_mid, item.wing_damage_outer} },
	}
	local prev = st.prev_wing_pose
	for _, side in ipairs(sides) do
		local cur_side = geom[side.key]
		local prev_side = prev and prev[side.key]
		local pts = { geom.root, cur_side.inner, cur_side.middle, cur_side.outer }
		local muls = { side.mul[1], side.mul[2], side.mul[3] }
		-- segments root→inner, inner→middle, middle→outer
		for seg = 1, 3 do
			local a, b = pts[seg], pts[seg + 1]
			local dmg_mul = muls[seg] * boost
			local pa, pb = a, b
			if prev_side then
				local prev_pts = { prev.root or geom.root, prev_side.inner, prev_side.middle, prev_side.outer }
				pa, pb = prev_pts[seg], prev_pts[seg + 1]
			end
			for _, enemy in ipairs(enemies) do
				if auxi.check_all_exists(enemy) and not enemy:IsDead() then
					local hit = capsule_hits(enemy.Position, a, b, radius)
					if not hit and prev_side then
						hit = capsule_hits(enemy.Position, pa, pb, radius)
							or capsule_hits(enemy.Position, pb, b, radius)
					end
					if hit then
						local hash = GetPtrHash(enemy)
						local until_frame = st.wing_hit_cd[hash] or 0
						if frame >= until_frame then
							st.wing_hit_cd[hash] = frame + item.wing_hit_cooldown
							local dmg = player.Damage * dmg_mul
							enemy:TakeDamage(dmg, 0, EntityRef(player), 0)
							if (st.wing_sound_cd or 0) <= 0 then
								st.wing_sound_cd = item.wing_sound_cooldown
								sound_tracker.PlayStackedSound(SoundEffect.SOUND_MEATY_DEATHS, 0.35, 1.2, false, 0, 2)
							end
							local splash = Isaac.Spawn(1000, EffectVariant.BLOOD_EXPLOSION, 0, enemy.Position, Vector(0, 0), player)
							if splash then
								splash:GetSprite().Scale = Vector(0.35, 0.35)
							end
						end
					end
				end
			end
		end
	end
	st.prev_wing_pose = {
		root = geom.root,
		left = { inner = geom.left.inner, middle = geom.left.middle, outer = geom.left.outer },
		right = { inner = geom.right.inner, middle = geom.right.middle, outer = geom.right.outer },
	}
end

local function tick_charge_blocked(player, d, st)
	-- Cannot start/advance charge while player animation blocks shooting ownership.
	local counter = d[COUNTER_KEY] or 0
	if st.phase == PHASE_READY then
		st.ready_grace = math.max(0, (st.ready_grace or 0) - 1)
		if st.ready_grace <= 0 then
			counter = math.max(0, counter - item.charge_decay)
			if counter <= 5 then counter = 0 end
			d[COUNTER_KEY] = counter
			if counter <= 0 then
				st.phase = PHASE_IDLE
				st.wall_normal = nil
			else
				st.phase = PHASE_CHARGING
			end
		end
		return
	end
	if counter > 0 then
		counter = math.max(0, counter - item.charge_decay)
		if counter <= 5 then counter = 0 end
		d[COUNTER_KEY] = counter
		if counter <= 0 then
			st.phase = PHASE_IDLE
			st.wall_normal = nil
		end
	end
end

local function tick_charge(player, d, st, on_wall)
	local counter = d[COUNTER_KEY] or 0
	if on_wall then
		st.off_wall_frames = 0
		refresh_wall_normal(player, st)
		counter = math.min(item.charge_max, counter + 1)
		d[COUNTER_KEY] = counter
		if counter >= item.charge_max then
			st.phase = PHASE_READY
			st.ready_grace = item.ready_grace_max
		else
			st.phase = PHASE_CHARGING
		end
		return
	end

	if st.phase == PHASE_READY then
		st.ready_grace = math.max(0, (st.ready_grace or 0) - 1)
		st.off_wall_frames = (st.off_wall_frames or 0) + 1
		local mov = auxi.getmov(player)
		local leaving = mov and mov:Length() > 0.1
		if leaving or st.off_wall_frames >= 3 then
			begin_launch(player, d, st)
			return
		end
		if st.ready_grace > 0 then
			return
		end
	end

	counter = math.max(0, counter - item.charge_decay)
	if counter <= 5 then counter = 0 end
	d[COUNTER_KEY] = counter
	st.off_wall_frames = 0
	if counter <= 0 then
		st.phase = PHASE_IDLE
		st.ready_grace = 0
		st.wall_normal = nil
	else
		st.phase = PHASE_CHARGING
	end
end

local function tick_flight(player, d, st)
	ensure_invuln(player, d)
	st.flight_left = (st.flight_left or 0) - 1
	st.timer = (st.timer or 0) + 1
	if (st.wing_sound_cd or 0) > 0 then
		st.wing_sound_cd = st.wing_sound_cd - 1
	end
	if (st.bounce_boost_left or 0) > 0 then
		st.bounce_boost_left = st.bounce_boost_left - 1
	end

	local progress = 1 - math.max(0, st.flight_left) / math.max(1, item.dash_total)
	local input = auxi.getmov(player)
	if (st.bounce_steer_left or 0) > 0 then
		st.bounce_steer_left = st.bounce_steer_left - 1
		if input and input:Length() > 0.1 and st.dash_dir then
			st.dash_dir = (st.dash_dir * 0.7 + input:Normalized() * 0.3):Normalized()
		end
	else
		st.dash_dir = steer_dash_dir(st.dash_dir or Vector(1, 0), input, progress)
	end
	update_bank(st, st.dash_dir)

	if st.phase == PHASE_LAUNCH then
		st.speed = launch_speed_at(st.timer)
		st.spread = launch_spread_at(st.timer)
		if st.timer >= item.launch_frames then
			st.phase = PHASE_DASH
			st.speed = item.max_speed
			st.spread = 1
		end
	elseif st.phase == PHASE_BOUNCE then
		st.bounce_t = (st.bounce_t or 0) + 1
		st.spread = bounce_spread_at(st.bounce_t)
		if st.bounce_t <= 1 then
			st.speed = item.max_speed * item.bounce_speed_mul
		elseif st.bounce_t <= item.bounce_compress_frames + 2 then
			st.speed = math.max(12.5, (st.speed or 14) * 0.96)
		else
			st.speed = math.min(item.max_speed, (st.speed or 12.5) + 0.2)
		end
		local bounce_end = item.bounce_compress_frames + item.bounce_reignite_frames
		if st.bounce_t >= bounce_end then
			st.phase = PHASE_DASH
			st.bounce_t = 0
		end
	else
		st.speed = math.min(item.max_speed, (st.speed or item.max_speed) + 0.08)
	end

	player.Velocity = st.dash_dir * (st.speed or item.max_speed)
	d[EFFECT_KEY] = d[EFFECT_KEY] or {}
	d[EFFECT_KEY].dir = st.dash_dir:GetAngleDegrees()

	if (st.bounce_immune or 0) > 0 then
		st.bounce_immune = st.bounce_immune - 1
		st.wall_contact = 0
	else
		local on_wall = item.real_collideswithgrid(player)
		if on_wall then
			st.wall_contact = (st.wall_contact or 0) + 1
			if st.wall_contact >= item.wall_stick_frames or player:CollidesWithGrid() then
				begin_bounce(player, d, st)
			end
		else
			st.wall_contact = 0
		end
	end

	if st.phase ~= PHASE_RECOVERY then
		local pose = compute_wing_pose(st, d[COUNTER_KEY] or 0)
		local geom = compute_wing_world_pose(player, st, pose)
		st.wing_geom = geom
		apply_wing_sweep_damage(player, st, geom)
		maintain_brimstone(player, d, st, pose, geom)
	end

	if st.flight_left <= 0 and st.phase ~= PHASE_RECOVERY then
		begin_recovery(player, d, st)
	end
end

local function tick_recovery(player, d, st)
	st.timer = (st.timer or 0) + 1
	local t = math.min(1, st.timer / math.max(1, item.recovery_frames))
	local keep = 1 - t
	local take = t
	local desired = auxi.getmov(player) or Vector(0, 0)
	if desired:Length() > 0.05 then
		desired = desired:Normalized() * player.MoveSpeed * 4
	else
		desired = Vector(0, 0)
	end
	player.Velocity = player.Velocity * (0.2 + 0.6 * keep) + desired * (0.2 + 0.6 * take)
	if st.timer >= item.recovery_frames then
		st.phase = PHASE_IDLE
		st.timer = 0
		st.dash_dir = nil
		st.speed = 0
		st.wall_normal = nil
		d[STATE_KEY] = empty_state()
	end
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_EVALUATE_CACHE,
	params = nil,
	Function = function(_, player, cacheFlag)
		if auxi.has_have_coll(player, item.entity) then
			if cacheFlag == CacheFlag.CACHE_FLYING then
				player.CanFly = true
			end
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PLAYER_RENDER,
	params = nil,
	Function = function(_, player, offset)
		if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
		if not auxi.has_have_coll(player, item.entity) then return end
		local d = player:GetData()
		local st = get_state(d)
		d[COUNTER_KEY] = d[COUNTER_KEY] or 0
		local cnt = d[COUNTER_KEY]
		local flying = st.phase == PHASE_LAUNCH or st.phase == PHASE_DASH
			or st.phase == PHASE_BOUNCE or st.phase == PHASE_RECOVERY
		local pose = compute_wing_pose(st, cnt)
		local any_wing = false
		for i = 1, 5 do
			if (pose.layer_vis[i] or 0) > 0.05 then
				any_wing = true
				break
			end
		end
		d[EFFECT_KEY] = d[EFFECT_KEY] or {}
		if any_wing or flying then
			local pos = Isaac.WorldToScreen(player.Position + player_offset_holder.GetPlayerOffset(player))
				+ Vector(0, -12) * player.SpriteScale.Y
			local geom = st.wing_geom
			if not geom or not flying then
				geom = compute_wing_world_pose(player, st, pose)
				if flying then st.wing_geom = geom end
			end
			local facing = geom.facing or resolve_facing(player, st, pose, d)
			local dash_ang = facing:GetAngleDegrees()
			d[EFFECT_KEY].dir = auxi.checkrounded(d[EFFECT_KEY].dir or dash_ang, dash_ang, 0.75, 0.25, 360)

			local frame = Game():GetFrameCount()
			local do_sprite_update = d[SPRITE_FRAME_KEY] ~= frame
			if do_sprite_update then
				d[SPRITE_FRAME_KEY] = frame
			end

			d[SPRITE_KEY] = d[SPRITE_KEY] or {}
			for i = 1, 5 do
				d[EFFECT_KEY][i] = d[EFFECT_KEY][i] or {}
				local vis = pose.layer_vis[i] or 0
				local layout = item.wing_layout[i]
				if vis > 0.05 then
					if d[SPRITE_KEY][i] == nil then
						local s = Sprite()
						s:Load("gfx/mimics/Blood_Wing/Wing.anm2")
						s:Play("Appear")
						d[SPRITE_KEY][i] = s
					end
				elseif d[SPRITE_KEY][i] then
					d[SPRITE_KEY][i].Color = auxi.MulColor(d[SPRITE_KEY][i].Color, Color(1, 1, 1, 0.55))
					if d[SPRITE_KEY][i].Color.A < 0.01 then d[SPRITE_KEY][i] = nil end
				end

				local s = d[SPRITE_KEY][i]
				if s and vis > 0.02 then
					if do_sprite_update then s:Update() end
					if s:IsFinished("Appear") then s:Play("Idle", true) end

					for j = 1, 2 do
						local sign = (j == 1) and 1 or -1
						local world = geom.layer[i] and geom.layer[i][j]
						if not world then
							local off = layer_world_offset(player, facing, pose, layout, sign, pose.bank or 0)
							world = player.Position + off
						end
						d[EFFECT_KEY][i]["pos"..tostring(j)] = world
						local p0 = Isaac.WorldToScreen(player.Position)
						local p1 = Isaac.WorldToScreen(world)
						local tpos = pos + (p1 - p0)

						local wing_off = layout.angle * sign
						local target_ang = dash_ang + 90 + wing_off
						local key = i * 2 + j
						local cur_ang = st.visual_angle[key]
						if cur_ang == nil then
							cur_ang = target_ang
						else
							cur_ang = approach_angle(cur_ang, target_ang, layout.follow)
						end
						st.visual_angle[key] = cur_ang

						s.Rotation = cur_ang
						s.Scale = Vector(layout.scale, layout.scale) * math.max(0.5, player.SpriteScale.X)
						local alpha = clamp(vis, 0, 1)
						if st.phase == PHASE_READY then
							alpha = alpha * lerp(0.9, 1.0, clamp((pose.pulse - 0.96) / 0.08, 0, 1))
						end
						s.Color = Color(1, 1, 1, alpha, 0, 0, 0)
						s:Render(tpos, Vector(0, 0), Vector(0, 0))
					end
				end
			end
		else
			d[SPRITE_KEY] = {}
			if not flying then
				d[EFFECT_KEY] = {}
			end
		end
		Charging_Bar_holder.render_me(player, {
			name1 = COUNTER_KEY,
			name2 = SPRITE_KEY,
			name3 = item.own_key,
			loadname = "gfx/effects/chargebar/chargebar_Blood_Wing.anm2",
			check1 = function()
				return cnt > 5 or st.phase == PHASE_READY
			end,
			check2 = function()
				return cnt >= item.charge_max or st.phase == PHASE_READY
					or st.phase == PHASE_LAUNCH or st.phase == PHASE_DASH or st.phase == PHASE_BOUNCE
			end,
			check3 = function()
				if flying then
					return math.ceil(math.max(0, st.flight_left) / item.dash_total * 100)
				end
				return math.ceil(cnt / item.charge_max * 100)
			end,
			signal1 = function() end,
		})
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE,
	params = nil,
	Function = function(_, player, collid, count)
		if collid == item.entity and count < 0 then
			Charging_Bar_holder.remove_charge_bar(player, item.own_key)
			local d = player:GetData()
			clear_lasers(d)
			end_invuln(player, d)
			d[STATE_KEY] = nil
			d[COUNTER_KEY] = nil
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE,
	params = nil,
	Function = function(_, player)
		if not auxi.has_have_coll(player, item.entity) then return end
		local d = player:GetData()
		d[UPDATE_KEY] = true
		local st = get_state(d)
		local phase = st.phase

		if phase == PHASE_LAUNCH or phase == PHASE_DASH or phase == PHASE_BOUNCE then
			tick_flight(player, d, st)
		elseif phase == PHASE_RECOVERY then
			tick_recovery(player, d, st)
		else
			if auxi.g_dir_can_work(player) then
				local on_wall = item.real_collideswithgrid(player)
				tick_charge(player, d, st, on_wall)
			else
				tick_charge_blocked(player, d, st)
			end
		end
		refresh_layer_blends(st, d[COUNTER_KEY] or 0)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_GAME_EXIT,
	params = nil,
	Function = function(_)
		for _, player in pairs(auxi.GetPlayers()) do
			local d = player:GetData()
			clear_lasers(d)
			end_invuln(player, d)
			d[STATE_KEY] = nil
		end
	end,
})

return item
