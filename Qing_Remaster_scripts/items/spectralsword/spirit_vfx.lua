-- 妖刀·逢魔灵质粒子：
-- 不变量：新增 visible orbit 不得凭空生成；由 extract carrier 到达后转入 orbit。
-- 消耗：从现有 orbit 取出转为 inject。set_spirit_visual 只设目标数。
-- 初始化/恢复：reconcile_orbits(..., immediate=true) 才允许直接摆盘。

local M = {}

M.VISIBLE_ORBS_MAX = 18

local EXTRACT_FRAMES = 14
local INJECT_FRAMES = 16
local JOIN_FRAMES = 7
local DETACH_FRAMES = 5
local ENTRY_RADIUS_MUL = 1.2
local DETACH_RADIUS_MUL = 1.18
local ORBIT_BASE_R = 13
local ORBIT_RADIUS_GAIN = 5
local ORBIT_SPEED = 0.072
local PHASE_APPROACH = 0.08
local ORBIT_SCALE_BASE = 0.82
local ORBIT_SCALE_GAIN = 0.12
local ORBIT_DEPTH_SCALE_BACK = 0.88
local ORBIT_DEPTH_SCALE_FRONT = 1.12
local ORBIT_ALPHA_BASE = 0.72
local ORBIT_ALPHA_GAIN = 0.22
local ORBIT_DEPTH_ALPHA_BACK = 0.65
local ORBIT_DEPTH_ALPHA_FRONT = 1.0
local FLIGHT_SCALE_BASE = 0.88
-- Seija 吞掉的 extract：约 u=0.55 起开始消散
local DISSIPATE_START_U = 0.55
-- extract 后半段：逐渐被移动中的入轨点吸引
local EXTRACT_HOME_START_U = 0.60

local function clamp01(t)
	return math.max(0, math.min(1, t))
end

local function lerp(a, b, t)
	return a + (b - a) * clamp01(t)
end

local function ease_out_cubic(t)
	t = clamp01(t)
	return 1 - (1 - t) ^ 3
end

local function vec_copy(v)
	return Vector(v.X, v.Y)
end

local function atan2(y, x)
	if math.atan2 then
		return math.atan2(y, x)
	end
	return math.atan(y, x)
end

local function norm_angle_diff(diff)
	while diff > math.pi do diff = diff - math.pi * 2 end
	while diff < -math.pi do diff = diff + math.pi * 2 end
	return diff
end

local function approach_angle(current, target, rate)
	return current + norm_angle_diff(target - current) * rate
end

local function lerp_angle(a, b, t)
	return a + norm_angle_diff(b - a) * clamp01(t)
end

local function curve_offset_for_seed(seed, upward)
	seed = math.floor(tonumber(seed) or 0)
	local y_base = upward and -4 or -3
	return Vector(((seed % 13) - 6) * 0.8, y_base - (seed % 7))
end

local function normalize_essence(ess)
	if type(ess) == "number" then
		return {stat = math.max(0, math.floor(ess)), resource = 0, chance = 0}
	end
	ess = ess or {}
	return {
		stat = math.max(0, math.floor(tonumber(ess.stat) or 0)),
		resource = math.max(0, math.floor(tonumber(ess.resource) or 0)),
		chance = math.max(0, math.floor(tonumber(ess.chance) or 0)),
	}
end

function M.essence_total(ess)
	ess = normalize_essence(ess)
	return ess.stat + ess.resource + ess.chance
end

--- 1 essence = 1 orb；总数封顶 VISIBLE_ORBS_MAX
function M.visible_for_spirit(spirit_or_essence)
	return math.min(M.VISIBLE_ORBS_MAX, math.max(0, M.essence_total(spirit_or_essence)))
end

