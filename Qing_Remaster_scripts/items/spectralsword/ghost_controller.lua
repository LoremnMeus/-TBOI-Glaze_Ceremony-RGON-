-- 妖刀·逢魔妖鬼控制器：屏幕空间运动 / path-history spine / 交互状态机。
-- 生命周期：EMERGE → ENTRY_ORBIT → ENTRY_TRAVEL → HOVER ↔ TRAVEL / 动作 → RETURN → SINK
-- 出场：举起刀锚点冒出 → 升至环绕椭圆顶 → 绕玩家约 0.875 圈 → 切线脱离飞向 HUD。
-- 尾巴：真实头部轨迹按距离重采样 → ideal spine soft-follow → 轻长度校正 → wave。
-- request_exit(ghost, target_pos)：调用方提供屏幕空间回归点。

local hud_nodes = require("Qing_Remaster_scripts.items.spectralsword.hud_nodes")

local M = {}

M.STATE = {
	EMERGE = "EMERGE",
	ENTRY_ORBIT = "ENTRY_ORBIT",
	ENTRY_TRAVEL = "ENTRY_TRAVEL",
	IDLE = "IDLE",
	TRAVEL = "TRAVEL",
	HOVER = "HOVER",
	SLASH_WINDUP = "SLASH_WINDUP",
	SLASH = "SLASH",
	EXTRACT = "EXTRACT",
	INJECT_WINDUP = "INJECT_WINDUP",
	INJECT = "INJECT",
	FAIL = "FAIL",
	RETURN = "RETURN",
	SINK = "SINK",
}

local SEGMENT_COUNT = 10
local SEGMENT_LENGTH = 7
local CHAIN_LENGTH = (SEGMENT_COUNT - 1) * SEGMENT_LENGTH
local FOLLOW_RATE = 0.28
local ARRIVE_DIST = 3.5
local TRAVEL_ARC = 18
local ENTRY_TRAVEL_ARC = 32
local ENTRY_TRAVEL_RATE = 0.09
local RETURN_TRAVEL_ARC = 28
local RETURN_TRAVEL_RATE = 0.09
local WAVE_AMP = 1.8
local WAVE_SPEED = 0.12
local WAVE_PHASE = 0.65
-- path_history[1] = newest（靠头）；path_history[#] = oldest（靠尾）
local PATH_SAMPLE_SPACING = 2.0
local PATH_KEEP_DISTANCE = 96
local SPINE_FOLLOW_HEAD = 0.72
local SPINE_FOLLOW_TAIL = 0.28
local LENGTH_CORRECTION = 0.32
local SLASH_WINDUP_FRAMES = 3
local SLASH_FRAMES = 4
local INJECT_WINDUP_FRAMES = 3
local ACTION_HOLD_FRAMES = 3
local FAIL_FRAMES = 8
local EMERGE_FRAMES = 7
local EMERGE_DEPTH = 10
local EMERGE_HEIGHT = 10
local SINK_FRAMES = 7

-- 出场表现默认（对齐 MultiKnife 举起中心 Y=-20）
local DEFAULT_SPAWN = {
	sword_anchor_x = 0,
	sword_anchor_y = -20,
	sword_emerge_x = 0,
	sword_emerge_y = -4,
	rise_distance = 26,
	orbit_rx = 42,
	orbit_ry = 14,
	orbit_frames = 34,
	orbit_revs = 0.875,
	leave_tangent = 26,
	orbit_center_y = -10,
}

local function copy_spawn(src)
	local t = {}
	for k, v in pairs(src) do
		t[k] = v
	end
	return t
end

M.SPAWN = copy_spawn(DEFAULT_SPAWN)

function M.get_spawn_config()
	return copy_spawn(M.SPAWN)
end

function M.set_spawn_config(key, value)
	if DEFAULT_SPAWN[key] == nil then return false end
	local n = tonumber(value)
	if n == nil then return false end
	M.SPAWN[key] = n
	return true
end

function M.reset_spawn_config()
	M.SPAWN = copy_spawn(DEFAULT_SPAWN)
end

local WIDTH_PROFILE = {
	0.82, 0.74, 0.64, 0.53, 0.43, 0.34, 0.25, 0.17, 0.10, 0.04,
}

local function vec_copy(v)
	return Vector(v.X, v.Y)
end

local function vec_normalize(v, fallback)
	local len = v:Length()
	if len < 0.001 then
		return fallback and vec_copy(fallback) or Vector(0, 1)
	end
	return Vector(v.X / len, v.Y / len)
end

local function bezier2(p0, p1, p2, t)
	local u = 1 - t
	return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t)
