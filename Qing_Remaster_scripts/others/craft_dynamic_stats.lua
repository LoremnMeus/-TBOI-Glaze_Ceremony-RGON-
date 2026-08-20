-- 蓝图制造动态/条件属性：只改 Air Flight 档案，不改玩家
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "Craft_Dynamic_Stats_",
}

local BLOODY_LUST_DMG = {0, 0.5, 1.2, 2.1, 3.2, 4.5, 6.0}

-- Binge Eater：仅这八个原版 food 会提供其专属永久属性。
local BINGE_FOOD = {
	[22] = {fire_rate = 0.5, range = 100}, -- Lunch
	[23] = {fire_rate = 0.5, shotspeed = 0.2}, -- Dinner
	[24] = {damage = 1, shotspeed = 0.2}, -- Dessert
	[25] = {shotspeed = 0.2, range = 100}, -- Breakfast
	[26] = {damage = 1, range = 100}, -- Rotten Meat
	[346] = {shotspeed = 0.2, luck = 1}, -- A Snack
	[456] = {damage = 1, luck = 1}, -- Midnight Snack
	[707] = {fire_rate = 0.5, luck = 1}, -- Supper
}

-- PurityState: RED=0 / BLUE=1 / YELLOW=2 / ORANGE=3
-- BLUE 用 fire_rate，合并时按 FR=30/(delay+1) 反算 firedelay
local PURITY_BY_STATE = {
	[0] = {damage = 4},
	[1] = {fire_rate = 2},
	[2] = {speed = 0.5},
	[3] = {range = 120}, -- +3 显示射程
}

local function ncount(counts, id)
	return (counts and counts[id]) or 0
end

local function player_data(player)
	if not player then return nil end
	return player:GetData()
end

local function clamp(v, a, b)
	if v < a then return a end
	if v > b then return b end
	return v
end

--- 真实持有（忽略 imitate / modifiers）
local function truly_owns(player, id)
	return player and player.HasCollectible and player:HasCollectible(id, true) == true
end

local function dyn_slot(rec, id)
	if not rec then return nil end
	rec.dynamic = rec.dynamic or {}
	local key = tostring(id)
	if type(rec.dynamic[key]) ~= "table" then
		rec.dynamic[key] = {}
	end
	return rec.dynamic[key]
end

local function craft_rng(player, rec, salt)
	local seed = (rec and tonumber(rec.uid)) or 1
	seed = seed + (tonumber(salt) or 0) * 97
	if player and player.InitSeed then seed = seed + (player.InitSeed % 10007) end
	local room = Game() and Game():GetRoom()
	if room and room.GetDecorationSeed then seed = seed + (room:GetDecorationSeed() % 100003) end
	seed = seed % 4294967296
	if seed <= 0 then seed = seed + 4294967296 end
	local rng = RNG()
	rng:SetSeed(math.floor(seed), 35)
	return rng
end

--- 事件型随机不得每次从同一 seed 的首项重新开始；序号保存在对应 Flight 档案中。
local function next_craft_rng(player, rec, salt)
	if not rec then return craft_rng(player, rec, salt) end
	rec.dynamic_rng_serial = rec.dynamic_rng_serial or {}
	local key = tostring(salt or 0)
	local serial = (tonumber(rec.dynamic_rng_serial[key]) or 0) + 1
	rec.dynamic_rng_serial[key] = serial
	return craft_rng(player, rec, (tonumber(salt) or 0) + serial * 1009)
end

-- wiki: 第 k 次受伤（previous=k-1）speed=(0.04*prev)+0.07，FR=(0.1*prev)+0.25；最多 6 层 → +1.02 / +3.0
local function bloody_gust_bonuses(hits)
	hits = clamp(hits or 0, 0, 6)
	local spd, fr = 0, 0
	for prev = 0, hits - 1 do
		spd = spd + (0.04 * prev + 0.07)
		fr = fr + (0.1 * prev + 0.25)
	end
	return spd, fr
end

local function delay_to_fire_rate(delay)
	return 30 / (math.max(delay or 0, 0) + 1)
end

local function fire_rate_to_delay(fr)
	fr = math.max(fr or 0.1, 0.1)
	return 30 / fr - 1
end

local function apply_fire_rate_bonus(delay, fr_bonus)
	if not fr_bonus or fr_bonus == 0 then return delay end
	return fire_rate_to_delay(delay_to_fire_rate(delay) + fr_bonus)
end

function item.get_level_hit_count(player)
	local d = player_data(player)
	if not d then return 0 end
	return clamp(tonumber(d[item.own_key.."level_hit_count"]) or 0, 0, 6)
end

function item.get_room_kill_count(player)
	local d = player_data(player)
	if not d then return 0 end
	return clamp(tonumber(d[item.own_key.."room_kill_count"]) or 0, 0, 10)
end

function item.set_crown_light_off(player, off)
	local d = player_data(player)
	if d then d[item.own_key.."crown_light_off"] = off and true or nil end
end

function item.is_crown_light_off(player)
	local d = player_data(player)
	return d and d[item.own_key.."crown_light_off"] == true
end

local function has_effect(player, id)
	if not player or not player.GetEffects then return false end
	local eff = player:GetEffects()
	if not eff then return false end
	if eff.HasCollectibleEffect and eff:HasCollectibleEffect(id) then return true end
	if eff.GetCollectibleEffectNum then
		return (eff:GetCollectibleEffectNum(id) or 0) > 0
	end
	return false
end

