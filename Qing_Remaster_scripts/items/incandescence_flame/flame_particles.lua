-- Orbs leave the real outer edge. They stay on that slice until they clear it.

local geom = require("Qing_Remaster_scripts.items.incandescence_flame.flame_geometry")

local particles = {}

local CAP = { small = 21, medium = 20, large = 14, xlarge = 7 }
local TOTAL = 62
local LIFE = { small = { 8, 14 }, medium = { 12, 20 }, large = { 24, 32 }, xlarge = { 24, 32 } }
local SHED_RATE = 1.15
local FRONT_RATE = 0.6
local BULGE_COOL = 10
local ATTACH_FRAMES = 1
local EMERGE_FRAMES = 3

local function particles_on(cfg, state)
	if not cfg or cfg.static_solid or not state then
		return false
	end
	local profile = cfg.perf_profile or "normal"
	if profile == "layers_particles" or profile == "stress" then
		return true
	end
	if profile == "sim_only" or profile == "orange" or profile == "layers" then
		return false
	end
	return cfg.show_ember == true
end

local function role_count(state, role)
	local n = 0
	for i = 1, #state.ember do
		if state.ember[i].role == role then
			n = n + 1
		end
	end
	return n
end

local function drop_small(state)
	for i = 1, #state.ember do
		if state.ember[i].role == "small" then
			table.remove(state.ember, i)
			state.recycled = (state.recycled or 0) + 1
			return true
		end
	end
	return false
end

local function total_cap(cfg)
	local n = cfg and cfg.ember_cap or TOTAL
	if n < 4 then n = 4 end
	if n > TOTAL then n = TOTAL end
	return n
end

local function room_for(state, role, cfg)
	if role_count(state, role) >= (CAP[role] or 1) then
		return false
	end
	if #state.ember < total_cap(cfg) then
		return true
	end
	if role == "small" then
		state.budget_clamped = true
		return false
	end
	if drop_small(state) then
		return true
	end
	state.budget_clamped = true
	return false
end

local function note_birth(state, sample)
	local bag = state.orb_birth
	if not bag then
		bag = { upper = 0, lower = 0, front = 0, bulge = 0, event = 0 }
		state.orb_birth = bag
	end
	local motion = state.orb_motion
	if not motion then
		motion = { normal = 0, tangent = 0, bulge = 0 }
		state.orb_motion = motion
	end
	local move = sample.motion or "normal"
	motion[move] = (motion[move] or 0) + 1
	local source = sample.source or ""
	if source == "bulge" then
		bag.bulge = (bag.bulge or 0) + 1
		bag.event = (bag.event or 0) + 1
	elseif source == "front" then
		bag.front = (bag.front or 0) + 1
	elseif source == "release" then
		bag.release = (bag.release or 0) + 1
	elseif source == "shed" then
		local side = sample.side or ""
		if side == "upper" or side == "lower" then
			bag[side] = (bag[side] or 0) + 1
		else
			bag.event = (bag.event or 0) + 1
		end
	else
		bag.event = (bag.event or 0) + 1
	end
end

local function motion_for(source, time, index)
	if source == "bulge" then
		return "bulge"
	end
	local roll = geom.hash01(time or 0, index or 1, 61)
	if roll < 0.65 then
		return "normal"
	end
	return "tangent"
end

local function segment_emitting(state, id)
	if not id then
		return state.emitting == true
	end
	local seg = state.segments and state.segments[id]
	if not seg then
		return state.emitting == true
	end
	return seg.phase == "emitting" and not seg.emission_closed
end

local function kind_for(source, time, index, cfg)
	if cfg and cfg.orb_uniform then
		return "small"
	end
	local roll = geom.hash01(time or 0, index or 1, source == "front" and 51 or source == "bulge" and 52 or 53)
	if source == "bulge" then
		if roll > 0.55 then
			return "large"
		end
		return "medium"
	end
	if source == "front" then
		if roll > 0.92 then
			return "xlarge"
		end
		if roll > 0.4 then
			return "large"
		end
		return "medium"
	end
	if roll > 0.84 then
		return "medium"
	end
	return "small"
end

local function place_on(sample, u, depth)
	local ax = sample.ax or sample.x or 0
	local ay = sample.ay or sample.y or 0
	local bx = sample.bx or sample.x or ax
	local by = sample.by or sample.y or ay
	if u < 0 then u = 0 end
	if u > 1 then u = 1 end
	local ex = ax + (bx - ax) * u
	local ey = ay + (by - ay) * u
	local nx = sample.nx or 0
	local ny = sample.ny or 0
	return ex - nx * depth, ey - ny * depth, ex, ey, nx, ny