end

local function bezier2_tangent(p0, p1, p2, t)
	local d = (p1 - p0) * (2 * (1 - t)) + (p2 - p1) * (2 * t)
	return vec_normalize(d, nil)
end

local function ease_out_cubic(t)
	t = math.max(0, math.min(1, t))
	return 1 - (1 - t) ^ 3
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function clamp01(t)
	if t < 0 then return 0 end
	if t > 1 then return 1 end
	return t
end

local function perpendicular(from, to)
	local d = to - from
	local len = d:Length()
	if len < 0.001 then return Vector(0, -1) end
	return Vector(-d.Y / len, d.X / len)
end

local function make_segments(origin)
	local segs = {}
	for i = 1, SEGMENT_COUNT do
		segs[i] = {
			pos = origin + Vector(0, SEGMENT_LENGTH * (i - 1)),
			dir = Vector(0, 1),
		}
	end
	return segs
end

local function atan2(y, x)
	if math.atan2 then
		return math.atan2(y, x)
	end
	return math.atan(y, x)
end

local function ellipse_pos(center, ang, rx, ry)
	return center + Vector(math.cos(ang) * rx, math.sin(ang) * ry)
end

local function ellipse_tangent(ang, rx, ry)
	return vec_normalize(Vector(-math.sin(ang) * rx, math.cos(ang) * ry), Vector(1, 0))
end

--- opts table：sword_anchor / orbit_center / target_node_id；或旧签名 (spawn_pos, target_node_id)
function M.create_ghost(spawn_pos_or_opts, target_node_id)
	local opts = {}
	if type(spawn_pos_or_opts) == "table" and spawn_pos_or_opts.X == nil then
		opts = spawn_pos_or_opts
	else
		opts.sword_anchor = spawn_pos_or_opts
		opts.target_node_id = target_node_id
	end
	local cfg = M.get_spawn_config()
	local sword = opts.sword_anchor or Vector(160, 120)
	local orbit_c = opts.orbit_center or (sword + Vector(0, cfg.orbit_center_y))
	local emerge_from = sword + Vector(cfg.sword_emerge_x, cfg.sword_emerge_y)
	local orbit_rx = cfg.orbit_rx
	local orbit_ry = cfg.orbit_ry
	local orbit_top = ellipse_pos(orbit_c, -math.pi * 0.5, orbit_rx, orbit_ry)
	local rise_candidate = Vector(orbit_c.X, emerge_from.Y - cfg.rise_distance)
	local emerge_aim = Vector(orbit_top.X, math.min(orbit_top.Y, rise_candidate.Y))
	local start_ang = atan2(emerge_aim.Y - orbit_c.Y, emerge_aim.X - orbit_c.X)
	local emerge_to = ellipse_pos(orbit_c, start_ang, orbit_rx, orbit_ry)
	local seed = vec_copy(emerge_from)
	local entry_mode = opts.entry_mode or "hud"
	local orbit_revs = cfg.orbit_revs
	local target_node = opts.target_node_id
	if entry_mode == "orbit_return" then
		orbit_revs = tonumber(opts.orbit_revs) or 1.0
		target_node = nil
	else
		target_node = target_node or hud_nodes.default_node_id()
		if opts.orbit_revs ~= nil then
			orbit_revs = tonumber(opts.orbit_revs) or orbit_revs
		end
	end
	return {
		active = true,
		state = M.STATE.EMERGE,
		state_t = 0,
		head_pos = vec_copy(emerge_from),
		prev_head_pos = vec_copy(emerge_from),
		target_pos = vec_copy(emerge_to),
		target_node = target_node,
		entry_mode = entry_mode,
		entry_orbit_done = false,
		facing = 1,
		segments = make_segments(emerge_from),
		path_history = {seed},
		path_committed = vec_copy(seed),
		initial_tail_dir = Vector(0, 1),
		travel_from = vec_copy(emerge_from),
		travel_to = vec_copy(emerge_to),
		travel_t = 1,
		travel_side = 1,
		travel_tangent = nil,
		slash_t = 0,
		inject_t = 0,
		emerge_from = emerge_from,
		emerge_to = emerge_to,
		orbit_center = vec_copy(orbit_c),
		orbit_rx = orbit_rx,
		orbit_ry = orbit_ry,
		orbit_start_ang = start_ang,
		orbit_revs = orbit_revs,
		orbit_frames = math.max(1, math.floor(cfg.orbit_frames)),
		leave_tangent = cfg.leave_tangent,
		sword_anchor = vec_copy(sword),
		tail_reveal = 0,
		coil = 0,
		wave_amp = WAVE_AMP,
		alpha = 0,
		pulse = 0,
		notice = nil,
		fail_reason = nil,
		pending_action = nil,
		debug = false,
	}
