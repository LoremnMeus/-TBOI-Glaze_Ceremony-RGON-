-- 妖刀天使节点：Deal 分配重塑器（纯试探 + 目标求解）。
-- 只改转化 modifier x；总 Deal T 不动；不涉及灵质。
-- 不调用 AddAngelRoomChance；执行层由 Item 消费 find_angel_target 结果。

local deal_chance_semantics = require("Qing_Remaster_scripts.auxiliary.deal_chance_semantics")

local M = {}

local DEAL_STEP = 0.05
local DEAL_MOD_MIN = -1.0
local DEAL_MOD_MAX = 1.0
-- 显示匹配：必须落到目标刻度，禁止 0.0015 级“差不多”。
local DISPLAY_MATCH = 5e-7
local PLATEAU_EPS = 5e-5
local SCAN_STEPS = 256

local function abs(v)
	return v < 0 and -v or v
end

local function read_actual_x()
	local level = Game():GetLevel()
	if level and level.GetAngelRoomChance then
		return tonumber(level:GetAngelRoomChance()) or 0
	end
	return 0
end

--- bounds: {x_lo, x_hi, actual_x, external_x, sword_x}
function M.x_bounds(applied_sword_x, player_sword_x)
	local actual = read_actual_x()
	applied_sword_x = tonumber(applied_sword_x) or 0
	player_sword_x = tonumber(player_sword_x)
	if player_sword_x == nil then
		player_sword_x = applied_sword_x
	end
	local external = actual - applied_sword_x
	-- 本玩家 sword 可在 [DEAL_MOD_MIN, DEAL_MOD_MAX] 内移动；总 x = external + 全员 sword。
	-- 单玩家时：x ∈ [external+MIN, external+MAX]。
	local others = applied_sword_x - player_sword_x
	local x_lo = external + others + DEAL_MOD_MIN
	local x_hi = external + others + DEAL_MOD_MAX
	if x_lo > x_hi then
		x_lo, x_hi = x_hi, x_lo
	end
	return {
		x_lo = x_lo,
		x_hi = x_hi,
		actual_x = actual,
		external_x = external,
		sword_x = player_sword_x,
		applied_sword_x = applied_sword_x,
	}
end

function M.evaluate_angel_display_at(x)
	return deal_chance_semantics.evaluate_angel_display_at(x, {allow_getter_fallback = true})
end

local function desired_display(direction, current_angel, total)
	direction = direction >= 0 and 1 or -1
	current_angel = tonumber(current_angel) or 0
	total = tonumber(total) or 0
	if direction > 0 then
		local room = total - current_angel
		if room <= 1e-12 then
			return nil
		end
		if room < DEAL_STEP - 1e-12 then
			return total
		end
		return current_angel + DEAL_STEP
	end
	if current_angel <= 1e-12 then
		return nil
	end
	if current_angel < DEAL_STEP - 1e-12 then
		return 0
	end
	return current_angel - DEAL_STEP
end