end

local function spawn_orb(state, cfg, sample, kind, source, motion)
	if not sample or not sample.id then
		return false
	end
	if not room_for(state, kind, cfg) then
		return false
	end
	local span = LIFE[kind] or { 10, 14 }
	local life_mul = cfg.orb_life or 1
	local roll = geom.hash01(sample.id or 1, state.time or 0, kind == "small" and 1 or 2)
	local life = math.floor((span[1] + (span[2] - span[1]) * roll) * life_mul + 0.5)
	if life < 4 then life = 4 end
	if source == "release" and kind ~= "large" and kind ~= "xlarge" then
		life = math.floor(life * 0.8 + 0.5)
		if life < 4 then life = 4 end
	end
	local depth = (cfg.birth_depth or 10) * (0.7 + 0.35 * geom.hash01(sample.id or 1, state.time or 0, 41))
	if kind == "small" then
		depth = depth * 0.65
	elseif kind == "large" or kind == "xlarge" then
		depth = depth * 1.1
	end
	local u = 0.32 + 0.36 * geom.hash01(sample.id or 1, (state.time or 0) + (sample.id_b or 0), 44)
	local x, y, ex, ey, nx, ny = place_on(sample, u, depth)
	local temp0 = sample.temperature or 0.45
	if temp0 < 0 then temp0 = 0 end
	if temp0 > 1 then temp0 = 1 end
	state.spawned = (state.spawned or 0) + 1
	local slip = geom.hash01(state.time or 0, state.spawned, 33) > 0.5 and 1 or -1
	state.ember[#state.ember + 1] = {
		uid = state.spawned,
		kind = kind,
		role = kind,
		source = source,
		motion = motion or "normal",
		phase = "attached",
		segment_id = sample.segment_id,
		x = x,
		y = y,
		birth_x = x,
		birth_y = y,
		edge_x = ex,
		edge_y = ey,
		nx = nx,
		ny = ny,
		vx = 0,
		vy = 0,
		parent_vx = sample.vx or 0,
		parent_vy = sample.vy or 0,
		age = 0,
		life = life,
		hold = 0.55,
		birth_depth = depth,
		attached_frames = ATTACH_FRAMES,
		emerge_frames = EMERGE_FRAMES,
		emerge_age = 0,
		emergence = 0.12,
		edge_relative = -depth,
		temp0 = temp0,
		temperature = temp0,
		source_slice_id = sample.id,
		source_id_b = sample.id_b,
		source_edge_key = sample.edge_key,
		aim_x = sample.jet_x or 0,
		aim_y = sample.jet_y or 0,
		source_side = sample.side or "upper",
		source_u = u,
		source_travel = sample.travel or 0,
		slip = slip,
	}
	sample.source = source
	sample.motion = motion or "normal"
	note_birth(state, sample)
	return true
end

