-- 原版道具的确定性 TearParams 外观数据（来自局内 v3 独立基线审计）。
-- TearScale 会随最终伤害自动变化，禁止在这里固化。
local M = {}

-- 后出现的项目优先，作为多道具配方的稳定降级规则。
local VARIANT_ORDER = {
	{7, TearVariant.BLOOD}, {48, TearVariant.CUPID_BLUE}, {80, TearVariant.BLOOD},
	{90, TearVariant.BLOOD}, {138, TearVariant.BLOOD}, {183, TearVariant.BLOOD},
	{213, TearVariant.LOST_CONTACT}, {229, TearVariant.BLOOD}, {230, TearVariant.BLOOD},
	{237, TearVariant.SCHYTHE}, {306, TearVariant.CUPID_BLUE}, {315, TearVariant.METALLIC},
	{359, TearVariant.NAIL}, {379, TearVariant.PUPULA}, {399, TearVariant.BLOOD},
	{429, TearVariant.COIN}, {440, TearVariant.BLOOD}, {453, TearVariant.BONE},
	{462, TearVariant.BLOOD}, {529, TearVariant.EYE}, {531, TearVariant.BALLOON},
	{532, TearVariant.HUNGRY}, {592, TearVariant.ROCK}, {596, TearVariant.ICE},
}

-- 相对普通蓝泪 -23.75 的高度差；叠到 Air Flight 的 PositionOffset 高度上。
local HEIGHT_ORDER = {
	{6, 18}, {440, 18}, {572, -8}, {594, -8}, {598, 14.25},
}

-- FireTear 局内抽样（tear_falling_audit_v1）：TearParams 不含下落物理。
-- accel/speed 为单件持有时的绝对实体值；后出现的优先。
local FALLING_ORDER = {
	{149, accel = 0.512, speed = -8.0}, -- Ipecac
	{531, accel = 0.8, speed = -8.9}, -- Haemolacria
}

-- 原版默认 Height；stats.range 用内部单位（显示射程 ×40，默认 260）。
local BASE_HEIGHT = -23.75
local BASE_RANGE = 260
-- FireTear / 飞行器 dir 约定：速度 ≈ ShotSpeed × 10。
local TEAR_SPEED_PER_SHOTSPEED = 10

local function has(counts, id)
	return (tonumber(counts and counts[id]) or 0) > 0
end

local function has_hydrobounce(flags)
	local flag = TearFlags and TearFlags.TEAR_HYDROBOUNCE
	if not flag or flags == nil then return false end
	return (flags & flag) == flag
end

--- 按目标水平射程反推 Falling*（FS0=0 的欧拉积分：H_n = H0 + FA·n(n+1)/2）。
--- 与 Repentance「射程按格数、弹速升高则下落加快」一致：n = range / tear_speed。
--- opts.min_fa / opts.max_fa：可选钳制。默认 min_fa=0.02（Craft / 求索者之眼既有行为）。
--- 长射程调用方可传更低 min_fa；须保持 FA > 0.001 以免切换 height2offset 视觉分支
--- （见 tear_vertical_control_rules.md）。第三返回值为 {raw_fa, clamped, min_fa, max_fa}。
function M.falling_for_range(height, range, shotspeed, tear_speed, opts)
	opts = type(opts) == "table" and opts or nil
	height = tonumber(height) or BASE_HEIGHT
	if height > -1 then height = BASE_HEIGHT end
	range = math.max(20, tonumber(range) or BASE_RANGE)
	local speed = tonumber(tear_speed)
	if not speed or speed < 0.5 then
		speed = TEAR_SPEED_PER_SHOTSPEED * math.max(0.1, tonumber(shotspeed) or 1)
	end
	local n = range / speed
	if n < 1 then n = 1 end
	local fa_raw = -2 * height / (n * (n + 1))
	local min_fa = 0.02
	local max_fa = 2
	if opts then
		if opts.min_fa ~= nil then min_fa = tonumber(opts.min_fa) or min_fa end
		if opts.max_fa ~= nil then max_fa = tonumber(opts.max_fa) or max_fa end
	end
	local fa = fa_raw
	local clamped = false
	if fa < min_fa then
		fa = min_fa
		clamped = true
	end
	if fa > max_fa then
		fa = max_fa
		clamped = true
	end
	return fa, 0, {
		raw_fa = fa_raw,
		applied_fa = fa,
		clamped = clamped,
		min_fa = min_fa,
		max_fa = max_fa,
		n = n,
		speed = speed,
		range = range,
	}