local function whore_active(player)
	if not player then return false end
	if has_effect(player, 122) then return true end
	-- 无红心容器：视为可激活
	local max_red = player:GetMaxHearts() or 0
	if max_red <= 0 then return true end
	local red = player:GetHearts() or 0
	-- 半颗红心及以下（普通角色）
	return red <= 1
end

local function missing_full_heart_containers(player)
	if not player then return 0 end
	local max_red = player:GetMaxHearts() or 0
	if max_red <= 0 then return 0 end
	local containers = math.floor(max_red / 2)
	local filled = math.ceil((player:GetHearts() or 0) / 2)
	return math.max(0, containers - filled)
end

local function crown_of_light_active(player)
	if not player then return false end
	if item.is_crown_light_off(player) then return false end
	if has_effect(player, 415) then return true end
	local max_red = player:GetMaxHearts() or 0
	if max_red <= 0 then return false end
	return (player:GetHearts() or 0) >= max_red
end

local function dark_prince_crown_active(player)
	if not player then return false end
	if has_effect(player, 442) then return true end
	-- 恰好 1 完整红心（2 半格）
	local red = player:GetHearts() or 0
	return red == 2
end

--- 供飞行器王冠渲染与其它模块查询明灭
function item.crown_of_light_active(player)
	return crown_of_light_active(player)
end

function item.dark_prince_crown_active(player)
	return dark_prince_crown_active(player)
end

--- 保证实验性针剂结果稳定写入 rec
function item.ensure_experimental(rec, player)
	if not rec then return nil end
	if rec.experimental and type(rec.experimental) == "table" then
		return rec.experimental
	end
	local rng = nil
	if player and player.GetCollectibleRNG then
		rng = player:GetCollectibleRNG(CollectibleType.COLLECTIBLE_EXPERIMENTAL_TREATMENT or 240)
	end
	local seed = (rec.uid and tonumber(rec.uid)) or (rec.seed) or 1
	local function rind(n)
		if rng then return rng:RandomInt(n) end
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed % n
	end
	local keys = {"damage", "speed", "shotspeed", "luck", "firedelay", "range"}
	-- 洗牌后前 4 正 2 负
	for i = #keys, 2, -1 do
		local j = rind(i) + 1
		keys[i], keys[j] = keys[j], keys[i]
	end
	local out = {}
	for i = 1, #keys do
		out[keys[i]] = (i <= 4) and 1 or -1
	end
	rec.experimental = out
	return out
end

local function apply_experimental(add, mul, signs, copies)
	copies = math.max(1, copies or 1)
	for _ = 1, copies do
		if not signs then break end
		add.damage = add.damage + (signs.damage or 0) * 1
		add.speed = add.speed + (signs.speed or 0) * 0.2
		add.shotspeed = add.shotspeed + (signs.shotspeed or 0) * 0.2
		add.luck = add.luck + (signs.luck or 0) * 1
		add.firedelay = add.firedelay + (signs.firedelay or 0) * (-0.5) -- +tears → -delay
		add.range = add.range + (signs.range or 0) * 100 -- 2.5 * 40
	end
end

local function purity_bonus_from_state(st)
	if PurityState then
		if st == PurityState.RED then return PURITY_BY_STATE[0] end
		if st == PurityState.BLUE then return PURITY_BY_STATE[1] end
		if st == PurityState.YELLOW then return PURITY_BY_STATE[2] end
		if st == PurityState.ORANGE then return PURITY_BY_STATE[3] end
	end
	return PURITY_BY_STATE[st] or PURITY_BY_STATE[0]
end

local function purity_bonus_owned(player)
	if not player or not truly_owns(player, 407) then return nil end
	if not player.GetPurityState then return PURITY_BY_STATE[0] end
	return purity_bonus_from_state(player:GetPurityState())
end

--- 未持有时：Flight 独立颜色；commit 时若无状态则初始化
function item.ensure_purity_sim(rec, player, commit)
	local slot = dyn_slot(rec, 407)
	if not slot then return PURITY_BY_STATE[0] end
	if slot.pending_room_reroll then return nil end
	if slot.state == nil then
		if commit then
			local rng = craft_rng(player, rec, 407)
			slot.state = rng:RandomInt(4)
		else
			return PURITY_BY_STATE[0]
		end
	end
	return PURITY_BY_STATE[tonumber(slot.state) or 0] or PURITY_BY_STATE[0]
end

function item.reroll_purity_sim(rec, player)
	local slot = dyn_slot(rec, 407)
	if not slot then return end
	local rng = craft_rng(player, rec, 407 + Game():GetFrameCount())
	slot.state = rng:RandomInt(4)
end

local function suspend_purity_sim(rec)
	local slot = dyn_slot(rec, 407)
	if not slot then return end
	slot.state = nil
	slot.pending_room_reroll = true
end

local function resume_purity_sim(rec, player)
	local slot = dyn_slot(rec, 407)
	if not slot or not slot.pending_room_reroll then return end
	slot.pending_room_reroll = nil
	local rng = next_craft_rng(player, rec, 407)
	slot.state = rng:RandomInt(4)
end