local function pick_weighted(list, total, time, index, salt)
	if not list or #list == 0 or total <= 0 then
		return nil
	end
	local cursor = geom.hash01(time or 0, index or 1, salt or 21) * total
	for i = 1, #list do
		if (list[i].cumulative or 0) >= cursor then
			return list[i].sample
		end
	end
	return list[#list].sample
end

local function source_lists(state, samples, prev)
	local shed = {}
	local front = {}
	local shed_total = 0
	local front_total = 0
	local next_prev = {}
	for i = 1, #samples do
		local sample = samples[i]
		local key = tostring(sample.id or 0) .. ":" .. tostring(sample.side or "")
		local old = prev and prev[key]
		local temp = sample.temperature or 0
		local half = sample.half or 0
		local heat_delta = 0
		local contract = 0
		if old then
			heat_delta = math.abs(temp - (old.temp or temp))
			contract = (old.half or half) - half
		end
		sample.heat_delta = heat_delta
		sample.contract = contract
		next_prev[key] = { temp = temp, half = half, id = sample.id }
		local arc = sample.length or 0
		local curve = math.min(sample.curvature or 0, 1.2)
		local shed_w = arc * (0.35 + temp) * (1 + curve * 0.8) * (1 + math.min(heat_delta, 0.5) * 1.4)
		local front_w = arc * (0.45 + temp)
		if shed_w < 0 then shed_w = 0 end
		if front_w < 0 then front_w = 0 end
		local open = segment_emitting(state, sample.segment_id)
		if open and (sample.side == "upper" or sample.side == "lower") then
			shed_total = shed_total + shed_w
			shed[#shed + 1] = { sample = sample, cumulative = shed_total }
		end
		if open and (sample.side == "front" or sample.front) then
			front_total = front_total + front_w
			front[#front + 1] = { sample = sample, cumulative = front_total }
		end
	end
	return shed, shed_total, front, front_total, next_prev
end

local function take_budget(state, cfg, key, rate, list, total, source, salt)
	local acc = state.orb_acc
	if total <= 0 or rate <= 0 then
		return 0
	end
	acc[key] = math.min(3, (acc[key] or 0) + rate)
	local made = 0
	local guard = 0
	while acc[key] >= 1 and guard < 4 do
		guard = guard + 1
		acc[key] = acc[key] - 1
		state.spawn_attempted_frame = (state.spawn_attempted_frame or 0) + 1
		state.spawn_attempted = (state.spawn_attempted or 0) + 1
		local sample = pick_weighted(list, total, state.time or 0, state.spawn_attempted, salt)
		local kind = kind_for(source, state.time or 0, state.spawn_attempted, cfg)
		local motion = motion_for(source, state.time or 0, state.spawn_attempted)
		if sample and spawn_orb(state, cfg, sample, kind, source, motion) then
			made = made + 1
			state.spawn_accepted_frame = (state.spawn_accepted_frame or 0) + 1
			state.spawn_accepted = (state.spawn_accepted or 0) + 1
		else
			state.spawn_rejected_frame = (state.spawn_rejected_frame or 0) + 1
			state.spawn_rejected = (state.spawn_rejected or 0) + 1
		end
	end
	return made
end

local function shed_bulges(state, cfg, samples)
	local cool = state.bulge_cool or {}
	local now = state.time or 0
	local wait = cfg.bulge_cool or BULGE_COOL
	if wait < 4 then wait = 4 end
	local made = 0
	for i = 1, #samples do
		local sample = samples[i]
		local side = sample.side
		if (side == "upper" or side == "lower") and sample.id and segment_emitting(state, sample.segment_id) and (sample.contract or 0) > 9 and (sample.temperature or 0) > 0.22 then
			if (cool[sample.id] or 0) <= now then
				local count = 1 + math.floor(geom.hash01(now, sample.id, 71) * 3)
				if count > 3 then count = 3 end
				local made_here = 0
				for n = 1, count do
					state.spawn_attempted_frame = (state.spawn_attempted_frame or 0) + 1
					state.spawn_attempted = (state.spawn_attempted or 0) + 1
					local kind = kind_for("bulge", now, sample.id * 10 + n, cfg)
					if spawn_orb(state, cfg, sample, kind, "bulge", "bulge") then
						made = made + 1
						made_here = made_here + 1
						state.spawn_accepted_frame = (state.spawn_accepted_frame or 0) + 1
						state.spawn_accepted = (state.spawn_accepted or 0) + 1
					else
						state.spawn_rejected_frame = (state.spawn_rejected_frame or 0) + 1
						state.spawn_rejected = (state.spawn_rejected or 0) + 1
					end
				end
				if made_here > 0 then
					cool[sample.id] = now + wait
					state.bulge_events = (state.bulge_events or 0) + 1
				end
			end
		end
	end
	state.bulge_cool = cool
	return made
end

local function active_releases(state)
	local n = 0
	local now = state.time or 0
	for _, seg in pairs(state.segments or {}) do
		local rel = seg.release
		if rel and (rel.budget or 0) > (rel.spawned or 0) then
			local age = now - (rel.start_frame or 0)
			if age >= 0 and age <= (rel.duration or 0) then
				n = n + 1
			end
		end
	end
	return n
end

local function pick_release_sample(samples, id, source_id)
	local rear_best, rear_d = nil, 1e9
	local edge_best, edge_d = nil, 1e9
	for i = 1, #samples do
		local sample = samples[i]
		if sample.segment_id == id then
			local prefer = source_id and (sample.id == source_id or sample.id_b == source_id)
			local d = prefer and 0 or (sample.travel or 0)
			if sample.side == "rear" then
				if d < rear_d then
					rear_d = d
					rear_best = sample
				end
			elseif sample.side == "upper" or sample.side == "lower" then
				if d < edge_d then
					edge_d = d
					edge_best = sample
				end
			end
		end
	end
	return rear_best or edge_best
end

local function shed_releases(state, cfg, samples)
	state.release_births_frame = 0
	if not samples or #samples == 0 then
		return 0
	end
	local now = state.time or 0
	local frame_cap = 2
	if active_releases(state) > 3 then
		frame_cap = 1
	end
	local ids = {}
	for id, seg in pairs(state.segments or {}) do
		if seg.release then
			ids[#ids + 1] = id
		end
	end
	table.sort(ids)
	local made = 0
	for n = 1, #ids do
		if made >= frame_cap then
			break
		end
		local id = ids[n]
		local rel = state.segments[id].release
		local age = now - (rel.start_frame or 0)
		local dur = rel.duration or 0
		local budget = rel.budget or 0
		local spawned = rel.spawned or 0
		if age >= 0 and age <= dur and spawned < budget then
			local left_frames = dur - age + 1
			if left_frames < 1 then
				left_frames = 1
			end
			local left_orbs = budget - spawned
			local period = math.floor((dur + 1) / budget)
			if period < 1 then
				period = 1
			end
			local due = (age % period) == 0 or left_orbs >= left_frames
			if due then
				local sample = pick_release_sample(samples, id, rel.source_slice_id)
				local roll = geom.hash01(now, id + spawned, 82)
				local motion = roll < 0.75 and "tangent" or "normal"
				local size_roll = geom.hash01(now, id + spawned, 83)
				local kind = "xlarge"
				if size_roll < 0.20 then
					kind = "medium"
				elseif size_roll < 0.75 then
					kind = "large"
				end
				state.spawn_attempted_frame = (state.spawn_attempted_frame or 0) + 1
				state.spawn_attempted = (state.spawn_attempted or 0) + 1
				if sample and spawn_orb(state, cfg, sample, kind, "release", motion) then
					rel.spawned = spawned + 1
					state.release_births_frame = (state.release_births_frame or 0) + 1
					state.release_particle_total = (state.release_particle_total or 0) + 1
					made = made + 1
					state.spawn_accepted_frame = (state.spawn_accepted_frame or 0) + 1
					state.spawn_accepted = (state.spawn_accepted or 0) + 1
				else
					state.spawn_rejected_frame = (state.spawn_rejected_frame or 0) + 1
					state.spawn_rejected = (state.spawn_rejected or 0) + 1
				end
			end
		end
	end
	return made
end

function particles.consume(state, cfg, built)
	local t0 = nil
	if Isaac and Isaac.GetNanoTime then
		t0 = Isaac.GetNanoTime()
	end
	if not built or not particles_on(cfg, state) then
		if state then
			state.orb_birth = { upper = 0, lower = 0, front = 0, bulge = 0, event = 0 }
			state.spawn_attempted_frame = 0
			state.spawn_accepted_frame = 0
			state.spawn_rejected_frame = 0
			state.release_births_frame = 0
		end
		return 0
	end
	state.orb_birth = { upper = 0, lower = 0, front = 0, bulge = 0, event = 0 }
	state.orb_motion = { normal = 0, tangent = 0, bulge = 0 }
	state.spawn_attempted_frame = 0
	state.spawn_accepted_frame = 0
	state.spawn_rejected_frame = 0
	state.orb_acc = state.orb_acc or { shed = 0, front = 0 }
	local samples = built.edge_samples or {}
	if #samples == 0 then
		state.release_births_frame = 0
		return 0
	end
	local shed, shed_total, front, front_total, next_prev = source_lists(state, samples, state.edge_prev)
	state.edge_prev = next_prev
	local made = shed_bulges(state, cfg, samples)
	local heat = 0
	local heat_n = 0
	for i = 1, #shed do
		local temp = shed[i].sample.temperature or 0
		heat = heat + temp
		heat_n = heat_n + 1
	end
	if heat_n > 0 then
		heat = heat / heat_n
	end
	local shed_rate = cfg.shed_rate or SHED_RATE
	local heat_scale = heat / 0.45
	if heat_scale < 0.25 then heat_scale = 0.25 end
	if heat_scale > 1.4 then heat_scale = 1.4 end
	shed_rate = shed_rate * heat_scale
	local front_rate = 0
	local length = cfg.length or 300
	local reached = (built.front_core_distance or 0) >= length * 0.98
	if state.emitting and reached then
		front_rate = (cfg.front_rate or FRONT_RATE) * heat_scale
	end
	if not state.emitting then
		local full = cfg.afterglow_frames or 1
		local fade = 0
		if full > 0 then
			fade = (state.afterglow or 0) / full
		end
		if fade < 0 then fade = 0 end
		if fade > 1 then fade = 1 end
		shed_rate = shed_rate * fade * 0.35
		front_rate = 0
	end
	if cfg.perf_profile == "stress" then
		shed_rate = shed_rate * 2
		front_rate = front_rate * 2
	end
	made = made + take_budget(state, cfg, "shed", shed_rate, shed, shed_total, "shed", 21)
	made = made + take_budget(state, cfg, "front", front_rate, front, front_total, "front", 22)
	made = made + shed_releases(state, cfg, samples)
	built.edge_weight_total = shed_total + front_total
	local spawn_us = 0
	if t0 and Isaac.GetNanoTime then
		spawn_us = (Isaac.GetNanoTime() - t0) / 1000
	end
	state.orb_spawn_us = spawn_us
	state.orb_build_us = (state.orb_follow_us or 0) + spawn_us
	return made
end

local function same_segment(piece, sample)
	if piece.segment_id or sample.segment_id then
		return piece.segment_id ~= nil and piece.segment_id == sample.segment_id
	end
	return true
end

local function find_segment(map, keys, piece)
	if piece.source_edge_key then
		local sample = keys and keys[piece.source_edge_key]
		if sample and same_segment(piece, sample) then
			return sample
		end
		return nil
	end
	local slot = map and piece.source_slice_id and map[piece.source_slice_id]
	if not slot then
		return nil
	end
	local list = slot[piece.source_side or "upper"]
	if not list or #list == 0 then
		return nil
	end
	local id_a = piece.source_slice_id
	local id_b = piece.source_id_b
	for i = 1, #list do
		local sample = list[i]
		if same_segment(piece, sample) and sample.id == id_a and sample.id_b == id_b then
			return sample
		end
	end
	return nil
end

local function detach_lost(state, piece)
	state.source_lost = (state.source_lost or 0) + 1
	piece.lost = true
	piece.phase = "detached"
	piece.vx = (piece.parent_vx or 0) * 0.45 + (piece.nx or 0) * 1.2
	piece.vy = (piece.parent_vy or 0) * 0.45 + (piece.ny or 0) * 1.2
end

local function forward_tangent(seg)
	local tx = seg.tx or 0
	local ty = seg.ty or 0
	local vx = seg.vx or 0
	local vy = seg.vy or 0
	if tx * vx + ty * vy < 0 then
		return -tx, -ty
	end
	return tx, ty
end

local function release_orb(piece, seg, ex, ey)
	local nx = seg.nx or piece.nx or 0
	local ny = seg.ny or piece.ny or 0
	local slip = piece.slip or 1
	local pvx = seg.vx or piece.parent_vx or 0
	local pvy = seg.vy or piece.parent_vy or 0
	if piece.source == "release" then
		if piece.motion == "tangent" then
			local ftx, fty = piece.ftx, piece.fty
			if not ftx then
				ftx, fty = forward_tangent(seg)
			end
			piece.vx = 0.65 * pvx + 1.4 * ftx + 0.35 * nx
			piece.vy = 0.65 * pvy + 1.4 * fty + 0.35 * ny
		else
			piece.vx = 0.7 * pvx + 1.1 * nx
			piece.vy = 0.7 * pvy + 1.1 * ny
		end
	elseif piece.motion == "tangent" then
		local ftx, fty = piece.ftx, piece.fty
		if not ftx then
			ftx, fty = forward_tangent(seg)
		end
		piece.vx = 0.65 * pvx + 1.8 * ftx + 0.5 * nx
		piece.vy = 0.65 * pvy + 1.8 * fty + 0.5 * ny
	else
		local jump_x = ex - (piece.edge_x or ex)
		local jump_y = ey - (piece.edge_y or ey)
		if jump_x * jump_x + jump_y * jump_y > 24 * 24 then
			jump_x, jump_y = 0, 0
		end
		piece.vx = jump_x + 1.7 * nx + slip * 0.35 * (seg.tx or 0)
		piece.vy = jump_y + 1.7 * ny + slip * 0.35 * (seg.ty or 0)
	end
	if piece.source == "front" or piece.source_side == "front" then
		local ax = piece.aim_x or 0
		local ay = piece.aim_y or 0
		local alen = math.sqrt(ax * ax + ay * ay)
		if alen > 0.001 then
			ax, ay = ax / alen, ay / alen
			local along = piece.vx * ax + piece.vy * ay
			if along < -1.5 then
				piece.vx = piece.vx - along * ax
				piece.vy = piece.vy - along * ay
			end
		end
	end
	piece.phase = "detached"
	piece.emergence = 1
end

local function follow_edge(state, piece, seg)
	local u = piece.source_u or 0.5
	local ax = seg.ax or seg.x or piece.x
	local ay = seg.ay or seg.y or piece.y
	local bx = seg.bx or seg.x or ax
	local by = seg.by or seg.y or ay
	local ex = ax + (bx - ax) * u
	local ey = ay + (by - ay) * u
	local nx = seg.nx or piece.nx or 0
	local ny = seg.ny or piece.ny or 0
	piece.nx = nx
	piece.ny = ny
	piece.parent_vx = seg.vx or 0
	piece.parent_vy = seg.vy or 0
	local depth = piece.birth_depth or 8
	if piece.motion == "tangent" then
		local ftx, fty = forward_tangent(seg)
		piece.ftx = ftx
		piece.fty = fty
		local along = ftx * (bx - ax) + fty * (by - ay)
		local step = along >= 0 and 0.28 or -0.28
		piece.source_u = (piece.source_u or u) + step
		u = piece.source_u
		if u < 0 then u = 0 end
		if u > 1 then u = 1 end
		ex = ax + (bx - ax) * u
		ey = ay + (by - ay) * u
		depth = depth * 0.35
	end
	if piece.phase == "attached" then
		piece.x = ex - nx * depth
		piece.y = ey - ny * depth
		piece.edge_relative = -depth
		piece.emergence = 0.12
		local leave = piece.age >= (piece.attached_frames or ATTACH_FRAMES)
		if piece.motion == "tangent" and (piece.source_u <= 0.02 or piece.source_u >= 0.98 or piece.age >= 3) then
			leave = true
		end
		if leave then
			piece.phase = "emerging"
			piece.emerge_age = 0
		end
	elseif piece.phase == "emerging" then
		piece.emerge_age = (piece.emerge_age or 0) + 1
		local dur = piece.emerge_frames or EMERGE_FRAMES
		if dur < 2 then dur = 2 end
		local u_out = piece.emerge_age / dur
		if u_out > 1 then u_out = 1 end
		local out = 4
		local signed = -depth + (depth + out) * u_out
		piece.x = ex + nx * signed
		piece.y = ey + ny * signed
		piece.edge_relative = signed
		local progress = (signed + depth) / (depth + out)
		if progress < 0 then progress = 0 end
		if progress > 1 then progress = 1 end
		piece.emergence = progress
		if piece.emerge_age >= dur then
			release_orb(piece, seg, ex, ey)
		end
	end
	piece.edge_x = ex
	piece.edge_y = ey
end

function particles.integrate(state, built)
	if not state or not state.ember then
		return
	end
	local t0 = nil
	if Isaac and Isaac.GetNanoTime then
		t0 = Isaac.GetNanoTime()
	end
	local map = built and built.edge_by_id or {}
	local keys = built and built.edge_by_key or {}
	local i = 1
	while i <= #state.ember do
		local piece = state.ember[i]
		piece.age = piece.age + 1
		if piece.age >= piece.life or piece.x ~= piece.x then
			if piece.x ~= piece.x then
				state.nan_count = (state.nan_count or 0) + 1
			end
			table.remove(state.ember, i)
			state.recycled = (state.recycled or 0) + 1
		else
			local phase = piece.phase
			if phase == "attached" or phase == "emerging" then
				local seg = find_segment(map, keys, piece)
				if not seg then
					detach_lost(state, piece)
				else
					follow_edge(state, piece, seg)
				end
			else
				piece.vx = (piece.vx or 0) * 0.96
				piece.vy = (piece.vy or 0) * 0.96 - 0.012
				piece.x = piece.x + piece.vx
				piece.y = piece.y + piece.vy
				if piece.edge_x then
					local dx = piece.x - piece.edge_x
					local dy = piece.y - piece.edge_y
					piece.edge_relative = dx * (piece.nx or 0) + dy * (piece.ny or 0)
				end
				piece.emergence = 1
				local life_u = 0
				if piece.life and piece.life > 0 then
					life_u = piece.age / piece.life
				end
				if life_u > 0.55 then
					piece.phase = "cooling"
				end
			end
			local life_u = 0
			if piece.life and piece.life > 0 then
				life_u = piece.age / piece.life
			end
			if life_u > 1 then life_u = 1 end
			piece.temperature = (piece.temp0 or 0.45) * (1 - life_u * 0.85)
			i = i + 1
		end
	end
	if t0 and Isaac.GetNanoTime then
		state.orb_follow_us = (Isaac.GetNanoTime() - t0) / 1000
	end
end

return particles