local function essence_multiset(ess)
	ess = normalize_essence(ess)
	local list = {}
	for _ = 1, ess.stat do list[#list + 1] = "stat" end
	for _ = 1, ess.resource do list[#list + 1] = "resource" end
	for _ = 1, ess.chance do list[#list + 1] = "chance" end
	while #list > M.VISIBLE_ORBS_MAX do list[#list] = nil end
	return list
end

local function ensure_meta(vfx)
	if not vfx then return end
	vfx.particles = vfx.particles or {}
	vfx.node_pulse = vfx.node_pulse or {}
	vfx.orbit_rotation = vfx.orbit_rotation or 0
	vfx.next_orbit_id = vfx.next_orbit_id or 1
	vfx.target_orbit_count = vfx.target_orbit_count or 0
	vfx.spirit_bright = vfx.spirit_bright or 0
end

local function orbit_center(ghost)
	return ghost and ghost.head_pos or nil
end

local function state_radius_mul(st)
	if st == "SLASH" or st == "SLASH_WINDUP" then
		return 1.18
	elseif st == "INJECT" or st == "INJECT_WINDUP" then
		return 0.86
	elseif st == "FAIL" then
		return 1.22
	end
	return 1.0
end

local function state_alpha_mul(st)
	if st == "FAIL" then
		return 0.7
	end
	return 1.0
end

local function base_radius(vfx)
	local bright = math.min(1, (vfx.spirit_bright or 0) / 24)
	return ORBIT_BASE_R + bright * ORBIT_RADIUS_GAIN
end

local function is_orbit_member(p)
	return p and (p.state == "orbit" or p.state == "joining_orbit")
end

local function list_orbit_members(vfx)
	local out = {}
	for _, p in ipairs(vfx.particles or {}) do
		if is_orbit_member(p) then
			out[#out + 1] = p
		end
	end
	return out
end

local function count_pending_joins(vfx)
	local n = 0
	for _, p in ipairs(vfx.particles or {}) do
		if p.state == "extract" and p.role == "orbit_join" then
			n = n + 1
		end
	end
	return n
end

local function apply_orbit_radii(vfx, p)
	local r = base_radius(vfx)
	local jitter = ((p.seed or 0) % 3) - 1
	p.orbit_radius_x = r + jitter
	p.orbit_radius_y = (r + jitter) * 0.62
	local bright = math.min(1, (vfx.spirit_bright or 0) / 24)
	p.scale = ORBIT_SCALE_BASE + bright * ORBIT_SCALE_GAIN
	p.alpha = ORBIT_ALPHA_BASE + bright * ORBIT_ALPHA_GAIN
	p.speed_mul = 0.975 + ((p.seed or 0) % 3) * 0.025
end

local function reassign_slots(vfx)
	local members = list_orbit_members(vfx)
	table.sort(members, function(a, b)
		return (a.orbit_id or 0) < (b.orbit_id or 0)
	end)
	local n = #members
	for i, p in ipairs(members) do
		p.orbit_slot = i
		p.target_phase = (n > 0) and (math.pi * 2 * (i - 1) / n) or 0
		p.orbit_count = n
		apply_orbit_radii(vfx, p)
	end
end

local function compute_orbit_xy(center, angle, rx, ry)
	local depth = math.sin(angle)
	local pos = center + Vector(math.cos(angle) * rx, math.sin(angle) * ry + depth * 1.2)
	return pos, depth
end

--- 为即将入轨的 extract 预订槽位；entry 在正式半径外侧。
function M.reserve_orbit_slot(vfx, ghost, _essence_kind)
	ensure_meta(vfx)
	local members = #list_orbit_members(vfx)
	local pending = count_pending_joins(vfx)
	local n_final = members + pending + 1
	local slot_index = members + pending
	local target_phase = (n_final > 0) and (math.pi * 2 * slot_index / n_final) or 0
	local r = base_radius(vfx)
	local orbit_rx = r
	local orbit_ry = r * 0.62
	local entry_rx = orbit_rx * ENTRY_RADIUS_MUL
	local entry_ry = orbit_ry * ENTRY_RADIUS_MUL
	local center = orbit_center(ghost)
	local entry_pos = nil
	if center then
		entry_pos = select(1, compute_orbit_xy(
			center,
			(vfx.orbit_rotation or 0) + target_phase,
			entry_rx,
			entry_ry
		))
	end
	return {
		target_phase = target_phase,
		orbit_radius_x = orbit_rx,
		orbit_radius_y = orbit_ry,
		entry_phase = target_phase,
		entry_radius_x = entry_rx,
		entry_radius_y = entry_ry,
		entry_pos = entry_pos,
	}
end

local function moving_entry_pos(vfx, ghost, p)
	local center = orbit_center(ghost)
	if not center or p.target_phase == nil then
		return p.to
	end
	local erx = p.entry_radius_x or ((p.orbit_radius_x or ORBIT_BASE_R) * ENTRY_RADIUS_MUL)
	local ery = p.entry_radius_y or (erx * 0.62)
	return select(1, compute_orbit_xy(
		center,
		(vfx.orbit_rotation or 0) + p.target_phase,
		erx,
		ery
	))
end

local function alloc_orbit_id(vfx)
	local id = vfx.next_orbit_id or 1
	vfx.next_orbit_id = id + 1
	return id
end

local function create_orbit_particle(vfx, phase, essence_kind)
	local id = alloc_orbit_id(vfx)
	local p = {
		state = "orbit",
		orbit_id = id,
		orbit_slot = 1,
		phase = phase or 0,
		target_phase = phase or 0,
		seed = id * 97,
		pos = Vector(0, 0),
		t = 0,
		life = 9999,
		layer = "front",
		depth = 0,
		essence_kind = essence_kind or "stat",
		render_scale = nil,
		render_alpha = nil,
	}
	apply_orbit_radii(vfx, p)
	vfx.particles[#vfx.particles + 1] = p
	return p
end

local function remove_particle(vfx, target)
	local kept = {}
	for _, p in ipairs(vfx.particles) do
		if p ~= target then
			kept[#kept + 1] = p
		end
	end
	vfx.particles = kept
end

function M.create()
	return {
		particles = {},
		node_pulse = {},
		orbit_rotation = 0,
		next_orbit_id = 1,
		target_orbit_count = 0,
		spirit_bright = 0,
		essence = {stat = 0, resource = 0, chance = 0},
	}
end

function M.clear(vfx)
	if not vfx then return end
	vfx.particles = {}
	vfx.node_pulse = {}
	vfx.orbit_rotation = 0
	vfx.target_orbit_count = 0
	vfx.spirit_bright = 0
	vfx.essence = {stat = 0, resource = 0, chance = 0}
end

--- 初始化 / Continue：按 essence 种类补齐/裁剪 orbit。
function M.reconcile_orbits(vfx, ghost, spirit_or_essence, opts)
	if not vfx then return end
	ensure_meta(vfx)
	opts = opts or {}
	local ess = normalize_essence(spirit_or_essence)
	local needed = essence_multiset(ess)
	local target = #needed
	vfx.target_orbit_count = target
	vfx.spirit_bright = M.essence_total(ess)
	vfx.essence = ess

	if not opts.immediate then
		return
	end

	for _, p in ipairs(vfx.particles) do
		if p.state == "extract" and p.role == "orbit_join" then
			p.role = "absorb"
		end
	end

	local pool = {stat = {}, resource = {}, chance = {}}
	for _, p in ipairs(list_orbit_members(vfx)) do
		local k = p.essence_kind or "stat"
		pool[k] = pool[k] or {}
		pool[k][#pool[k] + 1] = p
	end
	local keep = {}
	for _, kind in ipairs(needed) do
		local bucket = pool[kind]
		if bucket and #bucket > 0 then
			keep[#keep + 1] = table.remove(bucket)
		else
			local phase = (#keep > 0 and target > 0) and (math.pi * 2 * #keep / target) or 0
			keep[#keep + 1] = create_orbit_particle(vfx, phase, kind)
		end
	end
	for _, bucket in pairs(pool) do
		for _, p in ipairs(bucket) do
			remove_particle(vfx, p)
		end
	end
	reassign_slots(vfx)

	local center = orbit_center(ghost)
	if center then
		for _, p in ipairs(list_orbit_members(vfx)) do
			p.state = "orbit"
			p.phase = p.target_phase or 0
			local ang = (vfx.orbit_rotation or 0) + p.phase
			local rx = (p.orbit_radius_x or ORBIT_BASE_R)
			local ry = (p.orbit_radius_y or rx * 0.62)
			local pos, depth = compute_orbit_xy(center, ang, rx, ry)
			p.pos = pos
			p.depth = depth
			p.layer = depth >= 0 and "front" or "back"
		end
	end
end

function M.set_spirit_visual(vfx, ghost, spirit_or_essence, opts)
	if not vfx then return end
	ensure_meta(vfx)
	opts = opts or {}
	local ess = normalize_essence(spirit_or_essence)
	vfx.target_orbit_count = M.visible_for_spirit(ess)
	vfx.spirit_bright = M.essence_total(ess)
	vfx.essence = ess
	if opts.immediate then
		M.reconcile_orbits(vfx, ghost, ess, {immediate = true})
	else
		for _, p in ipairs(list_orbit_members(vfx)) do
			apply_orbit_radii(vfx, p)
		end
	end
end

local function spawn_flight(vfx, state, from, to, seed, extra)
	seed = seed or Random()
	extra = extra or {}
	local p = {
		state = state,
		role = extra.role or "absorb",
		essence_kind = extra.essence_kind or "stat",
		from = vec_copy(from),
		to = vec_copy(to),
		pos = vec_copy(from),
		t = 0,
		life = state == "inject" and INJECT_FRAMES or EXTRACT_FRAMES,
		seed = seed,
		scale = FLIGHT_SCALE_BASE + (seed % 9) / 100,
		alpha = 1,
		curve_offset = extra.curve_offset or curve_offset_for_seed(seed, state == "extract"),
		layer = "front",
		depth = 1,
		render_scale = nil,
		render_alpha = nil,
	}
	vfx.particles[#vfx.particles + 1] = p
	return p
end

function M.spawn_extract(vfx, from, to, opts)
	if not vfx or not from then return end
	ensure_meta(vfx)
	if type(opts) == "number" then
		opts = {visual_count = opts}
	end
	opts = opts or {}
	local kind = opts.essence_kind or "stat"
	local visual_count = opts.visual_count or 1
	local join_count = opts.orbit_join_count
	if join_count == nil and opts.essence_before and opts.essence_after then
		local b = normalize_essence(opts.essence_before)
		local a = normalize_essence(opts.essence_after)
		join_count = math.max(0, (a[kind] or 0) - (b[kind] or 0))
	end
	join_count = join_count or 1
	if opts.essence_after then
		local ess = normalize_essence(opts.essence_after)
		vfx.target_orbit_count = M.visible_for_spirit(ess)
		vfx.spirit_bright = M.essence_total(ess)
		vfx.essence = ess
	end
	local already = #list_orbit_members(vfx) + count_pending_joins(vfx)
	local room = math.max(0, (vfx.target_orbit_count or 0) - already)
	join_count = math.min(join_count, room, visual_count)
	local ghost = opts.ghost

	for i = 1, visual_count do
		local seed = (Random() % 100000) + i * 17
		local role
		if i <= join_count then
			role = "orbit_join"
		elseif opts.dissipate then
			role = "dissipate"
		else
			role = "absorb"
		end
		local flight_to = to
		local slot = nil
		if role == "orbit_join" then
			slot = M.reserve_orbit_slot(vfx, ghost, kind)
			flight_to = slot.entry_pos or to or from
		elseif not flight_to then
			flight_to = from
		end
		local p = spawn_flight(vfx, "extract", from, flight_to, seed, {
			role = role,
			essence_kind = kind,
			curve_offset = curve_offset_for_seed(seed, true),
		})
		if slot then
			p.target_phase = slot.target_phase
			p.orbit_radius_x = slot.orbit_radius_x
			p.orbit_radius_y = slot.orbit_radius_y
			p.entry_phase = slot.entry_phase
			p.entry_radius_x = slot.entry_radius_x
			p.entry_radius_y = slot.entry_radius_y
		end
	end
end

local function take_orbit_for_inject(vfx, kind)
	local members = list_orbit_members(vfx)
	table.sort(members, function(a, b)
		local ak = (a.essence_kind == kind) and 0 or 1
		local bk = (b.essence_kind == kind) and 0 or 1
		if ak ~= bk then return ak < bk end
		local ao = (a.state == "orbit") and 0 or 1
		local bo = (b.state == "orbit") and 0 or 1
		if ao ~= bo then return ao < bo end
		return (a.orbit_id or 0) > (b.orbit_id or 0)
	end)
	if kind then
		for _, p in ipairs(members) do
			if p.essence_kind == kind then return p end
		end
		return nil
	end
	return members[1]
end

function M.spawn_inject(vfx, to, opts)
	if not vfx or not to then return end
	ensure_meta(vfx)
	opts = opts or {}
	local kind = opts.essence_kind or "stat"
	local visual_count = opts.visual_count or 1
	local leave_count = opts.orbit_leave_count
	if leave_count == nil and opts.essence_before and opts.essence_after then
		local b = normalize_essence(opts.essence_before)
		local a = normalize_essence(opts.essence_after)
		leave_count = math.max(0, (b[kind] or 0) - (a[kind] or 0))
	end
	leave_count = leave_count or 1
	if opts.essence_after then
		local ess = normalize_essence(opts.essence_after)
		vfx.target_orbit_count = M.visible_for_spirit(ess)
		vfx.spirit_bright = M.essence_total(ess)
		vfx.essence = ess
	end
	leave_count = math.min(leave_count, #list_orbit_members(vfx))

	local carriers_spawned = 0
	for i = 1, leave_count do
		local carrier = take_orbit_for_inject(vfx, kind)
		if not carrier then break end
		-- 同一颗球：先短暂外扩脱轨，再转为 inject Bezier
		carrier.state = "detaching"
		carrier.role = "orbit_leave"
		carrier.detach_t = 0
		carrier.inject_to = vec_copy(to)
		carrier.life = 9999
		carriers_spawned = carriers_spawned + 1
	end

	if carriers_spawned == 0 and visual_count > 0 and opts.from then
		for i = 1, visual_count do
			local seed = (Random() % 100000) + i * 31
			spawn_flight(vfx, "inject", opts.from, to, seed, {
				role = "absorb",
				essence_kind = kind,
				curve_offset = curve_offset_for_seed(seed, false),
			})
		end
	end

	reassign_slots(vfx)
	if opts.node_id then
		vfx.node_pulse[opts.node_id] = 12
	end
end

local function begin_joining_orbit(vfx, p, ghost)
	local center = orbit_center(ghost)
	p.state = "joining_orbit"
	p.role = nil
	p.join_t = 0
	p.life = 9999
	p.orbit_id = alloc_orbit_id(vfx)
	p.seed = p.seed or (p.orbit_id * 97)
	p.essence_kind = p.essence_kind or "stat"
	if center then
		local world_ang = atan2(p.pos.Y - center.Y, p.pos.X - center.X)
		p.entry_phase = world_ang - (vfx.orbit_rotation or 0)
		if not p.entry_radius_x then
			local dx = p.pos.X - center.X
			local dy = p.pos.Y - center.Y
			local dist = math.sqrt(dx * dx + dy * dy)
			p.entry_radius_x = dist
			p.entry_radius_y = dist * 0.62
		end
	else
		p.entry_phase = p.entry_phase or p.target_phase or 0
	end
	p.phase = p.entry_phase or 0
	if not p.orbit_radius_x then
		apply_orbit_radii(vfx, p)
	else
		local bright = math.min(1, (vfx.spirit_bright or 0) / 24)
		p.scale = ORBIT_SCALE_BASE + bright * ORBIT_SCALE_GAIN
		p.alpha = ORBIT_ALPHA_BASE + bright * ORBIT_ALPHA_GAIN
		p.speed_mul = 0.975 + ((p.seed or 0) % 3) * 0.025
	end
	reassign_slots(vfx)
end

function M.tick(vfx, ghost)
	if not vfx then return end
	ensure_meta(vfx)
	local next_list = {}
	local head = ghost and ghost.head_pos
	local center = orbit_center(ghost)
	local st = ghost and ghost.state
	local r_mul = state_radius_mul(st)
	local a_mul = state_alpha_mul(st)

	vfx.orbit_rotation = (vfx.orbit_rotation or 0) + ORBIT_SPEED

	for _, p in ipairs(vfx.particles) do
		p.t = (p.t or 0) + 1
		if p.state == "extract" then
			local raw_u = clamp01(p.t / p.life)
			local u = ease_out_cubic(raw_u)
			if p.role == "orbit_join" then
				local entry = moving_entry_pos(vfx, ghost, p)
				if entry then
					p.to = entry
				end
			elseif head and p.role ~= "dissipate" then
				p.to = head
			end
			local mid = (p.from + p.to) * 0.5 + (p.curve_offset or Vector(0, -12))
			local u1 = 1 - u
			local bezier = p.from * (u1 * u1) + mid * (2 * u1 * u) + p.to * (u * u)
			if p.role == "orbit_join" and raw_u > EXTRACT_HOME_START_U and p.to then
				local home_t = (raw_u - EXTRACT_HOME_START_U) / math.max(1e-3, 1 - EXTRACT_HOME_START_U)
				home_t = ease_out_cubic(home_t)
				p.pos = bezier * (1 - home_t) + p.to * home_t
			else
				p.pos = bezier
			end
			p.alpha = 1 - u * 0.2
			p.layer = "front"
			p.depth = 1
			p.render_scale = p.scale
			p.render_alpha = p.alpha
			if p.role == "dissipate" then
				-- 中途消散：玩家可见「抽出来了但散掉」
				if raw_u >= DISSIPATE_START_U then
					local fade = (raw_u - DISSIPATE_START_U) / math.max(1e-3, 1 - DISSIPATE_START_U)
					fade = clamp01(fade)
					p.alpha = (1 - u * 0.2) * (1 - fade)
					p.render_scale = (p.scale or ORBIT_SCALE_BASE) * (1 - fade * 0.45)
					p.render_alpha = p.alpha
				end
				if p.t < p.life then
					next_list[#next_list + 1] = p
				end
			elseif p.t < p.life then
				next_list[#next_list + 1] = p
			elseif p.role == "orbit_join" then
				begin_joining_orbit(vfx, p, ghost)
				next_list[#next_list + 1] = p
			end
			-- absorb：到达后销毁
		elseif p.state == "detaching" then
			p.detach_t = (p.detach_t or 0) + 1
			p.phase = approach_angle(p.phase or 0, p.target_phase or 0, PHASE_APPROACH)
			if p.speed_mul then
				p.phase = p.phase + ORBIT_SPEED * ((p.speed_mul or 1) - 1)
			end
			local ang = (vfx.orbit_rotation or 0) + (p.phase or 0)
			local leave_u = ease_out_cubic((p.detach_t or 0) / DETACH_FRAMES)
			local mul = lerp(1.0, DETACH_RADIUS_MUL, leave_u) * r_mul
			local rx = (p.orbit_radius_x or ORBIT_BASE_R) * mul
			local ry = (p.orbit_radius_y or rx * 0.62) * mul
			if center then
				local pos, depth = compute_orbit_xy(center, ang, rx, ry)
				p.pos = pos
				p.depth = depth
				p.layer = depth >= 0 and "front" or "back"
				local z = (depth + 1) * 0.5
				p.render_scale = (p.scale or ORBIT_SCALE_BASE) * lerp(ORBIT_DEPTH_SCALE_BACK, ORBIT_DEPTH_SCALE_FRONT, z)
				p.render_alpha = (p.alpha or 1) * lerp(ORBIT_DEPTH_ALPHA_BACK, ORBIT_DEPTH_ALPHA_FRONT, z) * a_mul
			end
			if (p.detach_t or 0) >= DETACH_FRAMES then
				p.state = "inject"
				p.from = vec_copy(p.pos)
				p.to = p.inject_to or p.pos
				p.t = 0
				p.life = INJECT_FRAMES
				p.curve_offset = curve_offset_for_seed(p.seed or 0, false)
				p.orbit_id = nil
				p.inject_to = nil
				p.detach_t = nil
				p.layer = "front"
				p.depth = 1
				p.scale = FLIGHT_SCALE_BASE + ((p.seed or 0) % 9) / 100
				p.alpha = 1
			end
			next_list[#next_list + 1] = p
		elseif p.state == "inject" then
			local u = ease_out_cubic(p.t / p.life)
			local mid = (p.from + p.to) * 0.5 + (p.curve_offset or Vector(0, -10))
			local u1 = 1 - u
			p.pos = p.from * (u1 * u1) + mid * (2 * u1 * u) + p.to * (u * u)
			p.alpha = 1 - u * 0.35
			p.layer = "front"
			p.depth = 1
			p.render_scale = p.scale
			p.render_alpha = p.alpha
			if p.t < p.life then
				next_list[#next_list + 1] = p
			end
		elseif p.state == "joining_orbit" then
			p.join_t = (p.join_t or 0) + 1
			local u = ease_out_cubic((p.join_t or 0) / JOIN_FRAMES)
			local phase = lerp_angle(p.entry_phase or 0, p.target_phase or 0, u)
			p.phase = phase
			local rx = lerp(
				p.entry_radius_x or ((p.orbit_radius_x or ORBIT_BASE_R) * ENTRY_RADIUS_MUL),
				p.orbit_radius_x or ORBIT_BASE_R,
				u
			) * r_mul
			local ry = lerp(
				p.entry_radius_y or (rx * 0.62),
				p.orbit_radius_y or (rx * 0.62),
				u
			) * r_mul
			if center then
				local orbit_pos, depth = compute_orbit_xy(center, (vfx.orbit_rotation or 0) + phase, rx, ry)
				p.pos = orbit_pos
				p.depth = depth
				p.layer = depth >= 0 and "front" or "back"
				local z = (depth + 1) * 0.5
				p.render_scale = (p.scale or ORBIT_SCALE_BASE) * lerp(ORBIT_DEPTH_SCALE_BACK, ORBIT_DEPTH_SCALE_FRONT, z)
				p.render_alpha = (p.alpha or 1) * lerp(ORBIT_DEPTH_ALPHA_BACK, ORBIT_DEPTH_ALPHA_FRONT, z) * a_mul
			end
			if (p.join_t or 0) >= JOIN_FRAMES then
				p.state = "orbit"
				p.join_from = nil
				p.join_t = nil
				p.entry_phase = nil
				p.entry_radius_x = nil
				p.entry_radius_y = nil
			end
			next_list[#next_list + 1] = p
		elseif p.state == "orbit" then
			p.phase = approach_angle(p.phase or 0, p.target_phase or 0, PHASE_APPROACH)
			if p.speed_mul then
				p.phase = p.phase + ORBIT_SPEED * ((p.speed_mul or 1) - 1)
			end
			local ang = (vfx.orbit_rotation or 0) + (p.phase or 0)
			local rx = (p.orbit_radius_x or ORBIT_BASE_R) * r_mul
			local ry = (p.orbit_radius_y or rx * 0.62) * r_mul
			if center then
				local pos, depth = compute_orbit_xy(center, ang, rx, ry)
				p.pos = pos
				p.depth = depth
				p.layer = depth >= 0 and "front" or "back"
				local z = (depth + 1) * 0.5
				p.render_scale = (p.scale or ORBIT_SCALE_BASE) * lerp(ORBIT_DEPTH_SCALE_BACK, ORBIT_DEPTH_SCALE_FRONT, z)
				p.render_alpha = (p.alpha or 1) * lerp(ORBIT_DEPTH_ALPHA_BACK, ORBIT_DEPTH_ALPHA_FRONT, z) * a_mul
			end
			next_list[#next_list + 1] = p
		end
	end
	vfx.particles = next_list

	for id, frames in pairs(vfx.node_pulse) do
		local n = frames - 1
		if n <= 0 then vfx.node_pulse[id] = nil
		else vfx.node_pulse[id] = n end
	end
end

--- layer = nil → 全部；orbit/joining 按 depth 层；飞行粒子归 front
function M.get_particles(vfx, layer)
	local src = (vfx and vfx.particles) or {}
	if layer == nil then
		return src
	end
	local out = {}
	for _, p in ipairs(src) do
		if p.state == "orbit" or p.state == "joining_orbit" or p.state == "detaching" then
			if p.layer == layer then
				out[#out + 1] = p
			end
		elseif layer == "front" then
			out[#out + 1] = p
		end
	end
	return out
end

function M.get_node_pulse(vfx, node_id)
	if not vfx or not vfx.node_pulse then return 0 end
	return vfx.node_pulse[node_id] or 0
end

return M