end

function M.is_active(ghost)
	return ghost and ghost.active == true
end

function M.is_input_ready(ghost)
	return ghost and ghost.active and ghost.state == M.STATE.HOVER
end

local function set_state(ghost, state)
	ghost.state = state
	ghost.state_t = 0
end

local function refresh_target_anchor(ghost, player)
	if not ghost or not ghost.target_node then
		return
	end
	local node = hud_nodes.get(ghost.target_node)
	if not node then return end
	if node.get_ghost_anchor then
		ghost.target_pos = node.get_ghost_anchor(player)
	elseif node.get_anchor then
		ghost.target_pos = node.get_anchor(player)
	end
	if node.get_anchor then
		ghost.hud_anchor = node.get_anchor(player)
	end
end

local function setup_bezier_travel(ghost, from, to, arc, ctrl_override)
	ghost.travel_from = vec_copy(from)
	ghost.travel_to = vec_copy(to)
	ghost.travel_t = 0
	if ctrl_override then
		ghost.travel_ctrl = vec_copy(ctrl_override)
	else
		local side = ghost.travel_side or 1
		ghost.travel_side = -side
		local mid = (ghost.travel_from + ghost.travel_to) * 0.5
		local n = perpendicular(ghost.travel_from, ghost.travel_to)
		ghost.travel_ctrl = mid + n * (arc * side)
	end
	local dx = ghost.travel_to.X - ghost.travel_from.X
	if math.abs(dx) > 0.5 then
		ghost.facing = dx >= 0 and 1 or -1
	end
end

function M.begin_travel(ghost, player, node_id)
	if not ghost or not node_id or node_id == ghost.target_node then
		if ghost and ghost.state == M.STATE.HOVER then
			refresh_target_anchor(ghost, player)
		end
		return false
	end
	local node = hud_nodes.get(node_id)
	if not node then return false end
	ghost.target_node = node_id
	refresh_target_anchor(ghost, player)
	setup_bezier_travel(ghost, ghost.head_pos, ghost.target_pos, TRAVEL_ARC)
	set_state(ghost, M.STATE.TRAVEL)
	return true
end

local function begin_entry_orbit(ghost)
	ghost.orbit_ang = ghost.orbit_start_ang or (-math.pi * 0.5)
	ghost.orbit_t = 0
	set_state(ghost, M.STATE.ENTRY_ORBIT)
end

local function begin_entry_travel(ghost, player)
	if not ghost.target_node then
		return
	end
	refresh_target_anchor(ghost, player)
	local ang = ghost.orbit_ang or ghost.orbit_start_ang or (-math.pi * 0.5)
	local tan = ellipse_tangent(ang, ghost.orbit_rx or 42, ghost.orbit_ry or 14)
	local leave = ghost.leave_tangent or 26
	local ctrl = ghost.head_pos + tan * leave
	setup_bezier_travel(ghost, ghost.head_pos, ghost.target_pos, ENTRY_TRAVEL_ARC, ctrl)
	set_state(ghost, M.STATE.ENTRY_TRAVEL)
end

function M.request_navigate(ghost, player, direction)
	if not M.is_input_ready(ghost) then return false end
	local next_id = hud_nodes.neighbor(ghost.target_node, direction)
	if not next_id then return false end
	return M.begin_travel(ghost, player, next_id)