--- Libra（Repentance/DLC+ wiki 闭式公式）：平衡 speed / fire rate / damage / range。
--- 必须在 build_profile 完成 fire_rate_mul / 武器倍率 / Rock Bottom 之后调用。
--- 本项目 stats.range 使用原版显示射程的 40 倍；stats.firedelay 是 MaxFireDelay，
--- 因此 b = 30 / (firedelay + 1)，d = range / 40。
--- luck / shot speed 不参与平衡。角色/飞行器的基准档案是 Isaac 默认属性。
function item.apply_libra(stats, player)
	if not stats then return end
	local a0 = 1
	local b0 = 30 / 11
	local c0 = 3.5

	local a = tonumber(stats.speed) or a0
	local pending_fr_mul = tonumber(stats.fire_rate_mul) or 1
	if pending_fr_mul <= 0 then pending_fr_mul = 1 end
	local b = delay_to_fire_rate(tonumber(stats.firedelay) or 10) * pending_fr_mul
	local c = tonumber(stats.damage) or c0
	local d = (tonumber(stats.range) or 260) / 40

	local damage_tears_ratio = math.max(0, (b * c) / (b0 * c0))
	local x = 0.25 * (a + (4 * d + 1) / 27)
		+ 0.5 * (damage_tears_ratio ^ (13 / 40))
	x = math.max(0, x)

	stats.speed = math.min(2, x)
	stats.firedelay = fire_rate_to_delay(b0 * (x ^ (4 / 3)))
	stats.damage = c0 * (x ^ (100 / 56))
	stats.range = ((27 * x - 1) / 4) * 40
	stats.fire_rate_mul = 1
end

function item.floor_key()
	local level = Game():GetLevel()
	if not level then return 0 end
	return (level:GetStage() or 0) * 100 + (level:GetStageType() or 0)
end

--- 562 Rock Bottom：用当前底层更新峰值后覆写输出；峰值不回灌为下次输入。
function item.apply_rock_bottom(stats, rec)
	if not stats or not rec then return end
	local maxv = rec.rock_bottom_max
	if type(maxv) ~= "table" then
		maxv = {}
		rec.rock_bottom_max = maxv
	end
	local fr = delay_to_fire_rate(tonumber(stats.firedelay) or 10)
	local function bump(key, val)
		val = tonumber(val) or 0
		local prev = tonumber(maxv[key])
		if prev == nil or val > prev then maxv[key] = val end
	end
	bump("damage", stats.damage)
	bump("speed", stats.speed)
	bump("range", stats.range)
	bump("shotspeed", stats.shotspeed)
	bump("luck", stats.luck)
	bump("fire_rate", fr)
	stats.damage = maxv.damage
	stats.speed = maxv.speed
	stats.range = maxv.range
	stats.shotspeed = maxv.shotspeed
	stats.luck = maxv.luck
	stats.firedelay = math.max(1, fire_rate_to_delay(maxv.fire_rate or fr))
end

-- Candy Heart / Soul Locket：getter 已是玩家累计总量。
-- 材料份数 >0 时只复制一份，禁止再按 copies 叠乘。
local function apply_bonus_table(add, fire_delay_add_ref, bonus, copies)
	if not bonus or (copies or 0) <= 0 then return end
	add.damage = add.damage + (tonumber(bonus.Damage) or 0)
	add.speed = add.speed + (tonumber(bonus.MoveSpeed) or 0)
	add.shotspeed = add.shotspeed + (tonumber(bonus.ShotSpeed) or 0)
	add.luck = add.luck + (tonumber(bonus.Luck) or 0)
	-- TearRange：内部单位直加（不再 ×40）
	add.range = add.range + (tonumber(bonus.TearRange) or 0)
	-- FireDelay：delay 加算（可负）
	fire_delay_add_ref[1] = fire_delay_add_ref[1] + (tonumber(bonus.FireDelay) or 0)
end

local function keepers_sack_bonus(coins)
	coins = math.max(0, tonumber(coins) or 0)
	local q = math.floor(coins / 3)
	local damage_count = math.floor((q + 2) / 3)
	local range_count = math.floor((q + 1) / 3)
	local speed_count = math.floor(q / 3)
	return {
		damage = 0.5 * damage_count,
		range = 10 * range_count,
		speed = 0.03 * speed_count,
	}
end

-- 191 白名单：简单 tear flags（轮换时 OR 进 flag_extra）
item.DOLLAR_BILL_POOL = {
	{flag = TearFlags.TEAR_HOMING, name = "homing"},
	{flag = TearFlags.TEAR_SPECTRAL, name = "spectral"},
	{flag = TearFlags.TEAR_POISON, name = "poison"},
	{flag = TearFlags.TEAR_SLOW, name = "slow"},
	{flag = TearFlags.TEAR_FEAR, name = "fear"},
	{flag = TearFlags.TEAR_CHARM, name = "charm"},
	{flag = TearFlags.TEAR_BURN, name = "burn"},
	{flag = TearFlags.TEAR_CONFUSION, name = "confusion"},
	{flag = TearFlags.TEAR_SHRINK, name = "shrink"},
	{flag = TearFlags.TEAR_PIERCING, name = "piercing"},
}