end

-- Probe Tear Lifecycle v4 fit (codex_work/notes/tear_vanilla_fs_range_model.md). Approximate only.
local VANILLA_FS_A = 0.9000
local VANILLA_FS_B = 0.9642
local VANILLA_FS_C = 0.1002
local VANILLA_LAND_H = -1.0
local VANILLA_FS_LO = -28
local VANILLA_FS_HI = 6
local VANILLA_BIN_ITERS = 28

local function resolve_tear_speed(shotspeed, tear_speed)
	local speed = tonumber(tear_speed)
	if not speed or speed < 0.5 then
		speed = TEAR_SPEED_PER_SHOTSPEED * math.max(0.1, tonumber(shotspeed) or 1)
	end
	return speed
end

--- Simulate land frame under measured FS update + H += FS_next (FA usually 0).
local function vanilla_land_frames(h0, fs0, fa, max_frames)
	local h = h0
	local fs = fs0
	fa = fa or 0
	for t = 1, max_frames do
		fs = VANILLA_FS_A * fs + VANILLA_FS_B * fa + VANILLA_FS_C
		h = h + fs
		if h > VANILLA_LAND_H then
			return t, h, fs
		end
	end
	return nil, h, fs
end

--- 原版式射程：FA=0，按目标飞行帧数 N≈range/|Velocity| 反推实体初始 FallingSpeed。
--- 不修改 falling_for_range()；仅供显式调用方（当前：罗喉 configure_rahu_tear）。
--- 返回：fa(=0), fs0, meta。meta.status = ok | clamped_fs | unsolvable | bad_input
function M.falling_for_range_vanilla(height, range, shotspeed, tear_speed, opts)
	opts = type(opts) == "table" and opts or nil
	height = tonumber(height) or BASE_HEIGHT
	if height > -1 then height = BASE_HEIGHT end
	range = math.max(20, tonumber(range) or BASE_RANGE)
	local speed = resolve_tear_speed(shotspeed, tear_speed)
	local n_target = range / speed
	if n_target < 1 then n_target = 1 end
	n_target = math.floor(n_target + 0.5)
	local fa = 0
	if opts and opts.fa ~= nil then
		fa = tonumber(opts.fa) or 0
	end
	local fs_lo = VANILLA_FS_LO
	local fs_hi = VANILLA_FS_HI
	if opts then
		if opts.fs_lo ~= nil then fs_lo = tonumber(opts.fs_lo) or fs_lo end
		if opts.fs_hi ~= nil then fs_hi = tonumber(opts.fs_hi) or fs_hi end
	end
	local max_frames = math.max(n_target + 30, math.floor(n_target * 2 + 0.5), 60)
	if opts and opts.max_frames ~= nil then
		max_frames = math.max(8, math.floor(tonumber(opts.max_frames) or max_frames))
	end

	local function land_at(fs0)
		return vanilla_land_frames(height, fs0, fa, max_frames)
	end

	local land_lo = land_at(fs_lo)
	local land_hi = land_at(fs_hi)
	-- More negative FS → longer air time (land_lo should be >= land_hi when both land).
	if land_lo == nil and land_hi == nil then
		return fa, fs_lo, {
			mode = "vanilla_fs",
			status = "unsolvable",
			reason = "never_lands_in_window",
			height = height,
			fa = fa,
			fs = fs_lo,
			n_target = n_target,
			speed = speed,
			range = range,
			max_frames = max_frames,
			model = {a = VANILLA_FS_A, b = VANILLA_FS_B, c = VANILLA_FS_C},
		}
	end

	local lo, hi = fs_lo, fs_hi
	-- Want land_frames ≈ n_target. If fs more negative → larger land_frames.
	for _ = 1, VANILLA_BIN_ITERS do
		local mid = (lo + hi) * 0.5
		local land_mid = land_at(mid)
		if land_mid == nil then
			-- Too much hang time / never lands → mid too negative → raise FS (less hang).
			lo = mid
		elseif land_mid > n_target then
			lo = mid
		else
			hi = mid
		end
	end
	local fs0 = (lo + hi) * 0.5
	local land_n, land_h, land_fs = land_at(fs0)
	local status = "ok"
	local clamped = false
	if land_n == nil then
		status = "unsolvable"
		fs0 = fs_hi
		land_n, land_h, land_fs = land_at(fs0)
	elseif math.abs(fs0 - fs_lo) < 1e-4 or math.abs(fs0 - fs_hi) < 1e-4 then
		status = "clamped_fs"
		clamped = true
	end
	if land_n and math.abs(land_n - n_target) > math.max(3, n_target * 0.15) then
		status = clamped and "clamped_fs" or "approx"
	end

	return fa, fs0, {
		mode = "vanilla_fs",
		status = status,
		clamped = clamped,
		height = height,
		fa = fa,
		fs = fs0,
		applied_fa = fa,
		applied_fs = fs0,
		n_target = n_target,
		predicted_land_frames = land_n,
		predicted_land_height = land_h,
		predicted_land_fs = land_fs,
		speed = speed,
		range = range,
		max_frames = max_frames,
		model = {a = VANILLA_FS_A, b = VANILLA_FS_B, c = VANILLA_FS_C, land_h = VANILLA_LAND_H},
		note = "Fit coefficients from Tear Lifecycle v4; Height integrate residual exists.",
	}