end

function M.request_extract(ghost)
	if not M.is_input_ready(ghost) then return false end
	ghost.pending_action = "extract"
	set_state(ghost, M.STATE.SLASH_WINDUP)
	ghost.slash_t = 0
	return true
end

function M.request_inject(ghost)
	if not M.is_input_ready(ghost) then return false end
	ghost.pending_action = "inject"
	set_state(ghost, M.STATE.INJECT_WINDUP)
	ghost.inject_t = 0
	return true
end

function M.request_exit(ghost, target_pos)
	if not ghost or not ghost.active then return false end
	if ghost.state == M.STATE.RETURN or ghost.state == M.STATE.SINK then
		return false
	end
	local to = target_pos and vec_copy(target_pos) or (vec_copy(ghost.head_pos) + Vector(0, 24))
	ghost.return_from = vec_copy(ghost.head_pos)
	ghost.return_to = to
	ghost.return_t = 0
	local side = ghost.travel_side or 1
	ghost.travel_side = -side
	local mid = (ghost.return_from + ghost.return_to) * 0.5
	local n = perpendicular(ghost.return_from, ghost.return_to)
	ghost.return_ctrl = mid + n * (RETURN_TRAVEL_ARC * side)
	local dx = ghost.return_to.X - ghost.return_from.X
	if math.abs(dx) > 0.5 then
		ghost.facing = dx >= 0 and 1 or -1
	end
	ghost.alpha = 1
	ghost.tail_reveal = 1
	set_state(ghost, M.STATE.RETURN)
	return true
end

local function path_arc_length(hist)
	local total = 0
	for i = 1, #hist - 1 do
		total = total + (hist[i] - hist[i + 1]):Length()
	end
	return total
end

local function trim_path_by_distance(hist)
	while #hist > 1 and path_arc_length(hist) > PATH_KEEP_DISTANCE do
		table.remove(hist) -- drop oldest
	end
end

--- 按距离重采样：不覆盖已提交点；慢速移动也会累积真实轨迹。
local function append_path_history(ghost)
	local hist = ghost.path_history
	if not hist then
		hist = {vec_copy(ghost.head_pos)}
		ghost.path_history = hist
		ghost.path_committed = vec_copy(ghost.head_pos)
		return
	end
	if #hist == 0 then
		hist[1] = vec_copy(ghost.head_pos)
		ghost.path_committed = vec_copy(ghost.head_pos)
		return
	end

	local hp = ghost.head_pos
	local committed = ghost.path_committed or hist[1]
	local delta = hp - committed
	local dist = delta:Length()
	if dist < PATH_SAMPLE_SPACING then
		return
	end

	local dir = vec_normalize(delta, ghost.initial_tail_dir or Vector(0, 1))
	local remaining = dist
	while remaining >= PATH_SAMPLE_SPACING do
		committed = committed + dir * PATH_SAMPLE_SPACING
		table.insert(hist, 1, vec_copy(committed))
		remaining = remaining - PATH_SAMPLE_SPACING
	end
	ghost.path_committed = vec_copy(committed)
	trim_path_by_distance(hist)
end