--- 在 [x_lo, x_hi] 上扫描可达 Angel 显示；返回样本与极值。
local function scan_range(x_lo, x_hi)
	local samples = {}
	local n = SCAN_STEPS
	local span = x_hi - x_lo
	if abs(span) < 1e-15 then
		local ev = M.evaluate_angel_display_at(x_lo)
		samples[1] = {x = x_lo, angel = ev.angel, total = ev.total, devil = ev.devil}
		return samples, ev.angel, ev.angel, x_lo, x_lo
	end
	local amin, amax = 1e9, -1e9
	local xmin, xmax = x_lo, x_hi
	for i = 0, n do
		local x = x_lo + span * (i / n)
		local ev = M.evaluate_angel_display_at(x)
		local a = ev.angel
		samples[#samples + 1] = {x = x, angel = a, total = ev.total, devil = ev.devil}
		if a < amin then
			amin = a
			xmin = x
		end
		if a > amax then
			amax = a
			xmax = x
		end
	end
	return samples, amin, amax, xmin, xmax
end

--- 连续段内线性反解 x，使 display.angel ≈ target。
--- 仅当两端之间单调且无大跳时接受。
function M.solve_angel_x_for_display(target, x_lo, x_hi)
	target = tonumber(target)
	if target == nil then
		return nil
	end
	x_lo = tonumber(x_lo)
	x_hi = tonumber(x_hi)
	if x_lo == nil or x_hi == nil then
		return nil
	end
	if x_lo > x_hi then
		x_lo, x_hi = x_hi, x_lo
	end

	local ev_lo = M.evaluate_angel_display_at(x_lo)
	local ev_hi = M.evaluate_angel_display_at(x_hi)
	local a_lo, a_hi = ev_lo.angel, ev_hi.angel

	if abs(a_lo - target) <= DISPLAY_MATCH then
		return {x = x_lo, angel = a_lo, kind = "exact"}
	end
	if abs(a_hi - target) <= DISPLAY_MATCH then
		return {x = x_hi, angel = a_hi, kind = "exact"}
	end

	local amin = a_lo < a_hi and a_lo or a_hi
	local amax = a_lo > a_hi and a_lo or a_hi
	if target < amin - DISPLAY_MATCH or target > amax + DISPLAY_MATCH then
		return nil
	end

	-- 若区间内存在跳变，缩小到包含 target 的单调子段（用中点探测）。
	local lo, hi = x_lo, x_hi
	local alo, ahi = a_lo, a_hi
	for _ = 1, 48 do
		local mid = (lo + hi) * 0.5
		local am = M.evaluate_angel_display_at(mid).angel
		if abs(am - target) <= DISPLAY_MATCH then
			return {x = mid, angel = am, kind = "exact"}
		end
		-- 选择仍夹住 target 的一侧；若两侧都夹，取更接近线性的半侧。
		local left_min = alo < am and alo or am
		local left_max = alo > am and alo or am
		local right_min = am < ahi and am or ahi
		local right_max = am > ahi and am or ahi
		local in_left = target >= left_min - DISPLAY_MATCH and target <= left_max + DISPLAY_MATCH
		local in_right = target >= right_min - DISPLAY_MATCH and target <= right_max + DISPLAY_MATCH
		if in_left and not in_right then
			hi, ahi = mid, am
		elseif in_right and not in_left then
			lo, alo = mid, am
		elseif in_left and in_right then
			-- 两边都可达：优先向 target 与端点差值更小的方向（连续区）。
			local err_l = abs(((alo + am) * 0.5) - target)
			local err_r = abs(((am + ahi) * 0.5) - target)
			if err_l <= err_r then
				hi, ahi = mid, am
			else
				lo, alo = mid, am
			end
		else
			return nil
		end
	end

	local x = (lo + hi) * 0.5
	local got = M.evaluate_angel_display_at(x).angel
	if abs(got - target) <= DISPLAY_MATCH then
		return {x = x, angel = got, kind = "exact"}
	end
	-- 连续线性区：用端点插值再验证。
	if abs(ahi - alo) > 1e-15 then
		local t = (target - alo) / (ahi - alo)
		if t >= -1e-9 and t <= 1 + 1e-9 then
			t = math.max(0, math.min(1, t))
			x = lo + (hi - lo) * t
			got = M.evaluate_angel_display_at(x).angel
			if abs(got - target) <= DISPLAY_MATCH then
				return {x = x, angel = got, kind = "exact"}
			end
		end
	end
	return nil
end

--- 沿 direction 找下一个与 current 不同的可达平台（状态跳变）。
local function find_jump_target(direction, current_angel, samples)
	direction = direction >= 0 and 1 or -1
	local best_a = nil
	local best_x = nil
	local best_dist = 1e9
	for _, s in ipairs(samples) do
		local da = s.angel - current_angel
		if direction > 0 and da > PLATEAU_EPS then
			local dist = da
			-- 取沿方向最近的不同平台（最小正增量）。
			if dist < best_dist - 1e-12
				or (abs(dist - best_dist) <= 1e-12 and best_x ~= nil and abs(s.x) < abs(best_x))
			then
				best_dist = dist
				best_a = s.angel
				best_x = s.x
			end
		elseif direction < 0 and da < -PLATEAU_EPS then
			local dist = -da
			if dist < best_dist - 1e-12
				or (abs(dist - best_dist) <= 1e-12 and best_x ~= nil and abs(s.x) < abs(best_x))
			then
				best_dist = dist
				best_a = s.angel
				best_x = s.x
			end
		end
	end
	if best_a == nil then
		return nil
	end
	-- 同一平台上取使 |Δx| 最小的样本 x（再扫一次）。
	local plat = best_a
	local pick_x = best_x
	local pick_dx = 1e9
	local actual = read_actual_x()
	for _, s in ipairs(samples) do
		if abs(s.angel - plat) <= PLATEAU_EPS then
			local dx = abs(s.x - actual)
			if dx < pick_dx then
				pick_dx = dx
				pick_x = s.x
			end
		end
	end
	return {angel = plat, x = pick_x}
end

--- 按 x 扫描序切分可达 Angel 显示区间（相邻样本跳变 → 新区间）。
local function build_angel_intervals(samples)
	if not samples or #samples == 0 then
		return {}
	end
	local jump_eps = math.max(PLATEAU_EPS * 20, 0.01)
	local intervals = {}
	local run_lo = samples[1].angel
	local run_hi = samples[1].angel
	local run_x_at_lo = samples[1].x
	local run_x_at_hi = samples[1].x
	local function close_run()
		intervals[#intervals + 1] = {
			lo = run_lo,
			hi = run_hi,
			x_at_lo = run_x_at_lo,
			x_at_hi = run_x_at_hi,
		}
	end
	for i = 2, #samples do
		local a = samples[i].angel
		local prev = samples[i - 1].angel
		if abs(a - prev) > jump_eps then
			close_run()
			run_lo, run_hi = a, a
			run_x_at_lo, run_x_at_hi = samples[i].x, samples[i].x
		else
			if a < run_lo then
				run_lo = a
				run_x_at_lo = samples[i].x
			end
			if a > run_hi then
				run_hi = a
				run_x_at_hi = samples[i].x
			end
		end
	end
	close_run()
	table.sort(intervals, function(a, b)
		return a.lo < b.lo
	end)
	return intervals
end

local function interval_containing(intervals, angel)
	for _, iv in ipairs(intervals) do
		if angel >= iv.lo - PLATEAU_EPS and angel <= iv.hi + PLATEAU_EPS then
			return iv
		end
	end
	return nil
end

--- want 落在当前连续段外侧 gap：直接取断层另一侧下一可达段，不停在本段边缘。
local function find_gap_cross_target(direction, want, current_angel, samples)
	local intervals = build_angel_intervals(samples)
	if #intervals == 0 then
		return nil
	end
	local cur_iv = interval_containing(intervals, current_angel)
	if not cur_iv then
		return nil
	end
	direction = direction >= 0 and 1 or -1
	if direction < 0 then
		if want >= cur_iv.lo - PLATEAU_EPS then
			return nil
		end
		-- 当前段下方：取 lo 最大且仍低于本段的区间（紧邻的下一档）
		local best = nil
		for _, iv in ipairs(intervals) do
			if iv.hi < cur_iv.lo - PLATEAU_EPS then
				if not best or iv.hi > best.hi then
					best = iv
				end
			end
		end
		if not best then
			return nil
		end
		-- 降方向：落到该段上沿（通常是单点 0 或连续段顶端）
		return {angel = best.hi, x = best.x_at_hi}
	end
	if want <= cur_iv.hi + PLATEAU_EPS then
		return nil
	end
	local best = nil
	for _, iv in ipairs(intervals) do
		if iv.lo > cur_iv.hi + PLATEAU_EPS then
			if not best or iv.lo < best.lo then
				best = iv
			end
		end
	end
	if not best then
		return nil
	end
	return {angel = best.lo, x = best.x_at_lo}
end

--- direction: +1 = 提高 Angel（E/inject），-1 = 降低（Q/extract）
--- opts: {applied_sword_x=, player_sword_x=}
--- 返回 {kind="exact"|"jump"|"blocked", current=, target=, target_x=, total=, ...}
function M.find_angel_target(direction, opts)
	opts = opts or {}
	direction = (tonumber(direction) or 0) >= 0 and 1 or -1
	local bounds = M.x_bounds(opts.applied_sword_x, opts.player_sword_x)
	local cur = M.evaluate_angel_display_at(bounds.actual_x)
	local blocked = {
		kind = "blocked",
		current = cur.angel,
		target = cur.angel,
		target_x = bounds.actual_x,
		total = cur.total,
		devil = cur.devil,
		x_lo = bounds.x_lo,
		x_hi = bounds.x_hi,
	}

	if not cur.eligible then
		return blocked
	end
	local T = cur.total
	local A0 = cur.angel
	if T <= 1e-12 then
		return blocked
	end

	local samples, amin, amax = scan_range(bounds.x_lo, bounds.x_hi)
	if (amax - amin) <= PLATEAU_EPS then
		return blocked
	end

	local want = desired_display(direction, A0, T)
	if want == nil then
		return blocked
	end

	-- 扫描命中：优先用样本上已达目标的 x（再局部精炼）。
	local hit_x, hit_err = nil, 1e9
	for _, s in ipairs(samples) do
		local e = abs(s.angel - want)
		if e < hit_err then
			hit_err = e
			hit_x = s.x
		end
	end
	if hit_x ~= nil and hit_err <= DISPLAY_MATCH then
		return {
			kind = "exact",
			current = A0,
			target = want,
			target_x = hit_x,
			total = T,
			devil = T - want,
			x_lo = bounds.x_lo,
			x_hi = bounds.x_hi,
		}
	end

	-- 1) 连续反解目标 → exact
	local refine_lo = bounds.x_lo
	local refine_hi = bounds.x_hi
	if hit_x ~= nil then
		local span = (bounds.x_hi - bounds.x_lo) / SCAN_STEPS
		refine_lo = math.max(bounds.x_lo, hit_x - span * 2)
		refine_hi = math.min(bounds.x_hi, hit_x + span * 2)
	end
	local solved = M.solve_angel_x_for_display(want, refine_lo, refine_hi)
	if not solved then
		solved = M.solve_angel_x_for_display(want, bounds.x_lo, bounds.x_hi)
	end
	if solved and abs(solved.angel - want) <= DISPLAY_MATCH then
		return {
			kind = "exact",
			current = A0,
			target = want,
			target_x = solved.x,
			total = T,
			devil = T - want,
			x_lo = bounds.x_lo,
			x_hi = bounds.x_hi,
		}
	end

	-- 2) 目标落入 gap：跨断层到另一侧可达段（如 52.5→0，而非 52.5→50）
	local gap = find_gap_cross_target(direction, want, A0, samples)
	if gap then
		return {
			kind = "jump",
			current = A0,
			target = gap.angel,
			target_x = gap.x,
			total = T,
			devil = T - gap.angel,
			x_lo = bounds.x_lo,
			x_hi = bounds.x_hi,
			gap_cross = true,
		}
	end

	-- 3) 普通方向跳变（下一不同平台）
	local jump = find_jump_target(direction, A0, samples)
	if jump then
		return {
			kind = "jump",
			current = A0,
			target = jump.angel,
			target_x = jump.x,
			total = T,
			devil = T - jump.angel,
			x_lo = bounds.x_lo,
			x_hi = bounds.x_hi,
		}
	end

	return blocked
end

function M.can_adjust(direction, opts)
	local plan = M.find_angel_target(direction, opts)
	return plan.kind ~= "blocked", plan
end

--- 由目标总 x 与 external，得到本玩家新的 sword 贡献（钳制到 mod 范围）。
function M.sword_delta_for_target_x(target_x, external_x, others_sword_x, player_sword_x)
	target_x = tonumber(target_x) or 0
	external_x = tonumber(external_x) or 0
	others_sword_x = tonumber(others_sword_x) or 0
	player_sword_x = tonumber(player_sword_x) or 0
	local new_sword = target_x - external_x - others_sword_x
	new_sword = math.max(DEAL_MOD_MIN, math.min(DEAL_MOD_MAX, new_sword))
	return new_sword, new_sword - player_sword_x
end

M.DEAL_STEP = DEAL_STEP
M.DISPLAY_MATCH = DISPLAY_MATCH

return M