end

--- 碰撞后延长飞行：保留当前 Height / FallingAcceleration，只反算新的 FallingSpeed。
--- 与 falling_for_range_vanilla 不同：不会把接近地面的 Height 回退到 BASE_HEIGHT。
--- bonus_frames：希望在「当前剩余落地帧」之上再增加的逻辑帧数（30Hz 泪弹 Update）。
--- 返回：applied_fs, meta（含 remaining、target、status）。
function M.extend_flight(tear, bonus_frames, opts)
	opts = type(opts) == "table" and opts or nil
	if not tear then
		return nil, {status = "bad_input", reason = "nil_tear"}
	end
	local height = tonumber(tear.Height)
	local fs = tonumber(tear.FallingSpeed)
	local fa = tonumber(tear.FallingAcceleration) or 0
	if height == nil or fs == nil then
		return nil, {status = "bad_input", reason = "missing_vertical"}
	end
	bonus_frames = math.max(0, math.floor(tonumber(bonus_frames) or 0))
	if bonus_frames <= 0 then
		return fs, {
			status = "noop",
			height = height,
			fa = fa,
			fs = fs,
			bonus_frames = 0,
			remaining = nil,
		}
	end

	local fs_lo = VANILLA_FS_LO
	local fs_hi = VANILLA_FS_HI
	local max_frames = 180
	if opts then
		if opts.fs_lo ~= nil then fs_lo = tonumber(opts.fs_lo) or fs_lo end
		if opts.fs_hi ~= nil then fs_hi = tonumber(opts.fs_hi) or fs_hi end
		if opts.max_frames ~= nil then
			max_frames = math.max(8, math.floor(tonumber(opts.max_frames) or max_frames))
		end
	end

	local remaining = vanilla_land_frames(height, fs, fa, max_frames)
	if remaining == nil then
		-- 当前轨迹在窗口内落不下来：仍尝试把目标定为 max_frames（更负的 FS 通常更久）。
		remaining = max_frames
	end
	local n_target = remaining + bonus_frames
	max_frames = math.max(max_frames, n_target + 30, math.floor(n_target * 2 + 0.5))

	local function land_at(fs0)
		return vanilla_land_frames(height, fs0, fa, max_frames)
	end

	local lo, hi = fs_lo, fs_hi
	for _ = 1, VANILLA_BIN_ITERS do
		local mid = (lo + hi) * 0.5
		local land_mid = land_at(mid)
		if land_mid == nil then
			lo = mid
		elseif land_mid > n_target then
			lo = mid
		else
			hi = mid
		end
	end
	local fs0 = (lo + hi) * 0.5
	local land_n, land_h, land_fs = land_at(fs0)
	local status = "ok"
	local clamped = false
	if land_n == nil then
		status = "unsolvable"
		fs0 = fs_lo
		land_n, land_h, land_fs = land_at(fs0)
	elseif math.abs(fs0 - fs_lo) < 1e-4 or math.abs(fs0 - fs_hi) < 1e-4 then
		status = "clamped_fs"
		clamped = true
	end

	tear.FallingSpeed = fs0
	return fs0, {
		mode = "extend_flight",
		status = status,
		clamped = clamped,
		height = height,
		fa = fa,
		fs_before = fs,
		fs = fs0,
		applied_fs = fs0,
		bonus_frames = bonus_frames,
		remaining = remaining,
		n_target = n_target,
		predicted_land_frames = land_n,
		predicted_land_height = land_h,
		predicted_land_fs = land_fs,
		max_frames = max_frames,
		model = {a = VANILLA_FS_A, b = VANILLA_FS_B, c = VANILLA_FS_C, land_h = VANILLA_LAND_H},
		note = "Mid-flight FS solve; Height/FA unchanged. Fit from Tear Lifecycle v4.",
	}
