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
function M.falling_for_range(height, range, shotspeed, tear_speed)
	height = tonumber(height) or BASE_HEIGHT
	if height > -1 then height = BASE_HEIGHT end
	range = math.max(20, tonumber(range) or BASE_RANGE)
	local speed = tonumber(tear_speed)
	if not speed or speed < 0.5 then
		speed = TEAR_SPEED_PER_SHOTSPEED * math.max(0.1, tonumber(shotspeed) or 1)
	end
	local n = range / speed
	if n < 1 then n = 1 end
	local fa = -2 * height / (n * (n + 1))
	if fa < 0.02 then fa = 0.02 end
	if fa > 2 then fa = 2 end
	return fa, 0
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