function item.tick_dollar_bill(air, rec, counts, attacking)
	if ncount(counts, 191) <= 0 or not air then return 0 end
	local d = air:GetData()
	local key = item.own_key.."dollar_"
	if not attacking then
		return d[key.."flag"] or 0
	end
	local frame = Game():GetFrameCount()
	local next_f = d[key.."next"] or 0
	if frame >= next_f then
		local rng = nil
		local player = air.Player or auxi.check_spawner_player(air)
		if player and player.GetCollectibleRNG then
			rng = player:GetCollectibleRNG(191)
		end
		local pool = item.DOLLAR_BILL_POOL
		local idx = 1
		if rng then idx = rng:RandomInt(#pool) + 1
		else idx = (frame % #pool) + 1 end
		local pick = pool[idx]
		d[key.."flag"] = pick.flag
		d[key.."name"] = pick.name
		local span = 60 + (rng and rng:RandomInt(31) or (frame % 31))
		d[key.."next"] = frame + span
	end
	return d[key.."flag"] or 0
end

--- 主入口：就地修改 stats，返回附加信息
--- ctx.commit_state：为 true（或存在 air）时才写回 rec 上的持续计时/峰值；预览必须为 false
function item.apply_to_stats(stats, ctx)
	ctx = ctx or {}
	local player = ctx.player
	local rec = ctx.rec
	local counts = ctx.counts or {}
	local air = ctx.air
	local runtime_in = ctx.runtime or {}
	local commit_state = ctx.commit_state == true or air ~= nil
	local add = {damage = 0, firedelay = 0, shotspeed = 0, range = 0, luck = 0, speed = 0}
	local mul = {damage = 1}
	local tags = {}
	local extras = {}
	local runtime = {}
	local body_extra = 1
	local fire_rate_mul = 1
	local fire_rate_add = 0
	local flag_extra = 0

	local function copies(id)
		return ncount(counts, id)
	end

	-- 109 Money = Power
	if copies(109) > 0 and player then
		local coins = clamp(player:GetNumCoins() or 0, 0, 99)
		add.damage = add.damage + 0.04 * coins * copies(109)
		tags[#tags + 1] = "money"
	end

	-- 122 Whore of Babylon
	if copies(122) > 0 and whore_active(player) then
		add.damage = add.damage + 1.5 * copies(122)
		add.speed = add.speed + 0.3 * copies(122)
		tags[#tags + 1] = "whore"
	end

	-- 157 / 695 共享本层受伤层数
	local hits = item.get_level_hit_count(player)
	if copies(157) > 0 then
		add.damage = add.damage + (BLOODY_LUST_DMG[hits + 1] or 0) * copies(157)
		tags[#tags + 1] = "bloody_lust"
	end
	if copies(695) > 0 then
		local gust_spd, gust_fr = bloody_gust_bonuses(hits)
		add.speed = add.speed + gust_spd * copies(695)
		fire_rate_add = fire_rate_add + gust_fr * copies(695)
		tags[#tags + 1] = "bloody_gust"
	end

	-- 240 Experimental Treatment
	if copies(240) > 0 then
		local signs = item.ensure_experimental(rec, player)
		apply_experimental(add, mul, signs, copies(240))
		tags[#tags + 1] = "experimental"
	end

	-- 493 Adrenaline
	if copies(493) > 0 and player then
		local miss = missing_full_heart_containers(player)
		local bonus = ((2 * miss) ^ 1.6) * 0.1
		add.damage = add.damage + bonus * copies(493)
		tags[#tags + 1] = "adrenaline"
	end

	-- 415 Crown of Light
	if copies(415) > 0 and crown_of_light_active(player) then
		mul.damage = mul.damage * (2 ^ copies(415))
		add.shotspeed = add.shotspeed - 0.3 * copies(415)
		tags[#tags + 1] = "crown_light"
	end

	-- 442 Dark Prince's Crown
	if copies(442) > 0 and dark_prince_crown_active(player) then
		add.firedelay = add.firedelay - 2 * copies(442) -- +2 fire rate 近似
		add.range = add.range + 60 * copies(442)
		add.shotspeed = add.shotspeed + 0.2 * copies(442)
		tags[#tags + 1] = "dark_crown"
	end

	-- 407 Purity：真实持有读 GetPurityState；否则 Flight 独立颜色
	if copies(407) > 0 then
		local b = nil
		if truly_owns(player, 407) then
			b = purity_bonus_owned(player)
		else
			b = item.ensure_purity_sim(rec, player, commit_state)
		end
		if b then
			for _ = 1, copies(407) do
				add.damage = add.damage + (b.damage or 0)
				add.speed = add.speed + (b.speed or 0)
				add.range = add.range + (b.range or 0)
				fire_rate_add = fire_rate_add + (b.fire_rate or 0)
			end
			tags[#tags + 1] = "purity"
		end
	end

	-- 411 Lusty Blood：真实持有可读 effect 层；否则用 Flight 击杀归属
	if copies(411) > 0 then
		local kills = item.get_room_kill_count(player)
		if truly_owns(player, 411) and has_effect(player, 411) then
			local eff = player:GetEffects()
			local n = eff and eff.GetCollectibleEffectNum and eff:GetCollectibleEffectNum(411)
			if n and n > 0 then kills = clamp(n, 0, 10) end
		end
		add.damage = add.damage + 0.5 * kills * copies(411)
		tags[#tags + 1] = "lusty_blood"
	end

	-- 436 Milk!：本层破碎后 +1.0 Fire Rate；该层不再认领新牛奶
	if copies(436) > 0 and rec and rec.milk_broken_floor ~= nil then
		if tonumber(rec.milk_broken_floor) == item.floor_key() then
			fire_rate_add = fire_rate_add + 1.0
			tags[#tags + 1] = "milk"
			extras.milk = false
		end
	end

	-- 497 Camo Undies（由 AF 写入 runtime）
	if copies(497) > 0 then
		if runtime_in.camo_stealthed then
			add.speed = add.speed + 0.5 * copies(497)
			tags[#tags + 1] = "camo_undies"
		end
		local camo_dmg = tonumber(runtime_in.camo_damage) or 0
		local camo_fr = tonumber(runtime_in.camo_fire_rate) or 0
		if camo_dmg ~= 0 or camo_fr ~= 0 then
			add.damage = add.damage + camo_dmg * copies(497)
			fire_rate_add = fire_rate_add + camo_fr * copies(497)
			tags[#tags + 1] = "camo_undies"
		end
	end

	-- 594 Jupiter：静止积蓄的额外移速
	if copies(594) > 0 then
		local jup = tonumber(runtime_in.jupiter_speed) or 0
		if jup > 0 then
			add.speed = add.speed + jup * copies(594)
			tags[#tags + 1] = "jupiter"
		end
	end

	-- 567 Paschal Candle：真实持有读 effect；否则 Flight 清房层；多个不叠加
	if copies(567) > 0 then
		local layers = 0
		if truly_owns(player, 567) and player and player.GetEffects then
			local eff = player:GetEffects()
			local n = eff and eff.GetCollectibleEffectNum and eff:GetCollectibleEffectNum(567)
			if n and n > 0 then layers = clamp(n, 0, 5) end
		elseif rec then
			if rec.paschal_layers == nil and commit_state then rec.paschal_layers = 1 end
			layers = clamp(tonumber(rec.paschal_layers) or 1, 0, 5)
		end
		if layers > 0 then
			fire_rate_add = fire_rate_add + 0.4 * layers
			tags[#tags + 1] = "paschal_candle"
			runtime.paschal_layers = layers
		end
	end

	-- 664 Binge Eater：RGON 没有专用 getter，按该 Flight 配方内的 food 独立模拟。
	if copies(664) > 0 then
		local food_total = 0
		for id, bonus in pairs(BINGE_FOOD) do
			local n = ncount(counts, id)
			if n > 0 then
				food_total = food_total + n
				add.damage = add.damage + (bonus.damage or 0) * n
				add.shotspeed = add.shotspeed + (bonus.shotspeed or 0) * n
				add.range = add.range + (bonus.range or 0) * n
				add.luck = add.luck + (bonus.luck or 0) * n
				fire_rate_add = fire_rate_add + (bonus.fire_rate or 0) * n
			end
		end
		add.speed = add.speed - 0.03 * food_total

		local dur = 0
		if rec then
			if commit_state then
				local now = Game():GetFrameCount()
				local previous = tonumber(rec.binge_food_total)
				if previous == nil then
					rec.binge_food_total = food_total
				elseif food_total > previous then
					rec.binge_duration = 900
					rec.binge_food_total = food_total
				elseif food_total ~= previous then
					rec.binge_food_total = food_total
				end
				local last = tonumber(rec.binge_last_frame) or now
				local elapsed = math.max(0, now - last) + (tonumber(rec.binge_frame_remainder) or 0)
				rec.binge_duration = math.max(0, (tonumber(rec.binge_duration) or 0) - math.floor(elapsed / 2))
				rec.binge_frame_remainder = elapsed % 2
				rec.binge_last_frame = now
			end
			dur = tonumber(rec.binge_duration) or 0
		end
		if dur > 0 then
			add.damage = add.damage + 3.6 * math.min(1, dur / 900)
		end
		tags[#tags + 1] = "binge_eater"
	end

	-- 654 False PHD：没有可读取的原版累计 getter；Flight 独立记录配方存在期间吃下的属性下降药丸。
	if copies(654) > 0 then
		add.damage = add.damage + (tonumber(rec and rec.false_phd_damage) or 0)
		tags[#tags + 1] = "false_phd"
	end

	-- 621 Red Stew：t 初始 5400，每 2 帧 -1，击杀 +30，上限 9000；多个不叠加
	if copies(621) > 0 then
		local dur = 0
		if truly_owns(player, 621) and player.GetRedStewBonusDuration then
			dur = tonumber(player:GetRedStewBonusDuration()) or 0
			if dur > 0 and rec and commit_state then
				rec.red_stew_duration = dur
				rec.red_stew_last_frame = Game():GetFrameCount()
			end
		elseif rec then
			if commit_state then
				local now = Game():GetFrameCount()
				if rec.red_stew_duration == nil then
					rec.red_stew_duration = 5400
					rec.red_stew_last_frame = now
					rec.red_stew_frame_remainder = 0
				else
					local last = tonumber(rec.red_stew_last_frame) or now
					local elapsed = math.max(0, now - last) + (tonumber(rec.red_stew_frame_remainder) or 0)
					rec.red_stew_duration = math.max(0, (tonumber(rec.red_stew_duration) or 0) - math.floor(elapsed / 2))
					rec.red_stew_frame_remainder = elapsed % 2
					rec.red_stew_last_frame = now
				end
			end
			dur = tonumber(rec.red_stew_duration) or 0
		end
		if dur > 0 then
			add.damage = add.damage + math.floor(0.1 * dur) / 25
			tags[#tags + 1] = "red_stew"
		end
	end

	-- 694 Heartbreak（碎心数来自玩家本体，非道具内部累计）
	if copies(694) > 0 and player and player.GetBrokenHearts then
		local n = tonumber(player:GetBrokenHearts()) or 0
		if n > 0 then
			add.damage = add.damage + 0.25 * n * copies(694)
			tags[#tags + 1] = "heartbreak"
		end
	end

	-- 716 Keeper's Sack：真实持有读 getter 一次；否则 Flight 消费累计器
	if copies(716) > 0 then
		local sack = nil
		if truly_owns(player, 716) and player.GetKeepersSackBonus then
			sack = keepers_sack_bonus(player:GetKeepersSackBonus())
		elseif rec then
			local Sack = require("Qing_Remaster_scripts.mimics.Keeper_Sack_holder")
			sack = Sack.stats_from_layers(dyn_slot(rec, 716))
		end
		if sack then
			add.damage = add.damage + (sack.damage or 0)
			add.range = add.range + (sack.range or 0)
			add.speed = add.speed + (sack.speed or 0)
			if (sack.damage or 0) > 0 or (sack.range or 0) > 0 or (sack.speed or 0) > 0 then
				tags[#tags + 1] = "keepers_sack"
			end
		end
	end

	-- 671/686：真实持有复制 getter 一次；否则读 Flight 独立层数
	local fd_add = {0}
	if copies(671) > 0 then
		if truly_owns(player, 671) and player.GetCandyHeartBonus then
			apply_bonus_table(add, fd_add, player:GetCandyHeartBonus(), 1)
			tags[#tags + 1] = "candy_heart"
		elseif rec then
			local Heart = require("Qing_Remaster_scripts.mimics.Heart_holder")
			local b = Heart.bonus_from_layers(dyn_slot(rec, 671), 1)
			add.damage = add.damage + (b.damage or 0)
			add.range = add.range + (b.range or 0)
			add.speed = add.speed + (b.speed or 0)
			add.shotspeed = add.shotspeed + (b.shotspeed or 0)
			add.luck = add.luck + (b.luck or 0)
			fire_rate_add = fire_rate_add + (b.tear or 0)
			if (b.damage or 0) + (b.range or 0) + (b.speed or 0) + (b.tear or 0) > 0 then
				tags[#tags + 1] = "candy_heart"
			end
		end
	end
	if copies(686) > 0 then
		if truly_owns(player, 686) and player.GetSoulLocketBonus then
			apply_bonus_table(add, fd_add, player:GetSoulLocketBonus(), 1)
			tags[#tags + 1] = "soul_locket"
		elseif rec then
			local Heart = require("Qing_Remaster_scripts.mimics.Heart_holder")
			local b = Heart.bonus_from_layers(dyn_slot(rec, 686), 2)
			add.damage = add.damage + (b.damage or 0)
			add.range = add.range + (b.range or 0)
			add.speed = add.speed + (b.speed or 0)
			add.shotspeed = add.shotspeed + (b.shotspeed or 0)
			add.luck = add.luck + (b.luck or 0)
			fire_rate_add = fire_rate_add + (b.tear or 0)
			if (b.damage or 0) + (b.range or 0) + (b.speed or 0) + (b.tear or 0) > 0 then
				tags[#tags + 1] = "soul_locket"
			end
		end
	end
	add.firedelay = add.firedelay + fd_add[1]

	-- 运行时射击状态（由 Air Flight 写入 runtime_in）
	if runtime_in.epiphora_fire_rate_mul then
		fire_rate_mul = fire_rate_mul * clamp(tonumber(runtime_in.epiphora_fire_rate_mul) or 1, 1, 2)
	end
	if runtime_in.eye_drops_fire_rate_mul then
		fire_rate_mul = fire_rate_mul * (tonumber(runtime_in.eye_drops_fire_rate_mul) or 1)
	end
	if runtime_in.neptunus_fire_rate_mul then
		fire_rate_mul = fire_rate_mul * clamp(tonumber(runtime_in.neptunus_fire_rate_mul) or 1, 1, 6)
	end
	if runtime_in.dead_eye_damage_mul then
		mul.damage = mul.damage * (tonumber(runtime_in.dead_eye_damage_mul) or 1)
	end
	if runtime_in.dollar_flag then
		flag_extra = flag_extra | runtime_in.dollar_flag
	end

	-- 合并加算/乘算；Fire Rate 加算按当前 delay 反算（可突破软上限语义）
	-- Libra / Rock Bottom 改在 craft_combat_profile.build_profile 武器倍率之后执行
	stats.damage = (stats.damage + add.damage) * mul.damage
	stats.firedelay = apply_fire_rate_bonus(stats.firedelay + add.firedelay, fire_rate_add)
	stats.shotspeed = stats.shotspeed + add.shotspeed
	stats.range = stats.range + add.range
	stats.luck = stats.luck + add.luck
	stats.speed = stats.speed + add.speed
	stats.fire_rate_mul = (tonumber(stats.fire_rate_mul) or 1) * fire_rate_mul

	if copies(304) > 0 then
		tags[#tags + 1] = "libra"
		extras.libra = true
	end
	if copies(562) > 0 then
		tags[#tags + 1] = "rock_bottom"
		extras.rock_bottom = true
	end

	runtime.flag_extra = flag_extra
	return {
		body_scale_mul = body_extra,
		tags = tags,
		extras = extras,
		runtime = runtime,
		flag_extra = flag_extra,
	}
end

local function each_craft(player, fn)
	local bp = require("Qing_Remaster_scripts.items.Item_Blue_Print")
	if not bp or not bp.get_craft_store then return end
	for _, rec in ipairs(bp.get_craft_store(player) or {}) do
		fn(rec)
	end
end

local function craft_count(rec, id)
	if not rec or not rec.ingredients then return 0 end
	local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")
	local n = 0
	local seen = {}
	for slot, v in pairs(rec.ingredients) do
		local sk = tostring(slot)
		if not seen[sk] then
			seen[sk] = true
			if CraftProfile.ingredient_id(v) == id then n = n + 1 end
		end
	end
	return n
end

local function craft_has(rec, id)
	return craft_count(rec, id) > 0
end

local function heart_roll_amounts(subtype)
	subtype = tonumber(subtype) or 0
	local candy, soul = 0, 0
	if subtype == HeartSubType.HEART_FULL or subtype == HeartSubType.HEART_SCARED then
		candy = 2
	elseif subtype == HeartSubType.HEART_HALF then
		candy = 1
	elseif subtype == HeartSubType.HEART_DOUBLEPACK then
		candy = 4
	elseif subtype == HeartSubType.HEART_SOUL or subtype == HeartSubType.HEART_BLACK then
		soul = 2
	elseif subtype == HeartSubType.HEART_HALF_SOUL then
		soul = 1
	elseif subtype == HeartSubType.HEART_BLENDED then
		candy, soul = 1, 1
	elseif subtype == HeartSubType.HEART_BONE or subtype == HeartSubType.HEART_ROTTEN then
		candy = 1
	end
	return candy, soul
end

--- 未真实持有时：红心/魂心拾取写入 Flight 独立累计（份数提高抽取次数）
function item.on_craft_heart_pickup(player, candy_cnt, soul_cnt)
	if not player then return end
	candy_cnt = math.max(0, math.floor(tonumber(candy_cnt) or 0))
	soul_cnt = math.max(0, math.floor(tonumber(soul_cnt) or 0))
	if candy_cnt <= 0 and soul_cnt <= 0 then return end
	local Heart = require("Qing_Remaster_scripts.mimics.Heart_holder")
	each_craft(player, function(rec)
		if candy_cnt > 0 and not truly_owns(player, 671) then
			local n = craft_count(rec, 671)
			if n > 0 then
				local slot = dyn_slot(rec, 671)
				Heart.roll_heart_bonus(slot, next_craft_rng(player, rec, 671), candy_cnt * n)
			end
		end
		if soul_cnt > 0 and not truly_owns(player, 686) then
			local n = craft_count(rec, 686)
			if n > 0 then
				local slot = dyn_slot(rec, 686)
				Heart.roll_heart_bonus(slot, next_craft_rng(player, rec, 686), soul_cnt * n)
			end
		end
	end)
end

--- 未真实持有店长袋时：把玩家商店消费写入各 Flight
function item.on_player_spent_coins(player, price)
	if not player or (tonumber(price) or 0) <= 0 then return end
	if truly_owns(player, 716) then return end
	local Sack = require("Qing_Remaster_scripts.mimics.Keeper_Sack_holder")
	each_craft(player, function(rec)
		local n = craft_count(rec, 716)
		if n <= 0 then return end
		local slot = dyn_slot(rec, 716)
		local rolls = Sack.add_spent(slot, price)
		if rolls > 0 then
			Sack.roll_sack_bonus(slot, next_craft_rng(player, rec, 716), rolls * n)
		end
	end)
end

local function paschal_ignores_damage(flags)
	flags = flags or 0
	if DamageFlag.DAMAGE_NO_PENALTIES and (flags & DamageFlag.DAMAGE_NO_PENALTIES) ~= 0 then return true end
	if DamageFlag.DAMAGE_FAKE and (flags & DamageFlag.DAMAGE_FAKE) ~= 0 then return true end
	if DamageFlag.DAMAGE_IV_BAG and (flags & DamageFlag.DAMAGE_IV_BAG) ~= 0 then return true end
	if DamageFlag.DAMAGE_CURSED_DOOR and (flags & DamageFlag.DAMAGE_CURSED_DOOR) ~= 0 then return true end
	if DamageFlag.DAMAGE_CHEST and (flags & DamageFlag.DAMAGE_CHEST) ~= 0 then return true end
	if DamageFlag.DAMAGE_SPIKES and (flags & DamageFlag.DAMAGE_SPIKES) ~= 0 then
		local rt = Game():GetRoom():GetType()
		if rt == RoomType.ROOM_SACRIFICE or rt == RoomType.ROOM_DEVIL then return true end
	end
	return false
end

-- 受伤：嗜血层 + 白王冠关闭；Paschal 只对原版会熄灭蜡烛的伤害清零
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_ENTITY_TAKE_DMG or ModCallbacks.MC_ENTITY_TAKE_DMG,
	params = EntityType.ENTITY_PLAYER,
	Function = function(_, ent, amount, flags, source, countdown)
		local player = ent and ent:ToPlayer()
		if not player or (amount or 0) <= 0 then return end
		-- 自伤/持续伤害去重：同一帧只计一次
		local d = player:GetData()
		local frame = Game():GetFrameCount()
		if d[item.own_key.."hit_frame"] == frame then return end
		d[item.own_key.."hit_frame"] = frame
		local n = tonumber(d[item.own_key.."level_hit_count"]) or 0
		d[item.own_key.."level_hit_count"] = clamp(n + 1, 0, 6)
		item.set_crown_light_off(player, true)
		local clear_paschal = not paschal_ignores_damage(flags)
		if clear_paschal then d[item.own_key.."paschal_room_hit"] = true end
		each_craft(player, function(rec)
			if clear_paschal and craft_has(rec, 567) then
				rec.paschal_layers = 0
			end
			if craft_has(rec, 407) and not truly_owns(player, 407) then
				suspend_purity_sim(rec)
			end
		end)
	end,
})

local function heart_state(player)
	return {
		hearts = player:GetHearts() or 0,
		soul = player:GetSoulHearts() or 0,
		bone = player.GetBoneHearts and (player:GetBoneHearts() or 0) or 0,
		rotten = player.GetRottenHearts and (player:GetRottenHearts() or 0) or 0,
	}
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION,
	params = PickupVariant.PICKUP_HEART,
	Function = function(_, pickup, collider)
		local player = collider and collider:ToPlayer()
		if not player or not pickup or pickup:IsShopItem() then return end
		local pd = pickup:GetData()
		pd[item.own_key.."heart_pre"] = pd[item.own_key.."heart_pre"] or {}
		pd[item.own_key.."heart_pre"][GetPtrHash(player)] = heart_state(player)
	end,
})

if ModCallbacks.MC_POST_PICKUP_COLLISION then
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_PICKUP_COLLISION,
		params = PickupVariant.PICKUP_HEART,
		Function = function(_, pickup, collider)
			local player = collider and collider:ToPlayer()
			if not player or not pickup or pickup:IsShopItem() then return end
			local pd = pickup:GetData()
			local all = pd[item.own_key.."heart_pre"]
			local key = GetPtrHash(player)
			local before = all and all[key]
			if not before then return end
			all[key] = nil
			local after = heart_state(player)
			local candy, soul = 0, 0
			-- 骨心/腐烂心会同时改变通用红心读数；按子类型单独计量，避免一次拾取重复结算。
			if pickup.SubType == HeartSubType.HEART_BONE then
				candy = math.max(0, after.bone - before.bone)
			elseif pickup.SubType == HeartSubType.HEART_ROTTEN then
				candy = math.max(0, after.rotten - before.rotten)
			else
				candy = math.max(0, after.hearts - before.hearts)
				soul = math.max(0, after.soul - before.soul)
			end
			if candy > 0 or soul > 0 then
				item.on_craft_heart_pickup(player, candy, soul)
			end
		end,
	})
end

if ModCallbacks.MC_POST_PICKUP_SHOP_PURCHASE then
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_PICKUP_SHOP_PURCHASE,
		params = nil,
		Function = function(_, pickup, player, money_spent)
			if player and (tonumber(money_spent) or 0) > 0 then
				item.on_player_spent_coins(player, money_spent)
			end
		end,
	})
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_LEVEL,
	params = nil,
	Function = function(_)
		for i = 0, Game():GetNumPlayers() - 1 do
			local p = Game():GetPlayer(i)
			if p then
				local d = p:GetData()
				d[item.own_key.."level_hit_count"] = 0
				d[item.own_key.."hit_frame"] = nil
				each_craft(p, function(rec)
					rec.milk_broken_floor = nil
				end)
			end
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function(_)
		for i = 0, Game():GetNumPlayers() - 1 do
			local p = Game():GetPlayer(i)
			if p then
				local d = p:GetData()
				d[item.own_key.."room_kill_count"] = 0
				d[item.own_key.."crown_light_off"] = nil
				d[item.own_key.."paschal_room_hit"] = nil
				d[item.own_key.."paschal_room_awarded"] = nil
				each_craft(p, function(rec)
					if craft_has(rec, 407) and not truly_owns(p, 407) then
						resume_purity_sim(rec, p)
					end
				end)
			end
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD,
	params = nil,
	Function = function(_)
		for i = 0, Game():GetNumPlayers() - 1 do
			local p = Game():GetPlayer(i)
			if p then
				local d = p:GetData()
				if not d[item.own_key.."paschal_room_awarded"] and not d[item.own_key.."paschal_room_hit"] then
					d[item.own_key.."paschal_room_awarded"] = true
					each_craft(p, function(rec)
						if craft_has(rec, 567) then
							rec.paschal_layers = clamp((tonumber(rec.paschal_layers) or 0) + 1, 0, 5)
						end
					end)
				end
			end
		end
	end,
})

--- Air Flight 击杀归属累加 Lusty Blood；红豆汤自维护计时最小延长
function item.on_craft_kill(player)
	if not player then return end
	local d = player:GetData()
	local n = tonumber(d[item.own_key.."room_kill_count"]) or 0
	d[item.own_key.."room_kill_count"] = clamp(n + 1, 0, 10)
	each_craft(player, function(rec)
		if craft_has(rec, 664) and (tonumber(rec.binge_duration) or 0) > 0 then
			rec.binge_duration = math.min(900, (tonumber(rec.binge_duration) or 0) + 30)
		end
		if craft_has(rec, 621) and (tonumber(rec.red_stew_duration) or 0) > 0 then
			-- 原版内部计数 t 每次击杀 +30，最大 9000。
			rec.red_stew_duration = math.min(9000, (tonumber(rec.red_stew_duration) or 0) + 30)
		end
	end)
end

local FALSE_PHD_DOWN = {
	[PillEffect.PILLEFFECT_HEALTH_DOWN] = true,
	[PillEffect.PILLEFFECT_RANGE_DOWN] = true,
	[PillEffect.PILLEFFECT_SPEED_DOWN] = true,
	[PillEffect.PILLEFFECT_TEARS_DOWN] = true,
	[PillEffect.PILLEFFECT_LUCK_DOWN] = true,
}

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_USE_PILL,
	params = nil,
	Function = function(_, effect, player, flags, color)
		if not player or not FALSE_PHD_DOWN[effect] then return end
		local giant = color and ((color & PillColor.PILL_GIANT_FLAG) ~= 0)
		local gain = giant and 1.2 or 0.6
		each_craft(player, function(rec)
			if craft_has(rec, 654) then
				rec.false_phd_damage = (tonumber(rec.false_phd_damage) or 0) + gain
			end
		end)
	end,
})

return item