--- head → tail：poly[1]=current head，其后为 path_history（新→旧）。
local function build_head_to_tail_polyline(ghost)
	local poly = {vec_copy(ghost.head_pos)}
	local hist = ghost.path_history
	if hist then
		for i = 1, #hist do
			poly[#poly + 1] = hist[i]
		end
	end
	return poly
end

--- 沿 head→tail 折线后退 dist；不足时沿最老方向或 initial_tail_dir 外推。
local function sample_at_distance(ghost, points_head_to_tail, dist)
	local remaining = dist
	local n = #points_head_to_tail
	if n == 0 then
		return Vector(0, 0)
	end
	if n == 1 then
		local dir = ghost.initial_tail_dir or Vector(0, 1)
		return points_head_to_tail[1] + dir * remaining
	end
	for i = 1, n - 1 do
		local a = points_head_to_tail[i]
		local b = points_head_to_tail[i + 1]
		local seg = b - a
		local len = seg:Length()
		if len > 0.001 then
			if remaining <= len then
				return a + seg * (remaining / len)
			end
			remaining = remaining - len
		end
	end
	local a = points_head_to_tail[n - 1]
	local b = points_head_to_tail[n]
	local dir = vec_normalize(b - a, ghost.initial_tail_dir or Vector(0, 1))
	return b + dir * remaining
end

local function update_soft_body(ghost)
	append_path_history(ghost)
	local segs = ghost.segments
	local poly = build_head_to_tail_polyline(ghost)

	local tip = sample_at_distance(ghost, poly, CHAIN_LENGTH)
	local end_to_end = (ghost.head_pos - tip):Length()
	local coil = clamp01(1 - end_to_end / math.max(CHAIN_LENGTH, 1))
	ghost.coil = coil
	-- coil 只压 wave，不改几何硬度
	ghost.wave_amp = WAVE_AMP * lerp(1.0, 0.5, coil)

	segs[1].pos = vec_copy(ghost.head_pos)

	for i = 2, SEGMENT_COUNT do
		local ideal = sample_at_distance(ghost, poly, (i - 1) * SEGMENT_LENGTH)
		local t = (i - 2) / math.max(1, SEGMENT_COUNT - 2)
		local follow = lerp(SPINE_FOLLOW_HEAD, SPINE_FOLLOW_TAIL, t)
		segs[i].pos = segs[i].pos + (ideal - segs[i].pos) * follow
	end

	-- 一次轻长度校正（允许约 6~8px 弹性，不强行 rigid 7）
	for i = 2, SEGMENT_COUNT do
		local prev = segs[i - 1].pos
		local diff = segs[i].pos - prev
		local len = diff:Length()
		if len > 0.001 then
			local target = prev + diff * (SEGMENT_LENGTH / len)
			segs[i].pos = segs[i].pos + (target - segs[i].pos) * LENGTH_CORRECTION
			segs[i].dir = vec_normalize(segs[i].pos - prev, Vector(0, 1))
		end
	end

	ghost.prev_head_pos = vec_copy(ghost.head_pos)
end

function M.get_render_points(ghost, time)
	time = time or (Game():GetFrameCount())
	local pts = {}
	local segs = ghost.segments
	local reveal = tonumber(ghost.tail_reveal) or 1
	local wave_amp = tonumber(ghost.wave_amp) or WAVE_AMP
	for i = 1, SEGMENT_COUNT do
		local pos = segs[i].pos
		local tangent
		if i < SEGMENT_COUNT then
			tangent = segs[i + 1].pos - pos
		else
			tangent = pos - segs[i - 1].pos
		end
		local len = tangent:Length()
		local normal = Vector(0, 0)
		if len > 0.001 then
			normal = Vector(-tangent.Y / len, tangent.X / len)
		elseif segs[i].dir then
			local d = segs[i].dir
			normal = Vector(-d.Y, d.X)
		end
		local wave = math.sin(time * WAVE_SPEED - i * WAVE_PHASE) * wave_amp
		local fade = (i - 1) / (SEGMENT_COUNT - 1)
		local progress = (i - 1) / math.max(1, SEGMENT_COUNT - 1)
		local segment_reveal = math.max(0, math.min(1, (reveal - progress) * 4))
		pts[i] = {
			pos = pos + normal * (wave * fade),
			width = (WIDTH_PROFILE[i] or 0.1) * segment_reveal,
			alpha = segment_reveal,
		}
	end
	return pts
end

local function advance_bezier(ghost, rate, from_key, to_key, ctrl_key, t_key, arrive_state)
	local from = ghost[from_key]
	local to = ghost[to_key]
	local ctrl = ghost[ctrl_key] or ((from + to) * 0.5)
	ghost[t_key] = math.min(1, (ghost[t_key] or 0) + rate)
	local t = ease_out_cubic(ghost[t_key])
	local desired = bezier2(from, ctrl, to, t)
	ghost.travel_tangent = bezier2_tangent(from, ctrl, to, t)
	ghost.head_pos = ghost.head_pos + (desired - ghost.head_pos) * FOLLOW_RATE
	if ghost[t_key] >= 1 and (ghost.head_pos - to):Length() <= ARRIVE_DIST then
		ghost.head_pos = vec_copy(to)
		ghost.travel_tangent = nil
		set_state(ghost, arrive_state)
		return true
	end
	return false
end

local function advance_travel(ghost, player)
	refresh_target_anchor(ghost, player)
	ghost.travel_to = vec_copy(ghost.target_pos)
	advance_bezier(ghost, 0.07, "travel_from", "travel_to", "travel_ctrl", "travel_t", M.STATE.HOVER)
end

local function advance_entry_travel(ghost, player)
	refresh_target_anchor(ghost, player)
	ghost.travel_to = vec_copy(ghost.target_pos)
	advance_bezier(ghost, ENTRY_TRAVEL_RATE, "travel_from", "travel_to", "travel_ctrl", "travel_t", M.STATE.HOVER)
end

local function advance_return(ghost)
	advance_bezier(ghost, RETURN_TRAVEL_RATE, "return_from", "return_to", "return_ctrl", "return_t", M.STATE.SINK)
	ghost.alpha = 1
	ghost.tail_reveal = 1
end

local function hover_track(ghost, player)
	refresh_target_anchor(ghost, player)
	ghost.head_pos = ghost.head_pos + (ghost.target_pos - ghost.head_pos) * FOLLOW_RATE
	ghost.pulse = (ghost.pulse or 0) + 0.055
	ghost.travel_tangent = nil
end

local function finish_action(ghost, hooks, action)
	ghost.pending_action = nil
	if action == "extract" and hooks.on_extract then
		local result = hooks.on_extract(ghost) or {}
		if result.ok then
			set_state(ghost, M.STATE.EXTRACT)
		else
			ghost.fail_reason = result.reason
			ghost.notice = result.notice
			set_state(ghost, M.STATE.FAIL)
		end
	elseif action == "inject" and hooks.on_inject then
		local result = hooks.on_inject(ghost) or {}
		if result.ok then
			set_state(ghost, M.STATE.INJECT)
		else
			ghost.fail_reason = result.reason
			ghost.notice = result.notice
			set_state(ghost, M.STATE.FAIL)
		end
	else
		set_state(ghost, M.STATE.HOVER)
	end
end

function M.tick(ghost, player, hooks)
	if not ghost or not ghost.active then return end
	hooks = hooks or {}
	ghost.state_t = (ghost.state_t or 0) + 1
	local st = ghost.state

	if st == M.STATE.EMERGE then
		local t = math.min(1, ghost.state_t / EMERGE_FRAMES)
		local e = ease_out_cubic(t)
		ghost.alpha = e
		ghost.tail_reveal = e
		local from = ghost.emerge_from or ghost.head_pos
		local to = ghost.emerge_to or ghost.head_pos
		ghost.head_pos = from + (to - from) * e
		ghost.travel_tangent = nil
		if ghost.state_t >= EMERGE_FRAMES then
			ghost.alpha = 1
			ghost.tail_reveal = 1
			ghost.head_pos = vec_copy(to)
			begin_entry_orbit(ghost)
		end
	elseif st == M.STATE.ENTRY_ORBIT then
		ghost.alpha = 1
		ghost.tail_reveal = 1
		local frames = math.max(1, ghost.orbit_frames or 34)
		local revs = ghost.orbit_revs or 0.875
		ghost.orbit_t = (ghost.orbit_t or 0) + 1
		local u = math.min(1, ghost.orbit_t / frames)
		local start_ang = ghost.orbit_start_ang or (-math.pi * 0.5)
		local ang = start_ang + revs * math.pi * 2 * ease_out_cubic(u)
		ghost.orbit_ang = ang
		local c = ghost.orbit_center or ghost.head_pos
		ghost.head_pos = ellipse_pos(c, ang, ghost.orbit_rx or 42, ghost.orbit_ry or 14)
		ghost.travel_tangent = ellipse_tangent(ang, ghost.orbit_rx or 42, ghost.orbit_ry or 14)
		local dx = ghost.travel_tangent.X
		if math.abs(dx) > 0.05 then
			ghost.facing = dx >= 0 and 1 or -1
		end
		if ghost.orbit_t >= frames then
			if ghost.entry_mode == "orbit_return" then
				ghost.entry_orbit_done = true
				if hooks.on_entry_orbit_done then
					hooks.on_entry_orbit_done(ghost)
				end
			else
				begin_entry_travel(ghost, player)
			end
		end
	elseif st == M.STATE.ENTRY_TRAVEL then
		ghost.alpha = 1
		ghost.tail_reveal = 1
		advance_entry_travel(ghost, player)
	elseif st == M.STATE.TRAVEL then
		ghost.alpha = 1
		ghost.tail_reveal = 1
		advance_travel(ghost, player)
	elseif st == M.STATE.HOVER or st == M.STATE.IDLE then
		ghost.alpha = 1
		ghost.tail_reveal = 1
		hover_track(ghost, player)
		if st == M.STATE.IDLE then set_state(ghost, M.STATE.HOVER) end
	elseif st == M.STATE.SLASH_WINDUP then
		hover_track(ghost, player)
		ghost.slash_t = ghost.state_t
		if ghost.state_t >= SLASH_WINDUP_FRAMES then
			set_state(ghost, M.STATE.SLASH)
		end
	elseif st == M.STATE.SLASH then
		hover_track(ghost, player)
		ghost.slash_t = SLASH_WINDUP_FRAMES + ghost.state_t
		if ghost.state_t >= SLASH_FRAMES then
			finish_action(ghost, hooks, ghost.pending_action or "extract")
		end
	elseif st == M.STATE.INJECT_WINDUP then
		hover_track(ghost, player)
		ghost.inject_t = ghost.state_t
		if ghost.state_t >= INJECT_WINDUP_FRAMES then
			finish_action(ghost, hooks, "inject")
		end
	elseif st == M.STATE.EXTRACT or st == M.STATE.INJECT then
		hover_track(ghost, player)
		if st == M.STATE.INJECT then ghost.inject_t = (ghost.inject_t or 0) + 1 end
		if ghost.state_t >= ACTION_HOLD_FRAMES then
			set_state(ghost, M.STATE.HOVER)
		end
	elseif st == M.STATE.FAIL then
		hover_track(ghost, player)
		if ghost.state_t >= FAIL_FRAMES then
			ghost.fail_reason = nil
			ghost.notice = nil
			set_state(ghost, M.STATE.HOVER)
		end
	elseif st == M.STATE.RETURN then
		advance_return(ghost)
	elseif st == M.STATE.SINK then
		local t = math.min(1, ghost.state_t / SINK_FRAMES)
		local e = ease_out_cubic(t)
		local from = ghost.return_to or ghost.head_pos
		local sink_to = from + Vector(0, EMERGE_DEPTH + EMERGE_HEIGHT)
		ghost.head_pos = from + (sink_to - from) * e
		ghost.tail_reveal = 1 - e
		ghost.alpha = 1 - e
		ghost.travel_tangent = nil
		if ghost.state_t >= SINK_FRAMES then
			ghost.active = false
			ghost.alpha = 0
			ghost.tail_reveal = 0
			if hooks.on_exit_done then hooks.on_exit_done(ghost) end
		end
	end

	update_soft_body(ghost)
end

function M.get_debug_info(ghost)
	if not ghost then return nil end
	return {
		state = ghost.state,
		node = ghost.target_node,
		head = ghost.head_pos and string.format("%.0f,%.0f", ghost.head_pos.X, ghost.head_pos.Y) or nil,
		target = ghost.target_pos and string.format("%.0f,%.0f", ghost.target_pos.X, ghost.target_pos.Y) or nil,
		alpha = ghost.alpha,
		tail_reveal = ghost.tail_reveal,
		coil = ghost.coil,
		path_len = ghost.path_history and #ghost.path_history or 0,
		segments = ghost.segments,
	}
end

M.SEGMENT_COUNT = SEGMENT_COUNT
M.SEGMENT_LENGTH = SEGMENT_LENGTH
M.WIDTH_PROFILE = WIDTH_PROFILE
M.EMERGE_FRAMES = EMERGE_FRAMES
M.EMERGE_DEPTH = EMERGE_DEPTH
M.EMERGE_HEIGHT = EMERGE_HEIGHT

return M