end

function M.apply(ent, counts, flags, effects, opts)
	if not ent or not ent.ToTear then return end
	local tear = ent:ToTear()
	if not tear then return end
	opts = opts or {}
	-- C Section 胎儿仍是 EntityTear：下落/高度要脱钩玩家，但绝不能 ChangeVariant。
	local is_fetus = TearVariant.FETUS and tear.Variant == TearVariant.FETUS

	local height_delta = nil
	for _, rec in ipairs(HEIGHT_ORDER) do
		if has(counts, rec[1]) then height_delta = rec[2] end
	end
	if opts.parasitoid then height_delta = -23.75 end

	local fall = nil
	for _, rec in ipairs(FALLING_ORDER) do
		-- 剖腹产胎儿：不吃血泪 Falling*（保持胎儿轨，落地再自模拟爆发）
		if has(counts, rec[1]) and not (is_fetus and rec[1] == 531) then
			fall = rec
		end
	end
	local hydro = has_hydrobounce(flags)
	local height_delta_applied = false
	-- 自管环绕泪（土星/无暇）：FA=-0.1 悬浮；Height 必须按同一 FA 换算，禁止先按 FA>0 写 Height 再改 FA。
	if opts.suspend_fall then
		tear.FallingAcceleration = -0.1
		tear.FallingSpeed = 0
		local base_h = BASE_HEIGHT
		if opts.set_base_height then
			local h = opts.set_base_height(tear.FallingAcceleration)
			if h ~= nil then base_h = h end
		end
		tear.Height = base_h + (height_delta or 0)
		if tear.PositionOffset ~= nil then
			tear.PositionOffset = Vector(0, 0)
		end
		height_delta_applied = true
	-- 扁石（HYDROBOUNCE）：必须保留可触地的下落，禁止写成近零 Falling*。
	-- 仅首帧设 Height；后续弹跳交引擎，勿每帧再改 Falling/PO（见 Craft_Familiar_holder）。
	elseif hydro then
		if fall then
			tear.FallingAcceleration = fall.accel or 0.5
			tear.FallingSpeed = fall.speed or 0
		else
			-- 默认给一点下落，否则飞行器高度的泪弹几乎落不下来
			if not tear.FallingAcceleration or math.abs(tear.FallingAcceleration) < 0.05 then
				tear.FallingAcceleration = 0.5
			end
		end
		-- 先落到正确 FallingAcceleration，再算 Height（offset2height 分支依赖 accel）。
		if opts.set_base_height then
			local h = opts.set_base_height(tear.FallingAcceleration)
			if h ~= nil then tear.Height = h end
		end
	elseif fall then
		tear.FallingAcceleration = fall.accel or 0
		tear.FallingSpeed = fall.speed or 0
		if opts.set_base_height then
			local h = opts.set_base_height(tear.FallingAcceleration)
			if h ~= nil then tear.Height = h end
		end
	else
		-- 脱钩玩家 TearFalling*：用制造档案 range（缺省按基础 260）反推下落。
		-- 旧写法 FA=0/FS=0.3 会让飞行器高度泪几乎不落地，表现为「射穿整个房间」。
		-- 用 accel>0 采样 set_base_height，使 Flight 走 Offset.Y 直映分支。
		local base_h = BASE_HEIGHT
		if opts.set_base_height then
			local h = opts.set_base_height(1)
			if h ~= nil then base_h = h end
		elseif tear.Height ~= nil then
			base_h = tear.Height
		end
		local final_h = base_h + (height_delta or 0)
		local tear_speed = tear.Velocity and tear.Velocity:Length() or nil
		local fa, fs = M.falling_for_range(final_h, opts.range, opts.shotspeed, tear_speed)
		tear.FallingAcceleration = fa
		tear.FallingSpeed = fs
		tear.Height = final_h
		height_delta_applied = true
	end
	if is_fetus then return end

	local variant = nil
	for _, rec in ipairs(VARIANT_ORDER) do
		if has(counts, rec[1]) then variant = rec[2] end
	end
	-- 概率外观复用本颗泪已经投出的结果，禁止另投一次。
	local sticky = effects and effects[401] and effects[401].flag
	if has(counts, 401) and sticky and flags and (flags & sticky) == sticky then
		variant = TearVariant.EXPLOSIVO
	end
	local conditional_variants = {
		{398, TearVariant.GODS_FLESH}, {459, TearVariant.BOOGER},
		{460, TearVariant.GLAUCOMA}, {496, TearVariant.NEEDLE},
		{553, TearVariant.SPORE}, {637, TearVariant.FIST},
	}
	for _, rec in ipairs(conditional_variants) do
		local effect = effects and effects[rec[1]]
		local flag = effect and effect.flag
		if has(counts, rec[1]) and flag and flags and (flags & flag) == flag then
			variant = rec[2]
		end
	end
	-- Chemical Peel / Peeper / Blood Clot / Lead Pencil 的血泪只属于对应眼睛或概率外观，静态 GetTearHitParams 审计无法捕获。
	if opts.force_blood_variant then variant = TearVariant.BLOOD end
	-- Tough Love：概率牙齿泪（非 TearFlag）。血泪气球等保留伤害倍率、不换外观。
	if opts.tough_love and TearVariant.TOOTH then
		local skip_look = (TearVariant.BALLOON and tear.Variant == TearVariant.BALLOON)
			or (TearVariant.BALLOON_BOMB and tear.Variant == TearVariant.BALLOON_BOMB)
			or (TearVariant.BALLOON_BRIMSTONE and tear.Variant == TearVariant.BALLOON_BRIMSTONE)
			or (variant == TearVariant.BALLOON)
			or (variant == TearVariant.BALLOON_BOMB)
			or (variant == TearVariant.BALLOON_BRIMSTONE)
			or has(counts, 531)
		if not skip_look then
			variant = TearVariant.TOOTH
		end
	end
	-- Apple!：概率刀片泪（非 TearFlag）；优先于血泪/牙齿外观。
	if opts.apple and TearVariant.RAZOR then
		local skip_look = (TearVariant.BALLOON and tear.Variant == TearVariant.BALLOON)
			or (TearVariant.BALLOON_BOMB and tear.Variant == TearVariant.BALLOON_BOMB)
			or (TearVariant.BALLOON_BRIMSTONE and tear.Variant == TearVariant.BALLOON_BRIMSTONE)
			or (variant == TearVariant.BALLOON)
			or (variant == TearVariant.BALLOON_BOMB)
			or (variant == TearVariant.BALLOON_BRIMSTONE)
			or has(counts, 531)
		if not skip_look then
			variant = TearVariant.RAZOR
		end
	end
	-- 血泪主泪贴图：普通 BALLOON；博士 BALLOON_BOMB；硫磺/科技/科技X 均用 BALLOON_BRIMSTONE
	-- shared（多 guest）：博士优先炸弹气球，否则有硫磺/科技/科技X 用硫磺气球
	if has(counts, 531) and not opts.force_variant then
		local mode = opts.haemo_burst_mode
		local shared = mode == "shared" or mode == "mixed" or mode == "multi"
		if (mode == "bombs" or (shared and has(counts, 168))) and TearVariant.BALLOON_BOMB then
			variant = TearVariant.BALLOON_BOMB
		elseif (mode == "brim" or mode == "tech" or mode == "techx"
			or (shared and (has(counts, 118) or has(counts, 68) or has(counts, 395))))
			and TearVariant.BALLOON_BRIMSTONE then
			variant = TearVariant.BALLOON_BRIMSTONE
		else
			-- tears / knife 回退：普通气球
			variant = TearVariant.BALLOON
		end
	end
	-- 概率形态应覆盖普通单眼外观，否则会让拟寄生物等已触发效果丢失实体类型。
	-- force_variant（剑泪血泪等）优先于拟寄生物/贪婪眼外观。
	if not opts.force_variant then
		if opts.parasitoid then variant = TearVariant.EGG end
		if opts.eye_of_greed and TearVariant.COIN then variant = TearVariant.COIN end
	else
		variant = opts.force_variant
	end
	-- 制造泪必须脱钩玩家 TearVariant（否则玩家铅笔/血泪等会污染无对应材料的飞行器）。
	-- 注意：对已是目标 Variant 再 ChangeVariant 会让泪弹贴图丢失（含 BLUE=0）。
	local want = variant
	if want == nil then want = TearVariant.BLUE or 0 end
	if tear.ChangeVariant and tear.Variant ~= want then
		tear:ChangeVariant(want)
		if tear.ResetSpriteScale then tear:ResetSpriteScale() end
	end

	if not height_delta_applied and height_delta and tear.Height ~= nil then
		tear.Height = tear.Height + height_delta
	end
end

return M
